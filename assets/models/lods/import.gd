@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	var source:= get_source_file()
	var manifest_path:= "res://assets/models/lods/%s.json" % source.get_file().get_basename()
	if not FileAccess.file_exists(manifest_path):
		return scene
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if data.get("sha256", "") != FileAccess.get_sha256(source):
		push_warning("Model LODs need rebuilding for %s; keeping the regular import." % source)
		return scene
	var updated:= 0
	for entry: Dictionary in data.get("meshes", []):
		var node:= scene.get_node_or_null(NodePath(entry ["node"])) as MeshInstance3D
		if node == null or not node.mesh is ArrayMesh:
			continue
		var original:= node.mesh as ArrayMesh
		if original.get_blend_shape_count() > 0:
			continue
		var surfaces: Array = original.get("_surfaces")
		if surfaces.size() != entry ["surfaces"].size():
			continue
		var valid:= true
		for i in surfaces.size():
			if fingerprint(surfaces [i]) != entry ["surfaces"] [i] ["fingerprint"]:
				valid = false
		if not valid:
			push_warning("Model LOD vertex layout changed on %s; rebuild its LODs." % entry ["node"])
			continue
		for i in surfaces.size():
			var levels: Array = RenderingServer.mesh_get_surface(original.get_rid(), i).get("lods", []).duplicate(true)
			for level: Dictionary in entry ["surfaces"] [i].get("levels", []):
				levels.append({ "edge_length": float(level ["edge_length"]),
					"index_data": Marshalls.base64_to_raw(level ["indices"]) })
			levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a ["edge_length"]) < float(b ["edge_length"]))
			var kept: Array = []
			var smallest: int = surfaces [i] ["index_data"].size()
			for level: Dictionary in levels:
				var bytes: PackedByteArray = level ["index_data"]
				if bytes.size() < smallest:
					kept.append(float(level ["edge_length"]))
					kept.append(bytes)
					smallest = bytes.size()
			surfaces [i] ["lods"] = kept
		var replacement:= ArrayMesh.new()
		replacement.set("_surfaces", surfaces)
		replacement.resource_name = original.resource_name
		replacement.custom_aabb = original.custom_aabb


		replacement.shadow_mesh = null
		node.mesh = replacement
		updated += 1
	print("[model LODs] %s: %d meshes, original close geometry retained" % [source.get_file(), updated])
	return scene


static func fingerprint(surface: Dictionary) -> String:
	var hash:= HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for key in ["vertex_data", "attribute_data", "skin_data", "index_data"]:
		var bytes: PackedByteArray = surface.get(key, PackedByteArray())
		if not bytes.is_empty():
			hash.update(bytes)
	return hash.finish().hex_encode()
