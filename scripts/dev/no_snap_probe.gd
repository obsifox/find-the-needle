class_name DevNoSnapProbe
extends Node


var world: Node3D
var player: Player


const STAND:= Vector3(13.37, 0.0, 9.21)


const END_OFFSET:= 0.6

var _pass:= 0
var _fail:= 0


func run() -> void:
	await get_tree().process_frame
	var tool: BuildTool = player.build
	if tool == null:
		_check("the player has a build tool", false)
		_finish()
		return
	_check("the key is bound", InputMap.has_action("build_no_snap")
		and not InputMap.action_get_events("build_no_snap").is_empty())
	await _case_belt(tool)
	await _case_full_joint(tool)
	await _case_machine(tool)
	_finish()


func _case_belt(tool: BuildTool) -> void:
	print("\n=== a belt stops snapping ===")
	Tech.grant("belt", 1)
	GameState.add_money(1000.0)
	player.global_position = STAND
	player.velocity = Vector3.ZERO
	player.set_look(0.62, -0.75)
	player.equip_build("belt")
	for _f in 6:
		await get_tree().process_frame
	_check("the tool comes up holding a belt", player.build_id == "belt")
	_check("the key answers on a belt", tool.can_stop_snapping())
	_check("snapping starts on", not tool.snap_stopped())
	_check("...and no warning is up", not _warning_up())


	var raw:= tool._surface_point(Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)
	var look:= player.look_direction()
	var side:= Vector3(- look.z, 0.0, look.x).normalized()
	var belt: Conveyor = world.builds.add_conveyor(raw + side * (END_OFFSET + 4.0),
		raw + side * END_OFFSET)
	for _f in 4:
		await get_tree().process_frame
	raw = tool._surface_point(Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)
	var end: Vector3 = belt.b
	print("[nosnap] aim %s, belt end %s, %.2f m apart"
		% [_fmt(raw), _fmt(end), raw.distance_to(end)])
	_check("the belt end is inside the snap radius",
		raw.distance_to(end) < Cfg.BELT_SNAP_RADIUS)

	_check("snapping on, the aim is pulled onto the belt end",
		tool._aim_point().is_equal_approx(end) and tool._joined)
	tool.primary()
	await get_tree().process_frame
	_check("...and a click anchors the run there",
		bool(tool.status() ["placing"]) and tool._anchor.is_equal_approx(end))
	tool.cancel()
	await get_tree().process_frame

	_press("build_no_snap")
	for _f in 4:
		await get_tree().process_frame
	_check("F switches snapping off", tool.snap_stopped())
	_check("...and puts the red warning up", _warning_up())
	_check("...which says the queue will not hold",
		world.hud._no_snap.text.get_slice_count("\n") == 3)


	var live:= tool._surface_point(Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)
	var aim:= tool._aim_point()
	_check("snapping off, the aim stays where the crosshair is %s" % _fmt(aim),
		aim.distance_to(live) < 0.01 and not tool._joined)
	tool.primary()
	await get_tree().process_frame
	_check("...and a click anchors the run there too, not on the belt",
		bool(tool.status() ["placing"]) and tool._anchor.distance_to(live) < 0.01)
	tool.cancel()
	await get_tree().process_frame
	_check("the switch survives cancelling a run", tool.snap_stopped())

	_press("build_no_snap")
	for _f in 4:
		await get_tree().process_frame
	_check("a second press turns snapping back on", not tool.snap_stopped())
	_check("...and takes the warning down", not _warning_up())
	_check("...and the aim snaps again", tool._aim_point().is_equal_approx(end))

	_press("build_no_snap")
	for _f in 4:
		await get_tree().process_frame
	player._set_tool(Player.Tool.HAND)
	for _f in 4:
		await get_tree().process_frame
	_check("the warning goes with the belt when it is put away", not _warning_up())
	player.equip_build("belt")
	for _f in 4:
		await get_tree().process_frame
	_check("...and the belt comes back snapping", not tool.snap_stopped())


func _case_full_joint(_tool: BuildTool) -> void:
	print("\n=== a corner is not snapped to ===")


	var builds: BuildManager = world.builds
	var corner:= STAND + Vector3(0.0, 0.0, 30.0)
	var tail:= corner + Vector3(4.0, 0.0, 0.0)
	builds.add_conveyor(corner - Vector3(4.0, 0.0, 0.0), corner)
	builds.add_conveyor(corner, tail)
	await get_tree().process_frame


	var near:= corner + Vector3(0.3, 0.0, 0.22)
	_check("the corner has a load in and a load out", builds.joint_full(corner))
	_check("...so an aim beside it is left where it is",
		builds.snap_endpoint(near).is_equal_approx(near))


	_check("a free end is not full", not builds.joint_full(tail))
	_check("...and still pulls an aim onto itself",
		builds.snap_endpoint(tail + Vector3(0.3, 0.0, 0.22)).is_equal_approx(tail))


	builds.add_conveyor(tail + Vector3(0.0, 0.0, 4.0), tail)
	await get_tree().process_frame
	_check("a second run arriving fills it", builds.joint_full(tail))
	_check("...and the aim is handed back", builds.snap_endpoint(
		tail + Vector3(0.3, 0.0, 0.22)).is_equal_approx(tail + Vector3(0.3, 0.0, 0.22)))


func _case_machine(tool: BuildTool) -> void:
	print("\n=== a press stops snapping to a splitter ===")
	Tech.grant("compressor", 1)
	player.equip_build("belt")
	for _f in 4:
		await get_tree().process_frame
	_press("build_no_snap")
	for _f in 4:
		await get_tree().process_frame
	_check("switched off with a belt in hand", tool.snap_stopped())
	player.equip_build("compressor")
	for _f in 4:
		await get_tree().process_frame
	_check("the tool comes up holding a press", player.build_id == "compressor")
	_check("the key answers on a press", tool.can_stop_snapping())
	_check("...the belt's switch did not follow it", not tool.snap_stopped())
	_check("...and no warning is up", not _warning_up())


	var site:= STAND + Vector3(0.0, 0.0, -30.0)
	var q:= PhysicsRayQueryParameters3D.create(site + Vector3.UP * 20.0,
		site - Vector3.UP * 20.0)
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	var hit:= tool.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		site.y = (hit ["position"] as Vector3).y
	var builds: BuildManager = world.builds
	var splitter:= builds.add_splitter(
		site + Vector3.UP * (Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR), 0.0)
	await get_tree().process_frame
	var mouth: Dictionary = { }
	for j in builds.free_line_joints(splitter.global_position, 3.0):
		if bool(j ["wye"]) and not bool(j ["start"]):
			mouth = j
			break
	_check("the splitter has a free arm", not mouth.is_empty())
	if mouth.is_empty():
		builds.demolish(splitter)
		player._set_tool(Player.Tool.HAND)
		return
	var spec:= tool._seat_spec(BuildTool.Mode.COMPRESSOR)
	var f: Vector3 = mouth ["forward"]
	var side:= Vector3(- f.z, 0.0, f.x)

	var on:= (mouth ["point"] as Vector3) + f * (MachineSeat.MOUTH_BELT + float(spec ["in"]))
	on.y = site.y
	var r:= Cfg.COMPRESSOR_SNAP_RADIUS
	var seat:= tool._seat_on_line(on, r, spec)
	_check("snapping on, a press aimed on the arm's lane seats on it",
		not seat.is_empty() and bool(seat.get("lane", false)))
	_check("...but not one aimed a metre beside the lane",
		tool._seat_on_line(on + side * 1.0, r, spec).is_empty())
	_check("...nor one aimed two metres further out along it",
		tool._seat_on_line(on + f * 2.0, r, spec).is_empty())

	_press("build_no_snap")
	for _f in 4:
		await get_tree().process_frame
	_check("F switches a press's snapping off", tool.snap_stopped())
	_check("...and puts the red warning up", _warning_up())
	_check("...without the belt's queue line",
		world.hud._no_snap.text.get_slice_count("\n") == 2)
	_check("snapping off, the same aim on the lane stands free",
		tool._seat_on_line(on, r, spec).is_empty())
	_press("build_no_snap")
	for _f in 4:
		await get_tree().process_frame
	_check("a second press turns it back on", not tool.snap_stopped())
	_check("...and the lane catches the press again",
		not tool._seat_on_line(on, r, spec).is_empty())
	builds.demolish(splitter)
	player._set_tool(Player.Tool.HAND)


func _warning_up() -> bool:
	var hud: Hud = world.hud
	if hud == null:
		return false
	return hud._no_snap.visible


func _fmt(at: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [at.x, at.y, at.z]


func _press(action: String) -> void:
	for e in InputMap.action_get_events(action):
		var key:= e as InputEventKey
		if key == null:
			continue
		for down: bool in [true, false]:
			var ev:= key.duplicate() as InputEventKey
			ev.pressed = down
			Input.parse_input_event(ev)
		return
	_check("the %s action has a key bound to press" % action, false)


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _finish() -> void:
	print("[nosnap] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
