class_name MetalDetector
extends Node3D


const MODEL_PATH:= "res://assets/models/compiled/metal_detector.scn"
const PING_SHADER:= "res://assets/detector_ping.gdshader"


const HEAD_TIP:= Vector3(-0.5418, 0.5115, 0.0)

const GRIP_END:= Vector3(0.1279, -0.077, 0.0)


const MODEL_FACE:= Vector3(0.0, 0.0, 1.0)


const SHAFT_LEN:= 0.892


const GRIP_SIDE:= 0.4
const GRIP_DOWN:= 0.2
const GRIP_FORWARD:= 0.45


const SHAFT_DIR:= Vector3(-0.05, 0.5, -1.0)


const FACE_ROLL:= 1.45


const IDLE_GRIP_SIDE:= 0.55
const IDLE_GRIP_DOWN:= 0.45
const IDLE_GRIP_FORWARD:= 0.75
const IDLE_SHAFT_DIR:= Vector3(0.02, 1.0, -0.16)

const POWER_BLEND:= 0.34


var player: Player
var field: HayField


var props: PropManager


var live: LiveStrandManager

var visual: Node3D

var _active:= false


var _powered:= false

var _power_blend:= 0.0


var _signal:= 0.0

var _tick:= 0.0


var _ping_root: Node3D
var _pings: Array [MeshInstance3D] = []

var _ping_age: Array [float] = []

var _surge: MeshInstance3D
var _surge_age:= -1.0


var _surge_on:= true


var power_cycles:= 0


func setup(p_field: HayField, p_props: PropManager = null,
		p_live: LiveStrandManager = null) -> void:
	field = p_field
	props = p_props
	live = p_live
	_mount_mesh()
	set_active(false)


func _mount_mesh() -> void:
	visual = Node3D.new()
	visual.name = "DetectorVisual"
	if player != null and player.camera != null:
		player.camera.add_child(visual)
	else:
		add_child(visual)

	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("MetalDetector: could not load %s" % MODEL_PATH)
		return
	var inst: Node3D = packed.instantiate()
	_ground_materials(inst)
	visual.add_child(inst)
	_update_visual_pose()
	_mount_pings()


func _ground_materials(inst: Node3D) -> void:
	var meshes:= inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)
	for child in meshes:
		var mi:= child as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(s)
			if src is not StandardMaterial3D:
				continue
			var m:= (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.metallic = minf(m.metallic, 0.15)
			m.roughness = maxf(m.roughness, 0.58)
			mi.set_surface_override_material(s, m)


func set_active(on: bool) -> void:
	_active = on
	if visual != null:
		visual.visible = on
	if on:
		_tick = 0.0
		_update_visual_pose()
	else:
		_signal = 0.0


		_powered = false
		_power_blend = 0.0
	_clear_pings()
	_clear_surge()


func is_active() -> bool:
	return _active


func toggle_power() -> void:
	if not _active:
		return
	_powered = not _powered
	if not _powered:
		_signal = 0.0
		_tick = 0.0
		_clear_pings()
		power_cycles += 1
	else:


		_tick = 0.0


	_emit_surge(_powered)
	Audio.play("ui_toggle", -4.0)


func is_powered() -> bool:
	return _powered


func set_power(on: bool) -> void:
	if _powered == on:
		return
	_powered = on
	if not on:
		_signal = 0.0
		_clear_pings()
		_clear_surge()
	_tick = 0.0
	_power_blend = 1.0 if on else 0.0
	_update_visual_pose()


func signal_strength() -> float:
	return _signal


func coil_position() -> Vector3:
	return _coil_world()


func _read_signal(at: Vector3) -> float:
	var range_m:= Tech.detector_range()
	if range_m <= 0.0:
		return 0.0

	var best:= 0.0
	var positions:= GameState.needle_positions
	for i in positions.size():
		if GameState.needle_taken [i] == 1:
			continue
		var n:= positions [i]


		if absf(n.x - at.x) > range_m or absf(n.z - at.z) > range_m:
			continue
		var d:= at.distance_to(n)
		if d > range_m:
			continue
		var cover:= 0.0
		if field != null:
			cover = maxf(field.depth_floor_at(n.x, n.z) - n.y, 0.0)
		var effective:= d + cover * Cfg.DETECT_HAY_COST
		if effective >= range_m:
			continue
		var s: float = 1.0 - effective / range_m
		if s > best:
			best = s
	best = maxf(best, _read_blocks(at, range_m))
	best = maxf(best, _read_loose(at, range_m))
	return best if best >= Cfg.DETECT_FLOOR else 0.0


func _read_loose(at: Vector3, range_m: float) -> float:
	if live == null:
		return 0.0
	var best:= 0.0
	for b in live.needles:
		if not is_instance_valid(b):
			continue
		var p:= b.global_position
		if absf(p.x - at.x) > range_m or absf(p.z - at.z) > range_m:
			continue
		var d:= at.distance_to(p)
		if d >= range_m:
			continue
		var s: float = 1.0 - d / range_m
		if s > best:
			best = s
	return best


func _read_blocks(at: Vector3, range_m: float) -> float:
	if props == null:
		return 0.0
	var muffle:= range_m * Cfg.DETECT_BLOCK_MUFFLE
	var best:= 0.0
	for item in props.items:
		if not is_instance_valid(item) or not item.holds_needle():
			continue
		var p:= item.global_position


		if absf(p.x - at.x) > range_m or absf(p.z - at.z) > range_m:
			continue
		var effective:= at.distance_to(p) + muffle
		if effective >= range_m:
			continue
		var s: float = 1.0 - effective / range_m
		if s > best:
			best = s
	return best


func _tick_audio(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	if _signal <= 0.0:
		_tick = Cfg.DETECT_TICK_IDLE
		Audio.play_pitched("detector_beep", 0.72, -20.0)
		_emit_ping()
		return
	_tick = lerpf(Cfg.DETECT_TICK_SLOW, Cfg.DETECT_TICK_FAST, _signal)


	Audio.play_pitched("detector_beep", 0.9 + 0.5 * _signal, -12.0 + 5.0 * _signal)
	_emit_ping()


static func _grip_at(power:= 1.0) -> Vector3:
	var live:= Vector3(GRIP_SIDE, - GRIP_DOWN, - GRIP_FORWARD)
	var idle:= Vector3(IDLE_GRIP_SIDE, - IDLE_GRIP_DOWN, - IDLE_GRIP_FORWARD)
	return idle.lerp(live, smoothstep(0.0, 1.0, power))


static func _shaft_at(power:= 1.0) -> Vector3:
	var live:= SHAFT_DIR.normalized()
	return IDLE_SHAFT_DIR.normalized().lerp(live, smoothstep(0.0, 1.0, power)).normalized()


static func head_offset(power:= 1.0) -> Vector3:
	return _grip_at(power) + _shaft_at(power) * SHAFT_LEN


func _local_pose() -> Transform3D:
	var grip:= _grip_at(_power_blend)
	var along:= _shaft_at(_power_blend)


	var side:= along.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var face:= along.cross(side).normalized().rotated(along, FACE_ROLL)

	var m_along:= (HEAD_TIP - GRIP_END).normalized()
	var m_face:= MODEL_FACE.normalized()
	var bm:= Basis(m_along, m_face, m_along.cross(m_face))
	var bw:= Basis(along, face, along.cross(face))
	var rot:= bw * bm.transposed()
	return Transform3D(rot, grip - rot * GRIP_END)


func head_local() -> Vector3:
	return head_offset(_power_blend)


func _update_visual_pose() -> void:
	if visual != null and player != null:
		visual.transform = _local_pose()


func _coil_world() -> Vector3:
	if visual != null:
		return visual.global_transform * HEAD_TIP
	if player != null and player.camera != null:
		return player.camera.global_transform * head_local()
	return global_position


func _process(delta: float) -> void:
	if not _active or player == null:
		return
	_power_blend = move_toward(_power_blend, 1.0 if _powered else 0.0, delta / POWER_BLEND)
	_update_visual_pose()
	_advance_pings(delta)
	_advance_surge(delta)


func _physics_process(delta: float) -> void:
	if not _active or not _powered or player == null:
		_signal = 0.0
		return
	_signal = _read_signal(_coil_world())
	_tick_audio(delta)


const PING_COUNT:= 3

const PING_LIFE:= 0.55


const PING_SIZE:= 1.6
const PING_AHEAD:= 0.35


func _mount_pings() -> void:
	if player == null or player.camera == null:
		return


	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return
	var shader: Shader = load(PING_SHADER)
	if shader == null:
		push_error("MetalDetector: could not load %s" % PING_SHADER)
		return
	_ping_root = Node3D.new()
	_ping_root.name = "DetectorPings"
	player.camera.add_child(_ping_root)

	var quad:= QuadMesh.new()
	quad.size = Vector2(PING_SIZE, PING_SIZE)
	for i in PING_COUNT:
		var mi:= MeshInstance3D.new()
		mi.name = "Ping%d" % i
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


		mi.extra_cull_margin = PING_SIZE
		var mat:= ShaderMaterial.new()
		mat.shader = shader
		mi.material_override = mat
		mi.visible = false
		_ping_root.add_child(mi)
		_pings.append(mi)
		_ping_age.append(-1.0)
	_mount_surge(shader)


func emit_ping() -> void:
	_emit_ping()


func _emit_ping() -> void:
	if _pings.is_empty():
		return
	var pick:= 0
	var oldest:= -1.0
	for i in _pings.size():
		if _ping_age [i] < 0.0:
			pick = i
			oldest = -1.0
			break
		if _ping_age [i] > oldest:
			oldest = _ping_age [i]
			pick = i
	_ping_age [pick] = 0.0
	_pings [pick].visible = true
	_place_ping(_pings [pick])
	_write_ping(pick)


func _advance_pings(delta: float) -> void:
	for i in _pings.size():
		if _ping_age [i] < 0.0:
			continue
		_ping_age [i] += delta
		if _ping_age [i] >= PING_LIFE:
			_ping_age [i] = -1.0
			_pings [i].visible = false
			continue
		_place_ping(_pings [i])
		_write_ping(i)


func _place_ping(mi: MeshInstance3D) -> void:
	var along:= _shaft_at(_power_blend)
	mi.position = head_local() + along * PING_AHEAD


func _write_ping(i: int) -> void:
	var mat:= _pings [i].material_override as ShaderMaterial
	if mat == null:
		return
	var t: float = clampf(_ping_age [i] / PING_LIFE, 0.0, 1.0)
	mat.set_shader_parameter("radius", lerpf(0.05, 1.0, t))
	mat.set_shader_parameter("width", lerpf(0.13, 0.04, t))
	mat.set_shader_parameter("feather", lerpf(0.1, 0.05, t))
	mat.set_shader_parameter("strength", lerpf(0.032, 0.004, t))


	mat.set_shader_parameter("fade", (1.0 - t) * (1.0 - 0.35 * t))


func _clear_pings() -> void:
	for i in _pings.size():
		_ping_age [i] = -1.0
		_pings [i].visible = false


const SURGE_LIFE:= 0.85


const SURGE_SIZE:= 2.6


const SURGE_ON_TINT:= Vector3(1.0, 0.76, 0.32)
const SURGE_OFF_TINT:= Vector3(0.42, 0.52, 0.62)


func _mount_surge(shader: Shader) -> void:
	var quad:= QuadMesh.new()
	quad.size = Vector2(SURGE_SIZE, SURGE_SIZE)
	_surge = MeshInstance3D.new()
	_surge.name = "PowerSurge"
	_surge.mesh = quad
	_surge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surge.extra_cull_margin = SURGE_SIZE
	var mat:= ShaderMaterial.new()
	mat.shader = shader
	_surge.material_override = mat
	_surge.visible = false
	_ping_root.add_child(_surge)


func _emit_surge(on: bool) -> void:
	if _surge == null:
		return
	_surge_on = on
	_surge_age = 0.0
	_surge.visible = true
	_place_surge()
	_write_surge()


func _advance_surge(delta: float) -> void:
	if _surge == null or _surge_age < 0.0:
		return
	_surge_age += delta
	if _surge_age >= SURGE_LIFE:
		_surge_age = -1.0
		_surge.visible = false
		return
	_place_surge()
	_write_surge()


func _place_surge() -> void:
	var along:= _shaft_at(_power_blend)
	_surge.position = head_local() + along * PING_AHEAD


func _write_surge() -> void:
	var mat:= _surge.material_override as ShaderMaterial
	if mat == null:
		return
	var t: float = clampf(_surge_age / SURGE_LIFE, 0.0, 1.0)
	var out:= 1.0 - pow(1.0 - t, 2.5)
	mat.set_shader_parameter("radius", lerpf(0.04, 1.0, out))
	mat.set_shader_parameter("width", lerpf(0.2, 0.05, out))
	mat.set_shader_parameter("feather", lerpf(0.14, 0.05, out))
	mat.set_shader_parameter("strength", lerpf(0.055, 0.004, out))
	mat.set_shader_parameter("tint", SURGE_ON_TINT if _surge_on else SURGE_OFF_TINT)


	var lit:= 1.25 if _surge_on else 0.7
	mat.set_shader_parameter("glow", lit)
	mat.set_shader_parameter("fade", (1.0 - t) * (1.0 - 0.35 * t))


func _clear_surge() -> void:
	if _surge == null:
		return
	_surge_age = -1.0
	_surge.visible = false
