class_name ShopMenu
extends Control


const PANEL_W:= 860.0
const PANEL_H:= 560.0


const SHELF_H:= 560.0


const ROW_ICON:= 52.0


const HELP_TEXT:= "E to close"

var player: Player
var props: PropManager
var shop: HayShop
var hud: Hud

var _panel: PanelContainer
var _money_label: Label
var _status_label: Label
var _buy_buttons: Dictionary = { }

var _owned_labels: Dictionary = { }
var _fetch_buttons: Dictionary = { }
var _licence_buttons: Dictionary = { }


var _rows: Dictionary = { }

var _hovered:= ""
var _row_box: StyleBoxFlat
var _row_locked: StyleBoxFlat
var _row_lit: StyleBoxFlat

var _locked_card: Control
var _locked_name: Label
var _locked_icon: TextureRect
var _locked_body: Label
var _locked_tree: Button
var _locked_id:= ""
var _open:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.money_changed.connect(_on_money_changed)
	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_refresh)


func _build_in() -> void:


	_row_box = _row_style(Color(ArmPanel.COL_PAPER, 0.0), Color(ArmPanel.COL_PAPER, 0.0))
	_row_locked = _row_style(ArmPanel.COL_TILE_EDGE, ArmPanel.COL_TILE)
	_row_lit = _row_style(ArmPanel.COL_INK, ArmPanel.COL_TILE_ON)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)


	_panel = PlateKit.card(PANEL_W)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	centre.add_child(_panel)

	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	whole.add_child(ArmPanel.band(tr("SUPPLY CO."), tr(HELP_TEXT),
		set_open.bind(false), null, false, "bucket", ArmPanel.SCOPE_SHOP) [0])
	whole.add_child(PlateKit.rule())


	var strip:= PanelContainer.new()
	strip.add_theme_stylebox_override("panel", ArmPanel.box(ArmPanel.COL_STRIP, ArmPanel.PAD, 10.0))
	whole.add_child(strip)
	var strip_row:= HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 12)
	strip.add_child(strip_row)
	strip_row.add_child(PlateIcons.rect("cart", 22, ArmPanel.COL_INK))
	_money_label = _label("", 20, ArmPanel.COL_INK, true)
	strip_row.add_child(_money_label)
	var subtitle:= _label(tr("Tools and containers"), 15, ArmPanel.COL_INK_SOFT)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip_row.add_child(subtitle)
	whole.add_child(PlateKit.rule())

	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(ArmPanel.PAD))
	inset.add_theme_constant_override("margin_right", int(ArmPanel.PAD))
	inset.add_theme_constant_override("margin_top", 10)
	inset.add_theme_constant_override("margin_bottom", 10)
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	whole.add_child(inset)
	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inset.add_child(box)


	var shelf:= ScrollContainer.new()
	shelf.custom_minimum_size = Vector2(0, SHELF_H)
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var bar:= shelf.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", MachinePanel._bar_box(ArmPanel.COL_HOVER))
	bar.add_theme_stylebox_override("grabber", MachinePanel._bar_box(ArmPanel.COL_INK_SOFT))
	bar.add_theme_stylebox_override("grabber_highlight", MachinePanel._bar_box(ArmPanel.COL_INK))
	bar.add_theme_stylebox_override("grabber_pressed", MachinePanel._bar_box(ArmPanel.COL_INK))
	box.add_child(shelf)
	var shelf_box:= VBoxContainer.new()
	shelf_box.add_theme_constant_override("separation", 10)
	shelf_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_child(shelf_box)

	for id: String in ItemDb.ids():
		if ItemDb.price(id) <= 0.0:
			continue
		shelf_box.add_child(_item_row(id))


	var licences:= _licence_ids()
	if not licences.is_empty():
		shelf_box.add_child(_hrule())
		shelf_box.add_child(PlateKit.heading(tr("UNLOCKED IN THE TECH TREE"), "lock"))
		for id: String in licences:
			shelf_box.add_child(_licence_row(id))


	var foot:= PlateKit.foot(whole)
	_status_label = _label(tr(HELP_TEXT), 15, ArmPanel.COL_INK_SOFT)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.custom_minimum_size.y = 28.0
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_status_label)

	_build_locked_card()
	_on_money_changed(GameState.money)


func _licence_ids() -> Array:
	var out: Array = []
	if shop == null:
		return out
	for id: Variant in shop.display_ids():
		var s:= str(id)
		if not HayShop.sold_here(s) and TechTree.has_id(s):
			out.append(s)
	out.sort()
	return out


func _licence_row(id: String) -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 62)
	row.add_child(_row_icon(TechTree.icon_of(id)))

	var text_box:= VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	text_box.add_child(_label(Cfg.upper(TechTree.display_name(id)), 20, ArmPanel.COL_INK, true))
	var blurb:= _label(TechTree.blurb(id), 14, ArmPanel.COL_INK_SOFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(blurb)
	row.add_child(text_box)

	var price:= _label("$%s" % _fmt(TechTree.cost_at(id, 0)), 19, ArmPanel.COL_TAKE_INK, true)
	price.custom_minimum_size = Vector2(90, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)

	var owned:= Tech.is_unlocked(id)
	var btn:= _button(tr("OWNED") if owned else tr("TECH TREE"), _on_licence.bind(id),
		"working" if owned else "upgrade")
	btn.disabled = owned
	btn.custom_minimum_size = Vector2(100, 46)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	_licence_buttons [id] = btn
	return row


func _on_licence(id: String) -> void:
	set_open(false)
	if player != null and player.tech_panel != null:
		player.tech_panel.set_open(true)
	else:
		_status(tr("%s is bought on the tech tree (Tab)") % TechTree.display_name(id), false)


func _item_row(id: String) -> Control:
	var card:= PanelContainer.new()
	card.name = id
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _row_box)
	card.gui_input.connect(_on_row_input.bind(id))
	card.mouse_entered.connect(_on_row_hover.bind(id, true))
	card.mouse_exited.connect(_on_row_hover.bind(id, false))
	_rows [id] = card

	var row:= HBoxContainer.new()


	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 66)
	card.add_child(row)
	row.add_child(_row_icon(TechTree.icon_of(ItemDb.unlock_of(id))))

	var text_box:= VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	var name_label:= _label(ItemDb.display_name(id), 20, ArmPanel.COL_INK, true)
	text_box.add_child(name_label)
	var spec:= ItemDb.spec(id)
	var blurb:= _label(str(spec.get("blurb", "")), 14, ArmPanel.COL_INK_SOFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(blurb)
	row.add_child(text_box)


	var owned:= _label("", 14, ArmPanel.COL_INK_SOFT)
	owned.custom_minimum_size = Vector2(78, 0)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(owned)
	_owned_labels [id] = owned

	var price:= _label("$%s" % _fmt(ItemDb.price(id)), 19, ArmPanel.COL_TAKE_INK, true)
	price.custom_minimum_size = Vector2(80, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)

	var fetch:= _button(tr("BRING TO ME"), _on_fetch.bind(id), "drop")
	fetch.name = "Fetch"
	fetch.custom_minimum_size = Vector2(132, 46)
	fetch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fetch.tooltip_text = tr("Teleport the ones you already own to your feet")
	row.add_child(fetch)
	_fetch_buttons [id] = fetch

	var buy:= _button(tr("BUY"), _on_buy.bind(id), "cart")
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(100, 46)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)
	_buy_buttons [id] = buy
	return card


func _row_style(border: Color, bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(0)
	b.content_margin_left = 8.0
	b.content_margin_right = 8.0
	b.content_margin_top = 3.0
	b.content_margin_bottom = 3.0
	return b


func _on_row_hover(id: String, entered: bool) -> void:
	if entered:
		_hovered = id
	elif _hovered == id:
		_hovered = ""
	_paint_row(id)
	if not entered:
		_say(tr(HELP_TEXT))
		return
	if ItemDb.is_unlocked(id):
		_say(tr(HELP_TEXT))
	else:
		_say(tr("%s is locked. Click to see what unlocks it.") % ItemDb.display_name(id))


func _on_row_input(event: InputEvent, id: String) -> void:
	var mb:= event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if ItemDb.is_unlocked(id):
		return
	_show_locked(id)
	accept_event()


func _paint_row_in(id: String) -> void:


	_row_locked.bg_color = ArmPanel.COL_TILE
	_row_locked.border_color = ArmPanel.COL_TILE_EDGE
	_row_lit.bg_color = ArmPanel.COL_TILE_ON
	_row_lit.border_color = ArmPanel.COL_INK
	var card: PanelContainer = _rows.get(id)
	if card == null:
		return
	var unlocked:= ItemDb.is_unlocked(id)
	if unlocked:
		card.add_theme_stylebox_override("panel", _row_box)
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	card.add_theme_stylebox_override("panel",
		_row_lit if _hovered == id else _row_locked)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _row_icon(tile: String) -> Control:
	var rect:= TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.custom_minimum_size = Vector2(ROW_ICON, ROW_ICON)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER


	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex:= TechPanel.icon_for(tile)
	rect.texture = tex


	rect.visible = tex != null
	return rect


func _build_locked_card() -> void:
	_locked_card = Control.new()
	_locked_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	_locked_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_locked_card.visible = false
	add_child(_locked_card)


	var dim:= ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked_card.add_child(dim)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked_card.add_child(centre)

	var panel:= PlateKit.card(480.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	panel.add_child(whole)
	whole.add_child(ArmPanel.band(tr("LOCKED"), "", _hide_locked, null, false, "",
		ArmPanel.SCOPE_SHOP) [0])
	whole.add_child(PlateKit.rule())
	var inset:= MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		inset.add_theme_constant_override(side, 26)
	inset.add_theme_constant_override("margin_top", 16)
	inset.add_theme_constant_override("margin_bottom", 20)
	whole.add_child(inset)
	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inset.add_child(box)


	var icon_row:= CenterContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_row)
	_locked_icon = TextureRect.new()
	_locked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked_icon.custom_minimum_size = Vector2(72, 72)
	_locked_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_locked_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_locked_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_row.add_child(_locked_icon)

	_locked_name = _label("", 19, ArmPanel.COL_INK, true)
	_locked_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_locked_name)

	box.add_child(_hrule())

	_locked_body = _label("", 15, ArmPanel.COL_INK_SOFT)
	_locked_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_locked_body.custom_minimum_size = Vector2(0, 52)
	box.add_child(_locked_body)

	var buttons:= HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	var back:= _button(tr("BACK TO THE SHELF"), _hide_locked, "back")
	back.custom_minimum_size = Vector2(190, 46)
	buttons.add_child(back)

	_locked_tree = _button(tr("OPEN TECH TREE"), _on_locked_tree, "upgrade")
	_locked_tree.custom_minimum_size = Vector2(190, 46)
	buttons.add_child(_locked_tree)


func _show_locked_in(id: String) -> void:
	if _locked_card == null:
		return
	_locked_id = id
	_locked_name.text = Cfg.upper(ItemDb.display_name(id))
	var node:= ItemDb.unlock_of(id)
	var tex:= TechPanel.icon_for(TechTree.icon_of(node))
	_locked_icon.texture = tex


	_locked_icon.visible = tex != null
	var key:= InputSetup.hint("tech_tree")


	if TechTree.has_id(node):
		_locked_body.text = tr("Buy the %s card in the tech tree first. Press %s to open it.") % [
			TechTree.display_name(node), key]
	else:
		_locked_body.text = tr("Unlock this in the tech tree first. Press %s to open it.") % key


	_locked_tree.visible = TechTree.has_id(node) and player != null and player.tech_panel != null
	_locked_card.visible = true
	Audio.play("ui_open", -6.0)


func _hide_locked() -> void:
	if _locked_card == null or not _locked_card.visible:
		return
	_locked_card.visible = false
	_locked_id = ""
	Audio.play("ui_close", -6.0)


func _on_locked_tree() -> void:
	var node:= ItemDb.unlock_of(_locked_id)
	var tree: TechPanel = player.tech_panel if player != null else null
	_locked_card.visible = false
	_locked_id = ""
	if tree == null or not TechTree.has_id(node):
		Audio.play("ui_error")
		return
	set_open(false)
	tree.show_node(node)


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 0, heavy)
	l.text = text

	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _hrule() -> Control:
	var r:= ColorRect.new()
	r.color = ArmPanel.COL_TILE_EDGE
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _button(text: String, action: Callable, icon: String = "") -> Button:
	var b:= PlateKit.button(text, icon, action)
	b.size_flags_horizontal = Control.SIZE_FILL
	b.add_theme_font_size_override("font_size", 16)
	return b


static func _fmt(v: float) -> String:
	return Hud.money_text(v)


func is_near_shop() -> bool:
	if player == null or shop == null:
		return false


	if player.carry != null and player.carry.is_carrying() and not player.carry.toy_in_hand():
		return false


	return shop.is_near(player.global_position)


func is_at_counter() -> bool:
	if player == null or shop == null:
		return false
	if not is_near_shop():
		return false
	return shop.is_hovered(player.eye_position(), player.look_direction())


var fetched:= 0


func is_open() -> bool:
	return _open


func try_open() -> bool:
	if _open or not is_at_counter():
		return false
	set_open(true)
	return true


func set_open(on: bool) -> void:
	if on and not is_near_shop():
		return
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if not on and _locked_card != null:

		_locked_card.visible = false
		_locked_id = ""
	if on:
		_hovered = ""
		_say(tr(HELP_TEXT))
		_refresh()
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return


	if _locked_card != null and _locked_card.visible:
		if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact") or event.is_action_pressed("secondary"):
			_hide_locked()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("tech_tree"):


			_on_locked_tree()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _on_money_changed(amount: float) -> void:
	if _money_label != null:
		_money_label.text = tr("Available:  $%.2f") % amount
	_refresh()


func _on_tech_changed(_id: String, _rank: int) -> void:
	_refresh()


func _refresh_in() -> void:
	if _buy_buttons.is_empty() and _licence_buttons.is_empty():
		return
	for id: String in _buy_buttons:
		var b: Button = _buy_buttons [id]
		var licensed:= ItemDb.is_unlocked(id)


		b.disabled = licensed and not GameState.can_afford(ItemDb.price(id))
		b.text = tr("BUY") if licensed else tr("LOCKED")
		b.icon = PlateIcons.texture("cart" if licensed else "lock", 20)
		b.add_theme_color_override("font_color", ArmPanel.COL_INK if licensed else ArmPanel.COL_LOCKED)
		_paint_row(id)
		var n:= _owned_count(id)
		if _owned_labels.has(id):
			var lab: Label = _owned_labels [id]
			lab.text = "" if n == 0 else tr("you own %d") % n
		if _fetch_buttons.has(id):
			var fb: Button = _fetch_buttons [id]


			fb.visible = n > 0
	for id: String in _licence_buttons:
		var lb: Button = _licence_buttons [id]
		var owned:= Tech.is_unlocked(id)
		lb.disabled = owned
		lb.text = tr("OWNED") if owned else tr("TECH TREE")
		lb.icon = PlateIcons.texture("working" if owned else "upgrade", 20)


	if _locked_id != "" and ItemDb.is_unlocked(_locked_id):
		_hide_locked()


func _on_buy(id: String) -> void:
	if not _open:
		return


	if not ItemDb.is_unlocked(id):
		_show_locked(id)
		return
	if props == null or player == null or not is_near_shop():
		return
	var price:= ItemDb.price(id)
	if not GameState.spend_money(price):
		Audio.play("ui_error")
		_status(tr("Not enough cash for %s") % ItemDb.display_name(id), false)
		_refresh()
		return


	var item:= props.spawn_at_feet(id, player)
	if item == null:


		GameState.add_money(price)
		Audio.play("ui_error")
		_status(tr("Could not place that item"), false)
		_refresh()
		return

	GameState.note_purchase("tool", id, 0, price)
	Audio.play("build_confirm", -4.0)


	if GameState.TOOL_IDS.has(id) and not GameState.can_carry_another():
		_status(tr("Purchased %s. Your hands are full: press %s to put a tool down, then pick this one up.")
			% [ItemDb.display_name(id), InputSetup.hint("drop_tool")], true)
	else:
		_status(tr("Purchased %s") % ItemDb.display_name(id), true)
	_refresh()


func _owned_count(id: String) -> int:
	if props == null:
		return 0
	var n:= props.count_of(id)
	if GameState.has_tool(id):
		n += 1
	return n


func _on_fetch(id: String) -> void:
	if not _open or props == null or player == null:
		return
	var moved:= 0
	for item in props.items:
		if not is_instance_valid(item) or item.item_id != id:
			continue
		if item.is_held():
			continue
		props.place_at_feet(item, player, moved)
		moved += 1
	if moved == 0:
		Audio.play("ui_error")
		var have_tool:= GameState.has_tool(id)
		_status(tr("Your %s is already in your hands") % ItemDb.display_name(id)
			if have_tool else tr("You do not own one yet"), false)
		return
	GameState.used_fetch = true


	fetched += 1
	Audio.play("build_confirm", -5.0)
	_status(tr("Brought %d %s to your feet") % [moved, ItemDb.display_name(id)], true)


func _status_in(text: String, good: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", ArmPanel.COL_GO if good else ArmPanel.COL_WARN)


func _say_in(text: String) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", ArmPanel.COL_INK_SOFT)


func _build() -> void:
	var was:= ArmPanel.push_palette(ArmPanel.mode_of(ArmPanel.SCOPE_SHOP))
	_build_in()
	ArmPanel.pop_palette(was)


func _refresh() -> void:
	var was:= ArmPanel.push_palette(ArmPanel.mode_of(ArmPanel.SCOPE_SHOP))
	_refresh_in()
	ArmPanel.pop_palette(was)


func _say(text: String) -> void:
	var was:= ArmPanel.push_palette(ArmPanel.mode_of(ArmPanel.SCOPE_SHOP))
	_say_in(text)
	ArmPanel.pop_palette(was)


func _status(text: String, good: bool) -> void:
	var was:= ArmPanel.push_palette(ArmPanel.mode_of(ArmPanel.SCOPE_SHOP))
	_status_in(text, good)
	ArmPanel.pop_palette(was)


func _paint_row(id: String) -> void:
	var was:= ArmPanel.push_palette(ArmPanel.mode_of(ArmPanel.SCOPE_SHOP))
	_paint_row_in(id)
	ArmPanel.pop_palette(was)


func _show_locked(id: String) -> void:
	var was:= ArmPanel.push_palette(ArmPanel.mode_of(ArmPanel.SCOPE_SHOP))
	_show_locked_in(id)
	ArmPanel.pop_palette(was)
