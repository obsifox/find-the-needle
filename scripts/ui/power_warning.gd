class_name PowerWarning
extends Control


const WARN_BELOW:= 0.65


const CLEAR_ABOVE:= 0.7
const CLEAR_SECONDS:= 1.5
const SETTLE_SECONDS:= 4.0
const SHOW_SECONDS:= 15.0
const REPEAT_SECONDS:= 300.0


const HUNGRY_BELOW:= 0.95


const BOILER:= "generator_output"


const PLANT_AFTER:= 2


const GAP_BELOW:= 8.0

const FALLBACK_TOP:= 58.0
const PAD_X:= 16.0
const PAD_TOP:= 12.0
const PAD_BOTTOM:= 13.0
const ICON:= 50.0
const ICON_GAP:= 12.0
const TITLE_SIZE:= 24
const ADVICE_SIZE:= 18


const LINE_TIGHTEN:= 0.0
const STRIPE_H:= 5.0
const STRIPE_PITCH:= 14.0
const TIMER_H:= 3.0


const COL_HAZARD:= MachineAlert.COL_HAZARD
const COL_PLATE:= Color(0.05, 0.04, 0.03, 0.86)
const COL_WASH:= Color(1.0, 0.36, 0.12)
const COL_TAPE_DARK:= Color(0.06, 0.05, 0.03)
const COL_ADVICE:= Color(0.97, 0.95, 0.88)
const COL_HOT:= Color(1.0, 0.98, 0.86)


const SLIDE:= 16.0
const FADE_IN:= 5.0
const FADE_OUT:= 2.5
const POP_FROM:= 0.82
const POP_STIFF:= 260.0
const POP_DAMP:= 13.0


const FLICKER:= [1.0, 0.12, 0.85, 1.0, 0.08, 0.04, 0.7, 0.25, 1.0, 0.95,
	0.45, 1.0, 1.0, 0.6, 1.0]
const FLICKER_RATE:= 20.0
const GLOW_HZ:= 1.1
const GLOW_RINGS:= 5


const JOLT_EVERY:= 2.6
const JOLT_FALL:= 4.5
const ARC_SECONDS:= 0.2
const SHEEN_EVERY:= 3.4
const SHEEN_SWEEP:= 1.0
const MAX_SPARKS:= 70
const SPARK_GRAVITY:= 420.0


const POLL_SECONDS:= 0.25

var hud: Hud


var anchor_under: Control


var _nets: Array [Dictionary] = []
var _poll_in:= 0.0

var _short_for:= 0.0
var _clear_for:= 0.0

var _since_shown:= REPEAT_SECONDS

var _left:= 0.0

var _age:= 0.0
var _vis:= 0.0
var _was_up:= false
var _ducked:= false
var _hidden:= false
var _feed:= false
var _boiler_maxed:= false

var _plant:= false
var _pct:= -1
var _width:= 0.0

var _pop:= 1.0
var _pop_v:= 0.0
var _jolt:= 0.0
var _next_jolt:= 0.0
var _crackle:= 0.0
var _arc_left:= 0.0
var _arc_from:= Vector2.ZERO
var _arc_to:= Vector2.ZERO
var _arc:= PackedVector2Array()

var _sparks: Array [Dictionary] = []
var _rng:= RandomNumberGenerator.new()

var _box: Control
var _clip: Control
var _sheen: Control
var _icon: TextureRect
var _title: Label
var _advice: Label
var _fx: Control


func _ready() -> void:
	name = "PowerWarning"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 200.0
	visible = false
	_rng.randomize()


	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.draw.connect(_draw_plate)
	add_child(_box)


	_clip = Control.new()
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	_box.add_child(_clip)
	_sheen = Control.new()
	_sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheen.draw.connect(_draw_sheen)
	_clip.add_child(_sheen)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.texture = MachineAlert._sign_art("power")
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2(ICON, ICON)
	_icon.pivot_offset = _icon.size * 0.5
	_box.add_child(_icon)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(_title, TITLE_SIZE, COL_HAZARD, 6, true)
	_box.add_child(_title)

	_advice = Label.new()
	_advice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(_advice, ADVICE_SIZE, COL_ADVICE, 5, true)
	_box.add_child(_advice)


	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_box.add_child(_fx)


func _process(delta: float) -> void:
	_poll_in -= delta
	if _poll_in <= 0.0:
		_poll_in = POLL_SECONDS
		var grid: PowerGrid = hud._grid() if hud != null else null
		_nets = grid.networks() if grid != null else ([] as Array [Dictionary])
	step(delta, _nets, hud != null and hud.toast_up(), Cfg.no_hud)


func step(delta: float, nets: Array [Dictionary], toast_up: bool,
		hud_hidden: bool) -> void:
	var short:= worst(nets, WARN_BELOW)
	var slow:= worst(nets, CLEAR_ABOVE)
	_short_for = _short_for + delta if not short.is_empty() else 0.0
	_clear_for = _clear_for + delta if slow.is_empty() else 0.0
	_since_shown += delta
	_hidden = hud_hidden
	_ducked = toast_up or hud_hidden

	if _left > 0.0:
		if _clear_for >= CLEAR_SECONDS:
			_left = 0.0
		elif not _ducked:
			_left = maxf(_left - delta, 0.0)


		if not slow.is_empty():
			_write(float(slow ["satisfaction"]))
	elif not short.is_empty() and _short_for >= SETTLE_SECONDS and _since_shown >= REPEAT_SECONDS and not _ducked:
		_begin(short)

	_animate(delta)


static func worst(nets: Array [Dictionary], below: float) -> Dictionary:
	var best: Dictionary = { }
	for net: Dictionary in nets:
		var cap:= float(net.get("cap", 0.0))
		if cap <= 0.0 or float(net.get("demand", 0.0)) <= 0.0:
			continue
		var sat:= float(net.get("satisfaction", 1.0))
		if sat > below:
			continue
		if not best.is_empty() and sat >= float(best ["satisfaction"]):
			continue
		best = { "satisfaction": sat,
			"feed": float(net.get("supply", 0.0)) < cap * HUNGRY_BELOW,
			"hay_gens": int(net.get("hay_gens", 0)) }
	return best


func showing_text() -> String:
	return "%s\n%s" % [_title.text, _advice.text] if _left > 0.0 else ""


func is_up() -> bool:
	return _left > 0.0


func repeat_in() -> float:
	return maxf(REPEAT_SECONDS - _since_shown, 0.0)


func _begin(net: Dictionary) -> void:
	_left = SHOW_SECONDS
	_since_shown = 0.0
	_age = 0.0
	_width = 0.0
	_pct = -1
	_feed = bool(net ["feed"])


	_boiler_maxed = Tech.is_maxed(BOILER)
	_plant = Tech.has_gas_plant() and int(net.get("hay_gens", 0)) >= PLANT_AFTER
	_write(float(net ["satisfaction"]))
	_pop = POP_FROM
	_pop_v = 0.0
	_was_up = true


	_next_jolt = float(FLICKER.size()) / FLICKER_RATE
	_burst(_icon.position + _icon.size * 0.5, 18, 1.0)


func _write(satisfaction: float) -> void:
	var pct:= int(round(satisfaction * 100.0))
	if pct == _pct:
		return
	_pct = pct

	_title.text = tr("NOT ENOUGH POWER  ·  everything runs at %d%%") % pct
	_advice.text = advice(_feed, _boiler_maxed, _plant)
	_lay_out()


static func advice(feed: bool, boiler_maxed: bool, plant:= false) -> String:
	if plant:
		return Cfg.tr("Build a Gas Plant and feed it eco bricks. It gets %d times the power from each straw.") % int(Cfg.GAS_PLANT_KJ_PER_STRAND / Cfg.GENERATOR_KJ_PER_STRAND)
	if feed:
		return Cfg.tr("Feed your hay generator more hay.")
	if boiler_maxed:
		return Cfg.tr("Build another hay generator.")
	return Cfg.tr("Build another hay generator, or upgrade it in the tech tree (%s).") % TechTree.display_name(BOILER)


func _lay_out() -> void:
	_title.reset_size()
	_advice.reset_size()
	var t:= _title.get_combined_minimum_size()
	var a:= _advice.get_combined_minimum_size()


	_width = maxf(_width, PAD_X + ICON + ICON_GAP + maxf(t.x, a.x) + PAD_X)
	var text_h:= t.y + a.y - LINE_TIGHTEN
	var inner:= maxf(text_h, ICON)
	var h:= PAD_TOP + inner + PAD_BOTTOM
	_box.size = Vector2(_width, h)
	_box.pivot_offset = _box.size * 0.5
	_clip.size = _box.size
	_sheen.size = _box.size
	_fx.size = _box.size
	var text_x:= PAD_X + ICON + ICON_GAP
	var text_top:= PAD_TOP + (inner - text_h) * 0.5
	_icon.position = Vector2(PAD_X, PAD_TOP + (inner - ICON) * 0.5)
	_title.position = Vector2(text_x, text_top)
	_advice.position = Vector2(text_x, text_top + t.y - LINE_TIGHTEN)


func _top_edge() -> float:
	var parent:= get_parent() as CanvasItem
	if anchor_under == null or not is_instance_valid(anchor_under) or parent == null:
		return FALLBACK_TOP
	var xf:= parent.get_global_transform().affine_inverse() * anchor_under.get_global_transform()
	return (xf * Vector2(0.0, anchor_under.size.y)).y + GAP_BELOW


func _animate(delta: float) -> void:
	var up:= _left > 0.0 and not _ducked


	if up and not _was_up:
		_pop = POP_FROM
		_pop_v = 0.0
	_was_up = up
	_vis = move_toward(_vis, 1.0 if up else 0.0, delta * (FADE_IN if up else FADE_OUT))
	if up:
		_age += delta

	_pop_v += (1.0 - _pop) * POP_STIFF * delta
	_pop_v *= exp(- POP_DAMP * delta)
	_pop += _pop_v * delta
	_jolt = maxf(_jolt - delta * JOLT_FALL, 0.0)

	if up and _age >= _next_jolt:
		_next_jolt = _age + JOLT_EVERY
		_zap()
	_crackle -= delta
	if up and _crackle <= 0.0:
		_crackle = _rng.randf_range(0.25, 0.8)
		_burst(_edge_point(), _rng.randi_range(2, 4), 0.5)
	_arc_left = maxf(_arc_left - delta, 0.0)
	if _arc_left > 0.0:

		_arc = _bolt_path(_arc_from, _arc_to)
	_tick_sparks(delta)

	visible = _vis > 0.0 and not _hidden
	if not visible:
		return
	var slide:= (1.0 - ease(_vis, 0.4)) * - SLIDE
	_box.position = Vector2(roundf((size.x - _box.size.x) * 0.5),
		roundf(_top_edge() + slide))
	_box.scale = Vector2.ONE * _pop
	modulate.a = _vis * _flicker()
	_icon.scale = Vector2.ONE * (1.0 + 0.3 * _jolt)
	_icon.rotation = sin(_age * 55.0) * 0.14 * _jolt
	_title.self_modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.6), _jolt)
	_box.queue_redraw()
	_sheen.queue_redraw()
	_fx.queue_redraw()


func _flicker() -> float:
	var at:= int(_age * FLICKER_RATE)
	if at < FLICKER.size():
		return float(FLICKER [at])

	return 0.8 if _arc_left > 0.0 else 1.0


func _zap() -> void:
	_jolt = 1.0
	_arc_from = _icon.position + _icon.size * 0.5
	_arc_to = _edge_point()
	_arc_left = ARC_SECONDS
	_arc = _bolt_path(_arc_from, _arc_to)
	_burst(_arc_from, 14, 1.0)
	_burst(_arc_to, 6, 0.7)


func _edge_point() -> Vector2:
	var w:= _box.size.x
	var h:= _box.size.y
	var side:= _rng.randi_range(0, 2)
	if side == 0:
		return Vector2(_rng.randf_range(w * 0.3, w), 0.0)
	if side == 1:
		return Vector2(_rng.randf_range(w * 0.3, w), h)
	return Vector2(w, _rng.randf_range(0.0, h))


func _bolt_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var pts:= PackedVector2Array()
	var steps:= 8
	var normal:= (to - from).orthogonal().normalized()
	for i in steps + 1:
		var jitter:= 0.0
		if i > 0 and i < steps:
			jitter = _rng.randf_range(-7.0, 7.0)
		pts.append(from.lerp(to, float(i) / float(steps)) + normal * jitter)
	return pts


func _burst(at: Vector2, count: int, speed: float) -> void:
	for i in count:
		if _sparks.size() >= MAX_SPARKS:
			return
		var v:= Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(90.0, 260.0) * speed
		v.y -= 60.0 * speed
		var life:= _rng.randf_range(0.25, 0.6)
		_sparks.append({ "p": at, "v": v, "life": life, "max": life })


func _tick_sparks(delta: float) -> void:
	var kept: Array [Dictionary] = []
	for spark: Dictionary in _sparks:
		var life:= float(spark ["life"]) - delta
		if life <= 0.0:
			continue
		var v: Vector2 = spark ["v"]
		v.y += SPARK_GRAVITY * delta
		v *= exp(-1.8 * delta)
		spark ["v"] = v
		spark ["p"] = (spark ["p"] as Vector2) + v * delta
		spark ["life"] = life
		kept.append(spark)
	_sparks = kept


func _draw_plate() -> void:
	var r:= Rect2(Vector2.ZERO, _box.size)
	var pulse:= 0.5 + 0.5 * sin(_age * TAU * GLOW_HZ)
	for i in GLOW_RINGS:
		var a:= (0.32 - 0.06 * float(i)) * (0.55 + 0.45 * pulse + 0.6 * _jolt)
		_box.draw_rect(r.grow(2.0 + 3.0 * float(i)), Color(COL_HAZARD, a), false, 3.0)
	_box.draw_rect(r, COL_PLATE)
	_box.draw_rect(r, Color(COL_WASH, 0.07 + 0.08 * pulse + 0.15 * _jolt))
	_box.draw_rect(r, Color(COL_HAZARD, 0.9), false, 2.0)
	var left:= clampf(_left / SHOW_SECONDS, 0.0, 1.0)

	var inset:= 5.0
	_box.draw_rect(Rect2(inset, r.size.y - TIMER_H - inset,
		(r.size.x - inset * 2.0) * left, TIMER_H), Color(COL_HAZARD, 0.7))


func _draw_sheen() -> void:
	var w:= _box.size.x
	var h:= _box.size.y
	_sheen.draw_rect(Rect2(0.0, 0.0, w, STRIPE_H), COL_TAPE_DARK)
	var x:= - STRIPE_PITCH * 2.0 + fmod(_age * 18.0, STRIPE_PITCH)
	while x < w + STRIPE_PITCH:
		var stripe:= PackedVector2Array([
			Vector2(x, 0.0), Vector2(x + STRIPE_PITCH * 0.5, 0.0),
			Vector2(x + STRIPE_PITCH * 0.5 - STRIPE_H, STRIPE_H),
			Vector2(x - STRIPE_H, STRIPE_H)])
		_sheen.draw_colored_polygon(stripe, COL_HAZARD)
		x += STRIPE_PITCH
	var t:= fmod(_age, SHEEN_EVERY) / SHEEN_SWEEP
	if t >= 1.0:
		return
	var cx:= lerpf(-60.0, w + 60.0, t)
	var half:= 22.0
	var lean:= h * 0.45
	var band:= PackedVector2Array([
		Vector2(cx - half + lean, 0.0), Vector2(cx + half + lean, 0.0),
		Vector2(cx + half - lean, h), Vector2(cx - half - lean, h)])
	_sheen.draw_colored_polygon(band, Color(COL_HOT, 0.1))


func _draw_fx() -> void:
	if _arc_left > 0.0 and _arc.size() > 1:
		var a:= _arc_left / ARC_SECONDS
		_fx.draw_polyline(_arc, Color(COL_HAZARD, 0.35 * a), 6.0)
		_fx.draw_polyline(_arc, Color(COL_HOT, 0.95 * a), 1.8)
	for spark: Dictionary in _sparks:
		var p: Vector2 = spark ["p"]
		var v: Vector2 = spark ["v"]
		var k:= float(spark ["life"]) / float(spark ["max"])
		var col:= COL_HAZARD.lerp(COL_HOT, k)
		col.a = clampf(k * 1.6, 0.0, 1.0)
		_fx.draw_line(p, p - v * 0.035, col, 2.0)
