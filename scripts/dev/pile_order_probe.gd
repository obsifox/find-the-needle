class_name DevPileOrderProbe
extends Node


const LOG:= "res://pile_order_probe.log"

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

	_case_quiet_on_a_full_pile()
	_case_the_rare_ones_are_deeper()
	await _case_the_two_sheets()
	await _case_hay_does_not_open_it()
	await _case_the_case_is_the_gate()
	_case_a_lost_needle_comes_back()
	await _case_the_run_survives()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_quiet_on_a_full_pile() -> void:
	_check(not _board().can_order(),
		"the note is offering on a full pile with every needle still buried")

	_check(GameState.needles_buried() == GameState.pile_needle_types().size(),
		"pile opened with %d needles buried, expected %d"
			% [GameState.needles_buried(), GameState.pile_needle_types().size()])


func _case_the_two_sheets() -> void:
	_look_at("contract")
	_check(_board().hovered_sheet(player.eye_position(), player.look_direction())
			== "contract",
		"standing at the docket, the board thinks the crosshair is elsewhere")
	_check(not GameState.contract_pinned, "the docket starts out pinned")
	_check(_press(), "E on the contract docket did nothing")
	await _settle(2)
	_check(GameState.contract_pinned, "E on the docket did not pin it")
	_check(world.contracts.visible, "the docket was pinned and no card came up")

	_check(_press(), "E on the pinned docket did nothing")
	await _settle(2)
	_check(not GameState.contract_pinned, "a second press did not take it down")
	_check(not world.contracts.visible, "the card stayed up after being unpinned")


	GameState.contract_pinned = true
	var d:= GameState.to_dict()
	GameState.contract_pinned = false
	GameState.from_dict(d)
	_check(GameState.contract_pinned, "the pin did not survive a save and load")
	GameState.contract_pinned = false
	GameState.contract_pin_changed.emit(false)

	_look_at("note")
	_check(_board().hovered_sheet(player.eye_position(), player.look_direction())
			== "note",
		"standing at the note, the board thinks the crosshair is elsewhere")


	var hay:= GameState.hay_total
	var panel: LoadPanel = world.load_panel
	_check(_press(), "E on a waiting note was dropped rather than answered")
	await _settle(2)
	_check(panel.is_open(), "E on a waiting note did not open the order panel")
	panel.press_order()
	await _settle(2)
	_check(panel.is_open(),
		"ordering on a waiting note closed the panel as if the order had gone")
	_check(is_equal_approx(GameState.hay_total, hay),
		"ordering on a waiting note tipped a load in regardless")
	panel.set_open(false)


func _case_the_rare_ones_are_deeper() -> void:
	var field: HayField = world.field
	if field == null:
		_check(false, "no field to measure needle cover against")
		return
	var deep_sum:= 0.0
	var deep_n:= 0
	var rest_sum:= 0.0
	var rest_n:= 0
	for i in GameState.needle_positions.size():
		var p: Vector3 = GameState.needle_positions [i]
		var cover: float = field.height_at(p.x, p.z) - p.y
		if NeedleTypes.is_deep(GameState.type_of(i)):
			deep_sum += cover
			deep_n += 1
		else:
			rest_sum += cover
			rest_n += 1
	_check(deep_n > 0, "not one of the lot's deep types was seeded")
	if deep_n == 0 or rest_n == 0:
		return
	var deep: float = deep_sum / float(deep_n)
	var rest: float = rest_sum / float(rest_n)
	_check(deep > rest,
		"the rare types are not buried deeper: %.2f m of cover against %.2f m"
			% [deep, rest])
	_log("  deep types under %.2f m of hay, the rest under %.2f m" % [deep, rest])


func _case_hay_does_not_open_it() -> void:
	GameState.hay_total = GameState.hay_initial * (Cfg.ORDER_HAY_FRACTION - 0.02)
	await _tick()
	_check(not _board().can_order(),
		"digging down to %.0f%% opened the note on its own, with the case unfilled"
			% [GameState.hay_left_fraction() * 100.0])


	GameState.hay_total = GameState.hay_initial
	await _tick()


func _case_the_case_is_the_gate() -> void:
	for i in GameState.needle_taken.size():
		GameState.needle_taken [i] = 1
	await _tick()
	_check(GameState.hay_left_fraction() > 0.5,
		"probe emptied the pile as well as the registry, so this case proves nothing")
	_check(not _board().can_order(),
		"the note opened with the needles merely dug up rather than in the case")

	var pool:= NeedleTypes.pool(GameState.lot_tier)
	for k in pool.size() - 1:
		GameState.discover(int(pool [k]), Vector3.ZERO)
	await _tick()
	_check(not _board().can_order(),
		"the note opened with %d of %d in the case" % [pool.size() - 1, pool.size()])

	GameState.discover(int(pool [pool.size() - 1]), Vector3.ZERO)
	await _tick()
	_check(_board().can_order(),
		"the note stayed shut with every type of the lot in the case")
	_check(GameState.lot_missing().is_empty(),
		"lot_missing still names %d types with the case full"
			% GameState.lot_missing().size())


func _case_a_lost_needle_comes_back() -> void:
	var field: HayField = world.field
	if field == null:
		_check(false, "no field to rebury into")
		return
	var type:= int(NeedleTypes.pool(GameState.lot_tier) [0])
	var before:= GameState.needle_positions.size()
	_check(field.rebury(type), "rebury refused to put a needle back in the stack")
	_check(GameState.needle_positions.size() == before + 1,
		"rebury did not add a needle to the registry")
	var last:= GameState.needle_positions.size() - 1
	_check(GameState.type_of(last) == type,
		"rebury buried type %d where %d was asked for"
			% [GameState.type_of(last), type])
	_check(GameState.needle_taken [last] == 0,
		"the reburied needle arrived already out of the ground")


func _case_the_run_survives() -> void:


	GameState.add_money(4321.0)
	GameState.discover(0, Vector3(1, 1, 1))
	GameState.deposit_needle(0, GameState.needle_positions [0])
	var money:= GameState.money
	var dug:= GameState.hay_dug
	var seed_before:= GameState.run_seed
	var found:= GameState.needles_found
	var discovered:= GameState.is_discovered(0)
	var stock:= GameState.stock_of(0)
	var old_first:= GameState.needle_positions [0]


	var owed:= GameState.debt
	var credit:= GameState.credit_stack_fee()

	await _deliver()

	_check(is_equal_approx(GameState.money, money),
		"the bank moved: %.2f before, %.2f after" % [money, GameState.money])
	_check(is_equal_approx(GameState.debt, owed + credit),
		"paying later owes $%.2f, expected $%.2f on top of $%.2f"
			% [GameState.debt, credit, owed])
	_check(GameState.hay_dug >= dug,
		"hay_dug went backwards: %.0f before, %.0f after" % [dug, GameState.hay_dug])
	_check(GameState.needles_found == found,
		"the run's found count was reset: %d before, %d after"
			% [found, GameState.needles_found])
	_check(GameState.is_discovered(0) == discovered,
		"a discovered specimen left the case")
	_check(GameState.stock_of(0) == stock,
		"drawer stock changed: %d before, %d after" % [stock, GameState.stock_of(0)])
	_check(GameState.run_seed != seed_before,
		"the run seed did not move, so the new stack is the old one again")
	_check(GameState.needle_positions.size() == GameState.pile_needle_types().size(),
		"new load has %d needles, expected %d"
			% [GameState.needle_positions.size(), GameState.pile_needle_types().size()])


	_check(GameState.needles_buried() == GameState.needle_positions.size(),
		"new load arrived with %d of its %d needles already out"
			% [GameState.needle_positions.size() - GameState.needles_buried(),
				GameState.needle_positions.size()])
	_check(GameState.needle_positions [0] != old_first,
		"the first needle is at the old one's coordinates, so nothing was reseeded")


func _board() -> DeliveryBoard:
	return world.delivery_board


func _deliver() -> void:
	_stand_at_the_board()
	var took:= _press()
	_check(took, "E at the board did nothing while the note was offering")
	await _settle(2)
	var panel: LoadPanel = world.load_panel
	_check(panel.is_open(), "E on an offering note did not open the order panel")
	panel.press_order()
	await _settle(4)
	await _tick()


func _look_at(sheet: String) -> void:
	var board:= _board()
	var at: Vector3 = board.docket_point() if sheet == "contract" else board.note_point()
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


func _stand_at_the_board() -> void:
	_look_at("note")


func _tick() -> void:
	await _settle(1)
	_board()._refresh_note()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _check(ok: bool, why: String) -> void:
	if not ok and why != "":
		_fails.append(why)


func _log(line: String) -> void:
	print("[pileorder] " + line)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
