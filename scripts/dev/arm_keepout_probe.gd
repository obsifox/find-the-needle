class_name DevArmKeepOutProbe
extends Node


var world: Node3D

const BASE:= Vector3(11.8, 0.06, 4.0)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	GameState.add_money(20000.0)
	var builds: BuildManager = world.builds
	var build: BuildTool = world.player.build
	builds.add_conveyor(BASE + Vector3(1.8, 0.45, -1.2), BASE + Vector3(1.8, 0.45, 1.8))
	var arm: RoboticArm = builds.add_robotic_arm(BASE, 0.0, 1)
	build.set_active(true)
	build.set_mode(BuildTool.Mode.ROBOTIC_ARM)
	build.set_arm_tier(0)


	build.set_process(false)
	build.set_physics_process(false)
	await get_tree().process_frame
	var ghost: RoboticArm = build._arm_ghost
	if ghost == null:
		_fail("no arm hologram")
		return
	var orb:= ghost._model.find_child("RA_ReachOrb_Ghost", true, false) as Node3D
	if orb != null and orb.is_visible_in_tree():
		_fail("the reach dome still shows on the hologram")
		return

	var bad:= ConveyorKit.ghost_material(false)
	var mismatches: Array [String] = []
	var saw_red:= false
	var saw_calm:= false
	var saw_none:= false
	var x:= 1.0
	while x <= 9.0:
		var at:= BASE + Vector3(x, 0.0, 0.3)
		var refused:= _place(build, ghost, at)
		var rule: bool = builds.arm_reach_conflict(at, 0)
		var red:= 0
		var calm:= 0
		for ring in build._arm_keep_rings:
			if is_instance_valid(ring) and ring.visible:
				if ring.material_override == build._arm_keep_bad_mat:
					red += 1
				else:
					calm += 1
		var tinted:= _tinted(arm, bad)
		var strip_green:= build._arm_feed_mat != null and build._arm_feed_mat.albedo_color.g > build._arm_feed_mat.albedo_color.r + 0.2
		print("[armkeepout] x=%.2f rule=%s refused=%s (%s) red=%d calm=%d tinted=%s strip_green=%s"
			% [x, rule, refused, build._eval ["reason"], red, calm, tinted, strip_green])


		if (rule and not refused) or (red > 0) != rule or tinted != rule:
			mismatches.append("x=%.2f" % x)
		if build._arm_feed_mat != null and strip_green == refused:
			mismatches.append("strip x=%.2f" % x)
		saw_red = saw_red or red > 0
		saw_calm = saw_calm or (calm > 0 and red == 0)
		saw_none = saw_none or (calm == 0 and red == 0)
		x += 0.25
	if not mismatches.is_empty():
		_fail("the circles, the tint and the rule disagree at %s" % str(mismatches))
		return
	if not (saw_red and saw_calm and saw_none):
		_fail("walk never showed all three of red, calm and nothing (%s %s %s)"
			% [saw_red, saw_calm, saw_none])
		return

	_place(build, ghost, BASE + Vector3(2.4, 0.0, 0.3))
	if not _tinted(arm, bad):
		_fail("setup for the put away check did not tint the arm")
		return
	build.set_active(false)
	if _tinted(arm, bad):
		_fail("the warning colour stayed on the arm after the tool was put away")
		return
	build.set_active(true)
	build.set_mode(BuildTool.Mode.ROBOTIC_ARM)
	build.set_arm_tier(0)

	var seams:= _seam_check(builds)
	if seams != "":
		_fail(seams)
		return

	if DisplayServer.get_name() != "headless":
		await _shots(build)
	print("[armkeepout] PASS")
	get_tree().quit()


func _place(build: BuildTool, ghost: RoboticArm, at: Vector3) -> bool:
	ghost = build._arm_ghost
	ghost.global_position = at
	var tier: Dictionary = Cfg.ROBOT_ARM_TIERS [0]
	build._eval = build._evaluate_arm(at, Vector3.UP, world.builds.arm_price(0),
		float(tier ["scale"]))
	var ok:= bool(build._eval ["ok"])
	ghost.set_preview_valid(ok)
	build._update_arm_feeds(at)
	build._tint_arm_feeds(ok)
	build._update_arm_neighbours(at)
	return not ok


func _seam_check(builds: BuildManager) -> String:
	var a0:= BASE + Vector3(-6.0, 0.45, 8.0)
	var a1:= a0 + Vector3(2.0, 0.0, 0.0)
	var a2:= a1 + Vector3(2.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(12.0))
	var first: Node = builds.add_conveyor(a0, a1)
	var second: Node = builds.add_conveyor(a1, a2)
	if first == null or second == null:
		return "could not lay the two belts for the seam check"


	var runs: Array = [first, second]
	for corner in builds.corners:
		if is_instance_valid(corner) and corner._point_at(0.0).distance_to(a1) < 1.0:
			runs.append(corner)
	print("[armkeepout] seam runs=%d" % runs.size())
	var verts:= RoboticArm.reach_strip(runs, a1 + Vector3.UP, 50.0)
	var uses:= { }
	for t in range(0, verts.size(), 3):
		for e in 3:
			var p:= verts [t + e]
			var q:= verts [t + (e + 1) % 3]
			var kp:= "%.3f,%.3f,%.3f" % [p.x, p.y, p.z]
			var kq:= "%.3f,%.3f,%.3f" % [q.x, q.y, q.z]
			var key:= kp + "|" + kq if kp < kq else kq + "|" + kp
			uses [key] = int(uses.get(key, 0)) + 1
	var boundary:= 0
	for key: String in uses:
		if int(uses [key]) == 1:
			boundary += 1
	var quads:= verts.size() / 6
	print("[armkeepout] seam quads=%d boundary=%d want=%d" % [quads, boundary, 2 * quads + 2])
	if quads == 0 or boundary != 2 * quads + 2:
		return "the feed strip is cut at the joint (%d open edges for %d quads)" % [boundary, quads]
	return ""


func _tinted(arm: RoboticArm, bad: Material) -> bool:
	for node in arm.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).material_overlay == bad:
			return true
	return false


func _shots(build: BuildTool) -> void:
	var out:= "user://armkeepout"
	var args:= OS.get_cmdline_user_args()
	var i:= args.find("--armkeepout")
	if i >= 0 and i + 1 < args.size() and not args [i + 1].begins_with("--"):
		out = args [i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var cam:= Camera3D.new()
	cam.fov = 60.0
	world.add_child(cam)
	cam.look_at_from_position(BASE + Vector3(3.2, 4.2, 7.5), BASE + Vector3(2.4, 0.4, 0.0),
		Vector3.UP)
	cam.current = true
	for shot: Array in [["inside", 2.4], ["outside", 3.8]]:
		_place(build, build._arm_ghost, BASE + Vector3(float(shot [1]), 0.0, 0.3))
		for _f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path:= out.path_join("arm_keepout_%s.png" % shot [0])
		get_viewport().get_texture().get_image().save_png(path)
		print("[armkeepout] shot %s" % ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error("armkeepout: %s" % message)
	print("[armkeepout] FAIL %s" % message)
	get_tree().quit(1)
