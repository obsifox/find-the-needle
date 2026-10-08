class_name PolePanel
extends Control


const PANEL_W:= 480.0

const PAD:= 18.0

const RULE:= 3.0


const REFRESH:= 0.25

var player: Player

var _pole: PowerPole
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _title: Label

var _readout: Label
var _count: Label

var _switch: ArmPanel.PowerToggle
var _pole_head: Label
var _pole_note: Label

var _pole_switch: ArmPanel.PowerToggle
var _timer:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func pole() -> PowerPole:
	return _pole


func open(from: PowerPole) -> void:
	if from == null:
		return
	_pole = from
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
		_pole = null


func _process(delta: float) -> void:
	if not _open:
		return
	if not is_instance_valid(_pole):
		close()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_switch() -> void:
	var grid:= _grid()
	if grid == null or not is_instance_valid(_pole):
		return
	grid.switch_line(_pole, grid.line_running(_pole))
	_refresh()


func _on_pole_switch() -> void:
	var grid:= _grid()
	if grid == null or not is_instance_valid(_pole):
		return
	grid.switch_pole(_pole, grid.pole_running(_pole))
	_refresh()


func _grid() -> PowerGrid:
	if player != null and player.build != null and player.build.builds != null:
		return player.build.builds.grid
	return null


func _refresh() -> void:
	if _title == null or not is_instance_valid(_pole):
		return
	_title.text = tr("CABLE BOX") if _pole is PowerBox else tr("POWER POLE")
	PlateKit.set_photo(_top ["photo"], "power_pole")
	_pole_head.text = tr("THIS BOX") if _pole is PowerBox else tr("THIS POLE")
	var grid:= _grid()
	if grid == null:
		return
	var switches:= grid.switches_of(_pole)
	var off:= 0
	for machine in switches:
		if bool(machine.call("is_switched_off")):
			off += 1
	var running:= grid.line_running(_pole)
	var all_off:= not switches.is_empty() and not running


	_readout.text = (tr("EVERYTHING ON THIS LINE IS SWITCHED OFF") if all_off
		else MachinePanel._network_text(grid.report(_pole)))
	var got:= grid.report(_pole)
	ArmPanel.write_state(_top ["word"], _top ["sign"], 2 if all_off else 0)
	ArmPanel.write_power_chip(_top ["chip"], _top ["chip_word"],
		float(got ["satisfaction"]) if bool(got ["connected"]) and not all_off else 1.0)


	var n:= switches.size()
	if off > 0 and not all_off:
		_count.text = tr_n("%d machine on this line  ·  %d switched off",
			"%d machines on this line  ·  %d switched off", n) % [n, off]
	else:
		_count.text = tr_n("%d machine on this line", "%d machines on this line", n) % n


	_switch.set_dead(switches.is_empty())
	var tip:= tr("TURN OFF THE WHOLE LINE")
	if switches.is_empty():
		tip = tr("NOTHING ON THIS LINE TO SWITCH")
	elif all_off:
		tip = tr("TURN ON THE WHOLE LINE")


	_switch.set_running(not all_off, tip)
	_refresh_pole(grid)


func _refresh_pole(grid: PowerGrid) -> void:
	var box:= _pole is PowerBox
	var mine:= grid.pole_switches(_pole)
	var n:= mine.size()
	var running:= grid.pole_running(_pole)
	_pole_switch.set_dead(mine.is_empty())
	if mine.is_empty():
		_pole_note.text = (tr("No machine is wired to this box.") if box
			else tr("No machine is wired to this pole."))
		_pole_switch.set_running(true, tr("NOTHING WIRED TO THIS BOX") if box
			else tr("NOTHING WIRED TO THIS POLE"))
		return
	if box:
		_pole_note.text = tr_n(
			"%d machine is wired to this box. The rest of the line keeps running.",
			"%d machines are wired to this box. The rest of the line keeps running.", n) % n
	else:
		_pole_note.text = tr_n(
			"%d machine is wired to this pole. The rest of the line keeps running.",
			"%d machines are wired to this pole. The rest of the line keeps running.", n) % n
	if running:
		_pole_switch.set_running(true, tr("TURN OFF THIS BOX'S MACHINES") if box
			else tr("TURN OFF THIS POLE'S MACHINES"))
	else:
		_pole_switch.set_running(false, tr("TURN ON THIS BOX'S MACHINES") if box
			else tr("TURN ON THIS POLE'S MACHINES"))


func _build() -> void:
	_panel = PlateKit.card(PANEL_W)
	add_child(_panel)

	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_top = PlateKit.top(whole, tr("POWER POLE"), "power_pole", close, null)
	_title = _top ["name"]
	_readout = _top ["line"]

	var col:= PlateKit.body(whole, PANEL_W)
	var width:= col.custom_minimum_size.x - 110.0

	col.add_child(PlateKit.heading(tr("LINE"), "plug"))
	var line_row:= HBoxContainer.new()
	line_row.add_theme_constant_override("separation", 12)
	col.add_child(line_row)
	var line_words:= VBoxContainer.new()
	line_words.add_theme_constant_override("separation", 2)
	line_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_row.add_child(line_words)
	_count = PlateKit.note("", width, 15)
	_count.add_theme_color_override("font_color", ArmPanel.COL_INK)
	line_words.add_child(_count)


	line_words.add_child(PlateKit.note(
		tr("Stops every machine on this line, generators too. Press again to start them all."),
		width))
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	line_row.add_child(_switch)

	var pole_head:= PlateKit.heading(tr("THIS POLE"), "pin")
	_pole_head = pole_head.get_child(0).get_child(1) as Label
	col.add_child(pole_head)
	var pole_row:= HBoxContainer.new()
	pole_row.add_theme_constant_override("separation", 12)
	col.add_child(pole_row)
	_pole_note = PlateKit.note("", width)
	_pole_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pole_row.add_child(_pole_note)
	_pole_switch = ArmPanel.PowerToggle.new()
	_pole_switch.pressed.connect(_on_pole_switch)
	pole_row.add_child(_pole_switch)


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
