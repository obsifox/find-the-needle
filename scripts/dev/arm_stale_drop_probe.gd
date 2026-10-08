class_name DevArmStaleDropProbe
extends Node


var world: Node3D

const SETTLE:= 30

const CARRY_FRAMES:= 900


const DELIVER_FRAMES:= 300

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var builds: BuildManager = world.builds


	var base:= Vector3(11.8, 0.06, 4.0)
	var run:= builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)


	for i in SETTLE:
		await get_tree().physics_frame
	await _check_busy_spot(arm, run, base)

	print("\n=== a belt motor arrives while the load is in the air ===")
	Tech.grant("belt_speed", 0)
	if not await _await_carrying(arm):
		_fail("the arm never picked anything up, so nothing below was tested")
		_finish()
		return
	print("  ok    carrying %d strands at %.2f m/s belt" % [
		arm._payload_count, Tech.belt_speed()])
	Tech.grant("belt_speed", 4)
	print("  ok    belt motor bought mid-swing, now %.2f m/s" % Tech.belt_speed())
	await _await_at_deck(arm)
	_is("the belt is empty", run.riders_debug().size(), 0)

	_is("...and an empty belt has room for the load", arm._drop_run_clear(), true)
	_is("the cycle completes", await _await_cycle(arm), true)

	print("\n=== a payload rank arrives while the load is in the air ===")


	Tech.grant("arm_payload", 0)
	if not await _await_carrying(arm):
		_fail("the arm stopped working, so the second half was not tested")
		_finish()
		return
	Tech.grant("arm_payload", 6)
	await _await_at_deck(arm)
	_is("the belt is empty", run.riders_debug().size(), 0)
	_is("...and an empty belt has room for the load", arm._drop_run_clear(), true)
	_is("the cycle completes", await _await_cycle(arm), true)

	print("\n=== the committed spot goes bad on an empty belt ===")


	if not await _await_carrying(arm):
		_fail("the arm stopped working, so the third case was not tested")
		_finish()
		return


	for i in CARRY_FRAMES:
		if arm._phase == RoboticArm.Phase.SWING_DROP:
			break
		await get_tree().physics_frame
	arm._drop_target = run.b
	await _await_at_deck(arm)
	_is("the belt is empty", run.riders_debug().size(), 0)
	_is("the spot itself is refused", arm._drop_run_clear(), false)


	_is("the load goes down anyway", await _await_cycle(arm), true)
	_finish()


func _check_busy_spot(arm: RoboticArm, run: Conveyor, base: Vector3) -> void:
	print("\n=== a busy spot on an otherwise empty belt ===")
	arm.set_process(false)
	var count:= 60
	var choice:= arm._choose_drop(count)
	if choice.is_empty():
		_fail("the empty fixture belt has no drop point")
		arm.set_process(true)
		return
	var point: Vector3 = choice ["point"]
	var blocker:= StaticBody3D.new()
	blocker.collision_layer = Cfg.L_PROP
	blocker.collision_mask = 0
	var shape:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	shape.shape = box
	blocker.add_child(shape)
	world.add_child(blocker)
	blocker.global_position = run.landing_point(point, Tech.belt_speed())
	await get_tree().physics_frame
	_is("the nearest spot is occupied", arm._room_on(run, point, count), false)
	choice = arm._choose_drop(count)
	_is("another spot on that belt is found", not choice.is_empty(), true)
	if not choice.is_empty():
		_is("the chosen spot is clear", arm._room_on(run, choice ["point"], count), true)
		_is("the chosen spot is reachable", arm._shoulder_world().distance_to(
			choice ["point"]) < arm.reach_m() * 0.98, true)
	arm._payload_count = count
	arm._drop_run = run
	arm._drop_target = point
	_is("the held load can find room on its own belt", arm._repoint_on_run(), true)
	var relief: Conveyor = world.builds.add_conveyor(base + Vector3(-1.8, 0.45, -1.2),
		base + Vector3(-1.8, 0.45, 1.8))
	arm._phase = RoboticArm.Phase.DESCEND_DROP
	arm._drop_target = point
	arm._hold_since = 0.0
	arm._hold_retry_at = 0.0
	arm._finish_phase()
	_is("a passing obstruction does not restart the swing",
		arm._phase, RoboticArm.Phase.DESCEND_DROP)
	arm._hold_retry_at = 0.0
	arm._finish_phase()
	_is("a lasting obstruction moves the claw to free deck",
		arm._phase, RoboticArm.Phase.SWING_DROP)
	_is("the free deck on its own belt is used first", arm._drop_run == run, true)
	arm._phase = RoboticArm.Phase.DESCEND_DROP
	arm._drop_target = point
	arm._hold_since = 0.0
	arm._finish_phase()
	_is("a new arrival gets a fresh pause",
		arm._phase, RoboticArm.Phase.DESCEND_DROP)
	world.remove_child(blocker)
	blocker.queue_free()
	await get_tree().physics_frame
	var cycles:= arm.completed_cycles
	arm._finish_phase()
	_is("the claw opens as soon as its original spot clears",
		arm._phase, RoboticArm.Phase.OPEN_CLAWS)
	_is("the waiting load was delivered", arm.completed_cycles, cycles + 1)
	world.builds.demolish(relief)
	arm._payload_count = 0
	arm._hold_since = 0.0
	arm._hold_retry_at = 0.0
	arm._phase = RoboticArm.Phase.IDLE
	arm.set_process(true)
	await get_tree().physics_frame


func _await_carrying(arm: RoboticArm) -> bool:
	for i in CARRY_FRAMES:
		if arm._payload_count > 0 and arm._phase == RoboticArm.Phase.LIFT:
			return true
		await get_tree().physics_frame
	return false


func _await_at_deck(arm: RoboticArm) -> void:
	for i in CARRY_FRAMES:
		if arm._phase == RoboticArm.Phase.DESCEND_DROP and arm._payload_count > 0:
			return
		await get_tree().physics_frame


func _await_cycle(arm: RoboticArm) -> bool:
	var was:= arm.completed_cycles
	for i in DELIVER_FRAMES:
		if arm.completed_cycles > was:
			return true
		await get_tree().physics_frame
	return false


func _finish() -> void:
	print("\n[arm-stale] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
