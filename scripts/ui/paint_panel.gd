class_name PaintPanel
extends Control


const PANEL_W:= 620.0


const COL_PAPER:= Color(0.92, 0.89, 0.8)
const COL_INK:= Color(0.13, 0.12, 0.11)
const COL_RED:= Color(0.55, 0.13, 0.09)
const COL_FADE:= Color(0.13, 0.12, 0.11, 0.55)


const COL_RULE:= Color(0.13, 0.12, 0.11, 0.22)


const TOOL_NAMES:= ["PEN", "LINE", "BOX", "OVAL", "RUBBER"]


const ROTATE_NAMES:= ["NEVER", "1 MIN", "5 MIN", "10 MIN"]

const THUMB:= Vector2(150.0, 113.0)
const SWATCH:= 30.0
const TAB_H:= 30.0

var player: Player

var _board: PaintBoard
var _open:= false
var _panel: PanelContainer
var _title: Label
var _tab_buttons: Array [Button] = []
var _pages: Array [Control] = []
var _page:= 0
var _tool_buttons: Array [Button] = []
var _size_buttons: Array [Button] = []
var _swatch_buttons: Array [Button] = []
var _rotate_buttons: Array [Button] = []
var _picker: ColorPickerButton
var _keep_button: Button
var _status: Label
var _gallery: GridContainer

var _arming:= -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_open() -> bool:
	return _open


func board() -> PaintBoard:
	return _board


func open(from: PaintBoard) -> void:
	if from == null:
		return
	_board = from


	_picker.color = from.ink
	show_tab(0)
	_set_open(true)


func close() -> void:
	_set_open(false)


func show_tab(i: int) -> void:
	_page = clampi(i, 0, _pages.size() - 1)
	for n in _pages.size():
		_pages [n].visible = n == _page
	_refresh()


func _set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	Audio.play("ui_open" if on else "ui_close", -4.0)
	if on:
		_fill_gallery()
		_refresh()
	else:
		_arming = -1
		_board = null


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_tool(i: int) -> void:
	if is_instance_valid(_board):
		_board.tool = i as PaintBoard.Tool
	Audio.play("ui_click", -8.0)
	_refresh()


func _on_size(i: int) -> void:
	if is_instance_valid(_board):
		_board.width_step = i
	Audio.play("ui_click", -8.0)
	_refresh()


func _on_ink(c: Color) -> void:
	if is_instance_valid(_board):
		_board.ink = c


	_refresh()


func _on_swatch(i: int) -> void:
	_picker.color = PaintBoard.SWATCHES [i]
	Audio.play("ui_click", -8.0)
	_on_ink(PaintBoard.SWATCHES [i])


func _on_rotate(i: int) -> void:
	if is_instance_valid(_board):
		_board.rotate_secs = PaintBoard.ROTATE_CHOICES [i]
	Audio.play("ui_click", -8.0)
	_refresh()


func _on_clear() -> void:
	if is_instance_valid(_board):
		_board.clear()
	_refresh()


func _on_keep() -> void:
	if not is_instance_valid(_board):
		return
	if not _board.keep():
		_status.text = tr("There is nothing on the board to keep.")
		return
	Audio.play("ui_click", -4.0)
	_fill_gallery()
	_refresh()


func _on_show(i: int) -> void:
	if is_instance_valid(_board):
		_board.show_kept(i)
	_arming = -1
	_fill_gallery()
	_refresh()


func _on_forget(i: int) -> void:
	if _arming != i:
		_arming = i
		_fill_gallery()
		return
	var was:= _board.showing if is_instance_valid(_board) else -1
	Sketchbook.forget(i)
	_arming = -1
	if is_instance_valid(_board) and was == i:


		_board.show_kept(mini(i, maxi(Sketchbook.count() - 1, 0)))
	_fill_gallery()
	_refresh()


func _fill_gallery() -> void:
	if _gallery == null:
		return
	for child in _gallery.get_children():
		_gallery.remove_child(child)
		child.queue_free()
	var book:= Sketchbook.all()
	if book.is_empty():
		var empty:= _label(tr("Nothing kept yet. Draw something on the board, then press KEEP THIS on the first page."), 15, COL_FADE)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(PANEL_W - 60.0, 90.0)
		_gallery.add_child(empty)
		return
	for i in book.size():
		_gallery.add_child(_card(i, book [i]))


func _card(i: int, d: Dictionary) -> Control:
	var up:= is_instance_valid(_board) and _board.showing == i and not _board.drafting
	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var thumb:= Thumb.new()
	thumb.strokes = d.get("strokes", [])
	thumb.custom_minimum_size = THUMB
	thumb.up = up
	box.add_child(thumb)


	var name:= _mono(str(d.get("name", "Drawing")), 13, COL_INK)
	name.custom_minimum_size = Vector2(THUMB.x, 0.0)
	name.clip_text = true
	box.add_child(name)
	var mark:= _mono(tr("ON THE BOARD") if up else " ", 11, COL_RED)
	box.add_child(mark)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var show_it:= _button(tr("SHOW"), func() -> void: _on_show(i), 13)
	show_it.custom_minimum_size = Vector2(THUMB.x * 0.56, 24.0)
	row.add_child(show_it)
	var kill:= _button(tr("SURE?") if _arming == i else tr("RUB OUT"),
		func() -> void: _on_forget(i), 13)
	kill.custom_minimum_size = Vector2(THUMB.x * 0.44, 24.0)
	if _arming == i:
		_paint_button(kill, COL_RED, COL_PAPER)
	row.add_child(kill)
	box.add_child(row)
	return box


func _refresh() -> void:
	if _title == null:
		return
	var live:= is_instance_valid(_board)
	_title.text = Cfg.upper(_board.title()) if live else tr("PAINT BOARD")
	for i in _tab_buttons.size():
		_lit(_tab_buttons [i], i == _page)
	for i in _tool_buttons.size():
		_lit(_tool_buttons [i], live and int(_board.tool) == i)
	for i in _size_buttons.size():
		var on:= live and _board.width_step == i
		_lit(_size_buttons [i], on)
		(_size_buttons [i].get_node("Nib") as Nib).set_ink(
			COL_PAPER if on else COL_INK)
	for i in _swatch_buttons.size():
		_lit_swatch(_swatch_buttons [i], i, live
			and _board.ink.is_equal_approx(PaintBoard.SWATCHES [i]))
	for i in _rotate_buttons.size():
		_lit(_rotate_buttons [i], live and _board.rotate_secs
			== PaintBoard.ROTATE_CHOICES [i])
	_keep_button.disabled = not live or _board.strokes.is_empty()
	if not live:
		_status.text = ""
	elif _board.drafting:
		_status.text = tr("Not saved yet. Press KEEP THIS to save it.")
	elif _board.strokes.is_empty():
		_status.text = tr("Shut this, then hold the left button to draw. The right button rubs a line out.")
	else:
		_status.text = tr("A saved drawing. Drawing on it makes a new copy.")


func _build() -> void:
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
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 22.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	_panel.add_child(box)


	var masthead:= HBoxContainer.new()
	masthead.add_theme_constant_override("separation", 12)
	box.add_child(masthead)
	var firm:= _mono(tr("DRAWING TOOLS"), 12, COL_FADE)
	firm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	firm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	masthead.add_child(firm)
	masthead.add_child(PanelClose.make(close, COL_PAPER))
	_title = _label(tr("PAINT BOARD"), 30, COL_INK, true)
	box.add_child(_title)
	box.add_child(_rule(2, COL_INK))

	box.add_child(_tab_strip())

	var tools:= _tools_page()
	var gallery:= _gallery_page()
	_pages = [tools, gallery]
	box.add_child(tools)
	box.add_child(gallery)

	box.add_child(_rule(1, COL_RULE))
	_status = _label("", 14, COL_FADE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_W - 60.0, 0.0)
	box.add_child(_status)
	box.add_child(_mono(tr("%s OR ESC TO CLOSE")
		% Cfg.upper(InputSetup.hint("interact")), 12, COL_FADE))
	show_tab(0)


func _tab_strip() -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for i in 2:
		var b:= _button([tr("TOOLS"), tr("DRAWINGS")] [i],
			func() -> void: show_tab(i), 15)
		b.custom_minimum_size = Vector2(126.0, TAB_H)
		_tab_buttons.append(b)
		row.add_child(b)


	var tail:= Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tail)
	return row


func _tools_page() -> Control:
	var page:= VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)

	page.add_child(_heading(tr("TOOL")))
	var tools:= HBoxContainer.new()
	tools.add_theme_constant_override("separation", 0)
	for i in TOOL_NAMES.size():
		var b:= _button(tr(str(TOOL_NAMES [i])), func() -> void: _on_tool(i), 15)
		b.custom_minimum_size = Vector2(0.0, 32.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tool_buttons.append(b)
		tools.add_child(b)
	page.add_child(tools)


	page.add_child(_heading(tr("NIB")))
	var sizes:= HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 0)
	for i in PaintBoard.WIDTHS.size():
		var b:= _button("", func() -> void: _on_size(i), 15)
		b.custom_minimum_size = Vector2(0.0, 38.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nib:= Nib.new()
		nib.name = "Nib"
		nib.width = PaintBoard.WIDTHS [i]
		nib.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nib)
		_size_buttons.append(b)
		sizes.add_child(b)
	page.add_child(sizes)


	page.add_child(_heading(tr("COLOUR")))
	var inks:= HBoxContainer.new()
	inks.add_theme_constant_override("separation", 0)
	for i in PaintBoard.SWATCHES.size():
		var b:= _button("", func() -> void: _on_swatch(i), 15)
		b.custom_minimum_size = Vector2(SWATCH, SWATCH)
		_swatch_buttons.append(b)
		inks.add_child(b)


	var gap:= Control.new()
	gap.custom_minimum_size = Vector2(10.0, 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inks.add_child(gap)
	_picker = ColorPickerButton.new()
	_picker.custom_minimum_size = Vector2(SWATCH * 1.6, SWATCH)
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.color_changed.connect(_on_ink)
	inks.add_child(_picker)
	var mix:= _mono(tr("  MIX"), 12, COL_FADE)
	mix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inks.add_child(mix)
	page.add_child(inks)

	page.add_child(_heading(tr("SWAP THE PICTURE")))
	var rot:= HBoxContainer.new()
	rot.add_theme_constant_override("separation", 0)
	for i in ROTATE_NAMES.size():
		var b:= _button(tr(str(ROTATE_NAMES [i])), func() -> void: _on_rotate(i), 15)
		b.custom_minimum_size = Vector2(0.0, 30.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rotate_buttons.append(b)
		rot.add_child(b)
	page.add_child(rot)
	page.add_child(_label(tr("Only ever swaps between drawings you have kept, and never while you are part way through one."), 13, COL_FADE))


	var pad:= Control.new()
	pad.custom_minimum_size = Vector2(0.0, 6.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(pad)
	var acts:= HBoxContainer.new()
	acts.add_theme_constant_override("separation", 0)
	_keep_button = _button(tr("KEEP THIS"), _on_keep, 17)
	_keep_button.custom_minimum_size = Vector2(190.0, 40.0)
	_paint_button(_keep_button, COL_INK, COL_PAPER)
	acts.add_child(_keep_button)
	var spacer:= Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acts.add_child(spacer)
	var wipe:= _button(tr("CLEAR THE BOARD"), _on_clear, 17)
	wipe.custom_minimum_size = Vector2(190.0, 40.0)
	_paint_button(wipe, COL_PAPER, COL_RED)
	acts.add_child(wipe)
	page.add_child(acts)
	return page


func _gallery_page() -> Control:
	var page:= VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	page.add_child(_heading(tr("YOUR DRAWINGS")))
	var scroll:= ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PANEL_W - 60.0, 340.0)
	_gallery = GridContainer.new()
	_gallery.columns = 3
	_gallery.add_theme_constant_override("h_separation", 14)
	_gallery.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_gallery)
	page.add_child(scroll)
	return page


func _heading(text: String) -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_mono(text, 12, COL_FADE))
	var line:= _rule(1, COL_RULE)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


func _rule(thick: int, colour: Color) -> ColorRect:
	var r:= ColorRect.new()
	r.color = colour
	r.custom_minimum_size = Vector2(0, thick)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _lit(b: Button, on: bool) -> void:
	_paint_button(b, COL_INK if on else COL_PAPER,
		COL_PAPER if on else COL_INK)


func _lit_swatch(b: Button, i: int, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var chip:= StyleBoxFlat.new()
		chip.bg_color = PaintBoard.SWATCHES [i]
		chip.set_corner_radius_all(0)
		chip.border_color = COL_INK
		chip.set_border_width_all(4 if on else 1)
		if state == "hover" and not on:
			chip.set_border_width_all(2)
		b.add_theme_stylebox_override(state, chip)


func _paint_button(b: Button, bg: Color, fg: Color) -> void:
	for colour: String in ["font_color", "font_hover_color",
			"font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(colour, fg)
	b.add_theme_color_override("font_disabled_color", COL_FADE)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = COL_INK
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(0)
		if state == "hover":
			sb.bg_color = bg.darkened(0.1)
		elif state == "pressed":
			sb.bg_color = bg.darkened(0.18)
			sb.border_width_top = 4
			sb.border_width_left = 4
		elif state == "disabled":
			sb.bg_color = bg.lerp(COL_PAPER, 0.6)
			sb.border_color = COL_RULE
		b.add_theme_stylebox_override(state, sb)


func _button(text: String, on_press: Callable, size: int) -> Button:
	var b:= Button.new()
	b.text = text


	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_constant_override("outline_size", 0)
	_paint_button(b, COL_PAPER, COL_INK)
	b.pressed.connect(on_press)
	return b


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()


	UiFont.style(l, size, colour, 0, heavy)
	l.text = text
	return l


func _mono(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= _label(text, size, colour, heavy)
	l.add_theme_font_override("font", UiFont.mono())
	return l


class Nib:
	extends Control

	var width:= 0.01
	var _ink:= Color(0.13, 0.12, 0.11)

	func set_ink(c: Color) -> void:
		if _ink == c:
			return
		_ink = c
		queue_redraw()

	func _draw() -> void:


		draw_circle(size * 0.5, maxf(1.5, width * size.x * 3.2), _ink)


class Thumb:
	extends Control

	var strokes: Array = []

	var up:= false

	func _draw() -> void:
		var r:= Rect2(Vector2.ZERO, size)
		draw_rect(r, PaintBoard.PaintSurface.GROUND, true)
		for s: Dictionary in strokes:
			PaintBoard.draw_stroke(self, s, size)


		draw_rect(r, PaintPanel.COL_RED if up else PaintPanel.COL_INK,
			false, 3.0 if up else 1.0)
