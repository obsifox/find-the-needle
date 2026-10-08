class_name DevHandfulProbe
extends Node


const LAND_SLACK:= 0.01


const NOT_THERE_YET:= 0.3

const FIRST_LEVEL_MAX:= 0.25


const ALL_LEVELS_MAX:= 2.5


const ROW:= 7
const ROW_STEP:= 0.08


const SPOT:= Vector3(10.0, 0.4, 0.0)

var player: Player
var live: LiveStrandManager

var _fails:= 0
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	print("\n=== a handful, floated in ===")
	if player == null or player.hand == null or live == null:
		_fail("no hand to test")
		_finish()
		return
	_rng.seed = 4242
	Tech.reset()
	player._set_tool(Player.Tool.HAND)
	player.global_position = SPOT
	player.set_look(- PI * 0.5, 0.0)
	await _ticks(30)

	_check_capacity()
	await _check_grab()
	await _check_fills_and_stops()
	await _check_float()
	await _check_let_go()
	await _check_needle()
	Tech.reset()
	_finish()


func _finish() -> void:
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	_fails += 1


func _ticks(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _lay(out:= 1.0) -> RigidBody3D:
	var eye:= player.eye_position()
	var dir:= player.look_direction()
	var across:= dir.cross(Vector3.UP).normalized()
	var b: RigidBody3D = live.spawn(eye + dir * out, Basis.looking_at(across, Vector3.UP),
		Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	if b == null:
		_fail("could not spawn a strand")
		return null
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	return b


func _fill(n: int) -> Array [RigidBody3D]:
	var got: Array [RigidBody3D] = []
	for _i in n:
		var b:= _lay()
		if b == null:
			break
		await _ticks(2)
		player.hand.primary()
		got.append(b)
	return got


func _let_go_and_tidy() -> void:
	var bodies: Array [RigidBody3D] = player.hand.held_bodies()
	player.hand.drop_held()
	await _ticks(2)
	for b in bodies:
		if is_instance_valid(b):
			live.consume(b)


func _check_capacity() -> void:
	print("\n-- the card is the count --")
	Tech.reset()
	if player.hand.capacity() != 1:
		_fail("a fresh run holds %d, not one" % player.hand.capacity())
	var top:= TechTree.max_rank("hand_carry")
	if top != Cfg.HAND_HOLD_RANKS.size():
		_fail("the card has %d levels and the table %d" % [top, Cfg.HAND_HOLD_RANKS.size()])
	var total:= 0.0
	var last:= 0.0
	for rank in range(1, top + 1):
		Tech.grant("hand_carry", rank)
		var price:= TechTree.cost_at("hand_carry", rank - 1)
		total += price
		var want:= int(Cfg.HAND_HOLD_RANKS [mini(rank, Cfg.HAND_HOLD_RANKS.size()) - 1])
		if player.hand.capacity() != want:
			_fail("level %d holds %d, not %d" % [rank, player.hand.capacity(), want])


		if price < last:
			_fail("level %d costs $%.2f, less than the one before" % [rank, price])
		last = price
	if player.hand.capacity() != 15:
		_fail("the last level holds %d, not fifteen" % player.hand.capacity())
	var first:= TechTree.cost_at("hand_carry", 0)
	if first > FIRST_LEVEL_MAX:
		_fail("the first level costs $%.2f, which is not cheap" % first)
	if total > ALL_LEVELS_MAX:
		_fail("all %d levels cost $%.2f, over $%.2f" % [top, total, ALL_LEVELS_MAX])
	print("  1 -> %d strands over %d levels, first $%.2f, all $%.2f"
		% [player.hand.capacity(), top, first, total])
	Tech.reset()


func _check_grab() -> void:
	print("\n-- one click grabs as many as the level says --")
	for rank: int in [1, TechTree.max_rank("hand_carry")]:
		Tech.reset()
		Tech.grant("hand_carry", rank)
		var row: Array [RigidBody3D] = []
		for i in ROW:
			var b:= _lay(1.0 + ROW_STEP * float(i))
			if b != null:
				row.append(b)
		await _ticks(4)
		player.hand.primary()
		var want:= mini(Tech.hand_grab(), player.hand.capacity())
		print("  level %d: one click took %d of %d hung, grab %d"
			% [rank, player.hand.count(), row.size(), Tech.hand_grab()])
		if player.hand.count() != want:
			_fail("level %d took %d on one click, not %d" % [rank, player.hand.count(), want])
		if row.size() > 0 and not player.hand.holds(row [0]):
			_fail("level %d did not take the strand nearest the eye first" % rank)
		await _let_go_and_tidy()
		for b in row:
			if is_instance_valid(b):
				live.consume(b)
		await _ticks(2)
	Tech.reset()


func _check_fills_and_stops() -> void:
	print("\n-- a click on hay takes another, until the hand is full --")
	Tech.grant("hand_carry", 2)
	var cap:= player.hand.capacity()
	for i in cap:
		var b:= _lay()
		if b == null:
			return
		await _ticks(4)
		if not player.aim.strand_lit():
			_fail("with %d of %d held, the strand on the crosshair is not outlined" % [i, cap])
		player.hand.primary()
		if player.hand.count() != i + 1:
			_fail("click %d left %d in the hand" % [i + 1, player.hand.count()])
			break
		if not player.hand.holds(b):
			_fail("click %d did not take the strand on the crosshair" % (i + 1))

	var extra:= _lay()
	await _ticks(4)
	if player.aim.strand_lit():
		_fail("a full hand still outlines a strand it cannot take")
	if not player.aim.hay_aimed():
		_fail("a full hand on hay does not know it is on hay")
	player.hand.primary()
	if player.hand.count() != cap:
		_fail("a click on hay with a full hand left %d, not %d" % [player.hand.count(), cap])
	if extra != null:
		if player.hand.holds(extra):
			_fail("a full hand took one more")
		live.consume(extra)
	print("  %d taken, the next click on hay did nothing" % player.hand.count())
	await _let_go_and_tidy()
	Tech.reset()


func _check_float() -> void:
	print("\n-- the strand floats in, it does not appear --")
	var b:= _lay()
	if b == null:
		return
	await _ticks(2)
	player.hand.primary()
	await _ticks(1)
	var gap:= b.global_position.distance_to(player.hand.hold_pose(0).origin)
	if gap < NOT_THERE_YET:
		_fail("one tick after the click the strand is already %.2f m from the fist" % gap)
	var ticks:= 1
	while not player.hand.landed() and ticks < 90:
		await _ticks(1)
		ticks += 1
	if not player.hand.landed():
		_fail("still floating after %d ticks" % ticks)
	await _ticks(1)
	var miss:= b.global_position.distance_to(player.hand.hold_pose(0).origin)
	if miss > LAND_SLACK:
		_fail("landed %.3f m from where the hand holds it" % miss)
	print("  %.2f m out one tick in, landed after %d ticks, %.4f m off the pose"
		% [gap, ticks, miss])
	await _let_go_and_tidy()


func _check_let_go() -> void:
	print("\n-- a click on nothing drops the lot, a throw throws the lot --")
	Tech.grant("hand_carry", 3)
	var got: Array [RigidBody3D] = await _fill(3)
	await _ticks(4)

	player.hand.primary()
	if player.hand.is_holding():
		_fail("a click on nothing kept %d strands" % player.hand.count())
	for b in got:
		if b.freeze or bool(b.get_meta(LiveStrandManager.META_PROTECTED, false)):
			_fail("a dropped strand is still frozen or protected")
	for b in got:
		live.consume(b)

	got = await _fill(3)
	var before:= player.hand.throws
	var dir:= player.look_direction()
	player.hand.throw_held()
	if player.hand.throws != before + 1:
		_fail("one throw of three strands counted %d throws" % (player.hand.throws - before))
	for b in got:
		if b.linear_velocity.dot(dir) < HandTool.THROW_SPEED * 0.5:
			_fail("a thrown strand left at %.2f m/s along the aim"
				% b.linear_velocity.dot(dir))
	await _ticks(2)
	for b in got:
		if is_instance_valid(b):
			live.consume(b)


	var late:= _lay()
	await _ticks(2)
	player.hand.primary()
	await _ticks(1)
	var fist:= player.hand.hold_pose(0).origin
	player.hand.throw_held()
	var off:= late.global_position.distance_to(fist)
	if off > LAND_SLACK:
		_fail("a strand thrown mid float left %.2f m from the fist" % off)
	print("  dropped and threw three; a mid float throw left %.4f m from the fist" % off)
	await _ticks(2)
	if is_instance_valid(late):
		live.consume(late)
	Tech.reset()


func _check_needle() -> void:
	print("\n-- a needle is carried alone --")
	Tech.grant("hand_carry", 3)
	var first: Array [RigidBody3D] = await _fill(1)


	var fake:= _lay()
	if fake == null:
		return
	fake.set_meta("needle_index", 0)
	await _ticks(2)
	player.hand.primary()
	if player.hand.holds(fake):
		_fail("a hand holding hay took a needle as well")


	for b in first:
		if is_instance_valid(b):
			live.consume(b)
	await _let_go_and_tidy()

	player.hand.primary()
	if not player.hand.holds(fake):
		_fail("an empty hand did not take the needle")
	if not player.hand.is_full():
		_fail("a hand with a needle in it has room")
	var hay:= _lay()
	await _ticks(2)
	player.hand.primary()
	if hay != null and player.hand.holds(hay):
		_fail("a hand holding a needle took hay as well")
	fake.remove_meta("needle_index")
	print("  hay then needle, needle then hay: neither shares")
	await _let_go_and_tidy()
	if is_instance_valid(fake):
		live.consume(fake)
	if hay != null and is_instance_valid(hay):
		live.consume(hay)
	Tech.reset()
