class_name DevCabinetProbe
extends Node


var world: Node3D
var builds: BuildManager
var player: Player

var _pass:= 0
var _fail:= 0


func shoot(out_dir: String) -> void:
	world.block_save = true
	GameState.reset(777, 0.0)


	var rng:= RandomNumberGenerator.new()
	rng.seed = 12
	const HELD:= [0, 3, 1, 0, 12, 2, 1, 0]
	for t in NeedleTypes.count():
		var held: int = HELD [t % HELD.size()]
		for i in held:
			GameState.deposit_needle(
				GameState.register_needle(Vector3.ZERO, rng, t), Vector3.ZERO)
		if t < 6 and held > 0:
			GameState.discover(t, Vector3.ZERO)
	var cab:= builds.add_cabinet(Vector3(3.0, 0.0, 3.0), 0.0)
	await get_tree().process_frame
	cab.open_doors()


	var carry:= 14
	var live: LiveStrandManager = world.get("live") as LiveStrandManager
	if player != null:
		player.global_position = cab.read_position() - Vector3(0, 1.35, 0)
		var to:= cab.slot_position(carry) - player.eye_position()
		player.rotation.y = atan2(- to.x, - to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		if live != null:
			var idx:= GameState.register_needle(Vector3.ZERO, null, carry)
			GameState.needle_taken [idx] = 1
			player.hand._grab(live.reveal_needle(idx, cab.slot_position(carry)))


	for i in 130:
		await get_tree().process_frame
	while cab.marker_pulse() < 0.92:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/cabinet_case.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
	get_tree().quit(0)


func shoot_card(out_dir: String) -> void:
	world.block_save = true
	GameState.reset(4646, 0.0)


	GameState.hay_dug = 1840.0
	GameState.money_earned = 27350.0
	var rng:= RandomNumberGenerator.new()
	rng.seed = 31
	for t in NeedleTypes.count():
		GameState.deposit_needle(
			GameState.register_needle(Vector3.ZERO, rng, t), Vector3.ZERO)
		GameState.discover(t, Vector3.ZERO)
	var cab:= builds.add_cabinet(Vector3(3.0, 0.0, 3.0), 0.0)
	await get_tree().process_frame
	if player != null:
		player.global_position = cab.read_position() - Vector3(0, 1.35, 0)
		var to:= cab.ending_button_at() - player.eye_position()
		player.rotation.y = atan2(- to.x, - to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


	cab.play_ending()
	var card: DemoEndDialog = world.demo_end_dialog
	for i in 1200:
		if card != null and card.is_open():
			break
		if cab.press_ending():
			for j in 20:
				await get_tree().process_frame
		else:
			await get_tree().process_frame


	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/demo_card.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
	get_tree().quit(0)


func run() -> void:
	builds = world.get("builds") as BuildManager
	if builds == null:
		push_error("[cabinet] no BuildManager on the world")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	await _check_model()
	await _check_reveal()
	await _check_catch_up()
	await _check_director()
	await _check_rules()
	await _check_hand_deposit()
	await _check_thrown()
	await _check_dipped()
	await _check_open_toast()
	await _check_withdraw()
	await _check_inspect_click()
	await _check_save()
	await _check_ending()
	await _check_ending_fires()
	await _check_demo_card()
	await _check_fill()
	await _check_forget()
	print("\n[cabinet] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _place(at:= Vector3(3.0, 0.0, 3.0)) -> NeedleCabinet:
	var cab:= builds.add_cabinet(at, 0.0)
	await get_tree().process_frame
	return cab


func _bank_and_discover(index: int, pos: Vector3) -> bool:
	GameState.deposit_needle(index, pos)
	return GameState.discover(GameState.type_of(index), pos)


func _count_plays(key: String, seconds: float) -> int:
	var au: Node = get_tree().root.get_node_or_null("/root/Audio")
	if au == null:
		return -1
	var stamps: Dictionary = au._last_play
	var last: int = stamps.get(key, -1)
	var n:= 0
	var t:= 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var now: int = stamps.get(key, -1)
		if now != last:
			last = now
			n += 1
	return n


func _check_fill() -> void:
	print("\n-- fill the cabinet --")
	GameState.reset(2468, 1000.0)
	var cab:= await _place()
	var dbg: DebugMenu = world.get("debug_menu") as DebugMenu
	if dbg == null:
		_ok(false, "the debug menu exists (Cfg.DEBUG)")
		return

	var n:= NeedleTypes.count()
	dbg.call("_on_fill_cabinet")
	await get_tree().process_frame
	var empty:= _empty_slots(cab)
	_ok(empty.size() == 1, "one compartment left empty of %d (%d)" % [n, empty.size()])
	var first:= -1 if empty.is_empty() else empty [0]
	_ok(first >= 0 and NeedleTypes.name_of(first) == DebugMenu.HOLE,
		"and the empty one is %s" % ("none at all" if first < 0
			else NeedleTypes.name_of(first)))


	dbg.call("_on_fill_cabinet")
	await get_tree().process_frame
	var again:= _empty_slots(cab)
	_ok(again == empty, "pressing it again leaves the same compartment empty")


	_ok(not cab.ending_armed(), "a case one short does not arm the ending")
	builds.clear()


func _empty_slots(cab: NeedleCabinet) -> PackedInt32Array:
	var out:= PackedInt32Array()
	for t in NeedleTypes.count():
		if not cab.has_specimen(t):
			out.append(t)
	return out


func _check_forget() -> void:
	print("\n-- forget every needle --")
	GameState.reset(31337, 1000.0)
	var cab:= await _place()
	var dbg: DebugMenu = world.get("debug_menu") as DebugMenu
	if dbg == null:
		_ok(false, "the debug menu exists (Cfg.DEBUG)")
		return


	var kept:= 0
	var spent_type:= 1
	for i in 3:
		GameState.deposit_needle(
			GameState.register_needle(Vector3.ZERO, null, spent_type), Vector3.ZERO)
	GameState.discover(spent_type, Vector3.ZERO)
	GameState.needle_stock [spent_type] = 1
	GameState.deposit_needle(
		GameState.register_needle(Vector3.ZERO, null, kept), Vector3.ZERO)
	GameState.discover(kept, Vector3.ZERO)
	GameState.withdraw_needle(kept, Vector3.ZERO)
	await get_tree().process_frame
	_ok(GameState.needles_by_type [spent_type] == 3
		and GameState.stock_of(spent_type) == 1,
		"staged: three found of a type, one still held")
	_ok(not GameState.needle_out.is_empty(), "...and one specimen out of a drawer")

	dbg.call("_on_forget_needles")
	await get_tree().process_frame

	_ok(GameState.needles_found == 0, "the total is back to zero, not %d"
		% GameState.needles_found)
	var ledger:= 0
	var stock:= 0
	var seen:= 0
	for t in NeedleTypes.count():
		ledger += GameState.needles_by_type [t]
		stock += GameState.stock_of(t)
		seen += 1 if GameState.is_discovered(t) else 0
	_ok(ledger == 0, "the lifetime ledger is empty, including what was spent (%d)"
		% ledger)
	_ok(stock == 0, "the drawers are empty (%d)" % stock)
	_ok(seen == 0, "the case has never seen a needle (%d)" % seen)
	_ok(GameState.needle_out.is_empty(),
		"a carried specimen is no longer on loan, so putting it back is a find")

	var lit:= 0
	for t in NeedleTypes.count():
		if cab.has_specimen(t):
			lit += 1
	_ok(lit == 0, "every compartment went dark (%d still showing)" % lit)
	builds.clear()


func _check_model() -> void:
	print("\n-- model --")
	GameState.reset(4242, 1000.0)
	var cab:= await _place()
	_ok(cab.get_node_or_null("Model") != null, "model instantiated")

	var missing: Array [String] = []
	var shown:= 0
	for t in NeedleTypes.count():
		var node:= cab.find_child(NeedleTypes.object_of(t), true, false)
		if node == null:
			missing.append(NeedleTypes.object_of(t))
		elif (node as MeshInstance3D).visible:
			shown += 1
	_ok(missing.is_empty(), "all 24 slots present%s"
		% ("" if missing.is_empty() else " (missing %s)" % ", ".join(missing)))


	_ok(shown == 0, "no specimens shown before anything is found (saw %d)" % shown)

	var doors:= cab.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ok(doors != null and doors.has_animation(NeedleCabinet.ANIM_DOORS),
		"the DoorsOpen clip imported")

	var bodies:= cab.find_children("*", "StaticBody3D", true, false)
	var layered:= bodies.size() > 0
	for b in bodies:
		if (b as StaticBody3D).collision_layer != Cfg.L_BUILD:
			layered = false
	_ok(layered, "carcass collider is on L_BUILD")
	builds.clear()


func _check_reveal() -> void:
	print("\n-- reveal --")
	GameState.reset(4243, 1000.0)
	var cab:= await _place()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 11
	var idx:= GameState.register_needle(Vector3.ZERO, rng)
	var t:= GameState.type_of(idx)

	_bank_and_discover(idx, Vector3(1, 1, 1))
	cab.reveal(t)
	await get_tree().process_frame
	var mesh:= cab.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D
	_ok(mesh != null and mesh.visible, "%s appeared on discovery" % NeedleTypes.name_of(t))


	var others:= 0
	for other in NeedleTypes.count():
		if other == t:
			continue
		var om:= cab.find_child(NeedleTypes.object_of(other), true, false) as MeshInstance3D
		if om != null and om.visible:
			others += 1
	_ok(others == 0, "no other specimen appeared (saw %d)" % others)

	var mat:= mesh.get_surface_override_material(0) as StandardMaterial3D
	_ok(mat != null and mat.emission_enabled,
		"the revealed specimen is glowing on its own material")


	var ap:= cab.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation("DoorsOpen"):
		_ok(false, "the case has its door animation")
	else:
		var length:= ap.get_animation("DoorsOpen").length

		var spins:= 0
		while ap.is_playing() and spins < 600:
			await get_tree().process_frame
			spins += 1
		_ok(cab.is_open() and not ap.is_playing(), "the doors finished opening")

		var second:= (t + 1) % NeedleTypes.count()
		var idx2:= GameState.register_needle(Vector3.ZERO, null, second)
		_bank_and_discover(idx2, Vector3(1, 1, 1))
		cab.reveal(second)
		await get_tree().process_frame
		_ok(not ap.is_playing() and is_equal_approx(ap.current_animation_position, length),
			"a second find left the open doors alone (playhead at %.2f of %.2f)"
			% [ap.current_animation_position, length])
		_ok(cab.is_open(), "...and the case is still open")
	builds.clear()


func _check_catch_up() -> void:
	print("\n-- catch-up --")
	GameState.reset(4244, 1000.0)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 5


	var want: Array [int] = []
	for i in 40:
		var idx:= GameState.register_needle(Vector3.ZERO, rng)
		_bank_and_discover(idx, Vector3.ZERO)
		var t:= GameState.type_of(idx)
		if not want.has(t):
			want.append(t)
	var cab:= await _place()
	var shown:= 0
	for t in want:
		var m:= cab.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D
		if m != null and m.visible:
			shown += 1
	_ok(shown == want.size(),
		"a cabinet built after %d discoveries opened showing all of them (%d)"
			% [want.size(), shown])
	builds.clear()


func _check_director() -> void:
	print("\n-- director --")
	GameState.reset(4246, 1000.0)
	var dir:= DiscoveryDirector.new()
	dir.builds = builds
	add_child(dir)
	await get_tree().process_frame

	var rng:= RandomNumberGenerator.new()
	rng.seed = 21


	var lone:= GameState.register_needle(Vector3.ZERO, rng)
	var lone_t:= GameState.type_of(lone)
	_bank_and_discover(lone, Vector3(2, 0.5, 2))
	await get_tree().process_frame
	_ok(GameState.is_discovered(lone_t),
		"a discovery with no cabinet standing is still recorded")

	var cab:= await _place()
	var idx:= GameState.register_needle(Vector3.ZERO, rng)
	var t:= GameState.type_of(idx)
	while t == lone_t:
		idx = GameState.register_needle(Vector3.ZERO, rng)
		t = GameState.type_of(idx)
	_bank_and_discover(idx, Vector3(6, 0.5, -4))
	await get_tree().process_frame
	var flights:= dir.find_children("*", "DiscoveryFlight", true, false)
	_ok(flights.size() == 1, "a mote launched toward the cabinet (%d)" % flights.size())
	var mesh:= cab.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D

	_ok(mesh != null and not mesh.visible, "the slot is still empty mid-flight")


	var guard:= 0
	while dir.find_children("*", "DiscoveryFlight", true, false).size() > 0 and guard < 600:
		guard += 1
		await get_tree().process_frame
	_ok(mesh.visible, "the specimen appeared when the mote landed")
	dir.queue_free()
	builds.clear()


func _check_rules() -> void:
	print("\n-- rules --")
	GameState.reset(4247, 1000.0)
	var cab:= await _place()


	var shaded:= 0
	var blank: Array [String] = []
	for mesh in cab.find_children("*", "MeshInstance3D", true, false):
		var mi:= mesh as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m:= mi.get_surface_override_material(i) as ShaderMaterial
			if m == null or m.shader == null:
				continue
			if m.shader.resource_path != NeedleCabinet.SHADER:
				continue
			shaded += 1
			if m.get_shader_parameter("tex_albedo") == null:
				blank.append(m.resource_name)
	_ok(shaded > 0 and blank.is_empty(),
		"%d photographed surfaces all have an albedo bound%s"
			% [shaded, "" if blank.is_empty() else " (blank: %s)" % ", ".join(blank)])

	_ok(builds.has_cabinet(), "the manager reports a cabinet")
	_ok(builds.owner_of(cab.find_child("*", true, false)) == cab
		or builds.owner_of(cab) == cab, "owner_of resolves the cabinet")


	_ok(cab.in_reach(cab.read_position()), "in reach at the reading spot")
	_ok(not cab.in_reach(cab.global_position + Vector3(9, 0, 9)),
		"not in reach from across the shed")
	_ok(builds.cabinet_in_reach(cab.read_position()) == cab,
		"cabinet_in_reach finds it")

	var before:= GameState.money
	var refund:= builds.demolish(cab)
	_ok(refund == Cfg.CABINET_COST,
		"dismantling refunds the full price (%.0f)" % refund)
	_ok(not builds.has_cabinet(), "the cabinet is gone from the ledger")
	GameState.add_money(refund)
	_ok(GameState.money >= before, "money went back up")
	builds.clear()


func _hold_aim(p: Player, at: Vector3) -> void:
	var start:= Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 150:
		await _aim_at(p, at)


func _hint_says(text: String) -> bool:
	var hud: Hud = world.get("hud") as Hud
	if hud == null or hud._hints == null:
		return false
	for row: PackedStringArray in hud._hints._hints():
		for cell in row:
			if cell.findn(text) >= 0:
				return true
	return false


func _aim_at(p: Player, target: Vector3) -> void:
	var to:= target - p.eye_position()
	p.rotation.y = atan2(- to.x, - to.z)
	p.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await get_tree().process_frame


func _look_and_settle(p: Player, at: Vector3, frames:= 24) -> void:
	for i in frames:
		await _aim_at(p, at)


func _check_open_toast() -> void:
	print("\n-- the open prompt --")
	GameState.reset(4410, 0.0)
	var p: Player = world.get("player") as Player
	var hud: Hud = world.get("hud") as Hud
	if p == null or hud == null:
		_ok(false, "world has a player and a HUD")
		return
	var cab:= await _place(Vector3(13.0, 0.0, 2.0))
	p.global_position = cab.global_position + Vector3(0.0, 0.0, 1.6)
	await get_tree().process_frame

	hud.show_toast("", 0.0)
	await _look_and_settle(p, cab.slot_position(7))
	print("     eye %.2f m from the reading spot, toast '%s'"
		% [p.eye_position().distance_to(cab.read_position()), hud.toast_text()])
	_ok(hud.toast_text().findn("OPEN THE CABINET") >= 0,
		"a shut case under the crosshair asks to be opened")
	_ok(hud._toast.modulate.a > 0.9, "...and the line is solid, not a leftover fade")

	hud.show_toast("", 0.0)
	await _look_and_settle(p, cab.global_position + Vector3(6.0, 0.5, 8.0))
	_ok(hud.toast_text() == "", "looking away takes it back")

	cab.interact()
	await get_tree().process_frame
	hud.show_toast("", 0.0)
	await _look_and_settle(p, cab.slot_position(7))
	_ok(cab.is_open() and hud.toast_text() == "",
		"an open case does not ask to be opened")
	cab.interact()
	builds.clear()


func _check_hand_deposit() -> void:
	print("\n-- putting one in by hand --")
	GameState.reset(9182, 0.0)
	var p: Player = world.get("player") as Player
	var live: LiveStrandManager = world.get("live") as LiveStrandManager
	if p == null or live == null:
		_ok(false, "world has a player and a strand manager")
		return
	var cab:= await _place(Vector3(13.0, 0.0, 2.0))


	var at:= cab.global_position + Vector3(0.6, 0.9, 1.4)
	var index:= GameState.register_needle(at, null, 7)
	GameState.needle_taken [index] = 1
	var needle:= live.reveal_needle(index, at)
	p.global_position = cab.global_position + Vector3(0.0, 0.0, 1.6)


	for i in 60:
		await get_tree().physics_frame


	await _hold_aim(p, p.eye_position() + Vector3(0.0, 5.0, 0.0))
	_ok(not _hint_says("Pluck strand") and not _hint_says("Pick the needle up"),
		"an empty hand pointed at nothing offers no pluck")
	await _hold_aim(p, needle.global_position)
	_ok(_hint_says("Pick the needle up"),
		"...and the needle under the crosshair is named on the bar")
	await _aim_at(p, needle.global_position)
	p.hand.primary()
	_ok(p.hand.is_holding_needle(), "a loose needle can be picked up by hand")
	_ok(p.hand.held_needle_index() == index, "...and it is the one that was aimed at")


	await _aim_at(p, cab.slot_position(7))
	_ok(not cab.is_open(), "the case starts shut")
	_ok(p.hand.deposit_target() == null, "a shut case is not a deposit target")

	cab.interact()
	await get_tree().process_frame
	_ok(cab.is_open(), "E opens it")
	_ok(p.hand.deposit_target() == cab, "an open case under the crosshair is")


	await _aim_at(p, cab.global_position + Vector3(6.0, 0.5, 8.0))
	_ok(p.hand.deposit_target() == null, "...and only while it is under the crosshair")

	await _aim_at(p, cab.slot_position(7))


	await get_tree().process_frame
	var marker:= cab.get_node_or_null("SlotMarker") as MeshInstance3D
	_ok(marker != null and marker.visible, "the compartment it goes in is lit up")
	if marker != null:


		var off:= marker.global_position.distance_to(cab.slot_position(7))
		print("     marker sits %.3f m from the slot" % off)
		_ok(off < 0.15, "...the RIGHT compartment (%.3f m off)" % off)

	var stock_before:= GameState.stock_of(7)
	p.hand.primary()
	await get_tree().process_frame
	_ok(not p.hand.is_holding(), "the left button empties the hand")
	_ok(not is_instance_valid(needle) or not needle.is_inside_tree(),
		"...the needle is gone off the floor, not dropped on it")
	_ok(GameState.stock_of(7) == stock_before + 1,
		"...and into the drawer stock (%d -> %d)"
		% [stock_before, GameState.stock_of(7)])
	_ok(GameState.is_discovered(7), "...marked discovered")
	_ok(p.hand.deposit_target() == null, "an empty hand is not offered the case")


	builds.clear()
	await get_tree().process_frame


func _check_thrown() -> void:
	print("\n-- throwing one at the case --")
	GameState.reset(9183, 0.0)
	var live: LiveStrandManager = world.get("live") as LiveStrandManager
	if live == null:
		_ok(false, "world has a strand manager")
		return
	var cab:= await _place(Vector3(13.0, 0.0, 2.0))
	_ok(not cab.is_open(), "the case is shut")

	var target:= cab.global_position + Vector3(0.0, 1.0, 0.0)
	var from:= cab.global_position + Vector3(0.0, 1.2, 1.8)
	var index:= GameState.register_needle(from, null, 11)
	GameState.needle_taken [index] = 1
	var thrown:= live.reveal_needle(index, from)
	live.set_protected(thrown, true)
	Shovel.mark_let_go(thrown)
	thrown.linear_velocity = (target - from).normalized() * 6.0


	var held_at:= cab.global_position + Vector3(0.45, 1.4, 0.0)
	var held_index:= GameState.register_needle(held_at, null, 12)
	GameState.needle_taken [held_index] = 1
	var held:= live.reveal_needle(held_index, held_at)
	live.set_protected(held, true)
	held.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	held.freeze = true

	var floor_at:= cab.global_position + Vector3(0.0, 0.05, 1.2)
	var floor_index:= GameState.register_needle(floor_at, null, 13)
	GameState.needle_taken [floor_index] = 1
	var lying:= live.reveal_needle(floor_index, floor_at)

	var stock_before:= GameState.stock_of(11)
	var frames:= 0
	while frames < 90 and is_instance_valid(thrown) and thrown.is_inside_tree():
		await get_tree().physics_frame
		frames += 1
	print("     caught after %d physics frames" % frames)
	_ok(not is_instance_valid(thrown) or not live.needles.has(thrown),
		"a needle thrown at a shut case goes in")
	_ok(GameState.stock_of(11) == stock_before + 1,
		"...into the drawer stock (%d -> %d)" % [stock_before, GameState.stock_of(11)])
	_ok(GameState.is_discovered(11), "...and is discovered")

	for i in 30:
		await get_tree().physics_frame
	_ok(is_instance_valid(held) and live.needles.has(held),
		"a needle something still holds against the case stays held")
	_ok(is_instance_valid(lying) and live.needles.has(lying),
		"a needle on the floor a stride away stays on the floor")
	_ok(not GameState.is_discovered(12) and not GameState.is_discovered(13),
		"...and neither of them is discovered")

	for b in [held, lying]:
		if is_instance_valid(b):
			live.consume_needle(b)
	builds.clear()
	await get_tree().process_frame


func _check_dipped() -> void:
	print("\n-- dipping a loaded blade into the case --")
	GameState.reset(6021, 0.0)
	var live: LiveStrandManager = world.get("live") as LiveStrandManager
	if live == null:
		_ok(false, "world has a strand manager")
		return
	var cab:= await _place(Vector3(13.0, 0.0, 2.0))
	_ok(not cab.is_open(), "the case is shut")

	var blade:= Shovel.new()
	blade.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(blade)
	_ok(blade.is_in_group(Shovel.GROUP), "a blade joins the blades group")


	var box: AABB = cab._catch_box
	var face:= cab.to_global(Vector3(box.get_center().x, box.get_center().y,
		box.end.z + 0.08))
	var far:= face + cab.global_basis.z * 1.2

	var on_blade:= _held_needle(live, face, 14)
	blade._riding [on_blade.get_instance_id()] = on_blade
	var not_blade:= _held_needle(live, face + Vector3(0.0, 0.3, 0.0), 15)
	var blade_far:= _held_needle(live, far, 16)
	blade._riding [blade_far.get_instance_id()] = blade_far

	var stock_before:= GameState.stock_of(14)
	for i in 10:
		await get_tree().physics_frame
	_ok(not is_instance_valid(on_blade) or not live.needles.has(on_blade),
		"a needle on a blade dipped into a shut case goes in")
	_ok(GameState.stock_of(14) == stock_before + 1,
		"...into the drawer stock (%d -> %d)" % [stock_before, GameState.stock_of(14)])
	_ok(GameState.is_discovered(14), "...and is discovered")
	_ok(is_instance_valid(not_blade) and live.needles.has(not_blade),
		"a needle held at the case by something that is not a blade stays held")
	_ok(is_instance_valid(blade_far) and live.needles.has(blade_far),
		"a needle on a blade a stride away stays on the blade")
	_ok(not GameState.is_discovered(15) and not GameState.is_discovered(16),
		"...and neither of them is discovered")

	for b in [not_blade, blade_far]:
		if is_instance_valid(b):
			live.consume_needle(b)
	blade._riding.clear()
	blade.queue_free()
	builds.clear()
	await get_tree().process_frame


func _held_needle(live: LiveStrandManager, at: Vector3, type: int) -> RigidBody3D:
	var index:= GameState.register_needle(at, null, type)
	GameState.needle_taken [index] = 1
	var b:= live.reveal_needle(index, at)
	live.set_protected(b, true)
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	return b


func _check_withdraw() -> void:
	print("\n-- taking one back out --")
	GameState.reset(5150, 0.0)
	var p: Player = world.get("player") as Player
	if p == null:
		_ok(false, "world has a player")
		return
	var cab:= await _place()


	p.global_position = cab.global_position + Vector3(0.0, 0.0, 1.6)
	await get_tree().physics_frame


	var t:= 11
	for i in 3:
		var idx:= GameState.register_needle(Vector3.ZERO, null, t)
		GameState.deposit_needle(idx, Vector3.ZERO)
	_ok(GameState.stock_of(t) == 3 and not GameState.is_discovered(t),
		"three in the drawer and none of them discovered")

	await _aim_at(p, cab.slot_position(t))
	_ok(p.hand.case_target().is_empty(), "a shut case offers nothing")
	cab.interact()
	await get_tree().process_frame
	var target: Dictionary = p.hand.case_target()
	_ok(target.get("cabinet") == cab and int(target.get("type", -1)) == t,
		"an open case offers the compartment under the crosshair")


	_ok(String(target.get("action", "")) == "take",
		"...and offers to take one, because the mount is empty")


	await get_tree().process_frame
	var ghost:= cab.get_node_or_null("SlotMarker") as MeshInstance3D
	_ok(ghost != null and ghost.visible, "the compartment shows a ghost specimen")
	if ghost != null:
		var real:= cab.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D
		_ok(real != null and ghost.mesh == real.mesh,
			"...and it is that needle's own shape, not a box")
		_ok(ghost.global_position.distance_to(cab.slot_position(t)) < 0.02,
			"...standing exactly where the specimen would (%.3f m off)"
			% ghost.global_position.distance_to(cab.slot_position(t)))


	var drawer:= cab.find_child("Drawer_1", true, false) as Node3D
	var shut_at:= drawer.position if drawer != null else Vector3.ZERO

	p.hand.primary()
	await get_tree().process_frame
	_ok(p.hand.is_holding_needle(), "the left button puts one in the hand")
	_ok(GameState.type_of(p.hand.held_needle_index()) == t,
		"...and it is the type that was aimed at")
	_ok(GameState.stock_of(t) == 2, "...out of the drawer (3 -> %d)"
		% GameState.stock_of(t))
	_ok(not GameState.is_discovered(t),
		"...and taking one out did not discover it")
	_ok(drawer != null, "the model has the drawer that type lives in")
	if drawer != null:


		for i in 20:
			await get_tree().process_frame
		_ok(drawer.position.distance_to(shut_at) > 0.05,
			"the drawer it came from slid out (%.3f m)"
			% drawer.position.distance_to(shut_at))


	await _aim_at(p, cab.slot_position(t))
	p.hand.primary()
	await get_tree().process_frame
	_ok(GameState.stock_of(t) == 3, "putting it back restored the drawer (%d)"
		% GameState.stock_of(t))
	_ok(GameState.is_discovered(t), "...and THAT is what discovered it")
	_ok(GameState.found_of(t) == 3,
		"the round trip did not inflate the ledger (%d, expected 3)"
		% GameState.found_of(t))


	var tally:= cab.find_child("Count_%02d" % t, true, false) as Label3D
	_ok(tally != null and tally.visible and tally.text == "x3",
		"the compartment says how many are in the drawer (%s)"
		% ("missing" if tally == null else tally.text))


	var mesh:= cab.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D


	var landing:= 0
	while (mesh == null or not mesh.visible) and landing < 200:
		await get_tree().process_frame
		landing += 1
	_ok(mesh != null and mesh.visible, "the specimen is on display")
	await _aim_at(p, cab.slot_position(t))
	var filled: Dictionary = p.hand.case_target()
	_ok(String(filled.get("action", "")) == "inspect",
		"a filled compartment offers a look instead (%s)"
		% String(filled.get("action", "nothing")))


	for i in 3:
		GameState.withdraw_needle(t, Vector3.ZERO)
	await get_tree().process_frame
	_ok(mesh != null and not mesh.visible,
		"taking the last one out emptied the compartment")
	_ok(p.hand.case_target().is_empty(), "an empty drawer offers nothing")


	GameState.deposit_needle(GameState.register_needle(Vector3.ZERO, null, t),
		Vector3.ZERO)
	await get_tree().process_frame
	_ok(mesh != null and mesh.visible, "putting one back put it on display again")
	_ok(GameState.is_discovered(t), "...and it was never un-discovered")

	while GameState.stock_of(t) > 0:
		GameState.withdraw_needle(t, Vector3.ZERO)
	await get_tree().process_frame
	var empty_tally:= cab.find_child("Count_%02d" % t, true, false) as Label3D
	_ok(empty_tally != null and not empty_tally.visible,
		"an empty drawer shows no tally")

	builds.clear()
	await get_tree().process_frame


func _check_inspect_click() -> void:
	print("\n-- looking at one --")
	GameState.reset(6161, 0.0)
	var p: Player = world.get("player") as Player
	var inspector: NeedleInspector = world.get("needle_inspector") as NeedleInspector
	if p == null or inspector == null:
		_ok(false, "world has a player and an inspector")
		return
	var cab:= await _place()
	p.global_position = cab.global_position + Vector3(0.0, 0.0, 1.6)
	await get_tree().physics_frame


	var t:= 5
	var idx:= GameState.register_needle(Vector3.ZERO, null, t)
	GameState.deposit_needle(idx, Vector3.ZERO)
	GameState.discover(t, cab.slot_position(t))
	cab.open_doors()
	await get_tree().process_frame
	_ok(cab.has_specimen(t), "a specimen is standing in the compartment")

	await _aim_at(p, cab.slot_position(t))
	p.hand.primary()
	await get_tree().process_frame
	_ok(inspector.is_open(), "the left button opened the inspector on it")
	_ok(not p.hand.is_holding(), "...without taking it out of the case")


	var take:= InputEventAction.new()
	take.action = "inspect_needle"
	take.pressed = true
	get_viewport().push_input(take)
	await get_tree().process_frame
	_ok(p.hand.is_holding_needle(), "F took it out of the case")
	_ok(GameState.type_of(p.hand.held_needle_index()) == t,
		"...and it is the one that was on display")
	_ok(not inspector.is_open(), "...and the panel shut behind it")
	_ok(not cab.has_specimen(t), "...leaving the compartment empty")

	p.hand.drop_held()
	builds.clear()
	await get_tree().process_frame


func _check_save() -> void:
	print("\n-- save --")
	GameState.reset(4245, 1000.0)
	var cab:= await _place()
	cab.position = Vector3(-2.5, 0.0, 4.25)
	cab.rotation.y = 1.1
	var rng:= RandomNumberGenerator.new()
	rng.seed = 3
	var idx:= GameState.register_needle(Vector3.ZERO, rng)
	var t:= GameState.type_of(idx)
	_bank_and_discover(idx, Vector3.ZERO)

	var data:= builds.to_array()
	var saved:= GameState.to_dict()
	var entries:= data.filter(func(e: Variant) -> bool:
		return typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "needle_cabinet")
	_ok(entries.size() == 1, "one cabinet serialised (got %d)" % entries.size())

	builds.clear()
	GameState.reset(1, 1000.0)
	GameState.from_dict(saved)
	builds.from_array(data)
	await get_tree().process_frame
	_ok(builds.cabinets.size() == 1, "cabinet restored")
	if builds.cabinets.size() == 1:
		var back:= builds.cabinets [0]
		_ok(back.position.distance_to(Vector3(-2.5, 0.0, 4.25)) < 0.001
			and absf(back.rotation.y - 1.1) < 0.001, "position and yaw survived")
		var m:= back.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D
		_ok(m != null and m.visible, "the specimen was still in the case after load")
	_ok(GameState.is_discovered(t), "the discovery flag survived the save")
	builds.clear()


func _check_ending() -> void:
	print("\n[cabinet] the ending")
	GameState.reset(4242, 0.0)
	var cab:= await _place()
	var panel:= cab.find_child("Cab_EndPanel", true, false) as Node3D
	_ok(panel != null, "Cab_EndPanel survived the export")
	if panel == null:
		builds.clear()
		return
	_ok(panel.find_child("End_Button", true, false) != null,
		"End_Button is parented to the panel, so it travels with it")
	_ok(not panel.visible, "the panel starts hidden")
	var home:= panel.position


	var rng:= RandomNumberGenerator.new()
	rng.seed = 19
	var seeded: Array [int] = []
	var step:= 0
	while step < NeedleTypes.count():
		seeded.append(step)
		_bank_and_discover(
			GameState.register_needle(Vector3.ZERO, rng, step), Vector3(3.0, 1.2, 2.2))
		step += NeedleTypes.cols()
	await get_tree().process_frame
	var mounted:= 0
	for t in NeedleTypes.count():
		if cab.has_specimen(t):
			mounted += 1
	_ok(mounted >= 3, "%d specimens on display going in" % mounted)
	_ok(not cab.ending_armed(), "the button is dead before the panel exists")

	cab.play_ending()


	await _count_plays("needle_collect", 5.5)
	var chimes: int = cab.end_chimes
	_ok(chimes == seeded.size(),
		"the case emptied to %d chimes, one a row (%d rows had a specimen)"
			% [chimes, seeded.size()])

	_ok(panel.visible, "the panel is showing once it has run")
	_ok(panel.position.distance_to(home) < 0.001,
		"it landed on the rest position the model gave it")
	var still_up:= 0
	for t in NeedleTypes.count():
		var slot:= cab.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D
		if slot != null and slot.visible:
			still_up += 1
	_ok(still_up == 0, "every specimen is out of the case (%d left)" % still_up)


	var found:= 0
	var lit:= 0
	for i in NeedleCabinet.LCD_SEGMENTS:
		var seg:= cab.find_child("Lcd_S%d" % i, true, false) as MeshInstance3D
		if seg == null:
			continue
		found += 1
		var m:= seg.get_surface_override_material(0) as ShaderMaterial
		if m != null and float(m.get_shader_parameter("emit_strength")) > 0.0:
			lit += 1
	_ok(found == NeedleCabinet.LCD_SEGMENTS,
		"all seven segments survived the export (%d)" % found)
	_ok(lit == 5, "and the readout is showing a 3 (%d lit)" % lit)

	var reach:= cab.ending_button_at().y - cab.global_position.y
	_ok(reach > 1.2 and reach < 1.6,
		"the button sits at %.2f m, inside a standing player's view" % reach)

	var fired:= [0]
	cab.ending_pressed.connect(func() -> void: fired [0] += 1)
	_ok(cab.ending_armed(), "the button is live once the panel has landed")


	var btn:= cab.find_child("End_Button", true, false) as Node3D
	var out_at:= btn.position if btn != null else Vector3.ZERO


	_ok(cab.press_ending(), "press one")
	_ok(cab.press_ending(), "press two")
	_ok(cab.ending_armed(), "still live with one press left")
	_ok(cab.press_ending(), "press three")
	_ok(fired [0] == 3, "three presses reported (got %d)" % fired [0])
	_ok(not cab.is_open(), "the third press shut the case")
	_ok(not cab.ending_armed(), "and the button went dead behind the doors")
	_ok(not cab.press_ending(), "a fourth press does nothing")


	cab.open_doors()
	await get_tree().create_timer(1.8).timeout
	_ok(cab.is_open(), "the case opens again")
	_ok(cab.ending_armed(), "the button is live again")
	_ok(cab.press_ending() and cab.press_ending() and cab.press_ending(),
		"and it has a full three presses in it")
	_ok(fired [0] == 6, "six presses over two rounds (got %d)" % fired [0])


	await get_tree().create_timer(1.2).timeout
	_ok(btn != null and not cab.is_open(), "the case is shut after three more")
	if btn != null:
		var travel:= btn.position.distance_to(out_at)
		_ok(travel > NeedleCabinet.END_RETRACT * 0.9,
			"the button stayed in, %.0f mm behind where it stands out"
			% (travel * 1000.0))
	builds.clear()


func shoot_ending(out_dir: String) -> void:
	world.block_save = true
	GameState.reset(777, 0.0)


	for t in NeedleTypes.count():
		GameState.discovered [t] = 1
		GameState.needle_stock [t] = maxi(GameState.stock_of(t), 1)
		GameState.needle_stock_changed.emit(t, GameState.needle_stock [t])
	var cab:= builds.add_cabinet(Vector3(3.0, 0.0, 3.0), 0.0)
	await get_tree().process_frame
	if player != null:


		var stand:= cab.read_position() - Vector3(0, 1.35, 0)
		var back:= (stand - cab.global_position).normalized()
		player.global_position = cab.global_position + back * 2.9
		var to:= cab.global_position + Vector3(0, 1.5, 0) - player.eye_position()
		player.rotation.y = atan2(- to.x, - to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	cab.open_doors()
	for i in 110:
		await get_tree().process_frame
	await _grab(out_dir, "end_0_full")

	cab.play_ending()


	const STAGES:= [
		[0.55, "end_1_wipe"],
		[1.4, "end_2_empty"],
		[2.15, "end_3_falling"],
		[3.3, "end_4_landed"],
	]
	var elapsed:= 0.0
	for stage: Array in STAGES:
		await get_tree().create_timer(float(stage [0]) - elapsed).timeout
		elapsed = float(stage [0])
		await _grab(out_dir, String(stage [1]))


	for i in 3:
		cab.press_ending()
		for f in 14:
			await get_tree().process_frame
	for i in 90:
		await get_tree().process_frame
	await _grab(out_dir, "end_5_slammed")


	cab.open_doors()
	await get_tree().create_timer(1.8).timeout
	if player != null:
		player.global_position = cab.read_position() - Vector3(0, 1.35, 0)
		var at:= cab.ending_button_at() - Vector3(0, 0.1, 0)
		var look:= at - player.eye_position()
		player.rotation.y = atan2(- look.x, - look.z)
		player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	await get_tree().create_timer(0.4).timeout
	await _grab(out_dir, "end_6_readout")
	print("[cabinet] ending shot into %s" % out_dir)
	get_tree().quit(0)


func _grab(out_dir: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path:= "%s/%s.png" % [out_dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


func _check_ending_fires() -> void:
	print("\n[cabinet] the last needle")
	GameState.reset(909, 0.0)


	var dir:= DiscoveryDirector.new()
	dir.builds = builds
	add_child(dir)
	await get_tree().process_frame
	var cab:= await _place()

	var rng:= RandomNumberGenerator.new()
	rng.seed = 5
	var last:= NeedleTypes.count() - 1


	for t in last:
		GameState.discovered [t] = 1
		GameState.needle_stock [t] = maxi(GameState.stock_of(t), 1)
	_ok(not GameState.collection_complete(), "23 of 24 is not a finished set")
	_ok(not cab.ending_covered(), "and nothing has started")

	cab.accept(GameState.register_needle(Vector3.ZERO, rng, last))
	_ok(GameState.collection_complete(), "the last needle completed the set")
	_ok(not cab.ending_covered(),
		"nothing starts on the frame the needle is banked")


	await get_tree().create_timer(7.0).timeout
	_ok(cab.ending_covered(), "and it starts on its own after the last specimen")
	dir.queue_free()
	builds.clear()


func _check_demo_card() -> void:
	print("\n[cabinet] the demo card")
	var card:= world.get("demo_end_dialog") as DemoEndDialog
	_ok(card != null, "the world built a demo card")
	if card == null:
		return
	card.set_open(false)

	GameState.reset(3131, 0.0)
	var cab:= await _place()
	_ok(cab.ending_pressed.is_connected(card.celebrate),
		"a cabinet joining the yard gets its button hooked to the card")


	cab.play_ending()
	await get_tree().create_timer(5.5).timeout
	_ok(cab.ending_armed(), "the button is live")
	_ok(cab.press_ending(), "pressed with nothing in the case")
	_ok(not card.is_open(), "and no card came up for an unfinished collection")


	for t in NeedleTypes.count():
		GameState.discovered [t] = 1
	_ok(GameState.collection_complete(), "the set is finished")
	_ok(cab.press_ending(), "pressed again")
	_ok(card.is_open(), "and the card is up")
	_ok(card.was_seen(), "and the run is marked as congratulated")


	card.set_open(false)
	cab.open_doors()
	await get_tree().create_timer(2.0).timeout
	if cab.ending_armed():
		_ok(cab.press_ending(), "pressed a fourth time, after the doors reopened")
		_ok(not card.is_open(), "and the card stays down: once a run")
	builds.clear()
