class_name DevArmRelinkProbe
extends Node


var world: Node3D


const CARRY_FRAMES:= 900


const HOLD_FRAMES:= 120

const RECOVER_FRAMES:= 900

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var builds: BuildManager = world.builds
	var base:= Vector3(11.8, 0.06, 4.0)
	var first:= builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))


	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in 30:
		await get_tree().physics_frame

	print("\n=== the arm gets a load into the air ===")
	if not await _await_carrying(arm):
		_fail("the arm never picked anything up, so nothing below was tested")
		_finish()
		return
	print("  ok    carrying %d strands, phase %d" % [arm._payload_count, arm._phase])

	print("\n=== the belt is demolished out from under it ===")
	var cycles_before:= arm.completed_cycles
	builds.demolish(first)
	for i in HOLD_FRAMES:
		await get_tree().physics_frame


	_is("still holding its load", arm._payload_count > 0, true)
	_is("has not finished the cycle", arm.completed_cycles, cycles_before)

	print("\n=== a new belt goes in and the arm picks it back up ===")


	var second:= builds.add_conveyor(base + Vector3(-1.8, 0.45, -1.2),
		base + Vector3(-1.8, 0.45, 1.8))
	var recovered:= await _await_cycle(arm, cycles_before)
	_is("the cycle completes", recovered, true)
	if recovered:
		_is("onto the new run", arm._drop_run == second, true)
		_is("and the claw is empty again", arm._payload_count, 0)
	_finish()


func _finish() -> void:
	print("\n[arm-relink] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])


func _await_carrying(arm: RoboticArm) -> bool:
	for i in CARRY_FRAMES:
		if arm._payload_count > 0 and arm._phase in [RoboticArm.Phase.LIFT,
				RoboticArm.Phase.SWING_DROP, RoboticArm.Phase.DESCEND_DROP]:
			return true
		await get_tree().physics_frame
	return false


func _await_cycle(arm: RoboticArm, was: int) -> bool:
	for i in RECOVER_FRAMES:
		if arm.completed_cycles > was:
			return true
		await get_tree().physics_frame
	return false
