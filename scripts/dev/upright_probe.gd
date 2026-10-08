class_name DevUprightProbe
extends Node


const SPOT:= Vector3(13.0, 0.0, 2.0)
const SETTLE:= 40

const UP_MIN:= 0.98


const HIT_SPEED:= 7.0


const STUCK_MAX:= 0.02

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
	player.global_position = SPOT + Vector3(-3.0, 0.4, 0)
	for i in 20:
		await get_tree().physics_frame

	print("\n=== the control: unlocked, a bale knocks it over ===")
	var loose:= await _stand_bucket(SPOT)
	loose.tumble()
	await _hit(loose, "hay_bale", 0.3)
	await _wait(2.0)
	print("  up after the hit %.3f" % _up(loose))
	_ok(_up(loose) < UP_MIN, "a bucket with its lock lifted goes over")
	_free(loose)

	print("\n=== locked, nothing but a throw moves it ===")
	var bucket:= await _stand_bucket(SPOT)
	_ok(bucket.axis_lock_angular_x and bucket.axis_lock_angular_z,
		"a fresh bucket is locked on both tipping axes")
	_ok(bucket.axis_lock_linear_x and bucket.axis_lock_linear_z,
		"and pinned on both horizontal ones once it has settled")
	var stood:= bucket.global_position
	await _hit(bucket, "hay_bale", 0.3)
	await _wait(2.0)
	print("  up after the bale %.3f, moved %.3f m"
		% [_up(bucket), bucket.global_position.distance_to(stood)])
	_ok(_up(bucket) > UP_MIN, "a bale at %.0f m/s leaves it standing" % HIT_SPEED)
	_ok(bucket.global_position.distance_to(stood) < STUCK_MAX,
		"and leaves it where it stood")
	await _hit(bucket, "hay_wad", 0.12)
	await _wait(2.0)
	print("  up after the wad %.3f, moved %.3f m"
		% [_up(bucket), bucket.global_position.distance_to(stood)])
	_ok(_up(bucket) > UP_MIN, "and so does a wad low on the wall")
	_ok(bucket.global_position.distance_to(stood) < STUCK_MAX,
		"and the wad does not shove it either")

	print("\n=== tipped in the hands, set down with Q ===")
	player.global_position = bucket.global_position + Vector3(-1.2, 0.4, 0)
	await _wait(0.2)
	_ok(player.carry.take(bucket), "the player picks it up")
	await _wait(0.2)


	_ok(not bucket.axis_lock_angular_x and not bucket.axis_lock_angular_z,
		"held, it is unlocked, or the hands could never tip it")


	for i in 40:
		player.carry.rotate_input(Vector2(20.0, -40.0))
	bucket.global_transform = player.carry.call("_pose")
	print("  up in the hands %.3f" % _up(bucket))
	_ok(_up(bucket) < UP_MIN, "it is tipped in the hands before the drop")
	player.carry.drop()
	await _wait(2.0)
	print("  up on the floor %.3f" % _up(bucket))
	_ok(_up(bucket) > 0.999, "it lands level, not on one edge")

	print("\n=== thrown with F ===")
	player.global_position = bucket.global_position + Vector3(-1.2, 0.4, 0)
	await _wait(0.2)
	player.carry.take(bucket)
	await _wait(0.1)
	player.carry.throw()
	_ok(bucket.is_tumbling(), "a throw lifts the lock")
	var lowest:= 1.0
	var t:= 0.0
	while t < 6.0 and bucket.is_tumbling():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		lowest = minf(lowest, _up(bucket))
	await _wait(0.3)
	print("  lowest up in flight %.3f, settled after %.2f s, up %.3f"
		% [lowest, t, _up(bucket)])
	_ok(lowest < UP_MIN, "and the bucket actually turns over in flight")
	_ok(not bucket.is_tumbling(), "it settles within six seconds")
	_ok(bucket.axis_lock_angular_x and bucket.axis_lock_angular_z,
		"and the lock is back once it lies still")


	var lay:= rad_to_deg(acos(clampf(_up(bucket), -1.0, 1.0)))
	await _hit(bucket, "hay_bale", 0.15)
	await _wait(2.0)
	var now:= rad_to_deg(acos(clampf(_up(bucket), -1.0, 1.0)))
	print("  lying %.1f deg off vertical, %.1f after a bale" % [lay, now])
	_ok(absf(now - lay) < 3.0, "a bale does not roll it from where the throw left it")
	_free(bucket)

	print("\n=== a barrow, hit and loaded ===")
	var barrow:= props_spawn_barrow(SPOT)
	await _wait(1.5)
	_ok(barrow.axis_lock_angular_x and barrow.axis_lock_angular_z,
		"a fresh barrow is locked on both tipping axes")
	_ok(barrow.axis_lock_linear_x and barrow.axis_lock_linear_z,
		"and pinned on both horizontal ones once it has settled")
	var parked:= barrow.global_position
	await _hit(barrow, "hay_bale", 0.45)
	await _wait(2.0)
	print("  up after a bale on the tray %.3f, moved %.3f m"
		% [_up(barrow), barrow.global_position.distance_to(parked)])
	_ok(_up(barrow) > UP_MIN, "a bale into the side of the tray leaves it standing")
	_ok(barrow.global_position.distance_to(parked) < STUCK_MAX,
		"and leaves it parked where it was")


	for i in 6:
		var wad:= (world.props as PropManager).spawn("hay_wad", Transform3D(Basis.IDENTITY,
			barrow.global_position + Vector3(0.28, 1.2 + 0.25 * i, -0.6)))
		if wad != null:
			wad.linear_velocity = Vector3(1.5, -3.0, 0)
	await _wait(3.0)
	print("  up after six wads on the rim %.3f, moved %.3f m"
		% [_up(barrow), barrow.global_position.distance_to(parked)])
	_ok(_up(barrow) > UP_MIN, "wads landing on one corner leave it standing")
	_ok(barrow.global_position.distance_to(parked) < STUCK_MAX,
		"and six of them do not walk it across the yard")

	player.global_position = barrow.global_position + Vector3(0, 0.4, 1.4)
	await _wait(0.2)
	_ok(player.carry.take(barrow), "the player takes the handles")
	await _wait(0.3)
	_ok(not barrow.axis_lock_angular_x and not barrow.axis_lock_angular_z,
		"pushed, it is unlocked, or it could never be tipped")
	player.carry.drop()
	await _wait(2.0)
	print("  up after setting it down %.3f" % _up(barrow))
	_ok(_up(barrow) > 0.999, "it is set down level on its wheel and legs")

	print("\n=== a tool in the hands passes through a barrow ===")


	for tool_body: CollisionObject3D in [
			player.shovel.body if player.shovel != null else null,
			player.pitchfork.body if player.pitchfork != null else null]:
		if tool_body == null:
			continue
		var pairs:= bool(tool_body.collision_mask & barrow.collision_layer) or bool(barrow.collision_mask & tool_body.collision_layer)
		_ok(not pairs, "%s does not collide with the barrow" % tool_body.name)


	var moved:= await _sweep_through(barrow, "hay_wad", true)
	print("  a held wad swept through an unpinned barrow moved it %.3f m" % moved)
	_ok(moved > 0.02, "a held wad swept through the tray shoves a loose barrow")
	barrow.global_position = SPOT
	await _wait(1.0)


	var facing:= barrow.global_basis.z
	moved = await _sweep_through(barrow, "hay_wad")
	var turned:= rad_to_deg(facing.angle_to(barrow.global_basis.z))
	print("  the same wad through a settled barrow moved it %.3f m, turned it %.1f deg"
		% [moved, turned])
	_ok(moved < 0.005, "a wad dragged through a settled barrow does not move it")


	_ok(turned < 3.0, "and does not swing it round")
	barrow.global_position = SPOT
	await _wait(1.0)
	moved = await _sweep_through(barrow, "sand_shovel", true)
	print("  the held toy spade swept through moved it %.3f m" % moved)
	_ok(moved < 0.005, "the toy spade in the hands passes through it")
	barrow.global_position = SPOT
	await _wait(1.0)

	print("\n=== nothing carried lifts it, and it still falls when its floor goes ===")


	var rose:= await _lift_from_under(barrow, true)
	print("  a held wad pushed up under an unpinned barrow raised it %.3f m" % rose)
	_ok(rose > 0.02, "a held wad pushed up under the tray lifts a loose barrow")
	barrow.global_position = SPOT
	await _wait(1.0)
	_ok(barrow.is_pinned(), "a settled barrow is pinned where it stands")
	rose = await _lift_from_under(barrow)
	print("  the same wad under a settled barrow raised it %.3f m" % rose)
	_ok(rose < 0.005, "a held wad pushed up under a settled barrow does not lift it")
	_free(barrow)
	await _deck_taken_away()
	await _prop_taken_away()
	await _pile_dug_away()

	print("\n=== summary ===")
	print("  %d failure(s)" % _fails)
	print("[upright] %s" % ("OK" if _fails == 0 else "FAILED"))
	get_tree().quit(0 if _fails == 0 else 1)


func _lift_from_under(target: Wheelbarrow, unpin:= false) -> float:
	var props: PropManager = world.props
	var base:= target.global_position
	var under:= base + Vector3(0, Wheelbarrow.FLOOR_Y - 0.35, -0.25)
	var item:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, under)) as Carryable
	if item == null:
		_ok(false, "a hay_wad could be spawned")
		return 0.0
	item.pick_up()
	var most:= 0.0
	for i in 41:
		item.global_transform = Transform3D(Basis.IDENTITY,
			under + Vector3(0, 0.6 * float(i) / 40.0, 0))
		if unpin:
			target.unplant()
		await get_tree().physics_frame
		most = maxf(most, target.global_position.y - base.y)
	item.release(Vector3.ZERO)
	props.remove(item)
	await _wait(0.5)
	return most


func _deck_taken_away() -> void:
	var at:= SPOT + Vector3(0, 0, -5.0)
	var deck: Platform = world.builds.add_platform(at + Vector3(0, 1.0, 0), Vector2(3.0, 3.0))
	await _wait(0.5)
	var barrow:= props_spawn_barrow(at + Vector3(0, 1.0, 0))
	await _wait(1.5)
	var up_there:= barrow.global_position.y
	_ok(up_there > 0.8 and barrow.is_pinned(),
		"a barrow set on a deck plants up there (y %.2f)" % up_there)
	world.builds.demolish(deck)
	await _wait(2.0)
	print("  deck dismantled: barrow from y %.2f to %.2f" % [up_there, barrow.global_position.y])
	_ok(barrow.global_position.y < 0.3, "dismantling the deck drops the barrow to the floor")
	_free(barrow)


func _prop_taken_away() -> void:
	var at:= SPOT + Vector3(0, 0, 5.0)
	var props: PropManager = world.props
	var bale:= props.spawn("hay_bale", Transform3D(Basis.IDENTITY, at + Vector3(0, 0.3, 0))) as Carryable
	await _wait(1.0)
	var top:= bale.global_position.y + 0.5
	var bucket:= await _stand_bucket(Vector3(at.x, top, at.z))
	await _wait(0.5)
	var up_there:= bucket.global_position.y
	_ok(bucket.is_pinned(), "a bucket stood on a bale plants there (y %.2f)" % up_there)
	props.remove(bale)
	await _wait(1.5)
	print("  bale removed: bucket from y %.2f to %.2f" % [up_there, bucket.global_position.y])
	_ok(bucket.global_position.y < up_there - 0.15, "removing the bale drops the bucket")
	_free(bucket)


func _pile_dug_away() -> void:
	var field: HayField = world.field

	var dir:= Vector3(-1.0, 0.0, 0.0)
	var at:= Vector3.ZERO
	var r:= 0.5
	while r < Cfg.PILE_RADIUS * 1.5:
		var p:= dir * r
		if field.height_at(p.x, p.z) <= 1.5:
			at = Vector3(p.x, 0.0, p.z) - dir * 0.8
			break
		r += 0.25
	if at == Vector3.ZERO:
		_ok(false, "there is a face on the pile to carve a shelf into")
		return
	player.global_position = at + dir * 2.4 + Vector3(0, 0.3, 0)
	var shelf:= field.height_at(at.x, at.z) - 0.2
	_flatten(field, at, 0.8, shelf)
	await _wait(1.0)
	at.y = field.height_at(at.x, at.z)
	var bucket:= await _stand_bucket(at + Vector3(0, 0.03, 0))
	await _wait(0.5)
	var up_there:= bucket.global_position.y
	print("  shelf at y %.2f, bucket stood at y %.2f" % [at.y, up_there])
	_ok(bucket.is_pinned() and absf(up_there - at.y) < 0.15,
		"a bucket stood on a shelf in the pile plants there")
	_flatten(field, at, 0.8, at.y - 0.5)
	await _wait(2.0)
	print("  dug under: bucket from y %.2f to %.2f, pile there now %.2f" % [up_there,
		bucket.global_position.y, field.height_at(at.x, at.z)])
	_ok(bucket.global_position.y < up_there - 0.3, "digging the pile out under it drops the bucket")
	_free(bucket)


func _flatten(field: HayField, centre: Vector3, half: float, level: float) -> void:
	var x:= centre.x - half
	while x <= centre.x + half:
		var z:= centre.z - half
		while z <= centre.z + half:
			var drop:= field.height_at(x, z) - level
			if drop > 0.0:
				field.carve_column(x, z, drop)
			z += Cfg.CELL * 0.5
		x += Cfg.CELL * 0.5


func _stand_bucket(at: Vector3) -> Bucket:
	var props: PropManager = world.props
	var b:= props.spawn("bucket", Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0))) as Bucket
	await _wait(1.0)
	return b


func props_spawn_barrow(at: Vector3) -> Wheelbarrow:
	var props: PropManager = world.props
	return props.spawn("wheelbarrow", Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0))) as Wheelbarrow


func _sweep_through(target: Wheelbarrow, id: String, unpin:= false) -> float:
	var props: PropManager = world.props
	var tray:= target.global_position + Vector3(0, Wheelbarrow.RIM_Y - 0.05, -0.25)
	var item:= props.spawn(id, Transform3D(Basis.IDENTITY, tray + Vector3(-1.0, 0, 0))) as Carryable
	if item == null:
		_ok(false, "%s could be spawned" % id)
		return 0.0
	item.pick_up()
	var before:= target.global_position
	var steps:= 60
	for i in steps + 1:
		var at:= tray + Vector3(lerpf(-1.0, 1.0, float(i) / float(steps)), 0, 0)
		item.global_transform = Transform3D(Basis.IDENTITY, at)
		if unpin:
			target.unplant()
		await get_tree().physics_frame
	var moved:= target.global_position.distance_to(before)
	item.release(Vector3.ZERO)
	props.remove(item)
	await _wait(0.5)
	return moved


func _hit(target: Carryable, id: String, height: float) -> void:
	var props: PropManager = world.props
	var aim:= target.global_position + Vector3(0, height, 0)
	var from:= aim + Vector3(0, 0, -1.2)
	var prop:= props.spawn(id, Transform3D(Basis.IDENTITY, from))
	if prop == null:
		_ok(false, "%s could be spawned" % id)
		return
	prop.linear_velocity = Vector3(0, 0, HIT_SPEED)
	await _wait(1.0)
	if is_instance_valid(prop):
		props.remove(prop)


func _up(b: Node3D) -> float:
	return b.global_basis.y.normalized().dot(Vector3.UP)


func _wait(seconds: float) -> void:
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _free(item: Carryable) -> void:
	var props: PropManager = world.props
	props.remove(item)
