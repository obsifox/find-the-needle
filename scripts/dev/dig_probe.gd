class_name DevDigProbe
extends Node


const SPILL:= 40

var world: Node3D
var player: Player
var props: PropManager
var field: HayField


func run() -> void:
	var fails:= 0
	fails += _check_progression()
	fails += await _check_aim_pivot()
	fails += await _check_scoop_hint()
	fails += await _check_ground_pickup()
	fails += await _check_live_dig()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_progression() -> int:
	print("\n-- what each rank digs --")
	var bad:= 0
	var tools:= [
		{ "name": "toy shovel", "node": "toy_shovel_size", "base": SandShovel.SCOOP_MAX,
			"scale": Tech.toy_shovel_scale },
		{ "name": "spade", "node": "shovel_size", "base": Cfg.SCOOP_MAX,
			"scale": Tech.spade_scale },
		{ "name": "pitchfork", "node": "fork_size", "base": Pitchfork.SCOOP_MAX,
			"scale": Tech.fork_scale },
	]
	for tool: Dictionary in tools:
		var node:= str(tool ["node"])
		var line:= PackedStringArray()
		var prev:= 0
		for rank in range(TechTree.max_rank(node) + 1):
			Tech.reset()
			Tech.grant(node, rank)
			var scoop:= Tech.scoop_max(int(tool ["base"]),
				float((tool ["scale"] as Callable).call()))
			line.append("r%d %d" % [rank, scoop])
			if rank > 0 and scoop <= prev:
				bad += _fail("%s at rank %d lifts no more than rank %d"
					% [tool ["name"], rank, rank - 1])
			prev = scoop
		print("  %-11s %s" % [tool ["name"], "   ".join(line)])
	Tech.reset()
	return bad


func _check_aim_pivot() -> int:
	print("\n-- what the aim gesture turns each tool about --")
	var bad:= 0
	if player == null or player.shovel == null or player.pitchfork == null:
		return _fail("no tools to aim")


	var was_mode:= Cfg.tool_mode
	Cfg.tool_mode = Cfg.TOOL_ADVANCED
	Tech.reset()
	for tool: Array in [["spade", Player.Tool.SHOVEL, Vector3.ZERO],
			["pitchfork", Player.Tool.PITCHFORK, Pitchfork.PIVOT]]:
		var name:= str(tool [0])
		Tech.grant(name, 1)
		GameState.grant_tool(name)
		player._set_tool(tool [1] as Player.Tool)
		var rig: Shovel = player.shovel if tool [1] == Player.Tool.SHOVEL else player.pitchfork
		rig.reset_aim()


		for i in 90:
			await get_tree().physics_frame


		var head: Vector3 = tool [2]
		var rest:= rig.body.global_transform * head
		var worst:= 0.0
		for step: Vector2 in [Vector2(0, 220), Vector2(0, -180), Vector2(200, 0),
				Vector2(-260, 90), Vector2(120, -240)]:
			rig.reset_aim()
			rig.aim_input(step)
			for i in 4:
				await get_tree().physics_frame
			worst = maxf(worst, (rig.body.global_transform * head).distance_to(rest))
		rig.reset_aim()
		print("  %-11s the metal moves at most %.3f m across the whole aim range"
			% [name, worst])


		if worst > 0.01:
			bad += _fail("aiming the %s swings its working end %.3f m"
				% [name, worst])
	player._set_tool(Player.Tool.HAND)
	Tech.reset()
	Cfg.tool_mode = was_mode
	return bad


func _check_scoop_hint() -> int:
	print("\n-- the dig prompt follows the blade --")
	var bad:= 0
	if player == null:
		return _fail("no player to aim")
	Tech.reset()
	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)

	player.global_position = Vector3(13.0, 0.4, 2.0)
	await _hold_pitch(-0.9)
	if not _hint_says("Scoop"):
		bad += _fail("a blade pointed at the floor does not offer the dig")
	await _hold_pitch(1.3)
	if _hint_says("Scoop"):
		bad += _fail("a blade pointed at the sky offers a dig that does nothing")
	else:
		print("  the row comes and goes with the patch")
	player._set_tool(Player.Tool.HAND)
	Tech.reset()
	return bad


func _hold_pitch(pitch: float) -> void:
	var start:= Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 150:
		player.head.rotation.x = pitch
		await get_tree().process_frame


func _hint_says(text: String) -> bool:
	var hud: Hud = world.get("hud") as Hud
	if hud == null or hud._hints == null:
		return false
	for row: PackedStringArray in hud._hints._hints():
		for cell in row:
			if cell.findn(text) >= 0:
				return true
	return false


func _check_ground_pickup() -> int:
	print("\n-- picking spilled hay up off the floor --")
	var bad:= 0
	if player == null or player.shovel == null or world == null:
		return _fail("no spade to gather with")
	var live: LiveStrandManager = world.live
	if live == null:
		return _fail("no strand manager")

	Tech.reset()


	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)
	player.shovel.reset_aim()
	for i in 10:
		await get_tree().physics_frame


	var at:= player.global_position - player.global_transform.basis.z * 1.2
	at.y = 0.15
	var rng:= RandomNumberGenerator.new()
	rng.seed = 1312
	var dropped: Array [RigidBody3D] = []
	for i in SPILL:
		var jitter:= Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * 0.05,
			rng.randf_range(-0.25, 0.25))
		var b:= live.spawn(at + jitter, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
		if b != null:
			dropped.append(b)
	for i in 30:
		await get_tree().physics_frame
	if dropped.is_empty():
		return _fail("nothing would spawn to pick up")

	var ledger:= GameState.hay_total
	var g:= player.shovel.pan_geometry()
	var took:= player.shovel.gather_at(at, int(g ["max"]), float(g ["radius"]),
		g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]))
	for i in 45:
		await get_tree().physics_frame

	print("  dropped %d on the slab, the blade took %d" % [dropped.size(), took])
	if took <= 0:
		bad += _fail("a blade aimed at spilled hay picked up none of it")

	if not is_equal_approx(GameState.hay_total, ledger):
		bad += _fail("picking hay up changed the ledger by %.1f -- it was debited when it spilled"
			% (GameState.hay_total - ledger))

	var carried:= player.shovel.carried_strands()
	print("  and is carrying %d of them" % carried)
	if carried <= 0:
		bad += _fail("the hay was moved to the pan and the pan is not holding it")


	var again:= player.shovel.gather_at(at, int(g ["max"]), float(g ["radius"]),
		g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]))
	if again > 0:
		bad += _fail("a second sweep re-took %d strands already on the blade" % again)
	else:
		print("  a second sweep over the same patch takes nothing already held")

	for b in dropped:
		if is_instance_valid(b) and b.is_inside_tree():
			live.set_protected(b, false)
	player.shovel.set_active(false)
	Tech.reset()
	return bad


func _check_live_dig() -> int:
	print("\n-- a real dig --")
	var bad:= 0
	if player == null or player.shovel == null or props == null:
		return _fail("no spade to dig with")
	Tech.reset()

	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	Tech.grant("shovel_size", 3)

	var before:= props.count_of("hay_wad")


	var scoop:= Tech.scoop_max(Cfg.SCOOP_MAX, Tech.spade_scale())
	print("  the pile holds %.0f strands" % GameState.hay_total)


	var took:= 0
	var at:= Cfg.PILE_CENTER
	for step in 12:
		var angle:= float(step) * 1.0472
		var ring:= 1.5 + float(step) * 0.6
		at = Cfg.PILE_CENTER + Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)
		if field != null:
			at.y = field.height_at(at.x, at.z) - 0.05
		took = player.shovel.scoop_at(at, scoop, Cfg.SCOOP_RADIUS * Tech.spade_scale(),
			Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.5))
		if took > 0:
			break
	await get_tree().physics_frame
	var made:= props.count_of("hay_wad") - before
	print("  spade at rank 3 dug %d strands and stood up %d balls" % [took, made])
	if took <= 0:
		print("        nothing was lit to dig -- headless draws no crust.")
		print("        run: godot --path . -- --digshot captures/tech")
		return bad


	if made != 0:
		bad += _fail("a spade at rank 3 bundled %d balls -- no hand tool should"
			% made)
	return bad
