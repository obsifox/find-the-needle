class_name DevThrowProbe
extends Node


const AIM_SLACK:= 0.03


const ARRIVE_SPEED:= 0.6


const SPANS:= [0.35, 0.9, 1.8, 3.0]


const SPILL:= 26


const NOT_THERE_YET:= 0.3


const LAND_FRAMES:= 45


const KEEP_RATIO:= 0.6

var world: Node3D
var player: Player
var field: HayField
var live: LiveStrandManager

var _fails:= 0


func run() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("\n=== does the hay actually fly? ===")
	if player == null or player.shovel == null or live == null:
		_fail("no tool to throw with")
		_finish()
		return
	Tech.reset()
	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)
	player.shovel.reset_aim()
	for _i in 10:
		await get_tree().physics_frame

	await _check_flight()


	await _check_gather_throws(Player.Tool.SHOVEL, "spade")
	await _check_gather_throws(Player.Tool.PITCHFORK, "pitchfork")
	await _check_a_full_bite_survives()
	await _check_a_stowed_tool_still_flies()
	_check_chaff()
	await _check_live_dig()
	_finish()


func _finish() -> void:
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	_fails += 1


func _check_flight() -> void:
	print("\n-- the flight lands where it aims, at rest --")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210


	var base:= Cfg.PILE_CENTER + Vector3.UP * (Cfg.PILE_HEIGHT + 6.0)
	var arcs:= {
		"level": Vector3(1.0, 0.0, 0.0),
		"uphill": Vector3(0.72, 0.7, 0.0),
		"downhill": Vector3(0.72, -0.7, 0.0),
	}
	for name: String in arcs:
		var dir: Vector3 = (arcs [name] as Vector3).normalized()
		for span: float in SPANS:
			var to:= base + dir * span
			var b:= live.spawn(base, StrandFactory.random_strand_basis(rng),
				Vector3.ZERO, StrandFactory.random_tint(rng))
			if b == null:
				_fail("the pool would not hand over a strand to throw")
				return
			var id:= b.get_instance_id()
			player.shovel._throw_strand(b, base, to)

			var frames:= 0
			var lofted:= 0.0
			while player.shovel._in_flight.has(id) and frames < LAND_FRAMES:
				await get_tree().physics_frame
				frames += 1


				lofted = maxf(lofted, _off_line(b.global_position, base, to))
			var missed:= b.global_position.distance_to(to)
			var speed:= b.linear_velocity.length()
			var ok:= missed <= AIM_SLACK and speed <= ARRIVE_SPEED
			print("  %-8s %.2f m in %2d frames: off by %.3f m at %.2f m/s, arc %.3f m  %s"
				% [name, span, frames, missed, speed, lofted,
				"ok" if ok else "BAD"])
			if frames >= LAND_FRAMES:
				_fail("a %.2f m %s flight never finished" % [span, name])
			if missed > AIM_SLACK:
				_fail("a %.2f m %s flight ended %.3f m from where it was aimed"
					% [span, name, missed])
			if speed > ARRIVE_SPEED:
				_fail("a %.2f m %s flight arrived at %.2f m/s, and the pan cannot catch that"
					% [span, name, speed])
			if lofted < 0.02:
				_fail("a %.2f m %s flight was a straight line, not a throw"
					% [span, name])
			LiveStrandManager.hold(b, 0.0)


func _off_line(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab:= b - a
	if ab.length_squared() < 1e-09:
		return p.distance_to(a)
	var t:= clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _check_gather_throws(which: Player.Tool, named: String) -> void:
	print("\n-- the %s throws spillage onto itself, it does not move it there --"
		% named)
	var tool_node: Shovel = player.shovel if which == Player.Tool.SHOVEL else player.pitchfork
	GameState.grant_tool(named)
	player._set_tool(which)
	tool_node.reset_aim()
	for _i in 12:
		await get_tree().physics_frame
	var at:= player.global_position - player.global_transform.basis.z * 1.2
	at.y = 0.15
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4242
	var dropped: Array [RigidBody3D] = []
	for _i in SPILL:
		var jitter:= Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * 0.05,
			rng.randf_range(-0.25, 0.25))
		var b:= live.spawn(at + jitter, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
		if b != null:
			dropped.append(b)
	for _i in 30:
		await get_tree().physics_frame
	if dropped.is_empty():
		_fail("nothing would spawn to pick up")
		return

	var g:= tool_node.pan_geometry()
	var pan: Vector3 = (g ["xf"] as Transform3D) * (g ["origin"] as Vector3)
	var took:= tool_node.gather_at(at, int(g ["max"]), float(g ["radius"]),
		g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]))
	if took <= 0:
		_fail("a blade aimed at spilled hay picked up none of it")
		return


	var moved:= 0
	var still:= 0
	var unclaimed:= 0
	var nearest:= INF
	var now:= Time.get_ticks_msec() * 0.001
	for b in dropped:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.linear_velocity.length() < 0.01:
			continue
		moved += 1
		nearest = minf(nearest, b.global_position.distance_to(pan))
		if b.global_position.distance_to(pan) < NOT_THERE_YET:
			still += 1
		if float(b.get_meta(LiveStrandManager.META_HOLD_UNTIL, 0.0)) <= now:
			unclaimed += 1
	print("  the blade took %d, %d of them left the floor moving" % [took, moved])
	print("  nearest one to the pan on that frame: %.2f m" % nearest)
	if moved <= 0:
		_fail("the gather set nothing moving: the load was placed, not thrown")
	if still > 0:
		_fail("%d strands were already within %.2f m of the pan on the frame they were taken"
			% [still, NOT_THERE_YET])
	if unclaimed > 0:
		_fail("%d strands were thrown without a hold and can be recycled mid-air"
			% unclaimed)

	var trace:= PackedStringArray()
	for _i in LAND_FRAMES:
		await get_tree().physics_frame
		if _i % 5 == 4:
			trace.append("f%d:%d" % [_i + 1, tool_node.carried_strands()])
	var carried:= tool_node.carried_strands()
	print("  on the blade over time: %s" % " ".join(trace))


	var inv:= tool_node.body.global_transform.orthonormalized().affine_inverse()
	var under:= 0
	for b in dropped:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if tool_node._riding.has(b.get_instance_id()):
			continue
		var l:= inv * b.global_position


		if l.y < 0.0 and l.y > -0.12 and absf(l.x) < 0.2 and absf(l.z) < 0.25:
			under += 1
	print("  %d ended up underneath the blade" % under)
	if under > 4:
		_fail("%d strands were driven through the plate they were thrown at"
			% under)
	print("  the tool flew hay on %d ticks" % tool_node.flown_ticks)
	print("  and %d of them are on the blade %d frames later" % [carried, LAND_FRAMES])
	if carried <= 0:
		_fail("the hay was thrown at the pan and none of it stayed there")


	for b in dropped:
		if is_instance_valid(b) and b.is_inside_tree():
			live.set_protected(b, false)
			b.global_position = Cfg.PILE_CENTER + Vector3.UP * 40.0
			b.linear_velocity = Vector3.ZERO
	await _control_placed_load(tool_node, carried)


func _control_placed_load(tool_node: Shovel, thrown_kept: int) -> void:
	tool_node.set_active(false)
	tool_node.set_active(true)
	for _i in 20:
		await get_tree().physics_frame
	var g:= tool_node.pan_geometry()
	var xf: Transform3D = g ["xf"]
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4242
	var placed: Array [RigidBody3D] = []
	for _i in SPILL:
		var local:= Vector3(
			rng.randf_range(-0.38, 0.38) * float(g ["w"]),
			Shovel.WALL_H * 1.6 + rng.randf() * 0.05,
			rng.randf_range(-0.38, 0.38) * float(g ["d"])) + (g ["origin"] as Vector3)
		var b:= live.spawn(xf * local, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
		if b != null:
			placed.append(b)
	for _i in LAND_FRAMES:
		await get_tree().physics_frame
	var kept:= tool_node.carried_strands()
	print("  for comparison, %d placed straight into the pan leaves %d on it"
		% [placed.size(), kept])
	if kept > 0 and float(thrown_kept) < float(kept) * KEEP_RATIO:
		_fail("the throw left %d on the blade where placing them leaves %d"
			% [thrown_kept, kept])
	tool_node.set_active(false)
	tool_node.set_active(true)


	for b in placed:
		if is_instance_valid(b) and b.is_inside_tree():
			live.set_protected(b, false)
			b.global_position = Cfg.PILE_CENTER + Vector3.UP * 40.0
			b.linear_velocity = Vector3.ZERO


func _check_a_full_bite_survives() -> void:
	print("\n-- a full bite is not recycled while it is crossing --")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 777
	var base:= Cfg.PILE_CENTER + Vector3.UP * (Cfg.PILE_HEIGHT + 6.0)
	var thrown: Array [RigidBody3D] = []
	for _i in Cfg.SCOOP_MAX:
		var from:= base + Vector3(rng.randfn(0.0, 0.1), 0.0, rng.randfn(0.0, 0.1))
		var b:= live.spawn(from, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
		if b == null:
			continue
		player.shovel._throw_strand(b, from, from + Vector3(0.9, 0.2, 0.0))
		thrown.append(b)
	if thrown.is_empty():
		_fail("the pool would not hand over a bite to throw")
		return


	var pressure: Array [RigidBody3D] = []
	for _i in LAND_FRAMES:
		for _n in 8:
			var extra:= live.spawn(base + Vector3.UP * 2.0,
				StrandFactory.random_strand_basis(rng), Vector3.ZERO,
				StrandFactory.random_tint(rng))
			if extra != null:
				pressure.append(extra)
		await get_tree().physics_frame

	var lost:= 0
	for b in thrown:
		if not is_instance_valid(b) or not b.is_inside_tree():
			lost += 1
	print("  threw %d, asked the pool for %d more mid-flight, lost %d"
		% [thrown.size(), pressure.size(), lost])
	if lost > 0:
		_fail("%d of %d strands were recycled while still in the air"
			% [lost, thrown.size()])
	for b in thrown + pressure:
		if is_instance_valid(b) and b.is_inside_tree():
			LiveStrandManager.hold(b, 0.0)


func _check_a_stowed_tool_still_flies() -> void:
	print("\n-- a stowed tool still flies what it threw --")
	player._set_tool(Player.Tool.PITCHFORK)
	for _i in 10:
		await get_tree().physics_frame
	if player.shovel._active:
		_fail("the spade is still out; this leg proves nothing")
		return

	var rng:= RandomNumberGenerator.new()
	rng.seed = 31337
	var from:= Cfg.PILE_CENTER + Vector3.UP * (Cfg.PILE_HEIGHT + 6.0)
	var to:= from + Vector3(0.8, 0.1, 0.0)
	var b:= live.spawn(from, StrandFactory.random_strand_basis(rng),
		Vector3.ZERO, StrandFactory.random_tint(rng))
	if b == null:
		_fail("the pool would not hand over a strand to throw")
		return
	var id:= b.get_instance_id()
	player.shovel._throw_strand(b, from, to)


	var frames:= 0
	while player.shovel._in_flight.has(id) and frames < LAND_FRAMES:
		await get_tree().physics_frame
		frames += 1
	var missed:= b.global_position.distance_to(to)
	print("  a stowed spade landed its throw %.3f m from the mark, in %d frames"
		% [missed, frames])
	if frames >= LAND_FRAMES:
		_fail("a stowed tool never finished its flight")
	elif missed > AIM_SLACK:
		_fail("a stowed tool left its throw %.2f m short: nothing flew it"
			% missed)
	LiveStrandManager.hold(b, 0.0)


func _check_chaff() -> void:
	print("\n-- the bite throws chaff --")
	var vfx: ScoopVfx = player.shovel.vfx
	if vfx == null:
		_fail("the tool built no chaff emitter")
		return


	if player.shovel.body != null and vfx.is_ancestor_of(player.shovel.body):
		_fail("the chaff emitter is under the tool and will follow the camera")
	if vfx.get_parent() == player.shovel:
		_fail("the chaff emitter is parented to the tool rather than the world")

	vfx.reset_stats()
	var at:= Cfg.PILE_CENTER + Vector3.UP * 2.0
	var first:= vfx.burst(at, Vector3.BACK, 1.0)
	var second:= vfx.burst(at, Vector3.BACK, 1.0)
	print("  a full bite emitted %d, an instant second bite %d" % [first, second])
	if first <= 0:
		_fail("a full bite threw no chaff at all")
	if second >= first:
		_fail("chaff is not rate limited: two bites in one frame cost %d and %d"
			% [first, second])
	var thin:= vfx.burst(at, Vector3.BACK, 0.0)
	if thin != 0:
		_fail("a bite that lifted nothing still threw %d chaff" % thin)


func _check_live_dig() -> void:
	print("\n-- a real bite starts in the pile --")
	if field == null:
		_fail("no field to dig")
		return


	player._set_tool(Player.Tool.SHOVEL)
	for _i in 12:
		await get_tree().physics_frame
	var g:= player.shovel.pan_geometry()
	var took:= 0
	var at:= Cfg.PILE_CENTER


	var pan:= Vector3.ZERO
	for step in 12:
		var angle:= float(step) * 1.0472
		var ring:= 1.5 + float(step) * 0.6
		at = Cfg.PILE_CENTER + Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)
		at.y = field.height_at(at.x, at.z) - 0.05
		pan = at + Vector3.UP * 0.6
		took = player.shovel.scoop_at(at, int(g ["max"]), float(g ["radius"]),
			Transform3D(Basis.IDENTITY, pan), Vector3.ZERO,
			float(g ["w"]), float(g ["d"]))
		if took > 0:
			break
	if took <= 0:
		print("        nothing was lit to dig: this leg needs a window.")
		print("        run: godot --path . -- --throw")
		return


	await get_tree().physics_frame


	var space:= player.get_world_3d().direct_space_state
	var shape:= SphereShape3D.new()
	shape.radius = float(g ["radius"]) * 4.0
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = Cfg.L_STRAND
	var moving:= 0
	for hit: Dictionary in space.intersect_shape(q, Cfg.SCOOP_MAX * 2):
		var rb:= hit.get("collider") as RigidBody3D
		if rb != null and rb.linear_velocity.length() > 0.05:
			moving += 1
	print("  dug %d strands; %d of them are still at the bite and moving"
		% [took, moving])
	if moving <= 0:
		_fail("a bite of %d strands left nothing moving at the bite: the load was spawned on the tool"
			% took)


	var arrived: Dictionary = { }
	q.transform = Transform3D(Basis.IDENTITY, pan)
	shape.radius = 0.3
	for _i in LAND_FRAMES:
		await get_tree().physics_frame
		for hit: Dictionary in space.intersect_shape(q, Cfg.SCOOP_MAX * 2):
			var rb:= hit.get("collider") as RigidBody3D
			if rb != null:
				arrived [rb.get_instance_id()] = true
	print("  %d of them reached the pan they were thrown at" % arrived.size())
	if arrived.size() * 3 < took:
		_fail("only %d of %d dug strands reached the pan they were thrown at"
			% [arrived.size(), took])
