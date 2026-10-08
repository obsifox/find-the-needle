class_name DevBeltFootProbe
extends Node


var world: Node3D
var _failed:= 0


func _check(label: String, ok: bool) -> void:
	print("[beltfoot] %s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		_failed += 1


func run() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = world.player.build
	GameState.money = maxf(GameState.money, 10000000.0)
	var fwd:= Vector3.BACK

	var kinds:= {
		"hay stairs": func(at: Vector3, body: Object) -> Dictionary:
			return tool._evaluate_stairs(at, fwd, Vector3.UP, body),
		"paint board": func(at: Vector3, body: Object) -> Dictionary:
			return tool._evaluate_paintboard(at, fwd, Vector3.UP, body),
		"work lamp": func(at: Vector3, body: Object) -> Dictionary:
			return tool._evaluate_worklamp(at, fwd, Vector3.UP, body),
	}


	var mid:= _ground(Vector3(-30.0, 0.0, 30.0))
	var belt:= builds.add_conveyor(mid + Vector3(-4.0, 0.0, 0.0), mid + Vector3(4.0, 0.0, 0.0))

	var deck_top:= _ground(Vector3(-45.0, 0.0, 30.0)) + Vector3.UP * 2.2
	var deck:= builds.add_platform(deck_top, Vector2(6.0, 6.0))
	for i in 5:
		await get_tree().physics_frame

	for kind: String in kinds:
		var judge: Callable = kinds [kind]


		var on_belt:= 0
		var let_through:= 0
		var blind:= 0
		for step in range(-70, 71):
			var hit:= _aim_down(mid + Vector3(0.0, 0.0, step * 0.01))
			if hit.is_empty() or not BuildTool._is_belt_body(hit ["collider"]):
				continue
			on_belt += 1


			if bool(judge.call(hit ["position"], null) ["ok"]):
				blind += 1
			var ev: Dictionary = judge.call(hit ["position"], hit ["collider"])
			if bool(ev ["ok"]) or str(ev ["reason"]) != tr("on a belt"):
				let_through += 1
				if let_through <= 3:
					print("[beltfoot]   %s at z%+.2f, y %.2f: ok %s, \"%s\"" % [kind,
						step * 0.01, (hit ["position"] as Vector3).y, ev ["ok"], ev ["reason"]])
		_check("%s aim lands on the belt (%d spots, %d passed with no ground test)"
			% [kind, on_belt, blind], on_belt > 0)
		_check("%s refused on the belt (%d let through)" % [kind, let_through],
			let_through == 0)


		var floor_hit:= _aim_down(mid + Vector3(0.0, 0.0, 6.0))
		var ev_floor: Dictionary = judge.call(floor_hit.get("position", mid),
			floor_hit.get("collider"))
		_check("%s allowed on the floor (%s)" % [kind, ev_floor ["reason"]], ev_floor ["ok"])


		var deck_hit:= _aim_down(deck_top)
		var ev_deck: Dictionary = judge.call(deck_hit.get("position", deck_top),
			deck_hit.get("collider"))
		_check("%s allowed on a deck (%s)" % [kind, ev_deck ["reason"]],
			builds.owner_of(deck_hit.get("collider")) == deck and bool(ev_deck ["ok"]))

	builds.demolish(belt)
	print("[beltfoot] %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _aim_down(at: Vector3) -> Dictionary:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 2.0)
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	q.collide_with_areas = false
	return world.get_world_3d().direct_space_state.intersect_ray(q)


func _ground(at: Vector3) -> Vector3:
	var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 20.0)
	q.collision_mask = Cfg.L_WORLD
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3(at.x, 0.0 if hit.is_empty() else (hit ["position"] as Vector3).y, at.z)
