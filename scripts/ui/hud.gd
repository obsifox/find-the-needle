class_name Hud
extends Control


const CROSS_RADIUS:= 6.0
const CROSS_RADIUS_HOT:= 8.5
const CROSS_WIDTH:= 1.6


const CROSS_ARM_GAP:= 0.55
const CROSS_ARM_END:= 1.35


const CROSS_DOT_SCALE:= 0.42


const MONEY_SIZE:= 60


const INCOME_SIZE:= 24


const HAY_RATE_SIZE:= 18
const HAY_RATE_ROW:= 26
const COL_INCOME:= Color(0.92, 0.95, 0.74, 0.78)


const COL_OWED:= Color(1.0, 0.52, 0.42)

const OWED_ROW:= 28


const LOST_TOAST_SECONDS:= 10.0


const TOAST_SIDE:= 360
const LOST_TOAST_COLOR:= Color(1.0, 0.28, 0.22)


const HUD_NOTICE_SECONDS:= 3.5
const HUD_NOTICE_SIZE:= 22
const COL_HUD_NOTICE:= Color(0.96, 0.97, 0.94, 0.85)


const WATERMARK_TEXT:= "Find The Needle Demo " + Cfg.BUILD_TAG


const WATERMARK_TEXT_FULL:= "Find The Needle " + Cfg.BUILD_TAG
const WATERMARK_SIZE:= 24
const COL_WATERMARK:= Color(0.96, 0.97, 0.94, 0.6)
const COL_WATERMARK_PLATE:= Color(0.02, 0.03, 0.04, 0.42)


const WATERMARK_NOTE:= "Bugs might exist. Please report them on Discord."
const WATERMARK_NOTE_SIZE:= 12
const COL_WATERMARK_NOTE:= Color(0.96, 0.97, 0.94, 0.52)


const COL_CASE:= Color(1.0, 0.9, 0.62)


const WRECK_W:= 260.0
const WRECK_H:= 12.0
const WRECK_TOP:= 34.0
const COL_WRECK:= Color(0.96, 0.44, 0.28)


const COL_FLIP:= Color(0.42, 0.76, 0.98)


const COL_RIP:= Color(0.9, 0.74, 0.36)


const STAM_W:= 280.0
const STAM_H:= 16.0


const STAM_LEFT:= 24.0
const STAM_UP:= 74.0


const COL_STAM_FULL:= Color(0.92, 0.82, 0.44)
const COL_STAM_LOW:= Color(0.9, 0.38, 0.26)
const COL_STAM_PLATE:= Color(0.03, 0.03, 0.04, 0.55)


const RAINBOW_TURNS:= 1.4
const RAINBOW_FADE:= 0.5


const DET_W:= 210.0
const DET_H:= 12.0
const DET_UP:= 100.0


const COL_DET_LOW:= Color(0.36, 0.55, 0.62)
const COL_DET_HIGH:= Color(0.42, 0.86, 0.52)


const FUEL_W:= 210.0
const FUEL_H:= 10.0
const FUEL_GAP:= 12.0


const COL_FUEL_FULL:= Color(0.46, 0.8, 0.96)
const COL_FUEL_LOW:= Color(0.96, 0.44, 0.2)


const STAM_LINGER:= 1.2


const PUNCH_ADD:= 0.22
const PUNCH_MAX:= 0.55


const PUNCH_FALL:= 3.2


const PUNCH_SHAKE:= 26.0
const PUNCH_SHAKE_AMT:= 0.18
const COL_WRECK_PLATE:= Color(0.03, 0.03, 0.04, 0.62)


const PROMPT_TOP:= 132.0
const PROMPT_HEIGHT:= 62.0
const PROMPT_FADE:= 7.0


const PROMPT_POP_STIFF:= 320.0
const PROMPT_POP_DAMP:= 16.0

const PROMPT_POP_FROM:= 0.72


const PROMPT_POP_OUT:= 2.0
const PROMPT_POP_SWAP:= 1.6


const PROMPT_ICON_H:= 42
const PROMPT_ICON_W:= 48


const DEBUG_TOP:= 12.0
const DEBUG_GAP:= 10.0


const FRAME_WINDOW_USEC:= 3000000
const COL_PROMPT_KEY:= Color(0.06, 0.07, 0.09)
const COL_PROMPT_TITLE:= Color(1.0, 0.86, 0.34)
const COL_PROMPT_SUB:= Color(0.86, 0.88, 0.94, 0.82)

var field: HayField
var live: LiveStrandManager
var props: PropManager
var player: Player


var shop: ShopMenu


var map: MapMenu


var quests: QuestPanel

var _debug:= false
var _label: Label
var _toast: Label
var _toast_time:= 0.0
var _fps_avg:= 60.0


var _frame_end_usec:= PackedInt64Array()
var _frame_ms:= PackedFloat32Array()
var _last_frame_usec:= 0
var _ring:= CROSS_RADIUS
var _money: Label

var _owed: Label

var _income: Label


var _belts_full: Label


var _ready_card: Label
var _ready_pill: PanelContainer
var _ready_icon: TextureRect

var _ready_hide_msec:= -1
var _ready_fade: Tween
var _ready_card_poll:= 0.0
var _ready_pulse: Tween


var _ready_alert_msec:= -1


var _ready_shown_id:= ""


const READY_ALERT_GAP:= 20.0


const READY_SHOW_FOR:= 4.0

const READY_FADE:= 0.4

const READY_ICON_SIZE:= 30.0


const READY_BREATH_WINDOW:= 45.0

const COL_READY_TEXT:= Color(0.07, 0.13, 0.05)


const READY_CARD_POLL:= 0.25


const COL_READY_CARD:= Color(0.72, 0.93, 0.56)

var _hand_count: Label
var _hand_full_shown:= false
const COL_HAND_FULL:= Color(1.0, 0.78, 0.35)
var _belts_full_cap:= 0


var _income_shown:= -1.0
var _hay_left: Label


var _hay_rate: Label
var _hay_rate_shown:= -1.0
var _build: Label

var _tip: Label


var _cancel_hint: HBoxContainer
var _cancel_icon: TextureRect

const CANCEL_ICON:= 30.0

var _price: Label

var _no_snap: Label
var _upgrades: Label


const UPGRADES_TOP:= 52.0
const UPGRADES_TOP_WITH_TIP:= 74.0
const UPGRADES_BOTTOM:= 100.0


const TIP_TOP:= 52.0

const PRICE_SIZE:= 32
const TIP_BOTTOM:= 96.0


const SHORT_BELOW:= 0.7

var _case: Label


var _cab_since:= 0.0
var _hints: ControlHints
var _nudge: UpgradeNudge
var _hotkey_bar: HotkeyBar

var _wreck: Control
var _stam: Control
var _stam_plate: Panel
var _stam_fill: ColorRect

var _stam_punch:= 0.0


var _stam_shake:= 0.0
var _stam_seen_refusals:= 0


var _stam_linger:= 0.0


var _stam_seen_glow:= 0.0
var _stam_hue:= 0.0

var _stam_rainbow: ShaderMaterial = null
var _det: Control
var _det_fill: ColorRect
var _det_label: Label
var _fuel: Control
var _fuel_plate: Panel
var _fuel_fill: ColorRect
var _fuel_label: Label

var _fuel_linger:= 0.0
var _wreck_fill: ColorRect
var _wreck_label: Label
var _watermark: Control
var _power_warning: PowerWarning
var _prompt: Control
var _prompt_a:= 0.0


var _prompt_plate: Control

var _prompt_scale:= 1.0
var _prompt_scale_v:= 0.0
var _prompt_cap: Control
var _prompt_icon: TextureRect
var _prompt_key: Label
var _prompt_title: Label
var _prompt_sub: Label


var _prompt_kinds: HBoxContainer


var _prompt_source:= ""

var _t_hovered: ConveyorTSplitter
var _no_hud:= false


var _hud_notice: Label
var _hud_notice_time:= 0.0


var _build_tone:= "good"


var _lit_pole: PowerPole = null
var _lit_machines: Array [Node3D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


	_apply_hud_scale()
	get_viewport().size_changed.connect(_apply_hud_scale)

	_label = Label.new()
	_label.position = Vector2(16, DEBUG_TOP)
	UiFont.style(_label, 15, Color(1, 1, 1, 0.82), 4)
	_label.visible = false
	add_child(_label)

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 88


	_toast.offset_left = TOAST_SIDE
	_toast.offset_right = - TOAST_SIDE
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_toast, 30, Color(1, 0.96, 0.86), 6, true)
	_toast.modulate.a = 0.0
	add_child(_toast)


	_hud_notice = Label.new()
	_hud_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_notice.offset_top = 130
	_hud_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_hud_notice, HUD_NOTICE_SIZE, COL_HUD_NOTICE, 5, true)
	_hud_notice.modulate.a = 0.0
	add_child(_hud_notice)


	_money = Label.new()
	_money.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_money.offset_top = 8
	_money.offset_bottom = 88
	_money.offset_right = -26
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFont.style(_money, MONEY_SIZE, Color(0.92, 0.95, 0.74), 7, true)
	add_child(_money)


	_owed = Label.new()
	_owed.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_owed.offset_top = 78
	_owed.offset_bottom = 78 + OWED_ROW
	_owed.offset_right = -26
	_owed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFont.style(_owed, 22, COL_OWED, 5, true)
	_owed.visible = false
	add_child(_owed)


	_income = Label.new()
	_income.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_income.offset_top = 112
	_income.offset_bottom = 112 + INCOME_SIZE * 2
	_income.offset_right = -26
	_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFont.style(_income, INCOME_SIZE, COL_INCOME, 5, true)
	_income.visible = false
	add_child(_income)

	_belts_full = Label.new()
	_belts_full.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_belts_full.offset_right = -26
	_belts_full.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFont.style(_belts_full, HAY_RATE_SIZE, MachineAlert.COL_HAZARD, 4, true)
	_belts_full.visible = false
	add_child(_belts_full)


	_ready_pill = PanelContainer.new()
	_ready_pill.anchor_left = 1.0
	_ready_pill.anchor_right = 1.0
	_ready_pill.offset_left = -26
	_ready_pill.offset_right = -26
	_ready_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ready_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill:= StyleBoxFlat.new()
	pill.bg_color = COL_READY_CARD
	pill.border_color = COL_READY_CARD.darkened(0.45)
	pill.set_border_width_all(2)
	pill.set_corner_radius_all(14)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 3
	pill.content_margin_bottom = 3
	pill.shadow_color = Color(0, 0, 0, 0.45)
	pill.shadow_size = 4
	_ready_pill.add_theme_stylebox_override("panel", pill)
	_ready_pill.visible = false
	add_child(_ready_pill)
	var pill_row:= HBoxContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_theme_constant_override("separation", 8)
	_ready_pill.add_child(pill_row)


	_ready_icon = TextureRect.new()
	_ready_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_icon.custom_minimum_size = Vector2(READY_ICON_SIZE, READY_ICON_SIZE)
	_ready_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ready_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ready_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ready_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pill_row.add_child(_ready_icon)
	_ready_card = Label.new()
	_ready_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ready_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiFont.style(_ready_card, HAY_RATE_SIZE + 2, COL_READY_TEXT, 0, true)
	_ready_card.visible = false
	pill_row.add_child(_ready_card)


	_hand_count = Label.new()
	_hand_count.anchor_left = 0.5
	_hand_count.anchor_right = 0.5
	_hand_count.anchor_top = 0.5
	_hand_count.anchor_bottom = 0.5
	_hand_count.offset_left = 26
	_hand_count.offset_right = 160
	_hand_count.offset_top = -14
	_hand_count.offset_bottom = 14
	_hand_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hand_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.style(_hand_count, HAY_RATE_SIZE, COL_INCOME, 4, true)
	_hand_count.visible = false
	add_child(_hand_count)


	var stamp:= Label.new()
	stamp.text = WATERMARK_TEXT if Cfg.DEMO else WATERMARK_TEXT_FULL
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_theme_font_override("font", UiFont.watermark())
	stamp.add_theme_font_size_override("font_size", WATERMARK_SIZE)
	stamp.add_theme_color_override("font_color", COL_WATERMARK)
	stamp.add_theme_constant_override("outline_size", 0)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


	var note:= Label.new()
	note.text = tr(WATERMARK_NOTE)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", UiFont.regular())
	note.add_theme_font_size_override("font_size", WATERMARK_NOTE_SIZE)
	note.add_theme_color_override("font_color", COL_WATERMARK_NOTE)
	note.add_theme_constant_override("outline_size", 0)

	var lines:= VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 0)
	lines.add_child(stamp)
	lines.add_child(note)


	var plate:= DemoPlate.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _watermark_box())
	plate.stamp = lines
	plate.build_name = stamp.text


	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_watermark = VBoxContainer.new()
	_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_watermark.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_watermark.offset_top = 2
	_watermark.offset_bottom = 2 + WATERMARK_SIZE * 3
	add_child(_watermark)
	_watermark.add_child(plate)


	_power_warning = PowerWarning.new()
	_power_warning.hud = self
	_power_warning.anchor_under = plate
	add_child(_power_warning)


	plate.warning = _power_warning

	_hay_left = Label.new()
	_hay_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hay_left.offset_top = 78
	_hay_left.offset_bottom = 112


	_hay_left.offset_right = -26
	_hay_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFont.style(_hay_left, 22, Color(0.96, 0.84, 0.55, 0.9), 5, true)
	add_child(_hay_left)

	_hay_rate = Label.new()
	_hay_rate.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hay_rate.offset_right = -26
	_hay_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFont.style(_hay_rate, HAY_RATE_SIZE, Color(0.96, 0.84, 0.55, 0.7), 4, true)
	_hay_rate.visible = false
	add_child(_hay_rate)


	_build = Label.new()
	_build.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_build.anchor_top = 0.5
	_build.anchor_bottom = 0.5
	_build.offset_top = 26
	_build.offset_bottom = 92
	_build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_build, 21, Cfg.COL_GHOST_OK, 5, true)
	_build.visible = false
	add_child(_build)


	_price = Label.new()
	_price.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_price.anchor_top = 0.5
	_price.anchor_bottom = 0.5
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_price, PRICE_SIZE, Cfg.COL_GHOST_OK, 6, true)
	_price.visible = false
	add_child(_price)


	_no_snap = Label.new()
	_no_snap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_no_snap.anchor_top = 0.5
	_no_snap.anchor_bottom = 0.5
	_no_snap.offset_top = -152
	_no_snap.offset_bottom = -40
	_no_snap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_no_snap, 22, Cfg.COL_GHOST_BAD, 5, true)
	_no_snap.visible = false
	add_child(_no_snap)


	_tip = Label.new()
	_tip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tip.anchor_top = 0.5
	_tip.anchor_bottom = 0.5
	_tip.offset_top = TIP_TOP
	_tip.offset_bottom = TIP_BOTTOM
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_tip, 15, Color(0.94, 0.78, 0.42, 0.92), 4, true)
	_tip.visible = false
	add_child(_tip)


	_cancel_hint = HBoxContainer.new()
	_cancel_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_cancel_hint.anchor_top = 0.5
	_cancel_hint.anchor_bottom = 0.5
	_cancel_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_cancel_hint.add_theme_constant_override("separation", 6)
	_cancel_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_icon = TextureRect.new()
	_cancel_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cancel_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cancel_icon.custom_minimum_size = Vector2(CANCEL_ICON, CANCEL_ICON)
	_cancel_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cancel_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_hint.add_child(_cancel_icon)
	var cancel_words:= Label.new()
	cancel_words.name = "Words"
	cancel_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiFont.style(cancel_words, 19, Color(0.96, 0.94, 0.88), 5, true)
	_cancel_hint.add_child(cancel_words)
	_cancel_hint.visible = false
	add_child(_cancel_hint)


	_upgrades = Label.new()
	_upgrades.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_upgrades.anchor_top = 0.5
	_upgrades.anchor_bottom = 0.5
	_upgrades.offset_top = UPGRADES_TOP
	_upgrades.offset_bottom = UPGRADES_BOTTOM
	_upgrades.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_upgrades, 16, Color(0.72, 0.86, 0.74, 0.85), 4, true)
	_upgrades.visible = false
	add_child(_upgrades)


	_case = Label.new()
	_case.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_case.anchor_top = 0.5
	_case.anchor_bottom = 0.5
	_case.offset_top = 78
	_case.offset_bottom = 144
	_case.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_case, 22, COL_CASE, 6, true)
	_case.visible = false
	add_child(_case)

	_hints = ControlHints.new()
	_hints.name = "ControlHints"
	_hints.player = player
	add_child(_hints)

	_nudge = UpgradeNudge.new()
	_nudge.name = "UpgradeNudge"
	_nudge.player = player
	_nudge.hud = self
	add_child(_nudge)

	_hotkey_bar = HotkeyBar.new()
	_hotkey_bar.name = "HotkeyBar"
	_hotkey_bar.player = player
	add_child(_hotkey_bar)

	_wreck = _build_wreck_meter()
	add_child(_wreck)

	_stam = _build_stamina_meter()
	add_child(_stam)

	_det = _build_detector_meter()
	add_child(_det)

	_fuel = _build_fuel_meter()
	add_child(_fuel)

	_prompt = _build_prompt()
	add_child(_prompt)

	Cfg.no_hud_changed.connect(_set_no_hud)
	_set_no_hud(Cfg.no_hud)
	Cfg.hud_style_changed.connect(_on_hud_style_changed)


	Cfg.hay_readout_changed.connect(func(_mode: int) -> void: _update_hay_left())
	Cfg.show_hay_rate_changed.connect(_on_show_hay_rate_changed)

	GameState.needle_found.connect(_on_needle_found)


	GameState.money_changed.connect(_on_money_changed)
	GameState.purchased.connect(_on_purchased)
	GameState.debt_changed.connect(func(_owed: float) -> void:
		_on_money_changed(GameState.money))


	GameState.hay_changed.connect(_on_hay_changed)
	_on_money_changed(GameState.money)
	_on_hay_changed(GameState.hay_total, GameState.hay_dug)


func set_catalog(panel: CatalogPanel) -> void:
	if _hotkey_bar != null:
		_hotkey_bar.catalog = panel


func _set_no_hud(on: bool) -> void:
	_no_hud = on


	for c: Control in [_toast, _money, _hay_left, _build, _tip, _upgrades, _case, _hints,
			_hotkey_bar, _prompt, _watermark]:
		c.visible = not on


	if _nudge != null:
		_nudge.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


	_apply_optional_pieces()


	_wreck.visible = false

	_ready_card.visible = false
	_ready_pill.visible = false
	_hand_count.visible = false
	_stam.visible = false


	_det.visible = false


	_income.visible = false
	_hay_rate.visible = false

	_belts_full.visible = _belts_full_cap > 0 and not on
	_label.visible = _debug and not on


	queue_redraw()


func _apply_optional_pieces() -> void:
	if _hotkey_bar != null:
		_hotkey_bar.visible = Cfg.show_hotkey_bar and not _no_hud
	if _hints != null:
		_hints.visible = Cfg.show_control_hints and not _no_hud


func _on_hud_style_changed() -> void:
	_apply_hud_scale()
	_apply_optional_pieces()
	queue_redraw()


func _apply_hud_scale() -> void:
	var s:= clampf(Cfg.hud_scale, Cfg.HUD_SCALE_MIN, Cfg.HUD_SCALE_MAX)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	pivot_offset = Vector2.ZERO
	scale = Vector2(s, s)
	size = get_viewport_rect().size / s
	queue_redraw()


func _watermark_box() -> StyleBoxFlat:
	var box:= StyleBoxFlat.new()
	box.bg_color = COL_WATERMARK_PLATE
	box.set_corner_radius_all(0)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 4.0
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug = not _debug
		_label.visible = _debug and not _no_hud


	if event.is_action_pressed("toggle_hud"):
		Cfg.set_no_hud(not Cfg.no_hud)
		_show_hud_notice()


func _show_hud_notice() -> void:
	var key:= InputSetup.hint("toggle_hud")
	if _no_hud:
		_hud_notice.text = tr("HUD hidden. Press %s to bring it back.") % key
	else:
		_hud_notice.text = tr("HUD back. Press %s to hide it.") % key
	_hud_notice_time = HUD_NOTICE_SECONDS


func _update_hud_notice(delta: float) -> void:
	if _hud_notice_time > 0.0:
		_hud_notice_time -= delta
		_hud_notice.modulate.a = clampf(_hud_notice_time, 0.0, 1.0)
	elif _hud_notice.modulate.a != 0.0:
		_hud_notice.modulate.a = 0.0


func hud_notice_text() -> String:
	return _hud_notice.text if _hud_notice_time > 0.0 else ""


func _on_needle_found(index: int, _pos: Vector3) -> void:


	var type:= GameState.type_of(index)


	show_toast(NeedleTypes.name_of(type))


	Audio.play("needle_ting", -2.0)
	Audio.play("needle", -7.5)


func announce_needle_lost(type: int, paid: float, cause: GameState.NeedleLoss,
		back: String) -> void:


	var needle:= NeedleTypes.name_of(type)
	var what:= ""
	match cause:
		GameState.NeedleLoss.SCRAPPED:
			what = tr("NOT CAREFUL ENOUGH  ·  %s went out with the hay  ·  +$%s") % [
				needle, money_text(paid)]
		GameState.NeedleLoss.BURNED:
			what = tr("NOT CAREFUL ENOUGH  ·  %s went into the firebox and burned") % needle
		GameState.NeedleLoss.DEMOLISHED:
			what = tr("NOT CAREFUL ENOUGH  ·  %s was still inside the machine you took down") % needle
		_:
			what = tr("NOT CAREFUL ENOUGH  ·  %s was still inside what you sold") % needle
	show_toast(what + back, LOST_TOAST_SECONDS, LOST_TOAST_COLOR)


	Audio.play("needle_lost", -10.0)


func _on_money_changed(amount: float) -> void:
	_money.text = "$%s" % money_text(amount)


	var owing:= GameState.debt > 0.0
	if owing:
		_owed.text = tr("YOU OWE $%s") % money_text(GameState.debt)
	if _owed.visible != owing:
		_owed.visible = owing
		_lay_out_corner()


func _lay_out_corner() -> void:
	var drop:= OWED_ROW if _owed.visible else 0
	_hay_left.offset_top = 78 + drop
	_hay_left.offset_bottom = 112 + drop
	_hay_rate.offset_top = 112 + drop
	_hay_rate.offset_bottom = 112 + drop + HAY_RATE_ROW
	if _hay_rate.visible:
		drop += HAY_RATE_ROW
	_income.offset_top = 112 + drop
	_income.offset_bottom = 112 + drop + INCOME_SIZE * 2
	if _income.visible:
		drop += INCOME_SIZE + 8
	_belts_full.offset_top = 112 + drop
	_belts_full.offset_bottom = 112 + drop + HAY_RATE_ROW
	if _belts_full.visible:
		drop += HAY_RATE_ROW


	_ready_pill.offset_top = 112 + drop + 4
	_ready_pill.offset_bottom = 112 + drop + 4


func _update_ready_card(delta: float) -> void:
	_ready_card_poll -= delta
	if _ready_card_poll > 0.0:
		return
	_ready_card_poll = READY_CARD_POLL
	var id:= _ready_card_id()


	var key:= "" if id == "" else "%s:%d" % [id, Tech.rank_of(id)]
	var now:= Time.get_ticks_msec()
	if key != "" and key != _ready_shown_id:
		_ready_card.text = tr("UPGRADE READY  ·  %s  $%s  ·  %s") % [
			Cfg.upper(TechTree.display_name(id)), money_text(Tech.next_cost(id)),
			InputSetup.hint("tech_tree")]
		var icon:= TechPanel.icon_for(TechTree.icon_of(id))
		_ready_icon.texture = icon
		_ready_icon.visible = icon != null
		_ready_hide_msec = now + int(READY_SHOW_FOR * 1000.0)
		_show_ready(true)


		_alert_ready()
	elif key == "":
		_show_ready(false)
	elif _ready_hide_msec >= 0 and now >= _ready_hide_msec:
		_ready_hide_msec = -1
		_show_ready(false, true)
	_ready_shown_id = key


func _show_ready(on: bool, fade: bool = false) -> void:
	if _ready_fade != null and _ready_fade.is_valid():
		_ready_fade.kill()
	_ready_fade = null
	if not on and fade and _ready_pill.visible:
		_ready_fade = create_tween()
		_ready_fade.tween_property(_ready_pill, "modulate:a", 0.0, READY_FADE)
		_ready_fade.tween_callback(func() -> void:
			_ready_fade = null
			_show_ready(false))
		return
	_ready_pill.modulate.a = 1.0
	if not on:
		_ready_hide_msec = -1
	if _ready_card.visible == on:
		return
	_ready_card.visible = on
	_ready_pill.visible = on
	_lay_out_corner()


func _alert_ready() -> void:
	var now:= Time.get_ticks_msec()
	if _ready_alert_msec >= 0 and float(now - _ready_alert_msec) / 1000.0 < READY_ALERT_GAP:
		return
	_ready_alert_msec = now


	Audio.play("build_confirm", -11.0)
	_pulse_ready.call_deferred()


func _pulse_ready() -> void:
	if _ready_pill == null or not _ready_pill.visible:
		return
	if _ready_pulse != null and _ready_pulse.is_valid():
		_ready_pulse.kill()
	_ready_pill.pivot_offset = Vector2(_ready_pill.size.x, _ready_pill.size.y * 0.5)
	_ready_pill.scale = Vector2.ONE
	_ready_pulse = create_tween()
	for beat in 3:
		_ready_pulse.tween_property(_ready_pill, "scale", Vector2.ONE * 1.14, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_ready_pulse.tween_property(_ready_pill, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _ready_card_id() -> String:
	if not Cfg.teach_hints or player == null:
		return ""


	if player.stamina != null and player.stamina.since_low() < READY_BREATH_WINDOW and TechTree.has_id("strong_back") and Tech.rank_of("strong_back") == 0 and Tech.rank_of("second_wind") == 0 and not Tech.off_site("strong_back") and bool(Tech.can_buy("strong_back") ["ok"]):
		return "strong_back"


	var carry:= player.carry
	if carry != null and carry.since_full() < READY_BREATH_WINDOW and carry.full_cap == carry.stack_capacity() and TechTree.has_id("arm_load") and not Tech.off_site("arm_load") and bool(Tech.can_buy("arm_load") ["ok"]):
		return "arm_load"
	if Tech.is_unlocked("spade"):
		return ""


	if not MissionBook.reached("buy_handful"):
		return ""
	var best:= ""
	var best_cost:= INF
	for id: String in TechTree.ids():
		if id == TechTree.ROOT:
			continue


		if TechTree.is_tuning(id) and not BuildCatalog.builds_for(TechTree.tuned_machine(id)).is_empty():
			continue
		var check: Dictionary = Tech.can_buy(id)
		if not bool(check ["ok"]):
			continue
		if id == "hand_carry":
			return id
		var cost:= float(check ["cost"])
		if cost < best_cost:
			best_cost = cost
			best = id
	return best


func _update_hand_count() -> void:
	var hand: HandTool = player.hand if player != null else null
	var show:= hand != null and hand.is_holding() and not hand.is_holding_needle()
	if show:
		var cap:= hand.capacity()
		_hand_count.text = "%d / %d" % [hand.count(), cap]
		var full:= hand.count() >= cap
		if full != _hand_full_shown:
			_hand_full_shown = full
			_hand_count.add_theme_color_override("font_color",
				COL_HAND_FULL if full else COL_INCOME)
	_hand_count.visible = show


func set_belts_full(on: bool, cap: int) -> void:
	var want:= cap if on else 0
	if want == _belts_full_cap:
		return
	_belts_full_cap = want
	if on:
		_belts_full.text = tr("BELTS FULL  ·  LIMIT %d  ·  %s > %s") % [cap, tr("OPTIONS"), tr("GAMEPLAY")]
	_belts_full.visible = on and not _no_hud
	_lay_out_corner()


func belts_full_cap() -> int:
	return _belts_full_cap


func _update_income() -> void:
	var rate:= GameState.income_per_minute()
	var shown:= roundf(rate * 100.0) / 100.0
	if shown == _income_shown and _jump_show <= 0.0:
		return
	_income_shown = shown
	if _income.visible != (shown > 0.0):
		_income.visible = shown > 0.0
		_lay_out_corner()
	if not _income.visible:
		return
	if _jump_show > 0.0:
		_income.text = tr("$%s/min  (was $%s)") % [money_text(shown), money_text(_jump_from)]

		var k:= clampf(_jump_show / 1.5, 0.0, 1.0)
		_income.modulate = Color(1.0, 1.0, 1.0).lerp(COL_JUMP, k)
	else:
		_income.text = tr("$%s/min") % money_text(shown)
		_income.modulate = Color.WHITE


const JUMP_AFTER:= 60.0
const JUMP_SHOW:= 6.0
const JUMP_MIN:= 1.05
const COL_JUMP:= Color(0.55, 1.0, 0.55)
var _jump_from:= 0.0
var _jump_wait:= 0.0
var _jump_show:= 0.0


func _on_purchased(_kind: String, _id: String) -> void:
	if _jump_wait <= 0.0 and _jump_show <= 0.0:
		_jump_from = GameState.income_per_minute()
	_jump_wait = JUMP_AFTER


func _update_jump(delta: float) -> void:
	if _jump_show > 0.0:
		_jump_show = maxf(0.0, _jump_show - delta)
		if _jump_show <= 0.0:
			_income_shown = -1.0
	if _jump_wait <= 0.0:
		return
	_jump_wait -= delta
	if _jump_wait > 0.0:
		return
	var now:= GameState.income_per_minute()
	if _jump_from > 0.0 and now >= _jump_from * JUMP_MIN:
		_jump_show = JUMP_SHOW


func _on_show_hay_rate_changed(_on: bool) -> void:
	_hay_rate_shown = -1.0
	_update_hay_rate()


func _update_hay_rate() -> void:
	var on:= Cfg.show_hay_rate and not _no_hud
	if _hay_rate.visible != on:
		_hay_rate.visible = on
		_lay_out_corner()
	if not on:
		return
	var shown:= roundf(GameState.hay_removed_per_minute())
	if shown == _hay_rate_shown:
		return
	_hay_rate_shown = shown
	_hay_rate.text = tr("%s DUG/MIN") % fmt(shown)


func _on_hay_changed(_remaining: float, _dug_total: float) -> void:
	_update_hay_left()


func _update_hay_left() -> void:
	_hay_left.text = tr("%s HAY LEFT") % hay_left_amount()


static func hay_left_amount() -> String:
	if Cfg.hay_readout == Cfg.HayReadout.AMOUNT:
		return fmt(GameState.hay_never_dug())
	return Cfg.percent(str(int(round(GameState.hay_left_fraction() * 100.0))))


func show_toast(text: String, seconds: float = 3.0,
		tint: Color = Color.WHITE) -> void:
	_toast.text = text
	_toast_time = maxf(seconds, 0.0)
	_toast.modulate = Color(tint.r, tint.g, tint.b, _toast.modulate.a)


func toast_text() -> String:
	return _toast.text


func toast_up() -> bool:
	return _toast_time > 0.0


func _process(delta: float) -> void:
	_record_frame()


	if _hints.player == null:
		_hints.player = player
	if _nudge.player == null:
		_nudge.player = player


	_update_hud_notice(delta)


	if _no_hud:
		return


	var target:= (CROSS_RADIUS_HOT if _aiming_at_something() else CROSS_RADIUS) * Cfg.crosshair_size
	_ring = lerpf(_ring, target, clampf(delta * 16.0, 0.0, 1.0))
	queue_redraw()

	_update_ready_card(delta)
	_update_hand_count()

	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	elif _toast.modulate.a != 0.0:
		_toast.modulate.a = 0.0

	_update_jump(delta)
	_update_income()
	_update_hay_rate()
	_update_wreck_meter()
	_update_stamina_meter(delta)
	_update_detector_meter()

	_update_fuel_meter(delta)
	_update_build_readout()
	_update_case_prompt()
	_update_cabinet_toast(delta)

	_update_t_hover(delta)
	_update_prompt(delta)
	_update_throw_hover()

	if not _debug or field == null:
		return


	var top:= DEBUG_TOP
	if quests != null:
		var edge:= quests.bottom_edge()
		if edge > 0.0:
			top = edge + DEBUG_GAP
	_label.position.y = top
	_fps_avg = lerpf(_fps_avg, Engine.get_frames_per_second(), 0.1)
	var carried:= 0
	if player != null:
		if player.current_tool == Player.Tool.SHOVEL:
			carried = player.shovel.carried_strands()
		elif player.current_tool == Player.Tool.PITCHFORK:
			carried = player.pitchfork.carried_strands()
	_label.text = "\n".join([
		_frame_line(),


		"position         %.1f, %.1f, %.1f"
			% ([player.global_position.x, player.global_position.y,
				player.global_position.z] if player != null else [0.0, 0.0, 0.0]),


		"hay in pile      %s   (drain gave back %s)"
			% [fmt(GameState.hay_total), fmt(GameState.hay_returned)],
		"hay excavated    %s" % fmt(GameState.hay_dug),
		"hay sold         %s   ($%s earned)"
			% [fmt(GameState.hay_sold), money_text(GameState.money_earned)],
		"crust drawn      %s" % fmt(field.drawn_instance_count()),
		"strands simulated %d / %d" % [live.active_count(), Cfg.live_strand_budget],


		"hay objects      %d bodies, %d on belts"
			% [props.items.size() if props != null else 0, BeltPath.records_aboard()],
		"on active tool   %d" % carried,
		"stamina          %d / %d"
			% [int(player.stamina.current) if player != null else 0,
				int(player.stamina.maximum()) if player != null else 0],
		"needles found    %d" % GameState.needles_found,
		"quality          %s  (perf x%.2f)" % [Cfg.preset() ["name"], Cfg.perf_scale],


		"render thread    %s  (chosen %s)" % [
			"ON" if Cfg.running_render_thread() else "OFF",
			Cfg.RENDER_THREAD_NAMES [Cfg.render_thread]],

		"render           %.0f%%  (%d x %d)"
			% [100.0 * float(Cfg.gfx ["render_scale"]),


				get_tree().root.size.x * Cfg.gfx ["render_scale"],
				get_tree().root.size.y * Cfg.gfx ["render_scale"]],
	])


func _record_frame() -> void:
	var now:= Time.get_ticks_usec()
	if _last_frame_usec > 0:
		_frame_end_usec.append(now)
		_frame_ms.append((now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	var old:= 0
	while old < _frame_end_usec.size() and now - _frame_end_usec [old] > FRAME_WINDOW_USEC:
		old += 1
	if old > 0:
		_frame_end_usec = _frame_end_usec.slice(old)
		_frame_ms = _frame_ms.slice(old)


func _frame_line() -> String:
	var n:= _frame_ms.size()
	if n == 0:
		return "%d fps" % int(round(_fps_avg))
	var sorted:= _frame_ms.duplicate()
	sorted.sort()
	var p99: float = sorted [mini(n - 1, int(floor(n * 0.99)))]
	var worst: float = sorted [n - 1]
	return "%d fps   1%% low %d   worst %.1f ms  (last %d s)" % [
		int(round(_fps_avg)), int(round(1000.0 / maxf(p99, 0.001))), worst,
		roundi(FRAME_WINDOW_USEC / 1000000.0)]


func _update_case_prompt() -> void:
	if _no_hud or player == null or player.aim == null:
		_case.visible = false
		return
	var type:= player.aim.marked_type()
	if type < 0:
		_case.visible = false
		return


	var needle:= NeedleTypes.name_of(type)
	var line:= ""
	match player.aim.marked_action():
		"deposit":
			line = tr("Click LMB to add the %s needle to the cabinet") % needle
		"take":
			line = tr("Click LMB to take a %s needle out of the drawer") % needle
		"inspect":
			line = tr("Click LMB to look at the %s needle") % needle
	_case.text = line
	_case.visible = line != ""


const CABINET_LOOK_EVERY:= 0.1


func _update_cabinet_toast(delta: float) -> void:
	_cab_since += delta
	if _cab_since < CABINET_LOOK_EVERY:
		return
	_cab_since = 0.0
	if _toast_time > 0.0 and _toast.text != _cabinet_line():
		return
	if _aimed_cabinet() == null:
		return
	show_toast(_cabinet_line(), 1.0)


func _cabinet_line() -> String:
	return tr("OPEN THE CABINET  ·  %s") % InputSetup.hint("interact")


func _aimed_cabinet() -> NeedleCabinet:
	if player == null or player.build == null or player.build.builds == null:
		return null
	var cab: NeedleCabinet = player.build.builds.cabinet_under(
		player.eye_position(), player.look_direction())
	if cab == null or cab.is_open():
		return null
	return cab


func _build_wreck_meter() -> Control:
	var root:= Control.new()
	root.name = "DismantleMeter"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = - WRECK_W * 0.5
	root.offset_right = WRECK_W * 0.5
	root.offset_top = WRECK_TOP
	root.offset_bottom = WRECK_TOP + WRECK_H + 30.0
	root.visible = false

	var plate:= Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	plate.offset_bottom = WRECK_H
	var box:= StyleBoxFlat.new()
	box.bg_color = COL_WRECK_PLATE
	box.border_color = Color(1, 1, 1, 0.26)
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	plate.add_theme_stylebox_override("panel", box)
	root.add_child(plate)


	_wreck_fill = ColorRect.new()
	_wreck_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wreck_fill.color = COL_WRECK
	_wreck_fill.position = Vector2(2, 2)
	_wreck_fill.size = Vector2(0, WRECK_H - 4.0)
	plate.add_child(_wreck_fill)

	_wreck_label = Label.new()
	_wreck_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_wreck_label.offset_top = WRECK_H + 5.0
	_wreck_label.offset_bottom = WRECK_H + 30.0
	_wreck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


	UiFont.style(_wreck_label, 17, COL_WRECK, 5, true)
	root.add_child(_wreck_label)
	return root


func _build_stamina_meter() -> Control:
	var root:= Control.new()
	root.name = "StaminaMeter"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)

	var plate:= Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(STAM_LEFT, - STAM_UP)
	plate.size = Vector2(STAM_W, STAM_H)
	var box:= StyleBoxFlat.new()
	box.bg_color = COL_STAM_PLATE
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	plate.add_theme_stylebox_override("panel", box)


	plate.pivot_offset = Vector2(0.0, STAM_H * 0.5)
	root.add_child(plate)
	_stam_plate = plate

	_stam_fill = ColorRect.new()
	_stam_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stam_fill.color = COL_STAM_FULL
	_stam_fill.position = Vector2(2, 2)
	_stam_fill.size = Vector2(0, STAM_H - 4.0)
	plate.add_child(_stam_fill)
	return root


func _update_stamina_meter(delta: float) -> void:
	if player == null or _no_hud:
		_stam.visible = false
		return
	var f:= player.stamina.fraction()
	var flash: float = player._spent_flash


	var refusals: int = player.spent_refusals
	if refusals > _stam_seen_refusals:
		_stam_punch = minf(_stam_punch
			+ PUNCH_ADD * float(refusals - _stam_seen_refusals), PUNCH_MAX)
	_stam_seen_refusals = refusals
	_stam_punch = maxf(0.0, _stam_punch - _stam_punch * PUNCH_FALL * delta)
	_stam_shake += delta * PUNCH_SHAKE


	var glow: float = player.stamina.glow
	if glow > _stam_seen_glow:
		_stam_punch = minf(_stam_punch + PUNCH_MAX * 0.6, PUNCH_MAX)
	_stam_seen_glow = glow

	if f < 0.999 or flash > 0.0 or _stam_punch > 0.001 or glow > 0.0:
		_stam_linger = STAM_LINGER
	else:
		_stam_linger = maxf(0.0, _stam_linger - delta)
	_stam.visible = _stam_linger > 0.0
	if not _stam.visible:
		_stam_punch = 0.0
		return
	_stam.modulate.a = clampf(_stam_linger / STAM_LINGER * 2.0, 0.0, 1.0)
	_stam_fill.size.x = (STAM_W - 4.0) * f
	_stam_plate.scale = Vector2.ONE * (1.0 + _stam_punch
		* (1.0 + PUNCH_SHAKE_AMT * sin(_stam_shake)))


	var tint:= COL_STAM_LOW.lerp(COL_STAM_FULL, clampf(f * 2.0, 0.0, 1.0))
	if flash > 0.0:
		tint = tint.lerp(Color(1, 1, 1), 0.35 + 0.35 * sin(flash * 34.0))
	_stam_fill.color = tint


	if glow > 0.0:
		_stam_hue = fmod(_stam_hue + delta * RAINBOW_TURNS, 1.0)
		if _stam_rainbow == null:
			_stam_rainbow = ShaderMaterial.new()
			_stam_rainbow.shader = preload("res://assets/stamina_rainbow.gdshader")
		if _stam_fill.material != _stam_rainbow:
			_stam_fill.material = _stam_rainbow
		_stam_rainbow.set_shader_parameter("phase", _stam_hue)
		_stam_rainbow.set_shader_parameter("amount", clampf(glow / RAINBOW_FADE, 0.0, 1.0))
	elif _stam_fill.material != null:
		_stam_fill.material = null


func _build_detector_meter() -> Control:
	var root:= Control.new()
	root.name = "DetectorMeter"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	root.visible = false

	var plate:= Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(STAM_LEFT, - DET_UP)
	plate.size = Vector2(DET_W, DET_H)
	var box:= StyleBoxFlat.new()
	box.bg_color = COL_STAM_PLATE
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	plate.add_theme_stylebox_override("panel", box)
	root.add_child(plate)

	_det_fill = ColorRect.new()
	_det_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_det_fill.color = COL_DET_LOW
	_det_fill.position = Vector2(2, 2)
	_det_fill.size = Vector2(0, DET_H - 4.0)
	plate.add_child(_det_fill)

	_det_label = Label.new()
	_det_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_det_label.position = Vector2(STAM_LEFT + DET_W + 10.0, - DET_UP - 4.0)
	UiFont.style(_det_label, 15, Color(0.86, 0.88, 0.9), 4)
	root.add_child(_det_label)
	return root


func _update_detector_meter() -> void:
	var det: MetalDetector = player.detector if player != null else null
	if det == null or _no_hud or not det.is_active():
		_det.visible = false
		return
	_det.visible = true
	var f:= det.signal_strength()
	var want:= (DET_W - 4.0) * f
	_det_fill.size.x = lerpf(_det_fill.size.x, want, 0.25)
	_det_fill.color = COL_DET_LOW.lerp(COL_DET_HIGH, f)
	if not det.is_powered():


		_det_label.text = tr("OFF")
		_det_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
	else:
		_det_label.text = tr("SIGNAL")
		_det_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9))


func _build_fuel_meter() -> Control:
	var root:= Control.new()
	root.name = "FuelMeter"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	root.visible = false

	_fuel_plate = Panel.new()
	_fuel_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel_plate.position = Vector2(STAM_LEFT, - (STAM_UP + FUEL_H + FUEL_GAP))
	_fuel_plate.size = Vector2(FUEL_W, FUEL_H)
	var box:= StyleBoxFlat.new()
	box.bg_color = COL_STAM_PLATE
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	_fuel_plate.add_theme_stylebox_override("panel", box)
	root.add_child(_fuel_plate)

	_fuel_fill = ColorRect.new()
	_fuel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel_fill.color = COL_FUEL_FULL
	_fuel_fill.position = Vector2(2, 2)
	_fuel_fill.size = Vector2(0, FUEL_H - 4.0)
	_fuel_plate.add_child(_fuel_fill)

	_fuel_label = Label.new()
	_fuel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel_label.text = tr("JETPACK")
	UiFont.style(_fuel_label, 13, Color(0.86, 0.88, 0.9), 4)
	root.add_child(_fuel_label)
	return root


func _update_fuel_meter(delta: float) -> void:
	var jp: Jetpack = player.jetpack if player != null else null
	if jp == null or _no_hud or not jp.owned():
		_fuel.visible = false
		_fuel_linger = 0.0
		return
	var f:= jp.fraction()
	if jp.is_thrusting() or jp.is_recharging() or f < Cfg.JETPACK_LOW:
		_fuel_linger = STAM_LINGER
	else:
		_fuel_linger = maxf(0.0, _fuel_linger - delta)
	_fuel.visible = _fuel_linger > 0.0
	if not _fuel.visible:
		return
	_fuel.modulate.a = clampf(_fuel_linger / STAM_LINGER * 2.0, 0.0, 1.0)
	var below:= DET_UP if _det.visible else STAM_UP
	var up:= below + FUEL_H + FUEL_GAP
	_fuel_plate.position.y = - up
	_fuel_label.position = Vector2(STAM_LEFT + FUEL_W + 10.0, - up - 5.0)
	_fuel_fill.size.x = (FUEL_W - 4.0) * f
	_fuel_fill.color = COL_FUEL_LOW.lerp(COL_FUEL_FULL, clampf(f * 2.0, 0.0, 1.0))


func _update_wreck_meter() -> void:
	var p:= _wreck_progress()
	var tint:= COL_WRECK


	var named:= _wreck_name()
	var want:= (tr("DISMANTLING %s    hold %s") % [named, InputSetup.hint("dismantle")]
		if named != "" else tr("DISMANTLING    hold %s") % InputSetup.hint("dismantle"))
	if p < 0.0:
		p = _rip_progress()
		tint = COL_RIP


		want = tr("RIPPING OPEN    hold %s") % InputSetup.hint("dismantle")
	if p < 0.0:
		p = _flip_progress()
		tint = COL_FLIP
		want = tr("REVERSING    hold %s") % InputSetup.hint("interact")
	_wreck.visible = p >= 0.0 and not _no_hud
	if not _wreck.visible:
		return
	_wreck_fill.size.x = (WRECK_W - 4.0) * p
	_wreck_fill.color = tint


	if _wreck_label.text != want:
		_wreck_label.text = want
		UiFont.style(_wreck_label, 17, tint, 5, true)


func _wreck_name() -> String:
	if player == null or player.build == null:
		return ""
	return Cfg.upper(player.build.dismantle_name())


func _wreck_progress() -> float:
	if player == null or player.build == null:
		return -1.0
	return player.build.dismantle_progress()


func _rip_progress() -> float:
	if player == null or player.carry == null:
		return -1.0
	return player.carry.rip_progress()


func _flip_progress() -> float:
	if player == null or player.build == null:
		return -1.0
	return player.build.reverse_progress()


func _build_prompt() -> Control:


	var bar:= HBoxContainer.new()
	bar.name = "WalkUpPrompt"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = PROMPT_TOP
	bar.offset_bottom = PROMPT_TOP + PROMPT_HEIGHT
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.modulate.a = 0.0

	var plate:= PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 9.0
	plate.add_theme_stylebox_override("panel", sb)
	bar.add_child(plate)
	_prompt_plate = plate


	plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)


	var cap:= PanelContainer.new()
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap_sb:= StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.94, 0.96, 1.0, 0.94)
	cap_sb.set_corner_radius_all(0)
	cap_sb.content_margin_left = 11.0
	cap_sb.content_margin_right = 11.0
	cap_sb.content_margin_top = 3.0
	cap_sb.content_margin_bottom = 4.0
	cap.add_theme_stylebox_override("panel", cap_sb)
	_prompt_key = Label.new()


	_prompt_key.text = InputSetup.hint("interact")
	UiFont.style(_prompt_key, 24, COL_PROMPT_KEY, 0, true)
	cap.add_child(_prompt_key)
	row.add_child(cap)
	_prompt_cap = cap


	_prompt_icon = TextureRect.new()
	_prompt_icon.visible = false
	_prompt_icon.custom_minimum_size = Vector2(PROMPT_ICON_W, PROMPT_ICON_H)
	_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prompt_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_prompt_icon)

	var text:= VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_title = Label.new()
	UiFont.style(_prompt_title, 24, COL_PROMPT_TITLE, 5, true)
	text.add_child(_prompt_title)
	_prompt_sub = Label.new()
	UiFont.style(_prompt_sub, 14, COL_PROMPT_SUB, 4)
	var sub_row:= HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 6)
	sub_row.add_child(_prompt_sub)
	_prompt_kinds = HBoxContainer.new()
	_prompt_kinds.add_theme_constant_override("separation", 2)
	_prompt_kinds.visible = false
	sub_row.add_child(_prompt_kinds)
	text.add_child(sub_row)
	row.add_child(text)
	return bar


func _update_prompt(delta: float) -> void:
	var source:= _prompt_wanted()
	if source != _prompt_source:


		if source == "":
			_prompt_scale_v += PROMPT_POP_OUT
		elif _prompt_source == "":
			_prompt_scale = PROMPT_POP_FROM
			_prompt_scale_v = 0.0
		else:
			_prompt_scale_v += PROMPT_POP_SWAP
		_prompt_source = source
		_write_prompt(source)
	var target:= 1.0 if source != "" else 0.0
	if _prompt_a != target:
		_prompt_a = move_toward(_prompt_a, target, delta * PROMPT_FADE)
		_prompt.modulate.a = _prompt_a
	_settle_prompt(delta)


func _settle_prompt(delta: float) -> void:
	if _prompt_plate == null:
		return
	if _prompt_scale == 1.0 and _prompt_scale_v == 0.0:
		return
	var left:= minf(delta, 0.1)
	while left > 0.0:
		var step:= minf(left, 1.0 / 120.0)
		left -= step
		_prompt_scale_v += (1.0 - _prompt_scale) * PROMPT_POP_STIFF * step
		_prompt_scale_v -= _prompt_scale_v * PROMPT_POP_DAMP * step
		_prompt_scale += _prompt_scale_v * step


	if absf(_prompt_scale - 1.0) < 0.001 and absf(_prompt_scale_v) < 0.01:
		_prompt_scale = 1.0
		_prompt_scale_v = 0.0
	_prompt_plate.scale = Vector2(_prompt_scale, _prompt_scale)


func _prompt_wanted() -> String:
	if player == null:
		return ""


	if player.catalog != null and player.catalog.is_open():
		return ""
	if player.tech_panel != null and player.tech_panel.is_open():
		return ""


	if player.arm_links != null and player.arm_links.is_active():
		return ""
	if player.drone_zone != null and player.drone_zone.is_active():
		return ""


	var aimed:= _console_source(_console_under())
	if aimed != "":
		return aimed


	var scanned:= _scanner_source(_scanner_under())
	if scanned != "":
		return scanned


	var dish:= _radar_under()
	if dish != null:
		return dish.plate_source()


	if player.board != null:
		match player.board.hovered_sheet(
				player.eye_position(), player.look_direction()):
			"contract":


				return "unpin" if GameState.contract_pinned else "pin"
			"note":


				return "board" if player.board.can_order() else "board_wait"
			"clearance":
				if player.sell_all_dialog == null or not player.sell_all_dialog.is_open():
					return "clearance"
	if player.bay_door != null and _door_prompt() != "":
		return "door"


	if player.leaderboards != null and not player.leaderboards.is_open() and player.leaderboards.is_at_board():
		return "leaderboards"
	if shop != null and not shop.is_open() and shop.is_at_counter():
		return "shop"
	return ""


func _console_under() -> Node3D:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.console_under(
		player.eye_position(), player.look_direction())


func _update_throw_hover() -> void:
	var aim: ThrowAim = null
	if player != null and player.build != null and player.build.builds != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not (player.catalog != null and player.catalog.is_open()) and not (player.tech_panel != null and player.tech_panel.is_open()):
		aim = ThrowAim.under_crosshair(player.build.builds,
			player.eye_position(), player.look_direction())
	ThrowAim.set_hovered(aim)


func _update_t_hover(delta: float) -> void:
	var t: ConveyorTSplitter = null
	if player != null and player.build != null and player.build.builds != null and not player.build.is_active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not (player.catalog != null and player.catalog.is_open()) and not (player.tech_panel != null and player.tech_panel.is_open()):
		t = _splitter_in_reach() as ConveyorTSplitter
	if _t_hovered != t and is_instance_valid(_t_hovered):
		_t_hovered.show_possible(false, 0.0)
	_t_hovered = t
	if t != null:
		t.show_possible(true, delta)


func _scanner_under() -> HaystackScanner:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.scanner_under(
		player.eye_position(), player.look_direction())


func _scanner_source(scanner: HaystackScanner) -> String:
	if scanner == null or player == null:
		return ""
	if player.needle_drawer != null and player.needle_drawer.is_open():
		return ""
	if scanner.has_bank():
		return "scanner:%d%s" % [scanner.banked.size(), ":held" if scanner.is_held() else ""]
	if scanner.is_drawer_open():
		return "scanner:close"
	return "scanner:empty"


func _console_source(machine: Node3D) -> String:
	if machine == null or player == null:
		return ""
	if machine is TubeLauncher:
		return "launcher" if _panel_shut(player.launcher_panel) else ""
	if machine is HaySilo:
		return "silo" if _panel_shut(player.silo_panel) else ""
	if machine is WorkLamp:
		return "lamp" if _panel_shut(player.lamp_panel) else ""
	if machine is PistonRake:
		return "rake" if _panel_shut(player.rake_panel) else ""
	if machine is HayPelletizer:
		return "mill" if _panel_shut(player.pelletizer_panel) else ""
	if machine is ConveyorSplitter:
		if not (machine as ConveyorSplitter).has_panel():
			return ""
		if not _panel_shut(player.splitter_panel):
			return ""

		if machine is ConveyorTSplitter and not (machine as ConveyorTSplitter).fed:
			return "tjunction"
		return "splitter"
	if machine is RoboticArm:
		return "arm" if _panel_shut(player.arm_panel) else ""


	if machine is HayDrone:
		if not _panel_shut(player.drone_panel):
			return ""
		var aircraft:= machine as HayDrone
		return "drone:%d%s" % [int(aircraft.has_job()), str(aircraft.plate_status() [1])]
	if machine is PowerPole:
		return "pole" if _panel_shut(player.pole_panel) else ""


	return "machine" if _panel_shut(player.machine_panel) else ""


func _panel_shut(panel: Node) -> bool:
	return panel != null and not bool(panel.call("is_open"))


func _door_prompt() -> String:
	if player == null or player.bay_door == null:
		return ""
	return player.bay_door.prompt(player.eye_position(), player.look_direction())


func _launcher_in_reach() -> TubeLauncher:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.launcher_under(
		player.eye_position(), player.look_direction())


func _launcher_stats() -> String:
	var gun:= _launcher_in_reach()
	if gun == null:
		return ""
	var alert:= gun.alert_reason()
	if alert != "":
		return alert
	return tr("throws %.0f m  ·  %.0f deg  ·  power %d%%") % [
		gun.range_metres(), gun.tilt_now(), int(round(gun.power * 100.0))]


func _lamp_in_reach() -> WorkLamp:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.lamp_under(
		player.eye_position(), player.look_direction())


func _lamp_stats() -> String:
	var lamp:= _lamp_in_reach()
	if lamp == null:
		return ""
	if lamp.is_switched_off():
		return tr("switched off")
	return tr("lighting %.0f m  ·  %.0f%% brightness") % [lamp.lit_metres(),
		lamp.brightness * 100.0]


func _silo_in_reach() -> HaySilo:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.silo_under(
		player.eye_position(), player.look_direction())


func _silo_stats() -> String:
	var tank:= _silo_in_reach()
	if tank == null:
		return ""
	var alert:= tank.alert_reason()
	if alert != "":
		return alert


	if tank.is_switched_off():
		return tr("SWITCHED OFF  ·  %d of %d loads inside") % [tank.held(), tank.capacity()]
	if not tank.is_running():
		return tr("STOPPED  ·  %d of %d loads inside") % [tank.held(), tank.capacity()]


	return tr("%d a minute  ·  %d of %d loads inside") % [
		int(round(tank.rate_per_minute())), tank.held(), tank.capacity()]


func _splitter_in_reach() -> ConveyorSplitter:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.splitter_under(
		player.eye_position(), player.look_direction())


func _splitter_stats() -> String:
	var splitter:= _splitter_in_reach()
	if splitter == null:
		return ""


	return tr("sends %s") % splitter.mode_label()


func _arm_stats() -> String:
	var arm:= _arm_in_reach()
	if arm == null:
		return ""


	if _arm_takes_some(arm):
		return tr("takes")
	if arm.accept_mask == RoboticArm.PICK_ALL:
		return tr("takes everything")
	return tr("takes %s") % arm.accept_label()


static func _arm_takes_some(arm: RoboticArm) -> bool:
	return arm.accept_mask != RoboticArm.PICK_ALL and (arm.accept_mask & ~ RoboticArm.PICK_LOCKED) != 0


func _write_arm_kinds(arm: RoboticArm) -> void:
	if _prompt_kinds == null:
		return
	for child in _prompt_kinds.get_children():
		child.queue_free()
	_prompt_kinds.visible = arm != null and _arm_takes_some(arm)
	if not _prompt_kinds.visible:
		return
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		if not arm.accepts(int(kind ["bit"])):
			continue
		var icon:= TextureRect.new()
		icon.texture = ArmPanel.kind_icon(str(kind ["id"]))
		icon.custom_minimum_size = Vector2(22.0, 22.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prompt_kinds.add_child(icon)


func _arm_in_reach() -> RoboticArm:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.arm_under(
		player.eye_position(), player.look_direction())


func _powered_in_reach() -> Node3D:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.powered_under(
		player.eye_position(), player.look_direction())


func _rake_in_reach() -> PistonRake:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.rake_under(
		player.eye_position(), player.look_direction())


func _rake_stats() -> String:
	var rake:= _rake_in_reach()
	if rake == null:
		return ""
	return tr("throws %.1f m  ·  one wad every %.1f s") % [
		rake.throw_distance, Tech.rake_throw_seconds()]


func _mill_in_reach() -> HayPelletizer:
	return _console_under() as HayPelletizer


func _mill_stats() -> String:
	var mill:= _mill_in_reach()
	if mill == null:
		return ""
	return tr("throws %.1f m  ·  one brick every %.1f s") % [
		mill.throw_distance, Tech.pellet_cycle_seconds()]


func _order_line() -> String:
	var fee:= GameState.next_stack_fee()
	if fee <= 0.0:
		return tr("This load is free")
	return tr("Pay $%s now, or $%s later") % [money_text(fee),
		money_text(GameState.credit_stack_fee())]


func _write_prompt(source: String) -> void:
	if _prompt_title == null:
		return
	_write_arm_kinds(null)
	if source.begins_with("scanner:"):
		_write_scanner_prompt(source.substr("scanner:".length()))
		return
	if source.begins_with("radar:"):
		_write_radar_prompt(source.substr("radar:".length()))
		return

	if source.begins_with("drone:"):
		_show_prompt_key("interact")
		var rest:= source.substr("drone:".length())
		_prompt_title.text = tr("DRONE JOB") if rest.begins_with("1") else tr("SET UP THE DRONE")
		_prompt_sub.text = rest.substr(1)
		return
	match source:
		"launcher":
			_show_prompt_key("interact")
			_prompt_title.text = tr("SET POWER")
			_prompt_sub.text = _launcher_stats()
		"silo":
			_show_prompt_key("interact")
			_prompt_title.text = tr("SET SPEED")
			_prompt_sub.text = _silo_stats()
		"lamp":
			_show_prompt_key("interact")


			_prompt_title.text = tr("DIM THE LAMP")
			_prompt_sub.text = _lamp_stats()
		"rake":
			_show_prompt_key("interact")
			_prompt_title.text = tr("ADJUST THROW")
			_prompt_sub.text = _rake_stats()
		"mill":
			_show_prompt_key("interact")


			_prompt_title.text = tr("ADJUST THROW")
			_prompt_sub.text = _mill_stats()
		"splitter":
			_show_prompt_key("interact")
			_prompt_title.text = tr("ADJUST SPLITTER")
			_prompt_sub.text = _splitter_stats()
		"tjunction":
			_show_prompt_key("interact")
			_prompt_title.text = tr("ADJUST SPLITTER")
			_prompt_sub.text = tr("connect belts to any side and it sets itself up")
		"arm":
			_show_prompt_key("interact")
			_prompt_title.text = tr("SET PICKUP")
			_prompt_sub.text = _arm_stats()
			_write_arm_kinds(_arm_in_reach())
		"pole":
			_show_prompt_key("interact")


			var post:= _console_under() as PowerPole
			var grid:= _grid()
			var dark:= post != null and grid != null and not grid.switches_of(post).is_empty() and not grid.line_running(post)
			_prompt_title.text = tr("TURN THE LINE ON") if dark else tr("LINE SWITCH")
			_prompt_sub.text = (tr("everything on it is switched off") if dark
				else tr("turn off everything on this line"))
		"machine":
			_show_prompt_key("interact")
			var aimed:= _powered_in_reach()
			var off:= aimed != null and aimed.has_method("is_switched_off") and bool(aimed.call("is_switched_off"))
			_prompt_title.text = tr("TURN ON") if off else tr("MACHINE SWITCH")
			_prompt_sub.text = (tr("switched off") if off else tr("running")) if aimed != null else ""
		"door":


			_show_prompt_key("interact")
			_prompt_title.text = Cfg.upper(_door_prompt())
			_prompt_sub.text = tr("Dispatch bay  ·  the yard outside")
		"board":
			_show_prompt_key("interact")
			_prompt_title.text = tr("ORDER THE NEXT LOAD")
			_prompt_sub.text = _order_line()
		"board_wait":
			_show_prompt_key("interact")
			_prompt_title.text = tr("NEXT LOAD")
			_prompt_sub.text = tr("What the next load needs, and where it lands")
		"pin":
			_show_prompt_key("interact")
			_prompt_title.text = tr("PIN THIS ORDER")
			_prompt_sub.text = tr("Show this order on your screen")
		"unpin":
			_show_prompt_key("interact")
			_prompt_title.text = tr("TAKE IT DOWN")
			_prompt_sub.text = tr("Remove the order from your screen")
		"clearance":


			_show_prompt_key("interact")
			_prompt_title.text = tr("CLEARANCE SALE")
			_prompt_sub.text = tr("Sell everything you built")
		"leaderboards":
			_show_prompt_key("interact")
			_prompt_title.text = tr("OPEN LEADERBOARDS")
			_prompt_sub.text = tr("See your rank")
		"shop":
			_show_prompt_key("interact")
			_prompt_title.text = tr("OPEN SHOP")
			_prompt_sub.text = tr("Supply Co.  ·  tools, buckets and barrows")
		_:


			pass


func _update_build_readout() -> void:


	var no_snap:= player != null and player.build != null and player.build.is_active() and player.build.snap_stopped()
	_no_snap.visible = no_snap
	if no_snap:


		_no_snap.text = "%s\n%s" % [tr("NO SNAP MODE ACTIVATED"),
			tr("You won't be able to snap to machines or anything")]


		if player.build.belt_in_hand():
			_no_snap.text += "\n" + tr("Queue won't work: hay falls off the end instead of waiting")


	_price.visible = false
	_cancel_hint.visible = false
	if _wreck.visible:
		_light_pole_coverage(null)
		_build.visible = false
		_tip.visible = false
		_upgrades.visible = false
		return
	if player == null or player.build == null or not player.build.is_active():
		var machine:= _machine_under_crosshair()


		_light_pole_coverage(machine)
		var fault:= _machine_fault(machine)


		var waiting:= _machine_waiting(machine) if fault == "" else ""
		var diagnostic:= fault if fault != "" else (
			waiting if waiting != "" else _machine_diagnostic(machine))


		var product:= _machine_product(machine) if diagnostic != "" else ""
		if product != "":
			diagnostic += "\n" + product
		_build.visible = diagnostic != ""
		_build.text = diagnostic


		var rows:= float(diagnostic.count("\n")) * float(_build.get_line_height())
		var tip:= _machine_tip(machine) if fault != "" else ""
		_tip.text = tip
		_tip.visible = tip != ""
		_tip.offset_top = TIP_TOP + rows
		_tip.offset_bottom = TIP_BOTTOM + rows


		var track:= _machine_upgrades(machine) if diagnostic != "" else ""
		_upgrades.text = track
		_upgrades.visible = track != ""


		_upgrades.offset_top = (UPGRADES_TOP_WITH_TIP if tip != "" else UPGRADES_TOP) + rows
		_upgrades.offset_bottom = UPGRADES_BOTTOM + rows
		if diagnostic != "":
			_set_build_tone("bad" if fault != "" else (
				"warn" if waiting != "" and not _machine_clear(machine) else "good"))
		return


	_light_pole_coverage(null)
	var st: Dictionary = player.build.status()
	var ok: bool = st ["ok"]
	var line: String
	if not ok and st ["reason"] != "":
		line = st ["reason"]


		var need: float = st.get("need", NAN)
		if not is_nan(need):
			line += "\n" + tr("%.2f m long, needs %.2f m") % [st ["length"], need]
	elif st.get("kind", "conveyor") == "wall":


		var whole:= int(round(st ["length"] / Cfg.WALL_PANEL))
		line = tr_n("%d bay · %.0f m    $%s", "%d bays · %.0f m    $%s", whole) % [
			whole, st ["length"], money_text(st ["cost"])] if st ["placing"] else tr("%.1f m out") % st ["reach"]
	elif st.get("kind", "conveyor") == "roof":


		var span:= int(round(st ["length"] / Cfg.ROOF_BAY))
		var deep:= int(st.get("rows", 1))
		line = tr("%d x %d bays · %.0f m2    $%s") % [span, deep,
			st ["length"] * Cfg.ROOF_DEPTH * float(deep),
			money_text(st ["cost"])] if st ["placing"] else tr("$%s    %.1f m out") % [money_text(st ["cost"]), st ["reach"]]
	elif st.get("kind", "conveyor") == "railing":
		line = tr("%.1f m    $%s") % [st ["length"], money_text(st ["cost"])] if st ["placing"] else tr("%.1f m out") % st ["reach"]
	elif st.get("kind", "conveyor") == "stair":


		line = tr("%.1f m rise · %.0f°    $%s") % [
			st ["length"], st.get("angle", 0.0), money_text(st ["cost"])] if st ["placing"] else tr("click the deck edge to start")
	elif st.get("kind", "conveyor") == "haylift":


		var decided: bool = st ["placing"] or st.get("deck_snap", false)
		line = tr("%s m up · %d sections    $%s") % [
			HayLift.metres(st ["length"]), st.get("sections", 0), money_text(st ["cost"])] if decided else tr("click the base, then look up")


		if st ["placing"] and int(st.get("sections", 0)) == 0:
			line += "\n" + tr("works like a conveyor · look up to make it taller")


		var gap: float = st.get("deck_gap", NAN)
		if decided and not is_nan(gap):
			line += "\n" + (tr("meets the deck") if absf(gap) < 0.01
				else tr("misses the deck by %d cm") % int(roundf(absf(gap) * 100.0)))
	elif st.get("kind", "conveyor") == "platform":
		var span: Vector2 = st ["span"]
		line = tr("%.0f x %.0f m    %.0f m2    $%s") % [
			span.x, span.y, st ["length"], money_text(st ["cost"])]


		var up: float = st.get("up", NAN)
		if not is_nan(up):
			var sections:= int(st.get("lift", -1))


			if sections < 0 and bool(st.get("grid", false)) and up <= HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX) + 0.01:
				sections = HayLift.sections_for(up)
			var lift_note: String
			if sections == 0:
				lift_note = tr("works with the shortest lift")
			elif sections > 0:
				lift_note = tr_n("works with a %d section lift",
					"works with a %d section lift", sections) % sections
			elif up > HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX) + 0.01:
				lift_note = tr("too high for a lift")
			else:


				lift_note = tr("press %s to fit a lift") % InputSetup.hint("build_grid")
			line += "\n" + tr("%s m up") % HayLift.metres(up) + " · " + lift_note
	elif st.get("kind", "conveyor") == "splitter":
		line = tr("one in, two out    $%s") % money_text(st ["cost"])
	elif st.get("kind", "conveyor") == "joiner":
		line = tr("two in, one out    $%s") % money_text(st ["cost"])
	elif st.get("kind", "conveyor") == "u_splitter":
		line = tr("one in, two out side by side    $%s") % money_text(st ["cost"])
	elif st.get("kind", "conveyor") == "t_splitter":


		var cost:= money_text(st ["cost"])
		if not st.get("snapped", false):
			line = tr("splits 1 belt into 2, or joins 2 into 1    $%s") % cost
			line += "\n" + tr("put it on the end of a belt")
		else:
			if st.get("straight", false):
				line = tr("splits: straight on and to one side    $%s") % cost
			else:
				line = tr("splits: left and right    $%s") % cost
			line += "\n" + tr("%s changes the ways out  ·  a 2nd belt in makes it join") % InputSetup.hint("build_rotate")
	elif st.get("kind", "conveyor") == "u_joiner":
		line = tr("two in side by side, one out    $%s") % money_text(st ["cost"])
	elif st.get("kind", "conveyor") == "water_splitter":


		line = tr("one pipe in, two out    $%s") % money_text(st ["cost"])
	elif st.get("kind", "conveyor") == "compressor":
		line = tr("%.1f hay/s  x%.1f  $%s/min max    $%s") % [st ["hay_rate"],
			st ["ratio"], money_text(st ["income_min"]), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "pulper":


		line = tr("%.1f hay/s  ·  %.1f litres/s  x%.2f  $%s/min max    $%s") % [
			st ["hay_rate"], st ["water_lps"], st ["ratio"],
			money_text(st ["income_min"]), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "paper":


		line = tr("%.0f m long  ·  %.1f hay/s  x%.2f  $%s/min max    $%s") % [
			st ["length"], st ["hay_rate"], st ["ratio"],
			money_text(st ["income_min"]), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "briquette":


		line = tr("%d straw + %d bricks a disc  ·  %.0f m long  x%.2f  $%s/min max    $%s") % [
			st ["strands"], st ["bricks"], st ["length"], st ["ratio"],
			money_text(st ["income_min"]), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "pelletizer":
		line = tr("%.1f hay/s  x%.1f  $%s/min max    $%s") % [st ["hay_rate"],
			st ["ratio"], money_text(st ["income_min"]), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "gas_plant":


		line = tr("%.0f kW  ·  bricks only  ·  needs %.1f litres/s    $%s") % [st ["output_kw"],
			st ["water_lps"], money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "generator":


		line = tr("%.0f kW  ·  full, it lasts %.0f min    $%s") % [st ["output_kw"],
			st ["burn_min"], money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "borehole":


		line = tr("%.0f litres/s  ·  needs %.0f kW    $%s") % [st ["water_lps"],
			st ["draw_kw"], money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "pole":


		line = "%s    $%s" % [st ["note"], money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "wrapper":


		line = tr("%.0f bales/h  x%.2f  $%s/min max    $%s") % [st ["rate"],
			st ["ratio"], money_text(st ["income_min"]), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "silo":


		line = tr("holds %d loads  ·  0 to %d a minute    $%s") % [
			int(st ["capacity"]), int(st ["rate_max"]),
			money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "launcher":
		line = tr("throws %.0f m at %d%% power    $%s") % [st ["range"],
			int(round(float(st ["power"]) * 100.0)), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "scanner":
		line = tr("%s    in/out %.1f hay/s    $%s") % [
			st ["tier_name"], st ["rate"], money_text(st ["cost"])]


		if st ["bottleneck"]:
			line += tr("    SLOWER THAN YOUR BEST ARM: one can feed %.1f/s") % st ["arm_rate"]
	elif st.get("kind", "conveyor") == "hay_drone":


		line = tr("works up to %.0f m away%s    $%s") % [st ["radius"], _fleet_text(st),
			money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "piston_rake":


		line = tr("%.1f m reach · throws %.1f m%s    $%s") % [Cfg.RAKE_REACH,
			Cfg.RAKE_THROW_DISTANCE, _fleet_text(st), money_text(st ["cost"])]
	elif st.get("kind", "conveyor") == "robotic_arm":
		line = tr("%s    %.1f hay/s  $%s/min raw%s%s    $%s") % [st ["tier_name"],
			st ["rate"], money_text(st ["income_min"]), _power_text(st),
			_fleet_text(st), money_text(st ["cost"])]


		if int(st.get("belts", 1)) == 0:
			line += "\n" + RoboticArm.no_belt_text(st.get("near", { }) as Dictionary)
	elif st.get("kind", "conveyor") == "paintboard":


		line = tr("a board to draw on    $%s") % money_text(st ["cost"])
	elif st.get("kind", "conveyor") == "worklamp":


		line = tr("lights up to %.0f m · runs on a battery    $%s") % [
			Cfg.WORK_LAMP_RANGE, money_text(st ["cost"])]
	elif st ["placing"]:
		line = tr("%.1f m    $%s") % [st ["length"], money_text(st ["cost"])]


		var turn: float = st.get("turn", NAN)
		if not is_nan(turn) and absf(turn) > 0.01:
			line += tr("    %.0f deg turn") % absf(rad_to_deg(turn))


		var bends: int = st.get("bends", 0)
		if bends > 0:
			line += tr_n("    goes around, %d corner", "    goes around, %d corners",
				bends) % bends
	else:
		line = tr("%.1f m out") % st ["reach"]


	if st.has("cost"):
		var price:= "$" + money_text(st ["cost"])


		if bool(st.get("gift", false)):
			if line.rfind(price) < 0:
				line += "    " + price
			line = _lift_price(line, price)
			_price.text = tr("FREE GIFT")
		else:
			line = _lift_price(line, price)
	_build.text = line
	_build.visible = true
	if not ok and player.build.stuck():
		_show_cancel_hint(line)


	_tip.visible = false
	_upgrades.visible = false


	var tone: String = "good" if ok else "bad"
	if ok:
		tone = str(st.get("tone", "good"))
	elif st.get("done", false):


		tone = "neutral"
	_set_build_tone(tone)


func _show_cancel_hint(line: String) -> void:
	var art:= InputIcons.of_action("secondary", true)
	_cancel_icon.texture = art
	_cancel_icon.visible = art != null
	(_cancel_hint.get_node("Words") as Label).text = tr("Cancel") if art != null else "%s: %s" % [InputSetup.hint("secondary"), tr("Cancel")]
	var top:= _build.offset_top + float(line.count("\n") + 1) * float(_build.get_line_height()) + 4.0
	if _price.visible:
		top = _price.offset_bottom
	_cancel_hint.offset_top = top
	_cancel_hint.offset_bottom = top + CANCEL_ICON + 4.0
	_cancel_hint.visible = true


func _lift_price(line: String, price: String) -> String:
	var at:= line.rfind(price)
	if at < 0:
		return line
	var before:= line.substr(0, at).rstrip(" ·")
	var after:= line.substr(at + price.length())
	var rest:= before + after if before != "" else after.lstrip(" ")
	_price.text = price
	_price.visible = true
	var rows:= float(rest.count("\n") + 1) * float(_build.get_line_height())
	_price.offset_top = _build.offset_top + rows + 2.0
	_price.offset_bottom = _price.offset_top + PRICE_SIZE * 1.6
	return rest


func _utility_line(machine: Node3D, wet:= false) -> String:


	if machine.has_method("is_switched_off") and bool(machine.call("is_switched_off")):


		return "\n" + tr("SWITCHED OFF  ·  %s to turn it back on") % InputSetup.hint("interact")
	var power:= 1.0
	var grid:= _grid()
	if grid != null:
		var got:= grid.report(machine)
		if not bool(got ["connected"]):
			for blocked in grid.unreachable():
				if blocked == machine:
					return "\n" + tr("NO CABLE REACHES THIS  ·  a pole is near, but something is in the way")
			return "\n" + tr("NOT ON A NETWORK  ·  put a power pole near this machine")
		power = float(got ["satisfaction"])
	var water:= 1.0
	if wet:
		var net:= _water()
		if net != null:
			var got:= net.report(machine)


			if not bool(got ["connected"]):
				return "\n" + tr("NO PIPE ON IT  ·  connect a water pipe to its flange")
			water = float(got ["satisfaction"])


	var worst:= minf(power, water)


	if worst >= SHORT_BELOW:
		var rating:= MachinePower.rating_line(machine, grid)
		return "" if rating == "" else "\n" + rating


	if water < power:
		return "\n" + tr("SHORT ON WATER  ·  everything at %d%%") % int(round(worst * 100.0))
	return "\n" + tr("SHORT ON POWER  ·  everything at %d%%") % int(round(worst * 100.0))


static func _now_text(rated: float, power: float, unit: String, fmt:= "%.1f") -> String:
	return "%s %s" % [fmt % (rated * power), unit]


func _pole_readout(pole: PowerPole) -> String:
	var grid:= _grid()
	if grid == null:
		return tr("POWER POLE")
	var got:= grid.report(pole)
	var served:= grid.served_by(pole).size()


	if pole is PowerBox:
		return tr_n("CABLE BOX    %d machine on it", "CABLE BOX    %d machines on it",
			served) % served + _network_text(got) + _shortfall_text(grid, pole, got)
	return tr_n("POWER POLE    %d machine on it", "POWER POLE    %d machines on it",
		served) % served + _network_text(got) + _shortfall_text(grid, pole, got)


func _shortfall_text(grid: PowerGrid, pole: Node3D, got: Dictionary) -> String:
	var supply:= float(got ["supply"])
	var demand:= float(got ["demand"])
	if float(got ["satisfaction"]) >= 0.999 or demand - supply <= 0.05:
		return ""
	var cap:= 0.0
	for machine in grid.members_of(pole):
		if not machine.has_method("cap_kw"):
			continue
		if machine.has_method("is_switched_off") and bool(machine.call("is_switched_off")):
			return ""
		cap += float(machine.call("cap_kw"))
	if cap > 0.0 and supply < cap * PowerWarning.HUNGRY_BELOW:
		return "\n" + PowerWarning.advice(true, false)
	var more:= maxi(ceili((demand - supply) / maxf(Tech.generator_output(), 0.001)), 1)
	return "\n" + tr_n("Build %d more hay generator.", "Build %d more hay generators.",
		more) % more


func _network_text(got: Dictionary) -> String:
	var supply:= float(got ["supply"])
	var demand:= float(got ["demand"])
	var satisfaction:= float(got ["satisfaction"])


	if satisfaction < 0.999:
		return "\n" + tr("needs %.1f kW  ·  makes %.1f kW  ·  SHORT %.1f kW  ·  everything at %d%%") % [
			demand, supply, maxf(demand - supply, 0.0), int(round(satisfaction * 100.0))]
	return "\n" + tr("needs %.1f kW  ·  makes %.1f kW  ·  %.1f kW spare") % [
		demand, supply, float(got.get("spare", 0.0))]


func _light_pole_coverage(node: Node) -> void:
	var pole: PowerPole = null
	var walk:= node
	while walk != null:
		if walk is PowerPole:
			pole = walk as PowerPole
			break
		walk = walk.get_parent()
	if pole == _lit_pole:
		return
	for machine in _lit_machines:
		if is_instance_valid(machine):
			BuildTool._set_overlay(machine, null)
	_lit_machines.clear()
	_lit_pole = pole


	CableTrace.reveal(get_tree(), "aimed", pole is PowerBox)
	var grid:= _grid()
	if pole == null or grid == null:
		return
	var overlay:= ConveyorKit.ghost_material(true)
	for machine in grid.served_by(pole):
		BuildTool._set_overlay(machine, overlay)
		_lit_machines.append(machine)


func _grid() -> PowerGrid:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.grid


func _water() -> WaterGrid:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.water


func _well_water_line(pump: BoreholePump) -> String:
	if pump.is_switched_off():
		return ""
	var net:= _water()
	if net == null:
		return ""
	var got:= net.report(pump)


	if not bool(got ["connected"]):
		return "\n" + tr("NO PIPE ON IT  ·  connect a water pipe to its flange")
	return _water_text(got)


static func _water_text(got: Dictionary) -> String:
	var supply:= float(got ["supply"])
	var demand:= float(got ["demand"])
	var satisfaction:= float(got ["satisfaction"])


	if satisfaction < 0.999:
		return "\n" + Cfg.tr("needs %.1f litres/s  ·  makes %.1f  ·  SHORT %.1f  ·  everything at %d%%") % [
			demand, supply, maxf(demand - supply, 0.0), int(round(satisfaction * 100.0))]
	return "\n" + Cfg.tr("needs %.1f litres/s  ·  makes %.1f  ·  %.1f spare") % [
		demand, supply, maxf(supply - demand, 0.0)]


static func _clock(seconds: float) -> String:
	if seconds <= 0.0:


		return Cfg.tr("out", "fuel gauge")
	var whole:= int(round(seconds))
	return Cfg.tr("%d:%02d left") % [whole / 60, whole % 60]


func _set_build_tone(tone: String) -> void:
	if tone == _build_tone:
		return
	_build_tone = tone
	var colour:= Cfg.COL_GHOST_OK
	match tone:
		"warn":
			colour = Cfg.COL_GHOST_WARN
		"bad":
			colour = Cfg.COL_GHOST_BAD
		"neutral":
			colour = Cfg.COL_GHOST_NEUTRAL
	_build.add_theme_color_override("font_color", colour)
	_price.add_theme_color_override("font_color", colour)


var _refused_pulse: Tween


func nudge_build() -> void:
	var label: Label = _price if _price.visible else _build
	if not label.visible:
		return
	if _refused_pulse != null and _refused_pulse.is_valid():
		_refused_pulse.kill()
	_price.scale = Vector2.ONE
	_build.scale = Vector2.ONE


	var rows:= float(maxi(label.get_line_count(), 1))
	label.pivot_offset = Vector2(label.size.x * 0.5,
		rows * float(label.get_line_height()) * 0.5)
	_refused_pulse = label.create_tween()
	_refused_pulse.tween_property(label, "scale", Vector2.ONE * 1.3, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refused_pulse.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _machine_under_crosshair() -> Node:
	if player == null or player.camera == null or player.current_tool == Player.Tool.BUILD:
		return null
	var from:= player.camera.global_position
	var query:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Tech.carry_reach(), Cfg.L_BUILD)
	query.exclude = [player.get_rid()]


	query.collide_with_areas = true
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.get("collider") as Node


func _machine_fault(node: Node) -> String:
	if node == null or player == null or player.build == null:
		return ""
	var builds:= player.build.builds
	if builds == null or builds.watch == null:
		return ""
	var walk:= node
	while walk != null:
		var reason:= builds.watch.alert_reason(walk)
		if reason != "":
			return reason
		walk = walk.get_parent()
	return ""


func _machine_waiting(node: Node) -> String:
	while node != null:
		if node is RoboticArm:
			return (node as RoboticArm).waiting_reason()
		node = node.get_parent()
	return ""


func _machine_clear(node: Node) -> bool:
	while node != null:
		if node is RoboticArm:
			return (node as RoboticArm).is_clear()
		node = node.get_parent()
	return false


func _machine_diagnostic(node: Node) -> String:
	while node != null:
		if node is RoboticArm:
			var arm:= node as RoboticArm
			var rated:= Tech.arm_throughput(arm.tier_index)
			return tr("%s    %s    $%s/min raw%s") % [
				tr(str(arm.tier_data() ["name"])), _now_text(rated, arm.power, tr("hay/s")),
				money_text(Tech.income_per_minute(rated * arm.power)), _utility_line(arm)]
		if node is HaystackScanner:
			var scanner:= node as HaystackScanner
			var line:= tr("%s    in/out %s    buffer %d/%d") % [
				tr(str(scanner.tier_data() ["name"])),
				_now_text(scanner.throughput(), scanner.power, tr("hay/s")),
				scanner.stored, scanner.buffer_capacity()]


			if scanner.has_block():
				var n:= scanner.blocks.size()
				var what:= Cfg.lower_in_english(ItemDb.display_name(
					str(scanner.blocks [0].get("id", ""))))


				line += tr_n("    %d %s inside  ·  %.1f s", "    %d %ss inside  ·  %.1f s each", n) % [n, what, scanner.block_seconds()]


			if Tech.arm_unlocked() and not scanner.has_block():
				var feed:= Tech.arm_throughput(Tech.max_arm_tier())


				if feed > scanner.throughput():
					line += tr("    SLOWER THAN YOUR BEST ARM: one can feed %.1f/s") % feed
			return line + _utility_line(scanner)
		if node is HayCompressor:
			var press:= node as HayCompressor
			var rated:= float(Tech.compressor_bale_strands()) / Tech.compressor_press_seconds()


			return tr("COMPRESSOR    %s    $%s/min    buffer %d/%d%s") % [
				_now_text(rated, press.power, tr("hay/s")),
				money_text(Tech.income_per_minute(rated * press.power, Tech.bale_value_ratio())),
				press.stored, press.buffer_capacity(), _utility_line(press)]
		if node is PowerPole:
			return _pole_readout(node as PowerPole)


		if node is GasPlant:
			var plant:= node as GasPlant
			return tr("GAS PLANT    makes %.1f / %.1f kW  ·  burns %.1f hay/s  ·  gets %.1f hay/s  ·  hopper %s  ·  tank %s%s") % [
				plant.output_kw(), plant.rated_output_kw(), plant.burning_strands(),
				plant.arriving, _clock(plant.fuel_seconds()),
				_clock(plant.tank_seconds()), _utility_line(plant)]
		if node is HayGenerator:
			var gen:= node as HayGenerator


			return tr("HAY GENERATOR    makes %.1f / %.1f kW  ·  burns %.1f hay/s  ·  gets %.1f hay/s  ·  box %d/%d, %s%s") % [
				gen.output_kw(), gen.rated_output_kw(), gen.burning_strands(),
				gen.arriving, gen.box_strands(), gen.box_capacity_strands(),
				_clock(gen.fuel_seconds()), _utility_line(gen)]
		if node is BoreholePump:
			var pump:= node as BoreholePump


			return tr("BOREHOLE PUMP    makes %s  ·  %.0f strokes a minute%s%s") % [
				_now_text(Tech.borehole_output(), pump.power, tr("litres/s")),
				pump.strokes_per_minute(), _utility_line(pump),
				_well_water_line(pump)]
		if node is HayPulper:
			var pulper:= node as HayPulper


			var rated:= float(Tech.pulper_batch_strands())
			var pulp_rate:= rated / Tech.pulper_cycle_seconds()
			return tr("PULPER    %s    $%s/min    buffer %d/%d%s") % [
				_now_text(pulp_rate, pulper.drive(), tr("hay/s")),
				money_text(Tech.income_per_minute(pulp_rate * pulper.drive(),
					Tech.pulp_value_ratio())),
				pulper.stored, pulper.buffer_capacity(),
				_utility_line(pulper, true)]
		if node is PaperMachine:
			var mill:= node as PaperMachine


			var paper_ratio:= Tech.pulp_value_ratio() * Tech.paper_value_ratio()
			return tr("PAPER MILL    %s  x%.2f total    queue %d/%d%s") % [
				_now_text(3600.0 / Tech.paper_cycle_seconds(), mill.power,
					tr("rolls/h"), "%.0f"),
				paper_ratio, mill.queued.size(), mill.buffer_capacity(),
				_utility_line(mill)]
		if node is BriquettePress:
			var briq:= node as BriquettePress


			return tr("FEED DISC PRESS    %s  x%.2f    hay %d/%d  ·  bricks %d/%d%s") % [
				_now_text(3600.0 / Tech.briquette_cycle_seconds(), briq.power,
					tr("discs/h"), "%.0f"),
				Tech.disc_value_ratio(),
				briq.stored_strands, briq.strand_capacity(),
				briq.stored_bricks, briq.brick_capacity(),
				_utility_line(briq)]
		if node is HayWrapper:
			var wrap:= node as HayWrapper


			var foil_ratio:= Tech.bale_value_ratio() * Tech.foil_value_ratio()
			return tr("WRAPPER    %s  x%.2f total    queue %d/%d%s") % [
				_now_text(3600.0 / Tech.wrapper_seconds(), wrap.power, tr("bales/h"), "%.0f"),
				foil_ratio, wrap.queued.size(), wrap.buffer_capacity(), _utility_line(wrap)]
		if node is PistonRake:


			var rake:= node as PistonRake
			var period:= Tech.rake_throw_seconds()


			var cadence:= tr("standing still")
			if rake.power > 0.0:
				cadence = tr("one wad every %.1f s") % (period / rake.power)
			return tr("PISTON RAKE    %s    throws %.1f m    %s%s") % [
				_now_text(float(Tech.rake_bite_strands()) / period, rake.power, tr("hay/s")),
				rake.throw_distance, cadence, _utility_line(rake)]
		if node is HayDrone:


			var aircraft:= node as HayDrone
			var job:= tr("not set up")
			if aircraft.has_job():
				job = tr("digging") if aircraft.mode == HayDrone.Mode.DIG else tr("collecting")
			return tr("HAY DRONE    %s    %d loads carried%s") % [job, aircraft.trips,
				_utility_line(aircraft)]
		if node is HayPelletizer:
			var mill:= node as HayPelletizer
			var rated:= float(Tech.pellet_brick_strands()) / Tech.pellet_cycle_seconds()

			return tr("PELLETIZER    %s    $%s/min    buffer %d/%d%s") % [
				_now_text(rated, mill.power, tr("hay/s")),
				money_text(Tech.income_per_minute(rated * mill.power, Tech.brick_value_ratio())),
				mill.stored, mill.buffer_capacity(), _utility_line(mill)]
		node = node.get_parent()
	return ""


func _machine_product(node: Node) -> String:
	while node != null:
		if node is HayCompressor:
			return tr("1 bale = %d hay strands") % Tech.compressor_bale_strands()
		if node is HayPelletizer:
			return tr("1 brick = %d hay strands") % Tech.pellet_brick_strands()


		if node is GasPlant:
			return tr("%d kW = 1 brick strand a second") % int(round(Cfg.GAS_PLANT_KJ_PER_STRAND))
		if node is HayGenerator:


			return tr("1 kW = 1 hay strand a second")
		if node is HayPulper:


			return tr("1 pulp slab = %d hay strands + %.0fl") % [
				Tech.pulper_batch_strands(), Cfg.PULPER_WATER_LITRES]
		if node is HayWrapper:


			return tr("1 wrapped bale = 1 bale")
		if node is PaperMachine:


			return tr("1 paper roll = %d pulp slabs") % Cfg.PAPER_SLABS_PER_ROLL
		if node is BriquettePress:


			return tr("1 feed disc = %d hay strands + %d eco bricks (%d strands each)") % [
				Tech.briquette_batch_strands(), Tech.briquette_batch_bricks(),
				Tech.pellet_brick_strands()]
		if node is BoreholePump:


			return tr("1 stroke = %.0fl") % (Tech.borehole_output() * 60.0
				/ maxf(Cfg.BOREHOLE_STROKES_PER_MIN, 0.001))
		node = node.get_parent()
	return ""


func _machine_tip(node: Node) -> String:
	var walk:= node
	while walk != null:
		if walk.has_method("alert_tip"):
			return str(walk.call("alert_tip"))
		walk = walk.get_parent()
	return ""


func _machine_upgrades(node: Node) -> String:
	var id:= _catalog_id_of(node)
	if id == "":
		return ""
	var parts: PackedStringArray = []
	for tech_id: String in BuildCatalog.upgrades_of(id):
		parts.append("%s %d/%d" % [TechTree.display_name(tech_id),
			Tech.rank_of(tech_id), TechTree.max_rank(tech_id)])
	return "    ".join(parts)


func _catalog_id_of(node: Node) -> String:
	while node != null:
		if node is RoboticArm:
			return "arm"
		if node is HaystackScanner:
			return "scanner"
		if node is HayCompressor:
			return "compressor"
		if node is HayPulper:
			return "pulper"
		if node is PaperMachine:
			return "paper_machine"
		if node is BriquettePress:
			return "briquette_press"
		if node is HayWrapper:
			return "wrapper"
		if node is HaySilo:
			return "silo"
		if node is PistonRake:
			return "rake"
		if node is HayPelletizer:
			return "pelletizer"
		if node is GasPlant:
			return "gas_plant"
		if node is HayGenerator:
			return "generator"
		if node is BoreholePump:
			return "borehole"
		if node is WaterSplitter:
			return "water_splitter"
		if node is PowerBox:
			return "box"
		if node is PowerPole:
			return "pole"
		if node is TubeLauncher:
			return "launcher"
		if node is WorkLamp:
			return "worklamp"
		if node is HayDrone:
			return "drone"
		node = node.get_parent()
	return ""


static func _power_text(st: Dictionary) -> String:
	if not st.has("draw_kw"):
		return ""
	var draw:= float(st ["draw_kw"])
	var spare:= float(st.get("spare_kw", 0.0))
	if spare >= draw:
		return Cfg.tr("    needs %.1f kW · %.1f spare") % [draw, spare]
	return Cfg.tr("    needs %.1f kW · %.1f spare · SHORT") % [draw, spare]


static func _fleet_text(st: Dictionary) -> String:
	if not st.has("limit"):
		return ""
	var count:= int(st.get("count", 0))
	if count < int(st.get("free", 0)):
		return ""
	return "    " + Cfg.tr("%d of %d") % [count, int(st ["limit"])]


static func money_text(v: float) -> String:
	if absf(v) < Cfg.MONEY_CENTS_BELOW:
		return "%.2f" % v
	return fmt(v)


static func fmt(v: float) -> String:
	var n:= int(round(v))
	var s:= str(absi(n))
	var out:= ""
	var c:= 0
	for i in range(s.length() - 1, -1, -1):
		out = s [i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _aiming_at_something() -> bool:
	if player == null:
		return false
	if player.carry != null and player.carry.target() != null:
		return true
	return player.aim != null and player.aim.has_target()


func _draw() -> void:
	if _no_hud:
		return


	var px:= 1.0 / maxf(scale.x, 0.001)
	draw_crosshair(self, (size * 0.5).round(), _ring * px, px,
		_aiming_at_something())


static func draw_crosshair(canvas: CanvasItem, centre: Vector2, radius: float,
		px: float, hot: bool) -> void:
	if Cfg.crosshair_style == Cfg.CROSSHAIR_OFF:
		return
	var c:= centre
	var tint:= Cfg.crosshair_tint()
	tint.a *= 0.95 if hot else 0.7


	var edge:= Color(1, 1, 1, 0.62) if Cfg.crosshair_colour == Cfg.CROSSHAIR_BLACK else Color(0, 0, 0, 0.42)
	edge.a *= Cfg.crosshair_opacity


	var w:= maxf(CROSS_WIDTH * sqrt(Cfg.crosshair_size), 1.0) * px
	var r:= radius

	match Cfg.crosshair_style:
		Cfg.CROSSHAIR_DOT:
			var dot:= r * CROSS_DOT_SCALE
			canvas.draw_circle(c, dot + w * 0.9, edge)
			canvas.draw_circle(c, dot, tint)
		Cfg.CROSSHAIR_CROSS:


			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var a:= c + dir * r * CROSS_ARM_GAP
				var b:= c + dir * r * CROSS_ARM_END
				canvas.draw_line(a, b, edge, w + 1.8 * px, true)
				canvas.draw_line(a, b, tint, w, true)
		_:
			canvas.draw_arc(c, r, 0.0, TAU, 40, edge, w + 1.8 * px, true)
			canvas.draw_arc(c, r, 0.0, TAU, 40, tint, w, true)


func _write_scanner_prompt(state: String) -> void:
	match state:
		"close":
			_show_prompt_key("interact")
			_prompt_title.text = tr("CLOSE THE DRAWER")
			_prompt_sub.text = tr("Needle scanner  ·  the drawer is empty")
		"empty":
			_hide_prompt_key()
			_prompt_title.text = tr("NEEDLE SCANNER")
			_prompt_sub.text = tr("No needles yet  ·  found ones wait in the drawer")
		_:
			_show_prompt_key("interact")
			var parts:= state.split(":")
			var n:= int(parts [0])
			_prompt_title.text = tr("OPEN THE DRAWER")
			var line: String = tr("1 needle inside") if n == 1 else tr("%d needles inside") % n
			if parts.size() > 1 and parts [1] == "held":
				line += tr("  ·  the belt waits until you take them")
			_prompt_sub.text = line


func _write_radar_prompt(state: String) -> void:
	var parts:= state.split(":")
	var dish:= _radar_under()
	var shows:= NeedleRadar.tier_summary(dish.tier()) if dish != null else ""
	match parts [0]:
		"locked":
			_hide_prompt_key()
			_prompt_title.text = tr("SATELLITE DISH")
			_prompt_sub.text = tr("Buy the Satellite Dish plans to use it")
		"busy":
			_hide_prompt_key()
			_prompt_title.text = tr("SCANNING")
			_prompt_sub.text = tr("Watch the pile")
		"cool":
			_hide_prompt_key()
			_prompt_title.text = tr("RECHARGING")
			var secs:= int(parts [1]) if parts.size() > 1 else 0
			_prompt_sub.text = tr("Ready again in %d s") % secs
		_:
			_show_prompt_key("interact")
			_prompt_title.text = tr("SCAN THE PILE")
			var found:= int(parts [1]) if parts.size() > 1 else -1
			if found == 0:
				_prompt_sub.text = tr("No needles close enough last time  ·  %s") % shows
			else:
				_prompt_sub.text = shows


func _radar_under() -> NeedleRadar:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.needle_radar_under(
		player.eye_position(), player.look_direction())


func _hide_prompt_key() -> void:
	if _prompt_icon != null:
		_prompt_icon.visible = false
	_prompt_cap.visible = false


func _show_prompt_key(action: String) -> void:
	var art:= InputIcons.of_action(action)
	_prompt_key.text = InputSetup.hint(action)
	if _prompt_icon != null:
		_prompt_icon.texture = art
		_prompt_icon.visible = art != null
	_prompt_cap.visible = art == null or _prompt_icon == null
