class_name NeedleGlints
extends Node3D


const NEAR:= 3.0
const FAR:= 5.5


const SIZE:= 0.21


const LIFT:= 0.045


const SHARPNESS:= 1200.0


const DECAY:= 4.5


const ENERGY:= 3.2


const REST:= 0.03


const SWEEP_A:= 9.0
const SWEEP_RATE_A:= 0.31
const SWEEP_B:= 4.0
const SWEEP_RATE_B:= 0.127


const SIGHT_CHECK:= 0.2

var live: LiveStrandManager
var player: Node3D


var sun_dir:= Vector3(0.4313, 0.6817, -0.591)


var _pool: Array [Dictionary] = []


var _hot: Dictionary = { }
var _fresh: Dictionary = { }


var _sight: Dictionary = { }
var _sight_due: Dictionary = { }
var _time:= 0.0


var _peak:= 0.0
var _drawn:= 0


const GLINT_SHADER:= "\r\nshader_type spatial;\r\nrender_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;\r\n\r\nuniform vec4 core_tint : source_color = vec4(1.0, 0.99, 0.96, 1.0);\r\nuniform vec4 edge_tint : source_color = vec4(1.0, 0.87, 0.62, 1.0);\r\nuniform float energy = 0.0;\r\n\r\nvoid fragment() {\r\n\tvec2 p = UV * 2.0 - 1.0;\r\n\tfloat r = length(p);\r\n\t// Sized in fractions of the quad, so the shape holds whatever SIZE is set\r\n\t// to: a core about an eighth of the way out, a soft ball around it, and the\r\n\t// four-point star a bright highlight throws through a lens. The star is\r\n\t// what makes a dot read as a FLASH rather than as a light -- it is the part\r\n\t// the eye recognises as \"something over there is very bright\".\r\n\tfloat core = exp(-r * r * 45.0) * 6.0 + exp(-r * r * 12.0) * 1.6;\r\n\tfloat halo = exp(-r * r * 3.0) * 0.42;\r\n\tfloat star = (exp(-p.x * p.x * 170.0) + exp(-p.y * p.y * 170.0))\r\n\t\t* exp(-r * r * 4.0) * 0.85;\r\n\tfloat v = (core + halo + star) * (1.0 - smoothstep(0.62, 1.0, r));\r\n\tALBEDO = mix(edge_tint.rgb, core_tint.rgb, clamp(core, 0.0, 1.0)) * v * energy;\r\n\tALPHA = 1.0;\r\n}\r\n"


var _shader: Shader
var _mesh: QuadMesh


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = GLINT_SHADER
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(SIZE, SIZE)


func peak() -> float:
	return _peak


func drawn() -> int:
	return _drawn


func _process(delta: float) -> void:
	_time += delta
	_peak = 0.0
	_drawn = 0
	_fresh = { }
	if live == null or not is_instance_valid(player):
		_hot = _fresh
		_hide_from(0)
		return
	var eye:= player.global_position
	if player is Player:
		eye = (player as Player).eye_position()

	for b in live.needles:
		if not is_instance_valid(b):
			continue


		if b.freeze and not LiveStrandManager.is_pinned(b):
			continue
		var p:= _highlight_point(b)
		var d:= p.distance_to(eye)
		if d >= FAR:
			continue
		var close:= clampf(inverse_lerp(FAR, NEAR, d), 0.0, 1.0)


		close = close * close * (3.0 - 2.0 * close)
		_draw(_drawn, b, p, eye, close, delta)
		_drawn += 1

	_hot = _fresh
	_hide_from(_drawn)


func _draw(index: int, b: RigidBody3D, at: Vector3, eye: Vector3, close: float,
		delta: float) -> void:
	while _pool.size() <= index:
		_pool.append(_make_quad())
	var entry:= _pool [index]
	var mi:= entry ["mesh"] as MeshInstance3D


	var phase:= float(b.get_instance_id() % 997) * 0.0063
	var off:= SWEEP_A * sin(_time * TAU * SWEEP_RATE_A + phase) + SWEEP_B * sin(_time * TAU * SWEEP_RATE_B + phase * 2.3)


	var spec:= pow(maxf(cos(deg_to_rad(off)), 0.0), SHARPNESS)
	var id:= b.get_instance_id()
	var hot:= maxf(spec, float(_hot.get(id, 0.0)) - delta * DECAY)
	_fresh [id] = hot

	var lit:= (REST + hot * (1.0 - REST)) * close
	_peak = maxf(_peak, lit)
	mi.visible = lit > 0.002
	if not mi.visible:
		return
	mi.global_position = at


	var to_eye:= eye - at
	if to_eye.length_squared() > 1e-06:
		mi.look_at(eye, Vector3.UP if absf(to_eye.normalized().y) < 0.99
			else Vector3.RIGHT)


	mi.scale = Vector3.ONE * lerpf(0.55, 1.0, pow(lit, 0.35))
	(entry ["mat"] as ShaderMaterial).set_shader_parameter("energy", lit * ENERGY)


func _in_sight(b: RigidBody3D, at: Vector3, eye: Vector3, delta: float) -> bool:
	var id:= b.get_instance_id()
	var due:= float(_sight_due.get(id, 0.0)) - delta
	if due > 0.0:
		_sight_due [id] = due
		return bool(_sight.get(id, true))


	_sight_due [id] = SIGHT_CHECK * (0.5 + float(id % 97) / 194.0)
	var q:= PhysicsRayQueryParameters3D.create(eye, at)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
	q.collide_with_areas = false
	var clear:= get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_sight [id] = clear
	return clear


func _highlight_point(b: RigidBody3D) -> Vector3:
	for c in b.get_children():
		if c is MeshInstance3D:
			return (c as MeshInstance3D).global_position + Vector3(0, LIFT, 0)
	return b.global_position + Vector3(0, LIFT, 0)


func _hide_from(index: int) -> void:
	for k in range(index, _pool.size()):
		(_pool [k] ["mesh"] as MeshInstance3D).visible = false


func _make_quad() -> Dictionary:
	var mat:= ShaderMaterial.new()
	mat.shader = _shader
	var mi:= MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return { "mesh": mi, "mat": mat }
