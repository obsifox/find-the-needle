class_name DevBoardPeriodProbe
extends Node


var world: Node3D
var player: Player

var _fail:= 0


const FADE_STEP:= RankBoard.FADE_SECS + 0.01


func run() -> void:
	print("\n=== board periods ===")
	_clock_case()
	_days_case()
	_wiring_case()
	await _wall_case()
	print("=== board periods: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _unix(y: int, mo: int, d: int, h: int = 0, mi: int = 0, s: int = 0) -> int:
	return Time.get_unix_time_from_datetime_dict(
		{ "year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": s })


func _clock_case() -> void:

	var now:= float(_unix(2026, 9, 16, 21, 30, 15))
	var cases:= [
		["day", "2026-09-16", _unix(2026, 9, 17)],
		["week", "2026-09-14", _unix(2026, 9, 21)],
		["month", "2026-09-01", _unix(2026, 10, 1)],
		["all", "", 0],
	]
	for c: Array in cases:
		var start:= Leaderboard.period_start_day(c [0], now)
		var ends:= Leaderboard.period_ends(c [0], now)
		if start != c [1]:
			_bad("%s starts on '%s', not '%s'" % [c [0], start, c [1]])
		if ends != c [2]:
			_bad("%s ends at %d, not %d" % [c [0], ends, c [2]])

	if Leaderboard.period_start_day("week", float(_unix(2026, 9, 14, 0, 0, 1))) != "2026-09-14":
		_bad("Monday is not the start of its own week")
	if Leaderboard.period_start_day("week", float(_unix(2026, 9, 20, 23, 59, 59))) != "2026-09-14":
		_bad("Sunday is not in the week that began on Monday")
	if Leaderboard.period_ends("month", float(_unix(2026, 12, 31, 12))) != _unix(2027, 1, 1):
		_bad("December does not end on the first of January")

	var saved_locale:= TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var said:= LeaderboardPanel.clock_line("day", now)
	if said != "RESETS IN 2h 29m 45s":
		_bad("the daily countdown reads '%s'" % said)
	if LeaderboardPanel.clock_line("all", now) != "NEVER RESETS":
		_bad("ALL TIME reads '%s'" % LeaderboardPanel.clock_line("all", now))
	TranslationServer.set_locale(saved_locale)
	print("  clock: day, week and month start and end in UTC; '%s'" % said)


func _days_case() -> void:
	var kept:= Profile.days
	var today:= Leaderboard.day_key(Time.get_unix_time_from_system())
	var now:= Time.get_unix_time_from_system()
	var yesterday:= Leaderboard.day_key(now - 86400.0)
	var long_ago:= Leaderboard.day_key(now - 60.0 * 86400.0)
	Profile.days = {
		today: { "hay_dug": 100.0, "needles_found": 2, "money_peak": 50.0,
			"first_needle_secs": 900.0, "play_secs": 60, "structures_built": 3,
			"money_earned": 10.0, "pile_clear": { "standard": 4000.0 }, "best_income": 30.0 },
		yesterday: { "hay_dug": 40.0, "needles_found": 1, "money_peak": 80.0,
			"first_needle_secs": 600.0, "play_secs": 30, "structures_built": 1,
			"money_earned": 5.0, "pile_clear": { }, "best_income": 70.0 },
		long_ago: { "hay_dug": 999.0 },
	}
	if Profile.period_value("best_income", "day") != 30.0:
		_bad("today's best minute reads %.1f" % Profile.period_value("best_income", "day"))
	if Profile.period_value("hay_dug", "day") != 100.0:
		_bad("today's hay reads %.1f" % Profile.period_value("hay_dug", "day"))
	if Profile.period_value("needles_found", "month") < 2.0:
		_bad("the month's needles read %.1f" % Profile.period_value("needles_found", "month"))
	if Profile.period_value("first_needle_secs", "day") != 900.0:
		_bad("today's fastest needle reads %.1f" % Profile.period_value("first_needle_secs", "day"))
	if Profile.period_value("pile_clear_standard", "day") != 4000.0:
		_bad("today's standard clear reads %.1f" % Profile.period_value("pile_clear_standard", "day"))
	if Profile.period_value("pile_clear_huge", "day") != 0.0:
		_bad("a size nobody cleared today reads %.1f" % Profile.period_value("pile_clear_huge", "day"))


	if yesterday >= Leaderboard.period_start_day("week", now):
		if Profile.period_value("money_peak", "week") != 80.0:
			_bad("the week's peak reads %.1f" % Profile.period_value("money_peak", "week"))
		if Profile.period_value("first_needle_secs", "week") != 600.0:
			_bad("the week's fastest needle reads %.1f"
				% Profile.period_value("first_needle_secs", "week"))
		if Profile.period_value("best_income", "week") != 70.0:
			_bad("the week's best minute reads %.1f (a best, not a sum)"
				% Profile.period_value("best_income", "week"))
		if Profile.period_value("hay_dug", "week") != 140.0:
			_bad("the week's hay reads %.1f" % Profile.period_value("hay_dug", "week"))

	var payload:= Profile.days_payload()
	var day: Dictionary = payload.get(today, { })
	for key: String in ["play_secs", "needles_found", "structures_built"]:
		if typeof(day.get(key)) != TYPE_INT:
			_bad("%s is posted as type %d, and the server's bigint will refuse it"
				% [key, typeof(day.get(key))])
	if not JSON.stringify(day).contains("\"needles_found\":2"):
		_bad("the day is written as %s" % JSON.stringify(day))
	if not Leaderboard.submit_body().has("p_days"):
		_bad("the post carries no days")


	var landed:= payload.duplicate(true)
	if not Leaderboard.changed_days(payload, landed).is_empty():
		_bad("days that already landed are sent again")
	if Leaderboard.changed_days(payload, { }).size() != payload.size():
		_bad("a first post leaves days out")
	(landed [today] as Dictionary) ["hay_dug"] = -1.0
	var moved:= Leaderboard.changed_days(payload, landed)
	if moved.size() != 1 or not moved.has(today):
		_bad("a changed day is sent as %s" % str(moved.keys()))

	Profile._forget_old_days()
	if Profile.days.has(long_ago):
		_bad("a day sixty days old is still kept")
	if not Profile.days.has(yesterday):
		_bad("yesterday was let go")
	Profile.days = kept
	print("  days: added up per period, old days let go, counters posted as whole numbers")


func _wiring_case() -> void:
	var sql:= FileAccess.get_file_as_string("res://tools/supabase/leaderboard.sql")
	if sql == "":
		_bad("could not read tools/supabase/leaderboard.sql")
		return
	var at:= sql.find("function public.period_values")
	var body:= sql.substr(at, sql.find("$fn$;", at) - at) if at >= 0 else ""
	if body == "":
		_bad("the SQL has no period_values")
	for b: Dictionary in Leaderboard.BOARDS:
		var keys: Array [String] = []
		if bool(b.get("sized", false)):
			for spec: Dictionary in Cfg.PILE_SIZES:
				keys.append(Leaderboard.board_key(b, str(spec ["id"])))
				if not sql.contains("v_d -> 'pile_clear' ->> '%s'" % str(spec ["id"])):
					_bad("store_days never reads the '%s' clear" % str(spec ["id"]))
		else:
			keys.append(str(b ["key"]))
			if not sql.contains("v_d ->> '%s'" % str(b ["key"])):
				_bad("store_days never reads '%s' out of a day" % str(b ["key"]))
		for key: String in keys:
			if not body.contains("when '%s'" % key):
				_bad("board '%s' is not in period_values" % key)
	for spec: Dictionary in Leaderboard.PERIODS:
		var key:= str(spec ["key"])
		if key != Leaderboard.ALL_TIME and not sql.contains("when '%s'" % key):
			_bad("period '%s' has no start in period_start" % key)
	for grant: String in [
			"jsonb, jsonb, double precision) to authenticated",
			"top_period(text, text, int) to anon, authenticated",
			"my_rank_period(text, text) to authenticated"]:
		if not sql.contains(grant):
			_bad("the SQL has no grant '%s'" % grant)

	var was:= Profile.debug_tainted
	Profile.debug_tainted = false
	var clean:= Leaderboard.submit_body()
	Profile.debug_tainted = was
	var shapes:= Leaderboard.bodies_for_older_servers(clean)
	if shapes.size() < 2 or shapes [0].has("p_best_income") or not shapes [0].has("p_days") or shapes [1].has("p_days") or not shapes [1].has("p_pile_clear"):
		_bad("the first two older shapes are not the post without its income, then its days")
	for shape: Dictionary in shapes:
		if shape.has("p_best_income"):
			_bad("an older shape still carries the income board")
	if not clean.has("p_best_income"):
		_bad("the post carries no income per minute")
	if not clean.has("p_days"):
		_bad("building the older shapes changed the post they were built from")
	print("  wiring: %d boards in period_values, %d older shapes" % [
		Leaderboard.BOARDS.size(), shapes.size()])


func _wall_case() -> void:
	var wall:= world.rank_board as RankBoard
	if wall == null:
		_bad("the world built no standing board")
		return
	var found: Array [Dictionary] = []
	for key: String in ["money_earned", "first_needle_secs", "hay_dug"]:
		found.append({ "board": RankBoard.board_by_key(key), "key": key,
			"rank": found.size() * 3 + 1 })
	wall.show_ranks(found)
	var saw:= { }
	saw [wall.under_text()] = true
	var start:= wall.shown_index()


	for i in 24:
		wall._process(1.0)
		if wall._fade != null and wall._fade.is_running():
			wall._fade.custom_step(FADE_STEP)
			if wall._under.transparency < 0.9:
				_bad("the line was not faded out after %.2f s" % FADE_STEP)
			wall._fade.custom_step(FADE_STEP)
		await get_tree().process_frame
		saw [wall.under_text()] = true
	print("  wall: showed %s" % str(saw.keys()))
	if saw.size() < 3:
		_bad("the wall showed %d of the 3 boards it was given" % saw.size())
	if wall.shown_index() == start and saw.size() < 3:
		_bad("the wall never moved off the first board")
	for l: Label3D in [wall._rank_line, wall._under, wall._detail]:
		if l.transparency > 0.01 and (wall._fade == null or not wall._fade.is_running()):
			_bad("a line was left faded at %.2f" % l.transparency)

	var menu:= player.leaderboards
	if menu == null:
		_bad("the player has no leaderboard menu")
	var face: Node3D = wall.face
	var front:= face.to_global(Vector3(0.0, 0.0, 2.0))
	var behind:= face.to_global(Vector3(0.0, 0.0, -2.0))
	var far:= face.to_global(Vector3(0.0, 0.0, 9.0))
	var aim:= wall.board_point()
	if not wall.is_hovered(front, aim - front):
		_bad("E from two metres in front of the slate is not taken")
	if wall.is_hovered(behind, aim - behind):
		_bad("E from behind the wall is taken")
	if wall.is_hovered(far, aim - far):
		_bad("E from nine metres is taken")
	if wall.is_hovered(front, face.global_transform.basis.x):
		_bad("E looking along the wall is taken")
	print("  press: front yes, behind no, far no, along the wall no")


func _bad(line: String) -> void:
	print("  FAIL  %s" % line)
	_fail += 1
