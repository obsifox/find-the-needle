class_name DevDismantleProbe
extends Node


const SETTLE:= 8


const TARGET_RANGE:= 3.5


const PAPER_RANGE:= 5.0


const PATIENCE:= 8.0

var world: Node3D
var player: Player

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:


	world.block_save = true
	print("--- dismantle probe ---")
	for i in SETTLE:
		await get_tree().process_frame


	player._set_tool(Player.Tool.HAND)
	player.capture_mouse(true)
	GameState.add_money(20000.0)
	for i in SETTLE:
		await get_tree().process_frame
	_ok(not player.build.is_active(), "the build tool is put away")

	await _case_strip()
	await _case_arm_aim()
	await _case_drone_aim()
	await _case_launcher_aim()
	await _case_wrapper_aim()
	await _case_paper_aim()
	await _case_hatch_aim()
	await _case_demolish_wake()
	await _case_rake_sheds()
	await _case_bare_hands()
	await _case_chain()
	await _case_chain_keeps_its_kind()
	await _case_chain_spares_the_floor()
	await _case_named()
	await _case_copy()
	await _case_let_go()
	await _case_look_away()
	await _case_mouse_taken()
	await _case_blocked()
	await _case_misses_say_why()
	await _case_a_machine_with_hay_in_it()
	await _case_a_deck_under_every_kind()
	await _case_nothing_is_founded_on_the_pile()

	print("--- %s ---" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _case_strip() -> void:
	print("\n=== the prompt on the hint strip ===")
	var strip:= _strip()
	_ok(strip != null, "the HUD has a hint strip")
	if strip == null:
		return
	_ok(player.build.dismantle_target() == null, "the crosshair starts on nothing")
	_ok(not _strip_says(strip, "Dismantle"), "...so the bar does not offer the hold")
	var wall:= await _wall_in_front()
	_ok(_strip_says(strip, "Dismantle"), "a wall in the crosshair puts it on the bar")
	world.builds.demolish(wall)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(not _strip_says(strip, "Dismantle"), "...and it goes when the wall does")


func _case_arm_aim() -> void:
	print("\n=== aiming at a robotic arm ===")
	var arm:= await _arm_in_front()
	var volume:= arm.get_node_or_null("AimVolume") as Area3D
	_ok(volume != null and (volume.collision_layer & Cfg.L_BUILD) != 0,
		"the machine puts an aim volume on the build layer")


	var drawn:= _body_aabb(arm)
	var scaled_height: float = RoboticArm.AIM_HEIGHT * arm.visual_scale()
	var reach_up: float = arm.global_position.y + scaled_height
	_ok(reach_up >= drawn.position.y + drawn.size.y - 0.1,
		"...as tall as the machine's body is drawn (%.2f m against %.2f m)"
			% [reach_up, drawn.position.y + drawn.size.y])


	var mast:= arm.find_child("RA_MastVisual", true, false) as MeshInstance3D
	_ok(mast != null and (mast.global_transform * mast.get_aabb()).size.y > 2.0,
		"...and the mast is what makes it that tall")
	_ok(RoboticArm.AIM_RADIUS <= RoboticArm.BASE_RADIUS,
		"...and no wider than the pedestal that is already solid")

	_ok(player.build.dismantle_target() == arm,
		"a level look at the machine finds it")

	player.set_look(player.rotation.y, -0.35)
	await get_tree().process_frame
	_ok(player.build.dismantle_target() == arm, "...and so does a look down at it")
	player.set_look(player.rotation.y, 0.0)
	await get_tree().process_frame
	world.builds.demolish(arm)
	await get_tree().process_frame


func _case_drone_aim() -> void:
	print("\n=== aiming at a hay drone ===")
	var drone:= await _drone_in_front()
	var drawn:= _visual_aabb(drone)
	print("  the aircraft is drawn %.2f m tall, to %.2f m"
		% [drawn.size.y, drawn.position.y + drawn.size.y])
	var volume:= drone.get_node_or_null("AimVolume") as Area3D
	_ok(volume != null and (volume.collision_layer & Cfg.L_BUILD) != 0,
		"the machine puts an aim volume on the build layer")
	var reach_up: float = drone.global_position.y + HayDrone.AIM_HEIGHT
	_ok(reach_up >= drawn.position.y + drawn.size.y - 0.1,
		"...as tall as the aircraft is drawn (%.2f m against %.2f m)"
			% [reach_up, drawn.position.y + drawn.size.y])


	var middle:= drawn.position + drawn.size * Vector3(0.5, 0.5, 0.5)
	var high:= drawn.position + drawn.size * Vector3(0.5, 0.86, 0.5)

	await _aim_at(middle)
	_ok(player.build.dismantle_target() == drone,
		"a look at the middle of the aircraft finds the machine")
	_ok(_hud_walks_up_to(drone),
		"...and the HUD's own ray reaches it from the same aim")

	await _aim_at(high)
	_ok(player.build.dismantle_target() == drone,
		"a look at the rotor deck finds it too")


	_ok(_hud_walks_up_to(drone),
		"...and the HUD's ray does as well, which is the fault line")


	await _aim_at(drawn.position + drawn.size * Vector3(0.5, 1.0, 0.5)
		+ Vector3(0.0, 1.0, 0.0))
	_ok(player.build.dismantle_target() != drone,
		"a look at the air above the drone finds nothing")

	player.set_look(player.rotation.y, 0.0)
	await get_tree().process_frame
	world.builds.demolish(drone)
	await get_tree().process_frame


func _case_launcher_aim() -> void:
	print("\n=== aiming at a tube launcher ===")
	var gun:= await _launcher_in_front()


	var drawn:= _visual_aabb(gun)
	await _aim_at(drawn.position + drawn.size * Vector3(0.5, 0.5, 0.5))
	_ok(player.build.dismantle_target() == gun,
		"a look at the machine finds it")
	_ok(_hud_walks_up_to(gun), "...and the HUD's own ray reaches it as well")

	var cost: float = gun.build_cost()
	var purse: float = GameState.money
	var standing: int = world.builds.tube_launchers.size()
	_press(true)
	var gone:= await _wait_until(func() -> bool:
		return world.builds.tube_launchers.size() < standing)
	_press(false)
	await get_tree().process_frame
	_ok(gone, "the hold takes it down")
	_ok(absf(GameState.money - (purse + cost)) < 0.01,
		"...paying the build cost back ($%.0f)" % cost)
	player.set_look(player.rotation.y, 0.0)
	await get_tree().process_frame


func _launcher_in_front() -> TubeLauncher:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * TARGET_RANGE
	var gun: TubeLauncher = world.builds.add_tube_launcher(
		Vector3(at.x, player.global_position.y, at.z), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	return gun


func _case_wrapper_aim() -> void:
	print("\n=== aiming at a hay wrapper ===")
	var wrap:= await _wrapper_in_front()


	var drawn:= _visual_aabb(wrap)
	await _aim_at(drawn.position + drawn.size * Vector3(0.5, 0.3, 0.5))
	_ok(player.build.dismantle_target() == wrap, "a look at the machine finds it")

	var cost: float = wrap.build_cost()
	var purse: float = GameState.money
	var standing: int = world.builds.wrappers.size()
	_press(true)
	var gone:= await _wait_until(func() -> bool:
		return world.builds.wrappers.size() < standing)
	_press(false)
	await get_tree().process_frame
	_ok(gone, "the hold takes it down")
	_ok(absf(GameState.money - (purse + cost)) < 0.01,
		"...paying the build cost back ($%.0f)" % cost)
	player.set_look(player.rotation.y, 0.0)
	await get_tree().process_frame


func _case_paper_aim() -> void:
	print("\n=== aiming at a paper mill ===")
	var mill:= await _paper_in_front()
	for aim: Array in [
			[Vector3(0.0, 1.2, -2.02), "the press"],
			[Vector3(0.0, 0.9, -0.37), "the dryer body"],
			[Vector3(0.0, 0.5, 1.66), "the winder"]]:
		var at: Vector3 = aim [0]
		var what: String = aim [1]
		await _aim_at(mill.to_global(at))
		_ok(player.build.dismantle_target() == mill, "a look at %s finds the mill" % what)

	var span:= _solid_span_z(mill)
	_ok(span.x > - Cfg.PAPER_LENGTH * 0.5 + 0.56,
		"the solid stops short of the infeed face (%.2f)" % span.x)
	_ok(span.y < Cfg.PAPER_LENGTH * 0.5 - PaperMachine.OUT_STUB,
		"...and short of where the outfeed stub starts (%.2f)" % span.y)

	await _aim_at(mill.to_global(Vector3(0.0, 0.9, -0.37)))
	var cost: float = mill.build_cost()
	var purse: float = GameState.money
	var standing: int = world.builds.papers.size()
	_press(true)
	var gone:= await _wait_until(func() -> bool:
		return world.builds.papers.size() < standing)
	_press(false)
	await get_tree().process_frame
	_ok(gone, "the hold takes it down")
	_ok(absf(GameState.money - (purse + cost)) < 0.01,
		"...paying the build cost back ($%.0f)" % cost)
	player.set_look(player.rotation.y, 0.0)
	await get_tree().process_frame


func _solid_span_z(machine: Node3D) -> Vector2:
	var span:= Vector2(INF, - INF)
	var body:= machine.get_node_or_null("Body") as StaticBody3D


	if body == null:
		_fails += 1
		print("  FAIL the machine has no body to measure")
		return Vector2(- INF, INF)
	for c in body.get_children():
		var cs:= c as CollisionShape3D
		if cs == null:
			continue
		var box:= cs.shape as BoxShape3D
		if box == null:
			continue
		span.x = minf(span.x, cs.position.z - box.size.z * 0.5)
		span.y = maxf(span.y, cs.position.z + box.size.z * 0.5)
	if not is_finite(span.x):
		_fails += 1
		print("  FAIL the body carries no box shapes to measure")
		return Vector2(- INF, INF)
	return span


func _case_hatch_aim() -> void:
	print("\n=== aiming at a dump hatch ===")
	var tip:= await _hatch_in_front()
	var volume:= tip.get_node_or_null("AimVolume") as Area3D
	_ok(volume != null and (volume.collision_layer & Cfg.L_BUILD) != 0,
		"the machine puts an aim volume on the build layer")
	_ok(volume != null and not volume.monitoring,
		"...and it is not monitoring, because nothing ever asks it anything")


	var drawn:= _visual_aabb(tip)
	var reach_up: float = tip.global_position.y + DumpHatch.AIM_CENTRE.y + DumpHatch.AIM_SIZE.y * 0.5
	print("  the machine is drawn %.2f m tall, to %.2f m"
		% [drawn.size.y, drawn.position.y + drawn.size.y])
	_ok(reach_up >= drawn.position.y + drawn.size.y - 0.1,
		"...as tall as the machine is drawn (%.2f m against %.2f m)"
			% [reach_up, drawn.position.y + drawn.size.y])


	var aims:= {
		"the bin under the deck": Vector3(0.0, 0.52, 0.56),
		"the catcher's mouth": Vector3(0.0, 1.05, 0.13),
		"the middle of the deck": Vector3(0.0, 0.8, 0.9),
	}


	for what: String in aims:
		await _aim_at(tip.to_global(aims [what]))
		_ok(not _solid_under_crosshair(),
			"nothing solid stands behind %s" % what)
		_ok(player.build.dismantle_target() == tip,
			"...and a look at it finds the machine")


	await _aim_at(tip.to_global(Vector3(0.0, 2.4, 0.9)))
	_ok(player.build.dismantle_target() != tip,
		"a look at the air above the machine finds nothing")


	await _aim_at(tip.to_global(aims ["the bin under the deck"]))
	var cost: float = tip.build_cost()
	var purse: float = GameState.money
	var standing: int = world.builds.dump_hatches.size()
	_press(true)
	var gone:= await _wait_until(func() -> bool:
		return world.builds.dump_hatches.size() < standing)
	_press(false)
	await get_tree().process_frame
	_ok(gone, "the hold takes it down")
	_ok(absf(GameState.money - (purse + cost)) < 0.01,
		"...paying the build cost back ($%.0f)" % cost)
	player.set_look(player.rotation.y, 0.0)
	await get_tree().process_frame


func _hatch_in_front() -> DumpHatch:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * TARGET_RANGE


	var tip: DumpHatch = world.builds.add_dump_hatch(
		Vector3(at.x, player.global_position.y, at.z), player.rotation.y + PI * 0.5)
	for i in SETTLE:
		await get_tree().physics_frame
	return tip


func _solid_under_crosshair() -> bool:
	var from:= player.camera.global_position
	var query:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * BuildTool.DISMANTLE_REACH, Cfg.L_BUILD)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _wrapper_in_front() -> HayWrapper:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * TARGET_RANGE
	var wrap: HayWrapper = world.builds.add_wrapper(
		Vector3(at.x, player.global_position.y, at.z), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	return wrap


func _paper_in_front() -> PaperMachine:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * PAPER_RANGE
	var mill: PaperMachine = world.builds.add_paper(
		Vector3(at.x, player.global_position.y, at.z), player.rotation.y + PI * 0.5)
	for i in SETTLE:
		await get_tree().physics_frame
	return mill


func _aim_at(target: Vector3) -> void:
	var eye:= player.camera.global_position
	var flat:= Vector2(target.x - eye.x, target.z - eye.z).length()
	player.set_look(atan2(target.x - eye.x, target.z - eye.z) + PI,
		atan2(target.y - eye.y, maxf(flat, 0.001)))
	for i in 3:
		await get_tree().physics_frame


func _hud_walks_up_to(machine: Node) -> bool:
	var from:= player.camera.global_position
	var query:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Tech.carry_reach(), Cfg.L_BUILD)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = true
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(query)
	var walk:= hit.get("collider") as Node
	while walk != null:
		if walk == machine:
			return true
		walk = walk.get_parent()
	return false


func _drone_in_front() -> HayDrone:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * TARGET_RANGE
	var drone: HayDrone = world.builds.add_hay_drone(
		Vector3(at.x, player.global_position.y, at.z), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	return drone


func _arm_in_front() -> RoboticArm:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * TARGET_RANGE
	var arm: RoboticArm = world.builds.add_robotic_arm(
		Vector3(at.x, player.global_position.y, at.z), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	return arm


func _body_aabb(arm: Node3D) -> AABB:
	var boom:= arm.find_child("RA_ShoulderPitch", true, false)
	var box:= AABB()
	var first:= true
	for m: MeshInstance3D in _meshes(arm):
		if boom != null and boom.is_ancestor_of(m):
			continue
		var world_box:= m.global_transform * m.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box


func _visual_aabb(node: Node3D) -> AABB:
	var box:= AABB()
	var first:= true
	for m: MeshInstance3D in _meshes(node):
		var world_box:= m.global_transform * m.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box


func _meshes(node: Node) -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	var mesh:= node as MeshInstance3D
	if mesh != null and mesh.visible:
		out.append(mesh)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


func _case_demolish_wake() -> void:
	print("\n=== hay asleep on a building that is dismantled ===")
	var dir:= player.look_direction()
	var centre:= player.global_position + Vector3(dir.x, 0.0, dir.z).normalized() * TARGET_RANGE + Vector3(0.0, 1.6, 0.0)
	var deck: Platform = world.builds.add_platform(centre, Vector2(3.0, 3.0))
	for i in SETTLE:
		await get_tree().physics_frame

	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), centre + Vector3(0.0, 0.5, 0.0)),
		{ "strands": 20 }) as HayWad
	_ok(wad != null, "a wad is dropped onto the deck")
	if wad == null:
		world.builds.demolish(deck)
		return
	_ok(await _wait_until(func() -> bool: return wad.sleeping),
		"...and goes to sleep on it")
	var rest_y:= wad.global_position.y
	_ok(rest_y > centre.y - 0.5,
		"...up on the deck rather than on the floor (%.2f m)" % rest_y)

	world.builds.demolish(deck)
	await get_tree().physics_frame
	_ok(not wad.sleeping, "taking the deck down wakes the load it was holding")
	_ok(await _wait_until(func() -> bool:
		return wad.global_position.y < rest_y - 0.5),
		"...and it comes down instead of hanging in the air")


	if is_instance_valid(wad):
		world.props.remove(wad)
	await get_tree().process_frame


func _case_rake_sheds() -> void:
	print("\n=== a load left on the rake's own back ===")
	var dir:= player.look_direction()
	var foot:= player.global_position + Vector3(dir.x, 0.0, dir.z).normalized() * TARGET_RANGE
	var rake: PistonRake = world.builds.add_piston_rake(foot, atan2(- dir.x, - dir.z))
	for i in SETTLE:
		await get_tree().physics_frame

	var roof: float = rake.global_position.y + PistonRake.BODY_H


	var on_top: Vector3 = rake.global_position + rake.global_basis.z * PistonRake.BODY_Z + Vector3(0.0, PistonRake.BODY_H + 0.3, 0.0)
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), on_top),
		{ "strands": 20 }) as HayWad
	_ok(wad != null, "a wad is dropped onto the roof")
	if wad == null:
		world.builds.demolish(rake)
		return

	var cleared:= await _wait_until(func() -> bool:
		return wad.sleeping and wad.global_position.y < roof - 0.3)
	_ok(cleared, "the machine shakes it off (rest %.2f m, roof at %.2f m)"
		% [wad.global_position.y, roof])

	var off: Vector3 = rake.to_local(wad.global_position)
	_ok(absf(off.x) > PistonRake.BODY_W * 0.5 - 0.1,
		"...clear of the flank rather than down the middle (%.2f m out)" % absf(off.x))

	if is_instance_valid(wad):
		world.props.remove(wad)


	var straw: Array [RigidBody3D] = []
	for i in 6:
		var at:= on_top + Vector3(randf_range(-0.4, 0.4), float(i) * 0.05,
			randf_range(-0.6, 0.6))
		var b: RigidBody3D = world.live.spawn(at, Basis(), Vector3.ZERO,
			Color(0.86, 0.72, 0.38))
		if b != null:
			straw.append(b)
	_ok(straw.size() == 6, "six loose strands are dropped onto the roof")
	var swept:= await _wait_until(func() -> bool:
		for b: RigidBody3D in straw:
			if is_instance_valid(b) and b.global_position.y > roof - 0.3:
				return false
		return true)
	_ok(swept, "...and every one of them is off the machine")


	var alive:= 0
	for b: RigidBody3D in straw:
		if is_instance_valid(b):
			alive += 1
	_ok(alive > 0, "...and they went by being shed, not by being reclaimed (%d left)"
		% alive)

	world.builds.demolish(rake)
	await get_tree().process_frame


func _case_bare_hands() -> void:
	print("\n=== held to the end, with an empty hand ===")
	var wall:= await _wall_in_front()
	var cost: float = wall.build_cost()
	var purse: float = GameState.money

	_press(true)


	var started:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() >= 0.0)
	_ok(started, "the key starts a hold")
	_ok(is_instance_valid(wall), "...and nothing has come down yet")

	var half:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() > 0.35)
	_ok(half, "the meter fills while the key is held")
	_ok(is_instance_valid(wall), "...and the wall is still standing part-way in")


	var standing: int = world.builds.walls.size()
	var gone:= await _wait_until(func() -> bool:
		return world.builds.walls.size() < standing)
	_press(false)
	await get_tree().process_frame
	_ok(gone, "the wall comes down at the end of the hold")
	_ok(player.build.dismantle_progress() < 0.0, "...and the hold is over")
	_ok(absf(GameState.money - (purse + cost)) < 0.01,
		"...paying the build cost back ($%.0f)" % cost)


func _case_chain() -> void:
	print("\n=== held down across two buildings ===")
	await _wall_in_front()
	var purse: float = GameState.money
	_press(true)


	var standing: int = world.builds.walls.size()
	var first:= await _wait_until(func() -> bool:
		return world.builds.walls.size() < standing)
	_ok(first, "the first wall comes down at the end of the hold")


	await _wall_in_front()
	var armed:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() >= 0.0)
	_ok(armed, "the second wall starts a hold without a second press")
	var again: int = world.builds.walls.size()
	var second:= await _wait_until(func() -> bool:
		return world.builds.walls.size() < again)
	_ok(second, "...and comes down on the held key")
	_ok(GameState.money > purse, "...with both refunds paid back")

	_press(false)
	await get_tree().process_frame
	await get_tree().process_frame


	var facing:= player.rotation.y
	player.set_look(facing + PI, 0.6)
	await get_tree().process_frame
	_ok(player.build.dismantle_target() == null, "the crosshair is on the sky")
	_press(true)
	await get_tree().process_frame
	player.set_look(facing, 0.0)
	var wall:= await _wall_in_front()
	_ok(await _stays_up(wall), "a key held since a MISS takes nothing down")
	_ok(player.build.dismantle_progress() < 0.0, "...and never starts a hold")
	_press(false)
	await get_tree().process_frame
	world.builds.demolish(wall)
	for i in SETTLE:
		await get_tree().physics_frame


func _case_chain_keeps_its_kind() -> void:
	print("\n=== held down from a wall onto a machine ===")
	await _wall_in_front()
	_press(true)
	var standing: int = world.builds.walls.size()
	_ok(await _wait_until(func() -> bool:
		return world.builds.walls.size() < standing),
		"the wall comes down at the end of the hold")

	var wrap:= await _wrapper_in_front()
	var drawn:= _visual_aabb(wrap)
	await _aim_at(drawn.position + drawn.size * Vector3(0.5, 0.3, 0.5))
	_ok(player.build.dismantle_target() == wrap, "the crosshair is on the wrapper")
	_ok(await _stays_up(wrap), "a chain started on a wall leaves the wrapper standing")
	_ok(player.build.dismantle_progress() < 0.0, "...and never starts a hold")
	_press(false)
	await get_tree().process_frame
	world.builds.demolish(wrap)
	player.set_look(player.rotation.y, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame


func _case_chain_spares_the_floor() -> void:
	print("\n=== held down from a deck onto the deck underfoot ===")
	var builds: BuildManager = world.builds
	var feet:= player.global_position
	var dir:= player.look_direction()
	var away:= Vector3(dir.x, 0.0, dir.z).normalized()
	var lift:= Vector3(0.0, 0.6, 0.0)
	var under: Platform = builds.add_platform(feet + lift, Vector2(3.0, 3.0))
	var ahead: Platform = builds.add_platform(feet + away * 4.0 + lift, Vector2(2.0, 2.0))
	player.global_position = Vector3(feet.x, under.top_y() + 0.05, feet.z)
	player.velocity = Vector3.ZERO
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(under.supports_point(player.global_position), "the player stands on a deck")

	await _aim_at(ahead.global_position)
	_ok(player.build.dismantle_target() == ahead, "the crosshair is on the other deck")
	_press(true)
	var decks: int = builds.platforms.size()
	_ok(await _wait_until(func() -> bool:
		return builds.platforms.size() < decks),
		"the other deck comes down at the end of the hold")

	await _aim_at(under.global_position + away * 0.6)
	_ok(player.build.dismantle_target() == under, "the crosshair is on the deck underfoot")
	_ok(await _stays_up(under), "a held chain leaves the deck underfoot standing")
	_press(false)
	await get_tree().process_frame
	await get_tree().process_frame

	_press(true)
	decks = builds.platforms.size()
	_ok(await _wait_until(func() -> bool:
		return builds.platforms.size() < decks),
		"...and a fresh press still takes it down")
	_press(false)
	player.set_look(player.rotation.y, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame


func _stays_up(building: Node3D) -> bool:
	var waited:= 0.0
	while waited < BuildTool.DISMANTLE_HOLD * 3.0:
		if not is_instance_valid(building):
			return false
		waited += get_process_delta_time()
		await get_tree().process_frame
	return is_instance_valid(building)


func _case_named() -> void:
	print("\n=== the bar names the building ===")
	var wall:= await _wall_in_front()

	_press(true)
	var started:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() >= 0.0)
	_ok(started, "the key starts a hold")
	_ok(player.build.dismantle_name() == "Wall", "the hold knows it has a wall")


	await get_tree().process_frame
	var label: Label = world.hud.get("_wreck_label")
	_ok(label != null and label.text.begins_with("DISMANTLING WALL    "),
		"...and the bar reads \"%s\"" % ("<no label>" if label == null else label.text))
	_press(false)
	await get_tree().process_frame


	wall.kind = YardWall.Bay.DOOR
	_ok(world.builds.name_of(wall) == "Doorway", "a door bay is named as one")
	wall.kind = YardWall.Bay.WINDOW
	_ok(world.builds.name_of(wall) == "Window Wall", "and a window bay as one")
	_ok(world.builds.name_of(null) == "", "nothing at all is named nothing")

	world.builds.demolish(wall)
	for i in SETTLE:
		await get_tree().physics_frame


func _case_copy() -> void:
	print("\n=== the middle click copies a building ===")
	player._set_tool(Player.Tool.HAND)
	await get_tree().process_frame
	var strip:= _strip()
	var had:= Tech.rank_of("wall")
	Tech.grant("wall", 0)
	var wall:= await _wall_in_front()
	_ok(player.build.copy_id() == "wall", "the ray reads the wall as a wall")
	_ok(strip != null and not _strip_says(strip, "Copy"),
		"a locked wall is not offered as a copy")
	await _click_middle()
	_ok(player.current_tool == Player.Tool.HAND and player.build_id == "",
		"...and the click leaves the hands alone")

	Tech.grant("wall", 1)
	_ok(strip != null and _strip_says(strip, "Copy wall"),
		"an unlocked wall puts \"Copy wall\" on the bar")
	await _click_middle()
	_ok(player.current_tool == Player.Tool.BUILD and player.build_id == "wall",
		"the click raises a wall hologram (%s)" % player.build_id)
	_ok(player.build.is_active(), "...and the tool is out")
	_ok(player.build.copy_id() == "" and not _strip_says(strip, "Copy"),
		"holding a wall already, the bar stops offering one")
	world.builds.demolish(wall)
	for i in SETTLE:
		await get_tree().physics_frame


	Tech.grant(BuildCatalog.unlock_of("wrapper"), 1)
	player.set_look(player.rotation.y, 0.0)
	var wrap:= await _wrapper_in_front()
	var drawn:= _visual_aabb(wrap)
	await _aim_at(drawn.position + drawn.size * Vector3(0.5, 0.3, 0.5))
	_ok(player.build.copy_id() == "wrapper", "the ray reads the wrapper")
	await _click_middle()
	_ok(player.build_id == "wrapper",
		"the click swaps the wall for a wrapper (%s)" % player.build_id)
	world.builds.demolish(wrap)


	var pump:= BoreholePump.new()
	_ok(world.builds.id_of(pump) == "borehole", "a borehole reads as a borehole")
	pump.free()
	Tech.grant("wall", had)
	player._set_tool(Player.Tool.HAND)
	player.set_look(player.rotation.y, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame


func _click_middle() -> void:
	var sent:= false
	for e in InputMap.action_get_events("pick_build"):
		var button:= e as InputEventMouseButton
		if button == null:
			continue
		for down: bool in [true, false]:
			var ev:= button.duplicate() as InputEventMouseButton
			ev.pressed = down
			Input.parse_input_event(ev)
			await get_tree().process_frame
		sent = true
		break
	if not sent:
		_ok(false, "the copy action has a mouse button bound to press")
	for i in 2:
		await get_tree().process_frame


func _case_let_go() -> void:
	print("\n=== let go part-way ===")
	var wall:= await _wall_in_front()
	var purse: float = GameState.money

	_press(true)
	var part:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() > 0.3)
	_ok(part, "the hold gets going")
	_press(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(player.build.dismantle_progress() < 0.0, "letting go ends the hold")
	_ok(is_instance_valid(wall), "...and the wall is still there")
	_ok(is_equal_approx(GameState.money, purse), "...and nothing was refunded")


	_press(true)
	await get_tree().process_frame
	_ok(player.build.dismantle_progress() < 0.2,
		"a second hold starts from the beginning")
	_press(false)
	await get_tree().process_frame
	_ok(is_instance_valid(wall), "...so a tap and a tap is not a demolition")
	world.builds.demolish(wall)
	await get_tree().process_frame


func _case_look_away() -> void:
	print("\n=== looked away part-way ===")
	var wall:= await _wall_in_front()
	var facing:= player.rotation.y

	_press(true)
	var part:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() > 0.3)
	_ok(part, "the hold gets going")
	player.set_look(facing + PI, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(player.build.dismantle_progress() < 0.0, "turning away ends the hold")
	_ok(is_instance_valid(wall), "...and the wall is still there")

	_press(false)
	player.set_look(facing, 0.0)
	await get_tree().process_frame
	world.builds.demolish(wall)
	await get_tree().process_frame


func _case_mouse_taken() -> void:
	print("\n=== a panel takes the mouse part-way ===")
	var wall:= await _wall_in_front()

	_press(true)
	var part:= await _wait_until(func() -> bool:
		return player.build.dismantle_progress() > 0.3)
	_ok(part, "the hold gets going")
	player.capture_mouse(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(player.build.dismantle_progress() < 0.0, "losing the mouse ends the hold")
	_ok(is_instance_valid(wall), "...and the wall is still there")


	_press(false)
	await get_tree().process_frame
	_press(true)
	await get_tree().process_frame
	_ok(player.build.dismantle_progress() < 0.0,
		"and no hold can be started with a panel up")
	_press(false)
	player.capture_mouse(true)
	await get_tree().process_frame
	world.builds.demolish(wall)
	await get_tree().process_frame


func _case_blocked() -> void:
	print("\n=== a loaded deck ===")


	player.set_look(player.rotation.y, -0.45)
	await get_tree().process_frame
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * (TARGET_RANGE * 0.8)
	var away:= Vector3(dir.x, 0.0, dir.z).normalized()


	var centre:= at + away * (Cfg.PLATFORM_TILE * 0.4)
	var deck: Platform = world.builds.add_platform(centre,
		Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE))
	var top: float = deck.top_y()
	var belt_from:= Vector3(centre.x, top, centre.z) + away * 0.2
	var belt: Conveyor = world.builds.add_conveyor(belt_from,
		belt_from + away * (Cfg.BELT_SEGMENT * 2.0))
	for i in SETTLE:
		await get_tree().physics_frame

	_ok(world.builds.demolish_blocked_reason(deck) != "",
		"the deck is carrying something")
	_ok(player.build.dismantle_target() == deck, "the ray is on the deck")
	world.hud.show_toast("", 0.0)
	_press(true)


	for i in 12:
		await get_tree().process_frame
	_ok(player.build.dismantle_progress() < 0.0, "the hold refuses to start")
	_ok(is_instance_valid(deck), "...and the deck is still there")


	_ok(world.hud.toast_text().contains("CLEAR 1 FROM THE DECK FIRST"),
		"...and a toast says why (%s)" % world.hud.toast_text())
	var strip:= _strip()
	if strip != null:


		_ok(not _strip_says(strip, "Dismantle"),
			"...the bar does not offer a hold that would be refused")
		_ok(not _strip_says(strip, "to dismantle this"),
			"...and does not park the refusal on the bar")
	_press(false)
	await get_tree().process_frame
	world.builds.demolish(belt)
	world.builds.demolish(deck)
	await get_tree().process_frame


func _case_misses_say_why() -> void:
	print("\n=== a press that finds nothing ===")


	var yaw0: float = player.rotation.y
	var clear:= false
	for k in 8:
		player.set_look(yaw0 + k * PI / 4.0, 0.0)
		await get_tree().physics_frame
		var from:= player.eye_position()
		var q:= PhysicsRayQueryParameters3D.create(from,
			from + player.look_direction() * (BuildTool.DISMANTLE_REACH + 6.0))
		q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
		q.collide_with_areas = true
		if player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			clear = true
			break
	_ok(clear, "some heading from the spawn is clear for fourteen metres")
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var at:= eye + dir * (BuildTool.DISMANTLE_REACH + 4.0)
	var across:= dir.cross(Vector3.UP).normalized() * (Cfg.WALL_PANEL * 0.5)
	var foot:= Vector3(at.x, player.global_position.y, at.z)
	var wall: YardWall = world.builds.add_wall(foot - across, foot + across,
		YardWall.Bay.SOLID)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(player.build.dismantle_target() == null, "a wall past the reach is not a target")
	world.hud.show_toast("", 0.0)
	_press(true)
	await get_tree().process_frame
	_press(false)
	await get_tree().process_frame
	_ok(is_instance_valid(wall), "...the wall is still there")
	_ok(world.hud.toast_text().contains("GET CLOSER"),
		"...and a toast says to get closer (%s)" % world.hud.toast_text())
	world.builds.demolish(wall)
	await get_tree().physics_frame


	player.set_look(player.rotation.y, -1.5)
	for i in SETTLE:
		await get_tree().physics_frame
	world.hud.show_toast("", 0.0)
	_press(true)
	await get_tree().process_frame
	_press(false)
	await get_tree().process_frame
	_ok(world.hud.toast_text().contains("THINGS YOU BUILT"),
		"the floor says only built things come down (%s)" % world.hud.toast_text())


	player.set_look(player.rotation.y, 1.5)
	await get_tree().physics_frame
	world.hud.show_toast("", 0.0)
	_press(true)
	await get_tree().process_frame
	_press(false)
	await get_tree().process_frame
	_ok(world.hud.toast_text() == "", "open sky says nothing")
	player.set_look(yaw0, 0.0)
	await get_tree().process_frame


func _case_a_machine_with_hay_in_it() -> void:
	print("\n=== a machine with hay still in it ===")
	var builds: BuildManager = world.builds
	var dir:= player.look_direction()
	var away:= Vector3(dir.x, 0.0, dir.z).normalized()
	var base:= player.global_position + away * (TARGET_RANGE * 3.0)
	var across:= away.cross(Vector3.UP).normalized()


	var tank: HaySilo = builds.add_silo(base, 0.0)
	var press: HayCompressor = builds.add_compressor(base + across * 8.0, 0.0)
	var wrap: HayWrapper = builds.add_wrapper(base + across * 16.0, 0.0)
	var mill: HayPelletizer = builds.add_pelletizer(base + across * 24.0, 0.0)
	var gun: TubeLauncher = builds.add_tube_launcher(base + across * 32.0, 0.0)
	var tip: DumpHatch = builds.add_dump_hatch(base + across * 40.0, 0.0)
	var loaded: Array [Node3D] = [tank, press, wrap, mill, gun, tip]


	for machine: Node3D in loaded:
		if machine.has_method("set_switched_off"):
			machine.call("set_switched_off", true)
	for machine: Node3D in loaded:
		_ok(builds.hay_inside(machine) == "",
			"an empty %s has nothing to lose" % builds.name_of(machine))
	tank.queued.append({ "id": "hay_wad", "state": { "strands": 40 } })
	press.stored = 40
	wrap.queued.append(40)
	mill.stored = 40
	gun.stored = 40
	tip.stored = 40
	for i in SETTLE:
		await get_tree().physics_frame
	for machine: Node3D in loaded:
		var what:= builds.name_of(machine)
		var lost:= builds.hay_inside(machine)
		_ok(lost != "", "a loaded %s says what it would lose: \"%s\"" % [what, lost])
		_ok(builds.demolish_blocked_reason(machine) == "",
			"...and does not refuse for it")


		var price:= builds.value_of(machine)
		var purse:= GameState.money
		world.hud.show_toast("", 0.0)
		player.build.dismantle(machine)
		_ok(not is_instance_valid(machine) or machine.is_queued_for_deletion(),
			"...and comes down")
		_ok(is_equal_approx(GameState.money - purse, price),
			"...for its price and not a cent for the hay ($%.2f against $%.2f)"
				% [GameState.money - purse, price])
		_ok(world.hud.toast_text().contains("LOST"),
			"...and a toast says what went with it (%s)" % world.hud.toast_text())
		_ok(world.hud.toast_text().contains("+$" + Hud.money_text(price)),
			"...and what came back (%s)" % world.hud.toast_text())
	for i in SETTLE:
		await get_tree().physics_frame


	var bare: HayCompressor = builds.add_compressor(base, 0.0)
	var bare_price:= builds.value_of(bare)
	world.hud.show_toast("", 0.0)
	player.build.dismantle(bare)
	_ok(world.hud.toast_text().contains("MONEY BACK")
			and world.hud.toast_text().contains("+$" + Hud.money_text(bare_price))
			and not world.hud.toast_text().contains("LOST"),
		"an empty machine shows the refund alone (%s)" % world.hud.toast_text())
	for i in SETTLE:
		await get_tree().physics_frame


	var running: HayWrapper = builds.add_wrapper(base, 0.0)
	running.queued.append(40)
	var turning:= await _wait_until(func() -> bool: return running.is_wrapping())
	_ok(turning, "a wrapper handed a bale starts turning")
	if turning:
		_ok(running.queued.is_empty() and builds.hay_inside(running) == "a load",
			"...and with its queue empty it still names a load (%s)"
				% builds.hay_inside(running))
		_ok(builds.demolish_blocked_reason(running) == "",
			"...and does not refuse for it")
		_ok(builds.demolish(running) > 0.0, "...and comes down mid cycle")
	else:
		builds.demolish(running)
	for i in SETTLE:
		await get_tree().physics_frame


func _case_a_deck_under_every_kind() -> void:
	print("\n=== a deck under each kind of machine ===")
	var builds: BuildManager = world.builds
	var dir:= player.look_direction()
	var away:= Vector3(dir.x, 0.0, dir.z).normalized()
	var across:= away.cross(Vector3.UP).normalized()
	var base:= player.global_position + away * (TARGET_RANGE * 5.0)


	var kinds: Array [Callable] = [
		func(at: Vector3) -> Node3D: return builds.add_compressor(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_scanner(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_silo(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_generator(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_power_pole(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_tube_launcher(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_dump_hatch(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_splitter(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_cabinet(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_hay_drone(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_piston_rake(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_robotic_arm(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_wrapper(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_pelletizer(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_hay_stairs(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_joiner(at, 0.0),
		func(at: Vector3) -> Node3D: return builds.add_paint_board(at, 0.0),
	]
	for i in kinds.size():
		var centre:= base + across * (float(i) * 10.0) + Vector3(0.0, 1.2, 0.0)
		var deck: Platform = builds.add_platform(centre, Vector2(6.0, 6.0))
		await get_tree().physics_frame
		var machine: Node3D = (kinds [i] as Callable).call(
			Vector3(centre.x, deck.top_y(), centre.z))
		for f in 3:
			await get_tree().physics_frame
		var what:= builds.name_of(machine)
		_ok(builds.standing_on(deck).has(machine),
			"a %s on a deck counts as standing on it" % what)
		_ok(builds.demolish_blocked_reason(deck) != "",
			"...so the deck under it refuses to come down")
		_ok(builds.demolish(deck) == 0.0, "...and pays nothing for trying")
		builds.demolish(machine)
		await get_tree().physics_frame
		_ok(builds.demolish_blocked_reason(deck) == "",
			"...and the deck is free again once the %s has gone" % what)
		builds.demolish(deck)
		await get_tree().physics_frame


func _case_nothing_is_founded_on_the_pile() -> void:
	print("\n=== a hologram over the crown of the pile ===")
	var tool:= player.build as BuildTool
	var field: HayField = world.builds.field
	if tool == null or field == null:
		_ok(false, "the run has no build tool and pile to aim at")
		return
	var crown_h:= field.height_at(0.0, 0.0)
	_ok(crown_h > 1.0, "there is a pile to stand on (%.2f m)" % crown_h)
	var crown:= Vector3(0.0, crown_h, 0.0)


	var floor_at:= Vector3(0.0, player.global_position.y,
		Cfg.PILE_RADIUS + 6.0)
	_ok(field.height_at(floor_at.x, floor_at.z) < 0.05,
		"...and bare concrete to compare it with")


	var sunk: Dictionary = tool._evaluate_deck(crown, Vector2(4.0, 4.0))
	_ok(str(sunk ["reason"]) == "in the hay",
		"a deck sunk into the crown: %s" % sunk ["reason"])
	for up: float in [1.0, 20.0]:
		var over: Dictionary = tool._evaluate_deck(crown + Vector3.UP * up,
			Vector2(4.0, 4.0))
		_ok(bool(over ["ok"]), "a deck %.0f m over the crown: %s"
			% [up, "ok" if bool(over ["ok"]) else str(over ["reason"])])
	var on_floor: Dictionary = tool._evaluate_deck(floor_at, Vector2(4.0, 4.0))
	_ok(not (str(on_floor ["reason"]) in ["in the hay", "stand it on the floor"]),
		"a deck on the floor is not refused for hay: %s" % on_floor ["reason"])

	for spot: Array in [[crown, true], [floor_at, false]]:
		var at: Vector3 = spot [0]
		var refused: bool = spot [1]
		var where:= "the crown" if refused else "the floor"
		_ok((tool._evaluate_cabinet(at, Vector3.BACK, Vector3.UP) ["reason"] as String
			== "stand it on the floor") == refused,
			"a cabinet on %s: %s" % [where,
				tool._evaluate_cabinet(at, Vector3.BACK, Vector3.UP) ["reason"]])
		_ok((tool._evaluate_pole(at, Vector3.UP) ["reason"] as String
			== "stand it on the floor") == refused,
			"a pole on %s: %s" % [where,
				tool._evaluate_pole(at, Vector3.UP) ["reason"]])
		_ok((tool._evaluate_drone(at, Vector3.UP) ["reason"] as String
			== "stand it on the floor") == refused,
			"a drone on %s: %s" % [where,
				tool._evaluate_drone(at, Vector3.UP) ["reason"]])
		var arm_price: float = world.builds.arm_price(tool._arm_tier)
		_ok((tool._evaluate_arm(at, Vector3.UP, arm_price, 1.0) ["reason"] as String
			== "stand it on the floor") == refused,
			"an arm on %s: %s" % [where,
				tool._evaluate_arm(at, Vector3.UP, arm_price, 1.0) ["reason"]])


func _strip() -> ControlHints:
	if world.hud == null:
		return null
	return world.hud.get_node_or_null("ControlHints") as ControlHints


func _strip_says(strip: ControlHints, text: String) -> bool:
	var rows: Array = strip.call("_hints")
	for row: PackedStringArray in rows:
		if row.size() >= 2 and row [1].contains(text):
			return true
	return false


func _wall_in_front() -> YardWall:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * TARGET_RANGE


	var across:= dir.cross(Vector3.UP).normalized() * (Cfg.WALL_PANEL * 0.5)
	var foot:= Vector3(at.x, player.global_position.y, at.z)
	var wall: YardWall = world.builds.add_wall(foot - across, foot + across,
		YardWall.Bay.SOLID)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(player.build.dismantle_target() == wall, "the ray is on the wall")
	return wall


func shoot(out_dir: String) -> void:
	world.block_save = true


	while Loading.is_active():
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout

	player._set_tool(Player.Tool.HAND)
	player.capture_mouse(true)
	GameState.add_money(20000.0)


	var arm:= await _arm_in_front()
	_press(true)


	await _wait_until(func() -> bool:
		return player.build.dismantle_progress() > 0.5)
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/dismantle_hold.png" % out_dir
	img.save_png(path)
	print("wrote %s" % path)

	_press(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var idle:= get_viewport().get_texture().get_image()
	var idle_path:= "%s/dismantle_idle.png" % out_dir
	idle.save_png(idle_path)
	print("wrote %s" % idle_path)
	if is_instance_valid(arm):
		world.builds.demolish(arm)
	get_tree().quit(0)


func _press(down: bool) -> void:
	for e in InputMap.action_get_events("dismantle"):
		var key:= e as InputEventKey
		if key == null:
			continue
		var ev:= key.duplicate() as InputEventKey
		ev.pressed = down
		Input.parse_input_event(ev)
		return
	_fails += 1
	print("  FAIL the dismantle action has no key bound to press")


func _wait_until(test: Callable) -> bool:
	var waited:= 0.0
	while waited < PATIENCE:
		if bool(test.call()):
			return true
		waited += get_process_delta_time()
		await get_tree().process_frame
	return false
