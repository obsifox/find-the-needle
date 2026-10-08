class_name DevBlobReproProbe
extends Node


var world: Node3D
var player: Player

const WATCH_SECONDS:= 12.0
const SHOT_EVERY:= 1.5


const CAM_ORIGIN:= Vector3(-8.884055, 1.515903, 5.206352)
const CAM_BASIS:= Basis(
	Vector3(-0.919217, 0.0, 0.393751),
	Vector3(0.251418, 0.769605, 0.586939),
	Vector3(-0.303032, 0.638521, -0.707434))
const PERF_SCALE:= 0.81

var _cam: Camera3D
var _out:= ""
var _shot:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--blobrepro")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	_out = ua [i + 2] if i >= 0 and i + 2 < ua.size() else "user://blobrepro"
	if path == "" or not FileAccess.file_exists(path):
		print("BLOBREPRO: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("BLOBREPRO: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("BLOBREPRO: save version %d, %d buildings, %d props, block_save=%s"
		% [int(d.get("version", 0)), (d.get("buildings", []) as Array).size(),
			(d.get("props", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)


	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0 and "--freshpile" not in ua:
		world.field.generate(int(GameState.run_seed), heights)


		GameState.from_dict(d.get("state", { }))
		print("BLOBREPRO: %d saved heights restored" % heights.size())
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))

	Cfg.perf_scale = PERF_SCALE
	_cam = Camera3D.new()
	_cam.fov = player.camera.fov if player != null and player.camera != null else 75.0
	_cam.near = 0.05
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.global_transform = Transform3D(CAM_BASIS, CAM_ORIGIN)
	_cam.current = true
	if player != null:
		player.global_position = CAM_ORIGIN + Vector3(0.0, -1.66, 0.0)
	if world.hud != null:
		world.hud.visible = false
	world.field.update_lod(CAM_ORIGIN)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for k in 90:
		await get_tree().process_frame

	if "--digtest" in ua:
		await _dig_test()
		get_tree().quit()
		return

	var arms: Array = world.builds.robotic_arms
	print("BLOBREPRO: %d arms in the yard" % arms.size())
	for a in arms:
		var arm: RoboticArm = a
		print("  arm %s at %s, %.2f m from the camera" % [arm.name, _v(arm.global_position),
			arm.global_position.distance_to(CAM_ORIGIN)])

	var t:= 0.0
	var found:= false
	while t < WATCH_SECONDS:
		var r:= await _count_black("shot_%02d" % _shot)
		var line:= "t=%5.1f  black=%6d" % [t, r ["count"]]
		if r ["count"] > 0:
			line += "  box=%s" % str(r ["box"])
		for a in arms:
			var arm: RoboticArm = a
			var claw:= _claw_of(arm)
			line += "  | %s %s%s" % [arm.name, RoboticArm.Phase.keys() [arm._phase],
				(" claw " + _v(claw.global_position)) if claw != null else ""]
		print(line)
		if r ["count"] > 0 and not found:
			found = true
			await _bisect(arms)
		_shot += 1
		var waited:= 0.0
		while waited < SHOT_EVERY:
			waited += get_process_delta_time()
			await get_tree().process_frame
		t += SHOT_EVERY
	if not found:
		print("BLOBREPRO: no pure black pixel in %d shots" % _shot)
	get_tree().quit()


func _dig_test() -> void:
	var field:= world.field as HayField
	var space:= world.get_world_3d().direct_space_state
	var nc:= Cfg.field_cells()
	var shown:= 0
	var tufts: Array [Vector3] = []
	for cj in nc:
		for ci in nc:
			var c:= field.cell_center(ci, cj)
			if c.distance_to(CAM_ORIGIN) > 7.0:
				continue
			var h:= field.height_at(c.x, c.z)
			if h < 0.005 or h > 0.12:
				continue
			var point:= Vector3(c.x, h, c.z)

			var eye:= point + Vector3(1.0, 1.6, 0.0)
			var dir:= (point - eye).normalized()
			var aim:= Shovel.aim_from(eye, dir, space, field)
			var q:= PhysicsRayQueryParameters3D.create(eye, eye + dir * Cfg.SCOOP_REACH)
			q.collision_mask = Cfg.L_PILE
			var hit:= space.intersect_ray(q)
			var hit_s:= "no pile hit" if hit.is_empty() else "pile hit at %s (h there %.3f)" % [
				_v(hit ["position"]), field.height_at(hit ["position"].x, hit ["position"].z)]
			print("  cell (%d,%d) at %s h=%.3f | %s | aim=%s | strands in scoop radius: %d"
				% [ci, cj, _v(c), h, hit_s, str(aim), field.count_in_radius(point, Cfg.SCOOP_RADIUS)])
			shown += 1
			tufts.append(point)
			if shown >= 12:
				break
		if shown >= 12:
			break
	if shown == 0:
		print("  no thin remnant within 7 m of the camera")
		return

	var hits:= 0
	var loose:= 0
	var misses:= []
	for cj in nc:
		for ci in nc:
			var c:= field.cell_center(ci, cj)
			if c.distance_to(CAM_ORIGIN) > 20.0:
				continue
			var h:= field.height_at(c.x, c.z)
			if h < 0.005 or h > 0.12:
				continue
			var point:= Vector3(c.x, h, c.z)
			var eye:= point + Vector3(1.0, 1.6, 0.0)
			var aim:= Shovel.aim_from(eye, (point - eye).normalized(), space, field)
			if aim.is_empty():
				misses.append([ci, cj, h, "nothing"])
			elif bool(aim.get("loose", false)):
				loose += 1
				var e:= Cfg.CELL * 0.5
				misses.append([ci, cj, h, "under(cell)=%.1f at floor hit %s corners %.3f %.3f %.3f %.3f" % [field.strands_under(aim ["position"], Cfg.CELL), _v(aim ["position"]),
					field.height_at(c.x - e, c.z - e), field.height_at(c.x + e, c.z - e),
					field.height_at(c.x - e, c.z + e), field.height_at(c.x + e, c.z + e)]])
			else:
				hits += 1
	print("  SURVEY: %d thin cells within 20 m: %d dig, %d fall through to loose sweep, %d no hit at all"
		% [hits + loose + (misses.size() - loose), hits, loose, misses.size() - loose])
	for m in misses.slice(0, 12):
		print("    miss cell (%d,%d) h=%.3f %s" % [m [0], m [1], m [2], m [3]])


	player.equip_tool_id("spade")
	for k in 60:
		await get_tree().physics_frame
	print("  spade active=%s field=%s live=%s tool=%s" % [player.shovel.get("_active"),
		player.shovel.field != null, player.shovel.live != null, str(player.get("tool"))])
	if not bool(player.shovel.get("_active")):
		player.shovel.set_active(true)
		print("  (spade forced active)")
	tufts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in mini(6, tufts.size()):
		var point:= tufts [i]
		var eye:= point + Vector3(1.0, 1.6, 0.0)
		var dir:= (point - eye).normalized()
		player.global_position = eye - Vector3(0.0, player.camera.position.y + player.head.position.y, 0.0)
		player.rotation.y = atan2(- dir.x, - dir.z)
		player.head.rotation.x = asin(dir.y)
		for k in 6:
			await get_tree().physics_frame
		var look:= player.look_direction()
		var before:= GameState.hay_total
		var crust_before:= field.count_in_radius(point, Cfg.SCOOP_RADIUS)
		var live_h:= field.height_at(point.x, point.z)
		var under_now:= field.strands_under(point, Cfg.CELL)
		var g:= player.shovel.pan_geometry()
		var aim:= player.shovel.aim_point()
		var aim_static:= Shovel.aim_from(player.eye_position(), player.look_direction(), space, field)
		var n: int = player.shovel.scoop()
		for k in 3:
			await get_tree().physics_frame
		print("  DIG at %s: live h=%.4f under(cell)=%.1f | pan max %d radius %.3f | aim %s static %s | scoop() -> %d | hay_total %.0f -> %.0f | crust strands %d -> %d | riding %d"
			% [_v(point), live_h, under_now, int(g ["max"]), float(g ["radius"]),
				str(aim), str(aim_static), n, before, GameState.hay_total, crust_before,
				field.count_in_radius(point, Cfg.SCOOP_RADIUS), player.shovel.get("_riding").size()])


func _bisect(arms: Array) -> void:
	var env: Environment = (world.get_node("Environment") as WorldEnvironment).environment
	print("-- bisect --")
	env.glow_enabled = false
	print("  glow off:      black=%6d" % (await _count_black("bisect_glow_off")) ["count"])
	env.glow_enabled = true
	for a in arms:
		var arm: RoboticArm = a
		arm.visible = false
		print("  no %s:  black=%6d" % [arm.name, (await _count_black("bisect_no_" + arm.name)) ["count"]])
		arm.visible = true
	world.props.visible = false
	print("  no props:      black=%6d" % (await _count_black("bisect_no_props")) ["count"])
	world.props.visible = true
	world.field.visible = false
	print("  no field:      black=%6d" % (await _count_black("bisect_no_field")) ["count"])
	world.field.visible = true

	for surf_name in ["Shell", "Crust"]:
		var hidden: Array [Node3D] = []
		for chunk in (world.field as HayField).chunks:
			var n:= chunk.get_node_or_null(surf_name) as Node3D
			if n != null and n.visible:
				n.visible = false
				hidden.append(n)
		print("  no %-8s (%d nodes): black=%6d" % [surf_name, hidden.size(),
			(await _count_black("bisect_no_" + surf_name)) ["count"]])
		for n in hidden:
			n.visible = true


	var shell_mat:= StrandFactory.pile_surface_material()
	var was: Variant = shell_mat.get_shader_parameter("anisotropy")
	shell_mat.set_shader_parameter("anisotropy", 0.0)
	print("  shell anisotropy 0: black=%6d" % (await _count_black("bisect_aniso_0")) ["count"])
	shell_mat.set_shader_parameter("anisotropy", was)

	for child in world.get_children():
		var node:= child as Node3D
		if node == null or not node.visible or node == _cam or node == world.props or node == world.field or node is RoboticArm:
			continue
		node.visible = false
		var c: int = (await _count_black("bisect_no_" + node.name)) ["count"]
		node.visible = true
		if c == 0:
			print("  no %s: black=%6d  <- owns it" % [node.name, c])
	print("-- end bisect --")


func _count_black(label: String) -> Dictionary:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, label])
	var n:= 0
	var x0:= img.get_width()
	var y0:= img.get_height()
	var x1:= -1
	var y1:= -1
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c:= img.get_pixel(x, y)
			if c.r + c.g + c.b < 0.05:
				n += 1
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return { "count": n * 4, "box": Rect2i(x0, y0, maxi(x1 - x0, 0), maxi(y1 - y0, 0)) }


func _claw_of(arm: RoboticArm) -> Node3D:
	if arm._socket != null:
		return arm._socket
	return null


func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
