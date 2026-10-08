class_name DevBeltProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 30
const CARRY_SECONDS:= 3.0
const DROPPED:= 24

var _rng:= RandomNumberGenerator.new()


func run() -> void:
	_rng.seed = 20250823
	for i in 40:
		await get_tree().process_frame


	var a:= Vector3(13.0, 0.75, -5.0)
	var b:= Vector3(13.0, 0.75, 5.0)
	player.global_position = Vector3(11.0, 0.4, 0.0)
	player.equip_build("belt")
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	GameState.add_money(1000.0)

	print("\n=== placement rules ===")
	_rule("level 10 m run", a, b, true)
	_rule("too short", a, a + Vector3(0, 0, 0.3), false)
	_rule("too long", a, a + Vector3(0, 0, Cfg.BELT_MAX_LENGTH + 2.0), false)
	_rule("too steep", a, a + Vector3(0, 6.0, 3.0), false)
	_rule("through the floor", Vector3(13.0, -0.4, -5.0), Vector3(13.0, -0.4, 5.0), false)


	var wall: float = world.warehouse.inner
	_rule("through the wall", Vector3(wall - 4.0, 1.2, 0.0),
		Vector3(wall + 2.0, 1.2, 0.0), false)


	_rule("resting on the floor",
		Vector3(13.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, -5.0),
		Vector3(13.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 5.0), true)

	var purse:= GameState.money
	GameState.add_money(- purse)
	_rule("cannot afford it", a, b, false)
	GameState.add_money(purse)

	print("\n=== ledger ===")
	var start_money:= GameState.money
	var cost:= Conveyor.cost_for(a, b)
	var belt: Conveyor = world.builds.add_conveyor(a, b)
	GameState.spend_money(cost)
	print("  built %.1f m for $%.2f, balance $%.2f -> $%.2f"
		% [a.distance_to(b), cost, start_money, GameState.money])
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	print("\n=== transport ===")
	var dropped: Array [RigidBody3D] = []
	for i in DROPPED:
		var pos:= Vector3(
			13.0 + _rng.randf_range(-0.25, 0.25),
			0.95,
			-4.4 + _rng.randf_range(-0.4, 0.4))
		var body: RigidBody3D = world.live.spawn(pos, StrandFactory.random_strand_basis(_rng),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			dropped.append(body)


	for i in 40:
		await get_tree().physics_frame

	var travel: Vector3 = belt.forward
	var start_z: Array [float] = []
	for body in dropped:
		start_z.append(body.global_position.dot(travel))

	var ticks:= int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame

	var moved:= 0
	var total:= 0.0
	var on_deck:= 0
	for i in dropped.size():
		var body:= dropped [i]
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		on_deck += 1
		var d: float = body.global_position.dot(travel) - start_z [i]
		total += d
		if d > 0.5:
			moved += 1
	var mean: float = total / maxf(float(on_deck), 1.0)
	print("  dropped %d, still present %d" % [dropped.size(), on_deck])
	print("  carried >0.5 m: %d" % moved)


	print("  mean travel    : %.2f m over %.1f s  (%.2f m/s, belt runs %.2f)"
		% [mean, CARRY_SECONDS, mean / CARRY_SECONDS, Tech.belt_speed()])

	print("\n=== corner ===")


	var c:= Vector3(8.0, 0.75, 5.0)
	var turned: Conveyor = world.builds.add_conveyor(b, c)
	print("  runs %d, corners fitted %d, children %d"
		% [world.builds.conveyors.size(), world.builds.corners.size(),
			world.builds.get_child_count()])
	for corner in world.builds.corners:
		print("    corner apex %.2v" % corner.apex)
	print("  trim on run 1 end: %.2f m   on run 2 start: %.2f m"
		% [belt.trim_end, turned.trim_start])
	var carried: Array [RigidBody3D] = []
	for i in DROPPED:
		var pos:= Vector3(
			13.0 + _rng.randf_range(-0.25, 0.25),
			0.95,
			-4.4 + _rng.randf_range(-0.4, 0.4))
		var body: RigidBody3D = world.live.spawn(pos, StrandFactory.random_strand_basis(_rng),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			carried.append(body)


	var window:= 22.4 / maxf(Cfg.BELT_SPEED, 0.01)
	var ticks_round:= int(window / maxf(get_physics_process_delta_time(), 1e-06))


	var crossed: Dictionary = { }
	var sample:= int(ticks_round / 7)
	for i in ticks_round:
		await get_tree().physics_frame
		var by_path: Dictionary = { }
		var loose:= 0
		for body in carried:
			if not is_instance_valid(body) or not body.is_inside_tree():
				continue
			if not BeltPath.is_rider(body):
				loose += 1
				continue
			var owner_node: Node = body.get_meta(LiveStrandManager.META_RIDER)
			if owner_node == turned:
				crossed [body.get_instance_id()] = true
			var key: String = owner_node.name if owner_node != null else "?"
			by_path [key] = int(by_path.get(key, 0)) + 1
		if i % sample == sample - 1:
			print("    t=%4.1fs  loose %2d  aboard %s" % [float(i) / 60.0, loose,
				str(by_path)])

	var lost:= 0
	for body in carried:
		if crossed.has(body.get_instance_id()):
			continue


		if is_instance_valid(body) and body.is_inside_tree() and BeltPath.is_rider(body):
			continue
		lost += 1
	print("  of %d dropped: %d crossed the joint, %d FELL THROUGH IT"
		% [carried.size(), crossed.size(), lost])

	print("\n=== the motor upgrade reaches what is built ===")


	var was_speed:= belt.drive_speed
	var corner_was: float = world.builds.corners [0].drive_speed if world.builds.corners.size() > 0 else -1.0
	Tech.grant("belt_speed", 4)
	var want_speed:= Tech.belt_speed()
	var corner_now: float = world.builds.corners [0].drive_speed if world.builds.corners.size() > 0 else -1.0
	print("  run    %.2f -> %.2f m/s  (tech says %.2f)"
		% [was_speed, belt.drive_speed, want_speed])
	print("  bend   %.2f -> %.2f m/s" % [corner_was, corner_now])
	print("  the laid run followed it : %s"
		% str(is_equal_approx(belt.drive_speed, want_speed)))
	print("  the bend followed it too : %s"
		% str(is_equal_approx(corner_now, want_speed)))
	Tech.grant("belt_speed", 0)

	print("\n=== save round trip ===")
	var packed: Array = world.builds.to_array()
	world.builds.from_array(packed)


	var restored: Conveyor = null
	for cv in world.builds.conveyors:
		if cv.a.is_equal_approx(a) and cv.b.is_equal_approx(b):
			restored = cv
			break
	print("  %d building(s) serialised; test run found again after reload: %s"
		% [packed.size(), restored != null])

	print("\n=== demolish ===")
	if restored != null:
		var before:= GameState.money
		var was: int = world.builds.corners.size()
		var refund: float = world.builds.demolish(restored)
		GameState.add_money(refund)

		print("  refund $%.2f, balance $%.2f -> $%.2f, corners %d -> %d"
			% [refund, before, GameState.money, was, world.builds.corners.size()])

	get_tree().quit()


func _rule(label: String, from: Vector3, to: Vector3, want_ok: bool) -> void:
	var r: Dictionary = player.build._evaluate(from, to, true)
	var mark:= "ok  " if r ["ok"] == want_ok else "FAIL"
	print("  %s  %-20s len %5.1f m  $%7.2f  %s%s"
		% [mark, label, r ["length"], r ["cost"],
			"green" if r ["ok"] else "red", "" if r ["reason"] == "" else " (%s)" % r ["reason"]])
