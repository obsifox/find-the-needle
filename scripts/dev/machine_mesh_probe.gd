extends SceneTree


const IMPORT_SCRIPT = preload("res://assets/models/lods/import.gd")
const MODELS:= ["briquette_press", "hay_pulper_reference", "borehole_pump", "hay_silo", "paper_machine", "feed_disc", "hay_pulp"]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.scratchpad/machine_opt"))
	var requested: Array [String] = []
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			requested.append(arg)
	for name in MODELS:
		if not requested.is_empty() and not name in requested:
			continue
		var path: String = "res://assets/models/" + name + ".glb"
		var scene: Node = load(path).instantiate()
		var rows:= []
		var manifest_path: String = "res://assets/models/lods/" + name + ".json"
		var verify:= not "--dump" in OS.get_cmdline_user_args()
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) if FileAccess.file_exists(manifest_path) else { }
		var source_hash:= FileAccess.get_sha256(path)
		var checked:= 0
		var changed:= 0
		var counts:= [0, 0, 0, 0]
		for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var m:= node.mesh as ArrayMesh
			if m == null: continue
			if name == "paper_machine" and node.name == "Wound_roll":
				var found:= false
				for shape in m.get_blend_shape_count():
					found = found or m.get_blend_shape_name(shape) == "Start_winding"
				if not found:
					push_error("Paper winding morph is missing")
					quit(1)
					return
			var row:= { "node": str(scene.get_path_to(node)), "mesh": m.resource_name, "surfaces": [] }
			for s in m.get_surface_count():
				var arrays:= m.surface_get_arrays(s)
				var pos: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
				var raw: Dictionary = m.get("_surfaces") [s]
				var lods: Array = RenderingServer.mesh_get_surface(m.get_rid(), s).get("lods", [])
				var totals:= [idx.size() / 3, idx.size() / 3, idx.size() / 3, idx.size() / 3]
				for lod: Dictionary in lods:
					var n: int = lod ["index_data"].size() / (2 if pos.size() <= 65536 else 4) / 3
					for i in range(1, 4):
						if float(lod ["edge_length"]) <= [0, 0.01, 0.025, 0.05] [i]: totals [i] = n
				for i in 4: counts [i] += totals [i]
				var sr:= { "fingerprint": IMPORT_SCRIPT.fingerprint(raw), "vertices": Marshalls.raw_to_base64(pos.to_byte_array()), "indices": Marshalls.raw_to_base64(idx.to_byte_array()), "existing": totals, "material": m.surface_get_material(s).resource_name if m.surface_get_material(s) else "" }


				if not verify and manifest.get("sha256", "") == source_hash:
					for prior: Dictionary in manifest.get("meshes", []):
						if prior ["node"] == row ["node"] and s < prior ["surfaces"].size():
							sr ["existing"] = prior ["surfaces"] [s] ["existing"]
				for slot in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
					if arrays [slot] != null: sr [str(slot)] = Marshalls.raw_to_base64(arrays [slot].to_byte_array())
				row ["surfaces"].append(sr)
			rows.append(row)
			if verify:
				var expected: Dictionary = { }
				for entry: Dictionary in manifest.get("meshes", []):
					if entry ["node"] == row ["node"]: expected = entry
				if expected.is_empty() or expected ["surfaces"].size() != row ["surfaces"].size():
					push_error("Missing LOD manifest mesh: " + row ["node"])
					quit(1)
					return
				for i in row ["surfaces"].size():
					if row ["surfaces"] [i] ["fingerprint"] != expected ["surfaces"] [i] ["fingerprint"] or row ["surfaces"] [i] ["material"] != expected ["surfaces"] [i] ["material"]:
						push_error("Close geometry changed: " + row ["node"])
						quit(1)
						return
					checked += 1
					for threshold in range(1, 4):
						if row ["surfaces"] [i] ["existing"] [threshold] < expected ["surfaces"] [i] ["existing"] [threshold]:
							changed += 1
							break
		if verify:
			if source_hash != manifest.get("sha256", "") or changed == 0:
				push_error("Stale or ineffective LODs: " + name)
				quit(1)
				return
			print("[machine meshes] PASS ", name, ": ", checked, " identical close surfaces; ", changed, " improved distance surfaces")
			print(name, " ", counts)
			scene.free()
			continue
		var f:= FileAccess.open("res://.scratchpad/machine_opt/" + name + "_arrays.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({ "source": path, "sha256": FileAccess.get_sha256(path), "meshes": rows }))
		print(name, " ", counts)
		scene.free()
	quit()
