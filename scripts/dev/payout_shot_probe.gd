class_name DevPayoutShotProbe
extends Node


var world: Node3D
var player: Player
var stand: HaySellingStand
var _fails:= 0


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var dial:= stand._find("Scale_Dial") as VisualInstance3D
	var target:= stand._popup_at - Vector3(0, HaySellingStand.POPUP_UP, 0)
	var face:= Vector3(stand._coins_face.x, 0.0, stand._coins_face.z)
	if dial != null:
		target = dial.global_transform * dial.get_aabb().get_center()
	if face.length() < 0.01:
		face = stand.global_transform.basis.z
	face = face.normalized()

	await _place(target + face * 0.9 + Vector3.UP * 0.05, target)
	stand._celebrate(12.5, 0)
	await get_tree().create_timer(0.35).timeout
	_check("close payout", stand._popups)
	await _snap(out_dir, "payout_close.png")
	await get_tree().create_timer(1.6).timeout

	stand._celebrate(48.0, 0, true)
	await get_tree().create_timer(0.24).timeout
	_check("close best", [stand._best])
	await _snap(out_dir, "best_close_glint.png")
	await get_tree().create_timer(0.34).timeout
	await _snap(out_dir, "best_close_glint2.png")
	await get_tree().create_timer(0.9).timeout
	await _snap(out_dir, "best_close_gold.png")
	await get_tree().create_timer(1.6).timeout

	await _place(target + face * 5.0 + Vector3.UP * 0.6, target + Vector3.UP * 0.8)
	stand._celebrate(12.5, 0)
	await get_tree().create_timer(0.35).timeout
	var far:= stand._popup_place()
	print("[payoutshot] far place %.2v, anchor %.2v" % [far [0], stand._popup_at])
	if not (far [0] as Vector3).is_equal_approx(stand._popup_at):
		print("[payoutshot] FAIL far payout was moved off the plate")
		_fails += 1
	await _snap(out_dir, "payout_far.png")
	await get_tree().create_timer(1.6).timeout
	stand._celebrate(48.0, 0, true)
	await get_tree().create_timer(0.6).timeout
	await _snap(out_dir, "best_far.png")

	print("[payoutshot] %s" % ("PASS" if _fails == 0 else "FAIL %d" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(what: String, labels: Array) -> void:
	var cam:= get_viewport().get_camera_3d()
	for l: Label3D in labels:
		if l == null or not l.visible:
			continue
		var seen:= cam.is_position_in_frustum(l.global_position)
		print("[payoutshot] %s: %s at %.2v, %.2f m from the eye, scale %.2f, %s"
			% [what, l.name, l.global_position,
			l.global_position.distance_to(cam.global_position), l.scale.x,
			"in view" if seen else "OUT OF VIEW"])
		if not seen:
			_fails += 1


func _place(at: Vector3, target: Vector3) -> void:
	player.set_physics_process(false)
	var flat:= Vector2(target.x - at.x, target.z - at.z).length()
	player.set_look(atan2(target.x - at.x, target.z - at.z) + PI,
		atan2(target.y - at.y, maxf(flat, 0.001)))
	player.global_position = at
	for _pass in 3:
		for i in 4:
			await get_tree().process_frame
		player.global_position += at - player.camera.global_position
	for i in 4:
		await get_tree().process_frame


func _snap(out_dir: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
