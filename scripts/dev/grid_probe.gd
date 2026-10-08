class_name DevGridProbe
extends Node


var world: Node3D
var player: Player


const STAND:= Vector3(13.37, 0.0, 9.21)

var _pass:= 0
var _fail:= 0


func run() -> void:
	await get_tree().process_frame
	var tool: BuildTool = player.build
	if tool == null:
		_check("the player has a build tool", false)
		_finish()
		return

	_case_constants()
	await _case_machine(tool)
	await _case_run(tool)
	await _case_arm(tool)
	await _case_free_pieces(tool)
	await _case_deck_seam(tool)
	_finish()


func _case_deck_seam(tool: BuildTool) -> void:
	print("\n=== a hologram on the seam between two decks ===")
	var builds: BuildManager = world.builds
	var z:= roundf(STAND.z) + 30.0
	var left:= builds.add_platform(Vector3(41.0, 3.0, z), Vector2(4.0, 4.0))
	var right:= builds.add_platform(Vector3(45.0, 3.0, z), Vector2(4.0, 4.0))
	for i in 3:
		await get_tree().physics_frame
	var top:= left.top_y()
	var seam:= Vector3(43.0, top, z)
	var raw_q:= PhysicsRayQueryParameters3D.create(seam + Vector3.UP * Cfg.BUILD_GRID_PROBE,
		seam + Vector3.DOWN * Cfg.BUILD_GRID_PROBE)
	raw_q.collision_mask = Cfg.BUILD_SURFACE_MASK
	var raw:= tool.get_world_3d().direct_space_state.intersect_ray(raw_q)
	print("  (raw ray down the seam: %s)" % ("nothing" if raw.is_empty()
		else "y %.3f, normal %s" % [raw ["position"].y, raw ["normal"]]))
	for aim_x: float in [43.3, 42.7]:
		var fake:= { "position": Vector3(aim_x, top, z + 0.2), "normal": Vector3.UP }
		var got: Dictionary = tool._grid_hit(fake)
		var at: Vector3 = got ["position"]
		var normal: Vector3 = got ["normal"]
		_check("aimed at x %.1f it lands on the seam crossing (%.2f, %.2f)"
			% [aim_x, at.x, at.z], is_equal_approx(at.x, 43.0) and is_equal_approx(at.z, z))
		_check("at the deck's height, not the floor's (%.3f against %.3f)" % [at.y, top],
			absf(at.y - top) < 0.02)
		_check("and reads as level (normal %s)" % normal, normal.dot(Vector3.UP) > 0.99)
	builds.demolish(left)
	builds.demolish(right)
	await get_tree().physics_frame


func _case_constants() -> void:
	print("\n=== the lattice divides the deck ===")
	_check("the grid step is half a platform tile (%.2f m against %.2f m)"
		% [Cfg.BUILD_GRID_STEP, Cfg.PLATFORM_TILE],
		is_equal_approx(Cfg.BUILD_GRID_STEP * 2.0, Cfg.PLATFORM_TILE))
	_check("the drawn grid reaches past the furthest the wheel winds a ghost"
		+ " (%.1f m against %.1f m)" % [Cfg.BUILD_GRID_RADIUS, Cfg.BUILD_REACH_MAX],
		Cfg.BUILD_GRID_RADIUS > Cfg.BUILD_REACH_MAX)
	_check("the key is bound", InputMap.has_action("build_grid")
		and not InputMap.action_get_events("build_grid").is_empty())


func _case_machine(tool: BuildTool) -> void:
	print("\n=== a press goes on a crossing, and faces square ===")
	Tech.grant("compressor", 1)
	player.global_position = STAND
	player.velocity = Vector3.ZERO


	player.set_look(0.62, -0.75)
	player.equip_build("compressor")
	_check("the tool comes up holding a press",
		BuildCatalog.is_unlocked("compressor") and player.build_id == "compressor")
	for _f in 6:
		await get_tree().process_frame

	var ghost: HayCompressor = tool.get_node_or_null("CompressorGhost")
	if ghost == null:
		_check("the tool carries a press hologram", false)
		return
	_check("the key answers on a press", tool.snaps_to_grid())
	_check("the grid starts switched off", not tool.grid_snapping())

	var free_at:= ghost.global_position
	var free_yaw:= ghost.global_rotation.y
	_check("free-aimed, it sits off the lattice %s" % _fmt(free_at),
		not _on_lattice(free_at))

	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("the key switches the grid on", tool.grid_snapping())

	var on_at:= ghost.global_position
	print("[gridsnap] free %s -> snapped %s" % [_fmt(free_at), _fmt(on_at)])
	_check("...and the press moves onto a crossing %s" % _fmt(on_at),
		_on_lattice(on_at))


	var moved:= Vector2(on_at.x - free_at.x, on_at.z - free_at.z)
	_check("...to the NEAREST one, not the tidiest (%.2f m, %.2f m)"
		% [moved.x, moved.y],
		absf(moved.x) <= Cfg.BUILD_GRID_STEP * 0.5 + 0.01
		and absf(moved.y) <= Cfg.BUILD_GRID_STEP * 0.5 + 0.01)
	_check("...and it stays on the floor it was standing on (%.3f m up)"
		% (on_at.y - free_at.y), absf(on_at.y - free_at.y) < 0.25)


	var fwd:= ghost.forward()
	var square:= absf(fwd.x) < 0.001 or absf(fwd.z) < 0.001
	_check("the press faces a world quarter (%.1f deg off the free aim)"
		% absf(rad_to_deg(angle_difference(ghost.global_rotation.y, free_yaw))),
		square)


	var plate: MeshInstance3D = tool.get_node_or_null("BuildGrid")
	if plate == null:
		_check("the tool carries a grid to draw", false)
	else:
		_check("the grid is drawn while it is on", plate.visible)
		_check("...over the aim rather than at the world origin",
			Vector2(plate.global_position.x - on_at.x,
				plate.global_position.z - on_at.z).length() < Cfg.BUILD_GRID_STEP)

	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("a second press puts it back to free placing", not tool.grid_snapping())
	if plate != null:
		_check("...and takes the drawing away", not plate.visible)


func _case_run(tool: BuildTool) -> void:
	print("\n=== a run starts on a crossing ===")
	Tech.grant("belt", 1)


	GameState.add_money(1000.0)
	player.equip_build("belt")
	_check("the tool comes up holding a belt",
		BuildCatalog.is_unlocked("belt") and player.build_id == "belt")
	for _f in 6:
		await get_tree().process_frame
	_check("the key answers on a run", tool.snaps_to_grid())
	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("the grid comes on for a run", tool.grid_snapping())

	print("[gridsnap] the run reads %s" % tool.status())
	tool.primary()
	await get_tree().process_frame


	_check("the click starts a run", bool(tool.status() ["placing"]))
	var start: Vector3 = tool._anchor
	print("[gridsnap] run anchored at %s" % _fmt(start))
	_check("the first click lands on a crossing %s" % _fmt(start),
		_on_lattice(start) and start != Vector3.ZERO)
	tool.cancel()
	await get_tree().process_frame
	_check("...and cancelling leaves nothing standing",
		world.builds.conveyors.is_empty())


func _case_arm(tool: BuildTool) -> void:
	print("\n=== an arm goes on a crossing, and faces square ===")
	Tech.grant("arm_small", 1)
	player.global_position = STAND
	player.velocity = Vector3.ZERO
	player.set_look(0.62, -0.75)
	player.equip_build("arm")
	_check("the tool comes up holding an arm", player.build_id == "arm")
	for _f in 6:
		await get_tree().process_frame
	var ghost: Node3D = tool.get_node_or_null("RoboticArmGhost")
	if ghost == null:
		_check("the tool carries an arm hologram", false)
		return
	_check("the key answers on an arm", tool.snaps_to_grid())
	var free_at:= ghost.global_position
	_check("free-aimed, it sits off the lattice %s" % _fmt(free_at),
		not _on_lattice(free_at))
	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("the key switches the grid on for an arm", tool.grid_snapping())
	var on_at:= ghost.global_position
	print("[gridsnap] arm free %s -> snapped %s" % [_fmt(free_at), _fmt(on_at)])
	_check("...and the arm moves onto a crossing %s" % _fmt(on_at),
		_on_lattice(on_at))
	var moved:= Vector2(on_at.x - free_at.x, on_at.z - free_at.z)
	_check("...the nearest one (%.2f m, %.2f m)" % [moved.x, moved.y],
		absf(moved.x) <= Cfg.BUILD_GRID_STEP * 0.5 + 0.01
		and absf(moved.y) <= Cfg.BUILD_GRID_STEP * 0.5 + 0.01)
	var quarters:= ghost.global_rotation.y / (PI * 0.5)
	_check("...and faces a world quarter (%.3f quarters)" % quarters,
		absf(quarters - roundf(quarters)) < 0.001)
	var plate: MeshInstance3D = tool.get_node_or_null("BuildGrid")
	if plate != null:
		_check("...with the grid drawn", plate.visible)


	for pair: Array in [["cabinet", "cabinet"], ["paintboard", "paint_board"]]:
		Tech.grant(pair [1], 1)
		player.equip_build(pair [0])
		for _f in 4:
			await get_tree().process_frame
		_check("the key answers on a %s" % pair [0],
			player.build_id == pair [0] and tool.snaps_to_grid())


func _case_free_pieces(tool: BuildTool) -> void:
	print("\n=== a deck squares up its own way ===")
	Tech.grant("deck", 1)
	player.equip_build("deck")
	_check("the tool comes up holding a deck", player.build_id == "deck")
	for _f in 4:
		await get_tree().process_frame
	_check("the key answers on a deck", tool.snaps_to_grid())
	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("...and pressing it switches the grid on", tool.grid_snapping())
	var plate: MeshInstance3D = tool.get_node_or_null("BuildGrid")
	if plate != null:
		_check("...and draws it", plate.visible)
	player.equip_build("deck")
	for _f in 4:
		await get_tree().process_frame
	_check("...and it is off again when the deck is picked again",
		not tool.grid_snapping())


	await _set_grid(tool, true)
	_check("switched on with a press in hand", tool.grid_snapping())
	player.equip_build("belt")
	for _f in 4:
		await get_tree().process_frame
	_check("...and off again on picking a belt", not tool.grid_snapping())
	if plate != null:
		_check("...with no drawing left on the floor", not plate.visible)

	await _set_grid(tool, true)
	player.equip_build("compressor")
	for _f in 4:
		await get_tree().process_frame
	_check("...off when the press slot is picked again", not tool.grid_snapping())

	await _set_grid(tool, true)
	player._set_tool(Player.Tool.HAND)
	for _f in 4:
		await get_tree().process_frame
	player.equip_build("compressor")
	for _f in 4:
		await get_tree().process_frame
	_check("...and off after a trip to the hand", not tool.grid_snapping())
	player._set_tool(Player.Tool.HAND)


func _set_grid(tool: BuildTool, want: bool) -> void:
	player.equip_build("compressor")
	for _f in 4:
		await get_tree().process_frame
	if tool.grid_snapping() == want:
		return
	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame


func _on_lattice(at: Vector3) -> bool:
	return absf(at.x - snappedf(at.x, Cfg.BUILD_GRID_STEP)) < 0.001 and absf(at.z - snappedf(at.z, Cfg.BUILD_GRID_STEP)) < 0.001


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
	print("[gridsnap] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
