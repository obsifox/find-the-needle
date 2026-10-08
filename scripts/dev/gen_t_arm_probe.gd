class_name DevGenTArmProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const WAD_STRANDS:= 97
const WADS:= 12
const WAD_EVERY:= 2.4

const MOUTH_REACH:= 1.5


const SITE:= Vector3(-14.0, 0.0, 14.0)

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	GameState.add_money(50000.0)
	player.global_position = Vector3(-6.0, 0.4, -6.0)
	player.build._reach = 14.0
	await _settle()
	await _case("generator 12 cm SHORT of the arm mouth, as the player built it", 0.12)
	await _case("generator ON the arm mouth", 0.0)
	await _open_end_case()
	await _scanner_overlap_case()
	await _gen_ghost_case(Cfg.T_SPLITTER_PORT_R_V1, [4.0, 5.0, 5.5])
	await _gen_ghost_case(Cfg.T_SPLITTER_PORT_R_V2, [5.0, 6.0, 4.0])
	await _scanner_ghost_case()
	await _t_ghost_case()
	await _lone_t_case()
	_finish()


func _build_t(port_r:= Cfg.T_SPLITTER_PORT_R_V1) -> Dictionary:
	var builds: BuildManager = world.builds
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var placed:= ConveyorTSplitter.placed_port_r
	ConveyorTSplitter.placed_port_r = port_r
	var t:= builds.add_t_splitter(SITE + Vector3(0.0, deck_y, 0.0), 0.0,
		ConveyorTSplitter.STEM) as ConveyorTSplitter
	ConveyorTSplitter.placed_port_r = placed
	await _settle()
	var stem:= t.port_in()
	var feed: Conveyor = builds.add_conveyor(stem - Vector3(0.0, 0.0, 4.0), stem)
	var spill_mouth:= t.port_right()
	var spill: Conveyor = builds.add_conveyor(spill_mouth,
		spill_mouth + t.arm_travel(ConveyorSplitter.RIGHT) * 4.0)
	await _settle()
	return { "t": t, "feed": feed, "spill": spill,
		"mouth": t.port_left(), "travel": t.arm_travel(ConveyorSplitter.LEFT) }


static func _gen_centre(port: Vector3, travel: Vector3) -> Vector3:
	return port + travel * HayGenerator.PORT_BACK - Vector3.UP * HayGenerator.PORT_UP


func _case(label: String, short_by: float) -> void:
	print("\n=== %s ===" % label)
	var builds: BuildManager = world.builds
	var rig:= await _build_t()
	var t: ConveyorTSplitter = rig ["t"]
	var feed: Conveyor = rig ["feed"]
	var mouth: Vector3 = rig ["mouth"]
	var travel: Vector3 = rig ["travel"]
	_check("the arm points +X (%v)" % travel, travel.is_equal_approx(Vector3.RIGHT))
	var port:= mouth - travel * short_by
	var gen: HayGenerator = builds.add_generator(_gen_centre(port, travel), PI * 0.5)
	await _settle()
	var port_err:= gen.intake_port().distance_to(port)
	_check("the generator's port is where it was aimed (%.3f m off)" % port_err, port_err < 0.01)
	print("  arm mouth %v, generator port %v, gap along the arm %.3f m"
		% [mouth, gen.intake_port(), (gen.intake_port() - mouth).dot(travel)])
	var arm: BeltPath = t.route(ConveyorSplitter.LEFT)
	_check("the arm hands to the generator's deck (%s)" % _name_of(arm.downstream),
		arm.downstream == gen.deck())


	gen.set_switched_off(true)
	t.set_priority_side(ConveyorSplitter.LEFT)
	for i in 2:
		await get_tree().physics_frame
	_check("the deck is held shut", gen.deck().is_blocked())
	await _feed_wads(feed, WADS)
	var at_mouth:= _floor_wads_near(mouth)
	_check("nothing on the floor at the mouth (%d)" % at_mouth, at_mouth == 0)
	_check("the queue parks on the arm (%d records)" % arm.run.count(), arm.run.count() >= 1)
	print("  records: feed %d arm %d other arm %d deck %d"
		% [feed.run.count(), arm.run.count(),
			t.route(ConveyorSplitter.RIGHT).run.count(), gen.deck().run.count()])
	await _clear([gen, rig ["spill"], feed, t])


func _open_end_case() -> void:
	print("\n=== a belt ending 45 cm inside a shut generator deck ===")
	var builds: BuildManager = world.builds
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var port:= SITE + Vector3(1.5, deck_y, 0.0)
	var travel:= Vector3.RIGHT
	var gen: HayGenerator = builds.add_generator(_gen_centre(port, travel), PI * 0.5)
	await _settle()
	var inside:= 0.45
	var feed: Conveyor = builds.add_conveyor(port - travel * 4.0, port + travel * inside)
	await _settle()
	_check("the belt is not joined to the deck (%s)" % _name_of(feed.downstream),
		feed.downstream == null)
	_check("...but knows it ends over it (%s)" % _name_of(feed.end_deck),
		feed.end_deck == gen.deck())
	gen.set_switched_off(true)
	for i in 2:
		await get_tree().physics_frame
	_check("the deck is held shut", gen.deck().is_blocked())
	await _feed_wads(feed, 6)
	var at_end:= _floor_wads_near(port + travel * inside)
	var aboard:= feed.run.count() + feed._riders.size()
	_check("nothing on the floor at the belt's end (%d)" % at_end, at_end == 0)
	_check("the wads wait on the belt (%d aboard)" % aboard, aboard >= 4)
	gen.set_switched_off(false)
	for i in int(15.0 / get_physics_process_delta_time()):
		await get_tree().physics_frame
	var left:= feed.run.count() + feed._riders.size()
	_check("opened, the belt lets them go (%d left aboard, firebox %.0f kJ)" % [left, gen.fuel],
		left < aboard and gen.fuel > 0.0)
	await _clear([gen, feed])


func _scanner_overlap_case() -> void:
	print("\n=== a scanner built on the grid, 12 cm inside at both ends ===")
	var builds: BuildManager = world.builds
	var rig:= await _build_t()
	var t: ConveyorTSplitter = rig ["t"]
	var mouth: Vector3 = rig ["mouth"]
	var travel: Vector3 = rig ["travel"]
	var half:= Cfg.SCANNER_LENGTH * 0.5
	var centre:= mouth - travel * 0.12 + travel * half
	var scanner: HaystackScanner = builds.add_scanner(centre, atan2(travel.x, travel.z))
	await _settle()
	print("  arm mouth %v, scanner in %v, out %v" % [mouth, scanner.port_in(), scanner.port_out()])
	var out_start:= scanner.port_out() - travel * 0.12
	var onward: Conveyor = builds.add_conveyor(out_start, out_start + travel * 4.0)
	await _settle()
	var arm: BeltPath = t.route(ConveyorSplitter.LEFT)
	_check("the arm hands to the scanner (%s)" % _name_of(arm.downstream),
		arm.downstream == scanner.deck())
	_check("the scanner hands to the belt starting inside its outfeed (%s)"
		% _name_of(scanner.deck().downstream), scanner.deck().downstream == onward)
	await _clear([onward, scanner, rig ["spill"], rig ["feed"], t])


func _gen_ghost_case(port_r: float, spots: Array) -> void:
	print("\n=== the generator ghost beside a %.1f m T's arm ===" % port_r)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	var rig:= await _build_t(port_r)
	var t: ConveyorTSplitter = rig ["t"]
	var travel: Vector3 = rig ["travel"]
	var mouth: Vector3 = rig ["mouth"]
	tool._mode = BuildTool.Mode.GENERATOR
	var base:= Vector3(t.global_position.x, 0.0, t.global_position.z)


	for i in range(spots.size() - 1, -1, -1):
		var spot: Vector3 = base + travel * float(spots [i])
		await _drive(spot + Vector3(0.0, 0.4, -3.0), spot)
		tool._update_generator_ghost()
		var port:= tool._generator_ghost.intake_port()
		var out:= (port - mouth).dot(travel)
		_check("aimed %.1f m out: buildable (%s)" % [float(spots [i]), tool._eval ["reason"]],
			tool._eval ["ok"])
		_check("...its port snapped a metre past the mouth (%.3f m)" % out,
			absf(out - MachineSeat.MOUTH_BELT) < 0.01
			and absf((port - mouth - travel * out).length()) < 0.01)
		var ramp:= tool._generator_ramp
		_check("...with the metre drawn as a belt from the mouth (%.3f m)"
			% (ramp [0].distance_to(ramp [1]) if ramp.size() == 2 else -1.0),
			ramp.size() == 2 and ramp [0].distance_to(mouth) < 0.001
			and absf(ramp [0].distance_to(ramp [1]) - MachineSeat.MOUTH_BELT) < 0.01)
	if not tool._eval ["ok"]:
		await _clear([rig ["spill"], rig ["feed"], t])
		return
	var runs_before:= builds.conveyors.size()
	var gens_before:= builds.generators.size()
	tool._place_generator()
	await _settle()
	_check("one generator was placed", builds.generators.size() == gens_before + 1)
	_check("...and one belt with it", builds.conveyors.size() == runs_before + 1)
	var gen: HayGenerator = builds.generators [builds.generators.size() - 1]
	var belt: Conveyor = builds.conveyors [builds.conveyors.size() - 1]
	await _belt_parks(rig, belt, gen)
	await _clear([gen, belt, rig ["spill"], rig ["feed"], t])


func _belt_parks(rig: Dictionary, belt: Conveyor, machine: Node) -> void:
	var t: ConveyorTSplitter = rig ["t"]
	var arm: BeltPath = t.route(ConveyorSplitter.LEFT)
	var deck: BeltPath = machine.call("deck")
	_check("the arm hands to the belt (%s)" % _name_of(arm.downstream), arm.downstream == belt)
	_check("...and the belt to the machine (%s)" % _name_of(belt.downstream),
		belt.downstream == deck)
	var gen:= machine as HayGenerator
	if gen == null:
		return
	gen.set_switched_off(true)
	t.set_priority_side(ConveyorSplitter.LEFT)
	for i in 2:
		await get_tree().physics_frame
	_check("the deck is held shut", deck.is_blocked())
	await _feed_wads(rig ["feed"], WADS)
	var fallen:= _floor_wads_near(rig ["mouth"]) + _floor_wads_near(belt.b)
	_check("nothing on the floor at the mouth or the port (%d)" % fallen, fallen == 0)
	_check("the queue parks on the belt (%d records)" % belt.run.count(), belt.run.count() >= 1)


func _scanner_ghost_case() -> void:
	print("\n=== the scanner ghost on a 2 m T's arm ===")
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	var rig:= await _build_t(Cfg.T_SPLITTER_PORT_R_V2)
	var t: ConveyorTSplitter = rig ["t"]
	var travel: Vector3 = rig ["travel"]
	var mouth: Vector3 = rig ["mouth"]
	tool._mode = BuildTool.Mode.SCANNER
	var base:= Vector3(t.global_position.x, 0.0, t.global_position.z)
	for d: float in [4.4, 3.0]:
		var spot:= base + travel * d
		await _drive(spot + Vector3(-1.0, 0.4, -3.0), spot)
		tool._update_scanner_ghost()
		_check("aimed %.1f m out: buildable (%s)" % [d, tool._eval ["reason"]], tool._eval ["ok"])
		var out:= (tool._scanner_ghost.port_in() - mouth).dot(travel)
		_check("...its intake snapped a metre past the mouth (%.3f m)" % out,
			absf(out - MachineSeat.MOUTH_BELT) < 0.01)
		var stub:= tool._seat_stub
		_check("...with the metre drawn as a belt (%.3f m)"
			% (stub [0].distance_to(stub [1]) if stub.size() == 2 else -1.0),
			stub.size() == 2 and absf(stub [0].distance_to(stub [1]) - MachineSeat.MOUTH_BELT) < 0.01)
	if not tool._eval ["ok"]:
		await _clear([rig ["spill"], rig ["feed"], t])
		return
	var runs_before:= builds.conveyors.size()
	tool._place_scanner()
	await _settle()
	_check("one belt was laid with it", builds.conveyors.size() == runs_before + 1)
	var scanner: HaystackScanner = builds.scanners [builds.scanners.size() - 1]
	var belt: Conveyor = builds.conveyors [builds.conveyors.size() - 1]
	await _belt_parks(rig, belt, scanner)
	await _clear([scanner, belt, rig ["spill"], rig ["feed"], t])


func _t_ghost_case() -> void:
	print("\n=== the T ghost beside a standing generator ===")
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var gen: HayGenerator = builds.add_generator(
		_gen_centre(SITE + Vector3(2.62 + Cfg.T_SPLITTER_PORT_R, deck_y, 0.0),
			Vector3.RIGHT), PI * 0.5)
	await _settle()
	tool._mode = BuildTool.Mode.T_SPLITTER
	var results: Array = []
	for cx: float in [2.0, 1.0]:

		var stem:= SITE + Vector3(cx, deck_y, - Cfg.T_SPLITTER_PORT_R)
		var feed: Conveyor = builds.add_conveyor(stem - Vector3(0.0, 0.0, 4.0), stem)
		await _settle()


		var at:= SITE + Vector3(cx, 0.0, - Cfg.T_SPLITTER_PORT_R + 0.3)
		await _drive(at + Vector3(0.0, 0.4, -3.5), at)
		tool._update_t_splitter_ghost()
		var g:= tool._t_splitter_ghost
		print("  T at %v: %s, port %v" % [g.global_position,
			tool._eval ["reason"], gen.intake_port()])
		results.append({ "ok": tool._eval ["ok"], "reason": tool._eval ["reason"] })
		if cx == 1.0 and tool._eval ["ok"]:
			var runs_before:= builds.conveyors.size()
			tool._place_t_splitter()
			await _settle()
			_check("placed with no belt", builds.conveyors.size() == runs_before)
			var t: ConveyorTSplitter = builds.splitters [builds.splitters.size() - 1]
			await _clear([t])
		await _clear([feed])
	_check("62 cm short of the machine the T is refused (%s)" % results [0] ["reason"],
		not results [0] ["ok"] and results [0] ["reason"] == tr("too close to the machine"))
	_check("a crossing further back it stands (%s)" % results [1] ["reason"],
		results [1] ["ok"])
	await _clear([gen])


func _lone_t_case() -> void:
	print("\n=== the generator ghost on a lone T's stem, its entry for now ===")
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var t:= builds.add_t_splitter(SITE + Vector3(0.0, deck_y, 0.0), 0.0,
		ConveyorTSplitter.STEM) as ConveyorTSplitter
	await _settle()
	_check("the lone T's entry is its stem", t.entry == ConveyorTSplitter.STEM and not t.fed)
	var mouth:= t.to_global(t.mouth_of(ConveyorTSplitter.STEM))
	var out:= (t.global_basis * ConveyorTSplitter.lane_out(ConveyorTSplitter.STEM)).normalized()
	tool._mode = BuildTool.Mode.GENERATOR
	var spot:= Vector3(mouth.x, 0.0, mouth.z) + out * 3.0
	await _drive(spot + Vector3(-3.0, 0.4, 0.0), spot)
	tool._update_generator_ghost()
	var port:= tool._generator_ghost.intake_port()
	_check("buildable on the stem (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...its port snapped a metre down the stem (%.3f m)" % (port - mouth).dot(out),
		absf((port - mouth).dot(out) - MachineSeat.MOUTH_BELT) < 0.01
		and ((port - mouth) - out * (port - mouth).dot(out)).length() < 0.01)
	if not tool._eval ["ok"]:
		await _clear([t])
		return
	var runs_before:= builds.conveyors.size()
	tool._place_generator()
	await _settle()
	_check("...placed with its metre of belt", builds.conveyors.size() == runs_before + 1)
	var gen: HayGenerator = builds.generators [builds.generators.size() - 1]
	var link: Conveyor = builds.conveyors [builds.conveyors.size() - 1]
	_check("...and the belt feeds the generator", link.downstream == gen.deck())

	var bar:= t.to_global(t.mouth_of(ConveyorTSplitter.BAR_NEG))
	var feed: Conveyor = builds.add_conveyor(bar + Vector3(-4.0, 0.0, 0.0), bar)
	await _settle()
	var now:= t if is_instance_valid(t) else null
	for s in builds.splitters:
		if s is ConveyorTSplitter and is_instance_valid(s) and s.global_position.is_equal_approx(SITE + Vector3(0.0, deck_y, 0.0)):
			now = s
	_check("fed at the bar, the T turned round (entry %d)" % (now.entry if now != null else -1),
		now != null and now.entry == ConveyorTSplitter.BAR_NEG and now.fed)
	var hands:= false
	if now != null:
		for side: int in now.output_sides():
			if now.route(side).downstream == link:
				hands = true
	_check("...and hands out of the stem to the generator's belt", hands)
	gen.fuel = 0.0
	if now != null:
		now.set_priority_side(ConveyorSplitter.LEFT if now.route(ConveyorSplitter.LEFT).downstream == link
			else ConveyorSplitter.RIGHT)
	await _feed_wads(feed, 3)
	_check("wads off the feed reach the firebox (%.0f kJ)" % gen.fuel, gen.fuel > 0.0)
	await _clear([gen, link, feed, now])


func _feed_wads(feed: Conveyor, n: int) -> void:
	for i in n:
		_wad_on(feed)
		for k in int(WAD_EVERY / get_physics_process_delta_time()):
			await get_tree().physics_frame
	for i in int(12.0 / get_physics_process_delta_time()):
		await get_tree().physics_frame


func _floor_wads_near(at: Vector3) -> int:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var n:= 0
	for item in world.props.items:
		var rb:= item as RigidBody3D
		if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
			continue
		var p:= rb.global_position
		if p.y < deck_y - 0.05 and Vector2(p.x - at.x, p.z - at.z).length() <= MOUTH_REACH:
			n += 1
			print("  on the floor at %v" % p)
	return n


func _clear(buildings: Array) -> void:
	for b in buildings:
		if is_instance_valid(b):
			world.builds.demolish(b)
	await _settle()
	for item in world.props.items.duplicate():
		if is_instance_valid(item):
			world.props.remove(item)
	await _settle()


static func _name_of(path: BeltPath) -> String:
	if not is_instance_valid(path):
		return "-"
	return path.get_parent().name + "/" + path.name


func _wad_on(feed: Conveyor) -> void:
	var at:= feed.a + feed.forward * 0.6 + Vector3.UP * 0.45
	world.props.spawn("hay_wad", Transform3D(Basis(), at), { "strands": WAD_STRANDS })


func _finish() -> void:
	player.build.set_active(false)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("GEN T ARM PROBE FAILED")
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
