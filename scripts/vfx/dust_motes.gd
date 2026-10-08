class_name DustMotes
extends Node3D


const MOTE_SIZE:= 0.018


const MOTE_COUNT:= 60

const BOX:= Vector3(4.5, 2.8, 4.5)


const MOTE_LIFETIME:= 12.0


const AIR_TOP:= 8.6


const AIR_BOTTOM:= 0.9

var _p: GPUParticles3D
var _proc: ParticleProcessMaterial


var _wanted:= true


func _ready() -> void:
	_proc = ParticleProcessMaterial.new()
	_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX


	_proc.direction = Vector3(0.0, -1.0, 0.0)
	_proc.spread = 55.0
	_proc.initial_velocity_min = 0.01
	_proc.initial_velocity_max = 0.06


	_proc.gravity = Vector3(0.012, -0.016, 0.005)
	_proc.damping_min = 0.0
	_proc.damping_max = 0.02


	_proc.scale_min = 0.5
	_proc.scale_max = 1.2


	_proc.turbulence_enabled = true
	_proc.turbulence_noise_strength = 0.16
	_proc.turbulence_noise_scale = 1.8
	_proc.turbulence_noise_speed = Vector3(0.05, 0.02, 0.04)
	_proc.turbulence_influence_min = 0.03
	_proc.turbulence_influence_max = 0.1

	_p = GPUParticles3D.new()
	_p.name = "Motes"
	_p.process_material = _proc
	_p.draw_pass_1 = _mote_mesh()
	_p.amount = MOTE_COUNT
	_p.lifetime = MOTE_LIFETIME


	_p.preprocess = MOTE_LIFETIME
	_p.randomness = 1.0


	_p.local_coords = false


	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_proc.emission_box_extents = BOX
	_p.visibility_aabb = AABB(- BOX * 1.5, BOX * 3.0)
	add_child(_p)
	fit_to(null)


func _mote_mesh() -> QuadMesh:
	var q:= QuadMesh.new()
	q.size = Vector2(MOTE_SIZE, MOTE_SIZE)
	q.material = _mote_material()
	return q


const MOTE_TINT:= Color(1.0, 0.94, 0.82)


const NEAR_GONE:= 0.6
const NEAR_FULL:= 2.2

static var _mote_mat: StandardMaterial3D


static func _mote_material() -> StandardMaterial3D:
	if _mote_mat != null:
		return _mote_mat
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))


	ramp.add_point(0.35, Color(1, 1, 1, 0.95))
	var tex:= GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32

	var m:= StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = MOTE_TINT
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED


	m.billboard_keep_scale = true


	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0

	m.emission_enabled = true
	m.emission = MOTE_TINT
	m.emission_energy_multiplier = 0.1


	m.backlight_enabled = true
	m.backlight = Color(0.95, 0.88, 0.74)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = NEAR_GONE
	m.distance_fade_max_distance = NEAR_FULL
	_mote_mat = m
	return m


var _reach:= Warehouse.INNER

var _reach_z:= Vector2(- Warehouse.INNER, Warehouse.INNER)


func fit_to(shed: Warehouse) -> void:
	if _proc == null:
		return
	var half: float = Warehouse.INNER if shed == null else shed.inner
	var lo: float = - half if shed == null else shed.z_lo()


	_reach = maxf(0.0, half - BOX.x)
	_reach_z = Vector2(minf(0.0, lo + BOX.z), maxf(0.0, half - BOX.z))


func _process(_delta: float) -> void:
	if not _wanted:
		return
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return
	var at:= cam.global_position


	global_position = Vector3(
		clampf(at.x, - _reach, _reach),
		clampf(at.y, AIR_BOTTOM + BOX.y, AIR_TOP - BOX.y),
		clampf(at.z, _reach_z.x, _reach_z.y))


func set_wanted(on: bool) -> void:
	_wanted = on
	if _p == null:
		return
	_p.emitting = on
	_p.visible = on
