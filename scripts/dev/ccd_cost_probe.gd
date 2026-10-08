class_name DevCcdCostProbe
extends Node


var world: Node3D


const BODIES:= 200

const FRAMES:= 200


const WARMUP:= 30

const PAIRS:= 5


const FALL:= 14.0

const TOP:= 8.0
const BOTTOM:= 1.0
const STRANDS:= 60

var _failures:= 0
var _wads: Array [RigidBody3D] = []
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	_rng.seed = 20260920


	await _check_free_flight()
	await _build()
	if _wads.size() < BODIES:
		print("[ccdcost] only %d of %d wads spawned" % [_wads.size(), BODIES])
	var off: Array [float] = []
	var on: Array [float] = []
	for pair in PAIRS:
		off.append(await _leg(false))
		on.append(await _leg(true))
		print("  pair %d:  off %6.3f ms   on %6.3f ms" % [pair + 1, off [-1], on [-1]])
	var a:= _median(off)
	var b:= _median(on)
	print("\n=== %d wads falling at %.0f m/s, %d frames a leg, %d pairs ==="
		% [_wads.size(), FALL, FRAMES, PAIRS])
	print("  continuous collision off   %6.3f ms a physics frame" % a)
	print("  continuous collision on    %6.3f ms a physics frame" % b)
	print("  the difference             %+6.3f ms, %+.1f%%"
		% [b - a, 100.0 * (b - a) / maxf(a, 0.0001)])
	var each:= (b - a) / float(maxi(_wads.size(), 1))
	print("  per body in the air        %+6.4f ms" % each)
	print("\n  A rake stroke puts ONE wad in the air and a pelletizer one brick,")
	print("  so a yard with six throwing machines all firing at once is six of")
	print("  these: %+6.4f ms a frame. A wad that has landed, is riding, or is"
		% (each * 6.0))
	print("  asleep is not in this figure at all: Jolt skips the cast below")
	print("  0.75 of the shape's inner radius a step, which for a %d strand wad"
		% STRANDS)
	print("  is %.1f m/s." % _cast_speed())
	print("\n[ccdcost] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		_fail(label)


func _check_free_flight() -> void:
	var props: PropManager = world.props
	props.clear()
	for i in 20:
		await get_tree().physics_frame


	var at:= Vector3(0.0, 30.0, 0.0)
	var vel:= Vector3(9.0, 9.0, 0.0)
	var bare:= props.spawn("hay_wad", Transform3D(Basis(), at),
		{ "strands": STRANDS }) as HayWad
	var armed:= props.spawn("hay_wad", Transform3D(Basis(), at + Vector3(0, 0, 4.0)),
		{ "strands": STRANDS }) as HayWad
	if bare == null or armed == null:
		_fail("could not spawn the two wads for the free flight case")
		return
	for wad in [bare, armed]:
		wad.sleeping = false
		wad.linear_velocity = vel
		wad.angular_velocity = Vector3.ZERO
	armed.arm_flight()
	var worst:= 0.0
	for i in 60:
		await get_tree().physics_frame


		var a:= bare.global_position - at
		var b:= armed.global_position - (at + Vector3(0, 0, 4.0))
		worst = maxf(worst, (a - b).length())
	print("\n=== the same throw, armed and not, with nothing in the way ===")
	print("  after 60 ticks: bare %.3f m out, armed %.3f m out"
		% [(bare.global_position - at).length(),
			(armed.global_position - at - Vector3(0, 0, 4.0)).length()])
	print("  worst gap between the two arcs: %.4f m" % worst)
	_check("arming a load does not change the arc it flies", worst < 0.01)
	props.clear()
	for i in 20:
		await get_tree().physics_frame
	await _check_landing()


func _check_landing() -> void:
	var props: PropManager = world.props
	var g:= absf(float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)))

	var from:= Vector3(0.0, 1.6, 0.0)
	var speed:= 8.0
	var a:= deg_to_rad(Cfg.RAKE_LAUNCH_ANGLE)
	var vel:= Vector3(cos(a) * speed, sin(a) * speed, 0.0)
	var rest:= { }
	for armed in [false, true]:
		var carried:= 0.0
		var n:= 0
		for shot in 6:
			var at:= from + Vector3(0.0, 0.0, float(shot) * 5.0)
			var wad:= props.spawn("hay_wad", Transform3D(Basis(), at),
				{ "strands": STRANDS }) as HayWad
			if wad == null:
				continue
			wad.sleeping = false
			wad.linear_velocity = vel
			if armed:
				wad.arm_flight()


			for i in 240:
				await get_tree().physics_frame
				if not is_instance_valid(wad):
					break
			if is_instance_valid(wad):
				carried += wad.global_position.x - at.x
				n += 1
		rest [armed] = carried / float(maxi(n, 1))
		props.clear()
		for i in 20:
			await get_tree().physics_frame
	var vacuum:= speed * speed * sin(2.0 * a) / g
	print("\n=== where the same throw comes to rest ===")
	print("  a %.1f m/s throw at %.0f degrees, vacuum range %.2f m"
		% [speed, Cfg.RAKE_LAUNCH_ANGLE, vacuum])
	print("  unarmed, 6 throws: %.3f m out" % float(rest [false]))
	print("  armed,   6 throws: %.3f m out" % float(rest [true]))
	print("  the difference:    %+.3f m" % (float(rest [true]) - float(rest [false])))


	_check("arming does not run a thrown load away across the yard",
		absf(float(rest [true]) - float(rest [false])) < 1.0)


func _cast_speed() -> float:
	var size:= Cfg.WAD_BASE_SIZE * HayWad.scale_for(STRANDS)
	var inner:= minf(size.x, minf(size.y, size.z)) * 0.5
	return 0.75 * inner * float(maxi(Engine.physics_ticks_per_second, 1))


func _build() -> void:
	var props: PropManager = world.props
	props.clear()
	for i in 40:
		await get_tree().physics_frame


	var side:= int(ceil(sqrt(float(BODIES))))
	for i in BODIES:
		var at:= Vector3(
			float(i % side) * 1.2 - float(side) * 0.6,
			TOP + float(i / side) * 0.05,
			float(i / side) * 1.2 - float(side) * 0.6)
		var wad:= props.spawn("hay_wad", Transform3D(Basis(), at),
			{ "strands": STRANDS }) as HayWad
		if wad == null:
			continue
		_wads.append(wad)
	for i in 20:
		await get_tree().physics_frame


func _leg(ccd: bool) -> float:
	for wad in _wads:
		if is_instance_valid(wad):
			wad.continuous_cd = ccd
	for i in WARMUP:
		_rearm()
		await get_tree().physics_frame
	var started:= Time.get_ticks_usec()
	for i in FRAMES:
		_rearm()
		await get_tree().physics_frame
	var spent:= float(Time.get_ticks_usec() - started) * 0.001
	return spent / float(FRAMES)


func _rearm() -> void:
	for wad in _wads:
		if not is_instance_valid(wad):
			continue
		var rb:= wad as RigidBody3D
		if rb.global_position.y > BOTTOM:
			continue
		var at:= rb.global_position
		at.y = TOP
		rb.global_position = at
		rb.linear_velocity = Vector3(0.0, - FALL, 0.0)
		rb.angular_velocity = Vector3.ZERO
		rb.sleeping = false


func _median(values: Array [float]) -> float:
	var sorted:= values.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return 0.0
	return sorted [sorted.size() / 2]
