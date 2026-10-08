class_name JetpackVfx
extends Node3D


const NOZZLE_Y:= 0.95
const NOZZLE_BACK:= Player.CAP_RADIUS - 0.02
const NOZZLE_SPREAD:= 0.13

const JET_DIR:= Vector3(0.0, -1.0, 0.22)

const FLAME_AMOUNT:= 36
const FLAME_LIFE:= 0.2


const SMOKE_AMOUNT:= 180
const SMOKE_LIFE:= 2.6

const GLOW_ENERGY:= 1.6
const GLOW_RANGE:= 4.0

const GLOW_RAMP:= 18.0

const GLOW_FADE_BEGIN:= 30.0
const GLOW_FADE_LENGTH:= 10.0

var player: Player
var flames: Array [GPUParticles3D] = []
var smoke: GPUParticles3D
var glow: OmniLight3D

var _lit:= false
var _glow:= 0.0
var _t:= 0.0


func _ready() -> void:
	position = Vector3(0.0, NOZZLE_Y, NOZZLE_BACK)
	for side: float in [-1.0, 1.0]:
		var f:= _make_flame()
		f.position = Vector3(side * NOZZLE_SPREAD, 0.0, 0.0)
		add_child(f)
		flames.append(f)
	smoke = _make_smoke()
	add_child(smoke)

	glow = OmniLight3D.new()
	glow.name = "JetGlow"
	glow.light_color = HayGenerator.FIRE_COLOUR
	glow.light_energy = 0.0
	glow.omni_range = GLOW_RANGE
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, -0.15, 0.0)
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = GLOW_FADE_BEGIN
	glow.distance_fade_length = GLOW_FADE_LENGTH
	glow.visible = false
	add_child(glow)


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var jet:= player.jetpack
	var lit:= jet.is_thrusting()
	if lit != _lit:
		_lit = lit
		for f in flames:
			f.emitting = lit
		smoke.emitting = lit


	var strength:= 1.0
	if lit and jet.fraction() < Cfg.JETPACK_LOW:
		strength = 0.3 + 0.7 * absf(sin(_t * 23.0) * sin(_t * 7.1 + 0.8))
	for f in flames:
		f.amount_ratio = strength
	_glow = lerpf(_glow, strength if lit else 0.0, 1.0 - exp(- GLOW_RAMP * delta))
	var flicker:= 1.0 + 0.15 * sin(_t * 31.0) + 0.1 * sin(_t * 13.7 + 1.3)
	glow.light_energy = GLOW_ENERGY * _glow * flicker
	glow.visible = _glow > 0.01


func _make_flame() -> GPUParticles3D:
	var p:= GPUParticles3D.new()
	p.name = "JetFlame"
	p.amount = FLAME_AMOUNT
	p.lifetime = FLAME_LIFE
	p.local_coords = false


	p.fixed_fps = 0
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1.5, -2.5, -1.5), Vector3(3.0, 3.0, 3.0))

	var m:= ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.025
	m.direction = JET_DIR.normalized()
	m.spread = 6.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 6.0
	m.gravity = Vector3.ZERO
	m.damping_min = 4.0
	m.damping_max = 8.0


	m.inherit_velocity_ratio = 0.8
	m.scale_min = 0.8
	m.scale_max = 1.2
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(0.4, 0.8), Vector2(1.0, 0.2)])

	m.angle_min = -180.0
	m.angle_max = 180.0
	m.anim_offset_min = 0.0
	m.anim_offset_max = 1.0
	p.process_material = m

	var quad:= QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var fm:= ShaderMaterial.new()
	fm.shader = load(HayGenerator.FLAME_SHADER)


	fm.set_shader_parameter("stretch", 1.0)
	fm.set_shader_parameter("brightness", 1.7)
	fm.set_shader_parameter("rise_speed", 3.0)
	fm.set_shader_parameter("erosion", 0.55)
	quad.material = fm
	p.draw_pass_1 = quad
	return p


func _make_smoke() -> GPUParticles3D:
	var p:= GPUParticles3D.new()
	p.name = "JetSmoke"
	p.amount = SMOKE_AMOUNT
	p.lifetime = SMOKE_LIFE
	p.local_coords = false
	p.fixed_fps = 0
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	p.visibility_aabb = AABB(Vector3(-12.0, -14.0, -12.0), Vector3(24.0, 24.0, 24.0))

	var m:= ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(NOZZLE_SPREAD, 0.05, 0.05)
	m.direction = JET_DIR.normalized()
	m.spread = 14.0
	m.initial_velocity_min = 2.2
	m.initial_velocity_max = 3.4
	m.inherit_velocity_ratio = 0.0


	m.damping_min = 4.0
	m.damping_max = 6.0

	m.gravity = Vector3(0.0, 0.35, 0.0)
	m.scale_min = 0.6
	m.scale_max = 1.0
	m.scale_curve = _curve([Vector2(0.0, 0.2), Vector2(0.3, 0.6), Vector2(1.0, 1.0)])
	m.angle_min = -180.0
	m.angle_max = 180.0


	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1.0, 0.72, 0.45, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.05, Color(1.0, 0.85, 0.65, 0.9))
	ramp.add_point(0.45, Color(1.0, 1.0, 1.0, 0.7))
	var tex:= GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m

	var quad:= QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	var sm:= StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true


	sm.albedo_color = Color(0.72, 0.7, 0.66, 0.75)
	sm.albedo_texture = _puff_texture()
	sm.disable_receive_shadows = true


	sm.proximity_fade_enabled = true
	sm.proximity_fade_distance = 0.4
	quad.material = sm
	p.draw_pass_1 = quad
	return p


func _curve(points: Array [Vector2]) -> CurveTexture:
	var c:= Curve.new()
	for pt in points:
		c.add_point(pt)
	var t:= CurveTexture.new()
	t.curve = c
	return t


static var _puff: ImageTexture

static func _puff_texture() -> ImageTexture:
	if _puff != null:
		return _puff
	var noise:= FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	noise.seed = 7
	var size:= 96
	var half:= float(size) * 0.5
	var img:= Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d:= Vector2(x - half + 0.5, y - half + 0.5).length() / half
			var v:= noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a:= 1.0 - smoothstep(0.15, 1.0, d + (v - 0.5) * 0.7)
			a *= 0.5 + 0.5 * v

			a *= 1.0 - smoothstep(0.8, 1.0, d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_puff = ImageTexture.create_from_image(img)
	return _puff
