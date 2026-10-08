class_name ThrowAim
extends Node3D


enum { OFF, HOVER, PANEL }


signal pin_ended


const COL_HOVER:= Color(0.66, 0.68, 0.71, 0.88)

const COL_PANEL:= Color(1.0, 0.55, 0.12, 0.95)


const HOVER_HEIGHT:= 0.16
const BOB:= 0.05

const PERIOD:= 1.7

const PULSE:= 0.04


const CASCADE_HOVER:= 0.55
const CASCADE_PANEL:= 0.95

const SPIN:= 0.6


const REFRESH:= 0.25


const REFRESH_PANEL:= 1.0 / 30.0

const FADE:= 0.22

const GLIDE:= 12.0


const HIT_MASK:= Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD


var source: Node3D


var spot_radius:= 0.34


var arc_on_hover:= false

var _mode:= OFF
var _panel:= false
var _hovered:= false

var _pinned_left:= 0.0
var _arrow: MeshInstance3D
var _arrow_mat: ShaderMaterial
var _dot: MeshInstance3D
var _dot_mat: ShaderMaterial
var _arc: MeshInstance3D
var _arc_mat: ShaderMaterial

var _t:= 0.0


var _cascade:= 0.0
var _refresh_in:= 0.0

var _shown:= 0.0
var _orange:= 0.0
var _arc_shown:= 0.0

var _spot:= Vector3.ZERO
var _normal:= Vector3.UP
var _has_spot:= false

var _drawn_spot:= Vector3.ZERO
var _exclude: Array [RID] = []


static var _hover_aim: ThrowAim = null

static var _arrow_shader: Shader
static var _dot_shader: Shader
static var _arc_shader: Shader
static var _chevron_quad: QuadMesh


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_arrow_mat = _material(_shader_arrow())
	if _chevron_quad == null:
		_chevron_quad = QuadMesh.new()
	_arrow = _instance(_chevron_quad, _arrow_mat)


	_arrow.extra_cull_margin = 1.0
	_dot_mat = _material(_shader_dot())
	var quad:= PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_dot = _instance(quad, _dot_mat)
	_arc_mat = _material(_shader_arc())
	_arc = _instance(null, _arc_mat)

	_dot_mat.render_priority = 3
	_arc_mat.render_priority = 4
	_arrow_mat.render_priority = 5
	visible = false
	set_process(false)


func set_panel(on: bool) -> void:
	_panel = on
	_resolve()


func pin(seconds: float) -> void:
	var was:= _pinned_left > 0.0
	_pinned_left = maxf(seconds, 0.0)
	_resolve()
	if was and _pinned_left <= 0.0:
		pin_ended.emit()


func pinned_left() -> float:
	return _pinned_left


static func set_hovered(aim: ThrowAim) -> void:
	if aim == _hover_aim:
		return
	if is_instance_valid(_hover_aim):
		_hover_aim._hovered = false
		_hover_aim._resolve()
	_hover_aim = aim
	if aim != null:
		aim._hovered = true
		aim._resolve()


static func under_crosshair(from_node: Node3D, from: Vector3, look: Vector3) -> ThrowAim:
	if from_node == null or not from_node.is_inside_tree() or look == Vector3.ZERO:
		return null
	var space:= from_node.get_world_3d().direct_space_state
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + look.normalized() * Cfg.THROW_HOVER_REACH, HIT_MASK)
	var aim:= _aim_of(space.intersect_ray(q))
	if aim != null:
		return aim


	q.collide_with_areas = true
	return _aim_of(space.intersect_ray(q))


static func _aim_of(hit: Dictionary) -> ThrowAim:
	var node:= hit.get("collider") as Node
	while node != null:
		if node.has_method("throw_aim"):
			return node.call("throw_aim") as ThrowAim
		node = node.get_parent()
	return null


func _resolve() -> void:
	var mode:= PANEL if (_panel or _pinned_left > 0.0) else (HOVER if _hovered else OFF)
	var was:= _mode
	_mode = mode
	if mode == OFF:

		return
	_refresh_in = 0.0
	if not visible:
		visible = true
		set_process(true)
		_t = 0.0
		_orange = 1.0 if mode == PANEL else 0.0
		_refresh()
		_drawn_spot = _spot
	elif was != mode:
		_refresh()


func mode() -> int:
	return _mode


func _arc_wanted() -> bool:
	return _mode == PANEL or (_mode == HOVER and arc_on_hover)


func landing() -> Vector3:
	return _spot


func arc_drawn() -> bool:
	return _arc != null and _arc.mesh != null


func _process(delta: float) -> void:
	_t += delta
	if _pinned_left > 0.0:
		_pinned_left -= delta
		if _pinned_left <= 0.0:
			_pinned_left = 0.0
			_resolve()
			pin_ended.emit()
	var step:= delta / FADE
	_shown = move_toward(_shown, 0.0 if _mode == OFF else 1.0, step)
	_orange = move_toward(_orange, 1.0 if _mode == PANEL else 0.0, step)
	_arc_shown = move_toward(_arc_shown, 1.0 if _arc_wanted() else 0.0, step)
	if _mode == OFF and _shown <= 0.0:
		visible = false
		set_process(false)
		return

	_refresh_in -= delta
	if _refresh_in <= 0.0 and _mode != OFF:
		_refresh()

	_drawn_spot = _drawn_spot.lerp(_spot, 1.0 - exp(- GLIDE * delta))
	var wave:= sin(_t * TAU / PERIOD)
	var s:= 1.0 - PULSE * wave
	var up:= HOVER_HEIGHT + BOB * wave
	_arrow.global_transform = Transform3D(Basis.from_scale(Vector3(s, s, s)),
		_drawn_spot + Vector3.UP * up)

	var d:= spot_radius * (1.0 - 0.1 * wave) * (0.85 + 0.15 * _orange)
	_dot.global_transform = Transform3D(_basis_on(_normal).scaled(Vector3(d, d, d)),
		_drawn_spot + _normal * 0.03)

	_cascade = fmod(_cascade + delta * lerpf(CASCADE_HOVER, CASCADE_PANEL, _orange), 1.0)

	var tint:= COL_HOVER.lerp(COL_PANEL, _orange)
	var fade:= _shown * _shown * (3.0 - 2.0 * _shown)
	_arrow_mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, tint.a * fade))
	_arrow_mat.set_shader_parameter("cascade", _cascade)
	_dot_mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, 0.85 * fade))
	_dot_mat.set_shader_parameter("spin", fmod(_t * SPIN, TAU))
	_arc_mat.set_shader_parameter("tint",
		Color(tint.r, tint.g, tint.b, 0.85 * _arc_shown * fade))
	_arc.visible = _arc_shown > 0.0


func _refresh() -> void:
	_refresh_in = REFRESH_PANEL if _mode == PANEL else REFRESH
	if source == null or not is_instance_valid(source) or not source.is_inside_tree():
		return
	var path: Dictionary = source.call("throw_path")
	if path.is_empty():
		return
	var points: Array = LaunchArc.sample(path ["from"], path ["velocity"],
		float(path ["ground_y"]), bool(path.get("damped", true)))
	if points.size() < 2:
		return
	if _exclude.is_empty():
		for body in source.find_children("*", "CollisionObject3D", true, false):
			_exclude.append((body as CollisionObject3D).get_rid())
	var cut:= _first_contact(points)
	points = cut ["points"]
	_spot = cut ["at"]
	_normal = cut ["normal"]
	if not _has_spot:
		_drawn_spot = _spot
		_has_spot = true


	if _arc_wanted() or _arc_shown > 0.0:
		_arc.mesh = _ribbon(points)
		var metres:= _length(points)
		_arc_mat.set_shader_parameter("length_m", metres)


		_arc_mat.set_shader_parameter("dash", clampf(metres / 8.0, 0.1, 0.34))
	else:
		_arc.mesh = null


func _first_contact(points: Array) -> Dictionary:
	var space:= get_world_3d().direct_space_state
	for i in points.size() - 1:
		var a: Vector3 = points [i]
		var b: Vector3 = points [i + 1]
		var q:= PhysicsRayQueryParameters3D.create(a, b, HIT_MASK, _exclude)
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			continue
		var at: Vector3 = hit ["position"]
		var out:= points.slice(0, i + 1)
		out.append(at)
		var n: Vector3 = hit ["normal"]
		return { "points": out, "at": at, "normal": n if n.length_squared() > 0.5 else Vector3.UP }
	return { "points": points, "at": points [points.size() - 1], "normal": Vector3.UP }


static func _length(points: Array) -> float:
	var total:= 0.0
	for i in points.size() - 1:
		total += (points [i + 1] as Vector3).distance_to(points [i])
	return total


func _ribbon(points: Array) -> ArrayMesh:
	var verts:= PackedVector3Array()
	var normals:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	var idx:= PackedInt32Array()
	var along:= 0.0
	for i in points.size():
		var p: Vector3 = points [i]
		if i > 0:
			along += p.distance_to(points [i - 1])
		var ahead: Vector3 = points [mini(i + 1, points.size() - 1)]
		var back: Vector3 = points [maxi(i - 1, 0)]
		var dir:= ahead - back
		if dir.length_squared() < 1e-08:
			dir = Vector3.DOWN
		dir = dir.normalized()
		for side in 2:
			verts.append(p)
			normals.append(dir)
			uvs.append(Vector2(along, float(side)))
	for i in points.size() - 1:
		var o:= i * 2
		idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	arrays [Mesh.ARRAY_INDEX] = idx
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var box:= mesh.get_aabb().grow(0.2)
	mesh.custom_aabb = box
	return mesh


static func _basis_on(n: Vector3) -> Basis:
	var up:= n.normalized()
	var ref:= Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x:= ref.cross(up).normalized()
	var z:= x.cross(up).normalized()
	return Basis(x, up, z)


func _instance(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	return mi


static func _material(shader: Shader) -> ShaderMaterial:
	var m:= ShaderMaterial.new()
	m.shader = shader
	return m


static func _shader_arrow() -> Shader:
	if _arrow_shader == null:
		_arrow_shader = Shader.new()
		_arrow_shader.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled, skip_vertex_transform;\nuniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 0.9);\nuniform float cascade = 0.0;\n// The quad in metres, and how far below the lowest point its bottom edge is.\nconst vec2 SIZE = vec2(0.50, 0.60);\nconst float BASE = 0.06;\n// Half the span of a chevron, how steeply its arms rise, how thick it is\n// across the band, the step between chevrons, and the dark edge.\nconst float HALF = 0.20;\nconst float RISE = 0.62;\nconst float THICK = 0.055;\nconst float GAP = 0.15;\nconst float EDGE = 0.018;\nvec2 local(vec2 uv) {\n\treturn vec2((uv.x - 0.5) * SIZE.x, (1.0 - uv.y) * SIZE.y - BASE);\n}\nvoid vertex() {\n\tfloat s = length(MODEL_MATRIX[0].xyz);\n\tVERTEX = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + vec3(local(UV) * s, 0.0);\n\tNORMAL = vec3(0.0, 0.0, 1.0);\n}\nvoid fragment() {\n\tvec2 q = local(UV);\n\tfloat across = inversesqrt(1.0 + RISE * RISE);\n\tfloat best = 1e3;\n\tfloat lit = 0.0;\n\tfor (int k = 0; k < 3; k++) {\n\t\tfloat v = (q.y - float(k) * GAP - RISE * abs(q.x)) * across;\n\t\tfloat d = max(abs(v - THICK * 0.5) - THICK * 0.5, abs(q.x) - HALF);\n\t\tif (d < best) {\n\t\t\tbest = d;\n\t\t\tfloat ph = fract(cascade + float(k) * 0.22);\n\t\t\tlit = exp(-ph * ph * 14.0) + exp(-(1.0 - ph) * (1.0 - ph) * 14.0);\n\t\t}\n\t}\n\tfloat aa = max(fwidth(best), 1e-5);\n\tfloat body = 1.0 - smoothstep(-aa, aa, best);\n\tfloat edge = 1.0 - smoothstep(EDGE - aa, EDGE + aa, best);\n\tfloat core = 1.0 - smoothstep(-THICK * 0.30 - aa, -THICK * 0.30 + aa, best);\n\tfloat glow = 0.35 + 0.65 * lit;\n\tvec3 col = tint.rgb * (0.78 + 0.30 * lit);\n\tcol = mix(col, vec3(1.0, 0.96, 0.88), 0.40 * lit * core);\n\tALBEDO = mix(vec3(0.03, 0.025, 0.02), col, body);\n\tALPHA = tint.a * glow * max(body, 0.6 * edge);\n}\n"


	return _arrow_shader


static func _shader_dot() -> Shader:
	if _dot_shader == null:
		_dot_shader = Shader.new()
		_dot_shader.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;\nuniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 0.7);\nuniform float spin = 0.0;\nfloat band(float x, float lo, float hi, float aa) {\n\treturn smoothstep(lo - aa, lo + aa, x) * (1.0 - smoothstep(hi - aa, hi + aa, x));\n}\nvoid fragment() {\n\tvec2 p = (UV - 0.5) * 2.0;\n\tfloat r = length(p);\n\tfloat aa = max(fwidth(r), 1e-4);\n\tfloat core = (1.0 - smoothstep(0.0, 0.55, r)) * 0.35;\n\tfloat step_a = TAU * 0.25;\n\tfloat from_tick = abs((fract((atan(p.y, p.x) + spin) / step_a + 0.5) - 0.5) * step_a * r);\n\tfloat ring = band(r, 0.62, 0.71, aa);\n\tfloat tick = (1.0 - smoothstep(0.045 - aa, 0.045 + aa, from_tick)) * band(r, 0.80, 0.97, aa);\n\tfloat mark = max(ring, tick);\n\tfloat wide = max(band(r, 0.58, 0.75, aa),\n\t\t(1.0 - smoothstep(0.085 - aa, 0.085 + aa, from_tick)) * band(r, 0.76, 1.0, aa));\n\tfloat lit = clamp(mark + 1.0 - smoothstep(0.50, 0.58, r), 0.0, 1.0);\n\tALBEDO = mix(vec3(0.03, 0.025, 0.02), tint.rgb, lit);\n\tALPHA = tint.a * max(max(core, mark), 0.30 * wide);\n}\n"


	return _dot_shader


static func _shader_arc() -> Shader:
	if _arc_shader == null:
		_arc_shader = Shader.new()
		_arc_shader.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled, skip_vertex_transform;\nuniform vec4 tint : source_color = vec4(1.0, 0.55, 0.12, 0.85);\nuniform float width = 0.065;\nuniform float dash = 0.34;\nuniform float duty = 0.55;\nuniform float flow = 0.55;\nuniform float length_m = 1.0;\nvoid vertex() {\n\tvec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tvec3 t = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);\n\tvec3 side = cross(t, normalize(-p));\n\tfloat l = length(side);\n\tside = l > 0.0001 ? side / l : vec3(1.0, 0.0, 0.0);\n\tVERTEX = p + side * width * (UV.y - 0.5);\n\tNORMAL = vec3(0.0, 0.0, 1.0);\n}\nvoid fragment() {\n\tfloat d = (UV.x - TIME * flow) / dash;\n\tfloat f = fract(d);\n\tfloat aa = max(fwidth(d), 0.0001);\n\tfloat on = smoothstep(0.0, aa, f) * (1.0 - smoothstep(duty - aa, duty, f));\n\tfloat fin = min(0.8, length_m * 0.25);\n\tfloat ends = smoothstep(0.0, fin, UV.x) * (1.0 - smoothstep(length_m - fin, length_m - fin * 0.25, UV.x));\n\tALBEDO = tint.rgb;\n\tALPHA = tint.a * on * ends;\n}\n"


	return _arc_shader
