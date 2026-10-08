class_name DevPaperShotProbe
extends Node


const LANE_X:= 13.0
const SETTLE_FRAMES:= 40

var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in SETTLE_FRAMES:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	for _w in SETTLE_FRAMES:
		await get_tree().process_frame

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mill: PaperMachine = world.builds.add_paper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	for _w in SETTLE_FRAMES * 2:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()

	var out:= mill.port_out()
	var into:= mill.port_in()
	print("[papershot] outfeed face %s, mouth %s" % [out, into])


	await _snap_from(out_dir, "paper_outfeed.png",
		out + Vector3(2.3, 1.35, 2.2), out + Vector3(0.0, 0.15, -0.6))


	await _snap_from(out_dir, "paper_outfeed_face.png",
		out + Vector3(0.55, 0.55, 1.9), out + Vector3(0.0, 0.02, -0.3))

	await _snap_from(out_dir, "paper_mouth.png",
		into + Vector3(2.3, 1.35, -2.2), into + Vector3(0.0, 0.15, 0.6))


	await _snap_from(out_dir, "paper_wide.png",
		mill.global_position + Vector3(6.4, 3.2, 6.2),
		mill.global_position + Vector3(0.0, 0.8, 0.6))

	print("[papershot] done")
	get_tree().quit()


func _snap_from(out_dir: String, name: String, at: Vector3,
		aim: Vector3) -> void:
	_cam.look_at_from_position(at, aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
