extends RefCounted


const NUDGES: Array [Vector3] = [Vector3.ZERO, Vector3(0.004, 0.0, 0.0),
	Vector3(0.0, 0.0, -0.009), Vector3(0.3, 0.0, 0.2), Vector3(1.1, 0.0, -0.4),
	Vector3(0.0, 0.5, 0.0), Vector3(-2.2, 0.0, 1.3)]
const SAMPLES:= 300

var checked:= 0
var fails:= 0
var b: BuildManager
var _said:= 0


func run(world: Node3D, _tool: BuildTool) -> int:
	b = world.builds
	var points:= _points()
	print("MEMOCHECK: %d query points; %d flanges, %d wyes, %d arms, %d poles, %d machines on the grid"
		% [points.size(), b._flanges().size(), b.splitters.size() + b.joiners.size(),
			b.robotic_arms.size(), b.power_poles.size(), b.grid.machines().size()])
	_compare(points, "standing yard")
	_compare_grid("standing yard")
	await _changes(world)
	b.ghost_reading = false
	BuildManager.yard_memo_enabled = true
	print("MEMOCHECK: %d comparisons, %d differ  %s" % [checked, fails, "PASS" if fails == 0 else "FAIL"])
	return fails


func _points() -> PackedVector3Array:
	var base:= PackedVector3Array()
	b.ghost_reading = false
	for entry: Array in b._flanges():
		if is_instance_valid(entry [1]):
			base.append((entry [1] as Node3D).global_position)
	for list: Array in [b.splitters, b.joiners]:
		for wye: Node3D in list:
			if is_instance_valid(wye):
				for d: Vector4 in wye.call("footprint"):
					base.append(Vector3(d.x, d.y, d.z))
	for arm in b.robotic_arms:
		if is_instance_valid(arm):
			base.append(arm.global_position)
	var out:= PackedVector3Array()
	var lo:= Vector3(-40, 0, -40)
	var hi:= Vector3(40, 3, 40)
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
	for p in points:
		var near_wye: Node3D = null
		if not b.splitters.is_empty():
			near_wye = b.splitters [0]
		var questions:= {
			"nearest_flange": func() -> Variant: return b.nearest_flange(p),
			"nearest_flange 2 m": func() -> Variant: return b.nearest_flange(p, 2.0),
			"water_ports_at": func() -> Variant: return b.water_ports_at(p),
			"flange_owner": func() -> Variant: return b.flange_owner(p),
			"flange_owner 1 m": func() -> Variant: return b.flange_owner(p, 1.0),
			"water_port_bearing_at": func() -> Variant: return b.water_port_bearing_at(p),
			"water_port_taken": func() -> Variant: return b.water_port_taken(p),
			"snap_water_endpoint": func() -> Variant: return b.snap_water_endpoint(p),
			"wye_overlap Y disc": func() -> Variant:
				return b.wye_overlap([Vector4(p.x, p.y, p.z, Cfg.SPLITTER_PORT_R)] as Array [Vector4]),
			"wye_overlap U discs": func() -> Variant:
				return b.wye_overlap([Vector4(p.x, p.y, p.z, 0.7), Vector4(p.x + 1.5, p.y, p.z, 0.7),
					Vector4(p.x, p.y, p.z + 1.2, 0.55)] as Array [Vector4]),
			"wye_overlap ignoring": func() -> Variant:
				return b.wye_overlap([Vector4(p.x, p.y, p.z, 1.0)] as Array [Vector4], near_wye),
		}
		for tier in Cfg.ROBOT_ARM_TIERS.size():
			questions ["arm_reach_conflict tier %d" % tier] = func() -> Variant:
				return b.arm_reach_conflict(p, tier)
		for q: String in questions:
			var ask: Callable = questions [q]
			b.ghost_reading = true
			BuildManager.yard_memo_enabled = false
			var walked: Variant = ask.call()
			BuildManager.yard_memo_enabled = true
			var kept: Variant = ask.call()
			b.ghost_reading = false
			_same(where, q, p, walked, kept)

	for node: Node in b.get_children():
		BuildManager.yard_memo_enabled = false
		var walked: Array = PowerGrid.own_bodies(node)
		BuildManager.yard_memo_enabled = true
		var kept: Array = PowerGrid.own_bodies(node)
		_same(where, "own_bodies " + node.name, Vector3.ZERO, walked, kept)
	BuildManager.yard_memo_enabled = false
	var machines_walked:= b.grid.machines()
	BuildManager.yard_memo_enabled = true
	_same(where, "grid.machines", Vector3.ZERO, machines_walked, b.grid.machines())


func _compare_grid(where: String) -> void:
	BuildManager.yard_memo_enabled = false
	b.grid.rebuild()
	var walked:= _grid_state()
	var survey_walked:= _attach_state()
	BuildManager.yard_memo_enabled = true
	b.grid.rebuild()
	var kept:= _grid_state()
	for key: String in walked:
		_same(where, "grid " + key, Vector3.ZERO, walked [key], kept.get(key))
	_same(where, "grid attach", Vector3.ZERO, survey_walked, _attach_state())


	b.grid.rebuild()
	var again:= _grid_state()
	for key: String in walked:
		_same(where, "grid again " + key, Vector3.ZERO, walked [key], again.get(key))


func _grid_state() -> Dictionary:
	var grid:= b.grid
	var poles:= { }
	var wires:= { }
	for pole in b.power_poles:
		if not is_instance_valid(pole):
			continue
		poles [pole.name] = grid.network_of(pole)
		var mine: Array = []
		for w: Node3D in pole._wires:
			if w is CableTrace:
				mine.append((w as CableTrace).points())
			elif w is PowerLine:
				mine.append([_names((w as PowerLine).from_anchors), _names((w as PowerLine).to_anchors)])
		wires [pole.name] = mine
	var links:= { }
	for machine in grid.machines():
		var rec: Dictionary = grid._link.get(machine.get_instance_id(), { })
		links [machine.name] = [] if rec.is_empty() else [(rec ["pole"] as Node).name,
			(rec ["port"] as Node).name, rec ["length"], rec ["net"], grid.network_of(machine)]
	var unreachable: Array = []
	for m in grid.unreachable():
		unreachable.append(m.name)
	var nets: Array = []
	for net: Dictionary in grid._nets:
		nets.append([_names(net ["poles"]), _names(net ["machines"])])
	var feeders: Array = []
	for machine in grid.machines():
		if grid.is_feeder(machine):
			feeders.append(machine.name)
	return { "poles": poles, "wires": wires, "links": links, "unreachable": unreachable,
		"nets": nets, "feeders": feeders }


func _attach_state() -> Array:
	var poles: Array [PowerPole] = b.grid._poles()
	var survey: Dictionary = b.grid.attach(poles)
	var found: Array = []
	for rec: Dictionary in (survey ["found"] as Dictionary).values():
		found.append([(rec ["machine"] as Node).name, (rec ["pole"] as Node).name,
			(rec ["port"] as Node).name, rec ["length"]])
	return [found, _names(survey ["unreachable"])]


static func _names(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		out.append((n as Node).name if is_instance_valid(n) else "<freed>")
	return out


func _same(where: String, q: String, p: Vector3, walked: Variant, kept: Variant) -> void:
	checked += 1
	if typeof(walked) == typeof(kept) and walked == kept:
		return
	fails += 1
	if _said < 25:
		_said += 1
		print("MEMOCHECK FAIL (%s) %s at %v: walk %s, memo %s" % [where, q, p, str(walked), str(kept)])


func _changes(world: Node3D) -> void:
	var tree:= world.get_tree()


	var site:= Vector3(4.0, 0.0, 4.0)
	var ms:= b.grid.machines()
	if not ms.is_empty():
		site = ms [0].global_position + Vector3(3.0, 0.0, 2.5)
	var around:= PackedVector3Array()
	for n in NUDGES:
		around.append(site + n)
	var fill:= func() -> void:
		b.ghost_reading = true
		b._flanges()
		b._wye_footprints()
		b._module_keepouts()
		b.ghost_reading = false
		b.grid.machines()
		for node: Node in b.get_children():
			PowerGrid.own_bodies(node)
	for kind: String in ["pole", "box", "belt", "main", "arm", "u splitter"]:
		fill.call()
		var made: Node3D = null
		match kind:
			"pole":
				made = b.add_power_pole(site, 0.0)
			"box":
				made = b.add_power_pole(site + Vector3(1.0, 0.0, 0.0), 0.0, true)
			"belt":
				made = b.add_conveyor(site + Vector3(0, 0.43, 0), site + Vector3(5.0, 0.43, 0.0))
			"main":
				made = b.add_water_main(site + Vector3(0, 0.6, 1.0), site + Vector3(4.0, 0.6, 1.0))
			"arm":
				made = b.add_robotic_arm(site + Vector3(-2.0, 0.0, -2.0), 0.0)
			"u splitter":
				made = b.add_u_splitter(site + Vector3(0, 0.43, -3.0), 0.0)
		if made == null:
			print("MEMOCHECK: could not put down a %s at %v" % [kind, site])
			continue
		_compare(around, "after a %s" % kind)
		_compare_grid("after a %s" % kind)
		fill.call()
		b.demolish(made)
		_compare(around, "after dismantling a %s, same frame" % kind)
		await tree.process_frame
		await tree.process_frame
		_compare(around, "after dismantling a %s, two frames on" % kind)
		_compare_grid("after dismantling a %s" % kind)
	print("MEMOCHECK: six kinds put down and taken away")
