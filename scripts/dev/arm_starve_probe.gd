class_name DevArmStarveProbe
extends Node


var world: Node3D


const SETTLE:= 30

const WATCH_FRAMES:= 900


const ORIGIN:= Vector3(70.0, 0.06, 70.0)

const PITCH:= 4.5

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var builds: BuildManager = world.builds
	var count:= Cfg.ARM_LIMIT
	var side:= ceili(sqrt(float(count)))
	var arms: Array [RoboticArm] = []
	for i in count:
		var at:= ORIGIN + Vector3(float(i % side) * PITCH, 0.0, float(i / side) * PITCH)
		arms.append(builds.add_robotic_arm(at, 0.0))
	for i in SETTLE:
		await get_tree().process_frame

	print("\n=== %d idle arms, watched for %d frames ===" % [count, WATCH_FRAMES])
	var last: Array [float] = []
	var scans: Array [int] = []
	var longest: Array [int] = []
	var since: Array [int] = []
	for arm in arms:
		last.append(arm._scan_left)
		scans.append(0)
		longest.append(0)
		since.append(0)
	var busiest:= 0
	var dt:= 0.0
	var started:= Time.get_ticks_msec()
	for frame in WATCH_FRAMES:
		await get_tree().process_frame
		if frame % 150 == 0:
			print("        frame %d, %d ms" % [frame, Time.get_ticks_msec() - started])
		dt = maxf(dt, get_process_delta_time())
		var this_frame:= 0
		for i in count:
			var arm:= arms [i]
			since [i] += 1
			if arm._scan_left > last [i]:
				scans [i] += 1
				this_frame += 1
				since [i] = 0
			longest [i] = maxi(longest [i], since [i])
			last [i] = arm._scan_left
		busiest = maxi(busiest, this_frame)

	var idle:= 0
	for arm in arms:
		if arm._phase == RoboticArm.Phase.IDLE:
			idle += 1
	_is("every arm stayed idle", idle, count)
	var fewest: int = scans.min()
	var starved:= scans.count(0)


	var interval_frames:= ceili(RoboticArm.SCAN_INTERVAL / maxf(dt, 0.001))
	var allowed:= 2 * (count + interval_frames)
	print("        scans per arm %d to %d, longest wait %d frames, allowed %d"
		% [fewest, scans.max(), longest.max(), allowed])
	_is("arms that never scanned", starved, 0)
	_is("longest wait within allowance", longest.max() <= allowed, true)
	_is("at most one scan a frame", busiest <= 1, true)
	_finish()


func _finish() -> void:
	print("\n[arm-starve] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
