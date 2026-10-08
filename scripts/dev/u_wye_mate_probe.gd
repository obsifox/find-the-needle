class_name DevUWyeMateProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const FED:= 30
const FEED_RUN:= 3.0
const OUT_RUN:= 3.0
const CARRY_SECONDS:= 44.0 / Cfg.BELT_SPEED
const MOUTH_TOL:= 0.001

const MATES:= 4

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0
var _deck_y:= 0.0


func run() -> void:
	_rng.seed = 20260913
	for i in 40:
		await get_tree().process_frame
	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(-7.0, 0.4, -12.0)
	GameState.add_money(50000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	tool.set_active(true)
	await _settle()


	print("\n=== a U splitter's infeed on a Y joiner's spout ===")
	var j0: ConveyorJoiner = builds.add_joiner(Vector3(-12.0, _deck_y, -9.0), 0.0)
	await _settle()
	tool.set_mode(BuildTool.Mode.U_SPLITTER)
	tool._reach = 14.0
	await _drive(Vector3(-8.0, 0.4, -8.0), _floor(j0.port_out() + j0.forward() * 0.6))
	tool._update_u_splitter_ghost()
	var usg:= tool._u_splitter_ghost
	_check("buildable there (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))
	_check("...with its infeed on the spout (%.4f m)" % usg.port_in().distance_to(j0.port_out()),
		usg.port_in().distance_to(j0.port_out()) < MOUTH_TOL)
	_check("...and in line with it (%.4f)" % usg.forward().dot(j0.forward()),
		usg.forward().dot(j0.forward()) > 0.999)
	var placed: Node3D = await _place(tool, builds, BuildTool.Mode.U_SPLITTER)
	var us:= placed as ConveyorUSplitter
	if us == null:
		_finish()
		return


	print("\n=== a U joiner's two arms on the U splitter's two outfeeds ===")
	tool.set_mode(BuildTool.Mode.U_JOINER)
	tool._reach = 14.0
	var us_left:= us.port(ConveyorSplitter.LEFT)


	await _drive(Vector3(-8.0, 0.4, -4.0), _floor(us_left + Vector3(-0.6, 0.0, 0.4)))
	tool._update_u_joiner_ghost()
	var ujg:= tool._u_joiner_ghost
	_check("buildable there (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))
	for side in ConveyorSplitter.SIDES:
		var out:= us.port(side)
		var on:= -1
		for arm_side in ConveyorJoiner.SIDES:
			if ujg.port(arm_side).distance_to(out) < MOUTH_TOL:
				on = arm_side
		_check("...with an arm's mouth on outfeed %d (arm %d)" % [side, on], on == side)
	_check("...carrying on along the line (%.4f)" % ujg.forward().dot(us.forward()),
		ujg.forward().dot(us.forward()) > 0.999)
	placed = await _place(tool, builds, BuildTool.Mode.U_JOINER)
	var uj:= placed as ConveyorUJoiner
	if uj == null:
		_finish()
		return


	print("\n=== a Y splitter's infeed on the U joiner's spout ===")
	tool.set_mode(BuildTool.Mode.SPLITTER)
	tool._reach = 14.0
	await _drive(Vector3(-8.0, 0.4, 1.5), _floor(uj.port_out() + uj.forward() * 0.6))
	tool._update_splitter_ghost()
	var sg:= tool._splitter_ghost
	_check("buildable there (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))
	_check("...with its infeed on the spout (%.4f m)" % sg.port_in().distance_to(uj.port_out()),
		sg.port_in().distance_to(uj.port_out()) < MOUTH_TOL)
	placed = await _place(tool, builds, BuildTool.Mode.SPLITTER)
	var ys:= placed as ConveyorSplitter
	if ys == null:
		_finish()
		return


	print("\n=== a U splitter's arm on the head of a run ===")


	var head:= Vector3(-3.0, _deck_y, 10.0)
	var run_h: Conveyor = builds.add_conveyor(head, head + Vector3(0.0, 0.0, 3.0))
	await _settle()
	tool.set_mode(BuildTool.Mode.U_SPLITTER)
	tool._reach = 14.0
	await _drive(Vector3(-7.0, 0.4, 6.0), _floor(head + Vector3(-0.7, 0.0, -0.3)))
	tool._update_u_splitter_ghost()
	_check("buildable there (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))
	_check("...with its LEFT outfeed on the head of the run (%.4f m)"
		% usg.port(ConveyorSplitter.LEFT).distance_to(head),
		usg.port(ConveyorSplitter.LEFT).distance_to(head) < MOUTH_TOL)
	_check("...facing along it (%.4f)" % usg.forward().dot(run_h.forward),
		usg.forward().dot(run_h.forward) > 0.999)
	_check("...with its body on the side aimed at (%.2f)" % (usg.global_position.x - head.x),
		usg.global_position.x < head.x)
	placed = await _place(tool, builds, BuildTool.Mode.U_SPLITTER)
	var us_head:= placed as ConveyorUSplitter
	if us_head != null:
		_check("the placed U's left route hands into the run",
			us_head.route(ConveyorSplitter.LEFT).downstream == run_h)
		_check("...and the run stands no post at its head (%s)" % [run_h.support_stations()],
			not run_h.support_stations().has(0.0))


	print("\n=== the links ===")
	_check("the U splitter is fed by the Y joiner's spout", us.feeder() == j0.out_path())
	for side in ConveyorSplitter.SIDES:
		_check("U splitter route %d hands into U joiner arm %d" % [side, side],
			us.route(side).downstream == uj.arm(side))
	_check("the Y splitter is fed by the U joiner's spout", ys.feeder() == uj.out_path())
	var links:= _mated_links(builds)
	_check("every mated mouth is linked the way hay travels (%d of %d)" % [links.x, links.y],
		links.y == MATES and links.x == MATES)


	print("\n=== legs ===")
	for row in [["the Y joiner at the top", j0, 6],
			["the U splitter (infeed on a spout)", us, 4],
			["the U joiner (both arms on outfeeds)", uj, 2],
			["the Y splitter (infeed on the U's spout)", ys, 4]]:
		var wye: Node3D = row [1]
		_check("%s stands on %d legs (%d)" % [row [0], row [2], _legs(wye)], _legs(wye) == int(row [2]))


	print("\n=== a shared mouth is taken ===")
	var shared:= us.port(ConveyorSplitter.RIGHT)
	_check("a run may not leave it (%s)" % tool._joint_taken(shared, true),
		tool._joint_taken(shared, true) != "")
	_check("a run may not arrive at it (%s)" % tool._joint_taken(shared, false),
		tool._joint_taken(shared, false) != "")
	_check("the mated pair do not overlap each other by the test",
		not builds.wye_overlap(uj.footprint(), uj) and not builds.wye_overlap(us.footprint(), us))
	var nudged: Array [Vector4] = []
	for d: Vector4 in uj.footprint():
		nudged.append(d - Vector4(0.0, 0.0, 0.05, 0.0))
	_check("...and the U joiner 5 cm closer is refused", builds.wye_overlap(nudged, uj))


	print("\n=== hay through the chain ===")
	var feed_end:= j0.port(ConveyorJoiner.LEFT)
	var feed_along:= j0.arm_travel(ConveyorJoiner.LEFT)
	var feed: Conveyor = builds.add_conveyor(feed_end - feed_along * FEED_RUN, feed_end)
	var out_a: Conveyor = builds.add_conveyor(ys.port(ConveyorSplitter.LEFT),
		ys.port(ConveyorSplitter.LEFT) + ys.arm_travel(ConveyorSplitter.LEFT) * OUT_RUN)
	var out_b: Conveyor = builds.add_conveyor(ys.port(ConveyorSplitter.RIGHT),
		ys.port(ConveyorSplitter.RIGHT) + ys.arm_travel(ConveyorSplitter.RIGHT) * OUT_RUN)
	await _settle()
	var room:= Warehouse.INNER - 1.0
	for end: Vector3 in [feed.a, out_a.b, out_b.b]:
		_check("the rig stays inside the shed (%.2f, %.2f)" % [end.x, end.z],
			absf(end.x) < room and absf(end.z) < room)
	_check("the feed run hands into the Y joiner's arm", feed.downstream == j0.arm(ConveyorJoiner.LEFT))
	links = _mated_links(builds)
	_check("laying runs unmated nothing (%d of %d)" % [links.x, links.y],
		links.y == MATES and links.x == MATES)

	var on_feed:= { }
	var on_us:= { }
	var on_uj:= { }
	var on_ys:= { }
	var on_out:= { }
	_count(feed, on_feed)
	for side in ConveyorSplitter.SIDES:
		_count(us.route(side), on_us)
		_count(uj.arm(side), on_uj)
		_count(ys.route(side), on_ys)
	_count(out_a, on_out)
	_count(out_b, on_out)
	var across:= Vector3.UP.cross(feed_along).normalized()
	var fed:= 0
	for i in FED:
		var at: Vector3 = feed.a + feed_along * _rng.randf_range(0.0, 1.6) + across * _rng.randf_range(-0.2, 0.2) + Vector3.UP * 0.22
		if world.live.spawn(at, StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
				Cfg.COL_HAY_LIGHT) != null:
			fed += 1
	for i in int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	var us_split:= [0, 0]
	for side in ConveyorSplitter.SIDES:
		us_split [side] = us.route(side).riders().size() + us.route(side).run.count()
	print("  fed %d, boarded %d, U splitter %d, U joiner %d, Y splitter %d, out %d"
		% [fed, _hay(on_feed), _hay(on_us), _hay(on_uj), _hay(on_ys), _hay(on_out)])
	_check("the feed run took on most of it (%d of %d)" % [_hay(on_feed), fed],
		_hay(on_feed) >= int(fed * 0.8))
	_check("everything crossed into the U splitter (%d of %d)" % [_hay(on_us), _hay(on_feed)],
		_hay(on_us) >= _hay(on_feed) - 2)
	_check("everything crossed from its outfeeds into the U joiner (%d of %d)"
		% [_hay(on_uj), _hay(on_us)], _hay(on_uj) >= _hay(on_us) - 1)
	_check("everything crossed into the Y splitter (%d of %d)" % [_hay(on_ys), _hay(on_uj)],
		_hay(on_ys) >= _hay(on_uj) - 1)
	_check("nothing was lost between the feed and the two outlets (%d of %d)"
		% [_hay(on_out), _hay(on_feed)], _hay(on_out) >= _hay(on_feed) - 2)


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
	var u_count:= 0
	for splitter in builds.splitters:
		if splitter is ConveyorUSplitter:
			u_count += 1
	for joiner in builds.joiners:
		if joiner is ConveyorUJoiner:
			u_count += 1
	_check("...with its three Us still Us (%d)" % u_count, u_count == 3)


	print("\n=== taking the U joiner away ===")
	var mid: ConveyorUJoiner = null
	var top: ConveyorUSplitter = null
	var bottom: ConveyorSplitter = null
	for joiner in builds.joiners:
		if joiner is ConveyorUJoiner:
			mid = joiner
	for splitter in builds.splitters:
		if mid != null and splitter.port_in().is_equal_approx(mid.port_out()):
			bottom = splitter
		if splitter is ConveyorUSplitter and mid != null and splitter.port(ConveyorSplitter.LEFT).is_equal_approx(mid.port(ConveyorJoiner.LEFT)):
			top = splitter as ConveyorUSplitter
	_check("the U joiner and both its neighbours are found again",
		mid != null and top != null and bottom != null)
	if mid != null and top != null and bottom != null:
		builds.demolish(mid)
		await _settle()
		_check("the U splitter's routes hand into nothing",
			top.route(ConveyorSplitter.LEFT).downstream == null
				and top.route(ConveyorSplitter.RIGHT).downstream == null)
		_check("...and it still stands on four legs (%d)" % _legs(top), _legs(top) == 4)
		_check("the Y splitter has no feeder", bottom.feeder() == null)
		_check("...and stands its own legs under its infeed again (%d)" % _legs(bottom),
			_legs(bottom) == 6)
		_check("...and both outfeeds are open to runs again",
			tool._joint_taken(top.port(ConveyorSplitter.LEFT), true) == ""
				and tool._joint_taken(top.port(ConveyorSplitter.RIGHT), true) == "")

	_finish()


func _finish() -> void:
	player.build.set_active(false)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("U WYE MATE PROBE FAILED")
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


func _place(tool: BuildTool, builds: BuildManager, mode: BuildTool.Mode) -> Node3D:
	var joins:= mode == BuildTool.Mode.U_JOINER or mode == BuildTool.Mode.JOINER
	var list: Array = builds.joiners if joins else builds.splitters
	var before:= list.size()
	match mode:
		BuildTool.Mode.U_SPLITTER:
			tool._place_u_splitter()
		BuildTool.Mode.U_JOINER:
			tool._place_u_joiner()
		BuildTool.Mode.SPLITTER:
			tool._place_splitter()
	await _settle()
	_check("it was placed", list.size() == before + 1)
	if list.size() != before + 1:
		return null
	return list [list.size() - 1]


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
