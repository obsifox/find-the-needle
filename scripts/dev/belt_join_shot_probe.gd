class_name DevBeltJoinShotProbe
extends Node


const EYE:= 1.9

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR


	var x:= 13.0
	var a:= Vector3(x, lift, -6.0)
	var b:= Vector3(x, lift, -2.0)
	var c:= Vector3(x, lift, 1.4)
	var d:= Vector3(x, lift, 2.8)


	var e:= d + Vector3(3.0, 0.0, 3.0)
	GameState.add_money(20000.0)
	for pair in [[a, b], [b, c], [c, d], [d, e]]:
		world.builds.add_conveyor(pair [0], pair [1])
		var span: float = pair [0].distance_to(pair [1])
		var n:= maxi(1, int(round(span / Cfg.BELT_SEGMENT)))
		print("[beltjoin] %.2f m -> %d sections drawn at %.3f"
			% [span, n, span / float(n) / Cfg.BELT_SEGMENT])
	for i in 20:
		await get_tree().process_frame
	for run: Conveyor in world.builds.conveyors:
		var drums:= run.get_node_or_null("Drums")
		print("[beltjoin] %s trims %.3f/%.3f drums=%d"
			% [run.name, run.trim_start, run.trim_end,
			0 if drums == null else drums.get_child_count()])
	print("[beltjoin] corners fitted: %d" % world.builds.corners.size())


	await _look(out_dir, "join_over_1000_1133.png",
		b + Vector3(-0.55, 0.78, -0.62), b)
	await _look(out_dir, "join_over_1133_1400.png",
		c + Vector3(-0.55, 0.78, -0.62), c)


	await _look(out_dir, "join_side_straight.png",
		Vector3(b.x - 1.25, 0.0, b.z - 0.95), b)


	await _look(out_dir, "join_side_bend.png",
		Vector3(d.x - 1.25, 0.0, d.z - 0.95), d)


	await _look(out_dir, "run_grazing.png",
		a + Vector3(-0.55, 0.42, -1.1), d)

	get_tree().quit(0)


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	_aim(target)
	for i in 6:
		await get_tree().process_frame
	player.global_position = at
	_aim(target)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


func _aim(target: Vector3) -> void:
	var to_target:= target - player.eye_position()
	player.set_look(atan2(- to_target.x, - to_target.z),
		atan2(to_target.y, Vector2(to_target.x, to_target.z).length()))
