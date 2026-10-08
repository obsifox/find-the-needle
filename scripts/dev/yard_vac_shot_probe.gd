class_name DevYardVacShotProbe
extends Node


const OUT:= ["vac_idle", "vac_suck", "vac_floor", "vac_full", "vac_pour"]


const FLOOR_HAY:= 90

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true


	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.8)

	Tech.grant_legacy()
	Tech.grant("yard_vac", 1)
	GameState.grant_tool("yard_vac")
	player.capture_mouse(true)

	var field: HayField = world.field


	var r:= 0.0
	for i in 60:
		var probe:= 9.5 - float(i) * 0.1
		if field.height_at(probe, 0.0) > 0.6:
			r = probe
			break
	var face:= Vector3(r, field.height_at(r, 0.0), 0.0)
	var stand:= Vector3(r + 1.6, 0.0, 0.0)
	stand.y = field.height_at(stand.x, stand.z)
	_stand_at(stand, (face - stand) * Vector3(1, 0, 1))
	player._set_tool(Player.Tool.YARD_VAC)
	var vac:= player.yard_vac
	vac.clear()


	player.head.rotation.x = -0.1
	await _wait(0.5)
	await _shot(out_dir, "vac_idle")


	_look_at(face)
	vac.set_sucking(true)
	await _wait(1.2)
	await _shot(out_dir, "vac_suck")


	vac.set_sucking(false)
	vac.clear()
	var slab:= Vector3(13.4, 0.05, 8.0)
	_stand_at(Vector3(slab.x - 1.2, 0.0, slab.z), Vector3(1, 0, 0))
	_look_at(slab)
	_scatter(slab)
	await _wait(0.8)
	vac.set_sucking(true)
	await _wait(0.9)
	await _shot(out_dir, "vac_floor")
	vac.set_sucking(false)


	vac.set_sucking(false)
	vac.debug_fill(Tech.vac_capacity())
	await _wait(0.4)
	await _shot(out_dir, "vac_full")


	_stand_at(Vector3(slab.x - 1.2, 0.0, slab.z), Vector3(1, 0, 0))
	player._set_tool(Player.Tool.YARD_VAC)
	player.head.rotation.x = -0.55
	vac.set_pouring(true)
	await _wait(1.0)
	await _shot(out_dir, "vac_pour")
	vac.set_pouring(false)

	get_tree().quit()


func _scatter(at: Vector3) -> void:
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210
	for i in FLOOR_HAY:
		var p:= at + Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * 0.1,
			rng.randf_range(-0.45, 0.45))
		live.spawn(p, StrandFactory.random_strand_basis(rng), Vector3.ZERO,
			StrandFactory.random_tint(rng))


func _stand_at(pos: Vector3, facing: Vector3) -> void:
	player.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, atan2(- facing.x, - facing.z), 0.0)


func _look_at(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()),
		-1.5, 1.5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out_dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [out_dir, shot_name]
	img.save_png(path)
	print("wrote %s" % path)
