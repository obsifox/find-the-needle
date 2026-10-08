class_name DevShredShotProbe
extends Node


const SETTLE_FRAMES:= 40


const AT:= Vector3(13.0, 0.4, 4.0)

var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in SETTLE_FRAMES:
		await get_tree().process_frame
	player.global_position = AT + Vector3(-3.0, 0.0, 0.0)
	for _w in SETTLE_FRAMES:
		await get_tree().process_frame

	var props: PropManager = world.props
	var roll: PaperRoll = props.spawn("paper_roll",
		Transform3D(Basis(), AT)) as PaperRoll
	if roll == null:
		print("[shredshot] could not spawn a roll")
		get_tree().quit(1)
		return


	for _w in SETTLE_FRAMES * 2:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()


	var eye:= AT + Vector3(-1.85, 1.05, 1.85)
	var aim:= AT + Vector3(0.0, 0.3, 0.0)

	await _snap(out_dir, "shred_0_before.png", eye, aim)
	props.rip(roll)


	await _snap(out_dir, "shred_1_burst.png", eye, aim)
	await _hold(ShredBurst.LIFETIME * 0.45)
	await _snap(out_dir, "shred_2_open.png", eye, aim)
	await _hold(ShredBurst.LIFETIME * 0.75)
	await _snap(out_dir, "shred_3_gone.png", eye, aim)

	print("[shredshot] done")
	get_tree().quit()


func _hold(seconds: float) -> void:
	var left:= seconds
	while left > 0.0:
		left -= get_process_delta_time()
		await get_tree().process_frame


func _snap(out_dir: String, shot_name: String, at: Vector3, aim: Vector3) -> void:
	_cam.look_at_from_position(at, aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, shot_name]
	img.save_png(path)
	print("wrote %s" % path)
