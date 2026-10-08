class_name DevArmNeedleProbe
extends Node


var world: Node3D

const SETTLE_FRAMES:= 40


const CYCLE_FRAMES:= 1800


const YARD:= Vector3(-11.8, 0.06, 4.0)
const YARD_B:= Vector3(-11.8, 0.06, -6.0)

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	await _case_picks_one_up()
	await _case_digs_up_its_own()
	await _case_pinned_is_available()
	await _case_outranks_hay()
	await _case_leaves_the_others_alone()
	await _case_the_till_loses_it()
	_case_one_needle_one_arm()
	print("\n[arm-needle] %s"
		% ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _case_picks_one_up() -> void:
	print("\n=== an arm picks a loose needle up and belts it ===")
	var builds: BuildManager = world.builds
	builds.clear()
	_clear_needles()
	var belt:= builds.add_conveyor(YARD + Vector3(1.8, 0.45, -1.2),
		YARD + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(YARD, 0.0, 1)
	var needle:= _needle_at(YARD + Vector3(-1.6, 0.3, 0.0))
	if needle == null:
		return
	await _settle(SETTLE_FRAMES)

	var lifted:= false
	for i in CYCLE_FRAMES:
		if arm._payload_needle == needle:
			lifted = true
			break
		await get_tree().physics_frame
	_is("the needle ends up in the claw", lifted, true)
	if not lifted:
		return


	_is("held, not merely touched",
		bool(needle.get_meta(LiveStrandManager.META_PROTECTED, false)), true)
	_is("no hay was counted for it", arm._payload_count, 0)

	var placed:= false
	for i in CYCLE_FRAMES:
		if arm.delivered_needles > 0:
			placed = true
			break
		await get_tree().physics_frame
	_is("and is put down again", placed, true)
	if not placed:
		return
	_is("the same specimen, not a fresh one", is_instance_valid(needle), true)
	_is("the cycle is marked as a needle run", arm.last_cycle_needle, true)
	_is("nobody is still holding it",
		bool(needle.get_meta(LiveStrandManager.META_PROTECTED, false)), false)


	var aboard:= false
	for i in CYCLE_FRAMES / 4:
		if BeltPath.is_rider(needle):
			aboard = true
			break
		await get_tree().physics_frame
	var deck:= (belt.a + belt.b) * 0.5
	var off:= Vector2(needle.global_position.x - deck.x,
		needle.global_position.z - deck.z)
	print("  needle is %.2f m from the middle of the run" % off.length())
	_is("and the belt took it aboard", aboard, true)


func _case_digs_up_its_own() -> void:
	print("\n=== an arm picks its own find out of its own crater ===")
	var builds: BuildManager = world.builds
	builds.clear()
	_clear_needles()


	var base:= Vector3(0.0, 0.06, 7.4)
	builds.add_conveyor(base + Vector3(1.8, 0.45, 0.6),
		base + Vector3(1.8, 0.45, 3.2))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	await _settle(SETTLE_FRAMES)
	var pick: Dictionary = arm._find_field_pickup(arm._shoulder_world())
	if pick.is_empty():
		_fail("the arm found no hay to dig at %.2v" % base)
		return
	var surface:= pick ["point"] as Vector3


	var buried:= surface - Vector3(0, 0.12, 0)
	var index:= GameState.register_needle(buried, null, 0)
	print("  needle %d buried at %.2v, arm digs at %.2v" % [index, buried, surface])

	var found: RigidBody3D = null
	for i in CYCLE_FRAMES:
		for b in world.live.needles:
			if is_instance_valid(b) and int(b.get_meta("needle_index", -1)) == index:
				found = b
				break
		if found != null:
			break
		await get_tree().physics_frame
	_is("the dig turned it up", found != null, true)
	if found == null:
		return
	_is("and the ledger says it is no longer buried",
		GameState.needle_taken [index], 1)

	var lifted:= false
	for i in CYCLE_FRAMES:
		if arm._payload_needle == found:
			lifted = true
			break
		await get_tree().physics_frame
	_is("the arm goes back for it", lifted, true)
	if not lifted:
		return
	var before:= arm.delivered_needles
	for i in CYCLE_FRAMES:
		if arm.delivered_needles > before:
			break
		await get_tree().physics_frame
	_is("and posts it", arm.delivered_needles > before, true)


func _case_pinned_is_available() -> void:
	print("\n=== and a PINNED needle is still available ===")
	var builds: BuildManager = world.builds
	builds.clear()
	_clear_needles()
	var needle:= _needle_at(YARD_B + Vector3(-1.6, 0.3, 0.0))
	if needle == null:
		return
	var pinned:= false
	for i in CYCLE_FRAMES / 4:
		await get_tree().physics_frame
		if LiveStrandManager.is_pinned(needle):
			pinned = true
			break
	_is("the needle pinned itself first", pinned, true)
	_is("which means it is frozen", needle.freeze, true)
	if not pinned:
		return


	var found: RigidBody3D = world.live.nearest_available_needle(
		needle.global_position + Vector3(0, 1.1, 0), 4.0)
	_is("the search offers it anyway", found == needle, true)

	builds.add_conveyor(YARD_B + Vector3(1.8, 0.45, -1.2),
		YARD_B + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(YARD_B, 0.0, 1)
	var lifted:= false
	for i in CYCLE_FRAMES:
		if arm._payload_needle == needle:
			lifted = true
			break
		await get_tree().physics_frame
	_is("and an arm takes it out of the pin", lifted, true)
	_is("thawed on the way into the claw",
		LiveStrandManager.is_pinned(needle), false)


func _case_outranks_hay() -> void:
	print("\n=== a needle outranks the hay around it ===")
	var builds: BuildManager = world.builds
	builds.clear()
	_clear_needles()
	builds.add_conveyor(YARD + Vector3(1.8, 0.45, -1.2),
		YARD + Vector3(1.8, 0.45, 1.8))
	var needle:= _needle_at(YARD + Vector3(-1.5, 0.3, 0.3))
	if needle == null:
		return


	for i in 12:
		world.live.spawn(YARD + Vector3(-1.0 + 0.05 * float(i), 0.4, -0.2),
			Basis.IDENTITY, Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	await _settle(SETTLE_FRAMES * 2)
	var arm:= builds.add_robotic_arm(YARD, 0.0, 1)

	var took: String = ""
	for i in CYCLE_FRAMES:
		if arm._payload_needle != null:
			took = "needle"
			break
		if arm._payload_count > 0 or not arm._payload.is_empty():
			took = "hay"
			break
		await get_tree().physics_frame
	_is("the first thing lifted", took, "needle")


func _case_leaves_the_others_alone() -> void:
	print("\n=== and leaves the ones that are not its business ===")
	var builds: BuildManager = world.builds
	builds.clear()
	_clear_needles()
	var live: LiveStrandManager = world.live


	var belt:= builds.add_conveyor(YARD_B + Vector3(0.0, 0.45, -1.2),
		YARD_B + Vector3(0.0, 0.45, 1.8))
	var deck:= (belt.a + belt.b) * 0.5
	var rider:= _needle_at(deck + Vector3(0, 0.06, 0))
	if rider == null:
		return
	var aboard:= false
	for i in CYCLE_FRAMES / 4:
		await get_tree().physics_frame
		if BeltPath.is_rider(rider):
			aboard = true
			break
	_is("the belt has it", aboard, true)


	var eye:= rider.global_position + Vector3(0, 1.1, 0)
	_is("a rider is left alone",
		live.nearest_available_needle(eye, 4.0) == null, true)
	BeltPath.release(rider)
	eye = rider.global_position + Vector3(0, 1.1, 0)
	_is("...and is offered again once it is off the belt",
		live.nearest_available_needle(eye, 4.0) == rider, true)
	var at:= rider.global_position


	live.set_protected(rider, true)
	rider.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rider.freeze = true
	_is("one in a hand is left alone",
		live.nearest_available_needle(at + Vector3(0, 1.1, 0), 4.0) == null, true)
	live.set_protected(rider, false)
	rider.freeze = false


	rider.set_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL,
		Time.get_ticks_msec() * 0.001 + 30.0)
	_is("a fresh delivery is left alone",
		live.nearest_available_needle(at + Vector3(0, 1.1, 0), 4.0) == null, true)
	rider.remove_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL)


func _case_the_till_loses_it() -> void:
	print("\n=== a needle over the till is sold for scrap and gone ===")
	var stand: HaySellingStand = world.stand
	if stand == null:
		_fail("no selling stand in the world")
		return
	world.builds.clear()
	_clear_needles()
	await _settle(SETTLE_FRAMES)

	var found_before:= GameState.needles_found
	var research_before:= GameState.research_held()
	var money_before:= GameState.money
	var discovered_before:= GameState.discovered.duplicate()

	var needle:= _needle_at(stand.mouth_centre())
	if needle == null:
		return
	var eaten:= false
	for i in CYCLE_FRAMES / 4:
		await get_tree().physics_frame
		if not is_instance_valid(needle):
			eaten = true
			break
	_is("the till took it in", eaten, true)
	if not eaten:
		return


	await _settle(SETTLE_FRAMES * 3)

	print("  money %.2f -> %.2f, research %d -> %d, found %d -> %d"
		% [money_before, GameState.money, research_before,
			GameState.research_held(), found_before, GameState.needles_found])
	_is("it paid scrap value",
		is_equal_approx(GameState.money - money_before, Cfg.NEEDLE_SCRAP_PRICE), true)
	_is("nothing was banked to the drawers",
		GameState.research_held(), research_before)
	_is("it does not count as found", GameState.needles_found, found_before)
	_is("and nothing was discovered",
		GameState.discovered == discovered_before, true)


func _case_one_needle_one_arm() -> void:
	print("\n=== one needle is one machine's errand ===")
	var builds: BuildManager = world.builds
	builds.clear()
	_clear_needles()
	var live: LiveStrandManager = world.live
	var at:= YARD + Vector3(-1.6, 0.3, 0.0)
	var needle:= _needle_at(at)
	if needle == null:
		return
	var eye:= at + Vector3(0, 1.1, 0)
	var mine:= builds.add_robotic_arm(YARD, 0.0, 1)
	var theirs:= builds.add_robotic_arm(YARD_B, 0.0, 1)
	needle.set_meta(LiveStrandManager.META_CLAIM, mine.get_instance_id())
	_is("the machine that claimed it still sees it",
		live.nearest_available_needle(eye, 4.0, 0.0, mine.get_instance_id()) == needle,
		true)
	_is("the other one does not",
		live.nearest_available_needle(eye, 4.0, 0.0, theirs.get_instance_id()) == null,
		true)


	needle.set_meta(LiveStrandManager.META_CLAIM, 0)
	_is("a claim by nobody is no claim at all",
		live.nearest_available_needle(eye, 4.0, 0.0, theirs.get_instance_id()) == needle,
		true)


func _needle_at(at: Vector3) -> RigidBody3D:
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	var b: RigidBody3D = world.live.reveal_needle(index, at)
	if b == null:
		_fail("could not spawn a needle at %.2v" % at)
	return b


func _clear_needles() -> void:
	var live: LiveStrandManager = world.live
	for b in live.needles.duplicate():
		BeltPath.release(b)
		live.consume_needle(b)


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
