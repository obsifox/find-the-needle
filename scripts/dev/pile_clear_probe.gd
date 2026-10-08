class_name DevPileClearProbe
extends Node


var world: Node3D
var player: Player

var _fail:= 0

var _fired:= 0


func run() -> void:
	print("\n=== pile clear ===")
	GameState.pile_emptied.connect(_count)
	await _settle_case()


	var hf: HayField = world.get("field")
	if hf != null:
		hf._last_of_pile_wait = INF
	await _latch_case()
	await _mountain_case()
	await _field_case()
	_save_case()
	_career_case()
	_board_case()
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--shot")
	if at >= 0 and at + 1 < args.size():
		await _shoot(args [at + 1])
	print("=== pile clear: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _count() -> void:
	_fired += 1


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _asked() -> void:
	await _frames()
	GameState.check_cleared()


func _settle_case() -> void:
	for i in 90:
		await get_tree().process_frame
	if GameState.pile_cleared or _fired > 0:
		_bad("a yard nobody has dug read as cleared (%.0f of %.0f strands never dug)"
			% [GameState.hay_never_dug(), GameState.hay_initial])
	print("  settle: a freshly built yard is not a cleared one")


func _latch_case() -> void:
	GameState.reset(7001, 100000.0)
	_fired = 0
	GameState.tick_run_clock(50.0)
	GameState.remove_hay(99000.0)
	await _asked()
	if GameState.pile_cleared or _fired != 0:
		_bad("a thousand strands left read as cleared")
	GameState.remove_hay(600.0)
	await _asked()
	if not GameState.pile_cleared or _fired != 1:
		_bad("400 strands left did not clear the pile (cleared %s, fired %d)"
			% [GameState.pile_cleared, _fired])


	var first_time:= GameState.first_clear_secs
	if absf(first_time - 50.0) > 0.5:
		_bad("the first clear recorded %.2f, expected about 50" % first_time)
	var first_line:= _toast()
	if not first_line.contains("50s"):
		_bad("the first pile's line was '%s', with no time in it" % first_line)
	if not _has_confetti():
		_bad("no confetti was put in the yard")


	GameState.remove_hay(4.0)
	GameState.return_hay(300.0)
	await _asked()
	if _fired != 1 or not GameState.pile_cleared:
		_bad("hay moving after the clear cheered again or un-cleared the pile (fired %d)"
			% _fired)


	GameState.new_pile(7002, 100000.0)
	if GameState.pile_cleared:
		_bad("a fresh stack arrived already cleared")
	GameState.tick_run_clock(30.0)
	GameState.remove_hay(99600.0)
	await _asked()
	if _fired != 2:
		_bad("two piles dug out cheered %d times, expected 2" % _fired)
	if GameState.first_clear_secs != first_time:
		_bad("the second pile moved the run's clear time from %.2f to %.2f"
			% [first_time, GameState.first_clear_secs])
	var later_line:= _toast()
	if later_line.contains("1m 20s") or later_line == first_line:
		_bad("a later pile's line quotes the run clock as its time: '%s'" % later_line)


	GameState.reset(7003, 100000.0)
	GameState.run_timed = false
	GameState.remove_hay(99999.0)
	await _asked()
	if not GameState.pile_cleared or GameState.first_clear_secs >= 0.0:
		_bad("an untimed run cleared %s with a time of %.2f"
			% [GameState.pile_cleared, GameState.first_clear_secs])
	print("  latch: once a pile, the run's first is timed, a new stack re-arms it")
	print("  world: '%s', then '%s', and confetti in the yard" % [first_line, later_line])


func _mountain_case() -> void:
	var tipped:= 316000000.0
	GameState.reset(7005, tipped)
	_fired = 0
	for left: float in [3000000.0, 550220.0]:
		GameState.remove_hay(GameState.hay_never_dug() - left)
		await _asked()
		if GameState.pile_cleared or _fired != 0:
			_bad("%s left of %s read as cleared" % [Hud.fmt(left), Hud.fmt(tipped)])
	GameState.remove_hay(GameState.hay_never_dug() - Cfg.PILE_CLEAR_STRANDS * 0.8)
	await _asked()
	if not GameState.pile_cleared or _fired != 1:
		_bad("%s left of the mountain did not clear (cleared %s, fired %d)"
			% [Hud.fmt(GameState.hay_never_dug()), GameState.pile_cleared, _fired])
	print("  mountain: not at 3,000,000 or 550,220, cleared at %s"
		% Hud.fmt(Cfg.PILE_CLEAR_STRANDS * 0.8))


func _field_case() -> void:
	var hf: HayField = world.get("field")
	if hf == null:
		_bad("no field to test the drifted ledger against")
		return
	var real:= hf.measure_strands()
	GameState.reset(7006, real)
	_fired = 0
	GameState.remove_hay(real - 100.0)
	hf._last_of_pile_seen = INF
	hf._last_of_pile_wait = 0.0
	for i in int(HayField.LAST_OF_PILE_EVERY * 60.0) + 30:
		await get_tree().process_frame
	hf._last_of_pile_wait = INF
	if GameState.pile_cleared or _fired != 0:
		_bad("a ledger of 100 over a field of %s cheered" % Hud.fmt(real))
	if GameState.hay_never_dug() < real * 0.9:
		_bad("the ledger was left at %s over a field of %s"
			% [Hud.fmt(GameState.hay_never_dug()), Hud.fmt(real)])
	print("  field: a ledger of 100 over %s standing was matched to %s, no cheer"
		% [Hud.fmt(real), Hud.fmt(GameState.hay_never_dug())])


	var nv:= Cfg.field_verts()
	for k in hf.heights.size():
		if hf.heights [k] > RoboticArm.FIELD_FLOOR:
			hf.heights [k] = RoboticArm.FIELD_FLOOR
			hf._touch_vertex(k % nv, k / nv)
	for c in hf.chunks:
		c.rebuild_collision()
	var film:= hf.measure_strands()
	GameState.reset(7007, real)
	_fired = 0
	GameState.remove_hay(real - film)
	hf._last_of_pile_seen = INF
	hf._last_of_pile_wait = 0.0
	for i in int(HayField.LAST_OF_PILE_EVERY * 60.0) + 30:
		await get_tree().process_frame
	hf._last_of_pile_wait = INF
	if not GameState.pile_cleared or _fired != 1:
		_bad("a bare film of %s strands did not clear (left %s, fired %d)"
			% [Hud.fmt(film), Hud.fmt(GameState.hay_never_dug()), _fired])
	print("  film: %s strands of stubble with nothing standing swept to %s and cheered"
		% [Hud.fmt(film), Hud.fmt(GameState.hay_never_dug())])


func _save_case() -> void:
	GameState.reset(7004, 1000.0)
	GameState.tick_run_clock(12.5)
	GameState.remove_hay(995.0)
	GameState.check_cleared()
	var d:= GameState.to_dict()
	GameState.first_clear_secs = -1.0
	GameState.pile_cleared = false
	GameState.from_dict(d)
	if not GameState.pile_cleared or not is_equal_approx(GameState.first_clear_secs, 12.5):
		_bad("the clear did not survive a save round trip (cleared %s, %.2f)"
			% [GameState.pile_cleared, GameState.first_clear_secs])


	d.erase("first_clear_secs")
	d.erase("pile_cleared")
	GameState.from_dict(d)
	if not GameState.pile_cleared:
		_bad("an old save of a dug out yard would cheer again on its load")
	if GameState.first_clear_secs >= 0.0:
		_bad("an old save was handed a clear time of %.2f" % GameState.first_clear_secs)

	d ["hay_total"] = 800.0
	GameState.from_dict(d)
	if GameState.pile_cleared:
		_bad("an old save with its pile standing loaded as cleared")
	print("  save: the time and the latch come back, and an old empty yard stays quiet")


func _career_case() -> void:
	var was: Dictionary = Profile.pile_clear_secs.duplicate()
	Profile.pile_clear_secs = { "standard": 90.0, "mountain": 86400.0 }
	if not is_equal_approx(Profile.board_value("pile_clear_standard"), 90.0):
		_bad("the STANDARD best reads %.2f, expected 90" % Profile.board_value("pile_clear_standard"))
	if Profile.board_value("pile_clear_big") != 0.0:
		_bad("a size with no time reads %.2f" % Profile.board_value("pile_clear_big"))
	if not is_equal_approx(Profile.board_value("first_needle_secs"), Profile.first_needle_secs):
		_bad("an unsized board no longer reads through board_value")
	var sent: Dictionary = Profile.totals().get("p_pile_clear", { })
	if not is_equal_approx(float(sent.get("mountain", 0.0)), 86400.0):
		_bad("the post carries %s for the clear times" % str(sent))
	Profile.pile_clear_secs = was
	print("  career: one best for each size, in the post and on the player's own line")


func _board_case() -> void:
	var board: Dictionary = { }
	for b: Dictionary in Leaderboard.BOARDS:
		if str(b ["key"]) == "pile_clear":
			board = b
	if board.is_empty() or not bool(board.get("sized", false)):
		_bad("there is no sized pile_clear board")
	if Leaderboard.board_key(board, "huge") != "pile_clear_huge":
		_bad("the HUGE board is asked for as '%s'" % Leaderboard.board_key(board, "huge"))

	var sql:= FileAccess.get_file_as_string("res://tools/supabase/leaderboard.sql")
	if sql == "":
		_bad("could not read tools/supabase/leaderboard.sql")
	for spec: Dictionary in Cfg.PILE_SIZES:
		var id:= str(spec ["id"])
		var arms:= sql.count("when 'pile_clear_%s'" % id)

		if arms != 4:
			_bad("size '%s' appears in %d of the SQL's 4 CASEs" % [id, arms])
		if not sql.contains("add column if not exists pile_clear_%s " % id):
			_bad("the SQL has no column for size '%s'" % id)
		if not sql.contains("p_pile_clear ->> '%s'" % id):
			_bad("submit_totals never reads the '%s' time out of the post" % id)
	if not sql.contains("boolean, jsonb, jsonb, double precision) to authenticated"):
		_bad("the grant is not on the thirteen argument submit_totals")

	var was:= Profile.debug_tainted
	Profile.debug_tainted = false
	var clean:= Leaderboard.submit_body()
	Profile.debug_tainted = true
	var locked:= Leaderboard.submit_body()
	Profile.debug_tainted = was
	if not clean.has("p_pile_clear"):
		_bad("the post carries no clear times")


	var shapes:= Leaderboard.bodies_for_older_servers(clean)
	if shapes.size() != 4 or shapes [2].has("p_pile_clear") or not shapes [2].has("p_debug_used") or shapes [3].has("p_pile_clear") or shapes [3].has("p_career_epoch"):
		_bad("the older shapes of a clean post are wrong: %s" % str(shapes))
	if Leaderboard.bodies_for_older_servers(locked).size() != 3:
		_bad("a locked game has a shape for a server that cannot hide it")
	if not clean.has("p_pile_clear"):
		_bad("building the older shapes changed the post they were built from")

	var saved_locale:= TranslationServer.get_locale()
	TranslationServer.set_locale("en")

	var cases:= [
		["time", 88225.0, "24h 30m 25s"],
		["time", 3600.0, "1h 00m 00s"],
		["time", 65.0, "1m 05s"],
		["time", 42.9, "42s"],
		["time", 0.0, "0s"],
		["stopwatch", 5231.4, "1h 27m 11s"],
	]
	for c: Array in cases:
		var got:= Leaderboard.format_value(c [0], c [1])
		if got != c [2]:
			_bad("%s of %s s prints as '%s', expected '%s'" % [c [0], c [1], got, c [2]])
	TranslationServer.set_locale(saved_locale)
	print("  board: every size in every CASE, older servers covered, times as 24h 30m 25s")


func _shoot(out_dir: String) -> void:
	GameState.reset(7005, 1000.0)
	var inner: float = world.warehouse.inner
	var at:= Vector3(0.0, 2.2, inner - 1.5)
	var target:= Vector3(0.0, 3.5, 0.0)


	var hf: Variant = world.get("field")
	if hf is Node3D:
		hf.visible = false
	player.global_position = at
	player.look_at_from_position(at, target, Vector3.UP)
	var pitch:= atan2(target.y - at.y, Vector2(target.x - at.x, target.z - at.z).length())
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = pitch
	await _frames()
	GameState.remove_hay(999.0)
	GameState.check_cleared()
	var waits:= [0.6, 0.9, 1.5]
	for i in waits.size():
		await get_tree().create_timer(float(waits [i])).timeout
		await RenderingServer.frame_post_draw
		var img:= get_viewport().get_texture().get_image()
		var path:= "%s/pile_clear_%d.png" % [out_dir, i]
		img.save_png(path)
		print("[pileclear] wrote %s" % path)


func _toast() -> String:
	var hud: Variant = world.get("hud")
	if hud == null:
		return ""
	return str(hud.toast_text())


func _has_confetti() -> bool:
	for c in world.get_children():
		if c is PileClearedVfx:
			return true
	return false


func _bad(line: String) -> void:
	print("  FAIL  %s" % line)
	_fail += 1
