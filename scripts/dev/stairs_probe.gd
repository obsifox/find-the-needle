class_name DevStairsProbe
extends Node


var world: Node3D
var player: Player


var _lowered: Array = []

const SETTLE_FRAMES:= 40


const TRANSIT_FRAMES:= 420


const BACKLOG_WADS:= 30
const BACKLOG_EVERY:= 24
const BACKLOG_STRANDS:= 197


const BACKLOG_DRAIN_FROM:= 300
const BACKLOG_FRAMES:= 4200


const BACKLOG_DRAIN_S:= 1.3

const STALL_TUFT:= 40

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(20000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	var at:= Vector3(13.0, 0.0, -6.0)
	var tower: HayStairs = world.builds.add_hay_stairs(at, 0.0)
	tower.lowered_record.connect(func(seq: int) -> void: _lowered.append(seq))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	await _check_model(tower)
	await _check_geometry(tower)
	await _check_snapping(tower)
	await _check_buying()
	await _check_catch(tower)
	await _check_front(tower)
	await _check_jam(tower)
	await _check_backlog(tower)
	await _check_restored_heap()
	await _check_stall_lapses(tower)
	await _check_ghost(tower)


	await _check_motor(tower)

	await _check_dismantle(tower)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _check_model(tower: HayStairs) -> void:
	print("\n=== model ===")
	_ok("model instantiated", tower.get_node_or_null("Model") != null)


	for marker in ["Marker_Mouth", "Marker_Step_0", "Marker_Step_1",
			"Marker_Step_2", "Marker_BeltDrop", "Marker_BeltOut"]:
		_ok("marker %s" % marker, tower._find(marker) != null)
	_ok("material table loads", not HayStairs.spec_table().is_empty())


	var solid:= 0
	for n in tower.find_children("*", "StaticBody3D", true, false):
		if (n as StaticBody3D).collision_layer == Cfg.L_BUILD:
			solid += 1
	_ok("model colliders on L_BUILD (%d found)" % solid, solid >= 8)


	_ok("the modelled belt is not in the game build",
		tower._find("Belt-noimp") == null and tower._find("Belt") == null)
	await get_tree().process_frame


func _check_geometry(tower: HayStairs) -> void:
	print("\n=== geometry ===")
	var deck:= tower.outfeed_port()
	_ok("outfeed on the deck plane (%.3f vs %.3f)" % [deck.y, Cfg.HAY_STAIRS_DECK],
		absf(deck.y - Cfg.HAY_STAIRS_DECK) < 0.02)


	_ok("discharges toward +Z as placed",
		(deck - tower.global_position).dot(Vector3.BACK) > 0.9)
	_ok("the mouth is above the outfeed (%.2f m of drop)"
		% (tower.mouth_position().y - deck.y),
		tower.mouth_position().y - deck.y > 2.0)


	var descends:= true
	for i in range(1, tower._line.size()):
		if tower._line [i].y >= tower._line [i - 1].y:
			descends = false


	_ok("the rail line falls at every step (%d nodes)" % tower._line.size(),
		descends and tower._line.size() == HayStairs.STEPS * 2 + 2)


	var span: float = tower._cum [tower._cum.size() - 1]
	var straight:= tower._line [0].distance_to(tower._line [tower._line.size() - 1])
	_ok("the descent is a zig-zag, not a chute (%.2f m of rail over %.2f m)"
		% [span, straight], span > straight + 0.05)


	var widest:= 0.0
	for i in range(1, tower._line.size()):
		var leg:= tower._line [i] - tower._line [i - 1]
		widest = maxf(widest, Vector2(leg.x, leg.z).length())
	_ok("a load crosses the tower on the way down (widest leg %.2f m)" % widest,
		widest > 0.45)
	_ok("it lays a deck of its own", tower.deck() != null)
	await get_tree().process_frame


func _check_snapping(tower: HayStairs) -> void:
	print("\n=== snapping ===")

	var port:= tower.outfeed_port()
	var near:= port + Vector3(0.35, 0.0, 0.4)
	var snapped: Vector3 = world.builds.snap_endpoint(near)
	_ok("a belt end near the outfeed snaps onto it (off by %.3f m)"
		% snapped.distance_to(port), snapped.is_equal_approx(port))
	var far:= port + Vector3(5.0, 0.0, 0.0)
	_ok("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_ok("a second tower on the same spot is refused",
		world.builds.stairs_overlap(tower.global_position))


	_ok("...and one a clear diameter away is not",
		not world.builds.stairs_overlap(tower.global_position
			+ Vector3(Cfg.HAY_STAIRS_HALF_WIDTH * 2.0 + 0.2, 0.0, 0.0)))
	await get_tree().process_frame


func _check_buying() -> void:
	print("\n=== buying one ===")
	Tech.grant("haystairs")
	_ok("the tree sells it", BuildCatalog.is_unlocked("haystairs"))
	_ok("...and the panel has an icon for it",
		CatalogPanel._icon_for("haystairs") != null)

	player.equip_build("haystairs")
	_ok("equipping puts the tool in stairs mode",
		player.build_id == "haystairs"
			and player.build._mode == BuildTool.Mode.HAY_STAIRS)


	var spot:= Vector3(13.0, 0.0, 4.0)
	var eye:= spot + Vector3(0.0, 1.7, 3.6)
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	var flat:= Vector3(spot.x - eye.x, 0.0, spot.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(spot.y - eye.y, maxf(flat.length(), 0.001))
	player.velocity = Vector3.ZERO
	for i in 12:
		await get_tree().process_frame

	var st: Dictionary = player.build.status()
	_ok("the readout is the stairs' own (%s)" % st.get("kind", "?"),
		st.get("kind", "") == "haystairs")
	_ok("...and quotes the right price ($%.0f)" % float(st.get("cost", 0.0)),
		is_equal_approx(float(st.get("cost", 0.0)), Cfg.HAY_STAIRS_COST))
	_ok("clear floor is accepted (%s)" % st.get("reason", ""), bool(st ["ok"]))

	var before: int = world.builds.hay_stairs.size()
	var purse:= GameState.money
	player.build.primary()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_ok("clicking builds one (%d -> %d)" % [before, int(world.builds.hay_stairs.size())],
		int(world.builds.hay_stairs.size()) == before + 1)
	_ok("...and charges for it ($%.0f)" % (purse - GameState.money),
		is_equal_approx(purse - GameState.money, Cfg.HAY_STAIRS_COST))


	if int(world.builds.hay_stairs.size()) > before:
		var placed: HayStairs = world.builds.hay_stairs [world.builds.hay_stairs.size() - 1]
		var out:= placed.outfeed_port() - placed.global_position
		out.y = 0.0
		var toward:= Vector3(eye.x - spot.x, 0.0, eye.z - spot.z).normalized()
		_ok("...with its open front toward the player (%.2f)" % out.normalized().dot(toward),
			out.normalized().dot(toward) > 0.9)


	for i in 12:
		await get_tree().process_frame
	_ok("a second one on the same spot is refused (%s)"
		% player.build.status().get("reason", ""),
		not bool(player.build.status() ["ok"]))


	if int(world.builds.hay_stairs.size()) > before:
		var built: HayStairs = world.builds.hay_stairs [world.builds.hay_stairs.size() - 1]
		var refund: float = world.builds.demolish(built)
		_ok("...and it can be taken down again for $%.0f" % refund,
			is_equal_approx(refund, Cfg.HAY_STAIRS_COST))
	else:
		_ok("...and it can be taken down again", false)
	player.build.cancel()
	await get_tree().process_frame


func _check_catch(tower: HayStairs) -> void:
	print("\n=== catch and let down ===")
	var before:= _wads_everywhere(tower)
	var mouth:= tower.mouth_position()


	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), mouth + Vector3(0.55, 1.0, 0.3)),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
	_ok("a wad was dropped in", wad != null)
	if wad == null:
		return
	var strands_in:= wad.strands


	var claimed:= false
	var landed:= Vector3.ZERO
	var seq:= -1
	var n0:= _lowered.size()
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if tower.in_transit() > 0:
			claimed = true
		if _lowered.size() > n0:
			seq = int(_lowered [_lowered.size() - 1])
			var at:= _load_on_deck(tower, seq)
			if not at.is_empty():
				landed = at ["pos"]
				break
	var out:= _load_on_deck(tower, seq) if seq >= 0 else { }
	_ok("the machine took it over on the way down", claimed)
	_ok("it is still one wad", not out.is_empty())
	if out.is_empty():
		return
	_ok("...with its hay intact (%d of %d)" % [int(out ["strands"]), strands_in],
		int(out ["strands"]) == strands_in)

	_ok("it came out on the belt (%.2f m up, deck is %.2f)"
		% [landed.y, Cfg.HAY_STAIRS_DECK],
		absf(landed.y - Cfg.HAY_STAIRS_DECK) < 0.45)
	_ok("...and the belt has it (as a %s)" % out ["as"], not out.is_empty())
	_ok("nothing was duplicated (%d wads before, %d after)"
		% [before, _wads_everywhere(tower)], _wads_everywhere(tower) == before + 1)
	_ok("the machine let go of it", tower.in_transit() == 0)
	_remove_load(tower, seq)
	await get_tree().physics_frame


func _check_motor(tower: HayStairs) -> void:
	print("\n=== the belt motor ===")
	Tech.grant("belt_speed", 0)
	var slow:= await _rail_frames(tower)
	Tech.grant("belt_speed", 8)
	_ok("an upgrade reaches a tower already built (%.2f m/s, belts %.2f)"
		% [tower._speed, Tech.belt_speed()],
		is_equal_approx(tower._speed, Tech.belt_speed()))
	var fast:= await _rail_frames(tower)
	Tech.grant("belt_speed", 0)
	_ok("...and a load comes down faster (%d frames on the rails, %d without it)"
		% [fast, slow], fast > 0 and slow > 0 and fast * 2 < slow)
	_ok("...and a reset slows it again (%.2f m/s)" % tower._speed,
		is_equal_approx(tower._speed, Cfg.BELT_SPEED))


func _rail_frames(tower: HayStairs) -> int:
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), tower.mouth_position() + Vector3(0.0, 0.6, 0.3)),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
	if wad == null:
		return -1
	var frames:= 0
	var n0:= _lowered.size()
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if _lowered.size() > n0:
			break
		if tower.in_transit() > 0:
			frames += 1
	var whole:= _lowered.size() > n0
	if whole:
		_remove_load(tower, int(_lowered [_lowered.size() - 1]))
	elif is_instance_valid(wad):
		world.props.remove(wad)
	await get_tree().physics_frame
	return frames if whole else -1


func _check_front(tower: HayStairs) -> void:
	print("\n=== nothing leaves by the front ===")
	var inside:= tower.to_global(Vector3(0.0, 2.3, 0.1))
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), inside),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
	if wad == null:
		_ok("a wad was thrown at the front", false)
		return
	wad.linear_velocity = tower.global_transform.basis * Vector3(0.0, 0.0, 5.0)
	wad.angular_velocity = Vector3.ZERO


	var out_front:= false
	var far:= 0.0
	var n0:= _lowered.size()
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if is_instance_valid(wad) and wad.is_inside_tree():
			var local:= tower.to_local(wad.global_position)


			far = maxf(far, local.z if local.y > 1.05 else 0.0)
			if local.z > HayStairs.FRONT_Z + 0.2 and local.y > 1.05:
				out_front = true
		if _lowered.size() > n0:
			break
	_ok("it stayed in (reached z %.2f, the mouth is at %.2f)"
		% [far, HayStairs.FRONT_Z], not out_front)
	var seq:= int(_lowered [_lowered.size() - 1]) if _lowered.size() > n0 else -1
	_ok("...and left the way it was meant to",
		seq >= 0 and not _load_on_deck(tower, seq).is_empty())
	if seq >= 0:
		_remove_load(tower, seq)
	elif is_instance_valid(wad):
		world.props.remove(wad)
	await get_tree().physics_frame


func _check_jam(tower: HayStairs) -> void:
	print("\n=== the jam that cannot happen ===")

	var wedge:= tower._point_at(tower._cum [2]) + Vector3.UP * 0.3
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), wedge),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
	if wad == null:
		_ok("a wad was wedged in", false)
		return
	wad.linear_velocity = Vector3.ZERO
	wad.angular_velocity = Vector3.ZERO
	var freed:= false
	var n0:= _lowered.size()
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if _lowered.size() > n0:
			freed = true
			break
	_ok("a load put down at rest inside is carried out anyway", freed)
	if freed:
		_remove_load(tower, int(_lowered [_lowered.size() - 1]))
	elif is_instance_valid(wad):
		world.props.remove(wad)
	await get_tree().physics_frame


func _check_backlog(tower: HayStairs) -> void:
	print("\n=== a stream faster than it lets down ===")
	var deck:= tower.deck()
	var mouth:= tower.mouth_position()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var fed: Array [HayWad] = []
	var drained:= 0
	var closest:= INF
	var most:= 0
	for i in BACKLOG_FRAMES:
		if i % BACKLOG_EVERY == 0 and fed.size() < BACKLOG_WADS:
			var off:= Vector3(rng.randf_range(-0.45, 0.45), 0.9,
				rng.randf_range(-0.25, 0.25))
			var w:= world.props.spawn("hay_wad", Transform3D(Basis(), mouth + off),
				{ "strands": BACKLOG_STRANDS }) as HayWad
			if w != null:
				fed.append(w)
		await get_tree().physics_frame

		var ss: Array [float] = []
		for r in tower._carried:
			ss.append(float(r ["s"]))
		ss.sort()
		for k in range(1, ss.size()):
			closest = minf(closest, ss [k] - ss [k - 1])
		most = maxi(most, ss.size())

		if i >= BACKLOG_DRAIN_FROM and deck != null:
			drained += _drain_deck(deck, BACKLOG_DRAIN_S)

		if fed.size() == BACKLOG_WADS and i > BACKLOG_DRAIN_FROM and i % 30 == 0:
			var busy:= tower.in_transit() > 0
			for w in fed:
				if is_instance_valid(w) and w.is_inside_tree() and _up_in(tower, w):
					busy = true
					break
			if not busy and deck.riders().is_empty() and deck.run.count() == 0:
				break

	var stuck:= 0
	var litter:= 0
	for w in fed:
		if not is_instance_valid(w) or not w.is_inside_tree():
			continue
		if _up_in(tower, w):
			stuck += 1
		else:
			litter += 1
	var room:= int(floor(tower._cum [tower._cum.size() - 1] / HayStairs.RIDE_GAP)) + 1
	_ok("never two loads on the rails closer than a gap (closest %.3f, gap %.2f)"
		% [closest if closest < INF else -1.0, HayStairs.RIDE_GAP],
		closest >= HayStairs.RIDE_GAP - 0.01)
	_ok("never more loads on the rails than fit on them (%d, room for %d)" % [most, room],
		most <= room)
	_ok("the queue drained (%d of %d let down onto the deck)" % [drained, BACKLOG_WADS],
		drained > 0)
	_ok("nothing is left up in the tower (%d stuck, %d on the rails)"
		% [stuck, tower.in_transit()], stuck == 0 and tower.in_transit() == 0)
	print("  (%d spilled or left loose below the treads)" % litter)
	for w in fed:
		if is_instance_valid(w) and w.is_inside_tree():
			world.props.remove(w)
	await get_tree().physics_frame


func _check_restored_heap() -> void:
	print("\n=== a save with a heap in the throat ===")

	var at:= Vector3(13.0, 0.0, 4.0)
	var stack: Array [HayWad] = []
	for i in 24:


		var w:= world.props.spawn("hay_wad",
			Transform3D(Basis(), at + Vector3(0.0, 2.94 + 0.017 * i, 0.0)),
			{ "strands": BACKLOG_STRANDS }) as HayWad
		if w != null:
			stack.append(w)
	var tower: HayStairs = world.builds.add_hay_stairs(at, 0.0)
	for i in 3:
		await get_tree().physics_frame

	var left: Array [HayWad] = []
	for w in stack:
		if is_instance_valid(w) and w.is_inside_tree():
			left.append(w)
	var inside:= 0
	for a in left.size():
		for b in range(a + 1, left.size()):
			var ba:= (left [a].global_transform * left [a].ride_box()).grow(-0.08)
			var bb:= (left [b].global_transform * left [b].ride_box()).grow(-0.08)
			if ba.intersects(bb):
				inside += 1
	_ok("the heap was thinned as the tower came up (%d of %d left)"
		% [left.size(), stack.size()], left.size() < stack.size() and left.size() <= 3)
	_ok("...and nothing left is inside anything else (%d pairs)" % inside, inside == 0)

	for i in TRANSIT_FRAMES * 2:
		await get_tree().physics_frame
	var up:= 0
	for w in left:
		if is_instance_valid(w) and w.is_inside_tree() and _up_in(tower, w):
			up += 1
	_ok("...and what was left comes down (%d still up, %d on the rails)"
		% [up, tower.in_transit()], up == 0 and tower.in_transit() == 0)
	for w in left:
		if is_instance_valid(w) and w.is_inside_tree():
			world.props.remove(w)


	_clear_records(tower.deck())
	for rb in tower.deck().riders():
		if rb is HayWad:
			world.props.remove(rb as Carryable)
	world.builds.demolish(tower)
	await get_tree().physics_frame


func _check_stall_lapses(tower: HayStairs) -> void:
	print("\n=== a stuck load can be cleared ===")
	var deck:= tower.deck()
	var speed:= deck.drive_speed
	deck.set_drive_speed(0.0)
	var mouth:= tower.mouth_position()


	var first:= world.props.spawn("hay_tuft", Transform3D(Basis(), mouth + Vector3(0, 0.9, 0)),
		{ "strands": STALL_TUFT }) as HayTuft
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if BeltPath.is_rider(first):
			break
	var second:= world.props.spawn("hay_tuft", Transform3D(Basis(), mouth + Vector3(0, 0.9, 0)),
		{ "strands": STALL_TUFT }) as HayTuft
	var born:= Time.get_ticks_msec()
	var total: float = tower._cum [tower._cum.size() - 1]
	var waiting:= false
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		for r in tower._carried:
			if r.get("body") == second and float(r ["s"]) >= total - 0.01:
				waiting = true
		if waiting:
			break


	for i in 30:
		await get_tree().physics_frame
	_ok("a load is held at the bottom by a stopped deck", waiting
		and tower.in_transit() == 1)
	if not waiting:
		deck.set_drive_speed(speed)
		for w in [first, second]:
			if is_instance_valid(w):
				world.props.remove(w)
		return
	_ok("...and while it is fresh the yard may not take it",
		world.props.is_spoken_for(second))

	for r in tower._carried:
		if r.get("body") == second:
			r ["moved_ms"] = Time.get_ticks_msec() - HayStairs.STALL_HOLD_MS - 1000


	var until:= maxi(Time.get_ticks_msec() + int(LiveStrandManager.HOLD_GRACE * 1000.0),
		born + int(Cfg.PROP_BIRTH_GRACE * 1000.0)) + 300
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	_ok("a minute without moving and the hold has lapsed",
		not LiveStrandManager.is_on_hold(second))
	_ok("...so the yard may take it", not world.props.is_spoken_for(second))
	world.props.fold_away(second)
	for i in 3:
		await get_tree().physics_frame
	_ok("...and taking it leaves nothing on the rails (%d)" % tower.in_transit(),
		tower.in_transit() == 0)

	deck.set_drive_speed(speed)
	if is_instance_valid(first):
		world.props.remove(first)
	await get_tree().physics_frame


func _up_in(tower: HayStairs, w: Node3D) -> bool:
	var l:= tower.to_local(w.global_position)
	return absf(l.x) < 0.95 and absf(l.z) < 0.55 and l.y > 0.9 and l.y < 3.8


func _check_ghost(tower: HayStairs) -> void:
	print("\n=== the hologram ===")
	var ghost:= HayStairs.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = tower.global_position + Vector3(0, 0, 8.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_ok("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	_ok("...and lays no belt of its own", ghost.deck() == null)
	_ok("...and claims nothing", ghost.in_transit() == 0)
	ghost.set_preview_valid(false)


	var shared:= HayCompressor.materials_shared()
	var mine:= _table_mats(tower)
	var theirs:= _table_mats(ghost)
	var worn:= _worn(tower)
	var ghost_worn:= _worn(ghost)
	var alone:= 0
	for m in worn:
		if not ghost_worn.has(m):
			alone += 1
	print("  census: the placed machine wears %d materials, %d not shared with the ghost"
		% [worn.size(), alone])
	var alike:= 0
	var apart:= 0
	for key in theirs:
		if mine.has(key):
			if mine [key] == theirs [key]:
				alike += 1
			else:
				apart += 1
	_ok("the ghost wears %s materials (%d the same, %d apart)"
		% ["the same" if shared else "its own", alike, apart],
		alike + apart > 0 and (apart == 0 if shared else alike == 0))
	var tinted:= 0
	for mesh in tower._meshes():
		if mesh.material_overlay != null:
			tinted += 1
	_ok("...and its red does not reach the placed tower (%d tinted)" % tinted,
		tinted == 0)
	world.remove_child(ghost)
	ghost.queue_free()
	await get_tree().process_frame


func _worn(machine: Node3D) -> Dictionary:
	var out:= { }
	for mesh in machine._meshes():
		if mesh.mesh != null:
			for i in mesh.mesh.get_surface_count():
				var m:= (mesh as MeshInstance3D).get_surface_override_material(i)
				if m != null:
					out [m] = true
	return out


func _table_mats(tower: HayStairs) -> Dictionary:
	var out:= { }
	var table: Dictionary = HayStairs.spec_table().get("surfaces", { })
	for mesh in tower._meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var m:= mesh.get_surface_override_material(i)
			if m != null and table.has(m.resource_name):
				out [m.resource_name] = m
	return out


func _check_dismantle(tower: HayStairs) -> void:
	print("\n=== dismantled under its load ===")
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), tower.mouth_position() + Vector3(0.0, 1.0, 0.0)),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
	if wad == null:
		_ok("a wad was dropped in", false)
		return


	var carried:= false
	var held_at:= Vector3.ZERO
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if tower.in_transit() > 0 and not tower.carried_record(0).is_empty():
			held_at = tower.carried_transform(0).origin
			if held_at.y > Cfg.HAY_STAIRS_DECK + 0.6:
				carried = true
				break
	_ok("the wad was on the rails, well above the deck", carried)
	if not carried:
		if is_instance_valid(wad):
			world.props.remove(wad)
		return
	var refund: float = world.builds.demolish(tower)
	_ok("the tower was dismantled under it (refund %.0f)" % refund,
		refund > 0.0 and (not is_instance_valid(tower) or tower.is_queued_for_deletion()))
	for i in 5:
		await get_tree().physics_frame


	var loose:= _wad_body_near(held_at, 0.6)
	_ok("the wad was let go of (a body where it was held)", loose != null
		and not loose.freeze and not loose.has_meta(HayStairs.META_CARRIED))
	for i in 120:
		await get_tree().physics_frame
	var drop:= held_at.y - loose.global_position.y if is_instance_valid(loose) else 0.0
	_ok("...and fell (%.2f m down)" % drop, drop > 0.3)
	if is_instance_valid(loose):
		world.props.remove(loose)
	await get_tree().physics_frame


func _wads() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayWad:
			out.append(item)
	return out


func _wads_everywhere(tower: HayStairs) -> int:
	var n:= _wads().size()
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		n += _records_on(path, BeltRun.Kind.WAD)
	if is_instance_valid(tower):
		n += tower.carried_count(BeltRun.Kind.WAD)
	return n


func _records_on(path: BeltPath, kind: int) -> int:
	var run: BeltRun = path.run
	var n:= 0
	for i in range(run.first(), run.first() + run.count()):
		if run.kind_of(i) == kind:
			n += 1
	return n


func _load_on_deck(tower: HayStairs, seq: int) -> Dictionary:
	var deck:= tower.deck()
	var where:= BeltPath.record_where(seq)
	if not where.is_empty() and where ["path"] == deck:
		var run: BeltRun = deck.run
		return { "as": "record", "pos": (where ["pose"] as Transform3D).origin,
			"strands": run.strands_of(int(where ["row"])) }
	for rb in deck.riders():
		if rb is HayWad and rb is not HayTuft:
			return { "as": "body", "pos": rb.global_position, "strands": (rb as HayWad).strands }
	return { }


func _remove_load(tower: HayStairs, seq: int) -> void:
	var where:= BeltPath.record_where(seq)
	if not where.is_empty():
		(where ["path"] as BeltPath).run.remove_at(int(where ["row"]))
		return
	for rb in tower.deck().riders():
		if rb is HayWad and rb is not HayTuft:
			world.props.remove(rb as Carryable)
			return
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and item is HayWad and item is not HayTuft and tower.to_local(item.global_position).length() < 4.0:
			world.props.remove(item)
			return


func _drain_deck(deck: BeltPath, s_min: float) -> int:
	var n:= 0
	var run: BeltRun = deck.run
	var i:= run.first() + run.count() - 1
	while i >= run.first():
		if run.kind_of(i) == BeltRun.Kind.WAD and run.s_of(i) > s_min:
			var was_head:= i == run.first()
			run.remove_at(i)
			n += 1
			if was_head:
				break
		i -= 1
	for rb in deck.riders():
		if rb is HayWad and rb is not HayTuft and float(deck._nearest(rb.global_position) ["s"]) > s_min:
			world.props.remove(rb as Carryable)
			n += 1
	return n


func _clear_records(path: BeltPath) -> int:
	if path == null or not is_instance_valid(path):
		return 0
	var run: BeltRun = path.run
	var n:= 0
	var i:= run.first() + run.count() - 1
	while i >= run.first():
		var was_head:= i == run.first()
		run.remove_at(i)
		n += 1
		if was_head:
			break
		i -= 1
	return n


func _wad_body_near(at: Vector3, radius: float) -> HayWad:
	var best: HayWad = null
	var best_d:= radius
	for item in world.props.items:
		if not is_instance_valid(item) or not item.is_inside_tree() or item is not HayWad or item is HayTuft:
			continue
		var d: float = item.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = item as HayWad
	return best


func _ok(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
