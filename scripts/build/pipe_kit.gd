class_name PipeKit
extends RefCounted


const SOURCE:= "res://assets/blender/water_pipe.blend"


const SPEC:= "res://assets/models/water_pipe_materials.json"
const FLOW_SHADER:= "res://assets/water_flow.gdshader"


const MAT_WATER:= "M_WP_Water"


const MAT_PIPE:= "M_WP_Pipe"


const PIPE_R:= 0.13


const SUPPORT_ATTACH:= 0.175


const GRIP_LO:= 0.116
const GRIP_HI:= 0.456


const CLAMP_HALF:= 0.044

static var _section: ArrayMesh
static var _window: ArrayMesh
static var _water: ArrayMesh
static var _saddle: ArrayMesh
static var _leg: ArrayMesh
static var _foot: ArrayMesh
static var _bend: ArrayMesh
static var _spec_cache: Dictionary = { }


static func section_mesh() -> ArrayMesh:
	_load()
	return _section


static func window_mesh() -> ArrayMesh:
	_load()
	return _window


static func water_mesh() -> ArrayMesh:
	_load()
	return _water


static func bend_mesh() -> ArrayMesh:
	_load()
	return _bend


static func _barrel_only(section: ArrayMesh) -> ArrayMesh:
	if section == null:
		return null
	var out:= ArrayMesh.new()
	for i in section.get_surface_count():
		var m:= section.surface_get_material(i)
		if m == null or m.resource_name != MAT_PIPE:
			continue
		out.add_surface_from_arrays(section.surface_get_primitive_type(i),
			section.surface_get_arrays(i))
		out.surface_set_material(out.get_surface_count() - 1, m)
	if out.get_surface_count() != 1:
		push_error("PipeKit: the section has no '%s' surface to lay a bend from" % MAT_PIPE)
		return section
	return out


static func saddle_mesh() -> ArrayMesh:
	_load()
	return _saddle


static func leg_mesh() -> ArrayMesh:
	_load()
	return _leg


static func foot_mesh() -> ArrayMesh:
	_load()
	return _foot


static func _load() -> void:
	if _section != null:
		return
	var packed: PackedScene = load(SOURCE)
	if packed == null:
		push_error("PipeKit: cannot load %s" % SOURCE)
		return
	var root:= packed.instantiate()
	_section = _mesh_of(root, "Pipe_Section")
	_window = _mesh_of(root, "Pipe_Window")
	_water = _mesh_of(root, "Pipe_Water")
	_saddle = _mesh_of(root, "Pipe_Saddle")
	_leg = _mesh_of(root, "Pipe_Leg")
	_foot = _mesh_of(root, "Pipe_Foot")
	_bend = _barrel_only(_section)
	root.free()


	_dress(_section, 4)
	_dress(_window, 5)
	_dress(_water, 1)
	_dress(_saddle, 2)
	_dress(_leg, 1)
	_dress(_foot, 1)
	if _bend != _section:
		_dress(_bend, 1)


static func _mesh_of(root: Node, node_name: String) -> ArrayMesh:
	var node:= root.find_child(node_name, true, false)
	var mi:= node as MeshInstance3D
	if mi == null:
		push_error("PipeKit: %s has no MeshInstance3D '%s'" % [SOURCE, node_name])
		return null


	return mi.mesh as ArrayMesh


static func _dress(mesh: ArrayMesh, expect: int) -> void:
	if mesh == null:
		return
	var n:= mesh.get_surface_count()
	if n != expect:
		push_error("PipeKit: expected %d surfaces, got %d. The materials in "
			% [expect, n] + "assets/blender/water_pipe.blend no longer split it")
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("PipeKit: no material table at %s, the kit will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	for i in n:
		var old:= mesh.surface_get_material(i)
		var key:= old.resource_name if old != null else ""
		if key == MAT_WATER:


			mesh.surface_set_material(i, make_flow_material())
			continue
		var built:= HayCompressor.make_material(key, spec, shader)
		if built == null:
			push_warning("PipeKit: no table entry for '%s', leaving it as imported" % key)
			continue
		mesh.surface_set_material(i, built)


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


static func make_flow_material() -> ShaderMaterial:
	var m:= ShaderMaterial.new()
	m.shader = load(FLOW_SHADER)
	m.resource_name = MAT_WATER
	var flats: Dictionary = spec_table().get("flats", { })
	var d: Dictionary = flats.get(MAT_WATER, { })
	m.set_shader_parameter("still", _col(d.get("still", [0.14, 0.33, 0.4])))
	m.set_shader_parameter("flowing", _col(d.get("color", [0.34, 0.502, 0.54])))
	m.set_shader_parameter("foam", _col(d.get("foam", [0.64, 0.76, 0.75])))
	m.set_shader_parameter("foam_share", float(d.get("foam_share", 0.4)))
	m.set_shader_parameter("rough", float(d.get("rough", 0.44)))
	m.set_shader_parameter("flow", 0.0)
	return m


static func _col(a: Variant) -> Color:
	var arr: Array = a
	if arr.size() < 3:
		return Color.WHITE
	return Color(float(arr [0]), float(arr [1]), float(arr [2]))
