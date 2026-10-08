class_name DevDensityTest
extends Node


var world: Node3D
var player: Player
var build_ms:= 0.0


func run(target_per_cell: int) -> void:


	Cfg.crust_strands_per_cell = target_per_cell
	var t0:= Time.get_ticks_msec()
	world.field.rebuild_density()
	build_ms = float(Time.get_ticks_msec() - t0)

	var allocated:= 0
	for c in world.field.chunks:
		var mmi: MultiMeshInstance3D = c.get_node_or_null("Crust")
		if mmi != null:
			allocated += mmi.multimesh.instance_count


	var results:= { }
	for shot: Array in [
		[Vector3(11.5, 1.7, 1.0), Vector3(2.0, 3.5, 0.0), "at the pile"],
		[Vector3(0.0, 12.5, 15.5), Vector3(0.0, 3.0, 0.0), "across the shed"],
	]:
		player.global_position = shot [0] - Vector3(0, Player.EYE_HEIGHT, 0)
		var flat:= Vector3(shot [1].x - shot [0].x, 0.0, shot [1].z - shot [0].z)
		player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
		player.head.rotation.x = atan2(shot [1].y - shot [0].y, maxf(flat.length(), 0.001))
		for i in 60:
			await get_tree().process_frame
		var total:= 0.0
		for i in 90:
			await get_tree().process_frame
			total += get_process_delta_time()
		var ms:= total / 90.0 * 1000.0
		results [shot [2]] = [ms, world.field.drawn_instance_count()]

	print("\n=== crust density %d strands/cell ===" % target_per_cell)
	print("  allocated instances : %d" % allocated)
	print("  build time          : %.1f s  (one-off, at load)" % (build_ms / 1000.0))
	for k: String in results:
		var r: Array = results [k]
		print("  %-16s   %6.2f ms = %5.1f fps   drawn %d"
			% [k, r [0], 1000.0 / maxf(r [0], 0.001), r [1]])
	get_tree().quit()
