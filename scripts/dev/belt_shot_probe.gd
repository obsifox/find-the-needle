class_name DevBeltShotProbe
extends Node


const EYE:= 1.9

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR

	var a:= Vector3(13.0, lift, -5.0)
	var b:= Vector3(13.0, lift, 1.0)
	GameState.add_money(20000.0)
	world.builds.add_conveyor(a, b)
	for i in 10:
		await get_tree().process_frame


	player.equip_build("belt")
	var tool: BuildTool = player.build
	tool._state = BuildTool.State.RUNNING
	tool._anchor = b
	await _look(out_dir, "belt_ghost_corner.png",
		b + Vector3(-3.4, EYE - lift, -3.0), b + Vector3(4.0, -0.2, 0.4))


	world.builds.add_conveyor(b, b + Vector3(6.0, 0.0, 0.0))
	tool._state = BuildTool.State.AIMING
	player.equip_build("hand")
	for i in 10:
		await get_tree().process_frame
	await _look(out_dir, "belt_corner_built.png",
		b + Vector3(-3.4, EYE - lift, -3.0), b + Vector3(2.0, -0.3, 0.4))


	var mid:= b + Vector3(0.3, 0.0, -0.3)
	await _look(out_dir, "belt_corner_close.png",
		mid + Vector3(1.05, 1.35 - lift, -1.05), mid, -34.0)


	var seam:= b - Vector3(0.0, 0.0, Cfg.BELT_CORNER_RADIUS)


	await _look(out_dir, "belt_corner_seam.png",
		seam + Vector3(0.8, 0.72, -0.85), seam, -31.0)


	var head:= b + Vector3(6.0, 0.0, 0.0)
	await _look(out_dir, "belt_head_drum.png",
		head + Vector3(1.15, 0.8 - lift, -1.3), head + Vector3(0.05, -0.13, 0.0))


	await _look(out_dir, "belt_tail_drum.png",
		a + Vector3(1.25, 0.8 - lift, -1.25), a + Vector3(0.0, -0.13, -0.1))

	get_tree().quit(0)


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3,
		pitch: float = -16.0) -> void:
	player.global_position = at
	player.look_at_from_position(at, target, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = deg_to_rad(pitch)


	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
