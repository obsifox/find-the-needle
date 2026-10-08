class_name DevPropProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30
const TIPPED:= 60
const POUR_SECONDS:= 6.0

var _rng:= RandomNumberGenerator.new()


func run() -> void:
	_rng.seed = 20260823
	for i in 40:
		await get_tree().process_frame


	var spot:= Vector3(13.0, 0.35, 4.0)
	player.global_position = spot + Vector3(-1.4, 0.05, 0.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = 0.0
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== spawn ===")
	var bucket:= world.props.spawn("bucket", Transform3D(Basis(), spot)) as Bucket
	var shovel: Carryable = world.props.spawn("sand_shovel",
		Transform3D(Basis(), spot + Vector3(0.9, 0.3, 0.0)))
	print("  bucket %s   sand shovel %s   props tracked %d"
		% [bucket != null, shovel != null, world.props.items.size()])
	if bucket == null:
		get_tree().quit()
		return
	for i in 90:
		await get_tree().physics_frame


	print("  bucket settled at %.3v  (floor under it %.4f, gap %+.4f)"
		% [bucket.global_position, _floor_under(bucket.global_position),
			bucket.global_position.y - _floor_under(bucket.global_position)])
	if shovel != null:
		var f:= _floor_under(shovel.global_position)
		print("  shovel settled at %.3v  (floor under it %.4f, gap %+.4f)"
			% [shovel.global_position, f,
				shovel.global_position.y - SandShovel.BLADE_POS.y
					+ SandShovel.BLADE_SIZE.y * 0.5 - f])
	_dump_materials(bucket)
	if shovel != null:
		_dump_materials(shovel)

	print("\n=== catching hay ===")
	var before:= bucket.stored
	for i in TIPPED:
		var p:= bucket.global_position + Vector3(
			_rng.randf_range(-0.06, 0.06), 0.65, _rng.randf_range(-0.06, 0.06))
		world.live.spawn(p, StrandFactory.random_strand_basis(_rng),
			Vector3(0, -0.6, 0), StrandFactory.random_tint(_rng))
	for i in 120:
		await get_tree().physics_frame
	print("  tipped %d strands in from 65 cm up; bucket counted %d"
		% [TIPPED, bucket.stored - before])
	print("  live strands still simulated: %d" % world.live.active_count())

	print("\n=== pick up ===")


	var eye:= player.eye_position()
	var to_bucket:= bucket.global_position + Vector3(0, Bucket.RIM_Y * 0.5, 0) - eye
	player.rotation = Vector3(0, atan2(- to_bucket.x, - to_bucket.z), 0)
	player.head.rotation.x = atan2(to_bucket.y, Vector2(to_bucket.x, to_bucket.z).length())
	await get_tree().physics_frame
	print("  aimed from %.2v, head pitch %.2f rad" % [eye, player.head.rotation.x])
	var took: bool = player.carry.try_pick()
	print("  try_pick -> %s   carrying %s   tools stowed %s"
		% [took, player.carry.is_carrying(),
			not (player.hand._active or player.shovel._active or player.build.is_active())])
	for i in 20:
		await get_tree().physics_frame
	var offset: float = bucket.global_position.distance_to(player.eye_position())
	print("  held %.2f m from the eye (reach is %.2f)" % [offset, Cfg.CARRY_REACH])

	print("\n=== pour ===")
	bucket.from_state({ "stored": Cfg.BUCKET_CAPACITY })
	var start: int = bucket.stored


	Input.action_press("carry_rotate")


	for i in 200:
		player.carry.rotate_input(Vector2(0.0, -60.0))
	print("  tilt limit %.2f rad; bucket up-vector now %.3f (pour starts under %.2f)"
		% [Cfg.CARRY_TILT_LIMIT, bucket.global_transform.basis.y.dot(Vector3.UP),
			Cfg.BUCKET_TIP_START])
	var ticks:= int(POUR_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var spawned_peak:= 0
	var tracker:= PourTracker.new()
	for i in ticks:


		player.carry.rotate_input(Vector2(0.0, -60.0))
		await get_tree().physics_frame
		spawned_peak = maxi(spawned_peak, world.live.active_count())
		var stream: Array [RigidBody3D] = world.live._active.duplicate()


		for item in world.props.items:
			if item is HayTuft:
				stream.append(item)
		tracker.tick(stream, bucket, i)
	print("  poured %d of %d strands in %.0f s (%d left in the bucket)"
		% [start - bucket.stored, start, POUR_SECONDS, bucket.stored])
	if not tracker.report():
		push_error("props: poured hay did not clear the mouth and rim")
		get_tree().quit(1)
		return
	print("  peak live strands during the pour: %d / %d budget"
		% [spawned_peak, Cfg.live_strand_budget])


	Input.action_release("carry_rotate")
	var held_at: int = bucket.stored
	for i in ticks:
		player.carry.rotate_input(Vector2(0.0, -60.0))
		await get_tree().physics_frame
	print("  with the gesture released, %d more strands left a bucket tilted just as far"
		% (held_at - bucket.stored))

	print("\n=== pouring into the stand ===")


	var st: HaySellingStand = world.stand
	var bay: Vector3 = st.to_global(Vector3(-2.1, 1.18, 3.05))


	var stance: Vector3 = st.to_global(Vector3(-2.1, 0.0, 4.35))
	var facing: Vector3 = (bay - stance)
	player.global_position = stance + Vector3(0, 0.1, 0)
	player.rotation = Vector3(0, atan2(- facing.x, - facing.z), 0)
	player.head.rotation.x = -0.25
	bucket.from_state({ "stored": 240 })
	var purse:= GameState.money
	var sold_before:= GameState.hay_sold
	Input.action_press("carry_rotate")
	for k in 40:
		player.carry.rotate_input(Vector2(0.0, -60.0))
	for i in int(5.0 / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	Input.action_release("carry_rotate")
	print("  poured %d strands over the bay; sold %d, balance $%.2f -> $%.2f"
		% [240 - bucket.stored, int(GameState.hay_sold - sold_before), purse,
			GameState.money])

	print("\n=== drop and throw ===")
	player.carry.drop()
	print("  after drop: carrying %s, frozen %s" % [player.carry.is_carrying(), bucket.freeze])
	for i in 40:
		await get_tree().physics_frame
	print("  bucket resting at %.3v" % bucket.global_position)

	print("\n=== wheelbarrow ===")


	player.global_position = Vector3(11.0, 0.4, 6.2)
	player.head.rotation.x = 0.0
	var barrow:= world.props.spawn("wheelbarrow",
		Transform3D(Basis(), Vector3(11.0, 0.4, 4.6))) as Wheelbarrow
	for i in 60:
		await get_tree().physics_frame
	print("  settled at %.3v  (floor %.4f)"
		% [barrow.global_position, _floor_under(barrow.global_position)])

	var eye2:= player.eye_position()
	var to_it:= barrow.global_position + Vector3(0, Wheelbarrow.RIM_Y, 0) - eye2
	player.rotation = Vector3(0, atan2(- to_it.x, - to_it.z), 0)
	player.head.rotation.x = atan2(to_it.y, Vector2(to_it.x, to_it.z).length())


	for i in 8:
		await get_tree().process_frame
	var seen:= player.carry.target()
	print("  under the crosshair: %s   prompt: %s %s   highlighted: %s"
		% [seen != null,
			seen.interact_key() if seen != null else "-",
			seen.interact_verb() if seen != null else "-",
			seen._highlighted if seen != null else false])
	print("  left-button pick refused (it is not a hand item): %s"
		% not player.carry.try_pick(true))
	print("  E pick -> %s" % player.carry.try_pick())
	for i in 20:
		await get_tree().physics_frame

	var grip:= barrow.to_global(Wheelbarrow.GRIP)
	var wheel_bottom: float = barrow.to_global(Wheelbarrow.AXLE).y - Wheelbarrow.WHEEL_R
	print("  grips %.2f m in front of the player and %.3f m up; wheel %+.3f off the floor"
		% [Vector2(grip.x - player.global_position.x,
			grip.z - player.global_position.z).length(),
			grip.y - _floor_under(grip),
			wheel_bottom - _floor_under(barrow.global_position)])

	var was:= barrow.global_position
	var walked_from:= player.global_position
	for i in 60:
		player.velocity = Vector3(0, player.velocity.y, -2.5)
		player.move_and_slide()
		await get_tree().physics_frame
	print("  player walked %.2f m, barrow followed %.2f m, still %+.3f off the floor"
		% [walked_from.distance_to(player.global_position),
			was.distance_to(barrow.global_position),
			barrow.global_position.y - _floor_under(barrow.global_position)])


	barrow.from_state({ "stored": Cfg.BARROW_CAPACITY })
	var before_tip: int = barrow.stored
	var lip_was: Vector3 = barrow.to_global(Vector3(0, Wheelbarrow.RIM_Y, Wheelbarrow.RIM_Z0))
	var grip_was: Vector3 = barrow.to_global(Wheelbarrow.GRIP)
	Input.action_press("carry_rotate")
	for k in 40:
		player.carry.rotate_input(Vector2(0.0, -60.0))
	await get_tree().physics_frame
	print("  tipped: front lip %+.3f m, grips %+.3f m -- it turns over the wheel"
		% [barrow.to_global(Vector3(0, Wheelbarrow.RIM_Y, Wheelbarrow.RIM_Z0)).y - lip_was.y,
			barrow.to_global(Wheelbarrow.GRIP).y - grip_was.y])
	for i in int(4.0 / maxf(get_physics_process_delta_time(), 1e-06)):
		player.carry.rotate_input(Vector2(0.0, -60.0))
		await get_tree().physics_frame
	Input.action_release("carry_rotate")
	print("  poured %d of %d strands in 4 s (%d left)"
		% [before_tip - barrow.stored, before_tip, barrow.stored])


	var ahead:= 0
	var behind:= 0
	var fwd:= - barrow.global_transform.basis.z
	for strand in world.live._active:
		if (strand.global_position - barrow.global_position).dot(fwd) > 0.0:
			ahead += 1
		else:
			behind += 1
	print("  of %d loose strands, %d landed ahead of the barrow and %d behind"
		% [ahead + behind, ahead, behind])
	player.carry.drop()
	print("  after letting go: carrying %s" % player.carry.is_carrying())


	await _upgrades_are_visible(bucket)

	print("\n=== save round trip ===")
	bucket.from_state({ "stored": 137 })
	var packed: Array = world.props.to_array()
	world.props.from_array(packed)
	var restored:= 0
	var carried_over:= -1
	for item in world.props.items:
		if item is Bucket:
			restored += 1
			carried_over = maxi(carried_over, (item as Bucket).stored)
	print("  %d prop(s) serialised, %d bucket(s) back, fullest holds %d strands"
		% [packed.size(), restored, carried_over])

	get_tree().quit()


func _floor_under(p: Vector3) -> float:
	var from:= p + Vector3(0, 2.0, 0)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0)
	q.collision_mask = Cfg.L_WORLD
	q.collide_with_areas = false
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit ["position"] as Vector3).y if not hit.is_empty() else NAN


func _dump_materials(item: Carryable) -> void:
	for n in item.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m:= mi.get_active_material(i) as StandardMaterial3D
			if m == null:
				continue
			var c:= m.albedo_color
			print("    %-12s %-10s albedo sRGB(%.3f %.3f %.3f) -> linear(%.4f %.4f %.4f)  metal %.2f  rough %.2f"
				% [item.item_id, m.resource_name, c.r, c.g, c.b,
					c.srgb_to_linear().r, c.srgb_to_linear().g, c.srgb_to_linear().b,
					m.metallic, m.roughness])


func _upgrades_are_visible(bucket: HayContainer) -> void:
	print("\n=== a bigger bucket is bigger ===")
	player.carry.drop()
	for i in 10:
		await get_tree().physics_frame
	Tech.reset()
	await get_tree().physics_frame
	var before:= _drawn_size(bucket)
	var cap_before:= bucket.capacity()

	Tech.grant("bucket", 1)
	Tech.grant("bucket_size", 5)


	for i in 10:
		await get_tree().physics_frame
	var after:= _drawn_size(bucket)
	var cap_after:= bucket.capacity()

	var grew:= after.y / maxf(before.y, 1e-06)
	print("  drawn height  %.3f m -> %.3f m  (x%.3f, want x%.3f)"
		% [before.y, after.y, grew, pow(1.1, 5.0)])
	print("  capacity      %d -> %d  (x%.2f, and capacity is the cube of size)"
		% [cap_before, cap_after, float(cap_after) / maxf(float(cap_before), 1.0)])
	print("  %s the bucket grew with its upgrade"
		% ("ok  " if grew > 1.4 else "FAIL"))


class PourTracker:
	const AGE:= 10
	const FOLLOW:= 45


	const CLEAR:= 0.1
	var _last: Dictionary = { }
	var _pending: Array = []
	var ahead:= 0
	var under:= 0
	var behind:= 0
	var stuck:= 0
	var went_back:= 0
	var _sum:= 0.0

	func tick(active: Array [RigidBody3D], bucket: Bucket, now: int) -> void:
		var here: Dictionary = { }
		for b in active:
			var id:= b.get_instance_id()
			here [id] = true
			if not _last.has(id):


				_pending.append([b, now, false])
		_last = here
		var up:= bucket.global_transform.basis.y
		var f:= Vector3(up.x, 0.0, up.z)
		if f.length_squared() < 1e-06:
			return
		f = f.normalized()
		var mouth:= bucket.pour_point()
		var base:= bucket.global_position
		var keep: Array = []
		for e: Array in _pending:
			var body: RigidBody3D = e [0]
			if not is_instance_valid(body) or not here.has(body.get_instance_id()):
				continue
			var age:= now - int(e [1])
			var p:= body.global_position
			if not e [2] and (p - base).dot(f) < 0.0:
				e [2] = true
				went_back += 1
			if age == AGE:
				var d:= (p - mouth).dot(f)
				_sum += d
				if body.linear_velocity.length() < 0.3:
					stuck += 1
				if d > 0.0:
					ahead += 1
				elif (p - base).dot(f) > 0.0:
					under += 1
				else:
					behind += 1
			if age < FOLLOW:
				keep.append(e)
		_pending = keep

	func report() -> bool:
		var n:= maxi(ahead + under + behind, 1)
		var mean:= _sum / float(n)
		print("  %d tick(s) after leaving: %d ahead of the mouth, %d under the bucket, %d behind its base; on average %+.3f m past the middle of the mouth"
			% [AGE, ahead, under, behind, mean])
		print("  %d had stopped on the bucket instead of falling; %d went behind the base at some point in %d ticks"
			% [stuck, went_back, FOLLOW])
		print("  %s the stream comes out of the mouth, not out from under the bucket"
			% ("ok  " if mean > CLEAR and went_back == 0 else "FAIL"))
		print("  %s nothing the pour makes is born stuck on the rim"
			% ("ok  " if float(stuck) / float(n) < 0.05 else "FAIL"))
		return ahead + under + behind > 0 and mean > CLEAR and went_back == 0 and float(stuck) / float(n) < 0.05


func _drawn_size(item: Node3D) -> Vector3:
	var box:= AABB()
	var first:= true
	for n in item.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		var world:= mi.global_transform * mi.mesh.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box.size
