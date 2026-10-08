extends SceneTree
func _init() -> void:
	var w = load("res://scenes/main.tscn").instantiate()
	root.add_child(w)
	await process_frame
	await process_frame
	var field: HayField = w.get_node("HayField")
	var n_with:= 0
	var reported:= 0
	for c in field.chunks:
		var mmi: MultiMeshInstance3D = c.get_node_or_null("Shell")
		if mmi == null:
			continue
		var mm:= mmi.multimesh
		var surf:= (mm.mesh as ArrayMesh).get_surface_count() if mm.mesh != null else -1
		if surf > 0:
			n_with += 1
			if reported < 3:
				reported += 1
				print("Shell chunk %s: instances=%d visible=%d surfaces=%d mat=%s aabb=%s visible_node=%s"
					% [c.name, mm.instance_count, mm.visible_instance_count, surf,
								str(mmi.material_override), str(mmi.custom_aabb), str(mmi.visible)])
	print("[probe] shell nodes with geometry: %d" % n_with)
	quit()
