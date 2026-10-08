class_name Wheelbarrow
extends HayContainer


const MODEL:= "res://assets/models/wheelbarrow.glb"


const SCALE:= 0.688

const YAW:= - PI * 0.5


const FLOOR_Y:= 0.325
const RIM_Y:= 0.464
const FLOOR_HX:= 0.193
const FLOOR_Z0:= -0.413
const FLOOR_Z1:= 0.034
const RIM_HX:= 0.323
const RIM_Z0:= -0.654
const RIM_Z1:= 0.151

const AXLE:= Vector3(0.0, 0.166, -0.605)
const WHEEL_R:= 0.166
const WHEEL_T:= 0.107


const GRIP:= Vector3(0.0, 0.56, 0.63)
const LEG_X:= 0.172
const LEG_Y:= 0.088


const NOSE:= 1.4

const WALL_T:= 0.03
const MASS:= 15.0


const GROUP:= &"wheelbarrows"
const GEAR_GROUP:= &"barrow_gear"


func _init() -> void:
	add_to_group(GROUP)


static func keep_apart(body: PhysicsBody3D) -> void:
	var tree:= body.get_tree()
	if tree == null:
		return
	var others: Array [Node] = tree.get_nodes_in_group(GROUP)
	if body is Wheelbarrow:
		others.append_array(tree.get_nodes_in_group(GEAR_GROUP))
		others.append_array(tree.get_nodes_in_group(&"robotic_arms"))
	for other: Node in others:
		var o:= other as PhysicsBody3D
		if o == null or o == body or not is_instance_valid(o):
			continue
		body.add_collision_exception_with(o)
		o.add_collision_exception_with(body)


func size_node() -> String:
	return "barrow_size"


func size_scale() -> float:
	return Tech.barrow_scale()


func capacity() -> int:
	return Tech.barrow_capacity()


func pour_rate() -> float:
	return Tech.barrow_pour_rate()


func tip_start() -> float:
	return Cfg.BARROW_TIP_START


func tip_full() -> float:
	return Cfg.BARROW_TIP_FULL


func fill_instances() -> int:
	return Cfg.BARROW_FILL_INSTANCES


func container_noun() -> String:
	return tr("barrow")


func stays_upright() -> bool:
	return true


func _build_model() -> void:
	_rng.randomize()
	mass = MASS
	var pm:= PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.0
	physics_material_override = pm
	_mount_model(MODEL, Transform3D(Basis(Vector3.UP, YAW).scaled(Vector3.ONE * SCALE),
		Vector3.ZERO))
	_build_load()


func _build_shapes() -> void:
	var tray_z:= (FLOOR_Z0 + FLOOR_Z1) * 0.5

	_shape_box(Vector3(FLOOR_HX * 2.0, WALL_T, FLOOR_Z1 - FLOOR_Z0),
		Vector3(0.0, FLOOR_Y - WALL_T * 0.5, tray_z))


	var side_x:= (FLOOR_HX + RIM_HX) * 0.5
	var rim_z:= (RIM_Z0 + RIM_Z1) * 0.5
	for s in [-1.0, 1.0]:
		_shape_box(Vector3(WALL_T, RIM_Y - FLOOR_Y, RIM_Z1 - RIM_Z0),
			Vector3(side_x * s, (FLOOR_Y + RIM_Y) * 0.5, rim_z))

	_shape_box(Vector3(RIM_HX * 1.7, 0.16, WALL_T), Vector3(0.0, 0.405, RIM_Z0 + 0.03))
	_shape_box(Vector3(RIM_HX * 1.7, 0.13, WALL_T), Vector3(0.0, 0.39, RIM_Z1 - 0.03))


	_shape_cylinder(WHEEL_R, WHEEL_T, AXLE, Basis(Vector3(0, 0, 1), PI * 0.5))


	for s in [-1.0, 1.0]:
		_shape_box(Vector3(0.06, LEG_Y, 0.12), Vector3(LEG_X * s, LEG_Y * 0.5, -0.02))
	_shape_box(Vector3(0.7, 0.05, 0.26), Vector3(0.0, GRIP.y, GRIP.z + 0.02))

	_build_interior()


func _make_interior_shape() -> CollisionShape3D:
	var cs:= CollisionShape3D.new()
	var hull:= ConvexPolygonShape3D.new()
	var pts:= PackedVector3Array()
	for sx in [-1.0, 1.0]:
		pts.append(Vector3(FLOOR_HX * sx, FLOOR_Y - 0.005, FLOOR_Z0))
		pts.append(Vector3(FLOOR_HX * sx, FLOOR_Y - 0.005, FLOOR_Z1))

		pts.append(Vector3(RIM_HX * sx, RIM_Y + 0.021, RIM_Z0))
		pts.append(Vector3(RIM_HX * sx, RIM_Y + 0.021, RIM_Z1))
	hull.points = pts
	cs.shape = hull
	return cs


func _load_point(u: float, rng: RandomNumberGenerator) -> Vector3:
	var y:= lerpf(FLOOR_Y + 0.012, RIM_Y - 0.012, u)
	var t:= clampf(inverse_lerp(FLOOR_Y, RIM_Y, y), 0.0, 1.0)


	var margin: float = Cfg.STRAND_LEN_MAX * 0.45
	var hx: float = maxf(0.01, lerpf(FLOOR_HX, RIM_HX, t) - margin)
	var z0: float = lerpf(FLOOR_Z0, RIM_Z0, t) + margin
	var z1: float = lerpf(FLOOR_Z1, RIM_Z1, t) - margin
	if z1 < z0:
		z0 = (z0 + z1) * 0.5
		z1 = z0
	return Vector3(rng.randf_range(- hx, hx), y, rng.randf_range(z0, z1))


func _load_bounds() -> AABB:
	return AABB(Vector3(- RIM_HX, FLOOR_Y - 0.05, RIM_Z0),
		Vector3(RIM_HX * 2.0, RIM_Y - FLOOR_Y + 0.1, RIM_Z1 - RIM_Z0))


func _lip_point(spill: Vector3) -> Vector3:
	var hz:= (RIM_Z1 - RIM_Z0) * 0.5
	var cz:= (RIM_Z0 + RIM_Z1) * 0.5
	var s:= INF
	if absf(spill.x) > 0.0001:
		s = minf(s, RIM_HX / absf(spill.x))
	if absf(spill.z) > 0.0001:
		s = minf(s, hz / absf(spill.z))
	if not is_finite(s):
		s = hz
	return Vector3(spill.x * s, RIM_Y, cz + spill.z * s)


func carry_mode() -> Mode:
	return Mode.PUSHED


func carry_pivot() -> Vector3:
	return GRIP * size_scale()


func tilt_pivot() -> Vector3:
	return AXLE * size_scale()


func tilt_limits() -> Vector3:
	return Vector3(Cfg.BARROW_TILT_LIMIT, 0.0, 0.0)


func push_reach() -> float:
	return NOSE


func interact_verb() -> String:
	return tr("Drive")
