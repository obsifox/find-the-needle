class_name WaterGrid
extends RefCounted


const M_DRAW:= &"water_draw_lps"
const M_OUTPUT:= &"water_lps"
const M_PORTS:= &"water_ports"
const M_SET:= &"set_water"


const M_BLOCKED:= &"set_water_blocked"


const M_PUMPLESS:= &"set_water_pumpless"

var builds: BuildManager


var unmetered:= false


static var _old_grid: bool = "--oldgrid" in OS.get_cmdline_user_args()


var _nets: Array [Dictionary] = []

var _net_of_main: Dictionary = { }


var _link: Dictionary = { }

var _pushed: Dictionary = { }


var _loose: Array [Node3D] = []


var _ends:= PointIndex.new()


var _loose_told:= false


func _init(manager: BuildManager) -> void:
	builds = manager


func rebuild() -> void:
	_nets.clear()
	_net_of_main.clear()
	_link.clear()


	_pushed.clear()
	_loose_told = false
	if builds == null:
		return

	var mains:= _mains()
	_ends = PointIndex.new()
	for i in mains.size():
		for end: Vector3 in mains [i].endpoints():
			_ends.add(end, i, i)


	if not mains.is_empty():
		_build_networks(mains)
		_attach_machines(mains)
	_classify()
	_find_loose()
	_push_blocked()
	tick()


func _classify() -> void:
	for net: Dictionary in _nets:
		var src: Array [Node3D] = []
		var sink: Array [Node3D] = []
		var push: Array [Node3D] = []
		for machine: Node3D in (net ["machines"] as Array [Node3D]):
			if not is_instance_valid(machine):
				continue
			if machine.has_method(M_OUTPUT):
				src.append(machine)
			if machine.has_method(M_DRAW):
				sink.append(machine)
			if machine.has_method(M_SET):
				push.append(machine)
		net ["src"] = src
		net ["sink"] = sink
		net ["push"] = push


		net ["k_sat"] = -1.0
		net ["k_flow"] = -1.0


func _build_networks(mains: Array [WaterMain]) -> void:
	var tol:= Cfg.PIPE_JOIN_TOLERANCE
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(mains.size())
	for i in mains.size():
		parent [i] = i
	for i in mains.size():
		for end: Vector3 in mains [i].endpoints():
			for hit: Array in _ends.within(end, tol):
				_join(parent, i, int(hit [1]))
	_bridge_fittings(parent, tol)

	var index_of:= { }
	for i in mains.size():
		var root:= _root(parent, i)
		if not index_of.has(root):
			index_of [root] = _nets.size()
			var fresh: Array [WaterMain] = []
			var members: Array [Node3D] = []
			_nets.append({ "mains": fresh, "supply": 0.0, "demand": 0.0,
				"satisfaction": 1.0, "flow": 0.0, "machines": members })
		var net:= int(index_of [root])
		(_nets [net] ["mains"] as Array [WaterMain]).append(mains [i])
		_net_of_main [mains [i].get_instance_id()] = net


func _bridge_fittings(parent: PackedInt32Array, tol: float) -> void:
	if builds == null:
		return
	var fittings:= builds.water_machines()
	var group:= PackedInt32Array()
	group.resize(fittings.size())
	for i in fittings.size():
		group [i] = i
	for i in fittings.size():
		for j in range(i + 1, fittings.size()):
			if _bolted(fittings [i], fittings [j], tol):
				_join(group, i, j)
	var first_of:= { }
	for i in fittings.size():
		var root:= _root(group, i)
		for port: Node3D in ports_of(fittings [i]):
			for hit: Array in _ends.within(port.global_position, tol):
				var k:= int(hit [1])
				if not first_of.has(root):
					first_of [root] = k
				else:
					_join(parent, int(first_of [root]), k)


static func _bolted(one: Node3D, other: Node3D, tol: float) -> bool:
	if not (one is WaterSplitter and other is WaterSplitter):
		return false
	for a: Node3D in ports_of(one):
		for b: Node3D in ports_of(other):
			if a.global_position.distance_to(b.global_position) <= tol:
				return true
	return false


static func _join(parent: PackedInt32Array, i: int, j: int) -> void:
	var ri:= _root(parent, i)
	var rj:= _root(parent, j)
	if ri != rj:
		parent [ri] = rj


static func _root(parent: PackedInt32Array, i: int) -> int:
	var r:= i
	while parent [r] != r:
		r = parent [r]
	var walk:= i
	while parent [walk] != walk:
		var next:= parent [walk]
		parent [walk] = r
		walk = next
	return r


func _attach_machines(mains: Array [WaterMain]) -> void:
	var tol:= Cfg.PIPE_JOIN_TOLERANCE
	for machine in machines():
		var found:= false
		for port: Node3D in ports_of(machine):


			var landed:= _ends.within(port.global_position, tol)
			landed.sort_custom(func(x: Array, y: Array) -> bool: return int(x [2]) < int(y [2]))
			for hit: Array in landed:
				var run:= mains [int(hit [1])]
				var net:= int(_net_of_main.get(run.get_instance_id(), -1))
				if net < 0:
					continue
				_link [machine.get_instance_id()] = {
					"machine": machine, "main": run, "port": port, "net": net,
				}
				(_nets [net] ["machines"] as Array [Node3D]).append(machine)
				found = true
				break
			if found:
				break


func _push_blocked() -> void:
	var loose:= { }
	for machine in _loose:
		if is_instance_valid(machine):
			loose [machine.get_instance_id()] = true


	var pumped:= { }
	for i in _nets.size():
		for member: Node3D in (_nets [i] ["machines"] as Array [Node3D]):
			if is_instance_valid(member) and member.has_method(M_OUTPUT):
				pumped [i] = true
				break
	for machine in machines():
		if machine.has_method(M_BLOCKED):
			machine.call(M_BLOCKED, loose.has(machine.get_instance_id()))
		if machine.has_method(M_PUMPLESS):
			var net:= network_of(machine)
			machine.call(M_PUMPLESS, net >= 0 and not pumped.has(net))


func tick() -> void:
	if unmetered:
		for machine in machines():
			_push(machine, 1.0)
		return
	for net: Dictionary in _nets:
		var supply:= 0.0
		var demand:= 0.0
		for machine: Node3D in (net ["src"] as Array [Node3D]):
			if is_instance_valid(machine):
				supply += float(machine.call(M_OUTPUT))
		for machine: Node3D in (net ["sink"] as Array [Node3D]):
			if is_instance_valid(machine):
				demand += float(machine.call(M_DRAW))
		net ["supply"] = supply
		net ["demand"] = demand


		net ["satisfaction"] = (1.0 if demand <= 0.0
			else clampf(supply / demand, 0.0, 1.0))


		net ["flow"] = 0.0 if supply <= 0.0 else float(net ["satisfaction"])


		var sat:= float(net ["satisfaction"])
		if _old_grid or float(net ["k_sat"]) != sat:
			net ["k_sat"] = sat
			for machine: Node3D in (net ["push"] as Array [Node3D]):


				if not is_instance_valid(machine):
					continue
				_push(machine, sat)


		var flow:= float(net ["flow"])
		if _old_grid or float(net ["k_flow"]) != flow:
			net ["k_flow"] = flow
			for run: WaterMain in (net ["mains"] as Array [WaterMain]):
				if is_instance_valid(run):
					run.set_flow(flow)


	if _loose_told and not _old_grid:
		return
	_loose_told = true
	for machine in _loose:
		if is_instance_valid(machine):
			_push(machine, 0.0)


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


func machines() -> Array [Node3D]:
	var out: Array [Node3D] = []
	if builds == null:
		return out
	for building in builds.all_buildings():
		if building == null or not is_instance_valid(building):
			continue
		if building.has_method(M_DRAW) or building.has_method(M_OUTPUT):
			out.append(building)
	return out


static func ports_of(machine: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	if machine == null or not machine.has_method(M_PORTS):
		return out
	for port: Node3D in machine.call(M_PORTS):
		if port != null and is_instance_valid(port):
			out.append(port)
	return out


func _mains() -> Array [WaterMain]:
	var out: Array [WaterMain] = []
	if builds == null:
		return out
	for run in builds.water_mains:
		if is_instance_valid(run):
			out.append(run)
	return out


func _find_loose() -> void:
	_loose.clear()
	for machine in machines():
		if not _link.has(machine.get_instance_id()):
			_loose.append(machine)


func unplumbed() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for machine in _loose:
		if is_instance_valid(machine):
			out.append(machine)
	return out


func report(node: Node3D) -> Dictionary:
	var net:= network_of(node)
	if net < 0:
		return { "connected": false, "supply": 0.0, "demand": 0.0,
			"satisfaction": 0.0, "flow": 0.0, "machines": 0, "mains": 0 }
	var row:= _nets [net]
	return {
		"connected": true,
		"supply": float(row ["supply"]),
		"demand": float(row ["demand"]),
		"satisfaction": float(row ["satisfaction"]),
		"flow": float(row ["flow"]),
		"machines": (row ["machines"] as Array [Node3D]).size(),
		"mains": (row ["mains"] as Array [WaterMain]).size(),
	}


func network_of(node: Node3D) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	if node is WaterMain:
		return int(_net_of_main.get(node.get_instance_id(), -1))
	var record: Dictionary = _link.get(node.get_instance_id(), { })
	return -1 if record.is_empty() else int(record ["net"])


func members_of(node: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var net:= network_of(node)
	if net < 0:
		return out
	for machine: Node3D in (_nets [net] ["machines"] as Array [Node3D]):
		if is_instance_valid(machine):
			out.append(machine)
	return out


func mains_of(node: Node3D) -> Array [WaterMain]:
	var out: Array [WaterMain] = []
	var net:= network_of(node)
	if net < 0:
		return out
	for run: WaterMain in (_nets [net] ["mains"] as Array [WaterMain]):
		if is_instance_valid(run):
			out.append(run)
	return out


func main_for(machine: Node3D) -> WaterMain:
	var record: Dictionary = _link.get(machine.get_instance_id(), { })
	if record.is_empty():
		return null
	var run: WaterMain = record ["main"]
	return run if is_instance_valid(run) else null


func port_for(machine: Node3D) -> Node3D:
	var record: Dictionary = _link.get(machine.get_instance_id(), { })
	if record.is_empty():
		return null
	var port: Node3D = record ["port"]
	return port if is_instance_valid(port) else null


func served_by(run: WaterMain) -> Array [Node3D]:
	var out: Array [Node3D] = []
	for record: Dictionary in _link.values():
		if record ["main"] == run and is_instance_valid(record ["machine"]):
			out.append(record ["machine"])
	return out


func network_count() -> int:
	return _nets.size()
