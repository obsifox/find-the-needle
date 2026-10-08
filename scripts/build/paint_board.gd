class_name PaintBoard
extends Node3D


const MODEL:= "res://assets/models/paint_board.glb"
const SPEC:= "res://assets/models/paint_board_materials.json"


const N_CANVAS:= "Canvas"
const N_TL:= "Marker_CanvasTL"
const N_BR:= "Marker_CanvasBR"


const RES:= Vector2i(1024, 768)


const FALLBACK_SIZE:= Vector2(2.0, 1.5)
const FALLBACK_MID_Y:= 1.57
const FALLBACK_Z:= 0.019


const REACH:= 4.0


enum Tool { PEN, LINE, RECT, ELLIPSE, ERASER }


const WIDTHS:= [0.0025, 0.006, 0.014, 0.03]


const ERASE_R:= 0.022


const SWATCHES: Array [Color] = [
	Color(0.09, 0.09, 0.1), Color(0.35, 0.36, 0.38), Color(0.72, 0.73, 0.75),
	Color(0.78, 0.13, 0.11), Color(0.9, 0.45, 0.09), Color(0.93, 0.76, 0.15),
	Color(0.16, 0.55, 0.24), Color(0.11, 0.38, 0.76), Color(0.44, 0.2, 0.62),
	Color(0.98, 0.98, 0.97),
]


const SAMPLE_MIN:= 0.0006


const ROTATE_CHOICES:= [0, 60, 300, 600]
const ROTATE_DEFAULT:= 300


const ELLIPSE_SIDES:= 72

signal drawing_changed()


static func draw_stroke(ci: CanvasItem, s: Dictionary, res: Vector2) -> void:
	var pts: PackedVector2Array = s ["p"]
	if pts.is_empty():
		return
	var col: Color = s ["c"]


	var w:= maxf(1.0, float(s ["w"]) * res.x)
	var px:= PackedVector2Array()
	px.resize(pts.size())
	for i in pts.size():
		px [i] = pts [i] * res
	match int(s ["t"]):
		Tool.PEN:
			if px.size() == 1:
				ci.draw_circle(px [0], w * 0.5, col)
				return
			ci.draw_polyline(px, col, w, true)


			ci.draw_circle(px [0], w * 0.5, col)
			ci.draw_circle(px [px.size() - 1], w * 0.5, col)
		Tool.LINE:
			if px.size() < 2:
				return
			ci.draw_line(px [0], px [1], col, w, true)
			ci.draw_circle(px [0], w * 0.5, col)
			ci.draw_circle(px [1], w * 0.5, col)
		Tool.RECT:
			if px.size() < 2:
				return
			ci.draw_polyline(PackedVector2Array([px [0],
				Vector2(px [1].x, px [0].y), px [1], Vector2(px [0].x, px [1].y),
				px [0]]), col, w, true)
		Tool.ELLIPSE:
			if px.size() < 2:
				return
			var c:= (px [0] + px [1]) * 0.5
			var rad:= (px [1] - px [0]) * 0.5
			var ring:= PackedVector2Array()
			ring.resize(ELLIPSE_SIDES + 1)
			for i in ELLIPSE_SIDES + 1:
				var a:= TAU * float(i) / float(ELLIPSE_SIDES)
				ring [i] = c + Vector2(rad.x * cos(a), rad.y * sin(a))
			ci.draw_polyline(ring, col, w, true)


var placement_preview:= false


var player: Player


var strokes: Array = []

var showing:= -1


var drafting:= false


var tool: Tool = Tool.PEN
var ink:= Color(0.09, 0.09, 0.1)
var width_step:= 1
var rotate_secs:= ROTATE_DEFAULT

var _model: Node3D
var _canvas: MeshInstance3D
var _vp: SubViewport
var _surface: PaintSurface
var _material: StandardMaterial3D


var _tl:= Vector3.ZERO
var _size:= FALLBACK_SIZE
var _plane_z:= FALLBACK_Z


var _live: PackedVector2Array = PackedVector2Array()
var _live_tool: Tool = Tool.PEN
var _was_painting:= false
var _was_erasing:= false
var _since_rotate:= 0.0

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_load_model()
	_find_canvas()
	_skin()
	_setup_bodies()
	if placement_preview:
		set_preview_valid(true)
		set_process(false)
		return
	add_to_group("paint_boards")
	_build_canvas()


	show_kept(0)


func _load_model() -> void:
	var scene: PackedScene = load(MODEL) as PackedScene
	if scene == null:
		push_warning("PaintBoard: no model at %s" % MODEL)
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)


func _find_canvas() -> void:
	if _model == null:
		return
	_canvas = _model.find_child(N_CANVAS, true, false) as MeshInstance3D
	var tl:= _model.find_child(N_TL, true, false) as Node3D
	var br:= _model.find_child(N_BR, true, false) as Node3D
	if tl == null or br == null:
		push_warning("PaintBoard: %s missing its canvas markers, using the authored size" % MODEL)
		_tl = Vector3(- FALLBACK_SIZE.x * 0.5, FALLBACK_MID_Y + FALLBACK_SIZE.y * 0.5,
			FALLBACK_Z)
		_size = FALLBACK_SIZE
		_plane_z = FALLBACK_Z
		return
	var a:= tl.position
	var b:= br.position
	_tl = a
	_size = Vector2(absf(b.x - a.x), absf(a.y - b.y))
	_plane_z = a.z


func _build_canvas() -> void:
	if _canvas == null:
		push_warning("PaintBoard: %s has no '%s' mesh, nothing can be drawn on it"
			% [MODEL, N_CANVAS])
		return
	_vp = SubViewport.new()
	_vp.name = "CanvasViewport"
	_vp.size = RES
	_vp.disable_3d = true
	_vp.transparent_bg = false


	_vp.use_hdr_2d = false
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)

	_surface = PaintSurface.new()
	_surface.name = "PaintSurface"
	_surface.board = self
	_vp.add_child(_surface)

	_material = StandardMaterial3D.new()
	_material.albedo_texture = _vp.get_texture()


	_material.roughness = 0.26
	_material.metallic = 0.0
	_canvas.set_surface_override_material(0, _material)
	_repaint()


func hit_uv(from: Vector3, look: Vector3) -> Vector2:
	if look == Vector3.ZERO or _size.x <= 0.0 or _size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var inv:= global_transform.affine_inverse()
	var o:= inv * from
	var d:= (inv.basis * look).normalized()

	if d.z >= -0.0001:
		return Vector2(-1.0, -1.0)
	var t:= (_plane_z - o.z) / d.z
	if t <= 0.0:
		return Vector2(-1.0, -1.0)
	var p:= o + d * t
	var uv:= Vector2((p.x - _tl.x) / _size.x, (_tl.y - p.y) / _size.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1.0, -1.0)
	return uv


func paintable(from: Vector3, look: Vector3) -> bool:
	if placement_preview:
		return false
	var uv:= hit_uv(from, look)
	if uv.x < 0.0:
		return false
	return from.distance_to(global_position) <= REACH + _size.y


func _process(delta: float) -> void:
	_rotate(delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if not player.is_mouse_captured():
		_release()
		return
	var uv:= hit_uv(player.eye_position(), player.look_direction())
	var near:= player.eye_position().distance_to(global_position) <= REACH + _size.y
	if uv.x < 0.0 or not near:
		_release()
		_cursor(Vector2(-1.0, -1.0))
		return
	_cursor(uv)
	var erasing:= Input.is_action_pressed("secondary") or tool == Tool.ERASER
	var painting:= Input.is_action_pressed("primary")
	if painting and erasing:
		if not _was_erasing:
			_fork()
		erase_at(uv)
		_was_erasing = true
		return
	if painting:
		_paint(uv)
		_was_painting = true
		return
	_release()


func _rotate(delta: float) -> void:
	if drafting or rotate_secs <= 0 or Sketchbook.count() < 2:
		return
	_since_rotate += delta
	if _since_rotate < float(rotate_secs):
		return
	_since_rotate = 0.0
	show_kept((showing + 1) % Sketchbook.count())


func _fork() -> void:
	if drafting:
		return
	drafting = true
	showing = -1
	_since_rotate = 0.0
	drawing_changed.emit()


func _paint(uv: Vector2) -> void:
	_fork()
	if _live.is_empty():
		_live_tool = tool
		_live.append(uv)
		_repaint()
		return
	if _live_tool == Tool.PEN:
		if _live [_live.size() - 1].distance_to(uv) < SAMPLE_MIN:
			return
		_live.append(uv)
	else:


		if _live.size() < 2:
			_live.append(uv)
		else:
			_live [1] = uv
	_repaint()


func _release() -> void:
	_was_painting = false
	_was_erasing = false
	if _live.is_empty():
		return
	var done:= _live
	_live = PackedVector2Array()


	if _live_tool != Tool.PEN and done.size() < 2:
		_repaint()
		return
	if strokes.size() >= Sketchbook.MAX_STROKES:
		_repaint()
		return
	strokes.append({
		"t": int(_live_tool),
		"c": ink,
		"w": WIDTHS [clampi(width_step, 0, WIDTHS.size() - 1)],
		"p": done,
	})
	_repaint()
	drawing_changed.emit()


func erase_at(uv: Vector2) -> void:
	var kept: Array = []
	var hit:= false
	for s: Dictionary in strokes:
		var pts: PackedVector2Array = s ["p"]
		var touched:= false
		for p in pts:
			if p.distance_to(uv) <= ERASE_R:
				touched = true
				break
		if touched:
			hit = true
		else:
			kept.append(s)
	if not hit:
		return
	strokes = kept
	_repaint()
	drawing_changed.emit()


func visible_strokes() -> Array:
	var out:= strokes.duplicate()
	if not _live.is_empty():
		out.append({
			"t": int(_live_tool),
			"c": ink,
			"w": WIDTHS [clampi(width_step, 0, WIDTHS.size() - 1)],
			"p": _live,
		})
	return out


func clear() -> void:
	strokes = []
	_live = PackedVector2Array()
	drafting = false
	showing = -1
	_since_rotate = 0.0
	_repaint()
	drawing_changed.emit()


func keep(title: String = "") -> bool:
	if Sketchbook.keep(strokes, title) < 0:
		return false
	drafting = false
	showing = 0
	_since_rotate = 0.0
	drawing_changed.emit()
	return true


func set_picture(what: Array) -> void:
	strokes = what.duplicate()
	_live = PackedVector2Array()
	drafting = false
	showing = -1
	_repaint()
	drawing_changed.emit()


func show_kept(i: int) -> void:
	var n:= Sketchbook.count()
	if n <= 0:
		strokes = []
		showing = -1
		_repaint()
		return
	showing = clampi(i, 0, n - 1)
	strokes = Sketchbook.strokes_of(showing)
	_live = PackedVector2Array()
	drafting = false
	_since_rotate = 0.0
	_repaint()
	drawing_changed.emit()


func title() -> String:
	if drafting:
		return tr("Unsaved drawing")
	var d:= Sketchbook.at(showing)
	if d.is_empty():
		return tr("Empty board")
	return str(d.get("name", tr("Drawing")))


func _cursor(uv: Vector2) -> void:
	if _surface == null or _surface.cursor == uv:
		return
	_surface.cursor = uv
	_surface.cursor_r = (ERASE_R if (tool == Tool.ERASER
		or Input.is_action_pressed("secondary"))
		else WIDTHS [clampi(width_step, 0, WIDTHS.size() - 1)] * 0.5)
	_repaint()


func _repaint() -> void:
	if _surface == null or _vp == null:
		return
	_surface.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _setup_bodies() -> void:
	for node in find_children("*", "StaticBody3D", true, false):
		var body:= node as StaticBody3D
		if body == null:
			continue
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


func build_cost() -> float:
	return Cfg.PAINT_BOARD_COST


func to_dict() -> Dictionary:


	return {
		"type": "paint_board",
		"position": global_position,
		"yaw": global_rotation.y,
		"showing": showing,
		"rotate_secs": rotate_secs,
	}


func from_dict(d: Dictionary) -> void:
	rotate_secs = int(d.get("rotate_secs", ROTATE_DEFAULT))
	if not ROTATE_CHOICES.has(rotate_secs):
		rotate_secs = ROTATE_DEFAULT
	show_kept(int(d.get("showing", 0)))


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("PaintBoard: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null or mesh == _canvas:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return HayCompressor.make_material(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("PaintBoard: no table entry for %s" % ", ".join(missed.keys()))


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	var stack: Array [Node] = [_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			out.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return out


func spec_table() -> Dictionary:
	if _spec_cache.has(SPEC):
		return _spec_cache [SPEC]
	var table: Dictionary = { }


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		table = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			table = parsed
	_spec_cache [SPEC] = table
	return table


class PaintSurface:
	extends Node2D

	var board: PaintBoard

	var cursor:= Vector2(-1.0, -1.0)
	var cursor_r:= 0.01


	const GROUND:= Color(0.855, 0.85, 0.82)

	func _draw() -> void:
		if board == null:
			return
		var res:= Vector2(PaintBoard.RES)
		draw_rect(Rect2(Vector2.ZERO, res), GROUND, true)
		for s: Dictionary in board.visible_strokes():
			PaintBoard.draw_stroke(self, s, res)
		_cursor(res)


	func _cursor(res: Vector2) -> void:
		if cursor.x < 0.0:
			return
		var at:= cursor * res
		var r:= maxf(3.0, cursor_r * res.x)
		draw_arc(at, r, 0.0, TAU, 32, Color(0.1, 0.1, 0.11, 0.55), 1.5, true)
