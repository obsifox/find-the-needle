class_name DevSignProbe
extends Node


var world: Node3D
var player: Player
var warehouse: Warehouse
var door: BayDoor


func run() -> void:
	if world != null:
		world.block_save = true
	var fails:= 0
	fails += _check_ledger()
	fails += await _check_void()
	Tech.reset()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_ledger() -> int:
	print("\n-- ledger --")
	var stand:= world.get("stand") as HaySellingStand if world != null else null
	if stand == null:
		return _fail("no selling stand in the world")
	var labels: Array [Label3D] = []
	for n in stand.find_children("LedgerNote*", "Label3D", true, false):
		labels.append(n as Label3D)
	if labels.is_empty():
		return _fail("the ledger has nothing written in it")
	var want:= HaySellingStand.LEDGER_NOTE.split("\n").size()
	var bad:= 0
	if labels.size() != want:
		bad += _fail("%d lines written, the note has %d" % [labels.size(), want])
	var model:= stand.get_node("Model") as Node3D
	for l in labels:
		if l.text.strip_edges() == "":
			bad += _fail("%s is blank" % l.name)
			continue
		var span:= l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			l.font_size).x * l.pixel_size
		if span > HaySellingStand.LEDGER_TEXT_WIDTH + 0.001:
			bad += _fail("%s is %.3f m across %.3f m of rule" % [l.name, span,
				HaySellingStand.LEDGER_TEXT_WIDTH])

		var up:= l.global_transform.basis.z.normalized()
		if up.y < 0.99:
			bad += _fail("%s faces %s, not up" % [l.name, up])


		var at:= model.to_local(l.global_position)
		if absf(at.x + 0.85) > 0.155 or absf(at.z - 1.1) > 0.115 or absf(at.y - 1.1245) > 0.005:
			bad += _fail("%s is at %s, off the pad" % [l.name, at])
		print("  %s  %.3f m wide  %s" % [l.name, span, l.text])
	return bad


func _check_void() -> int:
	print("\n-- the void --")
	if player == null:
		return _fail("no player was handed to the probe")
	var bad:= 0


	var indoors:= await _stand_at(Vector3(13.2, 1.0, 5.6))
	var home:= await _drop_from(indoors)
	if home.y <= Player.VOID_Y:
		return _fail("the player is at y %.1f and still falling -- never caught" % home.y)
	if not player.is_on_floor():
		bad += _fail("the player was put back at y %.2f but is on nothing" % home.y)
	var drift:= _flat(home - indoors)
	if drift > 2.0:
		bad += _fail("a fall indoors put the player back %.1f m away" % drift)
	print("  indoors: fell from (%.1f, %.1f), back at (%.1f, %.1f), %.2f m away"
		% [indoors.x, indoors.z, home.x, home.z, drift])


	var apron:= await _stand_at(_apron_spot())
	print("  stood on the apron at (%.1f, %.2f, %.1f)" % [apron.x, apron.y, apron.z])
	var rescued:= await _drop_from(apron)
	if not _indoors(rescued):
		bad += _fail("a fall off the apron put the player back at (%.1f, %.1f), "
			% [rescued.x, rescued.z] + "still outside the %.1f m walls" % warehouse.inner)
	elif _flat(rescued - indoors) > 2.0:
		bad += _fail("the player came back indoors but %.1f m from the floor they left"
			% _flat(rescued - indoors))
	else:
		print("  apron: fell from (%.1f, %.1f), back inside at (%.1f, %.1f)"
			% [apron.x, apron.z, rescued.x, rescued.z])


	player._safe_seeded = false
	await _stand_at(_apron_spot())
	var spawned:= await _drop_from(player.global_position)
	if not _indoors(spawned):
		bad += _fail("with no floor remembered, the fall left the player outside")
	elif _flat(spawned - player.respawn_fallback) > 2.0:
		bad += _fail("with no floor remembered, the player landed %.1f m from the spawn"
			% _flat(spawned - player.respawn_fallback))
	else:
		print("  nothing remembered: back at the spawn (%.1f, %.1f)"
			% [spawned.x, spawned.z])
	return bad


func _stand_at(at: Vector3) -> Vector3:
	player.velocity = Vector3.ZERO
	player.global_position = at
	for _i in 30:
		await get_tree().physics_frame
	return player.global_position


func _drop_from(from: Vector3) -> Vector3:
	player.global_position = Vector3(from.x, -100.0, from.z)
	player.velocity = Vector3(0.0, -40.0, 0.0)
	for _i in 30:
		await get_tree().physics_frame
	return player.global_position


func _apron_spot() -> Vector3:
	return Vector3(warehouse.inner + 8.0, 1.2, warehouse.bay_centre(0.0) + 8.0)


func _indoors(at: Vector3) -> bool:
	return absf(at.x) <= warehouse.inner and absf(at.z) <= warehouse.inner


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	var stand:= world.get("stand") as HaySellingStand
	var model:= stand.get_node("Model") as Node3D
	var pad:= model.to_global(Vector3(-0.85, 1.12, 1.1))

	player.set_physics_process(false)


	await _shot(out_dir, "ledger_close.png", model.to_global(Vector3(-0.85, 1.66, 1.75)),
		model.to_global(Vector3(-0.85, 1.2, 0.9)))
	await _shot(out_dir, "ledger_step_back.png",
		model.to_global(Vector3(-0.55, 1.66, 2.6)), pad)
	get_tree().quit(0)


func _look_from(eye: Vector3, at: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	var to_at:= at - eye
	player.set_look(atan2(- to_at.x, - to_at.z),
		atan2(to_at.y, Vector2(to_at.x, to_at.z).length()))


func _shot(out_dir: String, shot_name: String, eye: Vector3, at: Vector3) -> void:
	for _i in 20:
		_look_from(eye, at)
		await get_tree().process_frame
	_look_from(eye, at)
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, shot_name]
	img.save_png(path)
	print("[ledgershot] wrote %s" % path)
