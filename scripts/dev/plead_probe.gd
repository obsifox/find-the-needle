class_name DevPleadProbe
extends Node


var world: Node3D
var player: Player

var _fails:= 0


var _yard:= true


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run(out_dir: String) -> void:
	call_deferred("_run", out_dir)


func _run(out_dir: String) -> void:
	world.block_save = true
	for i in 10:
		await get_tree().process_frame

	var missions: MissionDirector = world.missions
	missions.process_mode = Node.PROCESS_MODE_DISABLED
	var card: QuestPanel = world.quests
	card.in_yard = func() -> bool: return _yard


	var was_hud:= Cfg.no_hud
	var was_missions:= Cfg.show_missions
	Cfg.no_hud = false
	Cfg.no_hud_changed.emit(false)
	Cfg.show_missions = true
	Cfg.show_missions_changed.emit(true)
	var shots:= out_dir != "" and DisplayServer.get_name() != "headless"

	print("\n[plead] a fresh step")
	card.show_step(2)
	await _frames(5)
	_ok(not card._bubble.visible, "a fresh step says nothing")
	_ok(is_equal_approx(card._plate_sb.border_color.a, QuestPanel.RULE_ALPHA),
		"...and its gold rule sits still")
	card._stuck_for = QuestPanel.PLEAD_AFTER * 0.25
	await _frames(20)
	_ok(is_equal_approx(card._plate_sb.border_color.a, QuestPanel.RULE_ALPHA),
		"a couple of minutes in, still nothing")

	print("\n[plead] lonely")
	card._stuck_for = QuestPanel.LONELY_AFTER + 0.5
	await _frames(40)
	_ok(not card._bubble.visible, "five minutes does not ask yet")
	_ok(card._plate_sb.border_color.a > QuestPanel.RULE_ALPHA + 0.03,
		"...but the rule breathes (alpha %.2f)" % card._plate_sb.border_color.a)
	if shots:
		await _shot(out_dir, "plead_lonely.png")

	_yard = false
	var held:= card._stuck_for
	await _frames(15)
	_ok(is_equal_approx(card._stuck_for, held), "the clock stops while a menu is open")
	_ok(is_equal_approx(card._plate_sb.border_color.a, QuestPanel.RULE_ALPHA),
		"...and the rule stops breathing behind it")
	card._stuck_for = QuestPanel.PLEAD_AFTER + 1.0
	await _frames(5)
	_ok(not card._bubble.visible, "a plea never starts behind a menu")
	_yard = true

	print("\n[plead] the plea")
	card._stuck_for = QuestPanel.PLEAD_AFTER - 0.01
	await _frames(3)
	_ok(card._bubble.visible, "ten minutes asks")
	_ok(card._pleas == 1, "...once")
	_ok(card._stuck_for < 1.0, "...and starts the clock again")
	_ok(card._plea.text.contains("in a while") and not card._plea.text.contains("["),
		"...in plain words, with nothing wobbling")
	_ok(card._plea_hint.text.contains("OPTIONS") and card._plea_hint.text.contains("GAMEPLAY"),
		"...and says where missions are turned off")
	_ok(card._plea.visible_characters < card._plea.get_total_character_count(),
		"the line is typed, not dropped in whole")
	await get_tree().create_timer(3.6).timeout
	_ok(card._plea.visible_characters >= card._plea.get_total_character_count(),
		"...and finished typing in a few seconds (%d of %d)"
			% [card._plea.visible_characters, card._plea.get_total_character_count()])
	_ok(card._plea_hint.modulate.a > 0.9, "...with the switch line under it")
	_ok(is_zero_approx(card._panel.rotation), "the card never tilts")
	if shots:
		await _shot(out_dir, "plead_bubble.png")

	print("\n[plead] the bar moving")
	card.show_progress({ "have": 5.0, "need": 10.0, "text": "5 / 10" })
	card._stuck_for = 100.0
	card.show_progress({ "have": 4.0, "need": 10.0, "text": "4 / 10" })
	_ok(is_equal_approx(card._stuck_for, 100.0) and card._bubble.visible,
		"a dip in the bar is not progress")
	card.show_progress({ "have": 6.0, "need": 10.0, "text": "6 / 10" })
	_ok(is_zero_approx(card._stuck_for), "the bar passing its best starts the clock again")
	_ok(not card._bubble.visible, "...and shuts the bubble at once")
	card.show_progress({ })

	print("\n[plead] going away by itself")
	card._stuck_for = QuestPanel.PLEAD_AFTER
	await _frames(3)
	_ok(card._bubble.visible and card._pleas == 2, "the second plea")
	await get_tree().create_timer(12.5).timeout
	_ok(not card._bubble.visible, "...fades out on its own")
	await _frames(2)
	_ok(is_equal_approx(card._plate_sb.border_color.a, QuestPanel.RULE_ALPHA),
		"...and the rule goes quiet with it")

	print("\n[plead] never more than three")
	card._stuck_for = QuestPanel.PLEAD_AFTER
	await _frames(3)
	_ok(card._pleas == 3, "the third plea")
	card._hush()
	card._stuck_for = QuestPanel.PLEAD_AFTER + 5.0
	await _frames(20)
	_ok(not card._bubble.visible and card._pleas == 3, "there is no fourth")
	_ok(is_equal_approx(card._plate_sb.border_color.a, QuestPanel.RULE_ALPHA),
		"...and no breathing after the last one")

	print("\n[plead] a new step")
	card.show_step(3)
	_ok(card._pleas == 0 and is_zero_approx(card._stuck_for),
		"a new step starts with an empty clock and its pleas back")

	print("\n[plead] missions turned off")
	card._stuck_for = QuestPanel.LONELY_AFTER + 10.0
	Cfg.show_missions = false
	Cfg.show_missions_changed.emit(false)
	held = card._stuck_for
	await _frames(15)
	_ok(is_equal_approx(card._stuck_for, held), "the clock stops with missions off")
	card._stuck_for = QuestPanel.PLEAD_AFTER + 1.0
	await _frames(5)
	_ok(not card._bubble.visible and card._pleas == 0, "...and nothing asks")
	Cfg.show_missions = true
	Cfg.show_missions_changed.emit(true)

	print("\n[plead] a step that is a wait")
	card.show_step(MissionBook.index_of("first_needle"))
	await _frames(3)
	card._stuck_for = QuestPanel.LONELY_AFTER + 10.0
	held = card._stuck_for
	await _frames(15)
	_ok(is_equal_approx(card._stuck_for, held), "the clock stops on Find a needle")
	_ok(is_equal_approx(card._plate_sb.border_color.a, QuestPanel.RULE_ALPHA),
		"...and the rule does not breathe")
	card._stuck_for = QuestPanel.PLEAD_AFTER + 1.0
	await _frames(5)
	_ok(not card._bubble.visible and card._pleas == 0, "...and nothing asks")
	for id: String in ["first_contract", "build_drone", "extend_shed"]:
		_ok(not MissionBook.pleads(MissionBook.index_of(id)), "%s never asks" % id)
	for id: String in ["first_hay", "rake_throw", "detector_power", "bank_needle"]:
		_ok(MissionBook.pleads(MissionBook.index_of(id)), "%s still asks" % id)
	card.show_step(3)
	await _frames(3)

	print("\n[plead] finishing the step")
	card._stuck_for = QuestPanel.PLEAD_AFTER
	await _frames(3)
	_ok(card._bubble.visible, "a plea is up")
	card.mark_complete("probe")
	_ok(not card._bubble.visible and is_zero_approx(card._panel.rotation),
		"finishing the step takes it away mid sentence")

	card.in_yard = card._in_yard
	missions.process_mode = Node.PROCESS_MODE_INHERIT
	Cfg.show_missions = was_missions
	Cfg.show_missions_changed.emit(was_missions)
	Cfg.no_hud = was_hud
	Cfg.no_hud_changed.emit(was_hud)

	print("\n[plead] %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(out_dir: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
