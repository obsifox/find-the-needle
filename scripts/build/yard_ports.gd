class_name YardPorts
extends RefCounted


static var epoch:= 0


var starts:= PointIndex.new()
var ends:= PointIndex.new()


var mouths: Array [Dictionary] = []


var splitter_ports: Array [Array] = []
var joiner_ports: Array [Array] = []

var _mouth:= PointIndex.new()
var _bearing:= PointIndex.new()
var _t_out:= PointIndex.new()
var _intake:= PointIndex.new()
var _generator:= PointIndex.new()


static func touch() -> void:
	epoch += 1


func _init(b: BuildManager) -> void:
	for i in b.conveyors.size():
		var c:= b.conveyors [i]
		if is_instance_valid(c):
			starts.add(c.a, c, i)
			ends.add(c.b, c, i)
	_file_mouths(b)
	_file_bearings(b)
	_file_t_mouths(b)
	_file_intakes(b)
	for i in b.generators.size():
		var gen:= b.generators [i]
		if is_instance_valid(gen):
			_generator.add(gen.intake_port(), gen, i)
	for splitter in b.splitters:
		if is_instance_valid(splitter):
			splitter_ports.append([splitter, splitter.ports()])
	for joiner in b.joiners:
		if is_instance_valid(joiner):
			joiner_ports.append([joiner, joiner.ports()])


func mouth_count(point: Vector3) -> int:
	return _mouth.all(point).size()


func bearing_hit(point: Vector3) -> Array:
	return _bearing.best(point)


func t_out(point: Vector3) -> Vector3:
	var hit:= _t_out.best(point)
	return hit [1] if not hit.is_empty() else Vector3.ZERO


func intake(point: Vector3) -> bool:
	return not _intake.best(point).is_empty()


func generator(point: Vector3) -> HayGenerator:
	for e: Array in _generator.all(point):
		if is_instance_valid(e [1]):
			return e [1]
	return null


func runs_ending_at(at: Vector3) -> Array [Conveyor]:
	return _exact(ends, at, false)


func runs_starting_at(at: Vector3) -> Array [Conveyor]:
	return _exact(starts, at, true)


func _exact(index: PointIndex, at: Vector3, start: bool) -> Array [Conveyor]:
	var out: Array [Conveyor] = []
	for e: Array in index.all(at):
		var c: Conveyor = e [1] if is_instance_valid(e [1]) else null
		if c != null and (c.a if start else c.b).is_equal_approx(at):
			out.append(c)
	return out


func _file_mouths(b: BuildManager) -> void:
	for splitter in b.splitters:
		if not is_instance_valid(splitter):
			continue
		mouths.append({ "point": splitter.port_in(), "forward": splitter.forward(),
			"start": true })
		for side in splitter.output_sides():
			mouths.append({ "point": splitter.port(side),
				"forward": splitter.arm_travel(side),
				"start": false })
	for joiner in b.joiners:
		if not is_instance_valid(joiner):
			continue
		mouths.append({ "point": joiner.port_out(), "forward": joiner.forward(),
			"start": false })
		for side: int in ConveyorJoiner.SIDES:
			mouths.append({ "point": joiner.port(side), "forward": joiner.arm_travel(side),
				"start": true })
	for i in mouths.size():
		_mouth.add(mouths [i] ["point"], true, i)


func _file_bearings(b: BuildManager) -> void:
	var r:= 0
	for splitter in b.splitters:
		if not is_instance_valid(splitter):
			continue
		_bearing.add(splitter.port_in(), splitter.forward(), r)
		r += 1
		for side in splitter.output_sides():
			_bearing.add(splitter.port(side), splitter.arm_travel(side), r)
			r += 1
	for joiner in b.joiners:
		if not is_instance_valid(joiner):
			continue
		_bearing.add(joiner.port_out(), joiner.forward(), r)
		r += 1
		for side: int in ConveyorJoiner.SIDES:
			_bearing.add(joiner.port(side), joiner.arm_travel(side), r)
			r += 1
	var spliced: Array [Array] = [b.scanners, b.compressors, b.pulpers, b.papers]
	for list: Array in spliced:
		r = _file_through(list, r)
	for press in b.briquette_presses:
		if not is_instance_valid(press):
			continue

		_bearing.add(press.port_wad(), press.global_basis.x.normalized(), r)
		_bearing.add(press.port_brick(), press.global_basis.z.normalized(), r + 1)
		_bearing.add(press.port_out(), press.global_basis.z.normalized(), r + 2)
		r += 3
	var after: Array [Array] = [b.hay_lifts, b.wrappers, b.silos]
	for list: Array in after:
		r = _file_through(list, r)
	var termini: Array [Array] = [b.pelletizers, b.generators, b.tube_launchers]
	for list: Array in termini:
		for machine: Node3D in list:
			if is_instance_valid(machine):
				_bearing.add(machine.call("intake_port"), machine.call("forward"), r)
				r += 1
	for tower in b.hay_stairs:
		if is_instance_valid(tower):
			_bearing.add(tower.outfeed_port(), tower.outfeed_forward(), r)
			r += 1


func _file_through(list: Array, r: int) -> int:
	for machine: Node3D in list:
		if not is_instance_valid(machine):
			continue
		var along: Vector3 = machine.call("forward")
		_bearing.add(machine.call("port_in"), along, r)
		_bearing.add(machine.call("port_out"), along, r + 1)
		r += 2
	return r


func _file_t_mouths(b: BuildManager) -> void:
	var r:= 0
	for splitter in b.splitters:
		if not (splitter is ConveyorTSplitter) or not is_instance_valid(splitter):
			continue
		var t:= splitter as ConveyorTSplitter
		for lane in ConveyorTSplitter.LANES:
			_t_out.add(t.to_global(t.mouth_of(lane)),
				(t.global_basis * ConveyorTSplitter.lane_out(lane)).normalized(), r)
			r += 1
	for joiner in b.joiners:
		if not (joiner is ConveyorTJoiner) or not is_instance_valid(joiner):
			continue
		var tj:= joiner as ConveyorTJoiner
		for lane in ConveyorTSplitter.LANES:
			_t_out.add(tj.to_global(ConveyorTSplitter.lane_mouth(lane, tj.port_r)),
				(tj.global_basis * ConveyorTSplitter.lane_out(lane)).normalized(), r)
			r += 1


func _file_intakes(b: BuildManager) -> void:
	for splitter in b.splitters:
		if is_instance_valid(splitter) and not (splitter is ConveyorTSplitter):
			_intake.add(splitter.port_in(), true, 0)
	for joiner in b.joiners:
		if not is_instance_valid(joiner) or joiner is ConveyorTJoiner:
			continue
		for side: int in ConveyorJoiner.SIDES:
			_intake.add(joiner.port(side), true, 0)
	var spliced: Array [Array] = [b.scanners, b.compressors, b.pulpers, b.papers,
		b.hay_lifts, b.wrappers, b.silos]
	for list: Array in spliced:
		for machine: Node3D in list:
			if is_instance_valid(machine):
				_intake.add(machine.call("port_in"), true, 0)
	for press in b.briquette_presses:
		if is_instance_valid(press):
			_intake.add(press.port_wad(), true, 0)
			_intake.add(press.port_brick(), true, 0)
	var termini: Array [Array] = [b.pelletizers, b.generators, b.tube_launchers]
	for list: Array in termini:
		for machine: Node3D in list:
			if is_instance_valid(machine):
				_intake.add(machine.call("intake_port"), true, 0)
