class_name HayShop
extends Node3D


const MODEL:= "res://assets/models/compiled/hay_shop.scn"


const SPEC:= "res://assets/models/hay_shop_materials.json"


const DISPLAY:= "res://assets/models/hay_shop_display.json"


const SHADER:= "res://assets/stand_surface.gdshader"

const N_PLAYER_STAND:= "Marker_PlayerStand"
const N_SPAWN_OUT:= "Marker_SpawnOut"
const N_FOCUS:= "Marker_ShopFocus"


const N_TRIGGER:= "Trigger_ShopZone"


const OPEN_DISTANCE:= 4.5


const AIM_DEGREES:= 42.0


const SPAWN_FORWARD:= 0.55

var _model: Node3D
var _displays: Node3D


var _stand_local:= Vector3.ZERO
var _spawn_local:= Vector3.ZERO

var _focus_local:= Vector3.ZERO


var _painted: Dictionary = { }


func _ready() -> void:
	_build_model()
	_hide_volumes()
	_skin()
	_read_markers()
	_build_displays()
	_check_tags()


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayShop: cannot load %s" % MODEL)
		return
	_model = packed.instantiate()
	_model.name = "Model"
	add_child(_model)


func _hide_volumes() -> void:
	var trigger:= _find(N_TRIGGER) as VisualInstance3D
	if trigger != null:
		trigger.visible = false


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _skin() -> void:
	if _model == null:
		return
	var spec:= _load_spec()
	if spec.is_empty():
		push_warning("HayShop: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src == null:
				continue


			var key:= src.resource_name


			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.make_material(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mi.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("HayShop: no table entry for %s" % ", ".join(missed.keys()))


func _load_spec() -> Dictionary:
	return _read_json(SPEC)


static func _read_json(path: String) -> Dictionary:
	var res: JSON = load(path) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		return res.data
	if not FileAccess.file_exists(path):
		return { }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _read_markers() -> void:
	_stand_local = _marker_local(N_PLAYER_STAND, Vector3(0.0, 0.0, 2.33))
	_spawn_local = _marker_local(N_SPAWN_OUT, _stand_local)
	_focus_local = _marker_local(N_FOCUS, Vector3(0.0, 1.34, 1.38))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	if _model == null:
		return fallback
	var n:= _find(node_name) as Node3D
	if n == null:
		push_warning("HayShop: model has no %s, falling back to a fixed offset" % node_name)
		return fallback


	return to_local(n.global_position)


func _build_displays() -> void:
	var table:= _read_json(DISPLAY)
	var rows: Array = table.get("displays", [])
	if rows.is_empty():
		push_warning("HayShop: no display table at %s, the shelves will be bare" % DISPLAY)
		return
	_displays = Node3D.new()
	_displays.name = "Displays"
	add_child(_displays)

	for entry: Variant in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var id:= str(row.get("id", ""))
		_painted [id] = {
			"price": float(row.get("price", 0.0)),
			"label": str(row.get("label", "")),
		}
		var path:= str(row.get("model", ""))
		if not ResourceLoader.exists(path):
			push_warning("HayShop: display '%s' has no model at %s" % [id, path])
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			continue
		var inst:= packed.instantiate() as Node3D
		if inst == null:
			continue
		inst.name = "Display_%s" % id
		_displays.add_child(inst)
		inst.transform = _row_transform(row)
		_skin_display(inst, path)


func _skin_display(inst: Node3D, model_path: String) -> void:
	var spec_path:= model_path.get_basename() + "_materials.json"
	if not ResourceLoader.exists(spec_path) and not FileAccess.file_exists(spec_path):
		return
	var spec:= _read_json(spec_path)
	if spec.is_empty():
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src == null or src.resource_name.is_empty():
				continue
			var key:= src.resource_name
			if not built.has(key):
				built [key] = HayCompressor.make_material(key, spec, shader)
			if built [key] != null:
				mi.set_surface_override_material(i, built [key])


static func _row_transform(row: Dictionary) -> Transform3D:
	var cols: Array = row.get("basis_columns", [])
	var origin: Array = row.get("origin", [])
	if cols.size() != 3 or origin.size() != 3:
		return Transform3D.IDENTITY
	return Transform3D(
		Basis(_vec(cols [0]), _vec(cols [1]), _vec(cols [2])),
		_vec(origin))


static func _vec(a: Variant) -> Vector3:
	var v: Array = a
	return Vector3(float(v [0]), float(v [1]), float(v [2]))


func _check_tags() -> void:
	var wrong: Array [String] = []
	for id: String in _painted:
		var live:= live_price(id)
		if live >= 0.0 and absf(live - painted_price(id)) > 0.005:
			wrong.append("%s is priced $%s and painted $%s"
				% [id, Hud.money_text(live), Hud.money_text(painted_price(id))])
		var name:= live_label(id)
		if name != "" and painted_label(id) != "" and name.to_upper() != painted_label(id).to_upper():
			wrong.append("%s is called '%s' and painted '%s'"
				% [id, name, painted_label(id)])
	if wrong.is_empty():
		return
	push_warning("HayShop: the tags are out of date (%s). Rebuild with: blender -b -P assets/blender/_build/shop.py"
		% "; ".join(wrong))


static func live_price(id: String) -> float:
	if ItemDb.has_item(id) and ItemDb.price(id) > 0.0:
		return ItemDb.price(id)
	if TechTree.has_id(id):
		return TechTree.cost_at(id, 0)
	return -1.0


static func live_label(id: String) -> String:
	if ItemDb.has_item(id) and ItemDb.price(id) > 0.0:
		return ItemDb.display_name(id)
	if TechTree.has_id(id):
		return TechTree.display_name(id)
	return ""


static func sold_here(id: String) -> bool:
	return ItemDb.has_item(id) and ItemDb.price(id) > 0.0


func interact_point() -> Vector3:
	return to_global(_stand_local)


func spawn_point() -> Vector3:
	return to_global(_spawn_local)


func focus_point() -> Vector3:
	return to_global(_focus_local)


func is_near(pos: Vector3) -> bool:
	return pos.distance_to(interact_point()) <= OPEN_DISTANCE


func is_hovered(eye: Vector3, look: Vector3) -> bool:


	var stand:= interact_point()
	if not is_near(Vector3(eye.x, stand.y, eye.z)):
		return false
	var to_counter:= focus_point() - eye
	if to_counter.length_squared() < 0.0001:
		return true
	return look.normalized().dot(to_counter.normalized()) >= cos(deg_to_rad(AIM_DEGREES))


func painted_price(id: String) -> float:
	var d: Dictionary = _painted.get(id, { })
	return float(d.get("price", -1.0))


func painted_label(id: String) -> String:
	var d: Dictionary = _painted.get(id, { })
	return str(d.get("label", ""))


func display_ids() -> Array:
	return _painted.keys()
