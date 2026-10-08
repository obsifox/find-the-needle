class_name Railing
extends StaticBody3D


const COLLIDER_THICK:= 0.14

var placement_preview:= false


var aim_marker:= false

var a:= Vector3.ZERO
var b:= Vector3.ZERO
var length:= 0.0


var paid_cost:= -1.0

var _posts: MultiMeshInstance3D
var _rail: MeshInstance3D
var _collision: CollisionShape3D
var _shape: BoxShape3D
var _built:= { "a": Vector3.INF, "b": Vector3.INF }
var _preview_valid:= true


static func cost_for(from: Vector3, to: Vector3) -> float:
	return _level(from, to).distance_to(from) * Cfg.RAILING_COST_PER_M * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return cost_for(a, b)


static func _level(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x, from.y, to.z)


func setup(from: Vector3, to: Vector3) -> void:
	a = from
	b = _level(from, to)
	length = a.distance_to(b)


	paid_cost = cost_for(a, b)


func _ready() -> void:
	collision_layer = 0 if placement_preview else Cfg.L_BUILD
	collision_mask = 0
	_build_model()
	if placement_preview:
		set_preview_valid(true)


func set_shape(from: Vector3, to: Vector3) -> void:
	var levelled:= _level(from, to)
	if a.is_equal_approx(from) and b.is_equal_approx(levelled):
		return
	a = from
	b = levelled
	length = a.distance_to(b)
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_aim_marker(on: bool) -> void:
	if aim_marker == on:
		return
	aim_marker = on
	_built = { "a": Vector3.INF, "b": Vector3.INF }
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func covers(point: Vector3) -> bool:
	if absf(point.y - a.y) > 0.05 or length < 1e-06:
		return false
	var along:= (b - a) / length
	var t:= (point - a).dot(along)
	if t < - Cfg.RAILING_MIN_LENGTH * 0.5 or t > length + Cfg.RAILING_MIN_LENGTH * 0.5:
		return false
	return (point - (a + along * clampf(t, 0.0, length))).length() < 0.4


func _build_model() -> void:
	if a.is_equal_approx(_built ["a"]) and b.is_equal_approx(_built ["b"]) and _posts != null:
		return
	_built = { "a": a, "b": b }


	global_position = (a + b) * 0.5
	global_rotation = Vector3(0.0, _yaw(), 0.0)

	var posts: Array [Transform3D] = []
	if aim_marker:


		posts.append(Transform3D())
	else:
		var n:= maxi(1, int(round(length / Cfg.PLATFORM_RAIL_POST_SPACING)))
		for i in n + 1:

			posts.append(Transform3D(Basis(),
				Vector3(0.0, 0.0, - length * 0.5 + length * (float(i) / float(n)))))
	if _posts != null:
		remove_child(_posts)
		_posts.queue_free()
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = StructureKit.rail_post_mesh()
	mm.instance_count = posts.size()
	for i in posts.size():
		mm.set_instance_transform(i, posts [i])
	_posts = MultiMeshInstance3D.new()
	_posts.name = "Posts"
	_posts.multimesh = mm
	add_child(_posts)

	if _rail != null:
		remove_child(_rail)
		_rail.queue_free()
	_rail = MeshInstance3D.new()
	_rail.name = "Rail"
	_rail.mesh = StructureKit.rail_mesh()
	_rail.transform = Transform3D(
		Basis().scaled(Vector3(1.0, 1.0, maxf(length, 0.01))),
		Vector3(0.0, Cfg.PLATFORM_RAIL_H - StructureKit.RAIL_SECTION * 0.5, 0.0))


	_rail.visible = not aim_marker
	add_child(_rail)

	if placement_preview:
		_posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return

	if _shape == null:
		_shape = BoxShape3D.new()
		_collision = CollisionShape3D.new()
		_collision.name = "BarrierCollision"
		_collision.shape = _shape
		add_child(_collision)


	_shape.size = Vector3(COLLIDER_THICK, Cfg.PLATFORM_RAIL_H, maxf(length, 0.01))
	_collision.position = Vector3(0.0, Cfg.PLATFORM_RAIL_H * 0.5, 0.0)


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
	if _posts != null:
		_posts.material_override = material
	if _rail != null:
		_rail.material_override = material


func to_dict() -> Dictionary:
	return { "type": "railing", "a": a, "b": b, "paid": build_cost() }
