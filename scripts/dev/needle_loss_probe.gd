class_name DevNeedleLossProbe
extends Node


var world: Node3D

const SETTLE:= 8


const FAR:= Vector3(-14.0, 0.06, -9.0)

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:


	world.block_save = true
	reparent(get_tree().root)
	print("--- needle loss probe ---")
	GameState.add_money(500000.0)
	for i in SETTLE:
		await get_tree().process_frame

	await _case_a_needle_left_on_the_floor_is_saved()
	await _case_the_drain_eats_a_block()
	await _case_press_demolished()
	await _case_wrapper_demolished()
	await _case_silo_demolished()
	await _case_launcher_demolished()
	await _case_generator_burns_one()
	await _case_lost_with_the_stack_dug_out()

	_case_a_withdrawn_needle_that_burns_stays_burnt()

	print("\n=== needle loss probe: %s ===" % [
		"PASS" if _fails == 0 else "%d FAILURE(S)" % _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _case_a_needle_left_on_the_floor_is_saved() -> void:
	print("\n=== a needle left lying on the floor, through a save and a load ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var body: RigidBody3D = world.live.reveal_needle(index, FAR + Vector3.UP * 0.4)
	if body == null:
		_fail("could not put a needle on the floor")
		return
	for i in SETTLE:
		await get_tree().physics_frame
	print("  one needle of type %d on the floor, %d in the pile"
		% [type, GameState.needles_buried()])
	_ok(_still_reachable(type), "it is reachable before the save")


	var was_at:= body.global_position
	world._gather_loose_needles()
	var sheet: Dictionary = GameState.to_dict()
	var yard: Array = world.builds.to_array()
	var loose: Array = world.props.to_array()
	_ok(sheet.has("needle_loose") and (sheet ["needle_loose"] as PackedInt32Array).size() == 1,
		"the save carries the one needle that was on the floor")


	for b in world.live.needles.duplicate():
		world.live.consume_needle(b)
	GameState.from_dict(sheet)
	world.builds.from_array(yard)
	world.props.from_array(loose)
	world._restore_loose_needles()
	for i in SETTLE:
		await get_tree().process_frame

	print("  after the load: %d loose needles, %d in the pile, discovered %s"
		% [world.live.needles.size(), GameState.needles_buried(),
			GameState.is_discovered(type)])
	_ok(_still_reachable(type),
		"a needle left on the floor is still reachable after a load")
	_ok(world.live.needles.size() == 1,
		"...as a body, not as a line in the ledger")
	var now_at: Vector3 = world.live.needles [0].global_position if world.live.needles.size() == 1 else Vector3.INF


	_ok(now_at.distance_to(was_at) < 0.25,
		"...and lying where it was left (off by %.3f m)" % now_at.distance_to(was_at))

	world._restore_loose_needles()
	_ok(world.live.needles.size() == 1,
		"a second load does not put a second copy of it back")


func _case_the_drain_eats_a_block() -> void:
	print("\n=== the yard cap drain takes a block with a needle in it ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var bale:= _block_holding("hay_bale", FAR, index)
	if bale == null:
		return


	var litter: Array [Carryable] = []
	for i in 6:
		var w: Carryable = world.props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, FAR + Vector3(float(i) * 0.9, 0.0, 1.6)),
			{ "strands": 4 })
		if w != null:
			litter.append(w)


	for held in litter:
		LiveStrandManager.release_hold(held)
	LiveStrandManager.release_hold(bale)
	var was_cap:= Cfg.prop_cap
	Cfg.prop_cap = 2
	var announced:= [false]
	var heard:= func(_t: int, _paid: float,
			_cause: GameState.NeedleLoss) -> void: announced [0] = true
	GameState.needle_lost.connect(heard)
	for i in 30:
		world.props._drain_pass()
		await get_tree().physics_frame
	GameState.needle_lost.disconnect(heard)
	Cfg.prop_cap = was_cap

	var gone:= not is_instance_valid(bale)
	print("  the drain ran: %d props left, the bale %s, needle_lost %s"
		% [world.props.items.size(), "GONE" if gone else "survived",
			"fired" if announced [0] else "silent"])
	_ok(not gone or announced [0],
		"a block with a needle in it is spared, or its loss is announced")
	_ok(_still_reachable(type),
		"...and the type is still somewhere the player can reach it")

	if is_instance_valid(bale):
		bale.needle_index = -1
		world.props.remove(bale)
	for w in litter:
		if is_instance_valid(w):
			world.props.remove(w)


func _case_press_demolished() -> void:
	print("\n=== a press holding a needle is demolished ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var press: HayCompressor = world.builds.add_compressor(FAR, 0.0)
	if press == null:
		_fail("could not stand a press up")
		return
	press.pending_needles.append(index)
	await _demolition_holds("a press", press, type)


func _case_wrapper_demolished() -> void:
	print("\n=== a wrapper holding a needle is demolished ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var wrap: HayWrapper = world.builds.add_wrapper(FAR, 0.0)
	if wrap == null:
		_fail("could not stand a wrapper up")
		return
	wrap.queued_needles.append(index)
	await _demolition_holds("a wrapper", wrap, type)


func _case_silo_demolished() -> void:
	print("\n=== a silo holding a needle is demolished ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var tank: HaySilo = world.builds.add_silo(FAR, 0.0)
	if tank == null:
		_fail("could not stand a silo up")
		return
	tank.pending_needles.append(index)
	await _demolition_holds("a silo", tank, type)


func _case_launcher_demolished() -> void:
	print("\n=== a launcher holding a needle is demolished ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var tube: TubeLauncher = world.builds.add_tube_launcher(FAR, 0.0)
	if tube == null:
		_fail("could not stand a launcher up")
		return
	tube.pending_needles.append(index)
	await _demolition_holds("a launcher", tube, type)


func _case_generator_burns_one() -> void:
	print("\n=== a needle fed to a generator's firebox ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var gen: HayGenerator = world.builds.add_generator(FAR, 0.0)
	if gen == null:
		_fail("could not stand a generator up")
		return
	for i in SETTLE:
		await get_tree().process_frame
	var announced:= [0]
	var heard:= func(_t: int, _paid: float,
			_cause: GameState.NeedleLoss) -> void: announced [0] += 1
	GameState.needle_lost.connect(heard)
	var bale:= _block_holding("hay_bale", gen.hopper_position(), index)
	if bale == null:
		GameState.needle_lost.disconnect(heard)
		return
	var eaten:= false
	for i in 240:
		await get_tree().physics_frame
		if not is_instance_valid(bale):
			eaten = true
			break
	GameState.needle_lost.disconnect(heard)
	print("  the bale %s, needle_lost fired %d time(s)"
		% ["went in" if eaten else "is still standing", announced [0]])
	_ok(eaten, "the firebox swallows the bale")
	_ok(announced [0] == 1, "...and announces the specimen that was inside it")
	_ok(_still_reachable(type),
		"...so the type is back in the stack and the run continues")
	_ok(not gen.to_dict().has("needles"),
		"a generator saves no ash pit, because it holds none")
	world.builds.demolish(gen)
	for i in SETTLE:
		await get_tree().process_frame


func _case_lost_with_the_stack_dug_out() -> void:
	print("\n=== a needle lost with the stack dug out ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return


	for b in world.live.needles.duplicate():
		world.live.consume_needle(b)
	var index:= _bury(type)
	var field: HayField = world.field
	var kept:= field.heights.duplicate()
	field.heights.fill(0.0)
	var buried:= GameState.needles_buried()
	GameState.lose_needle(index, type, 0.0, GameState.NeedleLoss.SCRAPPED)
	for i in SETTLE:
		await get_tree().physics_frame
	field.heights = kept
	print("  after the loss: %d loose needles, %d in the pile (was %d)"
		% [world.live.needles.size(), GameState.needles_buried(), buried])
	_ok(world.live.needles.size() == 1,
		"with nothing to bury it in, the type comes back as a body on the floor")
	_ok(_still_reachable(type),
		"...so the type is still somewhere the player can reach it")
	for b in world.live.needles.duplicate():
		world.live.consume_needle(b)


func _case_a_withdrawn_needle_that_burns_stays_burnt() -> void:
	print("\n[a withdrawn needle that is burned]")
	var type:= _fresh_lot_type()
	if type < 0:
		return


	GameState.deposit_needle(_bury(type), FAR)
	GameState.discover(type, FAR)
	var held:= GameState.stock_of(type)
	var ledger:= GameState.found_of(type)
	var found:= GameState.needles_found
	_ok(held == 1, "the cabinet holds one after the deposit")

	var index:= GameState.withdraw_needle(type, FAR)
	_ok(index >= 0, "and hands it back out on request")
	_ok(GameState.stock_of(type) == 0, "...leaving the drawer empty")


	GameState.lose_needle(index, type, 0.0, GameState.NeedleLoss.BURNED)
	_ok(not GameState.needle_out.has(index),
		"burning it strikes it off the withdrawal list")
	_ok(GameState.stock_of(type) == 0, "...and the drawer is still empty")

	var sheet:= GameState.to_dict()
	GameState.from_dict(sheet)
	_ok(GameState.stock_of(type) == 0,
		"and a save and a load do not put it back in the cabinet")
	_ok(GameState.found_of(type) == ledger and GameState.needles_found == found,
		"...while the record of having found it is untouched")


func _demolition_holds(what: String, machine: Node3D, type: int) -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var reason: String = world.builds.demolish_blocked_reason(machine)
	var announced:= [false]
	var heard:= func(_t: int, _paid: float,
			_cause: GameState.NeedleLoss) -> void: announced [0] = true
	GameState.needle_lost.connect(heard)
	world.builds.demolish(machine)
	for i in SETTLE:
		await get_tree().process_frame
	GameState.needle_lost.disconnect(heard)
	var stood:= is_instance_valid(machine) and not machine.is_queued_for_deletion()
	print("  %s: blocked_reason %s, %s, needle_lost %s" % [
		what, "\"%s\"" % reason if reason != "" else "(none)",
		"still standing" if stood else "came down",
		"fired" if announced [0] else "silent"])
	_ok(reason != "" or announced [0] or _still_reachable(type),
		"%s cannot be taken down with a needle in it without saying so" % what)
	_ok(_still_reachable(type),
		"...and the type is still somewhere the player can reach it")
	if is_instance_valid(machine) and not machine.is_queued_for_deletion():


		_disarm(machine)
		world.builds.demolish(machine)


func _disarm(machine: Node3D) -> void:
	for field in ["pending_needles", "ash_needles", "queued_needles", "banked"]:
		if field in machine:
			machine.set(field, machine.get(field).slice(0, 0))


func _fresh_lot_type() -> int:
	var pool:= NeedleTypes.pool(GameState.lot_tier)
	if pool.is_empty():
		_fail("the lot has no types in it")
		return -1
	while GameState.discovered.size() < NeedleTypes.count():
		GameState.discovered.append(0)
	var target: int = pool [0]
	for t in pool:
		GameState.discovered [t] = 0 if t == target else 1


	for i in GameState.needle_taken.size():
		if int(GameState.needle_type [i]) == target:
			GameState.needle_taken [i] = 1
	return target


func _bury(type: int) -> int:
	var index:= GameState.register_needle(FAR, null, type)
	GameState.needle_taken [index] = 1
	return index


func _block_holding(id: String, at: Vector3, index: int) -> Carryable:
	var item: Carryable = world.props.spawn(id, Transform3D(Basis.IDENTITY, at),
		{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
	if item == null:
		_fail("could not spawn a %s" % id)
		return null
	item.needle_index = index
	return item


func _still_reachable(type: int) -> bool:
	if GameState.is_discovered(type):
		return true
	for i in GameState.needle_taken.size():
		if GameState.needle_taken [i] == 0 and int(GameState.needle_type [i]) == type:
			return true
	var live: LiveStrandManager = world.live
	if live != null:
		for b in live.needles:
			if not is_instance_valid(b) or not b.has_meta("needle_index"):
				continue
			if GameState.type_of(int(b.get_meta("needle_index"))) == type:
				return true
	for item: Carryable in world.props.items:
		if not is_instance_valid(item) or not item.holds_needle():
			continue
		if GameState.type_of(item.needle_index) == type:
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    %s" % what)
	else:
		_fails += 1
		print("  FAIL  %s" % what)


func _fail(what: String) -> void:
	_fails += 1
	print("  FAIL  %s" % what)
