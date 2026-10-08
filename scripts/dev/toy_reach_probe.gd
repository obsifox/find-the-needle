class_name DevToyReachProbe
extends Node


const SETTLE:= 30


const LOAD:= 12


const AIM_LIFT:= 0.15

var world: Node3D
var player: Player

var _fails: Array [String] = []


var _bucket: Carryable = null


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	Tech.grant_legacy()
	GameState.grant_tool("sand_shovel")
	GameState.grant_tool("spade")
	GameState.grant_tool("pitchfork")
	for i in SETTLE:
		await get_tree().physics_frame

	await _case_empty_toy_at_a_bucket()
	await _case_left_click_at_a_bucket()
	await _case_left_click_at_nothing_still_digs()
	await _case_e_at_open_ground_keeps_the_spade()
	await _case_loaded_toy_at_a_bucket()
	await _case_switch_with_a_loaded_blade()

	print("")
	for f in _fails:
		print("  FAIL  %s" % f)
	print("[probe] %s" % ("PASS" if _fails.is_empty() else "%d FAILURE(S)" % _fails.size()))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _case_empty_toy_at_a_bucket() -> void:
	print("\n=== an EMPTY toy spade, reaching for a bucket ===")
	var bucket:= await _stand_at_a_bucket()
	if bucket == null:
		return
	await _equip_the_toy()
	var aimed:= await _aim_at(bucket)
	print("  before: holding %s, target %s, bucket %.2f m off"
		% [_what(player.carry.held()), _what(player.carry.target()),
			bucket.global_position.distance_to(player.eye_position())])
	if not aimed:
		_fails.append("the bucket was not even the carry target with the toy spade out")
	_press_interact()
	await get_tree().physics_frame
	print("  after:  holding %s" % _what(player.carry.held()))
	if player.carry.held() != bucket:
		_fails.append("E with an empty toy spade did not pick the bucket up")
		_clear_hands()
		return
	if player.current_tool != Player.Tool.TOY:
		_fails.append("picking the bucket up moved the bar off the toy spade (tool %d)"
			% player.current_tool)


	_press_interact()
	for i in 5:
		await get_tree().physics_frame
	print("  down:   holding %s, tool %d" % [_what(player.carry.held()), player.current_tool])
	if not (player.carry.held() is SandShovel):
		_fails.append("putting the bucket down did not put the toy spade back in the hands")
	_clear_hands()


func _case_left_click_at_a_bucket() -> void:
	print("\n=== the LEFT BUTTON at a bucket, with the toy spade out ===")
	var bucket:= await _stand_at_a_bucket()
	if bucket == null:
		return
	await _equip_the_toy()
	var aimed:= await _aim_at(bucket)
	print("  before: holding %s, target %s"
		% [_what(player.carry.held()), _what(player.carry.target())])
	if not aimed:
		_fails.append("the bucket was not the carry target, so the left button was not tested")
	player._active_tool_primary(true)
	await get_tree().physics_frame
	print("  after:  holding %s" % _what(player.carry.held()))
	if player.carry.held() != bucket:
		_fails.append("the left button with a toy spade out did not pick the bucket up")
	_clear_hands()


func _case_left_click_at_nothing_still_digs() -> void:
	print("\n=== the LEFT BUTTON at the pile, with the toy spade out ===")
	_stand_at_the_pile()
	await _equip_the_toy()
	var toy:= player.carry.held() as SandShovel
	if toy == null:
		_fails.append("the toy spade was not in hand for the dig case")
		return
	print("  before: target %s, %d strands on the spade"
		% [_what(player.carry.target()), toy.carried_strands()])
	if player.carry.target() != null:
		_fails.append("there was something to reach for at the pile, so the dig was not tested")
		_clear_hands()
		return
	player._active_tool_primary(true)
	for i in 60:
		await get_tree().physics_frame
	print("  after:  holding %s, %d strands on the spade"
		% [_what(player.carry.held()), toy.carried_strands()])
	if not (player.carry.held() is SandShovel):
		_fails.append("the left button at the pile took the toy spade out of the player's hands")
	elif toy.carried_strands() <= 0:
		_fails.append("the left button at the pile did not dig")
	_clear_hands()


func _case_e_at_open_ground_keeps_the_spade() -> void:
	print("\n=== E at open ground, with the toy spade out ===")
	_stand_at_the_pile()
	await _equip_the_toy()
	print("  before: holding %s, target %s"
		% [_what(player.carry.held()), _what(player.carry.target())])
	if player.carry.target() != null:
		_fails.append("there was something to reach for, so E at nothing was not tested")
		_clear_hands()
		return
	var owned:= GameState.has_tool("sand_shovel")
	_press_interact()
	await get_tree().physics_frame
	print("  after:  holding %s, tool %d, still owned %s"
		% [_what(player.carry.held()), player.current_tool,
			GameState.has_tool("sand_shovel")])
	if not (player.carry.held() is SandShovel):
		_fails.append("E at open ground put the toy spade down, which no other tool does")
	if owned and not GameState.has_tool("sand_shovel"):
		_fails.append("E at open ground gave away ownership of the toy spade")
	_clear_hands()


func _case_loaded_toy_at_a_bucket() -> void:
	print("\n=== a LOADED toy spade, reaching for a bucket ===")
	var bucket:= await _stand_at_a_bucket()
	if bucket == null:
		return
	await _equip_the_toy()
	var toy:= player.carry.held() as SandShovel
	if toy == null:
		_fails.append("the toy spade was not in hand for the loaded case")
		return
	await _load(toy)
	var carried:= toy.carried_strands()
	print("  before: %d strands on the spade" % carried)
	if carried <= 0:
		_fails.append("could not get any hay onto the toy spade, so nothing was tested")
		return
	if not await _aim_at(bucket):
		_fails.append("the bucket was not the carry target with a loaded toy spade out")
	var loose_before:= _loose_count()
	_press_interact()
	await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	var loose_after:= _loose_count()
	print("  after:  holding %s, loose straw %d -> %d"
		% [_what(player.carry.held()), loose_before, loose_after])
	if player.carry.held() != bucket:
		_fails.append("E with a loaded toy spade did not pick the bucket up")
	if loose_after <= loose_before:
		_fails.append("the load did not end up on the ground: loose straw went %d -> %d"
			% [loose_before, loose_after])
	_clear_hands()


func _case_switch_with_a_loaded_blade() -> void:
	print("\n=== the number row with a loaded pitchfork ===")
	_stand_at_the_pile()
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for i in SETTLE:
		await get_tree().physics_frame
	player.pitchfork.scoop()
	for i in 60:
		await get_tree().physics_frame
	var carried:= player.pitchfork.carried_strands()
	print("  before: %d strands on the fork, tool %d" % [carried, player.current_tool])
	if carried <= 0:
		_fails.append("the fork picked nothing up, so the switch was not tested")
		return
	var loose_before:= _loose_count()
	player._set_tool(Player.Tool.SHOVEL)
	for i in SETTLE:
		await get_tree().physics_frame
	var loose_after:= _loose_count()
	print("  after:  tool %d, fork holds %d, loose straw %d -> %d"
		% [player.current_tool, player.pitchfork.carried_strands(),
			loose_before, loose_after])
	if player.current_tool != Player.Tool.SHOVEL:
		_fails.append("the number row refused to switch away from a loaded fork")
	if player.pitchfork.carried_strands() > 0:
		_fails.append("%d strands stayed on the fork after switching away from it"
			% player.pitchfork.carried_strands())
	if loose_after <= loose_before:
		_fails.append("the forkful did not reach the ground: loose straw went %d -> %d"
			% [loose_before, loose_after])


func _press_interact() -> void:
	var ev:= InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	player._unhandled_input(ev)


func _stand_at_a_bucket() -> Carryable:
	_clear_hands()


	player.global_position = Vector3(10.5, 0.4, 0.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	var at:= player.global_position + Vector3(0.9, 0.5, 0.0)


	if _bucket == null or not is_instance_valid(_bucket):
		var props: PropManager = world.props
		_bucket = props.spawn("bucket", Transform3D(Basis.IDENTITY, at))
	else:
		_bucket.global_transform = Transform3D(Basis.IDENTITY, at)
		if _bucket is RigidBody3D:
			(_bucket as RigidBody3D).linear_velocity = Vector3.ZERO
			(_bucket as RigidBody3D).angular_velocity = Vector3.ZERO
	var bucket: Carryable = _bucket
	if bucket == null:
		_fails.append("could not place a bucket to reach for")
		return null
	for i in SETTLE:
		await get_tree().physics_frame


	if not await _aim_at(bucket):
		_fails.append("empty-handed, the bucket was not the carry target either, so the rig is wrong")
		print("  rig check: empty hands see %s at %.2f m"
			% [_what(player.carry.target()),
				bucket.global_position.distance_to(player.eye_position())])
		return null
	return bucket


func _aim_at(bucket: Carryable) -> bool:
	for i in SETTLE:
		_look_at(bucket.global_position + Vector3(0.0, AIM_LIFT, 0.0))
		await get_tree().physics_frame
		if player.carry.target() == bucket:
			return true
	return false


func _look_at(at: Vector3) -> void:
	var dir:= (at - player.eye_position()).normalized()
	player.rotation.y = atan2(- dir.x, - dir.z)
	player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))


func _equip_the_toy() -> void:
	player._set_tool(Player.Tool.TOY)
	for i in SETTLE:
		await get_tree().physics_frame


func _load(toy: SandShovel) -> void:
	var live: LiveStrandManager = world.live
	var g:= toy.pan_geometry()
	var xf: Transform3D = g ["xf"]
	var origin: Vector3 = g ["origin"]
	var rng:= RandomNumberGenerator.new()
	rng.seed = 12345
	for i in LOAD:
		var local:= Vector3(rng.randf_range(-0.05, 0.05), 0.1,
			rng.randf_range(-0.05, 0.05)) + origin
		live.spawn(xf * local, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
	for i in 60:
		await get_tree().physics_frame


func _loose_count() -> int:
	var live: LiveStrandManager = world.live
	var n:= 0
	for b in live._active:
		if not live.is_held_by_a_tool(b):
			n += 1
	return n


func _clear_hands() -> void:
	if player.carry != null and player.carry.is_carrying():
		if player.carry.held() is SandShovel:
			player._stow_toy()
		else:
			player.carry.drop()
	player.current_tool = Player.Tool.HAND


func _what(item: Object) -> String:
	if item == null:
		return "nothing"
	return item.get_class() if not (item is Carryable) else (item as Carryable).display_name


func _stand_at_the_pile() -> void:
	_clear_hands()
	player.global_position = Vector3(11.5, 0.4, 0.0)
	player.rotation = Vector3(0, PI * 0.5, 0)
	player.head.rotation.x = -0.55
	player.velocity = Vector3.ZERO
