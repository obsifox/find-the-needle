class_name DemoPlate
extends PanelContainer


const TIP_FIRST:= 60.0
const TIP_SECONDS:= 20.0
const TIP_EVERY:= 60.0

const FADE:= 0.28
const RESIZE:= 0.32


const TIP_MAX_W:= 560.0
const TIP_HEAD_SIZE:= 17
const TIP_SIZE:= 16
const COL_TIP_HEAD:= Color(1.0, 0.86, 0.34, 0.85)
const COL_TIP:= Color(0.96, 0.97, 0.94, 0.9)
const COL_TIMER:= Color(1.0, 0.86, 0.34, 0.55)
const TIMER_H:= 2.0

const BUILD_SIZE:= 13
const BUILD_GAP:= 12
const COL_BUILD:= Color(0.96, 0.97, 0.94, 0.5)

enum Face { STAMP, TIP }


var stamp: Control


var build_name:= ""

var warning: PowerWarning

var _stage: Control
var _tip: VBoxContainer
var _tip_head: Label
var _tip_text: Label

var _face:= Face.STAMP
var _want:= Face.STAMP

var _alpha:= 1.0

var _grow:= 1.0
var _grow_from:= Vector2.ZERO
var _grow_to:= Vector2.ZERO

var _until_tip:= TIP_FIRST
var _tip_left:= 0.0
var _bag: Array [int] = []
var _rng:= RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_timer)
	add_child(_stage)
	if stamp == null:
		stamp = Control.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(stamp)

	_tip = VBoxContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_constant_override("separation", 0)
	_tip.visible = false
	_stage.add_child(_tip)


	_tip_head = Label.new()
	_tip_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_head.text = tr("TIP")
	_tip_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_head.add_theme_font_override("font", UiFont.watermark())
	_tip_head.add_theme_font_size_override("font_size", TIP_HEAD_SIZE)
	_tip_head.add_theme_color_override("font_color", COL_TIP_HEAD)
	_tip_head.add_theme_constant_override("outline_size", 0)
	_tip.add_child(_tip_row(_tip_head))

	_tip_text = Label.new()
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_text.add_theme_font_override("font", UiFont.regular())
	_tip_text.add_theme_font_size_override("font_size", TIP_SIZE)
	_tip_text.add_theme_color_override("font_color", COL_TIP)
	_tip_text.add_theme_constant_override("outline_size", 0)
	_tip.add_child(_tip_text)

	_stage.custom_minimum_size = _content_size(Face.STAMP)


func _tip_row(head: Label) -> Control:
	if build_name == "":
		return head
	var build:= Label.new()
	build.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build.text = build_name
	build.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	build.add_theme_font_override("font", UiFont.watermark())
	build.add_theme_font_size_override("font_size", BUILD_SIZE)
	build.add_theme_color_override("font_color", COL_BUILD)
	build.add_theme_constant_override("outline_size", 0)

	var spacer:= Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE


	spacer.custom_minimum_size.x = ceilf(UiFont.watermark().get_string_size(
			build_name, HORIZONTAL_ALIGNMENT_LEFT, -1, BUILD_SIZE).x)

	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row:= HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", BUILD_GAP)
	row.add_child(spacer)
	row.add_child(head)
	row.add_child(build)
	return row


func _process(delta: float) -> void:
	step(delta, Cfg.show_tips, warning != null and warning.is_up())


func step(delta: float, tips_on: bool, warning_up: bool) -> void:
	if _want == Face.TIP:


		if _face == Face.TIP and _alpha >= 1.0:
			_tip_left -= delta
		if _tip_left <= 0.0 or not tips_on or warning_up:
			_want = Face.STAMP
			_until_tip = TIP_EVERY - TIP_SECONDS
	elif _face == Face.STAMP:
		_until_tip -= delta
		if _until_tip <= 0.0 and tips_on and not warning_up:
			var next:= _next_tip()
			if next >= 0:
				show_tip(next)
			else:
				_until_tip = TIP_EVERY

	_animate(delta)


func show_tip(i: int) -> void:
	_tip_text.text = _wrap(GameTips.say(i))
	_tip_left = TIP_SECONDS
	_want = Face.TIP


func showing_tip() -> String:
	return _tip_text.text.replace("\n", " ") if _face == Face.TIP and _want == Face.TIP else ""


func next_tip_in() -> float:
	return maxf(_until_tip, 0.0) if _want == Face.STAMP else 0.0


func _next_tip() -> int:
	return GameTips.draw(_bag, _rng)


func _animate(delta: float) -> void:
	if _want != _face:

		_alpha = maxf(_alpha - delta / FADE, 0.0)
		if _alpha <= 0.0:
			_node_of(_face).visible = false
			_face = _want
			_node_of(_face).visible = true
			_grow_from = _stage.custom_minimum_size
			_grow_to = _content_size(_face)
			_grow = 0.0
	elif _grow < 1.0:
		_grow = minf(_grow + delta / RESIZE, 1.0)
		var t:= smoothstep(0.0, 1.0, _grow)
		_stage.custom_minimum_size = _grow_from.lerp(_grow_to, t).round()
	else:
		_alpha = minf(_alpha + delta / FADE, 1.0)

	for face: Face in [Face.STAMP, Face.TIP]:
		var node:= _node_of(face)
		var want:= node.get_combined_minimum_size()
		node.size = want
		node.position = ((_stage.size - want) * 0.5).floor()
	_node_of(_face).modulate.a = _alpha
	if _face == Face.TIP:
		_stage.queue_redraw()


func _node_of(face: Face) -> Control:
	return _tip if face == Face.TIP else stamp


func _content_size(face: Face) -> Vector2:
	var node:= _node_of(face)
	return Vector2.ZERO if node == null else node.get_combined_minimum_size()


func _wrap(text: String) -> String:
	if _text_w(text) <= TIP_MAX_W:
		return text
	if UiFont.unspaced(text):
		return _wrap_unspaced(text)


	var words:= text.split(" ")
	var best:= text
	var best_w:= INF
	for i in range(1, words.size()):
		var first:= " ".join(words.slice(0, i))
		var second:= " ".join(words.slice(i))
		var longer:= maxf(_text_w(first), _text_w(second))
		if longer < best_w:
			best_w = longer
			best = first + "\n" + second
	return best


const _CLAUSE_BONUS:= 24.0


func _wrap_unspaced(text: String) -> String:
	var best:= text
	var best_score:= INF
	for i in range(1, text.length()):
		if not UiFont.can_break(text, i):
			continue
		var first:= text.substr(0, i).strip_edges()
		var second:= text.substr(i).strip_edges()
		var score:= maxf(_text_w(first), _text_w(second))
		if not UiFont.clause_break(text, i):
			score += _CLAUSE_BONUS
		if score < best_score:
			best_score = score
			best = first + "\n" + second
	return best


func _text_w(s: String) -> float:
	return UiFont.regular().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_SIZE).x


func _draw_timer() -> void:
	if _face != Face.TIP or _want != Face.TIP:
		return
	var box:= get_theme_stylebox("panel")
	var left:= box.content_margin_left if box != null else 0.0
	var right:= box.content_margin_right if box != null else 0.0
	var bottom:= box.content_margin_bottom if box != null else 0.0
	var full:= _stage.size.x + left + right
	var share:= clampf(_tip_left / TIP_SECONDS, 0.0, 1.0)
	var col:= Color(COL_TIMER, COL_TIMER.a * _alpha)
	_stage.draw_rect(Rect2(- left, _stage.size.y + bottom - TIMER_H, full * share, TIMER_H), col)
