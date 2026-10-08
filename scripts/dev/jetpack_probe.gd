class_name DevJetpackProbe
extends Node


var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func run() -> void:
	await _frames(60)
	print("[jetpack] build: %s, pile: %s" % ["demo" if Cfg.DEMO else "full", Cfg.pile_size_id])
	player.capture_mouse(true)
	_card_case()
	await _no_card_case()
	if Cfg.DEMO:
		_demo_save_case()
	else:
		Tech.grant("jetpack", 1)
		_ok(Tech.has_jetpack(), "a granted card is a jetpack worn")
		await _bounce_case()
		await _drain_case()
		await _recharge_case()
		await _air_case()
		_save_case()
		await _brick_case()
		await _pen_case()
		await _eave_case()
		await _sky_case()
		await _mountain_case()
	_release_keys()
	print("\n[jetpack] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _card_case() -> void:
	print("\n=== the card ===")
	_ok(TechTree.has_id("jetpack"), "there is a jetpack card")
	_ok(TechTree.is_demo("jetpack") == Cfg.DEMO,
		"it is %s" % ("a demo padlock" if Cfg.DEMO else "for sale"))
	if Cfg.DEMO:
		Tech.grant("jetpack", 1)
		_ok(not Tech.is_unlocked("jetpack"), "a free grant does not hand the demo the card")
		_ok(not Tech.has_jetpack(), "and Tech.has_jetpack says no")
	else:
		_ok(is_equal_approx(Tech.next_cost("jetpack"), Cfg.JETPACK_CARD_COST),
			"it costs $%d" % int(Cfg.JETPACK_CARD_COST))


func _no_card_case() -> void:
	print("\n=== no card, no thrust ===")
	Tech.reset()
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	await _land_at(_floor_spot())
	var base:= player.global_position.y
	var peak:= await _jump_then_hold(90)
	_ok(peak - base < 1.0,
		"jump and a second press held tops out at %.2f m, a plain hop" % (peak - base))
	_ok(not player.jetpack.is_thrusting(), "and nothing is lit")
	_ok(is_equal_approx(GameState.jetpack_fuel, Cfg.JETPACK_TANK_SECONDS),
		"and nothing was spent")


func _demo_save_case() -> void:
	print("\n=== a full save opened in the demo ===")
	var d:= GameState.to_dict()
	d ["jetpack_fuel"] = 7.0
	GameState.from_dict(d)
	_ok(is_zero_approx(GameState.jetpack_fuel), "the demo does not load a tank of fuel")


func _bounce_case() -> void:
	print("\n=== holding jump from the ground is a bounce ===")
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	await _land_at(_floor_spot())
	var base:= player.global_position.y
	var peak:= base
	var lit:= 0
	Input.action_press("jump")
	for i in 120:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
		if player.jetpack.is_thrusting():
			lit += 1
	Input.action_release("jump")
	_ok(lit == 0, "two seconds of jump held from the floor lit the jet %d times" % lit)
	_ok(peak - base < 1.2, "and bounced to %.2f m, no higher than a hop" % (peak - base))
	_ok(is_equal_approx(GameState.jetpack_fuel, Cfg.JETPACK_TANK_SECONDS),
		"and spent nothing")


func _drain_case() -> void:
	print("\n=== thrust drains the tank ===")
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	await _land_at(_floor_spot())
	var base:= player.global_position.y
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	await _frames(6)
	var before:= GameState.jetpack_fuel
	var lit:= 0
	var fastest:= 0.0
	var ticks:= 60
	Input.action_press("jump")
	for i in ticks:
		await get_tree().physics_frame
		if player.jetpack.is_thrusting():
			lit += 1
		fastest = maxf(fastest, player.velocity.y)
	Input.action_release("jump")
	var spent:= before - GameState.jetpack_fuel
	var step:= 1.0 / float(Engine.physics_ticks_per_second)
	_ok(lit >= ticks - 2, "a press in the air lit the jet for %d of %d ticks" % [lit, ticks])
	_ok(absf(spent - float(lit) * step) < 0.02,
		"%d ticks of thrust spent %.3f s of tank" % [lit, spent])
	var rise:= player.global_position.y - base
	_ok(rise > 1.5, "and climbed %.2f m, well past a jump" % rise)
	var cap:= maxf(Cfg.JETPACK_CLIMB_MAX, Tech.jump_velocity(Player.JUMP_VELOCITY, Player.GRAVITY))
	_ok(fastest <= cap + 0.05, "never faster up than %.2f m/s (%.2f)" % [cap, fastest])
	await _frames(3)
	_ok(not player.jetpack.is_thrusting(), "letting go puts the jet out")


func _recharge_case() -> void:
	print("\n=== the tank fills on the ground, after the delay ===")
	await _land_at(_floor_spot())
	GameState.jetpack_fuel = 2.0
	await _secs(0.5)
	_ok(is_equal_approx(GameState.jetpack_fuel, 2.0),
		"half a second after landing the tank has not moved (%.3f)" % GameState.jetpack_fuel)
	await _secs(1.0)
	var at:= GameState.jetpack_fuel
	await _secs(1.0)
	var gained:= GameState.jetpack_fuel - at
	var want:= Cfg.JETPACK_TANK_SECONDS / Cfg.JETPACK_RECHARGE_SECONDS
	_ok(absf(gained - want) < 0.05,
		"then it fills at %.2f s a second (%.2f)" % [want, gained])


func _air_case() -> void:
	print("\n=== tap, fall, tap never fills it ===")
	GameState.jetpack_fuel = 4.0
	await _land_at(_floor_spot())
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	var climbed:= false
	var worst:= 0.0
	var last:= GameState.jetpack_fuel
	for cycle in 12:
		await _frames(6)
		Input.action_press("jump")
		await _frames(4)
		Input.action_release("jump")
		if not player.is_on_floor():
			climbed = true
			worst = maxf(worst, GameState.jetpack_fuel - last)
		last = GameState.jetpack_fuel
	_ok(climbed, "the taps kept the player off the ground")
	_ok(worst <= 0.0, "and the tank never rose while in the air (worst %+.4f)" % worst)
	await _land_at(_floor_spot())


func _save_case() -> void:
	print("\n=== the tank is saved ===")
	GameState.jetpack_fuel = 3.75
	var d:= GameState.to_dict()
	GameState.jetpack_fuel = 9.0
	GameState.from_dict(d)
	_ok(is_equal_approx(GameState.jetpack_fuel, 3.75),
		"3.75 s round trips through to_dict and from_dict (%.2f)" % GameState.jetpack_fuel)
	var old:= d.duplicate()
	old.erase("jetpack_fuel")
	GameState.from_dict(old)
	_ok(is_equal_approx(GameState.jetpack_fuel, Cfg.JETPACK_TANK_SECONDS),
		"a save from before the jetpack loads a full tank")
	GameState.from_dict(d)


func _brick_case() -> void:
	print("\n=== an eco brick fills the tank ===")
	await _land_at(_floor_spot())
	var props: PropManager = world.props
	GameState.jetpack_fuel = 2.0
	var brick:= _spawn_brick(props)
	await _frames(2)
	player.carry.take(brick)
	await _frames(2)
	_press_interact()
	await _frames(3)
	_ok(not player.carry.is_carrying(), "E with a brick and a low tank empties the hands")
	_ok(not is_instance_valid(brick) or not props.items.has(brick), "the brick is gone")
	_ok(player.jetpack.is_full(), "and the tank is full")

	var second:= _spawn_brick(props)
	await _frames(2)
	player.carry.take(second)
	await _frames(2)
	_press_interact()
	await _frames(3)
	_ok(not player.carry.is_carrying(), "E with a full tank still lets go")
	_ok(is_instance_valid(second) and props.items.has(second),
		"and puts the brick down instead of eating it")
	if is_instance_valid(second):
		props.remove(second)


func _spawn_brick(props: PropManager) -> Carryable:
	var at:= player.global_position + Vector3(0.0, 1.2, 0.0) - player.global_transform.basis.z * 0.8
	return props.spawn("eco_brick", Transform3D(Basis.IDENTITY, at))


func _pen_case() -> void:
	print("\n=== out over the pen fence ===")
	var shed:= player.warehouse
	var fence:= shed.yard_fence() if shed != null else null
	if fence == null:
		_ok(false, "the yard has a pen to fly out of")
		return
	var spot:= _pen_spot(fence, shed)
	if spot == Vector3.INF:
		_ok(false, "found ground inside the pen")
		return
	var out:= _way_out(fence, shed, spot)
	await _land_at(spot)
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	_face(out)
	var got:= await _fly(spot.y + 30.0, 20.0, fence)
	_ok(got ["peak"] > spot.y + 25.0,
		"climbed past where the old pen stopped (%.1f m)" % (got ["peak"] - spot.y))
	_held(got, out, "the fence")


func _eave_case() -> void:
	print("\n=== high over the shed, and off an eave ===")
	var shed:= player.warehouse
	var fence:= shed.yard_fence() if shed != null else null
	if fence == null:
		_ok(false, "the yard has a shed to fly over")
		return
	var start:= _floor_spot()
	start.y = 24.0
	var out:= _way_out(fence, shed, start)
	_release_keys()
	player.velocity = Vector3.ZERO
	player.global_position = start
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS

	Input.action_press("jump")
	var moved:= false
	var last:= player.global_position
	for i in 60:
		await get_tree().physics_frame
		if player.global_position.distance_to(last) > 3.0:
			moved = true
		last = player.global_position
	_ok(not moved, "hanging twenty metres over the shed does not respawn anybody")
	_face(out)
	var got:= await _fly(- INF, 25.0, fence)
	_held(got, out, "the ring past the eave")


func _sky_case() -> void:
	print("\n=== a kilometre up, and out ===")
	var shed:= player.warehouse
	var fence:= shed.yard_fence() if shed != null else null
	if fence == null:
		_ok(false, "the yard has a ring to fly into")
		return


	var out:= _way_out(fence, shed, _floor_spot())
	var start:= out * (shed.inner - 3.0) + Vector3.UP * 1000.0
	_release_keys()
	player.velocity = Vector3.ZERO
	player.global_position = start
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	_face(out)
	var got:= await _fly(- INF, 8.0, fence)
	_held(got, out, "the ring a kilometre up")


func _held(got: Dictionary, dir: Vector3, what: String) -> void:
	_ok(not got ["respawned"], "flying at %s did not teleport the player%s"
		% [what, "" if not got.has("jump") else " (moved %s)" % got ["jump"]])
	_ok(not got ["escaped"], "and they were never over the field (first at %v)"
		% [got ["escaped_at"]])
	var gap:= _wall_ahead(got ["pressed"], dir)
	_ok(gap < 0.3, "and a wall stopped them (%.2f m from it, still pushing)" % gap)


func _wall_ahead(at: Vector3, dir: Vector3) -> float:
	var from:= at + Vector3.UP * 1.0
	var q:= PhysicsRayQueryParameters3D.create(from, from + dir * 5.0)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PEN
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	return from.distance_to(hit ["position"]) - Player.CAP_RADIUS


func _fly(height: float, limit: float, fence: YardFence = null) -> Dictionary:
	var out:= { "respawned": false, "escaped": false, "escaped_at": Vector3.ZERO,
		"peak": - INF, "pressed": player.global_position }
	if player.is_on_floor():
		Input.action_press("jump")
		await _frames(4)
		Input.action_release("jump")
		await _frames(6)
	Input.action_press("jump")
	var forward:= height == - INF
	if forward:
		Input.action_press("move_forward")
	var last:= player.global_position
	var t:= 0.0
	var step:= 1.0 / float(Engine.physics_ticks_per_second)
	while t < limit:
		await get_tree().physics_frame
		t += step
		out ["peak"] = maxf(float(out ["peak"]), player.global_position.y)
		if not forward and player.global_position.y >= height:
			forward = true

			GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
			Input.action_press("move_forward")
		var p:= player.global_position
		if fence != null and not out ["escaped"] and not _inside_ring(fence, p, -0.05):
			out ["escaped"] = true
			out ["escaped_at"] = p
		out ["pressed"] = p
		var jumped:= p.distance_to(last) > 3.0
		if jumped:
			out ["jump"] = "%v to %v at %.2f s" % [last, p, t]
		last = p
		if jumped and _in_shed(p):
			out ["respawned"] = true
			break
	_release_keys()
	return out


func _mountain_case() -> void:
	if not Cfg.pile_size_id.to_lower().contains("mountain"):
		print("\n=== off the crown of THE MOUNTAIN: skipped, run with --pile mountain ===")
		return
	print("\n=== off the crown of THE MOUNTAIN ===")
	var field: HayField = world.field
	var crown:= Vector3(0.0, field.height_at(0.0, 0.0), 0.0)
	await _land_at(crown)
	_ok(player.is_on_floor(), "standing on the crown at %.1f m" % crown.y)
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	var base:= player.global_position.y
	var peak:= await _jump_then_hold(90)
	_ok(peak - base > 2.0, "and thrust still lifts off it (%.1f m)" % (peak - base))
	await _land_at(_floor_spot())


func _floor_spot() -> Vector3:
	return Vector3(13.4, 0.05, 8.0)


func _in_shed(p: Vector3) -> bool:
	var shed:= player.warehouse
	return shed != null and absf(p.x) <= shed.inner and absf(p.z) <= shed.inner


func _pen_spot(fence: YardFence, shed: Warehouse) -> Vector3:
	var best:= Vector3.INF
	var best_d:= INF
	var reach:= shed.inner + 60.0
	var x:= - reach
	while x <= reach:
		var z:= - reach
		while z <= reach:
			var p:= Vector3(x, 0.0, z)


			if _inside_ring(fence, p, 2.0) and not _in_shed(p):
				var d:= maxf(absf(x), absf(z)) - shed.inner
				if d > 4.0 and d < best_d:
					best_d = d
					best = p
			z += 2.0
		x += 2.0
	if best == Vector3.INF:
		return best
	best.y = _ground_y(best)
	return best


func _inside_ring(fence: YardFence, p: Vector3, margin: float) -> bool:
	var l:= fence.to_local(p)
	return fence._in_plan(Vector2(l.x, l.z), - margin)


func _way_out(fence: YardFence, shed: Warehouse, from: Vector3) -> Vector3:
	for dir: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var far:= from + dir * (shed.inner + 40.0)
		if not fence.encloses(far) and not _in_shed(far):
			return dir
	return Vector3(1, 0, 0)


func _ground_y(p: Vector3) -> float:
	var space:= player.get_world_3d().direct_space_state
	var q:= PhysicsRayQueryParameters3D.create(p + Vector3.UP * 40.0, p + Vector3.DOWN * 20.0)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	var hit:= space.intersect_ray(q)
	return float((hit ["position"] as Vector3).y) if not hit.is_empty() else 0.0


func _face(dir: Vector3) -> void:
	player.rotation = Vector3(0.0, atan2(- dir.x, - dir.z), 0.0)
	player.head.rotation.x = 0.0


func _land_at(p: Vector3) -> void:
	_release_keys()
	player.velocity = Vector3.ZERO
	player.global_position = p + Vector3(0.0, 0.1, 0.0)
	for i in 180:
		await get_tree().physics_frame
		if i > 5 and player.is_on_floor():
			break
	await _frames(3)


func _jump_then_hold(hold: int) -> float:
	var peak:= player.global_position.y
	Input.action_press("jump")
	for i in 4:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release("jump")
	for i in 6:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_press("jump")
	for i in hold:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release("jump")
	return peak


func _press_interact() -> void:
	var ev:= InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	player._unhandled_input(ev)


func _release_keys() -> void:
	for a: String in ["jump", "move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await _frames(int(ceil(s * float(Engine.physics_ticks_per_second))))
