class_name DevAlertShotProbe
extends Node


var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var site:= _site()
	if site.is_empty():
		push_warning("alertshot: no spot beside the pile to stand a rake on")
		get_tree().quit(1)
		return
	GameState.add_money(2000.0)


	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1] + PI)


	var side:= Vector3(cos(site [1]), 0.0, - sin(site [1])) * 2.2
	var twin: PistonRake = world.builds.add_piston_rake(site [0] + side, site [1] + PI)
	for i in 10:
		await get_tree().process_frame


	var watch: MachineWatch = world.builds.watch
	for i in 30:
		watch.force_sweep(MachineWatch.POLL)
	await get_tree().process_frame
	print("machines flagged: %d  ·  %s"
		% [watch.alert_count(), watch.alert_reason(rake)])
	if twin != null and watch._tracked.has(twin.get_instance_id()):
		var twin_sign: MachineAlert = watch._tracked [twin.get_instance_id()] ["sign"]
		if twin_sign != null:
			twin_sign.set_icon("power")

	var chest:= rake.global_position + Vector3(0.0, 1.1, 0.0)
	var pair:= chest + side * 0.5 if twin != null else chest


	var behind:= - Vector3(sin(site [1]), 0.0, cos(site [1]))

	await _look(out_dir, "alert_near.png", _station(pair, behind, 4.5, 0.4), pair)
	await _look(out_dir, "alert_far.png", _station(pair, behind, 11.0, 1.6), pair)
	await _look(out_dir, "alert_over_hay.png",
		_station(pair, behind, 6.0, 3.2), pair)


	await _look(out_dir, "alert_aimed.png", _station(chest, behind, 4.5, 0.4), chest)


	await _look(out_dir, "alert_edge.png",
		_station(chest, behind, MachineAlert.CUT_RANGE - MachineAlert.FADE, 2.4),
		chest)

	get_tree().quit(0)


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


func _site() -> Array:
	var field: HayField = world.field
	var flat: Array = []
	for ring in [7.0, 8.0, 9.0, 6.0, 10.0, 12.0, 14.0, 16.0, 18.0]:
		for step in 24:
			var a:= TAU * float(step) / 24.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			at.y = field.height_at(at.x, at.z)
			if at.y > 0.1:
				continue
			var inward:= Vector3(- cos(a), 0.0, - sin(a)).normalized()
			if flat.is_empty():
				flat = [at, atan2(inward.x, inward.z)]
			var face:= at + inward * Cfg.RAKE_REACH
			if field.height_at(face.x, face.z) > at.y + 0.25:
				return [at, atan2(inward.x, inward.z)]


	return flat


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3) -> void:
	player.set_physics_process(false)


	var flat:= Vector2(target.x - at.x, target.z - at.z).length()
	player.set_look(atan2(target.x - at.x, target.z - at.z) + PI,
		atan2(target.y - at.y, maxf(flat, 0.001)))
	player.global_position = at
	for pass_i in 3:
		for i in 4:
			await get_tree().process_frame
		player.global_position += at - player.camera.global_position
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
