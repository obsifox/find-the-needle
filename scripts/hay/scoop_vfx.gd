class_name ScoopVfx
extends Node3D


const CAP:= 160
const LIFETIME:= 0.85


const BURST:= 26
const PER_SECOND:= 190.0


const PUFF_CAP:= 48
const PUFF_LIFETIME:= 0.95
const PUFF_BURST:= 11
const PUFF_PER_SECOND:= 40.0

const PUFF_SIZE:= 0.13
const PUFF_GROW:= 2.6


const PUFF_SPEED:= Vector2(0.25, 0.75)
const PUFF_UP:= Vector2(0.15, 0.45)


const PUFF_ALPHA:= 0.42


const CRUMBLE:= 12
const CRUMBLE_PER_SECOND:= 80.0
const CRUMBLE_SPEED:= Vector2(0.1, 0.45)


const SPEED_ALONG:= Vector2(0.9, 2.6)
const SPEED_ACROSS:= 0.55
const SPEED_UP:= Vector2(0.15, 1.05)

var _particles: GPUParticles3D
var _puffs: GPUParticles3D
var _rng:= RandomNumberGenerator.new()
var _tokens:= float(BURST)
var _puff_tokens:= float(PUFF_BURST)
var _crumble_tokens:= float(CRUMBLE)
var _last_usec:= 0


var emitted_total:= 0
var peak_burst:= 0


func _ready() -> void:
	_rng.randomize()
	_last_usec = Time.get_ticks_usec()
	_build()


func _build() -> void:
	var pm:= ParticleProcessMaterial.new()


	pm.gravity = Vector3(0.0, -5.4, 0.0)
	pm.damping_min = 1.4
	pm.damping_max = 3.2
	pm.angular_velocity_min = -680.0
	pm.angular_velocity_max = 680.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.45
	pm.scale_max = 1.0
	pm.lifetime_randomness = 0.35


	var colours:= Gradient.new()
	colours.set_color(0, Cfg.COL_HAY_DARK)
	colours.set_color(1, Cfg.COL_HAY_LIGHT)
	var colour_tex:= GradientTexture1D.new()
	colour_tex.gradient = colours
	pm.color_initial_ramp = colour_tex


	var shrink:= Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.55, 0.92))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_tex:= CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex


	var mesh:= BoxMesh.new()
	mesh.size = Vector3(Cfg.STRAND_THICK * 0.8, Cfg.STRAND_THICK * 0.8,
		Cfg.STRAND_LENGTH * 0.42)
	var mat:= StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.78
	mat.metallic = 0.0
	mesh.material = mat

	_particles = GPUParticles3D.new()
	_particles.name = "ScoopChaff"
	_particles.amount = CAP
	_particles.lifetime = LIFETIME
	_particles.emitting = false
	_particles.local_coords = false
	_particles.fixed_fps = 30
	_particles.interpolate = true
	_particles.fract_delta = true
	_particles.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	_particles.process_material = pm
	_particles.draw_pass_1 = mesh
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	_particles.visibility_aabb = AABB(
		Vector3(- Cfg.FIELD_EXTENT - 2.0, -2.0, - Cfg.FIELD_EXTENT - 2.0),
		Vector3((Cfg.FIELD_EXTENT + 2.0) * 2.0, Cfg.PILE_HEIGHT + 10.0,
			(Cfg.FIELD_EXTENT + 2.0) * 2.0))
	add_child(_particles)
	_build_puffs()


func _build_puffs() -> void:
	var pm:= ParticleProcessMaterial.new()


	pm.gravity = Vector3(0.0, -0.12, 0.0)
	pm.damping_min = 1.6
	pm.damping_max = 2.8
	pm.particle_flag_disable_z = false
	pm.lifetime_randomness = 0.3


	var grow:= Curve.new()
	grow.add_point(Vector2(0.0, 1.0))
	grow.add_point(Vector2(0.4, 1.0 + (PUFF_GROW - 1.0) * 0.6))
	grow.add_point(Vector2(1.0, PUFF_GROW))
	var grow_tex:= CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex

	var fade:= Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.12, Color(1, 1, 1, 1.0))
	fade.add_point(0.45, Color(1, 1, 1, 0.7))
	var fade_tex:= GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex

	var mesh:= QuadMesh.new()
	mesh.size = Vector2(PUFF_SIZE, PUFF_SIZE)
	var mat:= StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX


	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true


	var dust:= Cfg.COL_HAY_LIGHT.lerp(Cfg.COL_HAY_DARK, 0.45).lerp(
		Color(0.4, 0.36, 0.3), 0.35)
	mat.albedo_color = Color(dust.r, dust.g, dust.b, PUFF_ALPHA)
	mat.albedo_texture = _puff_texture()
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	mesh.material = mat

	_puffs = GPUParticles3D.new()
	_puffs.name = "BiteDust"
	_puffs.amount = PUFF_CAP
	_puffs.lifetime = PUFF_LIFETIME
	_puffs.emitting = false
	_puffs.local_coords = false
	_puffs.fixed_fps = 30
	_puffs.interpolate = true
	_puffs.fract_delta = true
	_puffs.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_puffs.process_material = pm
	_puffs.draw_pass_1 = mesh
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puffs.visibility_aabb = _particles.visibility_aabb
	add_child(_puffs)


func _puff_texture() -> GradientTexture2D:
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 0.8))
	var tex:= GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func burst(at: Vector3, toward: Vector3, strength:= 1.0) -> int:
	if _particles == null:
		return 0
	var dir:= toward
	if dir.length_squared() < 1e-06:
		dir = Vector3.UP
	dir = dir.normalized()


	var side:= dir.cross(Vector3.UP)
	if side.length_squared() < 1e-06:
		side = Vector3.RIGHT
	side = side.normalized()

	_refill()
	var want:= int(round(float(BURST) * clampf(strength, 0.0, 1.0)))
	var count:= mini(want, int(floor(_tokens)))
	if count <= 0:
		return 0
	_tokens -= float(count)
	peak_burst = maxi(peak_burst, count)
	emitted_total += count

	var flags:= (GPUParticles3D.EMIT_FLAG_POSITION
		| GPUParticles3D.EMIT_FLAG_ROTATION_SCALE
		| GPUParticles3D.EMIT_FLAG_VELOCITY)
	for _n in count:
		var p:= at + Vector3(
			_rng.randfn(0.0, 0.05), _rng.randf_range(0.0, 0.06),
			_rng.randfn(0.0, 0.05))
		var v:= dir * _rng.randf_range(SPEED_ALONG.x, SPEED_ALONG.y)
		v += side * _rng.randfn(0.0, SPEED_ACROSS)
		v += Vector3.UP * _rng.randf_range(SPEED_UP.x, SPEED_UP.y)
		_particles.emit_particle(
			Transform3D(StrandFactory.random_strand_basis(_rng, 0.3), p),
			v, Color.WHITE, Color.WHITE, flags)
	return count


func bite(at: Vector3, radius: float, strength:= 1.0) -> int:
	_refill()
	var s:= clampf(strength, 0.0, 1.0)
	var made:= 0
	var flags:= (GPUParticles3D.EMIT_FLAG_POSITION
		| GPUParticles3D.EMIT_FLAG_ROTATION_SCALE
		| GPUParticles3D.EMIT_FLAG_VELOCITY)
	if _puffs != null:
		var want:= int(round(float(PUFF_BURST) * lerpf(0.5, 1.0, s)))
		var count:= mini(want, int(floor(_puff_tokens)))
		_puff_tokens -= float(count)
		for _n in count:


			var a:= _rng.randf() * TAU
			var r:= radius * _rng.randf_range(0.2, 1.0)
			var out:= Vector3(cos(a), 0.0, sin(a))
			var p:= at + out * r + Vector3(0.0, _rng.randf_range(0.0, 0.08), 0.0)
			var v:= out * _rng.randf_range(PUFF_SPEED.x, PUFF_SPEED.y) + Vector3.UP * _rng.randf_range(PUFF_UP.x, PUFF_UP.y)
			var size:= _rng.randf_range(0.7, 1.3)
			_puffs.emit_particle(
				Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), p),
				v, Color.WHITE, Color.WHITE, flags)
			made += 1
	if _particles != null:
		var want:= int(round(float(CRUMBLE) * s))
		var count:= mini(want, int(floor(_crumble_tokens)))
		_crumble_tokens -= float(count)
		for _n in count:


			var a:= _rng.randf() * TAU
			var rim:= Vector3(cos(a), 0.0, sin(a))
			var p:= at + rim * radius * _rng.randf_range(0.9, 1.3) + Vector3(0.0, _rng.randf_range(0.02, 0.1), 0.0)
			var v:= - rim * _rng.randf_range(CRUMBLE_SPEED.x, CRUMBLE_SPEED.y) + Vector3(0.0, _rng.randf_range(-0.1, 0.15), 0.0)
			_particles.emit_particle(
				Transform3D(StrandFactory.random_strand_basis(_rng, 0.3), p),
				v, Color.WHITE, Color.WHITE, flags)
			made += 1
		peak_burst = maxi(peak_burst, count)
		emitted_total += count
	return made


func shake_off(at: Vector3, forward: Vector3, count: int) -> int:
	if _particles == null or count <= 0:
		return 0
	_refill()
	var n:= mini(count, int(floor(_tokens)))
	if n <= 0:
		return 0
	_tokens -= float(n)
	emitted_total += n
	var fwd:= forward
	if fwd.length_squared() < 1e-06:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var side:= fwd.cross(Vector3.UP)
	if side.length_squared() < 1e-06:
		side = Vector3.RIGHT
	side = side.normalized()
	var flags:= (GPUParticles3D.EMIT_FLAG_POSITION
		| GPUParticles3D.EMIT_FLAG_ROTATION_SCALE
		| GPUParticles3D.EMIT_FLAG_VELOCITY)
	for _i in n:

		var p:= at + side * _rng.randf_range(-0.12, 0.12) + fwd * _rng.randf_range(-0.04, 0.14) + Vector3.UP * _rng.randf_range(0.02, 0.07)
		var v:= side * _rng.randfn(0.0, 0.25) + fwd * _rng.randf_range(0.0, 0.3) + Vector3.UP * _rng.randf_range(-0.05, 0.25)
		_particles.emit_particle(
			Transform3D(StrandFactory.random_strand_basis(_rng, 0.3), p),
			v, Color.WHITE, Color.WHITE, flags)
	return n


func _refill() -> void:
	var now:= Time.get_ticks_usec()
	if _last_usec <= 0:
		_last_usec = now
		return
	var elapsed:= float(now - _last_usec) / 1000000.0
	_last_usec = now
	_tokens = minf(float(BURST), _tokens + elapsed * PER_SECOND)
	_puff_tokens = minf(float(PUFF_BURST), _puff_tokens + elapsed * PUFF_PER_SECOND)
	_crumble_tokens = minf(float(CRUMBLE), _crumble_tokens + elapsed * CRUMBLE_PER_SECOND)


func reset_stats() -> void:
	emitted_total = 0
	peak_burst = 0
