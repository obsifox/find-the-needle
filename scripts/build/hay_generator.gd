class_name HayGenerator
extends Node3D


const MODEL:= "res://assets/models/compiled/hay_generator.scn"
const SPEC:= "res://assets/models/hay_generator_materials.json"


const N_BELT_HEAD:= "Gen_BeltHead"
const N_FIRE:= "Gen_FireLight"
const N_VOLT:= "Gen_Volt_needle"


const N_WIRE_PORT:= "Gen_WirePort"


const WIRE_PORT_FALLBACK:= Vector3(0.0, 2.756, 2.11)


const N_BOIL:= "Boil_Gauge_needle"

const N_HEAP:= "Gen_Heap"

const CLIP:= "Run"


const MAT_LED:= "M_Led"
const MAT_BULB:= "M_Bulb"
const LED_DARK:= 0.15
const LED_LIT:= 3.0
const BULB_DARK:= 0.2
const BULB_LIT:= 5.0


const HEAD_BACK:= 1.42
const HEAD_UP:= 0.43


const FEED_LENGTH:= 1.2


const PORT_REACH:= 0.38


const PORT_BACK:= HEAD_BACK + FEED_LENGTH + PORT_REACH
const PORT_UP:= HEAD_UP


const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06
const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 10
const ARROW_SPEED:= 0.9


const INTAKE_LENGTH:= 1.8
const INTAKE_HEIGHT:= 0.55


const HOPPER_AT:= Vector3(0.0, 1.0592, -0.98)
const HOPPER_SIZE:= Vector3(0.9, 0.65, 0.61)


const HEAP_SCALE_MIN:= 0.34
const HEAP_SCALE_MAX:= 1.0


const VOLT_SWEEP:= 250.0
const VOLT_PARKED:= 34.0


const NEEDLE_AXIS:= Vector3(0.0, 0.0, -1.0)


const NEEDLE_SLEW:= 220.0


const BOIL_SWEEP:= 250.0
const BOIL_PARKED:= -38.0
const BOIL_AXIS:= Vector3(1.0, 0.0, 0.0)


const FIRE_ENERGY:= 3.2
const FIRE_RANGE:= 4.5
const FIRE_COLOUR:= Color(1.0, 0.56, 0.2)


const FIRE_RAMP:= 6.0


const FIRE_FLICKER:= 0.22
const FLAME_SHADER:= "res://assets/firebox_flame.gdshader"


const STEAM_SHADER:= "res://assets/smoke_column.gdshader"

const STEAM_PARAM:= &"volume_gain"


const STEAM_AT:= Vector3(0.0, 1.93, -0.3)


const STEAM_BASE_R:= 0.12
const STEAM_TOP_R:= 0.85
const STEAM_HEIGHT:= 2.8


const STEAM_RAMP:= 0.8

const RUN_LOOP:= "generator"
const RUN_LOOP_DB:= -13.0
const RUN_LOOP_SILENT:= -80.0
const RUN_LOOP_RAMP:= 120.0
const RUN_LOOP_HEIGHT:= 1.1

signal fired()
signal died()

var live: LiveStrandManager


var props: PropManager
var placement_preview:= false


var fuel:= 0.0


var _saved_ash:= PackedInt32Array()

var starved_for:= 0.0


var paid_cost:= -1.0


var port_reach:= PORT_REACH


var power:= 1.0


var demand_kw:= -1.0


var made_kw:= 0.0


var fed_kw:= 0.0


var arriving:= 0.0


var switched_off:= false


var on_network:= true

var _model: Node3D
var _anim: AnimationPlayer
var _intake: Area3D
var _hopper: Area3D
var _belt: BeltPath
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D

var _ghost_from:= Vector3.ZERO
var _ghost_dir:= Vector3.BACK
var _ghost_length:= 0.0
var _flow_phase:= 0.0
var _body: StaticBody3D

var _heap: Node3D
var _heap_rest:= Transform3D()
var _volt: Node3D
var _volt_rest:= Basis()
var _volt_deg:= VOLT_PARKED
var _boil: Node3D
var _boil_rest:= Basis()
var _fire_light: OmniLight3D
var _fire_puff: GPUParticles3D
var _fire_gain:= 0.0
var _fire_phase:= 0.0
var _steam: MeshInstance3D
var _steam_gain:= 0.0

var _led_meshes: Array [MeshInstance3D] = []
var _bulb_meshes: Array [MeshInstance3D] = []
var _burning:= false

var _ports: Array [Node3D] = []


var _stoked:= false


var _fed_kj:= 0.0


var _refused:= false


var _oversize:= false


var _ember:= 0.0

const FEED_SMOOTHING:= 1.0


const ARRIVING_SECONDS:= 15.0

var _loop_voice:= -1
var _loop_gain:= RUN_LOOP_SILENT
var _loop_target:= RUN_LOOP_SILENT

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	_build_collider()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)
	_build_belt()
	_build_intake_area()
	_build_hopper_area()
	_build_instruments()
	_build_instruction_board()
	_build_fire()
	_build_steam()
	add_to_group("hay_generators")
	_apply_lamps()
	_apply_heap()
	_apply_meter(0.0)
	_apply_gauge()


var _fuel_readout: Label3D


var _board_seconds:= -1
var _board_off:= false
var _board_burning:= false


const BOARD_REACH:= 15.0


func _instruction_label(face: Node3D, body: String, at: Vector2,
		size: int, max_width: float) -> Label3D:
	var label:= Label3D.new()
	label.font = UiFont.regular()
	label.font_size = size
	label.pixel_size = 0.001
	label.outline_size = 0
	label.modulate = Color(0.92, 0.9, 0.82)
	label.shaded = false
	label.double_sided = false
	label.no_depth_test = false
	label.position = Vector3(at.x, at.y, 0.0)
	label.text = body
	face.add_child(label)
	_fit_instruction_label(label, max_width)
	return label


func _fit_instruction_label(label: Label3D, max_width: float) -> void:
	var widest:= 1.0
	for line in label.text.split("\n"):
		widest = maxf(widest, label.font.get_string_size(line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x)
	label.pixel_size = minf(0.001, max_width / widest)


func _build_instruction_board() -> void:
	var anchor:= _find("Gen_InstructionFace") as Node3D
	if anchor == null:
		return
	var face:= Node3D.new()
	face.rotation.y = PI / 2.0
	anchor.add_child(face)
	_instruction_label(face, tr("FEED\nHAY"), Vector2(-0.33, 0.115), 32, 0.29)
	_instruction_label(face, tr("GENERATE\nPOWER"), Vector2(0.0, 0.115), 32, 0.29)
	_instruction_label(face, tr("RUN\nMACHINES"), Vector2(0.33, 0.115), 32, 0.29)
	_instruction_label(face, tr("More machines running =\nhay burns faster"),
		Vector2(0.0, -0.028), 30, 0.9)
	_fuel_readout = _instruction_label(face, "", Vector2(0.0, -0.17), 34, 0.9)
	_update_instruction_board()


func _update_instruction_board() -> void:
	if _fuel_readout == null:
		return
	var seconds:= ceili(fuel_seconds())
	var burning:= fuel > 0.0
	if seconds == _board_seconds and switched_off == _board_off and burning == _board_burning:
		return
	if not _board_in_reach():
		return
	_board_seconds = seconds
	_board_off = switched_off
	_board_burning = burning
	if switched_off:
		_fuel_readout.text = tr("Switched off")
	elif fuel <= 0.0:
		_fuel_readout.text = tr("Out of fuel: add hay")
	else:
		_fuel_readout.text = tr("Fuel left: %d min %02d sec") % [seconds / 60, seconds % 60]
	_fit_instruction_label(_fuel_readout, 0.9)


func _board_in_reach() -> bool:
	if not is_inside_tree():
		return true
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return true
	return cam.global_position.distance_squared_to(_fuel_readout.global_position) <= BOARD_REACH * BOARD_REACH


func _build_model() -> void:
	var packed: PackedScene = load(_model_path())
	if packed == null:
		push_error("HayGenerator: cannot load %s" % _model_path())
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("HayGenerator: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	_led_meshes.clear()
	_bulb_meshes.clear()
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if src.get_meta("immutable_palette", false):
				preload("res://assets/models/machine_palette.gd").validate_import(src, spec)
				continue
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return _make_surface(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key == MAT_LED and not _led_meshes.has(mesh):
				_led_meshes.append(mesh)
			elif key == MAT_BULB and not _bulb_meshes.has(mesh):
				_bulb_meshes.append(mesh)
	if not missed.is_empty():
		push_warning("HayGenerator: no table entry for %s" % ", ".join(missed.keys()))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= HayCompressor.make_material(key, spec, shader)


	var flat: Dictionary = spec.get("flats", { }).get(key, { })
	if flat.get("linear_color", false) and made is StandardMaterial3D:
		var finish: StandardMaterial3D = made
		finish.albedo_color = finish.albedo_color.linear_to_srgb()
	if key == MAT_LED or key == MAT_BULB:
		made = HayCompressor.lamp_material(made)
	return made


static func spec_table() -> Dictionary:
	if not _spec_cache.is_empty():
		return _spec_cache


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_spec_cache = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_spec_cache = parsed
	return _spec_cache


func _build_animation() -> void:
	_anim = _find("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		return
	var clip:= _clip_name()
	if clip == "":
		return
	var a:= _anim.get_animation(clip)
	if a == null:
		return
	a.loop_mode = Animation.LOOP_LINEAR
	for i in range(a.get_track_count() - 1, -1, -1):
		if str(a.track_get_path(i)).contains(N_VOLT):
			a.remove_track(i)


func _model_path() -> String:
	return MODEL


func _clip_name() -> String:
	if _anim == null:
		return ""
	if _anim.has_animation(CLIP):
		return CLIP
	for name in _anim.get_animation_list():
		if name.ends_with(CLIP):
			return name
	return ""


func _build_collider() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	_body.collision_mask = 0
	add_child(_body)
	for spec: Array in [

			[Vector3(1.6, 0.17, 3.73), Vector3(0.0, 0.115, 0.415)],

			[Vector3(1.0, 0.52, 0.66), Vector3(0.0, 0.48, -0.95)],

			[Vector3(0.935, 0.2, 0.646), Vector3(0.0, 0.9604, -0.98)],

			[Vector3(1.055, 0.045, 0.41), Vector3(0.0, 0.755, -1.445)],
			[Vector3(0.06, 0.395, 0.37), Vector3(0.5, 0.5675, -1.455)],
			[Vector3(0.06, 0.395, 0.37), Vector3(-0.5, 0.5675, -1.455)],

			[Vector3(0.76, 1.0, 0.62), Vector3(0.0, 0.7, -0.29)],

			[Vector3(1.3, 1.0, 1.3), Vector3(0.0, 0.6, 1.3)],

			[Vector3(0.8, 0.92, 0.34), Vector3(0.0, 0.96, 2.11)]]:
		var box:= BoxShape3D.new()
		box.size = spec [0]
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.position = spec [1]
		_body.add_child(cs)


	var stack:= CylinderShape3D.new()
	stack.radius = 0.15
	stack.height = 0.8
	var scs:= CollisionShape3D.new()
	scs.shape = stack
	scs.position = Vector3(0.0, 1.52, -0.3)
	_body.add_child(scs)


func _build_belt() -> void:


	var belt:= Conveyor.new()
	belt.name = "IntakeDeck"
	var run: PackedVector3Array = belt_runs() [0]
	belt.setup(run [0], run [1])
	_belt = belt
	add_child(belt)


	belt.hold_records(_eats_kind)


func _build_ghost_belt() -> void:
	_solve_ghost_run()

	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


	var fmm:= MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = ConveyorKit.flow_arrow_mesh()
	fmm.instance_count = ARROW_CAPACITY
	fmm.visible_instance_count = 0
	_ghost_flow = MultiMeshInstance3D.new()
	_ghost_flow.name = "GhostFlow"
	_ghost_flow.multimesh = fmm
	_ghost_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_flow.material_override = ConveyorKit.flow_material()
	add_child(_ghost_flow)
	_shape_flow()


func _process(delta: float) -> void:
	if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
		return
	_flow_phase += delta * ARROW_SPEED
	_shape_flow()


	var run: PackedVector3Array = belt_runs() [0]
	var basis:= BeltPath.run_basis(run [0], run [1])
	_ghost_belt.show_belt(belt_runs(), 0.0, support_xforms(), [],
		[[false, run [0], basis.rotated(basis.y, PI)], [true, run [1], basis]])


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([intake_port(), belt_head()])]


func support_xforms() -> Array:
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	if not is_inside_tree():
		return [legs, feet]
	var run: PackedVector3Array = belt_runs() [0]
	var a:= run [0]
	var b:= run [1]
	var length:= a.distance_to(b)
	if length < 1e-06:
		return [legs, feet]
	var n:= maxi(1, int(round(length / Cfg.BELT_SUPPORT_SPACING)))
	var stations: Array [float] = []
	for i in n + 1:
		stations.append(length * float(i) / float(n))
	var reject:= Callable()
	if placement_preview:
		reject = _over_own_body
	return Conveyor.trestles(get_world_3d().direct_space_state, a, b, stations, [], reject)


func _over_own_body(top: Vector3, ground: Vector3) -> bool:
	if _body == null:
		return false
	var t:= to_local(top)
	var g:= to_local(ground)
	for child in _body.get_children():
		var cs:= child as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var box:= cs.shape as BoxShape3D
		var half:= box.size * 0.5
		var c:= cs.position
		if absf(t.x - c.x) <= half.x and absf(t.z - c.z) <= half.z and c.y - half.y < t.y and c.y + half.y > g.y:
			return true
	return false


func _solve_ghost_run() -> void:
	var to:= _head_local()
	var from:= to - Vector3(0.0, 0.0, feed_length())
	var span:= to - from
	_ghost_from = from
	_ghost_length = span.length()
	if _ghost_length < 0.01:


		_ghost_dir = Vector3.BACK
		_ghost_length = 1.0
		return
	_ghost_dir = span / _ghost_length


func ghost_run() -> Dictionary:
	if not placement_preview:
		return { }
	return {
		"from": to_global(_ghost_from),
		"to": to_global(_ghost_from + _ghost_dir * _ghost_length),
		"length": _ghost_length,
	}


func _shape_flow() -> void:
	var length:= _ghost_length
	var from:= _ghost_from
	var dir:= _ghost_dir
	var lift:= Vector3.UP * ARROW_LIFT
	var facing:= Basis.looking_at(- dir, Vector3.UP)
	var mm:= _ghost_flow.multimesh
	var n:= clampi(maxi(1, int(round(length / ARROW_PITCH))), 1, ARROW_CAPACITY)
	var pitch:= length / n
	var phase:= fmod(_flow_phase, pitch)
	for i in n:
		var along:= fmod(i * pitch + phase, length)
		mm.set_instance_transform(i, Transform3D(facing,
			from + dir * along + lift))
		var fade:= (clampf(along / ARROW_FADE, 0.0, 1.0)
			* clampf((length - along) / ARROW_FADE, 0.0, 1.0))
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, fade))
	mm.visible_instance_count = n


func _build_intake_area() -> void:
	_intake = Area3D.new()
	_intake.name = "IntakeMouth"
	_intake.collision_layer = 0

	_intake.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_intake.monitorable = false
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
		INTAKE_HEIGHT, intake_length())
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
	_intake.add_child(cs)
	add_child(_intake)


	_intake.position = to_local(port_in()) + Vector3(0.0, 0.0,
		(feed_length() - (INTAKE_LENGTH - FEED_LENGTH)) * 0.5)


	_intake.position.y = to_local(port_in()).y


func _build_hopper_area() -> void:
	_hopper = Area3D.new()
	_hopper.name = "HopperMouth"
	_hopper.collision_layer = 0
	_hopper.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_hopper.monitorable = false
	var box:= BoxShape3D.new()
	box.size = _hopper_size()
	var cs:= CollisionShape3D.new()
	cs.shape = box
	_hopper.add_child(cs)
	add_child(_hopper)


	_hopper.position = _hopper_at() + Vector3(0.0, _hopper_size().y * 0.25, 0.0)


func _hopper_at() -> Vector3:
	return HOPPER_AT


func _hopper_size() -> Vector3:
	return HOPPER_SIZE


func _build_instruments() -> void:
	_volt = _find(N_VOLT) as Node3D
	if _volt == null:
		push_warning("HayGenerator: %s has no %s; the voltmeter will not move"
			% [MODEL, N_VOLT])
	else:
		_volt_rest = _volt.transform.basis


	_boil = _find(N_BOIL) as Node3D
	if _boil != null:
		_boil_rest = _boil.transform.basis


	_heap = _find(N_HEAP) as Node3D
	if _heap == null:
		push_warning("HayGenerator: %s has no %s; the hopper will look empty"
			% [MODEL, N_HEAP])
	else:


		_heap_rest = _heap.transform


func _fire_local() -> Vector3:
	return _marker_local(N_FIRE, Vector3(0.44, 0.72, -0.3))


func _build_fire() -> void:
	var at:= _fire_local()

	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.light_color = FIRE_COLOUR
	_fire_light.light_energy = 0.0
	_fire_light.omni_range = FIRE_RANGE
	_fire_light.shadow_enabled = false
	_fire_light.position = at
	_fire_light.visible = false
	add_child(_fire_light)

	var pm:= ParticleProcessMaterial.new()


	pm.direction = Vector3(0.35, 1.0, 0.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0.0, 0.55, 0.0)
	pm.damping_min = 1.2
	pm.damping_max = 2.4
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	pm.scale_curve = _flame_curve()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.02, 0.09, 0.11)
	pm.color = FIRE_COLOUR


	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0


	var quad:= QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = _flame_material()

	_fire_puff = GPUParticles3D.new()
	_fire_puff.name = "FirePuff"
	_fire_puff.amount = 18
	_fire_puff.lifetime = 0.75
	_fire_puff.emitting = false
	_fire_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire_puff.process_material = pm
	_fire_puff.draw_pass_1 = quad
	_fire_puff.position = at
	add_child(_fire_puff)


func _build_steam() -> void:
	if _steam_mesh == null:
		var cone:= CylinderMesh.new()
		cone.top_radius = STEAM_TOP_R
		cone.bottom_radius = STEAM_BASE_R
		cone.height = STEAM_HEIGHT
		cone.radial_segments = 24
		cone.rings = 10
		cone.cap_top = false
		cone.cap_bottom = false
		_steam_mesh = cone

	_steam = MeshInstance3D.new()
	_steam.name = "Steam"
	_steam.mesh = _steam_mesh


	_steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_steam.material_override = HayCompressor.shared_material(MODEL, "steam",
		func() -> Material: return _steam_material())

	HayCompressor.drive_instance(_steam, STEAM_PARAM, 0.0)
	_steam.visible = false
	add_child(_steam)

	_steam.position = STEAM_AT + Vector3(0.0, STEAM_HEIGHT * 0.5, 0.0)


static var _steam_mesh: CylinderMesh


static func _steam_material() -> Material:
	var mat:= ShaderMaterial.new()
	mat.shader = load(STEAM_SHADER)


	mat.set_shader_parameter("scale", 3.2)

	mat.set_shader_parameter("tex_speed", Vector3(0.0, -2.4, 0.3))

	mat.set_shader_parameter("smoke_volume", 1.0)
	mat.set_shader_parameter("smoke_aperture", 0.14)
	mat.set_shader_parameter("edge_falloff", 1.3)
	mat.set_shader_parameter("smoke_softness", 0.28)
	mat.set_shader_parameter("noise_contrast", 2.0)
	mat.set_shader_parameter("warp", 1.3)
	mat.set_shader_parameter("sway", 0.45)


	mat.set_shader_parameter("smoke_color", Color(0.8, 0.81, 0.82, 0.85))


	mat.set_shader_parameter("top_fade", 0.5)
	mat.set_shader_parameter("base_fade", 0.12)
	return mat


static func _flame_curve() -> CurveTexture:
	var c:= Curve.new()
	c.add_point(Vector2(0.0, 0.55))
	c.add_point(Vector2(0.22, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t:= CurveTexture.new()
	t.curve = c
	return t


func _flame_material() -> ShaderMaterial:
	var m:= ShaderMaterial.new()
	m.shader = load(FLAME_SHADER)
	return m


func port_in() -> Vector3:
	return to_global(_head_local() - Vector3(0.0, 0.0, feed_length()))


func feed_length() -> float:
	return FEED_LENGTH + port_reach


func intake_length() -> float:
	return feed_length() + INTAKE_LENGTH - FEED_LENGTH


func intake_port() -> Vector3:
	return port_in()


func belt_head() -> Vector3:
	return to_global(_head_local())


func _head_local() -> Vector3:
	return _marker_local(N_BELT_HEAD, Vector3(0.0, HEAD_UP, - HEAD_BACK))


func deck() -> BeltPath:
	return _belt


func forward() -> Vector3:
	var d:= global_position - port_in()
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
	return to_global(Vector3(0.0, 0.9, 2.95))


func hopper_position() -> Vector3:
	return to_global(_hopper_at())


static func broadside_forward(look: Vector3) -> Vector3:
	var flat:= Vector3(look.x, 0.0, look.z)
	if flat.length_squared() < 1e-06:
		return Vector3.BACK
	flat = flat.normalized()
	return Vector3(flat.z, 0.0, - flat.x)


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func capacity() -> float:
	return Tech.generator_firebox_kj()


func is_full() -> bool:
	return _stoked


func straw_room() -> int:
	if _stoked:
		return 0
	var worth:= loose_worth()
	return maxi(0, int(floor((capacity() - fuel) / maxf(worth, 0.001))))


func is_burning() -> bool:
	return _burning


func fill() -> float:
	return clampf(fuel / maxf(capacity(), 0.001), 0.0, 1.0)


func output_kw() -> float:
	return made_kw


func rated_output_kw() -> float:
	return Tech.generator_output()


func kj_per_strand() -> float:
	return Cfg.GENERATOR_KJ_PER_STRAND


func burning_strands() -> float:
	return made_kw / kj_per_strand()


func box_strands() -> int:
	return int(round(fuel / kj_per_strand()))


func box_capacity_strands() -> int:
	return int(round(capacity() / kj_per_strand()))


func cap_kw() -> float:
	return 0.0 if switched_off else rated_output_kw()


func wanted_kw() -> float:
	if switched_off:
		return 0.0
	var cap:= rated_output_kw()
	if demand_kw < 0.0:
		return cap
	return clampf(demand_kw, Cfg.GENERATOR_PILOT_KW, cap)


func deliverable_kw() -> float:
	if switched_off:
		return 0.0
	var cap:= rated_output_kw()
	if fuel > 0.0:
		return cap
	return clampf(maxf(fed_kw, made_kw), 0.0, cap)


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_build_ports()
	return _ports


func _build_ports() -> void:
	_ports.clear()
	var node:= _find(_wire_port_name()) as Node3D
	if node == null:
		var stand_in:= Node3D.new()
		stand_in.name = _wire_port_name()
		stand_in.position = _wire_port_fallback()
		add_child(stand_in)
		node = stand_in
	_ports.append(node)


func _wire_port_name() -> String:
	return N_WIRE_PORT


func _wire_port_fallback() -> Vector3:
	return WIRE_PORT_FALLBACK


func set_power(f: float) -> void:
	power = clampf(f, 0.0, 1.0)


func set_load(kw: float) -> void:
	demand_kw = kw


func set_on_network(on: bool) -> void:
	on_network = on


var power_blocked:= false


func set_power_blocked(b: bool) -> void:
	power_blocked = b


func set_switched_off(off: bool) -> void:
	switched_off = off


func is_switched_off() -> bool:
	return switched_off


func fuel_seconds() -> float:
	var kw:= maxf(made_kw, Cfg.GENERATOR_PILOT_KW)
	return 0.0 if fuel <= 0.0 else fuel / kw


func _lose_the_needle(index: int) -> void:
	if index < 0:
		return
	GameState.lose_needle(index, GameState.type_of(index), 0.0,
		GameState.NeedleLoss.BURNED)


func adopt_saved_ash(indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	_saved_ash = indices


func _drain_saved_ash() -> void:
	if _saved_ash.is_empty():
		return
	if GameState.needle_lost.get_connections().is_empty():
		return
	var held:= _saved_ash


	_saved_ash = PackedInt32Array()
	for index in held:
		_lose_the_needle(index)


static func burn_value(body: Node) -> float:
	var per:= Cfg.GENERATOR_KJ_PER_STRAND
	if body is EcoBrick:
		return float((body as EcoBrick).hay_strands()) * per * Cfg.GENERATOR_BURN_BRICK
	if body is FeedDisc:
		return float((body as FeedDisc).hay_strands()) * per * Cfg.GENERATOR_BURN_DISC
	if body is FoiledBale:
		return float((body as FoiledBale).hay_strands()) * per * Cfg.GENERATOR_BURN_FOIL
	if body is HayBale:
		return float((body as HayBale).hay_strands()) * per * Cfg.GENERATOR_BURN_BALE
	if body is HayWad:
		return float((body as HayWad).hay_strands()) * per * Cfg.GENERATOR_BURN_LOOSE
	return 0.0


static func burn_value_of(kind: int, strands: int) -> float:
	var per:= Cfg.GENERATOR_KJ_PER_STRAND
	match kind:
		BeltRun.Kind.BRICK:
			return float(strands) * per * Cfg.GENERATOR_BURN_BRICK
		BeltRun.Kind.DISC:
			return float(strands) * per * Cfg.GENERATOR_BURN_DISC
		BeltRun.Kind.FOILED_BALE:
			return float(strands) * per * Cfg.GENERATOR_BURN_FOIL
		BeltRun.Kind.BALE:
			return float(strands) * per * Cfg.GENERATOR_BURN_BALE
		BeltRun.Kind.WAD:
			return float(strands) * per * Cfg.GENERATOR_BURN_LOOSE
	return 0.0


func worth_of_body(body: Node) -> float:
	return burn_value(body)


func worth_of(kind: int, strands: int) -> float:
	return burn_value_of(kind, strands)


func loose_worth() -> float:
	return Cfg.GENERATOR_KJ_PER_STRAND * Cfg.GENERATOR_BURN_LOOSE


func _refuse_fuel(_rb: RigidBody3D) -> void:
	pass


func _eats_kind(kind: int, strands: int) -> bool:
	if strands < 0:
		return worth_of(kind, 1) > 0.0
	var worth:= worth_of(kind, strands)
	if worth <= 0.0:
		return false
	if is_full() or switched_off:
		if not switched_off and worth > capacity() + 0.001:
			_oversize = true
		return false
	if fuel + worth > capacity() + 0.001:
		if worth <= capacity() or fuel > 0.0:
			_refused = true
			_oversize = _oversize or worth > capacity()
			return false
	return true


func alert_reason() -> String:
	if placement_preview:
		return ""

	if switched_off:
		return ""


	if _oversize:
		return tr("TOO BIG FOR THE FIREBOX  ·  it goes in once the fire has burnt down")


	if not on_network and (fuel > 0.0 or _burning):
		if power_blocked:
			return Cfg.tr("NO CABLE REACHES THIS  ·  a pole is near, but something is in the way")
		return tr("NO POLE  ·  the power has nowhere to go, put a pole near it")


	if fuel > 0.0 or made_kw > 0.0:
		return ""
	if starved_for >= Cfg.MACHINE_STARVED_AFTER:
		return _empty_reason()
	return ""


func _empty_reason() -> String:
	return tr("FIREBOX EMPTY  ·  nothing is reaching the hopper")


func alert_icon() -> String:
	return "power" if not on_network and (fuel > 0.0 or _burning) else ""


func factory_tick(delta: float) -> void:


	_drain_saved_ash()
	var held:= fuel
	_fed_kj = 0.0
	_refused = false
	_oversize = false
	_intake_fuel()


	starved_for = 0.0 if fuel > held else starved_for + delta


	if delta > 0.0:
		fed_kw = lerpf(fed_kw, _fed_kj / delta, minf(1.0, delta * FEED_SMOOTHING))
		arriving = lerpf(arriving, _fed_kj / kj_per_strand() / delta,
			minf(1.0, delta / ARRIVING_SECONDS))
	_latch_full()
	_tick_burn(delta)
	_update_instruction_board()
	_sync_backpressure()
	_tick_fire(delta)
	_tick_steam(delta)
	_tick_loop(delta)


func is_waiting() -> bool:
	if fuel > 0.0 or fed_kw > 0.001 or not _saved_ash.is_empty() or (_intake != null and _intake.has_overlapping_bodies()) or (_hopper != null and _hopper.has_overlapping_bodies()):
		_idle_memo.clear()
		return false
	var key:= [_burning, _stoked, _ember, _fire_gain, _steam_gain, _volt_deg,
		_loop_voice, _loop_gain, _loop_target, made_kw, demand_kw, power,
		switched_off, on_network, _refused, _oversize]
	return FactoryClock.idle_router([_belt], key, _idle_memo)


var _idle_memo: Array = []


func _intake_fuel() -> void:
	if live == null:
		return


	if _belt != null:
		var rec:= _belt.take_record(_eats_kind, 0.0, _belt.path_length())
		if not rec.is_empty():
			var worth:= worth_of(int(rec ["kind"]), int(rec ["strands"]))
			if int(rec ["needle"]) >= 0:
				_lose_the_needle(int(rec ["needle"]))
			fuel = minf(fuel + worth, capacity())
			_fed_kj += worth
			Audio.play_3d("machine_thud", _belt.global_position, -9.0)
	for mouth: Area3D in [_intake, _hopper]:
		if mouth == null:
			continue
		for body in mouth.get_overlapping_bodies():
			_swallow(body as RigidBody3D, mouth)


func _note_oversize(rb: RigidBody3D) -> void:
	var carryable:= rb as Carryable
	if carryable == null or carryable.is_held():
		return
	if worth_of_body(carryable) > capacity() + 0.001:
		_oversize = true


func _swallow(rb: RigidBody3D, mouth: Area3D) -> void:
	if rb == null or not rb.is_inside_tree():
		return

	if is_full() or switched_off:


		if not switched_off:
			_note_oversize(rb)
		return
	var carryable:= rb as Carryable
	if carryable != null:


		if carryable.is_held():
			return


		var worth:= worth_of_body(carryable)
		if worth <= 0.0:
			if burn_value(carryable) > 0.0:
				_refuse_fuel(carryable)
			return


		if carryable.freeze and not BeltPath.is_rider(carryable):
			return


		if fuel + worth > capacity() + 0.001:
			if worth <= capacity() or fuel > 0.0:
				_refused = true
				_oversize = _oversize or worth > capacity()
				return
		BeltPath.release(carryable)


		if carryable.needle_index >= 0:
			_lose_the_needle(carryable.needle_index)
		fuel = minf(fuel + worth, capacity())
		_fed_kj += worth


		Audio.play_3d("machine_thud", mouth.global_position, -9.0)
		if props != null:
			props.remove(carryable)
		else:
			carryable.queue_free()
		return
	if not (rb.collision_layer & Cfg.L_STRAND):
		return
	if rb.freeze and not BeltPath.is_rider(rb):
		return


	if rb.has_meta("needle_index"):
		BeltPath.release(rb)


		var index:= int(rb.get_meta("needle_index", -1))
		if live.consume_needle(rb):
			_lose_the_needle(index)
		return


	var worth:= loose_worth()
	if worth <= 0.0:
		_refuse_fuel(rb)
		return
	if fuel + worth > capacity() + 0.001:
		_refused = true
		return


	BeltPath.release(rb)
	if live.consume(rb):
		fuel = minf(fuel + worth, capacity())
		_fed_kj += worth


		Audio.play_3d("machine_feed", mouth.global_position, -13.0)


func _latch_full() -> void:
	if _stoked:
		if fuel <= capacity() * Cfg.GENERATOR_REFILL_AT:
			_stoked = false
	elif fuel >= capacity():
		_stoked = true


func _tick_burn(delta: float) -> void:
	var was:= _burning
	var burnt:= 0.0
	if delta > 0.0 and fuel > 0.0:
		burnt = minf(fuel, wanted_kw() * delta)
		fuel = maxf(fuel - burnt, 0.0)
	made_kw = burnt / delta if delta > 0.0 else 0.0


	_ember = Cfg.GENERATOR_EMBER_SECONDS if burnt > 0.0 or fuel > 0.0 else maxf(_ember - delta, 0.0)
	_burning = not switched_off and (fuel > 0.0 or _ember > 0.0)
	if _burning and not was:
		if _anim != null and _clip_name() != "":
			_anim.play(_clip_name())
		if _loop_voice < 0:


			_loop_voice = Audio.loop_acquire(RUN_LOOP)
			_loop_gain = RUN_LOOP_SILENT
		_loop_target = RUN_LOOP_DB
		Audio.play_3d("machine_clunk", _emitter(), -11.0)
		fired.emit()
	elif was and not _burning:
		if _anim != null:
			_anim.pause()
		_loop_target = RUN_LOOP_SILENT
		Audio.play_3d("machine_vent", _emitter(), -12.0)
		died.emit()
	if was != _burning:
		_apply_lamps()
	_apply_heap()
	_apply_meter(delta)
	_apply_gauge()


func _sync_backpressure() -> void:
	if _belt == null:
		return


	var full:= is_full() or switched_off or _refused
	if _belt.is_blocked() != full:
		_belt.set_blocked(full)
	_belt.set_outlet_held(full)


func _apply_lamps() -> void:
	HayCompressor.light_lamps(_led_meshes, LED_LIT if _burning else LED_DARK)
	HayCompressor.light_lamps(_bulb_meshes, BULB_LIT if _burning else BULB_DARK)


func led_energy() -> float:
	return HayCompressor.lamp_energy(_led_meshes)


func bulb_energy() -> float:
	return HayCompressor.lamp_energy(_bulb_meshes)


func _apply_heap() -> void:
	if _heap == null:
		return
	var showing:= fuel > 0.0
	_heap.visible = showing
	if not showing:
		return


	var f:= fill()
	var s:= lerpf(HEAP_SCALE_MIN, HEAP_SCALE_MAX, f)
	var w:= lerpf(0.78, 1.0, f)
	_heap.transform = Transform3D(
		_heap_rest.basis.scaled(Vector3(w, s, w)), _heap_rest.origin)


func _apply_meter(delta: float) -> void:
	if _volt == null:
		return
	var reading:= power if _burning else 0.0
	var target:= lerpf(- VOLT_SWEEP * 0.5, VOLT_SWEEP * 0.5,
		clampf(reading, 0.0, 1.0))
	_volt_deg = (target if delta <= 0.0
		else move_toward(_volt_deg, target, NEEDLE_SLEW * delta))
	var t:= _volt.transform
	t.basis = _volt_rest * Basis(NEEDLE_AXIS, deg_to_rad(_volt_deg - VOLT_PARKED))
	_volt.transform = t


func _apply_gauge() -> void:
	if _boil == null:
		return
	var deg:= lerpf(- BOIL_SWEEP * 0.5, BOIL_SWEEP * 0.5, fill())
	var t:= _boil.transform
	t.basis = _boil_rest * Basis(BOIL_AXIS, deg_to_rad(deg - BOIL_PARKED))
	_boil.transform = t


func _tick_fire(delta: float) -> void:
	if _fire_light == null:
		return
	_fire_gain = move_toward(_fire_gain, 1.0 if _burning else 0.0, FIRE_RAMP * delta)
	var alight:= _fire_gain > 0.001
	_fire_light.visible = alight
	if _fire_puff != null and _fire_puff.emitting != _burning:
		_fire_puff.emitting = _burning
	if not alight:
		return
	_fire_phase += delta


	var flicker:= 1.0 + FIRE_FLICKER * (
		sin(_fire_phase * 11.3) * 0.6 + sin(_fire_phase * 4.7) * 0.4)
	_fire_light.light_energy = FIRE_ENERGY * _fire_gain * flicker


func _tick_steam(delta: float) -> void:
	if _steam == null:
		return
	var was:= _steam_gain
	_steam_gain = move_toward(_steam_gain, 1.0 if _burning else 0.0, STEAM_RAMP * delta)
	_steam.visible = _steam_gain > 0.001
	if _steam_gain != was:
		HayCompressor.drive_instance(_steam, STEAM_PARAM, _steam_gain)


func _emitter() -> Vector3:
	return global_position + Vector3(0, RUN_LOOP_HEIGHT, 0)


func _tick_loop(delta: float) -> void:
	if _loop_voice < 0:
		return
	_loop_gain = move_toward(_loop_gain, _loop_target, RUN_LOOP_RAMP * delta)
	if _loop_target <= RUN_LOOP_SILENT and _loop_gain <= RUN_LOOP_SILENT + 0.5:
		_release_loop()
		return
	Audio.loop_update(_loop_voice, _emitter(), _loop_gain)


func _release_loop() -> void:
	if _loop_voice < 0:
		return
	Audio.loop_release(_loop_voice)
	_loop_voice = -1
	_loop_gain = RUN_LOOP_SILENT
	_loop_target = RUN_LOOP_SILENT


func _exit_tree() -> void:
	_release_loop()


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return list_price()


func list_price() -> float:
	return Cfg.GENERATOR_COST


func to_dict() -> Dictionary:
	return {
		"type": "hay_generator",
		"position": global_position,
		"yaw": global_rotation.y,

		"paid": build_cost(),


		"fuel": fuel,


		"off": switched_off,


		"port_reach": port_reach,
	}
