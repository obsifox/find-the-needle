class_name BuildFx
extends Node3D


static func build_tint() -> Color:
	return Cfg.COL_GHOST_OK


static func wreck_tint() -> Color:
	return Cfg.COL_GHOST_WARN


const GIFT_TINT:= Color(1.0, 0.78, 0.26)


var _tint:= Color.WHITE


const BUILD_BASE:= 0.45
const BUILD_PER_M:= 0.14
const BUILD_MIN:= 0.6
const BUILD_MAX:= 1.5
const WRECK_BASE:= 0.3
const WRECK_PER_M:= 0.08
const WRECK_MIN:= 0.4
const WRECK_MAX:= 0.95


const BELT_PACE:= 0.5


const WRECK_TURN:= 0.1


const SETTLE:= 0.16

const SPARK_REFRESH:= 0.04


const SPARK_POINTS:= 96

const SPARK_SPEED:= 9.5


const LEAD_MIN:= 0.15
const LEAD_MAX:= 0.6


const RESCAN:= 0.12
const RESCAN_EAGER:= 6

const SHADER:= "\nshader_type spatial;\nrender_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;\n\nuniform vec4 tint : source_color = vec4(0.28, 1.0, 0.42, 1.0);\n// Where the front stands along `axis`.\nuniform float front = -10000.0;\n// The way the front travels, a unit world vector: up for a machine, along the\n// run for a belt.\nuniform vec3 axis = vec3(0.0, 1.0, 0.0);\n// +1 keeps what is ABOVE the front, -1 keeps what is below it. A wreck and a\n// build both keep what is below: the one front comes down, the other goes up.\nuniform float dir = 1.0;\nuniform float band = 0.2;\n// How solid the hologram body is before the rim and the lattice add to it.\nuniform float body = 0.42;\nuniform float fade = 1.0;\n// A white wash over the whole mesh.\nuniform float flash = 0.0;\n// Draws the front's hot edge. Off for the hold glow, which has no front.\nuniform float edge_gain = 1.0;\n\nvarying vec3 wpos;\n\nvoid vertex() {\n\twpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n}\n\nfloat hash(vec3 p) {\n\treturn fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);\n}\n\nvoid fragment() {\n\t// Ragged on a lattice about twelve centimetres across, so the front reads\n\t// as something being laid down and not as a clip plane.\n\tfloat rag = (hash(floor(wpos * 8.0)) - 0.5) * band * 0.9;\n\tfloat along = dot(wpos, axis);\n\tfloat d = (along - front) * dir + rag;\n\tif (d < 0.0) {\n\t\tdiscard;\n\t}\n\tfloat fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);\n\t// A world lattice. An axis the face does not move along is dropped, or a\n\t// wall that happens to sit on a grid line lights up end to end.\n\tvec3 cell = wpos * 3.0;\n\tvec3 fw = fwidth(cell);\n\tvec3 grid = abs(fract(cell - 0.5) - 0.5) / max(fw, vec3(1e-4));\n\tgrid = mix(vec3(1e3), grid, step(vec3(1e-3), fw));\n\tfloat line = 1.0 - clamp(min(min(grid.x, grid.y), grid.z), 0.0, 1.0);\n\tfloat scan = 0.5 + 0.5 * sin(along * 70.0 - TIME * 14.0 * dir);\n\tfloat edge = (1.0 - smoothstep(0.0, band, d)) * edge_gain;\n\tvec3 col = tint.rgb * (0.55 + 1.4 * fres + 0.9 * line + 0.25 * scan);\n\tcol += mix(tint.rgb, vec3(1.0), 0.6) * edge * 3.0;\n\tfloat a = body + 0.4 * fres + 0.35 * line + edge;\n\tcol = mix(col, vec3(1.6) + tint.rgb, flash);\n\ta = mix(a, 0.3 + 0.6 * fres, flash);\n\tALBEDO = col;\n\tALPHA = clamp(a, 0.0, 1.0) * fade;\n}\n"


static var _shader: Shader

enum Kind { BUILD, WRECK }

var _kind:= Kind.BUILD


var _targets: Array = []
var _mat: ShaderMaterial


var _prev: Dictionary = { }


var _lifted: Array = []

var _copies: Array [GeometryInstance3D] = []

var _boxes: Array [AABB] = []


var _mm_boxes: Dictionary = { }


var _axis:= Vector3.UP
var _base:= 0.0
var _top:= 0.0
var _t:= 0.0
var _duration:= 1.0

var _lead:= 0.0
var _eye: Node3D
var _sparks: GPUParticles3D
var _spark_img: Image
var _spark_tex: ImageTexture
var _spark_clock:= 0.0
var _rescan_clock:= 0.0
var _rescans:= 0

var _landed:= false
var _restored:= false
var _rng:= RandomNumberGenerator.new()


static func build(parent: Node, buildings: Array [Node3D], eye: Node3D) -> BuildFx:
	var fx:= BuildFx.new()
	fx.name = "BuildFx"
	fx._kind = Kind.BUILD
	fx._targets.assign(buildings)
	fx._eye = eye
	parent.add_child(fx)
	fx._start()
	return fx


static func wreck(parent: Node, buildings: Array [Node3D], eye: Node3D) -> BuildFx:
	var fx:= BuildFx.new()
	fx.name = "WreckFx"
	fx._kind = Kind.WRECK

	fx._targets.assign(buildings)
	fx._eye = eye
	parent.add_child(fx)
	fx._snapshot(buildings)
	fx._start()
	return fx


static func glow_material() -> ShaderMaterial:
	var m:= _material(wreck_tint())
	m.set_shader_parameter("front", -10000.0)
	m.set_shader_parameter("dir", 1.0)
	m.set_shader_parameter("edge_gain", 0.0)
	m.set_shader_parameter("body", 0.0)
	return m


static func set_glow(m: ShaderMaterial, progress: float) -> void:
	var p:= clampf(progress, 0.0, 1.0)
	m.set_shader_parameter("body", 0.08 + 0.4 * p)
	m.set_shader_parameter("fade", 0.35 + 0.65 * p)

	m.set_shader_parameter("flash", 0.12 * p * (0.5 + 0.5 * sin(p * p * 40.0)))


func abandon() -> void:
	queue_free()


func progress() -> float:
	var start:= _lead if _kind == Kind.BUILD else WRECK_TURN
	return clampf((_t - start) / _duration, 0.0, 1.0)


static func _material(tint: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m:= ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", tint)
	return m


static func meshes_of(root: Node) -> Array [GeometryInstance3D]:
	var out: Array [GeometryInstance3D] = []


	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		return out
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g:= n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var mi:= g as MeshInstance3D
		if mi != null and mi.mesh != null:
			out.append(g)
			continue
		var mmi:= g as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null and mmi.multimesh.instance_count > 0:
			out.append(g)
	return out


func _snapshot(buildings: Array [Node3D]) -> void:
	_mat = _material(wreck_tint())
	for b in buildings:
		for g in meshes_of(b):
			var copy: GeometryInstance3D
			var mi:= g as MeshInstance3D
			if mi != null:
				var m:= MeshInstance3D.new()
				m.mesh = mi.mesh
				copy = m
			else:
				var mm:= MultiMeshInstance3D.new()
				mm.multimesh = (g as MultiMeshInstance3D).multimesh
				copy = mm
			copy.material_override = _mat
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(copy)

			copy.transform = g.global_transform
			_copies.append(copy)
			_add_box(g)


func _add_box(g: GeometryInstance3D) -> void:
	var local:= AABB()
	var mmi:= g as MultiMeshInstance3D
	if mmi == null:
		local = g.get_aabb()
	else:
		local = mmi.custom_aabb
		if local.size.length_squared() < 1e-08 and mmi.multimesh != null:
			local = mmi.multimesh.custom_aabb
		if local.size.length_squared() < 1e-08:
			var id:= mmi.get_instance_id()
			var remembered: Variant = _mm_boxes.get(id)
			if remembered == null:
				remembered = mmi.get_aabb()
				_mm_boxes [id] = remembered
			local = remembered as AABB
	if local.size.length_squared() < 1e-08:
		return
	_boxes.append(g.global_transform * local)


func _start() -> void:
	_rng.randomize()
	if _kind == Kind.BUILD:
		_tint = build_tint()
		for t in _targets:
			if is_instance_valid(t) and t.get("gift") == true:
				_tint = GIFT_TINT
		_mat = _material(_tint)
		_rescan()
	_pick_axis()
	_mat.set_shader_parameter("axis", _axis)
	_measure()
	var h:= maxf(_top - _base, 0.2)
	if _kind == Kind.BUILD:
		_duration = clampf(BUILD_BASE + BUILD_PER_M * h, BUILD_MIN, BUILD_MAX)
		_lead = clampf(_toward_eye((_base + _top) * 0.5).length() / SPARK_SPEED,
			LEAD_MIN, LEAD_MAX)
	else:
		_duration = clampf(WRECK_BASE + WRECK_PER_M * h, WRECK_MIN, WRECK_MAX)
	if _only_belts():
		_duration *= BELT_PACE
		_lead *= BELT_PACE

	_mat.set_shader_parameter("dir", -1.0)
	_mat.set_shader_parameter("body", 0.55)
	_set_front(0.0)
	_make_sparks()
	if _kind == Kind.WRECK:

		_mat.set_shader_parameter("flash", 1.0)


func _only_belts() -> bool:
	var any:= false
	for t in _targets:
		if not _standing(t):
			continue
		if not (t is Conveyor or t is ConveyorCorner):
			return false
		any = true
	return any


func _rescan() -> void:
	_boxes.clear()
	_forget_gone()
	for b in _targets:


		if not _standing(b):
			continue
		for g in meshes_of(b as Node):
			_add_box(g)
			if _prev.has(g):
				continue
			_prev [g] = [g.material_override, g.material_overlay, g.cast_shadow]


			g.tree_exiting.connect(_on_mesh_leaving.bind(g), CONNECT_ONE_SHOT)


			if BeltBatch.instance != null and BeltBatch.instance.holds(g):
				BeltBatch.instance.drop(g)
				_lifted.append(g)
			g.material_override = _mat
			g.material_overlay = null
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pick_axis() -> void:
	_axis = Vector3.UP
	var first: Node3D = null
	var last: Node3D = null
	for t in _targets:
		if _standing(t) and (t is Conveyor or t is WaterMain or t is Railing or t is Roof):
			if first == null:
				first = t
			last = t
	if first != null:
		var run: Vector3 = (last.get("b") as Vector3) - (first.get("a") as Vector3)
		if run.length() > 0.3:
			_axis = run.normalized()
			return
	if _boxes.is_empty():
		return
	var box:= _world_box()
	if box.size.y >= 1.0 or box.size.y >= 0.5 * maxf(box.size.x, box.size.z):
		return
	_axis = Vector3.RIGHT if box.size.x >= box.size.z else Vector3.BACK
	if _eye != null and is_instance_valid(_eye) and (_eye.global_position - box.get_center()).dot(_axis) > 0.0:
		_axis = - _axis


func _span(box: AABB) -> Vector2:
	var half:= box.size * 0.5
	var r:= absf(_axis.x) * half.x + absf(_axis.y) * half.y + absf(_axis.z) * half.z
	var m:= box.get_center().dot(_axis)
	return Vector2(m - r, m + r)


func _measure() -> void:
	if _boxes.is_empty():
		for b in _targets:
			if _standing(b):
				_base = b.global_position.dot(_axis)
				_top = _base + 1.0
		return
	_base = INF
	_top = - INF
	for box in _boxes:
		var s:= _span(box)
		_base = minf(_base, s.x)
		_top = maxf(_top, s.y)


	if _axis != Vector3.UP:
		for t in _targets:
			if _standing(t) and (t is Conveyor or t is WaterMain or t is Railing or t is Roof):
				for end: Vector3 in [t.get("a"), t.get("b")]:
					_base = minf(_base, end.dot(_axis))
					_top = maxf(_top, end.dot(_axis))


func _front_at(p: float) -> float:
	var band:= 0.2
	if _kind == Kind.BUILD:
		return lerpf(_base - band, _top + band, 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 1.6))
	return lerpf(_top + band, _base - band, pow(clampf(p, 0.0, 1.0), 1.6))


func _set_front(p: float) -> void:
	_mat.set_shader_parameter("front", _front_at(p))


func _process(delta: float) -> void:
	_t += delta
	if _kind == Kind.BUILD:
		_tick_build(delta)
	else:
		_tick_wreck(delta)


func _tick_build(delta: float) -> void:


	var aim:= _t / _duration
	var p:= (_t - _lead) / _duration


	_rescan_clock += delta
	if p < 1.0 and (_rescans < RESCAN_EAGER or _rescan_clock >= RESCAN):
		_rescans += 1
		_rescan_clock = 0.0
		_rescan()
		_measure()
	if aim < 1.0:
		_spark_along_front(delta, _front_at(aim))
	elif _sparks.emitting:
		_sparks.emitting = false
	if p < 1.0:
		_set_front(maxf(p, 0.0))
		return

	var f:= (_t - _lead - _duration) / WRECK_TURN
	if f < 1.0:
		_set_front(1.0)
		_mat.set_shader_parameter("flash", f)
		return

	_land()
	var s:= (f - 1.0) * WRECK_TURN / SETTLE
	if s < 1.0:
		_mat.set_shader_parameter("fade", pow(1.0 - s, 1.6) * 0.8)
		return
	_restore()
	queue_free()


func _tick_wreck(delta: float) -> void:
	if _t < WRECK_TURN:
		_mat.set_shader_parameter("flash", 1.0 - _t / WRECK_TURN)
		return
	_mat.set_shader_parameter("flash", 0.0)
	var p:= (_t - WRECK_TURN) / _duration
	if p < 1.0:
		_set_front(p)
		_spark_along_front(delta, _front_at(p))
		return
	if _sparks.emitting:
		_sparks.emitting = false
		for c in _copies:
			c.visible = false
	if _t > WRECK_TURN + _duration + 1.6:
		queue_free()


func _land() -> void:
	if _landed:
		return
	_landed = true
	_mat.set_shader_parameter("front", -10000.0)
	_mat.set_shader_parameter("dir", 1.0)
	_mat.set_shader_parameter("edge_gain", 0.0)
	_mat.set_shader_parameter("body", 0.0)
	_mat.set_shader_parameter("flash", 1.0)
	_mat.set_shader_parameter("fade", 0.8)
	_forget_gone()
	for k in _prev.keys():
		if not is_instance_valid(k):
			continue
		var g:= k as GeometryInstance3D
		var was: Array = _prev [k]
		if g.material_override == _mat:
			g.material_override = was [0]
			if g.material_overlay == null:
				g.material_overlay = _mat
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			g.cast_shadow = was [2]


func _restore() -> void:
	if _restored:
		return
	_restored = true
	_forget_gone()
	for k in _prev.keys():
		if not is_instance_valid(k):
			continue
		var g:= k as GeometryInstance3D
		var was: Array = _prev [k]
		if g.material_override == _mat:
			g.material_override = was [0]
		if g.material_overlay == _mat or (not _landed and g.material_overlay == null):
			g.material_overlay = was [1]
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			g.cast_shadow = was [2]
	_prev.clear()


	for held in _lifted:
		if not is_instance_valid(held):
			continue
		var g:= held as GeometryInstance3D
		if g.is_inside_tree() and not g.is_queued_for_deletion():
			BeltBatch.adopt(g)
	_lifted.clear()


func _forget_gone() -> void:
	for k in _prev.keys():
		if is_instance_valid(k) and (k as Node).is_inside_tree():
			continue
		_give_back(k)
		_prev.erase(k)
	var kept: Array = []
	for held in _lifted:
		if is_instance_valid(held) and (held as Node).is_inside_tree():
			kept.append(held)
	_lifted = kept


func _on_mesh_leaving(g: Variant) -> void:
	_give_back(g)
	_prev.erase(g)
	_lifted.erase(g)


func _give_back(k: Variant) -> void:
	if not is_instance_valid(k) or not _prev.has(k):
		return
	var g:= k as GeometryInstance3D
	if g == null:
		return
	var was: Array = _prev [k]
	if g.material_override == _mat:
		g.material_override = was [0]
	if g.material_overlay == _mat:
		g.material_overlay = was [1]
	if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		g.cast_shadow = was [2]


static func _standing(n: Variant) -> bool:
	if not is_instance_valid(n):
		return false
	var node:= n as Node
	return node != null and node.is_inside_tree() and not node.is_queued_for_deletion()


func _exit_tree() -> void:


	_restore()


func _make_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "FrontSparks"
	var wreck:= _kind == Kind.WRECK
	_sparks.amount = 220
	_spark_img = Image.create(SPARK_POINTS, 1, false, Image.FORMAT_RGBF)
	_spark_tex = ImageTexture.create_from_image(_spark_img)
	var pm:= ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = _spark_tex
	pm.emission_point_count = SPARK_POINTS
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.0
	pm.damping_max = 0.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var tint:= wreck_tint() if wreck else _tint
	var size:= Curve.new()
	if wreck:


		_sparks.lifetime = clampf(_toward_eye(_top).length() / SPARK_SPEED, 0.25, 1.6)
		pm.spread = 12.0
		pm.initial_velocity_min = 7.0
		pm.initial_velocity_max = 12.0
		pm.color_ramp = _ramp(tint, false)
		size.add_point(Vector2(0.0, 1.0))
		size.add_point(Vector2(0.7, 0.8))
		size.add_point(Vector2(1.0, 0.0))
	else:


		var reach:= _toward_eye((_base + _top) * 0.5).length()
		_sparks.lifetime = _lead
		pm.spread = 3.0
		pm.initial_velocity_min = reach / _lead
		pm.initial_velocity_max = reach / _lead
		pm.color_ramp = _ramp(tint, true)
		size.add_point(Vector2(0.0, 0.0))
		size.add_point(Vector2(0.3, 0.8))
		size.add_point(Vector2(1.0, 1.0))
	var size_tex:= CurveTexture.new()
	size_tex.curve = size
	pm.scale_curve = size_tex
	_sparks.process_material = pm
	_sparks.draw_pass_1 = GlintParticles.draw_quad(0.16, 0.45, 0.4)
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.visibility_aabb = _world_box().grow(20.0)
	add_child(_sparks)
	_sparks.emitting = true


static func _ramp(tint: Color, inward: bool) -> GradientTexture1D:
	var hot:= Color(1.0, 1.0, 1.0, 1.0)
	var gone:= Color(tint.r, tint.g, tint.b, 0.0)
	var bright:= Color(tint.r * 1.5, tint.g * 1.5, tint.b * 1.5, 1.0)
	var g:= Gradient.new()
	g.set_color(0, gone if inward else hot)
	g.set_color(1, hot if inward else gone)
	g.add_point(0.75 if inward else 0.25, bright)
	var t:= GradientTexture1D.new()
	t.gradient = g
	return t


func _world_box() -> AABB:
	if _boxes.is_empty():
		return AABB(global_position, Vector3.ONE)
	var box:= _boxes [0]
	for b in _boxes:
		box = box.merge(b)
	return box


func _spark_along_front(delta: float, s: float) -> void:
	_spark_clock -= delta
	if _spark_clock > 0.0:
		return
	_spark_clock = SPARK_REFRESH
	var live: Array [AABB] = []
	var weight: Array [float] = []
	var total:= 0.0
	for box in _boxes:
		var span:= _span(box)
		if s < span.x - 0.05 or s > span.y + 0.05:
			continue


		var volume:= box.size.x * box.size.y * box.size.z
		var w:= sqrt(volume / maxf(span.y - span.x, 0.05)) + 0.05
		live.append(box)
		weight.append(w)
		total += w
	var pm:= _sparks.process_material as ParticleProcessMaterial
	if live.is_empty():
		_sparks.amount_ratio = 0.0
		return
	_sparks.amount_ratio = 1.0
	var out:= _toward_eye(s)
	var back:= Vector3.ZERO
	if _kind == Kind.BUILD:
		back = out.normalized() * pm.initial_velocity_min * _lead
		pm.direction = - out.normalized()
	else:
		pm.direction = out.normalized()
	for i in SPARK_POINTS:
		var pick:= _rng.randf() * total
		var k:= 0
		while k < live.size() - 1 and pick > weight [k]:
			pick -= weight [k]
			k += 1
		var box:= live [k]
		var p:= box.position + Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * box.size
		p += _axis * (s - p.dot(_axis)) + back
		_spark_img.set_pixel(i, 0, Color(p.x, p.y, p.z))


	_spark_tex.update(_spark_img.duplicate())


func _toward_eye(s: float) -> Vector3:
	if _eye == null or not is_instance_valid(_eye):
		return Vector3.UP
	var c:= _world_box().get_center()
	c += _axis * (s - c.dot(_axis))
	return _eye.global_position + Vector3(0.0, -0.35, 0.0) - c
