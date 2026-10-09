extends Node3D


const GAME_SCENE:= "res://scenes/main.tscn"


const SHOT_FLAG:= "--menushot"


const GLINT_FLAG:= "--glintshot"


const POSTER_FLAG:= "--postershot"


const LOAD_FLAG:= "--loadflow"


const BIND_FLAG:= "--controls"


const RES_FLAG:= "--resolution"


const HUD_FLAG:= "--hudopts"


const HUD_SHOT_FLAG:= "--hudpageshot"


const LEADERBOARD_FLAG:= "--lbshot"


const CRASH_FLAG:= "--crashreport"


const SIZE_FLAG:= "--pilesize"


const END_FLAG:= "--pileend"


const SIZE_SHOT_FLAG:= "--sizeshot"


const PLATE_FLAG:= "--menuplate"


const POWER_WARN_FLAG:= "--powerwarn"


const TIPS_FLAG:= "--tips"


const CLOSE_GUARD_FLAG:= "--closeguard"


const LANG_SHOT_FLAG:= "--langshot"


const MENU_LANG_FLAG:= "--menulang"


func _ready() -> void:
	var ua:= OS.get_cmdline_user_args()
	GameLog.put("menu", "menu_root: building UI at %d ms (%d user args)" % [Time.get_ticks_msec(), ua.size()])


	var lang_at:= ua.find(MENU_LANG_FLAG)
	if lang_at >= 0 and lang_at + 1 < ua.size() and not ua [lang_at + 1].begins_with("--"):
		_apply_shot_language(ua [lang_at + 1])
	var stays_for:= [SHOT_FLAG, GLINT_FLAG, POSTER_FLAG, LOAD_FLAG, BIND_FLAG,
		RES_FLAG, HUD_FLAG, HUD_SHOT_FLAG, LEADERBOARD_FLAG, CRASH_FLAG,
		SIZE_FLAG, END_FLAG, SIZE_SHOT_FLAG, PLATE_FLAG, POWER_WARN_FLAG, TIPS_FLAG,
		LANG_SHOT_FLAG, CLOSE_GUARD_FLAG]
	var stays:= ua.is_empty()
	for flag: String in stays_for:
		stays = stays or (flag in ua)
	if not stays:
		call_deferred("_skip_to_game")
		return


	if LOAD_FLAG in ua and get_tree().root.get_node_or_null("LoadProbe") == null:
		var lp:= DevLoadProbe.new()
		lp.name = "LoadProbe"
		get_tree().root.add_child.call_deferred(lp)
		lp.run.call_deferred()


	if SIZE_FLAG in ua:
		var size_probe:= DevPileSizeProbe.new()
		size_probe.name = "PileSizeProbe"
		add_child(size_probe)
		size_probe.run.call_deferred()
		return

	if END_FLAG in ua:
		var end_probe:= DevPileEndProbe.new()
		end_probe.name = "PileEndProbe"
		add_child(end_probe)
		end_probe.run.call_deferred()
		return


	if POWER_WARN_FLAG in ua:
		var warn_probe:= DevPowerWarningProbe.new()
		warn_probe.name = "PowerWarningProbe"
		add_child(warn_probe)
		warn_probe.run.call_deferred()
		return

	if TIPS_FLAG in ua:
		var tips_probe:= DevTipsProbe.new()
		tips_probe.name = "TipsProbe"
		add_child(tips_probe)
		tips_probe.run.call_deferred()
		return

	if CLOSE_GUARD_FLAG in ua:
		var guard_probe:= DevCloseGuardProbe.new()
		guard_probe.name = "CloseGuardProbe"
		add_child(guard_probe)
		guard_probe.run.call_deferred()
		return


	if POSTER_FLAG in ua:
		var poster:= PosterShot.new()
		poster.name = "PosterShot"
		add_child(poster)
		return


	var bg: MenuBackground = null
	_force_3d = GLINT_FLAG in ua or PLATE_FLAG in ua
	if _wants_plate():
		_add_plate()
	else:
		bg = MenuBackground.new()
		bg.name = "Background"
		bg.staged = Loading.is_active() and not (SHOT_FLAG in ua)
		add_child(bg)
		if bg.staged:
			await bg.built
		GameLog.put("menu", "menu_root: 3D background built at %d ms" % Time.get_ticks_msec())
	Cfg.quality_changed.connect(_on_quality_changed)

	var layer:= CanvasLayer.new()
	layer.name = "MenuLayer"
	add_child(layer)

	if LANG_SHOT_FLAG in ua:
		var lang_shot:= LanguagePickShot.new()
		lang_shot.name = "LanguagePickShot"
		lang_shot.layer = layer
		add_child(lang_shot)
		lang_shot.run.call_deferred()
		return


	if ua.is_empty() and not Cfg.locale_asked:
		if Loading.is_active():
			Loading.hide_screen()
		var picker:= LanguagePicker.new()
		picker.name = "LanguagePicker"
		layer.add_child(picker)
		await picker.chosen

	var menu:= MainMenu.new()
	menu.name = "MainMenu"
	layer.add_child(menu)
	_menu = menu
	menu.static_toggled.connect(_on_static_toggled)
	_sync_scrim()


	if CrashReport.pending != "":
		var report:= CrashReportDialog.new()
		report.name = "CrashReport"
		layer.add_child(report)

	if CRASH_FLAG in ua:
		var crash_probe:= DevCrashProbe.new()
		crash_probe.name = "CrashProbe"
		crash_probe.layer = layer
		add_child(crash_probe)
		crash_probe.run.call_deferred()

	if SHOT_FLAG in ua:
		var probe:= MenuShotProbe.new()
		probe.name = "MenuShotProbe"
		probe.menu = menu
		add_child(probe)

	if PLATE_FLAG in ua:
		var plate:= MenuPlateShot.new()
		plate.name = "MenuPlateShot"
		plate.menu = menu
		add_child(plate)
		plate.run.call_deferred()

	if BIND_FLAG in ua:


		var page:= OptionsPanel.new()
		page.name = "ControlsProbePanel"
		layer.add_child(page)
		var bind_probe:= DevControlsProbe.new()
		bind_probe.name = "ControlsProbe"
		bind_probe.panel = page
		add_child(bind_probe)
		bind_probe.run.call_deferred()

	if RES_FLAG in ua:


		var res_probe:= DevResolutionProbe.new()
		res_probe.name = "ResolutionProbe"
		add_child(res_probe)
		res_probe.run.call_deferred()

	if HUD_FLAG in ua:


		var hud_probe:= DevHudOptionsProbe.new()
		hud_probe.name = "HudOptionsProbe"
		add_child(hud_probe)
		hud_probe.run.call_deferred()

	if HUD_SHOT_FLAG in ua:


		var hud_shot:= HudPageShot.new()
		hud_shot.name = "HudPageShot"
		hud_shot.menu = menu
		add_child(hud_shot)
		hud_shot.run.call_deferred()

	if GLINT_FLAG in ua:
		var glint:= GlintProbe.new()
		glint.name = "GlintProbe"
		glint.background = bg
		add_child(glint)


	if Loading.is_active():
		Loading.hide_screen()
	GameLog.put("menu", "menu_root: ready at %d ms" % Time.get_ticks_msec())


const PLATE_PATH:= "res://assets/branding/menu_plate.jpg"

var _force_3d:= false
var _menu: MainMenu


func _wants_plate() -> bool:
	return not _force_3d and Cfg.menu_backdrop_static()


func _add_plate() -> void:
	var plate_layer:= CanvasLayer.new()
	plate_layer.name = "Background"
	plate_layer.layer = -1
	var rect:= TextureRect.new()
	rect.name = "Plate"
	rect.texture = load(PLATE_PATH)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate_layer.add_child(rect)
	add_child(plate_layer)
	move_child(plate_layer, 0)


func _sync_scrim() -> void:
	if _menu == null:
		return
	var scrim:= _menu.get_node_or_null("Scrim") as CanvasItem
	if scrim != null:
		scrim.visible = not (get_node_or_null("Background") is CanvasLayer)


func _on_quality_changed(_level: int) -> void:
	_sync_backdrop()


func _on_static_toggled(_on: bool) -> void:
	_sync_backdrop()


func _sync_backdrop() -> void:
	var old:= get_node_or_null("Background")
	var has_plate:= old is CanvasLayer
	if has_plate == _wants_plate():
		return
	if old != null:
		remove_child(old)
		old.queue_free()
	if _wants_plate():
		_add_plate()
	else:
		var bg:= MenuBackground.new()
		bg.name = "Background"
		add_child(bg)
		move_child(bg, 0)
	_sync_scrim()


func _skip_to_game() -> void:
	if "--stagedload" in OS.get_cmdline_user_args():
		Loading.show_screen("FIND THE NEEDLE", tr("PREPARING THE PILE"))
		Loading.enter_scene(GAME_SCENE)
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _apply_shot_language(code: String) -> void:
	TranslationServer.set_locale(code)
	BuildCatalog.invalidate()
	ItemDb.invalidate()
	TechTree.invalidate()


	UiFont.relocale()
