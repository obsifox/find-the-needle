class_name DevNeedlePinProbe
extends Node


const LOG:= "res://needle_pin_probe.log"


const YARD:= Vector3(13.0, 0.0, 0.0)


const PATIENCE:= 180

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()

var _flashes:= 0
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	_rng.seed = 20260825
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))


	player.global_position = YARD + Vector3(-6.0, 0.4, 0.0)
	await _settle(30)

	await _case_pins_where_it_lands()
	await _case_hay_cannot_move_it()
	await _case_a_dig_wakes_it()
	await _case_lost_footing()
	await _case_a_hand_can_take_it()
	await _case_a_belt_can_take_it()
	await _case_a_dig_lands_it_on_the_blade()
	await _case_every_blade_can_hold_one()
	await _case_a_fork_lifts_a_lone_needle()
	await _case_a_blade_does_not_drop_it()
	await _case_a_loose_needle_winks_up_close()
	await _case_the_pile_cannot_swallow_one()
	await _case_wallhack()


	await _case_a_halved_pile_keeps_its_needles()

	if _fails.is_empty():
		_log("\nOK")
	else:
		for f in _fails:
			_log("\nFAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_pins_where_it_lands() -> void:
	_log("\n=== pins where it lands ===")
	var n:= _drop(YARD + Vector3(0, 1.2, 0))
	if n == null:
		return
	var pinned:= await _await_pinned(n)
	_check("pinned after landing", pinned)
	_check("frozen while pinned", n.freeze)
	var at:= n.global_position
	await _settle(60)
	var moved:= n.global_position.distance_to(at)
	_log("  drift over a second while pinned: %.4f m" % moved)
	_check("does not drift", moved < 0.001)
	_clear()


func _case_hay_cannot_move_it() -> void:
	_log("\n=== hay cannot move it ===")
	var n:= _drop(YARD + Vector3(0, 1.2, 0))
	if n == null:
		return
	if not await _await_pinned(n):
		_check("pinned before the hay lands", false)
		_clear()
		return
	var at:= n.global_position
	for i in 20:
		world.live.spawn(at + Vector3(_rng.randf_range(-0.15, 0.15), 1.0,
			_rng.randf_range(-0.15, 0.15)),
			StrandFactory.random_strand_basis(_rng),
			Vector3(0, -3.0, 0), Cfg.COL_HAY_LIGHT)
	await _settle(90)
	var moved:= n.global_position.distance_to(at)
	_log("  moved by 20 strands landing on it: %.4f m" % moved)
	_check("hay does not shift a pinned needle", moved < 0.001)
	_clear()


func _case_a_dig_wakes_it() -> void:
	_log("\n=== a dig wakes it ===")
	var n:= _drop(YARD + Vector3(0, 1.2, 0))
	if n == null:
		return
	if not await _await_pinned(n):
		_check("pinned before the dig", false)
		_clear()
		return
	world.live.reveal_needles_in(n.global_position, 1.0)
	_check("unpinned by a dig on top of it", not LiveStrandManager.is_pinned(n))
	_check("thawed, not merely unflagged", not n.freeze)
	_clear()


func _case_lost_footing() -> void:
	_log("\n=== loses its footing ===")
	var n:= _drop(YARD + Vector3(0, 1.2, 0))
	if n == null:
		return
	if not await _await_pinned(n):
		_check("pinned before the ground goes", false)
		_clear()
		return
	n.global_position = YARD + Vector3(0, 4.0, 0)
	var thawed:= false
	for i in PATIENCE:
		await get_tree().physics_frame
		if not LiveStrandManager.is_pinned(n):
			thawed = true
			break
	_check("unpinned once nothing is under it", thawed)
	await _settle(120)
	_log("  fell back to y=%.2f" % n.global_position.y)
	_check("falls again once thawed", n.global_position.y < 1.0)
	_clear()


func _case_a_hand_can_take_it() -> void:
	_log("\n=== a hand can take it ===")
	var n:= _drop(YARD + Vector3(0, 1.2, 0))
	if n == null:
		return
	if not await _await_pinned(n):
		_check("pinned before the grab", false)
		_clear()
		return
	player.hand._grab(n)
	_check("held", player.hand.is_holding())
	_check("no longer reads as pinned", not LiveStrandManager.is_pinned(n))
	_check("still frozen -- now because a hand has it", n.freeze)
	player.hand.drop_held()
	await _settle(10)
	_check("thawed when let go of", not n.freeze)
	_clear()


func _case_a_belt_can_take_it() -> void:
	_log("\n=== a belt can take it ===")
	GameState.add_money(2000.0)
	var a:= YARD + Vector3(0, 0.75, -5.0)
	var b:= YARD + Vector3(0, 0.75, 5.0)
	world.builds.add_conveyor(a, b)
	await _settle(30)


	var n:= _drop(a + Vector3(0, 0.4, 0.6))
	if n == null:
		return
	var deck_at:= Vector3.ZERO
	var aboard:= false
	for i in PATIENCE:
		await get_tree().physics_frame
		if BeltPath.is_rider(n):
			aboard = true
			deck_at = n.global_position
			break
	_check("a needle dropped on a belt is caught", aboard)
	if aboard:
		await _settle(60)
		var along:= n.global_position.distance_to(deck_at)
		_log("  carried %.2f m in a second" % along)
		_check("actually carried", along > 0.2)
		_check("not still flagged pinned while riding",
			not LiveStrandManager.is_pinned(n))
	_clear()
	if not aboard:
		return


	var m:= _drop(YARD + Vector3(1.6, 1.2, -5.0))
	if m == null:
		return
	if not await _await_pinned(m):
		_check("pinned on the floor beside the belt", false)
		_clear()
		return
	m.global_position = deck_at


	_log("  set down on the deck frozen: pinned=%s"
		% ("yes" if LiveStrandManager.is_pinned(m) else "no"))
	var taken:= false
	for i in PATIENCE:
		await get_tree().physics_frame
		if BeltPath.is_rider(m):
			taken = true
			break
	_check("a PINNED needle put on the deck is caught", taken)
	if taken:
		var was:= m.global_position
		await _settle(60)
		_log("  carried %.2f m in a second" % m.global_position.distance_to(was))
		_check("carried once caught", m.global_position.distance_to(was) > 0.2)
		_check("no longer flagged pinned", not LiveStrandManager.is_pinned(m))
	_clear()


func _case_a_dig_lands_it_on_the_blade() -> void:
	_log("\n=== a dig lands the needle on the blade ===")


	GameState.grant_tool(Player.tool_unlock(Player.Tool.SHOVEL))
	player._set_tool(Player.Tool.SHOVEL)
	await _settle(10)
	var sh: Shovel = player.shovel
	_check("the spade is in hand at all", sh.basin.monitoring)


	var hole:= YARD + Vector3(2.5, 0.0, 0.0)
	var idx:= GameState.register_needle(hole + Vector3(0, 0.3, 0), _rng)
	var lying:= _drop(hole + Vector3(0.15, 0.6, 0))
	if lying == null:
		return
	_check("the loose one has settled first", await _await_pinned(lying))

	var landed: int = world.live.reveal_needles_in(hole, 0.6, sh.needle_landing_now)
	_log("  handed to the blade: %d" % landed)
	_check("both came up", landed == 2)
	var pan:= sh._hold_centre()
	var reach:= sh._hold_radius()
	var dug:= _body_for(idx)
	_check("the buried one became a body", dug != null)
	if dug != null:
		_log("  the dug one landed %.3f m from the pan centre (reach %.3f)"
			% [dug.global_position.distance_to(pan), reach])
		_check("the dug one is in the pan, not in the hole",
			dug.global_position.distance_to(pan) <= reach)
	_log("  the loose one landed %.3f m from the pan centre"
		% lying.global_position.distance_to(pan))
	_check("the loose one came up with it",
		lying.global_position.distance_to(pan) <= reach)
	_check("and is not still nailed to the floor",
		not LiveStrandManager.is_pinned(lying))


	await _settle(45)
	_log("  carried in the pan a second later: %d" % sh.carried_strands())
	_check("the blade is holding them", sh.carried_strands() >= 2)
	_clear()


func _case_a_blade_does_not_drop_it() -> void:
	_log("\n=== a blade standing still keeps its needle ===")
	GameState.grant_tool(Player.tool_unlock(Player.Tool.SHOVEL))
	player._set_tool(Player.Tool.SHOVEL)


	player.head.rotation.x = -0.9
	await _settle(20)
	var sh: Shovel = player.shovel
	var at:= sh.needle_landing_now()
	_log("  pan at %.2v, %.2f m over the floor" % [at, at.y])
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	var n: RigidBody3D = world.live.reveal_needle(index, at)
	if n == null:
		_fails.append("could not put a needle on the blade")
		return
	LiveStrandManager.hold(n)


	await _settle(90)
	_log("  after a second and a half: pinned=%s frozen=%s, pan holds %d"
		% [LiveStrandManager.is_pinned(n), n.freeze, sh.carried_strands()])
	_check("a needle in the pan is not pinned to the world",
		not LiveStrandManager.is_pinned(n))
	_check("and is still on the blade", sh.carried_strands() >= 1)
	var in_pan:= n.global_position.distance_to(sh._hold_centre())


	_log("  %.3f m from the pan centre (grip %.3f)" % [in_pan, sh._hold_radius()])
	_check("has not slid out of the dish", in_pan <= sh._hold_radius() + 0.06)


	var was:= n.global_position
	player.global_position += Vector3(1.5, 0.0, 0.0)
	await _settle(30)
	_log("  moved %.2f m when the player did" % n.global_position.distance_to(was))
	_check("carried when the blade moves",
		n.global_position.distance_to(was) > 0.5)
	player.head.rotation.x = 0.0
	_clear()


func _case_every_blade_can_hold_one() -> void:
	_log("\n=== every blade can hold one ===")
	for which: int in [Player.Tool.SHOVEL, Player.Tool.PITCHFORK]:


		GameState.grant_tool(Player.tool_unlock(which))
		player._set_tool(which)
		await _settle(10)
		var spade: bool = which == Player.Tool.SHOVEL
		var t: Shovel = player.shovel if spade else player.pitchfork
		var label:= "spade" if spade else "fork"
		_check("the %s is in hand at all" % label, t.basin.monitoring)
		await _lands_in_basin(label, t.needle_landing_now(), t.basin)
		_clear()

	player._set_tool(Player.Tool.HAND)
	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("sand_shovel")
	player.select_hotbar_slot(4)
	await _settle(20)
	var toy:= player.carry.held() as SandShovel
	if toy == null:
		_fails.append("the toy shovel would not come out")
		return
	var n:= await _lands_in_basin("toy", toy.needle_landing_now(), toy._basin)
	_clear()


	if n != null:
		var pinned:= _drop(toy.needle_landing_now())
		if pinned != null:
			world.live.pin_needle(pinned)
			_check("pinned for the sweep", LiveStrandManager.is_pinned(pinned))
			await _settle(20)
			_check("the toy blade thaws what it is carrying",
				not LiveStrandManager.is_pinned(pinned))
			_log("  toy pan holds: %d" % toy.carried_strands())
			_check("the toy blade is holding it", toy.carried_strands() >= 1)
	_clear()
	player._set_tool(Player.Tool.HAND)
	if player.carry.is_carrying():
		player.carry.drop()
	await _settle(10)


func _case_a_fork_lifts_a_lone_needle() -> void:
	_log("\n=== a fork lifts a needle lying on its own ===")
	GameState.grant_tool(Player.tool_unlock(Player.Tool.PITCHFORK))
	player._set_tool(Player.Tool.PITCHFORK)
	player.head.rotation.x = -0.9
	await _settle(10)
	var fork: Shovel = player.pitchfork
	var n:= _drop(player.global_position + Vector3(0.0, 1.0, -1.2))
	if n == null:
		return
	_check("pinned alone on the floor", await _await_pinned(n))
	var g:= fork.pan_geometry()
	var got:= fork.gather_at(n.global_position, int(g ["max"]), float(g ["radius"]),
		g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]))
	_log("  gather returned %d" % got)
	_check("the click counts the needle", got >= 1)
	_check("no longer pinned", not LiveStrandManager.is_pinned(n))
	await _settle(45)
	var off:= n.global_position.distance_to(fork._hold_centre())
	_log("  %.3f m from the tines (grip %.3f), fork holds %d"
		% [off, fork._hold_radius(), fork.carried_strands()])
	_check("the needle is on the fork", off <= fork._hold_radius() + 0.06)
	player.head.rotation.x = 0.0
	_clear()
	player._set_tool(Player.Tool.HAND)
	await _settle(10)


func _lands_in_basin(what: String, at: Vector3, basin: Area3D) -> RigidBody3D:
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	var b: RigidBody3D = world.live.reveal_needle(index, at)
	if b == null:
		_fails.append("could not put a needle on the %s" % what)
		return null


	LiveStrandManager.hold(b)

	await _settle(2)
	if not basin.monitoring:
		_fails.append("the %s's pan is switched off -- nothing to ask" % what)
		return b
	var seen:= false
	for other in basin.get_overlapping_bodies():
		if other == b:
			seen = true
	_log("  %s: landed at %.3v" % [what, at])
	_check("the %s puts a needle inside its own pan" % what, seen)
	return b


func _body_for(index: int) -> RigidBody3D:
	for b in world.live.needles:
		if is_instance_valid(b) and int(b.get_meta("needle_index", -1)) == index:
			return b
	return null


func _case_the_pile_cannot_swallow_one() -> void:
	_log("\n=== the pile cannot swallow one ===")
	var field: HayField = world.field
	if field == null or field.heights.is_empty():
		_fails.append("no pile to swallow anything")
		return
	var crown:= Vector2(Cfg.PILE_CENTER.x, Cfg.PILE_CENTER.z)
	var top:= field.height_at(crown.x, crown.y)
	_log("  crown stands %.2f m over the slab" % top)


	var deep:= Vector3(crown.x + 2.5, 0.05, crown.y)
	var n:= _drop(deep + Vector3(0, 0.02, 0))
	if n == null:
		return
	var up:= await _await_surfaced(n, field)
	_log("  came up at %.2v" % n.global_position)
	_check("does not stay under the hay", up)
	var drift:= Vector2(n.global_position.x - deep.x,
		n.global_position.z - deep.z).length()
	_log("  %.2f m from the column it was under" % drift)
	_check("surfaces through its own column", drift < 0.25)
	_check("and is frozen where it surfaced", LiveStrandManager.is_pinned(n))
	_clear()


	var aim:= Vector3(crown.x + 1.4, 0.0, crown.y - 0.9)
	aim.y = field.height_at(aim.x, aim.z)
	var thrown:= _drop(aim + Vector3(0, 2.5, 0))
	if thrown == null:
		return
	thrown.linear_velocity = Vector3(0, -9.0, 0)


	var caught:= await _await_pinned(thrown)
	var rest_at:= thrown.global_position
	var under:= field.depth_floor_at(rest_at.x, rest_at.z) - rest_at.y
	var off:= Vector2(rest_at.x - aim.x, rest_at.z - aim.z).length()
	_log("  thrown in at %.2v, stopped %.2f m away and %.3f m under the hay"
		% [aim, off, under])
	_check("a needle thrown into the pile comes to rest", caught)
	_check("on the hay rather than inside it", under <= LiveStrandManager.NEEDLE_SUNK)
	_check("where it was thrown, not where the pile takes it", off < 0.6)
	_check("and is frozen there", LiveStrandManager.is_pinned(thrown))
	_clear()


	var rests:= _drop(Vector3(crown.x + 1.1, top + 0.4, crown.y + 0.7))
	if rests == null:
		return
	_check("settles on the pile", await _await_pinned(rests))
	var lay:= rests.global_position
	await _settle(150)
	var hop:= rests.global_position.distance_to(lay)
	_log("  a needle resting on hay moved %.4f m over two and a half seconds"
		% hop)
	_check("leaves a needle resting on the pile alone", hop < 0.001)


	_clear()
	var quiet:= _drop(YARD + Vector3(2.5, 1.2, 0))
	if quiet == null:
		return
	_check("the control needle settled", await _await_pinned(quiet))
	var stood:= quiet.global_position
	await _settle(120)
	var moved:= quiet.global_position.distance_to(stood)
	_log("  a needle in the open drifted %.4f m over two seconds" % moved)
	_check("leaves a needle in the open alone", moved < 0.001)
	_clear()


func _await_surfaced(b: RigidBody3D, field: HayField) -> bool:
	for i in 300:
		await get_tree().process_frame
		var p:= b.global_position
		if p.y >= field.depth_floor_at(p.x, p.z):
			return true
	return false


func _case_a_loose_needle_winks_up_close() -> void:
	_log("\n=== a loose needle winks up close ===")
	var glints: NeedleGlints = world.needle_glints
	if glints == null:
		_fails.append("no needle glints on the world")
		return


	var n:= _drop(YARD + Vector3(2.5, 1.2, 0))
	if n == null:
		return
	_check("settled first", await _await_pinned(n))
	var at:= n.global_position
	_log("  needle at %.2v  valid=%s frozen=%s pinned=%s  live needles=%d"
		% [at, is_instance_valid(n), n.freeze, LiveStrandManager.is_pinned(n),
			world.live.needles.size()])

	await _stand_off(at, 8.0)
	_log("  from 8 m out: %d drawn, peak %.3f" % [glints.drawn(), glints.peak()])
	_check("nothing from across the room", glints.drawn() == 0)


	await _stand_off(at, 0.6)
	var flashes:= 0
	var near_peak:= await _brightest_over(glints, 4.0)
	_log("  standing over it: %d drawn, brightest over 4s %.3f, %d flashes"
		% [glints.drawn(), near_peak, _flashes])
	_check("lit when you are on top of it", glints.drawn() == 1 and near_peak > 0.5)
	flashes = _flashes


	_check("flashes more than once while you stand still", flashes >= 2)

	await _stand_off(at, 3.0)
	var far_peak:= await _brightest_over(glints, 4.0)
	_log("  three metres off: %d drawn, brightest over 4s %.3f"
		% [glints.drawn(), far_peak])
	_check("dimmer the further off you are", far_peak < near_peak)


	await _stand_off(at, 0.6)
	var before:= glints.drawn()
	GameState.register_needle(player.global_position + Vector3(0.3, 0.1, 0.0), _rng)
	await _idle(3)
	_log("  with one buried underfoot: %d drawn" % glints.drawn())
	_check("a buried needle is never drawn", glints.drawn() == before)

	player.hand._grab(n)
	await _idle(3)
	_log("  once picked up: %d drawn" % glints.drawn())
	_check("a needle in a hand is not drawn", glints.drawn() == 0)
	player.hand.drop_held()
	await _idle(3)


	var field: HayField = world.field
	var flank:= Vector3(7.4, 0.0, 3.2)
	flank.y = field.height_at(flank.x, flank.z) - 0.05
	world.live.unpin(n)
	n.global_position = flank
	n.linear_velocity = Vector3.ZERO
	await _stand_off(n.global_position, 1.2)
	_log("  in the crust: %d drawn" % glints.drawn())
	_check("a needle in the hay still flashes", glints.drawn() == 1)


	var behind:= _behind_something_solid()
	if behind == Vector3.ZERO:
		_log("  (nothing solid within reach to hide a needle behind)")
	else:
		world.live.unpin(n)
		n.global_position = behind
		n.freeze = true
		await _idle(20)
		_log("  behind something solid at %.2v: %d drawn"
			% [behind, glints.drawn()])
		_check("does not flash through walls and machines", glints.drawn() == 0)
		n.freeze = false
	_clear()


func _behind_something_solid() -> Vector3:
	var eye:= player.eye_position()
	for step in 12:
		var yaw:= TAU * float(step) / 12.0
		var dir:= Vector3(sin(yaw), -0.15, cos(yaw)).normalized()
		var q:= PhysicsRayQueryParameters3D.create(eye, eye + dir * 4.0)
		q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
		q.collide_with_areas = false


		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		var at: Vector3 = hit ["position"]


		if eye.distance_to(at) > 3.5:
			continue
		return at + dir * 0.25
	return Vector3.ZERO


func _brightest_over(glints: NeedleGlints, seconds: float) -> float:
	var top:= 0.0
	var t:= 0.0


	var armed:= true
	_flashes = 0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var now:= glints.peak()
		top = maxf(top, now)
		if armed and now > 0.6:
			_flashes += 1
			armed = false
		elif now < 0.15:
			armed = true
	return top


func _stand_off(target: Vector3, back: float) -> void:
	player.global_position = target + Vector3(back, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	await _idle(3)
	_log("    eye %.2f m from the mark" % player.eye_position().distance_to(target))


func _idle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _case_wallhack() -> void:
	_log("\n=== wallhack ===")
	var hack: NeedleWallhack = world.needle_wallhack
	if hack == null:
		_fails.append("no wallhack node -- Cfg.DEBUG is off")
		return
	var n:= _drop(YARD + Vector3(0, 1.2, 0))
	if n == null:
		return
	await _settle(20)
	hack.set_enabled(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var seen:= hack.census()
	var buried:= int(seen ["buried"])
	var loose:= int(seen ["loose"])
	_log("  census: %d buried, %d loose" % [buried, loose])
	_check("counts the needle just dropped", loose >= 1)
	var shown:= 0
	for child in hack.get_children():
		if (child as Node3D).visible:
			shown += 1
	_log("  markers drawn: %d" % shown)
	_check("one marker per needle", shown == buried + loose)
	hack.set_enabled(false)
	await get_tree().process_frame
	var left:= 0
	for child in hack.get_children():
		if (child as Node3D).visible:
			left += 1
	_check("nothing drawn once switched off", left == 0)
	_clear()


func _case_a_halved_pile_keeps_its_needles() -> void:
	_log("\n=== a halved pile keeps its needles ===")
	var field: HayField = world.field
	if field == null or field.heights.is_empty():
		_fails.append("no field to halve")
		return


	var mine:= PackedInt32Array()
	for k in 3:
		var at: Vector3 = Cfg.PILE_CENTER + Vector3(float(k) * 0.7 - 0.7, 0.0, 0.0)
		var surf:= field.height_at(at.x, at.z)
		if surf < 1.0:
			continue
		at.y = surf * 0.75
		mine.append(GameState.register_needle(at, _rng))
	_check("three needles buried in the crown", mine.size() == 3)

	var buried:= _buried_count()
	for i in field.heights.size():
		field.heights [i] *= 0.5
	field.rebuild_everything()


	var stranded:= _stranded_count(field, 0.0)
	_log("  above the new surface, before settling: %d of %d" % [stranded, buried])
	_check("halving alone strands needles", stranded > 0)

	var moved: Dictionary = world.live.settle_buried_needles(0.5)
	_log("  sunk %d, surfaced %d" % [int(moved ["sunk"]), int(moved ["surfaced"])])
	_check("every needle still buried is under hay",
		_stranded_count(field, LiveStrandManager.NEEDLE_HEADROOM) == 0)
	_check("none were left where they were",
		int(moved ["sunk"]) + int(moved ["surfaced"]) >= stranded)
	_check("the ledger is the same length", _buried_count()
		+ int(moved ["surfaced"]) == buried)

	var bodies:= 0
	for b in world.live.needles:
		if is_instance_valid(b):
			bodies += 1
	_log("  loose bodies now: %d" % bodies)
	_check("surfaced needles are real bodies", bodies >= int(moved ["surfaced"]))

	for idx in mine:
		var p:= GameState.needle_positions [idx]
		_check("crown needle %d accounted for" % idx,
			GameState.needle_taken [idx] == 1
			or p.y <= field.depth_floor_at(p.x, p.z)
				- LiveStrandManager.NEEDLE_HEADROOM)
	_clear()


func _buried_count() -> int:
	var n:= 0
	for i in GameState.needle_positions.size():
		if GameState.needle_taken [i] == 0:
			n += 1
	return n


func _stranded_count(field: HayField, slack: float) -> int:
	var n:= 0
	for i in GameState.needle_positions.size():
		if GameState.needle_taken [i] != 0:
			continue
		var p:= GameState.needle_positions [i]
		if p.y > field.depth_floor_at(p.x, p.z) - slack:
			n += 1
	return n


func _drop(at: Vector3) -> RigidBody3D:
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	var b: RigidBody3D = world.live.reveal_needle(index, at)
	if b == null:
		_fails.append("could not spawn a needle at %.2v" % at)
	return b


func _await_pinned(b: RigidBody3D) -> bool:
	for i in PATIENCE:
		await get_tree().physics_frame
		if LiveStrandManager.is_pinned(b):
			return true
	return false


func _clear() -> void:
	if player.hand.is_holding():
		player.hand.drop_held()
	var live: LiveStrandManager = world.live
	for b in live.needles.duplicate():
		BeltPath.release(b)
		live.consume_needle(b)


func _check(what: String, ok: bool) -> void:
	_log("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _log(msg: String) -> void:
	print("[needlepin] %s" % msg)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(msg)
	f.close()
