class_name DeliveryBoard
extends Node3D


const MODEL:= "res://assets/models/compiled/delivery_board.scn"
const SPEC:= "res://assets/models/delivery_board_materials.json"


const LEAN:= 8.0


const SHEET_HALF:= Vector2(0.17, 0.225)
const SHEET_AT:= Vector2(-0.355, 1.505)


const CORK_Y:= 0.016


const HEADER_BOTTOM:= 1.795


const SHEET_Y:= CORK_Y - 0.004


const INK_OUT:= 0.0006


const H_TITLE:= 0.03
const H_COUNT:= 0.052
const H_BODY:= 0.017
const H_SMALL:= 0.014


const WANTED_SIDE:= 0.062
const WANTED_X:= -0.112


const PIXEL:= 0.0004

const COL_INK:= Color(0.13, 0.12, 0.11)
const COL_RED:= Color(0.55, 0.13, 0.09)
const COL_PAPER:= Color(0.76, 0.72, 0.62)
const COL_NOTE_PAPER:= Color(0.7, 0.64, 0.52)


const NOTE_HALF:= Vector2(0.135, 0.175)


const NOTE_AT:= Vector2(0.3, 1.18)


const NOTE_SPIN:= 4.5

const H_NOTE_TITLE:= 0.026
const H_NOTE_LINE:= 0.016
const H_NOTE_FOOT:= 0.015


const CHIT_HALF:= Vector2(0.12, 0.09)
const CHIT_AT:= Vector2(0.34, 1.62)


const CHIT_SPIN:= 6.0

const H_CHIT_TITLE:= 0.019
const H_CHIT_COUNT:= 0.034
const H_CHIT_LINE:= 0.013


const TALLY_HALF:= Vector2(0.33, 0.03)
const TALLY_AT:= Vector2(0.0, 1.7625)


const TALLY_SPIN:= -1.5


const H_TALLY:= 0.03


const CLEAR_HALF:= Vector2(0.24, 0.12)
const CLEAR_AT:= Vector2(-0.215, 1.08)

const CLEAR_SPIN:= 3.0

const H_CLEAR_HEAD:= 0.055
const H_CLEAR_UNDER:= 0.03


const CLEAR_HEAD_Y:= 0.014
const CLEAR_UNDER_Y:= -0.062

const COL_CLEAR_CARD:= Color(0.75, 0.74, 0.69)
const COL_CLEAR_HEAD:= Color(0.58, 0.11, 0.09)
const COL_CLEAR_UNDER:= Color(0.24, 0.21, 0.18)


const CLEAR_HEAD_TEXT:= "CLEARANCE"

const CLEAR_UNDER_TEXT:= "sell everything you built"


const OUTLINE_W:= 0.011


const OUTLINE_BACK:= 0.0005
const COL_OUTLINE:= Color(1.0, 0.78, 0.28)


const COL_PICKED:= Color(1.0, 1.0, 1.0)


const OUTLINE_PULSE:= 1.6


const OUTLINE_A_LOW:= 0.42
const OUTLINE_A_HIGH:= 0.78
const OUTLINE_A_HOVER:= 1.0


const ORDER_DISTANCE:= 3.6


const NOTE_TICK:= 0.25


const SEAT_ACROSS:= -5.8
const SEAT_IN:= 2.0


signal note_pressed()


signal chit_pressed()


signal clearance_pressed()

var door: BayDoor
var warehouse: Warehouse


var live: LiveStrandManager


var player: Player

var _model: Node3D
var _face: Node3D
var _title: Label3D
var _count: Label3D
var _body: Label3D
var _state: Label3D
var _reward: Label3D
var _wanted: Sprite3D

var _note: Node3D
var _note_title: Label3D
var _note_gate: Label3D
var _note_detail: Label3D
var _note_foot: Label3D
var _tally: Label3D
var _chit: Node3D
var _chit_title: Label3D
var _chit_count: Label3D
var _chit_gloss: Label3D
var _chit_loose: Label3D
var _chit_rim: MeshInstance3D
var _chit_rim_mat: StandardMaterial3D
var _clear: Node3D
var _clear_rim: MeshInstance3D
var _outline: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _docket_rim: MeshInstance3D
var _docket_rim_mat: StandardMaterial3D
var _note_clock:= 0.0
var _pulse:= 0.0


func _ready() -> void:
	_build_model()
	_skin()
	_build_docket()
	_build_note()
	_build_chit()
	_build_tally()
	_build_clearance()
	_seat()
	if warehouse != null:
		warehouse.rebuilt.connect(_seat)


	_hide_docket()
	_refresh_note()


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("DeliveryBoard: cannot load %s" % MODEL)
		return
	_model = packed.instantiate()
	_model.name = "Model"
	add_child(_model)


func _skin() -> void:
	if _model == null:
		return
	var spec:= _load_spec()
	if spec.is_empty():
		push_warning("DeliveryBoard: no material table at %s, the board will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
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
				continue
			mi.set_surface_override_material(i, built [key])


static func _load_spec() -> Dictionary:
	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		return res.data
	if not FileAccess.file_exists(SPEC):
		return { }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


static func board_to_local(p: Vector3) -> Vector3:
	var c:= cos(deg_to_rad(- LEAN))
	var s:= sin(deg_to_rad(- LEAN))
	var by:= p.y * c - p.z * s
	var bz:= p.y * s + p.z * c
	return Vector3(p.x, bz, - by)


func _build_docket() -> void:
	_face = Node3D.new()
	_face.name = "Docket"
	_face.position = board_to_local(Vector3(SHEET_AT.x, SHEET_Y, SHEET_AT.y))
	_face.rotation.x = deg_to_rad(- LEAN)
	add_child(_face)


	_docket_rim = _rim("DocketPick", SHEET_HALF)
	_docket_rim_mat = _docket_rim.material_override
	_face.add_child(_docket_rim)

	var paper:= MeshInstance3D.new()
	paper.name = "Sheet"
	var quad:= QuadMesh.new()
	quad.size = SHEET_HALF * 2.0
	paper.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_PAPER
	mat.roughness = 0.92
	mat.metallic = 0.0
	paper.material_override = mat
	_face.add_child(paper)


	_title = _print("Title", H_TITLE, COL_INK, SHEET_HALF.y - 0.045, true)
	_state = _print("State", H_SMALL, COL_RED, SHEET_HALF.y - 0.088, true)
	_count = _print("Count", H_COUNT, COL_INK, 0.055, true)


	_wanted = Sprite3D.new()
	_wanted.name = "Wanted"
	_wanted.position = Vector3(WANTED_X, 0.055, INK_OUT)
	_wanted.shaded = true
	_wanted.double_sided = false
	_wanted.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_wanted.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wanted.visible = false
	_face.add_child(_wanted)
	_body = _print("Body", H_BODY, COL_INK, -0.045, false)
	_reward = _print("Reward", H_SMALL, COL_RED, - SHEET_HALF.y + 0.052, false)


func _print(node_name: String, cap: float, colour: Color, at_y: float,
		heavy: bool, onto: Node3D = null, half_w: float = SHEET_HALF.x) -> Label3D:
	var l:= Label3D.new()
	l.name = node_name
	l.pixel_size = PIXEL
	l.font_size = int(round(cap / PIXEL))
	l.outline_size = 0
	l.modulate = colour
	l.width = (half_w * 2.0 - 0.024) / PIXEL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector3(0.0, at_y, INK_OUT)


	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.shaded = true
	l.double_sided = false
	l.no_depth_test = false
	l.font = UiFont.bold() if heavy else UiFont.regular()
	var host: Node3D = _face if onto == null else onto
	host.add_child(l)
	return l


func _rim(node_name: String, half: Vector2) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.name = node_name
	var quad:= QuadMesh.new()
	quad.size = (half + Vector2(OUTLINE_W, OUTLINE_W)) * 2.0
	mi.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_PICKED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 0.0, - OUTLINE_BACK)
	mi.visible = false
	return mi


func _build_note() -> void:
	_note = Node3D.new()
	_note.name = "OrderNote"
	_note.position = board_to_local(Vector3(NOTE_AT.x, SHEET_Y, NOTE_AT.y))
	_note.rotation.x = deg_to_rad(- LEAN)
	add_child(_note)


	var spun:= Node3D.new()
	spun.name = "Spin"
	spun.rotation.z = deg_to_rad(NOTE_SPIN)
	_note.add_child(spun)

	_outline = _rim("Offer", NOTE_HALF)
	_outline_mat = _outline.material_override
	spun.add_child(_outline)

	var paper:= MeshInstance3D.new()
	paper.name = "Sheet"
	var quad:= QuadMesh.new()
	quad.size = NOTE_HALF * 2.0
	paper.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_NOTE_PAPER
	mat.roughness = 0.92
	mat.metallic = 0.0
	paper.material_override = mat
	spun.add_child(paper)


	_note_title = _print("NoteTitle", H_NOTE_TITLE, COL_INK,
		NOTE_HALF.y - 0.05, true, spun, NOTE_HALF.x)
	_note_gate = _print("NoteGate", H_NOTE_LINE, COL_INK,
		0.048, false, spun, NOTE_HALF.x)
	_note_detail = _print("NoteDetail", H_NOTE_LINE, COL_INK,
		-0.004, false, spun, NOTE_HALF.x)
	_note_foot = _print("NoteFoot", H_NOTE_FOOT, COL_RED,
		- NOTE_HALF.y + 0.048, true, spun, NOTE_HALF.x)
	_note_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_write(_note_title, tr("NEXT LOAD"))


func _build_chit() -> void:
	_chit = Node3D.new()
	_chit.name = "NeedleChit"
	_chit.position = board_to_local(Vector3(CHIT_AT.x, SHEET_Y, CHIT_AT.y))
	_chit.rotation.x = deg_to_rad(- LEAN)
	add_child(_chit)

	var spun:= Node3D.new()
	spun.name = "Spin"
	spun.rotation.z = deg_to_rad(CHIT_SPIN)
	_chit.add_child(spun)

	_chit_rim = _rim("Pick", CHIT_HALF)
	_chit_rim_mat = _chit_rim.material_override
	spun.add_child(_chit_rim)

	var paper:= MeshInstance3D.new()
	paper.name = "Sheet"
	var quad:= QuadMesh.new()
	quad.size = CHIT_HALF * 2.0
	paper.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_PAPER
	mat.roughness = 0.92
	mat.metallic = 0.0
	paper.material_override = mat
	spun.add_child(paper)


	_chit_title = _print("ChitTitle", H_CHIT_TITLE, COL_INK,
		CHIT_HALF.y - 0.03, true, spun, CHIT_HALF.x)
	_chit_count = _print("ChitCount", H_CHIT_COUNT, COL_INK,
		0.004, true, spun, CHIT_HALF.x)


	_chit_gloss = _print("ChitGloss", H_CHIT_LINE, COL_INK,
		-0.03, false, spun, CHIT_HALF.x)
	_chit_loose = _print("ChitLoose", H_CHIT_LINE, COL_RED,
		- CHIT_HALF.y + 0.032, false, spun, CHIT_HALF.x)
	_chit_loose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_write(_chit_title, tr("NEEDLES"))
	_write(_chit_gloss, tr("IN THE CASE FROM THIS LOAD"))


func _build_tally() -> void:
	var strip:= Node3D.new()
	strip.name = "Tally"
	strip.position = board_to_local(Vector3(TALLY_AT.x, SHEET_Y, TALLY_AT.y))
	strip.rotation.x = deg_to_rad(- LEAN)
	add_child(strip)


	var spun:= Node3D.new()
	spun.name = "Spin"
	spun.rotation.z = deg_to_rad(TALLY_SPIN)
	strip.add_child(spun)

	var paper:= MeshInstance3D.new()
	paper.name = "Sheet"
	var quad:= QuadMesh.new()
	quad.size = TALLY_HALF * 2.0
	paper.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_PAPER
	mat.roughness = 0.92
	mat.metallic = 0.0
	paper.material_override = mat
	spun.add_child(paper)


	_tally = _print("TallyLine", H_TALLY, COL_INK, 0.0, true, spun, TALLY_HALF.x)


func _build_clearance() -> void:
	_clear = Node3D.new()
	_clear.name = "ClearanceCard"
	_clear.position = board_to_local(Vector3(CLEAR_AT.x, SHEET_Y, CLEAR_AT.y))
	_clear.rotation.x = deg_to_rad(- LEAN)
	add_child(_clear)

	var spun:= Node3D.new()
	spun.name = "Spin"
	spun.rotation.z = deg_to_rad(CLEAR_SPIN)
	_clear.add_child(spun)

	_clear_rim = _rim("Pick", CLEAR_HALF)
	spun.add_child(_clear_rim)

	var card:= MeshInstance3D.new()
	card.name = "Sheet"
	var quad:= QuadMesh.new()
	quad.size = CLEAR_HALF * 2.0
	card.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_CLEAR_CARD
	mat.roughness = 0.78
	mat.metallic = 0.0
	card.material_override = mat
	spun.add_child(card)

	_paint(_print("ClearanceHead", H_CLEAR_HEAD, COL_CLEAR_HEAD,
		CLEAR_HEAD_Y, true, spun, CLEAR_HALF.x), tr(CLEAR_HEAD_TEXT))
	_paint(_print("ClearanceUnder", H_CLEAR_UNDER, COL_CLEAR_UNDER,
		CLEAR_UNDER_Y, true, spun, CLEAR_HALF.x), tr(CLEAR_UNDER_TEXT))


static func _paint(l: Label3D, text: String) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var room:= l.width * l.pixel_size
	l.text = text
	var wide:= l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER,
		-1.0, l.font_size).x
	if wide > 0.0:
		l.pixel_size = minf(l.pixel_size, room / wide)


func _refresh_note() -> void:
	if _note == null:
		return
	var pool:= NeedleTypes.pool(GameState.lot_tier)
	var need:= pool.size()
	var missing:= GameState.lot_missing().size()
	var have:= need - missing
	var ready:= can_order()


	var over:= GameState.demo_is_over()
	_write(_note_gate, tr("%s %d of %d needle kinds in the case")
		% ["[X]" if ready or over else "[  ]", have, need])


	_write(_tally, tr("HAY LEFT   %s") % Hud.hay_left_amount())


	var fee:= GameState.next_stack_fee()
	if over:
		_write(_note_detail, tr("The demo ends here"))
	else:
		_write(_note_detail, tr("Pay now: $%s") % Hud.money_text(fee) if fee > 0.0
			else tr("This load is free"))


	var key:= InputSetup.hint("interact")
	if over:
		_write(_note_foot, tr("NEXT LOAD IN THE FULL GAME"))
	elif ready:
		_write(_note_foot, tr("READY  ·  PRESS %s") % key)
	else:
		_write(_note_foot, tr("PRESS %s TO SEE WHAT IT NEEDS") % key)
	_note_foot.modulate = COL_RED if ready else COL_INK

	_refresh_chit()


func _refresh_chit() -> void:
	if _chit == null:
		return
	_write(_chit_count, "%d / ?" % GameState.pile_needles_found)
	var loose:= 0
	if live != null:
		loose = live.loose_undiscovered_types().size()
	if loose <= 0:
		_write(_chit_loose, "")
	else:


		_write(_chit_loose, tr_n("%d STILL NEEDED, IN THE YARD",
			"%d STILL NEEDED, IN THE YARD", loose) % loose)


func _process(delta: float) -> void:
	_note_clock += delta
	if _note_clock >= NOTE_TICK:
		_note_clock = 0.0
		_refresh_note()
	_drive_outline(delta)


func _drive_outline(delta: float) -> void:
	if _outline == null:
		return
	var picked:= ""
	if player != null:
		picked = hovered_sheet(player.eye_position(), player.look_direction())

	if _docket_rim != null:
		_docket_rim.visible = picked == "contract"
		_docket_rim_mat.albedo_color = COL_PICKED

	if _chit_rim != null:
		_chit_rim.visible = picked == "chit"
		_chit_rim_mat.albedo_color = COL_PICKED

	if _clear_rim != null:
		_clear_rim.visible = picked == "clearance"

	if picked == "note":
		_outline.visible = true
		_outline_mat.albedo_color = COL_PICKED
		return
	var offering:= can_order()
	_outline.visible = offering
	if not offering:
		_pulse = 0.0
		return
	_pulse = fmod(_pulse + delta, OUTLINE_PULSE)
	var breath:= 0.5 - 0.5 * cos(TAU * _pulse / OUTLINE_PULSE)
	_outline_mat.albedo_color = Color(COL_OUTLINE.r, COL_OUTLINE.g,
		COL_OUTLINE.b, lerpf(OUTLINE_A_LOW, OUTLINE_A_HIGH, breath))


func can_order() -> bool:
	return GameState.may_order_pile()


func note_point() -> Vector3:
	return _note.global_position if _note != null else global_position


func docket_point() -> Vector3:
	return _face.global_position if _face != null else global_position


func chit_point() -> Vector3:
	return _chit.global_position if _chit != null else global_position


func clearance_point() -> Vector3:
	return _clear.global_position if _clear != null else global_position


func hovered_sheet(eye: Vector3, look: Vector3) -> String:
	var best:= ""
	var best_d:= ORDER_DISTANCE
	var dir:= look.normalized()


	if _face != null and _face.visible:
		var d:= _sheet_hit(eye, dir, _face)
		if d >= 0.0 and d <= best_d:
			best_d = d
			best = "contract"
	if _note != null:
		var d:= _sheet_hit(eye, dir, _note)
		if d >= 0.0 and d <= best_d:
			best_d = d
			best = "note"
	if _chit != null:
		var d:= _sheet_hit(eye, dir, _chit)
		if d >= 0.0 and d <= best_d:
			best_d = d
			best = "chit"
	if _clear != null:
		var d:= _sheet_hit(eye, dir, _clear)
		if d >= 0.0 and d <= best_d:
			best_d = d
			best = "clearance"
	return best


func _sheet_hit(eye: Vector3, dir: Vector3, holder: Node3D) -> float:
	var paper:= holder.get_node_or_null("Sheet") as MeshInstance3D
	if paper == null:
		paper = holder.get_node_or_null("Spin/Sheet") as MeshInstance3D
	if paper == null or not (paper.mesh is QuadMesh):
		return -1.0
	var half:= (paper.mesh as QuadMesh).size * 0.5 + Vector2(OUTLINE_W, OUTLINE_W)
	var from:= paper.to_local(eye)
	var along:= paper.to_local(eye + dir) - from


	if along.z > -0.0001:
		return -1.0
	var t:= - from.z / along.z
	if t <= 0.0:
		return -1.0
	var hit:= from + along * t
	if absf(hit.x) > half.x or absf(hit.y) > half.y:
		return -1.0
	return eye.distance_to(paper.to_global(hit))


func is_hovered(eye: Vector3, look: Vector3) -> bool:
	return can_order() and hovered_sheet(eye, look) == "note"


func take_press(eye: Vector3, look: Vector3) -> bool:
	match hovered_sheet(eye, look):
		"contract":
			GameState.contract_pinned = not GameState.contract_pinned
			GameState.contract_pin_changed.emit(GameState.contract_pinned)
			Audio.play("ui_select", -6.0)
			return true
		"chit":


			chit_pressed.emit()
			Audio.play("ui_open", -6.0)
			return true
		"note":


			note_pressed.emit()
			Audio.play("ui_open", -6.0)
			return true
		"clearance":
			clearance_pressed.emit()
			Audio.play("ui_select", -6.0)
			return true
	return false


static func _write(l: Label3D, text: String) -> void:
	if l != null and l.text != text:
		l.text = text


func _seat() -> void:
	if door == null:
		return
	var at:= door.to_global(Vector3(SEAT_ACROSS, 0.0, SEAT_IN))
	at.y = warehouse.floor_y(at) if warehouse != null else 0.0
	global_position = at


	rotation.y = door.rotation.y


static func face_normal() -> Vector3:
	return board_to_local(Vector3(0.0, -1.0, 0.0))


func face_point() -> Vector3:
	return _face.global_position if _face != null else global_position


func show_contract(index: int, have: int, need: int, state_line: String) -> void:
	var c:= DeliveryBook.contract(index)
	if c.is_empty():
		show_finished()
		return
	_face.visible = true


	_write(_title, DeliveryBook.title_of(index))
	_write(_state, state_line)
	_write(_count, "%d / %d" % [have, need])


	var pic:= TechPanel.icon_for(str(c.get("want", "")))
	if _wanted.texture != pic:
		_wanted.texture = pic
		if pic != null:
			_wanted.pixel_size = WANTED_SIDE / float(pic.get_width())
	_wanted.visible = pic != null
	_write(_body, DeliveryBook.detail_of(index))
	var tech:= DeliveryBook.reward_tech(index)
	var pay:= float(c.get("pay", 0.0))


	if tech.is_empty():
		_write(_reward, tr("PAYS $%s") % Hud.money_text(pay))
	else:
		_write(_reward, tr("PAYS $%s\nRELEASES %s") % [Hud.money_text(pay),
			TechTree.display_name(tech)])


func show_finished() -> void:
	if _face == null:
		return
	_face.visible = true
	var n:= DeliveryBook.count()
	_write(_title, tr("No orders left"))
	_write(_state, tr("ALL FILLED"))
	_write(_count, "%d / %d" % [n, n])


	_wanted.visible = false
	_write(_body, tr("You have filled every order. Keep selling what you make at the stand."))
	_write(_reward, "")


func _hide_docket() -> void:
	if _face != null:
		_face.visible = false


func docket_visible() -> bool:
	return _face != null and _face.visible
