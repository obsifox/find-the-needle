class_name DevTubLoadProbe
extends Node


const SETTLE:= 20
const KINDS:= ["bucket", "wheelbarrow"]

const SPOT:= Vector3(13.0, 0.05, 4.0)

const LAND:= 150


const RIDE_IN:= 300

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func run() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, note: String = "") -> void:
	if ok:
		_pass += 1
		print("  ok    %s%s" % [label, "" if note.is_empty() else "   " + note])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if note.is_empty() else "   " + note])


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	Tech.grant_legacy()
	player.global_position = SPOT + Vector3(0.0, 0.4, 2.5)
	for i in SETTLE:
		await get_tree().physics_frame

	for id: String in KINDS:
		print("\n=== %s: loads dropped from the air ===" % id)
		for n: int in [50, Cfg.WAD_MAX_STRANDS]:
			await _air(id, "hay_wad", n)
		for n: int in [12, 40, Cfg.TUFT_MAX]:
			await _air(id, "hay_tuft", n)
		print("\n=== %s: loads dropped out of the player's hands ===" % id)
		await _hand(id, "hay_wad", 50)
		await _hand(id, "hay_tuft", 40)
		await _hand(id, "hay_tuft", Cfg.TUFT_MAX)
		print("\n=== %s: loads tipped off the spade ===" % id)
		await _spade_pour(id, "hay_wad", 50)
		await _spade_pour(id, "hay_tuft", 40)

	print("\n=== the spade picking a load up off the floor ===")
	await _spade_click("hay_wad", 50)
	await _spade_click("hay_tuft", 40)
	await _spade_click("hay_tuft", Cfg.TUFT_MAX)
	await _spade_end_to_end()
	print("\n=== a tuft dumped off the fork ===")
	for walk: float in [0.0, 4.0]:
		for pitch: float in [-60.0, -25.0, 0.0, 30.0]:
			for n: int in [12, Cfg.TUFT_MAX]:
				await _fork_dump(n, pitch, walk)

	print("\n=== a load riding a belt through the mouth ===")
	for id: String in KINDS:
		await _belt_ride(id, 50)

	print("\n=== the count over the mouth ===")
	_check("full strength beside it", is_equal_approx(FillCount.range_strength(1.0), 1.0))
	_check("gone across the yard", FillCount.range_strength(FillCount.HIDE_RANGE) <= 0.0)
	for id: String in KINDS:
		await _count(id)
	if DisplayServer.get_name() != "headless":
		for id: String in KINDS:
			await _photo(id)

	print("\n%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _air(kind: String, load_id: String, n: int) -> void:
	var box: HayContainer = await _stand(kind)
	if box == null:
		return
	var props: PropManager = world.props
	var at:= box.pour_point() + Vector3.UP * 0.5
	var thing:= props.spawn(load_id, Transform3D(Basis.IDENTITY, at), { "strands": n }) as HayWad
	if thing == null:
		_check("%s: could place a %s" % [kind, load_id], false)
		props.remove(box)
		return
	await _judge(box, thing, n, "%s: a %d strand %s dropped in" % [kind, n, _noun(load_id)])


func _hand(kind: String, load_id: String, n: int) -> void:
	var box: HayContainer = await _stand(kind)
	if box == null:
		return
	player._set_tool(Player.Tool.HAND)
	player.head.rotation.x = 0.0
	player.set("_pitch", 0.0)
	var props: PropManager = world.props
	var thing:= props.spawn(load_id,
		Transform3D(Basis.IDENTITY, player.global_position + Vector3(0.0, 1.0, -1.0)),
		{ "strands": n }) as HayWad
	if thing == null or not player.carry.take(thing):
		_check("%s: could take hold of a %s" % [kind, load_id], false)
		if thing != null:
			props.remove(thing)
		props.remove(box)
		return
	for i in 6:
		await get_tree().physics_frame

	var over:= thing.global_position - box.pour_point()
	box.global_position += Vector3(over.x, 0.0, over.z)
	box.sleeping = false
	for i in 20:
		await get_tree().physics_frame
	player.carry.drop()
	await _judge(box, thing, n, "%s: a %d strand %s dropped from the hands" % [kind, n, _noun(load_id)])


func _spade_pour(kind: String, load_id: String, n: int) -> void:
	var box: HayContainer = await _stand(kind)
	if box == null:
		return
	box.global_rotation = Vector3.ZERO
	for i in 20:
		await get_tree().physics_frame
	var spade: Shovel = await _spade()

	player.global_position = SPOT + Vector3(0.0, 0.4, 1.3)
	player.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame
	_look_at(box.pour_point())
	for i in 6:
		await get_tree().physics_frame
	var props: PropManager = world.props
	var thing:= props.spawn(load_id, Transform3D(Basis.IDENTITY, spade._hold_centre()),
		{ "strands": n }) as HayWad
	for i in 40:
		await get_tree().physics_frame
	var riding:= spade.carried_strands()
	_check("%s: the pan holds a %d strand %s" % [kind, n, _noun(load_id)], riding >= n,
		"%d in the pan" % riding)
	_check("%s: and the spade sees the %s" % [kind, kind], spade.pour_target() == box)
	spade.dump()
	await _judge(box, thing, n, "%s: a %d strand %s tipped off the spade" % [kind, n, _noun(load_id)])
	player.global_position = SPOT + Vector3(0.0, 0.4, 2.5)
	player.velocity = Vector3.ZERO


func _belt_ride(kind: String, n: int) -> void:
	var props: PropManager = world.props
	var builds: BuildManager = world.builds
	var box: HayContainer = await _stand(kind)
	if box == null:
		return
	var centre:= box.to_global(box._hold_local)
	var over:= box._hold_radius * 0.9
	var line:= centre + Vector3.UP * over
	var along:= Vector3.RIGHT
	var run:= builds.add_conveyor(line - along * 3.0, line + along * 1.0)
	if run == null:
		_check("%s: a run could be laid over the mouth" % kind, false)
		props.remove(box)
		return
	builds.rebuild_junctions()
	for i in 10:
		await get_tree().physics_frame
	var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
		line - along * 1.2 + Vector3.UP * 0.25), { "strands": n }) as HayWad


	var made:= wad != null


	for i in 30:
		await get_tree().physics_frame
	_check("%s: the wad rides the run as a record and not as a body" % kind,
		made and not is_instance_valid(wad), "stored %d so far" % box.stored)
	for i in RIDE_IN:
		await get_tree().physics_frame
		if box.stored >= n:
			break
	_check("%s: a %d strand wad riding a belt over the tub goes in" % [kind, n],
		box.stored == n, "stored %d of %d, hold %.2v r %.2f, deck %.2f over it"
		% [box.stored, n, centre, box._hold_radius, over])
	props.remove(box)
	builds.demolish(run)
	for i in 4:
		await get_tree().physics_frame


func _spade_click(load_id: String, n: int) -> void:
	var spade: Shovel = await _spade()
	var props: PropManager = world.props
	var at:= SPOT + Vector3(0.0, 0.1, 1.2)
	var thing:= props.spawn(load_id, Transform3D(Basis.IDENTITY, at), { "strands": n }) as HayWad
	for i in 60:
		await get_tree().physics_frame
	_look_at(thing.global_position)
	for i in 6:
		await get_tree().physics_frame
	var aim:= spade.aim_point()
	spade.scoop()
	for i in 60:
		await get_tree().physics_frame
	var riding:= spade.carried_strands()
	_check("a click on a %d strand %s puts it on the pan" % [n, _noun(load_id)], riding >= n,
		"%d in the pan, aim %s" % [riding, aim])


	var from:= spade._hold_centre()
	spade.dump()
	_check("the dumped %s passes through the blade" % _noun(load_id),
		spade.body in thing.get_collision_exceptions())
	for i in 90:
		await get_tree().physics_frame
	if is_instance_valid(thing):
		_check("and leaves the pan", thing not in spade.basin.get_overlapping_bodies(),
			"%.2f m from where it rode" % thing.global_position.distance_to(from))
		_check("and collides with the blade again once clear",
			spade.body not in thing.get_collision_exceptions())
		props.remove(thing)


func _spade_end_to_end() -> void:
	var box: HayContainer = await _stand("bucket")
	if box == null:
		return
	box.global_rotation = Vector3.ZERO
	var spade: Shovel = await _spade()
	player.global_position = SPOT + Vector3(0.0, 0.4, 1.4)
	player.velocity = Vector3.ZERO
	var props: PropManager = world.props
	var tuft:= props.spawn("hay_tuft", Transform3D(Basis.IDENTITY, SPOT + Vector3(1.0, 0.1, 1.4)),
		{ "strands": 40 }) as HayWad
	for i in 60:
		await get_tree().physics_frame
	_look_at(tuft.global_position)
	for i in 6:
		await get_tree().physics_frame
	spade.scoop()
	for i in 60:
		await get_tree().physics_frame
	_check("the click put the tuft on the pan", spade.carried_strands() >= 40,
		"%d in the pan" % spade.carried_strands())
	_look_at(box.pour_point())
	for i in 10:
		await get_tree().physics_frame
	_check("the spade sees the bucket", spade.pour_target() == box,
		"%.2f m to the mouth" % player.eye_position().distance_to(box.pour_point()))
	spade.dump()
	await _judge(box, tuft, 40, "a tuft off the floor, onto the spade and into the bucket")
	player.global_position = SPOT + Vector3(0.0, 0.4, 2.5)
	player.velocity = Vector3.ZERO


func _fork_dump(n: int, pitch: float, walk: float) -> void:
	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	var fork: Shovel = player.pitchfork
	fork.reset_aim()
	player.global_position = SPOT + Vector3(-2.0, 0.4, 2.5)
	player.velocity = Vector3.ZERO
	var props: PropManager = world.props
	var tuft:= props.spawn("hay_tuft", Transform3D(Basis.IDENTITY,
		SPOT + Vector3(-2.0, 0.1, 1.3)), { "strands": n }) as HayWad
	for i in 60:
		await get_tree().physics_frame
	_look_at(tuft.global_position)
	for i in 6:
		await get_tree().physics_frame
	fork.scoop()
	for i in 60:
		await get_tree().physics_frame
	player.head.rotation.x = deg_to_rad(pitch)
	player.set("_pitch", deg_to_rad(pitch))
	for i in 20:
		await get_tree().physics_frame
	var riding:= fork.carried_strands()
	if riding < n:
		_check("the fork holds a %d strand tuft at %+.0f degrees" % [n, pitch], false,
			"%d on the tines" % riding)
		if is_instance_valid(tuft):
			props.remove(tuft)
		return
	var from:= tuft.global_position
	var ahead:= - player.global_basis.z
	fork.dump()


	var close:= 0
	for i in 60:
		if walk > 0.0:
			player.global_position += ahead * walk / Engine.physics_ticks_per_second
		await get_tree().physics_frame
		if is_instance_valid(tuft) and tuft.global_position.distance_to(fork._hold_centre()) < 0.5:
			close += 1
	var gone:= tuft.global_position.distance_to(from) if is_instance_valid(tuft) else INF
	var apart:= tuft.global_position.distance_to(fork._hold_centre()) if is_instance_valid(tuft) else INF
	var speed:= tuft.linear_velocity.length() if is_instance_valid(tuft) else 0.0
	_check("a %d strand tuft dumped at %+.0f degrees, walking %.0f m/s, leaves the fork"
			% [n, pitch, walk],
		is_instance_valid(tuft) and apart > 0.5 and speed < walk * 0.5 + 0.5,
		"%.2f m from the head, %.2f m from where it rode, near it %d ticks, %.1f m/s"
			% [apart, gone, close, speed])
	if is_instance_valid(tuft):
		props.remove(tuft)
	await get_tree().physics_frame


func _count(kind: String) -> void:
	player._set_tool(Player.Tool.HAND)
	player.global_position = SPOT + Vector3(0.0, 0.4, 2.5)
	player.velocity = Vector3.ZERO
	var box: HayContainer = await _stand(kind)
	if box == null:
		return
	var count:= box.get_node_or_null("FillCount") as FillCount
	_check("%s: has a count" % kind, count != null)
	if count == null:
		world.props.remove(box)
		return
	box.stored = 123
	await _frames(4)
	var want:= "123 / %d" % box.capacity()
	_check("%s: it reads the load" % kind, count.shown_text() == want,
		"\"%s\", wanted \"%s\"" % [count.shown_text(), want])
	var mouth:= box.to_local(box.pour_point())
	_check("%s: over the mouth" % kind,
		Vector2(count.position.x - mouth.x, count.position.z - mouth.z).length() < 0.02
			and count.position.y > mouth.y)


	var props: PropManager = world.props
	var tuft:= props.spawn("hay_tuft", Transform3D(Basis.IDENTITY, box.pour_point() + Vector3.UP * 0.5),
		{ "strands": 40 }) as HayWad
	for i in LAND:
		await get_tree().physics_frame
		if not is_instance_valid(tuft):
			break
	await _frames(2)
	want = "163 / %d" % box.capacity()
	_check("%s: and follows what goes in" % kind, count.shown_text() == want,
		"\"%s\", wanted \"%s\"" % [count.shown_text(), want])

	player.global_position = SPOT + Vector3(0.0, 0.4, 9.0)
	await _frames(4)
	_check("%s: hidden from across the yard" % kind, count.shown_text() == "")
	player.global_position = SPOT + Vector3(0.0, 0.4, 2.5)
	player.velocity = Vector3.ZERO
	await _frames(4)

	box.flash_full()
	await _frames(2)
	_check("%s: stands aside for the FULL badge" % kind, count.shown_text() == "")
	var badge:= box.get_node_or_null("FullBadge") as FullBadge
	if badge != null:
		badge.snuff()
	await _frames(2)
	_check("%s: and comes back after it" % kind, count.shown_text() != "")

	if player.carry.take(box):
		await _frames(4)
		if box.carry_mode() == Carryable.Mode.HELD:
			_check("%s: hidden in the hands" % kind, count.shown_text() == "")
		else:
			_check("%s: still shown while pushed" % kind, count.shown_text() != "")
		player.carry.drop()
	else:
		_check("%s: could take hold of it" % kind, false)
	await _frames(20)
	if is_instance_valid(tuft):
		props.remove(tuft)
	props.remove(box)
	await get_tree().physics_frame


func _photo(kind: String) -> void:
	player._set_tool(Player.Tool.SHOVEL)
	var box: HayContainer = await _stand(kind)
	if box == null:
		return
	box.global_rotation = Vector3.ZERO
	box.stored = int(box.capacity() * 0.57)
	box._refresh_fill()
	player.global_position = SPOT + Vector3(0.9, 0.4, 1.6)
	player.velocity = Vector3.ZERO
	await _frames(10)
	_look_at(box.pour_point() + Vector3.DOWN * 0.25)
	await _frames(40)
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--tubload")
	var dir:= args [at + 1] if at + 1 < args.size() and not args [at + 1].begins_with("--") else "user://"
	var path:= dir.path_join("tubload_%s.png" % kind)
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
	print("  photographed %s to %s" % [kind, path])
	world.props.remove(box)
	await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _spade() -> Shovel:
	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)
	player.shovel.reset_aim()
	for i in 10:
		await get_tree().physics_frame
	return player.shovel


func _look_at(p: Vector3) -> void:
	var dir:= (p - player.eye_position()).normalized()
	player.rotation.y = atan2(- dir.x, - dir.z)
	var pitch:= asin(clampf(dir.y, -1.0, 1.0))
	player.head.rotation.x = pitch
	player.set("_pitch", pitch)


func _judge(box: HayContainer, thing: HayWad, n: int, label: String) -> void:
	var props: PropManager = world.props
	for i in LAND:
		await get_tree().physics_frame
		if not is_instance_valid(thing):
			break
	var left: int = thing.strands if is_instance_valid(thing) else 0
	var where:= ""
	if is_instance_valid(thing):
		where = ", load at %s, mouth at %s" % [thing.global_position, box.pour_point()]
	_check(label, box.stored == n and left == 0,
		"stored %d of %d, %d left in the load%s" % [box.stored, n, left, where])
	if is_instance_valid(thing):
		props.remove(thing)
	props.remove(box)
	await get_tree().physics_frame


func _stand(kind: String) -> HayContainer:
	var props: PropManager = world.props
	var box:= props.spawn(kind, Transform3D(Basis.IDENTITY, SPOT)) as HayContainer
	if box == null:
		_check("could place a %s" % kind, false)
		return null
	for i in 45:
		await get_tree().physics_frame
	box.stored = 0
	return box


func _noun(load_id: String) -> String:
	return "tuft" if load_id == "hay_tuft" else "wad"
