class_name RankBoard
extends ChalkBoard


const WALL_X:= 2.7 - 0.045 / 2.0


const BOARD_AT:= Vector2(0.14, 1.55)


const SIZE:= Vector2(0.82, 0.66)


const TITLE:= "LEADERBOARDS"


const H_RANK:= 0.135

const H_UNDER:= 0.052
const H_DETAIL:= 0.044


const BOARD_KEY:= "money_earned"


const REFETCH_AFTER:= 120.0


const SHOW_SECS:= 5.0
const FADE_SECS:= 0.35


const PRESS_DISTANCE:= 5.0


enum State { ASKING, RANKED, UNRANKED, OFFLINE, LOST, DISABLED, CLOSED }

var _rank_line: Label3D
var _under: Label3D
var _detail: Label3D
var _name: Label3D
var _foot: Label3D

var _state:= State.CLOSED
var _rank:= 0


var _ranks: Array [Dictionary] = []
var _shown:= 0
var _show_left:= SHOW_SECS
var _fade: Tween


var _busy:= false

var _fetched_at:= -1


func _ready() -> void:
	_build()
	_state = State.DISABLED if not Leaderboard.enabled else State.CLOSED
	_write_lines()
	if not Leaderboard.enabled:
		return
	if not Leaderboard.viewed.is_connected(_on_viewed):
		Leaderboard.viewed.connect(_on_viewed)


func _build() -> void:
	half = SIZE
	hang(WALL_X, BOARD_AT)
	write_title(tr(TITLE))


	var span:= half.x * 2.0 - MARGIN * 2.0
	_rank_line = write("Rank", H_RANK, COL_CHALK, Vector2(0.0, 0.135), span,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	_under = write("Under", H_UNDER, COL_CHALK, Vector2(0.0, -0.02), span,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	_detail = write("Detail", H_DETAIL, COL_LABEL, Vector2(0.0, -0.19), span,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	_name = write("Name", H_DETAIL, COL_LABEL, Vector2(0.0, -0.31), span,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	_foot = write("Foot", H_FOOT, COL_FOOT, Vector2(0.0, - half.y + 0.085), span,
		HORIZONTAL_ALIGNMENT_CENTER, false)


func _process(delta: float) -> void:
	if _state == State.RANKED:
		_cycle(delta)


func _cycle(delta: float) -> void:
	if _ranks.size() < 2 or (_fade != null and _fade.is_running()):
		return
	_show_left -= delta
	if _show_left > 0.0:
		return
	_show_left = SHOW_SECS
	_fade = create_tween()
	for l: Label3D in [_rank_line, _under, _detail]:
		_fade.parallel().tween_property(l, "transparency", 1.0, FADE_SECS)
	_fade.tween_callback(_next_board)
	for l: Label3D in [_rank_line, _under, _detail]:
		_fade.parallel().tween_property(l, "transparency", 0.0, FADE_SECS)


func _next_board() -> void:
	if not _ranks.is_empty():
		_shown = (_shown + 1) % _ranks.size()
	_write_lines()


func _on_viewed() -> void:
	if _busy or not Leaderboard.enabled:
		return
	if _fetched_at >= 0 and Time.get_ticks_msec() - _fetched_at < int(REFETCH_AFTER * 1000.0):
		return
	_fetch()


func _fetch() -> void:
	if _busy or not Leaderboard.enabled:
		return
	_busy = true
	var started:= Time.get_ticks_msec()
	if _state == State.CLOSED:
		_set_state(State.ASKING, 0)
	var found: Array [Dictionary] = []
	var failure:= ""
	for board: Dictionary in Leaderboard.BOARDS:
		var key:= Leaderboard.board_key(board, SaveManager.current_pile_size)
		var standing:= await Leaderboard.my_standing(key)
		if not is_instance_valid(self):
			return
		if not bool(standing ["ok"]):


			if str(standing ["reason"]) == "missing":
				continue
			failure = str(standing ["reason"])
			break
		var rank:= int(standing ["rank"])
		if rank > 0:
			found.append({ "board": board, "key": key, "rank": rank })
	_busy = false
	if failure == "" or failure == "none":


		_fetched_at = started
	if failure == "":
		_set_ranks(found)
		return
	_ranks.clear()
	match failure:
		"off": _set_state(State.DISABLED, 0)
		"lost": _set_state(State.LOST, 0)
		"none": _set_state(State.UNRANKED, 0)
		_: _set_state(State.OFFLINE, 0)


func _set_ranks(found: Array [Dictionary]) -> void:
	var was:= str(_current().get("key", ""))
	_ranks = found
	_shown = 0
	for i in _ranks.size():
		if str(_ranks [i] ["key"]) == was:
			_shown = i
	_state = State.RANKED if not _ranks.is_empty() else State.UNRANKED
	_rank = int(_current().get("rank", 0))
	_write_lines()


func _set_state(state: State, rank: int) -> void:
	if state == _state and rank == _rank:
		return
	_state = state
	_rank = rank
	_write_lines()


func _current() -> Dictionary:
	if _ranks.is_empty():
		return { }
	return _ranks [_shown % _ranks.size()]


static func board_by_key(key: String) -> Dictionary:
	for board: Dictionary in Leaderboard.BOARDS:
		if str(board ["key"]) == key:
			return board
	return Leaderboard.BOARDS [0]


func is_hovered(eye: Vector3, look: Vector3) -> bool:
	if face == null:
		return false
	var from:= face.to_local(eye)
	var along:= face.to_local(eye + look.normalized()) - from


	if along.z > -0.0001:
		return false
	var t:= (SLATE_T / 2.0 - from.z) / along.z
	if t <= 0.0:
		return false
	var hit:= from + along * t
	if absf(hit.x) > half.x + FRAME_W or absf(hit.y) > half.y + FRAME_W:
		return false
	return eye.distance_to(face.to_global(hit)) <= PRESS_DISTANCE


static func lines_for(state: State, rank: int, board_name: String,
		value: float, board: Dictionary = { }, size_id: String = "") -> Dictionary:
	var figure:= Leaderboard.format_value("money", value)


	var who:= Cfg.tr("as %s") % board_name if board_name != "" else ""
	match state:
		State.RANKED:
			var on:= board if not board.is_empty() else board_by_key(BOARD_KEY)
			var title:= Cfg.tr(str(on ["title"]))
			if bool(on.get("sized", false)) and size_id != "":
				title += "  ·  " + str(Cfg.pile_size_spec(size_id).get("name", size_id))
			return {


				"rank": Cfg.tr("YOU ARE %s") % LeaderboardPanel._ordinal(rank),
				"under": title,
				"detail": Leaderboard.format_value(str(on ["kind"]), value),
				"name": who,
				"foot": Cfg.tr("press %s to see every board") % InputSetup.hint("interact"),
			}
		State.UNRANKED:
			return {
				"rank": Cfg.tr("UNRANKED"),
				"under": Cfg.tr("NOT ON THE BOARDS YET"),
				"detail": Cfg.tr("MOST MONEY EARNED   %s") % figure,
				"name": who,
				"foot": Cfg.tr("sell some hay and it will be posted for you"),
			}
		State.LOST:
			return {
				"rank": Cfg.tr("SIGNED OUT"),
				"under": Cfg.tr("OPEN THE LEADERBOARDS TO SIGN IN"),
				"detail": Cfg.tr("MOST MONEY EARNED   %s") % figure,
				"name": "",
				"foot": Cfg.tr("your progress is saved"),
			}
		State.OFFLINE:
			return {
				"rank": Cfg.tr("OFFLINE"),
				"under": Cfg.tr("THE BOARDS CANNOT BE REACHED"),
				"detail": Cfg.tr("MOST MONEY EARNED   %s") % figure,
				"name": who,
				"foot": Cfg.tr("your progress is saved, your rank will show later"),
			}
		State.CLOSED:
			return {
				"rank": Cfg.tr("YOUR RANK"),
				"under": Cfg.tr("OPEN THE LEADERBOARDS TO SEE IT"),
				"detail": Cfg.tr("MOST MONEY EARNED   %s") % figure,
				"name": who,
				"foot": Cfg.tr("press %s to see every board") % InputSetup.hint("interact"),
			}
		State.DISABLED:
			return {
				"rank": Cfg.tr("NO BOARDS"),
				"under": Cfg.tr("SWITCHED OFF IN THIS BUILD"),
				"detail": Cfg.tr("MOST MONEY EARNED   %s") % figure,
				"name": "",
				"foot": "",
			}
		_:
			return {
				"rank": Cfg.tr("CONNECTING"),
				"under": Cfg.tr("LOADING"),
				"detail": "",
				"name": "",
				"foot": "",
			}


func _write_lines() -> void:
	var cur:= _current()
	var key:= str(cur.get("key", BOARD_KEY))
	var l:= lines_for(_state, int(cur.get("rank", _rank)), Profile.board_name,
		Profile.board_value(key), cur.get("board", { }), SaveManager.current_pile_size)
	_rank_line.text = str(l ["rank"])
	_under.text = str(l ["under"])
	_detail.text = str(l ["detail"])
	_name.text = str(l ["name"])
	_foot.text = str(l ["foot"])


func state() -> State:
	return _state


func rank() -> int:
	return _rank


func rank_text() -> String:
	return _rank_line.text if _rank_line != null else ""


func under_text() -> String:
	return _under.text if _under != null else ""


func detail_text() -> String:
	return _detail.text if _detail != null else ""


func show_state(state: State, rank: int) -> void:
	_ranks.clear()
	if state == State.RANKED:
		_ranks.append({ "board": board_by_key(BOARD_KEY), "key": BOARD_KEY, "rank": rank })
	_shown = 0
	_state = state
	_rank = rank
	_write_lines()


func show_ranks(found: Array [Dictionary]) -> void:
	_set_ranks(found)


func shown_index() -> int:
	return _shown
