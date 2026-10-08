class_name PelletizerPanel
extends Control


const PANEL_W:= 520.0


const REFRESH:= 0.25

var player: Player

var _mill: HayPelletizer
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _value: Label
var _stats: Label

var _power: Label
var _slider: HSlider

var _switch: ArmPanel.PowerToggle

var _pin: Button
var _timer:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func mill() -> HayPelletizer:
	return _mill


func open(from: HayPelletizer) -> void:
	if from == null:
		return


	var want:= from.throw_distance
	_mill = from
	_slider.min_value = Cfg.PELLETIZER_THROW_MIN
	_slider.max_value = Cfg.PELLETIZER_THROW_MAX
	_slider.step = 0.25
	_slider.value = want
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


	_show_range(on)
	if not on:
		_mill = null


func _show_range(on: bool) -> void:
	if player == null or player.build == null or player.build.builds == null:
		return
	player.build.builds.show_mill_range(_mill if on else null)


func _process(delta: float) -> void:
	if not _open:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_write_power()
	if is_instance_valid(_mill):
		PlateKit.write_pin(_pin, _mill.range_pinned_left())


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_slider(v: float) -> void:
	if is_instance_valid(_mill):


		_mill.set_throw_distance(v)


		_mill.show_range(true)
	_refresh()


func _on_switch() -> void:
	if is_instance_valid(_mill):
		_mill.set_switched_off(not _mill.is_switched_off())
	_refresh()


func _on_pin() -> void:
	RangePinButton.toggle(_mill)
	_refresh()


func _refresh() -> void:
	if _value == null:
		return
	if is_instance_valid(_mill):
		_switch.set_running(not _mill.is_switched_off())
		PlateKit.write_pin(_pin, _mill.range_pinned_left())
	_value.text = "%.2f m" % _slider.value
	var secs:= Tech.pellet_cycle_seconds()
	var per:= Tech.pellet_brick_strands()
	_stats.text = tr("one brick every %.1f s   ·   %d straw each   ·   %d may lie on the pad") % [secs, per, Cfg.PELLETIZER_PAD_BRICKS]
	_write_power()


func _write_power() -> void:
	if _power == null:
		return
	_power.text = MachinePower.rating_line_for(_mill, player)
	PlateKit.write_status(_top, _mill,
		tr("How far out it throws its bricks. Keep that circle clear."), player)


func _build() -> void:
	_panel = PlateKit.card(PANEL_W, PlateKit.GLASS)
	add_child(_panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	_top = PlateKit.top(whole, tr("PELLETIZER"), "pelletizer", close, _switch)
	var col:= PlateKit.body(whole, PANEL_W)
	var inner:= col.custom_minimum_size.x

	col.add_child(PlateKit.heading(tr("HOW FAR IT THROWS"), "throw"))
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PlateKit.slider(_slider)
	_slider.value_changed.connect(_on_slider)
	row.add_child(_slider)
	_value = _label("", 22, ArmPanel.COL_INK, true)
	_value.custom_minimum_size.x = 90.0
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_value)

	col.add_child(PlateKit.heading(tr("WHAT IT DOES"), "job"))
	_stats = PlateKit.note("", inner, 15)
	col.add_child(_stats)

	var foot:= PlateKit.foot(whole)
	_pin = PlateKit.button(Cfg.tr("Show Range"), "eye", _on_pin)
	_pin.custom_minimum_size.x = 220.0
	_pin.size_flags_horizontal = Control.SIZE_FILL
	foot.add_child(_pin)
	_power = PlateKit.power_line()
	foot.add_child(_power)


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
