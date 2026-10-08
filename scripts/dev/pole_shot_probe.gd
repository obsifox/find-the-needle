class_name DevPoleShotProbe
extends Node


const OUT_DIR:= "user://poleshot"


const LANE_X:= 13.0

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame
	GameState.add_money(20000.0)

	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = world.builds.add_power_pole(Vector3(LANE_X + 2.5, 0.0, 0.0), 0.0)
	var deck:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	world.builds.add_compressor(Vector3(LANE_X, deck, -3.0), 0.0)
	world.builds.add_compressor(Vector3(LANE_X, deck, 3.0), 0.0)
	await _settle(40)

	var at:= pole.global_position + Vector3(-2.5, 0.0, 2.5)
	player.global_position = at
	player.look_at_from_position(at, pole.global_position, Vector3.UP)
	player.rotation.x = 0.0
	await _settle(10)

	if player.pole_panel != null:
		player.pole_panel.open(pole)
		await _settle(10)
		await _frame("%s/pole_panel.png" % out_dir, "the line running")
		player.pole_panel._on_switch()
		await _settle(10)
		await _frame("%s/pole_panel_off.png" % out_dir, "the whole line switched off")
		player.pole_panel._on_switch()
		player.pole_panel._on_pole_switch()
		await _settle(10)
		await _frame("%s/pole_panel_pole_off.png" % out_dir, "only this pole's machines off")
		player.pole_panel.close()

	get_tree().quit(0)


func _frame(path: String, what: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[poleshot] wrote %s  (%s)" % [ProjectSettings.globalize_path(path), what])


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
