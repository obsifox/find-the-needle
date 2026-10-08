class_name DevBriquetteShotProbe
extends Node


const LANE_X:= 22.0


const DIE_EYE:= Vector3(0.05, 1.62, 3.05)
const DIE_AIM:= Vector3(0.0, 1.18, 0.0)


const FEED_EYE:= Vector3(-3.9, 3.9, -4.2)
const FEED_AIM:= Vector3(-0.55, 1.05, -0.75)


const ROOM_X:= 12.0


const ROOM_EYE:= Vector3(2.9, 1.7, 3.4)
const ROOM_AIM:= Vector3(-0.1, 1.55, 0.0)


const SIGN_SHOTS: Array [Array] = [
	["briquette_sign_hay.png", Vector3(-3.95, 1.7, -0.87), Vector3(-2.11, 1.4, -0.87)],
	["briquette_sign_bricks.png", Vector3(0.4, 1.7, -7.0), Vector3(0.0, 1.95, -3.1)],
	["briquette_sign_discs.png", Vector3(-0.3, 1.7, 4.9), Vector3(0.0, 2.2, 0.71)],
]

const GHOST_X:= LANE_X + 14.0

var world: Node3D
var player: Player

var _cam: Camera3D
var _press: BriquettePress


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in 40:
		await get_tree().process_frame
	player.global_position = Vector3(LANE_X - 12.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	for _w in 30:
		await get_tree().process_frame

	_press = world.builds.add_briquette(Vector3(LANE_X, 0.0, 0.0), 0.0)
	for _w in 60:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()


	Cfg.set_no_hud(true)


	for shot: Array in SIGN_SHOTS:
		await _snap(out_dir, str(shot [0]), shot [1], shot [2])
	var ghost:= BriquettePress.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = Vector3(GHOST_X, 0.0, 0.0)
	ghost.set_preview_valid(true)
	for _w in 20:
		await get_tree().process_frame
	await _snap_at(out_dir, "briquette_sign_ghost.png", ghost.global_position,
		SIGN_SHOTS [1] [1], SIGN_SHOTS [1] [2])
	world.remove_child(ghost)
	ghost.queue_free()


	_press.stored_strands = Tech.briquette_batch_strands() * 4


	await _wait(func() -> bool: return _press.road_front(BriquettePress.SIDE_GRIND) > 0.45, 600)
	_report("hay pour 1")
	await _snap(out_dir, "briquette_hay_pour_1.png", FEED_EYE, FEED_AIM)
	await _wait(func() -> bool: return _press.road_front(BriquettePress.SIDE_GRIND) > 1.25, 600)
	_report("hay pour 2")
	await _snap(out_dir, "briquette_hay_pour_2.png", FEED_EYE, FEED_AIM)
	await _wait(func() -> bool: return _press.road_arrived(BriquettePress.SIDE_GRIND), 600)
	await _settle(90)
	_report("hay only")
	await _snap(out_dir, "briquette_hay_only.png", FEED_EYE, FEED_AIM)


	_press.stored_strands = 0
	await _wait(func() -> bool: return _press.grinder_spin() < BriquettePress.ROAD_SOURCE_SPIN, 600)
	await _settle(60)
	_report("hay drain")
	await _snap(out_dir, "briquette_hay_drain.png", FEED_EYE, FEED_AIM)
	await _wait(func() -> bool: return not _press.road_busy(BriquettePress.SIDE_GRIND), 600)
	_press.stored_bricks = Tech.briquette_batch_bricks() * 6
	await _wait(func() -> bool: return _press.road_front(BriquettePress.SIDE_MILL) > 0.9, 600)
	_report("brick pour 1")
	await _snap(out_dir, "briquette_bricks_pour_1.png", FEED_EYE, FEED_AIM)
	await _wait(func() -> bool: return _press.road_front(BriquettePress.SIDE_MILL) > 1.7, 600)
	_report("brick pour 2")
	await _snap(out_dir, "briquette_bricks_pour_2.png", FEED_EYE, FEED_AIM)
	await _wait(func() -> bool: return _press.road_arrived(BriquettePress.SIDE_MILL), 600)
	await _settle(90)
	_report("bricks only")
	await _snap(out_dir, "briquette_bricks_only.png", FEED_EYE, FEED_AIM)


	_press.stored_strands = 0
	_press.stored_bricks = 0
	await _settle(_settle_heap())
	_report("empty")
	await _snap(out_dir, "briquette_heap_0.png", DIE_EYE, DIE_AIM)


	for step: Array in [[1, 0, "heap_1"], [3, 1, "heap_2"], [2, 2, "heap_3"]]:
		_press.stored_strands = Tech.briquette_batch_strands() * int(step [0]) / 3
		_press.stored_bricks = Tech.briquette_batch_bricks() * int(step [1]) / 2
		await _settle(_settle_heap())
		_report(str(step [2]))
		await _snap(out_dir, "briquette_%s.png" % step [2], DIE_EYE, DIE_AIM)


	_press.stored_strands = Tech.briquette_batch_strands() * 6
	_press.stored_bricks = Tech.briquette_batch_bricks() * 6
	await _wait(func() -> bool: return _press.is_running(), 600)


	for shot: Array in [


			[3.0, "charge"],

			[40.0, "closed"],

			[92.0, "formed"],

			[108.0, "pushed"],

			[118.0, "handed"]]:
		await _wait_frame(float(shot [0]))
		_report(str(shot [1]))
		await _snap(out_dir, "briquette_%s.png" % shot [1], DIE_EYE, DIE_AIM)


		await _snap(out_dir, "briquette_%s_feed.png" % shot [1],
			FEED_EYE, FEED_AIM)

	await _room_pass(out_dir)

	print("[briquetteshot] done")
	get_tree().quit()


func _room_pass(out_dir: String) -> void:


	var inside: BriquettePress = world.builds.add_briquette(
		Vector3(ROOM_X, 0.0, 0.0), 0.0)
	if inside == null:
		print("[briquetteshot] WARNING: no room in the shed for the room pass")
		return
	for _w in 60:
		await get_tree().physics_frame
	var was: bool = Cfg.gfx.get("reflect_probe", true)
	for state: Array in [[false, "sky"], [true, "room"]]:
		Cfg.gfx ["reflect_probe"] = bool(state [0])
		world.call("_apply_render_settings")


		for _w in 20:
			await get_tree().process_frame
		var shot:= "briquette_room_%s.png" % state [1]
		await _snap_at(out_dir, shot, inside.global_position, ROOM_EYE, ROOM_AIM)
		print("  room reflection %-4s blue over red on the columns %.2f"
			% [state [1], _column_blue(out_dir, shot)])
	Cfg.gfx ["reflect_probe"] = was
	world.call("_apply_render_settings")


func _column_blue(out_dir: String, name: String) -> float:
	var img:= Image.load_from_file("%s/%s" % [out_dir, name])
	if img == null:
		return 0.0
	var red:= 0.0
	var blue:= 0.0
	var y:= img.get_height() / 2
	for x in range(0, img.get_width(), 4):
		var c:= img.get_pixel(x, y)
		red += c.r
		blue += c.b
	return blue / maxf(red, 0.0001)


func _wait_frame(want: float) -> void:


	for _w in 1200:
		if not _press.is_running() or _press.cycle_frame() > want:
			break
		await get_tree().physics_frame
	for _w in 1200:
		if _press.is_running() and _press.cycle_frame() >= want:
			return
		await get_tree().physics_frame
	print("[briquetteshot] WARNING: the cycle never reached frame %.0f" % want)


func _wait(cond: Callable, frames: int) -> void:
	for _w in frames:
		if bool(cond.call()):
			return
		await get_tree().physics_frame
	print("[briquetteshot] WARNING: gave up waiting")


func _report(label: String) -> void:
	var model:= _press.get_node_or_null("Model")
	var shown: Array [String] = []
	for node_name: String in [BriquettePress.N_CLIP_SPOUT,
			BriquettePress.N_CLIP_FALL, BriquettePress.N_CLIP_MILL_BED,
			BriquettePress.N_CLIP_CHAFF, BriquettePress.N_CLIP_GRIND_BED,
			BriquettePress.N_CLIP_GRIND_TURN, BriquettePress.N_CLIP_CHARGE,
			BriquettePress.N_CLIP_DISC]:
		var node:= model.find_child(node_name, true, false) as Node3D
		if node != null and node.visible:
			shown.append(node_name)
	print("  %-12s frame %6.1f  fill %.2f  drawn %.2f  grind %.2f  mill %.2f  fronts %.2f %.2f  showing: %s"
		% [label, _press.cycle_frame(), _press.charge_fill(),
			_press.charge_drawn(), _press.grinder_spin(), _press.mill_spin(),
			_press.road_front(BriquettePress.SIDE_GRIND),
			_press.road_front(BriquettePress.SIDE_MILL),
			"nothing" if shown.is_empty() else ", ".join(shown)])


func _settle_heap() -> int:
	return int(60.0 * (Cfg.BRIQUETTE_SPIN_SECONDS
		+ _press.road_seconds(BriquettePress.SIDE_MILL)
		+ 1.0 / BriquettePress.CHARGE_GROW)) + 30


func _settle(frames: int) -> void:
	for _w in frames:
		await get_tree().physics_frame


func _snap(out_dir: String, name: String, eye: Vector3, aim: Vector3) -> void:
	await _snap_at(out_dir, name, _press.global_position, eye, aim)


func _snap_at(out_dir: String, name: String, origin: Vector3, eye: Vector3,
		aim: Vector3) -> void:
	_cam.look_at_from_position(origin + eye, origin + aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
