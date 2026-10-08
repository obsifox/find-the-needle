class_name DevRetierProbe
extends Node


var world: Node3D

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	Tech.reset()
	Tech.grant("belt")
	Tech.grant("arm_small")
	Tech.grant("scanner_mk1")

	var builds: BuildManager = world.builds
	var base:= Vector3(11.8, 0.06, 4.0)
	var arm:= builds.add_robotic_arm(base, 0.0, Tech.max_arm_tier())
	var scanner:= builds.add_scanner(base + Vector3(0.0, 0.0, 9.0), 0.0,
		Tech.max_scanner_tier())
	_check_built_small(arm, scanner)
	_check_mid_cycle_refit(builds, base + Vector3(0.0, 0.0, -9.0))
	_check_locked_upgrade(arm)
	_check_refit(arm, scanner)
	_check_paid_upgrade(arm)
	_check_refund_is_what_was_paid(builds, arm, scanner)
	_check_never_downgrades(builds, base)
	_check_save_round_trip(builds, base)
	_check_legacy_save_migrates(builds, base)
	_check_upgrade_at_own_price(builds, base)
	await _check_refit_reports_its_draw(builds, base)

	print("\n[retier] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])


func _near(label: String, got: float, want: float) -> void:
	if absf(got - want) <= 0.0005:
		print("  ok    %s = %.4f" % [label, got])
	else:
		_fail("%s = %.4f, expected %.4f" % [label, got, want])


func _check_built_small(arm: RoboticArm, scanner: HaystackScanner) -> void:
	print("\n=== built under the starting plans ===")
	_is("arm tier", arm.tier_index, 0)
	_is("arm paid", arm.build_cost(), float(Cfg.ROBOT_ARM_TIERS [0] ["cost"]))
	_is("scanner tier", scanner.tier_index, 0)
	_is("scanner paid", scanner.build_cost(), float(Cfg.SCANNER_TIERS [0] ["cost"]))


func _check_mid_cycle_refit(builds: BuildManager, at: Vector3) -> void:
	print("\n=== a refit mid-reach keeps its aim ===")
	var arm:= builds.add_robotic_arm(at, 0.0, 0)
	var target:= at + Vector3(0.0, 0.9, 2.1)
	arm._start_pose(RoboticArm.Phase.SWING_DROP, target, 0.85)
	var before:= arm._pose_to
	arm.set_tier(2)
	var after:= arm._pose_to
	if before.is_equal_approx(after):
		_fail("the pose in flight was left aimed by the old model")
	else:
		print("  ok    pose re-aimed at the new size")
	_is("re-aimed at the same world point", after,
		arm._solve_world_target(target))
	builds.demolish(arm)


func _check_refit(arm: RoboticArm, scanner: HaystackScanner) -> void:
	print("\n=== buying the plans refits the scanners and leaves the arms ===")
	Tech.grant("arm_standard")
	_is("arm tier after standard plans", arm.tier_index, 0)
	Tech.grant("arm_long")
	Tech.grant("scanner_mk2")
	_is("arm tier after long plans", arm.tier_index, 0)
	_near("arm reach is still the small arm's", arm.reach_m(),
		float(Cfg.ROBOT_ARM_TIERS [0] ["reach"]))


	var best_tier:= Cfg.SCANNER_TIERS.size() - 1
	var best: Dictionary = Cfg.SCANNER_TIERS [best_tier]
	_is("scanner tier", scanner.tier_index, best_tier)
	_is("scanner batch", scanner.batch_size(), Tech.scan_batch(int(best ["batch"])))
	_is("scanner cycle", scanner.scan_seconds(),
		Tech.scan_seconds(float(best ["scan_seconds"])))
	_is("scanner buffer", scanner.buffer_capacity(),
		Tech.scanner_buffer(int(best ["buffer"])))


func _check_locked_upgrade(arm: RoboticArm) -> void:
	print("\n=== no plans, no upgrade ===")
	GameState.money = maxf(GameState.money, 10000000.0)
	var before:= GameState.money
	_is("the block names the plans", arm.upgrade_block(), tr("not unlocked yet"))
	_is("upgrade refused", arm.upgrade(), false)
	_is("nothing spent", GameState.money, before)
	_is("still small", arm.tier_index, 0)


func _check_paid_upgrade(arm: RoboticArm) -> void:
	print("\n=== the plate's upgrade charges the difference ===")
	var small:= float(Cfg.ROBOT_ARM_TIERS [0] ["cost"])
	var standard:= float(Cfg.ROBOT_ARM_TIERS [1] ["cost"])
	var long:= float(Cfg.ROBOT_ARM_TIERS [2] ["cost"])
	var before:= GameState.money
	_is("quoted small to standard", arm.upgrade_price(), standard - small)
	_is("nothing in the way", arm.upgrade_block(), "")
	_is("upgrade to standard", arm.upgrade(), true)
	_is("tier", arm.tier_index, 1)
	_is("charged the difference", before - GameState.money, standard - small)
	_is("paid is the standard price", arm.build_cost(), standard)
	_is("quoted standard to long", arm.upgrade_price(), long - standard)
	_is("upgrade to long", arm.upgrade(), true)
	_is("paid is the long price", arm.build_cost(), long)
	var top: Dictionary = Cfg.ROBOT_ARM_TIERS [2]
	_is("arm tier", arm.tier_index, 2)
	_near("arm reach", arm.reach_m(), float(top ["reach"]))
	_near("model scale", arm._model.scale.x, float(top ["scale"]))
	var shape:= arm._collider.shape as CylinderShape3D
	_near("collider radius", shape.radius, RoboticArm.BASE_RADIUS * float(top ["scale"]))
	_near("collider height", shape.height, RoboticArm.BASE_HEIGHT * float(top ["scale"]))
	_near("collider sits on the floor", arm._collider.position.y, shape.height * 0.5)
	var spent:= GameState.money
	_is("the biggest model says so", arm.upgrade_block(), tr("biggest model"))
	_is("and has nothing to sell", arm.upgrade(), false)
	_is("and charged nothing", GameState.money, spent)


func _check_refund_is_what_was_paid(builds: BuildManager, arm: RoboticArm,
		scanner: HaystackScanner) -> void:
	print("\n=== a refit is not a money printer ===")
	_is("arm refund", builds.demolish(arm), float(Cfg.ROBOT_ARM_TIERS [2] ["cost"]))
	_is("scanner refund", builds.demolish(scanner), float(Cfg.SCANNER_TIERS [0] ["cost"]))


func _check_never_downgrades(builds: BuildManager, base: Vector3) -> void:
	print("\n=== a machine is never taken back down a model ===")
	var arm:= builds.add_robotic_arm(base, 0.0, Tech.max_arm_tier())
	var scanner:= builds.add_scanner(base + Vector3(0.0, 0.0, 9.0), 0.0,
		Tech.max_scanner_tier())
	Tech.grant("arm_long", 0)
	Tech.grant("arm_standard", 0)
	Tech.grant("scanner_mk2", 0)
	_is("arm after the plans are revoked", arm.tier_index, 2)
	_is("scanner after the plans are revoked", scanner.tier_index,
		Cfg.SCANNER_TIERS.size() - 1)
	builds.demolish(arm)
	builds.demolish(scanner)


func _check_save_round_trip(builds: BuildManager, base: Vector3) -> void:
	print("\n=== the refit survives a save ===")
	builds.clear()
	Tech.reset()
	Tech.grant("belt")
	Tech.grant("arm_small")
	Tech.grant("scanner_mk1")
	var bought: RoboticArm = builds.add_robotic_arm(base, 0.0, 0)
	builds.add_robotic_arm(base + Vector3(0.0, 0.0, 12.0), 0.0, 0)
	Tech.grant("arm_standard")
	Tech.grant("arm_long")
	Tech.grant("scanner_mk2")
	GameState.money = maxf(GameState.money, 10000000.0)
	bought.upgrade()
	var paid:= bought.build_cost()
	var saved:= builds.to_array()
	builds.from_array(saved)
	var arm: RoboticArm = builds.robotic_arms [0]
	var kept: RoboticArm = builds.robotic_arms [1]
	_is("upgraded tier out of the save", arm.tier_index, 1)
	_is("price out of the save", arm.build_cost(), paid)
	_is("the arm nobody upgraded is still small", kept.tier_index, 0)
	_is("and still cost what a small arm cost", kept.build_cost(),
		float(Cfg.ROBOT_ARM_TIERS [0] ["cost"]))


func _check_legacy_save_migrates(builds: BuildManager, base: Vector3) -> void:
	print("\n=== an old save comes up to the best model ===")
	var legacy:= [{
		"type": "robotic_arm",
		"position": base,
		"yaw": 0.0,
		"tier": 0,
	}, {
		"type": "haystack_scanner",
		"position": base + Vector3(0.0, 0.0, 9.0),
		"yaw": 0.0,
		"tier": 0,
	}]
	builds.from_array(legacy)
	var arm: RoboticArm = builds.robotic_arms [0]
	var scanner: HaystackScanner = builds.scanners [0]


	_is("legacy arm tier", arm.tier_index, 2)
	_is("legacy scanner tier", scanner.tier_index, Cfg.SCANNER_TIERS.size() - 1)


	_is("legacy arm refund", arm.build_cost(), float(Cfg.ROBOT_ARM_TIERS [0] ["cost"]))
	_is("legacy scanner refund", scanner.build_cost(),
		float(Cfg.SCANNER_TIERS [0] ["cost"]))


func _check_upgrade_at_own_price(builds: BuildManager, base: Vector3) -> void:
	print("\n=== a refit is priced at the arm's own crowd price ===")
	builds.clear()
	Tech.grant("arm_standard")
	Tech.grant("arm_long")
	GameState.money = maxf(GameState.money, 10000000.0)
	var small:= float(Cfg.ROBOT_ARM_TIERS [0] ["cost"])
	var standard:= float(Cfg.ROBOT_ARM_TIERS [1] ["cost"])
	var long:= float(Cfg.ROBOT_ARM_TIERS [2] ["cost"])
	var first: RoboticArm = builds.add_robotic_arm(base + Vector3(0.0, 0.0, 12.0), 0.0, 0,
		small)
	for i in 3:
		builds.add_robotic_arm(base + Vector3(0.0, 0.0, -12.0 * (i + 1)), 0.0, 0,
			builds.arm_price(0))
	var late_paid:= builds.arm_price(0)

	var late: RoboticArm = builds.add_robotic_arm(base, 0.0, 0, late_paid)
	_is("five arms standing", builds.robotic_arms.size(), 5)
	_is("the first arm still refits at list", first.upgrade_price(), standard - small)
	var multiple:= late_paid / small
	var want:= snappedf(standard * multiple, 10.0) - late_paid
	_is("the late arm refits at its own place", late.upgrade_price(), want)
	if want <= standard - small:
		_fail("a crowded arm should pay more than the list difference")
	late.upgrade()
	_is("nothing in the way of the second step", late.upgrade_block(), "")
	late.upgrade()
	var outright:= snappedf(long * multiple, 10.0)
	if absf(late.build_cost() - outright) > 10.0:
		_fail("small and two refits cost %.0f, a long arm at that place %.0f"
			% [late.build_cost(), outright])
	else:
		print("  ok    small and two refits = %.0f, long outright at that place = %.0f"
			% [late.build_cost(), outright])
	builds.clear()


func _check_refit_reports_its_draw(builds: BuildManager, base: Vector3) -> void:
	print("\n=== a refit re-reports its draw to the grid ===")
	builds.clear()
	Tech.reset()
	Tech.grant("belt")
	Tech.grant("arm_small")
	var grid: PowerGrid = builds.grid
	var was_unmetered:= grid.unmetered
	grid.unmetered = false
	var arm:= builds.add_robotic_arm(base, 0.0, Tech.max_arm_tier())
	var gen:= builds.add_generator(base + Vector3(0.0, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	builds.add_power_pole(base + Vector3(3.0, 0.0, -2.0), 0.0)
	await _settle()
	_is("the arm is on the network", grid.network_of(arm) >= 0, true)
	var small: Dictionary = Cfg.ROBOT_ARM_TIERS [0]
	var long: Dictionary = Cfg.ROBOT_ARM_TIERS [2]
	_near("small arm's draw", arm.draw_kw(), float(small ["draw_kw"]))
	_near("...and the grid bills it", float(grid.report(arm) ["demand"]),
		float(small ["draw_kw"]))
	Tech.grant("arm_standard")
	Tech.grant("arm_long")
	GameState.money = maxf(GameState.money, 10000000.0)
	arm.upgrade()
	arm.upgrade()
	_is("refitted to the long arm", arm.tier_index, 2)
	await _settle()
	_near("long arm's draw", arm.draw_kw(), float(long ["draw_kw"]))
	_near("...and the grid bills the new figure with no rebuild",
		float(grid.report(arm) ["demand"]), float(long ["draw_kw"]))
	if float(long ["draw_kw"]) <= float(small ["draw_kw"]):
		_fail("a long arm should want more than a small one")
	grid.unmetered = was_unmetered
	builds.clear()


func _settle() -> void:
	for i in 8:
		await get_tree().process_frame
		await get_tree().physics_frame
