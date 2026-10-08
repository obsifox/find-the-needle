class_name DevSmartSortProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30

const TOP_RANK:= 8
const FEED_RUN:= 10.0


const OUT_RUN:= 14.0
const EACH:= 6
const IDS: Array [String] = ["hay_wad", "hay_bale", "eco_brick"]
const NAMES: Array [String] = ["wad", "bale", "brick"]


const SPACINGS:= [2.4, 1.4]
const CENTRE:= Vector3(-11.0, 0.0, 1.0)


const MOUTH:= 0.1

const PLAIN_MACHINE:= 2.0
const BENCH_CALLS:= 20000
const PROF_KEY:= "machine ConveyorCompactSplitter"


var _kinds: Array [int] = [BeltRun.Kind.WAD, BeltRun.Kind.BALE, BeltRun.Kind.BRICK]


var _mouth:= { }
var _kind:= { }
var _arrived:= { }


var _held_by:= { }
var _stopped_by:= { }
var _wrong:= 0
var _relabelled:= 0
var _out_at: Array [int] = []
var _mach_max:= 0
var _runs_us:= 0
var _ticks:= 0
var _every_prop: Array [RigidBody3D] = []
var _rows: Array [Dictionary] = []


func run() -> void:
	if "--smartoverflow" in OS.get_cmdline_user_args():
		call_deferred("_run_overflow")
	else:
		call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	GameState.add_money(500000.0)
	player.global_position = CENTRE + Vector3(6.0, 0.4, 6.0)
	player.set_physics_process(false)


	world.props.clean_blocked = true
	Tech.grant("belt_speed", TOP_RANK)
	FactoryClock.profile = true
	print("belt %.2f m/s (rank %d), %d of each kind a case, in turn: wad, bale, brick"
		% [Tech.belt_speed(), TOP_RANK, EACH])
	print("smart doors: 1 takes wads, 2 takes bales, 3 takes bricks")
	for i in SETTLE:
		await get_tree().physics_frame

	for pack: float in SPACINGS:
		var gap:= pack / Tech.belt_speed()
		print("\n=== %.1f m apart, a load every %.3f s ===" % [pack, gap])
		await _plain(pack, gap)
		await _case("compact, taking turns", pack, gap, false)
		await _case("smart, a door a kind", pack, gap, true)
		await _case("smart, timed by part", pack, gap, true, true)

	_report()
	get_tree().quit(0)


func _deck(at: Vector3) -> Vector3:
	return at + Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)


func _plain(pack: float, gap: float) -> void:
	var a:= _deck(CENTRE) - Vector3(0.0, 0.0, FEED_RUN)
	var belt: Conveyor = world.builds.add_conveyor(a,
		a + Vector3(0.0, 0.0, FEED_RUN + PLAIN_MACHINE + OUT_RUN))
	for i in SETTLE:
		await get_tree().physics_frame
	await _feed(belt, [] as Array [Conveyor], null, "plain belt", pack, gap)
	await _clear()


func _case(label: String, pack: float, gap: float, smart: bool, by_part: bool = false) -> void:
	var c: ConveyorCompactSplitter = world.builds.add_compact_splitter(
		_deck(CENTRE), 0.0, smart)
	if smart:
		for side: int in ConveyorCompactSplitter.OUTPUTS:
			c.set_filter(side, _kinds [side])
	var feed: Conveyor = world.builds.add_conveyor(
		c.port_in() - c.forward() * FEED_RUN, c.port_in())
	var outs: Array [Conveyor] = []
	for side: int in c.output_sides():
		var mouth:= c.port(side)
		var out: Conveyor = world.builds.add_conveyor(mouth, mouth + c.arm_travel(side) * OUT_RUN)
		outs.append(out)
	for i in SETTLE:
		await get_tree().physics_frame
	var timer: PartTimer = null
	if by_part:
		FactoryClock.leave(c)
		timer = PartTimer.new()
		timer.c = c
		add_child(timer)
	await _feed(feed, outs, c, label, pack, gap)
	if timer != null:
		var line:= "      one step by part, us a step over %d steps:" % timer.steps
		var total:= 0.0
		for key: String in timer.us.keys():
			var each:= float(timer.us [key]) / maxf(float(timer.steps), 1.0)
			total += each
			line += "\n        %-26s %6.2f" % [key, each]
		print(line + "\n        %-26s %6.2f" % ["whole step", total])
		timer.queue_free()
	elif smart:
		_bench(c)
	await _clear()


class PartTimer extends Node:
	var c: ConveyorCompactSplitter
	var us:= { }
	var steps:= 0

	func _ready() -> void:
		process_physics_priority = FactoryClock.BEFORE_THE_MACHINES + 1

	func _physics_process(_delta: float) -> void:
		if c == null or not is_instance_valid(c) or not c.is_inside_tree():
			return
		steps += 1
		var t:= Time.get_ticks_usec()
		c._tick_stalls(_delta)
		t = _add("stall counts", t)
		c._apply_catching()
		t = _add("choose a door, open it", t)
		c._unjam_throat()
		t = _add("unjam the throat", t)
		c._share_throat()
		t = _add("share the throat", t)
		c._refresh_held()
		t = _add("refresh held", t)
		var side:= c._open_side()
		t = _add("choose a door again", t)
		WyeSweep.run(c._sweep, c, c._sweep_lanes(), Cfg.BELT_SPEED,
			c.arm_travel(side) if side >= 0 else c.forward())
		t = _add("sweep loose props", t)
		if c._feeder != null and is_instance_valid(c._feeder):
			c._feeder.set_outlet_held(side < 0)
		c._awaiting_choice = false
		_add("let the feed go", t)

	func _add(key: String, t: int) -> int:
		var now:= Time.get_ticks_usec()
		us [key] = int(us.get(key, 0)) + now - t
		return now


func _feed(feed: Conveyor, outs: Array [Conveyor], c: ConveyorCompactSplitter,
		label: String, pack: float, gap: float) -> void:
	_mouth.clear()
	_kind.clear()
	_arrived.clear()
	_held_by.clear()
	_stopped_by.clear()
	_wrong = 0
	_relabelled = 0
	_out_at.clear()
	_mach_max = 0
	_runs_us = 0
	_ticks = 0
	FactoryClock.prof.clear()


	var mouth_line:= FEED_RUN if c == null else feed.path_length()
	var plain_line:= FEED_RUN + PLAIN_MACHINE if c == null else -1.0
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var at:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.6, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var fed:= 0
	for i in EACH * IDS.size():
		var body:= world.props.spawn(IDS [i % IDS.size()],
			Transform3D(Basis(Vector3.UP, yaw), at)) as RigidBody3D
		if body != null:
			fed += 1
			_every_prop.append(body)
		for k in int(gap / step):
			await _tick(feed, outs, c, mouth_line, plain_line)
	var limit:= int((FEED_RUN + OUT_RUN) / maxf(Tech.belt_speed(), 0.01) / step) + 120
	for k in limit:
		await _tick(feed, outs, c, mouth_line, plain_line)
		if _arrived.size() >= fed:
			break
	_print_case(label, pack, fed, c)


func _tick(feed: Conveyor, outs: Array [Conveyor], c: ConveyorCompactSplitter,
		mouth_line: float, plain_line: float) -> void:
	await get_tree().physics_frame
	if feed == null or not is_instance_valid(feed):
		return
	_ticks += 1
	_mach_max = maxi(_mach_max, FactoryClock.last_machines_usec)
	_runs_us += FactoryClock.last_runs_usec
	var now:= Engine.get_physics_frames()
	var r:= feed.run
	for i in range(r.first(), r.first() + r.count()):
		var seq:= r.seq_of(i)
		var s:= r.s_of(i)
		var kind:= r.kind_of(i)
		if not _kind.has(seq):
			_kind [seq] = kind
		if s + r.reach_of(i) >= mouth_line - MOUTH:
			if not _mouth.has(seq):
				_mouth [seq] = [now, s]
			if r.speed_of(i) < 0.05:
				_stopped_by [kind] = int(_stopped_by.get(kind, 0)) + 1
		if plain_line > 0.0 and s >= plain_line and _mouth.has(seq) and not _arrived.has(seq):
			_arrive(seq, now, s - float((_mouth [seq] as Array) [1]), kind)
	for side in outs.size():
		var o:= outs [side].run
		for i in range(o.first(), o.first() + o.count()):
			var seq:= o.seq_of(i)
			if _arrived.has(seq) or not _mouth.has(seq):
				continue
			var dist:= mouth_line - float((_mouth [seq] as Array) [1]) + c.route(side).path_length() + o.s_of(i)
			_arrive(seq, now, dist, o.kind_of(i))
			if c.smart and o.kind_of(i) != _kinds [side]:
				_wrong += 1


func _arrive(seq: int, now: int, dist: float, kind: int) -> void:
	_arrived [seq] = true
	_out_at.append(now)
	var took:= float(now - int((_mouth [seq] as Array) [0])) / float(Engine.physics_ticks_per_second)
	var held:= took - dist / maxf(Tech.belt_speed(), 0.01)
	if int(_kind.get(seq, -1)) != kind:
		_relabelled += 1
	(_held_by.get_or_add(kind, []) as Array).append(held)


func _mean_gap(at: Array [int]) -> float:
	var last:= at.size() - 3
	if last - 3 < 2:
		return 0.0
	return float(at [last - 1] - at [3]) / float(last - 4) / float(Engine.physics_ticks_per_second)


func _print_case(label: String, pack: float, fed: int, c: ConveyorCompactSplitter) -> void:
	var mean:= _mean_gap(_out_at)
	var seen:= { }
	for seq in _kind.keys():
		seen [_kind [seq]] = int(seen.get(_kind [seq], 0)) + 1
	print("  %-22s through %2d / %2d fed, wrong door %d, %.3f s a load; seqs seen on the feed %s, relabelled on the way %d"
		% [label, _arrived.size(), fed, _wrong, mean, str(seen), _relabelled])


	var on_belts:= [0, 0, 0]
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var r:= path.run
		for i in range(r.first(), r.first() + r.count()):
			var idx:= _kinds.find(r.kind_of(i))
			if idx >= 0:
				on_belts [idx] += 1
	var loose:= [0, 0, 0]
	for idx in IDS.size():
		loose [idx] = world.props.count_of(IDS [idx])
	print("      now on the belts: wad %d, bale %d, brick %d; as bodies: wad %d, bale %d, brick %d"
		% [on_belts [0], on_belts [1], on_belts [2], loose [0], loose [1], loose [2]])
	var all_held: Array = []
	var stopped:= 0
	for idx in _kinds.size():
		var k:= _kinds [idx]
		var held: Array = _held_by.get(k, [])
		all_held.append_array(held)
		stopped += int(_stopped_by.get(k, 0))
		print("      %-6s held mean %6.3f s, worst %6.3f s, over %d loads; front stood still at the mouth %d ticks"
			% [NAMES [idx], _avg(held), _worst(held), held.size(), int(_stopped_by.get(k, 0))])
	var row:= { "label": label, "pack": pack, "gap": mean, "held": _avg(all_held),
		"worst": _worst(all_held), "stopped": stopped, "wrong": _wrong,
		"through": _arrived.size(), "fed": fed, "step_us": 0.0, "load_us": 0.0 }
	if c != null:
		var prof: Array = FactoryClock.prof.get(PROF_KEY, [0, 0])
		var us:= float(prof [0])
		var calls:= maxi(int(prof [1]), 1)
		row ["step_us"] = us / calls
		row ["load_us"] = us / maxf(float(_arrived.size()), 1.0)
		print("      splitter step %.1f us mean over %d steps on %d ticks, %.1f us for each load through; worst tick of every machine %d us; belts %.1f us a tick"
			% [us / calls, int(prof [1]), _ticks, row ["load_us"], _mach_max,
				float(_runs_us) / maxf(float(_ticks), 1.0)])
		var others: Array [String] = []
		for key: String in FactoryClock.prof.keys():
			if key != PROF_KEY:
				others.append(key)
		if not others.is_empty():
			print("      also on the clock: %s" % ", ".join(others))
	_rows.append(row)


func _bench(c: ConveyorCompactSplitter) -> void:
	var line:= "      choosing a door, %d calls each:" % BENCH_CALLS
	for idx in _kinds.size():
		var k:= _kinds [idx]
		var t:= Time.get_ticks_usec()
		for n in BENCH_CALLS:
			c._choose_output(k)
		line += " %s %.2f us" % [NAMES [idx], float(Time.get_ticks_usec() - t) / BENCH_CALLS]
	print(line)


func _avg(a: Array) -> float:
	var total:= 0.0
	for v in a:
		total += float(v)
	return total / maxf(float(a.size()), 1.0)


func _worst(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var w:= - INF
	for v in a:
		w = maxf(w, float(v))
	return w


func _clear() -> void:
	world.builds.from_array([])
	for body in _every_prop:
		if is_instance_valid(body) and body.is_inside_tree() and body is Carryable:
			world.props.remove(body as Carryable)
	_every_prop.clear()
	for i in 10:
		await get_tree().physics_frame


	for item in world.props.items.duplicate():
		if is_instance_valid(item) and IDS.has(item.item_id):
			world.props.remove(item)
	for i in 5:
		await get_tree().physics_frame


const OVERFLOW_WARMUP:= 6.0
const OVERFLOW_WINDOW:= 20.0
const WAD_GAP:= 0.6


var _wad_gap:= WAD_GAP
var _wad_strands:= 0

var _only:= ""
const DOOR2_RUN:= 3.0
const DOOR3_RUN:= 8.0
const RANKS:= [8, 3, 0]


func _run_overflow() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	GameState.add_money(500000.0)
	player.global_position = CENTRE + Vector3(6.0, 0.4, 6.0)
	player.set_physics_process(false)
	world.props.clean_blocked = true
	var any:= ConveyorCompactSplitter.RULE_ANY
	var spill:= ConveyorCompactSplitter.RULE_OVERFLOW

	var ranks: Array = RANKS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rank="):
			ranks = [int(a.trim_prefix("rank="))]
		elif a.begins_with("gap="):
			_wad_gap = float(a.trim_prefix("gap="))
		elif a.begins_with("strands="):
			_wad_strands = int(a.trim_prefix("strands="))
		elif a.begins_with("only="):
			_only = a.trim_prefix("only=")
		elif a == "oldfull":
			ConveyorCompactSplitter.fill_to_fork = false
	for rank: int in ranks:
		Tech.grant("belt_speed", rank)
		for i in SETTLE:
			await get_tree().physics_frame
		print("\n=== belt rank %d, %.2f m/s, wads %.1f m apart: a packed belt carries %.2f a second ==="
			% [rank, Tech.belt_speed(), _wad_gap, Tech.belt_speed() / _wad_gap])
		await _overflow_rig("plain belt", false, any, 0.0)
		await _overflow_rig("door 2 always free", true, spill, 0.0)
		await _overflow_rig("door 2 full for good", true, spill, INF)
		await _overflow_rig("door 2 takes one every 1 s", true, spill, 1.0)
		await _overflow_rig("door 2 takes one every 3 s", true, spill, 3.0)
		await _overflow_rig("every 1 s, door 3 Anything", true, any, 1.0)
	get_tree().quit(0)


func _overflow_rig(label: String, machine: bool, door3_rule: int, drain: float) -> void:
	if _only != "" and not label.contains(_only):
		return
	var feed: Conveyor
	var two: Conveyor
	var three: Conveyor = null
	var c: ConveyorCompactSplitter = null
	if machine:
		c = world.builds.add_compact_splitter(_deck(CENTRE), 0.0, true)
		c.set_filter(ConveyorCompactSplitter.OUT_LEFT, ConveyorCompactSplitter.RULE_NONE)
		c.set_filter(ConveyorCompactSplitter.OUT_FORWARD, ConveyorCompactSplitter.RULE_ANY)
		c.set_filter(ConveyorCompactSplitter.OUT_RIGHT, door3_rule)
		feed = world.builds.add_conveyor(c.port_in() - c.forward() * FEED_RUN, c.port_in())
		var m2:= c.port(ConveyorCompactSplitter.OUT_FORWARD)
		two = world.builds.add_conveyor(m2,
			m2 + c.arm_travel(ConveyorCompactSplitter.OUT_FORWARD) * DOOR2_RUN)
		var m3:= c.port(ConveyorCompactSplitter.OUT_RIGHT)
		three = world.builds.add_conveyor(m3,
			m3 + c.arm_travel(ConveyorCompactSplitter.OUT_RIGHT) * DOOR3_RUN)
	else:
		var a:= _deck(CENTRE) - Vector3(0.0, 0.0, FEED_RUN)
		feed = world.builds.add_conveyor(a, a + Vector3(0.0, 0.0, FEED_RUN + DOOR2_RUN))
		two = feed
	for i in SETTLE:
		await get_tree().physics_frame

	var hz:= float(Engine.physics_ticks_per_second)


	var ride:= (FEED_RUN + 2.0 + DOOR3_RUN) / maxf(Tech.belt_speed(), 0.01)
	var warm:= int((OVERFLOW_WARMUP + ride * 2.0) * hz)
	var total:= warm + int(OVERFLOW_WINDOW * hz)
	var gap_ticks:= maxi(1, ceili(_wad_gap / maxf(Tech.belt_speed(), 0.01) * hz))
	var since:= gap_ticks
	var clock:= 0.0
	var out2:= 0
	var out3:= 0
	var fed:= 0
	var stood:= 0
	var watched:= 0

	var throat:= 0
	var switches:= 0
	var was_down: Object = feed.downstream
	var front_was:= - INF
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var at:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
	for t in total:
		await get_tree().physics_frame
		var counting:= t >= warm
		since += 1
		if since >= gap_ticks and _head_clear(feed):
			var body:= world.props.spawn("hay_wad",
				Transform3D(Basis(Vector3.UP, yaw), at)) as RigidBody3D
			if body != null:
				if _wad_strands > 0 and body is HayWad:
					(body as HayWad).set_strands(_wad_strands)
				_every_prop.append(body)
				since = 0
				if counting:
					fed += 1
		two.set_outlet_held(true)
		if three != null:
			three.set_outlet_held(true)
		clock += 1.0 / hz
		if drain == 0.0:
			while _lift_parked(two):
				if counting:
					out2 += 1
		elif not is_inf(drain) and clock >= drain and _lift_parked(two):
			clock = 0.0
			if counting:
				out2 += 1
		if three != null:
			while _lift_parked(three):
				if counting:
					out3 += 1
		if not counting or c == null:
			continue
		var front:= - INF
		for m in feed.load_marks(false):
			front = maxf(front, float(m ["s"]))
		if not is_inf(front):
			watched += 1
			if absf(front - front_was) < 0.0001:
				stood += 1
		front_was = front
		if _throat_blocked(c):
			throat += 1
		if feed.downstream != was_down:
			switches += 1
			was_down = feed.downstream

	var secs:= OVERFLOW_WINDOW
	var line:= "  %-28s %.2f a second through (door 2 %.2f, door 3 %.2f), %.2f fed" % [
		label, float(out2 + out3) / secs, float(out2) / secs, float(out3) / secs,
		float(fed) / secs]
	if c != null:
		line += ", feed stood still %d%% of the time, feed switched door %d times, a load stood in the throat %d%% of the time" % [
			int(100.0 * float(stood) / maxf(float(watched), 1.0)), switches,
			int(100.0 * float(throat) / maxf(float(watched), 1.0))]
	print(line)
	_where(feed, two, three, c)
	await _clear()


func _throat_blocked(c: ConveyorCompactSplitter) -> bool:
	var fork:= c._throat_s()
	for side: int in ConveyorCompactSplitter.OUTPUTS:
		var r:= c.route(side).run
		for i in range(r.first(), r.first() + r.count()):
			if r.s_of(i) - r.reach_of(i) < fork and r.speed_of(i) < 0.05:
				return true
	return false


func _head_clear(feed: Conveyor) -> bool:
	var r:= feed.run
	for i in range(r.first(), r.first() + r.count()):
		if r.s_of(i) < 0.8 + _wad_gap and r.speed_of(i) < 0.05:
			return false
	return true


func _where(feed: Conveyor, two: Conveyor, three: Conveyor, c: ConveyorCompactSplitter) -> void:
	var line:= "      at the end: feed %s" % _path_state(feed)
	if c != null:
		for side: int in ConveyorCompactSplitter.OUTPUTS:
			var route:= c.route(side)
			line += "; route %d %s stall %.2f foreign %s" % [side + 1, _path_state(route),
				float(c._compact_stall [side]), str(route._foreign)]
		line += "; throat ends %.2f" % c._throat_s()
		line += "; door 2 belt %s; door 3 belt %s; door for a wad now %d, feed goes to %s" % [
			_path_state(two), _path_state(three),
			c._choose_output(BeltRun.Kind.WAD) + 1,
			str(feed.downstream.name) if feed.downstream != null else "nothing"]
	line += "; loose wads %d" % world.props.count_of("hay_wad")
	print(line)


func _path_state(p: BeltPath) -> String:
	if p == null or not is_instance_valid(p):
		return "none"
	var marks:= p.load_marks(false)
	var front:= - INF
	for m in marks:
		front = maxf(front, float(m ["s"]))
	var at: Array [String] = []
	for m in marks:
		at.append("%.2f/%.2f" % [float(m ["s"]), float(m ["reach"])])
	return "[%d loads, front %.2f of %.2f, waiting %s, catching %s, at %s]" % [marks.size(),
		(front if not is_inf(front) else 0.0), p.path_length(), p.has_load_waiting(),
		p._catching, " ".join(at)]


func _lift_parked(belt: Conveyor) -> bool:
	var rb:= belt.waiting_rider()
	if rb != null and rb is Carryable:
		world.props.remove(rb as Carryable)
		belt.wake()
		return true
	var r:= belt.run
	if not r.front_near_end(0.0):
		return false
	var best:= -1
	var best_s:= - INF
	for i in range(r.first(), r.first() + r.count()):
		if r.s_of(i) > best_s:
			best_s = r.s_of(i)
			best = i
	if best < 0:
		return false
	r.remove_at(best)
	belt.wake()
	return true


func _report() -> void:
	print("\n=== held at the machine, seconds a load ===")
	print("  %-22s %6s %9s %9s %9s %8s %9s %9s" % ["", "apart", "a load",
		"held", "worst", "stopped", "step us", "load us"])
	for row in _rows:
		print("  %-22s %4.1f m %7.3f s %7.3f s %7.3f s %8d %9.1f %9.1f"
			% [row ["label"], row ["pack"], row ["gap"], row ["held"], row ["worst"],
				row ["stopped"], row ["step_us"], row ["load_us"]])
	print("\n  held: time from the end of the feed to the out belt, less that distance at belt speed.")
	print("  stopped: ticks the front load stood still at the mouth. Straight through is 0 and 0.")
