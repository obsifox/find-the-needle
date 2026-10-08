extends SceneTree


const MODEL_DIRS:= ["res://assets/models", "res://assets/terrain/flora", "res://"]
const SUFFIXES:= [".glb", ".tscn", ".scn"]


func _init() -> void:
	var rows: Array [Dictionary] = []
	for dir_path in MODEL_DIRS:
		for file in _scenes_in(dir_path):
			var row:= _measure(file)
			if not row.is_empty():
				rows.append(row)

	rows.sort_custom(func(a, b): return int(a ["tris"]) > int(b ["tris"]))

	var total_tris:= 0
	var total_surf:= 0
	print("\n=== every model, heaviest first ===\n")
	print("  %-30s %10s %9s %8s %10s   %s"
		% ["model", "triangles", "surfaces", "meshes", "tris/surf",
			"heaviest single node"])
	for r in rows:
		total_tris += int(r ["tris"])
		total_surf += int(r ["surfaces"])
		var per:= 0
		if int(r ["surfaces"]) > 0:
			per = int(r ["tris"]) / int(r ["surfaces"])
		print("  %-30s %10d %9d %8d %10d   %s (%d)"
			% [r ["name"], r ["tris"], r ["surfaces"], r ["meshes"], per,
				r ["heaviest_name"], r ["heaviest"]])
	print("\n  %-30s %10d %9d over %d models"
		% ["TOTAL", total_tris, total_surf, rows.size()])


	rows.sort_custom(func(a, b): return int(a ["surfaces"]) > int(b ["surfaces"]))
	print("\n=== the same models by surfaces, which is draw calls ===\n")
	for i in mini(15, rows.size()):
		var r: Dictionary = rows [i]
		print("  %-30s %4d surfaces, %8d tris"
			% [r ["name"], r ["surfaces"], r ["tris"]])


	var pieces: Array [Dictionary] = []
	for r in rows:
		for piece: Dictionary in (r ["nodes"] as Array):
			if int(piece ["tris"]) >= 200:
				pieces.append(piece)
	pieces.sort_custom(func(a, b): return int(a ["tris"]) > int(b ["tris"]))
	print("\n=== every mesh node over 200 triangles, heaviest first ===\n")
	for piece: Dictionary in pieces:
		print("  %-34s %8d tris %3d surf   in %s"
			% [piece ["name"], piece ["tris"], piece ["surfaces"], piece ["file"]])

	print("\n[modelaudit] done")
	quit(0)


func _scenes_in(dir_path: String) -> Array [String]:
	var out: Array [String] = []
	var d:= DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f:= d.get_next()
	while f != "":
		if not d.current_is_dir():
			for suffix in SUFFIXES:
				if f.ends_with(suffix):
					out.append("%s/%s" % [dir_path, f])
					break
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func _measure(path: String) -> Dictionary:
	var res:= load(path)
	if res == null or not (res is PackedScene):
		return { }
	var root: Node = (res as PackedScene).instantiate()
	if root == null:
		return { }
	var meshes:= 0
	var surfaces:= 0
	var tris:= 0
	var heaviest:= 0
	var heaviest_name:= ""
	var nodes: Array [Dictionary] = []
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			if m != null:
				meshes += 1
				surfaces += m.get_surface_count()
				var t: int = m.get_faces().size() / 3
				tris += t


				if t > heaviest:
					heaviest = t
					heaviest_name = String(n.name)
				nodes.append({ "name": String(n.name), "tris": t,
					"surfaces": m.get_surface_count(), "file": path.get_file() })
		elif n is MultiMeshInstance3D:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				meshes += 1
				surfaces += mm.mesh.get_surface_count()


				tris += mm.mesh.get_faces().size() / 3
	root.free()
	return {
		"name": path.get_file(),
		"tris": tris,
		"surfaces": surfaces,
		"meshes": meshes,
		"heaviest": heaviest,
		"heaviest_name": heaviest_name,
		"nodes": nodes,
	}
