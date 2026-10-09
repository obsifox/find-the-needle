class_name WaterSplitter
extends Node3D


const MODEL:= "res://assets/models/compiled/water_splitter.scn"


const SPEC:= "res://assets/models/water_splitter_materials.json"


const N_BODY:= "Water_Splitter"
const BODY_SURFACES:= 4


const N_IN:= "Marker_In"
const N_OUT_L:= "Marker_OutL"
const N_OUT_R:= "Marker_OutR"


const PORT_FALLBACK:= {
	N_IN: Vector3(0.0, 0.0, -0.58),
	N_OUT_L: Vector3(-0.410122, 0.0, 0.410122),
	N_OUT_R: Vector3(0.410122, 0.0, 0.410122),
}


static var _spec_cache: Dictionary = { }


static var _dressed: ArrayMesh


var placement_preview:= false


var paid_cost:= -1.0

var _model: Node3D
var _ports: Array [Node3D] = []


static func cost_for() -> float:
	return Cfg.PIPE_SPLITTER_COST * Tech.build_cost_scale()


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


	paid_cost = cost_for()


func _ready() -> void:
	_build_model()
	_dress()
	if placement_preview:
		set_preview_valid(true)
	else:
		add_to_group("water_splitters")


	set_process(false)
	set_physics_process(false)


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("WaterSplitter: cannot load %s" % MODEL)
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


func body_rids() -> Array [RID]:
	var out: Array [RID] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "StaticBody3D", true, false):
		out.append((n as StaticBody3D).get_rid())
	return out


func _dress() -> void:
	var body:= _find(N_BODY) as MeshInstance3D
	var mesh: ArrayMesh = null
	if body != null:
		mesh = body.mesh as ArrayMesh
	if mesh == null:
		push_error("WaterSplitter: %s has no MeshInstance3D '%s'" % [MODEL, N_BODY])
		return
	if mesh == _dressed:
		return
	var n:= mesh.get_surface_count()
	if n != BODY_SURFACES:
		push_error("WaterSplitter: expected %d surfaces, got %d. The materials "
			% [BODY_SURFACES, n]
			+ "in assets/blender/water_splitter.blend no longer split it")
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("WaterSplitter: no material table at %s, it will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	for i in n:
		var old:= mesh.surface_get_material(i)
		var key:= old.resource_name if old != null else ""
		var built:= HayCompressor.make_material(key, spec, shader)
		if built == null:
			push_warning("WaterSplitter: no table entry for '%s', leaving it as imported" % key)
			continue
		mesh.surface_set_material(i, built)
	_dressed = mesh


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


func water_ports() -> Array [Node3D]:
	if _ports.is_empty():
		for id: String in [N_IN, N_OUT_L, N_OUT_R]:
			var node:= _find(id) as Node3D
			if node == null:
				var stand_in:= Node3D.new()
				stand_in.name = id
				stand_in.position = PORT_FALLBACK [id]
				add_child(stand_in)
				node = stand_in
			_ports.append(node)
	return _ports


func port_in() -> Vector3:
	return _port_at(0)


func port_left() -> Vector3:
	return _port_at(1)


func port_right() -> Vector3:
	return _port_at(2)


func ports() -> Array [Vector3]:
	return [port_in(), port_left(), port_right()]


func _port_at(i: int) -> Vector3:
	var list:= water_ports()
	return global_position if i >= list.size() else list [i].global_position


func water_port_bearing(port: Node3D) -> Vector3:
	var out:= port.global_position - global_position
	out.y = 0.0
	return out.normalized() if out.length_squared() > 1e-08 else Vector3.ZERO


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return cost_for()


func to_dict() -> Dictionary:
	return {
		"type": "water_splitter",
		"position": global_position,
		"yaw": global_rotation.y,


		"paid": build_cost(),
	}
