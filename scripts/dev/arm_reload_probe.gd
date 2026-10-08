class_name DevArmReloadProbe
extends Node


var world: Node3D

const SETTLE_FRAMES:= 40
const CARRY_FRAMES:= 900
const CYCLE_FRAMES:= 900

const STALL_FRAMES:= 400
const RELOADS:= 8

var _pass:= 0
var _fail:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	var base:= Vector3(11.8, 0.06, 4.0)
	builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	print("\n=== the arm works before anything is saved ===")
	if not await _await_cycle(arm, arm.completed_cycles):
		_check("a cycle completes", false)
		print("  the arm never worked, so nothing below proves anything")
		_finish()
		return
	_check("a cycle completes", true)

	print("\n=== reloaded while IDLE ===")
	arm = await _reload(builds, props)
	_check("the arm came back", arm != null)
	if arm != null:
		_check("...and cycles again", await _await_cycle(arm, arm.completed_cycles))

	print("\n=== reloaded MID-CARRY, which is what an autosave catches ===")
	arm = builds.robotic_arms [0]


	_clear_floor(props)
	var carrying:= await _await_carrying(arm)
	_check("the arm has a load in the air", carrying)
	if carrying:
		print("  saving with %d strands in the claw, phase %d"
			% [arm._payload_count, arm._phase])


	var carried:= arm._payload_count
	var bodies:= arm._payload.size()
	var from_field:= arm._pickup_from_field
	var hay_before:= GameState.hay_total
	arm = await _reload(builds, props)
	_check("the arm came back", arm != null)
	if arm != null:
		_check("...and cycles again", await _await_cycle(arm, arm.completed_cycles))
	print("  claw held %d strands as %d bodies + %d as a number (from field: %s)"
		% [carried, bodies, carried - bodies, from_field])
	print("  strand pool: %d free, %d active, budget %d"
		% [world.live._pool.size(), world.live._active.size(),
			Cfg.live_strand_budget])
	print("  pile was %.1f before the reload, %.1f after"
		% [hay_before, GameState.hay_total])
	_check("the hay carried as a number is not destroyed by the reload",
		GameState.hay_total >= hay_before + float(carried - bodies) - 1.0)

	print("\n=== reloaded carrying a WHOLE WAD ===")
	arm = builds.robotic_arms [0]


	props.spawn("hay_wad", Transform3D(Basis(), base + Vector3(-1.1, 0.3, 0.0)),
		{ "strands": 150 })
	var held:= await _await_wad(arm)
	_check("the arm has a wad in the claw", held)
	arm = await _reload(builds, props)
	_check("the arm came back", arm != null)
	if arm != null:
		_check("...and cycles again", await _await_cycle(arm, arm.completed_cycles))

	print("\n=== %d reloads back to back ===" % RELOADS)
	var survived:= true
	for i in RELOADS:
		arm = await _reload(builds, props)
		if arm == null or not await _await_cycle(arm, arm.completed_cycles):
			_check("reload %d still cycles" % (i + 1), false)
			survived = false
			break
	if survived:
		_check("every reload still cycles", true)
		print("  %d props left in the yard" % props.items.size())

	print("\n=== an obstruction on the drop point ===")
	arm = builds.robotic_arms [0]
	await _await_idle(arm)
	var drop: Dictionary = builds.nearest_conveyor_drop(
		arm._shoulder_world(), arm.reach_m() * 0.98)
	_check("the arm has a drop point", not drop.is_empty())
	if not drop.is_empty():
		var blocker:= props.spawn("hay_wad",
			Transform3D(Basis(), drop ["point"] as Vector3),
			{ "strands": 120 }) as HayWad


		blocker.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		blocker.freeze = true
		var was:= arm.completed_cycles
		var moved:= await _await_cycle_within(arm, was, STALL_FRAMES)


		print("  %s while blocked -- phase %d, holding %d"
			% ["kept cycling" if moved else "stalled", arm._phase,
				arm._payload_count])

		if is_instance_valid(blocker):
			props.remove(blocker)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		_check("...and is NOT retired -- it works once the point is cleared",
			await _await_cycle(arm, arm.completed_cycles))

	_finish()


func _reload(builds: BuildManager, props: PropManager) -> RoboticArm:
	var yard: Array = builds.to_array()
	var loose: Array = props.to_array()
	var belts:= {
		"paths": BeltPath.belts_to_array(),
		"lifts": HayLift.rows_to_array(),
		"stairs": HayStairs.rows_to_array(),
	}
	builds.from_array(yard)
	props.from_array(loose)
	BeltPath.belts_from_array(belts ["paths"], props)
	HayLift.rows_from_array(belts ["lifts"], props)
	HayStairs.rows_from_array(belts ["stairs"], props)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	return builds.robotic_arms [0] if not builds.robotic_arms.is_empty() else null


func _await_carrying(arm: RoboticArm) -> bool:
	for i in CARRY_FRAMES:
		if arm._payload_count > 0 and arm._payload_prop == null and arm._phase in [RoboticArm.Phase.LIFT,
				RoboticArm.Phase.SWING_DROP, RoboticArm.Phase.DESCEND_DROP]:
			return true
		await get_tree().physics_frame
	return false


func _clear_floor(props: PropManager) -> void:
	for item in props.items.duplicate():
		var prop:= item as Carryable
		if prop == null or not is_instance_valid(prop):
			continue
		if BeltPath.is_rider(prop) or prop.is_held():
			continue
		props.remove(prop)


func _await_wad(arm: RoboticArm) -> bool:
	for i in CARRY_FRAMES:
		if arm._payload_prop != null and arm._phase in [RoboticArm.Phase.LIFT,
				RoboticArm.Phase.SWING_DROP, RoboticArm.Phase.DESCEND_DROP]:
			return true
		await get_tree().physics_frame
	return false


func _await_idle(arm: RoboticArm) -> void:
	for i in CYCLE_FRAMES:
		if arm._phase == RoboticArm.Phase.IDLE:
			return
		await get_tree().physics_frame


func _await_cycle(arm: RoboticArm, was: int) -> bool:
	return await _await_cycle_within(arm, was, CYCLE_FRAMES)


func _await_cycle_within(arm: RoboticArm, was: int, frames: int) -> bool:
	for i in frames:
		if arm.completed_cycles > was:
			return true
		await get_tree().physics_frame
	return false


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  ok    %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)


func _finish() -> void:
	print("\n[arm-reload] %d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)
