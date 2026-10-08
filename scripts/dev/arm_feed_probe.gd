class_name DevArmFeedProbe
extends Node


var world: Node3D

const SETTLE_FRAMES:= 30


const BLOCK_STEP:= 0.3


const SPREAD_CYCLES:= 4
const CYCLE_FRAMES:= 1200

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	await _check_spread()
	await _check_no_room()
	await _check_wad_pickup()
	await _check_wad_left_alone()
	print("\n[arm-feed] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])


func _check_spread() -> void:
	print("\n=== an arm serves every belt in reach ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(11.8, 0.06, 4.0)
	var left:= builds.add_conveyor(base + Vector3(-1.8, 0.45, -1.2),
		base + Vector3(-1.8, 0.45, 1.8))
	var right:= builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var served:= { }
	for cycle in SPREAD_CYCLES:
		var before:= arm.completed_cycles
		var seen: BeltPath = null
		var done:= false
		for i in CYCLE_FRAMES:


			if arm._payload_count > 0 and arm._drop_run != null:
				seen = arm._drop_run
			if arm.completed_cycles > before:
				done = true
				break
			await get_tree().physics_frame
		if not done:
			_fail("cycle %d never finished" % (cycle + 1))
			return
		if seen != null:
			served [seen] = int(served.get(seen, 0)) + 1
	print("  served left=%d right=%d over %d cycles"
		% [int(served.get(left, 0)), int(served.get(right, 0)), SPREAD_CYCLES])
	_is("both runs were fed", served.size(), 2)


func _check_no_room() -> void:
	print("\n=== and delivers nothing when there is no room ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(11.8, 0.06, 4.0)
	builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2), base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var runs:= builds.conveyor_drops(arm._shoulder_world(), arm.reach_m() * 0.98)
	_is("exactly one run in reach", runs.size(), 1)
	if runs.is_empty():
		return


	var line: BeltPath = runs [0] ["conveyor"] as BeltPath
	var parked: Array [HayWad] = []
	var along:= 0.0
	while along <= line.path_length():
		var blocker:= world.props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, line._point_at(along) + Vector3.UP * 0.26),
			{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
		along += BLOCK_STEP
		if blocker == null:
			continue
		parked.append(blocker)


		blocker.freeze = true


		blocker.set_meta(PropManager.META_CLAIM, get_instance_id())
	if parked.is_empty():
		_fail("could not spawn wads to block the run with")
		return
	print("  %d wads parked along the run" % parked.size())
	for i in CYCLE_FRAMES / 2:
		if arm.completed_cycles > 0:
			break
		await get_tree().physics_frame
	_is("no load was delivered", arm.completed_cycles, 0)


	print("  arm is holding %d strands in phase %d" % [arm._payload_count, arm._phase])
	_is("it holds its load rather than dropping it",
		arm._payload_count == 0 or arm._phase in [RoboticArm.Phase.DESCEND_DROP,
			RoboticArm.Phase.PARK_HOLD], true)
	for blocker in parked:
		if is_instance_valid(blocker):
			blocker.freeze = false


func _check_wad_pickup() -> void:
	print("\n=== an arm picks a wad up off the floor ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(-11.8, 0.06, 4.0)
	var belt:= builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)


	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis.IDENTITY, base + Vector3(-1.6, 0.35, 0.0)),
		{ "strands": 80 }) as HayWad
	if wad == null:
		_fail("could not spawn a wad to test with")
		return
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var lifted:= false
	for i in CYCLE_FRAMES:
		if arm._payload_prop == wad:
			lifted = true
			break
		await get_tree().physics_frame
	_is("the wad ends up in the claw", lifted, true)
	if not lifted:
		return
	_is("carried whole, not torn into strands", arm._payload_count, 80)

	var placed:= false
	for i in CYCLE_FRAMES:
		if arm.completed_cycles > 0:
			placed = true
			break
		await get_tree().physics_frame
	_is("and is put down again", placed, true)
	if not placed:
		return


	var seq:= arm.last_record_seq
	_is("put down on the belt as a record", seq >= 0, true)
	if seq < 0:
		return
	var where:= BeltPath.record_where(seq)
	_is("the record is on this belt", where.get("path") == belt, true)
	if where.is_empty():
		return
	var run: BeltRun = (where ["path"] as BeltPath).run
	_is("still holding its hay", run.strands_of(int(where ["row"])), 80)
	_is("nobody is holding it", arm._payload_prop == null, true)


	var at:= (where ["pose"] as Transform3D).origin
	var deck:= (belt.a + belt.b) * 0.5
	var off:= Vector2(at.x - deck.x, at.z - deck.z)
	print("  wad is %.2f m from the middle of a %.2f m run"
		% [off.length(), belt.a.distance_to(belt.b)])
	_is("and it stands on the belt", off.length() < 2.0, true)


func _check_wad_left_alone() -> void:
	print("\n=== and leaves the ones that are not its business ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(-11.8, 0.06, -6.0)
	builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2), base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var at:= Transform3D(Basis.IDENTITY, base + Vector3(-1.6, 0.35, 0.0))
	var claimed:= world.props.spawn("hay_wad", at, { "strands": 80 }) as HayWad
	if claimed == null:
		_fail("could not spawn a wad to test with")
		return


	claimed.set_meta(PropManager.META_CLAIM, world.get_instance_id())
	_is("a wad another machine claimed is skipped",
		arm._find_prop_pickup(arm._shoulder_world()), "<null>")
	claimed.remove_meta(PropManager.META_CLAIM)
	_is("...and is taken once the claim is dropped",
		arm._find_prop_pickup(arm._shoulder_world()), claimed)

	claimed.set_meta(LiveStrandManager.META_RIDER, builds.conveyors [0])
	_is("a wad riding a belt is a delivery, not a pickup",
		arm._find_prop_pickup(arm._shoulder_world()), "<null>")
	claimed.remove_meta(LiveStrandManager.META_RIDER)
