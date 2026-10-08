class_name DevGenWyeProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const MOUTH_TOL:= 0.001
const WAD_STRANDS:= 50

const WADS:= 45

const WAD_EVERY:= 2.4


const GAP:= 1.4

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(-10.0, 0.4, -4.0)
	GameState.add_money(50000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	tool._reach = 14.0
	await _settle()


	print("\n=== a generator dropped onto the end of a run ===")


	var end:= Vector3(10.0, BuildTool.GENERATOR_PORT_UP, 5.0)
	var lead: Conveyor = builds.add_conveyor(end - Vector3(0.0, 0.0, 3.0), end)
	await _settle()
	tool._mode = BuildTool.Mode.GENERATOR
	await _drive(end + Vector3(3.0, 0.4 - end.y, -2.0), _floor(end + Vector3(0.0, 0.0, 0.4)))
	tool._update_generator_ghost()
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...with its port on the run's end (%.5f m)"
		% tool._generator_ghost.intake_port().distance_to(end),
		tool._generator_ghost.intake_port().is_equal_approx(end))
	tool._place_generator()
	await _settle()
	var on_end: HayGenerator = builds.generator_at_port(end)
	_check("the placed machine's port is on the run's end", on_end != null)
	_check("...and the run hands to its deck",
		on_end != null and lead.downstream == on_end.deck())
	if on_end != null:
		builds.demolish(on_end)
	builds.demolish(lead)
	await _settle()


	print("\n=== a generator on a floor splitter's arm ===")
	var fwd:= Vector3(-1.0, 0.0, 1.0).normalized()
	var s_low: ConveyorSplitter = builds.add_splitter(Vector3(-13.0, deck_y, -8.0),
		atan2(fwd.x, fwd.z))
	await _settle()
	var feed_to:= s_low.port_in()
	var feed: Conveyor = builds.add_conveyor(feed_to - fwd * 3.0, feed_to)
	var gen_side:= ConveyorSplitter.LEFT
	if s_low.arm_travel(ConveyorSplitter.RIGHT).dot(Vector3.BACK) > s_low.arm_travel(ConveyorSplitter.LEFT).dot(Vector3.BACK):
		gen_side = ConveyorSplitter.RIGHT
	var spill_side:= ConveyorSplitter.RIGHT if gen_side == ConveyorSplitter.LEFT else ConveyorSplitter.LEFT
	var mouth:= s_low.port(gen_side)
	var arm:= s_low.arm_travel(gen_side)
	arm = Vector3(arm.x, 0.0, arm.z).normalized()
	var spill: Conveyor = builds.add_conveyor(s_low.port(spill_side),
		s_low.port(spill_side) + s_low.arm_travel(spill_side) * 2.0)
	await _settle()

	tool._mode = BuildTool.Mode.GENERATOR


	await _drive(mouth + Vector3(3.0, 0.4 - mouth.y, -1.0),
		_floor(mouth + arm * (0.3 + BuildTool.GENERATOR_PORT_BACK)))
	tool._update_generator_ghost()
	_check("aimed 30 cm out it snaps a metre out (%.3f m, %s)"
		% [(tool._generator_ghost.intake_port() - mouth).dot(arm), tool._eval ["reason"]],
		tool._eval ["ok"] and absf((tool._generator_ghost.intake_port() - mouth).dot(arm)
			- MachineSeat.MOUTH_BELT) < 0.01)

	var aim:= _floor(mouth + arm * (GAP + BuildTool.GENERATOR_PORT_BACK))
	await _drive(mouth + Vector3(3.0, 0.4 - mouth.y, -1.0), aim)
	tool._update_generator_ghost()
	var ghost: HayGenerator = tool._generator_ghost
	var ramp:= tool._generator_ramp
	_check("aimed %.1f m out it is buildable (%s)" % [GAP, tool._eval ["reason"]], tool._eval ["ok"])
	_check("...with a metre of belt (%.3f m)"
		% (ramp [0].distance_to(ramp [1]) if ramp.size() == 2 else -1.0),
		ramp.size() == 2 and absf(ramp [0].distance_to(ramp [1]) - MachineSeat.MOUTH_BELT) < 0.01)
	_check("...from the mouth", ramp.size() == 2 and ramp [0].distance_to(mouth) < MOUTH_TOL)
	_check("...to the port", ramp.size() == 2
		and ramp [1].distance_to(ghost.intake_port()) < MOUTH_TOL)
	var drift:= ghost.intake_port() - (mouth + arm * MachineSeat.MOUTH_BELT)
	_check("the port stands a metre down the arm (%.3f m off)" % Vector2(drift.x, drift.z).length(),
		Vector2(drift.x, drift.z).length() < 0.01)
	_check("the machine faces down the arm", ghost.forward().dot(arm) > 0.999)
	_check("the machine stands on the floor", absf(ghost.global_position.y) < 0.02)
	var want_bill:= builds.generator_price() + (Conveyor.cost_for(ramp [0], ramp [1]) if ramp.size() == 2 else 0.0)
	_check("the bill is the machine and the belt",
		is_equal_approx(float(tool._eval ["cost"]), want_bill))
	_check("the belt is drawn", tool._ghost.visible)

	var money_before:= GameState.money
	var gens_before:= builds.generators.size()
	var runs_before:= builds.conveyors.size()
	tool._place_generator()
	await _settle()
	_check("one generator was placed", builds.generators.size() == gens_before + 1)
	_check("...and one run with it", builds.conveyors.size() == runs_before + 1)
	_check("...for exactly the bill ($%.2f)" % (money_before - GameState.money),
		absf(money_before - GameState.money - want_bill) < 0.01)
	if builds.generators.size() != gens_before + 1 or builds.conveyors.size() != runs_before + 1:
		_finish()
		return
	var gen: HayGenerator = builds.generators [builds.generators.size() - 1]
	var link: Conveyor = builds.conveyors [builds.conveyors.size() - 1]
	_check("the arm feeds the belt", s_low.route(gen_side).downstream == link)
	_check("...and the belt the generator", link.downstream == gen.deck())
	_check("the mouth is no longer offered to another generator",
		builds.nearest_wye_outlet(mouth, 1.0).is_empty())
	_check("...nor to a wye", builds.nearest_wye_joint(mouth, 0.2).is_empty())


	print("\n=== wads along the floor intake ===")
	s_low.set_priority_side(gen_side)
	gen.fuel = 0.0
	var fed_kj:= 0.0
	var peak:= 0.0
	for i in 2:
		_wad_on(feed)
		for k in int(WAD_EVERY / get_physics_process_delta_time()):
			await get_tree().physics_frame
			peak = maxf(peak, gen.fuel)
	for i in int(20.0 / get_physics_process_delta_time()):
		await get_tree().physics_frame
		peak = maxf(peak, gen.fuel)
	fed_kj = peak
	_check("an empty box takes the wads (peaked at %.0f kJ)" % fed_kj,
		fed_kj >= float(WAD_STRANDS) * 1.5 * Cfg.GENERATOR_KJ_PER_STRAND)

	print("\n=== a shut mouth sends the rest down the other arm ===")


	var spilled:= { }
	s_low.route(spill_side).caught.connect(func(b: RigidBody3D) -> void:
		spilled [b.get_instance_id()] = true)


	s_low.route(spill_side).caught_record.connect(func(seq: int, _kind: int, _strands: int) -> void:
		spilled [seq] = true)
	gen.set_switched_off(true)
	for i in 2:
		await get_tree().physics_frame
	_check("the deck is held", gen.deck().is_blocked())
	for i in WADS:
		_wad_on(feed)
		for k in int(WAD_EVERY / get_physics_process_delta_time()):
			await get_tree().physics_frame
	for i in int(15.0 / get_physics_process_delta_time()):
		await get_tree().physics_frame


	var queued:= s_low.route(gen_side).riders().size() + s_low.route(gen_side).run.count() + link.riders().size() + link.run.count() + gen.deck().riders().size() + gen.deck().run.count()
	print("  %d wads fed, %d went down the spill arm, %d queued for the generator"
		% [WADS, spilled.size(), queued])
	print("  aboard: feed %d, arm route %d, deck %d"
		% [feed.riders().size() + feed.run.count(),
			s_low.route(gen_side).riders().size() + s_low.route(gen_side).run.count(),
			gen.deck().riders().size() + gen.deck().run.count()])
	_check("the spill arm took wads once the generator's side backed up",
		spilled.size() > 0)


	var room:= s_low.route(gen_side).path_length() + link.path_length() + gen.deck().path_length()
	var wad_pitch:= Cfg.WAD_BASE_SIZE.z * Cfg.WAD_PACK * 0.9
	_check("the generator's queue fits the arm and its deck (%d wads in %.1f m)"
		% [queued, room], float(queued) * wad_pitch <= room)
	_check("...and the main line behind the splitter kept moving (%d on it)"
		% (feed.riders().size() + feed.run.count()),
		feed.riders().size() + feed.run.count() <= 2)
	gen.set_switched_off(false)


	print("\n=== an old save's generator mated straight onto a mouth ===")


	var hi_fwd:= Vector3(1.0, 0.0, 1.0).normalized()
	var s_high: ConveyorSplitter = builds.add_splitter(
		Vector3(13.0, BuildTool.GENERATOR_PORT_UP, -8.0), atan2(hi_fwd.x, hi_fwd.z))
	await _settle()
	var hi_side:= ConveyorSplitter.LEFT
	if s_high.arm_travel(ConveyorSplitter.RIGHT).dot(Vector3.BACK) > s_high.arm_travel(ConveyorSplitter.LEFT).dot(Vector3.BACK):
		hi_side = ConveyorSplitter.RIGHT
	var hi_mouth:= s_high.port(hi_side)
	var hi_arm:= s_high.arm_travel(hi_side)
	hi_arm = Vector3(hi_arm.x, 0.0, hi_arm.z).normalized()
	builds.add_generator(hi_mouth + hi_arm * BuildTool.GENERATOR_PORT_BACK
		- Vector3.UP * BuildTool.GENERATOR_PORT_UP, atan2(hi_arm.x, hi_arm.z))
	await _settle()
	var mated: HayGenerator = builds.generator_at_port(hi_mouth)
	_check("the machine's port is on the mouth", mated != null)
	if mated != null:
		_check("the arm hands straight to the generator's deck",
			s_high.route(hi_side).downstream == mated.deck())
		_check("a run out of that mouth is refused (%s)" % tool._joint_taken(hi_mouth, true),
			tool._joint_taken(hi_mouth, true) != "")
		_check("...and one into it (%s)" % tool._joint_taken(hi_mouth, false),
			tool._joint_taken(hi_mouth, false) != "")
		_check("the mouth is not offered to a wye",
			builds.nearest_wye_joint(hi_mouth, 0.2).is_empty())

		print("\n=== save ===")
		var data: Array = builds.to_array()
		builds.from_array(data)
		await _settle()
		var back: HayGenerator = builds.generator_at_port(hi_mouth)
		var back_splitter: ConveyorSplitter = null
		for s: ConveyorSplitter in builds.splitters:
			if s.port(hi_side).is_equal_approx(hi_mouth):
				back_splitter = s
		_check("the mated pair comes back linked", back != null and back_splitter != null
			and back_splitter.route(hi_side).downstream == back.deck())

		print("\n=== taking the generator away ===")
		if back != null and back_splitter != null:
			builds.demolish(back)
			await _settle()
			_check("the arm hands to nothing", back_splitter.route(hi_side).downstream == null)
			_check("...and the mouth is free again (%s)" % tool._joint_taken(hi_mouth, true),
				tool._joint_taken(hi_mouth, true) == "")

	_finish()


func _wad_on(feed: Conveyor) -> void:
	var at:= feed.a + feed.forward * 0.6 + Vector3.UP * 0.45
	world.props.spawn("hay_wad", Transform3D(Basis(), at), { "strands": WAD_STRANDS })


func _finish() -> void:
	player.build.set_active(false)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("GEN WYE PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


func _drive(stand: Vector3, at: Vector3) -> void:
	player.global_position = stand
	_aim(at)
	for i in 4:
		await get_tree().physics_frame
	_aim(at)


static func _floor(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


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
