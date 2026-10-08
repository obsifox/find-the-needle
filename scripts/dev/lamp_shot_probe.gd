class_name DevLampShotProbe
extends Node


const OUT_DIR:= "res://docs/work_lamp"


const LANE_X:= -13.0


const EYE:= Vector3(LANE_X, 1.7, 11.0)
const AIM:= Vector3(LANE_X, 1.2, -9.0)
const LAMP_Z:= 7.0


const LAMP2_Z:= -1.0
const PITCH:= -3.0

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame
	GameState.add_money(20000.0)

	await _aim(EYE, AIM, PITCH)
	await _frame("%s/bay_dark.png" % out_dir, "the lane with nothing in it")


	var one: WorkLamp = world.builds.add_work_lamp(
		Vector3(LANE_X, 0.0, LAMP_Z), PI)
	await _settle()
	await _frame("%s/bay_one_lamp.png" % out_dir, "one lamp")


	one.set_brightness(Cfg.WORK_LAMP_BRIGHT_MIN)
	await _settle()
	await _frame("%s/bay_dial_low.png" % out_dir, "one lamp, turned right down")
	one.set_brightness(1.0)
	await _settle()
	await _frame("%s/bay_dial_full.png" % out_dir, "one lamp, flat out")
	one.set_brightness(Cfg.WORK_LAMP_BRIGHT_DEFAULT)
	await _settle()

	world.builds.add_work_lamp(Vector3(LANE_X, 0.0, LAMP2_Z), PI)
	await _settle()
	await _frame("%s/bay_two_lamps.png" % out_dir, "two lamps")


	world.builds.clear()
	await _settle()
	world.builds.add_work_lamp(Vector3(LANE_X, 0.0, LAMP_Z), 0.0)
	await _settle()
	await _frame("%s/bay_lamp_turned.png" % out_dir, "one lamp, turned to face us")
	world.builds.clear()
	await _settle()
	one = world.builds.add_work_lamp(Vector3(LANE_X, 0.0, LAMP_Z), PI)
	await _settle()


	await _aim(one.global_position + Vector3(1.9, 1.55, 3.1),
		one.global_position + Vector3(0.0, 1.45, 0.0), 0.0)
	await _frame("%s/lamp_close.png" % out_dir, "the lamp itself")


	if player.lamp_panel != null:
		player.lamp_panel.open(one)
		await _settle()
		await _frame("%s/lamp_panel.png" % out_dir, "the panel")


		one.set_switched_off(true)
		player.lamp_panel._refresh()
		await _settle()
		await _frame("%s/lamp_panel_off.png" % out_dir, "the panel, switched off")
		one.set_switched_off(false)
		player.lamp_panel.close()

	get_tree().quit(0)


func _aim(at: Vector3, aim: Vector3, pitch: float) -> void:
	player.global_position = at
	player.look_at_from_position(at, aim, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = deg_to_rad(pitch)
	await _settle()


func _frame(path: String, what: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[lampshot] wrote %s  (%s)" % [path, what])


func _settle() -> void:
	for i in 6:
		await get_tree().process_frame
