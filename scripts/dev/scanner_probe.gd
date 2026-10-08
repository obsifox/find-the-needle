class_name DevScannerProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const FED:= 20


const CARRY_SECONDS:= 20.0 + 32.0 / Cfg.BELT_SPEED

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0


const BELT_RANKS:= 3


func run() -> void:
	_rng.seed = 20260823
	if "--leak" in OS.get_cmdline_user_args():
		await _leak()
		return
	Tech.grant("belt_speed", BELT_RANKS)
	for i in 40:
		await get_tree().process_frame


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var feed_a:= Vector3(13.0, deck_y, -7.0)
	var feed_b:= Vector3(13.0, deck_y, -1.0)
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(5000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== model ===")
	var scanner: HaystackScanner = world.builds.add_scanner(
		feed_b + Vector3(0, 0, Cfg.SCANNER_LENGTH * 0.5), 0.0)
	scanner.live = world.live
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	_check("model instantiated", scanner.get_node_or_null("Model") != null)
	for marker in ["Marker_BeltIn", "Marker_BeltOut", "Marker_ScanVolume",
			"Marker_Bin", "Marker_Screen"]:
		_check("marker %s" % marker, scanner._find(marker) != null)


	for pair in [[scanner._scan_player, HaystackScanner.ANIM_SCAN],
			[scanner._magnet_player, HaystackScanner.ANIM_MAGNET],
			[scanner._drawer_player, HaystackScanner.ANIM_DRAWER]]:
		var p: AnimationPlayer = pair [0]
		var clip: String = pair [1]
		_check("clip %s" % clip, p != null and p.has_animation(clip))
		_check("%s player carries only its own clip" % clip,
			p != null and p.get_animation_list().size() == 1)


		var target: String = HaystackScanner.CLIP_TARGET [clip]
		var foreign:= 0
		if p != null and p.has_animation(clip):
			var a: Animation = p.get_animation(clip)
			for t in a.get_track_count():
				if not String(a.track_get_path(t)).contains(target):
					foreign += 1
		_check("%s drives only %s (%d foreign tracks)" % [clip, target, foreign],
			foreign == 0)


	var scan_clip:= scanner._find_animation(scanner._scan_player,
		HaystackScanner.ANIM_SCAN)
	_check("Scan loops", scan_clip != null and scan_clip.loop_mode != Animation.LOOP_NONE)


	var mag_clip:= scanner._find_animation(scanner._magnet_player,
		HaystackScanner.ANIM_MAGNET)
	_check("MagnetSweep loops", mag_clip != null and mag_clip.loop_mode != Animation.LOOP_NONE)


	_check("sweep is parked with nothing to scan",
		not scanner._scan_player.is_playing())
	_check("magnet is parked with nothing to scan",
		not scanner._magnet_player.is_playing())
	_check("tier 0 scan is %.1f s"
		% float(Cfg.SCANNER_TIERS [Cfg.SCANNER_DEFAULT_TIER] ["scan_seconds"]),
		is_equal_approx(scanner.scan_seconds(),
			float(Cfg.SCANNER_TIERS [Cfg.SCANNER_DEFAULT_TIER] ["scan_seconds"])))

	for key in [HaystackScanner.MAT_GLOW, HaystackScanner.MAT_LASER,
			HaystackScanner.MAT_BEAM]:
		_check("driven material %s" % key, scanner._driven.has(key))

	print("\n=== geometry ===")
	var span:= scanner.port_in().distance_to(scanner.port_out())
	_check("ports %.2f m apart (want %.2f)" % [span, Cfg.SCANNER_LENGTH],
		absf(span - Cfg.SCANNER_LENGTH) < 0.02)


	_check("infeed port on the deck plane (%.3f vs %.3f)"
		% [scanner.port_in().y, deck_y], absf(scanner.port_in().y - deck_y) < 0.02)


	_check("travel is +Z as placed", scanner.forward().dot(Vector3.BACK) > 0.99)

	print("\n=== snapping ===")


	var near:= scanner.port_out() + Vector3(0.35, 0.0, 0.4)
	var snapped: Vector3 = world.builds.snap_endpoint(near)
	_check("belt end snaps to the outfeed port (off by %.3f m)"
		% snapped.distance_to(scanner.port_out()),
		snapped.is_equal_approx(scanner.port_out()))
	var far:= scanner.port_out() + Vector3(4.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second scanner on the same spot is refused",
		world.builds.scanner_overlap(scanner.global_position))

	print("\n=== the deck is part of the machine ===")


	_check("the module has a deck of its own", scanner.deck() != null)


	var in_ledger:= false
	for c in world.builds.conveyors:
		if c == scanner.deck():
			in_ledger = true
	_check("...that is not in the belt ledger", not in_ledger)


	_check("aiming at it resolves to the whole machine",
		world.builds.owner_of(scanner.deck()) == scanner)
	var deck_body: Node = null
	for node in scanner.deck().find_children("*", "StaticBody3D", true, false):
		deck_body = node
		break
	_check("...and so does aiming at its collider",
		deck_body == null or world.builds.owner_of(deck_body) == scanner)


	var decks_before:= scanner.deck()
	_check("the deck is a child of the module, so it is freed with it",
		decks_before.is_inside_tree()
			and decks_before.get_parent() == scanner)

	print("\n=== transport ===")

	world.builds.add_conveyor(feed_a, scanner.port_in())
	var out_end:= scanner.port_out() + Vector3(0, 0, 6.0)
	var out_run: Conveyor = world.builds.add_conveyor(scanner.port_out(), out_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var step:= maxf(get_physics_process_delta_time(), 1e-06)


	var sink_z:= out_end.z - 0.4


	var want:= 36
	var made:= 0
	var arrived:= 0
	var elapsed:= 0.0
	var next_in:= 0.0
	while elapsed < 46.0:
		await get_tree().physics_frame
		elapsed += step
		next_in -= step
		if made < want and next_in <= 0.0:
			next_in = 0.14
			if world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.15, 0.15),
					0.22, 0.0), StrandFactory.random_strand_basis(_rng),
					Vector3.ZERO, Cfg.COL_HAY_LIGHT) != null:
				made += 1
		arrived += _drain(sink_z)
		if made >= want and arrived >= want:
			break
	print("  fed %d strands, %d came out the far side after %.1f s" % [made, arrived, elapsed])
	_check("hay is not eaten crossing the module (%d of %d)" % [arrived, made],
		arrived >= made - 1)
	_check("...and none is invented (%d of %d)" % [arrived, made], arrived <= made)
	_check("nothing banked from plain hay", scanner.banked.is_empty())
	_check("the machine emptied itself out", scanner.stored == 0)

	print("\n=== the instruments wind down ===")


	scanner.stored = scanner.batch_size()
	var ran:= false
	var watch:= 0.0
	while watch < 30.0:
		await get_tree().physics_frame
		watch += step
		_drain(sink_z)
		if scanner.is_scanning():
			ran = true
			continue
		if ran:
			break
	_check("the machine ran a cycle", ran)

	_check("the sweep does not stop dead when the work does",
		scanner._scan_player.is_playing())
	_check("...nor does the magnet", scanner._magnet_player.is_playing())


	var wind:= 0.0
	while wind < 4.0 and (scanner._scan_player.is_playing()
			or scanner._magnet_player.is_playing()):
		await get_tree().physics_frame
		wind += step
		_drain(sink_z)
	_check("the sweep parks itself (%.1f s)" % wind,
		not scanner._scan_player.is_playing())
	_check("...and so does the magnet", not scanner._magnet_player.is_playing())


	var arm_node:= scanner._model.find_child(HaystackScanner.N_ARM, true, false) as Node3D
	var across:= 0.0
	if arm_node != null:
		across = scanner.to_local(arm_node.global_transform
			* HaystackScanner.PING_LOCAL).x
	_check("...hanging plumb rather than frozen mid-swing (%.3f m across)" % across,
		arm_node != null and absf(across) < 0.01)


	var flush:= 0.0
	while flush < 1.5:
		await get_tree().physics_frame
		flush += step
		_drain(scanner.port_out().z + 0.2)

	print("\n=== rate ===")


	Tech.grant("belt_speed", TechTree.max_rank("belt_speed"))
	_drain(sink_z)
	scanner.stored = scanner.buffer_capacity()
	scanner._outgoing = 0
	scanner._cycle_left = 0.0
	scanner._maybe_start_cycle()
	_check("the buffer fills to the tier's capacity (%d/%d)"
		% [scanner.stored, scanner.buffer_capacity()], scanner.is_full())

	var cycles:= 4


	var window:= scanner.scan_seconds() * float(cycles) + 1.5
	var out_in_window:= 0
	elapsed = 0.0
	while elapsed < window:
		await get_tree().physics_frame
		elapsed += step


		if scanner.stored <= scanner.buffer_capacity() - scanner.batch_size():
			scanner.stored = scanner.buffer_capacity()


		out_in_window += _drain(scanner.port_out().z + 0.2)
	var measured:= float(out_in_window) / (scanner.scan_seconds() * float(cycles))
	print("  %.2f strands/s out of a saturated machine (tier says %.2f)"
		% [measured, scanner.throughput()])


	_check("throughput matches the tier (%.2f vs %.2f)"
		% [measured, scanner.throughput()],
		absf(measured - scanner.throughput()) <= scanner.throughput() * 0.2)
	Tech.grant("belt_speed", BELT_RANKS)

	print("\n=== the line stops ===")


	scanner.stored = 0
	scanner._outgoing = 0
	scanner._cycle_left = 0.0
	_drain(scanner.port_out().z - 0.2)
	var far_a:= Vector3(9.0, deck_y, -13.0)
	var bend:= Vector3(13.0, deck_y, -13.0)
	var run_c: Conveyor = world.builds.add_conveyor(far_a, bend)
	world.builds.add_conveyor(bend, feed_a)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the far run knows what comes after it", run_c.downstream != null)

	var fed_gap:= 0.0
	var jammed_made:= 0
	elapsed = 0.0
	while elapsed < 40.0:
		await get_tree().physics_frame
		elapsed += step
		fed_gap -= step


		if fed_gap <= 0.0 and jammed_made < 240:
			fed_gap = 0.1
			if world.live.spawn(far_a + Vector3(0.0, 0.22, _rng.randf_range(-0.03, 0.03)),
					StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
					Cfg.COL_HAY_LIGHT) != null:
				jammed_made += 1


	print("  buffer %d/%d, %d strands on the far run after %.1f s"
		% [scanner.stored, scanner.buffer_capacity(), run_c.riders().size(), elapsed])
	_check("a healthy scanner does not back up its one-lane infeed",
		not scanner.is_full() and not run_c.is_blocked())

	print("\n=== the arm stalls ===")
	var free_run:= Cfg.BELT_SPEED * 0.5


	var arm: RoboticArm = world.builds.add_robotic_arm(
		Vector3((far_a.x + run_c.laid_end().x) * 0.5, 0.0, far_a.z + 1.2), 0.0)
	arm.live = world.live
	arm.builds = world.builds
	arm.field = world.field
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	out_run.set_blocked(true)


	var hit_the_cap:= false
	elapsed = 0.0
	while elapsed < 20.0 and not hit_the_cap:
		await get_tree().physics_frame
		elapsed += step
		hit_the_cap = scanner._outgoing >= scanner.batch_size()
		_keep_feeding(far_a)


	for i in int(18.0 / step):
		await get_tree().physics_frame
		_keep_feeding(far_a)
	print("  outfeed shut: %d scanned strands queued inside the machine (a batch is %d)"
		% [scanner._outgoing, scanner.batch_size()])
	var jam_point:= (far_a + run_c.laid_end()) * 0.5
	_check("a blocked outfeed propagates back to the far infeed",
		not run_c.has_room_near(jam_point))


	for i in 6:
		world.live.spawn(arm.global_position + Vector3(0.0, 0.35, 0.5)
			+ Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3)),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	for i in 30:
		await get_tree().physics_frame
	var shoulder:= arm.global_position + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * arm.visual_scale()


	_check("there is hay for the arm to pick up",
		world.live.nearest_available_hay(shoulder, arm.reach_m() * 0.96,
			RoboticArm.MIN_REACH * arm.visual_scale()) != null)
	var arm_drop: Dictionary = world.builds.nearest_conveyor_drop(shoulder, arm.reach_m() * 0.98)
	_check("...and a belt within reach to put it on", not arm_drop.is_empty())


	var arm_belt:= arm_drop.get("conveyor") as BeltPath
	_check("...and that belt says it has no room",
		arm_belt != null and not arm_belt.has_room_near(arm_drop ["point"] as Vector3))


	var frozen:= _leader(run_c)
	var frozen_at:= frozen.global_position if frozen != null else Vector3.ZERO
	for i in int(0.5 / step):
		await get_tree().physics_frame
	var frozen_crept:= frozen.global_position.distance_to(frozen_at) if frozen != null else 99.0


	var settle:= 0.0
	while settle < 16.0 and frozen != null and frozen_crept >= 0.01:
		frozen_at = frozen.global_position
		for i in int(0.5 / step):
			await get_tree().physics_frame
		frozen_crept = frozen.global_position.distance_to(frozen_at)
		settle += 0.5
	print("  outfeed shut: a strand three runs back moved %.4f m in half a second, %.1f s after the stall"
		% [frozen_crept, settle])


	_check("a stalled machine all but stops it (%.0f%% of a free belt)"
		% (100.0 * frozen_crept / free_run), frozen_crept < free_run * 0.08)

	var idle_ticks:= 0
	var moved_ticks:= 0
	var committed:= false
	var released_into_jam:= false
	elapsed = 0.0
	while elapsed < 6.0:
		await get_tree().physics_frame
		elapsed += step
		_keep_feeding(far_a)
		if arm._phase == RoboticArm.Phase.IDLE:
			idle_ticks += 1
			if committed:
				released_into_jam = true
		else:
			moved_ticks += 1
			committed = true
			if arm._phase in [RoboticArm.Phase.OPEN_CLAWS, RoboticArm.Phase.RETURN_HOME]:
				released_into_jam = true
	print("  arm spent %d of %d ticks idle over a jammed belt"
		% [idle_ticks, idle_ticks + moved_ticks])


	_check("the arm does not release its load into a jammed line",
		not released_into_jam)


	out_run.set_blocked(false)
	for rb in run_c.riders():
		BeltPath.release(rb)
		world.live.consume(rb)


	for i in 6:
		world.live.spawn(arm.global_position + Vector3(0.0, 0.35, 0.45)
			+ Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3)),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	elapsed = 0.0
	var restarted:= false
	while elapsed < 8.0:
		await get_tree().physics_frame
		elapsed += step
		if arm._phase != RoboticArm.Phase.IDLE:
			restarted = true
			break
	print("  arm restarted %.1f s after the belt under it cleared" % elapsed)
	_check("...and starts again once there is room", restarted)
	world.builds.demolish(arm)


	for rb in world.live._active.duplicate():
		BeltPath.release(rb)
		world.live.consume(rb)
	elapsed = 0.0
	while elapsed < 90.0 and (scanner.stored > 0 or scanner.is_scanning()
			or scanner._outgoing > 0):
		await get_tree().physics_frame
		elapsed += step
		_drain(sink_z)
		for rb in world.live._active.duplicate():
			BeltPath.release(rb)
			world.live.consume(rb)
	print("  line cleared in %.1f s (buffer %d, outgoing %d)"
		% [elapsed, scanner.stored, scanner._outgoing])
	_check("a jammed line drains rather than deadlocking",
		scanner.stored == 0 and scanner._outgoing == 0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	print("\n=== catching ===")


	var drop:= scanner.port_in() - scanner.forward() * 1.2 + Vector3(0, 0.14, 0)
	var index:= GameState.register_needle(drop)


	GameState.needle_taken [index] = 1
	var needle: RigidBody3D = world.live.reveal_needle(index, drop)
	_check("needle spawned", needle != null)
	var found_before:= GameState.needles_found
	var swallowed_at:= -1.0
	elapsed = 0.0
	while elapsed < 24.0 and scanner.banked.is_empty():
		await get_tree().physics_frame
		elapsed += step
		_drain(sink_z)
		if swallowed_at < 0.0 and (not is_instance_valid(needle)
				or not needle.is_inside_tree()):
			swallowed_at = elapsed
	if swallowed_at >= 0.0:
		var lag:= elapsed - swallowed_at
		print("  taken in at %.2f s, banked %.2f s later (a cycle is %.2f s)"
			% [swallowed_at, lag, scanner.scan_seconds()])
		_check("the needle is found by a SCAN, not on arrival (%.2f s later)" % lag,
			lag > scanner.scan_seconds() * 0.25)
	_check("needle banked (%d held)" % scanner.banked.size(),
		scanner.banked.size() == 1)
	_check("banked the right index",
		scanner.banked.size() == 1 and scanner.banked [0] == index)
	_check("needle is off the belt", not is_instance_valid(needle)
		or not needle.is_inside_tree())


	_check("needles_found untouched while banked (%d)" % GameState.needles_found,
		GameState.needles_found == found_before)

	print("\n=== find alarm ===")


	_check("beacon is driven on its own mesh", not scanner._beacon_meshes.is_empty())
	_check("alarm spindle built", scanner._alarm_pivot != null)
	if scanner._alarm_pivot != null:
		_check("two lobes on the spindle",
			scanner._alarm_pivot.get_child_count() == 2)
		var lit_now:= scanner._alarm_pivot.visible
		var angle_before:= scanner._alarm_angle

		_check("alarm is lit after a catch", lit_now)


		_check("no klaxon voice was taken",
			not Audio.LOOP_LIB.has("needle_alarm"))
		for i in 12:
			await get_tree().physics_frame
		_check("the spindle is turning (%.2f -> %.2f rad)"
			% [angle_before, scanner._alarm_angle],
			not is_equal_approx(angle_before, scanner._alarm_angle))


		var quiet:= 0.0
		while scanner._alarm > 0.0 and quiet < Cfg.SCANNER_ALARM_SECONDS + 3.0:
			await get_tree().physics_frame
			quiet += step
		_check("alarm stops after %.0f s (took %.1f)"
			% [Cfg.SCANNER_ALARM_SECONDS, quiet], scanner._alarm <= 0.0)


		_check("...but the beacon is still lit, holding a needle",
			scanner._alarm_pivot.visible)
		var turned:= scanner._alarm_angle
		for i in 12:
			await get_tree().physics_frame
		_check("...and still turning (%.2f -> %.2f rad)"
			% [turned, scanner._alarm_angle],
			not is_equal_approx(turned, scanner._alarm_angle))


	print("\n=== the alarm on arrival ===")
	player.global_position = scanner.global_position + Vector3(0.0, 0.4, 13.0)
	var away:= 0.0
	while (scanner._alarm > 0.0 or scanner._player_near) and away < Cfg.SCANNER_ALARM_SECONDS + 3.0:
		await get_tree().physics_frame
		away += step
	_check("the alarm goes quiet with nobody there (%.1f s, %.1f m out)"
		% [away, player.global_position.distance_to(scanner.global_position)],
		scanner._alarm <= 0.0 and not scanner._player_near)
	_check("...and the needle is still in the drawer", not scanner.banked.is_empty())
	player.global_position = scanner.console_position() + Vector3(1.2, 0.0, 0.0)
	for i in 2:
		await get_tree().physics_frame
	_check("walking up sounds it again (%.1f s of alarm)" % scanner._alarm,
		scanner._alarm > 0.0 and scanner._player_near)


	var rearmed:= scanner._alarm
	for i in 30:
		await get_tree().physics_frame
	_check("...and not again while standing there (%.1f -> %.1f s)"
		% [rearmed, scanner._alarm], scanner._alarm < rearmed)


	var glow:= scanner._driven.has(HaystackScanner.MAT_GLOW)
	_check("the lamp strip has a material to drive", glow)
	if glow:
		_check("the flash itself is over (%.2f s left)" % scanner._flash,
			scanner._flash <= 0.0)
		_check("...but the lamps are still gold with a needle in the drawer",
			scanner.lamp_colour(HaystackScanner.MAT_GLOW).is_equal_approx(Cfg.COL_SCAN_FIND))

	print("\n=== the Mk I holds the line ===")


	_check("a Mk I halts on a find", scanner.halts_on_find())
	_check("...and is held while the drawer has something in it", scanner.is_held())
	_check("its mouth is shut", scanner._belt != null and scanner._belt.is_blocked())


	_check("...and so is its outfeed",
		scanner._belt != null and scanner._belt._outlet_held)
	_check("the screen says STOP",
		scanner._screen != null and scanner._screen.text.begins_with("STOP"))
	_check("and the machine says why",
		scanner.alert_reason().begins_with("NEEDLE FOUND"))


	var tip:= scanner.alert_tip()
	print("  tip: %s" % tip)
	_check("...and offers the way out of it", tip.begins_with("TIP"))
	_check("...naming the model that does not halt (%s)"
		% str(Cfg.SCANNER_TIERS [Cfg.SCANNER_TIERS.size() - 1] ["name"]),
		tip.contains(str(Cfg.SCANNER_TIERS [Cfg.SCANNER_TIERS.size() - 1] ["name"])))


	_drain(sink_z)
	scanner.stored = scanner.batch_size() * 2
	scanner._outgoing = scanner.batch_size()
	var held_out:= 0
	elapsed = 0.0
	while elapsed < 5.0:
		await get_tree().physics_frame
		elapsed += step
		held_out += _drain(sink_z)
	print("  %d strands left a held machine in %.0f s (buffer %d, waiting to go down %d)"
		% [held_out, elapsed, scanner.stored, scanner._outgoing])
	_check("nothing leaves a held machine", held_out == 0)
	_check("...and no cycle runs while it is held", not scanner.is_scanning())


	_check("the needle comes out of the drawer",
		scanner.take_banked(index) and scanner.banked.is_empty())
	for i in 10:
		await get_tree().physics_frame
	_check("the hold lifts", not scanner.is_held())


	_check("...and the tip goes with it", scanner.alert_tip() == "")
	_check("the outfeed is let go",
		scanner._belt != null and not scanner._belt._outlet_held)
	var resumed:= 0
	elapsed = 0.0
	while elapsed < 10.0:
		await get_tree().physics_frame
		elapsed += step
		resumed += _drain(sink_z)
	print("  %d strands came out in the %.0f s after the drawer was emptied"
		% [resumed, elapsed])
	_check("the line runs again", resumed > 0)


	scanner.rebank(index)
	_check("...and a Mk I is held again the moment there is one in it",
		scanner.is_held())
	for i in 4:
		await get_tree().physics_frame

	print("\n=== nothing gets past ===")


	scanner.set_tier(Cfg.SCANNER_TIERS.size() - 1)
	_check("a Mk II does not halt on a find",
		not scanner.halts_on_find() and not scanner.is_held())
	var seeded: Array [int] = []
	var stream_secs:= 22.0
	var elapsed_stream:= 0.0
	var next_hay:= 0.0
	var next_needle:= 1.0
	var banked_at_start:= scanner.banked.size()
	while elapsed_stream < stream_secs:
		await get_tree().physics_frame
		elapsed_stream += step
		next_hay -= step
		next_needle -= step
		if next_hay <= 0.0:
			next_hay = 0.12
			var hay_at:= feed_a + Vector3(_rng.randf_range(-0.2, 0.2), 0.22, 0.0)
			world.live.spawn(hay_at, StrandFactory.random_strand_basis(_rng),
				Vector3.ZERO, Cfg.COL_HAY_LIGHT)


		if next_needle <= 0.0 and seeded.size() < 6:
			next_needle = 2.7
			var npos:= feed_a + Vector3(_rng.randf_range(-0.15, 0.15), 0.26, 0.0)
			var ni:= GameState.register_needle(npos)
			GameState.needle_taken [ni] = 1
			world.live.reveal_needle(ni, npos)
			seeded.append(ni)

	var escaped:= 0
	for rb in world.live.needles:
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			continue
		if rb.global_position.z > scanner.port_out().z + 0.2:
			escaped += 1
	var caught_here:= scanner.banked.size() - banked_at_start
	print("  fed %d needles into a continuous stream over %.0f s"
		% [seeded.size(), stream_secs])
	print("  banked %d, still upstream/in the machine %d, PAST THE OUTFEED %d"
		% [caught_here, seeded.size() - caught_here - escaped, escaped])
	_check("no needle reached the outfeed (%d escaped)" % escaped, escaped == 0)

	print("\n=== an overloaded machine does not wave hay past ===")


	_drain(scanner.port_out().z - 0.2)
	scanner.stored = scanner.buffer_capacity()
	scanner._outgoing = 0
	scanner._cycle_left = 0.0


	scanner._belt.open_mouth()
	var seeded_over: Array [RigidBody3D] = []
	for i in 8:
		var on_deck:= scanner.port_in() + scanner.forward() * (0.1 + 0.1 * float(i)) + Vector3(0.0, 0.16, 0.0)
		var loose: RigidBody3D = world.live.spawn(on_deck,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if loose != null:
			seeded_over.append(loose)
	_check("%d strands put on the deck of a full machine" % seeded_over.size(),
		seeded_over.size() > 0)
	elapsed = 0.0
	while elapsed < 8.0:
		await get_tree().physics_frame
		elapsed += step


		scanner.stored = maxi(scanner.stored, scanner.buffer_capacity())
	scanner._belt.shut_mouth(scanner.port_in()
		+ scanner.forward() * HaystackScanner.INTAKE_LENGTH)
	var rode_past:= 0
	var swallowed:= 0
	for rb in seeded_over:
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			swallowed += 1
			continue
		if rb.global_position.z > scanner.port_out().z + 0.05:
			rode_past += 1
	print("  %d of %d swallowed by a full machine, %d PAST THE OUTFEED (buffer %d/%d)"
		% [swallowed, seeded_over.size(), rode_past, scanner.stored,
			scanner.buffer_capacity()])
	_check("a full machine still eats what is on its deck (%d of %d)"
		% [swallowed, seeded_over.size()], swallowed == seeded_over.size())
	_check("no hay rode past an overloaded machine (%d did)" % rode_past,
		rode_past == 0)


	var room:= 10
	scanner.stored = scanner.buffer_capacity() - room
	scanner._outgoing = 0


	scanner._cycle_left = 99.0
	var before_wad:= scanner.stored
	var wad_strands:= 60
	var wad_at:= scanner.port_in() + scanner.forward() * 0.5 + Vector3(0.0, 0.3, 0.0)
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), wad_at), { "strands": wad_strands }) as HayWad
	_check("a %d-strand wad is dropped in the mouth of a nearly full machine"
		% wad_strands, wad != null)


	elapsed = 0.0
	while elapsed < 4.0 and scanner.stored < before_wad + wad_strands:
		await get_tree().physics_frame
		elapsed += step
		scanner._cycle_left = 99.0
	var took: int = scanner.stored - before_wad
	print("  %d room in the buffer, wad of %d, machine took %d"
		% [room, wad_strands, took])


	_check("the wad went in whole rather than up to the brim (%d taken, room was %d)"
		% [took, room], took >= wad_strands)


	_check("...and nothing of it was left riding (%d wads on the deck)"
		% _wads_on(scanner._belt), _wads_on(scanner._belt) == 0)
	scanner._cycle_left = 0.0
	scanner.stored = 0
	scanner._outgoing = 0

	print("\n=== hay thrown into a full machine waits in its mouth ===")


	_drain(scanner.port_out().z - 0.2)
	scanner.stored = scanner.buffer_capacity()
	scanner._outgoing = 0
	scanner._cycle_left = 99.0
	var full_at:= scanner.stored
	var thrown_at:= scanner.port_in() + scanner.forward() * 0.5 + Vector3(0.0, 0.6, 0.0)
	var thrown:= world.props.spawn("hay_wad",
		Transform3D(Basis(), thrown_at), { "strands": wad_strands }) as HayWad
	_check("a %d-strand wad is thrown into the mouth of a full machine" % wad_strands,
		thrown != null)
	elapsed = 0.0
	while elapsed < 4.0:
		await get_tree().physics_frame
		elapsed += step
		scanner._cycle_left = 99.0
	var waiting:= is_instance_valid(thrown) and thrown.is_inside_tree()
	var into_mouth:= -1.0
	if waiting:
		into_mouth = (thrown.global_position - scanner.port_in()).dot(scanner.forward())
	print("  buffer %d/%d after 4 s, wad %s, %.2f m into a %.2f m mouth"
		% [scanner.stored, scanner.buffer_capacity(), "waiting" if waiting else "gone",
			into_mouth, HaystackScanner.INTAKE_LENGTH])


	_check("the full machine did not take it (buffer %d, was %d)"
		% [scanner.stored, full_at], scanner.stored < full_at + wad_strands)
	_check("...and it is lying still in the mouth (%.2f m in)" % into_mouth,
		waiting and into_mouth >= 0.0 and into_mouth < HaystackScanner.INTAKE_LENGTH)
	scanner.stored = 0
	elapsed = 0.0


	while elapsed < 3.0 and scanner.stored < wad_strands:
		await get_tree().physics_frame
		elapsed += step
		scanner._cycle_left = 99.0
	_check("once there is room it goes in whole (%d taken)" % scanner.stored,
		scanner.stored >= wad_strands)
	scanner._cycle_left = 0.0
	scanner.stored = 0
	scanner._outgoing = 0

	print("\n=== wads queued on a snapped infeed stay on it ===")


	var infeed: Conveyor = null
	for c: Conveyor in world.builds.conveyors:
		if is_instance_valid(c) and c.laid_end().distance_to(scanner.port_in()) < 0.05:
			infeed = c
	_check("the module has a run snapped onto its infeed", infeed != null)
	if infeed != null:
		for body: Node in infeed.riders():
			var rb:= body as RigidBody3D
			BeltPath.release(rb)
			if rb is HayWad:
				world.props.remove(rb as HayWad)
			else:
				world.live.consume(rb)
		_clear_records(infeed)
	_drain(scanner.port_in().z - 0.05)
	scanner.stored = scanner.buffer_capacity()
	scanner._outgoing = 0
	scanner._cycle_left = 99.0
	var queued: Array [HayWad] = []
	for i in 6:
		var on_run:= scanner.port_in() - scanner.forward() * (0.6 + 0.8 * float(i)) + Vector3(0.0, 0.35, 0.0)
		var w:= world.props.spawn("hay_wad",
			Transform3D(Basis(), on_run), { "strands": wad_strands }) as HayWad
		if w != null:
			queued.append(w)
	_check("%d wads put on the infeed of a full machine" % queued.size(), queued.size() == 6)
	elapsed = 0.0
	while elapsed < 12.0:
		await get_tree().physics_frame
		elapsed += step
		scanner._cycle_left = 99.0
	var over:= scanner.stored - scanner.buffer_capacity()


	var left_on_run:= _wads_on(infeed) if infeed != null else 0
	print("  buffer %d/%d after 12 s, %d of %d wads still on the run"
		% [scanner.stored, scanner.buffer_capacity(), left_on_run, queued.size()])
	_check("a full machine takes less than one wad off its infeed (%d over)" % over,
		over < wad_strands)
	scanner.stored = 0
	elapsed = 0.0
	while elapsed < 6.0 and scanner.stored < wad_strands:
		await get_tree().physics_frame
		elapsed += step
		scanner._cycle_left = 99.0
	_check("once there is room the queue moves in (%d taken)" % scanner.stored,
		scanner.stored >= wad_strands)
	for w in queued:
		if is_instance_valid(w) and w.is_inside_tree():
			BeltPath.release(w)
			world.props.remove(w)

	if infeed != null:
		_clear_records(infeed)
	_clear_records(scanner._belt)
	_drain(scanner.port_in().z - 0.05)
	scanner._cycle_left = 0.0
	scanner.stored = 0
	scanner._outgoing = 0

	print("\n=== wads fed down onto a full machine ===")


	var layouts: Array [Dictionary] = [
		{ "name": "sloped and snapped", "at": Vector3(16.0, 0.0, -2.0), "over": false },
		{ "name": "ending over the mouth", "at": Vector3(16.0, 0.0, 6.0), "over": true },
	]
	for layout: Dictionary in layouts:
		var sc: HaystackScanner = world.builds.add_scanner(layout ["at"] as Vector3, 0.0)
		sc.live = world.live
		sc.props = world.props
		var run_end:= sc.port_in()
		if bool(layout ["over"]):
			run_end = sc.port_in() + sc.forward() * 0.5 + Vector3(0.0, 0.45, 0.0)
		var run_start:= run_end - sc.forward() * 4.0 + Vector3(0.0, 0.9, 0.0)
		var feed_run: Conveyor = world.builds.add_conveyor(run_start, run_end)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		sc.stored = sc.buffer_capacity()
		sc._outgoing = 0
		sc._cycle_left = 99.0
		var fed: Array [HayWad] = []
		for i in 4:
			var along:= run_start.lerp(run_end, 0.1 + 0.2 * float(i))
			var fw:= world.props.spawn("hay_wad",
				Transform3D(Basis(), along + Vector3(0.0, 0.35, 0.0)),
				{ "strands": wad_strands }) as HayWad
			if fw != null:
				fed.append(fw)
		elapsed = 0.0
		while elapsed < 15.0:
			await get_tree().physics_frame
			elapsed += step
			sc._cycle_left = 99.0
		var over_by:= sc.stored - sc.buffer_capacity()


		var alive:= _wads_on(feed_run) + _wads_on(sc._belt)
		for item in world.props.items:
			var lw:= item as HayWad
			if lw != null and is_instance_valid(lw) and lw.is_inside_tree() and not BeltPath.is_rider(lw) and lw.global_position.distance_to(sc.global_position) < 6.0:
				alive += 1
		print("  %s: snapped %s, buffer %d/%d after 15 s, %d of %d wads still in the world"
			% [layout ["name"], feed_run.downstream != null, sc.stored,
				sc.buffer_capacity(), alive, fed.size()])
		_check("%s: a full machine takes less than one wad (%d over)"
			% [layout ["name"], over_by], over_by < wad_strands)
		for fw in fed:
			if is_instance_valid(fw) and fw.is_inside_tree():
				BeltPath.release(fw)
				world.props.remove(fw)


		_clear_records(feed_run)
		_clear_records(sc._belt)
		world.builds.demolish(feed_run)
		world.builds.demolish(sc)
		for i in 4:
			await get_tree().physics_frame

	print("\n=== a bale-fed scanner ===")


	_drain(scanner.port_out().z - 0.2)
	scanner.blocks.clear()
	scanner._pending.clear()
	scanner.stored = 0
	scanner._outgoing = 0
	scanner._cycle_left = 0.0


	scanner.starved_for = Cfg.MACHINE_STARVED_AFTER + 1.0
	_check("a scanner nothing has reached says NO HAY",
		scanner.alert_reason().begins_with("NO HAY"))
	var bale_at:= scanner.port_in() + scanner.forward() * (HaystackScanner.INTAKE_LENGTH * 0.5) + Vector3.UP * 0.2
	var bale: HayBale = world.props.spawn("hay_bale",
		Transform3D(Basis(), bale_at)) as HayBale
	_check("a bale is dropped in the mouth", bale != null)
	elapsed = 0.0
	while elapsed < 3.0 and not scanner.has_block():
		await get_tree().physics_frame
		elapsed += step
	_check("the machine takes it off the deck (%.1f s)" % elapsed, scanner.has_block())


	var complaint:= ""
	elapsed = 0.0
	while elapsed < 3.0:
		await get_tree().physics_frame
		elapsed += step
		if complaint == "":
			complaint = scanner.alert_reason()
	_check("...and does not call itself starved while it works on it ('%s')"
		% complaint, complaint == "")


	var bank_aside:= scanner.banked.duplicate()
	scanner.banked.clear()

	for k in FactoryClock.stride:
		await get_tree().physics_frame
	var face:= scanner._screen.text if scanner._screen != null else ""
	scanner.banked = bank_aside
	var lines:= face.split("\n")
	print("  the console reads: '%s'" % face.replace("\n", " / "))
	_check("the screen names what it is holding", lines [0] == "BALE")
	_check("...and counts the hold down",
		lines.size() > 1 and lines [1].to_float() > 0.0
			and lines [1].to_float() <= Cfg.SCANNER_BLOCK_SECONDS)


	elapsed = 0.0
	while elapsed < Cfg.SCANNER_BLOCK_SECONDS + 6.0 and scanner.has_block():
		await get_tree().physics_frame
		elapsed += step
	_check("the bale is put back on the belt (%.1f s)" % elapsed,
		not scanner.has_block())
	_check("...and it is in the world, not eaten (%d bales)" % _bales_in_world(),
		_bales_in_world() > 0)


	_drain(scanner.port_out().z - 0.2)
	_remove_bales()
	var drop_at:= scanner.port_out() - scanner.forward() * HaystackScanner.OUTPUT_LEAD + Vector3.UP * HaystackScanner.OUTPUT_LIFT
	var blocker: HayBale = world.props.spawn("hay_bale",
		Transform3D(Basis(), drop_at)) as HayBale
	if blocker != null:
		blocker.freeze = true
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	scanner.starved_for = 0.0
	scanner.blocks.append({
		"id": "hay_bale", "state": { }, "needle": -1, "left": 0.0,
	})
	elapsed = 0.0
	var wedged:= ""
	while elapsed < 3.0:
		await get_tree().physics_frame
		elapsed += step
		wedged = scanner.alert_reason()
	print("  a block with nowhere to go says: '%s'" % wedged)
	_check("a block it cannot put down is reported, not sat on silently",
		wedged.begins_with("OUTFEED BACKED UP"))
	if blocker != null and is_instance_valid(blocker):
		world.props.remove(blocker)
	scanner.blocks.clear()
	scanner.starved_for = 0.0
	scanner.stored = 0
	scanner._outgoing = 0
	_drain(scanner.port_out().z - 0.2)

	print("\n=== debug menu: a picked needle, fed in ===")


	var dbg: DebugMenu = world.debug_menu
	if dbg == null:
		_check("debug menu exists (Cfg.DEBUG)", false)
	else:
		dbg.live = world.live
		dbg.builds = world.builds
		dbg.player = player


		var console:= scanner.console_position()
		player.global_position = Vector3(console.x + 1.2, 0.4, console.z)
		await get_tree().physics_frame


		var naive: Dictionary = world.builds.nearest_conveyor_drop(
			player.global_position, DebugMenu.NEEDLE_BELT_RANGE)
		if not naive.is_empty():
			var naive_along: float = ((naive ["point"] as Vector3)
				- scanner.global_position).dot(scanner.forward())
			print("  from the console, 'nearest belt' lands %.2f m along travel from the module centre (%s)"
				% [naive_along, "PAST the sweep -- never scanned" if naive_along > 0.0
					else "before it"])


		var wanted:= 3
		var registered_before:= GameState.needle_positions.size()
		dbg._needle_dest = DebugMenu.NeedleDest.SCANNER
		dbg._spawn_needle_type(wanted)
		await get_tree().physics_frame
		_check("the picker spawned a needle",
			GameState.needle_positions.size() == registered_before + 1)
		var picked_index:= GameState.needle_positions.size() - 1
		_check("...as the type that was picked (%s)" % NeedleTypes.name_of(wanted),
			GameState.type_of(picked_index) == wanted)
		var along: float = (GameState.needle_positions [picked_index]
			- scanner.global_position).dot(scanner.forward())
		print("  it went down %.2f m upstream of the module centre" % - along)
		_check("...upstream of the sweep, not past it (%.2f m along travel)" % along,
			along < 0.0)


		var waited_pick:= 0.0


		while waited_pick < 30.0 and not scanner.banked.has(picked_index):
			await get_tree().physics_frame
			waited_pick += step


		_check("...and the scanner banked it %.1f s later" % waited_pick,
			scanner.banked.has(picked_index))


	scanner.set_tier(Cfg.SCANNER_DEFAULT_TIER)

	print("\n=== demolition ===")
	_check("refused while loaded: '%s'"
		% world.builds.demolish_blocked_reason(scanner),
		world.builds.demolish_blocked_reason(scanner) != "")
	_check("refund is zero while loaded", is_zero_approx(world.builds.demolish(scanner)))
	_check("still standing", is_instance_valid(scanner)
		and world.builds.scanners.has(scanner))

	print("\n=== save round trip ===")
	var saved: Array = world.builds.to_array()
	var entry: Dictionary = { }
	for d: Dictionary in saved:
		if d.get("type", "") == "haystack_scanner":
			entry = d
	_check("written to the save", not entry.is_empty())
	var banked_out: PackedInt32Array = entry.get("banked", PackedInt32Array())
	_check("bank written (%d)" % banked_out.size(),
		banked_out.size() == scanner.banked.size() and banked_out.has(index))
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var restored: HaystackScanner = null
	if world.builds.scanners.size() > 0:
		restored = world.builds.scanners [0]
	_check("restored", restored != null)
	_check("bank survived the round trip",
		restored != null and restored.banked.size() == banked_out.size()
			and restored.banked.has(index))


	_check("tier survived the round trip",
		restored != null and restored.tier_index == Cfg.SCANNER_DEFAULT_TIER)


	var faster:= HaystackScanner.new()
	faster.setup(Vector3.ZERO, 0.0, 1)
	var t0:= float(Cfg.SCANNER_TIERS [0] ["scan_seconds"])
	var t1:= float(Cfg.SCANNER_TIERS [1] ["scan_seconds"])
	_check("a higher tier scans faster (%.1f s -> %.1f s)" % [t0, t1], t1 < t0)
	_check("...and the machine reads its own tier",
		is_equal_approx(faster.scan_seconds(), t1))


	var block_0:= restored.block_seconds()
	var block_1:= faster.block_seconds()
	print("  a block: %.2f s on a MK I, %.2f s on a MK II" % [block_0, block_1])
	_check("the base hold is the config figure (%.2f s)" % block_0,
		is_equal_approx(block_0, Cfg.SCANNER_BLOCK_SECONDS))
	_check("...and a higher tier looks through a block sooner (%.2f s)" % block_1,
		block_1 < block_0)
	var ranks_before:= Tech.rank_of("scan_solids")
	Tech.grant("scan_solids", 6)
	var block_ranked:= restored.block_seconds()
	print("  six ranks of Scan Bigger Blocks: %.2f s -> %.2f s a block (%.1f/min -> %.1f/min)"
		% [block_0, block_ranked, 60.0 / block_0, 60.0 / block_ranked])
	_check("...and the node shortens the hold (%.2f s -> %.2f s)"
		% [block_0, block_ranked], block_ranked < block_0)


	var ladder_ok:= true
	var ladder:= PackedStringArray()
	for rank in range(1, TechTree.max_rank("scan_solids") + 1):
		Tech.grant("scan_solids", rank)
		var printed:= TechTree.value_at("scan_solids", rank).replace(" s a block", "")
		ladder.append("%s vs %.2f" % [printed, restored.block_seconds()])
		if absf(printed.to_float() - restored.block_seconds()) > 0.05:
			ladder_ok = false
	print("  the card's ladder against the machine: %s" % ", ".join(ladder))
	_check("every rung of the card is what the machine does", ladder_ok)
	Tech.grant("scan_solids", 6)


	_check("...while the hay cycle is untouched (%.2f s)" % restored.scan_seconds(),
		is_equal_approx(restored.scan_seconds(), Tech.scan_seconds(t0)))
	Tech.ranks ["scan_solids"] = ranks_before
	if ranks_before <= 0:
		Tech.ranks.erase("scan_solids")
	faster.free()

	print("\n=== the drawer panel ===")


	var panel: NeedleDrawer = world.needle_drawer
	if panel == null or restored == null:
		_check("the drawer panel was built", false)
	else:
		restored.live = world.live
		player.global_position = restored.console_position() + Vector3(1.2, 0.0, 0.0)
		var listed:= restored.banked.size()
		var pick: int = restored.banked [0] if listed > 0 else -1
		var pick_type:= GameState.type_of(pick)
		var stock_before:= GameState.stock_of(pick_type)
		var found_at_panel:= GameState.needles_found
		panel.open(restored)
		await get_tree().process_frame
		_check("the panel opened", panel.is_open())
		var cards:= panel.cards()
		_check("one card per needle in the tray (%d of %d)" % [cards.size(), listed],
			cards.size() == listed and listed > 0)


		if cards.size() > 0:
			panel.click_card(cards [0])
		await get_tree().process_frame
		_check("the needle is in the player's hand",
			player.hand.is_holding_needle()
				and player.hand.held_needle_index() == pick)
		_check("...the one that was clicked (%s)" % NeedleTypes.name_of(pick_type),
			player.hand.held_needle_index() == pick)
		_check("out of the bank (%d left, was %d)" % [restored.banked.size(), listed],
			restored.banked.size() == listed - 1 and not restored.banked.has(pick))


		_check("the drawers did not gain one (%d, was %d)"
			% [GameState.stock_of(pick_type), stock_before],
			GameState.stock_of(pick_type) == stock_before)
		_check("and the run has not found one (%d, was %d)"
			% [GameState.needles_found, found_at_panel],
			GameState.needles_found == found_at_panel)
		_check("the panel shut behind it", not panel.is_open())


		var left:= restored.banked.size()
		if left > 0:
			panel.open(restored)
			await get_tree().process_frame
			var more:= panel.cards()
			if more.size() > 0:
				panel.click_card(more [0])
			await get_tree().process_frame
			_check("full hands cannot take a second (%d still in the tray)"
				% restored.banked.size(), restored.banked.size() == left)
			_check("...and the panel stays up to say so", panel.is_open())
			panel.set_open(false)


		player.hand.drop_held()
		var shut:= 0.0
		while shut < 4.0 and restored.is_drawer_open():
			await get_tree().physics_frame
			shut += get_physics_process_delta_time()
		_check("the tray shut with the panel (%.1f s)" % shut,
			not restored.is_drawer_open())

		print("\n=== the scanner's switch, on the drawer panel ===")


		var kept:= restored.banked.duplicate()
		restored.banked.clear()
		panel.open(restored)
		await get_tree().process_frame
		_check("an empty tray still opens the panel", panel.is_open())
		_check("...with no cards on it", panel.cards().is_empty())
		_check("...and without sliding the tray out", not restored.is_drawer_open())
		var button:= panel._switch
		_check("the panel carries the switch", button != null and button.visible)
		var rated:= restored.rated_kw()
		if button != null:
			button.pressed.emit()
		await get_tree().process_frame
		_check("TURN OFF switches the scanner off", restored.is_switched_off())
		_check("...it draws nothing (%.2f kW, rated %.2f)" % [restored.draw_kw(), rated],
			restored.draw_kw() == 0.0 and rated > 0.0)
		_check("...and stands still (power %.2f)" % restored.power, restored.power == 0.0)
		_check("the switch now reads OFF",
			button != null and not button.running)
		if button != null:
			button.pressed.emit()
		await get_tree().process_frame
		_check("TURN ON brings it back (power %.2f)" % restored.power,
			not restored.is_switched_off() and restored.power > 0.0)

		restored.set_switched_off(true)
		await get_tree().process_frame
		_check("a switch thrown elsewhere shows on the open panel",
			button != null and not button.running)
		restored.set_switched_off(false)
		panel.set_open(false)
		restored.banked = kept

	print("\n=== the drawer ===")
	if restored != null:
		restored.live = world.live
		var before: int = world.live.needles.size()
		var owed: int = restored.banked.size()
		var found_at_open:= GameState.needles_found
		var owed_last:= restored.banked [owed - 1] if owed > 0 else -1
		var tray:= restored.find_child("TrayCollision", true, false)
		_check("tray has a collider", tray != null)
		var bin_node:= restored._find("Marker_Bin") as Node3D
		var bin_closed:= bin_node.global_position


		var lamp:= restored._driven.has(HaystackScanner.MAT_GLOW)
		if lamp and owed > 0:
			_check("a loaded scanner comes back gold",
				restored.lamp_colour(HaystackScanner.MAT_GLOW).is_equal_approx(Cfg.COL_SCAN_FIND))
		if restored._alarm_pivot != null and owed > 0:
			_check("...with its beacon already turning",
				restored._alarm_pivot.visible)
		restored.dispense()
		var ticks_drawer:= int(3.0 / maxf(get_physics_process_delta_time(), 1e-06))
		for i in ticks_drawer:
			await get_tree().physics_frame
			if restored.banked.is_empty():
				break
		_check("drawer opened", restored.is_drawer_open())
		_check("bank emptied", restored.banked.is_empty())


		if lamp:
			_check("the lamps go back to idle once it is empty",
				restored.lamp_colour(HaystackScanner.MAT_GLOW).is_equal_approx(Cfg.COL_SCAN_IDLE))


		for k in FactoryClock.stride:
			await get_tree().physics_frame
		if restored._alarm_pivot != null:
			_check("the beacon goes out with them",
				not restored._alarm_pivot.visible)


		var after: int = world.live.needles.size()
		_check("nothing is dropped on the floor (%d loose needles, was %d)"
			% [after, before], after == before)


		var travelled:= bin_closed.distance_to(bin_node.global_position)
		print("  drawer ran out %.3f m" % travelled)
		_check("the drawer actually moved (%.3f m)" % travelled, travelled > 0.15)


		var wait_flight:= 0.0
		while wait_flight < 12.0 and GameState.needles_found < found_at_open + owed:
			await get_tree().physics_frame
			wait_flight += step
		print("  %d of %d landed in the collection after %.1f s"
			% [GameState.needles_found - found_at_open, owed, wait_flight])
		_check("every needle reached the collection (%d of %d)"
			% [GameState.needles_found - found_at_open, owed],
			GameState.needles_found == found_at_open + owed)
		_check("...and the one that was banked last is among them",
			owed_last < 0 or GameState.stock_of(GameState.type_of(owed_last)) > 0)
		_check("no needle is left in the world (%d loose)" % world.live.needles.size(),
			world.live.needles.size() == before)

		_check("now demolishable: '%s'"
			% world.builds.demolish_blocked_reason(restored),
			world.builds.demolish_blocked_reason(restored) == "")
		var refund: float = world.builds.demolish(restored)
		var tier_cost:= float(Cfg.SCANNER_TIERS [Cfg.SCANNER_DEFAULT_TIER] ["cost"])
		_check("refunded $%.0f" % refund, is_equal_approx(refund, tier_cost))

	print("\n=== debug menu needle spawn ===")


	var menu: DebugMenu = world.debug_menu
	if menu == null:
		_check("debug menu exists (Cfg.DEBUG)", false)
	else:
		menu.live = world.live
		menu.builds = world.builds
		var loose_before: int = world.live.needles.size()
		var registered_before:= GameState.needle_positions.size()
		menu._on_spawn_needle()
		await get_tree().physics_frame
		_check("'At your feet' put a needle in the world",
			world.live.needles.size() == loose_before + 1)


		_check("...and registered it with GameState",
			GameState.needle_positions.size() == registered_before + 1)
		_check("...marked no longer buried",
			GameState.needle_taken [GameState.needle_positions.size() - 1] == 1)


		player.global_position = feed_a + Vector3(1.5, 0.0, 0.0)
		await get_tree().physics_frame
		var on_belt_before: int = world.live.needles.size()
		menu._on_needle_to_belt()
		await get_tree().physics_frame
		_check("'Onto nearest belt' put a needle in the world",
			world.live.needles.size() == on_belt_before + 1)
		if world.live.needles.size() > on_belt_before:
			var dropped: RigidBody3D = world.live.needles [world.live.needles.size() - 1]
			var over_deck:= absf(dropped.global_position.y - feed_a.y)
			print("  dropped %.2f m above the belt deck" % over_deck)
			_check("landed over the belt, not on the floor (%.2f m)" % over_deck,
				over_deck < 0.5)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("SCANNER PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


var _feed_left:= 0.0


func _keep_feeding(at: Vector3) -> void:
	_feed_left -= maxf(get_physics_process_delta_time(), 1e-06)
	if _feed_left > 0.0:
		return
	_feed_left = 0.1
	world.live.spawn(at + Vector3(0.0, 0.22, _rng.randf_range(-0.03, 0.03)),
		StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)


func _leader(run: Conveyor) -> RigidBody3D:
	var best: RigidBody3D = null
	var best_d:= - INF
	for rb in run.riders():
		var d: float = (rb.global_position - run.a).dot(run.forward)
		if d > best_d:
			best_d = d
			best = rb
	return best


func _bales_in_world() -> int:
	var n:= 0
	for item in world.props.items:
		if is_instance_valid(item) and item is HayBale:
			n += 1
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		n += _records_on(path, BeltRun.Kind.BALE)
	return n


func _remove_bales() -> void:
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and item is HayBale:
			world.props.remove(item)
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		_clear_records(path, BeltRun.Kind.BALE)


func _wads_on(path: BeltPath) -> int:
	if path == null or not is_instance_valid(path):
		return 0
	var n:= _records_on(path, BeltRun.Kind.WAD)
	for rb in path.riders():
		if rb is HayWad:
			n += 1
	return n


func _records_on(path: BeltPath, kind: int) -> int:
	var run: BeltRun = path.run
	var n:= 0
	for i in range(run.first(), run.first() + run.count()):
		if run.kind_of(i) == kind:
			n += 1
	return n


func _clear_records(path: BeltPath, kind: int = -1) -> int:
	if path == null or not is_instance_valid(path):
		return 0
	var run: BeltRun = path.run
	var n:= 0
	var i:= run.first() + run.count() - 1
	while i >= run.first():
		if kind < 0 or run.kind_of(i) == kind:
			var was_head:= i == run.first()
			run.remove_at(i)
			n += 1
			if was_head:
				break
		i -= 1
	return n


func _drain(sink_z: float) -> int:
	var n:= 0
	for rb in world.live._active.duplicate():
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			continue
		if rb.global_position.z < sink_z:
			continue
		BeltPath.release(rb)
		if world.live.consume(rb):
			n += 1


	for item in world.props.items.duplicate():
		var wad:= item as HayWad
		if wad == null or not is_instance_valid(wad) or not wad.is_inside_tree():
			continue
		if wad.global_position.z < sink_z:
			continue
		n += wad.strands
		world.props.remove(wad)


	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		var i:= run.first() + run.count() - 1
		while i >= run.first():
			if run.kind_of(i) == BeltRun.Kind.WAD and run.pose_of(i).origin.z >= sink_z:
				n += run.strands_of(i)
				var was_head:= i == run.first()
				run.remove_at(i)
				if was_head:
					break
			i -= 1
	return n


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _leak_save(path: String) -> void:
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("LEAK: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))
	BeltPath.debug_props = true
	var at:= Vector3(-7.0, 0.43, -21.0)
	player.noclip = true
	player.global_position = Vector3(-8.4, 0.3, -22.7)
	player.velocity = Vector3.ZERO
	var sc: HaystackScanner = null
	for s: HaystackScanner in world.builds.scanners:
		if not is_instance_valid(s):
			continue
		if sc == null or s.global_position.distance_to(at) < sc.global_position.distance_to(at):
			sc = s
	if sc == null:
		print("LEAK: no scanner in %s" % path)
		get_tree().quit(1)
		return
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var deck:= sc.deck()
	var cap:= sc.buffer_capacity()
	print("\n=== leak in a save copy: belt %.2f m/s ===" % Tech.belt_speed())
	print("  scanner at %v: %d/%d, deck shut %s, outgoing %d, outfeed %s"
		% [sc.global_position, sc.stored, cap, deck.is_blocked(), sc._outgoing,
			deck.downstream.get_parent().name if deck.downstream != null else "-"])
	var start:= sc.stored
	var gained:= 0
	var leaks:= 0
	var elapsed:= 0.0
	var next_print:= 20.0
	while elapsed < 120.0:
		var near: Array = []
		for item in world.props.items:
			var w:= item as HayWad
			if w == null or not is_instance_valid(w) or not w.is_inside_tree():
				continue
			if w.global_position.distance_to(sc.port_in()) > 1.8:
				continue
			var whose:= "loose"
			if w.has_meta(LiveStrandManager.META_RIDER):
				var p = w.get_meta(LiveStrandManager.META_RIDER)
				whose = ("deck" if is_same(p, deck)
					else (p as Node).name if is_instance_valid(p) else "?")
			near.append([w, w.strands, whose,
				(w.global_position - sc.port_in()).dot(sc.forward()),
				float(deck._nearest(w.global_position) ["s"]),
				BeltPath.debug_last_refusal.get(w.get_instance_id(), "")])
		var was_full:= sc.is_full()
		var before:= sc.stored
		await get_tree().physics_frame
		elapsed += step
		if sc.stored > before:
			gained += sc.stored - before
		if was_full:
			for rec: Array in near:
				var w = rec [0]
				if is_instance_valid(w) and (w as Node).is_inside_tree():
					continue
				leaks += 1
				if leaks <= 10:
					print("    t %.2f: %d strand load eaten at %d/%d, riding %s, %.2f m in, deck s %.2f, last refusal '%s'"
						% [elapsed, rec [1], before, cap, rec [2], rec [3], rec [4], rec [5]])
		if elapsed >= next_print:
			next_print += 20.0
			print("    t %.0f s: %d/%d, deck shut %s, outgoing %d, scanning %s, taken in %d"
				% [elapsed, sc.stored, cap, deck.is_blocked(), sc._outgoing,
					sc.is_scanning(), gained])
	print("  %d loads went into the full machine in %.0f s: %d strands, %.1f a second (buffer %d to %d)"
		% [leaks, elapsed, gained, gained / elapsed, start, sc.stored])
	_check("a full scanner takes nothing in over two minutes (%d taken)" % gained,
		gained < Cfg.WAD_MAX_STRANDS)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _leak() -> void:
	var args:= OS.get_cmdline_user_args()
	var after:= args.find("--leak") + 1
	if after < args.size() and FileAccess.file_exists(args [after]):
		await _leak_save(args [after])
		return
	Tech.grant("belt_speed", TechTree.max_rank("belt_speed"))
	Tech.grant("scan_batch", TechTree.max_rank("scan_batch"))
	Tech.grant("scan_speed", TechTree.max_rank("scan_speed"))
	player.global_position = Vector3(10.5, 0.4, 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	print("\n=== leak: belt %.2f m/s ===" % Tech.belt_speed())


	var layouts: Array [Dictionary] = [
		{ "name": "flat and snapped", "rise": 0.0, "over": -1.0, "far": false },
		{ "name": "flat and snapped, player far off", "rise": 0.0, "over": -1.0, "far": true },
		{ "name": "sloped and snapped", "rise": 0.9, "over": -1.0, "far": false },
		{ "name": "ending 0.5 m over the mouth", "rise": 0.9, "over": 0.5, "far": false },
		{ "name": "ending 0.9 m in", "rise": 0.9, "over": 0.9, "far": false },
		{ "name": "ending 1.1 m in", "rise": 0.9, "over": 1.1, "far": false },
		{ "name": "ending 1.3 m in", "rise": 0.9, "over": 1.3, "far": false },
	]
	var only:= ""
	var ua:= OS.get_cmdline_user_args()
	if ua.find("--leak") + 1 < ua.size() and not ua [ua.find("--leak") + 1].begins_with("--"):
		only = ua [ua.find("--leak") + 1]
	for layout: Dictionary in layouts:
		if only != "" and not String(layout ["name"]).contains(only):
			continue
		var sc: HaystackScanner = world.builds.add_scanner(Vector3(13.0, deck_y, 0.0), 0.0, 1)
		sc.live = world.live
		sc.props = world.props
		var fwd:= sc.forward()
		var run_end:= sc.port_in()
		if float(layout ["over"]) >= 0.0:
			run_end = sc.port_in() + fwd * float(layout ["over"]) + Vector3(0.0, 0.45, 0.0)
		var run_start:= run_end - fwd * 6.0 + Vector3(0.0, float(layout ["rise"]), 0.0)
		var feed_run: Conveyor = world.builds.add_conveyor(run_start, run_end)
		var out_end:= sc.port_out() + fwd * 6.0
		var out_run: Conveyor = world.builds.add_conveyor(sc.port_out(), out_end)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		var deck:= sc.deck()
		var cap:= sc.buffer_capacity()
		print("  %s: %s, snapped %s, capacity %d, %.1f strands/s"
			% [layout ["name"], sc.tier_data() ["name"], feed_run.downstream != null,
				cap, sc.throughput()])
		var feed_at:= run_start + fwd * 0.4 + Vector3(0.0, 0.35, 0.0)
		var fed:= 0
		var max_over:= 0
		var leaked:= 0
		var leaks:= 0
		var next_feed:= 0.0
		var next_print:= 10.0
		var elapsed:= 0.0
		while elapsed < 60.0:
			if bool(layout ["far"]):
				player.global_position = Vector3(13.0, 0.4, -80.0)
			next_feed -= step
			if next_feed <= 0.0:
				var n:= _rng.randi_range(60, Cfg.WAD_MAX_STRANDS)
				if HayWad.room_at(sc._space(), feed_at, n):
					if world.props.spawn("hay_wad", Transform3D(Basis(), feed_at),
							{ "strands": n }) != null:
						fed += n
						next_feed = 0.2
			var near: Array = []
			for item in world.props.items:
				var w:= item as HayWad
				if w == null or not is_instance_valid(w) or not w.is_inside_tree():
					continue
				if w.global_position.distance_to(sc.port_in()) > 1.6:
					continue
				var whose:= "loose"
				if w.has_meta(LiveStrandManager.META_RIDER):
					var p = w.get_meta(LiveStrandManager.META_RIDER)
					whose = ("deck" if is_same(p, deck)
						else ("feed" if is_same(p, feed_run) else "other"))
				near.append([w, w.strands, whose,
					(w.global_position - sc.port_in()).dot(fwd), w.freeze])
			var was_full:= sc.is_full()
			var was_shut:= deck.is_blocked()
			var was_stored:= sc.stored
			await get_tree().physics_frame
			elapsed += step
			_drain(out_end.z - 0.4)
			max_over = maxi(max_over, sc.stored - cap)
			if not was_full:
				continue
			for rec: Array in near:
				var w = rec [0]
				if is_instance_valid(w) and (w as Node).is_inside_tree():
					continue
				leaked += int(rec [1])
				leaks += 1
				if leaks <= 8:
					print("    t %.2f: %d strand wad eaten at %d/%d, riding %s, %.2f m into the mouth, frozen %s, deck shut %s"
						% [elapsed, rec [1], was_stored, cap, rec [2], rec [3], rec [4], was_shut])
			if elapsed >= next_print:
				next_print += 10.0
				print("    t %.0f s: buffer %d/%d, fed %d, deck shut %s, %d riders on the feed"
					% [elapsed, sc.stored, cap, fed, deck.is_blocked(), feed_run.riders().size()])
		print("    %d wads (%d strands) went into a full machine, most over capacity %d"
			% [leaks, leaked, max_over])
		_check("%s: never a wad over capacity (%d over)" % [layout ["name"], max_over],
			max_over < Cfg.WAD_MAX_STRANDS)
		player.global_position = Vector3(10.5, 0.4, 0.0)
		_drain(-1000000000.0)
		world.builds.demolish(feed_run)
		world.builds.demolish(out_run)
		world.builds.demolish(sc)
		for i in 8:
			await get_tree().physics_frame
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
