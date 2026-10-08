class_name DebugMenu
extends Control


const GRANTS: Array [float] = [100.0, 1000.0, 10000.0]


const HOLE:= "SEWING"


const PANEL_W:= 760.0


const PANEL_H:= 800.0


const PICKER_W:= 760.0
const PICKER_H:= 660.0


const LOOK_W:= 640.0
const LOOK_H:= 840.0
const PANEL_GUTTER:= 18.0


const DESIGN_H:= 900.0


const SCALE_MIN:= 1.0
const SCALE_MAX:= 2.2


const SCALE_BOOST:= 1.0


const ARM_SECONDS:= 4.0
const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_TEXT:= Color(0.92, 0.94, 0.98)
const COL_DIM:= Color(0.72, 0.76, 0.84)
const COL_MUTED:= Color(0.44, 0.48, 0.56)
const COL_CARD:= Color(0.08, 0.095, 0.12, 0.94)
const COL_CARD_HOVER:= Color(0.12, 0.14, 0.17, 0.98)


const COL_DANGER:= Color(0.94, 0.58, 0.46)


const NEEDLE_THROW:= 1.6
const NEEDLE_BELT_RANGE:= 14.0


const NEEDLE_BELT_LIFT:= 0.26


const SCANNER_FEED_LEAD:= 2.0


enum NeedleDest { FEET, BELT, SCANNER }


var world: Node3D

var player: Player
var props: PropManager
var hud: Hud
var live: LiveStrandManager
var builds: BuildManager

var wallhack: NeedleWallhack


var _scale:= 1.0

var _panel: PanelContainer

var _page: ScrollContainer
var _money_label: Label
var _open:= false


var _needle_modal: Control
var _needle_panel: PanelContainer
var _needle_where: Label
var _dest_buttons: Dictionary = { }
var _needle_dest: NeedleDest = NeedleDest.SCANNER


var _wallhack_button: Button

var _noclip_button: Button


var _zones_button: Button
var _bodies_button: Button
var _render_button: Button


var _view: DebugView
var _render_mode:= 0


var _look_modal: Control
var _look_panel: PanelContainer


var _look_refresh: Array [Callable] = []


var _sun_refresh: Array [Callable] = []


var _sun_elev:= 43.0
var _sun_azim:= 0.0


var _authored_gfx: Dictionary = { }
var _authored_env: Environment
var _authored_sun: Dictionary = { }
var _authored_fill: Dictionary = { }
var _authored_sky: ShaderMaterial

var _undo_glyph_cache:= ""

var _board_note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


	process_mode = Node.PROCESS_MODE_ALWAYS
	_scale = clampf(get_viewport_rect().size.y / DESIGN_H,
		SCALE_MIN, SCALE_MAX) * SCALE_BOOST
	_build()
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()
	GameState.money_changed.connect(_on_money_changed)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.93)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(_px(14))
	sb.content_margin_left = _px(20.0)


	sb.content_margin_right = _px(20.0 + 22.0)
	sb.content_margin_top = _px(16.0)
	sb.content_margin_bottom = _px(18.0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)


	_page = ScrollContainer.new()
	_page.name = "Page"
	_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_page)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_px(7)))


	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(box)

	var heading:= HBoxContainer.new()
	var title:= _label(tr("DEBUG MODE"), 26, COL_TITLE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_hint:= _label("F1 / ESC", 13, COL_DIM, true)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(close_hint)
	box.add_child(heading)


	box.add_child(_label(tr("Test-only tools · %s")
		% (tr("%s is enabled") % "Cfg.DEBUG" if Cfg.DEBUG
			else tr("unlocked for this session")),
		14, COL_DIM))

	_board_note = _label("", 15, COL_DANGER, true)
	_board_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_board_note)
	_refresh_board_note()

	_money_label = _label("", 20, COL_TEXT, true)
	box.add_child(_hrule())
	box.add_child(_money_label)
	_on_money_changed(GameState.money)

	var money_row:= HBoxContainer.new()
	money_row.add_theme_constant_override("separation", int(_px(8)))
	for amount in GRANTS:
		money_row.add_child(_button("+$%s" % _fmt(amount),
			_on_grant.bind(amount)))
	money_row.add_child(_button(tr("Reset"), _on_reset_money))
	box.add_child(money_row)

	box.add_child(_hrule())
	var tech_heading:= HBoxContainer.new()
	var tech_title:= _label(tr("TECH TREE"), 19, COL_TEXT, true)
	tech_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_heading.add_child(tech_title)
	tech_heading.add_child(
		_label(tr("Skip the whole tree, or put it back"), 12, COL_MUTED))
	box.add_child(tech_heading)
	var tech_row:= HBoxContainer.new()
	tech_row.add_theme_constant_override("separation", int(_px(8)))
	tech_row.add_child(_button(tr("Unlock everything"), _on_unlock_all))
	tech_row.add_child(_button(tr("Unlock all plans"), _on_unlock_plans))
	tech_row.add_child(_button(tr("Reset tree"), _on_reset_tech))
	box.add_child(tech_row)

	box.add_child(_hrule())
	var spawn_heading:= HBoxContainer.new()
	var spawn_title:= _label(tr("SPAWN ITEM"), 19, COL_TEXT, true)
	spawn_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_heading.add_child(spawn_title)
	spawn_heading.add_child(_label(tr("Choose an item to place in front of you"), 12, COL_MUTED))
	box.add_child(spawn_heading)


	var grid:= GridContainer.new()
	grid.name = "ItemGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_px(8)))
	grid.add_theme_constant_override("v_separation", int(_px(8)))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in ItemDb.ids():


		if Cfg.DEMO and id in GameState.DEMO_WITHHELD_TOOLS:
			continue
		grid.add_child(_item_card(id))
	box.add_child(grid)

	box.add_child(_hrule())
	var needle_heading:= HBoxContainer.new()
	var needle_title:= _label(tr("NEEDLE"), 19, COL_TEXT, true)
	needle_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needle_heading.add_child(needle_title)
	needle_heading.add_child(
		_label(tr("Finding one by digging takes a while"), 12, COL_MUTED))
	box.add_child(needle_heading)
	var needle_row:= HBoxContainer.new()
	needle_row.add_theme_constant_override("separation", int(_px(8)))
	needle_row.add_child(_button(tr("Spawn needle..."), _open_needle_picker))
	_wallhack_button = _button("", _on_toggle_wallhack)
	needle_row.add_child(_wallhack_button)
	_refresh_wallhack()
	box.add_child(needle_row)
	var cabinet_row:= HBoxContainer.new()
	cabinet_row.add_theme_constant_override("separation", int(_px(8)))
	cabinet_row.add_child(
		_button(tr("Fill the cabinet, all but one"), _on_fill_cabinet))
	cabinet_row.add_child(
		_label(tr("Every compartment but the %s one") % HOLE, 12, COL_MUTED))
	box.add_child(cabinet_row)
	var forget_row:= HBoxContainer.new()
	forget_row.add_theme_constant_override("separation", int(_px(8)))
	forget_row.add_child(_button(tr("Forget every needle"), _on_forget_needles))
	forget_row.add_child(
		_label(tr("Case dark, drawers empty, counters back to zero"), 12,
			COL_MUTED))
	box.add_child(forget_row)
	var ending_row:= HBoxContainer.new()
	ending_row.add_theme_constant_override("separation", int(_px(8)))
	ending_row.add_child(_button(tr("Play the ending"), _on_play_ending))
	ending_row.add_child(
		_label(tr("Specimens out, panel down, button live"), 12, COL_MUTED))
	box.add_child(ending_row)

	box.add_child(_hrule())
	var pile_heading:= HBoxContainer.new()
	var pile_title:= _label(tr("PILE"), 19, COL_TEXT, true)
	pile_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_heading.add_child(pile_title)
	pile_heading.add_child(
		_label(tr("Press again for a quarter, and again for an eighth"), 12,
			COL_MUTED))
	box.add_child(pile_heading)
	var pile_row:= HBoxContainer.new()
	pile_row.add_theme_constant_override("separation", int(_px(8)))
	pile_row.add_child(_button(tr("Take half of it"), _on_halve_pile))
	box.add_child(pile_row)

	box.add_child(_hrule())
	var gift_heading:= HBoxContainer.new()
	var gift_title:= _label(tr("GIFT CARD"), 19, COL_TEXT, true)
	gift_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_heading.add_child(gift_title)
	gift_heading.add_child(
		_label(tr("Plays as the tutorial plays it, and gives nothing"), 12, COL_MUTED))
	box.add_child(gift_heading)
	var gift_row:= HBoxContainer.new()
	gift_row.add_theme_constant_override("separation", int(_px(8)))
	for id: String in GiftCard.PRIZES:
		gift_row.add_child(_button(BuildCatalog.display_name(id), _on_play_gift.bind(id)))
	box.add_child(gift_row)

	box.add_child(_hrule())
	var move_heading:= HBoxContainer.new()
	var move_title:= _label(tr("PLAYER"), 19, COL_TEXT, true)
	move_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_heading.add_child(move_title)
	move_heading.add_child(
		_label(tr("Jump up, crouch down, shift fast"), 12, COL_MUTED))
	box.add_child(move_heading)
	var move_row:= HBoxContainer.new()
	move_row.add_theme_constant_override("separation", int(_px(8)))
	_noclip_button = _button("", _on_toggle_noclip)
	move_row.add_child(_noclip_button)
	move_row.add_child(
		_label(tr("Fly, and through anything in the way"), 12, COL_MUTED))
	_refresh_noclip()
	box.add_child(move_row)

	box.add_child(_hrule())
	box.add_child(_label(tr("HELD CONTAINER"), 17, COL_TEXT, true))
	var load_row:= HBoxContainer.new()
	load_row.add_theme_constant_override("separation", int(_px(8)))
	load_row.add_child(_button(tr("Fill"), _on_set_load.bind(1.0)))
	load_row.add_child(_button(tr("Half"), _on_set_load.bind(0.5)))
	load_row.add_child(_button(tr("Empty"), _on_set_load.bind(0.0)))
	box.add_child(load_row)

	box.add_child(_hrule())
	var show_heading:= HBoxContainer.new()
	var show_title:= _label(tr("SHOW"), 19, COL_TEXT, true)
	show_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_heading.add_child(show_title)
	show_heading.add_child(
		_label(tr("Stays on when the menu closes"), 12, COL_MUTED))
	box.add_child(show_heading)
	var zones_row:= HBoxContainer.new()
	zones_row.add_theme_constant_override("separation", int(_px(8)))
	_zones_button = _button("", _on_toggle_zones)
	zones_row.add_child(_zones_button)
	zones_row.add_child(
		_label(tr("Where a machine takes hay, and where the stand pays for it"), 12,
			COL_MUTED))
	box.add_child(zones_row)
	var bodies_row:= HBoxContainer.new()
	bodies_row.add_theme_constant_override("separation", int(_px(8)))
	_bodies_button = _button("", _on_cycle_bodies)
	bodies_row.add_child(_bodies_button)
	bodies_row.add_child(
		_label(tr("Solid is what you walk into. All adds strands and the pile"), 12,
			COL_MUTED))
	box.add_child(bodies_row)
	var render_row:= HBoxContainer.new()
	render_row.add_theme_constant_override("separation", int(_px(8)))
	_render_button = _button("", _on_cycle_render)
	render_row.add_child(_render_button)
	render_row.add_child(
		_label(tr("The image with the lighting taken off it"), 12, COL_MUTED))
	box.add_child(render_row)
	_refresh_show()

	box.add_child(_hrule())
	var look_heading:= HBoxContainer.new()
	var look_title:= _label(tr("LOOK"), 19, COL_TEXT, true)
	look_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look_heading.add_child(look_title)
	look_heading.add_child(
		_label(tr("The lights and the image, live"), 12, COL_MUTED))
	box.add_child(look_heading)
	var look_row:= HBoxContainer.new()
	look_row.add_theme_constant_override("separation", int(_px(8)))
	look_row.add_child(_button(tr("Lighting and environment..."), _open_look_panel))
	look_row.add_child(
		_label(tr("Sun, exposure, fog, ambient. Nothing is saved until you say so"),
			12, COL_MUTED))
	box.add_child(look_row)

	_build_crash_section(box)
	_build_needle_modal()


func _build_crash_section(box: VBoxContainer) -> void:
	box.add_child(_hrule())
	var heading:= HBoxContainer.new()
	var title:= _label(tr("END THIS SESSION"), 19, COL_DANGER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label(tr("Press once to arm, again to do it"), 12, COL_MUTED))
	box.add_child(heading)


	var warning:= _label(
		tr("Everything since the last autosave goes with it. That is what a crash is. The report card comes up on the next launch."),
		12, COL_MUTED)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warning)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_px(8)))
	row.add_child(_arm_button(tr("Crash the engine"), _on_crash_trap))
	row.add_child(_arm_button(tr("Kill the process"), _on_crash_kill))
	box.add_child(row)

	var note:= HBoxContainer.new()
	note.add_theme_constant_override("separation", int(_px(8)))
	note.add_child(_button(tr("Throw a script error"), _on_script_error))
	note.add_child(_label(tr("Survivable, and deliberately not reported"), 12,
		COL_MUTED))
	box.add_child(note)


func scroll_to_foot() -> void:
	if _page != null:
		_page.scroll_vertical = int(_page.get_v_scroll_bar().max_value)


func scroll_to_head() -> void:
	if _page != null:
		_page.scroll_vertical = 0


func _layout_panel() -> void:
	var viewport_size:= get_viewport_rect().size
	_centre(_panel, viewport_size, _px(PANEL_W), _px(PANEL_H))
	_centre(_needle_panel, viewport_size, _px(PICKER_W), _px(PICKER_H))


	if _look_panel != null:
		var look_size:= Vector2(
			minf(_px(LOOK_W), maxf(_px(280.0), viewport_size.x - PANEL_GUTTER * 2.0)),
			minf(_px(LOOK_H), maxf(_px(260.0), viewport_size.y - PANEL_GUTTER * 2.0)))
		_look_panel.position = Vector2(PANEL_GUTTER,
			(viewport_size.y - look_size.y) * 0.5)
		_look_panel.size = look_size


func _centre(panel: PanelContainer, viewport_size: Vector2,
		want_w: float, want_h: float) -> void:
	if panel == null:
		return
	var panel_size:= Vector2(
		minf(want_w, maxf(_px(280.0), viewport_size.x - PANEL_GUTTER * 2.0)),
		minf(want_h, maxf(_px(260.0), viewport_size.y - PANEL_GUTTER * 2.0)))
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size


func _item_card(id: String) -> PanelContainer:
	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(0, _px(68))


	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style:= StyleBoxFlat.new()
	card_style.bg_color = COL_CARD
	card_style.border_color = Color(1, 1, 1, 0.08)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(0)
	card_style.content_margin_left = _px(10.0)
	card_style.content_margin_right = _px(10.0)
	card_style.content_margin_top = _px(8.0)
	card_style.content_margin_bottom = _px(8.0)
	card.add_theme_stylebox_override("panel", card_style)

	var card_box:= HBoxContainer.new()
	card_box.add_theme_constant_override("separation", int(_px(8)))
	card.add_child(card_box)

	var info:= VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", int(_px(2)))
	card_box.add_child(info)

	var top:= HBoxContainer.new()
	var name_label:= _label(ItemDb.display_name(id), 16, COL_TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var price:= _label("$%s" % _fmt(ItemDb.price(id)), 15, COL_TITLE, true)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(price)
	info.add_child(top)

	var blurb:= _label(str(ItemDb.spec(id).get("blurb", "")), 12, COL_DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.clip_text = true
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(blurb)

	var spawn:= _button(tr("SPAWN"), _on_spawn.bind(id))
	spawn.custom_minimum_size = Vector2(_px(78), _px(32))
	spawn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_box.add_child(spawn)
	return card


func _build_needle_modal() -> void:
	_needle_modal = Control.new()
	_needle_modal.name = "NeedlePicker"
	_needle_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_needle_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_needle_modal.visible = false
	add_child(_needle_modal)


	var scrim:= ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_needle_modal.add_child(scrim)

	_needle_panel = PanelContainer.new()
	_needle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_needle_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.98)
	sb.border_color = Cfg.COL_NEEDLE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = int(_px(18))
	sb.content_margin_left = _px(20.0)
	sb.content_margin_right = _px(20.0)
	sb.content_margin_top = _px(16.0)
	sb.content_margin_bottom = _px(18.0)
	_needle_panel.add_theme_stylebox_override("panel", sb)
	_needle_modal.add_child(_needle_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_px(7)))
	_needle_panel.add_child(box)

	var heading:= HBoxContainer.new()
	var title:= _label(tr("SPAWN NEEDLE"), 24, COL_TITLE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var back:= _button(tr("Back"), _close_needle_picker)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(back)
	box.add_child(heading)


	_needle_where = _label("", 13, COL_DIM)
	_needle_where.clip_text = true
	box.add_child(_needle_where)

	var dest_row:= HBoxContainer.new()
	dest_row.add_theme_constant_override("separation", int(_px(8)))
	dest_row.add_child(_dest_button(NeedleDest.SCANNER, tr("Into a scanner")))
	dest_row.add_child(_dest_button(NeedleDest.BELT, tr("Onto nearest belt")))
	dest_row.add_child(_dest_button(NeedleDest.FEET, tr("At your feet")))
	box.add_child(dest_row)

	box.add_child(_hrule())


	var rolled:= _button(tr("Roll one, the way a dig would"),
		_spawn_needle_type.bind(-1))
	rolled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(rolled)

	var scroll:= ScrollContainer.new()
	scroll.name = "NeedleScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, _px(260))
	var list:= VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(_px(4)))


	for lot in NeedleTypes.lot_count():
		list.add_child(_label(tr("LOT %d") % (lot + 1), 13, COL_MUTED, true))
		var grid:= GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", int(_px(8)))
		grid.add_theme_constant_override("v_separation", int(_px(6)))
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for type in NeedleTypes.pool(lot):
			grid.add_child(_needle_card(type))
		list.add_child(grid)
	scroll.add_child(list)
	box.add_child(scroll)

	_refresh_dest()


func _needle_card(type: int) -> Control:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_px(1)))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var b:= _button(NeedleTypes.name_of(type), _spawn_needle_type.bind(type))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, _px(32))


	var tint:= NeedleCabinet.type_colour(type)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style:= (b.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
		style.border_color = tint
		style.border_width_left = int(maxf(1.0, _px(3.0)))
		b.add_theme_stylebox_override(state, style)
	col.add_child(b)

	var odds:= _label(tr("research %d  ·  1:%d")
		% [NeedleTypes.research_of(type), NeedleTypes.one_in(type)], 11, COL_MUTED)
	odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(odds)
	return col


func _dest_button(dest: NeedleDest, text: String) -> Button:
	var b:= _button(text, _set_dest.bind(dest))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("off", b.get_theme_stylebox("normal"))
	var on_style:= (b.get_theme_stylebox("pressed") as StyleBoxFlat).duplicate()
	on_style.border_color = COL_TITLE
	b.set_meta("on", on_style)
	_dest_buttons [dest] = b
	return b


func _set_dest(dest: NeedleDest) -> void:
	_needle_dest = dest
	Audio.play("ui_click")
	_refresh_dest()


func _refresh_dest() -> void:
	for key: NeedleDest in _dest_buttons:
		var b: Button = _dest_buttons [key]
		var on:= key == _needle_dest
		b.add_theme_stylebox_override("normal",
			b.get_meta("on" if on else "off") as StyleBox)
		b.add_theme_color_override("font_color", COL_TITLE if on else COL_TEXT)
	if _needle_where != null:


		_needle_where.text = tr("Goes %s  ·  a roll uses lot %d") % [
			_dest_blurb(), GameState.lot_tier + 1]


func _dest_blurb() -> String:
	match _needle_dest:
		NeedleDest.SCANNER:
			return tr("onto the run feeding the nearest scanner, riding in")
		NeedleDest.BELT:
			return tr("onto the belt nearest YOU, whichever way it runs")
		_:
			return tr("on the floor in front of you")


func _open_needle_picker() -> void:
	if _needle_modal == null:
		return


	if _needle_dest == NeedleDest.SCANNER and _nearest_scanner() == null:
		_needle_dest = NeedleDest.FEET
	_refresh_dest()
	_needle_modal.visible = true
	Audio.play("ui_open", -6.0)


func _close_needle_picker() -> void:
	if _needle_modal == null or not _needle_modal.visible:
		return
	_needle_modal.visible = false
	Audio.play("ui_close", -6.0)


func _spawn_needle_type(type: int) -> void:
	_close_needle_picker()
	match _needle_dest:
		NeedleDest.SCANNER:
			_on_needle_to_scanner(type)
		NeedleDest.BELT:
			_on_needle_to_belt(type)
		_:
			_on_spawn_needle(type)


func _px(n: float) -> float:
	return n * _scale


func _pt(n: int) -> int:
	return int(round(float(n) * _scale))


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	UiFont.style(l, _pt(size), colour, 0, heavy)
	l.text = text
	return l


func _hrule() -> Control:
	var r:= ColorRect.new()
	r.color = Color(1, 1, 1, 0.12)
	r.custom_minimum_size = Vector2(0, maxf(1.0, _px(1.0)))
	return r


func _button(text: String, action: Callable) -> Button:
	var b:= Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", _pt(14))
	b.custom_minimum_size = Vector2(0, _px(36))
	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.16, 0.2, 0.96)
	normal.border_color = Color(1, 1, 1, 0.12)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.content_margin_left = _px(10.0)
	normal.content_margin_right = _px(10.0)
	var hover:= normal.duplicate()
	hover.bg_color = COL_CARD_HOVER
	hover.border_color = Color(1.0, 0.86, 0.34, 0.65)
	var pressed:= hover.duplicate()
	pressed.bg_color = Color(0.25, 0.22, 0.12, 0.98)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)


	b.pressed.connect(_note_used)


	if action.is_valid():
		b.pressed.connect(action)
	return b


func _note_used() -> void:
	GameState.debug_used = true
	Profile.note_debug_used()
	_refresh_board_note()


func _refresh_board_note() -> void:
	if _board_note == null:
		return
	if Profile.debug_tainted:
		_board_note.text = tr("A button in this menu was used, so this game will not appear on the leaderboards.")
	else:
		_board_note.text = tr("Press any button in this menu and this game will never appear on the leaderboards.")


func _arm_button(text: String, action: Callable) -> Button:
	var b:= _button(text, Callable())
	b.set_meta("label", text)
	b.set_meta("armed_until", 0.0)
	b.add_theme_color_override("font_color", COL_DANGER)
	b.pressed.connect(_on_dangerous.bind(b, action))
	return b


func _on_dangerous(b: Button, action: Callable) -> void:
	var now:= Time.get_ticks_msec() / 1000.0
	if now < float(b.get_meta("armed_until", 0.0)):
		action.call()
		return
	b.set_meta("armed_until", now + ARM_SECONDS)
	b.text = tr("Press again")
	Audio.play("ui_click")


	var lapse:= get_tree().create_timer(ARM_SECONDS, true, false, true)
	lapse.timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.text = str(b.get_meta("label", "")))


func _on_crash_trap() -> void:
	print("[debug menu] deliberate crash, from the F1 menu")
	OS.crash("Deliberate crash from the F1 debug menu")


func _on_crash_kill() -> void:
	print("[debug menu] killing this process outright, from the F1 menu")
	OS.kill(OS.get_process_id())


func _on_script_error() -> void:
	_toast(tr("Throwing a script error. The game will keep running."))
	var empty: Array [int] = []
	print("[debug menu] deliberate script error: %d" % empty [7])
	print("[debug menu] THIS LINE NEVER RUNS")


static func _fmt(v: float) -> String:
	return Hud.money_text(v)


func _on_money_changed(amount: float) -> void:
	if _money_label != null:
		_money_label.text = tr("Money:  $%.2f") % amount


func _on_grant(amount: float) -> void:
	GameState.add_money(amount)
	Audio.play("coins", -4.0)
	_toast("+$%d" % int(amount))


func _on_unlock_all() -> void:
	for id: String in TechTree.ids():
		Tech.grant(id, TechTree.max_rank(id))
	_toast(tr("tech tree fully unlocked"))


func _on_unlock_plans() -> void:
	Tech.grant_legacy()
	_toast(tr("all plans unlocked, no levels bought"))


func _on_reset_tech() -> void:
	Tech.reset()
	_toast(tr("tech tree reset to bare hands"))


func _on_reset_money() -> void:
	GameState.add_money(GameState.STARTING_MONEY - GameState.money)
	Audio.play("ui_click")
	_toast(tr("money reset"))


func _on_spawn(id: String) -> void:
	if props == null or player == null:
		return
	var item:= props.spawn_near(id, player)
	if item == null:
		Audio.play("ui_error")
		return
	Audio.play("build_confirm", -4.0)
	_toast(tr("spawned %s") % ItemDb.display_name(id))


func _on_toggle_wallhack() -> void:
	if wallhack == null:
		Audio.play("ui_error")
		return
	var on:= wallhack.toggle()
	_refresh_wallhack()
	if not on:
		_toast(tr("wallhack off"))
		return
	var seen:= wallhack.census()
	_toast(tr("wallhack on: %d buried, %d loose")
		% [int(seen ["buried"]), int(seen ["loose"])])


func _refresh_wallhack() -> void:
	if _wallhack_button == null:
		return
	var on:= wallhack != null and wallhack.is_enabled()
	_wallhack_button.text = tr("Wallhack: ON") if on else tr("Wallhack: OFF")


func _on_toggle_noclip() -> void:
	if player == null:
		Audio.play("ui_error")
		return
	player.set_noclip(not player.noclip)
	_refresh_noclip()
	_toast(tr("noclip on: walls are off") if player.noclip else tr("noclip off"))


func _refresh_noclip() -> void:
	if _noclip_button == null:
		return
	var on:= player != null and player.noclip
	_noclip_button.text = tr("Noclip: ON") if on else tr("Noclip: OFF")


const RENDER_MODES: Array = [
	["Normal", Viewport.DEBUG_DRAW_DISABLED],
	["Unshaded", Viewport.DEBUG_DRAW_UNSHADED],
	["Lighting", Viewport.DEBUG_DRAW_LIGHTING],
	["Overdraw", Viewport.DEBUG_DRAW_OVERDRAW],
	["Wireframe", Viewport.DEBUG_DRAW_WIREFRAME],
]


func _ensure_view() -> DebugView:
	if _view != null and is_instance_valid(_view):
		return _view
	if world == null:
		return null
	_view = DebugView.new()
	_view.name = "DebugView"
	world.add_child(_view)
	return _view


func _on_toggle_zones() -> void:
	var view:= _ensure_view()
	if view == null:
		Audio.play("ui_error")
		return
	var n:= view.set_zones(not view.zones)
	_refresh_show()
	_toast(tr("zones: %d volumes") % n if view.zones else tr("zones off"))


func _on_cycle_bodies() -> void:
	var view:= _ensure_view()
	if view == null:
		Audio.play("ui_error")
		return
	var next:= (view.bodies + 1) % 3
	var count:= view.set_bodies(next)
	_refresh_show()
	if next == DebugView.Bodies.OFF:
		_toast(tr("collisions off"))
		return


	if count [1] > 0:
		_toast(tr("collisions: %d shapes, %d over the cap not drawn")
			% [count [0], count [1]])
	else:
		_toast(tr("collisions: %d shapes") % count [0])


func _on_cycle_render() -> void:
	_render_mode = (_render_mode + 1) % RENDER_MODES.size()
	var mode: int = RENDER_MODES [_render_mode] [1]


	if mode == Viewport.DEBUG_DRAW_WIREFRAME:
		RenderingServer.set_debug_generate_wireframes(true)
	get_viewport().debug_draw = mode
	_refresh_show()
	_toast(tr("render: %s") % tr(String(RENDER_MODES [_render_mode] [0])))


func _refresh_show() -> void:
	if _zones_button == null:
		return
	var live: DebugView = _view if _view != null and is_instance_valid(_view) else null
	_zones_button.text = tr("Zones: ON") if live != null and live.zones else tr("Zones: OFF")
	var mode: int = live.bodies if live != null else DebugView.Bodies.OFF
	var names:= [tr("OFF"), tr("SOLID"), tr("ALL")]
	_bodies_button.text = tr("Collisions: %s") % names [mode]
	_render_button.text = tr("Render: %s") % tr(String(RENDER_MODES [_render_mode] [0]))


func _on_play_ending() -> void:
	var cabs:= get_tree().get_nodes_in_group("needle_cabinets")
	if cabs.is_empty():
		Audio.play("ui_error")
		_toast(tr("No cabinet to end"))
		return
	for n in cabs:
		var cab:= n as NeedleCabinet
		if cab != null:
			cab.play_ending()
	_toast(tr("Ending playing  ·  press the button when it lands"))


func _on_play_gift(id: String) -> void:
	var card:= world.get("gift_card") as GiftCard if world != null else null
	if card == null:
		Audio.play("ui_error")
		_toast(tr("No gift card in this scene"))
		return
	set_open(false)
	if player != null:
		player.capture_mouse(false)
	card.play(id, _on_gift_taken)


func _on_gift_taken() -> void:
	if player != null and not _open:
		player.capture_mouse(true)


func _on_fill_cabinet() -> void:
	var n:= NeedleTypes.count()
	if n <= 0:
		Audio.play("ui_error")
		return


	var hole:= -1
	for type in n:
		if NeedleTypes.name_of(type) == HOLE:
			hole = type
			break
	for type in n:
		_set_collected(type, type != hole)
	if hole < 0:
		_toast(tr("Cabinet FILLED  ·  no %s compartment to leave empty") % HOLE)
	else:
		_toast(tr("Cabinet filled  ·  %s missing") % NeedleTypes.name_of(hole))


func _on_forget_needles() -> void:
	var n:= NeedleTypes.count()
	if n <= 0:
		Audio.play("ui_error")
		return
	var had:= GameState.needles_found
	for type in n:
		_set_collected(type, false)
	GameState.needles_found = 0
	for type in GameState.needles_by_type.size():
		GameState.needles_by_type [type] = 0
	GameState.needle_out = PackedInt32Array()
	_toast(tr_n("Collection cleared  ·  %d find forgotten",
		"Collection cleared  ·  %d finds forgotten", had) % had)


func _set_collected(type: int, held: bool) -> void:
	if type < 0 or type >= GameState.discovered.size():
		return
	GameState.discovered [type] = 1 if held else 0
	var have:= GameState.stock_of(type)
	var want:= maxi(have, 1) if held else 0
	if want != have:
		GameState.needle_stock [type] = want


		GameState.needles_found = maxi(0,
			GameState.needles_found + want - have)
		if type < GameState.needles_by_type.size():
			GameState.needles_by_type [type] = maxi(0,
				GameState.needles_by_type [type] + want - have)
	GameState.needle_stock_changed.emit(type, GameState.needle_stock [type])


func _on_halve_pile() -> void:
	var field: HayField = builds.field if builds != null else null
	if field == null or field.heights.is_empty():
		Audio.play("ui_error")
		_toast(tr("No pile to take"))
		return

	field.settle_join()
	for i in field.heights.size():
		field.heights [i] *= 0.5


	field.rebuild_everything()


	GameState.lose_hay(GameState.hay_total * 0.5)


	var moved:= { "sunk": 0, "surfaced": 0 }
	if live != null:
		moved = live.settle_buried_needles(0.5)


	var said:= tr("Pile halved  ·  %s strands left") % Hud.fmt(GameState.hay_total)


	if int(moved ["surfaced"]) > 0:
		said += "  ·  " + tr_n("%d needle left on the surface",
			"%d needles left on the surface", int(moved ["surfaced"])) % int(moved ["surfaced"])
	elif int(moved ["sunk"]) > 0:
		said += "  ·  " + tr("%d needles came down with it") % int(moved ["sunk"])
	_toast(said)


func _on_spawn_needle(type: int = -1) -> void:
	var look:= player.look_direction()
	look.y = 0.0
	if look.length_squared() < 1e-06:
		look = Vector3.BACK
	var at:= player.global_position + look.normalized() * NEEDLE_THROW
	at.y += 0.35
	if _drop_needle(at, type) < 0:
		return
	_toast(tr("%s at your feet") % _needle_noun(type))


func _on_needle_to_belt(type: int = -1) -> void:
	if builds == null:
		Audio.play("ui_error")
		return
	var drop:= builds.nearest_conveyor_drop(player.global_position,
		NEEDLE_BELT_RANGE)
	if drop.is_empty():
		Audio.play("ui_error")
		_toast(tr("no belt within %d m") % int(NEEDLE_BELT_RANGE))
		return


	if _drop_needle(drop ["point"] as Vector3, type) < 0:
		return
	_toast(tr("%s on the belt") % _needle_noun(type))


func _on_needle_to_scanner(type: int = -1) -> void:
	if builds == null or player == null:
		Audio.play("ui_error")
		return
	var scanner:= _nearest_scanner()
	if scanner == null:
		Audio.play("ui_error")
		_toast(tr("no scanner built"))
		return
	if _drop_needle(_scanner_feed_point(scanner), type) < 0:
		return
	_toast(tr("%s riding into the scanner") % _needle_noun(type))


func _nearest_scanner() -> HaystackScanner:
	if builds == null or player == null:
		return null
	var best: HaystackScanner = null
	var best_d:= INF
	for scanner in builds.scanners:
		if not is_instance_valid(scanner):
			continue
		var d:= scanner.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = scanner
	return best


func _scanner_feed_point(scanner: HaystackScanner) -> Vector3:
	var port:= scanner.port_in()
	var fwd:= scanner.forward()
	var run:= _feed_run(port)
	if run == null:


		return port + fwd * 0.3 + Vector3.UP * NEEDLE_BELT_LIFT
	var lead:= minf(SCANNER_FEED_LEAD, run.a.distance_to(run.b) - 0.3)
	return port - fwd * maxf(lead, 0.3) + Vector3.UP * NEEDLE_BELT_LIFT


func _feed_run(port: Vector3) -> Conveyor:
	if builds == null:
		return null
	for c in builds.conveyors:
		if is_instance_valid(c) and c.b.is_equal_approx(port):
			return c
	return null


func _needle_noun(type: int) -> String:
	if type < 0 or type >= NeedleTypes.count():
		return tr("needle")
	return NeedleTypes.name_of(type).to_lower()


func _drop_needle(at: Vector3, type: int = -1) -> int:
	if live == null:
		Audio.play("ui_error")
		return -1
	var index:= GameState.register_needle(at, null, type)
	live.reveal_needle(index, at)
	GameState.needle_taken [index] = 1
	Audio.play_3d("needle_ting", at, -6.0)
	return index


func _on_set_load(fraction: float) -> void:
	var c:= _target_container()
	if c == null:
		Audio.play("ui_error")
		_toast(tr("nothing to fill"))
		return
	c.from_state({ "stored": int(round(fraction * float(c.capacity()))) })
	Audio.play("ui_click")
	_toast(tr("%s at %d%%") % [c.container_noun(), int(round(fraction * 100.0))])


func _target_container() -> HayContainer:
	if player != null and player.carry != null:
		var held:= player.carry.held()
		if held is HayContainer:
			return held as HayContainer
	if props == null or player == null:
		return null
	var best: HayContainer = null
	var best_d:= INF
	for item in props.items:
		if item is not HayContainer:
			continue
		var d: float = item.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = item as HayContainer
	return best


func _toast(text: String) -> void:
	if hud != null:
		hud.show_toast(text)


const LOOK_KNOB_LABEL:= 132.0
const LOOK_KNOB_VALUE:= 58.0


const LOOK_RESET_GLYPH:= "↺"
const LOOK_RESET_PLAIN:= "<"


const SUN_ELEV_MIN:= 3.0
const SUN_ELEV_MAX:= 86.0


const LIGHT_PREFIXES:= ["light_", "shadow_", "directional_shadow_"]


const LOOK_SCENE_PATH:= "res://scenes/look/yard_look.tscn"


func _look_rows() -> Array:
	return [
[tr("SUN"), [
	["lightcol", tr("Colour"), "Sun", "light_color"],
	["light", tr("Energy"), "Sun", "light_energy", 0.0, 8.0, 0.05, 2],
	["light", tr("Indirect"), "Sun", "light_indirect_energy", 0.0, 4.0, 0.01, 2],
	["light", tr("Specular"), "Sun", "light_specular", 0.0, 4.0, 0.01, 2],


	["light", tr("Softness"), "Sun", "light_angular_distance", 0.0, 10.0, 0.05, 2],


	["light", tr("Shafts"), "Sun", "light_volumetric_fog_energy", 0.0, 4.0, 0.05, 2],
	["lightenum", tr("Draws in sky"), "Sun", "sky_mode",
		[tr("LIGHT AND SKY"), tr("LIGHT ONLY"), tr("SKY ONLY")]],


	["sunelev"],
	["sunazim"],
	["sunrot", tr("Rotation X"), 0],
	["sunrot", tr("Rotation Y"), 1],
	["sunrot", tr("Rotation Z"), 2],
]],
[tr("SUN SHADOW"), [
	["gfxflag", tr("Shadows"), "shadows"],
	["lightenum", tr("Mode"), "Sun", "directional_shadow_mode",
		[tr("ORTHOGONAL"), tr("2 SPLITS"), tr("4 SPLITS")]],
	["light", tr("Bias"), "Sun", "shadow_bias", 0.0, 1.0, 0.002, 3],
	["light", tr("Normal bias"), "Sun", "shadow_normal_bias", 0.0, 4.0, 0.01, 2],
	["light", tr("Blur"), "Sun", "shadow_blur", 0.0, 4.0, 0.01, 2],
	["light", tr("Opacity"), "Sun", "shadow_opacity", 0.0, 1.0, 0.01, 2],
	["light", tr("Transmittance"), "Sun", "shadow_transmittance_bias",
		-2.0, 2.0, 0.01, 2],
	["light", tr("Split 1"), "Sun", "directional_shadow_split_1", 0.0, 1.0, 0.005, 3],
	["light", tr("Split 2"), "Sun", "directional_shadow_split_2", 0.0, 1.0, 0.005, 3],
	["light", tr("Split 3"), "Sun", "directional_shadow_split_3", 0.0, 1.0, 0.005, 3],
	["lightflag", tr("Blend splits"), "Sun", "directional_shadow_blend_splits"],
	["light", tr("Fade start"), "Sun", "directional_shadow_fade_start",
		0.0, 1.0, 0.005, 3],
	["light", tr("Range"), "Sun", "directional_shadow_max_distance",
		10.0, 200.0, 1.0, 0],
	["light", tr("Pancake"), "Sun", "directional_shadow_pancake_size",
		0.0, 60.0, 0.5, 1],
	["lightflag", tr("Reverse cull"), "Sun", "shadow_reverse_cull_face"],
]],
[tr("FILL LIGHT"), [
	["lightcol", tr("Colour"), "BounceFill", "light_color"],
	["light", tr("Energy"), "BounceFill", "light_energy", 0.0, 3.0, 0.01, 2],
	["light", tr("Indirect"), "BounceFill", "light_indirect_energy",
		0.0, 4.0, 0.01, 2],
	["light", tr("Specular"), "BounceFill", "light_specular", 0.0, 4.0, 0.01, 2],
	["light", tr("Shafts"), "BounceFill", "light_volumetric_fog_energy",
		0.0, 4.0, 0.05, 2],
]],
[tr("IMAGE"), [
	["tonemap"],
	["gfx", tr("Exposure"), "exposure", 0.2, 2.0, 0.01, 2],
	["gfx", tr("White point"), "white", 1.0, 16.0, 0.1, 2],
	["env", tr("AgX white"), "tonemap_agx_white", 2.0, 16.5, 0.1, 2],
	["env", tr("AgX contrast"), "tonemap_agx_contrast", 1.0, 2.0, 0.01, 2],
	["gfxflag", tr("Contrast / sat."), "adjustment"],
	["env", tr("Brightness"), "adjustment_brightness", 0.5, 1.6, 0.01, 2],
	["env", tr("Contrast"), "adjustment_contrast", 0.5, 1.6, 0.01, 2],
	["env", tr("Saturation"), "adjustment_saturation", 0.0, 2.0, 0.01, 2],
	["gfxflag", tr("Colour grade"), "color_correction"],
]],
[tr("BLOOM"), [
	["gfxflag", tr("Bloom"), "glow"],
	["gfx", tr("Intensity"), "glow_intensity", 0.0, 2.0, 0.01, 2],
	["env", tr("Strength"), "glow_strength", 0.0, 2.0, 0.01, 2],
	["env", tr("Mix"), "glow_mix", 0.0, 1.0, 0.001, 3],
	["env", tr("Spread"), "glow_bloom", 0.0, 1.0, 0.01, 2],
	["envenum", tr("Blend"), "glow_blend_mode",
		[tr("ADDITIVE"), tr("SCREEN"), tr("SOFT LIGHT"), tr("REPLACE"), tr("MIX")]],
	["env", tr("HDR threshold"), "glow_hdr_threshold", 0.0, 4.0, 0.01, 2],
	["env", tr("HDR scale"), "glow_hdr_scale", 0.0, 4.0, 0.01, 2],
	["envflag", tr("Normalised"), "glow_normalized"],


	["env", tr("Level 1"), "glow_levels/1", 0.0, 4.0, 0.01, 2],
	["env", tr("Level 2"), "glow_levels/2", 0.0, 4.0, 0.01, 2],
	["env", tr("Level 3"), "glow_levels/3", 0.0, 4.0, 0.01, 2],
	["env", tr("Level 4"), "glow_levels/4", 0.0, 4.0, 0.01, 2],
	["env", tr("Level 5"), "glow_levels/5", 0.0, 4.0, 0.01, 2],
	["env", tr("Level 6"), "glow_levels/6", 0.0, 4.0, 0.01, 2],
	["env", tr("Level 7"), "glow_levels/7", 0.0, 4.0, 0.01, 2],
]],
[tr("AMBIENT"), [
	["envcol", tr("Ambient colour"), "ambient_light_color"],
	["env", tr("Ambient energy"), "ambient_light_energy", 0.0, 4.0, 0.01, 2],
	["gfx", tr("From the sky"), "sky_contribution", 0.0, 1.0, 0.01, 2],
	["gfxflag", tr("Ambient from sky"), "ambient_sky"],
	["gfxflag", tr("Sky reflections"), "reflect_sky"],
	["env", tr("Sky energy"), "background_energy_multiplier", 0.0, 4.0, 0.01, 2],
	["gfxflag", tr("Occlusion"), "ssao"],
	["env", tr("AO radius"), "ssao_radius", 0.01, 8.0, 0.01, 2],
	["env", tr("AO strength"), "ssao_intensity", 0.0, 8.0, 0.05, 2],
	["env", tr("AO power"), "ssao_power", 0.0, 8.0, 0.05, 2],
	["env", tr("AO detail"), "ssao_detail", 0.0, 5.0, 0.01, 2],
	["env", tr("AO horizon"), "ssao_horizon", 0.0, 1.0, 0.01, 2],
	["env", tr("AO sharpness"), "ssao_sharpness", 0.0, 1.0, 0.01, 2],
	["env", tr("AO on light"), "ssao_light_affect", 0.0, 1.0, 0.01, 2],
	["env", tr("AO on channel"), "ssao_ao_channel_affect", 0.0, 1.0, 0.01, 2],
	["gfxflag", tr("Indirect light"), "ssil"],
	["env", tr("GI radius"), "ssil_radius", 0.01, 16.0, 0.01, 2],
	["env", tr("GI strength"), "ssil_intensity", 0.0, 8.0, 0.05, 2],
	["env", tr("GI sharpness"), "ssil_sharpness", 0.0, 1.0, 0.01, 2],
	["env", tr("GI rejection"), "ssil_normal_rejection", 0.0, 1.0, 0.01, 2],
]],
[tr("AIR"), [
	["gfxflag", tr("Depth fog"), "fog"],
	["envcol", tr("Fog colour"), "fog_light_color"],
	["env", tr("Fog light"), "fog_light_energy", 0.0, 8.0, 0.05, 2],
	["env", tr("Fog density"), "fog_density", 0.0, 0.06, 0.0005, 4],
	["env", tr("Sun scatter"), "fog_sun_scatter", 0.0, 1.0, 0.01, 2],
	["env", tr("Aerial persp."), "fog_aerial_perspective", 0.0, 1.0, 0.01, 2],
	["env", tr("Fog on sky"), "fog_sky_affect", 0.0, 1.0, 0.01, 2],
	["env", tr("Fog height"), "fog_height", -20.0, 40.0, 0.1, 1],
	["env", tr("Height density"), "fog_height_density", -4.0, 4.0, 0.01, 2],
	["gfxflag", tr("Volumetric fog"), "vfog"],
	["env", tr("Volume density"), "volumetric_fog_density", 0.0, 0.2, 0.002, 3],
	["envcol", tr("Volume albedo"), "volumetric_fog_albedo"],
	["envcol", tr("Volume emission"), "volumetric_fog_emission"],
	["env", tr("Emission energy"), "volumetric_fog_emission_energy",
		0.0, 8.0, 0.05, 2],
	["env", tr("Anisotropy"), "volumetric_fog_anisotropy", -0.9, 0.9, 0.01, 2],
	["env", tr("Volume length"), "volumetric_fog_length", 1.0, 200.0, 1.0, 0],
	["env", tr("Detail spread"), "volumetric_fog_detail_spread", 0.5, 6.0, 0.05, 2],
	["env", tr("Ambient inject"), "volumetric_fog_ambient_inject", 0.0, 4.0, 0.05, 2],
	["env", tr("GI inject"), "volumetric_fog_gi_inject", 0.0, 4.0, 0.05, 2],
	["env", tr("Volume on sky"), "volumetric_fog_sky_affect", 0.0, 1.0, 0.01, 2],
	["envflag", tr("Reprojection"), "volumetric_fog_temporal_reprojection_enabled"],
	["env", tr("Reproject amount"),
		"volumetric_fog_temporal_reprojection_amount", 0.5, 0.99, 0.001, 3],
]],
]


func _open_look_panel() -> void:
	if _env() == null:
		_toast(tr("No look in this world"))
		return
	if _look_modal == null:
		_read_authored()
		_build_look_panel()
	_refresh_look()


	_panel.visible = false
	_look_modal.visible = true
	Audio.play("ui_open", -6.0)


func _close_look_panel() -> void:
	if _look_modal == null or not _look_modal.visible:
		return
	_look_modal.visible = false
	_panel.visible = true
	Audio.play("ui_close", -6.0)


func _env() -> Environment:
	if world == null:
		return null
	var we:= world.get_node_or_null("Environment") as WorldEnvironment
	return we.environment if we != null else null


func _light(node_name: String) -> DirectionalLight3D:
	if world == null:
		return null
	return world.get_node_or_null(NodePath(node_name)) as DirectionalLight3D


func _sun() -> DirectionalLight3D:
	return _light("Sun")


func _read_authored() -> void:
	_authored_gfx = Cfg.authored_gfx()
	_authored_env = ResourceLoader.load(Cfg.LOOK_ENV_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Environment
	_authored_sky = ResourceLoader.load(SKY_MAT_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as ShaderMaterial
	_authored_sun = { }
	_authored_fill = { }
	var packed:= load(LOOK_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var fresh:= packed.instantiate()
	for light_name: String in ["Sun", "BounceFill"]:
		var src:= fresh.get_node_or_null(
			NodePath(light_name)) as DirectionalLight3D
		if src == null:
			continue
		var props:= { "transform": src.transform,
			"rotation_degrees": src.rotation_degrees }
		for prop: Dictionary in src.get_property_list():
			var prop_name:= String(prop ["name"])
			if int(prop ["usage"]) & PROPERTY_USAGE_STORAGE == 0:
				continue
			for prefix: String in LIGHT_PREFIXES:
				if prop_name.begins_with(prefix):
					props [prop_name] = src.get(prop_name)
					break
		if light_name == "Sun":
			_authored_sun = props
		else:
			_authored_fill = props
	fresh.free()


func _build_look_panel() -> void:
	_look_modal = Control.new()
	_look_modal.name = "LookPanel"
	_look_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_modal.visible = false
	add_child(_look_modal)

	_look_panel = PanelContainer.new()
	_look_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = int(_px(16))
	sb.content_margin_left = _px(16.0)
	sb.content_margin_right = _px(16.0 + 20.0)
	sb.content_margin_top = _px(14.0)
	sb.content_margin_bottom = _px(14.0)
	_look_panel.add_theme_stylebox_override("panel", sb)
	_look_modal.add_child(_look_panel)

	var page:= ScrollContainer.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_look_panel.add_child(page)
	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_px(4)))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(box)

	var heading:= HBoxContainer.new()
	var title:= _label(tr("LOOK"), 22, COL_TITLE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var back:= _button(tr("Back"), _close_look_panel)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(back)
	box.add_child(heading)
	box.add_child(_label(
		tr("WASD walks, right mouse drag looks. %s puts one row back")
		% _undo_glyph(), 12, COL_MUTED))

	_look_refresh.clear()
	_sun_refresh.clear()

	for section: Array in _look_rows():
		box.add_child(_look_heading(String(section [0])))
		for spec: Array in section [1]:
			var row:= _look_row(spec)
			if row != null:
				box.add_child(row)
	_sky_rows(box)

	box.add_child(_hrule())
	var out_row:= HBoxContainer.new()
	out_row.add_theme_constant_override("separation", int(_px(8)))
	out_row.add_child(_button(tr("Copy the numbers"), _on_look_copy))
	out_row.add_child(_button(tr("All of it back"), _on_look_revert))
	box.add_child(out_row)


	if OS.has_feature("editor"):
		var save_row:= HBoxContainer.new()
		save_row.add_theme_constant_override("separation", int(_px(8)))
		save_row.add_child(
			_arm_button(tr("Write it to the look files"), _on_look_save))
		save_row.add_child(_label(
			tr("Overwrites %s and %s") % ["yard_environment.tres", "yard_look.tscn"],
			12, COL_MUTED))
		box.add_child(save_row)
	_layout_panel()


func _look_heading(text: String) -> Control:
	var head:= VBoxContainer.new()
	head.add_theme_constant_override("separation", int(_px(3)))
	head.add_child(_hrule())
	head.add_child(_label(text, 14, COL_TITLE, true))
	return head


func _undo_glyph() -> String:
	if _undo_glyph_cache != "":
		return _undo_glyph_cache
	var font:= UiFont.bold()
	_undo_glyph_cache = LOOK_RESET_GLYPH
	if font == null or not font.has_char(LOOK_RESET_GLYPH.unicode_at(0)):
		_undo_glyph_cache = LOOK_RESET_PLAIN
	return _undo_glyph_cache


func _undo_button(shows: String, action: Callable) -> Button:
	var b:= _button(_undo_glyph(), action)
	b.custom_minimum_size = Vector2(_px(26), _px(22))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tr("Back to %s, the authored value") % shows
	return b


func _look_row(spec: Array) -> Control:
	match String(spec [0]):
		"gfx":
			return _gfx_knob(spec [1], spec [2], spec [3], spec [4], spec [5], spec [6])
		"gfxflag":
			return _gfx_flag(spec [1], spec [2])
		"tonemap":
			return _tonemap_row()
		"env":
			return _env_knob(spec [1], spec [2], spec [3], spec [4], spec [5], spec [6])
		"envflag":
			return _env_flag(spec [1], spec [2])
		"envcol":
			return _env_colour(spec [1], spec [2])
		"envenum":
			return _env_enum(spec [1], spec [2], spec [3])
		"light":
			return _light_knob(spec [1], spec [2], spec [3], spec [4], spec [5],
				spec [6], spec [7])
		"lightflag":
			return _light_flag(spec [1], spec [2], spec [3])
		"lightcol":
			return _light_colour(spec [1], spec [2], spec [3])
		"lightenum":
			return _light_enum(spec [1], spec [2], spec [3], spec [4])
		"sunelev":
			return _sun_aim_knob(tr("Elevation"), SUN_ELEV_MIN, SUN_ELEV_MAX,
				func() -> float: return _sun_elev, _set_sun_elev,
				_authored_angle(true))
		"sunazim":
			return _sun_aim_knob(tr("Azimuth"), -180.0, 180.0,
				func() -> float: return _sun_azim, _set_sun_azim,
				_authored_angle(false))
		"sunrot":
			return _sun_rot_knob(spec [1], spec [2])
	push_warning("[look] no row of kind %s" % spec [0])
	return null


func _row_shell(title: String) -> HBoxContainer:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_px(6)))
	var name_label:= _label(title, 13, COL_DIM)
	name_label.custom_minimum_size = Vector2(_px(LOOK_KNOB_LABEL), 0)
	name_label.clip_text = true
	row.add_child(name_label)
	return row


func _knob(title: String, lo: float, hi: float, step: float,
		getter: Callable, setter: Callable, digits: int = 2,
		authored: Variant = null) -> HBoxContainer:
	var row:= _row_shell(title)

	var slider:= HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(_px(140), _px(16))
	row.add_child(slider)

	var value:= _label("", 13, COL_TEXT, true)
	value.custom_minimum_size = Vector2(_px(LOOK_KNOB_VALUE), 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	slider.value_changed.connect(func(v: float) -> void:
		_note_used()
		setter.call(v)
		value.text = String.num(v, digits))
	var refresh:= func() -> void:
		var now:= float(getter.call())
		slider.set_value_no_signal(clampf(now, lo, hi))
		value.text = String.num(now, digits)
	refresh.call()
	_look_refresh.append(refresh)

	if authored != null:
		row.add_child(_undo_button(String.num(float(authored), digits),
			func() -> void:
				setter.call(float(authored))
				refresh.call()))
	return row


func _flag_row(title: String, getter: Callable, setter: Callable,
		authored: Variant = null) -> HBoxContainer:
	var row:= _row_shell(title)
	var b:= _button("", Callable())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, _px(24))
	var refresh:= func() -> void:
		b.text = tr("ON") if bool(getter.call()) else tr("OFF")
	b.pressed.connect(func() -> void:
		setter.call(not bool(getter.call()))
		refresh.call())
	refresh.call()
	_look_refresh.append(refresh)
	row.add_child(b)
	if authored != null:
		row.add_child(_undo_button(tr("ON") if bool(authored) else tr("OFF"),
			func() -> void:
				setter.call(bool(authored))
				refresh.call()))
	return row


func _enum_row(title: String, names: Array, getter: Callable, setter: Callable,
		authored: Variant = null) -> HBoxContainer:
	var row:= _row_shell(title)
	var b:= _button("", Callable())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, _px(24))
	var refresh:= func() -> void:
		b.text = String(names [clampi(int(getter.call()), 0, names.size() - 1)])
	b.pressed.connect(func() -> void:
		setter.call(wrapi(int(getter.call()) + 1, 0, names.size()))
		refresh.call())
	refresh.call()
	_look_refresh.append(refresh)
	row.add_child(b)
	if authored != null:
		var was:= clampi(int(authored), 0, names.size() - 1)
		row.add_child(_undo_button(String(names [was]),
			func() -> void:
				setter.call(was)
				refresh.call()))
	return row


func _colour_row(title: String, getter: Callable, setter: Callable,
		authored: Variant = null, alpha: bool = false) -> HBoxContainer:
	var row:= _row_shell(title)
	var pick:= ColorPickerButton.new()
	pick.edit_alpha = alpha
	pick.focus_mode = Control.FOCUS_NONE
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.custom_minimum_size = Vector2(_px(90), _px(24))
	pick.color_changed.connect(func(c: Color) -> void:
		_note_used()
		setter.call(c))
	var refresh:= func() -> void:
		pick.color = getter.call()
	refresh.call()
	_look_refresh.append(refresh)
	row.add_child(pick)
	if authored != null:
		var was: Color = authored
		row.add_child(_undo_button("#" + was.to_html(false),
			func() -> void:
				setter.call(was)
				refresh.call()))
	return row


func _env_flag(title: String, prop: String) -> HBoxContainer:
	var authored: Variant = null
	if _authored_env != null:
		authored = _authored_env.get(prop)
	return _flag_row(title,
		func() -> bool: return bool(_env().get(prop)),
		func(v: bool) -> void: _env().set(prop, v),
		authored)


func _env_colour(title: String, prop: String) -> HBoxContainer:
	var authored: Variant = null
	if _authored_env != null:
		authored = _authored_env.get(prop)
	return _colour_row(title,
		func() -> Color: return _env().get(prop),
		func(c: Color) -> void: _env().set(prop, c),
		authored)


func _env_enum(title: String, prop: String, names: Array) -> HBoxContainer:
	var authored: Variant = null
	if _authored_env != null:
		authored = _authored_env.get(prop)
	return _enum_row(title, names,
		func() -> int: return int(_env().get(prop)),
		func(v: int) -> void: _env().set(prop, v),
		authored)


func _light_flag(title: String, node_name: String, prop: String) -> HBoxContainer:
	var authored: Dictionary = _authored_light(node_name)
	return _flag_row(title,
		func() -> bool: return bool(_light(node_name).get(prop)),
		func(v: bool) -> void: _light(node_name).set(prop, v),
		authored.get(prop))


func _light_colour(title: String, node_name: String, prop: String) -> HBoxContainer:
	var authored: Dictionary = _authored_light(node_name)
	return _colour_row(title,
		func() -> Color: return _light(node_name).get(prop),
		func(c: Color) -> void: _light(node_name).set(prop, c),
		authored.get(prop))


func _light_enum(title: String, node_name: String, prop: String,
		names: Array) -> HBoxContainer:
	var authored: Dictionary = _authored_light(node_name)
	return _enum_row(title, names,
		func() -> int: return int(_light(node_name).get(prop)),
		func(v: int) -> void: _light(node_name).set(prop, v),
		authored.get(prop))


func _authored_light(node_name: String) -> Dictionary:
	return _authored_sun if node_name == "Sun" else _authored_fill


const SKY_MAT_PATH:= "res://scenes/look/yard_sky.tres"
const SKY_SKIP:= ["cloud_shape_offset"]


const SKY_NOT_AUTHORED:= ["cloud_shape_offset", "cloud_noise_offset",
	"use_cumulus", "cloud_marches", "light_marches", "atmosphere_sample_count"]


const SKY_SPAN:= 4.0


func _sky_material() -> ShaderMaterial:
	var e:= _env()
	if e == null or e.sky == null:
		return null
	return e.sky.sky_material as ShaderMaterial


func _sky_rows(box: VBoxContainer) -> void:
	var mat:= _sky_material()
	if mat == null or mat.shader == null:
		return
	box.add_child(_look_heading(tr("SKY")))
	box.add_child(_label(
		tr("Generated from the shader. The cloud march count is re-written by the graphics preset"),
		12, COL_MUTED))
	for u: Dictionary in mat.shader.get_shader_uniform_list():
		var row:= _sky_row(mat, u)
		if row != null:
			box.add_child(row)


func _sky_row(mat: ShaderMaterial, u: Dictionary) -> Control:
	var uniform:= String(u ["name"])
	if uniform in SKY_SKIP:
		return null
	var type:= int(u ["type"])
	var hint:= int(u ["hint"])
	var title:= uniform.capitalize()
	var now: Variant = _sky_value(mat, uniform)
	var authored: Variant = null
	if _authored_sky != null:
		authored = _authored_sky.get_shader_parameter(uniform)
	if authored == null:
		authored = now

	if type == TYPE_BOOL:
		return _flag_row(title,
			func() -> bool: return bool(_sky_value(mat, uniform)),
			func(v: bool) -> void: mat.set_shader_parameter(uniform, v),
			authored)
	if type == TYPE_COLOR or (type == TYPE_VECTOR3
			and hint == PROPERTY_HINT_COLOR_NO_ALPHA):

		var as_vec:= type == TYPE_VECTOR3
		return _colour_row(title,
			func() -> Color: return _sky_colour(mat, uniform),
			func(c: Color) -> void: mat.set_shader_parameter(uniform,
				Vector3(c.r, c.g, c.b) if as_vec else c),
			_as_colour(authored))
	if type != TYPE_FLOAT and type != TYPE_INT:
		return null

	var span:= _sky_span(u, float(now))
	return _knob(title, span.x, span.y, span.z,
		func() -> float: return float(_sky_value(mat, uniform)),
		func(v: float) -> void: mat.set_shader_parameter(uniform,
			int(round(v)) if type == TYPE_INT else v),
		0 if type == TYPE_INT else 3, authored)


func _sky_value(mat: ShaderMaterial, uniform: String) -> Variant:
	var v: Variant = mat.get_shader_parameter(uniform)
	if v != null:
		return v
	return RenderingServer.shader_get_parameter_default(
		mat.shader.get_rid(), uniform)


func _sky_colour(mat: ShaderMaterial, uniform: String) -> Color:
	return _as_colour(_sky_value(mat, uniform))


func _as_colour(v: Variant) -> Variant:
	if v is Color:
		return v
	if v is Vector3:
		var vec: Vector3 = v
		return Color(vec.x, vec.y, vec.z)
	return null


func _sky_span(u: Dictionary, now: float) -> Vector3:
	if int(u ["hint"]) == PROPERTY_HINT_RANGE:
		var parts:= String(u ["hint_string"]).split(",")
		if parts.size() >= 2:
			var lo:= float(parts [0])
			var hi:= float(parts [1])
			var step:= float(parts [2]) if parts.size() > 2 else (hi - lo) / 200.0
			if step <= 0.0:
				step = (hi - lo) / 200.0
			return Vector3(lo, hi, step)
	var top:= maxf(1.0, absf(now) * SKY_SPAN)
	var bottom:= - top if now < 0.0 else 0.0
	return Vector3(bottom, top, (top - bottom) / 200.0)


func _gfx_flag(title: String, key: String) -> HBoxContainer:
	return _flag_row(title,
		func() -> bool: return bool(Cfg.gfx [key]),
		func(v: bool) -> void: _set_gfx_live(key, v),
		_authored_gfx.get(key))


func _tonemap_row() -> HBoxContainer:


	var names:= Cfg.TONEMAP_NAMES.map(func(n: String) -> String: return tr(n))
	return _enum_row(tr("Tonemap"), names,
		func() -> int: return int(Cfg.gfx ["tonemap"]),
		func(v: int) -> void: _set_gfx_live("tonemap", v),
		_authored_gfx.get("tonemap"))


func _env_knob(title: String, prop: String, lo: float, hi: float, step: float,
		digits: int = 2) -> HBoxContainer:
	var authored: Variant = null
	if _authored_env != null:
		authored = _authored_env.get(prop)
	return _knob(title, lo, hi, step,
		func() -> float: return float(_env().get(prop)),
		func(v: float) -> void: _env().set(prop, v),
		digits, authored)


func _gfx_knob(title: String, key: String, lo: float, hi: float, step: float,
		digits: int = 2) -> HBoxContainer:
	return _knob(title, lo, hi, step,
		func() -> float: return float(Cfg.gfx [key]),
		func(v: float) -> void: _set_gfx_live(key, v),
		digits, _authored_gfx.get(key))


func _light_knob(title: String, node_name: String, prop: String,
		lo: float, hi: float, step: float, digits: int = 2) -> HBoxContainer:
	var authored: Dictionary = (_authored_sun if node_name == "Sun"
		else _authored_fill)
	return _knob(title, lo, hi, step,
		func() -> float: return float(_light(node_name).get(prop)),
		func(v: float) -> void: _light(node_name).set(prop, v),
		digits, authored.get(prop))


func _sun_aim_knob(title: String, lo: float, hi: float, getter: Callable,
		setter: Callable, authored: Variant) -> HBoxContainer:
	var row:= _knob(title, lo, hi, 0.5, getter, setter, 1, authored)
	_sun_refresh.append(_look_refresh [_look_refresh.size() - 1])
	return row


func _sun_rot_knob(title: String, axis: int) -> HBoxContainer:
	var authored: Variant = null
	if _authored_sun.has("rotation_degrees"):
		authored = (_authored_sun ["rotation_degrees"] as Vector3) [axis]
	var row:= _knob(title, -180.0, 180.0, 0.5,
		_sun_rot.bind(axis), _set_sun_rot.bind(axis), 1, authored)
	_sun_refresh.append(_look_refresh [_look_refresh.size() - 1])
	return row


func _set_gfx_live(key: String, value: Variant) -> void:
	Cfg.gfx [key] = value
	if world != null:
		world._apply_render_settings()


func _sun_rot(axis: int) -> float:
	var sun:= _sun()
	return 0.0 if sun == null else sun.rotation_degrees [axis]


func _set_sun_rot(degrees: float, axis: int) -> void:
	var sun:= _sun()
	if sun == null:
		return
	var r:= sun.rotation_degrees
	r [axis] = degrees
	sun.rotation_degrees = r
	_refresh_sun()


func _set_sun_elev(degrees: float) -> void:
	_sun_elev = degrees
	_aim_sun()


func _set_sun_azim(degrees: float) -> void:
	_sun_azim = degrees
	_aim_sun()


func _aim_sun() -> void:
	var sun:= _sun()
	if sun == null:
		return
	var el:= deg_to_rad(_sun_elev)
	var az:= deg_to_rad(_sun_azim)
	var dir:= Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
	sun.transform = Transform3D(Basis(), dir).looking_at(Vector3.ZERO, Vector3.UP)
	_refresh_sun()


func _authored_angle(elevation: bool) -> Variant:
	if not _authored_sun.has("transform"):
		return null
	var dir:= (_authored_sun ["transform"] as Transform3D).basis.z.normalized()
	if elevation:
		return clampf(rad_to_deg(asin(clampf(dir.y, -1.0, 1.0))),
			SUN_ELEV_MIN, SUN_ELEV_MAX)
	return rad_to_deg(atan2(dir.x, dir.z))


func _refresh_sun() -> void:
	var sun:= _sun()
	if sun != null:


		var dir:= sun.global_transform.basis.z.normalized()
		_sun_elev = clampf(rad_to_deg(asin(clampf(dir.y, -1.0, 1.0))),
			SUN_ELEV_MIN, SUN_ELEV_MAX)
		_sun_azim = rad_to_deg(atan2(dir.x, dir.z))
	for refresh: Callable in _sun_refresh:
		refresh.call()


func _refresh_look() -> void:
	_refresh_sun()
	for refresh: Callable in _look_refresh:
		refresh.call()


func _on_look_copy() -> void:
	var text:= _look_text()
	if text == "":
		_toast(tr("No look in this world"))
		return
	DisplayServer.clipboard_set(text)
	print("\n=== look ===\n%s\n" % text)
	_toast(tr("Copied, and printed to the log"))


func _look_text() -> String:
	var e:= _env()
	var sun:= _sun()
	var fill:= _light("BounceFill")
	if e == null or sun == null or fill == null:
		return ""
	var lines:= PackedStringArray()
	lines.append("; yard_environment.tres")
	lines.append("tonemap_mode = %d" % int(e.tonemap_mode))
	lines.append("tonemap_exposure = %s" % String.num(e.tonemap_exposure, 4))
	lines.append("tonemap_white = %s" % String.num(e.tonemap_white, 4))
	lines.append("ambient_light_energy = %s"
		% String.num(e.ambient_light_energy, 4))
	lines.append("ambient_light_sky_contribution = %s"
		% String.num(e.ambient_light_sky_contribution, 4))
	lines.append("ssao_intensity = %s" % String.num(e.ssao_intensity, 4))
	lines.append("ssil_intensity = %s" % String.num(e.ssil_intensity, 4))
	lines.append("glow_intensity = %s" % String.num(e.glow_intensity, 4))
	lines.append("glow_bloom = %s" % String.num(e.glow_bloom, 4))
	lines.append("fog_density = %s" % String.num(e.fog_density, 5))
	lines.append("fog_aerial_perspective = %s"
		% String.num(e.fog_aerial_perspective, 4))
	lines.append("fog_sun_scatter = %s" % String.num(e.fog_sun_scatter, 4))
	lines.append("volumetric_fog_density = %s"
		% String.num(e.volumetric_fog_density, 5))
	lines.append("volumetric_fog_ambient_inject = %s"
		% String.num(e.volumetric_fog_ambient_inject, 4))
	lines.append("adjustment_brightness = %s"
		% String.num(e.adjustment_brightness, 4))
	lines.append("adjustment_contrast = %s"
		% String.num(e.adjustment_contrast, 4))
	lines.append("adjustment_saturation = %s"
		% String.num(e.adjustment_saturation, 4))
	lines.append("")
	lines.append("; yard_look.tscn, node Sun")
	lines.append("; rotation %s, which is elevation %s and azimuth %s"
		% [sun.rotation_degrees, String.num(_sun_elev, 1),
			String.num(_sun_azim, 1)])


	lines.append("transform = %s" % var_to_str(sun.transform))
	lines.append("light_energy = %s" % String.num(sun.light_energy, 4))
	lines.append("light_angular_distance = %s"
		% String.num(sun.light_angular_distance, 4))
	lines.append("light_volumetric_fog_energy = %s"
		% String.num(sun.light_volumetric_fog_energy, 4))
	lines.append("directional_shadow_max_distance = %s"
		% String.num(sun.directional_shadow_max_distance, 2))
	lines.append("")
	lines.append("; yard_look.tscn, node BounceFill")
	lines.append("light_energy = %s" % String.num(fill.light_energy, 4))


	var mat:= _sky_material()
	if mat != null and mat.shader != null:
		var moved:= PackedStringArray()
		for u: Dictionary in mat.shader.get_shader_uniform_list():
			var uniform:= String(u ["name"])
			if uniform in SKY_NOT_AUTHORED:
				continue
			var now: Variant = mat.get_shader_parameter(uniform)
			if now == null or typeof(now) == TYPE_OBJECT:
				continue
			var was: Variant = null
			if _authored_sky != null:
				was = _authored_sky.get_shader_parameter(uniform)
			if was != null and _same_value(now, was):
				continue
			moved.append("shader_parameter/%s = %s" % [uniform, var_to_str(now)])
		if not moved.is_empty():
			lines.append("")
			lines.append("; yard_sky.tres")
			lines.append_array(moved)
	return "\n".join(lines)


func _same_value(a: Variant, b: Variant) -> bool:
	if a is float and b is float:
		return is_equal_approx(a, b)
	return a == b


func _on_look_revert() -> void:
	var e:= _env()
	if e == null:
		return
	Cfg.sync_gfx_to_preset(false)

	if _authored_env != null:
		for prop: Dictionary in _authored_env.get_property_list():
			var prop_name:= String(prop ["name"])


			if prop_name.begins_with("resource_") or prop_name == "script":
				continue
			if int(prop ["usage"]) & PROPERTY_USAGE_STORAGE == 0:
				continue
			e.set(prop_name, _authored_env.get(prop_name))

	for light_name: String in ["Sun", "BounceFill"]:
		var authored: Dictionary = (_authored_sun if light_name == "Sun"
			else _authored_fill)
		var dst:= _light(light_name)
		if dst == null or authored.is_empty():
			continue
		for prop_name: String in authored:
			if prop_name == "rotation_degrees":
				continue
			dst.set(prop_name, authored [prop_name])

	var mat:= _sky_material()
	if mat != null and _authored_sky != null and mat.shader != null:
		for u: Dictionary in mat.shader.get_shader_uniform_list():
			var uniform:= String(u ["name"])
			var was: Variant = _authored_sky.get_shader_parameter(uniform)


			mat.set_shader_parameter(uniform, was)

	if world != null:
		world._apply_render_settings()


		world._apply_sky_settings()
	_refresh_look()
	_toast(tr("Back to the authored look"))


func _on_look_save() -> void:
	if world == null:
		return
	var writer:= DevLookExport.new()
	writer.world = world
	writer._save_environment()
	writer._save_look_scene()
	writer.free()


	var mat:= _sky_material()
	if mat != null and mat.resource_path == SKY_MAT_PATH:
		ResourceSaver.save(mat, SKY_MAT_PATH)
	_toast(tr("Written. Reload the scene if the editor has it open"))


func toggle() -> void:
	set_open(not _open)


func is_open() -> bool:
	return _open


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on


	if on:
		_refresh_wallhack()


	if not on and _needle_modal != null:
		_needle_modal.visible = false


	if not on and _look_modal != null:
		_look_modal.visible = false
		_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


	if player != null:
		player.capture_mouse(not on)
		player.free_move = on
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _input(event: InputEvent) -> void:
	if not _open or player == null:
		return
	var mb:= event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	player.capture_mouse(mb.pressed)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("free_mouse"):


		if _needle_modal != null and _needle_modal.visible:
			_close_needle_picker()
		elif _look_modal != null and _look_modal.visible:
			_close_look_panel()
		else:
			set_open(false)
		get_viewport().set_input_as_handled()
