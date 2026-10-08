class_name DevHeapShotProbe
extends Node


const EYE_DIR:= Vector3(0.94, 0.0, 0.34)
const EYE_BACK:= 1.05
const EYE_UP:= 0.62

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	Tech.grant_legacy()
	for i in 30:
		await get_tree().process_frame

	DirAccess.make_dir_recursive_absolute(out_dir)
	var props: PropManager = world.props


	var at:= Vector3(13.0, 0.0, 0.0)

	for kind: String in ["bucket", "wheelbarrow"]:
		var box:= props.spawn(kind, Transform3D(Basis.IDENTITY, at)) as HayContainer
		if box == null:
			push_warning("heapshot: could not place a %s" % kind)
			continue


		box.freeze = true


		var mouth: Vector3 = box.global_position + box._mouth_centre * box.size_scale()

		for shot: Array in [["half", 0.5], ["nearly", 0.86], ["full", 1.0]]:
			box.stored = int(round(float(box.capacity()) * float(shot [1])))
			box._refresh_fill()
			await _look(out_dir, "%s_%s.png" % [kind, shot [0]], mouth, EYE_BACK)


		FullBadge.flash_over(box, box.badge_point())
		await _look(out_dir, "%s_badge.png" % kind, mouth, EYE_BACK)

		props.remove(box)
		await get_tree().process_frame

	print("[heapshot] written to %s" % out_dir)
	get_tree().quit()


func _look(out_dir: String, shot: String, target: Vector3, back: float) -> void:
	player.set_physics_process(false)
	var lift: float = EYE_UP if back <= EYE_BACK else back * 0.28
	var at:= target + EYE_DIR.normalized() * back + Vector3.UP * lift
	var flat:= Vector2(target.x - at.x, target.z - at.z).length()
	player.set_look(atan2(target.x - at.x, target.z - at.z) + PI,
		atan2(target.y - at.y, maxf(flat, 0.001)))
	player.global_position = at
	for pass_i in 3:
		for i in 4:
			await get_tree().process_frame
		player.global_position += at - player.camera.global_position
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
