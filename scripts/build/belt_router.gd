class_name BeltRouter
extends RefCounted


const STEPS: Array [float] = [1.2, 2.4, 3.6, 5.0]


const BEND_COST:= 1.5


const APPROACH:= 1.6


const MAX_TURN_COS:= -0.02


const LEG_CLEAR:= Cfg.BELT_WIDTH + 0.1


const CHOICES:= 4


const TRIES:= 48


const KEEP_SLACK:= 1.15
const KEEP_MARGIN:= 0.6

var tool: BuildTool


func _init(owner: BuildTool) -> void:
	tool = owner


func find(from: Vector3, to: Vector3) -> Array [Dictionary]:
	var shapes:= _shapes(from, to)
	shapes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x ["score"] < y ["score"])
	var picks: Array [Dictionary] = []
	var memo:= { }
	var tried:= 0
	for shape in shapes:
		if picks.size() >= CHOICES or tried >= TRIES:
			break
		tried += 1
		if _clears(shape ["points"], memo):
			picks.append(shape)
	return picks


func recheck(from: Vector3, to: Vector3, sig: String) -> Dictionary:
	for shape in _shapes(from, to):
		if shape ["sig"] == sig:
			return shape if _clears(shape ["points"], { }) else { }
	return { }


static func choose(picks: Array [Dictionary], sig: String, pinned: bool) -> Dictionary:
	if picks.is_empty():
		return { }
	var best: Dictionary = picks [0]
	for pick in picks:
		if pick ["sig"] != sig:
			continue
		if pinned or float(pick ["score"]) <= float(best ["score"]) * KEEP_SLACK + KEEP_MARGIN:
			return pick
	return best


func _shapes(from: Vector3, to: Vector3) -> Array [Dictionary]:
	var builds:= tool.builds
	var tail:= _flat(builds.port_bearing_at(from))
	var head:= _flat(builds.port_bearing_at(to))
	var start:= from + tail * APPROACH
	var finish:= to - head * APPROACH
	var frames: Array [Dictionary] = []
	var incoming:= builds.feed_run_into(from)
	if incoming != null:
		_add_frame(frames, "in", incoming.forward)
	_add_frame(frames, "tail", tail)
	_add_frame(frames, "head", head)
	var onward:= builds.run_out_of(to)
	if onward != null:
		_add_frame(frames, "out", onward.forward)
	_add_frame(frames, "line", finish - start)
	_add_frame(frames, "world", Vector3.BACK)

	var out: Array [Dictionary] = []
	var seen:= { }
	var gap:= finish - start
	for frame in frames:
		var u: Vector3 = frame ["u"]
		var v:= Vector3(u.z, 0.0, - u.x)
		var du:= gap.x * u.x + gap.z * u.z
		var dv:= gap.x * v.x + gap.z * v.z
		var kind: String = frame ["kind"]
		_offer(out, seen, kind + ":uv", from, to, start, finish, u, v,
			PackedVector2Array([Vector2(du, 0.0)]))
		_offer(out, seen, kind + ":vu", from, to, start, finish, u, v,
			PackedVector2Array([Vector2(0.0, dv)]))
		for step in _steps(du):
			var at: float = step ["at"]
			_offer(out, seen, kind + ":uvu:" + str(step ["tag"]), from, to, start, finish,
				u, v, PackedVector2Array([Vector2(at, 0.0), Vector2(at, dv)]))
		for step in _steps(dv):
			var at: float = step ["at"]
			_offer(out, seen, kind + ":vuv:" + str(step ["tag"]), from, to, start, finish,
				u, v, PackedVector2Array([Vector2(0.0, at), Vector2(du, at)]))
	return out


static func _steps(d: float) -> Array [Dictionary]:
	var out: Array [Dictionary] = [{ "at": d * 0.5, "tag": "mid" }]
	for i in STEPS.size():
		var k: float = STEPS [i]
		out.append({ "at": minf(0.0, d) - k, "tag": "lo%d" % i })
		out.append({ "at": maxf(0.0, d) + k, "tag": "hi%d" % i })
		if absf(d) > k * 2.0:
			var s:= signf(d)
			out.append({ "at": s * k, "tag": "near%d" % i })
			out.append({ "at": d - s * k, "tag": "far%d" % i })
	return out


func _offer(out: Array [Dictionary], seen: Dictionary, sig: String, from: Vector3,
		to: Vector3, start: Vector3, finish: Vector3, u: Vector3, v: Vector3,
		corners: PackedVector2Array) -> void:
	var pts:= PackedVector3Array([from])
	if not start.is_equal_approx(from):
		pts.append(start)
	var first:= pts.size()
	for c in corners:
		pts.append(start + u * c.x + v * c.y)
	var after:= pts.size()
	if not finish.is_equal_approx(to):
		pts.append(finish)
	pts.append(to)

	var total:= 0.0
	var prev:= start
	for i in range(first, after):
		total += _flat_len(pts [i] - prev)
		prev = pts [i]
	total += _flat_len(finish - prev)
	var run:= 0.0
	prev = start
	for i in range(first, after):
		var p:= pts [i]
		run += _flat_len(p - prev)
		prev = p
		p.y = lerpf(start.y, finish.y, run / maxf(total, 1e-06))
		pts [i] = p

	pts = _tidy(pts)
	if pts.size() < 3:
		return
	var key:= str(pts)
	if seen.has(key):
		return
	seen [key] = true
	var length:= 0.0
	var cost:= 0.0
	for i in pts.size() - 1:
		length += pts [i].distance_to(pts [i + 1])
		cost += Conveyor.cost_for(pts [i], pts [i + 1])
	var bends:= pts.size() - 2
	out.append({ "sig": sig, "points": pts, "length": length, "cost": cost,
		"bends": bends, "score": length + BEND_COST * float(bends) })


static func _tidy(pts: PackedVector3Array) -> PackedVector3Array:
	var out:= PackedVector3Array([pts [0]])
	for i in range(1, pts.size()):
		var p:= pts [i]
		var last:= out [out.size() - 1]
		if _flat_len(p - last) < 0.01:


			if i == pts.size() - 1 and out.size() > 1:
				out [out.size() - 1] = p
			continue
		out.append(p)
	var i:= 1
	while i < out.size() - 1:
		var a:= (out [i] - out [i - 1]).normalized()
		var b:= (out [i + 1] - out [i]).normalized()
		if a.dot(b) > 0.9995:
			out.remove_at(i)
			continue
		if _flat(a).dot(_flat(b)) < MAX_TURN_COS:
			return PackedVector3Array()
		i += 1
	return out


func _clears(pts: PackedVector3Array, memo: Dictionary) -> bool:
	var builds:= tool.builds
	var legs:= pts.size() - 1
	for i in legs:
		if tool._leg_shape_reason(pts [i], pts [i + 1], pts [i].distance_to(pts [i + 1])) != "":
			return false


	if tool._doubles_back(pts):
		return false
	if tool._mode == BuildTool.Mode.ENCLOSED_CONVEYOR and tool._bends_short_piece(pts):
		return false
	for i in legs:
		for j in range(i + 2, legs):
			if _legs_touch(pts [i], pts [i + 1], pts [j], pts [j + 1]):
				return false


	for i in range(1, legs):
		if builds.feed_run_into(pts [i]) != null or builds.run_out_of(pts [i]) != null:
			return false


	var key:= str(pts)
	if not memo.has(key):
		memo [key] = tool._legs_clear_reason(pts)
	return memo [key] == ""


static func _legs_touch(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> bool:
	var near:= Geometry2D.get_closest_points_between_segments(
		Vector2(a0.x, a0.z), Vector2(a1.x, a1.z), Vector2(b0.x, b0.z), Vector2(b1.x, b1.z))
	return near [0].distance_to(near [1]) < LEG_CLEAR


static func _add_frame(frames: Array [Dictionary], kind: String, along: Vector3) -> void:
	var u:= _flat(along)
	if u == Vector3.ZERO:
		return
	for frame in frames:
		var d:= absf(u.dot(frame ["u"] as Vector3))
		if d > 0.9994 or d < 0.035:
			return
	frames.append({ "kind": kind, "u": u })


static func _flat(v: Vector3) -> Vector3:
	var f:= Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-06 else Vector3.ZERO


static func _flat_len(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
