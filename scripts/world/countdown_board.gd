class_name CountdownBoard
extends Node3D


const TOTAL_SECONDS:= 24 * 60 * 60


const SCR_W:= 1.72
const SCR_H:= 0.44


const DIGIT_H:= 0.68
const CELL_W:= 0.58
const CELL_GAP:= 0.17
const COLON_W:= 0.22


const DIM_Z:= 0.004
const LIT_Z:= 0.007


const DOT_AT:= [0.28, 0.7]


const SEG_KEYS:= "abcdefg"
const SEG_T:= 0.11
const SEG_GAP:= 0.014
const SLANT:= 0.08
const GLYPH:= {
	"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg",
	"5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}


const BLINK_SECONDS:= 0.75


const TICK_DB:= -9.0


const HEARD_WITHIN:= 24.0


const AUDIBLE:= false


signal expired()


var lit_material: Material
var dim_material: Material


var player: Node3D


var _slot:= 0


var armed:= false

var _lit: MeshInstance3D
var _dim: MeshInstance3D


var _cells: Array [Dictionary] = []


var _shown:= -1
var _blink:= 0.0
var _announced:= false


var _tock_next:= false


var _last_strike:= ""
var _strikes:= 0


func _ready() -> void:
	_slot = SaveManager.current_slot


	Profile.countdown_slot = _slot
	_cells = _layout()
	_dim = _layer("Ghost", DIM_Z)
	_wear(_dim, _mesh(_all_on()), dim_material)
	_lit = _layer("Digits", LIT_Z)
	_refresh()


func _exit_tree() -> void:


	if Profile.countdown_slot == _slot:
		Profile.countdown_slot = -1


func arm() -> void:
	armed = true


func slot() -> int:
	return _slot


func remaining() -> int:
	return clampi(TOTAL_SECONDS - Profile.countdown_spent_in(_slot),
		0, TOTAL_SECONDS)


func reading() -> String:
	return format_clock(maxi(_shown, 0))


func is_spent() -> bool:
	return remaining() <= 0


func last_strike() -> String:
	return _last_strike


func strike_count() -> int:
	return _strikes


func ghost_bounds() -> AABB:
	return _dim.get_aabb() if _dim != null and _dim.mesh != null else AABB()


func _process(delta: float) -> void:
	_refresh()
	if _shown > 0:


		if not _lit.visible:
			_lit.visible = true
		return
	_blink += delta
	if _blink >= BLINK_SECONDS:
		_blink -= BLINK_SECONDS
		_lit.visible = not _lit.visible
	if armed and not _announced:
		_announced = true
		expired.emit()


func _refresh() -> void:
	var left:= remaining()
	if left == _shown:
		return
	var had:= _shown
	_shown = left
	_wear(_lit, _mesh(_on_for(format_clock(left))), lit_material)


	if had > 0:
		_tick()


func _tick() -> void:
	_last_strike = ""
	if player == null:
		return
	var at:= global_position
	if player.global_position.distance_to(at) > HEARD_WITHIN:
		return
	_last_strike = "clock_tock" if _tock_next else "clock_tick"
	_strikes += 1
	if AUDIBLE:
		Audio.play_3d(_last_strike, at, TICK_DB)
	_tock_next = not _tock_next


func _layer(node_name: String, z: float) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.name = node_name
	mi.position.z = z


	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _wear(mi: MeshInstance3D, mesh: ArrayMesh, mat: Material) -> void:
	mi.mesh = mesh
	if mat == null:
		return
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, mat)


func _layout() -> Array [Dictionary]:
	var h:= SCR_H * DIGIT_H
	var pattern:= "88:88:88"
	var total:= 0.0
	for i in pattern.length():
		total += (COLON_W if pattern [i] == ":" else CELL_W) * h
	total += CELL_GAP * h * float(pattern.length() - 1)
	var x:= - total * 0.5
	var out: Array [Dictionary] = []
	for i in pattern.length():
		var colon:= pattern [i] == ":"
		var w:= (COLON_W if colon else CELL_W) * h
		out.append({ "x": x, "w": w, "colon": colon })
		x += w + CELL_GAP * h
	return out


func _on_for(text: String) -> Array [String]:
	var out: Array [String] = []
	for i in _cells.size():
		var ch:= text [i] if i < text.length() else " "
		if bool(_cells [i] ["colon"]):
			out.append(":" if ch == ":" else "")
		else:
			out.append(str(GLYPH.get(ch, "")))
	return out


func _all_on() -> Array [String]:
	var out: Array [String] = []
	for cell: Dictionary in _cells:
		out.append(":" if bool(cell ["colon"]) else "abcdefg")
	return out


func _mesh(on: Array [String]) -> ArrayMesh:
	var h:= SCR_H * DIGIT_H
	var bottom:= - h * 0.5
	var verts:= PackedVector3Array()
	var normals:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	for i in _cells.size():
		var cell:= _cells [i]
		var x0: float = cell ["x"]
		var w: float = cell ["w"]
		var lit: String = on [i] if i < on.size() else ""
		if lit.is_empty():
			continue
		if bool(cell ["colon"]):
			var hw:= SEG_T * 0.5
			var cx:= COLON_W * 0.5
			for f: float in DOT_AT:
				_polygon(verts, normals, uvs, PackedVector2Array([
					Vector2(cx - hw, f - hw), Vector2(cx + hw, f - hw),
					Vector2(cx + hw, f + hw), Vector2(cx - hw, f + hw)]),
					x0, bottom, w, h)
			continue
		for key: String in SEG_KEYS:
			if lit.contains(key):
				_polygon(verts, normals, uvs, segment(key), x0, bottom, w, h)
	var mesh:= ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func segment(key: String) -> PackedVector2Array:
	var hw:= SEG_T * 0.5
	var xl:= hw
	var xr:= CELL_W - hw
	var yb:= hw
	var yt:= 1.0 - hw
	match key:
		"a": return _bar(xl, xr, yt)
		"g": return _bar(xl, xr, 0.5)
		"d": return _bar(xl, xr, yb)
		"b": return _post(xr, 0.5, yt)
		"c": return _post(xr, yb, 0.5)
		"e": return _post(xl, yb, 0.5)
		"f": return _post(xl, 0.5, yt)
	return PackedVector2Array()


static func _bar(x0: float, x1: float, y: float) -> PackedVector2Array:
	var hw:= SEG_T * 0.5
	var l:= x0 + SEG_GAP
	var r:= x1 - SEG_GAP
	return PackedVector2Array([Vector2(l, y), Vector2(l + hw, y - hw),
		Vector2(r - hw, y - hw), Vector2(r, y), Vector2(r - hw, y + hw),
		Vector2(l + hw, y + hw)])


static func _post(x: float, y0: float, y1: float) -> PackedVector2Array:
	var hw:= SEG_T * 0.5
	var b:= y0 + SEG_GAP
	var t:= y1 - SEG_GAP
	return PackedVector2Array([Vector2(x, b), Vector2(x + hw, b + hw),
		Vector2(x + hw, t - hw), Vector2(x, t), Vector2(x - hw, t - hw),
		Vector2(x - hw, b + hw)])


static func _polygon(verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, pts: PackedVector2Array, x0: float, bottom: float,
		w: float, h: float) -> void:
	var p:= PackedVector3Array()
	var uv:= PackedVector2Array()
	for q: Vector2 in pts:
		var x:= x0 + (q.x + (q.y - 0.5) * SLANT) * h
		p.append(Vector3(x, bottom + q.y * h, 0.0))
		uv.append(Vector2((x - x0) / w, 1.0 - q.y))


	for i in range(1, p.size() - 1):
		verts.append_array([p [0], p [i + 1], p [i]])
		uvs.append_array([uv [0], uv [i + 1], uv [i]])
		for _j in 3:
			normals.append(Vector3.BACK)


static func format_clock(secs: int) -> String:
	var s:= maxi(secs, 0)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
