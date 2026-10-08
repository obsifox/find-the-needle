class_name DevGenPanelShotProbe
extends Node


const OUT_DIR:= "user://genpanelshot"


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
	world.builds.add_compressor(Vector3(LANE_X, deck, 0.0), 0.0)
	world.builds.add_compressor(Vector3(LANE_X, deck, 3.0), 0.0)
	await _settle(40)

	var at:= gen.global_position + Vector3(-3.0, 0.0, 3.0)
	player.global_position = at
	player.look_at_from_position(at, gen.global_position, Vector3.UP)
	player.rotation.x = 0.0
	await _settle(10)

	var panel: MachinePanel = world.machine_panel
	if panel != null:
		panel.open(gen)
		await _settle(20)
		await _frame("%s/gen_panel_short.png" % out_dir, "three presses on the line")


		panel.set_process(false)
		var rows: PackedStringArray = []
		for i in 48:
			rows.append("%s\t%.1f kW" % ["robotic arm", 4.0])
		for i in 8:
			rows.append("%s\t%.1f kW" % ["piston rake", 4.0])
		for i in 9:
			rows.append("%s\t%.1f kW" % ["hay wrapper", 1.8])
		for i in 9:
			rows.append("%s\t%.1f kW" % ["haystack scanner", 0.6])
		for i in 26:
			rows.append("%s\t%.1f kW" % ["hay compressor  (off)", 0.0])
		panel._write_draws(rows)
		await _settle(10)
		await _frame("%s/gen_panel_long.png" % out_dir, "a hundred rows, at the top")
		var bar:= panel._draws_scroll.get_v_scroll_bar()
		panel._draws_scroll.scroll_vertical = int(bar.max_value * 0.5)
		await _settle(10)
		await _frame("%s/gen_panel_long_scrolled.png" % out_dir, "a hundred rows, scrolled halfway")
		panel.close()

	get_tree().quit(0)


func _frame(path: String, what: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[genpanelshot] wrote %s  (%s)" % [ProjectSettings.globalize_path(path), what])


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
