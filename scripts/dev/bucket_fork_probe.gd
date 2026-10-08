class_name DevBucketForkProbe
extends Node


const SPOT:= Vector3(13.0, 0.0, 2.0)
const SETTLE:= 40


const DRIFT_MAX_DEG:= 2.0


const SLOPE_H_MIN:= 0.6
const SLOPE_H_MAX:= 1.6

var world: Node3D
var player: Player

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	for i in SETTLE:
		await get_tree().process_frame
	GameState.grant_tool("pitchfork")

	await _put_down_with_the_fork_out(0.0)
	await _put_down_with_the_fork_out(-0.6)
	await _lift_with_the_tines(true)
	await _lift_with_the_tines(false)
	await _stand_on_the_pile(0, false, 0.0)
	await _stand_on_the_pile(300, false, 0.5)
	await _stand_on_the_pile(150, true, 1.0)
	await _stand_on_the_pile(0, true, 1.5)

	print("\n=== summary ===")
	print("  %d failure(s)" % _fails)
	print("[bucketfork] %s" % ("OK" if _fails == 0 else "FAILED"))
	get_tree().quit(0 if _fails == 0 else 1)


func _put_down_with_the_fork_out(pitch: float) -> void:
	print("\n=== put down with the fork out, looking %.0f degrees down ===" % - rad_to_deg(pitch))
	player.global_position = SPOT + Vector3(-1.2, 0.4, 0)
	player.global_rotation = Vector3.ZERO
	player.head.rotation.x = pitch
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for i in 20:
		await get_tree().physics_frame
	var props: PropManager = world.props
	var bucket:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, SPOT + Vector3(0, 0.05, 0))) as Bucket
	await _wait(1.0)
	_ok(player.carry.take(bucket), "the player picks the bucket up")
	await _wait(0.5)
	_ok(not player.pitchfork._active, "the fork is stowed while the bucket is held")
	player.carry.drop()
	await _wait(0.2)
	var tines: Vector3 = player.pitchfork.body.global_position
	print("  0.2 s after the drop: bucket y %.3f, fork body y %.3f, fork active %s"
		% [bucket.global_position.y, tines.y, str(player.pitchfork._active)])
	await _wait(2.0)
	print("  2.2 s after the drop: bucket y %.3f, %.2f m in front"
		% [bucket.global_position.y,
			(bucket.global_position - player.global_position).dot(- player.global_basis.z)])
	_ok(bucket.global_position.y < 0.15, "the bucket is on the floor, not on the tines")
	var before:= bucket.global_position


	player.global_position += Vector3(0, 0, 2.5)
	await _wait(1.5)
	var moved:= bucket.global_position.distance_to(before)
	print("  the player stepped 2.5 m aside, the bucket moved %.3f m" % moved)
	_ok(moved < 0.1, "and the bucket stays where it was put down")
	props.remove(bucket)
	player._set_tool(Player.Tool.HAND)
	player.head.rotation.x = 0.0


func _lift_with_the_tines(control: bool) -> void:
	print("\n=== the tines pushed under a bucket stood on the pile%s ==="
		% (" (the control: old masks)" if control else ""))


	var bearing:= 0.5
	var spot:= _slope_spot(bearing)
	if spot.is_empty():
		_ok(false, "there is a slope to stand the bucket on")
		return
	var at: Vector3 = spot ["at"]
	var dir:= Vector3(cos(bearing), 0.0, sin(bearing))
	player.global_position = at + dir * 1.6 + Vector3(0, 0.3, 0)
	player.global_rotation = Vector3(0.0, PI * 0.5 - bearing, 0.0)
	player.head.rotation.x = 0.0
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	var props: PropManager = world.props
	var bucket:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, at + Vector3(0, 0.08, 0))) as Bucket
	var fork_mask: int = player.pitchfork.body.collision_mask
	if control:
		bucket.collision_mask |= Cfg.L_TOOL
		player.pitchfork.body.collision_mask |= Cfg.L_PROP
	await _wait(1.0)
	var stood:= bucket.global_position


	var tip:= Vector3.ZERO
	for i in 90:
		player.head.rotation.x -= 0.015
		await get_tree().physics_frame
		tip = player.pitchfork.body.global_transform * Vector3(0.0, 0.0, Pitchfork.FORK_HEAD_Z - Pitchfork.TINE_LEN * 0.5)
		if tip.y < stood.y - 0.06:
			break
	await _wait(0.3)
	print("  bucket stood at y %.3f, tine tips at y %.3f, %.2f m short of it"
		% [stood.y, tip.y, (bucket.global_position - tip).dot(- dir)])


	for i in 40:
		player.global_position -= dir * 0.02
		if control:
			bucket.unplant()
		await get_tree().physics_frame
	print("  walked in: bucket at y %.3f (%+.3f), up %.3f"
		% [bucket.global_position.y, bucket.global_position.y - stood.y,
			bucket.global_basis.y.normalized().dot(Vector3.UP)])

	player.head.rotation.x = 0.0
	await _hold_open(bucket, control, 1.5)
	print("  fork raised: bucket at y %.3f (%+.3f)"
		% [bucket.global_position.y, bucket.global_position.y - stood.y])
	var before:= bucket.global_position
	player.global_position += Vector3(- dir.z, 0.0, dir.x) * 2.5
	await _hold_open(bucket, control, 1.5)
	var moved:= bucket.global_position.distance_to(before)
	print("  the player stepped 2.5 m aside, the bucket moved %.3f m, y %.3f"
		% [moved, bucket.global_position.y])
	var lifted:= bucket.global_position.y > stood.y + 0.2 or moved > 0.5
	if control:
		_ok(lifted, "the control: with the old masks the fork does carry the bucket off")
	else:
		_ok(bucket.global_position.y < stood.y + 0.2, "the bucket was not lifted off the pile")
		_ok(moved < 0.1, "and does not follow the fork about")
	player.pitchfork.body.collision_mask = fork_mask
	props.remove(bucket)
	player._set_tool(Player.Tool.HAND)
	player.head.rotation.x = 0.0


func _hold_open(bucket: Bucket, open: bool, seconds: float) -> void:
	var t:= 0.0
	while t < seconds:
		if open:
			bucket.unplant()
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _slope_spot(bearing: float) -> Dictionary:
	var field: HayField = world.field
	if field == null:
		return { }
	var at:= Vector3.ZERO
	var found:= false
	var flattest:= 90.0
	var dir:= Vector3(cos(bearing), 0.0, sin(bearing))
	var r:= 0.5
	while r < Cfg.PILE_RADIUS * 1.5:
		var p:= dir * r
		var h:= field.height_at(p.x, p.z)
		if h >= SLOPE_H_MIN and h <= SLOPE_H_MAX:
			var nn:= field.normal_at(p.x, p.z)
			var deg:= rad_to_deg(acos(clampf(nn.dot(Vector3.UP), -1.0, 1.0)))
			if deg < flattest:
				flattest = deg
				at = Vector3(p.x, h, p.z)
				found = true
		r += 0.25
	if not found:
		return { }
	return { "at": at, "deg": flattest }


func _stand_on_the_pile(straw: int, rain: bool, bearing: float) -> void:
	print("\n=== stood on the pile at bearing %.0f, %d loose strands round it%s ==="
		% [rad_to_deg(bearing), straw, ", straw raining in" if rain else ""])


	var spot:= _slope_spot(bearing)
	if spot.is_empty():
		_ok(false, "there is a stretch of slope between %.1f and %.1f m high"
			% [SLOPE_H_MIN, SLOPE_H_MAX])
		return
	var at: Vector3 = spot ["at"]
	print("  slope at (%.2f, %.2f): surface %.2f m high, %.1f degrees off level"
		% [at.x, at.z, at.y, float(spot ["deg"])])
	player.global_position = at + Vector3(2.0, 0.6, 2.0)
	var props: PropManager = world.props
	var bucket:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, at + Vector3(0, 0.08, 0))) as Bucket
	await _wait(1.0)
	if straw > 0:
		var live: LiveStrandManager = world.live
		var rng:= RandomNumberGenerator.new()
		rng.seed = 4242
		for i in straw:
			var a:= rng.randf() * TAU
			var d:= rng.randf_range(0.15, 0.45)
			var p:= bucket.global_position + Vector3(cos(a) * d, 0.6 + rng.randf() * 0.4, sin(a) * d)
			live.spawn(p, StrandFactory.random_strand_basis(rng), Vector3.ZERO,
				StrandFactory.random_tint(rng))

		await _wait(1.0)
	var start_yaw:= _yaw(bucket)
	var start_pos:= bucket.global_position
	var worst_spin:= 0.0
	var t:= 0.0
	var next_report:= 2.0
	var rain_rng:= RandomNumberGenerator.new()
	rain_rng.seed = 777
	var live_rain: LiveStrandManager = world.live
	while t < 10.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if rain and live_rain != null and int(t * 60.0) % 3 == 0:
			var a:= rain_rng.randf() * TAU
			var d:= rain_rng.randf_range(0.0, Bucket.R_RIM * 1.1)
			live_rain.spawn(bucket.global_position + Vector3(cos(a) * d, 1.2, sin(a) * d),
				StrandFactory.random_strand_basis(rain_rng), Vector3.ZERO,
				StrandFactory.random_tint(rain_rng))
		worst_spin = maxf(worst_spin, absf(bucket.angular_velocity.y))
		if t >= next_report:
			print("  %4.1f s  heading %+6.2f deg  spin %+.4f rad/s  moved %.3f m  %s"
				% [t, rad_to_deg(angle_difference(start_yaw, _yaw(bucket))),
					bucket.angular_velocity.y,
					bucket.global_position.distance_to(start_pos),
					"asleep" if bucket.sleeping else "awake"])
			next_report += 2.0
	var drift:= absf(rad_to_deg(angle_difference(start_yaw, _yaw(bucket))))
	print("  turned %.2f degrees in ten seconds, fastest spin %.4f rad/s" % [drift, worst_spin])
	_ok(drift < DRIFT_MAX_DEG, "a bucket on the slope holds its heading")
	_ok(bucket.global_basis.y.normalized().dot(Vector3.UP) > 0.98, "and stays upright")
	props.remove(bucket)


static func _yaw(b: Node3D) -> float:
	var f:= b.global_basis.x
	return atan2(f.z, f.x)


func _wait(seconds: float) -> void:
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
