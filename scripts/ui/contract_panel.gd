class_name ContractPanel
extends Control


const PANEL_W:= 300.0
const MARGIN:= 22.0


const TOP:= 168.0


const LEAN:= -1.4


const DONE_HOLD:= 3.2


const UNPIN_AFTER:= 10.0


const PAPER:= DeliveryBoard.COL_PAPER
const PAPER_EDGE:= Color(0.541, 0.478, 0.376)
const INK:= DeliveryBoard.COL_INK
const INK_DIM:= Color(0.404, 0.353, 0.286)
const INK_RULE:= Color(0.541, 0.478, 0.376, 0.55)
const RED:= DeliveryBoard.COL_RED
const DONE:= Color(0.157, 0.4, 0.157)
const PIN:= Color(0.706, 0.18, 0.145)

var _panel: PanelContainer
var _pin: Panel
var _eyebrow: Label
var _title: Label
var _bar_back: Panel
var _bar_fill: Panel
var _fill_box: StyleBoxFlat
var _count: Label
var _state: Label

var _hold:= 0.0


var _unpin_in:= 0.0


const FINISHED:= -2
var _shown:= -1


var _have:= false

var _muted:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	Cfg.no_hud_changed.connect(_set_plate)
	Cfg.hud_style_changed.connect(_apply_hud_scale)


	GameState.contract_pin_changed.connect(_on_pin_changed)
	_apply_hud_scale()
	_set_plate()


func _on_pin_changed(_pinned: bool) -> void:


	_unpin_in = 0.0
	_apply()


func _apply() -> void:
	visible = _have and GameState.contract_pinned and not _muted


func set_suppressed(on: bool) -> void:
	_muted = on
	_apply()


func _set_plate(_on: bool = false) -> void:
	_panel.visible = not Cfg.no_hud
	_pin.visible = _panel.visible


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
	_aa_box(sheet)
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

	_eyebrow = _label("", 12, INK_DIM, true)
	box.add_child(_eyebrow)

	_title = _label("", 20, INK, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	box.add_child(_rule())

	_count = _label("", 15, INK, true)
	box.add_child(_count)


	_bar_back = Panel.new()
	_bar_back.add_theme_stylebox_override("panel", _aa_box(StyleBoxFlat.new(), Color(0.353, 0.31, 0.251, 0.35)))
	_bar_back.custom_minimum_size = Vector2(0, 5)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill = Panel.new()
	_fill_box = _aa_box(StyleBoxFlat.new(), INK)
	_bar_fill.add_theme_stylebox_override("panel", _fill_box)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_bottom = 1.0
	_bar_fill.offset_left = 0.0
	_bar_fill.offset_top = 0.0
	_bar_fill.offset_right = 0.0
	_bar_fill.offset_bottom = 0.0
	_bar_back.add_child(_bar_fill)
	box.add_child(_bar_back)


	_state = _label("", 12, RED, true)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_state)


	_pin = Panel.new()
	_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_pin.size = Vector2(11, 11)
	_pin.position = Vector2(- (MARGIN + PANEL_W * 0.5) - 5.5, TOP + 1.0)
	var head:= StyleBoxFlat.new()
	head.bg_color = PIN
	_aa_box(head)
	head.border_color = Color(0.361, 0.078, 0.063)
	head.set_border_width_all(1)
	head.shadow_color = Color(0, 0, 0, 0.45)
	head.shadow_size = 4
	head.shadow_offset = Vector2(0, 2)
	_pin.add_theme_stylebox_override("panel", head)
	add_child(_pin)


func _label(text: String, size: int, colour: Color, heavy: bool) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 0, heavy)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rule() -> Control:
	var r:= Panel.new()
	r.add_theme_stylebox_override("panel", _aa_box(StyleBoxFlat.new(), INK_RULE))
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _aa_box(box: StyleBoxFlat, colour: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	if colour.a > 0.0:
		box.bg_color = colour
	box.set_corner_radius_all(1)
	box.anti_aliasing = true
	return box


func show_contract(index: int, have: int, need: int, state_line: String) -> void:
	if _hold > 0.0:
		return
	var c:= DeliveryBook.contract(index)
	if c.is_empty():
		show_finished()
		return
	if index != _shown:
		_shown = index
		_eyebrow.text = tr("CONTRACT %d OF %d") % [index + 1, DeliveryBook.count()]


		_title.text = DeliveryBook.title_of(index)
		_title.add_theme_color_override("font_color", INK)


	_write(_count, DeliveryBook.count_text(index, have, need))
	_write(_state, state_line)
	_bar_fill.anchor_right = clampf(float(have) / maxf(float(need), 1.0), 0.0, 1.0)
	_have = true
	_apply()


func mark_complete(_title_text: String) -> void:


	if not _have:
		return
	_write(_state, tr("SIGNED OFF"))
	_state.add_theme_color_override("font_color", DONE)
	_title.add_theme_color_override("font_color", DONE)
	_fill_box.bg_color = DONE
	_hold = DONE_HOLD
	if visible:
		Audio.play("ui_select", -6.0)


func show_finished() -> void:
	if _hold > 0.0:
		return
	if _shown != FINISHED:
		_shown = FINISHED
		_eyebrow.text = tr("DELIVERIES")
		_title.text = tr("No orders left")
		_title.add_theme_color_override("font_color", DONE)
		_state.add_theme_color_override("font_color", DONE)
		_fill_box.bg_color = DONE
		if GameState.contract_pinned:
			_unpin_in = UNPIN_AFTER
	var n:= DeliveryBook.count()


	_write(_count, "%d / %d" % [n, n])
	_write(_state, tr("ALL FILLED"))
	_bar_fill.anchor_right = 1.0
	_have = true
	_apply()


static func _write(l: Label, text: String) -> void:
	if l.text != text:
		l.text = text


func _process(delta: float) -> void:
	if _unpin_in > 0.0:
		_unpin_in = maxf(0.0, _unpin_in - delta)
		if _unpin_in <= 0.0 and GameState.contract_pinned:
			GameState.contract_pinned = false
			GameState.contract_pin_changed.emit(false)
	if _hold <= 0.0:
		return
	_hold = maxf(0.0, _hold - delta)
	if _hold <= 0.0:


		_shown = -1
		_fill_box.bg_color = INK
		_bar_fill.anchor_right = 0.0
		_state.add_theme_color_override("font_color", RED)
