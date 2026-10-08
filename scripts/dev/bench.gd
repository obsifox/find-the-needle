class_name DevBench
extends Node


var world: Node3D
var field: HayField
var live: LiveStrandManager

const FRAMES:= 150
const SAMPLES_X:= 5
const SAMPLES_Z:= 4
const BLADE_W:= 0.34
const BLADE_D:= 0.4


func run() -> void:
	field = world.get_node("HayField")
	live = world.get_node("LiveStrands")
	for i in 30:
		await get_tree().process_frame

	var t_carve:= 0.0
	var t_settle:= 0.0
	var t_flush:= 0.0
	var t_live:= 0.0
	var cells_dirtied:= 0
	var spawned:= 0
	var worst_frame:= 0.0


	var depth:= 0.0
	for f in FRAMES:
		var frame_start:= Time.get_ticks_usec()
		depth = minf(depth + 0.012, 0.75)
		var blade_pos:= Vector3(0.0, 4.6 - depth * 2.0, 6.2 + depth)
		var basis:= Basis.from_euler(Vector3(-0.4, 0.0, 0.0))

		var t0:= Time.get_ticks_usec()
		var total:= 0.0
		var pts:= PackedVector3Array()
		for j in SAMPLES_Z:
			for i in SAMPLES_X:
				var off:= Vector3(
					lerpf(- BLADE_W * 0.46, BLADE_W * 0.46, float(i) / float(SAMPLES_X - 1)),
					0.0,
					lerpf(- BLADE_D * 0.48, BLADE_D * 0.46, float(j) / float(SAMPLES_Z - 1)))
				var p:= blade_pos + basis * off
				var res:= field.carve_sphere(p, 0.13, 5.5 / 60.0)
				total += res ["strands"]
				pts.append_array(res ["points"])
		t_carve += Time.get_ticks_usec() - t0

		if total > 0.0:
			spawned += live.spawn_from_carve(pts, total, Vector3(0, 0.4, -0.6))

		cells_dirtied += field._dirty_cells.size() + field._cell_queue.size()

		t0 = Time.get_ticks_usec()
		field._settle()
		t_settle += Time.get_ticks_usec() - t0

		t0 = Time.get_ticks_usec()
		field._flush_dirty()
		t_flush += Time.get_ticks_usec() - t0

		t0 = Time.get_ticks_usec()
		live._process(1.0 / 60.0)
		t_live += Time.get_ticks_usec() - t0

		worst_frame = maxf(worst_frame, float(Time.get_ticks_usec() - frame_start))
		await get_tree().process_frame

	var n:= float(FRAMES)
	print("\n=== dig benchmark: %d frames ===" % FRAMES)
	print("  carve          %7.2f ms/frame" % (t_carve / n / 1000.0))
	print("  settle/relax   %7.2f ms/frame" % (t_settle / n / 1000.0))
	print("  crust rebuild  %7.2f ms/frame" % (t_flush / n / 1000.0))
	print("  live strands   %7.2f ms/frame" % (t_live / n / 1000.0))
	print("  ------------------------------")
	print("  TOTAL          %7.2f ms/frame   (16.7 ms = 60 fps)"
		% ((t_carve + t_settle + t_flush + t_live) / n / 1000.0))
	print("  worst frame    %7.2f ms" % (worst_frame / 1000.0))
	print("  cell-updates queued (avg backlog): %d" % (cells_dirtied / FRAMES))
	print("  live strands spawned: %d, active: %d" % [spawned, live.active_count()])
	print("  strands per cell: %d" % Cfg.crust_strands_per_cell)
	get_tree().quit()
