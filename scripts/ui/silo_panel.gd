class_name SiloPanel
extends Control


const PANEL_W:= 620.0

const RADIUS:= 0


const REFRESH:= 0.25


const KINDS: Array [String] = ["hay_bale", "foiled_bale", "eco_brick", "hay_wad"]

var player: Player

var _silo: HaySilo
var _open:= false
var _panel: PanelContainer


var _top: Dictionary
var _pill_text: Label
var _dial: Dial
var _per_min: Label
var _unit: Label
var _per_sec: Label
var _ceiling: Label
var _down: Button
var _up: Button
var _switch: Button


var _power_switch: ArmPanel.PowerToggle
var _level: Meter
var _level_text: Label
var _slots: Array [Control] = []
var _flow: Label
var _note: Label

var _power: Label
var _timer:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func silo() -> HaySilo:
	return _silo


func open(from: HaySilo) -> void:
	if from == null:
		return


	_silo = from
	_dial.notch = Cfg.SILO_RATE_STEP_PER_MIN
	_dial.maximum = from.rate_max_per_minute()
	_dial.set_reading(from.rate_per_minute())
	_refresh()
	_set_open(true)


func close() -> void:
	_set_open(false)


func _set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	set_process(on)
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if not on:
		_silo = null


func _process(delta: float) -> void:
	if not _open:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH


	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_step(by: float) -> void:
	if not is_instance_valid(_silo):
		return
	_silo.set_rate_per_minute(_silo.rate_per_minute() + by)
	_dial.set_reading(_silo.rate_per_minute())
	_refresh()


func _on_dial(loads_per_minute: float) -> void:
	if is_instance_valid(_silo):
		_silo.set_rate_per_minute(loads_per_minute)
	_refresh()


func _on_switch() -> void:
	if not is_instance_valid(_silo):
		return
	if _silo.is_running():
		_silo.stop()
	else:
		_silo.start()
	_dial.set_reading(_silo.rate_per_minute())
	_refresh()


func _on_power_switch() -> void:
	if is_instance_valid(_silo):
		_silo.set_switched_off(not _silo.is_switched_off())
	_refresh()


func _refresh() -> void:
	if _per_min == null or not is_instance_valid(_silo):
		return
	var running:= _silo.is_running()
	var off:= _silo.is_switched_off()
	var per_min:= _silo.rate_per_minute()


	if not _dial.dragging:
		_dial.maximum = _silo.rate_max_per_minute()
		_dial.set_reading(per_min)


	_dial.stopped = not running or off


	var still:= not running or off
	_per_min.text = tr("STOPPED") if still else _grouped(int(round(per_min)))
	_per_min.add_theme_color_override("font_color",
		ArmPanel.COL_WARN if still else ArmPanel.COL_INK)


	_unit.text = "" if still else tr("loads a minute")
	_per_sec.text = tr("nothing is coming out") if still else tr("that is %s a second") % _seconds_text(_silo.rate())


	var top:= _grouped(int(round(_silo.rate_max_per_minute())))
	_ceiling.text = tr("up to %s a minute, all the belt can take") % top if HaySilo.belt_caps_dial() else tr("up to %s a minute") % top

	var step:= Cfg.SILO_RATE_STEP_PER_MIN
	_down.disabled = per_min <= 0.0
	_up.disabled = per_min >= _silo.rate_max_per_minute() - 0.001
	_down.text = "−%d" % int(step)
	_up.text = "+%d" % int(step)
	_switch.text = tr("STOP") if running else tr("START")
	_switch.icon = PlateIcons.texture("stopped" if running else "working", 20)
	_face(_switch, ArmPanel.COL_WARN if running else ArmPanel.COL_GO)
	_power_switch.set_running(not off)

	_write_pill()
	_write_level()
	_write_flow()


	_power.text = MachinePower.rating_line_for(_silo, player)
	_power.visible = _power.text != ""


func _write_pill() -> void:
	var word:= tr("RUNNING")
	var colour:= ArmPanel.COL_GO
	if _silo.is_switched_off():
		word = tr("SWITCHED OFF")
		colour = ArmPanel.COL_WARN
	elif not _silo.is_running():
		word = tr("STOPPED")
		colour = ArmPanel.COL_WARN
	elif _silo.blocked_for > 0.0:
		word = tr("BLOCKED")
		colour = ArmPanel.COL_WARN
	elif _silo.is_full():
		word = tr("FULL")
		colour = ArmPanel.COL_WAIT
	elif not _silo.has_load():
		word = tr("EMPTY")
		colour = ArmPanel.COL_WAIT

	var state:= 0 if colour == ArmPanel.COL_GO else (1 if colour == ArmPanel.COL_WAIT else 2)
	ArmPanel.write_state(_pill_text, _top ["sign"], state)
	_pill_text.text = word
	(_top ["line"] as Label).text = tr("It holds hay and lets it out at the speed you pick.")
	ArmPanel.write_power_chip(_top ["chip"], _top ["chip_word"],
		MachinePower.power_share_for(_silo, player))


func _write_level() -> void:
	var held:= _silo.held()
	var cap:= _silo.capacity()
	_level.fill = _silo.fill()


	_level.colour = ArmPanel.COL_TAKE_INK
	if _silo.is_full():
		_level.colour = ArmPanel.COL_WARN
	elif _level.fill >= 0.9:
		_level.colour = ArmPanel.COL_WAIT
	_level.queue_redraw()
	_level_text.text = tr("%s / %s loads") % [_grouped(held), _grouped(cap)]

	var counts:= _silo.contents()
	var i:= 0
	for id: String in KINDS:
		var n:= int(counts.get(id, 0))
		i = _fill_slot(i, id, n, _count_text(id, n))
	if _silo.stored > 0:
		i = _fill_slot(i, "hay_strand", _silo.stored,
			tr("%s loose straw") % _grouped(_silo.stored))


	if _silo.pending_needles.size() > 0:
		var n:= _silo.pending_needles.size()
		i = _fill_slot(i, "needle", n,
			tr_n("%d needle waiting", "%d needles waiting", n) % n)
	if i == 0:
		i = _fill_slot(i, "", 0, tr("nothing in it yet"))
	while i < _slots.size():
		_slots [i].visible = false
		i += 1


func _fill_slot(at: int, icon: String, count: int, text: String) -> int:
	if count <= 0 and icon != "":
		return at
	if at >= _slots.size():
		return at
	var slot:= _slots [at]
	slot.visible = true
	var rect:= slot.get_node("Icon") as TextureRect


	rect.texture = TechPanel.icon_for(icon) if icon != "" else null
	(slot.get_node("Text") as Label).text = text
	return at + 1


func _write_flow() -> void:
	var got:= _silo.measured_per_minute()
	var want:= _silo.rate_per_minute()
	_flow.text = tr("%s a minute") % _grouped(int(round(got)))
	_flow.add_theme_color_override("font_color",
		ArmPanel.COL_INK_SOFT if _silo.is_shut() else ArmPanel.COL_INK)
	if _silo.is_switched_off():
		_note.text = tr("It is switched off and the tank is full, so the belt above it has stopped as well.") if _silo.is_full() else tr("It is switched off, so nothing is coming out. Hay can still go in until the tank is full.")
		return
	if not _silo.is_running():
		_note.text = tr("The dial is at zero and the tank is full, so the belt above it has stopped as well.") if _silo.is_full() else tr("The dial is at zero, so nothing is coming out. Hay can still go in until the tank is full.")
		return
	if _silo.blocked_for > 0.0:
		_note.text = tr("The belt below is full, so hay is waiting inside.")
		return
	if _silo.held() <= 0:
		_note.text = tr("Nothing in it yet. It will start letting hay out as soon as some arrives.")
		return


	if _silo.is_full():
		_note.text = tr("It is full, so the belt above has stopped. Turn the dial up, or make room on the belt underneath.")
		return
	if got <= 0.0:
		_note.text = tr("Nothing has come out in the last few seconds. Check the belt below has room.")
		return
	if got < want * 0.75:
		_note.text = tr("The belt below is too slow for this speed. A faster belt helps.")
		return
	_note.text = tr("Keeping up with the dial.")


static func _grouped(n: int) -> String:
	var digits:= str(absi(n))
	var out:= ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	out = digits + out
	return ("-" + out) if n < 0 else out


static func _seconds_text(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return "%d" % int(round(v))
	return "%.1f" % v


func _count_text(id: String, n: int) -> String:
	match id:
		"hay_bale":
			return tr_n("%s hay bale", "%s hay bales", n) % _grouped(n)
		"foiled_bale":
			return tr_n("%s wrapped bale", "%s wrapped bales", n) % _grouped(n)
		"eco_brick":
			return tr_n("%s eco brick", "%s eco bricks", n) % _grouped(n)
		"hay_wad":
			return tr_n("%s hay wad", "%s hay wads", n) % _grouped(n)
	return "%s %s" % [_grouped(n), ItemDb.display_name(id)]


func _face(b: Button, colour: Color) -> void:
	for state: String in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(state, colour)
	b.add_theme_color_override("font_disabled_color", colour.darkened(0.55))


func _plate(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(RADIUS)
		sb.set_border_width_all(2)
		sb.border_color = ArmPanel.COL_INK
		sb.bg_color = ArmPanel.COL_PAPER
		match state:
			"hover":
				sb.bg_color = ArmPanel.COL_HOVER
			"pressed":
				sb.bg_color = ArmPanel.COL_TILE_ON
			"disabled":
				sb.bg_color = ArmPanel.COL_PAPER
				sb.border_color = ArmPanel.COL_LOCKED
			"focus":
				sb.draw_center = false
		b.add_theme_stylebox_override(state, sb)


func _build() -> void:
	_panel = PlateKit.card(PANEL_W, PlateKit.GLASS)
	add_child(_panel)

	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_panel.add_child(col)


	_power_switch = ArmPanel.PowerToggle.new()
	_power_switch.pressed.connect(_on_power_switch)
	_top = PlateKit.top(col, tr("HAY SILO"), "silo", close, _power_switch)
	_pill_text = _top ["word"]

	var body:= MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		body.add_theme_constant_override(side, 20)
	body.add_theme_constant_override("margin_top", 12)
	body.add_theme_constant_override("margin_bottom", 16)
	col.add_child(body)
	var rows:= VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	body.add_child(rows)

	rows.add_child(PlateKit.heading(tr("FEED RATE"), "dial"))
	rows.add_child(_rate_block())
	rows.add_child(_spacer(6))
	rows.add_child(PlateKit.heading(tr("INSIDE THE TANK"), "tank"))
	rows.add_child(_level_block())
	rows.add_child(_spacer(6))
	rows.add_child(PlateKit.heading(tr("GETTING OUT"), "flow"))
	rows.add_child(_flow_block())


	var foot:= PlateKit.foot(col)
	_power = PlateKit.power_line()
	foot.add_child(_power)


func _rate_block() -> Control:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)


	var reading:= HBoxContainer.new()
	reading.add_theme_constant_override("separation", 8)
	col.add_child(reading)
	_per_min = _label("0", 40, ArmPanel.COL_INK, true)
	_per_min.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	reading.add_child(_per_min)
	var unit:= VBoxContainer.new()
	unit.add_theme_constant_override("separation", 0)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	reading.add_child(unit)
	_unit = _label(tr("loads a minute"), 17, ArmPanel.COL_INK)
	unit.add_child(_unit)
	_per_sec = _label("", 14, ArmPanel.COL_INK_SOFT)
	unit.add_child(_per_sec)

	var controls:= HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	col.add_child(controls)
	_down = _step_button(- Cfg.SILO_RATE_STEP_PER_MIN)
	controls.add_child(_down)
	_dial = Dial.new()
	_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dial.track = ArmPanel.COL_TILE
	_dial.edge = ArmPanel.COL_TILE_EDGE
	_dial.fill = ArmPanel.COL_TAKE_INK
	_dial.grab = ArmPanel.COL_INK
	_dial.ground = ArmPanel.COL_PAPER
	_dial.changed.connect(_on_dial)
	controls.add_child(_dial)
	_up = _step_button(Cfg.SILO_RATE_STEP_PER_MIN)
	controls.add_child(_up)


	_switch = Button.new()
	_switch.text = tr("STOP")
	_switch.custom_minimum_size = Vector2(96, 40)
	_switch.focus_mode = Control.FOCUS_NONE
	_switch.add_theme_font_override("font", UiFont.bold())
	_switch.add_theme_font_size_override("font_size", 16)
	_plate(_switch)
	PlateIcons.on_button(_switch, "stopped", 20, ArmPanel.COL_WARN, ArmPanel.COL_LOCKED)
	_switch.custom_minimum_size.x = 120.0
	_switch.pressed.connect(_on_switch)
	controls.add_child(_switch)

	var ends:= HBoxContainer.new()
	col.add_child(ends)
	ends.add_child(_label(tr("off"), 13, ArmPanel.COL_INK_SOFT))
	var gap:= Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(gap)
	_ceiling = _label("", 13, ArmPanel.COL_INK_SOFT)
	ends.add_child(_ceiling)
	return col


func _level_block() -> Control:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_level = Meter.new()
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level.track = ArmPanel.COL_TILE
	_level.edge = ArmPanel.COL_TILE_EDGE
	_level.ground = ArmPanel.COL_PAPER
	row.add_child(_level)
	_level_text = _label("", 17, ArmPanel.COL_INK, true)
	_level_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_text.custom_minimum_size = Vector2(180, 0)
	row.add_child(_level_text)


	var list:= VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	col.add_child(list)
	for i in 6:
		var slot:= HBoxContainer.new()
		slot.add_theme_constant_override("separation", 8)
		slot.visible = false
		var rect:= TextureRect.new()
		rect.name = "Icon"
		rect.custom_minimum_size = Vector2(24, 24)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		slot.add_child(rect)
		var text:= _label("", 15, ArmPanel.COL_INK_SOFT)
		text.name = "Text"
		slot.add_child(text)
		list.add_child(slot)
		_slots.append(slot)
	return col


func _flow_block() -> Control:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)


	_flow = _label(tr("%s a minute") % "0", 22, ArmPanel.COL_INK, true)
	row.add_child(_flow)
	var tail:= _label(tr("actually coming out"), 15, ArmPanel.COL_INK_SOFT)
	tail.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(tail)
	_note = _label("", 14, ArmPanel.COL_INK_SOFT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(PANEL_W - 40.0, 0.0)
	col.add_child(_note)
	return col


func _spacer(h: int) -> Control:
	var c:= Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _step_button(by: float) -> Button:
	var b:= Button.new()
	b.custom_minimum_size = Vector2(58, 40)
	b.focus_mode = Control.FOCUS_NONE


	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 16)
	_face(b, ArmPanel.COL_INK)
	_plate(b)
	b.pressed.connect(_on_step.bind(by))
	return b


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)


class Dial extends Control:
	signal changed(loads_per_minute: float)


	const TRACK_H:= 26.0
	const GRAB_W:= 14.0
	const GRAB_OVER:= 6.0


	const TICK_EVERY:= 60.0

	var maximum:= 300.0
	var notch:= 10.0
	var dragging:= false


	var stopped:= false
	var track:= Color.BLACK
	var edge:= Color.GRAY
	var fill:= Color.ORANGE
	var grab:= Color.WHITE
	var ground:= Color.BLACK

	var _value:= 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(120, TRACK_H + GRAB_OVER * 2.0)
		mouse_filter = Control.MOUSE_FILTER_STOP


	func set_reading(loads_per_minute: float) -> void:
		var v:= clampf(loads_per_minute, 0.0, maximum)
		if is_equal_approx(v, _value):
			return
		_value = v
		queue_redraw()

	func reading() -> float:
		return _value

	func _gui_input(event: InputEvent) -> void:
		var click:= event as InputEventMouseButton
		if click != null and click.button_index == MOUSE_BUTTON_LEFT:
			dragging = click.pressed
			if click.pressed:
				_take(click.position.x)
			accept_event()
			return
		var move:= event as InputEventMouseMotion
		if move != null and dragging:
			_take(move.position.x)
			accept_event()


	func _take(x: float) -> void:
		var span:= maxf(size.x - GRAB_W, 1.0)
		var frac:= clampf((x - GRAB_W * 0.5) / span, 0.0, 1.0)
		var want: float = round(frac * maximum / notch) * notch
		if is_equal_approx(want, _value):
			return
		_value = want
		queue_redraw()
		changed.emit(_value)

	func _draw() -> void:
		var top:= (size.y - TRACK_H) * 0.5
		var box:= Rect2(0.0, top, size.x, TRACK_H)
		draw_rect(box, track)
		var frac:= _value / maxf(maximum, 0.001)


		var lit:= GRAB_W * 0.5 + (size.x - GRAB_W) * frac
		if frac > 0.0 and not stopped:
			draw_rect(Rect2(0.0, top, lit, TRACK_H), fill)


		var at:= TICK_EVERY
		while at < maximum:
			var x:= GRAB_W * 0.5 + (size.x - GRAB_W) * (at / maximum)
			draw_rect(Rect2(x - 1.0, top + 4.0, 2.0, TRACK_H - 8.0),
				Color(ground.r, ground.g, ground.b, 0.85))
			at += TICK_EVERY
		draw_rect(box, edge, false, 2.0)
		var gx:= lit - GRAB_W * 0.5
		var gbox:= Rect2(gx, top - GRAB_OVER, GRAB_W, TRACK_H + GRAB_OVER * 2.0)
		draw_rect(gbox, edge.darkened(0.4) if stopped else grab)
		draw_rect(gbox, ground, false, 2.0)


class Meter extends Control:
	const BAR_H:= 22.0


	const DIVISIONS:= 10

	var fill:= 0.0
	var colour:= Color.ORANGE
	var track:= Color.BLACK
	var edge:= Color.GRAY
	var ground:= Color.BLACK

	func _init() -> void:
		custom_minimum_size = Vector2(120, BAR_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box:= Rect2(Vector2.ZERO, Vector2(size.x, BAR_H))
		draw_rect(box, track)
		var lit:= clampf(fill, 0.0, 1.0)
		if lit > 0.0:


			draw_rect(Rect2(0.0, 0.0, maxf(size.x * lit, 3.0), BAR_H), colour)
		for i in range(1, DIVISIONS):
			var x:= size.x * float(i) / float(DIVISIONS)
			draw_rect(Rect2(x - 1.0, 0.0, 2.0, BAR_H),
				Color(ground.r, ground.g, ground.b, 0.85))
		draw_rect(box, edge, false, 2.0)
