class_name BeltSweep
extends RefCounted


const CARRY_HW:= 0.42
const CARRY_T:= 0.016

const RETURN_TOP:= -0.196
const RETURN_T:= 0.013


const STR_Y1:= -0.05
const STR_Y0:= -0.17
const STR_WEB_X0:= 0.393
const STR_WEB_X1:= 0.405
const STR_FL_X:= 0.455
const STR_FL_T:= 0.012


const SKIRT_Y0:= -0.006
const LIP_X:= 0.482
const LIP_Y:= 0.118


const IDLER_R:= 0.055
const IDLER_HL:= 0.395


const BOLT_R:= 0.009
const BOLT_T:= 0.007
const BOLT_Y:= 0.055
const BOLT_STANDOFF:= 0.003


const IDLER_PITCH:= 1.0
const BOLT_PITCH:= 0.5


const BARREL_SEGS:= 18
const BOLT_SEGS:= 6


const CUSP_KEEP:= 0.15


const CUSP_SPAN:= 4.0


static func frames(pts: PackedVector3Array) -> Array:
	var out: Array = []
	var n:= pts.size()
	if n < 2:
		return out
	var dirs: Array [Vector3] = []
	for i in n - 1:
		var d:= pts [i + 1] - pts [i]
		dirs.append(d.normalized() if d.length_squared() > 1e-12 else Vector3.BACK)
	var last:= dirs.size() - 1
	var s:= 0.0
	for i in n:
		var t: Vector3
		if i == 0:
			t = dirs [0] * 1.5 - dirs [mini(1, last)] * 0.5
		elif i == n - 1:
			t = dirs [last] * 1.5 - dirs [maxi(last - 1, 0)] * 0.5
		else:
			t = dirs [i - 1] + dirs [i]
		if i > 0:
			s += pts [i - 1].distance_to(pts [i])
		if t.length_squared() < 1e-08:
			t = Vector3.BACK
		t = t.normalized()
		var ax:= Vector3.UP.cross(t)
		if ax.length_squared() < 1e-08:
			ax = Vector3.RIGHT
		ax = ax.normalized()
		out.append([pts [i], ax, t.cross(ax).normalized(), t, s,
			Vector2(- CUSP_SPAN, CUSP_SPAN)])
	_bound_across(out)
	return out


static func _bound_across(fr: Array) -> void:
	for i in fr.size() - 1:
		var a: Array = fr [i]
		var b: Array = fr [i + 1]
		var t: Vector3 = a [3]
		var adv: float = ((b [0] as Vector3) - (a [0] as Vector3)).dot(t)
		var drift: float = ((b [1] as Vector3) - (a [1] as Vector3)).dot(t)
		if adv <= 1e-09 or absf(drift) < 1e-09:
			continue
		var x: float = - adv * (1.0 - CUSP_KEEP) / drift
		for f: Array in [a, b]:
			var lim: Vector2 = f [5]
			if drift > 0.0:

				lim.x = maxf(lim.x, minf(x, 0.0))
			else:
				lim.y = minf(lim.y, maxf(x, 0.0))
			f [5] = lim


static func length_of(fr: Array) -> float:
	return 0.0 if fr.is_empty() else float(fr [fr.size() - 1] [4])


static func slice(fr: Array, from_s: float, to_s: float) -> Array:
	if fr.size() < 2 or to_s - from_s < 0.001:
		return []
	var out: Array = [_ring_at(fr, from_s)]
	for f: Array in fr:
		var s:= float(f [4])
		if s > from_s + 0.0005 and s < to_s - 0.0005:
			out.append(f)
	out.append(_ring_at(fr, to_s))
	return out


static func _ring_at(fr: Array, s: float) -> Array:
	var last: int = fr.size() - 1
	if s <= float(fr [0] [4]):
		return fr [0]
	if s >= float(fr [last] [4]):
		return fr [last]
	for i in last:
		var lo: Array = fr [i]
		var hi: Array = fr [i + 1]
		var a:= float(lo [4])
		var b:= float(hi [4])
		if s > b or b - a < 1e-06:
			continue
		var t:= (s - a) / (b - a)


		var lo_lim: Vector2 = lo [5]
		var hi_lim: Vector2 = hi [5]
		return [(lo [0] as Vector3).lerp(hi [0], t),
			((lo [1] as Vector3).lerp(hi [1], t)).normalized(),
			((lo [2] as Vector3).lerp(hi [2], t)).normalized(),
			((lo [3] as Vector3).lerp(hi [3], t)).normalized(), s,
			Vector2(maxf(lo_lim.x, hi_lim.x), minf(lo_lim.y, hi_lim.y))]
	return fr [last]


static func deck_mesh(fr: Array) -> ArrayMesh:
	if fr.size() < 2:
		return null
	var mesh:= ArrayMesh.new()
	var vk:= _v_scale(length_of(fr))
	var span:= length_of(fr)

	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_skin(st, fr, _box_loop(CARRY_HW, - CARRY_T, 0.0), vk)
	_skin(st, fr, _box_loop(CARRY_HW, RETURN_TOP - RETURN_T, RETURN_TOP), vk)
	_close(mesh, st, ConveyorKit.belt_material())

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1, 1]:
		_skin(st, fr, _stringer_loop(side), vk)
	_close(mesh, st, ConveyorKit.frame_material())

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n:= maxi(1, int(round(span / IDLER_PITCH)))
	for i in n:
		_barrel(st, _ring_at(fr, span * (float(i) + 0.5) / float(n)),
			- IDLER_HL, IDLER_HL, - (CARRY_T + IDLER_R), IDLER_R,
			BARREL_SEGS, false)
	_close(mesh, st, ConveyorKit.drum_material())
	return mesh


static func rail_mesh(fr: Array, side: int,
		stretches: Array [Vector2]) -> ArrayMesh:
	if fr.size() < 2 or stretches.is_empty():
		return null
	var vk:= _v_scale(length_of(fr))
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any:= false
	for seg in stretches:
		var part:= slice(fr, seg.x, seg.y)
		if part.size() < 2:
			continue
		any = true
		_skin(st, part, _skirt_loop(side), vk)
		var span:= seg.y - seg.x
		var n:= maxi(1, int(round(span / BOLT_PITCH)))
		var x0: float = float(side) * (Cfg.BELT_WIDTH * 0.5 + BOLT_STANDOFF)
		for i in n:
			_barrel(st, _ring_at(fr, seg.x + span * (float(i) + 0.5) / float(n)),
				x0 - float(side) * BOLT_T * 0.5, x0 + float(side) * BOLT_T * 0.5,
				BOLT_Y, BOLT_R, BOLT_SEGS, true)
	if not any:
		return null
	var mesh:= ArrayMesh.new()
	_close(mesh, st, ConveyorKit.frame_material())
	return mesh


static func held_copy(mesh: ArrayMesh) -> ArrayMesh:
	if mesh == null:
		return null
	var out:= ArrayMesh.new()
	var running:= ConveyorKit.belt_material()
	for i in mesh.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			mesh.surface_get_arrays(i))
		var m:= mesh.surface_get_material(i)
		out.surface_set_material(i,
			ConveyorKit.belt_material_held() if m == running else m)
	return out


static func _box_loop(hw: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(- hw, y0), Vector2(hw, y0),
		Vector2(hw, y1), Vector2(- hw, y1)])


static func _stringer_loop(side: int) -> PackedVector2Array:
	var s:= float(side)
	return PackedVector2Array([
		Vector2(s * STR_WEB_X0, STR_Y1), Vector2(s * STR_FL_X, STR_Y1),
		Vector2(s * STR_FL_X, STR_Y1 - STR_FL_T),
		Vector2(s * STR_WEB_X1, STR_Y1 - STR_FL_T),
		Vector2(s * STR_WEB_X1, STR_Y0 + STR_FL_T),
		Vector2(s * STR_FL_X, STR_Y0 + STR_FL_T),
		Vector2(s * STR_FL_X, STR_Y0), Vector2(s * STR_WEB_X0, STR_Y0)])


static func _skirt_loop(side: int) -> PackedVector2Array:
	var s:= float(side)
	var x_in:= Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T
	var x_out:= Cfg.BELT_WIDTH * 0.5
	return PackedVector2Array([
		Vector2(s * x_in, SKIRT_Y0), Vector2(s * x_out, SKIRT_Y0),
		Vector2(s * x_out, LIP_Y), Vector2(s * LIP_X, LIP_Y),
		Vector2(s * LIP_X, Cfg.BELT_RAIL_H),
		Vector2(s * x_in, Cfg.BELT_RAIL_H)])


static func _v_scale(span: float) -> float:
	if span < 0.001:
		return 1.0
	var whole:= maxf(1.0, roundf(span / ConveyorKit.CLEAT_PITCH))
	return whole * ConveyorKit.CLEAT_PITCH / span


static func _skin(st: SurfaceTool, fr: Array, loop: PackedVector2Array,
		vk: float) -> void:
	var pts:= _ccw(loop)
	var k:= pts.size()
	for e in k:
		var a: Vector2 = pts [e]
		var b: Vector2 = pts [(e + 1) % k]
		var d:= b - a
		if d.length_squared() < 1e-12:
			continue

		var fn:= Vector2(d.y, - d.x).normalized()


		var across:= absf(fn.x) > absf(fn.y)
		for i in fr.size() - 1:
			var lo: Array = fr [i]
			var hi: Array = fr [i + 1]
			var v_lo:= float(lo [4]) * vk
			var v_hi:= float(hi [4]) * vk
			var uv: Array [Vector2] = []
			if across:
				uv = [Vector2(v_lo, a.y), Vector2(v_lo, b.y),
					Vector2(v_hi, b.y), Vector2(v_hi, a.y)]
			else:
				uv = [Vector2(a.x, v_lo), Vector2(b.x, v_lo),
					Vector2(b.x, v_hi), Vector2(a.x, v_hi)]
			_quad(st, [_on(lo, a), _on(lo, b), _on(hi, b), _on(hi, a)],
				[_dir(lo, fn), _dir(lo, fn), _dir(hi, fn), _dir(hi, fn)], uv)
	_cap(st, fr [0], pts, false)
	_cap(st, fr [fr.size() - 1], pts, true)


static func _cap(st: SurfaceTool, f: Array, pts: PackedVector2Array,
		ahead: bool) -> void:
	var idx:= Geometry2D.triangulate_polygon(pts)
	var face: Vector3 = (f [3] as Vector3) * (1.0 if ahead else -1.0)
	for t in idx.size() / 3:
		var a: Vector2 = pts [idx [t * 3]]
		var b: Vector2 = pts [idx [t * 3 + 1]]
		var c: Vector2 = pts [idx [t * 3 + 2]]

		_tri(st, [_on(f, a), _on(f, b), _on(f, c)], face, [a, b, c])


static func _on(f: Array, p: Vector2) -> Vector3:
	var lim: Vector2 = f [5]
	return (f [0] as Vector3) + (f [1] as Vector3) * clampf(p.x, lim.x, lim.y) + (f [2] as Vector3) * p.y


static func _dir(f: Array, n: Vector2) -> Vector3:
	return ((f [1] as Vector3) * n.x + (f [2] as Vector3) * n.y).normalized()


static func _barrel(st: SurfaceTool, f: Array, x0: float, x1: float,
		cy: float, r: float, segs: int, caps: bool) -> void:


	var lim: Vector2 = f [5]
	var want:= absf(x1 - x0)
	x0 = clampf(x0, lim.x, lim.y)
	x1 = clampf(x1, lim.x, lim.y)


	if want > 0.001 and absf(x1 - x0) < 0.001:
		return
	var ax: Vector3 = f [1]
	var up: Vector3 = f [2]
	var fwd: Vector3 = f [3]
	var lo:= (f [0] as Vector3) + ax * x0
	var hi:= (f [0] as Vector3) + ax * x1


	var along:= ax if is_equal_approx(x0, x1) else (hi - lo).normalized()


	for j in segs:
		var pa:= TAU * float(j) / float(segs)
		var pb:= TAU * float(j + 1) / float(segs)
		var na:= (up * cos(pa) + fwd * sin(pa)).normalized()
		var nb:= (up * cos(pb) + fwd * sin(pb)).normalized()
		var oa:= up * cy + na * r
		var ob:= up * cy + nb * r
		_quad(st, [lo + oa, lo + ob, hi + ob, hi + oa], [na, nb, nb, na],
			[Vector2(x0, r * pa), Vector2(x0, r * pb),
			Vector2(x1, r * pb), Vector2(x1, r * pa)])
		if not caps:
			continue
		_tri(st, [lo + up * cy, lo + oa, lo + ob], - along,
			[Vector2(x0, 0.0), Vector2(x0, r * pa), Vector2(x0, r * pb)])
		_tri(st, [hi + up * cy, hi + oa, hi + ob], along,
			[Vector2(x1, 0.0), Vector2(x1, r * pa), Vector2(x1, r * pb)])


static func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	var wound: Vector3 = ((p [1] as Vector3) - p [0]).cross((p [2] as Vector3) - p [0])
	var order:= [0, 1, 2, 0, 2, 3] if wound.dot(n [0]) < 0.0 else [0, 3, 2, 0, 2, 1]
	for i: int in order:
		st.set_normal(n [i])
		st.set_uv(uv [i])
		st.add_vertex(p [i])


static func _tri(st: SurfaceTool, p: Array, face: Vector3, uv: Array) -> void:
	var wound: Vector3 = ((p [1] as Vector3) - p [0]).cross((p [2] as Vector3) - p [0])
	var order:= [0, 1, 2] if wound.dot(face) < 0.0 else [0, 2, 1]
	for i: int in order:
		st.set_normal(face)
		st.set_uv(uv [i])
		st.add_vertex(p [i])


static func _ccw(loop: PackedVector2Array) -> PackedVector2Array:
	var area:= 0.0
	var n:= loop.size()
	for i in n:
		var a:= loop [i]
		var b:= loop [(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return loop
	var out:= PackedVector2Array()
	for i in n:
		out.append(loop [n - 1 - i])
	return out


static func _close(mesh: ArrayMesh, st: SurfaceTool, m: Material) -> void:
	st.generate_tangents()
	st.set_material(m)
	st.commit(mesh)
