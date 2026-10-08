class_name DevWallProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame

	GameState.add_money(50000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build


	for standing in builds.walls.duplicate():
		builds.demolish(standing)
	await get_tree().physics_frame


	var pristine:= builds.to_array()

	_rounding()
	_dressing()


	var deck:= builds.add_platform(Vector3(13.0, 0.35, -5.0), Vector2(16.0, 8.0))
	for i in 10:
		await get_tree().process_frame
		await get_tree().physics_frame
	var top:= deck.top_y()

	await _mesh_solidity()
	await _collision(builds, top)
	await _reality(builds, tool, top)
	await _snapping(builds, top)
	await _placement(builds, tool, top)
	await _persistence(builds, top)


	builds.from_array(pristine)
	await get_tree().physics_frame

	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _rounding() -> void:
	print("\n=== the far end rounds to whole bays ===")
	var from:= Vector3.ZERO


	for case: Array in [
			[0.1, 1, "a drag shorter than a bay rounds UP to one"],
			[Cfg.WALL_PANEL * 0.4, 1, "and so does most of the way to one"],
			[Cfg.WALL_PANEL * 1.4, 1, "a drag under a bay and a half rounds down"],
			[Cfg.WALL_PANEL * 1.6, 2, "and over it rounds up"],
			[5.3, 3, "an arbitrary drag takes the nearest whole bay"],
			[Cfg.WALL_MAX_LENGTH + 8.0, int(Cfg.WALL_MAX_LENGTH / Cfg.WALL_PANEL),
				"and a drag past the maximum stops at it"],
		]:
		var end:= YardWall.end_for(from, Vector3(0.0, 0.0, float(case [0])))
		_ok(str(case [2]), "%.2f" % end.z, "%.2f" % (float(case [1]) * Cfg.WALL_PANEL))


	var raked:= YardWall.end_for(Vector3(0.0, 2.0, 0.0), Vector3(6.0, 9.0, 0.0))
	_ok("the far end is pulled level with the near one", "%.2f" % raked.y, "%.2f" % 2.0)
	_ok("and the rounding is measured on the flat, not down the slope",
		"%.2f" % raked.x, "%.2f" % 6.0)


	var diag:= YardWall.end_for(Vector3.ZERO, Vector3(3.0, 0.0, 4.0))
	_ok("a diagonal run keeps its bearing", "%.3f" % (diag.x / diag.z), "%.3f" % 0.75)
	_ok("and comes out a whole number of bays long",
		"%.2f" % diag.length(), "%.2f" % (Cfg.WALL_PANEL * 3.0))


	for pulled: float in [0.1, Cfg.WALL_PANEL * 1.6, 5.3, Cfg.WALL_MAX_LENGTH + 8.0]:
		var door:= YardWall.end_for(from, Vector3(0.0, 0.0, pulled),
			YardWall.Bay.DOOR)
		_ok("a doorway dragged %.1f m is still one bay" % pulled,
			"%.2f" % door.z, "%.2f" % Cfg.WALL_PANEL)
	_ok("and keeps its bearing like any other run",
		"%.3f" % YardWall.end_for(Vector3.ZERO, Vector3(3.0, 0.0, 4.0),
			YardWall.Bay.DOOR).length(), "%.3f" % Cfg.WALL_PANEL)


func _dressing() -> void:
	print("\n=== it wears the deck's own steel ===")
	var plate:= StructureKit.plate_material()
	var beam:= StructureKit.beam_material()
	for case: Array in [
			[StructureKit.wall_panel_mesh(YardWall.Bay.SOLID), 2, "the closed bay"],
			[StructureKit.wall_panel_mesh(YardWall.Bay.WINDOW), 2, "the windowed bay"],
			[StructureKit.wall_panel_mesh(YardWall.Bay.DOOR), 2, "the door bay"],
			[StructureKit.wall_post_mesh(), 1, "the post"],
		]:
		var mesh: ArrayMesh = case [0]
		if mesh == null:
			_ok("%s imported" % case [2], false, true)
			continue
		_ok("%s has its surfaces split" % case [2], mesh.get_surface_count(), case [1])
		var painted:= true
		for i in mesh.get_surface_count():
			var m:= mesh.surface_get_material(i)


			painted = painted and (m == plate or m == beam)
		_ok("and every one of them is a StructureKit material", painted, true)


func _mesh_solidity() -> void:
	print("\n=== the drawing has no holes in it ===")
	var at:= Vector3(0.0, -500.0, 0.0)
	var bodies: Array [StaticBody3D] = []
	var names:= ["closed", "windowed", "door"]
	for bay: YardWall.Bay in [YardWall.Bay.SOLID, YardWall.Bay.WINDOW,
			YardWall.Bay.DOOR]:
		var mesh:= StructureKit.wall_panel_mesh(bay)
		if mesh == null:
			_ok("the %s bay imported" % names [int(bay)], false, true)
			return
		var body:= StaticBody3D.new()
		body.collision_layer = Cfg.L_BUILD
		body.collision_mask = 0
		var shape:= CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		body.position = at + Vector3(0.0, 0.0, float(bodies.size()) * 20.0)
		add_child(body)
		bodies.append(body)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var closed:= bodies [0].position
	var glazed:= bodies [1].position


	var out_z:= (Cfg.WALL_WINDOW_WIDTH * 0.5 + Cfg.WALL_PANEL * 0.5) * 0.5
	for z: float in [- out_z, out_z]:
		for spec: Array in [
				[Cfg.WALL_WINDOW_SILL - 0.05, "at sill level"],
				[Cfg.WALL_WINDOW_HEAD + 0.05, "at head level"],
			]:
			_ok("the bay corner %s beside the opening is plated" % spec [1],
				_solid(glazed + Vector3(0.0, float(spec [0]), z)), true)


	var mid:= Vector3(0.0,
		(Cfg.WALL_WINDOW_SILL + Cfg.WALL_WINDOW_HEAD) * 0.5, 0.0)
	_ok("and the opening itself is not", _solid(glazed + mid), false)
	_ok("while the closed bay is plated across the middle",
		_solid(closed + mid), true)

	var low:= Vector3(0.0, Cfg.WALL_WINDOW_SILL * 0.5, 0.0)
	_ok("both bays are plated below the sill",
		_solid(glazed + low) and _solid(closed + low), true)


	var doored:= bodies [2].position
	_ok("the doorway is open at ankle height",
		_solid(doored + Vector3(0.0, 0.06, 0.0)), false)
	_ok("and open at head height", _solid(doored
		+ Vector3(0.0, Cfg.WALL_DOOR_HEAD - 0.1, 0.0)), false)
	_ok("the head above it is plated", _solid(doored
		+ Vector3(0.0, (Cfg.WALL_HEIGHT + Cfg.WALL_DOOR_HEAD) * 0.5, 0.0)), true)


	var beside:= (Cfg.WALL_DOOR_WIDTH * 0.5 + Cfg.WALL_PANEL * 0.5) * 0.5
	for z: float in [- beside, beside]:
		_ok("the bay is plated beside the doorway",
			_solid(doored + Vector3(0.0, 1.0, z)), true)
		_ok("and railed under that plate",
			_solid(doored + Vector3(0.0, 0.06, z)), true)

	for body in bodies:
		remove_child(body)
		body.queue_free()
	await get_tree().physics_frame


func _solid(at: Vector3) -> bool:
	var query:= PhysicsRayQueryParameters3D.create(
		at - Vector3(1.0, 0.0, 0.0), at + Vector3(1.0, 0.0, 0.0))
	query.collision_mask = Cfg.L_BUILD
	query.collide_with_areas = false
	return not get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty()


func _snapping(builds: BuildManager, top: float) -> void:
	print("\n=== a run joins another at a post ===")
	var a:= Vector3(11.0, top, -4.0)
	var b:= a + Vector3(0.0, 0.0, Cfg.WALL_PANEL * 3.0)
	var wall:= builds.add_wall(a, b, YardWall.Bay.SOLID)
	await get_tree().physics_frame

	_ok("a three-bay run offers four posts", wall.post_points().size(), 4)
	_ok("the first is the run's near end",
		"%.2f" % wall.post_points() [0].distance_to(a), "%.2f" % 0.0)
	_ok("and the last its far end",
		"%.2f" % wall.post_points() [3].distance_to(b), "%.2f" % 0.0)


	var low:= Vector3(a.x + 0.2, a.y + 0.4, a.z + Cfg.WALL_PANEL * 0.9)
	var snapped: Vector3 = builds.snap_wall_point(low)
	_ok("a point low on a wall joins at the base of a column",
		"%.2f" % snapped.y, "%.2f" % a.y)
	_ok("and at the joint it was nearest, not at the end of the run",
		"%.2f" % snapped.z, "%.2f" % (a.z + Cfg.WALL_PANEL))


	var near_mid:= Vector3(a.x + 0.5, a.y + 1.0, a.z + Cfg.WALL_PANEL * 2.0 + 0.3)
	_ok("a mid-run joint takes a point aimed near it",
		"%.2f" % builds.snap_wall_point(near_mid).distance_to(
			a + Vector3(0.0, 0.0, Cfg.WALL_PANEL * 2.0)), "%.2f" % 0.0)

	var clear:= Vector3(a.x + 6.0, a.y, a.z)
	_ok("a point clear of every wall is not dragged onto one",
		builds.nearest_wall_post(clear) == null, true)


	var below:= Vector3(a.x, a.y - 4.0, a.z)
	_ok("nor is a run on the floor captured by a wall on the deck overhead",
		builds.nearest_wall_post(below) == null, true)


	var tool: BuildTool = player.build
	tool._mode = BuildTool.Mode.WALL
	tool._state = BuildTool.State.AIMING
	tool._anchor = builds.snap_wall_point(b + Vector3(0.3, 0.5, -0.2))
	_ok("so a new run anchors exactly on the old run's end post",
		"%.2f" % tool._anchor.distance_to(b), "%.2f" % 0.0)
	tool._state = BuildTool.State.RUNNING
	var corner:= builds.add_wall(tool._anchor,
		tool._anchor + Vector3(Cfg.WALL_PANEL * 2.0, 0.0, 0.0), YardWall.Bay.WINDOW)
	await get_tree().physics_frame
	_ok("and the two runs share a column",
		"%.2f" % corner.post_points() [0].distance_to(wall.post_points() [3]),
		"%.2f" % 0.0)
	tool._state = BuildTool.State.AIMING
	builds.demolish(corner)
	await get_tree().physics_frame
	await _stacking(builds, wall)
	builds.demolish(wall)
	await get_tree().physics_frame


func _stacking(builds: BuildManager, lower: YardWall) -> void:
	print("\n=== and a second course goes on top of the first ===")
	var a:= lower.a


	var on_top:= Vector3(a.x, a.y + Cfg.WALL_HEIGHT,
		a.z + Cfg.WALL_PANEL * 0.9)
	var snapped: Vector3 = builds.snap_wall_point(on_top)
	_ok("a point on TOP of a wall stays up there",
		"%.2f" % snapped.y, "%.2f" % (a.y + Cfg.WALL_COURSE))
	_ok("and lands on a column rather than between two",
		"%.2f" % snapped.z, "%.2f" % (a.z + Cfg.WALL_PANEL))


	_ok("the boundary between the two courses is the middle of the face",
		"%.2f" % builds.snap_wall_point(Vector3(a.x, a.y + Cfg.WALL_HEIGHT * 0.5,
			a.z + Cfg.WALL_PANEL)).y, "%.2f" % a.y)
	_ok("...and just above it is the upper one",
		"%.2f" % builds.snap_wall_point(Vector3(a.x, a.y + Cfg.WALL_HEIGHT * 0.6,
			a.z + Cfg.WALL_PANEL)).y, "%.2f" % (a.y + Cfg.WALL_COURSE))


	var up_a:= Vector3(a.x, a.y + Cfg.WALL_COURSE, a.z)
	var up_b:= Vector3(lower.b.x, up_a.y, lower.b.z)
	_ok("a course laid on top of a wall has something under it",
		builds.wall_unsupported(up_a, up_b), false)
	_ok("and is not refused as already walled",
		builds.wall_overlap(up_a, up_b), false)

	var upper:= builds.add_wall(up_a, up_b, YardWall.Bay.WINDOW)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("so the second course stands, exactly one course up",
		"%.3f" % (upper.a.y - lower.a.y), "%.3f" % Cfg.WALL_COURSE)
	_ok("with its bays over the bays below, column for column",
		"%.3f" % Vector2(upper.post_points() [1].x - lower.post_points() [1].x,
			upper.post_points() [1].z - lower.post_points() [1].z).length(),
		"%.3f" % 0.0)

	var high:= Vector3(a.x, a.y + Cfg.WALL_COURSE + Cfg.WALL_WINDOW_SILL * 0.5,
		a.z + Cfg.WALL_PANEL * 1.5)
	_ok("the upper course is solid at its own knee height", _blocked(high), true)


	_ok("and the joint between the courses is solid, not a gap",
		_blocked(Vector3(a.x, a.y + Cfg.WALL_COURSE, a.z + Cfg.WALL_PANEL * 1.5)),
		true)
	builds.demolish(upper)
	await get_tree().physics_frame


func _collision(builds: BuildManager, top: float) -> void:
	print("\n=== the opening is open and the wall is not ===")
	var a:= Vector3(8.0, top, -5.0)
	var b:= a + Vector3(Cfg.WALL_PANEL * 3.0, 0.0, 0.0)
	var solid:= builds.add_wall(a, b, YardWall.Bay.SOLID)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_ok("a three-bay run stands three bays of panel",
		solid.get_node("Bays").multimesh.instance_count, 3)
	_ok("and a post at each joint and each end",
		solid.get_node("Posts").multimesh.instance_count, 4)


	var eye:= Vector3(a.x + Cfg.WALL_PANEL * 1.5, top + Cfg.WALL_WINDOW_SILL
		+ (Cfg.WALL_WINDOW_HEAD - Cfg.WALL_WINDOW_SILL) * 0.5, a.z)
	_ok("a closed bay is solid at window height", _blocked(eye), true)
	_ok("and solid at knee height", _blocked(eye - Vector3(0.0, 1.0, 0.0)), true)
	builds.demolish(solid)
	await get_tree().physics_frame

	var glazed:= builds.add_wall(a, b, YardWall.Bay.WINDOW)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("a windowed run stands the same three bays",
		glazed.get_node("Bays").multimesh.instance_count, 3)


	_ok("the opening is OPEN at the centre of a bay", _blocked(eye), false)


	var sill:= Vector3(eye.x, top + Cfg.WALL_WINDOW_SILL * 0.5, eye.z)
	var head:= Vector3(eye.x, top + (Cfg.WALL_HEIGHT + Cfg.WALL_WINDOW_HEAD)
		* 0.5, eye.z)
	var jamb:= Vector3(a.x + Cfg.WALL_PANEL, eye.y, eye.z)
	_ok("but the sill below it is solid", _blocked(sill), true)
	_ok("the head above it is solid", _blocked(head), true)
	_ok("and the jamb between two bays is solid", _blocked(jamb), true)


	var reveal:= (Cfg.WALL_PANEL - Cfg.WALL_WINDOW_WIDTH) * 0.25
	_ok("the end of the run is closed at window height",
		_blocked(Vector3(a.x + reveal, eye.y, eye.z)), true)
	builds.demolish(glazed)
	await get_tree().physics_frame


	var doorway:= builds.add_wall(a, a + Vector3(Cfg.WALL_PANEL, 0.0, 0.0),
		YardWall.Bay.DOOR)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("a doorway stands a single bay",
		doorway.get_node("Bays").multimesh.instance_count, 1)
	var through:= Vector3(a.x + Cfg.WALL_PANEL * 0.5, 0.0, a.z)
	_ok("the doorway is open at eye height",
		_blocked(through + Vector3(0.0, top + 1.6, 0.0)), false)

	_ok("and open at ankle height",
		_blocked(through + Vector3(0.0, top + 0.06, 0.0)), false)
	_ok("the head above it is solid", _blocked(through + Vector3(0.0,
		top + (Cfg.WALL_HEIGHT + Cfg.WALL_DOOR_HEAD) * 0.5, 0.0)), true)
	var door_reveal:= (Cfg.WALL_PANEL - Cfg.WALL_DOOR_WIDTH) * 0.25
	_ok("and the jamb beside it is solid at ankle height",
		_blocked(Vector3(a.x + door_reveal, top + 0.06, a.z)), true)
	builds.demolish(doorway)
	await get_tree().physics_frame


func _blocked(at: Vector3) -> bool:
	var query:= PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = Cfg.L_BUILD
	query.collide_with_areas = false
	return not get_viewport().world_3d.direct_space_state.intersect_point(query, 1).is_empty()


func _reality(builds: BuildManager, tool: BuildTool, top: float) -> void:
	print("\n=== a wall that is drawn is a wall that stops things ===")
	var a:= Vector3(9.0, top, -7.0)
	var b:= a + Vector3(Cfg.WALL_PANEL * 2.0, 0.0, 0.0)
	builds.add_wall(a, b, YardWall.Bay.SOLID)
	await get_tree().physics_frame
	await get_tree().physics_frame


	var column: Vector3 = builds.snap_wall_point(Vector3(a.x + Cfg.WALL_PANEL,
		top + Cfg.WALL_HEIGHT, a.z))
	_ok("aiming at the top of a column offers a course up there",
		"%.2f" % column.y, "%.2f" % (top + Cfg.WALL_COURSE))
	_ok("and half a bay to one side of it comes back the same point",
		"%.2f" % builds.snap_wall_point(column
			+ Vector3(0.0, 0.0, Cfg.WALL_PANEL * 0.5)).distance_to(column),
		"%.2f" % 0.0)


	var twice:= tool._evaluate_wall(column, column, true)
	_ok("a second click on the column the first one anchored to is refused",
		twice ["ok"], false)
	_ok("and says why", str(twice ["reason"]), "no length")


	tool.set_active(true)
	tool._mode = BuildTool.Mode.WALL
	tool._anchor = column
	tool._state = BuildTool.State.RUNNING
	tool._eval = twice
	var standing:= builds.walls.size()
	tool._wall_primary()
	_ok("so the click builds nothing", builds.walls.size(), standing)
	tool._state = BuildTool.State.AIMING
	tool.set_active(false)


	_ok("and a run with no length is refused by the manager as well",
		builds.add_wall(column, column, YardWall.Bay.SOLID) == null, true)
	_ok("leaving the yard as it was", builds.walls.size(), standing)


	var degenerate:= YardWall.new()
	degenerate.name = "Degenerate"
	degenerate.setup(column, column, YardWall.Bay.SOLID)
	builds.add_child(degenerate)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("a run with no length draws no bays",
		degenerate.get_node("Bays").multimesh.instance_count, 0)
	_ok("so there is nothing standing there to walk through",
		_blocked(column + Vector3(0.0, Cfg.WALL_HEIGHT * 0.5,
			Cfg.WALL_PANEL * 0.5)), false)
	degenerate.queue_free()
	await get_tree().physics_frame


	var poisoned: Array = builds.to_array()
	poisoned.append({ "type": "wall", "a": column, "b": column, "kind": 0 })
	builds.from_array(poisoned)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("a run with no length in a save is dropped rather than stood up",
		builds.walls.size(), standing)


	_ok("every wall standing has a barrier on the build layer",
		_barrierless(builds), [])


	_ok("a body fired at a wall does not come out the far side",
		await _stopped_by(builds.walls [0]), true)


	var standing_wall: YardWall = builds.walls [0]
	var middle:= (standing_wall.a + standing_wall.b) * 0.5
	_ok("the run refuses another laid along it",
		builds.wall_overlap(standing_wall.a, standing_wall.b), true)
	_ok("and stops a body standing in the same place",
		_blocked(middle + Vector3(0.0, Cfg.WALL_HEIGHT * 0.5, 0.0)), true)


	for doomed in builds.walls.duplicate():
		builds.demolish(doomed)
	await get_tree().physics_frame
	_ok("the probe leaves no walls behind", builds.walls.size(), 0)


func _barrierless(builds: BuildManager) -> Array [String]:
	var out: Array [String] = []
	for wall: YardWall in builds.walls:
		if not is_instance_valid(wall):
			continue
		if (wall.collision_layer & Cfg.L_BUILD) == 0:
			out.append("%s is on layer %d" % [wall.name, wall.collision_layer])
			continue
		var shapes:= 0
		for child in wall.get_children():
			var shape:= child as CollisionShape3D
			if shape != null and shape.shape != null and not shape.disabled:
				shapes += 1
		if shapes == 0:
			out.append("%s has no collision shape" % wall.name)
	return out


func _stopped_by(wall: YardWall) -> bool:
	var mid:= (wall.a + wall.b) * 0.5 + Vector3(0.0, Cfg.WALL_HEIGHT * 0.5, 0.0)
	var across:= Vector3(wall.b - wall.a).normalized().cross(Vector3.UP)
	var body:= RigidBody3D.new()
	body.gravity_scale = 0.0
	body.collision_layer = Cfg.L_PROP
	body.collision_mask = Cfg.L_BUILD


	body.continuous_cd = true
	var shape:= CollisionShape3D.new()
	var ball:= SphereShape3D.new()
	ball.radius = 0.15
	shape.shape = ball
	body.add_child(shape)
	wall.get_parent().add_child(body)
	body.global_position = mid + across * 1.5
	body.linear_velocity = - across * 8.0
	for i in 30:
		await get_tree().physics_frame
	var side:= (body.global_position - mid).dot(across)
	body.queue_free()
	await get_tree().physics_frame
	return side > 0.0


func _placement(builds: BuildManager, tool: BuildTool, top: float) -> void:
	print("\n=== placed with the tool, not by hand ===")


	tool.set_active(true)
	tool._reach = 20.0
	tool._mode = BuildTool.Mode.WALL
	player.global_position = Vector3(7.0, top + 0.1, -5.0)
	for i in 4:
		await get_tree().process_frame

	_aim(Vector3(9.0, top, -5.0))
	tool._update_wall_ghost()
	_ok("pointing at a deck is a valid first click", tool._eval ["ok"], true)
	_ok("and the hologram is a single post, not a bay",
		tool._wall_ghost.get_node("Bays").multimesh.instance_count, 0)

	tool._wall_primary()
	_ok("the first click starts a run instead of building",
		tool._state == BuildTool.State.RUNNING, true)
	_ok("and builds nothing yet", builds.walls.size(), 0)
	var anchor: Vector3 = tool._anchor


	_aim(Vector3(anchor.x + 5.3, top, -5.0))
	tool._update_wall_ghost()
	var quoted: float = tool._eval ["cost"]
	var drawn: float = tool._wall_ghost.length
	_ok("the ghost rounds the drag to whole bays",
		"%.2f" % drawn, "%.2f" % (Cfg.WALL_PANEL * 3.0))
	_ok("and is priced at the rounded length, not the dragged one",
		"%.2f" % quoted,
		"%.2f" % (drawn * Cfg.WALL_COST_PER_M * Tech.build_cost_scale()))


	var hud: Hud = world.hud
	hud._update_build_readout()
	_ok("the readout counts the run in bays", hud._build.text.contains("3 bays"), true)
	_ok("the price has its own row under it", hud._price.visible
		and hud._price.text.begins_with("$") and not hud._build.text.contains("$"), true)

	var before:= GameState.money
	tool._wall_primary()
	_ok("the second click builds the wall", builds.walls.size(), 1)
	var wall: YardWall = builds.walls [0]
	_ok("of the length that was quoted", "%.2f" % wall.length, "%.2f" % drawn)
	_ok("and charges what was quoted",
		"%.2f" % (before - GameState.money), "%.2f" % quoted)
	_ok("a solid run is built solid", wall.kind, YardWall.Bay.SOLID)


	_ok("the tool chains from the end of the run it just built",
		"%.2f" % tool._anchor.distance_to(wall.b), "%.2f" % 0.0)
	_ok("and stays in a run rather than dropping the chain",
		tool._state == BuildTool.State.RUNNING, true)


	tool._anchor = wall.a
	_aim(wall.b + (wall.b - wall.a).normalized() * 0.2)
	tool._update_wall_ghost()
	_ok("a run laid on top of one already standing is refused",
		tool._eval ["ok"], false)
	_ok("and says why", str(tool._eval ["reason"]), "already walled")


	tool._anchor = Vector3(60.0, top + 6.0, -60.0)
	_aim(Vector3(66.0, top + 6.0, -60.0))
	tool._update_wall_ghost()
	_ok("a run over open air is refused", tool._eval ["ok"], false)
	_ok("and says why", str(tool._eval ["reason"]), "nothing under it")


	tool._mode = BuildTool.Mode.WALL_WINDOW
	tool._state = BuildTool.State.AIMING
	_aim(Vector3(15.0, top, -3.0))
	tool._update_wall_ghost()
	tool._wall_primary()
	_aim(Vector3(19.0, top, -3.0))
	tool._update_wall_ghost()
	tool._wall_primary()
	_ok("the window mode builds through the same two clicks",
		builds.walls.size(), 2)
	_ok("and builds a windowed run", builds.walls [1].kind, YardWall.Bay.WINDOW)


	tool._mode = BuildTool.Mode.WALL_DOOR
	tool._state = BuildTool.State.AIMING
	_aim(Vector3(9.0, top, -3.0))
	tool._update_wall_ghost()
	tool._wall_primary()
	_aim(Vector3(13.0, top, -3.0))
	tool._update_wall_ghost()
	_ok("a doorway dragged four metres is drawn one bay long",
		"%.2f" % tool._wall_ghost.length, "%.2f" % Cfg.WALL_PANEL)
	_ok("and priced as one bay, not as the drag",
		"%.2f" % float(tool._eval ["cost"]),
		"%.2f" % (Cfg.WALL_PANEL * Cfg.WALL_COST_PER_M * Tech.build_cost_scale()))
	tool._wall_primary()
	_ok("the third run is the doorway", builds.walls.size(), 3)
	_ok("built as a door bay", builds.walls [2].kind, YardWall.Bay.DOOR)
	_ok("one bay wide", builds.walls [2].bays, 1)
	_ok("and standing where it was quoted",
		"%.2f" % builds.walls [2].length, "%.2f" % Cfg.WALL_PANEL)
	tool._state = BuildTool.State.AIMING
	tool.set_active(false)


func _persistence(builds: BuildManager, top: float) -> void:
	print("\n=== it survives a save ===")
	var saved:= builds.to_array()
	var walls_saved:= 0
	for entry: Dictionary in saved:
		if str(entry.get("type", "")) == "wall":
			walls_saved += 1
	_ok("all three runs are written out", walls_saved, 3)

	var was: Array [Dictionary] = []
	for wall: YardWall in builds.walls:
		was.append({ "a": wall.a, "b": wall.b, "kind": wall.kind })
	builds.from_array(saved)
	await get_tree().physics_frame
	_ok("and all three come back", builds.walls.size(), 3)
	var same:= builds.walls.size() == was.size()
	for i in builds.walls.size():
		if i >= was.size():
			break
		var wall: YardWall = builds.walls [i]
		same = same and wall.a.is_equal_approx(was [i] ["a"]) and wall.b.is_equal_approx(was [i] ["b"]) and wall.kind == int(was [i] ["kind"])
	_ok("standing where they stood, and each the bay it was", same, true)


	var legacy: Array = [{ "type": "wall", "a": builds.walls [0].a,
		"b": builds.walls [0].b, "windowed": true }]
	builds.from_array(legacy)
	await get_tree().physics_frame
	_ok("a save written before the doorway loads its window", builds.walls.size(), 1)
	_ok("as a windowed run and not a solid one",
		builds.walls [0].kind, YardWall.Bay.WINDOW)
	builds.from_array(saved)
	await get_tree().physics_frame


	var wall_back: YardWall = builds.walls [0]
	var cost:= wall_back.length * Cfg.WALL_COST_PER_M * Tech.build_cost_scale()
	_ok("a demolished run refunds what it cost",
		"%.2f" % wall_back.build_cost(), "%.2f" % cost)


	var refunded:= builds.demolish(wall_back)
	await get_tree().physics_frame
	_ok("and the yard is one run lighter", builds.walls.size(), 2)
	_ok("with the money handed back", "%.2f" % refunded, "%.2f" % cost)


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _ok(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok   %s" % label)
		return
	_fails += 1
	print("  FAIL %s -> %s (wanted %s)" % [label, got, want])
