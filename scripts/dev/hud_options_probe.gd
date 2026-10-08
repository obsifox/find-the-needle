class_name DevHudOptionsProbe
extends Node


var _fails:= 0
var _saved:= ""
var _had_file:= false
var _saved_audio:= ""
var _had_audio:= false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("--- hud options probe ---")
	_borrow_settings()

	_check_lists()
	_check_setters_clamp()
	_check_file()
	_check_nonsense_file()
	await _check_scale()
	await _check_pieces()
	await _check_hide_key()
	_check_page()
	_check_restart_notice()
	_check_resets()

	_give_settings_back()
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_lists() -> void:
	_ok(Cfg.CROSSHAIR_COLOUR_NAMES.size() == Cfg.CROSSHAIR_COLOURS.size(),
		"every crosshair colour on offer has a colour behind it")
	_ok(Cfg.CROSSHAIR_STYLE_NAMES.size() == 4,
		"the four crosshair shapes are all named")
	_ok(Cfg.CROSSHAIR_STYLE_NAMES [Cfg.CROSSHAIR_OFF] == "Off",
		"the last shape is the one that draws nothing")
	_ok(Cfg.CROSSHAIR_COLOURS [Cfg.CROSSHAIR_BLACK].v < 0.2,
		"the colour the HUD treats as black is in fact the dark one")
	_ok(Cfg.SHADOW_QUALITY_NAMES.size() == Cfg.SHADOW_ATLAS_SIZES.size()
		and Cfg.SHADOW_QUALITY_NAMES.size() == Cfg.SHADOW_FILTER_QUALITIES.size(),
		"every shadow quality has an atlas and a filter behind it")


func _check_setters_clamp() -> void:
	Cfg.set_gfx("machine_distance", 99)
	_ok(Cfg.machine_distance_metres() == 0.0, "a distance index above the list is clamped to Unlimited")
	Cfg.set_gfx("machine_distance", -5)
	_ok(Cfg.machine_distance_metres() == 40.0, "a negative distance index is clamped to the nearest choice")
	Cfg.set_hud_scale(99.0)
	_ok(Cfg.hud_scale == Cfg.HUD_SCALE_MAX, "HUD scale stops at the top of its range")
	Cfg.set_hud_scale(-5.0)
	_ok(Cfg.hud_scale == Cfg.HUD_SCALE_MIN, "...and at the bottom")

	Cfg.set_crosshair_opacity(0.0)
	_ok(Cfg.crosshair_opacity == Cfg.CROSSHAIR_OPACITY_MIN,
		"the crosshair cannot be faded to nothing")
	Cfg.set_crosshair_size(99.0)
	_ok(Cfg.crosshair_size == Cfg.CROSSHAIR_SIZE_MAX, "the crosshair has a top size")
	Cfg.set_crosshair_style(50)
	_ok(Cfg.crosshair_style == Cfg.CROSSHAIR_STYLE_NAMES.size() - 1,
		"the shape cannot be set off the end of the list")
	Cfg.set_crosshair_colour(50)
	_ok(Cfg.crosshair_colour == Cfg.CROSSHAIR_COLOURS.size() - 1,
		"...nor the colour")


	Cfg.set_crosshair_colour(0)
	Cfg.set_crosshair_opacity(0.5)
	_ok(is_equal_approx(Cfg.crosshair_tint().a, 0.5),
		"the tint carries the opacity for both halves of the mark")


func _check_file() -> void:
	Cfg.set_hud_scale(1.45)
	Cfg.set_crosshair_style(Cfg.CROSSHAIR_CROSS)
	Cfg.set_crosshair_size(2.25)
	Cfg.set_crosshair_opacity(0.65)
	Cfg.set_crosshair_colour(2)
	Cfg.set_show_hotkey_bar(false)
	Cfg.set_show_control_hints(false)
	var shadow_quality:= (int(Cfg.gfx ["shadow_quality"]) + 1) % Cfg.SHADOW_QUALITY_NAMES.size()
	Cfg.set_gfx("shadow_quality", shadow_quality)
	Cfg.set_gfx("machine_distance", 1)

	var cf:= ConfigFile.new()
	_ok(cf.load(Cfg.SETTINGS_PATH) == OK, "the settings file is written")
	_ok(is_equal_approx(float(cf.get_value("hud", "hud_scale", 0.0)), 1.45),
		"...with the HUD scale in it")
	_ok(int(cf.get_value("graphics", "shadow_quality", -1)) == shadow_quality,
		"...and the chosen shadow quality")
	_ok(int(cf.get_value("graphics", "machine_distance", -1)) == 1,
		"...and the chosen machine render distance")


	Cfg.hud_scale = 1.0
	Cfg.crosshair_style = Cfg.CROSSHAIR_RING
	Cfg.show_hotkey_bar = true
	Cfg.load_settings()
	_ok(int(Cfg._gfx_file.get("machine_distance", -1)) == 1,
		"the machine distance override returns through the settings loader")
	_ok(is_equal_approx(Cfg.hud_scale, 1.45), "...and it comes back on the next load")
	_ok(Cfg.crosshair_style == Cfg.CROSSHAIR_CROSS, "...so does the shape")
	_ok(is_equal_approx(Cfg.crosshair_size, 2.25), "...the size")
	_ok(is_equal_approx(Cfg.crosshair_opacity, 0.65), "...the opacity")
	_ok(Cfg.crosshair_colour == 2, "...the colour")
	_ok(not Cfg.show_hotkey_bar, "...and the two pieces that were put away")
	_ok(not Cfg.show_control_hints, "...both of them")


func _check_nonsense_file() -> void:
	var cf:= ConfigFile.new()
	cf.load(Cfg.SETTINGS_PATH)
	cf.set_value("hud", "hud_scale", 0.001)
	cf.set_value("hud", "crosshair_style", 99)
	cf.set_value("hud", "crosshair_colour", -3)
	cf.set_value("hud", "crosshair_opacity", 0.0)
	cf.save(Cfg.SETTINGS_PATH)
	Cfg.load_settings()
	_ok(Cfg.hud_scale >= Cfg.HUD_SCALE_MIN, "a nonsense scale in the file is floored")
	_ok(Cfg.crosshair_style < Cfg.CROSSHAIR_STYLE_NAMES.size(),
		"a shape index off the end of the file is clamped to one that exists")
	_ok(Cfg.crosshair_colour >= 0, "so is a negative colour")
	_ok(Cfg.crosshair_opacity >= Cfg.CROSSHAIR_OPACITY_MIN,
		"and a zeroed opacity comes back at something visible")


func _check_scale() -> void:
	var hud:= await _hud()
	var view:= hud.get_viewport_rect().size
	for want: float in [1.0, Cfg.HUD_SCALE_MIN, Cfg.HUD_SCALE_MAX, 1.25]:
		Cfg.set_hud_scale(want)
		await get_tree().process_frame
		var covered:= hud.size * hud.scale
		_ok(is_equal_approx(hud.scale.x, want) and is_equal_approx(hud.scale.y, want),
			"at %.2fx the HUD is scaled by that much" % want)
		_ok(covered.is_equal_approx(view),
			"...and still covers the window (%d x %d)" % [covered.x, covered.y])


		_ok(hud.position.is_zero_approx(), "...from the top left corner")
	hud.get_parent().queue_free()


func _check_pieces() -> void:
	var hud:= await _hud()
	var bar:= hud.get_node_or_null("HotkeyBar") as Control
	var hints:= hud.get_node_or_null("ControlHints") as Control
	_ok(bar != null and hints != null, "the HUD has a tool bar and a hint row to hide")
	if bar == null or hints == null:
		hud.get_parent().queue_free()
		return

	Cfg.set_no_hud(false)
	Cfg.set_show_hotkey_bar(true)
	Cfg.set_show_control_hints(true)
	_ok(bar.visible and hints.visible, "both are up with everything switched on")

	Cfg.set_show_hotkey_bar(false)
	_ok(not bar.visible, "the tool bar goes when its switch does")
	_ok(hints.visible, "...and leaves the hints where they were")

	Cfg.set_show_hotkey_bar(true)
	Cfg.set_no_hud(true)
	_ok(not bar.visible and not hints.visible, "camera mode puts both away regardless")
	Cfg.set_no_hud(false)
	_ok(bar.visible and hints.visible, "...and they come back when it ends")
	hud.get_parent().queue_free()


func _check_hide_key() -> void:
	var hud:= await _hud()
	Cfg.set_no_hud(false)

	_press_hide(hud)
	_ok(Cfg.no_hud, "the hide key switches camera mode on")
	var said:= hud.hud_notice_text()
	_ok(said.contains(InputSetup.hint("toggle_hud")),
		"...and names the key that brings it back (%s)" % said)

	_press_hide(hud)
	_ok(not Cfg.no_hud, "and pressing it again brings the HUD back")
	_ok(hud.hud_notice_text() != "", "...saying so on the way back too")

	Cfg.set_no_hud(false)
	hud.get_parent().queue_free()


func _press_hide(hud: Hud) -> void:
	var ev:= InputSetup.event_from_spec(InputSetup.spec_of("toggle_hud"))
	if ev == null:
		_ok(false, "the hide key is bound to something")
		return
	ev.set("pressed", true)
	hud._unhandled_input(ev)


func _hud() -> Hud:
	var layer:= CanvasLayer.new()
	var hud:= Hud.new()
	hud.name = "HUD"
	layer.add_child(hud)
	add_child(layer)
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	return hud


func _check_page() -> void:
	Cfg.set_hud_scale(1.45)
	Cfg.set_crosshair_size(2.25)
	Cfg.set_crosshair_colour(3)
	Cfg.set_crosshair_style(Cfg.CROSSHAIR_DOT)

	var page:= OptionsPanel.new()

	add_child(page)
	_ok(_says(page, "HUD"), "there is a HUD tab to click")
	_ok(_says(page, tr("Machine render distance")), "Graphics offers a machine render distance control")
	_ok(_says(page, "1.45x"), "the page shows the HUD scale in force")
	_ok(_says(page, "2.25x"), "...and the crosshair size")
	_ok(_says(page, Cfg.CROSSHAIR_COLOUR_NAMES [3]), "...and the colour by name")
	_ok(_says(page, Cfg.CROSSHAIR_STYLE_NAMES [Cfg.CROSSHAIR_DOT]),
		"...and the shape by name")
	_ok(_says(page, "BIGGEST FPS GAINS"),
		"the graphics page puts its strongest performance controls first")
	_ok(_says(page, "Lower or disable these first when the pile slows down."),
		"the performance group tells the player what to adjust")
	_ok(_says(page, "Shadow quality"),
		"the graphics page offers a shadow quality dropdown")
	_ok(_says(page, "Shadow blur"),
		"the graphics page offers independent shadow blur")


	var heights:= _page_heights(page)
	var i:= OptionsPanel.TABS.find("HUD")
	if heights.size() == OptionsPanel.TABS.size():
		_ok(heights [i] <= PauseMenu.OPTIONS_MAX_H,
			"the HUD page (%d px) fits the pause card (%d px) without scrolling"
			% [int(heights [i]), int(PauseMenu.OPTIONS_MAX_H)])
	else:
		_ok(false, "the pages could be measured")
	page.queue_free()


func _check_restart_notice() -> void:
	var page:= OptionsPanel.new()
	var quits:= [0]
	page.quit_action = func() -> void: quits [0] += 1
	page.quit_saves = true
	add_child(page)

	var was:= Cfg.renderer
	var running:= Cfg.running_renderer()
	var other:= ""
	for r: String in Cfg.RENDERERS:
		if r != running:
			other = r
			break

	Cfg.renderer = running
	page._after_renderer_pick()
	_ok(not page.is_restart_notice_open(),
		"picking the renderer already running asks for no restart")

	Cfg.renderer = other
	page._after_renderer_pick()
	_ok(page.is_restart_notice_open(), "picking another renderer puts up the restart notice")
	_ok(_button(page, "SAVE AND QUIT") != null, "...with a SAVE AND QUIT button during a run")

	var esc:= InputEventAction.new()
	esc.action = "free_mouse"
	esc.pressed = true
	page._input(esc)
	_ok(not page.is_restart_notice_open(), "Escape closes it")

	page._after_renderer_pick()
	var quit:= _button(page, "SAVE AND QUIT")
	if quit != null:
		quit.pressed.emit()
	_ok(quits [0] == 1, "SAVE AND QUIT calls the host's quit once")
	_ok(not page.is_restart_notice_open(), "...and takes the notice down")

	page.quit_saves = false
	page._after_renderer_pick()
	_ok(_button(page, "QUIT GAME") != null and _button(page, "SAVE AND QUIT") == null,
		"on the title screen the button is a plain QUIT GAME")
	var later:= _button(page, "LATER")
	if later != null:
		later.pressed.emit()
	_ok(not page.is_restart_notice_open(), "LATER closes it without quitting")
	_ok(quits [0] == 1, "...and the host's quit was not called again")

	Cfg.renderer = was
	page.queue_free()


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).visible:
		return node as Button
	for child: Node in node.get_children():
		var found:= _button(child, text)
		if found != null:
			return found
	return null


func _page_heights(page: OptionsPanel) -> Array [float]:
	var out: Array [float] = []
	for child: Node in page.get_children():
		if child.get_child_count() != OptionsPanel.TABS.size():
			continue
		if child.get_child(0) is Button:
			continue
		for p: Node in child.get_children():
			out.append((p as Control).get_combined_minimum_size().y)
		break
	return out


func _says(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	if node is Button and (node as Button).text == text:
		return true
	for child: Node in node.get_children():
		if _says(child, text):
			return true
	return false


func _check_resets() -> void:
	var page:= OptionsPanel.new()
	add_child(page)


	var buttons:= 0
	for name: String in ["RESET TO DEFAULTS", "RESET TO PRESET"]:
		buttons += _counts(page, name)
	_ok(buttons == OptionsPanel.TABS.size(),
		"every one of the %d pages carries a reset button (%d found)"
		% [OptionsPanel.TABS.size(), buttons])


	Cfg.set_hud_scale(1.45)
	Audio.volume ["music"] = 0.02


	_reset_buttons(page) [0].pressed.emit()
	_ok(is_equal_approx(Audio.volume ["music"], float(Audio.VOLUME_DEFAULT ["music"])),
		"pressing the AUDIO page's button puts the mix back")
	_ok(is_equal_approx(Cfg.hud_scale, 1.45), "...without touching the HUD page")


	_ok(_reset_buttons(page).size() == OptionsPanel.TABS.size(),
		"...and the rebuilt panel still has all %d of them" % OptionsPanel.TABS.size())
	page.queue_free()

	Audio.volume ["music"] = 0.02
	Cfg.set_hud_scale(1.45)
	Audio.reset_volumes()
	_ok(is_equal_approx(Audio.volume ["music"], float(Audio.VOLUME_DEFAULT ["music"])),
		"the audio reset puts the mix back")
	_ok(is_equal_approx(Cfg.hud_scale, 1.45), "...and leaves the HUD page alone")

	Cfg.set_mouse_sensitivity(2.5)
	Cfg.set_tool_mode(Cfg.TOOL_ADVANCED)
	Cfg.reset_controls()
	_ok(is_equal_approx(Cfg.mouse_sensitivity, Cfg.MOUSE_SENS_DEFAULT),
		"the controls reset puts the look speed back")
	_ok(Cfg.tool_mode == Cfg.TOOL_SIMPLE, "...and the tool handling")
	_ok(is_equal_approx(Cfg.hud_scale, 1.45), "...and still leaves the HUD page alone")

	Cfg.set_vsync(false)
	Cfg.set_smooth_camera(true)
	Cfg.set_prop_cap(Cfg.PROP_CAP_MAX)
	Cfg.reset_display()
	_ok(Cfg.vsync == Cfg.VSYNC_DEFAULT, "the display reset puts V-Sync back")
	_ok(Cfg.smooth_camera == Cfg.SMOOTH_CAMERA_DEFAULT, "...and the camera mode")
	_ok(Cfg.quality == Cfg.QUALITY_DEFAULT, "...and the quality preset")
	_ok(Cfg.prop_cap == Cfg.PROP_CAP_MAX, "...and leaves the yard cap where it was")

	Cfg.set_crosshair_style(Cfg.CROSSHAIR_OFF)
	Cfg.set_crosshair_colour(Cfg.CROSSHAIR_BLACK)
	Cfg.set_show_hotkey_bar(false)
	Cfg.reset_hud()
	_ok(is_equal_approx(Cfg.hud_scale, Cfg.HUD_SCALE_DEFAULT),
		"the HUD reset puts the scale back")
	_ok(Cfg.crosshair_style == Cfg.CROSSHAIR_STYLE_DEFAULT, "...and the crosshair shape")
	_ok(Cfg.crosshair_colour == Cfg.CROSSHAIR_WHITE, "...and its colour")
	_ok(Cfg.show_hotkey_bar, "...and the tool bar")
	_ok(Cfg.prop_cap == Cfg.PROP_CAP_MAX, "...and still leaves the yard cap alone")

	Cfg.set_prop_decay(false)
	Cfg.set_show_missions(false)
	Cfg.reset_gameplay()


	_ok(Cfg.prop_cap == Cfg.authored_prop_cap(), "the gameplay reset puts the yard cap back")
	_ok(Cfg.prop_decay == Cfg.PROP_DECAY_DEFAULT, "...and turns the drain back on")
	_ok(Cfg.show_missions, "...and the mission card back on")


func _reset_buttons(node: Node) -> Array [Button]:
	var out: Array [Button] = []
	if node is Button and str((node as Button).text).begins_with("RESET TO "):
		out.append(node as Button)
	for child: Node in node.get_children():
		out.append_array(_reset_buttons(child))
	return out


func _counts(node: Node, text: String) -> int:
	var n:= 0
	if node is Button and (node as Button).text == text:
		n += 1
	for child: Node in node.get_children():
		n += _counts(child, text)
	return n


func _borrow_settings() -> void:
	_had_file = FileAccess.file_exists(Cfg.SETTINGS_PATH)
	if _had_file:
		_saved = FileAccess.get_file_as_string(Cfg.SETTINGS_PATH)

	_had_audio = FileAccess.file_exists(Audio.SETTINGS_PATH)
	if _had_audio:
		_saved_audio = FileAccess.get_file_as_string(Audio.SETTINGS_PATH)


func _give_settings_back() -> void:
	if _had_file:
		var f:= FileAccess.open(Cfg.SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_saved)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cfg.SETTINGS_PATH))
	if _had_audio:
		var af:= FileAccess.open(Audio.SETTINGS_PATH, FileAccess.WRITE)
		if af != null:
			af.store_string(_saved_audio)
			af.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Audio.SETTINGS_PATH))
	Cfg.load_settings()
	Audio.load_settings()


	Cfg.hud_style_changed.emit()
