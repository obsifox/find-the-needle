class_name DevChargePostShotProbe
extends Node


var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.near = 0.02
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true

	for i in 90:
		await get_tree().process_frame


	var pad:= Vector3(12.0, 0.02, -7.0)
	player.global_position = pad + Vector3(-4.0, 0.4, -4.0)
	GameState.add_money(40000.0)
	for i in 40:
		await get_tree().physics_frame

	var drone: HayDrone = world.builds.add_hay_drone(pad, 0.0)


	drone.power_ports()
	drone.set_power(1.0)
	for i in 40:
		await get_tree().physics_frame

	var post:= pad + Vector3(HayDrone.POST_RADIUS, 0.0, 0.0)
	var box:= post + Vector3(-0.135, 0.76, 0.0)


	await _look(out_dir, "post_walkup.png",
		post + Vector3(-0.55, 1.0, -1.55), post + Vector3(0.0, 0.62, 0.0), 48.0)
	await _look(out_dir, "post_box.png",
		post + Vector3(-0.6, 0.9, -0.44), box, 42.0)
	await _look(out_dir, "post_base.png",
		post + Vector3(-0.62, 0.34, -0.52), post + Vector3(0.0, 0.09, 0.0), 42.0)


	drone.set_switched_off(true)
	for i in 6:
		await get_tree().process_frame
	await _look(out_dir, "post_box_dark.png",
		post + Vector3(-0.6, 0.9, -0.44), box, 42.0)
	drone.set_switched_off(false)
	for i in 6:
		await get_tree().process_frame

	await _look(out_dir, "post_in_place.png",
		pad + Vector3(-2.6, 1.75, -3.1), pad + Vector3(0.6, 0.55, 0.0), 55.0)

	get_tree().quit(0)


func _look(out_dir: String, shot: String, eye: Vector3, target: Vector3,
		fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, target, Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("[postshot] wrote %s" % path)
