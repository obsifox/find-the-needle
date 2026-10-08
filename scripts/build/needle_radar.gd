class_name NeedleRadar
extends Node3D


const MODEL:= "res://assets/models/needle_radar.glb"
const CLIP:= "SearchSweep"
const BEAM_SHADER:= preload("res://assets/radar_beam.gdshader")
const RING_SHADER:= preload("res://assets/radar_ring.gdshader")
const FLARE_SHADER:= preload("res://assets/coin_rays.gdshader")


const N_AZIMUTH:= "AzimuthPivot"
const N_ELEVATION:= "ElevationPivot"
const N_AIM:= "AimDirection"
const N_HYD_BASE:= "HydraulicBase"
const N_HYD_TIP:= "HydraulicTip"
const N_BARREL:= "HydraulicBarrelPivot"
const N_ROD:= "HydraulicRodPivot"


const HORN_AT:= Vector3(0.0, 0.0, 2.44)


const ELEVATION_MIN:= 14.0
const ELEVATION_MAX:= 52.0


const LOOK:= 6.0


const CONSOLE_AT:= Vector3(1.43, 1.2, 0.79)


const BODY_BOX:= Vector3(4.4, 1.55, 3.6)
const MAST_BOX:= Vector3(1.6, 2.3, 1.6)
const MAST_Y:= 2.45


const COL_BEAM:= Color(0.4, 0.85, 1.0)


const COL_AREA:= Color(1.0, 0.68, 0.16)

const COL_SPOT:= Color(0.42, 0.92, 1.0)


const SPOT_CORE:= 0.035
const SPOT_HALO:= 0.2

const SPOT_RING:= 0.75

const BEAM_CORE_SHARE:= 0.28


const MARK_REFRESH:= 0.2

const MARK_FADE_IN:= 0.5
const MARK_FADE_OUT:= 1.5


const TAG_FONT:= 26
const TAG_PIXEL:= 0.0009


const TAG_RANGE:= 16.0


const IMPACT_SECONDS:= 0.9
const IMPACT_RADIUS:= 4.5


const MOTOR_FULL_DEG:= 30.0
const MOTOR_DB:= -2.0
const MOTOR_SWEEP_DB:= -9.0
const MOTOR_REACH:= 40.0

enum Phase { IDLE, TURN, LOCK, BEAM, RETURN }

var placement_preview:= false

var field: HayField


var cooldown: float:
	get:
		return GameState.radar_cooldown
	set(value):
		GameState.radar_cooldown = maxf(0.0, value)

var last_found:= -1


var tier_override:= -1

var phase:= Phase.IDLE

var _model: Node3D
var _anim: AnimationPlayer
var _azimuth: Node3D
var _elevation: Node3D
var _aim: Node3D
var _hyd_base: Node3D
var _hyd_tip: Node3D
var _barrel: Node3D
var _rod: Node3D


var _barrel_x:= Vector3.RIGHT
var _rod_x:= Vector3.RIGHT

var _phase_t:= 0.0
var _delivered:= false
var _landed:= false
var _fired_tier:= 0
var _targets:= PackedInt32Array()
var _target:= Vector3.ZERO

var _home_azimuth:= 0.0
var _home_elevation:= 0.0

var _uplink: MeshInstance3D
var _uplink_halo: MeshInstance3D
var _downlink: MeshInstance3D
var _downlink_halo: MeshInstance3D
var _flare: MeshInstance3D
var _flare_mat: ShaderMaterial
var _glint: MeshInstance3D
var _glint_mat: ShaderMaterial
var _impact: MeshInstance3D
var _impact_t:= -1.0
var _pool: MeshInstance3D
var _spin:= 0.0

var _motor:= -1
var _motor_level:= 0.0
var _last_az:= 0.0
var _last_el:= 0.0


var _marks: Array [Dictionary] = []
var _mark_since:= 0.0

static var _headless:= DisplayServer.get_name() == "headless"
static var _tube: CylinderMesh
static var _disc: PlaneMesh
static var _card: QuadMesh
static var _beam_core_mat: ShaderMaterial
static var _beam_halo_mat: ShaderMaterial
static var _spot_core_mat: ShaderMaterial
static var _spot_halo_mat: ShaderMaterial
static var _spot_ring_mat: ShaderMaterial
static var _area_wall_mat: ShaderMaterial
static var _area_ring_mat: ShaderMaterial
static var _impact_mat: ShaderMaterial
static var _pool_mat: ShaderMaterial


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_load_model()
	_build_bodies()
	if placement_preview:
		set_process(false)
		set_preview_valid(true)
		return
	_build_beams()
	add_to_group("needle_radars")
	if _azimuth != null:
		_last_az = _azimuth.rotation.y
	if _elevation != null:
		_last_el = _elevation.rotation.x


func _process(delta: float) -> void:
	tick(delta)


func _exit_tree() -> void:
	if _motor >= 0:
		Audio.loop_release(_motor)
		_motor = -1


func tier() -> int:
	if tier_override >= 0:
		return mini(tier_override, Cfg.RADAR_TIERS.size() - 1)
	return Tech.radar_tier()


func tier_data() -> Dictionary:
	return Cfg.RADAR_TIERS [clampi(tier(), 0, Cfg.RADAR_TIERS.size() - 1)]


func activate() -> String:
	if placement_preview:
		return "preview"
	if tier() < 0:
		return tr("needs the Satellite Dish plans")
	if phase != Phase.IDLE:
		return tr("already scanning")
	if cooldown > 0.0:
		return tr("recharging")
	_fired_tier = tier()
	_targets = targets_in_range()
	_target = _aim_point(_targets)
	if _azimuth != null:
		_home_azimuth = _azimuth.rotation.y
	if _elevation != null:
		_home_elevation = _elevation.rotation.x
	if _anim != null:
		_anim.pause()
	_phase_t = 0.0
	_delivered = false
	_landed = false
	phase = Phase.TURN
	return ""


func is_busy() -> bool:
	return phase != Phase.IDLE


func targets_in_range() -> PackedInt32Array:
	var out:= PackedInt32Array()
	var here:= global_position
	var r2:= Cfg.RADAR_RANGE * Cfg.RADAR_RANGE
	for i in GameState.needle_positions.size():
		if i >= GameState.needle_taken.size() or GameState.needle_taken [i] != 0:
			continue
		var p:= GameState.needle_positions [i]
		var dx:= p.x - here.x
		var dz:= p.z - here.z
		if dx * dx + dz * dz <= r2:
			out.append(i)
	return out


func tick(delta: float) -> void:


	if not is_inside_tree() or get_tree().get_first_node_in_group("needle_radars") == self:
		cooldown = cooldown - delta
	_tick_marks(delta)
	match phase:
		Phase.TURN:
			if _turn_to(bearing_to(_target), - deg_to_rad(Cfg.RADAR_UPLINK_ELEVATION), delta):
				phase = Phase.LOCK
				_phase_t = 0.0
				Audio.play_3d("radar_stop", _motor_at())
		Phase.LOCK:
			_phase_t += delta
			_fit_flare(_phase_t / Cfg.RADAR_LOCK_SECONDS, delta)
			if _phase_t >= Cfg.RADAR_LOCK_SECONDS:
				phase = Phase.BEAM
				_phase_t = 0.0
				_show_beams(true)
				Audio.play_3d("needle_reveal", global_position)
		Phase.BEAM:
			_phase_t += delta
			var t:= clampf(_phase_t / Cfg.RADAR_BEAM_SECONDS, 0.0, 1.0)
			_fit_beams(t, delta)


			if not _delivered and _phase_t >= Cfg.RADAR_BEAM_SECONDS * 0.5:
				_deliver()
			if _phase_t >= Cfg.RADAR_BEAM_SECONDS:
				_show_beams(false)
				phase = Phase.RETURN
		Phase.RETURN:
			if _turn_to(_home_azimuth, _home_elevation, delta):
				phase = Phase.IDLE
				Audio.play_3d("radar_stop", _motor_at(), -4.0)
				if _anim != null:
					_anim.play()
	_tick_impact(delta)
	_tick_motor(delta)


func bearing_to(point: Vector3) -> float:
	if _azimuth == null or _azimuth.get_parent() == null:
		return 0.0
	var local:= (_azimuth.get_parent() as Node3D).to_local(point) - _azimuth.position
	return atan2(local.x, local.z)


func bearing_error(point: Vector3) -> float:
	if _azimuth == null:
		return PI
	return absf(angle_difference(_azimuth.rotation.y, bearing_to(point)))


func elevation_degrees() -> float:
	return - rad_to_deg(_elevation.rotation.x) if _elevation != null else 0.0


func aim_point() -> Vector3:
	return _target


func horn_position() -> Vector3:
	if _elevation == null:
		return global_position + Vector3.UP * MAST_Y
	return _elevation.to_global(HORN_AT)


func hydraulic_length() -> float:
	if _barrel == null or _rod == null:
		return 0.0
	return _barrel.position.distance_to(_rod.position)


func pose(azimuth_deg: float, elevation_deg: float) -> void:
	if _anim != null:
		_anim.pause()
	if _azimuth == null or _elevation == null:
		return
	_azimuth.rotation.y = deg_to_rad(azimuth_deg)
	_elevation.rotation.x = - deg_to_rad(clampf(elevation_deg, ELEVATION_MIN, ELEVATION_MAX))
	_fit_hydraulics()
	_last_az = _azimuth.rotation.y
	_last_el = _elevation.rotation.x


func marks() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for m in _marks:
		var index:= int(m ["index"])
		out.append({
			"index": index, "centre": m ["centre"], "exact": m ["exact"],
			"depth": m ["depth"], "left": m ["left"], "depth_text": depth_text(index),
			"tag": tag_text(index) if bool(m ["depth"]) else "",
		})
	return out


func clear_marks() -> void:
	for m in _marks:
		var node:= m ["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
	_marks.clear()


static func area_centre(p: Vector3) -> Vector3:
	var rng:= RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)))
	var angle:= rng.randf() * TAU


	var dist:= sqrt(rng.randf()) * Cfg.RADAR_AREA_RADIUS * Cfg.RADAR_AREA_SPREAD
	return p + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func depth_of(index: int) -> float:
	if index < 0 or index >= GameState.needle_positions.size():
		return 0.0
	var p:= GameState.needle_positions [index]
	return maxf(0.0, _surface_y(p) - p.y)


func depth_text(index: int) -> String:
	return tr("%.1f m deep") % depth_of(index)


func needle_name(index: int) -> String:
	return NeedleTypes.name_of(GameState.type_of(index))


func tag_text(index: int) -> String:
	return "%s\n%s" % [needle_name(index), depth_text(index)]


func _deliver() -> void:
	_delivered = true
	last_found = _targets.size()
	if _targets.is_empty():


		return
	cooldown = Cfg.RADAR_COOLDOWN
	var data: Dictionary = Cfg.RADAR_TIERS [_fired_tier]
	for index in _targets:
		_add_mark(index, data)
	Audio.play_3d("detector_beep", _target)


func _add_mark(index: int, data: Dictionary) -> void:

	for k in range(_marks.size() - 1, -1, -1):
		if int(_marks [k] ["index"]) == index:
			var old:= _marks [k] ["node"] as Node3D
			if is_instance_valid(old):
				old.queue_free()
			_marks.remove_at(k)
	_ensure_resources()
	var p:= GameState.needle_positions [index]
	var exact:= bool(data ["exact"])
	var node:= Node3D.new()
	node.name = "Mark%d" % index
	node.top_level = true
	add_child(node)
	var shaft: MeshInstance3D
	var halo: MeshInstance3D = null
	var ring: MeshInstance3D
	if exact:
		shaft = _glow_instance(node, _tube, _spot_core_mat)
		halo = _glow_instance(node, _tube, _spot_halo_mat)
		ring = _glow_instance(node, _disc, _spot_ring_mat)
	else:
		shaft = _glow_instance(node, _tube, _area_wall_mat)
		ring = _glow_instance(node, _disc, _area_ring_mat)
	var label: Label3D = null


	if bool(data ["depth"]) and not _headless:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = TAG_PIXEL
		label.font_size = TAG_FONT
		label.outline_size = 8
		label.outline_modulate = Color(0.0, 0.05, 0.08, 0.85)
		label.modulate = Color(0.85, 0.97, 1.0)
		label.line_spacing = -4.0
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.visibility_range_end = TAG_RANGE
		label.visibility_range_end_margin = 4.0
		label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(label)
	_marks.append({
		"index": index,
		"centre": p if exact else area_centre(p),
		"exact": exact,
		"depth": bool(data ["depth"]),
		"left": float(data ["seconds"]),
		"age": 0.0,
		"node": node, "shaft": shaft, "halo": halo, "ring": ring, "label": label,
	})
	var m:= _marks [_marks.size() - 1]
	_place_mark(m)
	_fade_mark(m)


func _tick_marks(delta: float) -> void:
	if _marks.is_empty():
		return
	_mark_since += delta
	var refresh:= _mark_since >= MARK_REFRESH
	if refresh:
		_mark_since = 0.0
	for k in range(_marks.size() - 1, -1, -1):
		var m:= _marks [k]
		m ["left"] = float(m ["left"]) - delta
		m ["age"] = float(m ["age"]) + delta
		var index:= int(m ["index"])


		var gone:= index >= GameState.needle_taken.size() or GameState.needle_taken [index] != 0
		if float(m ["left"]) <= 0.0 or gone:
			var node:= m ["node"] as Node3D
			if is_instance_valid(node):
				node.queue_free()
			_marks.remove_at(k)
			continue
		if refresh:
			_place_mark(m)
		_fade_mark(m)


func _place_mark(m: Dictionary) -> void:
	var node:= m ["node"] as Node3D
	if not is_instance_valid(node):
		return
	var centre: Vector3 = m ["centre"]
	var top:= _surface_y(centre)
	var shaft:= m ["shaft"] as MeshInstance3D
	var ring:= m ["ring"] as MeshInstance3D
	var slope:= _surface_basis(centre)
	if bool(m ["exact"]):
		var p:= GameState.needle_positions [int(m ["index"])]
		var reach:= maxf(top + Cfg.RADAR_MARK_HEIGHT - p.y, 0.5)
		node.global_position = p
		shaft.transform = Transform3D(Basis.from_scale(Vector3(SPOT_CORE, reach, SPOT_CORE)),
			Vector3(0.0, reach * 0.5, 0.0))
		var halo:= m ["halo"] as MeshInstance3D
		halo.transform = Transform3D(Basis.from_scale(Vector3(SPOT_HALO, reach, SPOT_HALO)),
			Vector3(0.0, reach * 0.5, 0.0))
		ring.transform = Transform3D(slope.scaled_local(Vector3.ONE * SPOT_RING),
			Vector3(0.0, top - p.y + 0.04, 0.0))
		var label:= m ["label"] as Label3D
		if label != null:
			label.position = Vector3(0.0, reach + 0.15, 0.0)
			label.text = tag_text(int(m ["index"]))
	else:
		var low:= top - Cfg.RADAR_AREA_SINK
		var high:= top + Cfg.RADAR_AREA_HEIGHT
		var r:= Cfg.RADAR_AREA_RADIUS
		node.global_position = Vector3(centre.x, low, centre.z)
		shaft.transform = Transform3D(Basis.from_scale(Vector3(r, high - low, r)),
			Vector3(0.0, (high - low) * 0.5, 0.0))
		ring.transform = Transform3D(slope.scaled_local(Vector3.ONE * r * 1.04),
			Vector3(0.0, top - low + 0.05, 0.0))


func _fade_mark(m: Dictionary) -> void:
	if _headless:
		return
	var f:= clampf(float(m ["age"]) / MARK_FADE_IN, 0.0, 1.0) * clampf(float(m ["left"]) / MARK_FADE_OUT, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	for key in ["shaft", "halo", "ring"]:
		var gi:= m [key] as GeometryInstance3D
		if gi != null:
			gi.set_instance_shader_parameter("fade", f)
	var label:= m ["label"] as Label3D
	if label != null:
		label.transparency = 1.0 - f


func _surface_y(p: Vector3) -> float:
	if field == null:
		return p.y
	return maxf(field.height_at(p.x, p.z), 0.0)


func _surface_basis(p: Vector3) -> Basis:
	if field == null:
		return Basis.IDENTITY
	var e:= 0.5
	var n:= Vector3(_surface_y(p - Vector3(e, 0.0, 0.0)) - _surface_y(p + Vector3(e, 0.0, 0.0)),
		2.0 * e,
		_surface_y(p - Vector3(0.0, 0.0, e)) - _surface_y(p + Vector3(0.0, 0.0, e)))
	return _basis_along(n.normalized(), Vector3.RIGHT)


static func _ensure_resources() -> void:
	if _tube != null:
		return


	_tube = CylinderMesh.new()
	_tube.top_radius = 1.0
	_tube.bottom_radius = 1.0
	_tube.height = 1.0
	_tube.radial_segments = 24
	_tube.rings = 1


	_tube.cap_top = false
	_tube.cap_bottom = false
	_disc = PlaneMesh.new()
	_disc.size = Vector2(2.0, 2.0)
	_card = QuadMesh.new()
	_card.size = Vector2(1.0, 1.0)

	_beam_core_mat = _beam_material(COL_BEAM, 2.2, 0.0, 6.0, 38.0)
	_beam_halo_mat = _beam_material(COL_BEAM, 0.55, 0.0, 6.0, 38.0)
	_spot_core_mat = _beam_material(COL_SPOT, 2.4, 0.0, 1.1, 2.2)
	_spot_halo_mat = _beam_material(COL_SPOT, 0.5, 0.0, 1.1, 2.2)


	_area_wall_mat = _beam_material(COL_AREA, 2.0, 1.0, 0.6, 0.8)
	_area_wall_mat.set_shader_parameter("top_fade", 1.0)
	_area_wall_mat.set_shader_parameter("pulse_amount", 0.5)
	_area_wall_mat.set_shader_parameter("end_fade", 0.25)

	_spot_ring_mat = _ring_material(COL_SPOT, 1.4, 2.0, 0.7, 0.0, 0.9)
	_area_ring_mat = _ring_material(COL_AREA, 2.0, 3.0, 0.35, 0.96, 0.0)
	_impact_mat = _ring_material(COL_BEAM, 2.0, 1.0, 0.0, 0.0, 0.0)
	_pool_mat = _ring_material(COL_BEAM, 1.0, 3.0, 1.2, 0.0, 1.2)


static func _beam_material(colour: Color, intensity: float, rim: float,
		spacing: float, speed: float) -> ShaderMaterial:
	var mat:= ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("tint", colour)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("rim", rim)
	mat.set_shader_parameter("pulse_spacing", spacing)
	mat.set_shader_parameter("pulse_speed", speed)
	return mat


static func _ring_material(colour: Color, intensity: float, rings: float, speed: float,
		edge: float, centre: float) -> ShaderMaterial:
	var mat:= ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter("tint", colour)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("rings", rings)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("edge", edge)
	mat.set_shader_parameter("centre", centre)
	return mat


static func _glow_instance(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


func _turn_to(azimuth: float, elevation: float, delta: float) -> bool:
	if _azimuth == null or _elevation == null:
		return true
	var step:= deg_to_rad(Cfg.RADAR_TURN_DEG) * delta
	var lo:= - deg_to_rad(ELEVATION_MAX)
	var hi:= - deg_to_rad(ELEVATION_MIN)
	var want_el:= clampf(elevation, lo, hi)
	_azimuth.rotation.y = rotate_toward(_azimuth.rotation.y, azimuth, step)
	_elevation.rotation.x = move_toward(_elevation.rotation.x, want_el, step)
	_fit_hydraulics()
	return absf(angle_difference(_azimuth.rotation.y, azimuth)) < 0.002 and absf(_elevation.rotation.x - want_el) < 0.002


func _fit_hydraulics() -> void:
	if _barrel == null or _rod == null or _hyd_base == null or _hyd_tip == null:
		return
	var a:= _azimuth.to_local(_hyd_base.global_position)
	var b:= _azimuth.to_local(_hyd_tip.global_position)
	var along:= b - a
	if along.length_squared() < 1e-06:
		return
	var dir:= along.normalized()
	_barrel.transform = Transform3D(_basis_along(dir, _barrel_x), a)
	_rod.transform = Transform3D(_basis_along(- dir, _rod_x), b)


static func _basis_along(y: Vector3, x_hint: Vector3) -> Basis:
	var z:= x_hint.cross(y)
	if z.length_squared() < 1e-06:
		z = Vector3.RIGHT.cross(y)
	z = z.normalized()
	var x:= y.cross(z).normalized()
	return Basis(x, y, z)


func _motor_at() -> Vector3:
	return _azimuth.global_position if _azimuth != null else global_position


func _tick_motor(delta: float) -> void:
	if _azimuth == null or _elevation == null or delta <= 0.0:
		return
	var turned:= absf(angle_difference(_last_az, _azimuth.rotation.y)) + absf(_elevation.rotation.x - _last_el)
	_last_az = _azimuth.rotation.y
	_last_el = _elevation.rotation.x
	var speed:= clampf(rad_to_deg(turned / delta) / MOTOR_FULL_DEG, 0.0, 1.0)
	var want:= speed
	if phase == Phase.IDLE:
		want *= db_to_linear(MOTOR_SWEEP_DB - MOTOR_DB)
	_motor_level = move_toward(_motor_level, want, delta * 4.0)
	var near:= true
	var cam:= get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		near = cam.global_position.distance_to(global_position) <= MOTOR_REACH
	if _motor_level <= 0.001 or not near:
		if _motor >= 0:
			Audio.loop_release(_motor)
			_motor = -1
		return
	if _motor < 0:
		_motor = Audio.loop_acquire("radar_turn")
		if _motor < 0:
			return
	Audio.loop_update(_motor, _motor_at(), linear_to_db(_motor_level) + MOTOR_DB,
		0.9 + 0.15 * speed)


func _build_beams() -> void:
	_ensure_resources()
	_uplink = _beam_instance("Uplink", _tube, _beam_core_mat)
	_uplink_halo = _beam_instance("UplinkHalo", _tube, _beam_halo_mat)
	_downlink = _beam_instance("Downlink", _tube, _beam_core_mat)
	_downlink_halo = _beam_instance("DownlinkHalo", _tube, _beam_halo_mat)
	_pool = _beam_instance("Pool", _disc, _pool_mat)
	_impact = _beam_instance("Impact", _disc, _impact_mat)


	_flare_mat = ShaderMaterial.new()
	_flare_mat.shader = FLARE_SHADER
	_flare_mat.set_shader_parameter("tint", COL_BEAM)
	_flare = _beam_instance("Flare", _card, _flare_mat)
	_glint_mat = ShaderMaterial.new()
	_glint_mat.shader = FLARE_SHADER
	_glint_mat.set_shader_parameter("tint", COL_BEAM)
	_glint = _beam_instance("Glint", _card, _glint_mat)


func _beam_instance(beam_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi:= _glow_instance(self, mesh, mat)
	mi.name = beam_name
	mi.top_level = true
	mi.visible = false
	return mi


func _show_beams(on: bool) -> void:
	for mi: MeshInstance3D in [_uplink, _uplink_halo, _downlink, _downlink_halo, _pool, _glint]:
		if mi != null:
			mi.visible = on
	if on:
		_fit_beams(0.0, 0.0)
	elif _flare != null:
		_flare.visible = false


func _fit_flare(t: float, delta: float) -> void:
	if _flare == null:
		return
	t = clampf(t, 0.0, 1.0)
	_flare.visible = true
	_spin += delta * (1.5 + 6.0 * t)
	_flare.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * (0.3 + 1.3 * t * t)),
		horn_position())
	_flare_mat.set_shader_parameter("strength", 0.2 + 1.3 * t * t)
	_flare_mat.set_shader_parameter("spin", _spin)


func _fit_beams(t: float, delta: float) -> void:
	if _uplink == null or _elevation == null:
		return
	var grow:= clampf(t * 3.0, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var fade:= smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.72, 1.0, t))
	var from:= horn_position()
	var dir:= _elevation.global_basis.z.normalized()
	var up_to:= from + dir * Cfg.RADAR_UPLINK_LENGTH * grow
	_stretch(_uplink, from, up_to, Cfg.RADAR_UPLINK_RADIUS * BEAM_CORE_SHARE)
	_stretch(_uplink_halo, from, up_to, Cfg.RADAR_UPLINK_RADIUS)
	var ground:= Vector3(_target.x, _surface_y(_target), _target.z)
	var sky:= ground + Vector3.UP * Cfg.RADAR_DOWNLINK_HEIGHT
	var down_to:= sky.lerp(ground, grow)
	_stretch(_downlink, sky, down_to, Cfg.RADAR_DOWNLINK_RADIUS * BEAM_CORE_SHARE)
	_stretch(_downlink_halo, sky, down_to, Cfg.RADAR_DOWNLINK_RADIUS)
	if not _headless:
		for mi: MeshInstance3D in [_uplink, _uplink_halo, _downlink, _downlink_halo, _pool]:
			mi.set_instance_shader_parameter("fade", fade)


	_spin += delta * 5.0
	_flare.visible = true
	var flash:= exp(- t * 14.0) * 2.5
	_flare.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * (1.2 + flash * 0.8)), from)
	_flare_mat.set_shader_parameter("strength", (0.9 + flash) * fade)
	_flare_mat.set_shader_parameter("spin", _spin)


	_glint.visible = grow < 1.0
	_glint.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 4.0), down_to)
	_glint_mat.set_shader_parameter("strength", 1.6 * (1.0 - grow * grow))
	_glint_mat.set_shader_parameter("spin", - _spin)

	_pool.visible = grow >= 1.0
	_pool.global_transform = Transform3D(
		_surface_basis(ground).scaled_local(Vector3.ONE * Cfg.RADAR_DOWNLINK_RADIUS * 2.2),
		ground + Vector3.UP * 0.05)
	if grow >= 1.0 and not _landed:
		_landed = true
		_impact_t = 0.0
		_impact.global_transform = Transform3D(
			_surface_basis(ground).scaled_local(Vector3.ONE * IMPACT_RADIUS),
			ground + Vector3.UP * 0.3)


func _tick_impact(delta: float) -> void:
	if _impact == null or _impact_t < 0.0:
		return
	_impact_t += delta
	var t:= _impact_t / IMPACT_SECONDS
	if t >= 1.0:
		_impact.visible = false
		_impact_t = -1.0
		return
	_impact.visible = true
	if not _headless:
		_impact.set_instance_shader_parameter("burst", 1.0 - pow(1.0 - t, 2.0))


static func _stretch(mi: MeshInstance3D, from: Vector3, to: Vector3, radius: float) -> void:
	var along:= to - from
	var length:= maxf(along.length(), 0.01)
	var y:= along / length if along.length_squared() > 1e-08 else Vector3.UP
	var side:= Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var x:= y.cross(side).normalized()
	var z:= x.cross(y).normalized()
	mi.global_transform = Transform3D(Basis(x * radius, y * length, z * radius), (from + to) * 0.5)


func _aim_point(targets: PackedInt32Array) -> Vector3:
	if targets.is_empty():
		return Vector3(0.0, _surface_y(Vector3.ZERO), 0.0)
	var sum:= Vector3.ZERO
	for index in targets:
		sum += GameState.needle_positions [index]
	var mid:= sum / float(targets.size())
	return Vector3(mid.x, _surface_y(mid), mid.z)


func _load_model() -> void:
	var scene:= load(MODEL) as PackedScene
	if scene == null:
		push_warning("NeedleRadar: no model at %s" % MODEL)
		return
	_model = scene.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	_azimuth = _model.find_child(N_AZIMUTH, true, false) as Node3D
	_elevation = _model.find_child(N_ELEVATION, true, false) as Node3D
	_aim = _model.find_child(N_AIM, true, false) as Node3D
	_hyd_base = _model.find_child(N_HYD_BASE, true, false) as Node3D
	_hyd_tip = _model.find_child(N_HYD_TIP, true, false) as Node3D
	_barrel = _model.find_child(N_BARREL, true, false) as Node3D
	_rod = _model.find_child(N_ROD, true, false) as Node3D
	if _azimuth == null or _elevation == null or _aim == null:
		push_warning("NeedleRadar: %s is missing its pivots, the dish will not turn" % MODEL)

	if _barrel != null:
		_barrel_x = _barrel.basis.x.normalized()
	if _rod != null:
		_rod_x = _rod.basis.x.normalized()
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null or not _anim.has_animation(CLIP):
		_anim = null
		return
	_anim.get_animation(CLIP).loop_mode = Animation.LOOP_LINEAR
	if placement_preview:
		return
	_anim.play(CLIP)


	var clip_len:= _anim.get_animation(CLIP).length
	_anim.seek(fposmod(absf(position.x * 7.3 + position.z * 3.1), clip_len), true)


func _build_bodies() -> void:
	var body:= StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	body.collision_mask = 0
	add_child(body)
	_add_box(body, BODY_BOX, Vector3(0.0, BODY_BOX.y * 0.5, 0.0))
	_add_box(body, MAST_BOX, Vector3(0.0, MAST_Y, 0.0))
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _add_box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape:= BoxShape3D.new()
	shape.size = size
	var col:= CollisionShape3D.new()
	col.shape = shape
	col.position = at
	body.add_child(col)


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func in_reach(from: Vector3) -> bool:
	var c:= to_global(CONSOLE_AT)
	return Vector2(from.x - c.x, from.z - c.z).length() <= Cfg.RADAR_REACH


func prompt() -> String:
	if tier() < 0 or phase != Phase.IDLE or cooldown > 0.0:
		return ""
	return tr("Scan the pile")


func plate_source() -> String:
	if tier() < 0:
		return "radar:locked"
	if phase != Phase.IDLE:
		return "radar:busy"
	if cooldown > 0.0:
		return "radar:cool:%d" % ceili(cooldown)
	return "radar:ready:%d" % last_found


static func tier_summary(t: int) -> String:
	var data: Dictionary = Cfg.RADAR_TIERS [clampi(t, 0, Cfg.RADAR_TIERS.size() - 1)]
	var secs:= int(data ["seconds"])
	if not bool(data ["exact"]):
		return Cfg.tr("a rough circle round each needle for %d s") % secs
	if bool(data ["depth"]):
		return Cfg.tr("exact spots, names and depths, for %d s") % secs
	return Cfg.tr("exact spots for %d s") % secs


func build_cost() -> float:
	return Cfg.RADAR_COST


func to_dict() -> Dictionary:
	return {
		"type": "needle_radar",
		"position": global_position,
		"yaw": global_rotation.y,


		"cool": cooldown,
	}


func from_dict(d: Dictionary) -> void:
	cooldown = maxf(cooldown, clampf(float(d.get("cool", 0.0)), 0.0, Cfg.RADAR_COOLDOWN))
