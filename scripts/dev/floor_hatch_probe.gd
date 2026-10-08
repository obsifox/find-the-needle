class_name DevFloorHatchProbe
extends Node


var world: Node3D
var player: Player

var _failed:= 0


func run() -> void:
	for _i in 10:
		await get_tree().physics_frame
	var hatch: FloorHatch = world.get("floor_hatch")
	_check(hatch != null, "STANDS  the world built a hatch")
	if hatch == null:
		_finish()
		return
	_check(hatch.global_position.distance_to(Cfg.PILE_CENTER) < 0.001,
		"STANDS  at the pile centre (%v)" % hatch.global_position)
	var inside:= hatch.find_child(FloorHatch.INTERIOR, true, false) as Node3D
	_check(inside != null and not inside.visible, "STANDS  shaft hidden while shut")
	var painted:= 0
	for node in hatch.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(i) != null:
				painted += 1
	_check(painted > 0, "STANDS  %d surfaces painted off the table" % painted)

	_check(hatch.is_locked(), "LOCKED  locked with no key")
	var was_demo:= Cfg.DEMO
	hatch.unlocked = true
	Cfg.DEMO = true
	_check(hatch.is_locked(), "LOCKED  the demo stays locked with the key turned")
	Cfg.DEMO = false
	_check(not hatch.is_locked(), "LOCKED  the full game opens with the key turned")
	Cfg.DEMO = was_demo
	hatch.unlocked = false

	var space:= hatch.get_world_3d().direct_space_state
	var q:= PhysicsRayQueryParameters3D.create(Vector3(0.2, 1.0, 0.1), Vector3(0.2, -1.0, 0.1))
	q.collision_mask = Cfg.L_WORLD
	var hit:= space.intersect_ray(q)
	_check(not hit.is_empty() and hit ["collider"] == hatch.lid_body(),
		"LID     the ray stops on the lid")
	if not hit.is_empty():
		_check(absf(float(hit ["position"].y) - FloorHatch.LID_TOP) < 0.004,
			"LID     at %.4f m" % float(hit ["position"].y))

	var tool:= player.build
	var across: Object = tool._obstruction(Vector3(-1.5, 0.0, 0.0), Vector3(1.5, 0.0, 0.0), 3.0)
	_check(across == hatch.keepout_body(), "KEEPOUT a belt across the hatch meets the keepout (%s)"
		% [across.name if across is Node else str(across)])
	var beside: Object = tool._obstruction(Vector3(-1.5, 0.0, 1.6), Vector3(1.5, 0.0, 1.6), 3.0)
	_check(beside != hatch.keepout_body(), "KEEPOUT a belt beside it does not")
	var high: Object = tool._obstruction(Vector3(-1.5, 3.0, 0.0), Vector3(1.5, 3.0, 0.0), 3.0)
	_check(high != hatch.keepout_body(), "KEEPOUT a belt at deck height over it does not")

	var eye:= Vector3(0.0, 1.66, 1.4)
	var look:= (Vector3(0.0, FloorHatch.LID_TOP, 0.0) - eye).normalized()
	var field: HayField = world.get("field")
	var hay_before:= field.height_at(0.0, 0.0) if field != null else 0.0
	print("[floorhatch] hay over the lid before digging: %.2f m" % hay_before)


	await _dig_to(field, 0.3)
	print("[floorhatch] hay over the lid, thin layer: %.3f m" % field.height_at(0.0, 0.0))
	eye.y = field.height_at(0.0, 1.4) + 1.66
	look = (Vector3(0.0, FloorHatch.LID_TOP, 0.0) - eye).normalized()
	_check(not hatch.is_hovered(eye, look), "BURIED  not found through a layer of hay")
	await _dig_to(field, 0.0)
	print("[floorhatch] hay over the lid after digging: %.3f m" % field.height_at(0.0, 0.0))
	eye.y = field.height_at(0.0, 1.4) + 1.66
	look = (Vector3(0.0, FloorHatch.LID_TOP, 0.0) - eye).normalized()
	_check(hatch.is_hovered(eye, look), "BURIED  found once dug out")
	_check(not hatch.is_hovered(eye, - look), "BURIED  not found looking away")

	hatch.rattle()
	var anim:= hatch.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(anim != null and anim.is_playing() and anim.current_animation == "Rattle",
		"RATTLE  the Rattle clip plays")


	var saved:= GameState.to_dict()
	_check(GameState.has_hatch and saved.get("floor_hatch", false) == true,
		"SAVES   a new game has the hatch and saves it")
	saved.erase("floor_hatch")
	GameState.from_dict(saved)
	_check(not GameState.has_hatch, "SAVES   a save from before the hatch loads without it")
	_finish()


func _dig_to(field: HayField, floor: float) -> void:
	var r:= 3.5
	var x:= - r
	while x <= r:
		var z:= - r
		while z <= r:
			if Vector2(x, z).length() <= r:
				field.carve_column(x, z, maxf(field.height_at(x, z) - floor, 0.0) + (100.0 if floor <= 0.0 else 0.0))
			z += Cfg.CELL
		x += Cfg.CELL
	for _i in 240:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print("[floorhatch] %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _finish() -> void:
	print("[floorhatch] %s" % ("PASS" if _failed == 0 else "FAIL (%d)" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)
