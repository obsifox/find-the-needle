class_name TouchControls
extends CanvasLayer
## Mobile touch HUD v2 (V39). Rebuilt around the 9 designed round buttons
## (menu / run / jump / dig / build / use / e / q / tech) with a fully
## responsive layout: every position is normalized (0..1) against the live
## viewport, sizes scale with the short screen edge, everything is clamped
## inside the device safe area (notches / nav bars) and the whole layer
## re-flows on resize / rotation.
##
## Fixes over the v1 layer:
##   - v1 placed buttons at hardcoded pixel offsets -> cut off or overlapping
##     on anything that was not the reference phone. Now layout is anchored
##     by fractions, so 16:9 .. 21:9 and tablets all work.
##   - v1 tap buttons called Input.action_press(), which only flips the
##     polled action state and never emits an InputEvent. The player and
##     every panel listen for events (event.is_action_pressed), so E / MENU /
##     TECH / BUILD / Q / hotbar were dead on touch. Taps now synthesize real
##     InputEventAction via Input.parse_input_event().
##   - While a mouse-designed UI (pause / shop / tech...) is up the player
##     releases mouse capture; this layer then goes passive: it hides, stops
##     consuming touches and re-enables emulate_mouse_from_touch so the stock
##     Godot Buttons in those panels respond to fingers. Back in gameplay
##     (capture on) it turns emulation off again to keep the look path clean.
##
## HUD EDIT MODE: long-press MENU (0.7 s) to enter. Drag a button to move it,
## tap a button to cycle S / M / L, RESET restores defaults, DONE saves and
## exits. The layout persists per device to user://hud_layout.cfg as
## normalized coordinates, so it stays correct after resize / rotation.

const CFG_PATH:= "user://hud_layout.cfg"
const LAYOUT_VERSION:= 1
const EDIT_LONGPRESS_S:= 0.7
const TAP_RELEASE_S:= 0.08
const SIZE_SCALES:= [0.8, 1.0, 1.25]
const HIT_GROW:= 6.0

const RUN_ON_TINT:= Color(1.3, 1.12, 0.85)
const COL_PANEL:= Color(0.05, 0.08, 0.12, 0.8)
const COL_PANEL_LINE:= Color(0.55, 0.62, 0.74, 0.7)

const TEX:= {
	"menu": "res://assets/ui/hud/hud_menu.png",
	"run": "res://assets/ui/hud/hud_run.png",
	"jump": "res://assets/ui/hud/hud_jump.png",
	"dig": "res://assets/ui/hud/hud_dig.png",
	"build": "res://assets/ui/hud/hud_build.png",
	"use": "res://assets/ui/hud/hud_use.png",
	"e": "res://assets/ui/hud/hud_e.png",
	"q": "res://assets/ui/hud/hud_q.png",
	"tech": "res://assets/ui/hud/hud_tech.png",
}

# Fallback accent per button (used only if a texture is missing, and for the
# edit rings) -- matches the colour language of the designed PNGs.
const COL:= {
	"menu": Color(0.75, 0.82, 0.92),
	"run": Color(1.0, 0.78, 0.82),
	"jump": Color(0.62, 0.65, 0.98),
	"dig": Color(1.0, 0.66, 0.2),
	"build": Color(0.35, 0.95, 0.45),
	"use": Color(0.3, 0.95, 0.75),
	"e": Color(1.0, 0.85, 0.3),
	"q": Color(1.0, 0.45, 0.5),
	"tech": Color(0.8, 0.45, 1.0),
}

# mode: hold | tap | toggle ; act: an input action, or mouse_left/mouse_right
# f: button diameter as a fraction of the short screen edge.
# pos: default centre as a normalized (0..1) fraction of the viewport.
const BUTTONS:= {
	"dig": {"mode": "hold", "act": "mouse_left", "f": 0.16, "pos": Vector2(0.885, 0.690)},
	"use": {"mode": "hold", "act": "mouse_right", "f": 0.128, "pos": Vector2(0.768, 0.838)},
	"jump": {"mode": "hold", "act": "jump", "f": 0.128, "pos": Vector2(0.885, 0.462)},
	"e": {"mode": "tap", "act": "interact", "f": 0.128, "pos": Vector2(0.768, 0.628)},
	"run": {"mode": "toggle", "act": "sprint", "f": 0.128, "pos": Vector2(0.648, 0.792)},
	"menu": {"mode": "tap", "act": "free_mouse", "f": 0.1, "pos": Vector2(0.948, 0.1)},
	"tech": {"mode": "tap", "act": "tech_tree", "f": 0.118, "pos": Vector2(0.948, 0.252)},
	"build": {"mode": "tap", "act": "build_catalog", "f": 0.118, "pos": Vector2(0.948, 0.404)},
	"q": {"mode": "tap", "act": "drop_tool", "f": 0.1, "pos": Vector2(0.948, 0.556)},
}

const HOTBAR_N:= 5

var _root: Control
var _btn_nodes: Dictionary = {}
var _btn_labels: Dictionary = {}
var _layout: Dictionary = {}
var _hotbar_nodes: Array = []

var _stick_root: Control
var _knob: Control
var _stick_r:= 130.0
var _knob_r:= 54.0
var _stick_touch: int = -1
var _stick_base: Vector2
var _look_touch: int = -1
var _look_last: Vector2

var _btn_touches: Dictionary = {}
var _sprint_on:= false

var _edit:= false
var _edit_rings: Control
var _edit_bar: Control
var _bar_btns: Dictionary = {}
var _bar_hint: Label
var _bar_touch: int = -1
var _bar_id:= ""
var _drag_index: int = -1
var _drag_id:= ""
var _drag_offset: Vector2
var _drag_moved:= false
var _press_pos: Vector2
var _press_ms: int = 0

var _menu_token: int = 0
var _passive:= false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.emulate_mouse_from_touch = false
	_load_layout()
	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_stick()
	_build_buttons()
	_build_hotbar()
	_build_edit_ui()
	_relayout()
	get_viewport().size_changed.connect(_on_resized)


func _exit_tree() -> void:
	_release_all()
	# Stock menus (main menu included) are mouse-designed; leave mouse
	# emulation on so they stay usable by finger once this layer is gone.
	Input.emulate_mouse_from_touch = true


func _process(_dt: float) -> void:
	# Gameplay = the player holds mouse capture (platform-independent: works
	# on Android where Input.mouse_mode is unreliable). Any UI-open state
	# flips this layer passive so stock panels get the touches.
	var g:= _gameplay_active()
	if g == _passive:
		_set_passive(not g)


func _gameplay_active() -> bool:
	var w: Node = get_parent()
	if w != null and "player" in w:
		var p: Node = w.get("player")
		if p != null and p.has_method("is_mouse_captured"):
			return p.call("is_mouse_captured")
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _set_passive(on: bool) -> void:
	_passive = on
	_release_all()
	if _edit:
		_exit_edit(false)
	_root.visible = not on
	# Mouse-designed UIs need synthesized mouse clicks; gameplay must not
	# have them (they would double-feed the look path).
	Input.emulate_mouse_from_touch = on


func _on_resized() -> void:
	call_deferred("_relayout")


# ---------------------------------------------------------------- layout --

func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _min_dim() -> float:
	var vp:= _view_size()
	return minf(vp.x, vp.y)


func _ui_scale() -> float:
	return clampf(_min_dim() / 900.0, 0.7, 1.6)


## Device safe area (notches / punch holes / nav bars) converted from window
## pixels into this canvas' coordinate space. Falls back to the full rect.
func _safe_rect() -> Rect2:
	var vp:= _view_size()
	var r:= Rect2(Vector2.ZERO, vp)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var sa:= DisplayServer.get_display_safe_area()
		var win:= Vector2(DisplayServer.window_get_size())
		if win.x > 1.0 and win.y > 1.0 and vp.x > 1.0 and vp.y > 1.0:
			var sx:= win.x / vp.x
			var sy:= win.y / vp.y
			var off:= Vector2(sa.position.x / sx, sa.position.y / sy)
			var sz:= Vector2(sa.size.x / sx, sa.size.y / sy)
			var sr:= Rect2(off, sz).intersection(r)
			if sr.size.x > 40.0 and sr.size.y > 40.0:
				r = sr
	return r


func _size_idx(id: String) -> int:
	return clampi(int(_layout[id]["size"]), 0, SIZE_SCALES.size() - 1)


func _btn_px(id: String) -> float:
	var spec: Dictionary = BUTTONS[id]
	var base:= _min_dim() * float(spec["f"])
	base = clampf(base, 58.0, 230.0)
	return base * float(SIZE_SCALES[_size_idx(id)])


func _center_px(id: String) -> Vector2:
	var pos: Vector2 = _layout[id]["pos"]
	var c:= Vector2(pos.x * _view_size().x, pos.y * _view_size().y)
	var safe:= _safe_rect()
	var half:= Vector2(_btn_px(id), _btn_px(id)) * 0.5
	var pad:= 4.0
	var lo:= safe.position + half + Vector2(pad, pad)
	var hi:= safe.end - half - Vector2(pad, pad)
	c.x = clampf(c.x, lo.x, maxf(lo.x, hi.x))
	c.y = clampf(c.y, lo.y, maxf(lo.y, hi.y))
	return c


func _relayout() -> void:
	if _root == null:
		return
	var safe:= _safe_rect()
	# --- action buttons ---------------------------------------------------
	for id in _btn_nodes:
		var n: Control = _btn_nodes[id]
		var px:= _btn_px(id)
		n.size = Vector2(px, px)
		n.pivot_offset = n.size * 0.5
		n.position = _center_px(id) - n.size * 0.5
		var lab: Label = _btn_labels.get(id)
		if lab != null:
			lab.add_theme_font_size_override("font_size", int(px * 0.3))
		n.queue_redraw()
	# --- hotbar ------------------------------------------------------------
	var bw:= clampf(_min_dim() * 0.075, 48.0, 110.0)
	var gap:= bw * 0.35
	var total:= float(_hotbar_nodes.size()) * bw + float(_hotbar_nodes.size() - 1) * gap
	var cx:= safe.position.x + safe.size.x * 0.5
	var y:= safe.position.y + 10.0
	for i in _hotbar_nodes.size():
		var h: Control = _hotbar_nodes[i]
		h.size = Vector2(bw, bw * 0.72)
		h.position = Vector2(cx - total * 0.5 + float(i) * (bw + gap), y)
		var lab: Label = h.get_node_or_null("L")
		if lab != null:
			lab.size = h.size
			lab.add_theme_font_size_override("font_size", int(bw * 0.34))
		h.queue_redraw()
	# --- stick ---------------------------------------------------------------
	_stick_r = clampf(_min_dim() * 0.13, 84.0, 170.0)
	_knob_r = _stick_r * 0.42
	_stick_root.size = Vector2(_stick_r, _stick_r) * 2.0
	_knob.size = Vector2(_knob_r, _knob_r) * 2.0
	_knob.position = Vector2(_stick_r, _stick_r) - Vector2(_knob_r, _knob_r)
	_stick_home()
	_stick_root.queue_redraw()
	_knob.queue_redraw()
	# --- edit bar ------------------------------------------------------------
	_layout_edit_bar(safe)
	if _edit_rings != null:
		_edit_rings.queue_redraw()


func _stick_home() -> void:
	var safe:= _safe_rect()
	var m:= clampf(_min_dim() * 0.03, 14.0, 40.0)
	var c:= Vector2(safe.position.x + m + _stick_r, safe.end.y - m - _stick_r)
	_stick_root.position = c - Vector2(_stick_r, _stick_r)


# ---------------------------------------------------------------- visuals --

func _build_buttons() -> void:
	for id in BUTTONS:
		var n:= _make_btn_visual(id)
		_root.add_child(n)
		_btn_nodes[id] = n


func _make_btn_visual(id: String) -> Control:
	var tex: Texture2D = load(TEX[id]) if TEX.has(id) else null
	var n: Control
	if tex != null:
		var tr:= TextureRect.new()
		tr.name = id
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		n = tr
	else:
		n = _make_fallback(id)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## Disc + coloured ring + letter, used only when the designed PNG is missing
## (e.g. running headless in dev) so the HUD never goes invisible.
func _make_fallback(id: String) -> Control:
	var c:= Control.new()
	c.name = id
	c.set_meta("col", COL.get(id, Color(1, 1, 1)))
	c.draw.connect(func() -> void:
		var r: float = maxf(c.size.x * 0.5 - 2.0, 4.0)
		var mid: Vector2 = c.size * 0.5
		var col: Color = c.get_meta("col")
		c.draw_circle(mid, r, Color(0.07, 0.1, 0.14, 0.6))
		c.draw_arc(mid, r, 0.0, TAU, 40, col, 3.0)
		c.draw_arc(mid, r * 0.8, 0.0, TAU, 40, col * Color(1, 1, 1, 0.4), 1.5))
	var lab:= Label.new()
	lab.name = "L"
	lab.text = id.to_upper()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lab)
	_btn_labels[id] = lab
	return c


func _set_btn_pressed(id: String, on: bool) -> void:
	var n: Control = _btn_nodes.get(id)
	if n == null:
		return
	if on:
		n.scale = Vector2(0.9, 0.9)
		n.modulate = Color(1.35, 1.35, 1.35)
	elif id == "run" and _sprint_on:
		n.scale = Vector2.ONE
		n.modulate = RUN_ON_TINT
	else:
		n.scale = Vector2.ONE
		n.modulate = Color(1, 1, 1)


func _update_run_visual() -> void:
	var n: Control = _btn_nodes.get("run")
	if n == null:
		return
	n.modulate = RUN_ON_TINT if _sprint_on else Color(1, 1, 1)


func _build_hotbar() -> void:
	for i in HOTBAR_N:
		var h:= Control.new()
		h.name = "hotbar_%d" % (i + 1)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_meta("idx", i + 1)
		h.draw.connect(func() -> void:
			var r:= Rect2(Vector2.ZERO, h.size)
			var sb:= StyleBoxFlat.new()
			sb.bg_color = Color(0.08, 0.08, 0.09, 0.55)
			sb.set_corner_radius_all(int(h.size.y * 0.22))
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 0.28)
			h.draw_style_box(sb, r))
		var lab:= Label.new()
		lab.name = "L"
		lab.text = str(i + 1)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(lab)
		_root.add_child(h)
		_hotbar_nodes.append(h)


func _build_stick() -> void:
	_stick_root = Control.new()
	_stick_root.name = "Stick"
	_stick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_root.draw.connect(func() -> void:
		var r: float = _stick_root.size.x * 0.5
		var mid: Vector2 = _stick_root.size * 0.5
		_stick_root.draw_circle(mid, r - 2.0, Color(1, 1, 1, 0.07))
		_stick_root.draw_arc(mid, r - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0))
	_root.add_child(_stick_root)

	_knob = Control.new()
	_knob.name = "Knob"
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.draw.connect(func() -> void:
		var r: float = _knob.size.x * 0.5
		var mid: Vector2 = _knob.size * 0.5
		_knob.draw_circle(mid, r - 2.0, Color(1, 1, 1, 0.3))
		_knob.draw_arc(mid, r - 2.0, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 2.0))
	_stick_root.add_child(_knob)


func _build_edit_ui() -> void:
	_edit_rings = Control.new()
	_edit_rings.name = "EditRings"
	_edit_rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edit_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_rings.draw.connect(func() -> void:
		for id in _btn_nodes:
			var n: Control = _btn_nodes[id]
			var c: Vector2 = n.position + n.size * 0.5
			var r: float = n.size.x * 0.5 + 10.0
			var hot: bool = id == _drag_id
			var col:= Color(1, 0.92, 0.55, 0.95) if hot else Color(0.85, 0.9, 1.0, 0.75)
			var segs:= 12
			for s in segs:
				var a0: float = TAU * float(s) / float(segs)
				var a1: float = a0 + TAU / float(segs) * 0.62
				var w: float = 4.0 if hot else 2.4
				_edit_rings.draw_arc(c, r, a0, a1, 10, col, w))
	_root.add_child(_edit_rings)
	_edit_rings.visible = false

	_edit_bar = Control.new()
	_edit_bar.name = "EditBar"
	_edit_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_bar.draw.connect(func() -> void:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = COL_PANEL
		sb.set_corner_radius_all(int(_edit_bar.size.y * 0.28))
		sb.set_border_width_all(1)
		sb.border_color = COL_PANEL_LINE
		_edit_bar.draw_style_box(sb, Rect2(Vector2.ZERO, _edit_bar.size)))
	_edit_bar.visible = false
	_root.add_child(_edit_bar)

	var hint:= Label.new()
	hint.name = "Hint"
	hint.text = "HUD EDIT - drag: move / tap: size / long-press MENU: exit"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", Color(0.93, 0.95, 0.99, 0.95))
	_edit_bar.add_child(hint)
	_bar_hint = hint

	_bar_btns["reset"] = _make_bar_btn("RESET")
	_bar_btns["done"] = _make_bar_btn("DONE")
	_edit_bar.add_child(_bar_btns["reset"])
	_edit_bar.add_child(_bar_btns["done"])


func _make_bar_btn(label: String) -> Control:
	var c:= Control.new()
	c.name = label
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r:= Rect2(Vector2.ZERO, c.size)
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.14, 0.2, 0.92)
		sb.set_corner_radius_all(int(c.size.y * 0.3))
		sb.set_border_width_all(2)
		sb.border_color = COL_PANEL_LINE
		c.draw_style_box(sb, r))
	var lab:= Label.new()
	lab.name = "L"
	lab.text = label
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", Color(0.93, 0.95, 0.99))
	c.add_child(lab)
	return c


func _layout_edit_bar(safe: Rect2) -> void:
	if _edit_bar == null:
		return
	var u:= _ui_scale()
	var h:= 58.0 * u
	var btn_w:= 110.0 * u
	var pad:= 14.0 * u
	var gap:= 12.0 * u
	var panel_w:= minf(safe.size.x - 24.0, pad * 2.0 + btn_w * 2.0 + gap * 3.0 + 420.0 * u)
	var bx:= safe.position.x + safe.size.x * 0.5 - panel_w * 0.5
	var by:= safe.position.y + 10.0
	_edit_bar.position = Vector2(bx, by)
	_edit_bar.size = Vector2(panel_w, h)
	if _bar_hint != null:
		_bar_hint.position = Vector2(pad, 0)
		_bar_hint.size = Vector2(panel_w - pad * 2.0 - btn_w * 2.0 - gap * 2.0, h)
		_bar_hint.add_theme_font_size_override("font_size", int(15.0 * u))
	var rx: float = panel_w - pad - btn_w
	_bar_btns["reset"].position = Vector2(rx, (h - h * 0.72) * 0.5)
	_bar_btns["reset"].size = Vector2(btn_w, h * 0.72)
	_bar_btns["done"].position = Vector2(rx - gap - btn_w, (h - h * 0.72) * 0.5)
	_bar_btns["done"].size = Vector2(btn_w, h * 0.72)
	for bid in _bar_btns:
		var b: Control = _bar_btns[bid]
		var lab: Label = b.get_node_or_null("L")
		if lab != null:
			lab.size = b.size
			lab.add_theme_font_size_override("font_size", int(15.0 * u))
		b.queue_redraw()
	_edit_bar.queue_redraw()


# ----------------------------------------------------------------- input --

func _unhandled_input(event: InputEvent) -> void:
	if _passive:
		return
	if event is InputEventScreenTouch:
		var st:= event as InputEventScreenTouch
		if st.pressed:
			_touch_start(st.index, st.position)
		else:
			_touch_end(st.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var dr:= event as InputEventScreenDrag
		_touch_drag(dr.index, dr.position)
		get_viewport().set_input_as_handled()


func _touch_start(index: int, pos: Vector2) -> void:
	if _edit:
		_edit_touch_start(index, pos)
		return
	var id:= _hit_button(pos)
	if id != "":
		_btn_touches[index] = id
		_btn_down(id)
		return
	var vp:= _view_size()
	# left-bottom zone -> move stick (appears under the finger)
	if pos.x < vp.x * 0.42 and pos.y > vp.y * 0.45:
		if _stick_touch == -1:
			_stick_touch = index
			_stick_base = _clamp_point(pos, _stick_r)
			_stick_root.position = _stick_base - Vector2(_stick_r, _stick_r)
			_knob.position = Vector2(_stick_r, _stick_r) - Vector2(_knob_r, _knob_r)
		return
	# otherwise -> look drag
	if _look_touch == -1:
		_look_touch = index
		_look_last = pos


func _touch_drag(index: int, pos: Vector2) -> void:
	if _edit:
		_edit_touch_drag(index, pos)
		return
	if index == _stick_touch:
		_stick_move(pos)
	elif index == _look_touch:
		_look_move(pos)


func _touch_end(index: int) -> void:
	if _edit:
		_edit_touch_end(index)
		# a pre-edit hold may still be down (e.g. the MENU long-press itself)
		var held: String = _btn_touches.get(index, "")
		if held != "":
			_btn_touches.erase(index)
			_btn_up(held)
		return
	var id: String = _btn_touches.get(index, "")
	if id != "":
		_btn_touches.erase(index)
		_btn_up(id)
	elif index == _stick_touch:
		_stick_touch = -1
		_release_move()
		_stick_home()
	elif index == _look_touch:
		_look_touch = -1


func _hit_button(pos: Vector2) -> String:
	var best:= ""
	var best_area:= -1.0
	for id in _btn_nodes:
		var n: Control = _btn_nodes[id]
		if Rect2(n.position, n.size).grow(HIT_GROW).has_point(pos):
			var a: float = n.size.x * n.size.y
			if best == "" or a < best_area:
				best = id
				best_area = a
	return best


func _clamp_point(pos: Vector2, r: float) -> Vector2:
	var safe:= _safe_rect()
	var m:= r + 2.0
	var lo:= safe.position + Vector2(m, m)
	var hi:= safe.end - Vector2(m, m)
	return Vector2(clampf(pos.x, lo.x, maxf(lo.x, hi.x)), clampf(pos.y, lo.y, maxf(lo.y, hi.y)))


# --------------------------------------------------------------- actions --

func _btn_down(id: String) -> void:
	var spec: Dictionary = BUTTONS[id]
	var mode: String = spec["mode"]
	_set_btn_pressed(id, true)
	_buzz(16)
	match mode:
		"hold":
			_act_press(spec["act"])
		"toggle":
			_sprint_on = not _sprint_on
			if _sprint_on:
				Input.action_press(spec["act"])
			else:
				Input.action_release(spec["act"])
			_set_btn_pressed(id, false)
			_update_run_visual()
		"tap":
			if id == "menu":
				_menu_arm()
			else:
				_tap_action(spec["act"])


func _btn_up(id: String) -> void:
	var spec: Dictionary = BUTTONS[id]
	var mode: String = spec["mode"]
	match mode:
		"hold":
			_act_release(spec["act"])
		"tap":
			if id == "menu" and not _edit:
				_menu_fire()
	_set_btn_pressed(id, false)


## Holds map to mouse buttons (dig = LMB, use = RMB) or polled actions.
func _act_press(act: String) -> void:
	if act == "mouse_left":
		_mouse_btn(MOUSE_BUTTON_LEFT, true)
	elif act == "mouse_right":
		_mouse_btn(MOUSE_BUTTON_RIGHT, true)
	else:
		Input.action_press(act)


func _act_release(act: String) -> void:
	if act == "mouse_left":
		_mouse_btn(MOUSE_BUTTON_LEFT, false)
	elif act == "mouse_right":
		_mouse_btn(MOUSE_BUTTON_RIGHT, false)
	else:
		Input.action_release(act)


## Taps must emit a REAL InputEvent: the player and every panel listen with
## event.is_action_pressed(...) in _unhandled_input, which Input.action_press
## alone can never reach (v1 bug: those buttons were dead on touch).
func _tap_action(action: String) -> void:
	var ev:= InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)
	var t:= get_tree().create_timer(TAP_RELEASE_S)
	t.timeout.connect(func() -> void:
		var up:= InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up))


func _mouse_btn(button: int, pressed: bool) -> void:
	var ev:= InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = _view_size() * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _buzz(ms: int) -> void:
	if OS.has_feature("android"):
		Input.vibrate_handheld(ms)


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]:
		Input.action_release(a)
	for index in _btn_touches.keys():
		_btn_up(_btn_touches[index])
	_btn_touches.clear()
	_stick_touch = -1
	_look_touch = -1
	_sprint_on = false
	for bid in _btn_nodes:
		_set_btn_pressed(bid, false)
	_update_run_visual()


# ------------------------------------------------------ menu long-press --

func _menu_arm() -> void:
	_menu_token += 1
	var tok: int = _menu_token
	var t:= get_tree().create_timer(EDIT_LONGPRESS_S)
	t.timeout.connect(func() -> void:
		if tok == _menu_token and not _edit:
			_menu_token += 1
			_enter_edit())


func _menu_fire() -> void:
	_menu_token += 1
	if not _edit:
		_tap_action(BUTTONS["menu"]["act"])


# ------------------------------------------------------------- edit mode --

func _enter_edit() -> void:
	if _edit:
		return
	_edit = true
	_release_all()
	_edit_rings.visible = true
	_edit_bar.visible = true
	_edit_rings.queue_redraw()
	_buzz(40)


func _exit_edit(save: bool) -> void:
	if not _edit:
		return
	if save:
		_save_layout()
	_edit = false
	_drag_index = -1
	_drag_id = ""
	_bar_touch = -1
	_bar_id = ""
	_edit_rings.visible = false
	_edit_bar.visible = false
	_buzz(20)


func _edit_touch_start(index: int, pos: Vector2) -> void:
	for bid in _bar_btns:
		var n: Control = _bar_btns[bid]
		if n.get_global_rect().grow(6.0).has_point(pos):
			_bar_touch = index
			_bar_id = bid
			n.modulate = Color(1.3, 1.3, 1.3)
			return
	var id:= _hit_button(pos)
	if id != "":
		_drag_index = index
		_drag_id = id
		_drag_offset = pos - _center_px(id)
		_drag_moved = false
		_press_pos = pos
		_press_ms = Time.get_ticks_msec()


func _edit_touch_drag(index: int, pos: Vector2) -> void:
	if index == _bar_touch:
		return
	if index != _drag_index or _drag_id == "":
		return
	if not _drag_moved and pos.distance_to(_press_pos) > 10.0:
		_drag_moved = true
	if not _drag_moved:
		return
	var c:= _clamp_point(pos - _drag_offset, _btn_px(_drag_id) * 0.5)
	_layout[_drag_id]["pos"] = Vector2(c.x / _view_size().x, c.y / _view_size().y)
	var n: Control = _btn_nodes[_drag_id]
	n.position = c - n.size * 0.5
	_edit_rings.queue_redraw()


func _edit_touch_end(index: int) -> void:
	if index == _bar_touch:
		_bar_touch = -1
		var bid:= _bar_id
		_bar_id = ""
		if _bar_btns.has(bid):
			_bar_btns[bid].modulate = Color(1, 1, 1)
		if bid == "reset":
			_layout = _default_layout()
			_relayout()
			_save_layout()
			_buzz(30)
		elif bid == "done":
			_exit_edit(true)
		return
	if index != _drag_index or _drag_id == "":
		return
	var quick: bool = Time.get_ticks_msec() - _press_ms < 350
	if _drag_moved:
		_save_layout()
	elif quick:
		_cycle_size(_drag_id)
	_drag_index = -1
	_drag_id = ""
	_edit_rings.queue_redraw()


func _cycle_size(id: String) -> void:
	_layout[id]["size"] = (_size_idx(id) + 1) % SIZE_SCALES.size()
	_relayout()
	_save_layout()
	_buzz(16)


# ------------------------------------------------------- stick and look --

func _stick_move(pos: Vector2) -> void:
	var d:= pos - _stick_base
	var l:= d.length()
	if l > _stick_r:
		d = d / l * _stick_r
		l = _stick_r
	_knob.position = Vector2(_stick_r, _stick_r) + d - Vector2(_knob_r, _knob_r)
	var strn:= clampf(l / _stick_r, 0.0, 1.0)
	var fwd: float = clampf(-d.y / _stick_r, -1.0, 1.0)
	var side: float = clampf(d.x / _stick_r, -1.0, 1.0)
	_apply_axis("move_forward", "move_back", fwd * strn)
	_apply_axis("move_right", "move_left", side * strn)


func _apply_axis(pos_action: String, neg_action: String, value: float) -> void:
	if value > 0.02:
		Input.action_release(neg_action)
		Input.action_press(pos_action, value)
	elif value < -0.02:
		Input.action_release(pos_action)
		Input.action_press(neg_action, -value)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func _release_move() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)


func _look_move(pos: Vector2) -> void:
	var d:= pos - _look_last
	_look_last = pos
	if d == Vector2.ZERO:
		return
	var ev:= InputEventMouseMotion.new()
	ev.relative = d * 0.22
	ev.screen_relative = ev.relative
	ev.position = _view_size() * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)


# ----------------------------------------------------------- persistence --

func _default_layout() -> Dictionary:
	var out: Dictionary = {}
	for id in BUTTONS:
		out[id] = {"pos": BUTTONS[id]["pos"], "size": 1}
	return out


func _load_layout() -> void:
	_layout = _default_layout()
	var cf:= ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	if int(cf.get_value("meta", "version", 0)) != LAYOUT_VERSION:
		return
	for id in _layout:
		var p: Variant = cf.get_value("layout", id + "_pos", null)
		if p is Vector2:
			var v: Vector2 = p
			if v.x >= 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= 1.0:
				_layout[id]["pos"] = v
		var s: Variant = cf.get_value("layout", id + "_size", 1)
		if s is int:
			_layout[id]["size"] = clampi(int(s), 0, SIZE_SCALES.size() - 1)


func _save_layout() -> void:
	var cf:= ConfigFile.new()
	cf.set_value("meta", "version", LAYOUT_VERSION)
	for id in _layout:
		cf.set_value("layout", id + "_pos", _layout[id]["pos"])
		cf.set_value("layout", id + "_size", _layout[id]["size"])
	cf.save(CFG_PATH)

