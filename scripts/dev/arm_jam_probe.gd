class_name DevArmJamProbe
extends Node


var world: Node3D


const SETTLE:= 30


const CARRY_FRAMES:= 900


const HOLD_FRAMES:= 600

const RECOVER_FRAMES:= 1200


const FEED_EVERY:= 3
const PER_DROP:= 4
const FEED_FRAMES:= 600

var _rng:= RandomNumberGenerator.new()
var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	_rng.seed = 20260905
	var builds: BuildManager = world.builds


	var base:= Vector3(11.8, 0.06, 4.0)
	var head:= base + Vector3(1.8, 0.45, -1.2)
	var tail:= base + Vector3(1.8, 0.45, 1.8)
	var jammed:= builds.add_conveyor(head, tail)
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== the run stops for good and fills up ===")


	jammed.set_outlet_held(true)
	var fed:= 0
	for tick in FEED_FRAMES:
		if tick % FEED_EVERY == 0:
			fed += _feed(head)
		await get_tree().physics_frame
	print("  ok    %d strands fed, %d riders aboard" % [fed, jammed.riders_debug().size()])

	print("\n=== the arm ends up stopped over it ===")


	if not await _await_stopped(arm):
		_fail("the arm never came to a stop over the full run, so nothing below was tested")
		_finish()
		return
	var holding:= arm._payload_count > 0
	print("        stopped %s" % ("holding a load" if holding else "idle, claw empty"))
	var cycles_before:= arm.completed_cycles
	for i in HOLD_FRAMES:
		await get_tree().physics_frame
	_is("still holding its load" if holding else "still idle",
		arm._payload_count > 0, holding)
	_is("and no cycle has finished", arm.completed_cycles, cycles_before)

	print("\n=== it says why it is standing still ===")


	var reason:= arm.alert_reason()
	_is("alert_reason is not empty", reason != "", true)
	if reason != "":
		print("        %s" % reason)

	print("\n=== a second run in reach gets the load ===")


	var relief:= builds.add_conveyor(base + Vector3(-1.8, 0.45, -1.2),
		base + Vector3(-1.8, 0.45, 1.8))
	for i in SETTLE:
		await get_tree().physics_frame
	var recovered:= await _await_cycle(arm, cycles_before)
	_is("the cycle completes", recovered, true)
	if recovered:
		_is("onto the run with room", arm._drop_run == relief, true)


		if holding:
			_is("and the claw is empty again", arm._payload_count, 0)
	_finish()


func _feed(at: Vector3) -> int:
	var made:= 0
	for i in PER_DROP:
		var pos:= at + Vector3(_rng.randf_range(-0.1, 0.1), 0.55,
			_rng.randf_range(-0.1, 0.1))
		var body: RigidBody3D = world.live.spawn(pos,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
			Cfg.COL_HAY_LIGHT)
		if body != null:
			made += 1
	return made


func _await_stopped(arm: RoboticArm) -> bool:
	for i in CARRY_FRAMES:
		if arm._payload_count > 0 and arm._phase in [RoboticArm.Phase.DESCEND_DROP,
				RoboticArm.Phase.PARK_HOLD]:
			return true
		if arm._payload_count == 0 and arm._phase == RoboticArm.Phase.IDLE and arm._stall != "":
			return true
		await get_tree().physics_frame
	return false


func _await_cycle(arm: RoboticArm, was: int) -> bool:
	for i in RECOVER_FRAMES:
		if arm.completed_cycles > was:
			return true
		await get_tree().physics_frame
	return false


func _finish() -> void:
	print("\n[arm-jam] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
