class_name DronePanel
extends Control


const REFRESH:= 0.25

const SHOW_SECONDS:= 120.0

const EXPLAIN_KEY:= "drone_plate"

var player: Player

var _drone: HayDrone
var _open:= false
var _panel: PanelContainer
var _state_word: Label
var _state_line: Label
var _power_chip: Control
var _power_word: Label
var _state_sign: TextureRect
var _explain: Label
var _power: Label
var _switch: ArmPanel.PowerToggle
var _show_btn: Button

var _show_why: Label

var _show_asked:= false

var _mode_rows: Dictionary = { }
var _mode_dots: Dictionary = { }
var _mode_whys: Dictionary = { }
var _mode_why: Label
var _modes_box: Control
var _mode_locked: Control

var _kinds_step: Control
var _kinds_box: Control
var _boxes: Dictionary = { }
var _ticks: Dictionary = { }
var _zone_row: Label
var _zone_x: LinkButton
var _zone_mark: Control
var _drop_row: Label
var _drop_x: LinkButton
var _drop_mark: Control
var _reach_line: Label
var _timer:= 0.0

var _refit:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func drone() -> HayDrone:
	return _drone


func open(from: HayDrone) -> void:
	if from == null:
		return
	_drone = from


	_drone.show_job(true, _drone.job_seconds_left())
	_show_asked = false
	_write_explainer()
	_refresh()


	_panel.modulate.a = 0.0
	_timer = 0.0
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

		if is_instance_valid(_drone) and _drone.job_seconds_left() <= 0.0:
			_drone.show_job(false)
		_drone = null


func _process(delta: float) -> void:
	if not _open:
		return
	if not is_instance_valid(_drone):
		close()
		return


	if _refit:
		_refit = false
		_fit()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_write_live()
	_panel.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_mode(m: int) -> void:
	if is_instance_valid(_drone):
		_drone.set_mode(m)
		if _drone.job_shown():
			_drone.show_job(true, _drone.job_seconds_left())
	_refresh()


func _on_tick(on: bool, bit: int) -> void:
	if is_instance_valid(_drone):
		_drone.set_accepting(bit, on)
	_refresh()


func _on_all(on: bool) -> void:
	if is_instance_valid(_drone):
		for kind: Dictionary in RoboticArm.PICK_KINDS:
			_drone.set_accepting(int(kind ["bit"]), on)
	_refresh()


func _on_switch() -> void:
	if is_instance_valid(_drone):
		_drone.set_switched_off(not _drone.is_switched_off())
	_refresh()


func _on_show() -> void:
	if not is_instance_valid(_drone):
		return
	_show_asked = true
	if _drone.job_shown() and _has_job():
		_drone.show_job(false)
		_show_asked = false
	elif _has_job():
		_drone.show_job(true, SHOW_SECONDS)
	_write_show()
	_fit()
	_refit = true


func _has_job() -> bool:
	return _drone.zone_at != Vector3.INF or _drone.drop_at != Vector3.INF


func _on_choose() -> void:
	var target:= _drone
	close()
	if player != null and player.drone_zone != null and is_instance_valid(target):
		player.drone_zone.begin(target)


func _on_clear_zone() -> void:
	if is_instance_valid(_drone):
		_drone.clear_zone()
	_refresh()


func _on_clear_drop() -> void:
	if is_instance_valid(_drone):
		_drone.clear_drop()
	_refresh()


func _refresh() -> void:
	if _state_word == null or not is_instance_valid(_drone):
		return
	_refit = true
	_switch.set_running(not _drone.is_switched_off())
	for m: int in _mode_rows:
		(_mode_rows [m] as Button).set_pressed_no_signal(m == _drone.mode)
		(_mode_dots [m] as ArmPanel.TileMark).set_on(m == _drone.mode)
	_mode_why.text = str(_mode_whys.get(_drone.mode, ""))


	var can_collect:= Tech.drone_collect_unlocked()
	_modes_box.visible = can_collect
	_mode_locked.visible = not can_collect
	for bit: int in _boxes:
		var on:= _drone.accepts(bit)
		(_boxes [bit] as Button).set_pressed_no_signal(on)
		(_ticks [bit] as ArmPanel.TileMark).set_on(on)
	var collecting:= can_collect and _drone.mode == HayDrone.Mode.COLLECT
	_kinds_step.visible = collecting
	_kinds_box.visible = collecting
	_write_live()


func _write_live() -> void:
	if not is_instance_valid(_drone):
		return
	_write_status()
	_write_where()
	_write_show()
	_power.text = MachinePower.rating_line_for(_drone, player)
	_power.visible = _power.text != ""
	_fit()


func _write_status() -> void:
	var status:= _drone.plate_status()
	ArmPanel.write_state(_state_word, _state_sign, int(status [0]))
	_state_line.text = str(status [1])
	ArmPanel.write_power_chip(_power_chip, _power_word,
		MachinePower.power_share_for(_drone, player))


func _write_where() -> void:
	var pad:= _drone.global_position
	var zone_set:= _drone.zone_at != Vector3.INF
	var drop_set:= _drone.drop_at != Vector3.INF
	if not zone_set:
		_zone_row.text = tr("Not set yet.")
		_zone_row.add_theme_color_override("font_color", ArmPanel.COL_INK_SOFT)
	else:
		_zone_row.text = tr("%.1f m circle, %.0f m from the pad") % [
			_drone.zone_r, _flat(_drone.zone_at, pad)]
		_zone_row.add_theme_color_override("font_color", ArmPanel.COL_INK)
	_zone_x.visible = zone_set
	_mark_set(_zone_mark, ArmPanel.COL_TAKE_INK, zone_set)
	if not drop_set:
		_drop_row.text = tr("Not set yet.")
		_drop_row.add_theme_color_override("font_color", ArmPanel.COL_INK_SOFT)
	else:
		var what:= tr("Floor")
		match _drone.drop_kind:
			HayDrone.Drop.BELT:
				what = tr("Belt")
			HayDrone.Drop.STAIRS:
				what = tr("Hay stairs")
		_drop_row.text = tr("%s, %.0f m from the pad") % [what, _flat(_drone.drop_at, pad)]
		_drop_row.add_theme_color_override("font_color", ArmPanel.COL_INK)
	_drop_x.visible = drop_set
	_mark_set(_drop_mark, ArmPanel.COL_PUT_INK, drop_set)
	_reach_line.text = tr("It works up to %.0f m from its pad. Loads carried: %d.") % [
		_drone.radius(), _drone.trips]


static func _mark_set(mark: Control, ink: Color, on: bool) -> void:
	var sb:= mark.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	sb.bg_color = ink if on else ArmPanel.COL_PAPER
	sb.border_color = ink
	sb.set_border_width_all(0 if on else 2)
	if mark.get_child_count() > 0:
		(mark.get_child(0) as CanvasItem).self_modulate = ArmPanel.COL_PAPER if on else ink


func _write_show() -> void:
	if _show_btn == null or not is_instance_valid(_drone):
		return
	var left:= _drone.job_seconds_left()
	var on:= _drone.job_shown() and _has_job()
	if on and left > 0.0:
		var s:= int(ceil(left))
		_show_btn.text = tr("HIDE ZONE  ·  %d:%02d") % [s / 60, s % 60]
	elif on:
		_show_btn.text = tr("HIDE ZONE")
	else:
		_show_btn.text = tr("SHOW ZONE")
	var missing:= ""
	if _drone.zone_at == Vector3.INF and _drone.drop_at == Vector3.INF:
		missing = tr("No zone or drop set up yet. Press SET ZONE AND DROP to choose them.")
	elif _drone.zone_at == Vector3.INF:
		missing = tr("No zone set up yet. Press SET ZONE AND DROP to choose one.")
	elif _drone.drop_at == Vector3.INF:
		missing = tr("No drop set up yet. Press SET ZONE AND DROP to choose one.")
	_show_why.text = missing
	_show_why.visible = _show_asked and missing != ""
	_show_btn.icon = PlateIcons.texture("eye_off" if on else "eye", 20)
	ArmPanel.light_button(_show_btn, on)


func _write_explainer() -> void:
	_explain.visible = Cfg.teach_hints and not Cfg.machine_seen(EXPLAIN_KEY)
	if _explain.visible:
		Cfg.see_machine(EXPLAIN_KEY)


func _fit() -> void:
	if _panel == null:
		return
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build() -> void:
	_panel = _card()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)


	whole.add_child(ArmPanel.band(tr("HAY DRONE"),
		tr("%s or ESC to close") % InputSetup.hint("interact"), close, _switch, false, "drone") [0])
	whole.add_child(_rule())
	var strip:= ArmPanel.status_strip()
	_state_word = strip [1]
	_state_line = strip [2]
	_power_chip = strip [3]
	_power_word = strip [4]
	_state_sign = strip [5]
	whole.add_child(strip [0])
	whole.add_child(_rule())
	var cols:= _inset(whole)
	var col:= _column(cols)
	cols.add_child(_column_rule())
	var right:= _column(cols)

	_explain = _body_label()
	_explain.text = tr("Give it a zone and a drop point. It digs the pile in the zone and flies the hay to the drop.")
	_explain.add_theme_color_override("font_color", ArmPanel.COL_INK)
	_explain.add_theme_font_size_override("font_size", 14)
	col.add_child(_explain)

	col.add_child(_step(tr("WHAT IT DOES"), false, "job"))
	var modes:= HBoxContainer.new()
	modes.add_theme_constant_override("separation", ArmPanel.TILE_GAP)
	_modes_box = modes
	col.add_child(modes)
	for answer: Array in [
		[HayDrone.Mode.DIG, "pile", tr("Dig the pile"),
			tr("Takes hay off the top of the pile in its zone, a clawful a trip.")],
		[HayDrone.Mode.COLLECT, "wad", tr("Collect things"),
			tr("Picks up what you tick below from its zone, one at a time.")],
	]:
		modes.add_child(_mode_tile(int(answer [0]), str(answer [1]), str(answer [2]),
			str(answer [3])))
	_mode_why = _body_label()
	_mode_why.add_theme_font_size_override("font_size", 14)
	col.add_child(_mode_why)
	_mode_locked = _locked_line(
		tr("Collecting things instead unlocks with Drone Pickup on the tech tree."))
	col.add_child(_mode_locked)

	_kinds_step = _step(tr("WHAT IT PICKS UP"), true, "picks")
	col.add_child(_kinds_step)
	var grid:= GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", ArmPanel.TILE_GAP)
	grid.add_theme_constant_override("v_separation", ArmPanel.TILE_GAP)
	_kinds_box = grid
	col.add_child(grid)
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		if HayDrone.COLLECT_KINDS.has(str(kind ["id"])):
			grid.add_child(_kind_cell(kind))

	right.add_child(_step(tr("WHERE IT WORKS"), false, "pin"))
	var zone:= _where_row(tr("ZONE"), ArmPanel.COL_TAKE_INK, _on_clear_zone,
		tr("Clear the zone"), "zone")
	_zone_row = zone [0]
	_zone_x = zone [1]
	_zone_mark = zone [3]
	right.add_child(zone [2])
	var drop:= _where_row(tr("DROP"), ArmPanel.COL_PUT_INK, _on_clear_drop,
		tr("Clear the drop"), "drop")
	_drop_row = drop [0]
	_drop_x = drop [1]
	_drop_mark = drop [3]
	right.add_child(drop [2])
	var choose:= _plate_button(_on_choose)
	choose.text = tr("SET ZONE AND DROP")
	PlateIcons.on_button(choose, "pin", 20, ArmPanel.COL_INK, ArmPanel.COL_LOCKED)
	right.add_child(choose)
	_reach_line = _body_label()
	right.add_child(_reach_line)
	var how:= _body_label()
	how.text = tr("The zone and the drop belong to this drone only. The drop can be a belt, hay stairs or the floor, but never the selling stand.")
	how.add_theme_font_size_override("font_size", 13)
	right.add_child(how)


	whole.add_child(_rule())
	var foot:= ArmPanel.foot(whole)
	var show_box:= VBoxContainer.new()
	show_box.add_theme_constant_override("separation", 2)
	show_box.custom_minimum_size.x = 260.0
	foot.add_child(show_box)
	_show_btn = _plate_button(_on_show)
	PlateIcons.on_button(_show_btn, "eye", 20, ArmPanel.COL_INK, ArmPanel.COL_LOCKED)
	show_box.add_child(_show_btn)
	_show_why = _label("", 12, ArmPanel.COL_WARN)
	_show_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_show_why.custom_minimum_size.x = 260.0
	_show_why.visible = false
	show_box.add_child(_show_why)
	_power = _label("", 13, ArmPanel.COL_INK_SOFT)
	_power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power.custom_minimum_size.y = MachineSwitch.HEIGHT
	_power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_power)


func _where_row(word: String, ink: Color, on_clear: Callable, tip: String,
		drawing: String) -> Array:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = ArmPanel.ROW_H
	var square:= ArmPanel.letter_badge("", ink, true, drawing)
	row.add_child(square)
	var head:= _label(word, 15, ink, true)
	head.custom_minimum_size.x = 64.0
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	var what:= _label("", 15, ArmPanel.COL_INK)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(what)
	var cross:= _link("×", on_clear)
	cross.add_theme_font_size_override("font_size", 20)
	cross.underline = LinkButton.UNDERLINE_MODE_NEVER
	cross.tooltip_text = tip
	row.add_child(cross)
	return [what, cross, row, square]


func _mode_tile(m: int, icon_id: String, answer: String, why: String) -> Control:
	var t:= ArmPanel.tile(ArmPanel.kind_icon(icon_id), answer, ArmPanel._tile_w(2))
	var row: Button = t ["button"]
	row.tooltip_text = why
	row.pressed.connect(_on_mode.bind(m))
	_mode_rows [m] = row
	_mode_dots [m] = t ["mark"]
	_mode_whys [m] = why
	return t ["holder"]


func _kind_cell(kind: Dictionary) -> Control:
	var bit:= int(kind ["bit"])
	var t:= ArmPanel.tile(ArmPanel.kind_icon(str(kind ["id"])), tr(str(kind ["name"])),
		ArmPanel._tile_w(4))
	var row: Button = t ["button"]
	row.tooltip_text = tr(str(kind ["note"]))
	row.toggled.connect(_on_tick.bind(bit))
	_boxes [bit] = row
	_ticks [bit] = t ["mark"]
	return t ["holder"]


func _card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(ArmPanel.CARD_W, 0.0)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = ArmPanel.COL_PAPER
	sb.border_color = ArmPanel.COL_INK
	sb.set_border_width_all(int(ArmPanel.RULE))
	sb.set_corner_radius_all(ArmPanel.RADIUS)
	sb.set_content_margin_all(0.0)
	card.add_theme_stylebox_override("panel", sb)
	return card


func _inset(whole: VBoxContainer) -> HBoxContainer:
	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(ArmPanel.PAD))
	inset.add_theme_constant_override("margin_right", int(ArmPanel.PAD))
	inset.add_theme_constant_override("margin_top", int(ArmPanel.PAD) - 4)
	inset.add_theme_constant_override("margin_bottom", int(ArmPanel.PAD))
	whole.add_child(inset)
	var cols:= HBoxContainer.new()
	cols.add_theme_constant_override("separation", int((ArmPanel.COL_GAP - 2.0) * 0.5))
	inset.add_child(cols)
	return cols


func _column(cols: HBoxContainer) -> VBoxContainer:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = ArmPanel.COL_W
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col)
	return col


func _column_rule() -> Control:
	var line:= ColorRect.new()
	line.color = Color(ArmPanel.COL_INK, 0.25)
	line.custom_minimum_size = Vector2(2.0, 0.0)
	return line


func _step(title: String, links: bool, icon: String) -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(PlateIcons.rect(icon, 22, ArmPanel.COL_INK))
	var heading:= _label(title, 16, ArmPanel.COL_INK, true)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)
	var fill:= Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	if links:
		row.add_child(_link(tr("All"), _on_all.bind(true)))
		row.add_child(_link(tr("None"), _on_all.bind(false)))
	var gap:= MarginContainer.new()
	gap.add_theme_constant_override("margin_top", 6)
	gap.add_child(row)
	return gap


func _link(text: String, on_pressed: Callable) -> LinkButton:
	var l:= LinkButton.new()
	l.text = text
	l.focus_mode = Control.FOCUS_NONE
	l.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_override("font", UiFont.bold())
	l.add_theme_font_size_override("font_size", 14)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		l.add_theme_color_override(state,
			ArmPanel.COL_INK if state != "font_hover_color" else ArmPanel.COL_INK_SOFT)
	l.pressed.connect(on_pressed)
	return l


func _plate_button(on_pressed: Callable) -> Button:
	var b:= Button.new()
	b.custom_minimum_size = Vector2(0.0, MachineSwitch.HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(ArmPanel.RADIUS)
		sb.set_border_width_all(2)
		sb.border_color = ArmPanel.COL_LOCKED if state == "disabled" else ArmPanel.COL_INK
		sb.bg_color = ArmPanel.COL_HOVER if state == "hover" else ArmPanel.COL_PAPER
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		b.add_theme_stylebox_override(state, sb)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		b.add_theme_color_override(colour, ArmPanel.COL_INK)
	b.add_theme_color_override("font_disabled_color", ArmPanel.COL_LOCKED)
	b.pressed.connect(on_pressed)
	return b


func _rule() -> Control:
	var line:= ColorRect.new()
	line.color = ArmPanel.COL_INK
	line.custom_minimum_size = Vector2(0.0, 2.0)
	return line


func _locked_line(text: String) -> Control:
	var box:= ArmPanel.DashedBox.new()
	box.ink = ArmPanel.COL_LOCKED
	var l:= _body_label()
	l.custom_minimum_size.x -= 20.0
	l.text = text
	l.add_theme_color_override("font_color", ArmPanel.COL_LOCKED)
	l.add_theme_font_size_override("font_size", 14)
	box.add_child(l)
	return box


func _body_label() -> Label:
	var l:= _label("", 15, ArmPanel.COL_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ArmPanel.COL_W, 0.0)
	return l


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
