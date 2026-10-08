class_name EnclosedConveyor
extends Conveyor


static func cost_for(from: Vector3, to: Vector3) -> float:
	return from.distance_to(to) * Cfg.ENCLOSED_BELT_COST_PER_M * Tech.build_cost_scale()


func setup(from: Vector3, to: Vector3) -> void:
	super (from, to)
	paid_cost = cost_for(a, b)


func build_cost() -> float:
	return paid_cost if paid_cost >= 0.0 else cost_for(a, b)


func _ready() -> void:


	record_only = true
	loose_mouth = MOUTH
	loose_tail = MOUTH
	super ()


func _lay() -> void:
	super ()
	set_belt_drawn(false)


	BeltRunBatch.unwatch(run)
	_fit_aim_volume()
	_fit_roof()


func _fit_aim_volume() -> void:
	var aim:= get_node_or_null("ShellAim") as Area3D
	if aim == null:
		aim = Area3D.new()
		aim.name = "ShellAim"
		aim.top_level = true
		aim.collision_layer = Cfg.L_BUILD
		aim.collision_mask = 0
		aim.monitoring = false
		var shape:= CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		aim.add_child(shape)
		add_child(aim)
	var from:= laid_start()
	var to:= laid_end()
	var along:= to - from
	if along.length() < 0.01:
		return
	var ahead:= along.normalized()
	var right:= ahead.cross(Vector3.UP).normalized()
	var up:= right.cross(ahead).normalized()


	var box:= (aim.get_child(0) as CollisionShape3D).shape as BoxShape3D
	box.size = Vector3(0.96, 0.92, along.length())
	aim.global_transform = Transform3D(Basis(right, up, - ahead),
		(from + to) * 0.5 + up * 0.23)


const MOUTH:= 0.6


func set_open_ends(intake: bool, outlet: bool) -> void:
	var mouth:= MOUTH if intake else -1.0
	var tail:= MOUTH if outlet else -1.0
	if mouth == loose_mouth and tail == loose_tail:
		return
	loose_mouth = mouth
	loose_tail = tail
	_fit_roof()


const CASING_HALF_WIDTH:= 0.48
const CASING_BELOW:= 0.23
const CASING_ABOVE:= 0.69


const MOUTH_CLEAR_HALF_WIDTH:= 0.405
const MOUTH_CLEAR_HEIGHT:= 0.62


func _fit_roof() -> void:
	if not is_inside_tree():
		return
	var shapes:= casing_body(self, "ShellRoof", 7).get_children()
	var from:= laid_start()
	var to:= laid_end()
	var length:= from.distance_to(to)
	var start:= maxf(loose_mouth, 0.0)
	var end:= length - maxf(loose_tail, 0.0)
	fit_casing_box(shapes [0], from, to, start, end,
		- CASING_HALF_WIDTH, CASING_HALF_WIDTH, - CASING_BELOW, CASING_ABOVE)
	_fit_mouth(shapes, 1, from, to, 0.0, minf(start, length))
	_fit_mouth(shapes, 4, from, to, maxf(end, 0.0), length)


func _fit_mouth(shapes: Array [Node], first: int, from: Vector3, to: Vector3,
		s0: float, s1: float) -> void:
	fit_casing_box(shapes [first], from, to, s0, s1, - CASING_HALF_WIDTH,
		- MOUTH_CLEAR_HALF_WIDTH, - CASING_BELOW, CASING_ABOVE)
	fit_casing_box(shapes [first + 1], from, to, s0, s1, MOUTH_CLEAR_HALF_WIDTH,
		CASING_HALF_WIDTH, - CASING_BELOW, CASING_ABOVE)
	fit_casing_box(shapes [first + 2], from, to, s0, s1, - MOUTH_CLEAR_HALF_WIDTH,
		MOUTH_CLEAR_HALF_WIDTH, MOUTH_CLEAR_HEIGHT, CASING_ABOVE)


static func casing_body(owner_node: Node3D, body_name: String, count: int) -> StaticBody3D:
	var body:= owner_node.get_node_or_null(body_name) as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = body_name
		body.top_level = true
		body.collision_layer = Cfg.L_BUILD
		body.collision_mask = 0
		owner_node.add_child(body)
	while body.get_child_count() < count:
		var shape:= CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
	for i in body.get_child_count():
		(body.get_child(i) as CollisionShape3D).disabled = i >= count
	body.global_transform = Transform3D.IDENTITY
	return body


static func fit_casing_box(node: Node, from: Vector3, to: Vector3,
		s0: float, s1: float, x0: float, x1: float, y0: float, y1: float) -> void:
	var shape:= node as CollisionShape3D
	var along:= to - from
	shape.disabled = s1 - s0 < 0.05 or along.length() < 0.01
	if shape.disabled:
		return
	var ahead:= along.normalized()
	var right:= ahead.cross(Vector3.UP).normalized()
	var up:= right.cross(ahead).normalized()
	(shape.shape as BoxShape3D).size = Vector3(x1 - x0, y1 - y0, s1 - s0)
	shape.transform = Transform3D(Basis(right, up, - ahead), from
		+ ahead * ((s0 + s1) * 0.5) + right * ((x0 + x1) * 0.5) + up * ((y0 + y1) * 0.5))


func _refresh_drums() -> void:
	pass


func refresh_supports() -> void:


	if absf(forward.y) > 0.01:
		super ()


func to_dict() -> Dictionary:
	var d:= { "type": "enclosed_conveyor", "a": a, "b": b, "paid": build_cost() }
	if line_id != 0:
		d ["line"] = line_id
	return d
