class_name FoiledBale
extends Carryable


const MODEL:= "res://assets/models/hay_wrapper.glb"
const MESH_NODE:= "Wrapper_Foiled"

static var _shared_mesh: Mesh = null
static var _surface_names: PackedStringArray = PackedStringArray()
static var _looked:= false


var strands:= Cfg.COMPRESSOR_BALE_STRANDS


func _ready() -> void:
	super ()
	mass = Cfg.WRAPPER_FOILED_MASS


	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.0
	angular_damp = 4.0


func impact_sfx() -> String:
	return "bale_land"


func _build_model() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		push_error("FoiledBale: %s has no %s" % [MODEL, MESH_NODE])
		return
	var mi:= MeshInstance3D.new()
	mi.name = "Foiled"
	mi.mesh = mesh
	skin(mi)
	add_child(mi)


	_model = mi
	_meshes.assign([mi])


func _build_shapes() -> void:
	var size:= Cfg.WRAPPER_FOILED_SIZE
	_shape_box(size, Vector3(0.0, size.y * 0.5, 0.0))


static func skin(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	if HayWrapper.spec_table().is_empty():
		return
	for i in mi.mesh.get_surface_count():
		var key:= _surface_name(i)
		if key.is_empty():
			continue
		var mat:= _material(key)
		if mat != null:
			mi.set_surface_override_material(i, mat)


static func _material(key: String) -> Material:
	var maker:= func() -> Material:
		return HayWrapper.make_material(key, HayWrapper.spec_table(),
			load(HayWrapper.SHADER))
	return Carryable.shared_material("foiled/" + key, maker)


static func warm_up() -> void:
	if shared_mesh() == null:
		return
	for i in _surface_names.size():
		var key:= _surface_names [i]
		if not key.is_empty():
			_material(key)


static func shared_mesh() -> Mesh:
	_look_up()
	return _shared_mesh


static func _surface_name(i: int) -> String:
	_look_up()
	if i < 0 or i >= _surface_names.size():
		return ""
	return _surface_names [i]


static func _look_up() -> void:
	if _looked:
		return
	_looked = true
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("FoiledBale: cannot load %s" % MODEL)
		return
	var scene: Node3D = packed.instantiate()
	var node:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
	if node != null:
		_shared_mesh = node.mesh
		if _shared_mesh != null:
			for i in _shared_mesh.get_surface_count():
				var m:= node.get_active_material(i)
				_surface_names.append("" if m == null else m.resource_name)


	scene.queue_free()


func to_state() -> Dictionary:
	return { "strands": strands }


func from_state(state: Dictionary) -> void:
	strands = int(state.get("strands", Cfg.COMPRESSOR_BALE_STRANDS))


func sale_strands() -> float:
	return float(strands) * Tech.bale_value_ratio() * Tech.foil_value_ratio()


func hay_strands() -> int:
	return strands


func clearance_size() -> Vector3:
	return Vector3(Cfg.WRAPPER_FOILED_SIZE.x, Cfg.WRAPPER_FOILED_SIZE.y,
		Cfg.WRAPPER_PRODUCT_CLEAR)


func can_rip() -> bool:
	return true
