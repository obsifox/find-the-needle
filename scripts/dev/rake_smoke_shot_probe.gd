class_name DevRakeSmokeShotProbe
extends Node


const EYE:= 1.9

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var site:= _site()
	if site.is_empty():
		push_warning("rakeshot: no spot beside the pile to stand a rake on")
		get_tree().quit(1)
		return
	GameState.add_money(2000.0)
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])


	for i in 90:
		await get_tree().process_frame


	player.set_physics_process(false)


	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var side:= fwd.cross(Vector3.UP).normalized()


	var chest:= rake.global_position + Vector3(0.0, 1.0, 0.0)
	var stand:= chest + side * 1.8 - fwd * 0.6 + Vector3(0.0, 0.5, 0.0)
	await _look(out_dir, "rake_readout.png", stand, chest)


	await _look(out_dir, "rake_console_behind.png",
		chest - fwd * 2.4 + Vector3(0.0, 0.4, 0.0), chest)


	var apron:= rake.global_position + side * 4.0
	apron.y = world.field.height_at(apron.x, apron.z)
	var spare: PistonRake = world.builds.add_piston_rake(apron, site [1])
	spare.throw_distance = 5.0
	for i in 8:
		await get_tree().process_frame


	await _look(out_dir, "rake_hover.png",
		spare.global_position - fwd * 1.0 + side * 5.5 + Vector3(0.0, 6.5, 0.0),
		spare.global_position + Vector3(0.0, 0.6, 0.0))


	player.rake_panel.open(spare)
	for i in 6:
		await get_tree().process_frame


	await _look(out_dir, "rake_range.png",
		spare.global_position - fwd * 1.0 + side * 5.5 + Vector3(0.0, 6.5, 0.0),
		spare.global_position - fwd * 1.2 + Vector3(0.0, 0.2, 0.0))
	player.rake_panel.close()

	get_tree().quit(0)


func _site() -> Array:
	var field: HayField = world.field
	for ring_step in range(12, 30):
		var ring:= float(ring_step) * 0.5
		for step in 24:
			var a:= TAU * float(step) / 24.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			at.y = field.height_at(at.x, at.z)
			if at.y > 0.1:
				continue
			var inward:= Vector3(- cos(a), 0.0, - sin(a)).normalized()
			if player.build._rake_hay_over_chassis(at, inward, field) > Cfg.RAKE_STAND_CLEAR:
				continue
			var face:= at + inward * Cfg.RAKE_REACH
			if field.height_at(face.x, face.z) > at.y + 0.25:
				return [at, atan2(inward.x, inward.z)]
	return []


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3) -> void:


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
	print("wrote %s  (lens off by %.3f m)"
		% [path, player.camera.global_position.distance_to(at)])
