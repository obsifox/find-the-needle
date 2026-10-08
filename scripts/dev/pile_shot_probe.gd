class_name DevPileShotProbe
extends Node


var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	var inner: float = world.warehouse.inner
	var h: float = Cfg.PILE_HEIGHT
	print("[pileshot] %s: %.0f m of hay, %.1f m footprint, walls at %.1f m"
		% [Cfg.pile_size_id, h, Cfg.settled_footprint(), inner])


	await _look(out_dir, "pile_%s_inside.png" % Cfg.pile_size_id,
		Vector3(inner - 1.5, clampf(h * 0.5, 1.7, 8.5), inner - 1.5),
		Vector3(0.0, h * 0.35, 0.0))


	var toe: float = Cfg.settled_footprint()


	await _look(out_dir, "pile_%s_toe.png" % Cfg.pile_size_id,
		Vector3(toe * 0.75, 2.2, toe * 0.75 + 6.0),
		Vector3(toe * 0.62, 0.6, 0.0))


	_show_layers(true, false)
	await _look(out_dir, "pile_%s_toe_crust.png" % Cfg.pile_size_id,
		Vector3(toe * 0.75, 2.2, toe * 0.75 + 6.0),
		Vector3(toe * 0.62, 0.6, 0.0))
	_show_layers(false, true)
	await _look(out_dir, "pile_%s_toe_shells.png" % Cfg.pile_size_id,
		Vector3(toe * 0.75, 2.2, toe * 0.75 + 6.0),
		Vector3(toe * 0.62, 0.6, 0.0))
	_show_layers(true, true)


	await _look(out_dir, "pile_%s_outside.png" % Cfg.pile_size_id,
		Vector3(inner + h * 1.6 + 22.0, maxf(h * 0.85, 14.0), inner + h * 1.6 + 22.0),
		Vector3(0.0, h * 0.4, 0.0))
	get_tree().quit(0)


func _show_layers(crust: bool, shells: bool) -> void:
	var field: HayField = world.get_node("HayField")
	for c: HayChunk in field.chunks:
		if c._mmi != null:
			c._mmi.visible = crust
		if c._surf_mi != null:
			c._surf_mi.visible = shells


func _look(out_dir: String, name: String, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	player.look_at_from_position(at, target, Vector3.UP)


	var pitch:= atan2(target.y - at.y, Vector2(target.x - at.x, target.z - at.z).length())
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = pitch
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("[pileshot] wrote %s" % path)
