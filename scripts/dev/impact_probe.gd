class_name DevImpactProbe
extends Node


const SPOT:= Vector3(13.0, 0.0, 2.0)


const SETTLE:= 40

const FLIGHT:= 2.5


const GENTLE_DROP:= 0.12


const THROW_DIR:= Vector3(1, 0.55, 0)

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
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = SPOT + Vector3(0, 0.4, 0)
	for i in 20:
		await get_tree().physics_frame

	print("\n=== thrown, it lands out loud ===")
	print("  %-12s %-14s %6s %7s" % ["item", "key", "heard", "dv"])
	await _throw("spade", "tool_clang")
	await _throw("pitchfork", "tool_clang")
	await _throw("broom", "item_clatter")
	await _throw("bucket", "item_clatter")


	await _throw("sand_shovel", "plastic_drop")
	await _throw("hay_bale", "bale_land")
	await _throw("eco_brick", "brick_land")
	await _throw("hay_wad", "wad_land")

	print("\n=== set down, it does not ===")
	await _gentle("spade", "tool_clang")
	await _gentle("bucket", "item_clatter")


	await _gentle("hay_wad", "wad_land")

	print("\n=== hay stays out of it ===")


	var wad:= _spawn("hay_wad", SPOT + Vector3(0, 3.0, 0))
	if wad != null:
		_ok(wad.impact_sfx() == "wad_land", "a hay wad lands as loose hay")
		_ok(wad.contact_monitor, "and now pays for contact reporting to do it")
		_free(wad)
	else:
		_ok(false, "a hay wad could be spawned")
	await get_tree().physics_frame


	for pair in [["sand_shovel", "tool_clang"], ["eco_brick", "build_place_metal"],
			["hay_bale", "hay_dump"], ["hay_wad", "hay_dump"]]:
		var item:= _spawn(pair [0], SPOT + Vector3(0, 0.2, 0))
		if item == null:
			_ok(false, "%s could be spawned" % pair [0])
			continue
		_ok(item.impact_sfx() != pair [1],
			"a %s does not borrow '%s'" % [pair [0], pair [1]])
		_free(item)
	await get_tree().physics_frame

	print("\n=== summary ===")
	print("  %d failure(s)" % _fails)
	print("[impact] %s" % ("OK" if _fails == 0 else "FAILED"))
	get_tree().quit(0 if _fails == 0 else 1)


func _spawn(id: String, at: Vector3) -> Carryable:
	var props: PropManager = world.props
	return props.spawn(id, Transform3D(Basis.IDENTITY, at))


func _free(item: Carryable) -> void:
	var props: PropManager = world.props
	props.remove(item)


func _dv(item: Carryable) -> float:
	var st:= PhysicsServer3D.body_get_direct_state(item.get_rid())
	if st == null:
		return 0.0
	var hardest:= 0.0
	for i in st.get_contact_count():
		hardest = maxf(hardest, st.get_contact_impulse(i).length())
	return hardest / item.mass


func _throw(id: String, key: String) -> void:
	var item:= _spawn(id, SPOT + Vector3(0, 1.4, 0))
	if item == null:
		_ok(false, "%s could be spawned" % id)
		return


	item.tumble()
	item.linear_velocity = THROW_DIR.normalized() * Cfg.CARRY_THROW_SPEED
	item.angular_velocity = Vector3(0, 0, -8.0)
	var heard:= 0
	var peak:= 0.0
	var last_mute: float = item._impact_mute_until
	var t:= 0.0
	while t < FLIGHT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		peak = maxf(peak, _dv(item))
		if item._impact_mute_until > last_mute:
			last_mute = item._impact_mute_until
			heard += 1
	print("  %-12s %-14s %6d %7.2f" % [id, key, heard, peak])
	_ok(heard >= 1, "a thrown %s is heard landing" % id)
	_ok(heard <= 2, "and is heard %d time(s), not once per bounce" % heard)
	_ok(item.impact_sfx() == key, "and it is '%s' that it asks for" % key)
	_free(item)
	await get_tree().physics_frame


func _gentle(id: String, key: String) -> void:
	var item:= _spawn(id, SPOT + Vector3(0, GENTLE_DROP, 0))
	if item == null:
		_ok(false, "%s could be spawned" % id)
		return
	var before: float = item._impact_mute_until
	var peak:= 0.0
	var t:= 0.0
	while t < 1.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		peak = maxf(peak, _dv(item))
	_ok(item._impact_mute_until == before,
		"a %s set down from %.0f cm makes no '%s' (hardest dv %.2f)"
			% [id, GENTLE_DROP * 100.0, key, peak])
	_free(item)
	await get_tree().physics_frame
