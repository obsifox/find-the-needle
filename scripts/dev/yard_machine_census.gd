extends RefCounted


const STRUCTURES:= ["platform", "stair", "railing", "yard_wall", "roof"]
const UTILITIES:= ["power_pole", "power_box", "water_main"]
var _differences: Dictionary = { }

func count(probe: Node) -> Array [Dictionary]:
	var by_type: Dictionary = { }
	for root: Node3D in probe.world.builds.every_placed():
		var script:= root.get_script() as Script
		var key:= script.resource_path.get_file().get_basename() if script != null else root.get_class()
		if key in ["conveyor", "conveyor_corner"]:
			continue
		if not by_type.has(key):
			by_type [key] = { "type": key, "roots": [], "instances": 0, "meshes": 0,
				"surfaces": 0, "eligible_surfaces": 0, "multimeshes": 0, "materials": { },
				"mesh_surfaces": 0, "eligible_meshes": 0, "eligible_mesh_surfaces": 0,
				"multimesh_surfaces": 0, "eligible_multimesh_surfaces": 0,
				"source_materials": { }, "eligible_materials": { },
				"mesh_min": 2147483647, "mesh_max": 0, "surface_min": 2147483647, "surface_max": 0 }
		var row: Dictionary = by_type [key]
		row ["roots"].append(root)
		row ["instances"] += 1
		var meshes:= 0
		var surfaces:= 0
		var stack: Array [Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child: Node in node.get_children():
				stack.append(child)
			var mesh: Mesh = null
			var geometry:= node as GeometryInstance3D
			if node is MeshInstance3D:
				mesh = node.mesh
				if mesh != null:
					meshes += 1
			elif node is MultiMeshInstance3D and node.multimesh != null:
				mesh = node.multimesh.mesh
				row ["multimeshes"] += 1
			if mesh == null:
				continue
			var n:= mesh.get_surface_count()
			surfaces += n
			var eligible: bool = geometry.is_visible_in_tree() and (geometry.layers & probe._cam.cull_mask) != 0
			var distance: float = probe._cam.global_position.distance_to(geometry.to_global(mesh.get_aabb().get_center()))
			eligible = eligible and (geometry.visibility_range_begin == 0.0 or distance >= geometry.visibility_range_begin)
			eligible = eligible and (geometry.visibility_range_end == 0.0 or distance < geometry.visibility_range_end)
			if node is MultiMeshInstance3D:
				eligible = eligible and node.multimesh.instance_count > 0 and node.multimesh.visible_instance_count != 0
				row ["multimesh_surfaces"] += n
				if eligible:
					row ["eligible_multimesh_surfaces"] += n
			else:
				row ["mesh_surfaces"] += n
				if eligible:
					row ["eligible_meshes"] += 1
					row ["eligible_mesh_surfaces"] += n
			if eligible:
				row ["eligible_surfaces"] += n
			for s in n:
				var source:= mesh.surface_get_material(s)
				var source_name:= source.resource_name if source != null else "unnamed"
				row ["source_materials"] [source_name] = int(row ["source_materials"].get(source_name, 0)) + 1
				if eligible:
					row ["eligible_materials"] [source_name] = int(row ["eligible_materials"].get(source_name, 0)) + 1
				var mat: Material = node.get_active_material(s) if node is MeshInstance3D else mesh.surface_get_material(s)
				var name: String = mat.resource_name if mat != null else "unnamed"
				if name.is_empty() and mat is ShaderMaterial:
					name = mat.shader.resource_path.get_file()
				row ["materials"] [name] = int(row ["materials"].get(name, 0)) + 1
		row ["meshes"] += meshes
		row ["surfaces"] += surfaces
		row ["mesh_min"] = mini(row ["mesh_min"], meshes)
		row ["mesh_max"] = maxi(row ["mesh_max"], meshes)
		row ["surface_min"] = mini(row ["surface_min"], surfaces)
		row ["surface_max"] = maxi(row ["surface_max"], surfaces)
	var rows: Array [Dictionary] = []
	for value: Dictionary in by_type.values():
		rows.append(value)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a ["eligible_surfaces"] > b ["eligible_surfaces"])
	print("Machine census: eligible counts apply visibility and LOD ranges, before frustum and occlusion culling.")
	for row: Dictionary in rows:
		var report:= row.duplicate()
		report.erase("roots")
		print("MACHINE_CENSUS " + JSON.stringify(report))
	return rows

func measure(probe: Node, rows: Array [Dictionary]) -> void:
	var limit:= 8
	var ua:= OS.get_cmdline_user_args()
	if "--machine-fog-only" in ua:
		await _measure_fog(probe)
		return
	if "--machine-range-ui-only" in ua:
		var ancestor: Node = probe.world.pause_menu.get_parent()
		while ancestor != null:
			if ancestor is CanvasLayer:
				ancestor.visible = true
			ancestor = ancestor.get_parent()
		probe.world.pause_menu.set_open(true)
		probe.world.pause_menu._on_options()
		for panel: Node in probe.world.pause_menu.find_children("*", "", true, false):
			if panel is OptionsPanel:
				panel._select_tab(OptionsPanel.TABS.find("GRAPHICS"))
		for frame in 8:
			await probe.get_tree().process_frame
		await _shot(probe, "settings_machine_distance")
		return
	if "--machine-range-only" in ua:
		await _measure_ranges(probe)
		return
	if "--material-share-only" in ua:
		await _measure_materials(probe, rows)
		return
	var at:= ua.find("--top-types")
	if at >= 0 and at + 1 < ua.size():
		limit = maxi(1, int(ua [at + 1]))
	var measured:= 0
	for row: Dictionary in rows:
		if "--distance-only" in ua:
			break
		if row ["type"] in UTILITIES:
			continue
		var roots: Array = row ["roots"]
		await probe._row("%s hidden (%d)" % [row ["type"], roots.size()], func() -> void:
			probe._hide_all(roots))
		await probe._row("everything on (%s control)" % row ["type"], func() -> void: pass)
		measured += 1
		if measured >= limit:
			break
	var machines: Array = []
	for row: Dictionary in rows:
		if not row ["type"] in STRUCTURES and not row ["type"] in UTILITIES:
			machines.append_array(row ["roots"])
	var pairs:= 1
	at = ua.find("--distance-pairs")
	if at >= 0 and at + 1 < ua.size():
		pairs = maxi(1, int(ua [at + 1]))
	await _shot(probe, "all")
	for pair in pairs:
		for cutoff in [40.0, 60.0, 80.0, 120.0]:
			var distant: Array = []
			for root: Node3D in machines:
				if root.global_position.distance_to(probe._cam.global_position) > cutoff:
					distant.append(root)
			await probe._row("machines beyond %.0f m hidden (%d), pair %d" % [cutoff, distant.size(), pair + 1], func() -> void:
				probe._hide_all(distant))
			if pair == 0:
				await _shot(probe, "cutoff_%d" % int(cutoff))
			await probe._row("everything on (%.0f m control, pair %d)" % [cutoff, pair + 1], func() -> void: pass)


func _shot(probe: Node, label: String) -> void:
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--census-shots")
	if at < 0 or at + 1 >= ua.size():
		return
	var directory:= ProjectSettings.globalize_path(ua [at + 1]).replace("\\", "/").simplify_path()
	var scratch:= ProjectSettings.globalize_path("res://.scratchpad/").replace("\\", "/")
	assert (directory.to_lower().begins_with(scratch.to_lower()), "census screenshots belong in the project scratchpad")
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	probe.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [directory, label])


func _measure_materials(probe: Node, rows: Array [Dictionary]) -> void:
	var bodies: Array [MeshInstance3D] = []
	for row: Dictionary in rows:
		if row ["type"] != "hay_pulper":
			continue
		for root: Node3D in row ["roots"]:
			var body:= root.find_child("HayPulperBody", true, false) as MeshInstance3D
			if body != null:
				bodies.append(body)
	var shared: Dictionary = { }
	var changes: Array [Dictionary] = []
	for body: MeshInstance3D in bodies:
		for surface in body.mesh.get_surface_count():
			var source:= body.mesh.surface_get_material(surface)
			var key:= source.resource_name if source != null else ""
			if key.is_empty() or key in ["M_PU_LampGo", "HD_PU_Glass", "M_PU_Belt"]:
				continue
			var material:= body.get_active_material(surface)
			if not shared.has(key):
				shared [key] = material
			elif material != shared [key] and _same_material(material, shared [key]):
				changes.append({ "body": body, "surface": surface,
					"original": body.get_surface_override_material(surface), "shared": shared [key] })
	print("MATERIAL_SHARE_TEST: %d bodies, %d immutable keys, %d equivalent overrides" % [bodies.size(), shared.size(), changes.size()])
	await probe._row("original pulper materials (control)", func() -> void: pass)
	await _shot(probe, "materials_original")
	for pair in 2:
		await probe._row("shared immutable pulper materials, pair %d" % [pair + 1], func() -> void:
			for entry: Dictionary in changes:
				entry ["body"].set_surface_override_material(entry ["surface"], entry ["shared"]))
		if pair == 0:
			await _shot(probe, "materials_shared")
		for entry: Dictionary in changes:
			entry ["body"].set_surface_override_material(entry ["surface"], entry ["original"])
		await probe._row("original pulper materials (control %d)" % [pair + 1], func() -> void: pass)


func _same_material(a: Material, b: Material) -> bool:
	if a == null or b == null or a.get_class() != b.get_class():
		return false
	for property: Dictionary in a.get_property_list():
		var key: String = property ["name"]
		if (int(property ["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or key.begins_with("resource_"):
			continue
		if a.get(key) != b.get(key):
			if not _differences.has(a.resource_name):
				_differences [a.resource_name] = true
				print("MATERIAL_SHARE_DIFFERENCE: %s, %s, %s, %s" % [a.resource_name, key, str(a.get(key)), str(b.get(key))])
			return false
	return true


func _measure_ranges(probe: Node) -> void:
	var manager:= probe.world.get_node("MachineDrawDistance") as MachineDrawDistance
	var saved: int = Cfg.gfx ["machine_distance"]
	await probe._row("machine distance Unlimited (control)", func() -> void:
		Cfg.gfx ["machine_distance"] = 6
		manager._refresh())
	await _shot(probe, "range_unlimited")
	for pair in 2:
		for index in [0, 1]:
			var metres: float = Cfg.MACHINE_DISTANCE_METRES [index]
			await probe._row("machine distance %.0f m, pair %d" % [metres, pair + 1], func() -> void:
				Cfg.gfx ["machine_distance"] = index
				manager._refresh())
			if pair == 0:
				await _shot(probe, "range_%d" % int(metres))
			await probe._row("machine distance Unlimited (%.0f m control, pair %d)" % [metres, pair + 1], func() -> void:
				Cfg.gfx ["machine_distance"] = 6
				manager._refresh())
	Cfg.gfx ["machine_distance"] = saved
	manager._refresh()


func _measure_fog(probe: Node) -> void:
	var saved_distance: int = Cfg.gfx ["machine_distance"]
	var saved_fog: bool = Cfg.gfx ["fog"]
	var manager:= probe.world.get_node("MachineDrawDistance") as MachineDrawDistance
	Cfg.gfx ["machine_distance"] = 1
	for pair in 2:
		await probe._row("60 m, depth fog off, pair %d" % [pair + 1], func() -> void:
			Cfg.gfx ["fog"] = false
			probe.world._apply_render_settings()
			manager._refresh())
		if pair == 0:
			await _shot(probe, "fog_off")
		await probe._row("60 m, distance fog on, pair %d" % [pair + 1], func() -> void:
			Cfg.gfx ["fog"] = true
			probe.world._apply_render_settings()
			manager._refresh())
		if pair == 0:
			await _shot(probe, "fog_on")
		await probe._row("60 m, depth fog off control, pair %d" % [pair + 1], func() -> void:
			Cfg.gfx ["fog"] = false
			probe.world._apply_render_settings()
			manager._refresh())
	Cfg.gfx ["fog"] = true
	probe.world._apply_render_settings()
	manager._refresh()
	var camera_transform: Transform3D = probe._cam.global_transform
	probe._cam.global_position = Vector3(-12, 6, 12)
	probe._cam.look_at(Vector3(12, 6, 0))
	for frame in 12:
		await probe.get_tree().process_frame
	await _shot(probe, "fog_inside")
	probe._cam.global_transform = camera_transform
	Cfg.gfx ["machine_distance"] = saved_distance
	Cfg.gfx ["fog"] = saved_fog
	probe.world._apply_render_settings()
	manager._refresh()
