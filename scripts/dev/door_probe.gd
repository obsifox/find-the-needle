class_name DevDoorProbe
extends Node


var warehouse: Warehouse
var door: BayDoor
var map: MapMenu

var world: Node3D
var player: Player


var hud: Hud
var quests: QuestPanel


const NOT_GEOMETRY:= ["Trigger_DoorZone"]


var _pose:= { }


func run() -> void:
	var fails:= 0
	fails += _check_model()
	fails += _check_seat()
	fails += _check_columns()
	fails += _check_follows_the_wall()
	fails += _check_reach()
	fails += _finished("let in", await _check_let_in())
	fails += _check_countdown()


	fails += _finished("expiry", await _check_expiry())
	fails += _finished("escapement", await _check_escapement())
	fails += _check_board()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _finished(what: String, result: Variant) -> int:
	if typeof(result) == TYPE_INT:
		return int(result)
	print("  FAIL  the %s check never finished -- see the error above it" % what)
	return 1


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	Tech.reset()
	await _stand_at_door()
	await _shot(out_dir, "door_prompt.png")


	_hide_ui(hud)
	_hide_ui(quests)
	await _look_from(CLOCK_EYE, CLOCK_AIM)
	await _shot(out_dir, "door_clock.png")


	await _open_and_settle()
	await _shot(out_dir, "door_clock_open.png")
	door.snap_shut()
	_show_ui(hud)
	_show_ui(quests)
	await _stand_at_door()
	if map != null:
		map.set_open(true)
		await _shot(out_dir, "door_board.png")
		map.set_open(false)
	Tech.grant("yard_space", TechTree.max_rank("yard_space"))


	await get_tree().process_frame
	await _stand_at_door()
	await _shot(out_dir, "door_extended.png")
	_hide_ui(hud)
	_hide_ui(quests)
	await _look_from(CLOCK_EYE, CLOCK_AIM)
	await _open_and_settle()
	await _shot(out_dir, "door_extended_open.png")
	door.snap_shut()
	Tech.reset()
	get_tree().quit(0)


const CARD_SHOTS:= [
	{ "eye": Vector3(14.8, 7.2, 12.0), "at": Vector3(-3.0, 2.4, -4.0), "name": "yard_a.png" },
	{ "eye": Vector3(15.4, 8.2, 8.0), "at": Vector3(-4.0, 1.8, -3.0), "name": "yard_b.png" },
	{ "eye": Vector3(13.0, 6.2, 15.4), "at": Vector3(-4.0, 2.6, -2.0), "name": "yard_c.png" },
]


func shoot_card(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	Tech.reset()


	_hide_ui(hud)
	_hide_ui(quests)
	for shot: Dictionary in CARD_SHOTS:
		if player != null:
			var eye: Vector3 = shot ["eye"]
			player.global_position = eye
			player.look_at_from_position(eye, shot ["at"], Vector3.UP)
			player.rotation.x = 0.0
			if player.head != null:
				var to_at: Vector3 = (shot ["at"] as Vector3) - eye
				var flat:= Vector2(to_at.x, to_at.z).length()
				player.head.rotation.x = atan2(to_at.y, flat)
		await _shot(out_dir, str(shot ["name"]))
	get_tree().quit(0)


static func _hide_ui(node: CanvasItem) -> void:
	_set_ui(node, false)


static func _show_ui(node: CanvasItem) -> void:
	_set_ui(node, true)


static func _set_ui(node: CanvasItem, on: bool) -> void:
	if node == null:
		return
	var layer:= node.get_parent() as CanvasLayer
	if layer != null:
		layer.visible = on
	else:
		node.visible = on


const SHOT_STANDOFF:= 2.9


const SHOT_AIM_HEIGHT:= 3.4


const CLOCK_EYE:= Vector3(3.6, 0.0, 4.4)
const CLOCK_AIM:= Vector3(0.0, 7.98, 0.0)


func _stand_at_door(standoff:= SHOT_STANDOFF, aim_height:= SHOT_AIM_HEIGHT) -> void:
	if player == null or door == null:
		return


	var away:= door.global_transform.basis.z.normalized()
	_place(door.interact_point() + away * standoff,
		door.to_global(Vector3(0.0, aim_height, 0.0)))


func _look_from(local_eye: Vector3, local_aim: Vector3) -> void:
	if player == null or door == null:
		return
	_place(door.to_global(local_eye), door.to_global(local_aim))


func _place(at: Vector3, aim: Vector3) -> void:
	player.global_position = at
	player.look_at_from_position(at, aim, Vector3.UP)
	player.rotation.x = 0.0
	var eye:= at + Vector3.UP * (player.head.position.y if player.head != null else 1.6)
	var to_aim:= aim - eye
	var flat:= Vector2(to_aim.x, to_aim.z).length()
	player.set_look(player.rotation.y, atan2(to_aim.y, flat))


	_pose = { "at": at, "aim": aim }


func _hold_pose() -> void:
	if _pose.is_empty() or player == null:
		return
	var at: Vector3 = _pose ["at"]
	var aim: Vector3 = _pose ["aim"]
	player.global_position = at
	player.look_at_from_position(at, aim, Vector3.UP)
	player.rotation.x = 0.0
	var eye:= at + Vector3.UP * (player.head.position.y if player.head != null else 1.6)
	var to_aim:= aim - eye
	player.set_look(player.rotation.y,
		atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))


func _open_and_settle() -> void:
	door.set_open_amount(1.0)
	var env:= get_viewport().find_world_3d().environment
	if env != null and env.sdfgi_enabled:
		env.sdfgi_enabled = false
		await get_tree().process_frame
		await get_tree().process_frame
		env.sdfgi_enabled = true
	await get_tree().create_timer(4.0).timeout


func _shot(out_dir: String, name: String) -> void:


	for _i in 30:
		await get_tree().process_frame
		_hold_pose()
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("[doorshot] wrote %s" % path)


func _check_model() -> int:
	print("\n-- model --")
	var bad:= 0
	if door == null:
		return _fail("no bay door was handed to the probe")

	for n: String in [BayDoor.N_PLAYER_STAND, BayDoor.N_FOCUS, BayDoor.N_TRIGGER]:
		if door.find_child(n, true, false) == null:
			bad += _fail(("the model has no %s -- rebuild it with " % n)
				+ "blender -b -P assets/blender/_build/door.py")


	var trigger:= door.find_child(BayDoor.N_TRIGGER, true, false) as VisualInstance3D
	if trigger != null and trigger.visible:
		bad += _fail("the trigger volume is visible -- it will render as a white box")


	var bodies:= door.find_children("*", "StaticBody3D", true, false)
	if bodies.size() < 5:
		bad += _fail("%d collision bodies, expected 5 (leaf, 2 jambs, 2 bollards)"
			% bodies.size())


	var unskinned: Array [String] = []
	var surfaces:= 0
	for mi: MeshInstance3D in _visible_meshes():
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			if mi.get_surface_override_material(i) == null:
				unskinned.append(mi.name)
	if not unskinned.is_empty():
		bad += _fail("unskinned: %s" % ", ".join(unskinned))
	print("  %d bodies, %d skinned surfaces" % [bodies.size(), surfaces])
	return bad


const CLOCK_CASES:= [
	[0, "00:00:00"], [1, "00:00:01"], [59, "00:00:59"], [60, "00:01:00"],
	[3599, "00:59:59"], [3600, "01:00:00"], [86399, "23:59:59"],
	[86400, "24:00:00"],
]


const CLOCK_SPENT:= [[0, 86400], [3600, 82800], [86400, 0], [999999, 0]]


const OTHER_SLOTS:= [[1, 8 * 3600], [2, 20 * 3600]]


func _check_countdown() -> int:
	print("\r\n-- countdown board --")
	var bad:= 0
	if door == null:
		return _fail("no bay door was handed to the probe")
	var board:= door.countdown
	if board == null:
		return _fail(("the door built no countdown board -- rebuild the model with "
			+ "blender -b -P assets/blender/_build/door.py"))


	var marker:= door.find_child(BayDoor.N_CLOCK, true, false) as Node3D
	if marker == null:
		bad += _fail("the model has no %s" % BayDoor.N_CLOCK)
	else:
		var off:= board.global_position.distance_to(marker.global_position)
		if off > 0.02:
			bad += _fail("the readout sits %.0f mm off %s"
				% [off * 1000.0, BayDoor.N_CLOCK])


	var ghost:= board.ghost_bounds()
	if ghost.size.x <= 0.0:
		bad += _fail("the ghost layer is empty -- nothing will be drawn")
	elif ghost.size.x > CountdownBoard.SCR_W - 0.06:
		bad += _fail("the readout is %.2f m wide and the aperture is %.2f -- it runs under the bezel"
			% [ghost.size.x, CountdownBoard.SCR_W])
	elif ghost.size.y > CountdownBoard.SCR_H - 0.04:
		bad += _fail("the readout is %.2f m tall in a %.2f m aperture"
			% [ghost.size.y, CountdownBoard.SCR_H])

	for c: Array in CLOCK_CASES:
		var got:= CountdownBoard.format_clock(int(c [0]))
		if got != str(c [1]):
			bad += _fail("%d s formatted as %s, expected %s" % [c [0], got, c [1]])


	var slot:= board.slot()
	var was:= Profile.countdown_spent.duplicate()

	for c: Array in CLOCK_SPENT:
		Profile.countdown_spent [slot] = int(c [0])
		var left:= board.remaining()
		if left != int(c [1]):
			bad += _fail("%d s of play left %d on the clock, expected %d"
				% [c [0], left, c [1]])


	Profile.countdown_spent [slot] = 0
	for o: Array in OTHER_SLOTS:
		Profile.countdown_spent [int(o [0])] = int(o [1])
	if board.remaining() != CountdownBoard.TOTAL_SECONDS:
		bad += _fail("time played in another slot came off this board: %s"
			% CountdownBoard.format_clock(board.remaining()))
	else:
		print("  slot %d reads %s, with %s and %s standing on the other two"
			% [slot, CountdownBoard.format_clock(board.remaining()),
				CountdownBoard.format_clock(
					CountdownBoard.TOTAL_SECONDS - int(OTHER_SLOTS [0] [1])),
				CountdownBoard.format_clock(
					CountdownBoard.TOTAL_SECONDS - int(OTHER_SLOTS [1] [1]))])


	if Profile.countdown_slot != slot:
		bad += _fail("the career file is counting into slot %d, not %d"
			% [Profile.countdown_slot, slot])

	Profile.countdown_spent = was


	if not board.armed:
		bad += _fail("the world never armed the board -- it can never announce itself")
	if board.expired.get_connections().is_empty():
		bad += _fail("nothing is listening for `expired` -- the board runs out to nobody")
	print("  reads %s, %.2f x %.2f m of digits in a %.2f x %.2f aperture"
		% [board.reading(), ghost.size.x, ghost.size.y,
			CountdownBoard.SCR_W, CountdownBoard.SCR_H])
	return bad


func _check_escapement() -> int:
	print("\r\n-- escapement --")
	if door == null or door.countdown == null:
		return _fail("no countdown board to listen to")
	if player == null:
		return _fail("the probe was handed no player, so nothing can be in earshot")
	var board:= door.countdown
	var bad:= 0

	for key: String in ["clock_tick", "clock_tock"]:
		var files: Variant = Audio.SFX_LIB.get(key)
		if files == null or (files as Array).is_empty():
			bad += _fail("Audio has no `%s`" % key)
			continue
		for path: String in files:
			if not ResourceLoader.exists(path):
				bad += _fail("`%s` points at %s, which is not there" % [key, path])

	var slot:= board.slot()
	var was_secs:= Profile.countdown_spent [slot]
	var was_pos:= player.global_position

	player.global_position = door.interact_point()
	var heard:= await _struck(board, 4)
	if heard.has(""):
		bad += _fail("a second passed in silence with the player at the door: %s"
			% str(heard))
	elif heard [0] == heard [1]:
		bad += _fail("the escapement struck %s twice running" % heard [0])
	elif not (heard.has("clock_tick") and heard.has("clock_tock")):
		bad += _fail("only one half of the escapement is ever used: %s" % str(heard))
	else:
		print("  in earshot: %s" % " ".join(heard))


	var away:= door.global_transform.basis.z.normalized()
	player.global_position = door.interact_point() + away * (CountdownBoard.HEARD_WITHIN + 6.0)
	var far:= await _struck(board, 2)
	if far != ["", ""]:
		bad += _fail("the board was heard from %.0f m away: %s"
			% [CountdownBoard.HEARD_WITHIN + 6.0, str(far)])
	else:
		print("  out of earshot: silent past %.0f m" % CountdownBoard.HEARD_WITHIN)


	player.global_position = door.interact_point()
	Profile.countdown_spent [slot] = CountdownBoard.TOTAL_SECONDS - 1
	await _settle()
	var before_last:= board.strike_count()
	var last:= await _struck(board, 1)
	if board.strike_count() == before_last:
		bad += _fail("the last second before zero passed in silence")
	var spent_at:= board.strike_count()
	for _i in 3:
		Profile.countdown_spent [slot] += 1
		await _settle()
	if board.strike_count() != spent_at:
		bad += _fail("a spent board struck %d more times"
			% (board.strike_count() - spent_at))
	else:
		print("  runs down: %s on the last second, then nothing" % last [0])

	Profile.countdown_spent [slot] = was_secs
	player.global_position = was_pos
	await get_tree().process_frame
	return bad


func _struck(board: CountdownBoard, count: int) -> Array [String]:
	var out: Array [String] = []
	for _i in count:
		Profile.countdown_spent [board.slot()] += 1
		await _settle()
		out.append(board.last_strike())
	return out


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check_expiry() -> int:
	print("\r\n-- running out --")
	if door == null or door.countdown == null:
		return _fail("no countdown board to run out")
	if hud == null:
		return _fail("the probe was handed no HUD, so it cannot hear the board")
	var board:= door.countdown
	var slot:= board.slot()
	var was_secs:= Profile.countdown_spent [slot]
	var was_seen:= Profile.countdown_seen_slots [slot]
	var before:= hud.toast_text()

	Profile.countdown_seen_slots [slot] = false
	Profile.countdown_spent [slot] = CountdownBoard.TOTAL_SECONDS + 60


	await get_tree().process_frame
	await get_tree().process_frame

	var bad:= 0
	if not board.is_spent():
		bad += _fail("a career past twenty four hours left the board still running")
	if board.reading() != "00:00:00":
		bad += _fail("a spent board reads %s" % board.reading())
	var said:= hud.toast_text()
	if said == before:
		bad += _fail("the board ran out and said nothing")
	elif not Profile.countdown_seen_in(slot):
		bad += _fail("it spoke without latching, so it will say it again tomorrow")
	elif Profile.countdown_seen_in(slot + 1):
		bad += _fail("running out in slot %d latched the next slot too" % slot)
	else:
		print("  said: %s" % said)

	Profile.countdown_spent [slot] = was_secs
	Profile.countdown_seen_slots [slot] = was_seen

	await get_tree().process_frame
	if board.reading() == "00:00:00":
		bad += _fail("the board stayed at zero after the career was put back")
	return bad


func _visible_meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if door == null:
		return out
	for n in door.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null or NOT_GEOMETRY.has(mi.name):
			continue
		out.append(mi)
	return out


func _check_seat() -> int:
	print("\n-- seat --")
	var bad:= 0
	if door == null or warehouse == null:
		return _fail("no door or no warehouse")


	if not is_equal_approx(door.position.x, warehouse.inner):
		bad += _fail("seated at x %.3f, the wall face is at %.3f"
			% [door.position.x, warehouse.inner])


	var want_y:= warehouse.floor_y(door.position)
	if not is_equal_approx(door.position.y, want_y):
		bad += _fail("floor at %.3f, expected %.3f" % [door.position.y, want_y])


	var forward:= door.global_transform.basis.z.normalized()
	if forward.dot(Vector3.LEFT) < 0.999:
		bad += _fail("the door faces %s, expected -X (into the shed)" % forward)


	var centre:= warehouse.bay_centre(door.along)
	if not is_equal_approx(door.position.z, centre):
		bad += _fail("seated at z %.3f, the nearest bay centre is %.3f"
			% [door.position.z, centre])
	print("  x %.2f  y %.3f  z %.2f, facing into the shed"
		% [door.position.x, door.position.y, door.position.z])
	return bad


func _column_boxes() -> Array [AABB]:
	var out: Array [AABB] = []
	if warehouse == null or door == null:
		return out
	for child in warehouse.get_children():
		var root:= child as Node3D
		if root == null:
			continue
		for n in root.get_children():
			var mi:= n as MeshInstance3D
			if mi == null:
				continue
			var box:= mi.mesh as BoxMesh
			if box == null or not is_equal_approx(box.size.y, Warehouse.WALL_H):
				continue


			var half:= box.size * 0.5
			var local:= AABB()
			for i in 8:
				var corner:= Vector3(
					half.x if i & 1 else - half.x,
					half.y if i & 2 else - half.y,
					half.z if i & 4 else - half.z)
				var p:= door.to_local(root.global_position + corner)
				if i == 0:
					local = AABB(p, Vector3.ZERO)
				else:
					local = local.expand(p)


			if absf(local.position.x + local.size.x * 0.5) < 6.0 and local.position.z > -1.0 and local.position.z < 2.0:
				out.append(local)
	return out


func _check_columns() -> int:
	print("\n-- column clearance --")
	var bad:= 0
	if door == null or warehouse == null:
		return _fail("no door or no warehouse")

	var top:= TechTree.max_rank("yard_space")
	var worst:= INF
	var worst_rank:= 0
	for rank in range(top + 1):
		Tech.reset()
		if rank > 0:
			Tech.grant("yard_space", rank)
		var columns:= _column_boxes()
		if columns.is_empty():
			bad += _fail("rank %d: found no columns beside the door to measure against"
				% rank)
			continue
		var clash:= ""
		var closest:= INF
		for mi: MeshInstance3D in _visible_meshes():
			var xf:= door.global_transform.affine_inverse() * mi.global_transform
			for surface in mi.mesh.get_surface_count():
				var arrays:= mi.mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
				for v: Vector3 in verts:
					var p:= xf * v
					for col: AABB in columns:
						if col.has_point(p):
							clash = mi.name


						if p.z >= col.position.z and p.z <= col.position.z + col.size.z:
							var edge: float = col.position.x if p.x < 0.0 else col.position.x + col.size.x
							closest = minf(closest, absf(edge - p.x))
		if clash != "":
			bad += _fail("rank %d: '%s' is inside a column" % [rank, clash])
		if closest < worst:
			worst = closest
			worst_rank = rank
	Tech.reset()
	if worst < 0.02:
		bad += _fail("only %.0f mm of clearance at rank %d -- too close to call"
			% [worst * 1000.0, worst_rank])
	print("  %d ranks walked, tightest gap %.0f mm at rank %d"
		% [top + 1, worst * 1000.0, worst_rank])
	return bad


func _check_follows_the_wall() -> int:
	print("\n-- follows the wall --")
	var bad:= 0
	if door == null or warehouse == null:
		return _fail("no door or no warehouse")

	Tech.reset()


	var base_x:= Cfg.yard_inner_for_pile()
	var stock_x:= door.position.x
	var stock_z:= door.position.z
	if not is_equal_approx(stock_x, base_x):
		bad += _fail("a fresh run seats the door at x %.2f, the wall is at %.2f"
			% [stock_x, base_x])

	var top:= TechTree.max_rank("yard_space")
	for rank in range(1, top + 1):
		Tech.reset()
		Tech.grant("yard_space", rank)
		if not is_equal_approx(door.position.x, warehouse.inner):
			bad += _fail("rank %d: wall at %.2f, door at %.2f"
				% [rank, warehouse.inner, door.position.x])
			break
		if not is_equal_approx(door.position.z, warehouse.bay_centre(door.along)):
			bad += _fail("rank %d: door at z %.2f is not on a bay centre (%.2f)"
				% [rank, door.position.z, warehouse.bay_centre(door.along)])
			break
		if not is_equal_approx(door.position.y, warehouse.floor_y(door.position)):
			bad += _fail("rank %d: door floats at y %.3f" % [rank, door.position.y])
			break

	Tech.grant("yard_space", top)
	var grown_x:= door.position.x


	Tech.reset()
	if not is_equal_approx(door.position.x, base_x):
		bad += _fail("after a reset the door stayed at x %.2f" % door.position.x)
	if not is_equal_approx(door.position.z, stock_z):
		bad += _fail("after a reset the door stayed at z %.2f" % door.position.z)
	print("  wall %.1f m -> %.1f m -> %.1f m, door with it every step"
		% [stock_x, grown_x, door.position.x])
	return bad


func _check_reach() -> int:
	print("\n-- hovering --")
	var bad:= 0
	if door == null:
		return _fail("no door")

	var stand:= door.interact_point() + Vector3.UP * 1.6
	var at_door:= (door.focus_point() - stand).normalized()
	if not door.is_hovered(stand, at_door):
		bad += _fail("standing on the door's own marker looking at it is not a hover")


	if door.is_hovered(stand, - at_door):
		bad += _fail("facing away from the door still offers E")


	var along:= door.global_transform.basis.x.normalized()
	if door.is_hovered(stand, along):
		bad += _fail("looking along the wall still offers E")


	var far:= door.focus_point() - at_door * (BayDoor.OPEN_DISTANCE + 6.0)
	if door.is_hovered(far, at_door):
		bad += _fail("the door is offered from %.0f m away" % (BayDoor.OPEN_DISTANCE + 6.0))
	print("  offered at the marker, refused facing away, along the wall, and from range")


	door.snap_shut()


	if not door.toggle() or not door.is_moving():
		bad += _fail("E on a shut door did not start it moving")


	if door.is_hovered(stand, at_door):
		bad += _fail("a door that is still moving is offered anyway")


	door.snap_shut()
	door.set_open_amount(1.0)
	if not door.is_hovered(stand, at_door):
		bad += _fail("an open door standing still is not offered")
	if not door.toggle() or not door.is_moving():
		bad += _fail("E on an open door did not start it closing")
	door.snap_shut()
	door.set_open_amount(1.0)

	door.held = true
	if door.is_hovered(stand, at_door):
		bad += _fail("the door is offered while a delivery holds it")
	door.held = false
	door.snap_shut()
	print("  worked by E when it is still, and not while it moves or a lorry has it")


	if door.prompt(stand, at_door) == "":
		bad += _fail("no words are offered at the door itself")
	if door.prompt(stand, - at_door) != "":
		bad += _fail("the prompt is shown to somebody facing away from the door")
	if door.prompt(far, at_door) != "":
		bad += _fail("the prompt is shown from %.0f m away"
			% (BayDoor.OPEN_DISTANCE + 6.0))
	if door.prompt(stand, at_door) != "Open the door":
		bad += _fail("a shut door does not offer to open")
	door.snap_shut()
	door.set_open_amount(1.0)
	if door.prompt(stand, at_door) != "Shut the door":
		bad += _fail("an open door does not offer to shut")
	door.snap_shut()
	print("  and the words follow the same rule, and change with the door")
	return bad


func _check_let_in() -> int:
	print("\n-- let in from outside --")
	var bad:= 0
	if door == null or player == null:
		return _fail("no door or no player")
	if not door.is_locked():
		print("  SKIP  the opening order is signed here, so the door is not locked")
		return 0
	door.snap_shut()
	var out_eye:= door.to_global(Vector3(0.0, 1.6, - (Warehouse.WALL_T + 2.1)))
	var in_eye:= door.interact_point() + Vector3.UP * 1.6
	var look_in:= (door.focus_point() - out_eye).normalized()
	var look_out:= (door.focus_point() - in_eye).normalized()
	if not door.is_outside(out_eye) or door.is_outside(in_eye):
		bad += _fail("is_outside has the two sides of the wall the wrong way round")
	if not door.is_hovered(out_eye, look_in):
		bad += _fail("a player 2 m outside looking at the door is not offered it")
	if door.prompt(out_eye, look_in) != "Open the door":
		bad += _fail("outside, a shut locked door does not offer to open")
	if not door.let_in() or not door.is_moving():
		bad += _fail("let_in did not start a shut locked door opening")
	door.snap_shut()
	door.set_open_amount(1.0)
	if door.prompt(out_eye, look_in) != "":
		bad += _fail("outside, an open locked door offers to shut itself on the player")
	if door.prompt(in_eye, look_out) == "":
		bad += _fail("inside, the locked door stopped offering its press")


	var was:= player.global_position
	player.global_position = door.to_global(Vector3(0.0, 0.1, -2.0))
	for i in 4:
		await get_tree().physics_frame
	if door.is_moving() or door.is_shut():
		bad += _fail("the door came down while the player was still outside")

	player.global_position = door.to_global(
		Vector3(0.0, 0.1, BayDoor.LET_IN_CLEAR + 1.0))
	for i in 4:
		await get_tree().physics_frame
	if not door.is_moving():
		bad += _fail("the door did not drop behind a player let back in")
	player.global_position = was
	door.snap_shut()
	print("  opened from outside while locked, shut behind the player once in")
	return bad


func _check_board() -> int:
	print("\n-- map board --")
	var bad:= 0
	if MapMenu.MAPS.size() < 5:
		bad += _fail("%d sites on the board, expected at least 5" % MapMenu.MAPS.size())

	var here:= 0
	var ids:= { }
	for spec: Dictionary in MapMenu.MAPS:
		var id:= str(spec.get("id", ""))
		if id == "" or ids.has(id):
			bad += _fail("site id '%s' is empty or repeated" % id)
		ids [id] = true
		if str(spec.get("name", "")) == "" or str(spec.get("blurb", "")) == "":
			bad += _fail("site '%s' has no name or no blurb" % id)


		var img:= str(spec.get("image", ""))
		if img == "" or not ResourceLoader.exists(img):
			bad += _fail("site '%s' has no picture at '%s'" % [id, img])
		if MapMenu._is_here(spec):
			here += 1
		elif Cfg.DEMO and MapMenu._is_available(spec):
			bad += _fail("site '%s' is travellable in the demo" % id)
	if here != 1:
		bad += _fail("%d sites claim to be the one the player is in, expected 1" % here)


	var panel:= MapMenu.new()
	add_child(panel)
	var locks:= 0
	var texts:= 0
	for n in panel.find_children("*", "", true, false):
		if n is MapMenu.LockIcon:
			locks += 1
		var label:= n as Label


		if label != null and label.text == tr(MapMenu.LOCKED_TEXT):
			texts += 1
	var want:= MapMenu.MAPS.size() - 1 if Cfg.DEMO else 0
	if locks != want:
		bad += _fail("%d padlocks drawn, expected %d" % [locks, want])
	if texts != want:
		bad += _fail("%d cards say '%s', expected %d" % [texts, MapMenu.LOCKED_TEXT, want])
	if panel.is_open():
		bad += _fail("the board starts open")
	panel.queue_free()
	print("  %d sites, 1 home, %d locked and saying so" % [MapMenu.MAPS.size(), locks])
	return bad
