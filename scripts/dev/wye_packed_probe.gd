class_name DevWyePackedProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30
const FEED_RUN:= 8.0
const OUT_RUN:= 4.0
const COUNT:= 40


const WARMUP:= 1.0

const OVERLAP_SLACK:= 0.03

var _pass:= 0
var _fail:= 0
var _x:= -20.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var args:= OS.get_cmdline_user_args()
	if "--no-share-feed" in args:
		ConveyorSplitter.share_feed_enabled = false
	if "--old-blade" in args:
		ConveyorSplitter.old_blade = true
	GameState.add_money(500000.0)
	player.global_position = Vector3(10.0, 0.4, 10.0)
	player.set_physics_process(false)
	world.props.clean_blocked = true


	Tech.grant("belt_speed", 8)
	var fast:= Tech.belt_speed()
	print("belt motor rank 8, %.2f m/s" % fast)

	await _case("Y, packed, both arms backed up", false, 0.29 / fast, 3.0, true)
	await _case("U, packed, both arms backed up", true, 0.29 / fast, 3.0, true)
	await _case("U, packed, flowing", true, 0.29 / fast, INF, true)
	await _case_feed_moves("Y", false)
	await _case_feed_moves("U", true)


	await _case_bundle()

	await _case_records("Y", false)
	await _case_records("U", true)

	await _case("Y, 2.4 m apart", false, 2.4 / fast, INF, false)


	Tech.reset()
	Tech.grant("belt_speed", 0)
	print("\nbelt motor rank 0, %.2f m/s" % Tech.belt_speed())
	await _case("Y, 1.5 m apart, rank 0", false, 1.5 / Tech.belt_speed(), INF, false)
	await _case("U, 1.5 m apart, rank 0", true, 1.5 / Tech.belt_speed(), INF, false)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _deck(at: Vector3) -> Vector3:
	return at + Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)


func _case(title: String, u: bool, gap: float, block_at: float, packed: bool) -> void:
	print("\n=== %s, a wad every %.3f s ===" % [title, gap])
	var centre:= _deck(Vector3(_x, 0.0, -14.0))
	_x += 8.0
	var s: ConveyorSplitter
	if u:
		s = world.builds.add_u_splitter(centre, 0.0)
	else:
		s = world.builds.add_splitter(centre, 0.0)
	var feed: Conveyor = world.builds.add_conveyor(
		s.port_in() - s.forward() * FEED_RUN, s.port_in())
	var outs: Array [Conveyor] = []
	for side: int in s.output_sides():
		var mouth:= s.port(side)
		outs.append(world.builds.add_conveyor(mouth, mouth + s.arm_travel(side) * OUT_RUN))
	for i in SETTLE:
		await get_tree().physics_frame

	var first_catch:= [-1.0]
	for route in s.routes():
		route.caught_record.connect(func(_q: int, _k: int, _n: int) -> void:
			if first_catch [0] < 0.0:
				first_catch [0] = ConveyorSplitter._physics_now())
		route.caught.connect(func(_b: RigidBody3D) -> void:
			if first_catch [0] < 0.0:
				first_catch [0] = ConveyorSplitter._physics_now())

	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var spawn_at:= feed.a + feed.forward * 0.6 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var fed:= 0
	var t:= 0.0
	var next_feed:= 0.0
	var total:= COUNT * gap + 8.0
	var overlap_ticks:= 0
	var worst:= INF
	var hits:= 0
	var resting_hits:= 0
	var early_hits:= 0
	var swing_ticks:= 0
	var batch_ticks:= 0
	var ticks:= 0
	var last_angle:= s._gate_angle
	var blocked:= false

	var ran:= [-1, -1]
	while t < total:
		if not blocked and t >= block_at:
			blocked = true
			ran = [s.route(ConveyorSplitter.LEFT).run.handed + _aboard(s.route(ConveyorSplitter.LEFT)),
				s.route(ConveyorSplitter.RIGHT).run.handed + _aboard(s.route(ConveyorSplitter.RIGHT))]
			for o in outs:
				o.set_blocked(true)
		if fed < COUNT and t >= next_feed:
			world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP, yaw), spawn_at))
			fed += 1
			next_feed += gap
		await get_tree().physics_frame
		t += step
		ticks += 1
		var loads:= _loads(s)
		var o:= _overlap(loads, s)
		if o < 0.0:
			overlap_ticks += 1
		worst = minf(worst, o)
		if s._batching:
			batch_ticks += 1
		var moved:= not is_equal_approx(s._gate_angle, last_angle)
		if moved:
			swing_ticks += 1
		last_angle = s._gate_angle
		if _under_blade(s, loads):
			var since:= ConveyorSplitter._physics_now() - float(first_catch [0])
			if first_catch [0] >= 0.0 and since >= WARMUP:
				hits += 1
				if not moved and _avoidable(s, loads):
					resting_hits += 1
			else:
				early_hits += 1
	for l in _loads(s):
		var lp: Vector3 = s.to_local(l [0])
	var left:= s.route(ConveyorSplitter.LEFT).run.handed + _aboard(s.route(ConveyorSplitter.LEFT))
	var right:= s.route(ConveyorSplitter.RIGHT).run.handed + _aboard(s.route(ConveyorSplitter.RIGHT))
	print("  fed %d: left %d, right %d; overlap ticks %d (deepest %.3f m); blade moved %d ticks, through a load %d (%d of them at rest, %d more in the first second); batching %d of %d ticks"
		% [fed, left, right, overlap_ticks, minf(worst, 0.0), swing_ticks, hits, resting_hits, early_hits, batch_ticks, ticks])
	_check("%s: no two loads drawn inside each other" % title, overlap_ticks == 0)
	if packed:
		_check("%s: took turns in batches" % title, batch_ticks > 0)


		_check("%s: the blade stood in a load it could have missed for %d ticks (limit %d)"
			% [title, resting_hits, _resting_limit()], resting_hits <= _resting_limit())
		var changes:= float(left + right) / float(ConveyorSplitter.BATCH)
		_check("%s: the blade swung through a load %d ticks, %.1f a batch" % [title,
			hits - resting_hits, (hits - resting_hits) / maxf(changes, 1.0)],
			hits - resting_hits <= (int(ceil(changes)) + 1) * 12)


		var l_ran:= left if int(ran [0]) < 0 else int(ran [0])
		var r_ran:= right if int(ran [1]) < 0 else int(ran [1])
		_check("%s: the division stayed within a batch while the arms ran (%d / %d, %d / %d in the end)"
			% [title, l_ran, r_ran, left, right], absi(l_ran - r_ran) <= ConveyorSplitter.BATCH)
	else:
		_check("%s: the blade never through a load" % title, hits == 0)
		_check("%s: one load each way (%d ticks moving, %d batching)"
			% [title, swing_ticks, batch_ticks], swing_ticks > 0 and batch_ticks == 0)
		_check("%s: the division stayed even (%d / %d)" % [title, left, right],
			absi(left - right) <= 1)
	for o in outs:
		o.set_blocked(false)


func _case_records(what: String, u: bool) -> void:
	var title:= "%s, both arms packed from the mouth" % what
	var fast:= Tech.belt_speed()
	var gap:= 0.3 / fast
	print("\r\n=== %s, a wad every %.3f s ===" % [title, gap])
	var centre:= _deck(Vector3(_x, 0.0, -14.0))
	_x += 8.0
	var s: ConveyorSplitter
	if u:
		s = world.builds.add_u_splitter(centre, 0.0)
	else:
		s = world.builds.add_splitter(centre, 0.0)
	var outs: Array [Conveyor] = []
	for out_side: int in s.output_sides():
		var mouth:= s.port(out_side)
		var o: Conveyor = world.builds.add_conveyor(mouth, mouth + s.arm_travel(out_side) * 1.0)
		o.set_blocked(true)
		outs.append(o)
	for i in SETTLE:
		await get_tree().physics_frame
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var t:= 0.0
	var next_feed:= 0.0
	var fed:= 0
	var side:= ConveyorSplitter.LEFT
	var overlap_ticks:= 0
	var worst:= INF
	var resting_hits:= 0
	while t < 26 * gap + 3.0:
		if fed < 26 and t >= next_feed:
			var run:= s.route(side).run
			var other:= s.route(ConveyorSplitter._other(side)).run
			var o_rear:= other.count() > 0 and other.s_of(other.first() + other.count() - 1) < 0.29
			if not o_rear:
				var was:= run.catching
				run.catching = true
				if run.board(BeltRun.Kind.WAD, 197, -1, 0.146, 0.0, 0.146, 0.0, fast):
					fed += 1
					side = ConveyorSplitter._other(side)
					s.route(ConveyorSplitter.LEFT).wake()
					s.route(ConveyorSplitter.RIGHT).wake()
				run.catching = was
			next_feed += gap
		await get_tree().physics_frame
		t += step
		var loads:= _loads(s)
		var o:= _overlap(loads, s)
		if o < 0.0:
			overlap_ticks += 1
		worst = minf(worst, o)
		var moved:= not is_equal_approx(s._gate_angle, s._gate_goal)


		var parked: bool = float(s._stall [0]) > 0.0 and float(s._stall [1]) > 0.0
		if parked and not moved and _under_blade(s, loads) and _avoidable(s, loads):
			resting_hits += 1
	for l in _loads(s):
		var lp: Vector3 = s.to_local(l [0])
	print("  boarded %d: left %d, right %d; overlap ticks %d (deepest %.3f m); parked, the blade stood in a load it could miss %d ticks"
		% [fed, _aboard(s.route(ConveyorSplitter.LEFT)), _aboard(s.route(ConveyorSplitter.RIGHT)),
		overlap_ticks, minf(worst, 0.0), resting_hits])
	_check("%s: no two loads drawn inside each other" % title, overlap_ticks == 0)
	_check("%s: the blade stood in a load it could have missed for %d ticks (limit %d)"
		% [title, resting_hits, _resting_limit()], resting_hits <= _resting_limit())
	for o in outs:
		o.set_blocked(false)


static func _resting_limit() -> int:
	return 6 * FactoryClock.stride


func _case_feed_moves(what: String, u: bool) -> void:
	var title:= "%s alternate, fed 0.45 m apart" % what
	var fast:= Tech.belt_speed()
	print("\r\n=== %s ===" % title)
	var centre:= _deck(Vector3(_x, 0.0, -14.0))
	_x += 8.0
	var s: ConveyorSplitter
	if u:
		s = world.builds.add_u_splitter(centre, 0.0)
	else:
		s = world.builds.add_splitter(centre, 0.0)
	var feed: Conveyor = world.builds.add_conveyor(s.port_in() - s.forward() * 10.0, s.port_in())
	for out_side: int in s.output_sides():
		var mouth:= s.port(out_side)
		world.builds.add_conveyor(mouth, mouth + s.arm_travel(out_side) * OUT_RUN)
	for i in SETTLE:
		await get_tree().physics_frame
	var gap:= 0.45 / fast
	var spawn_at:= feed.a + feed.forward * 0.6 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var t:= 0.0
	var next_feed:= 0.0
	var fed:= 0
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var end:= feed.path_length()
	var held:= 0
	var batching:= 0
	while t < 12.0:
		if fed < 40 and t >= next_feed:
			world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP, yaw), spawn_at))
			fed += 1
			next_feed += gap
		await get_tree().physics_frame
		t += step
		if s._batching:
			batching += 1
		var r:= feed.run
		if r.count() == 0:
			continue
		var h:= r.first()
		if r.s_of(h) > end - 0.6 and r.speed_of(h) < 0.2:
			held += 1
	var left:= s.route(ConveyorSplitter.LEFT).run.handed
	var right:= s.route(ConveyorSplitter.RIGHT).run.handed
	print("  fed %d: left %d, right %d; batching %d ticks; feed front held at the splitter %d ticks"
		% [fed, left, right, batching, held])
	_check("%s: took turns in batches" % title, batching > 0)
	_check("%s: the feed never stopped at the splitter" % title, held == 0)
	_check("%s: the division stayed within a batch (%d / %d)" % [title, left, right],
		absi(left - right) <= ConveyorSplitter.BATCH)


func _case_bundle() -> void:
	var title:= "U, the 23:08 bundle"
	print("\r\n=== %s ===" % title)
	var fast:= Tech.belt_speed()
	var centre:= _deck(Vector3(_x, 0.0, -14.0))
	_x += 8.0
	var s: ConveyorUSplitter = world.builds.add_u_splitter(centre, 0.0)
	var outs: Array [Conveyor] = []
	for out_side: int in s.output_sides():
		var mouth:= s.port(out_side)
		var o: Conveyor = world.builds.add_conveyor(mouth, mouth + s.arm_travel(out_side) * 1.0)
		o.set_blocked(true)
		outs.append(o)
	for i in SETTLE:
		await get_tree().physics_frame
	var at:= {
		ConveyorSplitter.LEFT: [3.129, 2.838, 2.546, 2.255, 1.963, 1.672],
		ConveyorSplitter.RIGHT: [3.228, 2.887, 2.596, 2.304, 2.013, 1.721, 1.43, 1.138],
	}
	for side in ConveyorSplitter.SIDES:
		var run:= s.route(side).run
		var was:= run.catching
		run.catching = true
		for x: float in at [side]:
			run.board(BeltRun.Kind.WAD, 197, -1, 0.146, 0.0, 0.146, x, 0.0, null, -1, false)
		run.catching = was
		s.route(side).wake()
	var under:= 0
	var avoidable:= 0
	for i in 180:
		await get_tree().physics_frame
		if i < 60:
			continue
		var loads:= _loads(s)
		if _under_blade(s, loads):
			under += 1
			if _avoidable(s, loads):
				avoidable += 1
	print("  blade %.3f (goal %.3f), stall %s, parked under %d, depth +%.3f -%.3f; under a wad %d of 120 ticks, %d of them avoidable"
		% [s._gate_angle, s._gate_goal, str(s._stall), s._parked_under.size() / 3,
			s._blade_depth(Cfg.SPLITTER_GATE_SWING), s._blade_depth(- Cfg.SPLITTER_GATE_SWING), under, avoidable])
	for l in _loads(s):
		var lp: Vector3 = s.to_local(l [0])
		print("    side %d local (%.2f, %.2f)" % [l [2], lp.x, lp.z])
	_check("%s: the blade clear of every wad it could miss" % title, avoidable == 0)
	for o in outs:
		o.set_blocked(false)


func _loads(s: ConveyorSplitter) -> Array:
	var out:= []
	for side in ConveyorSplitter.SIDES:
		var route:= s.route(side)
		if route == null:
			continue
		for rb in route.riders():
			if is_instance_valid(rb):
				out.append([rb.global_position, float(BeltPath.load_shape(rb) ["reach"]), side])
		var run:= route.run
		var f:= run.first()
		for i in range(f, f + run.count()):
			out.append([run.pose_of(i).origin, run.reach_of(i), side])
	return out


static func _overlap(loads: Array, s: ConveyorSplitter) -> float:
	var worst:= INF
	for i in loads.size():
		for j in range(i + 1, loads.size()):
			if int(loads [i] [2]) == int(loads [j] [2]):
				continue
			var a: Vector3 = loads [i] [0]
			var b: Vector3 = loads [j] [0]
			var d:= Vector2(a.x - b.x, a.z - b.z).length()
			var gap:= d - float(loads [i] [1]) - float(loads [j] [1]) + OVERLAP_SLACK
			worst = minf(worst, gap)
	return worst


static func _under_blade(s: ConveyorSplitter, loads: Array) -> bool:
	if s._gate == null or s._gate.mesh == null:
		return false
	var box:= s._gate.mesh.get_aabb()
	var a:= s._gate.to_global(Vector3(0.0, 0.0, box.position.z))
	var b:= s._gate.to_global(Vector3(0.0, 0.0, box.end.z))
	var a2:= Vector2(a.x, a.z)
	var b2:= Vector2(b.x, b.z)
	for l in loads:
		var p: Vector3 = l [0]
		var p2:= Vector2(p.x, p.z)
		var q:= Geometry2D.get_closest_point_to_segment(p2, a2, b2)
		if p2.distance_to(q) < float(l [1]):
			return true
	return false


static func _avoidable(s: ConveyorSplitter, loads: Array) -> bool:
	if s._gate == null:
		return false
	var was:= s._gate.rotation.y
	s._gate.rotation.y = - was
	var clear:= not _under_blade(s, loads)
	s._gate.rotation.y = was
	return clear


static func _aboard(path: BeltPath) -> int:
	return path.riders().size() + path.run.count() if path != null else 0


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
