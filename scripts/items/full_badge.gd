class_name FullBadge
extends Node3D


const WORD:= "FULL"


const NO_ROOM:= "NO ROOM"


const RISE:= 0.16
const HOLD:= 0.95
const FALL:= 0.42
const LIFE:= RISE + HOLD + FALL


const PEAK_ALPHA:= 0.92


const DRIFT:= 0.085
const GROW_FROM:= 0.88


const CLEARANCE:= 0.18


const SIZE:= 46
const PIXEL_SIZE:= 0.0013
const OUTLINE:= 10


const INK:= Color(1.0, 0.94, 0.82)
const EDGE:= Color(0.05, 0.045, 0.04)


const FULL_RANGE:= 7.0
const CUT_RANGE:= 12.0
const CUT_SCALE:= 0.5

var _label: Label3D
var _t:= 0.0

var _word:= WORD


static func flash_over(item: Node3D, at: Vector3, word: String = WORD) -> FullBadge:
	var badge:= item.get_node_or_null("FullBadge") as FullBadge
	if badge == null:
		badge = FullBadge.new()
		badge.name = "FullBadge"
		item.add_child(badge)
	badge.position = at
	badge.set_word(word)
	badge.restart()
	return badge


func set_word(word: String) -> void:
	_word = word
	if _label != null:
		_label.text = tr(word)


static func snuff_on(item: Node3D) -> void:
	var badge:= item.get_node_or_null("FullBadge") as FullBadge
	if badge != null:
		badge.snuff()


func snuff() -> void:
	_t = LIFE
	if _label != null:
		_label.visible = false
	set_process(false)


func _ready() -> void:
	_build()
	set_process(false)


func _build() -> void:
	_label = Label3D.new()


	_label.name = "Mark"
	_label.text = tr(_word)
	_label.font = UiFont.bold()
	_label.font_size = SIZE
	_label.outline_size = OUTLINE
	_label.modulate = INK
	_label.outline_modulate = EDGE
	_label.pixel_size = PIXEL_SIZE


	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.no_depth_test = true
	_label.shaded = false
	_label.double_sided = true


	_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED


	_label.render_priority = 6
	_label.outline_render_priority = 5
	_label.visible = false
	add_child(_label)


func restart() -> void:
	_t = 0.0
	if _label != null:
		_label.visible = true
	set_process(true)


func _process(delta: float) -> void:
	if _label == null:
		set_process(false)
		return
	_t += delta
	if _t >= LIFE:
		_label.visible = false
		set_process(false)
		return
	var away:= _camera_range()
	var size:= range_scale(away)
	if size <= 0.0:
		_label.visible = false
		return
	_label.visible = true
	var k:= clampf(_t / LIFE, 0.0, 1.0)


	_label.position = Vector3(0.0, DRIFT * (1.0 - pow(1.0 - k, 2.0)), 0.0)
	var grown:= smoothstep(0.0, RISE, _t)
	_label.pixel_size = PIXEL_SIZE * size * lerpf(GROW_FROM, 1.0, grown)


	var a:= alpha_at(_t) * PEAK_ALPHA
	_label.modulate = Color(INK.r, INK.g, INK.b, a)
	_label.outline_modulate = Color(EDGE.r, EDGE.g, EDGE.b, a)


static func alpha_at(t: float) -> float:
	if t <= 0.0 or t >= LIFE:
		return 0.0
	var a:= 1.0
	if t < RISE:
		a = t / RISE
	elif t > RISE + HOLD:
		a = 1.0 - (t - RISE - HOLD) / FALL
	return smoothstep(0.0, 1.0, clampf(a, 0.0, 1.0))


static func range_scale(away: float) -> float:
	if away >= CUT_RANGE:
		return 0.0
	if away <= FULL_RANGE:
		return 1.0
	return clampf(FULL_RANGE / away, CUT_SCALE, 1.0)


func _camera_range() -> float:
	if not is_inside_tree():
		return 0.0
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	return cam.global_position.distance_to(global_position)
