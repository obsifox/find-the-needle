class_name VacVfx
extends Node3D


const WIND_LIFE:= 0.42


const WIND_AMOUNT:= 52
const SPOUT_AMOUNT:= 80


const WIND_SPREAD_R:= 0.46


const ARRIVE_OVERSHOOT:= 1.08


const TRAIL_AMOUNT:= 26
const TRAIL_LIFE:= 0.4


const TRAIL_LEN:= 0.16


const TRAIL_SPIN:= 1.35

const TRAIL_RING:= 0.22
const TRAIL_WIDTH:= 0.016


const GULP_TIME:= 0.3
const GULP_END_SCALE:= 0.1
const GULP_SPIN:= 9.0
const GULP_MAX:= 24

var wind: GPUParticles3D
var spout: GPUParticles3D
var trails: GPUParticles3D


var _gulps: Array = []


var _mouth:= Vector3.ZERO


func _ready() -> void:
	wind = _make_wind()
	spout = _make_spout()
	trails = _make_trails()
	for p: GPUParticles3D in [wind, spout, trails]:
		p.top_level = true
		p.emitting = false


		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)


func set_intake(on: bool, at: Vector3, mouth: Vector3) -> void:
	if not on:
		wind.emitting = false
		trails.emitting = false
		return
	var gap:= at.distance_to(mouth)
	_aim(wind, at, mouth)
	_set_speed(wind, gap / WIND_LIFE * ARRIVE_OVERSHOOT)
	wind.emitting = true


	_aim(trails, at, mouth)
	_set_speed(trails, gap / TRAIL_LIFE * ARRIVE_OVERSHOOT)
	trails.emitting = true


func set_pour(on: bool, mouth: Vector3, dir: Vector3) -> void:
	if not on:
		spout.emitting = false
		return
	_aim(spout, mouth, mouth + dir)
	spout.emitting = true


func stop() -> void:
	wind.emitting = false
	spout.emitting = false
	trails.emitting = false
	for g: Array in _gulps:
		(g [0] as Node).queue_free()
	_gulps.clear()


func track_mouth(at: Vector3) -> void:
	_mouth = at


func gulp(src: MeshInstance3D) -> void:
	if src == null or src.mesh == null or not src.is_inside_tree():
		return
	if _gulps.size() >= GULP_MAX:
		return
	var mi:= MeshInstance3D.new()
	mi.mesh = src.mesh
	for i in src.mesh.get_surface_count():
		mi.set_surface_override_material(i, src.get_surface_override_material(i))
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var from:= src.global_transform
	mi.global_transform = from
	var axis:= Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0))
	if axis.length_squared() < 0.0001:
		axis = Vector3.UP
	_gulps.append([mi, from, 0.0, axis.normalized()])


func _process(delta: float) -> void:
	if _gulps.is_empty():
		return
	for i in range(_gulps.size() - 1, -1, -1):
		var g: Array = _gulps [i]
		var mi:= g [0] as MeshInstance3D
		var age:= float(g [2]) + delta
		g [2] = age
		var t:= age / GULP_TIME
		if t >= 1.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_gulps.remove_at(i)
			continue


		var e:= t * t
		var from: Transform3D = g [1]
		var turn:= Basis(g [3] as Vector3, age * GULP_SPIN)
		var basis:= (turn * from.basis).scaled(
			Vector3.ONE * lerpf(1.0, GULP_END_SCALE, e))
		mi.global_transform = Transform3D(basis, from.origin.lerp(_mouth, e))


func _aim(p: GPUParticles3D, at: Vector3, target: Vector3) -> void:
	var d:= target - at
	if d.length_squared() < 1e-06:
		return
	var back:= - d.normalized()
	var up:= Vector3.UP
	if absf(back.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right:= up.cross(back).normalized()
	p.global_transform = Transform3D(Basis(right, back.cross(right), back), at)


func _set_speed(p: GPUParticles3D, speed: float) -> void:
	var m:= p.process_material as ParticleProcessMaterial
	if m == null:
		return
	m.initial_velocity_min = speed * 0.82
	m.initial_velocity_max = speed * 1.12


func _make_wind() -> GPUParticles3D:
	var p:= GPUParticles3D.new()
	p.name = "VacWind"
	p.amount = WIND_AMOUNT
	p.lifetime = WIND_LIFE
	p.local_coords = false
	p.draw_pass_1 = _wisp_mesh()
	var m:= ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = WIND_SPREAD_R
	m.direction = Vector3(0.0, 0.0, -1.0)


	m.spread = 38.0
	m.gravity = Vector3.ZERO

	m.scale_min = 0.22
	m.scale_max = 0.62

	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.35, Color(1, 1, 1, 0.22))
	var tex:= GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	return p


func _make_trails() -> GPUParticles3D:
	var p:= GPUParticles3D.new()
	p.name = "VacTrails"
	p.amount = TRAIL_AMOUNT
	p.lifetime = TRAIL_LIFE
	p.local_coords = false


	var streak:= BoxMesh.new()
	streak.size = Vector3(TRAIL_WIDTH, TRAIL_LEN, TRAIL_WIDTH)
	streak.material = _trail_material()
	p.draw_pass_1 = streak

	var m:= ParticleProcessMaterial.new()


	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	m.emission_ring_radius = TRAIL_RING
	m.emission_ring_inner_radius = TRAIL_RING * 0.45
	m.emission_ring_height = 0.1
	m.direction = Vector3(0.0, 0.0, -1.0)
	m.spread = 8.0
	m.gravity = Vector3.ZERO


	m.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)


	m.set_param_min(ParticleProcessMaterial.PARAM_ORBIT_VELOCITY, - TRAIL_SPIN)
	m.set_param_max(ParticleProcessMaterial.PARAM_ORBIT_VELOCITY, TRAIL_SPIN)
	m.scale_min = 0.7
	m.scale_max = 1.15
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.22, Color(1, 1, 1, 0.85))
	ramp.add_point(0.75, Color(1, 1, 1, 0.55))
	var tex:= GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	return p


func _trail_material() -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true


	m.albedo_texture = _streak_texture()


	m.albedo_color = Color(0.88, 0.86, 0.78, 0.34)
	return m


func _streak_texture() -> GradientTexture2D:
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.55, Color(1, 1, 1, 0.75))
	var tex:= GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 8
	tex.height = 64

	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	return tex


func _make_spout() -> GPUParticles3D:
	var p:= GPUParticles3D.new()
	p.name = "VacSpout"
	p.amount = SPOUT_AMOUNT
	p.lifetime = 1.1
	p.local_coords = false
	p.draw_pass_1 = _wisp_mesh()
	var m:= ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.1
	m.direction = Vector3(0.0, 0.0, -1.0)
	m.spread = 30.0
	m.initial_velocity_min = 0.7
	m.initial_velocity_max = 1.8


	m.gravity = Vector3(0.0, -2.4, 0.0)
	m.damping_min = 1.2
	m.damping_max = 2.6
	m.scale_min = 0.6
	m.scale_max = 2.0
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.45))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	var tex:= GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	return p


func _wisp_mesh() -> QuadMesh:
	var mesh:= QuadMesh.new()
	mesh.size = Vector2(0.085, 0.085)
	mesh.material = _air_material()
	return mesh


func _air_material() -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true


	m.albedo_color = Color(0.62, 0.55, 0.4, 0.1)
	m.disable_receive_shadows = true


	m.albedo_texture = _puff_texture()
	return m


func _puff_texture() -> GradientTexture2D:
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))


	ramp.add_point(0.34, Color(1, 1, 1, 0.85))
	var tex:= GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
