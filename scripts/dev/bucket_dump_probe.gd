class_name DevBucketDumpProbe
extends Node


const SETTLE:= 40


const FLUNG:= 4.0


const DUMP_SECONDS:= 20.0

const WATCH_TICKS:= 900

var world: Node3D
var player: Player

var _worst:= 0.0
var _worst_at:= 0
var _worst_live:= 0


func run() -> void:
	call_deferred("_run")


func _spray_case(box: HayContainer, live: LiveStrandManager) -> void:
	print("\n  --- which way the hay leaves ---")


	var at:= Vector3(13.0, 1.4, 0.0)
	var pose:= Transform3D(Basis(Vector3.RIGHT, deg_to_rad(70.0)), at)
	box.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	box.freeze = true


	for i in 6:
		box.global_transform = pose
		await get_tree().physics_frame

	await _measure_spray(box, live, "standing still", pose, Vector3.ZERO)


	box._held = true
	await _measure_spray(box, live, "held and swung", pose, Vector3(0.12, 0.0, 0.0))
	box._held = false
	box.freeze = false


func _measure_spray(box: HayContainer, live: LiveStrandManager, what: String,
		pose: Transform3D, step: Vector3) -> void:
	var lean:= box.global_transform.basis.y
	var spill:= Vector3(lean.x, 0.0, lean.z)
	spill = spill.normalized() if spill.length_squared() > 1e-06 else Vector3.FORWARD
	var seen:= { }
	for b: RigidBody3D in live._active:
		seen [b.get_instance_id()] = true
	var stored_before:= box.stored

	var behind:= 0
	var fast:= 0
	var worst:= 0.0
	var counted:= 0
	var here:= box.global_position
	for i in 6:
		here += step
		box.global_transform = Transform3D(pose.basis, here)
		await get_tree().physics_frame
		for b: RigidBody3D in live._active:
			var id:= b.get_instance_id()
			if seen.has(id):
				continue
			seen [id] = true
			counted += 1
			var off:= b.global_position - here
			var flat:= Vector3(off.x, 0.0, off.z)
			if flat.length() > 0.02 and flat.normalized().dot(spill) < 0.0:
				behind += 1
			var sp:= b.linear_velocity.length()
			worst = maxf(worst, sp)
			if sp > FLUNG:
				fast += 1
	print("  %-16s poured %d, saw %d: %d behind the lip, %d flung, worst %.1f m/s"
		% [what, stored_before - box.stored, counted, behind, fast, worst])


	if fast * 3 > counted:
		print("  FAIL  %d of %d strands left at more than %.0f m/s"
			% [fast, counted, FLUNG])
	if behind > counted / 2:
		print("  FAIL  %d of %d strands came out behind the lip" % [behind, counted])


func _print_spread(what: String, samples: Array [float]) -> void:
	if samples.is_empty():
		return
	var sorted:= samples.duplicate()
	sorted.sort()
	var total:= 0.0
	for v in samples:
		total += v
	var k:= int(float(sorted.size() - 1) * 0.95)
	print("  %-6s %4d ticks   mean %6.2f ms   p95 %6.2f ms   worst %6.2f ms"
		% [what, sorted.size(), total / sorted.size(), sorted [k], sorted [-1]])


func _awake(live: LiveStrandManager) -> int:
	var n:= 0
	for b: RigidBody3D in live._active:
		if not b.sleeping and not b.freeze:
			n += 1
	return n


func _which() -> String:
	var args:= OS.get_cmdline_user_args()
	var i:= args.find("--bucketdump")
	if i >= 0 and i + 1 < args.size() and not args [i + 1].begins_with("--"):
		return args [i + 1]
	return "bucket"


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame


	var at:= Vector3(13.0, 1.4, 0.0)
	player.global_position = Vector3(10.5, 0.4, 0.0)
	Tech.grant_legacy()
	for i in SETTLE:
		await get_tree().physics_frame

	var props: PropManager = world.props
	var live: LiveStrandManager = world.live
	var id:= _which()
	var thing: Carryable = props.spawn(id, Transform3D(Basis.IDENTITY, at))
	if thing == null:
		print("[bucketdump] could not place a %s" % id)
		get_tree().quit()
		return
	var box:= thing as HayContainer
	if box == null:
		print("[bucketdump] %s is not a container" % id)
		get_tree().quit()
		return
	box.stored = box.capacity()
	print("\n=== a %s holding %d strands, tipped on its side ===" % [
		box.display_name, box.stored])
	print("live budget %d, already live %d" % [
		Cfg.live_strand_budget, live.active_count()])

	for i in SETTLE:
		await get_tree().physics_frame

	await _spray_case(box, live)


	var eye:= player.camera.global_position
	var floor_at:= Vector3(at.x, 0.2, at.z)
	player.set_look(atan2(floor_at.x - eye.x, floor_at.z - eye.z) + PI,
		atan2(floor_at.y - eye.y, maxf(Vector2(floor_at.x - eye.x,
			floor_at.z - eye.z).length(), 0.001)))


	box.global_transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.05, at.z))
	box.linear_velocity = Vector3.ZERO
	box.angular_velocity = Vector3.ZERO
	for i in 120:
		await get_tree().physics_frame


	var last:= Time.get_ticks_usec()
	var quiet: Array [float] = []
	for i in 120:
		await get_tree().physics_frame
		var now_q:= Time.get_ticks_usec()
		quiet.append(float(now_q - last) * 0.001)
		last = now_q


	box.global_transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), at)
	box.linear_velocity = Vector3.ZERO
	box.angular_velocity = Vector3.ZERO
	var ticks:= int(DUMP_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))

	print("\n  frame   frame ms   live strands   awake   riding   still in it")
	var pour_ms: Array [float] = []
	for tick in ticks:
		await get_tree().physics_frame
		var now_us:= Time.get_ticks_usec()
		var ms:= float(now_us - last) * 0.001
		last = now_us
		var n:= live.active_count()
		pour_ms.append(ms)
		if ms > _worst:
			_worst = ms
			_worst_at = tick
			_worst_live = n


		if tick % 40 == 0 or tick < 6:
			print("  %5d   %8.2f   %12d   %5d   %6d   %s" % [tick, ms, n,
				_awake(live), box._riding.size(), str(box.stored)])
		if box.stored <= 0 and tick > 60:
			print("  %5d   %8.2f   %12d   %5d   %6d   empty" % [tick, ms, n,
				_awake(live), box._riding.size()])
			break


	print("\r\n  --- after the pour, with nobody touching anything ---")
	var after_ms: Array [float] = []
	for i in WATCH_TICKS:
		await get_tree().physics_frame
		var now_a:= Time.get_ticks_usec()
		var ms2:= float(now_a - last) * 0.001
		last = now_a
		after_ms.append(ms2)
		if i % 120 != 0:
			continue
		print("  %+5.1f s   %8.2f   %12d   %5d   %6d" % [
			float(i) * get_physics_process_delta_time(), ms2,
			live.active_count(), _awake(live), box._riding.size()])

	print("")
	_print_spread("quiet", quiet)
	_print_spread("pour", pour_ms)
	_print_spread("after", after_ms)
	print("  worst frame of the pour: %.2f ms at tick %d, with %d live strands"
		% [_worst, _worst_at, _worst_live])
	print("  a 60 Hz budget is 16.67 ms; a frame has to fit inside it")
	get_tree().quit()
