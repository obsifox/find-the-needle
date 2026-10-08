class_name ConveyorCorner
extends BeltPath


var from_point: Vector3
var apex: Vector3
var to_point: Vector3


func setup(from: Vector3, corner: Vector3, to: Vector3) -> void:
	from_point = from
	apex = corner
	to_point = to


func is_hand_laid() -> bool:
	return true


func _ready() -> void:


	super ()


	gathers_straw = true


	coarse_far = true


	records_props = true
	_lay()


func _lay() -> void:
	_fit_arc()


	var turn:= float(_arc.get("turn", 0.0))
	var radius:= float(_arc.get("radius", 0.0))
	var points:= _sample(clampi(int(ceil(turn / Cfg.BELT_CORNER_STEP)), 2, 12))


	var reach:= maxf(radius * turn, from_point.distance_to(to_point))
	draw_curve = _sample(clampi(maxi(
		int(ceil(turn / Cfg.BELT_CORNER_DRAW_STEP)),
		int(ceil(reach / Cfg.BELT_CORNER_DRAW_SPAN))), 6, 96))


	build_path(points, Cfg.BELT_JOINT_OVERLAP)


var _arc:= { }


func _fit_arc() -> void:
	_arc = arc_of(from_point, apex, to_point)


static func arc_of(from: Vector3, corner: Vector3, to: Vector3) -> Dictionary:
	var in_leg:= corner - from
	var out_leg:= to - corner
	var l0:= in_leg.length()
	var l1:= out_leg.length()
	var flat:= { "turn": 0.0, "radius": 0.0 }
	if l0 < 1e-05 or l1 < 1e-05:
		return flat
	in_leg /= l0
	out_leg /= l1
	var turn:= in_leg.angle_to(out_leg)
	var axis:= in_leg.cross(out_leg)
	if turn < 0.0001 or axis.length_squared() < 1e-12:
		return flat
	axis = axis.normalized()


	var radius:= (l0 + l1) * 0.5 / tan(turn * 0.5)

	var centre:= from + axis.cross(in_leg) * radius


	var spoke:= from - centre
	var perp:= axis.cross(spoke)
	return {
		"turn": turn,
		"radius": radius,
		"axis": axis,
		"centre": centre,
		"spoke": spoke,
		"perp": perp,


		"close": to - (centre + spoke * cos(turn) + perp * sin(turn)),
	}


static func arc_points(arc: Dictionary, from: Vector3, to: Vector3,
		n: int) -> PackedVector3Array:
	var out:= PackedVector3Array()
	out.resize(n + 1)
	var turn:= float(arc.get("turn", 0.0))
	if turn <= 0.0:
		for i in n + 1:
			out [i] = from.lerp(to, float(i) / float(n))
		return out
	var centre: Vector3 = arc ["centre"]
	var spoke: Vector3 = arc ["spoke"]
	var perp: Vector3 = arc ["perp"]
	var close: Vector3 = arc ["close"]
	for i in n + 1:
		var u:= float(i) / float(n)
		var a:= turn * u
		out [i] = centre + spoke * cos(a) + perp * sin(a) + close * u
	return out


func _sample(n: int) -> PackedVector3Array:
	return arc_points(_arc, from_point, to_point, n)


func set_rail_windows(windows: Array [Dictionary]) -> void:
	if windows.size() == open_windows.size():
		var same:= true
		for i in windows.size():
			var w: Dictionary = windows [i]
			var mine: Dictionary = open_windows [i]
			if int(w ["side"]) != int(mine ["side"]) or not is_equal_approx(float(w ["from"]), float(mine ["from"])) or not is_equal_approx(float(w ["to"]), float(mine ["to"])):
				same = false
				break
		if same:
			return
	open_windows = windows
	if is_inside_tree():
		_lay()


func apex_s() -> float:
	return path_length() * 0.5
