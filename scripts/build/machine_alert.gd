class_name MachineAlert
extends Node3D


const SIZE:= 192


const TRI:= 0.8
const RIM:= 0.058

const PLATE_HALF:= TRI
const SQRT3:= 1.7320508


const MARK_CENTRE:= Vector2(0.0, -0.23)
const MARK_SCALE:= 0.9
const SHADOW_DROP:= 0.075
const SHADOW_SOFT:= 0.17
const SHADOW_ALPHA:= 0.45


const AA:= 0.016


const MARK_DROP:= 0.035


const BADGE_PX:= 46.0


const FULL_RANGE:= 6.0
const CUT_RANGE:= 22.0
const CUT_SCALE:= 0.6
const FADE:= 5.0


const CLEARANCE:= 0.55


const BREATHE:= 0.035
const BREATHE_HZ:= 0.8


const RIPPLE_EVERY:= 2.4
const RIPPLE_LIFE:= 1.1
const RIPPLE_GROW:= 1.35
const RIPPLE_ALPHA:= 0.55

const RIPPLE_WIDTH:= 0.05


const POP_IN:= 0.38
const POP_OUT:= 0.2

const SWAP_BUMP:= 0.22


const AIMED_SCALE:= 0.42
const AIMED_RATE:= 9.0


const AIM_REACH:= 9.0


const NUDGE_GAP:= 6.0
const NUDGE_MAX:= 2.2
const NUDGE_RATE:= 14.0


const BOLT:= [
	Vector2(0.022, 0.072), Vector2(-0.01, 0.072), Vector2(-0.025, 0.012),
	Vector2(-0.003, 0.012), Vector2(-0.022, -0.072), Vector2(0.019, 0.006),
	Vector2(-0.001, 0.006)]


const BOLT_SCALE:= 4.7
const BOLT_FAT:= 0.028


const COL_HAZARD:= Color(1.0, 0.78, 0.05)


const COL_JAM:= Color(0.88, 0.2, 0.17)


const COL_WATER:= Color(0.16, 0.53, 0.91)


const COL_RIM:= Color(1.0, 0.97, 0.91)


const COL_MARK_LIGHT:= Color(1.0, 0.99, 0.97)
const COL_MARK_DARK:= Color(0.19, 0.12, 0.02)
const COL_SHADOW:= Color(0.03, 0.025, 0.02)


static var _art: Dictionary = { }


static var _live: Array [MachineAlert] = []


static var _solved_frame:= -1
static var _aimed: MachineAlert = null


static var _solved_msec:= 0
static var _solve_due:= true


static var _order: Array [MachineAlert] = []


const SOLVE_EVERY_MS:= 100


const SOLVE_MAX:= 16


const ORDER_SLACK:= 8.0


static var _overlay: Control = null


var _icon:= ""

var _age:= 0.0

var _leaving:= -1.0
var _bump:= 0.0

var _focus:= 0.0


var _drawn:= 0.0
var _alpha:= 0.0
var _ring:= -1.0
var _ring_alpha:= 0.0

var _nudge_to:= Vector2.ZERO
var _nudge:= Vector2.ZERO

var _away2:= 0.0


static func stand_over(machine: Node3D, icon: String = "") -> MachineAlert:
	var flag:= MachineAlert.new()
	flag.name = "Alert"
	flag._icon = icon
	flag.position = Vector3(0.0, _model_top(machine) + CLEARANCE, 0.0)
	machine.add_child(flag)
	return flag


func set_icon(icon: String) -> void:
	if icon == _icon:
		return
	_icon = icon
	_bump = 1.0


func icon() -> String:
	return _icon


func is_listed() -> bool:
	return _live.has(self)


func retire() -> void:
	var host:= get_parent()
	var tree:= get_tree() if is_inside_tree() else null
	var root: Node = tree.current_scene if tree != null else null
	if host == null or root == null or _drawn <= 0.0:
		if host != null:
			host.remove_child(self)
		queue_free()
		return
	var at:= global_transform
	host.remove_child(self)
	name = "RetiredAlert"
	root.add_child(self)
	global_transform = at
	_leaving = 0.0


static func _model_top(machine: Node3D) -> float:
	return maxf(0.0, MachinePower.body_box(machine).end.y)


func _enter_tree() -> void:
	if not _live.has(self):
		_live.append(self)
	_solve_due = true


func _exit_tree() -> void:
	_live.erase(self)
	_order.erase(self)
	_solve_due = true
	if _aimed == self:
		_aimed = null


func _process(delta: float) -> void:
	if Engine.get_process_frames() != _solved_frame:
		_solved_frame = Engine.get_process_frames()
		var now:= Time.get_ticks_msec()
		if _solve_due or now - _solved_msec >= SOLVE_EVERY_MS:
			_solve_due = false
			_solved_msec = now
			_solve_frame(get_viewport())

	_age += delta
	_bump = maxf(_bump - delta * 5.0, 0.0)
	_focus = move_toward(_focus, 1.0 if _aimed == self else 0.0, delta * AIMED_RATE)
	var gone:= 0.0
	if _leaving >= 0.0:
		_leaving += delta
		gone = clampf(_leaving / POP_OUT, 0.0, 1.0)
		if gone >= 1.0:
			_drawn = 0.0
			queue_free()
			return

	var away:= _camera_range()
	var size:= range_scale(away)
	if size <= 0.0 or not is_visible_in_tree():


		_drawn = 0.0
		_ring = -1.0
		return

	var clock:= float(Time.get_ticks_msec()) * 0.001
	var breath:= 1.0 + BREATHE * sin(clock * TAU * BREATHE_HZ)
	_drawn = size * breath * pop_scale(_age) * (1.0 + SWAP_BUMP * _bump * _bump) * lerpf(1.0, AIMED_SCALE, smoothstep(0.0, 1.0, _focus)) * (1.0 - gone * gone)
	_alpha = range_fade(away)


	var k:= fmod(clock, RIPPLE_EVERY) / RIPPLE_LIFE
	var quiet:= (1.0 - _focus) * smoothstep(POP_IN, POP_IN * 2.0, _age) * (1.0 - gone)
	if k < 1.0 and quiet > 0.0:
		_ring = 1.0 - pow(1.0 - k, 3.0)
		_ring_alpha = RIPPLE_ALPHA * pow(1.0 - k, 1.6) * quiet * _alpha
	else:
		_ring = -1.0

	_nudge = _nudge.lerp(_nudge_to, 1.0 - exp(- NUDGE_RATE * delta))


static func pop_scale(age: float) -> float:
	var t:= clampf(age / POP_IN, 0.0, 1.0) - 1.0
	const OVER:= 1.9
	return 1.0 + (OVER + 1.0) * t * t * t + OVER * t * t


static func range_scale(away: float) -> float:
	if away >= CUT_RANGE:
		return 0.0
	if away <= FULL_RANGE:
		return 1.0
	return clampf(FULL_RANGE / away, CUT_SCALE, 1.0)


static func range_fade(away: float) -> float:
	return clampf((CUT_RANGE - away) / FADE, 0.0, 1.0)


func _camera_range() -> float:
	if not is_inside_tree():
		return 0.0
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	return cam.global_position.distance_to(global_position)


static func _px_scale(vp: Viewport) -> float:
	return vp.get_visible_rect().size.y / 1080.0


static func _solve_frame(vp: Viewport) -> void:
	_aimed = null
	_order.clear()
	var cam:= vp.get_camera_3d() if vp != null else null
	if cam == null:
		return
	_ensure_overlay(vp)
	_aimed = _aim_at(cam)

	var eye:= cam.global_position
	var reach:= (CUT_RANGE + ORDER_SLACK) * (CUT_RANGE + ORDER_SLACK)
	for badge in _live:
		badge._nudge_to = Vector2.ZERO
		badge._away2 = eye.distance_squared_to(badge.global_position)
		if badge._away2 <= reach:
			_order.append(badge)
	_order.sort_custom(_farther)


	var px:= _px_scale(vp)
	var at: Array [Vector2] = []
	var radius: Array [float] = []
	var who: Array [MachineAlert] = []
	var k:= _order.size() - 1
	while k >= 0 and who.size() < SOLVE_MAX:
		var badge:= _order [k]
		k -= 1
		if badge._drawn <= 0.0 or badge._leaving >= 0.0:
			continue
		if cam.is_position_behind(badge.global_position):
			continue
		who.append(badge)
		at.append(cam.unproject_position(badge.global_position))
		radius.append(BADGE_PX * 0.5 * px * badge._drawn)
	var n:= who.size()
	if n < 2:
		return
	var gap:= NUDGE_GAP * px
	var push: Array [Vector2] = []
	push.resize(n)
	push.fill(Vector2.ZERO)


	for _pass in 4:
		for i in n:
			for j in range(i + 1, n):
				var d:= (at [i] + push [i]) - (at [j] + push [j])
				var need:= radius [i] + radius [j] + gap
				var dist:= d.length()
				if dist >= need:
					continue

				var dir:= d / dist if dist > 0.01 else Vector2.LEFT
				var shove:= dir * (need - dist) * 0.5
				push [i] += shove
				push [j] -= shove
	for i in n:
		who [i]._nudge_to = push [i].limit_length(radius [i] * NUDGE_MAX)


static func _farther(a: MachineAlert, b: MachineAlert) -> bool:
	return a._away2 > b._away2


static func _any_drawn() -> bool:
	for badge in _order:
		if badge._drawn > 0.0:
			return true
	return false


static func _aim_at(cam: Camera3D) -> MachineAlert:
	if _live.is_empty():
		return null
	var from:= cam.global_position
	var query:= PhysicsRayQueryParameters3D.create(from,
		from - cam.global_transform.basis.z * AIM_REACH, Cfg.L_BUILD)
	query.collide_with_areas = true
	var hit:= cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var walk:= hit.get("collider") as Node


	for _depth in 6:
		if walk == null:
			return null
		var badge:= walk.get_node_or_null("Alert") as MachineAlert
		if badge != null:
			return badge
		walk = walk.get_parent()
	return null


static func _ensure_overlay(vp: Viewport) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var tree:= vp.get_tree()
	var host: Node = tree.current_scene if tree != null and tree.current_scene != null else vp
	var layer:= CanvasLayer.new()
	layer.name = "MachineAlerts"
	layer.layer = 0
	_overlay = AlertOverlay.new()
	_overlay.name = "Badges"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.add_child(_overlay)
	host.add_child(layer)


static func _draw_all(canvas: Control) -> void:
	if _live.is_empty() or Cfg.no_hud:
		return
	var vp:= canvas.get_viewport()
	var cam:= vp.get_camera_3d() if vp != null else null
	if cam == null:
		return
	var px:= _px_scale(vp)


	var order: Array [MachineAlert] = []
	for badge in _order:
		if badge._drawn > 0.0 and badge._alpha > 0.0 and not cam.is_position_behind(badge.global_position):
			order.append(badge)

	var ring:= _ring_art()
	for badge in order:
		if badge._ring < 0.0:
			continue
		var body:= _body_colour(badge._icon)
		canvas.draw_texture_rect(ring, _plate_rect(cam, badge,
			BADGE_PX * px * badge._drawn * lerpf(1.0, RIPPLE_GROW, badge._ring)),
			false, Color(body, badge._ring_alpha))
	for badge in order:
		canvas.draw_texture_rect(_sign_art(badge._icon),
			_plate_rect(cam, badge, BADGE_PX * px * badge._drawn),
			false, Color(1.0, 1.0, 1.0, badge._alpha))


static func _plate_rect(cam: Camera3D, badge: MachineAlert, plate: float) -> Rect2:
	var centre:= cam.unproject_position(badge.global_position) + badge._nudge
	var edge:= plate / PLATE_HALF
	return Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge))


class AlertOverlay extends Control:
	var _was:= true

	func _process(_delta: float) -> void:
		var any:= MachineAlert._any_drawn()
		if any or _was:
			queue_redraw()
		_was = any

	func _draw() -> void:
		MachineAlert._draw_all(self)


static func _body_colour(icon: String) -> Color:
	if icon == "power":
		return COL_HAZARD
	if icon == "water":
		return COL_WATER
	return COL_JAM


static func _sign_art(icon: String) -> ImageTexture:
	if _art.has(icon):
		return _art [icon]
	var body:= _body_colour(icon)
	var ink:= COL_MARK_DARK if icon == "power" else COL_MARK_LIGHT
	var img:= Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, _badge_pixel(_texel(x, y), body, ink, icon))
	img.generate_mipmaps()
	var tex:= ImageTexture.create_from_image(img)
	_art [icon] = tex
	return tex


static func _ring_art() -> ImageTexture:
	if _art.has("ring"):
		return _art ["ring"]
	var img:= Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var outer:= _plate_sharp(_texel(x, y))
			var d:= absf(outer - RIPPLE_WIDTH * 0.5) - RIPPLE_WIDTH * 0.5
			var a:= 1.0 - smoothstep(- AA, AA, d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	var tex:= ImageTexture.create_from_image(img)
	_art ["ring"] = tex
	return tex


static func _texel(x: int, y: int) -> Vector2:
	return Vector2(
		(float(x) + 0.5) / float(SIZE) * 2.0 - 1.0,
		1.0 - (float(y) + 0.5) / float(SIZE) * 2.0)


static func _badge_pixel(p: Vector2, body: Color, ink: Color, icon: String) -> Color:
	var outer:= _plate_sharp(p)
	var inner:= outer + RIM


	var drop:= _plate(p + Vector2(0.0, SHADOW_DROP))
	var shadow:= SHADOW_ALPHA * (1.0 - smoothstep(- SHADOW_SOFT * 0.4, SHADOW_SOFT, drop))
	var plate:= 1.0 - smoothstep(- AA, AA, outer)
	if plate <= 0.0 and shadow <= 0.003:
		return Color(COL_SHADOW, 0.0)


	var up:= clampf(p.y / 0.62, -1.0, 1.0)
	var col:= body.lerp(Color.WHITE, 0.14 * maxf(up, 0.0))
	col = col.lerp(Color.BLACK, 0.22 * maxf(- up, 0.0))
	col = col.lerp(Color.BLACK, 0.16 * smoothstep(-0.14, 0.0, inner))

	var gloss_d:= Vector2(p.x / 0.24, (p.y - 0.3) / 0.17).length()
	col = col.lerp(Color.WHITE, 0.08 * (1.0 - smoothstep(0.2, 1.0, gloss_d)))

	var mark:= _mark(p, icon)
	if ink.get_luminance() > 0.5:
		var under:= _mark(p + Vector2(0.0, MARK_DROP), icon)
		col = col.lerp(Color.BLACK, 0.26 * (1.0 - smoothstep(-0.02, 0.05, under)))
	col = col.lerp(ink, 1.0 - smoothstep(- AA, AA, mark))


	var fill:= 1.0 - smoothstep(- AA, AA, inner)
	var seam:= 1.0 - smoothstep(0.0, AA * 1.6, absf(inner))
	var rim:= COL_RIM.lerp(body.lerp(Color.BLACK, 0.45), seam * 0.55)
	col = rim.lerp(col, fill)


	var a:= plate + shadow * (1.0 - plate)
	var out:= COL_SHADOW.lerp(col, plate / a)
	out.a = a
	return out


static func _plate(p: Vector2) -> float:
	var q:= Vector2(absf(p.x) - TRI, p.y + TRI * 0.5 / SQRT3 + TRI / SQRT3)
	if q.x + SQRT3 * q.y > 0.0:
		q = Vector2(q.x - SQRT3 * q.y, - SQRT3 * q.x - q.y) * 0.5
	q.x -= clampf(q.x, -2.0 * TRI, 0.0)
	return - q.length() * signf(q.y)


static func _plate_sharp(p: Vector2) -> float:
	var inradius:= TRI / SQRT3
	var y:= p.y + inradius * 0.5
	return maxf(- y - inradius, 0.5 * (SQRT3 * absf(p.x) + y) - inradius)


static func _mark(p: Vector2, icon: String) -> float:
	var q:= (p - MARK_CENTRE) / MARK_SCALE
	var d:= _bang(q)
	if icon == "power":
		d = _polygon(q / BOLT_SCALE, BOLT) * BOLT_SCALE - BOLT_FAT
	elif icon == "water":
		d = _drop(q)
	return d * MARK_SCALE


static func _bang(p: Vector2) -> float:
	var bar:= _rounded_box(p - Vector2(0.0, 0.1), Vector2(0.062, 0.2), 0.062)
	var dot:= p.distance_to(Vector2(0.0, -0.245)) - 0.078
	return minf(bar, dot)


const DROP_R:= 0.215
const DROP_APEX:= 0.34
const DROP_CENTRE:= Vector2(0.0, -0.13)
static var _drop_tri: Array = []


static func _drop_outline() -> Array:
	var reach:= DROP_APEX - DROP_CENTRE.y
	var s:= DROP_R / reach
	var c:= sqrt(1.0 - s * s)
	var touch:= DROP_CENTRE + Vector2(DROP_R * c, DROP_R * s)
	return [Vector2(0.0, DROP_APEX), touch, Vector2(- touch.x, touch.y)]


static func _drop(p: Vector2) -> float:
	if _drop_tri.is_empty():
		_drop_tri = _drop_outline()
	return minf(p.distance_to(DROP_CENTRE) - DROP_R, _polygon(p, _drop_tri))


static func _polygon(p: Vector2, poly: Array) -> float:
	var n:= poly.size()
	var best:= (p - (poly [0] as Vector2)).length_squared()
	var inside:= false
	for i in n:
		var a: Vector2 = poly [i]
		var b: Vector2 = poly [(i + 1) % n]
		var edge:= b - a
		var to_p:= p - a
		var t:= clampf(to_p.dot(edge) / maxf(edge.length_squared(), 1e-12), 0.0, 1.0)
		best = minf(best, (to_p - edge * t).length_squared())


		if (a.y > p.y) != (b.y > p.y):
			if p.x < a.x + (p.y - a.y) / (b.y - a.y) * edge.x:
				inside = not inside
	return - sqrt(best) if inside else sqrt(best)


static func _rounded_box(p: Vector2, half: Vector2, radius: float) -> float:
	var d:= Vector2(absf(p.x), absf(p.y)) - half + Vector2(radius, radius)
	var out:= Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()
	return out + minf(maxf(d.x, d.y), 0.0) - radius
