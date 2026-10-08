class_name DevBeltFanProbe
extends Node


const SETTLE:= 40


const PILE:= 30
const PILE_RADIUS:= 0.22

const WATCH_SECONDS:= 3.0


const APPROACH_SECONDS:= 12.0


const SEAM_STRANDS:= 10
const SEAM_SECONDS:= 8.0


const WADS:= 6
const WAD_PITCH:= 0.3

const HEAP:= 120
const HEAP_RADIUS:= 0.22
const HEAP_HEIGHT:= 0.45
const HEAP_SECONDS:= 8.0


const FAST_BELT:= 3.22

const FEED_SECONDS:= 10.0
const FEED_EVERY:= 4
const PER_DROP:= 5

var world: Node3D
var player: Player

var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	_rng.seed = 20260827
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = Vector3(11.0, 0.4, 0.0)
	GameState.add_money(20000.0)

	await _single_run()
	await _across_a_joint()
	await _a_heap()
	await _wads_together()
	await _across_the_seam()


	await _approaching_a_seam(12, false, 29.0)
	await _approaching_a_seam(2, false, 34.0)
	await _approaching_a_seam(12, true, 39.0)
	await _approaching_a_seam(2, true, 44.0)
	await _record_queue_drawn_stopped()
	await _handed_to_a_sleeping_run()

	print("\n[beltfan] done")
	get_tree().quit()


func _single_run() -> void:

	var belt: Conveyor = world.builds.add_conveyor(
		Vector3(13.0, 0.75, -5.0), Vector3(13.0, 0.75, 5.0))
	if belt == null:
		print("[beltfan] could not lay the test run")
		return
	for i in SETTLE:
		await get_tree().physics_frame

	var path: BeltPath = belt
	print("\n=== case 1: one %d-strand dump onto a single %.1f m run ==="
		% [PILE, path.path_length()])
	print("  nominal spacing %.3f m, belt speed %.2f m/s" % [Cfg.BELT_RIDE_SPACING, Cfg.BELT_SPEED])

	var dropped:= _dump(PILE, 13.0, -4.4).size()
	for i in 30:
		await get_tree().physics_frame

	var first:= path.riders_debug()
	print("\n  dropped %d, aboard after settling: %d" % [dropped, first.size()])
	_report("at boarding", first)

	var seqs:= { }
	for r in first:
		seqs [int(r ["seq"])] = true

	var ticks:= int(WATCH_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var marks:= [int(ticks / 3), int(ticks * 2 / 3), ticks - 1]
	for tick in ticks:
		await get_tree().physics_frame
		if tick in marks:
			var still: Array = []
			for r in path.riders_debug():
				if seqs.has(int(r ["seq"])):
					still.append(r)
			_report("after %.2f s" % [(tick + 1) * get_physics_process_delta_time()], still)


func _across_a_joint() -> void:


	var mid:= Vector3(-13.0, 0.75, 0.0)
	var up: Conveyor = world.builds.add_conveyor(Vector3(-13.0, 0.75, -6.0), mid)
	var down: Conveyor = world.builds.add_conveyor(mid, Vector3(-13.0, 0.75, 6.0))
	if up == null or down == null:
		print("[beltfan] could not lay the jointed pair")
		return
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== case 2: the same feed across a JOINT ===")
	print("  upstream %.1f m -> downstream %.1f m, linked: %s"
		% [up.path_length(), down.path_length(), str(up.downstream == down)])

	var ticks:= int(FEED_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var spawned:= 0


	var handed:= [0]
	down.caught.connect(func(_b: RigidBody3D) -> void: handed [0] += 1)


	var poured: Array [RigidBody3D] = []
	var wait_sum:= 0.0
	var lane_sum:= 0.0
	var samples:= 0
	for tick in ticks:
		if tick % FEED_EVERY == 0:
			var made:= _dump(PER_DROP, -13.0, -5.6)
			spawned += made.size()
			poured.append_array(made)
		await get_tree().physics_frame
		if tick % 10 == 0:
			var mark:= up.path_length() - Cfg.BELT_RIDE_SPACING
			var waiting:= 0
			var seen:= { }
			for r in up.riders_debug():
				if float(r ["s"]) < mark:
					continue
				waiting += 1
				seen [int(round(float(r ["side"]) / (Cfg.STRAND_THICK * 6.0)))] = true
			wait_sum += float(waiting)
			lane_sum += float(seen.size())
			samples += 1

	print("\n  hay dropped on the upstream head : %d over %.0f s" % [spawned, FEED_SECONDS])
	print("  riders sitting on the upstream run: %d" % up.riders_debug().size())
	print("  loads taken by the downstream run : %d  (%.1f a second)"
		% [handed [0], float(handed [0]) / FEED_SECONDS])
	print("  a lane-blind joint can pass at most %.1f a second (%.2f m/s / %.3f m)"
		% [Cfg.BELT_SPEED / Cfg.BELT_RIDE_SPACING, Cfg.BELT_SPEED, Cfg.BELT_RIDE_SPACING])
	if samples > 0:
		print("  waiting at the upstream mouth  : %.1f riders in %.1f lanes (mean)"
			% [wait_sum / float(samples), lane_sum / float(samples)])
	_report("upstream now", up.riders_debug())
	_report("downstream now", down.riders_debug())


	print("\n  --- loose straw on an overloaded, still-moving run ---")
	var live_watch: Array [RigidBody3D] = []
	var live_prev: Array [Vector3] = []
	for b: RigidBody3D in poured:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.has_meta(LiveStrandManager.META_RIDER):
			continue
		live_watch.append(b)
		live_prev.append(b.global_position)
	var live_buzz:= 0.0
	var live_ticks:= int(2.0 / maxf(get_physics_process_delta_time(), 1e-06))
	for tick in live_ticks:
		await get_tree().physics_frame
		for i in live_watch.size():
			var lb: RigidBody3D = live_watch [i]
			if not is_instance_valid(lb) or not lb.is_inside_tree():
				continue
			var now: Vector3 = lb.global_position
			live_buzz += now.distance_to(live_prev [i])
			live_prev [i] = now
	var live_frozen:= 0
	for b2: RigidBody3D in live_watch:
		if is_instance_valid(b2) and BeltPath.is_settled(b2):
			live_frozen += 1
	print("  deck running: %s, loose straw %d, of it frozen %d"
		% [str(not up.deck_shows_held()), live_watch.size(), live_frozen])
	if not live_watch.is_empty():
		print("  distance TRAVELLED by loose straw: %.4f m each, %.3f m total"
			% [live_buzz / float(live_watch.size()), live_buzz])

	print("\n  --- the drawn deck ---")


	print("  full-but-draining run shows it running   : %s" % str(not up.deck_shows_held()))


	down.set_blocked(true)
	var wait:= int(4.0 / maxf(get_physics_process_delta_time(), 1e-06))
	var fed: Array [RigidBody3D] = []
	for tick in wait:
		await get_tree().physics_frame
		if tick % FEED_EVERY == 0:
			fed.append_array(_dump(PER_DROP, -13.0, -5.6))
	print("  fully held run shows stopped rubber      : %s" % str(up.deck_shows_held()))
	var settled:= 0
	for b: RigidBody3D in fed:
		if is_instance_valid(b) and BeltPath.is_settled(b):
			settled += 1
	print("  loose straw frozen where it lay          : %d" % settled)


	var settle:= int(2.0 / maxf(get_physics_process_delta_time(), 1e-06))
	for tick in settle:
		await get_tree().physics_frame
	var watched: Array [RigidBody3D] = []
	var was: Array [Vector3] = []
	for b: RigidBody3D in fed:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.has_meta(LiveStrandManager.META_RIDER):
			continue
		watched.append(b)
		was.append(b.global_position)


	var shake_ticks:= int(2.0 / maxf(get_physics_process_delta_time(), 1e-06))
	var path_len: Array [float] = []
	var prev: Array [Vector3] = []
	for b: RigidBody3D in watched:
		path_len.append(0.0)
		prev.append(b.global_position)
	for tick in shake_ticks:
		await get_tree().physics_frame
		for i in watched.size():
			var wb: RigidBody3D = watched [i]
			if not is_instance_valid(wb) or not wb.is_inside_tree():
				continue
			var now: Vector3 = wb.global_position
			path_len [i] += now.distance_to(prev [i])
			prev [i] = now
	var buzz:= 0.0
	var moved:= 0.0
	var worst:= 0.0
	var awake:= 0
	var alive:= 0
	for i in watched.size():
		var b: RigidBody3D = watched [i]
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.has_meta(LiveStrandManager.META_RIDER):
			continue
		alive += 1
		var d: float = b.global_position.distance_to(was [i])
		moved += d
		worst = maxf(worst, d)
		buzz += path_len [i]
		if not b.sleeping:
			awake += 1
	if alive > 0:
		print("  loose hay on the held run: %d, of which awake %d" % [alive, awake])
		print("    net displacement %.4f m each over 2 s, worst %.4f m"
			% [moved / float(alive), worst])
		print("    distance actually TRAVELLED (the shake): %.4f m each, %.3f m total"
			% [buzz / float(alive), buzz])
	else:
		print("  no loose hay left on the held run to measure")


	down.set_blocked(false)
	for tick in wait:
		await get_tree().physics_frame
	print("  released, and running again              : %s  (%d riders left)"
		% [str(not up.deck_shows_held()), up.riders_debug().size()])


func _approaching_a_seam(feed_every: int, turn: bool, x: float) -> void:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mid:= Vector3(x, deck_y, 0.0)
	var up: Conveyor = world.builds.add_conveyor(Vector3(x, deck_y, -6.0), mid)


	var tail:= (Vector3(x + 6.0, deck_y, 0.0) if turn
		else Vector3(x, deck_y, 6.0))
	var down: Conveyor = world.builds.add_conveyor(mid, tail)
	if up == null or down == null:
		print("[beltfan] could not lay the approach pair")
		return
	for i in SETTLE:
		await get_tree().physics_frame

	var step_full:= Cfg.BELT_SPEED / 60.0
	print("\n=== case 6: the last metre before a seam ===")
	print("  %s, feeding a strand every %d steps (%.1f a second)"
		% ["a right-angle CORNER" if turn else "a straight seam", feed_every,
			60.0 / float(feed_every)])
	print("  upstream hands to: %s"
		% ("a corner piece" if up.downstream != null and up.downstream != down
			else ("the next run" if up.downstream == down else "nothing")))


	var ticks:= int(APPROACH_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var mark:= up.path_length() - 1.0
	var last: Dictionary = { }
	var stopped:= 0
	var slow:= 0
	var normal:= 0
	var fast:= 0
	var back:= 0
	var worst_back:= 0.0
	var worst_fwd:= 0.0
	for tick in ticks:
		if tick % feed_every == 0:
			_dump(1, x, -5.6)
		await get_tree().physics_frame
		var now: Dictionary = { }
		for r in up.riders_debug():
			var seq: int = r ["seq"]
			var at: float = r ["s"]
			now [seq] = at
			if at < mark or not last.has(seq):
				continue
			var d: float = at - float(last [seq])
			if d < -1e-06:
				back += 1
				worst_back = maxf(worst_back, - d)
			elif d < step_full * 0.1:
				stopped += 1
			elif d < step_full * 0.75:
				slow += 1
			elif d <= step_full * 1.25:
				normal += 1
			else:
				fast += 1
				worst_fwd = maxf(worst_fwd, d)
		last = now

	var seen:= stopped + slow + normal + fast + back
	if seen == 0:
		print("  nothing reached the approach zone")
		return
	print("  %d rider-steps measured in the last metre:" % seen)
	print("    stopped dead   %5d  (%4.1f%%)" % [stopped, 100.0 * stopped / seen])
	print("    slow           %5d  (%4.1f%%)" % [slow, 100.0 * slow / seen])
	print("    normal         %5d  (%4.1f%%)" % [normal, 100.0 * normal / seen])
	print("    faster         %5d  (%4.1f%%)  worst %.4f m (%.1fx)"
		% [fast, 100.0 * fast / seen, worst_fwd, worst_fwd / step_full])
	print("    went BACKWARDS %5d  (%4.1f%%)  worst %.4f m (%.1fx)"
		% [back, 100.0 * back / seen, worst_back, worst_back / step_full])
	print("  a smoothly carried strand would be 100%% normal and nothing else.")


func _across_the_seam() -> void:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mid:= Vector3(24.0, deck_y, 0.0)
	var up: Conveyor = world.builds.add_conveyor(Vector3(24.0, deck_y, -5.0), mid)
	var down: Conveyor = world.builds.add_conveyor(mid, Vector3(24.0, deck_y, 5.0))
	if up == null or down == null:
		print("[beltfan] could not lay the seam pair")
		return
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== case 5: one strand at a time across a seam ===")
	print("  linked: %s. A carried strand covers %.4f m in one step."
		% [str(up.downstream == down), Cfg.BELT_SPEED / 60.0])

	var tracked: Array [RigidBody3D] = []
	for i in SEAM_STRANDS:
		var b: RigidBody3D = world.live.spawn(
			Vector3(24.0 + _rng.randf_range(-0.12, 0.12), deck_y + 0.1,
				-4.6 + float(i) * 0.9),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if b != null:
			tracked.append(b)

	var prev: Array [Vector3] = []
	for b: RigidBody3D in tracked:
		prev.append(b.global_position)
	var worst_step:= 0.0
	var worst_note:= ""
	var loose_ticks: Array [int] = []
	var drop_below:= 0.0
	for i in tracked.size():
		loose_ticks.append(0)

	var ticks:= int(SEAM_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for tick in ticks:
		await get_tree().physics_frame
		for i in tracked.size():
			var b: RigidBody3D = tracked [i]
			if not is_instance_valid(b) or not b.is_inside_tree():
				continue
			var now: Vector3 = b.global_position
			var step:= now.distance_to(prev [i])


			if absf(now.z) < 1.0:
				var rider:= b.has_meta(LiveStrandManager.META_RIDER)
				if not rider:
					loose_ticks [i] += 1
					drop_below = maxf(drop_below, deck_y - now.y)
				if step > worst_step:
					worst_step = step
					worst_note = "at z %+.3f, %s, one step of %.4f m" % [
						now.z, "carried" if rider else "LOOSE", step]
			prev [i] = now

	var total_loose:= 0
	var seen:= 0
	for i in tracked.size():
		if loose_ticks [i] > 0:
			seen += 1
			total_loose += loose_ticks [i]
	print("  %d of %d strands went loose at the seam" % [seen, tracked.size()])
	if seen > 0:
		print("  they spent %.1f steps each back on physics (%.3f s)"
			% [float(total_loose) / float(seen),
				float(total_loose) / float(seen) * get_physics_process_delta_time()])
	print("  furthest any strand fell below the deck: %.4f m" % drop_below)
	print("  worst single step near the seam: %.4f m  (%.1fx a carried step)"
		% [worst_step, worst_step / maxf(Cfg.BELT_SPEED / 60.0, 1e-06)])
	if worst_note != "":
		print("    %s" % worst_note)


func _wads_together() -> void:
	for pitch: float in [0.3, 0.12, 0.0]:
		await _wad_pitch(pitch)


func _wad_pitch(WAD_PITCH: float) -> void:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var belt: Conveyor = world.builds.add_conveyor(
		Vector3(19.0 + WAD_PITCH * 20.0, deck_y, -6.0), Vector3(19.0 + WAD_PITCH * 20.0, deck_y, 6.0))
	if belt == null:
		print("[beltfan] could not lay the wad run")
		return
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== case 4: %d wads set down %.2f m apart on a running run ==="
		% [WADS, WAD_PITCH])
	print("  a base wad's own footprint is %.3f m, so _occupied refuses another"
		% (Cfg.WAD_BASE_SIZE.x * Cfg.WAD_COLLIDER_SHRINK * HayWad.scale_for(Cfg.WAD_BASE_STRANDS) * 0.5))
	print("  within twice that of a wad already aboard.")

	var wads: Array [RigidBody3D] = []
	for i in WADS:
		var at:= Vector3(19.0 + WAD_PITCH * 20.0, deck_y + 0.25, -5.0 + float(i) * WAD_PITCH)
		var w:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
			{ "strands": Cfg.WAD_BASE_STRANDS }) as RigidBody3D
		if w != null:
			wads.append(w)
	print("  set down %d" % wads.size())


	for i in 600:
		await get_tree().physics_frame

	var aboard:= 0
	var loose: Array [RigidBody3D] = []
	var prev: Array [Vector3] = []
	for w: RigidBody3D in wads:
		if not is_instance_valid(w) or not w.is_inside_tree():
			continue
		if w.has_meta(LiveStrandManager.META_RIDER):
			aboard += 1
			continue
		loose.append(w)
		prev.append(w.global_position)
	print("  carried as riders: %d, still loose on the deck: %d" % [aboard, loose.size()])


	var buzz:= 0.0
	var net:= 0.0
	var ticks:= int(2.0 / maxf(get_physics_process_delta_time(), 1e-06))
	var start: Array [Vector3] = prev.duplicate()
	for tick in ticks:
		await get_tree().physics_frame
		for i in loose.size():
			var w: RigidBody3D = loose [i]
			if not is_instance_valid(w) or not w.is_inside_tree():
				continue
			var now: Vector3 = w.global_position
			buzz += now.distance_to(prev [i])
			prev [i] = now
	for i in loose.size():
		var w: RigidBody3D = loose [i]
		if is_instance_valid(w) and w.is_inside_tree():
			net += w.global_position.distance_to(start [i])
	if loose.is_empty():
		print("  nothing left loose to measure")
		return
	var n:= float(loose.size())
	print("  loose wads over 2 s: travelled %.4f m each, moved %.4f m each"
		% [buzz / n, net / n])


	if net > 0.001:
		print("  travelled / moved = %.1f  (1.0 is clean transport, high is grinding)"
			% (buzz / maxf(net, 0.001)))
	else:
		print("  it went nowhere at all: this is pure vibration")


func _a_heap() -> void:
	var belt: Conveyor = world.builds.add_conveyor(
		Vector3(16.0, 0.75, -5.0), Vector3(16.0, 0.75, 5.0))
	if belt == null:
		print("[beltfan] could not lay the heap run")
		return
	for i in SETTLE:
		await get_tree().physics_frame

	var path: BeltPath = belt
	var deck_y:= 0.75
	print("\n=== case 3: a %d-strand HEAP on a %.1f m run ===" % [HEAP, path.path_length()])
	print("  catch height %.3f m above the deck; drive volume is %.3f m tall"
		% [Cfg.BELT_RIDE_CATCH_H, Cfg.BELT_DRIVE_H])

	var tipped:= _heap(HEAP, 16.0, -4.2)
	print("  tipped %d strands over one spot" % tipped.size())

	var ticks:= int(HEAP_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var per_second:= int(1.0 / maxf(get_physics_process_delta_time(), 1e-06))
	for tick in ticks:
		await get_tree().physics_frame
		if tick % per_second != per_second - 1:
			continue


		var loose:= 0
		var high:= 0
		var tallest:= 0.0
		for b: RigidBody3D in tipped:
			if not is_instance_valid(b) or not b.is_inside_tree():
				continue
			if b.has_meta(LiveStrandManager.META_RIDER):
				continue
			var at: Vector3 = b.global_position
			loose += 1
			var over:= at.y - deck_y
			tallest = maxf(tallest, over)
			if over > Cfg.BELT_RIDE_CATCH_H:
				high += 1
		print("    %2d s  aboard %3d   still loose %3d  (%d of them above catch height, tallest %.3f m)"
			% [(tick + 1) / per_second, path.riders_debug().size(), loose, high, tallest])


func _heap(count: int, x: float, z: float) -> Array [RigidBody3D]:
	var made: Array [RigidBody3D] = []
	for i in count:
		var ang:= _rng.randf() * TAU
		var rad:= sqrt(_rng.randf()) * HEAP_RADIUS
		var pos:= Vector3(
			x + cos(ang) * rad,
			0.8 + _rng.randf() * HEAP_HEIGHT,
			z + sin(ang) * rad)
		var body: RigidBody3D = world.live.spawn(pos,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			made.append(body)
	return made


func _handed_to_a_sleeping_run() -> void:
	var x:= 56.0
	var deck_y:= 0.75


	var up: Conveyor = world.builds.add_conveyor(
		Vector3(x, deck_y, -3.0), Vector3(x, deck_y, 0.0))
	var middle: Conveyor = world.builds.add_conveyor(
		Vector3(x, deck_y, 0.0), Vector3(x + 1.1, deck_y, 0.0))
	var tail: Conveyor = world.builds.add_conveyor(
		Vector3(x + 1.1, deck_y, 0.0), Vector3(x + 1.1, deck_y, 3.0))
	if up == null or middle == null or tail == null:
		print("[beltfan] could not lay the sleeping zigzag")
		return


	var chain: Array [BeltPath] = []
	var walk: BeltPath = up
	while walk != null and not chain.has(walk):
		chain.append(walk)
		walk = walk.downstream


	for p: BeltPath in chain:
		p.set_drive_speed(FAST_BELT)

	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== case 7: a load handed to a run that has gone to sleep ===")
	print("  the chain the hay crosses, at %.2f m/s:" % FAST_BELT)
	for p: BeltPath in chain:
		print("    %-12s %.2f m  asleep %s" % [p.name, p.path_length(), str(p._asleep)])
	if chain.size() < 3:
		print("  NOTE: the corners were not fitted, so this run tests nothing.")


	var strand: RigidBody3D = world.live.spawn(
		Vector3(x, deck_y + 0.2, -2.8),
		StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	if strand == null:
		print("  could not spawn the strand")
		return

	var jam_ticks:= 0
	var jammed:= { }
	var per_second:= int(1.0 / maxf(get_physics_process_delta_time(), 1e-06))
	var ticks:= int(6.0 / maxf(get_physics_process_delta_time(), 1e-06))
	for tick in ticks:
		await get_tree().physics_frame
		for p: BeltPath in chain:
			if p._asleep and not p._riders.is_empty():
				jam_ticks += 1
				jammed [p.name] = int(jammed.get(p.name, 0)) + 1
		if tick % per_second == per_second - 1:
			print("    %d s  %s  strand on %s" % [(tick + 1) / per_second,
				_chain_row(chain), _owner_name(strand)])

	print("  the strand ended up on: %s" % _owner_name(strand))
	print("  runs caught asleep holding a load: %d tick(s) %s"
		% [jam_ticks, str(jammed) if jam_ticks > 0 else "(0 is the fix)"])


	var wad: RigidBody3D = world.props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(x, deck_y + 0.3, -2.8)),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as RigidBody3D
	if wad == null:
		print("  could not spawn the wad behind it")
		return
	for tick in ticks:
		await get_tree().physics_frame
		for p: BeltPath in chain:
			if p._asleep and not p._riders.is_empty():
				jam_ticks += 1
				jammed [p.name] = int(jammed.get(p.name, 0)) + 1
	print("  %s" % _chain_row(chain))
	print("  the wad behind it: on %s, at %v (past the stub is z > %.2f)"
		% [_owner_name(wad),
			wad.global_position if is_instance_valid(wad) else Vector3.ZERO, 0.0])
	print("  runs caught asleep holding a load, both feeds: %d tick(s)" % jam_ticks)


func _chain_row(chain: Array [BeltPath]) -> String:
	var out:= ""
	for p: BeltPath in chain:
		out += "%s %s/%d  " % [p.name, "asleep" if p._asleep else "awake", p._riders.size()]
	return out


func _owner_name(b: RigidBody3D) -> String:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return "gone"
	if not b.has_meta(LiveStrandManager.META_RIDER):
		return "-"
	var p = b.get_meta(LiveStrandManager.META_RIDER)
	return (p as Node).name if is_instance_valid(p) else "-"


func _report(when: String, riders: Array) -> void:
	if riders.is_empty():
		print("  %-18s nothing aboard" % when)
		return
	var lo:= INF
	var hi:= - INF
	for r in riders:
		lo = minf(lo, float(r ["s"]))
		hi = maxf(hi, float(r ["s"]))


	var lanes:= { }
	for r in riders:
		var key:= int(round(float(r ["side"]) / (Cfg.STRAND_THICK * 6.0)))
		if not lanes.has(key):
			lanes [key] = []
		lanes [key].append(float(r ["s"]))
	var pitches: Array [float] = []
	for key: int in lanes:
		var lane: Array = lanes [key]
		lane.sort()
		for i in range(1, lane.size()):
			pitches.append(float(lane [i]) - float(lane [i - 1]))
	var mean:= 0.0
	for p in pitches:
		mean += p
	if not pitches.is_empty():
		mean /= float(pitches.size())
	print("  %-18s %3d aboard, span %.3f m (%.3f -> %.3f), %d lanes, mean in-lane pitch %.3f m"
		% [when, riders.size(), hi - lo, lo, hi, lanes.size(), mean])


func _record_queue_drawn_stopped() -> void:
	var x:= 64.0
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mid:= Vector3(x, deck_y, 0.0)
	var up: Conveyor = world.builds.add_conveyor(Vector3(x, deck_y, -4.0), mid)
	var down: Conveyor = world.builds.add_conveyor(mid, Vector3(x, deck_y, 4.0))
	if up == null or down == null:
		print("[beltfan] could not lay the record queue pair")
		return
	for i in SETTLE:
		await get_tree().physics_frame
	down.set_blocked(true)
	print("\n=== case 8: a queue of records behind a shut belt ===")
	for i in 8:
		world.props.spawn("hay_wad",
			Transform3D(Basis(), Vector3(x, deck_y + 0.25, -3.6 + float(i) * 0.35)),
			{ "strands": Cfg.WAD_BASE_STRANDS })
	for i in 480:
		await get_tree().physics_frame
	print("  records %d, riders %d, drawn stopped %s"
		% [up.run.count(), up._riders.size(), str(up.deck_shows_held())])
	print("  [%s] a parked record queue shows stopped rubber"
		% ("pass" if up.run.count() > 0 and up.deck_shows_held() else "FAIL"))
	down.set_blocked(false)
	for i in 60:
		await get_tree().physics_frame
	print("  [%s] and runs again once the belt ahead opens"
		% ("pass" if not up.deck_shows_held() else "FAIL"))


func _dump(count: int, x: float, z: float) -> Array [RigidBody3D]:
	var made: Array [RigidBody3D] = []
	for i in count:
		var ang:= _rng.randf() * TAU
		var rad:= sqrt(_rng.randf()) * PILE_RADIUS
		var pos:= Vector3(
			x + cos(ang) * rad,
			1.0 + _rng.randf() * 0.1,
			z + sin(ang) * rad)
		var body: RigidBody3D = world.live.spawn(pos,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			made.append(body)
	return made
