class_name ZoneCard
extends Control


const PANEL_W:= 300.0
const MARGIN:= 22.0


const TOP:= 340.0


const LEAN:= 1.1


const TICK:= 0.5
const MAX_ROWS:= 5

const PAPER:= DeliveryBoard.COL_PAPER
const PAPER_EDGE:= Color(0.541, 0.478, 0.376)
const INK:= DeliveryBoard.COL_INK
const INK_DIM:= Color(0.404, 0.353, 0.286)
const RED:= DeliveryBoard.COL_RED
const CLEAR:= Color(0.157, 0.4, 0.157)

var zone: LandingZone

var _panel: PanelContainer
var _status: Label
var _rows: Label
var _clock:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	Cfg.no_hud_changed.connect(_on_no_hud)
	Cfg.hud_style_changed.connect(_apply_hud_scale)
	if zone != null:
		zone.shown_changed.connect(_on_shown)
	_apply_hud_scale()
	_apply()


func _on_shown(_on: bool) -> void:
	_apply()


func _on_no_hud(_on: bool) -> void:
	_apply()


func _apply() -> void:
	visible = zone != null and zone.is_shown() and not Cfg.no_hud
	if visible:
		_clock = 0.0
		refresh()


func _apply_hud_scale() -> void:
	scale = Vector2.ONE * clampf(Cfg.hud_scale, Cfg.HUD_SCALE_MIN, Cfg.HUD_SCALE_MAX)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(- (MARGIN + PANEL_W), TOP)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.pivot_offset = Vector2(PANEL_W * 0.5, 6.0)
	_panel.rotation = deg_to_rad(LEAN)

	var sheet:= StyleBoxFlat.new()
	sheet.bg_color = PAPER
	sheet.border_color = PAPER_EDGE
	sheet.set_border_width_all(1)
	sheet.set_corner_radius_all(0)
	sheet.content_margin_left = 16.0
	sheet.content_margin_right = 16.0
	sheet.content_margin_top = 14.0
	sheet.content_margin_bottom = 14.0
	sheet.shadow_color = Color(0, 0, 0, 0.42)
	sheet.shadow_size = 7
	sheet.shadow_offset = Vector2(-3, 5)
	_panel.add_theme_stylebox_override("panel", sheet)
	add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	box.add_child(_label(tr("NEXT LOAD"), 12, INK_DIM, true))
	box.add_child(_label(tr("LANDING ZONE"), 20, INK, true))

	_status = _label("", 14, RED, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	_rows = _label("", 14, INK, false)
	box.add_child(_rows)

	var foot:= _label(tr("Hide the wall from the note on the board"), 12, INK_DIM, false)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(foot)


func _label(text: String, size: int, colour: Color, heavy: bool) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 0, heavy)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if _clock < TICK:
		return
	_clock = 0.0
	refresh()


func refresh() -> void:
	if zone == null:
		return
	var list:= zone.summary()
	var total:= 0
	for row: Dictionary in list:
		total += int(row ["count"])
	if total == 0:
		_write(_status, tr("All clear. Go back to the board and order the load."))
		_status.add_theme_color_override("font_color", CLEAR)
	else:
		_write(_status, tr_n("%d thing is still in the way", "%d things are still in the way",
			total) % total)
		_status.add_theme_color_override("font_color", RED)

	var lines:= PackedStringArray()
	for k in mini(list.size(), MAX_ROWS):
		lines.append("%s  x%d" % [str(list [k] ["name"]), int(list [k] ["count"])])
	if list.size() > MAX_ROWS:
		var rest:= list.size() - MAX_ROWS
		lines.append(tr_n("and %d more kind", "and %d more kinds", rest) % rest)
	_write(_rows, "\n".join(lines))
	_rows.visible = total > 0


static func _write(l: Label, text: String) -> void:
	if l != null and l.text != text:
		l.text = text
