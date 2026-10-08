class_name LeaderboardPanel
extends VBoxContainer


const COL_ACCENT:= Color(0.58, 0.72, 0.9)
const COL_TEXT:= Color(0.93, 0.95, 0.98)
const COL_DIM:= Color(0.6, 0.65, 0.73)
const COL_EDGE:= Color(0.42, 0.5, 0.62, 0.55)
const COL_FILL:= Color(0.09, 0.11, 0.14, 0.92)


const COL_GOLD:= Color(1.0, 0.86, 0.34)
const COL_SILVER:= Color(0.82, 0.86, 0.92)
const COL_BRONZE:= Color(0.88, 0.63, 0.38)


const COL_YOU:= Color(0.4, 0.87, 0.55)


const BLURB:= "Your totals from every run. The daily, weekly and monthly boards start fresh by themselves."


const PANEL_W:= 960.0
const TAB_GAP:= 4.0


const TAB_FONT:= 14

const SIZE_ROW_H:= 30.0
const SIZE_FONT:= 13


const PERIOD_ROW_H:= 30.0


const ROWS_H:= 356.0
const ROW_H:= 34.0
const RANK_W:= 78.0
const VALUE_W:= 210.0
const FETCH_LIMIT:= 100

var _tab:= 0
var _tab_buttons: Array [Button] = []

var _size:= Cfg.DEFAULT_PILE_SIZE
var _size_row: HBoxContainer
var _size_buttons: Array [Button] = []


var _period:= "all"
var _period_buttons: Array [Button] = []
var _clock: Label
var _clock_left:= 0.0

var _clock_ends:= 0
var _value_header: Label
var _rows_box: VBoxContainer
var _status: Label
var _identity: Label
var _rank_line: Label
var _rename_button: Button
var _rename_row: HBoxContainer
var _rename_edit: LineEdit
var _rename_note: Label


var _generation:= 0


var _started:= false


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_W, 0)
	add_theme_constant_override("separation", 10)
	_build_period_row()
	_build_tab_bar()
	_build_size_row()
	_build_header()
	_build_rows()
	_build_footer()
	_refresh_identity()
	if not Leaderboard.signed_in.is_connected(_on_signed_in):
		Leaderboard.signed_in.connect(_on_signed_in)
	if not Leaderboard.submitted.is_connected(_on_submitted):
		Leaderboard.submitted.connect(_on_submitted)


func _start() -> void:
	if not Leaderboard.enabled:
		_set_status(tr("The leaderboards are not available in this build."))
		return


	_load_board()
	if not await Leaderboard.sign_in():
		return
	if not is_instance_valid(self):
		return
	_refresh_identity()
	await _post_and_reload()


func _post_and_reload() -> void:
	var landed: bool = await Leaderboard.submit()
	Leaderboard.viewed.emit()
	if landed or not is_instance_valid(self):
		return
	_load_board()
	_load_my_rank()


func _on_submitted() -> void:
	if not _started or not is_visible_in_tree():
		return
	_load_board()
	_load_my_rank()


func _build_period_row() -> void:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", int(TAB_GAP))
	row.custom_minimum_size = Vector2(0, PERIOD_ROW_H)
	add_child(row)
	_period_buttons.clear()
	for spec: Dictionary in Leaderboard.PERIODS:
		var b:= Button.new()
		b.text = tr(str(spec ["tab"]))
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, PERIOD_ROW_H)
		b.set_meta("period", str(spec ["key"]))
		b.pressed.connect(_select_period.bind(str(spec ["key"])))
		row.add_child(b)
		_period_buttons.append(b)
	_clock = Label.new()
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.style(_clock, 15, COL_ACCENT, 0, true)
	row.add_child(_clock)
	_refresh_period_row()


func _refresh_period_row() -> void:
	for b in _period_buttons:
		_style_size(b, str(b.get_meta("period")) == _period)
	_tick_clock()


func _select_period(key: String) -> void:
	if key == _period:
		return
	Audio.play("ui_click")
	_period = key
	_clock_ends = 0
	_refresh_period_row()
	_load_board()
	_load_my_rank()


static func clock_line(period: String, unix: float) -> String:
	var ends:= Leaderboard.period_ends(period, unix)
	if ends <= 0:
		return Cfg.tr("NEVER RESETS")
	return Cfg.tr("RESETS IN %s") % Leaderboard.clock_text(maxf(float(ends) - unix, 0.0))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock_left -= delta
	if _clock_left <= 0.0:
		_tick_clock()


func _tick_clock() -> void:
	_clock_left = 0.25
	if _clock == null:
		return
	var now:= Time.get_unix_time_from_system()
	_clock.text = clock_line(_period, now)


	if _clock_ends > 0 and now < float(_clock_ends) + 2.0:
		return
	if _started and _clock_ends > 0:
		_load_board()
		_load_my_rank()
	_clock_ends = Leaderboard.period_ends(_period, now)


func _build_tab_bar() -> void:
	var bar:= HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(TAB_GAP))
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	_tab_buttons.clear()
	for i in Leaderboard.BOARDS.size():
		var b:= Button.new()
		b.text = tr(str(Leaderboard.BOARDS [i] ["tab"]))
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(tab_width(), 34)


		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = tr(str(Leaderboard.BOARDS [i] ["title"]))
		_style_tab(b, i == _tab)
		b.pressed.connect(_select_tab.bind(i))
		bar.add_child(b)
		_tab_buttons.append(b)


static func tab_width() -> float:
	var n:= Leaderboard.BOARDS.size()
	return floorf((PANEL_W - TAB_GAP * float(n - 1)) / float(n))


func _build_size_row() -> void:
	_size_row = HBoxContainer.new()
	_size_row.add_theme_constant_override("separation", int(TAB_GAP))
	_size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_size_row.custom_minimum_size = Vector2(0, SIZE_ROW_H)
	add_child(_size_row)
	_size_buttons.clear()
	for spec: Dictionary in Cfg.PILE_SIZES:
		var id:= str(spec ["id"])
		if id == SaveManager.current_pile_size:
			_size = id
		var b:= Button.new()

		b.text = str(Cfg.pile_size_spec(id).get("name", id))
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, SIZE_ROW_H)
		b.set_meta("size_id", id)
		b.pressed.connect(_select_size.bind(id))
		_size_row.add_child(b)
		_size_buttons.append(b)
	_refresh_size_row()


func _refresh_size_row() -> void:
	var sized:= bool(Leaderboard.BOARDS [_tab].get("sized", false))
	for b in _size_buttons:
		b.visible = sized
		_style_size(b, str(b.get_meta("size_id")) == _size)


func _select_size(id: String) -> void:
	if id == _size:
		return
	Audio.play("ui_click")
	_size = id
	_refresh_size_row()
	_load_board()
	_load_my_rank()


func _board_title(board: Dictionary) -> String:
	var title:= tr(str(board ["title"]))
	if bool(board.get("sized", false)):
		title += "  ·  " + str(Cfg.pile_size_spec(_size).get("name", _size))
	if _period != Leaderboard.ALL_TIME:
		for spec: Dictionary in Leaderboard.PERIODS:
			if str(spec ["key"]) == _period:
				title = tr(str(spec ["tab"])) + "  ·  " + title
	return title


func _build_header() -> void:
	var head:= HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	add_child(head)

	head.add_child(_cell("#", RANK_W, COL_DIM, 13, HORIZONTAL_ALIGNMENT_RIGHT))
	var spacer:= Control.new()
	spacer.custom_minimum_size = Vector2(14, 0)
	head.add_child(spacer)
	head.add_child(_cell(tr("PLAYER"), 0, COL_DIM, 13, HORIZONTAL_ALIGNMENT_LEFT, true))
	_value_header = _cell(tr(str(Leaderboard.BOARDS [_tab] ["title"])), VALUE_W,
		COL_DIM, 13, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(_value_header)

	var rule:= Panel.new()
	rule.custom_minimum_size = Vector2(0, 1)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_EDGE
	rule.add_theme_stylebox_override("panel", sb)
	add_child(rule)


func _build_rows() -> void:
	var scroll:= ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


	scroll.custom_minimum_size = Vector2(0, ROWS_H)
	add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 1)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_W - 80.0, 0)
	UiFont.style(_status, 16, COL_DIM, 0)
	_rows_box.add_child(_status)


func _build_footer() -> void:
	var rule:= Panel.new()
	rule.custom_minimum_size = Vector2(0, 1)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_EDGE
	rule.add_theme_stylebox_override("panel", sb)
	add_child(rule)

	var foot:= HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	add_child(foot)

	var mine:= VBoxContainer.new()
	mine.add_theme_constant_override("separation", 2)
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(mine)

	_identity = Label.new()
	UiFont.style(_identity, 17, COL_YOU, 0, true)
	mine.add_child(_identity)

	_rank_line = Label.new()
	UiFont.style(_rank_line, 14, COL_DIM, 0)
	mine.add_child(_rank_line)

	_rename_button = Button.new()
	_rename_button.text = tr("CHANGE NAME")
	_rename_button.focus_mode = Control.FOCUS_NONE
	_rename_button.custom_minimum_size = Vector2(168, 34)
	_rename_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_pill(_rename_button)
	_rename_button.pressed.connect(_on_rename_pressed)
	foot.add_child(_rename_button)

	_build_rename_row()


func _build_rename_row() -> void:
	_rename_row = HBoxContainer.new()
	_rename_row.add_theme_constant_override("separation", 10)
	_rename_row.visible = false
	add_child(_rename_row)

	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = tr("3 to 28 characters")
	_rename_edit.max_length = 28
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_edit.add_theme_font_override("font", UiFont.regular())
	_rename_edit.add_theme_font_size_override("font_size", 17)
	_rename_edit.add_theme_color_override("font_color", COL_TEXT)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_rename_edit.add_theme_stylebox_override("normal", sb)
	_rename_edit.add_theme_stylebox_override("focus", sb)
	_rename_edit.text_submitted.connect(_on_rename_submitted)
	_rename_row.add_child(_rename_edit)

	var ok:= Button.new()
	ok.text = tr("CONFIRM")
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(120, 34)
	_style_pill(ok)
	ok.pressed.connect(func() -> void: _on_rename_submitted(_rename_edit.text))
	_rename_row.add_child(ok)

	var cancel:= Button.new()
	cancel.text = tr("CANCEL")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(110, 34)
	_style_pill(cancel)
	cancel.pressed.connect(_close_rename)
	_rename_row.add_child(cancel)

	_rename_note = Label.new()
	_rename_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rename_note.custom_minimum_size = Vector2(PANEL_W, 0)
	_rename_note.visible = false
	UiFont.style(_rename_note, 14, COL_BRONZE, 0)
	add_child(_rename_note)


func _select_tab(index: int) -> void:
	if index == _tab:
		return
	Audio.play("ui_click")
	_tab = index
	for i in _tab_buttons.size():
		_style_tab(_tab_buttons [i], i == index)
	_value_header.text = tr(str(Leaderboard.BOARDS [index] ["title"]))
	_refresh_size_row()
	_load_board()
	_load_my_rank()


func refresh() -> void:
	if not _started:
		_started = true
		_start()
		return


	_post_and_reload()


func _quiet_title(board: Dictionary) -> String:
	match str(board.get("key", "")):
		"money_peak":
			return tr("richest yard")
		"money_earned":
			return tr("most money earned")
		"best_income":
			return tr("biggest income per minute")
		"hay_dug":
			return tr("total hay dug")
		"needles_found":
			return tr("needles found")
		"first_needle_secs":
			return tr("fastest first needle")
		"pile_clear":
			return tr("fastest pile clear")
		"structures_built":
			return tr("structures built")
		"play_secs":
			return tr("time played")
	return tr(str(board.get("title", "")))


func _load_board() -> void:
	_generation += 1
	var mine:= _generation
	var board: Dictionary = Leaderboard.BOARDS [_tab]
	_set_status(tr("Loading %s...") % _quiet_title(board))

	var res: Dictionary = await Leaderboard.fetch_board(
		Leaderboard.board_key(board, _size), FETCH_LIMIT, _period)
	if mine != _generation or not is_instance_valid(self):
		return

	if not res.get("ok", false):

		_set_status(tr("Could not load the board: %s.\nYour progress is saved and will be posted next time you open this page.")
			% str(res.get("error", tr("the server did not answer"))))
		return

	var rows: Array = res.get("rows", [])
	_clear_rows()
	if rows.is_empty():
		_set_status(tr("Nothing on this board yet. Dig something and you will be first."))
		return
	for r: Dictionary in rows:
		_rows_box.add_child(_row(
			int(r.get("rank", 0)),
			str(r.get("name", "")),
			float(r.get("value", 0.0)),
			str(board ["kind"])))


func _load_my_rank() -> void:
	if not Leaderboard.enabled or Profile.board_name == "":
		return
	var board: Dictionary = Leaderboard.BOARDS [_tab]
	var mine:= _generation
	var key:= Leaderboard.board_key(board, _size)
	var standing:= await Leaderboard.my_standing(key, _period)
	if mine != _generation or not is_instance_valid(self):
		return
	var rank:= int(standing ["rank"])
	var value:= Leaderboard.format_value(str(board ["kind"]),
		Profile.period_value(key, _period))


	if not bool(standing ["ok"]):
		var line:= "%s  %s" % [_board_title(board), value]
		if str(standing ["reason"]) == "missing":
			line += "  ·  " + tr("this board is not on the server yet")
		_rank_line.text = line
	elif rank <= 0:
		_rank_line.text = tr("%s  %s  ·  not on this board yet") % [_board_title(board), value]
	else:
		_rank_line.text = tr("%s  %s  ·  rank %s") % [_board_title(board), value, _ordinal(rank)]


func _clear_rows() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	_status = null


func _set_status(text: String) -> void:
	_clear_rows()
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_W - 80.0, 90.0)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.style(_status, 16, COL_DIM, 0)
	_status.text = text
	_rows_box.add_child(_status)


func _row(rank: int, name: String, value: float, kind: String) -> Control:
	var you:= name != "" and name == Profile.board_name
	var colour:= COL_TEXT
	match rank:
		1: colour = COL_GOLD
		2: colour = COL_SILVER
		3: colour = COL_BRONZE
	if you:
		colour = COL_YOU

	var panel:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()


	sb.bg_color = Color(COL_YOU.r, COL_YOU.g, COL_YOU.b, 0.13) if you else Color(0.0, 0.0, 0.0, 0.18 if rank <= 3 else 0.0)
	if you:
		sb.border_width_left = 3
		sb.border_color = COL_YOU
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", sb)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size = Vector2(0, ROW_H)
	panel.add_child(row)

	row.add_child(_cell(str(rank), RANK_W - 8.0, colour, 18,
		HORIZONTAL_ALIGNMENT_RIGHT, rank <= 3 or you))
	var gap:= Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	row.add_child(gap)
	row.add_child(_cell(name, 0, colour, 18, HORIZONTAL_ALIGNMENT_LEFT, you))
	row.add_child(_cell(Leaderboard.format_value(kind, value), VALUE_W, colour,
		18, HORIZONTAL_ALIGNMENT_RIGHT, rank <= 3 or you))
	return panel


func _cell(text: String, width: float, colour: Color, size: int,
		align: int, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFont.style(l, size, colour, 0, heavy)
	return l


func _on_signed_in(_name: String) -> void:
	_refresh_identity()


func _refresh_identity() -> void:
	if not Leaderboard.enabled:
		_identity.text = tr("OFFLINE")
		_rename_button.visible = false
		return
	if Profile.board_name == "":
		_identity.text = tr("CONNECTING...")
		_rename_button.disabled = true
		return
	_identity.text = tr("YOU ARE %s") % Cfg.upper(Profile.board_name)
	_rename_button.disabled = Profile.name_changed
	_rename_button.tooltip_text = "" if not Profile.name_changed else tr("A name can only be changed once, and this one already has been.")


func _on_rename_pressed() -> void:
	Audio.play("ui_open")
	_rename_row.visible = true
	_rename_note.visible = true
	_rename_note.add_theme_color_override("font_color", COL_BRONZE)


	_rename_note.text = tr("This can only be done ONCE. Whatever you confirm here is your name on every board from now on, and it cannot be changed again or taken back.")
	_rename_edit.text = ""
	_rename_edit.grab_focus()


func _close_rename() -> void:
	Audio.play("ui_back")
	_rename_row.visible = false
	_rename_note.visible = false


func _on_rename_submitted(text: String) -> void:
	var wanted:= text.strip_edges()
	if wanted.length() < 3:
		_rename_fault(tr("A name is at least three characters."))
		return

	_rename_edit.editable = false
	var res: Dictionary = await Leaderboard.rename(wanted)
	if not is_instance_valid(self):
		return
	_rename_edit.editable = true

	if not res.get("ok", false):


		var reason:= str(res.get("error", ""))
		_rename_fault(reason.capitalize() + "." if reason != "" else tr("That did not work."))
		return

	Audio.play("ui_select")
	_rename_row.visible = false
	_rename_note.visible = false
	_refresh_identity()
	_load_board()


func _rename_fault(message: String) -> void:
	Audio.play("ui_error")
	_rename_note.visible = true
	_rename_note.add_theme_color_override("font_color", Color(1.0, 0.6, 0.52))
	_rename_note.text = message


static func _ordinal(n: int) -> String:


	if n % 100 >= 11 and n % 100 <= 13:
		return Cfg.tr("%dth", "ordinal: 11th, 12th, 13th") % n
	match n % 10:
		1: return Cfg.tr("%dst", "ordinal: 1st, 21st") % n
		2: return Cfg.tr("%dnd", "ordinal: 2nd, 22nd") % n
		3: return Cfg.tr("%drd", "ordinal: 3rd, 23rd") % n
	return Cfg.tr("%dth", "ordinal: 4th and the rest") % n


func _style_tab(b: Button, on: bool) -> void:
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", TAB_FONT)
	b.add_theme_color_override("font_color", COL_ACCENT if on else COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", COL_ACCENT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.17, 0.22, 0.95) if on else Color(0.07, 0.08, 0.1, 0.55)
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
		sb.content_margin_top = 5.0
		sb.content_margin_bottom = 5.0
		sb.border_width_bottom = 2
		sb.border_color = COL_ACCENT if on else Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(state, sb)


func _style_size(b: Button, on: bool) -> void:
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", SIZE_FONT)
	b.add_theme_color_override("font_color", COL_TEXT if on else COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", COL_ACCENT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.17, 0.22, 0.95) if on else Color(0.07, 0.08, 0.1, 0.55)
		sb.border_color = COL_ACCENT if on else COL_EDGE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 3.0
		sb.content_margin_bottom = 3.0
		b.add_theme_stylebox_override(state, sb)


func _style_pill(b: Button) -> void:
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_ACCENT)
	b.add_theme_color_override("font_pressed_color", COL_ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.43, 0.48))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var accent:= state == "hover" or state == "pressed"
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.18, 0.24, 0.95) if accent else COL_FILL
		sb.border_color = COL_ACCENT if accent else COL_EDGE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 5.0
		sb.content_margin_bottom = 5.0
		b.add_theme_stylebox_override(state, sb)
