class_name DevWyeFullProbe
extends Node


var world: Node3D
var player: Player

const FEED:= 24
const RUN:= 3.0
const SETTLE_FRAMES:= 30

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.0, 0.4, 10.0)
	GameState.add_money(50000.0)
	var rank:= 9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rank="):
			rank = int(a.substr(7))
	Tech.grant("belt_speed", rank)
	print("belt motor rank %d, %.2f m/s" % [rank, Tech.belt_speed()])
	var x:= -14.0
	for c in [["alternate, left arm full", -1, ConveyorSplitter.LEFT],
			["left first, left arm full", ConveyorSplitter.LEFT, ConveyorSplitter.LEFT],
			["right first, right arm full", ConveyorSplitter.RIGHT, ConveyorSplitter.RIGHT],
			["alternate, right arm full", -1, ConveyorSplitter.RIGHT],
			["pinned to a full left arm, then alternate", -1, ConveyorSplitter.LEFT, true],
			["pinned to a full right arm, then alternate", -1, ConveyorSplitter.RIGHT, true],
			["pinned to a full left arm, then right first", -1, ConveyorSplitter.LEFT, true,
				ConveyorSplitter.RIGHT],
			["pinned to a full right arm, then left first", -1, ConveyorSplitter.RIGHT, true,
				ConveyorSplitter.LEFT],
			["the F12 knot, right first", ConveyorSplitter.RIGHT, ConveyorSplitter.LEFT, false,
				-2, true],
			["the F12 knot mirrored, left first", ConveyorSplitter.LEFT, ConveyorSplitter.RIGHT,
				false, -2, true]]:
		await _case(c [0], c [1], c [2], Vector3(x, 0.0, -14.0), c.size() > 3 and c [3],
			c [4] if c.size() > 4 else -2, c.size() > 5 and c [5])
		x += 7.0
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _case(title: String, priority: int, full_side: int, origin: Vector3,
		pack:= false, then:= -2, knot:= false) -> void:
	print("\n=== %s ===" % title)
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var feed_from:= Vector3(origin.x, deck_y, origin.z)
	var heading:= Vector3(0.0, 0.0, 1.0)
	var centre:= feed_from + heading * (4.0 + Cfg.SPLITTER_PORT_R)
	var s: ConveyorSplitter = world.builds.add_splitter(centre, 0.0)
	var feed: Conveyor = world.builds.add_conveyor(feed_from, s.port_in())
	var arms:= { }
	for side in ConveyorSplitter.SIDES:
		var dir: Vector3 = s.port(side) - s.global_position
		dir.y = 0.0
		arms [side] = world.builds.add_conveyor(s.port(side),
			s.port(side) + dir.normalized() * RUN)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	s.set_priority_side(priority)
	if pack:
		s.set_forced_side(full_side)
	(arms [full_side] as Conveyor).set_blocked(true)
	var open_side:= ConveyorSplitter.RIGHT if full_side == ConveyorSplitter.LEFT else ConveyorSplitter.LEFT
	var laid:= 0
	if knot:
		for lay in [[s.route(full_side), [2.034, 1.53, 1.235, 0.94, 0.645, 0.073]],
				[s.route(open_side), [0.364, 0.0]]]:
			var path: BeltPath = lay [0]
			var r:= path.run
			var was:= r.catching
			r.catching = true
			for at in lay [1]:
				if r.board(BeltRun.Kind.WAD, Cfg.WAD_BASE_STRANDS, -1, 0.146, 0.0, 0.0,
						float(at), 0.0, null, -1, false):
					laid += 1
			r.catching = was
			path.wake()
		print("  laid the knot: %d loads" % laid)

	var took:= [0, 0]
	for side in ConveyorSplitter.SIDES:
		var route:= s.route(side)
		route.caught_record.connect(func(_seq: int, _kind: int, _n: int) -> void:
			took [side] += 1)
		route.caught.connect(func(_b: RigidBody3D) -> void:
			took [side] += 1)

	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var spawn_at:= feed.a + feed.forward * 0.6 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var gap:= maxf(0.15, 0.45 / Tech.belt_speed())
	var fed:= 0
	var t:= 0.0
	var next_feed:= 0.0
	var throat_ticks:= 0
	var last: Node3D = null
	var overlap_ticks:= 0
	var worst:= 0.0

	var measure:= DevWyePackedProbe.new()
	var total:= FEED * gap + 12.0
	var switch_at:= FEED * gap + 3.0 if pack else INF
	while t < total:
		if t >= switch_at:
			switch_at = INF
			var r:= s.route(full_side).run
			print("  switched to alternate: full route holds %d, rear at s %.3f, fork at s %.3f, feed holds %d"
				% [r.count(), r.s_of(r.first() + r.count() - 1), s._fork_s(full_side), _aboard(feed)])
			s.set_forced_side(-1)
			if then != -2:
				s.set_priority_side(then)


		var falling:= is_instance_valid(last) and last.is_inside_tree() and last.global_position.distance_to(spawn_at) < 0.6
		if fed < FEED and t >= next_feed and not falling and _clear_at(feed, 0.6):
			last = world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP, yaw), spawn_at)) as Node3D
			fed += 1
			next_feed = t + gap
		await get_tree().physics_frame
		t += step
		if s._queue_at_throat(full_side) and s.route(full_side).has_load_waiting():
			throat_ticks += 1
		var o:= DevWyePackedProbe._overlap(measure._loads(s), s)
		if o < 0.0:
			overlap_ticks += 1
		worst = minf(worst, o)
	for side in ConveyorSplitter.SIDES:
		var rr:= s.route(side).run
		var at:= PackedStringArray()
		for i in range(rr.first(), rr.first() + rr.count()):
			at.append("%.3f" % rr.s_of(i))
		print("  route %d holds s [%s]" % [side, ", ".join(at)])
	measure.free()
	var on_feed:= _aboard(feed)
	var in_full:= _aboard(s.route(full_side)) + _aboard(arms [full_side] as Conveyor)
	print("  fed %d, took %d left / %d right, full side holds %d, feed belt holds %d, full arm at the throat %d ticks"
		% [fed, took [0], took [1], in_full, on_feed, throat_ticks])
	_check("%s: the feed belt emptied (%d still on it)" % [title, on_feed], on_feed == 0)
	_check("%s: no two loads drawn inside each other (%d ticks, deepest %.3f m)"
		% [title, overlap_ticks, worst], overlap_ticks == 0)


	var out_open:= s.route(open_side).run.handed + _aboard(s.route(open_side))
	_check("%s: the open arm took every wad the full side could not hold (%d + %d of %d)"
		% [title, out_open, in_full, fed + laid], out_open + in_full >= fed + laid)
	(arms [full_side] as Conveyor).set_blocked(false)


static func _clear_at(feed: Conveyor, at: float) -> bool:
	for m in feed.load_marks(false):
		if absf(float(m ["s"]) - at) < 0.6:
			return false
	return true


static func _aboard(path: BeltPath) -> int:
	return path.riders().size() + path.run.count() if path != null else 0


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
