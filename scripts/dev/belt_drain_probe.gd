class_name DevBeltDrainProbe
extends Node


const BELT_A:= Vector3(13.0, 0.75, -5.0)
const BELT_B:= Vector3(13.0, 0.75, 5.0)


const WATCH:= Vector3(-13.0, 0.4, 13.0)


const DUMP:= Vector3(-13.0, 0.6, -13.0)

const ABANDONED:= Vector3(-4.0, 0.4, -13.0)


const TOWER:= Vector3(13.0, 0.0, -12.0)


const LEDGER_EPS:= 0.5

const BELT_STRANDS:= 40
const FILLER_STRANDS:= 23

const SETTLE:= 40


const WAIT_FRAMES:= 2500

var world: Node3D
var player: Player

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0
var _belt: Conveyor


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	_rng.seed = 20260901
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = WATCH
	GameState.add_money(50000.0)


	Cfg.belt_decay = true
	Cfg.belt_cap = Cfg.BELT_CAP_DEFAULT
	world.props.clear()
	await _spin(SETTLE)

	if not await _lay_the_belt():
		print("\n[beltdrain] FAIL: no belt to test against")
		get_tree().quit(1)
		return

	await _check_props_queued_on_a_deck()
	await _check_strands_queued_on_a_deck()
	await _check_a_load_on_the_stairs()
	await _check_the_floor_still_drains()

	print("\n=== belt drain probe: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _lay_the_belt() -> bool:
	_belt = world.builds.add_conveyor(BELT_A, BELT_B)
	if _belt == null:
		return false
	await _spin(SETTLE)
	_belt.set_drive_speed(0.0)
	await _spin(10)
	print("laid a %.1f m run and stopped it" % _belt.path_length())
	return true


func _check_props_queued_on_a_deck() -> void:
	print("\n=== wads queued on a stopped belt ===")
	world.props.clear()
	await _spin(20)


	var riding:= _drop_wads(17, 5.0, -0.58)
	await _spin(120)
	var queued:= _drop_wads(7, -4.88, 0.21)
	await _spin(120)

	var on_deck: Array [Carryable] = []
	var on_belt: Array [Carryable] = []
	var strays: Array [Carryable] = []
	for w in riding + queued:
		if not is_instance_valid(w):
			continue
		if BeltPath.is_rider(w):
			on_belt.append(w)
		elif _on_the_deck(w.global_position, _wad_half_width(w)):
			on_deck.append(w)
			on_belt.append(w)
		else:
			strays.append(w)
	var aboard: int = on_belt.size() - on_deck.size()


	for w in strays:
		world.props.remove(w)
	print("  wads that missed the run : %d, cleared out of the way" % strays.size())
	print("  wads spawned onto the run: %d" % (riding.size() + queued.size()))
	print("  ...riding                : %d" % aboard)
	print("  ...resting on the deck   : %d" % on_deck.size())
	for w in on_deck:
		var p:= w.global_position
		var at: Dictionary = _belt._nearest(p)
		print("      at (%.2f, %.2f, %.2f)  s %.2f  lift %+.3f  side %+.3f  held %s"
			% [p.x, p.y, p.z, float(at ["s"]), float(at ["lift"]),
			float(at ["side"]), LiveStrandManager.is_on_hold(w)])

	if not _ok("the belt turned some wads away and they are lying on its deck",
			on_deck.size() >= 2):
		return
	_ok("...and every one of them is outside the keep radius",
		_all_beyond(on_deck, Cfg.PROP_KEEP_DIST))


	var was_cap: int = Cfg.prop_cap


	Cfg.prop_cap = 0
	var hay_before:= GameState.hay_total
	var line_before: int = world.props.items.size()
	print("  cap dropped to %d against a line of %d" % [Cfg.prop_cap, line_before])
	await _spin(240)
	print("  props retired            : %d" % (line_before - world.props.items.size()))
	print("  hay_total %.1f -> %.1f" % [hay_before, GameState.hay_total])
	_ok("a yard that is nothing but a loaded belt loses nothing to the drain",
		world.props.items.size() == line_before)
	var still_there:= 0
	for w in on_belt:
		if is_instance_valid(w):
			still_there += 1
	_ok("...every wad on the run is still on it (%d of %d)"
		% [still_there, on_belt.size()], still_there == on_belt.size())
	_ok("...and the pile ledger does not move at all",
		_unmoved(hay_before))
	var riders: int = world.props.items.size() - world.props.yard_count()
	_ok("...and the wads riding the run are not counted against the yard (%d)"
		% riders, riders > 0)
	Cfg.prop_cap = was_cap


	var over:= on_deck.size() + 6
	var want: int = Cfg.prop_cap + over
	_fill_far(want - world.props.yard_count())
	await _spin(5)
	_ok("the yard is over its cap", world.props.yard_count() > Cfg.prop_cap)

	hay_before = GameState.hay_total
	var before: int = world.props.items.size()
	await _drain_until_settled()
	var went: int = before - world.props.items.size()
	var back:= GameState.hay_total - hay_before
	print("  props retired            : %d" % went)
	print("  hay_total %.1f -> %.1f  (+%.0f)" % [hay_before, GameState.hay_total, back])

	_ok("the drain actually ran", went > 0)
	var survived:= 0
	for w in on_deck:
		if is_instance_valid(w):
			survived += 1
	_ok("nothing queued on the deck was taken (%d of %d survived)"
		% [survived, on_deck.size()], survived == on_deck.size())
	_ok("what came back is the litter and nothing but the litter (%.0f, want %d)"
		% [back, went * FILLER_STRANDS],
		absf(back - float(went * FILLER_STRANDS)) < LEDGER_EPS)


func _check_strands_queued_on_a_deck() -> void:
	print("\n=== hay queued on a stopped belt ===")
	world.props.clear()
	await _spin(20)

	var hay: Array [RigidBody3D] = []


	for wave in 3:
		for i in 26:
			var b:= _drop_hay(Vector3(
				13.0 + _rng.randf_range(-0.16, 0.16),
				1.02,
				-4.7 + float(i) * 0.37 + _rng.randf_range(-0.05, 0.05)))
			if b != null:
				hay.append(b)
		await _spin(30)
	for wave in 8:
		for i in 12:
			var b:= _drop_hay(Vector3(
				13.0 + _rng.randf_range(-0.1, 0.1),
				1.02,
				-4.75 + _rng.randf_range(0.0, 1.1)))
			if b != null:
				hay.append(b)
		await _spin(24)


	await _spin(150)

	var on_deck: Array [RigidBody3D] = []


	var where: Array [Vector3] = []
	var aboard:= 0
	for b in hay:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.has_meta(LiveStrandManager.META_RIDER):
			aboard += 1
		elif _on_the_deck(b.global_position):
			on_deck.append(b)
			where.append(b.global_position)
	print("  strands dropped on the run: %d" % hay.size())
	print("  ...riding                 : %d" % aboard)
	print("  ...resting on the deck    : %d" % on_deck.size())

	if not _ok("the belt turned hay away and it is lying on its deck",
			on_deck.size() >= 5):
		return
	_ok("...and every strand of it is past the despawn distance",
		_all_beyond(on_deck, Cfg.STRAND_DESPAWN_DIST))

	var hay_before:= GameState.hay_total


	var was_on_deck: Array [bool] = []
	for i in on_deck.size():
		was_on_deck.append(true)
	var taken_off_deck:= 0
	var taken_on_deck:= 0


	for tick in 400:
		await get_tree().physics_frame
		for i in on_deck.size():
			var b: RigidBody3D = on_deck [i]
			if is_instance_valid(b) and b.is_inside_tree():
				was_on_deck [i] = _on_the_deck(b.global_position)
				continue
			if where [i] == Vector3.INF:
				continue
			if was_on_deck [i]:
				taken_on_deck += 1
				var at: Dictionary = _belt._nearest(where [i])
				print("      GONE off the deck: s %.2f of %.2f  lift %+.3f  side %+.3f"
					% [float(at ["s"]), _belt.path_length(),
					float(at ["lift"]), float(at ["side"])])
			else:
				taken_off_deck += 1
			where [i] = Vector3.INF

		for i in on_deck.size():
			var b: RigidBody3D = on_deck [i]
			if where [i] != Vector3.INF and is_instance_valid(b) and b.is_inside_tree():
				where [i] = b.global_position

	var survived: int = on_deck.size() - taken_on_deck - taken_off_deck
	var back:= GameState.hay_total - hay_before
	print("  strands still on the deck : %d of %d" % [survived, on_deck.size()])
	print("  ...taken while on the deck: %d" % taken_on_deck)
	print("  ...taken after leaving it : %d" % taken_off_deck)
	print("  hay_total %.1f -> %.1f  (+%.0f)" % [hay_before, GameState.hay_total, back])
	_ok("nothing queued on the deck was reclaimed", taken_on_deck == 0)


	_ok("the ledger moved by exactly the hay that had left the deck (%.0f, want %d)"
		% [back, taken_off_deck],
		absf(back - float(taken_off_deck)) < LEDGER_EPS)


func _check_a_load_on_the_stairs() -> void:
	print("\n=== a load being let down the stairs ===")
	world.props.clear()
	await _spin(20)

	var tower: HayStairs = world.builds.add_hay_stairs(TOWER, 0.0)
	if not _ok("a tower to test against", tower != null):
		return
	await _spin(SETTLE)


	var mouth:= tower.mouth_position()
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), mouth + Vector3(0.55, 1.0, 0.3)),
		{ "strands": BELT_STRANDS }) as HayWad
	if not _ok("a wad dropped into the funnel", wad != null):
		return

	var caught:= false
	var held_in_transit:= false
	var spared:= false
	var keep2: float = Cfg.PROP_KEEP_DIST * Cfg.PROP_KEEP_DIST
	for i in 900:
		await get_tree().physics_frame
		if not is_instance_valid(wad) or tower.in_transit() == 0:
			continue
		caught = true


		held_in_transit = LiveStrandManager.is_on_hold(wad)
		spared = not world.props._may_retire(wad, WATCH, keep2)
		break
	_ok("the machine took the wad over", caught)
	_ok("...and left its mark on it while it had it", held_in_transit)
	_ok("...so the drain refuses to touch it", spared)


	if is_instance_valid(wad):
		world.props.remove(wad)
	var floor_wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), ABANDONED + Vector3(2.0, 0.0, 0.0)),
		{ "strands": BELT_STRANDS }) as HayWad


	if floor_wad != null:
		LiveStrandManager.release_hold(floor_wad)
	await _spin(150)
	_ok("...and the same wad on bare floor is still the drain's to take",
		floor_wad != null and world.props._may_retire(floor_wad, WATCH, keep2))
	world.props.clear()


	world.builds.demolish(tower)
	await _spin(10)


func _check_the_floor_still_drains() -> void:
	print("\n=== hay abandoned on the floor ===")
	var loose: Array [RigidBody3D] = []
	for i in 40:
		var pos:= ABANDONED + Vector3(
			_rng.randf_range(-0.9, 0.9), 0.3, _rng.randf_range(-0.9, 0.9))
		var b:= _drop_hay(pos)
		if b != null:
			loose.append(b)

	await _spin(150)
	_ok("the floor hay is past the despawn distance too",
		_all_beyond(loose, Cfg.STRAND_DESPAWN_DIST))
	await _spin(400)

	var survived:= 0
	for b in loose:
		if is_instance_valid(b) and b.is_inside_tree():
			survived += 1
	print("  strands still on the floor: %d of %d" % [survived, loose.size()])
	_ok("the drain still takes hay left on the floor", survived < loose.size())


func _drop_wads(n: int, z0: float, step: float) -> Array [Carryable]:
	var out: Array [Carryable] = []
	for i in n:
		var w: Carryable = world.props.spawn("hay_wad", Transform3D(Basis(),
			Vector3(13.0, 1.15, z0 + float(i) * step)), { "strands": BELT_STRANDS })
		if w != null:
			out.append(w)
	return out


func _drop_hay(pos: Vector3) -> RigidBody3D:
	return world.live.spawn(pos, StrandFactory.random_strand_basis(_rng),
		Vector3.ZERO, Cfg.COL_HAY_LIGHT)


func _fill_far(n: int) -> void:
	for i in maxi(n, 0):
		var x:= float(i % 12) * 0.45
		var z:= float(i / 12) * 0.45
		var w: Carryable = world.props.spawn("hay_wad",
			Transform3D(Basis(), DUMP + Vector3(x, 0.0, z)),
			{ "strands": FILLER_STRANDS })
		if w != null:
			LiveStrandManager.release_hold(w)


func _on_the_deck(p: Vector3, half_w: float = Cfg.BELT_RIDE_HALF_W) -> bool:
	return absf(p.x - 13.0) <= half_w and p.z >= -5.4 and p.z <= 5.4 and p.y >= 0.55


func _wad_half_width(w: Carryable) -> float:
	var shape: Dictionary = BeltPath.load_shape(w)
	return maxf(0.0, Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T - float(shape ["reach"]))


func _unmoved(was: float) -> bool:
	return absf(GameState.hay_total - was) < LEDGER_EPS


func _all_beyond(bodies: Array, d: float) -> bool:
	for b in bodies:


		if not is_instance_valid(b) or not (b as Node3D).is_inside_tree():
			continue
		if (b as Node3D).global_position.distance_to(WATCH) < d:
			return false
	return true


func _drain_until_settled() -> void:
	var spent:= 0
	while spent < WAIT_FRAMES and world.props.yard_count() > Cfg.prop_cap:
		await get_tree().process_frame
		spent += 1


	await _spin(60)


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
