class_name DevDemoLotProbe
extends Node


const LOG:= "res://demo_lot_probe.log"

var world: Node3D

var _fails: PackedStringArray = PackedStringArray()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	await _settle(8)
	_log("  build: %s" % ("demo" if Cfg.DEMO else "full"))

	_check(Cfg.demo_lot_gate == Cfg.DEMO,
		"World set the limit to %s on the one run that keeps it" % Cfg.demo_lot_gate)


	Cfg.demo_lot_gate = true

	_case_a_fresh_pile()
	await _case_the_lot_is_done()
	await _case_the_card()
	_case_a_save_past_it()
	await _case_the_full_game()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_a_fresh_pile() -> void:
	_check(GameState.lot_tier == Cfg.DEMO_LAST_LOT,
		"a fresh run opened on lot %d" % GameState.lot_tier)
	_check(GameState.demo_holds_next_load(), "the demo's last lot is not held")
	_check(not GameState.demo_is_over(), "the demo is over before a needle is in the case")
	_check(not GameState.may_order_pile(), "the note offers a load on an untouched pile")


	var expected: Array [int] = []
	if Cfg.DEMO:
		for type in NeedleTypes.pool(Cfg.DEMO_LAST_LOT):
			expected.append(type)
	else:
		for type in NeedleTypes.count():
			expected.append(type)
	var got: Array [int] = []
	for type in GameState.needle_type:
		got.append(int(type))
	got.sort()
	expected.sort()
	_check(got == expected, "a fresh pile buried %d needles %s, expected %s"
		% [got.size(), str(got), str(expected)])
	_log("  fresh pile: %d needles, types %s" % [got.size(), str(got)])


func _case_the_lot_is_done() -> void:
	_fill_lot(Cfg.DEMO_LAST_LOT)
	_check(GameState.lot_complete(Cfg.DEMO_LAST_LOT), "marking the lot found did not finish it")
	_check(GameState.demo_is_over(), "all six are in and the demo is not over")
	_check(not GameState.may_order_pile(), "all six are in and the demo still sells the next load")

	var board: DeliveryBoard = world.delivery_board
	board._refresh_note()
	_check(not board.can_order(), "the board offers the next load at the end of the demo")
	_check(board._note_foot.text == tr("NEXT LOAD IN THE FULL GAME"),
		"the note's foot reads '%s' at the end of the demo" % board._note_foot.text)
	_check(board._note_gate.text.begins_with("[X]"),
		"the note's box is not ticked with all six in: '%s'" % board._note_gate.text)
	_check(board._note_detail.text == tr("The demo ends here"),
		"the note still quotes a price: '%s'" % board._note_detail.text)

	var panel: LoadPanel = world.load_panel
	panel.refresh()
	_check(not panel._refresh_needles(), "step 1 reads DONE at the end of the demo")
	_check(panel._needles_line.text.contains(tr("The next load comes with the full game.")),
		"step 1 does not say the load is in the full game: '%s'" % panel._needles_line.text)

	var seed_before:= GameState.run_seed
	panel.press_order(true)
	panel.press_order(false)
	world._deliver_new_pile(true)
	world._deliver_new_pile(false)
	await _settle(4)
	_check(GameState.run_seed == seed_before, "a load came in at the end of the demo")
	_check(GameState.lot_tier == Cfg.DEMO_LAST_LOT,
		"the lot moved on to %d at the end of the demo" % GameState.lot_tier)


func _case_the_card() -> void:
	var card: DemoEndDialog = world.demo_end_dialog
	var reveal: DiscoveryCard = world.discovery_card
	var delay: float = world.DEMO_CARD_DELAY
	var last:= int(NeedleTypes.pool(Cfg.DEMO_LAST_LOT) [NeedleTypes.pool(Cfg.DEMO_LAST_LOT).size() - 1])

	_check(GameState.needle_discovered.is_connected(world._on_discovered_for_the_demo),
		"nothing listens for the last discovery of the demo")


	card._seen = false
	reveal.play(last)
	world._on_discovered_for_the_demo(last, Vector3.ZERO)
	await _settle(2)
	_check(not card.is_open(), "the demo card came up on the same frame as the discovery")
	await _seconds(delay + 0.3)
	if reveal.is_playing():
		_check(not card.is_open(), "the demo card came up over the reveal card")
	var waited:= 0.0
	while reveal.is_playing() and waited < 15.0:
		await _seconds(0.25)
		waited += 0.25
	await _seconds(0.6)
	_check(card.is_open(), "the last needle of the demo went in and no card came up")
	_check(card._headline.text == tr("THE FIRST SIX FOUND"),
		"the demo card's headline reads '%s'" % card._headline.text)
	_check(card._after.text == tr("That is the end of the demo. The full game has %d more loads and %d more kinds of needle. You can keep playing or stop here.") % [3, 18],
		"the demo card promises the wrong amount: '%s'" % card._after.text)

	_check(card._wishlist.visible == Cfg.DEMO,
		"the demo card's wishlist button is shown=%s with DEMO=%s" % [card._wishlist.visible, Cfg.DEMO])
	_check(card.WISHLIST_URL.begins_with(PauseMenu.STEAM_URL) and "utm_source=demo" in card.WISHLIST_URL,
		"the wishlist button opens an untagged address: %s" % card.WISHLIST_URL)
	card.set_open(false)


	world._on_discovered_for_the_demo(last, Vector3.ZERO)
	await _seconds(delay + 0.6)
	_check(not card.is_open(), "the demo card came up a second time in one run")


func _case_a_save_past_it() -> void:
	GameState.lot_tier = Cfg.DEMO_LAST_LOT + 1
	_fill_lot(GameState.lot_tier)
	_check(not GameState.demo_holds_next_load(), "a save past the demo's lot is still held")
	_check(not GameState.demo_is_over(), "a save past the demo's lot reads as a finished demo")
	_check(GameState.may_order_pile(), "a save already past the first lot lost its next load")
	GameState.lot_tier = Cfg.DEMO_LAST_LOT


func _case_the_full_game() -> void:
	Cfg.demo_lot_gate = false
	_check(not GameState.demo_is_over(), "with the limit off the demo still reads as over")
	_check(GameState.may_order_pile(), "with the limit off a finished first lot does not order")
	var board: DeliveryBoard = world.delivery_board
	board._refresh_note()
	_check(board._note_foot.text != tr("NEXT LOAD IN THE FULL GAME"),
		"the full game's note says the load is in the full game")

	var card: DemoEndDialog = world.demo_end_dialog
	var delay: float = world.DEMO_CARD_DELAY
	card._seen = false
	world._on_discovered_for_the_demo(0, Vector3.ZERO)
	await _seconds(delay + 0.6)
	_check(not card.is_open(), "the full game threw the demo card at a finished first lot")


	for lot in NeedleTypes.lot_count():
		_fill_lot(lot)
	card.celebrate()
	_check(card.is_open(), "a full case did not bring the card up")
	_check(card._headline.text == tr("ALL TWENTY-FOUR FOUND"),
		"a full case's card reads '%s'" % card._headline.text)
	card.set_open(false)


	var was_demo:= Cfg.DEMO
	Cfg.DEMO = false
	card._seen = false
	card.celebrate()
	_check(card.is_open() and not card._wishlist.visible,
		"the full game's card asks for a wishlist")
	Cfg.DEMO = was_demo
	card.set_open(false)


func _fill_lot(lot: int) -> void:
	for t in NeedleTypes.pool(lot):
		if t >= 0 and t < GameState.discovered.size():
			GameState.discovered [t] = 1


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(ok: bool, why: String) -> void:
	if not ok and why != "":
		_fails.append(why)


func _log(line: String) -> void:
	print("[demolot] " + line)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
