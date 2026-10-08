class_name CatalogPanel
extends Control


const PANEL_W:= 940.0


const PANEL_H:= 712.0
const CARD_H:= 74.0
const CARD_ICON:= 56.0


const GRID_COLS:= 4
const TILE_H:= 172.0
const TILE_ICON:= 84.0
const TILE_GAP:= 10


const TILE_LOCK:= 22.0
const TILE_BADGE:= 13


const PANEL_LIFT:= 46.0


const SUBTITLE_SIZE:= 15
const PROMPT_ICON:= 26.0
const PROMPT_GAP:= 26

const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_TEXT:= Color(0.92, 0.94, 0.98)
const COL_DIM:= Color(0.72, 0.76, 0.84)
const COL_LOCKED:= Color(0.55, 0.58, 0.64)
const COL_PIN:= Color(0.86, 0.72, 0.34)


const PIN_SIZE:= 16
const PIN_LINK_SIZE:= 13


const COL_LINK_HOVER:= Color(1.0, 0.86, 0.34)


const CARD_POP:= 1.022

const POP_GUTTER:= 12


const SCROLL_W:= 12.0
const CARD_PRESS:= 0.972
const POP_TIME:= 0.11
const PRESS_TIME:= 0.07


const TILE_POP:= 1.055
const TILE_PRESS:= 0.94


static var LOCK_ICON: Texture2D = load("res://assets/ui/icon_lock.svg")


const NAME_LOCK:= 16


const BUILD_ICON_SHEET:= preload("res://assets/ui/icons/build-menu-icons-game.png")

const BUILD_ICON_GRID:= 7
const BUILD_ICON_TILES:= {
	"arm": Vector2i(0, 0),
	"arm_long": Vector2i(0, 0),
	"arm_standard": Vector2i(0, 0),
	"belt": Vector2i(1, 0),
	"borehole": Vector2i(0, 4),
	"box": Vector2i(6, 3),
	"briquette_press": Vector2i(0, 5),
	"cabinet": Vector2i(4, 1),
	"compact_splitter": Vector2i(6, 5),
	"compressor": Vector2i(2, 0),
	"deck": Vector2i(5, 0),
	"drone": Vector2i(3, 0),
	"enclosed_belt": Vector2i(5, 5),
	"gas_plant": Vector2i(1, 6),
	"generator": Vector2i(3, 3),
	"hatch": Vector2i(2, 3),
	"haylift": Vector2i(6, 4),
	"haystairs": Vector2i(1, 2),
	"joiner": Vector2i(5, 1),
	"launcher": Vector2i(3, 2),
	"needle_radar": Vector2i(3, 5),
	"paintboard": Vector2i(5, 3),
	"paper_machine": Vector2i(5, 4),
	"pelletizer": Vector2i(3, 1),
	"pipe": Vector2i(1, 4),
	"pole": Vector2i(4, 3),
	"pulper": Vector2i(2, 4),
	"rail": Vector2i(0, 1),
	"rake": Vector2i(2, 2),
	"roof": Vector2i(5, 2),
	"roof_hatch": Vector2i(0, 3),
	"roof_pitch": Vector2i(6, 2),
	"scanner": Vector2i(2, 1),
	"silo": Vector2i(1, 3),
	"smart_splitter": Vector2i(0, 6),
	"splitter": Vector2i(1, 1),
	"stair": Vector2i(6, 0),
	"u_joiner": Vector2i(2, 5),
	"u_splitter": Vector2i(1, 5),
	"t_splitter": Vector2i(4, 5),
	"wall": Vector2i(6, 1),
	"wall_door": Vector2i(4, 2),
	"wall_window": Vector2i(0, 2),
	"water_splitter": Vector2i(3, 4),
	"worklamp": Vector2i(4, 4),
	"wrapper": Vector2i(4, 0),
}


const TAB_ICON_FOR:= {
	"excavation": "rake",
	"haulage": "belt",
	"processing": "compressor",
	"power": "generator",


	"water": "borehole",
	"structure": "wall",
	"prospecting": "scanner",
}


static var TAB_ALL_ICON: Texture2D = load("res://assets/ui/icon_grid.svg")
static var TAB_UNLOCKED_ICON: Texture2D = load("res://assets/ui/icon_unlock.svg")


static var TAB_HOTKEYED_ICON: Texture2D = load("res://assets/ui/icon_hotkeyed.svg")


static var VIEW_LIST_ICON: Texture2D = load("res://assets/ui/icon_view_list.svg")
static var VIEW_GRID_ICON: Texture2D = load("res://assets/ui/icon_view_grid.svg")
const VIEW_ICON:= 22
const VIEW_BUTTON:= 38.0


static var SORT_ICON: Texture2D = load("res://assets/ui/icon_recent.svg")


const SORT_LABEL:= "Sort by last used"
const SORT_SIZE:= 14
const SORT_GAP:= 14.0


const SORT_BUTTON:= 176.0


static var SEARCH_ICON: Texture2D = load("res://assets/ui/icon_search.svg")
const SEARCH_W:= 230.0


const TIP_WRAP:= 54


const TAB_ICON:= 34


const ICON_LIT:= Color(1.2, 1.2, 1.2)
const ICON_DIM:= Color(0.74, 0.76, 0.8)

var player: Player


var gift_card: GiftCard

var _panel: PanelContainer


var _subtitle: HBoxContainer
var _list: VBoxContainer


var _grid: GridContainer
var _footer: Label
var _cat_buttons: Dictionary = { }
var _cards: Dictionary = { }


var _tiles: Dictionary = { }


var _grid_view:= false
var _view_list_btn: Button
var _view_grid_btn: Button


var _sort_recent:= true
var _sort_btn: Button


var _search: LineEdit


const TAB_UNLOCKED:= "@unlocked"


const TAB_HOTKEYED:= "@hotkeyed"


var _category:= ""
var _hovered:= ""


var _pending_slot:= -1
var _open:= false

var _card_box: StyleBoxFlat
var _card_hover: StyleBoxFlat
var _card_locked: StyleBoxFlat


var _card_locked_hover: StyleBoxFlat
var _card_found: StyleBoxFlat


var _pop_tweens: Dictionary = { }


var _scroll: ScrollContainer


var _found:= ""
var _found_tween: Tween


var _announced: Dictionary = { }

static var _icon_cache: Dictionary = { }


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.hotbar_changed.connect(_refresh_pins)
	Cfg.t_splitter_size_changed.connect(func(_r: float) -> void: _paint_sizes())


func is_open() -> bool:
	return _open


func set_open(on: bool) -> void:
	if on == _open:
		return
	if on and _gift_first():
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if not on:
		_pending_slot = -1
		_hovered = ""
		_clear_found()
		if _search != null:
			_search.release_focus()


		_reset_pops()
	else:


		_apply_order()


		var searched:= _search != null and _search.text != ""
		if _search != null:
			_search.text = ""
		if _category == TAB_UNLOCKED or _category == TAB_HOTKEYED:
			_select_category(_category)
		elif searched:
			_refilter()

		_light_newest()
	_refresh_pins()
	_say_default()
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _gift_first() -> bool:
	if gift_card == null:
		return false
	if gift_card.is_holding():
		return true
	var id:= GameState.gift_card_due
	if id == "":
		return false
	GameState.gift_card_due = ""


	if GiftCard.went_down_in_one(id):
		return false
	if player != null:
		player.capture_mouse(false)
	gift_card.play(id, _back_to_yard)
	return true


func _back_to_yard() -> void:
	if player != null and not _open:
		player.capture_mouse(true)


func open_for_slot(slot: int) -> void:
	set_open(true)
	_pending_slot = slot
	_subtitle_message(tr("Pick something for slot %s") % _slot_key(slot))


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse"):
		set_open(false)
		get_viewport().set_input_as_handled()
		return


	var searching:= _search != null and _search.has_focus()
	if event.is_action_pressed("build_catalog") and not searching:
		set_open(false)
		get_viewport().set_input_as_handled()
		return
	var typed:= _is_typing(event)


	if typed and _search != null and not _search.has_focus() and not _is_hotbar_bind(event):
		_search.grab_focus()
		return


	if _hovered == "":
		return
	for n in Player.HOTBAR_KEYS:
		if not event.is_action_pressed("hotbar_%d" % (n + 1)):
			continue
		get_viewport().set_input_as_handled()
		var slot:= Player.favourite_for_key(n)
		if slot < 0:

			Audio.play("ui_error")
			return
		_assign(_hovered, slot)
		return


func _is_typing(event: InputEvent) -> bool:
	var key:= event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return false
	if key.keycode == KEY_BACKSPACE:
		return _search != null and _search.text != ""
	return key.unicode >= 32


func _is_hotbar_bind(event: InputEvent) -> bool:
	if _hovered == "":
		return false
	for n in Player.HOTBAR_KEYS:
		if event.is_action_pressed("hotbar_%d" % (n + 1)):
			return true
	return false


func _search_shows(id: String) -> bool:
	if _search == null:
		return true
	var q:= _search.text.strip_edges()
	if q == "":
		return true
	return BuildCatalog.display_name(id).findn(q) >= 0


func _on_search_changed(_text: String) -> void:


	_reset_pops()
	_refilter()
	_say_default()
	_scroll.scroll_vertical = 0


func _on_search_submitted(_text: String) -> void:
	for id: String in _ordered_ids():
		if _shows(id) and BuildCatalog.is_unlocked(id):
			_pick(id)
			return
	Audio.play("ui_error")


func _shows(id: String) -> bool:
	return _tab_shows(_category, id) and _search_shows(id)


func _build() -> void:
	var dim:= ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_card_box = _make_card_box(Color(1, 1, 1, 0.13), Color(0.06, 0.07, 0.09, 0.8))
	_card_hover = _make_card_box(COL_PIN, Color(0.1, 0.11, 0.09, 0.92))
	_card_locked = _make_card_box(Color(1, 1, 1, 0.06), Color(0.05, 0.05, 0.06, 0.55))


	_card_locked_hover = _make_card_box(Color(0.86, 0.72, 0.34, 0.66),
		Color(0.09, 0.09, 0.1, 0.88))


	_card_found = _make_card_box(Color(1.0, 0.86, 0.34), Color(0.16, 0.14, 0.06, 0.96))

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = - PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5
	_panel.offset_top = - PANEL_H * 0.5 - PANEL_LIFT
	_panel.offset_bottom = PANEL_H * 0.5 - PANEL_LIFT

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.62)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)


	var header:= HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 0)
	box.add_child(header)

	var lead:= HBoxContainer.new()
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lead.custom_minimum_size = Vector2(SORT_BUTTON + SORT_GAP + VIEW_BUTTON * 2.0, 0)
	header.add_child(lead)
	lead.add_child(_search_box())

	var title:= _label(tr("BUILD CATALOGUE"), 30, COL_TITLE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var views:= HBoxContainer.new()
	views.add_theme_constant_override("separation", 0)
	views.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(views)

	_sort_btn = Button.new()
	_sort_btn.text = tr(SORT_LABEL)
	_sort_btn.icon = SORT_ICON


	_sort_btn.tooltip_text = tr("Show recently built machines first.")
	_sort_btn.focus_mode = Control.FOCUS_NONE
	_sort_btn.custom_minimum_size = Vector2(SORT_BUTTON, VIEW_BUTTON)
	_sort_btn.add_theme_constant_override("icon_max_width", VIEW_ICON)
	_sort_btn.add_theme_constant_override("h_separation", 8)
	_sort_btn.add_theme_font_override("font", UiFont.bold())
	_sort_btn.add_theme_font_size_override("font_size", SORT_SIZE)


	_sort_btn.add_theme_stylebox_override("hover", _tab_box(Color(1, 1, 1, 0.09)))
	_sort_btn.add_theme_stylebox_override("pressed", _tab_box(Color(1, 1, 1, 0.14)))
	_sort_btn.add_theme_stylebox_override("focus", _tab_box(Color(1, 1, 1, 0.0)))
	_sort_btn.pressed.connect(_toggle_sort)
	views.add_child(_sort_btn)

	var gap:= Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(SORT_GAP, 0)
	views.add_child(gap)

	_view_list_btn = _view_button(false, VIEW_LIST_ICON,
		tr("List: machines with descriptions"))
	_view_grid_btn = _view_button(true, VIEW_GRID_ICON,
		tr("Icons: pictures only"))
	views.add_child(_view_list_btn)
	views.add_child(_view_grid_btn)

	_subtitle = HBoxContainer.new()
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.alignment = BoxContainer.ALIGNMENT_CENTER
	_subtitle.add_theme_constant_override("separation", PROMPT_GAP)
	box.add_child(_subtitle)
	box.add_child(_hrule())

	var split:= HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)

	var tabs:= VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.custom_minimum_size = Vector2(184, 0)
	split.add_child(tabs)
	tabs.add_child(_tab_button("", tr("Everything"), TAB_ALL_ICON))


	tabs.add_child(_tab_button(TAB_UNLOCKED, tr("Unlocked"), TAB_UNLOCKED_ICON))
	for cat: Dictionary in BuildCatalog.CATEGORIES:
		var cat_id:= str(cat ["id"])


		tabs.add_child(_tab_button(cat_id, BuildCatalog.category_name(cat_id),
			_icon_for(str(TAB_ICON_FOR.get(cat_id, "")))))


	tabs.add_child(_tab_button(TAB_HOTKEYED, tr("Hotkeyed"), TAB_HOTKEYED_ICON))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(_scroll)


	var bar:= _scroll.get_v_scroll_bar()


	bar.custom_minimum_size = Vector2(SCROLL_W, 0.0)
	bar.add_theme_stylebox_override("scroll", _bar_box(Color(1, 1, 1, 0.07)))
	bar.add_theme_stylebox_override("grabber", _bar_box(Color(1, 1, 1, 0.34)))
	bar.add_theme_stylebox_override("grabber_highlight",
		_bar_box(Color(1, 1, 1, 0.5)))
	bar.add_theme_stylebox_override("grabber_pressed", _bar_box(COL_PIN))


	var gutter:= MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_left", POP_GUTTER)
	gutter.add_theme_constant_override("margin_right", POP_GUTTER)
	gutter.add_theme_constant_override("margin_top", POP_GUTTER)
	gutter.add_theme_constant_override("margin_bottom", POP_GUTTER)
	_scroll.add_child(gutter)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	gutter.add_child(_list)
	for id: String in BuildCatalog.ordered_ids():
		var card:= _card(id)
		_cards [id] = card
		_list.add_child(card)


	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", TILE_GAP)
	_grid.add_theme_constant_override("v_separation", TILE_GAP)
	gutter.add_child(_grid)
	for id: String in BuildCatalog.ordered_ids():
		var tile:= _tile(id)
		_tiles [id] = tile
		_grid.add_child(tile)

	box.add_child(_hrule())
	_footer = _label("", 15, COL_DIM)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.max_lines_visible = 2
	_footer.custom_minimum_size = Vector2(0, _footer.get_line_height() * 2
		+ _footer.get_theme_constant("line_spacing"))
	box.add_child(_footer)
	_grid_view = Cfg.catalog_grid
	_sort_recent = Cfg.catalog_recent_first
	_paint_sort_button()
	_apply_order()
	_apply_view()
	_select_category("")
	_say_default()


func _search_box() -> PanelContainer:
	var strip:= PanelContainer.new()
	strip.custom_minimum_size = Vector2(SEARCH_W, VIEW_BUTTON)
	strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb:= _tab_box(Color(1, 1, 1, 0.06))
	sb.border_color = Color(1, 1, 1, 0.13)
	sb.set_border_width_all(1)
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	strip.add_theme_stylebox_override("panel", sb)

	var row:= HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	strip.add_child(row)

	var glass:= TextureRect.new()
	glass.texture = SEARCH_ICON
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glass.custom_minimum_size = Vector2(VIEW_ICON, VIEW_ICON)
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glass.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glass.modulate = COL_DIM
	row.add_child(glass)

	_search = LineEdit.new()
	_search.placeholder_text = tr("Search")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.clear_button_enabled = true
	_search.context_menu_enabled = false
	_search.add_theme_font_override("font", UiFont.bold())
	_search.add_theme_font_size_override("font_size", SORT_SIZE + 1)
	_search.add_theme_color_override("font_color", COL_TITLE)
	_search.add_theme_color_override("font_placeholder_color", Color(COL_DIM, 0.7))
	_search.add_theme_color_override("caret_color", COL_TITLE)
	for state: String in ["normal", "focus", "read_only"]:
		_search.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_search.text_changed.connect(_on_search_changed)
	_search.text_submitted.connect(_on_search_submitted)


	_search.focus_entered.connect(_say_default)
	_search.focus_exited.connect(_say_default)
	row.add_child(_search)
	return strip


func _make_card_box(border: Color, bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(0)
	b.content_margin_left = 14.0
	b.content_margin_right = 14.0
	b.content_margin_top = 9.0
	b.content_margin_bottom = 9.0
	return b


func _bar_box(bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(0)
	return b


func _tab_box(bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(0)
	b.content_margin_left = 12.0
	b.content_margin_right = 12.0
	b.content_margin_top = 6.0
	b.content_margin_bottom = 6.0
	return b


func _tab_button(id: String, text: String, icon: Texture2D) -> Button:
	var b:= Button.new()
	b.text = text
	b.icon = icon
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE


	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_constant_override("icon_max_width", TAB_ICON)
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 17)


	b.add_theme_stylebox_override("normal", _tab_box(Color(1, 1, 1, 0.0)))
	b.add_theme_stylebox_override("hover", _tab_box(Color(1, 1, 1, 0.09)))
	b.add_theme_stylebox_override("pressed", _tab_box(Color(1, 1, 1, 0.14)))
	b.add_theme_stylebox_override("focus", _tab_box(Color(1, 1, 1, 0.0)))
	b.pressed.connect(_select_category.bind(id))
	_cat_buttons [id] = b
	return b


func _view_button(grid: bool, icon: Texture2D, tip: String) -> Button:
	var b:= Button.new()
	b.icon = icon
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(VIEW_BUTTON, VIEW_BUTTON)
	b.add_theme_constant_override("icon_max_width", VIEW_ICON)
	b.add_theme_stylebox_override("normal", _tab_box(Color(1, 1, 1, 0.0)))
	b.add_theme_stylebox_override("hover", _tab_box(Color(1, 1, 1, 0.09)))
	b.add_theme_stylebox_override("pressed", _tab_box(Color(1, 1, 1, 0.14)))
	b.add_theme_stylebox_override("focus", _tab_box(Color(1, 1, 1, 0.0)))
	b.pressed.connect(_set_view.bind(grid))
	return b


func _card(id: String) -> PanelContainer:
	var card:= PanelContainer.new()
	card.name = id
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(0, CARD_H)
	card.add_theme_stylebox_override("panel", _card_box)
	card.gui_input.connect(_on_card_input.bind(id))
	card.mouse_entered.connect(_on_card_hover.bind(id, true))
	card.mouse_exited.connect(_on_card_hover.bind(id, false))

	var row:= HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_build_icon(id))

	var text_box:= VBoxContainer.new()
	text_box.name = "Text"
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	text_box.add_child(_name_line(id))
	var blurb:= _label(BuildCatalog.blurb(id), 14, COL_DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(blurb)
	row.add_child(text_box)

	var sizes:= _size_switch(id)
	if sizes != null:
		sizes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sizes)

	var cost:= _label(BuildCatalog.cost_text(id), 16, COL_TITLE, true)
	cost.name = "Cost"
	cost.custom_minimum_size = Vector2(190, 0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost)


	var pin:= _label("", PIN_SIZE, COL_PIN, true)
	pin.name = "Pin"
	pin.custom_minimum_size = Vector2(86, 0)
	pin.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pin)
	return card


func _tile(id: String) -> PanelContainer:
	var tile:= PanelContainer.new()
	tile.name = id
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.custom_minimum_size = Vector2(0, TILE_H)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _card_box)
	tile.tooltip_text = "%s\n%s\n\n%s" % [BuildCatalog.display_name(id),
		BuildCatalog.cost_text(id), _wrap(BuildCatalog.blurb(id), TIP_WRAP)]
	tile.gui_input.connect(_on_card_input.bind(id))
	tile.mouse_entered.connect(_on_card_hover.bind(id, true))
	tile.mouse_exited.connect(_on_card_hover.bind(id, false))

	var col:= VBoxContainer.new()
	col.name = "Body"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 5)
	tile.add_child(col)
	col.add_child(_tile_art(id))


	var name_l:= _label(BuildCatalog.display_name(id), 14, COL_TEXT, true)
	name_l.name = "Name"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)


	var cost:= _label(BuildCatalog.cost_text(id), 13, COL_TITLE, true)
	cost.name = "Cost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.clip_text = true
	cost.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(cost)
	return tile


func _tile_art(id: String) -> Control:
	var art:= Control.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(0, TILE_ICON)


	art.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var icon:= _build_icon(id)
	icon.custom_minimum_size = Vector2.ZERO
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(icon)


	var lock:= TextureRect.new()
	lock.name = "Lock"
	lock.texture = LOCK_ICON
	lock.modulate = COL_LOCKED
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lock.offset_left = - TILE_LOCK
	lock.offset_top = 0.0
	lock.offset_right = 0.0
	lock.offset_bottom = TILE_LOCK
	lock.visible = false
	art.add_child(lock)


	var pin:= _label("", TILE_BADGE, COL_PIN, true)
	pin.name = "Pin"
	pin.add_theme_stylebox_override("normal", _badge_box())
	pin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pin.visible = false
	art.add_child(pin)


	var sizes:= _size_switch(id)
	if sizes != null:
		sizes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		sizes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		art.add_child(sizes)

	var fresh:= _new_tag()
	fresh.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fresh.grow_vertical = Control.GROW_DIRECTION_BEGIN
	art.add_child(fresh)
	return art


func _size_switch(id: String) -> HBoxContainer:
	if id != "t_splitter":
		return null
	var box:= HBoxContainer.new()
	box.name = "Size"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var group:= ButtonGroup.new()
	for r: float in Cfg.T_SPLITTER_SIZES:
		var b:= Button.new()
		b.name = "R%d" % roundi(r * 100.0)
		b.text = tr("1 m") if is_equal_approx(r, Cfg.T_SPLITTER_PORT_R_1M) else tr("1.5 m")
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tr("How long the arms are on the next T junction you place")
		b.add_theme_font_size_override("font_size", TILE_BADGE)
		b.add_theme_color_override("font_color", COL_DIM)
		b.add_theme_color_override("font_hover_color", COL_TEXT)
		b.add_theme_color_override("font_pressed_color", COL_TITLE)
		b.add_theme_color_override("font_hover_pressed_color", COL_TITLE)
		var plain:= _badge_box()
		var lit:= _badge_box()
		lit.bg_color = Color(0.2, 0.16, 0.05, 0.92)
		lit.border_color = COL_PIN
		lit.set_border_width_all(1)
		var hover:= _badge_box()
		hover.bg_color = Color(0.12, 0.13, 0.16, 0.92)
		b.add_theme_stylebox_override("normal", plain)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", lit)
		b.add_theme_stylebox_override("hover_pressed", lit)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.button_pressed = is_equal_approx(r, Cfg.t_splitter_port_r)
		b.pressed.connect(Cfg.set_t_splitter_port_r.bind(r))
		box.add_child(b)
	return box


func _paint_sizes() -> void:
	for node: Control in [_cards.get("t_splitter"), _tiles.get("t_splitter")]:
		if node == null:
			continue
		var box:= node.find_child("Size", true, false) as HBoxContainer
		if box == null:
			continue
		for b: Button in box.get_children():
			b.set_pressed_no_signal(b.name == "R%d" % roundi(Cfg.t_splitter_port_r * 100.0))


func _badge_box() -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = Color(0.04, 0.05, 0.07, 0.86)
	b.set_corner_radius_all(0)
	b.content_margin_left = 5.0
	b.content_margin_right = 5.0
	b.content_margin_top = 1.0
	b.content_margin_bottom = 1.0
	return b


func _wrap(text: String, width: int) -> String:


	if UiFont.unspaced(text):
		return UiFont.wrap_unspaced(text, width)
	var out:= ""
	var line:= ""
	for word: String in text.split(" ", false):
		if line == "":
			line = word
		elif line.length() + 1 + word.length() <= width:
			line += " " + word
		else:
			out += line + "\n"
			line = word
	return out + line


static func icon_for(id: String) -> AtlasTexture:
	return _icon_for(id)


static func _icon_for(id: String) -> AtlasTexture:
	if not BUILD_ICON_TILES.has(id):
		return null
	if _icon_cache.has(id):
		return _icon_cache [id]
	var tile: Vector2i = BUILD_ICON_TILES [id]


	var step:= Vector2(BUILD_ICON_SHEET.get_width(),
		BUILD_ICON_SHEET.get_height()) / float(BUILD_ICON_GRID)
	var atlas:= AtlasTexture.new()
	atlas.atlas = BUILD_ICON_SHEET
	atlas.region = Rect2(Vector2(tile) * step, step)
	_icon_cache [id] = atlas
	return atlas


func _name_line(id: String) -> HBoxContainer:
	var row:= HBoxContainer.new()
	row.name = "NameLine"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	row.add_child(_label(BuildCatalog.display_name(id), 20, COL_TEXT, true))

	var lock:= TextureRect.new()
	lock.name = "Lock"
	lock.texture = LOCK_ICON
	lock.modulate = COL_LOCKED
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.custom_minimum_size = Vector2(NAME_LOCK, NAME_LOCK)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.visible = false
	row.add_child(lock)
	row.add_child(_new_tag())
	return row


func _new_tag() -> Label:
	var tag:= _label(tr("NEW", "key hint"), 13, ControlHints.COL_NEW, true)
	tag.name = "New"
	tag.add_theme_stylebox_override("normal", _badge_box())
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.visible = false
	return tag


func _build_icon(id: String) -> TextureRect:
	var icon:= TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(CARD_ICON, CARD_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER


	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.texture = _icon_for(id)
	icon.visible = icon.texture != null


	icon.modulate = ICON_LIT
	return icon


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 0, heavy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	return l


func _hrule() -> Control:
	var r:= ColorRect.new()
	r.color = Color(1, 1, 1, 0.12)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _set_view(grid: bool) -> void:
	if grid == _grid_view:
		return
	_grid_view = grid
	Cfg.set_catalog_grid(grid)
	Audio.play("ui_hotbar", -6.0)
	_hovered = ""
	_apply_view()
	_say_default()


	if _found != "":
		_light(_found)


func _apply_view() -> void:
	_reset_pops()
	_list.visible = not _grid_view
	_grid.visible = _grid_view
	for pair: Array in [[_view_list_btn, not _grid_view], [_view_grid_btn, _grid_view]]:
		var b: Button = pair [0]
		var on: bool = pair [1]
		b.add_theme_stylebox_override("normal",
			_tab_box(Color(1, 1, 1, 0.14 if on else 0.0)))
		var tint: Color = COL_TITLE if on else COL_DIM
		for state: String in ["icon_normal_color", "icon_hover_color",
				"icon_pressed_color"]:
			b.add_theme_color_override(state, tint)
	for id: String in _cards:
		_paint(id)


func _toggle_sort() -> void:
	_sort_recent = not _sort_recent
	Cfg.set_catalog_recent_first(_sort_recent)
	Audio.play("ui_hotbar", -6.0)
	_hovered = ""
	_paint_sort_button()
	_reset_pops()
	_apply_order()


	if _found != "":
		_light(_found)
	_say_default()


func _paint_sort_button() -> void:
	if _sort_btn == null:
		return
	_sort_btn.add_theme_stylebox_override("normal",
		_tab_box(Color(1, 1, 1, 0.14 if _sort_recent else 0.0)))
	var tint: Color = COL_TITLE if _sort_recent else COL_DIM
	_sort_btn.add_theme_color_override("font_color", tint)
	_sort_btn.add_theme_color_override("font_hover_color", tint)
	_sort_btn.add_theme_color_override("font_pressed_color", tint)
	for state: String in ["icon_normal_color", "icon_hover_color",
			"icon_pressed_color"]:
		_sort_btn.add_theme_color_override(state, tint)


func _ordered_ids() -> Array:
	var rest:= BuildCatalog.ordered_ids()
	var out:= []
	for id: String in rest:
		if _is_new(id) and BuildCatalog.has_gift(id):
			out.append(id)
	for id: String in GameState.fresh_builds:
		if _is_new(id) and not out.has(id):
			out.append(id)
	if _sort_recent:
		for id: String in GameState.recent_builds:
			if _cards.has(id) and not out.has(id):
				out.append(id)
	for id: String in rest:
		if BuildCatalog.is_unlocked(id) and not out.has(id):
			out.append(id)
	for id: String in rest:
		if not out.has(id):
			out.append(id)
	return out


func _is_new(id: String) -> bool:
	if not _cards.has(id) or not BuildCatalog.is_unlocked(id):
		return false
	return BuildCatalog.has_gift(id) or GameState.fresh_builds.has(id)


func _light_newest() -> void:
	for id: String in _ordered_ids():
		if not _is_new(id):
			return
		if _announced.has(id):
			continue
		_announced [id] = true
		if not _shows(id):
			_select_category("")
		_light(id)
		return


func _apply_order() -> void:
	var at:= 0
	for id: String in _ordered_ids():
		var card:= _cards.get(id) as Control
		var tile:= _tiles.get(id) as Control
		if card == null or tile == null:
			continue
		_list.move_child(card, at)
		_grid.move_child(tile, at)
		at += 1


func _node_for(id: String) -> Control:
	var set_of: Dictionary = _tiles if _grid_view else _cards
	return set_of.get(id) as Control


func _select_category(id: String) -> void:
	_category = id


	_hovered = ""
	for key: String in _cat_buttons:
		var b: Button = _cat_buttons [key]
		b.add_theme_color_override("font_color", COL_TITLE if key == id else COL_DIM)


		var tint:= ICON_LIT if key == id else Color(1.0, 1.0, 1.0)
		for state: String in ["icon_normal_color", "icon_hover_color",
				"icon_pressed_color"]:
			b.add_theme_color_override(state, tint)


	_reset_pops()
	_refilter()


	_say_default()


func _refilter() -> void:
	for card_id: String in _cards:
		var shows:= _shows(card_id)
		var card:= _cards [card_id] as Control
		var tile:= _tiles [card_id] as Control


		if not shows and (card.visible or tile.visible):
			if _hovered == card_id:
				_hovered = ""
			_pop(card_id, 1.0, 0.0)
		card.visible = shows
		tile.visible = shows
		_paint(card_id)


func _tab_shows(tab: String, id: String) -> bool:
	if tab == "":
		return true
	if tab == TAB_UNLOCKED:
		return BuildCatalog.is_unlocked(id)
	if tab == TAB_HOTKEYED:


		return GameState.hotbar_index_of(id) >= 0 and BuildCatalog.is_unlocked(id)
	return BuildCatalog.category_of(id) == tab


func _on_card_hover(id: String, entered: bool) -> void:
	if entered:
		_hovered = id
	elif _hovered == id:
		_hovered = ""
	_paint(id)
	_pop(id, _hover_scale() if entered else 1.0, POP_TIME)
	if entered and BuildCatalog.is_unlocked(id):


		_say(tr("%s   ·   LMB equip   ·   RMB pin   ·   a number key binds it to that box")
			% BuildCatalog.display_name(id))
	elif entered:


		var node:= BuildCatalog.unlock_of(id)
		if TechTree.has_id(node):
			_say(tr("%s is unlocked by %s. Click to open it in the tech tree.")
				% [BuildCatalog.display_name(id), TechTree.display_name(node)])
		else:
			_say_default()
	else:
		_say_default()


func _on_card_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb:= event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_press(id)
		_pick(id)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_press(id)
		_toggle_pin(id)
	else:
		return
	accept_event()


func _press(id: String) -> void:
	var card:= _node_for(id)
	if card == null:
		return
	_pop(id, TILE_PRESS if _grid_view else CARD_PRESS, PRESS_TIME)
	var t: Tween = _pop_tweens.get(id)
	if t != null and t.is_valid():
		t.tween_property(card, "scale",
			Vector2.ONE * (_hover_scale() if _hovered == id else 1.0), POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hover_scale() -> float:
	return TILE_POP if _grid_view else CARD_POP


func _pop(id: String, to: float, time: float) -> void:
	var card:= _node_for(id)
	if card == null:
		return
	var old: Tween = _pop_tweens.get(id)
	if old != null and old.is_valid():
		old.kill()


	card.pivot_offset = card.size * 0.5
	if time <= 0.0 or not is_inside_tree():
		card.scale = Vector2.ONE * to
		_pop_tweens.erase(id)
		return
	var t:= create_tween()

	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(card, "scale", Vector2.ONE * to, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tweens [id] = t


func _reset_pops() -> void:
	for t: Tween in _pop_tweens.values():
		if t != null and t.is_valid():
			t.kill()
	_pop_tweens.clear()
	for set_of: Dictionary in [_cards, _tiles]:
		for id: String in set_of:
			(set_of [id] as Control).scale = Vector2.ONE


func _pick(id: String) -> void:
	if not BuildCatalog.is_unlocked(id):
		_show_on_tree(id)
		return
	if _pending_slot >= 0:
		GameState.set_hotbar_slot(_pending_slot, id)
	if player != null:
		player.equip_build(id)
	set_open(false)


func _show_on_tree(id: String) -> void:
	var node:= BuildCatalog.unlock_of(id)
	var tree: TechPanel = player.tech_panel if player != null else null
	if node == "" or tree == null or not TechTree.has_id(node):

		Audio.play("build_denied")
		return
	set_open(false)
	tree.show_node(node)


func show_entry(id: String) -> void:
	if not _cards.has(id):
		return
	set_open(true)


	_select_category("")
	_light(id)


func _light(id: String) -> void:
	var card:= _node_for(id)
	if card == null:
		return
	_clear_found()
	_found = id
	_paint(id)


	await get_tree().process_frame


	if _found != id or not _open or not is_inside_tree() or not is_instance_valid(card) or not is_instance_valid(_scroll):
		return
	_scroll.ensure_control_visible(card)
	_found_tween = create_tween()
	_found_tween.set_loops(3)


	_found_tween.tween_property(card, "modulate", Color(1.45, 1.4, 1.15), 0.22)
	_found_tween.tween_property(card, "modulate", Color.WHITE, 0.3)
	await _found_tween.finished
	if _found == id:
		_clear_found()


func _clear_found() -> void:
	if _found_tween != null and _found_tween.is_valid():
		_found_tween.kill()
	_found_tween = null
	var was:= _found
	_found = ""
	if was == "":
		return


	for set_of: Dictionary in [_cards, _tiles]:
		var card:= set_of.get(was) as Control
		if card != null:
			card.modulate = Color.WHITE
	_paint(was)


func _toggle_pin(id: String) -> void:
	if not BuildCatalog.is_unlocked(id):
		Audio.play("build_denied")
		return


	var was_pinned:= GameState.hotbar_index_of(id) >= 0
	var slot:= GameState.toggle_hotbar(id)
	if slot >= 0:
		Audio.play("ui_hotbar", -3.0)
		_say(tr("%s pinned to key %s") % [BuildCatalog.display_name(id), _slot_key(slot)])
		return
	if was_pinned:
		Audio.play("ui_hotbar", -3.0)
		_say(tr("%s unpinned") % BuildCatalog.display_name(id))
		return
	Audio.play("ui_error")
	if GameState.carried_tool_count() > 0:

		_say(tr("Every slot is taken. Put a tool down to make room, or hover a card and press the key of the box you want it to replace"))
	else:
		_say(tr("Every slot is taken. Hover a card and press the key of the box you want it to replace"))


func _assign(id: String, slot: int) -> void:
	if not BuildCatalog.is_unlocked(id):
		Audio.play("build_denied")
		return
	GameState.set_hotbar_slot(slot, id)
	Audio.play("ui_hotbar", -3.0)
	_say(tr("%s on key %s") % [BuildCatalog.display_name(id), _slot_key(slot)])


func _refresh_pins() -> void:
	if _category == TAB_HOTKEYED:
		_refilter()
		return
	for id: String in _cards:
		_paint(id)


func _paint(id: String) -> void:
	var unlocked:= BuildCatalog.is_unlocked(id)
	var slot:= GameState.hotbar_index_of(id)
	var box:= _card_box
	if _found == id:


		box = _card_found
	elif not unlocked:
		box = _card_locked_hover if _hovered == id else _card_locked
	else:
		box = _card_hover if _hovered == id else _card_box


	var gift:= unlocked and BuildCatalog.has_gift(id)
	if gift and _found != id:
		box = _card_found
	_paint_cost(id, gift)
	_paint_tile(id, unlocked, slot, box)
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	card.add_theme_stylebox_override("panel", box)
	var icon: TextureRect = card.get_node_or_null("Row/Icon")
	if icon != null:
		icon.modulate = ICON_LIT if unlocked else ICON_DIM
	var fresh: Label = card.get_node_or_null("Row/Text/NameLine/New")
	if fresh != null:
		fresh.visible = unlocked and Cfg.build_is_new(id)
	var sizes: Control = card.get_node_or_null("Row/Size")
	if sizes != null:
		sizes.visible = unlocked
	var lock: TextureRect = card.get_node_or_null("Row/Text/NameLine/Lock")
	if lock != null:
		lock.visible = not unlocked


		lock.modulate = COL_LINK_HOVER if _hovered == id else COL_LOCKED
	var pin: Label = card.get_node_or_null("Row/Pin")
	if pin == null:
		return
	if not unlocked:


		var to_tree:= TechTree.has_id(BuildCatalog.unlock_of(id))
		pin.text = tr("Tech Tree >") if to_tree else tr("LOCKED")


		pin.add_theme_font_size_override("font_size", PIN_LINK_SIZE if to_tree else PIN_SIZE)
		pin.add_theme_color_override("font_color",
			COL_LINK_HOVER if to_tree and _hovered == id else COL_LOCKED)
	elif slot >= 0 and GameState.hotbar_slot_parked(slot):


		pin.text = tr("BAR FULL")
		pin.add_theme_font_size_override("font_size", PIN_SIZE)
		pin.add_theme_color_override("font_color", COL_LOCKED)
	elif slot >= 0:
		pin.text = tr("KEY %s") % _slot_key(slot)
		pin.add_theme_font_size_override("font_size", PIN_SIZE)
		pin.add_theme_color_override("font_color", COL_PIN)
	else:
		pin.text = ""


func _paint_cost(id: String, gift: bool) -> void:
	var labels: Array [Label] = []
	var card: PanelContainer = _cards.get(id)
	if card != null:
		var l: Label = card.get_node_or_null("Row/Cost")
		if l != null:
			labels.append(l)
	var tile: PanelContainer = _tiles.get(id)
	if tile != null:
		var t: Label = tile.get_node_or_null("Body/Cost")
		if t != null:
			labels.append(t)
	for l: Label in labels:
		l.text = BuildCatalog.cost_text(id)
		l.add_theme_color_override("font_color", COL_GIFT if gift else COL_TITLE)


const COL_GIFT:= Color(1.0, 0.95, 0.62)


func _paint_tile(id: String, unlocked: bool, slot: int, box: StyleBoxFlat) -> void:
	var tile: PanelContainer = _tiles.get(id)
	if tile == null:
		return
	tile.add_theme_stylebox_override("panel", box)
	var icon: TextureRect = tile.get_node_or_null("Body/Art/Icon")
	if icon != null:
		icon.modulate = ICON_LIT if unlocked else ICON_DIM
	var fresh: Label = tile.get_node_or_null("Body/Art/New")
	if fresh != null:
		fresh.visible = unlocked and Cfg.build_is_new(id)
	var sizes: Control = tile.get_node_or_null("Body/Art/Size")
	if sizes != null:
		sizes.visible = unlocked
	var lock: TextureRect = tile.get_node_or_null("Body/Art/Lock")
	if lock != null:
		lock.visible = not unlocked
		lock.modulate = COL_LINK_HOVER if _hovered == id else COL_LOCKED
	var pin: Label = tile.get_node_or_null("Body/Art/Pin")
	if pin != null:
		pin.visible = unlocked and slot >= 0
		if pin.visible:
			pin.text = tr("BAR FULL") if GameState.hotbar_slot_parked(slot) else tr("KEY %s") % _slot_key(slot)


	var name_l: Label = tile.get_node_or_null("Body/Name")
	if name_l != null:
		name_l.add_theme_color_override("font_color",
			COL_TEXT if unlocked else COL_LOCKED)
	var cost: Label = tile.get_node_or_null("Body/Cost")
	if cost != null:
		cost.add_theme_color_override("font_color",
			COL_TITLE if unlocked else COL_LOCKED)


func _say(text: String) -> void:
	if _footer != null:
		_footer.text = text


func _say_default() -> void:
	if _subtitle != null and _pending_slot < 0:
		_subtitle_prompts()


	if _shown_count() == 0:
		if _search != null and _search.text.strip_edges() != "":
			_say(tr("Nothing here has that name."))
			return
		if _category == TAB_HOTKEYED:
			_say(tr("Nothing is on your bar yet. Right click anything in the catalogue to put it on a key."))
			return
		if _category == TAB_UNLOCKED:
			_say(tr("You have not unlocked anything to build yet."))
			return

	if _search != null and _search.has_focus():
		_say(tr("Esc to close"))
	else:
		_say(tr("B to close"))


func _shown_count() -> int:
	var n:= 0
	for id: String in _cards:
		if _shows(id):
			n += 1
	return n


func _subtitle_prompts() -> void:
	_clear_subtitle()
	_subtitle.add_child(_mouse_prompt("mouse_left", tr("Equip")))
	_subtitle.add_child(_mouse_prompt("mouse_right", tr("Add to hotkey bar")))
	_subtitle.add_child(_lock_prompt(tr("Locked: click to show tree")))


func _subtitle_message(text: String) -> void:
	_clear_subtitle()
	_subtitle.add_child(_label(text, SUBTITLE_SIZE, COL_DIM))


func _clear_subtitle() -> void:


	for c: Node in _subtitle.get_children():
		_subtitle.remove_child(c)
		c.queue_free()


func _mouse_prompt(sprite: String, what: String) -> HBoxContainer:
	var row:= HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	var art:= InputIcons.named(sprite)
	if art == null:


		var says:= tr("Left click %s") if sprite == "mouse_left" else tr("Right click %s")
		row.add_child(_label(says % what, SUBTITLE_SIZE, COL_DIM))
		return row

	var pic:= TextureRect.new()
	pic.texture = art
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE


	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(PROMPT_ICON, PROMPT_ICON)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)

	var l:= _label(what, SUBTITLE_SIZE, COL_DIM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _lock_prompt(what: String) -> HBoxContainer:
	var row:= HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)

	var pic:= TextureRect.new()
	pic.texture = LOCK_ICON
	pic.modulate = COL_LOCKED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


	pic.custom_minimum_size = Vector2(PROMPT_ICON * 0.72, PROMPT_ICON * 0.72)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)

	var l:= _label(what, SUBTITLE_SIZE, COL_LOCKED)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _slot_key(slot: int) -> String:
	return Player.favourite_key_label(slot)
