class_name QuestPanel
extends Control


const PANEL_W:= 330.0
const MARGIN:= 22.0


const BADGE_W:= 36.0


const TICK_HOLD:= 0.75


const LONELY_AFTER:= 300.0

const PLEAD_AFTER:= 600.0


const PLEAS_PER_STEP:= 3


const BREATH_PERIOD:= 2.8
const RULE_ALPHA:= 0.4
const RULE_ALPHA_LONELY:= 0.95


const BUBBLE_W:= 250.0
const BUBBLE_GAP:= 14.0
const TAIL:= 10.0
const TYPE_RATE:= 26.0
const PLEA_HOLD:= 7.0
const PLEA_FADE:= 0.6

const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_TEXT:= Color(0.94, 0.95, 0.98)
const COL_DIM:= Color(0.74, 0.78, 0.86)
const COL_DONE:= Color(0.72, 0.93, 0.56)


const COL_REWARD:= Color(1.0, 0.93, 0.62)


var in_yard: Callable

var _panel: PanelContainer
var _plate_sb: StyleBoxFlat
var _bubble: PanelContainer
var _plea: RichTextLabel
var _plea_hint: Label
var _plea_tween: Tween


var _stuck_for:= 0.0


var _best_have:= - INF
var _pleas:= 0
var _breath_t:= 0.0
var _step_label: Label
var _title: Label


var _detail: RichTextLabel
var _keycap: PanelContainer
var _keycap_label: Label


var _keycap_icon: TextureRect
var _reward: Label
var _done_label: Label
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _progress_label: Label

var _shown:= -1


var _keys:= ""
var _hold:= 0.0


var _shown_for:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	if not in_yard.is_valid():
		in_yard = _in_yard


	InputSetup.changed.connect(_restate)


	Cfg.no_hud_changed.connect(_set_plate)


	Cfg.hud_style_changed.connect(_apply_hud_scale)
	_apply_hud_scale()


	Cfg.show_missions_changed.connect(_set_plate)
	_set_plate()


func _set_plate(_on: bool = false) -> void:
	_panel.visible = not Cfg.no_hud and Cfg.show_missions
	if not _panel.visible:
		_hush()


func _apply_hud_scale() -> void:
	scale = Vector2.ONE * clampf(Cfg.hud_scale, Cfg.HUD_SCALE_MIN, Cfg.HUD_SCALE_MAX)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(MARGIN, MARGIN)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.size = Vector2(PANEL_W, 0)

	var sb:= StyleBoxFlat.new()


	sb.bg_color = Color(0.04, 0.05, 0.07, 0.66)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.4)
	sb.set_border_width_all(1)
	sb.border_width_left = 3


	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", sb)
	_plate_sb = sb
	add_child(_panel)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_step_label = _label("", 12, COL_DIM, true)
	box.add_child(_step_label)

	var head:= HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)

	_title = _label("", 19, COL_TITLE, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)

	_keycap = _build_keycap()
	head.add_child(_keycap)
	_keycap_icon = TextureRect.new()
	_keycap_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_keycap_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_keycap_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_keycap_icon.visible = false
	head.add_child(_keycap_icon)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true


	_detail.fit_content = true
	_detail.scroll_active = false


	_detail.clip_contents = false
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.custom_minimum_size = Vector2(PANEL_W - 28.0, 0)
	UiFont.style_rich(_detail, 13, COL_TEXT, 3)


	_detail.add_theme_constant_override("line_separation", 2)
	box.add_child(_detail)


	_reward = _label("", 14, COL_REWARD, true)
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward.visible = false
	box.add_child(_reward)


	_bar_back = ColorRect.new()
	_bar_back.color = Color(1, 1, 1, 0.13)
	_bar_back.custom_minimum_size = Vector2(0, 5)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill = ColorRect.new()
	_bar_fill.color = COL_TITLE
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE


	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_bottom = 1.0
	_bar_fill.offset_left = 0.0
	_bar_fill.offset_top = 0.0
	_bar_fill.offset_right = 0.0
	_bar_fill.offset_bottom = 0.0
	_bar_back.add_child(_bar_fill)
	box.add_child(_bar_back)

	_progress_label = _label("", 13, COL_TITLE, true)
	box.add_child(_progress_label)
	_set_progress_visible(false)

	_done_label = _label("", 14, COL_DONE, true)
	_done_label.visible = false
	box.add_child(_done_label)

	_build_bubble()


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.position = Vector2(MARGIN + PANEL_W + BUBBLE_GAP, MARGIN)
	_bubble.custom_minimum_size = Vector2(BUBBLE_W, 0)
	_bubble.visible = false
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.82)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 11.0
	_bubble.add_theme_stylebox_override("panel", sb)
	add_child(_bubble)


	var tail_y:= 24.0
	var edge:= Polygon2D.new()
	edge.color = sb.border_color
	edge.polygon = PackedVector2Array([Vector2(0, tail_y - 9), Vector2(- TAIL, tail_y),
		Vector2(0, tail_y + 9)])
	_bubble.add_child(edge)
	var fill:= Polygon2D.new()


	fill.color = Color(sb.bg_color, 1.0)
	fill.polygon = PackedVector2Array([Vector2(2.5, tail_y - 6.5), Vector2(- TAIL + 3.2, tail_y),
		Vector2(2.5, tail_y + 6.5)])
	_bubble.add_child(fill)

	_bubble.pivot_offset = Vector2(- TAIL, tail_y)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(box)

	_plea = RichTextLabel.new()
	_plea.bbcode_enabled = true
	_plea.fit_content = true
	_plea.scroll_active = false


	_plea.clip_contents = false
	_plea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plea.custom_minimum_size = Vector2(BUBBLE_W - 28.0, 0)


	_plea.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	UiFont.style_rich(_plea, 15, COL_TEXT, 3, true)
	_plea.add_theme_constant_override("line_separation", 2)
	box.add_child(_plea)

	_plea_hint = _label("", 12, COL_DIM)
	_plea_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plea_hint.custom_minimum_size = Vector2(BUBBLE_W - 28.0, 0)
	box.add_child(_plea_hint)


func _build_keycap() -> PanelContainer:
	var cap:= PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb:= StyleBoxFlat.new()


	sb.bg_color = Color(0.92, 0.93, 0.96, 0.9)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 4.0
	cap.add_theme_stylebox_override("panel", sb)


	_keycap_label = Label.new()
	UiFont.style(_keycap_label, 14, Color(0.06, 0.07, 0.1), 0, true)
	_keycap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(_keycap_label)
	return cap


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()


	UiFont.style(l, size, colour, 3, heavy)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func mark_complete(_id: String) -> void:
	if not visible:
		return
	_hush()
	_done_label.text = tr("done")
	_done_label.visible = true
	_title.add_theme_color_override("font_color", COL_DONE)
	_hold = TICK_HOLD


	if _panel.visible:
		Audio.play("ui_select", -6.0)


func show_step(index: int) -> void:
	if _hold > 0.0:
		return
	if index < 0 or index >= MissionBook.count():


		visible = false
		_shown = index
		_shown_for = 0.0
		_forget_stuck()
		return
	if index == _shown:


		if MissionBook.keys_of(index) != _keys:
			_restate()

			_stuck_for = 0.0
			_hush()
		return
	_shown = index
	_shown_for = 0.0
	_forget_stuck()
	_step_label.text = tr("STEP %d OF %d") % [index + 1, MissionBook.count()]
	_title.add_theme_color_override("font_color", COL_TITLE)
	_restate()
	_done_label.visible = false


	_set_progress_visible(false)
	visible = true


func _restate() -> void:
	if _shown < 0 or _title == null:
		return
	_title.text = MissionBook.say(_shown, "title")


	var detail:= MissionBook.say_rich(_shown, "detail")
	_detail.text = detail
	_detail.visible = detail != ""
	var reward:= MissionBook.reward_text(_shown)
	_reward.text = reward
	_reward.visible = reward != ""


	_keys = MissionBook.keys_of(_shown)
	var keys:= MissionBook.expand(_keys)


	var art: AtlasTexture = null
	var action:= MissionBook.cue_action(_shown)
	if _keys.strip_edges() == "{%s}" % action:
		art = InputIcons.of_spec(InputSetup.spec_of(action), true)
	_keycap_icon.texture = art
	if art != null:


		_keycap_icon.custom_minimum_size = art.region.size * (BADGE_W / InputIcons.KEY_W)
	_keycap_icon.visible = art != null
	_keycap.visible = keys != "" and art == null
	_keycap_label.text = keys


func show_progress(p: Dictionary) -> void:
	if p.is_empty() or not visible or _hold > 0.0:
		_set_progress_visible(false)
		return
	_set_progress_visible(true)
	_progress_label.text = str(p.get("text", ""))

	_progress_label.visible = _progress_label.text != ""
	var need:= maxf(float(p.get("need", 1.0)), 0.0001)
	var have:= float(p.get("have", 0.0))
	_bar_fill.anchor_right = clampf(have / need, 0.0, 1.0)


	if _best_have == - INF:
		_best_have = have
	elif have > _best_have:
		_best_have = have
		_stuck_for = 0.0
		_hush()


func _set_progress_visible(on: bool) -> void:
	if _bar_back != null:
		_bar_back.visible = on
	if _progress_label != null:
		_progress_label.visible = on


func bottom_edge() -> float:
	if not visible or _panel == null or not _panel.visible:
		return 0.0
	return _panel.position.y + _panel.size.y


func showing() -> int:
	return _shown if visible and _hold <= 0.0 else -1


func seconds_shown(index: int) -> float:
	return _shown_for if _shown == index and visible and _hold <= 0.0 else 0.0


func _process(delta: float) -> void:
	_tick_stuck(delta)
	if _hold <= 0.0:
		_shown_for += delta
		return
	_hold = maxf(0.0, _hold - delta)
	if _hold <= 0.0:


		_shown = -1
		_shown_for = 0.0


func _tick_stuck(delta: float) -> void:
	var counting:= visible and _panel.visible and _hold <= 0.0 and _shown >= 0 and MissionBook.pleads(_shown) and bool(in_yard.call())
	if counting:
		_stuck_for += delta


	var lonely:= _bubble.visible or (counting and _pleas < PLEAS_PER_STEP
		and _stuck_for >= LONELY_AFTER)
	if lonely:
		_breath_t += delta
		var k:= 0.5 - 0.5 * cos(_breath_t * TAU / BREATH_PERIOD)
		_plate_sb.border_color.a = lerpf(RULE_ALPHA, RULE_ALPHA_LONELY, k)
	elif _breath_t != 0.0:
		_breath_t = 0.0
		_plate_sb.border_color.a = RULE_ALPHA
	if counting and _pleas < PLEAS_PER_STEP and _stuck_for >= PLEAD_AFTER:
		_plead()


func _plead() -> void:
	_hush()
	_pleas += 1
	_stuck_for = 0.0
	var note:= tr("You haven't finished this mission in a while.")
	_plea.text = _escape(note)
	_plea.visible_characters = 0


	_plea_hint.text = tr("If you want, you can hide missions in %s > %s.") % [tr("OPTIONS"), tr("GAMEPLAY")]
	_plea_hint.modulate.a = 0.0
	_bubble.modulate.a = 0.0
	_bubble.scale = Vector2.ONE
	_bubble.visible = true


	_plea_tween = create_tween()
	_plea_tween.tween_property(_bubble, "modulate:a", 1.0, 0.3)
	_plea_tween.tween_property(_plea, "visible_characters", note.length(),
		note.length() / TYPE_RATE)
	_plea_tween.tween_property(_plea_hint, "modulate:a", 1.0, 0.4)
	_plea_tween.tween_interval(PLEA_HOLD)
	_plea_tween.tween_property(_bubble, "modulate:a", 0.0, PLEA_FADE)
	_plea_tween.tween_callback(func() -> void: _bubble.visible = false)


func _hush() -> void:
	if _plea_tween != null:
		_plea_tween.kill()
		_plea_tween = null
	if _bubble != null:
		_bubble.visible = false


func _forget_stuck() -> void:
	_stuck_for = 0.0
	_best_have = - INF
	_pleas = 0
	_hush()


func _in_yard() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus()


func _escape(s: String) -> String:
	return s.replace("[", "[lb]")
