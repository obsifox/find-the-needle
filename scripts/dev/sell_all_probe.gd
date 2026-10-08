class_name DevSellAllProbe
extends Node


const LOG:= "res://sell_all_probe.log"


const BUILD_COST_SPECIMEN:= 12

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

	await _case_the_sign_only_asks()
	await _case_the_sale_pays_what_it_said()
	await _case_a_belt_cannot_be_farmed()
	await _case_the_panel_counts_a_loaded_deck()
	await _case_it_will_not_take_hay()
	await _case_what_is_left_standing()
	await _case_the_tool_quotes_one_price()
	await _case_no_structure_can_be_farmed()
	await _case_a_discount_bought_later_pays_in_full()
	await _case_the_sale_pays_what_was_paid()
	await _case_the_price_survives_a_save()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_the_sign_only_asks() -> void:
	var board:= _board()
	if board == null:
		_fails.append("there is no delivery board for the clearance card to hang on")
		return
	_build_a_small_yard()
	var before:= _standing()


	var at:= board.clearance_point()
	var foot:= board.global_position
	_check(Vector2(at.x - foot.x, at.z - foot.z).length() < 0.8,
		"the clearance card has come off the board it is pinned to")
	_check(at.y - foot.y > 0.9 and at.y - foot.y < 1.3,
		"the clearance card is %.2f m up the board, off the cork" % (at.y - foot.y))

	_look_at_the_sign(8.0)
	_check(_hovered() != "clearance", "the card answers from eight metres away")
	_look_at_the_sign(-1.6)
	_check(_hovered() != "clearance", "the card answers through the back of the board")

	_look_at_the_sign(1.6)
	_check(_hovered() == "clearance",
		"the crosshair on the card picks '%s' instead" % _hovered())
	_check(board.take_press(player.eye_position(), player.look_direction()),
		"E on the card did nothing")
	await _settle(2)
	_check(_dialog() != null and _dialog().is_open(),
		"E on the sign did not raise the warning")
	_check(_standing() == before,
		"E on the sign took the yard down without asking")
	_dialog().set_open(false)
	await _settle(2)


func _case_the_sale_pays_what_it_said() -> void:
	_build_a_small_yard()
	var tally:= YardSale.tally(_builds(), _props())
	var purse:= GameState.money
	_check(int(tally.machines) > 0, "the tally counted no machines in a built yard")
	_check(float(tally.total) > 0.0, "the tally priced a built yard at nothing")

	_dialog().open(tally)
	await _settle(2)
	_dialog()._on_sell()
	await _settle(4)

	_check(is_equal_approx(GameState.money, purse + float(tally.total)),
		"paid $%.2f for a yard the panel priced at $%.2f"
		% [GameState.money - purse, float(tally.total)])
	_check(_standing() == 0, "%d buildings still standing after the sale" % _standing())


func _case_a_belt_cannot_be_farmed() -> void:
	var builds:= _builds()
	var tool:= player.build as BuildTool
	if tool == null:
		_fails.append("the player has no build tool to price a belt with")
		return
	Tech.reset()
	var full:= Conveyor.cost_for(Vector3.ZERO, Vector3(10.0, 0.0, 0.0))
	Tech.grant("steel_saving", 3)
	_check(Tech.build_cost_scale() < 1.0,
		"the discount is not on, so this case is proving nothing")
	_check(Conveyor.cost_for(Vector3.ZERO, Vector3(10.0, 0.0, 0.0)) < full,
		"a belt costs the same with the material discount bought as without it")

	var a:= _yard_spot(30.0)
	var b:= a + Vector3(6.0, 0.0, 0.0)
	var bill:= float(tool._evaluate(a, b, true) ["cost"])
	var belt:= builds.add_conveyor(a, b)
	await _settle(2)
	var refund:= builds.demolish(belt)
	_check(is_equal_approx(refund, bill),
		"a belt billed at $%.2f refunded $%.2f, which is $%.2f a lap"
			% [bill, refund, refund - bill])
	Tech.reset()
	await _settle(2)


func _case_the_panel_counts_a_loaded_deck() -> void:
	var builds:= _builds()
	var deck:= builds.add_platform(_yard_spot(40.0) + Vector3(0, 1.2, 0),
		Vector2(4.0, 4.0))
	var top:= deck.top_y()
	builds.add_conveyor(_yard_spot(40.0) + Vector3(-1.5, top, 0),
		_yard_spot(40.0) + Vector3(1.5, top, 0))
	await _settle(2)

	var tally:= YardSale.tally(builds, _props())
	_check(int(tally.structures) > 0,
		"the panel did not count a deck it was about to sell")
	_check(tally.kept.size() == 0,
		"the panel said something would be left standing in a yard it clears")
	var sold:= YardSale.sell(builds, _props())
	await _settle(2)
	_check(is_equal_approx(float(sold.paid), float(tally.total)),
		"the panel offered $%.2f and the till paid $%.2f"
			% [float(tally.total), float(sold.paid)])


func _case_it_will_not_take_hay() -> void:
	var props:= _props()
	var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, _yard_spot(2.0)))
	var spade:= props.spawn("spade", Transform3D(Basis.IDENTITY, _yard_spot(3.0)))
	var loose:= props.spawn("bucket", Transform3D(Basis.IDENTITY, _yard_spot(4.0)))


	spade.pick_up()
	await _settle(2)

	var tally:= YardSale.tally(_builds(), _props())
	_check(int(tally.tools) == 1,
		"the tally offered %d tools for one bucket, one held spade and one wad"
			% int(tally.tools))

	var sold:= YardSale.sell(_builds(), _props())
	await _settle(2)
	_check(is_instance_valid(wad) and props.items.has(wad),
		"the sale took a hay wad off the ground")
	_check(is_instance_valid(spade) and props.items.has(spade),
		"the sale took the item out of the player's hands")
	_check(not is_instance_valid(loose) or not props.items.has(loose),
		"the sale left a bucket lying in the yard")
	_check(int(sold.tools) == 1, "the sale bought %d items rather than one"
		% int(sold.tools))
	if is_instance_valid(spade):
		spade.release(Vector3.ZERO)


func _case_what_is_left_standing() -> void:
	var builds:= _builds()
	var deck:= builds.add_platform(_yard_spot(6.0) + Vector3(0, 1.2, 0),
		Vector2(4.0, 4.0))
	var top:= deck.top_y()
	var on_deck:= builds.add_conveyor(_yard_spot(6.0) + Vector3(-1.5, top, 0),
		_yard_spot(6.0) + Vector3(1.5, top, 0))
	var scanner:= builds.add_scanner(_yard_spot(10.0), 0.0)


	scanner.banked.append(0)
	await _settle(2)

	var tally:= YardSale.tally(builds, _props())
	_check(tally.kept.size() > 0,
		"the panel promised to clear a yard holding a loaded scanner")

	YardSale.sell(builds, _props())
	await _settle(4)
	_check(not is_instance_valid(deck) or not builds.platforms.has(deck),
		"the deck is still standing with its belt sold out from under it")
	_check(not is_instance_valid(on_deck) or not builds.conveyors.has(on_deck),
		"the belt on the deck survived the sale")
	_check(is_instance_valid(scanner) and builds.scanners.has(scanner),
		"the sale took a scanner with a needle still banked in it")

	scanner.banked.clear()
	YardSale.sell(builds, _props())


func _case_the_tool_quotes_one_price() -> void:
	var tool:= player.build as BuildTool
	if tool == null:
		_fails.append("the player has no build tool to price a structure with")
		return
	var a:= _yard_spot(60.0)
	var b:= a + Vector3(0.0, 0.0, 6.0)
	var span:= Vector2(4.0, 4.0)


	_discount(false)
	var list_belt:= Conveyor.cost_for(a, b)
	var list_rail:= Railing.cost_for(a, b)
	var list_deck:= Platform.cost_for(span)
	var list_stair:= Stair.cost_for(2.0)
	var list_wall:= YardWall.cost_for(a, b, YardWall.Bay.SOLID)
	var list_roof:= Roof.cost_for(a, b, Roof.Kind.FLAT, 1)

	_discount(true)
	_check(Tech.build_cost_scale() < 1.0,
		"the discount is not on, so these cases are proving nothing")
	_check(Conveyor.cost_for(a, b) < list_belt, "the discount misses a belt")
	_check(Railing.cost_for(a, b) < list_rail, "the discount misses a railing")
	_check(Platform.cost_for(span) < list_deck, "the discount misses a deck")
	_check(Stair.cost_for(2.0) < list_stair, "the discount misses a stair")
	_check(YardWall.cost_for(a, b, YardWall.Bay.SOLID) < list_wall,
		"the discount misses a wall")
	_check(Roof.cost_for(a, b, Roof.Kind.FLAT, 1) < list_roof,
		"the discount misses a roof")

	_check(is_equal_approx(float(tool._evaluate(a, b, true) ["cost"]),
		Conveyor.cost_for(a, b)), "the tool quotes a belt its own way")
	_check(is_equal_approx(float(tool._evaluate_railing(a, b, true) ["cost"]),
		Railing.cost_for(a, b)), "the tool quotes a railing its own way")
	_check(is_equal_approx(float(tool._evaluate_deck(a, span) ["cost"]),
		Platform.cost_for(span)), "the tool quotes a deck its own way")


	var was_mode:= tool._mode
	tool._mode = BuildTool.Mode.WALL
	_check(is_equal_approx(float(tool._evaluate_wall(a, b, true) ["cost"]),
		YardWall.cost_for(a, b, YardWall.Bay.SOLID)),
		"the tool quotes a solid wall its own way")
	tool._mode = BuildTool.Mode.WALL_WINDOW
	_check(is_equal_approx(float(tool._evaluate_wall(a, b, true) ["cost"]),
		YardWall.cost_for(a, b, YardWall.Bay.WINDOW)),
		"the tool quotes a windowed wall its own way")
	tool._mode = BuildTool.Mode.WALL_DOOR
	_check(is_equal_approx(float(tool._evaluate_wall(a, b, true) ["cost"]),
		YardWall.cost_for(a, b, YardWall.Bay.DOOR)),
		"the tool quotes a doorway its own way")
	tool._mode = was_mode
	for kind: Roof.Kind in [Roof.Kind.FLAT, Roof.Kind.PITCHED, Roof.Kind.HATCH]:
		_check(is_equal_approx(
			float(tool._evaluate_roof(a, b, kind, 1, 1, true) ["cost"]),
			Roof.cost_for(a, b, kind, 1)),
			"the tool quotes roof kind %d its own way" % int(kind))


	_discount(false)


func _case_no_structure_can_be_farmed() -> void:
	var builds:= _builds()
	_discount(true)
	var made:= _one_of_each(builds)
	await _settle(2)
	for entry: Dictionary in made:
		var bill:= float(entry ["bill"])
		var refund:= builds.demolish(entry ["node"] as Node3D)
		_check(is_equal_approx(refund, bill),
			"a %s billed at $%.2f refunded $%.2f, which is $%.2f a lap"
				% [entry ["what"], bill, refund, refund - bill])
	await _settle(2)
	_discount(false)


func _case_a_discount_bought_later_pays_in_full() -> void:
	var builds:= _builds()
	_discount(false)
	var made:= _one_of_each(builds)
	await _settle(2)
	_discount(true)
	for entry: Dictionary in made:
		var bill:= float(entry ["bill"])
		var refund:= builds.demolish(entry ["node"] as Node3D)
		_check(is_equal_approx(refund, bill),
			"a %s bought for $%.2f before the discount refunded $%.2f after it"
				% [entry ["what"], bill, refund])
	await _settle(2)
	_discount(false)


func _case_the_sale_pays_what_was_paid() -> void:
	var builds:= _builds()
	_discount(false)
	var made:= _one_of_each(builds)
	var owed:= 0.0
	for entry: Dictionary in made:
		owed += float(entry ["bill"])
	await _settle(2)
	_discount(true)

	var tally:= YardSale.tally(builds, _props())


	var offered:= float(tally.structures_value) + float(tally.machines_value)
	_check(is_equal_approx(offered, owed),
		"the panel offered $%.2f for a yard that cost $%.2f" % [offered, owed])
	var sold:= YardSale.sell(builds, _props())
	await _settle(4)
	var paid:= float(sold.structures_value) + float(sold.machines_value)
	_check(is_equal_approx(paid, owed),
		"the till paid $%.2f for a yard that cost $%.2f" % [paid, owed])
	_check(is_equal_approx(float(sold.paid), float(tally.total)),
		"the panel offered $%.2f in total and the till paid $%.2f"
			% [float(tally.total), float(sold.paid)])
	_discount(false)


func _case_the_price_survives_a_save() -> void:
	var builds:= _builds()
	_discount(false)
	var made:= _one_of_each(builds)
	var owed:= 0.0
	for entry: Dictionary in made:
		owed += float(entry ["bill"])
	await _settle(2)

	var written:= builds.to_array()
	_discount(true)
	builds.from_array(written)
	await _settle(4)

	var back:= 0.0
	for building: Node3D in builds.all_buildings():
		back += builds.value_of(building)
	_check(builds.all_buildings().size() == made.size(),
		"%d of %d structures came back out of the save"
			% [builds.all_buildings().size(), made.size()])
	_check(is_equal_approx(back, owed),
		"a yard that cost $%.2f is worth $%.2f after a save and a load"
			% [owed, back])
	builds.clear()
	await _settle(2)
	_discount(false)


func _one_of_each(builds: BuildManager) -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	var slot:= 60.0
	var across:= Vector3(0.0, 0.0, 1.0)

	var belt_a:= _yard_spot(slot)
	var belt_b:= belt_a + across * 6.0
	out.append({ "what": "belt", "bill": Conveyor.cost_for(belt_a, belt_b),
		"node": builds.add_conveyor(belt_a, belt_b) })

	slot += 6.0
	var deck_span:= Vector2(4.0, 4.0)
	out.append({ "what": "deck", "bill": Platform.cost_for(deck_span),
		"node": builds.add_platform(_yard_spot(slot) + Vector3(0.0, 1.2, 0.0),
			deck_span) })

	slot += 6.0
	out.append({ "what": "stair", "bill": Stair.cost_for(2.0),
		"node": builds.add_stair(_yard_spot(slot) + Vector3(0.0, 2.0, 0.0), 0.0, 2.0) })

	slot += 6.0
	var rail_a:= _yard_spot(slot)
	var rail_b:= rail_a + across * 4.0
	out.append({ "what": "railing", "bill": Railing.cost_for(rail_a, rail_b),
		"node": builds.add_railing(rail_a, rail_b) })

	for bay: YardWall.Bay in [YardWall.Bay.SOLID, YardWall.Bay.WINDOW,
			YardWall.Bay.DOOR]:
		slot += 6.0
		var wall_a:= _yard_spot(slot)
		var wall_b:= wall_a + across * 4.0
		out.append({ "what": "wall kind %d" % int(bay),
			"bill": YardWall.cost_for(wall_a, wall_b, bay),
			"node": builds.add_wall(wall_a, wall_b, bay) })

	for kind: Roof.Kind in [Roof.Kind.FLAT, Roof.Kind.PITCHED, Roof.Kind.HATCH]:
		slot += 6.0
		var roof_a:= _yard_spot(slot) + Vector3(0.0, 3.0, 0.0)
		var roof_b:= roof_a + across * 4.0
		out.append({ "what": "roof kind %d" % int(kind),
			"bill": Roof.cost_for(roof_a, roof_b, kind, 1),
			"node": builds.add_roof(roof_a, roof_b, kind, 1, 1) })

	for entry: Dictionary in out:
		if entry ["node"] == null:
			_fails.append("the yard would not build a %s to price" % entry ["what"])
	return out


func _discount(on: bool) -> void:
	Tech.reset()
	if on:
		Tech.grant("steel_saving", 3)
	if BUILD_COST_SPECIMEN < GameState.discovered.size():
		GameState.discovered [BUILD_COST_SPECIMEN] = 1 if on else 0
	Tech._invalidate_specimens()


func _board() -> DeliveryBoard:
	return world.delivery_board


func _hovered() -> String:
	return _board().hovered_sheet(player.eye_position(), player.look_direction())


func _dialog() -> SellAllDialog:
	return world.sell_all_dialog


func _builds() -> BuildManager:
	return world.builds


func _props() -> PropManager:
	return world.props


func _build_a_small_yard() -> void:
	var builds:= _builds()
	for i in 3:
		var at:= _yard_spot(12.0 + float(i) * 3.0)
		builds.add_conveyor(at, at + Vector3(2.5, 0, 0))
	builds.add_platform(_yard_spot(24.0) + Vector3(0, 1.2, 0), Vector2(3.0, 3.0))


func _yard_spot(along: float) -> Vector3:
	return Vector3(-12.0 - along, 0.0, 14.0)


func _standing() -> int:
	return _builds().all_buildings().size()


func _look_at_the_sign(distance: float) -> void:
	var board:= _board()
	var at:= board.clearance_point()
	var out:= board.global_transform.basis * DeliveryBoard.face_normal()
	out.y = 0.0
	var stand:= at + out.normalized() * distance
	stand.y = board.global_position.y + 0.2
	player.global_position = stand
	var to_sign:= at - player.eye_position()
	player.set_look(atan2(- to_sign.x, - to_sign.z),
		atan2(to_sign.y, Vector2(to_sign.x, to_sign.z).length()))


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _check(ok: bool, why: String) -> void:
	if not ok and why != "":
		_fails.append(why)


func _log(line: String) -> void:
	print("[sellup] " + line)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
