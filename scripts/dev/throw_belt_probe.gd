class_name DevThrowBeltProbe
extends Node


const SPEEDS:= [6.0, 14.0, 26.0]


const SWEEP_SPEEDS:= [8.0, 9.0, 10.0, 11.0, 12.0]

const THROWS:= 6

const WATCH:= 180

const APART:= 150
const SETTLE:= 40

const BURST:= 2.0

const SPEED:= 3.2

const HEAD:= Vector3(13.0, 0.75, -12.0)
const TAIL:= Vector3(13.0, 0.75, 12.0)

var world: Node3D
var player: Player

var _rng:= RandomNumberGenerator.new()
var _fails:= 0


var _top:= Vector3.ZERO


var _high:= false
var _marked:= false


var _under:= 0
var _under_armed:= 0

var _cases:= 0
var _stranded:= 0


var _rise:= 1.5
var _back:= 3.0
var _angle:= 0.0
var _brick:= false


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = Vector3(6.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	_rng.seed = 20260912
	if "--bricks" in OS.get_cmdline_user_args():
		await _bricks()
		return

	print("\n[throwbelt] wads thrown onto a belt driven at %.1f m/s" % SPEED)
	print("[throwbelt] a prop is refused until it is within %.2f m/s of what the"
		% BeltPath.PROP_SETTLE_SPEED)
	print("[throwbelt] deck under it is doing, so every one of these bounces loose")
	print("[throwbelt] on a moving deck first. The question is what happens then.")

	var rows: Array [String] = []
	for place in ["midrun", "seam", "rail", "slope", "crest", "lob", "rakelob"]:
		for speed: float in SPEEDS:
			rows.append(await _case(place, speed))


	var sweep: Array [String] = []
	for speed: float in SWEEP_SPEEDS:
		for place in ["lob", "rail"]:
			sweep.append(await _case(place, speed))
	print("\n=== worst upward speed after the load touched the belt ===")
	print("  place    throw   landed  aboard   thrown up   worst up   arrived vy"
		+ "   ticks loose   under   the ones that never boarded")
	for row in rows:
		print(row)
	print("\n=== how fast it has to arrive before the deck stops catching it ===")
	print("  the `under` column is what decides the arming threshold in"
		+ " Carryable.arm_flight")
	for row in sweep:
		print(row)


	if _stranded > 0:
		print("\n[throwbelt] NOTE: %d loads ended the watch LYING ON A BELT that"
			% _stranded)
		print("[throwbelt] would not take them aboard, over %d cases. That is the"
			% _cases)
		print("[throwbelt] settle band in BeltPath._catch refusing a load it ought")
		print("[throwbelt] to carry. See the note there about measuring vy against")
		print("[throwbelt] the deck rather than against the horizon.")
	if _under > 0:
		print("\n[throwbelt] NOTE: %d loads ended up UNDER the deck they were"
			% _under)
		print("[throwbelt] thrown at, %d of them ARMED for the flight. The rubber"
			% _under_armed)
		print("[throwbelt] is Cfg.BELT_DECK_THICK (%.0f cm), so an arrival steeper"
			% (Cfg.BELT_DECK_THICK * 100.0))
		print("[throwbelt] than about %.1f m/s is past the slab in one physics step"
			% Carryable.skip_speed())
		print("[throwbelt] unless continuous collision is on. The unarmed rows are")
		print("[throwbelt] the control and are MEANT to sink: compare `lob` with")
		print("[throwbelt] `rakelob`, the same throw with the flag set. See")
		print("[throwbelt] Carryable.arm_flight and BeltPath.mark_machine_throw.")
	print("\n[throwbelt] %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _case(place: String, speed: float) -> String:


	_high = place == "lob" or place == "rakelob"
	_marked = place == "rakelob"
	var mid:= HEAD.lerp(TAIL, 0.5)
	var top:= mid


	if place == "slope" or place == "crest":
		top = mid + Vector3(0.0, (TAIL.z - HEAD.z) * 0.5 * tan(deg_to_rad(18.0)), 0.0)
	_top = top
	var a: Conveyor = world.builds.add_conveyor(HEAD, top)
	var b: Conveyor = world.builds.add_conveyor(top, Vector3(TAIL.x, top.y, TAIL.z))
	if a == null or b == null:
		print("[throwbelt] could not lay the runs")
		_fails += 1
		return ""
	var paths: Array [BeltPath] = [a, b]
	for k in world.builds.corners:
		if is_instance_valid(k):
			paths.append(k)
	for p in paths:
		p.set_drive_speed(SPEED)
	for i in SETTLE:
		await get_tree().physics_frame


	var deck_y:= a.global_position.y + Cfg.BELT_FRAME_DEPTH
	var target:= mid
	match place:
		"midrun":
			target = HEAD.lerp(mid, 0.5)
			target.y = deck_y
		"seam":
			target = mid
			target.y = deck_y
		"rail":


			target = HEAD.lerp(mid, 0.5) + Vector3(Cfg.BELT_WIDTH * 0.5, 0.0, 0.0)
			target.y = deck_y
		"slope":


			target = HEAD.lerp(top, 0.5)
			target.y += Cfg.BELT_FRAME_DEPTH
		"crest":


			target = HEAD.lerp(top, 0.85)
			target.y += Cfg.BELT_FRAME_DEPTH
		"lob", "rakelob":


			target = HEAD.lerp(mid, 0.5)
			target.y = deck_y

	var landed:= 0
	var aboard:= 0
	var thrown:= 0
	var worst:= 0.0
	var worst_after:= 0
	var arrived:= 0.0
	var wait:= 0.0
	var waits:= 0


	var stranded:= 0
	var flew:= 0
	var sank:= 0
	for shot in THROWS:
		var res:= await _throw(target, speed, deck_y)
		if res.is_empty():
			continue
		landed += 1
		sank += (1 if bool(res ["under"]) else 0)
		arrived = minf(arrived, float(res ["arrived"]))
		if bool(res ["aboard"]):
			aboard += 1
			wait += float(res ["boarded"])
			waits += 1
		if not bool(res ["aboard"]):
			stranded += (1 if String(res ["ended"]) == "on belt" else 0)
			flew += (1 if String(res ["ended"]) != "on belt" else 0)
		if float(res ["up"]) >= BURST:
			thrown += 1
		if float(res ["up"]) > worst:
			worst = float(res ["up"])
			worst_after = int(res ["after"])
	for c in world.builds.conveyors.duplicate():
		if is_instance_valid(c):
			world.builds.demolish(c)
	(world.props as PropManager).clear()
	for i in SETTLE:
		await get_tree().physics_frame


	_cases += 1
	if thrown > 0:
		_fails += 1


	if sank > 0 and _marked:
		_fails += 1
	_stranded += stranded
	_under += sank
	if _marked:
		_under_armed += sank
	return "  %-8s %5.0f %8d %7d %11d %10.2f %10.2f %9s %7d %10s" % [place, speed,
		landed, aboard, thrown, worst, arrived,
		("%.0f" % (wait / float(waits)) if waits > 0 else "never"), sank,
		("-" if aboard == landed else "%d on belt, %d off" % [stranded, flew])]


func _bricks() -> void:
	_brick = true
	print("\n[throwbelt] eco bricks (%s), arming speed %.2f m/s" % [
		Cfg.ECO_BRICK_SIZE, _probe_brick_arm_speed()])
	var rows: Array [String] = []
	_high = false
	_marked = true
	_angle = 42.0
	for rise: float in [0.76, 2.0, 3.5]:
		for back: float in [2.0, 2.6, 3.5, 4.5]:
			for place in ["midrun", "rail"]:
				_rise = rise
				_back = back
				rows.append(await _brick_case(place, 0.0))
	var sweep: Array [String] = []
	_angle = 0.0
	_high = true
	_rise = 1.5
	_back = 3.0
	for speed: float in [4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0]:
		for marked: bool in [false, true]:
			for place in ["midrun", "rail"]:
				_marked = marked
				sweep.append(await _brick_case(place, speed))
	var head:= "  place    rise  back  marked  launch   arrival  armed  landed" + "  aboard  under  under armed  under unarmed"
	print("\n=== the pelletizer's throw: 42 degrees, speed solved for distance ===")
	print(head)
	for row in rows:
		print(row)
	print("\n=== high arc speed sweep from 1.5 m up, 3 m back ===")
	print(head)
	for row in sweep:
		print(row)
	print("\n[throwbelt] bricks under a deck between the rails: %d, of which armed %d"
		% [_under, _under_armed])
	print("\n[throwbelt] %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _probe_brick_arm_speed() -> float:
	var s:= Cfg.ECO_BRICK_SIZE
	return (minf(s.x, minf(s.y, s.z)) + Cfg.BELT_DECK_THICK) * float(maxi(Engine.physics_ticks_per_second, 1)) * Carryable.ARM_MARGIN


func _brick_case(place: String, speed: float) -> String:
	var mid:= HEAD.lerp(TAIL, 0.5)
	_top = mid
	var a: Conveyor = world.builds.add_conveyor(HEAD, mid)
	var b: Conveyor = world.builds.add_conveyor(mid, TAIL)
	if a == null or b == null:
		print("[throwbelt] could not lay the runs")
		_fails += 1
		return ""
	var paths: Array [BeltPath] = [a, b]
	for k in world.builds.corners:
		if is_instance_valid(k):
			paths.append(k)
	for p in paths:
		p.set_drive_speed(SPEED)
	for i in SETTLE:
		await get_tree().physics_frame
	var deck_y:= a.global_position.y + Cfg.BELT_FRAME_DEPTH
	var target:= HEAD.lerp(mid, 0.5)
	if place == "rail":
		target += Vector3(Cfg.BELT_WIDTH * 0.5, 0.0, 0.0)
	target.y = deck_y

	var landed:= 0
	var aboard:= 0
	var armed:= 0
	var under_armed:= 0
	var under_bare:= 0
	var launch:= 0.0
	var fastest:= 0.0
	for shot in THROWS:
		var res:= await _throw(target, speed, deck_y)
		if res.is_empty():
			continue
		landed += 1
		launch = float(res ["launch"])
		fastest = maxf(fastest, float(res ["fastest"]))
		aboard += (1 if bool(res ["aboard"]) else 0)
		armed += (1 if bool(res ["armed"]) else 0)
		if bool(res ["inside"]):
			if bool(res ["armed"]):
				under_armed += 1
			else:
				under_bare += 1
	for c in world.builds.conveyors.duplicate():
		if is_instance_valid(c):
			world.builds.demolish(c)
	(world.props as PropManager).clear()
	for i in SETTLE:
		await get_tree().physics_frame
	_under += under_armed + under_bare
	_under_armed += under_armed
	if _marked and under_armed + under_bare > 0:
		_fails += 1
	return "  %-8s %4.2f  %4.1f  %6s  %6.2f  %8.2f  %5d  %6d  %6d  %5d  %11d  %13d" % [
		place, _rise, _back, ("yes" if _marked else "no"), launch, fastest, armed,
		landed, aboard, under_armed + under_bare, under_armed, under_bare]


func _deck_under(p: Vector3) -> float:
	var t:= clampf((p.z - HEAD.z) / maxf(_top.z - HEAD.z, 1e-06), 0.0, 1.0)
	return lerpf(HEAD.y, _top.y, t) + Cfg.BELT_FRAME_DEPTH


func _throw(target: Vector3, speed: float, deck_y: float) -> Dictionary:


	var from:= target + Vector3(0.0, _rise, - _back)
	var flat:= target - from
	flat.y = 0.0
	var dist:= flat.length()
	var dir:= flat.normalized()

	var g:= 9.8
	var v2:= speed * speed
	var root:= v2 * v2 - g * (g * dist * dist + 2.0 * (target.y - from.y) * v2)
	if root < 0.0:

		root = 0.0


	var ang:= atan2(v2 + sqrt(root), g * dist) if _high else atan2(v2 - sqrt(root), g * dist)


	if _angle > 0.0:
		ang = deg_to_rad(_angle)
		var den:= 2.0 * pow(cos(ang), 2.0) * (dist * tan(ang) + (from.y - target.y))
		speed = sqrt(g * dist * dist / maxf(den, 0.0001))
	var vel:= dir * cos(ang) * speed + Vector3.UP * sin(ang) * speed

	var props: PropManager = world.props
	var wad:= props.spawn("eco_brick", Transform3D(Basis(), from),
		{ "strands": Cfg.PELLETIZER_BRICK_STRANDS }) if _brick else props.spawn("hay_wad", Transform3D(Basis(), from), { "strands": 60 })
	if wad == null:
		return { }
	var rb:= wad as RigidBody3D
	rb.linear_velocity = vel
	if _marked:
		BeltPath.mark_machine_throw(rb)
	var armed:= rb.continuous_cd


	var inside:= false
	var fastest:= 0.0

	var touched:= -1
	var up:= 0.0
	var after:= 0
	var aboard:= false


	var under:= false


	var arrived:= 0.0
	var boarded:= -1
	for tick in WATCH:
		await get_tree().physics_frame
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			break


		var p3:= rb.global_position


		var on_belt:= p3.y <= _deck_under(p3) + 0.45 and absf(p3.x - HEAD.x) <= Cfg.BELT_WIDTH and p3.z >= HEAD.z - 0.5 and p3.z <= TAIL.z + 0.5
		if touched < 0:
			if on_belt or BeltPath.is_rider(rb):
				touched = tick


				arrived = rb.linear_velocity.y
			else:
				continue


		if not BeltPath.is_rider(rb) and rb.linear_velocity.y > up:
			up = rb.linear_velocity.y
			after = tick - touched
		if not BeltPath.is_rider(rb) and p3.y < _deck_under(p3) - 0.5 and absf(p3.x - HEAD.x) <= Cfg.BELT_WIDTH and p3.z >= HEAD.z - 0.5 and p3.z <= TAIL.z + 0.5:
			under = true
			if absf(p3.x - HEAD.x) <= Cfg.BELT_WIDTH * 0.5 - 0.05:
				inside = true
		if touched == tick:
			fastest = rb.linear_velocity.length()
		if BeltPath.is_rider(rb):
			aboard = true
			if boarded < 0:
				boarded = tick - touched

	if is_instance_valid(rb) and rb.is_inside_tree():
		BeltPath.release(rb)
		props.remove(wad)
	for i in APART:
		await get_tree().physics_frame
	if touched < 0:
		return { }


	var ended:= "gone"
	if is_instance_valid(rb) and rb.is_inside_tree():
		var e:= rb.global_position
		ended = ("on belt" if e.y <= _deck_under(e) + 0.45
			and absf(e.x - HEAD.x) <= Cfg.BELT_WIDTH
			and e.z >= HEAD.z - 0.5 and e.z <= TAIL.z + 0.5 else "off belt")
	return { "aboard": aboard, "up": up, "after": after, "ended": ended,
		"arrived": arrived, "boarded": boarded, "under": under,
		"armed": armed, "inside": inside, "launch": speed, "fastest": fastest }
