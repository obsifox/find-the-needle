class_name DevEnclosedBeltProbe
extends Node


var world: Node3D
var failures: Array [String] = []


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)


func run() -> void:


	BeltRunBatch.draw_headless = true
	var builds: BuildManager = world.builds
	var y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(-12.0, y, -10.0)
	var b:= Vector3(-12.0, y, -5.0)
	var c:= Vector3(-7.0, y, -5.0)
	var line:= builds.new_line_id()
	var first:= builds.add_enclosed_conveyor(a, b, line)
	var second:= builds.add_enclosed_conveyor(b, c, line)

	check(first.record_only and second.record_only,
		"Enclosed runs accept recordable cargo only")
	check(first.run.event_sink == null and second.run.event_sink == null,
		"Enclosed cargo has no renderer")
	var sections:= first.get_node_or_null("Path/Sections") as GeometryInstance3D
	check(sections != null and not sections.visible,
		"The ordinary open belt drawing is hidden")
	check(builds.corners.size() == 1 and builds.corners [0] is EnclosedConveyorCorner,
		"Connected enclosed runs use a hidden transport bend")

	var shell: Node3D = builds._enclosed_visuals
	check(shell != null, "The enclosed shell exists")
	if shell != null:
		check(shell.find_children("Terminal", "MeshInstance3D", true, false).size() == 2,
			"Only the two exposed ends are open mouths")
		check(shell.find_children("*", "AnimationPlayer", true, false).is_empty()
			and shell.find_children("Leaf", "MeshInstance3D", true, false).is_empty(),
			"No door leaf and nothing animating on the shell")
		check(shell.find_children("BlackVoid_*", "MeshInstance3D", true, false).size() == 2,
			"Both exposed ends have black interiors")
		check(shell.find_children("Bend_*", "MeshInstance3D", true, false).size() == 1,
			"The connected line has one enclosed bend")

	var all_saved:= builds.to_array()
	var saved:= all_saved.filter(func(d: Dictionary) -> bool:
		return d.get("type", "") == "enclosed_conveyor")
	check(saved.size() == 2, "Both enclosed runs save with their own type")
	check(builds.id_of(first) == "enclosed_belt", "Copy identifies the enclosed catalogue entry")
	check(BuildCatalog.unlock_of("enclosed_belt") == "enclosed_belt",
		"The enclosed conveyor has its own catalogue unlock")
	check(TechTree.has_id("enclosed_belt")
		and TechTree.requires("enclosed_belt") == ["belt"],
		"The enclosed conveyor has its own node after Conveyor Plans")
	check(TechTree.icon_of("enclosed_belt") == "enclosed_belt",
		"The enclosed conveyor tech node uses its own icon")
	check(CatalogPanel.icon_for("enclosed_belt") != null,
		"The enclosed conveyor has a build menu icon")
	check(TechPanel.icon_for("enclosed_belt") != null,
		"The enclosed conveyor has a tech tree icon")
	check(is_equal_approx(first.build_cost(), a.distance_to(b)
		* Cfg.ENCLOSED_BELT_COST_PER_M * Tech.build_cost_scale()),
		"The placed and refunded prices agree")

	var boarded:= first.run.board(BeltRun.Kind.ROLL, 100, -1, 0.32, 0.0, 0.28)
	check(boarded, "A paper roll boards as a record")
	check(first.run.event_sink == null, "Boarding cargo does not attach a renderer")
	if shell != null:
		check(shell.get_node_or_null("Intake_0") != null
			and shell.get_node_or_null("Outlet_0") != null,
			"Both exposed ends are ports on the shell")


	check(first.loose_mouth == EnclosedConveyor.MOUTH and first.loose_tail < 0.0
		and second.loose_mouth < 0.0 and second.loose_tail == EnclosedConveyor.MOUTH,
		"Only the line's two exposed ends take loose hay")
	var roof:= first.get_node_or_null("ShellRoof") as StaticBody3D
	check(roof != null and not (roof.get_child(0) as CollisionShape3D).disabled,
		"The casing is solid")
	var middle:= (a + b) * 0.5
	check(builds.conveyor_drops(middle + Vector3.UP, 3.0).is_empty(),
		"An arm finds no drop point on an enclosed run")
	var held:= world.props.spawn("hay_wad", Transform3D(Basis(), middle + Vector3.UP * 0.3),
		{ "strands": 20 }) as Carryable
	check(held != null and first.board_body(held, middle) < 0,
		"A claw or a hand cannot board a load onto the casing")
	var aboard:= first.run.count()
	if held != null:
		held.global_position = middle + Vector3.UP * 2.0
		held.linear_velocity = Vector3.ZERO
		for i in 120:
			await get_tree().physics_frame
		check(first.run.count() == aboard and is_instance_valid(held),
			"A wad dropped on the casing does not board")
		check(is_instance_valid(held) and held.global_position.y > y + 0.6,
			"A wad dropped on the casing rests on its roof")
		if is_instance_valid(held):
			held.queue_free()


	await get_tree().physics_frame
	var ahead:= (b - a).normalized()
	var across:= ahead.cross(Vector3.UP).normalized()
	var mouth:= a + ahead * 0.3
	check(_shell_at(mouth + Vector3.UP * 0.3) == "",
		"The intake mouth is open where the loads go in")
	check(_shell_at(mouth + across * 0.44 + Vector3.UP * 0.3) == "ShellRoof"
		and _shell_at(mouth - across * 0.44 + Vector3.UP * 0.3) == "ShellRoof",
		"...between two solid side walls")
	check(_shell_at(mouth + Vector3.UP * 0.66) == "ShellRoof",
		"...under a solid roof")
	var tail:= c - (c - b).normalized() * 0.3
	check(_shell_at(tail + Vector3.UP * 0.3) == ""
		and _shell_at(tail + Vector3.UP * 0.66) == "ShellRoof",
		"The outlet mouth is a collar the same way")
	var bend:= builds.corners [0] if not builds.corners.is_empty() else null
	if bend != null:
		var middle_of_bend:= ConveyorCorner.arc_points(
			ConveyorCorner.arc_of(bend.from_point, bend.apex, bend.to_point),
			bend.from_point, bend.to_point, 2) [1]
		var outward:= bend.apex - middle_of_bend
		outward = Vector3(outward.x, 0.0, outward.z).normalized()
		check(_shell_at(middle_of_bend + Vector3.UP * 0.3) == "ShellBend",
			"The bend's casing is solid")
		check(_shell_at(middle_of_bend + outward * 0.45 + Vector3.UP * 0.3) == "ShellBend"
			and _shell_at(middle_of_bend - outward * 0.45 + Vector3.UP * 0.3) == "ShellBend",
			"...out to both sides of the turn")
	check(await _rests_on(mouth), "A wad dropped on the intake mouth rests on its roof")
	if bend != null:
		check(await _rests_on(ConveyorCorner.arc_points(
			ConveyorCorner.arc_of(bend.from_point, bend.apex, bend.to_point),
			bend.from_point, bend.to_point, 2) [1]),
			"A wad dropped on the bend rests on its roof")


	var needle: RigidBody3D = world.live.reveal_needle(
		-1, a.lerp(b, 0.05) + Vector3.UP * 0.06)
	check(needle != null, "The probe's needle exists")
	if needle != null:


		var bucket: Carryable = world.props.spawn("bucket",
			Transform3D(Basis(), a.lerp(b, 0.05) + Vector3.UP * 0.4))
		check(bucket != null and not first.accepts_handover(Cfg.BELT_RIDE_SPACING,
			NAN, Cfg.STRAND_THICK, null, bucket),
			"A sealed run still turns away a load that cannot be a record")
		check(first.accepts_handover(Cfg.BELT_RIDE_SPACING, NAN,
			Cfg.STRAND_THICK, null, needle),
			"...and takes a needle, which has no record kind either")
		if bucket != null:
			world.props.remove(bucket)
		var boarded_needle:= false
		var crossed:= false
		for i in 900:
			await get_tree().physics_frame
			if not is_instance_valid(needle):
				break
			if first.holds(needle):
				boarded_needle = true
			if second.holds(needle):
				crossed = true
				break
		check(boarded_needle, "A needle boards the sealed run at its intake mouth")
		check(crossed, "...and rides it on through the bend into the run beyond")
		check(is_instance_valid(needle) and needle.global_position.y > y - 0.2,
			"...rather than being tipped on the floor at the intake")
		if is_instance_valid(needle):
			BeltPath.release(needle)
			needle.queue_free()
			await get_tree().physics_frame


	await _aim_at((a + b) * 0.5 + Vector3(3.0, 0.0, 0.0), (a + b) * 0.5 + Vector3.UP * 0.4)
	var tool: BuildTool = world.player.build
	var lit:= tool.enclosed_hint_runs()
	check(lit.has(first) and lit.has(second),
		"Looking at the casing lights the whole enclosed line")
	var hint:= tool.get_node_or_null("EnclosedHint") as MultiMeshInstance3D
	check(hint != null and hint.visible and hint.multimesh.visible_instance_count > 0,
		"...and the chevrons are drawn over it")


	await _aim_at((a + b) * 0.5 + Vector3(3.0, 0.0, 0.0), (a + b) * 0.5 + Vector3.UP * 40.0)
	check(tool.enclosed_hint_runs().is_empty(),
		"Looking away takes the direction hint off the line")


	var d:= Vector3(-2.0, y, -5.0)
	var other:= builds.add_enclosed_conveyor(c, d, builds.new_line_id())
	check(builds.reverse_conveyor(other), "The joined run reverses")
	check(builds._enclosed_visuals != null
		and builds._enclosed_visuals.find_children(
			"Terminal", "MeshInstance3D", true, false).size() == 4,
		"A run reversed head to head keeps every shell, with a mouth at each end")
	check(other.loose_tail == EnclosedConveyor.MOUTH and second.loose_tail == EnclosedConveyor.MOUTH,
		"Both runs meeting head to head get an outlet mouth")
	builds.demolish(other)
	all_saved = builds.to_array()

	builds.clear()
	await builds.from_array(all_saved)
	var restored:= builds.conveyors.filter(func(belt: Conveyor) -> bool:
		return belt is EnclosedConveyor)
	check(restored.size() == 2, "Both enclosed runs restore with their own class")
	check(builds._enclosed_visuals != null
		and builds._enclosed_visuals.find_children(
			"Terminal", "MeshInstance3D", true, false).size() == 2,
		"The connected shell and its two mouths rebuild after load")

	print("ENCLOSED BELT: ", "PASS" if failures.is_empty() else "FAIL",
		"; hidden cargo, two open mouths, one bend, direction hint, save restore")
	get_tree().quit(0 if failures.is_empty() else 1)


func _shell_at(point: Vector3) -> String:
	var query:= PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = Cfg.L_BUILD
	query.collide_with_areas = false
	for hit in world.get_world_3d().direct_space_state.intersect_point(query, 16):
		var body:= hit ["collider"] as Node
		if body != null and String(body.name).begins_with("Shell"):
			return String(body.name)
	return ""


func _rests_on(at: Vector3) -> bool:
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at + Vector3.UP * 2.0),
		{ "strands": 20 }) as Carryable
	if wad == null:
		return false
	for i in 120:
		await get_tree().physics_frame
	var resting:= is_instance_valid(wad) and wad.global_position.y > at.y + 0.6
	if is_instance_valid(wad):
		wad.queue_free()
	return resting


func _aim_at(from: Vector3, target: Vector3) -> void:
	var player: Player = world.player
	player.global_position = Vector3(from.x, player.global_position.y, from.z)
	await get_tree().physics_frame
	var eye:= player.camera.global_position
	var flat:= Vector2(target.x - eye.x, target.z - eye.z).length()
	player.set_look(atan2(target.x - eye.x, target.z - eye.z) + PI,
		atan2(target.y - eye.y, maxf(flat, 0.001)))
	for i in 12:
		await get_tree().process_frame
