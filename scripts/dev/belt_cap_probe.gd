class_name DevBeltCapProbe
extends Node


const BELT_A:= Vector3(13.0, 0.75, -5.0)
const BELT_B:= Vector3(13.0, 0.75, 5.0)


const LOOSE_A:= Vector3(13.0, 0.75, -17.0)
const LOOSE_B:= Vector3(13.0, 0.75, -7.0)


const STRAW:= 150
const STRAW_LANES:= 5
const STRAW_PITCH:= 0.3


const WATCH:= Vector3(-13.0, 0.4, 13.0)


const WADS:= 17
const STRANDS:= 40


const DROP_Z:= 5.0
const DROP_STEP:= -0.58


const SHED_BY:= 6

const SETTLE:= 40


const WAIT:= 400


const LEDGER_EPS:= 0.5

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0
var _belt: Conveyor


var _was_cap:= 0
var _was_decay:= false


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = WATCH
	GameState.add_money(50000.0)
	_was_cap = Cfg.belt_cap
	_was_decay = Cfg.belt_decay
	Cfg.belt_decay = true


	Cfg.belt_cap = Cfg.BELT_CAP_MAX
	world.props.clear()
	await _spin(SETTLE)

	if not await _lay_the_belt():
		print("\n[beltcap] FAIL: no belt to test against")
		_finish()
		return

	await _check_the_back_goes_first()
	await _check_a_needle_is_spared()
	await _check_the_switch()


	await _check_a_shovelled_line_is_not_throttled()

	print("\n=== belt cap probe: %d passed, %d failed ===" % [_pass, _fail])
	_finish()


func _lay_the_belt() -> bool:
	_belt = world.builds.add_conveyor(BELT_A, BELT_B)
	if _belt == null:
		return false
	await _spin(SETTLE)
	_belt.set_drive_speed(0.0)
	await _spin(10)
	print("laid a %.1f m run and stopped it" % _belt.path_length())
	return true


func _check_a_shovelled_line_is_not_throttled() -> void:
	print("\n=== a shovelled line at the shipped cap ===")
	Cfg.belt_decay = true
	Cfg.belt_cap = Cfg.BELT_CAP_DEFAULT
	var run: Conveyor = world.builds.add_conveyor(LOOSE_A, LOOSE_B)
	if not _ok("laid a second run for loose hay", run != null):
		return
	await _spin(SETTLE)
	run.set_drive_speed(0.0)
	await _spin(10)

	var refused_before:= BeltPath._refused
	var straw:= _tip_hay_onto(run)
	print("  strands tipped onto it   : %d" % straw.size())
	await _spin(240)

	var riding:= 0
	for b in straw:
		if is_instance_valid(b) and BeltPath.is_rider(b):
			riding += 1
	print("  ...aboard                : %d  (cap is %d)" % [riding, Cfg.belt_cap])
	print("  take-ons refused for cap : %d" % (BeltPath._refused - refused_before))
	print("  loads the belts carry    : %d" % BeltPath.belt_load())


	_ok("more strands ride than the belts count loads",
		riding > BeltPath.belt_load())
	_ok("...and not one strand was turned away for want of budget",
		BeltPath._refused == refused_before)


	_ok("...and the whole line is well under one cap of loads",
		BeltPath.belt_load() < Cfg.belt_cap)


	_ok("...but the straw is not weightless", BeltPath.belt_load() > 0)


func _check_the_back_goes_first() -> void:
	print("\n=== a loaded run, capped under what it is carrying ===")
	var wads: Array [Carryable] = await _load_the_run()
	var riding:= _belt.riders_debug()
	print("  wads laid on the run     : %d" % wads.size())
	print("  ...aboard                : %d" % riding.size())
	print("  belts carrying           : %d" % BeltPath.belt_load())
	if not _ok("the run is carrying a queue worth capping",
			riding.size() >= SHED_BY + 4):
		return


	var ids: Array [int] = []
	var at: Array [float] = []
	for r: Dictionary in riding:
		ids.append(int(r ["seq"]))
		at.append(float(r ["s"]))
	var leader:= 0
	for i in ids.size():
		if at [i] > at [leader]:
			leader = i

	var before:= BeltPath.belt_load()
	var hay_before:= GameState.hay_total
	Cfg.belt_cap = before - SHED_BY
	print("  cap dropped to %d against a load of %d" % [Cfg.belt_cap, before])
	await _spin(WAIT)


	var after:= BeltPath.belt_load()
	var left:= { }
	for r: Dictionary in _belt.riders_debug():
		left [int(r ["seq"])] = true
	var gone:= 0
	var last_left:= 1000000000.0
	var first_gone:= -1000000000.0
	for i in ids.size():
		if left.has(ids [i]):
			last_left = minf(last_left, at [i])
		else:
			gone += 1
			first_gone = maxf(first_gone, at [i])
	print("  belts carrying now       : %d" % after)
	print("  wads folded away         : %d" % gone)
	print("  hay_total %.1f -> %.1f  (%d wads of %d strands is %d)"
		% [hay_before, GameState.hay_total, gone, STRANDS, gone * STRANDS])

	_ok("the belts came down to the cap", after == Cfg.belt_cap)


	var said: String = world.hud.toast_text() if world.hud != null else ""
	print("  toast                    : %s" % said)
	_ok("...and the player was told the belts are full",
		said.begins_with("THE THINGS ON YOUR BELTS REACHED THE LIMIT OF %d" % Cfg.belt_cap))

	_ok("...and BELTS FULL is up in the corner",
		world.hud != null and world.hud.belts_full_cap() == Cfg.belt_cap)


	_ok("...and stopped there rather than clearing the deck", gone == SHED_BY)
	_ok("...the load nearest the end of the run is still on it", left.has(ids [leader]))
	print("  furthest one folded away : s %.2f" % first_gone)
	print("  nearest one still riding : s %.2f" % last_left)
	_ok("...and everything folded away was behind everything left",
		gone == 0 or first_gone < last_left)


	var back:= GameState.hay_total - hay_before
	_ok("the hay in them came back to the pile, exactly",
		absf(back - float(gone * STRANDS)) < LEDGER_EPS)


func _check_a_needle_is_spared() -> void:
	print("\n=== a needle at the back of the queue ===")
	var tail:= _tail_of_the_run()
	var pin: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), tail), { "strands": STRANDS, "needle": 0 })
	if pin == null:
		_ok("could spawn a wad with a needle in it", false)
		return
	LiveStrandManager.release_hold(pin)
	await _spin(120)


	var pinned:= _needle_aboard()
	if not _ok("the wad with the needle in it is aboard", pinned >= 0):
		return

	var before:= BeltPath.belt_load()
	var others:= _belt.riders_debug().size() - 1


	Cfg.belt_cap = before - 2
	print("  cap dropped to %d, needle is the last thing aboard" % Cfg.belt_cap)
	await _spin(WAIT)

	_ok("the needle is still riding", _needle_aboard() == pinned)
	_ok("...and the shed took the loads in front of it instead",
		BeltPath.belt_load() <= Cfg.belt_cap and others > 0)


func _needle_aboard() -> int:
	for r: Dictionary in _belt.riders_debug():
		if int(r.get("needle", -1)) >= 0:
			return int(r ["seq"])
	return -1


func _check_the_switch() -> void:
	print("\n=== the cap switched off ===")
	Cfg.belt_decay = false
	Cfg.belt_cap = Cfg.BELT_CAP_MIN
	var before:= BeltPath.belt_load()
	var hay_before:= GameState.hay_total
	print("  cap %d against a load of %d, and switched off"
		% [Cfg.belt_cap, before])
	await _spin(WAIT)
	print("  belts carrying now       : %d" % BeltPath.belt_load())
	_ok("nothing was folded away with the cap switched off",
		BeltPath.belt_load() == before)
	_ok("...and the pile ledger did not move",
		absf(GameState.hay_total - hay_before) < LEDGER_EPS)


func _load_the_run() -> Array [Carryable]:
	var out: Array [Carryable] = []
	for i in WADS:
		var w: Carryable = world.props.spawn("hay_wad", Transform3D(Basis(),
			Vector3(13.0, 1.15, DROP_Z + float(i) * DROP_STEP)),
			{ "strands": STRANDS })
		if w != null:


			LiveStrandManager.release_hold(w)
			out.append(w)
	await _spin(160)
	return out


func _tip_hay_onto(_run: Conveyor) -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []


	var live: LiveStrandManager = world.live
	var along:= (LOOSE_B - LOOSE_A).normalized()
	var across:= Vector3.UP.cross(along).normalized()


	var deck:= LOOSE_B - along * 0.6
	for i in STRAW:
		var lane:= i % STRAW_LANES
		var step:= i / STRAW_LANES
		var at:= deck - along * (float(step) * STRAW_PITCH) + across * ((float(lane) - float(STRAW_LANES - 1) * 0.5) * 0.11)
		at.y = LOOSE_A.y + 0.06
		var b:= live.spawn(at, Basis(), Vector3.ZERO,
			Color(0.86, 0.72, 0.38))
		if b != null:
			out.append(b)
	return out


func _tail_of_the_run() -> Vector3:
	return Vector3(13.0, 1.15, BELT_A.z + 0.4)


func _spin(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _ok(what: String, condition: bool) -> bool:
	if condition:
		_pass += 1
		print("  ok : %s" % what)
	else:
		_fail += 1
		print("  NO : %s" % what)
	return condition


func _finish() -> void:
	Cfg.belt_cap = _was_cap
	Cfg.belt_decay = _was_decay
	get_tree().quit(1 if _fail > 0 else 0)
