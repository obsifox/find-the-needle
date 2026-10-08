extends SceneTree


const PALETTE = preload("res://assets/models/machine_palette.gd")
const FINGERPRINT = preload("res://assets/models/lods/import.gd")
var _failures:= 0
var _checks:= 0


func _initialize() -> void:
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--before")
	if at < 0 or at + 1 >= args.size():
		push_error("Palette probe needs --before pointing to a captured original PackedScene")
		quit(1)
		return
	var before: Node = load(args [at + 1]).instantiate()
	var after: Node = load("res://assets/models/hay_pulper_reference.glb").instantiate()
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/hay_pulper_reference_materials.json"))
	var key:= "MP_PU_StaticPalette"
	var entries: Array = spec ["palettes"] [key] ["entries"]
	for node in before.find_children("*", "", true, false):
		var path: NodePath = before.get_path_to(node)
		var other:= after.get_node_or_null(path)
		_check(other != null and other.get_class() == node.get_class(), "node contract: %s" % path)
		if other == null:
			continue
		if node is Node3D:
			_check(node.transform == other.transform, "unchanged transform: %s" % path)
		if node is AnimationPlayer:
			_check(node.get_animation_list() == other.get_animation_list(), "animation names")
			for clip: String in node.get_animation_list():
				_check(_animation(node.get_animation(clip)) == _animation(other.get_animation(clip)), "animation data: " + clip)
		if node is MeshInstance3D:
			if str(path) == "HayPulper/HayPulperBody":
				_check(node.mesh.get_surface_count() == 27 and other.mesh.get_surface_count() == 10, "body 27 surfaces to 10")
				_compare_body(node.mesh, other.mesh, entries, key)
			else:
				_check(_mesh_hashes(node.mesh) == _mesh_hashes(other.mesh), "unchanged mesh: %s" % path)
		if node is CollisionShape3D:
			_check(node.shape.get_class() == other.shape.get_class(), "collision type: %s" % path)
			if node.shape is ConvexPolygonShape3D:
				_check(node.shape.points == other.shape.points, "collision points: %s" % path)
	var material:= PALETTE.material(key, spec)
	_check(material == PALETTE.material(key, spec) and material.get_meta("palette_entries") == entries, "immutable material shared with its recorded palette layout")
	var image: Image = material.get_shader_parameter("palette").get_image()
	for i in entries.size():
		var flat: Dictionary = spec ["flats"] [entries [i]]
		var rgb: Array = flat ["color"]
		_check(image.get_pixel(i, 0).is_equal_approx(Color(rgb [0], rgb [1], rgb [2]).srgb_to_linear()), "palette colour: " + entries [i])
		_check(image.get_pixel(i, 1).is_equal_approx(Color(flat.get("metal", 0.0), flat.get("rough", 0.6), 0.4)), "palette finish: " + entries [i])
	PALETTE.apply(before, spec)
	_check(_mesh_hashes(before.get_node("HayPulper/HayPulperBody").mesh) == _mesh_hashes(after.get_node("HayPulper/HayPulperBody").mesh), "current merge step reproduces the imported buffers")
	before.free()
	after.free()
	print("[machine palette] %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _compare_body(before: ArrayMesh, after: ArrayMesh, entries: Array, key: String) -> void:
	var selected:= 0
	for s in before.get_surface_count():
		if before.surface_get_material(s).resource_name in entries:
			selected += 1
	_check(before.get_surface_count() - selected + 1 == after.get_surface_count(), "only selected surfaces merged")
	var merged:= -1
	for s in after.get_surface_count():
		if after.surface_get_material(s).resource_name == key:
			merged = s
	_check(merged >= 0 and after.surface_get_material(merged).get_meta("palette_entries", []) == entries, "palette surface present with the recorded layout")
	if merged < 0:
		return
	var arrays:= after.surface_get_arrays(merged)
	var vertices: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays [Mesh.ARRAY_NORMAL]
	var uv: Variant = arrays [Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays [Mesh.ARRAY_TEX_UV2]
	var indices: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
	var offset:= 0
	var index_offset:= 0
	var rows: Array [Dictionary] = []
	var edges: Array [float] = [0.0]
	for s in before.get_surface_count():
		var name:= before.surface_get_material(s).resource_name
		if not name in entries:
			var counterpart:= -1
			for t in after.get_surface_count():
				if after.surface_get_material(t).resource_name == name and FINGERPRINT.fingerprint(before.get("_surfaces") [s]) == FINGERPRINT.fingerprint(after.get("_surfaces") [t]):
					counterpart = t
			_check(counterpart >= 0, "exception retained: " + name)
			if counterpart >= 0:
				_check(FINGERPRINT.fingerprint(before.get("_surfaces") [s]) == FINGERPRINT.fingerprint(after.get("_surfaces") [counterpart]), "exact exception buffers: " + name)
			continue
		var original:= before.surface_get_arrays(s)
		var original_vertices: PackedVector3Array = original [Mesh.ARRAY_VERTEX]
		var original_indices: PackedInt32Array = original [Mesh.ARRAY_INDEX]
		var positions_equal:= true
		var normals_equal:= true
		var uv_equal:= true
		var cells_equal:= true
		for v in original_vertices.size():
			positions_equal = positions_equal and vertices [offset + v] == original_vertices [v]
			normals_equal = normals_equal and normals [offset + v].distance_to(original [Mesh.ARRAY_NORMAL] [v]) < 0.0002
			if original [Mesh.ARRAY_TEX_UV] != null:
				uv_equal = uv_equal and uv [offset + v] == original [Mesh.ARRAY_TEX_UV] [v]
			cells_equal = cells_equal and int(floor(uv2 [offset + v].x * entries.size())) == entries.find(name)
		_check(positions_equal, "exact published vertex positions: " + name)
		_check(normals_equal, "normal packing preserved: " + name)
		_check(uv_equal, "original texture UVs: " + name)
		_check(cells_equal, "face palette cells: " + name)
		for slot in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR]:
			if original [slot] == null:
				_check(arrays [slot] == null, "unchanged absent attribute %d: %s" % [slot, name])
				continue
			var stride:= 4 if slot == Mesh.ARRAY_TANGENT else 1
			var equal:= true
			for i in original [slot].size():
				if slot == Mesh.ARRAY_TANGENT:
					equal = equal and absf(arrays [slot] [offset * stride + i] - original [slot] [i]) < 0.0002
				else:
					equal = equal and arrays [slot] [offset + i].is_equal_approx(original [slot] [i])
			_check(equal, "published attribute %d retained: %s" % [slot, name])
		var triangles_equal:= true
		for i in original_indices.size():
			triangles_equal = triangles_equal and indices [index_offset + i] == original_indices [i] + offset
		_check(triangles_equal, "exact triangle order: " + name)
		var levels: Array = RenderingServer.mesh_get_surface(before.get_rid(), s).get("lods", [])
		for level: Dictionary in levels:
			if not float(level ["edge_length"]) in edges:
				edges.append(float(level ["edge_length"]))
		rows.append({ "surface": s, "offset": offset })
		offset += original_vertices.size()
		index_offset += original_indices.size()
	_check(offset == vertices.size() and index_offset == indices.size(), "all original vertices and triangles retained")
	for edge in edges:
		var expected:= PackedInt32Array()
		for row: Dictionary in rows:
			var source_indices:= _at_edge(before, row ["surface"], edge)
			for value in source_indices:
				expected.append(value + int(row ["offset"]))
		_check(expected == _at_edge(after, merged, edge), "exact LOD triangles at %.9f" % edge)


func _at_edge(mesh: ArrayMesh, surface: int, edge: float) -> PackedInt32Array:
	var arrays:= mesh.surface_get_arrays(surface)
	var result: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
	for level: Dictionary in RenderingServer.mesh_get_surface(mesh.get_rid(), surface).get("lods", []):
		if float(level ["edge_length"]) <= edge:
			var bytes: PackedByteArray = level ["index_data"]
			if arrays [Mesh.ARRAY_VERTEX].size() > 65536:
				result = bytes.to_int32_array()
			else:
				result = PackedInt32Array()
				for i in bytes.size() / 2:
					result.append(bytes.decode_u16(i * 2))
	return result


func _mesh_hashes(mesh: ArrayMesh) -> Array:
	var hashes:= []
	for surface: Dictionary in mesh.get("_surfaces"):
		hashes.append(FINGERPRINT.fingerprint(surface))
	return hashes


func _animation(animation: Animation) -> Array:
	var data:= [animation.length, animation.loop_mode]
	for track in animation.get_track_count():
		data.append([animation.track_get_type(track), animation.track_get_path(track), animation.track_get_interpolation_type(track)])
		for key in animation.track_get_key_count(track):
			data.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key), animation.track_get_key_transition(track, key)])
	return data


func _check(passed: bool, message: String) -> void:
	_checks += 1
	if not passed:
		_failures += 1
		push_error("[machine palette] FAIL: " + message)
