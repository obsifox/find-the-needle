class_name DevArmLoadShotProbe
extends Node


var world: Node3D
var player: Player


const STAND:= Vector3(13.2, 0.4, 5.6)

var _made: Array [Carryable] = []


func shoot(out_dir: String) -> void:
	world.block_save = true
	Tech.grant("arm_load", TechTree.max_rank("arm_load"))
	for i in 40:
		await get_tree().process_frame

	await _pile(["hay_wad"])
	await _look(out_dir, "armload_1_wad.png")
	await _pile(["hay_wad", "hay_wad", "hay_wad"])
	await _look(out_dir, "armload_3_wads.png")
	await _pile(["hay_bale", "hay_bale", "hay_bale", "hay_bale", "hay_bale"])
	await _look(out_dir, "armload_5_bales.png")
	await _look(out_dir, "armload_5_bales_down.png", -35.0)
	await _aside(out_dir, "armload_5_bales_aside.png", Vector3(2.6, 0.9, -1.8))
	await _pile(["hay_wad", "hay_bale", "foiled_bale", "eco_brick", "feed_disc"])
	await _look(out_dir, "armload_5_mixed.png")

	Tech.grant("arm_load", 0)
	get_tree().quit(0)


func _pile(kinds: Array) -> void:
	var props: PropManager = world.props
	player.carry.drop_all()
	for it in _made:
		if is_instance_valid(it):
			props.remove(it)
	_made.clear()
	player.global_position = STAND
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 4:
		await get_tree().process_frame
	for i in kinds.size():
		var item:= props.spawn(str(kinds [i]),
			Transform3D(Basis(), STAND + Vector3(3.0 + float(i), 0.6, 0.0)),
			{ "strands": 60 })
		if item == null:
			continue
		_made.append(item)
		if i == 0:
			player.carry.take(item)
		else:
			player.carry.stack_on(item)
	for i in 10:
		await get_tree().process_frame


func _look(out_dir: String, shot: String, pitch: float = -8.0) -> void:
	player.global_position = STAND
	player.rotation = Vector3.ZERO
	if player.head != null:
		player.head.rotation.x = deg_to_rad(pitch)
	if player.camera != null:
		player.camera.make_current()


	for i in 6:
		await get_tree().process_frame
	await _write(out_dir, shot)


func _aside(out_dir: String, shot: String, from: Vector3) -> void:
	player.global_position = STAND
	player.rotation = Vector3.ZERO
	if player.head != null:
		player.head.rotation.x = 0.0
	for i in 6:
		await get_tree().process_frame
	var cam:= Camera3D.new()
	world.add_child(cam)
	var at:= STAND + from
	cam.look_at_from_position(at, player.eye_position() + Vector3(0.5, 0.2, 0.0),
		Vector3.UP)
	cam.make_current()
	for i in 4:
		await get_tree().process_frame
	await _write(out_dir, shot)
	cam.queue_free()
	if player.camera != null:
		player.camera.make_current()


func _write(out_dir: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
