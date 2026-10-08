class_name DevBeltReverseProbe
extends Node


const SETTLE:= 8


const TARGET_RANGE:= 3.0


const REACHABLE_RANGE:= 1.5


const CONSOLE_RANGE:= 1.4


const DECK_HEIGHT:= 0.45


const PATIENCE:= 8.0

var world: Node3D
var player: Player

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:


	world.block_save = true
	print("--- belt reverse probe ---")
	for i in SETTLE:
		await get_tree().process_frame


	if not await _wait_until(func() -> bool: return world.hud != null):
		print("  FAIL the world never built a HUD")
		_fails += 1


	player._set_tool(Player.Tool.HAND)
	player.capture_mouse(true)
	GameState.add_money(40000.0)
	for i in SETTLE:
		await get_tree().process_frame

	await _case_flip()
	await _case_strip()
	await _case_corner()
	await _case_let_go()
	await _case_look_away()
	await _case_mouse_taken()
	await _case_module_belt()
	await _case_pick_wins()
	await _case_beats_proximity()
	await _case_save()
	await _case_arrows()

	print("--- %s ---" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _case_flip() -> void:
	print("\n=== the hold turns a run round ===")
	var run:= await _run_in_front()
	if run == null:
		return
	var was_a:= run.a
	var was_b:= run.b
	var was_travel:= run.basis_at(0.0).z

	_press(true)
	_ok(await _wait_until(func() -> bool: return player.build.reverse_progress() >= 0.0),
		"the press starts the hold")
	_ok(await _wait_until(func() -> bool: return run.a.is_equal_approx(was_b)),
		"...and the run turns round when it is served")
	_press(false)
	for i in SETTLE:
		await get_tree().physics_frame

	_ok(run.b.is_equal_approx(was_a), "the far end is where the near end was")
	_ok(run.forward.dot(was_b - was_a) < 0.0, "the heading is the other way")
	_ok(run.basis_at(0.0).z.dot(was_travel) < -0.9,
		"...and so is the direction the deck carries")
	_ok(player.build.reverse_progress() < 0.0, "the hold is over")
	await _clear()


func _case_strip() -> void:
	print("\n=== the prompt on the hint strip ===")
	var strip:= _strip()
	_ok(strip != null, "the HUD has a hint strip")
	if strip == null:
		return
	_ok(player.build.reverse_target() == null, "the crosshair starts on nothing")
	_ok(not _strip_says(strip, "Reverse belt"), "...so the bar does not offer the hold")
	var run:= await _run_in_front()
	if run == null:
		return
	_ok(_strip_says(strip, "Reverse belt"), "a run in the crosshair puts it on the bar")
	_ok(_strip_lit(strip, "Reverse belt") == false, "...unlit, because nothing is held")
	_press(true)
	_ok(await _wait_until(func() -> bool: return _strip_lit(strip, "Reverse belt")),
		"...and lit once the hold starts")
	_press(false)
	for i in SETTLE:
		await get_tree().physics_frame
	await _clear()
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(not _strip_says(strip, "Reverse belt"), "...and it goes when the run does")


func _case_corner() -> void:
	print("\n=== the bend beside it is refitted ===")
	var base:= _ground_in_front()
	var p:= base + Vector3(-2.0, DECK_HEIGHT, 0.0)
	var q:= base + Vector3(0.0, DECK_HEIGHT, 0.0)
	var r:= base + Vector3(0.0, DECK_HEIGHT, 2.0)
	var first: Conveyor = world.builds.add_conveyor(p, q)
	var second: Conveyor = world.builds.add_conveyor(q, r)
	for i in SETTLE:
		await get_tree().physics_frame

	_ok(world.builds.corners.size() == 1, "an L of two runs is fitted with one bend")
	_ok(first.downstream != null and first.downstream is ConveyorCorner,
		"...and the first run hands its load to it")

	player.build.reverse(second)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(world.builds.corners.is_empty(), "reversing the second takes the bend away")
	_ok(first.downstream == null, "...and the first run is left handing on to nothing")
	_ok(second.downstream == null, "...as is the one that was turned")

	player.build.reverse(second)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(world.builds.corners.size() == 1, "turning it back puts the bend back")
	_ok(first.downstream != null and first.downstream is ConveyorCorner,
		"...and the hand-over with it")
	await _clear()


func _case_let_go() -> void:
	print("\n=== letting go cancels ===")
	var run:= await _run_in_front()
	if run == null:
		return
	var was_a:= run.a
	_press(true)
	_ok(await _wait_until(func() -> bool: return player.build.reverse_progress() > 0.1),
		"the hold is under way")
	_press(false)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(player.build.reverse_progress() < 0.0, "the meter is gone")
	_ok(run.a.is_equal_approx(was_a), "and the run never turned")
	await _clear()


func _case_look_away() -> void:
	print("\n=== looking away cancels ===")
	var run:= await _run_in_front()
	if run == null:
		return
	var was_a:= run.a
	var facing:= player.rotation.y
	_press(true)
	_ok(await _wait_until(func() -> bool: return player.build.reverse_progress() > 0.1),
		"the hold is under way")
	player.set_look(facing + PI, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(player.build.reverse_progress() < 0.0, "turning away drops the hold")

	var waited:= 0.0
	while waited < BuildTool.REVERSE_HOLD * 1.5:
		waited += get_process_delta_time()
		await get_tree().process_frame
	_ok(run.a.is_equal_approx(was_a), "and the run never turned")
	_press(false)
	player.set_look(facing, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	await _clear()


func _case_mouse_taken() -> void:
	print("\n=== a panel taking the mouse cancels ===")
	var run:= await _run_in_front()
	if run == null:
		return
	var was_a:= run.a
	_press(true)
	_ok(await _wait_until(func() -> bool: return player.build.reverse_progress() > 0.1),
		"the hold is under way")
	player.capture_mouse(false)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(player.build.reverse_progress() < 0.0, "losing the mouse drops the hold")
	var waited:= 0.0
	while waited < BuildTool.REVERSE_HOLD * 1.5:
		waited += get_process_delta_time()
		await get_tree().process_frame
	_ok(run.a.is_equal_approx(was_a), "and the run never turned")
	_press(false)
	player.capture_mouse(true)
	for i in SETTLE:
		await get_tree().physics_frame
	await _clear()


func _case_module_belt() -> void:
	print("\n=== a machine's own belt is not a run ===")
	var at:= _ground_in_front(CONSOLE_RANGE)
	var scanner: HaystackScanner = world.builds.add_scanner(at, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame


	await _aim_at(scanner.console_position())
	_ok(player.build.dismantle_target() == scanner, "the ray is on the machine")
	_ok(player.build.reverse_target() == null, "...and there is nothing to reverse")
	_ok(not _strip_says(_strip(), "Reverse belt"), "...so the bar does not offer it")
	await _clear()


func _case_pick_wins() -> void:
	print("\n=== a prop on the belt still answers E ===")


	var run:= await _run_in_front(REACHABLE_RANGE)
	if run == null:
		return


	run.set_catching(false)
	run.set_drive_speed(0.0)
	var was_a:= run.a
	var mid:= (run.laid_start() + run.laid_end()) * 0.5


	var bucket: Carryable = world.props.spawn("bucket",
		Transform3D(Basis.IDENTITY, mid + Vector3.UP * 0.12))


	var reached:= await _aim_until_carryable(bucket)
	_ok(player.build.reverse_target() == run, "the ray reaches the run behind it")
	_ok(reached, "...and the bucket is within reach")

	_press(true)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(player.carry.is_carrying(), "E picks the bucket up")
	_ok(player.build.reverse_progress() < 0.0, "...and does not start a hold")
	_press(false)
	var waited:= 0.0
	while waited < BuildTool.REVERSE_HOLD * 1.5:
		waited += get_process_delta_time()
		await get_tree().process_frame
	_ok(run.a.is_equal_approx(was_a), "and the run never turned")

	player.drop_active_tool()
	if is_instance_valid(bucket):
		bucket.queue_free()
	for i in SETTLE:
		await get_tree().physics_frame
	await _clear()


func _case_beats_proximity() -> void:
	print("\n=== a run beside a scanner still answers the aim ===")


	var side:= player.look_direction().cross(Vector3.UP).normalized()
	var want:= _ground_in_front(CONSOLE_RANGE * 0.45) + side * CONSOLE_RANGE * 0.75


	var trial: HaystackScanner = world.builds.add_scanner(want, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	var drift:= trial.console_position() - trial.global_position
	world.builds.demolish(trial)
	for i in SETTLE:
		await get_tree().physics_frame
	var scanner: HaystackScanner = world.builds.add_scanner(
		want - Vector3(drift.x, 0.0, drift.z), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame


	var run:= await _run_in_front(REACHABLE_RANGE, -1.0)
	var eye:= player.eye_position()
	_ok(eye.distance_to(scanner.console_position()) < Cfg.SCANNER_REACH,
		"the player is standing inside the scanner's old reach (%.2f m)"
			% eye.distance_to(scanner.console_position()))
	if run != null:
		_ok(player.build.reverse_target() == run, "...and aiming at the run")
		_press(true)
		_ok(await _wait_until(func() -> bool: return player.build.reverse_progress() >= 0.0),
			"E goes to the belt and not to the console")
		_press(false)
		for i in SETTLE:
			await get_tree().physics_frame
	await _clear()


func _case_save() -> void:
	print("\n=== a reversal survives a save ===")
	var base:= _ground_in_front()
	var p:= base + Vector3(-1.5, DECK_HEIGHT, 0.0)
	var q:= base + Vector3(1.5, DECK_HEIGHT, 0.0)
	var laid: Conveyor = world.builds.add_conveyor(p, q)
	for i in SETTLE:
		await get_tree().physics_frame
	player.build.reverse(laid)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(laid.a.is_equal_approx(q), "the run is laid the other way")

	var saved: Array = world.builds.to_array()
	world.builds.from_array(saved)
	for i in SETTLE:
		await get_tree().physics_frame
	_ok(world.builds.conveyors.size() == 1, "one run comes back")
	if world.builds.conveyors.is_empty():
		return
	var back: Conveyor = world.builds.conveyors [0]
	_ok(back.a.is_equal_approx(q) and back.b.is_equal_approx(p),
		"...pointing the way it was left")
	await _clear()


func _case_arrows() -> void:
	print("\n=== the arrows on the belt ===")
	var vfx: BeltFlipVfx = world.belt_flip_vfx
	_ok(vfx != null, "the world built the effect")
	if vfx == null:
		return
	_ok(not vfx.showing(), "nothing is drawn with the crosshair on nothing")
	var run:= await _run_in_front()
	if run == null:
		return
	await get_tree().process_frame
	_ok(vfx.showing(), "a run in the crosshair lights the chain up")
	_ok(vfx.travel().dot(run.forward) > 0.9, "...pointing the way the belt carries")
	var idle:= vfx.arrow_speed()
	_ok(idle > 0.0, "the chain scrolls at %.2f m/s while it is only looked at" % idle)

	var was_a:= run.a
	var was_forward:= run.forward
	_press(true)
	_ok(await _wait_until(func() -> bool: return player.build.reverse_progress() > 0.4),
		"the hold gets under way")
	_ok(vfx.arrow_speed() < idle, "...and the chain has wound down with it")
	_ok(await _wait_until(func() -> bool: return run.b.is_equal_approx(was_a)),
		"the hold turns the run round")
	await get_tree().process_frame
	_ok(vfx.travel().dot(was_forward) < -0.9, "...and the arrows are pointing back")


	_ok(vfx.arrow_speed() > Tech.belt_speed(),
		"the flip whips the chain up rather than leaving it stalled")
	_press(false)
	for i in SETTLE:
		await get_tree().physics_frame
	await _clear()
	await get_tree().process_frame
	_ok(not vfx.showing(), "and the chain goes when the run does")


func _run_in_front(distance: float = TARGET_RANGE,
		aim_along: float = 0.0) -> Conveyor:
	var at:= _ground_in_front(distance)
	var across:= player.look_direction().cross(Vector3.UP).normalized()
	var mid:= Vector3(at.x, player.global_position.y + DECK_HEIGHT, at.z)
	var run: Conveyor = world.builds.add_conveyor(mid - across * 1.5, mid + across * 1.5)
	for i in SETTLE:
		await get_tree().physics_frame


	await _aim_at(mid + across * aim_along)
	_ok(player.build.reverse_target() == run, "the ray is on the run")
	if player.build.reverse_target() != run:
		return null
	return run


func _ground_in_front(distance: float = TARGET_RANGE) -> Vector3:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var at:= eye + dir * distance
	return Vector3(at.x, player.global_position.y, at.z)


func _clear() -> void:
	world.builds.clear()
	player.set_look(player.rotation.y, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame


func _aim_until_carryable(item: Carryable) -> bool:
	var waited:= 0.0
	while waited < PATIENCE:
		if not is_instance_valid(item):
			return false
		var eye:= player.camera.global_position
		var to: Vector3 = item.global_position
		var flat:= Vector2(to.x - eye.x, to.z - eye.z).length()
		player.set_look(atan2(to.x - eye.x, to.z - eye.z) + PI,
			atan2(to.y - eye.y, maxf(flat, 0.001)))
		await get_tree().physics_frame
		if player.carry.target() == item:
			return true
		waited += get_process_delta_time()
	return false


func _aim_at(target: Vector3) -> void:
	var eye:= player.camera.global_position
	var flat:= Vector2(target.x - eye.x, target.z - eye.z).length()
	player.set_look(atan2(target.x - eye.x, target.z - eye.z) + PI,
		atan2(target.y - eye.y, maxf(flat, 0.001)))
	for i in 3:
		await get_tree().physics_frame


func _press(down: bool) -> void:
	for e in InputMap.action_get_events("interact"):
		var key:= e as InputEventKey
		if key == null:
			continue
		var ev:= key.duplicate() as InputEventKey
		ev.pressed = down
		Input.parse_input_event(ev)
		return
	_fails += 1
	print("  FAIL the interact action has no key bound to press")


func _strip() -> ControlHints:
	if world.hud == null:
		return null
	return world.hud.get_node_or_null("ControlHints") as ControlHints


func _strip_says(strip: ControlHints, text: String) -> bool:
	if strip == null:
		return false
	var rows: Array = strip.call("_hints")
	for row: PackedStringArray in rows:
		if row.size() >= 2 and row [1].contains(text):
			return true
	return false


func _strip_lit(strip: ControlHints, text: String) -> bool:
	if strip == null:
		return false
	var rows: Array = strip.call("_hints")
	for row: PackedStringArray in rows:
		if row.size() >= 3 and row [1].contains(text) and row [2] == "lit":
			return true
	return false


func _wait_until(test: Callable) -> bool:
	var waited:= 0.0
	while waited < PATIENCE:
		if bool(test.call()):
			return true
		waited += get_process_delta_time()
		await get_tree().process_frame
	return false
