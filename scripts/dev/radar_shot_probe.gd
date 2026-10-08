class_name DevRadarShotProbe
extends Node


var world: Node3D
var player: Player

const STEP:= 1.0 / 60.0


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var field: HayField = world.field
	var site:= _site(field)
	var at: Vector3 = site [0]
	var inward: Vector3 = site [1]
	var dish: NeedleRadar = world.builds.add_needle_radar(at, atan2(inward.x, inward.z))
	dish.set_process(false)
	for i in 10:
		await get_tree().process_frame
	print("dish at %s, %d needles in range" % [at, dish.targets_in_range().size()])

	var side:= inward.cross(Vector3.UP).normalized()


	dish.tier_override = 3
	GameState.radar_cooldown = 0.0
	print("activate: '%s'" % dish.activate())
	_step_until(dish, func() -> bool: return dish.phase == NeedleRadar.Phase.LOCK)
	_step_for(dish, Cfg.RADAR_LOCK_SECONDS * 0.8)
	var horn:= dish.horn_position()
	await _look(out_dir, "radar_1_charge.png", horn + side * 4.5 - inward * 1.0 + Vector3.UP * 0.4, horn)

	_step_until(dish, func() -> bool: return dish.phase == NeedleRadar.Phase.BEAM)
	_step_for(dish, Cfg.RADAR_BEAM_SECONDS * 0.12)
	horn = dish.horn_position()
	await _look(out_dir, "radar_2_horn.png", horn + side * 5.0 - inward * 2.0 + Vector3.UP * 1.5,
		horn + (horn - dish.global_position).normalized() * 2.0)

	_step_for(dish, Cfg.RADAR_BEAM_SECONDS * 0.2)
	var aim:= dish.aim_point()
	var mid:= at.lerp(aim, 0.5)


	await _look(out_dir, "radar_3_wide.png", at - inward * 2.5 - side * 7.0 + Vector3.UP * 1.8,
		mid + Vector3.UP * 5.0)

	_step_for(dish, Cfg.RADAR_BEAM_SECONDS * 0.08)
	var toward_dish:= (at - aim)
	toward_dish.y = 0.0
	toward_dish = toward_dish.normalized()
	await _look(out_dir, "radar_4_land.png", aim + toward_dish * 9.0 + side * 3.0 + Vector3.UP * 4.5, aim)

	_step_until(dish, func() -> bool: return dish.phase == NeedleRadar.Phase.RETURN)
	_step_for(dish, 1.0)
	var marks:= dish.marks()
	print("marks up: %d" % marks.size())
	if not marks.is_empty():
		var near:= _nearest(marks, at)
		var p: Vector3 = near ["centre"]
		var top:= field.height_at(p.x, p.z)
		var spot:= Vector3(p.x, top, p.z)
		var back:= (at - spot)
		back.y = 0.0
		back = back.normalized()
		print("close mark tag: %s" % str(near ["tag"]).c_escape())
		await _look(out_dir, "radar_5_mark_close.png",
			spot + back * 5.0 + side * 1.5 + Vector3.UP * 2.2, spot + Vector3.UP * 1.2)
		await _look(out_dir, "radar_6_marks_far.png",
			at + inward * 1.0 + side * 3.0 + Vector3.UP * 4.0, aim + Vector3.UP * 1.0)


	_step_until(dish, func() -> bool: return dish.phase == NeedleRadar.Phase.IDLE)
	dish.clear_marks()
	GameState.radar_cooldown = 0.0
	dish.tier_override = 0
	dish.activate()
	_step_until(dish, func() -> bool: return dish.phase == NeedleRadar.Phase.RETURN)
	_step_for(dish, 1.0)
	marks = dish.marks()
	if not marks.is_empty():
		var near:= _nearest(marks, at)
		var c: Vector3 = near ["centre"]
		var spot:= Vector3(c.x, field.height_at(c.x, c.z), c.z)
		var back:= (at - spot)
		back.y = 0.0
		back = back.normalized()
		await _look(out_dir, "radar_7_circle.png",
			spot + back * 6.0 + Vector3.UP * 3.5, spot + Vector3.UP * 0.3)

	get_tree().quit(0)


func _step_for(dish: NeedleRadar, seconds: float) -> void:
	var t:= 0.0
	while t < seconds:
		dish.tick(STEP)
		t += STEP


func _step_until(dish: NeedleRadar, done: Callable, limit: float = 60.0) -> void:
	var t:= 0.0
	while t < limit and not done.call():
		dish.tick(STEP)
		t += STEP


func _nearest(marks: Array [Dictionary], to: Vector3) -> Dictionary:
	var best: Dictionary = marks [0]
	var best_d:= INF
	for m in marks:
		var c: Vector3 = m ["centre"]
		var d:= Vector2(c.x - to.x, c.z - to.z).length()
		if d < best_d:
			best_d = d
			best = m
	return best


func _site(field: HayField) -> Array:
	for ring in [Cfg.PILE_RADIUS + 7.0, Cfg.PILE_RADIUS + 10.0, Cfg.PILE_RADIUS + 14.0]:
		for step in 16:
			var a:= TAU * float(step) / 16.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			var h:= field.height_at(at.x, at.z)
			if h > 0.05:
				continue
			at.y = maxf(h, 0.0)
			return [at, Vector3(- cos(a), 0.0, - sin(a))]
	return [Vector3(Cfg.PILE_RADIUS + 7.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]


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
