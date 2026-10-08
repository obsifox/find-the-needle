class_name DevJamProbe
extends Node


var world: Node3D
var player: Node3D

const SETTLE_FRAMES:= 40


const LANE_X:= 13.0


const FEED_RUN:= 6.0

const RIDE_TIMEOUT:= 25.0


const WATCH_FRAMES:= 60


const STILL:= 0.002

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(400000.0)
	await _settle()

	await _case_pelletizer()
	await _case_paper_mill()
	await _case_pulper()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_pelletizer() -> void:
	print("\n=== the pelletizer ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mill: HayPelletizer = world.builds.add_pelletizer(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	await _settle()
	var run: Conveyor = _feed_run(mill.intake_port(), mill.forward())
	await _settle()
	_check("the run feeding it hands hay to the intake stub", run != null)
	_check("...and the stub itself hands nothing on, being a terminus",
		mill.deck() != null and mill.deck().downstream == null)


	var fed: bool = await _rides_in(mill.intake_port(), mill.forward(), "hay_wad")
	_check("a wad rides in and is eaten (buffer %d)" % mill.stored, fed)

	var slab:= await _parks(mill.deck(), mill.intake_port(), mill.forward(),
		"hay_pulp")
	_check("a pulp slab rides in and is NOT eaten", slab != null)
	if slab == null:
		await _teardown(mill, run)
		return
	_check("...it is parked on the mill's own stub, never let go",
		mill.deck().carries(slab))
	_check("...and frozen, which is what a rider is", slab.freeze)
	var drift:= await _watch(slab)
	_check("...and it does not move: %.4f m over a second (want under %.3f)"
		% [drift, STILL], drift < STILL)
	var short_by:= _short_of(slab, mill.port_in(), mill.forward())
	_check("...stopping %.2f m short of the lip rather than past it" % short_by,
		short_by > 0.0)
	_check("the mill says what is wrong ('%s')" % mill.alert_reason(),
		mill.alert_reason().begins_with("WRONG LOAD"))
	_check("...and names the load in it", "pulp" in mill.alert_reason().to_lower())


	var second: bool = await _rides_in(mill.intake_port(), mill.forward(),
		"hay_wad")
	_check("a wad still gets in past the parked slab", second)


	world.props.remove(slab)
	await _settle()
	_check("picking the slab up clears the alert ('%s')" % mill.alert_reason(),
		not mill.alert_reason().begins_with("WRONG LOAD"))

	await _teardown(mill, run)


func _case_paper_mill() -> void:
	print("\n=== the paper mill ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mill: PaperMachine = world.builds.add_paper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	await _settle()
	var run: Conveyor = _feed_run(mill.port_in(), mill.forward())
	await _settle()

	var fed: bool = await _rides_in(mill.port_in(), mill.forward(), "hay_pulp")
	_check("a slab rides in and is eaten (queue %d)" % mill.queued.size(), fed)


	var roll:= await _parks(mill.deck(), mill.port_in(), mill.forward(),
		"paper_roll")
	_check("a paper roll rides in and is NOT eaten", roll != null)
	if roll == null:
		await _teardown(mill, run)
		return
	_check("...it is parked on the mill's own stub, never let go",
		mill.deck().carries(roll))
	var drift:= await _watch(roll)
	_check("...and it does not move: %.4f m over a second" % drift,
		drift < STILL)
	var short_by:= _short_of(roll, mill.feed_point(), mill.forward())
	_check("...stopping %.2f m short of the lip rather than past it" % short_by,
		short_by > 0.0)
	_check("the mill says what is wrong ('%s')" % mill.alert_reason(),
		mill.alert_reason().begins_with("WRONG LOAD"))

	var second: bool = await _rides_in(mill.port_in(), mill.forward(), "hay_pulp")
	_check("a slab still gets in past the parked roll", second)


	var stub: BeltPath = mill.deck()
	var straw: RigidBody3D = _spawn_strand(mill.port_in(), mill.forward())
	_check("a strand can be put on the deck to try it", straw != null)
	if straw != null:


		var gone:= func() -> bool: return not is_instance_valid(straw) or not stub.carries(straw)
		await _wait_for(gone, RIDE_TIMEOUT)
		_check("...and loose hay is still let go at the lip rather than held",
			not is_instance_valid(straw) or not stub.carries(straw))

	world.props.remove(roll)
	await _teardown(mill, run)


func _case_pulper() -> void:
	print("\n=== the pulper ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	await _settle()
	var run: Conveyor = _feed_run(pulper.port_in(), pulper.forward())
	await _settle()

	var fed: bool = await _rides_in(pulper.port_in(), pulper.forward(), "hay_wad")
	_check("a wad rides in and is eaten (buffer %d)" % pulper.stored, fed)

	var roll:= await _parks(pulper.deck(), pulper.port_in(),
		pulper.forward(), "paper_roll")
	_check("a paper roll rides in and is NOT eaten", roll != null)
	if roll == null:
		await _teardown(pulper, run)
		return
	_check("...it is parked on the pulper's own stub, never let go",
		pulper.deck().carries(roll))
	var drift:= await _watch(roll)
	_check("...and it does not move: %.4f m over a second" % drift,
		drift < STILL)


	var short_by:= _short_of(roll, pulper.feed_point(), pulper.forward())
	_check("...stopping %.2f m short of the lip rather than past it" % short_by,
		short_by > 0.0)
	_check("the pulper says what is wrong ('%s')" % pulper.alert_reason(),
		pulper.alert_reason().begins_with("WRONG LOAD"))

	var second: bool = await _rides_in(pulper.port_in(), pulper.forward(),
		"hay_wad")
	_check("a wad still gets in past the parked roll", second)

	world.props.remove(roll)
	await _teardown(pulper, run)


func _teardown(machine: Node3D, run: Conveyor) -> void:
	await _settle(5)
	if run != null:
		world.builds.demolish(run)
	var why: String = world.builds.demolish_blocked_reason(machine)
	world.builds.demolish(machine)
	await _settle()
	_check("the machine and its run come back out of the yard%s"
		% ("" if why == "" else " (refused: %s)" % why),
		not is_instance_valid(machine) and not is_instance_valid(run))


func _short_of(body: Node3D, lip: Vector3, fwd: Vector3) -> float:
	return - (body.global_position - lip).dot(fwd)


func _feed_run(attach: Vector3, fwd: Vector3) -> Conveyor:
	var run: Conveyor = world.builds.add_conveyor(attach - fwd * FEED_RUN, attach)
	return run


func _rides_in(attach: Vector3, fwd: Vector3, id: String) -> bool:
	var item:= _spawn_on_run(attach, fwd, id)
	if item == null:
		return false


	var eaten:= func() -> bool: return _loads_of(id) == 0
	await _wait_for(eaten, RIDE_TIMEOUT)
	await _settle(10)
	return _loads_of(id) == 0


func _loads_of(id: String) -> int:
	var n:= 0
	for p in world.props.items:
		if is_instance_valid(p) and p.is_inside_tree() and p.item_id == id:
			n += 1
	for path in BeltPath._live:
		if not is_instance_valid(path):
			continue
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
				n += 1
	return n


func _waiting_of(stub: BeltPath, id: String) -> Carryable:
	var w:= stub.waiting_rider() as Carryable
	return w if w != null and w.item_id == id else null


func _parks(stub: BeltPath, attach: Vector3, fwd: Vector3,
		id: String) -> Carryable:
	var item:= _spawn_on_run(attach, fwd, id)
	if item == null:
		return null


	var parked:= func() -> bool: return _waiting_of(stub, id) != null
	await _wait_for(parked, RIDE_TIMEOUT)


	await _settle(20)
	return _waiting_of(stub, id)


func _spawn_on_run(attach: Vector3, fwd: Vector3, id: String) -> Carryable:
	var at:= attach - fwd * (FEED_RUN * 0.5) + Vector3(0.0, 0.15, 0.0)
	return world.props.spawn(id, Transform3D(Basis(), at))


func _spawn_strand(attach: Vector3, fwd: Vector3) -> RigidBody3D:
	var at:= attach - fwd * (FEED_RUN * 0.5) + Vector3(0.0, 0.15, 0.0)
	var body: RigidBody3D = world.live.spawn(at, Basis(), Vector3.ZERO,
		Cfg.COL_HAY_LIGHT)
	return body


func _watch(body: Node3D) -> float:
	var from:= body.global_position
	var worst:= 0.0
	for i in WATCH_FRAMES:
		await get_tree().physics_frame
		if not is_instance_valid(body):
			return INF
		worst = maxf(worst, body.global_position.distance_to(from))
	return worst


func _settle(frames: int = SETTLE_FRAMES) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait_for(cond: Callable, timeout: float) -> void:
	var spent:= 0.0
	while spent < timeout:
		if bool(cond.call()):
			return
		await get_tree().physics_frame
		spent += 1.0 / 60.0


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
