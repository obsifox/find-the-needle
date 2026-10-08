class_name DevFenceProbe
extends Node


var world: Node3D
var player: Player
var warehouse: Warehouse


const RAY_Y:= 1.2


const RAY_HEIGHTS: Array [float] = [1.2, 3.0, 5.5, 8.0, 9.0, 12.0, 30.0, 150.0, 1500.0]


const RAY_LEN:= 400.0


const RAYS:= 720


func run() -> void:
	if world != null:
		world.block_save = true
	var fails:= 0
	fails += _check_built()
	fails += _check_reach()
	fails += await _check_gate_block()
	fails += await _check_backstop()
	fails += await _check_both_ways("stock")


	Tech.grant("yard_space", TechTree.max_rank("yard_space"))
	fails += _check_built()
	fails += await _check_both_ways("extended")
	Tech.reset()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _fence() -> YardFence:
	if warehouse == null:
		return null
	return warehouse.find_child("YardFence", true, false) as YardFence


func _check_built() -> int:
	print("\n-- the kit --")
	var pen:= _fence()
	if pen == null:
		return _fail("the yard has no YardFence in it")
	var bad:= 0
	for part in ["FencePanels", "FencePosts"]:
		var mmi:= pen.get_node_or_null(NodePath(part)) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			bad += _fail("no %s were built" % part)
			continue
		if mmi.multimesh.instance_count < 8:
			bad += _fail("%s has only %d instances in it"
				% [part, mmi.multimesh.instance_count])
		else:
			print("  %-12s %d instances" % [part, mmi.multimesh.instance_count])


		if part != "FencePanels":
			continue
		for i in mmi.multimesh.mesh.get_surface_count():
			var m:= mmi.multimesh.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null:
				bad += _fail("panel surface %d has no material on it" % i)
			elif m.albedo_texture == null:
				bad += _fail("panel surface %d has no albedo map" % i)
	var body:= pen.get_node_or_null(NodePath("FenceCollision")) as StaticBody3D
	if body == null:
		bad += _fail("the fence has no collision on it at all")
	elif body.get_child_count() < 3:
		bad += _fail("the fence has %d colliders, which is not a closed pen"
			% body.get_child_count())
	else:
		print("  %-12s %d runs" % ["collision", body.get_child_count()])


	var tall:= pen.get_node_or_null(NodePath("PenCollision")) as StaticBody3D
	if tall == null:
		bad += _fail("the fence has no player pen on it, so the wire is the limit")
	elif tall.collision_layer != Cfg.L_PEN:
		bad += _fail("the pen is on layer %d rather than L_PEN, so it stops the lorry"
			% tall.collision_layer)
	elif tall.get_child_count() < 3:
		bad += _fail("the pen has %d boxes, which is not a closed pen"
			% tall.get_child_count())
	else:
		print("  %-12s %d boxes, %.1f m tall"
			% ["pen", tall.get_child_count(), YardFence.PEN_HEIGHT])
	bad += _check_ring(pen)
	return bad


func _check_ring(pen: YardFence) -> int:
	var bad:= 0
	var sides:= 0
	var tall:= pen.get_node_or_null(NodePath("PenCollision"))
	if tall != null:
		for kid: Node in tall.get_children():
			if String(kid.name).begins_with("Ring"):
				sides += 1
	if sides != 8:
		bad += _fail("the ring round the yard has %d sides rather than 8" % sides)
	if YardFence.SHED_GAP >= Player.CAP_RADIUS * 2.0:
		bad += _fail("the ring stands %.2f m off the shed, and a %.2f m player fits down it"
			% [YardFence.SHED_GAP, Player.CAP_RADIUS * 2.0])
	if bad == 0:
		print("  %-12s %d sides, %.2f m off the walls" % ["ring", sides, YardFence.SHED_GAP])
	return bad


func _check_gate_block() -> int:
	print("\n-- the wall in the gateway --")
	var pen:= _fence()
	if pen == null:
		return _fail("the yard has no YardFence in it")
	var bad:= 0
	pen.set_open(true)
	await _settle(pen)
	var space:= pen.get_world_3d().direct_space_state
	var from:= pen.to_global(Vector3(0.0, RAY_Y, pen.reach_out - 6.0))
	var to:= pen.to_global(Vector3(0.0, RAY_Y, pen.reach_out + 6.0))
	var mine:= PhysicsRayQueryParameters3D.create(from, to, Cfg.L_PEN)
	if space.intersect_ray(mine).is_empty():
		bad += _fail("the open gateway lets the player straight through it")
	var theirs:= PhysicsRayQueryParameters3D.create(from, to,
		Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP)
	if not space.intersect_ray(theirs).is_empty():
		bad += _fail("something other than the player is stopped in the gateway")


	var across:= 0
	for i in 41:
		var t:= pen.to_global(Vector3((pen.gate_w * 0.5 + 1.0) * (i / 20.0 - 1.0),
			RAY_Y, pen.reach_out + 6.0))
		var q:= PhysicsRayQueryParameters3D.create(from, t, Cfg.L_WORLD | Cfg.L_PEN)
		if space.intersect_ray(q).is_empty():
			across += 1
	if across > 0:
		bad += _fail("%d of 41 lines across the open gateway lead out" % across)


	if player != null and (player.collision_mask & Cfg.L_PEN) == 0:
		bad += _fail("the player does not collide with the wall in the gateway")
	if bad == 0:
		print("  open, and shut to the player alone")
	pen.set_open(false)
	await _settle(pen)
	return bad


const SETTLE_TICKS:= 8


func _check_backstop() -> int:
	print("\n-- put back --")
	var pen:= _fence()
	if pen == null:
		return _fail("the yard has no YardFence in it")
	if player == null:
		return _fail("there is no player to put anywhere")
	var bad:= 0

	var outside:= {
		"behind the shed": Vector3(0.0, 12.0, -60.0),
		"out to the side": Vector3(60.0, 2.0, 10.0),
		"down the corridor": Vector3(0.0, 2.0,
			(pen.reach_out + pen.corridor_out) * 0.5),
		"off the roof, forwards": Vector3(0.0, 11.0, pen.reach_out + 40.0),
	}
	for where: String in outside:
		player.global_position = pen.to_global(outside [where] as Vector3)
		for _i in SETTLE_TICKS:
			await get_tree().physics_frame
		if not _in_yard(pen, player.global_position):
			bad += _fail("%s: the player is left at %v, outside the yard"
				% [where, player.global_position])
	var inside:= {
		"the middle of the apron": Vector3(0.0, 1.0, pen.reach_out * 0.5),
		"up against the wire": Vector3(0.0, 1.0, pen.reach_out - 0.5),
		"on the floor of the shed": Vector3(0.0, 1.0, -8.0),
		"on the eave behind the shed": Vector3(0.0, 12.0, - pen.shed_depth - 0.2),
		"high over the shed": Vector3(0.0, 60.0, - pen.shed_depth * 0.5),
	}
	for where: String in inside:
		var at:= pen.to_global(inside [where] as Vector3)
		player.global_position = at
		for _i in SETTLE_TICKS:
			await get_tree().physics_frame


		var moved:= Vector2(player.global_position.x - at.x,
			player.global_position.z - at.z).length()
		if moved > 2.0:
			bad += _fail("%s: the player was hauled %.1f m out of a legal spot"
				% [where, moved])
	if bad == 0:
		print("  %d ways out all put back, %d legal spots all left alone"
			% [outside.size(), inside.size()])
	return bad


func _in_yard(pen: YardFence, at: Vector3) -> bool:
	if warehouse != null and absf(at.x) <= warehouse.inner and absf(at.z) <= warehouse.inner:
		return true
	return pen.encloses(at)


func _check_reach() -> int:
	print("\n-- who it answers --")
	var pen:= _fence()
	if pen == null:
		return _fail("the yard has no YardFence in it")
	var bad:= 0
	var gate:= pen.gate_point()

	var inward:= (pen.to_global(Vector3.ZERO) - gate).normalized()
	var eye:= gate + inward * (YardFence.OPEN_DISTANCE - 1.0)
	if not pen.is_hovered(eye, - inward):
		bad += _fail("the gate is not offered from %.1f m away, looking at it"
			% (YardFence.OPEN_DISTANCE - 1.0))
	if pen.is_hovered(eye, inward):
		bad += _fail("the gate is offered to somebody facing away from it")
	var far:= gate + inward * (YardFence.OPEN_DISTANCE + 4.0)
	if pen.is_hovered(far, - inward):
		bad += _fail("the gate is offered from %.1f m away"
			% (YardFence.OPEN_DISTANCE + 4.0))
	if bad == 0:
		print("  offered within %.1f m and on aim, and not otherwise"
			% YardFence.OPEN_DISTANCE)
	bad += _check_press_does_nothing(pen)
	return bad


func _check_press_does_nothing(pen: YardFence) -> int:
	var bad:= 0


	if not pen.is_shut():
		return _fail("the gate is not shut before anything has touched it")
	if not pen.toggle():
		bad += _fail("the gate does not take the press, so the shop will get it")
	if pen.is_open():
		bad += _fail("E swung the gate open")
	if bad == 0:
		print("  the press is taken and the gate stays shut")
	return bad


func _check_sealed(label: String, stand_z: float) -> int:
	var bad:= 0
	for y: float in RAY_HEIGHTS:
		bad += _sweep("%s, %.1f m up" % [label, y], stand_z, y)
	return bad


func _sweep(label: String, stand_z: float, y: float) -> int:
	var pen:= _fence()
	if pen == null:
		return _fail("%s: no fence to test" % label)
	var space:= pen.get_world_3d().direct_space_state
	var from:= pen.to_global(Vector3(0.0, y, stand_z))
	var out:= 0
	var worst:= 0.0
	var worst_at:= Vector3.ZERO
	for i in RAYS:
		var a:= TAU * i / RAYS
		var to:= from + Vector3(sin(a), 0.0, cos(a)) * RAY_LEN
		var q:= PhysicsRayQueryParameters3D.create(from, to,
			Cfg.L_WORLD | Cfg.L_PEN)
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			out += 1
			worst = RAY_LEN
			worst_at = to
			continue
		var reach:= from.distance_to(hit ["position"])
		if reach > worst and out == 0:
			worst = reach
			worst_at = hit ["position"]
	if out > 0:
		return _fail("%s: %d of %d directions lead out, one of them towards %v"
			% [label, out, RAYS, worst_at])
	print("  %-26s %d directions, every one blocked, furthest %.1f m"
		% [label, RAYS, worst])
	return 0


func _check_both_ways(label: String) -> int:
	print("\n-- shut and open (%s) --" % label)
	var pen:= _fence()
	if pen == null:
		return _fail("%s: no fence to test" % label)
	var bad:= 0
	pen.set_open(false)
	await _settle(pen)
	if not pen.is_shut():
		bad += _fail("%s: the gate will not shut" % label)
	bad += _check_sealed("%s, gate shut" % label, pen.reach_out * 0.5)


	bad += _check_sealed("%s, over the shed" % label, - pen.shed_depth * 0.5)

	pen.set_open(true)
	await _settle(pen)
	if not pen.is_open():
		bad += _fail("%s: the gate will not open" % label)
	bad += _check_sealed("%s, gate open" % label, pen.reach_out * 0.5)


	bad += _check_sealed("%s, in the corridor" % label,
		(pen.reach_out + pen.corridor_out) * 0.5)

	pen.set_open(false)
	await _settle(pen)
	return bad


func _settle(pen: YardFence) -> void:
	for _i in int(YardFence.SWING_TIME * 70.0):
		if not pen.is_processing():
			return
		await get_tree().process_frame


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	Tech.reset()
	await get_tree().process_frame


	player.set_physics_process(false)
	player.set_process(false)

	var pen:= _fence()
	if pen == null:
		print("[fenceshot] there is no fence to photograph")
		get_tree().quit(1)
		return


	var out:= pen.reach_out


	await _look_from(pen.to_global(Vector3(0.0, 1.66, out - 9.0)),
		pen.to_global(Vector3(0.0, 1.3, out)))
	await _shot(out_dir, "fence_gate.png")


	await _look_from(pen.to_global(Vector3(-7.5, 1.66, out - 5.0)),
		pen.to_global(Vector3(1.0, 1.2, out)))
	await _shot(out_dir, "fence_gate_oblique.png")


	await _look_from(pen.to_global(Vector3(2.0, 1.66, out + 8.0)),
		pen.to_global(Vector3(-0.5, 1.2, out)))
	await _shot(out_dir, "fence_gate_outside.png")


	pen.set_open(true)
	await _settle(pen)
	await _look_from(pen.to_global(Vector3(0.0, 1.66, out - 7.0)),
		pen.to_global(Vector3(0.0, 1.4, out + 30.0)))
	await _shot(out_dir, "fence_gate_open.png")

	await _look_from(pen.to_global(Vector3(0.0, 1.66, out + 6.0)),
		pen.to_global(Vector3(0.0, 1.4, pen.corridor_out)))
	await _shot(out_dir, "fence_corridor.png")

	pen.set_open(false)
	await _settle(pen)
	await _departure(out_dir, pen)
	get_tree().quit()


func _departure(out_dir: String, pen: YardFence) -> void:
	var truck: DeliveryTruck = world.get("truck")
	if truck == null:
		print("[fenceshot] no lorry in this world, skipping the departure")
		return
	truck.snap_parked()
	await get_tree().physics_frame


	await _look_from(pen.to_global(Vector3(0.0, 1.66, 2.0)),
		pen.to_global(Vector3(0.0, 1.6, pen.corridor_out)))
	truck.depart()


	for shot in [["fence_leaving_gate.png", 8.8], ["fence_leaving_fog.png", 2.2],
			["fence_leaving_gone.png", 2.4]]:
		await _hold(float(shot [1]))
		await _shot(out_dir, String(shot [0]))


func _hold(seconds: float) -> void:
	for _i in int(seconds * 60.0):
		await get_tree().physics_frame


func _look_from(eye: Vector3, at: Vector3) -> void:
	player.global_position = eye
	player.look_at_from_position(eye, at, Vector3.UP)
	player.rotation.x = 0.0
	var to_at:= at - eye
	player.head.rotation.x = atan2(to_at.y, Vector2(to_at.x, to_at.z).length())
	await get_tree().process_frame


func _shot(out_dir: String, shot_name: String) -> void:
	for _i in 16:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[fenceshot] wrote %s" % path)
