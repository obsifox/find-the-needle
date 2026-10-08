class_name OptionsPanel
extends VBoxContainer


const COL_ACCENT:= Color(0.58, 0.72, 0.9)
const COL_TEXT:= Color(0.93, 0.95, 0.98)
const COL_DIM:= Color(0.6, 0.65, 0.73)
const COL_EDGE:= Color(0.42, 0.5, 0.62, 0.55)
const COL_FILL:= Color(0.09, 0.11, 0.14, 0.92)


const COL_WARN:= Color(0.93, 0.76, 0.42)


const COL_GO:= Color(0.2, 0.55, 0.28)
const COL_STOP:= Color(0.72, 0.22, 0.2)
const ICON_QUIT:= preload("res://assets/ui/icon_power.svg")
const ICON_LATER:= preload("res://assets/ui/icon_recent.svg")


const NOTICE:= {
	"title": "RESTART TO SWITCH",
	"renderer": "You are playing on %s now. The game switches to %s the next time it starts.",
	"language": "The game is in %s now. It switches to %s the next time it starts.",
	"render_thread_on": "The render thread turns on the next time the game starts.",
	"render_thread_off": "The render thread turns off the next time the game starts.",
	"saves": "Save and quit now, then start the game again. Or keep playing and switch later.",
	"quits": "Quit now, then start the game again. Or switch later.",
	"save_quit": "SAVE AND QUIT",
	"quit": "QUIT GAME",
	"later": "LATER",
}


const TABS: Array [String] = ["AUDIO", "CONTROLS", "HUD", "DISPLAY", "GRAPHICS", "GAMEPLAY"]


const PAGE_W:= 700.0

const LABEL_W:= 250.0
const LABEL_W_NARROW:= 168.0


const SCROLL_GUTTER:= 20.0

var label_width:= LABEL_W

var _tab:= 0
var _pages: Array [Control] = []
var _tab_buttons: Array [Button] = []


var _tab_bar: HBoxContainer = null


var _bar_host: Node = null
var _bar_index:= 0


const BIND_COLUMNS: Array [Array] = [
	["MOVEMENT", "HANDS", "BUILDING"],
	["HOTBAR", "SYSTEM"],
]


var _capturing:= ""
var _bind_buttons: Dictionary = { }
var _bind_note: Label


const GAMEPLAY_BODY:= 13
const GAMEPLAY_NOTE:= 12


var _yard_note: Label
var _clean_note: Label
var _belt_note: Label


var _belt_sb: StyleBoxFlat
var _belt_title: Label
var _belt_full_line: Label
var _readout_note: Label
var _mission_note: Label


var _sweep_button: Button
var _sweep_note: Label


var _sweep_armed:= false


var quit_action: Callable


var quit_saves:= false


const RESTART_LAYER:= 100


var _restart_layer: CanvasLayer = null
var _restart_body: Label
var _restart_quit: Button
var _restart_later: Button
var _restart_title: Label
var _restart_alt: Label


func _init(p_label_width: float = LABEL_W) -> void:
	label_width = p_label_width


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(PAGE_W, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


	set_process_input(false)


	if not InputSetup.changed.is_connected(_refresh_bindings):
		InputSetup.changed.connect(_refresh_bindings)


	if not visibility_changed.is_connected(_on_visibility):
		visibility_changed.connect(_on_visibility)

	_build_tab_bar()

	_pages.clear()
	var stack:= VBoxContainer.new()
	stack.custom_minimum_size = Vector2(PAGE_W, 0)
	add_child(stack)
	for i in TABS.size():
		var page:= VBoxContainer.new()
		page.add_theme_constant_override("separation", 2)
		page.custom_minimum_size = Vector2(PAGE_W, 0)
		page.visible = i == _tab
		stack.add_child(page)
		_pages.append(page)

	_build_audio(_pages [0])
	_build_controls(_pages [1])
	_build_hud(_pages [2])
	_build_display(_pages [3])
	_build_graphics(_pages [4])
	_build_gameplay(_pages [5])
	_select_tab(_tab)


func fit_into(scroll: ScrollContainer, cap: float, screen_reserve:= 0.0) -> void:


	if not is_node_ready():
		await ready
	var host:= scroll.get_parent()
	var bar_h:= 0.0
	if host != null and _tab_bar != null and _tab_bar.get_parent() == self:
		_bar_host = host
		_bar_index = scroll.get_index()
		_pin_bar()
		bar_h = _tab_bar.get_combined_minimum_size().y
		if host is BoxContainer:
			bar_h += host.get_theme_constant("separation")


		tree_exiting.connect(func() -> void:
			if is_instance_valid(_tab_bar):
				_tab_bar.queue_free())


	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var fit:= func() -> void:
		var total:= cap
		if screen_reserve > 0.0 and is_inside_tree():
			total = maxf(cap, get_viewport().get_visible_rect().size.y - screen_reserve)
		var page_cap:= maxf(total - bar_h, 0.0)
		scroll.custom_minimum_size = Vector2(PAGE_W + SCROLL_GUTTER,
			minf(get_combined_minimum_size().y, page_cap))
	minimum_size_changed.connect(fit)
	if screen_reserve > 0.0 and is_inside_tree():
		get_viewport().size_changed.connect(fit)
		tree_exiting.connect(func() -> void:
			if get_viewport().size_changed.is_connected(fit):
				get_viewport().size_changed.disconnect(fit))
	fit.call()


func _pin_bar() -> void:
	if _bar_host == null or not is_instance_valid(_bar_host):
		return
	if _tab_bar == null or _tab_bar.get_parent() != self:
		return
	remove_child(_tab_bar)


	_tab_bar.custom_minimum_size = Vector2(PAGE_W + SCROLL_GUTTER, 0)
	_tab_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	_bar_host.add_child(_tab_bar)
	_bar_host.move_child(_tab_bar, _bar_index)


func _build_tab_bar() -> void:
	var bar:= HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER


	bar.custom_minimum_size = Vector2(PAGE_W, 0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(bar)
	_tab_bar = bar
	_tab_buttons.clear()


	var tab_w:= floorf((PAGE_W - 6.0 * (TABS.size() - 1)) / TABS.size())
	for i in TABS.size():
		var b:= Button.new()
		b.text = _tab_label(i)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(tab_w, 32)
		_style_tab(b, i == _tab)
		b.pressed.connect(_select_tab.bind(i))
		bar.add_child(b)
		_tab_buttons.append(b)


func _tab_label(i: int) -> String:
	match TABS [i]:
		"AUDIO":
			return tr("AUDIO")
		"CONTROLS":
			return tr("CONTROLS")
		"HUD":
			return tr("HUD")
		"DISPLAY":
			return tr("DISPLAY")
		"GRAPHICS":
			return tr("GRAPHICS")
		"GAMEPLAY":
			return tr("GAMEPLAY")
	return TABS [i]


func _select_tab(index: int) -> void:


	_end_capture()
	_tab = index
	for i in _pages.size():
		_pages [i].visible = i == index
	for i in _tab_buttons.size():
		_style_tab(_tab_buttons [i], i == index)
	if TABS [index] == "GAMEPLAY":
		_refresh_gameplay_notes()


func _refresh_gameplay_notes() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_yard_note):
		_yard_note.text = _yard_verdict()
	if is_instance_valid(_belt_note):
		_belt_note.text = _belt_verdict()
	_paint_belt_card()
	if is_instance_valid(_clean_note):
		_clean_note.text = _clean_verdict()
	if is_instance_valid(_readout_note):
		_readout_note.text = _hay_readout_verdict()
	if is_instance_valid(_mission_note):
		_mission_note.text = _mission_verdict()


	_disarm_sweep()


func _build_audio(page: Control) -> void:
	page.add_child(_volume_row(tr("Master"), "master"))
	page.add_child(_volume_row(tr("Music"), "music"))
	page.add_child(_volume_row(tr("Effects"), "sfx"))
	page.add_child(_volume_row(tr("Ambience"), "ambience"))


	page.add_child(_reset_button(tr("RESET TO DEFAULTS"), func() -> void:
		Audio.reset_volumes()
		_rebuild()))


func _build_controls(page: Control) -> void:
	_build_tool_mode_row(page)
	page.add_child(_slider_row(tr("Look sensitivity"), Cfg.MOUSE_SENS_MIN, Cfg.MOUSE_SENS_MAX,
		0.05, Cfg.mouse_sensitivity, _on_sensitivity, _fmt_multiplier))
	page.add_child(_toggle_row(tr("Invert mouse left and right"), Cfg.invert_look_x,
		Cfg.set_invert_look_x))
	page.add_child(_toggle_row(tr("Invert mouse up and down"), Cfg.invert_look_y,
		Cfg.set_invert_look_y))

	if Cfg.is_mobile:
		# BUGFIX (mobile): keyboard rebinding rows are meaningless on touch --
		# hide the whole bindings grid on phones.
		return
	var was:= label_width
	label_width = LABEL_W_NARROW
	_bind_buttons.clear()

	var cols:= HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	page.add_child(cols)
	for groups: Array in BIND_COLUMNS:
		var col:= VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
		for group: String in groups:


			col.add_child(_heading(InputSetup.group_label(group)))
			for row: Dictionary in InputSetup.offered_rows():
				if str(row ["group"]) != group:
					continue
				col.add_child(_bind_row(str(row ["actions"] [0]), str(row ["label"])))

	label_width = was


	_bind_note = _label("", 14, COL_DIM)
	_bind_note.custom_minimum_size = Vector2(0, 22)
	_bind_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_bind_note)


	page.add_child(_reset_button(tr("RESET TO DEFAULTS"), func() -> void:
		_end_capture()
		Cfg.reset_controls()
		InputSetup.reset_all()
		_rebuild()
		_say(tr("All keys reset to default."), COL_DIM)))


func _bind_row(row: String, title: String) -> HBoxContainer:
	var b:= Button.new()
	b.text = InputSetup.label(row)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(116, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_pill(b)
	b.pressed.connect(_begin_capture.bind(row))
	_bind_buttons [row] = b


	var box:= HBoxContainer.new()
	box.add_child(b)
	var filler:= Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	return _row(title, box)


func _build_display(page: Control) -> void:
	_build_language_row(page)


	page.add_child(_slider_row(tr("Tech tree text"), Cfg.TECH_TEXT_SCALE_MIN,
		Cfg.TECH_TEXT_SCALE_MAX, 0.05, Cfg.tech_text_scale, Cfg.set_tech_text_scale,
		_fmt_multiplier))
	page.add_child(_note_under(_label(
		tr("Makes the tech tree text bigger."),
		14, COL_DIM)))
	page.add_child(_quality_row())

	if Cfg.integrated_gpu() and Cfg.quality >= Cfg.Quality.HIGH:
		page.add_child(_note_under(_label(
			tr("Your graphics chip is built into the processor. High and Ultra can run out of memory and crash. Low is safer."),
			14, COL_WARN)))
	_build_window_rows(page)
	if not Cfg.is_mobile:
		page.add_child(_toggle_row(tr("V-Sync"), Cfg.vsync, Cfg.set_vsync))


	var caps:= Cfg.FPS_CAPS
	var fmt_cap:= func(v: float) -> String:
		var cap: int = caps [int(round(v))]
		return tr("MAX") if cap == 0 else "%d" % cap
	page.add_child(_slider_row(tr("Frame rate limit"), 0.0, float(caps.size() - 1), 1.0,
		float(maxi(0, caps.find(Cfg.max_fps))),
		func(v: float) -> void: Cfg.set_max_fps(caps [int(round(v))]), fmt_cap))


	page.add_child(_toggle_row(tr("Smooth camera"), Cfg.smooth_camera, Cfg.set_smooth_camera))
	page.add_child(_slider_row(tr("Camera smoothing"), 0.0, 1.0, 0.05,
		Cfg.smooth_camera_amount, Cfg.set_smooth_camera_amount, _fmt_pct))
	if not Cfg.is_mobile:
		_build_renderer_row(page)
	_build_render_thread_row(page)


	page.add_child(_reset_button(tr("RESET TO DEFAULTS"), func() -> void:
		var was_renderer:= Cfg.renderer
		var was_thread:= Cfg.render_thread_wanted()
		Cfg.reset_display()
		_rebuild()

		if Cfg.renderer != was_renderer:
			_after_renderer_pick()
		elif Cfg.render_thread_wanted() != was_thread:
			_after_render_thread_pick()))


func _build_window_rows(page: Control) -> void:
	var sizes:= Cfg.window_sizes()
	var names:= PackedStringArray()
	for size: Vector2i in sizes:
		names.append("%d x %d" % [size.x, size.y])
	var here: int = maxi(0, sizes.find(Cfg.window_size))

	var note:= _label("", 14, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)
	var refresh:= func() -> void:
		if Cfg.fullscreen:
			var screen:= DisplayServer.screen_get_size(
				DisplayServer.window_get_current_screen())
			note.text = tr("Fullscreen at %d x %d. Resolution only changes windowed mode.") % [
				screen.x, screen.y]
			note.add_theme_color_override("font_color", COL_ACCENT)
		else:
			note.text = tr("Windowed.")
			note.add_theme_color_override("font_color", COL_DIM)

	if not Cfg.is_mobile:
		page.add_child(_toggle_row(tr("Fullscreen"), Cfg.fullscreen,
			func(on: bool) -> void:
				Cfg.set_fullscreen(on)
				refresh.call()))
	if not Cfg.is_mobile:
		page.add_child(_choice_row(tr("Resolution"), names, here,
			func(i: int) -> void: Cfg.set_window_size(sizes [i])))
	page.add_child(_note_under(note))
	refresh.call()


func _note_under(note: Control) -> HBoxContainer:
	var line:= HBoxContainer.new()
	var pad:= Control.new()
	pad.custom_minimum_size = Vector2(label_width + 12.0, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(pad)
	line.add_child(note)
	return line


func _build_tool_mode_row(page: Control) -> void:
	var note:= _wrapped("", 14, COL_DIM)


	var refresh:= func() -> void:
		if Cfg.simple_tools():
			note.text = tr("Left click to dig, right click to empty. Running, jumping or turning fast spills hay.")
		else:
			note.text = tr("Hold right click and move the mouse to tip the tool. Tip it further to empty it faster.")

	page.add_child(_choice_row(tr("Tool handling"),
		PackedStringArray(Cfg.TOOL_MODE_NAMES), Cfg.tool_mode,
		func(i: int) -> void:
			Cfg.set_tool_mode(i)
			refresh.call()))
	page.add_child(_note_under(note))
	refresh.call()


func _build_renderer_row(page: Control) -> void:
	var here: int = maxi(0, Cfg.RENDERERS.find(Cfg.renderer))
	var note:= _label("", 14, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)

	var refresh:= func() -> void:
		var running: String = Cfg.running_renderer()
		var running_name: String = Cfg.RENDERER_NAMES [maxi(0, Cfg.RENDERERS.find(running))]
		if running == Cfg.renderer:
			note.text = tr("Running on %s.") % running_name
			note.add_theme_color_override("font_color", COL_DIM)
		else:
			note.text = tr("Running on %s. Restart to switch.") % running_name
			note.add_theme_color_override("font_color", COL_ACCENT)

	page.add_child(_choice_row(tr("Renderer"), PackedStringArray(Cfg.RENDERER_NAMES), here,
		func(i: int) -> void:
			if not Cfg.set_renderer(Cfg.RENDERERS [i]):
				note.text = tr("Could not write the setting. Is the game folder read-only?")
				note.add_theme_color_override("font_color", COL_ACCENT)
				return
			refresh.call()
			_after_renderer_pick()))

	page.add_child(_note_under(note))
	refresh.call()


func _build_render_thread_row(page: Control) -> void:
	var status:= _wrapped("", 16, COL_TEXT)
	var about:= _wrapped(tr("An experimental Godot feature. It uses a second processor core to draw the game, for more fps. If the game crashes, turn it off."), 15, COL_TEXT.darkened(0.15))
	var notes:= VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override("separation", 2)
	notes.add_child(status)
	notes.add_child(about)

	var on_off:= func(on: bool) -> String:
		return tr("ON") if on else tr("OFF")
	var menu:= OptionButton.new()
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(170, 30)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.add_theme_font_size_override("font_size", 16)
	_style_pill(menu)

	var refresh:= func() -> void:


		menu.clear()
		for i: int in Cfg.RENDER_THREAD_NAMES.size():
			var name:= tr(str(Cfg.RENDER_THREAD_NAMES [i]))
			if i == Cfg.RenderThread.AUTO:
				name = "%s (%s)" % [name, on_off.call(Cfg.render_thread_auto())]
			menu.add_item(name)
		menu.select(int(Cfg.render_thread))
		var running:= Cfg.running_render_thread()
		var wanted:= Cfg.render_thread_wanted()
		if running == wanted:
			status.text = tr("Running now: %s.") % on_off.call(running)
			status.add_theme_color_override("font_color", COL_TEXT)
		else:
			status.text = tr("Running now: %s. After a restart: %s.") % [
				on_off.call(running), on_off.call(wanted)]
			status.add_theme_color_override("font_color", COL_WARN)

	menu.item_selected.connect(func(i: int) -> void:
		if not Cfg.set_render_thread(i):
			status.text = tr("Could not write the setting. Is the game folder read-only?")
			status.add_theme_color_override("font_color", COL_WARN)
			return
		refresh.call()
		_after_render_thread_pick())

	var box:= HBoxContainer.new()
	box.add_child(menu)
	var filler:= Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	page.add_child(_row(tr("Render thread"), box))
	page.add_child(_note_under(notes))
	refresh.call()


const HAY_DENSITY_MAX:= 260.0


func _build_hay_card(page: Control) -> void:
	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)


	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("HAY DENSITY"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("How thick the hay looks. Higher looks better but runs slower."),
		15, COL_TEXT))


	var note:= _label("", 14, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)


	var pending:= { "v": float(Cfg.gfx ["hay_density"]) }
	var apply:= Button.new()
	apply.text = tr("APPLY")
	apply.focus_mode = Control.FOCUS_NONE
	apply.custom_minimum_size = Vector2(120, 28)
	apply.disabled = true
	_style_pill(apply)

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_slider_row(tr("Strands per cell"), float(Cfg.HAY_DENSITY_MIN),
		HAY_DENSITY_MAX, 2.0, pending ["v"],
		func(v: float) -> void:
			pending ["v"] = v
			apply.disabled = is_equal_approx(v, float(Cfg.gfx ["hay_density"]))
			note.text = _hay_verdict(v),
		_fmt_count))


	box.add_child(_note_under(note))
	apply.pressed.connect(func() -> void:
		Cfg.set_gfx("hay_density", pending ["v"])
		apply.disabled = true)
	box.add_child(_note_under(_beside(apply)))
	label_width = was
	note.text = _hay_verdict(pending ["v"])

	box.add_child(_wrapped(
		tr("Higher values can make the game slower."),
		14, COL_WARN))


func _hay_verdict(v: float) -> String:
	if v <= float(Cfg.HAY_DENSITY_MIN) + 4.0:
		return tr("As thin as it gets. Easiest on your computer.")
	if v >= HAY_DENSITY_MAX - 8.0:
		return tr("As thick as it gets. Looks best, runs slowest.")
	return tr("Thicker than normal.")


func _wrapped(text: String, size: int, colour: Color) -> Label:
	var l:= _label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _build_hud(page: Control) -> void:
	page.add_child(_heading(tr("READOUTS")))
	page.add_child(_toggle_row(tr("No HUD"), Cfg.no_hud, Cfg.set_no_hud))


	page.add_child(_note_under(_label(
		tr("Hides the whole HUD. It comes back when you restart the game."),
		14, COL_DIM)))
	page.add_child(_slider_row(tr("HUD scale"), Cfg.HUD_SCALE_MIN, Cfg.HUD_SCALE_MAX,
		0.05, Cfg.hud_scale, Cfg.set_hud_scale, _fmt_multiplier))
	page.add_child(_note_under(_label(
		tr("Size of the whole HUD."),
		14, COL_DIM)))
	page.add_child(_toggle_row(tr("Tool bar"), Cfg.show_hotkey_bar,
		Cfg.set_show_hotkey_bar))
	page.add_child(_toggle_row(tr("Button hints"), Cfg.show_control_hints,
		Cfg.set_show_control_hints))
	page.add_child(_note_under(_label(
		tr("The keys keep working either way."), 14, COL_DIM)))

	page.add_child(_heading(tr("CROSSHAIR")))
	page.add_child(_row(tr("Preview"), _beside(_crosshair_preview())))
	page.add_child(_choice_row(tr("Shape"), PackedStringArray(Cfg.CROSSHAIR_STYLE_NAMES),
		Cfg.crosshair_style, Cfg.set_crosshair_style))
	page.add_child(_slider_row(tr("Size"), Cfg.CROSSHAIR_SIZE_MIN, Cfg.CROSSHAIR_SIZE_MAX,
		0.05, Cfg.crosshair_size, Cfg.set_crosshair_size, _fmt_multiplier))
	page.add_child(_slider_row(tr("Opacity"), Cfg.CROSSHAIR_OPACITY_MIN, 1.0,
		0.05, Cfg.crosshair_opacity, Cfg.set_crosshair_opacity, _fmt_pct))
	page.add_child(_choice_row(tr("Colour"), PackedStringArray(Cfg.CROSSHAIR_COLOUR_NAMES),
		Cfg.crosshair_colour, Cfg.set_crosshair_colour))
	page.add_child(_reset_button(tr("RESET TO DEFAULTS"), func() -> void:
		Cfg.reset_hud()
		_rebuild()))


func _crosshair_preview() -> Control:
	var swatch:= Control.new()
	swatch.custom_minimum_size = Vector2(150, 54)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Cfg.hud_style_changed.connect(swatch.queue_redraw)
	swatch.draw.connect(func() -> void:
		var half:= swatch.size * Vector2(0.5, 1.0)
		swatch.draw_rect(Rect2(Vector2.ZERO, half), Color(0.78, 0.66, 0.36))
		swatch.draw_rect(Rect2(Vector2(half.x, 0.0), half), Color(0.24, 0.2, 0.14))


		Hud.draw_crosshair(swatch, (swatch.size * 0.5).round(),
			Hud.CROSS_RADIUS * Cfg.crosshair_size, 1.0, false))
	return swatch


func _beside(control: Control) -> HBoxContainer:
	var box:= HBoxContainer.new()
	box.add_child(control)
	var filler:= Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	return box


func _build_graphics(page: Control) -> void:
	var was:= label_width
	label_width = LABEL_W_NARROW

	var cols:= HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	page.add_child(cols)

	var left:= VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)

	var right:= VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)


	left.add_child(_heading(tr("BIGGEST FPS GAINS")))
	left.add_child(_gfx_dropdown(tr("Machine render distance"), Cfg.MACHINE_DISTANCE_NAMES,
		"machine_distance"))
	left.add_child(_note_under(_wrapped(tr("Machines keep working beyond this distance."), 14, COL_ACCENT)))
	left.add_child(_wrapped(tr("Depth fog softens the distance cutoff."), 14, COL_DIM))
	left.add_child(_gfx_slider(tr("Render scale"), 0.5, 1.0, 0.05, "render_scale", _fmt_pct))
	left.add_child(_gfx_toggle(tr("Sun shadows"), "shadows"))
	left.add_child(_gfx_dropdown(tr("Shadow quality"), Cfg.SHADOW_QUALITY_NAMES,
		"shadow_quality"))
	left.add_child(_gfx_slider(tr("Shadow blur"), 0.0, 10.0, 0.2,
		"shadow_blur", _fmt_degrees))
	left.add_child(_gfx_toggle(tr("Ambient occlusion"), "ssao"))
	left.add_child(_gfx_toggle(tr("Bounced light"), "gi"))
	left.add_child(_gfx_toggle(tr("Volumetric fog"), "vfog"))
	left.add_child(_gfx_choice(tr("Antialiasing"), Cfg.MSAA_NAMES, "msaa"))
	left.add_child(_note_under(_label(
		tr("Turn these down first if the game is slow."), 14, COL_ACCENT)))

	left.add_child(_heading(tr("HAY AND SURFACES")))


	left.add_child(_gfx_choice(tr("Floor texture"), Cfg.TEXTURE_RES_NAMES, "texture_res"))


	left.add_child(_gfx_slider(tr("Hay at distance"), 0.3, 1.0, 0.05, "hay_lod_min", _fmt_pct))

	left.add_child(_heading(tr("LIGHTING LOOK")))


	left.add_child(_gfx_toggle(tr("Ambient from sky"), "ambient_sky"))
	left.add_child(_gfx_slider(tr("Sky contribution"), 0.0, 1.0, 0.05, "sky_contribution", _fmt_pct))
	left.add_child(_gfx_toggle(tr("Sky reflections"), "reflect_sky"))


	left.add_child(_gfx_toggle(tr("Room reflections"), "reflect_probe"))

	right.add_child(_heading(tr("SMALLER FPS GAINS")))
	right.add_child(_gfx_toggle(tr("Temporal AA"), "taa"))
	right.add_child(_gfx_toggle(tr("FXAA"), "fxaa"))
	right.add_child(_gfx_toggle(tr("Indirect light"), "ssil"))
	right.add_child(_gfx_toggle(tr("Depth fog"), "fog"))


	right.add_child(_gfx_toggle(tr("Dust motes"), "dust"))
	right.add_child(_gfx_toggle(tr("Bloom"), "glow"))
	right.add_child(_gfx_toggle(tr("Near focus blur"), "dof"))

	right.add_child(_heading(tr("IMAGE")))
	right.add_child(_gfx_slider(tr("Bloom strength"), 0.0, 1.0, 0.02, "glow_intensity", _fmt_amount))
	right.add_child(_gfx_choice(tr("Tonemap"), Cfg.TONEMAP_NAMES, "tonemap"))
	right.add_child(_gfx_slider(tr("Exposure"), 0.2, 2.0, 0.05, "exposure", _fmt_amount))
	right.add_child(_gfx_slider(tr("White point"), 1.0, 16.0, 0.5, "white", _fmt_amount))
	right.add_child(_gfx_toggle(tr("Contrast / sat."), "adjustment"))
	right.add_child(_gfx_toggle(tr("Colour grade"), "color_correction"))


	right.add_child(_gfx_toggle(tr("Auto exposure"), "auto_exposure"))

	right.add_child(_heading(tr("RECOVERY")))
	right.add_child(_shell_rebuild_row())

	label_width = was


	_build_hay_card(page)


	page.add_child(_reset_button(tr("RESET TO PRESET"), func() -> void:
		Cfg.reset_gfx()
		_rebuild()))


func _build_gameplay(page: Control) -> void:


	_build_belt_card(page)
	_build_mission_card(page)
	_build_tips_card(page)
	_build_hay_readout_card(page)

	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("LOOSE ITEMS IN THE YARD"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("How many wads, bales and bricks can lie around the yard. Past this number, the ones furthest from you go back onto the pile. Items you hold or a machine is picking up are safe."),
		GAMEPLAY_BODY, COL_TEXT))


	box.add_child(_wrapped(
		tr("The graphics preset sets this for you. Move the slider and it stays where you put it."),
		GAMEPLAY_NOTE, COL_DIM))

	var note:= _label("", GAMEPLAY_BODY, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)
	_yard_note = note

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_toggle_row(tr("Cap the yard"), Cfg.prop_decay,
		func(v: bool) -> void:
			Cfg.set_prop_decay(v)
			note.text = _yard_verdict()))
	box.add_child(_slider_row(tr("Items allowed"), float(Cfg.PROP_CAP_MIN),
		float(Cfg.PROP_CAP_MAX), 5.0, float(Cfg.prop_cap),
		func(v: float) -> void:
			Cfg.set_prop_cap(int(v))
			note.text = _yard_verdict(),
		_fmt_count))


	box.add_child(_note_under(note))
	label_width = was
	note.text = _yard_verdict()

	box.add_child(_wrapped(
		tr("With no limit, the floor can fill up and the game will get slow."),
		GAMEPLAY_NOTE, COL_WARN))

	_build_sweep_rows(box)

	_build_clean_card(page)

	_build_build_fx_card(page)


	page.add_child(_reset_button(tr("RESET TO DEFAULTS"), func() -> void:
		Cfg.reset_gameplay()
		_rebuild()))


func _build_clean_card(page: Control) -> void:
	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("AUTO CLEANER"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("Hay, bales and bricks that lie still on the floor too long go back onto the pile. Items you hold, items on belts and items a machine is picking up are safe."),
		GAMEPLAY_BODY, COL_TEXT))

	var note:= _label("", GAMEPLAY_BODY, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)
	_clean_note = note

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_toggle_row(tr("Auto clean"), Cfg.auto_clean,
		func(v: bool) -> void:
			Cfg.set_auto_clean(v)
			note.text = _clean_verdict()))
	box.add_child(_slider_row(tr("Clean after"), Cfg.AUTO_CLEAN_SECONDS_MIN,
		Cfg.AUTO_CLEAN_SECONDS_MAX, 15.0, Cfg.auto_clean_seconds,
		func(v: float) -> void:
			Cfg.set_auto_clean_seconds(v)
			note.text = _clean_verdict(),
		_fmt_wait))

	box.add_child(_note_under(note))
	label_width = was
	note.text = _clean_verdict()

	box.add_child(_wrapped(
		tr("Saving bales for later? Keep this off, or they will be cleaned up too."),
		GAMEPLAY_NOTE, COL_WARN))


func _clean_verdict() -> String:
	if not Cfg.auto_clean:
		return tr("Off. Hay stays where it lands.")
	return tr("Hay still for %s goes back on the pile.") % _fmt_wait(Cfg.auto_clean_seconds)


func _build_build_fx_card(page: Control) -> void:
	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("BUILD EFFECTS"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("A glowing hologram and sparks when you build something or take it down."),
		GAMEPLAY_BODY, COL_TEXT))

	var note:= _label("", GAMEPLAY_BODY, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_toggle_row(tr("Build effects"), Cfg.build_fx,
		func(v: bool) -> void:
			Cfg.set_build_fx(v)
			note.text = _build_fx_verdict()))
	box.add_child(_note_under(note))
	label_width = was
	note.text = _build_fx_verdict()


func _build_fx_verdict() -> String:
	if not Cfg.build_fx:
		return tr("Off. Buildings just appear and disappear.")
	return tr("On. Buildings glow as they go up and come down.")


func _build_sweep_rows(box: VBoxContainer) -> void:
	var pad:= Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pad)

	var b:= Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(290, 28)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_pill(b)
	b.pressed.connect(_on_sweep_pressed)
	box.add_child(b)
	_sweep_button = b

	var note:= _wrapped("", GAMEPLAY_NOTE, COL_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_sweep_note = note

	_disarm_sweep()


func _yard() -> PropManager:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager


func _disarm_sweep() -> void:
	_sweep_armed = false
	if not is_instance_valid(_sweep_button):
		return
	_sweep_button.text = tr("PUT LOOSE HAY BACK ON THE PILE")
	var live:= _yard() != null
	_sweep_button.disabled = not live
	if live:
		_say_sweep(tr("Puts everything on the floor back onto the pile. Bales and bricks turn back into plain hay, so sell them first."), COL_DIM)
	else:
		_say_sweep(tr("Only works while you are playing."), COL_DIM)


func _say_sweep(text: String, colour: Color) -> void:
	_sweep_note.text = text
	_sweep_note.add_theme_color_override("font_color", colour)


func _on_sweep_pressed() -> void:
	var props:= _yard()
	if props == null:
		_disarm_sweep()
		return
	if not _sweep_armed:
		_sweep_armed = true
		_sweep_button.text = tr("YES, PUT IT ALL BACK")
		_say_sweep(tr("This cannot be undone. Press it again to do it."), COL_WARN)
		Audio.play("ui_click", -4.0)
		return

	var things:= props.sweep_floor()
	var straws:= props.live.sweep_floor() if props.live != null else 0


	_disarm_sweep()
	if things == 0 and straws == 0:
		_say_sweep(tr("Nothing was lying around. The floor is already clear."), COL_DIM)
		Audio.play("ui_back", -6.0)
	else:
		_say_sweep(tr("Put %d things and %d straws back on the pile.") % [things, straws],
			COL_ACCENT)
		Audio.play("ui_drop", -2.0)


	if is_instance_valid(_yard_note):
		_yard_note.text = _yard_verdict()


func _build_belt_card(page: Control) -> void:


	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.border_width_left = 5
	_belt_sb = sb
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	_belt_title = _label(tr("STUFF ON THE BELTS"), 15, COL_ACCENT, true)
	box.add_child(_belt_title)
	_belt_full_line = _label(
		tr("Your belts are full now. Raise the limit to stop things disappearing."),
		GAMEPLAY_BODY, COL_WARN)
	box.add_child(_belt_full_line)
	_paint_belt_card()
	box.add_child(_wrapped(
		tr("How many items can ride your belts at once. Loose straw only counts as a small part of a load. Past this number, new items at the start of a belt go back onto the pile."),
		GAMEPLAY_BODY, COL_TEXT))

	var note:= _label("", GAMEPLAY_BODY, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)
	_belt_note = note

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_toggle_row(tr("Cap the belts"), Cfg.belt_decay,
		func(v: bool) -> void:
			Cfg.set_belt_decay(v)
			note.text = _belt_verdict()
			_paint_belt_card()))
	box.add_child(_slider_row(tr("Loads allowed"), float(Cfg.BELT_CAP_MIN),
		float(Cfg.BELT_CAP_MAX), 5.0, float(Cfg.belt_cap),
		func(v: float) -> void:
			Cfg.set_belt_cap(int(v))
			note.text = _belt_verdict()
			_paint_belt_card(),
		_fmt_count))


	box.add_child(_note_under(note))
	label_width = was
	note.text = _belt_verdict()

	box.add_child(_wrapped(
		tr("Full belts are hard on your computer. Lower this first if a big factory makes the game slow."),
		GAMEPLAY_NOTE, COL_WARN))


func _paint_belt_card() -> void:
	if _belt_sb == null or not is_instance_valid(_belt_title):
		return
	var full:= Cfg.belt_decay and is_inside_tree() and get_tree().get_first_node_in_group(PropManager.GROUP) != null and BeltPath.belt_load() >= Cfg.belt_cap
	var edge:= COL_WARN if full else COL_ACCENT
	_belt_sb.border_color = edge
	_belt_title.add_theme_color_override("font_color", edge)
	_belt_full_line.visible = full


func _belt_verdict() -> String:
	if not Cfg.belt_decay:
		return tr("No limit. The belts will carry whatever you put on them.")


	var here:= ""
	if get_tree().get_first_node_in_group(PropManager.GROUP) != null:
		here = tr("  ·  %d loads riding now") % BeltPath.belt_load()
	if Cfg.belt_cap <= Cfg.BELT_CAP_MIN + 10:
		return tr("Low. One long belt can fill this by itself.") + here
	if Cfg.belt_cap <= 600:
		return tr("About what a busy factory keeps moving.") + here
	if Cfg.belt_cap <= 900:
		return tr("More than a working yard needs.") + here
	return tr("As much as the belts can hold. The game will slow down.") + here


func _build_hay_readout_card(page: Control) -> void:
	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("HAY LEFT"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("How much hay is left in the pile, as a percent or an amount."),
		GAMEPLAY_BODY, COL_TEXT))

	var note:= _label("", GAMEPLAY_BODY, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)
	_readout_note = note

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_choice_row(tr("Show it as"), PackedStringArray(Cfg.HAY_READOUT_NAMES),
		Cfg.hay_readout,
		func(i: int) -> void:
			Cfg.set_hay_readout(i)
			note.text = _hay_readout_verdict()))


	box.add_child(_note_under(note))

	box.add_child(_toggle_row(tr("Dug per minute"), Cfg.show_hay_rate,
		func(v: bool) -> void: Cfg.set_show_hay_rate(v)))
	label_width = was
	note.text = _hay_readout_verdict()


func _hay_readout_verdict() -> String:
	if get_tree().get_first_node_in_group(PropManager.GROUP) == null:
		return tr("Shown under your money while you play.")
	return tr("Right now: %s HAY LEFT") % Hud.hay_left_amount()


func _yard_verdict() -> String:
	if not Cfg.prop_decay:
		return tr("No limit. Nothing ever disappears.")

	var here:= ""
	var props:= get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager
	if props != null:
		here = tr("  ·  %d out there now") % props.yard_count()


	if Cfg.prop_cap <= Cfg.PROP_CAP_MIN + 10:
		return tr("Low. One busy machine can hit this by itself.") + here
	if Cfg.prop_cap <= 150:
		return tr("Plenty for a busy yard.") + here
	if Cfg.prop_cap <= 600:
		return tr("A big pile of stuff, more than you need.") + here
	return tr("As much stuff as the yard can hold. The game will slow down.") + here


func _build_mission_card(page: Control) -> void:
	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("MISSIONS"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("The card in the top left corner that tells you what to do next. You can ignore it."),
		GAMEPLAY_BODY, COL_TEXT))

	var note:= _label("", GAMEPLAY_BODY, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)
	_mission_note = note

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_toggle_row(tr("Show missions"), Cfg.show_missions,
		func(v: bool) -> void:
			Cfg.set_show_missions(v)
			note.text = _mission_verdict()))


	box.add_child(_note_under(note))
	label_width = was
	note.text = _mission_verdict()

	box.add_child(_wrapped(
		tr("Hides the card. Your progress is kept."),
		GAMEPLAY_NOTE, COL_DIM))


func _build_tips_card(page: Control) -> void:
	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_ACCENT, 0.45)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)
	page.add_child(card)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(tr("TIPS"), 15, COL_ACCENT, true))
	box.add_child(_wrapped(
		tr("Shows a tip at the top of the screen every few minutes."),
		GAMEPLAY_BODY, COL_TEXT))

	var was:= label_width
	label_width = LABEL_W_NARROW
	box.add_child(_toggle_row(tr("Show tips"), Cfg.show_tips, Cfg.set_show_tips))


	box.add_child(_toggle_row(tr("Teaching hints"), Cfg.teach_hints,
		Cfg.set_teach_hints))
	label_width = was
	box.add_child(_wrapped(
		tr("New keys, buildings, tech cards and machines are shown to you once. Turn this on again to see them all again."),
		GAMEPLAY_NOTE, COL_DIM))


func _mission_verdict() -> String:
	if not Cfg.show_missions:
		return tr("Hidden. Your progress is kept.")
	if get_tree().get_first_node_in_group(PropManager.GROUP) == null:
		return tr("Shown while you play.")
	var i: int = GameState.mission_index
	if i < 0 or i >= MissionBook.count():
		return tr("All %d done. The card is gone already.") % MissionBook.count()
	return tr("Step %d of %d  ·  %s") % [i + 1, MissionBook.count(),
		MissionBook.say(i, "title")]


func _rebuild() -> void:
	_end_capture()


	if is_instance_valid(_tab_bar) and _tab_bar.get_parent() != null and _tab_bar.get_parent() != self:
		_tab_bar.get_parent().remove_child(_tab_bar)
		_tab_bar.queue_free()


	for c: Node in get_children():
		remove_child(c)
		c.queue_free()


	_restart_layer = null
	_ready()
	_pin_bar()


func _heading(text: String) -> Control:
	var box:= VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var pad:= Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pad)
	box.add_child(_label(text, 14, COL_ACCENT, true))
	return box


func _row(title: String, control: Control) -> HBoxContainer:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 30)
	var l:= _label(title, 17, COL_TEXT)
	l.custom_minimum_size = Vector2(label_width, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _volume_row(title: String, bus: String) -> HBoxContainer:
	return _slider_row(title, 0.0, 1.0, 0.05, Audio.volume [bus],
		func(v: float) -> void: Audio.set_volume(bus, v), _fmt_pct)


func _slider_row(title: String, lo: float, hi: float, step: float, value: float,
		on_change: Callable, fmt: Callable) -> HBoxContainer:
	var box:= HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var slider:= HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value


	slider.custom_minimum_size = Vector2(90, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE


	slider.scrollable = false
	_style_slider(slider)
	box.add_child(slider)

	var readout:= _label(fmt.call(value), 15, COL_DIM)
	readout.custom_minimum_size = Vector2(50, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(readout)

	slider.value_changed.connect(func(v: float) -> void:
		readout.text = fmt.call(v)
		on_change.call(v))
	return _row(title, box)


func _choice_row(title: String, values: PackedStringArray, index: int,
		on_pick: Callable) -> HBoxContainer:
	var box:= HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var value:= _label(tr(values [index]), 16, COL_TEXT, true)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size = Vector2(90, 0)

	var state:= { "i": index }
	var step:= func(by: int) -> void:
		state ["i"] = wrapi(int(state ["i"]) + by, 0, values.size())
		value.text = tr(values [state ["i"]])
		on_pick.call(int(state ["i"]))

	box.add_child(_arrow("<", step.bind(-1)))
	box.add_child(value)
	box.add_child(_arrow(">", step.bind(1)))
	return _row(title, box)


func _build_language_row(page: Control) -> void:
	var names:= PackedStringArray()
	var here:= 0
	for i: int in Cfg.LOCALES.size():

		names.append(tr("System") if str(Cfg.LOCALES [i] ["code"]) == ""
			else str(Cfg.LOCALES [i] ["name"]))
		if str(Cfg.LOCALES [i] ["code"]) == Cfg.locale:
			here = i
	var note:= _label("", 14, COL_DIM)
	note.custom_minimum_size = Vector2(0, 20)

	var refresh:= func() -> void:
		var running:= Cfg.locale_name(Cfg.running_locale())
		if Cfg.locale_pending():
			note.text = tr("The game is in %s. Restart to switch.") % running
			note.add_theme_color_override("font_color", COL_ACCENT)
		else:
			note.text = tr("The game is in %s.") % running
			note.add_theme_color_override("font_color", COL_DIM)


	var menu:= OptionButton.new()
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(170, 26)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for n: String in names:
		menu.add_item(n)
	menu.select(here)
	_style_pill(menu)

	menu.add_theme_font_override("font", UiFont.every_script(true))
	var on_pick:= func(i: int) -> void:
		_pick_language(str(Cfg.LOCALES [i] ["code"]))
		refresh.call()
	menu.item_selected.connect(on_pick)

	var box:= HBoxContainer.new()
	box.add_child(menu)
	var filler:= Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	page.add_child(_row(tr("Language"), box))
	page.add_child(_note_under(note))
	refresh.call()


func _pick_language(code: String) -> void:
	if not Cfg.choose_locale(code):
		return
	if not Cfg.locale_pending():
		_hide_restart_notice(true)
		return
	var running:= Cfg.locale_name(Cfg.running_locale())
	var picked:= Cfg.locale_name(Cfg.locale)
	_show_restart_notice("language", [running, picked], Cfg.locale)


func _quality_row() -> HBoxContainer:
	var levels: Array = Cfg.PRESETS.keys()
	var names:= PackedStringArray()
	for level: Variant in levels:


		names.append(Cfg.upper(tr(str(Cfg.PRESETS [level] ["name"]))))
	var here: int = maxi(0, levels.find(Cfg.quality))
	return _choice_row(tr("Quality preset"), names, here,
		func(i: int) -> void:
			Cfg.set_quality(levels [i])
			_rebuild())


func _toggle_row(title: String, on: bool, on_change: Callable) -> HBoxContainer:
	var b:= Button.new()
	b.text = tr("ON") if on else tr("OFF")
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_pill(b)
	b.toggled.connect(func(pressed: bool) -> void:
		b.text = tr("ON") if pressed else tr("OFF")
		on_change.call(pressed))


	var box:= HBoxContainer.new()
	box.add_child(b)
	var filler:= Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	return _row(title, box)


func _gfx_toggle(title: String, key: String) -> HBoxContainer:
	return _toggle_row(title, bool(Cfg.gfx [key]),
		func(v: bool) -> void: Cfg.set_gfx(key, v))


func _gfx_slider(title: String, lo: float, hi: float, step: float, key: String,
		fmt: Callable) -> HBoxContainer:
	return _slider_row(title, lo, hi, step, float(Cfg.gfx [key]),
		func(v: float) -> void: Cfg.set_gfx(key, v), fmt)


func _gfx_choice(title: String, names: Array, key: String) -> HBoxContainer:
	var list:= PackedStringArray(names)
	return _choice_row(title, list, clampi(int(Cfg.gfx [key]), 0, list.size() - 1),
		func(i: int) -> void: Cfg.set_gfx(key, i))


func _gfx_dropdown(title: String, names: Array, key: String) -> HBoxContainer:
	var list:= PackedStringArray(names)
	var menu:= OptionButton.new()
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(128, 26)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for item: String in list:
		menu.add_item(tr(item))
	menu.select(clampi(int(Cfg.gfx [key]), 0, list.size() - 1))
	_style_pill(menu)
	menu.item_selected.connect(func(i: int) -> void: Cfg.set_gfx(key, i))

	var box:= HBoxContainer.new()
	box.add_child(menu)
	var filler:= Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	return _row(title, box)


func _shell_rebuild_row() -> HBoxContainer:
	var b:= Button.new()
	var field:= _active_hay_field()
	b.text = tr("REBUILD") if field != null else tr("IN GAME")
	b.disabled = field == null
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(116, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tr("Rebuilds how the pile looks. Use it if the pile looks wrong.")
	_style_pill(b)
	b.pressed.connect(_on_shell_rebuild.bind(b))
	return _row(tr("Hay shell"), _beside(b))


func _active_hay_field() -> HayField:
	var scene:= get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("HayField", true, false) as HayField


func _on_shell_rebuild(b: Button) -> void:
	var field:= _active_hay_field()
	if field == null:
		b.text = tr("IN GAME")
		b.disabled = true
		return
	b.text = tr("WORKING")
	b.disabled = true
	await get_tree().process_frame
	var rebuilt:= field.rebuild_shells()
	if not is_instance_valid(b):
		return
	b.text = tr("%d DONE") % rebuilt
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(b):
		b.text = tr("REBUILD")
		b.disabled = false


func _arrow(glyph: String, action: Callable) -> Button:
	var b:= Button.new()
	b.text = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_pill(b)
	b.pressed.connect(action)
	return b


func _style_tab(b: Button, on: bool) -> void:
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", COL_ACCENT if on else COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", COL_ACCENT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.17, 0.22, 0.95) if on else Color(0.07, 0.08, 0.1, 0.55)
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
		sb.content_margin_top = 5.0
		sb.content_margin_bottom = 5.0


		sb.border_width_bottom = 2
		sb.border_color = COL_ACCENT if on else Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(state, sb)


func _reset_button(text: String, action: Callable) -> Control:
	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var pad:= Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pad)

	var b:= Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 28)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_pill(b)
	b.pressed.connect(action)
	box.add_child(b)
	return box


func _style_pill(b: Button) -> void:
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_ACCENT)
	b.add_theme_color_override("font_pressed_color", COL_ACCENT)


	b.add_theme_color_override("font_hover_pressed_color", COL_ACCENT)


	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var accent:= state != "normal" and state != "focus" and state != "disabled"
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.18, 0.24, 0.95) if accent else COL_FILL
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(1)
		sb.border_color = COL_ACCENT if accent else COL_EDGE
		sb.content_margin_top = 3.0
		sb.content_margin_bottom = 3.0
		b.add_theme_stylebox_override(state, sb)


func _style_slider(s: HSlider) -> void:
	var track:= StyleBoxFlat.new()
	track.bg_color = COL_FILL
	track.set_corner_radius_all(0)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", track)

	var filled:= StyleBoxFlat.new()
	filled.bg_color = Color(COL_ACCENT, 0.85)
	filled.set_corner_radius_all(0)
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)


	s.add_theme_constant_override("center_grabber", 1)


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(l, size, colour, 4, heavy)
	return l


func _after_renderer_pick() -> void:
	if Cfg.renderer == Cfg.running_renderer():
		_hide_restart_notice(true)
		return
	var running:= tr(str(Cfg.RENDERER_NAMES [maxi(0, Cfg.RENDERERS.find(Cfg.running_renderer()))]))
	var picked:= tr(str(Cfg.RENDERER_NAMES [maxi(0, Cfg.RENDERERS.find(Cfg.renderer))]))
	_show_restart_notice("renderer", [running, picked])


func _after_render_thread_pick() -> void:
	var wanted:= Cfg.render_thread_wanted()
	if wanted == Cfg.running_render_thread():
		_hide_restart_notice(true)
		return
	_show_restart_notice("render_thread_on" if wanted else "render_thread_off", [])


func is_restart_notice_open() -> bool:
	return _restart_layer != null and is_instance_valid(_restart_layer) and _restart_layer.visible


func _show_restart_notice(head: String, args: Array, picked:= "") -> void:
	if _restart_layer == null or not is_instance_valid(_restart_layer):
		_build_restart_notice()
	var can_quit:= quit_action.is_valid()
	var saves:= can_quit and quit_saves
	var way:= "saves" if saves else ("quits" if can_quit else "")


	var here:= TranslationServer.get_locale()
	var langs: Array [String] = [here]
	if picked != "" and Cfg._language_of(picked) != Cfg._language_of(here):
		langs = [Cfg._language_of(picked), here]

	var said: Array [String] = []
	for lang: String in langs:
		var text:= _say_in(NOTICE [head], lang) % args
		if way != "":
			text += "\n\n" + _say_in(NOTICE [way], lang)
		said.append(text)
	_restart_title.text = _say_in(NOTICE ["title"], langs [0])
	_restart_body.text = said [0]
	_restart_alt.visible = langs.size() > 1
	_restart_alt.text = "" if langs.size() < 2 else _say_in(NOTICE ["title"], langs [1]) + "\n" + said [1]
	_restart_later.text = _in_each(NOTICE ["later"], langs)
	_restart_quit.text = _in_each(NOTICE ["save_quit"] if saves else NOTICE ["quit"], langs)
	_restart_quit.visible = can_quit

	_restart_layer.visible = true
	set_process_input(true)
	Audio.play("ui_open", -4.0)


func _in_each(msgid: String, langs: Array [String]) -> String:
	var lines:= PackedStringArray()
	for lang: String in langs:
		lines.append(_say_in(msgid, lang))
	return "\n".join(lines)


static func _say_in(msgid: String, lang: String) -> String:
	for t: Translation in TranslationServer.find_translations(lang, false):
		var said:= String(t.get_message(msgid))
		if said != "":
			return said
	return msgid


func _hide_restart_notice(quiet:= false) -> void:
	if not is_restart_notice_open():
		return
	_restart_layer.visible = false
	set_process_input(_capturing != "")
	if not quiet:
		Audio.play("ui_back", -4.0)


func _on_restart_quit() -> void:
	if not quit_action.is_valid():
		return
	_hide_restart_notice(true)
	Audio.play("ui_select")
	quit_action.call()


func _build_restart_notice() -> void:
	_restart_layer = CanvasLayer.new()
	_restart_layer.name = "RestartNotice"
	_restart_layer.layer = RESTART_LAYER
	_restart_layer.visible = false
	add_child(_restart_layer)

	var root:= Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_layer.add_child(root)


	var dim:= ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.025, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	var panel:= PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.98)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.border_color = Color(COL_ACCENT, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 24
	sb.content_margin_left = 44.0
	sb.content_margin_right = 44.0
	sb.content_margin_top = 34.0
	sb.content_margin_bottom = 32.0
	panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(panel)

	var content:= VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)


	_restart_title = _label("", 30, COL_ACCENT, true)
	_restart_title.add_theme_font_override("font", UiFont.every_script(true))
	_restart_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_restart_title)

	_restart_body = _wrapped("", 19, COL_TEXT)
	_restart_body.add_theme_font_override("font", UiFont.every_script())
	_restart_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_restart_body)


	_restart_alt = _wrapped("", 15, COL_DIM)
	_restart_alt.add_theme_font_override("font", UiFont.every_script())
	_restart_alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_restart_alt.visible = false
	content.add_child(_restart_alt)

	var actions:= HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)

	_restart_later = _notice_button(COL_STOP, ICON_LATER)
	_restart_later.pressed.connect(_hide_restart_notice)
	actions.add_child(_restart_later)

	_restart_quit = _notice_button(COL_GO, ICON_QUIT)
	_restart_quit.pressed.connect(_on_restart_quit)
	actions.add_child(_restart_quit)


func _notice_button(fill: Color, icon: Texture2D) -> Button:
	var b:= Button.new()
	b.icon = icon
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(220, 56)
	b.add_theme_font_override("font", UiFont.every_script(true))
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_constant_override("icon_max_width", 26)
	b.add_theme_constant_override("h_separation", 12)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "icon_normal_color", "icon_hover_color",
			"icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(colour, Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var lit:= state == "hover" or state == "pressed"
		var style:= StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.14) if lit else fill
		style.border_color = Color.WHITE if lit else fill.lightened(0.28)
		style.set_corner_radius_all(0)
		style.set_border_width_all(2)
		style.content_margin_left = 18.0
		style.content_margin_right = 18.0
		b.add_theme_stylebox_override(state, style)
	return b


func _on_sensitivity(v: float) -> void:
	Cfg.set_mouse_sensitivity(v)


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_end_capture()


		_hide_restart_notice(true)
	elif TABS [_tab] == "GAMEPLAY":
		_refresh_gameplay_notes()


func _begin_capture(row: String) -> void:
	_end_capture()
	_capturing = row
	_bind_buttons [row].text = tr("PRESS...")
	_say(tr("Press a key or a mouse button.  Escape cancels, Backspace clears."), COL_ACCENT)
	set_process_input(true)


func _end_capture() -> void:
	if _capturing == "":
		return
	_capturing = ""
	set_process_input(false)
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if is_restart_notice_open():


		if event.is_action_pressed("free_mouse"):
			_hide_restart_notice()
			get_viewport().set_input_as_handled()
		return
	if _capturing == "":
		return
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()

	if event is InputEventKey:
		var key:= event as InputEventKey
		if not key.pressed or key.echo:
			return
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		match code:
			KEY_ESCAPE:
				_end_capture()
				_say(tr("Left as it was."), COL_DIM)
			KEY_BACKSPACE, KEY_DELETE:
				_assign("")
			_:
				_assign(InputSetup.spec_from_event(key))
		return

	if event is InputEventMouseButton:
		var mb:= event as InputEventMouseButton
		if mb.pressed:
			_assign(InputSetup.spec_from_event(mb))


func _assign(spec: String) -> void:
	var row:= _capturing
	var title:= InputSetup.row_label(row)
	_end_capture()
	if row == "":
		return
	if spec == "":
		InputSetup.clear(row)
		_say(tr("%s is now unbound.") % title, COL_ACCENT)
		return


	if spec in InputSetup.specs(row):
		_say(tr("%s was already %s.") % [title, InputSetup.spec_label(spec)], COL_DIM)
		return
	var taken:= InputSetup.bind(row, spec)
	if taken.is_empty():
		_say(tr("%s is now %s.") % [title, InputSetup.spec_label(spec)], COL_DIM)
	else:


		_say(tr("%s is now %s, taken from %s.")
			% [title, InputSetup.spec_label(spec), ", ".join(taken)], COL_ACCENT)


func _refresh_bindings() -> void:
	for row: String in _bind_buttons:
		var b: Button = _bind_buttons [row]
		if is_instance_valid(b):
			b.text = tr("PRESS...") if row == _capturing else InputSetup.label(row)


func _say(text: String, colour: Color) -> void:
	if _bind_note == null or not is_instance_valid(_bind_note):
		return
	_bind_note.text = text
	_bind_note.add_theme_color_override("font_color", colour)


func _fmt_multiplier(v: float) -> String:
	return "%.2fx" % v


func _fmt_pct(v: float) -> String:
	return Cfg.percent(str(int(round(v * 100.0))))


func _fmt_amount(v: float) -> String:
	return "%.2f" % v


func _fmt_degrees(v: float) -> String:
	return "%.1f°" % v


func _fmt_count(v: float) -> String:
	return "%d" % int(round(v))


func _fmt_wait(v: float) -> String:
	var s:= int(round(v))
	if s < 60:
		return tr("%d s") % s
	if s % 60 == 0:
		return tr("%d min") % (s / 60)
	return tr("%d min %d s") % [s / 60, s % 60]
