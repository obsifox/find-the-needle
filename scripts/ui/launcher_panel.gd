class_name LauncherPanel
extends Control


const PANEL_W:= 520.0

var player: Player

var _launcher: TubeLauncher
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _value: Label
var _stats: Label
var _angle: HSlider
var _power: HSlider

var _switch: ArmPanel.PowerToggle

var _pin: Button


var _mains: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_open() -> bool:
	return _open


func launcher() -> TubeLauncher:
	return _launcher


func open(from: TubeLauncher) -> void:
	if from == null:
		return


	var want_aim:= from.aim
	var want_power:= from.power
	_launcher = from
	_angle.min_value = Cfg.LAUNCHER_TILT_MIN
	_angle.max_value = Cfg.LAUNCHER_TILT_MAX
	_angle.step = 1.0
	_angle.value = TubeLauncher.tilt_for(want_aim)
	_power.min_value = 0.0
	_power.max_value = 1.0


	_power.step = 0.005
	_power.value = want_power
	_launcher.aim = want_aim
	_launcher.power = want_power
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


	_show_arc(on)
	if not on:
		_launcher = null


func _show_arc(on: bool) -> void:
	if is_instance_valid(_launcher):
		_launcher.show_arc(on)


func _process(_delta: float) -> void:


	if _open and is_instance_valid(_launcher):
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_angle(degrees: float) -> void:
	if is_instance_valid(_launcher):
		_launcher.aim = TubeLauncher.aim_for_tilt(degrees)
		_launcher.show_arc(true)
	_refresh()


func _on_power(v: float) -> void:
	if is_instance_valid(_launcher):
		_launcher.power = v


		_launcher.show_arc(true)
	_refresh()


func _on_switch() -> void:
	if is_instance_valid(_launcher):
		_launcher.set_switched_off(not _launcher.is_switched_off())
	_refresh()


func _on_pin() -> void:
	RangePinButton.toggle(_launcher)
	_refresh()


func _refresh() -> void:
	if _value == null or not is_instance_valid(_launcher):
		return
	_switch.set_running(not _launcher.is_switched_off())
	PlateKit.write_pin(_pin, _launcher.range_pinned_left())
	_value.text = "%.0f m" % _launcher.range_metres()
	_mains.text = MachinePower.rating_line_for(_launcher, player)


	PlateKit.write_status(_top, _launcher, tr("Angle sets how high, power sets how far."),
		player)


	_stats.text = tr("%.0f deg   ·   power %.1f%%   ·   throws whatever reaches it") % [
		_launcher.tilt_now(), _launcher.power * 100.0]


func _build() -> void:
	_panel = PlateKit.card(PANEL_W, PlateKit.GLASS)
	add_child(_panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	_top = PlateKit.top(whole, tr("TUBE LAUNCHER"), "launcher", close, _switch)
	var col:= PlateKit.body(whole, PANEL_W)
	var inner:= col.custom_minimum_size.x


	col.add_child(PlateKit.heading(tr("ANGLE"), "angle"))
	_angle = _new_slider()
	_angle.value_changed.connect(_on_angle)
	col.add_child(_angle)


	col.add_child(PlateKit.heading(tr("POWER", "throw strength"), "gauge"))
	_power = _new_slider()
	_power.value_changed.connect(_on_power)
	col.add_child(_power)


	col.add_child(PlateKit.heading(tr("HOW FAR IT THROWS"), "throw"))
	_value = _label("", 26, ArmPanel.COL_INK, true)
	col.add_child(_value)
	_stats = PlateKit.note("", inner, 15)
	col.add_child(_stats)

	var foot:= PlateKit.foot(whole)
	_pin = PlateKit.button(Cfg.tr("Show Range"), "eye", _on_pin)
	_pin.custom_minimum_size.x = 220.0
	_pin.size_flags_horizontal = Control.SIZE_FILL
	foot.add_child(_pin)
	_mains = PlateKit.power_line()
	foot.add_child(_mains)


func _new_slider() -> HSlider:
	var s:= HSlider.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PlateKit.slider(s)
	return s


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
