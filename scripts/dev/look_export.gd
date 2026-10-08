class_name DevLookExport
extends Node


const LOOK_DIR:= "res://scenes/look"
const ENV_PATH:= "res://scenes/look/yard_environment.tres"
const LOOK_PATH:= "res://scenes/look/yard_look.tscn"
const GEO_PATH:= "res://scenes/dev/look_mockup_geo.scn"
const MOCKUP_PATH:= "res://scenes/dev/look_mockup.tscn"
const LOOK_SCRIPT:= "res://scripts/world/yard_look.gd"
const ROOM_SCRIPT:= "res://scripts/world/look_editor_room.gd"


const CAM_EYE:= Vector3(13.2, 1.8, 6.4)
const CAM_AIM:= Vector3(0.0, 3.2, 0.0)


const CRUST_CHUNKS:= 6


const SHELL_MAX_INSTANCES:= 64


const SETTLE_FRAMES:= 180

var world: Node3D

var _force:= false


func run() -> void:
	_force = "--force" in OS.get_cmdline_user_args()

	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== look export ===")


	_dump_look()
	if FileAccess.file_exists(ENV_PATH) and not _force:
		print("  %s exists, leaving the look alone (--force to overwrite)"
			% ENV_PATH)
	else:
		_save_environment()
		_save_look_scene()
	_save_geometry()
	_save_mockup()
	print("=== done ===\n")
	get_tree().quit()


func _env() -> Environment:
	return (world.get_node("Environment") as WorldEnvironment).environment


func _save_environment() -> void:
	DirAccess.make_dir_recursive_absolute(LOOK_DIR)
	var e:= _env()


	e.resource_path = ENV_PATH
	e.resource_name = "YardEnvironment"
	var err:= ResourceSaver.save(e, ENV_PATH)
	print("  %s  %s" % [ENV_PATH, error_string(err)])


func _save_look_scene() -> void:
	var root:= Node3D.new()
	root.name = "YardLook"
	root.set_script(load(LOOK_SCRIPT))


	var we:= WorldEnvironment.new()
	we.name = "Environment"
	we.environment = load(ENV_PATH)
	root.add_child(we)
	we.owner = root

	for name_ in ["Sun", "BounceFill", "SkyFill"]:
		var src:= world.get_node_or_null(NodePath(name_)) as Node3D
		if src == null:
			push_warning("look export: no %s in the world" % name_)
			continue
		var copy:= src.duplicate() as Node3D
		copy.name = name_
		root.add_child(copy)
		copy.owner = root


	var room:= Node3D.new()
	room.name = "EditorRoom"
	room.set_script(load(ROOM_SCRIPT))
	root.add_child(room)
	room.owner = root

	var packed:= PackedScene.new()
	packed.pack(root)
	var err:= ResourceSaver.save(packed, LOOK_PATH)
	print("  %s  %s" % [LOOK_PATH, error_string(err)])
	root.free()


func _dump_look() -> void:
	var e:= _env()
	var sun:= world.get_node("Sun") as DirectionalLight3D
	var fill:= world.get_node("BounceFill") as DirectionalLight3D
	print("  -- sun")
	print("     basis      %s" % sun.global_transform.basis)
	print("     origin     %s" % sun.global_position)
	print("     energy %.4f  colour %s  angular %.3f" % [
		sun.light_energy, sun.light_color, sun.light_angular_distance])
	print("     shadow %s  max %.2f  splits %.3f/%.3f/%.3f  bias %.4f/%.4f" % [
		sun.shadow_enabled, sun.directional_shadow_max_distance,
		sun.directional_shadow_split_1, sun.directional_shadow_split_2,
		sun.directional_shadow_split_3, sun.shadow_bias, sun.shadow_normal_bias])
	print("  -- fill")
	print("     basis      %s" % fill.global_transform.basis)
	print("     energy %.4f  colour %s  spec %.2f" % [
		fill.light_energy, fill.light_color, fill.light_specular])
	print("  -- environment")
	print("     ambient  src %d  sky %.4f  col %s  energy %.4f" % [
		e.ambient_light_source, e.ambient_light_sky_contribution,
		e.ambient_light_color, e.ambient_light_energy])
	print("     tonemap  mode %d  exposure %.4f  white %.4f" % [
		e.tonemap_mode, e.tonemap_exposure, e.tonemap_white])
	print("     glow     %.4f bloom %.4f thr %.4f scale %.4f blend %d" % [
		e.glow_intensity, e.glow_bloom, e.glow_hdr_threshold,
		e.glow_hdr_scale, e.glow_blend_mode])
	var levels:= PackedStringArray()
	for i in 7:
		levels.append("%.2f" % e.get_glow_level(i))
	print("     glow lv  %s" % ", ".join(levels))
	print("     ssao     r %.3f i %.3f p %.3f detail %.3f horizon %.4f" % [
		e.ssao_radius, e.ssao_intensity, e.ssao_power,
		e.ssao_detail, e.ssao_horizon])
	print("     ssil     r %.3f i %.3f sharp %.3f reject %.3f" % [
		e.ssil_radius, e.ssil_intensity, e.ssil_sharpness,
		e.ssil_normal_rejection])
	print("     vfog     d %.5f len %.2f aniso %.3f albedo %s inject %.3f" % [
		e.volumetric_fog_density, e.volumetric_fog_length,
		e.volumetric_fog_anisotropy, e.volumetric_fog_albedo,
		e.volumetric_fog_ambient_inject])
	print("     fog      d %.5f aerial %.3f scatter %.3f col %s" % [
		e.fog_density, e.fog_aerial_perspective, e.fog_sun_scatter,
		e.fog_light_color])
	print("     adjust   contrast %.4f sat %.4f bright %.4f lut %s" % [
		e.adjustment_contrast, e.adjustment_saturation,
		e.adjustment_brightness, e.adjustment_color_correction != null])


func _is_junk(n: Node) -> bool:
	return n is CollisionObject3D or n is CollisionShape3D or n is OccluderInstance3D or n is AudioStreamPlayer3D or n is Camera3D or n is Light3D or n is WorldEnvironment or n is GPUParticles3D or n is CPUParticles3D


func _copy_visuals(src: Node, into: Node3D, owner_of: Node3D) -> void:
	for child in src.get_children():
		if _is_junk(child):
			continue
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			var leaf:= (child as Node3D).duplicate(0) as Node3D
			for grand in leaf.get_children():
				grand.free()
			into.add_child(leaf)
			leaf.owner = owner_of
			continue
		if child is Node3D:
			var group:= Node3D.new()
			group.name = child.name
			group.transform = (child as Node3D).transform
			group.visible = (child as Node3D).visible
			into.add_child(group)
			group.owner = owner_of
			_copy_visuals(child, group, owner_of)
			if group.get_child_count() == 0:
				group.free()


func _save_geometry() -> void:
	var root:= Node3D.new()
	root.name = "LookMockupGeo"

	for name_ in ["Warehouse", "BayDoor", "YardGround"]:
		var src:= world.get_node_or_null(NodePath(name_))
		if src == null:
			continue
		var group:= Node3D.new()
		group.name = name_
		if src is Node3D:
			group.transform = (src as Node3D).transform
		root.add_child(group)
		group.owner = root
		_copy_visuals(src, group, root)

	_copy_pile(root)

	var packed:= PackedScene.new()
	packed.pack(root)
	var err:= ResourceSaver.save(packed, GEO_PATH)
	print("  %s  %s  (%d nodes)" % [GEO_PATH, error_string(err),
		_count(root)])


	for group in root.get_children():
		print("     %-16s %4d nodes  %3d meshes" % [group.name,
			_count(group), _count_drawn(group)])
	root.free()


func _copy_pile(root: Node3D) -> void:
	var field:= world.get("field") as Node3D
	if field == null:
		push_warning("look export: no hay field to bake")
		return
	var chunks: Array = field.get("chunks")
	if chunks == null or chunks.is_empty():
		push_warning("look export: the field has no chunks")
		return

	var order: Array [int] = []
	for i in chunks.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return (chunks [a] as Node3D).global_position.distance_squared_to(CAM_EYE) < (chunks [b] as Node3D).global_position.distance_squared_to(CAM_EYE))
	var with_crust:= { }
	for i in mini(CRUST_CHUNKS, order.size()):
		with_crust [order [i]] = true

	var pile:= Node3D.new()
	pile.name = "Pile"
	root.add_child(pile)
	pile.owner = root

	var strands:= 0
	for i in chunks.size():
		var chunk:= chunks [i] as Node3D
		var group:= Node3D.new()
		group.name = "Chunk%d" % i
		group.transform = chunk.transform
		pile.add_child(group)
		group.owner = root
		for child in chunk.get_children():
			if _is_junk(child):
				continue
			if child is MultiMeshInstance3D:
				var mmi:= child as MultiMeshInstance3D
				if mmi.multimesh == null:
					continue
				var is_shell:= mmi.multimesh.instance_count <= SHELL_MAX_INSTANCES
				if not is_shell and not with_crust.has(i):
					continue
				if not is_shell:
					strands += mmi.multimesh.visible_instance_count
			elif not (child is MeshInstance3D):
				continue
			var leaf:= (child as Node3D).duplicate(0) as Node3D
			group.add_child(leaf)
			leaf.owner = root
		if group.get_child_count() == 0:
			group.free()
	print("  pile: %d chunks, crust on %d of them (%d strands)" % [
		chunks.size(), with_crust.size(), strands])


func _save_mockup() -> void:
	var root:= Node3D.new()
	root.name = "LookMockup"

	var look:= (load(LOOK_PATH) as PackedScene).instantiate()
	root.add_child(look)
	look.owner = root

	var geo:= (load(GEO_PATH) as PackedScene).instantiate()
	root.add_child(geo)
	geo.owner = root

	var cam:= Camera3D.new()
	cam.name = "PreviewCam"
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 400.0
	root.add_child(cam)
	cam.owner = root
	cam.look_at_from_position(CAM_EYE, CAM_AIM, Vector3.UP)

	var packed:= PackedScene.new()
	packed.pack(root)
	var err:= ResourceSaver.save(packed, MOCKUP_PATH)
	print("  %s  %s" % [MOCKUP_PATH, error_string(err)])
	root.free()


func _count(n: Node) -> int:
	var total:= 1
	for c in n.get_children():
		total += _count(c)
	return total


func _count_drawn(n: Node) -> int:
	var total:= 1 if (n is MeshInstance3D or n is MultiMeshInstance3D) else 0
	for c in n.get_children():
		total += _count_drawn(c)
	return total
