class_name DevDetectorShotProbe
extends Node


const STAND:= Vector3(12.0, 0.0, 9.0)


const PITCH:= -32.0


const LEVEL_PITCH:= -6.0


const STEEP_PITCH:= -55.0


var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	Tech.reset()


	Tech.grant("cabinet", 1)
	Tech.grant("metal_detector", 1)
	GameState.grant_tool("metal_detector")


	player.scripted = true
	player.global_position = STAND
	player.look_at_from_position(STAND, STAND + Vector3(-1, 0, -1), Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	player.select_hotbar_slot(Player.TOOL_SLOTS.find(Player.Tool.DETECTOR))
	for _w in 60:
		await get_tree().process_frame


	await _shoot_at_pitch(out_dir, "detector_off.png", PITCH)
	player.detector.set_power(true)
	for _w in 40:
		await get_tree().process_frame

	await _shoot_at_pitch(out_dir, "detector_sweep.png", PITCH)


	player.detector.emit_ping()
	await _shoot_at_pitch(out_dir, "detector_ping.png", PITCH)
	await _shoot_at_pitch(out_dir, "detector_level.png", LEVEL_PITCH)
	await _shoot_at_pitch(out_dir, "detector_steep.png", STEEP_PITCH)


	player.set_look(player.rotation.y + deg_to_rad(35.0), deg_to_rad(PITCH))
	await _shoot_at_pitch(out_dir, "detector_turned.png", PITCH)

	get_tree().quit()


func _shoot_at_pitch(out_dir: String, name: String, pitch: float) -> void:
	player.set_look(player.rotation.y, deg_to_rad(pitch))
	for _w in 20:
		await get_tree().process_frame
	print("  %s: head %.2f m in front of the eye, %.2f m below it, gaze %.0f degrees"
		% [name, _head_ahead(), _head_below(), rad_to_deg(player.head.rotation.x)])
	await _snap(out_dir, name)


func _head_ahead() -> float:
	var local:= player.global_transform.affine_inverse() * player.detector.coil_position()
	return - local.z


func _head_below() -> float:
	return player.camera.global_position.y - player.detector.coil_position().y


func _snap(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
