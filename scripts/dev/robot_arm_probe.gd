class_name DevRobotArmProbe
extends Node


var world: Node3D


func run() -> void:
	call_deferred("_run")


func _run() -> void:

	reparent(get_tree().root)
	var packed:= load("res://robotic_arm_game_ready.glb") as PackedScene
	if packed == null:
		_fail("robot arm GLB did not import as a PackedScene")
		return
	var imported: Node = packed.instantiate()
	for required in ["RA_BaseYaw", "RA_ShoulderPitch", "RA_ElbowPitch",
			"RA_ToolLevel", "SOCKET_HayGrip", "RA_ClawPivot_4"]:
		if imported.find_child(required, true, false) == null:
			imported.free()
			_fail("import is missing %s" % required)
			return
	var triangles:= 0
	for mesh: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null:
			triangles += mesh.mesh.get_faces().size() / 3
	print("[robot-arm-probe] imported triangles=%d" % triangles)
	if triangles <= 0 or triangles > 110000:
		imported.free()
		_fail("arm export is empty or exceeds its 110000 triangle budget")
		return
	imported.free()

	var base: Vector3 = Vector3(11.8, 0.06, 4.0)
	world.builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm: RoboticArm = world.builds.add_robotic_arm(base, 0.0, 1)
	var near_small_conflict: bool = world.builds.arm_reach_conflict(
		base + Vector3(3.0, 0.0, 0.0), 0)
	var near_long_conflict: bool = world.builds.arm_reach_conflict(
		base + Vector3(4.0, 0.0, 0.0), 2)
	var far_long_clear: bool = not world.builds.arm_reach_conflict(
		base + Vector3(4.6, 0.0, 0.0), 2)
	var small_tier: Dictionary = Cfg.ROBOT_ARM_TIERS [0]


	GameState.add_money(20000.0)
	var placement_eval: Dictionary = world.player.build._evaluate_arm(
		base + Vector3(3.0, 0.0, 0.0), Vector3.UP,
		float(small_tier ["cost"]), float(small_tier ["scale"]))
	var ghost_denied: bool = not bool(placement_eval ["ok"]) and placement_eval ["reason"] == "another arm in reach"
	print("[robot-arm-probe] placement near_small=%s near_long=%s far_long_clear=%s ghost_denied=%s"
		% [near_small_conflict, near_long_conflict, far_long_clear, ghost_denied])
	if not near_small_conflict or not near_long_conflict or not far_long_clear or not ghost_denied:
		_fail("arm reach exclusion rule failed")
		return
	var camera:= Camera3D.new()
	camera.fov = 58.0
	world.add_child(camera)
	camera.look_at_from_position(base + Vector3(4.1, 2.8, 3.7),
		base + Vector3(0.0, 1.25, 0.0), Vector3.UP)
	camera.current = true


	var material_names:= { }
	var overridden:= 0
	var mismatched: Array [String] = []
	var flats: Dictionary = RoboticArm.spec_table().get("flats", { })
	for mesh in arm._mesh_children(arm._model):
		for surface in mesh.mesh.get_surface_count():
			var material:= mesh.mesh.surface_get_material(surface)
			var slot:= material.resource_name if material != null else "<null>"
			material_names [slot] = true
			var override:= mesh.get_surface_override_material(surface) as StandardMaterial3D
			if override == null:
				continue
			overridden += 1


			if slot == "RA_ReachWire" or not flats.has(slot):
				continue
			var want: Color = RoboticArm._col(flats [slot].get("color", []))
			var got: Color = override.albedo_color
			if absf(got.r - want.r) > 0.002 or absf(got.g - want.g) > 0.002 or absf(got.b - want.b) > 0.002:
				mismatched.append(slot)
	print("[robot-arm-probe] materials=%s overridden=%d table=%d mismatched=%s"
		% [str(material_names.keys()), overridden, flats.size(), str(mismatched)])
	print("[robot-arm-probe] field_pick=%s" % str(arm._find_field_pickup(
		arm.global_position + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * arm.visual_scale())))
	var saved_buildings: Array = world.builds.to_array()
	if saved_buildings.filter(func(entry: Dictionary) -> bool:
		return entry.get("type", "") == "robotic_arm").size() != 1:
		_fail("robot arm was not serialized by BuildManager")
		return
	await get_tree().create_timer(0.8).timeout
	var approached_open:= is_equal_approx(arm._claw_angle, RoboticArm.CLAW_OPEN)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://captures/robot_arm_ingame_palette.png")
	await get_tree().create_timer(1.2).timeout
	var transfer_closed:= is_equal_approx(arm._claw_angle, RoboticArm.CLAW_CLOSED)
	await get_tree().create_timer(4.5).timeout
	print("[robot-arm-probe] open_approach=%s closed_transfer=%s cycles=%d payload=%d field_source=%s"
		% [approached_open, transfer_closed, arm.completed_cycles,
			arm.last_payload_count, arm.last_cycle_from_field])
	if not approached_open or not transfer_closed or arm.completed_cycles < 1 or arm.last_payload_count < 1 or not arm.last_cycle_from_field or overridden < 1 or flats.is_empty() or not mismatched.is_empty():
		_fail("pick-and-place cycle did not complete")
		return


	var held: Array = []
	for tick in 1200:
		if arm._phase == RoboticArm.Phase.LIFT and not arm._payload.is_empty():
			held = arm._payload.duplicate()
			break
		await get_tree().physics_frame
	if held.is_empty():
		_fail("no straw payload available for the demolition check")
		return
	var held_pose:= Transform3D(arm._payload_pose.basis.orthonormalized(), arm._payload_pose.origin)
	var harvest_point:= arm._pickup_source
	if arm._payload_visual == null or arm._payload_visual.multimesh.instance_count != held.size():
		_fail("claw batch did not contain the complete visual sample")
		return
	for entry in held:
		var body: RigidBody3D = entry ["body"]
		if body.collision_layer != 0 or body.collision_mask != 0 or not body.has_meta(LiveStrandManager.META_LOCAL_VISUAL):
			_fail("claw straw still participates in collision queries")
			return
		if not RoboticArm.sample_physics_enabled and PhysicsServer3D.body_get_space(body.get_rid()).is_valid():
			_fail("claw sample retained a physics space")
			return
	var hay_before:= GameState.hay_total
	var undrawn:= arm._payload_count - held.size()
	var live_before: int = world.live.active_count()
	arm.to_dict()
	if not is_equal_approx(GameState.hay_total, hay_before + undrawn) or world.live.active_count() != live_before or world.live._local_visual_count != held.size():
		_fail("serializing a batched claw changed its visible hay accounting")
		return
	world.builds.demolish(arm)
	await get_tree().process_frame
	await get_tree().physics_frame
	for entry in held:
		var body = entry ["body"]
		if not is_instance_valid(body) or body.freeze or (body.collision_layer & Cfg.L_STRAND) == 0 or body.collision_mask == 0 or PhysicsServer3D.body_get_space(body.get_rid()) != body.get_world_3d().space:
			_fail("demolition did not restore loose straw collision")
			return
		var expected: Vector3 = held_pose * (entry ["offset"] as Vector3)
		if body.has_meta(LiveStrandManager.META_LOCAL_VISUAL) or body.global_position.distance_to(expected) > 0.25:
			_fail("demolition did not materialize straw at the claw")
			return
	if world.live._local_visual_count != 0:
		_fail("demolition left a stale local visual count")
		return
	print("[robot-arm-probe] batched sample serialized and released with collisions restored")
	var tiny: RoboticArm = world.builds.add_robotic_arm(base, 0.0, 1)
	tiny.set_process(false)
	tiny._pickup_source = harvest_point
	var samples:= tiny._harvest_field_payload(mini(5, Cfg.WAD_MIN_STRANDS - 1))
	for i in samples.size():
		tiny._payload.append({ "body": samples [i], "offset": Vector3(float(i) * 0.02, 0.0, 0.0),
			"basis": Basis.IDENTITY, "layer": Cfg.L_STRAND, "mask": LiveStrandManager.STRAND_MASK })
	tiny._build_payload_visual()
	tiny._update_payload()
	var small_pose:= tiny._payload_pose
	tiny._drop_target = tiny._socket.global_position
	tiny._drop_velocity = Vector3.ZERO
	var small_count: int = world.live.active_count()
	tiny._release_payload()
	if samples.is_empty() or world.live.active_count() != small_count or tiny._payload_visual != null:
		_fail("small claw release changed the sample count or left its visual batch")
		return
	for i in samples.size():
		var body:= samples [i]
		var expected: Vector3 = small_pose * Vector3(float(i) * 0.02, 0.0, 0.0)
		if body.freeze or body.collision_layer != Cfg.L_STRAND or body.collision_mask != LiveStrandManager.STRAND_MASK or PhysicsServer3D.body_get_space(body.get_rid()) != body.get_world_3d().space or body.global_position.distance_to(expected) > 0.001:
			_fail("small claw release did not restore loose straw at its current pose")
			return
	print("[robot-arm-probe] small claw release restores sample count, space and pose")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("robot-arm-probe: %s" % message)
	get_tree().quit(1)
