class_name DemoEndDialog
extends Control


signal menu_requested()

const PANEL_W:= 620.0


const COL_PAPER:= Color(0.92, 0.89, 0.8)
const COL_INK:= Color(0.13, 0.12, 0.11)


const COL_RED:= Color(0.55, 0.13, 0.09)

const COL_FADE:= Color(0.13, 0.12, 0.11, 0.55)
const COL_RULE:= Color(0.13, 0.12, 0.11, 0.22)


const WISHLIST_URL:= PauseMenu.STEAM_URL + "?utm_source=demo&utm_medium=demo_card"


const STAMP_TILT:= 3.5

var player: Player


var save_action: Callable

var _open:= false
var _seen:= false
var _leaving:= false
var _panel: PanelContainer
var _figures: VBoxContainer

var _headline: Label
var _body: Label
var _after: Label

var _wishlist: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return _open


func was_seen() -> bool:
	return _seen


func celebrate() -> void:
	if _seen or _open:
		return
	if not (GameState.collection_complete() or GameState.demo_is_over()):
		return
	_seen = true
	_fill()
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
	if not _open or _leaving:
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
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 26.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	box.add_child(_label(tr("NEEDLE COLLECTION"), 13, COL_FADE))


	_headline = _label("", 36, COL_INK, true)
	box.add_child(_headline)
	box.add_child(_rule(2, COL_INK))


	_body = _label("", 17, COL_INK)
	box.add_child(_body)

	box.add_child(_stamp())

	_figures = VBoxContainer.new()
	_figures.add_theme_constant_override("separation", 0)
	box.add_child(_figures)

	_after = _label("", 15, COL_FADE)
	_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_after)

	var gap:= Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)


	_wishlist = _button(tr("WISHLIST ON STEAM"), PauseMenu.COL_STEAM, COL_PAPER)
	_wishlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wishlist.custom_minimum_size = Vector2(0, 52)
	_wishlist.pressed.connect(_on_wishlist)
	box.add_child(_wishlist)

	var ask_gap:= Control.new()
	ask_gap.custom_minimum_size = Vector2(0, 4)
	ask_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ask_gap)


	var buttons:= HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 0)
	box.add_child(buttons)

	var stay:= _button(tr("KEEP PLAYING"), COL_PAPER, COL_INK)
	stay.pressed.connect(func() -> void: set_open(false))
	buttons.add_child(stay)

	var spacer:= Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(spacer)

	var out:= _button(tr("MAIN MENU"), COL_INK, COL_PAPER)
	out.pressed.connect(_on_menu)
	buttons.add_child(out)


func _stamp() -> Control:
	var holder:= Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(0, 62)

	var stamp:= PanelContainer.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.13, 0.09, 0.09)
	sb.border_color = COL_RED
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 5.0
	stamp.add_theme_stylebox_override("panel", sb)
	stamp.add_child(_label(tr("DEMO COMPLETE"), 22, COL_RED, true))
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


func _on_menu() -> void:
	if _leaving:
		return
	_leaving = true


	if save_action.is_valid():
		save_action.call()
	Audio.play("ui_back")
	Loading.show_screen("FIND THE NEEDLE", tr("RETURNING TO THE YARD"))
	menu_requested.emit()


func _on_wishlist() -> void:
	if _leaving:
		return
	Audio.play("ui_select")
	if OS.shell_open("steam://openurl/" + WISHLIST_URL) == OK:
		return
	if OS.shell_open(WISHLIST_URL) == OK:
		return
	Audio.play("ui_error")
	_after.text = tr("Please open this address in your browser: %s") % WISHLIST_URL


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


func _fill() -> void:

	_wishlist.visible = Cfg.DEMO
	if GameState.collection_complete():
		_headline.text = tr("ALL TWENTY-FOUR FOUND")
		_body.text = tr("You found every needle in this yard.")


		_after.text = tr("That is every needle in the game. You can keep playing or stop here.")
	else:


		var loads:= NeedleTypes.lot_count() - 1 - Cfg.DEMO_LAST_LOT
		var kinds:= 0
		for lot in range(Cfg.DEMO_LAST_LOT + 1, NeedleTypes.lot_count()):
			kinds += NeedleTypes.pool(lot).size()
		_headline.text = tr("THE FIRST SIX FOUND")
		_body.text = tr("You found every kind of needle in the first load.")
		_after.text = tr("That is the end of the demo. The full game has %d more loads and %d more kinds of needle. You can keep playing or stop here.") % [loads, kinds]
	for child in _figures.get_children():
		_figures.remove_child(child)
		child.queue_free()
	_row(tr("needles picked up"), str(GameState.needles_found))
	_row(tr("hay dug out of the pile"), Hud.money_text(GameState.hay_dug))
	_row(tr("money earned"), "$%s" % Hud.money_text(GameState.money_earned))


func _row(what: String, figure: String) -> void:
	var line:= HBoxContainer.new()
	var name_label:= _label(what, 16, COL_INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0, 30)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	var value:= _mono(figure, 16, COL_INK, true)
	value.custom_minimum_size = Vector2(150, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(value)
	_figures.add_child(line)
	_figures.add_child(_rule(1, COL_RULE))
