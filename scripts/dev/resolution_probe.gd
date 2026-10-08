class_name DevResolutionProbe
extends Node


var _fails:= 0
var _saved:= ""
var _had_file:= false
var _was_size:= Vector2i.ZERO
var _was_fullscreen:= false


var _real:= false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _skip(what: String) -> void:
	print("  --   %s (headless)" % what)


func run() -> void:
	print("--- resolution probe ---")
	_real = DisplayServer.get_name() != "headless"
	_borrow_settings()

	_check_list()
	_check_fits_the_screen()
	await _check_applies()
	await _check_fullscreen_defers()
	await _check_rapid_changes()
	await _check_file()
	_check_floor()
	_check_row()

	await _give_settings_back()
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_list() -> void:
	var sizes:= Cfg.window_sizes()
	_ok(not sizes.is_empty(), "there is at least one size to pick")


	var rising:= true
	for i in range(1, sizes.size()):
		rising = rising and sizes [i].x > sizes [i - 1].x
	_ok(rising, "the sizes come out smallest first, with no repeats")
	_ok(Cfg.window_size in sizes,
		"the size in force is in the list, so the row can show it")


func _check_fits_the_screen() -> void:
	if not _real:
		_skip("every offered size fits the screen")
		return
	var room:= DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen()).size
	var fits:= true
	for size: Vector2i in Cfg.window_sizes():
		if size == Cfg.window_size:
			continue
		fits = fits and size.x <= room.x and size.y <= room.y
	_ok(fits, "every offered size fits the screen (%d x %d)" % [room.x, room.y])


func _check_applies() -> void:
	Cfg.set_fullscreen(false)
	await Cfg.wait_for_display()
	var sizes:= Cfg.window_sizes()
	var want:= Vector2i.ZERO
	for size: Vector2i in sizes:
		if size != Cfg.window_size:
			want = size
			break
	if want == Vector2i.ZERO:
		_skip("picking a size resizes the window (only one size on offer)")
		return

	Cfg.set_window_size(want)
	await Cfg.wait_for_display()
	_ok(Cfg.window_size == want, "picking a size sticks")
	if not _real:
		_skip("...and the window is that size")
		return
	_ok(DisplayServer.window_get_size() == want,
		"...and the window is that size (%d x %d)" % [want.x, want.y])


	var room:= DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	var pos:= DisplayServer.window_get_position()
	_ok(pos.x >= room.position.x and pos.y >= room.position.y,
		"...and its top left corner is on the screen")


func _check_fullscreen_defers() -> void:
	var sizes:= Cfg.window_sizes()
	if sizes.size() < 2:
		_skip("a size set in fullscreen lands on the way out")
		return
	var windowed:= Cfg.window_size
	var other: Vector2i = sizes [0] if sizes [0] != windowed else sizes [1]

	Cfg.set_fullscreen(true)
	await Cfg.wait_for_display()
	Cfg.set_window_size(other)
	await Cfg.wait_for_display()
	_ok(Cfg.window_size == other, "a size can be set while fullscreen")
	if _real:
		_ok(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED,
			"...without dropping out of fullscreen")

	Cfg.set_fullscreen(false)
	await Cfg.wait_for_display()
	if _real:
		_ok(DisplayServer.window_get_size() == other,
			"...and it lands on the way back out")
	else:
		_skip("...and it lands on the way back out")


func _check_rapid_changes() -> void:
	var sizes:= Cfg.window_sizes()
	if sizes.size() < 2:
		_skip("rapid display requests keep only the final state")
		return
	var first: Vector2i = sizes [0]
	var last: Vector2i = sizes [-1]
	for i in 12:
		Cfg.set_fullscreen(i % 2 == 0)
		Cfg.set_window_size(first if i % 2 == 0 else last)
	Cfg.set_fullscreen(false)
	Cfg.set_window_size(first)
	await Cfg.wait_for_display()
	_ok(not Cfg.fullscreen and Cfg.window_size == first,
		"rapid display requests keep only the final setting")
	if _real:
		_ok(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
			"rapid display requests finish windowed")
		_ok(DisplayServer.window_get_size() == first,
			"rapid display requests finish at the final size")
	else:
		_skip("rapid display requests finish at the final window state")


func _check_file() -> void:
	var sizes:= Cfg.window_sizes()
	var want: Vector2i = sizes [0] if sizes [0] != Cfg.window_size else sizes [-1]
	Cfg.set_window_size(want)
	await Cfg.wait_for_display()

	var cf:= ConfigFile.new()
	_ok(cf.load(Cfg.SETTINGS_PATH) == OK, "the settings file is written")
	_ok(Vector2i(cf.get_value("display", "window_size", Vector2i.ZERO)) == want,
		"...with the size in it")


	Cfg.window_size = Vector2i.ZERO
	Cfg.load_settings()
	_ok(Cfg.window_size == want, "...and reading it back gives the same size")


func _check_floor() -> void:
	var cf:= ConfigFile.new()
	cf.load(Cfg.SETTINGS_PATH)
	cf.set_value("display", "window_size", Vector2i(1, 1))
	cf.save(Cfg.SETTINGS_PATH)
	Cfg.load_settings()
	_ok(Cfg.window_size.x >= 800 and Cfg.window_size.y >= 450,
		"a nonsense size in the file is floored at something readable")


func _check_row() -> void:
	var page:= OptionsPanel.new()

	add_child(page)
	var want:= "%d x %d" % [Cfg.window_size.x, Cfg.window_size.y]
	_ok(_says(page, want), "the DISPLAY page shows the size in force (%s)" % want)
	page.queue_free()


func _says(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _says(child, text):
			return true
	return false


func _borrow_settings() -> void:
	_was_size = Cfg.window_size
	_was_fullscreen = Cfg.fullscreen
	_had_file = FileAccess.file_exists(Cfg.SETTINGS_PATH)
	if _had_file:
		_saved = FileAccess.get_file_as_string(Cfg.SETTINGS_PATH)


func _give_settings_back() -> void:


	Cfg.window_size = _was_size
	Cfg.fullscreen = _was_fullscreen
	Cfg._apply_display()
	await Cfg.wait_for_display()
	if _had_file:
		var f:= FileAccess.open(Cfg.SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_saved)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cfg.SETTINGS_PATH))
	Cfg.load_settings()
