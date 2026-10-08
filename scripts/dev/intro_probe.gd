class_name DevIntroProbe
extends Node


const PATIENCE:= 20.0


const MEDDLE_AT:= 1.1


const SWAY_MIN_DEG:= 10.0


const SWAY_OUTSIDE_MAX_DEG:= 2.0

var world: Node3D
var player: Player
var door: BayDoor
var warehouse: Warehouse
var intro: IntroSequence

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	call_deferred("_run")


const SHOT_TIMES:= [0.2, 1.6, 3.2, 5.0, 5.7, 6.65, 7.4, 8.6, 9.1, 10.0]


func shoot(out_dir: String) -> void:
	call_deferred("_shoot", out_dir)


func _shoot(out_dir: String) -> void:
	world.block_save = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	intro.begin()
	var t:= 0.0
	var next:= 0
	while next < SHOT_TIMES.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t < float(SHOT_TIMES [next]):
			continue
		await RenderingServer.frame_post_draw
		var path:= "%s/intro_%d.png" % [out_dir, next]
		get_viewport().get_texture().get_image().save_png(path)
		print("[introshot] %5.1fs  %s" % [t, path])
		next += 1
	await _shoot_open(out_dir)
	get_tree().quit()


func _shoot_open(out_dir: String) -> void:


	if intro.is_running():
		intro.abort()
		await get_tree().process_frame
	door.set_open_amount(1.0)
	var eye:= player.global_position
	var to_door:= door.focus_point() - (eye + Vector3.UP * player.head.position.y)
	player.set_look(atan2(- to_door.x, - to_door.z),
		atan2(to_door.y, Vector2(to_door.x, to_door.z).length()))
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/intro_open.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("[introshot]  open   %s" % path)


func _run() -> void:
	world.block_save = true


	intro.abort()
	await get_tree().process_frame

	print("\n=== it is asked for by a new game and by nothing else ===")
	_check_gating()

	print("\n=== the door has something to say ===")
	_check_audio()

	print("\n=== the wall has a doorway in it ===")
	_check_void()

	print("\n=== and it follows the wall when the shed grows ===")
	await _check_void_follows()

	print("\n=== the leaf moves, and so does its collision ===")
	await _check_leaf()

	print("\n=== nothing the player presses gets them out of it ===")
	await _check_unskippable()

	print("\n=== the sequence plays and hands back ===")
	var watched:= await _play(false)

	print("\n=== and the abort lands in the same place ===")
	var cut:= await _play(true)
	if not watched.is_empty() and not cut.is_empty():
		var drift: float = (watched ["pos"] as Vector3).distance_to(cut ["pos"])
		_ok(drift < 0.35, "abort stops within 35 cm of the watched walk (%.2f m)" % drift)
		var turn: float = absf(rad_to_deg(angle_difference(
			watched ["yaw"] as float, cut ["yaw"] as float)))
		_ok(turn < 8.0, "abort faces within 8 degrees of the watched turn (%.1f)" % turn)

	print("\n%s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _check_gating() -> void:
	var slot:= SaveManager.current_slot


	var size:= Cfg.pile_size_id


	SaveManager.begin_new_game(slot, true)
	_ok(SaveManager.take_intro_due(), "a new game asks for the sequence")
	_ok(not SaveManager.take_intro_due(), "...and asks exactly once")
	SaveManager.begin_load(slot)
	_ok(not SaveManager.take_intro_due(), "a load never asks for it")
	Cfg.apply_pile_size(size)


func _check_audio() -> void:
	for key: String in ["door_open", "door_slam"]:
		var paths: Variant = Audio.SFX_LIB.get(key)
		var list: Array = paths if paths is Array else []
		_ok(not list.is_empty(), "'%s' is in the library" % key)
		for path: String in list:
			var stream: AudioStream = load(path) as AudioStream
			_ok(stream != null and stream.get_length() > 0.05,
				"'%s' loads %.2f s from %s" % [key, 0.0 if stream == null
					else stream.get_length(), path.get_file()])


	for key: String in ["door_open", "door_slam"]:
		_ok(not Audio.LOOP_LIB.has(key), "'%s' is a one-shot, not a held loop" % key)
	_ok(Audio.has_method("stop_world_sfx"),
		"and the title screen has a way to silence anything that leaks anyway")


func _check_void() -> void:
	var space:= world.get_world_3d().direct_space_state
	var mid:= door.global_position + Vector3(0.0, BayDoor.OPENING_H * 0.5, 0.0)


	var outward:= - door.global_basis.z
	var along:= door.global_basis.x
	var q:= PhysicsRayQueryParameters3D.create(
		mid - outward * 1.5, mid + outward * 2.0)
	q.collision_mask = Cfg.L_WORLD


	q.exclude = _leaf_body_rids()
	_ok(space.intersect_ray(q).is_empty(),
		"nothing solid across the middle of the opening once the leaf is discounted")


	var beside:= mid + along * (BayDoor.OPENING_W * 0.5 + 1.0)
	var q2:= PhysicsRayQueryParameters3D.create(
		beside - outward * 1.5, beside + outward * 2.0)
	q2.collision_mask = Cfg.L_WORLD
	_ok(not space.intersect_ray(q2).is_empty(),
		"the wall a metre to the side of the opening is still solid")


	var sill:= Vector3(door.global_position.x, 0.02, door.global_position.z)
	var q3:= PhysicsRayQueryParameters3D.create(
		sill + outward * (Warehouse.WALL_T - 0.05), sill + outward * 0.05)
	q3.collision_mask = Cfg.L_WORLD
	q3.exclude = _leaf_body_rids()


	q3.hit_from_inside = true
	_ok(not space.intersect_ray(q3).is_empty(),
		"the wall below the sill is still solid, so there is no letterbox")


	var head:= door.global_position + Vector3(0.0, 2.0, 0.0)
	var q4:= PhysicsRayQueryParameters3D.create(
		head + outward * (Warehouse.WALL_T - 0.05), head + outward * 0.05)
	q4.collision_mask = Cfg.L_WORLD
	q4.exclude = _leaf_body_rids()
	q4.hit_from_inside = true
	_ok(space.intersect_ray(q4).is_empty(),
		"the same ray at head height finds nothing, so the void is genuinely open")


func _check_void_follows() -> void:
	var top:= TechTree.max_rank("yard_space")
	var worst:= 0.0
	var bad:= 0
	for rank in range(0, top + 1):
		Tech.reset()
		if rank > 0:
			Tech.grant("yard_space", rank)
		await get_tree().process_frame
		if not _void_open_here():
			bad += 1
		worst = maxf(worst, absf(door.global_position.x) - warehouse.inner)
	Tech.reset()
	await get_tree().process_frame
	_ok(bad == 0, "the opening is still open at all %d ranks (%d bad)"
		% [top + 1, bad])
	_ok(absf(worst) < 0.01,
		"the door stayed on the wall face at every rank (worst %.3f m)" % worst)
	_ok(_void_open_here(), "and it is open again back at the stock size")


func _void_open_here() -> bool:
	var space:= world.get_world_3d().direct_space_state
	var mid:= door.global_position + Vector3(0.0, BayDoor.OPENING_H * 0.5, 0.0)
	var outward:= - door.global_basis.z
	var q:= PhysicsRayQueryParameters3D.create(
		mid + outward * (Warehouse.WALL_T - 0.05), mid + outward * 0.05)
	q.collision_mask = Cfg.L_WORLD
	q.exclude = _leaf_body_rids()
	q.hit_from_inside = true
	return space.intersect_ray(q).is_empty()


func _leaf_body_rids() -> Array [RID]:
	var out: Array [RID] = []
	for n in door.find_children("*", "StaticBody3D", true, false):
		out.append((n as StaticBody3D).get_rid())
	return out


func _check_leaf() -> void:
	var body:= door.find_child("Col_Leaf*", true, false) as Node3D
	_ok(body != null, "the leaf has a collision box to move")
	if body == null:
		return
	var shut_y:= body.global_position.y
	door.set_open_amount(1.0)
	await get_tree().process_frame
	var open_y:= body.global_position.y
	_ok(is_equal_approx(door.open_amount(), 1.0), "the leaf reports itself open")
	_ok(open_y - shut_y > BayDoor.LIFT_MAX - 0.05,
		"the collision box rose with the leaf (%.2f m)" % (open_y - shut_y))


	_ok(BayDoor.CLIP_Y <= Warehouse.WALL_H,
		"the raised leaf stops being drawn under the eaves (%.2f <= %.2f)"
			% [BayDoor.CLIP_Y, Warehouse.WALL_H])


	_ok(BayDoor.CLIP_Y > BayDoor.OPENING_H,
		"the plane is above the clear opening (%.2f > %.2f)"
			% [BayDoor.CLIP_Y, BayDoor.OPENING_H])

	door.snap_shut()
	await get_tree().process_frame
	_ok(door.is_shut() and is_equal_approx(body.global_position.y, shut_y),
		"snapping shut puts both halves back")


func _tutorial_ui() -> Array [Control]:
	var out: Array [Control] = []
	for c: Control in [world.get("hud"), world.get("quests"),
			world.get("mission_cue")]:
		if c != null:
			out.append(c)
	return out


func _ui_down() -> bool:
	for c in _tutorial_ui():
		if c.visible and c.modulate.a > 0.01:
			return false
	return true


func _ui_up() -> bool:
	for c in _tutorial_ui():
		if c.modulate.a <= 0.01:
			return false
	return true


func _ui_state() -> String:
	var parts:= PackedStringArray()
	for c in _tutorial_ui():
		parts.append("%s %s a=%.2f"
			% [c.name, "on" if c.visible else "off", c.modulate.a])
	return "  ·  ".join(parts)


func _check_unskippable() -> void:
	intro.begin()
	var waited:= 0.0
	while waited < MEDDLE_AT:
		waited += await _tick()
	var where:= player.global_position
	for ev in _mash():
		get_viewport().push_input(ev)


	await _tick()
	await _tick()
	_ok(intro.is_running(), "the sequence is still running after the mashing")
	_ok(player.scripted, "and the body is still the sequence's")


	_ok(player.global_position.distance_to(where) < 3.0,
		"and was not thrown onto the mark (%.2f m on)"
		% player.global_position.distance_to(where))
	var menu:= world.get_node_or_null("PauseMenu")
	_ok(menu == null or not bool(menu.call("is_open")),
		"and Escape did not open the pause menu over it")
	intro.abort()
	await _tick()


func _mash() -> Array [InputEvent]:
	var out: Array [InputEvent] = []
	for code in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_E]:
		var k:= InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = true
		out.append(k)
	var m:= InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	out.append(m)
	var j:= InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_A
	j.pressed = true
	out.append(j)
	return out


func _play(cut_short: bool) -> Dictionary:
	intro.begin()
	var yaw_at_start:= player.rotation.y
	_ok(intro.is_running(),
		"%s: the sequence is running" % ("abort" if cut_short else "watch"))
	_ok(player.scripted, "the body is flagged scripted while it runs")
	_ok(_ui_down(), "and nothing is drawn over it: %s" % _ui_state())


	_ok(not world.save_now(), "no save is written while it runs")

	var waited:= 0.0
	var walked:= false


	var sway_right:= 0.0
	var sway_left:= 0.0
	var sway_outside:= 0.0
	if cut_short:
		while waited < MEDDLE_AT:
			waited += await _tick()
		intro.abort()
	while intro.is_running() and waited < PATIENCE:
		waited += await _tick()
		if player.velocity.length() > 0.2:
			walked = true
			var off_line:= angle_difference(yaw_at_start, player.rotation.y)
			sway_right = maxf(sway_right, - off_line)
			sway_left = maxf(sway_left, off_line)
			if not _inside(player.global_position):
				sway_outside = maxf(sway_outside, absf(off_line))

	if intro.is_running():
		_ok(false, "the sequence finished inside %.0f s" % PATIENCE)
		return { }
	_ok(true, "the sequence finished after %.1f s" % waited)
	if not cut_short:
		_ok(walked, "the player was actually walked, not teleported")


		_ok(rad_to_deg(sway_right) > SWAY_MIN_DEG,
			"the head looked right on the way in (%.1f degrees)"
			% rad_to_deg(sway_right))
		_ok(rad_to_deg(sway_left) > SWAY_MIN_DEG,
			"and back to the left (%.1f degrees)" % rad_to_deg(sway_left))


		_ok(rad_to_deg(sway_outside) < SWAY_OUTSIDE_MAX_DEG,
			"and not until it was under the door (%.1f degrees outside)"
			% rad_to_deg(sway_outside))
	_ok(not player.scripted, "the body was handed back")
	_ok(door.is_shut(), "the door was left shut")
	_ok(not door.is_moving(), "the leaf was left still")
	_ok(not intro.is_running(), "the save guard has let go")
	_ok(_ui_up(), "the interface came back: %s" % _ui_state())
	_ok(_inside(player.global_position), "the player was left inside the building")
	_check_clear_of_the_pile(player.global_position)
	var to_door:= door.focus_point() - player.eye_position()
	to_door.y = 0.0
	var off:= rad_to_deg(to_door.normalized().angle_to(- player.global_basis.z))
	_ok(off < 25.0, "the player was left looking at the door (%.1f degrees off)" % off)


	var turned:= absf(rad_to_deg(angle_difference(yaw_at_start, player.rotation.y)))
	_ok(turned > 140.0, "the camera came round (%.0f degrees)" % turned)
	return { "pos": player.global_position, "yaw": player.rotation.y }


func _check_clear_of_the_pile(pos: Vector3) -> void:
	var field: HayField = world.field
	if field == null:
		return
	var depth:= field.depth_floor_at(pos.x, pos.z)
	_ok(depth <= IntroSequence.ROOM_HAY_DEPTH,
		"and on the floor rather than in the pile (%.2f m of hay underfoot)" % depth)
	var gap:= _hay_ahead(pos)
	_ok(gap >= Player.CAP_RADIUS,
		"with the hay still ahead of them (%.2f m to the toe)" % gap)
	print("  [room] %s: shed %.1f m, stopped %.1f m in, %.2f m of floor left"
		% [Cfg.pile_size_id, warehouse.inner,
			warehouse.inner - absf(pos.x), gap])


func _hay_ahead(pos: Vector3) -> float:
	var field: HayField = world.field
	var dir:= door.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	var d:= 0.0
	while d < 2.0 * Cfg.FIELD_EXTENT:
		var p:= pos + dir * d
		if field.depth_floor_at(p.x, p.z) > IntroSequence.ROOM_HAY_DEPTH:
			return d
		d += Cfg.CELL
	return d


func _tick() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _inside(p: Vector3) -> bool:
	return absf(p.x) < warehouse.inner and absf(p.z) < warehouse.inner
