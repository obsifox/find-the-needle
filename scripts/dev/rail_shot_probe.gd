class_name DevRailShotProbe
extends Node


const EYE:= 1.9

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR

	var joint:= Vector3(13.0, lift, 0.0)
	var west:= joint + Vector3(0.0, 0.0, -5.0)


	var out_end:= joint + Vector3(4.0, 0.0, 4.0)
	var north:= joint + Vector3(5.0, 0.0, 0.0)
	GameState.add_money(20000.0)
	world.builds.add_conveyor(west, joint)
	world.builds.add_conveyor(joint, out_end)
	world.builds.add_conveyor(north, joint)
	for i in 20:
		await get_tree().process_frame


	var eye:= joint + Vector3(2.4, EYE - lift - 0.85, -2.2)
	await _look(out_dir, "rail_junction_open.png", eye, joint)


	var shut: Array [Dictionary] = []
	for c in world.builds.conveyors:
		c.set_rail_windows(shut.duplicate())


	for k in world.builds.corners:
		k.set_rail_windows(shut.duplicate())
	for i in 10:
		await get_tree().process_frame
	await _look(out_dir, "rail_junction_closed.png", eye, joint)


	world.builds.clear()
	for i in 20:
		await get_tree().process_frame
	var turn_a:= Vector3(20.0, lift, -4.0)
	var turn_b:= Vector3(20.0, lift, 0.0)
	var turn_c:= turn_b + Vector3(1.05, 0.0, 0.0)
	world.builds.add_conveyor(turn_a, turn_b)
	world.builds.add_conveyor(turn_b, turn_c)
	world.builds.add_conveyor(turn_c, turn_c + Vector3(0.0, 0.0, -4.0))
	for i in 20:
		await get_tree().process_frame
	var over:= Vector3(turn_b.x + 0.5, lift + 0.6, turn_b.z + 2.2)
	await _look(out_dir, "rail_switchback.png", over,
		Vector3(turn_b.x + 0.5, lift, turn_b.z - 0.3), -46.0)

	get_tree().quit(0)


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3,
		pitch:= -20.0) -> void:
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
