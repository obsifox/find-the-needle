class_name HayTuft
extends HayWad


const TUFT_MODEL:= "res://assets/models/compiled/hay_tuft.scn"
const TUFT_SPEC:= "res://assets/models/hay_tuft_materials.json"


static var all: Array [HayTuft] = []


static var _sizes: Array = []
static var _tuft_spec: Dictionary = { }
static var _tuft_looked:= false


var _size_index:= -1


func _ready() -> void:
	super ()
	if not all.has(self):
		all.append(self)
	tree_exiting.connect(_unlist)
	_emerge()


const EMERGE_MAX:= 3.0


var _emerging:= 0.0
var _emerge_layer:= 0
var _emerge_mask:= 0


func _emerge() -> void:
	_emerge_layer = collision_layer
	_emerge_mask = collision_mask
	collision_layer = 0
	collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	_emerging = EMERGE_MAX


func _physics_process(delta: float) -> void:
	if _emerging <= 0.0:
		return
	_emerging -= delta
	if _emerging > 0.0 and _straw_inside():
		return
	_emerging = 0.0
	collision_layer = _emerge_layer
	if BeltPath.is_rider(self) and BeltPath.cargo_physics_enabled:
		collision_layer &= ~ Cfg.L_BELT_CATCH
	collision_mask = _emerge_mask


func _straw_inside() -> bool:
	if not is_inside_tree():
		return false
	var box:= BoxShape3D.new()
	box.size = _collider_size()
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = global_transform * Transform3D(Basis(), Vector3(0.0, box.size.y * 0.5, 0.0))
	q.collision_mask = Cfg.L_STRAND
	q.collide_with_areas = false
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var body:= hit.get("collider") as Node
		if body != null and not body.has_meta(LiveStrandManager.META_RIDER):
			return true
	return false


func _unlist() -> void:
	all.erase(self)


func add_strands(count: int) -> int:
	var took:= mini(count, Cfg.TUFT_MAX - strands)
	if took > 0:
		set_strands(strands + took)
	return took


func takes_straw() -> bool:
	return is_inside_tree() and not is_held() and not freeze and strands < Cfg.TUFT_MAX and not has_meta(PropManager.META_CLAIM)


func reach() -> float:
	var s:= _size_row()
	if s.is_empty():
		return 0.2
	var size: Vector3 = s ["size"]
	return maxf(size.x, size.z) * 0.5 * _stretch()


func height() -> float:
	var s:= _size_row()
	if s.is_empty():
		return 0.05
	return (s ["size"] as Vector3).y * _lift()


func clearance_size() -> Vector3:
	return _collider_size()


func _pick_size() -> int:
	_look_up_tuft()
	var best:= -1
	var best_d:= INF
	for i in _sizes.size():
		var d:= absf(log(float(maxi(strands, 1)) / float(_sizes [i] ["strands"])))
		if d < best_d:
			best_d = d
			best = i
	return best


func _size_row() -> Dictionary:
	if _size_index < 0 or _size_index >= _sizes.size():
		return { }
	return _sizes [_size_index]


func _stretch() -> float:
	var s:= _size_row()
	if s.is_empty():
		return 1.0
	return clampf(sqrt(float(strands) / float(s ["strands"])),
		Cfg.TUFT_STRETCH.x, Cfg.TUFT_STRETCH.y)


func _lift() -> float:
	return sqrt(_stretch())


func _build_model() -> void:
	_look_up_tuft()


	var holder:= Node3D.new()
	holder.name = "Tuft"
	var mi:= MeshInstance3D.new()
	mi.name = "Tuft_LOD"
	holder.add_child(mi)
	add_child(holder)
	_model = holder
	_meshes.assign([mi])


func _lod_meshes() -> Array:
	var row:= _size_row()
	return row ["meshes"] if not row.is_empty() else []


func _lod_cuts() -> PackedFloat32Array:
	var row:= _size_row()
	return row ["ends"] if not row.is_empty() else PackedFloat32Array()


func _lod_scale() -> float:
	return _stretch()


func _surface_material(key: String) -> Material:
	return HayTuft._material(key)


static var _materials: Dictionary = { }


static func _material(key: String) -> Material:
	if not _materials.has(key):
		_materials [key] = HayCompressor.make_material(key, _tuft_spec,
			load(HayCompressor.SHADER))
	return _materials [key]


static func warm_up() -> void:
	_look_up_tuft()
	for row: Dictionary in _sizes:
		for mesh: Mesh in row ["meshes"]:
			for s in mesh.get_surface_count():
				var src:= mesh.surface_get_material(s)
				_material(src.resource_name if src != null else "")


func _build_shapes() -> void:
	_shape_box(Vector3(0.3, 0.04, 0.2), Vector3(0.0, 0.02, 0.0))


func _collider_size() -> Vector3:
	var s:= _size_row()
	if s.is_empty():
		return Vector3(0.3, 0.04, 0.2)
	var size: Vector3 = s ["size"]
	return Vector3(size.x * _stretch(), size.y * _lift(), size.z * _stretch()) * Cfg.TUFT_COLLIDER_SHRINK


func _apply_strands() -> void:
	var was:= _size_index
	_size_index = _pick_size()
	if _model != null:
		_model.scale = Vector3(_stretch(), _lift(), _stretch())


		if _size_index != was:
			_lod = -1
			_set_lod(0)
	var box_size:= _collider_size()
	for child in get_children():
		var cs:= child as CollisionShape3D
		if cs == null:
			continue
		var box:= cs.shape as BoxShape3D
		if box == null:
			continue
		box.size = box_size
		cs.position = Vector3(0.0, box_size.y * 0.5, 0.0)
	mass = clampf(float(strands) * Cfg.WAD_MASS_PER_STRAND, Cfg.TUFT_MASS_MIN,
		Cfg.WAD_MASS_MAX)


static func full_collider_size() -> Vector3:
	_look_up_tuft()
	var best:= Vector3(0.3, 0.04, 0.2)
	var most:= -1
	for row: Dictionary in _sizes:
		if int(row ["strands"]) > most:
			most = int(row ["strands"])
			best = row ["size"]
	return best * Cfg.TUFT_COLLIDER_SHRINK


static func _look_up_tuft() -> void:
	if _tuft_looked:
		return
	_tuft_looked = true
	var res: JSON = load(TUFT_SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_tuft_spec = res.data
	elif FileAccess.file_exists(TUFT_SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUFT_SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_tuft_spec = parsed
	var packed: PackedScene = load(TUFT_MODEL)
	if packed == null:
		push_error("HayTuft: cannot load %s" % TUFT_MODEL)
		return
	var scene: Node3D = packed.instantiate()
	for entry: Variant in _tuft_spec.get("sizes", []):
		if entry is not Dictionary:
			continue
		var row: Dictionary = entry
		var meshes: Array = []
		var ends:= PackedFloat32Array()
		for lod: Variant in row.get("lods", []):
			if lod is not Dictionary:
				continue
			var node:= scene.find_child(String((lod as Dictionary).get("node", "")), true,
				false) as MeshInstance3D
			if node == null or node.mesh == null:
				continue
			meshes.append(node.mesh)
			ends.append(float((lod as Dictionary).get("end", 0.0)))
		if meshes.is_empty():
			continue
		ends [ends.size() - 1] = 0.0
		var size: Array = row.get("size", [0.3, 0.04, 0.2])
		_sizes.append({
			"strands": int(row.get("strands", 40)),
			"size": Vector3(float(size [0]), float(size [1]), float(size [2])),
			"meshes": meshes,
			"ends": ends,
		})
	if _sizes.is_empty():
		push_error("HayTuft: %s has no tuft meshes in it" % TUFT_MODEL)
	scene.queue_free()
