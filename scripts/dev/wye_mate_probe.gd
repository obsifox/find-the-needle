class_name DevWyeMateProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const FED:= 30
const FEED_RUN:= 3.0
const OUT_RUN:= 3.0


const CARRY_SECONDS:= 40.0 / Cfg.BELT_SPEED

const MOUTH_TOL:= 0.001


const MATES:= 4

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0
var _deck_y:= 0.0


func run() -> void:
	_rng.seed = 20260910
	for i in 40:
		await get_tree().process_frame
	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(-10.5, 0.4, 0.0)
	GameState.add_money(50000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	tool._reach = 14.0
	await _settle()


	print("\n=== a splitter on the head of a run ===")

	var head_a:= Vector3(-13.0, _deck_y, 10.0)
	var run_a: Conveyor = builds.add_conveyor(head_a, head_a + Vector3(0.0, 0.0, 3.0))
	await _settle()
	tool._mode = BuildTool.Mode.SPLITTER
	await _drive(Vector3(-16.0, 0.4, 7.0), _floor(head_a - Vector3(0.0, 0.0, 0.6)))
	tool._update_splitter_ghost()
	var sg: ConveyorSplitter = tool._splitter_ghost
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	var head_side:= _splitter_arm_on(sg, head_a)
	_check("...with one arm's mouth on the head of the run", head_side >= 0)
	if head_side >= 0:
		var arm_dir:= (sg.port(head_side) - sg.global_position).normalized()
		_check("...laid along the run (%.4f)" % arm_dir.dot(run_a.forward),
			arm_dir.dot(run_a.forward) > 0.999)
	_check("...with the infeed facing the way the player looks (%.2f)"
		% sg.forward().dot(_flat_look()), sg.forward().dot(_flat_look()) > 0.5)
	var s_head: ConveyorSplitter = await _place_splitter(tool, builds)
	if s_head != null and head_side >= 0:
		_check("the placed splitter's arm hands into the run",
			s_head.route(head_side).downstream == run_a)


	print("\n=== a joiner on the head of a run ===")
	var head_b:= Vector3(-13.0, _deck_y, -10.0)
	var run_b: Conveyor = builds.add_conveyor(head_b, head_b + Vector3(0.0, 0.0, -3.0))
	await _settle()
	tool._mode = BuildTool.Mode.JOINER
	await _drive(Vector3(-13.0, 0.4, -5.5), _floor(head_b + Vector3(0.0, 0.0, 0.6)))
	tool._update_joiner_ghost()
	var jg: ConveyorJoiner = tool._joiner_ghost
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...with its spout on the head of the run (%.4f m)"
		% jg.port_out().distance_to(head_b), jg.port_out().distance_to(head_b) < MOUTH_TOL)
	_check("...facing the way the run leaves (%.4f)" % jg.forward().dot(run_b.forward),
		jg.forward().dot(run_b.forward) > 0.999)
	var j_head: ConveyorJoiner = await _place_joiner(tool, builds)
	if j_head != null:
		_check("the placed joiner's outfeed hands into the run",
			j_head.out_path().downstream == run_b)


	print("\n=== a splitter's infeed mated onto a joiner's spout ===")
	var j0: ConveyorJoiner = builds.add_joiner(Vector3(-13.0, _deck_y, -3.0), 0.0)
	await _settle()
	tool._mode = BuildTool.Mode.SPLITTER
	await _drive(Vector3(-13.0, 0.4, 3.0), _floor(j0.port_out() + j0.forward() * 0.6))
	tool._update_splitter_ghost()
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...with its infeed on the spout (%.4f m)" % sg.port_in().distance_to(j0.port_out()),
		sg.port_in().distance_to(j0.port_out()) < MOUTH_TOL)
	_check("...and in line with it (%.4f)" % sg.forward().dot(j0.forward()),
		sg.forward().dot(j0.forward()) > 0.999)
	var s1: ConveyorSplitter = await _place_splitter(tool, builds)
	if s1 == null:
		_finish()
		return


	print("\n=== a joiner's arm mated onto a splitter's arm ===")
	tool._mode = BuildTool.Mode.JOINER
	var s1_left:= s1.port(ConveyorSplitter.LEFT)
	var s1_left_dir:= (s1_left - s1.global_position).normalized()

	await _drive(s1_left + Vector3(1.0, 0.4 - _deck_y, -3.0), _floor(s1_left + s1_left_dir * 0.4))
	tool._update_joiner_ghost()
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	var j1_side:= _joiner_arm_on(jg, s1_left)
	_check("...with one arm's mouth on the splitter's arm", j1_side >= 0)
	if j1_side >= 0:
		_check("...laid along it (%.4f)" % jg.arm_travel(j1_side).dot(s1_left_dir),
			jg.arm_travel(j1_side).dot(s1_left_dir) > 0.999)
	var j1: ConveyorJoiner = await _place_joiner(tool, builds)
	if j1 == null or j1_side < 0:
		_finish()
		return


	print("\n=== a joiner's spout mated onto a joiner's arm ===")
	var free_arm:= ConveyorJoiner.RIGHT if j1_side == ConveyorJoiner.LEFT else ConveyorJoiner.LEFT
	var j1_free:= j1.port(free_arm)
	var j1_free_in:= j1.arm_travel(free_arm)
	await _drive(j1_free - j1_free_in * 3.0 + Vector3(0.0, 0.4 - _deck_y, 0.0),
		_floor(j1_free - j1_free_in * 0.4))
	tool._update_joiner_ghost()
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	_check("...with its spout on the free arm (%.4f m)" % jg.port_out().distance_to(j1_free),
		jg.port_out().distance_to(j1_free) < MOUTH_TOL)
	_check("...facing along it (%.4f)" % jg.forward().dot(j1_free_in),
		jg.forward().dot(j1_free_in) > 0.999)
	var j2: ConveyorJoiner = await _place_joiner(tool, builds)
	if j2 == null:
		_finish()
		return


	print("\n=== a splitter's arm mated onto a joiner's arm ===")
	tool._mode = BuildTool.Mode.SPLITTER
	var j0_right:= j0.port(ConveyorJoiner.RIGHT)
	var j0_right_in:= j0.arm_travel(ConveyorJoiner.RIGHT)
	var beside:= Vector3.UP.cross(j0_right_in).normalized()
	await _drive(j0_right - j0_right_in * 3.0 + beside + Vector3(0.0, 0.4 - _deck_y, 0.0),
		_floor(j0_right - j0_right_in * 0.4))
	tool._update_splitter_ghost()
	_check("buildable there (%s)" % tool._eval ["reason"], tool._eval ["ok"])
	var s3_side:= _splitter_arm_on(sg, j0_right)
	_check("...with one arm's mouth on the joiner's arm", s3_side >= 0)
	if s3_side >= 0:
		var s3_dir:= (sg.port(s3_side) - sg.global_position).normalized()
		_check("...laid along it (%.4f)" % s3_dir.dot(j0_right_in), s3_dir.dot(j0_right_in) > 0.999)
	_check("...with the infeed facing the way the player looks (%.2f)"
		% sg.forward().dot(_flat_look()), sg.forward().dot(_flat_look()) > 0.5)
	var s3: ConveyorSplitter = await _place_splitter(tool, builds)
	if s3 == null or s3_side < 0:
		_finish()
		return


	print("\n=== the links ===")
	_check("the splitter is fed by the joiner's outfeed", s1.feeder() == j0.out_path())
	_check("...and that outfeed hands into one of the splitter's routes",
		s1.routes().has(j0.out_path().downstream))
	_check("the splitter's left route hands into the joiner's arm",
		s1.route(ConveyorSplitter.LEFT).downstream == j1.arm(j1_side))
	_check("the second joiner's outfeed hands into the first one's free arm",
		j2.out_path().downstream == j1.arm(free_arm))
	_check("the second splitter's arm hands into the joiner's right arm",
		s3.route(s3_side).downstream == j0.arm(ConveyorJoiner.RIGHT))
	var links:= _mated_links(builds)
	_check("every mated mouth is linked the way hay travels (%d of %d)" % [links.x, links.y],
		links.y == MATES and links.x == MATES)


	print("\n=== legs ===")

	_check("a wye mated to nothing stands on six legs (%d)" % _legs(s_head), _legs(s_head) == 6)
	for row in [["the first joiner (right arm fed by a splitter)", j0, 4],
			["the splitter (infeed on a spout)", s1, 4],
			["the middle joiner (both arms fed by wyes)", j1, 2],
			["the second joiner (spout on an arm)", j2, 6],
			["the second splitter (arm on an arm)", s3, 6]]:
		var wye: Node3D = row [1]
		_check("%s stands on %d legs (%d)" % [row [0], row [2], _legs(wye)], _legs(wye) == int(row [2]))


	print("\n=== a shared mouth is taken ===")
	var shared:= s1.port_in()
	_check("a run may not leave it (%s)" % tool._joint_taken(shared, true),
		tool._joint_taken(shared, true) != "")
	_check("a run may not arrive at it (%s)" % tool._joint_taken(shared, false),
		tool._joint_taken(shared, false) != "")
	var offered:= builds.nearest_wye_joint(shared, Cfg.SPLITTER_SNAP_RADIUS)
	_check("no wye is offered it",
		offered.is_empty() or not (offered ["point"] as Vector3).is_equal_approx(shared))
	_check("a free mouth is still open to a run",
		tool._joint_taken(s1.port(ConveyorSplitter.RIGHT), true) == "")

	_check("a splitter 2.05 m off a splitter is still refused",
		builds.splitter_overlap(s1.global_position + Vector3(-2.05, 0.0, 0.0)))
	_check("a joiner 2.00 m off a joiner is still refused",
		builds.joiner_overlap(j0.global_position + Vector3(2.0, 0.0, 0.0)))


	print("\n=== hay through the chain ===")
	player.global_position = Vector3(-9.0, 0.4, 6.0)
	var feed_end:= j0.port(ConveyorJoiner.LEFT)
	var feed_along:= j0.arm_travel(ConveyorJoiner.LEFT)
	var feed: Conveyor = builds.add_conveyor(feed_end - feed_along * FEED_RUN, feed_end)
	var out_a: Conveyor = builds.add_conveyor(j1.port_out(), j1.port_out() + j1.forward() * OUT_RUN)
	var s1_right:= s1.port(ConveyorSplitter.RIGHT)
	var s1_right_dir:= (s1_right - s1.global_position).normalized()
	var out_b: Conveyor = builds.add_conveyor(s1_right, s1_right + s1_right_dir * OUT_RUN)
	await _settle()
	var room:= Warehouse.INNER - 1.0
	for end: Vector3 in [feed.a, out_a.b, out_b.b]:
		_check("the rig stays inside the shed (%.2f, %.2f)" % [end.x, end.z],
			absf(end.x) < room and absf(end.z) < room)
	_check("the feed run hands into the first joiner's arm",
		feed.downstream == j0.arm(ConveyorJoiner.LEFT))
	_check("the middle joiner hands into the run leaving it", j1.out_path().downstream == out_a)
	_check("the splitter's right route hands into the run leaving it",
		s1.route(ConveyorSplitter.RIGHT).downstream == out_b)
	links = _mated_links(builds)
	_check("laying runs unmated nothing (%d of %d)" % [links.x, links.y],
		links.y == MATES and links.x == MATES)

	var on_feed:= { }
	var on_left:= { }
	var on_right:= { }
	var on_arm:= { }
	var on_a:= { }
	var on_b:= { }
	_count(feed, on_feed)
	_count(s1.route(ConveyorSplitter.LEFT), on_left)
	_count(s1.route(ConveyorSplitter.RIGHT), on_right)
	_count(j1.arm(j1_side), on_arm)
	_count(out_a, on_a)
	_count(out_b, on_b)

	var across_feed:= Vector3.UP.cross(feed_along).normalized()
	var fed:= 0
	for i in FED:
		var at: Vector3 = feed.a + feed_along * _rng.randf_range(0.0, 1.6) + across_feed * _rng.randf_range(-0.2, 0.2) + Vector3.UP * 0.22
		var strand: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if strand != null:
			fed += 1
	var ticks:= int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame

	var through:= _hay(on_left) + _hay(on_right)
	print("  fed %d, boarded %d, into the splitter %d (left %d, right %d), into the joiner's arm %d, out %d + %d"
		% [fed, _hay(on_feed), through, _hay(on_left), _hay(on_right), _hay(on_arm),
			_hay(on_a), _hay(on_b)])
	_check("the feed run took on most of it (%d of %d)" % [_hay(on_feed), fed],
		_hay(on_feed) >= int(fed * 0.8))
	_check("everything crossed the spout into the splitter (%d of %d)"
		% [through, _hay(on_feed)], through >= _hay(on_feed) - 2)
	_check("the splitter sent hay down both arms (%d / %d)" % [_hay(on_left), _hay(on_right)],
		_hay(on_left) > 0 and _hay(on_right) > 0)
	_check("everything down the left arm crossed into the joiner (%d of %d)"
		% [_hay(on_arm), _hay(on_left)], _hay(on_arm) >= _hay(on_left) - 1)
	_check("...and left it on the run (%d of %d)" % [_hay(on_a), _hay(on_arm)],
		_hay(on_a) >= _hay(on_arm) - 1)
	_check("nothing was lost between the feed and the two outlets (%d of %d)"
		% [_hay(on_a) + _hay(on_b), _hay(on_feed)],
		_hay(on_a) + _hay(on_b) >= _hay(on_feed) - 2)


	print("\n=== save ===")
	var legs_before:= _total_legs(builds)
	var data: Array = builds.to_array()
	builds.from_array(data)
	await _settle()
	var relinked:= _mated_links(builds)
	_check("the chain comes back mated and linked (%d of %d)" % [relinked.x, relinked.y],
		relinked.y == MATES and relinked.x == MATES)
	_check("...on the same legs (%d, was %d)" % [_total_legs(builds), legs_before],
		_total_legs(builds) == legs_before)


	print("\n=== taking one away ===")
	var fed_splitter: ConveyorSplitter = null
	var spout: ConveyorJoiner = null
	for splitter in builds.splitters:
		for joiner in builds.joiners:
			if joiner.port_out().is_equal_approx(splitter.port_in()):
				fed_splitter = splitter
				spout = joiner
	_check("the splitter on the spout is found again", fed_splitter != null)
	if fed_splitter != null:
		builds.demolish(spout)
		await _settle()
		_check("the splitter has no feeder once the joiner is gone",
			fed_splitter.feeder() == null)
		_check("...and stands its own legs under its infeed again (%d)" % _legs(fed_splitter),
			_legs(fed_splitter) == 6)
		_check("...and the mouth is open to a run again (%s)"
			% tool._joint_taken(fed_splitter.port_in(), false),
			tool._joint_taken(fed_splitter.port_in(), false) == "")

	_finish()


func _finish() -> void:
	player.build.set_active(false)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("WYE MATE PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


func _mated_links(builds: BuildManager) -> Vector2i:
	var linked:= 0
	var mated:= 0
	var outlets: Array = []
	for splitter in builds.splitters:
		for side: int in ConveyorSplitter.SIDES:
			outlets.append([splitter.port(side), splitter.route(side)])
	for joiner in builds.joiners:
		outlets.append([joiner.port_out(), joiner.out_path()])
	for pair in outlets:
		var at: Vector3 = pair [0]
		var path: BeltPath = pair [1]
		for fed in builds.splitters:
			if fed.port_in().is_equal_approx(at):
				mated += 1
				if fed.feeder() == path and fed.routes().has(path.downstream):
					linked += 1
		for merge in builds.joiners:
			for arm_side: int in ConveyorJoiner.SIDES:
				if merge.port(arm_side).is_equal_approx(at):
					mated += 1
					if path.downstream == merge.arm(arm_side):
						linked += 1
	return Vector2i(linked, mated)


func _legs(wye: Node3D) -> int:
	if wye == null or not is_instance_valid(wye):
		return -1
	var mmi:= wye.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		return -1
	return mmi.multimesh.instance_count


func _total_legs(builds: BuildManager) -> int:
	var n:= 0
	for splitter in builds.splitters:
		n += _legs(splitter)
	for joiner in builds.joiners:
		n += _legs(joiner)
	return n


func _splitter_arm_on(wye: ConveyorSplitter, point: Vector3) -> int:
	for side: int in ConveyorSplitter.SIDES:
		if wye.port(side).distance_to(point) < MOUTH_TOL:
			return side
	return -1


func _joiner_arm_on(wye: ConveyorJoiner, point: Vector3) -> int:
	for side: int in ConveyorJoiner.SIDES:
		if wye.port(side).distance_to(point) < MOUTH_TOL:
			return side
	return -1


func _place_splitter(tool: BuildTool, builds: BuildManager) -> ConveyorSplitter:
	var before:= builds.splitters.size()
	tool._place_splitter()
	await _settle()
	_check("the splitter was placed", builds.splitters.size() == before + 1)
	if builds.splitters.size() != before + 1:
		return null
	return builds.splitters [builds.splitters.size() - 1]


func _place_joiner(tool: BuildTool, builds: BuildManager) -> ConveyorJoiner:
	var before:= builds.joiners.size()
	tool._place_joiner()
	await _settle()
	_check("the joiner was placed", builds.joiners.size() == before + 1)
	if builds.joiners.size() != before + 1:
		return null
	return builds.joiners [builds.joiners.size() - 1]


func _count(path: BeltPath, into: Dictionary) -> void:
	if path != null:
		path.caught.connect(func(b: RigidBody3D) -> void:
			into [b.get_instance_id()] = (b as HayWad).strands if b is HayWad else 1)


func _hay(counted: Dictionary) -> int:
	var n:= 0
	for v: int in counted.values():
		n += v
	return n


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


func _flat_look() -> Vector3:
	var look:= player.look_direction()
	look.y = 0.0
	return look.normalized()


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
