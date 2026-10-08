class_name DevPelletLandProbe
extends Node


var world: Node3D
var player: Player

const AT:= Vector3(12.0, 0.0, 12.0)
const SHOTS:= 8
const SETTLE_FRAMES:= 260

var _pass:= 0
var _fail:= 0


func run() -> void:
	await get_tree().process_frame
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	if builds == null or props == null:
		_check("the world has a build manager and a prop manager", false)
		_finish()
		return

	var mill:= builds.add_pelletizer(AT, 0.0)
	if mill == null:
		_check("BuildManager places a pelletizer", false)
		_finish()
		return
	await get_tree().process_frame
	await get_tree().physics_frame

	var ring:= mill.throw_target()
	var muzzle:= mill.spout_position()
	print("[pelletland] mill at %s, muzzle %s, ring %s (%.2f m out, %.2f m up)"
		% [AT, muzzle, ring,
			Vector2(ring.x - muzzle.x, ring.z - muzzle.z).length(),
			muzzle.y - AT.y])

	await _fire_and_measure(mill, props, ring, "bare ground")


	await _case_throw_setting(mill, props)
	mill.set_throw_distance(Cfg.PELLETIZER_THROW_DISTANCE)
	await get_tree().physics_frame


	var flat:= ring - muzzle
	flat.y = 0.0
	flat = flat.normalized()
	var across:= flat.cross(Vector3.UP).normalized()
	var deck_lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var run:= builds.add_conveyor(
		ring - across * 3.0 + Vector3.UP * deck_lift,
		ring + across * 3.0 + Vector3.UP * deck_lift)
	_check("a run lays across the ring", run != null)
	await get_tree().physics_frame
	await _fire_and_measure(mill, props, ring, "belt across the ring")
	if run != null:
		await _case_full_belt(mill, run, props, ring)

	await _case_hologram()


	await _case_reload()
	_finish()


func _case_hologram() -> void:
	print("\n=== the hologram faces where it can be read ===")
	var tool: BuildTool = player.build
	if tool == null:
		_check("the player has a build tool", false)
		return


	player.global_position = Vector3(6.0, 0.0, 6.0)
	player.velocity = Vector3.ZERO
	player.set_look(atan2(-1.0, 0.0), -0.55)


	Tech.grant("pelletizer", 1)
	player.equip_build("pelletizer")
	_check("the tool comes up holding a mill",
		BuildCatalog.is_unlocked("pelletizer") and player.build_id == "pelletizer")
	for _f in 6:
		await get_tree().process_frame

	var ghost: HayPelletizer = tool.get_node_or_null("PelletizerGhost")
	if ghost == null:
		_check("the tool carries a pelletizer hologram", false)
		return
	var look:= player.look_direction()
	look.y = 0.0
	look = look.normalized()
	var want:= HayPelletizer.default_forward(look)


	_check("free-aimed, it stands a quarter off the line of sight (%.1f deg)"
		% rad_to_deg(acos(clampf(ghost.forward().dot(look), -1.0, 1.0))),
		ghost.forward().dot(want) > 0.99)


	var right:= look.cross(Vector3.UP).normalized()


	var to_port:= ghost.intake_port() - ghost.global_position
	to_port.y = 0.0
	to_port = to_port.normalized()
	_check("...with the belt coming in on the right (%.2f)" % right.dot(to_port),
		right.dot(to_port) > 0.99)
	_check("the hint bar offers the turn", tool.can_turn())


	var seen: Array [Vector3] = [ghost.forward()]
	for turn in 4:
		_press("build_rotate")
		for _f in 4:
			await get_tree().process_frame
		var now:= ghost.forward()
		var quarter:= seen [seen.size() - 1].cross(now).y
		_check("press %d turns it a quarter (%.1f deg)"
			% [turn + 1, rad_to_deg(acos(clampf(
				seen [seen.size() - 1].dot(now), -1.0, 1.0)))],
			absf(seen [seen.size() - 1].dot(now)) < 0.02 and absf(quarter) > 0.98)
		seen.append(now)
	_check("four presses put it back exactly where it started",
		seen [4].dot(seen [0]) > 0.9999)
	player._set_tool(Player.Tool.HAND)


func _press(action: String) -> void:
	for e in InputMap.action_get_events(action):
		var key:= e as InputEventKey
		if key == null:
			continue
		for down: bool in [true, false]:
			var ev:= key.duplicate() as InputEventKey
			ev.pressed = down
			Input.parse_input_event(ev)
		return
	_check("the %s action has a key bound to press" % action, false)


func _fire_and_measure(mill: HayPelletizer, props: PropManager, ring: Vector3,
		label: String) -> void:
	var misses: Array [float] = []
	var lands: Array [Vector3] = []
	for _i in SHOTS:


		var box: Array [EcoBrick] = []
		var caught:= func(b: EcoBrick) -> void: box.append(b)
		mill.bricked.connect(caught)
		mill._batch = Cfg.PELLETIZER_BRICK_STRANDS
		mill._throw_brick()
		mill.bricked.disconnect(caught)
		if box.is_empty():
			continue
		var brick: EcoBrick = box [0]
		var at:= await _touchdown(brick)
		if at != Vector3.INF:
			lands.append(at)
			misses.append(Vector2(at.x - ring.x, at.z - ring.z).length())
		if is_instance_valid(brick):
			props.remove(brick)
		await get_tree().physics_frame

	if misses.is_empty():
		_check("[%s] the mill threw something that came down" % label, false)
		return
	var worst:= 0.0
	var total:= 0.0
	for m in misses:
		worst = maxf(worst, m)
		total += m
	var centre:= Vector3.ZERO
	for l in lands:
		centre += l
	centre /= float(lands.size())
	var off:= Vector2(centre.x - ring.x, centre.z - ring.z).length()
	print("[pelletland] %s: %d bricks, mean %.2f m off the ring, worst %.2f m,"
		% [label, misses.size(), total / float(misses.size()), worst]
		+ " landing centre %s vs ring %s" % [centre, ring])


	_check("[%s] the bricks come down inside the pad the ring is drawn round"
		% label + " (%.2f m)" % off, off <= Cfg.PELLETIZER_PAD_RADIUS)


func _case_full_belt(mill: HayPelletizer, run: Conveyor, props: PropManager,
		ring: Vector3) -> void:
	print("\n=== a full belt under the ring stops the mill ===")
	var thrown:= [0]
	var count:= func(_b: EcoBrick) -> void: thrown [0] += 1
	mill.bricked.connect(count)
	run.set_outlet_held(true)
	var per:= Tech.pellet_cycle_seconds()
	var tps:= Engine.physics_ticks_per_second


	var frames:= int((90.0 + per * 12.0) * tps)
	var last_throw:= 0
	var held_since:= -1
	for f in frames:
		mill.stored = mill.buffer_capacity()
		var before: int = thrown [0]
		await get_tree().physics_frame
		if thrown [0] != before:
			last_throw = f
		if held_since < 0 and mill.alert_reason().begins_with("BELT FULL"):
			held_since = f
	print("[pelletland] %d bricks thrown, last at %.1f s, held from %.1f s"
		% [thrown [0], last_throw / float(tps), held_since / float(tps)])
	_check("the mill says BELT FULL once the belt backs up past the ring",
		held_since >= 0 and mill.alert_reason().begins_with("BELT FULL"))
	_check("...and has thrown nothing for the last %d cycles" % 8,
		frames - last_throw > int(per * 8.0 * tps))


	var stacked:= 0
	for item in props.items:
		var b:= item as EcoBrick
		if b == null or not is_instance_valid(b) or BeltPath.is_rider(b):
			continue
		var d:= Vector2(b.global_position.x - ring.x, b.global_position.z - ring.z)
		if d.length() < 1.5 and b.global_position.y > AT.y + 0.3:
			stacked += 1
	_check("no loose brick is left lying on the queue (%d)" % stacked, stacked == 0)

	run.set_outlet_held(false)
	var at_release: int = thrown [0]
	for f in int(per * 6.0 * tps):
		mill.stored = mill.buffer_capacity()
		await get_tree().physics_frame
	_check("let go, the belt drains and the mill throws again (%d)"
		% (thrown [0] - at_release), thrown [0] - at_release >= 2)
	_check("...and the sign is gone", not mill.alert_reason().begins_with("BELT FULL"))
	mill.bricked.disconnect(count)
	mill.stored = 0


func _case_throw_setting(mill: HayPelletizer, props: PropManager) -> void:
	print("\n=== the throw is the player's to set ===")
	var muzzle:= mill.spout_position()


	var bore:= HayPelletizer.MUZZLE.normalized()
	var clear:= Vector2(bore.x, bore.z).length() * HayPelletizer.MUZZLE_CLEAR
	for metres: float in [Cfg.PELLETIZER_THROW_MIN,
			Cfg.PELLETIZER_THROW_DISTANCE, Cfg.PELLETIZER_THROW_MAX]:
		mill.set_throw_distance(metres)
		var at:= mill.throw_target()


		var out:= Vector2(at.x - muzzle.x, at.z - muzzle.z).length() - clear
		_check("set to %.2f m, the ring sits %.2f m out" % [metres, out],
			absf(out - metres) < 0.05)


	mill.set_throw_distance(99.0)
	_check("a setting past the far end is held at it (%.2f m)" % mill.throw_distance,
		absf(mill.throw_distance - Cfg.PELLETIZER_THROW_MAX) < 0.001)
	mill.set_throw_distance(0.0)
	_check("...and one below the near end at that (%.2f m)" % mill.throw_distance,
		absf(mill.throw_distance - Cfg.PELLETIZER_THROW_MIN) < 0.001)


	mill.set_throw_distance(Cfg.PELLETIZER_THROW_MAX)
	await get_tree().physics_frame
	await _fire_and_measure(mill, props, mill.throw_target(), "at the far setting")

	var panel: PelletizerPanel = player.pelletizer_panel
	_check("the player has a throw panel for the mill", panel != null)
	if panel == null:
		return


	mill.set_throw_distance(4.25)
	panel.open(mill)
	await get_tree().process_frame
	_check("opening the panel leaves the throw alone (%.2f m)" % mill.throw_distance,
		absf(mill.throw_distance - 4.25) < 0.01)
	_check("...and it draws that mill's throw", mill.range_shown())
	panel.close()
	await get_tree().process_frame
	_check("closing it takes the drawing away again", not mill.range_shown())


	panel.open(mill)
	await get_tree().process_frame
	panel._on_pin()
	panel.close()
	await get_tree().process_frame
	_check("the show range button keeps the drawing up with the panel shut",
		mill.range_shown())
	panel.open(mill)
	await get_tree().process_frame
	panel._on_pin()
	panel.close()
	await get_tree().process_frame
	_check("...and a second press takes it down", not mill.range_shown())


func _case_reload() -> void:
	print("\n=== the setting survives a reload ===")
	if world.builds.pelletizers.is_empty():
		_check("there is a mill in the yard to save", false)
		return
	var mill: HayPelletizer = world.builds.pelletizers [0]
	var bore:= HayPelletizer.MUZZLE.normalized()
	var clear:= Vector2(bore.x, bore.z).length() * HayPelletizer.MUZZLE_CLEAR
	mill.set_throw_distance(3.75)
	var yard: Array = world.builds.to_array()
	world.builds.from_array(yard)
	for _f in 10:
		await get_tree().physics_frame
	var back: HayPelletizer = null
	if not world.builds.pelletizers.is_empty():
		back = world.builds.pelletizers [0]
	_check("the mill comes back from a reload", back != null)
	if back == null:
		return
	_check("...still aimed where it was set (%.2f m)" % back.throw_distance,
		absf(back.throw_distance - 3.75) < 0.01)


	var out:= Vector2(back.throw_target().x - back.spout_position().x,
		back.throw_target().z - back.spout_position().z).length() - clear
	_check("...and the ring is out there with it (%.2f m)" % out,
		absf(out - 3.75) < 0.05)


func _touchdown(brick: EcoBrick) -> Vector3:
	var step:= 1.0 / float(Engine.physics_ticks_per_second)
	var g: float = absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))
	var falling:= false
	var last:= brick.global_position
	for _f in SETTLE_FRAMES:
		await get_tree().physics_frame
		if not is_instance_valid(brick):
			return Vector3.INF
		var vy:= brick.linear_velocity.y
		if vy < -1.0:
			falling = true


		elif falling and vy > -1.0 + g * step * 0.5:
			return last
		last = brick.global_position
	return last


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _finish() -> void:
	print("[pelletland] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
