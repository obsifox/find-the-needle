class_name MachinePanel
extends Control


const PANEL_W:= 480.0

const PAD:= 18.0

const RULE:= 3.0
const REFRESH:= 0.25


const DRAWS_MAX_H:= 360.0
const DRAWS_MAX_SCREEN:= 0.45

var player: Player


var hud: Hud

var _machine: Node3D
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _title: Label


var _readout: Label

var _line_head: Control
var _product: Label
var _budget: Label


var _draws: GridContainer
var _draws_scroll: ScrollContainer

var _sheet: GridContainer
var _sheet_rule: ColorRect

var _status: Label


var _warn: Label
var _warn_h:= 0.0

var _switch: ArmPanel.PowerToggle
var _timer:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func machine() -> Node3D:
	return _machine


func open(from: Node3D) -> void:
	if from == null or not from.has_method("set_switched_off"):
		return
	if from != _machine and _draws_scroll != null:
		_draws_scroll.scroll_vertical = 0
		_warn_h = 0.0
	_machine = from
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
		_machine = null


func _process(delta: float) -> void:
	if not _open:
		return
	if not is_instance_valid(_machine):
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
	if not is_instance_valid(_machine):
		return
	_machine.call("set_switched_off", not bool(_machine.call("is_switched_off")))
	_refresh()


func _refresh() -> void:
	if _title == null or not is_instance_valid(_machine):
		return
	var off:= bool(_machine.call("is_switched_off"))
	_title.text = _name_of(_machine)
	var line:= hud._machine_diagnostic(_machine) if hud != null else ""


	var first:= line.get_slice("\n", 0)


	var dark:= _dark_line()
	if dark != "":
		first = dark


	var alert:= ""
	if _machine.has_method("alert_reason"):
		alert = str(_machine.call("alert_reason"))
	var line_label: Label = _top ["line"]
	if off:
		ArmPanel.write_state(_readout, _top ["sign"], 2)
		_readout.text = tr("SWITCHED OFF")
		line_label.text = ""
	elif dark != "":
		ArmPanel.write_state(_readout, _top ["sign"], 2)
		line_label.text = dark
	elif alert != "":
		ArmPanel.write_state(_readout, _top ["sign"], 2)
		var cut:= alert.find("  ·  ")
		_readout.text = alert.substr(0, cut) if cut >= 0 else alert
		line_label.text = alert.substr(cut + 5) if cut >= 0 else first
	else:
		ArmPanel.write_state(_readout, _top ["sign"], 0)


		line_label.text = "" if _machine is HayGenerator else first
	ArmPanel.write_power_chip(_top ["chip"], _top ["chip_word"],
		MachinePower.power_share_for(_machine, player))
	PlateKit.set_photo(_top ["photo"], _tile_of(_machine))


	_product.text = hud._machine_product(_machine) if hud != null else ""


	_product.visible = _product.text != "" and not (_machine is HayGenerator)
	_switch.set_running(not off)
	_write_budget()
	_line_head.visible = _budget.visible or _draws_scroll.visible or _sheet.visible


func _dark_line() -> String:
	if _machine is HayGenerator or not _machine.has_method("draw_kw"):
		return ""
	var grid:= _grid()
	if grid == null:
		return ""
	var state:= grid.line_state(_machine)
	if state == MachinePower.LINE_OK:
		return ""
	return MachinePower.fault(0.0, false, state)


func _grid() -> PowerGrid:
	if player != null and player.build != null and player.build.builds != null:
		return player.build.builds.grid
	return null


func _write_budget() -> void:


	if not _write_sheet():
		_write_draws(PackedStringArray())
		_fill(_sheet, PackedStringArray())
		_status.visible = false
		_write_warnings(PackedStringArray())
	_budget.visible = _budget.text != ""
	_sheet_rule.visible = _sheet.visible and _draws_scroll.visible


func _write_sheet() -> bool:
	_budget.text = ""
	var grid:= _grid()


	var mine:= MachinePower.rating_line(_machine, grid)
	if grid == null:
		_budget.text = mine
		return false
	var got: Dictionary = grid.report(_machine)
	if not bool(got ["connected"]):
		_budget.text = _rows(mine, tr("Not on a network.  Put a power pole near it."))
		return false
	if not (_machine is HayGenerator):


		_budget.text = _rows(mine, tr("the whole line:  %s") % _network_text(got))
		return false
	var rows: PackedStringArray = []
	var sheet: PackedStringArray = []
	var warn: PackedStringArray = []
	var machines:= grid.members_of(_machine)
	var draws: Array [Dictionary] = []
	for m: Node3D in machines:
		if not m.has_method("draw_kw"):
			continue
		var kw:= float(m.call("draw_kw"))


		var name:= _quiet_name_of(m)
		if m.has_method("is_switched_off") and bool(m.call("is_switched_off")):
			name += "  " + tr("(off)")
		draws.append({ "name": name, "kw": kw })
	draws.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a ["kw"]) > float(b ["kw"]))
	for row: Dictionary in draws:
		rows.append("%s\t%s" % [str(row ["name"]), tr("%.1f kW") % float(row ["kw"])])
	if draws.is_empty():
		rows.append(tr("nothing is drawing on this line"))
	_write_draws(rows)


	var gen:= _machine as HayGenerator
	var plant:= _machine as GasPlant
	sheet.append(_cell(tr("this gas plant makes") if plant != null else tr("this generator makes"),
		tr("%.1f of %.1f kW") % [gen.output_kw(), gen.rated_output_kw()]))
	sheet.append(_cell(tr("the whole line needs"), tr("%.1f kW") % float(got ["demand"])))
	_hay_rows(sheet, gen, machines)
	if plant != null:


		sheet.append(_cell(tr("each straw gives"),
			tr("%d kJ, eco bricks only") % int(round(gen.kj_per_strand()))))
		sheet.append(_cell(tr("water"), tr("%d%%") % int(round(plant.water * 100.0))))
		sheet.append(_cell(tr("water tank"), tr("%d of %d seconds") % [
			int(round(plant.tank_seconds())), int(Cfg.GAS_PLANT_TANK_SECONDS)]))
	else:
		sheet.append(_cell(tr("each straw gives"),
			tr("%d kJ, loose or pressed") % int(round(gen.kj_per_strand()))))
	_fill(_sheet, sheet)


	var satisfaction:= float(got ["satisfaction"])
	var short:= satisfaction < 0.999
	if short:
		_status.text = tr("Short: %.1f kW") % maxf(float(got ["demand"]) - float(got ["supply"]), 0.0)
	else:
		_status.text = tr("Spare: %.1f kW") % float(got.get("spare", 0.0))
	_status.add_theme_color_override("font_color", ArmPanel.COL_WARN if short else ArmPanel.COL_GO)
	_status.visible = true


	if short:
		warn.append(tr("Machines run at %d%%") % int(round(satisfaction * 100.0)))


	var cold:= _cold_generators(grid)
	if cold > 0:


		warn.append(tr_n("%d generator has no hay", "%d generators have no hay", cold) % cold)
	_write_warnings(warn)
	return true


func _write_warnings(warn: PackedStringArray) -> void:
	_warn.text = "\n".join(warn)
	_warn_h = maxf(_warn_h, _warn.get_minimum_size().y if not warn.is_empty() else 0.0)
	_warn.custom_minimum_size.y = _warn_h
	_warn.visible = _warn_h > 0.0


static func _cell(label: String, value: String) -> String:
	return label + "\t" + value


func _fill(grid: GridContainer, rows: PackedStringArray) -> void:
	var want:= rows.size() * 2
	while grid.get_child_count() < want:
		var left:= grid.get_child_count() % 2 == 0
		var l:= _label("", 14 if left else 15, ArmPanel.COL_INK_SOFT if left else ArmPanel.COL_INK, not left)
		if left:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(l)
	while grid.get_child_count() > want:
		var last:= grid.get_child(grid.get_child_count() - 1)
		grid.remove_child(last)
		last.queue_free()
	for i in rows.size():
		var cells:= rows [i].split("\t", true, 1)
		(grid.get_child(i * 2) as Label).text = cells [0]
		(grid.get_child(i * 2 + 1) as Label).text = cells [1] if cells.size() > 1 else ""
	grid.visible = not rows.is_empty()


func draw_rows() -> int:
	return _draws.get_child_count() / 2


func _write_draws(rows: PackedStringArray) -> void:
	_fill(_draws, rows)
	_draws_scroll.visible = not rows.is_empty()
	if rows.is_empty():
		return
	_draws_scroll.custom_minimum_size.y = minf(_draws.get_combined_minimum_size().y, _draws_cap())


func _draws_cap() -> float:
	var view:= get_viewport()
	if view == null:
		return DRAWS_MAX_H
	return minf(DRAWS_MAX_H, view.get_visible_rect().size.y * DRAWS_MAX_SCREEN)


func _hay_rows(sheet: PackedStringArray, gen: HayGenerator, machines: Array [Node3D]) -> void:
	sheet.append(_cell(tr("burning"), tr("%.1f straws a second") % gen.burning_strands()))
	sheet.append(_cell(tr("coming in"), tr("about %.1f straws a second") % gen.arriving))


	var box:= tr("%d of %d straws") % [gen.box_strands(), gen.box_capacity_strands()]
	if gen.fuel_seconds() > 0.0:
		box = tr("%s, %s", "box and time left") % [box, Hud._clock(gen.fuel_seconds())]
	sheet.append(_cell(tr("in the box"), box))
	var total:= 0.0
	var count:= 0
	for m: Node3D in machines:
		if m is HayGenerator:
			total += (m as HayGenerator).burning_strands()
			count += 1
	if count > 1:
		sheet.append(_cell(tr("the whole line burns"), tr("%.1f straws a second") % total))


func _cold_generators(grid: PowerGrid) -> int:
	var n:= 0
	for m: Node3D in grid.members_of(_machine):
		var gen:= m as HayGenerator
		if gen == null or gen.is_switched_off():
			continue
		if gen.fuel <= 0.0 and gen.output_kw() <= 0.0:
			n += 1
	return n


static func _rows(a: String, b: String) -> String:
	if a == "" or b == "":
		return a + b
	return a + "\n" + b


static func _network_text(got: Dictionary) -> String:
	var supply:= float(got ["supply"])
	var demand:= float(got ["demand"])
	var satisfaction:= float(got ["satisfaction"])


	var text:= Cfg.tr("needs %.1f kW  ·  makes %.1f kW") % [demand, supply]
	if satisfaction < 0.999:
		return Cfg.tr("%s  ·  SHORT %.1f kW  ·  everything at %d%%") % [
			text, maxf(demand - supply, 0.0), int(round(satisfaction * 100.0))]
	return Cfg.tr("%s  ·  %.1f kW spare") % [text, float(got.get("spare", 0.0))]


static func _name_of(node: Node3D) -> String:
	var id:= _id_of(node)
	if id == "":
		return str(node.name).to_upper()
	return Cfg.upper(BuildCatalog.display_name(id))


static func _quiet_name_of(node: Node3D) -> String:
	match _id_of(node):
		"compressor":
			return Cfg.tr("hay compressor")
		"wrapper":
			return Cfg.tr("hay wrapper")
		"pelletizer":
			return Cfg.tr("hay pelletizer")
		"drone":
			return Cfg.tr("hay drone")
		"generator":
			return Cfg.tr("hay generator")
		"gas_plant":
			return Cfg.tr("gas plant")
		"borehole":
			return Cfg.tr("borehole pump")
		"silo":
			return Cfg.tr("hay silo")
		"rake":
			return Cfg.tr("piston rake")
		"arm":
			return Cfg.tr("robotic arm")
		"scanner":
			return Cfg.tr("haystack scanner")
		"launcher":
			return Cfg.tr("tube launcher")
		"pulper":
			return Cfg.tr("hay pulper")
		"paper_machine":
			return Cfg.tr("paper mill")
		"briquette_press":
			return Cfg.tr("feed disc press")


	return str(node.name).to_lower()


static func _id_of(node: Node3D) -> String:
	var id:= ""
	if node is HayCompressor:
		id = "compressor"
	elif node is HayWrapper:
		id = "wrapper"
	elif node is HayPelletizer:
		id = "pelletizer"
	elif node is HayDrone:
		id = "drone"
	elif node is GasPlant:
		id = "gas_plant"
	elif node is HayGenerator:
		id = "generator"
	elif node is BoreholePump:
		id = "borehole"
	elif node is HaySilo:
		id = "silo"
	elif node is PistonRake:
		id = "rake"
	elif node is RoboticArm:
		id = "arm"
	elif node is HaystackScanner:
		id = "scanner"
	elif node is TubeLauncher:
		id = "launcher"
	elif node is HayPulper:
		id = "pulper"
	elif node is PaperMachine:
		id = "paper_machine"
	elif node is BriquettePress:
		id = "briquette_press"
	return id


static func _tile_of(node: Node3D) -> String:
	var id:= _id_of(node)
	match id:
		"rake":
			return "piston_rake"
		"generator":
			return "electricity"
	return id


func _build() -> void:
	_panel = PlateKit.card(PANEL_W)
	add_child(_panel)

	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	_top = PlateKit.top(whole, tr("MACHINE"), "*", close, _switch)
	_title = _top ["name"]
	_readout = _top ["word"]

	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(PAD))
	inset.add_theme_constant_override("margin_right", int(PAD))
	inset.add_theme_constant_override("margin_top", int(PAD) - 4)
	inset.add_theme_constant_override("margin_bottom", int(PAD))
	whole.add_child(inset)

	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inset.add_child(col)

	var width:= PANEL_W - PAD * 2.0 - RULE * 2.0


	_product = _label("", 14, ArmPanel.COL_INK)
	_product.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_product.custom_minimum_size = Vector2(width, 0.0)
	col.add_child(_product)

	_line_head = PlateKit.heading(tr("LINE"), "plug")
	col.add_child(_line_head)

	_draws_scroll = ScrollContainer.new()
	_draws_scroll.custom_minimum_size = Vector2(width, 0.0)
	_draws_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_draws_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_draws_scroll.visible = false
	col.add_child(_draws_scroll)


	var bar:= _draws_scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", _bar_box(ArmPanel.COL_HOVER))
	bar.add_theme_stylebox_override("grabber", _bar_box(ArmPanel.COL_INK_SOFT))
	bar.add_theme_stylebox_override("grabber_highlight", _bar_box(ArmPanel.COL_INK))
	bar.add_theme_stylebox_override("grabber_pressed", _bar_box(ArmPanel.COL_INK))
	_draws = _grid_box()
	_draws_scroll.add_child(_draws)

	_budget = _label("", 14, ArmPanel.COL_INK_SOFT)
	_budget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_budget.custom_minimum_size = Vector2(width, 0.0)
	col.add_child(_budget)


	_sheet_rule = ColorRect.new()
	_sheet_rule.color = ArmPanel.COL_HOVER.darkened(0.12)
	_sheet_rule.custom_minimum_size = Vector2(0.0, 1.0)
	_sheet_rule.visible = false
	col.add_child(_sheet_rule)

	_sheet = _grid_box()
	_sheet.visible = false
	col.add_child(_sheet)

	_status = _label("", 15, ArmPanel.COL_GO, true)
	_status.visible = false
	col.add_child(_status)

	_warn = _label("", 14, ArmPanel.COL_WARN, true)
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.custom_minimum_size = Vector2(width, 0.0)
	_warn.visible = false
	col.add_child(_warn)


static func _grid_box() -> GridContainer:
	var g:= GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 3)
	return g


static func _bar_box(colour: Color) -> StyleBoxFlat:
	var box:= StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(0)
	box.content_margin_left = 3.0
	box.content_margin_right = 3.0
	return box


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return ArmPanel.label(text, size, colour, heavy)
