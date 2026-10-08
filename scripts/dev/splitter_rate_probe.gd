class_name DevSplitterRateProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30

const TOP_RANK:= 8
const FEED_RUN:= 10.0


var OUT_RUN:= 8.0


const SPACINGS:= [1.8, 0.9, 0.45]


var _rank:= TOP_RANK
var _spacings: Array = SPACINGS
var _strands:= 0


var _kind:= BeltRun.Kind.WAD
var _reach:= 0.146
var _lift:= 0.146
var _packed:= false
var COUNT:= 14

const WAD_REACH:= 0.146


const PINNED:= ["Y, pinned left", "T, pinned left"]
const KIND:= "hay_wad"
const CENTRE:= Vector3(-11.0, 0.0, 1.0)


var _out_at: Array [int] = []


var _in_at: Array [int] = []
var _every_prop: Array [RigidBody3D] = []


var _stalled:= 0
var _watched:= 0

var _front_was:= - INF


var _feed_v:= 0.0
var _feed_n:= 0
var _route_v:= 0.0
var _route_n:= 0
var _route_min:= INF


var _on_route:= { }
var _cross: Array [float] = []
var _routes: Array [BeltPath] = []
var _rows: Array [Dictionary] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	GameState.add_money(500000.0)
	player.global_position = CENTRE + Vector3(6.0, 0.4, 6.0)
	player.set_physics_process(false)


	world.props.clean_blocked = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rank="):
			_rank = int(a.trim_prefix("rank="))
		elif a == "gap=packed":
			_packed = true
		elif a.begins_with("gap="):
			_spacings = [float(a.trim_prefix("gap="))]
		elif a.begins_with("kind="):
			_kind = int(a.trim_prefix("kind=")) as BeltRun.Kind
		elif a.begins_with("strands="):
			_strands = int(a.trim_prefix("strands="))
		elif a.begins_with("count="):
			COUNT = int(a.trim_prefix("count="))
		elif a.begins_with("out="):
			OUT_RUN = float(a.trim_prefix("out="))
		elif a.begins_with("boost="):
			ConveyorSplitter.route_boost = float(a.trim_prefix("boost="))
		elif a == "oldgate=1":
			BeltRun.gate_follows = false
		elif a == "old=1":

			ConveyorSplitter.route_boost = 1.0
			ConveyorSplitter.old_throat = true
			BeltRun.gate_follows = false
		elif a == "nobatch=1":
			ConveyorSplitter.old_blade = true
		elif a == "share=0":
			ConveyorSplitter.share_feed_enabled = false
	Tech.grant("belt_speed", _rank)
	var speed:= Tech.belt_speed()
	if _kind != BeltRun.Kind.WAD:
		var body:= world.props.spawn(BeltRun.ITEM_IDS [_kind],
			Transform3D(Basis(), CENTRE + Vector3(0.0, 3.0, -30.0))) as RigidBody3D
		if body != null:
			var shape:= BeltPath.load_shape(body)
			_reach = float(shape ["reach"])
			_lift = float(shape.get("lift", _reach))
			if body is Carryable:
				world.props.remove(body as Carryable)
	if _packed:
		_spacings = [2.0 * _reach]
	print("belt %.2f m/s (rank %d), %d %s a case (reach %.3f) of %s strands, feed %.0f m, out %.0f m"
		% [speed, _rank, COUNT, BeltRun.ITEM_IDS [_kind], _reach,
			(str(_strands) if _strands > 0 else "default"), FEED_RUN, OUT_RUN])
	for i in SETTLE:
		await get_tree().physics_frame

	for pack: float in _spacings:
		var gap:= pack / speed
		print("\n=== %.2f m apart, a wad every %.3f s (%.1f a second offered) ==="
			% [pack, gap, 1.0 / gap])
		await _plain(gap)
		await _case("Y, taking turns", gap, _make_y.bind(-1))
		await _case("Y, pinned left", gap, _make_y.bind(ConveyorSplitter.LEFT))
		await _case("U, taking turns", gap, _make_u)
		await _case("T, taking turns", gap, _make_t.bind(-1))
		await _case("T, pinned left", gap, _make_t.bind(ConveyorSplitter.LEFT))
		await _case("compact, three doors", gap, _make_compact.bind(false))
		await _case("smart, three doors", gap, _make_compact.bind(true))

	_report()
	get_tree().quit(0)


func _deck(at: Vector3) -> Vector3:
	return at + Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)


func _wire(m: ConveyorSplitter) -> Dictionary:
	var feed: Conveyor = world.builds.add_conveyor(
		m.port_in() - m.forward() * FEED_RUN, m.port_in())
	var outs: Array [Conveyor] = []
	for side: int in m.output_sides():
		var mouth:= m.port(side)
		outs.append(world.builds.add_conveyor(mouth, mouth + m.arm_travel(side) * OUT_RUN))
	for out in outs:
		out.caught.connect(_on_out)
		out.caught_record.connect(_on_out_record)
	_routes = m.routes()
	for k in _routes.size():
		_routes [k].caught.connect(_on_in)
		_routes [k].caught_record.connect(_on_in_record)
		_routes [k].caught_record.connect(_on_in_side.bind(k))
	for i in SETTLE:
		await get_tree().physics_frame
	return { "feed": feed, "outs": outs, "machine": m }


func _make_y(pin: int) -> Dictionary:
	var y: ConveyorSplitter = world.builds.add_splitter(_deck(CENTRE), 0.0)
	if pin >= 0:
		y.set_forced_side(pin)
	return await _wire(y)


func _make_u() -> Dictionary:
	var u: ConveyorUSplitter = world.builds.add_u_splitter(_deck(CENTRE), 0.0)
	return await _wire(u)


func _make_t(pin: int) -> Dictionary:
	var t: ConveyorTSplitter = world.builds.add_t_splitter(_deck(CENTRE), 0.0, ConveyorTSplitter.STEM)
	if pin >= 0:
		t.set_forced_side(pin)
	return await _wire(t)


func _make_compact(smart: bool) -> Dictionary:
	var c: ConveyorCompactSplitter = world.builds.add_compact_splitter(
		_deck(CENTRE), 0.0, smart)
	return await _wire(c)


func _plain(gap: float) -> void:
	var a:= _deck(CENTRE) - Vector3(0.0, 0.0, FEED_RUN)


	var feed: Conveyor = world.builds.add_conveyor(a, a + Vector3(0.0, 0.0, FEED_RUN))
	var out: Conveyor = world.builds.add_conveyor(a + Vector3(0.0, 0.0, FEED_RUN),
		a + Vector3(0.0, 0.0, FEED_RUN + OUT_RUN))
	out.caught.connect(_on_out)
	out.caught_record.connect(_on_out_record)
	_routes.clear()
	for i in SETTLE:
		await get_tree().physics_frame
	await _feed({ "feed": feed, "outs": [out] as Array [Conveyor], "machine": null },
		gap, "plain belt")


func _case(label: String, gap: float, make: Callable) -> void:
	var rig: Dictionary = await make.call()
	await _feed(rig, gap, label)


func _feed(rig: Dictionary, gap: float, label: String) -> void:
	var feed:= rig ["feed"] as Conveyor
	_machine = rig ["machine"]
	_out_runs = rig ["outs"]
	_overlap_ticks = 0
	_overlap_worst = 0.0
	_overlap_pair = ""
	_overlap_kinds.clear()
	_bend_ticks = 0
	_out_at.clear()
	_in_at.clear()
	_feed_v = 0.0
	_feed_n = 0
	_route_v = 0.0
	_route_n = 0
	_route_min = INF
	_on_route.clear()
	_cross.clear()
	_stalled = 0
	_watched = 0
	_why.clear()
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var at:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var fed:= 0
	if _strands > 0:


		var t:= 0.0
		var next_at:= 0.0
		while fed < COUNT:
			if t >= next_at and feed.run.board(_kind, _strands, -1,
					_reach, 0.0, _lift, 0.0, Tech.belt_speed()):
				fed += 1
				feed.wake()
				next_at += gap
			await _watch(feed)
			t += step
	for i in (0 if _strands > 0 else COUNT):
		var body:= world.props.spawn(KIND, Transform3D(Basis(Vector3.UP, yaw), at)) as RigidBody3D
		if body != null:
			if _strands > 0 and body is HayWad:
				(body as HayWad).set_strands(_strands)
			fed += 1
			_every_prop.append(body)
		for k in int(gap / step):
			await _watch(feed)

	var limit:= int((FEED_RUN + OUT_RUN) / maxf(Tech.belt_speed(), 0.01) / step) + 60
	for k in limit:
		await _watch(feed)
		if _out_at.size() >= fed:
			break
	var mean:= _mean_gap(_out_at)
	var into:= _mean_gap(_in_at)
	var feed_v:= _feed_v / maxf(float(_feed_n), 1.0)
	var route_v:= _route_v / maxf(float(_route_n), 1.0)
	var cross:= 0.0
	for c in _cross:
		cross += c
	cross /= maxf(float(_cross.size()), 1.0)
	print("  %-22s out %2d / %2d, %.3f s a wad (%.1f a second), into the machine %.3f s, feed stalled %d%% of %d ticks"
		% [label, _out_at.size(), fed, mean, (1.0 / mean if mean > 0.0 else 0.0), into,
			int(100.0 * float(_stalled) / maxf(float(_watched), 1.0)), _watched])
	var route_len:= _routes [0].path_length() if not _routes.is_empty() else 0.0
	print("      on the belt %.2f m/s, in the machine %.2f m/s (slowest %.2f), across %.2f m in %.3f s (%d crossings, %.3f s at belt speed), routes drive %.2f"
		% [feed_v, route_v, (0.0 if is_inf(_route_min) else _route_min), route_len,
			cross, _cross.size(), route_len / maxf(Tech.belt_speed(), 0.01),
			(_routes [0].drive_speed if not _routes.is_empty() else 0.0)])
	print("      OVERLAP %-21s %d ticks, deepest %.3f m  %s" % [label, _overlap_ticks, _overlap_worst, _overlap_pair])
	print("        packed round a bend on one run: %d ticks" % _bend_ticks)
	for k in _overlap_kinds:
		print("        overlap %s: %d ticks" % [k, int(_overlap_kinds [k])])
	var steady_in:= _steady(_in_at)
	var steady_out:= _steady(_out_at)
	print("      STEADY %-22s in %.1f a second, out %.1f a second" % [label,
		(60.0 / steady_in if steady_in > 0.0 else 0.0) * float(Engine.physics_ticks_per_second) / 60.0,
		(60.0 / steady_out if steady_out > 0.0 else 0.0) * float(Engine.physics_ticks_per_second) / 60.0])
	print("      ticks between loads in:  %s" % _gaps_of(_in_at))
	print("      ticks between loads out: %s" % _gaps_of(_out_at))
	print("      routes in order: %s" % " ".join(_sides))
	_sides.clear()
	var whys:= _why.keys()
	whys.sort_custom(func(a, b): return int(_why [a]) > int(_why [b]))
	for w in whys:
		print("      stalled: %-40s %d" % [w, int(_why [w])])
	_rows.append({ "label": label, "gap": gap, "mean": mean, "in": into,
		"out": _out_at.size(), "fed": fed,
		"stall": float(_stalled) / maxf(float(_watched), 1.0) })
	await _clear()


func _watch(feed: Conveyor) -> void:
	await get_tree().physics_frame
	if feed == null or not is_instance_valid(feed):
		return
	_check_overlap(feed)
	var marks:= feed.load_marks()
	if marks.is_empty():
		return


	if feed.run.stepped_tick == _stepped_was:
		_sample(feed)
		return
	_stepped_was = feed.run.stepped_tick
	var front:= - INF
	for m in marks:
		front = maxf(front, float(m ["s"]))
	_watched += 1
	if absf(front - _front_was) < 0.0001:
		_stalled += 1
		_why_stalled(feed)
	_front_was = front
	_sample(feed)


const OVERLAP_SLACK:= 0.01
var _overlap_ticks:= 0
var _overlap_worst:= 0.0
var _overlap_pair:= ""
var _overlap_kinds:= { }
var _bend_ticks:= 0
var _bend_ticks_now:= false
var _out_runs: Array [Conveyor] = []


func _check_overlap(feed: Conveyor) -> void:
	var runs: Array [BeltRun] = [feed.run]
	var names: Array [String] = ["feed"]
	for k in _routes.size():
		if is_instance_valid(_routes [k]):
			runs.append(_routes [k].run)
			names.append("route%d" % k)
	for k in _out_runs.size():
		if is_instance_valid(_out_runs [k]):
			runs.append(_out_runs [k].run)
			names.append("out%d" % k)
	var at: Array [Vector3] = []
	var reach: Array [float] = []
	var run_of: Array [int] = []
	var who: Array [String] = []
	var where: Array [String] = []
	for n in runs.size():
		var r:= runs [n]
		for i in range(r.first(), r.first() + r.count()):
			at.append(r.pose_of(i).origin)
			reach.append(r.reach_of(i))
			run_of.append(n if r.s_of(i) <= r.length() + 0.001 else -1 - n)
			who.append("%s s=%.2f v=%.1f" % [names [n], r.s_of(i), r.speed_of(i)])
			where.append(names [n] + (" PAST END" if r.s_of(i) > r.length() + 0.001 else ""))
	var worst:= INF
	var pair:= ""
	var kinds:= ""
	for i in at.size():
		for j in range(i + 1, at.size()):
			var d:= Vector2(at [i].x - at [j].x, at [i].z - at [j].z).length()
			var o:= d - reach [i] - reach [j] + OVERLAP_SLACK


			if run_of [i] == run_of [j] and run_of [i] >= 0:
				if o < 0.0:
					_bend_ticks_now = true
				continue
			if o < worst:
				worst = o
				pair = "%s | %s" % [who [i], who [j]]
				kinds = "%s + %s" % [where [i], where [j]]
	if _bend_ticks_now:
		_bend_ticks += 1
		_bend_ticks_now = false
	if worst < 0.0:
		_overlap_ticks += 1
		var key:= "%s, %s" % [kinds, "under 1 cm" if worst > -0.01 else "1 to 5 cm" if worst > -0.05 else "over 5 cm"]
		_overlap_kinds [key] = int(_overlap_kinds.get(key, 0)) + 1
		if worst < _overlap_worst:
			_overlap_worst = worst
			_overlap_pair = pair


var _why:= { }
var _stepped_was:= -1
var _machine: Node = null


func _why_stalled(feed: Conveyor) -> void:
	var r:= feed.run
	var reason:= "front short of the end"
	if r.count() > 0 and r.s_of(r.first()) >= r.length() - 2.0 * r.reach_of(r.first()) - 0.01:
		var d:= r.downstream
		var reach:= r.reach_of(r.first())
		if r.end_held or r.outlet_held:
			reason = "feed held at its own end"
		elif d == null:
			reason = "no run in front"
		elif not d.catching:
			reason = "route not catching"
		elif d.blocked:
			reason = "route blocked"
		elif d.mouth_gate.is_valid() and float(d.mouth_gate.call(reach, r)) < 0.0:
			reason = "sibling on the mouth (gate)"
		else:
			var m:= d.mouth_limit(reach, r.gap_of(r.first()), r.kind_of(r.first()), r)
			var rear:= d.first() + d.count() - 1
			reason = "route rear too close (rear at %.2f doing %.1f m/s, %d aboard)" % [
				snappedf(d.s_of(rear), 0.05) if d.count() > 0 else -1.0,
				d.speed_of(rear) if d.count() > 0 else -1.0, d.count()]
	_why [reason] = int(_why.get(reason, 0)) + 1


func _sample(feed: Conveyor) -> void:
	var hz:= float(Engine.physics_ticks_per_second)
	var now:= Engine.get_physics_frames()
	var r:= feed.run
	for i in range(r.first(), r.first() + r.count()):
		_feed_v += r.speed_of(i)
		_feed_n += 1
	for route in _routes:
		if route == null or not is_instance_valid(route):
			continue
		var rr:= route.run
		for i in range(rr.first(), rr.first() + rr.count()):
			var v:= rr.speed_of(i)
			_route_v += v
			_route_n += 1
			_route_min = minf(_route_min, v)
			var seq:= rr.seq_of(i)
			if not _on_route.has(seq):
				_on_route [seq] = [now, now]
			else:
				(_on_route [seq] as Array) [1] = now

	var live:= { }
	for route in _routes:
		if route == null or not is_instance_valid(route):
			continue
		var rr:= route.run
		for i in range(rr.first(), rr.first() + rr.count()):
			live [rr.seq_of(i)] = true
	for seq in _on_route.keys():
		if live.has(seq):
			continue
		var span: Array = _on_route [seq]
		_cross.append(float(int(span [1]) - int(span [0])) / hz)
		_on_route.erase(seq)


func _mean_gap(at: Array [int]) -> float:
	var last:= mini(at.size(), COUNT - 3)
	if last - 3 < 1:
		return 0.0
	var total:= 0.0
	for i in range(4, last):
		total += float(at [i] - at [i - 1])
	return total / float(last - 4) / float(Engine.physics_ticks_per_second)


var _sides:= PackedStringArray()


func _on_in_side(_seq: int, _kind: int, _strands: int, k: int) -> void:
	var b: bool = is_instance_valid(_machine) and "_batching" in _machine and bool(_machine.get("_batching"))
	_sides.append(("B" if b else "") + str(k))


func _steady(at: Array [int]) -> float:
	var n:= at.size()
	var from:= n / 2
	var to:= n - 2
	if to - from < 4:
		return 0.0
	return float(at [to] - at [from]) / float(to - from)


func _gaps_of(at: Array [int]) -> String:
	var out:= PackedStringArray()
	for i in range(1, at.size()):
		out.append(str(at [i] - at [i - 1]))
	return " ".join(out)


func _on_out(body: RigidBody3D) -> void:
	if body.collision_layer & Cfg.L_PROP:
		_out_at.append(Engine.get_physics_frames())


func _on_out_record(_seq: int, _kind: int, _strands: int) -> void:
	_out_at.append(Engine.get_physics_frames())


func _on_in(body: RigidBody3D) -> void:
	if body.collision_layer & Cfg.L_PROP:
		_in_at.append(Engine.get_physics_frames())


func _on_in_record(_seq: int, _kind: int, _strands: int) -> void:
	_in_at.append(Engine.get_physics_frames())


func _clear() -> void:
	world.builds.from_array([])
	for body in _every_prop:
		if is_instance_valid(body) and body.is_inside_tree() and body is Carryable:
			world.props.remove(body as Carryable)
	_every_prop.clear()


	for item in world.props.items.duplicate():
		if is_instance_valid(item) and item.is_inside_tree() and Vector2(item.global_position.x - CENTRE.x,
					item.global_position.z - CENTRE.z).length() < FEED_RUN + OUT_RUN + 5.0:
			world.props.remove(item)
	_routes.clear()
	_front_was = - INF
	for i in 10:
		await get_tree().physics_frame


func _report() -> void:
	print("\n=== seconds a wad, by offered spacing ===")
	var packs: Array = []
	for row in _rows:
		if not packs.has(row ["gap"]):
			packs.append(row ["gap"])
	var labels: Array = []
	for row in _rows:
		if not labels.has(row ["label"]) and not PINNED.has(row ["label"]):
			labels.append(row ["label"])
	var head:= "  %-22s" % "offered every"
	for g: float in packs:
		head += "%9.3f s" % g
	print(head)
	for label: String in labels:
		var line:= "  %-22s" % label
		for g: float in packs:
			var got:= 0.0
			for row in _rows:
				if row ["label"] == label and is_equal_approx(float(row ["gap"]), g):
					got = float(row ["mean"])
			line += "%9.3f s" % got
		print(line)
	print("\n  A machine matching the plain belt on a row is not the limit at that rate.")
