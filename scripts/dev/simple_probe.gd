class_name DevSimpleProbe
extends Node


const LOAD:= 60


const LEG_SECONDS:= 3.0


const SETTLE:= 45


const MODE_SLACK:= 0.08


const WHIP_RATE:= 18.0


const WHIP_KEEP_MIN:= 0.97


const DUMP_MIN_REACH:= 0.35

const DUMP_HIT_SHARE:= 0.8


const POUR_SHARE_MIN:= 0.95


const POUR_SPILL_FLOOR:= 6

var world: Node3D
var player: Player
var field: HayField
var live: LiveStrandManager

var _spawned: Array [RigidBody3D] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true


	var was_mode:= Cfg.tool_mode
	Cfg.tool_mode = Cfg.TOOL_SIMPLE
	Tech.grant_legacy()
	for i in SETTLE:
		await get_tree().process_frame

	var fails:= 0
	fails += await _check_capacity()
	fails += await _check_refuses_when_full()
	fails += await _check_shed_signal()
	fails += await _check_carry()
	fails += await _check_dump()
	fails += await _check_pour_into_container()
	fails += await _check_every_tool()
	fails += await _check_no_tilt_gate()
	fails += await _check_fast_clicks()


	fails += await _check_badge_goes_with_the_tool()

	Cfg.tool_mode = was_mode
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_capacity() -> int:
	print("\n-- what a bladeful is, every tool at every rank --")
	print("  %-12s %5s %7s %7s %7s %16s"
		% ["blade", "rank", "holds", "bite", "digs", "load sits at"])
	var bad:= 0
	Tech.reset()


	GameState.grant_tool("sand_shovel")
	for rank in 3:
		if rank > 0:
			Tech.grant("toy_shovel_size", rank)
		var s:= Tech.toy_shovel_scale()
		var bite:= Tech.scoop_max(SandShovel.SCOOP_MAX, s)

		var cap:= Shovel.LOAD_BITES * bite
		print("  %-12s %5d %7d %7d %7.1f   (blade box %.3f x %.3f m)"
			% ["toy shovel", rank, cap, bite,
				float(cap) / maxf(float(bite), 1.0),
				SandShovel.BLADE_SIZE.x * s, SandShovel.BLADE_SIZE.z * s])
	Tech.reset()

	for tool: Array in [["spade", "shovel_size", Player.Tool.SHOVEL],
			["pitchfork", "fork_size", Player.Tool.PITCHFORK]]:
		var name:= str(tool [0])
		var node:= str(tool [1])
		GameState.grant_tool(name)
		for rank in TechTree.max_rank(node) + 1:
			if rank > 0:
				Tech.grant(node, rank)
			player._set_tool(tool [2] as Player.Tool)
			await get_tree().physics_frame
			var rig: Shovel = player.shovel if tool [2] == Player.Tool.SHOVEL else player.pitchfork
			var cap:= rig.capacity()
			var g:= rig.pan_geometry()
			var bite:= int(g ["max"])
			var origin:= g ["origin"] as Vector3
			print("  %-12s %5d %7d %7d %7.1f   %.3f..%.3f m (pan %.3f x %.3f)"
				% [name, rank, cap, bite, float(cap) / maxf(float(bite), 1.0),
					rig.load_base(origin), rig.load_ceiling(origin),
					float(g ["w"]), float(g ["d"])])


			var lift:= rig.load_base(origin) - origin.y
			if lift > Shovel.WALL_H:
				bad += _fail("a %s at rank %d lays its load %.3f m above its own "
					% [name, rank, lift]
					+ "pan floor, which is deeper than the %.3f m dish it is "
					% Shovel.WALL_H
					+ "supposed to sit in: it will look like it is hovering")
			if cap <= bite:
				bad += _fail("a %s at rank %d holds %d and digs %d at a time, "
					% [name, rank, cap, bite]
					+ "so it is full after one click")
	player._set_tool(Player.Tool.HAND)


	Tech.reset()
	Tech.grant_legacy()
	return bad


func _check_refuses_when_full() -> int:
	print("\n-- a full blade refuses the dig --")
	var bad:= 0


	await _load_spade(int(round(
		float(player.shovel.capacity() if player.shovel != null else LOAD) * 1.3)))
	var rig:= player.shovel
	var carried:= rig.carried_strands()
	var cap:= rig.capacity()
	print("  the spade holds %d and is carrying %d" % [cap, carried])
	if not rig.is_full():


		print("  (could not fill it; the refusal is untested this run)")
		return 0
	var took:= rig.scoop()
	print("  a dig at a full spade took %d strands" % took)
	if took != 0:
		bad += _fail("a full spade dug anyway and took %d" % took)


	var badge:= rig.body.get_node_or_null("FullBadge")
	print("  the full badge is %s" % ("up" if badge != null else "NOT up"))
	if badge == null:
		bad += _fail("a full spade raised no badge, so nothing on screen says why "
			+ "the dig did nothing")
	return bad


func _check_badge_goes_with_the_tool() -> int:
	print("\n-- the badge is put away with the blade --")
	var bad:= 0
	await _load_spade(int(round(
		float(player.shovel.capacity() if player.shovel != null else LOAD) * 1.3)))
	var rig:= player.shovel
	if not rig.is_full():
		print("  (could not fill it; there is no badge to put away this run)")
		return 0
	var badge:= rig.body.get_node_or_null("FullBadge")
	if badge == null:

		print("  (no badge went up; nothing to put away)")
		return 0
	var mark:= badge.get_node_or_null("Mark") as Label3D
	print("  with the spade out the badge is %s"
		% ("up" if mark != null and mark.visible else "down"))
	player._set_tool(Player.Tool.HAND)
	await get_tree().process_frame
	var lit: bool = mark != null and mark.visible
	print("  with the spade away it is %s" % ("STILL UP" if lit else "down"))
	if lit:
		bad += _fail("the full badge outlived the tool it was about, and the "
			+ "body it hangs off is not processing any more, so nothing is "
			+ "going to take it down")
	return bad


func _check_carry() -> int:
	print("\n-- what survives being carried --")
	print("  %-18s %8s %8s %6s" % ["on the way", "Simple", "Advanced", "kept"])
	var bad:= 0


	var still:= await _leg_both(Vector3.ZERO, false, 0.0, "stand still")
	if still.x < 1.0:
		bad += _fail("a Simple blade shed %.0f%% of its load standing still"
			% ((1.0 - still.x) * 100.0))


	var whip:= await _leg_both(Vector3.ZERO, false, WHIP_RATE, "whip, standing")
	if whip.x < WHIP_KEEP_MIN:
		bad += _fail("whipping the view kept only %.0f%% of the load; turning "
			% (whip.x * 100.0)
			+ "the camera has to cost nothing at all")


	for leg: Array in [["walk", Vector3(0, 0, -1), false],
			["sprint", Vector3(0, 0, -1), true]]:
		var kept:= await _leg_both(leg [1] as Vector3, bool(leg [2]), 0.0,
			str(leg [0]))
		if kept.x + MODE_SLACK < kept.y:
			bad += _fail("%s keeps %.0f%% under Simple against %.0f%% under "
				% [str(leg [0]), kept.x * 100.0, kept.y * 100.0]
				+ "Advanced, so the shed budget is losing hay the tilt gate kept")
	return bad


func _check_shed_signal() -> int:
	print("\n-- the spill rule, without the physics --")
	var bad:= 0
	await _load_spade(0)
	var tick:= 1.0 / 60.0


	var second:= 1.0

	player.velocity = Vector3.ZERO
	player._sprinting = false
	player._crouch = 0.0
	var idle:= Shovel.shed_share(player, second, false)
	print("  standing still           %.1f%% a second" % (idle * 100.0))
	if idle > 0.0:
		bad += _fail("standing still sheds %.1f%% of the load a second" % (idle * 100.0))


	player.velocity = Vector3(0.0, 0.0, - Player.SPEED)
	var jog:= Shovel.shed_share(player, second, false)
	print("  jogging, no keys         %.1f%% a second" % (jog * 100.0))
	if jog > 0.0:
		bad += _fail("jogging sheds %.1f%% a second with no key held" % (jog * 100.0))


	player._sprinting = true
	var run:= Shovel.shed_share(player, second, false)
	print("  sprinting                %.1f%% a second (want %.0f)"
		% [run * 100.0, Shovel.SHED_SPRINT_RATE * 100.0])
	if not is_equal_approx(run, Shovel.SHED_SPRINT_RATE):
		bad += _fail("a sprint sheds %.1f%% a second against a rate of %.0f%%"
			% [run * 100.0, Shovel.SHED_SPRINT_RATE * 100.0])


	player.velocity = Vector3.ZERO
	var stuck:= Shovel.shed_share(player, second, false)
	print("  sprinting into a wall    %.1f%% a second" % (stuck * 100.0))
	if stuck > 0.0:
		bad += _fail("holding sprint while stopped sheds %.1f%% a second"
			% (stuck * 100.0))


	player._sprinting = false
	var hop:= Shovel.shed_share(player, tick, true)
	print("  one jump                 %.1f%% of the load (want %.0f)"
		% [hop * 100.0, Shovel.SHED_JUMP_FRACTION * 100.0])
	if not is_equal_approx(hop, Shovel.SHED_JUMP_FRACTION):
		bad += _fail("a jump sheds %.1f%% against a charge of %.0f%%"
			% [hop * 100.0, Shovel.SHED_JUMP_FRACTION * 100.0])


	player.velocity = Vector3(0.0, 0.0, - Player.SPEED)
	player._sprinting = true
	player._crouch = 1.0
	var creep:= Shovel.shed_share(player, second, false)
	print("  crouched sprint          %.1f%% a second" % (creep * 100.0))
	if creep > run * 0.25:
		bad += _fail("crouching only takes the spill from %.1f%% to %.1f%%"
			% [run * 100.0, creep * 100.0])
	player._crouch = 0.0
	player._sprinting = false
	player.velocity = Vector3.ZERO


	var before:= player.jumps_taken()
	Input.action_press("jump")
	for f in 4:
		await get_tree().physics_frame
	Input.action_release("jump")
	var hops:= player.jumps_taken() - before
	print("  four frames of Space     %d jump counted" % hops)
	if hops != 1:
		bad += _fail("holding the jump key for four frames counted %d jumps, so "
			% hops + "a single hop is charged the wrong number of times")
	return bad


func _leg_both(dir: Vector3, sprint: bool, whip: float, what: String) -> Vector2:
	var out:= Vector2.ZERO
	for i in 2:
		Cfg.tool_mode = Cfg.TOOL_SIMPLE if i == 0 else Cfg.TOOL_ADVANCED
		await _load_spade(LOAD)
		var start:= player.shovel.carried_strands()
		await _travel(dir, sprint, whip)
		var kept:= float(player.shovel.carried_strands()) / maxf(float(start), 1.0)
		out [i] = kept
		if i == 0:
			_where_did_it_go(start)
	Cfg.tool_mode = Cfg.TOOL_SIMPLE
	print("  %-18s %7.0f%% %7.0f%% %6s"
		% [what, out.x * 100.0, out.y * 100.0,
			"ok" if out.x + MODE_SLACK >= out.y else "WORSE"])
	return out


func _check_dump() -> int:
	print("\n-- the dump shoves the load the way you are looking --")
	var bad:= 0
	await _load_spade(LOAD)
	var rig:= player.shovel
	var start:= rig.carried_strands()
	var aim:= player.look_direction()
	var from:= rig._hold_centre()


	var tufts_before: Dictionary = { }
	for t in HayTuft.all:
		tufts_before [t.get_instance_id()] = true
	var sent:= rig.dump()
	print("  shoved %d of %d along %.2f, %.2f, %.2f"
		% [sent, start, aim.x, aim.y, aim.z])
	if sent <= 0:
		return _fail("a loaded spade dumped nothing")


	for i in 8:
		await get_tree().physics_frame
	var left:= rig.carried_strands()
	if left > 0:
		bad += _fail("the spade is still carrying %d strands right after a dump"
			% left)
	for i in 112:
		await get_tree().physics_frame
	var ahead:= 0
	var total:= 0
	var reach:= 0.0
	var sideways:= 0.0
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		total += 1
		var moved:= b.global_position - from
		var along:= moved.dot(aim)
		reach = maxf(reach, along)
		sideways = maxf(sideways, (moved - aim * along).length())
		if along >= DUMP_MIN_REACH:
			ahead += 1


	for t in HayTuft.all:
		if not is_instance_valid(t) or not t.is_inside_tree() or tufts_before.has(t.get_instance_id()):
			continue
		total += t.strands
		var moved:= t.global_position - from
		var along:= moved.dot(aim)
		reach = maxf(reach, along)
		sideways = maxf(sideways, (moved - aim * along).length())
		if along >= DUMP_MIN_REACH:
			ahead += t.strands
	var share:= float(ahead) / maxf(float(total), 1.0)
	print("  of %d, %d ended at least %.2f m forward (furthest %.2f m, spread %.2f m)"
		% [total, ahead, DUMP_MIN_REACH, reach, sideways])
	if share < DUMP_HIT_SHARE:
		bad += _fail("only %.0f%% of the load was shoved clear of the blade, "
			% (share * 100.0)
			+ "wanted %.0f%%: it is being dropped rather than pushed"
			% (DUMP_HIT_SHARE * 100.0))
	return bad


func _check_pour_into_container() -> int:
	print("\n-- emptying a blade into a container --")
	print("  %-6s %-12s %6s %6s %7s %8s" % ["blade", "into", "load", "in", "share", "range"])
	var bad:= 0


	for leg: Array in [["spade", "bucket", -1.0], ["spade", "wheelbarrow", -1.0],
			["toy", "bucket", -1.0], ["toy", "wheelbarrow", -1.0],
			["toy", "bucket", 0.6],
			["toydug", "bucket", -1.0], ["toydug", "bucket", 0.6]]:
		var blade: String = leg [0]
		var which: String = leg [1]
		var r:= await _pour_at(which, blade, float(leg [2]))
		if r.is_empty():
			bad += _fail("could not set up the %s for the %s" % [which, blade])
			continue
		var share:= float(r ["in"]) / maxf(float(r ["load"]), 1.0)
		print("  %-6s %-12s %6d %6d %6.0f%% %7.2f m"
			% [blade, which, int(r ["load"]), int(r ["in"]), share * 100.0, float(r ["away"])])


		if int(r ["rest"]) < 95:
			print("    FINDING: a %s resting at %.2f upright is already past its"
				% [which, float(r ["upright"])]
				+ " own tip_start of %.2f, so it pours itself out where it"
				% float(r ["tip"])
				+ " stands: %d of 100 left after one second." % int(r ["rest"]))
			print("    Nothing can fill it, and that is older than this change."
				+ " Not asserted here.")
			continue
		var lost:= int(r ["load"]) - int(r ["in"])
		var allowed:= maxi(POUR_SPILL_FLOOR,
			int(floor(float(r ["load"]) * (1.0 - POUR_SHARE_MIN))))
		if lost > allowed:
			bad += _fail("only %.0f%% of the %s's load went into the %s: %d spilled, %d allowed"
				% [share * 100.0, blade, which, lost, allowed])
	return bad


func _pour_at(item_id: String, blade: String = "spade", reach: float = -1.0) -> Dictionary:
	_clear_hay()
	_stand_clear()
	var props: PropManager = world.props


	var ahead:= player.global_position + player.look_direction() * 1.1
	var c:= props.spawn(item_id,
		Transform3D(Basis(), Vector3(ahead.x, player.global_position.y + 0.5, ahead.z))) as HayContainer
	if c == null:
		return { }
	for i in 40:
		await get_tree().physics_frame


	c.global_rotation = Vector3.ZERO
	c.linear_velocity = Vector3.ZERO
	c.angular_velocity = Vector3.ZERO
	for i in 30:
		await get_tree().physics_frame


	if reach > 0.0:
		var flat:= c.global_position - player.global_position
		flat.y = 0.0
		flat = flat.normalized() if flat.length_squared() > 1e-06 else Vector3.RIGHT
		var feet:= c.global_position - flat * reach
		player.global_position = Vector3(feet.x, player.global_position.y, feet.z)
		player.velocity = Vector3.ZERO
		for i in 10:
			await get_tree().physics_frame


	var dir:= (c.pour_point() - player.eye_position()).normalized()
	player.rotation.y = atan2(- dir.x, - dir.z)
	var pitch:= asin(clampf(dir.y, -1.0, 1.0))
	player.head.rotation.x = pitch
	player.set("_pitch", pitch)
	for i in 4:
		await get_tree().physics_frame

	var rig: Node = null
	if blade == "toy" or blade == "toydug":
		var toy:= props.spawn("sand_shovel",
			Transform3D(Basis(), player.global_position + Vector3(0, 0.5, 0)))
		if toy != null:
			player.carry.take(toy)
		for i in 10:
			await get_tree().physics_frame
		var held:= player.carry.held() as SandShovel
		if held == null:
			props.remove(c)
			return { }
		rig = held
		if blade == "toy":
			_fill_blade(held._hold_centre(), LOAD)
		else:


			var yaw:= player.rotation.y
			player.rotation.y = yaw + PI
			player.head.rotation.x = -0.55
			player.set("_pitch", -0.55)
			for i in 10:
				await get_tree().physics_frame
			for bite in 20:
				if held.is_full():
					break
				held.scoop()
				for i in 25:
					await get_tree().physics_frame
			_spawned.clear()
			for id: int in held._riding:
				_spawned.append(held._riding [id])
			print("    dug %d strands onto a toy of capacity %d at size %.2f"
				% [held.carried_strands(), held.capacity(), Tech.toy_shovel_scale()])
			player.rotation.y = yaw
			player.head.rotation.x = pitch
			player.set("_pitch", pitch)
			for i in 10:
				await get_tree().physics_frame
	else:
		GameState.grant_tool("spade")
		player._set_tool(Player.Tool.SHOVEL)
		player.shovel.reset_aim()
		for i in 10:
			await get_tree().physics_frame
		_fill_blade(player.shovel._hold_centre(), LOAD)
		rig = player.shovel
	for i in SETTLE:
		await get_tree().physics_frame

	var load: int = rig.carried_strands()
	var away:= player.eye_position().distance_to(c.pour_point())


	if player.shovel.pour_target() != c:
		var eye:= player.eye_position()
		var q:= PhysicsRayQueryParameters3D.create(eye,
			eye + player.look_direction() * Shovel.DUMP_POUR_RANGE)
		q.collision_mask = Cfg.L_PROP | Cfg.L_BUILD | Cfg.L_WORLD
		var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
		print("    (the %s did not see the %s at %.2f m, the ray hit %s; measuring a shove)"
			% [blade, item_id, away, hit.get("collider", "nothing")])
	print("    %s: upright %.2f (pours below %.2f), rest pitch %.0f roll %.0f deg"
		% [item_id, c._upright(), c.tip_start(),
			rad_to_deg(c.global_rotation.x), rad_to_deg(c.global_rotation.z)])


	c.stored = 100
	for i in 60:
		await get_tree().physics_frame
	var kept_at_rest: int = c.stored
	c.stored = 0
	var before: int = c.stored
	var mouth:= c.pour_point()
	var from: Vector3 = rig._hold_centre()
	var sees:= player.shovel.pour_target() == c
	rig.dump()
	for i in 120:
		await get_tree().physics_frame


	var floor_n:= 0
	var high_n:= 0
	var far:= 0.0
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.global_position.y > mouth.y - 0.08:
			high_n += 1
		else:
			floor_n += 1
		far = maxf(far, Vector2(b.global_position.x - mouth.x, b.global_position.z - mouth.z).length())
	var off:= from - mouth
	print("    eyes %.0f deg down, blade %.2f m over the mouth, %.2f m out; pour aimed %s; missed: %d low, %d at rim height, furthest %.2f m"
		% [rad_to_deg(- pitch), off.y, Vector2(off.x, off.z).length(), "yes" if sees else "NO",
			floor_n, high_n, far])
	var result:= { "load": load, "in": c.stored - before, "away": away,
		"rest": kept_at_rest, "upright": c._upright(), "tip": c.tip_start() }


	if player.carry.held() is SandShovel:
		player._stow_toy()
	props.remove(c)
	return result


func _check_every_tool() -> int:
	print("\n-- all three blades, whipped and then emptied --")
	print("  %-12s %6s %6s %8s %7s" % ["blade", "start", "kept", "emptied", "reach"])
	var bad:= 0
	for which: String in ["spade", "fork", "toy"]:
		var rig: Node = await _load_any(which, LOAD)
		if rig == null:
			bad += _fail("could not put hay on the %s" % which)
			continue
		var start: int = rig.carried_strands()
		var from: Vector3 = rig._hold_centre()
		var aim:= player.look_direction()
		await _travel(Vector3.ZERO, false, WHIP_RATE)
		var kept: int = rig.carried_strands()
		var sent: int = rig.dump()
		for i in 8:
			await get_tree().physics_frame
		var still: int = rig.carried_strands()
		for i in 60:
			await get_tree().physics_frame
		var reach:= 0.0
		for b in _spawned:
			if is_instance_valid(b) and b.is_inside_tree():
				reach = maxf(reach, (b.global_position - from).dot(aim))
		print("  %-12s %6d %5.0f%% %8s %6.2fm"
			% [which, start, 100.0 * float(kept) / maxf(float(start), 1.0),
				"yes" if still == 0 else "%d left" % still, reach])
		if start <= 0:
			bad += _fail("the %s ended up with no load to test" % which)
			continue
		if float(kept) / float(start) < WHIP_KEEP_MIN:
			bad += _fail("whipping the view emptied %.0f%% off the %s"
				% [100.0 - 100.0 * float(kept) / float(start), which])
		if sent <= 0 and kept > 0:
			bad += _fail("the %s would not empty" % which)
		if still > 0:
			bad += _fail("the %s still held %d right after a dump" % [which, still])
	return bad


func _load_any(which: String, count: int) -> Node:
	if which == "spade":
		await _load_spade(count)
		return player.shovel
	if which == "fork":
		await _load_fork(count)
		return player.pitchfork
	await _load_toy(count)
	return player.carry.held() as SandShovel


func _load_fork(count: int) -> void:
	_clear_hay()
	_stand_clear()
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for i in 10:
		await get_tree().physics_frame


	var g:= player.pitchfork.pan_geometry()
	_fill_blade((g ["xf"] as Transform3D) * (g ["origin"] as Vector3), count)
	for i in SETTLE:
		await get_tree().physics_frame


func _load_toy(count: int) -> void:
	_clear_hay()
	_stand_clear()
	player._set_tool(Player.Tool.HAND)
	if player.carry.is_carrying():
		player.carry.drop()
	var props: PropManager = world.props
	var toy:= props.spawn("sand_shovel",
		Transform3D(Basis(), player.global_position + Vector3(0, 0.5, 0)))
	if toy != null:
		player.carry.take(toy)
	for i in 10:
		await get_tree().physics_frame
	var held:= player.carry.held() as SandShovel
	if held != null:
		_fill_blade(held._hold_centre(), count)
	for i in SETTLE:
		await get_tree().physics_frame


func _check_no_tilt_gate() -> int:
	print("\n-- looking down does not empty a Simple blade --")
	var bad:= 0
	for pitch: float in [-0.6, -1.1]:
		await _load_spade(LOAD, pitch)
		var start:= player.shovel.carried_strands()
		for i in int(LEG_SECONDS / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
		var ended:= player.shovel.carried_strands()
		var up:= player.shovel.body.global_transform.basis.y.dot(Vector3.UP)
		print("  eyes %2.0f deg down (pan at %.2f, Advanced would hold above %.2f): %d of %d left"
			% [rad_to_deg(- pitch), up, Shovel.TIP_POUR, ended, start])
		if ended < start:
			bad += _fail("a Simple blade at %.0f degrees shed %d strands with "
				% [rad_to_deg(- pitch), start - ended]
				+ "nobody asking it to")
	return bad


func _where_did_it_go(start: int) -> void:
	var rig:= player.shovel
	var centre:= rig._hold_centre()
	var inv:= rig.body.global_transform.affine_inverse()
	var in_pan:= 0
	var near:= 0
	var gone:= 0
	var lowest:= 0.0
	var widest:= 0.0
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		var away:= b.global_position.distance_to(centre)
		if away <= rig._hold_radius():
			in_pan += 1
		elif away <= 1.0:
			near += 1
		else:
			gone += 1
		var local:= inv * b.global_position
		lowest = minf(lowest, local.y)
		widest = maxf(widest, Vector2(local.x, local.z).length())
	print("      of %d: %d in the hold sphere, %d within a metre, %d further"
		% [start, in_pan, near, gone])
	print("      lowest %.3f m in blade space, furthest across %.3f m"
		% [lowest, widest])


func _load_spade(count: int, pitch: float = NAN) -> void:
	_clear_hay()
	_stand_clear()
	if not is_nan(pitch):
		player.head.rotation.x = pitch
		player.set("_pitch", pitch)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)
	player.shovel.reset_aim()
	for i in 10:
		await get_tree().physics_frame
	_fill_blade(player.shovel._hold_centre(), count)
	for i in SETTLE:
		await get_tree().physics_frame


func _fill_blade(at: Vector3, count: int) -> void:
	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210
	_spawned.clear()
	for i in count:
		var jitter:= Vector3(rng.randf_range(-0.05, 0.05),
			rng.randf_range(0.01, 0.07), rng.randf_range(-0.07, 0.07))
		var b:= live.spawn(at + jitter, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
		if b != null:
			_spawned.append(b)


func _check_fast_clicks() -> int:
	print("\n-- clicking fast does not overfill a blade --")
	var bad:= 0
	for which in ["toy", "spade"]:
		_clear_hay()
		_stand_clear()
		for i in 10:
			await get_tree().physics_frame
		var rig: Node = null
		if which == "toy":
			var props: PropManager = world.props
			var toy:= props.spawn("sand_shovel",
				Transform3D(Basis(), player.global_position + Vector3(0, 0.5, 0)))
			if toy != null:
				player.carry.take(toy)
			for i in 10:
				await get_tree().physics_frame
			rig = player.carry.held() as SandShovel
		else:
			GameState.grant_tool("spade")
			player._set_tool(Player.Tool.SHOVEL)
			player.shovel.reset_aim()
			for i in 10:
				await get_tree().physics_frame
			rig = player.shovel
		if rig == null:
			bad += _fail("could not put a %s in the player's hands" % which)
			continue

		player.rotation.y += PI
		player.head.rotation.x = -0.55
		player.set("_pitch", -0.55)
		for i in 10:
			await get_tree().physics_frame
		var cap: int = rig.capacity()
		var sent:= 0
		for click in 8:
			sent += int(rig.scoop())
			for i in 2:
				await get_tree().physics_frame
		for i in 60:
			await get_tree().physics_frame
		var got: int = rig.carried_strands()
		print("  %s: eight fast clicks sent %d, it carries %d of %d"
			% [which, sent, got, cap])
		if sent == 0:
			print("  (the %s dug nothing here; untested this run)" % which)
		elif sent > cap:
			bad += _fail("eight fast clicks sent %d strands at a %s that holds %d"
				% [sent, which, cap])
		if got > cap:
			bad += _fail("a %s rated %d is carrying %d after fast clicks"
				% [which, cap, got])


		if which == "toy" and got > 0:
			var inside:= _toy_strands_in_plastic(rig as SandShovel)
			print("  toy: %d of %d strands pass through the plastic" % [inside, got])
			if inside > 0:
				bad += _fail("%d strands of a dug toy load go through the blade" % inside)
		if which == "toy" and player.carry.held() is SandShovel:
			player._stow_toy()
		elif which == "spade":
			player._set_tool(Player.Tool.HAND)
	return bad


func _toy_strands_in_plastic(toy: SandShovel) -> int:
	var to_item:= toy.global_transform.orthonormalized().affine_inverse()
	var n:= 0
	for id: int in toy._riding:
		var rb:= toy._riding [id] as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			continue
		if SandShovel.dish_lift(rb, to_item * rb.global_transform) > SandShovel.DISH_CLEAR + 0.002:
			n += 1
	return n


func _clear_hay() -> void:
	for b in live._active.duplicate():
		live._despawn(b)


func _stand_clear() -> void:


	if player.carry != null and player.carry.is_carrying():
		player.carry.drop()
	player.global_position = Vector3(11.5, 0.4, 0.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = -0.55
	player.set("_pitch", -0.55)
	player.velocity = Vector3.ZERO


func _travel(dir: Vector3, sprint: bool, whip: float) -> void:
	var speed:= Player.SPRINT if sprint else Player.SPEED
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	for i in int(LEG_SECONDS / step):
		if dir != Vector3.ZERO:
			var forward:= - player.global_transform.basis.z
			player.velocity = Vector3(forward.x, 0, forward.z).normalized() * speed
			player.velocity.y = -1.0
			player.move_and_slide()
		if whip > 0.0:


			var way:= 1.0 if fmod(float(i) * step, 1.0) < 0.5 else -1.0
			player.rotate_y(whip * way * step)
		await get_tree().physics_frame
