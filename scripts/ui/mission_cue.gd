class_name MissionCue
extends Control


const TOP:= 196.0
const HEIGHT:= 318.0


const ICON:= 160.0


const HOLD:= 5.0
const GAP:= 2.4

const FADE:= 0.32


const PULSE:= 1.15
const PULSE_DEPTH:= 0.15


const SWAY:= 0.13
const SWAY_PERIOD:= 1.7


const SLIDE:= 15.0

const COL_VERB:= Color(1, 1, 1, 0.72)
const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_COUNT:= Color(0.94, 0.95, 0.98)


const COL_NOTE:= Color(0.88, 0.91, 0.97, 0.8)

var _root: VBoxContainer
var _verb: Label
var _stage: Control
var _icon: TextureRect
var _cap_box: CenterContainer
var _cap: Label
var _title: Label
var _note: Label
var _count: Label


var _art: Array [AtlasTexture] = []
var _caps: PackedStringArray = PackedStringArray()


var _verbs: PackedStringArray = PackedStringArray()


var _shown:= -1


var _keys:= ""

var _t:= 0.0
var _sway:= false


var _shows:= 0
var _limit:= 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_top = TOP
	offset_bottom = TOP + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


	InputSetup.changed.connect(_restate)


	Cfg.no_hud_changed.connect(_set_plate)


	Cfg.show_missions_changed.connect(_set_plate)
	_set_plate()


	Cfg.hud_style_changed.connect(_apply_hud_scale)


	resized.connect(_apply_hud_scale)
	_apply_hud_scale()


	visibility_changed.connect(func() -> void:
		if visible:
			_t = 0.0)


func _set_plate(_on: bool = false) -> void:
	_root.visible = not Cfg.no_hud and Cfg.show_missions


func _apply_hud_scale() -> void:
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	scale = Vector2.ONE * clampf(Cfg.hud_scale, Cfg.HUD_SCALE_MIN, Cfg.HUD_SCALE_MAX)


func _build() -> void:
	_root = VBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_theme_constant_override("separation", 6)
	add_child(_root)

	_verb = _label("", 18, COL_VERB, true)
	_verb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_verb)


	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(ICON, ICON)
	_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(_stage)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stage.add_child(_icon)


	_cap_box = CenterContainer.new()
	_cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cap_box.visible = false
	_stage.add_child(_cap_box)
	_cap_box.add_child(_draw_key())

	_title = _label("", 24, COL_TITLE, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)


	_note = _label("", 16, COL_NOTE)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.visible = false
	_root.add_child(_note)

	_count = _label("", 21, COL_COUNT, true)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.visible = false
	_root.add_child(_count)


func _draw_key() -> PanelContainer:
	var box:= PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.96, 0.98, 0.94)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	box.add_theme_stylebox_override("panel", sb)
	_cap = _label("", 56, Color(0.06, 0.07, 0.1), true)
	box.add_child(_cap)
	return box


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 4, heavy)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func show_step(index: int) -> void:


	if index >= 0 and MissionBook.has_cue(index) and InputSetup.spec_of(MissionBook.cue_action(index)) == "" and InputSetup.spec_of(MissionBook.cue_alt_action(index)) == "":
		if _shown != -1:
			_shown = -1
			visible = false
		return
	if not MissionBook.has_cue(index):
		if _shown != -1:
			_shown = -1
			visible = false
		return
	if index == _shown:


		if MissionBook.keys_of(index) != _keys:
			_t = 0.0
			_shows = 0
			_restate()
			visible = true
		return
	_shown = index


	_t = 0.0
	_shows = 0
	_limit = MissionBook.cue_repeat(index)
	_restate()
	visible = true


func show_progress(p: Dictionary) -> void:
	if _count == null:
		return
	_count.text = str(p.get("text", ""))
	_count.visible = _count.text != ""


func _restate() -> void:
	if _shown < 0:
		return
	var s:= MissionBook.step(_shown)
	_keys = MissionBook.keys_of(_shown)
	var action:= MissionBook.cue_action(_shown)
	_sway = bool(s.get("cue_sway", false))


	var press:= tr("HOLD", "key cue verb") if bool(s.get("cue_hold", false)) else tr("PRESS", "key cue verb")
	_verb.text = press


	_title.text = MissionBook.say(_shown, "title")
	_note.text = MissionBook.say(_shown, "cue_note")
	_note.visible = _note.text != ""


	_art.clear()
	_caps.clear()
	_verbs.clear()
	for want_mouse: bool in [true, false]:
		for a: String in [action, MissionBook.cue_alt_action(_shown)]:
			if a == "":
				continue
			for spec: String in InputSetup.specs_of(a):
				if spec.begins_with("mouse:") != want_mouse:
					continue
				_art.append(InputIcons.of_spec(spec))
				_caps.append(InputSetup.spec_label(spec))


				_verbs.append(tr("ROLL") if InputIcons.is_wheel(spec) else press)
	_frame(0.0)


func _frame(lift: float) -> void:
	if _art.is_empty():
		return
	var pairs:= int(ceil(_art.size() / 2.0))
	var which:= (_shows % pairs) * 2 if pairs > 1 else 0
	if _art.size() > 1 and lift > 0.0:
		which += 1
	which = mini(which, _art.size() - 1)
	_verb.text = _verbs [which]
	var art:= _art [which]
	_icon.texture = art
	_icon.visible = art != null
	_cap_box.visible = art == null
	if art == null:
		_cap.text = _caps [which]
	var slide:= SLIDE * lift if _art.size() > 1 else 0.0
	_icon.position.y = slide
	_cap_box.position.y = slide


func _process(delta: float) -> void:


	if not visible or _shown < 0:
		return


	_t += delta
	if _t >= HOLD + GAP:
		_t -= HOLD + GAP
		_shows += 1
	if _spent():
		visible = false
		return
	_root.modulate.a = _alpha()


	_stage.pivot_offset = _stage.size * 0.5
	_stage.scale = Vector2.ONE * (1.0 + PULSE_DEPTH * sin(TAU * _t / PULSE))
	_stage.rotation = SWAY * sin(TAU * _t / SWAY_PERIOD) if _sway else 0.0


	_frame(- cos(TAU * _t / PULSE))


func _spent() -> bool:
	return _limit > 0 and _shows >= _limit


func _alpha() -> float:
	if _t >= HOLD:
		return 0.0
	if _t < FADE:
		return _t / FADE
	if _t > HOLD - FADE:
		return (HOLD - _t) / FADE
	return 1.0
