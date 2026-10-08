class_name Bucket
extends HayContainer


const MODEL:= "res://assets/models/bucket.glb"


const SPEC:= "res://assets/models/bucket_materials.json"


const BASE_Y:= 0.024
const RIM_Y:= 0.3523
const R_BOTTOM:= 0.1273
const R_RIM:= 0.1891
const WALL_T:= 0.03
const HANDLE_TOP:= 0.5306


const WALL_PANELS:= 8

const MASS:= 1.6


func size_node() -> String:
	return "bucket_size"


func size_scale() -> float:
	return Tech.bucket_scale()


func capacity() -> int:
	return Tech.bucket_capacity()


func pour_rate() -> float:
	return Tech.bucket_pour_rate()


func tip_start() -> float:
	return Cfg.BUCKET_TIP_START


func tip_full() -> float:
	return Cfg.BUCKET_TIP_FULL


func fill_instances() -> int:
	return Cfg.BUCKET_FILL_INSTANCES


func impact_sfx() -> String:
	return "item_clatter"


func container_noun() -> String:
	return tr("bucket")


func stays_upright() -> bool:
	return true


func impact_min_dv() -> float:
	return IMPACT_MIN_DV if is_tumbling() else 2.2


func _build_model() -> void:
	_rng.randomize()
	mass = MASS
	var pm:= PhysicsMaterial.new()
	pm.friction = 0.85
	pm.bounce = 0.0
	physics_material_override = pm
	_mount_model(MODEL, Transform3D.IDENTITY)
	_skin()
	_build_load()


func _skin() -> void:
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("Bucket: no material table at %s, the bucket will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for mi in _meshes:
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return HayCompressor.make_material(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mi.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("Bucket: no table entry for %s" % ", ".join(missed.keys()))


static var _spec_cache: Dictionary = { }


static func spec_table() -> Dictionary:
	if not _spec_cache.is_empty():
		return _spec_cache


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_spec_cache = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_spec_cache = parsed
	return _spec_cache


func _build_shapes() -> void:


	_shape_cylinder(R_BOTTOM * 0.92, BASE_Y, Vector3(0, BASE_Y * 0.5, 0))


	var lean:= atan((R_RIM - R_BOTTOM) / (RIM_Y - BASE_Y))
	var wall_h:= (RIM_Y - BASE_Y) / cos(lean)
	var r_mid:= (R_BOTTOM + R_RIM) * 0.5 - WALL_T * 0.5
	var y_mid:= (BASE_Y + RIM_Y) * 0.5


	var chord:= 2.0 * r_mid * sin(PI / float(WALL_PANELS)) * 1.25
	for i in WALL_PANELS:
		var a:= TAU * float(i) / float(WALL_PANELS)
		var out:= Vector3(cos(a), 0.0, sin(a))
		var tangent:= Vector3(- sin(a), 0.0, cos(a))

		var along:= (Vector3.UP + out * tan(lean)).normalized()


		var b:= Basis(tangent, along, tangent.cross(along))
		_shape_box(Vector3(chord, wall_h, WALL_T), out * r_mid + Vector3.UP * y_mid, b)

	_build_interior()


func _make_interior_shape() -> CollisionShape3D:
	var cs:= CollisionShape3D.new()
	var hull:= ConvexPolygonShape3D.new()
	hull.points = _cone_points(inner_radius(BASE_Y), inner_radius(RIM_Y),
		BASE_Y, RIM_Y + 0.02)
	cs.shape = hull
	return cs


static func _cone_points(r0: float, r1: float, y0: float, y1: float) -> PackedVector3Array:
	var pts:= PackedVector3Array()
	for i in 12:
		var a:= TAU * float(i) / 12.0
		var c:= Vector3(cos(a), 0.0, sin(a))
		pts.append(c * r0 + Vector3.UP * y0)
		pts.append(c * r1 + Vector3.UP * y1)
	return pts


static func inner_radius(y: float) -> float:
	var t:= clampf(inverse_lerp(BASE_Y, RIM_Y, y), 0.0, 1.0)
	return lerpf(R_BOTTOM, R_RIM, t) - WALL_T


func _load_point(u: float, rng: RandomNumberGenerator) -> Vector3:
	var y:= lerpf(BASE_Y + 0.01, RIM_Y - 0.015, u)


	var r: float = maxf(0.0, inner_radius(y) - Cfg.STRAND_LEN_MAX * 0.45)
	var a:= rng.randf() * TAU
	var d:= sqrt(rng.randf()) * r
	return Vector3(cos(a) * d, y, sin(a) * d)


func _load_bounds() -> AABB:
	return AABB(Vector3(- R_RIM, 0.0, - R_RIM),
		Vector3(R_RIM * 2.0, RIM_Y, R_RIM * 2.0))


func _lip_point(spill: Vector3) -> Vector3:
	return spill * (R_RIM - WALL_T * 0.5) + Vector3.UP * RIM_Y


func carry_pivot() -> Vector3:
	return Vector3(0.0, RIM_Y * 0.72, 0.0) * size_scale()


func carry_yaw() -> float:
	return PI * 0.5
