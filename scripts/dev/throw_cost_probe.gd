class_name DevThrowCostProbe
extends Node


const WAD_RATE:= 10.0
const STRAND_RATE:= 100.0
const STREAM_SECONDS:= 12.0
const AFTER_SECONDS:= 12.0


const BASE_SECONDS:= 2.0
const ROW_SECONDS:= 2.0


const LOB_TIME:= 0.55

const EYE:= Vector3(-2.1, 1.62, 5.37)

var world: Node3D
var stand: HaySellingStand
var props: PropManager
var live: LiveStrandManager
var player: Player

var _rng:= RandomNumberGenerator.new()


func run() -> void:
	world.block_save = true
	_rng.seed = 20260926
	var builds:= world.get("builds") as BuildManager
	if builds != null:
		for arm in builds.robotic_arms.duplicate():
			if is_instance_valid(arm):
				arm.queue_free()
		builds.robotic_arms.clear()
	print("prop cap %d, live strand budget %d, drain keeps %.0f m round the player"
		% [Cfg.prop_cap, Cfg.live_strand_budget, Cfg.PROP_KEEP_DIST])
	var summary: Array [String] = []
	for kind in ["wad", "strand"]:
		for target in ["yard", "scale"]:
			summary.append(await _leg(kind, target))
	print("\n== summary (ms a frame, over the empty yard's line) ==")
	for s in summary:
		print(s)
	print("\n[throwcost] done")
	get_tree().quit(0)


func _leg(kind: String, target: String) -> String:
	await _clear()
	var rate:= WAD_RATE if kind == "wad" else STRAND_RATE
	print("\n-- %ss into the %s, %.0f a second for %.0f s, then %.0f s watching --"
		% [kind, target, rate, STREAM_SECONDS, AFTER_SECONDS])
	var base:= await _time(BASE_SECONDS)
	print("  empty yard: %.2f ms a frame" % base)
	print("     t   alive  awake    ms/frame  worst")

	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var owed:= 0.0
	var t:= 0.0
	var row_t:= 0.0
	var row_sum:= 0
	var row_n:= 0
	var row_worst:= 0
	var stream_sum:= 0
	var stream_n:= 0
	var after_sum:= 0
	var after_n:= 0
	var peak_alive:= 0
	var last:= Time.get_ticks_usec()
	var end_alive:= 0
	while t < STREAM_SECONDS + AFTER_SECONDS:
		if t < STREAM_SECONDS:
			owed += rate * step
			while owed >= 1.0:
				owed -= 1.0
				_throw(kind, target)
		await get_tree().physics_frame
		_stand_at()
		var now:= Time.get_ticks_usec()
		var cost:= now - last
		last = now
		t += step
		row_sum += cost
		row_n += 1
		row_worst = maxi(row_worst, cost)
		if t < STREAM_SECONDS:
			stream_sum += cost
			stream_n += 1
		elif t > STREAM_SECONDS + AFTER_SECONDS - 4.0:

			after_sum += cost
			after_n += 1
		row_t += step
		if row_t >= ROW_SECONDS - 1e-06:
			var counts:= _counts(kind)
			peak_alive = maxi(peak_alive, counts.x)
			end_alive = counts.x
			print("  %4.0f  %6d %6d   %8.2f  %6.2f" % [t, counts.x, counts.y,
				float(row_sum) / row_n / 1000.0, row_worst / 1000.0])
			row_t = 0.0
			row_sum = 0
			row_n = 0
			row_worst = 0
	var during:= float(stream_sum) / maxf(stream_n, 1) / 1000.0 - base
	var rest:= float(after_sum) / maxf(after_n, 1) / 1000.0 - base
	return "  %-6s %-5s  +%.2f while throwing, +%.2f after (%d left, peak %d alive)" % [kind, target, during, rest, end_alive, peak_alive]


func _throw(kind: String, target: String) -> void:
	var from:= stand.to_global(EYE) + Vector3(0, -0.2, 0)
	var vel: Vector3
	if target == "scale":
		var to:= stand.mouth_centre() + Vector3(_rng.randf_range(-0.25, 0.25),
			_rng.randf_range(0.0, 0.1), _rng.randf_range(-0.15, 0.15))
		var g:= Vector3(0, - float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)), 0)
		vel = (to - from) / LOB_TIME - 0.5 * g * LOB_TIME
	else:


		var away:= - (stand.to_global(Vector3(1.4, 0, 2.9)) - from)
		away.y = 0.0
		var dir:= away.normalized().rotated(Vector3.UP, _rng.randf_range(-1.4, 1.4))
		var speed:= Cfg.CARRY_THROW_SPEED if kind == "wad" else HandTool.THROW_SPEED
		vel = dir * speed * _rng.randf_range(0.8, 1.2) + Vector3(0, 1.4, 0)
	var start:= from + vel.normalized() * 0.6
	if kind == "wad":
		var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, start),
			{ "strands": 40 }) as RigidBody3D
		if wad != null:
			wad.linear_velocity = vel
	else:
		live.spawn(start, Basis.IDENTITY, vel, Color(0.9, 0.8, 0.5))


func _counts(kind: String) -> Vector2i:
	var alive:= 0
	var awake:= 0
	var bodies: Array = props.items if kind == "wad" else live.get("_active")
	for b in bodies:
		var rb:= b as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			continue
		alive += 1
		if not rb.sleeping and not rb.freeze:
			awake += 1
	return Vector2i(alive, awake)


func _time(seconds: float) -> float:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	await get_tree().physics_frame
	var began:= Time.get_ticks_usec()
	var n:= 0
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		_stand_at()
		t += step
		n += 1
	return float(Time.get_ticks_usec() - began) / maxf(n, 1) / 1000.0


func _clear() -> void:
	props.clear()
	for b in (live.get("_active") as Array).duplicate():
		if is_instance_valid(b) and not (b as RigidBody3D).has_meta("needle_index"):
			live.consume(b)

	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var t:= 0.0
	while t < 3.0:
		await get_tree().physics_frame
		_stand_at()
		t += step


func _stand_at() -> void:
	if player == null:
		return
	player.global_position = stand.to_global(EYE)
	player.velocity = Vector3.ZERO
