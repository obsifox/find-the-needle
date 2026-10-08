class_name MapMenu
extends Control


const CARD_W:= 316.0


const CARD_IMAGE_H:= 178.0
const CARD_COLUMNS:= 3

const CARD_BLURB_H:= 56.0
const CARD_LOCK:= Vector2(38.0, 46.0)


const COL_INK:= Color(1, 1, 1)

const INK_OUTLINE:= 5


const BG_PANEL:= Color(0, 0, 0, 0.8)
const BG_CARD:= Color(0, 0, 0, 0.45)
const BG_CARD_HERE:= Color(0, 0, 0, 0.72)


const EDGE:= Color(1, 1, 1, 0.85)
const EDGE_CARD:= Color(1, 1, 1, 0.3)
const EDGE_HERE:= Color(1, 1, 1, 0.95)


const SHADE_LOCKED:= Color(0, 0, 0, 0.52)
const SHADE_HERE:= Color(0, 0, 0, 0.3)


const LOCKED_TEXT:= "Not available in Demo"


const UNBUILT_TEXT:= "Not built yet"


const MAPS: Array [Dictionary] = [
	{
		"id": "warehouse",
		"name": "THE WAREHOUSE",
		"blurb": "Your home yard. A huge haystack inside a steel shed.",
		"tag": "HOME",
		"image": "res://assets/ui/maps/warehouse.jpg",
		"scene": "",
		"startable": true,
	},
	{
		"id": "brutalist_plaza",
		"name": "THE PLAZA",
		"blurb": "A huge open concrete hall with no roof.",
		"tag": "SITE 01",
		"image": "res://assets/ui/maps/brutalist_plaza.jpg",
		"scene": "",


	},
	{
		"id": "highlands_castle",
		"name": "HIGHLANDS CASTLE",
		"blurb": "A castle hall filled with hay.",
		"tag": "SITE 02",
		"image": "res://assets/ui/maps/highlands_castle.jpg",
		"scene": "",
	},
	{
		"id": "research_ship",
		"name": "THE RESEARCH SHIP",
		"blurb": "A research ship with hay in its cargo hold.",
		"tag": "SITE 03",
		"image": "res://assets/ui/maps/research_ship.jpg",
		"scene": "",
	},
	{
		"id": "the_deep",
		"name": "THE DEEP",
		"blurb": "A sunken ship on the sea floor, full of hay.",
		"tag": "SITE 04",
		"image": "res://assets/ui/maps/the_deep.jpg",
		"scene": "",
	},
	{
		"id": "orbital_station",
		"name": "ORBITAL STATION",
		"blurb": "A space station with no gravity. Hay floats where you leave it.",
		"tag": "SITE 05",
		"image": "res://assets/ui/maps/orbital_station.jpg",
		"scene": "",
	},
	{
		"id": "much_more",
		"name": "MUCH MORE...",
		"blurb": "More places to come in the full game.",
		"tag": "THE FULL GAME",
		"image": "res://assets/ui/maps/much_more.jpg",
		"scene": "",
	},
]

var player: Player
var door: BayDoor

var _panel: PanelContainer
var _open:= false


class LockIcon:
	extends Control

	var colour:= COL_INK

	func _draw() -> void:
		var w:= size.x
		var h:= size.y
		var shackle_w:= maxf(1.5, w * 0.11)


		draw_arc(Vector2(w * 0.5, h * 0.44), w * 0.25, PI, TAU, 16,
			colour, shackle_w, true)
		draw_rect(Rect2(Vector2(w * 0.14, h * 0.44), Vector2(w * 0.72, h * 0.5)),
			colour, true)


		draw_circle(Vector2(w * 0.5, h * 0.64), w * 0.075, Color(0, 0, 0, 0.9))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:


	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb:= StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = EDGE
	sb.set_border_width_all(1)


	sb.set_corner_radius_all(0)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 22.0
	_panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title:= _label(tr("CHANGE MAP"), 30, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle:= _label(tr("Travel to other sites"), 15)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_hrule())

	var grid:= GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for spec: Dictionary in MAPS:
		grid.add_child(_card(spec))

	box.add_child(_hrule())
	var foot:= _label(_footer_text(), 15)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(foot)


func _footer_text() -> String:
	if Cfg.DEMO:
		return tr("Other sites are in the full game.    E to close")
	return tr("E to close")


func _card(spec: Dictionary) -> Control:
	var here:= _is_here(spec)
	var locked:= not here and not _is_available(spec)

	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb:= StyleBoxFlat.new()


	sb.bg_color = BG_CARD_HERE if here else BG_CARD
	sb.border_color = EDGE_HERE if here else EDGE_CARD
	sb.set_border_width_all(2 if here else 1)
	sb.set_corner_radius_all(0)


	card.add_theme_stylebox_override("panel", sb)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	box.add_child(_card_image(spec, here, locked))

	var pad:= MarginContainer.new()
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 15)
	pad.add_theme_constant_override("margin_top", 11)
	pad.add_theme_constant_override("margin_bottom", 13)
	box.add_child(pad)

	var text:= VBoxContainer.new()
	text.add_theme_constant_override("separation", 5)
	pad.add_child(text)

	text.add_child(_label(_t(str(spec.get("name", ""))), 21, true))

	var blurb:= _label(_t(str(spec.get("blurb", ""))), 14)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


	blurb.custom_minimum_size = Vector2(0, CARD_BLURB_H)
	text.add_child(blurb)

	text.add_child(_card_footer(here, locked))
	return card


func _card_image(spec: Dictionary, here: bool, locked: bool) -> Control:
	var band:= Control.new()
	band.custom_minimum_size = Vector2(CARD_W, CARD_IMAGE_H)
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var path:= str(spec.get("image", ""))
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		push_warning("MapMenu: site '%s' has no picture at %s"
			% [str(spec.get("id", "")), path])
	else:
		var rect:= TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(rect)

	var shade:= ColorRect.new()
	shade.color = SHADE_HERE if here else SHADE_LOCKED
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(shade)


	var tag_pad:= MarginContainer.new()
	tag_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_pad.add_theme_constant_override("margin_left", 13)
	tag_pad.add_theme_constant_override("margin_top", 10)
	var tag:= _label(_t(str(spec.get("tag", ""))), 13, true)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tag_pad.add_child(tag)
	band.add_child(tag_pad)

	if locked:


		var centre:= CenterContainer.new()
		centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lock:= LockIcon.new()
		lock.custom_minimum_size = CARD_LOCK
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(lock)
		band.add_child(centre)
	return band


func _card_footer(here: bool, locked: bool) -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if here:
		row.add_child(_label(tr("YOU ARE HERE"), 15, true))
		return row
	if not locked:
		row.add_child(_label(tr("TRAVEL"), 15, true))
		return row


	row.add_child(_label(tr(LOCKED_TEXT) if Cfg.DEMO else tr(UNBUILT_TEXT), 15, true))
	return row


static func startable_maps() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for spec: Dictionary in MAPS:
		if bool(spec.get("startable", false)):
			out.append(_translated(spec))
	return out


static func display_name(id: String) -> String:
	for spec: Dictionary in MAPS:
		if str(spec.get("id", "")) == id:
			var text:= str(spec.get("name", ""))
			return Cfg.tr(text) if text != "" else id
	return id


static func _translated(spec: Dictionary) -> Dictionary:
	var out:= spec.duplicate()
	for field: String in ["name", "blurb", "tag"]:
		var text:= str(out.get(field, ""))
		if text != "":
			out [field] = Cfg.tr(text)
	return out


static func _is_available(spec: Dictionary) -> bool:
	if Cfg.DEMO:
		return false
	var scene:= str(spec.get("scene", ""))
	return scene != "" and ResourceLoader.exists(scene)


static func _is_here(spec: Dictionary) -> bool:
	return str(spec.get("id", "")) == "warehouse"


func _t(text: String) -> String:
	return text if text == "" else tr(text)


func _label(text: String, size: int, heavy: bool = false) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, COL_INK, INK_OUTLINE, heavy)
	l.text = text
	return l


func _hrule() -> Control:
	var r:= ColorRect.new()
	r.color = Color(1, 1, 1, 0.3)
	r.custom_minimum_size = Vector2(0, 1)
	return r


func is_at_door() -> bool:
	if player == null or door == null:
		return false


	if player.carry != null and player.carry.is_carrying():
		return false
	return door.is_hovered(player.eye_position(), player.look_direction())


func is_open() -> bool:
	return _open


func try_open() -> bool:
	if _open or not is_at_door():
		return false
	set_open(true)
	return true


func set_open(on: bool) -> void:
	if on and not is_at_door():
		return
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		set_open(false)
		get_viewport().set_input_as_handled()
