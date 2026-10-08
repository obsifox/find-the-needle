class_name SellAllDialog
extends Control


signal confirmed()

const PANEL_W:= 640.0


const COL_PAPER:= Color(0.92, 0.89, 0.8)
const COL_INK:= Color(0.13, 0.12, 0.11)
const COL_RED:= Color(0.55, 0.13, 0.09)

const COL_FADE:= Color(0.13, 0.12, 0.11, 0.55)


const COL_RULE:= Color(0.13, 0.12, 0.11, 0.22)


const STAMP_TILT:= -4.0

var player: Player

var _open:= false
var _panel: PanelContainer
var _rows: VBoxContainer
var _total: Label
var _kept: Label
var _go: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return _open


func open(tally: Dictionary) -> void:
	_fill(tally)
	set_open(true)


func set_open(on: bool) -> void:
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
	if event.is_action_pressed("interact") or event.is_action_pressed("secondary") or event.is_action_pressed("free_mouse"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim:= ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = - PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5


	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_PAPER
	sb.border_color = COL_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)


	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(7, 9)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)


	box.add_child(_label(tr("SELLING STAND"), 13, COL_FADE))

	box.add_child(_label(tr("CLEARANCE SALE"), 34, COL_INK, true))
	box.add_child(_rule(2, COL_INK))


	var blurb:= _label(tr("Everything you built is taken down and sold.\nEverything lying around is sold too."), 16, COL_INK)
	box.add_child(blurb)

	box.add_child(_stamp())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	box.add_child(_rows)

	box.add_child(_rule(2, COL_INK))
	var total_line:= HBoxContainer.new()
	box.add_child(total_line)
	var total_label:= _label(tr("YOU GET"), 20, COL_INK, true)
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_line.add_child(total_label)
	_total = _mono("", 20, COL_INK, true)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_line.add_child(_total)

	var stays:= _label(tr("You keep your money, needles, the pile and loose hay."), 14, COL_FADE)
	stays.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stays)

	_kept = _label("", 14, COL_RED)
	_kept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_kept)


	var gap:= Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)


	var buttons:= HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 0)
	box.add_child(buttons)

	var no:= _button(tr("CANCEL"), COL_PAPER, COL_INK)
	no.pressed.connect(func() -> void: set_open(false))
	buttons.add_child(no)

	var spacer:= Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(spacer)

	_go = _button(tr("SELL EVERYTHING"), COL_RED, COL_PAPER)
	_go.pressed.connect(_on_sell)
	buttons.add_child(_go)


func _stamp() -> Control:
	var holder:= Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE


	holder.custom_minimum_size = Vector2(0, 58)

	var stamp:= PanelContainer.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.13, 0.09, 0.09)
	sb.border_color = COL_RED
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 5.0
	stamp.add_theme_stylebox_override("panel", sb)
	stamp.add_child(_label(tr("THIS CANNOT BE UNDONE"), 19, COL_RED, true))
	holder.add_child(stamp)


	var place:= func() -> void:
		stamp.size = stamp.get_combined_minimum_size()
		stamp.position = (holder.size - stamp.size) * 0.5
		stamp.pivot_offset = stamp.size * 0.5
		stamp.rotation = deg_to_rad(STAMP_TILT)
	holder.resized.connect(place)
	place.call()
	return holder


func _button(text: String, bg: Color, fg: Color) -> Button:
	var b:= Button.new()
	b.text = text


	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(206, 44)
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 17)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		b.add_theme_color_override(colour, fg)
	b.add_theme_color_override("font_disabled_color", COL_FADE)
	b.add_theme_constant_override("outline_size", 0)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box:= StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = COL_INK
		box.set_border_width_all(2)
		box.set_corner_radius_all(0)
		if state == "hover":


			box.bg_color = bg.darkened(0.14)
		if state == "pressed":


			box.bg_color = bg.darkened(0.22)
			box.border_width_top = 5
			box.border_width_left = 5
		if state == "disabled":
			box.bg_color = COL_PAPER
			box.border_color = COL_FADE
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 10.0
		box.content_margin_bottom = 10.0
		b.add_theme_stylebox_override(state, box)
	return b


func _on_sell() -> void:


	set_open(false)
	confirmed.emit()


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(l, size, colour, 0, heavy)
	return l


func _mono(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= _label(text, size, colour, heavy)
	l.add_theme_font_override("font", UiFont.mono())
	return l


func _rule(thick: int, colour: Color) -> ColorRect:
	var r:= ColorRect.new()
	r.color = colour
	r.custom_minimum_size = Vector2(0, thick)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _fill(tally: Dictionary) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row(tr("belts and machines"), int(tally.get("machines", 0)),
		float(tally.get("machines_value", 0.0)))
	_row(tr("decks, stairs and railings"), int(tally.get("structures", 0)),
		float(tally.get("structures_value", 0.0)))
	_row(tr("tools lying in the yard"), int(tally.get("tools", 0)),
		float(tally.get("tools_value", 0.0)))
	var total:= float(tally.get("total", 0.0))
	_total.text = "$%s" % Hud.money_text(total)

	var kept: PackedStringArray = tally.get("kept", PackedStringArray())


	_kept.text = tr("NOT SOLD\n%s") % "\n".join(kept) if kept.size() > 0 else ""
	_kept.visible = _kept.text != ""


	var empty:= int(tally.get("machines", 0)) + int(tally.get("structures", 0)) + int(tally.get("tools", 0)) == 0
	_go.disabled = empty
	_go.text = tr("NOTHING TO SELL") if empty else tr("SELL EVERYTHING")


func _row(what: String, count: int, value: float) -> void:
	var ink:= COL_INK if count > 0 else COL_FADE
	var line:= HBoxContainer.new()
	var name_label:= _label(what, 16, ink)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0, 30)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	var count_label:= _mono(str(count), 16, ink)
	count_label.custom_minimum_size = Vector2(70, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(count_label)
	var money:= _mono("$%s" % Hud.money_text(value), 16, ink)
	money.custom_minimum_size = Vector2(130, 0)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(money)
	_rows.add_child(line)


	_rows.add_child(_rule(1, COL_RULE))
