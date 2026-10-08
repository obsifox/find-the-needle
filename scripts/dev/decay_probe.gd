class_name DevDecayProbe
extends Node


var world: Node3D
var player: Player


const DUMP:= Vector3(-13.0, 0.6, -13.0)


const WATCH:= Vector3(14.0, 0.4, 14.0)


const BELT_A:= Vector3(13.0, 0.75, -13.0)
const BELT_B:= Vector3(13.0, 0.75, -8.0)


const RAKE_AT:= Vector3(-13.0, 0.0, 8.0)


const PAD_WADS:= 7


const ARM_AT:= Vector3(-6.0, 0.0, 15.0)


const RING_WADS:= 18
const RING_R:= [1.4, 2.2]

const SETTLE:= 30


const WAIT_FRAMES:= 4000

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = WATCH
	GameState.add_money(200000.0)


	var was_clean:= Cfg.auto_clean
	var was_clean_wait:= Cfg.auto_clean_seconds
	Cfg.auto_clean = false
	for i in SETTLE:
		await get_tree().process_frame

	await _check_cap_holds()
	await _check_hay_is_returned()
	await _check_the_countdown_never_climbs()
	await _check_bought_items_are_spared()
	await _check_busy_items_are_spared()
	await _check_a_working_pad_is_spared()
	await _check_an_arms_ring_is_budgeted()
	await _check_the_cap_is_a_hard_cap()
	await _check_new_product_survives_its_flight()
	await _check_the_player_sees_nothing_vanish()
	await _check_the_fold_is_seen()
	await _check_switch_off()
	await _check_auto_clean()
	await _check_pelletizer_clears_its_pad()
	await _check_options_page()
	await _check_the_tidy_button()
	await _check_the_quality_dial_moves_the_cap()


	Cfg.auto_clean = was_clean
	Cfg.auto_clean_seconds = was_clean_wait
	Cfg.save_settings()
	print("\n=== decay probe: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check_cap_holds() -> void:
	print("\n=== the cap ===")
	await _clear_yard()
	var want: int = Cfg.prop_cap + 40
	_fill("hay_wad", want, { "strands": 40 })
	_ok("filled past the cap", world.props.items.size() == want)

	var spun:= await _drain_until_settled()
	_ok("drains to the cap", world.props.items.size() == Cfg.prop_cap)
	_ok("stops at the cap, does not keep going",
		world.props.items.size() == Cfg.prop_cap)


	_ok("a settled yard costs nothing more", spun < WAIT_FRAMES)


	await _clear_yard()
	_fill("hay_bale", Cfg.prop_cap + 12, { "strands": 60 })
	await _drain_until_settled()
	_ok("bales are capped too", world.props.items.size() == Cfg.prop_cap)

	await _clear_yard()
	_fill("eco_brick", Cfg.prop_cap + 12, { "strands": 45 })
	await _drain_until_settled()
	_ok("eco bricks are capped too", world.props.items.size() == Cfg.prop_cap)


func _check_hay_is_returned() -> void:
	print("\n=== conservation ===")
	await _clear_yard()
	var over:= 20
	var each:= 40
	_fill("hay_wad", Cfg.prop_cap + over, { "strands": each })
	var before:= GameState.hay_total
	await _drain_until_settled()
	var credited:= GameState.hay_total - before
	_ok("every folded wad puts its hay back",
		is_equal_approx(credited, float(over * each)))


	await _clear_yard()
	_fill("hay_bale", Cfg.prop_cap + over, { "strands": 60 })
	before = GameState.hay_total
	await _drain_until_settled()
	credited = GameState.hay_total - before
	_ok("a bale is credited its contents, not its premium",
		is_equal_approx(credited, float(over * 60)))
	_ok("...which is strictly less than it was worth at the stand",
		Tech.bale_value_ratio() <= 1.0
		or credited < float(over * 60) * Tech.bale_value_ratio())


func _check_the_countdown_never_climbs() -> void:
	print("\n=== the countdown ===")
	await _clear_yard()
	var was_mode: int = Cfg.hay_readout
	Cfg.hay_readout = Cfg.HayReadout.AMOUNT
	_fill("hay_wad", Cfg.prop_cap + 30, { "strands": 40 })

	var ledger_before:= GameState.hay_total
	var shown_before:= GameState.hay_never_dug()
	var text_before:= Hud.hay_left_amount()
	await _drain_until_settled()
	_ok("the drain still puts the hay back on the books",
		GameState.hay_total > ledger_before)
	_ok("...and the countdown does not move for it",
		is_equal_approx(GameState.hay_never_dug(), shown_before))
	_ok("...so the line in the corner reads what it read before",
		Hud.hay_left_amount() == text_before)


	var scoop:= 500.0
	GameState.remove_hay(scoop)
	_ok("a scoop still takes it straight down",
		is_equal_approx(GameState.hay_never_dug(), shown_before - scoop))


	var shown:= GameState.hay_never_dug()
	var written:= GameState.to_dict()
	GameState.hay_returned = 0.0
	GameState.from_dict(written)
	_ok("the offset is written to the save and read back",
		is_equal_approx(GameState.hay_never_dug(), shown))

	Cfg.hay_readout = was_mode


func _check_bought_items_are_spared() -> void:
	print("\n=== bought items ===")
	await _clear_yard()
	_fill("hay_wad", Cfg.prop_cap + 30, { "strands": 40 })
	var bucket: Carryable = world.props.spawn("bucket",
		Transform3D(Basis(), DUMP + Vector3(2.0, 0.0, 0.0)))
	_ok("a bucket holds no hay of its own",
		bucket != null and bucket.hay_strands() == 0)
	await _drain_until_settled()
	_ok("the bucket is still there",
		bucket != null and is_instance_valid(bucket)
		and world.props.items.has(bucket))


func _check_busy_items_are_spared() -> void:
	print("\n=== items in use ===")
	await _clear_yard()
	_fill("hay_wad", Cfg.prop_cap + 30, { "strands": 40 })


	var claimed: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(1.0, 0.0, 0.0)), { "strands": 40 })
	claimed.set_meta(PropManager.META_CLAIM, world.get_instance_id())


	var riding: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(1.6, 0.0, 0.0)), { "strands": 40 })
	riding.set_meta(LiveStrandManager.META_RIDER, true)

	await _drain_until_settled()
	_ok("a claimed wad is spared", world.props.items.has(claimed))
	_ok("a wad on a belt is spared", world.props.items.has(riding))


	var stale: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(2.4, 0.0, 0.0)), { "strands": 40 })
	var ghost:= Node.new()
	var ghost_id:= ghost.get_instance_id()
	ghost.free()
	stale.set_meta(PropManager.META_CLAIM, ghost_id)


	LiveStrandManager.release_hold(stale)
	world.props.player_ref = null
	var spared: bool = world.props._may_retire(stale, Vector3.ZERO,
		Cfg.PROP_KEEP_DIST * Cfg.PROP_KEEP_DIST)
	world.props.player_ref = player
	_ok("a claim by a dead machine does not protect", spared)


func _check_a_working_pad_is_spared() -> void:
	print("\n=== the ground a machine is working ===")
	await _clear_yard()
	var rake: PistonRake = world.builds.add_piston_rake(RAKE_AT, 0.0)
	_ok("stood a rake in the far corner", rake != null)
	if rake == null:
		return
	await get_tree().process_frame
	var pad:= rake.discharge_spot()
	print("  the rake throws at %.1f, %.1f, and the player is %.1f m away"
		% [pad.x, pad.z, pad.distance_to(WATCH)])


	_ok("...which is well outside the radius the drain leaves alone",
		pad.distance_to(WATCH) > Cfg.PROP_KEEP_DIST * 1.5)


	_fill("hay_wad", Cfg.prop_cap + 30, { "strands": 40 })
	var heap: Array [Carryable] = []
	for i in PAD_WADS:
		var a:= TAU * float(i) / float(PAD_WADS)
		var at:= pad + Vector3(cos(a) * 0.7, 0.0, sin(a) * 0.7)
		var w: Carryable = world.props.spawn("hay_wad",
			Transform3D(Basis(), at), { "strands": 40 })
		if w == null:
			continue


		LiveStrandManager.release_hold(w)
		heap.append(w)
	_ok("piled %d wads on the pad it throws at" % heap.size(),
		heap.size() == PAD_WADS)

	await _drain_until_settled()
	var left:= 0
	for w in heap:
		if is_instance_valid(w):
			left += 1
	print("  wads left on the pad     : %d of %d" % [left, heap.size()])
	print("  props left in the yard   : %d  (cap %d)"
		% [world.props.items.size(), Cfg.prop_cap])
	_ok("the heap on the working pad is untouched", left == heap.size())


	_ok("...and the yard still came down to its cap",
		world.props.items.size() == Cfg.prop_cap)


	world.builds.demolish(rake)
	await get_tree().process_frame
	var keep2: float = Cfg.PROP_KEEP_DIST * Cfg.PROP_KEEP_DIST
	var still: Carryable = null
	for w in heap:
		if is_instance_valid(w):
			still = w
			break
	_ok("...and a demolished rake stops sheltering it",
		still != null and world.props._may_retire(still, WATCH, keep2))
	await _clear_yard()


func _check_an_arms_ring_is_budgeted() -> void:
	print("\n=== the ring an arm reaches into ===")
	await _clear_yard()
	var arm: RoboticArm = world.builds.add_robotic_arm(ARM_AT, 0.0)
	_ok("stood an arm in the fourth corner", arm != null)
	if arm == null:
		return
	await get_tree().process_frame
	var ring: float = arm.reach_m() + PropManager.WORK_SPOT_R
	print("  the arm reaches %.2f m, so its ring is %.2f m, and the player is %.1f m away"
		% [arm.reach_m(), ring, ARM_AT.distance_to(WATCH)])


	_ok("...and the whole ring is outside the radius the drain leaves alone",
		ARM_AT.distance_to(WATCH) > Cfg.PROP_KEEP_DIST + ring)


	var heap: Array [Carryable] = []
	for i in RING_WADS:
		var r: float = float(RING_R [i % RING_R.size()])
		var a:= TAU * float(i) / float(RING_WADS)
		var at:= ARM_AT + Vector3(cos(a) * r, 0.6, sin(a) * r)
		var w: Carryable = world.props.spawn("hay_wad",
			Transform3D(Basis(), at), { "strands": 40 })
		if w == null:
			continue


		LiveStrandManager.release_hold(w)
		heap.append(w)
	_ok("piled %d wads in its ring" % heap.size(), heap.size() == RING_WADS)


	_fill("hay_wad", Cfg.prop_cap + 30, { "strands": 40 })

	await _drain_until_settled()
	var left:= 0
	for w in heap:
		if is_instance_valid(w):
			left += 1
	print("  wads left in the ring    : %d of %d  (budget %d)"
		% [left, heap.size(), Cfg.ARM_PAD_WADS])
	print("  props left in the yard   : %d  (cap %d)"
		% [world.props.items.size(), Cfg.prop_cap])

	_ok("the ring shelters its budget and no more", left == Cfg.ARM_PAD_WADS)


	var kept_newest:= true
	for i in heap.size():
		var want: bool = i >= heap.size() - Cfg.ARM_PAD_WADS
		if is_instance_valid(heap [i]) != want:
			kept_newest = false
	_ok("...and they are the newest ones in it", kept_newest)


	_ok("...and the yard still came down to its cap",
		world.props.items.size() == Cfg.prop_cap)


	world.builds.demolish(arm)
	await get_tree().process_frame
	var keep2: float = Cfg.PROP_KEEP_DIST * Cfg.PROP_KEEP_DIST
	var still_there: Carryable = null
	for w in heap:
		if is_instance_valid(w):
			still_there = w
			break
	_ok("...and a demolished arm stops sheltering the six it kept",
		still_there != null and world.props._may_retire(still_there, WATCH, keep2))
	await _clear_yard()


func _check_the_cap_is_a_hard_cap() -> void:
	print("\n=== nothing left that the courtesies allow ===")
	await _clear_yard()


	var was_cap: int = Cfg.prop_cap
	Cfg.prop_cap = 20
	var arm: RoboticArm = world.builds.add_robotic_arm(ARM_AT, 0.0)
	_ok("stood an arm in the fourth corner again", arm != null)
	if arm == null:
		Cfg.prop_cap = was_cap
		return
	await get_tree().process_frame


	var made: Array [Carryable] = []
	for i in RING_WADS:
		var r: float = float(RING_R [i % RING_R.size()])
		var a:= TAU * float(i) / float(RING_WADS)
		var w: Carryable = world.props.spawn("hay_wad", Transform3D(Basis(),
			ARM_AT + Vector3(cos(a) * r, 0.6, sin(a) * r)), { "strands": 40 })
		if w != null:
			LiveStrandManager.release_hold(w)
			made.append(w)
	for i in RING_WADS:
		var w: Carryable = world.props.spawn("hay_wad", Transform3D(Basis(),
			player.global_position + Vector3(float(i % 6) * 0.5 - 1.2, 0.6,
				1.5 + float(i / 6) * 0.6)), { "strands": 40 })
		if w != null:
			LiveStrandManager.release_hold(w)
			made.append(w)


	var bucket: Carryable = world.props.spawn("bucket",
		Transform3D(Basis(), ARM_AT + Vector3(0.9, 0.6, 0.0)))
	var find: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), ARM_AT + Vector3(-0.9, 0.6, 0.0)),
		{ "strands": 40, "needle": 0 })
	if find != null:
		LiveStrandManager.release_hold(find)
	_ok("a yard of %d, all of it sheltered, plus a bucket and a find"
		% made.size(), made.size() == RING_WADS * 2
		and bucket != null and find != null and find.holds_needle())
	print("  props in the yard now    : %d  (cap %d)"
		% [world.props.yard_count(), Cfg.prop_cap])

	await _drain_until_settled()
	print("  props left in the yard   : %d" % world.props.yard_count())


	_ok("the cap is reached anyway", world.props.yard_count() <= Cfg.prop_cap)
	_ok("...and the bucket is still there",
		is_instance_valid(bucket) and world.props.items.has(bucket))
	_ok("...and so is the block with the needle in it",
		is_instance_valid(find) and world.props.items.has(find))


	var near_left:= 0
	var far_left:= 0
	for w in made:
		if not is_instance_valid(w):
			continue
		if w.global_position.distance_to(player.global_position) < Cfg.PROP_KEEP_DIST:
			near_left += 1
		else:
			far_left += 1
	print("  left: %d underfoot, %d out at the arm" % [near_left, far_left])
	_ok("...and it worked the far end of the yard first", far_left == 0)

	world.builds.demolish(arm)
	Cfg.prop_cap = was_cap
	await _clear_yard()


func _check_new_product_survives_its_flight() -> void:
	print("\n=== a brick between the muzzle and the deck ===")
	await _clear_yard()


	_fill("hay_wad", Cfg.prop_cap + 30, { "strands": 40 })
	for item in world.props.items:
		item.set_meta(PropManager.META_CLAIM, world.get_instance_id())

	var keep2: float = Cfg.PROP_KEEP_DIST * Cfg.PROP_KEEP_DIST
	var fired: Carryable = world.props.spawn("eco_brick",
		Transform3D(Basis(), DUMP + Vector3(0.0, 2.0, -2.0)), { "strands": 45 })
	_ok("a brick that has just been fired is not litter",
		not world.props._may_retire(fired, WATCH, keep2))


	LiveStrandManager.release_hold(fired)
	_ok("...and is the drain's again once the grace lapses",
		world.props._may_retire(fired, WATCH, keep2))
	world.props.remove(fired)


	var belt: Conveyor = world.builds.add_conveyor(BELT_A, BELT_B)
	_ok("laid a run to land on", belt != null and belt.path_length() > 1.0)
	if belt == null:
		return


	belt.set_drive_speed(0.0)
	for i in SETTLE:
		await get_tree().process_frame

	var landed: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
		belt._point_at(belt.path_length() * 0.5) + Vector3(0.0, 0.25, 0.0)),
		{ "strands": 45 })


	for i in 40:
		if is_instance_valid(landed):
			landed.linear_velocity.y = -0.8
		await get_tree().physics_frame


	_ok("the brick is still on the deck it landed on",
		is_instance_valid(landed) and world.props.items.has(landed))
	if not is_instance_valid(landed):
		return


	LiveStrandManager.release_hold(landed)
	for i in 4:
		if is_instance_valid(landed):
			landed.linear_velocity.y = -0.8
		await get_tree().physics_frame
	_ok("a brick still bouncing on a deck is held",
		is_instance_valid(landed) and LiveStrandManager.is_on_hold(landed))
	_ok("...and is not aboard yet",
		is_instance_valid(landed) and not BeltPath.is_rider(landed))
	_ok("...so the drain leaves it where it landed",
		is_instance_valid(landed)
		and not world.props._may_retire(landed, WATCH, keep2))
	if not is_instance_valid(landed):
		return


	for i in 90:
		await get_tree().physics_frame


	var aboard:= false
	for row in range(belt.run.first(), belt.run.first() + belt.run.count()):
		if BeltRun.ITEM_IDS [belt.run.kind_of(row)] == "eco_brick":
			aboard = true
	_ok("...and the belt takes it aboard once it settles",
		aboard or (is_instance_valid(landed) and BeltPath.is_rider(landed)))


func _check_the_player_sees_nothing_vanish() -> void:
	print("\n=== under the player's nose ===")
	await _clear_yard()

	_fill("hay_wad", Cfg.prop_cap + 40, { "strands": 40 })
	var near: Array [Carryable] = []
	for i in 6:
		near.append(world.props.spawn("hay_wad",
			Transform3D(Basis(), player.global_position
				+ Vector3(float(i) * 0.5 - 1.2, 0.6, 1.5)), { "strands": 40 }))
	await _drain_until_settled()
	var kept:= 0
	for item in near:
		if is_instance_valid(item) and world.props.items.has(item):
			kept += 1
	_ok("every wad at the player's feet is still there", kept == near.size())
	_ok("...and the yard came down anyway",
		world.props.items.size() <= Cfg.prop_cap + near.size())


func _check_the_fold_is_seen() -> void:
	print("\n=== the fold ===")
	await _clear_yard()


	var item: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), DUMP), { "strands": 40 })
	var fold:= PropFold.play(item, world.props)
	_ok("a doomed prop hands its model over", fold != null)
	_ok("...and keeps none of it", item.detach_model() == null)
	_ok("...so the mesh is the fold's to draw now",
		fold.find_children("*", "MeshInstance3D", true, false).size() == 1)
	world.props.remove(item)


	_ok("...while the body itself goes on schedule", item.is_queued_for_deletion())
	_ok("...and the shrink is no part of the yard", world.props.items.is_empty())

	fold._process(PropFold.SWELL)
	var swelled: float = fold.scale.x
	_ok("it swells before it goes", swelled > 1.0)
	fold._process(PropFold.SHRINK * 0.5)
	var half: float = fold.scale.x
	_ok("...then comes down", half < swelled)
	_ok("...turning as it does", absf(fold.rotation.y) > 0.01)
	_ok("...and stays standing where the prop stood",
		fold.global_position.distance_to(DUMP) < 0.01)
	fold._process(PropFold.SHRINK * 0.5)
	_ok("...and takes itself away when it lands", fold.is_queued_for_deletion())


	await _clear_yard()
	_fill("hay_wad", Cfg.prop_cap + 6, { "strands": 40 })
	var seen:= 0
	for i in WAIT_FRAMES:
		await get_tree().process_frame
		seen = maxi(seen, _folds().size())
		if world.props.items.size() <= Cfg.prop_cap and seen > 0:
			break
	_ok("a real drain pass leaves a shrink behind it", seen > 0)
	_ok("...over a yard that is already back under the cap",
		world.props.items.size() <= Cfg.prop_cap)
	var left:= WAIT_FRAMES
	for i in WAIT_FRAMES:
		await get_tree().process_frame
		if _folds().is_empty():
			left = i
			break
	_ok("...and clears up after itself", left < WAIT_FRAMES)


	var last: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), DUMP), { "strands": 40 })
	PropFold.play(last, world.props)
	_ok("a fold is standing", _folds().size() == 1)
	world.props.clear()
	await get_tree().process_frame
	_ok("...and a yard cleared for a load takes it with it", _folds().is_empty())


func _check_switch_off() -> void:
	print("\n=== the switch ===")
	await _clear_yard()
	Cfg.prop_decay = false
	var want: int = Cfg.prop_cap + 25
	_fill("hay_wad", want, { "strands": 40 })
	for i in 240:
		await get_tree().process_frame
	_ok("nothing is folded away with the cap off",
		world.props.items.size() == want)
	Cfg.prop_decay = true
	await _clear_yard()


func _check_auto_clean() -> void:
	print("\n=== the auto cleaner ===")
	await _clear_yard()
	var was_decay:= Cfg.prop_decay
	var was_wait:= Cfg.auto_clean_seconds
	Cfg.prop_decay = false
	Cfg.auto_clean_seconds = 2.0


	world.props.clean_blocked = false


	Cfg.auto_clean = false
	_fill("hay_wad", 4, { "strands": 40 })
	for i in 300:
		await get_tree().process_frame
	_ok("with the cleaner off, still hay stays", world.props.items.size() == 4)
	await _clear_yard()

	Cfg.auto_clean = true
	_fill("hay_wad", 4, { "strands": 40 })
	var bale: Carryable = world.props.spawn("hay_bale",
		Transform3D(Basis(), DUMP + Vector3(0.0, 0.0, 3.0)), { "strands": 60 })
	var brick: Carryable = world.props.spawn("eco_brick",
		Transform3D(Basis(), DUMP + Vector3(1.0, 0.0, 3.0)), { "strands": 45 })
	var bucket: Carryable = world.props.spawn("bucket",
		Transform3D(Basis(), DUMP + Vector3(2.0, 0.0, 3.0)))
	var mover: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(4.0, 0.0, 3.0)), { "strands": 40 })
	for item: Carryable in [bale, brick, mover]:
		if item != null:
			LiveStrandManager.release_hold(item)
	_ok("the case's props all spawned",
		bale != null and brick != null and bucket != null and mover != null)
	var before:= GameState.hay_total


	var frames:= 0
	var early_ok:= true
	while frames < 900:
		await get_tree().process_frame
		frames += 1
		if frames % 60 == 0 and is_instance_valid(mover):
			var x:= 4.0 + float(frames / 60 % 2)
			mover.warp(Transform3D(Basis(), DUMP + Vector3(x, 0.0, 3.0)))
		if frames == 45 and world.props.items.size() != 8:
			early_ok = false
	_ok("nothing goes before the wait is up", early_ok)
	_ok("wads left still are cleaned up", world.props.count_of("hay_wad") == 1)
	_ok("so is a bale", not is_instance_valid(bale) or not world.props.items.has(bale))
	_ok("so is a brick", not is_instance_valid(brick) or not world.props.items.has(brick))
	_ok("a bought bucket is never taken",
		is_instance_valid(bucket) and world.props.items.has(bucket))
	_ok("a load that keeps being moved is never taken",
		is_instance_valid(mover) and world.props.items.has(mover))
	_ok("the hay in what it took goes back on the books",
		is_equal_approx(GameState.hay_total - before, float(4 * 40 + 60 + 45)))

	Cfg.auto_clean = false
	Cfg.auto_clean_seconds = was_wait
	Cfg.prop_decay = was_decay
	await _clear_yard()


func _check_pelletizer_clears_its_pad() -> void:
	print("\n=== the pelletizer's pad ===")
	await _clear_yard()
	var mill:= HayPelletizer.new()
	world.builds.add_child(mill)
	mill.setup(Vector3(6.0, 0.0, -13.0), 0.0)
	mill.props = world.props
	for i in SETTLE:
		await get_tree().process_frame


	_ok("the mill built its launcher", mill._launcher != null)


	var pad:= mill.throw_target()
	var laid: Array [Carryable] = []
	var n:= Cfg.PELLETIZER_PAD_BRICKS + 4
	for i in n:
		var ring:= 0.35 if i % 2 == 0 else 0.8
		var a:= TAU * float(i) / float(n)
		var brick: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
			pad + Vector3(cos(a) * ring, 0.15, sin(a) * ring)), { "strands": 45 })
		if brick != null:
			LiveStrandManager.release_hold(brick)
			laid.append(brick)
	_ok("the heap was laid (%d bricks)" % laid.size(), laid.size() == n)


	laid [0].needle_index = 0
	for i in SETTLE:
		await get_tree().process_frame
	_ok("a heap past the limit stands on the pad (%d loose)" % _loose_on_pad(pad),
		_loose_on_pad(pad) > Cfg.PELLETIZER_PAD_BRICKS)

	var before:= GameState.hay_total
	mill.starved_for = 0.0
	mill.stored = Tech.pellet_brick_strands()
	for i in 60:
		await get_tree().process_frame
		if mill.is_running():
			break
	_ok("a full pad does not stop the mill", mill.is_running())
	_ok("...and puts no sign over it", mill.alert_reason() == "")

	var expect_gone:= n - 1 - Cfg.PELLETIZER_PAD_BRICKS
	var gone:= 0
	var kept:= 0
	for i in range(1, n):
		var here: bool = is_instance_valid(laid [i]) and world.props.items.has(laid [i])
		if i <= expect_gone and not here:
			gone += 1
		if i > expect_gone and here:
			kept += 1
	_ok("the oldest bricks were folded away (%d of %d)" % [gone, expect_gone],
		gone == expect_gone)
	_ok("...and the newest %d stayed (%d)" % [Cfg.PELLETIZER_PAD_BRICKS, kept],
		kept == Cfg.PELLETIZER_PAD_BRICKS)
	_ok("...but never the one with a needle in it",
		is_instance_valid(laid [0]) and world.props.items.has(laid [0]))
	_ok("...with their hay handed back (%.0f)" % (GameState.hay_total - before),
		is_equal_approx(GameState.hay_total - before, 45.0 * expect_gone))
	_ok("...leaving %d loose on the pad (%d)" % [Cfg.PELLETIZER_PAD_BRICKS,
		_loose_on_pad(pad)], _loose_on_pad(pad) == Cfg.PELLETIZER_PAD_BRICKS)


	var bricks: int = world.props.count_of("eco_brick")
	for i in 900:
		await get_tree().process_frame
		if world.props.count_of("eco_brick") > bricks:
			break
	_ok("...and throws its brick onto the heap",
		world.props.count_of("eco_brick") > bricks)

	if is_instance_valid(laid [0]):
		laid [0].needle_index = -1
	mill.queue_free()
	await _clear_yard()


func _loose_on_pad(pad: Vector3) -> int:
	var loose:= 0
	for item in world.props.items:
		if is_instance_valid(item) and item.hay_strands() > 0 and item.global_position.distance_to(pad) < PropManager.WORK_SPOT_R and not world.props.is_spoken_for(item):
			loose += 1
	return loose


func _check_options_page() -> void:
	print("\n=== the gameplay page ===")


	var was_cap:= Cfg.prop_cap
	var was_on:= Cfg.prop_decay


	var was_cap_user: Variant = Cfg._prop_cap_user

	var was_belt_cap:= Cfg.belt_cap
	var was_belt_on:= Cfg.belt_decay

	var layer:= CanvasLayer.new()
	add_child(layer)
	var panel:= OptionsPanel.new()
	layer.add_child(panel)
	await get_tree().process_frame

	_ok("the page is on the tab bar", OptionsPanel.TABS.has("GAMEPLAY"))
	var page: Control = panel._pages [OptionsPanel.TABS.find("GAMEPLAY")]
	_ok("...and it has a page behind it", page != null)

	var sliders: Array [Node] = []
	var pills: Array [Node] = []
	_gather(page, sliders, pills)


	_ok("both caps and the cleaner have a slider", sliders.size() == 3)
	_ok("all six switches have a button (%d)" % pills.size(), pills.size() == 6)


	var slider:= _slider_named(page, "Items allowed")
	var pill:= _pill_named(page, "Cap the yard")
	var missions_pill:= _pill_named(page, "Show missions")
	_ok("each switch is on a row that names it",
		pill != null and missions_pill != null)
	if slider == null or pill == null or missions_pill == null:
		layer.queue_free()
		return
	_ok("the slider opens on the live value", int(slider.value) == Cfg.prop_cap)
	_ok("...between the two limits Cfg names",
		int(slider.min_value) == Cfg.PROP_CAP_MIN
		and int(slider.max_value) == Cfg.PROP_CAP_MAX)


	slider.value = 145.0
	await get_tree().process_frame
	_ok("dragging the slider moves the cap", Cfg.prop_cap == 145)
	pill.button_pressed = false
	await get_tree().process_frame
	_ok("the switch turns the cap off", not Cfg.prop_decay)
	pill.button_pressed = true
	await get_tree().process_frame
	_ok("...and back on", Cfg.prop_decay)


	Cfg.set_prop_cap(999999)
	_ok("a cap past the ceiling is clamped", Cfg.prop_cap == Cfg.PROP_CAP_MAX)
	Cfg.set_prop_cap(-5)
	_ok("...and one under the floor", Cfg.prop_cap == Cfg.PROP_CAP_MIN)


	_fill("hay_wad", 7, { "strands": 40 })
	await get_tree().process_frame
	var verdict:= panel._yard_verdict()
	_ok("the note counts the yard it is describing",
		verdict.contains("%d out there now" % world.props.yard_count()))


	panel._select_tab(OptionsPanel.TABS.find("GAMEPLAY"))
	_ok("...and the line on the page catches up when the tab is opened",
		panel._yard_note.text.contains("%d out there now" % world.props.yard_count()))
	panel.visible = false
	_fill("hay_wad", 3, { "strands": 40 })
	await get_tree().process_frame
	panel.visible = true
	_ok("...and again when the panel is shown with the tab already open",
		panel._yard_note.text.contains("%d out there now" % world.props.yard_count()))
	Cfg.prop_decay = false
	_ok("...and says so plainly when the cap is off",
		not panel._yard_verdict().contains("out there now"))
	Cfg.prop_decay = true


	var belt_slider:= _slider_named(page, "Loads allowed")
	var belt_pill:= _pill_named(page, "Cap the belts")
	var belt_rows:= belt_slider != null and belt_pill != null
	_ok("the belts have a row of their own", belt_rows)
	if belt_rows:
		_ok("...opening on the live value", int(belt_slider.value) == Cfg.belt_cap)
		_ok("...between the two limits Cfg names",
			int(belt_slider.min_value) == Cfg.BELT_CAP_MIN
			and int(belt_slider.max_value) == Cfg.BELT_CAP_MAX)
		belt_slider.value = 85.0
		await get_tree().process_frame
		_ok("...and dragging it moves the belt cap", Cfg.belt_cap == 85)
		belt_pill.button_pressed = false
		await get_tree().process_frame
		_ok("the switch turns the belt cap off", not Cfg.belt_decay)
		_ok("...and the note says so plainly",
			panel._belt_verdict().contains("No limit"))
		belt_pill.button_pressed = true
		await get_tree().process_frame
		_ok("...and back on", Cfg.belt_decay)
		_ok("...with the note counting what the belts are carrying",
			panel._belt_verdict().contains("riding now"))
		Cfg.set_belt_cap(999999)
		_ok("a belt cap past the ceiling is clamped",
			Cfg.belt_cap == Cfg.BELT_CAP_MAX)
		Cfg.set_belt_cap(-5)
		_ok("...and one under the floor", Cfg.belt_cap == Cfg.BELT_CAP_MIN)


	var was_missions:= Cfg.show_missions
	var was_step:= GameState.mission_index
	missions_pill.button_pressed = false
	await get_tree().process_frame
	_ok("the mission switch puts the card away", not Cfg.show_missions)
	_ok("...without touching the step the player is on",
		GameState.mission_index == was_step)


	_ok("...and the note says the chain is still running behind it",
		panel._mission_verdict().contains("progress is kept"))
	missions_pill.button_pressed = true
	await get_tree().process_frame
	_ok("...and brings it back", Cfg.show_missions)
	_ok("...reading out the step it is on",
		panel._mission_verdict().contains("Step "))

	layer.queue_free()
	Cfg.prop_cap = was_cap
	Cfg._prop_cap_user = was_cap_user
	Cfg.prop_decay = was_on
	Cfg.belt_cap = was_belt_cap
	Cfg.belt_decay = was_belt_on


	Cfg.save_settings()
	Cfg.set_show_missions(was_missions)
	Cfg.save_settings()
	await _clear_yard()


func _check_the_tidy_button() -> void:
	print("\n=== the tidy button ===")
	await _clear_yard()


	var props: PropManager = world.props
	var live: LiveStrandManager = props.live

	var layer:= CanvasLayer.new()
	add_child(layer)
	var panel:= OptionsPanel.new()
	layer.add_child(panel)
	await get_tree().process_frame
	var page: Control = panel._pages [OptionsPanel.TABS.find("GAMEPLAY")]
	panel._select_tab(OptionsPanel.TABS.find("GAMEPLAY"))


	var button:= _button_named(page, "PUT LOOSE HAY BACK ON THE PILE")
	_ok("the yard card carries a tidy button", button != null)
	if button == null:
		layer.queue_free()
		return
	_ok("...and it is alive, because there is a yard behind it", not button.disabled)


	var bucket: Carryable = props.spawn("bucket",
		Transform3D(Basis(), DUMP + Vector3(0.0, 0.0, -2.5)))
	var held: Carryable = props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(0.6, 0.0, -2.5)), { "strands": 40 })
	held.pick_up()
	var needled: Carryable = props.spawn("hay_bale",
		Transform3D(Basis(), DUMP + Vector3(1.2, 0.0, -2.5)),
		{ "strands": 60, "needle": 3 })
	var riding: Carryable = props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(1.8, 0.0, -2.5)), { "strands": 40 })
	riding.set_meta(LiveStrandManager.META_RIDER, true)
	var claimed: Carryable = props.spawn("hay_wad",
		Transform3D(Basis(), DUMP + Vector3(2.4, 0.0, -2.5)), { "strands": 40 })
	claimed.set_meta(PropManager.META_CLAIM, world.get_instance_id())
	var guarded: Array [Carryable] = [bucket, held, needled, riding, claimed]
	for item in guarded:


		LiveStrandManager.release_hold(item)


	const LITTER:= 20
	_fill("hay_wad", LITTER, { "strands": 40 })


	var litter: Array [int] = []
	for item in props.items:
		if not guarded.has(item):
			litter.append(item.get_instance_id())
	_ok("twenty wads are lying in the corner", litter.size() == LITTER)
	player.global_position = DUMP + Vector3(-3.0, 0.0, 1.5)
	props.player_ref = player
	await get_tree().process_frame

	var straws_before: int = live.active_count()
	live.spawn(DUMP + Vector3(0.0, 1.0, 2.0), Basis(), Vector3.ZERO,
		Color.WHITE)
	live.spawn(DUMP + Vector3(0.2, 1.0, 2.0), Basis(), Vector3.ZERO,
		Color.WHITE)
	_ok("two straws are loose on the floor",
		live.active_count() == straws_before + 2)


	var before: int = props.items.size()
	var ledger_before: float = GameState.hay_total
	button.pressed.emit()
	await get_tree().process_frame
	_ok("one press folds nothing", props.items.size() == before)
	_ok("...and the hay is where it was",
		is_equal_approx(GameState.hay_total, ledger_before))
	_ok("...and the button is asking instead", panel._sweep_armed)
	_ok("...in words, on the card",
		button.text == "YES, PUT IT ALL BACK"
		and panel._sweep_note.text.contains("cannot be undone"))


	panel._select_tab(OptionsPanel.TABS.find("AUDIO"))
	panel._select_tab(OptionsPanel.TABS.find("GAMEPLAY"))
	_ok("...and reopening the page forgets it was asked", not panel._sweep_armed)
	_ok("...so the label is back to the plain one",
		button.text == "PUT LOOSE HAY BACK ON THE PILE")


	button.pressed.emit()
	button.pressed.emit()
	await get_tree().process_frame
	_ok("the litter is gone", props.items.size() == before - LITTER)


	var left:= 0
	for id in litter:
		if instance_from_id(id) != null:
			left += 1
	_ok("...including the wads under the player's own boots", left == 0)
	_ok("...and the straw with it",
		live.active_count() == straws_before)


	var want:= float(LITTER * 40) + 2.0
	print("  the ledger moved by %.1f, and the litter held %.1f"
		% [GameState.hay_total - ledger_before, want])
	_ok("...and every strand of it is back on the books",
		GameState.hay_total >= ledger_before + want - 0.001)

	_ok("the bucket is still there", props.items.has(bucket))
	_ok("the wad in the player's hands is still there",
		props.items.has(held))
	_ok("the bale with a needle in it is still there",
		props.items.has(needled))
	_ok("the load on a belt is still there", props.items.has(riding))
	_ok("the wad a machine claimed is still there",
		props.items.has(claimed))


	_ok("the card says what it took",
		panel._sweep_note.text.contains("back on the pile"))
	_ok("...and the count above it has caught up",
		panel._yard_note.text.contains("%d out there now" % props.yard_count()))


	button.pressed.emit()
	button.pressed.emit()
	await get_tree().process_frame
	_ok("...and says so plainly when there was nothing to take",
		panel._sweep_note.text.contains("already clear"))

	held.release(Vector3.ZERO)
	layer.queue_free()
	player.global_position = WATCH
	await _clear_yard()


func _button_named(node: Node, text: String) -> Button:
	for child in node.get_children():
		var b:= child as Button
		if b != null and not b.toggle_mode and b.text == text:
			return b
		var found:= _button_named(child, text)
		if found != null:
			return found
	return null


func _check_the_quality_dial_moves_the_cap() -> void:
	print("\n=== the quality dial ===")
	var was_quality: int = Cfg.quality
	var was_cap:= Cfg.prop_cap
	var was_user: Variant = Cfg._prop_cap_user


	Cfg._prop_cap_user = null
	Cfg.apply_quality(Cfg.Quality.ULTRA, false)
	var ultra:= Cfg.prop_cap
	Cfg.apply_quality(Cfg.Quality.POTATO, false)
	var potato:= Cfg.prop_cap
	print("  Ultra says               : %d" % ultra)
	print("  Potato says              : %d" % potato)
	_ok("the dial writes the yard cap", ultra == Cfg.PRESETS [Cfg.Quality.ULTRA] ["prop_cap"])
	_ok("...and the cheap end asks for fewer", potato < ultra)


	var ladder_ok:= true
	for level: int in Cfg.PRESETS:
		var n: int = int(Cfg.PRESETS [level] ["prop_cap"])
		if n < Cfg.PROP_CAP_MIN or n > Cfg.PROP_CAP_MAX:
			ladder_ok = false
	_ok("...and every preset names one the slider could reach", ladder_ok)


	Cfg.set_prop_cap(555)
	Cfg.apply_quality(Cfg.Quality.POTATO, false)
	_ok("a cap the player set survives a dial move", Cfg.prop_cap == 555)
	Cfg.apply_quality(Cfg.Quality.ULTRA, false)
	_ok("...and survives the next one too", Cfg.prop_cap == 555)


	var was_missions:= Cfg.show_missions
	var was_readout:= Cfg.hay_readout
	Cfg.reset_gameplay()
	_ok("reset hands the row back to the preset", Cfg.prop_cap == ultra)
	_ok("...and forgets that anybody had touched it", Cfg._prop_cap_user == null)
	Cfg.set_show_missions(was_missions)
	Cfg.set_hay_readout(was_readout)

	Cfg._prop_cap_user = was_user
	Cfg.apply_quality(was_quality as Cfg.Quality, false)
	Cfg.prop_cap = was_cap


	Cfg.save_settings()


func _gather(node: Node, sliders: Array [Node], pills: Array [Node]) -> void:
	for child in node.get_children():
		if child is HSlider:
			sliders.append(child)
		elif child is Button and (child as Button).toggle_mode:
			pills.append(child)
		_gather(child, sliders, pills)


func _pill_named(node: Node, title: String) -> Button:
	for child in node.get_children():
		var row:= child as HBoxContainer
		if row != null and row.get_child_count() > 0:
			var head:= row.get_child(0) as Label
			if head != null and head.text == title:
				var s: Array [Node] = []
				var p: Array [Node] = []
				_gather(row, s, p)
				if not p.is_empty():
					return p [0] as Button
		var found:= _pill_named(child, title)
		if found != null:
			return found
	return null


func _slider_named(node: Node, title: String) -> HSlider:
	for child in node.get_children():
		var row:= child as HBoxContainer
		if row != null and row.get_child_count() > 0:
			var head:= row.get_child(0) as Label
			if head != null and head.text == title:
				var s: Array [Node] = []
				var p: Array [Node] = []
				_gather(row, s, p)
				if not s.is_empty():
					return s [0] as HSlider
		var found:= _slider_named(child, title)
		if found != null:
			return found
	return null


func _fill(id: String, n: int, state: Dictionary) -> void:
	var per_row:= 12
	for i in n:
		var x:= float(i % per_row) * 0.45
		var z:= float(i / per_row) * 0.45
		var item: Carryable = world.props.spawn(id,
			Transform3D(Basis(), DUMP + Vector3(x, 0.0, z)), state.duplicate())
		if item != null:
			LiveStrandManager.release_hold(item)


func _clear_yard() -> void:
	world.props.clear()
	for i in 20:
		await get_tree().process_frame


func _drain_until_settled() -> int:
	var quiet:= 0
	for i in WAIT_FRAMES:
		await get_tree().process_frame
		if world.props.items.size() <= Cfg.prop_cap:


			quiet += 1
			if quiet > 30:
				return i
		else:
			quiet = 0
	return WAIT_FRAMES


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)


func _folds() -> Array [Node]:
	var out: Array [Node] = []
	for child in world.props.get_children():
		if child is PropFold and not child.is_queued_for_deletion():
			out.append(child)
	return out
