class_name EnclosedConveyorKit
extends RefCounted


const ASSET:= "res://assets/models/enclosed_conveyor/enclosed_conveyor_kit.glb"
const SETTINGS:= "res://assets/models/enclosed_conveyor/enclosed_conveyor_connections.json"
const JOIN_EPSILON:= 0.001


const HALF_WIDTH:= 0.482
var _meshes: Dictionary = { }
var _settings: Dictionary
var _batches: Dictionary = { }
var _root: Node3D
var _ports: Array [Dictionary] = []


var _bends: Dictionary = { }


var _build:= 0


const BEND_KEEP:= 3


func _init(donor: Node3D = null, settings: Dictionary = { }) -> void:
	var owned:= donor == null
	if owned:
		donor = (load(ASSET) as PackedScene).instantiate()
	for node in donor.find_children("EC_Kit_*", "MeshInstance3D", true, false):
		_meshes [String(node.name).trim_prefix("EC_Kit_")] = node.mesh
	_settings = settings if not settings.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if owned:
		donor.free()


func build_network(runs: Array, low_detail: bool = false) -> Dictionary:
	_build += 1
	var nodes: Array [Vector3] = []
	var edges: Array [Vector2i] = []
	var incoming: Dictionary = { }
	var outgoing: Dictionary = { }
	for run in runs:
		if not run is Dictionary or not run.get("a") is Vector3 or not run.get("b") is Vector3:
			return { "root": null, "error": "Each run requires Vector3 endpoints a and b." }
		if not run.a.is_finite() or not run.b.is_finite() or run.a.distance_to(run.b) < 0.01:
			return { "root": null, "error": "A run has invalid or coincident endpoints." }
		var a:= _vertex(nodes, run.a)
		var b:= _vertex(nodes, run.b)


		if outgoing.has(a):
			nodes.append(run.a)
			a = nodes.size() - 1
		if incoming.has(b):
			nodes.append(run.b)
			b = nodes.size() - 1
		outgoing [a] = b
		incoming [b] = a
		edges.append(Vector2i(a, b))
	_root = Node3D.new()
	_root.name = "EnclosedConveyorNetwork"
	_root.top_level = true
	_batches.clear()
	_ports.clear()
	var visited: Dictionary = { }
	var starts: Array [int] = []
	for edge in edges:
		if not incoming.has(edge.x):
			starts.append(edge.x)
	for edge in edges:
		starts.append(edge.x)
	var chains:= 0
	for start in starts:
		if visited.has(start):
			continue
		var points: Array [Vector3] = [nodes [start]]
		var at:= start
		while outgoing.has(at) and not visited.has(at):
			visited [at] = true
			at = outgoing [at]
			points.append(nodes [at])
		var closed:= at == start
		var error:= _chain(points, closed, low_detail, chains)
		if not error.is_empty():
			_root.free()
			return { "root": null, "error": error }
		chains += 1
	_flush_batches()
	_age_bends()
	_root.set_meta("chain_count", chains)
	return { "root": _root, "ports": _ports, "error": "" }


func _vertex(nodes: Array [Vector3], point: Vector3) -> int:
	for i in nodes.size():
		if nodes [i].distance_to(point) <= JOIN_EPSILON:
			return i
	nodes.append(point)
	return nodes.size() - 1


func _frame(direction: Vector3) -> Basis:
	var forward:= direction.normalized()
	var right:= forward.cross(Vector3.UP).normalized()
	return Basis(right, right.cross(forward).normalized(), - forward)


func _chain(points: Array [Vector3], closed: bool, low: bool, index: int) -> String:
	if closed:
		points.pop_back()
	var n:= points.size()
	var entries: Array [Vector3] = points.duplicate()
	var exits: Array [Vector3] = points.duplicate()


	var turn_at: Array [float] = []
	var want: Array [float] = []
	for i in n:
		turn_at.append(0.0)
		want.append(0.0)
	for i in range(0 if closed else 1, n if closed else n - 1):
		var turn:= (points [i] - points [(i + n - 1) % n]).normalized().angle_to((points [(i + 1) % n] - points [i]).normalized())
		if turn < float(_settings.min_turn):
			continue
		turn_at [i] = turn
		want [i] = minf(float(_settings.radius) * tan(minf(turn, PI * 0.94) * 0.5),
			float(_settings.max_tangent))


	var allow: Array [float] = []
	for i in n:
		allow.append(INF)
	for i in range(n if closed else n - 1):
		var next:= (i + 1) % n
		var free:= maxf(points [i].distance_to(points [next])
			- float(_settings.min_straight), 0.0)
		var asked:= want [i] + want [next]
		var share:= 1.0 if asked <= free or asked <= 0.0 else free / asked
		allow [i] = minf(allow [i], want [i] * share)
		allow [next] = minf(allow [next], want [next] * share)
	var turns: Dictionary = { }
	for i in range(0 if closed else 1, n if closed else n - 1):
		var turn:= turn_at [i]
		if turn <= 0.0:
			continue
		var before:= points [(i + n - 1) % n]
		var after:= points [(i + 1) % n]
		var u:= (points [i] - before).normalized()
		var v:= (after - points [i]).normalized()
		var room:= minf(points [i].distance_to(before), points [i].distance_to(after))
		var bite:= allow [i]
		entries [i] = points [i] - u * bite
		exits [i] = points [i] + v * bite


		if not _curve_error(entries [i], points [i], exits [i]).is_empty():
			var over:= minf(HALF_WIDTH * tan(minf(turn, PI * 0.94) * 0.5), room * 0.95)
			entries [i] = points [i] + u * over
			exits [i] = points [i] - v * over
			continue
		turns [i] = true
	var centreline:= PackedVector3Array()
	for i in range(n if closed else n - 1):
		var next:= (i + 1) % n
		var a:= exits [i]
		var b:= entries [next]
		var direction:= b - a
		var suffix:= "_LOD1" if low else ""


		if direction.dot(points [next] - points [i]) <= 0.0:
			centreline.append(points [i])
			centreline.append(points [next])
		elif direction.cross(Vector3.UP).length_squared() < 1e-06:
			return "Vertical or collapsed enclosed runs are unsupported."
		else:
			var length:= direction.length()
			var basis:= _frame(direction)
			var count:= maxi(1, int(ceil(length)))
			for j in count:
				var pose:= Transform3D(basis.scaled_local(Vector3(1, 1, length / count)), a.lerp(b, (j + 0.5) / count))
				_instance("Section" + suffix, pose)
			var supports:= maxi(1, int(ceil(length / float(_settings.support_spacing))))
			if absf(direction.normalized().y) <= 0.01:
				for j in supports:
					_instance("Support" + suffix,
						Transform3D(basis, a.lerp(b, (j + 0.5) / supports)))
			centreline.append(a)
			centreline.append(b)
		if turns.has(next):
			var arc:= _arc(entries [next], points [next], exits [next])
			var bend:= MeshInstance3D.new()
			bend.name = "Bend_%d_%d" % [index, next]
			bend.mesh = _cached_bend(entries [next], points [next], exits [next], arc, low)
			_root.add_child(bend)
			for sample in range(1, 33):
				centreline.append(_arc_point(arc, sample / 32.0))
			var bend_direction:= exits [next] - entries [next]
			if absf(bend_direction.normalized().y) <= 0.01:
				_instance("Support" + suffix, Transform3D(_frame(bend_direction),
					_arc_point(arc, 0.5)))
	if not closed:
		_port("Intake_%d" % index, points [0], points [0] - points [1], centreline, low)
		centreline.reverse()
		_port("Outlet_%d" % index, points [-1], points [-1] - points [-2], centreline, low)
	return ""


func _curve_error(a: Vector3, b: Vector3, c: Vector3) -> String:
	var arc:= _arc(a, b, c)
	if arc.is_empty():
		return "The enclosed turn reverses or becomes vertical."
	if float(arc.radius) < float(_settings.minimum_curve_radius):
		return "The enclosed turn is too tight for its full width. Lengthen the adjacent runs or use a gentler turn."


	for i in 65:
		if _arc_forward(arc, i / 64.0).cross(Vector3.UP).length_squared() < 1e-06:
			return "The enclosed turn reverses or becomes vertical."
	return ""


func _arc(a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	var u:= (b - a).normalized()
	var v:= (c - b).normalized()
	var axis:= u.cross(v)
	if axis.length_squared() < 1e-06:
		return { }
	var angle:= u.angle_to(v)
	var radius:= a.distance_to(b) / tan(angle * 0.5)


	var origin:= a + (v - u * u.dot(v)).normalized() * radius
	return { "origin": origin, "arm": a - origin, "axis": axis.normalized(),
		"angle": angle, "forward": u, "radius": radius }


func _arc_point(arc: Dictionary, t: float) -> Vector3:
	return (arc.origin as Vector3) + (arc.arm as Vector3).rotated(arc.axis as Vector3, float(arc.angle) * t)


func _arc_forward(arc: Dictionary, t: float) -> Vector3:
	return (arc.forward as Vector3).rotated(arc.axis as Vector3, float(arc.angle) * t)


func _cached_bend(entry: Vector3, apex: Vector3, exit: Vector3, arc: Dictionary,
		low: bool) -> ArrayMesh:
	var key:= [entry, apex, exit, low]
	var kept: Array = _bends.get(key, [])
	if not kept.is_empty():
		kept [1] = _build
		return kept [0] as ArrayMesh
	var fresh:= _bend(arc, low)
	_bends [key] = [fresh, _build]
	return fresh


func _age_bends() -> void:
	if _bends.is_empty():
		return
	var stale: Array = []
	for key: Variant in _bends:
		if _build - int((_bends [key] as Array) [1]) >= BEND_KEEP:
			stale.append(key)
	for key: Variant in stale:
		_bends.erase(key)


func _bend(arc: Dictionary, low: bool) -> ArrayMesh:
	var template: ArrayMesh = _meshes ["Sweep_LOD1" if low else "Sweep"]
	var arrays:= template.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays [Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays [Mesh.ARRAY_TANGENT]
	for i in vertices.size():
		var t:= clampf(- vertices [i].z, 0, 1)
		var basis:= _frame(_arc_forward(arc, t))
		vertices [i] = _arc_point(arc, t) + basis * Vector3(vertices [i].x, vertices [i].y, 0)
		normals [i] = basis * normals [i]
		var tangent:= basis * Vector3(tangents [i * 4], tangents [i * 4 + 1], tangents [i * 4 + 2])
		tangents [i * 4] = tangent.x
		tangents [i * 4 + 1] = tangent.y
		tangents [i * 4 + 2] = tangent.z
	arrays [Mesh.ARRAY_VERTEX] = vertices
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TANGENT] = tangents
	var result:= ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, template.surface_get_material(0))
	return result


func mesh(piece: String) -> Mesh:
	return _meshes.get(piece) as Mesh


func _instance(piece: String, pose: Transform3D) -> void:
	if not _batches.has(piece):
		_batches [piece] = []
	_batches [piece].append(pose)


func _flush_batches() -> void:
	for piece in _batches:
		var multimesh:= MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _meshes [piece]
		multimesh.instance_count = _batches [piece].size()
		for i in multimesh.instance_count:
			multimesh.set_instance_transform(i, _batches [piece] [i])
		var instance:= MultiMeshInstance3D.new()
		instance.name = piece + "Batch"
		instance.multimesh = multimesh
		_root.add_child(instance)


func _port(label: String, at: Vector3, outward: Vector3, line: PackedVector3Array, low: bool) -> void:
	var suffix:= "_LOD1" if low else ""
	var port:= Node3D.new()
	port.name = label
	port.transform = Transform3D(_frame(outward), at)
	_root.add_child(port)
	var terminal:= MeshInstance3D.new()
	terminal.name = "Terminal"
	terminal.mesh = _meshes ["Terminal" + suffix]
	port.add_child(terminal)
	_ports.append({ "at": at, "kind": "intake" if label.begins_with("Intake") else "outlet" })
	var length:= 0.0
	for i in line.size() - 1:
		length += line [i].distance_to(line [i + 1])
	var remaining:= minf(1.013, length * 0.45)
	for i in line.size() - 1:
		var span:= line [i].distance_to(line [i + 1])
		if span < 1e-06:
			continue
		if remaining <= span:
			var black:= MeshInstance3D.new()
			black.name = "BlackVoid_" + label
			black.mesh = _meshes.BlackVoid
			black.transform = Transform3D(_frame(line [i + 1] - line [i]), line [i].lerp(line [i + 1], remaining / span))
			_root.add_child(black)
			break
		remaining -= span
