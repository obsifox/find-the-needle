class_name DevNudgeProbe
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
	for i in 10:
		await get_tree().process_frame


	var missions: MissionDirector = world.missions
	missions.process_mode = Node.PROCESS_MODE_DISABLED
	var hud: Hud = world.hud
	var board: TechPanel = player.tech_panel
	board.set_hint("")


	var was_teach:= Cfg.teach_hints
	var was_given:= Cfg.nudges_given.duplicate()
	Cfg.nudges_given.clear()

	print("\n[nudge] the wiring")
	_ok(TechTree.requires("strong_back") == [TechTree.ROOT], "Strong Back hangs off the root")
	_ok(TechTree.requires("second_wind") == [TechTree.ROOT], "Second Wind hangs off the root")
	_ok(TechTree.requires("yard_space") == [TechTree.ROOT], "Extend the Shed hangs off the root")
	_ok(str(TechTree.BRANCHES [1] ["id"]) == "fitness", "Fitness is the second lane")

	print("\n[nudge] out of breath")
	GameState.money = 0.0
	Cfg.teach_hints = false
	player.stamina.ran_dry += 1
	await _frames(3)
	_ok(not Cfg.nudge_given("strong_back"), "hints off: nothing said")
	Cfg.teach_hints = true
	hud.show_toast("probe", 30.0)
	player.stamina.ran_dry += 1
	await _frames(3)
	_ok(not Cfg.nudge_given("strong_back") and hud.toast_text() == "probe",
		"broke: nothing said, since the card cannot be bought yet")
	GameState.money = 1000.0
	player.spent_refusals += 1
	await _frames(3)
	var back:= TechTree.display_name("strong_back")
	_ok(Cfg.nudge_given("strong_back"), "a refused dig with the money in the bank names it")
	_ok(hud.toast_text().contains(back) and not hud.toast_text().contains("{"),
		"...in a line with the card's name and the key filled in: \"%s\"" % hud.toast_text())
	_ok(hud.toast_text().contains(InputSetup.hint("tech_tree")), "...naming the board's key")
	_ok(board._ring_id() == "strong_back", "...and rings the card on the board")
	hud.show_toast("probe", 30.0)
	player.stamina.ran_dry += 1
	await _frames(3)
	_ok(hud.toast_text() == "probe", "said once: the next dry bar says nothing")

	print("\n[nudge] the board")
	board.set_hint("belt")
	_ok(board._ring_id() == "belt", "a mission's card outranks the nudge")
	board.set_hint("")
	_ok(board._ring_id() == "strong_back", "...and the nudge comes back when it is gone")
	board.set_open(true)
	await _frames(3)
	_ok(board._selected == "strong_back", "the board opens on the card")
	board.set_open(false)
	await _frames(2)
	_ok(board._ring_id() == "", "shown once and shut: the ring lets go")

	print("\n[nudge] out of room")

	GameState.money = 1000.0
	hud.show_toast("probe", 30.0)
	Tech.grant("electricity")
	player.equip_build("generator")
	await _frames(3)
	_ok(player.build._active, "a generator ghost is up")
	var shed: Warehouse = world.warehouse


	var edge:= - shed.inner
	var mid:= shed.z_mid()
	var before:= player.build.shed_refusals
	_aim(shed, Vector3(edge + 6.0, 0.0, mid), Vector3(edge + 9.0, 0.0, mid))
	await _frames(8)
	_ok(player.build.shed_refusals == before,
		"open floor six metres in: the shed is not in the way (%s)" % str(player.build._eval ["reason"]))
	_ok(not Cfg.nudge_given("yard_space"), "...and nothing is said")
	_aim(shed, Vector3(edge + 0.3, 0.0, mid), Vector3(edge + 3.5, 0.0, mid))
	await _frames(8)
	_ok(player.build.shed_refusals > before,
		"into the wall: refused with the shed in the way (%s)" % str(player.build._eval ["reason"]))
	var grow:= TechTree.display_name("yard_space")
	_ok(Cfg.nudge_given("yard_space") and hud.toast_text().contains(grow),
		"...names Extend the Shed: \"%s\"" % hud.toast_text())
	_ok(board._ring_id() == "yard_space", "...and rings it")
	hud.show_toast("probe", 30.0)
	await _frames(8)
	_ok(hud.toast_text() == "probe", "said once: still pushing at the wall says nothing more")

	print("\n[nudge] hands full")


	var tool_was:= player.current_tool
	var money_was:= GameState.money
	var step_was:= GameState.mission_index
	player._set_tool(Player.Tool.HAND)
	GameState.money = 0.0
	hud.show_toast("probe", 30.0)
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var straw: RigidBody3D = player.hand.live.spawn(eye + dir * 1.0,
		Basis.looking_at(dir.cross(Vector3.UP).normalized(), Vector3.UP),
		Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	if straw != null:
		straw.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		straw.freeze = true
	await _frames(4)
	player.hand.primary()
	await _frames(3)
	_ok(player.hand.is_full(), "one strand fills a hand with nothing bought")
	_ok(not Cfg.nudge_given("hand_carry") and hud.toast_text() == "probe",
		"broke: nothing said, since the card cannot be bought yet")


	GameState.mission_index = MissionBook.index_of("first_dollar")
	GameState.money = 10.0
	await _frames(20)
	_ok(not Cfg.nudge_given("hand_carry") and hud.toast_text() == "probe",
		"on the first cards: nothing said, however full the hand")
	_ok(not hud._ready_card.visible, "...and the corner says nothing either")
	GameState.mission_index = MissionBook.index_of("buy_handful")
	await _frames(20)
	_ok(not Cfg.nudge_given("hand_carry"),
		"on Buy Bigger Handful: the card says it, so the line does not")
	_ok(hud._ready_card.visible, "...while the corner agrees with the card")
	GameState.mission_index = MissionBook.index_of("buy_toy_licence")
	await _frames(3)
	var handful:= TechTree.display_name("hand_carry")
	_ok(Cfg.nudge_given("hand_carry") and hud.toast_text().contains(handful),
		"a full hand with the money in the bank names it: \"%s\"" % hud.toast_text())
	_ok(board._ring_id() == "hand_carry", "...and rings the card on the board")
	hud.show_toast("probe", 30.0)
	await _frames(3)
	_ok(hud.toast_text() == "probe", "said once: the hand still full says nothing more")


	await _frames(20)
	_ok(hud._ready_card_id() == "hand_carry",
		"the corner names Bigger Handful while it can be bought")
	_ok(hud._ready_card.visible and hud._ready_card.text.contains(Cfg.upper(handful)),
		"...and shows it: \"%s\"" % hud._ready_card.text)
	_ok(hud._hand_count.visible and hud._hand_count.text == "1 / 1",
		"the fist reads \"%s\" beside the crosshair" % hud._hand_count.text)
	Cfg.teach_hints = false
	await _frames(20)
	_ok(not hud._ready_card.visible, "hints off: the corner says nothing")
	Cfg.teach_hints = true
	GameState.money = 0.0
	await _frames(20)
	_ok(not hud._ready_card.visible, "broke: the corner says nothing")
	player.hand.drop_held()
	await _frames(2)
	_ok(not hud._hand_count.visible, "an empty hand shows no count")
	board.set_nudge("")
	player._set_tool(tool_was)
	GameState.money = money_was
	GameState.mission_index = step_was
	await _frames(2)

	print("\n[nudge] a new game")


	var lists:= [Cfg.keys_used.duplicate(), Cfg.builds_placed.duplicate(),
		Cfg.techs_seen.duplicate(), Cfg.machines_seen.duplicate()]


	_aim(shed, Vector3(edge + 6.0, 0.0, mid), Vector3(edge + 9.0, 0.0, mid))
	await _frames(4)
	Cfg._forget_lessons()
	_ok(not Cfg.nudge_given("strong_back") and not Cfg.nudge_given("yard_space"),
		"a new game forgets both")
	player.stamina.ran_dry += 1
	await _frames(3)
	_ok(Cfg.nudge_given("strong_back") and hud.toast_text().contains(back),
		"...the next dry bar says it again: \"%s\"" % hud.toast_text())
	_aim(shed, Vector3(edge + 0.3, 0.0, mid), Vector3(edge + 3.5, 0.0, mid))
	await _frames(8)
	_ok(Cfg.nudge_given("yard_space") and hud.toast_text().contains(grow),
		"...and so does the wall: \"%s\"" % hud.toast_text())

	print("\n[nudge] low, and paid for later")


	_aim(shed, Vector3(edge + 6.0, 0.0, mid), Vector3(edge + 9.0, 0.0, mid))
	await _frames(4)
	Cfg._forget_lessons()
	GameState.money = 0.0
	hud.show_toast("probe", 30.0)
	var lows: int = player.stamina.ran_low
	player.stamina.current = player.stamina.maximum() * 0.1
	await _frames(4)
	_ok(player.stamina.ran_low > lows and player.stamina.since_low() < 1.0,
		"a bar under a fifth counts as low")
	_ok(not Cfg.nudge_given("strong_back") and hud.toast_text() == "probe",
		"low and broke: nothing said yet")
	GameState.money = 1000.0
	await _frames(4)
	_ok(Cfg.nudge_given("strong_back") and hud.toast_text().contains(back),
		"...and the money arriving says it: \"%s\"" % hud.toast_text())
	await _frames(20)
	_ok(hud._ready_card_id() == "strong_back", "the pill names Strong Back after a low bar")
	_ok(hud._ready_pill.visible and hud._ready_card.text.contains(Cfg.upper(back)),
		"...and is up: \"%s\"" % hud._ready_card.text)
	_ok(hud._ready_icon.visible and hud._ready_icon.texture != null,
		"...with the card's own drawing beside it")
	await get_tree().create_timer(Hud.READY_SHOW_FOR + Hud.READY_FADE + 0.5,
		true, false, true).timeout
	_ok(hud._ready_card_id() == "strong_back" and not hud._ready_pill.visible,
		"a few seconds later it has gone, though the card is still affordable")
	player.stamina.refill()

	print("\n[nudge] arms full")


	var carry:= player.carry
	var arms:= TechTree.display_name("arm_load")
	var ranks_were:= [Tech.rank_of("strong_back"), Tech.rank_of("arm_load")]
	Tech.grant("strong_back", 1)
	Tech.grant("arm_load", 0)
	GameState.money = 0.0
	hud.show_toast("probe", 30.0)
	_arms_full(carry)
	await _frames(4)
	_ok(not Cfg.nudge_given("arm_load") and hud.toast_text() == "probe",
		"arms full and broke: nothing said yet")
	GameState.money = 1000.0
	await _frames(4)
	_ok(Cfg.nudge_given("arm_load") and hud.toast_text().contains(arms),
		"...and the money arriving names Carry More: \"%s\"" % hud.toast_text())
	_ok(board._ring_id() == "arm_load", "...and rings it on the board")
	await _frames(20)
	_ok(hud._ready_card_id() == "arm_load" and hud._ready_pill.visible and hud._ready_card.text.contains(Cfg.upper(arms)),
		"the pill names it too: \"%s\"" % hud._ready_card.text)
	hud.show_toast("probe", 30.0)
	Tech.grant("arm_load", 1)
	await _seconds(Hud.READY_CARD_POLL * 2.0)
	_ok(hud._ready_card_id() != "arm_load",
		"a level bought: the pill waits for the new limit to be met")
	_arms_full(carry)
	await _seconds(Hud.READY_CARD_POLL * 2.0)
	_ok(hud._ready_card_id() == "arm_load" and hud._ready_pill.visible,
		"...and names the next level once it is: \"%s\"" % hud._ready_card.text)
	_ok(hud.toast_text() == "probe", "...while the line is not said a second time")
	carry.full_msec = -1
	Tech.grant("strong_back", ranks_were [0])
	Tech.grant("arm_load", ranks_were [1])

	Cfg.keys_used = lists [0]
	Cfg.builds_placed = lists [1]
	Cfg.techs_seen = lists [2]
	Cfg.machines_seen = lists [3]

	board.set_nudge("")
	missions.process_mode = Node.PROCESS_MODE_INHERIT
	Cfg.teach_hints = was_teach
	Cfg.nudges_given = was_given

	print("\n[nudge] %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit()


func _aim(shed: Warehouse, at: Vector3, stand: Vector3) -> void:
	var at_w:= shed.to_global(at)
	var stand_w:= shed.to_global(stand)
	stand_w.y = 0.2
	player.global_position = stand_w
	var look:= at_w - player.eye_position()
	player.set_look(atan2(- look.x, - look.z),
		atan2(look.y, Vector2(look.x, look.z).length()))


func _arms_full(carry: CarryTool) -> void:
	carry.arms_full += 1
	carry.full_msec = Time.get_ticks_msec()
	carry.full_cap = carry.stack_capacity()


func _seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
