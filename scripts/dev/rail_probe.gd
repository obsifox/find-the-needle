class_name DevRailProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 20


const RUN_LEN:= 8.0


const WIN_FROM:= 3.0
const WIN_TO:= 3.0 + Cfg.BELT_WIDTH

var _fails:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(11.0, 0.4, 0.0)
	GameState.add_money(5000.0)
	for i in SETTLE:
		await get_tree().process_frame

	print("\n=== the kit ===")
	_check("section still carries 3 surfaces",
		ConveyorKit.segment_mesh().get_surface_count(), 3)
	for side: int in [-1, 1]:
		var m:= ConveyorKit.rail_mesh(side)
		_check("rail %+d is one surface" % side,
			m.get_surface_count() if m != null else -1, 1)
	_check("the two rails are different meshes",
		1 if ConveyorKit.rail_mesh(-1) != ConveyorKit.rail_mesh(1) else 0, 1)

	print("\n=== a plain run, which must be what it always was ===")
	var a:= Vector3(13.0, 0.75, - RUN_LEN * 0.5)
	var b:= Vector3(13.0, 0.75, RUN_LEN * 0.5)
	var plain: Conveyor = world.builds.add_conveyor(a, b)
	for i in SETTLE:
		await get_tree().physics_frame
	var sections:= _instances(plain, "Sections")
	_check("both rails drawn on every section (L)", _instances(plain, "RailL"),
		sections)
	_check("both rails drawn on every section (R)", _instances(plain, "RailR"),
		sections)


	_near("left rail spans the whole run", _rail_length(plain, -1), RUN_LEN)
	_near("right rail spans the whole run", _rail_length(plain, 1), RUN_LEN)

	print("\n=== one side opened ===")


	plain.open_windows = [{ "side": 1, "from": WIN_FROM, "to": WIN_TO }]
	plain.build_path(PackedVector3Array([plain.laid_start(), plain.laid_end()]))
	for i in SETTLE:
		await get_tree().physics_frame
	var win:= WIN_TO - WIN_FROM
	_check("the untouched side is still whole", _instances(plain, "RailL"),
		_instances(plain, "Sections"))
	_check("the opened side has lost sections",
		1 if _instances(plain, "RailR") < _instances(plain, "RailL") else 0, 1)
	_near("left rail collider untouched", _rail_length(plain, -1), RUN_LEN)
	_near("right rail collider is short by the window",
		_rail_length(plain, 1), RUN_LEN - win)


	_check("no rail piece stands in the window",
		_pieces_inside(plain, 1, WIN_FROM, WIN_TO), 0)


	_near("the deck is untouched by a rail window", _deck_length(plain), RUN_LEN)

	print("\n=== both sides opened ===")
	plain.open_windows = [
		{ "side": 1, "from": WIN_FROM, "to": WIN_TO },
		{ "side": -1, "from": WIN_FROM, "to": WIN_TO },
	]
	plain.build_path(PackedVector3Array([plain.laid_start(), plain.laid_end()]))
	for i in SETTLE:
		await get_tree().physics_frame
	_near("left rail short by the window", _rail_length(plain, -1), RUN_LEN - win)
	_near("right rail short by the window", _rail_length(plain, 1), RUN_LEN - win)
	_near("the deck is still whole", _deck_length(plain), RUN_LEN)

	print("\n=== a window running off the end ===")


	plain.open_windows = [{ "side": 1, "from": -5.0, "to": 2.0 }]
	plain.build_path(PackedVector3Array([plain.laid_start(), plain.laid_end()]))
	for i in SETTLE:
		await get_tree().physics_frame
	_near("rail is what is left past the window", _rail_length(plain, 1),
		RUN_LEN - 2.0)


	_check("no zero-length collider in front of it", _rail_boxes(plain, 1), 1)

	plain.open_windows = []
	plain.build_path(PackedVector3Array([plain.laid_start(), plain.laid_end()]))

	print("\n=== a third belt tapped into a joint ===")


	world.builds.demolish(plain)
	for i in SETTLE:
		await get_tree().physics_frame
	var joint:= Vector3(13.0, 0.75, 0.0)
	var west:= joint + Vector3(0.0, 0.0, -4.0)
	var east:= joint + Vector3(0.0, 0.0, 4.0)
	var north:= joint + Vector3(4.0, 0.0, 0.0)
	var run_in: Conveyor = world.builds.add_conveyor(west, joint)
	var run_on: Conveyor = world.builds.add_conveyor(joint, east)
	for i in SETTLE:
		await get_tree().physics_frame


	_check("two runs end to end open nothing", run_in.open_windows.size()
		+ run_on.open_windows.size(), 0)

	var branch: Conveyor = world.builds.add_conveyor(north, joint)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("the branch opens both its own sides", branch.open_windows.size(), 2)
	_check("the run into the joint opens one", run_in.open_windows.size(), 1)
	_check("the run out of it opens one", run_on.open_windows.size(), 1)


	_check("...and keeps its far wall", _rail_boxes(run_in, -1), 1)
	_near("the near wall is out by exactly the reach",
		4.0 - _rail_length(run_in, 1), Cfg.BELT_JOINT_REACH, 0.002)
	_check("no rail piece left standing in the branch's mouth",
		_pieces_inside(run_in, 1, 4.0 - Cfg.BELT_JOINT_REACH, 4.0), 0)
	_near("the branch deck is untouched", _deck_length(branch), 4.0)

	print("\n=== and closed again when the branch goes ===")
	world.builds.demolish(branch)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("no window left on the through runs",
		run_in.open_windows.size() + run_on.open_windows.size(), 0)
	_near("the wall is back", _rail_length(run_in, 1), 4.0)
	_check("...in one piece", _rail_boxes(run_in, 1), 1)

	print("\n=== a CURVED joint, where the bend owns the junction ===")


	world.builds.demolish(run_on)
	for i in SETTLE:
		await get_tree().physics_frame
	var turned: Conveyor = world.builds.add_conveyor(joint,
		joint + Vector3(0.0, 0.0, 4.0) + Vector3(4.0, 0.0, 0.0))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a bend was fitted", world.builds.corners.size(), 1)
	var bend: ConveyorCorner = world.builds.corners [0]
	_check("the bend has no window with nothing tapped in",
		bend.open_windows.size(), 0)

	var tap: Conveyor = world.builds.add_conveyor(north, joint)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("the bend is still there", world.builds.corners.size(), 1)
	bend = world.builds.corners [0]
	_check("the BEND opens, which is the fix", bend.open_windows.size(), 1)
	_check("the tapped-in run opens both its sides", tap.open_windows.size(), 2)


	_check("the filleted runs are left alone", run_in.open_windows.size()
		+ turned.open_windows.size(), 0)
	_check("the bend keeps its far wall", 1 if _rail_boxes(bend, -1) > 0 else 0, 1)


	_check("and the near one goes end to end", _rail_boxes(bend, 1), 0)
	_check("which is the whole bend, because it is shorter than the mouth",
		1 if bend.path_length() < Cfg.BELT_JOINT_REACH * 2.0 else 0, 1)

	world.builds.demolish(tap)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("the bend closes again", 1 if world.builds.corners.size() > 0
		and world.builds.corners [0].open_windows.size() == 0 else 0, 1)

	print("\n=== the bend's own drawing, which is not a MultiMesh ===")


	bend = world.builds.corners [0]
	var skin:= bend.get_node_or_null("Path/Sections") as MeshInstance3D
	_check("drawn as one swept skin", 1 if skin != null else 0, 1)
	_check("...of rubber, frame and roller",
		0 if skin == null or skin.mesh == null else skin.mesh.get_surface_count(), 3)
	var running: Mesh = skin.mesh if skin != null else null
	bend.set_deck_held(true)
	_check("held, it draws a different mesh",
		1 if skin != null and skin.mesh != running else 0, 1)
	_check("...with the same surfaces on it",
		0 if skin == null or skin.mesh == null else skin.mesh.get_surface_count(),
		0 if running == null else running.get_surface_count())
	bend.set_deck_held(false)
	_check("running again, it is the skin it was swept with",
		1 if skin != null and skin.mesh == running else 0, 1)

	world.builds.demolish(turned)
	world.builds.add_conveyor(joint, east)
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== a wye draws no belt of its own, rails included ===")


	var wye: ConveyorSplitter = world.builds.add_splitter(
		Vector3(13.0, 0.75, 6.0), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	var lanes:= 0
	var showing:= 0
	for route in wye.get_children():
		var root:= route.get_node_or_null("Path")
		if root == null:
			continue
		lanes += 1
		for n: String in ["Sections", "RailL", "RailR"]:
			var mmi:= root.get_node_or_null(n) as MultiMeshInstance3D
			if mmi != null and mmi.visible:
				showing += 1


	_check("the wye laid its two routes", lanes, 2)
	_check("and draws no part of either", showing, 0)
	world.builds.demolish(wye)
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== a belt aimed at a flank is still not a junction ===")


	var flank_at:= Vector3(13.0, 0.75, -2.0)
	var flank: Conveyor = world.builds.add_conveyor(
		flank_at + Vector3(4.0, 0.0, 0.0), flank_at)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("the flank opened nothing in the run", run_in.open_windows.size(), 0)
	_check("and nothing in itself", flank.open_windows.size(), 0)
	_near("the wall is whole", _rail_length(run_in, 1), 4.0)


	world.builds.demolish(flank)
	world.builds.demolish(run_in)
	for i in SETTLE:
		await get_tree().physics_frame


	print("\n=== no trestle stands where the bend ate the belt ===")


	world.builds.clear()
	for i in SETTLE:
		await get_tree().physics_frame
	var leg_joint:= Vector3(13.0, 0.75, 0.0)
	var leg_in: Conveyor = world.builds.add_conveyor(
		leg_joint + Vector3(-5.0, 0.0, 0.0), leg_joint)


	var leg_out: Conveyor = world.builds.add_conveyor(leg_joint,
		leg_joint + Vector3(-3.5, 0.0, 3.5))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a bend was fitted", world.builds.corners.size(), 1)
	var turn:= leg_in.forward.angle_to(leg_out.forward)
	_check("...sharp enough that its apex clears the belt",
		1 if 0.5 * leg_in.trim_end * sin(turn * 0.5) > Cfg.BELT_WIDTH * 0.5
			else 0, 1)
	_check("the incoming run was trimmed back off the joint",
		1 if leg_in.trim_end > 0.05 else 0, 1)


	_check("no post on the incoming run is past what it laid",
		_stations_off_run(leg_in), 0)
	_check("nor on the outgoing one", _stations_off_run(leg_out), 0)


	_check("and none is standing at the apex",
		_stations_near(leg_in, leg_in.length) + _stations_near(leg_out, 0.0), 0)
	_check("the run still has posts under the part that IS laid",
		1 if leg_in.support_stations().size() > 0 else 0, 1)


	_check("and it grew exactly the posts it decided on",
		_leg_count(leg_in), leg_in.support_stations().size() * 2)


	world.builds.demolish(leg_out)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("taking the bend away puts the end post back",
		_stations_near(leg_in, leg_in.length), 1)


	world.builds.demolish(leg_in)
	for i in SETTLE:
		await get_tree().physics_frame
	var short_a:= Vector3(13.0, 0.75, -6.0)
	var short_b:= short_a + Vector3(3.0, 0.0, 0.0)
	var stub: Conveyor = world.builds.add_conveyor(short_a, short_b)
	world.builds.add_conveyor(short_a + Vector3(-2.5, 0.0, 2.5), short_a)
	world.builds.add_conveyor(short_b, short_b + Vector3(2.5, 0.0, 2.5))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a short run bitten at both ends is bitten at both ends",
		1 if stub.trim_start > 0.05 and stub.trim_end > 0.05 else 0, 1)
	_check("...and still stands on something",
		1 if stub.support_stations().size() > 0 else 0, 1)
	_check("...which is not outside it", _stations_off_run(stub), 0)

	print("\n=== a switchback, which is the shape that folded a bend ===")


	world.builds.clear()
	for i in SETTLE:
		await get_tree().physics_frame
	var turn_a:= Vector3(20.0, 0.75, -4.0)
	var turn_b:= Vector3(20.0, 0.75, 0.0)
	var turn_c:= turn_b + Vector3(1.05, 0.0, 0.0)
	world.builds.add_conveyor(turn_a, turn_b)
	var link: Conveyor = world.builds.add_conveyor(turn_b, turn_c)
	world.builds.add_conveyor(turn_c, turn_c + Vector3(0.0, 0.0, -4.0))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a switchback fits two bends", world.builds.corners.size(), 2)
	_near("...off a link too short to give either one room", link.length, 1.05, 0.01)
	var pinched:= 0
	var folded:= 0
	for fillet: ConveyorCorner in world.builds.corners:
		pinched += _pinched_rings(fillet)
		folded += _folded_rings(fillet)


	_check("...tight enough that the bound has work to do",
		1 if pinched > 0 else 0, 1)
	_check("and no edge of either bend runs backwards", folded, 0)

	world.builds.clear()
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== a post stands on bare floor and nothing else ===")


	var high: Conveyor = world.builds.add_conveyor(Vector3(13.0, 2.5, -6.0),
		Vector3(19.4, 2.5, -6.0))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a run over clear floor decides on three stations",
		high.support_stations().size(), 3)
	_check("...and grows a pair at every one", _leg_count(high), 6)
	var under: Conveyor = world.builds.add_conveyor(Vector3(16.2, 0.75, -9.0),
		Vector3(16.2, 0.75, -3.0))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a belt laid underneath takes the pair standing on it away",
		_leg_count(high), 4)
	world.builds.demolish(under)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("and taking that belt up puts the pair back", _leg_count(high), 6)

	world.builds.add_platform(Vector3(24.0, 1.5, -6.0), Vector2(8.0, 4.0))
	for i in SETTLE:
		await get_tree().physics_frame
	var on_deck: Conveyor = world.builds.add_conveyor(Vector3(21.0, 2.25, -6.0),
		Vector3(27.4, 2.25, -6.0))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("a run across a deck still stands on the deck", _leg_count(on_deck), 6)

	world.builds.clear()
	for i in SETTLE:
		await get_tree().physics_frame


	for i in 5:
		await get_tree().process_frame
	print("\n=== %s ===" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _bend_frames(bend: ConveyorCorner) -> Array:
	if bend.draw_curve.size() < 3:
		return []
	var local:= PackedVector3Array()
	for p: Vector3 in bend.draw_curve:
		local.append(p - bend.draw_curve [0])
	return BeltSweep.frames(local)


func _folded_rings(bend: ConveyorCorner) -> int:
	var fr:= _bend_frames(bend)
	var bad:= 0
	for i in maxi(fr.size() - 1, 0):
		var lo: Array = fr [i]
		var hi: Array = fr [i + 1]
		var along: Vector3 = lo [3]
		var lo_lim: Vector2 = lo [5]
		var hi_lim: Vector2 = hi [5]
		for x: float in [- BeltSweep.LIP_X, - BeltSweep.CARRY_HW,
				BeltSweep.CARRY_HW, BeltSweep.LIP_X]:
			var a: Vector3 = (lo [0] as Vector3) + (lo [1] as Vector3) * clampf(x, lo_lim.x, lo_lim.y)
			var b: Vector3 = (hi [0] as Vector3) + (hi [1] as Vector3) * clampf(x, hi_lim.x, hi_lim.y)
			if (b - a).dot(along) <= 0.0:
				bad += 1
	return bad


func _pinched_rings(bend: ConveyorCorner) -> int:
	var n:= 0
	for f: Array in _bend_frames(bend):
		var lim: Vector2 = f [5]
		if lim.x > - BeltSweep.CARRY_HW or lim.y < BeltSweep.CARRY_HW:
			n += 1
	return n


func _leg_count(run: Conveyor) -> int:
	var mmi:= run.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		return 0
	return mmi.multimesh.instance_count


func _stations_off_run(run: Conveyor) -> int:
	var slack:= Conveyor.SUPPORT_TRIM_SLACK
	var lo:= run.trim_start - slack
	var hi:= run.length - run.trim_end + slack
	var off:= 0
	for s: float in run.support_stations():
		if s < lo or s > hi:
			off += 1
	return off


func _stations_near(run: Conveyor, want: float) -> int:
	var near:= 0
	for s: float in run.support_stations():
		if absf(s - want) <= 0.25:
			near += 1
	return near


func _instances(path: BeltPath, mm_name: String) -> int:
	var root:= path.get_node_or_null("Path")
	if root == null:
		return -1
	var mmi:= root.get_node_or_null(mm_name) as MultiMeshInstance3D
	return mmi.multimesh.instance_count if mmi != null else -1


func _pieces_inside(path: BeltPath, side: int, from: float, to: float) -> int:
	var root:= path.get_node_or_null("Path")
	if root == null:
		return -1
	var mmi:= root.get_node_or_null("RailR" if side > 0 else "RailL") as MultiMeshInstance3D
	if mmi == null:
		return -1
	var run:= path as Conveyor
	if run == null:
		return -1
	var n:= 0
	for i in mmi.multimesh.instance_count:
		var s: float = (mmi.multimesh.get_instance_transform(i).origin
			- run.laid_start()).dot(run.forward)
		if s > from and s < to:
			n += 1
	return n


func _rail_length(path: BeltPath, side: int) -> float:
	var total:= 0.0
	for cs in _rail_shapes(path, side):
		total += (cs.shape as BoxShape3D).size.z
	return total


func _rail_boxes(path: BeltPath, side: int) -> int:
	return _rail_shapes(path, side).size()


func _rail_shapes(path: BeltPath, side: int) -> Array [CollisionShape3D]:
	var out: Array [CollisionShape3D] = []
	var root:= path.get_node_or_null("Path")
	if root == null:
		return out
	var want:= side * (Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T) * 0.5
	for body in root.get_children():
		if not (body is StaticBody3D):
			continue
		for cs in body.get_children():
			var shape:= cs as CollisionShape3D
			if shape == null or not (shape.shape is BoxShape3D):
				continue
			if absf(shape.position.x - want) < 0.01:
				out.append(shape)
	return out


func _deck_length(path: BeltPath) -> float:
	var total:= 0.0
	var root:= path.get_node_or_null("Path")
	if root == null:
		return 0.0
	for body in root.get_children():
		if not (body is StaticBody3D):
			continue
		for cs in body.get_children():
			var shape:= cs as CollisionShape3D
			if shape == null or not (shape.shape is BoxShape3D):
				continue

			var box:= shape.shape as BoxShape3D
			if absf(box.size.x - Cfg.BELT_WIDTH) < 0.01:
				total += box.size.z
	return total


func _check(what: String, got: int, want: int) -> void:
	var ok:= got == want
	if not ok:
		_fails += 1
	print("  %s %-46s %d (want %d)" % ["OK  " if ok else "FAIL", what, got, want])


func _near(what: String, got: float, want: float, tol: float = 0.05) -> void:
	var ok:= absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("  %s %-46s %.3f (want %.3f)"
		% ["OK  " if ok else "FAIL", what, got, want])
