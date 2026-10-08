class_name DevUJoinerProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const FED:= 24
const CARRY_SECONDS:= 36.0 / Cfg.BELT_SPEED
const FEED_RUN:= 3.0
const OUT_RUN:= 3.0
const WALL_MARGIN:= 1.0
const LINE_TOL:= 0.002

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0
var _arm_of: Dictionary = { }
var _boarded:= [0, 0]
var _delivered:= [0, 0]
var _reboarded:= 0
var _orphan:= 0
var _gave: Array [int] = []
var _pressed: Array [bool] = []
var _seen:= { }
var _double_give:= 0
var _both_free:= 0
var _held_streak:= 0
var _held_longest:= 0


func run() -> void:
	_rng.seed = 20260912
	for i in 40:
		await get_tree().process_frame

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var centre_at:= Vector3(-13.0, deck_y, 2.0)
	player.global_position = Vector3(-10.0, 0.4, 0.0)
	GameState.add_money(5000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	print("\n=== model ===")
	var joiner: ConveyorUJoiner = world.builds.add_u_joiner(centre_at, 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("it is filed with the joiners", world.builds.joiners.has(joiner))
	_check("...and in their group", joiner.is_in_group("conveyor_joiners"))
	_check("...and names itself as the U (%s)" % world.builds.name_of(joiner),
		world.builds.name_of(joiner) == BuildCatalog.display_name("u_joiner")
			and BuildCatalog.display_name("u_joiner") != BuildCatalog.display_name("joiner"))
	var body:= joiner.get_node_or_null("Body") as MeshInstance3D
	_check("U mesh instantiated", body != null and body.mesh != null)
	_check("...and it is the U joiner's own copy",
		body != null and body.mesh == ConveyorKit.u_joiner_mesh()
			and body.mesh != ConveyorKit.u_splitter_mesh())
	if body != null and body.mesh != null:
		_check("U has 3 surfaces, got %d" % body.mesh.get_surface_count(),
			body.mesh.get_surface_count() == 3)
	_check("the body is stood the other way round (%.3f rad)"
		% (body.rotation.y if body != null else 0.0),
		body != null and absf(absf(body.rotation.y) - PI) < 0.001)
	_check("no blade and no readout", joiner.get_node_or_null("Gate") == null
		and joiner.get_node_or_null("Readout") == null)


	print("\n=== scroll direction ===")
	var ref_g:= DevSplitterProbe._scroll_gradient(ConveyorKit.segment_mesh(),
		Vector3.ZERO, Vector3.BACK)
	var ref_speed:= float(ConveyorKit.belt_material().get_shader_parameter("speed"))
	var rev_speed:= float(ConveyorKit.belt_material_reversed().get_shader_parameter("speed"))
	_check("the reversed compound runs against the running one (%+.2f vs %+.2f)"
		% [rev_speed, ref_speed], absf(rev_speed) > 0.01 and signf(rev_speed) != signf(ref_speed))


	var mid_s:= ConveyorUSplitter.BEND_S + ConveyorUSplitter.BEND_ARC * 0.5
	for lane in [["outfeed", Vector3(0.0, 0.0, -0.75), Vector3.FORWARD],
			["an arm's bend", ConveyorUSplitter.arm_point(1.0, mid_s),
				- ConveyorUSplitter.arm_heading(1.0, mid_s)],
			["an arm's straight", Vector3(1.0, 0.0, 1.75), Vector3.FORWARD],
			["the other arm's bend", ConveyorUSplitter.arm_point(-1.0, mid_s),
				- ConveyorUSplitter.arm_heading(-1.0, mid_s)]]:
		var g:= DevSplitterProbe._scroll_gradient(ConveyorKit.u_joiner_mesh(),
			lane [1], lane [2], ConveyorKit.belt_material_reversed())
		_check("%s scrolls with the load (dV = %+.2f at speed %+.2f)" % [lane [0], g, rev_speed],
			absf(g) > 0.9 and signf(g * rev_speed) == signf(ref_g * ref_speed))


	print("\n=== ports and arms ===")
	for row in [["left", joiner.port_left(), Vector3(1.0, 0.0, -2.0)],
			["right", joiner.port_right(), Vector3(-1.0, 0.0, -2.0)],
			["outfeed", joiner.port_out(), Vector3(0.0, 0.0, 1.05)]]:
		var local:= joiner.to_local(row [1] as Vector3)
		_check("%s port at %s (want %s)" % [row [0], local, row [2]],
			local.distance_to(row [2] as Vector3) < 0.0001)
	_check("left mouth is on the leaving load's left (+X)",
		joiner.port_left().x > joiner.global_position.x)
	for side in ConveyorJoiner.SIDES:
		_check("arm %d brings its load in along the line" % side,
			joiner.arm_travel(side).dot(joiner.forward()) > 0.9999
				and world.builds.port_bearing_at(joiner.port(side)).dot(joiner.forward()) > 0.9999)
		var arm:= joiner.arm(side)
		if arm == null:
			_check("arm %d laid" % side, false)
			continue
		var line: PackedVector3Array = arm._line
		_check("arm %d runs its mouth, round the bend, to the junction (%d points)"
			% [side, line.size()],
			line.size() == ConveyorUSplitter.BEND_PIECES + 3
				and line [0].is_equal_approx(joiner.port(side))
				and line [line.size() - 1].is_equal_approx(joiner.global_position))

		var hand:= -1.0 if side == ConveyorJoiner.LEFT else 1.0
		var off:= 0.0
		for p: Vector3 in line:
			var local:= joiner.to_local(p)
			off = maxf(off, DevUSplitterProbe._off_arm(Vector3(- local.x, 0.0, - local.z), hand))
		_check("...every corner of it on the modelled centreline (worst %.4f m)" % off,
			off < LINE_TOL)
		_check("...and it hands into the outfeed", arm.downstream == joiner.out_path())


	print("\n=== the deck under it ===")
	for p: Vector3 in [Vector3(0.0, 0.0, -1.8), Vector3(0.0, 0.0, -1.25)]:
		var hit:= _floor_owner(joiner.to_global(p))
		_check("nothing of the machine's lies across the gap at %s (%s)" % [p, hit],
			hit != "machine")
	for p: Vector3 in [Vector3(-0.47, 0.0, 0.195), Vector3(0.47, 0.0, 0.195)]:
		var hit:= _floor_owner(joiner.to_global(p))
		_check("the side notch at %s is closed (%s)" % [p, hit], hit == "machine")


	print("\n=== legs ===")
	_check("it stands on six legs (%d)" % _legs(joiner), _legs(joiner) == 6)
	var pads:= [Vector3(1.0, -0.176, -2.0 + 0.27), Vector3(-1.0, -0.176, -2.0 + 0.27),
		Vector3(0.0, -0.176, Cfg.JOINER_PORT_R - 0.27)]
	var lanes: Array = joiner._lanes()
	for i in lanes.size():
		var got:= joiner._pad_centre(lanes [i])
		_check("pads for lane %d centred at %s (want %s)" % [i, got, pads [i]],
			got.distance_to(pads [i]) < 0.0001)


	print("\n=== snapping and overlap ===")
	for row in [["left", joiner.port_left()], ["right", joiner.port_right()],
			["outfeed", joiner.port_out()]]:
		var mouth: Vector3 = row [1]
		var snapped: Vector3 = world.builds.snap_endpoint(mouth + Vector3(0.3, 0.0, -0.35))
		_check("belt end snaps to the %s mouth (off by %.3f m)"
			% [row [0], snapped.distance_to(mouth)], snapped.is_equal_approx(mouth))
	_check("a Y joiner on the same spot is refused", world.builds.joiner_overlap(centre_at))
	_check("a Y splitter mated to the outfeed is not",
		not world.builds.splitter_overlap(joiner.port_out() + Vector3(0.0, 0.0, Cfg.SPLITTER_PORT_R)))


	print("\n=== an arm onto a run end, through the tool ===")
	var tool: BuildTool = player.build
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.U_JOINER)
	tool._reach = 14.0
	tool._grid_on = true


	var run_end:= Vector3(-9.0, deck_y, 8.0)
	var lead: Conveyor = world.builds.add_conveyor(run_end - Vector3(0.0, 0.0, 3.0), run_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	for row in [["right of the run", 1.0, Vector3(-9.9, 0.0, 8.1)],
			["left of the run", -1.0, Vector3(-8.1, 0.0, 8.1)]]:
		player.global_position = Vector3(-9.0, 0.4, 4.0)
		_aim(row [2])
		for i in 4:
			await get_tree().physics_frame
		_aim(row [2])
		tool._update_u_joiner_ghost()
		var ghost:= tool._u_joiner_ghost
		var hand: float = row [1]
		var side:= ConveyorJoiner.LEFT if hand > 0.0 else ConveyorJoiner.RIGHT
		_check("aimed %s, it is buildable (%s)" % [row [0], tool._eval ["reason"]],
			bool(tool._eval ["ok"]))
		_check("...the %s arm's mouth is on the run end (%.4f m off)"
			% ["left" if hand > 0.0 else "right", ghost.port(side).distance_to(run_end)],
			ghost.port(side).distance_to(run_end) < 0.001)
		_check("...the body stands %s (%.2f)" % [row [0], ghost.global_position.x - run_end.x],
			signf(ghost.global_position.x - run_end.x) == - hand)
		_check("...carrying on along the run", ghost.forward().dot(lead.forward) > 0.9999)
		_check("...with both inlets on the grid", _on_grid(ghost.port_left().x)
			and _on_grid(ghost.port_left().z) and _on_grid(ghost.port_right().x)
			and _on_grid(ghost.port_right().z))
	var money_before:= GameState.money
	var count_before: int = world.builds.joiners.size()
	tool._place_u_joiner()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var placed: ConveyorJoiner = world.builds.joiners [world.builds.joiners.size() - 1] if world.builds.joiners.size() == count_before + 1 else null
	_check("placing it builds a U joiner", placed is ConveyorUJoiner)
	_check("...for the Y joiner's price ($%.0f)" % (money_before - GameState.money),
		is_equal_approx(money_before - GameState.money, Cfg.JOINER_COST))
	if placed != null:
		_check("...and the run hands into the arm on its end",
			lead.downstream == placed.arm(ConveyorJoiner.RIGHT))
		_check("...and gives up its end post to the wye (%s)" % [lead.support_stations()],
			not lead.support_stations().has(lead.length))
		world.builds.demolish(placed)
	world.builds.demolish(lead)
	tool._grid_on = false
	tool.set_active(false)
	for i in 4:
		await get_tree().physics_frame


	print("\n=== the rig ===")
	var feed_start:= { }
	var feed_belt:= { }
	var room:= Warehouse.INNER - WALL_MARGIN
	for side in ConveyorJoiner.SIDES:
		feed_start [side] = joiner.port(side) - joiner.arm_travel(side) * FEED_RUN
		var s: Vector3 = feed_start [side]
		_check("feed %d stays inside the shed (%.2f, %.2f)" % [side, s.x, s.z],
			absf(s.x) < room and absf(s.z) < room)
		feed_belt [side] = world.builds.add_conveyor(feed_start [side], joiner.port(side))
	var out_end:= joiner.port_out() + joiner.forward() * OUT_RUN
	var out_belt: Conveyor = world.builds.add_conveyor(joiner.port_out(), out_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	for side in ConveyorJoiner.SIDES:
		_check("feed run %d hands into arm %d" % [side, side],
			(feed_belt [side] as Conveyor).downstream == joiner.arm(side))
	_check("the outfeed hands into the run leaving it", joiner.out_path().downstream == out_belt)


	print("\n=== merging round the bends ===")
	for side in ConveyorJoiner.SIDES:
		joiner.arm(side).caught.connect(func(b: RigidBody3D) -> void:
			if _arm_of.has(b.get_instance_id()):
				_reboarded += 1
				return
			_boarded [side] += 1
			_arm_of [b.get_instance_id()] = side)
	joiner.out_path().caught.connect(func(b: RigidBody3D) -> void:
		var from: int = _arm_of.get(b.get_instance_id(), -1)
		if from < 0:
			_orphan += 1
			return
		_delivered [from] += 1)

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

	var fell:= 0
	var ticks:= int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
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
			var now:= { }
			for m in a.load_marks():
				now [m ["id"]] = true
			var was: Dictionary = _seen.get(side, { })
			for id in was:
				if now.has(id):
					continue
				gave_this_step += 1
				_gave.append(side)
				var rival:= joiner.arm(ConveyorJoiner.LEFT if side == ConveyorJoiner.RIGHT
					else ConveyorJoiner.RIGHT)
				_pressed.append(rival.has_load_waiting())
			_seen [side] = now
		if gave_this_step > 1:
			_double_give += 1
		if i % 6 == 0:
			fell = maxi(fell, _fallen_through(joiner, fed_bodies))

	var boarded: int = _boarded [0] + _boarded [1]
	var got: int = _delivered [0] + _delivered [1]
	print("  fed %d, boarded %d left / %d right, delivered %d left / %d right"
		% [fed, _boarded [0], _boarded [1], _delivered [0], _delivered [1]])
	_check("both lines got moving (%d / %d)" % [_boarded [0], _boarded [1]],
		_boarded [0] > 0 and _boarded [1] > 0)
	_check("the arms took on most of the feed (%d of %d)" % [boarded, fed],
		boarded >= int(fed * 0.8))
	_check("nothing that boarded was lost round a bend (%d in, %d out)" % [boarded, got],
		got >= boarded - 2)
	_check("no strand fell through the machine (worst %d at once)" % fell, fell == 0)
	_check("hardly anything was picked up twice (%d)" % _reboarded, _reboarded <= 1)
	_check("almost everything came up an arm (%d loose)" % _orphan,
		_orphan <= maxi(2, int(fed * 0.1)))
	_check("neither line was starved (%d / %d)" % [_delivered [0], _delivered [1]],
		got > 0 and mini(_delivered [0], _delivered [1]) >= int(got * 0.35))
	var jumped:= 0
	var contended:= 0
	for k in _gave.size() - 1:
		if not _pressed [k]:
			continue
		contended += 1
		if _gave [k + 1] == _gave [k]:
			jumped += 1
	_check("no line ever took a contended slot twice running (%d of %d)" % [jumped, contended],
		contended > 4 and jumped == 0)
	_check("the two arms never let go in the same step (%d)" % _double_give, _double_give == 0)
	_check("the interlock never freed both arms at once (%d steps)" % _both_free, _both_free == 0)
	_check("...and never shut for long (longest %d steps)" % _held_longest,
		_held_longest <= ConveyorJoiner.FLIGHT_LIMIT + 2)

	await _record_deadlock(joiner, feed_belt, out_belt)


	print("\n=== save ===")
	var before: int = joiner.next_side
	var data: Array = world.builds.to_array()
	var found:= { }
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_u_joiner":
			found = entry
	_check("the U joiner is written to the save as a U", not found.is_empty())
	_check("...with the arm it owes (%d)" % before, int(found.get("next_side", -1)) == before)
	world.builds.from_array(data)
	var back: ConveyorJoiner = world.builds.joiners [0] if world.builds.joiners.size() == 1 else null
	var restored:= back.next_side if back != null else -1
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("...and comes back as exactly one joiner, a U",
		world.builds.joiners.size() == 1 and back is ConveyorUJoiner)
	_check("...owing the same arm", restored == before)
	if back != null:
		var bent:= 0
		for side in ConveyorJoiner.SIDES:
			if back.arm(side) != null and back.arm(side)._line.size() == ConveyorUSplitter.BEND_PIECES + 3:
				bent += 1
		_check("...with both arms laid round their bends (%d)" % bent, bent == 2)
		_check("...on six legs (%d)" % _legs(back), _legs(back) == 6)
		_check("...and the runs relinked", back.out_path().downstream != null
			and back.arm(ConveyorJoiner.LEFT) != null)
		var old_save: Array = world.builds.to_array().duplicate(true)
		for entry in old_save:
			if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_u_joiner":
				(entry as Dictionary) ["type"] = "conveyor_joiner"
		world.builds.from_array(old_save)
		for i in 4:
			await get_tree().physics_frame
		var old_one: ConveyorJoiner = world.builds.joiners [0] if world.builds.joiners.size() == 1 else null
		_check("a conveyor_joiner entry still loads as a Y",
			old_one != null and not (old_one is ConveyorUJoiner))

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("U JOINER PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


func _record_deadlock(joiner: ConveyorJoiner, feed_belt: Dictionary, out_belt: Conveyor) -> void:
	var left:= joiner.arm(ConveyorJoiner.LEFT)
	var right:= joiner.arm(ConveyorJoiner.RIGHT)
	var got:= { }
	joiner.out_path().caught_record.connect(func(_seq: int, kind: int, _strands: int) -> void:
		got [kind] = int(got.get(kind, 0)) + 1)

	for i in 240:
		if left._riders.is_empty() and right._riders.is_empty():
			break
		await get_tree().physics_frame


	var ranked: int = int(Tech.ranks.get("belt_speed", 0))


	for row in [[0, false, false], [8, false, false], [0, true, false], [8, true, false],
			[0, true, true], [8, true, true]]:
		Tech.ranks ["belt_speed"] = row [0]
		var every: Array = []
		every.append_array(joiner.paths())
		every.append_array([feed_belt [0], feed_belt [1], out_belt])
		for p: BeltPath in every:
			p.set_drive_speed(Tech.belt_speed())
		await _stream(joiner, feed_belt, out_belt, got, row [1], row [2])

	print("\n=== a wad caught in the junction, a roll waiting ===")
	_check("the arms are empty before the jam is set up",
		left.run.count() == 0 and right.run.count() == 0)
	got.clear()

	var wad:= right.push_record(BeltRun.Kind.WAD, 197, -1, { "strands": 197 },
		right.run.pose_at(right.path_length() - 0.108, 0.0, 0.0).origin, 0.0)
	var roll:= left.push_record(BeltRun.Kind.ROLL, 1029, -1, { "strands": 1029 },
		left.run.pose_at(left.path_length() - 0.56, 0.0, 0.0).origin, 0.0)
	_check("a wad sits past its parking spot and a roll waits at its own (%d, %d)"
		% [wad, roll], wad >= 0 and roll >= 0)
	joiner.next_side = ConveyorJoiner.LEFT
	var ticks:= 0
	while ticks < 180 and (int(got.get(BeltRun.Kind.WAD, 0)) < 1
			or int(got.get(BeltRun.Kind.ROLL, 0)) < 1):
		await get_tree().physics_frame
		_sink_end(out_belt)
		ticks += 1
	_check("the wad finishes crossing (%d)" % int(got.get(BeltRun.Kind.WAD, 0)),
		int(got.get(BeltRun.Kind.WAD, 0)) >= 1)
	_check("...and the roll goes after it (%d, in %d steps)"
		% [int(got.get(BeltRun.Kind.ROLL, 0)), ticks], int(got.get(BeltRun.Kind.ROLL, 0)) >= 1)


	print("\n=== a wad past its spot on each arm ===")
	for i in 120:
		if left.run.count() == 0 and right.run.count() == 0:
			break
		await get_tree().physics_frame
		_sink_end(out_belt)
	got.clear()
	var deep:= right.push_record(BeltRun.Kind.WAD, 197, -1, { "strands": 197 },
		right.run.pose_at(right.path_length() - 0.108, 0.0, 0.0).origin, 0.0)
	var shallow:= left.push_record(BeltRun.Kind.WAD, 197, -1, { "strands": 197 },
		left.run.pose_at(left.path_length() - 0.25, 0.0, 0.0).origin, 0.0)
	var by_l:= left.run.front_past_park_by()
	var by_r:= right.run.front_past_park_by()
	_check("both wads past their spots, the right deeper (%d %d, %.3f %.3f)"
		% [deep, shallow, by_l, by_r], deep >= 0 and shallow >= 0 and by_l > 0.0 and by_r > by_l)
	joiner._serving = ConveyorJoiner.LEFT
	joiner.next_side = ConveyorJoiner.LEFT
	ticks = 0
	while ticks < 180 and int(got.get(BeltRun.Kind.WAD, 0)) < 2:
		await get_tree().physics_frame
		_sink_end(out_belt)
		ticks += 1
	_check("both wads cross (%d in %d steps, arms %d %d)"
		% [int(got.get(BeltRun.Kind.WAD, 0)), ticks, left.run.count(), right.run.count()],
		int(got.get(BeltRun.Kind.WAD, 0)) >= 2)
	Tech.ranks ["belt_speed"] = ranked


func _stream(joiner: ConveyorJoiner, feed_belt: Dictionary, out_belt: Conveyor,
		got: Dictionary, backed: bool, sparse: bool) -> void:
	var speed:= Tech.belt_speed()
	print("\n=== a wad line against a %sroll line at %.2f m/s%s ===" % [
		"sparse " if sparse else "", speed, ", backed up" if backed else ""])
	var next_roll:= 0.0
	var wad_belt: Conveyor = feed_belt [ConveyorJoiner.RIGHT]
	var roll_belt: Conveyor = feed_belt [ConveyorJoiner.LEFT]
	var left:= joiner.arm(ConveyorJoiner.LEFT)
	var right:= joiner.arm(ConveyorJoiner.RIGHT)
	got.clear()
	var step:= maxf(get_physics_process_delta_time(), 1e-06)

	var patience:= int(maxf(3.0, 4.0 * 0.56 / speed) / step)
	var stuck:= 0
	var stuck_longest:= 0
	var last_total:= 0
	var clock:= 0.0
	var shut:= false
	var flip:= 0.0
	while clock < 60.0:
		await get_tree().physics_frame
		clock += step
		if backed:
			flip -= step
			if flip <= 0.0:
				shut = not shut
				flip = _rng.randf_range(0.2, 1.5)
				out_belt.set_outlet_held(shut)
		wad_belt.push_record(BeltRun.Kind.WAD, 197, -1, { "strands": 197 },
			wad_belt.run.pose_at(0.3, 0.0, 0.0).origin)
		next_roll -= step
		if not sparse or next_roll <= 0.0:
			if roll_belt.push_record(BeltRun.Kind.ROLL, 1029, -1, { "strands": 1029 },
					roll_belt.run.pose_at(0.3, 0.0, 0.0).origin) >= 0 and sparse:
				next_roll = _rng.randf_range(0.5, 3.0)
		if not shut:
			_sink_end(out_belt)
		var total:= int(got.get(BeltRun.Kind.WAD, 0)) + int(got.get(BeltRun.Kind.ROLL, 0))


		if total != last_total or total == 0:
			stuck = 0
		elif not shut:
			stuck += 1
		if stuck == patience:
			print("  stalled at %.1f s, next_side %d serving %d"
				% [clock, joiner.next_side, joiner._serving])
			for pr in [["left", left], ["right", right], ["out", joiner.out_path()]]:
				_dump(pr [0], pr [1])
		stuck_longest = maxi(stuck_longest, stuck)
		last_total = total
	out_belt.set_outlet_held(false)
	var wads:= int(got.get(BeltRun.Kind.WAD, 0))
	var rolls:= int(got.get(BeltRun.Kind.ROLL, 0))
	print("  %d wads and %d rolls through in %.0f s, longest wait %d steps"
		% [wads, rolls, clock, stuck_longest])
	_check("the merge never stalled (longest %d steps, allowed %d)" % [stuck_longest, patience],
		stuck_longest < patience)
	_check("...and both lines were served (%d wads, %d rolls)" % [wads, rolls],
		wads > 10 and rolls > 10 and (sparse
			or mini(wads, rolls) >= int((wads + rolls) * 0.35)))
	var aboard:= func() -> int:
		return wad_belt.run.count() + roll_belt.run.count() + left.run.count() + right.run.count()
	var left_over: int = aboard.call()
	for i in 3600:
		if aboard.call() == 0:
			break
		await get_tree().physics_frame
		_sink_end(out_belt)
	_check("the lines drain once feeding stops (%d of %d left)" % [aboard.call(), left_over],
		aboard.call() == 0)
	for i in 120:
		await get_tree().physics_frame
		_sink_end(out_belt)
	while out_belt.run.count() > 0:
		out_belt.take_record_at(out_belt.run.first())


func _dump(label: String, p: BeltPath) -> void:
	var r:= p.run
	print("    %s len %.3f held %s past park %s" % [label, p.path_length(), r.outlet_held,
		r.front_past_park()])
	for i in range(r.first(), r.first() + r.count()):
		print("      %s s %.3f park %.3f speed %.2f" % [BeltRun.ITEM_IDS [r.kind_of(i)],
			r.s_of(i), r._park_s(r.reach_of(i)), r.speed_of(i)])


static func _sink_end(run: Conveyor) -> void:
	var br: BeltRun = run.run
	if br.count() > 0 and br.s_of(br.first()) >= run.path_length() - 0.4:
		run.take_record_at(br.first())


func _floor_owner(at: Vector3) -> String:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 0.3,
		Cfg.L_BUILD)
	var hit:= get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "nothing"
	var node:= hit.get("collider") as Node
	if world.builds.owner_of(node) is ConveyorJoiner:
		return "machine"
	return str(node.name) if node != null else "?"


static func _fallen_through(wye: ConveyorJoiner, loads: Array) -> int:
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
