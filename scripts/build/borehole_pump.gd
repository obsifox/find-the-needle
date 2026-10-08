class_name BoreholePump
extends Node3D


const MODEL:= "res://assets/models/borehole_pump.glb"


const SPEC:= "res://assets/models/borehole_pump_materials.json"


const N_WIRE_PORT:= "Marker_WirePort"


const WIRE_PORT_FALLBACK:= Vector3(0.52, 1.62, -0.3)


const N_WATER_OUT:= "Marker_WaterOut"
const WATER_OUT_FALLBACK:= Vector3(0.0, 0.436, -2.34)


const N_NEEDLE:= "Pump_Needle"

const N_PANEL:= "Marker_Panel"
const PANEL_FALLBACK:= Vector3(1.03, 0.69, -0.3)

const CLIP:= "Run"


const GAUGE_SWEEP:= 250.0


const NEEDLE_AXIS:= Vector3(1.0, 0.0, 0.0)


const NEEDLE_SLEW:= 220.0


const STROKE_DB:= -8.0


const STROKE_HEIGHT:= 1.1


static var _spec_cache: Dictionary = { }


var placement_preview:= false

var _model: Node3D
var _anim: AnimationPlayer
var _needle: Node3D
var _needle_rest:= Basis()


var _needle_deg:= 0.0
var _ports: Array [Node3D] = []
var _water_ports: Array [Node3D] = []


var _gauge:= 0.5


var _stroke_at:= 0.0


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	_build_instruments()
	if placement_preview:
		set_physics_process(false)
		set_preview_valid(true)
		return


	FactoryClock.join(self)
	set_process(false)
	add_to_group("borehole_pumps")
	_apply_beam_speed()
	_apply_gauge(0.0)


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("BoreholePump: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0

	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("BoreholePump: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return _repaint(key, spec, shader))
			var made: Material = built [key]
			if made != null:
				mesh.set_surface_override_material(i, made)
	if not built.has("M_BP_RefGaugeGlass"):
		push_warning("BoreholePump: %s has no sight glass surface" % MODEL)


static func _repaint(key: String, spec: Dictionary, shader: Shader) -> Material:
	var surfaces: Dictionary = spec.get("surfaces", { })
	var flats: Dictionary = spec.get("flats", { })
	if not surfaces.has(key):
		var row: Dictionary = flats.get(key, { })
		var fres: Array = row.get("fresnel", [])
		if fres.size() < 2:
			return null
	return HayCompressor.make_material(key, spec, shader)


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
		push_warning("BoreholePump: %s has no AnimationPlayer; the beam will not nod" % MODEL)
		return
	var clip:= _clip_name()
	if clip == "":
		push_warning("BoreholePump: %s has no %s clip; the beam will not nod" % [MODEL, CLIP])
		return
	var a:= _anim.get_animation(clip)
	if a == null:
		return
	a.loop_mode = Animation.LOOP_LINEAR
	for i in range(a.get_track_count() - 1, -1, -1):
		if str(a.track_get_path(i)).contains(N_NEEDLE):
			a.remove_track(i)
	if not placement_preview:
		_anim.play(clip)


func _clip_name() -> String:
	if _anim == null:
		return ""
	if _anim.has_animation(CLIP):
		return CLIP
	for name in _anim.get_animation_list():
		if name.ends_with(CLIP):
			return name
	return ""


func clip_seconds() -> float:
	if _anim == null:
		return 0.0
	var clip:= _clip_name()
	if clip == "":
		return 0.0
	var a:= _anim.get_animation(clip)
	return 0.0 if a == null else a.length


func _build_instruments() -> void:
	_needle = _find(N_NEEDLE) as Node3D
	if _needle == null:
		push_warning("BoreholePump: %s has no %s; the pressure dial will not move"
			% [MODEL, N_NEEDLE])
		return


	_needle_rest = _needle.transform.basis


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


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var node:= _find(node_name) as Node3D
	if node == null:
		return fallback
	return to_local(node.global_position) if is_inside_tree() else node.position


var power:= 1.0


var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.BOREHOLE_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 1, [WIRE_PORT_FALLBACK])
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power


	_gauge = line_power
	_apply_beam_speed()


func set_switched_off(off: bool) -> void:
	switched_off = off
	set_power(line_power)


func is_switched_off() -> bool:
	return switched_off


func set_power_line(line: int) -> void:
	power_line = line


func set_power_blocked(b: bool) -> void:
	power_blocked = b


func alert_icon() -> String:
	return "power" if MachinePower.fault(power, power_blocked, power_line) != "" else ""


func alert_reason() -> String:
	if placement_preview:
		return ""

	if switched_off:
		return ""
	return MachinePower.fault(power, power_blocked, power_line)


func water_lps() -> float:
	return 0.0 if switched_off else Tech.borehole_output() * power


func water_ports() -> Array [Node3D]:
	if _water_ports.is_empty():
		var node:= _find(N_WATER_OUT) as Node3D
		if node == null:
			var stand_in:= Node3D.new()
			stand_in.name = N_WATER_OUT
			stand_in.position = WATER_OUT_FALLBACK
			add_child(stand_in)
			node = stand_in
		_water_ports.append(node)
	return _water_ports


func water_port() -> Vector3:
	var ports:= water_ports()
	return global_position if ports.is_empty() else ports [0].global_position


func strokes_per_minute() -> float:
	return Cfg.BOREHOLE_STROKES_PER_MIN * power


func _apply_beam_speed() -> void:
	if _anim == null:
		return
	var seconds:= clip_seconds()
	if seconds <= 0.0:
		return
	_anim.speed_scale = (Cfg.BOREHOLE_STROKES_PER_MIN / 60.0) * power * seconds


func factory_tick(delta: float) -> void:
	_apply_gauge(delta)
	_tick_stroke()


func _emitter() -> Vector3:
	return global_position + Vector3(0, STROKE_HEIGHT, 0)


func _tick_stroke() -> void:
	if _anim == null or placement_preview:
		return
	var at:= _anim.current_animation_position


	if at < _stroke_at:
		Audio.play_3d("pump_stroke", _emitter(), STROKE_DB,
			MachinePower.loop_pitch(power))
	_stroke_at = at


static func needle_angle(f: float) -> float:
	return - GAUGE_SWEEP / 2.0 + GAUGE_SWEEP * clampf(f, 0.0, 1.0)


func _apply_gauge(delta: float) -> void:
	if _needle == null:
		return
	var target:= needle_angle(_gauge)
	_needle_deg = (target if delta <= 0.0
		else move_toward(_needle_deg, target, NEEDLE_SLEW * delta))
	var t:= _needle.transform


	t.basis = _needle_rest * Basis(NEEDLE_AXIS,
		deg_to_rad(_needle_deg - needle_angle(0.5)))
	_needle.transform = t


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, PANEL_FALLBACK))


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


func build_cost() -> float:
	return Cfg.BOREHOLE_COST


func to_dict() -> Dictionary:
	return {
		"type": "borehole_pump",
		"position": global_position,
		"yaw": global_rotation.y,


		"off": switched_off,
	}
