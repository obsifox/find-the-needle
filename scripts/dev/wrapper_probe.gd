class_name DevWrapperProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const TEST_STRANDS:= 83

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var feed_a:= Vector3(13.0, deck_y, -7.0)
	var feed_b:= Vector3(13.0, deck_y, -1.0)
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(20000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== model ===")
	var wrap: HayWrapper = world.builds.add_wrapper(
		feed_b + Vector3(0, 0, Cfg.WRAPPER_LENGTH * 0.5), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	_check("model instantiated", wrap.get_node_or_null("Model") != null)
	for marker in ["Marker_BeltIn", "Marker_BeltOut", "Marker_BaleOut",
			"Marker_Station", "Marker_Panel"]:
		_check("marker %s" % marker, wrap._find(marker) != null)


	for part in ["Wrapper_Ring", "Wrapper_Roll0", "Wrapper_Roll1",
			"Wrapper_Web0", "Wrapper_Web1",
			"Wrapper_Pinch0", "Wrapper_Pinch1", "Wrapper_Cutter",
			"Wrapper_Motor", "Wrapper_Film", "Wrapper_Bale", "Wrapper_Foiled"]:
		_check("moving part %s" % part, wrap._find(part) != null)


	for orbit_name in ["Wrapper_Roll0", "Wrapper_Roll1",
			"Wrapper_Web0", "Wrapper_Web1"]:
		var part_ob:= wrap._find(orbit_name) as Node3D
		var ring:= wrap._find("Wrapper_Ring") as Node3D
		_check("%s orbits with the ring" % orbit_name,
			part_ob != null and ring != null and part_ob.get_parent() == ring)


	_check("wrap clip found", wrap._find_clip() != null)
	var visibility_tracks:= 0
	for track in wrap._find_clip().get_track_count():
		if wrap._find_clip().track_get_type(track) == Animation.TYPE_VALUE and String(wrap._find_clip().track_get_path(track)).ends_with(":visible"):
			visibility_tracks += 1
	_check("collapsed animation props leave the render lists", visibility_tracks == 3)
	_check("the ring is parked, not turning",
		wrap._anim != null and not wrap._anim.is_playing())


	var idle_bale:= wrap._find("Wrapper_Bale") as Node3D
	_check("an idle wrapper stands empty",
		idle_bale != null and not idle_bale.visible)


	_check("driven lamp resolved", not wrap._go_meshes.is_empty())
	var body:= wrap._find("HayWrapperBody") as MeshInstance3D
	_check("textured body keeps its three shared surfaces", body != null and body.mesh.get_surface_count() == 3)
	var detailed:= false
	for surface in body.mesh.get_surface_count():
		var palette:= body.get_active_material(surface) as ShaderMaterial
		if palette == null or not palette.get_meta("immutable_palette", false):
			continue
		detailed = palette.shader.resource_path == "res://assets/shaders/wrapper_palette.gdshader"
		for finish in ["paint", "steel", "rubber"]:
			var texture: Texture2D = palette.get_shader_parameter(finish + "_detail")
			_check("%s detail is shared, mipmapped and bounded to 512 pixels" % finish,
				texture != null and texture.get_size() == Vector2(512, 512) and texture.get_image().has_mipmaps())
	_check("wrapper retains photographic palette finishes after skinning", detailed)
	var film_mesh:= FoiledBale.shared_mesh()
	_check("finished wrap has only core and film surfaces", film_mesh != null and film_mesh.get_surface_count() == 2)
	var film_instance:= MeshInstance3D.new()
	film_instance.mesh = film_mesh
	FoiledBale.skin(film_instance)
	var film_material: StandardMaterial3D = null
	for surface in film_mesh.get_surface_count():
		var candidate:= film_instance.get_active_material(surface) as StandardMaterial3D
		if candidate != null and candidate.resource_name == "M_HW_Film":
			film_material = candidate
	_check("finished film is translucent", film_material != null and film_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and film_material.albedo_color.a > 0.2 and film_material.albedo_color.a < 0.8)
	_check("the closed film culls its back wall", film_material != null and film_material.cull_mode == BaseMaterial3D.CULL_BACK)
	_check("film wrinkles use a shared normal map", film_material != null and film_material.normal_texture != null)
	_check("both film dispensers have cutting jaws", wrap._find("Wrapper_Cutter1") != null)
	var lay_mesh:= wrap._find("Wrapper_Film") as MeshInstance3D
	_check("film coverage is animated on one surface", lay_mesh != null and lay_mesh.mesh.get_surface_count() == 1 and lay_mesh.mesh.get_blend_shape_count() == 16)
	_check("imported film bounds remain inside the bale envelope", lay_mesh != null and lay_mesh.mesh.get_aabb().size.length() < 1.2)
	var web_mesh:= wrap._find("Wrapper_Web0") as MeshInstance3D
	_check("sheet extension uses a stable morph", web_mesh != null and web_mesh.mesh.get_blend_shape_count() == 1 and web_mesh.scale.is_equal_approx(Vector3.ONE))
	film_instance.free()
	for i in 2:
		_check("nip %d has a separate lifting support" % i, wrap._find("Wrapper_PinchSupport%d" % i) != null)
		var barrel:= wrap._find("Wrapper_Pinch%d" % i) as MeshInstance3D
		var barrel_size:= barrel.mesh.get_aabb().size
		_check("nip %d spins only its cylindrical barrel" % i, barrel_size.y < 0.18 and barrel_size.z < 0.18)

	print("\n=== the hologram ===")
	var ghost:= HayWrapper.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = wrap.global_position + Vector3(0, 0, 6.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the ghost draws belt through itself", ghost._ghost_belt != null)
	_check("...and chevrons along it",
		ghost._ghost_flow != null
			and ghost._ghost_flow.multimesh.visible_instance_count > 0)


	var drawn:= 0.0
	if ghost._ghost_belt != null:
		drawn = ghost._ghost_belt.drawn_length
	var laid:= wrap.deck().path_length()
	_check("the ghost draws the belt the machine lays (%.3f m drawn, %.3f m laid)"
		% [drawn, laid], absf(drawn - laid) < 0.01)
	_check("...with its rails", ghost._ghost_belt != null
		and ghost._ghost_belt.drawn(BeltGhost.RAIL_L) > 0)


	for node_name: String in HayWrapper.CLIP_PROPS:
		var shipped:= ghost._find(node_name) as Node3D
		_check("the ghost hides %s" % node_name,
			shipped != null and not shipped.visible)
	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_check("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	_check("...and lays no belt path of its own", ghost.deck() == null)


	var shared:= HayCompressor.materials_shared()
	var worn:= not ghost._go_meshes.is_empty() and not wrap._go_meshes.is_empty()
	if worn:
		var a: MeshInstance3D = wrap._go_meshes [0]
		var b: MeshInstance3D = ghost._go_meshes [0]
		for s in a.mesh.get_surface_count():
			var mine:= a.get_surface_override_material(s)
			if mine != null and (mine == b.get_surface_override_material(s)) != shared:
				worn = false
	_check("the ghost wears %s materials" % ("the same" if shared else "its own"), worn)
	_check("...and the placed wrapper's lamp is not lit on it (%.2f, ghost %.2f)"
		% [wrap.go_energy(), ghost.go_energy()],
		wrap.go_energy() >= 0.0 and ghost.go_energy() < 0.0)
	world.remove_child(ghost)
	ghost.queue_free()

	print("\n=== geometry ===")
	var span:= wrap.port_in().distance_to(wrap.port_out())
	_check("ports %.2f m apart (want %.2f)" % [span, Cfg.WRAPPER_LENGTH],
		absf(span - Cfg.WRAPPER_LENGTH) < 0.02)
	_check("infeed port on the deck plane (%.3f vs %.3f)"
		% [wrap.port_in().y, deck_y], absf(wrap.port_in().y - deck_y) < 0.02)


	_check("travel is +Z as placed", wrap.forward().dot(Vector3.BACK) > 0.99)
	var out_at:= wrap.to_global(wrap._marker_local("Marker_BaleOut", Vector3.ZERO))
	_check("the product drop is downstream of centre",
		(out_at - wrap.global_position).dot(wrap.forward()) > 0.3)


	var lowest:= 1000000000.0
	for n in wrap.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		var box:= mi.get_aabb()
		lowest = minf(lowest, mi.to_global(box.position).y)
	_check("nothing reaches the floor of a ground-level run (lowest %.3f, floor %.3f)"
		% [lowest, wrap.global_position.y - deck_y],
		lowest > wrap.global_position.y - deck_y)

	print("\n=== it stands on its own legs ===")


	for socket: String in HayWrapper.LEG_MARKERS:
		_check("leg socket %s" % socket, wrap._find(socket) != null)
	wrap.refresh_supports()
	for i in 4:
		await get_tree().physics_frame
	var legs:= 0
	var feet:= 0
	var supports:= wrap.get_node_or_null("Supports")
	if supports != null:
		for n in supports.get_children():
			var mmi:= n as MultiMeshInstance3D
			if mmi == null or mmi.multimesh == null:
				continue
			if mmi.name == "Legs":
				legs = mmi.multimesh.instance_count
			elif mmi.name == "Feet":
				feet = mmi.multimesh.instance_count

	_check("eight trestles raised, four of them the gantry's own (%d)" % legs,
		legs == 8)
	_check("...and a foot under every one (%d)" % feet, feet == legs)


	var offsets: Array [float] = []
	for top: Vector3 in wrap.support_tops():
		offsets.append((top - wrap.global_position).dot(wrap.global_basis.x))
	offsets.sort()
	var shown:= ""
	for off: float in offsets:
		shown += "%.2f " % off
	print("    leg offsets across the run: %s" % shown)
	var outboard:= 0
	for off: float in offsets:
		if absf(off) > Cfg.BELT_WIDTH * 0.5 + 0.2:
			outboard += 1
	_check("eight legs are wanted, and drawn (%d wanted, %d drawn)"
		% [offsets.size(), legs], offsets.size() == 8 and legs == 8)
	_check("four of them stand outboard, at the gantry posts (%d)" % outboard,
		outboard == 4)

	_check("...and four under the deck, carrying the belt (%d)"
		% (offsets.size() - outboard), offsets.size() - outboard == 4)

	print("\n=== snapping ===")

	for port: Vector3 in [wrap.port_in(), wrap.port_out()]:
		var near:= port + Vector3(0.35, 0.0, 0.4)
		var snapped: Vector3 = world.builds.snap_endpoint(near)
		_check("a belt end near a port snaps onto it (off by %.3f m)"
			% snapped.distance_to(port), snapped.is_equal_approx(port))
	var far:= wrap.port_out() + Vector3(4.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second wrapper on the same spot is refused",
		world.builds.wrapper_overlap(wrap.global_position))


	var wfwd: Vector3 = wrap.forward()
	var wx:= Vector3(wfwd.z, 0.0, - wfwd.x)
	var wpos: Vector3 = wrap.global_position
	for turn: float in [1.0, -1.0]:
		_check("a wrapper 2.00 m off either flank fits (%s)"
			% ("same way round" if turn > 0.0 else "facing it"),
			not world.builds.wrapper_overlap(wpos + wx * 2.0, wfwd * turn)
			and not world.builds.wrapper_overlap(wpos - wx * 2.0, wfwd * turn))
		_check("...but not 1.90 m off",
			world.builds.wrapper_overlap(wpos + wx * 1.9, wfwd * turn)
			and world.builds.wrapper_overlap(wpos - wx * 1.9, wfwd * turn))


	_check("a press on the same spot is refused too",
		world.builds.compressor_overlap(wrap.global_position))
	_check("...and a scanner", world.builds.scanner_overlap(wrap.global_position))

	print("\n=== the line runs through it ===")
	world.builds.add_conveyor(feed_a, wrap.port_in())
	var out_end:= wrap.port_out() + Vector3(0, 0, 6.0)
	world.builds.add_conveyor(wrap.port_out(), out_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the module's deck knows what comes after it",
		wrap.deck() != null and wrap.deck().downstream != null)
	var sections:= 0
	for n in wrap.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi:= n as MultiMeshInstance3D
		if mmi.name == "Sections" and mmi.multimesh != null:
			sections += mmi.multimesh.instance_count
	_check("the placed module draws its own belt (%d sections)" % sections,
		sections > 0)
	for side in [-1, 1]:
		var rail_runs:= wrap.deck()._closed_runs(side, 0.0, Cfg.WRAPPER_LENGTH)
		_check("side %d rails clear the rotating dispensers and retain port guides" % side,
			rail_runs.size() == 2 and is_equal_approx(rail_runs [0].y, 0.2) and is_equal_approx(rail_runs [1].x, Cfg.WRAPPER_LENGTH - 0.2))

	var step:= maxf(get_physics_process_delta_time(), 1e-06)


	print("\n=== the clip is the clock ===")
	var clip:= wrap._find_clip()
	_check("the clip imported", clip != null)
	if clip != null:
		var want:= Cfg.WRAPPER_SECONDS
		var frame:= 1.0 / HayWrapper.CLIP_FPS
		_check("the clip is %.2f s, and Cfg says %.2f s (within a frame)"
			% [clip.length, want], absf(clip.length - want) <= frame * 1.5)
	_check("Cfg.WRAPPER_SECONDS is the frame count over the fps (%.3f vs %.3f)"
		% [Cfg.WRAPPER_SECONDS, HayWrapper.CYCLE_FRAMES / HayWrapper.CLIP_FPS],
		absf(Cfg.WRAPPER_SECONDS - HayWrapper.CYCLE_FRAMES / HayWrapper.CLIP_FPS) < 0.0001)


	_check("the hand-over frame is inside the clip (%.0f of %.0f)"
		% [HayWrapper.F_RELEASE, HayWrapper.CYCLE_FRAMES],
		HayWrapper.F_RELEASE <= HayWrapper.CYCLE_FRAMES)


	print("\n=== a bale rides in on the belt ===")
	var far_bale: HayBale = world.props.spawn("hay_bale",
		Transform3D(Basis(), feed_a + wrap.forward() * 0.6 + Vector3.UP * 0.08)) as HayBale
	if far_bale != null:
		far_bale.strands = TEST_STRANDS


	var rode:= 0.0
	var arrived:= false
	while rode < 40.0:
		await get_tree().physics_frame
		rode += step
		if not wrap.queued.is_empty() or wrap.is_wrapping():
			arrived = true
			break
	_check("a bale laid on the run reached the mouth on its own (%.1f s)" % rode,
		arrived)
	_check("...and the machine took it", not wrap.queued.is_empty() or wrap.is_wrapping())

	var settle:= 0.0
	while settle < 20.0 and (wrap.is_wrapping() or not wrap.queued.is_empty()):
		await get_tree().physics_frame
		settle += step
	_clear_kind("foiled_bale")
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	print("\n=== one bale in, one foiled bale out ===")
	_drop_bale(wrap, TEST_STRANDS)
	var elapsed:= 0.0
	var saw_wrapping:= false
	var saw_playing:= false


	var ring:= wrap._find("Wrapper_Ring") as Node3D
	var ring_from:= ring.rotation.y if ring != null else 0.0
	var ring_turned:= 0.0
	var ring_last:= ring_from
	while elapsed < 30.0:
		await get_tree().physics_frame
		elapsed += step
		if wrap.is_wrapping():
			saw_wrapping = true
			if wrap._anim != null and wrap._anim.is_playing():
				saw_playing = true
		if ring != null:


			var d:= wrapf(ring.rotation.y - ring_last, - PI, PI)
			ring_turned += absf(d)
			ring_last = ring.rotation.y
		if _count("foiled_bale") >= 1 and not wrap.is_wrapping():
			break
	_check("the machine ran a cycle", saw_wrapping)


	_check("...and the clip played while it did", saw_playing)
	_check("...and the ring turned (%.0f deg)" % rad_to_deg(ring_turned),
		ring_turned > TAU * 2.0)
	_check("exactly one foiled bale came out (%d)" % _count("foiled_bale"),
		_count("foiled_bale") == 1)
	_check("no bare bale is left over (%d)" % _count("hay_bale"), _count("hay_bale") == 0)


	var done_bale:= wrap._find("Wrapper_Bale") as Node3D
	_check("...and the clip's own bale went with it",
		done_bale != null and (wrap.is_wrapping() or not done_bale.visible))


	var product: FoiledBale = null
	var product_seq:= _seq_of("foiled_bale")
	var product_where:= BeltPath.record_where(product_seq) if product_seq >= 0 else { }
	if not product_where.is_empty():
		product = (product_where ["path"] as BeltPath).materialize_record(
			int(product_where ["row"])) as FoiledBale
	elif not _foiled().is_empty():
		product = _foiled() [0]
	_check("the product carries the bale's own count (%d, want %d)"
		% [product.strands if product != null else -1, TEST_STRANDS],
		product != null and product.strands == TEST_STRANDS)


	if product != null:
		var bare:= float(TEST_STRANDS) * Tech.bale_value_ratio()
		_check("...and is worth more than the bare bale was (%.1f vs %.1f)"
			% [product.sale_strands(), bare], product.sale_strands() > bare)
		_check("...and still reports the hay actually in it (%d)"
			% product.hay_strands(), product.hay_strands() == TEST_STRANDS)


	print("\n=== it refuses what it made ===")


	if product != null:
		var mouth:= wrap.port_in() + wrap.forward() * 0.4
		product.global_position = mouth + Vector3.UP * 0.05
		product.linear_velocity = Vector3.ZERO
		var queued_was:= wrap.queued.size()
		var watched:= 0.0
		while watched < 3.0:
			await get_tree().physics_frame
			watched += step


		_check("a foiled bale at the mouth is not swallowed",
			wrap.queued.size() == queued_was and _count("foiled_bale") == 1)
		_clear_kind("foiled_bale")
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame


	print("\n=== a wad rides straight through ===")
	var wad: HayWad = world.props.spawn("hay_wad",
		Transform3D(Basis(), feed_a + wrap.forward() * 0.6 + Vector3.UP * 0.1),
		{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
	_check("a wad to test with", wad != null)
	if wad != null:
		var wad_queue:= wrap.queued.size()
		var wad_ran:= 0.0
		var wad_far:= -1000000000.0
		var stalled:= 0.0
		var last_far:= -1000000000.0


		var wad_seq:= -1
		var wad_gone:= false
		while wad_ran < 30.0:
			await get_tree().physics_frame
			wad_ran += step
			if wad_seq < 0:
				wad_seq = _seq_of("hay_wad")
			var along:= _along(wad_seq, "hay_wad", wrap.port_in(), wrap.forward())
			if is_nan(along):
				wad_gone = true
				break
			wad_far = maxf(wad_far, along)


			if along < last_far + 0.01:
				stalled += step
			else:
				stalled = 0.0
				last_far = along
		var eaten:= wad_gone
		print("  deepest into the module : %.2f m of %.2f"
			% [wad_far, Cfg.WRAPPER_LENGTH])
		print("  longest it stood still  : %.1f s" % stalled)
		print("  the queue took it       : %s" % str(wrap.queued.size() != wad_queue))
		_check("the machine did not swallow it", not eaten
			and wrap.queued.size() == wad_queue)
		_check("...and it rode out the far side (%.2f m of a %.2f m module)"
			% [wad_far, Cfg.WRAPPER_LENGTH], wad_far > Cfg.WRAPPER_LENGTH)
		_clear_kind("hay_wad")
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame


	var hand: HayWad = world.props.spawn("hay_wad",
		Transform3D(Basis(), wrap.port_in()
			+ wrap.forward() * (HayWrapper.INTAKE_LENGTH * 0.5)
			+ Vector3.UP * 0.05),
		{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
	if hand != null:
		var hand_ran:= 0.0
		var hand_far:= -1000000000.0
		var hand_seq:= -1
		while hand_ran < 20.0:
			await get_tree().physics_frame
			hand_ran += step
			if hand_seq < 0:
				hand_seq = _seq_of("hay_wad")
			var along:= _along(hand_seq, "hay_wad", wrap.port_in(), wrap.forward())
			if is_nan(along):
				break
			hand_far = maxf(hand_far, along)
		print("  set down IN the mouth, it got: %.2f m" % hand_far)
		_check("a wad put down in the mouth rides out of it too (%.2f m of %.2f)"
			% [hand_far, Cfg.WRAPPER_LENGTH], hand_far > Cfg.WRAPPER_LENGTH)
		_clear_kind("hay_wad")
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame


	print("\n=== backpressure ===")
	_check("the deck is open while there is room",
		wrap.deck() != null and not wrap.deck().is_blocked())


	_drop_bale(wrap, TEST_STRANDS)
	var spun:= 0.0
	while spun < 8.0 and not wrap.is_wrapping():
		await get_tree().physics_frame
		spun += step
	_check("the machine is busy before the queue is filled", wrap.is_wrapping())
	wrap.queued.clear()
	for i in wrap.buffer_capacity():
		wrap.queued.append(TEST_STRANDS)
	_check("a full queue reports full", wrap.is_full())
	for i in 4:
		await get_tree().physics_frame
	_check("...and closes the module's own deck",
		wrap.deck() != null and wrap.deck().is_blocked())
	wrap.queued.clear()
	for i in 4:
		await get_tree().physics_frame
	_check("...and opens it again when it drains",
		wrap.deck() != null and not wrap.deck().is_blocked())


	var drain:= 0.0
	while drain < 12.0 and wrap.is_wrapping():
		await get_tree().physics_frame
		drain += step
	_clear_kind("foiled_bale")
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	print("\n=== a blocked outfeed ===")


	var blocker: FoiledBale = world.props.spawn("foiled_bale",
		Transform3D(Basis(), out_at + Vector3.UP * 0.05)) as FoiledBale
	if blocker != null:
		blocker.freeze = true
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		var before:= _count("foiled_bale")
		_drop_bale(wrap, TEST_STRANDS)
		var held:= 0.0
		while held < 12.0:
			await get_tree().physics_frame
			held += step
		_check("nothing new is set down on a blocked outfeed (%d, was %d)"
			% [_count("foiled_bale"), before], _count("foiled_bale") == before)
		_check("...and the machine says so",
			wrap.alert_reason().begins_with("OUTFEED BLOCKED"))


		world.props.remove(blocker)
		var freed:= 0.0
		while freed < 12.0:
			await get_tree().physics_frame
			freed += step
			if _count("foiled_bale") > before - 1:
				break
		_check("...and it ships the moment the deck clears (%d)" % _count("foiled_bale"),
			_count("foiled_bale") >= before)


	print("\n=== full, it holds what it cannot wrap ===")


	_drop_bale(wrap, TEST_STRANDS)
	spun = 0.0
	while spun < 8.0 and not wrap.is_wrapping():
		await get_tree().physics_frame
		spun += step
	wrap.queued.clear()
	for i in wrap.buffer_capacity():
		wrap.queued.append(TEST_STRANDS)
	for i in 4:
		await get_tree().physics_frame
	_check("the queue is full and the mouth is shut",
		wrap.is_full() and wrap.deck() != null and wrap.deck().is_blocked())
	var bare_before:= _count("hay_bale")
	_drop_bale(wrap, TEST_STRANDS)
	var leaked:= 0
	var watched:= 0.0
	while watched < 8.0:
		await get_tree().physics_frame
		watched += step
		for at: Vector3 in _positions_of("hay_bale"):
			if (at - wrap.port_out()).dot(wrap.forward()) > 0.05:
				leaked += 1


	var parked:= _holds_record(wrap.deck(), "hay_bale")
	for r in wrap.deck().riders():
		if r is HayBale:
			parked = true
	_check("nothing rides through a full wrapper unwrapped (%d steps past the outfeed)"
		% leaked, leaked == 0)


	_check("...the bale was held over the mouth or eaten by it",
		parked or _count("hay_bale") <= bare_before)


	_clear_kind("hay_bale")
	wrap.queued.clear()
	for i in wrap.buffer_capacity():
		wrap.queued.append(TEST_STRANDS)
	for i in 4:
		await get_tree().physics_frame
	var jam: HayWad = world.props.spawn("hay_wad",
		Transform3D(Basis(), wrap.port_in()
			+ wrap.forward() * (HayWrapper.INTAKE_LENGTH * 0.5)
			+ Vector3.UP * 0.05),
		{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
	if jam != null:
		var jam_ran:= 0.0
		var jam_far:= -1000000000.0
		var jam_seq:= -1
		while jam_ran < 12.0:
			await get_tree().physics_frame
			jam_ran += step


			while wrap.queued.size() < wrap.buffer_capacity():
				wrap.queued.append(TEST_STRANDS)
			if jam_seq < 0:
				jam_seq = _seq_of("hay_wad")
			var along:= _along(jam_seq, "hay_wad", wrap.port_in(), wrap.forward())
			if is_nan(along):
				break
			jam_far = maxf(jam_far, along)
		print("  a wad in a FULL wrapper got: %.2f m of %.2f"
			% [jam_far, Cfg.WRAPPER_LENGTH])
		_check("a full wrapper still lets a wad past (%.2f m of %.2f)"
			% [jam_far, Cfg.WRAPPER_LENGTH], jam_far > Cfg.WRAPPER_LENGTH)
		_clear_kind("hay_wad")


	var up: HayWad = world.props.spawn("hay_wad",
		Transform3D(Basis(), feed_a + wrap.forward() * 0.6 + Vector3.UP * 0.1),
		{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
	if up != null:
		var up_ran:= 0.0
		var up_far:= -1000000000.0
		var up_seq:= -1
		while up_ran < 25.0:
			await get_tree().physics_frame
			up_ran += step
			while wrap.queued.size() < wrap.buffer_capacity():
				wrap.queued.append(TEST_STRANDS)
			if up_seq < 0:
				up_seq = _seq_of("hay_wad")
			var along:= _along(up_seq, "hay_wad", wrap.port_in(), wrap.forward())
			if is_nan(along):
				break
			up_far = maxf(up_far, along)
		print("  a wad fed INTO a full wrapper got: %.2f m of %.2f"
			% [up_far, Cfg.WRAPPER_LENGTH])
		_check("...and one arriving off the run gets through it too (%.2f m)"
			% up_far, up_far > Cfg.WRAPPER_LENGTH)
		_clear_kind("hay_wad")

	wrap.queued.clear()
	drain = 0.0
	while drain < 20.0 and (wrap.is_wrapping() or not wrap.queued.is_empty()):
		await get_tree().physics_frame
		drain += step
	_clear_kind("foiled_bale")
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	print("\n=== Faster Wrapper ===")
	var speed_had:= Tech.rank_of("wrapper_speed")
	Tech.grant("wrapper_speed", TechTree.max_rank("wrapper_speed"))
	var want_cycle:= Tech.wrapper_seconds()
	_drop_bale(wrap, TEST_STRANDS)
	var waited:= 0.0
	while waited < 20.0 and not wrap.is_wrapping():
		await get_tree().physics_frame
		waited += step
	var cycle:= 0.0
	var clip_rate:= 0.0
	while cycle < 20.0 and wrap.is_wrapping():
		if wrap._anim != null:
			clip_rate = wrap._anim.speed_scale
		await get_tree().physics_frame
		cycle += step
	_check("a full rank wrap takes %.2f s (%.2f)" % [want_cycle, cycle],
		absf(cycle - want_cycle) < 0.1)
	_check("...and the clip plays at the same rate (%.3f vs %.3f)"
		% [clip_rate, Tech.wrapper_speed()],
		absf(clip_rate - Tech.wrapper_speed() * wrap.power) < 0.001)
	_check("...and one foiled bale came out of it (%d)" % _count("foiled_bale"),
		_count("foiled_bale") == 1)
	Tech.grant("wrapper_speed", speed_had)
	_clear_kind("foiled_bale")
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	print("\n=== save ===")
	_clear_kind("foiled_bale")
	wrap.queued.clear()
	wrap.queued.append(41)
	wrap.queued.append(62)
	var port_was:= wrap.port_in()
	var row:= wrap.to_dict()
	_check("the save names the type", row.get("type", "") == "hay_wrapper")
	var saved: Array = row.get("queued", [])
	_check("the save carries the queue (%s)" % str(saved),
		saved.size() == 2 and int(saved [0]) == 41 and int(saved [1]) == 62)
	var rows: Array = world.builds.to_array()
	world.builds.from_array(rows)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var reloaded: HayWrapper = world.builds.wrappers [0] if not world.builds.wrappers.is_empty() else null
	_check("the wrapper came back", reloaded != null)


	var held:= 0
	var head:= -1
	if reloaded != null:
		held = reloaded.queued.size() + (1 if reloaded.is_wrapping() else 0)
		head = reloaded._batch if reloaded.is_wrapping() else (
			reloaded.queued [0] if not reloaded.queued.is_empty() else -1)
	_check("...holding both bales still (%d)" % held, held == 2)
	_check("...and it took 41 first, not 62 (%d)" % head, head == 41)
	_check("...and its ports where they were",
		reloaded != null and reloaded.port_in().distance_to(port_was) < 0.02)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _drop_bale(wrap: HayWrapper, strands: int) -> void:
	var at:= wrap.port_in() + wrap.forward() * (HayWrapper.INTAKE_LENGTH * 0.5)
	var bale: HayBale = world.props.spawn("hay_bale",
		Transform3D(Basis(), at + Vector3.UP * 0.05)) as HayBale
	if bale != null:
		bale.strands = strands


func _bales() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayBale:
			out.append(item)
	return out


func _foiled() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is FoiledBale:
			out.append(item)
	return out


func _count(id: String) -> int:
	var n:= 0
	for item in world.props.items:
		if is_instance_valid(item) and item.is_inside_tree() and item.item_id == id:
			n += 1
	return n + _records_of(id).size()


func _records_of(id: String) -> Array:
	var out: Array = []
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
				out.append(run.seq_of(i))
	return out


func _seq_of(id: String) -> int:
	var recs:= _records_of(id)
	return int(recs [0]) if not recs.is_empty() else -1


func _positions_of(id: String) -> Array [Vector3]:
	var out: Array [Vector3] = []
	for item in world.props.items:
		if is_instance_valid(item) and item.is_inside_tree() and item.item_id == id:
			out.append((item as Node3D).global_position)
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
				out.append(run.pose_of(i).origin)
	return out


func _along(seq: int, id: String, origin: Vector3, axis: Vector3) -> float:
	var where:= BeltPath.record_where(seq) if seq >= 0 else { }
	if not where.is_empty():
		return ((where ["pose"] as Transform3D).origin - origin).dot(axis)
	for item in world.props.items:
		if is_instance_valid(item) and item.is_inside_tree() and item.item_id == id:
			return ((item as Node3D).global_position - origin).dot(axis)
	return NAN


func _clear_kind(id: String) -> void:
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and item.item_id == id:
			world.props.remove(item)
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		var i:= run.first() + run.count() - 1
		while i >= run.first():
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:


				var was_head:= i == run.first()
				run.remove_at(i)
				if was_head:
					break
			i -= 1


func _holds_record(path: BeltPath, id: String) -> bool:
	var run: BeltRun = path.run
	for i in range(run.first(), run.first() + run.count()):
		if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
			return true
	return false


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
