class_name HayWad
extends Carryable


const MODEL:= "res://assets/models/compiled/hay_wad.scn"
const SPEC:= "res://assets/models/hay_wad_materials.json"


const MESH_NODE:= "Wad"

static var _shared_meshes: Array [Mesh] = []


static var _lod_ends: PackedFloat32Array = PackedFloat32Array()
static var _looked:= false
static var _spec_cache: Dictionary = { }


var strands:= Cfg.WAD_BASE_STRANDS


var _lod:= -1
var _draw_scale:= 1.0


static var _drawn: Array [HayWad] = []
static var _lod_cursor:= 0


static var lod_frozen:= false


const LOD_SLICE_FRAMES:= 15


static func split(count: int) -> Array [int]:
	var out: Array [int] = []
	if count < Cfg.WAD_MIN_STRANDS:
		return out
	var n: int = int(ceil(float(count) / float(Cfg.WAD_MAX_STRANDS)))
	var each: int = count / n
	var extra: int = count % n
	for i in n:
		out.append(each + (1 if i < extra else 0))
	return out


static func scale_for(count: int) -> float:
	return pow(maxf(float(count), 1.0) / float(Cfg.WAD_BASE_STRANDS), 1.0 / 3.0) * Cfg.WAD_PACK


static func room_at(space: PhysicsDirectSpaceState3D, at: Vector3,
		count: int, exclude: Array [RID] = []) -> bool:
	return Carryable.room_for(space, at, Basis(), clearance_for(count), exclude)


static func clearance_for(count: int) -> Vector3:
	return Vector3(Cfg.WAD_BASE_SIZE.x, Cfg.WAD_BASE_SIZE.y, Cfg.WAD_CLEAR) * scale_for(count)


func clearance_size() -> Vector3:
	return clearance_for(strands)


func _enter_tree() -> void:
	_drawn.append(self)


func _exit_tree() -> void:
	_drawn.erase(self)


func _ready() -> void:
	super ()


	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0
	angular_damp = 5.0
	_apply_strands()


func set_strands(count: int) -> void:
	strands = maxi(1, count)
	if is_inside_tree():
		_apply_strands()


func _apply_strands() -> void:
	var s:= scale_for(strands)
	if _model != null:
		_model.scale = Vector3.ONE * s
		_draw_scale = s
	for child in get_children():
		var cs:= child as CollisionShape3D
		if cs == null:
			continue
		var box:= cs.shape as BoxShape3D
		if box == null:
			continue
		box.size = _collider_size() * s
		cs.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	mass = clampf(float(strands) * Cfg.WAD_MASS_PER_STRAND,
		Cfg.WAD_MASS_MIN, Cfg.WAD_MASS_MAX)


func impact_sfx() -> String:
	return "wad_land"


func _collider_size() -> Vector3:
	return Cfg.WAD_BASE_SIZE * Cfg.WAD_COLLIDER_SHRINK


func _build_model() -> void:
	var meshes:= shared_meshes()
	if meshes.is_empty():
		push_error("HayWad: %s has no wad mesh in it" % MODEL)
		return


	var holder:= Node3D.new()
	holder.name = "Wad"
	var mi:= MeshInstance3D.new()
	mi.name = "Wad_LOD"
	mi.layers = HAY_LAYER
	holder.add_child(mi)
	add_child(holder)


	_model = holder
	_meshes.assign([mi])
	_draw_scale = scale_for(strands)
	_lod = -1
	_set_lod(0)


func draw_shifted(shift: Transform3D) -> void:
	if _meshes.is_empty() or _model == null:
		return
	var mi:= _meshes [0]
	if shift == Transform3D.IDENTITY:
		if mi.transform != Transform3D.IDENTITY:
			mi.transform = Transform3D.IDENTITY
		return
	mi.global_transform = shift * _model.global_transform


func _lod_meshes() -> Array:
	return _shared_meshes


func _lod_cuts() -> PackedFloat32Array:
	return _lod_ends


func _lod_scale() -> float:
	return _draw_scale


func _surface_material(key: String) -> Material:
	return _material(key)


func _set_lod(lod: int) -> void:
	if lod == _lod or _meshes.is_empty():
		return
	var meshes:= _lod_meshes()
	if lod < 0 or lod >= meshes.size():
		return
	var mi:= _meshes [0]
	var mesh: Mesh = meshes [lod]
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var src:= mesh.surface_get_material(i)
		var mat:= _surface_material(src.resource_name if src != null else "")
		if mat != null:
			mi.set_surface_override_material(i, mat)
	_lod = lod


func _pick_lod(eye: Vector3) -> void:
	var cuts:= _lod_cuts()
	if cuts.is_empty():
		return
	var d:= global_position.distance_to(eye)
	var scale:= _lod_scale()
	var lod:= cuts.size() - 1
	for i in cuts.size():
		var end:= cuts [i] * scale
		if end > 0.0 and d < end:
			lod = i
			break
	_set_lod(lod)


static func lod_tick(eye: Vector3) -> void:
	var n:= _drawn.size()
	if n == 0 or lod_frozen:
		return
	var per:= mini(n, maxi(8, n / LOD_SLICE_FRAMES))
	for k in per:
		_lod_cursor += 1
		if _lod_cursor >= _drawn.size():
			_lod_cursor = 0
		var w: HayWad = _drawn [_lod_cursor]
		if is_instance_valid(w) and w.is_inside_tree():
			w._pick_lod(eye)


func _build_shapes() -> void:
	var size:= _collider_size()
	_shape_box(size, Vector3(0.0, size.y * 0.5, 0.0))


static func shared_mesh() -> Mesh:
	var all:= shared_meshes()
	return all [0] if not all.is_empty() else null


static func shared_meshes() -> Array [Mesh]:
	_look_up()
	return _shared_meshes


static func _material(key: String) -> Material:
	var maker:= func() -> Material:
		return HayCompressor.make_material(key, spec_table(),
			load(HayCompressor.SHADER))
	return Carryable.shared_material("wad/" + key, maker)


static func warm_up() -> void:
	for mesh: Mesh in shared_meshes():
		for i in mesh.get_surface_count():
			var src:= mesh.surface_get_material(i)
			_material(src.resource_name if src != null else "")


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
		push_error("HayWad: cannot load %s" % MODEL)
		return
	var scene: Node3D = packed.instantiate()
	var ends:= PackedFloat32Array()
	for entry: Variant in spec_table().get("lods", []):
		if entry is not Dictionary:
			continue
		var row: Dictionary = entry
		var node:= scene.find_child(String(row.get("node", "")), true, false) as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		_shared_meshes.append(node.mesh)
		ends.append(float(row.get("end", 0.0)))
	if _shared_meshes.is_empty():
		var one:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
		if one != null and one.mesh != null:
			_shared_meshes.append(one.mesh)
			ends.append(0.0)
		else:
			push_error("HayWad: %s has no wad mesh in it" % MODEL)


	if not ends.is_empty():
		ends [ends.size() - 1] = 0.0
	_lod_ends = ends


	scene.queue_free()


func to_state() -> Dictionary:
	return { "strands": strands }


func from_state(state: Dictionary) -> void:
	set_strands(int(state.get("strands", Cfg.WAD_BASE_STRANDS)))


func sale_strands() -> float:
	return float(strands)


func hay_strands() -> int:
	return strands


func can_rip() -> bool:
	return true


func rips_loose() -> bool:
	return true
