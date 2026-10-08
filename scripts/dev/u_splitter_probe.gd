class_name DevUSplitterProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const FED:= 40


const CARRY_SECONDS:= 28.0 / Cfg.BELT_SPEED
const OUT_RUN:= 3.0
const WALL_MARGIN:= 1.0


const LINE_TOL:= 0.002

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0
var _caught:= [0, 0]
var _arrived:= [0, 0]


var _caught_hay:= [0, 0]
var _arrived_hay:= [0, 0]
var _route_of: Dictionary = { }
var _strayed:= 0
var _agreed:= 0


static func belt_secs(metres: float) -> float:
	return metres / maxf(Cfg.BELT_SPEED, 0.01)


func run() -> void:
	_rng.seed = 20260911
	for i in 40:
		await get_tree().process_frame

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var feed_a:= Vector3(-13.0, deck_y, -8.0)
	var centre_at:= Vector3(-13.0, deck_y, -1.0)
	player.global_position = Vector3(-10.0, 0.4, 0.0)
	GameState.add_money(5000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	print("\n=== model ===")
	var splitter: ConveyorUSplitter = world.builds.add_u_splitter(centre_at, 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("it is filed with the splitters", world.builds.splitters.has(splitter))
	_check("...and in their group", splitter.is_in_group("conveyor_splitters"))
	_check("...and names itself as the U (%s)" % world.builds.name_of(splitter),
		world.builds.name_of(splitter) == BuildCatalog.display_name("u_splitter")
			and BuildCatalog.display_name("u_splitter") != BuildCatalog.display_name("splitter"))

	var body:= splitter.get_node_or_null("Body") as MeshInstance3D
	var gate:= splitter.get_node_or_null("Gate") as MeshInstance3D
	var readout:= splitter.get_node_or_null("Readout") as MeshInstance3D
	_check("U mesh instantiated", body != null and body.mesh != null)
	_check("...and it is the U's own, not the Y's",
		body != null and body.mesh == ConveyorKit.fast_mesh(ConveyorKit.u_splitter_mesh())
			and body.mesh != ConveyorKit.fast_mesh(ConveyorKit.splitter_mesh()))
	if body != null and body.mesh != null:
		_check("U has 3 surfaces (rubber, frame, roller), got %d"
			% body.mesh.get_surface_count(), body.mesh.get_surface_count() == 3)
		var box:= body.mesh.get_aabb()
		print("  plan %.3f across by %.3f along, x %.3f..%.3f, z %.3f..%.3f"
			% [box.size.x, box.size.z, box.position.x, box.end.x, box.position.z, box.end.z])


		_check("...3.05 m across its drums (%.3f)" % box.size.x, absf(box.size.x - 3.05) < 0.08)
		_check("...3.29 m along the line (%.3f)" % box.size.z, absf(box.size.z - 3.29) < 0.08)
		_check("...its infeed drum 0.12 past the infeed port (%.3f)" % box.position.z,
			absf(box.position.z - (- Cfg.SPLITTER_PORT_R - 0.12)) < 0.03)
		_check("...its outfeed drums 0.12 past the outfeed ports (%.3f)" % box.end.z,
			absf(box.end.z - (ConveyorUSplitter.OUT_Z + 0.12)) < 0.03)
	_check("the Y's blade is fitted", gate != null and gate.mesh == ConveyorKit.splitter_gate_mesh())
	_check("...on the Y's pivot (%.4f)" % (gate.position.z if gate != null else -1.0),
		gate != null and absf(gate.position.z - Cfg.SPLITTER_GATE_PIVOT) < 0.001)
	_check("the Y's readout is fitted",
		readout != null and readout.mesh == ConveyorKit.splitter_readout_mesh())

	var open:= 0
	for side in ConveyorSplitter.SIDES:
		var route:= splitter.route(side)
		_check("route %d laid" % side, route != null)
		if route != null and route._catching:
			open += 1
	_check("exactly one route open, got %d" % open, open == 1)


	print("\n=== the arms ===")


	var s45:= sin(Cfg.SPLITTER_SPLAY)
	var c45:= cos(Cfg.SPLITTER_SPLAY)
	var bend_s:= (ConveyorUSplitter.LANE_X - ConveyorUSplitter.BEND_R * (1.0 - c45)) / s45
	_check("BEND_S is the solved bend start (%.5f vs %.5f)" % [ConveyorUSplitter.BEND_S, bend_s],
		absf(ConveyorUSplitter.BEND_S - bend_s) < 1e-05)
	_check("BEND_ARC is 45 degrees of BEND_R (%.5f)" % ConveyorUSplitter.BEND_ARC,
		absf(ConveyorUSplitter.BEND_ARC - ConveyorUSplitter.BEND_R * Cfg.SPLITTER_SPLAY) < 1e-05)
	_check("BEND_CENTRE_Z is where both bends are cut about (%.5f)" % ConveyorUSplitter.BEND_CENTRE_Z,
		absf(ConveyorUSplitter.BEND_CENTRE_Z - (bend_s * c45 + ConveyorUSplitter.BEND_R * s45)) < 1e-05)
	_check("ARM_END is 2.3712 (%.5f)" % ConveyorUSplitter.ARM_END,
		absf(ConveyorUSplitter.ARM_END - 2.3712) < 0.0001)
	for hand: float in [1.0, -1.0]:
		var label:= "left" if hand > 0.0 else "right"
		var walked:= ConveyorUSplitter.arm_point(hand, ConveyorUSplitter.ARM_END)
		_check("the %s arm walked to its end lands on its mouth (off by %.6f)"
			% [label, walked.distance_to(ConveyorUSplitter.mouth_local(hand))],
			walked.distance_to(ConveyorUSplitter.mouth_local(hand)) < 0.0001)
		var centre:= Vector3(0.0, 0.0, ConveyorUSplitter.BEND_CENTRE_Z)
		var worst:= 0.0
		for k in 9:
			var s:= ConveyorUSplitter.BEND_S + ConveyorUSplitter.BEND_ARC * float(k) / 8.0
			worst = maxf(worst, absf(ConveyorUSplitter.arm_point(hand, s).distance_to(centre)
				- ConveyorUSplitter.BEND_R))
		_check("...its bend is cut about the shared centre (worst %.6f)" % worst, worst < 0.0001)

		var into:= ConveyorUSplitter.arm_heading(hand, ConveyorUSplitter.BEND_S)
		var out:= ConveyorUSplitter.arm_heading(hand, ConveyorUSplitter.BEND_E)
		_check("...it leaves the junction on 45 degrees and the bend on +Z (%.3f, %.3f)"
			% [rad_to_deg(into.angle_to(Vector3.BACK)), rad_to_deg(out.angle_to(Vector3.BACK))],
			absf(into.angle_to(Vector3.BACK) - Cfg.SPLITTER_SPLAY) < 0.0001
				and out.angle_to(Vector3.BACK) < 0.0001)

	for side in ConveyorSplitter.SIDES:
		var route:= splitter.route(side)
		if route == null:
			continue
		var hand:= 1.0 if side == ConveyorSplitter.LEFT else -1.0
		var line: PackedVector3Array = route._line
		_check("route %d runs infeed, junction, bend in %d pieces, mouth (%d points)"
			% [side, ConveyorUSplitter.BEND_PIECES, line.size()],
			line.size() == ConveyorUSplitter.BEND_PIECES + 4
				and line [0].is_equal_approx(splitter.port_in())
				and line [1].is_equal_approx(splitter.global_position)
				and line [line.size() - 1].is_equal_approx(splitter.port(side)))


		var off:= 0.0
		for i in range(1, line.size()):
			off = maxf(off, _off_arm(splitter.to_local(line [i]), hand))
		_check("...every corner of it on the modelled centreline (worst %.4f m)" % off,
			off < LINE_TOL)


		var sag:= 0.0
		for i in range(2, line.size() - 1):
			var mid:= splitter.to_local((line [i] + line [i + 1]) * 0.5)
			sag = maxf(sag, _off_arm(mid, hand))
		_check("...and no chord cuts the bend by more than 3 mm (%.4f m)" % sag, sag < 0.003)


	print("\n=== scroll direction ===")


	var ref_g:= DevSplitterProbe._scroll_gradient(ConveyorKit.segment_mesh(),
		Vector3.ZERO, Vector3.BACK)
	_check("the reference section has a scroll direction at all (%+.2f)" % ref_g,
		absf(ref_g) > 0.9)
	var mid_s:= ConveyorUSplitter.BEND_S + ConveyorUSplitter.BEND_ARC * 0.5
	for lane in [["infeed", Vector3(0.0, 0.0, -0.75), Vector3.BACK],
			["left junction", ConveyorUSplitter.arm_point(1.0, 0.72),
				ConveyorUSplitter.arm_heading(1.0, 0.72)],
			["left bend", ConveyorUSplitter.arm_point(1.0, mid_s),
				ConveyorUSplitter.arm_heading(1.0, mid_s)],
			["left last straight", Vector3(1.0, 0.0, 1.75), Vector3.BACK],
			["right bend", ConveyorUSplitter.arm_point(-1.0, mid_s),
				ConveyorUSplitter.arm_heading(-1.0, mid_s)],
			["right last straight", Vector3(-1.0, 0.0, 1.75), Vector3.BACK]]:
		var g:= DevSplitterProbe._scroll_gradient(ConveyorKit.u_splitter_mesh(),
			lane [1], lane [2])
		_check("%s scrolls with the load (dV/d(travel) = %+.2f)" % [lane [0], g],
			absf(g) > 0.9 and signf(g) == signf(ref_g))


	print("\n=== ports ===")
	for row in [["infeed", splitter.port_in(), Vector3(0.0, 0.0, -1.05)],
			["left", splitter.port_left(), Vector3(1.0, 0.0, 2.0)],
			["right", splitter.port_right(), Vector3(-1.0, 0.0, 2.0)]]:
		var local:= splitter.to_local(row [1] as Vector3)
		_check("%s port at %s (want %s)" % [row [0], local, row [2]],
			local.distance_to(row [2] as Vector3) < 0.0001)
	_check("travel is +Z as placed", splitter.forward().dot(Vector3.BACK) > 0.99)
	_check("left mouth is on the load's left (+X)",
		splitter.port_left().x > splitter.global_position.x)
	for side in ConveyorSplitter.SIDES:
		_check("arm %d hands on along the line (%.4f)" % [side,
			splitter.arm_travel(side).dot(splitter.forward())],
			splitter.arm_travel(side).dot(splitter.forward()) > 0.9999)
		_check("...and the yard is told so (%.4f)"
			% world.builds.port_bearing_at(splitter.port(side)).dot(splitter.forward()),
			world.builds.port_bearing_at(splitter.port(side)).dot(splitter.forward()) > 0.9999)


	var turned: ConveyorUSplitter = world.builds.add_u_splitter(
		Vector3(-8.0, deck_y, -12.0), PI * 0.5)
	for i in 4:
		await get_tree().physics_frame
	var want_left:= turned.global_position + Vector3(2.0, 0.0, -1.0)
	_check("a quarter turn puts the left outfeed at +2 along, 1 to the left (%.4f off)"
		% turned.port_left().distance_to(want_left),
		turned.port_left().distance_to(want_left) < 0.0001)
	world.builds.demolish(turned)
	for i in 4:
		await get_tree().physics_frame


	print("\n=== the deck under it ===")


	var gap_hit:= _floor_owner(splitter.to_global(Vector3(0.0, 0.0, 1.8)))
	_check("nothing of the machine's lies across the gap between the arms (%s)"
		% gap_hit, gap_hit != "machine")
	gap_hit = _floor_owner(splitter.to_global(Vector3(0.0, 0.0, 1.25)))
	_check("...nor further in, at the arch (%s)" % gap_hit, gap_hit != "machine")

	for p: Vector3 in [Vector3(-0.47, 0.0, -0.195), Vector3(0.47, 0.0, -0.195)]:
		var notch_hit:= _floor_owner(splitter.to_global(p))
		_check("the side notch at %s is closed (%s)" % [p, notch_hit], notch_hit == "machine")
	var outline:= ConveyorUSplitter.deck_outline()
	_check("the junction pan outline triangulates (%d points, %d triangles)"
		% [outline.size(), Geometry2D.triangulate_polygon(outline).size() / 3],
		Geometry2D.triangulate_polygon(outline).size() >= 3)


	print("\n=== legs ===")
	_check("it stands on six legs (%d)" % _legs(splitter), _legs(splitter) == 6)
	var pads:= [
		Vector3(0.0, -0.176, - Cfg.SPLITTER_PORT_R + 0.27),
		Vector3(1.0, -0.176, 2.0 - 0.27),
		Vector3(-1.0, -0.176, 2.0 - 0.27),
	]
	var lanes: Array = splitter._lanes()
	for i in lanes.size():
		var got:= splitter._pad_centre(lanes [i])
		_check("pads for lane %d centred at %s (want %s)" % [i, got, pads [i]],
			got.distance_to(pads [i]) < 0.0001)

	for lane: Dictionary in lanes:
		_check("lane at %s carries along +Z at its mouth" % lane ["mouth"],
			(lane ["travel"] as Vector3).dot(Vector3.BACK) > 0.9999)


	print("\n=== snapping and overlap ===")
	for row in [["infeed", splitter.port_in()], ["left", splitter.port_left()],
			["right", splitter.port_right()]]:
		var mouth: Vector3 = row [1]
		var snapped: Vector3 = world.builds.snap_endpoint(mouth + Vector3(0.3, 0.0, 0.35))
		_check("belt end snaps to the %s mouth (off by %.3f m)"
			% [row [0], snapped.distance_to(mouth)], snapped.is_equal_approx(mouth))
	var again: Array [Vector4] = []
	for d: Vector4 in ConveyorUSplitter.footprint_local():
		again.append(d + Vector4(centre_at.x, centre_at.y, centre_at.z, 0.0))
	_check("a second U on the same spot is refused", world.builds.wye_overlap(again))
	var beside: Array [Vector4] = []
	for d: Vector4 in ConveyorUSplitter.footprint_local():
		beside.append(d + Vector4(centre_at.x + 2.0, centre_at.y, centre_at.z, 0.0))
	_check("...and so is one 2 m to the side, whose arm lies on this one's",
		world.builds.wye_overlap(beside))
	_check("...and so is a Y splitter",
		world.builds.splitter_overlap(splitter.global_position))
	_check("...and a Y splitter on the end of an arm, overlapping it",
		world.builds.splitter_overlap(splitter.port_left() + Vector3(0.0, 0.0, 0.5)))
	_check("a Y splitter mated to the left outfeed is not",
		not world.builds.splitter_overlap(splitter.port_left()
			+ Vector3(0.0, 0.0, Cfg.SPLITTER_PORT_R)))
	_check("a compressor standing across the bend is refused",
		world.builds.compressor_overlap(splitter.to_global(Vector3(1.4, 0.0, 1.0))))


	print("\n=== a module on each outfeed ===")


	var lane_fwd:= splitter.forward()
	var lane_yaw:= atan2(lane_fwd.x, lane_fwd.z)
	var on_left:= splitter.to_global(Vector3(ConveyorUSplitter.LANE_X, 0.0, 3.5))
	var on_right:= splitter.to_global(Vector3(- ConveyorUSplitter.LANE_X, 0.0, 3.5))
	_check("the outfeeds stand %.2f m apart" % on_left.distance_to(on_right),
		absf(on_left.distance_to(on_right) - ConveyorUSplitter.LANE_X * 2.0) < 0.001)
	var pair_scanner: HaystackScanner = world.builds.add_scanner(on_left, lane_yaw)
	_check("a scanner on the other lane clears the first",
		not world.builds.scanner_overlap(on_right, lane_fwd))


	_check("...but one turned to face it does not",
		world.builds.scanner_overlap(on_right, - lane_fwd))
	world.builds.demolish(pair_scanner)
	var pair_press: HayCompressor = world.builds.add_compressor(on_left, lane_yaw)
	_check("a press on the other lane clears the first",
		not world.builds.compressor_overlap(on_right, lane_fwd))


	_check("...but a wrapper beside the press does not",
		world.builds.wrapper_overlap(on_right, lane_fwd))
	world.builds.demolish(pair_press)

	var pair_wrap: HayWrapper = world.builds.add_wrapper(on_left, lane_yaw)
	_check("a wrapper on the other lane clears the first",
		not world.builds.wrapper_overlap(on_right, lane_fwd))
	world.builds.demolish(pair_wrap)


	print("\n=== a scanner bolted straight onto an outfeed ===")


	var sizing: HaystackScanner = world.builds.add_scanner(on_left, lane_yaw)
	var onto_mouth:= splitter.port_left() - sizing.port_in()
	world.builds.demolish(sizing)
	var bolted: HaystackScanner = world.builds.add_scanner(on_left + onto_mouth, lane_yaw)
	for i in 4:
		await get_tree().physics_frame
	var mouth_off:= bolted.port_in().distance_to(splitter.port_left())
	_check("its mouth is on the left outfeed (%.4f off)" % mouth_off, mouth_off < 0.001)
	var left_route:= splitter.route(ConveyorSplitter.LEFT)
	_check("...and the left arm hands on to its deck",
		left_route != null and left_route.downstream == bolted.deck())
	world.builds.demolish(bolted)
	for i in 4:
		await get_tree().physics_frame
	_check("...and to nothing once it is gone",
		left_route != null and left_route.downstream == null)


	print("\n=== on the grid ===")


	var tool: BuildTool = player.build
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.U_SPLITTER)

	tool._reach = 14.0
	tool._grid_on = true
	player.global_position = Vector3(-6.0, 0.4, 9.0)
	_aim(Vector3(-6.3, 0.0, 12.4))
	for i in 4:
		await get_tree().physics_frame
	_aim(Vector3(-6.3, 0.0, 12.4))
	tool._update_u_splitter_ghost()
	var ghost:= tool._u_splitter_ghost
	_check("buildable there (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))
	var gc:= ghost.global_position
	_check("the centre is on a grid crossing (%.3f, %.3f)" % [gc.x, gc.z],
		_on_grid(gc.x) and _on_grid(gc.z))
	for side in ConveyorSplitter.SIDES:
		var p:= ghost.port(side)
		_check("outfeed %d on the grid (%.4f, %.4f)" % [side, p.x, p.z],
			_on_grid(p.x) and _on_grid(p.z))
	_check("the ghost's hologram carries three chevron chains", tool._ghost.visible)
	var before_count: int = world.builds.splitters.size()
	var money_before:= GameState.money
	tool._place_u_splitter()
	for i in 4:
		await get_tree().physics_frame
	_check("placing it builds a U", world.builds.splitters.size() == before_count + 1
		and world.builds.splitters [world.builds.splitters.size() - 1] is ConveyorUSplitter)
	_check("...for the Y splitter's price ($%.0f)" % (money_before - GameState.money),
		is_equal_approx(money_before - GameState.money, Cfg.SPLITTER_COST))
	var placed: ConveyorSplitter = world.builds.splitters [world.builds.splitters.size() - 1]

	var off_arm: Conveyor = world.builds.add_conveyor(
		world.builds.snap_endpoint(placed.port_left() + Vector3(0.2, 0.0, 0.1)),
		placed.port_left() + Vector3(0.0, 0.0, 3.0))
	for i in 4:
		await get_tree().physics_frame
	_check("a run snapped to the outfeed starts on the grid (%.4f, %.4f)" % [off_arm.a.x, off_arm.a.z],
		_on_grid(off_arm.a.x) and _on_grid(off_arm.a.z))
	_check("...and the route hands into it", placed.route(ConveyorSplitter.LEFT).downstream == off_arm)
	_check("...and the run leaves its end post to the wye (%s)" % [off_arm.support_stations()],
		not off_arm.support_stations().has(0.0))
	world.builds.demolish(off_arm)
	world.builds.demolish(placed)
	tool._grid_on = false
	tool.set_active(false)
	for i in 4:
		await get_tree().physics_frame


	print("\n=== walk up and press E ===")
	var from:= splitter.port_in() + Vector3(0.0, 1.2, -1.2)
	var seen: ConveyorSplitter = world.builds.splitter_under(from, splitter.global_position - from)
	_check("looking at it from its infeed finds the machine", seen == splitter)


	print("\n=== transport and division ===")
	var in_belt: Conveyor = world.builds.add_conveyor(feed_a, splitter.port_in())
	var out_belt:= { }
	var room:= Warehouse.INNER - WALL_MARGIN
	for side in ConveyorSplitter.SIDES:
		var end:= splitter.port(side) + splitter.forward() * OUT_RUN
		_check("the %d outfeed run stays inside the shed (%.2f, %.2f)" % [side, end.x, end.z],
			absf(end.x) < room and absf(end.z) < room)
		out_belt [side] = world.builds.add_conveyor(splitter.port(side), end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the feed run hands into the open route",
		splitter.routes().has(in_belt.downstream) and splitter.feeder() == in_belt)
	for side in ConveyorSplitter.SIDES:
		_check("route %d hands into its outfeed run" % side,
			splitter.route(side).downstream == out_belt [side])

	for side in ConveyorSplitter.SIDES:
		var route:= splitter.route(side)
		route.caught.connect(func(b: RigidBody3D) -> void:
			_caught [side] += 1
			_caught_hay [side] += (b as HayWad).strands if b is HayWad else 1
			_route_of [b.get_instance_id()] = side)
		(out_belt [side] as Conveyor).caught.connect(func(b: RigidBody3D) -> void:
			_arrived [side] += 1
			_arrived_hay [side] += (b as HayWad).strands if b is HayWad else 1
			var put_on: int = _route_of.get(b.get_instance_id(), -1)
			if put_on < 0:
				return
			if put_on == side:
				_agreed += 1
			else:
				_strayed += 1)

	var fed: Array [RigidBody3D] = []
	for i in FED:
		var at:= feed_a + Vector3(_rng.randf_range(-0.2, 0.2), 0.22, _rng.randf_range(0.0, 1.6))
		var strand: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if strand != null:
			fed.append(strand)

	var fell:= 0
	var blade_wrong:= 0
	var streak:= 0
	var ticks:= int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
		if i % 6 == 0:
			fell = maxi(fell, _fallen_through(splitter, fed))


		var angle: float = splitter._gate_angle
		if gate == null or absf(absf(angle) - Cfg.SPLITTER_GATE_SWING) >= 0.02:
			streak = 0
			continue
		if (angle > 0.0) == (splitter._imminent_side() == ConveyorSplitter.LEFT):
			streak = 0
			continue
		streak += 1
		blade_wrong = maxi(blade_wrong, streak)

	var took: int = _caught_hay [0] + _caught_hay [1]
	var got: int = _arrived_hay [0] + _arrived_hay [1]
	print("  fed %d, took on %d left, %d right, received %d left, %d right (strands %d in, %d out)"
		% [fed.size(), _caught [0], _caught [1], _arrived [0], _arrived [1], took, got])
	_check("the module took on most of the feed (%d of %d)" % [took, fed.size()],
		took >= int(fed.size() * 0.7))
	_check("nothing it took on was lost round a bend (%d in, %d out)" % [took, got],
		got >= took - 1)
	_check("no strand fell through the machine (worst %d at once)" % fell, fell == 0)
	_check("it kept both arms working (%d / %d)" % [_caught_hay [0], _caught_hay [1]],
		mini(_caught_hay [0], _caught_hay [1]) >= int(took * 0.2))
	_check("every load came out of the arm it was put on (%d kept, %d strayed)"
		% [_agreed, _strayed], _strayed == 0 and _agreed > 0)
	_check("the blade never sat facing the wrong arm (longest run %d ticks, limit %d)"
		% [blade_wrong, FactoryClock.stride + 1], blade_wrong <= FactoryClock.stride + 1)

	var quiet_left: int = _caught [0]
	var quiet_right: int = _caught [1]
	await _feed_line(feed_a, 12, 1.0, belt_secs(9.0))
	var quiet_l: int = _caught [0] - quiet_left
	var quiet_r: int = _caught [1] - quiet_right
	_check("fed one at a time, it divides them exactly (%d / %d)" % [quiet_l, quiet_r],
		quiet_l + quiet_r >= 8 and absi(quiet_l - quiet_r) <= 1)

	print("\n=== pinned to one arm ===")
	splitter.set_forced_side(ConveyorSplitter.RIGHT)
	var pin_left: int = _caught [0]
	var pin_right: int = _caught [1]
	await _feed_line(feed_a, 8, 1.0, belt_secs(9.0))
	var pinned_l: int = _caught [0] - pin_left
	var pinned_r: int = _caught [1] - pin_right
	_check("pinned right, every load went right (%d right, %d left)" % [pinned_r, pinned_l],
		pinned_r >= 6 and pinned_l == 0)
	_check("...and the blade sits across the shut arm (%.3f rad)"
		% (gate.rotation.y if gate != null else 0.0),
		gate != null and gate.rotation.y < - Cfg.SPLITTER_GATE_SWING + 0.02)
	splitter.set_forced_side(-1)

	print("\n=== wads round the bend ===")
	var wads_by:= [0, 0]
	var wads_out:= [0, 0]
	var wads: Array [RigidBody3D] = []


	for side in ConveyorSplitter.SIDES:
		splitter.route(side).caught.connect(func(b: RigidBody3D) -> void:
			if b.collision_layer & Cfg.L_PROP:
				wads_by [side] += 1)
		splitter.route(side).caught_record.connect(func(_seq: int, kind: int, _strands: int) -> void:
			if kind == BeltRun.Kind.WAD:
				wads_by [side] += 1)
		(out_belt [side] as Conveyor).caught.connect(func(b: RigidBody3D) -> void:
			if b.collision_layer & Cfg.L_PROP:
				wads_out [side] += 1)
		(out_belt [side] as Conveyor).caught_record.connect(func(_seq: int, kind: int, _strands: int) -> void:
			if kind == BeltRun.Kind.WAD:
				wads_out [side] += 1)
	var wad_fell:= 0
	for i in 6:
		var wad: RigidBody3D = world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
			feed_a + Vector3(0.0, 0.35, 0.0))) as RigidBody3D
		if wad != null:
			wads.append(wad)
		for k in int(belt_secs(2.24) / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
			if k % 6 == 0:
				wad_fell = maxi(wad_fell, _fallen_through(splitter, wads))
	for k in int(belt_secs(8.0) / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
		if k % 6 == 0:
			wad_fell = maxi(wad_fell, _fallen_through(splitter, wads))
	print("  wads aboard %d left, %d right; out %d left, %d right"
		% [wads_by [0], wads_by [1], wads_out [0], wads_out [1]])
	_check("it takes wads aboard (%d of 6)" % (wads_by [0] + wads_by [1]),
		wads_by [0] + wads_by [1] >= 4)
	_check("...one each way (%d / %d)" % [wads_by [0], wads_by [1]], mini(wads_by [0], wads_by [1]) >= 2)
	_check("...and every one comes out of its arm (%d in, %d out)"
		% [wads_by [0] + wads_by [1], wads_out [0] + wads_out [1]],
		wads_out [0] + wads_out [1] >= wads_by [0] + wads_by [1])
	_check("...with none dropped through the bend (%d)" % wad_fell, wad_fell == 0)
	for w in wads:
		if is_instance_valid(w) and w.is_inside_tree():
			world.props.remove(w as Carryable)


	print("\n=== save ===")
	splitter.set_forced_side(ConveyorSplitter.LEFT)
	var before: int = splitter.next_side
	var data: Array = world.builds.to_array()
	var found:= { }
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_u_splitter":
			found = entry
	_check("the U is written to the save as a U", not found.is_empty())
	_check("...with the arm it owes (%d) and the pin (%d)"
		% [int(found.get("next_side", -1)), int(found.get("forced_side", -99))],
		int(found.get("next_side", -1)) == before
			and int(found.get("forced_side", -99)) == ConveyorSplitter.LEFT)
	world.builds.from_array(data)
	var back: ConveyorSplitter = world.builds.splitters [0] if world.builds.splitters.size() == 1 else null
	var restored_pin: int = back.forced_side if back != null else -99
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("...and comes back as exactly one splitter", world.builds.splitters.size() == 1)
	_check("...which is a U", back is ConveyorUSplitter)
	_check("...still pinned to the same arm (%d)" % restored_pin,
		restored_pin == ConveyorSplitter.LEFT)
	if back != null:
		_check("...on the same spot (%.4f off)" % back.global_position.distance_to(centre_at),
			back.global_position.distance_to(centre_at) < 0.0001)
		var laid:= 0
		for side in ConveyorSplitter.SIDES:
			var r:= back.route(side)
			if r != null and r._line.size() == ConveyorUSplitter.BEND_PIECES + 4:
				laid += 1
		_check("...with both routes laid round their bends again (%d)" % laid, laid == 2)
		_check("...on six legs (%d)" % _legs(back), _legs(back) == 6)


		var old_save: Array = world.builds.to_array().duplicate(true)
		for entry in old_save:
			if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_u_splitter":
				(entry as Dictionary) ["type"] = "conveyor_splitter"
		world.builds.from_array(old_save)
		for i in 4:
			await get_tree().physics_frame
		var old_one: ConveyorSplitter = world.builds.splitters [0] if world.builds.splitters.size() == 1 else null
		_check("a conveyor_splitter entry still loads as a Y",
			old_one != null and not (old_one is ConveyorUSplitter))
		_check("...named as the Y was (%s)" % (old_one.name if old_one != null else "none"),
			old_one != null and str(old_one.name).begins_with("ConveyorSplitter"))
		var old_name: String = world.builds.name_of(old_one) if old_one != null else "none"
		_check("...and reports itself as a Belt Splitter (%s)" % old_name,
			old_name == BuildCatalog.display_name("splitter"))

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("U SPLITTER PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


static func _off_arm(p: Vector3, hand: float) -> float:
	var q:= Vector2(p.x, p.z)
	var flat:= func(v: Vector3) -> Vector2: return Vector2(v.x, v.z)
	var a0: Vector2 = flat.call(Vector3.ZERO)
	var a1: Vector2 = flat.call(ConveyorUSplitter.arm_point(hand, ConveyorUSplitter.BEND_S))
	var b0: Vector2 = flat.call(ConveyorUSplitter.arm_point(hand, ConveyorUSplitter.BEND_E))
	var b1: Vector2 = flat.call(ConveyorUSplitter.mouth_local(hand))
	var best:= minf(q.distance_to(Geometry2D.get_closest_point_to_segment(q, a0, a1)),
		q.distance_to(Geometry2D.get_closest_point_to_segment(q, b0, b1)))
	var c:= Vector2(0.0, ConveyorUSplitter.BEND_CENTRE_Z)


	var from_c:= q - c
	var start:= a1 - c
	var end:= b0 - c
	var span:= start.angle_to(end)
	var at:= start.angle_to(from_c)
	if signf(at) == signf(span) and absf(at) <= absf(span):
		best = minf(best, absf(from_c.length() - ConveyorUSplitter.BEND_R))
	return best


func _floor_owner(at: Vector3) -> String:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 0.3,
		Cfg.L_BUILD)
	var hit:= get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "nothing"
	var node:= hit.get("collider") as Node
	var owner_node: Node3D = world.builds.owner_of(node)
	if owner_node is ConveyorSplitter:
		return "machine"
	return str(node.name) if node != null else "?"


static func _fallen_through(wye: ConveyorSplitter, loads: Array) -> int:
	var n:= 0
	for rb in loads:
		if not is_instance_valid(rb) or not (rb as Node).is_inside_tree():
			continue
		var p: Vector3 = (rb as Node3D).global_position
		if p.y > wye.global_position.y - 0.3:
			continue
		for d: Vector4 in wye.footprint():
			if Vector2(p.x - d.x, p.z - d.z).length() < d.w:
				n += 1
				break
	return n


func _feed_line(at: Vector3, count: int, gap: float, tail: float) -> void:
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	for i in count:
		world.live.spawn(at + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.0),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		for k in int(gap / step):
			await get_tree().physics_frame
	for i in int(tail / step):
		await get_tree().physics_frame


func _legs(wye: Node3D) -> int:
	if wye == null or not is_instance_valid(wye):
		return -1
	var mmi:= wye.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		return -1
	return mmi.multimesh.instance_count


static func _on_grid(v: float) -> bool:
	return absf(v - roundf(v)) < 0.001


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
