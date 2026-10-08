class_name HotkeyBar
extends HBoxContainer


const SLOT:= 64.0


const TAB_H:= 17.0
const KEY_SIZE:= 12
const NAME_SIZE:= 12
const COL_TEXT:= Color(0.95, 0.96, 0.9)
const COL_DIM:= Color(0.82, 0.85, 0.78)
const COL_SELECTED:= Color(0.86, 0.72, 0.34, 0.96)

const COL_ON_TAB:= Color(0.1, 0.09, 0.06)

const COL_OFF:= Color(0.46, 0.48, 0.52)


const TOOL_LABELS:= ["Hand", "Spade", "Pitchfork", "Broom", "Toy Shovel",
	"Detector", "Yard Vac", "Lighter"]


const TOOL_TILES:= ["hands", "spade", "pitchfork", "broom", "toy_shovel",
	"metal_detector", "yard_vac", "lighter"]


const TRIM_ALPHA:= 0.35


const TRIM_SAMPLE:= 128


const TRIM_PAD:= 1


const TRIM_BREATH:= 1.1


static var _trim_cache: Dictionary = { }


static var _sheet_images: Dictionary = { }

var player: Player
var catalog: CatalogPanel

var _buttons: Array [Button] = []


var _tabs: Array [PanelContainer] = []
var _tab_labels: Array [Label] = []


var _columns: Array [VBoxContainer] = []
var _drop_button: Button
var _catalog_button: Button


var _selected:= ""


var _hovered:= -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)


	offset_top = - (72.0 + TAB_H + SLOT)
	offset_bottom = -72
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)


	for i in Player.slot_count():
		var column:= _slot_column(i)
		_columns.append(column)
		add_child(column)


	_catalog_button = _word_slot(tr("BUILD"), _on_catalog_pressed)
	add_child(_catalog_button.get_parent())
	_drop_button = _word_slot(tr("DROP"), _on_drop_pressed)
	add_child(_drop_button.get_parent())

	GameState.hotbar_changed.connect(_relabel)


	GameState.tools_changed.connect(_relabel)


	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_relabel)


	InputSetup.changed.connect(_relabel)
	_relabel()


func _process(_delta: float) -> void:
	if player == null:
		return


	var covered:= player.shop != null and player.shop.is_open()
	modulate.a = 0.0 if covered else 1.0
	var now:= _selection_key()
	if now == _selected:
		return
	_selected = now
	for i in _buttons.size():
		_paint(i)


func _selection_key() -> String:
	if player.current_tool == Player.Tool.BUILD:
		return "build:%s" % player.build_id
	return "tool:%d" % int(player.current_tool)


func _key_for_slot(i: int) -> String:
	if i < Player.TOOL_SLOTS.size():
		return "tool:%d" % int(Player.TOOL_SLOTS [i])
	var id:= GameState.hotbar_slot(i - Player.TOOL_SLOTS.size())
	return "" if id == "" else "build:%s" % id


static func _key_label(n: int) -> String:
	return Player.key_label(n)


func _icon_for_slot(i: int) -> Texture2D:
	if i < Player.TOOL_SLOTS.size():
		if i >= TOOL_TILES.size():
			return null
		var tile: String = TOOL_TILES [i]
		return _filled(TechPanel.icon_for(tile), "tool:" + tile)
	var id:= GameState.hotbar_slot(i - Player.TOOL_SLOTS.size())
	return null if id == "" else _filled(CatalogPanel.icon_for(id), "build:" + id)


static func _filled(tex: Texture2D, key: String) -> Texture2D:
	if tex == null:
		return null
	if _trim_cache.has(key):
		return _trim_cache [key]
	var out:= tex
	var atlas:= tex as AtlasTexture
	if atlas != null and atlas.atlas != null:
		var cell:= Rect2i(atlas.region)
		var sheet:= _sheet_image(atlas.atlas)
		if sheet != null and sheet.get_width() > 0:
			var box:= _square_on(_subject_rect(sheet.get_region(cell)), cell.size)
			if box.size.x > 0.0 and box.size.y > 0.0:
				var trimmed:= AtlasTexture.new()
				trimmed.atlas = atlas.atlas
				trimmed.region = Rect2(Vector2(cell.position) + box.position, box.size)
				out = trimmed
	_trim_cache [key] = out
	return out


static func _square_on(box: Rect2, cell: Vector2i) -> Rect2:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return box
	var side:= minf(maxf(box.size.x, box.size.y) * TRIM_BREATH,
		minf(float(cell.x), float(cell.y)))
	var mid:= box.get_center()
	var pos:= mid - Vector2.ONE * (side * 0.5)
	pos.x = clampf(pos.x, 0.0, float(cell.x) - side)
	pos.y = clampf(pos.y, 0.0, float(cell.y) - side)
	return Rect2(pos, Vector2.ONE * side)


static func _subject_rect(cell: Image) -> Rect2:
	var w:= cell.get_width()
	var h:= cell.get_height()
	if w <= 0 or h <= 0:
		return Rect2()
	var small:= cell.duplicate() as Image


	small.clear_mipmaps()
	small.resize(TRIM_SAMPLE, TRIM_SAMPLE, Image.INTERPOLATE_BILINEAR)
	var lo:= Vector2i(TRIM_SAMPLE, TRIM_SAMPLE)
	var hi:= Vector2i(-1, -1)
	for y in TRIM_SAMPLE:
		for x in TRIM_SAMPLE:
			if small.get_pixel(x, y).a < TRIM_ALPHA:
				continue
			lo.x = mini(lo.x, x)
			lo.y = mini(lo.y, y)
			hi.x = maxi(hi.x, x)
			hi.y = maxi(hi.y, y)
	if hi.x < lo.x:
		return Rect2()
	var step:= Vector2(w, h) / float(TRIM_SAMPLE)


	var pos:= (Vector2(lo) - Vector2.ONE * TRIM_PAD) * step
	var far:= (Vector2(hi) + Vector2.ONE * (1 + TRIM_PAD)) * step
	pos = Vector2(maxf(pos.x, 0.0), maxf(pos.y, 0.0))
	far = Vector2(minf(far.x, float(w)), minf(far.y, float(h)))
	return Rect2(pos, far - pos)


static func _sheet_image(sheet: Texture2D) -> Image:
	if _sheet_images.has(sheet):
		return _sheet_images [sheet]
	var img:= sheet.get_image()
	_sheet_images [sheet] = img
	return img


func _on_tech_changed(_id: String, _rank: int) -> void:
	_relabel()


func _relabel() -> void:


	var key:= 0
	for i in _buttons.size():

		var shown:= Player.slot_is_shown(i)
		_columns [i].visible = shown
		if not shown:
			continue
		_tab_labels [i].text = _key_label(key)
		key += 1
		_buttons [i].icon = _icon_for_slot(i)
		if i < TOOL_LABELS.size():


			_buttons [i].tooltip_text = tr(TOOL_LABELS [i])
			continue
		var id:= GameState.hotbar_slot(i - Player.TOOL_SLOTS.size())
		_buttons [i].tooltip_text = BuildCatalog.display_name(id)
	_tab_labels [_buttons.size()].text = InputSetup.hint("build_catalog")
	_tab_labels [_buttons.size() + 1].text = InputSetup.hint("drop_tool")


	_sheet_images.clear()

	_selected = ""


func _slot_column(index: int) -> VBoxContainer:
	var column:= _column()
	var button:= _square()
	button.pressed.connect(_on_slot_pressed.bind(index))
	button.mouse_entered.connect(_on_slot_hover.bind(index))
	button.mouse_exited.connect(_on_slot_hover.bind(-1))
	_buttons.append(button)
	column.add_child(button)
	_paint_at(_buttons.size() - 1, false, false)
	return column


func _word_slot(text: String, action: Callable) -> Button:
	var column:= _column()
	var button:= _square()
	button.text = text
	button.pressed.connect(action)
	column.add_child(button)

	button.add_theme_stylebox_override("normal", _box(false))
	button.add_theme_stylebox_override("hover", _box(false, true))
	return button


func _column() -> VBoxContainer:
	var column:= VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)

	column.size_flags_vertical = Control.SIZE_SHRINK_END

	var tab:= PanelContainer.new()
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.custom_minimum_size = Vector2(SLOT, TAB_H)
	tab.add_theme_stylebox_override("panel", _tab_box(false, false))

	var key:= Label.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.style(key, KEY_SIZE, COL_DIM, 0, true)
	tab.add_child(key)
	column.add_child(tab)

	_tabs.append(tab)
	_tab_labels.append(key)
	return column


func _square() -> Button:
	var b:= Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER


	b.expand_icon = true


	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", NAME_SIZE)
	b.add_theme_color_override("font_color", COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", COL_TEXT)
	return b


func _on_slot_hover(index: int) -> void:
	var was:= _hovered
	_hovered = index
	if was >= 0 and was < _buttons.size():
		_paint(was)
	if index >= 0:
		_paint(index)


func _paint(i: int) -> void:
	_paint_at(i, _key_for_slot(i) == _selected, i == _hovered)


func _paint_at(i: int, on: bool, hover: bool) -> void:
	_buttons [i].add_theme_stylebox_override("normal", _box(on))
	_buttons [i].add_theme_stylebox_override("hover", _box(on, true))
	_tabs [i].add_theme_stylebox_override("panel", _tab_box(on, hover))
	_tab_labels [i].add_theme_color_override("font_color", COL_ON_TAB if on else COL_DIM)


func _box(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var box:= StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.045, 0.042, 0.88 if selected else 0.68)
	box.border_color = COL_SELECTED if selected else Color(1, 1, 1, 0.2 if not hover else 0.4)
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(0)


	box.set_content_margin_all(0.0)


	box.border_width_top = 0
	return box


func _tab_box(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var box:= StyleBoxFlat.new()
	box.bg_color = COL_SELECTED if selected else Color(0.1, 0.12, 0.11, 0.86 if hover else 0.72)
	box.border_color = COL_SELECTED if selected else Color(1, 1, 1, 0.34 if hover else 0.18)
	box.set_border_width_all(1)
	box.border_width_bottom = 0
	box.set_corner_radius_all(0)
	box.content_margin_top = 1.0
	box.content_margin_bottom = 1.0
	return box


func _on_slot_pressed(index: int) -> void:
	if player != null:
		player.select_hotbar_slot(index)


func _on_catalog_pressed() -> void:
	if catalog != null:
		catalog.set_open(true)


func _on_drop_pressed() -> void:
	if player != null:
		player.drop_active_tool()
