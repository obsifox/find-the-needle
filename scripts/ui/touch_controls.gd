class_name TouchControls
extends CanvasLayer
## Mobile touch layer: virtual move stick, look-drag that feeds the existing
## mouse-motion look path, and action buttons that synthesize the same input
## events the keyboard/mouse bindings produce. Built for the FIND THE NEEDLE
## mobile build so every gameplay verb is reachable without a keyboard.

const STICK_R:= 150.0
const KNOB_R:= 62.0
const LOOK_SENS:= 0.0022
const MARGIN:= 26.0

const ACTIONS_TAP:= [
	"interact", "jump", "build_catalog", "tech_tree", "drop_tool",
]

var _stick_base: Vector2
var _stick_touch: int = -1
var _look_touch: int = -1
var _look_last: Vector2

var _stick_root: Control
var _knob: Control
var _btn_layer: Control

var _sprint_on:= false


func _ready() -> void:
	layer = 50
	Input.emulate_mouse_from_touch = false
	_build_stick()
	_build_buttons()


# ---------------------------------------------------------------- visuals --

func _circle(radius: float, fill: Color, line: Color) -> Control:
	var c:= Control.new()
	c.custom_minimum_size = Vector2(radius, radius) * 2.0
	c.draw.connect(func() -> void:
		c.draw_circle(Vector2(radius, radius), radius - 2.0, fill)
		c.draw_arc(Vector2(radius, radius), radius - 2.0, 0.0, TAU, 48, line, 2.0))
	return c


func _build_stick() -> void:
	_stick_root = Control.new()
	_stick_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_root.size = Vector2(STICK_R, STICK_R) * 2.0
	add_child(_stick_root)

	var base:= _circle(STICK_R, Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.22))
	base.position = Vector2.ZERO
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_root.add_child(base)

	_knob = _circle(KNOB_R, Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.45))
	_knob.position = Vector2(STICK_R, STICK_R) - Vector2(KNOB_R, KNOB_R)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_root.add_child(_knob)
	_place_bottom_left(_stick_root, Vector2(MARGIN + STICK_R, MARGIN + STICK_R))


func _place_bottom_left(c: Control, centre: Vector2) -> void:
	var vp:= _view_size()
	c.position = Vector2(centre.x, vp.y - centre.y) - c.size * 0.5


func _place_bottom_right(c: Control, centre: Vector2) -> void:
	var vp:= _view_size()
	c.position = Vector2(vp.x - centre.x, vp.y - centre.y) - c.size * 0.5


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _build_buttons() -> void:
	_btn_layer = Control.new()
	_btn_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_btn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_btn_layer)

	var vp:= _view_size()

	# --- primary cluster (right thumb): DIG / SECONDARY / JUMP / INTERACT --
	_add_hold("DIG", Vector2(vp.x - 130.0, vp.y - 150.0), func() -> void: _mouse_btn(MOUSE_BUTTON_LEFT, true), func() -> void: _mouse_btn(MOUSE_BUTTON_LEFT, false))
	_add_hold("USE", Vector2(vp.x - 260.0, vp.y - 90.0), func() -> void: _mouse_btn(MOUSE_BUTTON_RIGHT, true), func() -> void: _mouse_btn(MOUSE_BUTTON_RIGHT, false))
	_add_hold("JUMP", Vector2(vp.x - 130.0, vp.y - 290.0), func() -> void: Input.action_press("jump"), func() -> void: Input.action_release("jump"))
	_add_tap("E", Vector2(vp.x - 260.0, vp.y - 230.0), func() -> void: _tap_action("interact"))
	_sprint_btn("RUN", Vector2(vp.x - 390.0, vp.y - 110.0))

	# --- utility column (top right) -----------------------------------------
	_add_tap("MENU", Vector2(vp.x - 70.0, 110.0), func() -> void: _tap_action("free_mouse"))
	_add_tap("TECH", Vector2(vp.x - 70.0, 210.0), func() -> void: _tap_action("tech_tree"))
	_add_tap("BUILD", Vector2(vp.x - 70.0, 310.0), func() -> void: _tap_action("build_catalog"))
	_add_tap("Q", Vector2(vp.x - 70.0, 410.0), func() -> void: _tap_action("drop_tool"))

	# --- hotbar strip (top centre) ------------------------------------------
	var n:= 5
	for i in n:
		var idx: int = i + 1
		_add_tap(str(idx), Vector2(vp.x * 0.5 + (float(i) - float(n - 1) * 0.5) * 110.0, 70.0),
			func() -> void: _tap_action("hotbar_%d" % idx))


func _add_tap(label: String, centre: Vector2, on_press: Callable) -> Button:
	var b:= _make_btn(label, centre)
	b.button_down.connect(on_press)
	return b


func _add_hold(label: String, centre: Vector2, down: Callable, up: Callable) -> Button:
	var b:= _make_btn(label, centre)
	b.button_down.connect(down)
	b.button_up.connect(up)
	return b


func _sprint_btn(label: String, centre: Vector2) -> Button:
	var b:= _make_btn(label, centre)
	b.toggle_mode = true
	b.toggled.connect(func(on: bool) -> void:
		_sprint_on = on
		if on: Input.action_press("sprint")
		else: Input.action_release("sprint"))
	return b


func _make_btn(label: String, centre: Vector2) -> Button:
	var b:= Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 96)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, 0.55)
	style.set_corner_radius_all(18)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.28)
	b.add_theme_stylebox_override("normal", style)
	var style_down: StyleBoxFlat = style.duplicate()
	style_down.bg_color = Color(0.95, 0.85, 0.3, 0.7)
	b.add_theme_stylebox_override("pressed", style_down)
	_btn_layer.add_child(b)
	_place_bottom_right(b, centre) if centre.y > _view_size().y * 0.5 else _place_top_right(b, centre)
	return b


func _place_top_right(c: Control, centre: Vector2) -> void:
	var vp:= _view_size()
	c.position = Vector2(vp.x - centre.x, centre.y) - c.size * 0.5


# ------------------------------------------------------------------ input --

func _mouse_btn(button: int, pressed: bool) -> void:
	var ev:= InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = _view_size() * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _tap_action(action: String) -> void:
	Input.action_press(action)
	var timer:= get_tree().create_timer(0.08)
	timer.timeout.connect(func() -> void: Input.action_release(action))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st:= event as InputEventScreenTouch
		if st.pressed:
			_touch_start(st.index, st.position)
		else:
			_touch_end(st.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var dr:= event as InputEventScreenDrag
		if dr.index == _stick_touch:
			_stick_move(dr.position)
		elif dr.index == _look_touch:
			_look_move(dr.position)
		get_viewport().set_input_as_handled()


func _touch_start(index: int, pos: Vector2) -> void:
	if _over_button(pos):
		return
	var vp:= _view_size()
	# left-bottom quadrant -> move stick
	if pos.x < vp.x * 0.42 and pos.y > vp.y * 0.45:
		if _stick_touch == -1:
			_stick_touch = index
			_stick_base = pos
			_stick_root.position = pos - Vector2(STICK_R, STICK_R)
			_knob.position = Vector2(STICK_R, STICK_R) - Vector2(KNOB_R, KNOB_R)
			_stick_root.visible = true
		return
	# otherwise -> look drag
	if _look_touch == -1:
		_look_touch = index
		_look_last = pos


func _touch_end(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_release_move()
		_stick_root.visible = false
	elif index == _look_touch:
		_look_touch = -1


func _over_button(pos: Vector2) -> bool:
	for c in _btn_layer.get_children():
		if c is Control and (c as Control).get_global_rect().has_point(pos):
			return true
	return false


func _stick_move(pos: Vector2) -> void:
	var d:= pos - _stick_base
	var len:= d.length()
	if len > STICK_R:
		d = d / len * STICK_R
		len = STICK_R
	_knob.position = Vector2(STICK_R, STICK_R) + d - Vector2(KNOB_R, KNOB_R)
	var str := clampf(len / STICK_R, 0.0, 1.0)
	var fwd: float = clampf(-d.y / STICK_R, -1.0, 1.0)
	var side: float = clampf(d.x / STICK_R, -1.0, 1.0)
	_apply_axis("move_forward", "move_back", fwd * str)
	_apply_axis("move_right", "move_left", side * str)


func _apply_axis(pos_action: String, neg_action: String, value: float) -> void:
	if value > 0.02:
		Input.action_release(neg_action)
		Input.action_press(pos_action, value)
	elif value < -0.02:
		Input.action_release(pos_action)
		Input.action_press(neg_action, -value)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func _release_move() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)


func _look_move(pos: Vector2) -> void:
	var d:= pos - _look_last
	_look_last = pos
	if d == Vector2.ZERO:
		return
	var ev:= InputEventMouseMotion.new()
	ev.relative = d * LOOK_SENS * 100.0
	ev.screen_relative = ev.relative
	ev.position = _view_size() * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)
