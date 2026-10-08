class_name FillCount
extends Node3D


const SHOW_RANGE:= 4.5
const HIDE_RANGE:= 6.0


const SIZE:= 34
const OUTLINE:= 9
const PEAK_ALPHA:= 0.9

var _label: Label3D
var _box: HayContainer
var _player: Node3D
var _shown:= ""


static func attach(box: HayContainer) -> FillCount:
	var count:= box.get_node_or_null("FillCount") as FillCount
	if count == null:
		count = FillCount.new()
		count.name = "FillCount"
		box.add_child(count)
	return count


func _ready() -> void:
	_box = get_parent() as HayContainer
	_label = Label3D.new()
	_label.name = "Count"
	_label.font = UiFont.bold()
	_label.font_size = SIZE
	_label.outline_size = OUTLINE
	_label.modulate = FullBadge.INK
	_label.outline_modulate = FullBadge.EDGE
	_label.pixel_size = FullBadge.PIXEL_SIZE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.shaded = false
	_label.double_sided = true
	_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	_label.visible = false
	add_child(_label)


func _process(_delta: float) -> void:
	if _box == null or _label == null:
		return
	var a:= strength()
	if a <= 0.0:
		_label.visible = false
		return
	var text:= "%d / %d" % [_box.stored, _box.capacity()]
	if text != _shown:
		_shown = text
		_label.text = text
	position = _box.badge_point()
	_label.modulate = Color(FullBadge.INK.r, FullBadge.INK.g, FullBadge.INK.b, a * PEAK_ALPHA)
	_label.outline_modulate = Color(FullBadge.EDGE.r, FullBadge.EDGE.g, FullBadge.EDGE.b,
		a * PEAK_ALPHA)
	_label.visible = true


func strength() -> float:
	if _box == null or not _box.is_inside_tree():
		return 0.0
	if _box.is_held() and _box.carry_mode() == Carryable.Mode.HELD:
		return 0.0
	var badge:= _box.get_node_or_null("FullBadge/Mark") as Label3D
	if badge != null and badge.visible:
		return 0.0
	var who:= _find_player()
	if who == null:
		return 0.0
	var flat:= who.global_position - _box.global_position
	flat.y = 0.0
	return range_strength(flat.length())


static func range_strength(away: float) -> float:
	return 1.0 - smoothstep(SHOW_RANGE, HIDE_RANGE, away)


func shown_text() -> String:
	return _label.text if _label != null and _label.visible else ""


func _find_player() -> Node3D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player
