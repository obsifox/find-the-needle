class_name DevArmOrderProbe
extends Node


var world: Node3D

const BASE:= Vector3(0.0, 0.06, 14.0)
const NEAR:= Vector3(-1.2, 0.35, -0.4)
const FAR:= Vector3(-2.3, 0.35, -0.6)
const SETTLE_FRAMES:= 60
const CYCLE_FRAMES:= 1500

var _failures:= 0
var _spawned: Array = []
var _straw: Array [RigidBody3D] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	for id in ["belt", "arm_small", "arm_standard"]:
		Tech.grant(id)
	var mask:= RoboticArm.PICK_LOOSE | RoboticArm.PICK_BALE | RoboticArm.PICK_NEEDLE
	print("\n=== without the card it is loose hay first, whatever is set ===")
	_is("big things first, card not bought: first grab",
		await _first(RoboticArm.ORDER_BIG, "straw", NEAR, FAR, mask), "loose")
	Tech.grant("pick_order")
	print("\n=== with the card ===")
	_is("loose hay first, bale nearer: first grab",
		await _first(RoboticArm.ORDER_LOOSE, "straw", NEAR, FAR, mask), "loose")
	_is("big things first, straw nearer: first grab",
		await _first(RoboticArm.ORDER_BIG, "straw", FAR, NEAR, mask), "hay_bale")
	_is("whatever is closest, bale nearer: first grab",
		await _first(RoboticArm.ORDER_CLOSEST, "straw", NEAR, FAR, mask), "hay_bale")
	_is("whatever is closest, straw nearer: first grab",
		await _first(RoboticArm.ORDER_CLOSEST, "straw", FAR, NEAR, mask), "loose")
	var blocks:= RoboticArm.PICK_WAD | RoboticArm.PICK_BALE | RoboticArm.PICK_NEEDLE
	_is("loose hay first, small wad nearer than a bale: first grab",
		await _first(RoboticArm.ORDER_LOOSE, "wad", FAR, NEAR, blocks), "hay_wad")
	_is("big things first, small wad nearer than a bale: first grab",
		await _first(RoboticArm.ORDER_BIG, "wad", FAR, NEAR, blocks), "hay_bale")
	_is("big things first, a needle further than the bale: first grab",
		await _first(RoboticArm.ORDER_BIG, "needle", NEAR, FAR, mask), "needle")
	await _check_round_trip()
	print("\n[arm-order] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _first(order: int, other: String, bale_at: Vector3, other_at: Vector3,
		mask: int) -> String:
	await _clean()
	var builds: BuildManager = world.builds
	builds.add_conveyor(BASE + Vector3(-2.0, 0.45, 1.8), BASE + Vector3(2.0, 0.45, 1.8))
	var props: PropManager = world.props
	var bale:= props.spawn("hay_bale", Transform3D(Basis.IDENTITY, BASE + bale_at)) as HayBale
	if bale != null:
		bale.strands = 60
		_spawned.append(bale)
	match other:
		"straw":


			for i in 8:
				_straw.append(world.live.spawn(BASE + other_at + Vector3(0.04 * float(i), 0.05, 0.0),
					Basis.IDENTITY, Vector3.ZERO, Cfg.COL_HAY_LIGHT))
		"wad":
			var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, BASE + other_at)) as HayWad
			if wad != null:
				wad.strands = 20
				_spawned.append(wad)
		"needle":
			var at:= BASE + other_at + Vector3(0.0, -0.1, 0.0)
			var index:= GameState.register_needle(at, null, 0)
			GameState.needle_taken [index] = 1
			if world.live.reveal_needle(index, at) == null:
				_fail("could not spawn a needle")
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var arm:= builds.add_robotic_arm(BASE, 0.0, 1)
	arm.accept_mask = mask
	arm.set_pick_order(order)
	var loose: RigidBody3D = world.live.nearest_available_hay(arm._shoulder_world(),
		arm.work_reach(), RoboticArm.MIN_REACH * arm.visual_scale())
	print("  loose straw the arm can see: %s" % (
		"%.2f m away" % loose.global_position.distance_to(arm._shoulder_world())
		if loose != null else "none"))


	for i in CYCLE_FRAMES:
		await get_tree().physics_frame
		if arm._phase == RoboticArm.Phase.IDLE:
			continue
		if arm._pickup_needle != null or arm._payload_needle != null:
			return "needle"
		var block: Carryable = arm._pickup_prop if arm._pickup_prop != null else arm._payload_prop
		if block != null and is_instance_valid(block):
			return block.item_id
		return "pile" if arm._pickup_from_field else "loose"
	return "nothing"


func _check_round_trip() -> void:
	print("\n=== the answer survives a save ===")
	await _clean()
	var builds: BuildManager = world.builds
	var arm:= builds.add_robotic_arm(BASE, 0.0, 1)
	_is("the default writes nothing", arm.to_dict().has("order"), false)
	arm.set_pick_order(RoboticArm.ORDER_CLOSEST)
	var saved:= builds.to_array()
	_is("closest is written by name", str(saved [0].get("order", "")), "closest")
	builds.clear()
	await get_tree().physics_frame
	builds.from_array(saved)
	_is("and comes back", builds.robotic_arms [0].pick_order if not builds.robotic_arms.is_empty()
		else -1, RoboticArm.ORDER_CLOSEST)


func _clean() -> void:
	var builds: BuildManager = world.builds
	builds.clear()
	await get_tree().physics_frame
	for item: Variant in _spawned:
		if item != null and is_instance_valid(item):
			(item as Node).queue_free()
	_spawned.clear()
	var live: LiveStrandManager = world.live
	for b in _straw:
		if b != null and is_instance_valid(b):
			BeltPath.release(b)
			live.consume(b)
	_straw.clear()

	var props: PropManager = world.props
	for item: Variant in props.items.duplicate():
		if not is_instance_valid(item) or not item is HayTuft:
			continue
		if (item as Node3D).global_position.distance_to(BASE) < 6.0:
			(item as Node).queue_free()
	for b in live.needles.duplicate():
		BeltPath.release(b)
		live.consume_needle(b)
	await get_tree().physics_frame


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
