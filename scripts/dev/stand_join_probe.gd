class_name DevStandJoinProbe
extends Node


const SETTLE:= 40
const TIMEOUT:= 14.0

const QUIET_FOR:= 1.0
const STRAND_COUNT:= 24
const STRAND_SPACING:= 0.12

const RUN_LENGTH:= 5.0

var world: Node3D
var player: Player
var props: PropManager
var live: LiveStrandManager

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func shoot(out_dir: String) -> void:
	call_deferred("_shoot", out_dir)


func _run() -> void:
	world.block_save = true
	for i in SETTLE:
		await get_tree().process_frame
	var tool: BuildTool = player.build
	var builds: BuildManager = world.builds
	var stand: HaySellingStand = world.stand
	GameState.add_money(100000.0)
	tool.set_active(false)
	tool._mode = BuildTool.Mode.CONVEYOR

	var port:= stand.belt_entry_point()
	var along:= stand.intake_forward()
	print("  port %.3v  intake forward %.3v" % [port, along])

	print("\n=== the port ===")
	var near:= port - along * 0.5 + Vector3.UP * 0.09
	_check("an aim half a metre short snaps onto the pulley",
		builds.snap_endpoint(near).is_equal_approx(port))
	var far:= port - along * (Cfg.STAND_SNAP_RADIUS + 0.4)
	_check("an aim past the radius is left alone",
		builds.snap_endpoint(far).is_equal_approx(far))
	_check("the port carries the intake's bearing",
		builds.port_bearing_at(port).dot(along) > 0.999)
	await _crosshair_case(tool, stand, port, along)

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var from:= port - along * RUN_LENGTH
	from.y = lift

	print("\n=== a run arriving at an angle ===")
	var side:= along.cross(Vector3.UP).normalized()
	var slant_from:= port - along * 3.5 + side * 3.0
	slant_from.y = lift
	var slant:= tool._preview_points(slant_from, port)
	var last_leg:= (slant [slant.size() - 1] - slant [slant.size() - 2]).normalized()
	_check("the hologram bends onto the belt's line before the pulley (%.4f)"
		% last_leg.dot(along), last_leg.dot(along) > 0.99)

	print("\n=== a run laid straight in ===")
	var verdict:= tool._evaluate(from, port, true)
	_check("the run is green%s" % ("" if bool(verdict ["ok"])
		else "  (%s: %s)" % [verdict ["reason"], _blocker_name(tool, from, port)]),
		bool(verdict ["ok"]))
	var before:= builds.conveyors.size()
	tool._lay_run(from, port)
	for i in 4:
		await get_tree().physics_frame
	_check("one run laid", builds.conveyors.size() - before == 1)
	var run:= builds.feed_run_into(port)
	_check("it ends on the pulley", run != null)
	if run == null:
		_finish()
		return
	_check("and hands on to the stand's own belt",
		run.downstream == stand.intake_path())
	var taken:= tool._joint_taken(port, false)
	_check("a second run into the pulley is refused (%s)" % taken, taken != "")

	print("\n=== a wad rides across ===")
	await _wait_for_quiet()
	var at:= run.a + run.forward * 1.0 + Vector3.UP * 0.35
	var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at),
		{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
	if wad == null:
		_check("a wad could be spawned", false)
	else:
		var want:= wad.sale_strands() * Tech.hay_price()
		var paid:= await _takings()
		print("  paid $%.2f of $%.2f" % [paid, want])
		_check("the whole wad is paid for", is_equal_approx(paid, want))

	print("\n=== loose strands ride across ===")
	await _wait_for_quiet()
	var made:= 0
	var bodies: Array [RigidBody3D] = []
	for i in STRAND_COUNT:
		var spot:= run.a + run.forward * (0.6 + float(i) * STRAND_SPACING) + Vector3.UP * 0.12
		var body:= live.spawn(spot, Basis.IDENTITY, Vector3.ZERO, Color.WHITE)
		if body != null:
			made += 1
			bodies.append(body)
	var start_money:= GameState.money
	for i in 30:
		await get_tree().physics_frame
	_check("all of them are riding half a second in (%d of %d)"
		% [_riding(bodies), made], _riding(bodies) == made)


	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var waited:= 0.0
	while waited < TIMEOUT * 2.0 and _riding(bodies) > 0:
		await get_tree().physics_frame
		waited += step
	await _wait_for_quiet()
	var sold:= roundi((GameState.money - start_money) / maxf(Tech.hay_price(), 0.0001))
	print("  %d strands in, %d sold, %.1f s" % [made, sold, waited])
	for b in bodies:
		if is_instance_valid(b) and b.is_inside_tree() and BeltPath.is_rider(b):
			print("    still riding at %.2v" % b.global_position)
	_check("every strand is sold", made > 0 and sold == made)

	_finish()


func _crosshair_case(tool: BuildTool, stand: HaySellingStand, port: Vector3,
		along: Vector3) -> void:
	var floor_aim:= port - along * 0.45
	floor_aim.y = 0.0
	var stood:= port - along * 3.2
	stood.y = 0.0
	player.global_position = stood
	for i in 4:
		_aim(floor_aim)
		await get_tree().physics_frame
	var clicked:= tool._aim_point()
	_check("the crosshair's point is the pulley (%.3v, %.2f m off)"
		% [clicked, clicked.distance_to(port)], clicked.is_equal_approx(port))


	player.global_position = port - along.cross(Vector3.UP).normalized() * 4.0 - along * 2.0
	for i in 4:
		await get_tree().physics_frame


func _shoot(out_dir: String) -> void:
	world.block_save = true
	for i in SETTLE:
		await get_tree().process_frame
	var builds: BuildManager = world.builds
	var stand: HaySellingStand = world.stand
	var tool: BuildTool = player.build
	GameState.add_money(100000.0)
	var port:= stand.belt_entry_point()
	var along:= stand.intake_forward()
	var side:= along.cross(Vector3.UP).normalized()
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var from:= port - along * RUN_LENGTH
	from.y = lift
	tool._lay_run(from, port)
	for i in 20:
		await get_tree().process_frame
	var run:= builds.feed_run_into(port)
	print("[standjoin] run %s  downstream is the intake: %s" % [run,
		run != null and run.downstream == stand.intake_path()])

	await _look(out_dir, "stand_join_side.png",
		port - along * 1.1 + side * 1.6, port + along * 0.2)
	await _look(out_dir, "stand_join_over.png",
		port - along * 1.6 + side * 0.4 + Vector3.UP * 0.6, port + along * 0.6)
	await _look(out_dir, "stand_join_wide.png",
		port - along * 6.5 + side * 3.2, port + along * 1.5)


	var head:= stand.to_global(stand._belt_head)
	await _look(out_dir, "stand_belt_whole.png",
		port + along * 2.1 + side * 4.2, port + along * 2.1 + Vector3.UP * 0.4)
	await _look(out_dir, "stand_belt_head.png",
		head - along * 0.6 + side * 2.0 - Vector3.UP * head.y, head + along * 0.3 - Vector3.UP * 0.25)

	if run != null:
		for i in 3:
			props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
				run.a + run.forward * (2.2 + 0.9 * float(i)) + Vector3.UP * 0.35),
				{ "strands": Cfg.WAD_MAX_STRANDS })

		var eta:= (RUN_LENGTH - 2.2) / maxf(run.drive_speed, 0.1)
		var t:= 0.0
		while t < eta:
			await get_tree().physics_frame
			t += 1.0 / float(Engine.get_physics_ticks_per_second())
		await _look(out_dir, "stand_join_hay.png",
			port - along * 1.1 + side * 1.6, port + along * 0.2)
	get_tree().quit(0)


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	_aim(target)
	for i in 6:
		await get_tree().process_frame
	player.global_position = at
	_aim(target)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


func _aim(target: Vector3) -> void:
	var to_target:= target - player.eye_position()
	player.set_look(atan2(- to_target.x, - to_target.z),
		atan2(to_target.y, Vector2(to_target.x, to_target.z).length()))


func _wait_for_quiet() -> void:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var still:= 0.0
	var spent:= 0.0
	var last:= GameState.money
	while still < QUIET_FOR and spent < TIMEOUT:
		await get_tree().physics_frame
		spent += step
		if is_equal_approx(GameState.money, last):
			still += step
		else:
			still = 0.0
			last = GameState.money


func _takings() -> float:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var before:= GameState.money
	var waited:= 0.0
	while waited < TIMEOUT and GameState.money <= before:
		await get_tree().physics_frame
		waited += step
	var quiet:= 0.0
	var last:= GameState.money
	while waited < TIMEOUT and quiet < QUIET_FOR:
		await get_tree().physics_frame
		waited += step
		if is_equal_approx(GameState.money, last):
			quiet += step
		else:
			quiet = 0.0
			last = GameState.money
	return GameState.money - before


static func _riding(bodies: Array [RigidBody3D]) -> int:
	var n:= 0
	for b in bodies:
		if is_instance_valid(b) and b.is_inside_tree() and BeltPath.is_rider(b):
			n += 1
	return n


static func _blocker_name(tool: BuildTool, from: Vector3, to: Vector3) -> String:
	var hit:= tool._obstruction(from, to, from.distance_to(to)) as Node
	return str(hit.get_path()) if hit != null else "no body"


func _finish() -> void:
	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, good: bool) -> void:
	if not good:
		_fails += 1
	print("  %-4s %s" % ["ok" if good else "BAD", label])
