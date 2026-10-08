class_name DevStackPickProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 60

const WATCH:= 60


const MAX_SPEED:= 3.0

const MAX_RISE:= 0.05

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	for i in SETTLE:
		await get_tree().physics_frame
	await _case_stack(true)
	await _case_stack(false)
	await _case_flick()
	await _case_belt()
	print("\n[stackpick] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _floor_at(at: Vector3) -> float:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit ["position"] as Vector3).y if not hit.is_empty() else 0.0


func _stand() -> Vector3:
	if player.carry.is_carrying():
		player.carry.drop()
	player.global_position = Vector3(13.2, 0.4, 5.6)
	player.rotation = Vector3.ZERO
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	var spot:= player.global_position + Vector3(0, 0, -0.9)
	spot.y = _floor_at(spot)
	return spot


func _clear(items: Array) -> void:
	var props: PropManager = world.props
	for it in items:
		if is_instance_valid(it):
			if player.carry.held() == it:
				player.carry.stow()
			props.remove(it as Carryable)
	for i in 5:
		await get_tree().physics_frame


func _case_stack(pick_bottom: bool) -> void:
	var props: PropManager = world.props
	var spot:= _stand()
	var low:= props.spawn("hay_wad", Transform3D(Basis(), spot + Vector3.UP * 0.01),
		{ "strands": 60 }) as HayWad
	for i in 5:
		await get_tree().physics_frame
	var h:= low.ride_box().size.y
	var high:= props.spawn("hay_wad", Transform3D(Basis(), spot + Vector3.UP * (h + 0.01)),
		{ "strands": 60 }) as HayWad
	for i in SETTLE:
		await get_tree().physics_frame
	var taken:= low if pick_bottom else high
	var other:= high if pick_bottom else low
	var rest:= other.global_position
	print("\n=== pick the %s of a stack of two ===" % ("bottom" if pick_bottom else "top"))
	print("  wad %.2f m tall, the other at y %.3f, asleep %s" % [h, rest.y, other.sleeping])
	if not player.carry.take(taken):
		_fail("take() refused the wad")
		await _clear([low, high])
		return
	var peak_v:= 0.0
	var peak_y:= rest.y
	for i in WATCH:
		await get_tree().physics_frame
		peak_v = maxf(peak_v, other.linear_velocity.length())
		peak_y = maxf(peak_y, other.global_position.y)
	var rise:= peak_y - rest.y
	print("  the other wad: fastest %.2f m/s, rose %.3f m, ended at y %.3f"
		% [peak_v, rise, other.global_position.y])
	if peak_v > MAX_SPEED or rise > MAX_RISE:
		_fail("picking the %s threw the other wad" % ("bottom" if pick_bottom else "top"))


	if pick_bottom and other.global_position.y > rest.y - h * 0.5:
		_fail("the top wad was left hanging where the bottom one was")
	await _clear([low, high])


func _case_belt() -> void:
	print("\n=== a wad on a belt is taken by hand, and put back ===")
	var props: PropManager = world.props
	var builds: BuildManager = world.builds
	var spot:= _stand()
	var deck_y:= _floor_at(spot) + Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR


	var conv: Conveyor = builds.add_conveyor(Vector3(spot.x - 3.0, deck_y, spot.z),
		Vector3(spot.x + 3.0, deck_y, spot.z))
	for i in SETTLE:
		await get_tree().physics_frame
	var run: BeltPath = conv
	if run == null:
		_fail("the test belt has no path")
		return
	var wad:= props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(spot.x, deck_y + 0.02, spot.z)), { "strands": 60 }) as HayWad
	var seq:= -1
	for i in 120:
		await get_tree().physics_frame
		if run.run.count() > 0:
			seq = run.run.seq_of(run.run.first())
			break
	if seq < 0:
		_fail("the belt never took the wad as a record")
		await _clear([wad])
		builds.demolish(conv)
		return

	conv.set_drive_speed(0.0)
	for i in 2:
		await get_tree().physics_frame
	var where:= BeltPath.record_where(seq)
	if where.is_empty():
		_fail("the record left the run before it could be looked at")
		builds.demolish(conv)
		return
	var at:= (where ["pose"] as Transform3D).origin
	_look_at(at)
	await get_tree().physics_frame
	var eye:= player.eye_position()
	print("  record %d at %.2f, %.2f, %.2f; the eye at %.2f, %.2f, %.2f looking %s (%.2f m)"
		% [seq, at.x, at.y, at.z, eye.x, eye.y, eye.z, str(player.look_direction()),
			eye.distance_to(at)])
	var took:= player.carry.try_pick()
	if not took:
		_fail("the hand did not take the record off the belt")
	var held:= player.carry.held() as HayWad
	if held == null:
		_fail("nothing is in the hands after the pick")
	else:
		print("  in the hands: %s with %d strands, %d records left on the run"
			% [held.name, held.strands, run.run.count()])
		if held.strands != 60:
			_fail("the wad in the hands holds %d strands, not the record's 60" % held.strands)
		if run.run.count() != 0:
			_fail("the record is still on the run after the pick")

	if held != null:
		var hands:= held.global_position
		player.carry.drop()
		await get_tree().physics_frame
		print("  let go at %.2f, %.2f, %.2f: %d records on the run, %d wad bodies, carrying %s"
			% [hands.x, hands.y, hands.z, run.run.count(), _wad_bodies(),
				str(player.carry.is_carrying())])
		if run.run.count() != 1:
			_fail("letting go over the belt did not board a record (the run holds %d)"
				% run.run.count())
		if player.carry.is_carrying():
			_fail("the hands are still carrying after letting go")
		if _wad_bodies() != 0:
			_fail("%d wad bodies were left lying after letting go over the belt"
				% _wad_bodies())
	while run.run.count() > 0:
		run.take_record_at(run.run.first())
	if is_instance_valid(wad):
		await _clear([wad])
	builds.demolish(conv)
	for i in 5:
		await get_tree().physics_frame


func _look_at(target: Vector3) -> void:
	var d:= target - player.eye_position()
	player.rotation.y = atan2(- d.x, - d.z)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _wad_bodies() -> int:
	var n:= 0
	for item in world.props.items:
		if item is HayWad:
			n += 1
	return n


func _case_flick() -> void:
	var props: PropManager = world.props
	var spot:= _stand()
	var held:= props.spawn("hay_wad", Transform3D(Basis(), spot + Vector3.UP * 0.01),
		{ "strands": 60 }) as HayWad
	for i in 5:
		await get_tree().physics_frame
	player.carry.take(held)
	for i in 10:
		await get_tree().physics_frame


	var pivot:= player.eye_position()
	var mid:= pivot + Basis(Vector3.UP, PI * 0.25) * (held.global_position - pivot)
	var loose:= props.spawn("hay_wad", Transform3D(Basis(), mid), { "strands": 60 }) as HayWad
	loose.gravity_scale = 0.0
	for i in 5:
		await get_tree().physics_frame
	print("\n=== swing a held wad through a loose one ===")
	var peak_v:= 0.0
	for i in 6:
		player.rotate_y(PI * 0.5 / 6.0)
		await get_tree().physics_frame
		peak_v = maxf(peak_v, loose.linear_velocity.length())
	for i in WATCH:
		await get_tree().physics_frame
		peak_v = maxf(peak_v, loose.linear_velocity.length())
	print("  the loose wad: fastest %.2f m/s (a tenth of a second quarter turn)" % peak_v)
	await _clear([held, loose])
