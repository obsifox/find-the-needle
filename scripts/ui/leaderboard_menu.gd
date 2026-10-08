class_name LeaderboardMenu
extends Control


var player: Player
var board: RankBoard

var _open:= false
var _panel: LeaderboardPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:


	var wash:= ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.0, 0.0, 0.0, 0.45)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card:= PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	sb.border_color = LeaderboardPanel.COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)

	var column:= VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	var heading:= Label.new()
	heading.text = tr("LEADERBOARDS")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(heading, 26, LeaderboardPanel.COL_TEXT, 0, true)
	column.add_child(heading)

	var blurb:= Label.new()
	blurb.text = tr(LeaderboardPanel.BLURB)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(blurb, 15, LeaderboardPanel.COL_DIM, 0)
	column.add_child(blurb)

	_panel = LeaderboardPanel.new()
	column.add_child(_panel)

	var close:= Button.new()
	close.text = tr("CLOSE")
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(160, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel._style_pill(close)
	close.pressed.connect(set_open.bind(false))
	column.add_child(close)

	var hint:= Label.new()
	hint.text = tr("%s or ESC to close") % InputSetup.hint("interact")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(hint, 13, LeaderboardPanel.COL_DIM, 0)
	column.add_child(hint)


func is_open() -> bool:
	return _open


func is_at_board() -> bool:
	if player == null or board == null or not is_instance_valid(board):
		return false
	if player.carry != null and player.carry.is_carrying() and not player.carry.toy_in_hand():
		return false
	return board.is_hovered(player.eye_position(), player.look_direction())


func try_open() -> bool:
	if _open or not is_at_board():
		return false
	set_open(true)
	return true


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if on:


		_panel.refresh()
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse"):
		set_open(false)
		get_viewport().set_input_as_handled()
		return


	if event.is_action_pressed("interact") and not (get_viewport().gui_get_focus_owner() is LineEdit):
		set_open(false)
		get_viewport().set_input_as_handled()
