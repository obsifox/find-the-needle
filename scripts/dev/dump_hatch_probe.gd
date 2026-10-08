class_name DevDumpHatchProbe
extends Node


const SETTLE:= 30


const CYCLE_TICKS:= 2400


const DRAIN_TICKS:= 3600


const BELT_X0:= -3.12
const BELT_X1:= -1.42


const BELT_Z:= 3.05
const BELT_HALF:= 0.482

const THROW_X:= -2.1


const SEAT_X:= -2.85
const SEAT_Z:= 3.88


const SITE_X:= -13.0
const SITE_Z:= -7.0


const BELT_IN_FRONT:= 1.15


const BELT_PAST_SPOUT:= 1.9

var world: Node3D
var player: Player

var _fails:= 0
var _sold_strands:= 0


func run() -> void:
	call_deferred("_run")


func _ok(what: String, pass_: bool, detail: String = "") -> void:
	if pass_:
		print("  ok    %s%s" % [what, "" if detail == "" else "   (%s)" % detail])
	else:
		_fails += 1
		print("  FAIL  %s%s" % [what, "" if detail == "" else "   (%s)" % detail])


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame

	var stand: HaySellingStand = world.stand
	if stand == null:
		print("[dumphatch] no selling stand in this world")
		get_tree().quit()
		return
	stand.sold.connect(func(n: int, _amount: float) -> void: _sold_strands += n)

	var builds: BuildManager = world.builds

	print("\n=== before the plans are bought ===")
	_ok("the build menu will not sell one", not BuildCatalog.is_unlocked("hatch"))
	_ok("and nothing is standing in the yard", builds.dump_hatches.is_empty())

	print("\n=== buying the plans and building one ===")
	GameState.add_money(9000.0)


	for id in ["bucket", "bucket_size", "wheelbarrow", "dump_hatch"]:
		Tech.buy(id)
	_ok("the build menu sells one now", BuildCatalog.is_unlocked("hatch"))

	await _siting_one()
	await _siting_refusals(builds)


	var seat:= stand.to_global(Vector3(SEAT_X, 0.0, SEAT_Z))
	var hatch: DumpHatch = builds.add_dump_hatch(seat, stand.global_rotation.y)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok("the machine is standing", hatch != null and builds.dump_hatches.size() == 1)
	if hatch == null:
		get_tree().quit()
		return
	_ok("and it knows where the loose hay is counted", hatch.live != null)

	await _geometry(hatch, stand)


	var by_hand:= await _by_hand(hatch)
	var by_machine:= await _cycle(hatch, "wheelbarrow")

	print("\n=== the two ways of emptying a barrow ===")
	print("  by hand, over the same spot : %d strands sold" % by_hand)
	print("  on the machine             : %d strands sold" % by_machine)
	_ok("the machine sells more of a barrow than a pair of arms does",
		by_machine > by_hand, "%d against %d" % [by_machine, by_hand])


	var bucket_hand:= await _by_hand(hatch, "bucket")
	var bucket_sold:= await _cycle(hatch, "bucket")
	print("\n=== the two ways of emptying a bucket ===")
	print("  by hand, over the same spot : %d strands sold" % bucket_hand)
	print("  on the machine             : %d strands sold" % bucket_sold)


	_ok("the machine sells more of a bucket than a pair of arms does",
		bucket_sold > bucket_hand, "%d against %d" % [bucket_sold, bucket_hand])

	await _the_hopper(builds, stand)

	await _a_belt_in_front(builds, stand)

	await _a_belt_farther_out(builds, stand)

	await _while_it_is_holding_one(hatch)

	await _as_a_building(builds, stand)

	print("\n=== %d checks failed ===" % _fails)

	get_tree().quit()


func _siting_one() -> void:
	print("\n=== siting one with the build tool ===")
	var tool: BuildTool = player.build
	tool._mode = BuildTool.Mode.DUMP_HATCH
	tool._reach = 8.0


	var aim:= Vector3(SITE_X, 0.0, SITE_Z)
	player.global_position = aim + Vector3(3.0, 0.4, 0.0)


	for i in SETTLE:
		await get_tree().physics_frame
	_aim(aim)


	var ghost: DumpHatch = tool._hatch_ghost
	for i in 8:
		tool._update_dump_hatch_ghost()
		await get_tree().physics_frame
	var first_at:= ghost.global_position
	_ok("the hologram may be placed on open ground",
		tool._eval ["ok"], str(tool._eval ["reason"]))


	var drift:= 0.0
	for i in 6:
		tool._update_dump_hatch_ghost()
		await get_tree().physics_frame
		drift = maxf(drift, first_at.distance_to(ghost.global_position))
	_ok("...and holds still while the player does", drift < 0.001,
		"moved %.3f m across six frames" % drift)


	var look:= player.look_direction()
	look.y = 0.0
	look = look.normalized()
	var out:= ghost.spout_point() - ghost.global_position
	out.y = 0.0
	var stood:= ghost.approach_point() - ghost.global_position
	stood.y = 0.0
	_ok("...pouring the way the player is looking", out.normalized().dot(look) > 0.9,
		"%.2f" % out.normalized().dot(look))
	_ok("...with its standing room behind it",
		stood.normalized().dot(look) < -0.9, "%.2f" % stood.normalized().dot(look))

	tool._mode = BuildTool.Mode.CONVEYOR


func _siting_refusals(builds: BuildManager) -> void:
	print("\n=== where it may not stand ===")
	var tool: BuildTool = player.build
	var ghost: DumpHatch = tool._hatch_ghost
	ghost.global_rotation = Vector3.ZERO
	var aim:= Vector3(SITE_X, 0.0, SITE_Z)

	var across:= builds.add_conveyor(aim + Vector3(-4.0, 0.0, 0.7),
		aim + Vector3(4.0, 0.0, 0.7))
	for i in SETTLE:
		await get_tree().physics_frame
	var verdict: Dictionary = tool._evaluate_dump_hatch(aim, null)
	_ok("a belt through the frame is refused", not verdict ["ok"],
		str(verdict ["reason"]))

	var bodies:= across.find_children("*", "CollisionObject3D", true, false)
	if not bodies.is_empty():
		var top:= aim + Vector3(0.0, 0.0, 0.7)
		var q:= PhysicsRayQueryParameters3D.create(top + Vector3.UP * 2.0,
			top + Vector3.DOWN, Cfg.L_BUILD)
		var hit:= get_viewport().world_3d.direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			verdict = tool._evaluate_dump_hatch(hit ["position"], hit ["collider"])
			_ok("...and so is standing it on the belt", not verdict ["ok"]
				and str(verdict ["reason"]) == tr("on a belt"), str(verdict ["reason"]))
	builds.demolish(across)

	var ahead:= builds.add_conveyor(aim + Vector3(-4.0, 0.0, -1.0),
		aim + Vector3(4.0, 0.0, -1.0))
	for i in SETTLE:
		await get_tree().physics_frame
	verdict = tool._evaluate_dump_hatch(aim, null)
	_ok("a belt out past the spout is fine", verdict ["ok"], str(verdict ["reason"]))
	builds.demolish(ahead)
	for i in SETTLE:
		await get_tree().physics_frame

	verdict = tool._evaluate_dump_hatch(aim + Vector3(0.0, 0.5, 0.0), null)
	_ok("a frame with no floor under its feet is refused", not verdict ["ok"],
		str(verdict ["reason"]))


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _the_hopper(builds: BuildManager, stand: HaySellingStand) -> void:
	print("\n=== load after load, without waiting ===")
	var props: PropManager = world.props
	var away:= stand.to_global(Vector3(SEAT_X, 0.0, SEAT_Z + 14.0))
	var tip: DumpHatch = builds.add_dump_hatch(away, stand.global_rotation.y)
	for i in SETTLE:
		await get_tree().physics_frame
	var far:= tip.approach_point() + Vector3(0.0, 0.0, 9.0)

	var banked:= 0
	var slowest:= 0.0
	for n in 3:
		var thing: Carryable = props.spawn("wheelbarrow",
			Transform3D(Basis.IDENTITY, far + Vector3(0, 0.4, 0)))
		var box:= thing as HayContainer
		if box == null:
			_ok("a wheelbarrow could be placed", false)
			break
		box.stored = box.capacity()
		var loaded:= box.stored
		var before:= tip.stored
		player.global_position = far
		player.force_update_transform()
		player.carry.take(box)
		for i in 2:
			await get_tree().physics_frame

		player.global_position = tip.approach_point()
		player.force_update_transform()
		var waited:= 0
		for i in CYCLE_TICKS:
			await get_tree().physics_frame
			waited = i
			if player.carry.held() == box and box.stored <= 0:
				break
		var secs:= float(waited) * get_physics_process_delta_time()
		slowest = maxf(slowest, secs)
		_ok("barrow %d went in and came straight back" % (n + 1),
			box.stored <= 0 and player.carry.held() == box, "%.2f s" % secs)
		_ok("...and the hopper is deeper for it", tip.stored > before,
			"%d strands, was %d" % [tip.stored, before])
		banked += loaded
		player.carry.drop()
		props.remove(box)
		for i in 4:
			await get_tree().physics_frame


	_ok("it banked more than one barrow's worth", tip.stored > 2100,
		"%d strands still in it of %d put in" % [tip.stored, banked])


	var shown:= _bin_strands(tip)
	var want:= int(round(tip.fill_fraction() * float(DumpHatch.FILL_INSTANCES)))
	_ok("the bin is drawn as full as it is", shown == want and shown > 0,
		"%d of %d strands shown, %d%% full" % [shown, DumpHatch.FILL_INSTANCES,
			int(round(tip.fill_fraction() * 100.0))])
	_ok("...and no load waited on the last one", slowest < 3.0,
		"slowest handover %.2f s" % slowest)


	var spare: Carryable = props.spawn("wheelbarrow",
		Transform3D(Basis.IDENTITY, far + Vector3(0, 0.4, 0)))
	var full_box:= spare as HayContainer
	if full_box != null:
		full_box.stored = full_box.capacity()
		var was:= tip.stored
		tip.stored = DumpHatch.CAPACITY
		_ok("a full machine refuses the next load", not tip.will_take(full_box))
		_ok("...and says so by having no room", tip.room() == 0)
		tip.stored = 0
		_ok("an empty one wants it again", tip.will_take(full_box))
		tip.stored = was
		props.remove(full_box)

	builds.demolish(tip)
	for i in SETTLE:
		await get_tree().physics_frame
	player.global_position = far
	player.force_update_transform()


func _as_a_building(builds: BuildManager, stand: HaySellingStand) -> void:
	print("\n=== as a building ===")
	var first: DumpHatch = builds.dump_hatches [0]
	var away:= stand.to_global(Vector3(SEAT_X + 4.5, 0.0, SEAT_Z))
	var second: DumpHatch = builds.add_dump_hatch(away, 0.0)
	await get_tree().physics_frame
	_ok("a second one can be built", builds.dump_hatches.size() == 2)
	_ok("...and the two do not share a name", first.name != second.name)


	var low:= builds.add_platform(away + Vector3(0.0, 1.0, 0.8), Vector2(3.0, 3.0))
	var high:= builds.add_platform(away + Vector3(6.0, 2.5, 0.8), Vector2(3.0, 3.0))
	await get_tree().physics_frame
	_ok("a deck at 1 m through the tipper is refused",
		builds.hatch_through_deck(low.footprint(), low.top_y()) == second)
	_ok("...and a tipper put where that deck already stands is refused",
		builds.deck_through_hatch(away, second.global_rotation.y) == low)
	_ok("a tipper under a deck 2.5 m up has room",
		builds.deck_through_hatch(away + Vector3(6.0, 0.0, 0.0), 0.0) == null)
	_ok("a tipper standing on a deck is on it, not in it",
		builds.deck_through_hatch(away + Vector3(6.0, 2.5, 0.8), 0.0) == null)
	_ok("a tipper beside a low deck is clear of it",
		builds.deck_through_hatch(away + Vector3(-3.0, 0.0, 0.8), 0.0) == null)
	builds.demolish(low)
	builds.demolish(high)
	await get_tree().physics_frame
	_ok("the yard counts them among its buildings",
		builds.all_buildings().has(first) and builds.all_buildings().has(second))


	first.stored = 1234
	var saved:= builds.to_array()
	var rows:= 0


	var saved_hay:= -1
	for row: Dictionary in saved:
		if str(row.get("type", "")) != "dump_hatch":
			continue
		rows += 1
		var where: Vector3 = row.get("position", Vector3.ZERO)
		if where.distance_to(first.global_position) < 0.01:
			saved_hay = int(row.get("stored", -1))
	_ok("both are written to the save", rows == 2, "%d rows" % rows)
	_ok("...and one of them with a hopper full of hay", saved_hay > 1000,
		"%d strands in the row" % saved_hay)

	var was_first:= first.global_position
	var was_second:= second.global_position
	builds.from_array(saved)
	await get_tree().physics_frame
	_ok("both come back", builds.dump_hatches.size() == 2,
		"%d after the reload" % builds.dump_hatches.size())
	if builds.dump_hatches.size() == 2:
		var a: DumpHatch = builds.dump_hatches [0]
		var b: DumpHatch = builds.dump_hatches [1]
		_ok("...where they were put",
			a.global_position.distance_to(was_first) < 0.01
			and b.global_position.distance_to(was_second) < 0.01)


		_ok("...and wired up, not just placed", a.live != null and b.live != null)
		var kept:= a.stored if a.global_position.distance_to(was_first) < 0.01 else b.stored


		_ok("...still holding what was in the hopper",
			kept <= saved_hay and kept > saved_hay - 60,
			"%d strands, the row said %d" % [kept, saved_hay])


	var doomed: DumpHatch = builds.dump_hatches [1]
	var shape:= doomed.find_children("*", "StaticBody3D", true, false)
	_ok("the model gives the crosshair something to hit", not shape.is_empty())
	if not shape.is_empty():
		_ok("...and the dismantle ray walks it back to the machine",
			builds.owner_of(shape [0]) == doomed)
	_ok("...with nothing refusing the demolition",
		builds.demolish_blocked_reason(doomed) == "")

	var before:= GameState.money
	var refund:= builds.demolish(builds.dump_hatches [1])
	GameState.add_money(refund)
	await get_tree().physics_frame
	_ok("one can be demolished", builds.dump_hatches.size() == 1)
	_ok("...for its price back", is_equal_approx(refund, Cfg.DUMP_HATCH_COST),
		"$%.0f of $%.0f" % [refund, Cfg.DUMP_HATCH_COST])
	_ok("...and the money arrives", GameState.money > before)


func _geometry(hatch: DumpHatch, stand: HaySellingStand) -> void:
	print("\n=== where it stands, and which way it turns ===")
	var down:= hatch.dock_point()


	hatch._drive(1.0)
	var up:= hatch.dock_point()
	hatch._drive(0.0)

	_ok("the deck tips UP, not into the floor", up.y > down.y + 0.4,
		"dock rose %.2f m" % (up.y - down.y))


	var toward:= stand.to_local(down).z - stand.to_local(up).z
	_ok("and leans toward the belt", toward > 0.3,
		"moved %.2f m in" % toward)

	var spout:= stand.to_local(hatch.spout_point())
	_ok("the spout is over the belt's carrying run",
		spout.x > BELT_X0 and spout.x < BELT_X1,
		"x %.2f, run is %.2f to %.2f" % [spout.x, BELT_X0, BELT_X1])
	_ok("...and inside its skirts", absf(spout.z - BELT_Z) < BELT_HALF,
		"z %.2f, skirt is %.2f either side of %.2f"
		% [spout.z, BELT_HALF, BELT_Z])


	var edge: float = absf(SEAT_X - THROW_X) - 0.47
	_ok("the deck is clear of the throw lane", edge > 0.0,
		"%.2f m of daylight" % edge)


func _by_hand(hatch: DumpHatch, id: String = "wheelbarrow") -> int:
	print("\n=== the same %s, tipped by hand ===" % id)
	var props: PropManager = world.props
	hatch._drive(1.0)
	var pose:= hatch.dock_transform()
	hatch._drive(0.0)
	var thing: Carryable = props.spawn(id, pose)
	var box:= thing as HayContainer
	if box == null:
		_ok("a %s could be placed for the hand case" % id, false)
		return 0
	box.stored = box.capacity()
	var loaded:= box.stored
	box.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	box.freeze = true
	box.linear_velocity = Vector3.ZERO
	_sold_strands = 0
	var live: LiveStrandManager = world.live
	for i in CYCLE_TICKS + DRAIN_TICKS:
		box.global_transform = pose
		await get_tree().physics_frame
		if i % 480 == 0:
			print("  %+5.1f s   sold %5d   live %4d   still in it %5d"
				% [float(i) * get_physics_process_delta_time(), _sold_strands,
					live.active_count(), box.stored])
		if box.stored <= 0 and _sold_strands >= loaded:
			break
	print("  loaded %d, the stand bought %d, the yard took back %d"
		% [loaded, _sold_strands, loaded - _sold_strands])


	props.remove(box)
	for i in SETTLE:
		await get_tree().physics_frame
	return _sold_strands


func _cycle(hatch: DumpHatch, id: String = "wheelbarrow") -> int:
	print("\n=== a full %s, walked up to the machine ===" % id)
	var props: PropManager = world.props
	var thing: Carryable = props.spawn(id,
		Transform3D(Basis.IDENTITY, hatch.approach_point() + Vector3(0, 0.4, 0)))
	var box:= thing as HayContainer
	if box == null:
		_ok("a %s could be placed" % id, false)
		return 0
	box.stored = box.capacity()
	var loaded:= box.stored
	var was_in_hopper:= hatch.stored
	_sold_strands = 0
	print("  %d strands in it, and it pours %d a second by hand"
		% [loaded, int(box.pour_rate())])


	player.global_position = hatch.approach_point() + Vector3(0.0, 0.0, 9.0)
	player.force_update_transform()
	player.carry.take(box)
	for i in 2:
		await get_tree().physics_frame
	_ok("the player is holding it, out of the machine's reach",
		player.carry.held() == box and box.docked_in == null)


	player.global_position = hatch.approach_point()
	player.force_update_transform()

	var took_at:= -1
	for i in CYCLE_TICKS:
		await get_tree().physics_frame
		if box.docked_in == hatch:
			took_at = i
			break
	_ok("the machine took it with no key pressed", took_at >= 0,
		"after %.2f s" % (float(maxi(took_at, 0)) * get_physics_process_delta_time()))
	_ok("...and out of the player's hands", not player.carry.is_carrying())


	var swallowed_at:= -1
	for i in CYCLE_TICKS:
		await get_tree().physics_frame
		if box.stored <= 0:
			swallowed_at = i
			break
	_ok("the container came up empty", box.stored <= 0, "%d left" % box.stored)
	_ok("...into the hopper rather than onto the floor",
		hatch.stored >= was_in_hopper + loaded,
		"%d strands in the machine" % hatch.stored)


	_ok("...with the container's own tap held shut",
		is_equal_approx(box.pour_boost, 0.0), "boost %.2f" % box.pour_boost)


	_ok("and it was held frozen static, so nothing inherited the sweep",
		box.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC)


	var back_at:= -1
	var picked:= false
	for i in CYCLE_TICKS:
		await get_tree().physics_frame


		if box.docked_in != null and player.carry.try_pick():
			picked = true
			player.carry.drop()
		if player.carry.held() == box:
			back_at = i
			break
	var held_for:= float(maxi(back_at, 0) - maxi(took_at, 0)) * get_physics_process_delta_time()
	_ok("the player could not take it back mid-cycle", not picked)
	_ok("the barrow came back into their hands", back_at >= 0)
	_ok("...and the machine did not keep them waiting", held_for < 2.5,
		"%.2f s from taken to returned" % held_for)
	_ok("the deck came back down", not hatch.is_busy())
	_ok("and put the boost back", is_equal_approx(box.pour_boost, 1.0))


	player.carry.drop()
	player.global_position = hatch.approach_point() + Vector3(0.0, 0.0, 9.0)
	player.force_update_transform()
	for i in SETTLE:
		await get_tree().physics_frame


	print("\n=== where the hay went ===")
	var live: LiveStrandManager = world.live
	for i in DRAIN_TICKS:
		await get_tree().physics_frame
		if i % 480 == 0:
			print("  %+5.1f s   in the machine %5d   sold %5d   live %4d   over the belt %4d   in the gap %4d"
				% [float(i) * get_physics_process_delta_time(), hatch.stored,
					_sold_strands, live.active_count(),
					_over_the_belt(live), _in_the_gap(live)])
		if hatch.stored <= 0 and _sold_strands >= loaded:
			break
	print("  loaded %d, the stand bought %d, %d still in the machine"
		% [loaded, _sold_strands, hatch.stored])
	_where_is_the_gap(live)
	_ok("the hopper emptied itself", hatch.stored <= 0,
		"%d strands left in it" % hatch.stored)


	_ok("most of it reached the till", _sold_strands > loaded / 2,
		"%d of %d" % [_sold_strands, loaded])


	props.remove(box)
	for i in SETTLE:
		await get_tree().physics_frame
	return _sold_strands


func _over_the_belt(live: LiveStrandManager) -> int:
	var stand: HaySellingStand = world.stand
	var n:= 0
	for b: RigidBody3D in live._active:
		var p:= stand.to_local(b.global_position)
		if p.x > BELT_X0 - 0.3 and p.x < 2.0 and absf(p.z - BELT_Z) < BELT_HALF and p.y > 0.1:
			n += 1
	return n


func _bin_strands(tip: DumpHatch) -> int:
	var load_node:= tip.find_child("Hopper_Load", true, false) as MultiMeshInstance3D
	if load_node == null or load_node.multimesh == null:
		return -1
	return load_node.multimesh.visible_instance_count


func _in_the_gap(live: LiveStrandManager) -> int:
	var stand: HaySellingStand = world.stand
	var n:= 0
	for b: RigidBody3D in live._active:
		var p:= stand.to_local(b.global_position)
		if p.z >= BELT_Z + BELT_HALF and p.z < SEAT_Z + 0.4 and absf(p.x - SEAT_X) < 1.2:
			n += 1
	return n


func _where_is_the_gap(live: LiveStrandManager) -> void:
	var stand: HaySellingStand = world.stand
	var lo:= Vector3(999, 999, 999)
	var hi:= Vector3(-999, -999, -999)
	var mid:= Vector3.ZERO
	var n:= 0
	for b: RigidBody3D in live._active:
		var p:= stand.to_local(b.global_position)
		if p.z < BELT_Z + BELT_HALF or p.z > SEAT_Z + 0.4 or absf(p.x - SEAT_X) > 1.2:
			continue
		n += 1
		mid += p
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	if n == 0:
		print("  nothing is lying in the gap")
		return
	mid /= float(n)
	print("  %d strands lying in the gap, around (%.2f, %.2f, %.2f)"
		% [n, mid.x, mid.y, mid.z])
	print("  spread x %.2f..%.2f   y %.2f..%.2f   z %.2f..%.2f"
		% [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	print("  for reference: the belt deck is y 0.34 at z 3.05, the hinge is")
	print("  y %.2f at z %.2f, and the spout is over z %.2f"
		% [0.78, SEAT_Z, SEAT_Z - 0.76])


func _while_it_is_holding_one(near: DumpHatch) -> void:
	print("\n=== demolished with a load on it ===")
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	var spare: DumpHatch = builds.add_dump_hatch(
		near.global_position + Vector3(6.0, 0.0, 0.0), 0.0)
	await get_tree().physics_frame
	var thing: Carryable = props.spawn("bucket",
		Transform3D(Basis.IDENTITY, spare.approach_point() + Vector3(0, 0.4, 0)))
	var box:= thing as HayContainer
	if box == null:
		_ok("a bucket could be placed", false)
		return
	box.stored = box.capacity()
	var had:= box.stored
	spare.take(box)


	for i in 40:
		await get_tree().physics_frame
	_ok("the machine has it", box.docked_in == spare and spare.is_busy())

	builds.demolish(spare)
	await get_tree().physics_frame
	_ok("the bucket was handed back", box.docked_in == null)
	_ok("...unfrozen, so it falls rather than hanging there", not box.freeze)
	_ok("...and pourable at its own rate again",
		is_equal_approx(box.pour_boost, 1.0))


	_ok("...with its hay still in it", box.stored > 0,
		"%d of %d strands" % [box.stored, had])


	_ok("...and the player may pick it up", not player.carry._refused(box))
	props.remove(box)
	for i in SETTLE:
		await get_tree().physics_frame


func _a_belt_in_front(builds: BuildManager, stand: HaySellingStand) -> void:
	print("\n=== a belt a step in front of the spout ===")
	var props: PropManager = world.props
	var at:= stand.to_global(Vector3(SEAT_X + 16.0, 0.0, SEAT_Z + 14.0))
	var tip: DumpHatch = builds.add_dump_hatch(at, stand.global_rotation.y)
	for i in SETTLE:
		await get_tree().physics_frame


	var out:= - tip.global_transform.basis.z
	var side:= tip.global_transform.basis.x
	var line:= at + out * BELT_IN_FRONT
	var run: Conveyor = builds.add_conveyor(line - side * 4.0, line + side * 4.0)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok("a run is laid across the front of it", run != null)
	if run == null:
		builds.demolish(tip)
		return


	var arrow:= tip.throw_aim()
	_ok("the tipper carries a throw arrow", arrow != null)
	if arrow != null:
		var eye:= tip.to_global(Vector3(0.0, 1.7, 3.5))
		var look:= tip.to_global(Vector3(0.0, 0.8, 0.7)) - eye
		_ok("...which the crosshair finds on the machine",
			ThrowAim.under_crosshair(builds, eye, look) == arrow)


		ThrowAim.set_hovered(arrow)
		_ok("...and shows gray with its arc on a hover",
			arrow.mode() == ThrowAim.HOVER and arrow.arc_drawn())

		_ok("...coming down on the run", _off_the_line(arrow.landing(), line, side)
			< Cfg.BELT_WIDTH * 0.5 and absf(arrow.landing().y - line.y) < 0.15,
			"%.2f m off the centre line, %.2f m up"
			% [_off_the_line(arrow.landing(), line, side), arrow.landing().y - line.y])
		ThrowAim.set_hovered(null)


	tip._drive(DumpHatch.DUMP_FRACTION)
	var spout:= tip.spout_point()
	var aim: Vector3 = tip._aim_point(spout, out)
	tip._drive(0.0)
	_ok("the machine can see the run in front of it", aim.is_finite(),
		"spout is %.2f m short of the belt" % _off_the_line(spout, line, side))
	if aim.is_finite():
		_ok("...and aims at the deck rather than at the floor",
			_off_the_line(aim, line, side) < 0.05 and aim.y > line.y + 0.15,
			"%.2f m off the centre line, %.2f m above it"
			% [_off_the_line(aim, line, side), aim.y - line.y])


	var already:= { }
	for item: Carryable in props.items:
		if is_instance_valid(item) and item is HayWad:
			already [item] = true

	tip.stored = DumpHatch.WAD_STRANDS * 4
	tip._state = DumpHatch.State.DUMP_UP
	for i in CYCLE_TICKS:
		await get_tree().physics_frame
		if tip.stored <= 0:
			break
	_ok("the hopper emptied itself onto it", tip.stored <= 0,
		"%d strands left in it" % tip.stored)
	for i in DRAIN_TICKS / 8:
		await get_tree().physics_frame

	var on:= 0
	var off:= 0
	var worst:= 0.0
	for item: Carryable in props.items:
		if not is_instance_valid(item) or not (item is HayWad):
			continue
		if already.has(item):
			continue
		var d:= _off_the_line(item.global_position, line, side)
		if d < Cfg.BELT_WIDTH * 0.5:
			on += 1
		else:
			off += 1
			worst = maxf(worst, d)


	_ok("every wad landed on the run", off == 0 and on > 0,
		"%d on the belt, %d beside it%s"
		% [on, off, "" if off == 0 else ", worst %.2f m out" % worst])


	var behind:= at - out * BELT_IN_FRONT
	var back: Conveyor = builds.add_conveyor(behind - side * 4.0, behind + side * 4.0)
	builds.demolish(run)
	for i in SETTLE:
		await get_tree().physics_frame
	tip._drive(DumpHatch.DUMP_FRACTION)
	var back_aim: Vector3 = tip._aim_point(tip.spout_point(), out)
	tip._drive(0.0)
	_ok("...and ignores one built behind it", not back_aim.is_finite())

	builds.demolish(back)
	builds.demolish(tip)
	for i in SETTLE:
		await get_tree().physics_frame


func _a_belt_farther_out(builds: BuildManager, stand: HaySellingStand) -> void:
	print("\n=== a belt far enough out that the throw is a lob ===")
	var props: PropManager = world.props
	var at:= stand.to_global(Vector3(SEAT_X + 16.0, 0.0, SEAT_Z + 26.0))
	var tip: DumpHatch = builds.add_dump_hatch(at, stand.global_rotation.y)
	for i in SETTLE:
		await get_tree().physics_frame
	var out:= - tip.global_transform.basis.z
	var side:= tip.global_transform.basis.x
	var flat_out:= Vector3(out.x, 0.0, out.z).normalized()


	tip._drive(DumpHatch.DUMP_FRACTION)
	var lip:= tip.spout_point()
	tip._drive(0.0)
	var line:= Vector3(lip.x, at.y, lip.z) + flat_out * BELT_PAST_SPOUT


	var run: Conveyor = builds.add_conveyor(line - side * 2.0, line + side * 18.0)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok("a run is laid %.1f m past the spout" % BELT_PAST_SPOUT, run != null)
	if run == null:
		builds.demolish(tip)
		return


	tip._drive(DumpHatch.DUMP_FRACTION)
	var spout:= tip.spout_point()
	var aim: Vector3 = tip._aim_point(spout, out)
	tip._drive(0.0)
	_ok("the machine aims at it", aim.is_finite())
	if aim.is_finite():
		var throw: Vector3 = tip._arc_to(spout, aim)


		_ok("...with a throw that goes up first", throw.y > 0.0,
			"%.2f m/s up" % throw.y)
		var clear:= HayWad.clearance_for(DumpHatch.WAD_STRANDS / 2)
		var verdict:= BeltPath.pour_verdict(spout, throw, maxf(clear.x, clear.z) * 0.5)
		_ok("...and the belt sees that lob coming down on it",
			verdict != BeltPath.Pour.NO_BELT, "verdict %d" % verdict)
	var already:= { }
	for item: Carryable in props.items:
		if is_instance_valid(item) and item is HayWad:
			already [item] = true

	var thrown:= DumpHatch.WAD_STRANDS * 4
	tip.stored = thrown
	tip._state = DumpHatch.State.DUMP_UP
	for i in CYCLE_TICKS:
		await get_tree().physics_frame
		if tip.stored <= 0:
			break
	_ok("the hopper emptied itself onto it", tip.stored <= 0,
		"%d strands left in it" % tip.stored)
	for i in 120:
		await get_tree().physics_frame

	var aboard:= 0
	for i in run.run.count():
		aboard += run.run.strands_of(i)
	for rb in run.riders():
		if rb is HayWad:
			aboard += (rb as HayWad).strands
	var lying:= 0
	for item: Carryable in props.items:
		if is_instance_valid(item) and item is HayWad and not already.has(item) and not BeltPath.is_rider(item):
			lying += 1


	_ok("every strand thrown is aboard the run", aboard == thrown,
		"%d of %d aboard, %d wads lying loose" % [aboard, thrown, lying])
	_ok("...and no wad is lying about", lying == 0, "%d loose" % lying)

	builds.demolish(run)
	builds.demolish(tip)
	for i in SETTLE:
		await get_tree().physics_frame


func _off_the_line(p: Vector3, line: Vector3, side: Vector3) -> float:
	var flat:= Vector3(p.x - line.x, 0.0, p.z - line.z)
	var dir:= Vector3(side.x, 0.0, side.z).normalized()
	return (flat - dir * flat.dot(dir)).length()
