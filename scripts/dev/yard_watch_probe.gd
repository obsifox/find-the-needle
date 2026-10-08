class_name DevYardWatchProbe
extends Node


var world: Node3D
var player: Player


const WATCH_SECONDS:= 100.0


const WAD_EVERY:= 1.0

const NEAR:= 3.5


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--yardwatch")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("YARDWATCH: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return


	if ConveyorSplitter.old_throat:
		print("YARDWATCH: the splitters as they were before 26 Sep 2026")


	Cfg.belt_cap = maxi(Cfg.belt_cap, 10000)
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("YARDWATCH: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("YARDWATCH: save version %d, %d buildings, %d props, block_save=%s"
		% [int(d.get("version", 0)), (d.get("buildings", []) as Array).size(),
			(d.get("props", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))


	if "--basetech" in ua:
		print("YARDWATCH: research left at base, the save's tech is NOT applied")
	else:
		SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))
	BeltPath.debug_props = true


	world.props.from_array(d.get("props", []) if "--keeplitter" in ua else [])
	for k in 60:
		await get_tree().physics_frame

	var b: BuildManager = world.builds
	print("YARDWATCH: belt speed %.2f, %d runs, %d corners, %d splitters, %d arms, %d generators"
		% [Tech.belt_speed(), b.conveyors.size(), b.corners.size(), b.splitters.size(),
			b.robotic_arms.size(), b.generators.size()])


	for lift: HayLift in b.hay_lifts:
		var out:= lift.outfeed_deck()
		print("  lift %s: %d sections, riser %.2f, rise %.3f (port %.3f over mouth), outfeed %s"
			% [lift.name, lift.sections, lift.riser, lift.rise(),
				lift.port_out().y - lift.port_in().y,
				("feeds " + _name_of(out.downstream)) if out != null and out.downstream != null
					else "feeds nothing"])
	if "--pellets" in ua:
		await _pellets(b)
		get_tree().quit(0)
		return
	if b.splitters.is_empty():
		print("YARDWATCH: no splitter in this yard")
		get_tree().quit(1)
		return


	var first: ConveyorSplitter = null
	for s in b.splitters:
		var feeder: Conveyor = b.feed_run_into(s.port_in())
		var fed_by_splitter:= false
		for o in b.splitters:
			if o == s:
				continue
			for side in ConveyorSplitter.SIDES:
				if feeder != null and feeder.a.is_equal_approx(o.port(side)):
					fed_by_splitter = true
		if not fed_by_splitter and first == null:
			first = s
	if first == null:
		first = b.splitters [0]
	for n in b.splitters.size():
		var s: ConveyorSplitter = b.splitters [n]
		var feeder: Conveyor = b.feed_run_into(s.port_in())
		var outs:= []
		for side in ConveyorSplitter.SIDES:
			var route:= s.route(side)
			outs.append("%s->%s" % ["L" if side == ConveyorSplitter.LEFT else "R",
				_name_of(route.downstream if route != null else null)])
		print("  splitter %d%s at %s yaw %.2f: %s; feeder %s (%.2f m, downstream %s); routes %s"
			% [n, " (FIRST)" if s == first else "", _v(s.global_position), s.global_rotation.y,
				s.mode_label(), _name_of(feeder),
				feeder.path_length() if feeder != null else 0.0,
				_name_of(feeder.downstream) if feeder != null else "-", outs])

		if feeder != null:
			var up:= _what_ends_at(feeder.a)
			print("    the feeder is fed by %s" % up)


	if player != null:
		player.global_position = first.global_position + Vector3(0.0, 1.0, -3.0)

	var feeder0: Conveyor = b.feed_run_into(first.port_in())
	var spawn_at:= Vector3.ZERO
	var spawn_run: Conveyor = null
	var skipped:= 0
	var spread:= "--spread" in ua
	if spread:
		print("  wads will be set down THREE at a time, spread along the run like an arm's full load")
	if feeder0 != null:


		var up: Conveyor = feeder0
		for hop in 4:
			var prev:= _run_ending_at(up.a)
			if prev == null:
				break
			up = prev
			if up.path_length() > 2.5:
				break
		var fwd:= (up.laid_end() - up.laid_start()).normalized()
		spawn_at = up.laid_end() - fwd * minf(1.5, up.path_length() * 0.5) + Vector3.UP * 0.3
		spawn_run = up
		print("  wads will be set on %s (%.2f m) at %s" % [_name_of(up), up.path_length(), _v(spawn_at)])
	else:
		print("  no plain run feeds the first splitter; wads will be set at its mouth")
		spawn_at = first.port_in() - first.forward() * 0.6 + Vector3.UP * 0.3

	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var t:= 0.0
	var next_wad:= 0.0
	var next_log:= 0.0
	var fed:= 0
	var wads: Array [RigidBody3D] = []
	while t < WATCH_SECONDS:
		await get_tree().physics_frame
		t += step
		next_wad -= step
		next_log -= step
		if next_wad <= 0.0:
			next_wad = WAD_EVERY


			var deck_at:= spawn_at - Vector3.UP * 0.3
			var space:= get_viewport().world_3d.direct_space_state


			var lead:= 0.0 if "--blind" in ua else Tech.belt_speed() * RoboticArm.DROP_SETTLE_SECONDS
			var half:= Cfg.WAD_BASE_SIZE.x * 0.5 * HayWad.scale_for(60)
			if spawn_run != null and (("--blind" in ua and not spawn_run.has_room_near(deck_at))
					or ("--blind" not in ua and not spawn_run.has_room_to_land(spawn_at, 0.0, lead, half))
					or not HayWad.room_at(space, deck_at, 60)):
				skipped += 1
			elif spread:


				var along:= (spawn_run.laid_end() - spawn_run.laid_start()).normalized()
				for k in [-1.0, 0.0, 1.0]:
					var w:= world.props.spawn("hay_wad",
						Transform3D(Basis.IDENTITY, spawn_at + along * k * Cfg.WAD_CLEAR),
						{ "strands": 60 }) as RigidBody3D
					if w != null:
						wads.append(w)
						fed += 1
			else:
				var w:= world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY, spawn_at),
					{ "strands": 60 }) as RigidBody3D
				if w != null:
					wads.append(w)
					fed += 1
		if next_log <= 0.0:
			next_log = 2.0
			_report(t, fed, skipped, wads, b)
	print("YARDWATCH: done, %d wads fed" % fed)
	get_tree().quit()


func _record_overlaps(b: BuildManager) -> void:
	var pairs:= 0
	var worst:= 0.0
	var at_worst:= ""
	for s in b.splitters:
		var runs: Array [BeltRun] = []
		var feeder: Conveyor = b.feed_run_into(s.port_in())
		if feeder != null:
			runs.append(feeder.run)
		for route in s.routes():
			if route == null:
				continue
			runs.append(route.run)
			if route.downstream != null and is_instance_valid(route.downstream):
				runs.append(route.downstream.run)
		var at: Array [Vector3] = []
		var reach: Array [float] = []
		var of: Array [int] = []
		for n in runs.size():
			var r:= runs [n]
			for i in range(r.first(), r.first() + r.count()):
				at.append(r.pose_of(i).origin)
				reach.append(r.reach_of(i))
				of.append(n)
		for i in at.size():
			for j in range(i + 1, at.size()):
				if of [i] == of [j]:
					continue
				var o:= Vector2(at [i].x - at [j].x, at [i].z - at [j].z).length() - reach [i] - reach [j] + 0.01
				if o < 0.0:
					pairs += 1
					if o < worst:
						worst = o
						at_worst = "%s at %s" % [s.name, _v(s.global_position)]
	print("    belt records drawn inside each other round the splitters: %d pairs, deepest %.3f m %s"
		% [pairs, worst, at_worst])


func _report(t: float, fed: int, skipped: int, wads: Array [RigidBody3D],
		b: BuildManager) -> void:
	var riding:= 0
	var loose:= 0
	var on_top:= 0
	var floor:= 0


	var deck_y: float = (b.splitters [0] as ConveyorSplitter).global_position.y
	for w in wads:
		if not is_instance_valid(w) or not w.is_inside_tree():
			continue
		if BeltPath.is_rider(w):
			riding += 1
		elif w.global_position.y < 0.25:
			floor += 1
		elif w.global_position.y > deck_y + 0.12:


			on_top += 1
		else:
			loose += 1
	print("t=%5.1f fed %d (skipped %d): %d riding, %d loose on a deck, %d loose ON TOP of the queue, %d on the floor"
		% [t, fed, skipped, riding, loose, on_top, floor])


	var all_riding:= 0
	var all_loose:= 0
	var all_top:= 0
	var all_floor:= 0
	var where:= []
	for item in world.props.items:
		var w:= item as HayWad
		if w == null or not is_instance_valid(w) or not w.is_inside_tree():
			continue
		if BeltPath.is_rider(w):
			all_riding += 1
			continue
		var kind:= ""
		if w.global_position.y < 0.25:
			all_floor += 1
			kind = "floor"
		elif not _over_a_belt(w.global_position):

			continue
		elif w.global_position.y > deck_y + 0.12:
			all_top += 1
			kind = "TOP"
		else:
			all_loose += 1
			kind = "loose"
		if kind != "floor" and where.size() < 10:
			where.append("%s %s near %s, %s, v%.1f vy%.2f, %d strands%s" % [kind,
				_v(w.global_position), _nearest_machine(w.global_position),
				str(BeltPath.debug_last_refusal.get(w.get_instance_id(), "never asked")),
				Vector2(w.linear_velocity.x, w.linear_velocity.z).length(),
				w.linear_velocity.y, w.strands, " asleep" if w.sleeping else ""])
	print("    every wad in the yard: %d riding, %d loose on a deck, %d on top, %d on the floor"
		% [all_riding, all_loose, all_top, all_floor])
	_record_overlaps(b)
	for line in where:
		print("      %s" % line)


	var kinds:= { "rider/rider same path": 0, "rider/rider two paths": 0,
		"rider/loose": 0, "loose/loose": 0 }
	var examples:= []
	var yard_wads: Array = []
	for item in world.props.items:
		var w:= item as HayWad
		if w != null and is_instance_valid(w) and w.is_inside_tree() and w.global_position.y > 0.25:
			yard_wads.append(w)
	for i in yard_wads.size():
		for j in range(i + 1, yard_wads.size()):
			var wa: HayWad = yard_wads [i]
			var wb: HayWad = yard_wads [j]
			var ra: float = BeltPath.load_shape(wa) ["reach"]
			var rb: float = BeltPath.load_shape(wb) ["reach"]
			var d:= wa.global_position.distance_to(wb.global_position)

			if d >= (ra + rb) * 0.9:
				continue
			var a_rider:= BeltPath.is_rider(wa)
			var b_rider:= BeltPath.is_rider(wb)
			var kind:= "loose/loose"
			if a_rider and b_rider:
				var pa: int = int(wa.get_meta(LiveStrandManager.META_RIDER, -1))
				var pb: int = int(wb.get_meta(LiveStrandManager.META_RIDER, -1))
				kind = "rider/rider same path" if pa == pb else "rider/rider two paths"
			elif a_rider or b_rider:
				kind = "rider/loose"
			kinds [kind] = int(kinds [kind]) + 1
			if examples.size() < 6:
				examples.append("%s: %.2f m apart (reaches %.2f+%.2f) at %s near %s, %d and %d strands"
					% [kind, d, ra, rb, _v(wa.global_position),
						_nearest_machine(wa.global_position), wa.strands, wb.strands])
	var total_pairs:= 0
	for k in kinds:
		total_pairs += int(kinds [k])
	if total_pairs > 0:
		print("    wads inside each other: %s" % str(kinds))
		for line in examples:
			print("      %s" % line)
	for n in b.splitters.size():
		var s: ConveyorSplitter = b.splitters [n]
		var feeder: Conveyor = b.feed_run_into(s.port_in())
		var routes:= []
		for side in ConveyorSplitter.SIDES:
			var route:= s.route(side)
			if route == null:
				routes.append("-")
				continue
			routes.append("%s riders %d wait %s room %s stall %.2f catch %s" % [
				"L" if side == ConveyorSplitter.LEFT else "R", route.riders().size(),
				route.has_rider_waiting(), s._has_room(side), float(s._stall [side]),
				route._catching])
		var feed_txt:= "-"
		if feeder != null:
			feed_txt = "riders %d wait %s -> %s" % [feeder.riders().size(),
				feeder.has_rider_waiting(), _name_of(feeder.downstream)]
		print("  S%d open %d next %d | feeder %s | %s" % [n, s._open_side(), s.next_side,
			feed_txt, " | ".join(PackedStringArray(routes))])


		var spots:= []
		var pairs:= 0
		var near_wads:= []
		for w in wads:
			if not is_instance_valid(w) or not w.is_inside_tree():
				continue
			if w.global_position.distance_to(s.global_position) > NEAR:
				continue
			near_wads.append(w)
			if not BeltPath.is_rider(w):
				var p:= s.to_local(w.global_position)
				var v:= w.linear_velocity
				spots.append("(%.1f,%.1f,%.1f v%.1f vy%.2f %s%s)" % [p.x, p.y, p.z,
					Vector2(v.x, v.z).length(), v.y,
					str(BeltPath.debug_last_refusal.get(w.get_instance_id(), "never asked")),
					" asleep" if w.sleeping else ""])
		for i in near_wads.size():
			for j in range(i + 1, near_wads.size()):
				if near_wads [i].global_position.distance_to(near_wads [j].global_position) < 0.3:
					pairs += 1
		if not spots.is_empty() or pairs > 0:
			print("    S%d loose here %d, overlapping pairs %d: %s" % [n, spots.size(), pairs,
				" ".join(PackedStringArray(spots))])


const PELLET_WATCH:= 240


func _pellets(b: BuildManager) -> void:
	var mills: Array = b.pelletizers
	print("PELLETS: %d pelletizers" % mills.size())
	var thrown:= { }


	for m: HayPelletizer in mills:
		var t0:= Time.get_ticks_usec()
		for _i in 100:
			m._launcher.belt_landing(HayPelletizer.BRICK_REACH)
		var t1:= Time.get_ticks_usec()
		for _i in 100:
			m._resolve_aim()
			m._deck_takes(m._aim_belt) if m._aim_belt != null else true
		var t2:= Time.get_ticks_usec()
		print("  %s: belt_landing %.0f us, landing + room check %.0f us"
			% [m.name, (t1 - t0) / 100.0, (t2 - t1) / 100.0])
	if "--pelletcost" in OS.get_cmdline_user_args():
		return
	for m: HayPelletizer in mills:
		thrown [m] = 0
		var land: Dictionary = m._launcher.belt_landing(HayPelletizer.BRICK_REACH)
		var belt: BeltPath = land.get("belt")
		print("  %s at %s throw %.2f m, floor spot %s, lands on %s%s"
			% [m.name, _v(m.global_position), m.throw_distance, _v(m.throw_target()),
				_name_of(belt) if belt != null else "the floor",
				"" if belt == null else " at %s after %.2f s, blocked %s, room %s" % [
					_v(land ["at"]), land ["t"], belt.is_blocked(),
					belt.has_room_near(land ["at"], belt.drive_speed * float(land ["t"]))]])
		m.bricked.connect(func(brick: EcoBrick) -> void:
			thrown [m] += 1
			print("    %s threw (aim %s, holding %s)" % [m.name,
				_name_of(m._aim_belt) if m._aim_belt != null else "floor", m._holding]))
	for t in 60 * PELLET_WATCH:
		for m: HayPelletizer in mills:
			m.stored = m.buffer_capacity()
		await get_tree().physics_frame
		if t % 3600 == 3599:
			print("  -- %d s" % ((t + 1) / 60))
			for m: HayPelletizer in mills:
				print("    %s holding %s, %d thrown: %s"
					% [m.name, m._holding, thrown [m], _deck_state(m)])
	for m: HayPelletizer in mills:
		print("  %s: %d thrown in %d s, holding %s, alert '%s'"
			% [m.name, thrown [m], PELLET_WATCH, m._holding, m.alert_reason()])


func _deck_state(m: HayPelletizer) -> String:
	var belt: BeltPath = m._aim_belt
	if belt == null or not is_instance_valid(belt):
		return "floor"
	var paths: Array [BeltPath] = [belt]
	paths.append_array(belt._shared)
	var out:= PackedStringArray()
	for p in paths:
		if not is_instance_valid(p):
			continue
		out.append("%s[blk %s room %s catch %s rec %d]" % [_name_of(p), p.is_blocked(),
			p.has_room_near(m._aim_at, p.drive_speed * m._aim_flight), p._catching,
			p.run.count()])
	return ", ".join(out)


func _run_ending_at(point: Vector3) -> Conveyor:
	var b: BuildManager = world.builds
	var at:= point
	for c in b.corners:
		if is_instance_valid(c) and c.to_point.is_equal_approx(point):
			at = c.from_point
	for c in b.conveyors:
		if is_instance_valid(c) and (c.b.is_equal_approx(at) or c.laid_end().is_equal_approx(at)):
			return c
	return null


func _what_ends_at(point: Vector3) -> String:
	var b: BuildManager = world.builds
	for c in b.corners:
		if is_instance_valid(c) and c.to_point.is_equal_approx(point):
			return "corner from %s" % _v(c.from_point)
	for c in b.conveyors:
		if is_instance_valid(c) and c.b.is_equal_approx(point):
			return "run from %s" % _v(c.a)
	for s in b.splitters:
		for side in ConveyorSplitter.SIDES:
			if s.port(side).is_equal_approx(point):
				return "splitter %s arm" % ("L" if side == ConveyorSplitter.LEFT else "R")
	return "nothing at %s" % _v(point)


func _name_of(p: BeltPath) -> String:
	if p == null:
		return "NONE"
	var b: BuildManager = world.builds


	if p is Conveyor:
		var idx:= b.conveyors.find(p as Conveyor)
		if idx >= 0:
			return "run%d" % idx
	if p is ConveyorCorner:
		var idx:= b.corners.find(p as ConveyorCorner)
		if idx >= 0:
			return "corner%d" % idx
	for n in b.splitters.size():
		var s: ConveyorSplitter = b.splitters [n]
		for side in ConveyorSplitter.SIDES:
			if s.route(side) == p:
				return "S%d.%s" % [n, "L" if side == ConveyorSplitter.LEFT else "R"]
	return p.name


static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


func _over_a_belt(p: Vector3) -> bool:
	var b: BuildManager = world.builds
	var paths: Array = []
	paths.append_array(b.conveyors)
	paths.append_array(b.corners)
	for s in b.splitters:
		paths.append_array((s as ConveyorSplitter).routes())
	for path in paths:
		var bp:= path as BeltPath
		if bp == null or not is_instance_valid(bp) or bp.path_length() < 0.01:
			continue
		var at: Dictionary = bp._nearest(p)
		var s:= float(at ["s"])
		if s < 0.0 or s > bp.path_length():
			continue
		if absf(float(at ["side"])) > Cfg.BELT_WIDTH * 0.5 + 0.1:
			continue
		if float(at ["lift"]) < -0.1 or float(at ["lift"]) > 0.6:
			continue
		return true
	return false


func _nearest_machine(p: Vector3) -> String:
	var b: BuildManager = world.builds
	var best:= "nothing"
	var best_d:= INF
	for n in b.splitters.size():
		var d: float = p.distance_to((b.splitters [n] as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = "S%d %.1f m" % [n, d]
	for n in b.robotic_arms.size():
		var d: float = p.distance_to((b.robotic_arms [n] as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = "arm%d %.1f m" % [n, d]
	for n in b.generators.size():
		var d: float = p.distance_to((b.generators [n] as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = "gen%d %.1f m" % [n, d]
	return best
