class_name DevLighterShotProbe
extends Node


var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.8)
	if Cfg.DEMO:
		print("[lightershot] the demo has no lighter: run with --full")
		get_tree().quit(1)
		return
	Tech.grant("lighter", 1)
	GameState.grant_tool("lighter")
	player.capture_mouse(true)

	var slab:= Vector3(13.4, 0.05, 8.0)
	_stand_at(slab + Vector3(-2.0, 0.0, 0.0), Vector3(1, 0, 0))
	player.head.rotation.x = -0.12
	player._set_tool(Player.Tool.LIGHTER)
	await _wait(1.5)
	var l:= player.lighter

	l.debug_hold("open", 0.0)
	await _wait(0.3)
	await _shot(out_dir, "lighter_closed")
	l.debug_hold("open", 0.9)
	await _wait(0.3)
	await _shot(out_dir, "lighter_open")
	l.debug_hold("burn", 1.5)
	await _wait(0.3)
	await _shot(out_dir, "lighter_burning")

	await _case_shots(out_dir)

	l.debug_hold("open", 0.9)
	_scatter(slab)
	await _wait(1.2)
	_stand_at(slab + Vector3(-2.3, 0.0, 0.0), Vector3(1, 0, 0))
	_look_at(slab)
	l.debug_clear_cooldown()
	l.light_at(slab)
	await _wait(1.2)
	await _shot(out_dir, "fire_early")
	_stand_at(slab + Vector3(-3.6, 0.0, 0.0), Vector3(1, 0, 0))
	_look_at(slab + Vector3(0.0, 0.4, 0.0))
	await _wait(3.0)
	await _shot(out_dir, "fire_full")
	await _wait(7.0)
	await _shot(out_dir, "fire_scorch")

	player._set_tool(Player.Tool.HAND)
	var props: PropManager = world.props


	var at:= slab + Vector3(0.0, 0.2, -2.0)
	props.spawn("lighter", Transform3D(Basis.IDENTITY, at))
	_stand_at(at + Vector3(-0.9, 0.0, 0.0), Vector3(1, 0, 0))
	await _wait(1.0)
	_look_at(at + Vector3(0.0, -0.2, 0.0))
	await _wait(0.4)
	await _shot(out_dir, "lighter_prop")
	get_tree().quit()


func _case_shots(out_dir: String) -> void:
	player.lighter.visual.visible = false
	player.head.rotation.x = 0.0
	var packed: PackedScene = load(Lighter.MODEL_PATH)
	var inst: Node3D = packed.instantiate()
	player.camera.add_child(inst)
	Lighter.skin(inst)
	var ap:= inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		var src:= Lighter.source_clip(ap)
		if src != null:
			Lighter.apply_frame(ap, src, 2.0)
		ap.get_parent().remove_child(ap)
		ap.free()
	for face: Array in [["case_a", 0.0], ["case_b", PI]]:


		inst.transform = Transform3D(Basis.from_euler(Vector3(0.0, float(face [1]) + 0.85, 0.0))
			.scaled(Vector3.ONE * 2.2), Vector3(0.0, -0.12, -0.32))
		await _wait(0.3)
		await _shot(out_dir, str(face [0]))
	inst.queue_free()
	player.lighter.visual.visible = true


func _scatter(at: Vector3) -> void:
	var props: PropManager = world.props
	var live: LiveStrandManager = world.live
	for i in 3:
		props.spawn("hay_tuft", Transform3D(Basis.IDENTITY,
			at + Vector3(0.25 * float(i - 1), 0.1, 0.2 * float(i % 2))), { "strands": 80 })
	var rng:= RandomNumberGenerator.new()
	rng.seed = 9
	for i in 120:
		live.spawn(at + Vector3(rng.randf_range(-0.5, 0.5), 0.1 + rng.randf() * 0.1,
			rng.randf_range(-0.5, 0.5)), StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))


func _stand_at(pos: Vector3, facing: Vector3) -> void:
	player.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, atan2(- facing.x, - facing.z), 0.0)


func _look_at(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation = Vector3(0.0, atan2(- to.x, - to.z), 0.0)
	player.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.5, 1.5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out_dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [out_dir, shot_name]
	img.save_png(path)
	print("wrote %s" % path)
