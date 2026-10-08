class_name DevBeltAudit
extends Node


const LOG:= "res://belt_audit.log"
const SETTLE:= 40
const RIDE_SECONDS:= 2.5

var world: Node3D
var player: Player

var _rng:= RandomNumberGenerator.new()
var _paths: Array = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	_rng.seed = 20260824
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))


	await _settle(SETTLE)

	_collect()
	_report_geometry()
	_report_conflicts()
	await _report_rides()
	await _report_sleep()
	await _report_throws()
	await _report_across()
	await _report_stand()

	get_tree().quit()


func _collect() -> void:
	var b: BuildManager = world.builds
	for i in b.conveyors.size():
		_paths.append({ "label": "conveyor %d" % i, "path": b.conveyors [i] })
	for i in b.corners.size():
		_paths.append({ "label": "corner %d" % i, "path": b.corners [i] })


	for i in b.scanners.size():
		var s: HaystackScanner = b.scanners [i]
		if s._belt != null:
			_paths.append({ "label": "scanner %d module" % i, "path": s._belt })
	var stand: HaySellingStand = world.stand
	if stand != null and stand._belt != null:
		_paths.append({ "label": "selling stand belt", "path": stand._belt })


func _report_geometry() -> void:
	_log("=== what is built ===")
	var b: BuildManager = world.builds
	_log("  platforms %d, stairs %d, railings %d, scanners %d, cabinets %d, arms %d"
		% [b.platforms.size(), b.stairs.size(), b.railings.size(),
			b.scanners.size(), b.cabinets.size(), b.robotic_arms.size()])
	_log("  conveyor runs %d, corners fitted %d" % [b.conveyors.size(), b.corners.size()])

	for i in b.conveyors.size():
		var c: Conveyor = b.conveyors [i]
		_log("")
		_log("  conveyor %d  a=%.2v b=%.2v  len %.2f m  rise %.2f m  trim %.2f/%.2f  speed %.2f"
			% [i, c.a, c.b, c.length, c.b.y - c.a.y, c.trim_start, c.trim_end, c.drive_speed])
		_dump_spans(c)
	for entry in _paths:
		var p: BeltPath = entry ["path"]
		if p is Conveyor:
			continue
		_log("")
		_log("  %s  at %.2v  speed %.2f" % [entry ["label"], p.global_position, p.drive_speed])
		_dump_spans(p)


func _dump_spans(p: BeltPath) -> void:
	var spans: Array = p._spans
	if spans.is_empty():
		_log("      NO SPANS -- nothing was laid, so nothing can carry")
		return
	for j in spans.size():
		var span: Dictionary = spans [j]
		var area: Area3D = span ["area"]
		var body: StaticBody3D = span ["body"]
		var fwd: Vector3 = span ["forward"]
		if not is_instance_valid(area) or not is_instance_valid(body):
			_log("      span %d  DEAD (area %s, body %s)"
				% [j, is_instance_valid(area), is_instance_valid(body)])
			continue
		var box: BoxShape3D = (area.get_child(0) as CollisionShape3D).shape
		_log("      span %d  fwd %.2v  deck v %.2v  centre %.2v  drive box %.2v  monitoring %s"
			% [j, fwd, body.constant_linear_velocity, area.global_position,
				box.size, area.monitoring])


func _report_conflicts() -> void:
	_log("")
	_log("=== overlapping drive volumes ===")
	var spans: Array = []
	for entry in _paths:
		var p: BeltPath = entry ["path"]
		var list: Array = p._spans
		for j in list.size():
			var s: Dictionary = list [j]
			if not is_instance_valid(s ["area"]):
				continue
			spans.append({ "label": "%s span %d" % [entry ["label"], j], "span": s })

	var found:= 0
	for i in spans.size():
		for k in range(i + 1, spans.size()):
			var a: Dictionary = spans [i] ["span"]
			var b: Dictionary = spans [k] ["span"]
			var aa: Area3D = a ["area"]
			var ab: Area3D = b ["area"]
			var box_a: BoxShape3D = (aa.get_child(0) as CollisionShape3D).shape
			var box_b: BoxShape3D = (ab.get_child(0) as CollisionShape3D).shape


			var ra: float = box_a.size.length() * 0.5
			var rb: float = box_b.size.length() * 0.5
			var d:= aa.global_position.distance_to(ab.global_position)
			if d > ra + rb:
				continue
			var dot: float = (a ["forward"] as Vector3).dot(b ["forward"] as Vector3)
			var verdict:= "ok (same way)"
			if dot < -0.3:
				verdict = "OPPOSED -- hay here is pushed both ways"
			elif dot < 0.7:
				verdict = "crossing"
			_log("  %s  x  %s   overlap %.2f m, dot %+.2f  %s"
				% [spans [i] ["label"], spans [k] ["label"], (ra + rb) - d, dot, verdict])
			found += 1
	if found == 0:
		_log("  none")


func _report_rides() -> void:
	_log("")
	_log("=== a strand on each run ===")
	for entry in _paths:
		var p: BeltPath = entry ["path"]
		var spans: Array = p._spans
		if spans.is_empty():
			continue
		var mid: Dictionary = spans [spans.size() / 2]
		var area: Area3D = mid ["area"]
		if not is_instance_valid(area):
			continue


		var at: Vector3 = area.global_position + area.global_transform.basis.y * 0.15
		var body: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body == null:
			_log("  %s: no strand available" % entry ["label"])
			continue
		await _settle(45)
		if not _alive(body):
			_log("  %s: the strand was gone before the clock started" % entry ["label"])
			continue
		var start:= body.global_position
		var ticks:= int(RIDE_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
		var woke:= 0
		for i in ticks:
			await get_tree().physics_frame
			if not _alive(body):
				break
			if not body.sleeping:
				woke += 1
		if not _alive(body):
			_log("  %s: the strand was RECLAIMED mid-ride" % entry ["label"])
			continue
		var fwd: Vector3 = mid ["forward"]
		var moved:= body.global_position - start
		var along:= moved.dot(fwd)
		_log("  %s: landed y=%.2f, %.2f m along, %.2f m sideways, %.2f m down; awake %d/%d ticks"
			% [entry ["label"], start.y, along, (moved - fwd * along).length(),
				- moved.y, woke, ticks])
		if along < 0.3:
			_log("      did not travel  (in %d drive volume(s)) %s"
				% [_volumes_over(body), _rider_state(body)])
		world.live.consume(body)


func _report_sleep() -> void:
	_log("")
	_log("=== a strand that falls asleep on the deck ===")
	for entry in _paths:
		var p: BeltPath = entry ["path"]
		var spans: Array = p._spans
		if spans.is_empty():
			continue
		var mid: Dictionary = spans [spans.size() / 2]
		var area: Area3D = mid ["area"]
		if not is_instance_valid(area):
			continue
		var at: Vector3 = area.global_position + area.global_transform.basis.y * 0.05
		var body: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body == null:
			continue


		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true
		await get_tree().physics_frame
		await get_tree().physics_frame
		var seen_asleep: bool = body in area.get_overlapping_bodies()
		var reported: bool = area.has_overlapping_bodies()
		var start:= body.global_position
		var ticks:= int(1.5 / maxf(get_physics_process_delta_time(), 1e-06))
		for i in ticks:
			await get_tree().physics_frame
			if not _alive(body):
				break
		var moved:= 0.0
		var still_asleep:= true
		if _alive(body):
			moved = body.global_position.distance_to(start)
			still_asleep = body.sleeping
		_log("  %s: asleep on the deck -> drive volume sees it %s (area reports any %s); after 1.5 s moved %.2f m, sleeping %s"
			% [entry ["label"], seen_asleep, reported, moved, still_asleep])
		if _alive(body):
			world.live.consume(body)
		_log("")
		break


func _report_throws() -> void:
	_log("")
	_log("=== one strand thrown at a run, from where the player stands ===")


	_log("  thrown from 1.6 m to the side, eye 1.66 m up, at %.1f m/s" % HandTool.THROW_SPEED)
	for entry in _paths:
		var p: BeltPath = entry ["path"]
		if not (p is Conveyor):
			continue
		var run: Conveyor = p
		if run.length < 1.5:
			continue
		var made: Array = []
		for i in 9:
			var t:= 0.1 + 0.8 * (float(i / 3) / 2.0)
			var side:= (float(i % 3) - 1.0) * 0.3
			var across:= Vector3.UP.cross(run.forward).normalized()
			var target: Vector3 = run.laid_start().lerp(run.laid_end(), t) + across * side
			var eye: Vector3 = target + across * 1.6 + Vector3(0, 1.66, 0)
			var dir:= (target - eye).normalized()
			var b: RigidBody3D = world.live.spawn(eye,
				StrandFactory.random_strand_basis(_rng),
				dir * HandTool.THROW_SPEED + Vector3(0, 1.2, 0), Cfg.COL_HAY_LIGHT)
			if b != null:
				made.append({ "body": b, "target": target, "from": b.global_position })


		for tick in 300:
			await get_tree().physics_frame
			for m: Dictionary in made:
				var b: RigidBody3D = m ["body"]
				if not _alive(b):
					continue
				if _volumes_over(b) > 0:
					m ["reached"] = true


				if tick == 270:
					m ["late"] = b.global_position
		var tally: Dictionary = { }
		for m: Dictionary in made:
			var b: RigidBody3D = m ["body"]
			if not _alive(b):
				_bump(tally, "reclaimed mid-flight")
				continue
			var here:= b.global_position
			var reached: bool = m.get("reached", false)
			var rest:= _resting_on(b)
			var moved_late: float = (here - (m.get("late", here) as Vector3)).length()
			var verdict:= ""
			if not reached and rest != "belt":
				verdict = "MISSED the belt, landed on the %s" % rest
			elif reached and rest == "belt" and moved_late < 0.01:
				verdict = "STUCK ON THE DECK"
			elif reached and rest != "belt":
				verdict = "reached the deck, then ended up on the %s" % rest
			else:
				verdict = "riding"
			_bump(tally, verdict)
			if verdict.begins_with("STUCK") or verdict.begins_with("reached"):
				_log("      aimed %.2v -> %.2v  %s  (%.2f m off centre, sleeping %s, in %d volume(s)) %s"
					% [m ["target"], here, verdict, _off_centre(here, run), b.sleeping,
						_volumes_over(b), _rider_state(b)])
			world.live.consume(b)
		var parts:= PackedStringArray()
		for k: String in tally:
			parts.append("%d %s" % [tally [k], k])
		_log("  %s (%.1f m): thrown %d -> %s"
			% [entry ["label"], run.length, made.size(), ", ".join(parts)])


func _report_across() -> void:
	_log("")
	_log("=== one strand at a time, across the width of the deck ===")
	var run: Conveyor = null
	for entry in _paths:
		var p: BeltPath = entry ["path"]
		if p is Conveyor and (p as Conveyor).length > 5.0:
			run = p
			break
	if run == null:
		_log("  no run long enough to measure on")
		return
	var across:= Vector3.UP.cross(run.forward).normalized()
	var at:= run.laid_start().lerp(run.laid_end(), 0.25)


	for side: float in [0.0, 0.2, 0.35, 0.4, 0.43, 0.46, -0.43]:
		for lift: float in [0.02, 0.15]:
			var p:= at + across * side + Vector3(0, lift, 0)
			var b: RigidBody3D = world.live.spawn(p,
				StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
			if b == null:
				continue
			await _settle(60)
			if not _alive(b):
				_log("  %+.2f m off centre, dropped from %.2f: RECLAIMED" % [side, lift])
				continue
			var start:= b.global_position
			await _settle(120)
			if not _alive(b):
				_log("  %+.2f m off centre, dropped from %.2f: RECLAIMED mid-ride" % [side, lift])
				continue
			var travel:= (b.global_position - start).dot(run.forward)
			_log("  %+.2f m off centre, dropped from %.2f: settled at %.2v, carried %.2f m in 2 s, on the %s, in %d volume(s), sleeping %s"
				% [side, lift, start, travel, _resting_on(b), _volumes_over(b), b.sleeping])
			world.live.consume(b)


func _report_stand() -> void:
	_log("")
	_log("=== hay put on the selling stand's belt ===")
	var stand: HaySellingStand = world.stand
	if stand == null or stand._belt == null:
		_log("  no stand in this save")
		return
	var belt: BeltPath = stand._belt
	var before:= GameState.money
	var fed:= 0
	for i in 6:


		var at: Vector3 = belt._point_at(0.35 + 0.2 * i) + Vector3(0, 0.1, 0)
		var b: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if b != null:
			fed += 1
		await _settle(12)


	var carried:= 0
	for i in 900:
		await get_tree().physics_frame
		if belt.has_strands():
			carried += 1
	_log("  belt is %.2f m long, drive %.2f m/s" % [belt.path_length(), belt.drive_speed])
	_log("  fed %d strands, belt reported a load on %d of 900 ticks" % [fed, carried])
	_log("  balance %.2f -> %.2f (%+.2f)" % [before, GameState.money, GameState.money - before])
	if is_equal_approx(before, GameState.money):
		_log("  NOTHING WAS SOLD -- the hay never reached the payout")


func _rider_state(b: RigidBody3D) -> String:
	if not b.has_meta(LiveStrandManager.META_RIDER):
		return "[not a rider, freeze %s]" % b.freeze
	var path:= b.get_meta(LiveStrandManager.META_RIDER) as BeltPath
	if path == null:
		return "[rider of a dead path]"
	var label:= "?"
	for entry in _paths:
		if entry ["path"] == path:
			label = entry ["label"]
	for r: BeltPath.Rider in path._riders:
		if r.body == b:
			return "[rider of %s: s %.2f of %.2f, speed %.2f]" % [label, r.s,
				path.path_length(), r.speed]
	return "[flagged for %s but not on its list]" % label


func _bump(d: Dictionary, key: String) -> void:
	d [key] = int(d.get(key, 0)) + 1


func _resting_on(b: RigidBody3D) -> String:
	var from:= b.global_position + Vector3(0, 0.02, 0)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -0.4, 0))
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PROP
	q.hit_from_inside = true
	var hit: Dictionary = get_viewport().get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "nothing (still in the air)"
	var node: Node = hit ["collider"]
	while node != null:
		if node is BeltPath:
			return "belt"
		node = node.get_parent()
	return "floor"


func _off_centre(p: Vector3, run: Conveyor) -> float:
	var d:= p - run.laid_start()
	return (d - run.forward * d.dot(run.forward)).length()


func _alive(b: RigidBody3D) -> bool:
	return is_instance_valid(b) and b.get_parent() != null


func _volumes_over(b: RigidBody3D) -> int:
	var n:= 0
	for entry in _paths:
		var list: Array = (entry ["path"] as BeltPath)._spans
		for s: Dictionary in list:
			var area: Area3D = s ["area"]
			if is_instance_valid(area) and b in area.get_overlapping_bodies():
				n += 1
	return n


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _log(line: String) -> void:
	print("[beltaudit] %s" % line)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()
