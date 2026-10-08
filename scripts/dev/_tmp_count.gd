extends SceneTree
func _init() -> void:
	for f in ["tree", "hedge_bush", "grass_tuft"]:
		var ps: PackedScene = load("res://assets/terrain/flora/%s.tscn" % f)
		if ps == null:
			print(f, ": will not load"); continue
		var root:= ps.instantiate()
		var total:= 0
		var lines: Array [String] = []
		for n in _walk(root):
			var mi:= n as MeshInstance3D
			var m: Mesh = mi.mesh
			if m == null: continue
			var t:= 0
			for s in m.get_surface_count():
				var a:= m.surface_get_arrays(s)
				var idx: PackedInt32Array = a [Mesh.ARRAY_INDEX]
				var vtx: PackedVector3Array = a [Mesh.ARRAY_VERTEX]
				t += (idx.size() / 3) if idx.size() > 0 else (vtx.size() / 3)
			lines.append("    %-14s %6d tris" % [mi.name, t])
			total += t
		print("%s.tscn  ->  %d tris across %d meshes" % [f, total, lines.size()])
		for l in lines: print(l)
		root.free()
	quit()

func _walk(n: Node) -> Array [Node]:
	var out: Array [Node] = [n]
	for c in n.get_children(): out.append_array(_walk(c))
	return out
