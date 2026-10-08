class_name DevUnlockProbe
extends Node


var world: Node

var _fails:= 0
var _skipped:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _skip(what: String) -> void:
	_skipped += 1
	print("  --   %s (needs Cfg.DEBUG false)" % what)


func run() -> void:
	print("--- debug unlock probe ---")
	print("[build] Cfg.DEBUG = %s, Cfg.debug_on() = %s"
		% [str(Cfg.DEBUG), str(Cfg.debug_on())])

	_check_sequence()
	_check_arrows_are_free()
	_check_matching()
	await _check_unlock()
	_check_arm_button()
	_check_buttons_latch()

	if _skipped > 0:
		print("\n[probe] %d check(s) skipped: this build has debug on at boot,"
			% _skipped)
		print("        so there is nothing here to unlock. Flip Cfg.DEBUG to")
		print("        false and run --cheat again before you ship.")
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_arm_button() -> void:
	var menu: DebugMenu = world.get("debug_menu") as DebugMenu
	if menu == null:
		_skip("the two-press guard on the crash buttons")
		return


	var fired: Array [int] = [0]
	var b:= menu._arm_button("Test", func() -> void: fired [0] += 1)
	var resting:= b.text

	b.pressed.emit()
	_ok(fired [0] == 0, "a crash button does nothing at all on the first press")
	_ok(b.text != resting, "and says on its own face that it is armed")

	b.pressed.emit()
	_ok(fired [0] == 1, "and does the thing on the second")

	b.free()


func _check_buttons_latch() -> void:
	var menu: DebugMenu = world.get("debug_menu") as DebugMenu
	if menu == null:
		_skip("a button in the menu takes the game off the leaderboards")
		return


	var was_tainted:= Profile.debug_tainted
	var was_used:= GameState.debug_used
	Profile.debug_tainted = false
	GameState.debug_used = false

	var b:= menu._button("Test", func() -> void: pass)
	_ok(not Profile.debug_tainted, "a menu that is only there takes nothing off the boards")
	b.pressed.emit()
	_ok(Profile.debug_tainted, "pressing a button in it takes the game off the leaderboards")
	_ok(GameState.debug_used, "and marks the run, so its save remembers")
	_ok(menu._board_note != null and menu._board_note.text.contains("was used"),
		"and the line under the heading says so")
	b.free()

	Profile.debug_tainted = was_tainted
	GameState.debug_used = was_used
	menu._refresh_board_note()


func _check_sequence() -> void:
	var want: Array [int] = [
		KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
		KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
	]
	_ok(DebugUnlock.SEQUENCE == want,
		"the sequence is up up down down left right left right left right")


func _check_arrows_are_free() -> void:
	var arrows: Array [int] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	var clash:= ""
	for action: String in InputSetup.BINDINGS:
		for code: int in InputSetup.BINDINGS [action]:
			if code in arrows:
				clash = action
	_ok(clash == "", "no game action binds an arrow key" if clash == ""
		else "no game action binds an arrow key -- \"%s\" does" % clash)


func _feed(codes: Array) -> bool:
	var node:= DebugUnlock.new()
	var opened:= false
	for code: int in codes:
		opened = node.feed(code)
	node.free()
	return opened


func _check_matching() -> void:
	_ok(_feed(DebugUnlock.SEQUENCE), "the sequence opens it")


	var short:= DebugUnlock.SEQUENCE.slice(0, DebugUnlock.SEQUENCE.size() - 1)
	_ok(not _feed(short), "nine of the ten keys does not")
	var wrong:= short.duplicate()
	wrong.append(KEY_LEFT)
	_ok(not _feed(wrong), "ten keys with the last one wrong does not")


	var fumbled: Array [int] = [KEY_UP]
	fumbled.append_array(DebugUnlock.SEQUENCE)
	_ok(_feed(fumbled), "a false start still opens it -- up, then the sequence")


	var junk:= DebugUnlock.SEQUENCE.slice(0, 4)
	junk.append(KEY_UP)
	junk.append_array(DebugUnlock.SEQUENCE)
	_ok(_feed(junk), "and so does junk, then the sequence")


	var twice:= DebugUnlock.SEQUENCE.duplicate()
	twice.append(KEY_RIGHT)
	_ok(not _feed(twice), "one more key after it opens does not open it again")

	var node:= DebugUnlock.new()
	node.feed(KEY_UP)
	node.feed(KEY_UP)
	_ok(node.progress() == 2, "it counts the keys it has been given")
	node.feed(KEY_RIGHT)
	_ok(node.progress() == 0, "and forgets them on a wrong one")
	node.free()


func _check_unlock() -> void:
	if Cfg.debug_on():
		_skip("no debug menu before the sequence")
		_skip("F1 is not bound before the sequence")
		_skip("the sequence builds the menu")
		return

	_ok(world.get("debug_menu") == null, "no debug menu before the sequence")
	_ok(not InputMap.has_action("debug_menu"),
		"F1 is not bound before the sequence")
	_ok(world.get_node_or_null("DebugUnlock") != null,
		"something is listening for it")

	for code: int in DebugUnlock.SEQUENCE:
		var down:= InputEventKey.new()
		down.keycode = code
		down.pressed = true
		Input.parse_input_event(down)


		var up:= InputEventKey.new()
		up.keycode = code
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().process_frame

	await get_tree().process_frame

	_ok(Cfg.debug_unlocked, "the sequence sets the flag")
	_ok(Cfg.debug_on(), "and debug is on")
	_ok(InputMap.has_action("debug_menu"), "F1 is bound")
	var menu: Variant = world.get("debug_menu")
	_ok(menu != null, "the sequence builds the menu")
	if menu == null:
		return
	_ok(menu.wallhack != null, "with the wallhack wired to it")
	var pause: Variant = world.get("pause_menu")
	_ok(pause != null and pause.debug_menu == menu,
		"and Escape knowing about it")
