class_name ConveyorUJoiner
extends ConveyorJoiner


static func _turned(v: Vector3) -> Vector3:
	return Vector3(- v.x, v.y, - v.z)


static func _splitter_hand(hand: float) -> float:
	return - hand


static func mouth_local(hand: float) -> Vector3:
	return _turned(ConveyorUSplitter.mouth_local(_splitter_hand(hand)))


static func arm_line_local(hand: float) -> PackedVector3Array:
	var line:= ConveyorUSplitter.arm_line_local(_splitter_hand(hand))
	var out:= PackedVector3Array()
	for i in range(line.size() - 1, -1, -1):
		out.append(_turned(line [i]))
	return out


static func deck_outline() -> PackedVector2Array:
	var out:= PackedVector2Array()
	for p: Vector2 in ConveyorUSplitter.deck_outline():
		out.append(- p)
	return out


func port_left() -> Vector3:
	return to_global(mouth_local(1.0))


func port_right() -> Vector3:
	return to_global(mouth_local(-1.0))


func _mouths() -> Array:
	return [mouth_local(1.0), mouth_local(-1.0), Vector3(0.0, 0.0, Cfg.JOINER_PORT_R)]


func _lanes() -> Array:
	return [
		{ "mouth": mouth_local(1.0), "travel": Vector3(0.0, 0.0, 1.0) },
		{ "mouth": mouth_local(-1.0), "travel": Vector3(0.0, 0.0, 1.0) },
		{ "mouth": Vector3(0.0, 0.0, Cfg.JOINER_PORT_R), "travel": Vector3(0.0, 0.0, 1.0) },
	]


func _sweep_lanes() -> Array:
	var out: Array = []
	for hand: float in [1.0, -1.0]:
		for piece: Dictionary in ConveyorUSplitter.arm_pieces(_splitter_hand(hand), true):
			out.append({ "from": _turned(piece ["from"]), "mouth": _turned(piece ["mouth"]),
				"travel": _turned(piece ["travel"]) })
	out.append({ "mouth": Vector3(0.0, 0.0, Cfg.JOINER_PORT_R), "travel": Vector3(0.0, 0.0, 1.0) })
	return out


func _arm_points(side: int) -> PackedVector3Array:
	var pts:= arm_line(side)
	pts [0] = port(side)
	pts [pts.size() - 1] = global_position
	return pts


func arm_line(side: int) -> PackedVector3Array:
	var pts:= PackedVector3Array()
	for p: Vector3 in arm_line_local(1.0 if side == LEFT else -1.0):
		pts.append(to_global(p))
	return pts


func arm_travel(_side: int) -> Vector3:
	return forward()


func _body_mesh() -> ArrayMesh:
	return ConveyorKit.u_joiner_mesh()


func _make_infill() -> MeshInstance3D:
	return WyeSweep.infill_outline(deck_outline())


func _make_infill_body() -> StaticBody3D:
	return WyeSweep.infill_outline_body(deck_outline())


func _make_sweep() -> Area3D:
	return WyeSweep.make_lane_area(_sweep_lanes(), ConveyorUSplitter.HUB_R)


func _pad_centre(lane: Dictionary) -> Vector3:
	return ConveyorUSplitter.pad_centre(lane ["mouth"], lane ["travel"])


func footprint() -> Array [Vector4]:
	var out: Array [Vector4] = []
	for d: Vector4 in ConveyorUSplitter.footprint_local():
		var c:= to_global(_turned(Vector3(d.x, d.y, d.z)))
		out.append(Vector4(c.x, c.y, c.z, d.w))
	return out


func to_dict() -> Dictionary:
	var d:= super ()
	d ["type"] = "conveyor_u_joiner"
	return d
