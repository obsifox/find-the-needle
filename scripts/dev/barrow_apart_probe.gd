class_name DevBarrowApartProbe
extends Node


const SPOT:= Vector3(13.0, 0.0, 2.0)

var world: Node3D

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
	for i in 40:
		await get_tree().process_frame
	var props: PropManager = world.props
	var builds: BuildManager = world.builds
	builds.clear()

	print("\n=== exceptions ===")
	var arm_first:= builds.add_robotic_arm(SPOT + Vector3(0, 0, 4.0), 0.0, 1)
	var barrow:= props.spawn("wheelbarrow",
		Transform3D(Basis.IDENTITY, SPOT + Vector3(0, 0.05, 0))) as Wheelbarrow
	var arm_after:= builds.add_robotic_arm(SPOT + Vector3(0, 0, -4.0), 0.0, 1)
	var bucket:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, SPOT + Vector3(0, 1.2, 0.3))) as Bucket
	var bucket2:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, SPOT + Vector3(3.0, 0.05, 0))) as Bucket
	var ex:= barrow.get_collision_exceptions()
	_ok(arm_first in ex, "an arm built before the barrow is excepted")
	_ok(arm_after in ex, "an arm built after the barrow is excepted")
	_ok(bucket in ex and barrow in bucket.get_collision_exceptions(),
		"a bucket and the barrow are excepted both ways")
	_ok(not (bucket2 in bucket.get_collision_exceptions()), "two buckets still collide")

	print("\n=== a bucket dropped onto the barrow ===")
	await _wait(0.1)
	var before:= barrow.global_position
	await _wait(2.0)
	print("  bucket y %.3f, barrow moved %.3f m"
		% [bucket.global_position.y, barrow.global_position.distance_to(before)])
	_ok(bucket.global_position.y < 0.15, "the bucket falls through to the floor")
	_ok(barrow.global_position.distance_to(before) < 0.05, "the barrow does not move")
	props.remove(bucket)
	props.remove(bucket2)


	print("\n=== a held bucket swept through the barrow ===")
	var held:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, SPOT + Vector3(-1.5, 0.1, 0))) as Bucket
	await _wait(0.5)
	held.pick_up()
	before = barrow.global_position
	var top:= before.y
	for i in 120:
		var t:= float(i) / 119.0
		held.global_position = SPOT + Vector3(lerpf(-1.5, 1.5, t), 0.1, 0.0)
		await get_tree().physics_frame
		top = maxf(top, barrow.global_position.y)
	await _wait(0.5)
	print("  barrow rose %.3f m, moved %.3f m" % [top - before.y,
		barrow.global_position.distance_to(before)])
	_ok(top - before.y < 0.02 and barrow.global_position.distance_to(before) < 0.05,
		"a held bucket passes through the barrow")
	props.remove(held)


	print("\n=== a bucket in the player's hands walked into the barrow ===")
	var player: Player = world.player
	var bh:= props.spawn("bucket",
		Transform3D(Basis.IDENTITY, SPOT + Vector3(-2.5, 0.05, 0))) as Bucket
	player.global_position = SPOT + Vector3(-3.2, 0.0, 0)
	player.global_rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = -0.35
	await _wait(0.5)
	_ok(player.carry.take(bh), "the player picks the bucket up")
	await _wait(0.3)
	before = barrow.global_position
	top = before.y
	for i in 150:
		player.global_position = SPOT + Vector3(lerpf(-3.2, -0.2, float(i) / 149.0), 0.0, 0)
		await get_tree().physics_frame
		top = maxf(top, barrow.global_position.y)
	await _wait(0.5)
	print("  bucket held at %s, barrow rose %.3f m, moved %.3f m, exceptions %s"
		% [str(bh.global_position), top - before.y,
			barrow.global_position.distance_to(before),
			str(barrow in bh.get_collision_exceptions())])
	_ok(top - before.y < 0.02 and barrow.global_position.distance_to(before) < 0.05,
		"a bucket in the hands passes through the barrow")


	print("\n=== the barrow inside a held bucket's mouth, then walk away ===")
	barrow.global_transform = Transform3D(Basis.IDENTITY, bh.global_position + Vector3(-0.386, 0.146, -0.17))
	barrow.linear_velocity = Vector3.ZERO
	await _wait(0.2)
	var riding:= bh._riding.has(barrow.get_instance_id())
	before = barrow.global_position
	var from:= player.global_position
	for i in 60:
		player.global_position = from + Vector3(0, 0, 3.0 * float(i) / 59.0)
		await get_tree().physics_frame
	var followed:= Vector2(barrow.global_position.x - before.x,
		barrow.global_position.z - before.z).length()
	print("  claimed by the bucket %s, barrow followed %.3f m" % [str(riding), followed])
	_ok(not riding and followed < 0.5, "the bucket does not carry the barrow off")
	player.carry.drop()
	await _wait(0.3)
	props.remove(bh)
	player.global_position = SPOT + Vector3(-8.0, 0.0, 6.0)

	print("\n=== a wad dropped into the tray ===")
	var wad:= props.spawn("hay_wad",
		Transform3D(Basis.IDENTITY, barrow.global_position + Vector3(0, 1.0, 0.1))) as Carryable
	await _wait(2.0)
	var wy:= -1.0
	if is_instance_valid(wad) and wad.is_inside_tree():
		wy = wad.global_position.y
	print("  wad y %.3f, barrow fill %.3f" % [wy, barrow.fill_fraction()])
	_ok(wy > 0.2 or barrow.fill_fraction() > 0.0, "the wad stays in the barrow")
	props.remove(barrow)

	print("\n=== a barrow stood inside an arm's base ===")
	var at:= arm_first.global_position + Vector3(0.1, 0.05, 0.1)
	var b2:= props.spawn("wheelbarrow", Transform3D(Basis.IDENTITY, at)) as Wheelbarrow
	await _wait(0.1)
	before = b2.global_position
	await _wait(1.5)
	var moved:= Vector2(b2.global_position.x - before.x, b2.global_position.z - before.z).length()
	print("  barrow moved %.3f m sideways" % moved)
	_ok(moved < 0.05, "the arm does not push the barrow")
	_ok(arm_first in b2.get_collision_exceptions(), "and knows the arm")
	props.remove(b2)

	await _working_arm_beside_a_barrow()

	print("\n=== summary ===")
	print("  %d failure(s)" % _fails)
	print("[barrowapart] %s" % ("OK" if _fails == 0 else "FAILED"))
	get_tree().quit(0 if _fails == 0 else 1)


func _working_arm_beside_a_barrow() -> void:
	print("\n=== a barrow beside a working arm ===")
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	var field: HayField = world.field
	builds.clear()

	var base:= Vector3.ZERO
	for i in 400:
		var x:= float(i) * 0.1
		if field.height_at(x, 0.0) < 0.35:
			base = Vector3(x + 0.6, 0.0, 0.0)
			break
	print("  arm at %s, pile under the reach %.2f m" % [str(base), field.height_at(base.x - 1.0, 0.0)])
	builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2), base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	var cases:= {
		"floor, 1.1 m off": base + Vector3(0.0, 0.05, 1.1),
		"floor, 1.1 m other side": base + Vector3(0.0, 0.05, -1.1),
	}
	for p: Vector3 in [Vector3(-1.0, 0, 0.7), Vector3(-1.3, 0, -0.6), Vector3(-0.9, 0, 0.0)]:
		var at:= base + p
		at.y = field.height_at(at.x, at.z) + 0.05
		cases ["pile at %.1f,%.1f" % [p.x, p.z]] = at
	var barrows: Dictionary = { }
	for label: String in cases:
		var b:= props.spawn("wheelbarrow",
			Transform3D(Basis.IDENTITY, cases [label])) as Wheelbarrow
		b.contact_monitor = true
		b.max_contacts_reported = 16
		b.body_entered.connect(_on_touch.bind(label, arm))
		barrows [label] = b
	await _wait(1.0)
	var start: Dictionary = { }
	for label: String in barrows:
		start [label] = (barrows [label] as Wheelbarrow).global_transform
	var last: Dictionary = start.duplicate()
	for step in 80:
		await _wait(0.25)
		for label: String in barrows:
			var b:= barrows [label] as Wheelbarrow
			var t:= b.global_transform
			var d:= t.origin.distance_to((last [label] as Transform3D).origin)
			if d > 0.01:
				print("  [%s] t=%.2f moved %.3f m, arm phase %d, frozen %s, held %s" % [label,
					step * 0.25, d, arm._phase, str(b.freeze), str(b.is_held())])
			last [label] = t
	print("  arm cycles: phase now %d, stall '%s'" % [arm._phase, arm._stall])
	for label: String in barrows:
		var moved:= (barrows [label] as Wheelbarrow).global_position.distance_to(
			(start [label] as Transform3D).origin)
		print("  [%s] moved %.3f m in 20 s" % [label, moved])
		_ok(moved < 0.05, "a barrow %s stays put while the arm works" % label)


func _on_touch(o: Node, label: String, arm: RoboticArm) -> void:
	var layer:= (o as CollisionObject3D).collision_layer if o is CollisionObject3D else -1
	print("  [%s] t=%.2f touched %s (%s) layer %d, arm phase %d"
		% [label, Time.get_ticks_msec() / 1000.0, o.name, o.get_class(), layer, arm._phase])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
