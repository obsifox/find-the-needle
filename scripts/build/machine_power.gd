class_name MachinePower
extends RefCounted


const PORT_NAMES:= ["Marker_WirePort", "Marker_WirePortA", "Marker_WirePortB"]


const STAND_IN_INSET:= 0.16


const MIN_LOOP_PITCH:= 0.55


static func terminals(machine: Node3D, model: Node3D, want: int,
		fallbacks: Array [Vector3] = [], mats: Dictionary = { }) -> Array [Node3D]:
	var out: Array [Node3D] = []
	if model != null:
		for port_name in PORT_NAMES:
			var node:= model.find_child(port_name, true, false) as Node3D
			if node != null:
				out.append(node)
	if not out.is_empty():
		strip_leads(model, out)
		return out


	var explicit:= not fallbacks.is_empty()
	var host: Node3D = model if (explicit and model != null) else machine
	var at:= fallbacks if explicit else stand_in_points(machine, want)
	for i in at.size():
		out.append(fitting(host, at [i], "WirePort%d" % i, mats))
	return out


static func fitting(host: Node3D, base: Vector3, port_name: String,
		mats: Dictionary = { }) -> Node3D:
	var root:= Node3D.new()
	root.name = port_name + "Fitting"
	root.position = base
	host.add_child(root)
	var galv: Material = mats.get("steel", null)
	if galv == null:
		galv = _flat(Color(0.62, 0.645, 0.66), 0.5, 0.7)
	var porcelain: Material = mats.get("porcelain", null)
	if porcelain == null:
		porcelain = _flat(Color(0.93, 0.915, 0.88), 0.16, 0.0)
	var copper: Material = mats.get("copper", null)
	if copper == null:
		copper = _flat(Color(0.55, 0.26, 0.1), 0.36, 0.9)


	var inst:= MeshInstance3D.new()
	inst.name = "Fitting"
	inst.mesh = _part("fitting mesh", _new_fitting_mesh) as ArrayMesh
	inst.set_surface_override_material(0, galv)
	inst.set_surface_override_material(1, porcelain)
	inst.set_surface_override_material(2, copper)
	root.add_child(inst)
	var port:= Node3D.new()
	port.name = port_name
	port.position = Vector3(0.0, FITTING_WIRE_UP, 0.0)
	root.add_child(port)
	return port


const FITTING_WIRE_UP:= 0.016 + 0.2 + 0.014 + 0.09 + 0.15


static func mast(host: Node3D, foot: Vector3, height: float, tie: Vector3,
		port_name: String) -> Node3D:
	var root:= Node3D.new()
	root.name = port_name + "Mast"
	root.position = foot
	host.add_child(root)
	var galv:= _flat(Color(0.62, 0.645, 0.66), 0.5, 0.7)
	var reach:= Vector3(tie.x - foot.x, 0.0, tie.z - foot.z)
	var arm_y:= height - 0.07
	var end:= reach + Vector3(0.0, arm_y, 0.0)
	var inst:= MeshInstance3D.new()
	inst.name = "Mast"
	var build:= func() -> Resource: return _new_mast_mesh(height, reach)
	inst.mesh = _part("mast mesh %.3f %s" % [height, reach], build) as ArrayMesh
	inst.material_override = galv
	root.add_child(inst)
	return fitting(root, end + Vector3(0.0, 0.04, 0.0), port_name)


const TURN_SIDES:= 48


const INS_PROFILE:= [
	Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.048, 0.004),
	Vector2(0.051, 0.009), Vector2(0.052, 0.016), Vector2(0.0515, 0.022),
	Vector2(0.049, 0.028), Vector2(0.043, 0.033), Vector2(0.034, 0.037),
	Vector2(0.033, 0.052), Vector2(0.041, 0.058), Vector2(0.046, 0.064),
	Vector2(0.048, 0.07), Vector2(0.0475, 0.076), Vector2(0.045, 0.082),
	Vector2(0.039, 0.087), Vector2(0.031, 0.091), Vector2(0.03, 0.106),
	Vector2(0.036, 0.113), Vector2(0.044, 0.124), Vector2(0.045, 0.14),
	Vector2(0.038, 0.148), Vector2(0.037, 0.152), Vector2(0.044, 0.16),
	Vector2(0.045, 0.174), Vector2(0.041, 0.184), Vector2(0.03, 0.192),
	Vector2(0.018, 0.196), Vector2(0.0, 0.196)]
const INS_GROOVE_Y:= 0.15


static func _new_fitting_mesh() -> ArrayMesh:
	var steel:= _buffer()
	var porcelain:= _buffer()
	var copper:= _buffer()
	var flat:= 0.016
	var top:= flat + 0.2
	var cap:= top + 0.014
	var ins:= cap + 0.09


	_plate(steel, 0.11, flat, 0.003, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bolt(steel, Vector3(sx * 0.038, flat, sz * 0.038), 0.0085, 0.006)


	_lathe(steel, [
		Vector2(0.0, flat), Vector2(0.031, flat), Vector2(0.0275, flat + 0.004),
		Vector2(0.0245, flat + 0.01), Vector2(0.019, top - 0.004),
		Vector2(0.024, top - 0.001), Vector2(0.044, top), Vector2(0.046, top + 0.002),
		Vector2(0.046, cap - 0.002), Vector2(0.044, cap), Vector2(0.021, cap),
		Vector2(0.021, cap + 0.022), Vector2(0.017, cap + 0.026),
		Vector2(0.014, cap + 0.026), Vector2(0.014, ins + 0.01), Vector2(0.0, ins + 0.01)],
		TURN_SIDES)

	_lathe(steel, [
		Vector2(0.0, cap), Vector2(0.026, cap), Vector2(0.029, cap + 0.002),
		Vector2(0.029, cap + 0.01), Vector2(0.026, cap + 0.012), Vector2(0.0, cap + 0.012)],
		6, Transform3D.IDENTITY, true)

	var ins_xf:= Transform3D(Basis.IDENTITY, Vector3(0.0, ins, 0.0))
	_lathe(porcelain, INS_PROFILE, TURN_SIDES, ins_xf)


	for dy in [-0.005, 0.005]:
		_torus(copper, 0.039, 0.0035, ins + INS_GROOVE_Y + dy)


	var mesh:= ArrayMesh.new()
	for b in [steel, porcelain, copper]:
		_commit(mesh, b)
	return mesh


static func _new_mast_mesh(height: float, reach: Vector3) -> ArrayMesh:
	var b:= _buffer()
	var foot:= 0.02
	var r:= 0.045

	_plate(b, 0.26, foot, 0.004, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bolt(b, Vector3(sx * 0.1, foot, sz * 0.1), 0.016, 0.011)


	for k in 4:
		var out:= Vector3(cos(k * PI * 0.5), 0.0, sin(k * PI * 0.5))
		var side:= Vector3.UP.cross(out)
		_gusset(b, out, side, r - 0.004, 0.115, foot, 0.14, 0.01)

	_lathe(b, [
		Vector2(0.0, foot), Vector2(r + 0.007, foot), Vector2(r + 0.002, foot + 0.005),
		Vector2(r, foot + 0.01), Vector2(r, height - 0.012), Vector2(r + 0.007, height - 0.01),
		Vector2(r + 0.007, height), Vector2(r + 0.004, height + 0.005),
		Vector2(r * 0.6, height + 0.014), Vector2(0.0, height + 0.017)], 32)
	var arm_y:= height - 0.07
	var brace_y:= arm_y - 0.45

	for y in [arm_y, brace_y]:
		_lathe(b, [
			Vector2(0.0, y - 0.035), Vector2(r + 0.006, y - 0.035),
			Vector2(r + 0.009, y - 0.032), Vector2(r + 0.009, y + 0.032),
			Vector2(r + 0.006, y + 0.035), Vector2(0.0, y + 0.035)], 32)
	if reach.length() < 0.01:
		return _one_surface(b)
	var end:= reach + Vector3(0.0, arm_y, 0.0)

	_rod(b, Vector3(0.0, arm_y, 0.0), end, 0.03)
	_lathe(b, [
		Vector2(0.0, 0.0), Vector2(0.046, 0.0), Vector2(0.048, 0.002),
		Vector2(0.048, 0.008), Vector2(0.046, 0.01), Vector2(0.0, 0.01)],
		32, Transform3D(Basis.IDENTITY, end + Vector3(0.0, 0.03, 0.0)))

	_rod(b, Vector3(0.0, brace_y, 0.0), end - Vector3(0.0, 0.02, 0.0), 0.016)
	return _one_surface(b)


static func _one_surface(b: Dictionary) -> ArrayMesh:
	var mesh:= ArrayMesh.new()
	_commit(mesh, b)
	return mesh


static func _buffer() -> Dictionary:
	return { "v": [], "n": [], "uv": [] }


static func _commit(mesh: ArrayMesh, b: Dictionary) -> void:
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = PackedVector3Array(b ["v"])
	arrays [Mesh.ARRAY_NORMAL] = PackedVector3Array(b ["n"])
	arrays [Mesh.ARRAY_TEX_UV] = PackedVector2Array(b ["uv"])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


static func _tri(b: Dictionary, p: Array, n: Array, uv: Array, facing: Vector3) -> void:
	var g: Vector3 = (p [1] - p [0]).cross(p [2] - p [0])
	if g.length_squared() < 1e-14:
		return
	var order:= [0, 2, 1] if g.dot(facing) > 0.0 else [0, 1, 2]
	for i in order:
		b ["v"].append(p [i])
		b ["n"].append(n [i])
		b ["uv"].append(uv [i])


static func _lathe(b: Dictionary, profile: Array, sides: int,
		xf: Transform3D = Transform3D.IDENTITY, facet: bool = false,
		closed: bool = false) -> void:
	var count:= profile.size()
	var segs:= count if closed else count - 1
	var seg_n: Array [Vector2] = []
	for i in segs:
		var d: Vector2 = profile [(i + 1) % count] - profile [i]
		seg_n.append(Vector2(d.y, - d.x).normalized() if d.length() > 1e-09 else Vector2.ZERO)
	var smooth:= cos(deg_to_rad(40.0))
	var length:= 0.0
	var phase:= PI / sides if facet else 0.0
	for i in segs:
		var a: Vector2 = profile [i]
		var c: Vector2 = profile [(i + 1) % count]
		var n:= seg_n [i]
		if n == Vector2.ZERO:
			continue
		var na:= n
		var nc:= n
		var prev:= i - 1 if i > 0 else (segs - 1 if closed else -1)
		var next:= i + 1 if i < segs - 1 else (0 if closed else -1)
		if prev >= 0 and seg_n [prev].dot(n) > smooth:
			na = (seg_n [prev] + n).normalized()
		if next >= 0 and seg_n [next].dot(n) > smooth:
			nc = (seg_n [next] + n).normalized()
		var v0:= length
		length += a.distance_to(c)
		for k in sides:
			var t0:= phase + TAU * k / sides
			var t1:= phase + TAU * (k + 1) / sides
			var tn0:= (t0 + t1) * 0.5 if facet else t0
			var tn1:= tn0 if facet else t1
			var p:= [_ring(a, t0), _ring(a, t1), _ring(c, t1), _ring(c, t0)]
			var q:= [_ring_n(na, tn0), _ring_n(na, tn1), _ring_n(nc, tn1), _ring_n(nc, tn0)]
			if facet:

				q = [_ring_n(n, tn0), _ring_n(n, tn0), _ring_n(n, tn0), _ring_n(n, tn0)]
			var uv:= [Vector2(float(k) / sides, v0), Vector2(float(k + 1) / sides, v0),
				Vector2(float(k + 1) / sides, length), Vector2(float(k) / sides, length)]
			for j in 4:
				p [j] = xf * (p [j] as Vector3)
				q [j] = xf.basis * (q [j] as Vector3)
			var facing: Vector3 = xf.basis * _ring_n(n, (t0 + t1) * 0.5)
			_tri(b, [p [0], p [1], p [2]], [q [0], q [1], q [2]], [uv [0], uv [1], uv [2]], facing)
			_tri(b, [p [0], p [2], p [3]], [q [0], q [2], q [3]], [uv [0], uv [2], uv [3]], facing)


static func _ring(pt: Vector2, t: float) -> Vector3:
	return Vector3(pt.x * cos(t), pt.y, pt.x * sin(t))


static func _ring_n(n: Vector2, t: float) -> Vector3:
	return Vector3(n.x * cos(t), n.y, n.x * sin(t)).normalized()


static func _torus(b: Dictionary, ring_r: float, r: float, y: float) -> void:
	var section:= []
	for k in 10:
		var t:= TAU * k / 10.0
		section.append(Vector2(ring_r + r * cos(t), y + r * sin(t)))
	_lathe(b, section, 40, Transform3D.IDENTITY, false, true)


static func _plate(b: Dictionary, size: float, thick: float, bevel: float, at: Vector3) -> void:
	var r:= size * 0.5 * sqrt(2.0)
	var d:= bevel * sqrt(2.0)
	_lathe(b, [
		Vector2(0.0, 0.0), Vector2(r, 0.0), Vector2(r, thick - bevel),
		Vector2(r - d, thick), Vector2(0.0, thick)],
		4, Transform3D(Basis.IDENTITY, at), true)


static func _bolt(b: Dictionary, at: Vector3, r: float, h: float) -> void:
	var w:= h * 0.25
	_lathe(b, [
		Vector2(0.0, 0.0), Vector2(r * 1.3, 0.0), Vector2(r * 1.3, w),
		Vector2(0.0, w)], 16, Transform3D(Basis.IDENTITY, at))
	_lathe(b, [
		Vector2(0.0, w), Vector2(r, w), Vector2(r, w + h * 0.8),
		Vector2(r * 0.85, w + h), Vector2(0.0, w + h)],
		6, Transform3D(Basis.IDENTITY, at), true)
	_lathe(b, [
		Vector2(0.0, w + h), Vector2(r * 0.5, w + h), Vector2(r * 0.5, w + h * 1.35),
		Vector2(r * 0.4, w + h * 1.45), Vector2(0.0, w + h * 1.45)],
		12, Transform3D(Basis.IDENTITY, at))


static func _rod(b: Dictionary, a: Vector3, c: Vector3, r: float) -> void:
	var dir:= (c - a).normalized()
	var basis:= Basis(Quaternion(Vector3.UP, dir))
	var l:= a.distance_to(c)
	_lathe(b, [
		Vector2(0.0, - r * 0.3), Vector2(r * 0.7, - r * 0.2), Vector2(r, 0.0),
		Vector2(r, l), Vector2(r * 0.7, l + r * 0.2), Vector2(0.0, l + r * 0.3)],
		24, Transform3D(basis, a))


static func _gusset(b: Dictionary, out: Vector3, side: Vector3, inner: float,
		outer: float, y0: float, high: float, thick: float) -> void:
	var tri:= [out * inner + Vector3(0.0, y0, 0.0), out * outer + Vector3(0.0, y0, 0.0),
		out * inner + Vector3(0.0, y0 + high, 0.0)]
	var h:= side * thick * 0.5
	var lo:= [tri [0] - h, tri [1] - h, tri [2] - h]
	var hi:= [tri [0] + h, tri [1] + h, tri [2] + h]
	var zero:= [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	_tri(b, lo, [- side, - side, - side], zero, - side)
	_tri(b, hi, [side, side, side], zero, side)
	for i in 3:
		var j:= (i + 1) % 3
		var mid: Vector3 = (tri [i] + tri [j]) * 0.5
		var centre: Vector3 = (tri [0] + tri [1] + tri [2]) / 3.0
		var edge: Vector3 = tri [j] - tri [i]
		var n:= edge.cross(side).normalized()
		if n.dot(mid - centre) < 0.0:
			n = - n
		var ns:= [n, n, n]
		_tri(b, [lo [i], lo [j], hi [j]], ns, zero, n)
		_tri(b, [lo [i], hi [j], hi [i]], ns, zero, n)


const LEAD_SEED_Y:= 0.015
const LEAD_SEED_R_MAX:= 0.075

const LEAD_LEAVES_R:= 0.055
const LEAD_TOUCH:= 0.006
const LEAD_REACH:= 1.2


static var _stripped: Dictionary = { }


static func strip_leads(model: Node3D, ports: Array [Node3D]) -> void:
	if model == null or ports.is_empty():
		return
	var port_xf: Array [Transform3D] = []
	for p in ports:
		port_xf.append(_rel(p, model))
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		var mesh:= mi.mesh as ArrayMesh
		if mesh == null or mi.skin != null or mesh.get_blend_shape_count() > 0:
			continue
		var mi_xf:= _rel(mi, model)
		var to_ports: Array [Transform3D] = []
		for xf in port_xf:
			to_ports.append(xf.affine_inverse() * mi_xf)
		var key:= "%d %s" % [mesh.get_instance_id(), str(to_ports)]
		if not _stripped.has(key):
			_stripped [key] = _without_lead(mesh, to_ports)
		mi.mesh = _stripped [key]


static func _rel(node: Node, root: Node) -> Transform3D:
	var xf:= Transform3D.IDENTITY
	var n:= node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _without_lead(mesh: ArrayMesh, to_ports: Array [Transform3D]) -> ArrayMesh:
	var near:= false
	for xf in to_ports:
		if (xf * mesh.get_aabb()).grow(0.1).has_point(Vector3.ZERO):
			near = true
	if not near:
		return mesh
	var surfaces: Array = mesh.get("_surfaces")
	if surfaces.size() != mesh.get_surface_count():
		return mesh
	var out: Array = []
	var gone: Dictionary = { }
	for s in mesh.get_surface_count():
		var cut:= _lead_vertices(mesh, s, to_ports, gone)
		if cut.is_empty():
			out.append(surfaces [s])
			continue
		out.append(_cut_surface(surfaces [s], cut, false))
	if gone.is_empty():
		return mesh
	var result:= ArrayMesh.new()
	result.set("_surfaces", out)
	result.resource_name = mesh.resource_name
	result.custom_aabb = mesh.custom_aabb
	result.lightmap_size_hint = mesh.lightmap_size_hint
	result.shadow_mesh = mesh.shadow_mesh
	if mesh.shadow_mesh is ArrayMesh:
		result.shadow_mesh = _without_positions(mesh.shadow_mesh as ArrayMesh, gone)
	return result


static func _lead_vertices(mesh: ArrayMesh, s: int, to_ports: Array [Transform3D],
		gone: Dictionary) -> Dictionary:
	if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
		return { }
	var mat:= mesh.surface_get_material(s)
	if mat == null:
		return { }
	var cell:= -2
	var cells:= 1
	if "copper" in mat.resource_name.to_lower():
		cell = -1
	elif mat.has_meta("palette_entries"):
		var entries: Array = mat.get_meta("palette_entries")
		cells = entries.size()
		for i in entries.size():
			if "copper" in str(entries [i]).to_lower():
				cell = i
	if cell == -2:
		return { }
	var arrays:= mesh.surface_get_arrays(s)
	if arrays [Mesh.ARRAY_INDEX] == null:
		return { }
	var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
	var uv2:= PackedVector2Array()
	if cell >= 0:
		if arrays [Mesh.ARRAY_TEX_UV2] == null:
			return { }
		uv2 = arrays [Mesh.ARRAY_TEX_UV2]


	var parent: Dictionary = { }
	var at: Dictionary = { }
	for t in range(0, idx.size() - 2, 3):
		var tri:= [idx [t], idx [t + 1], idx [t + 2]]
		if cell >= 0 and int(uv2 [tri [0]].x * cells) != cell:
			continue
		for v: int in tri:
			if not parent.has(v):
				parent [v] = v
				var q:= Vector3i((verts [v] * 10000.0).round())
				if at.has(q):
					_union(parent, v, at [q])
				else:
					at [q] = v
		_union(parent, tri [0], tri [1])
		_union(parent, tri [0], tri [2])
	if parent.is_empty():
		return { }
	var islands: Dictionary = { }
	for v: int in parent:
		var root:= _find(parent, v)
		if not islands.has(root):
			islands [root] = []
		islands [root].append(v)

	var near: Array = []
	var cut_roots: Dictionary = { }
	var boxes: Dictionary = { }
	for root: int in islands:
		var members: Array = islands [root]
		var box:= AABB(verts [members [0]], Vector3.ZERO)
		for v: int in members:
			box = box.expand(verts [v])
		var tie:= false
		for xf in to_ports:
			tie = tie or _is_tie(verts, members, xf)
		if tie:
			continue
		var close:= false
		var seed:= false
		for xf in to_ports:
			if (xf * box.get_center()).length() > LEAD_REACH:
				continue
			close = true


			var in_groove:= false
			var leaves:= false
			for v: int in members:
				var p:= xf * verts [v]
				var r:= Vector2(p.x, p.z).length()
				in_groove = in_groove or (absf(p.y) < LEAD_SEED_Y and r < LEAD_SEED_R_MAX)
				leaves = leaves or r > LEAD_LEAVES_R
			seed = seed or (in_groove and leaves)
		if not close:
			continue
		boxes [root] = box
		near.append(root)
		if seed:
			cut_roots [root] = true
	if cut_roots.is_empty():
		return { }

	var grew:= true
	while grew:
		grew = false
		for root: int in near:
			if cut_roots.has(root):
				continue
			var box: AABB = (boxes [root] as AABB).grow(LEAD_TOUCH)
			for other: int in cut_roots.keys():
				if not box.intersects(boxes [other]):
					continue
				if _touch(verts, islands [root], islands [other]):
					cut_roots [root] = true
					grew = true
					break
	var cut: Dictionary = { }
	for root: int in cut_roots:
		for v: int in islands [root]:
			cut [v] = true
			gone [Vector3i((verts [v] * 10000.0).round())] = true
	return cut


static func _is_tie(verts: PackedVector3Array, members: Array, xf: Transform3D) -> bool:
	var low:= INF
	var high:= - INF
	for v: int in members:
		var p:= xf * verts [v]
		if absf(p.y) > 0.04 or Vector2(p.x, p.z).length() > 0.047:
			return false
		low = minf(low, p.y)
		high = maxf(high, p.y)
	return high - low < 0.02


static func _touch(verts: PackedVector3Array, a: Array, b: Array) -> bool:
	var limit:= LEAD_TOUCH * LEAD_TOUCH
	for i: int in a:
		for j: int in b:
			if verts [i].distance_squared_to(verts [j]) < limit:
				return true
	return false


static func _find(parent: Dictionary, v: int) -> int:
	var r: int = v
	while parent [r] != r:
		r = parent [r]
	var n: int = v
	while parent [n] != r:
		var next: int = parent [n]
		parent [n] = r
		n = next
	return r


static func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra:= _find(parent, a)
	var rb:= _find(parent, b)
	if ra != rb:
		parent [ra] = rb


static func _cut_surface(surface: Dictionary, cut: Dictionary, every: bool) -> Dictionary:
	var out:= surface.duplicate()
	var count: int = surface.get("index_count", 0)
	var data: PackedByteArray = surface.get("index_data", PackedByteArray())
	if count == 0 or data.is_empty():
		return out
	var wide:= data.size() / count == 4
	var kept:= _keep(_decode(data, wide), cut, every)
	if kept.is_empty():

		kept = PackedInt32Array([0, 0, 0])
	out ["index_data"] = _encode(kept, wide)
	out ["index_count"] = kept.size()
	var lods: Variant = surface.get("lods", null)
	if lods is Array and not (lods as Array).is_empty():
		var levels: Array = (lods as Array).duplicate()
		for i in levels.size():
			if levels [i] is PackedByteArray:
				var level:= _keep(_decode(levels [i], wide), cut, every)
				if level.is_empty():
					level = PackedInt32Array([0, 0, 0])
				levels [i] = _encode(level, wide)
			elif levels [i] is Dictionary and levels [i].has("index_data"):
				var entry: Dictionary = (levels [i] as Dictionary).duplicate()
				var level:= _keep(_decode(entry ["index_data"], wide), cut, every)
				if level.is_empty():
					level = PackedInt32Array([0, 0, 0])
				entry ["index_data"] = _encode(level, wide)
				levels [i] = entry
		out ["lods"] = levels
	return out


static func _keep(indices: PackedInt32Array, cut: Dictionary, every: bool) -> PackedInt32Array:
	var kept:= PackedInt32Array()
	for t in range(0, indices.size() - 2, 3):
		var a:= cut.has(indices [t])
		var b:= cut.has(indices [t + 1])
		var c:= cut.has(indices [t + 2])
		if (a and b and c) if every else (a or b or c):
			continue
		kept.append(indices [t])
		kept.append(indices [t + 1])
		kept.append(indices [t + 2])
	return kept


static func _decode(bytes: PackedByteArray, wide: bool) -> PackedInt32Array:
	if wide:
		return bytes.to_int32_array()
	var out:= PackedInt32Array()
	out.resize(bytes.size() / 2)
	for i in out.size():
		out [i] = bytes.decode_u16(i * 2)
	return out


static func _encode(indices: PackedInt32Array, wide: bool) -> PackedByteArray:
	if wide:
		return indices.to_byte_array()
	var out:= PackedByteArray()
	out.resize(indices.size() * 2)
	for i in indices.size():
		out.encode_u16(i * 2, indices [i])
	return out


static func _without_positions(mesh: ArrayMesh, gone: Dictionary) -> ArrayMesh:
	var surfaces: Array = mesh.get("_surfaces")
	if surfaces.size() != mesh.get_surface_count():
		return mesh
	var out: Array = []
	var changed:= false
	for s in mesh.get_surface_count():
		var raw: Variant = mesh.surface_get_arrays(s) [Mesh.ARRAY_VERTEX]
		if not raw is PackedVector3Array:
			out.append(surfaces [s])
			continue
		var verts: PackedVector3Array = raw
		var cut: Dictionary = { }
		for v in verts.size():
			if gone.has(Vector3i((verts [v] * 10000.0).round())):
				cut [v] = true
		if cut.is_empty():
			out.append(surfaces [s])
			continue
		changed = true
		out.append(_cut_surface(surfaces [s], cut, true))
	if not changed:
		return mesh
	var result:= ArrayMesh.new()
	result.set("_surfaces", out)
	result.resource_name = mesh.resource_name
	return result


static var _parts: Dictionary = { }


static func _part(key: String, build: Callable) -> Resource:
	if not HayCompressor.materials_shared():
		return build.call()
	if not _parts.has(key):
		_parts [key] = build.call()
	return _parts [key]


static func _flat(colour: Color, rough: float, metal: float) -> StandardMaterial3D:
	var build:= func() -> Resource: return _new_flat(colour, rough, metal)
	return _part("flat %s %.3f %.3f" % [colour, rough, metal], build) as StandardMaterial3D


static func _new_flat(colour: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	m.metallic = metal
	return m


static func stand_in_points(machine: Node3D, want: int) -> Array [Vector3]:
	var box:= body_box(machine)
	var top:= box.position.y + box.size.y
	var mid:= box.position + box.size * 0.5
	if want <= 1 or box.size.x <= 0.01:
		return [Vector3(mid.x, top, mid.z)]

	var along_x:= box.size.x >= box.size.z
	var reach:= (box.size.x if along_x else box.size.z) * (0.5 - STAND_IN_INSET)
	var offset:= Vector3(reach, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, reach)
	var centre:= Vector3(mid.x, top, mid.z)
	return [centre - offset, centre + offset]


static func body_box(machine: Node3D) -> AABB:
	var box:= AABB()
	var started:= false
	var into:= machine.global_transform.affine_inverse()
	for node in machine.find_children("*", "GeometryInstance3D", true, false):
		var vis:= node as GeometryInstance3D
		if not vis.visible or vis is GPUParticles3D:
			continue
		if vis.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var own:= vis.get_aabb()


		var to_machine:= into * vis.global_transform
		for corner in 8:
			var at:= own.position + own.size * Vector3(
				float(corner & 1), float((corner >> 1) & 1), float((corner >> 2) & 1))
			var here:= to_machine * at
			if started:
				box = box.expand(here)
			else:
				box = AABB(here, Vector3.ZERO)
				started = true
	return box


static func loop_pitch(power: float) -> float:
	return maxf(clampf(power, 0.0, 1.0), MIN_LOOP_PITCH)


static func fault(power: float, blocked: bool, line: int = LINE_OK) -> String:
	if power > 0.0:
		return ""
	if blocked:
		return Cfg.tr("NO CABLE REACHES THIS  ·  a pole is near, but something is in the way")
	if line == LINE_OUT_OF_HAY:
		return Cfg.tr("NO POWER  ·  the generator is out of hay, feed it")
	if line == LINE_NO_GENERATOR:
		return Cfg.tr("NO POWER  ·  nothing on this line makes power, build a generator or switch one on")
	return Cfg.tr("NO POWER  ·  put a power pole near this machine")


const LINE_OK:= 0
const LINE_OUT_OF_HAY:= 1
const LINE_NO_GENERATOR:= 2


static func rating_line(machine: Node, grid: PowerGrid) -> String:


	if machine == null or not is_instance_valid(machine) or not machine.has_method("rated_kw"):
		return ""
	var kw:= float(machine.call("rated_kw"))
	if kw <= 0.0:
		return ""
	var share:= power_share(machine, grid)


	if share < 0.999:
		return Cfg.tr("this machine needs %.1f kW  ·  it is getting %d%% of that") % [kw, int(round(share * 100.0))]
	return Cfg.tr("this machine needs %.1f kW") % kw


static func power_share(machine: Node, grid: PowerGrid) -> float:
	if machine == null or not is_instance_valid(machine) or not machine.has_method("rated_kw") or float(machine.call("rated_kw")) <= 0.0:
		return 1.0
	if machine.has_method("is_switched_off") and bool(machine.call("is_switched_off")):
		return 1.0
	if grid == null:
		return 1.0
	var got: Dictionary = grid.report(machine as Node3D)
	return float(got ["satisfaction"]) if bool(got ["connected"]) else 1.0


static func power_share_for(machine: Node, player: Player) -> float:
	var grid: PowerGrid = null
	if player != null and player.build != null and player.build.builds != null:
		grid = player.build.builds.grid
	return power_share(machine, grid)


static func rating_line_for(machine: Node, player: Player) -> String:
	var grid: PowerGrid = null
	if player != null and player.build != null and player.build.builds != null:
		grid = player.build.builds.grid
	return rating_line(machine, grid)
