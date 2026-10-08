class_name DevExposeProbe
extends Node


var world: Node3D
var player: Player
var _fails: PackedStringArray = PackedStringArray()
var _rng:= RandomNumberGenerator.new()


var _peak_live:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	_rng.seed = 20260903
	GameState.add_money(2000.0)
	await _settle(30)
	await _case_stays_buried()
	await _case_carved_off()
	await _case_under_the_rake()
	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_stays_buried() -> void:
	_log("\n=== a covered needle stays covered ===")
	var field: HayField = world.field
	var live: LiveStrandManager = world.live
	var at:= Vector3(3.0, 0.0, 0.0)
	var surf:= field.height_at(at.x, at.z)
	if surf < 2.0:
		_fails.append("the pile at (3, 0) is only %.2f m tall; nowhere to bury a test needle" % surf)
		return
	at.y = surf - 0.25
	var idx:= GameState.register_needle(at, _rng, 0)
	await _settle(150)
	_check("registry needle 0.25 m under is still buried after 150 ticks",
		GameState.needle_taken [idx] == 0)
	_check("...and no body was made for it", _body_of(idx) == null)
	_check("a direct sweep also leaves it alone", live.expose_uncovered_needles() == 0)

	GameState.needle_taken [idx] = 1


func _case_carved_off() -> void:
	_log("\n=== the column carved off a needle ===")
	var field: HayField = world.field
	var at:= Vector3(-3.0, 0.0, 2.0)
	var surf:= field.height_at(at.x, at.z)
	if surf < 2.0:
		_fails.append("the pile at (-3, 2) is only %.2f m tall; nowhere to bury a test needle" % surf)
		return
	at.y = surf - 0.4
	var idx:= GameState.register_needle(at, _rng, 1)


	var radius:= 0.6
	field.carve_volume(Vector3(at.x, surf, at.z), radius, PI * radius * radius * 0.6)
	var after:= field.height_at(at.x, at.z)
	_log("  surface over the needle went %.2f m to %.2f m, needle at %.2f m" % [surf, after, at.y])
	_check("the carve actually uncovered it", after < at.y)
	await _settle(int(LiveStrandManager.NEEDLE_EXPOSE_INTERVAL * 60.0) + 30)
	_check("the registry marks it taken", GameState.needle_taken [idx] == 1)
	var body:= _body_of(idx)
	_check("a needle body exists for it", body != null)
	if body != null:
		_check("...lying near where it was buried (%.2f m away)" % body.global_position.distance_to(at),
			body.global_position.distance_to(at) < 1.0)


func _case_under_the_rake() -> void:
	_log("\n=== under a working rake ===")
	Tech.reset()
	Tech.grant("rake_bite", 2)
	var field: HayField = world.field
	var live: LiveStrandManager = world.live
	var site:= _site()
	if site.is_empty():
		_fails.append("found no spot facing the pile to stand a rake on")
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])


	rake.needle_chance = 0.0
	await get_tree().process_frame
	await get_tree().process_frame


	await _one_stroke(rake)
	if rake._bite_sites.is_empty():
		_fails.append("the rake's first stroke took nothing; nothing to bury a needle under")
		world.builds.demolish(rake)
		return
	var head: Vector3 = rake._bite_sites [0]
	var surf:= field.height_at(head.x, head.z)
	var at:= Vector3(head.x, surf - 0.1, head.z)
	var idx:= GameState.register_needle(at, _rng, 2)
	_log("  needle buried 0.10 m under the head point, surface %.2f m" % surf)


	for _stroke in 3:
		await _one_stroke(rake)
	_check("three strokes over a covered needle leave it buried",
		GameState.needle_taken [idx] == 0 and _body_of(idx) == null)
	_log("  surface over it after three strokes: %.3f m" % field.height_at(at.x, at.z))


	var radius:= 0.4
	field.carve_volume(Vector3(at.x, surf, at.z), radius, PI * radius * radius * 0.2)
	var over:= field.height_at(at.x, at.z)
	_check("the carve took the cover off (surface %.3f m, needle %.3f m)" % [over, at.y],
		over < at.y)
	var surfaced:= live.expose_uncovered_needles()
	_check("the sweep surfaced it on the face", surfaced == 1 and _body_of(idx) != null)
	var body:= _body_of(idx)
	if body == null:
		world.builds.demolish(rake)
		return

	var carried:= false
	for stroke in 4:
		await _one_stroke(rake)
		var nearest:= INF
		for s: Vector3 in rake._bite_sites:
			nearest = minf(nearest, s.distance_to(body.global_position))
		_log("    stroke %d  needle at %.2v  %.2f m from where it lay, %.2f m from the nearest bite, freeze %s pinned %s" % [
			stroke + 1, body.global_position, body.global_position.distance_to(at), nearest,
			body.freeze, LiveStrandManager.is_pinned(body)])
		if body.global_position.distance_to(at) > 1.5 or body.freeze and not LiveStrandManager.is_pinned(body):
			carried = true
			_log("  lifted by the rake on stroke %d, now %.1f m from where it lay" % [
				stroke + 1, body.global_position.distance_to(at)])
			break
	_check("the rake picked the surfaced needle up and threw it", carried)
	world.builds.demolish(rake)
	await get_tree().process_frame


func _site() -> Array:
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
			if player.build._rake_hay_over_chassis(at, inward, field) > Cfg.RAKE_STAND_CLEAR:
				continue
			var face:= at + inward * Cfg.RAKE_REACH
			if field.height_at(face.x, face.z) > at.y + 0.25:
				return [at, atan2(inward.x, inward.z)]
	return []


func _one_stroke(rake: PistonRake) -> void:
	var thrown_before:= rake.last_thrown
	var bites_before:= rake.last_bite
	var settle:= 0
	for _i in 240:
		await get_tree().process_frame
		_peak_live = maxi(_peak_live, world.live.active_count())
		if rake.last_thrown != thrown_before or rake.last_bite != bites_before:
			settle += 1
			if settle >= 6:
				return


func _body_of(idx: int) -> RigidBody3D:
	for b in world.live.needles:
		if is_instance_valid(b) and int(b.get_meta("needle_index", -1)) == idx:
			return b
	return null


func _check(what: String, ok: bool) -> void:
	_log("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _log(msg: String) -> void:
	print("[expose] %s" % msg)
