class_name DevHayLiftProbe
extends Node


var world: Node3D
var player: Player


var _lifted: Array = []

const SETTLE_FRAMES:= 40


const TRANSIT_FRAMES:= 1100


const SECTIONS:= 3


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

	var at:= Vector3(13.0, Cfg.HAY_LIFT_DECK, -6.0)
	var lift: HayLift = world.builds.add_hay_lift(at, 0.0, SECTIONS)
	lift.lifted_record.connect(_on_lifted)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	if "--pouronly" in OS.get_cmdline_user_args():
		await _check_backpressure(lift)
		print("\n%d passed, %d failed" % [_pass, _fail])
		world.block_save = true
		get_tree().quit(1 if _fail > 0 else 0)
		return


	if "--strawonly" in OS.get_cmdline_user_args():
		await _check_loose_straw(lift)
		await _check_straw_trickle(lift)
		await _check_tuft_ride(lift)
		print("\n%d passed, %d failed" % [_pass, _fail])
		world.block_save = true
		get_tree().quit(1 if _fail > 0 else 0)
		return

	await _check_model(lift)
	await _check_numbers()
	await _check_geometry(lift)
	await _check_rails(lift)
	await _check_snapping(lift)
	await _check_buying()
	await _check_climb(lift)
	await _check_stall_lapses(lift)
	await _check_queue(lift)
	await _check_backpressure(lift)
	await _check_set_on_infeed(lift)
	await _check_loose_straw(lift)
	await _check_straw_trickle(lift)
	await _check_tuft_ride(lift)
	var skewed: HayLift = await _check_containment()
	await _check_motor(skewed)
	await _check_save(lift)
	await _check_ghost(lift)

	await _check_dismantle(lift)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _check_model(lift: HayLift) -> void:
	print("\n=== model ===")
	_ok("model instantiated", lift.get_node_or_null("Model") != null)
	for part in [HayLift.N_BOOT, HayLift.N_HEAD]:
		_ok("kit part %s" % part, lift._find(part) != null)


	for marker in [HayLift.N_BELT_IN, HayLift.N_BELT_OUT, HayLift.N_NIP,
			HayLift.N_PANEL]:
		_ok("marker %s" % marker, lift._find(marker) != null)
	_ok("material table loads", not HayLift.spec_table().is_empty())


	_ok("the tower is %d sections tall (%d found)" % [SECTIONS, lift._sections.size()],
		lift._sections.size() == SECTIONS)
	var strays:= 0
	for k in lift._sections.size():
		var part: Node3D = lift._sections [k]
		var want:= HayLift.MODEL_DECK + HayLift.BOOT_FLANGE + Cfg.HAY_LIFT_SECTION * float(k)
		if absf(part.position.y - want) > 0.001:
			strays += 1
	_ok("...each on its own metre (%d out of place)" % strays, strays == 0)
	_ok("...and none of them left at the origin, inside the boot",
		lift._sections.is_empty()
			or absf((lift._sections [0] as Node3D).position.y) > 0.5)


	var anim: AnimationPlayer = lift._anim
	_ok("the Run clip is there", anim != null and anim.has_animation(HayLift.CLIP))
	if anim != null and anim.has_animation(HayLift.CLIP):
		var length:= anim.get_animation(HayLift.CLIP).length


		_ok("...and is 90 frames at 30 fps (%.3f s)" % length,
			absf(length - 3.0) <= 1.0 / 30.0 + 0.001)
		_ok("...and it is running", anim.is_playing())


	var solid:= 0
	for n in lift.find_children("*", "StaticBody3D", true, false):
		if (n as StaticBody3D).collision_layer == Cfg.L_BUILD:
			solid += 1
	_ok("the machine builds its own hulls on L_BUILD (%d)" % solid, solid >= 3)


	var belt_surfaces:= 0
	var uvd:= 0
	for mesh in lift._meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null or src.resource_name != HayLift.MAT_BELT:
				continue
			belt_surfaces += 1
			if HayLift._has_uvs(mesh.mesh, i):
				uvd += 1
	_ok("the model names its belt surfaces (%d found)" % belt_surfaces,
		belt_surfaces > 0)
	_ok("all internal belt surfaces carry travel UVs (%d of %d)"
		% [uvd, belt_surfaces], uvd == belt_surfaces and uvd > 0)
	_ok("internal belt material follows transport speed", lift._belt_mat != null
		and is_equal_approx(float(lift._belt_mat.get_shader_parameter("speed")), lift.ride_speed()))


	var boot:= lift._boot as MeshInstance3D
	var beyond:= 0
	var tris:= 0
	var nearest:= INF
	if boot != null and boot.mesh != null:
		for i in boot.mesh.get_surface_count():
			var arrays:= boot.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
			var idx = arrays [Mesh.ARRAY_INDEX]
			tris += int((idx.size() if idx != null else verts.size()) / 3.0)
			for v in verts:
				var z:= lift.to_local(boot.to_global(v)).z
				nearest = minf(nearest, z)
				if z < HayLift.MODEL_CUT_Z - 0.002:
					beyond += 1
	_ok("the boot's own infeed is cut off at the mouth (%d vertices past the cut, nearest %.3f)"
		% [beyond, nearest], boot != null and beyond == 0)
	_ok("...and the rest of the boot survived the cut (%d triangles)" % tris,
		tris > 10000)
	var drum:= lift._find(HayLift.N_BOOT_DRUM) as Node3D
	_ok("...and the drum at the end of it is hidden",
		drum != null and not drum.visible)
	await get_tree().process_frame


func _check_numbers() -> void:
	print("\n=== the numbers ===")
	_ok("a bare lift rises %.2f m (%.2f)"
		% [Cfg.HAY_LIFT_BASE_RISE, HayLift.rise_for(0)],
		is_equal_approx(HayLift.rise_for(0), Cfg.HAY_LIFT_BASE_RISE))
	_ok("...and a section adds exactly one",
		is_equal_approx(HayLift.rise_for(1) - HayLift.rise_for(0),
			Cfg.HAY_LIFT_SECTION))
	_ok("the tallest reaches %.2f m"
		% HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX),
		HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX) <= Cfg.STAIR_MAX_RISE)


	_ok("...and the second click can reach it (%.1f m of reach)"
		% Cfg.BUILD_REACH_MAX,
		HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX) <= Cfg.BUILD_REACH_MAX)
	_ok("sections_for is rise_for backwards",
		HayLift.sections_for(HayLift.rise_for(4)) == 4)
	_ok("...and it clamps rather than going negative",
		HayLift.sections_for(-99.0) == 0
			and HayLift.sections_for(999.0) == Cfg.HAY_LIFT_SECTIONS_MAX)
	_ok("the price is flat plus the tower ($%.0f for %d)"
		% [HayLift.cost_for(SECTIONS), SECTIONS],
		is_equal_approx(HayLift.cost_for(SECTIONS),
			Cfg.HAY_LIFT_COST + Cfg.HAY_LIFT_SECTION_COST * float(SECTIONS)))
	_ok("...and the catalogue's 'from' is the shortest one",
		is_equal_approx(HayLift.cost_for(0), Cfg.HAY_LIFT_COST))


	var bale:= Cfg.COMPRESSOR_BALE_SIZE
	var across: Array [float] = [bale.y, bale.z]
	across.sort()
	_ok("the nip clears a bale across its travel (%.3f vs %.3f)"
		% [Cfg.HAY_LIFT_NIP, across [1]], Cfg.HAY_LIFT_NIP > across [1])


	var wad:= Cfg.WAD_BASE_SIZE
	_ok("...and a wad in every axis (%.3f)" % maxf(wad.x, maxf(wad.y, wad.z)),
		Cfg.HAY_LIFT_NIP > maxf(wad.x, maxf(wad.y, wad.z)))


	var travelled:= Cfg.HAY_LIFT_SPEED * 3.0
	for pair: Array in [[0.16711, 2.0], [0.11141, 3.0]]:
		var turns: float = travelled / (TAU * float(pair [0]))
		_ok("a drum of %.5f m turns %.0f whole times a loop (%.3f)"
			% [pair [0], pair [1], turns], absf(turns - float(pair [1])) < 0.01)
	await get_tree().process_frame


func _check_geometry(lift: HayLift) -> void:
	print("\n=== geometry ===")
	var infeed:= lift.port_in()
	var out:= lift.port_out()


	_ok("the mouth is on the deck plane (%.3f vs %.3f)"
		% [infeed.y - lift.global_position.y + Cfg.HAY_LIFT_DECK, Cfg.HAY_LIFT_DECK],
		absf(infeed.y - lift.global_position.y) < 0.02)
	_ok("the discharge is exactly the rise above it (%.3f vs %.3f)"
		% [out.y - infeed.y, lift.rise()],
		absf((out.y - infeed.y) - lift.rise()) < 0.02)
	_ok("...and the rise is what %d sections buy" % SECTIONS,
		is_equal_approx(lift.rise(), HayLift.rise_for(SECTIONS)))


	_ok("the MODEL discharges a whole %d + %d m over the mouth (%.3f)"
		% [int(Cfg.HAY_LIFT_BASE_RISE), SECTIONS, out.y - infeed.y],
		absf((out.y - infeed.y) - (Cfg.HAY_LIFT_BASE_RISE + float(SECTIONS))) < 0.01)


	var fwd:= lift.forward()
	_ok("the mouth is behind the machine (%.2f m)" % (infeed - lift.global_position).dot(fwd),
		(infeed - lift.global_position).dot(fwd) < -1.5)
	_ok("...and the discharge in front of it (%.2f m)" % (out - lift.global_position).dot(fwd),
		(out - lift.global_position).dot(fwd) > 1.5)
	_ok("both ports are on the tower's own axis",
		absf((infeed - lift.global_position).dot(lift.global_basis.x)) < 0.05
			and absf((out - lift.global_position).dot(lift.global_basis.x)) < 0.05)


	var feet:= INF
	var boot:= lift._boot as MeshInstance3D
	for surface in boot.mesh.get_surface_count():
		var arrays:= boot.mesh.surface_get_arrays(surface)
		for vertex: Vector3 in arrays [Mesh.ARRAY_VERTEX]:
			feet = minf(feet, boot.to_global(vertex).y)
	var floor_y:= lift.global_position.y - Cfg.HAY_LIFT_DECK
	_ok("the support feet touch the floor (gap %.6f m)" % (feet - floor_y),
		absf(feet - floor_y) < 0.001)


	_ok("it lays an infeed deck", lift.deck() != null)
	_ok("...and a discharge deck", lift.outfeed_deck() != null)
	_ok("...and they are not the same path", lift.deck() != lift.outfeed_deck())


	for pair: Array in [[lift.deck(), "infeed", lift.port_in().y],
			[lift.outfeed_deck(), "discharge", lift.port_out().y]]:
		var path: BeltPath = pair [0]
		if path == null:
			continue
		var ends:= _deck_ends(path)
		var rise: float = absf(ends [1].y - ends [0].y)
		_ok("the %s deck is level (%.3f m of fall over it)" % [pair [1], rise],
			rise < 0.02)
		_ok("...and on its own port's plane (%.3f off)"
			% absf(ends [0].y - float(pair [2])),
			absf(ends [0].y - float(pair [2])) < 0.02)
		print("  [note] %s deck %v -> %v (machine frame)"
			% [pair [1], lift.to_local(ends [0]), lift.to_local(ends [1])])


	if lift.deck() != null:
		var ends:= _deck_ends(lift.deck())
		var want:= lift.port_in().distance_to(
			lift.to_global(Vector3(0.0, 0.0, HayLift.MOUTH_Z)))
		_ok("the infeed deck runs from the port to the mouth (%.2f of %.2f m)"
			% [ends [0].distance_to(ends [1]), want],
			absf(ends [0].distance_to(ends [1]) - want) < 0.02 and want > 1.0)


	var blocked: Array [String] = []
	for spot: Vector3 in [lift.port_in(), lift.port_out(),
			lift._point_at(lift.total_length())]:
		for n in lift.find_children("*", "StaticBody3D", true, false):
			var body:= n as StaticBody3D
			if body.collision_layer != Cfg.L_BUILD:
				continue
			for c in body.find_children("*", "CollisionShape3D", true, false):
				var cs:= c as CollisionShape3D
				var box:= cs.shape as BoxShape3D
				if box == null:
					continue
				var at:= body.to_local(spot) - cs.position
				if absf(at.x) < box.size.x * 0.5 and absf(at.y) < box.size.y * 0.5 and absf(at.z) < box.size.z * 0.5:
					blocked.append(body.name)
	_ok("no hull of its own stands in its ports or its drop (%s)"
		% ("clear" if blocked.is_empty() else ", ".join(blocked)),
		blocked.is_empty())
	await get_tree().process_frame


func _check_rails(lift: HayLift) -> void:
	print("\n=== the rails ===")
	var line:= lift._line
	_ok("the line has both bends in it (%d nodes)" % line.size(),
		line.size() >= 2 + HayLift.BEND_STEPS * 2 + 2)
	if line.size() < 4:
		return
	var head: Vector3 = line [0]
	var tail: Vector3 = line [line.size() - 1]
	_ok("it starts at the mouth, a half nip up (%.3f)"
		% (head.y - lift.port_in().y),
		absf((head.y - lift.port_in().y) - HayLift.HALF_NIP) < 0.02)
	_ok("...and ends a half nip over the discharge (%.3f)"
		% (tail.y - lift.port_out().y),
		absf((tail.y - lift.port_out().y) - HayLift.HALF_NIP) < 0.02)


	var dips:= 0
	for i in range(1, line.size()):
		if line [i].y < line [i - 1].y - 0.001:
			dips += 1
	_ok("it never descends (%d downhill steps)" % dips, dips == 0)
	_ok("the whole path is %.2f m long" % lift.total_length(),
		lift.total_length() > lift.rise())


	_ok("the nip closes before the first bend (%.2f m in)" % lift._sink_in,
		lift._sink_in > 0.1 and lift._sink_in < lift.total_length() * 0.5)
	_ok("...and opens again over the last of the discharge",
		lift._sink_out > lift._sink_in
			and lift._sink_out < lift.total_length())
	_ok("a load at the mouth keeps the height it arrived at",
		is_equal_approx(lift._sink_fade(0.0), 1.0))
	_ok("...is centred in the nip by the climb",
		is_equal_approx(lift._sink_fade(lift.total_length() * 0.5), 0.0))
	_ok("...and is back on the deck by the discharge",
		is_equal_approx(lift._sink_fade(lift.total_length()), 1.0))
	await get_tree().process_frame


func _check_snapping(lift: HayLift) -> void:
	print("\n=== joining belt to it ===")
	var infeed:= lift.port_in()
	var out:= lift.port_out()
	var near_in:= infeed + Vector3(0.3, 0.0, 0.3)
	var near_out:= out + Vector3(0.3, 0.0, 0.3)
	_ok("a belt end near the mouth snaps onto it",
		world.builds.snap_lift_port(near_in).is_equal_approx(infeed))


	_ok("...and one near the discharge snaps onto that",
		world.builds.snap_lift_port(near_out).is_equal_approx(out))
	_ok("...and the two are told apart",
		not world.builds.snap_lift_port(near_out).is_equal_approx(infeed))
	var far:= infeed + Vector3(9.0, 0.0, 9.0)
	_ok("a belt end well clear is left alone",
		world.builds.snap_lift_port(far).is_equal_approx(far))


	_ok("snap_endpoint finds them too",
		world.builds.snap_endpoint(near_in).is_equal_approx(infeed))
	_ok("the machine owns its own discharge port",
		world.builds.outfeed_owner_at(out) == lift)
	_ok("...and a run laid at either end takes its bearing",
		world.builds.port_bearing_at(infeed).dot(lift.forward()) > 0.99
			and world.builds.port_bearing_at(out).dot(lift.forward()) > 0.99)

	_ok("a second lift on the same spot is refused",
		world.builds.lift_overlap(lift.global_position))
	_ok("...and one a clear diameter away is not",
		not world.builds.lift_overlap(lift.global_position
			+ Vector3(Cfg.HAY_LIFT_HALF_WIDTH * 2.0 + 0.2, 0.0, 0.0)))


	_ok("...and height does not excuse an overlap",
		world.builds.lift_overlap(lift.global_position + Vector3(0.0, 6.0, 0.0)))


	var fwd:= lift.forward()
	var across:= Vector3(fwd.z, 0.0, - fwd.x)
	var at:= lift.global_position
	_ok("a lift 1.6 m beside it on the same bearing fits",
		not world.builds.lift_overlap(at + across * 1.6, null, fwd)
			and not world.builds.lift_overlap(at - across * 1.6, null, fwd))
	_ok("...and one 1.4 m beside it does not",
		world.builds.lift_overlap(at + across * 1.4, null, fwd))
	_ok("...nor one 4 m ahead of it on the same line",
		world.builds.lift_overlap(at + fwd * 4.0, null, fwd))


	_ok("...nor one 5.9 m ahead of it",
		world.builds.lift_overlap(at + fwd * 5.9, null, fwd))
	_ok("...while one 6 m ahead of it, mouth on this one's discharge, fits",
		not world.builds.lift_overlap(at + fwd * 6.0, null, fwd))
	var tool: BuildTool = player.build
	if tool != null and tool._lift_ghost != null:
		tool._lift_ghost.set_riser(HayLift.SPACER)
		_ok("...and 2 m beside it the tool finds room for a whole tower",
			not tool._lift_blocked(at + across * 2.0, fwd, SECTIONS))
		await _check_infeed_room(tool, at + across * 2.0, fwd,
			lift.port_in() + across * 2.0)
	await get_tree().process_frame


func _check_infeed_room(tool: BuildTool, site: Vector3, fwd: Vector3,
		port: Vector3) -> void:
	var across:= Vector3(fwd.z, 0.0, - fwd.x)
	var mid:= site - fwd * 2.0
	var crossing: Conveyor = world.builds.add_conveyor(
		mid - across * 0.9, mid + across * 0.9)
	for i in 4:
		await get_tree().physics_frame
	_ok("a lift whose infeed deck crosses a belt has no room",
		crossing != null and tool._lift_blocked(site, fwd, 0))
	if crossing != null:
		world.builds.demolish(crossing)
	for i in 4:
		await get_tree().physics_frame
	var feeding: Conveyor = world.builds.add_conveyor(port - fwd * 2.0, port)
	for i in 4:
		await get_tree().physics_frame
	_ok("...while one on the end of the run feeding it does",
		feeding != null and not tool._lift_blocked(site, fwd, 0))
	if feeding != null:
		world.builds.demolish(feeding)
	for i in 4:
		await get_tree().physics_frame


func _check_buying() -> void:
	print("\n=== buying one ===")
	Tech.grant("haystairs")
	Tech.grant("haylift")
	_ok("the tree sells it", BuildCatalog.is_unlocked("haylift"))
	_ok("...and the panel has an icon for it",
		CatalogPanel._icon_for("haylift") != null)

	player.equip_build("haylift")
	_ok("equipping puts the tool in lift mode",
		player.build_id == "haylift"
			and player.build._mode == BuildTool.Mode.HAY_LIFT)


	var spot:= Vector3(13.0, 0.0, 4.0)
	var eye:= spot + Vector3(0.0, 1.7, 4.0)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	_look_at(eye, spot)
	for i in 12:
		await get_tree().process_frame

	var st: Dictionary = player.build.status()
	_ok("the readout is the lift's own (%s)" % st.get("kind", "?"),
		st.get("kind", "") == "haylift")
	_ok("...and says the height is not picked yet", not bool(st.get("placing", true)))


	_ok("...and quotes the bare price ($%.0f)" % float(st.get("cost", 0.0)),
		is_equal_approx(float(st.get("cost", 0.0)), Cfg.HAY_LIFT_COST))
	_ok("...and the hologram is drawn with no tower (%d sections)"
		% player.build._lift_ghost.sections,
		player.build._lift_ghost.sections == 0)
	_ok("clear floor is accepted (%s)" % st.get("reason", ""), bool(st ["ok"]))

	var before: int = world.builds.hay_lifts.size()
	var purse:= GameState.money
	player.build.primary()
	for i in 6:
		await get_tree().process_frame
	_ok("the first click builds nothing (%d)" % int(world.builds.hay_lifts.size()),
		int(world.builds.hay_lifts.size()) == before)
	_ok("...and charges nothing", is_equal_approx(purse, GameState.money))
	_ok("...it pins the base and waits for a height",
		bool(player.build.status().get("placing", false)))


	var want:= 4
	var target:= spot + Vector3(0.0, HayLift.rise_for(want), 0.0)
	_look_at(eye, target)
	for i in 12:
		await get_tree().process_frame
	var aimed: Dictionary = player.build.status()
	_ok("looking up builds a tower (%d sections, %.2f m)"
		% [int(aimed.get("sections", -1)), float(aimed.get("length", 0.0))],
		int(aimed.get("sections", -1)) == want)
	_ok("...the hologram followed it",
		player.build._lift_ghost.sections == want)
	_ok("...and the price followed the tower ($%.0f)" % float(aimed.get("cost", 0.0)),
		is_equal_approx(float(aimed.get("cost", 0.0)), HayLift.cost_for(want)))

	purse = GameState.money
	player.build.primary()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_ok("the second click builds one (%d -> %d)"
		% [before, int(world.builds.hay_lifts.size())],
		int(world.builds.hay_lifts.size()) == before + 1)
	_ok("...and charges the tower's price ($%.0f)" % (purse - GameState.money),
		is_equal_approx(purse - GameState.money, HayLift.cost_for(want)))


	if int(world.builds.hay_lifts.size()) > before:
		var built: HayLift = world.builds.hay_lifts [world.builds.hay_lifts.size() - 1]
		_ok("...at the height that was aimed (%d sections)" % built.sections,
			built.sections == want)
		var refund: float = world.builds.demolish(built)


		_ok("...and it refunds the tower too ($%.0f of $%.0f)"
			% [refund, HayLift.cost_for(want)],
			is_equal_approx(refund, HayLift.cost_for(want)))
	else:
		_ok("...at the height that was aimed", false)
		_ok("...and it refunds the tower too", false)
	player.build.cancel()
	await get_tree().process_frame


func _check_climb(lift: HayLift) -> void:
	print("\n=== up the tower ===")
	var before:= _wads_everywhere(lift)
	var seq:= await _feed_seq(lift, 0.0)
	_ok("a wad was set on the infeed (record %d)" % seq, seq >= 0)
	if seq < 0:
		return
	var strands_in:= Cfg.WAD_BASE_STRANDS

	var claimed:= false
	var highest:= - INF
	var landed:= Vector3.ZERO
	var out: Dictionary = { }
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		var at:= _where(lift, seq)
		if at ["stage"] == "rails":
			claimed = true
		if at ["stage"] != "gone":
			highest = maxf(highest, (at ["pos"] as Vector3).y)
			landed = at ["pos"]


		if claimed and lift.in_transit() == 0 and at ["stage"] == "out":
			out = at
			break
	_ok("the machine took it at the mouth", claimed)
	_ok("it is still one wad", not out.is_empty())
	if out.is_empty():
		_sweep(lift)
		return
	_ok("...with its hay intact (%d of %d)" % [int(out ["strands"]), strands_in],
		int(out ["strands"]) == strands_in)
	_ok("it climbed the tower (%.2f m up, the discharge is at %.2f)"
		% [highest, lift.port_out().y], highest > lift.port_out().y - 0.35)


	_ok("it came out on the discharge deck (%.3f m off it)"
		% absf(landed.y - lift.port_out().y),
		absf(landed.y - lift.port_out().y) < 0.3)
	_ok("...and over the deck rather than beside it (%.2f m out)"
		% (landed - lift.port_out()).length(),
		(landed - lift.port_out()).length() < 1.2)
	_ok("...and the belt has it (as a %s)" % out ["as"], out ["stage"] == "out")
	_ok("the machine let go of it", lift.in_transit() == 0)
	_ok("nothing was duplicated (%d wads before, %d after)"
		% [before, _wads_everywhere(lift)], _wads_everywhere(lift) == before + 1)
	_sweep(lift)
	await get_tree().physics_frame


func _check_stall_lapses(lift: HayLift) -> void:
	print("\n=== a stuck load can be cleared ===")
	var wad:= world.props.spawn("hay_tuft",
		Transform3D(Basis(), lift.port_in() + Vector3.UP * 0.03),
		{ "strands": STALL_TUFT }) as HayTuft
	if wad == null:
		_ok("a tuft was set on the infeed", false)
		return
	var born:= Time.get_ticks_msec()
	var carried:= false
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if not is_instance_valid(wad):
			break
		if lift.in_transit() > 0:
			carried = true
			break
	_ok("the lift took a load", carried)
	if not carried:
		if is_instance_valid(wad):
			world.props.remove(wad)
		return
	var speed:= lift._speed
	lift._speed = 0.0
	for i in 30:
		await get_tree().physics_frame
	_ok("...and while it is fresh the yard may not take it, rails stopped or not",
		world.props.is_spoken_for(wad))

	for r in lift._carried:
		if r.get("body") == wad:
			r ["moved_ms"] = Time.get_ticks_msec() - HayLift.STALL_HOLD_MS - 1000


	var until:= maxi(Time.get_ticks_msec() + int(LiveStrandManager.HOLD_GRACE * 1000.0),
		born + int(Cfg.PROP_BIRTH_GRACE * 1000.0)) + 300
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	_ok("a minute without moving and the hold has lapsed",
		not LiveStrandManager.is_on_hold(wad))
	_ok("...so the yard may take it", not world.props.is_spoken_for(wad))
	world.props.fold_away(wad)
	for i in 3:
		await get_tree().physics_frame
	_ok("...and taking it leaves nothing on the rails (%d)" % lift.in_transit(),
		lift.in_transit() == 0)
	lift._speed = speed
	await get_tree().physics_frame


func _check_queue(lift: HayLift) -> void:
	print("\n=== two at once ===")
	var first:= await _feed_seq(lift, 0.0)
	if first < 0:
		_ok("two wads were fed in", false)
		_sweep(lift)
		return


	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if lift.in_transit() > 0 and float((lift._carried [0] as Dictionary) ["s"]) > Cfg.HAY_LIFT_GAP + 0.1:
			break
	var second:= await _feed_seq(lift, 0.0)
	if second < 0:
		_ok("two wads were fed in", false)
		_sweep(lift)
		return
	_ok("two wads were fed in", true)

	var both:= false
	var closest:= INF
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if lift.in_transit() >= 2:
			both = true


			var a: float = float((lift._carried [0] as Dictionary) ["s"])
			var b: float = float((lift._carried [1] as Dictionary) ["s"])
			closest = minf(closest, absf(b - a))
		if lift.in_transit() == 0 and both:
			break
	_ok("both were on the rails at once", both)
	_ok("...and never closer than the nose-to-tail gap (%.2f of %.2f)"
		% [closest, Cfg.HAY_LIFT_GAP], closest >= Cfg.HAY_LIFT_GAP - 0.02)
	_ok("...and the machine is empty again", lift.in_transit() == 0)
	_sweep(lift)
	await get_tree().physics_frame


const POUR_RUN:= 7.0
const POUR_WADS:= 8


const POUR_SPACING:= 0.6


const POUR_FRAMES:= 2600


func _check_backpressure(lift: HayLift) -> void:
	print("\n=== a run pouring in faster than the tower climbs ===")
	var deck:= lift.deck()
	var tail:= lift.port_in() - lift.forward() * POUR_RUN


	var run: Conveyor = world.builds.add_conveyor(tail, lift.port_in())
	if run == null or deck == null:
		_ok("a run was laid into the mouth", false)
		return
	for i in 10:
		await get_tree().physics_frame
	_ok("a run was laid into the mouth", true)
	_ok("...and it hands its load to the lift's own infeed deck",
		run.downstream == deck)


	var fed: Array [HayWad] = []
	for k in POUR_WADS:
		var at:= lift.port_in() - lift.forward() * (0.45 + POUR_SPACING * float(k)) + Vector3.UP * Cfg.WAD_BASE_SIZE.y * 0.5
		var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
			{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
		if wad != null:
			fed.append(wad)
	_ok("%d wads were stood on it" % POUR_WADS, fed.size() == POUR_WADS)
	if fed.is_empty():
		world.builds.demolish(run)
		return


	var seqs: Array = []
	for i in 240:
		await get_tree().physics_frame
		seqs = _seqs_on(run, BeltRun.Kind.WAD) + _seqs_on(deck, BeltRun.Kind.WAD)
		if seqs.size() >= POUR_WADS:
			break
	print("  (%d of them boarded as records)" % seqs.size())


	var spat: Array = []
	var watch:= func(b: Object) -> void: spat.append(_spill_note(lift, deck, b))
	deck.handed_on.connect(watch)


	var deck_y: float = lift.global_position.y
	var floor_y: float = deck_y - Cfg.HAY_LIFT_DECK
	var spill_y:= (deck_y + floor_y) * 0.5


	var been_up: Dictionary = { }
	var spilt: Dictionary = { }
	var queued:= 0
	var held:= false
	var climbed:= 0
	var lowest:= INF
	for i in POUR_FRAMES:
		await get_tree().physics_frame
		held = held or deck._outlet_held
		queued = maxi(queued, deck.run.count() + run.run.count()
			+ deck.riders().size() + run.riders().size())
		var still:= 0
		for seq: int in seqs:
			if lift.carries(seq):
				been_up [seq] = true
				still += 1
				continue
			if been_up.has(seq):
				continue
			still += 1
		for item in world.props.items:
			if not is_instance_valid(item) or not item.is_inside_tree() or item is not HayWad or item is HayTuft:
				continue
			var local:= lift.to_local(item.global_position)
			if local.z > 0.0 or local.z < - POUR_RUN - 2.0 or absf(local.x) > 3.0:
				continue
			lowest = minf(lowest, item.global_position.y)
			if item.global_position.y < spill_y:
				spilt [item.get_instance_id()] = true
		climbed = been_up.size()
		if climbed >= seqs.size() and lift.in_transit() == 0:
			break
		if still == 0:
			break


	deck.handed_on.disconnect(watch)
	print("  (deck %.3f, floor %.3f, the line at %.3f, lowest wad %.3f)"
		% [deck_y, floor_y, spill_y, lowest])
	for note in spat:
		print("  [spilled] %s" % note)
	_ok("the infeed deck never ran a load off its own head (%d spat out)"
		% spat.size(), spat.is_empty())
	_ok("...because it held its head while the rails were full", held)
	_ok("...and nothing went on the floor at the mouth (%d of %d)"
		% [spilt.size(), fed.size()], spilt.is_empty())
	_ok("...and the wads queued up on the belt instead (%d standing at once)"
		% queued, queued >= 2)
	_ok("...and every one of them climbed in the end (%d of %d)"
		% [climbed, fed.size()], climbed == fed.size() and seqs.size() == fed.size())


	_clear_records(run)
	_sweep(lift)
	world.builds.demolish(run)
	for i in 20:
		await get_tree().physics_frame

	_ok("...and the deck lets go again once the tower drains", not deck._outlet_held)


func _check_set_on_infeed(lift: HayLift) -> void:
	print("\n=== set down on the infeed by hand ===")
	print("  (the hold-down closes %.2f m along the rails)" % lift._sink_in)
	var tight:= - HayLift.CASING * 0.5 - Cfg.WAD_BASE_SIZE.z * 0.5 - 0.03
	for z: float in [-1.4, tight]:
		var where:= "%.2f m short of the casing" % (- HayLift.CASING * 0.5 - z)
		var at:= lift.to_global(Vector3(0.0, 0.0, z)) + Vector3.UP * Cfg.WAD_BASE_SIZE.y * 0.5
		var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
			{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
		if wad == null:
			_ok("a wad set down %s was taken" % where, false)
			_ok("...without jumping when the belts took it", false)
			_ok("...or anywhere on the way up", false)
			_ok("...and it came off the top onto the discharge deck", false)
			continue


		var claimed:= false
		var claim_jump:= 0.0
		var worst_step:= 0.0
		var highest:= - INF
		var last:= wad.global_position
		var seq:= -1
		var n0:= _lifted.size()
		for i in TRANSIT_FRAMES:
			await get_tree().physics_frame
			var carried:= lift.in_transit() > 0
			var now:= last
			if carried:
				now = lift.carried_transform(0).origin
			elif is_instance_valid(wad) and wad.is_inside_tree():
				now = wad.global_position
			else:
				if _lifted.size() > n0:
					seq = int(_lifted [_lifted.size() - 1])
				elif seq < 0 and lift.deck().run.count() > 0:
					seq = lift.deck().run.last_seq
				var at_now:= _where(lift, seq) if seq >= 0 else { }
				if not at_now.is_empty() and at_now ["stage"] != "gone":
					now = at_now ["pos"]
			if carried and not claimed:
				claimed = true
				claim_jump = now.distance_to(last)
			elif carried:
				worst_step = maxf(worst_step, now.distance_to(last))
			highest = maxf(highest, now.y)
			last = now
			if claimed and not carried and _lifted.size() > n0:
				break
		_ok("a wad set down %s was taken" % where, claimed)


		_ok("...without jumping when the belts took it (%.3f m)" % claim_jump,
			claimed and claim_jump < 0.05)
		_ok("...or anywhere on the way up (worst frame %.3f m)" % worst_step,
			claimed and worst_step < 0.05)
		var out:= _where(lift, seq) if seq >= 0 else { }
		_ok("...and it came off the top onto the discharge deck",
			_lifted.size() > n0 and highest > lift.port_out().y - 0.35
				and not out.is_empty() and out ["stage"] == "out")
		_sweep(lift)
		await get_tree().physics_frame


const STRAW_DUMP:= 150
const STRAW_FRAMES:= 1800


func _check_loose_straw(lift: HayLift) -> void:
	print("\n=== loose straw tipped on the infeed ===")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var start:= _hay_total(_hay_round(lift))
	var made:= 0
	for i in STRAW_DUMP:
		var local:= Vector3(rng.randf_range(-0.25, 0.25), 0.05 + 0.003 * float(i),
			rng.randf_range(-1.6, -0.9))
		var body: RigidBody3D = world.live.spawn(lift.to_global(local),
			StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			made += 1
	_ok("%d strands were tipped on the infeed" % made, made == STRAW_DUMP)
	var cleared:= -1
	var most:= 0
	for f in STRAW_FRAMES:
		await get_tree().physics_frame
		most = maxi(most, lift.in_transit())
		if f % 120 == 0:
			print("  %5.1f s  %s  on the rails %d" % [f / 60.0, _hay_round(lift), lift.in_transit()])
		if cleared < 0 and f % 10 == 0 and int(_hay_round(lift) ["infeed"]) == 0:
			cleared = f
	var after:= _hay_round(lift)
	print("  end    %s" % after)
	_ok("the infeed was cleared (%s)" % ("after %.1f s" % (cleared / 60.0) if cleared >= 0
		else "%d strands still lying there" % int(after ["infeed"])), cleared >= 0)
	_ok("...inside twenty seconds", cleared >= 0 and cleared < 20 * 60)
	_ok("no hay was lost or made (%d before, %d after)"
		% [start + made, _hay_total(after)], _hay_total(after) == start + made)
	_ok("...and it went up as tufts (%d tufts, %d loose strands)"
		% [int(after ["tufts"]), int(after ["loose"])], int(after ["tufts"]) > 0)
	_clear_round(lift)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


const TRICKLE:= 25
const TRICKLE_EVERY:= 12


func _check_straw_trickle(lift: HayLift) -> void:
	print("\n=== straw fed a strand at a time ===")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 11
	var start:= _hay_total(_hay_round(lift))
	var made:= 0
	for i in TRICKLE:
		var body: RigidBody3D = world.live.spawn(lift.port_in() + Vector3.UP * 0.05,
			StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			made += 1
		for f in TRICKLE_EVERY:
			await get_tree().physics_frame
	var cleared:= -1
	for f in STRAW_FRAMES:
		await get_tree().physics_frame
		if f % 10 == 0 and int(_hay_round(lift) ["infeed"]) == 0:
			cleared = f
			break
	var after:= _hay_round(lift)
	print("  end    %s" % after)
	_ok("%d strands were fed in" % made, made == TRICKLE)
	_ok("the infeed was cleared after the last one (%s)" % ("%.1f s" % (cleared / 60.0)
		if cleared >= 0 else "%d still lying there" % int(after ["infeed"])),
		cleared >= 0 and cleared < 10 * 60)
	_ok("no hay was lost or made (%d before, %d after)"
		% [start + made, _hay_total(after)], _hay_total(after) == start + made)
	_clear_round(lift)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


func _check_tuft_ride(lift: HayLift) -> void:
	print("\n=== tufts up the tower ===")
	for n: int in [12, 40, 100]:
		for where: String in ["set on the infeed", "fed off the deck"]:
			await _ride_tuft(lift, n, where)


func _ride_tuft(lift: HayLift, n: int, where: String) -> void:
	var at:= lift.to_global(Vector3(0.0, 0.01, -1.4))
	if where == "fed off the deck":
		at = lift.port_in() + Vector3.UP * 0.03
	var tuft:= world.props.spawn("hay_tuft", Transform3D(Basis(), at),
		{ "strands": n }) as HayTuft
	var label:= "a %d strand tuft %s" % [n, where]
	if tuft == null:
		_ok("%s was made" % label, false)
		return
	var box:= tuft.ride_box()
	print("  %s: ride box %s, collider %s" % [label, box.size, tuft.clearance_size()])
	var claimed:= false
	var dropped:= false
	var claim_jump:= 0.0
	var worst_step:= 0.0
	var worst_turn:= 0.0
	var highest:= - INF
	var last:= tuft.global_transform
	for i in TRANSIT_FRAMES + 600:
		await get_tree().physics_frame
		if not is_instance_valid(tuft):
			break
		var now:= tuft.global_transform
		var carried:= tuft.has_meta(HayLift.META_CARRIED)
		if carried and not claimed:
			claimed = true
			claim_jump = now.origin.distance_to(last.origin)
		elif carried:
			worst_step = maxf(worst_step, now.origin.distance_to(last.origin))
			var q0:= Quaternion(last.basis.orthonormalized())
			var q1:= Quaternion(now.basis.orthonormalized())
			worst_turn = maxf(worst_turn, rad_to_deg(q0.angle_to(q1)))
		elif claimed and not BeltPath.is_rider(tuft) and highest < lift.port_out().y - 0.35:
			dropped = true
		highest = maxf(highest, now.origin.y)
		last = now
		if claimed and not carried and BeltPath.is_rider(tuft):
			break
	_ok("%s was taken" % label, claimed)
	_ok("...without jumping when the belts took it (%.3f m)" % claim_jump,
		claimed and claim_jump < 0.05)
	_ok("...or anywhere on the way up (worst frame %.3f m, %.1f deg)"
		% [worst_step, worst_turn], claimed and worst_step < 0.05 and worst_turn < 10.0)
	_ok("...and was never let go of on the way", claimed and not dropped)
	_ok("...and came off the top onto the discharge deck",
		is_instance_valid(tuft) and highest > lift.port_out().y - 0.35
			and BeltPath.is_rider(tuft))
	_ok("...still %d strands" % n, is_instance_valid(tuft) and tuft.strands == n)
	if is_instance_valid(tuft):
		world.props.remove(tuft)
	await get_tree().physics_frame


func _hay_round(lift: HayLift) -> Dictionary:
	var out:= { "infeed": 0, "rails": 0, "top": 0, "other": 0, "loose": 0, "tufts": 0 }
	for b: RigidBody3D in world.live._active:
		if is_instance_valid(b) and b.is_inside_tree() and _count_hay(out, lift, b, 1):
			out ["loose"] = int(out ["loose"]) + 1
	for item in world.props.items:
		if is_instance_valid(item) and item is HayWad and item.is_inside_tree() and _count_hay(out, lift, item, (item as HayWad).strands) and item is HayTuft:
			out ["tufts"] = int(out ["tufts"]) + 1
	return out


func _count_hay(out: Dictionary, lift: HayLift, body: Node3D, n: int) -> bool:
	var p:= lift.to_local(body.global_position)
	if absf(p.x) > 4.0 or absf(p.z) > 6.0:
		return false
	var key:= "other"
	if body.has_meta(HayLift.META_CARRIED):
		key = "rails"
	elif p.y > lift.rise() - 0.6:
		key = "top"
	elif p.y > -0.2 and p.y < 0.6 and p.z < - HayLift.CASING * 0.5 and absf(p.x) < 0.6:
		key = "infeed"
	out [key] = int(out [key]) + n
	return true


func _hay_total(h: Dictionary) -> int:
	return int(h ["infeed"]) + int(h ["rails"]) + int(h ["top"]) + int(h ["other"])


func _clear_round(lift: HayLift) -> void:
	var scratch:= { "infeed": 0, "rails": 0, "top": 0, "other": 0 }
	for b: RigidBody3D in world.live._active.duplicate():
		if is_instance_valid(b) and _count_hay(scratch, lift, b, 1):
			BeltPath.release(b)
			world.live.consume(b)
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and item is HayWad and _count_hay(scratch, lift, item, 1):
			world.props.remove(item)


func _check_containment() -> HayLift:
	print("\n=== square in the casing, on a lift that is not square to the yard ===")


	var yaw:= deg_to_rad(37.0)
	var lift: HayLift = world.builds.add_hay_lift(
		Vector3(19.0, Cfg.HAY_LIFT_DECK, -6.0), yaw, SECTIONS)
	lift.lifted_record.connect(_on_lifted)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	for id: String in ["hay_wad", "hay_bale", "foiled_bale", "paper_roll"]:
		await _ride_one(lift, id)
	return lift


func _check_motor(lift: HayLift) -> void:
	print("\n=== the same lift, on a maxed belt motor ===")
	var top:= TechTree.max_rank("belt_speed")
	Tech.grant("belt_speed", top)
	await get_tree().physics_frame
	_ok("the climb runs at the yard's belt speed (%.2f m/s at %d ranks)"
		% [lift.ride_speed(), top],
		is_equal_approx(lift.ride_speed(), Tech.belt_speed()))
	_ok("...which is well over the base machine (x%.2f)"
		% (lift.ride_speed() / Cfg.HAY_LIFT_SPEED),
		lift.ride_speed() > Cfg.HAY_LIFT_SPEED * 2.0)


	var anim: AnimationPlayer = lift._anim
	_ok("...and the drums turn with it (speed_scale x%.2f)"
		% (anim.speed_scale if anim != null else 0.0),
		anim != null and is_equal_approx(anim.speed_scale,
			lift.ride_speed() / Cfg.HAY_LIFT_SPEED))


	for id: String in ["hay_wad", "paper_roll"]:
		await _ride_one(lift, id)


	Tech.grant("belt_speed", 0)
	await get_tree().physics_frame
	_ok("the motor comes back off (%.2f m/s)" % lift.ride_speed(),
		is_equal_approx(lift.ride_speed(), Cfg.HAY_LIFT_SPEED))


func _ride_one(lift: HayLift, id: String) -> void:
	var at:= lift.port_in() + Vector3.UP * 0.06
	var item:= world.props.spawn(id, Transform3D(Basis(), at), { }) as Carryable
	if item == null:
		_ok("a %s was set on the infeed" % id, false)
		return
	var kind:= BeltRun.ITEM_IDS.find(id)
	var strands_in:= item.hay_strands()
	var n0:= _lifted.size()


	var carried:= false
	var climbed:= false


	var worst_skew:= 1.0
	var worst_across:= 0.0
	var worst_nip:= 0.0
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		if lift.in_transit() == 0:
			if carried:
				break
			continue
		carried = true
		var s: float = float((lift._carried [0] as Dictionary) ["s"])


		var fwd: Vector3 = lift.global_basis.inverse() * lift._ride_basis_at(s).z
		if fwd.y < 0.99:
			continue


		if s - lift._cum [lift._seg_at(s)] < 0.5:
			continue
		climbed = true


		var xf:= lift.carried_transform(0)
		worst_skew = minf(worst_skew,
			absf(xf.basis.x.normalized().dot(lift.global_basis.x.normalized())))
		var into:= lift.global_transform.affine_inverse() * xf
		var box:= lift.carried_box(0)
		for c in 8:
			var p: Vector3 = into * box.get_endpoint(c)
			worst_across = maxf(worst_across, absf(p.x))
			worst_nip = maxf(worst_nip, absf(p.z))

	_ok("a %s rode the tower" % id, carried and climbed)
	if not climbed:
		_sweep(lift)
		return
	_ok("...square to the casing on the climb (%.1f deg out)"
		% rad_to_deg(acos(clampf(worst_skew, -1.0, 1.0))), worst_skew > 0.999)
	_ok("...inside the flanks (%.3f of %.3f)"
		% [worst_across, HayLift.CASING * 0.5], worst_across <= HayLift.CASING * 0.5)
	_ok("...and inside the nip (%.3f of %.3f)"
		% [worst_nip, HayLift.HALF_NIP], worst_nip <= HayLift.HALF_NIP + 0.01)


	var seq:= int(_lifted [_lifted.size() - 1]) if _lifted.size() > n0 else -1
	var out:= _where(lift, seq) if seq >= 0 else { }
	_ok("...and it is its own kind and count again (%s, %d of %d)"
		% [BeltRun.ITEM_IDS [int(out.get("kind", kind))] if not out.is_empty() else "gone",
			int(out.get("strands", -1)), strands_in],
		not out.is_empty() and out ["stage"] == "out" and int(out ["kind"]) == kind
			and int(out ["strands"]) == strands_in)
	_sweep(lift)
	await get_tree().physics_frame


func _check_save(lift: HayLift) -> void:
	print("\n=== the save ===")
	var d:= lift.to_dict()
	_ok("it saves as a hay_lift", str(d.get("type", "")) == "hay_lift")
	_ok("...and carries its tower (%s)" % str(d.get("sections", "-")),
		int(d.get("sections", -1)) == SECTIONS)
	_ok("...and where it stands",
		(d.get("position", Vector3.ZERO) as Vector3).is_equal_approx(
			lift.global_position))


	var again: HayLift = world.builds.add_hay_lift(
		lift.global_position + Vector3(0.0, 0.0, 9.0),
		float(d.get("yaw", 0.0)), int(d.get("sections", 0)))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_ok("a lift rebuilt from it is the same height (%.2f vs %.2f)"
		% [again.rise(), lift.rise()], is_equal_approx(again.rise(), lift.rise()))
	_ok("...and its discharge is at the same height",
		absf((again.port_out().y - again.global_position.y)
			- (lift.port_out().y - lift.global_position.y)) < 0.01)
	_ok("...and it refunds what it cost",
		is_equal_approx(world.builds.demolish(again), HayLift.cost_for(SECTIONS)))
	await get_tree().physics_frame


	_ok("the save carries the riser (%s)" % str(d.get("riser", "-")),
		is_equal_approx(float(d.get("riser", -1.0)), HayLift.SPACER))
	var old_d:= d.duplicate()
	old_d.erase("riser")
	var old: HayLift = world.builds.add_hay_lift(
		lift.global_position + Vector3(0.0, 0.0, 9.0),
		float(old_d.get("yaw", 0.0)), int(old_d.get("sections", 0)),
		float(old_d.get("riser", 0.0)))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var old_rise:= old.port_out().y - old.port_in().y
	_ok("an old save's lift keeps 1.79 + %d (%.3f)" % [SECTIONS, old_rise],
		absf(old_rise - (Cfg.HAY_LIFT_BASE_RISE - HayLift.SPACER + float(SECTIONS))) < 0.01)
	_ok("...and carries no spacer", old._spacer == null and old.riser == 0.0)
	_ok("...and an old deck at that height still takes a lift that meets it",
		is_equal_approx(HayLift.riser_for_climb(old.rise()), 0.0)
		and HayLift.sections_reaching(old.rise(), 0.0) == SECTIONS)
	_ok("...while a whole metre takes the new one",
		is_equal_approx(HayLift.riser_for_climb(3.0), HayLift.SPACER))
	world.builds.demolish(old)
	await get_tree().physics_frame


func _check_ghost(lift: HayLift) -> void:
	print("\n=== the hologram ===")
	var ghost:= HayLift.new()
	ghost.placement_preview = true
	ghost.sections = 0
	world.add_child(ghost)
	ghost.global_position = Vector3(13.0, Cfg.HAY_LIFT_DECK, 10.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_ok("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	_ok("...and lays no belt of its own", ghost.deck() == null)
	_ok("...and claims nothing", ghost.in_transit() == 0)


	ghost.set_sections(5)
	_ok("it grows a tower on demand (%d)" % ghost._sections.size(),
		ghost._sections.size() == 5 and ghost.sections == 5)


	ghost.set_sections(0)
	_ok("...and comes back down to nothing (%d)" % ghost._sections.size(),
		ghost._sections.is_empty() and ghost.sections == 0)
	ghost.set_sections(3)
	_ok("...and grows again afterwards (%d)" % ghost._sections.size(),
		ghost._sections.size() == 3)
	_ok("...with the head still on top of it",
		absf(ghost._head.position.y - (HayLift.MODEL_DECK + HayLift.BOOT_FLANGE
			+ Cfg.HAY_LIFT_SECTION * 3.0 + HayLift.SPACER)) < 0.001)
	ghost.set_riser(0.0)
	_ok("...which drops onto the tower when it is fitted to an old deck",
		absf(ghost._head.position.y - (HayLift.MODEL_DECK + HayLift.BOOT_FLANGE
			+ Cfg.HAY_LIFT_SECTION * 3.0)) < 0.001 and not ghost._spacer.visible)
	ghost.set_riser(HayLift.SPACER)


	var bare:= 0
	var shown:= 0
	for mesh in ghost._meshes():


		if mesh.name.begins_with("GhostInfeed"):
			shown += 1
			continue
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			if mesh.get_surface_override_material(i) == null:
				bare += 1
	_ok("...and every surface skinned (%d unpainted)" % bare, bare == 0)


	var belt_ghost:= ghost.get_node_or_null("GhostBelt") as BeltGhost
	shown = belt_ghost.drawn(0) if belt_ghost != null else 0
	var laid:= ghost.belt_runs()
	var laid_length:= 0.0
	for run in laid:
		for k in run.size() - 1:
			laid_length += run [k].distance_to(run [k + 1])
	_ok("...and it shows the belts the built one lays (%d sections, %.3f m drawn, %.3f m laid)"
		% [shown, belt_ghost.drawn_length if belt_ghost != null else 0.0, laid_length],
		shown > 0 and belt_ghost != null and absf(belt_ghost.drawn_length - laid_length) < 0.01)


	var shared:= HayCompressor.materials_shared()
	var mine:= _table_mats(lift)
	var theirs:= _table_mats(ghost)
	var worn:= _worn(lift)
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
	_ok("...one per table entry, however tall either tower is",
		not mine.values().has(null) and not theirs.values().has(null))
	_ok("...and a belt of its own", ghost._belt_mat != null
		and lift._belt_mat != null and ghost._belt_mat != lift._belt_mat)
	ghost._belt_mat.set_shader_parameter("speed", 0.123)
	_ok("...whose speed does not reach the placed lift's (%.3f)"
		% float(lift._belt_mat.get_shader_parameter("speed")),
		is_equal_approx(float(lift._belt_mat.get_shader_parameter("speed")),
			lift.ride_speed()))
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


func _table_mats(lift: HayLift) -> Dictionary:
	var out:= { }
	var table: Dictionary = HayLift.spec_table().get("surfaces", { })
	for mesh in lift._meshes():
		if mesh.mesh == null or mesh.name.begins_with("GhostInfeed"):
			continue
		for i in mesh.mesh.get_surface_count():
			var m:= mesh.get_surface_override_material(i)
			if m == null or m == lift._belt_mat or not table.has(m.resource_name):
				continue
			if out.has(m.resource_name) and out [m.resource_name] != m:
				out [m.resource_name] = null
			elif not out.has(m.resource_name):
				out [m.resource_name] = m
	return out


func _check_dismantle(lift: HayLift) -> void:
	print("\n=== dismantled under its load ===")
	var seq:= await _feed_seq(lift, 0.0)
	if seq < 0:
		_ok("a wad was set on the infeed", false)
		return


	var floor_y:= lift.port_in().y
	var up:= false
	var held_at:= Vector3.ZERO
	for i in TRANSIT_FRAMES:
		await get_tree().physics_frame
		var k:= lift.row_of(seq)
		if k >= 0:
			held_at = lift.carried_transform(k).origin
			if held_at.y > floor_y + 1.5:
				up = true
				break
	_ok("the wad was carried half way up the tower", up)
	if not up:
		_sweep(lift)
		return
	var refund: float = world.builds.demolish(lift)
	_ok("the lift was dismantled under it (refund %.0f)" % refund,
		refund > 0.0 and (not is_instance_valid(lift) or lift.is_queued_for_deletion()))
	for i in 5:
		await get_tree().physics_frame


	var loose:= _wad_body_near(held_at, 0.6)
	_ok("the wad was let go of (a body where it was held)", loose != null
		and not loose.freeze and not loose.has_meta(HayLift.META_CARRIED))
	for i in 120:
		await get_tree().physics_frame
	var drop:= held_at.y - loose.global_position.y if is_instance_valid(loose) else 0.0
	_ok("...and fell (%.2f m down)" % drop, drop > 0.5)
	if is_instance_valid(loose):
		world.props.remove(loose)
	await get_tree().physics_frame


func _feed(lift: HayLift, back: float) -> HayWad:
	var at:= lift.port_in() + lift.forward() * back + Vector3.UP * Cfg.WAD_BASE_SIZE.y * 0.5
	return world.props.spawn("hay_wad", Transform3D(Basis(), at),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad


func _feed_seq(lift: HayLift, back: float) -> int:
	var deck:= lift.deck()
	var wad:= _feed(lift, back)
	if wad == null or deck == null:
		return -1
	for i in 120:
		await get_tree().physics_frame
		if not is_instance_valid(wad):
			return deck.run.last_seq
	return -1


func _on_lifted(seq: int) -> void:
	_lifted.append(seq)


func _where(lift: HayLift, seq: int) -> Dictionary:
	var k:= lift.row_of(seq)
	if k >= 0:
		var rec:= lift.carried_record(k)
		return { "stage": "rails", "pos": lift.carried_transform(k).origin,
			"kind": int(rec ["kind"]), "strands": int(rec ["strands"]), "as": "record" }
	var w:= BeltPath.record_where(seq)
	if not w.is_empty():
		var path: BeltPath = w ["path"]
		var row:= int(w ["row"])
		var stage:= "belt"
		if path == lift.deck():
			stage = "deck"
		elif path == lift.outfeed_deck():
			stage = "out"
		return { "stage": stage, "pos": (w ["pose"] as Transform3D).origin,
			"kind": path.run.kind_of(row), "strands": path.run.strands_of(row), "as": "record" }
	if lift.outfeed_deck() != null:
		for rb in lift.outfeed_deck().riders():
			var item:= rb as Carryable
			if item == null or rb is HayTuft or not BeltRun.ITEM_IDS.has(item.item_id):
				continue
			return { "stage": "out", "pos": rb.global_position,
				"kind": BeltRun.ITEM_IDS.find(item.item_id), "strands": item.hay_strands(),
				"as": "body" }
	return { "stage": "gone" }


func _wads_everywhere(lift: HayLift) -> int:
	var n:= _wads().size()
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		n += _records_on(path, BeltRun.Kind.WAD)
	if is_instance_valid(lift):
		n += lift.carried_count(BeltRun.Kind.WAD)
	return n


func _records_on(path: BeltPath, kind: int) -> int:
	var run: BeltRun = path.run
	var n:= 0
	for i in range(run.first(), run.first() + run.count()):
		if run.kind_of(i) == kind:
			n += 1
	return n


func _seqs_on(path: BeltPath, kind: int) -> Array:
	var out: Array = []
	var run: BeltRun = path.run
	for i in range(run.first(), run.first() + run.count()):
		if run.kind_of(i) == kind:
			out.append(run.seq_of(i))
	return out


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


func _sweep(lift: HayLift) -> void:
	if not is_instance_valid(lift):
		return
	for deck in [lift.deck(), lift.outfeed_deck()]:
		_clear_records(deck)
	for item in world.props.items.duplicate():
		if not is_instance_valid(item) or not item.is_inside_tree():
			continue
		var p:= lift.to_local(item.global_position)
		if absf(p.x) < 4.0 and absf(p.z) < 10.0:
			world.props.remove(item)


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


func _deck_ends(path: BeltPath) -> Array [Vector3]:
	var line:= path._line
	if line.size() < 2:
		return [Vector3.ZERO, Vector3.ZERO] as Array [Vector3]
	return [line [0], line [line.size() - 1]] as Array [Vector3]


func _look_at(eye: Vector3, spot: Vector3) -> void:
	var flat:= Vector3(spot.x - eye.x, 0.0, spot.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(spot.y - eye.y, maxf(flat.length(), 0.001))
	player.velocity = Vector3.ZERO


func _wads() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayWad:
			out.append(item)
	return out


func _ok(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _spill_note(lift: HayLift, deck: BeltPath, b: Object) -> String:
	var lowest:= INF
	for r in lift._carried:
		lowest = minf(lowest, float(r ["s"]))
	var rb:= b as RigidBody3D
	return "held=%s carrying=%d lowest=%.3f mouth=%d body=%s claimed=%s riding=%s" % [
		deck._outlet_held, lift.in_transit(), lowest,
		lift._mouth.get_overlapping_bodies().size() if lift._mouth != null else -1,
		rb.name if rb != null else "?",
		rb != null and rb.has_meta(HayLift.META_CARRIED),
		rb != null and BeltPath.is_rider(rb)]
