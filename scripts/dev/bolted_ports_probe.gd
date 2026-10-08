class_name DevBoltedPortsProbe
extends Node


var world: Node3D
var player: Player


const BASE:= Vector3(-13.0, 6.0, -1.0)
const RUN_LEN:= 2.0
const LIFT_SECTIONS:= 2
const STRANDS:= 60

const MEET:= 0.002

const JOINT_R:= 1.2
const SETTLE_TICKS:= 3


const WATCH_TICKS:= 150

const OUTLET_KINDS: Array [String] = ["conveyor", "enclosed", "splitter", "u_splitter",
	"t_splitter", "compact", "smart", "joiner", "u_joiner", "t_joiner", "scanner",
	"compressor", "pulper", "paper", "briquette", "wrapper", "silo", "lift", "stairs"]
const INLET_KINDS: Array [String] = ["conveyor", "enclosed", "splitter", "u_splitter",
	"t_splitter", "compact", "smart", "joiner", "u_joiner", "t_joiner", "scanner",
	"compressor", "pulper", "paper", "briquette", "wrapper", "silo", "pelletizer",
	"generator", "launcher", "lift", "stand"]


const MENU:= {
	"splitter": [BuildTool.Mode.SPLITTER, "_splitter_ghost"],
	"u_splitter": [BuildTool.Mode.U_SPLITTER, "_u_splitter_ghost"],
	"t_splitter": [BuildTool.Mode.T_SPLITTER, "_t_splitter_ghost"],
	"compact": [BuildTool.Mode.COMPACT_SPLITTER, "_compact_splitter_ghost"],
	"smart": [BuildTool.Mode.SMART_SPLITTER, "_smart_splitter_ghost"],
	"joiner": [BuildTool.Mode.JOINER, "_joiner_ghost"],
	"u_joiner": [BuildTool.Mode.U_JOINER, "_u_joiner_ghost"],
	"scanner": [BuildTool.Mode.SCANNER, "_scanner_ghost"],
	"compressor": [BuildTool.Mode.COMPRESSOR, "_compressor_ghost"],
	"pulper": [BuildTool.Mode.PULPER, "_pulper_ghost"],
	"paper": [BuildTool.Mode.PAPER, "_paper_ghost"],
	"briquette": [BuildTool.Mode.BRIQUETTE, "_briquette_ghost"],
	"wrapper": [BuildTool.Mode.WRAPPER, "_wrapper_ghost"],
	"silo": [BuildTool.Mode.SILO, "_silo_ghost"],
	"pelletizer": [BuildTool.Mode.PELLETIZER, "_pelletizer_ghost"],
	"generator": [BuildTool.Mode.GENERATOR, "_generator_ghost"],
	"launcher": [BuildTool.Mode.LAUNCHER, "_launcher_ghost"],
	"lift": [BuildTool.Mode.HAY_LIFT, "_lift_ghost"],
	"stairs": [BuildTool.Mode.HAY_STAIRS, "_stairs_ghost"],
}

const MENU_FLOOR:= Vector3(-13.0, 0.0, -1.0)


const PRODUCT:= { "compressor": "hay_bale", "wrapper": "foiled_bale",
	"pulper": "hay_pulp", "paper": "paper_roll", "briquette": "feed_disc" }

var _only:= ""
var _link_only:= false

var _geom:= { }

var _control:= { }
var _props_before:= { }
var _thrown:= 0

var _grid:= { }
var _failures: Array [String] = []


var _went_through: Array [String] = []
var _pairs:= 0
var _linked:= 0
var _held:= 0
var _place_fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--only")
	if i >= 0 and i + 1 < ua.size():
		_only = ua [i + 1]
	_link_only = "--linkonly" in ua


	Tech.ranks ["belt_speed"] = TechTree.max_rank("belt_speed")
	for k in 30:
		await get_tree().physics_frame
	_props_before = _snapshot_props()
	print("BOLTED: belt speed %.2f m/s, %d outlet kinds, %d inlet kinds%s%s" % [
		Tech.belt_speed(), OUTLET_KINDS.size(), INLET_KINDS.size(),
		", only '%s'" % _only if _only != "" else "", ", link only" if _link_only else ""])

	var outlets:= _outlet_names()
	var inlets:= _inlet_names()

	if "--menu" in ua:
		await _run_menu(outlets, inlets)
		return
	if "--gridreport" in ua:
		_grid_report(outlets, inlets)
		return

	if not _link_only:
		print("\n=== control: each outlet with nothing in front of it must throw ===")
		for o: Array in outlets:


			var needed:= false
			for n: Array in inlets:
				needed = needed or _wanted(_name(o), _name(n))
			if not needed:
				continue
			await _run_control(o)

	print("\n=== pairs ===")
	for o: Array in outlets:
		for n: Array in inlets:
			if not _wanted(_name(o), _name(n)):
				continue
			await _run_pair(o, n)

	_report(outlets, inlets)


func _outlet_names() -> Array:
	var out:= []
	for kind in OUTLET_KINDS:
		var node:= _make_at_base(kind)
		for o: Dictionary in _outlets_of(kind, node):
			out.append([kind, String(o ["label"])])
		_clear_yard()
	return out


func _inlet_names() -> Array:
	var out:= []
	for kind in INLET_KINDS:
		match kind:
			"conveyor", "enclosed", "splitter", "u_splitter", "t_splitter", "compact", "smart", "t_joiner", "stand":
				out.append([kind, "in"])
			"joiner", "u_joiner":
				out.append([kind, "L"])
				out.append([kind, "R"])
			"briquette":
				out.append([kind, "wad"])
				out.append([kind, "brick"])
			_:
				out.append([kind, "in"])
	return out


static func _name(pair: Array) -> String:
	return "%s.%s" % [pair [0], pair [1]]


func _wanted(a: String, b: String) -> bool:
	return _only == "" or a.contains(_only) or b.contains(_only)


static func _side_name(side: int) -> String:
	if side == ConveyorSplitter.LEFT:
		return "L"
	if side == ConveyorSplitter.RIGHT:
		return "R"
	return "door%d" % side


func _outlets_of(kind: String, node: Node3D) -> Array:
	var out:= []
	if node == null:
		return out
	match kind:
		"conveyor", "enclosed":
			var c:= node as Conveyor
			out.append({ "label": "out", "port": c.b, "dir": _dir_at(c, c.b), "path": c })
		"splitter", "u_splitter", "t_splitter", "compact", "smart":
			var sp:= node as ConveyorSplitter
			if sp == null:
				return out
			for side: int in sp.output_sides():
				var r: BeltPath = sp.route(side)
				if r != null:
					out.append({ "label": _side_name(side), "port": sp.port(side),
						"dir": _dir_at(r, sp.port(side)), "path": r })
		"joiner", "u_joiner", "t_joiner":
			var j:= node as ConveyorJoiner
			if j == null:
				return out
			out.append({ "label": "out", "port": j.port_out(),
				"dir": _dir_at(j.out_path(), j.port_out()), "path": j.out_path() })
		"pulper", "paper", "briquette", "lift":
			var p: BeltPath = node.call("outfeed_deck")
			var at: Vector3 = node.call("port_out")
			out.append({ "label": "out", "port": at, "dir": _dir_at(p, at), "path": p })
		"stairs":
			var st:= node as HayStairs
			out.append({ "label": "out", "port": st.outfeed_port(),
				"dir": _dir_at(st.deck(), st.outfeed_port()), "path": st.deck() })
		_:
			var d: BeltPath = node.call("deck")
			var at: Vector3 = node.call("port_out")
			out.append({ "label": "out", "port": at, "dir": _dir_at(d, at), "path": d })
	return out


func _inlet_of(kind: String, label: String, node: Node3D) -> Dictionary:
	if node == null:
		return { }
	match kind:
		"conveyor", "enclosed":
			var c:= node as Conveyor
			return { "port": c.a, "dir": _dir_at(c, c.a), "accepts": [c] }
		"splitter", "u_splitter", "t_splitter", "compact", "smart":
			var sp:= node as ConveyorSplitter
			if sp == null:
				return { }
			var routes:= []
			for side: int in sp.output_sides():
				if sp.route(side) != null:
					routes.append(sp.route(side))
			var first: BeltPath = sp.route(sp.next_side)
			return { "port": sp.port_in(), "dir": _dir_at(first, sp.port_in()), "accepts": routes }
		"joiner", "u_joiner":
			var j:= node as ConveyorJoiner
			if j == null:
				return { }
			var side:= ConveyorJoiner.LEFT if label == "L" else ConveyorJoiner.RIGHT
			return { "port": j.port(side), "dir": _dir_at(j.arm(side), j.port(side)),
				"accepts": [j.arm(side)] }
		"t_joiner":


			var r:= float(node.get("port_r"))
			var mouth:= node.to_global(ConveyorTSplitter.lane_mouth(ConveyorTSplitter.BAR_POS, r))
			var inward:= - (node.global_basis * ConveyorTSplitter.lane_out(ConveyorTSplitter.BAR_POS))
			inward.y = 0.0
			var arms:= []
			var tj:= node as ConveyorTJoiner
			if tj != null:
				for side: int in ConveyorJoiner.SIDES:
					if tj.inlet(side) == ConveyorTSplitter.BAR_POS:
						arms.append(tj.arm(side))
			return { "port": mouth, "dir": inward.normalized(), "accepts": arms }
		"briquette":
			var bp:= node as BriquettePress
			var at:= bp.port_wad() if label == "wad" else bp.port_brick()
			var d:= bp.wad_deck() if label == "wad" else bp.brick_deck()
			return { "port": at, "dir": _dir_at(d, at), "accepts": [d] }
		"silo":
			var s:= node as HaySilo
			return { "port": s.port_in(), "dir": _dir_at(s.feed_deck(), s.port_in()),
				"accepts": [s.feed_deck()] }
		"pelletizer", "generator", "launcher":
			var d: BeltPath = node.call("deck")
			var at: Vector3 = node.call("intake_port")
			return { "port": at, "dir": _dir_at(d, at), "accepts": [d] }
		"stand":
			var st:= node as HaySellingStand
			var ip:= st.intake_path()
			return { "port": st.belt_entry_point(), "dir": _dir_at(ip, st.belt_entry_point()),
				"accepts": [ip] }
		_:
			var d: BeltPath = node.call("deck")
			var at: Vector3 = node.call("port_in")
			return { "port": at, "dir": _dir_at(d, at), "accepts": [d] }


static func _dir_at(path: BeltPath, point: Vector3) -> Vector3:
	if path == null or path._line.size() < 2:
		return Vector3.ZERO
	var s:= float(path._nearest(point) ["s"])
	var d: Vector3 = path._basis_at(s).z
	d.y = 0.0
	return d.normalized()


static func _heading(v: Vector3) -> float:
	return atan2(v.x, v.z)


func _make(kind: String, at: Vector3, yaw: float) -> Node3D:
	var b: BuildManager = world.builds
	match kind:
		"splitter":
			return b.add_splitter(at, yaw)
		"u_splitter":
			return b.add_u_splitter(at, yaw)
		"t_splitter":
			return b.add_t_splitter(at, yaw)
		"compact":
			return b.add_compact_splitter(at, yaw)
		"smart":
			return b.add_compact_splitter(at, yaw, true)
		"joiner":
			return b.add_joiner(at, yaw)
		"u_joiner":
			return b.add_u_joiner(at, yaw)
		"t_joiner":
			return _make_t_joiner(at, yaw)
		"scanner":
			return b.add_scanner(at, yaw)
		"compressor":
			return b.add_compressor(at, yaw)
		"pulper":
			return b.add_pulper(at, yaw)
		"paper":
			return b.add_paper(at, yaw)
		"briquette":
			return b.add_briquette(at, yaw)
		"wrapper":
			return b.add_wrapper(at, yaw)
		"silo":
			return b.add_silo(at, yaw)
		"pelletizer":
			return b.add_pelletizer(at, yaw)
		"generator":
			return b.add_generator(at, yaw)
		"launcher":
			return b.add_tube_launcher(at, yaw)
		"lift":
			return b.add_hay_lift(at, yaw, LIFT_SECTIONS)
		"stairs":
			return b.add_hay_stairs(at, yaw)
	return null


func _make_t_joiner(at: Vector3, yaw: float) -> Node3D:
	var b: BuildManager = world.builds
	var t:= b.add_t_splitter(at, yaw)
	for lane: int in [ConveyorTSplitter.BAR_POS, ConveyorTSplitter.BAR_NEG]:
		_feed_lane(t, lane)
	return _t_at(at)


func _feed_lane(t: Node3D, lane: int) -> void:
	var r:= float(t.get("port_r"))
	var mouth:= t.to_global(ConveyorTSplitter.lane_mouth(lane, r))
	var outward:= (t.global_basis * ConveyorTSplitter.lane_out(lane))
	outward.y = 0.0
	world.builds.add_conveyor(mouth + outward.normalized() * RUN_LEN, mouth)


func _t_at(at: Vector3) -> Node3D:
	for sp in world.builds.splitters:
		if is_instance_valid(sp) and sp is ConveyorTSplitter and sp.global_position.distance_to(at) < 0.01:
			return sp
	for j in world.builds.joiners:
		if is_instance_valid(j) and j is ConveyorTJoiner and j.global_position.distance_to(at) < 0.01:
			return j
	return null


func _t_near(p: Vector3, skip: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d:= 2.5
	var candidates: Array = []
	candidates.append_array(world.builds.splitters)
	candidates.append_array(world.builds.joiners)
	for node in candidates:
		if not is_instance_valid(node) or node == skip:
			continue
		if not (node is ConveyorTSplitter or node is ConveyorTJoiner):
			continue
		var d: float = (node as Node3D).global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = node
	return best


func _make_at_base(kind: String) -> Node3D:
	if kind == "conveyor" or kind == "enclosed":
		return _lay_run(kind, BASE - Vector3.BACK * RUN_LEN, BASE)
	return _make_outlet(kind, BASE, 0.0)


func _make_outlet(kind: String, at: Vector3, yaw: float) -> Node3D:
	var node:= _make(kind, at, yaw)
	if kind == "t_splitter" and node != null:
		_feed_lane(node, ConveyorTSplitter.STEM)
		node = _t_at(at)
	return node


func _lay_run(kind: String, from: Vector3, to: Vector3) -> Node3D:
	if kind == "enclosed":
		return world.builds.add_enclosed_conveyor(from, to)
	return world.builds.add_conveyor(from, to)


func _geometry(kind: String, label: String, inlet: bool) -> Dictionary:
	var key:= "%s|%s|%s" % [kind, label, "in" if inlet else "out"]
	if _geom.has(key):
		return _geom [key]
	var node: Node3D = null
	if inlet and kind == "t_joiner":
		node = world.builds.add_t_splitter(BASE, 0.0)
	else:
		node = _make_at_base(kind)
	var port:= Vector3.INF
	var dir:= Vector3.ZERO
	if inlet:
		var n:= _inlet_of(kind, label, node)
		if not n.is_empty():
			port = n ["port"]
			dir = n ["dir"]
	else:
		for o: Dictionary in _outlets_of(kind, node):
			if o ["label"] == label:
				port = o ["port"]
				dir = o ["dir"]
	_clear_yard()
	var g:= { "L": port - BASE, "D": dir }
	_geom [key] = g
	return g


func _place_so(kind: String, label: String, inlet: bool, p: Vector3, t: Vector3) -> Node3D:
	if kind == "conveyor" or kind == "enclosed":
		return _lay_run(kind, p, p + t * RUN_LEN) if inlet else _lay_run(kind, p - t * RUN_LEN, p)
	var g:= _geometry(kind, label, inlet)
	var d: Vector3 = g ["D"]
	if d == Vector3.ZERO:
		return null
	var yaw:= _heading(t) - _heading(d)
	var at: Vector3 = p - (g ["L"] as Vector3).rotated(Vector3.UP, yaw)
	if kind == "t_joiner" and inlet:
		var t_node: ConveyorTSplitter = world.builds.add_t_splitter(at, yaw)
		_feed_lane(t_node, ConveyorTSplitter.BAR_NEG)
		return _t_at(at)
	return _make(kind, at, yaw) if inlet else _make_outlet(kind, at, yaw)


func _clear_yard() -> void:
	var b: BuildManager = world.builds
	var lists: Array = [b.splitters, b.joiners, b.scanners, b.compressors, b.pulpers,
		b.papers, b.briquette_presses, b.wrappers, b.silos, b.pelletizers, b.generators,
		b.tube_launchers, b.hay_stairs, b.hay_lifts, b.conveyors]


	for pass_no in 4:
		var left:= 0
		for list: Array in lists:
			for node in list.duplicate():
				if is_instance_valid(node) and not node.is_queued_for_deletion():
					b.demolish(node)
					left += 1
		if left == 0:
			break
	for it in world.props.items.duplicate():
		if is_instance_valid(it) and not _props_before.has(it.get_instance_id()):
			world.props.remove(it)


	for list: Array in lists:
		for node in list:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				print("BOLTED: %s would not come down" % node.name)


func _on_thrown(_body: RigidBody3D) -> void:
	_thrown += 1


func _load_outlet(path: BeltPath, kind: String) -> int:
	var item: String = PRODUCT.get(kind, "hay_wad")
	var k:= BeltRun.ITEM_IDS.find(item)
	var total:= path.path_length()
	var rows: Array = []
	for back: float in [0.3, 0.9]:
		var s:= total - back
		if s < 0.05:
			continue
		rows.append({ "kind": k, "strands": STRANDS, "reach": 0.0, "s": s, "lift": 0.0,
			"speed": path.drive_speed, "state": { },
			"xform": path.run.pose_at(s, 0.0, 0.0).translated(Vector3.UP * 0.25) })
	var got: Vector2i = path.restore_records(rows, world.props)
	return got.x + got.y


func _loose_since(since: Dictionary) -> int:
	var n:= 0
	for it in world.props.items:
		if not is_instance_valid(it) or since.has(it.get_instance_id()):
			continue
		var rb:= it as RigidBody3D
		if rb != null and not BeltPath.is_rider(rb):
			n += 1
	return n


func _note_born(since: Dictionary, born: Dictionary) -> void:
	for it in world.props.items:
		if not is_instance_valid(it):
			continue
		var id: int = it.get_instance_id()
		if since.has(id) or born.has(id) or BeltPath.is_rider(it as RigidBody3D):
			continue
		born [id] = (it as Node3D).global_position


func _snapshot_props() -> Dictionary:
	var ids:= { }
	for it in world.props.items:
		if is_instance_valid(it):
			ids [it.get_instance_id()] = true
	return ids


func _run_control(o: Array) -> void:
	_clear_yard()
	var node:= _make_at_base(o [0])
	var spec:= _find_outlet(o [0], o [1], node)
	if spec.is_empty():
		print("  %-22s NOT BUILT" % _name(o))
		_control [_name(o)] = false
		return
	for k in SETTLE_TICKS:
		await get_tree().physics_frame
	var path: BeltPath = spec ["path"]
	var open:= path.downstream == null
	_thrown = 0
	path.handed_on.connect(_on_thrown)
	var loaded:= _load_outlet(path, o [0])


	var since:= _snapshot_props()
	for k in WATCH_TICKS:
		await get_tree().physics_frame
	var loose:= _loose_since(since)
	if is_instance_valid(path):
		path.handed_on.disconnect(_on_thrown)
	var throws:= _thrown > 0 or loose > 0
	_control [_name(o)] = throws
	print("  %-22s open end %s, loaded %d, thrown %d, loose %d  %s" % [_name(o),
		str(open), loaded, _thrown, loose,
		"throws, so HOLD is tested" if throws else "HOLDS ON ITS OWN, so HOLD is not tested"])
	_clear_yard()


func _find_outlet(kind: String, label: String, node: Node3D) -> Dictionary:
	for spec: Dictionary in _outlets_of(kind, node):
		if spec ["label"] == label:
			return spec
	return { }


func _run_pair(o: Array, n: Array) -> void:
	_clear_yard()
	_pairs += 1


	if n [0] == "stand":
		_geometry(o [0], o [1], false)
	elif n [0] != "conveyor" and n [0] != "enclosed":
		_geometry(n [0], n [1], true)
	var stand: HaySellingStand = world.builds.stand
	var out_node: Node3D = null
	var in_node: Node3D = null
	var spec:= { }
	var inlet:= { }
	if n [0] == "stand":
		if stand == null:
			_cell(o, n, "P", "no selling stand in this yard")
			return
		in_node = stand
		var fixed:= _inlet_of("stand", "in", stand)
		out_node = _place_so(o [0], o [1], false, fixed ["port"], fixed ["dir"])
		spec = _find_outlet(o [0], o [1], out_node)
		inlet = fixed
	else:
		out_node = _make_at_base(o [0])
		spec = _find_outlet(o [0], o [1], out_node)
		if spec.is_empty():
			_cell(o, n, "P", "the outlet was not built")
			return
		in_node = _place_so(n [0], n [1], true, spec ["port"], spec ["dir"])
		inlet = _inlet_of(n [0], n [1], in_node)
	for k in SETTLE_TICKS:
		await get_tree().physics_frame


	if not is_instance_valid(out_node) and not spec.is_empty() and (o [0] == "t_splitter" or o [0] == "t_joiner"):
		out_node = _t_near(spec ["port"], in_node if is_instance_valid(in_node) else null)
		spec = _find_outlet(o [0], o [1], out_node)
		if spec.is_empty():
			_cell(o, n, "K", "bolting the inlet on turned the outlet into another kind (%s)"
				% (String(out_node.name) if out_node != null else "gone"))
			return
	if n [0] == "t_joiner" and not spec.is_empty():
		in_node = _t_near(spec ["port"], out_node if is_instance_valid(out_node) else null)
		inlet = _inlet_of("t_joiner", "in", in_node)
	if spec.is_empty() or inlet.is_empty():
		_cell(o, n, "P", "not built")
		return
	var apart:= (spec ["port"] as Vector3).distance_to(inlet ["port"])
	var facing:= (spec ["dir"] as Vector3).angle_to(inlet ["dir"])
	if apart > MEET or facing > 0.02:
		_cell(o, n, "P", "the ports do not meet: %.4f m apart, %.1f deg off"
			% [apart, rad_to_deg(facing)])
		return

	var path: BeltPath = spec ["path"]
	var accepts: Array = inlet ["accepts"]
	var linked:= path.downstream != null and accepts.has(path.downstream)
	if linked:
		_linked += 1
	var onto:= "none" if path.downstream == null else String(path.downstream.name)

	if _link_only or not bool(_control.get(_name(o), false)):
		var why:= "" if linked else "not linked (downstream %s)" % onto
		_cell(o, n, "." if linked else "L", why)
		return


	if in_node.has_method("set_switched_off"):
		in_node.call("set_switched_off", true)
	for p: BeltPath in accepts:
		p.set_blocked(true)
	_thrown = 0
	path.handed_on.connect(_on_thrown)
	var loaded:= _load_outlet(path, o [0])
	var since:= _snapshot_props()
	var born:= { }
	for k in WATCH_TICKS:
		for p: BeltPath in accepts:
			if is_instance_valid(p) and not p.is_blocked():
				p.set_blocked(true)
		_note_born(since, born)
		await get_tree().physics_frame
	_note_born(since, born)


	var joint: Vector3 = spec ["port"]
	var loose:= 0
	var beyond:= 0
	for id in born:
		var it = instance_from_id(id)
		if not is_instance_valid(it) or BeltPath.is_rider(it as RigidBody3D):
			continue
		if (born [id] as Vector3).distance_to(joint) <= JOINT_R:
			loose += 1
		else:
			beyond += 1
	if is_instance_valid(path):
		path.handed_on.disconnect(_on_thrown)
	if in_node == stand:
		for p: BeltPath in accepts:
			p.set_blocked(false)
	if beyond > 0:
		_went_through.append("%-22s -> %-18s %d load(s) went through the shut inlet and left %s"
			% [_name(o), _name(n), beyond, "further down the line"])
	var holds:= _thrown == 0 and loose == 0
	if holds:
		_held += 1
	var code:= "."
	if not linked and not holds:
		code = "LT"
	elif not linked:
		code = "L"
	elif not holds:
		code = "T"
	var detail:= ""
	if not linked:
		detail += "not linked (downstream %s)" % onto
	if not holds:
		detail += "%sloaded %d, thrown %d, loose %d%s" % ["; " if detail != "" else "",
			loaded, _thrown, loose, _where_loose(since, spec ["port"])]
	_cell(o, n, code, detail)


func _where_loose(since: Dictionary, joint: Vector3) -> String:
	var out:= ""
	for it in world.props.items:
		if not is_instance_valid(it) or since.has(it.get_instance_id()):
			continue
		var rb:= it as RigidBody3D
		if rb == null or BeltPath.is_rider(rb):
			continue
		var d:= rb.global_position - joint
		out += "\n        %s at x %+.2f z %+.2f y %+.2f from the joint, %.2f m away, v %.1f%s" % [
			(it as Carryable).item_id, d.x, d.z, d.y, d.length(), rb.linear_velocity.length(),
			", frozen" if rb.freeze else ""]
	return out


func _cell(o: Array, n: Array, code: String, detail: String) -> void:
	var row: Dictionary = _grid.get(_name(o), { })
	row [_name(n)] = code
	_grid [_name(o)] = row
	if code == "P":
		_place_fails += 1
	if code != ".":
		_failures.append("%-22s -> %-18s %s  %s" % [_name(o), _name(n), code, detail])


var _menu_grid:= { }
var _menu_bolted: Array [String] = []
var _menu_refused: Array [String] = []


func _run_menu(outlets: Array, inlets: Array) -> void:
	print("\n=== the build menu: can a player stand these port on port? ===")
	GameState.add_money(1000000000000.0)


	for o: Array in outlets:
		if MENU.has(o [0]):
			_geometry(o [0], o [1], false)
	for n: Array in inlets:
		if MENU.has(n [0]):
			_geometry(n [0], n [1], true)
	var tool: BuildTool = player.build
	tool.set_active(true)
	for o: Array in outlets:
		for n: Array in inlets:
			if not MENU.has(o [0]) or not MENU.has(n [0]) or not _wanted(_name(o), _name(n)):
				continue
			var out_first: String = await _menu_order(o, n, true)
			var in_first: String = await _menu_order(o, n, false)
			var code:= "."
			if out_first == "ok" or in_first == "ok":
				code = "B"
				_menu_bolted.append("%-22s -> %-18s %s" % [_name(o), _name(n),
					"either order" if out_first == in_first else
					("outlet first" if out_first == "ok" else "inlet first")])
			elif out_first.begins_with("refused") or in_first.begins_with("refused"):
				code = "r"
				_menu_refused.append("%-22s -> %-18s %s" % [_name(o), _name(n),
					out_first if out_first.begins_with("refused") else in_first])
			var row: Dictionary = _menu_grid.get(_name(o), { })
			row [_name(n)] = code
			_menu_grid [_name(o)] = row
	tool.set_active(false)
	_clear_yard()
	_menu_report(outlets, inlets)


func _menu_order(o: Array, n: Array, outlet_first: bool) -> String:
	_clear_yard()
	var first_kind: String = o [0] if outlet_first else n [0]
	var first:= await _menu_stand(first_kind)
	if first == null:
		return "the menu would not stand %s on bare floor" % first_kind
	var port:= Vector3.ZERO
	var travel:= Vector3.ZERO
	var g:= { }
	if outlet_first:
		var spec:= _find_outlet(o [0], o [1], first)
		if spec.is_empty():
			return "no such outlet"
		port = spec ["port"]
		travel = spec ["dir"]
		g = _geometry(n [0], n [1], true)
	else:
		var inl:= _inlet_of(n [0], n [1], first)
		if inl.is_empty():
			return "no such inlet"
		port = inl ["port"]
		travel = inl ["dir"]
		g = _geometry(o [0], o [1], false)
	var d: Vector3 = g ["D"]
	if d == Vector3.ZERO:
		return "not measured"
	var yaw:= _heading(travel) - _heading(d)
	var at: Vector3 = port - (g ["L"] as Vector3).rotated(Vector3.UP, yaw)
	var second_kind: String = n [0] if outlet_first else o [0]
	return await _menu_verdict(second_kind, at, yaw, first.global_position)


func _menu_stand(kind: String) -> Node3D:
	var aimed: bool = await _menu_aim(kind, MENU_FLOOR, Vector3.BACK, Vector3.BACK)
	var tool: BuildTool = player.build
	if not aimed or not bool(tool._eval.get("ok", false)):
		return null
	var before:= _all_built()
	tool._primary()
	for i in 2:
		await get_tree().physics_frame
	for node in _all_built():
		if not before.has(node) and _kind_matches(kind, node):
			return node
	return null


func _menu_verdict(kind: String, at: Vector3, yaw: float, first_at: Vector3) -> String:
	var fwd:= Vector3(sin(yaw), 0.0, cos(yaw))
	var floor_at:= Vector3(at.x, MENU_FLOOR.y, at.z)


	var away:= Vector3(at.x - first_at.x, 0.0, at.z - first_at.z)
	if away.length_squared() < 1e-06:
		away = fwd
	var aimed: bool = await _menu_aim(kind, floor_at, away.normalized(), fwd)
	if not aimed:
		return "the grid cannot face it that way"
	var tool: BuildTool = player.build
	var ghost:= tool.get(MENU [kind] [1]) as Node3D
	if ghost == null:
		return "no hologram"
	var off:= ghost.global_position.distance_to(at)
	if off > MEET:
		return "the hologram lands %.2f m away (%.2f up)" % [off, ghost.global_position.y - at.y]
	if absf(angle_difference(ghost.global_rotation.y, yaw)) > 0.01:
		return "the hologram faces another way"
	if not bool(tool._eval.get("ok", false)):
		return "refused: %s" % String(tool._eval.get("reason", "?"))
	return "ok"


func _menu_aim(kind: String, floor_at: Vector3, side: Vector3, fwd: Vector3) -> bool:
	var tool: BuildTool = player.build
	tool.set_mode(MENU [kind] [0])

	tool._reach = 14.0
	tool._grid_on = true
	player.global_position = floor_at + side * 5.0 + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	_aim(floor_at)
	var faced:= false
	for k in 4:
		tool._ghost_turn = k
		if tool._aim_forward().distance_to(fwd) < 0.01:
			faced = true
			break
	if not faced:
		return false
	tool._update_ghost(0.0)
	return true


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _all_built() -> Array:
	var b: BuildManager = world.builds
	var out:= []
	for list: Array in [b.splitters, b.joiners, b.scanners, b.compressors, b.pulpers,
			b.papers, b.briquette_presses, b.wrappers, b.silos, b.pelletizers,
			b.generators, b.tube_launchers, b.hay_stairs, b.hay_lifts]:
		for node in list:
			if is_instance_valid(node):
				out.append(node)
	return out


static func _kind_matches(kind: String, node: Node) -> bool:
	match kind:
		"splitter":
			return node is ConveyorSplitter and not (node is ConveyorUSplitter
				or node is ConveyorTSplitter or node is ConveyorCompactSplitter)
		"u_splitter":
			return node is ConveyorUSplitter
		"t_splitter":
			return node is ConveyorTSplitter
		"compact", "smart":
			return node is ConveyorCompactSplitter
		"joiner":
			return node is ConveyorJoiner and not (node is ConveyorUJoiner
				or node is ConveyorTJoiner)
		"u_joiner":
			return node is ConveyorUJoiner
		"scanner":
			return node is HaystackScanner
		"compressor":
			return node is HayCompressor
		"pulper":
			return node is HayPulper
		"paper":
			return node is PaperMachine
		"briquette":
			return node is BriquettePress
		"wrapper":
			return node is HayWrapper
		"silo":
			return node is HaySilo
		"pelletizer":
			return node is HayPelletizer
		"generator":
			return node is HayGenerator
		"launcher":
			return node is TubeLauncher
		"lift":
			return node is HayLift
		"stairs":
			return node is HayStairs
	return false


func _menu_report(outlets: Array, inlets: Array) -> void:
	print("\n=== menu grid: rows hand out, columns take in ===")
	print("  B  a player can stand these two port on port (in at least one order)")
	print("  r  the hologram lands port on port but is refused")
	print("  .  the menu never stands them port on port")
	var cols: Array = []
	for n: Array in inlets:
		if MENU.has(n [0]):
			cols.append(_name(n))
	for i in cols.size():
		print("  col %2d  %s" % [i, cols [i]])
	var head:= "%-22s" % ""
	for i in cols.size():
		head += "%3d" % i
	print(head)
	for o: Array in outlets:
		if not _menu_grid.has(_name(o)):
			continue
		var row: Dictionary = _menu_grid [_name(o)]
		var line:= "%-22s" % _name(o)
		for c: String in cols:
			line += "%3s" % String(row.get(c, "-"))
		print(line)
	print("\n=== pairs a player can build port on port ===")
	for s in _menu_bolted:
		print("  " + s)
	print("\n=== pairs the menu lines up and refuses ===")
	for s in _menu_refused:
		print("  " + s)
	print("\nBOLTED MENU: %d pairs a player can build port on port, %d lined up and refused"
		% [_menu_bolted.size(), _menu_refused.size()])
	get_tree().quit(0)


func _grid_report(outlets: Array, inlets: Array) -> void:
	print("\n=== ports against the 1 m grid, yaw 0 (x across, z along, y up) ===")
	for pair: Array in [[outlets, false], [inlets, true]]:
		for m: Array in pair [0]:
			var g:= _geometry(String(m [0]), String(m [1]), bool(pair [1]))
			var l: Vector3 = g ["L"]
			if not l.is_finite():
				print("  %-26s  no port" % _name(m))
				continue
			var d: Vector3 = g ["D"]
			print("  %-26s %-3s x %+6.3f  z %+6.3f  y %+6.3f  off x %.3f z %.3f  dir (%+.2f, %+.2f)" % [
				_name(m), "in" if pair [1] else "out", l.x, l.z, l.y,
				absf(l.x - roundf(l.x)), absf(l.z - roundf(l.z)), d.x, d.z])
	get_tree().quit(0)


func _report(outlets: Array, inlets: Array) -> void:
	_clear_yard()
	print("\n=== grid: rows hand out, columns take in ===")
	print("  .  linked, and it held with the inlet shut")
	print("  L  not linked: the outlet is an open end at a machine's mouth")
	print("  T  linked, and still something left the belts")
	print("  LT both")
	print("  K  bolting the inlet on turned the outlet into a different machine")
	print("  P  the two ports could not be made to meet")
	var cols: Array = []
	for n: Array in inlets:
		if _only == "" or _grid.values().any(func(r: Dictionary) -> bool: return r.has(_name(n))):
			cols.append(_name(n))
	for i in cols.size():
		print("  col %2d  %s" % [i, cols [i]])
	var head:= "%-22s" % ""
	for i in cols.size():
		head += "%3d" % i
	print(head)
	for o: Array in outlets:
		if not _grid.has(_name(o)):
			continue
		var row: Dictionary = _grid [_name(o)]
		var line:= "%-22s" % _name(o)
		for c: String in cols:
			line += "%3s" % String(row.get(c, "-"))
		print(line)
	print("\n=== failures ===")
	for f in _failures:
		print("  " + f)
	if not _went_through.is_empty():
		print("\n=== not failures: a shut inlet that let loads through anyway ===")
		for w in _went_through:
			print("  " + w)
	var failed:= _failures.size()
	print("\nBOLTED PORTS: %d pairs, %d linked, %d held, %d failed (%d could not be placed)"
		% [_pairs, _linked, _held, failed, _place_fails])
	print("BOLTED PORTS %s" % ("PASS" if failed == 0 else "FAILED"))
	get_tree().quit(0 if failed == 0 else 1)
