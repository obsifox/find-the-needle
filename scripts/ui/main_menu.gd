class_name MainMenu
extends Control


const GAME_SCENE:= "res://scenes/main.tscn"
const YOUTUBE_URL:= "https://www.youtube.com/@FindTheNeedleDev"
const X_URL:= "https://x.com/haydeveloper"
const DISCORD_URL:= "https://discord.gg/MqcvCz8eyG"

const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_TEXT:= Color(0.95, 0.96, 0.99)
const COL_DIM:= Color(0.7, 0.73, 0.79)
const COL_WARN:= Color(1.0, 0.6, 0.52)
const COL_OFF:= Color(0.44, 0.46, 0.5)

const MARGIN_L:= 76.0


const OPTIONS_MAX_H:= 470.0
const COLUMN_W:= 620.0


const SLOT_COLUMN_W:= 760.0
const SLOT_H:= 78.0


const SLOT_LIST_MAX_H:= 470.0


const ROW_PAD_TOP:= 10.0
const ROW_PAD_BOTTOM:= 34.0


const ROW_ACTION_W:= 104.0


const ROW_LOCK_W:= 96.0
const ROW_ACTION_GAP:= 16.0

const ROW_ACTION_EDGE:= 18.0


const CARD_W:= 372.0
const CARD_GAP:= 26.0


const CARD_ROWS:= 20


const ROW_STRIP_W:= [ROW_LOCK_W, ROW_ACTION_W, ROW_ACTION_W]
const STRIP_LOCK:= 0
const STRIP_ERASE:= 1
const STRIP_RENAME:= 2
const TITLE_BLUR_SHADER:= "\nshader_type canvas_item;\nrender_mode unshaded;\n\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;\n\nuniform float blur_radius = 0.7;\nuniform float blur_mix = 0.22;\n\nvoid fragment() {\n\tvec2 step_size = SCREEN_PIXEL_SIZE * blur_radius;\n\tvec4 center = textureLod(screen_texture, SCREEN_UV, 0.0);\n\tvec4 softened = center * 0.52;\n\tsoftened += textureLod(screen_texture, SCREEN_UV + vec2(step_size.x, 0.0), 0.0) * 0.08;\n\tsoftened += textureLod(screen_texture, SCREEN_UV - vec2(step_size.x, 0.0), 0.0) * 0.08;\n\tsoftened += textureLod(screen_texture, SCREEN_UV + vec2(0.0, step_size.y), 0.0) * 0.08;\n\tsoftened += textureLod(screen_texture, SCREEN_UV - vec2(0.0, step_size.y), 0.0) * 0.08;\n\tsoftened += textureLod(screen_texture, SCREEN_UV + step_size, 0.0) * 0.04;\n\tsoftened += textureLod(screen_texture, SCREEN_UV - step_size, 0.0) * 0.04;\n\tsoftened += textureLod(screen_texture, SCREEN_UV + vec2(step_size.x, -step_size.y), 0.0) * 0.04;\n\tsoftened += textureLod(screen_texture, SCREEN_UV + vec2(-step_size.x, step_size.y), 0.0) * 0.04;\n\tvec4 result = mix(center, softened, blur_mix);\n\tif (result.a > 0.0001) {\n\t\tresult.rgb /= result.a;\n\t}\n\tCOLOR *= result;\n}\n"


enum Page { ROOT, MAP_PICK, SIZE_PICK, NEW_GAME, LOAD_GAME, OPTIONS, LEADERBOARDS }


signal static_toggled(on: bool)

var _page: int = Page.ROOT
var _root_column: VBoxContainer
var _social_links: VBoxContainer
var _static_box: CheckBox
var _slot_column: VBoxContainer
var _map_column: VBoxContainer


var _chosen_map:= SaveManager.DEFAULT_MAP
var _size_column: VBoxContainer


var _chosen_size:= Cfg.DEFAULT_PILE_SIZE


var _size_expanded:= false
var _options_column: VBoxContainer


var _options_root: Control
var _leaderboard_root: Control
var _leaderboard_panel: LeaderboardPanel
var _slot_title: Label
var _slot_rows: Array [Button] = []
var _slot_detail: Array [Label] = []
var _slot_delete: Array [Button] = []
var _slot_rename: Array [Button] = []


var _slot_lock: Array [CheckBox] = []


var _slot_scroll: ScrollContainer


var _slot_list: VBoxContainer

var _slot_edit: Array [LineEdit] = []


var _slot_card: PanelContainer
var _card_title: Label
var _card_keys: Array [Label] = []
var _card_values: Array [Label] = []


var _card_slot:= -1


var _renaming:= -1
var _load_button: Button
var _modal: Control
var _modal_title: Label
var _modal_body: Label
var _modal_confirm: Button
var _modal_cancel: Button
var _modal_action: Callable
var _modal_cancel_action: Callable


var _modal_link: Button

var _modal_discord: Button
var _fade: ColorRect
var _leaving:= false
var _title_blur_material: ShaderMaterial


var _pending_overwrite:= -1


var _pending_delete:= -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_show_page(Page.ROOT)


	Audio.stop_world_sfx()

	Audio.ambience_start()
	Audio.set_indoor(0.85)
	Audio.music_start()
	if "--lbshot" in OS.get_cmdline_user_args():
		_shoot_leaderboards()
	if "--sizeshot" in OS.get_cmdline_user_args():
		_shoot_size_page()


func _shoot_leaderboards() -> void:


	print("[lbshot] the menu stayed up; no world, no slot loaded")
	var out:= "res://captures/leaderboard.png"
	var args:= OS.get_cmdline_user_args()
	var i:= args.find("--lbshot")
	if i >= 0 and i + 1 < args.size() and not args [i + 1].begins_with("--"):
		out = args [i + 1]
	_show_page(Page.LEADERBOARDS)

	if DisplayServer.get_name() == "headless":


		print("[lbshot] headless: nothing to draw, quitting")
		get_tree().quit()
		return


	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var img:= get_viewport().get_texture().get_image()
	img.save_png(out)
	print("[lbshot] wrote %s" % out)
	get_tree().quit()


func _shoot_size_page() -> void:
	print("[sizeshot] the menu stayed up; no world, no slot loaded")
	var out:= "res://captures/pile_sizes.png"
	var args:= OS.get_cmdline_user_args()
	var i:= args.find("--sizeshot")
	if i >= 0 and i + 1 < args.size() and not args [i + 1].begins_with("--"):
		out = args [i + 1]


	_size_expanded = true
	_fill_size_column()
	_show_page(Page.SIZE_PICK)


	_fade.color.a = 0.0

	if DisplayServer.get_name() == "headless":
		print("[sizeshot] headless: nothing to draw, quitting")


		for spec: Dictionary in Cfg.listed_pile_sizes():
			print("  %-14s%s %s" % [str(spec.get("name", "")),
				"  (behind the warning)" if spec.get("heavy", false) else "",
				_size_stats(spec)])
		get_tree().quit()
		return

	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var img:= get_viewport().get_texture().get_image()
	img.save_png(out)
	print("[sizeshot] wrote %s" % out)
	get_tree().quit()


func _build() -> void:
	_build_scrim()
	_build_title()


	var frame:= MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", int(MARGIN_L))


	frame.add_theme_constant_override("margin_top", 268)
	frame.add_theme_constant_override("margin_bottom", 48)
	add_child(frame)

	var column:= VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(column)

	var spacer:= Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL


	spacer.size_flags_stretch_ratio = 0.01
	column.add_child(spacer)

	_build_root_column(column)
	_build_map_column(column)
	_build_size_column(column)
	_build_slot_column(column)
	_build_slot_card()
	_build_options_column(column)
	_build_leaderboard_column()
	_build_social_links()
	_build_static_box()
	_build_footer()
	_build_modal()


	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.03, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)


func _build_scrim() -> void:
	var grad:= Gradient.new()
	grad.set_color(0, Color(0.02, 0.025, 0.035, 0.93))
	grad.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	grad.set_offset(1, 1.0)
	grad.add_point(0.46, Color(0.02, 0.025, 0.035, 0.68))
	var tex:= GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 8
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)

	var wash:= TextureRect.new()
	wash.texture = tex
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.anchor_right = 0.78


	wash.name = "Scrim"
	add_child(wash)


func _build_title() -> void:
	var box:= VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.position = Vector2(MARGIN_L, 60.0)
	box.custom_minimum_size = Vector2(COLUMN_W, 0)


	box.name = "TitleBlock"
	add_child(box)


	var name_box:= VBoxContainer.new()
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.add_theme_constant_override("separation", -8)
	name_box.custom_minimum_size = Vector2(COLUMN_W, 0)
	name_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(name_box)

	name_box.add_child(_title_line("FIND THE", 68))
	name_box.add_child(_title_line("NEEDLE", 104))


	if Cfg.DEMO:
		name_box.add_child(_title_line(tr("DEMO"), 56))


func _title_line(text: String, size: int) -> Control:
	var font:= UiFont.bold()
	var full_height:= ceilf(font.get_height(size))
	var outline_padding:= 10.0


	var holder:= Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(COLUMN_W, full_height)

	var group:= CanvasGroup.new()
	group.clear_margin = outline_padding
	group.fit_margin = outline_padding
	group.material = _get_title_blur_material()
	holder.add_child(group)

	var border_radius:= 4.0
	var border_colour:= Color(0.0, 0.0, 0.0, 0.92)
	for index in 16:
		var angle:= TAU * float(index) / 16.0
		var offset:= Vector2(cos(angle), sin(angle)) * border_radius
		group.add_child(_title_glyphs(
			text, size, border_colour, offset,
			Vector2(COLUMN_W, full_height + outline_padding)))

	group.add_child(_title_glyphs(
		text, size, COL_TEXT, Vector2.ZERO,
		Vector2(COLUMN_W, full_height + outline_padding)))
	return holder


func _title_glyphs(text: String, size: int, colour: Color,
		position: Vector2, bounds: Vector2) -> Label:
	var label:= _label(text, size, colour, true)


	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_constant_override("outline_size", 0)
	label.position = position
	label.size = bounds
	return label


func _get_title_blur_material() -> ShaderMaterial:
	if _title_blur_material == null:
		var shader:= Shader.new()
		shader.code = TITLE_BLUR_SHADER
		_title_blur_material = ShaderMaterial.new()
		_title_blur_material.shader = shader
	return _title_blur_material


func _build_root_column(parent: Control) -> void:
	_root_column = VBoxContainer.new()
	_root_column.add_theme_constant_override("separation", 4)
	_root_column.custom_minimum_size = Vector2(COLUMN_W, 0)
	_root_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(_root_column)

	_root_column.add_child(_entry(tr("NEW GAME"), _on_new_game))
	_load_button = _entry(tr("LOAD GAME"), _on_load_game)
	_root_column.add_child(_load_button)


	var multiplayer_button:= _entry(tr("MULTIPLAYER"), _on_multiplayer)
	multiplayer_button.visible = false
	_root_column.add_child(multiplayer_button)
	_root_column.add_child(_entry(tr("LEADERBOARDS"), _on_leaderboards))
	_root_column.add_child(_entry(tr("OPTIONS"), _on_options))
	_root_column.add_child(_entry(tr("QUIT"), _on_quit))


func _build_static_box() -> void:
	var c:= CheckBox.new()
	c.name = "StaticBackdrop"
	c.text = tr("STILL BACKGROUND")
	c.focus_mode = Control.FOCUS_NONE
	c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c.offset_right = -30.0
	c.offset_top = 24.0
	c.add_theme_font_override("font", UiFont.bold())
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_constant_override("h_separation", 6)
	c.add_theme_color_override("font_color", COL_DIM)
	c.add_theme_color_override("font_hover_color", COL_TITLE)
	c.add_theme_color_override("font_pressed_color", COL_TEXT)
	c.add_theme_color_override("font_hover_pressed_color", COL_TITLE)
	c.add_theme_icon_override("unchecked", _check_icon(false))
	c.add_theme_icon_override("checked", _check_icon(true))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color"]:
		c.add_theme_color_override(state, Color.WHITE)


	for state in ["normal", "pressed", "focus", "disabled"]:
		c.add_theme_stylebox_override(state, _static_box_style(false))
	for state in ["hover", "hover_pressed"]:
		c.add_theme_stylebox_override(state, _static_box_style(true))
	c.set_pressed_no_signal(Cfg.menu_backdrop_static())
	c.toggled.connect(_on_static_box)
	c.mouse_entered.connect(_on_hover.bind(c))
	add_child(c)
	_static_box = c


func _static_box_style(hover: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.86 if hover else 0.74)
	sb.set_border_width_all(1)
	sb.border_color = Color(COL_TITLE, 0.7) if hover else Color(1, 1, 1, 0.16)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	return sb


func _on_static_box(on: bool) -> void:
	Audio.play("ui_select")
	Cfg.menu_static = 1 if on else 0
	Cfg.save_settings()
	static_toggled.emit(on)


func _build_social_links() -> void:
	_social_links = VBoxContainer.new()
	_social_links.add_theme_constant_override("separation", 10)
	_social_links.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_social_links.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_social_links.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_social_links.offset_left = -444.0
	_social_links.offset_right = -60.0
	_social_links.offset_top = -310.0
	_social_links.offset_bottom = -62.0
	add_child(_social_links)

	var heading:= _label(tr("OFFICIAL LINKS"), 20, COL_TITLE, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_social_links.add_child(heading)
	_social_links.add_child(_social_button("@FindTheNeedleDev  Youtube", Color(0.9, 0.12, 0.12), _open_social.bind(YOUTUBE_URL)))
	_social_links.add_child(_social_button("X  /  @haydeveloper", Color(0.22, 0.24, 0.28), _open_social.bind(X_URL)))
	_social_links.add_child(_social_button(tr("DISCORD COMMUNITY"), Color(0.35, 0.4, 0.95), _open_social.bind(DISCORD_URL)))


func _build_modal() -> void:
	_modal = Control.new()
	_modal.name = "Notice"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)

	var dim:= ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.025, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)

	var panel:= PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -360.0
	panel.offset_right = 360.0
	panel.offset_top = -205.0
	panel.offset_bottom = 205.0
	panel.add_theme_stylebox_override("panel", _modal_style())
	_modal.add_child(panel)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var content:= VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)

	_modal_title = _label("", 34, COL_TITLE, true)
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_modal_title)

	_modal_body = _label("", 22, COL_TEXT)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_modal_body)

	_modal_link = _social_button(tr("WISHLIST ON STEAM"), PauseMenu.COL_STEAM, _on_modal_link)
	_modal_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_link.visible = false
	content.add_child(_modal_link)

	_modal_discord = _social_button(tr("DISCORD COMMUNITY"), Color(0.35, 0.4, 0.95), _open_social.bind(DISCORD_URL))
	_modal_discord.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_discord.custom_minimum_size = Vector2(280.0, 44.0)
	_modal_discord.add_theme_font_size_override("font_size", 17)
	_modal_discord.visible = false
	content.add_child(_modal_discord)

	var actions:= HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)

	_modal_cancel = _modal_button(tr("NOT YET"), false)
	_modal_cancel.pressed.connect(_cancel_modal)
	actions.add_child(_modal_cancel)

	_modal_confirm = _modal_button(tr("OK"), true)
	_modal_confirm.pressed.connect(_confirm_modal)
	actions.add_child(_modal_confirm)


func _build_map_column(parent: Control) -> void:
	_map_column = VBoxContainer.new()
	_map_column.add_theme_constant_override("separation", 8)
	_map_column.custom_minimum_size = Vector2(SLOT_COLUMN_W, 0)
	_map_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(_map_column)

	_map_column.add_child(_label(tr("WHERE ARE YOU WORKING"), 26, COL_TITLE, true))

	for spec: Dictionary in MapMenu.startable_maps():
		var id:= str(spec.get("id", ""))
		_map_column.add_child(_entry(str(spec.get("name", "")),
			_on_map_chosen.bind(id)))


		var blurb:= _label(str(spec.get("blurb", "")), 15, COL_OFF)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(SLOT_COLUMN_W, 0)
		_map_column.add_child(blurb)

	_map_column.add_child(_entry(tr("BACK"), _on_back))


func _build_size_column(parent: Control) -> void:
	_size_column = VBoxContainer.new()
	_size_column.add_theme_constant_override("separation", 6)
	_size_column.custom_minimum_size = Vector2(SLOT_COLUMN_W, 0)
	_size_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(_size_column)
	_fill_size_column()


func _fill_size_column() -> void:
	for child in _size_column.get_children():
		child.queue_free()
		_size_column.remove_child(child)

	_size_column.add_child(_label(tr("HOW MUCH HAY"), 26, COL_TITLE, true))

	for spec: Dictionary in Cfg.listed_pile_sizes():
		if bool(spec.get("heavy", false)) and not _size_expanded:
			continue
		var id:= str(spec.get("id", ""))
		_size_column.add_child(_entry(str(spec.get("name", "")),
			_on_size_chosen.bind(id), 46.0))
		_size_column.add_child(_size_blurb(
			"%s   %s" % [str(spec.get("blurb", "")), _size_stats(spec)], COL_OFF))

	if not _size_expanded:
		_size_column.add_child(_entry(tr("I WANT BIGGER"), _on_want_bigger, 46.0))
		_size_column.add_child(_size_blurb(
			tr("Bigger piles than this one. They ask a lot of a computer."), COL_OFF))

	_size_column.add_child(_entry(tr("BACK"), _on_back))


func _size_blurb(text: String, colour: Color) -> Label:
	var blurb:= _label(text, 15, colour)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(SLOT_COLUMN_W, 0)
	return blurb


func _on_want_bigger() -> void:
	Audio.play("ui_open")


	_show_modal(
		tr("BIGGER PILES"),
		tr("These piles may require your computer to be really powerful. The game may take a long time to load, may not load at all, and crashes may occur.\n\nSTANDARD is the size the game is tuned for."),
		tr("SHOW ME ANYWAY"),
		_reveal_big_sizes,
		true
	)


func _reveal_big_sizes() -> void:
	_size_expanded = true
	_fill_size_column()


func _size_stats(spec: Dictionary) -> String:
	var h: float = float(spec.get("height", 0.0))
	var strands: float = Cfg.pile_volume_estimate(spec) * Cfg.STRANDS_PER_M3


	if TranslationServer.get_locale().begins_with("zh"):
		var count:= "%.1f亿" % (strands / 100000000.0) if strands >= 100000000.0 else "%d万" % (int(round(strands / 100000.0)) * 10)
		return "高%d米，大约有%s根草。" % [int(round(h)), count]

	if TranslationServer.get_locale().begins_with("ja"):
		var count:= "%.1f億" % (strands / 100000000.0) if strands >= 100000000.0 else "%d万" % (int(round(strands / 100000.0)) * 10)


		var held:= ""
		for ch: String in "高さ%dm、干し草は約%s本。" % [int(round(h)), count]:
			held += ch if ch == "、" else ch + "⁠"
		return held


	if TranslationServer.get_locale().begins_with("ko"):
		var man:= int(round(strands / 1000000.0)) * 100
		var count:= "%d만" % man
		if man >= 10000:
			count = "%d억" % (man / 10000)
			if man % 10000 != 0:
				count += " %d만" % (man % 10000)
		return "높이 %dm, 건초는 약 %s 가닥이에요." % [int(round(h)), count]
	var millions:= strands / 1000000.0
	if millions >= 100.0:
		return tr("%d m tall, about %d million strands.") % [int(round(h)), int(round(millions))]
	return tr("%d m tall, about %.1f million strands.") % [int(round(h)), millions]


func _build_slot_column(parent: Control) -> void:
	_slot_column = VBoxContainer.new()
	_slot_column.add_theme_constant_override("separation", 8)
	_slot_column.custom_minimum_size = Vector2(SLOT_COLUMN_W, 0)
	_slot_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(_slot_column)

	_slot_title = _label("", 26, COL_TITLE, true)
	_slot_column.add_child(_slot_title)


	_slot_scroll = ScrollContainer.new()
	_slot_scroll.custom_minimum_size = Vector2(SLOT_COLUMN_W, SLOT_LIST_MAX_H)
	_slot_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER


	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_slot_column.add_child(_slot_scroll)
	_style_scrollbar(_slot_scroll.get_v_scroll_bar())

	var list:= VBoxContainer.new()
	list.name = "Slots"
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll.add_child(list)

	_slot_list = list

	_slot_column.add_child(_entry(tr("BACK"), _on_back))


func _build_slot_card() -> void:
	_slot_card = PanelContainer.new()
	_slot_card.name = "SlotCard"
	_slot_card.visible = false


	_slot_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_card.custom_minimum_size = Vector2(CARD_W, 0)
	_slot_card.add_theme_stylebox_override("panel", _card_style())
	add_child(_slot_card)

	var box:= VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	_slot_card.add_child(box)

	_card_title = _label("", 21, COL_TITLE, true)
	box.add_child(_card_title)

	var grid:= GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	box.add_child(grid)

	for _i in CARD_ROWS:
		var key:= _label("", 16, COL_DIM)


		key.visible = false
		grid.add_child(key)
		_card_keys.append(key)

		var value:= _label("", 16, COL_TEXT)
		value.visible = false
		grid.add_child(value)
		_card_values.append(value)


func _card_style() -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.97)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_color = Color(COL_TITLE, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb


func _reveal_slot(slot: int) -> void:
	if _slot_scroll == null or slot < 0 or slot >= _slot_rows.size():
		return
	_slot_scroll.ensure_control_visible(_slot_rows [slot])


func _style_scrollbar(bar: VScrollBar) -> void:
	if bar == null:
		return
	bar.custom_minimum_size = Vector2(10.0, 0.0)
	var track:= StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.04, 0.06, 0.45)
	track.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grab:= StyleBoxFlat.new()
		grab.bg_color = (COL_TITLE if state == "grabber"
			else COL_TITLE.lightened(0.2))
		grab.bg_color.a = 0.38 if state == "grabber" else 0.72
		grab.set_corner_radius_all(0)
		bar.add_theme_stylebox_override(state, grab)


func _build_options_column(_parent: Control) -> void:
	var centre:= CenterContainer.new()
	centre.name = "OptionsCentre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	sb.border_color = OptionsPanel.COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)

	_options_column = VBoxContainer.new()
	_options_column.add_theme_constant_override("separation", 8)
	card.add_child(_options_column)

	_options_root = centre


	var scroll:= ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_column.add_child(scroll)


	var panel:= OptionsPanel.new()

	panel.quit_action = _quit_now
	scroll.add_child(panel)
	panel.fit_into(scroll, OPTIONS_MAX_H)

	var back:= _entry(tr("BACK"), _on_back, 46.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_options_column.add_child(back)


func _build_leaderboard_column() -> void:
	var centre:= CenterContainer.new()
	centre.name = "LeaderboardCentre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	sb.border_color = LeaderboardPanel.COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)

	var column:= VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	_leaderboard_root = centre

	var heading:= _label(tr("LEADERBOARDS"), 26, COL_TITLE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var blurb:= _label(tr(LeaderboardPanel.BLURB), 15, COL_DIM)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(blurb)

	_leaderboard_panel = LeaderboardPanel.new()
	column.add_child(_leaderboard_panel)

	var back:= _entry(tr("BACK"), _on_back, 46.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(back)


func _build_footer() -> void:
	var foot:= _label(Cfg.BUILD_TAG, 15, COL_OFF)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.offset_left = -240.0
	foot.offset_right = -30.0
	foot.offset_top = -42.0
	foot.offset_bottom = -20.0
	add_child(foot)


func _show_page(page: int) -> void:
	_page = page
	_pending_overwrite = -1
	_pending_delete = -1


	_renaming = -1

	_card_slot = -1
	if _slot_card != null:
		_slot_card.visible = false
	_root_column.visible = page == Page.ROOT
	_social_links.visible = page == Page.ROOT
	_static_box.visible = page == Page.ROOT


	_static_box.set_pressed_no_signal(Cfg.menu_backdrop_static())
	_map_column.visible = page == Page.MAP_PICK
	_size_column.visible = page == Page.SIZE_PICK
	_slot_column.visible = page == Page.NEW_GAME or page == Page.LOAD_GAME
	_options_root.visible = page == Page.OPTIONS
	_leaderboard_root.visible = page == Page.LEADERBOARDS
	if page == Page.LEADERBOARDS:


		_leaderboard_panel.refresh()
	if page == Page.ROOT:
		_load_button.disabled = not SaveManager.any_save()
	elif _slot_column.visible:
		_slot_title.text = tr("START A NEW RUN IN") if page == Page.NEW_GAME else tr("CONTINUE")
		_refresh_slots()
		_scroll_to_the_interesting_slot(page)


func _scroll_to_the_interesting_slot(page: int) -> void:
	if _slot_scroll == null:
		return
	_slot_scroll.scroll_vertical = 0
	if page != Page.NEW_GAME:
		return
	var fresh:= SaveManager.next_free_slot()
	if fresh < 0:
		return


	await get_tree().process_frame
	if _page == Page.NEW_GAME:
		_reveal_slot(fresh)


func _shown_slots() -> Array [int]:
	var out: Array [int] = []
	for i in SaveManager.SLOT_COUNT:
		if SaveManager.has_save(i):
			out.append(i)
	if _page == Page.NEW_GAME:
		var fresh:= SaveManager.next_free_slot()
		if fresh >= 0:
			out.append(fresh)
	return out


func _refresh_slots() -> void:
	var shown:= _shown_slots()


	for slot: int in shown:
		while _slot_rows.size() <= slot:
			_slot_list.add_child(_slot_row(_slot_rows.size()))
	for r: Button in _slot_rows:
		r.visible = false


	for place in shown.size():
		_slot_list.move_child(_slot_rows [shown [place]], place)
	for i: int in shown:
		var s:= SaveManager.slot_summary(i)
		var row:= _slot_rows [i]
		row.visible = true
		var detail:= _slot_detail [i]
		var kill:= _slot_delete [i]
		var rename:= _slot_rename [i]
		var edit:= _slot_edit [i]
		var lock:= _slot_lock [i]
		var locked: bool = s.get("locked", false)


		var given:= str(s.get("name", ""))
		row.text = given if given != "" else tr("SLOT %d") % (i + 1)


		var newer: bool = str(s.get("status", "")) == SaveManager.READ_NEWER
		kill.visible = SaveManager.has_save(i) and not newer
		kill.text = tr("ERASE?") if _pending_delete == i else tr("ERASE")


		rename.visible = not s.is_empty() and s.get("readable", false)


		lock.visible = rename.visible


		lock.set_pressed_no_signal(locked)
		lock.text = tr("LOCKED") if locked else tr("LOCK")


		kill.disabled = locked
		rename.disabled = locked
		edit.visible = _renaming == i
		if edit.visible:


			rename.visible = false
			kill.visible = false
			lock.visible = false
			row.disabled = true
			detail.text = tr("Enter to save this name, Esc to leave it alone")
			detail.add_theme_color_override("font_color", COL_TITLE)
			continue
		if s.is_empty():


			row.text = tr("NEW GAME")
			detail.text = tr("Start a new run here")
			detail.add_theme_color_override("font_color", COL_DIM)
			row.disabled = false
		elif locked and _page == Page.NEW_GAME:


			detail.text = tr("Locked. Clear the box to start a new run here")
			detail.add_theme_color_override("font_color", COL_DIM)
			row.disabled = true
		elif _pending_delete == i:
			detail.text = tr("Click ERASE again to delete this save for good")
			detail.add_theme_color_override("font_color", COL_WARN)
			row.disabled = _page == Page.LOAD_GAME and not s.get("readable", false)
		elif newer:


			detail.text = tr("Saved by a newer version of the game. Update to open this run")
			detail.add_theme_color_override("font_color", COL_WARN)
			row.disabled = _page == Page.LOAD_GAME
		elif not s.get("readable", false):
			detail.text = tr("Damaged save. Cannot be read by this build")
			detail.add_theme_color_override("font_color", COL_WARN)
			row.disabled = _page == Page.LOAD_GAME
		elif s.get("incompatible", false):


			detail.text = tr("This save was made with a different pile size and cannot be opened by this build")
			detail.add_theme_color_override("font_color", COL_WARN)
			row.disabled = _page == Page.LOAD_GAME
		elif s.get("from_backup", false):


			detail.text = tr("Recovered from a backup  ·  %s") % _summary_line(s)
			detail.add_theme_color_override("font_color", COL_WARN)
			row.disabled = false
		elif _pending_overwrite == i:
			detail.text = tr("Click again to erase this run and start over")
			detail.add_theme_color_override("font_color", COL_WARN)
			row.disabled = false
		else:
			detail.text = _summary_line(s)
			detail.add_theme_color_override("font_color", COL_DIM)
			row.disabled = false


	if _card_slot >= 0:
		_show_slot_card(_card_slot)


func _summary_line(s: Dictionary) -> String:
	var needles: int = s ["needles_found"]


	var parts:= PackedStringArray([
		"$%s" % Hud.money_text(float(s ["money"])),
		tr_n("%d needle", "%d needles", needles) % needles,
		tr("%s strands dug") % Hud.fmt(float(s ["hay_dug"])),
	])


	var left:= float(s.get("hay_total", 0.0))
	if left > 0.0:
		parts.append(tr("%s left") % _short_count(left))


	var size:= str(s.get("pile_size", Cfg.DEFAULT_PILE_SIZE))
	if size != Cfg.DEFAULT_PILE_SIZE:
		parts.append(str(Cfg.pile_size_spec(size).get("name", "")))
	var when: int = s ["saved_at"]
	if when > 0:
		parts.append(_stamp(when))
	return "   ".join(parts)


func _short_count(v: float) -> String:


	var lang:= TranslationServer.get_locale()
	if (lang.begins_with("ko") or lang.begins_with("ja")) and v >= 10000.0:
		var man:= "万" if lang.begins_with("ja") else "만"
		var oku:= "億" if lang.begins_with("ja") else "억"
		if v >= 100000000.0:
			return ("%d%s" % [int(round(v / 100000000.0)), oku]) if v >= 1000000000.0 else ("%.1f%s" % [v / 100000000.0, oku]).replace(".0" + oku, oku)
		return "%d%s" % [int(round(v / 10000.0)), man]
	if v >= 1000000.0:
		var m:= v / 1000000.0
		return tr("%dM", "millions") % int(round(m)) if m >= 10.0 else tr("%.1fM", "millions") % m
	if v >= 1000.0:
		return tr("%dK", "thousands") % int(round(v / 1000.0))
	return Hud.fmt(v)


func _on_row_entered(slot: int) -> void:
	_card_slot = slot
	_show_slot_card(slot)


func _on_row_exited(slot: int) -> void:
	if _card_slot != slot:
		return
	_card_slot = -1
	_hide_slot_card.call_deferred()


func _hide_slot_card() -> void:
	if _card_slot < 0 and _slot_card != null:
		_slot_card.visible = false


func _show_slot_card(slot: int) -> void:
	if _slot_card == null or not _slot_column.visible or _renaming >= 0:
		return
	if slot < 0 or slot >= _slot_rows.size():
		return
	var s:= SaveManager.slot_summary(slot)


	if s.is_empty() or not bool(s.get("readable", false)):
		_slot_card.visible = false
		return
	_fill_slot_card(slot, s)
	_slot_card.visible = true
	_place_slot_card(slot)


func _place_slot_card(slot: int) -> void:
	var height:= _slot_card.get_combined_minimum_size().y
	_slot_card.size = Vector2(CARD_W, height)
	var x:= minf(MARGIN_L + SLOT_COLUMN_W + CARD_GAP, size.x - CARD_W - 24.0)


	var top:= _slot_rows [slot].global_position.y - global_position.y
	_slot_card.position = Vector2(x, clampf(top, 268.0, maxf(268.0, size.y - 48.0 - height)))


func _fill_slot_card(slot: int, s: Dictionary) -> void:
	var given:= str(s.get("name", ""))
	_card_title.text = given if given != "" else tr("SLOT %d") % (slot + 1)

	var row:= 0


	var played:= float(s.get("run_secs", 0.0))
	if played > 0.0:
		row = _card_line(row, tr("Played"), Leaderboard.clock_text(played))
	row = _card_line(row, tr("Hay"), _card_hay(s))


	row = _card_line(row, tr("Pile"),
		str(Cfg.pile_size_spec(str(s.get("pile_size", Cfg.DEFAULT_PILE_SIZE)))
			.get("name", "")).capitalize())


	var map:= str(s.get("map", SaveManager.DEFAULT_MAP))
	if map != SaveManager.DEFAULT_MAP:
		row = _card_line(row, tr("Site"), MapMenu.display_name(map))
	row = _card_line(row, tr("Built"), _card_built(s))
	row = _card_line(row, tr("Belt"), _card_belt(s))
	row = _card_line(row, tr("Upgrades"), _card_upgrades(s))
	row = _card_line(row, tr("Money"), "$%s" % Hud.money_text(float(s.get("money", 0.0))))
	row = _card_line(row, tr("Earned in total"),
		"$%s" % Hud.money_text(float(s.get("money_earned", 0.0))))
	row = _card_line(row, tr("Needles found"), str(int(s.get("needles_found", 0))))
	var stocked:= int(s.get("needles_stocked", 0))
	if stocked > 0:
		row = _card_line(row, tr("In the cabinet"), str(stocked))
	var first:= float(s.get("first_needle_secs", -1.0))
	if first > 0.0:
		row = _card_line(row, tr("First needle"), Leaderboard.clock_text(first))
	var cleared:= float(s.get("pile_clear_secs", -1.0))
	if cleared > 0.0:
		row = _card_line(row, tr("Pile cleared"), Leaderboard.clock_text(cleared))
	var orders:= int(s.get("contracts_done", 0))
	if orders > 0:
		row = _card_line(row, tr("Deliveries"), str(orders))
	row = _card_line(row, tr("Missions"), _card_missions(s))
	var when:= int(s.get("saved_at", 0))
	if when > 0:
		row = _card_line(row, tr("Saved"), _stamp(when))
	while row < _card_keys.size():
		_card_keys [row].visible = false
		_card_values [row].visible = false
		row += 1


func _card_line(row: int, key: String, value: String) -> int:
	if value == "" or row >= _card_keys.size():
		return row
	_card_keys [row].text = key
	_card_keys [row].visible = true
	_card_values [row].text = value
	_card_values [row].visible = true
	return row + 1


func _card_hay(s: Dictionary) -> String:
	var left:= float(s.get("hay_total", 0.0))
	var initial:= float(s.get("hay_initial", 0.0))
	if left <= 0.0 and initial <= 0.0:
		return ""
	if initial <= 0.0:
		return _short_count(left)
	var gone:= clampf(1.0 - left / initial, 0.0, 1.0)
	return "%s  ·  %s" % [
		tr("%s left of %s") % [_short_count(left), _short_count(initial)],
		tr("%d%% dug") % int(round(gone * 100.0))]


func _card_built(s: Dictionary) -> String:
	var n:= int(s.get("structures", 0))
	if n <= 0:
		return tr("nothing yet")
	return tr_n("%d structure", "%d structures", n) % n


func _card_belt(s: Dictionary) -> String:
	var metres:= float(s.get("belt_metres", 0.0))
	if metres <= 0.0:
		return ""
	return tr("%.1f km") % (metres / 1000.0) if metres >= 1000.0 else tr("%d m") % int(round(metres))


func _card_upgrades(s: Dictionary) -> String:
	var bought:= int(s.get("tech_ranks", 0))
	return str(bought) if bought > 0 else tr("nothing bought yet")


func _card_missions(s: Dictionary) -> String:
	var total:= MissionBook.count()
	if total <= 0:
		return ""


	var step:= int(s.get("mission_index", 0))
	if step >= total:
		return tr("all done")


	return tr("%d of %d", "jobs") % [step + 1, total]


func _on_new_game() -> void:
	Audio.play("ui_open")
	if Cfg.DEMO:
		_show_modal(
			tr("BEFORE YOU START"),
			tr("This is a demo version, so bugs may exist. Please report anything you find in our Discord channel.\n\nThe most active community members will be included in the credits when the full game releases."),
			tr("START DEMO"),
			_continue_new_game,
			true
		)
		return


	_show_modal(
		tr("BEFORE YOU START"),
		tr("This is a test version of the full game, so bugs may exist. Please report anything you find in our Discord channel."),
		tr("START"),
		_continue_new_game,
		true
	)


func _continue_new_game() -> void:
	if _only_site() != "":
		_on_map_chosen(_only_site())
		return
	_show_page(Page.MAP_PICK)


func _only_site() -> String:
	var sites:= MapMenu.startable_maps()
	if sites.size() != 1:
		return ""
	return str(sites [0].get("id", ""))


func _on_map_chosen(map_id: String) -> void:
	Audio.play("ui_select")
	_chosen_map = map_id


	_size_expanded = false
	_fill_size_column()
	_show_page(Page.SIZE_PICK)


func _on_size_chosen(size_id: String) -> void:
	Audio.play("ui_select")
	_chosen_size = size_id

	if not SaveManager.any_save():
		_start(0, true)
		return
	_show_page(Page.NEW_GAME)


func _on_load_game() -> void:
	Audio.play("ui_open")
	_show_page(Page.LOAD_GAME)


func _on_multiplayer() -> void:
	Audio.play("ui_open")
	_show_modal(
		tr("MULTIPLAYER"),
		tr("We're working hard to bring multiplayer to the game. Please be patient. It's coming soon!"),
		tr("GOT IT"),
		Callable(),
		false
	)


func _on_leaderboards() -> void:
	Audio.play("ui_open")
	_show_page(Page.LEADERBOARDS)


func _on_options() -> void:
	Audio.play("ui_open")
	_show_page(Page.OPTIONS)


func _on_back() -> void:
	Audio.play("ui_back")
	match _page:
		Page.NEW_GAME:
			_show_page(Page.SIZE_PICK)
		Page.SIZE_PICK:


			if _size_expanded:
				_size_expanded = false
				_fill_size_column()
			elif _only_site() != "":
				_show_page(Page.ROOT)
			else:
				_show_page(Page.MAP_PICK)
		_:
			_show_page(Page.ROOT)


func _on_quit() -> void:
	Audio.play("ui_open")
	_show_modal(
		tr("THANKS FOR PLAYING"),
		tr("Did you like it? Put Find The Needle on your Steam wishlist. It helps us a lot, and Steam will tell you when the game comes out."),
		tr("QUIT"),
		_quit_now,
		true,
		tr("CANCEL")
	)
	_modal_link.visible = true
	_modal_discord.visible = true


func _on_modal_link() -> void:
	Audio.play("ui_select")
	if OS.shell_open(PauseMenu.STEAM_URL) != OK:
		Audio.play("ui_error")
		_modal_body.text = tr("Please open this address in your browser:\n%s") % PauseMenu.STEAM_URL


func _quit_now() -> void:
	Audio.play("ui_close")
	get_tree().quit()


func _open_social(url: String) -> void:
	Audio.play("ui_select")
	var error:= OS.shell_open(url)
	if error != OK:
		Audio.play("ui_error")
		_show_modal(
			tr("COULDN'T OPEN LINK"),
			tr("Please open this address in your browser:\n%s") % url,
			tr("OK"),
			Callable(),
			false
		)


func _show_modal(title: String, body: String, confirm_text: String,
		action: Callable = Callable(), show_cancel: bool = false,
		cancel_text: String = "", cancel_action: Callable = Callable()) -> void:
	_modal_title.text = title
	_modal_body.text = body
	_modal_confirm.text = confirm_text
	_modal_cancel.text = cancel_text if cancel_text != "" else tr("NOT YET")
	_modal_cancel.visible = show_cancel
	_modal_link.visible = false
	_modal_discord.visible = false
	_modal_action = action
	_modal_cancel_action = cancel_action
	_modal.visible = true
	_modal_confirm.grab_focus()


func _hide_modal() -> void:
	if not _modal.visible:
		return
	Audio.play("ui_back")
	_modal.visible = false
	_modal_action = Callable()
	_modal_cancel_action = Callable()


func _cancel_modal() -> void:
	if not _modal.visible:
		return
	var action:= _modal_cancel_action
	_hide_modal()
	if action.is_valid():
		action.call()


func _confirm_modal() -> void:
	if not _modal.visible:
		return
	Audio.play("ui_select")
	var action:= _modal_action
	_modal.visible = false
	_modal_action = Callable()
	if action.is_valid():
		action.call()


func _on_rename_pressed(slot: int) -> void:
	var s:= SaveManager.slot_summary(slot)
	if s.is_empty() or not s.get("readable", false) or s.get("locked", false):
		Audio.play("ui_error")
		return


	_pending_delete = -1
	_pending_overwrite = -1
	_renaming = slot
	Audio.play("ui_open", -4.0)
	_refresh_slots()

	_reveal_slot(slot)
	var edit:= _slot_edit [slot]
	edit.text = str(s.get("name", ""))
	edit.grab_focus()
	edit.select_all()


func _on_rename_submitted(text: String, slot: int) -> void:
	SaveManager.rename_save(slot, text)
	_slot_edit [slot].release_focus()
	_renaming = -1
	Audio.play("ui_select")
	_refresh_slots()


func _on_rename_input(event: InputEvent, slot: int) -> void:
	if not event.is_action_pressed("free_mouse"):
		return
	var edit:= _slot_edit [slot]


	edit.accept_event()
	edit.release_focus()
	_renaming = -1
	Audio.play("ui_close", -4.0)
	_refresh_slots()


func _on_lock_toggled(pressed: bool, slot: int) -> void:
	if not SaveManager.set_locked(slot, pressed):


		Audio.play("ui_error")
		_refresh_slots()
		return


	_pending_delete = -1
	_pending_overwrite = -1
	Audio.play("ui_select" if pressed else "ui_close", -4.0)
	_refresh_slots()


func _on_delete_pressed(slot: int) -> void:
	if not SaveManager.has_save(slot) or SaveManager.is_locked(slot):
		return


	if str(SaveManager.slot_summary(slot).get("status", "")) == SaveManager.READ_NEWER:
		Audio.play("ui_error")
		_refresh_slots()
		return
	if _pending_delete != slot:
		Audio.play("ui_error")
		_pending_delete = slot
		_pending_overwrite = -1
		_refresh_slots()
		return
	SaveManager.delete_save(slot)
	Audio.play("ui_close")
	_pending_delete = -1
	_refresh_slots()


	_load_button.disabled = not SaveManager.any_save()


	if _page == Page.LOAD_GAME and not SaveManager.any_save():
		_show_page(Page.ROOT)


func _on_slot_pressed(slot: int) -> void:
	_pending_delete = -1
	if _page == Page.LOAD_GAME:


		var summary:= SaveManager.slot_summary(slot)
		if not summary.get("readable", false) or summary.get("incompatible", false):
			Audio.play("ui_error")
			_refresh_slots()
			return
		Audio.play("ui_select")
		_start(slot, false)
		return
	var s:= SaveManager.slot_summary(slot)
	if s.is_empty():
		Audio.play("ui_select")
		_start(slot, true)
		return
	if s.get("locked", false):


		Audio.play("ui_error")
		_refresh_slots()
		return
	if _pending_overwrite != slot:
		Audio.play("ui_error")
		_pending_overwrite = slot
		_refresh_slots()
		return
	Audio.play("ui_select")
	_start(slot, true)


func _start(slot: int, fresh: bool) -> void:
	if _leaving:
		return
	if fresh:


		if not SaveManager.begin_new_game(slot, false, _chosen_map, _chosen_size):
			Audio.play("ui_error")
			_refresh_slots()
			return


		Cfg.restart_lessons()
	else:
		SaveManager.begin_load(slot)
	_leaving = true
	_root_column.visible = false
	_slot_column.visible = false
	_social_links.visible = false
	move_child(_fade, get_child_count() - 1)
	var t:= create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.45)
	t.tween_callback(_enter_game)


func _enter_game() -> void:
	Loading.show_screen("FIND THE NEEDLE", tr("PREPARING THE PILE"))
	Loading.enter_scene(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if _modal.visible and event.is_action_pressed("free_mouse"):
		_hide_modal()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("free_mouse") and _page != Page.ROOT:
		_on_back()
		get_viewport().set_input_as_handled()


func _entry(text: String, on_press: Callable, height: float = 54.0) -> Button:
	var b:= Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TITLE)
	b.add_theme_color_override("font_pressed_color", COL_TITLE)
	b.add_theme_color_override("font_disabled_color", COL_OFF)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("normal", _entry_style(false))
	b.add_theme_stylebox_override("hover", _entry_style(true))
	b.add_theme_stylebox_override("pressed", _entry_style(true))
	b.add_theme_stylebox_override("focus", _entry_style(false))
	b.add_theme_stylebox_override("disabled", _entry_style(false))
	b.pressed.connect(on_press)
	b.mouse_entered.connect(_on_hover.bind(b))
	return b


func _entry_style(accent: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.3 if accent else 0.0)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	if accent:
		sb.border_width_left = 5
		sb.border_color = COL_TITLE
	return sb


func _social_button(text: String, colour: Color, on_press: Callable) -> Button:
	var b:= Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(384.0, 62.0)
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
	b.mouse_entered.connect(_on_hover.bind(b))
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


func _modal_style() -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.98)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.border_color = Color(COL_TITLE, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 24
	return sb


func _modal_button(text: String, primary: bool) -> Button:
	var b:= Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210.0, 58.0)
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(0.06, 0.065, 0.08) if primary else COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.02, 0.025, 0.03) if primary else COL_TITLE)
	b.add_theme_color_override("font_pressed_color", Color(0.02, 0.025, 0.03) if primary else COL_TITLE)
	b.add_theme_color_override("font_focus_color", Color(0.02, 0.025, 0.03) if primary else COL_TITLE)
	b.add_theme_stylebox_override("normal", _modal_button_style(primary, false))
	b.add_theme_stylebox_override("hover", _modal_button_style(primary, true))
	b.add_theme_stylebox_override("pressed", _modal_button_style(primary, true))
	b.add_theme_stylebox_override("focus", _modal_button_style(primary, true))
	b.mouse_entered.connect(_on_hover.bind(b))
	return b


func _modal_button_style(primary: bool, accent: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	if primary:
		sb.bg_color = COL_TITLE.lightened(0.1) if accent else COL_TITLE
		sb.border_color = Color.WHITE if accent else COL_TITLE.lightened(0.24)
	else:
		sb.bg_color = Color(0.1, 0.115, 0.15, 0.95)
		sb.border_color = COL_TITLE if accent else Color(0.55, 0.58, 0.64, 0.55)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	return sb


func _slot_row(slot: int) -> Button:
	var b:= Button.new()
	b.focus_mode = Control.FOCUS_NONE


	b.custom_minimum_size = Vector2(0, SLOT_H)
	b.add_theme_stylebox_override("normal", _slot_style(false, false))
	b.add_theme_stylebox_override("hover", _slot_style(true, false))
	b.add_theme_stylebox_override("pressed", _slot_style(true, false))
	b.add_theme_stylebox_override("focus", _slot_style(false, false))
	b.add_theme_stylebox_override("disabled", _slot_style(false, true))
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TITLE)
	b.add_theme_color_override("font_pressed_color", COL_TITLE)
	b.add_theme_color_override("font_disabled_color", COL_OFF)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_on_slot_pressed.bind(slot))
	b.mouse_entered.connect(_on_hover.bind(b))


	b.mouse_entered.connect(_on_row_entered.bind(slot))
	b.mouse_exited.connect(_on_row_exited.bind(slot))


	var detail:= _label("", 17, COL_DIM)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	detail.grow_vertical = Control.GROW_DIRECTION_BEGIN
	detail.offset_left = 22.0
	detail.offset_right = -18.0
	detail.offset_top = -30.0
	detail.offset_bottom = -12.0
	b.add_child(detail)


	var kill:= _row_action("Erase", tr("ERASE"), STRIP_ERASE, true)
	kill.pressed.connect(_on_delete_pressed.bind(slot))
	b.add_child(kill)
	_slot_delete.append(kill)


	var rename:= _row_action("Rename", tr("RENAME"), STRIP_RENAME, false)
	rename.pressed.connect(_on_rename_pressed.bind(slot))
	b.add_child(rename)
	_slot_rename.append(rename)


	var lock:= _row_lock()
	lock.toggled.connect(_on_lock_toggled.bind(slot))
	b.add_child(lock)
	_slot_lock.append(lock)


	var edit:= LineEdit.new()
	edit.name = "NameEdit"
	edit.visible = false
	edit.max_length = SaveManager.NAME_MAX_LEN
	edit.placeholder_text = tr("Name this run")
	edit.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edit.offset_left = 16.0


	edit.offset_right = - ROW_ACTION_EDGE

	edit.offset_top = ROW_PAD_TOP
	edit.offset_bottom = SLOT_H - ROW_PAD_BOTTOM
	edit.add_theme_font_override("font", UiFont.bold())
	edit.add_theme_font_size_override("font_size", 22)
	edit.add_theme_color_override("font_color", COL_TITLE)
	edit.add_theme_stylebox_override("normal", _edit_style())
	edit.add_theme_stylebox_override("focus", _edit_style())
	edit.text_submitted.connect(_on_rename_submitted.bind(slot))
	edit.gui_input.connect(_on_rename_input.bind(slot))
	b.add_child(edit)
	_slot_edit.append(edit)

	_slot_rows.append(b)
	_slot_detail.append(detail)
	return b


func _row_action(node_name: String, text: String, place: int, warn: bool) -> Button:
	var b:= Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE


	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.text = text
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.grow_vertical = Control.GROW_DIRECTION_END
	b.offset_left = - _row_action_left(place)
	b.offset_right = - (_row_action_left(place) - ROW_STRIP_W [place])


	b.offset_top = ROW_PAD_TOP
	b.offset_bottom = SLOT_H - ROW_PAD_BOTTOM
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", COL_OFF)


	var lit:= COL_WARN if warn else COL_TITLE
	b.add_theme_color_override("font_hover_color", lit)
	b.add_theme_color_override("font_pressed_color", lit)
	b.add_theme_color_override("font_disabled_color", Color(COL_OFF, 0.45))
	b.add_theme_stylebox_override("normal", _row_action_style(false, warn))
	b.add_theme_stylebox_override("hover", _row_action_style(true, warn))
	b.add_theme_stylebox_override("pressed", _row_action_style(true, warn))


	b.add_theme_stylebox_override("disabled", _row_action_style(false, warn))
	return b


func _row_lock() -> CheckBox:
	var c:= CheckBox.new()
	c.name = "Lock"
	c.text = tr("LOCK")
	c.focus_mode = Control.FOCUS_NONE
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c.grow_vertical = Control.GROW_DIRECTION_END
	c.offset_left = - _row_action_left(STRIP_LOCK)
	c.offset_right = - (_row_action_left(STRIP_LOCK) - ROW_STRIP_W [STRIP_LOCK])
	c.offset_top = ROW_PAD_TOP
	c.offset_bottom = SLOT_H - ROW_PAD_BOTTOM
	c.add_theme_font_override("font", UiFont.bold())
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_constant_override("h_separation", 6)
	c.add_theme_color_override("font_color", COL_OFF)
	c.add_theme_color_override("font_hover_color", COL_TITLE)
	c.add_theme_color_override("font_pressed_color", COL_TITLE)
	c.add_theme_icon_override("unchecked", _check_icon(false))
	c.add_theme_icon_override("checked", _check_icon(true))


	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color"]:
		c.add_theme_color_override(state, Color.WHITE)
	c.toggle_mode = true
	c.mouse_entered.connect(_on_hover.bind(c))
	return c


const CHECK_PX:= 22
const CHECK_SS:= 4


static var _check_off: ImageTexture
static var _check_on: ImageTexture


func _check_icon(ticked: bool) -> ImageTexture:
	if ticked and _check_on != null:
		return _check_on
	if not ticked and _check_off != null:
		return _check_off
	var n:= CHECK_PX * CHECK_SS
	var w:= 2 * CHECK_SS
	var img:= Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	img.fill_rect(Rect2i(0, 0, n, n), COL_TITLE if ticked else COL_OFF)
	img.fill_rect(Rect2i(w, w, n - w * 2, n - w * 2),
		Color(COL_TITLE, 0.16) if ticked else Color(0, 0, 0, 0))
	if ticked:

		_stroke(img, Vector2(0.24, 0.52), Vector2(0.43, 0.72), n)
		_stroke(img, Vector2(0.43, 0.72), Vector2(0.78, 0.29), n)
	img.resize(CHECK_PX, CHECK_PX, Image.INTERPOLATE_LANCZOS)
	var tex:= ImageTexture.create_from_image(img)
	if ticked:
		_check_on = tex
	else:
		_check_off = tex
	return tex


func _stroke(img: Image, from: Vector2, to: Vector2, n: int) -> void:
	var a:= from * float(n)
	var b:= to * float(n)
	var half:= int(roundf(1.4 * CHECK_SS))
	var steps:= int(ceilf(a.distance_to(b)))
	for i in steps + 1:
		var p:= a.lerp(b, float(i) / float(steps))
		var x:= clampi(int(roundf(p.x)) - half, 0, n - half * 2)
		var y:= clampi(int(roundf(p.y)) - half, 0, n - half * 2)
		img.fill_rect(Rect2i(x, y, half * 2, half * 2), COL_TITLE)


func _row_action_left(place: int) -> float:
	var left:= ROW_ACTION_EDGE
	for i in place + 1:
		if i > 0:
			left += ROW_ACTION_GAP
		left += ROW_STRIP_W [i]
	return left


func _row_action_style(accent: bool, warn: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	var tint:= Color(0.1, 0.03, 0.04) if warn else Color(0.1, 0.09, 0.04)
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.72 if accent else 0.0)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_color = ((COL_WARN if warn else COL_TITLE) if accent
		else Color(0.55, 0.58, 0.64, 0.3))
	return sb


func _edit_style() -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_color = COL_TITLE
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	return sb


func _slot_style(accent: bool, off: bool) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.24 if off else (0.62 if accent else 0.46))
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.border_color = COL_TITLE if accent else Color(0.55, 0.58, 0.64, 0.35)
	if accent:
		sb.border_width_left = 5
	sb.content_margin_left = 20.0
	sb.content_margin_right = 16.0


	sb.content_margin_top = ROW_PAD_TOP
	sb.content_margin_bottom = ROW_PAD_BOTTOM
	return sb


func _on_hover(b: Button) -> void:
	if not b.disabled:
		Audio.play("ui_tick", -6.0)


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(l, size, colour, 5, heavy)
	return l


func _month(index: int) -> String:
	match index:
		1: return tr("Jan", "month")
		2: return tr("Feb", "month")
		3: return tr("Mar", "month")
		4: return tr("Apr", "month")
		5: return tr("May", "month")
		6: return tr("Jun", "month")
		7: return tr("Jul", "month")
		8: return tr("Aug", "month")
		9: return tr("Sep", "month")
		10: return tr("Oct", "month")
		11: return tr("Nov", "month")
	return tr("Dec", "month")


func _stamp(unix: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d:= Time.get_datetime_dict_from_unix_time(unix + bias * 60)


	var lang:= TranslationServer.get_locale()
	if lang.begins_with("zh") or lang.begins_with("ja"):
		return "%s%d日 %02d:%02d" % [_month(int(d ["month"])), d ["day"], d ["hour"], d ["minute"]]
	if lang.begins_with("ko"):
		return "%s %d일 %02d:%02d" % [_month(int(d ["month"])), d ["day"], d ["hour"], d ["minute"]]
	return "%d %s, %02d:%02d" % [d ["day"], _month(int(d ["month"])), d ["hour"], d ["minute"]]
