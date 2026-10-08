class_name DevSplitterFlowProbe
extends Node


var world: Node3D
var player: Player

const OUT_LEN:= 6.0
const GAP:= 0.9

var _pass:= 0
var _fail:= 0
var _out_dir:= ""
var _deck_y:= 0.0


func _wanted(case: String) -> bool:
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--splitterflow")
	var named: Array [String] = []
	for i in range(at + 2, args.size()):
		if args [i].begins_with("--"):
			break
		named.append(args [i])
	return named.is_empty() or case in named


func run(out_dir: String) -> void:
	_out_dir = out_dir
	if _out_dir != "":
		DirAccess.make_dir_recursive_absolute(_out_dir)
	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	for i in 30:
		await get_tree().process_frame
	GameState.add_money(100000.0)


	world.props.clean_blocked = true


	player.set_physics_process(false)
	Tech.grant("belt_speed", 6)
	print("belt speed %.2f m/s" % Tech.belt_speed())
	if _wanted("compact_open"):
		await _compact_open(Vector3(-15.0, 0.0, -16.0))
	if _wanted("compact_enclosed"):
		await _compact_enclosed(Vector3(-4.0, 0.0, -16.0))
	if _wanted("smart_sort"):
		await _smart_sort(Vector3(7.0, 0.0, -16.0))
	if _wanted("smart_hold"):
		await _smart_hold(Vector3(-15.0, 0.0, 3.0))
	if _wanted("smart_overflow"):
		await _smart_overflow(Vector3(-4.0, 0.0, 3.0))
	if _wanted("mixed_bend"):
		await _mixed_bend(Vector3(6.0, 0.0, 6.0))
	if _wanted("tuft_stream_at_door"):
		await _tuft_stream_at_door(Vector3(-15.0, 0.0, 20.0))
	if _wanted("straw_at_door"):
		await _straw_at_door(Vector3(6.0, 0.0, 20.0))
	if _wanted("tuft_at_door"):


		await _tuft_at_door(Vector3(-15.0, 0.0, 27.0))
	if _wanted("open_enclosed_end"):
		await _open_enclosed_end(Vector3(6.0, 0.0, 14.0))


	if _wanted("doors_all_full"):
		await _doors_all_full(Vector3(18.0, 0.0, -16.0))
	if _wanted("door_no_belt"):
		await _door_with_no_belt(Vector3(29.0, 0.0, -16.0))
	print("\n=== splitterflow: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _compact_open(at: Vector3) -> void:
	print("\n=== compact splitter, open belts ===")
	var line:= _splitter_line(at, false, false, false)
	await _feed(line ["feed"], _many("hay_wad", 15), 30.0, line, "compact_open")
	var per:= _out_totals(line)
	_check("every wad reached an output belt (%d of 15)" % _sum(per), _sum(per) == 15)
	_check("all three doors took a share %s" % [per], per.min() >= 3)
	_check("the feed belt emptied (%d left)" % _aboard(line ["feed"]), _aboard(line ["feed"]) == 0)


func _compact_enclosed(at: Vector3) -> void:
	print("\n=== compact splitter, enclosed belts in and out ===")
	var line:= _splitter_line(at, false, true, true)
	var loads:= _many("hay_wad", 8)
	loads.append_array(_many("hay_bale", 4))
	loads.shuffle()
	await _feed(line ["feed"], loads, 34.0, line, "compact_enclosed")
	var per:= _out_totals(line)
	_check("every load crossed the enclosed line and a door (%d of 12)" % _sum(per),
		_sum(per) == 12)
	_check("all three doors took a share %s" % [per], per.min() >= 2)
	var left:= _aboard(line ["feed"]) + _aboard(line ["lead"])
	_check("nothing stuck in the enclosed feed (%d left)" % left, left == 0)


func _smart_sort(at: Vector3) -> void:
	print("\n=== smart splitter: bales to 1, wads to 2, door 3 shut ===")
	var line:= _splitter_line(at, true, false, false)
	var s: ConveyorCompactSplitter = line ["splitter"]
	s.set_filter(0, BeltRun.Kind.BALE)
	s.set_filter(1, BeltRun.Kind.WAD)
	s.set_filter(2, ConveyorCompactSplitter.RULE_NONE)
	var loads:= _many("hay_wad", 6)
	loads.append_array(_many("hay_bale", 6))
	loads.shuffle()
	await _feed(line ["feed"], loads, 30.0, line, "smart_sort")
	var k:= _out_kinds(line)
	_check("door 1 took only bales, all six", _only(k [0], BeltRun.Kind.BALE, 6))
	_check("door 2 took only wads, all six", _only(k [1], BeltRun.Kind.WAD, 6))
	_check("the shut door took nothing", k [2].is_empty())


func _smart_hold(at: Vector3) -> void:
	print("\n=== smart splitter: a load no door takes, then a catch all ===")
	var line:= _splitter_line(at, true, false, false)
	var s: ConveyorCompactSplitter = line ["splitter"]
	s.set_filter(0, BeltRun.Kind.BALE)
	s.set_filter(1, ConveyorCompactSplitter.RULE_NONE)
	s.set_filter(2, ConveyorCompactSplitter.RULE_NONE)
	var loads:= _many("hay_bale", 3)
	loads.append_array(_many("eco_brick", 2))
	loads.append_array(_many("hay_bale", 3))
	await _feed(line ["feed"], loads, 26.0, line, "smart_hold_before")
	var k:= _out_kinds(line)
	_check("the three bales ahead of the bricks left by door 1",
		_only(k [0], BeltRun.Kind.BALE, 3))
	_check("the bricks and the bales behind them wait (feed holds %d)"
		% _aboard(line ["feed"]), _aboard(line ["feed"]) == 5 and k [2].is_empty())
	s.set_filter(2, ConveyorCompactSplitter.RULE_UNDEFINED)
	await _feed(line ["feed"], [], 20.0, line, "smart_hold_after")
	k = _out_kinds(line)
	_check("the bricks left by the catch all door", _only(k [2], BeltRun.Kind.BRICK, 2))
	_check("the bales behind them reached door 1", _only(k [0], BeltRun.Kind.BALE, 6))


func _smart_overflow(at: Vector3) -> void:
	print("\n=== smart splitter: door 1 anything but blocked, door 3 overflow ===")
	var line:= _splitter_line(at, true, false, false)
	var s: ConveyorCompactSplitter = line ["splitter"]

	(line ["outs"] [0] as Conveyor).set_blocked(true)
	s.set_filter(0, ConveyorCompactSplitter.RULE_ANY)
	s.set_filter(1, ConveyorCompactSplitter.RULE_NONE)
	s.set_filter(2, ConveyorCompactSplitter.RULE_OVERFLOW)
	await _feed(line ["feed"], _many("hay_wad", 12), 30.0, line, "smart_overflow")
	var per:= _out_totals(line)
	var waiting:= _aboard(s.route(0))
	_check("overflow took everything the blocked door could not %s, %d waiting at door 1"
		% [per, waiting], per [2] + waiting == 12 and per [1] == 0)
	_check("nothing was thrown on the floor at the doors", _loose_near(line ["centre"], 2.5) == 0)


func _doors_all_full(at: Vector3) -> void:
	print("\n=== compact splitter: every door backed up ===")
	var line:= _splitter_line(at, false, false, false, 4.0)
	var s: ConveyorCompactSplitter = line ["splitter"]


	var shut:= func() -> void:
		for c: Conveyor in line ["outs"]:
			c.set_blocked(true)
	await _feed(line ["feed"], _many("hay_bale", 16), 40.0, line, "doors_all_full",
		9.0, shut)
	_out_kinds(line)
	_report_routes(s)
	var inside:= _throat_overlaps(s)
	for pair in inside:
		print("    %s" % pair)
	_check("no two loads stand inside each other on the throat (%d)" % inside.size(),
		inside.is_empty())
	_check("nothing was thrown on the floor (%d)" % _loose_near(line ["centre"], 4.0),
		_loose_near(line ["centre"], 4.0) == 0)
	_check("the loads that did not fit waited on the feed (%d)" % _aboard(line ["feed"]),
		_aboard(line ["feed"]) > 0)


func _door_with_no_belt(at: Vector3) -> void:
	print("\n=== compact splitter: doors 1 and 3 full, door 2 has no belt ===")
	var line:= _splitter_line(at, false, false, false, 1.6, ConveyorCompactSplitter.OUT_FORWARD)
	await _feed(line ["feed"], _many("hay_bale", 14), 34.0, line, "door_no_belt")
	var per:= _out_totals(line)
	var dumped:= _dumped_near(line ["centre"], 5.0)
	_check("the empty door did not swallow the line (%d in a heap)" % dumped,
		dumped <= 1)
	_check("the loads that did not fit waited on the feed (%d, doors %s)"
		% [_aboard(line ["feed"]), per], _aboard(line ["feed"]) > 0)


func _report_routes(s: ConveyorCompactSplitter) -> void:
	for side in ConveyorCompactSplitter.OUTPUTS:
		var route:= s.route(side)
		var at: Array [String] = []
		var triples:= route.lane_loads_before(INF)
		var i:= 0
		while i + 2 < triples.size():
			at.append("%.3f" % triples [i])
			i += 3
		print("  door %d: catching %s, len %.2f, loads at [%s]"
			% [side + 1, route._catching, route.path_length(), ", ".join(at)])


func _throat_overlaps(s: ConveyorCompactSplitter) -> Array [String]:
	var out: Array [String] = []
	var routes:= s.routes()
	for i in range(routes.size()):
		for load: Array in _loads_of(routes [i]):
			for j in range(i + 1, routes.size()):
				for other: Array in _loads_of(routes [j]):
					var apart:= (load [0] as Vector3).distance_to(other [0] as Vector3)
					if apart < maxf(float(load [1]), float(other [1])):
						out.append("%s has a load at %s and %s one %.2f m away at %s"
							% [routes [i].name, (load [0] as Vector3).snappedf(0.01),
								routes [j].name, apart,
								(other [0] as Vector3).snappedf(0.01)])
	return out


static func _loads_of(path: BeltPath) -> Array:
	var out: Array = []
	var triples:= path.lane_loads_before(INF)
	var i:= 0
	while i + 2 < triples.size():
		out.append([path._point_at(triples [i]), triples [i + 1]])
		i += 3
	return out


func _mixed_bend(at: Vector3) -> void:
	print("\n=== open belt, bend, enclosed belt, bend, open belt ===")
	var y:= _deck_y
	var p0:= Vector3(at.x, y, at.z)
	var p1:= p0 + Vector3(5.0, 0.0, 0.0)
	var p2:= p1 + Vector3(0.0, 0.0, 6.0)
	var p3:= p2 + Vector3(5.0, 0.0, 0.0)
	var id: int = world.builds.new_line_id()
	var first: Conveyor = world.builds.add_conveyor(p0, p1, id)
	var middle: Conveyor = world.builds.add_enclosed_conveyor(p1, p2, id)
	var last: Conveyor = world.builds.add_conveyor(p2, p3, id)
	last.set_outlet_held(true)
	var near:= 0
	for k: ConveyorCorner in world.builds.corners:
		if is_instance_valid(k) and not k is EnclosedConveyorCorner:
			near += 1
	print("  %d open bends in the yard" % near)
	var loads:= _many("hay_wad", 6)
	loads.append_array(_many("hay_bale", 2))
	var line:= { "feed": first, "centre": p1.lerp(p2, 0.5) }
	await _feed(first, loads, 34.0, line, "mixed_bend")
	var arrived:= _aboard(last)
	var inside:= _aboard(middle)
	print("  last belt holds %d, enclosed holds %d, first holds %d" % [arrived, inside,
		_aboard(first)])
	_check("all eight loads came through both bends (%d)" % arrived, arrived == 8)
	_check("nothing parked inside the shell (%d)" % inside, inside == 0)


func _tuft_at_door(at: Vector3) -> void:
	print("\n=== a tuft fed at an enclosed intake ===")
	var y:= _deck_y
	var p0:= Vector3(at.x, y, at.z)
	var p1:= p0 + Vector3(4.0, 0.0, 0.0)
	var p2:= p1 + Vector3(5.0, 0.0, 0.0)
	var p3:= p2 + Vector3(4.0, 0.0, 0.0)
	var id: int = world.builds.new_line_id()
	var first: Conveyor = world.builds.add_conveyor(p0, p1, id)
	var shell: Conveyor = world.builds.add_enclosed_conveyor(p1, p2, id)
	var last: Conveyor = world.builds.add_conveyor(p2, p3, id)
	last.set_outlet_held(true)
	var loads: Array = ["hay_tuft"]
	loads.append_array(_many("hay_wad", 4))
	var line:= { "feed": first, "centre": p1 }
	await _feed(first, loads, 26.0, line, "tuft_at_door")
	print("  first %d, enclosed %d, last %d" % [_aboard(first), _aboard(shell), _aboard(last)])
	for item in world.props.items:
		if is_instance_valid(item) and item.item_id == "hay_tuft":
			print("  tuft at %s" % item.global_position.snappedf(0.1))


	_check("the tuft and the four wads behind it all got through (%d of 5)" % _aboard(last),
		_aboard(last) == 5)
	var tufts_out:= 0
	for r in last.riders():
		if r is HayTuft:
			tufts_out += 1
	_check("the tuft came out as a tuft (%d)" % tufts_out, tufts_out == 1)
	_check("nothing was left inside (enclosed holds %d)" % _aboard(shell),
		_aboard(shell) == 0)


func _tuft_stream_at_door(at: Vector3) -> void:
	print("\n=== a stream of tufts and loose straw at an enclosed intake ===")
	var y:= _deck_y
	var p0:= Vector3(at.x, y, at.z)
	var p1:= p0 + Vector3(6.0, 0.0, 0.0)
	var p2:= p1 + Vector3(5.0, 0.0, 0.0)
	var p3:= p2 + Vector3(4.0, 0.0, 0.0)
	var id: int = world.builds.new_line_id()
	var first: Conveyor = world.builds.add_conveyor(p0, p1, id)
	var shell: Conveyor = world.builds.add_enclosed_conveyor(p1, p2, id)
	var last: Conveyor = world.builds.add_conveyor(p2, p3, id)


	var out:= { "tufts": 0, "tuft_hay": 0, "wads": 0, "other": 0 }
	shell.handed_on.connect(func(body: RigidBody3D) -> void:
		if body is HayTuft:
			out ["tufts"] += 1
			out ["tuft_hay"] += (body as HayTuft).strands
		elif body is HayWad:
			out ["wads"] += 1
		elif body is Carryable:
			out ["other"] += 1
		else:


			out ["tuft_hay"] += 1)
	shell.handed_on_record.connect(func(_seq: int, kind: int, strands: int) -> void:
		if kind == BeltRun.Kind.WAD:
			out ["wads"] += 1
		elif kind == BeltRun.Kind.TUFT:
			out ["tufts"] += 1
			out ["tuft_hay"] += strands
		else:
			out ["other"] += 1)
	var spawn_at:= first.a + first.forward * 0.6 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(first.forward.x, first.forward.z)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var step:= maxf(get_physics_process_delta_time(), 1e-06)


	var plan: Array = []
	plan.append_array(_many("hay_tuft", 12))
	plan.append_array(_many("straw", 3))
	plan.append_array(_many("hay_tuft", 12))
	plan.append_array(_many("hay_wad", 8))
	var tuft_hay:= 0
	var straw_fed:= 0
	var t:= 0.0
	var next:= 0.0
	var fed:= 0
	var last_report:= -1.0
	while t < 45.0:
		if fed < plan.size() and t >= next:
			var what: String = plan [fed]
			if what == "straw":
				for i in 40:
					var jitter:= Vector3(rng.randf_range(-0.15, 0.15),
						rng.randf_range(0.0, 0.2), rng.randf_range(-0.15, 0.15))
					if world.live.spawn(spawn_at + jitter, StrandFactory.random_strand_basis(rng),
							Vector3.ZERO, StrandFactory.random_tint(rng)) != null:
						straw_fed += 1
			else:
				var n:= 40 + rng.randi() % 60
				var extra:= { "strands": n } if what == "hay_tuft" else { }
				if world.props.spawn(what, Transform3D(Basis(Vector3.UP, yaw), spawn_at),
						extra) != null and what == "hay_tuft":
					tuft_hay += n
			fed += 1
			next += 0.5
		if t - last_report >= 3.0:
			last_report = t
			print("  t=%4.1f first %d (tufts %d, straw %d, wads %d)  enclosed %d  out %s  mouth heap %s"
				% [t, _aboard(first), _riders_of(first, "tuft"), _riders_of(first, "straw"),
				_riders_of(first, "wad"), _aboard(shell), out, _heap_at(p1)])
		await get_tree().physics_frame
		t += step
	var heap:= _heap_at(p1)
	print("  fed 24 tufts of %d strands, %d loose strands and 8 wads; out %s; mouth heap %s"
		% [tuft_hay, straw_fed, out, heap])
	_check("all eight wads came out of the enclosed run (%d)" % out ["wads"], out ["wads"] == 8)
	_check("every tuft's hay came out, and loose straw with it (%d of %d + up to %d)"
		% [out ["tuft_hay"], tuft_hay, straw_fed],
		out ["tuft_hay"] >= tuft_hay and out ["tuft_hay"] <= tuft_hay + straw_fed)
	_check("most of the loose straw came out too (%d of %d)"
		% [out ["tuft_hay"] - tuft_hay, straw_fed],
		out ["tuft_hay"] - tuft_hay >= straw_fed * 0.8)
	_check("nothing but hay came out (%d)" % out ["other"], out ["other"] == 0)
	_check("nothing lies in the mouth %s" % heap, heap ["tufts"] == 0 and heap ["straw"] == 0)
	_check("nothing stayed on the feed belt (%d)" % _aboard(first), _aboard(first) == 0)
	_check("nothing stayed inside the enclosed run (%d)" % _aboard(shell), _aboard(shell) == 0)
	_clear_props_near(p3, 6.0)


func _straw_at_door(at: Vector3) -> void:
	print("\n=== single strands, and hay dropped in the mouth, through a sealed bend ===")
	var y:= _deck_y
	var p0:= Vector3(at.x, y, at.z)
	var p1:= p0 + Vector3(5.0, 0.0, 0.0)
	var p2:= p1 + Vector3(4.0, 0.0, 0.0)
	var p3:= p2 + Vector3(0.0, 0.0, 4.0)
	var p4:= p3 + Vector3(0.0, 0.0, 4.0)
	var id: int = world.builds.new_line_id()
	var first: Conveyor = world.builds.add_conveyor(p0, p1, id)
	var sealed_a: Conveyor = world.builds.add_enclosed_conveyor(p1, p2, id)
	var sealed_b: Conveyor = world.builds.add_enclosed_conveyor(p2, p3, id)
	var last: Conveyor = world.builds.add_conveyor(p3, p4, id)
	var out:= { "tufts": 0, "hay": 0, "strands": 0, "records": 0, "biggest": 0 }
	sealed_b.handed_on.connect(func(body: RigidBody3D) -> void:
		if body is HayTuft:
			out ["tufts"] += 1
			out ["hay"] += (body as HayTuft).strands
			out ["biggest"] = maxi(out ["biggest"], (body as HayTuft).strands)
		else:
			out ["strands"] += 1
			out ["hay"] += 1)
	sealed_b.handed_on_record.connect(func(_seq: int, _kind: int, _n: int) -> void:
		out ["records"] += 1)
	var into_bend:= { "tuft_records": 0 }
	sealed_a.handed_on_record.connect(func(_seq: int, kind: int, _n: int) -> void:
		if kind == BeltRun.Kind.TUFT:
			into_bend ["tuft_records"] += 1)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 11
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var feed_at:= first.a + first.forward * 0.6 + Vector3(0.0, 0.1, 0.0)
	var mouth_at:= p1 + sealed_a.forward * 0.3 + Vector3(0.0, 0.3, 0.0)


	var lip_at:= p1 + sealed_a.forward * 0.15 + Vector3(0.0, 0.3, 0.0)
	var fed:= 0
	var t:= 0.0
	var next:= 0.0
	var dropped:= false
	var set_down:= false
	var tuft_n:= 37
	var seen_inside:= false
	while t < 30.0:

		if t >= next and t < 24.0:
			if world.live.spawn(feed_at, StrandFactory.random_strand_basis(rng),
					Vector3.ZERO, StrandFactory.random_tint(rng)) != null:
				fed += 1
			next += 0.4
		if not dropped and t >= 6.0:
			dropped = true
			for i in 30:
				var jitter:= Vector3(rng.randf_range(-0.12, 0.12),
					rng.randf_range(0.0, 0.15), rng.randf_range(-0.12, 0.12))
				if world.live.spawn(mouth_at + jitter, StrandFactory.random_strand_basis(rng),
						Vector3.ZERO, StrandFactory.random_tint(rng)) != null:
					fed += 1
		if not set_down and t >= 12.0:
			set_down = true
			world.props.spawn("hay_tuft", Transform3D(Basis(), lip_at), { "strands": tuft_n })
		for path: Conveyor in [sealed_a, sealed_b]:
			for r in path.riders():
				if r is HayTuft and path == sealed_a:
					seen_inside = true
		await get_tree().physics_frame
		t += step
	var heap:= _heap_at(p1)
	print("  fed %d loose strands and a %d strand tuft; out of the bend %s; %d tuft records crossed into the bend; mouth heap %s; first %d, sealed %d"
		% [fed, tuft_n, out, into_bend ["tuft_records"], heap, _aboard(first),
		_aboard(sealed_a) + _aboard(sealed_b)])
	_check("all of the hay came out of the far end (%d of %d)" % [out ["hay"], fed + tuft_n],
		out ["hay"] == fed + tuft_n)
	_check("the handful dropped in the mouth came out as one tuft (biggest %d)" % out ["biggest"],
		out ["biggest"] >= 30)
	_check("the trickle came out as the loose straw it went in as (%d strands, %d tufts)"
		% [out ["strands"], out ["tufts"]], out ["strands"] >= 50 and out ["tufts"] <= 4)
	_check("nothing crossed out of the casing as a record (%d)" % out ["records"],
		out ["records"] == 0)
	_check("tufts crossed into the bend as records (%d)" % into_bend ["tuft_records"],
		into_bend ["tuft_records"] > 0)
	_check("no tuft had a body before the far end", not seen_inside)
	_check("nothing lies in the mouth %s" % heap, heap ["tufts"] == 0 and heap ["straw"] == 0)
	_check("nothing stayed on the line (%d, %d)" % [_aboard(first),
		_aboard(sealed_a) + _aboard(sealed_b)],
		_aboard(first) == 0 and _aboard(sealed_a) + _aboard(sealed_b) == 0)
	_clear_props_near(p4, 6.0)


func _clear_props_near(centre: Vector3, radius: float) -> void:
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and not BeltPath.is_rider(item) and item.global_position.distance_to(centre) < radius:
			world.props.remove(item)


func _what(b: Node) -> String:
	if b is HayTuft:
		return "tuft"
	if b is HayWad:
		return "wad"
	if b is Carryable:
		return (b as Carryable).item_id
	return "straw"


func _riders_of(path: BeltPath, what: String) -> int:
	var n:= 0
	for r in path.riders():
		if _what(r) == what:
			n += 1
	return n


func _heap_at(seam: Vector3) -> Dictionary:
	var tufts:= 0
	var straw:= 0
	var top:= - INF
	for item in world.props.items:
		if is_instance_valid(item) and item is HayTuft and not BeltPath.is_rider(item) and item.global_position.distance_to(seam) < 1.2:
			tufts += 1
			top = maxf(top, item.global_position.y - seam.y)
	for rb: RigidBody3D in world.live._active:
		if is_instance_valid(rb) and rb.is_inside_tree() and not BeltPath.is_rider(rb) and rb.global_position.distance_to(seam) < 1.2:
			straw += 1
			top = maxf(top, rb.global_position.y - seam.y)
	return { "tufts": tufts, "straw": straw, "top": snappedf(top, 0.01) }


func _open_enclosed_end(at: Vector3) -> void:
	print("\n=== an enclosed belt with nothing after it ===")
	var y:= _deck_y
	var p0:= Vector3(at.x, y, at.z)
	var p1:= p0 + Vector3(5.0, 0.0, 0.0)
	var shell: Conveyor = world.builds.add_enclosed_conveyor(p0, p1)
	var line:= { "feed": shell, "centre": p1 }
	var before: int = world.props.items.size()
	await _feed(shell, _many("hay_wad", 3), 16.0, line, "enclosed_open_end")
	for item in world.props.items:
		if is_instance_valid(item) and item.global_position.distance_to(p0) < 12.0:
			print("  %s at %s" % [item.item_id, item.global_position.snappedf(0.1)])
	var landed:= _loose_near(p1 + Vector3(2.0, 0.0, 0.0), 5.0)
	print("  enclosed holds %d, %d loose past its end, props %d to %d" % [_aboard(shell),
		landed, before, world.props.items.size()])
	_check("wads leaving an open enclosed end land as wads (%d of 3)" % landed, landed == 3)


func _splitter_line(at: Vector3, smart: bool, enclosed_in: bool,
		enclosed_out: bool, out_len:= OUT_LEN, bare_side:= -1) -> Dictionary:
	var builds: BuildManager = world.builds
	var y:= _deck_y
	var centre:= Vector3(at.x, y, at.z + 8.0 + ConveyorCompactSplitter.PORT_R)
	var s: ConveyorCompactSplitter = builds.add_compact_splitter(centre, PI, smart)
	var line:= { "splitter": s, "centre": centre }
	var into:= s.port_in()
	if enclosed_in:
		var mid:= into - Vector3(0.0, 0.0, 4.0)
		line ["lead"] = builds.add_conveyor(Vector3(at.x, y, at.z), mid)
		line ["feed"] = builds.add_enclosed_conveyor(mid, into)
	else:
		line ["feed"] = builds.add_conveyor(Vector3(at.x, y, at.z), into)
		line ["lead"] = null
	var outs: Array = []
	for side in ConveyorCompactSplitter.OUTPUTS:
		if side == bare_side:
			outs.append(null)
			continue
		var mouth:= s.port(side)
		var dir:= s.arm_travel(side)
		dir.y = 0.0
		var far:= mouth + dir.normalized() * out_len
		var c: Conveyor = builds.add_enclosed_conveyor(mouth, far) if enclosed_out else builds.add_conveyor(mouth, far)


		c.set_outlet_held(true)
		outs.append(c)
	line ["outs"] = outs
	var built: Array [String] = []
	for side in ConveyorCompactSplitter.OUTPUTS:
		var c: Conveyor = outs [side]
		built.append("door %d %s" % [side + 1,
			"%.1f m" % c.path_length() if c != null else "bare"])
	print("  splitter at %s, feed %.1f m from %s, %s" % [centre.snappedf(0.1),
		(line ["feed"] as BeltPath).path_length(),
		((line ["lead"] if line ["lead"] != null else line ["feed"]) as Conveyor).a.snappedf(0.1),
		", ".join(built)])
	return line


func _feed(feed: Conveyor, ids: Array, seconds: float, line: Dictionary,
		shot: String, at:= -1.0, then:= Callable()) -> void:
	var head: Conveyor = line.get("lead") if line.get("lead") != null else feed
	var spawn_at:= head.a + head.forward * 0.6 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(head.forward.x, head.forward.z)
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var t:= 0.0
	var next:= 0.0
	var fed:= 0
	var shot_mid:= false
	var fired:= false
	while t < seconds:
		if not fired and at >= 0.0 and t >= at:
			fired = true
			then.call()
		if fed < ids.size() and t >= next:
			world.props.spawn(ids [fed], Transform3D(Basis(Vector3.UP, yaw), spawn_at))
			fed += 1
			next += GAP
		if not shot_mid and t >= seconds * 0.45:
			shot_mid = true
			await _shoot(line ["centre"], "%s_mid" % shot)
		await get_tree().physics_frame
		t += step
	await _shoot(line ["centre"], "%s_end" % shot)
	print("  fed %d of %d, yard holds %d props of a cap of %d"
		% [fed, ids.size(), world.props.items.size(), Cfg.prop_cap])
	_report_loose(line ["centre"])


func _dumped_near(centre: Vector3, radius: float) -> int:
	var n:= 0
	for item in world.props.items:
		if not is_instance_valid(item) or BeltPath.is_rider(item):
			continue
		var at: Vector3 = item.global_position
		if Vector2(at.x - centre.x, at.z - centre.z).length() < radius:
			n += 1
	return n


func _loose_near(centre: Vector3, radius: float) -> int:
	var n:= 0
	for item in world.props.items:
		if is_instance_valid(item):
			var at: Vector3 = item.global_position
			if Vector2(at.x - centre.x, at.z - centre.z).length() < radius and at.y < 0.6:
				n += 1
	return n


func _report_loose(centre: Vector3) -> void:
	var loose: Array [String] = []
	for item in world.props.items:
		if not is_instance_valid(item):
			continue
		var at: Vector3 = item.global_position
		if Vector2(at.x - centre.x, at.z - centre.z).length() < 12.0 and at.y < 0.35:
			loose.append("%s at %s" % [item.item_id, at.snappedf(0.1)])
	if not loose.is_empty():
		print("  LOOSE ON THE FLOOR: %s" % [loose])


func _watch(s: ConveyorCompactSplitter) -> Array:
	var counts:= [{ }, { }, { }]
	for side in ConveyorCompactSplitter.OUTPUTS:
		var route:= s.route(side)
		route.handed_on_record.connect(func(_seq: int, kind: int, _n: int) -> void:
			counts [side] [kind] = int(counts [side].get(kind, 0)) + 1)
		route.handed_on.connect(func(body: RigidBody3D) -> void:
			var kind:= BeltPath.record_kind(body)
			counts [side] [kind] = int(counts [side].get(kind, 0)) + 1)
	return counts


func _shoot(centre: Vector3, name: String) -> void:
	if _out_dir == "" or DisplayServer.get_name() == "headless":
		return
	var eye:= centre + Vector3(-5.5, 4.5, -5.5)
	player.global_position = eye
	var flat:= Vector3(centre.x - eye.x, 0.0, centre.z - eye.z)
	player.look_at_from_position(eye, eye + flat, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = atan2(centre.y - eye.y, flat.length())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out_dir, name])


static func _many(id: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(id)
	return out


static func _aboard(path: BeltPath) -> int:
	return path.riders().size() + path.run.count() if path != null else 0


func _out_kinds(line: Dictionary) -> Array:
	var out: Array = []
	for c: Conveyor in line ["outs"]:
		var kinds:= { }
		if c == null:
			out.append(kinds)
			continue
		for i in range(c.run.first(), c.run.first() + c.run.count()):
			var kind:= c.run.kind_of(i)
			kinds [kind] = int(kinds.get(kind, 0)) + 1
		for r in c.riders():
			var kind:= BeltPath.record_kind(r)
			kinds [kind] = int(kinds.get(kind, 0)) + 1
		out.append(kinds)
	var s: ConveyorCompactSplitter = line ["splitter"]
	var on_routes: Array = []
	for route in s.routes():
		on_routes.append(_aboard(route))
	print("  output belts hold %s, splitter routes hold %s, feed holds %d"
		% [out, on_routes, _aboard(line ["feed"])])
	return out


func _out_totals(line: Dictionary) -> Array:
	return _door_totals(_out_kinds(line))


static func _door_totals(counts: Array) -> Array:
	var out: Array = []
	for door: Dictionary in counts:
		var n:= 0
		for k in door:
			n += int(door [k])
		out.append(n)
	return out


static func _sum(values: Array) -> int:
	var n:= 0
	for v in values:
		n += int(v)
	return n


static func _only(door: Dictionary, kind: int, n: int) -> bool:
	return door.size() == 1 and int(door.get(kind, 0)) == n


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
