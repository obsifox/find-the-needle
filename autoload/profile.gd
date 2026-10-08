extends Node


const PATH:= "user://profile.cfg"


const POLL_SECONDS:= 2.0


const FLUSH_SECONDS:= 10.0

signal totals_changed()
signal identity_changed()


var money_peak: float = 0.0
var play_secs: int = 0
var hay_dug: float = 0.0
var needles_found: int = 0
var money_earned: float = 0.0
var structures_built: int = 0


var best_income: float = 0.0


var first_needle_secs: float = 0.0


var pile_clear_secs: Dictionary = { }


var days: Dictionary = { }


const DAYS_KEPT:= 40


var refresh_token:= ""


var access_token:= ""
var access_expires_at:= 0.0
var access_for:= ""


var board_name:= ""


var name_changed:= false


var session_lost:= false


var install_key:= ""


var countdown_spent: Array [int] = []


var countdown_seen_slots: Array [bool] = []


var countdown_slot:= -1


const CAREER_EPOCH:= 2


var _epoch:= 0


var _backfilled:= false


var debug_tainted:= false


var _seen:= { }


var _inert:= false

var _dirty:= false
var _flush_left:= 0.0
var _poll_left:= 0.0


var _secs_frac:= 0.0


var _in_yard:= false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


	_size_countdown()
	_inert = _harness_run()
	if _inert:
		set_process(false)
		return
	load_profile()
	ensure_install_key()


	if _epoch < CAREER_EPOCH:
		_rebuild_career()
	elif not _backfilled:
		_backfill()
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)
	if not GameState.hay_sold_changed.is_connected(_on_hay_sold):
		GameState.hay_sold_changed.connect(_on_hay_sold)


func _harness_run() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and not (arg in Cfg.PLAY_FLAGS):
			return true
	return false


func _process(delta: float) -> void:
	_tick_play_time(delta)

	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL_SECONDS
		_poll_run()

	if _dirty:
		_flush_left -= delta
		if _flush_left <= 0.0:
			save_profile()


func _tick_play_time(delta: float) -> void:
	if not play_time_counts(_in_yard, get_tree().paused, DisplayServer.window_is_focused()):
		return
	_secs_frac += delta
	if _secs_frac < 1.0:
		return
	var whole:= int(_secs_frac)
	_secs_frac -= float(whole)
	play_secs += whole
	_day_add("play_secs", whole)


	if countdown_slot >= 0 and countdown_slot < countdown_spent.size():
		countdown_spent [countdown_slot] += whole
	_touch()


static func play_time_counts(in_yard: bool, paused: bool, focused: bool) -> bool:
	return in_yard and not paused and focused


func _poll_run() -> void:


	if not _in_yard:
		return
	var moved:= false
	moved = _accumulate("hay_dug", GameState.hay_dug) or moved
	moved = _accumulate("money_earned", GameState.money_earned) or moved
	moved = _accumulate("needles_found", float(GameState.needles_found)) or moved


	var best:= better_time(first_needle_secs, GameState.first_needle_secs)
	if best != first_needle_secs:
		first_needle_secs = best
		moved = true

	var size_id:= SaveManager.current_pile_size
	var had:= float(pile_clear_secs.get(size_id, 0.0))
	var cleared:= better_time(had, GameState.first_clear_secs)
	if cleared != had:
		pile_clear_secs [size_id] = cleared
		moved = true


	if _reached_now("first_needle_secs", GameState.first_needle_secs):
		var today:= _today()
		today ["first_needle_secs"] = better_time(
			float(today.get("first_needle_secs", 0.0)), GameState.first_needle_secs)
		moved = true
	if _reached_now("first_clear_secs", GameState.first_clear_secs):
		var clears: Dictionary = _today() ["pile_clear"]
		clears [size_id] = better_time(float(clears.get(size_id, 0.0)),
			GameState.first_clear_secs)
		moved = true
	if moved:
		_touch()
		totals_changed.emit()


func _accumulate(key: String, run_value: float) -> bool:
	var seen: float = _seen.get(key, -1.0)
	if seen < 0.0 or run_value < seen:
		_seen [key] = run_value
		return false
	if run_value <= seen:
		return false
	var gained:= run_value - seen
	_seen [key] = run_value
	match key:
		"hay_dug": hay_dug += gained
		"money_earned": money_earned += gained
		"needles_found": needles_found += int(round(gained))
	if key == "needles_found":
		_day_add(key, int(round(gained)))
	else:
		_day_add(key, gained)
	return true


func _reached_now(key: String, run_value: float) -> bool:
	var seen:= float(_seen.get(key, run_value))
	_seen [key] = run_value
	return run_value > 0.0 and seen <= 0.0


func _today() -> Dictionary:
	var key:= Leaderboard.day_key(Time.get_unix_time_from_system())
	if days.has(key):
		return days [key]
	var day:= {
		"money_peak": 0.0, "play_secs": 0, "hay_dug": 0.0, "needles_found": 0,
		"money_earned": 0.0, "structures_built": 0, "first_needle_secs": 0.0,
		"pile_clear": { }, "best_income": 0.0,
	}
	days [key] = day
	_forget_old_days()
	return day


func _day_add(key: String, amount: Variant) -> void:
	var today:= _today()
	today [key] = today.get(key, 0) + amount


func _forget_old_days() -> void:
	var oldest:= Leaderboard.day_key(
		Time.get_unix_time_from_system() - float(DAYS_KEPT) * 86400.0)
	for key: String in days.keys():

		if key < oldest:
			days.erase(key)


func period_value(key: String, period: String) -> float:
	if period == Leaderboard.ALL_TIME:
		return board_value(key)
	var start:= Leaderboard.period_start_day(period, Time.get_unix_time_from_system())
	var out:= 0.0
	for day_key: String in days:
		if day_key < start:
			continue
		var day: Dictionary = days [day_key]
		if key == "money_peak" or key == "best_income":
			out = maxf(out, float(day.get(key, 0.0)))
		elif key == "first_needle_secs":
			out = better_time(out, float(day.get(key, 0.0)))
		elif key.begins_with("pile_clear_"):
			var clears: Dictionary = day.get("pile_clear", { })
			out = better_time(out, float(clears.get(key.trim_prefix("pile_clear_"), 0.0)))
		else:
			out += float(day.get(key, 0.0))
	return out


func days_payload() -> Dictionary:
	var out:= { }
	for day_key: String in days:
		var day: Dictionary = days [day_key]
		out [day_key] = {
			"money_peak": float(day.get("money_peak", 0.0)),
			"play_secs": int(day.get("play_secs", 0)),
			"hay_dug": float(day.get("hay_dug", 0.0)),
			"needles_found": int(day.get("needles_found", 0)),
			"money_earned": float(day.get("money_earned", 0.0)),
			"structures_built": int(day.get("structures_built", 0)),
			"first_needle_secs": float(day.get("first_needle_secs", 0.0)),
			"pile_clear": (day.get("pile_clear", { }) as Dictionary).duplicate(),
			"best_income": float(day.get("best_income", 0.0)),
		}
	return out


static func better_time(best: float, run: float) -> float:
	if run <= 0.0:
		return best
	if best <= 0.0 or run < best:
		return run
	return best


func begin_run() -> void:
	_in_yard = false
	_seen.clear()


func enter_yard() -> void:
	_seen.clear()
	_seen ["hay_dug"] = GameState.hay_dug
	_seen ["money_earned"] = GameState.money_earned
	_seen ["needles_found"] = float(GameState.needles_found)
	_seen ["first_needle_secs"] = GameState.first_needle_secs
	_seen ["first_clear_secs"] = GameState.first_clear_secs
	_in_yard = true

	_note_day_peak(GameState.money)


	if GameState.debug_used:
		note_debug_used()


func leave_yard() -> void:
	_in_yard = false


func note_debug_used() -> void:
	if debug_tainted:
		return
	debug_tainted = true
	_touch()


	save_profile()


func _on_money_changed(amount: float) -> void:


	_note_day_peak(amount)
	if amount <= money_peak:
		return
	money_peak = amount
	_touch()
	totals_changed.emit()


func _on_hay_sold(_sold_total: float) -> void:
	if not _in_yard:
		return
	var now:= GameState.income_per_minute()
	var today:= _today()
	if now > float(today.get("best_income", 0.0)):
		today ["best_income"] = now
		_touch()
	var best:= maxf(now, GameState.best_income)
	if best > best_income:
		best_income = best
		_touch()
		totals_changed.emit()


func _note_day_peak(amount: float) -> void:
	if not _in_yard:
		return
	var today:= _today()
	if amount <= float(today.get("money_peak", 0.0)):
		return
	today ["money_peak"] = amount
	_touch()


func note_structure_built(count: int = 1) -> void:
	if count <= 0:
		return
	structures_built += count
	_day_add("structures_built", count)
	_touch()
	totals_changed.emit()


func note_structure_removed(count: int = 1) -> void:
	if count <= 0 or structures_built <= 0:
		return
	structures_built = maxi(0, structures_built - count)


	var today:= _today()
	today ["structures_built"] = maxi(0, int(today.get("structures_built", 0)) - count)
	_touch()
	totals_changed.emit()


func countdown_spent_in(slot: int) -> int:
	return countdown_spent [slot] if slot >= 0 and slot < countdown_spent.size() else 0


func countdown_seen_in(slot: int) -> bool:
	return countdown_seen_slots [slot] if slot >= 0 and slot < countdown_seen_slots.size() else false


func note_countdown_seen(slot: int) -> void:
	if slot < 0 or slot >= countdown_seen_slots.size() or countdown_seen_slots [slot]:
		return
	countdown_seen_slots [slot] = true
	_touch()


func _size_countdown() -> void:
	while countdown_spent.size() < SaveManager.SLOT_COUNT:
		countdown_spent.append(0)
	while countdown_seen_slots.size() < SaveManager.SLOT_COUNT:
		countdown_seen_slots.append(false)


func set_identity(token: String, name_from_server: String, renamed: bool) -> void:
	refresh_token = token
	board_name = name_from_server
	name_changed = renamed
	_touch()
	save_profile()
	identity_changed.emit()


func totals() -> Dictionary:
	return {
		"p_money_peak": money_peak,
		"p_play_secs": play_secs,
		"p_hay_dug": hay_dug,
		"p_needles_found": needles_found,
		"p_money_earned": money_earned,
		"p_structures_built": structures_built,
		"p_first_needle_secs": first_needle_secs,

		"p_pile_clear": pile_clear_secs.duplicate(),

		"p_days": days_payload(),
		"p_best_income": best_income,
	}


func board_value(key: String) -> float:
	if key.begins_with("pile_clear_"):
		return float(pile_clear_secs.get(key.trim_prefix("pile_clear_"), 0.0))
	return float(totals().get("p_" + key, 0.0))


func _touch() -> void:


	if _inert:
		return
	if not _dirty:
		_flush_left = FLUSH_SECONDS
	_dirty = true


func _backfill() -> void:
	_backfilled = true
	var debug_run:= false
	for i in SaveManager.SLOT_COUNT:
		var s:= SaveManager.slot_summary(i)
		if s.is_empty() or not bool(s.get("readable", false)):
			continue
		hay_dug += float(s.get("hay_dug", 0.0))
		needles_found += int(s.get("needles_found", 0))
		money_earned += float(s.get("money_earned", 0.0))
		money_peak = maxf(money_peak, float(s.get("money_peak", s.get("money", 0.0))))
		structures_built += int(s.get("structures", 0))
		first_needle_secs = better_time(first_needle_secs,
			float(s.get("first_needle_secs", -1.0)))

		var size_id:= str(s.get("pile_size", Cfg.DEFAULT_PILE_SIZE))
		var clear:= better_time(float(pile_clear_secs.get(size_id, 0.0)),
			float(s.get("pile_clear_secs", -1.0)))
		if clear > 0.0:
			pile_clear_secs [size_id] = clear
		debug_run = debug_run or bool(s.get("debug_used", false))
	if hay_dug > 0.0 or needles_found > 0:
		print("[profile] seeded a career from existing saves: %.0f hay, %d needles, $%.2f, %d structures"
			% [hay_dug, needles_found, money_earned, structures_built])
	save_profile()

	if debug_run:
		note_debug_used()


func _rebuild_career() -> void:
	money_peak = 0.0
	hay_dug = 0.0
	needles_found = 0
	money_earned = 0.0
	structures_built = 0
	first_needle_secs = 0.0
	pile_clear_secs = { }
	_epoch = CAREER_EPOCH
	_backfilled = false
	print("[profile] career epoch %d: rebuilding from the saves, keeping %d s of time played"
		% [CAREER_EPOCH, play_secs])
	_backfill()


func save_profile() -> void:
	if _inert:
		return
	var cf:= ConfigFile.new()
	cf.set_value("career", "money_peak", money_peak)
	cf.set_value("career", "play_secs", play_secs)
	cf.set_value("career", "hay_dug", hay_dug)
	cf.set_value("career", "needles_found", needles_found)
	cf.set_value("career", "money_earned", money_earned)
	cf.set_value("career", "structures_built", structures_built)
	cf.set_value("career", "best_income", best_income)
	cf.set_value("career", "first_needle_secs", first_needle_secs)


	for size_id: String in pile_clear_secs:
		cf.set_value("pile_clear", size_id, float(pile_clear_secs [size_id]))

	for day_key: String in days:
		cf.set_value("days", day_key, days [day_key])
	cf.set_value("career", "backfilled", _backfilled)
	cf.set_value("career", "epoch", _epoch)
	cf.set_value("career", "debug_tainted", debug_tainted)


	for i in countdown_spent.size():
		if countdown_spent [i] <= 0 and not countdown_seen_slots [i]:
			continue
		cf.set_value("countdown", "spent_%d" % i, countdown_spent [i])
		cf.set_value("countdown", "seen_%d" % i, countdown_seen_slots [i])
	cf.set_value("identity", "refresh_token", refresh_token)
	cf.set_value("identity", "access_token", access_token)
	cf.set_value("identity", "access_expires_at", access_expires_at)
	cf.set_value("identity", "access_for", access_for)
	cf.set_value("identity", "board_name", board_name)
	cf.set_value("identity", "name_changed", name_changed)
	cf.set_value("identity", "session_lost", session_lost)
	cf.set_value("identity", "install_key", install_key)
	cf.save(PATH)
	_dirty = false


func stored_refresh_token() -> String:
	var cf:= ConfigFile.new()
	if cf.load(PATH) != OK:
		return ""
	return str(cf.get_value("identity", "refresh_token", ""))


func load_profile() -> void:
	var cf:= ConfigFile.new()
	if cf.load(PATH) != OK:
		return


	money_peak = maxf(0.0, float(cf.get_value("career", "money_peak", 0.0)))
	play_secs = maxi(0, int(cf.get_value("career", "play_secs", 0)))
	hay_dug = maxf(0.0, float(cf.get_value("career", "hay_dug", 0.0)))
	needles_found = maxi(0, int(cf.get_value("career", "needles_found", 0)))
	money_earned = maxf(0.0, float(cf.get_value("career", "money_earned", 0.0)))
	structures_built = maxi(0, int(cf.get_value("career", "structures_built", 0)))
	best_income = maxf(0.0, float(cf.get_value("career", "best_income", 0.0)))
	first_needle_secs = better_time(first_needle_secs,
		float(cf.get_value("career", "first_needle_secs", 0.0)))
	if cf.has_section("pile_clear"):
		for size_id: String in cf.get_section_keys("pile_clear"):
			var t:= better_time(float(pile_clear_secs.get(size_id, 0.0)),
				float(cf.get_value("pile_clear", size_id, 0.0)))
			if t > 0.0:
				pile_clear_secs [size_id] = t
	if cf.has_section("days"):
		for day_key: String in cf.get_section_keys("days"):
			var day: Variant = cf.get_value("days", day_key, { })
			if day is Dictionary:
				days [day_key] = day
		_forget_old_days()
	_backfilled = bool(cf.get_value("career", "backfilled", false))
	_epoch = int(cf.get_value("career", "epoch", 1))


	debug_tainted = debug_tainted or bool(cf.get_value("career", "debug_tainted", false))


	_size_countdown()
	for i in countdown_spent.size():


		countdown_spent [i] = maxi(countdown_spent [i],
			int(cf.get_value("countdown", "spent_%d" % i, 0)))
		countdown_seen_slots [i] = countdown_seen_slots [i] or bool(cf.get_value("countdown", "seen_%d" % i, false))
	refresh_token = str(cf.get_value("identity", "refresh_token", ""))
	access_token = str(cf.get_value("identity", "access_token", ""))
	access_expires_at = float(cf.get_value("identity", "access_expires_at", 0.0))
	access_for = str(cf.get_value("identity", "access_for", ""))
	board_name = str(cf.get_value("identity", "board_name", ""))
	name_changed = bool(cf.get_value("identity", "name_changed", false))
	session_lost = bool(cf.get_value("identity", "session_lost", false))
	install_key = str(cf.get_value("identity", "install_key", ""))


func ensure_install_key() -> void:
	if install_key != "":
		return
	install_key = Crypto.new().generate_random_bytes(32).hex_encode()
	save_profile()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_profile()
