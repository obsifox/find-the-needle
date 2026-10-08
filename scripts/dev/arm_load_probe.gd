class_name DevArmLoadProbe
extends Node


var world: Node3D
var player: Player


const SETTLE:= 40

const WALK:= 90


const OVERLAP_SLACK:= 0.005


const FOLLOW_REACH:= 3.2

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	for i in SETTLE:
		await get_tree().physics_frame
	await _case_no_card()
	Tech.grant("arm_load", TechTree.max_rank("arm_load"))
	print("\n  Strong Arms at rank %d: %d in the arms"
		% [Tech.rank_of("arm_load"), Tech.carry_stack()])
	await _case_full_pile()
	await _case_walk()
	await _case_in_view()
	await _case_unload()
	await _case_throw()
	await _case_drop_all()
	await _case_bucket()
	Tech.grant("arm_load", 0)
	print("\n[armload] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _floor_at(at: Vector3) -> float:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit ["position"] as Vector3).y if not hit.is_empty() else 0.0


func _stand() -> Vector3:
	player.carry.drop_all()
	player.global_position = Vector3(13.2, 0.4, 5.6)
	player.rotation = Vector3.ZERO
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	var spot:= player.global_position + Vector3(0, 0, -1.2)
	spot.y = _floor_at(spot)
	return spot


func _spawn(id: String, at: Vector3) -> Carryable:
	var props: PropManager = world.props
	return props.spawn(id, Transform3D(Basis(), at), { "strands": 60 })


func _clear(items: Array) -> void:
	var props: PropManager = world.props
	player.carry.drop_all()
	for it in items:
		if is_instance_valid(it):
			props.remove(it as Carryable)
	for i in 5:
		await get_tree().physics_frame


func _span_of(item: Carryable, axis: Vector3) -> Vector2:
	var box:= item.ride_box()
	var xf:= item.global_transform
	var lo:= INF
	var hi:= - INF
	for i in 8:
		var corner:= xf * (box.position + Vector3(
			box.size.x if (i & 1) != 0 else 0.0,
			box.size.y if (i & 2) != 0 else 0.0,
			box.size.z if (i & 4) != 0 else 0.0))
		var d:= corner.dot(axis)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


func _stacked_clear(items: Array) -> bool:
	var ok:= true
	var axis:= player.carry.pile_up()
	var below:= _span_of(items [0] as Carryable, axis)
	for i in range(1, items.size()):
		var span:= _span_of(items [i] as Carryable, axis)
		var gap:= span.x - below.y
		print("      block %d: %.3f to %.3f up the pile, %.0f mm above the one below"
			% [i + 1, span.x, span.y, gap * 1000.0])
		if gap < - OVERLAP_SLACK:
			ok = false
		below = span
	return ok


func _case_no_card() -> void:
	print("\n=== with nothing bought, the arms take one block ===")
	var spot:= _stand()
	var a:= _spawn("hay_wad", spot + Vector3.UP * 0.05)
	var b:= _spawn("hay_wad", spot + Vector3(0.7, 0.05, 0.0))
	for i in SETTLE:
		await get_tree().physics_frame
	_check("the card is unbought (%d in the arms)" % Tech.carry_stack(),
		Tech.carry_stack() == 1)
	_check("the first block goes in", player.carry.take(a))
	_check("the arms have no room for a second", not player.carry.stack_has_room())
	_check("stacking the second is refused", not player.carry.stack_on(b))
	_check("still carrying one", player.carry.carried_count() == 1)


	var fulls:= player.carry.arms_full
	var dir:= b.global_position - player.eye_position()
	var yaw:= atan2(- dir.x, - dir.z)
	var pitch:= atan2(dir.y, Vector2(dir.x, dir.z).length())
	player.set_look(yaw, pitch)
	for i in 20:
		await get_tree().process_frame
	_check("looking at the second with full arms is counted, once (%d)"
		% (player.carry.arms_full - fulls), player.carry.arms_full == fulls + 1)
	_check("...at the limit the player met (%d)" % player.carry.full_cap,
		player.carry.full_cap == 1 and player.carry.since_full() < 1.0)
	player.set_look(yaw, deg_to_rad(60.0))
	for i in 10:
		await get_tree().process_frame
	player.set_look(yaw, pitch)
	for i in 10:
		await get_tree().process_frame
	_check("looking away and back counts again", player.carry.arms_full == fulls + 2)
	await _clear([a, b])


func _case_full_pile() -> void:
	print("\n=== five blocks go into the arms and the sixth does not ===")
	var spot:= _stand()
	var kinds:= ["hay_wad", "hay_bale", "foiled_bale", "eco_brick", "feed_disc", "hay_wad"]
	var made: Array = []
	for i in kinds.size():
		made.append(_spawn(kinds [i], spot + Vector3(float(i) * 0.9, 0.05, 0.0)))
		for j in 4:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	for it in made:
		if it == null:
			_fail("a block would not spawn")
			await _clear(made)
			return
	_check("the first block goes in", player.carry.take(made [0] as Carryable))
	for i in range(1, 5):
		_check("block %d stacks (%s)" % [i + 1, kinds [i]],
			player.carry.stack_on(made [i] as Carryable))
	_check("five in the arms (%d)" % player.carry.carried_count(),
		player.carry.carried_count() == 5)
	_check("the arms are full", not player.carry.stack_has_room())
	_check("the sixth is refused", not player.carry.stack_on(made [5] as Carryable))
	_check("what is IN the hands is the last one taken",
		player.carry.held() == made [4])
	for i in 5:
		await get_tree().physics_frame
	print("    the pile as it stands:")
	_check("every block stands on the one below it",
		_stacked_clear(made.slice(0, 5)))
	await _clear(made)


func _case_walk() -> void:
	print("\n=== the pile follows the player round the yard ===")
	var spot:= _stand()
	var made: Array = []
	for i in 5:
		made.append(_spawn("hay_bale", spot + Vector3(float(i) * 0.9, 0.05, 0.0)))
		for j in 4:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	player.carry.take(made [0] as Carryable)
	for i in range(1, 5):
		player.carry.stack_on(made [i] as Carryable)
	var worst:= 0.0
	for i in WALK:


		player.rotate_y(0.02)
		player.velocity = - player.global_transform.basis.z * 2.0
		player.move_and_slide()
		await get_tree().physics_frame
		for it in made.slice(0, 5):
			var d: float = player.global_position.distance_to(
				(it as Carryable).global_position)
			worst = maxf(worst, d)
	print("    the furthest any block got from the player: %.2f m" % worst)
	_check("the pile stayed in the arms (%.2f m)" % worst, worst < FOLLOW_REACH)
	_check("still five in the arms (%d)" % player.carry.carried_count(),
		player.carry.carried_count() == 5)
	print("    the pile after the walk:")
	_check("every block still stands on the one below it",
		_stacked_clear(made.slice(0, 5)))
	await _clear(made)


func _case_in_view() -> void:
	print("\n=== where a full pile sits in the view ===")
	var spot:= _stand()
	var made: Array = []
	for i in 5:
		made.append(_spawn("hay_bale", spot + Vector3(float(i) * 0.9, 0.05, 0.0)))
		for j in 4:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	player.carry.take(made [0] as Carryable)
	for i in range(1, 5):
		player.carry.stack_on(made [i] as Carryable)
	for i in 5:
		await get_tree().physics_frame
	var eye:= player.eye_position()
	var fwd:= player.look_direction()
	var up:= Vector3.UP
	print("    the eye is at y %.2f, the vertical field of view is %.0f degrees"
		% [eye.y, player.camera.fov if player.camera != null else 0.0])
	for i in 5:
		var it:= made [i] as Carryable
		var box:= it.global_transform * it.ride_box()
		var mid:= box.get_center()
		var d:= mid - eye
		var flat:= (d - up * d.dot(up)).length()
		var right:= fwd.cross(up).normalized()
		var ahead:= maxf(d.dot(fwd), 0.001)
		print("      block %d: %.0f deg up and %.0f deg right of the crosshair, %.2f m out"
			% [i + 1, rad_to_deg(atan2(d.dot(up), maxf(flat, 0.001))),
				rad_to_deg(atan2(d.dot(right), ahead)), d.length()])
		print("        its near edge is %.0f deg right, its top %.0f deg up"
			% [rad_to_deg(atan2(box.position.dot(right) - eye.dot(right), ahead)),
				rad_to_deg(atan2(box.end.y - eye.y, ahead))])
	await _clear(made)


func _case_throw() -> void:
	print("\n=== a throw off a pile flies like a throw from empty arms ===")
	var solo:= await _throw_from(1, 0.0)
	var piled:= await _throw_from(5, 0.0)
	var turning:= await _throw_from(5, 0.05)
	print("    on its own %.2f m, off five %.2f m, off five while turning %.2f m"
		% [solo, piled, turning])
	_check("a bale thrown on its own goes somewhere (%.2f m)" % solo, solo > 1.5)
	_check("off a pile it goes at least as far as 80%% of that (%.2f m)" % piled,
		piled > solo * 0.8)
	_check("and while turning as well (%.2f m)" % turning, turning > solo * 0.8)


	var solo_down:= await _throw_from(1, 0.0, -40.0)
	var piled_down:= await _throw_from(5, 0.0, -40.0)
	print("    looking down: on its own %.2f m, off five %.2f m" % [solo_down, piled_down])
	_check("looking down, off a pile it goes as far as 80%% of a lone throw (%.2f m)"
		% piled_down, piled_down > solo_down * 0.8)


func _throw_from(count: int, turn: float, pitch: float = 0.0) -> float:
	var spot:= _stand()
	var made: Array = []
	for i in count:
		made.append(_spawn("hay_bale", spot + Vector3(float(i) * 0.9, 0.05, 0.0)))
		for j in 4:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	player.carry.take(made [0] as Carryable)
	for i in range(1, count):
		player.carry.stack_on(made [i] as Carryable)
	if count > 1:
		var top:= made [count - 1] as Carryable
		var under:= made [count - 2] as Carryable
		_check("carried blocks ignore each other",
			under in top.get_collision_exceptions())
	player.head.rotation.x = deg_to_rad(pitch)
	for i in 10:
		player.rotate_y(turn)
		await get_tree().physics_frame
	var thrown:= made [count - 1] as Carryable
	var from:= thrown.global_position
	player.carry.throw()
	for i in 90:
		if i < 10:
			player.rotate_y(turn)
		await get_tree().physics_frame
	var d:= thrown.global_position - from
	var flat:= Vector2(d.x, d.z).length()
	await _clear(made)
	return flat


func _case_drop_all() -> void:
	print("\n=== a whole armful let go of at once ===")
	var spot:= _stand()
	var made: Array = []
	for i in 5:
		made.append(_spawn("hay_wad", spot + Vector3(float(i) * 0.9, 0.05, 0.0)))
		for j in 4:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	player.carry.take(made [0] as Carryable)
	for i in range(1, 5):
		player.carry.stack_on(made [i] as Carryable)
	player.carry.drop_all()
	var fastest:= 0.0


	for i in 150:
		await get_tree().physics_frame
		if i > 60:
			for it in made:
				fastest = maxf(fastest, (it as Carryable).linear_velocity.length())
	var blind:= 0
	for it in made:
		for ex in (it as Carryable).get_collision_exceptions():
			print("      %s is still blind to %s" % [(it as Node).name, ex.name])
			blind += 1
	print("    fastest after landing %.2f m/s, %d exceptions left" % [fastest, blind])
	_check("nothing was fired off (%.2f m/s)" % fastest, fastest < 4.0)
	_check("they collide with each other again once apart (%d left)" % blind, blind == 0)
	await _clear(made)


func _case_unload() -> void:
	print("\n=== putting a pile down, one block at a time ===")
	var spot:= _stand()
	var made: Array = []
	for i in 3:
		made.append(_spawn("hay_wad", spot + Vector3(float(i) * 0.9, 0.05, 0.0)))
		for j in 4:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	player.carry.take(made [0] as Carryable)
	player.carry.stack_on(made [1] as Carryable)
	player.carry.stack_on(made [2] as Carryable)
	_check("three in the arms", player.carry.carried_count() == 3)
	var top: Carryable = made [2]
	player.carry.drop()
	_check("the top one left the arms", player.carry.carried_count() == 2)
	_check("the one under it is in the hands now", player.carry.held() == made [1])
	_check("the block that came off is loose again", not top.is_held())
	for i in SETTLE:
		await get_tree().physics_frame
	var floor_y:= _floor_at(top.global_position)
	print("    it came to rest at y %.2f, floor at %.2f, %.2f m from the player"
		% [top.global_position.y, floor_y,
			player.global_position.distance_to(top.global_position)])
	_check("it landed on the floor", top.global_position.y - floor_y < 1.0)
	_check("it landed in front of the player",
		player.global_position.distance_to(top.global_position) < 3.0)
	player.carry.drop_all()
	_check("the arms are empty after drop_all", not player.carry.is_carrying())
	for i in SETTLE:
		await get_tree().physics_frame
	var loose:= 0
	for it in made:
		if is_instance_valid(it) and not (it as Carryable).is_held():
			loose += 1
	_check("all three are loose bodies again (%d)" % loose, loose == 3)
	await _clear(made)


func _case_bucket() -> void:
	print("\n=== a bucket neither stacks nor takes a stack ===")
	var spot:= _stand()
	var bucket:= _spawn("bucket", spot + Vector3.UP * 0.05)
	var wad:= _spawn("hay_wad", spot + Vector3(0.9, 0.05, 0.0))
	for i in SETTLE:
		await get_tree().physics_frame
	if bucket == null or wad == null:
		_fail("the bucket or the wad would not spawn")
		await _clear([bucket, wad])
		return
	_check("a bucket does not stack", not bucket.stacks_in_arms())
	_check("a wad does", wad.stacks_in_arms())
	player.carry.take(bucket)
	_check("nothing stacks onto a bucket", not player.carry.stack_on(wad))
	_check("the bucket is still the only thing carried",
		player.carry.carried_count() == 1)
	player.carry.drop_all()
	for i in 10:
		await get_tree().physics_frame
	player.carry.take(wad)
	_check("a bucket does not stack onto a wad", not player.carry.stack_on(bucket))
	await _clear([bucket, wad])
