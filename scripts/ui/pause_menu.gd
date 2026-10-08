class_name PauseMenu
extends Control


const OPTIONS_MAX_H:= 460.0


const OPTIONS_SCREEN_RESERVE:= 340.0

const MENU_SCENE:= "res://scenes/main_menu.tscn"


const WORLD_PATH:= "res://scripts/world/world.gd"
const YOUTUBE_URL:= "https://www.youtube.com/@FindTheNeedleDev"
const X_URL:= "https://x.com/haydeveloper"
const DISCORD_URL:= "https://discord.gg/MqcvCz8eyG"


const STEAM_URL:= "https://store.steampowered.com/app/5160800/Find_The_Needle/"

const COL_STEAM:= Color(0.16, 0.42, 0.66)


const COL_TITLE:= OptionsPanel.COL_ACCENT
const COL_TEXT:= Color(0.95, 0.96, 0.99)
const COL_DIM:= Color(0.7, 0.73, 0.79)
const COL_OFF:= Color(0.44, 0.46, 0.5)

const PANEL_W:= 560.0

var player: Player
var shop: ShopMenu
var map: MapMenu
var catalog: CatalogPanel
var tech_panel: TechPanel
var debug_menu: DebugMenu
var hud: Hud

var intro: IntroSequence


var save_action: Callable

var _open:= false
var _title: Label


var _slot_btn: Button


var _slot_edit: LineEdit
var _status: Label
var _menu_page: VBoxContainer
var _options_page: VBoxContainer

var _wishlist_page: VBoxContainer

var _quick_load_page: VBoxContainer
var _quick_load_text: Label
var _leaving:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_open() -> bool:
	return _open


func set_open(on: bool) -> void:
	if on == _open or _leaving:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if on:
		_status.text = ""
		_refresh_slot_line()
		_show_page(_menu_page)
	else:
		_close_editor()
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("free_mouse"):
		return


	if catalog != null and catalog.gift_card != null and catalog.gift_card.is_holding():
		return
	if _open:


		if _slot_edit.visible:
			_close_editor()
			_status.text = ""
			Audio.play("ui_close", -4.0)
			get_viewport().set_input_as_handled()
			return


		if not _menu_page.visible:
			_show_page(_menu_page)
		else:
			set_open(false)
		get_viewport().set_input_as_handled()
		return


	if intro != null and intro.is_running():
		return
	if shop != null and shop.is_open():
		return
	if map != null and map.is_open():
		return
	if catalog != null and catalog.is_open():
		return
	if tech_panel != null and tech_panel.is_open():
		return
	if debug_menu != null and debug_menu.is_open():
		return


	if player != null and player.escape_is_taken():
		return
	set_open(true)
	get_viewport().set_input_as_handled()


func _build() -> void:
	var dim:= ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel:= PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	sb.border_color = Color(COL_TITLE, 0.62)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	_title = _label(tr("MENU"), 34, COL_TITLE, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)


	_slot_btn = _slot_button()
	box.add_child(_slot_btn)

	_slot_edit = _name_edit()
	box.add_child(_slot_edit)

	_status = _label("", 16, COL_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


	_status.custom_minimum_size = Vector2(0, 22)
	box.add_child(_status)

	var gap:= Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap)

	_menu_page = VBoxContainer.new()
	_menu_page.add_theme_constant_override("separation", 2)
	box.add_child(_menu_page)
	_menu_page.add_child(_entry(tr("RESUME"), _on_resume))
	_menu_page.add_child(_entry(tr("OPTIONS"), _on_options))
	_menu_page.add_child(_entry(tr("SAVE"), _on_save))


	_menu_page.add_child(_entry(tr("QUICK LOAD"), _on_quick_load_pressed))
	_menu_page.add_child(_entry(tr("SAVE AND EXIT TO TITLE"), _on_exit_to_title))
	_menu_page.add_child(_entry(tr("SAVE AND QUIT"), _on_quit_pressed))


	_menu_page.add_child(_entry(tr("RESPAWN"), _on_respawn))

	var social_gap:= Control.new()
	social_gap.custom_minimum_size = Vector2(0, 12)
	_menu_page.add_child(social_gap)

	var social_heading:= _label(tr("OFFICIAL LINKS"), 18, COL_TITLE, true)
	social_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_page.add_child(social_heading)
	_menu_page.add_child(_social_button(
		"@FindTheNeedleDev  Youtube", Color(0.9, 0.12, 0.12), _open_social.bind(YOUTUBE_URL)))
	_menu_page.add_child(_social_button(
		"X  /  @haydeveloper", Color(0.22, 0.24, 0.28), _open_social.bind(X_URL)))
	_menu_page.add_child(_social_button(
		tr("DISCORD COMMUNITY"), Color(0.35, 0.4, 0.95), _open_social.bind(DISCORD_URL)))


	_wishlist_page = VBoxContainer.new()
	_wishlist_page.add_theme_constant_override("separation", 6)
	_wishlist_page.visible = false
	box.add_child(_wishlist_page)
	var ask:= _label(tr("Did you like it? Put Find The Needle on your Steam wishlist. It helps us a lot, and Steam will tell you when the game comes out."), 20, COL_TEXT)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wishlist_page.add_child(ask)
	var ask_gap:= Control.new()
	ask_gap.custom_minimum_size = Vector2(0, 12)
	_wishlist_page.add_child(ask_gap)
	_wishlist_page.add_child(_social_button(tr("WISHLIST ON STEAM"), COL_STEAM, _on_wishlist))


	var discord:= _social_button(tr("DISCORD COMMUNITY"), Color(0.35, 0.4, 0.95), _open_social.bind(DISCORD_URL))
	discord.custom_minimum_size = Vector2(280.0, 44.0)
	discord.add_theme_font_size_override("font_size", 17)
	_wishlist_page.add_child(discord)
	var quit_gap:= Control.new()
	quit_gap.custom_minimum_size = Vector2(0, 12)
	_wishlist_page.add_child(quit_gap)
	_wishlist_page.add_child(_entry(tr("SAVE AND QUIT"), _on_quit))
	_wishlist_page.add_child(_entry(tr("CANCEL"), _on_options_back))

	_quick_load_page = VBoxContainer.new()
	_quick_load_page.add_theme_constant_override("separation", 6)
	_quick_load_page.visible = false
	box.add_child(_quick_load_page)
	_quick_load_text = _label("", 20, COL_TEXT)
	_quick_load_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quick_load_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_load_page.add_child(_quick_load_text)
	var load_gap:= Control.new()
	load_gap.custom_minimum_size = Vector2(0, 12)
	_quick_load_page.add_child(load_gap)
	_quick_load_page.add_child(_entry(tr("LOAD"), _on_quick_load))
	_quick_load_page.add_child(_entry(tr("CANCEL"), _on_options_back))

	_options_page = VBoxContainer.new()
	_options_page.add_theme_constant_override("separation", 6)
	_options_page.visible = false
	box.add_child(_options_page)


	var scroll:= ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_options_page.add_child(scroll)


	var options:= OptionsPanel.new()


	options.quit_action = _on_quit
	options.quit_saves = true
	scroll.add_child(options)
	options.fit_into(scroll, OPTIONS_MAX_H, OPTIONS_SCREEN_RESERVE)
	_options_page.add_child(_entry(tr("BACK"), _on_options_back))


func _show_page(page: Control) -> void:


	_close_editor()
	_menu_page.visible = page == _menu_page
	_options_page.visible = page == _options_page
	_wishlist_page.visible = page == _wishlist_page
	_quick_load_page.visible = page == _quick_load_page
	if page == _wishlist_page:
		_title.text = tr("THANKS FOR PLAYING")
	elif page == _quick_load_page:
		_title.text = tr("QUICK LOAD")
	else:
		_title.text = tr("MENU")


func _on_resume() -> void:
	set_open(false)


func _on_respawn() -> void:
	if player == null:
		return
	player.respawn(true)
	Audio.play("ui_select", -4.0)
	set_open(false)


func _refresh_slot_line() -> void:
	var slot:= tr("Slot %d") % (SaveManager.current_slot + 1)
	var given:= SaveManager.current_name
	_slot_btn.text = "%s (%s)" % [given, slot] if given != "" else slot


func _on_slot_pressed() -> void:
	if _leaving:
		return


	if SaveManager.is_locked():
		_status.text = tr("This run is locked. Unlock it on the title screen")
		Audio.play("ui_error")
		return
	_slot_btn.visible = false
	_slot_edit.visible = true
	_slot_edit.text = SaveManager.current_name
	_slot_edit.grab_focus()
	_slot_edit.select_all()
	_status.text = tr("Enter to save this name, Esc to leave it alone")
	Audio.play("ui_open", -4.0)


func _on_name_submitted(text: String) -> void:
	var slot:= SaveManager.current_slot
	var named:= false
	if SaveManager.has_save(slot):
		named = SaveManager.rename_save(slot, text)
	else:


		SaveManager.current_name = SaveManager.clean_name(text)
		named = true
	_close_editor()
	_refresh_slot_line()
	if named:
		_status.text = ""
		Audio.play("ui_select")
	else:
		_status.text = tr("Could not write the save")
		Audio.play("ui_error")


func _close_editor() -> void:
	if not _slot_edit.visible:
		return
	_slot_edit.release_focus()
	_slot_edit.visible = false
	_slot_btn.visible = true


func _on_options() -> void:
	Audio.play("ui_open", -4.0)
	_show_page(_options_page)


func _on_options_back() -> void:
	Audio.play("ui_back", -4.0)
	_show_page(_menu_page)


func _on_save() -> void:
	if _save():
		_status.text = tr("Saved to slot %d") % (SaveManager.current_slot + 1)
		Audio.play("ui_select")
	else:
		_status.text = tr("Could not write the save")
		Audio.play("ui_error")


func _on_quick_load_pressed() -> void:
	if _leaving:
		return
	var path:= SaveManager.slot_path(SaveManager.current_slot)
	if not FileAccess.file_exists(path):
		_status.text = tr("There is no save to load yet")
		Audio.play("ui_error")
		return
	var age:= int(Time.get_unix_time_from_system()) - int(FileAccess.get_modified_time(path))
	var when: String
	if age < 5:
		when = tr("This loads your last save, made just now.")
	else:
		when = tr("This loads your last save, made %s ago.") % _age_text(age)
	var minutes:= int(float(load(WORLD_PATH).AUTOSAVE_SECONDS) / 60.0)
	_quick_load_text.text = "%s %s\n\n%s" % [when,
		tr("Everything you did after that is lost."),
		tr_n("The game saves by itself every minute, and when you press SAVE.",
			"The game saves by itself every %d minutes, and when you press SAVE.",
			minutes) % minutes]
	Audio.play("ui_open", -4.0)
	_show_page(_quick_load_page)


func _age_text(age: int) -> String:
	if age < 120:
		return tr_n("%d second", "%d seconds", age) % age
	if age < 7200:
		return tr_n("%d minute", "%d minutes", age / 60) % (age / 60)
	return tr_n("%d hour", "%d hours", age / 3600) % (age / 3600)


func _on_quick_load() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.play("ui_select")
	get_tree().reload_current_scene()


func _on_exit_to_title() -> void:
	if _leaving:
		return
	_save()
	_leaving = true
	Audio.play("ui_back")


	Loading.show_screen("FIND THE NEEDLE", tr("RETURNING TO THE YARD"))

	get_tree().change_scene_to_file(MENU_SCENE)


func _on_quit_pressed() -> void:
	if _leaving:
		return
	Audio.play("ui_open", -4.0)
	_show_page(_wishlist_page)


func _on_wishlist() -> void:
	if _leaving:
		return
	Audio.play("ui_select")
	if OS.shell_open(STEAM_URL) != OK:
		_status.text = tr("Please open this address in your browser: %s") % STEAM_URL
		Audio.play("ui_error")


func _on_quit() -> void:
	if _leaving:
		return
	_save()
	_leaving = true
	get_tree().quit()


func _open_social(url: String) -> void:
	Audio.play("ui_select")
	var error:= OS.shell_open(url)
	if error != OK:
		_status.text = tr("Please open this address in your browser: %s") % url
		Audio.play("ui_error")


func _save() -> bool:
	if not save_action.is_valid():
		return false
	return bool(save_action.call())


func _slot_button() -> Button:
	var b:= Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tr("Name this run")
	b.add_theme_font_override("font", UiFont.regular())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TITLE)
	b.add_theme_color_override("font_pressed_color", COL_TITLE)
	b.add_theme_stylebox_override("normal", _slot_style(false))
	b.add_theme_stylebox_override("hover", _slot_style(true))
	b.add_theme_stylebox_override("pressed", _slot_style(true))
	b.add_theme_stylebox_override("focus", _slot_style(false))
	b.pressed.connect(_on_slot_pressed)
	return b


func _slot_style(accent: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.14, 0.85 if accent else 0.0)
	sb.set_corner_radius_all(0)
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


func _name_edit() -> LineEdit:
	var e:= LineEdit.new()
	e.visible = false
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.max_length = SaveManager.NAME_MAX_LEN
	e.placeholder_text = tr("Name this run")
	e.add_theme_font_override("font", UiFont.regular())
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", COL_TEXT)
	e.add_theme_stylebox_override("normal", _name_style())
	e.add_theme_stylebox_override("focus", _name_style())
	e.text_submitted.connect(_on_name_submitted)


	e.focus_exited.connect(_close_editor)
	return e


func _name_style() -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_color = COL_TITLE
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


func _entry(text: String, on_press: Callable) -> Button:
	var b:= Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TITLE)
	b.add_theme_color_override("font_pressed_color", COL_TITLE)
	b.add_theme_color_override("font_disabled_color", COL_OFF)
	b.add_theme_stylebox_override("normal", _entry_style(false))
	b.add_theme_stylebox_override("hover", _entry_style(true))
	b.add_theme_stylebox_override("pressed", _entry_style(true))
	b.add_theme_stylebox_override("focus", _entry_style(false))
	b.pressed.connect(on_press)
	return b


func _entry_style(accent: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.14, 0.85 if accent else 0.0)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	if accent:
		sb.border_width_left = 4
		sb.border_color = COL_TITLE
	return sb


func _social_button(text: String, colour: Color, on_press: Callable) -> Button:
	var b:= Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(384.0, 62.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_stylebox_override("normal", _social_style(colour, false))
	b.add_theme_stylebox_override("hover", _social_style(colour, true))
	b.add_theme_stylebox_override("pressed", _social_style(colour, true))
	b.add_theme_stylebox_override("focus", _social_style(colour, false))
	b.pressed.connect(on_press)
	return b


func _social_style(colour: Color, accent: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = colour.lightened(0.1) if accent else colour.darkened(0.18)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.border_color = Color.WHITE if accent else colour.lightened(0.28)
	sb.shadow_color = Color(0, 0, 0, 0.48)
	sb.shadow_size = 8 if accent else 5
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(l, size, colour, 4, heavy)
	return l
