class_name DevGiftsProbe
extends Node


var world: Node3D
var player: Player
var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	var missions: MissionDirector = world.missions
	var builds: BuildManager = world.builds
	for i in 30:
		await get_tree().process_frame

	print("\n=== the build card hands over the cabinet, once ===")
	GameState.reset(4321, 1000000.0)
	Tech.reset()
	GameState.mission_index = MissionBook.index_of("bring_to_me")
	await _frames(3)
	_ok(GameState.gift_waiting("cabinet") == 0, "nothing is given before the card is done")
	GameState.mission_index = MissionBook.index_of("open_build")
	await _frames(3)
	_ok(GameState.gift_waiting("cabinet") == 1, "finishing it leaves one cabinet waiting")
	_ok(Tech.is_unlocked("cabinet"), "with its research card, which placing it needs")
	_ok(BuildCatalog.cost_text("cabinet").begins_with(Cfg.tr("FREE x%d") % 1),
		"the catalogue prices it %s" % BuildCatalog.cost_text("cabinet"))
	var card: GiftCard = world.gift_card
	_ok(GameState.gift_card_due == "cabinet" and card != null and not card.is_playing(),
		"its card waits for the build key")
	var cat: CatalogPanel = world.catalog_panel
	cat.set_open(true)
	_ok(card.is_holding() and not cat.is_open(), "the build key plays the card instead")
	_ok(card.hud_layer != null and not card.hud_layer.visible
			and card.get_parent() is CanvasLayer and card.get_parent() != card.hud_layer,
		"with the HUD's layer off under it, and the card on its own")
	_ok(GameState.gift_card_due == "", "and the card is no longer owed")
	cat.set_open(true)
	_ok(card.is_holding() and not cat.is_open(), "pressing it again goes to the card")
	var click:= InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var button: Rect2 = card._take_rect(card.size.y / GiftCard.REF_H)
	click.position = button.get_center()
	card._input(click)
	_ok(card.is_holding(), "a click on TAKE IT before it is up does nothing")
	card._t = GiftCard.T_HOLD + 1.0
	card._process(0.05)
	_ok(card.is_holding(), "and the card holds past T_HOLD until it is taken")
	var beside:= click.duplicate() as InputEventMouseButton
	beside.position = button.position - Vector2(40.0, 40.0)
	card._input(beside)
	_ok(card.is_holding(), "a click beside the button does nothing")
	card._input(click)
	_ok(not card.is_holding() and not cat.is_open(),
		"a click on TAKE IT takes it, back to the yard, catalogue shut")
	_ok(card.hud_layer.visible, "and the HUD comes back as it goes")
	var t0:= 0.0
	while card.is_playing() and t0 < 2.0:
		card._process(0.05)
		t0 += 0.05
	_ok(not card.is_playing(), "and the card fades away")
	_ok(not FileAccess.file_exists(GiftCard.OPEN_MARK), "a card taken leaves no crash mark")

	for way: String in ["interact", "free_mouse"]:
		GameState.gift_card_due = "cabinet"
		cat.set_open(true)
		_ok(FileAccess.file_exists(GiftCard.OPEN_MARK), "the card marks itself open while it holds")
		card._t = 2.0
		var press:= InputEventAction.new()
		press.action = way
		press.pressed = true
		card._input(press)
		_ok(not card.is_holding() and not cat.is_open(), "%s skips it mid spin" % way)
		t0 = 0.0
		while card.is_playing() and t0 < 2.0:
			card._process(0.05)
			t0 += 0.05
		_ok(not card._revealed, "and the reveal does not go off as it fades")

	print("\n=== a card the game went down in is not played again ===")
	var mark:= FileAccess.open(GiftCard.OPEN_MARK, FileAccess.WRITE)
	mark.store_string("cabinet")
	mark.close()
	GameState.gift_card_due = "cabinet"
	cat.set_open(true)
	_ok(cat.is_open() and not card.is_playing(), "the catalogue opens, gift in it, no card")
	_ok(not FileAccess.file_exists(GiftCard.OPEN_MARK) and GameState.gift_card_due == "",
		"and the mark and the debt are both cleared")
	cat.set_open(false)
	mark = FileAccess.open(GiftCard.OPEN_MARK, FileAccess.WRITE)
	mark.store_string("cabinet")
	mark.close()
	GameState.gift_card_due = "rake"
	cat.set_open(true)
	_ok(card.is_holding() and not cat.is_open(),
		"a mark another gift's card left does not cost this one its card")
	var esc:= InputEventAction.new()
	esc.action = "free_mouse"
	esc.pressed = true
	card._input(esc)
	t0 = 0.0
	while card.is_playing() and t0 < 2.0:
		card._process(0.05)
		t0 += 0.05
	_ok(not FileAccess.file_exists(GiftCard.OPEN_MARK), "and no mark is left behind")
	GameState.mission_index = MissionBook.index_of("bring_to_me")
	await _frames(3)
	GameState.mission_index = MissionBook.index_of("open_build")
	await _frames(3)
	_ok(GameState.gift_card_due == "", "walking past again owes no second card")
	_ok(GameState.gift_waiting("cabinet") == 1, "walking past the card again gives nothing more")

	print("\n=== a gift costs nothing going up or coming down ===")
	var bank:= GameState.money
	var tool: BuildTool = player.build
	var log_before:= GameState.purchase_log.size()
	player.build_id = "cabinet"
	_ok(tool._pay_gift("cabinet"), "the gift pays for its own placement")
	var cab:= builds.add_cabinet(Vector3(9.0, 0.05, 12.0), 0.0, true)
	_ok(is_equal_approx(GameState.money, bank), "and no money moved ($%.2f)" % GameState.money)
	_ok(GameState.gift_waiting("cabinet") == 0, "the gift is used up")
	var last: Array = GameState.purchase_log [-1] if GameState.purchase_log.size() > log_before else []
	_ok(not last.is_empty() and str(last [1]) == "gift" and str(last [2]) == "cabinet",
		"the diary writes it down as a gift (%s)" % str(last))
	_ok(cab.build_cost() == 0.0, "a gift cabinet's bill is nothing")
	var refund:= builds.demolish(cab)
	_ok(is_zero_approx(refund), "taking it down pays nothing (%.2f)" % refund)
	_ok(GameState.gift_waiting("cabinet") == 1, "and the gift comes back to be placed again")
	var bought:= builds.add_cabinet(Vector3(9.0, 0.05, 12.0), 0.0, false)
	_ok(is_equal_approx(builds.demolish(bought), Cfg.CABINET_COST),
		"a cabinet that was paid for still refunds its price")

	print("\n=== the power card hands over the rake ===")
	GameState.mission_index = MissionBook.index_of("power_up")
	await _frames(3)
	_ok(GameState.gift_waiting("rake") == 0, "nothing until the power runs")
	GameState.mission_index = MissionBook.index_of("build_rake")
	await _frames(3)
	_ok(GameState.gift_waiting("rake") == 1, "then one rake waiting")
	_ok(Tech.is_unlocked("piston_rake"), "with the rake card")
	_ok(is_equal_approx(GiftCard.list_price("rake"),
			TechTree.cost_at("piston_rake", 0) + Cfg.RAKE_COST),
		"the card's struck price is the card and the rake ($%.0f)" % GiftCard.list_price("rake"))

	print("\n=== the rake fleet's refund never touches the gift ===")
	GameState.take_gift("rake")
	var gift:= builds.add_piston_rake(Vector3(3.0, 0.05, 8.0), 0.0, 0.0, true)
	var second:= builds.add_piston_rake(Vector3(6.0, 0.05, 8.0), 0.0)
	var third:= builds.add_piston_rake(Vector3(-6.0, 0.05, 8.0), 0.0)
	print("    bills: gift %.0f, second %.0f, third %.0f"
		% [gift.build_cost(), second.build_cost(), third.build_cost()])
	_ok(is_equal_approx(second.build_cost(), Cfg.RAKE_COST),
		"the gift counts as the first, so the second is list price ($%.0f)" % second.build_cost())
	var third_bill:= third.build_cost()
	_ok(third_bill > second.build_cost(), "and the third is dearer ($%.0f)" % third_bill)
	_ok(bool(gift.to_dict().get("gift", false)), "the gift rake saves as a gift")
	var gift_refund:= builds.demolish(gift)
	_ok(is_zero_approx(gift_refund), "taking the gift down pays nothing (%.2f)" % gift_refund)
	_ok(is_equal_approx(third.build_cost(), third_bill),
		"and leaves the dearest bill where it was ($%.0f)" % third.build_cost())
	_ok(GameState.gift_waiting("rake") == 1, "the gift is back to be placed again")
	var paid_refund:= builds.demolish(second)
	_ok(is_equal_approx(paid_refund, third_bill),
		"a paid rake still pays back the dearest bill standing ($%.0f)" % paid_refund)
	builds.demolish(third)

	print("\n=== placing the rake hands over the pole ===")


	GameState.gifts.erase("pole")
	GameState.gifts_given.erase("build_rake")
	GameState.gift_card_due = ""
	GameState.mission_index = MissionBook.index_of("build_rake")
	await _frames(3)
	_ok(GameState.gift_waiting("pole") == 0, "nothing until the rake is down")
	GameState.mission_index = MissionBook.index_of("build_power")
	await _frames(3)
	_ok(GameState.gift_waiting("pole") == 1, "then one pole waiting")
	_ok(GameState.gift_card_due == "pole", "and its card waits for the build key")
	_ok(is_equal_approx(GiftCard.list_price("pole"), Cfg.POLE_COST),
		"the card's struck price is the pole alone ($%.0f)" % GiftCard.list_price("pole"))
	GameState.take_gift("pole")
	var free_pole:= builds.add_power_pole(Vector3(4.0, 0.0, 10.0), 0.0, false, true)
	_ok(is_zero_approx(free_pole.build_cost()), "a gift pole's bill is nothing")
	_ok(bool(free_pole.to_dict().get("gift", false)), "and it saves as a gift")
	var pole_refund:= builds.demolish(free_pole)
	_ok(is_zero_approx(pole_refund), "taking it down pays nothing (%.2f)" % pole_refund)
	_ok(GameState.gift_waiting("pole") == 1, "and the gift comes back to be placed again")
	var box:= builds.add_power_pole(Vector3(4.0, 0.0, 10.0), 0.0, true, true)
	_ok(not box.gift, "a box is never the gift")
	builds.demolish(box)
	GameState.gifts.erase("pole")
	GameState.gift_card_due = ""

	print("\n=== a developed yard is not given what it has ===")
	GameState.gifts_given.clear()
	GameState.gifts.clear()
	builds.add_piston_rake(Vector3(3.0, 0.05, 8.0), 0.0)
	GameState.mission_index = MissionBook.index_of("power_up")
	await _frames(3)
	GameState.mission_index = MissionBook.index_of("build_rake")
	await _frames(3)
	_ok(GameState.gift_waiting("rake") == 0, "a yard with a rake standing is given none")

	print("\n=== a waiting gift survives a save ===")
	GameState.give_gift("rake")
	GameState.gift_card_due = "rake"
	var saved:= GameState.to_dict()
	GameState.gifts.clear()
	GameState.gift_card_due = ""
	GameState.from_dict(saved)
	_ok(GameState.gift_waiting("rake") == 1, "one rake still waiting after the reload")
	_ok(GameState.gifts_given.has("power_up"), "and the step still remembers it paid")
	_ok(GameState.gift_card_due == "rake", "and its card is still owed")

	print("\n=== the diary ===")
	GameState.reset(4321, 1000000.0)
	Tech.reset()
	GameState.run_secs = 42.0
	GameState.add_money(10.0)
	Tech.buy("hand_carry")
	var entry: Array = GameState.purchase_log [-1] if not GameState.purchase_log.is_empty() else []
	_ok(not entry.is_empty() and str(entry [1]) == "card" and str(entry [2]) == "hand_carry"
			and int(entry [3]) == 1 and is_equal_approx(float(entry [0]), 42.0),
		"a card is written down with the clock it was bought at (%s)" % str(entry))
	var round_trip:= GameState.to_dict()
	GameState.purchase_log.clear()
	GameState.from_dict(round_trip)
	_ok(GameState.purchase_log.size() == 1, "and the diary comes back with the save")

	print("\n=== the toy shovel's ladder ===")
	var bites:= PackedInt32Array()
	for rank in TechTree.max_rank("toy_shovel_size") + 1:
		Tech.reset()
		Tech.grant("toy_shovel_size", rank)
		bites.append(Tech.scoop_max(SandShovel.SCOOP_MAX, Tech.toy_shovel_scale()))
	_ok(bites == PackedInt32Array([18, 21, 24, 27]), "bites %s" % str(bites))
	var costs:= PackedFloat32Array()
	for rank in TechTree.max_rank("toy_shovel_size"):
		costs.append(TechTree.cost_at("toy_shovel_size", rank))
	_ok(costs == PackedFloat32Array([2.0, 4.0, 7.0]), "costs %s" % str(costs))
	Tech.reset()

	print("\n=== the gift card plays through and goes ===")
	var gc: GiftCard = world.gift_card
	gc.play("rake")
	var t:= 0.0
	while gc.is_playing() and t < 12.0:
		gc._process(0.05)
		t += 0.05
	_ok(not gc.is_playing(), "the card takes itself off after %.1f s" % t)

	print("\n=== F1 plays it and gives nothing ===")
	var dm: DebugMenu = world.debug_menu
	var owed:= GameState.gifts.duplicate()
	var due:= GameState.gift_card_due
	dm._on_play_gift("rake")
	_ok(gc.is_holding(), "the debug menu's button plays the card, holding")
	var esc_out:= InputEventAction.new()
	esc_out.action = "free_mouse"
	esc_out.pressed = true
	gc._input(esc_out)
	t = 0.0
	while gc.is_playing() and t < 2.0:
		gc._process(0.05)
		t += 0.05
	_ok(not gc.is_playing() and GameState.gifts == owed and GameState.gift_card_due == due,
		"and Escape takes it, with no gift handed over and no card owed")

	print("\n%s: %d failure(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
