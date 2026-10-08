class_name DevCrouchProbe
extends Node


const START:= Vector3(13.2, 0.5, 5.6)
const LEASH:= 3.0


const SWAY_CEILING:= 0.99
const SWAY_VISIBLE:= 0.9995


const LOG:= "res://crouch_probe.log"


func _log(msg: String) -> void:
	print("[crouch] %s" % msg)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(msg)
	f.close()

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()


var _worst_upright:= 1.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	_log("start")
	await _settle(10)

	_log("pose")
	await _check_pose()
	_log("headroom")
	await _check_headroom()
	_log("speed")
	await _check_speed()
	_log("spill")
	await _check_spill()
	_log("bucket")
	await _check_bucket()
	_log("done")

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check_pose() -> void:
	_reset()
	await _settle(6)
	_near("standing eye", player.head.position.y, Player.EYE_HEIGHT, 0.02)
	_near("standing capsule", _capsule().height, Player.STAND_HEIGHT, 0.02)

	Input.action_press("crouch")
	await _settle(40)
	_near("crouched blend", player.crouch_amount(), 1.0, 0.02)
	_near("crouched eye", player.head.position.y, Cfg.CROUCH_EYE_HEIGHT, 0.02)
	_near("crouched capsule", _capsule().height, Cfg.CROUCH_HEIGHT, 0.02)
	_near("capsule centred on its own height",
		_shape().position.y, _capsule().height * 0.5, 0.001)

	Input.action_release("crouch")
	await _settle(40)
	_near("stood back up", player.crouch_amount(), 0.0, 0.02)


func _check_headroom() -> void:
	_reset()
	Input.action_press("crouch")
	await _settle(40)

	var lid:= StaticBody3D.new()
	lid.collision_layer = Cfg.L_BUILD
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(3.0, 0.2, 3.0)
	cs.shape = box
	lid.add_child(cs)
	world.add_child(lid)
	lid.global_position = player.global_position + Vector3.UP * (Cfg.CROUCH_HEIGHT + 0.25)


	await _settle(4)

	Input.action_release("crouch")
	await _settle(40)
	if player.crouch_amount() < 0.9:
		_fails.append("stood up into a ceiling (crouch fell to %.2f)"
			% player.crouch_amount())
	lid.queue_free()
	await _settle(40)
	_near("stood up once the ceiling was gone", player.crouch_amount(), 0.0, 0.02)


func _check_speed() -> void:
	_reset()
	var walk:= await _peak_speed(30, false, false)
	var sprint:= await _peak_speed(30, true, false)
	var crouched:= await _peak_speed(240, false, true)
	var both:= await _peak_speed(240, true, true)
	print("[crouch] DEBUG pos=%.3v on_wall=%s" % [
		player.global_position, player.is_on_wall()])
	_log("speeds  walk=%.2f sprint=%.2f crouch=%.2f crouch+sprint=%.2f"
		% [walk, sprint, crouched, both])
	if sprint <= walk:
		_fails.append("sprint (%.2f) is not faster than walking (%.2f)" % [sprint, walk])
	_near("crouched speed", crouched, Cfg.CROUCH_SPEED, 0.35)
	_near("crouch beats sprint", both, Cfg.CROUCH_SPEED, 0.35)


func _check_spill() -> void:
	_reset()
	await _settle(6)
	var barrow:= world.props.spawn_near("wheelbarrow", player, 1.2) as HayContainer
	if barrow == null:
		_fails.append("could not spawn a wheelbarrow")
		return


	await _settle(45)


	var to:= (barrow.global_position + Vector3.UP * 0.45
		- player.eye_position()).normalized()
	player.head.rotation.x = asin(clampf(to.y, -1.0, 1.0))
	await _settle(2)
	if not player.carry.try_pick():
		var from:= player.eye_position()
		var q:= PhysicsRayQueryParameters3D.create(from,
			from + player.look_direction() * Cfg.CARRY_REACH)
		q.collision_mask = Cfg.L_PROP
		var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
		_fails.append("could not take hold of the wheelbarrow (player %s, barrow %s, ray hit %s)"
			% [player.global_position, barrow.global_position,
				"nothing" if hit.is_empty() else str(hit ["collider"])])
		return
	player.head.rotation.x = 0.0

	var sprint_lost:= await _haul(barrow, true, false)
	var sprint_tilt:= _worst_upright
	var crouch_lost:= await _haul(barrow, true, true)
	var crouch_tilt:= _worst_upright
	var walk_lost:= await _haul(barrow, false, false)
	var walk_tilt:= _worst_upright
	_log("barrow  tilt sprint=%.3f crouch=%.3f walk=%.3f against tip %.2f, lost %d/%d/%d"
		% [sprint_tilt, crouch_tilt, walk_tilt, barrow.tip_start(),
			sprint_lost, crouch_lost, walk_lost])


	if sprint_tilt < SWAY_CEILING:
		_fails.append("sprinting rocked the barrow to %.4f upright, under %.2f. JOSTLE_AMPLITUDE is back to throwing it about"
			% [sprint_tilt, SWAY_CEILING])
	if sprint_tilt > SWAY_VISIBLE:
		_fails.append("sprinting rocked the barrow only to %.4f upright. The sway is gone and the load reads as welded on"
			% sprint_tilt)
	if crouch_tilt <= barrow.tip_start():
		_fails.append("crouching rocked the barrow to %.3f upright, past its %.2f. JOSTLE_CROUCH_FACTOR is too high"
			% [crouch_tilt, barrow.tip_start()])
	if walk_tilt <= barrow.tip_start():
		_fails.append("walking rocked the barrow to %.3f upright, past its %.2f. Ordinary hauling must stay inside it"
			% [walk_tilt, barrow.tip_start()])
	if sprint_lost != 0 or crouch_lost != 0 or walk_lost != 0:
		_fails.append("hauling spilled %d / %d / %d strands. A held container pours only while its carrier is asking"
			% [sprint_lost, crouch_lost, walk_lost])
	player.carry.drop()
	await _settle(20)


func _check_bucket() -> void:
	_reset()
	await _settle(6)
	var bucket:= world.props.spawn_near("bucket", player, 1.0) as HayContainer
	if bucket == null:
		_fails.append("could not spawn a bucket")
		return
	await _settle(45)
	var to:= (bucket.global_position + Vector3.UP * 0.1
		- player.eye_position()).normalized()
	player.head.rotation.x = asin(clampf(to.y, -1.0, 1.0))
	await _settle(2)
	if not player.carry.try_pick():
		_fails.append("could not take hold of the bucket")
		return
	player.head.rotation.x = 0.0

	var run_lost:= await _haul(bucket, true, false)
	var run_tilt:= _worst_upright
	var jump_lost:= await _haul_jumping(bucket)
	var jump_tilt:= _worst_upright
	var crouch_lost:= await _haul(bucket, false, true)
	var crouch_tilt:= _worst_upright
	_log("bucket  tilt sprint=%.3f jumps=%.3f crouch=%.3f against tip %.2f, lost %d/%d/%d"
		% [run_tilt, jump_tilt, crouch_tilt, bucket.tip_start(),
			run_lost, jump_lost, crouch_lost])


	if run_tilt <= bucket.tip_start():
		_fails.append("sprinting rocked the BUCKET to %.3f upright, past its %.2f"
			% [run_tilt, bucket.tip_start()])
	if jump_tilt <= bucket.tip_start():
		_fails.append("landing rocked the bucket to %.3f upright, past its %.2f. JOSTLE_LAND_KICK is back to throwing it about"
			% [jump_tilt, bucket.tip_start()])
	if crouch_tilt <= bucket.tip_start():
		_fails.append("crouching rocked the bucket to %.3f upright, past its %.2f"
			% [crouch_tilt, bucket.tip_start()])
	if run_lost != 0 or jump_lost != 0 or crouch_lost != 0:
		_fails.append("carrying a bucket spilled %d / %d / %d strands. A held container pours only while its carrier is asking"
			% [run_lost, jump_lost, crouch_lost])
	player.carry.drop()
	await _settle(20)


func _haul_jumping(item: HayContainer) -> int:
	_reset()
	item.stored = item.capacity()
	item._refresh_fill()
	_hold(true, false)
	await _settle(45)
	var before:= item.stored
	_worst_upright = 1.0
	for i in 6:
		Input.action_press("jump")
		await _settle(2)
		Input.action_release("jump")
		for j in 28:
			await get_tree().physics_frame
			_leash()
			_worst_upright = minf(_worst_upright,
				item.global_transform.basis.y.dot(Vector3.UP))
	_release()
	await _settle(20)
	return before - item.stored


func _haul(barrow: HayContainer, sprint: bool, crouch: bool) -> int:
	_reset()
	barrow.stored = barrow.capacity()
	barrow._refresh_fill()


	_hold(sprint, crouch)
	await _settle(45)
	var before:= barrow.stored


	_worst_upright = 1.0
	for i in 120:
		await get_tree().physics_frame
		_leash()
		_worst_upright = minf(_worst_upright,
			barrow.global_transform.basis.y.dot(Vector3.UP))
	_release()
	await _settle(20)
	return before - barrow.stored


func _peak_speed(warmup: int, sprint: bool, crouch: bool) -> float:
	_reset()
	_hold(sprint, crouch)
	await _settle(warmup)
	var peak:= 0.0
	for i in 20:
		await get_tree().physics_frame
		_leash()
		peak = maxf(peak, Vector2(player.velocity.x, player.velocity.z).length())
	_release()
	await _settle(10)
	return peak


func _hold(sprint: bool, crouch: bool) -> void:
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	if crouch:
		Input.action_press("crouch")


func _release() -> void:
	for a in ["move_forward", "sprint", "crouch"]:
		Input.action_release(a)


func _reset() -> void:
	_release()
	player.global_position = START
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _leash() -> void:
	var here:= player.global_position
	if Vector2(here.x - START.x, here.z - START.z).length() > LEASH:
		player.global_position = Vector3(START.x, here.y, START.z)


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame
		_leash()


func _shape() -> CollisionShape3D:
	return player.get_node("Collider") as CollisionShape3D


func _capsule() -> CapsuleShape3D:
	return _shape().shape as CapsuleShape3D


func _near(what: String, got: float, want: float, tol: float) -> void:
	if absf(got - want) > tol:
		_fails.append("%s: got %.3f, wanted %.3f" % [what, got, want])
