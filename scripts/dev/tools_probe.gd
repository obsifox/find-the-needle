class_name DevToolsProbe
extends Node


const LOOK_DOWN:= 0.6


const TOY_LOAD:= 12

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


	var props: PropManager = world.props
	for i in 40:
		await get_tree().process_frame

	player.global_position = Vector3(13.0, 0.4, 2.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	for i in 20:
		await get_tree().physics_frame

	print("\n=== a fresh run is bare-handed ===")
	Tech.reset()
	GameState.owned_tools = { }
	GameState.tools_changed.emit()
	await get_tree().physics_frame
	_ok(not GameState.has_tool("spade"), "no spade")
	_ok(not Player.is_tool_unlocked(Player.Tool.SHOVEL), "so slot 2 is empty")
	_ok(Player.is_tool_unlocked(Player.Tool.HAND), "but the hand is always there")
	player.select_hotbar_slot(1)
	_ok(player.current_tool == Player.Tool.HAND,
		"and pressing 2 does not equip a spade nobody owns")

	print("\n=== the licence is a licence, and the counter is the purchase ===")


	Tech.grant("spade", 1)
	await get_tree().physics_frame
	_ok(not GameState.has_tool("spade"), "the licence alone does not hand one over")
	player.select_hotbar_slot(1)
	_ok(player.current_tool == Player.Tool.HAND,
		"and slot 2 still equips nothing")
	GameState.grant_tool("spade")
	await get_tree().physics_frame
	_ok(GameState.has_tool("spade"), "buying one at the shop does")
	player.select_hotbar_slot(1)
	_ok(player.current_tool == Player.Tool.SHOVEL, "and slot 2 equips it")

	print("\n=== Q puts it down as a real object ===")


	_ok(_hint_says("Drop spade"), "the hint strip names the key")
	var before:= props.count_of("spade")
	player.drop_active_tool()
	for i in 30:
		await get_tree().physics_frame
	_ok(props.count_of("spade") == before + 1,
		"a spade is standing in the yard")
	_ok(not GameState.has_tool("spade"), "and is no longer on the bar")
	_ok(player.current_tool == Player.Tool.HAND, "the hands are empty again")
	_ok(not _hint_says("Drop spade"),
		"...so the strip stops offering a spade to put down")
	player.select_hotbar_slot(1)
	_ok(player.current_tool == Player.Tool.HAND,
		"pressing 2 does nothing while the spade is on the floor")

	print("\n=== and E picks it back up ===")
	var dropped:= _find_prop("spade")
	_ok(dropped != null, "the dropped spade is findable")
	if dropped != null:
		_face(dropped.global_position + Vector3(0, 0.1, 0))
		for i in 10:
			await get_tree().process_frame
		var took: bool = player.carry.try_pick()
		for i in 5:
			await get_tree().physics_frame
		_ok(took, "E takes it")
		_ok(GameState.has_tool("spade"), "the spade is back on the bar")
		_ok(player.current_tool == Player.Tool.SHOVEL, "...and back in your hands")
		_ok(not player.carry.is_carrying(),
			"a tool is EQUIPPED, not carried like a bucket")
		_ok(props.count_of("spade") == before,
			"and the object on the floor is gone")

	print("\n=== the toy shovel does the same, as a carried object ===")


	Tech.grant("sand_shovel", 1)
	await get_tree().physics_frame
	_ok(not GameState.has_tool("sand_shovel"),
		"the licence alone does not hand one over")
	GameState.grant_tool("sand_shovel")
	await get_tree().physics_frame
	_ok(GameState.has_tool("sand_shovel"), "buying one at the shop does")
	player.select_hotbar_slot(4)
	for i in 10:
		await get_tree().physics_frame
	_ok(player.current_tool == Player.Tool.TOY, "slot 5 equips it")
	_ok(player.carry.held() is SandShovel, "...and it really is in your hands")
	player.select_hotbar_slot(0)
	for i in 10:
		await get_tree().physics_frame
	_ok(not player.carry.is_carrying(), "switching away puts it away")
	_ok(GameState.has_tool("sand_shovel"), "without losing it")
	_ok(props.count_of("sand_shovel") == 0,
		"and without leaving one lying in the yard")

	player.select_hotbar_slot(4)
	for i in 10:
		await get_tree().physics_frame
	player.drop_active_tool()
	for i in 30:
		await get_tree().physics_frame
	_ok(props.count_of("sand_shovel") == 1, "Q drops it as an object")
	_ok(not GameState.has_tool("sand_shovel"), "and gives up ownership")

	print("\n=== F throws whatever is in your hands ===")


	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player.select_hotbar_slot(1)
	for i in 10:
		await get_tree().physics_frame
	_ok(player.current_tool == Player.Tool.SHOVEL, "the spade is in your hands")
	var spades:= props.count_of("spade")
	player.throw_active_tool()


	await get_tree().physics_frame
	var flying:= _find_prop("spade")
	_ok(props.count_of("spade") == spades + 1, "F puts a spade in the world")
	_ok(not GameState.has_tool("spade"),
		"and gives up ownership, exactly as Q does")
	_ok(player.current_tool == Player.Tool.HAND, "the hands are empty again")
	if flying != null:
		var speed:= flying.linear_velocity.length()
		_ok(speed > Cfg.CARRY_THROW_SPEED * 0.5,
			"...and it is travelling at %.1f m/s rather than falling" % speed)
	for i in 60:
		await get_tree().physics_frame


	var bucket:= props.spawn_near("bucket", player, 0.8)
	_ok(bucket != null, "a bucket to throw")
	if bucket != null:
		player.carry.take(bucket)
		await get_tree().physics_frame
		_ok(player.carry.is_carrying(), "held")
		player.throw_active_tool()
		await get_tree().physics_frame
		_ok(not player.carry.is_carrying(), "F lets go of it")
		_ok(bucket.linear_velocity.length() > Cfg.CARRY_THROW_SPEED * 0.5,
			"and sends it, which the right button deliberately will not")
		props.remove(bucket)

	print("\n=== a bucket is not a tool ===")
	_ok(not ("bucket" in GameState.TOOL_IDS), "the bucket is not in the tool list")
	_ok(not ("wheelbarrow" in GameState.TOOL_IDS), "nor the wheelbarrow")


	_ok(Player.tool_boxes_max() < Player.HOTBAR_KEYS,
		"full pockets still leave keys for buildings")
	_ok(Player.visible_slots().size() <= Player.HOTBAR_KEYS,
		"every box on the bar has a key to press")
	_ok(Player.TOOL_SLOTS.size() > Player.tool_boxes_max(),
		"and there are more tools for sale than a player can carry at once")

	print("\n=== the save remembers who has what ===")


	Tech.grant("broom", 1)
	GameState.grant_tool("broom")
	await get_tree().physics_frame
	var held_before:= GameState.owned_tools.keys()
	held_before.sort()
	var props_before:= props.to_array().size()
	var d:= GameState.to_dict()
	GameState.owned_tools = { }
	GameState.from_dict(d)
	var held_after:= GameState.owned_tools.keys()
	held_after.sort()
	_ok(held_after == held_before,
		"the tools in hand survive: %s" % str(held_after))
	props.from_array(props.to_array())
	for i in 10:
		await get_tree().physics_frame
	_ok(props.to_array().size() == props_before,
		"and so do the ones left on the floor (%d)" % props_before)
	var back:= _find_prop("sand_shovel")
	_ok(back != null and back is SandShovel,
		"a dropped toy shovel comes back as a toy shovel")

	print("\n=== every tool is where it looks like it is ===")


	for id: String in ["spade", "pitchfork", "broom", "yard_vac", "lighter"]:
		var probe:= props.spawn(id, Transform3D(Basis(), Vector3(13.0, 1.2, 5.0))) as ToolProp
		if probe == null:
			_ok(false, "%s spawns" % id)
			continue
		for i in 90:
			await get_tree().physics_frame
		var box:= _box_of(probe)
		var mesh:= _mesh_bounds(probe)


		var off:= probe.to_local(mesh.get_center()) - box.get_center()
		_ok(Vector2(off.x, off.z).length() < 0.06,
			"%s: the mesh is on its collider, not beside it (%.2f cm out)"
				% [id, Vector2(off.x, off.z).length() * 100.0])
		_ok(mesh.size.y < mesh.size.z,
			"%s: it lies down rather than standing up (%.2f m tall, %.2f m long)"
				% [id, mesh.size.y, mesh.size.z])


		var sunk:= (probe.global_position.y + box.position.y) - mesh.position.y
		_ok(sunk < 0.06, "%s: no part of it is through the floor (%.1f cm under)"
			% [id, sunk * 100.0])
		_ok(absf(box.size.z - mesh.size.z) < 0.15,
			"%s: the collider is the length of the tool (box %.2f, mesh %.2f)"
				% [id, box.size.z, mesh.size.z])
		props.remove(probe)

	print("\n=== reaching past the toy spade ===")


	for item in props.items.duplicate():
		if item is SandShovel:
			props.remove(item)
	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("sand_shovel")
	player.select_hotbar_slot(4)
	for i in 15:
		await get_tree().physics_frame
	_ok(player.carry.held() is SandShovel, "the toy spade is in your hands")
	var toy:= player.carry.held() as SandShovel


	if toy != null:
		player.head.rotation.x = 0.0
		player.set("_pitch", 0.0)
		for i in 10:
			await get_tree().process_frame
		var level:= acos(clampf(toy.global_transform.basis.y.dot(Vector3.UP),
			-1.0, 1.0))
		player.head.rotation.x = - LOOK_DOWN
		player.set("_pitch", - LOOK_DOWN)
		for i in 10:
			await get_tree().process_frame
		var tipped:= acos(clampf(toy.global_transform.basis.y.dot(Vector3.UP),
			-1.0, 1.0))
		_ok(level < 0.12, "held level it sits flat (%.1f degrees off)"
			% rad_to_deg(level))
		_ok(absf(tipped - LOOK_DOWN) < 0.15,
			"looking down %.0f degrees pitches it %.0f, not %.0f"
				% [rad_to_deg(LOOK_DOWN), rad_to_deg(tipped), rad_to_deg(level)])
		player.head.rotation.x = 0.0
		player.set("_pitch", 0.0)

	var pail:= props.spawn("bucket",
		Transform3D(Basis(), player.global_position + Vector3(0.0, 0.4, 1.2)))
	_ok(pail != null, "a bucket within arm's reach")
	if pail != null and toy != null:
		_face(pail.global_position + Vector3(0, 0.1, 0))
		for i in 15:
			await get_tree().process_frame
		_ok(player.carry.target() == pail,
			"the ray finds it past the spade in front of the eye")
		_ok(_hint_says("Pick up"),
			"and the bar offers the pick-up rather than \"Let go\"")


		var hud: Hud = world.hud
		hud.show_toast("")
		_fill_blade(toy._hold_centre(), TOY_LOAD)
		for i in 40:
			await get_tree().physics_frame
		var loaded:= toy.carried_strands()
		_ok(loaded > 0, "%d strands put on the blade" % loaded)
		var free_before:= _loose_strands()
		var took: bool = player.try_swap_from_toy()
		for i in 30:
			await get_tree().physics_frame
		_ok(took and player.carry.held() == pail,
			"E takes the bucket even with the blade loaded")


		_ok(_held_strands() == 0,
			"and no strand is still claimed by a tool (%d held)" % _held_strands())
		_ok(_loose_strands() > free_before,
			"its load is loose on the floor: %d free strands, was %d"
				% [_loose_strands(), free_before])
		_ok(hud.toast_text().findn("dropped") >= 0,
			"and the player is told where the load went: \"%s\"" % hud.toast_text())
		_ok(player.current_tool == Player.Tool.TOY,
			"the bar stays on the toy spade while the bucket is carried")
		_ok(GameState.has_tool("sand_shovel"), "the spade is still owned")
		_ok(props.count_of("sand_shovel") == 0,
			"and it was not left lying in the yard")
		player.carry.drop()
		for i in 20:
			await get_tree().physics_frame
		_ok(player.carry.held() is SandShovel,
			"putting the bucket down puts the toy spade back in the hands")
		player._stow_toy()
		props.remove(pail)
	_clear_hay()
	for item in props.items.duplicate():
		if item is SandShovel:
			props.remove(item)
	if player.carry.is_carrying():
		player.carry.drop()
	player._set_tool(Player.Tool.HAND)
	for i in 20:
		await get_tree().physics_frame

	print("\n=== a second one you already own says so ===")


	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("spade")
	player.select_hotbar_slot(1)
	for i in 5:
		await get_tree().physics_frame
	_ok(GameState.has_tool("spade"), "the player owns a spade to begin with")
	var spare:= props.spawn("spade",
		Transform3D(Basis(), player.global_position + Vector3(0.0, 0.4, 1.2)))
	_ok(spare != null, "a second spade can be put on the floor")
	if spare != null:
		var hud: Hud = world.hud
		hud.show_toast("")
		_face(spare.global_position + Vector3(0, 0.1, 0))
		for i in 10:
			await get_tree().process_frame
		var again: bool = player.carry.try_pick()
		for i in 5:
			await get_tree().physics_frame
		_ok(not again, "E on it is refused")
		_ok(props.count_of("spade") > 0,
			"and it is left lying there rather than swallowed")
		_ok(hud.toast_text().findn("already") >= 0,
			"and the player is told why: \"%s\"" % hud.toast_text())
		for item in props.items.duplicate():
			if item == spare:
				props.remove(item)

	print("\n[tools] %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit()


func _hint_says(text: String) -> bool:
	var hud: Hud = world.hud
	if hud == null or hud._hints == null:
		return false
	for row: PackedStringArray in hud._hints._hints():
		for cell in row:
			if cell.findn(text) >= 0:
				return true
	return false


func _fill_blade(at: Vector3, count: int) -> void:
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 5150
	for i in count:
		var jitter:= Vector3(rng.randf_range(-0.04, 0.04),
			rng.randf_range(0.01, 0.05), rng.randf_range(-0.05, 0.05))
		live.spawn(at + jitter, StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, StrandFactory.random_tint(rng))


func _clear_hay() -> void:
	var live: LiveStrandManager = world.live
	if live == null:
		return
	for b in live._active.duplicate():
		live._despawn(b)


func _box_of(item: Carryable) -> AABB:
	for child in item.get_children():
		var cs:= child as CollisionShape3D
		if cs == null or cs.shape is not BoxShape3D:
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		return AABB(cs.position - size * 0.5, size)
	return AABB()


func _mesh_bounds(item: Node3D) -> AABB:
	var out:= AABB()
	var first:= true
	for node in item.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		if mi.mesh == null:
			continue
		var a:= mi.global_transform * mi.mesh.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _find_prop(id: String) -> Carryable:
	var props: PropManager = world.props
	for item in props.items:
		if is_instance_valid(item) and item.item_id == id:
			return item
	return null


func _face(at: Vector3) -> void:
	var to_it:= at - player.eye_position()
	player.rotation = Vector3(0, atan2(- to_it.x, - to_it.z), 0)
	player.head.rotation.x = atan2(to_it.y, Vector2(to_it.x, to_it.z).length())


func _held_strands() -> int:
	var live: LiveStrandManager = world.live
	if live == null:
		return 0
	var n:= 0
	for b in live._active:
		if live.is_held_by_a_tool(b):
			n += 1
	return n


func _loose_strands() -> int:
	var live: LiveStrandManager = world.live
	if live == null:
		return 0
	var n:= 0
	for b in live._active:
		if not live.is_held_by_a_tool(b):
			n += 1
	return n
