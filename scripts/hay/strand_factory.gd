class_name StrandFactory
extends RefCounted


static var _strand_mesh: ArrayMesh
static var _strand_outline_mesh: ArrayMesh
static var _needle_mesh: BoxMesh
static var _needle_model: ArrayMesh
static var _hay_mat: ShaderMaterial
static var _needle_mat: StandardMaterial3D
static var _strand_shapes: Array [BoxShape3D] = []


static func strand_mesh() -> ArrayMesh:
	if _strand_mesh == null:
		var t: float = Cfg.STRAND_THICK * 0.5


		var l: float = Cfg.STRAND_LENGTH * 0.5

		var verts:= PackedVector3Array([
			Vector3(- t, 0.0, - l), Vector3(t, 0.0, - l),
			Vector3(t, 0.0, l), Vector3(- t, 0.0, l),
		])
		var norms:= PackedVector3Array([
			Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
		])
		var tans:= PackedFloat32Array()
		for i in 4:
			tans.append_array(PackedFloat32Array([0.0, 0.0, 1.0, 1.0]))
		var idx:= PackedInt32Array([0, 2, 1, 0, 3, 2])
		_strand_mesh = _strand_surface(verts, norms, tans, idx)


		_strand_mesh.custom_aabb = AABB(
			Vector3(- t, - t, - l), Vector3(t * 2.0, t * 2.0, l * 2.0))
	return _strand_mesh


static func strand_outline_mesh() -> ArrayMesh:
	if _strand_outline_mesh == null:
		var t: float = Cfg.STRAND_THICK * 0.5
		var l: float = Cfg.STRAND_LENGTH * 0.5
		var verts:= PackedVector3Array([
			Vector3(- t, 0.0, - l), Vector3(t, 0.0, - l),
			Vector3(t, 0.0, l), Vector3(- t, 0.0, l),
			Vector3(0.0, - t, - l), Vector3(0.0, t, - l),
			Vector3(0.0, t, l), Vector3(0.0, - t, l),
		])
		var norms:= PackedVector3Array([
			Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
			Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT,
		])
		var tans:= PackedFloat32Array()
		for i in 8:
			tans.append_array(PackedFloat32Array([0.0, 0.0, 1.0, 1.0]))
		var idx:= PackedInt32Array([
			0, 2, 1, 0, 3, 2,
			4, 5, 6, 4, 6, 7,
		])
		_strand_outline_mesh = _strand_surface(verts, norms, tans, idx)
	return _strand_outline_mesh


static func _strand_surface(verts: PackedVector3Array, norms: PackedVector3Array,
		tans: PackedFloat32Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = norms
	arrays [Mesh.ARRAY_TANGENT] = tans
	arrays [Mesh.ARRAY_INDEX] = idx
	var m:= ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, hay_material())
	return m


static func bucket_length(bucket: int) -> float:
	var n: int = Cfg.STRAND_LEN_BUCKETS
	if n <= 1:
		return Cfg.STRAND_LENGTH
	var t:= float(clampi(bucket, 0, n - 1)) / float(n - 1)
	return lerpf(Cfg.STRAND_LEN_MIN, Cfg.STRAND_LEN_MAX, t)


static func strand_shape(bucket: int = -1) -> BoxShape3D:
	if _strand_shapes.is_empty():
		for i in Cfg.STRAND_LEN_BUCKETS:
			var sh:= BoxShape3D.new()
			sh.size = Vector3(Cfg.STRAND_THICK, Cfg.STRAND_THICK, bucket_length(i))
			_strand_shapes.append(sh)
	if bucket < 0:
		bucket = Cfg.STRAND_LEN_BUCKETS / 2
	return _strand_shapes [clampi(bucket, 0, _strand_shapes.size() - 1)]


static func random_length_scale(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(Cfg.STRAND_LEN_MIN, Cfg.STRAND_LEN_MAX) / Cfg.STRAND_LENGTH


static func hay_material() -> ShaderMaterial:
	if _hay_mat == null:
		var m:= ShaderMaterial.new()
		m.shader = load("res://assets/hay_strand.gdshader")
		set_highlight(Vector3.ZERO, 0.0, m)
		_hay_mat = m
	return _hay_mat


static func set_highlight(center: Vector3, radius: float, mat: ShaderMaterial = null) -> void:
	var m:= mat if mat != null else hay_material()
	m.set_shader_parameter("highlight_center", center)
	m.set_shader_parameter("highlight_radius", radius)


static var _shadow_mat: ShaderMaterial


static func shadow_proxy_material() -> ShaderMaterial:
	if _shadow_mat == null:
		var m:= ShaderMaterial.new()
		m.shader = load("res://assets/hay_shadow_proxy.gdshader")
		m.set_shader_parameter("shell_depth", Cfg.HAY_SHELL_DEPTH)
		m.set_shader_parameter("inset", 0.12)
		_shadow_mat = m
	return _shadow_mat


static var _surface_mat: ShaderMaterial


static func reset_pile_render_resources() -> void:
	_surface_mat = null
	_shadow_mat = null


static func pile_surface_material() -> ShaderMaterial:
	if _surface_mat == null:


		var m:= ShaderMaterial.new()
		m.shader = load("res://assets/hay_shells.gdshader")
		m.set_shader_parameter("shell_count", Cfg.HAY_SHELLS)
		m.set_shader_parameter("shell_depth", Cfg.HAY_SHELL_DEPTH)
		m.set_shader_parameter("strands_per_m", 115.0)
		m.set_shader_parameter("thickness", 0.62)
		m.set_shader_parameter("height_bias", 1.25)
		m.set_shader_parameter("hay_light", Cfg.COL_HAY_LIGHT)
		m.set_shader_parameter("hay_dark", Cfg.COL_HAY_DARK)


		m.set_shader_parameter("core_shade", 0.2)


		m.set_shader_parameter("solid_core", true)
		m.set_shader_parameter("debug_flat", false)
		_surface_mat = m
	return _surface_mat


const NEEDLE_LENGTH:= 0.18
const NEEDLE_SHAFT_R:= 0.0042
const NEEDLE_HEAD_LEN:= 0.062
const NEEDLE_HEAD_W:= 0.0078
const NEEDLE_HEAD_T:= 0.0032
const NEEDLE_EYE_LEN:= 0.03
const NEEDLE_EYE_W:= 0.0028


const NEEDLE_GLINT:= Color(0.55, 0.62, 0.75)
const NEEDLE_GLINT_ENERGY:= 0.14

const _NEEDLE_RADIAL:= 12
const _NEEDLE_PLATE_STEPS:= 40


const _NEEDLE_OUTLINE: Array = [
	Vector2(0.0, 0.5), Vector2(0.14, 0.72), Vector2(0.3, 0.9),
	Vector2(0.5, 1.0), Vector2(0.74, 0.99), Vector2(0.88, 0.92),
	Vector2(0.945, 0.78), Vector2(0.975, 0.6), Vector2(0.993, 0.36),
	Vector2(1.0, 0.0),
]


static var _kit: Dictionary = { }


static func _specimen_kit(type: int) -> Dictionary:
	if _kit.has(type):
		return _kit [type]
	var out:= {
		"mesh": _fallback_model(),
		"xform": Transform3D.IDENTITY,
		"extents": Vector3(NEEDLE_HEAD_W, NEEDLE_SHAFT_R, NEEDLE_LENGTH * 0.5),
	}
	var m: Mesh = NeedleCabinet.type_mesh(type) if type >= 0 else null
	if m != null:


		var s:= NEEDLE_LENGTH / NeedleTypes.specimen_length()
		var xf:= Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5).scaled(Vector3(s, s, s)),
			Vector3.ZERO)
		var box: AABB = xf * m.get_aabb()


		xf.origin = - box.get_center()
		out = {
			"mesh": m,
			"xform": xf,


			"extents": box.size * 0.5,
			"mats": _field_materials(m),
		}
	_kit [type] = out
	return out


static var _field_mats: Dictionary = { }


static func _field_materials(m: Mesh) -> Array [Material]:
	var out: Array [Material] = []
	for s in m.get_surface_count():
		var src: Material = m.surface_get_material(s)
		var key:= src.resource_name if src != null else ""
		if not _field_mats.has(key):
			_field_mats [key] = _field_material(key)
		out.append(_field_mats [key])
	return out


static func _field_material(key: String) -> StandardMaterial3D:
	var f:= NeedleCabinet.flat_spec(key)
	var c:= Cfg.COL_NEEDLE
	if f.has("color"):
		var a: Array = f ["color"]
		c = Color(float(a [0]), float(a [1]), float(a [2]))
	var m:= StandardMaterial3D.new()
	m.resource_name = key
	var alpha:= float(f.get("alpha", 1.0))
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.metallic = float(f.get("metal", 1.0))
	m.roughness = float(f.get("rough", 0.16))
	m.metallic_specular = 0.4
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED


	m.emission_enabled = true
	m.emission = c.lerp(NEEDLE_GLINT, 0.55)
	m.emission_energy_multiplier = NEEDLE_GLINT_ENERGY + float(f.get("emit", 0.0))
	return m


static func needle_mesh(type: int = -1) -> BoxMesh:
	var kit:= _specimen_kit(type)
	if not kit.has("box"):
		var bm:= BoxMesh.new()
		bm.size = (kit ["extents"] as Vector3) * 2.0
		bm.material = needle_material()
		kit ["box"] = bm
	return kit ["box"]


static func needle_extents(type: int = -1) -> Vector3:
	return _specimen_kit(type) ["extents"]


static func needle_visual_xform(type: int = -1) -> Transform3D:
	return _specimen_kit(type) ["xform"]


static func needle_model(type: int = -1) -> Mesh:
	return _specimen_kit(type) ["mesh"]


static func needle_surface_materials(type: int = -1) -> Array [Material]:
	var kit:= _specimen_kit(type)
	return kit ["mats"] if kit.has("mats") else ([] as Array [Material])


static func _fallback_model() -> ArrayMesh:
	if _needle_model == null:
		_needle_model = _build_needle()
	return _needle_model


static func _build_needle() -> ArrayMesh:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_needle_shank(st)
	_needle_eye(st)
	st.set_material(needle_material())
	return st.commit()


static func _needle_shank(st: SurfaceTool) -> void:
	var h:= NEEDLE_LENGTH * 0.5
	var r:= NEEDLE_SHAFT_R


	var profile: Array = [
		Vector2(- h, 0.0),
		Vector2(- h + h * 0.09, r * 0.26),
		Vector2(- h + h * 0.22, r * 0.56),
		Vector2(- h + h * 0.4, r * 0.85),
		Vector2(- h + h * 0.64, r),
		Vector2(h * 0.12, r),
		Vector2(h * 0.36, r * 0.9),
		Vector2(h * 0.56, r * 0.74),
	]
	var segs:= _NEEDLE_RADIAL
	for k in profile.size() - 1:
		var a: Vector2 = profile [k]
		var b: Vector2 = profile [k + 1]
		var dz:= b.x - a.x
		var dr:= b.y - a.y
		for s in segs:
			var t0:= TAU * float(s) / float(segs)
			var t1:= TAU * float(s + 1) / float(segs)


			var n0:= Vector3(dz * cos(t0), dz * sin(t0), - dr).normalized()
			var n1:= Vector3(dz * cos(t1), dz * sin(t1), - dr).normalized()
			var p00:= Vector3(a.y * cos(t0), a.y * sin(t0), a.x)
			var p10:= Vector3(a.y * cos(t1), a.y * sin(t1), a.x)
			var p01:= Vector3(b.y * cos(t0), b.y * sin(t0), b.x)
			var p11:= Vector3(b.y * cos(t1), b.y * sin(t1), b.x)
			if a.y > 1e-06:
				_tri(st, p00, p01, p10, n0, n0, n1)
			_tri(st, p10, p01, p11, n1, n0, n1)


	var last: Vector2 = profile [profile.size() - 1]
	var centre:= Vector3(0, 0, last.x)
	var out:= Vector3(0, 0, 1)
	for s in segs:
		var t0:= TAU * float(s) / float(segs)
		var t1:= TAU * float(s + 1) / float(segs)
		_tri(st,
			centre,
			Vector3(last.y * cos(t0), last.y * sin(t0), last.x),
			Vector3(last.y * cos(t1), last.y * sin(t1), last.x),
			out, out, out)


static func _needle_eye(st: SurfaceTool) -> void:
	var h:= NEEDLE_LENGTH * 0.5
	var z0:= h - NEEDLE_HEAD_LEN
	var t:= NEEDLE_HEAD_T
	var steps:= _NEEDLE_PLATE_STEPS
	var zs:= PackedFloat32Array()
	var ws:= PackedFloat32Array()
	var es:= PackedFloat32Array()
	for k in steps + 1:
		var u:= float(k) / float(steps)
		zs.append(z0 + NEEDLE_HEAD_LEN * u)
		ws.append(_outline_at(u) * NEEDLE_HEAD_W)
		es.append(_eye_at(zs [k]))

	var up:= Vector3.UP
	var dn:= Vector3.DOWN
	for k in steps:
		var za:= zs [k]
		var zb:= zs [k + 1]
		var wa:= ws [k]
		var wb:= ws [k + 1]
		var ea:= es [k]
		var eb:= es [k + 1]
		if ea <= 0.0 and eb <= 0.0:

			_quad(st, Vector3(- wa, t, za), Vector3(wa, t, za),
				Vector3(wb, t, zb), Vector3(- wb, t, zb), up)
			_quad(st, Vector3(- wa, - t, za), Vector3(wa, - t, za),
				Vector3(wb, - t, zb), Vector3(- wb, - t, zb), dn)
		else:
			for side: float in [-1.0, 1.0]:
				var ia:= side * ea
				var ib:= side * eb
				var oa:= side * wa
				var ob:= side * wb
				_quad(st, Vector3(ia, t, za), Vector3(oa, t, za),
					Vector3(ob, t, zb), Vector3(ib, t, zb), up)
				_quad(st, Vector3(ia, - t, za), Vector3(oa, - t, za),
					Vector3(ob, - t, zb), Vector3(ib, - t, zb), dn)

				var inw:= Vector3(- side * (zb - za), 0.0, side * (ib - ia)).normalized()
				_quad(st, Vector3(ia, - t, za), Vector3(ia, t, za),
					Vector3(ib, t, zb), Vector3(ib, - t, zb), inw)

		for side: float in [-1.0, 1.0]:
			var oa:= side * wa
			var ob:= side * wb
			var outw:= Vector3(side * (zb - za), 0.0, - side * (ob - oa)).normalized()
			_quad(st, Vector3(oa, - t, za), Vector3(oa, t, za),
				Vector3(ob, t, zb), Vector3(ob, - t, zb), outw)


static func _outline_at(u: float) -> float:
	var pts: Array = _NEEDLE_OUTLINE
	for k in pts.size() - 1:
		var a: Vector2 = pts [k]
		var b: Vector2 = pts [k + 1]
		if u <= b.x:
			var span:= maxf(b.x - a.x, 1e-06)
			return lerpf(a.y, b.y, clampf((u - a.x) / span, 0.0, 1.0))
	return 0.0


static func _eye_at(z: float) -> float:
	var centre:= NEEDLE_LENGTH * 0.5 - NEEDLE_HEAD_LEN * 0.44
	var half:= NEEDLE_EYE_LEN * 0.5
	var d:= (z - centre) / half
	if absf(d) >= 1.0:
		return 0.0
	return NEEDLE_EYE_W * sqrt(1.0 - d * d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
		return
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n, n, n)
	_tri(st, a, c, d, n, n, n)


static func needle_material() -> StandardMaterial3D:
	if _needle_mat == null:
		var m:= StandardMaterial3D.new()
		m.albedo_color = Cfg.COL_NEEDLE
		m.metallic = 1.0
		m.roughness = 0.16


		m.emission_enabled = true
		m.emission = Color(0.55, 0.62, 0.75)
		m.emission_energy_multiplier = 0.14
		_needle_mat = m
	return _needle_mat


static func hay_physics_material() -> PhysicsMaterial:
	var pm:= PhysicsMaterial.new()
	pm.friction = Cfg.STRAND_FRICTION
	pm.bounce = Cfg.STRAND_BOUNCE
	pm.rough = true
	return pm


static func random_tint(rng: RandomNumberGenerator) -> Color:
	var t:= rng.randf()


	t = pow(t, 1.45)
	var c:= Cfg.COL_HAY_DARK.lerp(Cfg.COL_HAY_LIGHT, t)
	var v:= rng.randf_range(0.78, 1.2)


	var h:= rng.randf_range(-1.0, 1.0)
	return Color(c.r * v * (1.0 + h * 0.07),
			c.g * v,
			c.b * v * (1.0 - h * 0.14), 1.0)


static func random_strand_basis(rng: RandomNumberGenerator, flat_bias: float = 0.75) -> Basis:
	var dir:= Vector3(
		rng.randfn(0.0, 1.0),
		rng.randfn(0.0, 1.0) * (1.0 - flat_bias),
		rng.randfn(0.0, 1.0)
	)
	if dir.length_squared() < 1e-06:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var up:= Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x_axis:= up.cross(dir).normalized()
	var y_axis:= dir.cross(x_axis).normalized()

	var spin:= rng.randf_range(0.0, TAU)
	var b:= Basis(x_axis, y_axis, dir).rotated(dir, spin)
	b.z *= random_length_scale(rng)
	return b
