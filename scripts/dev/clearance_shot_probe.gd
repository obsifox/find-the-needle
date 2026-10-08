class_name DevClearanceShotProbe
extends Node


var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame


	if "--clean-board-shot" in OS.get_cmdline_user_args():
		for layer in world.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false

	var board: DeliveryBoard = world.delivery_board
	var card_at:= board.clearance_point()
	var out:= board.global_transform.basis * DeliveryBoard.face_normal()
	out.y = 0.0
	out = out.normalized()


	await _look(out_dir, "clearance_walkup.png",
		_stand_at(card_at, out, 3.2, 0.45), card_at)


	await _look(out_dir, "clearance_read.png",
		_stand_at(card_at, out, 1.5, 0.0), card_at + Vector3(0.0, 0.35, 0.0))


	await _look(out_dir, "clearance_lit.png",
		_stand_at(card_at, out, 1.5, 0.0), card_at)


	_build_something_worth_losing()
	for i in 10:
		await get_tree().process_frame
	world.sell_all_dialog.open(YardSale.tally(world.builds, world.props))
	await _look(out_dir, "clearance_panel.png",
		_stand_at(card_at, out, 2.6, 0.0), card_at)

	get_tree().quit(0)


func _build_something_worth_losing() -> void:
	var builds: BuildManager = world.builds
	var at:= Vector3(6.0, 0.0, 8.0)
	for i in 4:
		var from:= at + Vector3(0.0, 0.0, float(i) * 2.2)
		builds.add_conveyor(from, from + Vector3(5.5, 0.0, 0.0))
	builds.add_platform(at + Vector3(9.0, 1.2, 3.0), Vector2(4.0, 4.0))
	builds.add_compressor(at + Vector3(-4.0, 0.0, 2.0), 0.0)


	builds.add_scanner(at + Vector3(-4.0, 0.0, 7.0), 0.0).banked.append(0)
	world.props.spawn("bucket", Transform3D(Basis.IDENTITY, at + Vector3(2.0, 0.4, -2.0)))
	world.props.spawn("spade", Transform3D(Basis.IDENTITY, at + Vector3(3.0, 0.4, -2.4)))


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	_aim(target)
	for i in 6:
		await get_tree().process_frame
	_aim(target)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


static func _stand_at(card_at: Vector3, out: Vector3, back: float,
		aside: float) -> Vector3:
	var spot:= card_at + out * back + out.cross(Vector3.UP) * aside
	spot.y = card_at.y - 1.08
	return spot


func _aim(target: Vector3) -> void:
	var to_target:= target - player.eye_position()
	player.set_look(atan2(- to_target.x, - to_target.z),
		atan2(to_target.y, Vector2(to_target.x, to_target.z).length()))
