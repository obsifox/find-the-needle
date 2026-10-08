class_name DevJetpackShotProbe
extends Node


const HEIGHT:= 30.0
const PITCH:= -0.32

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.8)
	player.capture_mouse(true)
	if "--jettrail" in OS.get_cmdline_user_args():
		await _trail(out_dir)
		get_tree().quit()
		return
	player.set_noclip(true)
	player.global_position = Vector3(0.0, HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	for k in 4:
		player.rotation = Vector3(0.0, float(k) * PI * 0.5, 0.0)
		player.head.rotation.x = PITCH
		await _wait(1.5)
		await _shot(out_dir, "over_yard_%d" % k)
	get_tree().quit()


func _trail(out_dir: String) -> void:
	Tech.grant("jetpack", 1)
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	var spot:= Vector3(13.4, 0.15, 8.0)
	player.global_position = spot
	player.velocity = Vector3.ZERO
	await _wait(0.6)
	var to_middle:= Vector3(- spot.x, 0.0, - spot.z).normalized()
	player.rotation = Vector3(0.0, atan2(- to_middle.x, - to_middle.z), 0.0)
	player.head.rotation.x = -1.3

	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	await _frames(6)
	Input.action_press("jump")
	await _wait(0.35)
	await _shot(out_dir, "jet_lift_off")
	player.head.rotation.x = 0.0
	var from:= player.global_position
	Input.action_press("move_forward")
	await _wait(1.3)
	Input.action_release("move_forward")
	var to:= player.global_position
	player.rotation.y += PI
	player.head.rotation.x = -0.45
	await _wait(0.1)
	await _shot(out_dir, "jet_trail_behind")
	player.head.rotation.x = - Player.PITCH_LIMIT
	await _wait(0.3)
	await _shot(out_dir, "jet_trail_below")
	Input.action_release("jump")
	await _side_shot(out_dir, from, to)


func _side_shot(out_dir: String, from: Vector3, to: Vector3) -> void:
	var mid:= (from + to) * 0.5
	var along:= Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var side:= along.cross(Vector3.UP).normalized()

	var eye:= mid + side * 6.0
	if Vector2(eye.x, eye.z).length() > Vector2(mid.x, mid.z).length():
		eye = mid - side * 6.0
	player.set_noclip(true)
	player.velocity = Vector3.ZERO
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT - 0.3, 0.0)
	var look:= mid - eye
	player.rotation = Vector3(0.0, atan2(- look.x, - look.z), 0.0)
	player.head.rotation.x = 0.0
	await _wait(0.05)
	await _shot(out_dir, "jet_trail_side")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out_dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [out_dir, shot_name]
	img.save_png(path)
	print("wrote %s" % path)
