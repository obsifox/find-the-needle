class_name WorkLamp
extends Node3D


const MODEL:= "res://assets/models/compiled/work_lamp.scn"
const SPEC:= "res://assets/models/work_lamp_materials.json"


const N_LAMPS:= ["Marker_Lamp_L", "Marker_Lamp_R"]


const FALLBACK_LAMPS:= [Vector3(-0.218, 1.947, 0.051),
	Vector3(0.218, 1.947, 0.051)]


const SPILL_AT:= Vector3(0.0, 1.9, -0.05)


const TINT:= Color(0.96, 0.97, 1.0)


const GLASS_MAT:= "M_LampGlass"


const CONSOLE_AT:= Vector3(0.0, 1.1, 0.0)


const GLASS_FLOOR:= 0.3

var placement_preview:= false


var brightness:= Cfg.WORK_LAMP_BRIGHT_DEFAULT

var _model: Node3D
var _lights: Array [Light3D] = []
var _spots: Array [SpotLight3D] = []


var _glass_meshes: Array [MeshInstance3D] = []
var _glass_emit:= 0.0
var _off:= false

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func set_brightness(v: float) -> void:
	brightness = clampf(v, Cfg.WORK_LAMP_BRIGHT_MIN, 1.0)
	_apply_brightness()


func set_switched_off(off: bool) -> void:
	_off = off
	_apply_brightness()


func is_switched_off() -> bool:
	return _off


func lit_metres() -> float:
	if _off:
		return 0.0
	return Cfg.WORK_LAMP_RANGE * sqrt(brightness)


func console_position() -> Vector3:
	return to_global(CONSOLE_AT)


func charge() -> float:
	return Cfg.WORK_LAMP_CHARGE


func _apply_brightness() -> void:
	var gain:= 0.0 if _off else brightness
	for spot in _spots:
		spot.light_energy = Cfg.WORK_LAMP_ENERGY * gain
	for light in _lights:
		if light is OmniLight3D:
			light.light_energy = Cfg.WORK_LAMP_SPILL_ENERGY * gain
	HayCompressor.light_lamps(_glass_meshes, 0.0 if _off
		else _glass_emit * lerpf(GLASS_FLOOR, 1.0, brightness))


func glass_energy() -> float:
	return HayCompressor.lamp_energy(_glass_meshes)


func _ready() -> void:
	_load_model()
	_skin()
	_setup_bodies()
	_build_lights()
	_apply_brightness()
	if placement_preview:
		set_preview_valid(true)
		return
	add_to_group("work_lamps")


func _load_model() -> void:
	var scene: PackedScene = load(MODEL) as PackedScene
	if scene == null:
		push_warning("WorkLamp: no model at %s" % MODEL)
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)


func _build_lights() -> void:
	for at in _head_points():
		var spot:= SpotLight3D.new()
		spot.name = "Head%d" % _lights.size()
		spot.position = at


		spot.rotation.y = PI
		spot.spot_range = Cfg.WORK_LAMP_RANGE
		spot.spot_angle = Cfg.WORK_LAMP_ANGLE


		spot.spot_angle_attenuation = 0.9


		spot.spot_attenuation = Cfg.WORK_LAMP_FALLOFF


		_spots.append(spot)
		_add_light(spot)
	var spill:= OmniLight3D.new()
	spill.name = "Spill"
	spill.position = SPILL_AT
	spill.omni_range = Cfg.WORK_LAMP_SPILL_RANGE
	spill.omni_attenuation = 1.4
	_add_light(spill)


func _add_light(light: Light3D) -> void:
	light.light_color = TINT


	light.shadow_enabled = false


	light.distance_fade_enabled = true
	light.distance_fade_begin = Cfg.WORK_LAMP_CULL - Cfg.WORK_LAMP_FADE
	light.distance_fade_length = Cfg.WORK_LAMP_FADE


	light.visible = not placement_preview
	add_child(light)
	_lights.append(light)


func _head_points() -> Array [Vector3]:
	var out: Array [Vector3] = []
	if _model != null:
		for marker_name: String in N_LAMPS:
			var marker:= _model.find_child(marker_name, true, false) as Node3D
			if marker != null:
				out.append(marker.position)
	if out.size() == N_LAMPS.size():
		return out
	push_warning("WorkLamp: %s missing its lamp markers, using the authored positions"
		% MODEL)
	out.clear()
	for at: Vector3 in FALLBACK_LAMPS:
		out.append(at)
	return out


func _setup_bodies() -> void:
	for node in find_children("*", "StaticBody3D", true, false):
		var body:= node as StaticBody3D
		if body == null:
			continue
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


func build_cost() -> float:
	return Cfg.WORK_LAMP_COST


func to_dict() -> Dictionary:
	return {
		"type": "work_lamp",
		"position": global_position,
		"yaw": global_rotation.y,
		"bright": brightness,
		"off": _off,
	}


func from_dict(d: Dictionary) -> void:


	_off = bool(d.get("off", false))
	set_brightness(float(d.get("bright", Cfg.WORK_LAMP_BRIGHT_DEFAULT)))


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("WorkLamp: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	_glass_meshes.clear()
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
					func() -> Material: return _make_surface(key, spec, shader))


				if key == GLASS_MAT and built [key] is ShaderMaterial:
					_glass_emit = float((built [key] as ShaderMaterial)
						.get_shader_parameter("emission_energy"))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key == GLASS_MAT and not _glass_meshes.has(mesh):
				_glass_meshes.append(mesh)
	if not missed.is_empty():
		push_warning("WorkLamp: no table entry for %s" % ", ".join(missed.keys()))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= HayCompressor.make_material(key, spec, shader)
	return HayCompressor.lamp_material(made) if key == GLASS_MAT else made


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	var stack: Array [Node] = [_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			out.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return out


func spec_table() -> Dictionary:
	if _spec_cache.has(SPEC):
		return _spec_cache [SPEC]
	var table: Dictionary = { }


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		table = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			table = parsed
	_spec_cache [SPEC] = table
	return table
