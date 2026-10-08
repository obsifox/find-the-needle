class_name DevBladePickProbe
extends Node


const SETTLE:= 30

const WAD_ALONG:= 1.4

var world: Node3D
var player: Player

var _fails: Array [String] = []
var _wad: HayWad = null


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	GameState.grant_tool("sand_shovel")
	GameState.grant_tool("spade")
	GameState.grant_tool("pitchfork")
	for i in SETTLE:
		await get_tree().physics_frame

	await _case_edge(Player.Tool.SHOVEL, "spade")
	await _case_edge(Player.Tool.PITCHFORK, "fork")
	await _case_edge(Player.Tool.TOY, "toy spade")
	await _case_bare_floor_still_digs()

	print("")
	for f in _fails:
		print("  FAIL  %s" % f)
	print("[bladepick] %s" % ("PASS" if _fails.is_empty() else "%d FAILURE(S)" % _fails.size()))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _case_edge(tool: Player.Tool, label: String) -> void:
	print("\n=== the ragged edge of a wad, with the %s out ===" % label)
	_clear_hands()
	var wad:= await _stand_at_a_wad()
	if wad == null:
		return
	player._set_tool(tool)
	for i in SETTLE:
		await get_tree().physics_frame
	if not await _aim_at_edge(wad):
		_fails.append("%s: found no aim at the wad's edge that the bare pick ray misses" % label)
		_clear_hands()
		return
	var on_blade_before:= _blade_load()
	print("  before: target %s, ray alone %s, blade holds %d"
		% [_what(player.carry.target()), _what(player.carry._probe_ray(false)), on_blade_before])
	if player.carry.target() != wad:
		_fails.append("%s: the wad at the edge was not offered to the hand (no hover wash)" % label)
	player._active_tool_primary(true)
	for i in SETTLE:
		await get_tree().physics_frame
	print("  after:  holding %s, tool %d" % [_what(player.carry.held()), player.current_tool])
	if player.carry.held() != wad:
		_fails.append("%s: a click at the wad's edge did not put the wad in the hands" % label)
	_clear_hands()


func _case_bare_floor_still_digs() -> void:
	print("\n=== bare floor, with the spade out ===")
	_clear_hands()
	if _wad != null and is_instance_valid(_wad):
		world.props.remove(_wad)
		_wad = null
	_place_player()
	player._set_tool(Player.Tool.SHOVEL)
	player.head.rotation.x = -0.7
	for i in SETTLE:
		await get_tree().physics_frame
	print("  before: target %s" % _what(player.carry.target()))
	if player.carry.target() != null:
		_fails.append("bare floor: something was offered to the hand with no wad near")
	player._active_tool_primary(true)
	for i in SETTLE:
		await get_tree().physics_frame
	print("  after:  holding %s, tool %d" % [_what(player.carry.held()), player.current_tool])
	if player.carry.is_carrying():
		_fails.append("bare floor: the click picked %s up" % _what(player.carry.held()))
	if player.current_tool != Player.Tool.SHOVEL:
		_fails.append("bare floor: the spade was put away")


func _place_player() -> void:
	player.global_position = Vector3(10.5, 0.4, 0.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO


func _stand_at_a_wad() -> HayWad:
	_place_player()
	for i in SETTLE:
		await get_tree().physics_frame
	var fwd:= - player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at:= player.global_position + fwd * WAD_ALONG
	at.y = 0.05


	if _wad == null or not is_instance_valid(_wad):
		_wad = world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at),
			{ "strands": 50 }) as HayWad
	else:
		_wad.global_transform = Transform3D(Basis.IDENTITY, at)
		_wad.linear_velocity = Vector3.ZERO
		_wad.angular_velocity = Vector3.ZERO
	if _wad == null:
		_fails.append("could not spawn a wad")
		return null
	for i in SETTLE:
		await get_tree().physics_frame
	return _wad


func _aim_at_edge(wad: HayWad) -> bool:
	var side:= player.global_transform.basis.x
	side.y = 0.0
	side = side.normalized()
	var half:= wad.clearance_size().x * 0.5
	var off:= half * 0.6
	while off < half + 0.08:
		_look_at(wad.global_position + side * off)

		for i in 8:
			await get_tree().physics_frame
		if player.carry._probe_ray(false) == null:
			print("  aimed %.3f m off the wad's centre (drawn half width %.3f)" % [off, half])
			return true
		off += 0.01
	return false


func _look_at(at: Vector3) -> void:
	var dir:= (at - player.eye_position()).normalized()
	player.rotation.y = atan2(- dir.x, - dir.z)
	player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))


func _blade_load() -> int:
	match player.current_tool:
		Player.Tool.SHOVEL:
			return player.shovel.carried_strands()
		Player.Tool.PITCHFORK:
			return player.pitchfork.carried_strands()
	return 0


func _clear_hands() -> void:
	if player.carry != null and player.carry.is_carrying():
		if player.carry.held() is SandShovel:
			player._stow_toy()
		else:
			player.carry.drop()
	player._set_tool(Player.Tool.HAND)


func _what(item: Object) -> String:
	if item == null:
		return "nothing"
	return item.get_class() if not (item is Carryable) else (item as Carryable).display_name
