class_name DevCoinShotProbe
extends Node


var world: Node3D
var player: Player
var stand: HaySellingStand


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame
	stand.coins_anywhere = true

	var spout:= stand._coins_at
	var face:= Vector3(stand._coins_face.x, 0.0, stand._coins_face.z)
	if face.length() < 0.01:
		face = stand.global_transform.basis.z
	face = face.normalized()


	var ground:= Vector3(spout.x, stand.global_position.y, spout.z) + face * 0.8
	var watch:= ground.lerp(spout, 0.5)

	await _place(_station(watch, face, 4.0, 0.6), watch)


	for _try in 12:
		if stand._coin_land != Vector3.INF:
			break
		stand._coin_landing()
		await get_tree().create_timer(0.25).timeout
	stand._coin_ready_at = 0.0
	stand._big_ready_at = 0.0
	stand._celebrate(60.0, HaySellingStand.COIN_POOL)
	await get_tree().create_timer(0.35).timeout
	await _snap(out_dir, "coins_air.png")

	var land:= stand._coin_land
	await _place(_station(land, face, 2.8, 1.5), land)
	await get_tree().create_timer(1.0).timeout
	await _snap(out_dir, "coins_floor.png")
	print("coins out: %d, aimed at %.2v from a spout at %.2v, rising %.2f m"
		% [stand._coins_out, land, spout, stand._coin_rise])
	for c: ExtraLifeCoin in stand._coin_pool:
		if c.is_active():
			print("  %s at %.2v" % [c.name, c.global_position])

	var coin:= _nearest_loose(land)
	if coin == null:
		push_warning("coinshot: no coin left on the floor to photograph")
		get_tree().quit(1)
		return


	coin._life = 100.0
	var at:= coin.global_position
	print("closest coin at %.2v" % at)
	await _place(_station(at, face, 1.2, 0.9), at)
	await _snap(out_dir, "coin_close.png")

	if not player.carry.take(coin):
		push_warning("coinshot: the hands would not take the coin")
		get_tree().quit(1)
		return
	for i in 12:
		await get_tree().process_frame
	await _snap(out_dir, "coin_held.png")

	player.stamina.current = 20.0

	Input.action_press("primary")
	player.carry.begin_eat()
	var hold:= ExtraLifeCoin.EAT_HOLD
	var blink:= ExtraLifeCoin.EAT_BLINK
	var shine:= ExtraLifeCoin.EAT_SHINE
	var shrink:= ExtraLifeCoin.EAT_SHRINK
	await get_tree().create_timer(hold * 0.8).timeout
	await _snap(out_dir, "coin_eat_shake.png")
	await get_tree().create_timer(hold * 0.2 + blink * 0.5).timeout
	await _snap(out_dir, "coin_eat_rays.png")
	Input.action_release("primary")
	await get_tree().create_timer(blink * 0.5 + shine * 0.5).timeout
	await _snap(out_dir, "coin_eat_shine.png")
	await get_tree().create_timer(shine * 0.5 + shrink * 0.3).timeout
	await _snap(out_dir, "coin_eat_shrink.png")
	await get_tree().create_timer(0.5).timeout
	await _snap(out_dir, "stamina_rainbow.png")
	await get_tree().create_timer(0.35).timeout
	await _snap(out_dir, "stamina_rainbow_2.png")
	get_tree().quit(0)


func _nearest_loose(to: Vector3) -> ExtraLifeCoin:
	var nearest: ExtraLifeCoin = null
	for coin: ExtraLifeCoin in stand._coin_pool:
		if not coin.is_active() or coin.is_held():
			continue
		if nearest == null or coin.global_position.distance_to(to) < nearest.global_position.distance_to(to):
			nearest = coin
	return nearest


func _station(target: Vector3, preferred: Vector3, radius: float, lift: float) -> Vector3:
	var space:= player.get_world_3d().direct_space_state
	var best:= target + preferred * radius + Vector3.UP * lift
	var turns:= 24
	for step in turns:
		var swing:= TAU * float((step + 1) / 2) / float(turns)
		var angle:= swing if step % 2 == 0 else - swing
		var at:= target + preferred.rotated(Vector3.UP, angle) * radius + Vector3.UP * lift
		if world.field.height_at(at.x, at.z) > at.y - 0.4:
			continue
		var query:= PhysicsRayQueryParameters3D.create(target, at)
		query.exclude = [player.get_rid()]
		if space.intersect_ray(query).is_empty():
			return at
	return best


func _place(at: Vector3, target: Vector3) -> void:
	player.set_physics_process(false)
	var flat:= Vector2(target.x - at.x, target.z - at.z).length()
	player.set_look(atan2(target.x - at.x, target.z - at.z) + PI,
		atan2(target.y - at.y, maxf(flat, 0.001)))
	player.global_position = at
	for _pass in 3:
		for i in 4:
			await get_tree().process_frame
		player.global_position += at - player.camera.global_position
	for i in 4:
		await get_tree().process_frame


func _snap(out_dir: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
