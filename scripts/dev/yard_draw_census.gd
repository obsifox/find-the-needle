extends RefCounted


func run(probe: Node) -> void:
	var cam: Camera3D = probe._cam
	var planes: Array [Plane] = cam.get_frustum()
	var eye:= cam.global_position
	var placed:= { }
	for root: Node3D in probe.world.builds.every_placed():
		placed [root.get_instance_id()] = root
	var rows:= { }
	var total:= { "objects": 0, "surfaces": 0, "skinned": 0 }
	var all_pairs:= { }
	var by_class:= { }
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var g:= node as GeometryInstance3D
		if g == null or not g.is_visible_in_tree() or (g.layers & cam.cull_mask) == 0:
			continue
		var box:= g.global_transform * g.get_aabb()
		if _outside(box, planes):
			continue
		var d:= eye.distance_to(box.get_center())
		if g.visibility_range_begin > 0.0 and d < g.visibility_range_begin:
			continue
		if g.visibility_range_end > 0.0 and d >= g.visibility_range_end:
			continue
		var key:= _owner_key(g, placed, probe.world)
		if not rows.has(key):
			rows [key] = { "objects": 0, "surfaces": 0, "pairs": { } }
		var row: Dictionary = rows [key]
		row ["objects"] += 1
		total ["objects"] += 1
		by_class [g.get_class()] = int(by_class.get(g.get_class(), 0)) + 1
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			if (g as MeshInstance3D).skin != null or (g as MeshInstance3D).skeleton != NodePath(""):
				total ["skinned"] += 1
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			row ["surfaces"] += 1
			total ["surfaces"] += 1
			continue
		for s in mesh.get_surface_count():
			var mat: Material = g.material_override
			if mat == null and g is MeshInstance3D:
				mat = (g as MeshInstance3D).get_active_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var pair:= "%d/%d/%d" % [mesh.get_rid().get_id(), s,
				mat.get_rid().get_id() if mat != null else 0]
			row ["surfaces"] += 1
			total ["surfaces"] += 1
			(row ["pairs"] as Dictionary) [pair] = true
			all_pairs [pair] = true
	var keys:= rows.keys()
	keys.sort_custom(func(a, b) -> bool: return rows [a] ["surfaces"] > rows [b] ["surfaces"])


	var empties:= { }
	var st: Array [Node] = [probe.world]
	while not st.is_empty():
		var nd: Node = st.pop_back()
		for ch: Node in nd.get_children():
			st.append(ch)
		var mmi:= nd as MultiMeshInstance3D
		if mmi == null or not mmi.is_visible_in_tree() or mmi.multimesh == null:
			continue
		var mm:= mmi.multimesh
		var shown:= mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		var ek:= _owner_key(mmi, placed, probe.world)
		if not empties.has(ek):
			empties [ek] = [0, 0]
		empties [ek] [1] += 1
		if shown == 0:
			empties [ek] [0] += 1
	print("\n--- visible MultiMeshes over the whole world: empty / all, by owner ---")
	for ek: String in empties:
		if empties [ek] [0] > 0 or empties [ek] [1] > 50:
			print("  %-34s %6d / %6d" % [ek, empties [ek] [0], empties [ek] [1]])
	print("\n--- draw census: %d objects, %d surfaces, %d distinct mesh/material pairs, %d skinned ---"
		% [total ["objects"], total ["surfaces"], all_pairs.size(), total ["skinned"]])
	print("  %-34s %8s %9s %7s" % ["owner", "objects", "surfaces", "pairs"])
	for k: String in keys:
		var r: Dictionary = rows [k]
		print("  %-34s %8d %9d %7d" % [k, r ["objects"], r ["surfaces"], (r ["pairs"] as Dictionary).size()])
	var classes:= by_class.keys()
	classes.sort_custom(func(a, b) -> bool: return by_class [a] > by_class [b])
	for c: String in classes:
		print("  class %-28s %8d" % [c, by_class [c]])


func _outside(box: AABB, planes: Array [Plane]) -> bool:
	for p in planes:
		var all_over:= true
		for i in 8:
			if not p.is_point_over(box.get_endpoint(i)):
				all_over = false
				break
		if all_over:
			return true
	return false


func _owner_key(g: Node, placed: Dictionary, world: Node) -> String:
	var n: Node = g
	var top: Node = g
	while n != null:
		if placed.has(n.get_instance_id()):
			var sc:= n.get_script() as Script
			return "built " + (sc.resource_path.get_file().get_basename() if sc != null else n.get_class())
		if n.get_parent() == world:
			top = n
			break
		n = n.get_parent()
	if top.get_parent() != world:
		return "outside world"
	var sc2:= top.get_script() as Script
	return "world " + (str(top.name) if sc2 == null else sc2.resource_path.get_file().get_basename())


var _worn: Array = []


func share(probe: Node, on: bool) -> void:
	if not on:
		for w: Array in _worn:
			if is_instance_valid(w [0]):
				(w [0] as MeshInstance3D).set_surface_override_material(w [1], w [2])
		_worn.clear()
		return
	var first:= { }
	for root: Node3D in probe.world.builds.every_placed():
		var stack: Array [Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child: Node in node.get_children():
				stack.append(child)
			var mi:= node as MeshInstance3D
			if mi == null or mi.mesh == null or mi.material_override != null:
				continue
			for s in mi.mesh.get_surface_count():
				var key:= "%d/%d" % [mi.mesh.get_rid().get_id(), s]
				var mat:= mi.get_active_material(s)
				if not first.has(key):
					first [key] = mat
					continue
				if first [key] == mat:
					continue
				_worn.append([mi, s, mi.get_surface_override_material(s)])
				mi.set_surface_override_material(s, first [key])
	print("[sharedmats] %d surfaces moved onto a shared material" % _worn.size())


func processing(probe: Node) -> void:
	var rows:= { }
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var p:= node.is_processing()
		var pp:= node.is_physics_processing()
		var mixer:= node as AnimationMixer
		var anim:= mixer != null and mixer.active and (mixer is AnimationTree or (mixer as AnimationPlayer).is_playing())
		if not p and not pp and not anim:
			continue
		var sc:= node.get_script() as Script
		var key:= sc.resource_path.get_file().get_basename() if sc != null else node.get_class()
		if not rows.has(key):
			rows [key] = [0, 0, 0]
		if p:
			rows [key] [0] += 1
		if pp:
			rows [key] [1] += 1
		if anim:
			rows [key] [2] += 1
	var keys:= rows.keys()
	keys.sort_custom(func(a, b) -> bool:
		return rows [a] [0] + rows [a] [1] + rows [a] [2] > rows [b] [0] + rows [b] [1] + rows [b] [2])
	var tp:= 0
	var tpp:= 0
	var ta:= 0
	for k: String in keys:
		tp += rows [k] [0]
		tpp += rows [k] [1]
		ta += rows [k] [2]
	print("\n--- processing census: %d _process, %d _physics_process, %d playing mixers ---" % [tp, tpp, ta])
	print("  %-34s %8s %8s %8s" % ["script", "process", "physics", "mixers"])
	for k: String in keys.slice(0, 45):
		print("  %-34s %8d %8d %8d" % [k, rows [k] [0], rows [k] [1], rows [k] [2]])


var _emptied: Array [Node3D] = []


func hide_empty(probe: Node, on: bool) -> void:
	if not on:
		for n in _emptied:
			if is_instance_valid(n):
				n.visible = true
		_emptied.clear()
		return
	var total:= 0
	var stack: Array [Node] = [probe.world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var mmi:= node as MultiMeshInstance3D
		if mmi == null or not mmi.visible or mmi.multimesh == null:
			continue
		total += 1
		var mm:= mmi.multimesh
		var shown:= mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if shown == 0:
			mmi.visible = false
			_emptied.append(mmi)
	print("[emptymm] %d of %d visible MultiMeshes had nothing to draw" % [_emptied.size(), total])


func lights(probe: Node) -> void:
	var vp:= probe.get_viewport().get_viewport_rid()
	var info:= func(kind: int, what: int) -> int:
		return RenderingServer.viewport_get_render_info(vp, kind, what)
	print("\n--- render passes, this frame ---")
	print("  visible pass  draws %6d  objects %6d  primitives %9d" % [
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
	print("  shadow pass   draws %6d  objects %6d  primitives %9d" % [
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
	var cam: Camera3D = probe._cam
	var planes: Array [Plane] = cam.get_frustum()
	var placed:= { }
	for root: Node3D in probe.world.builds.every_placed():
		placed [root.get_instance_id()] = root


	var rows:= { }
	var other:= { }
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node is WorldEnvironment:
			other ["WorldEnvironment"] = int(other.get("WorldEnvironment", 0)) + 1
			continue
		if node is ReflectionProbe or node is Decal or node is FogVolume or node is VoxelGI or node is LightmapGI:
			if (node as Node3D).is_visible_in_tree():
				other [node.get_class()] = int(other.get(node.get_class(), 0)) + 1
			continue
		var light:= node as Light3D
		var g:= node as GeometryInstance3D
		if light == null and g == null:
			continue
		var key:= _owner_key(node, placed, probe.world)
		if not rows.has(key):
			rows [key] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
		var r: Array = rows [key]
		if light != null:
			if light is DirectionalLight3D:
				key = "sun " + str(light.name)
				if not rows.has(key):
					rows [key] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
				r = rows [key]
			r [0] += 1
			if not light.is_visible_in_tree() or light.light_energy <= 0.0:
				continue
			r [1] += 1
			if light.shadow_enabled:
				r [2] += 1
			if light.distance_fade_enabled:
				r [5] += 1
			var reach:= 0.0
			if light is OmniLight3D:
				reach = (light as OmniLight3D).omni_range
			elif light is SpotLight3D:
				reach = (light as SpotLight3D).spot_range
			var in_view:= light is DirectionalLight3D or _sphere_in(light.global_position, reach, planes)
			if in_view and light.distance_fade_enabled and cam.global_position.distance_to(light.global_position) > light.distance_fade_begin + light.distance_fade_length:
				in_view = false
			if in_view:
				r [3] += 1
				if light.shadow_enabled:
					r [4] += 1
			continue
		if not g.is_visible_in_tree():
			continue
		if g is GPUParticles3D or g is CPUParticles3D:
			if (g.get("emitting") as bool):
				r [8] += 1
			continue
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and g.layers != 0:
			r [6] += 1
			if not _outside(g.global_transform * g.get_aabb(), planes):
				r [7] += 1
	print("\n--- lights and shadow casters, by owner (whole world) ---")
	print("  %-30s %6s %5s %6s %6s %8s %6s %8s %8s %9s" % ["owner", "lights", "lit",
		"shadow", "inview", "shadowIV", "faded", "casters", "castIV", "emitting"])
	var keys:= rows.keys()
	keys.sort_custom(func(a, b) -> bool: return rows [a] [1] * 1000 + rows [a] [6] > rows [b] [1] * 1000 + rows [b] [6])
	var tot:= [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for k: String in keys:
		var r: Array = rows [k]
		for i in r.size():
			tot [i] += r [i]
		if r [0] == 0 and r [6] == 0 and r [8] == 0:
			continue
		print("  %-30s %6d %5d %6d %6d %8d %6d %8d %8d %9d" % [k, r [0], r [1], r [2], r [3], r [4], r [5], r [6], r [7], r [8]])
	print("  %-30s %6d %5d %6d %6d %8d %6d %8d %8d %9d" % ["TOTAL", tot [0], tot [1], tot [2], tot [3], tot [4], tot [5], tot [6], tot [7], tot [8]])
	print("  other: %s" % str(other))


func _sphere_in(c: Vector3, radius: float, planes: Array [Plane]) -> bool:
	for p in planes:
		if p.distance_to(c) > radius:
			return false
	return true


var _lamp_shadows: Array [Light3D] = []
var _lamps: Array [Light3D] = []
var _casters: Array = []


func _positional(probe: Node) -> Array [Light3D]:
	var out: Array [Light3D] = []
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var l:= node as Light3D
		if l != null and not l is DirectionalLight3D and l.is_visible_in_tree():
			out.append(l)
	return out


func lamp_shadows(probe: Node, on: bool) -> void:
	if not on:
		for l in _lamp_shadows:
			if is_instance_valid(l):
				l.shadow_enabled = true
		_lamp_shadows.clear()
		return
	for l in _positional(probe):
		if l.shadow_enabled:
			l.shadow_enabled = false
			_lamp_shadows.append(l)
	print("[lightpairs] %d lamp shadows off" % _lamp_shadows.size())


func lamps(probe: Node, on: bool) -> void:
	if not on:
		for l in _lamps:
			if is_instance_valid(l):
				l.visible = true
		_lamps.clear()
		return
	for l in _positional(probe):
		l.visible = false
		_lamps.append(l)
	print("[lightpairs] %d lamps off" % _lamps.size())


func casters(probe: Node, on: bool) -> void:
	if not on:
		for c: Array in _casters:
			if is_instance_valid(c [0]):
				(c [0] as GeometryInstance3D).cast_shadow = c [1]
		_casters.clear()
		return
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var g:= node as GeometryInstance3D
		if g != null and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_casters.append([g, g.cast_shadow])
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("[lightpairs] %d casters off" % _casters.size())


func shadowed_lamps(probe: Node) -> void:
	var placed:= { }
	for root: Node3D in probe.world.builds.every_placed():
		placed [root.get_instance_id()] = root
	var cam: Camera3D = probe._cam
	print("\n--- lamps casting their own shadow ---")
	for l in _positional(probe):
		if not l.shadow_enabled or l.light_energy <= 0.0:
			continue
		var reach: float = l.get("omni_range") if l is OmniLight3D else l.get("spot_range")
		print("  %-28s %-12s %-40s range %5.1f  dist %5.1f  fade %s  bake %d  mode %s"
			% [_owner_key(l, placed, probe.world), l.get_class(), str(l.get_path()).right(40), reach,
				cam.global_position.distance_to(l.global_position),
				str(l.distance_fade_enabled), l.light_bake_mode,
				str(l.get("omni_shadow_mode")) if l is OmniLight3D else "-"])


func viewports(probe: Node) -> void:
	print("\n--- sub viewports ---")
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var sv:= node as SubViewport
		if sv != null:
			var shown:= true
			var p:= sv.get_parent()
			if p is CanvasItem:
				shown = (p as CanvasItem).is_visible_in_tree()
			print("  %-60s size %s update %d own_world %s 3d_off %s parent_shown %s"
				% [str(sv.get_path()).right(60), str(sv.size), sv.render_target_update_mode,
					str(sv.own_world_3d), str(sv.disable_3d), str(shown)])
		var dl:= node as DirectionalLight3D
		if dl != null and dl.is_visible_in_tree() and dl.light_energy > 0.0:
			print("  sun %-56s energy %.2f shadow %s world %s" % [str(dl.get_path()).right(56),
				dl.light_energy, str(dl.shadow_enabled),
				"yard" if dl.get_world_3d() == probe.world.get_world_3d() else "own"])


func heavy_meshes(probe: Node) -> void:
	var cam: Camera3D = probe._cam
	var planes: Array [Plane] = cam.get_frustum()
	var placed:= { }
	for root: Node3D in probe.world.builds.every_placed():
		placed [root.get_instance_id()] = root
	var rows:= { }
	var stack: Array [Node] = [probe.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var g:= node as GeometryInstance3D
		if g == null or not g.is_visible_in_tree() or (g.layers & cam.cull_mask) == 0:
			continue
		if _outside(g.global_transform * g.get_aabb(), planes):
			continue
		var mesh: Mesh = null
		var count:= 1
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mm:= (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			count = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh == null or not mesh is ArrayMesh or count == 0:
			continue
		var am:= mesh as ArrayMesh
		var id:= am.get_rid().get_id()
		if not rows.has(id):


			var tris:= 0
			var big:= 0
			var lods:= 0
			var floor_tris:= 0
			for s in am.get_surface_count():
				var n:= am.surface_get_array_index_len(s)
				if n <= 0:
					n = am.surface_get_array_len(s)
				tris += n / 3
				if n / 3 <= big:
					continue
				big = n / 3
				var surf: Dictionary = RenderingServer.mesh_get_surface(am.get_rid(), s)
				var levels: Array = surf.get("lods", [])
				lods = levels.size()
				floor_tris = big
				var wide:= int(surf.get("vertex_count", 0)) > 65535
				for lv: Dictionary in levels:
					var bytes: PackedByteArray = lv.get("index_data", PackedByteArray())
					floor_tris = mini(floor_tris, bytes.size() / (4 if wide else 2) / 3)
			var src:= "import" if am.resource_path.contains(".glb") or am.resource_path.contains(".blend") or am.resource_path.contains(".scn") else "runtime"
			rows [id] = { "name": am.resource_name if am.resource_name != "" else str(am.resource_path.get_file()),
				"owner": _owner_key(g, placed, probe.world), "tris": tris, "lods": lods,
				"floor": floor_tris, "big": big, "src": src, "n": 0, "cast": 0 }
		rows [id] ["n"] += count
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			rows [id] ["cast"] += count
	var ids:= rows.keys()
	ids.sort_custom(func(a, b) -> bool: return rows [a] ["tris"] * rows [a] ["n"] > rows [b] ["tris"] * rows [b] ["n"])
	var total:= 0
	var no_lod:= 0
	for id in ids:
		total += rows [id] ["tris"] * rows [id] ["n"]
		if rows [id] ["lods"] == 0:
			no_lod += rows [id] ["tris"] * rows [id] ["n"]
	print("\n--- heaviest meshes in view at full detail: %d k triangles, %d k of them on meshes with no LOD ---"
		% [total / 1000, no_lod / 1000])
	print("  %-28s %-26s %8s %6s %5s %8s %9s %6s %s" % ["owner", "mesh", "tris", "drawn", "lods",
		"lowest", "k total", "cast", "src"])
	for id in ids.slice(0, 40):
		var r: Dictionary = rows [id]
		print("  %-28s %-26s %8d %6d %5d %8d %9d %6d %s" % [r ["owner"], str(r ["name"]).left(26), r ["tris"], r ["n"],
			r ["lods"], r ["floor"], r ["tris"] * r ["n"] / 1000, r ["cast"], r ["src"]])
