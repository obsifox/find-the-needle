class_name DevBeltPileProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 40

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame

	var field: HayField = world.field
	var tool: BuildTool = player.build
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	GameState.add_money(5000.0)

	print("\nshed half-width %.1f m (stock 17.0, yard_space rank %d)"
		% [17.0 + Tech.warehouse_extra(), Tech.rank_of("yard_space")])

	print("\n=== pile profile (z = 0) ===")
	for x in range(-12, 13, 2):
		print("  x %+3d  h %.2f" % [x, field.height_at(float(x), 0.0)])

	print("\n=== runs against the pile ===")


	_chord(tool, field, "floor level, straight through", Vector3(-11.0, lift, 0.0),
		Vector3(11.0, lift, 0.0), true)
	_chord(tool, field, "floor level, short bite", Vector3(-11.0, lift, 0.0),
		Vector3(-3.0, lift, 0.0), true)
	_chord(tool, field, "half height through the crown", Vector3(-11.0, 1.6, 0.0),
		Vector3(11.0, 1.6, 0.0), true)
	_chord(tool, field, "grazing the skirt", Vector3(-11.0, lift, -9.0),
		Vector3(11.0, lift, -9.0), true)


	_chord(tool, field, "open floor, well clear", Vector3(13.0, lift, -5.0),
		Vector3(13.0, lift, 5.0), false)
	_chord(tool, field, "open floor, past the skirt", Vector3(-4.0, lift, -12.5),
		Vector3(4.0, lift, -12.5), false)

	await _corner_cases(tool, lift)

	await _guide_cases(tool, lift)

	await _joint_cases(tool, lift)

	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit()


func _corner_cases(tool: BuildTool, lift: float) -> void:

	var a:= Vector3(13.0, lift, -5.0)
	var b:= Vector3(13.0, lift, 2.0)
	world.builds.add_conveyor(a, b)
	for i in 10:
		await get_tree().process_frame

	print("\n=== the stub, before the anchor click ===")

	for deg in [0, 45, 90, 135, 180, 225, 270, 315]:
		var to: Vector3 = b + _heading(deg) * 1.6
		_expect("stub at %d deg" % deg, tool._evaluate(b, to, false), true)

	print("\n=== a real run leaving that end ===")


	for deg in [0, 45, 90, 315]:
		var to: Vector3 = b + _heading(deg) * 3.0
		_expect("run at %d deg" % deg, tool._evaluate(b, to, true), true)


	for deg in [135, 180, 225]:
		var to: Vector3 = b + _heading(deg) * 3.0
		_expect("hairpin at %d deg" % deg, tool._evaluate(b, to, true), false)

	print("\n=== a hairpin that climbs ===")


	for rise: float in [0.6, 1.5]:
		for deg in [90, 135, 180]:
			var to: Vector3 = b + _heading(deg) * sqrt(9.0 - rise * rise) + Vector3.UP * rise
			_reason("rise %.1f, turn %d" % [rise, deg], tool._evaluate(b, to, true),
				"" if deg == 90 else "turn further off the belt")

	print("\n=== belt on belt ===")


	_expect("straight down the middle",
		tool._evaluate(Vector3(13.0, lift, -4.0), Vector3(13.0, lift, 1.0), true), false)
	_expect("crossing it square",
		tool._evaluate(Vector3(10.0, lift, -1.0), Vector3(16.0, lift, -1.0), true), false)
	_expect("alongside, 1.2 m over",
		tool._evaluate(Vector3(14.2, lift, -4.0), Vector3(14.2, lift, 1.0), true), true)
	_expect("crossing it a metre above",
		tool._evaluate(Vector3(10.0, lift + 1.0, -1.0),
			Vector3(16.0, lift + 1.0, -1.0), true), true)


func _guide_cases(tool: BuildTool, lift: float) -> void:
	var base:= deg_to_rad(20.0)
	var fwd:= Vector3(sin(base), 0.0, cos(base))
	var b:= Vector3(-6.0, lift, -14.0) + fwd * 6.0
	world.builds.add_conveyor(Vector3(-6.0, lift, -14.0), b)
	for i in 10:
		await get_tree().process_frame

	print("\n=== heading guide ===")
	tool._state = BuildTool.State.RUNNING
	tool._joined = false
	for aim: int in [88, 92, 110, 45, 70]:
		var want:= _nearest_spoke(float(aim), rad_to_deg(base))
		var to: Vector3 = b + Vector3(sin(base + deg_to_rad(float(aim))), 0.0,
			cos(base + deg_to_rad(float(aim)))) * 5.0
		var got: Vector3 = tool._guided(b, to)
		var turn:= rad_to_deg(angle_difference(base,
			atan2(got.x - b.x, got.z - b.z)))
		var good:= absf(turn - want) < 0.5
		if not good:
			_fails += 1
		print("  aimed %3d deg off the run   %-4s want %6.1f  got %6.1f"
			% [aim, "ok" if good else "BAD", want, turn])

	print("\n=== previewed bend ===")
	for aim: int in [90, 3]:
		var to: Vector3 = b + Vector3(sin(base + deg_to_rad(float(aim))), 0.0,
			cos(base + deg_to_rad(float(aim)))) * 5.0
		var pts: PackedVector3Array = tool._preview_points(b, to)


		var want_bend: bool = aim == 90
		var good: bool = (pts.size() > 2) == want_bend
		if not good:
			_fails += 1
		print("  %2d deg turn                %-4s %d points%s"
			% [aim, "ok" if good else "BAD", pts.size(),
				"  (bend)" if pts.size() > 2 else "  (straight)"])

	print("\n=== previewed bend, laid upstream ===")


	var back:= Vector3(-6.0, lift, -14.0)
	for aim: int in [90, 3]:
		var dir:= Vector3(sin(base + deg_to_rad(float(aim))), 0.0,
			cos(base + deg_to_rad(float(aim))))
		var pts: PackedVector3Array = tool._preview_points(back - dir * 5.0, back)
		var want_bend: bool = aim == 90
		var good: bool = (pts.size() > 2) == want_bend
		if not good:
			_fails += 1
		print("  %2d deg turn                %-4s %d points%s"
			% [aim, "ok" if good else "BAD", pts.size(),
				"  (bend)" if pts.size() > 2 else "  (straight)"])

	print("\n=== the hologram walks the same line ===")


	for aim: int in [90, 3]:
		var to: Vector3 = b + Vector3(sin(base + deg_to_rad(float(aim))), 0.0,
			cos(base + deg_to_rad(float(aim)))) * 5.0
		var pts: PackedVector3Array = tool._preview_points(b, to)
		var total:= 0.0
		for i in pts.size() - 1:
			total += pts [i].distance_to(pts [i + 1])
		var head: Vector3 = tool._walk(pts, 0.0) ["point"]
		var tail: Vector3 = tool._walk(pts, total) ["point"]
		tool._eval = tool._evaluate(b, to, true)
		tool._shape_ghost(b, to)
		var n: int = tool._lay_ghost(pts)
		var good:= (head.distance_to(pts [0]) < 0.01
			and tail.distance_to(pts [pts.size() - 1]) < 0.01
			and n > 0 and n <= tool.GHOST_CAPACITY)
		if not good:
			_fails += 1
		print("  %2d deg turn                %-4s %5.2f m of line, %2d sections, "
			% [aim, "ok" if good else "BAD", total, n]
			+ "walked to %.3f m of each end"
			% maxf(head.distance_to(pts [0]), tail.distance_to(pts [pts.size() - 1])))

	tool._state = BuildTool.State.AIMING


static func _nearest_spoke(aim: float, base: float) -> float:
	var step:= rad_to_deg(Cfg.BELT_GUIDE_STEP)
	var best:= aim
	var best_d:= rad_to_deg(Cfg.BELT_GUIDE_WINDOW)
	for origin: float in [0.0, - base]:
		var spoke: float = origin + roundf((aim - origin) / step) * step
		if absf(aim - spoke) < best_d:
			best_d = absf(aim - spoke)
			best = spoke
	return best


static func _heading(deg: int) -> Vector3:
	var rad:= deg_to_rad(float(deg))
	return Vector3(sin(rad), 0.0, cos(rad))


func _expect(label: String, r: Dictionary, want_ok: bool) -> void:
	var ok: bool = r ["ok"]
	var good:= ok == want_ok
	if not good:
		_fails += 1
	print("  %-28s %-4s want %-5s got %-5s %s" % [label, "ok" if good else "BAD",
		str(want_ok), str(ok), r ["reason"]])


func _chord(tool: BuildTool, field: HayField, label: String,
		from: Vector3, to: Vector3, want_refused: bool) -> void:
	var length:= from.distance_to(to)
	var blocked: bool = tool._blocked(from, to, length)
	var in_pile: bool = tool._in_pile(from, to, length)

	var deepest:= 0.0
	var samples:= 40
	for i in samples + 1:
		var p:= from.lerp(to, float(i) / float(samples))
		deepest = maxf(deepest, field.height_at(p.x, p.z) - p.y)
	var refused:= blocked or in_pile
	if refused != want_refused:
		_fails += 1
	print("  %-30s %-4s len %5.1f  under hay %5.2f m  blocked %-5s  in_pile %-5s"
		% [label, "ok" if refused == want_refused else "BAD", length, deepest,
			str(blocked), str(in_pile)])


func _joint_cases(tool: BuildTool, lift: float) -> void:
	var p:= Vector3(-13.0, lift, 6.0)
	world.builds.add_conveyor(Vector3(-13.0, lift, 0.0), p)
	world.builds.add_conveyor(p, Vector3(-7.0, lift, 6.0))
	for i in 10:
		await get_tree().process_frame

	print("\n=== a third run at a full joint ===")


	_reason("leaving the elbow, outside", tool._evaluate(p,
		p + _heading(315) * 3.0, true), "already joined here  ·  use a splitter to branch")


	_reason("arriving at the elbow", tool._evaluate(
		p + _heading(315) * 3.0, p, true), "already joined here  ·  use a joiner to merge")


	_reason("the stub, anchored on it", tool._evaluate(p,
		p + _heading(315) * 1.6, false), "already joined here  ·  use a splitter to branch")

	_chain_cases(tool, p, lift)

	print("\n=== the wedge, off a plain joint ===")


	var q:= Vector3(-13.0, lift, -6.0)
	world.builds.add_conveyor(Vector3(-13.0, lift, -12.0), q)
	for i in 10:
		await get_tree().process_frame
	_reason("aimed back along the belt", tool._evaluate(q,
		q + _heading(200) * 3.0, true), "turn further off the belt")
	_reason("square off it", tool._evaluate(q, q + _heading(90) * 3.0, true), "")


	_reason("crossing a belt elsewhere", tool._evaluate(
		Vector3(-16.0, lift, -9.0), Vector3(-10.0, lift, -9.0), true), "blocked")

	await _same_side_cases(tool, lift)


func _same_side_cases(tool: BuildTool, lift: float) -> void:
	var r:= Vector3(-13.0, lift, 12.0)
	world.builds.add_conveyor(Vector3(-16.0, lift, 12.0), r)
	var s:= Vector3(-4.0, lift, 13.0)
	world.builds.add_conveyor(s, Vector3(-1.0, lift, 13.0))


	var t:= Vector3(8.0, lift, 13.0)
	world.builds.add_conveyor(Vector3(5.0, lift, 13.0), t)
	var turned: Conveyor = world.builds.add_conveyor(t, Vector3(8.0, lift, 16.0))
	for i in 10:
		await get_tree().process_frame

	print("\n=== a second run on the same side ===")
	_reason("arriving head to head", tool._evaluate(
		Vector3(-10.0, lift, 12.0), r, true), "already joined here  ·  use a joiner to merge")
	_reason("leaving beside a run out", tool._evaluate(
		s, s + _heading(0) * 3.0, true), "already joined here  ·  use a splitter to branch")

	print("\n=== a joint turned round ===")
	_truth("the second run turns round", world.builds.reverse_conveyor(turned))
	_reason("leaving two runs in", tool._evaluate(
		t, t + _heading(90) * 3.0, true), "already joined here  ·  use a splitter to branch")
	_reason("arriving at two runs in", tool._evaluate(
		t + _heading(90) * 3.0, t, true), "already joined here  ·  use a joiner to merge")


	print("\n=== a line started on the back of a belt ===")
	_truth("a belt's back end is a free tail", tool._free_tail(s))
	_truth("its front end is not", not tool._free_tail(Vector3(-1.0, lift, 13.0)))
	_truth("a turned joint is not", not tool._free_tail(t))
	var up:= s - _heading(0) * 3.0
	_expect("a run up to it", tool._evaluate(up, s, true), true)
	tool._lay_run(up, s)
	var fed: Conveyor = world.builds.feed_run_into(s)
	_truth("...feeds the belt it started on", fed != null and fed.a.is_equal_approx(up))
	_truth("...and its own back is the next tail", tool._free_tail(up))


func _chain_cases(tool: BuildTool, p: Vector3, lift: float) -> void:
	print("\n=== a line that connects ===")
	var stub:= p + _heading(315) * 1.6
	tool._state = BuildTool.State.RUNNING
	tool._anchor = p - _heading(0) * 6.0
	tool._chain_on(p, true)
	_truth("the last click stops the line", tool._state == BuildTool.State.AIMING)

	tool._update_run(p, stub, 0.016)
	_reason("the aim still on the joint", tool._eval, "belt connected")
	_truth("...said as done, not as a refusal", bool(tool._eval.get("done", false)))
	_truth("...and no red stub is drawn",
		tool._ghost.multimesh.visible_instance_count == 0)


	var off:= Vector3(-16.0, lift, 3.0)
	tool._update_run(off, off + _heading(90) * 1.6, 0.016)
	_expect("the aim moved off it", tool._eval, true)
	_truth("...and the finished joint is let go", tool._finished_at == Vector3.INF)

	tool._update_run(p, stub, 0.016)
	_reason("back on the joint later", tool._eval,
		"already joined here  ·  use a splitter to branch")


	tool._state = BuildTool.State.RUNNING
	tool._chain_on(off, false)
	_truth("a run ending on open floor chains on",
		tool._state == BuildTool.State.RUNNING and tool._anchor.is_equal_approx(off))
	tool._state = BuildTool.State.AIMING


func _truth(label: String, good: bool) -> void:
	if not good:
		_fails += 1
	print("  %-34s %s" % [label, "ok" if good else "BAD"])


func _reason(label: String, r: Dictionary, want: String) -> void:
	var got: String = r ["reason"]
	var good:= got == want
	if not good:
		_fails += 1
	print("  %-28s %-4s %s" % [label, "ok" if good else "BAD",
		got if got != "" else "(buildable)"])
