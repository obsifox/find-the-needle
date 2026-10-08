class_name DevSackShotProbe
extends Node


const EYE:= Vector3(-2.1, 1.62, 5.37)


const LOOK:= Vector3(1.4, 1.05, 2.9)


const FILLS:= [0.0, 0.55, 1.0]


const BEATS:= [0.17, 0.23, 0.4, 0.95, 1.35]


const FILM_FRAMES:= 6
const FILM_TAIL_FRAMES:= 40


const FILM_MAX_FRAMES:= 420

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	var stand: HaySellingStand = world.stand
	if stand == null:
		push_error("DevSackShotProbe: the world has no selling stand")
		get_tree().quit(1)
		return

	_stand_at(stand)
	for f: float in FILLS:
		_hold(stand, f)
		await _snap(out_dir, "sack_fill_%02d.png" % int(round(f * 100.0)))


	var lcd:= stand.find_child("ScaleStrandReadout", true, false) as Node3D
	if lcd == null:
		push_error("DevSackShotProbe: the stand has no ScaleStrandReadout")
	else:
		_hold(stand, 0.55)
		stand.set("_scale_strands", 1234)


		var eye:= get_viewport().get_camera_3d()
		var cam:= Camera3D.new()
		cam.fov = 35.0
		stand.add_child(cam)
		var face:= lcd.global_transform.basis.z.normalized()
		cam.look_at_from_position(lcd.global_position + face * 0.35 + Vector3.UP * 0.08,
			lcd.global_position, Vector3.UP)
		cam.make_current()
		await _snap(out_dir, "scale_lcd.png")
		cam.free()
		if eye != null:
			eye.make_current()
		stand.set("_scale_strands", 0)


	var tree:= get_tree()
	var step:= 1.0 / float(Engine.physics_ticks_per_second)
	for t: float in BEATS:


		var stale:= stand.find_child("SackInFlight", false, false)
		if stale != null:
			stale.free()


		_hold(stand, 1.0)
		stand.call("_launch_sack")
		var clock:= 0.0
		while clock < t:
			await tree.physics_frame


			_stand_at(stand)
			clock += step
		await _snap(out_dir, "sack_launch_%03d.png" % int(round(t * 100.0)))
	print("[sackshot] done")
	get_tree().quit(0)


func _stand_at(stand: HaySellingStand) -> void:
	var at:= stand.to_global(EYE)
	var target:= stand.to_global(LOOK)
	player.global_position = at


	player.look_at_from_position(at, Vector3(target.x, at.y, target.z), Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		var flat:= Vector2(target.x - at.x, target.z - at.z).length()
		player.head.rotation.x = atan2(target.y - at.y, flat)


func _hold(stand: HaySellingStand, f: float) -> void:
	stand.set("_notches", int(round(f * float(HaySellingStand.SACK_NOTCHES))))
	stand.set("_notch_queue", 0)
	stand.set("_notch_clock", 0.0)
	stand.set("_weigh", f)
	stand.set("_weigh_vel", 0.0)


	stand.set("_sack_idle", 0.0)
	stand.set("_batch_idle", 999.0)
	stand.set("_batch_age", 0.0)


	stand.set("_hold", 0.0)
	stand.set("_flyer", null)


func _snap(out_dir: String, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


func film(out_dir: String) -> void:
	world.block_save = true
	var stand: HaySellingStand = world.stand
	if stand == null:
		push_error("DevSackShotProbe: the world has no selling stand")
		get_tree().quit(1)
		return
	_stand_at(stand)

	var sp:= stand.get("_sack_anim") as AnimationPlayer
	if sp != null:
		sp.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	stand.set("_notches", 0)
	stand.set("_notch_queue", 0)
	stand.set("_weigh", 0.0)
	stand.set("_weigh_vel", 0.0)


	var arrivals:= int(float(HaySellingStand.SACK_NOTCHES) * 1.6)
	var dropped:= 0
	var shot:= 0
	var flown:= false
	var tail:= 0


	var tree:= get_tree()
	while true:
		tree.paused = false
		await tree.physics_frame
		await tree.physics_frame
		tree.paused = true


		_stand_at(stand)
		if dropped < arrivals and shot % FILM_FRAMES == 0:
			dropped += 1


			stand.call("_earn_notch", HaySellingStand.NOTCH_STRANDS)


		if stand.find_child("SackInFlight", false, false) != null:
			flown = true
		elif flown:
			tail += 1
		if tail > FILM_TAIL_FRAMES or shot > FILM_MAX_FRAMES:
			break
		await _snap(out_dir, "film_%04d.png" % shot)
		shot += 1
	tree.paused = false
	print("[sackshot] filmed %d frames" % shot)
	get_tree().quit(0)
