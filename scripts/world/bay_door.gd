class_name BayDoor
extends Node3D


const MODEL:= "res://assets/models/compiled/warehouse_door.scn"


const SPEC:= "res://assets/models/warehouse_door_materials.json"


const CLIP_FLAT:= "res://assets/clipped_flat.gdshader"


const N_TRIGGER:= "Trigger_DoorZone"
const N_PLAYER_STAND:= "Marker_PlayerStand"
const N_FOCUS:= "Marker_Focus"


const N_CLOCK:= "Marker_Clock"


const N_LEAF:= "Leaf"
const N_LEAF_BODY:= "Col_Leaf*"


const OPENING_W:= 4.4
const OPENING_H:= 5.4


const CLIP_Y:= OPENING_H + 0.46


const LIFT_MAX:= OPENING_H


const RISE_SECONDS:= 2.8
const SLAM_SECONDS:= 0.3


const OPEN_DB:= 6.0
const SLAM_DB:= 7.0


const BACK_THICKNESS:= 0.05


const OPEN_DISTANCE:= 5.0


const AIM_SLACK:= 0.25


enum Wall { X_POS, X_NEG, Z_POS, Z_NEG }

var wall: Wall = Wall.X_POS


var along:= 0.0


var warehouse: Warehouse


var held:= false


var _letting_in:= false

var _model: Node3D


var _stand_local:= Vector3.ZERO
var _focus_local:= Vector3(0.0, 2.4, 0.0)


var _leaf: Node3D
var _leaf_body: Node3D
var _leaf_rest:= Vector3.ZERO
var _body_rest:= Vector3.ZERO


var _leaf_mats: Array [ShaderMaterial] = []

var _lift:= 0.0
var _drive_tween: Tween


var countdown: CountdownBoard


func _ready() -> void:
	_build_model()
	_hide_volumes()
	_skin()
	_read_markers()
	_read_leaf()
	_add_countdown()
	_add_outside_frame()
	_seat()
	if warehouse != null:


		warehouse.rebuilt.connect(_seat)


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("BayDoor: cannot load %s" % MODEL)
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
		push_warning("BayDoor: no material table at %s, the door will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
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
		push_warning("BayDoor: no table entry for %s" % ", ".join(missed.keys()))


static func _load_spec() -> Dictionary:
	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		return res.data
	if not FileAccess.file_exists(SPEC):
		return { }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _read_markers() -> void:
	_stand_local = _marker_local(N_PLAYER_STAND, Vector3(0.0, 0.0, 2.1))
	_focus_local = _marker_local(N_FOCUS, Vector3(0.0, 2.43, 0.2))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	if _model == null:
		return fallback
	var n:= _find(node_name) as Node3D
	if n == null:
		push_warning("BayDoor: model has no %s, falling back to a fixed offset" % node_name)
		return fallback


	return to_local(n.global_position)


func _add_countdown() -> void:
	if _model == null:
		return
	var marker:= _find(N_CLOCK) as Node3D
	if marker == null:
		push_warning("BayDoor: model has no %s, the countdown board has no readout"
			% N_CLOCK)
		return
	var spec:= _load_spec()
	var shader: Shader = load(HayCompressor.SHADER)
	countdown = CountdownBoard.new()
	countdown.name = "Countdown"
	countdown.lit_material = HayCompressor.make_material("M_Lit", spec, shader)
	countdown.dim_material = HayCompressor.make_material("M_Dim", spec, shader)


	countdown.position = to_local(marker.global_position)
	add_child(countdown)


func _read_leaf() -> void:
	if _model == null:
		return
	_leaf = _find(N_LEAF) as Node3D
	if _leaf == null:
		push_warning("BayDoor: model has no %s, the door cannot open" % N_LEAF)
	else:
		_leaf_rest = _leaf.position
	_leaf_body = _model.find_child(N_LEAF_BODY, true, false) as Node3D
	if _leaf_body == null:
		push_warning("BayDoor: model has no %s, an open door will still be solid"
			% N_LEAF_BODY)
	else:
		_body_rest = _leaf_body.position
	_dedicate_leaf_materials()
	_add_back_face()


func _dedicate_leaf_materials() -> void:
	if _leaf == null:
		return
	var mine: Dictionary = { }
	for n: Node in _leaf.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var src:= mi.get_surface_override_material(i) as ShaderMaterial
			if src == null:
				continue
			if not mine.has(src):
				var copy:= src.duplicate() as ShaderMaterial
				mine [src] = copy
				_leaf_mats.append(copy)
			mi.set_surface_override_material(i, mine [src])


func _add_back_face() -> void:
	if _leaf == null:
		return


	var skin:= _find("Leaf_Skin") as Node3D
	var skin_z:= skin.position.z if skin != null else 0.07


	var originals:= _leaf.find_children("*", "MeshInstance3D", true, false)

	var back:= Node3D.new()
	back.name = "LeafBack"
	back.rotation.y = PI


	back.position.z = 2.0 * skin_z - BACK_THICKNESS
	_leaf.add_child(back)
	for n: Node in originals:
		var src:= n as MeshInstance3D
		var copy:= src.duplicate() as MeshInstance3D
		copy.name = "Back_" + src.name


		for i in src.get_surface_override_material_count():
			copy.set_surface_override_material(i, src.get_surface_override_material(i))
		back.add_child(copy)


	var seal:= BoxMesh.new()
	seal.size = Vector3(OPENING_W + 0.2, OPENING_H, 0.02)


	var mat:= ShaderMaterial.new()
	mat.shader = load(CLIP_FLAT)
	mat.set_shader_parameter("albedo", Vector3(0.03, 0.035, 0.033))
	mat.set_shader_parameter("rough", 0.95)
	_leaf_mats.append(mat)
	var sheet:= MeshInstance3D.new()
	sheet.name = "LeafSeal"
	sheet.mesh = seal


	sheet.set_surface_override_material(0, mat)
	sheet.position = Vector3(0.0, OPENING_H * 0.5, skin_z - BACK_THICKNESS * 0.5)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leaf.add_child(sheet)


func _surface_material_of(mesh_name: String) -> Material:
	var mi:= _find(mesh_name) as MeshInstance3D
	if mi == null:
		return null
	return mi.get_surface_override_material(0)


func _add_outside_frame() -> void:
	if _model == null:
		return
	var mat:= _surface_material_of("Door_Steel")
	if mat == null:
		return
	var jamb:= 0.34
	var out:= - (Warehouse.WALL_T + 0.05)
	for sx: float in [-1.0, 1.0]:
		_frame_box("OutJamb%d" % int(sx), mat,
			Vector3(jamb, OPENING_H + jamb, 0.1),
			Vector3(sx * (OPENING_W + jamb) * 0.5, (OPENING_H + jamb) * 0.5, out))
	_frame_box("OutHead", mat,
		Vector3(OPENING_W + jamb * 2.0, jamb, 0.1),
		Vector3(0.0, OPENING_H + jamb * 0.5, out))


func _frame_box(node_name: String, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mesh:= BoxMesh.new()
	mesh.size = size
	var mi:= MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	_model.add_child(mi)


func set_open_amount(t: float) -> void:
	_lift = clampf(t, 0.0, 1.0) * LIFT_MAX
	if _leaf != null:
		_leaf.position = _leaf_rest + Vector3(0.0, _lift, 0.0)
	if _leaf_body != null:
		_leaf_body.position = _body_rest + Vector3(0.0, _lift, 0.0)


func open_amount() -> float:
	return _lift / LIFT_MAX


func is_shut() -> bool:
	return _lift <= 0.001


func is_moving() -> bool:
	return _drive_tween != null and _drive_tween.is_valid()


func open(seconds: float = RISE_SECONDS) -> void:
	_drive(1.0, seconds, Tween.TRANS_SINE, Tween.EASE_OUT)
	Audio.play_3d("door_open", focus_point(), OPEN_DB)


func slam(seconds: float = SLAM_SECONDS) -> void:
	_drive(0.0, seconds, Tween.TRANS_QUAD, Tween.EASE_IN)
	Audio.play_3d_delayed("door_slam", focus_point(), seconds, SLAM_DB)


func is_locked() -> bool:
	return not GameState.contract_signed(DeliveryBook.id_at(0))


func toggle() -> bool:
	if is_moving() or held:
		return true
	if is_shut():
		open()
	else:
		slam()
	return true


const LET_IN_CLEAR:= 3.0


func is_outside(eye: Vector3) -> bool:
	return to_local(eye).z < 0.0


func let_in() -> bool:
	if is_moving() or held or not is_shut():
		return true
	open()
	_letting_in = true
	return true


func _physics_process(_delta: float) -> void:
	if not _letting_in:
		return
	if held or not is_locked():


		_letting_in = false
		return
	if is_moving():
		return
	if is_shut():

		_letting_in = false
		return
	var who:= get_tree().get_first_node_in_group("player") as Node3D
	if who == null or to_local(who.global_position).z < LET_IN_CLEAR:
		return
	_letting_in = false
	slam()


func prompt(eye: Vector3, look: Vector3) -> String:
	if not is_hovered(eye, look):
		return ""
	if is_locked() and is_outside(eye):

		return tr("Open the door") if is_shut() else ""
	return tr("Open the door") if is_shut() else tr("Shut the door")


func snap_shut() -> void:
	if _drive_tween != null and _drive_tween.is_valid():
		_drive_tween.kill()
	set_open_amount(0.0)


func _drive(to: float, seconds: float, trans: Tween.TransitionType,
		how: Tween.EaseType) -> void:
	if _drive_tween != null and _drive_tween.is_valid():
		_drive_tween.kill()
	_drive_tween = create_tween()
	_drive_tween.set_trans(trans).set_ease(how)
	_drive_tween.tween_method(set_open_amount, open_amount(), to, maxf(seconds, 0.01))


func _seat() -> void:
	var span:= warehouse.inner if warehouse != null else Warehouse.INNER
	var at:= _bay_centre()
	var horizontal:= wall == Wall.X_POS or wall == Wall.X_NEG

	var outward:= 1.0 if wall == Wall.X_POS or wall == Wall.Z_POS else -1.0
	var pos:= Vector3(span * outward, 0.0, at) if horizontal else Vector3(at, 0.0, span * outward)


	pos.y = warehouse.floor_y(pos) if warehouse != null else 0.0
	position = pos


	rotation.y = deg_to_rad(_yaw_degrees())
	_apply_clip()


func _apply_clip() -> void:
	var y:= global_position.y + CLIP_Y
	for m: ShaderMaterial in _leaf_mats:
		m.set_shader_parameter("clip_above", y)


func _yaw_degrees() -> float:
	match wall:
		Wall.X_POS:
			return -90.0
		Wall.X_NEG:
			return 90.0
		Wall.Z_POS:
			return 180.0
		_:
			return 0.0


func _bay_centre() -> float:
	if warehouse == null:
		return along
	return warehouse.bay_centre(along)


func interact_point() -> Vector3:
	return to_global(_stand_local)


func focus_point() -> Vector3:
	return to_global(_focus_local)


func inboard_point(distance: float) -> Vector3:
	return to_global(Vector3(0.0, 0.0, distance))


func is_hovered(eye: Vector3, look: Vector3) -> bool:


	if is_moving() or held:
		return false


	var stand:= _stand_local
	if is_outside(eye):
		stand.z = - (Warehouse.WALL_T + _stand_local.z)
	if eye.distance_to(to_global(stand)) > OPEN_DISTANCE:
		return false


	var from:= to_local(eye)
	var dir:= to_local(eye + look.normalized()) - from
	if absf(dir.z) < 0.0001:
		return false
	var t:= (_focus_local.z - from.z) / dir.z
	if t <= 0.0:
		return false
	var hit:= from + dir * t
	return absf(hit.x) <= OPENING_W * 0.5 + AIM_SLACK and hit.y >= - AIM_SLACK and hit.y <= OPENING_H + AIM_SLACK
