class_name DevFirstNeedleProbe
extends Node


var world: Node3D

var _fail:= 0


func run() -> void:
	print("\n=== first needle ===")
	_stopwatch_case()
	_legacy_case()
	_best_case()
	_format_case()
	_tab_case()
	_wiring_case()
	print("=== first needle: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _stopwatch_case() -> void:
	GameState.reset(5151, 1000.0)
	if not GameState.run_timed or GameState.run_secs != 0.0 or GameState.first_needle_secs >= 0.0:
		_bad("a new game does not start the stopwatch at zero with no time on it")
	GameState.tick_run_clock(83.25)
	if not is_equal_approx(GameState.run_secs, 83.25):
		_bad("the clock read %.2f after 83.25 s of ticks" % GameState.run_secs)
	var first:= NeedleTypes.pool(GameState.lot_tier) [0]
	var second:= NeedleTypes.pool(GameState.lot_tier) [1]
	GameState.discover(first, Vector3.ZERO)
	if not is_equal_approx(GameState.first_needle_secs, 83.25):
		_bad("the first needle into the case recorded %.2f, expected 83.25"
			% GameState.first_needle_secs)
	GameState.tick_run_clock(40.0)
	GameState.discover(second, Vector3.ZERO)
	if not is_equal_approx(GameState.first_needle_secs, 83.25):
		_bad("a SECOND discovery moved the time to %.2f" % GameState.first_needle_secs)


	var d:= GameState.to_dict()
	GameState.run_secs = 0.0
	GameState.first_needle_secs = -1.0
	GameState.from_dict(d)
	if not GameState.run_timed or not is_equal_approx(GameState.run_secs, 123.25) or not is_equal_approx(GameState.first_needle_secs, 83.25):
		_bad("the stopwatch did not survive a save round trip (timed %s, %.2f, %.2f)"
			% [GameState.run_timed, GameState.run_secs, GameState.first_needle_secs])
	print("  stopwatch: stops on the first needle into the case, and keeps through a save")


func _legacy_case() -> void:
	GameState.reset(5152, 1000.0)
	var d:= GameState.to_dict()
	d.erase("run_secs")
	d.erase("first_needle_secs")
	d.erase("run_timed")
	GameState.from_dict(d)
	if GameState.run_timed:
		_bad("a save with no clock in it loads as a timed run")
	GameState.tick_run_clock(5.0)
	GameState.discover(NeedleTypes.pool(GameState.lot_tier) [0], Vector3.ZERO)
	if GameState.first_needle_secs >= 0.0:
		_bad("an untimed run was given a first needle time of %.2f"
			% GameState.first_needle_secs)

	GameState.from_dict(GameState.to_dict())
	if GameState.run_timed:
		_bad("an untimed run came back timed after one save by this build")
	print("  legacy: a run from before the clock is never timed")


func _best_case() -> void:

	var cases:= [
		[0.0, 0.0, 0.0],
		[0.0, -1.0, 0.0],
		[0.0, 95.0, 95.0],
		[95.0, 0.0, 95.0],
		[95.0, -1.0, 95.0],
		[95.0, 60.5, 60.5],
		[60.5, 95.0, 60.5],
	]
	for c: Array in cases:
		var got:= Profile.better_time(c [0], c [1])
		if not is_equal_approx(got, c [2]):
			_bad("better_time(%s, %s) is %s, expected %s" % [c [0], c [1], got, c [2]])
	print("  career best: only ever comes down, and never to nothing")


func _format_case() -> void:
	var saved_locale:= TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var cases:= [
		[65.34, "1m 05s"],
		[9.99, "9s"],
		[600.0, "10m 00s"],
		[3725.0, "1h 02m 05s"],
	]
	for c: Array in cases:
		var got:= Leaderboard.format_value("stopwatch", c [0])
		if got != c [1]:
			_bad("a time of %s s prints as '%s', expected '%s'" % [c [0], got, c [1]])
	if Leaderboard.format_value("stopwatch", 0.0) != Cfg.tr("no time yet"):
		_bad("no time at all prints as a time, which reads as the fastest on the board")
	TranslationServer.set_locale(saved_locale)
	print("  format: hours, minutes and seconds; no time says so")


func _tab_case() -> void:
	var saved_locale:= TranslationServer.get_locale()
	var w:= LeaderboardPanel.tab_width()
	var n:= Leaderboard.BOARDS.size()
	if w * n + LeaderboardPanel.TAB_GAP * (n - 1) > LeaderboardPanel.PANEL_W:
		_bad("%d tabs at %.0f px do not fit the card" % [n, w])
	var font:= UiFont.bold()
	for locale: String in ["en", "de", "pl", "pt", "tr", "zh", "ja", "ko"]:
		TranslationServer.set_locale(locale)
		for b: Dictionary in Leaderboard.BOARDS:
			var text:= tr(str(b ["tab"]))
			var need:= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				LeaderboardPanel.TAB_FONT).x
			if need > w:
				_bad("[%s] tab '%s' needs %.0f px and has %.0f" % [locale, text, need, w])
	TranslationServer.set_locale(saved_locale)
	print("  tabs: %d across at %.0f px, every name fits in en, de, pl, pt, tr, zh, ja and ko" % [n, w])


func _wiring_case() -> void:
	var totals:= Profile.totals()
	var sql:= FileAccess.get_file_as_string("res://tools/supabase/leaderboard.sql")
	if sql == "":
		_bad("could not read tools/supabase/leaderboard.sql")
	for b: Dictionary in Leaderboard.BOARDS:
		var key:= str(b ["key"])
		if not totals.has("p_" + key):
			_bad("board '%s' has no p_%s in Profile.totals(), so the panel's own line reads zero"
				% [key, key])


		var server_keys: Array [String] = []
		if bool(b.get("sized", false)):
			for spec: Dictionary in Cfg.PILE_SIZES:
				server_keys.append(Leaderboard.board_key(b, str(spec ["id"])))
		else:
			server_keys.append(key)
		for server_key: String in server_keys:


			var arms:= sql.count("when '%s'" % server_key)
			if sql != "" and arms != 4:
				_bad("board '%s' appears in %d of the SQL's 4 CASEs" % [server_key, arms])
	if not sql.contains("p_first_needle_secs double precision default 0"):
		_bad("submit_totals takes no time, or takes it without a default for older builds")


	var missing:= { "code": 404, "error": "Could not find the function",
		"data": { "code": "PGRST202", "message": "Could not find the function" } }
	if not Leaderboard.missing_function(missing):
		_bad("a PGRST202 is not recognised, so an old server stops every board updating")
	if Leaderboard.missing_function({ "code": 400, "data": { "message": "implausible submission" } }):
		_bad("an ordinary refusal is read as a missing function and posted twice")
	print("  wiring: %d boards, each in the payload and in every CASE" % Leaderboard.BOARDS.size())


func _bad(line: String) -> void:
	print("  FAIL  %s" % line)
	_fail += 1
