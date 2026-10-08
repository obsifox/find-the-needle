class_name DevSplitJoinShotProbe
extends Node


const LIFT:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	for _i in 30:
		await get_tree().process_frame

	GameState.add_money(500000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	var deck:= Vector3(0.0, LIFT, 0.0)


	var y_at:= Vector3(-16.0, 0.0, 6.0) + deck
	var u_at:= Vector3(-16.0, 0.0, -2.0) + deck
	var t_at:= Vector3(-16.0, 0.0, -10.0) + deck
	var s_at:= Vector3(-9.0, 0.0, -10.0) + deck
	var q_at:= Vector3(-9.0, 0.0, 6.0) + deck


	var y:= builds.add_splitter(y_at, 0.0)
	tool._lay_run(y.port_in() - y.forward() * 3.0, y.port_in())
	var y_mouth:= y.port_left()
	var y_end:= y_mouth + Vector3(0.0, 0.0, 3.0)
	tool._lay_run(y_mouth, y_end)


	var u:= builds.add_u_splitter(u_at, 0.0)
	tool._lay_run(u.port_in() - u.forward() * 3.0, u.port_in())
	var u_mouth:= u.port_left()
	var u_end:= u_mouth + Vector3(0.9, 0.0, 2.9)
	tool._lay_run(u_mouth, u_end)


	var t:= builds.add_t_splitter(t_at, 0.0)
	tool._lay_run(t.port_in() - t.forward() * 3.0, t.port_in())
	var t_mouth:= t.port_left()
	var t_end:= t_mouth + Vector3(2.1, 0.0, 2.1)
	tool._lay_run(t_mouth, t_end)


	var s0:= s_at
	var s1:= s0 + Vector3(0.0, 0.0, 3.0)
	var s2:= s1 + Vector3(0.57, 0.0, 0.57)
	var s3:= s2 + Vector3(0.0, 0.0, 3.0)
	tool._lay_run(s0, s1)
	tool._lay_run(s1, s2)
	tool._lay_run(s2, s3)


	var q:= builds.add_u_splitter(q_at, 0.0)
	tool._lay_run(q.port_in() - q.forward() * 3.0, q.port_in())
	var q_mouth:= q.port_left()
	var q_knee:= q_mouth + Vector3(0.0, 0.0, 1.2)
	tool._lay_run(q_mouth, q_knee)
	tool._lay_run(q_knee, q_knee + Vector3(1.4, 0.0, 0.0))

	for _i in 30:
		await get_tree().process_frame

	print("[splitjoin] corners fitted: %d" % builds.corners.size())
	for run: Conveyor in builds.conveyors:
		var drums:= run.get_node_or_null("Drums")
		print("[splitjoin] %s %.2f m trims %.3f/%.3f drums=%d"
			% [run.name, run.length, run.trim_start, run.trim_end,
			0 if drums == null else drums.get_child_count()])


	for bend: ConveyorCorner in builds.corners:
		var arc:= ConveyorCorner.arc_of(bend.from_point, bend.apex,
			bend.to_point)
		print("[splitjoin] bend %.0f deg tangent %.3f radius %.3f%s"
			% [rad_to_deg(float(arc.get("turn", 0.0))),
			bend.from_point.distance_to(bend.apex),
			float(arc.get("radius", 0.0)),
			"  PINCHED" if float(arc.get("radius", 0.0)) < BeltSweep.LIP_X
				else ""])
	print("[splitjoin] Y arm heading %.1f deg to the run off it"
		% rad_to_deg(y.arm_travel(ConveyorSplitter.LEFT)
			.angle_to((y_end - y_mouth).normalized())))

	for rig: Array in [[y_mouth, "y"], [u_mouth, "u"], [t_mouth, "t"],
			[s1, "short"], [q_knee, "tight"]]:
		var at: Vector3 = rig [0]
		var tag: String = rig [1]
		await _look(out_dir, "%s_over.png" % tag,
			at + Vector3(-0.6, 0.9, -0.7), at)
		await _look(out_dir, "%s_side.png" % tag,
			Vector3(at.x - 1.5, 0.0, at.z - 1.2), at)

	get_tree().quit(0)


func _look(out_dir: String, shot: String, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	_aim(target)
	for _i in 6:
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
