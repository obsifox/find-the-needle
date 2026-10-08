class_name PowerGrid
extends RefCounted


const M_DRAW:= &"draw_kw"
const M_OUTPUT:= &"output_kw"
const M_PORTS:= &"power_ports"
const M_SET:= &"set_power"
const M_BLOCKED:= &"set_power_blocked"


const M_LINE:= &"set_power_line"


const M_LOAD:= &"set_load"


const M_ABLE:= &"deliverable_kw"


const M_NETWORKED:= &"set_on_network"


const M_CAP:= &"cap_kw"


const F_OUT:= 1
const F_HAY:= 2
const F_ABLE:= 1
const F_LOAD:= 2
const F_SET:= 1
const F_LINE:= 2
const F_FEED:= 4


static var _old_grid: bool = "--oldgrid" in OS.get_cmdline_user_args()


const CABLE_MASK:= Cfg.L_WORLD | Cfg.L_BUILD


const CABLE_TRANSPARENT:= "cable_transparent"

var builds: BuildManager


var unmetered:= false


var _nets: Array [Dictionary] = []

var _net_of_pole: Dictionary = { }


var _link: Dictionary = { }

var _unreachable: Array [Node3D] = []

var _pushed: Dictionary = { }

var _pushed_line: Dictionary = { }


var _loose: Array [Node3D] = []


var _feeders: Dictionary = { }


var _hung: Dictionary = { }


var _settle_all:= false


var _span_ok: Dictionary = { }


var _loose_told:= false

var _rows: Array [Dictionary] = []
var _rows_fresh:= false


func _init(manager: BuildManager) -> void:
	builds = manager


func rebuild() -> void:
	_nets.clear()
	_net_of_pole.clear()
	_link.clear()
	_unreachable.clear()


	_pushed.clear()
	_pushed_line.clear()
	_span_ok.clear()
	_loose_told = false
	_rows_fresh = false
	if builds == null:
		return

	var poles:= _poles()
	_resolve_links(poles)


	for pole in poles:
		pole.begin_restring()


	if not poles.is_empty():
		_build_networks(poles)
		_attach_machines(poles)
		_string_wires(poles)
	for pole in poles:
		pole.end_restring()
	_find_loose()
	_find_feeders()
	_classify()
	_push_blocked()
	tick()


func _classify() -> void:
	for net: Dictionary in _nets:
		var capped: Array [Node3D] = []
		var cap_flags:= PackedByteArray()
		var sup: Array [Node3D] = []
		var sup_flags:= PackedByteArray()
		var draw: Array [Node3D] = []
		var push: Array [Node3D] = []
		var push_flags:= PackedByteArray()
		for machine: Node3D in (net ["machines"] as Array [Node3D]):
			if not is_instance_valid(machine):
				continue
			var outputs:= machine.has_method(M_OUTPUT)
			if machine.has_method(M_CAP):
				capped.append(machine)
				cap_flags.append((F_OUT if outputs else 0)
					| (F_HAY if machine is HayGenerator and not (machine is GasPlant) else 0))
			if outputs:
				sup.append(machine)
				sup_flags.append((F_ABLE if machine.has_method(M_ABLE) else 0)
					| (F_LOAD if machine.has_method(M_LOAD) else 0))
			if machine.has_method(M_DRAW):
				draw.append(machine)
			var flags:= (F_SET if machine.has_method(M_SET) else 0) | (F_LINE if machine.has_method(M_LINE) else 0)
			if flags != 0:
				if _feeders.has(machine.get_instance_id()):
					flags |= F_FEED
				push.append(machine)
				push_flags.append(flags)
		var owns:= PackedFloat64Array()
		owns.resize(sup.size())
		net ["capped"] = capped
		net ["cap_flags"] = cap_flags
		net ["sup"] = sup
		net ["sup_flags"] = sup_flags
		net ["sup_able"] = owns
		net ["draw"] = draw
		net ["push"] = push
		net ["push_flags"] = push_flags
		net ["cap"] = 0.0
		net ["hay_gens"] = 0


		net ["k_sat"] = -1.0
		net ["k_line"] = -1
		net ["k_fed"] = false


func _find_feeders() -> void:
	_feeders.clear()
	if builds == null or builds.generators.is_empty():
		return
	var cooled:= _cooled_water_nets()
	if cooled.is_empty():
		return
	for machine in machines():
		if machine.has_method(WaterGrid.M_OUTPUT) and cooled.has(builds.water.network_of(machine)):
			_feeders [machine.get_instance_id()] = true


func _cooled_water_nets() -> Dictionary:
	var out: Dictionary = { }
	if builds == null or builds.water == null:
		return out
	for gen in builds.generators:
		if gen is GasPlant and is_instance_valid(gen) and gen.cap_kw() > 0.0:
			var net:= builds.water.network_of(gen)
			if net >= 0:
				out [net] = true
	return out


func is_feeder(machine: Node3D) -> bool:
	return machine != null and _feeders.has(machine.get_instance_id())


func is_dark(machine: Node3D) -> bool:
	var net:= network_of(machine)
	if net < 0:
		return false
	if float(_nets [net] ["supply"]) > 0.0:
		return false
	for member: Node3D in (_nets [net] ["machines"] as Array [Node3D]):
		if not is_instance_valid(member) or not member.has_method(M_OUTPUT):
			continue
		if member.has_method(M_CAP) and float(member.call(M_CAP)) > 0.0:
			return true
	return false


func line_state(machine: Node3D) -> int:
	var net:= network_of(machine)
	if net < 0:
		return MachinePower.LINE_OK
	return _line_of(float(_nets [net] ["supply"]), is_dark(machine))


static func _line_of(supply: float, fired: bool) -> int:
	if supply > 0.0:
		return MachinePower.LINE_OK
	return MachinePower.LINE_OUT_OF_HAY if fired else MachinePower.LINE_NO_GENERATOR


func _push_blocked() -> void:
	var blocked:= { }
	for machine in _unreachable:
		if is_instance_valid(machine):
			blocked [machine.get_instance_id()] = true
	for machine in machines():
		if machine.has_method(M_BLOCKED):
			machine.call(M_BLOCKED, blocked.has(machine.get_instance_id()))


		if machine.has_method(M_NETWORKED):
			machine.call(M_NETWORKED,
				unmetered or _link.has(machine.get_instance_id()))


func tick() -> void:
	if unmetered:
		for machine in machines():
			_push(machine, 1.0)
		return
	_rows_fresh = false
	for net: Dictionary in _nets:
		var supply:= 0.0
		var demand:= 0.0
		var able:= 0.0
		var could:= 0.0
		var cap:= 0.0
		var hay_gens:= 0
		var fired:= false


		var capped: Array [Node3D] = net ["capped"]
		var cap_flags: PackedByteArray = net ["cap_flags"]


		var i:= -1
		for machine: Node3D in capped:
			i += 1
			if not is_instance_valid(machine):
				continue
			var own:= float(machine.call(M_CAP))


			cap += own
			if own > 0.0:
				if cap_flags [i] & F_OUT:
					fired = true
				if cap_flags [i] & F_HAY:
					hay_gens += 1
		var sup: Array [Node3D] = net ["sup"]
		var sup_flags: PackedByteArray = net ["sup_flags"]
		var owns: PackedFloat64Array = net ["sup_able"]
		i = -1
		for machine: Node3D in sup:
			i += 1
			if not is_instance_valid(machine):
				continue
			supply += float(machine.call(M_OUTPUT))
			var own:= float(machine.call(M_ABLE if sup_flags [i] & F_ABLE else M_CAP))
			owns [i] = own
			could += own
			if sup_flags [i] & F_LOAD:
				able += own
		for machine: Node3D in (net ["draw"] as Array [Node3D]):
			if is_instance_valid(machine):
				demand += float(machine.call(M_DRAW))
		net ["supply"] = supply
		net ["demand"] = demand
		net ["cap"] = cap
		net ["hay_gens"] = hay_gens


		net ["could"] = could


		var satisfaction:= (1.0 if demand <= 0.0
			else clampf(supply / demand, 0.0, 1.0))
		net ["satisfaction"] = satisfaction


		i = -1
		for gen: Node3D in sup:
			i += 1
			if sup_flags [i] & F_LOAD and is_instance_valid(gen):
				gen.call(M_LOAD, 0.0 if able <= 0.0 else demand * owns [i] / able)


		var line:= _line_of(supply, fired)


		var fed:= supply > 0.0
		if not _old_grid and float(net ["k_sat"]) == satisfaction and int(net ["k_line"]) == line and bool(net ["k_fed"]) == fed:
			continue
		net ["k_sat"] = satisfaction
		net ["k_line"] = line
		net ["k_fed"] = fed
		var push: Array [Node3D] = net ["push"]
		var push_flags: PackedByteArray = net ["push_flags"]
		i = -1
		for machine: Node3D in push:
			i += 1


			if not is_instance_valid(machine):
				continue
			var flags:= push_flags [i]
			if flags & F_LINE:
				_push_line(machine, line)
			if flags & F_SET:
				_push(machine, 1.0 if flags & F_FEED and fed else satisfaction)


	if _loose_told and not _old_grid:
		return
	_loose_told = true
	for machine in _loose:
		if is_instance_valid(machine):
			_push(machine, 0.0)
			_push_line(machine, MachinePower.LINE_OK)


			if machine.has_method(M_LOAD):
				machine.call(M_LOAD, 0.0)


static func _able_of(supplier: Node3D) -> float:
	if supplier.has_method(M_ABLE):
		return float(supplier.call(M_ABLE))
	return float(supplier.call(M_CAP))


func _build_networks(poles: Array [PowerPole]) -> void:
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(poles.size())
	for i in poles.size():
		parent [i] = i
	var pairs:= _pairs(poles)
	for k in range(0, pairs.size(), 2):
		var i:= pairs [k]
		var j:= pairs [k + 1]
		if _strung(poles [i], poles [j]):
			var ri:= _root(parent, i)
			var rj:= _root(parent, j)
			if ri != rj:
				parent [rj] = ri
	var index: Dictionary = { }
	for i in poles.size():
		var root:= _root(parent, i)
		if not index.has(root):
			index [root] = _nets.size()
			var members: Array [PowerPole] = []
			var machines: Array [Node3D] = []
			_nets.append({ "poles": members, "machines": machines,
				"supply": 0.0, "demand": 0.0, "satisfaction": 1.0, "could": 0.0 })
		var at: int = index [root]
		(_nets [at] ["poles"] as Array [PowerPole]).append(poles [i])
		_net_of_pole [poles [i].get_instance_id()] = at


static func _root(parent: PackedInt32Array, i: int) -> int:
	var at:= i
	while parent [at] != at:
		parent [at] = parent [parent [at]]
		at = parent [at]
	return at


func _attach_machines(poles: Array [PowerPole]) -> void:
	var survey:= attach(poles)
	_unreachable.append_array(survey ["unreachable"] as Array [Node3D])
	for record: Dictionary in (survey ["found"] as Dictionary).values():
		var machine: Node3D = record ["machine"]
		var net: int = _net_of_pole.get(
			(record ["pole"] as PowerPole).get_instance_id(), -1)
		if net < 0:
			continue
		record ["net"] = net
		_link [machine.get_instance_id()] = record
		(_nets [net] ["machines"] as Array [Node3D]).append(machine)


func attach(poles: Array [PowerPole], only: Variant = null) -> Dictionary:
	var found: Dictionary = { }
	var unreachable: Array [Node3D] = []
	if builds == null:
		return { "found": found, "unreachable": unreachable }
	var space:= builds.get_world_3d().direct_space_state


	var survey:= { }
	var asked: Array [Node3D] = []
	if only is Array:
		asked.assign(only)
	else:
		asked = machines()
	for machine in asked:
		var record:= choose(space, machine, poles, survey)
		if record.is_empty():


			if in_reach_of_any(machine.global_position, poles):
				unreachable.append(machine)
			continue
		found [machine.get_instance_id()] = record
	return { "found": found, "unreachable": unreachable }


func _string_wires(poles: Array [PowerPole]) -> void:
	var hung:= { }
	var pairs:= _pairs(poles)
	for k in range(0, pairs.size(), 2):
		var i:= pairs [k]
		var j:= pairs [k + 1]
		if _strung(poles [i], poles [j]):
			var key:= _span_key(poles [i], poles [j])
			poles [i].connect_to(poles [j], _settle_all or _hung.has(key))
			hung [key] = true
	for record: Dictionary in _link.values():
		var pole: PowerPole = record ["pole"]
		var port: Node3D = record ["port"]
		if is_instance_valid(pole) and is_instance_valid(port):
			var key:= _span_key(pole, port)
			pole.connect_anchor(port, _settle_all or _hung.has(key))
			hung [key] = true
	_hung = hung
	_settle_all = false


static func _span_key(a: Node, b: Node) -> String:
	return "%d:%d" % [a.get_instance_id(), b.get_instance_id()]


static func _pairs(poles: Array [PowerPole]) -> PackedInt32Array:
	var out:= PackedInt32Array()
	if not BuildManager.yard_memo_enabled:
		for i in poles.size():
			for j in range(i + 1, poles.size()):
				out.append(i)
				out.append(j)
		return out
	var at:= { }
	for i in poles.size():
		at [poles [i].get_instance_id()] = i
	var found:= { }
	for i in poles.size():
		for other in poles [i].links_to:
			if not is_instance_valid(other):
				continue
			var j: int = at.get(other.get_instance_id(), -1)
			if j < 0 or j == i:
				continue
			found [Vector2i(mini(i, j), maxi(i, j))] = true
	var keys: Array = found.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	for key: Vector2i in keys:
		out.append(key.x)
		out.append(key.y)
	return out


func settle_next_rebuild() -> void:
	_settle_all = true


static func links_within(reach: float, a: Vector3, b: Vector3) -> bool:
	return _flat(a, b) <= reach


static func link_reach_between(a: PowerPole, b: PowerPole) -> float:
	return maxf(a.link_reach(), b.link_reach())


static func linked(a: PowerPole, b: PowerPole) -> bool:
	if not a.strung_to(b) and not b.strung_to(a):
		return false
	return links_within(link_reach_between(a, b), a.global_position,
		b.global_position)


static func span_clear(space: PhysicsDirectSpaceState3D, crown: Vector3,
		buried: bool, skip: Array [RID], to: PowerPole) -> bool:
	if buried and to.buried():
		return true
	var exclude: Array [RID] = skip.duplicate()
	exclude.append_array(to.own_bodies())
	exclude.append_array(transparent_bodies(to))
	return clear(space, crown, to.wire_point(), exclude)


func _strung(a: PowerPole, b: PowerPole) -> bool:
	if not linked(a, b):
		return false
	var key:= _span_key(a, b)
	if not _span_ok.has(key):
		_span_ok [key] = span_clear(builds.get_world_3d().direct_space_state,
			a.wire_point(), a.buried(), a.own_bodies(), b)
	return bool(_span_ok [key])


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return _flat(a, b)


func _resolve_links(poles: Array [PowerPole]) -> void:
	for pole in poles:
		if pole.links_at.size() == pole.links_to.size() or pole.links_at.is_empty():
			continue
		pole.links_to.clear()
		for at in pole.links_at:
			for other in poles:
				if other != pole and other.global_position.distance_to(at) < 0.1:
					pole.links_to.append(other)
					break


static func in_reach(pole: PowerPole, machine_at: Vector3) -> bool:
	return _flat(pole.global_position, machine_at) <= pole.supply_reach()


static func in_reach_of_any(machine_at: Vector3, poles: Array [PowerPole]) -> bool:
	for pole in poles:
		if is_instance_valid(pole) and in_reach(pole, machine_at):
			return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


static func choose(space: PhysicsDirectSpaceState3D, machine: Node3D,
		poles: Array [PowerPole], survey: Variant = null) -> Dictionary:
	var ports:= ports_of(machine)
	if ports.is_empty():
		return { }
	var kept: Dictionary = survey if survey is Dictionary else { }
	var exclude:= own_bodies(machine)
	if not kept.has("transparent"):
		kept ["transparent"] = transparent_bodies(machine)
	exclude.append_array(kept ["transparent"] as Array [RID])
	if BuildManager.yard_memo_enabled:
		return _choose_nearest_first(space, machine, poles, ports, exclude, kept)
	var best: Dictionary = { }
	var best_len:= INF
	for pole in poles:
		if not is_instance_valid(pole):
			continue
		if not in_reach(pole, machine.global_position):
			continue
		var crown:= pole.wire_point()


		var skip: Array [RID] = []
		var skip_ready:= false
		for port in ports:
			if not is_instance_valid(port):
				continue
			var at:= port.global_position
			var run:= crown.distance_to(at)
			if run >= best_len:
				continue


			if not pole.buried():
				if not skip_ready:
					skip.assign(exclude)
					var key:= pole.get_instance_id()
					if not kept.has(key):
						kept [key] = pole.own_bodies()
					skip.append_array(kept [key] as Array [RID])
					skip_ready = true
				if not clear(space, crown, at, skip):
					continue
			best_len = run
			best = { "machine": machine, "pole": pole, "port": port,
				"crown": crown, "at": at, "length": run }
	return best


static func _choose_nearest_first(space: PhysicsDirectSpaceState3D, machine: Node3D,
		poles: Array [PowerPole], ports: Array [Node3D], exclude: Array [RID],
		kept: Dictionary) -> Dictionary:
	var tries: Array = []
	for pole in poles:
		if not is_instance_valid(pole) or not in_reach(pole, machine.global_position):
			continue
		var crown:= pole.wire_point()
		for port in ports:
			if not is_instance_valid(port):
				continue
			var at:= port.global_position
			tries.append([crown.distance_to(at), tries.size(), pole, port, crown, at])
	tries.sort_custom(func(a: Array, b: Array) -> bool:
		return a [0] < b [0] or (a [0] == b [0] and a [1] < b [1]))
	for t: Array in tries:
		var pole: PowerPole = t [2]

		if not pole.buried():
			var key:= pole.get_instance_id()
			if not kept.has(key):
				kept [key] = pole.own_bodies()
			var skip: Array [RID] = []
			skip.assign(exclude)
			skip.append_array(kept [key] as Array [RID])
			if not clear(space, t [4], t [5], skip):
				continue
		return { "machine": machine, "pole": pole, "port": t [3],
			"crown": t [4], "at": t [5], "length": t [0] }
	return { }


static func clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Array [RID]) -> bool:
	if space == null:
		return true
	var steps:= maxi(2, int(ceil(from.distance_to(to) / Cfg.POLE_SAG_STEP)))
	var pts:= PowerLine.curve(from, to, steps)
	for i in pts.size() - 1:
		var query:= PhysicsRayQueryParameters3D.create(pts [i], pts [i + 1],
			CABLE_MASK)
		query.exclude = exclude


		query.collide_with_areas = false
		if not space.intersect_ray(query).is_empty():
			return false
	return true


static func ports_of(machine: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	if machine == null or not machine.has_method(M_PORTS):
		return out
	var got: Variant = machine.call(M_PORTS)
	if got is Array:
		for n: Variant in (got as Array):
			if n is Node3D and is_instance_valid(n):
				out.append(n as Node3D)
	return out


static func transparent_bodies(beside: Node) -> Array [RID]:
	var out: Array [RID] = []
	if beside == null or not beside.is_inside_tree():
		return out
	for node in beside.get_tree().get_nodes_in_group(CABLE_TRANSPARENT):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


static func own_bodies(node: Node) -> Array [RID]:


	if node != null and BuildManager.yard_memo_enabled and node.get_parent() is BuildManager:
		_memo_fresh(node.get_parent())
		var id:= node.get_instance_id()
		if not _bodies_memo.has(id):
			_bodies_memo [id] = _walk_bodies(node)
		return (_bodies_memo [id] as Array [RID]).duplicate()
	return _walk_bodies(node)


static func _walk_bodies(node: Node) -> Array [RID]:
	var out: Array [RID] = []
	if node == null:
		return out
	for child in node.find_children("*", "CollisionObject3D", true, false):
		var body:= child as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


static var _bodies_memo: Dictionary = { }
static var _machines_memo: Array [Node3D] = []
static var _memo_epoch:= -1
static var _memo_count:= -1


static func _memo_fresh(yard: Node) -> void:
	var count:= yard.get_child_count()
	if _memo_epoch == YardPorts.epoch and _memo_count == count:
		return
	_bodies_memo.clear()
	_machines_memo.clear()
	_memo_epoch = YardPorts.epoch
	_memo_count = count


func machines() -> Array [Node3D]:
	if builds == null:
		return [] as Array [Node3D]
	if not BuildManager.yard_memo_enabled:
		return _walk_machines()
	_memo_fresh(builds)
	if _machines_memo.is_empty():
		_machines_memo = _walk_machines()
	return _machines_memo.duplicate()


func _walk_machines() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for building in builds.all_buildings():
		if building == null or not is_instance_valid(building):
			continue
		if building.has_method(M_DRAW) or building.has_method(M_OUTPUT):
			out.append(building)
	return out


func _poles() -> Array [PowerPole]:
	var out: Array [PowerPole] = []
	if builds == null:
		return out
	for pole in builds.power_poles:
		if is_instance_valid(pole):
			out.append(pole)
	return out


func _find_loose() -> void:
	_loose.clear()
	for machine in machines():
		if not _link.has(machine.get_instance_id()):
			_loose.append(machine)


func unreachable() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for machine in _unreachable:
		if is_instance_valid(machine):
			out.append(machine)
	return out


func report(node: Node3D) -> Dictionary:
	var net:= network_of(node)
	if net < 0:
		return { "connected": false, "supply": 0.0, "demand": 0.0,
			"satisfaction": 0.0, "machines": 0, "poles": 0, "spare": 0.0 }
	var row:= _nets [net]
	return {
		"connected": true,
		"supply": float(row ["supply"]),
		"demand": float(row ["demand"]),
		"spare": maxf(float(row.get("could", 0.0)) - float(row ["demand"]), 0.0),
		"satisfaction": float(row ["satisfaction"]),
		"machines": (row ["machines"] as Array [Node3D]).size(),
		"poles": (row ["poles"] as Array [PowerPole]).size(),
	}


func members_of(node: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var net:= network_of(node)
	if net < 0:
		return out
	for machine: Node3D in (_nets [net] ["machines"] as Array [Node3D]):
		if is_instance_valid(machine):
			out.append(machine)
	return out


func switches_of(node: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	for machine in members_of(node):
		if machine.has_method("set_switched_off") and machine.has_method("is_switched_off"):
			out.append(machine)
	return out


func line_running(node: Node3D) -> bool:
	for machine in switches_of(node):
		if not bool(machine.call("is_switched_off")):
			return true
	return false


func switch_line(node: Node3D, off: bool) -> int:
	var moved:= 0
	for machine in switches_of(node):
		if bool(machine.call("is_switched_off")) == off:
			continue
		machine.call("set_switched_off", off)
		moved += 1
	if moved > 0:
		tick()
	return moved


func pole_switches(pole: PowerPole) -> Array [Node3D]:
	var out: Array [Node3D] = []
	for machine in served_by(pole):
		if machine.has_method(M_OUTPUT):
			continue
		if machine.has_method("set_switched_off") and machine.has_method("is_switched_off"):
			out.append(machine)
	return out


func pole_running(pole: PowerPole) -> bool:
	for machine in pole_switches(pole):
		if not bool(machine.call("is_switched_off")):
			return true
	return false


func switch_pole(pole: PowerPole, off: bool) -> int:
	var moved:= 0
	for machine in pole_switches(pole):
		if bool(machine.call("is_switched_off")) == off:
			continue
		machine.call("set_switched_off", off)
		moved += 1
	if moved > 0:
		tick()
	return moved


func network_of(node: Node3D) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	if node is PowerPole:
		return int(_net_of_pole.get(node.get_instance_id(), -1))
	var record: Dictionary = _link.get(node.get_instance_id(), { })
	return -1 if record.is_empty() else int(record ["net"])


func pole_for(machine: Node3D) -> PowerPole:
	var record: Dictionary = _link.get(machine.get_instance_id(), { })
	if record.is_empty():
		return null
	var pole: PowerPole = record ["pole"]
	return pole if is_instance_valid(pole) else null


func port_for(machine: Node3D) -> Node3D:
	var record: Dictionary = _link.get(machine.get_instance_id(), { })
	if record.is_empty():
		return null
	var port: Node3D = record ["port"]
	return port if is_instance_valid(port) else null


func served_by(pole: PowerPole) -> Array [Node3D]:
	var out: Array [Node3D] = []
	for record: Dictionary in _link.values():
		if record ["pole"] == pole and is_instance_valid(record ["machine"]):
			out.append(record ["machine"])
	return out


func network_count() -> int:
	return _nets.size()


func networks() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	if unmetered:
		return out


	if not _rows_fresh:
		_rows.clear()
		for net: Dictionary in _nets:
			_rows.append({
				"supply": float(net ["supply"]),
				"demand": float(net ["demand"]),
				"satisfaction": float(net ["satisfaction"]),
				"cap": float(net.get("cap", 0.0)),
				"hay_gens": int(net.get("hay_gens", 0)),
			})
		_rows_fresh = true
	for row in _rows:
		out.append(row.duplicate())
	return out


func _push(machine: Node3D, f: float) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	if not machine.has_method(M_SET):
		return
	var id:= machine.get_instance_id()
	if _pushed.has(id) and is_equal_approx(float(_pushed [id]), f):
		return
	_pushed [id] = f
	machine.call(M_SET, f)


func _push_line(machine: Node3D, line: int) -> void:
	if not machine.has_method(M_LINE):
		return
	var id:= machine.get_instance_id()
	if _pushed_line.has(id) and int(_pushed_line [id]) == line:
		return
	_pushed_line [id] = line
	machine.call(M_LINE, line)
