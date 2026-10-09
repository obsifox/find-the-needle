class_name LoadPanel
extends Control


const CARD_W:= 500.0
const PAD:= 24.0


const COL_PAPER:= DeliveryBoard.COL_PAPER
const COL_INK:= DeliveryBoard.COL_INK
const COL_RED:= DeliveryBoard.COL_RED
const COL_FADE:= Color(0.13, 0.12, 0.11, 0.42)
const COL_WASH:= Color(0, 0, 0, 0.55)


const COL_DONE:= Color(0.16, 0.38, 0.14)


static var LOCK_ICON: Texture2D = load("res://assets/ui/compiled/icon_lock.ctex")
const LOCK_PX:= 20

const TICK_PX:= 18.0

const H_TITLE:= 22
const H_HEAD:= 16
const H_NOTE:= 14
const H_BUTTON:= 16


const MAX_NAMED:= 3


signal order_requested(pay_now: bool)

var player: Player
var zone: LandingZone

var _open:= false


var _pay_dirty:= false

var _needles_state: Label
var _needles_line: Label
var _zone_state: Label
var _zone_line: Label
var _zone_button: Button
var _zone_lock_line: Label
var _pay_state: Label
var _bank_line: Label
var _now_button: Button
var _now_line: Label
var _later_button: Button
var _later_line: Label
var _debt_box: VBoxContainer
var _debt_line: Label
var _payoff_button: Button
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


	GameState.money_changed.connect(func(_m: float) -> void: _pay_dirty = true)
	GameState.debt_changed.connect(func(_d: float) -> void: _pay_dirty = true)


func _process(_delta: float) -> void:
	if _open and _pay_dirty:
		_pay_dirty = false
		_refresh_pay(_steps_done())


func _build() -> void:
	var wash:= ColorRect.new()
	wash.name = "Wash"
	wash.color = COL_WASH
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card:= PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_PAPER
	sb.border_color = Color(0.62, 0.58, 0.48)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = PAD
	sb.content_margin_bottom = PAD
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)

	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	card.add_child(col)

	var head:= HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	col.add_child(head)


	var balance:= Control.new()
	balance.custom_minimum_size = Vector2(PanelClose.SIZE, 0)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(balance)
	var title:= Label.new()
	title.text = tr("NEXT LOAD")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ink(title, H_TITLE, COL_INK, true)
	head.add_child(title)
	head.add_child(PanelClose.make(_shut, COL_PAPER))

	var intro:= _line(H_NOTE, COL_FADE, false)
	intro.text = tr("A truck brings a new pile of hay with new needles in it. Do these three steps to get it.")
	col.add_child(intro)


	col.add_child(_rule())
	_needles_state = _step(col, 1, tr("PUT ONE OF EACH NEEDLE IN THE CABINET"))
	_needles_line = _line(H_NOTE, COL_INK, false, true)
	col.add_child(_needles_line)


	col.add_child(_rule())
	_zone_state = _step(col, 2, tr("CLEAR THE LANDING SPOT"))
	_zone_line = _line(H_NOTE, COL_INK, false, true)
	col.add_child(_zone_line)
	_zone_button = _button("ZoneButton", press_zone)
	_zone_button.add_theme_constant_override("icon_max_width", LOCK_PX)
	_zone_button.add_theme_constant_override("h_separation", 8)
	col.add_child(_zone_button)
	_zone_lock_line = _line(H_NOTE, COL_FADE, false, true)
	col.add_child(_zone_lock_line)


	col.add_child(_rule())
	_pay_state = _step(col, 3, tr("PAY FOR THE HAY"))
	_bank_line = _line(H_NOTE, COL_INK, false, true)
	col.add_child(_bank_line)

	_now_button = _button("PayNowButton", press_order.bind(true))
	col.add_child(_now_button)
	_now_line = _line(H_NOTE, COL_INK, false, true)
	col.add_child(_now_line)

	_later_button = _button("PayLaterButton", press_order.bind(false))
	col.add_child(_later_button)
	_later_line = _line(H_NOTE, COL_INK, false, true)
	col.add_child(_later_line)


	_debt_box = VBoxContainer.new()
	_debt_box.add_theme_constant_override("separation", 5)
	col.add_child(_debt_box)
	_debt_box.add_child(_rule())
	_debt_line = _line(H_NOTE, COL_RED, true, true)
	_debt_box.add_child(_debt_line)
	_payoff_button = _button("PayOffButton", press_pay_off)
	_debt_box.add_child(_payoff_button)

	_note = _line(H_NOTE, COL_RED, true)
	col.add_child(_note)

	var foot:= _line(H_NOTE, COL_FADE, false)
	foot.text = tr("PRESS %s OR ESC TO CLOSE") % InputSetup.hint("interact")
	col.add_child(foot)


func _step(col: VBoxContainer, number: int, what: String) -> Label:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var tick:= Control.new()
	tick.custom_minimum_size = Vector2(TICK_PX, TICK_PX)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.set_meta("done", false)
	tick.draw.connect(_draw_tick.bind(tick))
	row.add_child(tick)
	var name_label:= Label.new()
	name_label.text = "%d.  %s" % [number, what]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(name_label, H_HEAD, COL_INK, true)
	row.add_child(name_label)
	var state:= Label.new()
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ink(state, H_HEAD, COL_RED, true)
	row.add_child(state)
	state.set_meta("tick", tick)
	return state


func _draw_tick(tick: Control) -> void:
	var s:= tick.size
	if bool(tick.get_meta("done", false)):
		tick.draw_rect(Rect2(Vector2.ZERO, s), COL_DONE)
		tick.draw_polyline(PackedVector2Array([
			s * Vector2(0.22, 0.52), s * Vector2(0.42, 0.74), s * Vector2(0.8, 0.28)]),
			COL_PAPER, 2.5, true)
	else:
		tick.draw_rect(Rect2(Vector2.ONE, s - Vector2(2.0, 2.0)), COL_INK, false, 2.0)


func _line(size: int, colour: Color, heavy: bool, left: bool = false) -> Label:
	var l:= Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARD_W - PAD * 2.0, 0)
	_ink(l, size, colour, heavy)
	return l


func _button(node_name: String, on_press: Callable) -> Button:
	var b:= Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


static func _ink(l: Label, size: int, colour: Color, heavy: bool) -> void:
	l.add_theme_font_override("font", UiFont.bold() if heavy else UiFont.regular())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("outline_size", 0)


func _rule() -> Control:
	var r:= ColorRect.new()
	r.color = Color(0.13, 0.12, 0.11, 0.2)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func is_open() -> bool:
	return _open


func open() -> void:
	set_open(true)


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if on:
		_write(_note, "")
		if zone != null:
			zone.refresh()
		refresh()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		_shut()
		get_viewport().set_input_as_handled()


func _shut() -> void:
	set_open(false)
	Audio.play("ui_close", -4.0)


func refresh() -> void:
	var case_done:= _refresh_needles()
	var ground_done:= _refresh_zone()
	_refresh_pay(case_done and ground_done)


func _refresh_needles() -> bool:
	var ready:= GameState.may_order_pile()
	var need:= NeedleTypes.pool(GameState.lot_tier).size()
	var missing:= GameState.lot_missing()


	if GameState.demo_is_over():
		_state(_needles_state, false, tr("FULL GAME"))
		_write(_needles_line, tr("All %d kinds are in the cabinet. That is the end of the demo. The next load comes with the full game.") % need)
		return false
	if ready:
		_state(_needles_state, true, tr("DONE"))
		_write(_needles_line, tr("All %d kinds of needle are in the cabinet.") % need)
		return true
	_state(_needles_state, false, tr("%d OF %d") % [need - missing.size(), need])
	if missing.size() <= MAX_NAMED:
		var names:= PackedStringArray()
		for t in missing:
			names.append(NeedleTypes.name_of(t))
		_write(_needles_line, tr("Find these in the hay and put them in the cabinet: %s.")
			% ", ".join(names))
	else:
		_write(_needles_line, tr("%d kinds are still missing. Find them in the hay and put them in the cabinet.")
			% missing.size())
	return false


func _refresh_zone() -> bool:
	var clear:= _zone_clear()
	if clear:
		_state(_zone_state, true, tr("DONE"))
	else:
		_state(_zone_state, false, tr("NOT DONE"))
	_write(_zone_line, tr("Anything you built in the zone where the new pile lands has to be taken down first."))

	var shown:= zone != null and zone.is_shown()


	var locked:= not shown and not wall_unlocked()
	_zone_button.text = tr("HIDE THE RED WALL") if shown else tr("SHOW WHERE IT LANDS")
	_zone_button.icon = LOCK_ICON if locked else null
	_style_button(_zone_button, not locked)
	if locked:


		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
				"icon_focus_color"]:
			_zone_button.add_theme_color_override(state, COL_INK)
	_zone_lock_line.visible = locked
	if locked:
		_write(_zone_lock_line, tr("Locked. Find %d needles to use it. You have found %d.")
			% [Cfg.LANDING_WALL_NEEDLES, GameState.needles_found])
	return clear


static func wall_unlocked() -> bool:
	return GameState.needles_found >= Cfg.LANDING_WALL_NEEDLES


func _refresh_pay(steps_done: bool) -> void:
	var fee:= GameState.next_stack_fee()
	var credit:= GameState.credit_stack_fee()
	var bank:= GameState.money
	if steps_done:
		_write(_bank_line, tr("You have $%s.") % Hud.money_text(bank))
	else:
		_write(_bank_line, tr("You have $%s. Do steps 1 and 2 first, then pick how to pay.")
			% Hud.money_text(bank))

	if fee <= 0.0:


		_state(_pay_state, true, tr("FREE"), false)
		_now_button.text = tr("GET THE LOAD")
		_style_button(_now_button, steps_done)
		_write(_now_line, tr("This load costs nothing."))
		_later_button.visible = false
		_later_line.visible = false
	else:
		_state(_pay_state, false, "")
		_later_button.visible = true
		_later_line.visible = true


		_now_button.text = tr("PAY NOW  ·  $%s") % Hud.money_text(fee)
		var can_pay:= GameState.can_afford(fee)
		_style_button(_now_button, steps_done and can_pay)
		if can_pay:
			_write(_now_line, tr("Paid from your money straight away. You will have $%s left.")
				% Hud.money_text(bank - fee))
			_now_line.add_theme_color_override("font_color", COL_INK)
		else:
			_write(_now_line, tr("You need $%s more to pay now.")
				% Hud.money_text(fee - bank))
			_now_line.add_theme_color_override("font_color", COL_RED)

		_later_button.text = tr("PAY LATER  ·  $%s") % Hud.money_text(credit)
		_style_button(_later_button, steps_done)
		_write(_later_line, tr("Costs $%s more. Until it is paid, the stand keeps half of the money from every sale.")
			% Hud.money_text(credit - fee))

	var owed:= GameState.debt
	_debt_box.visible = owed > 0.0
	if owed > 0.0:
		_write(_debt_line, tr("You still owe $%s. The stand is keeping half of every sale until it is paid.")
			% Hud.money_text(owed))
		var can:= minf(owed, bank)
		if can >= owed:
			_payoff_button.text = tr("PAY IT ALL OFF  ·  $%s") % Hud.money_text(owed)
		else:
			_payoff_button.text = tr("PAY $%s OF IT OFF") % Hud.money_text(can)
		_style_button(_payoff_button, can > 0.0)


func _steps_done() -> bool:
	return GameState.may_order_pile() and _zone_clear()


func _zone_clear() -> bool:
	return zone == null or not zone.is_blocked()


func _state(l: Label, done: bool, text: String, ticked: bool = done) -> void:
	_write(l, text)
	l.add_theme_color_override("font_color", COL_DONE if done else COL_RED)
	var tick:= l.get_meta("tick", null) as Control
	if tick != null and bool(tick.get_meta("done", false)) != ticked:
		tick.set_meta("done", ticked)
		tick.queue_redraw()


func _style_button(b: Button, awake: bool) -> void:
	var ink:= COL_INK if awake else COL_FADE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", H_BUTTON)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		b.add_theme_color_override(state, ink)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_focus_color"]:
		b.add_theme_color_override(state, ink)
	var normal:= _box(awake, 0.06 if awake else 0.02)
	var hover:= _box(awake, 0.14 if awake else 0.02)
	for state in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed"]:
		b.add_theme_stylebox_override(state, hover)


static func _box(awake: bool, fill: float) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.11, fill)
	sb.border_color = Color(0.13, 0.12, 0.11, 0.55 if awake else 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _say(text: String) -> void:
	_write(_note, text)


func press_zone() -> void:
	if zone == null:
		return
	if not zone.is_shown() and not wall_unlocked():
		var more:= Cfg.LANDING_WALL_NEEDLES - GameState.needles_found
		_say(tr_n("Find %d more needle to unlock this.", "Find %d more needles to unlock this.",
			more) % more)
		Audio.play("ui_error", -6.0)
		return
	zone.set_shown(not zone.is_shown())
	if zone.is_shown():
		_say(tr("A red wall is up in the yard where the hay will land. Anything in the way is red too. Hide it here, or it goes when the load comes."))
	else:
		_say("")
	Audio.play("ui_select", -6.0)
	refresh()


func press_order(pay_now: bool = false) -> void:


	if GameState.demo_is_over():
		_say(tr("That is the end of the demo. The next load comes with the full game."))
		Audio.play("ui_error", -6.0)
		return
	if not GameState.may_order_pile():
		var missing:= GameState.lot_missing()
		if missing.size() == 1:
			_say(tr("Step 1 is not done. %s is still missing from the case.")
				% NeedleTypes.name_of(missing [0]))
		else:
			_say(tr("Step 1 is not done. %d kinds are still missing from the case.")
				% missing.size())
		Audio.play("ui_error", -6.0)
		return
	if zone != null:
		zone.refresh()
		if zone.is_blocked():
			zone.set_shown(true)
			_say(tr("Step 2 is not done. Something is standing where the hay will land. It is marked in red in the yard."))
			Audio.play("ui_error", -6.0)
			refresh()
			return
	var fee:= GameState.next_stack_fee()
	if pay_now and not GameState.can_afford(fee):
		_say(tr("You need $%s more to pay now. You can pay later instead.")
			% Hud.money_text(fee - GameState.money))
		Audio.play("ui_error", -6.0)
		return
	set_open(false)
	order_requested.emit(pay_now)


func press_pay_off() -> void:
	if GameState.debt <= 0.0:
		return
	var paid:= GameState.pay_off_debt()
	if paid <= 0.0:
		_say(tr("You have no money to pay with yet."))
		Audio.play("ui_error", -6.0)
		return
	if GameState.debt <= 0.0:
		_say(tr("Paid $%s. You do not owe anything now.") % Hud.money_text(paid))
	else:
		_say(tr("Paid $%s. You still owe $%s.")
			% [Hud.money_text(paid), Hud.money_text(GameState.debt)])
	Audio.play("coins", -4.0)
	refresh()


static func _write(l: Label, text: String) -> void:
	if l != null and l.text != text:
		l.text = text
