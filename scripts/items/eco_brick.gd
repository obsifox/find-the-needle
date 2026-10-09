class_name EcoBrick
extends Carryable


const MODEL:= "res://assets/models/compiled/eco_brick.scn"
const MESH_NODE:= "EcoBrick"
const SPEC:= "res://assets/models/eco_brick_materials.json"

static var _shared_mesh: Mesh = null
static var _looked:= false
static var _spec_cache: Dictionary = { }


var strands:= Cfg.PELLETIZER_BRICK_STRANDS


func _ready() -> void:
	super ()
	mass = Cfg.ECO_BRICK_MASS


	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.05
	angular_damp = 2.0


func impact_sfx() -> String:
	return "brick_land"


func _build_model() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		push_error("EcoBrick: %s has no %s" % [MODEL, MESH_NODE])
		return
	var mi:= MeshInstance3D.new()
	mi.name = "Brick"
	mi.mesh = mesh
	skin(mi)
	add_child(mi)


	_model = mi
	_meshes.assign([mi])


func _build_shapes() -> void:
	var size:= Cfg.ECO_BRICK_SIZE
	_shape_box(size, Vector3(0.0, size.y * 0.5, 0.0))


static func skin(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	if spec_table().is_empty():
		return
	for i in mi.mesh.get_surface_count():
		var mat:= _material(_slot_name(mi.mesh, i))
		if mat != null:
			mi.set_surface_override_material(i, mat)


static func _material(key: String) -> Material:
	var maker:= func() -> Material:
		return HayCompressor.make_material(key, spec_table(),
			load(HayCompressor.SHADER))
	return Carryable.shared_material("brick/" + key, maker)


static func warm_up() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		_material(_slot_name(mesh, i))


static func _slot_name(mesh: Mesh, surface: int) -> String:
	var existing:= mesh.surface_get_material(surface)
	if existing != null and existing.resource_name != "":
		return existing.resource_name
	return "M_EB_Brick"


static func shared_mesh() -> Mesh:
	_look_up()
	return _shared_mesh


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
		push_error("EcoBrick: cannot load %s" % MODEL)
		return
	var scene: Node3D = packed.instantiate()
	var node:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
	if node == null:


		for child in scene.find_children("*", "MeshInstance3D", true, false):
			node = child as MeshInstance3D
			break
	if node != null:
		_shared_mesh = node.mesh


	scene.queue_free()


func to_state() -> Dictionary:
	return { "strands": strands }


func from_state(state: Dictionary) -> void:
	strands = int(state.get("strands", Cfg.PELLETIZER_BRICK_STRANDS))


func sale_strands() -> float:
	return float(strands) * Tech.brick_value_ratio()


func hay_strands() -> int:
	return strands


func clearance_size() -> Vector3:
	return Cfg.ECO_BRICK_SIZE


func can_rip() -> bool:
	return true
