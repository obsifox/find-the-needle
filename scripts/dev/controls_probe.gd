class_name DevControlsProbe
extends Node


var panel: OptionsPanel

var _fails:= 0
var _saved:= ""
var _had_file:= false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("--- controls probe ---")
	_borrow_file()

	_check_rows()
	_check_dev_row()
	_check_rebind()
	_check_grouped()
	_check_conflict()
	_check_multi()
	_check_unbind()
	_check_file()
	_check_prompts()
	_check_chips()
	await _check_page()

	_give_file_back()
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_rows() -> void:
	var ids:= { }
	var missing:= PackedStringArray()
	var unnamed:= PackedStringArray()
	for row: Dictionary in InputSetup.ROWS:
		var id:= str(row ["actions"] [0])
		ids [id] = true
		for action: String in row ["actions"]:
			if not InputSetup.BINDINGS.has(action) and not InputSetup.MOUSE_BINDINGS.has(action):
				missing.append(action)
			elif not InputMap.has_action(action):
				missing.append(action)
		if InputSetup.label(id) == InputSetup.UNBOUND:
			unnamed.append(id)
	_ok(missing.is_empty(), "every listed action is registered (%s)"
		% ("all" if missing.is_empty() else ", ".join(missing)))
	_ok(unnamed.is_empty(), "every row ships with a key on it (%s)"
		% ("all" if unnamed.is_empty() else ", ".join(unnamed)))
	_ok(ids.size() == InputSetup.ROWS.size(), "no row is listed twice")


	_ok(not ids.has("free_mouse"), "escape is not on the page")
	_ok(not ids.has("debug_menu"), "nor is the debug menu")


func _check_dev_row() -> void:
	var was_debug:= Cfg.DEBUG
	var was_unlocked:= Cfg.debug_unlocked

	Cfg.DEBUG = true
	_ok(_row_offered("screenshot"), "the repro key is offered in a debug build")

	Cfg.DEBUG = false
	Cfg.debug_unlocked = false
	_ok(not _row_offered("screenshot"), "and is gone from a shipped one")
	_ok(InputSetup.offered_rows().size() == InputSetup.ROWS.size() - 1,
		"which is the only row that goes")

	Cfg.debug_unlocked = true
	_ok(_row_offered("screenshot"), "the unlock sequence hands it back")

	Cfg.DEBUG = was_debug
	Cfg.debug_unlocked = was_unlocked


func _row_offered(action: String) -> bool:
	for row: Dictionary in InputSetup.offered_rows():
		if str(row ["actions"] [0]) == action:
			return true
	return false


func _check_rebind() -> void:
	InputSetup.bind("jump", "key:G")
	_ok(InputSetup.label("jump") == "G", "a rebound row reports its new key")
	_ok(_action_has_key("jump", KEY_G), "and the map answers to it")
	_ok(not _action_has_key("jump", KEY_SPACE), "and no longer to the old one")
	_ok(not InputSetup.is_default("jump"), "and knows it is not the default")

	InputSetup.reset("jump")
	_ok(_action_has_key("jump", KEY_SPACE), "resetting one row puts its key back")
	_ok(InputSetup.is_default("jump"), "and it counts as shipped again")


func _check_grouped() -> void:
	InputSetup.bind("reset_view", "key:H")
	_ok(_action_has_key("reset_view", KEY_H) and _action_has_key("carry_rotate", KEY_H),
		"both halves of a shared key move together")
	_ok(not _action_has_key("carry_rotate", KEY_R), "and neither is left on the old one")
	InputSetup.reset("reset_view")
	_ok(_action_has_key("carry_rotate", KEY_R), "and both come back together")


func _check_conflict() -> void:
	var taken:= InputSetup.bind("jump", InputSetup.binding("interact"))
	_ok(taken.size() == 1 and taken [0] == "Interact",
		"taking a key in use names the row it came from")
	_ok(InputSetup.label("interact") == InputSetup.UNBOUND,
		"and that row is left showing nothing")
	_ok(not InputMap.action_has_event("interact", InputSetup.key_event(KEY_E)),
		"and answers to nothing")
	_ok(_action_has_key("jump", KEY_E), "while the row that took it works")

	InputSetup.reset("jump")
	InputSetup.reset("interact")
	_ok(_action_has_key("interact", KEY_E) and _action_has_key("jump", KEY_SPACE),
		"and resetting both puts each back")


func _check_multi() -> void:
	_ok(_action_has_key("build_closer", KEY_C)
		and InputMap.action_has_event("build_closer",
			InputSetup.mouse_event(MOUSE_BUTTON_WHEEL_DOWN)),
		"the build distance answers to its key and its wheel")
	_ok(InputSetup.label("build_closer") == "Wheel down / C",
		"and the settings page shows both")
	_ok(InputSetup.holder("key:C") == "build_closer",
		"a row's second binding is found by the conflict check")

	var taken:= InputSetup.bind("jump", "key:C")
	_ok(taken.size() == 1 and taken [0] == "Place closer",
		"taking it names the row it came from")
	_ok(InputSetup.label("build_closer") == "Wheel down",
		"which keeps the wheel it was not asked for")
	_ok(not _action_has_key("build_closer", KEY_C),
		"and stops answering to the key that went")
	InputSetup.reset_all()
	_ok(_action_has_key("build_closer", KEY_C),
		"and a reset hands the key back")


func _check_unbind() -> void:
	InputSetup.clear("screenshot")
	_ok(InputSetup.label("screenshot") == InputSetup.UNBOUND, "a row can be left empty")
	_ok(InputMap.action_get_events("screenshot").is_empty(),
		"and nothing at all triggers it")


	_ok(InputSetup.holder("key:F12") == "", "the key it gave up is free")
	InputSetup.reset("screenshot")
	_ok(_action_has_key("screenshot", KEY_F12), "and it comes back")


func _check_file() -> void:
	InputSetup.bind("crouch", "key:C")
	InputSetup.clear("quick_save")
	var cf:= ConfigFile.new()
	_ok(cf.load(InputSetup.OVERRIDE_PATH) == OK, "the changes were written")
	_ok(str(cf.get_value("bindings", "crouch", "")) == "key:C",
		"a rebound row is in the file by name, not by keycode")
	_ok(str(cf.get_value("bindings", "quick_save", "-")) == "",
		"an emptied row is written as empty rather than dropped")
	_ok(not cf.has_section_key("bindings", "jump"),
		"a row still on its default is not written at all")


	InputSetup._load()
	InputSetup.apply()
	_ok(_action_has_key("crouch", KEY_C), "and a fresh boot rebuilds the change")
	_ok(InputMap.action_get_events("quick_save").is_empty(),
		"including a row the player emptied")
	_ok(_action_has_key("move_forward", KEY_W), "while untouched rows are shipped defaults")

	InputSetup.reset_all()
	_ok(_action_has_key("crouch", KEY_CTRL) and _action_has_key("quick_save", KEY_F5),
		"reset puts the whole map back")
	_ok(not InputSetup.is_customised(), "and nothing counts as changed")


func _check_prompts() -> void:
	var bad:= PackedStringArray()
	for i in MissionBook.count():


		for field: String in ["title", "detail", "keys", "cue_alt", "cue_then"]:
			for name: String in _placeholders(str(MissionBook.step(i).get(field, ""))):


				if MissionBook._named(name) == InputSetup.UNBOUND:
					bad.append("%s.%s: {%s}" % [MissionBook.id_at(i), field, name])
	_ok(bad.is_empty(), "every key the tutorial names is a key that exists (%s)"
		% ("all" if bad.is_empty() else ", ".join(bad)))


	_ok(InputSetup.hint("primary") == "LMB" and InputSetup.hint("secondary") == "RMB",
		"the mouse buttons are named the way the strip has always named them")
	_ok(InputSetup.hint("carry_rotate") == InputSetup.hint("reset_view"),
		"asking about either half of a shared key gets the same answer")
	InputSetup.bind("hotbar_1", "key:Z")
	_ok(InputSetup.hint("hotbar_1") == "Z", "and a rebound key is what they would print")
	_ok(MissionBook.expand("press {hotbar_1}") == "press Z",
		"including inside the tutorial's own sentences")
	InputSetup.reset_all()


func _check_chips() -> void:
	_ok(ControlHints._words("press:primary") == "LMB",
		"a chip still knows the words for its button")
	_ok(ControlHints._art("press:primary").size() == 1,
		"...and has a picture of it to draw instead")
	_ok(ControlHints._words("hold:crouch") == "Hold Ctrl",
		"a hold says so in front of the button")


	_ok(ControlHints._words("roll:build_further,build_closer") == "Wheel / V / C",
		"the wheel is named once and its keys beside it")
	_ok(ControlHints._art("roll:build_further,build_closer").size() == 4,
		"...and all four are drawn, notches before keys")


	InputSetup.bind("throw_item", "key:Semicolon")
	_ok(ControlHints._art("press:throw_item").is_empty(),
		"a key with no art draws none")
	_ok(ControlHints._words("press:throw_item") == InputSetup.hint("throw_item"),
		"...and falls back to whatever that key is called")


	InputSetup.bind("build_closer", "key:Z")
	_ok(ControlHints._words("roll:build_further,build_closer") == "Wheel / V / Z",
		"a wheel split across a letter names what is left of both halves")
	InputSetup.reset_all()


func _placeholders(text: String) -> PackedStringArray:
	var out:= PackedStringArray()
	var rest:= text
	while true:
		var open:= rest.find("{")
		if open < 0:
			return out
		var close:= rest.find("}", open)
		if close < 0:
			return out
		out.append(rest.substr(open + 1, close - open - 1))
		rest = rest.substr(close + 1)
	return out


func _check_page() -> void:
	panel.call("_select_tab", 1)
	var caps: Dictionary = panel.get("_bind_buttons")
	_ok(caps.size() == InputSetup.offered_rows().size(),
		"the page draws a cap for every row")
	var cap: Button = caps.get("dismantle")
	_ok(cap != null and cap.text == "X", "showing the key that is on it")

	panel.call("_begin_capture", "dismantle")
	_ok(cap.text == "PRESS...", "clicking one asks for a key")
	await _press(KEY_J)
	_ok(InputSetup.label("dismantle") == "J", "and the next key lands on that row")
	_ok(cap.text == "J", "with the cap redrawn")
	_ok(_action_has_key("dismantle", KEY_J), "and the map following")


	panel.call("_begin_capture", "dismantle")
	await _press(KEY_ESCAPE)
	_ok(InputSetup.label("dismantle") == "J", "escape leaves the row as it was")

	panel.call("_begin_capture", "dismantle")
	await _press(KEY_BACKSPACE)
	_ok(InputSetup.label("dismantle") == InputSetup.UNBOUND, "backspace empties it")


	var idle:= InputEventKey.new()
	idle.physical_keycode = KEY_K
	idle.pressed = true
	panel.call("_input", idle)
	_ok(InputSetup.label("dismantle") == InputSetup.UNBOUND,
		"a key pressed with nothing listening changes nothing")

	panel.call("_end_capture")
	InputSetup.reset_all()
	_ok(caps ["dismantle"].text == "X", "and a reset redraws every cap on the page")


func _press(keycode: int) -> void:
	var ev:= InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true


	panel.call("_input", ev)
	await get_tree().process_frame


func _action_has_key(action: String, keycode: int) -> bool:
	return InputMap.action_has_event(action, InputSetup.key_event(keycode))


func _borrow_file() -> void:
	_had_file = FileAccess.file_exists(InputSetup.OVERRIDE_PATH)
	if _had_file:
		_saved = FileAccess.get_file_as_string(InputSetup.OVERRIDE_PATH)


func _give_file_back() -> void:
	if _had_file:
		var f:= FileAccess.open(InputSetup.OVERRIDE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_saved)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(InputSetup.OVERRIDE_PATH))
	InputSetup._load()
	InputSetup.apply()
