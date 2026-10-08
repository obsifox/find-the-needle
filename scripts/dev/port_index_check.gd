extends RefCounted


const NUDGES: Array [Vector3] = [Vector3.ZERO, Vector3(0.004, 0.0, 0.0),
	Vector3(0.0, 0.0, -0.009), Vector3(0.02, 0.0, 0.0), Vector3(0.3, 0.0, 0.2),
	Vector3(0.0, 0.5, 0.0)]
const SAMPLES:= 400

var checked:= 0
var fails:= 0
var b: BuildManager
var tool: BuildTool
var _said:= 0


func run(world: Node3D, build_tool: BuildTool) -> int:
	b = world.builds
	tool = build_tool
	tool.set_mode(BuildTool.Mode.CONVEYOR)
	var base:= _ports()
	var points:= _around(base)
	print("PORTCHECK: %d ports, %d query points; %d conveyors, %d splitters, %d joiners, %d buildings"
		% [base.size(), points.size(), b.conveyors.size(), b.splitters.size(),
			b.joiners.size(), b.all_buildings().size()])
	var t:= Time.get_ticks_msec()
	_compare(points, "standing yard")
	print("PORTCHECK: standing yard compared in %.1f s" % ((Time.get_ticks_msec() - t) / 1000.0))
	await _changes(world)
	b.ghost_reading = false
	print("PORTCHECK: %d comparisons, %d differ  %s" % [checked, fails, "PASS" if fails == 0 else "FAIL"])
	return fails


func _ports() -> PackedVector3Array:
	b.ghost_reading = false
	var out:= PackedVector3Array()
	for c in b.conveyors:
		if is_instance_valid(c):
			out.append(c.a)
			out.append(c.b)
	for m: Dictionary in b._wye_mouths():
		out.append(m ["point"])
	for s in b.splitters:
		if is_instance_valid(s):
			out.append_array(PackedVector3Array(s.ports()))
			if s is ConveyorTSplitter:
				for lane in ConveyorTSplitter.LANES:
					out.append(s.to_global((s as ConveyorTSplitter).mouth_of(lane)))
	for j in b.joiners:
		if is_instance_valid(j):
			out.append_array(PackedVector3Array(j.ports()))
	var through: Array [Array] = [b.scanners, b.compressors, b.pulpers, b.papers,
		b.hay_lifts, b.wrappers, b.silos]
	for list: Array in through:
		for m: Node3D in list:
			if is_instance_valid(m):
				out.append(m.call("port_in"))
				out.append(m.call("port_out"))
	for press in b.briquette_presses:
		if is_instance_valid(press):
			out.append_array(PackedVector3Array([press.port_wad(), press.port_brick(), press.port_out()]))
	var termini: Array [Array] = [b.pelletizers, b.generators, b.tube_launchers]
	for list: Array in termini:
		for m: Node3D in list:
			if is_instance_valid(m):
				out.append(m.call("intake_port"))
	for tower in b.hay_stairs:
		if is_instance_valid(tower):
			out.append(tower.outfeed_port())
	if b.stand != null and is_instance_valid(b.stand) and b.stand.is_inside_tree():
		out.append(b.stand.belt_entry_point())
	return out


func _around(base: PackedVector3Array) -> PackedVector3Array:
	var out:= PackedVector3Array()
	var lo:= Vector3.INF
	var hi:= - Vector3.INF
	for p in base:
		lo = lo.min(p)
		hi = hi.max(p)
		for n in NUDGES:
			out.append(p + n)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 20260921
	for i in SAMPLES:
		out.append(Vector3(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y),
			rng.randf_range(lo.z, hi.z)))
	return out


func _compare(points: PackedVector3Array, where: String) -> void:
	var spec: Dictionary = tool._seat_spec(BuildTool.Mode.COMPRESSOR)
	b.ghost_reading = false
	var walked: Array = b._wye_mouths().duplicate(true)
	b.ghost_reading = true
	_same(where, "_wye_mouths", Vector3.ZERO, walked, b._wye_mouths())
	for p in points:
		var near: Conveyor = null
		b.ghost_reading = false
		var at_end:= b.runs_ending_at(p) + b.runs_starting_at(p)
		if not at_end.is_empty():
			near = at_end [0]
		var questions:= {
			"port_bearing_at": func() -> Variant: return b.port_bearing_at(p),
			"intake_at": func() -> Variant: return b.intake_at(p),
			"t_mouth_out": func() -> Variant: return b.t_mouth_out(p),
			"generator_at_port": func() -> Variant: return b.generator_at_port(p),
			"wye_mated_at": func() -> Variant: return b.wye_mated_at(p),
			"wye_mouth_taken": func() -> Variant: return b.wye_mouth_taken(p),
			"wye_mouth_taken ignoring": func() -> Variant: return b.wye_mouth_taken(p, near),
			"port_has_run": func() -> Variant: return b.port_has_run(p),
			"port_has_run ignoring": func() -> Variant: return b.port_has_run(p, near),
			"feed_run_into": func() -> Variant: return b.feed_run_into(p),
			"run_out_of": func() -> Variant: return b.run_out_of(p),
			"joint_full": func() -> Variant: return b.joint_full(p),
			"joint_full ignoring": func() -> Variant: return b.joint_full(p, near),
			"runs_ending_at": func() -> Variant: return b.runs_ending_at(p),
			"runs_starting_at": func() -> Variant: return b.runs_starting_at(p),
			"_mouth_count": func() -> Variant: return b._mouth_count(p),
			"snap_splitter_port": func() -> Variant: return b.snap_splitter_port(p),
			"snap_joiner_port": func() -> Variant: return b.snap_joiner_port(p),
			"snap_endpoint": func() -> Variant: return b.snap_endpoint(p),
			"free_line_joints": func() -> Variant: return b.free_line_joints(p, Cfg.COMPRESSOR_SNAP_RADIUS),
			"nearest_wye_joint": func() -> Variant: return b.nearest_wye_joint(p, 1.0),
			"nearest_wye_outlet": func() -> Variant: return b.nearest_wye_outlet(p, 1.0),
			"tool _free_tail": func() -> Variant: return tool._free_tail(p),
			"tool _free_intake": func() -> Variant: return tool._free_intake(p),
			"tool _joint_taken leaving": func() -> Variant: return tool._joint_taken(p, true),
			"tool _joint_taken arriving": func() -> Variant: return tool._joint_taken(p, false),
			"tool _port_knees": func() -> Variant: return tool._port_knees(p, p + Vector3(2.0, 0.0, 0.5)),
			"tool _run_cost": func() -> Variant: return tool._run_cost(p, p + Vector3(2.0, 0.0, 0.5)),
			"tool _seat_on_line": func() -> Variant: return tool._seat_on_line(p, Cfg.COMPRESSOR_SNAP_RADIUS, spec),
		}
		for q: String in questions:
			var ask: Callable = questions [q]
			b.ghost_reading = false
			var walked_answer: Variant = ask.call()
			b.ghost_reading = true
			var table_answer: Variant = ask.call()
			_same(where, q, p, walked_answer, table_answer)
	b.ghost_reading = false


func _same(where: String, q: String, p: Vector3, walked: Variant, table: Variant) -> void:
	checked += 1
	if typeof(walked) == typeof(table) and walked == table:
		return
	fails += 1
	if _said < 25:
		_said += 1
		print("PORTCHECK FAIL (%s) %s at %v: walk %s, table %s" % [where, q, p, str(walked), str(table)])


func _changes(world: Node3D) -> void:
	var tree:= world.get_tree()
	var reversed:= 0
	for c in b.conveyors.duplicate():
		if reversed >= 3 or not is_instance_valid(c):
			continue
		_compare(_around(PackedVector3Array([c.a, c.b])), "before reversing")
		if b.reverse_conveyor(c):
			reversed += 1
			_compare(_around(PackedVector3Array([c.a, c.b])), "after reversing %s" % c.name)
			b.reverse_conveyor(c)
			_compare(_around(PackedVector3Array([c.a, c.b])), "reversed back %s" % c.name)
	print("PORTCHECK: %d runs reversed and back" % reversed)
	var turned:= 0
	for s in b.splitters:
		if turned >= 3 or not (s is ConveyorTSplitter) or not is_instance_valid(s):
			continue
		var t:= s as ConveyorTSplitter
		var was:= t.entry
		var here:= PackedVector3Array(t.ports())
		_compare(_around(here), "before turning")
		t.set_entry((was + 1) % 3)
		_compare(_around(here), "T splitter %s entry %d" % [t.name, t.entry])
		t.set_entry(was)
		_compare(_around(here), "T splitter %s entry back" % t.name)
		turned += 1
	for j in b.joiners:
		if turned >= 6 or not (j is ConveyorTJoiner) or not is_instance_valid(j):
			continue
		var tj:= j as ConveyorTJoiner
		var was_out:= tj.out_lane
		var at:= PackedVector3Array(tj.ports())
		_compare(_around(at), "before turning")
		tj.set_out((was_out + 1) % 3)
		_compare(_around(at), "T joiner %s outlet %d" % [tj.name, tj.out_lane])
		tj.set_out(was_out)
		_compare(_around(at), "T joiner %s outlet back" % tj.name)
		turned += 1
	print("PORTCHECK: %d T pieces turned and back" % turned)

	var from:= Vector3(-46.0, 0.43, 34.0)
	var to:= from + Vector3(6.0, 0.0, 0.0)
	var spot:= _around(PackedVector3Array([from, to]))
	_compare(spot, "before laying")
	var laid:= b.add_conveyor(from, to)
	_compare(spot, "after laying")
	b.demolish(laid)
	_compare(spot, "after dismantling, same frame")
	await tree.process_frame
	await tree.process_frame
	_compare(spot, "after dismantling, two frames on")
