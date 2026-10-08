class_name DevArmShotProbe
extends Node


var world: Node3D
var player: Player

var _cam: Camera3D


const ARM_AT:= Vector3(13.0, 0.06, 5.0)


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

	player.global_position = ARM_AT + Vector3(-4.0, 0.4, -4.0)
	GameState.add_money(60000.0)
	for i in 40:
		await get_tree().physics_frame

	var arm: RoboticArm = world.builds.add_robotic_arm(ARM_AT, 0.0)
	for i in 60:
		await get_tree().physics_frame

	var base:= arm.global_position
	await _look(out_dir, "arm_walkup.png",
		base + Vector3(-3.4, 2.3, -3.4), base + Vector3(0.0, 1.3, 0.0), 52.0)
	await _look(out_dir, "arm_boom.png",
		base + Vector3(-1.35, 2.05, -1.35), base + Vector3(0.0, 1.75, 0.0), 44.0)
	await _look(out_dir, "arm_shoulder.png",
		base + Vector3(-0.95, 1.55, -0.95), base + Vector3(0.0, 1.1, 0.0), 40.0)
	await _look(out_dir, "arm_claws.png",
		base + Vector3(-1.1, 1.05, -1.1), base + Vector3(-0.45, 0.75, -0.45), 38.0)
	await _look(out_dir, "arm_mast.png",
		base + Vector3(-1.6, 2.6, -1.6), base + Vector3(-0.2, 2.1, -0.2), 42.0)
	await _look(out_dir, "arm_in_place.png",
		base + Vector3(-5.5, 1.7, -5.5), base + Vector3(0.0, 1.05, 0.0), 58.0)

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
	print("[armshot] wrote %s" % path)
