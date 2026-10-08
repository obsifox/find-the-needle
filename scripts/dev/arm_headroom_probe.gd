class_name DevArmHeadroomProbe
extends Node


var world: Node3D
var player: Player


const TARGET_ABOVE_SHOULDER:= 0.5

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	for i in 10:
		await get_tree().physics_frame
	await _measure()
	await _placement()
	print("\n[arm-headroom] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _measure() -> void:
	print("\n=== how high the boom climbs, by distance from the base ===")
	var builds: BuildManager = world.builds
	for tier in Cfg.ROBOT_ARM_TIERS.size():
		var at:= Vector3(40.0 + 12.0 * tier, 0.0, 40.0)
		var arm:= builds.add_robotic_arm(at, 0.0, tier)
		for i in 3:
			await get_tree().physics_frame
		arm.set_process(false)
		arm.set_physics_process(false)
		var scale:= arm.visual_scale()
		var boom:= arm.find_child("RA_ShoulderPitch", true, false) as Node3D
		if boom == null:
			_fail("tier %d has no RA_ShoulderPitch to measure" % tier)
			continue
		var meshes:= _meshes(boom)

		var reach:= arm.reach_m() * 0.98 / scale
		var top_y:= RoboticArm.SHOULDER_HEIGHT + TARGET_ABOVE_SHOULDER

		var ceiling: Array [float] = []
		ceiling.resize(24)
		ceiling.fill(0.0)
		var y:= -4.0
		while y <= top_y + 0.0001:
			var r:= 0.0
			while r <= reach:
				var d:= Vector2(r, y - RoboticArm.SHOULDER_HEIGHT).length()
				if d >= RoboticArm.MIN_REACH and d <= reach:
					arm._apply_angles(arm._solve_authored_target(Vector3(0.0, y, r)))
					for m in meshes:
						var box:= m.global_transform * m.get_aabb()
						var far:= 0.0
						for c in 8:
							var p:= box.get_endpoint(c) - at
							far = maxf(far, Vector2(p.x, p.z).length())
						var high:= (box.end.y - at.y) / scale
						var k:= mini(int(far / scale / 0.25), ceiling.size() - 1)
						for j in k + 1:
							ceiling [j] = maxf(ceiling [j], high)
				r += 0.1
			y += 0.1
		var line:= ""
		for j in ceiling.size():
			if ceiling [j] > 0.0:
				line += " %.2f:%.2f" % [j * 0.25, ceiling [j]]
		print("  tier %d (authored m, distance:top)%s" % [tier, line])
		for j in ceiling.size():
			var d:= j * 0.25
			var said:= RoboticArm.boom_ceiling(d)
			if ceiling [j] > said + 0.02:
				_fail("tier %d: the boom reaches %.2f m at %.2f m out, BOOM_CEILING says %.2f"
					% [tier, ceiling [j], d, said])


			var between:= RoboticArm.boom_ceiling(d + 0.125)
			if ceiling [j] > between + 0.02:
				_fail("tier %d: the boom reaches %.2f m at %.2f m out, BOOM_CEILING says %.2f"
					% [tier, ceiling [j], d + 0.125, between])
		builds.demolish(arm)
		await get_tree().physics_frame
	print("  ok    measured")


func _meshes(node: Node) -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	var mesh:= node as MeshInstance3D
	if mesh != null and mesh.visible and mesh.mesh != null:
		out.append(mesh)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


func _placement() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	GameState.money = maxf(GameState.money, 10000000.0)
	var tier:= 1
	var scale:= float(Cfg.ROBOT_ARM_TIERS [tier] ["scale"])
	var mast:= RoboticArm.AIM_HEIGHT * scale
	var boom:= RoboticArm.boom_ceiling(1.0) * scale
	var base:= Vector3(-30.0, _floor_y(Vector3(-30.0, 0.0, 30.0)), 30.0)
	tool._arm_tier = tier

	print("\n=== a deck over an arm that is already standing ===")
	var arm:= builds.add_robotic_arm(base, 0.0, tier)
	for i in 3:
		await get_tree().physics_frame
	_refused("a deck at the screenshot's height, over the arm",
		tool._evaluate_deck(base + Vector3(0.0, 1.8, 0.0), Vector2(4.0, 4.0)))
	_refused("a deck through the mast",
		tool._evaluate_deck(base + Vector3(0.0, mast - 0.5, 0.0), Vector2(4.0, 4.0)))
	_allowed("a deck clear of the mast",
		tool._evaluate_deck(base + Vector3(0.0, mast + Cfg.PLATFORM_THICK + 0.1, 0.0),
			Vector2(4.0, 4.0)))

	_refused("a deck beside it, in the boom's swing",
		tool._evaluate_deck(base + Vector3(3.0, boom - 0.3, 0.0), Vector2(4.0, 4.0)))
	_allowed("the same deck lifted over the swing",
		tool._evaluate_deck(base + Vector3(3.0, boom + Cfg.PLATFORM_THICK + 0.1, 0.0),
			Vector2(4.0, 4.0)))


	var edge:= 3.3 * scale
	var between:= (RoboticArm.boom_ceiling(3.25) + RoboticArm.boom_ceiling(3.5)) * 0.5 * scale
	_refused("a deck between two rows of the swing, under the nearer one",
		tool._evaluate_deck(base + Vector3(edge + 2.0, between + Cfg.PLATFORM_THICK, 0.0),
			Vector2(4.0, 4.0)))
	_allowed("a deck at belt height beside it, which it works onto",
		tool._evaluate_deck(base + Vector3(3.0, 0.9, 0.0), Vector2(4.0, 4.0)))
	_allowed("a deck out past its reach",
		tool._evaluate_deck(base + Vector3(8.0, 1.8, 0.0), Vector2(4.0, 4.0)))
	builds.demolish(arm)
	await get_tree().physics_frame

	print("\n=== an arm under a deck that is already standing ===")
	var low:= builds.add_platform(base + Vector3(0.0, 1.8, 0.0), Vector2(4.0, 4.0))
	for i in 3:
		await get_tree().physics_frame
	_refused("an arm under a low deck",
		tool._evaluate_arm(base, Vector3.UP, 0.0, scale))
	_refused("an arm beside a low deck, swinging under it",
		tool._evaluate_arm(base + Vector3(-3.0, 0.0, 0.0), Vector3.UP, 0.0, scale))
	_allowed("an arm well clear of it",
		tool._evaluate_arm(base + Vector3(-8.0, 0.0, 0.0), Vector3.UP, 0.0, scale))
	builds.demolish(low)
	var high:= builds.add_platform(
		base + Vector3(0.0, mast + Cfg.PLATFORM_THICK + 0.1, 0.0), Vector2(4.0, 4.0))
	for i in 3:
		await get_tree().physics_frame
	_allowed("an arm under a deck high enough to clear the mast",
		tool._evaluate_arm(base, Vector3.UP, 0.0, scale))

	print("\n=== two arms, one each side of that deck ===")
	var under:= builds.add_robotic_arm(base, 0.0, tier)
	for i in 3:
		await get_tree().physics_frame
	_is("an arm on the deck over it does not fight it",
		builds.arm_reach_conflict(base + Vector3(1.0, high.top_y() - base.y, 0.0), tier), false)


	var side:= builds.add_platform(base + Vector3(2.5, 2.2, 0.0), Vector2(2.0, 2.0))
	for i in 3:
		await get_tree().physics_frame
	_is("an arm up on a stand beside it, with no plate between, still does",
		builds.arm_reach_conflict(Vector3(base.x + 2.5, side.top_y(), base.z), tier), true)
	builds.demolish(under)
	builds.demolish(side)
	builds.demolish(high)
	await get_tree().physics_frame


func _floor_y(at: Vector3) -> float:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 20.0)
	q.collision_mask = Cfg.L_WORLD
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	return 0.0 if hit.is_empty() else (hit ["position"] as Vector3).y


func _refused(label: String, eval: Dictionary) -> void:
	if bool(eval ["ok"]):
		_fail("%s was allowed" % label)
	else:
		print("  ok    %s: refused (%s)" % [label, eval ["reason"]])


func _allowed(label: String, eval: Dictionary) -> void:
	if bool(eval ["ok"]):
		print("  ok    %s: allowed" % label)
	else:
		_fail("%s was refused (%s)" % [label, eval ["reason"]])


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1
