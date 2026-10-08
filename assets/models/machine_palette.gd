@tool
extends RefCounted


const SHADER = preload("res://assets/shaders/machine_palette.gdshader")
static var _materials: Dictionary = { }
static var _reported_stale: Dictionary = { }


static func validate_import(material: Material, spec: Dictionary) -> void:
	for key: String in material.get_meta("palette_spec_rows", { }):
		if material.get_meta("palette_spec_rows") [key] != spec.get("flats", { }).get(key, { }):
			var id:= material.get_instance_id()
			if not _reported_stale.has(id):
				_reported_stale [id] = true
				push_error("Machine palette material table changed; reimport the GLB before using its new finishes")
			return


static func apply_profile(scene: Node, spec: Dictionary, profile: Dictionary) -> void:
	if not profile.get("enabled", true):
		return
	var mode: String = profile ["finish_source"]
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node:= node as MeshInstance3D
		if not mesh_node.mesh is ArrayMesh or mesh_node.skin != null:
			continue
		var source:= mesh_node.mesh as ArrayMesh
		if source.get_blend_shape_count() > 0:
			continue
		var groups: Dictionary = { }
		var keys: Dictionary = { }
		var invalid_keys: Dictionary = { }
		for s in source.get_surface_count():
			var original:= source.surface_get_material(s) as StandardMaterial3D
			if original == null or original.resource_name in profile.get("excluded", []):
				continue
			var finish:= _finish(original, spec, mode)
			if finish.is_empty() or source.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				invalid_keys [original.resource_name] = true
				continue
			var arrays:= source.surface_get_arrays(s)
			if arrays [Mesh.ARRAY_TEX_UV2] != null or arrays [Mesh.ARRAY_BONES] != null or arrays [Mesh.ARRAY_WEIGHTS] != null:
				invalid_keys [original.resource_name] = true
				continue
			var custom_attributes:= false
			for slot in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				custom_attributes = custom_attributes or arrays [slot] != null
			if custom_attributes:
				invalid_keys [original.resource_name] = true
				continue
			var layout:= str(finish ["cull"])
			for slot in Mesh.ARRAY_MAX:
				if slot != Mesh.ARRAY_INDEX:
					layout += "1" if arrays [slot] != null else "0"
			var identity:= { "layout": layout, "finish": finish }
			if keys.has(original.resource_name) and keys [original.resource_name] != identity:
				invalid_keys [original.resource_name] = true
			keys [original.resource_name] = identity
			if not groups.has(layout):
				groups [layout] = { "entries": [], "finishes": [] }
			var group: Dictionary = groups [layout]
			if not original.resource_name in group ["entries"]:
				group ["entries"].append(original.resource_name)
				group ["finishes"].append(finish)
		for group: Dictionary in groups.values():
			for i in range(group ["entries"].size() - 1, -1, -1):
				if invalid_keys.has(group ["entries"] [i]):
					group ["entries"].remove_at(i)
					group ["finishes"].remove_at(i)
			if group ["entries"].size() < 2:
				continue
			var signature:= JSON.stringify(group)
			var key:= "MP_" + signature.sha256_text().left(16)
			var palette: ShaderMaterial = _materials.get(key)
			if palette == null:
				var entries: Array = group ["entries"]
				var image:= Image.create(entries.size(), 2, false, Image.FORMAT_RGBAF)
				for i in entries.size():
					var finish: Dictionary = group ["finishes"] [i]
					var rgb: Array = finish ["color"]
					image.set_pixel(i, 0, Color(rgb [0], rgb [1], rgb [2]))
					image.set_pixel(i, 1, Color(finish ["metal"], finish ["rough"], finish ["spec"]))
				palette = ShaderMaterial.new()
				palette.resource_name = key

				var local_shader:= Shader.new()
				local_shader.code = SHADER.code
				palette.shader = local_shader
				if group ["finishes"] [0] ["cull"] == BaseMaterial3D.CULL_DISABLED:
					var two_sided:= Shader.new()
					two_sided.code = SHADER.code.replace("cull_back", "cull_disabled")
					palette.shader = two_sided
				palette.set_shader_parameter("palette", ImageTexture.create_from_image(image))
				palette.set_meta("palette_entries", entries.duplicate())
				palette.set_meta("immutable_palette", true)
				palette.set_meta("palette_finishes", group ["finishes"].duplicate(true))
				var spec_rows:= { }
				for entry: String in entries:
					spec_rows [entry] = spec ["flats"] [entry].duplicate(true)
				palette.set_meta("palette_spec_rows", spec_rows)
				_materials [key] = palette
			var merged:= _merge(mesh_node.mesh, group ["entries"], palette)
			if merged != null:
				mesh_node.mesh = merged


static func _finish(original: StandardMaterial3D, spec: Dictionary, mode: String) -> Dictionary:
	var key:= original.resource_name
	if key.is_empty() or spec.get("surfaces", { }).has(key):
		return { }
	var row: Dictionary = spec.get("flats", { }).get(key, { })
	if row.is_empty() or row.get("alpha", 1.0) != 1.0 or row.get("emit", 0.0) != 0.0:
		return { }
	if mode != "imported":
		for property: String in row:
			if not property in ["color", "metal", "rough", "emit", "alpha", "spec", "linear_color"]:
				return { }
	var colour: Color
	var metal: float
	var rough: float
	var specular: float
	var cull:= BaseMaterial3D.CULL_BACK
	if mode == "imported":
		var defaults:= StandardMaterial3D.new()
		for property: Dictionary in original.get_property_list():
			var name: String = property ["name"]
			if property ["usage"] & PROPERTY_USAGE_STORAGE and not name in ["resource_name", "resource_path", "resource_local_to_scene", "albedo_color", "metallic", "roughness", "metallic_specular", "cull_mode"]:
				if original.get(name) != defaults.get(name):
					return { }
		if original.albedo_color.a != 1.0 or not original.cull_mode in [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_DISABLED]:
			return { }
		colour = original.albedo_color.srgb_to_linear()
		metal = original.metallic
		rough = original.roughness
		specular = original.metallic_specular
		cull = original.cull_mode
	else:
		var rgb: Array = row ["color"]
		colour = Color(rgb [0], rgb [1], rgb [2])
		if mode != "linear_table" and not row.get("linear_color", false):
			colour = colour.srgb_to_linear()
		metal = row.get("metal", 0.0)
		rough = row.get("rough", 0.6)
		specular = row.get("spec", 0.5) if mode == "linear_table" else 0.4
	return { "color": [colour.r, colour.g, colour.b], "metal": metal, "rough": rough, "spec": specular, "cull": cull }


static func material(key: String, spec: Dictionary) -> ShaderMaterial:
	var recipe: Dictionary = spec.get("palettes", { }).get(key, { })
	if recipe.is_empty():
		return null
	var cache_key:= key + JSON.stringify(recipe) + JSON.stringify(spec.get("flats", { }))
	if _materials.has(cache_key):
		return _materials [cache_key]
	var entries: Array = recipe ["entries"]
	if entries.size() < 2:
		push_error("Machine palette needs at least two finishes")
		return null
	for entry: String in entries:
		var finish: Dictionary = spec.get("flats", { }).get(entry, { })
		if finish.is_empty() or finish.get("alpha", 1.0) != 1.0 or finish.get("emit", 0.0) != 0.0:
			push_error("Machine palette finish changed and needs rebuilding: %s" % entry)
			return null
		for property: String in finish:
			if not property in ["color", "metal", "rough", "emit", "alpha"]:
				push_error("Machine palette does not support %s on %s" % [property, entry])
				return null
	var image:= Image.create(entries.size(), 2, false, Image.FORMAT_RGBAF)
	for i in entries.size():
		var finish: Dictionary = spec ["flats"] [entries [i]]
		var rgb: Array = finish ["color"]

		image.set_pixel(i, 0, Color(rgb [0], rgb [1], rgb [2]).srgb_to_linear())
		image.set_pixel(i, 1, Color(finish.get("metal", 0.0), finish.get("rough", 0.6), 0.4))
	var result:= ShaderMaterial.new()
	result.resource_name = key
	result.set_meta("palette_entries", entries.duplicate())

	var local_shader:= Shader.new()
	local_shader.code = SHADER.code
	result.shader = local_shader
	result.set_shader_parameter("palette", ImageTexture.create_from_image(image))
	_materials [cache_key] = result
	return result


static func apply(scene: Node, spec: Dictionary) -> void:
	for key: String in spec.get("palettes", { }):
		var recipe: Dictionary = spec ["palettes"] [key]
		for path: String in recipe ["nodes"]:
			var node:= scene.get_node_or_null(NodePath(path)) as MeshInstance3D
			if node == null or not node.mesh is ArrayMesh:
				push_error("Machine palette has no mesh at %s" % path)
				continue
			var finish:= material(key, spec)
			if finish == null:
				continue
			var merged:= _merge(node.mesh, recipe ["entries"], finish)
			if merged != null:
				node.mesh = merged


static func _indices(bytes: PackedByteArray, vertices: int) -> PackedInt32Array:
	if vertices > 65536:
		return bytes.to_int32_array()
	var result:= PackedInt32Array()
	result.resize(bytes.size() / 2)
	for i in result.size():
		result [i] = bytes.decode_u16(i * 2)
	return result


static func _merge(source: ArrayMesh, entries: Array, finish: Material) -> ArrayMesh:
	if source.get_blend_shape_count() != 0:
		push_error("Machine palette cannot merge a morph mesh")
		return null
	var selected: Array [int] = []
	var rows: Array [Dictionary] = []
	var edges: Array [float] = []
	var offset:= 0
	var seen: Dictionary = { }
	for s in source.get_surface_count():
		var original:= source.surface_get_material(s)
		if original == null or not original.resource_name in entries:
			continue
		seen [original.resource_name] = true
		if source.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			push_error("Machine palette requires triangle surfaces")
			return null
		var arrays:= source.surface_get_arrays(s)
		if arrays [Mesh.ARRAY_TEX_UV2] != null:
			push_error("Machine palette needs a free second UV channel")
			return null
		if arrays [Mesh.ARRAY_BONES] != null or arrays [Mesh.ARRAY_WEIGHTS] != null:
			push_error("Machine palette cannot merge a skinned surface")
			return null
		var vertices: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
		var levels: Array = RenderingServer.mesh_get_surface(source.get_rid(), s).get("lods", [])
		for level: Dictionary in levels:
			var edge:= float(level ["edge_length"])
			if not edge in edges:
				edges.append(edge)
		selected.append(s)
		rows.append({ "arrays": arrays, "levels": levels, "offset": offset,
			"cell": entries.find(original.resource_name), "vertices": vertices.size() })
		offset += vertices.size()
	if seen.size() != entries.size():
		push_error("Machine palette expected %d flat surfaces, found %d" % [entries.size(), selected.size()])
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	for slot in Mesh.ARRAY_MAX:
		if slot == Mesh.ARRAY_TEX_UV2 or slot == Mesh.ARRAY_INDEX:
			continue
		var joined: Variant = null
		var present: bool = rows [0] ["arrays"] [slot] != null
		for row: Dictionary in rows:
			var values: Variant = row ["arrays"] [slot]
			if (values != null) != present:
				push_error("Machine palette surfaces have incompatible vertex attributes")
				return null
			if values != null:
				if joined == null:
					joined = values.duplicate()
				else:
					joined.append_array(values)
		arrays [slot] = joined
	var uv:= PackedVector2Array()
	var indices:= PackedInt32Array()
	for row: Dictionary in rows:
		for v in int(row ["vertices"]):
			uv.append(Vector2((float(row ["cell"]) + 0.5) / entries.size(), 0.25))
		_append_indices(indices, row ["arrays"] [Mesh.ARRAY_INDEX], row ["offset"])
	arrays [Mesh.ARRAY_TEX_UV2] = uv
	arrays [Mesh.ARRAY_INDEX] = indices

	edges.sort()
	var lods: Dictionary = { }
	for edge: float in edges:
		var combined:= PackedInt32Array()
		for row: Dictionary in rows:
			var current: PackedInt32Array = row ["arrays"] [Mesh.ARRAY_INDEX]
			for level: Dictionary in row ["levels"]:
				if float(level ["edge_length"]) <= edge:
					current = _indices(level ["index_data"], row ["vertices"])
			_append_indices(combined, current, row ["offset"])
		lods [edge] = combined
	var joined:= ArrayMesh.new()
	joined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	joined.surface_set_material(0, finish)
	var combined_surface: Dictionary = joined.get("_surfaces") [0]
	var original_surfaces: Array = source.get("_surfaces")
	var kept: Array = []
	for s in source.get_surface_count():
		if s == selected [0]:
			kept.append(combined_surface)
		elif not s in selected:

			kept.append(original_surfaces [s])
	var result:= ArrayMesh.new()
	result.set("_surfaces", kept)
	result.resource_name = source.resource_name
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = null
	print("[machine palette] %s: %d surfaces to %d, %d vertices retained" %
		[source.resource_name, source.get_surface_count(), result.get_surface_count(), offset])
	return result


static func _append_indices(target: PackedInt32Array, values: PackedInt32Array, offset: int) -> void:
	for value in values:
		target.append(value + offset)
