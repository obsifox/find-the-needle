class_name PowerLine
extends Node3D


const WIRE_R:= 0.013


const GHOST_R:= 0.022


const POINTS:= 14
const TUBE_SIDES:= 6


const RELAX_PASSES:= 10


const SLACK:= 8.0 / 3.0 * Cfg.POLE_SAG * Cfg.POLE_SAG


const SAG_MAX:= 0.9


const GRAVITY:= 5.5


const DAMPING:= 0.965


const STEP:= 1.0 / 480.0


const MAX_STEPS_PER_FRAME:= 16


const SLEEP_SPEED:= 0.05
const SLEEP_EPSILON:= SLEEP_SPEED * STEP
const SLEEP_FRAMES:= 12


const MIN_AWAKE:= 0.35


const MOVE_EPSILON:= 0.01


static var _old_line: bool = "--oldline" in OS.get_cmdline_user_args()


const SEEN_EPSILON_SQ:= 0.0001 * 0.0001


const WIRE_MAT:= "M_Cable"


var from_anchors: Array [Node3D] = []
var to_anchors: Array [Node3D] = []

var _mesh: MeshInstance3D = null
var _material: Material = null


var _pos: PackedVector3Array = PackedVector3Array()
var _prev: PackedVector3Array = PackedVector3Array()
var _rest: PackedFloat32Array = PackedFloat32Array()
var _ends: PackedVector3Array = PackedVector3Array()


var settled:= false

var _asleep:= false


var _seen: PackedVector3Array = PackedVector3Array()
var _seen_self:= Transform3D()
var _still_frames:= 0
var _awake_for:= 0.0
var _accum:= 0.0


static func curve(p0: Vector3, p1: Vector3, steps: int = POINTS - 1) -> PackedVector3Array:
	var out:= PackedVector3Array()
	var sag:= sag_for(p0.distance_to(p1))
	for i in maxi(steps, 1) + 1:
		var t:= float(i) / float(maxi(steps, 1))
		var p:= p0.lerp(p1, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		out.append(p)
	return out


static func sag_for(span: float) -> float:
	return minf(span * Cfg.POLE_SAG, SAG_MAX)


static func _slack_for(span: float) -> float:
	if span < 0.001:
		return SLACK
	var ratio:= sag_for(span) / span
	return 8.0 / 3.0 * ratio * ratio


static func ghost_mesh(spans: Array) -> ArrayMesh:
	if spans.is_empty():
		return null
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pair: Array in spans:
		sweep(st, curve(pair [0], pair [1]), GHOST_R)
	st.generate_normals()
	return st.commit()


static func hang(parent: Node3D, from_end: Node3D, to_end: Node3D,
		material: Material = null, already_settled: bool = false) -> PowerLine:
	var line:= PowerLine.new()
	line.name = "PowerLine"
	line.from_anchors = anchors_of(from_end)
	line.to_anchors = anchors_of(to_end)
	line._material = material
	line.settled = already_settled
	parent.add_child(line)
	return line


static func hang_at(parent: Node3D, from_anchor: Node3D, to_anchor: Node3D,
		material: Material = null, already_settled: bool = false) -> PowerLine:
	var line:= PowerLine.new()
	line.name = "PowerLine"
	line.from_anchors = [from_anchor]
	line.to_anchors = [to_anchor]
	line._material = material
	line.settled = already_settled
	parent.add_child(line)
	return line


static func anchors_of(node: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	if node == null:
		return out
	if node.has_method("wire_anchors"):


		var got: Variant = node.call("wire_anchors")
		if got is Array:
			for n: Variant in (got as Array):
				if n is Node3D:
					out.append(n as Node3D)
		return out


	for suffix in ["", "L", "R"]:
		for prefix in ["Marker_Wire", "Gen_WirePort"]:
			var found:= node.find_child(prefix + suffix, true, false) as Node3D
			if found != null:
				out.append(found)
				break
	return out


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Wire"


	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	build()


func build() -> void:
	_note_seen()
	var pairs:= _pairs()
	_pos.clear()
	_prev.clear()
	_rest.clear()
	_ends.clear()
	for pair: Array in pairs:
		var a: Vector3 = pair [0]
		var b: Vector3 = pair [1]
		var span:= a.distance_to(b)


		var seg: float = span * (1.0 + _slack_for(span)) / float(POINTS - 1)
		var rest:= curve(a, b, POINTS - 1) if settled else PackedVector3Array()
		for i in POINTS:
			var p:= rest [i] if settled else a.lerp(b, float(i) / float(POINTS - 1))
			_pos.append(p)
			_prev.append(p)
		_rest.append(seg)
		_ends.append(a)
		_ends.append(b)
	if settled:
		_asleep = true
		_still_frames = SLEEP_FRAMES
	else:
		_wake()
	_remesh()


func _process(delta: float) -> void:


	if _asleep and _unmoved() and not _old_line:
		return
	if _repin():
		_wake()
	if _asleep:
		return
	_awake_for += delta
	_accum += delta
	var steps:= 0
	while _accum >= STEP and steps < MAX_STEPS_PER_FRAME:
		_accum -= STEP
		steps += 1
		_integrate()
	if steps == 0:
		return
	if _accum > STEP * MAX_STEPS_PER_FRAME:


		_accum = 0.0
	_remesh()
	_check_sleep()


func nudge(impulse:= Vector3.ZERO) -> void:
	_wake()
	if impulse == Vector3.ZERO:
		return


	for w in _ropes():
		for i in range(1, POINTS - 1):
			var k:= w * POINTS + i
			_prev [k] = _prev [k] - impulse * STEP


func is_asleep() -> bool:
	return _asleep


func set_wire_material(m: Material) -> void:
	_material = m
	if _mesh != null and m != null:
		_mesh.material_override = m


func points() -> PackedVector3Array:
	return _pos


func span_length() -> float:
	if _ends.size() < 2:
		return 0.0
	return _ends [0].distance_to(_ends [1])


func _ropes() -> int:
	return _rest.size()


func _wake() -> void:
	_asleep = false
	_still_frames = 0
	_awake_for = 0.0
	_accum = 0.0


func _integrate() -> void:
	var fall:= Vector3.DOWN * GRAVITY * STEP * STEP
	for i in _pos.size():
		var p:= _pos [i]
		_pos [i] = p + (p - _prev [i]) * DAMPING + fall
		_prev [i] = p
	for _pass in RELAX_PASSES:
		for w in _ropes():
			var base:= w * POINTS
			var rest:= _rest [w]
			for i in POINTS - 1:
				var a:= _pos [base + i]
				var b:= _pos [base + i + 1]
				var d:= b - a
				var length:= d.length()
				if length < 1e-05:
					continue


				var fix:= d * (0.5 * (1.0 - rest / length))
				_pos [base + i] = a + fix
				_pos [base + i + 1] = b - fix
			_pos [base] = _ends [w * 2]
			_pos [base + POINTS - 1] = _ends [w * 2 + 1]


func _unmoved() -> bool:
	if global_transform != _seen_self:
		return false
	var n: int = mini(from_anchors.size(), to_anchors.size())
	var k:= 0
	for i in n:
		var a:= from_anchors [i]
		var b:= to_anchors [i]
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if k + 1 >= _seen.size() or a.global_position.distance_squared_to(_seen [k]) > SEEN_EPSILON_SQ or b.global_position.distance_squared_to(_seen [k + 1]) > SEEN_EPSILON_SQ:
			return false
		k += 2
	return k == _seen.size()


func _note_seen() -> void:
	_seen.clear()
	_seen_self = global_transform
	var n: int = mini(from_anchors.size(), to_anchors.size())
	for i in n:
		var a:= from_anchors [i]
		var b:= to_anchors [i]
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		_seen.append(a.global_position)
		_seen.append(b.global_position)


func _repin() -> bool:
	_note_seen()
	var pairs:= _pairs()
	if pairs.size() != _ropes():
		build()
		return false
	var moved:= false
	for w in pairs.size():
		var a: Vector3 = pairs [w] [0]
		var b: Vector3 = pairs [w] [1]
		if (a.distance_to(_ends [w * 2]) > MOVE_EPSILON
				or b.distance_to(_ends [w * 2 + 1]) > MOVE_EPSILON):
			moved = true
		_ends [w * 2] = a
		_ends [w * 2 + 1] = b
	if moved:


		for w in pairs.size():
			var span: float = _ends [w * 2].distance_to(_ends [w * 2 + 1])
			_rest [w] = span * (1.0 + _slack_for(span)) / float(POINTS - 1)
	return moved


func _check_sleep() -> void:
	if _awake_for < MIN_AWAKE:
		return
	var worst:= 0.0
	for i in _pos.size():
		worst = maxf(worst, _pos [i].distance_to(_prev [i]))
	if worst < SLEEP_EPSILON:
		_still_frames += 1
		if _still_frames >= SLEEP_FRAMES:
			_asleep = true
	else:
		_still_frames = 0


func _pairs() -> Array:
	var out: Array = []
	var n: int = mini(from_anchors.size(), to_anchors.size())
	for i in n:
		var a:= from_anchors [i]
		var b:= to_anchors [i]
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		out.append([to_local(a.global_position), to_local(b.global_position)])
	return out


func _remesh() -> void:
	if _mesh == null:
		return
	if _ropes() == 0:
		_mesh.mesh = null
		return
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for w in _ropes():
		sweep(st, _pos.slice(w * POINTS, w * POINTS + POINTS), WIRE_R)
	st.generate_normals()
	_mesh.mesh = st.commit()
	if _material != null:
		_mesh.material_override = _material


static func sweep(st: SurfaceTool, pts: PackedVector3Array, radius: float) -> void:
	var n:= pts.size()
	if n < 2:
		return
	var side:= Vector3.UP.cross((pts [1] - pts [0]).normalized())
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()

	var rings: Array = []
	for i in n:
		var prev:= pts [maxi(i - 1, 0)]
		var next:= pts [mini(i + 1, n - 1)]
		var tangent:= next - prev
		if tangent.length() < 0.0001:
			tangent = Vector3.RIGHT
		tangent = tangent.normalized()
		side = side - tangent * side.dot(tangent)
		if side.length() < 0.0001:
			side = tangent.cross(Vector3.UP).normalized()
		side = side.normalized()
		var up:= tangent.cross(side).normalized()
		var ring: Array [Vector3] = []
		for k in TUBE_SIDES:
			var ang:= TAU * float(k) / float(TUBE_SIDES)
			ring.append(pts [i] + side * (radius * cos(ang))
				+ up * (radius * sin(ang)))
		rings.append(ring)

	for i in n - 1:
		var r0: Array = rings [i]
		var r1: Array = rings [i + 1]
		for k in TUBE_SIDES:
			var j:= (k + 1) % TUBE_SIDES
			st.add_vertex(r0 [k])
			st.add_vertex(r1 [k])
			st.add_vertex(r1 [j])
			st.add_vertex(r0 [k])
			st.add_vertex(r1 [j])
			st.add_vertex(r0 [j])
