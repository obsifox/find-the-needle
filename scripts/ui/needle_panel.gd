class_name NeedlePanel
extends Control


const CARD_W:= 470.0
const PAD:= 26.0


const COL_PAPER:= Color(0.92, 0.89, 0.8)
const COL_INK:= Color(0.13, 0.12, 0.11)
const COL_RED:= Color(0.55, 0.13, 0.09)
const COL_FADE:= Color(0.13, 0.12, 0.11, 0.42)
const COL_WASH:= Color(0, 0, 0, 0.55)

const H_TITLE:= 22
const H_COUNT:= 46
const H_ROW:= 17
const H_NOTE:= 15
const H_BUTTON:= 16


signal return_requested()

var player: Player
var live: LiveStrandManager

var _open:= false


var _armed:= false

var _count: Label
var _sub: Label
var _rows: VBoxContainer
var _loose: Label
var _button: Button
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var wash:= ColorRect.new()
	wash.name = "Wash"
	wash.color = COL_WASH
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)


	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card:= PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_PAPER
	sb.border_color = Color(0.62, 0.58, 0.48)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = PAD
	sb.content_margin_bottom = PAD
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)

	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	var head:= HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	col.add_child(head)


	var balance:= Control.new()
	balance.custom_minimum_size = Vector2(PanelClose.SIZE, 0)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(balance)
	var title:= Label.new()
	title.text = tr("NEEDLES")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ink(title, H_TITLE, COL_INK, true)
	head.add_child(title)
	head.add_child(PanelClose.make(_shut, COL_PAPER))

	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(_count, H_COUNT, COL_INK, true)
	col.add_child(_count)


	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(_sub, H_NOTE, COL_FADE, false)
	col.add_child(_sub)

	col.add_child(_rule())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)

	col.add_child(_rule())

	_loose = Label.new()
	_loose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(_loose, H_ROW, COL_INK, false)
	col.add_child(_loose)

	_button = Button.new()
	_button.name = "ReturnButton"
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_button)
	col.add_child(_button)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(CARD_W - PAD * 2.0, 0)
	_ink(_note, H_NOTE, COL_FADE, false)
	col.add_child(_note)

	var foot:= Label.new()
	foot.text = tr("PRESS E OR ESC TO PUT IT BACK ON THE BOARD")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(foot, H_NOTE, COL_FADE, false)
	col.add_child(foot)


static func _ink(l: Label, size: int, colour: Color, heavy: bool) -> void:
	l.add_theme_font_override("font", UiFont.bold() if heavy else UiFont.regular())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("outline_size", 0)


func _rule() -> Control:
	var r:= ColorRect.new()
	r.color = Color(0.13, 0.12, 0.11, 0.2)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func is_open() -> bool:
	return _open


func open() -> void:
	set_open(true)


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if on:


		_armed = false
		_write(_note, "")
		refresh()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		_shut()
		get_viewport().set_input_as_handled()


func _shut() -> void:
	set_open(false)
	Audio.play("ui_close", -4.0)


func refresh() -> void:
	var pool:= NeedleTypes.pool(GameState.lot_tier)
	var have:= 0
	for type in pool:
		if GameState.is_discovered(type):
			have += 1


	_write(_count, "%d / ?" % GameState.pile_needles_found)
	_write(_sub, tr("in the case from this load  ·  %d of %d kinds")
		% [have, pool.size()])

	for child in _rows.get_children():
		child.queue_free()
	for type in pool:
		_rows.add_child(_row(type))

	var loose:= _loose_types()
	var packed:= _packed_types()
	var out:= loose.size() + packed.size()
	if out == 0:
		_write(_loose, tr("No needle from this load is lying loose in the yard."))
		_loose.add_theme_color_override("font_color", COL_FADE)
	elif out == 1:
		var one:= loose [0] if loose.size() == 1 else packed [0]
		_write(_loose, tr("%s is out in the yard, not in the case.%s")
			% [NeedleTypes.name_of(one), _packed_note(packed)])
		_loose.add_theme_color_override("font_color", COL_RED)
	else:


		var both:= loose.duplicate()
		both.append_array(packed)
		_write(_loose, tr("%d needles you still need are out in the yard: %s.%s")
			% [out, _names_of(both, pool), _packed_note(packed)])
		_loose.add_theme_color_override("font_color", COL_RED)

	_style_button(loose)


static func _names_of(types: PackedInt32Array, pool: PackedInt32Array) -> String:
	var parts:= PackedStringArray()
	for type in pool:
		var n:= types.count(type)
		if n == 1:
			parts.append(NeedleTypes.name_of(type))
		elif n > 1:
			parts.append("%s (%d)" % [NeedleTypes.name_of(type), n])
	return ", ".join(parts)


func _row(type: int) -> Control:
	var box:= HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var found:= GameState.is_discovered(type)
	var tick:= Label.new()
	tick.text = "[X]" if found else "[  ]"
	_ink(tick, H_ROW, COL_INK if found else COL_FADE, true)
	box.add_child(tick)

	var name_label:= Label.new()
	name_label.text = NeedleTypes.name_of(type)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ink(name_label, H_ROW, COL_INK if found else COL_FADE, false)
	box.add_child(name_label)


	var effect:= Label.new()
	effect.text = NeedleTypes.effect_text(type) if found else ""
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ink(effect, H_NOTE, COL_FADE, false)
	box.add_child(effect)
	return box


func _loose_types() -> PackedInt32Array:
	if live == null:
		return PackedInt32Array()
	return live.loose_undiscovered_types()


func _packed_types() -> PackedInt32Array:
	var out:= PackedInt32Array()
	var props:= get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager
	if props == null:
		return out
	for item in props.items:
		if not is_instance_valid(item) or not item.holds_needle():
			continue
		var type:= GameState.type_of(item.needle_index)
		if GameState.is_discovered(type):
			continue
		out.append(type)
	return out


func _packed_note(packed: PackedInt32Array) -> String:
	if packed.is_empty():
		return ""


	if packed.size() == 1:
		return "\n" + tr("One of them is packed inside a bale, a wrapped bale or a brick. Run it past a scanner, or hold X on it to tear it open.")
	return "\n" + tr("%d of them are packed inside bales, wrapped bales or bricks. Run them past a scanner, or hold X on one to tear it open.") % packed.size()


func _style_button(loose: PackedInt32Array) -> void:
	if _button == null:
		return
	var awake:= not loose.is_empty()
	if _armed and awake:
		_button.text = tr("YES, SEND IT BACK INTO THE STACK")
	elif awake and loose.size() == 1:
		_button.text = tr("RETURN %s TO THE STACK") % Cfg.upper(NeedleTypes.name_of(loose [0]))
	elif awake:
		_button.text = tr("RETURN %d NEEDLES TO THE STACK") % loose.size()
	else:
		_button.text = tr("RETURN A STUCK NEEDLE TO THE STACK")

	var ink:= COL_RED if _armed and awake else (COL_INK if awake else COL_FADE)
	_button.add_theme_font_override("font", UiFont.bold())
	_button.add_theme_font_size_override("font_size", H_BUTTON)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		_button.add_theme_color_override(state, ink)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.11, 0.06 if awake else 0.02)
	sb.border_color = Color(0.13, 0.12, 0.11, 0.55 if awake else 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_button.add_theme_stylebox_override(state, sb)


func _on_button() -> void:
	var loose:= _loose_types()
	if loose.is_empty():
		_armed = false
		_write(_note, tr("No needles are lying loose right now. If a needle gets stuck somewhere you cannot reach, press this to put it back into the pile."))
		Audio.play("ui_error", -6.0)
		_style_button(loose)
		return

	if not _armed:
		_armed = true
		_write(_note, tr("This buries the needle in the pile again, and you will have to find it again. Press again to confirm."))
		Audio.play("ui_select", -6.0)
		_style_button(loose)
		return

	_armed = false


	_write(_note, "")
	return_requested.emit()
	Audio.play("ui_select", -4.0)
	refresh()


func report_return(buried: int, floored: int) -> void:
	if floored == 0 and buried > 0:
		_write(_note, tr("Back in the stack."))
	elif floored > 0 and buried == 0:
		_write(_note, tr("The pile is gone, so the needle is on the floor under this board."))
	elif floored > 0:
		_write(_note, tr("%d back in the stack, %d on the floor under this board.")
			% [buried, floored])
	else:
		_write(_note, tr("It could not be moved. Nothing has changed."))


static func _write(l: Label, text: String) -> void:
	if l != null and l.text != text:
		l.text = text
