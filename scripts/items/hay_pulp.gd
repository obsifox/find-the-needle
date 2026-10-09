class_name HayPulp
extends Carryable


const MODEL:= "res://assets/models/compiled/hay_pulp.scn"


const MESH_NODE:= "Pulp"
const WATER_NODE:= "Pulp_Water"
const SPEC:= "res://assets/models/hay_pulp_materials.json"

static var _shared_mesh: Mesh = null
static var _shared_water: Mesh = null
static var _surface_names: PackedStringArray = PackedStringArray()
static var _water_names: PackedStringArray = PackedStringArray()
static var _looked:= false
static var _spec_cache: Dictionary = { }


var strands:= Cfg.PULPER_BATCH_STRANDS


func _ready() -> void:
	super ()
	mass = Cfg.PULPER_SLAB_MASS


	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0
	angular_damp = 5.0


func impact_sfx() -> String:
	return "bale_land"


func _build_model() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		push_error("HayPulp: %s has no %s" % [MODEL, MESH_NODE])
		return
	var root:= Node3D.new()
	root.name = "Slab"
	var body:= MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	body.layers = HAY_LAYER
	_skin(body, mesh, _surface_names)
	root.add_child(body)
	var built: Array [MeshInstance3D] = [body]


	var water:= shared_water()
	if water != null:
		var film:= MeshInstance3D.new()
		film.name = "Liquor"
		film.mesh = water
		film.layers = HAY_LAYER
		_skin(film, water, _water_names)
		root.add_child(film)
		built.append(film)
	add_child(root)


	_model = root
	_meshes.assign(built)


static func _skin(into: MeshInstance3D, mesh: Mesh, names: PackedStringArray) -> void:
	if spec_table().is_empty():
		return
	for i in mesh.get_surface_count():
		var key:= "" if i >= names.size() else names [i]
		if key.is_empty():
			continue
		var mat:= _material(key)
		if mat != null:
			into.set_surface_override_material(i, mat)


static func _material(key: String) -> Material:
	var maker:= func() -> Material:
		return HayCompressor.make_material(key, spec_table(),
			load(HayCompressor.SHADER))
	return Carryable.shared_material("pulp/" + key, maker)


static func warm_up() -> void:
	_look_up()
	if spec_table().is_empty():
		return
	for key in _surface_names + _water_names:
		if not key.is_empty():
			_material(key)


static func skin(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	_look_up()
	_skin(mi, mi.mesh, _surface_names)


func _build_shapes() -> void:
	var size:= Cfg.PULPER_SLAB_SIZE
	_shape_box(size, Vector3(0.0, size.y * 0.5, 0.0))


static func shared_mesh() -> Mesh:
	_look_up()
	return _shared_mesh


static func shared_water() -> Mesh:
	_look_up()
	return _shared_water


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


static func _look_up() -> void:
	if _looked:
		return
	_looked = true
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayPulp: cannot load %s" % MODEL)
		return
	var scene: Node3D = packed.instantiate()
	var body:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
	if body != null:
		_shared_mesh = body.mesh
		_surface_names = _names_of(body)
	var water:= scene.find_child(WATER_NODE, true, false) as MeshInstance3D
	if water != null:
		_shared_water = water.mesh
		_water_names = _names_of(water)


	scene.queue_free()


static func _names_of(node: MeshInstance3D) -> PackedStringArray:
	var out:= PackedStringArray()
	if node.mesh == null:
		return out
	for i in node.mesh.get_surface_count():
		var m:= node.get_active_material(i)
		out.append("" if m == null else m.resource_name)
	return out


func to_state() -> Dictionary:
	return { "strands": strands }


func from_state(state: Dictionary) -> void:
	strands = int(state.get("strands", Cfg.PULPER_BATCH_STRANDS))


func sale_strands() -> float:
	return float(strands) * Tech.pulp_value_ratio()


func hay_strands() -> int:
	return strands


func clearance_size() -> Vector3:
	return Vector3(Cfg.PULPER_SLAB_SIZE.x, Cfg.PULPER_SLAB_SIZE.y,
		Cfg.PULPER_SLAB_CLEAR)


func can_rip() -> bool:
	return true
