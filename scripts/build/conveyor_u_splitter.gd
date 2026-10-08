class_name ConveyorUSplitter
extends ConveyorSplitter


const LANE_X:= 1.0

const OUT_Z:= 2.0

const BEND_R:= 1.0


const BEND_S:= 1.0

const BEND_ARC:= 0.7853982
const BEND_E:= BEND_S + BEND_ARC


const BEND_CENTRE_Z:= 1.4142136

const ARM_END:= BEND_E + OUT_Z - BEND_CENTRE_Z


const BEND_PIECES:= 6


const HUB_R:= 0.6


const X_IN:= 0.405
const X_OUT:= 0.45
const FILLET_SIDE:= 0.8
const FILLET_CROTCH:= 0.1
const ARC_DEG:= 2.5


const PAN_R:= 0.94

const LANE_BEARINGS:= [90.0, 225.0, 315.0]


const FOOT_R:= 0.5


static func arm_point(hand: float, s: float) -> Vector3:
	var splay:= Cfg.SPLITTER_SPLAY
	var out:= Vector3(hand * sin(splay), 0.0, cos(splay))
	if s <= BEND_S:
		return out * s


	var centre:= out * BEND_S + Vector3(- hand * cos(splay), 0.0, sin(splay)) * BEND_R
	var phi:= splay - minf(s - BEND_S, BEND_ARC) / BEND_R
	var p:= centre - Vector3(- hand * cos(phi), 0.0, sin(phi)) * BEND_R
	if s > BEND_E:
		p.z += s - BEND_E
	return p


static func arm_heading(hand: float, s: float) -> Vector3:
	var phi:= Cfg.SPLITTER_SPLAY - clampf(s - BEND_S, 0.0, BEND_ARC) / BEND_R
	return Vector3(hand * sin(phi), 0.0, cos(phi))


static func mouth_local(hand: float) -> Vector3:
	return Vector3(hand * LANE_X, 0.0, OUT_Z)


static func arm_line_local(hand: float) -> PackedVector3Array:
	var pts:= PackedVector3Array([Vector3.ZERO, arm_point(hand, BEND_S)])
	for k in range(1, BEND_PIECES + 1):
		pts.append(arm_point(hand, BEND_S + BEND_ARC * float(k) / float(BEND_PIECES)))
	pts.append(mouth_local(hand))
	return pts


static func pad_centre(mouth: Vector3, travel: Vector3) -> Vector3:
	var axis:= travel.normalized()
	if axis.dot(mouth) < 0.0:
		axis = - axis
	return mouth - axis * LEG_PAD_INSET + Vector3.DOWN * LEG_PAD_DEPTH


static func deck_outline() -> PackedVector2Array:
	var reaches:= [PAN_R, BEND_S, BEND_S]
	var pts:= PackedVector2Array()
	for i in LANE_BEARINGS.size():
		var phi: float = LANE_BEARINGS [i]
		var d:= _bearing(phi)
		var n:= _left_of(phi)
		var r: float = reaches [i]
		pts.append(_plan(d * r - n * X_OUT))
		pts.append(_plan(d * r + n * X_OUT))
		for p: Vector2 in _notch_arc(i, X_OUT):
			pts.append(_plan(p))
	return pts


static func _notch_arc(i: int, h: float) -> PackedVector2Array:
	var phi: float = LANE_BEARINGS [i]
	var phi2: float = LANE_BEARINGS [(i + 1) % LANE_BEARINGS.size()]
	var gap:= fposmod(phi2 - phi, 360.0)
	var r:= FILLET_CROTCH if gap < 100.0 else FILLET_SIDE
	var half_gap:= deg_to_rad(gap) / 2.0
	var b:= deg_to_rad(phi + gap / 2.0)
	var dc:= (X_IN + r) / sin(half_gap)
	var c:= Vector2(dc * cos(b), dc * sin(b))
	var a0:= phi - 90.0
	var sweep:= 180.0 - gap
	var n:= int(ceil(sweep / ARC_DEG))
	n += n % 2
	var rr:= r + X_IN - h
	var out:= PackedVector2Array()
	for k in n + 1:
		var a:= deg_to_rad(a0 - sweep * float(k) / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * rr)
	return out


static func _bearing(phi: float) -> Vector2:
	var a:= deg_to_rad(phi)
	return Vector2(cos(a), sin(a))


static func _left_of(phi: float) -> Vector2:
	var a:= deg_to_rad(phi)
	return Vector2(- sin(a), cos(a))


static func _plan(p: Vector2) -> Vector2:
	return Vector2(p.x, - p.y)


static var _arm_piece_cache: Dictionary = { }


static func arm_pieces(hand: float, inward: bool) -> Array:
	var key:= Vector2(hand, 1.0 if inward else 0.0)
	if _arm_piece_cache.has(key):
		return _arm_piece_cache [key]
	const OVERLAP:= 0.03
	var line:= arm_line_local(hand)
	var out: Array = []
	for i in line.size() - 1:
		var a: Vector3 = line [i]
		var b: Vector3 = line [i + 1]
		var dir:= (b - a).normalized()
		if i > 0:
			a -= dir * OVERLAP
		if i < line.size() - 2:
			b += dir * OVERLAP
		out.append({ "from": a, "mouth": b, "travel": - dir if inward else dir })
	for piece: Dictionary in out:
		piece.make_read_only()
	out.make_read_only()
	_arm_piece_cache [key] = out
	return out


static func footprint_local() -> Array [Vector4]:
	var out: Array [Vector4] = [Vector4(0.0, 0.0, 0.0, Cfg.SPLITTER_PORT_R)]
	for hand: float in [1.0, -1.0]:
		var bend:= arm_point(hand, BEND_S + BEND_ARC * 0.5)
		out.append(Vector4(bend.x, 0.0, bend.z, FOOT_R))
		var last:= mouth_local(hand) - Vector3(0.0, 0.0, FOOT_R)
		out.append(Vector4(last.x, 0.0, last.z, FOOT_R))
	return out


func port_left() -> Vector3:
	return to_global(mouth_local(1.0))


func port_right() -> Vector3:
	return to_global(mouth_local(-1.0))


func _mouths() -> Array:
	return [Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R), mouth_local(1.0), mouth_local(-1.0)]


func _lanes() -> Array:
	return [
		{ "mouth": Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R), "travel": Vector3(0.0, 0.0, 1.0) },
		{ "mouth": mouth_local(1.0), "travel": Vector3(0.0, 0.0, 1.0) },
		{ "mouth": mouth_local(-1.0), "travel": Vector3(0.0, 0.0, 1.0) },
	]


func _sweep_lanes() -> Array:
	var out: Array = [{ "mouth": Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R),
		"travel": Vector3(0.0, 0.0, 1.0) }]
	out.append_array(arm_pieces(1.0, false))
	out.append_array(arm_pieces(-1.0, false))
	return out


func _route_points(side: int) -> PackedVector3Array:
	var pts:= PackedVector3Array([port_in()])
	for p: Vector3 in arm_line_local(1.0 if side == LEFT else -1.0):
		pts.append(to_global(p))


	pts [pts.size() - 1] = port(side)
	return pts


func arm_line(side: int) -> PackedVector3Array:
	var pts:= PackedVector3Array()
	for p: Vector3 in arm_line_local(1.0 if side == LEFT else -1.0):
		pts.append(to_global(p))
	return pts


func _body_mesh() -> ArrayMesh:
	return ConveyorKit.fast_mesh(ConveyorKit.u_splitter_mesh())


func _make_infill() -> MeshInstance3D:
	return WyeSweep.infill_outline(deck_outline())


func _make_infill_body() -> StaticBody3D:
	return WyeSweep.infill_outline_body(deck_outline())


func _make_sweep() -> Area3D:
	return WyeSweep.make_lane_area(_sweep_lanes(), HUB_R)


func _pad_centre(lane: Dictionary) -> Vector3:
	return pad_centre(lane ["mouth"], lane ["travel"])


func arm_travel(_side: int) -> Vector3:
	return forward()


func footprint() -> Array [Vector4]:
	var out: Array [Vector4] = []
	for d: Vector4 in footprint_local():
		var c:= to_global(Vector3(d.x, d.y, d.z))
		out.append(Vector4(c.x, c.y, c.z, d.w))
	return out


func to_dict() -> Dictionary:
	var d:= super ()
	d ["type"] = "conveyor_u_splitter"
	return d
