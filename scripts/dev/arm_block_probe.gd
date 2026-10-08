class_name DevArmBlockProbe
extends Node


var world: Node3D

const SETTLE:= 40


const WATCH:= 2400


const STUCK:= 300

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	await _check_drop_geometry()
	await _check_block_footprint()
	await _check_reserve_wiring()
	await _check_live_run()
	print("\n[arm-block] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		_fail(label)


func _yard() -> Dictionary:
	var builds: BuildManager = world.builds
	builds.clear()
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var feed_end:= Vector3(13.0, deck_y, -1.0)
	var press:= builds.add_compressor(
		feed_end + Vector3(0, 0, Cfg.COMPRESSOR_LENGTH * 0.5), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	var fwd:= press.forward()
	var out_a:= press.port_out()
	var run_in:= builds.add_conveyor(press.port_in() - fwd * 6.0, press.port_in())
	var run_out:= builds.add_conveyor(out_a, out_a + fwd * 6.0)
	var side:= Vector3(fwd.z, 0.0, - fwd.x).normalized()
	var arm:= builds.add_robotic_arm(out_a * Vector3(1, 0, 1) + side * 1.6, 0.0, 1)
	for i in SETTLE:
		await get_tree().physics_frame
	return { "press": press, "arm": arm, "in": run_in, "out": run_out }


func _check_drop_geometry() -> void:
	print("\n=== the spot an arm beside a press picks ===")
	var yard:= await _yard()
	var press: HayCompressor = yard ["press"]
	var arm: RoboticArm = yard ["arm"]
	var builds: BuildManager = world.builds
	var fwd:= press.forward()
	var side:= Vector3(fwd.z, 0.0, - fwd.x).normalized()
	var origin:= press.global_position * Vector3(1, 0, 1)

	var bad:= 0
	var tried:= 0
	for along in [-1.6, -0.8, 0.0, 0.8, 1.6, 2.4]:
		for out in [1.2, 1.6, 2.0, 2.4]:
			arm.global_position = origin + fwd * along + side * out
			for i in 4:
				await get_tree().physics_frame
			var line:= await _sample(builds, arm, press)
			if line.is_empty():
				continue
			tried += 1
			if bool(line ["bad"]):
				bad += 1
				print("  BAD   along=%+.1f out=%.1f  %s" % [along, out, line ["why"]])
			else:
				print("  ok    along=%+.1f out=%.1f  %s" % [along, out, line ["why"]])
	print("  %d of %d stands put a load somewhere the press owns" % [bad, tried])
	_check("no stand an arm can take drops a load into the press", bad == 0)


func _sample(builds: BuildManager, arm: RoboticArm,
		press: HayCompressor) -> Dictionary:
	var runs:= builds.conveyor_drops(arm._shoulder_world(), arm.reach_m() * 0.98)
	if runs.is_empty():
		return { }
	var speed:= Tech.belt_speed()
	var count:= int(arm.tier_data() ["capacity"])


	var half:= Cfg.WAD_CLEAR * 0.5 * HayWad.scale_for(count)
	for entry in runs:
		var run:= entry ["conveyor"] as BeltPath
		var nearest:= entry ["point"] as Vector3
		var release:= run.usable_release(nearest, speed, arm._drop_lead(), half)
		if not run.has_room_to_land(release, speed, arm._drop_lead(), half):
			continue
		var landing:= run.landing_point(release, speed)
		var gap:= landing.distance_to(press.bale_spot())
		var why:= ""
		if not _build_clear(release, count, run):
			why = "the claw opens inside a placed body"
		elif not _build_clear(landing, count, run):
			why = "the load comes down inside a placed body"
		elif await _blocks_the_press(landing, count, press):
			why = "the load lands on the press's own outfeed (%.2f m from it)" % gap
		return {
			"bad": not why.is_empty(),
			"why": why if not why.is_empty()
				else "landing %.2f m from the bale spot" % gap,
		}


	return { "bad": false, "why": "no run would take a load at all" }


func _blocks_the_press(at: Vector3, count: int, press: HayCompressor) -> bool:
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
		{ "strands": count }) as HayWad
	if wad == null:
		return false
	wad.freeze = true
	await get_tree().physics_frame
	var blocked:= not press._bale_room(press.bale_spot())
	world.props.remove(wad)
	await get_tree().physics_frame
	return blocked


func _check_block_footprint() -> void:
	print("\n=== a carried block is charged its own size ===")
	var yard:= await _yard()
	var arm: RoboticArm = yard ["arm"]
	var count:= Cfg.COMPRESSOR_BALE_STRANDS
	var bale:= world.props.spawn("hay_bale", Transform3D(Basis(), Vector3(9, 3, 9)),
		{ "strands": count }) as HayBale
	if bale == null:
		_fail("could not spawn a bale to measure")
		return
	await get_tree().physics_frame
	var block:= bale.clearance_size()
	var wad:= HayWad.clearance_for(count)
	print("  a bale of %d strands is %.2f x %.2f x %.2f"
		% [count, block.x, block.y, block.z])
	print("  a wad  of %d strands is %.2f x %.2f x %.2f"
		% [count, wad.x, wad.y, wad.z])
	_check("a bale asks for more room than the wad it was measured as",
		block.x > wad.x and block.y > wad.y and block.z > wad.z)
	_check("...and the arm charges the bale that, not the wad",
		is_equal_approx(arm._footprint(count, bale), maxf(block.x, block.z) * 0.5))
	_check("...while a load that is still hay in the claw is still a wad",
		is_equal_approx(arm._footprint(count, null), Cfg.WAD_CLEAR * 0.5
			* HayWad.scale_for(count)))
	world.props.remove(bale)


func _check_reserve_wiring() -> void:
	print("\n=== the reserve is wired to the network ===")
	var yard:= await _yard()
	var press: HayCompressor = yard ["press"]
	var run_out: Conveyor = yard ["out"]
	var run_in: Conveyor = yard ["in"]
	print("  out=%.2f m  in=%.2f m  (the press asks for %.2f)"
		% [run_out.head_reserve(), run_in.head_reserve(), press.outfeed_reserve()])
	_check("the run leaving the press has a reserved head",
		run_out.head_reserve() > 0.0)


	_check("...and the run feeding it does not",
		is_zero_approx(run_in.head_reserve()))
	world.builds.demolish(press)
	for i in SETTLE:
		await get_tree().physics_frame
	_check("...and the reserve goes when the press does",
		is_zero_approx(run_out.head_reserve()))


func _check_live_run() -> void:
	print("\n=== and what that does to the press over time ===")
	var yard:= await _yard()
	var press: HayCompressor = yard ["press"]
	var arm: RoboticArm = yard ["arm"]


	var feed_at:= arm.global_position + Vector3(0.0, 0.6, -1.4)
	var blocked_for:= 0
	var worst:= ""
	for i in WATCH:
		if i % 240 == 0:
			world.props.spawn("hay_wad", Transform3D(Basis(), feed_at),
				{ "strands": 60 })
		var why:= press.alert_reason()
		if why.begins_with("OUTFEED"):
			blocked_for += 1
			worst = why
		else:
			blocked_for = 0
		if blocked_for > STUCK:
			break
		await get_tree().physics_frame
	print("  arm cycles=%d  blocked run=%d frames  arm says: %s"
		% [arm.completed_cycles, blocked_for, arm.alert_reason()])
	if not worst.is_empty():
		print("  alert seen: %s" % worst)
	_check("the press is not left blocked by what the arm put down",
		blocked_for <= STUCK)
	_report_near(press)


func _report_near(press: HayCompressor) -> void:
	var near: Array [String] = []
	for n in get_tree().root.find_children("*", "RigidBody3D", true, false):
		var rb:= n as RigidBody3D
		if not (rb.collision_layer & Cfg.L_PROP):
			continue
		var d:= rb.global_position.distance_to(press.bale_spot())
		if d > 3.0:
			continue
		near.append("%s at %.2f m from the bale spot, rider=%s, v=%.2f"
			% [rb.name, d, BeltPath.is_rider(rb), rb.linear_velocity.length()])
	print("  props within 3 m of the outfeed: %d" % near.size())
	for line in near:
		print("    %s" % line)


func _space() -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


func _build_clear(at: Vector3, count: int, run: BeltPath) -> bool:
	var probe:= BoxShape3D.new()
	var s:= HayWad.scale_for(count)
	probe.size = Vector3(Cfg.WAD_BASE_SIZE.x, Cfg.WAD_BASE_SIZE.y, Cfg.WAD_CLEAR) * s
	var query:= PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = Cfg.L_BUILD
	query.collide_with_areas = false
	query.transform = Transform3D(Basis(), at)
	var offenders: Array [String] = []
	for hit in _space().intersect_shape(query, 16):
		var body:= hit ["collider"] as Node
		if body == null:
			continue
		if run != null and run.is_ancestor_of(body):
			continue
		offenders.append(str(body.get_path()))
	if offenders.is_empty():
		return true
	for path in offenders:
		print("      in the way: %s" % path)
	return false
