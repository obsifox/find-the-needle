extends Node


const URL:= "https://obyylvzazdxkmnpsnsed.supabase.co"
const KEY:= "sb_publishable_p2k3g8tCOi4b6j_A0UqDug_t8ud7qtZ"


const BOARDS:= [
	{ "key": "money_peak", "tab": "RICHEST", "title": "RICHEST YARD", "kind": "money" },
	{ "key": "money_earned", "tab": "EARNED", "title": "MOST MONEY EARNED", "kind": "money" },
	{ "key": "best_income", "tab": "$/MIN", "title": "BIGGEST INCOME PER MINUTE", "kind": "money" },
	{ "key": "hay_dug", "tab": "HAY DUG", "title": "TOTAL HAY DUG", "kind": "count" },
	{ "key": "needles_found", "tab": "NEEDLES", "title": "NEEDLES FOUND", "kind": "count" },
	{ "key": "first_needle_secs", "tab": "FASTEST", "title": "FASTEST FIRST NEEDLE", "kind": "stopwatch" },
	{ "key": "pile_clear", "tab": "CLEARED", "title": "FASTEST PILE CLEAR", "kind": "stopwatch", "sized": true },
	{ "key": "structures_built", "tab": "BUILT", "title": "STRUCTURES BUILT", "kind": "count" },
	{ "key": "play_secs", "tab": "TIME", "title": "TIME PLAYED", "kind": "time" },
]


const PERIODS:= [
	{ "key": "day", "tab": "DAILY" },
	{ "key": "week", "tab": "WEEKLY" },
	{ "key": "month", "tab": "MONTHLY" },
	{ "key": "all", "tab": "ALL TIME" },
]
const ALL_TIME:= "all"


const REFRESH_MARGIN:= 300.0

signal signed_in(name: String)
signal submitted()
signal failed(what: String, message: String)


signal viewed()


var enabled:= true

signal auth_finished(ok: bool)

var _access_token:= ""
var _expires_at:= 0.0
var _signing_in:= false

var _key_claimed:= false


var _auth_busy:= false


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		enabled = false
		return


var _landed_days:= { }


static func changed_days(posted: Dictionary, landed: Dictionary) -> Dictionary:
	var out:= { }
	for key: String in posted:
		if not landed.has(key) or landed [key] != posted [key]:
			out [key] = posted [key]
	return out


func sign_in() -> bool:
	if not enabled or _signing_in:
		return false
	_signing_in = true
	var ok:= await _authenticate(true)
	_signing_in = false
	if not ok:
		return false
	var res:= await _claim()
	if not res.ok:
		failed.emit("sign_in", res.error)
		return false
	signed_in.emit(Profile.board_name)
	return true


func _claim() -> Dictionary:
	Profile.ensure_install_key()
	var res:= await _rpc("claim_player_key", { "p_key": Profile.install_key }, true)
	if not res.ok and missing_function(res):
		res = await _rpc("claim_player", { }, true)
	if not res.ok:
		return res


	_key_claimed = true
	var row: Dictionary = res.data [0] if res.data is Array and not res.data.is_empty() else { }
	Profile.set_identity(Profile.refresh_token,
		str(row.get("name", "")), bool(row.get("name_changed", false)))
	if bool(row.get("reclaimed", false)):
		print("[leaderboard] took the old row back as %s" % Profile.board_name)
	return res


func _authenticate(allow_signup: bool = false) -> bool:
	_adopt_stored_access()
	if _access_token != "" and Time.get_unix_time_from_system() < _expires_at - REFRESH_MARGIN:
		return true


	if _auth_busy:
		return await auth_finished
	_auth_busy = true
	var ok:= await _do_authenticate(allow_signup)
	_auth_busy = false
	auth_finished.emit(ok)
	return ok


func _do_authenticate(allow_signup: bool) -> bool:
	var res: Dictionary = { }
	if Profile.refresh_token != "":
		res = await _refresh_session(Profile.refresh_token)
		if not res.ok:
			return false

	if Profile.refresh_token == "":
		if not may_sign_up(allow_signup, Profile.session_lost):


			return false
		res = await _http("%s/auth/v1/signup" % URL, { }, false)
		if res.ok:
			Profile.session_lost = false

	if not res.ok:
		failed.emit("auth", res.error)
		return false
	_keep(res)
	return _access_token != ""


func _refresh_session(token: String) -> Dictionary:
	var res:= await _post_refresh(token)
	if res.ok:
		return res
	if not session_rejected(res):


		failed.emit("auth", res.error)
		return res

	var disk:= Profile.stored_refresh_token()
	if disk != "" and disk != token:
		Profile.refresh_token = disk
		res = await _post_refresh(disk)
		if res.ok:
			return res
		if not session_rejected(res):
			failed.emit("auth", res.error)
			return res

	push_warning("[leaderboard] the server rejected this session; open the leaderboards to sign in again")
	Profile.refresh_token = ""
	Profile.board_name = ""
	Profile.session_lost = true
	Profile.save_profile()
	return res


func _post_refresh(token: String) -> Dictionary:
	return await _http("%s/auth/v1/token?grant_type=refresh_token" % URL,
		{ "refresh_token": token }, false)


static func may_sign_up(allow_signup: bool, session_lost: bool) -> bool:
	return allow_signup or not session_lost


static func session_rejected(res: Dictionary) -> bool:
	var code:= int(res.get("code", 0))
	if code != 400 and code != 401:
		return false
	var d: Variant = res.get("data")
	var said:= str(res.get("error", ""))
	if d is Dictionary:
		var body: Dictionary = d
		said = "%s %s %s %s" % [said, body.get("error", ""),
			body.get("error_code", ""), body.get("error_description", "")]
	said = said.to_lower()
	for phrase in ["invalid_grant", "refresh_token_not_found",
			"refresh_token_already_used", "invalid refresh token",
			"already used"]:
		if said.contains(phrase):
			return true
	return false


func _keep(res: Dictionary) -> void:
	var d: Dictionary = res.data if res.data is Dictionary else { }
	_access_token = str(d.get("access_token", ""))
	_expires_at = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	Profile.refresh_token = str(d.get("refresh_token", Profile.refresh_token))


	Profile.access_token = _access_token
	Profile.access_expires_at = _expires_at
	Profile.access_for = Profile.refresh_token
	Profile.save_profile()


func _adopt_stored_access() -> void:
	if _access_token != "" or Profile.access_token == "":
		return
	if Profile.refresh_token == "" or Profile.access_for != Profile.refresh_token:
		return
	_access_token = Profile.access_token
	_expires_at = Profile.access_expires_at


func rename(new_name: String) -> Dictionary:
	if not enabled:
		return { "ok": false, "error": tr("leaderboard is off") }
	if not await _authenticate():
		return { "ok": false, "error": tr("could not sign in") }
	var res:= await _rpc("rename_player", { "p_name": new_name }, true)
	if not res.ok:
		failed.emit("rename", res.error)
		return { "ok": false, "error": res.error }
	Profile.set_identity(Profile.refresh_token, str(res.data), true)
	return { "ok": true, "name": Profile.board_name }


func submit() -> bool:
	if not enabled:
		return false
	if not await _authenticate():
		return false


	if not _key_claimed:
		await _claim()
	var body:= submit_body()
	var all_days: Dictionary = body.get("p_days", { })
	body ["p_days"] = changed_days(all_days, _landed_days)
	var res:= await _rpc("submit_totals", body, true)


	for older: Dictionary in bodies_for_older_servers(body):
		if res.ok or not missing_function(res):
			break
		res = await _rpc("submit_totals", older, true)
	if not res.ok and missing_function(res):


		return false
	if not res.ok:
		failed.emit("submit", res.error)
		return false
	if not submit_landed(res):
		_retry_after_limit()
		return false


	_landed_days = all_days
	submitted.emit()
	return true


static func submit_body() -> Dictionary:
	var body:= Profile.totals()
	body ["p_build"] = _build_string()


	body ["p_career_epoch"] = Profile.CAREER_EPOCH
	body ["p_debug_used"] = Profile.debug_tainted
	return body


static func body_for_older_server(body: Dictionary) -> Dictionary:
	if bool(body.get("p_debug_used", false)):
		return { }
	var older:= body.duplicate()
	older.erase("p_career_epoch")
	older.erase("p_debug_used")
	older.erase("p_pile_clear")
	older.erase("p_days")
	older.erase("p_best_income")
	return older


static func body_without_best_income(body: Dictionary) -> Dictionary:
	var out:= body.duplicate()
	out.erase("p_best_income")
	return out


static func body_without_days(body: Dictionary) -> Dictionary:
	var out:= body_without_best_income(body)
	out.erase("p_days")
	return out


static func body_without_pile_clear(body: Dictionary) -> Dictionary:
	var out:= body_without_days(body)
	out.erase("p_pile_clear")
	return out


static func bodies_for_older_servers(body: Dictionary) -> Array [Dictionary]:
	var out: Array [Dictionary] = [body_without_best_income(body), body_without_days(body),
		body_without_pile_clear(body)]
	var older:= body_for_older_server(body)
	if not older.is_empty():
		out.append(older)
	return out


static func board_key(board: Dictionary, size_id: String = "") -> String:
	var key:= str(board.get("key", ""))
	if bool(board.get("sized", false)):
		return "%s_%s" % [key, size_id if size_id != "" else Cfg.DEFAULT_PILE_SIZE]
	return key


const RATE_LIMIT_SECS:= 21.0


var _retry_armed:= false


static func submit_landed(res: Dictionary) -> bool:
	if not bool(res.get("ok", false)):
		return false
	var d: Variant = res.get("data")
	return not (d is bool and not d)


func _retry_after_limit() -> void:
	if _retry_armed:
		return
	_retry_armed = true
	await get_tree().create_timer(RATE_LIMIT_SECS, true).timeout
	_retry_armed = false
	submit()


static func missing_function(res: Dictionary) -> bool:
	var d: Variant = res.get("data")
	return d is Dictionary and str((d as Dictionary).get("code", "")) == "PGRST202"


func fetch_board(board: String, limit: int = 100, period: String = ALL_TIME) -> Dictionary:
	if not enabled:
		return { "ok": false, "rows": [], "error": tr("leaderboards are off in this build") }
	var res: Dictionary
	if period == ALL_TIME:
		res = await _rpc("top_players", { "p_board": board, "p_limit": limit }, false)
	else:
		res = await _rpc("top_period", { "p_board": board, "p_period": period,
			"p_limit": limit }, false)
	if not res.ok:
		if missing_function(res):
			_server_behind = 1
			return { "ok": false, "rows": [], "error": tr("this board is not on the server yet") }
		failed.emit("fetch", res.error)
		return { "ok": false, "rows": [], "error": res.error }
	if period != ALL_TIME:
		_server_behind = 0
	var rows: Array = res.data if res.data is Array else []
	if rows.is_empty() and board == PERIOD_SQL_BOARD and await server_is_behind():
		return { "ok": false, "rows": [], "error": tr("this board is not on the server yet") }
	return { "ok": true, "rows": rows, "error": "" }


const PERIOD_SQL_BOARD:= "best_income"


var _server_behind:= -1


func server_is_behind() -> bool:
	if _server_behind < 0:
		var res: Dictionary = await _rpc("top_period",
			{ "p_board": "money_earned", "p_period": "day", "p_limit": 1 }, false)
		if missing_function(res):
			_server_behind = 1
		elif res.ok:
			_server_behind = 0
	return _server_behind == 1


func my_rank(board: String, period: String = ALL_TIME) -> int:
	var standing:= await my_standing(board, period)
	return int(standing ["rank"])


func my_standing(board: String, period: String = ALL_TIME) -> Dictionary:
	if not enabled:
		return { "ok": false, "reason": "off", "rank": 0 }
	if Profile.refresh_token == "":
		return { "ok": false, "rank": 0,
			"reason": "lost" if Profile.session_lost else "none" }
	if not await _authenticate():
		return { "ok": false, "rank": 0,
			"reason": "lost" if Profile.session_lost else "unreachable" }
	var res: Dictionary
	if period == ALL_TIME:
		res = await _rpc("my_rank", { "p_board": board }, true)
	else:
		res = await _rpc("my_rank_period", { "p_board": board, "p_period": period }, true)
	if not res.ok:
		if missing_function(res):
			_server_behind = 1
			return { "ok": false, "reason": "missing", "rank": 0 }
		return { "ok": false, "reason": "unreachable", "rank": 0 }
	if period != ALL_TIME:
		_server_behind = 0


	if res.data == null and board == PERIOD_SQL_BOARD and await server_is_behind():
		return { "ok": false, "reason": "missing", "rank": 0 }
	return { "ok": true, "reason": "",
		"rank": 0 if res.data == null else int(res.data) }


func authed_rpc(fn: String, body: Dictionary) -> Dictionary:
	if not enabled:
		return { "ok": false, "code": 0, "data": null,
			"error": tr("the server is off in this build") }
	if not await _authenticate():
		return { "ok": false, "code": 0, "data": null,
			"error": tr("could not sign in") }
	return await _rpc(fn, body, true)


func _rpc(fn: String, body: Dictionary, authed: bool) -> Dictionary:
	return await _http("%s/rest/v1/rpc/%s" % [URL, fn], body, authed)


func _http(url: String, body: Dictionary, authed: bool) -> Dictionary:
	var headers:= PackedStringArray([
		"apikey: " + KEY,
		"Content-Type: application/json",
	])
	if authed:
		headers.append("Authorization: Bearer " + _access_token)


	var http:= HTTPRequest.new()


	http.timeout = 10.0
	add_child(http)
	var err:= http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return { "ok": false, "code": 0, "data": null, "error": tr("could not reach the server") }

	var out: Array = await http.request_completed
	http.queue_free()


	var result: int = out [0]
	if result != HTTPRequest.RESULT_SUCCESS:


		var why:= tr("could not reach the server")
		if result == HTTPRequest.RESULT_TIMEOUT:
			why = tr("the server did not answer in time")
		elif result == HTTPRequest.RESULT_CANT_RESOLVE:
			why = tr("no internet connection")
		return { "ok": false, "code": 0, "data": null, "error": why }

	var code: int = out [1]
	var text:= (out [3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = null
	if text.strip_edges() != "":
		parsed = JSON.parse_string(text)

	if code < 200 or code >= 300:


		var msg:= "HTTP %d" % code
		if parsed is Dictionary:
			msg = str(parsed.get("message", parsed.get("msg", msg)))
		return { "ok": false, "code": code, "data": parsed, "error": msg }

	return { "ok": true, "code": code, "data": parsed, "error": "" }


static func _build_string() -> String:
	return Cfg.build_string()


static func format_value(kind: String, value: float) -> String:
	match kind:
		"money":
			return "$" + _grouped(value)
		"stopwatch":
			if value <= 0.0:
				return Cfg.tr("no time yet")
			return clock_text(value)
		"time":
			return clock_text(value)
		_:
			return _grouped(value)


static func clock_text(secs: float) -> String:
	var total:= int(floor(maxf(secs, 0.0)))
	var h:= total / 3600
	var m:= (total % 3600) / 60
	var s:= total % 60


	if h > 0:
		return Cfg.tr("%dh %02dm %02ds", "stopwatch") % [h, m, s]
	if m > 0:
		return Cfg.tr("%dm %02ds", "stopwatch") % [m, s]
	return Cfg.tr("%ds", "stopwatch") % s


static func day_key(unix: float) -> String:
	return Time.get_date_string_from_unix_time(int(floor(unix)))


static func period_start_day(period: String, unix: float) -> String:
	var day:= int(floor(unix / 86400.0))
	match period:
		"day":
			return day_key(day * 86400)
		"week":


			return day_key((day - posmod(day + 3, 7)) * 86400)
		"month":
			var d:= Time.get_date_dict_from_unix_time(int(floor(unix)))
			return "%04d-%02d-01" % [int(d ["year"]), int(d ["month"])]
	return ""


static func period_ends(period: String, unix: float) -> int:
	var day:= int(floor(unix / 86400.0))
	match period:
		"day":
			return (day + 1) * 86400
		"week":
			return (day - posmod(day + 3, 7) + 7) * 86400
		"month":
			var d:= Time.get_date_dict_from_unix_time(int(floor(unix)))
			var year:= int(d ["year"])
			var month:= int(d ["month"]) + 1
			if month > 12:
				month = 1
				year += 1
			return Time.get_unix_time_from_datetime_dict(
				{ "year": year, "month": month, "day": 1, "hour": 0, "minute": 0, "second": 0 })
	return 0


static func _grouped(value: float) -> String:
	var s:= "%.0f" % value
	var out:= ""
	var n:= s.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s [i]
	return out
