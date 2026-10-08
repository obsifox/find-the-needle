class_name FeedDisc
extends Carryable


const MODEL:= "res://assets/models/feed_disc.glb"
const MESH_NODE:= "FeedDisc"
static var _shared_mesh: Mesh = null
static var _looked:= false


var strands:= default_strands()


var brick_hay:= default_brick_hay()
var brick_worth:= default_brick_worth()


static func default_strands() -> int:
	return Cfg.BRIQUETTE_BATCH_STRANDS + default_brick_hay()


static func default_brick_hay() -> int:
	return Cfg.BRIQUETTE_BATCH_BRICKS * Cfg.PELLETIZER_BRICK_STRANDS


static func default_brick_worth() -> float:
	return float(default_brick_hay()) * Cfg.PELLETIZER_BRICK_RATIO


func _ready() -> void:
	super ()
	mass = Cfg.FEED_DISC_MASS


	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.95
	physics_material_override.bounce = 0.02
	angular_damp = 3.0


func impact_sfx() -> String:
	return "brick_land"


func _build_model() -> void:
	var mesh:= shared_mesh()
	if mesh == null:
		push_error("FeedDisc: %s has no %s" % [MODEL, MESH_NODE])
		return
	var mi:= MeshInstance3D.new()
	mi.name = "Disc"
	mi.mesh = mesh

	add_child(mi)


	_model = mi
	_meshes.assign([mi])


func _build_shapes() -> void:
	var size:= Cfg.FEED_DISC_SIZE
	_shape_cylinder(size.x * 0.5, size.y, Vector3(0.0, size.y * 0.5, 0.0))


static func shared_mesh() -> Mesh:
	_look_up()
	return _shared_mesh


static func _look_up() -> void:
	if _looked:
		return
	_looked = true
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("FeedDisc: cannot load %s" % MODEL)
		return
	var scene: Node3D = packed.instantiate()
	var node:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
	if node == null:


		for child in scene.find_children("*", "MeshInstance3D", true, false):
			node = child as MeshInstance3D
			break
	if node != null:
		_shared_mesh = node.mesh
		for surface in _shared_mesh.get_surface_count():
			var mat:= _shared_mesh.surface_get_material(surface) as BaseMaterial3D
			if mat != null:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


	scene.queue_free()


func to_state() -> Dictionary:
	return { "strands": strands, "brick_hay": brick_hay, "brick_worth": brick_worth }


func from_state(state: Dictionary) -> void:
	strands = int(state.get("strands", default_strands()))


	brick_hay = clampi(int(state.get("brick_hay", default_brick_hay())), 0, strands)
	brick_worth = maxf(0.0, float(state.get("brick_worth",
		float(brick_hay) * Cfg.PELLETIZER_BRICK_RATIO)))


func sale_strands() -> float:
	return float(strands - brick_hay) * Tech.disc_value_ratio() + brick_worth


func hay_strands() -> int:
	return strands


func can_rip() -> bool:
	return true


func rip_yield() -> int:
	return Cfg.BRIQUETTE_BATCH_STRANDS


func rip_label() -> String:
	return tr("Break open the feed disc (the pellets are lost)")


func clearance_size() -> Vector3:
	return Vector3(Cfg.FEED_DISC_SIZE.x, Cfg.FEED_DISC_SIZE.y,
		Cfg.FEED_DISC_CLEAR)
