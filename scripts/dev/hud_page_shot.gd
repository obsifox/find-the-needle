class_name HudPageShot
extends Node


const OUT_DIR:= "res://captures"


const SETTLE_FRAMES:= 40

var menu: MainMenu


func run() -> void:
	if menu == null:
		push_error("[hudpageshot] no menu to walk")
		get_tree().quit(1)
		return

	var was:= [Cfg.crosshair_style, Cfg.crosshair_size]

	await _frames(SETTLE_FRAMES)


	var stale:= get_tree().root.find_child(
		CrashReportDialog.BTN_CLOSE, true, false) as Button
	if stale != null:
		if not await _press_button(stale, "the stale crash report"):
			return
	if not await _press("OPTIONS", "the options entry"):
		return
	if not await _press("HUD", "the HUD tab"):
		return
	await _shot("hud_page")


	Cfg.set_crosshair_size(2.5)
	for style: int in range(Cfg.CROSSHAIR_STYLE_NAMES.size()):
		Cfg.set_crosshair_style(style)
		await _shot("hud_crosshair_%s" % str(Cfg.CROSSHAIR_STYLE_NAMES [style]).to_lower())


	if not await _press("GRAPHICS", "the Graphics tab"):
		return
	await _shot("graphics_page")


	if not await _press("GAMEPLAY", "the Gameplay tab"):
		return
	await _shot("gameplay_page")


	var scroll:= _find_scroll(get_tree().root)
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames(6)
		await _shot("gameplay_page_foot")


	if not await _press("DISPLAY", "the Display tab"):
		return
	await _shot("display_page")
	scroll = _find_scroll(get_tree().root)
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames(6)
		await _shot("display_page_foot")


	Cfg.set_crosshair_style(int(was [0]))
	Cfg.set_crosshair_size(float(was [1]))
	get_tree().quit(0)


func _press(text: String, what: String) -> bool:
	return await _press_button(_find_button(get_tree().root, text), what)


func _press_button(b: Button, what: String) -> bool:
	if b == null:
		push_error("[hudpageshot] could not find %s" % what)
		get_tree().quit(1)
		return false
	var at:= b.get_global_rect().get_center()
	var window:= Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	if not window.has_point(at):
		push_error("[hudpageshot] %s is off the screen at %s" % [what, at])
		get_tree().quit(1)
		return false


	var hit:= get_viewport().get_final_transform() * at
	Input.warp_mouse(hit)
	for pressed: bool in [true, false]:
		var ev:= InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = hit
		ev.global_position = hit
		Input.parse_input_event(ev)
	await _frames(12)
	return true


func _find_scroll(node: Node) -> ScrollContainer:
	for child: Node in node.get_children():
		if child is ScrollContainer and (child as ScrollContainer).is_visible_in_tree():
			return child
		var found:= _find_scroll(child)
		if found != null:
			return found
	return null


func _find_button(node: Node, text: String) -> Button:
	for child: Node in node.get_children():
		if child is Button and (child as Button).text == text:
			return child
		var found:= _find_button(child, text)
		if found != null:
			return found
	return null


func _shot(shot_name: String) -> void:
	await _frames(6)
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [OUT_DIR, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[hudpageshot] %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
