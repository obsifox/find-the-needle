class_name AvalancheVfx
extends Node3D


var _particles: GPUParticles3D
var _rng:= RandomNumberGenerator.new()
var _tokens: float = 0.0
var _last_emit_usec:= 0


var emitted_total:= 0
var peak_burst:= 0


func _ready() -> void:
	_rng.randomize()
	_tokens = float(Cfg.AVALANCHE_PARTICLE_BURST)
	_last_emit_usec = Time.get_ticks_usec()
	_build_particles()


func _build_particles() -> void:
	var pm:= ParticleProcessMaterial.new()


	pm.gravity = Vector3(0.0, -0.65, 0.0)
	pm.damping_min = 0.25
	pm.damping_max = 0.7
	pm.angular_velocity_min = -520.0
	pm.angular_velocity_max = 520.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.72
	pm.scale_max = 1.28
	pm.lifetime_randomness = 0.18


	var colours:= Gradient.new()
	colours.set_color(0, Cfg.COL_HAY_DARK)
	colours.set_color(1, Cfg.COL_HAY_LIGHT)
	var colour_tex:= GradientTexture1D.new()
	colour_tex.gradient = colours
	pm.color_initial_ramp = colour_tex


	var shrink:= Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.72, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_tex:= CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex

	var mesh:= BoxMesh.new()
	mesh.size = Vector3(Cfg.STRAND_THICK, Cfg.STRAND_THICK, Cfg.STRAND_LENGTH)
	var material:= StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.roughness = 0.72
	material.metallic = 0.0
	mesh.material = material

	_particles = GPUParticles3D.new()
	_particles.name = "AvalancheStrands"
	_particles.amount = Cfg.AVALANCHE_PARTICLE_CAP
	_particles.lifetime = Cfg.AVALANCHE_PARTICLE_LIFETIME
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


func emit_spill(points: PackedVector3Array, field: HayField) -> int:
	if _particles == null or points.is_empty() or field == null:
		return 0
	_refill_tokens()
	var count:= mini(points.size(), int(floor(_tokens)))
	if count <= 0:
		return 0
	count = mini(count, Cfg.AVALANCHE_PARTICLE_BURST)
	_tokens -= float(count)
	peak_burst = maxi(peak_burst, count)
	emitted_total += count

	var flags:= (GPUParticles3D.EMIT_FLAG_POSITION
		| GPUParticles3D.EMIT_FLAG_ROTATION_SCALE
		| GPUParticles3D.EMIT_FLAG_VELOCITY)
	for n in count:


		var point_i:= mini(points.size() - 1,
			int((float(n) + _rng.randf()) * float(points.size()) / float(count)))
		var p:= points [point_i] + Vector3.UP * 0.035
		var normal:= field.normal_at(p.x, p.z)


		var downhill:= Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
		if downhill.length_squared() < 1e-05:
			downhill = Vector3(_rng.randfn(0.0, 1.0), -0.08,
				_rng.randfn(0.0, 1.0))
		downhill = downhill.normalized()
		var velocity:= downhill * _rng.randf_range(0.55, 1.45)
		velocity += Vector3(_rng.randfn(0.0, 0.1), _rng.randf_range(0.04, 0.2),
			_rng.randfn(0.0, 0.1))
		var basis:= StrandFactory.random_strand_basis(_rng, 0.3)
		_particles.emit_particle(Transform3D(basis, p), velocity, Color.WHITE,
			Color.WHITE, flags)
	return count


func _refill_tokens() -> void:
	var now:= Time.get_ticks_usec()
	if _last_emit_usec <= 0:
		_last_emit_usec = now
		return
	var elapsed:= float(now - _last_emit_usec) / 1000000.0
	_last_emit_usec = now
	_tokens = minf(float(Cfg.AVALANCHE_PARTICLE_BURST),
		_tokens + elapsed * Cfg.AVALANCHE_PARTICLES_PER_SECOND)


func reset_stats() -> void:
	emitted_total = 0
	peak_burst = 0
