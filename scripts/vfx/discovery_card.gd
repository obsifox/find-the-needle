class_name DiscoveryCard
extends Control


const REF_H:= 1080.0
const CARD_W:= 320.0
const CARD_H:= 620.0
const BURST:= 900.0


const T_LINE:= 0.14
const T_OPEN:= 0.2


const T_BURST:= 0.16
const T_BURST_SETTLE:= 0.95
const T_SPECIMEN:= 0.38
const T_TEXT:= 0.56
const T_TEXT_STEP:= 0.1
const T_HINT:= 1.6

const T_HOLD:= 4.2
const T_FADE:= 0.45


const SPIN_FAST:= 210.0
const SPIN_IDLE:= 9.0
const BURST_IN:= 1.75

const COL_DIM:= Color(0.02, 0.02, 0.03)
const DIM_ALPHA:= 0.55
const COL_CARD:= Color(0.07, 0.06, 0.05, 0.9)
const COL_EDGE:= Color(0.86, 0.72, 0.34)
const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_NAME:= Color(1.0, 0.97, 0.9)
const COL_SUB:= Color(0.84, 0.86, 0.92)
const COL_HINT:= Color(0.78, 0.8, 0.86)

signal inspect_requested(type: int)

var _type:= -1
var _tint:= Color.WHITE
var _t:= 0.0
var _running:= false
var _fading:= 0.0

var _burst: TextureRect
var _view: NeedleView
var _name: Label
var _odds: Label
var _worth: Label
var _title: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func _build() -> void:
	_burst = TextureRect.new()
	_burst.name = "Burst"
	_burst.texture = load("res://assets/ui/effect_cream.png") as Texture2D
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE


	var add:= CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_burst.material = add
	add_child(_burst)

	_view = NeedleView.new()
	_view.name = "Specimen"
	add_child(_view)

	_title = _label(34, COL_TITLE, true)
	_name = _label(58, COL_NAME, true)
	_odds = _label(28, COL_SUB, false)
	_worth = _label(30, COL_TITLE, false)
	_hint = _label(24, COL_HINT, false)


func _label(size: int, colour: Color, heavy: bool) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 6, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l


func play(type: int) -> void:
	_type = type
	_tint = NeedleCabinet.type_colour(type)
	_t = 0.0
	_fading = 0.0
	_running = true
	visible = true
	set_process(true)
	_view.set_type(type)
	_view.yaw = 0.0
	_view.spin = NeedleView.IDLE_SPIN
	_title.text = tr("NEW NEEDLE")
	_name.text = NeedleTypes.name_of(type)


	_odds.text = tr("CHANCE 1 IN %d") % NeedleTypes.one_in(type)


	if NeedleTypes.has_effect(type):
		_worth.text = Cfg.upper(NeedleTypes.effect_text(type))
	else:
		_worth.text = tr("ADDED TO THE CASE")
	_hint.text = tr("F  ·  TURN IT OVER")
	Audio.play("needle_reveal", -3.0)


func is_playing() -> bool:
	return _running


func dismiss() -> void:
	if _running and _fading <= 0.0:
		_fading = 0.001


func _unhandled_input(event: InputEvent) -> void:
	if not _running or _fading > 0.0:
		return
	if event.is_action_pressed("inspect_needle"):
		inspect_requested.emit(_type)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if _fading > 0.0:
		_fading += delta
	elif _t >= T_HOLD:
		_fading = 0.001
	if _fading > T_FADE:
		_running = false
		visible = false
		set_process(false)
		return
	_layout()
	queue_redraw()


func _layout() -> void:
	var s:= size.y / REF_H
	var mid:= size * 0.5
	var fade:= 1.0 - (smoothstep(0.0, T_FADE, _fading) if _fading > 0.0 else 0.0)


	var bt:= clampf((_t - T_BURST) / T_BURST_SETTLE, 0.0, 1.0)
	var k:= smoothstep(0.0, 1.0, bt)
	var burst_side:= BURST * s * lerpf(BURST_IN, 1.0, k)
	_burst.size = Vector2(burst_side, burst_side)
	_burst.pivot_offset = _burst.size * 0.5
	_burst.position = mid - _burst.size * 0.5


	var spin_now:= lerpf(SPIN_FAST, SPIN_IDLE, k)
	_burst.rotation = deg_to_rad(_spin_angle(spin_now))
	var burst_a:= 0.0 if _t < T_BURST else lerpf(0.95, 0.55, k)
	_burst.modulate = Color(_tint.r, _tint.g, _tint.b, burst_a * fade)


	var st:= clampf((_t - T_SPECIMEN) / 0.45, 0.0, 1.0)
	var sk:= smoothstep(0.0, 1.0, st)
	var view_side:= CARD_W * s * 0.88
	_view.size = Vector2(view_side, view_side * 1.35)
	_view.pivot_offset = _view.size * 0.5
	_view.position = mid - _view.size * 0.5 - Vector2(0, CARD_H * s * 0.1)
	_view.scale = Vector2.ONE * lerpf(1.35, 1.0, sk)
	_view.modulate.a = sk * fade


	var top:= mid.y - CARD_H * s * 0.5
	_place(_title, 0, top + 28.0 * s, s, fade)
	_place(_name, 1, mid.y + CARD_H * s * 0.2, s, fade)
	_place(_odds, 2, mid.y + CARD_H * s * 0.3, s, fade)
	_place(_worth, 3, mid.y + CARD_H * s * 0.36, s, fade)

	var ht:= clampf((_t - T_HINT) / 0.4, 0.0, 1.0)
	_hint.position = Vector2(0, mid.y + CARD_H * s * 0.46)
	_hint.size = Vector2(size.x, 40.0 * s)
	_hint.modulate.a = ht * fade * 0.9


func _place(l: Label, order: int, y: float, s: float, fade: float) -> void:
	var t:= clampf((_t - T_TEXT - float(order) * T_TEXT_STEP) / 0.28, 0.0, 1.0)
	var k:= smoothstep(0.0, 1.0, t)
	l.position = Vector2(0, y + (1.0 - k) * 14.0 * s)
	l.size = Vector2(size.x, 60.0 * s)
	l.modulate.a = k * fade


var _angle:= 0.0
var _last_t:= 0.0


func _spin_angle(rate: float) -> float:
	_angle += rate * (_t - _last_t)
	_last_t = _t
	return _angle


func _draw() -> void:
	if not _running:
		return
	var s:= size.y / REF_H
	var mid:= size * 0.5
	var fade:= 1.0 - (smoothstep(0.0, T_FADE, _fading) if _fading > 0.0 else 0.0)


	var dim:= smoothstep(0.0, T_LINE, _t) * DIM_ALPHA * fade
	draw_rect(Rect2(Vector2.ZERO, size), Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, dim))


	var hk:= smoothstep(0.0, 1.0, clampf(_t / T_LINE, 0.0, 1.0))
	var wk:= smoothstep(0.0, 1.0, clampf((_t - T_LINE) / T_OPEN, 0.0, 1.0))
	var h:= CARD_H * s * hk
	var w:= maxf(CARD_W * s * wk, 2.0 * s)
	var card:= Rect2(mid - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_rect(card, Color(COL_CARD.r, COL_CARD.g, COL_CARD.b, COL_CARD.a * fade))


	var edge:= Color(_tint.r, _tint.g, _tint.b, fade)
	var rule:= maxf(2.0 * s, 1.0)
	draw_rect(Rect2(card.position, Vector2(card.size.x, rule)), edge)
	draw_rect(Rect2(Vector2(card.position.x, card.end.y - rule),
		Vector2(card.size.x, rule)), edge)


	var side:= Color(COL_EDGE.r, COL_EDGE.g, COL_EDGE.b, 0.35 * fade)
	draw_rect(Rect2(card.position, Vector2(rule * 0.5, card.size.y)), side)
	draw_rect(Rect2(Vector2(card.end.x - rule * 0.5, card.position.y),
		Vector2(rule * 0.5, card.size.y)), side)
