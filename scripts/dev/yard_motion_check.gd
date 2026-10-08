extends RefCounted


const NEAR:= 25.0
const DEFAULT_FRAMES:= 600

var p: Node


func run(probe: Node) -> void:
	p = probe
	var ua:= OS.get_cmdline_user_args()
	var frames:= DEFAULT_FRAMES
	var at:= ua.find("--motioncheck")
	if at + 1 < ua.size() and ua [at + 1].is_valid_int():
		frames = int(ua [at + 1])
	var shots:= ""
	var at_s:= ua.find("--shots")
	if at_s >= 0 and at_s + 1 < ua.size():
		shots = ua [at_s + 1]
		DirAccess.make_dir_recursive_absolute(shots)


	var at_c:= ua.find("--cap")
	if at_c >= 0 and at_c + 1 < ua.size():
		Engine.max_fps = int(ua [at_c + 1])
	var tree:= p.get_tree()

	for i in 120:
		await tree.process_frame
	var cam:= p.get_viewport().get_camera_3d()
	var batch:= BeltRunBatch.instance
	if batch == null or cam == null:
		print("[motion] no drawer or camera")
		return


	var tap:= Tap.new()
	tap.process_priority = 1000000
	tap.check = self
	tap.cam = cam
	tap.batch = batch
	tap.left = frames
	tap.shots = shots
	p.add_child(tap)
	while tap.left > 0:
		await tree.process_frame
	tap.queue_free()
	print("\n[motion] clock %s, %d frames, runs within %.0f m" % [
		"60 Hz" if FactoryClock.stride == 1 else "every %d ticks" % FactoryClock.stride,
		frames, NEAR])
	_report("straight", tap.ratios, tap.runs_seen.size())
	_report("bends", tap.bend_ratios, tap.bends_seen.size())
	for line in tap.odd:
		print("[motion]   " + line)


func _report(label: String, ratios: PackedFloat64Array, runs: int) -> void:
	if ratios.is_empty():
		print("[motion] %s: no moving run near the camera" % label)
		return
	var sorted:= ratios.duplicate()
	sorted.sort()
	var n:= sorted.size()
	var off:= 0
	var stalls:= 0
	var leaps:= 0
	for r in ratios:
		if absf(r - 1.0) > 0.3:
			off += 1
		if r < 0.2:
			stalls += 1
		if r > 1.8:
			leaps += 1
	print("[motion] %s: %d samples over %d runs" % [label, n, runs])
	print("[motion] %s moved / (speed x frame): p1 %.2f  p5 %.2f  p50 %.2f  p95 %.2f  p99 %.2f" % [
		label, sorted [int(n * 0.01)], sorted [int(n * 0.05)], sorted [n / 2],
		sorted [mini(n - 1, int(n * 0.95))], sorted [mini(n - 1, int(n * 0.99))]])
	print("[motion] %s off by more than 30%%: %.1f%%   stood still: %.1f%%   leapt double: %.1f%%" % [
		label, 100.0 * off / n, 100.0 * stalls / n, 100.0 * leaps / n])


class Tap extends Node:
	var check
	var cam: Camera3D
	var batch: BeltRunBatch
	var left:= 0
	var shots:= ""
	var frame:= 0
	var ratios:= PackedFloat64Array()
	var runs_seen:= { }
	var bend_ratios:= PackedFloat64Array()
	var bends_seen:= { }
	var last:= { }
	var st:= PackedFloat64Array()
	var odd: PackedStringArray = []

	func _process(dt: float) -> void:
		if left <= 0:
			return
		left -= 1
		frame += 1
		if shots != "" and frame >= 200 and frame < 206:
			get_viewport().get_texture().get_image().save_png(
				shots.path_join("frame_%d.png" % (frame - 200)))
		st.resize(10)
		for run: BeltRun in batch._by_run:
			var rd = batch._by_run [run]
			if run.count() == 0 or (rd.straight and rd.holder == null):
				continue
			var eye:= cam.global_position
			if eye.distance_to(rd.origin) > 25.0 and eye.distance_to(rd.end) > 25.0:
				continue
			var key:= run.get_instance_id()
			run.draw_into(st)
			var drawn: float = rd.drawn_free
			var speed:= st [1]


			var stepping:= Engine.get_physics_frames() - run.stepped_tick <= FactoryClock.stride + 1
			var ok:= int(st [8]) > 0 and speed > 0.5 and st [2] > speed * 0.1 and run.awake and stepping
			var prev: Array = last.get(key, [])
			last [key] = [drawn, ok]
			if prev.is_empty() or not ok or not bool(prev [1]) or dt <= 0.0:
				continue
			var moved: float = drawn - float(prev [0])

			if moved < -0.01 or moved > speed * dt * 4.0:
				continue
			var ratio:= moved / (speed * dt)
			if rd.straight:
				ratios.append(ratio)
				runs_seen [key] = true
			else:
				bend_ratios.append(ratio)
				bends_seen [key] = true
			if (ratio < 0.2 or ratio > 1.6) and odd.size() < 40:
				odd.append("ratio %.2f  ticks since step %d  last_dt %.1f ticks  room %.3f  speed %.2f  frame dt %.1f ms  frac %.2f  awake %s  free %d jam %d" % [
					ratio, Engine.get_physics_frames() - run.stepped_tick,
					run.last_dt * 60.0, st [2], speed, dt * 1000.0,
					Engine.get_physics_interpolation_fraction(), run.awake, int(st [8]), int(st [7])])
