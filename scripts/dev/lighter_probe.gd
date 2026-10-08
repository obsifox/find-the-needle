class_name DevLighterProbe
extends Node


const LEDGER_TOL:= 2.0

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func run() -> void:
	await _frames(60)
	print("[lighter] build: %s" % ("demo" if Cfg.DEMO else "full"))
	player.capture_mouse(true)
	await _demo_case()
	if not Cfg.DEMO:
		Tech.grant("lighter", 1)
		_ok(ItemDb.is_unlocked("lighter"), "the licence puts the lighter on the counter")
		_ok(GameState.grant_tool("lighter"), "and one can be handed over")
		player._set_tool(Player.Tool.LIGHTER)
		await _secs(1.3)
		_ok(player.current_tool == Player.Tool.LIGHTER and player.lighter.is_ready(),
			"out and open (%s)" % player.lighter.state_name())
		await _pile_case()
		await _cooldown_case()
		await _slab_case()
		await _prop_case()
	print("\n[lighter] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _demo_case() -> void:
	print("\n=== the demo does not sell it ===")
	_ok(TechTree.is_demo("lighter") == Cfg.DEMO,
		"the licence is %s" % ("a demo padlock" if Cfg.DEMO else "for sale"))
	_ok("lighter" in GameState.TOOL_IDS, "the lighter is a tool id")
	if not Cfg.DEMO:
		_ok(is_equal_approx(Tech.next_cost("lighter"), Cfg.LIGHTER_LICENCE_COST),
			"the licence costs $%d" % int(Cfg.LIGHTER_LICENCE_COST))
		_ok(is_equal_approx(ItemDb.price("lighter"), Cfg.PRICE_LIGHTER),
			"the lighter costs $%d at the counter" % int(Cfg.PRICE_LIGHTER))
		GameState.money = maxf(GameState.money, Cfg.LIGHTER_LICENCE_COST * 2.0)
		Tech.grant("dump_hatch")
		_ok(not bool(Tech.can_buy("lighter") ["ok"]), "the dump hatch alone does not open the licence")
		Tech.grant("yard_vac")
		var after: Dictionary = Tech.can_buy("lighter")
		_ok(bool(after ["ok"]), "the yard vac licence opens it (%s)" % str(after.get("reason", "")))
		return
	Tech.grant("lighter", 1)
	_ok(not Tech.is_unlocked("lighter"), "a free grant does not hand over the licence")
	_ok(not ItemDb.is_unlocked("lighter"), "so the shop row stays locked")
	_ok(not GameState.grant_tool("lighter"), "GameState will not hand one over")
	player._set_tool(Player.Tool.LIGHTER)
	_ok(player.current_tool != Player.Tool.LIGHTER, "and the bar will not equip one")
	var d:= GameState.to_dict()
	d ["owned_tools"] = ["spade", "lighter"]
	GameState.from_dict(d)
	_ok(GameState.has_tool("spade") and not GameState.has_tool("lighter"),
		"a full save opened in the demo hands over its spade and not its lighter")
	_ok("lighter" in GameState.to_dict() ["owned_tools"],
		"and writes the lighter back out rather than deleting it")


	_ok(player.lighter.visual.get_child_count() == 0, "the demo loads no lighter model")
	var props: PropManager = world.props
	var at:= Transform3D(Basis(), Vector3(13.0, 0.2, 5.0))
	props.from_array([{ "id": "lighter", "xform": at, "state": { } },
		{ "id": "spade", "xform": at.translated(Vector3(1.0, 0.0, 0.0)), "state": { } }])
	await _frames(2)
	var spawned: Array [String] = []
	for item in props.items:
		if is_instance_valid(item):
			spawned.append(item.item_id)
	_ok(spawned.has("spade") and not spawned.has("lighter"),
		"a full save's yard spawns its spade and not its lighter (%s)" % [spawned])
	var rows:= props.to_array().filter(func(r: Variant) -> bool:
		return typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("id", "")) == "lighter")
	_ok(rows.size() == 1, "and writes the lying lighter back out (%d)" % rows.size())
	props.clear()


var _face:= Vector3.ZERO


func _pile_case() -> void:
	print("\n=== one fire in the pile ===")
	var field: HayField = world.field
	var live: LiveStrandManager = world.live
	var r:= 0.0
	for i in 80:
		var probe:= 9.5 - float(i) * 0.1
		if field.height_at(probe, 0.0) > 0.6:
			r = probe
			break
	_face = Vector3(r, field.height_at(r, 0.0), 0.0)
	var stand:= Vector3(r + 1.5, 0.0, 0.0)
	stand.y = maxf(field.height_at(stand.x, stand.z), 0.0)
	_stand_at(stand, _face - stand)
	await _frames(20)
	_look_at(_face)
	await _frames(4)
	var l:= player.lighter
	_ok(l.has_target(), "the lighter sees hay in the face of the pile")

	var rng:= RandomNumberGenerator.new()
	rng.seed = 41
	var needles: Array [int] = []
	for off: Vector3 in [Vector3(-0.12, -0.1, 0.1), Vector3(-0.08, -0.14, -0.2)]:
		needles.append(GameState.register_needle(_face + off, rng))

	var hay_before:= GameState.hay_total
	_ok(l.strike(), "the strike is taken")
	var fire: HayFire = null
	for i in 90:
		await get_tree().physics_frame
		fire = l.current_fire()
		if fire != null:
			break
	_ok(fire != null, "and the flame catches")
	if fire == null:
		return
	_ok(l.cooldown_left() > Cfg.LIGHTER_COOLDOWN - 1.0, "the cooldown starts when it lights")

	var ticks:= 0
	var tick_rate:= Engine.physics_ticks_per_second
	var max_ticks:= int((float(Cfg.LIGHTER_BURN_STRANDS) / Cfg.LIGHTER_BURN_RATE + 15.0) * tick_rate)
	while fire.is_burning() and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1
	var ledger:= hay_before - GameState.hay_total
	print("  burned %d in %.1f s: %d loose, %d from tufts and wads, %d off the crust; ledger fell %.1f"
		% [fire.burned, float(ticks) / 60.0, fire.burned_loose, fire.burned_props,
			fire.burned_pile, ledger])
	_ok(not fire.is_burning(), "it went out")
	_ok(fire.burned == Cfg.LIGHTER_BURN_STRANDS,
		"it burned exactly %d strands" % Cfg.LIGHTER_BURN_STRANDS)
	_ok(fire.burned_loose + fire.burned_props + fire.burned_pile == fire.burned,
		"every strand it burned is counted once")
	_ok(absf(ledger - float(fire.burned_pile)) <= LEDGER_TOL,
		"the ledger fell by what came off the crust (%.1f against %d)" % [ledger, fire.burned_pile])
	_ok(absf(ledger + float(fire.burned_loose + fire.burned_props)
			- float(Cfg.LIGHTER_BURN_STRANDS)) <= LEDGER_TOL,
		"ledger drop plus loose plus props is %d" % Cfg.LIGHTER_BURN_STRANDS)
	for idx in needles:
		var body:= _needle_body(live, idx)
		_ok(GameState.needle_taken [idx] == 1 and body != null,
			"needle %d came out of the ground and still exists" % idx)


func _needle_body(live: LiveStrandManager, idx: int) -> RigidBody3D:
	for b in live.needles:
		if is_instance_valid(b) and int(b.get_meta("needle_index", -1)) == idx:
			return b
	return null


func _cooldown_case() -> void:
	print("\n=== the cooldown ===")
	var l:= player.lighter
	for i in 60 * 6:
		if l.is_ready():
			break
		await get_tree().physics_frame
	_ok(l.is_ready(), "the lid is shut on the flame and opened ready again")
	_ok(l.cooldown_left() > 0.0, "the lighter is still cooling down (%.0f s)" % l.cooldown_left())
	var first:= l.current_fire()
	_look_at(_face)
	await _frames(3)
	var took:= l.strike()
	var state:= l.state_name()
	await _frames(40)
	_ok(not took, "a strike in the cooldown is refused")
	_ok(state == "DUD", "and strikes sparks instead (%s)" % state)
	_ok(l.current_fire() == first and not l.is_fire_burning(), "and no second fire starts")


func _slab_case() -> void:
	print("\n=== on the slab, beside things it must not touch ===")
	var props: PropManager = world.props
	var live: LiveStrandManager = world.live
	var builds: BuildManager = world.builds
	var spot:= Vector3(13.4, 0.05, 8.0)


	_stand_at(spot + Vector3(-1.6, 0.0, 0.0), Vector3(1, 0, 0))

	var belt:= builds.add_conveyor(spot + Vector3(-3.0, 0.0, 1.0), spot + Vector3(3.0, 0.0, 1.0))
	var rider:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
		spot + Vector3(-2.6, 1.2, 1.0)), { "strands": 30 }) as HayWad
	var claimed:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
		spot + Vector3(0.3, 0.3, -0.5)), { "strands": 25 }) as HayWad
	var bucket:= props.spawn("bucket", Transform3D(Basis.IDENTITY,
		spot + Vector3(-0.5, 0.2, -0.6))) as HayContainer
	var tufts: Array [HayTuft] = []
	for i in 2:
		tufts.append(props.spawn("hay_tuft", Transform3D(Basis.IDENTITY,
			spot + Vector3(0.0, 0.1, -0.2 + 0.4 * float(i))), { "strands": 40 + 20 * i }) as HayTuft)
	await _frames(30)
	claimed.set_meta(PropManager.META_CLAIM, get_instance_id())
	if bucket != null:
		bucket.stored = 40
	await _frames(60)


	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		live.spawn(spot + Vector3(rng.randf_range(-0.3, 0.3), 0.15 + rng.randf() * 0.1,
			rng.randf_range(-0.3, 0.3)), StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))
	await _frames(12)

	var riding:= BeltPath.is_rider(rider)
	_ok(riding, "the wad dropped on the belt is riding it")
	_ok(not HayFire.burnable_prop(rider), "and a fire will not take a load off a belt")
	_ok(not HayFire.burnable_prop(claimed), "nor a wad a machine has claimed")

	player.lighter.debug_clear_cooldown()
	_look_at(spot)
	await _frames(3)
	_ok(player.lighter.has_target(), "the lighter sees the heap on the slab")
	var fire:= player.lighter.light_at(spot)
	var scorch:= fire.get_node_or_null("Scorch") as MeshInstance3D
	_ok(scorch != null and scorch.visible,
		"a fire on bare floor lays a scorch mark (field height here %.3f)"
			% (world.field as HayField).height_at(spot.x, spot.z))
	var ticks:= 0
	while fire.is_burning() and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	print("  burned %d: %d loose, %d from tufts, %d off the crust, out after %.1f s"
		% [fire.burned, fire.burned_loose, fire.burned_props, fire.burned_pile,
			float(ticks) / 60.0])
	var tufts_left:= 0
	for t in tufts:
		if is_instance_valid(t) and props.items.has(t):
			tufts_left += 1
	_ok(not fire.is_burning() and fire.burned < Cfg.LIGHTER_BURN_STRANDS,
		"with only a heap to eat it starved and went out short of its budget")
	_ok(tufts_left == 0, "the tufts are burned (%d left)" % tufts_left)
	_ok(fire.burned_loose > 0, "and so is the loose straw (%d)" % fire.burned_loose)
	_ok(is_instance_valid(claimed) and claimed.hay_strands() == 25,
		"the claimed wad kept its 25 strands")
	_ok(bucket != null and is_instance_valid(bucket) and bucket.stored == 40,
		"the bucket kept its 40")
	_ok(is_instance_valid(belt) and belt.is_inside_tree(), "the belt is still standing")

	claimed.remove_meta(PropManager.META_CLAIM)
	for item: Carryable in [rider, claimed, bucket]:
		if is_instance_valid(item):
			props.remove(item)
	builds.clear()


func _prop_case() -> void:
	print("\n=== dropped, and picked back up ===")
	var props: PropManager = world.props
	_stand_at(Vector3(11.0, 0.05, 8.0), Vector3(1, 0, 0))
	await _frames(20)
	player._set_tool(Player.Tool.LIGHTER)
	await _secs(1.0)
	var t0:= Time.get_ticks_usec()
	player.drop_active_tool()
	var drop_ms:= float(Time.get_ticks_usec() - t0) / 1000.0
	_ok(player.lighter.state_name() == "STOWED",
		"Q takes it out of the hand at once, lid and all (%s)" % player.lighter.state_name())
	print("        the first drop took %.1f ms" % drop_ms)
	await _frames(30)
	_ok(not GameState.has_tool("lighter"), "Q takes the lighter out of the pockets")
	var prop: ToolProp = null
	for it in props.items:
		if it is ToolProp and (it as ToolProp).tool_id == "lighter":
			prop = it
	_ok(prop != null, "and stands it on the floor as a ToolProp")
	if prop == null:
		return
	_ok(prop.find_children("*", "AnimationPlayer", true, false).is_empty(),
		"lying down with nothing left to animate it")
	_ok(prop.claim(player), "picking it up is allowed")
	props.remove(prop)
	await _frames(3)
	_ok(GameState.has_tool("lighter") and player.current_tool == Player.Tool.LIGHTER,
		"and it is back in the hands")

	print("\n=== thrown, the second time a lighter is put down ===")
	await _secs(1.0)
	var t1:= Time.get_ticks_usec()
	player.throw_active_tool()
	var throw_ms:= float(Time.get_ticks_usec() - t1) / 1000.0
	_ok(player.lighter.state_name() == "STOWED", "F takes it out of the hand at once")
	_ok(throw_ms < 25.0,
		"and a later lighter does not skin its mesh again (%.1f ms)" % throw_ms)
	await _frames(3)
	var thrown: ToolProp = null
	for it in props.items:
		if it is ToolProp and (it as ToolProp).tool_id == "lighter":
			thrown = it
	_ok(thrown != null and thrown.find_children("*", "Skeleton3D", true, false).size() <= 1
		and _skinned_meshes(thrown) == 0, "and it still lies there baked, with no skin left")


func _skinned_meshes(root: Node) -> int:
	var n:= 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			n += 1
	return n


func _stand_at(pos: Vector3, facing: Vector3) -> void:
	player.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, atan2(- facing.x, - facing.z), 0.0)


func _look_at(at: Vector3) -> void:
	var to:= at - player.eye_position()
	var flat:= Vector2(to.x, to.z)
	player.rotation = Vector3(0.0, atan2(- to.x, - to.z), 0.0)
	player.head.rotation.x = clampf(atan2(to.y, flat.length()), -1.5, 1.5)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await _frames(int(ceil(s * float(Engine.physics_ticks_per_second))))
