class_name DevPipeShotProbe
extends Node


const LANE_X:= 13.0

var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in 40:
		await get_tree().process_frame
	player.global_position = Vector3(9.0, 0.4, 4.0)
	GameState.add_money(200000.0)
	for _w in 30:
		await get_tree().process_frame

	var deck_y:= Cfg.PIPE_RUN_HEIGHT
	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	var pump: BoreholePump = world.builds.add_borehole(
		Vector3(LANE_X, 0.0, -9.5), PI)
	for _w in 60:
		await get_tree().physics_frame

	var inlet: Vector3 = pulper.water_port()
	var outlet: Vector3 = pump.water_port()
	print("  pulper inlet %s   pump outlet %s" % [inlet, outlet])
	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)
	tool._lay_pipe(outlet, inlet)
	tool.cancel()
	for _w in 60:
		await get_tree().physics_frame
	for run in world.builds.water_mains:
		print("  run %s -> %s  trim %.2f  bend %.2f  joined %s" % [run.a, run.b,
			run.trim_start, run.bend_tangent, run.joined_start])

	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()


	await _snap(out_dir, "pipe_inlet.png",
		inlet + Vector3(-2.3, 1.1, 1.7), inlet + Vector3(-0.4, -0.1, 0.0))
	await _snap(out_dir, "pipe_inlet_wide.png",
		inlet + Vector3(-2.6, 3.0, -5.0), inlet + Vector3(-1.0, 0.0, 0.0))
	await _snap(out_dir, "pipe_outlet.png",
		outlet + Vector3(2.4, 1.2, 1.6), outlet + Vector3(0.0, -0.1, 0.6))
	await _snap(out_dir, "pipe_line.png",
		Vector3(LANE_X - 3.5, 6.5, -2.0), Vector3(LANE_X - 0.5, 0.6, -3.0))

	print("[pipeshot] done")
	get_tree().quit()


func _snap(out_dir: String, name: String, at: Vector3, aim: Vector3) -> void:
	_cam.look_at_from_position(at, aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
