class_name HayBale
extends Carryable


const MODEL:= "res://assets/models/compiled/hay_compressor.scn"
const MESH_NODE:= "Compressor_Bale"
const MAT_STRAW:= "M_HC_Straw"
const MAT_TWINE:= "M_HC_Twine"

static var _shared_mesh: Mesh = null
static var _looked:= false


var strands:= Cfg.COMPRESSOR_BALE_STRANDS


func _ready() -> void:
	super ()
	mass = Cfg.COMPRESSOR_BALE_MASS


	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0
	angular_damp = 4.0


func impact_sfx() -> String:
	return "bale_land"


func _build_model() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		push_error("HayBale: %s has no %s" % [MODEL, MESH_NODE])
		return
	var mi:= MeshInstance3D.new()
	mi.name = "Bale"
	mi.mesh = mesh
	skin(mi)
	add_child(mi)


	_model = mi
	_meshes.assign([mi])


func _build_shapes() -> void:
	var size:= Cfg.COMPRESSOR_BALE_SIZE
	_shape_box(size, Vector3(0.0, size.y * 0.5, 0.0))


static func shared_mesh() -> Mesh:
	_look_up()
	return _shared_mesh


static func skin(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	if HayCompressor.spec_table().is_empty():
		return
	for i in mi.mesh.get_surface_count():
		var src:= mi.get_active_material(i)
		var key:= "" if src == null else src.resource_name


		if key.is_empty():
			key = MAT_STRAW
		var mat:= _material(key)
		if mat != null:
			mi.set_surface_override_material(i, mat)


static func _material(key: String) -> Material:
	var maker:= func() -> Material:
		return HayCompressor.make_material(key, HayCompressor.spec_table(),
			load(HayCompressor.SHADER))
	return Carryable.shared_material("bale/" + key, maker)


static func warm_up() -> void:
	if shared_mesh() == null:
		return
	for key: String in [MAT_STRAW, MAT_TWINE]:
		_material(key)


static func _look_up() -> void:
	if _looked:
		return
	_looked = true
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayBale: cannot load %s" % MODEL)
		return
	var scene: Node3D = packed.instantiate()
	var node:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
	if node != null:
		_shared_mesh = node.mesh


	scene.queue_free()


func to_state() -> Dictionary:
	return { "strands": strands }


func from_state(state: Dictionary) -> void:
	strands = int(state.get("strands", Cfg.COMPRESSOR_BALE_STRANDS))


func sale_strands() -> float:
	return float(strands) * Tech.bale_value_ratio()


func hay_strands() -> int:
	return strands


func clearance_size() -> Vector3:
	return Vector3(Cfg.COMPRESSOR_BALE_SIZE.x, Cfg.COMPRESSOR_BALE_SIZE.y,
		Cfg.COMPRESSOR_BALE_CLEAR)


func can_rip() -> bool:
	return true
