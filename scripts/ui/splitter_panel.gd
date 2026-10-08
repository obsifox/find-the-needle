class_name SplitterPanel
extends Control


const PANEL_W:= 480.0

const PAD:= 18.0


const RULE:= 3.0


var player: Player

var _splitter: ConveyorSplitter
var _open:= false
var _panel: PanelContainer


var _gate_panel: PanelContainer
var _compact_panel: PanelContainer
var _filter_picks: Array [OptionButton] = []
var _filter_help: Array [Label] = []
var _compact_layout: BoxContainer


var _stuck_note: Label
var _door_map: DoorMap
var _stats: Label
var _gate_stats: Label


var _t_note: Label

var _feed_ask: Label
var _feed_row: HBoxContainer

var _feed_buttons: Dictionary = { }


var _buttons: Dictionary = { }


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_open() -> bool:
	return _open


func splitter() -> ConveyorSplitter:
	return _splitter


func open(from: ConveyorSplitter) -> void:
	if from == null:
		return
	_show_tags(false)
	_splitter = from
	_refresh()
	_set_open(true)
	_show_tags(true)


func close() -> void:
	_set_open(false)


func _set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if not on:
		_show_tags(false)
		_splitter = null


func _show_tags(on: bool) -> void:
	var compact:= _splitter as ConveyorCompactSplitter
	if compact != null and is_instance_valid(compact):
		compact.show_door_tags(on)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_pick(id: String) -> void:
	if is_instance_valid(_splitter):


		if id == _splitter.setting() and (id == ConveyorSplitter.SET_MAIN_LEFT
				or id == ConveyorSplitter.SET_MAIN_RIGHT):
			_splitter.set_priority_side(-1)
			_refresh()
			return
		match id:
			ConveyorSplitter.SET_PIN_LEFT:
				_splitter.set_forced_side(ConveyorSplitter.LEFT)
			ConveyorSplitter.SET_PIN_RIGHT:
				_splitter.set_forced_side(ConveyorSplitter.RIGHT)
			ConveyorSplitter.SET_MAIN_LEFT:
				_splitter.set_priority_side(ConveyorSplitter.LEFT)
			ConveyorSplitter.SET_MAIN_RIGHT:
				_splitter.set_priority_side(ConveyorSplitter.RIGHT)
			_:


				_splitter.set_forced_side(-1)
				_splitter.set_priority_side(-1)
	_refresh()


func _refresh() -> void:
	if _stats == null or not is_instance_valid(_splitter):
		return
	var compact:= _splitter as ConveyorCompactSplitter
	if _panel != null:
		_panel.visible = compact == null
	if _compact_panel != null:
		_compact_panel.visible = compact != null
	if compact != null:
		_gate_panel.visible = false
		_refresh_compact(compact)
		return


	if _gate_panel != null:
		_gate_panel.visible = Tech.priority_arm_unlocked()
	var now:= _splitter.setting()
	for id: String in _buttons:
		var button:= _buttons [id] as Button


		button.text = _splitter.name_for(id)
		button.button_pressed = id == now
		_paint(button)


	var straight:= _splitter.straight_side()
	var loose:= _splitter as ConveyorTSplitter
	if loose != null and loose.fed:
		loose = null
	if _feed_row != null:
		_feed_ask.visible = loose != null
		_feed_row.visible = loose != null
		for lane: int in _feed_buttons:
			var b:= _feed_buttons [lane] as Button


			b.button_pressed = loose != null and (lane == ConveyorTSplitter.STEM) == (loose.entry == ConveyorTSplitter.STEM)
			_paint(b)
	if _t_note != null:
		var t:= _splitter as ConveyorTSplitter
		_t_note.visible = t != null
		if loose != null:
			_t_note.text = tr("Once a belt arrives, the belt decides: a belt in at the middle splits left and right, a belt in at one end goes straight on and to the side.")
		elif t != null and straight < 0:
			_t_note.text = tr("The belt comes in at the middle, so hay goes left or right. Bring the belt in at one end instead and the T changes by itself to straight on and to the side.")
		elif t != null:
			_t_note.text = tr("The belt comes in at one end, so hay goes straight on or to the side. Bring the belt in at the middle instead and the T changes by itself to left and right.")
	if straight >= 0:
		_refresh_straight(straight)
		return


	var left_main:= _splitter.priority_side == ConveyorSplitter.LEFT


	if _splitter.priority_side >= 0:
		_stats.text = tr("This one is on priority.  Everything goes down the left side.") if left_main else tr("This one is on priority.  Everything goes down the right side.")
	elif _splitter.forced_side < 0:


		_stats.text = tr("One load down each side in turn.  If one side backs up, the other takes them all until it clears.")
	else:


		_stats.text = tr("Sends everything down the left side.  The other side is shut.") if _splitter.forced_side == ConveyorSplitter.LEFT else tr("Sends everything down the right side.  The other side is shut.")

	if _gate_stats == null:
		return
	if _splitter.priority_side < 0:
		_gate_stats.text = tr("Off.  The splitter is using the setting above.")
		return


	_gate_stats.text = tr("Everything goes down the left side first.  The right side only gets hay when the left side is backed up.") if left_main else tr("Everything goes down the right side first.  The left side only gets hay when the right side is backed up.")


func _refresh_straight(straight: int) -> void:
	var turns_left:= straight == ConveyorSplitter.RIGHT
	if _splitter.priority_side >= 0:
		if _splitter.priority_side == straight:
			_stats.text = tr("This one is on priority.  Everything goes straight on.")
		elif turns_left:
			_stats.text = tr("This one is on priority.  Everything goes down the left side.")
		else:
			_stats.text = tr("This one is on priority.  Everything goes down the right side.")
	elif _splitter.forced_side < 0:
		_stats.text = tr("One load down each side in turn.  If one side backs up, the other takes them all until it clears.")
	elif _splitter.forced_side == straight:
		_stats.text = tr("Sends everything straight on.  The other side is shut.")
	elif turns_left:
		_stats.text = tr("Sends everything down the left side.  The other side is shut.")
	else:
		_stats.text = tr("Sends everything down the right side.  The other side is shut.")

	if _gate_stats == null:
		return
	if _splitter.priority_side < 0:
		_gate_stats.text = tr("Off.  The splitter is using the setting above.")
	elif _splitter.priority_side == straight:
		_gate_stats.text = tr("Everything goes straight on first.  The side only gets hay when straight on is backed up.")
	elif turns_left:
		_gate_stats.text = tr("Everything goes down the left side first.  Straight on only gets hay when the left side is backed up.")
	else:
		_gate_stats.text = tr("Everything goes down the right side first.  Straight on only gets hay when the right side is backed up.")


func _build() -> void:


	var stack:= VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	stack.add_theme_constant_override("separation", 10)
	add_child(stack)

	_panel = _card()
	stack.add_child(_panel)
	var col:= _card_body(_panel, tr("CONVEYOR SPLITTER"),
		tr("%s or ESC to close") % InputSetup.hint("interact"), close, "splitter")
	col.add_child(_label(tr("Where the hay goes."), 15, ArmPanel.COL_INK_SOFT))


	_feed_ask = _label(tr("No belt yet. Where does the belt come in?"), 15, ArmPanel.COL_INK_SOFT)
	_feed_ask.visible = false
	col.add_child(_feed_ask)
	_feed_row = HBoxContainer.new()
	_feed_row.add_theme_constant_override("separation", 8)
	_feed_row.visible = false
	col.add_child(_feed_row)


	_feed_row.add_child(_feed_button(ConveyorTSplitter.STEM, tr("AT THE MIDDLE")))
	_feed_row.add_child(_feed_button(ConveyorTSplitter.BAR_POS, tr("AT ONE END")))

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)


	row.add_child(_pick_button(ConveyorSplitter.SET_PIN_LEFT, 3))
	row.add_child(_pick_button(ConveyorSplitter.SET_TURN, 3))
	row.add_child(_pick_button(ConveyorSplitter.SET_PIN_RIGHT, 3))

	col.add_child(_rule())
	_stats = _body_label()
	col.add_child(_stats)
	_t_note = _body_label()
	_t_note.visible = false
	col.add_child(_t_note)

	_gate_panel = _card()
	_gate_panel.visible = false
	stack.add_child(_gate_panel)
	var gate_col:= _card_body(_gate_panel, tr("PRIORITY"), tr("FITTED"))
	gate_col.add_child(_label(tr("One side gets hay first."),
		15, ArmPanel.COL_INK_SOFT))

	var gate_row:= HBoxContainer.new()
	gate_row.add_theme_constant_override("separation", 8)
	gate_col.add_child(gate_row)


	gate_row.add_child(_pick_button(ConveyorSplitter.SET_MAIN_LEFT, 2))
	gate_row.add_child(_pick_button(ConveyorSplitter.SET_MAIN_RIGHT, 2))

	gate_col.add_child(_rule())
	_gate_stats = _body_label()
	gate_col.add_child(_gate_stats)

	_build_smart_card(stack)


func _build_smart_card(stack: VBoxContainer) -> void:
	_compact_panel = _card()
	_compact_panel.visible = false
	stack.add_child(_compact_panel)
	var col:= _card_body(_compact_panel, tr("SMART SPLITTER"),
		tr("%s or ESC to close") % InputSetup.hint("interact"), close, "smart_splitter")
	col.add_child(_label(tr("Pick what may leave through each door."), 15, ArmPanel.COL_INK_SOFT))


	_stuck_note = _label("", 15, ArmPanel.COL_WARN, true)
	_stuck_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stuck_note.visible = false
	col.add_child(_stuck_note)
	_door_map = DoorMap.new()
	_door_map.output_pressed.connect(func(side: int) -> void:
		_filter_picks [side].grab_focus()
		_filter_picks [side].show_popup())
	col.add_child(_door_map)
	col.add_child(_rule())
	_compact_layout = BoxContainer.new()
	_compact_layout.vertical = true
	_compact_layout.add_theme_constant_override("separation", 10)
	col.add_child(_compact_layout)
	var settings:= _compact_layout
	for side in ConveyorCompactSplitter.OUTPUTS:
		var row:= HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		settings.add_child(row)
		var badge:= _door_badge(side)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
		var fields:= VBoxContainer.new()
		fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fields.add_theme_constant_override("separation", 6)
		row.add_child(fields)
		var pick:= OptionButton.new()
		pick.fit_to_longest_item = false
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size.y = 38
		_style_smart_button(pick)
		pick.add_theme_constant_override("icon_max_width", 32)
		var popup:= pick.get_popup()
		popup.add_theme_stylebox_override("panel", _face(ArmPanel.COL_PAPER))
		popup.add_theme_stylebox_override("hover", _face(ArmPanel.COL_INK))
		popup.add_theme_font_override("font", UiFont.regular())
		popup.add_theme_font_size_override("font_size", 15)
		popup.add_theme_color_override("font_color", ArmPanel.COL_INK)
		popup.add_theme_color_override("font_hover_color", ArmPanel.COL_PAPER)
		for rule: Array in [
				[tr("Anything"), ConveyorCompactSplitter.RULE_ANY],
				[tr("Everything else"), ConveyorCompactSplitter.RULE_UNDEFINED],
				[tr("Overflow"), ConveyorCompactSplitter.RULE_OVERFLOW],
				[tr("Closed"), ConveyorCompactSplitter.RULE_NONE]]:
			pick.add_item(rule [0])
			pick.set_item_metadata(pick.item_count - 1, rule [1])
		for kind in range(BeltRun.ITEM_IDS.size()):
			pick.add_icon_item(_item_icon(kind), tr("Only %s") % ItemDb.display_name(BeltRun.ITEM_IDS [kind]))
			pick.set_item_metadata(pick.item_count - 1, kind)
			popup.set_item_icon_max_width(pick.item_count - 1, 32)
		for index in range(pick.item_count):
			popup.set_item_as_radio_checkable(index, false)
		pick.item_selected.connect(_on_filter_pick.bind(side))
		pick.mouse_entered.connect(_highlight_port.bind(side))
		pick.mouse_exited.connect(_highlight_port.bind(-1))
		pick.focus_entered.connect(_highlight_port.bind(side))
		pick.focus_exited.connect(_highlight_port.bind(-1))
		fields.add_child(pick)
		_filter_picks.append(pick)
		var help:= _label("", 13, ArmPanel.COL_INK_SOFT)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fields.add_child(help)
		_filter_help.append(help)
	col.add_child(_rule())
	var footer:= _label(tr("Output numbers match the markings on the machine."), 13, ArmPanel.COL_INK_SOFT)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(footer)
	resized.connect(_layout_smart)
	_layout_smart()


func _layout_smart() -> void:
	if _compact_layout == null:
		return
	_compact_panel.custom_minimum_size.x = PANEL_W
	_compact_panel.size = Vector2.ZERO


func _highlight_port(side: int) -> void:
	_door_map.highlight = side
	_door_map.queue_redraw()


static func _item_icon(kind: int) -> Texture2D:
	var id:= BeltRun.ITEM_IDS [kind]
	if id == "hay_tuft" or id == "feed_disc":
		return load("res://assets/ui/icons/splitter_%s.png" % id)
	return TechPanel.icon_for(id)


func _style_smart_button(button: Button) -> void:
	button.add_theme_font_override("font", UiFont.regular())
	button.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _face(ArmPanel.COL_HOVER if state == "hover" else ArmPanel.COL_PAPER))
	var focus:= _face(Color.TRANSPARENT)
	focus.border_color = ArmPanel.COL_INK
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_constant_override("modulate_arrow", 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ArmPanel.COL_INK)


func _rule_help(rule: int) -> String:
	match rule:
		ConveyorCompactSplitter.RULE_ANY:
			return tr("Accepts any item.")
		ConveyorCompactSplitter.RULE_UNDEFINED:
			return tr("Items with no specific output rule.")
		ConveyorCompactSplitter.RULE_OVERFLOW:
			return tr("Used when other eligible outputs are full.")
		ConveyorCompactSplitter.RULE_NONE:
			return tr("No items leave through this output.")
	return tr("Routes only the selected item.")


func _door_badge(side: int) -> Control:
	var badge:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = ConveyorCompactSplitter.DOOR_COLOURS [side]
	sb.set_corner_radius_all(0)
	sb.border_color = ArmPanel.COL_INK
	sb.set_border_width_all(2)
	badge.add_theme_stylebox_override("panel", sb)
	badge.custom_minimum_size = Vector2(38.0, 38.0)
	var number:= _label(str(side + 1), 18, ArmPanel.COL_INK, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number)
	return badge


class DoorMap extends Control:
	signal output_pressed(side: int)
	var splitter: ConveyorCompactSplitter
	var highlight:= -1
	var item_icons: Array [Texture2D] = [null, null, null]

	func _init() -> void:
		custom_minimum_size = Vector2(220, 230)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var dirs:= [Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
			for side in range(3):
				var at: Vector2 = size * 0.5 + Vector2(0, -12) + dirs [side] * 65
				if Rect2(at - Vector2(22, 22), Vector2(44, 44)).has_point(event.position):
					output_pressed.emit(side)
					accept_event()

	func _draw() -> void:
		var c:= size * 0.5 + Vector2(0, -12)
		var ink:= ArmPanel.COL_INK
		var dirs:= [Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
		var tail:= c + Vector2(0, 88)
		var tip:= c + Vector2(0, 39)
		draw_line(tail, c, ArmPanel.COL_HOVER, 10, true)
		_arrow(tail, tip, ink)
		var font:= UiFont.regular()
		var text:= tr("INPUT")
		draw_string(font, c + Vector2(- font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, 112), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		for side in ConveyorCompactSplitter.OUTPUTS:
			var dir: Vector2 = dirs [side]
			var colour: Color = ConveyorCompactSplitter.DOOR_COLOURS [side]
			if highlight >= 0 and highlight != side:
				colour.a = 0.35
			var end:= c + dir * 102
			draw_line(c, end, ArmPanel.COL_HOVER, 10, true)
			var rule:= splitter.filter_for(side) if is_instance_valid(splitter) else ConveyorCompactSplitter.RULE_NONE
			if rule == ConveyorCompactSplitter.RULE_NONE:
				draw_dashed_line(c, end, Color(ink, 0.4), 1.5, 4, true)
			elif rule == ConveyorCompactSplitter.RULE_OVERFLOW:
				draw_dashed_line(c, end, colour, 2, 5, true)
				_arrow(end - dir * 10, end, colour)
			else:
				_arrow(c, end, colour)
			var at:= c + dir * 65
			var face:= StyleBoxFlat.new()
			face.bg_color = colour
			face.border_color = ArmPanel.COL_INK
			face.set_border_width_all(1)
			draw_style_box(face, Rect2(at - Vector2(22, 22), Vector2(44, 44)))
			if item_icons [side] != null:

				var icon_rect:= Rect2(at - Vector2(20, 20), Vector2(40, 40))
				draw_texture_rect(item_icons [side], icon_rect, false, Color(1, 1, 1, colour.a * 0.65))
			var number:= str(side + 1)
			var number_font:= UiFont.bold()
			var number_at:= at + Vector2(- number_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, 7)
			draw_string_outline(number_font, number_at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 3, ArmPanel.COL_PAPER)
			draw_string(number_font, number_at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ArmPanel.COL_INK)
		var body:= StyleBoxFlat.new()
		body.bg_color = ArmPanel.COL_PAPER
		body.border_color = ArmPanel.COL_INK
		body.set_border_width_all(2)
		body.set_corner_radius_all(0)
		draw_style_box(body, Rect2(c - Vector2(36, 36), Vector2(72, 72)))

	func _arrow(from: Vector2, to: Vector2, colour: Color) -> void:
		var dir:= (to - from).normalized()
		var side:= Vector2(- dir.y, dir.x) * 4
		draw_line(from, to, colour, 2, true)
		draw_polyline(PackedVector2Array([to - dir * 6 + side, to, to - dir * 6 - side]), colour, 2, true)


func _refresh_compact(splitter: ConveyorCompactSplitter) -> void:
	if _door_map != null:
		_door_map.splitter = splitter
		_door_map.highlight = -1
		_door_map.queue_redraw()
	_refresh_stuck()
	for side in ConveyorCompactSplitter.OUTPUTS:
		var pick:= _filter_picks [side]
		pick.disabled = not splitter.smart
		var rule:= splitter.filter_for(side)
		_door_map.item_icons [side] = _item_icon(rule) if rule >= 0 and rule < BeltRun.ITEM_IDS.size() else null
		_filter_help [side].text = _rule_help(rule)
		for index in range(pick.item_count):
			if int(pick.get_item_metadata(index)) == rule:
				pick.select(index)
				break


func _refresh_stuck() -> void:
	if _stuck_note == null:
		return
	var compact:= _splitter as ConveyorCompactSplitter
	var kind:= compact.stuck_kind() if is_instance_valid(compact) else -1
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
		_stuck_note.visible = false
		return
	_stuck_note.text = tr("No output takes %s, so the belt has stopped.") % ItemDb.display_name(BeltRun.ITEM_IDS [kind])
	_stuck_note.visible = true


func _process(_delta: float) -> void:
	if visible and _compact_panel != null and _compact_panel.visible:
		_refresh_stuck()


func _on_filter_pick(index: int, side: int) -> void:
	var compact:= _splitter as ConveyorCompactSplitter
	if compact == null or not compact.smart:
		return
	compact.set_filter(side, int(_filter_picks [side].get_item_metadata(index)))
	_refresh_compact(compact)


func _card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(PANEL_W, 0.0)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = ArmPanel.COL_PAPER
	sb.border_color = ArmPanel.COL_INK
	sb.set_border_width_all(int(RULE))
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(0.0)
	card.add_theme_stylebox_override("panel", sb)
	return card


func _card_body(card: PanelContainer, title: String, aside: String,
		closer: Callable = Callable(), tile: String = "") -> VBoxContainer:
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	card.add_child(whole)
	whole.add_child(ArmPanel.band(title, aside, closer, null, false, tile) [0])
	whole.add_child(_rule())

	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(PAD))
	inset.add_theme_constant_override("margin_right", int(PAD))
	inset.add_theme_constant_override("margin_top", int(PAD) - 2)
	inset.add_theme_constant_override("margin_bottom", int(PAD))
	whole.add_child(inset)

	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inset.add_child(col)
	return col


func _rule() -> Control:
	var line:= ColorRect.new()
	line.color = ArmPanel.COL_INK
	line.custom_minimum_size = Vector2(0.0, 2.0)
	return line


func _body_label() -> Label:
	var l:= _label("", 15, ArmPanel.COL_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - RULE * 2.0, 0.0)
	return l


func _pick_button(id: String, across: int) -> Button:
	var b:= Button.new()


	b.text = tr(str(ConveyorSplitter.SET_NAMES.get(id, "?")))
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(
		(PANEL_W - PAD * 2.0 - RULE * 2.0 - 8.0 * (across - 1)) / float(across), 38.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE


	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(_on_pick.bind(id))

	var drawing:= "split"
	match id:
		ConveyorSplitter.SET_PIN_LEFT, ConveyorSplitter.SET_MAIN_LEFT:
			drawing = "back"
		ConveyorSplitter.SET_PIN_RIGHT, ConveyorSplitter.SET_MAIN_RIGHT:
			drawing = "forward"
	PlateIcons.on_button(b, drawing, 18, ArmPanel.COL_INK, ArmPanel.COL_LOCKED)
	_buttons [id] = b
	_paint(b)
	return b


func _feed_button(lane: int, face: String) -> Button:
	var b:= Button.new()
	b.text = face
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(
		(PANEL_W - PAD * 2.0 - RULE * 2.0 - 8.0) / 2.0, 34.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(_on_feed_pick.bind(lane))
	_feed_buttons [lane] = b
	_paint(b)
	return b


func _on_feed_pick(lane: int) -> void:
	var t:= _splitter as ConveyorTSplitter
	if t != null and is_instance_valid(t):
		t.set_entry(lane)
	_refresh()


func _paint(b: Button) -> void:
	var on:= b.button_pressed
	b.add_theme_stylebox_override("normal", _face(ArmPanel.COL_TILE_ON if on else ArmPanel.COL_PAPER, on))
	b.add_theme_stylebox_override("hover", _face(ArmPanel.COL_TILE_ON if on else ArmPanel.COL_HOVER, on))
	b.add_theme_stylebox_override("pressed", _face(ArmPanel.COL_TILE_ON, true))
	b.add_theme_stylebox_override("hover_pressed", _face(ArmPanel.COL_TILE_ON, true))
	b.add_theme_stylebox_override("focus", _face(ArmPanel.COL_TILE_ON if on else ArmPanel.COL_PAPER, on))
	for state: String in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ArmPanel.COL_INK)


func _face(fill: Color, heavy: bool = false) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = ArmPanel.COL_INK
	sb.set_border_width_all(3 if heavy else 2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(6.0)
	return sb


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
