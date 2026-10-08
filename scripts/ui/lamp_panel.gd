class_name LampPanel
extends Control


const PANEL_W:= 480.0

const PAD:= 18.0

const RULE:= 3.0


const RADIUS:= 0

var player: Player

var _lamp: WorkLamp
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _value: Label
var _stats: Label
var _dial: Dial

var _switch: ArmPanel.PowerToggle


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_open() -> bool:
	return _open


func lamp() -> WorkLamp:
	return _lamp


func open(from: WorkLamp) -> void:
	if from == null:
		return
	_lamp = from


	_dial.set_reading(from.brightness)
	_refresh()
	_set_open(true)


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
		_lamp = null


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_dial(v: float) -> void:
	if is_instance_valid(_lamp):
		_lamp.set_brightness(v)
	_refresh()


func _on_switch() -> void:
	if is_instance_valid(_lamp):
		_lamp.set_switched_off(not _lamp.is_switched_off())
	_refresh()


func _refresh() -> void:
	if _value == null or not is_instance_valid(_lamp):
		return
	_switch.set_running(not _lamp.is_switched_off())
	PlateKit.write_status(_top, _lamp,
		tr("Turn it down if it is too bright, up to light more of the room."), player)


	_dial.stopped = _lamp.is_switched_off()
	_dial.queue_redraw()
	if _lamp.is_switched_off():


		_value.text = tr("OFF")
		_stats.text = tr("Brightness is saved.")
		return
	_value.text = tr("lights %.0f m") % _lamp.lit_metres()


	_stats.text = tr("Brightness %.0f%%   ·   Charged %.0f%%") % [
		_lamp.brightness * 100.0, _lamp.charge() * 100.0]


func _build() -> void:
	_panel = PlateKit.card(PANEL_W)
	add_child(_panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	_top = PlateKit.top(whole, tr("WORK LAMP"), "work_lamp", close, _switch)
	var col:= PlateKit.body(whole, PANEL_W)

	col.add_child(PlateKit.heading(tr("HOW BRIGHT"), "bright"))
	_dial = Dial.new()
	_dial.minimum = Cfg.WORK_LAMP_BRIGHT_MIN
	_dial.maximum = 1.0


	_dial.notch = 0.01


	_dial.track = ArmPanel.COL_TILE
	_dial.edge = ArmPanel.COL_TILE_EDGE
	_dial.fill = ArmPanel.COL_TAKE_INK
	_dial.grab = ArmPanel.COL_INK
	_dial.ground = ArmPanel.COL_PAPER
	_dial.dim = ArmPanel.COL_INK_SOFT
	_dial.changed.connect(_on_dial)
	col.add_child(_dial)


	_value = _label("", 24, ArmPanel.COL_INK, true)
	col.add_child(_value)
	_stats = _body_label()
	col.add_child(_stats)


func _body_label() -> Label:
	var l:= _label("", 15, ArmPanel.COL_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - RULE * 2.0, 0.0)
	return l


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)


class Dial extends Control:
	signal changed(value: float)


	const TRACK_H:= 26.0
	const GRAB_W:= 14.0
	const GRAB_OVER:= 6.0


	const TICKS:= 4

	var minimum:= 0.0
	var maximum:= 1.0
	var notch:= 0.01
	var dragging:= false


	var stopped:= false
	var track:= Color.WHITE
	var edge:= Color.BLACK
	var fill:= Color.BLACK
	var grab:= Color.WHITE
	var ground:= Color.BLACK
	var dim:= Color.GRAY

	var _value:= 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(120, TRACK_H + GRAB_OVER * 2.0)
		mouse_filter = Control.MOUSE_FILTER_STOP


	func set_reading(v: float) -> void:
		var want:= clampf(v, minimum, maximum)
		if is_equal_approx(want, _value):
			return
		_value = want
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
		var raw:= minimum + (maximum - minimum) * frac
		var want:= clampf(round(raw / notch) * notch, minimum, maximum)
		if is_equal_approx(want, _value):
			return
		_value = want
		queue_redraw()
		changed.emit(_value)

	func _draw() -> void:
		var top:= (size.y - TRACK_H) * 0.5
		var box:= Rect2(0.0, top, size.x, TRACK_H)
		draw_rect(box, track)
		var range_span:= maxf(maximum - minimum, 0.001)
		var frac:= clampf((_value - minimum) / range_span, 0.0, 1.0)


		var lit:= GRAB_W * 0.5 + (size.x - GRAB_W) * frac
		if not stopped:
			draw_rect(Rect2(0.0, top, lit, TRACK_H), fill)
		for i in range(1, TICKS):
			var x:= GRAB_W * 0.5 + (size.x - GRAB_W) * (float(i) / float(TICKS))


			draw_rect(Rect2(x - 1.0, top + 4.0, 2.0, TRACK_H - 8.0),
				track if (x < lit and not stopped) else dim)
		draw_rect(box, edge, false, 2.0)
		var gx:= lit - GRAB_W * 0.5
		var gbox:= Rect2(gx, top - GRAB_OVER, GRAB_W, TRACK_H + GRAB_OVER * 2.0)
		draw_rect(gbox, dim if stopped else grab)
		draw_rect(gbox, ground, false, 2.0)
