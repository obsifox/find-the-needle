class_name ObjectiveMarker
extends Control


const COL:= Color(1.0, 1.0, 1.0)
const COL_INK:= Color(0.19, 0.13, 0.06)
const COL_SHADOW:= Color(0.0, 0.0, 0.0, 0.32)

const BADGE_R:= 21.0
const ICON_PX:= 24.0


const TAIL_H:= 11.0
const TAIL_W:= 16.0


const BOB_PX:= 4.0
const BOB_HZ:= 0.9

const EDGE_INSET:= 80.0

const EDGE_TOP:= 0.22
const EDGE_BOTTOM:= 0.74


const NEAR:= 2.5
const FADE:= 2.0

const PULSE_S:= 1.6
const PULSE_PX:= 22.0

var missions: MissionDirector
var player: Player

var _t:= 0.0
var _alpha:= 0.0

var _at:= Vector2.ZERO
var _dir:= Vector2.DOWN

var _edge:= false
var _metres:= 0
var _icon:= ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible = false


func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, _aim(), delta * 4.0)
	visible = _alpha > 0.0
	if visible:
		queue_redraw()


func _aim() -> float:
	if missions == null or player == null or Cfg.no_hud or not Cfg.show_missions:
		return 0.0


	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return 0.0
	var spot: Variant = missions.marker_point()
	if not (spot is Vector3):
		return 0.0
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	_icon = missions.marker_icon()
	var point:= spot as Vector3
	var metres:= player.global_position.distance_to(point)
	_metres = int(round(metres))
	var view:= get_viewport_rect().size
	var inset:= EDGE_INSET * view.y / 1080.0
	var behind:= cam.is_position_behind(point)
	var s:= cam.unproject_position(point)
	if not behind and Rect2(Vector2(inset, inset), view - Vector2(inset, inset) * 2.0).has_point(s):
		_edge = false
		_at = s
		return clampf((metres - NEAR) / FADE, 0.0, 1.0)


	_edge = true
	var centre:= view * 0.5
	var d:= s - centre
	if behind:
		var local:= cam.global_transform.affine_inverse() * point
		d = Vector2(1.0 if local.x >= 0.0 else -1.0, 0.0)
	if d.length_squared() < 1.0:
		d = Vector2.RIGHT
	_dir = d.normalized()
	var half:= centre - Vector2(inset, inset)
	var k:= minf(half.x / maxf(absf(_dir.x), 0.0001), half.y / maxf(absf(_dir.y), 0.0001))
	_at = centre + _dir * k


	_at.y = clampf(_at.y, view.y * EDGE_TOP, view.y * EDGE_BOTTOM)
	return 1.0


func _draw() -> void:
	var px:= get_viewport_rect().size.y / 1080.0
	var bob:= (sin(_t * TAU * BOB_HZ) * 0.5 + 0.5) * BOB_PX * px
	var label:= tr("%d m") % _metres
	var reach:= (BADGE_R + TAIL_H) * px
	if _edge:


		var tip:= _at + _dir * bob
		var centre:= tip - _dir * reach
		_badge(centre, _dir, px)


		_text(label, centre + Vector2(0.0, (BADGE_R + 14.0) * px), px)
		return

	var phase:= fmod(_t, PULSE_S) / PULSE_S
	var ring:= COL
	ring.a *= (1.0 - phase) * 0.7 * _alpha
	draw_arc(_at, (4.0 + PULSE_PX * phase) * px, 0.0, TAU, 40, ring, 2.0 * px, true)
	var dot:= COL
	dot.a *= _alpha
	draw_circle(_at, 3.0 * px, dot, true, -1.0, true)
	var centre:= _at - Vector2(0.0, reach + 8.0 * px + bob)
	_badge(centre, Vector2.DOWN, px)
	_text(label, centre - Vector2(0.0, (BADGE_R + 14.0) * px), px)


func _badge(centre: Vector2, dir: Vector2, px: float) -> void:
	var r:= BADGE_R * px
	var side:= Vector2(- dir.y, dir.x) * TAIL_W * 0.5 * px

	var root:= centre + dir * r * 0.7
	var tail:= PackedVector2Array([centre + dir * (r + TAIL_H * px), root + side, root - side])

	for layer in 2:
		var grow:= (1.0 + layer * 1.5) * px
		var shade:= COL_SHADOW
		shade.a *= _alpha * (0.6 if layer == 0 else 0.4)
		var off:= Vector2(0.0, (2.0 + layer) * px)
		draw_circle(centre + off, r + grow, shade, true, -1.0, true)
		var shadow_tail:= PackedVector2Array()
		for p in tail:
			shadow_tail.append(p + off + (p - centre).normalized() * grow)
		draw_colored_polygon(shadow_tail, shade)
	var face:= COL
	face.a *= _alpha
	draw_colored_polygon(tail, face)
	draw_circle(centre, r, face, true, -1.0, true)
	if _icon == "":
		var core:= COL_INK
		core.a *= _alpha
		draw_circle(centre, r * 0.28, core, true, -1.0, true)
		return
	var size:= ICON_PX * px
	var tex:= PlateIcons.texture(_icon, int(round(size)))
	if tex == null:
		return
	var ink:= COL_INK
	ink.a *= _alpha
	draw_texture_rect(tex, Rect2(centre - Vector2(size, size) * 0.5, Vector2(size, size)),
		false, ink)


func _text(text: String, at: Vector2, px: float) -> void:
	var font:= UiFont.bold()
	var size:= int(round(19.0 * px))
	var w:= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos:= at + Vector2(- w * 0.5, size * 0.35)
	var rim:= COL_INK
	rim.a *= 0.8 * _alpha
	var col:= COL
	col.a *= _alpha
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		int(round(4.0 * px)), rim)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
