class_name NeedleInspector
extends Control


const COL_BACK:= Color(0.03, 0.035, 0.045, 0.965)
const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_TEXT:= Color(0.93, 0.95, 0.99)
const COL_DIM:= Color(0.74, 0.78, 0.86)
const COL_RULE:= Color(0.86, 0.72, 0.34, 0.55)

const REF_H:= 1080.0

const VIEW_FRACTION:= 0.6
const PANEL_W:= 420.0

const DRAG_SENS:= 0.01
const PITCH_LIMIT:= 1.35
const ZOOM_MIN:= 0.45
const ZOOM_MAX:= 1.6
const ZOOM_STEP:= 1.12

const IDLE_AFTER:= 0.9

var player: Player

var _open:= false
var _type:= -1


var _cabinet: NeedleCabinet
var _view: NeedleView
var _dragging:= false
var _idle:= 0.0
var _title: Label
var _body: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	_build()


func _build() -> void:
	_view = NeedleView.new()
	_view.name = "Specimen"


	add_child(_view)
	_title = _label(56, COL_TITLE, true)
	_body = _label(28, COL_TEXT, false)
	_hint = _label(24, COL_DIM, false)


func _label(size: int, colour: Color, heavy: bool) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 6, heavy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


func is_open() -> bool:
	return _open


func specimen_yaw() -> float:
	return _view.yaw if _view != null else 0.0


func open(type: int, cab: NeedleCabinet = null) -> void:
	_type = type
	_cabinet = cab
	_view.set_type(type)
	_view.yaw = 0.0
	_view.pitch = -0.18
	_view.zoom = 1.0
	_view.spin = NeedleView.IDLE_SPIN
	_idle = IDLE_AFTER
	_write()
	set_open(true)


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	set_process(on)
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_dragging = false
	if player != null:
		player.capture_mouse(not on)
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _write() -> void:
	_title.text = NeedleTypes.name_of(_type)
	var lines:= PackedStringArray()
	lines.append(tr("LOT %d") % (NeedleTypes.lot_of(_type) + 1))
	var one_in:= NeedleTypes.one_in(_type)
	lines.append(tr("CHANCE 1 IN %d  (%s)") % [one_in, _percent(one_in)])
	if NeedleTypes.has_effect(_type):
		lines.append("")
		lines.append("%s" % Cfg.upper(NeedleTypes.effect_name(_type)))
		lines.append(NeedleTypes.effect_text(_type))


		lines.append(tr("IN THE CASE") if GameState.is_discovered(_type)
			else tr("PUT IT IN THE CASE TO KEEP THIS"))
	lines.append("")
	lines.append(tr("HELD x%d") % GameState.stock_of(_type))
	lines.append(tr("FOUND x%d THIS RUN") % GameState.found_of(_type))
	_body.text = "\n".join(lines)
	var hints:= PackedStringArray([tr("DRAG TO TURN"), tr("WHEEL TO ZOOM")])


	if _can_take():
		hints.append(tr("F TO TAKE ONE"))
	hints.append(tr("%s OR ESC TO CLOSE") % Cfg.upper(InputSetup.hint("interact")))
	_hint.text = "  ·  ".join(hints)


func _percent(one_in: int) -> String:
	var pc:= 100.0 / float(maxi(one_in, 1))
	return Cfg.percent("%.0f" % pc if pc >= 10.0 else "%.1f" % pc)


func _gui_input(event: InputEvent) -> void:
	if not _open:
		return


	if event.is_action_pressed("secondary") and event is InputEventMouseButton:
		set_open(false)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb:= event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_idle = 0.0
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_view.zoom = clampf(_view.zoom / ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_view.zoom = clampf(_view.zoom * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm:= event as InputEventMouseMotion
		_view.yaw -= mm.relative.x * DRAG_SENS
		_view.pitch = clampf(_view.pitch - mm.relative.y * DRAG_SENS,
			- PITCH_LIMIT, PITCH_LIMIT)
		_view.spin = 0.0
		_idle = 0.0
		accept_event()


func _can_take() -> bool:
	return (_cabinet != null and is_instance_valid(_cabinet)
		and _cabinet.can_take(_type)
		and player != null and player.hand != null and not player.hand.is_holding())


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("inspect_needle"):


		if _can_take() and player.hand.withdraw_from(_cabinet, _type):
			set_open(false)
		get_viewport().set_input_as_handled()
		return


	if event.is_action_pressed("interact") or event.is_action_pressed("secondary") or event.is_action_pressed("free_mouse"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _dragging:
		_idle = 0.0
	else:
		_idle += delta
		if _idle >= IDLE_AFTER and is_zero_approx(_view.spin):


			_view.spin = NeedleView.IDLE_SPIN
	_layout()
	queue_redraw()


func _layout() -> void:
	var s:= size.y / REF_H
	var view_w:= size.x * VIEW_FRACTION
	_view.position = Vector2.ZERO
	_view.size = Vector2(view_w, size.y)

	var x:= view_w + 48.0 * s
	var w:= minf(PANEL_W * s, size.x - x - 40.0 * s)
	_title.position = Vector2(x, size.y * 0.26)
	_title.size = Vector2(w, 80.0 * s)
	_body.position = Vector2(x, size.y * 0.26 + 96.0 * s)
	_body.size = Vector2(w, size.y * 0.5)
	_hint.position = Vector2(x, size.y * 0.84)
	_hint.size = Vector2(w, 60.0 * s)


func _draw() -> void:
	if not _open:
		return
	var s:= size.y / REF_H
	draw_rect(Rect2(Vector2.ZERO, size), COL_BACK)


	var x:= size.x * VIEW_FRACTION + 20.0 * s
	draw_rect(Rect2(Vector2(x, size.y * 0.22),
		Vector2(maxf(2.0 * s, 1.0), size.y * 0.56)), COL_RULE)
