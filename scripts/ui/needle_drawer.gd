class_name NeedleDrawer
extends Control


const PANEL_W:= 900.0
const PANEL_H:= 684.0


const MIN_W:= 620.0

const SCREEN_PAD:= 20.0
const CARD_W:= 200.0
const CARD_H:= 268.0
const VIEW_H:= 130.0
const COLUMNS:= 4
const GAP:= 10.0


const CHROME_H:= 204.0

const EMPTY_H:= 60.0

const FOOTER_H:= 44.0


const SCROLL_W:= 16.0


const PAD:= ArmPanel.PAD
const RULE:= ArmPanel.RULE


const REFRESH:= ArmPanel.REFRESH

var player: Player

var _scanner: HaystackScanner
var _open:= false
var _panel: PanelContainer

var _top: Dictionary
var _timer:= 0.0
var _grid: GridContainer
var _footer: Label
var _footer_rule: Control

var _switch: ArmPanel.PowerToggle

var _empty: Label
var _scroll: ScrollContainer


var _index_of: Dictionary = { }


var _views: Array [NeedleView] = []
const META_VIEW:= &"needle_view"


var _spare_cards: Dictionary = { }
var _spare_count:= 0
const SPARE_CARDS:= 48
const META_KEY:= &"card_key"

var _card_box: StyleBoxFlat
var _card_hover: StyleBoxFlat
var _card_locked: StyleBoxFlat


var _locked:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	get_viewport().size_changed.connect(_fit)


func is_open() -> bool:
	return _open


func scanner() -> HaystackScanner:
	return _scanner


func open(from: HaystackScanner) -> void:
	if from == null:
		return
	_scanner = from
	if from.has_bank() and not from.is_drawer_open():
		from.open_drawer()


	if not from.caught.is_connected(_on_caught):
		from.caught.connect(_on_caught)
	_fill()
	set_open(true)


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if not on:


		if is_instance_valid(_scanner):
			if _scanner.caught.is_connected(_on_caught):
				_scanner.caught.disconnect(_on_caught)
			if _scanner.is_drawer_open():
				_scanner.close_drawer()
		_scanner = null
		_clear()
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return


	if event.is_action_pressed("interact") or event.is_action_pressed("secondary") or event.is_action_pressed("free_mouse"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim:= ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


	ArmPanel.ensure_mode()
	_card_box = _make_card_box(ArmPanel.COL_INK, ArmPanel.COL_PAPER)

	_card_hover = _make_card_box(ArmPanel.COL_INK, ArmPanel.COL_HOVER)


	_card_locked = _make_card_box(ArmPanel.COL_INK_SOFT, ArmPanel.COL_PAPER)


	_panel = PlateKit.card(MIN_W)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)


	_switch = ArmPanel.PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	_top = PlateKit.top(whole, tr("SCANNER DRAWER"), "scanner",
		func() -> void: set_open(false), _switch)

	var inset:= MarginContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_left", int(PAD))
	inset.add_theme_constant_override("margin_right", int(PAD))
	inset.add_theme_constant_override("margin_top", int(PAD) - 2)
	inset.add_theme_constant_override("margin_bottom", int(PAD))
	whole.add_child(inset)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inset.add_child(box)

	var scroll:= ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS


	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	scroll.add_child(_grid)
	_scroll = scroll

	_empty = _label(tr("THE TRAY IS EMPTY"), 17, ArmPanel.COL_INK_SOFT, true)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.visible = false
	box.add_child(_empty)


	_footer_rule = PlateKit.rule()
	box.add_child(_footer_rule)
	_footer = _label("", 16, ArmPanel.COL_INK_SOFT)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_footer)


func _fit() -> void:
	if _panel == null:
		return
	var screen:= get_viewport_rect().size
	var avail_w: float = maxf(320.0, screen.x - SCREEN_PAD * 2.0)
	var avail_h: float = maxf(240.0, screen.y - SCREEN_PAD * 2.0)
	var chrome_w:= RULE * 2.0 + PAD * 2.0 + SCROLL_W


	var room: float = minf(PANEL_W, avail_w) - chrome_w
	var cols:= int(floorf((room + GAP) / (CARD_W + GAP)))
	cols = clampi(cols, 1, COLUMNS)
	var n: int = maxi(1, _grid.get_child_count())
	cols = mini(cols, n)
	_grid.columns = cols

	var want_w:= chrome_w + float(cols) * CARD_W + float(cols - 1) * GAP
	var w: float = clampf(maxf(want_w, MIN_W), 0.0, avail_w)

	var rows:= int(ceilf(float(n) / float(cols)))
	var want_h:= CHROME_H + float(rows) * CARD_H + float(rows - 1) * GAP
	if _grid.get_child_count() == 0:

		want_h = CHROME_H - FOOTER_H + EMPTY_H
	var h: float = clampf(want_h, 0.0, minf(PANEL_H, avail_h))

	_panel.offset_left = - w * 0.5
	_panel.offset_right = w * 0.5
	_panel.offset_top = - h * 0.5
	_panel.offset_bottom = h * 0.5


func _make_card_box(border: Color, bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(0)
	b.content_margin_left = 10.0
	b.content_margin_right = 10.0
	b.content_margin_top = 10.0
	b.content_margin_bottom = 10.0
	return b


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


	UiFont.style(l, size, colour, 0, heavy)
	return l


func _fill() -> void:
	_clear()
	if not is_instance_valid(_scanner):
		return
	_locked = player != null and player.hand != null and player.hand.is_holding()
	for index in _scanner.banked:
		var card:= _card(index)
		_index_of [card] = index
		_grid.add_child(card)
	_show_empty()
	_fit()
	_say()


func _show_empty() -> void:
	var empty:= _grid.get_child_count() == 0
	_empty.visible = empty
	_scroll.visible = not empty


func _clear() -> void:
	_index_of.clear()
	if _grid == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		var view: NeedleView = child.get_meta(META_VIEW) if child.has_meta(META_VIEW) else null
		if view != null and is_instance_valid(view):
			view.park()
		if _spare_count < SPARE_CARDS and child.has_meta(META_KEY):
			var key:= String(child.get_meta(META_KEY))
			if not _spare_cards.has(key):
				_spare_cards [key] = []
			(_spare_cards [key] as Array).append(child)
			_spare_count += 1
			continue
		_drop_card(child)


func _drop_card(card: Node) -> void:
	var view: NeedleView = card.get_meta(META_VIEW) if card.has_meta(META_VIEW) else null
	if view != null and is_instance_valid(view):
		view.get_parent().remove_child(view)
		_views.append(view)
	card.queue_free()


func _card_key(type: int) -> String:
	return "%d:%d" % [type, int(GameState.is_discovered(type))]


func _spare_card(key: String) -> PanelContainer:
	var spare: Array = _spare_cards.get(key, [])
	while not spare.is_empty():
		var card = spare.pop_back()
		_spare_count -= 1
		if not is_instance_valid(card):
			continue


		(card as PanelContainer).add_theme_stylebox_override("panel",
			_card_locked if _locked else _card_box)


		PlateKit.sync(card, ArmPanel.dark)
		var view: NeedleView = card.get_meta(META_VIEW) if card.has_meta(META_VIEW) else null
		if view != null and is_instance_valid(view):
			view.yaw = 0.0

			view.apply_preset()
		return card as PanelContainer
	return null


func _take_view(type: int) -> NeedleView:
	var view: NeedleView = null
	while view == null and not _views.is_empty():
		view = _views.pop_back()
		if not is_instance_valid(view):
			view = null
	if view == null:
		view = NeedleView.new()
		view.custom_minimum_size = Vector2(0, VIEW_H)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.clip = _scroll
		view.type = type
		return view


	view.set_type(type)
	view.yaw = 0.0
	return view


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:

		for key: String in _spare_cards:
			for card in _spare_cards [key]:
				if is_instance_valid(card):
					card.free()
		_spare_cards.clear()
		for view in _views:
			if is_instance_valid(view):
				view.free()
		_views.clear()


func _card(index: int) -> PanelContainer:
	var type:= GameState.type_of(index)
	var key:= _card_key(type)
	var spare:= _spare_card(key)
	if spare != null:
		return spare
	var card:= PanelContainer.new()
	card.set_meta(META_KEY, key)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", _card_locked if _locked else _card_box)
	card.gui_input.connect(_on_card_input.bind(card))
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))

	var col:= VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)


	var view:= _take_view(type)
	card.set_meta(META_VIEW, view)
	col.add_child(view)

	var name_label:= _label(NeedleTypes.name_of(type), 19, ArmPanel.COL_INK, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)

	var odds:= _label(tr("LOAD %d  ·  1 IN %d") % [NeedleTypes.lot_of(type) + 1,
		NeedleTypes.one_in(type)], 14, ArmPanel.COL_INK_SOFT)
	odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(odds)


	if NeedleTypes.has_effect(type):
		var granted:= _label(NeedleTypes.effect_text(type), 14,
			ArmPanel.COL_INK if GameState.is_discovered(type) else ArmPanel.COL_INK_SOFT)
		granted.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		granted.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(granted)


	var new_line:= _label(tr("NEW TO THE CASE") if not GameState.is_discovered(type)
		else tr("IN THE CASE"), 14,
		ArmPanel.COL_INK if not GameState.is_discovered(type) else ArmPanel.COL_INK_SOFT)
	new_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(new_line)
	return card


func cards() -> Array [Control]:
	var out: Array [Control] = []
	if _grid == null:
		return out
	for child in _grid.get_children():
		if child is Control:
			out.append(child as Control)
	return out


func click_card(card: Control) -> void:
	_take(int(_index_of.get(card, -1)))


func _on_caught(index: int, _at: Vector3) -> void:
	if not _open or not is_instance_valid(_scanner):
		return
	if _index_of.values().has(index):
		return
	var card:= _card(index)
	_index_of [card] = index
	_grid.add_child(card)
	_show_empty()
	_fit()
	_say()


func _on_switch() -> void:
	if is_instance_valid(_scanner):
		_scanner.set_switched_off(not _scanner.is_switched_off())
	_say()


func _process(delta: float) -> void:
	if not _open:
		return
	if not is_instance_valid(_scanner):
		set_open(false)
		return
	_timer -= delta
	if _switch.running == _scanner.is_switched_off() or _timer <= 0.0:
		_say()


func _on_card_hover(card: Control, on: bool) -> void:
	if _locked:
		return
	card.add_theme_stylebox_override("panel", _card_hover if on else _card_box)


func _on_card_input(event: InputEvent, card: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb:= event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	_take(int(_index_of.get(card, -1)))


func _take(index: int) -> void:
	if index < 0 or player == null or player.hand == null:
		return
	if not is_instance_valid(_scanner):
		set_open(false)
		return
	if player.hand.is_holding():
		Audio.play("ui_error")
		_say()
		return
	var at:= _scanner.bin_position()
	if not _scanner.take_banked(index):


		_fill()
		return
	if not player.hand.take_needle(index, at):


		_scanner.rebank(index)
		_fill()
		return
	Audio.play_3d("needle_ting", at, -5.0)
	set_open(false)


func _say() -> void:
	if not is_instance_valid(_scanner):
		return
	_timer = REFRESH
	var n:= _scanner.banked.size()
	_switch.set_running(not _scanner.is_switched_off())


	PlateKit.write_status(_top, _scanner,
		tr_n("%d needle in the tray", "%d needles in the tray", n) % n, player)
	var full:= player != null and player.hand != null and player.hand.is_holding()
	_footer.visible = n > 0
	_footer_rule.visible = n > 0
	if full:
		_footer.text = tr("YOUR HANDS ARE FULL")
	else:
		_footer.text = tr("CLICK A NEEDLE TO TAKE IT TO THE CABINET")
