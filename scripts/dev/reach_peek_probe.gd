class_name DevReachPeekProbe
extends Node


const SETTLE:= 20


const NEAR:= 14.0
const FAR:= 30.0
const WALK:= 14.0

var world: Node3D
var player: Player

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _ok(what: String, pass_: bool, detail: String = "") -> void:
	if pass_:
		print("  ok    %s%s" % [what, "" if detail == "" else "   (%s)" % detail])
	else:
		_fails += 1
		print("  FAIL  %s%s" % [what, "" if detail == "" else "   (%s)" % detail])


func _drone_lit(drone: HayDrone) -> bool:
	var ring:= drone.find_child("RadiusRing", false, false) as MeshInstance3D
	return ring != null and ring.visible


func _rake_lit(rake: PistonRake) -> bool:
	var marks:= rake.find_child("Range", false, false) as RakeRange
	return marks != null and marks.visible


func _arm_lit(arm: RoboticArm) -> bool:
	var authored:= arm.find_child("RA_ReachGroundRing", true, false) as Node3D
	if authored != null and authored.visible:
		_ok("the authored ring stays hidden", false)
	return arm.range_lit()


func _mill_lit(mill: HayPelletizer) -> bool:
	return mill.range_shown()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _raise(tool: BuildTool, mode: BuildTool.Mode) -> void:
	tool.set_mode(mode)
	tool.set_active(true)
	await _wait(4)


func _tap(action: String) -> void:
	for down: bool in [true, false]:
		var ev:= InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await _wait(2)


func _run() -> void:
	await _wait(SETTLE)

	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	if builds == null or tool == null:
		print("[reachpeek] no build manager or no build tool")
		get_tree().quit(1)
		return


	player.capture_mouse(true)

	var here:= player.global_position


	var near_drone:= builds.add_hay_drone(here + Vector3(- NEAR, 0.0, 0.0), 0.0, 0.0)
	var far_drone:= builds.add_hay_drone(here + Vector3(FAR, 0.0, 0.0), 0.0, 0.0)
	var rake:= builds.add_piston_rake(here + Vector3(0.0, 0.0, 6.0), 0.0, 0.0)
	var arm:= builds.add_robotic_arm(here + Vector3(0.0, 0.0, -6.0), 0.0)


	var mill:= builds.add_pelletizer(here + Vector3(6.0, 0.0, 6.0), 0.0)
	await _wait(SETTLE)
	if near_drone == null or far_drone == null or rake == null or arm == null or mill == null:
		print("[reachpeek] the yard would not take the machines")
		get_tree().quit(1)
		return

	print("\n=== with the tool away ===")
	_ok("nothing is lit", not _drone_lit(near_drone) and not _rake_lit(rake)
		and not _arm_lit(arm) and not _mill_lit(mill))
	_ok("and the tool says so", not tool.is_peeking())


	_ok("a placed mill's arrow is down",
		mill.throw_aim() != null and mill.throw_aim().mode() == ThrowAim.OFF)

	print("\n=== a drone hologram, no button held ===")
	await _raise(tool, BuildTool.Mode.HAY_DRONE)
	_ok("the tool is peeking", tool.is_peeking())
	_ok("it knows which kind it is asking about", tool.reach_kind() == "drone")
	_ok("the near drone is lit", _drone_lit(near_drone))
	_ok("the far drone is not", not _drone_lit(far_drone),
		"%.0f m out, cut is %.0f" % [FAR, Cfg.RANGE_PEEK_DIST])
	_ok("the rake stayed dark", not _rake_lit(rake),
		"a throw is not a circle and the two cannot be compared")
	_ok("and so did the arm", not _arm_lit(arm))
	_ok("and so did the mill", not _mill_lit(mill))

	print("\n=== walking towards the far one ===")


	player.global_position = here + Vector3(WALK, 0.0, 0.0)
	await _wait(4)
	_ok("the player actually moved",
		absf(player.global_position.x - here.x - WALK) < 0.5,
		"or the shove-back has answered the next two checks instead")
	_ok("the far drone has come in", _drone_lit(far_drone))
	_ok("and the one behind has gone out", not _drone_lit(near_drone))
	player.global_position = here
	await _wait(4)
	_ok("walking back puts it the other way round",
		_drone_lit(near_drone) and not _drone_lit(far_drone))

	print("\n=== swapping to an arm ===")
	tool.set_mode(BuildTool.Mode.ROBOTIC_ARM)
	await _wait(4)
	_ok("the arm is lit now", _arm_lit(arm))
	_ok("and the drones came up with the old question",
		not _drone_lit(near_drone) and not _drone_lit(far_drone),
		"nothing sends an event for a mode change, which is why the reach is polled")

	print("\n=== swapping to a rake ===")
	tool.set_mode(BuildTool.Mode.PISTON_RAKE)
	await _wait(4)
	_ok("the rake is lit now", _rake_lit(rake))
	_ok("and the arm went dark", not _arm_lit(arm))

	print("\n=== swapping to a mill ===")
	tool.set_mode(BuildTool.Mode.PELLETIZER)
	await _wait(4)
	_ok("it knows which kind it is asking about",
		tool.reach_kind() == "pelletizer")
	_ok("the mill is lit now", _mill_lit(mill))
	_ok("and the rake went dark", not _rake_lit(rake))


	var aim:= mill.throw_aim()
	_ok("the arrow sits on the mill's own pad",
		aim != null and Vector2(aim.landing().x - mill.throw_target().x,
			aim.landing().z - mill.throw_target().z).length() < 0.3,
		"arrow %s against pad %s" % [
			aim.landing() if aim != null else Vector3.ZERO,
			mill.throw_target()])

	print("\n=== a hologram with no reach at all ===")
	tool.set_mode(BuildTool.Mode.CONVEYOR)
	await _wait(4)
	_ok("the tool has stopped peeking", not tool.is_peeking(),
		"a belt has nothing to compare against, so the floor says nothing")
	_ok("and the floor is clear", not _rake_lit(rake) and not _arm_lit(arm)
		and not _drone_lit(near_drone) and not _mill_lit(mill))

	print("\n=== putting the tool away ===")
	await _raise(tool, BuildTool.Mode.HAY_DRONE)
	_ok("it lit up again", _drone_lit(near_drone))
	tool.set_active(false)
	await _wait(4)
	_ok("the tool has stopped peeking", not tool.is_peeking())
	_ok("and the hologram going away puts it out", not _drone_lit(near_drone))

	await _check_put_away_keys(tool)

	print("\n=== %d checks failed ===" % _fails)

	get_tree().quit(1 if _fails > 0 else 0)


func _check_put_away_keys(tool: BuildTool) -> void:
	GameState.grant_tool("spade")
	Tech.grant("belt")
	Tech.grant("cabinet")
	player.select_hotbar_slot(1)
	await _wait(2)
	if player.current_tool != Player.Tool.SHOVEL:
		_ok("the spade came out to build from", false, "tool %d" % player.current_tool)
		return

	for key: String in ["secondary", "build_cancel"]:
		print("\n=== %s with a cabinet hologram ===" % key)
		player.equip_build("cabinet")
		await _wait(4)
		_ok("the hologram is up", tool.is_active())
		await _tap(key)
		_ok("it went away", not tool.is_active())
		_ok("and the spade is back in hand", player.current_tool == Player.Tool.SHOVEL,
			"tool %d" % player.current_tool)
		_ok("and still in the pockets", GameState.has_tool("spade"),
			"Q is drop_tool too, and must not go on to drop what it handed back")

	print("\n=== the right button with a belt run started ===")
	player.equip_build("belt")
	await _wait(4)


	tool._state = BuildTool.State.RUNNING
	await _tap("secondary")
	_ok("the first press only cancels the run", tool.is_active()
		and player.current_tool == Player.Tool.BUILD
		and tool._state == BuildTool.State.AIMING)
	await _tap("secondary")
	_ok("the second puts the hologram away",
		not tool.is_active() and player.current_tool == Player.Tool.SHOVEL)

	print("\n=== stepping from one hologram to another ===")
	player.equip_build("cabinet")
	player.equip_build("belt")
	await _wait(4)
	await _tap("secondary")
	_ok("the tool from before the FIRST hologram comes back",
		player.current_tool == Player.Tool.SHOVEL, "tool %d" % player.current_tool)

	print("\n=== B with a hologram up ===")
	player.equip_build("cabinet")
	await _wait(4)
	await _tap("build_catalog")
	_ok("the catalogue opened", player.catalog != null and player.catalog.is_open())
	if player.catalog != null:
		player.catalog.set_open(false)
	player.capture_mouse(true)
	await _wait(4)


	_ok("closing it with nothing picked leaves the hologram up",
		tool.is_active() and player.current_tool == Player.Tool.BUILD
		and player.build_id == "cabinet", "tool %d, %s" % [player.current_tool, player.build_id])
	await _tap("secondary")
	_ok("and it still goes back to the spade after",
		player.current_tool == Player.Tool.SHOVEL, "tool %d" % player.current_tool)

	print("\n=== the tool from before has been put down since ===")
	player.equip_build("cabinet")
	await _wait(4)
	GameState.take_tool("spade")
	await _tap("secondary")
	_ok("the hands come up empty", player.current_tool == Player.Tool.HAND,
		"tool %d" % player.current_tool)
