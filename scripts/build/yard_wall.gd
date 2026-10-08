class_name YardWall
extends StaticBody3D


var placement_preview:= false


static var _keep_empty_mm:= "--keepemptymm" in OS.get_cmdline_user_args()


var aim_marker:= false


enum Bay { SOLID, WINDOW, DOOR }


var kind:= Bay.SOLID

var a:= Vector3.ZERO
var b:= Vector3.ZERO
var length:= 0.0
var bays:= 0


var paid_cost:= -1.0

var _panels: MultiMeshInstance3D
var _posts: MultiMeshInstance3D


var shared_posts:= PackedInt32Array()
var _built:= { "a": Vector3.INF, "b": Vector3.INF, "kind": Bay.SOLID }
var _shapes: Array [CollisionShape3D] = []
var _preview_valid:= true


static func bays_for(metres: float, bay: Bay = Bay.SOLID) -> int:
	if bay == Bay.DOOR:
		return 1
	return clampi(int(round(absf(metres) / Cfg.WALL_PANEL)),
		int(Cfg.WALL_MIN_LENGTH / Cfg.WALL_PANEL),
		int(Cfg.WALL_MAX_LENGTH / Cfg.WALL_PANEL))


static func end_for(from: Vector3, to: Vector3, bay: Bay = Bay.SOLID) -> Vector3:
	var flat:= Vector3(to.x - from.x, 0.0, to.z - from.z)
	var span:= flat.length()
	if span < 0.0001:


		return from
	return from + flat / span * (float(bays_for(span, bay)) * Cfg.WALL_PANEL)


static func cost_for(from: Vector3, to: Vector3, bay: Bay = Bay.SOLID) -> float:
	return from.distance_to(end_for(from, to, bay)) * Cfg.WALL_COST_PER_M * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return length * Cfg.WALL_COST_PER_M * Tech.build_cost_scale()


func setup(from: Vector3, to: Vector3, bay: Bay = Bay.SOLID) -> void:
	kind = bay
	a = from
	b = end_for(from, to, bay)
	length = a.distance_to(b)
	bays = int(round(length / Cfg.WALL_PANEL))


	paid_cost = length * Cfg.WALL_COST_PER_M * Tech.build_cost_scale()


func _ready() -> void:
	_build_model()
	if placement_preview:
		set_preview_valid(true)


func set_shape(from: Vector3, to: Vector3) -> void:
	var end:= end_for(from, to, kind)
	if a.is_equal_approx(from) and b.is_equal_approx(end):
		return
	setup(from, to, kind)
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_kind(bay: Bay) -> void:
	if kind == bay:
		return
	setup(a, b, bay)
	_built ["a"] = Vector3.INF
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_aim_marker(on: bool) -> void:
	if aim_marker == on:
		return
	aim_marker = on
	_built ["a"] = Vector3.INF
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_shared_posts(skip: PackedInt32Array) -> void:
	if skip == shared_posts:
		return
	shared_posts = skip
	_built ["a"] = Vector3.INF
	_build_model()


func covers(point: Vector3) -> bool:
	if absf(point.y - a.y) > 0.05 or length < 1e-06:
		return false
	var along:= (b - a) / length
	var t:= (point - a).dot(along)
	if t < - Cfg.WALL_PANEL * 0.5 or t > length + Cfg.WALL_PANEL * 0.5:
		return false
	return (point - (a + along * clampf(t, 0.0, length))).length() < 0.4


func post_points() -> Array [Vector3]:
	var out: Array [Vector3] = []
	if length < 1e-06:
		out.append(a)
		return out
	var n:= maxi(1, bays)
	for i in n + 1:
		out.append(a.lerp(b, float(i) / float(n)))
	return out


func _bay_count() -> int:
	if aim_marker or length < 1e-06:
		return 0
	return maxi(1, bays)


func _build_model() -> void:


	collision_layer = 0 if placement_preview else Cfg.L_BUILD
	collision_mask = 0
	if a.is_equal_approx(_built ["a"]) and b.is_equal_approx(_built ["b"]) and int(_built ["kind"]) == kind and _panels != null:
		return
	_built = { "a": a, "b": b, "kind": kind }


	global_position = (a + b) * 0.5
	global_rotation = Vector3(0.0, _yaw(), 0.0)

	var n:= _bay_count()
	var half:= length * 0.5
	var panels: Array [Transform3D] = []
	for i in n:
		panels.append(Transform3D(Basis(),
			Vector3(0.0, 0.0, - half + Cfg.WALL_PANEL * (float(i) + 0.5))))
	var posts: Array [Transform3D] = []
	if aim_marker:


		posts.append(Transform3D())
	else:
		for i in n + 1:
			if shared_posts.has(i):
				continue
			posts.append(Transform3D(Basis(),
				Vector3(0.0, 0.0, - half + Cfg.WALL_PANEL * float(i))))

	_panels = _fit(_panels, "Bays", StructureKit.wall_panel_mesh(kind), panels)
	_posts = _fit(_posts, "Posts", StructureKit.wall_post_mesh(), posts)

	if placement_preview:
		_panels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	_build_collision(n, half)


	if n > 0 and _shapes.is_empty():
		push_error("YardWall: %d bays drawn at %s with no collider" % [n, a])


func _fit(node: MultiMeshInstance3D, node_name: String, mesh: Mesh,
		instances: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = instances.size()
	for i in instances.size():
		mm.set_instance_transform(i, instances [i])


	var shown:= _keep_empty_mm or not instances.is_empty()
	if node != null:
		node.multimesh = mm
		node.visible = shown
		return node
	var made:= MultiMeshInstance3D.new()
	made.name = node_name
	made.multimesh = mm
	made.visible = shown
	add_child(made)
	return made


func _build_collision(n: int, half: float) -> void:
	for shape in _shapes:
		remove_child(shape)
		shape.queue_free()
	_shapes.clear()


	if n <= 0:
		return
	var thick:= Cfg.WALL_COLLIDER_THICK
	if kind == Bay.SOLID:
		_add_shape(Vector3(thick, Cfg.WALL_HEIGHT, length),
			Vector3(0.0, Cfg.WALL_HEIGHT * 0.5, 0.0))
		return
	var door:= kind == Bay.DOOR
	var sill:= 0.0 if door else Cfg.WALL_WINDOW_SILL
	var head:= Cfg.WALL_DOOR_HEAD if door else Cfg.WALL_WINDOW_HEAD
	var width:= Cfg.WALL_DOOR_WIDTH if door else Cfg.WALL_WINDOW_WIDTH
	if sill > 0.0:
		_add_shape(Vector3(thick, sill, length), Vector3(0.0, sill * 0.5, 0.0))
	_add_shape(Vector3(thick, Cfg.WALL_HEIGHT - head, length),
		Vector3(0.0, (Cfg.WALL_HEIGHT + head) * 0.5, 0.0))


	var reveal:= (Cfg.WALL_PANEL - width) * 0.5
	for i in n + 1:
		var at:= - half + Cfg.WALL_PANEL * float(i)
		var lo:= maxf(at - reveal, - half)
		var hi:= minf(at + reveal, half)
		if hi - lo < 0.0001:
			continue
		_add_shape(Vector3(thick, head - sill, hi - lo),
			Vector3(0.0, (sill + head) * 0.5, (lo + hi) * 0.5))


func _add_shape(size: Vector3, at: Vector3) -> void:
	var box:= BoxShape3D.new()
	box.size = size
	var shape:= CollisionShape3D.new()
	shape.name = "WallCollision%d" % _shapes.size()
	shape.shape = box
	shape.position = at
	add_child(shape)
	_shapes.append(shape)


func _yaw() -> float:
	var dir:= b - a
	if absf(dir.x) < 1e-06 and absf(dir.z) < 1e-06:
		return 0.0
	return atan2(dir.x, dir.z)


func set_preview_valid(valid: bool) -> void:
	if not placement_preview:
		return
	_preview_valid = valid
	var material:= ConveyorKit.ghost_material(valid)
	if _panels != null:
		_panels.material_override = material
	if _posts != null:
		_posts.material_override = material


func to_dict() -> Dictionary:
	return { "type": "wall", "a": a, "b": b, "kind": int(kind),
		"paid": build_cost() }
