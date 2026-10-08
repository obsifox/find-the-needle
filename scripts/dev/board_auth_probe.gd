class_name DevBoardAuthProbe
extends Node


var world: Node3D
var player: Player

var _fail:= 0


func run() -> void:
	print("\n=== board auth ===")
	if Leaderboard.enabled:
		_bad("the boards are enabled in a headless run, which they must never be")
	_rejection_case()
	_signup_case()
	_latch_case()
	_key_case()
	_landed_case()
	_body_case()
	print("=== board auth: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _rejection_case() -> void:

	var rejections:= [
		{ "code": 400, "error": "Invalid Refresh Token: Already Used",
			"data": { "error": "invalid_grant",
				"error_description": "Invalid Refresh Token: Already Used" } },
		{ "code": 400, "error": "refresh_token_not_found",
			"data": { "error_code": "refresh_token_not_found",
				"msg": "Invalid Refresh Token: Refresh Token Not Found" } },
		{ "code": 401, "error": "invalid_grant", "data": { "error": "invalid_grant" } },
	]


	var survivable:= [
		{ "code": 0, "error": "could not reach the server", "data": null },
		{ "code": 0, "error": "the server did not answer in time", "data": null },
		{ "code": 0, "error": "no internet connection", "data": null },
		{ "code": 429, "error": "HTTP 429", "data": null },
		{ "code": 500, "error": "HTTP 500", "data": null },
		{ "code": 502, "error": "HTTP 502", "data": null },
		{ "code": 503, "error": "HTTP 503", "data": null },
		{ "code": 504, "error": "the server did not answer in time", "data": null },


		{ "code": 400, "error": "that name is taken",
			"data": { "message": "that name is taken" } },
	]
	for r: Dictionary in rejections:
		if not Leaderboard.session_rejected(r):
			_bad("HTTP %d '%s' is not read as a rejected session, so a dead token would be kept forever"
				% [int(r ["code"]), str(r ["error"])])
	for r: Dictionary in survivable:
		if Leaderboard.session_rejected(r):
			_bad("HTTP %d '%s' is read as a rejected session, which would throw the player's account away"
				% [int(r ["code"]), str(r ["error"])])
	print("  %d rejections and %d survivable failures, all read correctly"
		% [rejections.size(), survivable.size()])


func _signup_case() -> void:

	var cases:= [

		[true, false, true],
		[true, true, true],


		[false, false, true],


		[false, true, false],
	]
	for c: Array in cases:
		var got:= Leaderboard.may_sign_up(c [0], c [1])
		if got != c [2]:
			_bad("may_sign_up(allow %s, lost %s) says %s, expected %s"
				% [c [0], c [1], got, c [2]])
	print("  signup gate: a background caller is refused once a session is lost")


func _latch_case() -> void:
	if not ("session_lost" in Profile):
		_bad("Profile has no session_lost latch")
		return


	var src:= FileAccess.get_file_as_string("res://autoload/profile.gd")
	if not src.contains("cf.set_value(\"identity\", \"session_lost\""):
		_bad("session_lost is never written to profile.cfg, so a lost session comes back as a signup on the next launch")
	if not src.contains("cf.get_value(\"identity\", \"session_lost\""):
		_bad("session_lost is never read back out of profile.cfg")
	print("  latch: session_lost is on Profile and is saved and loaded")


func _key_case() -> void:
	if not ("install_key" in Profile):
		_bad("Profile has no install_key")
		return
	var src:= FileAccess.get_file_as_string("res://autoload/profile.gd")
	if not src.contains("cf.set_value(\"identity\", \"install_key\""):
		_bad("install_key is never written to profile.cfg")
	if not src.contains("cf.get_value(\"identity\", \"install_key\""):
		_bad("install_key is never read back out of profile.cfg")
	var board:= FileAccess.get_file_as_string("res://autoload/leaderboard.gd")
	if board.contains("install_key = \"\""):
		_bad("the leaderboard clears the install key, so a lost session can never reclaim its row")
	if not board.contains("\"claim_player_key\""):
		_bad("sign in never sends the install key")
	var sql:= FileAccess.get_file_as_string("res://tools/supabase/leaderboard.sql")
	if not sql.contains("on update cascade"):
		_bad("player_days does not follow a reclaimed row to its new user_id")
	print("  key: install_key is saved, loaded, never cleared, and sent on sign in")


func _landed_case() -> void:

	var cases:= [

		[true, true, true],


		[true, false, false],

		[true, null, true],

		[false, null, false],
		[false, true, false],
	]
	for c: Array in cases:
		var got:= Leaderboard.submit_landed({ "ok": c [0], "data": c [1] })
		if got != c [2]:
			_bad("submit_landed(ok %s, data %s) says %s, expected %s"
				% [c [0], c [1], got, c [2]])
	print("  submit: a rate limited post is not taken for a landed one")


func _body_case() -> void:
	var was:= Profile.debug_tainted
	Profile.debug_tainted = false
	var clean:= Leaderboard.submit_body()
	Profile.debug_tainted = true
	var locked:= Leaderboard.submit_body()
	Profile.debug_tainted = was

	if clean.get("p_debug_used") != false:
		_bad("a clean game posts with p_debug_used %s, and its row would be hidden"
			% str(clean.get("p_debug_used")))
	if locked.get("p_debug_used") != true:
		_bad("a locked game posts without saying so, and its numbers would land on the boards")
	if int(locked.get("p_career_epoch", 0)) != Profile.CAREER_EPOCH:
		_bad("the post carries epoch %s, not %d" % [str(locked.get("p_career_epoch")),
			Profile.CAREER_EPOCH])

	var older:= Leaderboard.body_for_older_server(clean)
	if older.is_empty() or older.has("p_career_epoch") or older.has("p_debug_used"):
		_bad("a clean game's post to an older server is %s" % str(older.keys()))
	if not clean.has("p_career_epoch"):
		_bad("building the older post changed the one it was built from")
	if not Leaderboard.body_for_older_server(locked).is_empty():
		_bad("a locked game posts to a server with no column to hide it")
	print("  submit: a locked game posts flagged, and never to a server that cannot hide it")


func _bad(line: String) -> void:
	print("  FAIL  %s" % line)
	_fail += 1
