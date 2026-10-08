class_name WaterMain
extends Node3D


var a: Vector3 = Vector3.ZERO
var b: Vector3 = Vector3.ZERO
var length: float = 0.0
var forward: Vector3 = Vector3.BACK


var trim_start: float = 0.0


var bend_tangent: float = 0.0

var bend_out: Vector3 = Vector3.ZERO


var joined_start:= false


var joined_end:= false


var paid_cost:= -1.0


var flow:= 0.0


var placed_stations: Array [float] = []


const BELT_CLEAR:= 0.2


const TRESTLE_GAP:= 1.0


static var _keep_empty_mm:= "--keepemptymm" in OS.get_cmdline_user_args()

var _sections: Node3D
var _supports: Node3D
var _bodies: Node3D
var _water_material: ShaderMaterial


var section_stations: PackedFloat32Array = PackedFloat32Array()
var section_pitches: PackedFloat32Array = PackedFloat32Array()


var _straight_count:= 0


var _line: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()


static func cost_for(from: Vector3, to: Vector3) -> float:
	return from.distance_to(to) * Cfg.PIPE_COST_PER_M * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return cost_for(a, b)


func setup(from: Vector3, to: Vector3) -> void:
	a = from
	b = to
	length = a.distance_to(b)
	forward = (b - a).normalized() if length > 1e-06 else Vector3.BACK


	paid_cost = cost_for(a, b)


func laid_start() -> Vector3:
	return a + forward * trim_start


func laid_end() -> Vector3:
	return b - forward * bend_tangent


func set_joint(start_trim: float, tangent: float, out_forward: Vector3,
		joined:= false, on_flange:= false) -> void:
	if is_equal_approx(start_trim, trim_start) and is_equal_approx(tangent, bend_tangent) and out_forward.is_equal_approx(bend_out) and joined == joined_start and on_flange == joined_end:
		return
	trim_start = start_trim
	bend_tangent = tangent
	bend_out = out_forward
	joined_start = joined
	joined_end = on_flange
	if is_inside_tree():
		_lay()


func reverse() -> void:
	var was_a:= a
	a = b
	b = was_a
	forward = (b - a).normalized() if length > 1e-06 else Vector3.BACK
	trim_start = 0.0
	bend_tangent = 0.0
	bend_out = Vector3.ZERO
	joined_start = false
	joined_end = false
	if is_inside_tree():
		_lay()


func endpoints() -> Array [Vector3]:
	return [a, b]


func _ready() -> void:
	_lay()


func centreline() -> PackedVector3Array:
	var out:= PackedVector3Array([laid_start()])
	if bend_tangent > 0.0 and bend_out != Vector3.ZERO:
		var tail:= laid_end()
		var head:= b + bend_out * bend_tangent
		var turn:= forward.angle_to(bend_out)
		var steps:= clampi(int(ceil(turn / Cfg.BELT_CORNER_STEP)), 2, 12)


		var arc:= ConveyorCorner.arc_of(tail, b, head)
		out.append_array(ConveyorCorner.arc_points(arc, tail, head, steps))
	else:
		out.append(b)
	return out


func centreline_length() -> float:
	return 0.0 if _cum.is_empty() else _cum [_cum.size() - 1]


func _lay() -> void:
	_clear()
	_line = centreline()
	if _line.size() < 2:
		return
	_cum = PackedFloat32Array()
	_cum.resize(_line.size())
	_cum [0] = 0.0
	for i in range(1, _line.size()):
		_cum [i] = _cum [i - 1] + _line [i - 1].distance_to(_line [i])


	_sections = Node3D.new()
	_sections.name = "Pipe"
	_sections.top_level = true
	add_child(_sections)
	_bodies = Node3D.new()
	_bodies.name = "Bodies"
	_bodies.top_level = true
	add_child(_bodies)

	var xforms: Array [Transform3D] = []
	section_stations = PackedFloat32Array()
	section_pitches = PackedFloat32Array()


	var over:= Cfg.PIPE_JOINT_OVERLAP
	for i in _line.size() - 1:
		var dir:= _line [i + 1] - _line [i]
		if dir.length_squared() < 1e-08:
			continue
		dir = dir.normalized()
		var p0: Vector3 = _line [i] - dir * over
		var p1: Vector3 = _line [i + 1] + dir * over
		var span:= p0.distance_to(p1)
		var basis:= BeltPath.run_basis(p0, p1)


		var n:= maxi(1, int(round(span / Cfg.BELT_SEGMENT)))
		var pitch:= span / float(n)
		var scale:= Vector3(1.0, 1.0, pitch / Cfg.BELT_SEGMENT)
		for k in n:
			var centre:= p0.lerp(p1, (k + 0.5) / float(n))
			xforms.append(Transform3D(basis.scaled_local(scale), centre))
			section_stations.append(_cum [i] - over + pitch * (k + 0.5))
			section_pitches.append(pitch)
		_add_span(basis, (p0 + p1) * 0.5, span)


		if i == 0:
			_straight_count = xforms.size()


	var win:= _window_index()
	var pipe: Array [Transform3D] = []
	var bends: Array [Transform3D] = []
	for i in xforms.size():
		if i == win:
			continue
		if i < _straight_count:
			pipe.append(xforms [i])
		else:
			bends.append(xforms [i])
	_add_mm(_sections, "Sections", PipeKit.section_mesh(), pipe)
	if not bends.is_empty():
		_sections.add_child(_mm("Bend", PipeKit.bend_mesh(), bends))
	if win >= 0:
		var one: Array [Transform3D] = [xforms [win]]
		_sections.add_child(_mm("Window", PipeKit.window_mesh(), one))


		var water:= MeshInstance3D.new()
		water.name = "Water"
		water.mesh = PipeKit.water_mesh()
		_water_material = PipeKit.make_flow_material()
		water.material_override = _water_material
		water.top_level = true
		_sections.add_child(water)
		water.global_transform = xforms [win]
		_apply_flow()


	call_deferred("refresh_supports")


func _window_index() -> int:
	if section_stations.is_empty() or _straight_count < 2:
		return -1
	var want: float = _cum [_cum.size() - 1] * 0.5
	var best:= -1
	var fallback:= 0


	for i in mini(_straight_count, section_stations.size()):
		if absf(section_stations [i] - want) < absf(section_stations [fallback] - want):
			fallback = i
		if absf(section_pitches [i] - Cfg.BELT_SEGMENT) > Cfg.BELT_SEGMENT * 0.15:
			continue
		if best < 0 or absf(section_stations [i] - want) < absf(section_stations [best] - want):
			best = i
	return best if best >= 0 else fallback


func _add_span(basis: Basis, centre: Vector3, span: float) -> void:
	var body:= StaticBody3D.new()
	body.name = "Main"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	_bodies.add_child(body)
	body.global_transform = Transform3D(basis, centre)
	var shape:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(PipeKit.PIPE_R * 2.0, PipeKit.PIPE_R * 2.0, span)
	shape.shape = box
	body.add_child(shape)


static func _add_mm(parent: Node, mm_name: String, mesh: Mesh,
		xforms: Array [Transform3D]) -> void:
	if xforms.is_empty() and not _keep_empty_mm:
		return
	parent.add_child(_mm(mm_name, mesh, xforms))


static func _mm(mm_name: String, mesh: Mesh,
		xforms: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.top_level = true
	return mmi


func _clear() -> void:
	for node: Node3D in [_sections, _supports, _bodies]:
		if node != null:
			remove_child(node)
			node.queue_free()
	_sections = null
	_supports = null
	_bodies = null
	_water_material = null


func refresh_supports() -> void:
	if not is_inside_tree():
		return
	if _supports != null:
		remove_child(_supports)
		_supports.queue_free()
		_supports = null
	placed_stations.clear()
	if _line.size() < 2:
		return
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	var saddles: Array [Transform3D] = []
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	var wanted:= support_stations()
	for want: float in wanted:
		var s:= _off_the_belts(space, own, want, wanted)


		if s < 0.0:
			continue
		placed_stations.append(s)
		var at:= _walk(s)
		var frame: Basis = at ["basis"]
		var axis: Vector3 = at ["point"]


		saddles.append(Transform3D(frame, axis))


		var top: Vector3 = axis - frame.y * PipeKit.SUPPORT_ATTACH
		var yaw:= _upright_basis(frame.z)
		var hit:= _drop_ray(space, own, top)
		if hit.is_empty():
			continue
		var ground: Vector3 = hit ["position"]
		var drop: float = top.y - ground.y
		if drop < 0.05:
			continue
		legs.append(Transform3D(yaw.scaled_local(Vector3(1, drop, 1)), top))
		feet.append(Transform3D(yaw, ground))

	_supports = Node3D.new()
	_supports.name = "Supports"
	_supports.top_level = true
	add_child(_supports)
	_add_mm(_supports, "Saddles", PipeKit.saddle_mesh(), saddles)
	_add_mm(_supports, "Legs", PipeKit.leg_mesh(), legs)
	_add_mm(_supports, "Feet", PipeKit.foot_mesh(), feet)


func _drop_ray(space: PhysicsDirectSpaceState3D, own: Array [RID],
		top: Vector3) -> Dictionary:
	var q:= PhysicsRayQueryParameters3D.create(top,
		top - Vector3(0, Cfg.BELT_SUPPORT_MAX_DROP, 0))


	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD


	q.exclude = own
	return space.intersect_ray(q)


func _off_the_belts(space: PhysicsDirectSpaceState3D, own: Array [RID],
		want: float, wanted: Array [float]) -> float:
	var total: float = _cum [_cum.size() - 1]
	var reach:= Cfg.PIPE_SUPPORT_SPACING * 0.5
	var taken: Array [float] = []
	for other: float in wanted:
		if absf(other - want) > 0.01:
			taken.append(other)
	taken.append_array(placed_stations)
	if joined_start:
		taken.append(0.0)
	if joined_end:
		taken.append(total)

	var candidates: Array [float] = [want]
	var mid:= (PipeKit.GRIP_LO + PipeKit.GRIP_HI) * 0.5
	for i in section_stations.size():
		var pitch: float = section_pitches [i]
		for f: float in [PipeKit.GRIP_LO, mid, PipeKit.GRIP_HI]:
			var s: float = section_stations [i] + f * pitch
			if s >= 0.0 and s <= total and absf(s - want) <= reach:
				candidates.append(s)
	candidates.sort_custom(func(x: float, y: float) -> bool: return absf(x - want) < absf(y - want))

	for s: float in candidates:
		var crowded:= false
		for other: float in taken:
			if absf(other - s) < TRESTLE_GAP:
				crowded = true
				break
		if not crowded and not _over_a_belt(space, own, s):
			return s
	return -1.0


func _over_a_belt(space: PhysicsDirectSpaceState3D, own: Array [RID],
		s: float) -> bool:
	var at:= _walk(s)
	var frame: Basis = at ["basis"]
	var top: Vector3 = (at ["point"] as Vector3) - frame.y * PipeKit.SUPPORT_ATTACH
	var yaw:= _upright_basis(frame.z)
	var offsets: Array [Vector3] = [Vector3.ZERO,
		yaw.x * BELT_CLEAR, yaw.x * - BELT_CLEAR,
		yaw.z * BELT_CLEAR, yaw.z * - BELT_CLEAR]
	for offset: Vector3 in offsets:
		var hit:= _drop_ray(space, own, top + offset)
		if not hit.is_empty() and _is_belt(hit ["collider"] as Node):
			return true
	return false


static func _is_belt(node: Node) -> bool:
	var n:= node
	while n != null:
		if n is BeltPath or n is ConveyorSplitter or n is ConveyorJoiner:
			return true
		n = n.get_parent()
	return false


func support_stations() -> Array [float]:
	var out: Array [float] = []
	if _cum.is_empty():
		return out
	var total: float = _cum [_cum.size() - 1]
	if total <= 0.0:
		return out
	var n:= maxi(1, int(round(total / Cfg.PIPE_SUPPORT_SPACING)))
	for i in n + 1:


		if i == 0 and joined_start:
			continue


		if i == n and joined_end:
			continue
		var s:= _grip_slide(total * float(i) / float(n))


		if s < 0.0 or s > total:
			continue
		var duplicate_of:= false
		for got: float in out:
			if absf(got - s) < 0.05:
				duplicate_of = true
				break
		if not duplicate_of:
			out.append(s)
	return out


func _grip_slide(s: float) -> float:
	if section_stations.is_empty():
		return s
	var best_i:= 0
	for i in section_stations.size():
		if absf(section_stations [i] - s) < absf(section_stations [best_i] - s):
			best_i = i
	var pitch: float = section_pitches [best_i]
	var local: float = s - section_stations [best_i]
	var lo:= PipeKit.GRIP_LO * pitch
	var hi:= PipeKit.GRIP_HI * pitch
	if local >= lo and local <= hi:
		return s
	var best:= lo
	for cand: float in [lo, hi, lo + pitch, hi - pitch]:
		if absf(cand - local) < absf(best - local):
			best = cand
	return s + best - local


func _walk(along: float) -> Dictionary:
	var left:= maxf(along, 0.0)
	for i in _line.size() - 1:
		var p:= _line [i]
		var q:= _line [i + 1]
		var span:= p.distance_to(q)
		if span < 0.0001:
			continue
		if left <= span or i == _line.size() - 2:
			return { "point": p.lerp(q, clampf(left / span, 0.0, 1.0)),
				"basis": BeltPath.run_basis(p, q) }
		left -= span
	return { "point": _line [0], "basis": BeltPath.run_basis(a, b) }


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


static func _upright_basis(dir: Vector3) -> Basis:
	var fwd:= Vector3(dir.x, 0.0, dir.z)
	if fwd.length_squared() < 1e-08:
		fwd = Vector3.BACK
	fwd = fwd.normalized()
	return Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd)


func set_flow(fraction: float) -> void:
	flow = clampf(fraction, 0.0, 1.0)
	_apply_flow()


func _apply_flow() -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("flow", flow)


func to_dict() -> Dictionary:
	return { "type": "water_main", "a": a, "b": b, "paid": build_cost() }
