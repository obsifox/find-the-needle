class_name DevRideProbe
extends Node


const LOG:= "res://ride_probe.log"


const RUN_A:= Vector3(13.0, 0.75, -5.0)
const RUN_B:= Vector3(13.0, 0.75, 5.0)
const DECK_Y:= 0.75


const DROP_HEIGHT:= 1.1
const RIDE_SECONDS:= 3.0


const HOLD_SECONDS:= 1.5

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()
var _rng:= RandomNumberGenerator.new()
var _belt: Conveyor


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	_rng.seed = 20260824
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	GameState.add_money(2000.0)


	player.global_position = Vector3(6.0, 0.5, -8.0)
	await _settle(30)

	_belt = world.builds.add_conveyor(RUN_A, RUN_B)
	await _settle(40)
	_log("belt laid, deck at y=%.2f, %.2f m/s along %.2v, deck collides %.2f m deep"
		% [DECK_Y, Cfg.BELT_SPEED, _belt.forward, Cfg.BELT_DECK_THICK])

	await _case_ccd_survives_the_hold()
	await _case_thrown_by_hand()
	await _case_hay_lands_and_rides()
	await _case_needle_lands_and_rides()
	await _case_prop_rides()
	await _case_climb_holds_hay()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_ccd_survives_the_hold() -> void:
	_log("\n=== continuous collision survives being held ===")
	var b: RigidBody3D = world.live.spawn(Vector3(6.0, 1.5, -8.0),
		StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	if b == null:
		_fails.append("could not spawn a strand to hold")
		return
	player.hand._grab(b)
	await _settle(int(HOLD_SECONDS * 60.0))
	var held_ccd:= b.continuous_cd
	player.hand.throw_held()
	var thrown_ccd:= b.continuous_cd
	_log("  after %.1f s in the hand: ccd %s; on release: ccd %s"
		% [HOLD_SECONDS, held_ccd, thrown_ccd])
	if not thrown_ccd:
		_fails.append("a strand held for %.1f s is thrown with no continuous collision"
			% HOLD_SECONDS)
	await _settle(30)
	if _live(b):
		world.live.consume(b)


func _case_thrown_by_hand() -> void:
	_log("\n=== one strand thrown by hand, the way the player throws it ===")
	var stuck:= 0
	var carried:= 0
	var missed:= 0
	for i in 8:


		var target: Vector3 = RUN_A.lerp(RUN_B, 0.05 + 0.025 * i)
		player.global_position = target + Vector3(2.2, 0.0, -0.9)
		var b: RigidBody3D = world.live.spawn(player.global_position + Vector3(0, 1.5, 0),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if b == null:
			continue
		player.hand._grab(b)
		await _settle(10)
		_aim_to_land_on(target)
		await _settle(2)
		player.hand.throw_held()

		await _settle(90)
		if not _live(b):
			missed += 1
			continue
		var from:= b.global_position
		await _settle(int(RIDE_SECONDS * 60.0))
		if not _live(b):
			missed += 1
			continue
		var moved:= b.global_position.distance_to(from)
		var on_belt: bool = b.global_position.y > DECK_Y - 0.2
		if not on_belt:
			missed += 1
		elif moved > 1.0:
			carried += 1
		else:
			stuck += 1
			_log("  STUCK at %.2v after %.1f s, moved %.2f m, rider %s"
				% [b.global_position, RIDE_SECONDS, moved, BeltPath.is_rider(b)])
		world.live.consume(b)
	_log("  thrown 8: carried %d, missed the belt %d, STUCK ON IT %d"
		% [carried, missed, stuck])
	if stuck > 0:
		_fails.append("%d of 8 hand-thrown strands sat still on a running belt" % stuck)
	if carried == 0:
		_fails.append("not one hand-thrown strand ever landed on the belt")


func _aim_to_land_on(target: Vector3) -> void:
	var aim:= target
	for i in 8:
		_aim_at(aim)
		var landed:= _simulate_throw()
		var miss:= target - landed
		miss.y = 0.0
		if miss.length() < 0.02:
			break
		aim += miss


func _aim_at(target: Vector3) -> void:
	var dir:= (target - player.eye_position()).normalized()
	player.rotation.y = atan2(- dir.x, - dir.z)
	player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))


func _simulate_throw() -> Vector3:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var dt:= 1.0 / 60.0
	var p:= player.eye_position()
	var v: Vector3 = player.look_direction() * HandTool.THROW_SPEED + Vector3(0, 1.2, 0)
	for i in 300:


		v.y -= g * dt
		v *= maxf(0.0, 1.0 - Cfg.STRAND_LINEAR_DAMP * dt)
		p += v * dt
		if p.y <= DECK_Y:
			break
	return p


func _case_hay_lands_and_rides() -> void:
	_log("\n=== hay thrown down onto the deck ===")
	var made: Array [RigidBody3D] = []
	for i in 12:
		var b: RigidBody3D = world.live.spawn(_drop_point(i, 12),
			StrandFactory.random_strand_basis(_rng),
			Vector3(0, - HandTool.THROW_SPEED, 0), Cfg.COL_HAY_LIGHT)
		if b != null:
			made.append(b)
	await _measure("strand", made)
	for b in made:
		if _live(b):
			world.live.consume(b)


func _case_needle_lands_and_rides() -> void:
	_log("\n=== a needle thrown down onto the deck ===")
	var made: Array [RigidBody3D] = []
	for i in 8:
		var n: RigidBody3D = world.live.reveal_needle(-1, _drop_point(i, 8))
		if n == null:
			continue
		n.linear_velocity = Vector3(0, - HandTool.THROW_SPEED, 0)
		made.append(n)
	await _measure("needle", made)
	for n in made:
		world.live.consume_needle(n)


func _case_prop_rides() -> void:
	_log("\n=== a bucket thrown down onto the deck ===")
	var item: Carryable = world.props.spawn("bucket",
		Transform3D(Basis.IDENTITY, Vector3(13.0, DECK_Y + DROP_HEIGHT, -4.0)))
	if item == null:
		_fails.append("could not spawn a bucket to throw")
		return
	item.linear_velocity = Vector3(0, - Cfg.CARRY_THROW_SPEED, 0)
	await _settle(60)
	var start: float = item.global_position.dot(_belt.forward)
	var low: float = item.global_position.y
	for i in int(RIDE_SECONDS * 60.0):
		await get_tree().physics_frame
		low = minf(low, item.global_position.y)
	var moved: float = item.global_position.dot(_belt.forward) - start
	_log("  lowest %.2f m, carried %.2f m in %.1f s" % [low, moved, RIDE_SECONDS])
	if low < DECK_Y - 0.4:
		_fails.append("the bucket went through the deck (down to y=%.2f)" % low)
	elif moved < 1.0:
		_fails.append("the bucket sat still on a running belt (%.2f m)" % moved)
	world.props.remove(item)


func _case_climb_holds_hay() -> void:
	_log("\r\n=== hay thrown onto a belt that CLIMBS ===")
	var rise:= tan(Cfg.BELT_MAX_SLOPE * 0.95) * 8.0
	var a:= Vector3(17.0, 0.6, -4.0)
	var b:= Vector3(17.0, 0.6 + rise, 4.0)
	var climb: Conveyor = world.builds.add_conveyor(a, b)
	if climb == null:
		_fails.append("could not lay a climbing run")
		return
	await _settle(40)
	var basis:= BeltPath.run_basis(a, b)
	_log("  run climbs %.2f m over %.2f m (%.1f deg, max %.1f)"
		% [rise, a.distance_to(b), rad_to_deg(atan(rise / 8.0)),
			rad_to_deg(Cfg.BELT_MAX_SLOPE)])

	var made: Array [RigidBody3D] = []
	for i in 12:
		var t:= 0.04 + 0.2 * (float(i) + 0.5) / 12.0
		var at: Vector3 = a.lerp(b, t) + basis.y * DROP_HEIGHT
		var s: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng),
			- basis.y * HandTool.THROW_SPEED, Cfg.COL_HAY_LIGHT)
		if s != null:
			made.append(s)
	if made.is_empty():
		_fails.append("nothing to drop onto the climbing run")
		world.builds.demolish(climb)
		return


	var deepest: Array [float] = []
	deepest.resize(made.size())
	deepest.fill(0.0)
	var start: Array [float] = []
	start.resize(made.size())
	start.fill(0.0)
	for i in 90:
		await get_tree().physics_frame
		_sample_plane(made, a, basis, deepest)
	for k in made.size():
		start [k] = made [k].global_position.dot(basis.z) if _live(made [k]) else 0.0
	for i in int(RIDE_SECONDS * 60.0):
		await get_tree().physics_frame
		_sample_plane(made, a, basis, deepest)

	var through:= 0
	var gone:= 0
	var slid_back:= 0
	var carried:= 0
	for k in made.size():
		if not _live(made [k]):
			gone += 1
			continue
		if deepest [k] < -0.25:
			through += 1
			_log("  THROUGH the deck: %.2f m under the rubber" % - deepest [k])
			continue
		var moved: float = made [k].global_position.dot(basis.z) - start [k]
		if moved > 0.5:
			carried += 1
		elif moved < -0.2:
			slid_back += 1
		else:
			_log("  STUCK at %.2v, moved %.2f m along the climb"
				% [made [k].global_position, moved])
	_log("  dropped %d: through the deck %d, gone %d, slid back down %d, carried up %d"
		% [made.size(), through, gone, slid_back, carried])
	if through > 0:
		_fails.append("%d of %d strands went through a CLIMBING deck"
			% [through, made.size()])
	if gone > 0:
		_fails.append("%d of %d strands left the world off a climbing run"
			% [gone, made.size()])
	if slid_back > 0:
		_fails.append("%d of %d strands slid back down a climbing belt"
			% [slid_back, made.size()])

	for s in made:
		if _live(s):
			world.live.consume(s)
	world.builds.demolish(climb)


func _sample_plane(made: Array [RigidBody3D], origin: Vector3, basis: Basis,
		deepest: Array [float]) -> void:
	for k in made.size():
		if not _live(made [k]):
			continue
		var d: float = (made [k].global_position - origin).dot(basis.y)
		deepest [k] = minf(deepest [k], d)


func _drop_point(i: int, of: int) -> Vector3:
	var t:= 0.04 + 0.2 * (float(i) + 0.5) / float(of)
	return RUN_A.lerp(RUN_B, t) + Vector3(0, DROP_HEIGHT, 0)


func _measure(what: String, made: Array [RigidBody3D]) -> void:
	if made.is_empty():
		_fails.append("nothing to drop for the %s case" % what)
		return


	var low: Array [float] = []
	var crossed: Array [float] = []
	low.resize(made.size())
	low.fill(9999.0)
	crossed.resize(made.size())
	crossed.fill(-1.0)
	for i in 90:
		await get_tree().physics_frame
		_sample(made, low, crossed)

	var start: Array [float] = []
	start.resize(made.size())
	for k in made.size():
		start [k] = made [k].global_position.dot(_belt.forward) if _live(made [k]) else 0.0
	for i in int(RIDE_SECONDS * 60.0):
		await get_tree().physics_frame
		_sample(made, low, crossed)

	var through:= 0
	var bounced_off:= 0
	var on_deck:= 0
	var carried:= 0
	var gone:= 0
	for k in made.size():
		if not _live(made [k]):
			gone += 1
			continue
		if low [k] < DECK_Y - 0.4:
			if crossed [k] >= 0.0 and crossed [k] < Cfg.BELT_WIDTH * 0.5:
				through += 1
			else:
				bounced_off += 1
				_log("  BOUNCED OFF at %.2f m from the centreline" % crossed [k])
			continue
		on_deck += 1
		var moved: float = made [k].global_position.dot(_belt.forward) - start [k]
		if moved > 1.0:
			carried += 1
		else:
			_log("  STUCK at %.2v after %.1f s, moved %.2f m, v %.2v"
				% [made [k].global_position, RIDE_SECONDS, moved,
					made [k].linear_velocity])
	_log("  dropped %d: through the deck %d, bounced off %d, gone %d, on the deck %d, carried %d"
		% [made.size(), through, bounced_off, gone, on_deck, carried])
	if through > 0:
		_fails.append("%d of %d thrown %ss went through the deck"
			% [through, made.size(), what])
	if gone > 0:
		_fails.append("%d of %d thrown %ss left the world" % [gone, made.size(), what])
	if bounced_off > 0:
		_fails.append("%d of %d thrown %ss bounced off the belt"
			% [bounced_off, made.size(), what])
	if carried < on_deck:
		_fails.append("%d %s(s) sat still on a running belt" % [on_deck - carried, what])


func _sample(made: Array [RigidBody3D], low: Array [float], crossed: Array [float]) -> void:
	for k in made.size():
		if not _live(made [k]):
			continue
		var p: Vector3 = made [k].global_position
		low [k] = minf(low [k], p.y)
		if crossed [k] < 0.0 and p.y < DECK_Y - 0.05:
			crossed [k] = absf(p.x - RUN_A.x)


func _live(b: RigidBody3D) -> bool:
	return is_instance_valid(b) and b.is_inside_tree()


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _log(msg: String) -> void:
	print("[ride] %s" % msg)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(msg)
	f.close()
