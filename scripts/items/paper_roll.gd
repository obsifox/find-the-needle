class_name PaperRoll
extends Carryable


const MODEL:= "res://assets/models/compiled/paper_roll.scn"
const MESH_NODE:= "PaperRoll"


const SPEC:= "res://assets/models/paper_roll_materials.json"

static var _shared_mesh: Mesh = null
static var _surface_names: PackedStringArray = PackedStringArray()
static var _looked:= false


var strands:= Cfg.PULPER_BATCH_STRANDS


func _ready() -> void:
	super ()
	mass = Cfg.PAPER_ROLL_MASS
	physics_material_override = PhysicsMaterial.new()


	physics_material_override.friction = 0.95
	physics_material_override.bounce = 0.0


	angular_damp = 6.0


func impact_sfx() -> String:
	return "brick_land"


func _build_model() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		push_error("PaperRoll: %s has no %s" % [MODEL, MESH_NODE])
		return
	var mi:= MeshInstance3D.new()
	mi.name = "Roll"
	mi.mesh = mesh
	if not spec_table().is_empty():
		for i in mesh.get_surface_count():
			var key:= _surface_name(i)
			if key.is_empty():
				continue
			var mat:= _material(key)
			if mat != null:
				mi.set_surface_override_material(i, mat)
	add_child(mi)


	_model = mi
	_meshes.assign([mi])


static func skin(mi: MeshInstance3D) -> void:
	if mi.mesh == null or spec_table().is_empty():
		return
	_look_up()
	for i in mi.mesh.get_surface_count():
		var key:= _surface_name(i)
		if key.is_empty():
			continue
		var mat:= _material(key)
		if mat != null:
			mi.set_surface_override_material(i, mat)


static func _material(key: String) -> Material:
	var maker:= func() -> Material:
		return HayWrapper.make_material(key, spec_table(),
			load(PaperMachine.SHADER))
	return Carryable.shared_material("roll/" + key, maker)


static func warm_up() -> void:
	var mesh:= shared_mesh()
	if mesh == null or spec_table().is_empty():
		return
	for i in mesh.get_surface_count():
		var key:= _surface_name(i)
		if not key.is_empty():
			_material(key)


static var _spec_cache: Dictionary = { }


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


func _build_shapes() -> void:
	var size:= Cfg.PAPER_ROLL_SIZE
	_shape_cylinder(size.y * 0.5, size.x, Vector3(0.0, size.y * 0.5, 0.0),
		Basis(Vector3(0, 0, 1), PI * 0.5))


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
		push_error("PaperRoll: cannot load %s" % MODEL)
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
	strands = int(state.get("strands", Cfg.PULPER_BATCH_STRANDS))


func sale_strands() -> float:
	return float(strands) * Tech.pulp_value_ratio() * Tech.paper_value_ratio()


func hay_strands() -> int:
	return strands


func can_rip() -> bool:
	return true


func rips_to_shreds() -> bool:
	return true


func rip_yield() -> int:
	return 0


func rip_label() -> String:
	return tr("Shred the paper roll (the paper is lost)")


func clearance_size() -> Vector3:
	return Vector3(Cfg.PAPER_ROLL_SIZE.x, Cfg.PAPER_ROLL_SIZE.y,
		Cfg.PAPER_ROLL_CLEAR)
