class_name DevToolThrowProbe
extends Node


var world: Node3D
var player: Player


const SPOT:= Vector3(13.0, 0.35, 4.0)
const FLIGHT_SECONDS:= 1.6


const WATCHED_TICKS:= 8


var _fails:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	GameState.grant_tool("pitchfork")

	GameState.grant_tool("spade")

	var with_fork:= await _throw_with(Player.Tool.PITCHFORK, "pitchfork")
	var bare:= await _throw_with(Player.Tool.HAND, "empty hands")

	print("\n=== summary ===")
	print("  fork on the bar: %.2f m     empty hands: %.2f m" % [with_fork, bare])


	_ok(with_fork > bare * 0.8,
		"a throw with the fork stowed goes about as far as one with empty hands")


	print("\n=== a tuft let go of with a blade on the bar ===")
	var r:= await _let_go(Player.Tool.SHOVEL, 0.0, "drop")
	_ok(not r ["on_pan"], "a tuft put down with the spade out does not land on the spade")
	_ok(not r ["marked"], "and the mark is gone a second later, so a click can gather it")
	r = await _let_go(Player.Tool.SHOVEL, 0.0, "throw")
	_ok(not r ["on_pan"], "a tuft thrown level with the spade out does not land on the spade")
	r = await _let_go(Player.Tool.SHOVEL, -1.0, "throw")
	_ok(not r ["on_pan"], "a tuft thrown at the floor with the spade out does not land on the spade")
	r = await _let_go(Player.Tool.SHOVEL, 0.0, "click")
	_ok(not r ["held"] and r ["speed"] > 3.0,
		"the left button throws a tuft with the spade out (%.1f m/s)" % r ["speed"])
	_ok(not r ["on_pan"], "and the thrown tuft does not land on the spade")
	r = await _let_go(Player.Tool.PITCHFORK, -1.0, "click")
	_ok(not r ["held"] and r ["speed"] > 3.0 and not r ["on_pan"],
		"the left button throws a tuft at the floor with the fork out, clear of the fork (%.1f m/s)"
			% r ["speed"])
	r = await _let_go(Player.Tool.HAND, 0.0, "click")
	_ok(not r ["held"] and r ["speed"] < 2.0,
		"with empty hands the left button still puts the tuft down (%.1f m/s)" % r ["speed"])
	print("  %d failure(s)" % _fails)
	print("[toolthrow] %s" % ("OK" if _fails == 0 else "FAILED"))
	get_tree().quit(0 if _fails == 0 else 1)


func _throw_with(tool: int, label: String) -> float:
	print("\n=== throwing a wad with %s ===" % label)
	player.global_position = SPOT + Vector3(-2.5, 0.05, 0.0)


	player.global_rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = 0.0
	player._set_tool(tool)
	for i in 30:
		await get_tree().physics_frame

	var props: PropManager = world.props
	var wad: Carryable = props.spawn("hay_wad",
		Transform3D(Basis(), player.global_position + Vector3(0.8, 1.0, 0.0)))
	if wad == null:
		print("  no wad spawned")
		_fails += 1
		return 0.0
	for i in 30:
		await get_tree().physics_frame
	if not player.carry.take(wad):
		print("  the wad was refused")
		_fails += 1
		props.remove(wad)
		return 0.0
	for i in 20:
		await get_tree().physics_frame

	var fork:= player.pitchfork
	print("  the fork is out: %s;  its collider stands %.2f m from the eye, at %.2v"
		% [str(fork._active),
			fork.body.global_position.distance_to(player.eye_position()),
			fork.body.global_position])
	var from: Vector3 = wad.global_position
	print("  the wad leaves from %.2v; it masks L_TOOL: %s"
		% [from, str(bool(wad.collision_mask & Cfg.L_TOOL))])

	wad.contact_monitor = true
	wad.max_contacts_reported = 8
	player.carry.throw()
	print("  velocity out of the hand: %.2v" % wad.linear_velocity)
	var touched:= PackedStringArray()
	for i in WATCHED_TICKS:
		await get_tree().physics_frame
		var names:= PackedStringArray()
		for b in wad.get_colliding_bodies():
			var n:= b as Node3D
			if n == null:
				continue
			names.append(n.name)
			if not touched.has(n.name):
				touched.append(n.name)
		print("    tick %d  at %.2v  v %.2v  touching [%s]"
			% [i, wad.global_position, wad.linear_velocity, ", ".join(names)])
	_ok(touched.is_empty(),
		"the wad touches nothing on its way out of the hand (it touched [%s])"
			% ", ".join(touched))

	for i in int(FLIGHT_SECONDS * 60.0) - WATCHED_TICKS:
		await get_tree().physics_frame
	var went: float = wad.global_position.x - from.x
	print("  %.2f s later it is at %.2v: %.2f m forward"
		% [FLIGHT_SECONDS, wad.global_position, went])
	props.remove(wad)
	player._set_tool(Player.Tool.HAND)
	return went


func _let_go(tool: int, pitch: float, how: String) -> Dictionary:
	var label:= "%s, %s, pitch %.1f" % [how, Player.tool_unlock(tool), pitch]
	print("\n  --- %s ---" % label)
	player.global_position = SPOT + Vector3(-2.5, 0.05, 3.0)
	player.global_rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = pitch
	player.set("_pitch", pitch)
	player._set_tool(tool)
	for i in 30:
		await get_tree().physics_frame
	var props: PropManager = world.props
	var tuft:= props.spawn("hay_tuft",
		Transform3D(Basis(), player.global_position + Vector3(0.8, 1.0, 0.0)),
		{ "strands": 40 }) as HayTuft
	var out:= { "on_pan": false, "marked": true, "held": true, "speed": 0.0 }
	if tuft == null:
		print("  no tuft spawned")
		_fails += 1
		return out
	for i in 30:
		await get_tree().physics_frame
	if not player.carry.take(tuft):
		print("  the tuft was refused")
		_fails += 1
		props.remove(tuft)
		return out
	for i in 20:
		await get_tree().physics_frame
	var started:= Time.get_ticks_msec()
	match how:
		"drop":
			player.carry.drop()
		"throw":
			player.carry.throw()
		"click":
			player._active_tool_primary(true)
	out ["held"] = player.carry.is_carrying()
	out ["speed"] = tuft.linear_velocity.length()
	var id:= tuft.get_instance_id()
	for i in 90:
		await get_tree().physics_frame
		if not is_instance_valid(tuft):
			break
		for blade: Shovel in [player.shovel, player.pitchfork]:
			if blade != null and blade._riding.has(id):
				out ["on_pan"] = true
	while Time.get_ticks_msec() < started + 1300:
		await get_tree().physics_frame
	if is_instance_valid(tuft):
		out ["marked"] = Shovel.let_go_recently(tuft)
		print("  left the hands at %.1f m/s, still held %s, on a pan %s, at %.2v"
			% [out ["speed"], str(out ["held"]), str(out ["on_pan"]), tuft.global_position])
		if player.carry.held() == tuft:
			player.carry.stow()
		props.remove(tuft)
	player._set_tool(Player.Tool.HAND)
	for i in 10:
		await get_tree().physics_frame
	return out


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	print("  %s %s" % ["PASS" if cond else "FAIL", what])
