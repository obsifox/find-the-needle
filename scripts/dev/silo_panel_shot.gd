class_name DevSiloPanelShot
extends Node


var world: Node3D


const SILO_AT:= Vector3(13.0, 0.06, 5.0)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--silopanelshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var builds: BuildManager = world.builds
	var tank:= builds.add_silo(SILO_AT, 0.0)
	var panel: SiloPanel = world.get("silo_panel")
	if panel == null:
		push_error("[silopanelshot] the world stood up no SiloPanel")
		get_tree().quit(1)
		return
	for _i in 12:
		await get_tree().process_frame


	tank.set_rate_per_minute(180.0)
	tank.stored = Tech.silo_wad_strands() * 74
	for i in 26:
		tank.queued.append({ "id": "hay_bale", "state": { "strands": 60 } })
	for i in 9:
		tank.queued.append({ "id": "foiled_bale", "state": { "strands": 60 } })
	tank.pending_needles.append(3)
	await _shot(panel, tank, "%s/silo_panel_running.png" % out_dir)


	tank.stop()
	await _shot(panel, tank, "%s/silo_panel_stopped.png" % out_dir)


	tank.start()
	tank.set_rate_per_minute(tank.rate_max_per_minute())
	tank.pending_needles = PackedInt32Array()
	tank.queued.clear()
	tank.stored = 0
	for i in tank.capacity():
		tank.queued.append({ "id": "hay_wad", "state": { "strands": 20 } })
	await _shot(panel, tank, "%s/silo_panel_full.png" % out_dir)


	tank.queued.clear()
	tank.stored = 0
	tank.set_rate_per_minute(Cfg.SILO_RATE_DEFAULT * 60.0)
	await _shot(panel, tank, "%s/silo_panel_empty.png" % out_dir)
	panel.close()


	for want: float in [10.0, 180.0, 300.0]:
		tank.set_rate_per_minute(want)
		await _door(tank, "%s/silo_door_%d.png" % [out_dir, int(want)])

	get_tree().quit()


func _door(tank: HaySilo, path: String) -> void:
	var player: Player = world.get("player")
	if player == null:
		return
	var console:= tank.console_position()
	var eye:= console + Vector3(0.95, 0.05, 0.0)
	var stand:= eye - Vector3.UP * (player.head.position.y if player.head != null else 1.6)
	player.global_position = stand


	player.look_at_from_position(stand, console, Vector3.UP)
	player.rotation.x = 0.0
	var to_aim:= console - eye
	player.set_look(player.rotation.y,
		atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))
	for _i in 4:
		await get_tree().physics_frame
	await _capture(path)
	print("[silopanelshot] %s  display says %d" % [
		path.get_file(), int(round(tank.rate_per_minute()))])


func _shot(panel: SiloPanel, tank: HaySilo, path: String) -> void:
	panel.close()
	panel.open(tank)


	for _i in 3:
		await get_tree().physics_frame
	await _capture(path)
	print("[silopanelshot] %s  %d of %d, %.0f a minute" % [
		path.get_file(), tank.held(), tank.capacity(), tank.rate_per_minute()])


func _capture(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
