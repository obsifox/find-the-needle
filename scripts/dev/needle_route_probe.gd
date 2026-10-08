class_name DevNeedleRouteProbe
extends Node


var world: Node3D

const SETTLE:= 8


const FAR:= Vector3(-14.0, 0.06, -9.0)


const FAR_B:= Vector3(-14.0, 0.06, -3.0)

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:


	world.block_save = true
	reparent(get_tree().root)
	print("--- needle route probe ---")
	GameState.add_money(500000.0)
	for i in SETTLE:
		await get_tree().process_frame

	await _case_the_lorry_bed()
	await _case_scanner_eats_a_wad()
	await _case_press_eats_a_wad()
	await _case_mill_eats_a_wad()
	await _case_container_eats_a_wad()
	await _case_wrapper_saved_between_wraps()
	await _case_scanner_saved_mid_cycle()
	await _case_scanner_saved_mid_flight()
	await _case_scanner_demolished_holding_a_block()

	print("\n=== needle route probe: %s ===" % [
		"PASS" if _fails == 0 else "%d FAILURE(S)" % _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _case_the_lorry_bed() -> void:
	print("\n=== a block with a needle in it, set in the lorry's bed ===")
	var truck: DeliveryTruck = world.truck
	if truck == null or world.deliveries == null:
		_fail("the yard has no lorry to load")
		return
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	truck.snap_parked()
	await _frames(SETTLE)

	var clean: Carryable = world.props.spawn("hay_bale",
		Transform3D(Basis(), truck.loading_point() + Vector3(0.0, 0.45, 0.0)))
	var was:= GameState.contract_delivered
	var took:= await _until(func() -> bool:
		return GameState.contract_delivered > was, 400)
	print("  a clean bale in the bed: delivered went %d to %d"
		% [was, GameState.contract_delivered])
	_ok(took, "an ordinary bale in the bed is loaded")
	if clean != null and is_instance_valid(clean):
		world.props.remove(clean)

	var counted:= GameState.contract_delivered
	var buried:= GameState.needles_buried()
	var heard:= [0]
	var listener:= func(_t: int, _paid: float,
		_cause: GameState.NeedleLoss) -> void: heard [0] += 1
	GameState.needle_lost.connect(listener)
	var loaded:= _block_holding("hay_bale", truck.loading_point()
		+ Vector3(0.0, 0.45, 0.0), index)
	if loaded == null:
		GameState.needle_lost.disconnect(listener)
		return
	var loaded_id:= loaded.get_instance_id()
	var gone:= await _until(func() -> bool:
		return not is_instance_id_valid(loaded_id), 400)


	await _frames(240)
	GameState.needle_lost.disconnect(listener)
	print("  a bale with a needle in it: delivered %d (was %d), the bale %s, needle_lost fired %d time(s), %d buried (was %d)"
		% [GameState.contract_delivered, counted, "went out" if gone else "is still in the bed",
			heard [0], GameState.needles_buried(), buried])
	_ok(gone, "the lorry loads it like any other bale")
	_ok(GameState.contract_delivered > counted, "...and counts it, because it did not look")
	_ok(heard [0] == 1, "...and says once that the needle went with it")
	_ok(GameState.needles_buried() == buried + 1, "...which puts one of the type back in the stack")
	_ok(_safe(type), "...so the type is still somewhere the player can get it")

	truck.depart()
	await _frames(SETTLE)


func _case_scanner_eats_a_wad() -> void:
	print("\n=== a scanner is fed a wad with a needle in it ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var scanner: HaystackScanner = world.builds.add_scanner(FAR, 0.0)
	if scanner == null:
		_fail("could not stand a scanner up")
		return
	await _frames(SETTLE)
	var at:= scanner.port_in() + scanner.forward() * 0.5 + Vector3(0.0, 0.3, 0.0)
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
		{ "strands": 40, "needle": index }) as HayWad
	if wad == null or not wad.holds_needle():
		_fail("could not drop a loaded wad in the mouth")
		return


	var wad_id:= wad.get_instance_id()
	var eaten:= await _until(func() -> bool:
		return not is_instance_id_valid(wad_id), 400)
	var holds:= await _until(func() -> bool:
		return index in scanner.held_needles(), 400)
	print("  the wad %s, the machine holds %s, drawer %s"
		% ["went in" if eaten else "is still standing", scanner.held_needles(),
			scanner.banked])
	_ok(eaten, "the scanner swallows the wad")
	_ok(holds, "...and keeps what was inside it")
	_ok(_safe(type), "...so the type is still somewhere the player can get it")
	await _hand_back("the scanner", scanner, type)


func _case_press_eats_a_wad() -> void:
	print("\n=== a press is fed a wad with a needle in it ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var press: HayCompressor = world.builds.add_compressor(FAR, 0.0)
	if press == null:
		_fail("could not stand a press up")
		return
	await _frames(SETTLE)
	await _feed_wad("the press", press, press._mouth(), index, type)
	await _hand_back("the press", press, type)


func _case_mill_eats_a_wad() -> void:
	print("\n=== a mill is fed a wad with a needle in it ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var mill: HayPelletizer = world.builds.add_pelletizer(FAR, 0.0)
	if mill == null:
		_fail("could not stand a mill up")
		return
	await _frames(SETTLE)
	await _feed_wad("the mill", mill, mill._mouth(), index, type)
	await _hand_back("the mill", mill, type)


func _case_container_eats_a_wad() -> void:
	print("\n=== a bucket is loaded from a wad with a needle in it ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var tub:= world.props.spawn("bucket",
		Transform3D(Basis(), FAR_B)) as HayContainer
	if tub == null:
		_fail("could not set a bucket down")
		return
	await _frames(SETTLE)
	var mouth:= tub.global_position + Vector3(0.0, 0.35, 0.0)

	var clean:= world.props.spawn("hay_wad", Transform3D(Basis(), mouth),
		{ "strands": 30 }) as HayWad
	var drank:= await _until(func() -> bool: return tub.stored > 0, 400)
	print("  a clean wad over the bucket: it holds %d strands" % tub.stored)
	_ok(drank, "an ordinary wad loads the bucket")
	if clean != null and is_instance_valid(clean):
		clean.queue_free()
	await _frames(SETTLE)

	var before:= tub.stored
	var loaded:= world.props.spawn("hay_wad", Transform3D(Basis(), mouth),
		{ "strands": 30, "needle": index }) as HayWad
	if loaded == null or not loaded.holds_needle():
		_fail("could not drop a loaded wad in the bucket")
		return
	await _frames(240)
	print("  a wad with a needle in it: the wad %s, the bucket holds %d (was %d)"
		% ["is still there" if is_instance_valid(loaded) else "GONE",
			tub.stored, before])
	_ok(is_instance_valid(loaded), "a bucket leaves a wad with a needle in it alone")
	_ok(tub.stored == before, "...and takes none of its hay")
	_ok(_safe(type), "...so the type is still somewhere the player can get it")

	if is_instance_valid(loaded):
		loaded.needle_index = -1
		loaded.queue_free()
	world.props.remove(tub)
	await _frames(SETTLE)


func _case_wrapper_saved_between_wraps() -> void:
	print("\n=== a wrapper saved between two wraps ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var wrap: HayWrapper = world.builds.add_wrapper(FAR, 0.0)
	if wrap == null:
		_fail("could not stand a wrapper up")
		return
	await _frames(SETTLE)
	wrap.queued.append(Cfg.COMPRESSOR_BALE_STRANDS)
	wrap.queued_needles.append(index)
	var made:= await _until(func() -> bool:
		return _blocks_holding(index) > 0, 900)
	var idle:= await _until(func() -> bool: return not wrap.is_wrapping(), 900)
	print("  the wrap ran: %d bale(s) in the world hold it, machine holds %s, idle %s"
		% [_blocks_holding(index), wrap.held_needles(), idle])
	_ok(made, "the needle comes out of the machine inside the foiled bale")
	_ok(idle, "...and the cycle finishes")
	_ok(wrap.held_needles().is_empty(),
		"...leaving the machine holding nothing")
	_ok(int(wrap.to_dict().get("wrapping_needle", -1)) == -1,
		"...and saving nothing about a bale it has already shipped")


	wrap.from_dict(wrap.to_dict())
	await _frames(SETTLE)
	print("  after a save and a load: machine holds %s, %d bale(s) in the world hold it"
		% [wrap.held_needles(), _blocks_holding(index)])
	_ok(wrap.held_needles().is_empty(),
		"a reload does not hand the machine back a needle it shipped")
	_ok(_blocks_holding(index) == 1, "...and there is still exactly one of it")

	var announced:= _listen()
	world.builds.demolish(wrap)
	await _frames(SETTLE)
	_hush(announced)
	print("  the idle wrapper came down: needle_lost %s"
		% ["fired" if announced [0] else "silent"])
	_ok(not announced [0],
		"demolishing an idle wrapper announces no loss it did not have")
	_ok(_blocks_holding(index) == 1 and _safe(type),
		"...and does not bury a second one of the type")
	_clear_blocks(index)


func _case_scanner_saved_mid_cycle() -> void:
	print("\n=== a scanner saved with a needle in the sweep ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var scanner: HaystackScanner = world.builds.add_scanner(FAR, 0.0)
	if scanner == null:
		_fail("could not stand a scanner up")
		return
	await _frames(SETTLE)
	var drop:= scanner.port_in() + scanner.forward() * 0.5 + Vector3(0.0, 0.2, 0.0)
	var body: RigidBody3D = world.live.reveal_needle(index, drop)
	if body == null:
		_fail("could not put a needle in the mouth")
		return
	var body_id:= body.get_instance_id()
	var swallowed:= await _until(func() -> bool:


		scanner._cycle_left = maxf(scanner._cycle_left, 99.0)
		return not is_instance_id_valid(body_id), 400)
	print("  the needle went in: pending %s, drawer %s, stock %d, loose %d, stored %d"
		% [scanner._pending, scanner.banked, GameState.stock_of(type),
			world.live.needles.size(), scanner.stored])
	_ok(swallowed, "the scanner takes the needle off the belt")
	_ok(index in scanner._pending, "...into the running sweep rather than the drawer")
	var saved: PackedInt32Array = scanner.to_dict().get("banked", PackedInt32Array())
	_ok(index in saved, "...and the save writes it down anyway")

	var yard: Array = world.builds.to_array()
	world.builds.from_array(yard)
	await _frames(SETTLE)
	var back: HaystackScanner = null
	for s: HaystackScanner in world.builds.scanners:
		back = s
	print("  after a save and a load: %d scanner(s), drawer %s"
		% [world.builds.scanners.size(), back.banked if back != null else "none"])
	_ok(back != null and index in back.banked,
		"the needle comes back in the drawer, where E gets it")
	_ok(_safe(type), "...so the type is still somewhere the player can get it")
	if back != null:
		_ok(world.builds.demolish_blocked_reason(back) != "",
			"...and the machine will not come down until it has been emptied")
		back.banked = PackedInt32Array()
		world.builds.demolish(back)
	await _frames(SETTLE)


func _case_scanner_saved_mid_flight() -> void:
	print("\n=== a scanner saved with a mote in the air ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var scanner: HaystackScanner = world.builds.add_scanner(FAR, 0.0)
	if scanner == null:
		_fail("could not stand a scanner up")
		return
	await _frames(SETTLE)
	scanner.banked.append(index)
	var was:= GameState.stock_of(type)
	scanner._spill()
	var saved: PackedInt32Array = scanner.to_dict().get("banked", PackedInt32Array())
	print("  E was pressed: drawer %s, save %s, machine holds %s"
		% [scanner.banked, saved, scanner.held_needles()])
	_ok(scanner.banked.is_empty(), "the drawer lets go the instant E is pressed")
	_ok(index in saved, "...and the save carries the needle that is still flying")
	_ok(index in scanner.held_needles(),
		"...and the machine still admits to holding it")

	await _frames(300)
	var landed: PackedInt32Array = scanner.to_dict().get("banked", PackedInt32Array())
	print("  the mote landed: stock of the type went %d to %d, save %s"
		% [was, GameState.stock_of(type), landed])
	_ok(GameState.stock_of(type) > was, "the mote arrives in the drawers")
	_ok(not (index in landed), "...and the save stops carrying it once it has")
	_ok(scanner.held_needles().is_empty(),
		"...and the machine stops holding it too")
	world.builds.demolish(scanner)
	await _frames(SETTLE)


func _case_scanner_demolished_holding_a_block() -> void:
	print("\n=== a scanner demolished with a block inside it ===")
	var type:= _fresh_lot_type()
	if type < 0:
		return
	var index:= _bury(type)
	var scanner: HaystackScanner = world.builds.add_scanner(FAR, 0.0)
	if scanner == null:
		_fail("could not stand a scanner up")
		return
	await _frames(SETTLE)
	var at:= scanner.port_in() + scanner.forward() * (HaystackScanner.INTAKE_LENGTH * 0.5) + Vector3.UP * 0.2
	var bale:= _block_holding("hay_bale", at, index)
	if bale == null:
		return
	var taken:= await _until(func() -> bool: return scanner.has_block(), 400)
	print("  the bale %s, the machine holds %s"
		% ["went in" if taken else "is still standing", scanner.held_needles()])
	_ok(taken, "the scanner takes the block off the deck")
	_ok(index in scanner.held_needles(), "...and says what is inside it")

	var reason: String = world.builds.demolish_blocked_reason(scanner)
	var announced:= _listen()
	world.builds.demolish(scanner)
	await _frames(SETTLE)
	_hush(announced)
	var stood:= is_instance_valid(scanner) and not scanner.is_queued_for_deletion()
	print("  demolition: blocked_reason %s, %s, needle_lost %s"
		% ["\"%s\"" % reason if reason != "" else "(none)",
			"still standing" if stood else "came down",
			"fired" if announced [0] else "silent"])
	_ok(reason != "" or announced [0],
		"it is either refused or announced, never both silent")
	_ok(_safe(type), "...and the type is still somewhere the player can get it")
	if stood:
		scanner.banked = PackedInt32Array()
		scanner.blocks.clear()
		world.builds.demolish(scanner)
	_clear_blocks(index)
	await _frames(SETTLE)


func _feed_wad(what: String, machine: Node3D, mouth: Vector3, index: int,
		type: int) -> void:
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), mouth),
		{ "strands": 40, "needle": index }) as HayWad
	if wad == null or not wad.holds_needle():
		_fail("could not drop a loaded wad in %s" % what)
		return

	var wad_id:= wad.get_instance_id()
	var eaten:= await _until(func() -> bool:
		return not is_instance_id_valid(wad_id), 400)
	var holds:= await _until(func() -> bool:
		return index in machine.call("held_needles"), 200)
	print("  the wad %s, %s holds %s"
		% ["went in" if eaten else "is still standing", what,
			machine.call("held_needles")])
	_ok(eaten, "%s swallows the wad" % what)
	_ok(holds, "...and keeps what was inside it")
	_ok(_safe(type), "...so the type is still somewhere the player can get it")


func _hand_back(what: String, machine: Node3D, type: int) -> void:
	var reason: String = world.builds.demolish_blocked_reason(machine)
	var announced:= _listen()
	world.builds.demolish(machine)
	await _frames(SETTLE)
	_hush(announced)
	var stood:= is_instance_valid(machine) and not machine.is_queued_for_deletion()
	print("  %s came down: blocked_reason %s, %s, needle_lost %s"
		% [what, "\"%s\"" % reason if reason != "" else "(none)",
			"still standing" if stood else "came down",
			"fired" if announced [0] else "silent"])
	_ok(reason != "" or announced [0], "...and %s cannot be taken down over it in silence" % what)
	_ok(_safe(type), "...so the type survives the demolition too")
	if stood:


		_disarm(machine)
		world.builds.demolish(machine)
		await _frames(SETTLE)
		_ok(not (is_instance_valid(machine) and not machine.is_queued_for_deletion()),
			"...and %s comes down once it is empty, leaving the stand clear" % what)


func _listen() -> Array:
	var heard:= [false]
	var f:= func(_t: int, _paid: float, _cause: GameState.NeedleLoss) -> void:
		heard [0] = true
	heard.append(f)
	GameState.needle_lost.connect(f)
	return heard


func _hush(heard: Array) -> void:
	GameState.needle_lost.disconnect(heard [1])


func _disarm(machine: Node3D) -> void:


	for field in ["pending_needles", "queued_needles", "banked", "_pending",
			"_flying", "queued", "blocks"]:
		if field in machine:
			machine.set(field, machine.get(field).slice(0, 0))
	for field in ["stored", "_outgoing"]:
		if field in machine:
			machine.set(field, 0)


func _blocks_holding(index: int) -> int:
	var n:= 0
	for item: Carryable in world.props.items:
		if is_instance_valid(item) and item.needle_index == index:
			n += 1
	return n


func _clear_blocks(index: int) -> void:
	for item: Carryable in world.props.items.duplicate():
		if is_instance_valid(item) and item.needle_index == index:
			item.needle_index = -1
			world.props.remove(item)


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


func _safe(type: int) -> bool:
	if _still_reachable(type):
		return true
	if GameState.stock_of(type) > 0:
		return true
	return _machine_holds(type)


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


func _machine_holds(type: int) -> bool:
	for child in world.builds.get_children():
		if not child.has_method("held_needles"):
			continue
		for index: int in child.call("held_needles"):
			if GameState.type_of(index) == type:
				return true
	return false


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _until(test: Callable, limit: int) -> bool:
	for _i in limit:
		if bool(test.call()):
			return true
		await get_tree().physics_frame
	return bool(test.call())


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    %s" % what)
	else:
		_fails += 1
		print("  FAIL  %s" % what)


func _fail(what: String) -> void:
	_fails += 1
	print("  FAIL  %s" % what)
