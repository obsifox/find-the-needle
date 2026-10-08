class_name DevDigSwingProbe
extends Node


const MOMENTS:= [0.04, 0.11, 0.16, 0.24, 0.3, 0.4]
const NAMES:= ["windup", "thrust", "jam", "lift", "heave", "settle"]

const STAND_BACK:= 2.1
const LOOK_IN:= 0.5


const SPEED_LIMIT:= 6.0
const TURN_LIMIT:= 10.0

var world: Node3D
var player: Player
var field: HayField

var _failed:= false


func shoot(out_dir: String) -> void:
	world.block_save = true
	_check_tables()
	Tech.reset()
	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	print("dig swing: tool mode is %s" % Cfg.TOOL_MODE_NAMES [Cfg.tool_mode])
	_stand()

	for _w in 90:
		await get_tree().process_frame

	player.select_hotbar_slot(1)
	for _w in 20:
		await get_tree().process_frame
	await _wait_for_aim()
	await _tool_pass(out_dir, "spade", player.shovel)

	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for _w in 30:
		await get_tree().process_frame
	await _tool_pass(out_dir, "fork", player.pitchfork)

	GameState.grant_tool("sand_shovel")
	player._set_tool(Player.Tool.TOY)
	for _w in 30:
		await get_tree().process_frame
	await _toy_pass(out_dir)

	print("dig swing: %s" % ("FAIL" if _failed else "ok"))
	get_tree().quit(1 if _failed else 0)


func _check_tables() -> void:
	var tables:= { "spade": DigSwing.spade(), "fork": DigSwing.fork(),
		"toy": DigSwing.toy() }
	for label: String in tables:
		var sw: DigSwing = tables [label]
		sw.start(1.0)
		var prev:= sw.pose()
		var fastest:= 0.0
		var quickest:= 0.0
		var steps:= 0
		while sw.is_swinging():
			sw.tick(0.001)
			var now:= sw.pose()
			fastest = maxf(fastest, Vector2(now.x - prev.x, now.y - prev.y).length() / 0.001)
			quickest = maxf(quickest, absf(now.z - prev.z) / 0.001)
			prev = now
			steps += 1
		var depth:= 0.0
		sw.start(1.0)
		while sw.is_swinging():
			sw.tick(0.001)
			depth = maxf(depth, absf(sw.pose().x))
		sw.start(1.0)
		for _i in 100:
			sw.tick(0.001)
		var mid:= sw.pose()
		sw.start(1.0)
		var refused:= (sw.pose() - mid).length()
		for _i in 240:
			sw.tick(0.001)
		var a:= sw.pose()
		sw.start(1.0)
		var b:= sw.pose()
		var gap:= (a - b).length()
		print("  %s table: %d ms, fastest %.2f m/s, quickest turn %.2f rad/s, "
			% [label, steps, fastest, quickest]
			+ "travel along the view %.3f m, a click at 100 ms moved the pose %.6f, "
			% [depth, refused] + "a click in the settle moved it %.6f" % gap)
		if fastest > SPEED_LIMIT or quickest > TURN_LIMIT:
			print("  FAIL: that is faster than arms")
			_failed = true
		if depth > 0.0:
			print("  FAIL: the stroke moves the tool along the view")
			_failed = true
		if refused > 1e-05 or gap > 1e-05:
			print("  FAIL: a second click snapped the tool")
			_failed = true


func _wait_for_aim() -> void:
	var frames:= 0
	while frames < 900:
		var aim:= player.shovel.aim_point()
		if not aim.is_empty():
			var at: Vector3 = aim ["position"]
			print("  aim on the pile after %d frames, %.2f m from the eye, loose=%s"
				% [frames, at.distance_to(player.eye_position()),
					str(aim.get("loose", false))])
			return
		if frames % 30 == 29:
			_stand()
		await get_tree().process_frame
		frames += 1
	print("  FAIL: nothing under the crosshair after %d frames" % frames)
	_failed = true


func _stand() -> void:
	var face_z:= 0.0
	var z:= 14.0
	while z > 0.5:
		if field.height_at(0.0, z) > 0.6:
			face_z = z
			break
		z -= 0.25
	var at:= Vector3(0.0, 0.3, face_z + STAND_BACK)
	var target:= Vector3(0.0, field.height_at(0.0, face_z - LOOK_IN) + 0.05,
		face_z - LOOK_IN)
	player.global_position = at
	player.look_at_from_position(at, Vector3(target.x, at.y, target.z), Vector3.UP)
	player.rotation.x = 0.0
	var eye:= player.eye_position()
	var d:= target - eye
	if player.head != null:
		player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	print("  face at z=%.2f, standing at z=%.2f" % [face_z, at.z])


func _tool_pass(out_dir: String, label: String, blade: Shovel) -> void:
	var vfx_before:= blade.vfx.emitted_total if blade.vfx != null else 0
	var got:= blade.scoop()
	print("  %s: dug %d strands" % [label, got])
	if got <= 0:
		print("  FAIL: the click took nothing, so there is no stroke to see")
		_failed = true
		return
	var vfx_after:= blade.vfx.emitted_total if blade.vfx != null else 0
	print("  %s: %d chaff asked for on the bite" % [label, vfx_after - vfx_before])
	await _film(out_dir, label, func() -> float: return blade._swing.elapsed())

	for _i in 50:
		await get_tree().physics_frame
	var before:= blade.carried_strands()
	blade.swing(1.0)
	for _i in 75:
		await get_tree().physics_frame
	_report_load(label, got, before, blade.carried_strands())


func _toy_pass(out_dir: String) -> void:
	var toy:= player.carry.held() as SandShovel
	if toy == null:
		print("  FAIL: no toy spade in the hands")
		_failed = true
		return
	var got:= toy.scoop()
	print("  toy: dug %d strands" % got)
	if got <= 0:
		print("  FAIL: the click took nothing, so there is no stroke to see")
		_failed = true
		return
	await _film(out_dir, "toy", func() -> float: return toy._swing.elapsed())
	for _i in 50:
		await get_tree().physics_frame
	var before:= toy.carried_strands()
	toy._swing.start(1.0)
	for _i in 75:
		await get_tree().physics_frame
	_report_load("toy", got, before, toy.carried_strands())


func _report_load(label: String, got: int, before: int, after: int) -> void:
	print("  %s: %d on the pan before a loaded swing, %d after (bite was %d)"
		% [label, before, after, got])
	if before <= 0:
		print("  FAIL: the bite never landed on the pan")
		_failed = true
		return
	var lost:= before - after
	var allowed:= 0 if Cfg.simple_tools() else int(ceil(float(before) * 0.1))
	if lost > allowed:
		print("  FAIL: the swing lost %d of %d, %d allowed" % [lost, before, allowed])
		_failed = true


func _film(out_dir: String, label: String, clock: Callable) -> void:
	var next:= 0
	var frames:= 0
	var started:= Time.get_ticks_usec()
	while next < MOMENTS.size():
		await get_tree().process_frame
		frames += 1
		var t: float = clock.call()
		if t < 0.0:


			for k in range(next, MOMENTS.size()):
				await _snap(out_dir, "%s_%d_%s_rest.png" % [label, k, NAMES [k]])
			break
		if t >= float(MOMENTS [next]):
			await _snap(out_dir, "%s_%d_%s_%03dms.png"
				% [label, next, NAMES [next], int(round(t * 1000.0))])
			next += 1
	var seconds:= float(Time.get_ticks_usec() - started) / 1000000.0
	print("  %s: filmed at %.1f frames a second"
		% [label, float(frames) / maxf(seconds, 0.001)])


func _snap(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
