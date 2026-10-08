class_name DevCarryProbe
extends Node


const SETTLE:= 40


const LEG_SECONDS:= 6.0


const LOAD:= 60


const POUR_TILTS: Array [float] = [0.3, 0.6, 0.9, 1.2, 1.35]


const POUR_PATIENCE:= 4.0


const TILT_FRAMES:= 12


const EYES_DOWN: Array [float] = [0.0, 0.55, 0.79]


const POUR_RESIDUE:= 0.05


const SLOW_TURN:= 0.9


const FLICK_TURN:= 6.0
const FLICK_PERIOD:= 0.5

var world: Node3D
var player: Player

var _rows: Array = []
var _traced:= false
var _spawned: Array [RigidBody3D] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true


	var was_mode:= Cfg.tool_mode
	Cfg.tool_mode = Cfg.TOOL_ADVANCED
	tree_exiting.connect(func() -> void: Cfg.tool_mode = was_mode)
	Tech.grant_legacy()
	for i in SETTLE:
		await get_tree().process_frame

	print("\n=== what survives the trip ===")
	print("  %-12s %-16s %6s %6s %6s" % ["blade", "on the way", "start", "end", "kept"])
	await _measure_spade("stand still", Vector3.ZERO, false, 0.0)
	await _measure_spade("walk", Vector3(0, 0, -1), false, 0.0)
	await _measure_spade("sprint", Vector3(0, 0, -1), true, 0.0)
	await _measure_spade("walk and turn", Vector3(0, 0, -1), false, SLOW_TURN)
	await _measure_spade("flick, standing", Vector3.ZERO, false, FLICK_TURN)
	await _measure_spade("walk and flick", Vector3(0, 0, -1), false, FLICK_TURN)
	await _measure_spade("sprint and flick", Vector3(0, 0, -1), true, FLICK_TURN)
	await _measure_toy("walk", Vector3(0, 0, -1), 0.0)
	await _measure_toy("flick, standing", Vector3.ZERO, FLICK_TURN)
	await _measure_toy("walk and flick", Vector3(0, 0, -1), FLICK_TURN)
	await _measure_fork("stand still", Vector3.ZERO, false, 0.0)
	await _measure_fork("walk", Vector3(0, 0, -1), false, 0.0)
	await _measure_fork("walk and flick", Vector3(0, 0, -1), false, FLICK_TURN)

	await _measure_pour()
	await _measure_eyes_down()

	print("\n=== summary ===")
	var worst:= 100.0
	for row: Dictionary in _rows:
		worst = minf(worst, float(row ["kept"]))
	print("  the worst leg delivered %.0f%% of its load" % worst)
	print("  a delivery the player can plan around wants to be at 100")
	get_tree().quit()


func _measure_eyes_down() -> void:
	print("\n=== looking down is not tipping ===")
	for pitch: float in EYES_DOWN:
		await _load_spade(LOAD, - pitch)
		var start:= player.shovel.carried_strands()
		var up_dot:= player.shovel.body.global_transform.basis.y.dot(Vector3.UP)


		var poured:= false
		var ticks:= int(LEG_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
		var forward:= - player.global_transform.basis.z
		for i in ticks:
			player.velocity = Vector3(forward.x, 0, forward.z).normalized() * Player.SPEED
			player.velocity.y = -1.0
			player.move_and_slide()
			await get_tree().physics_frame
			if bool(player.shovel.get("_pouring")):
				poured = true
		var ended:= player.shovel.carried_strands()
		print("  eyes %2.0f deg down (pan at %.2f, holds above %.2f): %s, %d of %d left"
			% [rad_to_deg(pitch), up_dot, Shovel.TIP_POUR,
				"POURED" if poured else "never poured", ended, start])
		if poured:
			print("  FAIL  looking down put the tool into the pour state")
	player.head.rotation.x = 0.0
	player.set("_pitch", 0.0)


func _measure_pour() -> void:
	print("\n=== a tipped blade empties itself, with nothing held down ===")
	print("  %-10s %-10s %8s %8s" % ["tilt", "", "left", "seconds"])
	for tilt: float in POUR_TILTS:
		await _load_spade(LOAD, 0.0)
		var start:= player.shovel.carried_strands()


		var tilt_frames:= TILT_FRAMES
		for f in tilt_frames:
			player.shovel.aim_input(Vector2(0.0, tilt / 0.004 / float(tilt_frames)))
			await get_tree().physics_frame


		var over:= false


		player.capture_mouse(true)
		await get_tree().physics_frame
		var step:= maxf(get_physics_process_delta_time(), 1e-06)
		var ticks:= 0
		var cap:= int(POUR_PATIENCE / step)


		var done: int = maxi(1, int(float(start) * POUR_RESIDUE))
		while ticks < cap and player.shovel.carried_strands() > done:
			await get_tree().physics_frame
			ticks += 1
		var left:= player.shovel.carried_strands()
		var emptied:= left <= done
		if left > 0:


			var inv:= player.shovel.body.global_transform.affine_inverse()
			var still:= 0
			var lo:= Vector3.ONE * 9.0
			var hi:= Vector3.ONE * -9.0
			for b in _spawned:
				if not is_instance_valid(b) or not b.is_inside_tree():
					continue
				var local:= inv * b.global_position
				if absf(local.x) > 0.4 or absf(local.y) > 0.4 or absf(local.z) > 0.4:
					continue
				if b.linear_velocity.length() < 0.05:
					still += 1
				lo = Vector3(minf(lo.x, local.x), minf(lo.y, local.y), minf(lo.z, local.z))
				hi = Vector3(maxf(hi.x, local.x), maxf(hi.y, local.y), maxf(hi.z, local.z))
			print("        %d still on the pan: local x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
				% [still, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
		over = player.shovel.body.global_transform.basis.y.dot(Vector3.UP) <= Shovel.TIP_POUR
		var secs:= float(ticks) * step
		print("  %5.0f deg %-10s %4d/%-3d %7s" % [
			rad_to_deg(tilt), "past the gate" if over else "held", left, start,
			"never" if not emptied else "%.2f" % secs])
		if over and not emptied:
			print("  FAIL  a blade past the tip gate did not empty")
		player.shovel.reset_aim()
		for i in 10:
			await get_tree().physics_frame
	print("  (nothing is pressed in any of those rows -- the tilt is the gesture)")


func _measure_spade(what: String, dir: Vector3, sprint: bool, turn: float) -> void:
	await _load_spade(LOAD)
	var start:= player.shovel.carried_strands()
	await _travel(dir, sprint, turn)
	_report("spade", what, start, player.shovel.carried_strands())
	_where(player.shovel._hold_centre(), player.shovel._hold_radius())


func _measure_fork(what: String, dir: Vector3, sprint: bool, turn: float) -> void:
	await _load_fork(LOAD)
	var start:= player.pitchfork.carried_strands()
	_hold_state()
	_traced = TRACE
	await _travel(dir, sprint, turn)
	_traced = false
	_report("pitchfork", what, start, player.pitchfork.carried_strands())
	_where(player.pitchfork._hold_centre(), player.pitchfork._hold_radius())
	_on_the_tines()


func _load_fork(count: int) -> void:
	_clear_hay()
	_stand_at_the_pile()
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for i in 10:
		await get_tree().physics_frame
	var g:= player.pitchfork.pan_geometry()
	_fill_blade((g ["xf"] as Transform3D) * (g ["origin"] as Vector3), count)
	for i in 45:
		await get_tree().physics_frame


const TRACE:= false


func _sample(t: float) -> void:
	var f:= player.pitchfork
	var inv:= f.body.global_transform.affine_inverse()
	var speed:= 0.0
	var zs:= 0.0
	var n:= 0
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		speed += b.linear_velocity.length()
		zs += (inv * b.global_position).z
		n += 1
	if n == 0:
		print("        t=%.0fs: nothing left" % t)
		return
	print("        t=%.0fs: %d alive, %d in the basin, mean speed %.2f m/s, mean local z %.3f"
		% [t, n, f.carried_strands(), speed / float(n), zs / float(n)])


func _hold_state() -> void:
	var f:= player.pitchfork
	var xf:= f.body.global_transform
	var centre:= f._hold_centre()
	var up:= xf.basis.y.normalized()
	var above:= 0
	var seen:= 0
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		seen += 1
		if (b.global_position - centre).dot(up) > HayHold.SETTLE_HEIGHT:
			above += 1
	print("      pan at %.2f (holds above %.2f); %d of %d sit above the settle line"
		% [up.dot(Vector3.UP), Shovel.TIP_POUR, above, seen])


func _on_the_tines() -> void:
	var inv:= player.pitchfork.body.global_transform.affine_inverse()
	var zs: Array [float] = []
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		var local:= inv * b.global_position
		if local.length() > 1.2:
			continue
		zs.append(local.z)
	if zs.is_empty():
		print("      nothing is left anywhere near the fork")
		return
	zs.sort()
	var back:= Pitchfork.FORK_HEAD_Z + Pitchfork.TINE_LEN * 0.5
	var on:= 0
	for z in zs:
		if z <= back:
			on += 1
	print("      load at local z %.3f..%.3f (the tines end at %.3f) -- %d of %d on the metal"
		% [zs [0], zs [zs.size() - 1], back, on, zs.size()])


func _measure_toy(what: String, dir: Vector3, turn: float) -> void:
	_clear_hay()
	_stand_at_the_pile()
	player._set_tool(Player.Tool.HAND)
	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("sand_shovel")
	player.select_hotbar_slot(4)
	for i in 20:
		await get_tree().physics_frame
	var toy:= player.carry.held() as SandShovel
	if toy == null:
		print("  (the toy shovel would not come out)")
		return
	_fill_blade(toy._hold_centre(), LOAD)


	for i in 45:
		await get_tree().physics_frame
	var start:= toy.carried_strands()
	await _travel(dir, false, turn)
	_report("toy shovel", what, start, toy.carried_strands())
	_where(toy._hold_centre(), toy._hold_radius())


func _fill_blade(at: Vector3, count: int) -> void:
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210
	_spawned.clear()
	for i in count:
		var jitter:= Vector3(rng.randf_range(-0.05, 0.05),
			rng.randf_range(0.01, 0.07), rng.randf_range(-0.07, 0.07))
		var b:= live.spawn(at + jitter, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
		if b != null:
			_spawned.append(b)


func _clear_hay() -> void:
	var live: LiveStrandManager = world.live
	for b in live._active.duplicate():
		live._despawn(b)


func _stand_at_the_pile() -> void:
	player.global_position = Vector3(11.5, 0.4, 0.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = -0.55
	player.velocity = Vector3.ZERO


func _travel(dir: Vector3, sprint: bool, turn: float) -> void:
	var speed:= Player.SPRINT if sprint else Player.SPEED
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var ticks:= int(LEG_SECONDS / step)
	var per_second:= int(1.0 / step)
	for i in ticks:
		if _traced and i > 0 and i % per_second == 0:
			_sample(float(i) * step)
		if dir != Vector3.ZERO:
			var forward:= - player.global_transform.basis.z
			player.velocity = Vector3(forward.x, 0, forward.z).normalized() * speed
			player.velocity.y = -1.0
			player.move_and_slide()
		if turn > 0.0:


			var sign:= 1.0 if fmod(float(i) * step, FLICK_PERIOD * 2.0) < FLICK_PERIOD else -1.0
			player.rotate_y(turn * sign * step)
		await get_tree().physics_frame


func _where(centre: Vector3, radius: float) -> void:
	var gone:= 0
	var in_sphere:= 0
	var near:= 0
	var floored:= 0
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			gone += 1
			continue
		var d:= b.global_position.distance_to(centre)
		if d <= radius:
			in_sphere += 1
		elif d <= 1.0:
			near += 1
		if b.global_position.y < 0.25:
			floored += 1
	print("      of %d: %d recycled, %d still inside the hold sphere, %d within a metre, %d on the floor"
		% [_spawned.size(), gone, in_sphere, near, floored])
	_spread(centre, radius)


func _spread(centre: Vector3, radius: float) -> void:
	var d: Array [float] = []
	for b in _spawned:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.global_position.y < 0.25:
			continue
		d.append(b.global_position.distance_to(centre))
	if d.is_empty():
		return
	d.sort()
	var p50:= d [int(float(d.size()) * 0.5)]
	var p90:= d [mini(int(float(d.size()) * 0.9), d.size() - 1)]
	print("      spread: half of it within %.2f m, 90%% within %.2f m, furthest %.2f m (hold sphere is %.2f m)"
		% [p50, p90, d [d.size() - 1], radius])


func _load_spade(count: int, pitch: float = NAN) -> void:
	_clear_hay()
	_stand_at_the_pile()
	if not is_nan(pitch):
		player.head.rotation.x = pitch
		player.set("_pitch", pitch)
	player._set_tool(Player.Tool.SHOVEL)
	player.shovel.reset_aim()
	for i in 10:
		await get_tree().physics_frame
	_fill_blade(player.shovel._hold_centre(), count)


	for i in 45:
		await get_tree().physics_frame


func _report(blade: String, what: String, start: int, ended: int) -> void:
	var kept:= 100.0 * float(ended) / maxf(float(start), 1.0)
	_rows.append({ "kept": kept, "what": "%s, %s" % [blade, what] })
	print("  %-12s %-16s %6d %6d %5.0f%%" % [blade, what, start, ended, kept])
