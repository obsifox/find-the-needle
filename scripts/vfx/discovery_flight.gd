class_name DiscoveryFlight
extends Node3D


const SPEED:= 8.0
const MIN_TIME:= 0.55
const MAX_TIME:= 3.0


const ARC_HEIGHT:= 0.28


const TRAIL_SIZE:= 0.11

signal arrived(type: int)

var _from:= Vector3.ZERO
var _to:= Vector3.ZERO
var _type:= -1
var _t:= 0.0
var _span:= 1.0
var _mesh: MeshInstance3D
var _trail: GPUParticles3D


static func spawn(parent: Node, type: int, from: Vector3, to: Vector3,
		tint: Color) -> DiscoveryFlight:
	var f:= DiscoveryFlight.new()
	f.name = "DiscoveryFlight"
	f._type = type
	f._from = from
	f._to = to
	parent.add_child(f)
	f.global_position = from
	f._build(tint)
	return f


func _build(tint: Color) -> void:
	var dist:= _from.distance_to(_to)
	_span = clampf(dist / SPEED, MIN_TIME, MAX_TIME)

	var sphere:= SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	sphere.radial_segments = 12
	sphere.rings = 6
	var m:= StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


	m.albedo_color = tint.lerp(Color.WHITE, 0.45)
	sphere.material = m
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	var pm:= ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3(0, -0.25, 0)
	pm.scale_min = 0.2
	pm.scale_max = 0.7
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.9))
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var ramp_tex:= GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex


	var quad:= GlintParticles.draw_quad(TRAIL_SIZE, GlintParticles.STAR_TRAIL,
		GlintParticles.ENERGY_TRAIL)

	_trail = GPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 0.6
	_trail.draw_pass_1 = quad
	_trail.process_material = pm
	_trail.local_coords = false


	var mid:= (_from + _to) * 0.5
	var half:= (_to - _from).abs() * 0.5 + Vector3(1.5, 1.5, 1.5)
	_trail.visibility_aabb = AABB(mid - half - global_position, half * 2.0)
	add_child(_trail)


func _process(delta: float) -> void:
	_t = minf(_t + delta / _span, 1.0)


	var k:= smoothstep(0.0, 1.0, _t)
	var p:= _from.lerp(_to, k)

	p.y += sin(_t * PI) * ARC_HEIGHT * clampf(_from.distance_to(_to) * 0.25, 1.0, 6.0)
	global_position = p
	if _mesh != null:
		var pulse:= 1.0 + 0.18 * sin(_t * TAU * 6.0)

		_mesh.scale = Vector3.ONE * pulse * lerpf(1.0, 0.35, k)
	if _t >= 1.0:
		arrived.emit(_type)
		if _trail != null:
			_trail.emitting = false
		queue_free()
