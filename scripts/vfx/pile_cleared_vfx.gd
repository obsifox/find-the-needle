class_name PileClearedVfx
extends Node3D


const PER_CANNON:= 360

const LIFETIME:= 5.5

const STAGGER:= 0.07


const PAPER: Array [Color] = [
	Color(1.0, 0.82, 0.1), Color(1.0, 0.24, 0.52), Color(0.1, 0.74, 1.0),
	Color(0.46, 0.9, 0.2), Color(1.0, 0.5, 0.08), Color(0.62, 0.36, 1.0),
]

const PIECE:= Vector2(0.055, 0.075)


const SHADER:= "\nshader_type spatial;\nrender_mode cull_disabled;\n\nuniform float life = 5.5;\n\nvarying vec3 v_paper;\nvarying float v_foil;\n\nfloat h(float n) {\n\treturn fract(sin(n * 12.9898) * 43758.5453);\n}\n\nmat3 turn(vec3 a, float t) {\n\tfloat s = sin(t);\n\tfloat c = cos(t);\n\tfloat o = 1.0 - c;\n\treturn mat3(\n\t\tvec3(o * a.x * a.x + c, o * a.x * a.y + a.z * s, o * a.z * a.x - a.y * s),\n\t\tvec3(o * a.x * a.y - a.z * s, o * a.y * a.y + c, o * a.y * a.z + a.x * s),\n\t\tvec3(o * a.z * a.x + a.y * s, o * a.y * a.z - a.x * s, o * a.z * a.z + c));\n}\n\nvoid vertex() {\n\tfloat id = float(INSTANCE_ID) + 1.0;\n\tvec3 axis = normalize(vec3(h(id * 1.31), h(id * 2.17), h(id * 3.73)) * 2.0 - 1.0 + 0.001);\n\tfloat rate = mix(6.0, 16.0, h(id * 5.11)) * (h(id * 7.97) < 0.5 ? -1.0 : 1.0);\n\tfloat t = h(id * 9.43) * 6.2832 + INSTANCE_CUSTOM.y * life * rate;\n\tmat3 r = turn(axis, t);\n\tVERTEX = r * VERTEX;\n\tNORMAL = r * NORMAL;\n\tTANGENT = r * TANGENT;\n\tvec3 c = COLOR.rgb;\n\tv_paper = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92),\n\t\tlessThan(c, vec3(0.04045)));\n\tv_foil = step(0.75, h(id * 11.7));\n}\n\nvoid fragment() {\n\tALBEDO = v_paper;\n\tMETALLIC = v_foil * 0.85;\n\tROUGHNESS = mix(0.45, 0.22, v_foil);\n\tSPECULAR = 0.7;\n\t// A little of its own light, so the colour survives a dim corner of the\n\t// shed instead of going to mud.\n\tEMISSION = v_paper * mix(0.35, 0.2, v_foil);\n}\n"


static var _shader: Shader


func play(radius: float) -> void:
	var pm:= _process_material()
	var mesh:= QuadMesh.new()
	mesh.size = PIECE
	var material:= ShaderMaterial.new()
	material.shader = _get_shader()
	material.set_shader_parameter("life", LIFETIME)
	mesh.material = material

	var ring:= maxf(radius * 0.9, 2.0)
	var cannons:= clampi(int(radius * 0.8), 6, 12)
	var reach:= ring + 8.0
	for i in cannons:
		var a:= TAU * float(i) / float(cannons)
		var at:= Vector3(cos(a) * ring, 0.4, sin(a) * ring)
		var cannon:= GPUParticles3D.new()
		cannon.name = "Confetti%d" % i
		cannon.amount = PER_CANNON
		cannon.lifetime = LIFETIME
		cannon.one_shot = true
		cannon.explosiveness = 0.88
		cannon.randomness = 0.3
		cannon.local_coords = false
		cannon.fixed_fps = 30
		cannon.interpolate = true
		cannon.process_material = pm
		cannon.draw_pass_1 = mesh
		cannon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cannon.emitting = false
		add_child(cannon)
		cannon.position = at


		cannon.look_at(global_position + Vector3(0.0, 0.4, 0.0), Vector3.UP)


		cannon.visibility_aabb = AABB(Vector3(- reach, -2.0, - reach),
			Vector3(reach * 2.0, 16.0, reach * 2.0))
		get_tree().create_timer(STAGGER * float(i)).timeout.connect(
			func() -> void: cannon.emitting = true)
	get_tree().create_timer(STAGGER * float(cannons) + LIFETIME + 1.0).timeout.connect(
		queue_free)


func _process_material() -> ParticleProcessMaterial:
	var pm:= ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3(0.0, 0.82, -0.57)
	pm.spread = 14.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 14.0


	pm.gravity = Vector3(0.0, -5.0, 0.0)
	pm.damping_min = 3.4
	pm.damping_max = 4.3
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	pm.lifetime_randomness = 0.3


	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_noise_speed = Vector3(0.3, 0.0, 0.3)
	pm.turbulence_influence_min = 0.06
	pm.turbulence_influence_max = 0.16
	var sway:= Curve.new()
	sway.add_point(Vector2(0.0, 0.0))
	sway.add_point(Vector2(0.25, 1.0))
	sway.add_point(Vector2(1.0, 1.0))
	var sway_tex:= CurveTexture.new()
	sway_tex.curve = sway
	pm.turbulence_influence_over_life = sway_tex


	var colours:= Gradient.new()
	colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets:= PackedFloat32Array()
	for i in PAPER.size():
		offsets.append(float(i) / float(PAPER.size()))
	colours.offsets = offsets
	colours.colors = PackedColorArray(PAPER)
	var colour_tex:= GradientTexture1D.new()
	colour_tex.gradient = colours
	pm.color_initial_ramp = colour_tex


	var shrink:= Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.8, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_tex:= CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	return pm


static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader
