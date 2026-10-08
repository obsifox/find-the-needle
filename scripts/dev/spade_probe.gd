extends SceneTree


func _init() -> void:
	var packed:= load("res://assets/downloaded/models/rusted_spade_01/rusted_spade_01_1k.gltf")
	var mi: MeshInstance3D = packed.instantiate().get_child(0)
	var verts:= mi.mesh.get_faces()
	var blade_y1:= -0.22

	var shaft_z:= 0.0
	var shaft_n:= 0
	for v in verts:
		if v.y > 0.0 and v.y < 0.45 and absf(v.x) < 0.03:
			shaft_z += v.z
			shaft_n += 1
	shaft_z /= maxf(float(shaft_n), 1.0)


	var rim_z:= 0.0
	var rim_n:= 0
	var mid_z:= 0.0
	var mid_n:= 0
	for v in verts:
		if v.y >= blade_y1:
			continue
		if absf(v.x) > 0.07:
			rim_z += v.z
			rim_n += 1
		elif absf(v.x) < 0.02:
			mid_z += v.z
			mid_n += 1
	rim_z /= maxf(float(rim_n), 1.0)
	mid_z /= maxf(float(mid_n), 1.0)
	print("shaft centre z = %+.5f  (n=%d)" % [shaft_z, shaft_n])
	print("blade rim    z = %+.5f  (n=%d)" % [rim_z, rim_n])
	print("blade middle z = %+.5f  (n=%d)" % [mid_z, mid_n])
	print("rim - middle   = %+.5f" % (rim_z - mid_z))
	print("=> dish opens toward model %sZ" % ("+" if rim_z > mid_z else "-"))
	quit()
