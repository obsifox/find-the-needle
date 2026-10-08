class_name DevMachineSeatProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 30

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	GameState.add_money(200000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	tool._reach = 14.0
	await _settle()


	print("\n=== front: a press aimed past the end of a run ===")
	var p:= Vector3(0.0, deck_y, 0.0)
	var into: Conveyor = builds.add_conveyor(p - Vector3(0.0, 0.0, 4.0), p)
	await _settle()
	tool._mode = BuildTool.Mode.COMPRESSOR
	await _drive(Vector3(0.1, 0.0, 1.1))
	tool._update_compressor_ghost()
	_check("buildable (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...its intake on the run's end (%.4f m)"
		% tool._compressor_ghost.port_in().distance_to(p),
		tool._compressor_ghost.port_in().distance_to(p) < 0.002)
	tool._place_compressor()
	await _settle()
	var front:= _press_at(builds, p, true)
	_check("the run hands to the press", front != null and into.downstream == front.deck())
	if front != null:
		builds.demolish(front)
	await _settle()


	print("\n=== back: a press aimed short of the head of a run ===")
	var q:= Vector3(6.0, deck_y, -4.0)
	var away: Conveyor = builds.add_conveyor(q, q + Vector3(0.0, 0.0, 4.0))
	await _settle()
	await _drive(Vector3(6.1, 0.0, -5.1))
	tool._update_compressor_ghost()
	_check("buildable (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...its outfeed on the run's head (%.4f m)"
		% tool._compressor_ghost.port_out().distance_to(q),
		tool._compressor_ghost.port_out().distance_to(q) < 0.002)
	tool._place_compressor()
	await _settle()
	var back:= _press_at(builds, q, false)
	_check("the press hands to the run", back != null and back.deck().downstream == away)
	if back != null:
		builds.demolish(back)
	builds.demolish(away)
	await _settle()


	print("\n=== the body decides, not the nearest end ===")


	var head:= p + Vector3(1.2, 0.0, 0.0)
	var side: Conveyor = builds.add_conveyor(head, head + Vector3(4.0, 0.0, 0.0))
	await _settle()
	var aim:= Vector3(0.7, 0.0, 0.8)
	_check("the crosshair is nearer the head (%.2f against %.2f)"
		% [_flat(aim, head), _flat(aim, p)], _flat(aim, head) < _flat(aim, p))
	await _drive(aim)
	tool._update_compressor_ghost()
	_check("...and the press still takes the end (%.4f m)"
		% tool._compressor_ghost.port_in().distance_to(p),
		tool._compressor_ghost.port_in().distance_to(p) < 0.002)
	builds.demolish(side)
	builds.demolish(into)
	await _settle()


	print("\n=== a pelletizer on a floor run's end climbs to its throat ===")


	tool._mode = BuildTool.Mode.PELLETIZER
	var low:= Vector3(12.0, deck_y, 0.0)
	var low_run: Conveyor = builds.add_conveyor(low - Vector3(0.0, 0.0, 4.0), low)
	await _settle()
	await _drive(Vector3(12.0, 0.0, 1.2))
	tool._update_pelletizer_ghost()
	_check("buildable (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...on a climb of its own, laid from the belt end",
		tool._seat_stub.size() == 2 and tool._seat_stub [0].is_equal_approx(low))
	var feet_y:= tool._pelletizer_ghost.global_position.y
	_check("...standing on the floor, not in it (feet at %.3f)" % feet_y,
		absf(feet_y) < MachineSeat.SINK_TOLERANCE)
	_check("...and the climb is billed", float(tool._eval ["cost"]) > Cfg.PELLETIZER_COST)
	builds.demolish(low_run)
	await _settle()

	print("\n=== ...and mates straight onto one at its port height ===")


	var level:= Vector3(12.0, BuildTool.PELLETIZER_PORT_UP, 0.0)
	var level_run: Conveyor = builds.add_conveyor(level - Vector3(0.0, 0.0, 4.0), level)
	await _settle()
	await _drive(Vector3(12.0, 0.0, 1.2))
	tool._update_pelletizer_ghost()
	_check("buildable (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...with no run laid", tool._seat_stub.is_empty())
	_check("...and nothing billed on top of the machine",
		is_equal_approx(float(tool._eval ["cost"]), Cfg.PELLETIZER_COST))
	builds.demolish(level_run)
	await _settle()

	print("\n=== ...and comes down off one high on trestles ===")
	var high:= Vector3(12.0, 2.0, 0.0)
	var high_run: Conveyor = builds.add_conveyor(high - Vector3(0.0, 0.0, 4.0), high)
	await _settle()
	await _drive(Vector3(12.0, 0.0, 0.5))
	tool._update_pelletizer_ghost()
	_check("buildable (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...on a run that descends to the throat",
		tool._seat_stub.size() == 2 and tool._seat_stub [1].y < tool._seat_stub [0].y)
	builds.demolish(high_run)
	await _settle()


	print("\n=== a press on a splitter's arm, by a metre of belt ===")
	tool._mode = BuildTool.Mode.COMPRESSOR
	var fwd:= Vector3(0.0, 0.0, 1.0)
	var wye: ConveyorSplitter = builds.add_splitter(Vector3(6.0, deck_y, -12.0),
		atan2(fwd.x, fwd.z))
	await _settle()
	var feed: Conveyor = builds.add_conveyor(wye.port_in() - fwd * 3.0, wye.port_in())
	await _settle()
	var mouth:= wye.port(ConveyorSplitter.LEFT)
	var arm:= wye.arm_travel(ConveyorSplitter.LEFT)
	arm = Vector3(arm.x, 0.0, arm.z).normalized()
	var half:= Cfg.COMPRESSOR_LENGTH * 0.5


	var spot:= mouth + arm * (half - 0.12)
	await _drive(Vector3(spot.x, 0.0, spot.z), arm * 3.5)
	tool._update_compressor_ghost()
	var out:= (tool._compressor_ghost.port_in() - mouth).dot(arm)
	_check("aimed 12 cm inside the mouth it snaps a metre out (%.3f m, %s)"
		% [out, tool._eval ["reason"]],
		tool._eval ["ok"] and absf(out - MachineSeat.MOUTH_BELT) < 0.01)

	spot = mouth + arm * (half + 1.4)
	await _drive(Vector3(spot.x, 0.0, spot.z), arm * 3.5)
	tool._update_compressor_ghost()
	_check("aimed 1.4 m out it is buildable (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	var stub:= tool._seat_stub
	_check("...with a metre of belt from the mouth (%.3f m)"
		% (stub [0].distance_to(stub [1]) if stub.size() == 2 else -1.0),
		stub.size() == 2 and stub [0].distance_to(mouth) < 0.001
		and absf(stub [0].distance_to(stub [1]) - 1.0) < 0.01)
	var drift:= tool._compressor_ghost.port_in() - (mouth + arm * MachineSeat.MOUTH_BELT)
	_check("...its intake a metre down the arm (%.3f m off)" % drift.length(),
		drift.length() < 0.01)
	var bill:= Cfg.COMPRESSOR_COST + (Conveyor.cost_for(stub [0], stub [1]) if stub.size() == 2 else 0.0)
	_check("...priced as the press and the belt",
		is_equal_approx(float(tool._eval ["cost"]), bill))
	var paid:= GameState.money
	tool._place_compressor()
	await _settle()
	_check("the press and the belt were paid for (%.0f)" % (paid - GameState.money),
		is_equal_approx(paid - GameState.money, bill))
	var link:= builds.run_out_of(mouth)
	_check("a run leaves the mouth", link != null)
	var on_arm:= _press_at(builds, mouth + arm * 1.0, true)
	_check("the press's intake is a metre out", on_arm != null)
	_check("the arm hands to the belt", link != null
		and wye.route(ConveyorSplitter.LEFT).downstream == link)
	_check("...and the belt to the press", link != null and on_arm != null
		and link.downstream == on_arm.deck())
	_check("...which is marked as laid with the press", link != null and on_arm != null
		and link.seat_port.is_finite() and PointIndex.joins(link.seat_port, on_arm.port_in()))

	print("\n=== taking the press down takes its metre, and only that ===")

	var own: Conveyor = null
	if on_arm != null:
		own = builds.add_conveyor(on_arm.port_out(), on_arm.port_out() + arm * 3.0)
	await _settle()
	_check("a hand laid belt is not marked", own != null and not own.seat_port.is_finite())
	_check("...and the splitter's feed is not either", not feed.seat_port.is_finite())
	var own_a:= own.a if own != null else Vector3.INF

	builds.from_array(builds.to_array())
	await _settle()
	link = builds.run_out_of(mouth)
	on_arm = _press_at(builds, mouth + arm * 1.0, true)
	_check("after a reload the metre is still marked", link != null and on_arm != null
		and link.seat_port.is_finite() and PointIndex.joins(link.seat_port, on_arm.port_in()))
	var owned:= builds.machine_belts_of(on_arm)
	_check("...and it is the press's to take (%d)" % owned.size(),
		owned.size() == 1 and owned [0] == link)
	var press_at:= on_arm.global_position if on_arm != null else Vector3.ZERO
	var press_yaw:= on_arm.global_rotation.y if on_arm != null else 0.0
	var runs_before:= builds.conveyors.size()
	var refund:= builds.demolish(on_arm) if on_arm != null else 0.0
	await _settle()
	_check("the press went", on_arm == null or not is_instance_valid(on_arm)
		or on_arm.is_queued_for_deletion())
	_check("...and its metre went with it", builds.run_out_of(mouth) == null)
	_check("...and nothing else (%d runs to %d)" % [runs_before, builds.conveyors.size()],
		builds.conveyors.size() == runs_before - 1)
	_check("...the hand laid belt still stands", builds.conveyors.any(
		func(c: Conveyor) -> bool: return is_instance_valid(c) and c.a.is_equal_approx(own_a)))
	_check("...and both came back in the refund ($%.0f of $%.0f paid)" % [refund, bill],
		is_equal_approx(refund, bill))

	print("\n=== a belt laid by hand to a machine stays when it goes ===")


	var mine: Conveyor = builds.add_conveyor(mouth, mouth + arm * MachineSeat.MOUTH_BELT)
	await _settle()
	var alone:= builds.add_compressor(press_at, press_yaw)
	await _settle()
	_check("a press on the end of it (%.4f m)" % alone.port_in().distance_to(mine.b),
		alone.port_in().distance_to(mine.b) < 0.01)
	_check("...owns no belt", builds.machine_belts_of(alone).is_empty())
	builds.demolish(alone)
	await _settle()
	_check("...and its going leaves the belt", is_instance_valid(mine)
		and not mine.is_queued_for_deletion() and builds.run_out_of(mouth) == mine)

	builds.from_array([])
	await _settle()

	_finish()


static func _press_at(builds: BuildManager, port: Vector3, intake: bool) -> HayCompressor:
	for press in builds.compressors:
		if not is_instance_valid(press):
			continue
		var at: Vector3 = press.port_in() if intake else press.port_out()
		if at.distance_to(port) < 0.002:
			return press
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


func _drive(at: Vector3, off:= Vector3(-2.5, 0.0, 0.0)) -> void:
	player.global_position = Vector3(at.x + off.x, 0.4, at.z + off.z)
	_aim(at)
	for i in 4:
		await get_tree().physics_frame
	_aim(at)
	var hit: Dictionary = player.build._surface_hit()
	print("  aim %s lands at %s on %s" % [at, hit.get("position"),
		(hit.get("collider") as Node).name if hit.get("collider") is Node else "nothing"])


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _finish() -> void:
	player.build.set_active(false)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("MACHINE SEAT PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)
