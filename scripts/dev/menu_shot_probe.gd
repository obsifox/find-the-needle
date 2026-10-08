class_name MenuShotProbe
extends Node


const OUT_DIR:= "res://captures"
const MENU_SCENE:= "res://scenes/main_menu.tscn"
const SETTLE_FRAMES:= 45


const WORLD_FRAMES:= 1800

var menu: MainMenu


const SCRATCH_DIR:= "user://probe_saves/menushot"


const PAUSE_NAME:= "Named mid run"


const SEEDED:= 8


var _scratch:= SEEDED


static var _already_ran:= false


func _ready() -> void:
	if _already_ran:
		queue_free()
		return
	_already_ran = true
	call_deferred("_detach")


func _detach() -> void:

	var root:= get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_use_scratch_dir()
	await _shot("menu_01_title", SETTLE_FRAMES)
	await _check_root_prompts()
	menu.call("_show_page", MainMenu.Page.LOAD_GAME)
	await _shot("menu_02_load", 6)

	menu.call("_show_page", MainMenu.Page.MAP_PICK)
	await _shot("menu_02b_map", 6)
	menu.call("_show_page", MainMenu.Page.OPTIONS)
	await _shot("menu_04_options", 6)


	var controls:= _find_button(menu, "CONTROLS")
	_check(controls != null, "the settings card offers a page of keys")
	if controls != null:
		_click(controls.get_global_rect().get_center())
		await _shot("menu_04b_controls", 6)


	var display:= _find_button(menu, "DISPLAY")
	_check(display != null, "the settings card offers a page of display options")
	if display != null:
		_click(display.get_global_rect().get_center())
		await _shot("menu_04c_display", 6)
	menu.call("_show_page", MainMenu.Page.NEW_GAME)
	await _shot("menu_03_new", 6)
	await _walk_into_a_new_run()
	await _walk_back_to_the_title()


	await _close_crash_card()
	await _new_game_row_follows()
	await _rename_the_run()
	await _lock_the_run()
	await _hover_opens_a_card()
	get_tree().quit()


func _use_scratch_dir() -> void:
	var dir:= SaveManager.use_scratch_dir(SCRATCH_DIR)
	var path:= SaveManager.slot_path(_scratch)
	if dir != SCRATCH_DIR or not path.begins_with(SCRATCH_DIR):
		push_error("[menushot] the scratch redirect did not take (slot %d is %s); refusing to run"
			% [_scratch + 1, path])
		get_tree().quit(1)
		return


	for i in SaveManager.SLOT_COUNT:
		for p: String in [SaveManager.slot_path(i), SaveManager.backup_path(i)]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for i in SEEDED:
		SaveManager.current_slot = i
		SaveManager.current_name = "Probe run %d" % (i + 1)
		SaveManager.current_locked = false
		SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY)
	SaveManager.current_name = ""
	print("[menushot] playing in %s. No slot is read or written." % dir)


func _close_crash_card() -> void:
	for dialog in get_tree().root.find_children("*", "CrashReportDialog", true, false):
		var close:= _find_button(dialog, "CLOSE")
		if close != null:
			_click(close.get_global_rect().get_center())
			await get_tree().process_frame
			await get_tree().process_frame


func _check_root_prompts() -> void:
	await _close_crash_card()


	var multiplayer:= _find_button(menu, "MULTIPLAYER")
	_check(multiplayer == null or not multiplayer.is_visible_in_tree(),
		"the title screen does not offer multiplayer")

	var leaderboards:= _find_button(menu, "LEADERBOARDS")
	_check(leaderboards != null, "the title screen offers leaderboards")
	if leaderboards != null:
		_click(leaderboards.get_global_rect().get_center())
		await _shot("menu_03_leaderboards_notice", 4)


		var close_leaderboards:= _find_button(menu, "GOT IT")
		if close_leaderboards == null:
			close_leaderboards = _find_button(menu, "BACK")
		_check(close_leaderboards != null, "the leaderboards can be left again")
		if close_leaderboards != null:
			_click(close_leaderboards.get_global_rect().get_center())
			await get_tree().process_frame

	var new_game:= _find_button(menu, "NEW GAME")
	_check(new_game != null, "the title screen offers a new game")
	if new_game != null:
		_click(new_game.get_global_rect().get_center())
		await _shot("menu_03_demo_notice", 4)
		var cancel_demo:= _find_button(menu, "NOT YET")
		_check(cancel_demo != null, "the demo notice can be declined")
		if cancel_demo != null:
			_click(cancel_demo.get_global_rect().get_center())
	await get_tree().process_frame


func _await_scene(path: String) -> void:
	for i in WORLD_FRAMES:
		await get_tree().process_frame
		var scene:= get_tree().current_scene
		if scene == null or scene.scene_file_path != path:
			continue


		if Loading.is_active():
			continue
		for _settle in SETTLE_FRAMES:
			await get_tree().process_frame
		return
	push_error("[menushot] %s never came up" % path)


func _shot(shot_name: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [OUT_DIR, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[menushot] %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _walk_into_a_new_run() -> void:
	SaveManager.delete_save(_scratch)
	menu.call("_refresh_slots")
	await get_tree().process_frame

	var ok:= _check(SaveManager.next_free_slot() == _scratch,
		"a new run goes in the slot after the last one (slot %d)" % (_scratch + 1))
	var row: Button = menu.get("_slot_rows") [_scratch]
	ok = _check(_last_row(menu) == row and row.text == tr("NEW GAME"),
		"the last row on NEW GAME says NEW GAME") and ok
	await _reveal(menu, _scratch)
	_click(row.get_global_rect().get_center())
	await _await_scene(MainMenu.GAME_SCENE)

	var world:= get_tree().current_scene


	var intro: Node = world.get("intro") if world != null else null
	if intro != null and bool(intro.call("is_running")):
		intro.call("abort")
		await get_tree().process_frame
		await get_tree().process_frame

	ok = _check(world != null and world.get("field") != null, "the world scene loaded") and ok
	ok = _check(SaveManager.current_slot == _scratch,
		"slot %d is the one being played" % (_scratch + 1)) and ok
	ok = _check(GameState.hay_dug == 0.0, "the run started fresh") and ok


	var body: CharacterBody3D = world.get("player") if world != null else null
	ok = _check(body != null and body.is_on_floor(), "physics is running again") and ok
	ok = _check(world != null and bool(world.call("save_now")), "it saves") and ok
	ok = _check(not SaveManager.slot_summary(_scratch).is_empty(),
		"and the menu can read what it wrote") and ok
	_pass("run", ok)


func _walk_back_to_the_title() -> void:
	var world:= get_tree().current_scene
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	var pause: PauseMenu = world.get("pause_menu")
	var ok:= _check(pause != null and pause.is_open(), "escape opens the pause menu")
	await _shot("pause_01_menu", 4)
	await _name_the_run_from_the_pause_menu(pause)


	var options_button:= _find_button(pause, "OPTIONS") if pause != null else null
	ok = _check(options_button != null, "the pause menu offers options") and ok
	if options_button != null:
		_click(options_button.get_global_rect().get_center())
		await _shot("pause_02_options", 6)
		_key(KEY_ESCAPE)
		await get_tree().process_frame
		await get_tree().process_frame
		ok = _check(pause.is_open(), "escape leaves the settings without closing the menu") and ok


	var respawn_button:= _find_button(pause, "RESPAWN") if pause != null else null
	ok = _check(respawn_button != null, "the pause menu offers a respawn") and ok
	var body: CharacterBody3D = world.get("player") if world != null else null
	if respawn_button != null and body != null:
		var home: Vector3 = body.get("respawn_fallback")
		body.global_position = home + Vector3(0.0, 3.0, 0.0)
		ok = _check(body.global_position.distance_to(home) > 1.0,
			"the player can be moved off the spawn point") and ok
		_click(respawn_button.get_global_rect().get_center())
		await get_tree().process_frame
		ok = _check(not pause.is_open(), "respawning closes the menu") and ok
		ok = _check(body.global_position.distance_to(home) < 0.5,
			"and puts the player back on the spawn point") and ok

		_key(KEY_ESCAPE)
		await get_tree().process_frame
		await get_tree().process_frame
		ok = _check(pause.is_open(), "and the menu opens again after it") and ok

	var exit_button:= _find_button(pause, "SAVE AND EXIT TO TITLE") if pause != null else null
	ok = _check(exit_button != null, "the pause menu offers a way out") and ok
	if exit_button != null:
		_click(exit_button.get_global_rect().get_center())
	await _await_scene(MENU_SCENE)

	var scene:= get_tree().current_scene
	ok = _check(scene != null and scene.scene_file_path == MENU_SCENE,
		"and lands back on the title screen") and ok
	ok = _check(SaveManager.has_save(_scratch), "having saved on the way out") and ok


	_pass("exit", ok)


func _name_the_run_from_the_pause_menu(pause: PauseMenu) -> void:
	var ok:= _check(pause != null and pause.is_open(), "the pause menu is up")
	if pause == null or not pause.is_open():
		_pass("pausename", ok)
		return
	var line: Button = pause.get("_slot_btn")
	var edit: LineEdit = pause.get("_slot_edit")
	ok = _check(line != null and line.visible, "the slot line is under the title") and ok
	ok = _check(edit != null and not edit.visible, "with no name box over it yet") and ok
	if line == null or edit == null:
		_pass("pausename", ok)
		return
	ok = _check(line.text.find(str(_scratch + 1)) >= 0,
		"and it says which slot the run is in") and ok

	_click(line.get_global_rect().get_center())
	await get_tree().process_frame
	ok = _check(edit.visible and not line.visible,
		"clicking the line puts a name box in its place") and ok
	ok = _check(edit.has_focus(), "...holding the keyboard, so typing goes into it") and ok
	await _shot("pause_01b_naming", 4)

	_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	ok = _check(not edit.visible and line.visible, "escape puts the slot line back") and ok
	ok = _check(pause.is_open(), "...without closing the menu behind it") and ok

	_click(line.get_global_rect().get_center())
	await get_tree().process_frame
	edit.text = PAUSE_NAME
	edit.text_submitted.emit(PAUSE_NAME)
	await get_tree().process_frame
	ok = _check(SaveManager.current_name == PAUSE_NAME,
		"Enter names the run the session is playing") and ok
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")) == PAUSE_NAME,
		"...and the save on disk carries it") and ok
	ok = _check(SaveManager.slot_summary(_scratch).get("readable", false),
		"...without eating the run it belongs to") and ok
	ok = _check(line.visible and line.text.find(PAUSE_NAME) >= 0,
		"...and the slot line reads it back") and ok
	await _shot("pause_01c_named", 4)


	SaveManager.set_locked(_scratch, true)
	_click(line.get_global_rect().get_center())
	await get_tree().process_frame
	ok = _check(not edit.visible and line.visible,
		"a locked run refuses to open the name box") and ok
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")) == PAUSE_NAME,
		"...and keeps the name it had") and ok

	SaveManager.set_locked(_scratch, false)
	_pass("pausename", ok)


func _new_game_row_follows() -> void:
	var title:= _current_menu()
	var ok:= _check(title != null, "the title screen is up")
	if title == null:
		_pass("newrow", ok)
		return
	title.call("_show_page", MainMenu.Page.NEW_GAME)
	await get_tree().process_frame
	var rows: Array = title.get("_slot_rows")
	var fresh:= SaveManager.next_free_slot()
	ok = _check(fresh == _scratch + 1 and fresh < rows.size(),
		"the NEW GAME row moved on to slot %d" % (_scratch + 2)) and ok
	if fresh == _scratch + 1 and fresh < rows.size():
		var fresh_row: Button = rows [fresh]
		ok = _check(_last_row(title) == fresh_row and fresh_row.text == tr("NEW GAME"),
			"...and is still the last row") and ok
	var played: Button = rows [_scratch]
	ok = _check(played.visible and played.text != tr("NEW GAME"),
		"the run just played is listed above it") and ok

	title.call("_show_page", MainMenu.Page.LOAD_GAME)
	await get_tree().process_frame
	ok = _check(_last_row(title) == played, "CONTINUE ends on the last run") and ok
	var offered:= false
	for r: Button in rows:
		offered = offered or (r.visible and r.text == tr("NEW GAME"))
	ok = _check(not offered, "...and offers no NEW GAME row") and ok
	_pass("newrow", ok)


func _hover_opens_a_card() -> void:
	var title:= _current_menu()
	var ok:= _check(title != null, "the title screen is up")
	if title == null:
		_pass("hovercard", ok)
		return
	var slot:= 0
	_write_card_fixture(slot)
	title.call("_show_page", MainMenu.Page.LOAD_GAME)
	await get_tree().process_frame

	var rows: Array = title.get("_slot_rows")
	var row: Button = rows [slot]
	title.call("_reveal_slot", slot)
	await get_tree().process_frame


	Input.warp_mouse(row.get_global_rect().get_center())
	var move:= InputEventMouseMotion.new()
	move.position = row.get_global_rect().get_center()
	move.global_position = move.position
	Input.parse_input_event(move)
	await get_tree().process_frame
	await get_tree().process_frame

	var card: PanelContainer = title.get("_slot_card")
	ok = _check(card != null and card.visible, "hovering a run opens its card") and ok
	if card == null or not card.visible:
		_pass("hovercard", ok)
		return
	ok = _check(not card.get_global_rect().intersects(row.get_global_rect()),
		"...beside the row rather than over it") and ok
	ok = _check(title.get_rect().encloses(card.get_global_rect()),
		"...and inside the window") and ok

	var said:= _card_text(title)


	var hay_line:= tr("%s left of %s") % [title.call("_short_count", 317000000.0),
		title.call("_short_count", 480000000.0)]
	for want: String in ["Hover fixture", Leaderboard.clock_text(15120.0), hay_line,
			tr("%d%% dug") % 34, tr_n("%d structure", "%d structures", 7) % 7,
			tr("%d m") % 40, "%s: %s" % [tr("Upgrades"), "2"]]:
		ok = _check(said.find(want) >= 0, "the card says '%s'" % want) and ok
	await _shot("menu_08_card", 4)


	Input.warp_mouse(Vector2(10.0, 10.0))
	var away:= InputEventMouseMotion.new()
	away.position = Vector2(10.0, 10.0)
	away.global_position = away.position
	Input.parse_input_event(away)
	await get_tree().process_frame
	await get_tree().process_frame
	ok = _check(not card.visible, "the card closes when the pointer leaves the row") and ok
	_pass("hovercard", ok)


func _card_text(title: MainMenu) -> String:
	var out:= str((title.get("_card_title") as Label).text)
	var keys: Array = title.get("_card_keys")
	var values: Array = title.get("_card_values")
	for i in keys.size():
		var key: Label = keys [i]
		if key.visible:
			out += "  %s: %s" % [key.text, (values [i] as Label).text]
	return out


func _write_card_fixture(slot: int) -> void:
	GameState.money = 1234567.0
	GameState.money_earned = 8400000.0
	GameState.needles_found = 12
	GameState.hay_initial = 480000000.0
	GameState.hay_total = 317000000.0
	GameState.hay_dug = 163000000.0
	GameState.run_secs = 15120.0


	var ranks:= { TechTree.ROOT: 1 }
	for id: String in TechTree.ids():
		if id != TechTree.ROOT and ranks.size() < 3:
			ranks [id] = 1
	Tech.from_dict({ "ranks": ranks })

	var yard: Array = []

	for i in 3:
		yard.append({ "type": "conveyor", "line": 7,
			"a": Vector3(0.0, 0.0, i * 10.0), "b": Vector3(0.0, 0.0, i * 10.0 + 10.0) })

	for i in 2:
		yard.append({ "type": "conveyor",
			"a": Vector3(i * 6.0, 0.0, 0.0), "b": Vector3(i * 6.0, 0.0, 5.0) })


	yard.append({ "type": "hay_compressor", "position": Vector3(4.0, 0.0, 4.0), "yaw": 0.0 })
	yard.append({ "type": "haystack_scanner", "position": Vector3(8.0, 0.0, 4.0), "yaw": 0.0 })
	yard.append({ "type": "hay_silo", "position": Vector3(12.0, 0.0, 4.0), "yaw": 0.0 })
	yard.append({ "type": "work_lamp", "position": Vector3(16.0, 0.0, 4.0), "yaw": 0.0 })

	SaveManager.current_slot = slot
	SaveManager.current_name = "Hover fixture"
	SaveManager.current_locked = false
	SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY, yard)


func _last_row(title: MainMenu) -> Button:
	var list: VBoxContainer = title.get("_slot_list")
	if list == null:
		return null
	var last: Button = null
	for child in list.get_children():
		if child is Button and (child as Button).visible:
			last = child as Button
	return last


func _rename_the_run() -> void:


	if not SaveManager.has_save(_scratch):
		SaveManager.current_slot = _scratch
		SaveManager.current_name = ""
		SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY)
	var ok:= _check(SaveManager.has_save(_scratch), "there is a run to name")
	ok = _check(SaveManager.rename_save(_scratch, "Second try"),
		"the slot takes a name") and ok
	var s:= SaveManager.slot_summary(_scratch)
	ok = _check(str(s.get("name", "")) == "Second try", "...and reads it back") and ok
	ok = _check(s.get("readable", false) and float(s.get("money", -1.0)) >= 0.0,
		"...without eating the run it belongs to") and ok


	SaveManager.rename_save(_scratch, "two\nlines")
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")) == "two lines",
		"a newline cannot break the slot line in two") and ok
	SaveManager.rename_save(_scratch, "x".repeat(SaveManager.NAME_MAX_LEN + 20))
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")).length()
			== SaveManager.NAME_MAX_LEN,
		"...and a name longer than the row is cut to fit") and ok
	SaveManager.rename_save(_scratch, "   ")
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")) == "",
		"a blank name clears it") and ok


	var free_slot:= -1
	for i in SaveManager.SLOT_COUNT:
		if not SaveManager.has_save(i):
			free_slot = i
			break
	if free_slot >= 0:
		ok = _check(not SaveManager.rename_save(free_slot, "nothing here"),
			"an empty slot refuses a name") and ok
		ok = _check(not SaveManager.has_save(free_slot),
			"...and is still empty afterwards") and ok


	SaveManager.rename_save(_scratch, "Needle hunt")
	var title:= _current_menu()
	ok = _check(title != null, "the title screen came back") and ok
	if title != null:
		title.call("_show_page", MainMenu.Page.LOAD_GAME)
		await _reveal(title, _scratch)
		var row: Button = title.get("_slot_rows") [_scratch]
		ok = _check(row != null and row.text == "Needle hunt",
			"the slot row is labelled with the name, not its number") and ok
		var rename_button: Button = row.get_node_or_null("Rename") if row != null else null
		ok = _check(rename_button != null and rename_button.visible,
			"and offers a way to change it") and ok
		await _shot("menu_05_named", 6)


		if rename_button != null:
			_click(rename_button.get_global_rect().get_center())
			await get_tree().process_frame
			var edit: LineEdit = row.get_node_or_null("NameEdit")
			ok = _check(edit != null and edit.visible,
				"clicking RENAME opens an editor on the row") and ok
			ok = _check(edit != null and edit.text == "Needle hunt",
				"...seeded with the name that is already there") and ok
			ok = _check(edit != null and edit.has_focus(),
				"...and holding the keyboard, so typing goes into it") and ok
			await _shot("menu_06_renaming", 4)

			if edit != null:
				edit.text = "Third attempt"
				edit.text_submitted.emit("Third attempt")
			await get_tree().process_frame
			ok = _check(str(SaveManager.slot_summary(_scratch).get("name", ""))
					== "Third attempt", "and Return writes it to the save") and ok
			ok = _check(edit == null or not edit.visible,
				"...and shuts the editor again") and ok
			ok = _check(row.text == "Third attempt",
				"...leaving the new name on the row") and ok
		SaveManager.delete_save(_scratch)
		title.call("_refresh_slots")
		await get_tree().process_frame
		ok = _check(row != null and not row.visible,
			"an erased slot drops off the CONTINUE list") and ok

	SaveManager.delete_save(_scratch)
	_pass("rename", ok)


func _reveal(title: MainMenu, slot: int) -> void:


	await get_tree().process_frame
	if title != null:
		title.call("_reveal_slot", slot)
	await get_tree().process_frame
	await get_tree().process_frame


func _lock_the_run() -> void:


	SaveManager.current_slot = _scratch
	SaveManager.current_name = ""
	SaveManager.current_locked = false
	SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY)
	SaveManager.rename_save(_scratch, "Keep this one")
	var ok:= _check(SaveManager.has_save(_scratch), "there is a run to lock")
	ok = _check(not SaveManager.is_locked(_scratch), "...and it starts unlocked") and ok
	ok = _check(SaveManager.set_locked(_scratch, true), "the slot takes a lock") and ok
	ok = _check(SaveManager.is_locked(_scratch), "...and reads it back") and ok
	var s:= SaveManager.slot_summary(_scratch)
	ok = _check(s.get("readable", false) and str(s.get("name", "")) == "Keep this one",
		"...without eating the run it belongs to") and ok
	ok = _check(s.get("locked", false), "...and the menu is told about it") and ok


	ok = _check(not SaveManager.delete_save(_scratch), "a locked slot refuses to be erased") and ok
	ok = _check(SaveManager.has_save(_scratch), "...and the save is still there") and ok
	ok = _check(not SaveManager.rename_save(_scratch, "Gone"),
		"a locked slot refuses a new name") and ok
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")) == "Keep this one",
		"...and keeps the one it had") and ok
	var was_playing:= SaveManager.current_slot
	ok = _check(not SaveManager.begin_new_game(_scratch),
		"a locked slot refuses to be started over") and ok
	ok = _check(SaveManager.current_slot == was_playing,
		"...and the refusal did not move the session onto it") and ok
	ok = _check(SaveManager.has_save(_scratch), "...and the save is STILL there") and ok


	SaveManager.begin_load(_scratch)
	ok = _check(SaveManager.current_locked,
		"loading a locked run carries the lock onto the session") and ok
	ok = _check(SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY),
		"...so the run saves over itself as usual") and ok
	ok = _check(SaveManager.is_locked(_scratch), "...without shaking the lock off") and ok
	ok = _check(str(SaveManager.slot_summary(_scratch).get("name", "")) == "Keep this one",
		"...or the name with it") and ok


	var title:= _current_menu()
	ok = _check(title != null, "the title screen is up") and ok
	if title == null:
		SaveManager.set_locked(_scratch, false)
		_pass("lock", ok)
		return
	title.call("_show_page", MainMenu.Page.NEW_GAME)
	await _reveal(title, _scratch)
	var row: Button = title.get("_slot_rows") [_scratch]
	var box: CheckBox = row.get_node_or_null("Lock") if row != null else null
	var kill: Button = row.get_node_or_null("Erase") if row != null else null
	var rename: Button = row.get_node_or_null("Rename") if row != null else null
	ok = _check(box != null and box.visible and box.button_pressed,
		"the row shows a ticked box") and ok
	ok = _check(kill != null and kill.disabled, "ERASE is greyed out") and ok
	ok = _check(rename != null and rename.disabled, "RENAME is greyed out") and ok
	ok = _check(row != null and row.disabled,
		"and the row itself will not start a new run over the top") and ok
	await _shot("menu_07_locked", 6)


	if box != null:
		_click(box.get_global_rect().get_center())
		await get_tree().process_frame
		ok = _check(not SaveManager.is_locked(_scratch),
			"clicking the box unlocks the save") and ok
		ok = _check(kill != null and not kill.disabled,
			"...which hands ERASE back") and ok


	SaveManager.set_locked(_scratch, false)
	ok = _check(SaveManager.delete_save(_scratch),
		"and an unlocked slot erases again") and ok
	_pass("lock", ok)


func _current_menu() -> MainMenu:
	var scene:= get_tree().current_scene
	if scene == null:
		return null
	if scene is MainMenu:
		return scene as MainMenu
	for child in scene.find_children("*", "MainMenu", true, false):
		return child as MainMenu
	return null


func _pass(stage: String, ok: bool) -> void:
	print("[menushot] %s: %s" % [stage, "PASS" if ok else "FAIL"])


func _find_button(node: Node, msgid: String) -> Button:
	var words:= tr(msgid)
	for child in node.get_children():
		if child is Button and (child as Button).text.begins_with(words):
			return child
		var found:= _find_button(child, msgid)
		if found != null:
			return found
	return null


func _check(condition: bool, what: String) -> bool:
	if not condition:
		push_error("[menushot] FAILED: %s" % what)
		print("[menushot]   no: %s" % what)
	return condition


func _click(at: Vector2) -> void:
	Input.warp_mouse(at)
	for pressed in [true, false]:
		var ev:= InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev:= InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
