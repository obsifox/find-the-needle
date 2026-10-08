class_name DevPowerlineProbe
extends Node


var world: Node3D
var player: Node


const SETTLE_SECONDS:= 3.0


const LENGTH_TOLERANCE:= 0.02


const SAG_CENTRE_TOLERANCE:= 0.1

var _pass:= 0
var _fail:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	print("[powerline] --- power line probe ---")
	await _case_hangs_between_two_anchors()
	await _case_length_matches_the_slack()
	await _case_sag_is_centred()
	await _case_it_goes_to_sleep()
	await _case_moving_an_anchor_wakes_it()
	await _case_two_wires_at_once()
	await _case_missing_anchor_is_not_a_crash()
	await _case_the_pole_model_carries_its_markers()
	print("[powerline] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _case_hangs_between_two_anchors() -> void:
	var rig:= _rig(Vector3(0.0, 3.1, 0.0), Vector3(0.0, 3.1, 6.0))
	var line: PowerLine = rig [1]
	await _settle(line)
	var pts:= _points(line, 0)
	_check("a span exists", pts.size() == PowerLine.POINTS,
		"%d points" % pts.size())
	var mid: Vector3 = pts [pts.size() / 2]
	_check("it sags in the middle", mid.y < 3.1 - 0.05,
		"middle at y=%.3f, ends at y=3.100" % mid.y)
	_check("its ends are on the anchors",
		pts [0].distance_to(Vector3(0.0, 3.1, 0.0)) < 0.001
		and pts [pts.size() - 1].distance_to(Vector3(0.0, 3.1, 6.0)) < 0.001,
		"ends at %s and %s" % [pts [0], pts [pts.size() - 1]])
	rig [0].queue_free()


func _case_length_matches_the_slack() -> void:
	for span in [2.0, 6.0, 14.0]:
		var rig:= _rig(Vector3.UP * 3.1, Vector3(0.0, 3.1, span))
		var line: PowerLine = rig [1]
		await _settle(line)
		var pts:= _points(line, 0)
		var measured:= 0.0
		for i in pts.size() - 1:
			measured += pts [i].distance_to(pts [i + 1])
		var strung: float = span * (1.0 + PowerLine.SLACK)
		var err: float = absf(measured - strung) / strung
		_check("a %.0f m span keeps its length" % span, err < LENGTH_TOLERANCE,
			"strung %.3f m, measured %.3f m, %.2f%% out" % [strung, measured, err * 100.0])
		rig [0].queue_free()


func _case_sag_is_centred() -> void:
	var rig:= _rig(Vector3.UP * 3.1, Vector3(0.0, 3.1, 8.0))
	var line: PowerLine = rig [1]
	await _settle(line)
	var pts:= _points(line, 0)
	var low:= 0
	for i in pts.size():
		if pts [i].y < pts [low].y:
			low = i
	var at:= float(low) / float(pts.size() - 1)
	_check("the low point is in the middle", absf(at - 0.5) < SAG_CENTRE_TOLERANCE,
		"lowest of %d points is #%d, %.2f along" % [pts.size(), low, at])
	rig [0].queue_free()


func _case_it_goes_to_sleep() -> void:
	var rig:= _rig(Vector3.UP * 3.1, Vector3(0.0, 3.1, 6.0))
	var line: PowerLine = rig [1]
	_check("it is awake when it is built", not line.is_asleep(), "")
	await _settle(line)
	_check("it goes to sleep once it has settled", line.is_asleep(),
		"still awake after %.1f s" % SETTLE_SECONDS)
	rig [0].queue_free()


func _case_moving_an_anchor_wakes_it() -> void:
	var rig:= _rig(Vector3.UP * 3.1, Vector3(0.0, 3.1, 6.0))
	var root: Node3D = rig [0]
	var line: PowerLine = rig [1]
	await _settle(line)
	if not line.is_asleep():
		_check("it slept before the anchor moved", false, "")
		root.queue_free()
		return
	var far: Node3D = line.to_anchors [0]
	far.position += Vector3(0.0, 0.0, 3.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("moving an anchor wakes it", not line.is_asleep(), "")
	await _settle(line)
	var pts:= _points(line, 0)
	_check("and it follows the anchor",
		pts [pts.size() - 1].distance_to(far.position) < 0.01,
		"end at %s, anchor at %s" % [pts [pts.size() - 1], far.position])
	root.queue_free()


func _case_two_wires_at_once() -> void:
	var root:= Node3D.new()
	world.add_child(root)
	var line:= PowerLine.new()
	line.from_anchors = [_anchor(root, Vector3(-0.13, 2.85, 0.0)),
		_anchor(root, Vector3(0.13, 2.85, 0.0))]
	line.to_anchors = [_anchor(root, Vector3(-0.28, 3.105, 7.0)),
		_anchor(root, Vector3(0.28, 3.105, 7.0))]
	root.add_child(line)
	await _settle(line)
	var a:= _points(line, 0)
	var b:= _points(line, 1)
	_check("both wires exist", a.size() == PowerLine.POINTS and b.size() == PowerLine.POINTS,
		"%d and %d points" % [a.size(), b.size()])


	var closest:= 1000000000.0
	for i in a.size():
		closest = minf(closest, a [i].distance_to(b [i]))
	_check("they stay apart", closest > 0.1,
		"closest approach %.3f m" % closest)
	root.queue_free()


func _case_missing_anchor_is_not_a_crash() -> void:
	var root:= Node3D.new()
	world.add_child(root)
	var line:= PowerLine.new()
	line.from_anchors = [_anchor(root, Vector3.UP * 3.0)]
	line.to_anchors = []
	root.add_child(line)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a span with one end draws nothing and survives", is_instance_valid(line), "")
	root.queue_free()


func _case_the_pole_model_carries_its_markers() -> void:
	var pole:= PowerPole.new()
	world.add_child(pole)
	await get_tree().process_frame
	var anchors:= pole.wire_anchors()
	_check("the pole offers one anchor", anchors.size() == 1,
		"%d anchors" % anchors.size())
	if anchors.size() == 1:
		var w:= anchors [0].global_position - pole.global_position


		_check("it is up at the crown", w.y > 3.0,
			"height %.3f" % w.y)


		_check("it is over the pole's axis", absf(w.x) < 0.1,
			"%.3f m off axis" % absf(w.x))
	pole.queue_free()


func _rig(a: Vector3, b: Vector3) -> Array:
	var root:= Node3D.new()
	world.add_child(root)
	var line:= PowerLine.new()
	line.from_anchors = [_anchor(root, a)]
	line.to_anchors = [_anchor(root, b)]
	root.add_child(line)
	return [root, line]


func _anchor(parent: Node3D, at: Vector3) -> Node3D:
	var n:= Node3D.new()
	parent.add_child(n)
	n.position = at
	return n


func _settle(line: PowerLine) -> void:
	var waited:= 0.0
	while waited < SETTLE_SECONDS and not line.is_asleep():
		await get_tree().process_frame
		waited += get_process_delta_time()


func _points(line: PowerLine, rope: int) -> PackedVector3Array:
	var out:= PackedVector3Array()
	var all: PackedVector3Array = line.points()
	var base: int = rope * PowerLine.POINTS
	if all.size() < base + PowerLine.POINTS:
		return out
	for i in PowerLine.POINTS:
		out.append(all [base + i])
	return out


func _check(what: String, ok: bool, detail: String) -> void:
	if ok:
		_pass += 1
		print("[powerline] PASS  %s" % what)
	else:
		_fail += 1
		print("[powerline] FAIL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
