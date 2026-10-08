class_name DevPoleBlockProbe
extends Node


var world: Node3D
var _failed:= 0


func _check(label: String, ok: bool) -> void:
	print("[poleblock] %s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		_failed += 1


func run() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = world.player.build
	GameState.money = maxf(GameState.money, 10000000.0)
	var fwd:= Vector3.BACK
	var belt:= Vector3.UP * (Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)

	var at:= _ground(Vector3(-30.0, 0.0, 30.0))
	var pole:= builds.add_power_pole(at, 0.0)
	for i in 3:
		await get_tree().physics_frame

	var solid:= true
	for body in pole.find_children("*", "StaticBody3D", true, false):
		for c in body.get_children():
			if c is CollisionShape3D and not ((c as CollisionShape3D).shape is ConvexPolygonShape3D):
				solid = false
	_check("pole collider is solid", solid)


	_check("generator with its probe centred on the pole is refused",
		not tool._evaluate_generator(at - fwd * 0.415, fwd, Vector3.UP, false) ["ok"])
	_check("generator on the pole's foot is refused",
		not tool._evaluate_generator(at, fwd, Vector3.UP, false) ["ok"])
	_check("generator a metre beside the pole is allowed",
		tool._evaluate_generator(at + Vector3(1.0, 0.0, 0.0), fwd, Vector3.UP, false) ["ok"])
	_check("splitter 8 m away is allowed",
		tool._evaluate_splitter(at + belt + Vector3(8.0, 0.0, 0.0), fwd, Vector3.UP, false) ["ok"])


	var reach:= Cfg.SPLITTER_PORT_R + 0.1
	var leaks:= 0
	var eager:= 0
	for z in range(-14, 15):
		var row:= ""
		for x in range(-14, 15):
			var off:= Vector3(x * 0.1, 0.0, z * 0.1)
			var ok:= bool(tool._evaluate_splitter(at + belt - off, fwd, Vector3.UP, false) ["ok"])
			var gap:= Vector2(off.x, off.z).length()
			if ok and gap < reach - 0.02:
				leaks += 1
			if not ok and gap > reach + 0.02:
				eager += 1
			row += "." if ok else "#"
		print("[poleblock]   z%+.1f %s" % [z * 0.1, row])
	_check("no splitter placed over the pole (%d leaks)" % leaks, leaks == 0)
	_check("no splitter refused clear of the pole (%d)" % eager, eager == 0)


	var high_at:= _ground(Vector3(-50.0, 0.0, 30.0))
	var high:= builds.add_power_pole(high_at + Vector3.UP * 2.79, 0.0)
	_check("wye under a pole on a deck is not refused by the pole",
		not builds._post_in_disc(high_at + belt, Cfg.SPLITTER_PORT_R))
	_check("wye on the deck beside that pole would be",
		builds._post_in_disc(high_at + Vector3.UP * 2.79 + belt, Cfg.SPLITTER_PORT_R))
	builds.power_poles.erase(high)
	high.queue_free()


	var gen_at:= _ground(Vector3(-30.0, 0.0, 60.0))
	builds.add_generator(gen_at, 0.0)
	var wye_at:= _ground(Vector3(-30.0, 0.0, 80.0)) + belt
	builds.add_splitter(wye_at, 0.0)
	for i in 3:
		await get_tree().physics_frame
	for spot: Array in [["generator's middle", gen_at],
			["generator's skid end", gen_at + fwd * 2.0],
			["wye's middle", Vector3(wye_at.x, gen_at.y, wye_at.z)],
			["space under a wye outlet arm", Vector3(wye_at.x + 0.6, gen_at.y, wye_at.z + 0.7)]]:
		var ev:= tool._evaluate_pole(spot [1], Vector3.UP)
		_check("pole in the %s is refused (%s)" % [spot [0], ev ["reason"]], not ev ["ok"])

	print("[poleblock] %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _ground(at: Vector3) -> Vector3:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 20.0)
	q.collision_mask = Cfg.L_WORLD
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3(at.x, 0.0 if hit.is_empty() else (hit ["position"] as Vector3).y, at.z)
