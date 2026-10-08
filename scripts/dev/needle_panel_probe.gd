class_name DevNeedlePanelProbe
extends Node


const LOG:= "res://needle_panel_probe.log"

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	await _settle(8)

	await _case_the_chit_is_its_own_sheet()
	await _case_asleep_with_nothing_loose()
	await _case_a_duplicate_is_invisible()
	await _case_two_presses_send_it_back()
	await _case_a_dug_out_stack_sets_it_down()
	await _case_the_line_names_what_is_missing()
	_case_the_sheet_counts_the_case()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_the_chit_is_its_own_sheet() -> void:
	_look_at("chit")
	_check(_board().hovered_sheet(player.eye_position(), player.look_direction())
			== "chit",
		"standing at the chit, the board thinks the crosshair is elsewhere")
	_check(not _panel().is_open(), "the panel was up before anything pressed it")
	var pinned:= GameState.contract_pinned
	var hay:= GameState.hay_total

	_check(_press(), "E on the chit was dropped rather than answered")
	await _settle(2)
	_check(_panel().is_open(), "E on the chit did not open the panel")
	_check(GameState.contract_pinned == pinned,
		"E on the chit pinned the docket beside it")
	_check(is_equal_approx(GameState.hay_total, hay),
		"E on the chit tipped a new load in")


	_panel().set_open(false)
	await _settle(2)
	_check(not _panel().is_open(), "the panel would not close")


func _case_asleep_with_nothing_loose() -> void:
	_clear_the_yard()
	_panel().set_open(true)
	await _settle(2)
	var before:= GameState.needle_positions.size()
	_press_button()
	await _settle(2)
	_check(GameState.needle_positions.size() == before,
		"the sleeping button buried a needle: %d in the registry, was %d"
			% [GameState.needle_positions.size(), before])
	_check(_note_text() != "", "pressing the sleeping button said nothing at all")


	_press_button()
	await _settle(2)
	_check(GameState.needle_positions.size() == before,
		"a second press of the sleeping button buried one anyway")
	_panel().set_open(false)


func _case_a_duplicate_is_invisible() -> void:
	_clear_the_yard()
	var type:= int(NeedleTypes.pool(GameState.lot_tier) [0])
	GameState.discover(type, Vector3.ZERO)
	_drop_a_needle(type)
	await _settle(2)
	_check(_live().loose_undiscovered_types().is_empty(),
		"a needle of a type already in the case counted as loose")

	_panel().set_open(true)
	await _settle(2)
	var before:= GameState.needle_positions.size()
	_press_button()
	_press_button()
	await _settle(2)
	_check(GameState.needle_positions.size() == before,
		"the button reburied a duplicate the case already held")
	_panel().set_open(false)
	_clear_the_yard()


func _case_two_presses_send_it_back() -> void:
	_clear_the_yard()

	var type:= -1
	for t in NeedleTypes.pool(GameState.lot_tier):
		if not GameState.is_discovered(t):
			type = int(t)
			break
	_check(type >= 0, "every type of the lot was already in the case")
	if type < 0:
		return
	_drop_a_needle(type)
	await _settle(2)
	_check(_live().loose_undiscovered_types().size() == 1,
		"the yard says %d loose where one was put down"
			% _live().loose_undiscovered_types().size())

	_panel().set_open(true)
	await _settle(2)
	var buried:= GameState.needles_buried()
	var bodies:= _live().needles.size()


	_press_button()
	await _settle(2)
	_check(GameState.needles_buried() == buried,
		"one press was enough to bury it: the confirm is not holding")
	_check(_live().needles.size() == bodies,
		"one press already took the body out of the world")


	_press_button()
	await _settle(4)
	_check(GameState.needles_buried() == buried + 1,
		"after the confirm the ground holds %d, expected %d"
			% [GameState.needles_buried(), buried + 1])
	_check(_live().needles.size() == bodies - 1,
		"the body is still lying in the yard after being sent back")
	var last:= GameState.needle_positions.size() - 1
	_check(GameState.type_of(last) == type,
		"type %d went back into the stack where %d was sent"
			% [GameState.type_of(last), type])
	_check(_live().loose_undiscovered_types().is_empty(),
		"the yard still reports something loose after the return")
	_panel().set_open(false)


func _case_a_dug_out_stack_sets_it_down() -> void:
	_clear_the_yard()
	var type:= -1
	for t in NeedleTypes.pool(GameState.lot_tier):
		if not GameState.is_discovered(t):
			type = int(t)
			break
	_check(type >= 0, "every type of the lot was already in the case")
	if type < 0:
		return
	var field: HayField = world.field
	var kept:= field.heights.duplicate()
	field.heights.fill(0.0)
	_drop_a_needle(type)
	await _settle(2)

	_panel().set_open(true)
	await _settle(2)
	var registry:= GameState.needle_positions.size()
	var buried:= GameState.needles_buried()
	_press_button()
	_press_button()
	await _settle(4)
	field.heights = kept

	_check(GameState.needles_buried() == buried,
		"a dug out stack took a needle: the ground holds %d, was %d"
			% [GameState.needles_buried(), buried])
	_check(GameState.needle_positions.size() == registry,
		"setting the needle down registered a second one: %d, was %d"
			% [GameState.needle_positions.size(), registry])
	var loose:= _live().loose_undiscovered_types()
	_check(loose.size() == 1 and loose [0] == type,
		"after the return the yard has %s loose, expected one of type %d"
			% [loose, type])
	if _live().needles.size() == 1:
		var d: float = _live().needles [0].global_position.distance_to(_board().chit_point())
		_check(d < 2.5, "the needle was set down %.2f m from the board" % d)
	_check(_label_starting("The pile is gone") != "",
		"the panel did not say the needle went on the floor")
	_check(_label_starting("Back in the stack") == "",
		"the panel still says it went back into the stack")
	_panel().set_open(false)
	_clear_the_yard()


func _case_the_line_names_what_is_missing() -> void:
	_clear_the_yard()
	var pool:= NeedleTypes.pool(GameState.lot_tier)
	var missing: Array [int] = []
	var spare:= -1
	for t in pool:
		if GameState.is_discovered(t):
			spare = int(t)
		elif missing.size() < 2:
			missing.append(int(t))
	_check(missing.size() == 2 and spare >= 0,
		"the lot needs two missing kinds and one held one, has %s missing and spare %d"
			% [missing, spare])
	if missing.size() < 2 or spare < 0:
		return
	_drop_a_needle(missing [0])
	_drop_a_needle(missing [0])
	_drop_a_needle(missing [1])
	_drop_a_needle(spare)
	await _settle(2)

	_panel().set_open(true)
	await _settle(2)
	var doubled:= "%s (2)" % NeedleTypes.name_of(missing [0])
	var line:= _label_containing(doubled)
	_check(line != "", "no line on the panel names %s" % doubled)
	_check(line.begins_with("3 "), "the line counts wrong: %s" % line)
	_check(line.contains(NeedleTypes.name_of(missing [1])),
		"the line leaves out %s: %s" % [NeedleTypes.name_of(missing [1]), line])
	_check(not line.contains(NeedleTypes.name_of(spare)),
		"the line names %s, which the case already holds: %s"
			% [NeedleTypes.name_of(spare), line])
	_panel().set_open(false)

	_board()._refresh_chit()
	var chit: String = _board()._chit_loose.text
	_check(chit.begins_with("3 "), "the chit counts wrong: %s" % chit)
	_clear_the_yard()


func _case_the_sheet_counts_the_case() -> void:
	var pool:= NeedleTypes.pool(GameState.lot_tier)
	for t in pool:
		GameState.discover(int(t), Vector3.ZERO)
	_check(GameState.lot_missing().is_empty(),
		"lot_missing names types the case holds")
	_check(_board().can_order(),
		"the board refuses a load with every type of the lot in the case")


func _board() -> DeliveryBoard:
	return world.delivery_board


func _panel() -> NeedlePanel:
	return world.needle_panel


func _live() -> LiveStrandManager:
	return world.live


func _clear_the_yard() -> void:
	for b in _live().needles.duplicate():
		if is_instance_valid(b):
			_live().consume_needle(b)


func _drop_a_needle(type: int) -> void:
	var at:= Vector3(6.0, 0.6, 6.0)
	var index:= GameState.register_needle(at, null, type)
	GameState.needle_taken [index] = 1
	_live().reveal_needle(index, at)


func _press_button() -> void:
	var b: Button = _panel().find_child("ReturnButton", true, false)
	if b == null:
		_check(false, "the panel has no return button on it")
		return
	b.pressed.emit()


func _note_text() -> String:
	return _label_starting("No needles are lying loose")


func _label_starting(prefix: String) -> String:
	for child in _panel().find_children("*", "Label", true, false):
		var l:= child as Label
		if l != null and l.text.begins_with(prefix):
			return l.text
	return ""


func _label_containing(part: String) -> String:
	for child in _panel().find_children("*", "Label", true, false):
		var l:= child as Label
		if l != null and l.text.contains(part):
			return l.text
	return ""


func _look_at(sheet: String) -> void:
	var board:= _board()
	var at:= board.chit_point()
	if sheet == "contract":
		at = board.docket_point()
	elif sheet == "note":
		at = board.note_point()
	var out:= board.global_transform.basis * DeliveryBoard.face_normal()
	out.y = 0.0
	var stand:= at + out.normalized() * 1.4
	stand.y = 0.2
	player.global_position = stand
	var to_sheet:= at - player.eye_position()
	player.set_look(atan2(- to_sheet.x, - to_sheet.z),
		atan2(to_sheet.y, Vector2(to_sheet.x, to_sheet.z).length()))


func _press() -> bool:
	return _board().take_press(player.eye_position(), player.look_direction())


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _check(ok: bool, why: String) -> void:
	if not ok and why != "":
		_fails.append(why)


func _log(line: String) -> void:
	print("[needlepanel] " + line)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
