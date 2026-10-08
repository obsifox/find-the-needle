class_name DevJoinerProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const FED:= 24


const CARRY_SECONDS:= 32.0 / Cfg.BELT_SPEED


const FEED_RUN:= 3.0
const OUT_RUN:= 3.0
const WALL_MARGIN:= 1.0

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0


var _arm_of: Dictionary = { }

var _boarded:= [0, 0]

var _delivered:= [0, 0]


var _reboarded:= 0


var _orphan:= 0


var _order: Array [int] = []


var _closest:= INF
var _closest_clear:= INF

const FLOOR_CLEAR:= 0.02


var _contended: Array [int] = []

var _both_free:= 0


var _held_streak:= 0
var _held_longest:= 0

var _pattern:= ""


var _gave: Array [int] = []
var _gave_pattern:= ""


var _pressed: Array [bool] = []


var _seen:= { }


var _double_give:= 0

var _loose_most:= 0


const JUNCTION_REACH:= 0.35


var _closest_note:= ""


func run() -> void:
	_rng.seed = 20260823
	for i in 40:
		await get_tree().process_frame


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var centre:= Vector3(-13.0, deck_y, -2.0)
	player.global_position = Vector3(-10.5, 0.4, 0.0)
	GameState.add_money(5000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== model ===")
	var joiner: ConveyorJoiner = world.builds.add_joiner(centre, 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var body:= joiner.get_node_or_null("Body") as MeshInstance3D
	_check("wye mesh instantiated", body != null and body.mesh != null)


	if body != null and body.mesh != null:
		_check("wye has 3 surfaces (rubber, frame, roller), got %d"
			% body.mesh.get_surface_count(), body.mesh.get_surface_count() == 3)


	_check("the body is stood the other way round (%.3f rad)"
		% (body.rotation.y if body != null else 0.0),
		body != null and is_equal_approx(absf(body.rotation.y), PI))
	_check("...and it is the joiner's own mesh, not the splitter's",
		body != null and body.mesh == ConveyorKit.joiner_mesh()
			and ConveyorKit.joiner_mesh() != ConveyorKit.splitter_mesh())


	for side in ConveyorJoiner.SIDES:
		var a:= joiner.arm(side)
		_check("arm %d laid" % side, a != null)
		if a == null:
			continue
		var line: PackedVector3Array = a._line
		_check("arm %d runs its own mouth -> the junction (%d points)"
			% [side, line.size()],
			line.size() == 2 and line [0].is_equal_approx(joiner.port(side))
				and line [1].is_equal_approx(joiner.global_position))
		_check("arm %d hands into the outfeed" % side, a.downstream == joiner.out_path())
	var out_path:= joiner.out_path()
	_check("outfeed laid", out_path != null)
	if out_path != null:
		var line: PackedVector3Array = out_path._line
		_check("outfeed runs the junction -> its own mouth (%d points)" % line.size(),
			line.size() == 2 and line [0].is_equal_approx(joiner.global_position)
				and line [1].is_equal_approx(joiner.port_out()))

	print("\n=== scroll direction ===")


	var ref_g:= DevSplitterProbe._scroll_gradient(ConveyorKit.segment_mesh(),
		Vector3.ZERO, Vector3.BACK)
	var ref_speed:= float(ConveyorKit.belt_material().get_shader_parameter("speed"))
	var joiner_speed:= float(
		ConveyorKit.belt_material_reversed().get_shader_parameter("speed"))
	print("  the belt section reads dV/d(travel) = %+.2f at speed %+.2f -- that is the convention"
		% [ref_g, ref_speed])
	_check("the reference section has a scroll direction at all (%+.2f)" % ref_g,
		absf(ref_g) > 0.9)
	_check("the joiner's compound runs against the splitter's (%+.2f vs %+.2f)"
		% [joiner_speed, ref_speed],
		absf(joiner_speed) > 0.01 and signf(joiner_speed) != signf(ref_speed))


	var lanes:= [
		["outfeed", Vector3(0.0, 0.0, -0.75), Vector3(0.0, 0.0, -1.0)],
		["left arm", ConveyorSplitter._arm_local(1.0) * 0.72,
			- ConveyorSplitter._arm_local(1.0).normalized()],
		["right arm", ConveyorSplitter._arm_local(-1.0) * 0.72,
			- ConveyorSplitter._arm_local(-1.0).normalized()],
	]
	for lane in lanes:
		var g:= DevSplitterProbe._scroll_gradient(ConveyorKit.joiner_mesh(),
			lane [1], lane [2], ConveyorKit.belt_material_reversed())
		_check("%s scrolls with the load, not against it (dV = %+.2f at speed %+.2f)"
			% [lane [0], g, joiner_speed],
			absf(g) > 0.9 and signf(g * joiner_speed) == signf(ref_g * ref_speed))

	print("\n=== geometry ===")
	for pair in [["left", joiner.port_left()], ["right", joiner.port_right()],
			["outfeed", joiner.port_out()]]:
		var label: String = pair [0]
		var mouth: Vector3 = pair [1]
		var r:= joiner.global_position.distance_to(mouth)
		_check("%s mouth %.3f m out (want %.2f)" % [label, r, Cfg.JOINER_PORT_R],
			absf(r - Cfg.JOINER_PORT_R) < 0.01)


		_check("...on the deck plane (%.3f vs %.3f)" % [mouth.y, deck_y],
			absf(mouth.y - deck_y) < 0.02)
	_check("travel is +Z as placed", joiner.forward().dot(Vector3.BACK) > 0.99)


	for pair in [["left", joiner.port_left()], ["right", joiner.port_right()]]:
		var mouth: Vector3 = pair [1]
		_check("the %s mouth is behind the junction (%.2f)"
			% [pair [0], (mouth - joiner.global_position).dot(joiner.forward())],
			(mouth - joiner.global_position).dot(joiner.forward()) < 0.0)
	_check("the outfeed mouth is in front of it",
		(joiner.port_out() - joiner.global_position).dot(joiner.forward()) > 0.0)
	var splay:= (joiner.global_position - joiner.port_left()).normalized().angle_to(joiner.forward())
	_check("arms splay %.1f deg (want %.1f)"
		% [rad_to_deg(splay), rad_to_deg(Cfg.JOINER_SPLAY)],
		absf(splay - Cfg.JOINER_SPLAY) < 0.01)

	_check("left mouth is on the leaving load's left (+X)",
		joiner.port_left().x > joiner.global_position.x)

	print("\n=== snapping ===")
	for pair in [["left", joiner.port_left()], ["right", joiner.port_right()],
			["outfeed", joiner.port_out()]]:
		var mouth: Vector3 = pair [1]
		var near: Vector3 = mouth + Vector3(0.3, 0.0, 0.35)
		var snapped: Vector3 = world.builds.snap_endpoint(near)
		_check("belt end snaps to the %s mouth (off by %.3f m)"
			% [pair [0], snapped.distance_to(mouth)], snapped.is_equal_approx(mouth))
	var far:= joiner.global_position + Vector3(6.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second joiner on the same spot is refused",
		world.builds.joiner_overlap(joiner.global_position))
	_check("...and so is a splitter spliced into the same stretch",
		world.builds.splitter_overlap(joiner.global_position))

	print("\n=== the rig ===")
	var feed_start:= { }
	for side in ConveyorJoiner.SIDES:
		feed_start [side] = joiner.port(side) - joiner.arm_travel(side) * FEED_RUN
	var out_end:= joiner.port_out() + joiner.forward() * OUT_RUN
	var room:= Warehouse.INNER - WALL_MARGIN
	for pair in [["left feed", feed_start [ConveyorJoiner.LEFT]],
			["right feed", feed_start [ConveyorJoiner.RIGHT]], ["outfeed", out_end]]:
		var end: Vector3 = pair [1]
		_check("the %s run stays inside the shed (%.2f, %.2f)"
			% [pair [0], end.x, end.z], absf(end.x) < room and absf(end.z) < room)

	var feed_belt:= { }
	for side in ConveyorJoiner.SIDES:
		feed_belt [side] = world.builds.add_conveyor(feed_start [side], joiner.port(side))
	var out_belt: Conveyor = world.builds.add_conveyor(joiner.port_out(), out_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	for side in ConveyorJoiner.SIDES:
		var belt:= feed_belt [side] as Conveyor
		_check("the %s feed run hands into arm %d"
			% ["left" if side == ConveyorJoiner.LEFT else "right", side],
			belt != null and belt.downstream == joiner.arm(side))
	_check("the outfeed hands into the run leaving it",
		out_path != null and out_path.downstream == out_belt)

	print("\n=== merging ===")
	for side in ConveyorJoiner.SIDES:
		var a:= joiner.arm(side)
		if a != null:
			a.caught.connect(func(b: RigidBody3D) -> void:


				_boarded_on(side, b.get_instance_id()))

			a.caught_record.connect(func(seq: int, _kind: int, _strands: int) -> void:
				_boarded_on(side, seq))
	if out_path != null:
		out_path.caught.connect(func(b: RigidBody3D) -> void:
			_delivered_by(joiner, _arm_of.get(b.get_instance_id(), -1)))
		out_path.caught_record.connect(func(seq: int, _kind: int, _strands: int) -> void:
			_delivered_by(joiner, _arm_of.get(seq, -1)))

	var fed:= 0
	var fed_bodies: Array [RigidBody3D] = []
	for side in ConveyorJoiner.SIDES:
		var along:= joiner.arm_travel(side)
		var across:= Vector3.UP.cross(along).normalized()
		for i in FED:
			var at: Vector3 = feed_start [side] + along * _rng.randf_range(0.0, 1.6) + across * _rng.randf_range(-0.2, 0.2) + Vector3.UP * 0.22
			var strand: RigidBody3D = world.live.spawn(at,
				StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
			if strand != null:
				fed += 1
				fed_bodies.append(strand)

	var ticks:= int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
		if not is_instance_valid(joiner):
			continue


		var free:= 0
		for side in ConveyorJoiner.SIDES:
			var a:= joiner.arm(side)
			if a != null and not a._outlet_held:
				free += 1
		if free > 1:
			_both_free += 1
		if free == 0:
			_held_streak += 1
			_held_longest = maxi(_held_longest, _held_streak)
		else:
			_held_streak = 0


		var gave_this_step:= 0
		for side in ConveyorJoiner.SIDES:
			var a:= joiner.arm(side)
			if a == null:
				continue
			var now:= { }
			for m in a.load_marks():
				now [m ["id"]] = true
			var was: Dictionary = _seen.get(side, { })
			for id in was:
				if now.has(id):
					continue
				gave_this_step += 1
				_gave.append(side)
				var rival:= joiner.arm(ConveyorJoiner.LEFT
					if side == ConveyorJoiner.RIGHT else ConveyorJoiner.RIGHT)
				var mark:= "l" if side == ConveyorJoiner.LEFT else "r"


				if rival != null and rival.has_load_waiting():
					_pressed.append(true)
					mark = mark.to_upper()
				else:
					_pressed.append(false)
				_gave_pattern += mark
			_seen [side] = now
		if gave_this_step > 1:
			_double_give += 1


		var loose:= 0
		for b in fed_bodies:


			if not is_instance_valid(b) or not b.is_inside_tree() or BeltPath.is_rider(b):
				continue
			if b.global_position.distance_to(joiner.global_position) < JUNCTION_REACH:
				loose += 1
		_loose_most = maxi(_loose_most, loose)
		if out_path != null:
			var riders:= out_path.riders_debug()
			for k in riders.size():
				var a_r: Dictionary = riders [k]
				for j in range(k + 1, riders.size()):
					var b_r: Dictionary = riders [j]
					if absf(float(a_r ["side"]) - float(b_r ["side"])) > Cfg.STRAND_THICK * 6.0:
						continue
					var gap:= absf(float(a_r ["s"]) - float(b_r ["s"]))
					_closest = minf(_closest, gap)


					var open_deck: float = out_path.path_length() - BeltPath.END_DEAD_ZONE - FLOOR_CLEAR
					if float(a_r ["s"]) > FLOOR_CLEAR and float(b_r ["s"]) > FLOOR_CLEAR and float(a_r ["s"]) < open_deck and float(b_r ["s"]) < open_deck and gap < _closest_clear:
						_closest_clear = gap
						_closest_note = ("#%d at s=%.3f side=%+.3f vs #%d at s=%.3f side=%+.3f"
							% [int(a_r ["seq"]), float(a_r ["s"]), float(a_r ["side"]),
								int(b_r ["seq"]), float(b_r ["s"]), float(b_r ["side"])])

	var boarded: int = _boarded [ConveyorJoiner.LEFT] + _boarded [ConveyorJoiner.RIGHT]
	var got: int = _delivered [ConveyorJoiner.LEFT] + _delivered [ConveyorJoiner.RIGHT]
	print("  fed %d, boarded %d left / %d right, delivered %d left / %d right"
		% [fed, _boarded [ConveyorJoiner.LEFT], _boarded [ConveyorJoiner.RIGHT],
			_delivered [ConveyorJoiner.LEFT], _delivered [ConveyorJoiner.RIGHT]])

	_check("both lines got moving (%d / %d boarded)"
		% [_boarded [ConveyorJoiner.LEFT], _boarded [ConveyorJoiner.RIGHT]],
		_boarded [ConveyorJoiner.LEFT] > 0 and _boarded [ConveyorJoiner.RIGHT] > 0)
	_check("the arms took on most of the feed (%d of %d)" % [boarded, fed],
		boarded >= int(fed * 0.8))


	_check("everything that boarded came out of the outfeed (%d in, %d out)"
		% [boarded, got], got >= boarded - 2)


	_check("hardly anything was picked up twice (%d)" % _reboarded, _reboarded <= 1)


	_check("almost everything came up an arm rather than over the junction (%d loose)"
		% _orphan, _orphan <= maxi(2, int(fed * 0.1)))


	var lean: int = absi(_delivered [ConveyorJoiner.LEFT]
		- _delivered [ConveyorJoiner.RIGHT])
	_check("neither line was starved (%d / %d, lean %d)"
		% [_delivered [ConveyorJoiner.LEFT], _delivered [ConveyorJoiner.RIGHT], lean],
		got > 0 and mini(_delivered [ConveyorJoiner.LEFT],
			_delivered [ConveyorJoiner.RIGHT]) >= int(got * 0.35))


	var jumped:= 0
	var contended:= 0
	for k in _gave.size() - 1:
		if not _pressed [k]:
			continue
		contended += 1
		if _gave [k + 1] == _gave [k]:
			jumped += 1
	var streak:= 1
	var longest:= 1
	for k in range(1, _order.size()):
		streak = streak + 1 if _order [k] == _order [k - 1] else 1
		longest = maxi(longest, streak)
	print("  %d of %d hand-overs were contended; the longest unbroken run of arrivals from one arm was %d"
		% [contended, _gave.size(), longest])
	print("  the order they were handed over: %s" % _gave_pattern)
	print("  the order they arrived:          %s" % _pattern)
	_check("no line ever took a contended slot twice running (%d of %d)"
		% [jumped, contended], contended > 4 and jumped == 0)


	print("  the closest two loads ever lay on the outfeed: %.3f m (%.3f m clear of its ends: %s)"
		% [_closest, _closest_clear, _closest_note])
	print("  the most loads ever loose within %.2f m of the junction at once: %d"
		% [JUNCTION_REACH, _loose_most])


	_check("the two arms never let go in the same step (%d)" % _double_give,
		_double_give == 0)
	_check("the interlock never freed both arms at once (%d steps)" % _both_free,
		_both_free == 0)


	_check("...and never shut for long (longest %d steps with neither released)"
		% _held_longest, _held_longest <= ConveyorJoiner.FLIGHT_LIMIT + 2)

	print("\n=== a bale keeps its turn ===")


	var bale_side:= ConveyorJoiner.LEFT
	var hay_side:= ConveyorJoiner.RIGHT


	var through:= [0]
	if out_path != null:
		out_path.caught.connect(func(b: RigidBody3D) -> void:
			if b is HayBale:
				through [0] += 1)


		out_path.caught_record.connect(func(_seq: int, kind: int, _strands: int) -> void:
			if kind == BeltRun.Kind.BALE:
				through [0] += 1)
	var bale_along:= joiner.arm_travel(bale_side)
	var hay_along:= joiner.arm_travel(hay_side)
	var hay_across:= Vector3.UP.cross(hay_along).normalized()
	var bales_fed:= 0
	var hay_next:= 0.0
	var bale_next:= 0.0
	var window:= 0.0
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	while window < 30.0:
		await get_tree().physics_frame
		window += step
		hay_next -= step
		bale_next -= step
		if hay_next <= 0.0:
			hay_next = 0.25
			world.live.spawn(feed_start [hay_side] + hay_along * 0.3
				+ hay_across * _rng.randf_range(-0.1, 0.1) + Vector3.UP * 0.22,
				StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if bales_fed < 2 and bale_next <= 0.0:
			bale_next = 4.0
			var bale: HayBale = world.props.spawn("hay_bale", Transform3D(Basis(),
				feed_start [bale_side] + bale_along * 0.3 + Vector3.UP * 0.05)) as HayBale
			if bale != null:
				bale.strands = Cfg.COMPRESSOR_BALE_STRANDS
				bales_fed += 1
		if bales_fed >= 2 and through [0] >= 2:
			break
	print("  %d bales fed against steady hay on the other line, %d came through in %.1f s"
		% [bales_fed, through [0], window])
	_check("a line of bales is served while the other line is busy (%d of %d)"
		% [through [0], bales_fed], bales_fed == 2 and through [0] >= 2)

	print("\n=== save ===")
	var before: int = joiner.next_side
	var data: Array = world.builds.to_array()
	var found:= { }
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_joiner":
			found = entry
	_check("the joiner is written to the save", not found.is_empty())
	_check("...with the arm it owes the next load (%d)" % before,
		int(found.get("next_side", -1)) == before)
	world.builds.from_array(data)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("...and comes back as exactly one joiner", world.builds.joiners.size() == 1)
	if world.builds.joiners.size() == 1:
		var reloaded: ConveyorJoiner = world.builds.joiners [0]
		_check("...still owing the same arm", reloaded.next_side == before)
		var freed:= 0
		for side in ConveyorJoiner.SIDES:
			var a:= reloaded.arm(side)
			if a != null and not a._outlet_held:
				freed += 1
		_check("...with exactly one arm released again, got %d" % freed, freed == 1)
		_check("...and its outfeed pointed at the run leaving it",
			reloaded.out_path() != null and reloaded.out_path().downstream != null)

	print("\n=== placement ===")


	var tool: BuildTool = player.build
	tool._reach = 14.0
	var run_end:= Vector3(-13.0, deck_y, -7.0)
	var feed: Conveyor = world.builds.add_conveyor(run_end - Vector3(0, 0, 3.0), run_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	tool._mode = BuildTool.Mode.JOINER


	var aim:= run_end + Vector3(0.0, - deck_y, 0.5)
	for stand in [["left", Vector3(-16.5, 0.4, -8.0), true],
			["right", Vector3(-9.5, 0.4, -8.0), false]]:
		player.global_position = stand [1]
		_aim(aim)
		for i in 4:
			await get_tree().physics_frame
		tool._update_joiner_ghost()
		var ghost: ConveyorJoiner = tool._joiner_ghost
		var want_left: bool = stand [2]
		var mouth: Vector3 = ghost.port_left() if want_left else ghost.port_right()
		var other: Vector3 = ghost.port_right() if want_left else ghost.port_left()
		_check("standing on the %s of the line, it is buildable there (%s)"
			% [stand [0], tool._eval ["reason"]], tool._eval ["ok"])
		_check("...and the run ends in the %s arm (%.3f m off)"
			% ["left" if want_left else "right", mouth.distance_to(run_end)],
			mouth.distance_to(run_end) < 0.01)
		_check("...not in the other one (%.3f m)" % other.distance_to(run_end),
			other.distance_to(run_end) > 1.0)


		var look:= player.look_direction()
		look.y = 0.0
		_check("...and the outfeed leaves the way they were facing (%.2f)"
			% ghost.forward().dot(look.normalized()),
			ghost.forward().dot(look.normalized()) > 0.5)


		var arm_dir:= (ghost.global_position - mouth).normalized()
		_check("...with the arm laid along the run itself (%.3f)"
			% arm_dir.dot(feed.forward), arm_dir.dot(feed.forward) > 0.999)

	print("\n=== the joint into an arm ===")


	var joiner_now: ConveyorJoiner = world.builds.joiners [0] if world.builds.joiners.size() > 0 else null
	if joiner_now != null:
		var mouth:= joiner_now.port(ConveyorJoiner.RIGHT)
		var bearing:= joiner_now.arm_travel(ConveyorJoiner.RIGHT)


		var straight_at:= mouth - joiner_now.forward() * 4.0
		var runs_before: int = world.builds.conveyors.size()
		var bends_before: int = world.builds.corners.size()
		player.build._lay_run(straight_at, mouth)
		for i in 4:
			await get_tree().physics_frame
		var laid: int = world.builds.conveyors.size() - runs_before
		_check("a run aimed at an arm is laid in two pieces (%d)" % laid, laid == 2)
		var last: Conveyor = world.builds.conveyors [world.builds.conveyors.size() - 1]
		_check("...the piece that meets the mouth runs along the arm (%.3f)"
			% last.forward.dot(bearing), last.forward.dot(bearing) > 0.999)
		_check("...and it ends ON the mouth (%.3f m)" % last.b.distance_to(mouth),
			last.b.distance_to(mouth) < 0.01)
		_check("...with a rounded corner fitted where it turns (%d new)"
			% (world.builds.corners.size() - bends_before),
			world.builds.corners.size() > bends_before)


		var knee: Conveyor = world.builds.conveyors [world.builds.conveyors.size() - 2]
		_check("...paid for out of both runs (%.2f m and %.2f m trimmed)"
			% [knee.trim_end, last.trim_start],
			knee.trim_end > 0.05 and last.trim_start > 0.05)


	var arm_wye: ConveyorSplitter = world.builds.add_splitter(
		Vector3(-12.0, deck_y, 6.0), 0.0)
	var in_wye: ConveyorSplitter = world.builds.add_splitter(
		Vector3(-9.0, deck_y, 11.0), PI * 0.5)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var arm_side: int = ConveyorSplitter.SIDES [0]
	for side: int in ConveyorSplitter.SIDES:
		if arm_wye.port(side).x > arm_wye.port(arm_side).x:
			arm_side = side
	var arm_mouth:= arm_wye.port(arm_side)
	var arm_bearing:= (arm_mouth - arm_wye.global_position).normalized()
	var infeed:= in_wye.port_in()
	var aimed:= (infeed - arm_mouth).normalized()
	print("  arm %.0f deg off the run, infeed %.0f deg off it"
		% [rad_to_deg(arm_bearing.angle_to(aimed)),
			rad_to_deg(in_wye.forward().angle_to(aimed))])
	var preview: PackedVector3Array = tool._preview_points(arm_mouth, infeed)
	_check("the hologram of a port to port run leaves the arm along it (%.3f)"
		% (preview [1] - arm_mouth).normalized().dot(arm_bearing),
		(preview [1] - arm_mouth).normalized().dot(arm_bearing) > 0.999)
	var port_runs_before: int = world.builds.conveyors.size()
	var port_bends_before: int = world.builds.corners.size()
	player.build._lay_run(arm_mouth, infeed)
	for i in 4:
		await get_tree().physics_frame
	var n: int = world.builds.conveyors.size()
	_check("a run from one port to another at an angle is laid in three pieces (%d)"
		% (n - port_runs_before), n - port_runs_before == 3)
	if n - port_runs_before == 3:
		var leaving: Conveyor = world.builds.conveyors [n - 3]
		var arriving: Conveyor = world.builds.conveyors [n - 1]
		_check("...the piece on the arm starts ON its mouth (%.3f m)"
			% leaving.a.distance_to(arm_mouth), leaving.a.distance_to(arm_mouth) < 0.01)
		_check("...and runs along the arm (%.3f)" % leaving.forward.dot(arm_bearing),
			leaving.forward.dot(arm_bearing) > 0.999)
		_check("...the piece at the infeed runs along the machine (%.3f)"
			% arriving.forward.dot(in_wye.forward()),
			arriving.forward.dot(in_wye.forward()) > 0.999)
		_check("...and ends ON the infeed (%.3f m)" % arriving.b.distance_to(infeed),
			arriving.b.distance_to(infeed) < 0.01)
		_check("...with a rounded corner at both knees (%d new)"
			% (world.builds.corners.size() - port_bends_before),
			world.builds.corners.size() - port_bends_before >= 2)

	print("\n=== flow chevrons ===")


	var mm: MultiMesh = tool._flow.multimesh
	_check("the joiner ghost draws chevrons (%d)" % mm.visible_instance_count,
		mm.visible_instance_count >= 6)


	tool._mode = BuildTool.Mode.SPLITTER
	tool._update_splitter_ghost()
	_check("the splitter ghost draws chevrons too (%d)" % mm.visible_instance_count,
		mm.visible_instance_count >= 6)


	tool.set_active(false)
	_check("putting the tool away takes the chevrons with it", not tool._ghost.visible)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("JOINER PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _boarded_on(side: int, key: int) -> void:
	if _arm_of.has(key):
		_reboarded += 1
		return
	_boarded [side] += 1
	_arm_of [key] = side


func _delivered_by(joiner: ConveyorJoiner, from: int) -> void:
	if from < 0:
		_orphan += 1
		return
	_delivered [from] += 1
	_order.append(from)


	var rival:= joiner.arm(ConveyorJoiner.LEFT if from == ConveyorJoiner.RIGHT
		else ConveyorJoiner.RIGHT)
	var pressed: bool = rival != null and rival.has_load_waiting()
	if pressed:
		_contended.append(from)


	var mark:= "l" if from == ConveyorJoiner.LEFT else "r"
	_pattern += mark.to_upper() if pressed else mark


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
