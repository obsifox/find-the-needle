class_name DevAlertProbe
extends Node


var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func run() -> void:
	world.block_save = true
	for i in 20:
		await get_tree().process_frame

	await _rake_says_why()
	await _arm_says_why()
	await _press_says_why()
	await _drone_says_why()
	_debounce()
	await _sign_stands_clear()
	_sign_keeps_its_distance()
	await _hud_names_the_drone_fault()

	print("[alerts] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _rake_says_why() -> void:
	var against:= _pile_side()
	_check("found a spot facing the pile", not against.is_empty())
	if against.is_empty():
		return
	var working: PistonRake = world.builds.add_piston_rake(against [0], against [1])
	await get_tree().process_frame
	_check("a rake stood against the pile reports nothing wrong",
		working.alert_reason() == "", working.alert_reason())


	var away: PistonRake = world.builds.add_piston_rake(
		against [0], against [1] + PI)
	await get_tree().process_frame
	var reason:= away.alert_reason()
	_check("a rake facing open ground says so", reason.begins_with("NOTHING TO RAKE"),
		reason)

	world.builds.demolish(working)
	world.builds.demolish(away)


func _arm_says_why() -> void:
	var open:= _open_floor()
	_check("found bare floor clear of the pile", open != Vector3.INF)
	if open == Vector3.INF:
		return
	var idle: RoboticArm = world.builds.add_robotic_arm(open, 0.0)
	await get_tree().process_frame


	await _settle(1.2)
	var reason:= idle.alert_reason()
	_check("an arm over bare floor raises no fault", reason == "", reason)
	_check("...and says it is all clear", idle.is_clear()
		and idle.waiting_reason().begins_with("ALL CLEAR"), idle.waiting_reason())
	var watch: MachineWatch = world.builds.watch
	for _i in 6:
		watch.force_sweep(MachineWatch.HOLD)
	_check("...and no sign stands over it", watch.alert_reason(idle) == "")

	idle.accept_mask = 0
	await _settle(1.2)
	reason = idle.alert_reason()
	_check("the same arm set to take nothing does say so",
		reason.begins_with("SET TO TAKE NOTHING"), reason)
	for _i in 2:
		watch.force_sweep(MachineWatch.HOLD)
	_check("...under a sign", watch.alert_reason(idle) != "")
	world.builds.demolish(idle)


func _press_says_why() -> void:
	var open:= _open_floor()
	if open == Vector3.INF:
		return
	var press: HayCompressor = world.builds.add_compressor(open, 0.0)
	await _settle(Cfg.MACHINE_STARVED_AFTER + 0.4)
	var reason:= press.alert_reason()
	_check("a press with nothing arriving says NO HAY",
		reason.begins_with("NO HAY"), reason)


	press.stored += 1
	press.starved_for = 0.0
	_check("...and stops saying it the moment something arrives",
		press.alert_reason() == "", press.alert_reason())
	world.builds.demolish(press)


func _drone_says_why() -> void:


	var open:= Vector3(13.0, 0.02, -6.0)
	var drone: HayDrone = world.builds.add_hay_drone(open, 0.0)


	await _settle(Cfg.DRONE_SCAN_INTERVAL * 2.0 + 0.3)
	var reason:= drone.alert_reason()
	_check("a drone with no job says it is not set up",
		reason.begins_with("NOT SET UP"), reason)


	drone.set_mode(HayDrone.Mode.COLLECT)
	var ground:= Vector3(open.x, 0.0, open.z)
	var zoned:= "no bearing fits"
	var dropped:= "no bearing fits"
	for k in 12:
		var a:= TAU * float(k) / 12.0
		if drone.set_zone(ground + Vector3(cos(a), 0.0, sin(a)) * 3.2, 1.5) == "":
			zoned = ""
			break
	for k in 12:
		var a:= TAU * float(k) / 12.0
		var at:= ground + Vector3(cos(a), 0.0, sin(a)) * 5.0
		if drone.drop_refusal(at) == "" and drone.set_drop(at, HayDrone.Drop.FLOOR) == "" and drone._route_why == "":
			dropped = ""
			break
	_check("the drone takes a zone and a drop", zoned == "" and dropped == "",
		"%s / %s" % [zoned, dropped])
	await _settle(Cfg.DRONE_SCAN_INTERVAL * 2.0 + 0.3)
	_check("...and stops saying anything is wrong once it has a job",
		drone.alert_reason() == "", drone.alert_reason())
	world.builds.demolish(drone)
	await get_tree().process_frame


func _debounce() -> void:
	var watch: MachineWatch = world.builds.watch
	_check("the build manager owns a watch", watch != null)
	if watch == null:
		return
	var against:= _pile_side()
	if against.is_empty():
		return
	var stuck: PistonRake = world.builds.add_piston_rake(
		against [0], against [1] + PI)


	var step:= MachineWatch.POLL
	var elapsed:= 0.0
	while elapsed + step < MachineWatch.HOLD:
		watch.force_sweep(step)
		elapsed += step
	_check("a fault under HOLD seconds old shows nothing", watch.alert_count() == 0)
	_check("...and the HUD is told nothing either",
		watch.alert_reason(stuck) == "")


	watch.force_sweep(step * 2.0)
	_check("a fault that keeps up raises a sign", watch.alert_count() == 1)
	_check("...and the sign is a child of the machine",
		stuck.find_child("Alert", false, false) != null)
	_check("...and the HUD is given the same words the sign went up for",
		watch.alert_reason(stuck).begins_with("NOTHING TO RAKE"),
		watch.alert_reason(stuck))


	stuck.rotation.y = against [1]
	watch.force_sweep(step)
	_check("a sign does not vanish on the first good poll", watch.alert_count() == 1)
	watch.force_sweep(MachineWatch.CLEAR)
	_check("...and does once the machine has been working a while",
		watch.alert_count() == 0)
	_check("...and the sign is gone from the machine",
		stuck.find_child("Alert", false, false) == null)

	world.builds.demolish(stuck)
	watch.force_sweep(step)
	_check("a demolished machine is dropped from the watch",
		watch.alert_count() == 0)


func _sign_stands_clear() -> void:
	var against:= _pile_side()
	if against.is_empty():
		return
	var stuck: PistonRake = world.builds.add_piston_rake(
		against [0], against [1] + PI)
	await get_tree().process_frame
	var flag:= MachineAlert.stand_over(stuck)
	await get_tree().process_frame
	var body:= _drawn_top(stuck, false)
	_check("the sign stands over the machine, not in it",
		flag.global_position.y > body, "sign %.2f vs bodywork top %.2f"
		% [flag.global_position.y, body])
	_check("...and not out of sight above it",
		flag.global_position.y < body + 2.0)

	_check("the badge is on the list the overlay draws from",
		flag.is_listed())
	world.builds.demolish(stuck)


	var gen: HayGenerator = world.builds.add_generator(against [0], against [1], 0.0)
	if gen == null:
		_check("a generator stands to measure its steam against", false)
		return
	gen.fuel = gen.capacity()


	await _settle(2.0)
	var steam_flag:= MachineAlert.stand_over(gen)
	await get_tree().process_frame
	var gen_body:= _drawn_top(gen, false)
	var everything:= _drawn_top(gen, true)
	_check("a lit generator really does draw something above its own bodywork",
		everything > gen_body + 0.5, "all %.2f vs body %.2f" % [everything, gen_body])
	_check("...and the sign is not pushed up into the steam by it",
		steam_flag.global_position.y < everything,
		"sign %.2f vs everything %.2f" % [steam_flag.global_position.y, everything])
	world.builds.demolish(gen)


func _sign_keeps_its_distance() -> void:
	_check("a sign under the player's nose is full size",
		is_equal_approx(MachineAlert.range_scale(1.0), 1.0),
		"%.3f" % MachineAlert.range_scale(1.0))
	_check("...and still full size at the range it is read from",
		is_equal_approx(MachineAlert.range_scale(MachineAlert.FULL_RANGE), 1.0))

	var near:= MachineAlert.range_scale(MachineAlert.FULL_RANGE + 2.0)
	var far:= MachineAlert.range_scale(MachineAlert.CUT_RANGE - 2.0)
	_check("a sign further off is drawn smaller", far < near and near < 1.0,
		"near %.3f, far %.3f" % [near, far])
	_check("...but not so small it cannot be read", far > 0.3, "%.3f" % far)

	_check("a sign across the yard is not drawn at all",
		MachineAlert.range_scale(MachineAlert.CUT_RANGE) == 0.0
		and MachineAlert.range_scale(60.0) == 0.0)
	_check("...and it faded out before it went, rather than popping",
		is_equal_approx(MachineAlert.range_fade(MachineAlert.CUT_RANGE), 0.0)
		and MachineAlert.range_fade(MachineAlert.CUT_RANGE - MachineAlert.FADE * 0.5) < 0.9)
	_check("a sign in reach is not faded",
		is_equal_approx(MachineAlert.range_fade(1.0), 1.0))


func _hud_names_the_drone_fault() -> void:
	var hud: Hud = world.hud
	var watch: MachineWatch = world.builds.watch
	if hud == null or watch == null:
		_check("the world has a HUD and a watch", false)
		return
	var open:= _open_floor()
	if open == Vector3.INF:
		return
	var drone: HayDrone = world.builds.add_hay_drone(open, 0.0)


	player._set_tool(Player.Tool.HAND)
	player.global_position = open + Vector3(2.0, 0.0, 0.0)
	await _settle(Cfg.DRONE_SCAN_INTERVAL * 2.0 + 0.3)
	var body:= drone.global_position + Vector3(0.0, 0.6, 0.0)
	var eye:= player.camera.global_position
	var flat:= Vector2(body.x - eye.x, body.z - eye.z).length()
	player.set_look(atan2(body.x - eye.x, body.z - eye.z) + PI,
		atan2(body.y - eye.y, maxf(flat, 0.001)))
	for i in 4:
		await get_tree().physics_frame


	for i in 30:
		watch.force_sweep(MachineWatch.POLL)
	await get_tree().process_frame

	var looked: Node = hud._machine_under_crosshair()
	_check("the crosshair finds the drone the player is looking at",
		looked != null, "found nothing")
	var said:= hud._machine_fault(looked)
	_check("...and the HUD names the fault the sign went up for",
		said != "" and said == watch.alert_reason(drone),
		"HUD said '%s', watch says '%s'" % [said, watch.alert_reason(drone)])
	world.builds.demolish(drone)
	await get_tree().process_frame


func _pile_side() -> Array:
	var field: HayField = world.field
	for ring_step in range(12, 30):
		var ring:= float(ring_step) * 0.5
		for step in 24:
			var a:= TAU * float(step) / 24.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			at.y = field.height_at(at.x, at.z)
			if at.y > 0.1:
				continue
			var inward:= Vector3(- cos(a), 0.0, - sin(a)).normalized()
			var face:= at + inward * Cfg.RAKE_REACH
			if field.height_at(face.x, face.z) > at.y + 0.25:
				return [at, atan2(inward.x, inward.z)]
	return []


func _open_floor() -> Vector3:
	var field: HayField = world.field
	for ring in [18.0, 19.0, 20.0, 17.0, 16.0]:
		for step in 32:
			var a:= TAU * float(step) / 32.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			if _hay_within(at, 6.0):
				continue
			at.y = field.height_at(at.x, at.z)
			return at
	return Vector3.INF


func _hay_within(at: Vector3, radius: float) -> bool:
	var field: HayField = world.field
	for step in 16:
		var a:= TAU * float(step) / 16.0
		for r: float in [radius, radius * 0.6, radius * 0.3]:
			var x:= at.x + cos(a) * r
			var z:= at.z + sin(a) * r
			if field.height_at(x, z) > 0.1:
				return true
	return field.height_at(at.x, at.z) > 0.1


func _drawn_top(machine: Node3D, effects: bool) -> float:
	var top:= - INF
	for node in machine.find_children("*", "GeometryInstance3D", true, false):
		var vis:= node as GeometryInstance3D
		if not vis.visible or vis is GPUParticles3D or vis.name == "Sign":
			continue
		if not effects and vis.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var box:= vis.get_aabb()
		for corner in 8:
			var at:= box.position + box.size * Vector3(
				float(corner & 1), float((corner >> 1) & 1), float((corner >> 2) & 1))
			top = maxf(top, (vis.global_transform * at).y)
	return top


func _settle(seconds: float) -> void:
	var left:= seconds
	while left > 0.0:
		left -= get_process_delta_time()
		await get_tree().process_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("[alerts] ok   %s" % what)
		return
	_fail += 1
	print("[alerts] FAIL %s%s" % [what, "  (%s)" % detail if detail != "" else ""])
