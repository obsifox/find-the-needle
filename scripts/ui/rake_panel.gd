class_name RakePanel
extends Control


const PANEL_W:= 520.0


const REFRESH:= 0.25

var player: Player

var _rake: PistonRake
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _value: Label
var _stats: Label

var _power: Label
var _slider: HSlider

var _switch: ArmPanel.PowerToggle

var _pin: Button

var _drive_note: Label

var _drive_box: VBoxContainer
var _back: Button
var _forward: Button
var _timer:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func rake() -> PistonRake:
	return _rake


func open(from: PistonRake) -> void:
	if from == null:
		return


	var want:= from.throw_distance


	if not from.is_driving():
		from.drive_blocked = ""
	_rake = from
	_slider.min_value = Cfg.RAKE_THROW_MIN
	_slider.max_value = Cfg.RAKE_THROW_MAX
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
		_rake = null


func _show_range(on: bool) -> void:
	if player == null or player.build == null or player.build.builds == null:
		return
	player.build.builds.show_rake_range(_rake if on else null)


func _process(delta: float) -> void:
	if not _open:
		return


	_lock_drive(is_instance_valid(_rake) and _rake.is_driving())
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_write_power()
	_write_drive()
	if is_instance_valid(_rake):
		PlateKit.write_pin(_pin, _rake.range_pinned_left())


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_slider(v: float) -> void:
	if is_instance_valid(_rake):
		_rake.throw_distance = v


		_rake.show_range(true)
	_refresh()


func _on_switch() -> void:
	if is_instance_valid(_rake):
		_rake.set_switched_off(not _rake.is_switched_off())
	_refresh()


func _on_pin() -> void:
	RangePinButton.toggle(_rake)
	_refresh()


func _on_drive(direction: float) -> void:
	if not is_instance_valid(_rake) or player == null or player.build == null:
		return
	_rake.drive(direction, player.build.rake_drive_reason)
	_lock_drive(_rake.is_driving())
	_write_drive()


func _lock_drive(on: bool) -> void:
	for b: Button in [_back, _forward]:
		if b != null and b.disabled != on:
			b.disabled = on


func _write_drive() -> void:
	if _drive_note == null:
		return
	_drive_box.visible = Tech.rake_wheels_unlocked()
	var why:= _rake.drive_blocked if is_instance_valid(_rake) else ""
	_drive_note.text = why
	_drive_note.visible = why != ""


func _refresh() -> void:
	if _value == null:
		return
	if is_instance_valid(_rake):
		_switch.set_running(not _rake.is_switched_off())
		PlateKit.write_pin(_pin, _rake.range_pinned_left())
	_value.text = "%.2f m" % _slider.value
	var per:= Tech.rake_bite_strands()
	var secs:= Tech.rake_throw_seconds()
	var a_minute:= float(per) * 60.0 / maxf(secs, 0.01)
	_stats.text = tr("one wad every %.1f s   ·   %.0f straw a minute") % [secs, a_minute]
	_write_power()
	_write_drive()


func _write_power() -> void:
	if _power == null:
		return
	_power.text = MachinePower.rating_line_for(_rake, player)
	PlateKit.write_status(_top, _rake, tr("How far behind itself it throws."), player)


func _build() -> void:
	_panel = PlateKit.card(PANEL_W, PlateKit.GLASS)
	add_child(_panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	_top = PlateKit.top(whole, tr("PISTON RAKE"), "piston_rake", close, _switch)
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

	_drive_box = VBoxContainer.new()
	_drive_box.add_theme_constant_override("separation", 8)
	_drive_box.visible = false
	col.add_child(_drive_box)
	_drive_box.add_child(PlateKit.heading(tr("MOVE IT"), "wheel"))
	_drive_box.add_child(PlateKit.note(tr("Move it without taking it down."), inner))
	var drive_row:= HBoxContainer.new()
	drive_row.add_theme_constant_override("separation", 10)
	_drive_box.add_child(drive_row)
	_back = _drive_button(tr("Back"), -1.0)
	_forward = _drive_button(tr("Forward"), 1.0)
	drive_row.add_child(_back)
	drive_row.add_child(_forward)
	_drive_note = PlateKit.note("", inner)
	_drive_note.add_theme_color_override("font_color", ArmPanel.COL_WAIT)
	_drive_note.visible = false
	_drive_box.add_child(_drive_note)

	var foot:= PlateKit.foot(whole)
	_pin = PlateKit.button(Cfg.tr("Show Range"), "eye", _on_pin)
	_pin.custom_minimum_size.x = 220.0
	_pin.size_flags_horizontal = Control.SIZE_FILL
	foot.add_child(_pin)
	_power = PlateKit.power_line()
	foot.add_child(_power)


func _drive_button(text: String, direction: float) -> Button:
	var b:= PlateKit.button(text, "forward" if direction > 0.0 else "back",
		_on_drive.bind(direction))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if direction > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	return b


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
