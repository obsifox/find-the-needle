class_name BrickLauncher
extends Node3D


@export var throw_distance:= 2.6


@export var launch_angle:= 42.0


@export var max_launch_speed:= 12.0


@export var solve_damping:= false


@export var ground_y:= 0.0


@export var spread_radius:= 0.08


@export var muzzle_clearance:= 0.0


@export var dust_colour:= Color(0.88, 0.76, 0.5)

@export var flash_energy:= 1.6

var _muzzle: GPUParticles3D
var _ring: GPUParticles3D
var _forward:= Vector3.FORWARD

static var _puff: Texture2D = null


func _ready() -> void:
	_muzzle = _make_burst("MuzzleBurst", 20, 0.85, 15.0, 5.0, 8.0,
		Vector3.ZERO, 0.0, 0.16, flash_energy)
	_ring = _make_burst("MouthRing", 16, 1.05, 50.0, 2.6, 5.0,
		Vector3(0.3, 0.01, 0.3), 0.9, 0.22, flash_energy * 0.35)
	add_child(_muzzle)
	add_child(_ring)
	aim_along(- global_transform.basis.z)


func aim_along(dir: Vector3) -> void:
	if dir.length_squared() < 1e-06:
		return
	_forward = dir.normalized()


	var up:= Vector3.UP if absf(_forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var basis:= Basis.looking_at(_forward, up)
	if _muzzle != null:
		_muzzle.global_transform = Transform3D(basis, global_position)
	if _ring != null:
		_ring.global_transform = Transform3D(basis, global_position)


func discharge(props: PropManager, strands: int = Cfg.PELLETIZER_BRICK_STRANDS) -> EcoBrick:
	burst()
	var from:= release_point()
	var brick:= props.spawn("eco_brick",
		Transform3D(_tumble_basis(), from),
		{ "strands": strands }) as EcoBrick
	if brick == null:
		return null
	brick.linear_velocity = _launch_velocity(from, _target(from))
	BeltPath.mark_machine_throw(brick)

	brick.angular_velocity = Vector3(
		randf_range(-3.0, 3.0),
		randf_range(-3.0, 3.0),
		randf_range(-3.0, 3.0))
	return brick


func solve_throw(from: Vector3) -> Vector3:
	return _launch_velocity(from, _target(from))


func aim_velocity() -> Vector3:
	return _launch_velocity(release_point(), landing_spot())


func middle_throw(from: Vector3) -> Vector3:
	var flat:= Vector3(_forward.x, 0.0, _forward.z)
	if flat.length_squared() < 1e-06:
		flat = Vector3.FORWARD
	return _launch_velocity(from, from + flat.normalized() * throw_distance)


func release_point() -> Vector3:
	return global_position + _forward * muzzle_clearance


func burst() -> void:
	for p: GPUParticles3D in [_muzzle, _ring]:
		if p == null:
			continue


		p.restart()
		p.emitting = true


func landing_spot() -> Vector3:
	var from:= release_point()
	var flat:= Vector3(_forward.x, 0.0, _forward.z)
	if flat.length_squared() < 1e-06:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var at:= from + flat * throw_distance
	at.y = ground_y
	return at


func belt_landing(reach: float) -> Dictionary:
	var g:= absf(float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)))
	var c:= float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	var dt:= 2.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	var keep:= maxf(0.0, 1.0 - c * dt)
	var p:= release_point()
	var v:= aim_velocity()
	var t:= 0.0


	var mid:= (p + landing_spot()) * 0.5
	var near:= BeltPath.paths_near(mid, p.distance_to(landing_spot()) * 0.5 + 1.0)
	if near.is_empty():
		return { }
	for _i in 600:
		v.y -= g * dt
		v *= keep
		p += v * dt
		t += dt
		if p.y < ground_y - BELT_LAND_DROP:
			break
		if v.y >= 0.0:
			continue


		var fwd:= Vector3(v.x, 0.0, v.z).normalized()
		for ahead: float in BELT_LAND_AHEAD:
			var belt:= BeltPath.path_under(p + fwd * ahead, reach, BELT_LAND_DROP, near)
			if belt != null:
				return { "belt": belt, "at": p + fwd * ahead, "t": t }
	return { }


const BELT_LAND_DROP:= 0.3

const BELT_LAND_AHEAD: Array [float] = [0.0, 0.15, 0.3]


func _target(from: Vector3) -> Vector3:
	var flat:= Vector3(_forward.x, 0.0, _forward.z)
	if flat.length_squared() < 1e-06:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var angle:= randf() * TAU
	var r:= sqrt(randf()) * spread_radius
	return from + flat * throw_distance + Vector3(cos(angle) * r, 0.0, sin(angle) * r)


func _launch_velocity(from: Vector3, to: Vector3) -> Vector3:
	var delta:= Vector3(to.x - from.x, 0.0, to.z - from.z)
	var flat:= delta
	if flat.length_squared() < 1e-06:
		flat = Vector3(_forward.x, 0.0, _forward.z)
		if flat.length_squared() < 1e-06:
			flat = Vector3.FORWARD
	flat = flat.normalized()

	var a: float = clampf(deg_to_rad(launch_angle), 0.05, 1.5)
	var r: float = maxf(delta.length(), 0.05)
	var h: float = maxf(from.y - ground_y, 0.05)
	var g: float = absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))
	var denom: float = 2.0 * pow(cos(a), 2.0) * (r * tan(a) + h)
	var speed: float = max_launch_speed
	if denom > 0.0001:
		speed = minf(sqrt(g * r * r / denom), max_launch_speed)
	if solve_damping:
		speed = _damped_speed(speed, a, r, h, g)
	return flat * (speed * cos(a)) + Vector3.UP * (speed * sin(a))


func _damped_speed(vacuum: float, a: float, r: float, h: float, g: float) -> float:
	var c:= float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	var dt:= 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	if c <= 0.0:
		return vacuum
	var lo:= vacuum
	var hi:= max_launch_speed
	if _damped_range(hi, a, h, g, c, dt) < r:
		return hi
	for _i in 20:
		var mid:= (lo + hi) * 0.5
		if _damped_range(mid, a, h, g, c, dt) < r:
			lo = mid
		else:
			hi = mid
	return hi


static func _damped_range(speed: float, a: float, h: float, g: float,
		c: float, dt: float) -> float:
	var keep:= maxf(0.0, 1.0 - c * dt)
	var vx:= speed * cos(a)
	var vy:= speed * sin(a)
	var x:= 0.0
	var y:= h
	for _i in 4000:
		vy -= g * dt
		vx *= keep
		vy *= keep
		var ny:= y + vy * dt
		if ny <= 0.0 and vy < 0.0:
			return x + vx * dt * (y / (y - ny))
		x += vx * dt
		y = ny
	return x


func _tumble_basis() -> Basis:
	return Basis.from_euler(Vector3(
		randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU)))


func _make_burst(node_name: String, amount: int, lifetime: float, spread: float,
		vmin: float, vmax: float, box: Vector3, flatness: float,
		quad: float, energy: float) -> GPUParticles3D:
	var pm:= ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -1.2, 0)
	pm.damping_min = 3.0
	pm.damping_max = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.scale_curve = _scale_curve()
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color = dust_colour
	if box != Vector3.ZERO:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box
	if flatness > 0.0:
		pm.flatness = flatness

	var mesh:= QuadMesh.new()
	mesh.size = Vector2(quad, quad)
	mesh.material = _puff_material(energy)

	var p:= GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = pm
	p.draw_pass_1 = mesh
	return p


static func _scale_curve() -> CurveTexture:
	var c:= Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.13, 1.0))
	c.add_point(Vector2(0.53, 0.0))
	var t:= CurveTexture.new()
	t.curve = c
	return t


func _puff_material(energy: float) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.albedo_color = dust_colour
	m.albedo_texture = _puff_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = dust_colour
		m.emission_energy_multiplier = energy
	return m


static func _puff_texture() -> Texture2D:
	if _puff != null:
		return _puff
	var g:= Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.85))
	var t:= GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_puff = t
	return _puff
