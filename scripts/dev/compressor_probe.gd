class_name DevCompressorProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0


func run() -> void:
	_rng.seed = 20260823
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
	var press: HayCompressor = world.builds.add_compressor(
		feed_b + Vector3(0, 0, Cfg.COMPRESSOR_LENGTH * 0.5), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	_check("model instantiated", press.get_node_or_null("Model") != null)
	for marker in ["Marker_BeltIn", "Marker_BeltOut", "Marker_BaleOut",
			"Marker_Panel"]:
		_check("marker %s" % marker, press._find(marker) != null)
	for part in ["Compressor_Ram", "Compressor_Door", "Compressor_Charge",
			"Compressor_Flywheel"]:
		_check("moving part %s" % part, press._find(part) != null)


	_check("press clip found", press._find_clip() != null)
	_check("the press is parked, not running",
		press._anim != null and not press._anim.is_playing())


	_check("driven lamp resolved", not press._go_meshes.is_empty())
	if not press._go_meshes.is_empty():


		_check("parked lamp is dim",
			is_equal_approx(press.go_energy(), HayCompressor.GO_IDLE))
		press.set_power(0.0)
		_check("unpowered lamp is dark", press.go_energy() == 0.0)
		press.set_power(1.0)
		press.set_switched_off(true)
		_check("switched off lamp is dark", press.go_energy() == 0.0)
		press.set_switched_off(false)
		_check("repowered lamp is dim again",
			is_equal_approx(press.go_energy(), HayCompressor.GO_IDLE))
		_check("running lamp stays under the wash out",
			HayCompressor.GO_RUNNING <= 0.6)
	_check("removed chaff outlet has no emitter", press.find_child("Shreds", true, false) == null)
	_check("removed chaff outlet has no mesh", press._find("Compressor_Spout") == null)
	_check("removed chaff outlet has no marker", press._find("Marker_Spout") == null)

	print("\n=== the hologram ===")


	var ghost:= HayCompressor.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = press.global_position + Vector3(0, 0, 6.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the ghost draws belt through itself", ghost._ghost_belt != null)
	_check("...and chevrons along it",
		ghost._ghost_flow != null
			and ghost._ghost_flow.multimesh.visible_instance_count > 0)


	var drawn:= 0.0
	if ghost._ghost_belt != null:
		drawn = ghost._ghost_belt.drawn_length
	var laid:= press.deck().path_length()
	_check("the ghost draws the belt the machine lays (%.3f m drawn, %.3f m laid)"
		% [drawn, laid], absf(drawn - laid) < 0.01)
	_check("...with its rails", ghost._ghost_belt != null
		and ghost._ghost_belt.drawn(BeltGhost.RAIL_L) > 0)


	var phase_was:= ghost._flow_phase
	for i in 10:
		await get_tree().process_frame
	_check("the chevrons scroll (%.3f -> %.3f)" % [phase_was, ghost._flow_phase],
		ghost._flow_phase > phase_was)

	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_check("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	_check("...and lays no belt path of its own", ghost.deck() == null)
	ghost.set_preview_valid(false)
	_check("a refused ghost paints its belt too",
		ghost._ghost_belt != null and ghost._ghost_belt.material() != null)
	world.remove_child(ghost)
	ghost.queue_free()

	print("\n=== geometry ===")
	var span:= press.port_in().distance_to(press.port_out())
	_check("ports %.2f m apart (want %.2f)" % [span, Cfg.COMPRESSOR_LENGTH],
		absf(span - Cfg.COMPRESSOR_LENGTH) < 0.02)
	_check("infeed port on the deck plane (%.3f vs %.3f)"
		% [press.port_in().y, deck_y], absf(press.port_in().y - deck_y) < 0.02)


	_check("travel is +Z as placed", press.forward().dot(Vector3.BACK) > 0.99)

	var bale_at:= press.to_global(press._marker_local("Marker_BaleOut", Vector3.ZERO))
	_check("the bale drop is downstream of centre",
		(bale_at - press.global_position).dot(press.forward()) > 0.3)

	print("\n=== snapping ===")

	for port: Vector3 in [press.port_in(), press.port_out()]:
		var near:= port + Vector3(0.35, 0.0, 0.4)
		var snapped: Vector3 = world.builds.snap_endpoint(near)
		_check("a belt end near a port snaps onto it (off by %.3f m)"
			% snapped.distance_to(port), snapped.is_equal_approx(port))
	var far:= press.port_out() + Vector3(4.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second press on the same spot is refused",
		world.builds.compressor_overlap(press.global_position))
	_check("a scanner on the same spot is refused too",
		world.builds.scanner_overlap(press.global_position))

	print("\n=== the line runs through it ===")
	world.builds.add_conveyor(feed_a, press.port_in())
	var out_end:= press.port_out() + Vector3(0, 0, 6.0)
	world.builds.add_conveyor(press.port_out(), out_end)


	for port: Vector3 in [press.port_in(), press.port_out()]:
		_check("a port with a belt on it does not pull the aim",
			not world.builds.snap_endpoint(port + Vector3(0.35, 0.0, 0.4))
				.is_equal_approx(port))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the module's deck knows what comes after it",
		press.deck() != null and press.deck().downstream != null)


	var sections:= 0
	for n in press.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi:= n as MultiMeshInstance3D
		if mmi.name == "Sections" and mmi.multimesh != null:
			sections += mmi.multimesh.instance_count
	_check("the placed module draws its own belt (%d sections)" % sections,
		sections > 0)


	_check("the drawn belt is placed in world space, not the module's",
		press.deck().get_node_or_null("Path") != null
			and (press.deck().get_node("Path") as Node3D).top_level)

	var step:= maxf(get_physics_process_delta_time(), 1e-06)


	print("\n=== one bale ===")
	var want:= Cfg.COMPRESSOR_BALE_STRANDS
	var made:= 0
	var elapsed:= 0.0
	var next_in:= 0.0
	var saw_pressing:= false
	var saw_throwing:= false
	while elapsed < 60.0:
		await get_tree().physics_frame
		elapsed += step
		next_in -= step
		if made < want and next_in <= 0.0:
			next_in = 0.1
			if world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.15, 0.15),
					0.22, 0.0), StrandFactory.random_strand_basis(_rng),
					Vector3.ZERO, Cfg.COL_HAY_LIGHT) != null:
				made += 1
		if press.is_pressing():
			if not saw_pressing:
				_check("pressing lamp is lit",
					is_equal_approx(press.go_energy(), HayCompressor.GO_RUNNING))


				press.set_power(0.0)
				_check("lamp goes dark mid press", press.is_pressing()
					and press.go_energy() == 0.0)
				press.set_power(1.0)
				_check("lamp comes back lit mid press",
					is_equal_approx(press.go_energy(), HayCompressor.GO_RUNNING))
			saw_pressing = true
			if press.find_child("Shreds", true, false) != null:
				saw_throwing = true
		if made >= want and _bale_count() >= 1 and not press.is_pressing():
			break
	print("  fed %d strands in %.1f s" % [made, elapsed])
	_check("the press ran", saw_pressing)
	_check("no chaff emits from the removed outlet", not saw_throwing)
	_check("one bale came out (%d)" % _bale_count(), _bale_count() == 1)
	_check("the machine is not still holding a bale's worth (%d left)"
		% press.stored, press.stored < Cfg.COMPRESSOR_BALE_STRANDS)


	var bale_seq:= _bale_seq()
	_check("the bale rides the outfeed as a record (seq %d)" % bale_seq, bale_seq >= 0)


	print("\n=== the belt carries it ===")
	var moved:= 0.0
	if bale_seq >= 0:
		var where:= BeltPath.record_where(bale_seq)
		var was: Vector3 = (where ["pose"] as Transform3D).origin
		elapsed = 0.0
		while elapsed < 8.0:
			await get_tree().physics_frame
			elapsed += step
			where = BeltPath.record_where(bale_seq)
			if where.is_empty():
				break
			moved = ((where ["pose"] as Transform3D).origin - was).dot(press.forward())
			if moved > 1.0:
				break
		print("  the bale travelled %.2f m downstream in %.1f s" % [moved, elapsed])
	_check("the belt drags the bale away (%.2f m)" % moved, moved > 0.6)


	var bale: HayBale = null
	var where_now:= BeltPath.record_where(bale_seq) if bale_seq >= 0 else { }
	if not where_now.is_empty():
		bale = (where_now ["path"] as BeltPath).materialize_record(int(where_now ["row"])) as HayBale
	elif not _bales().is_empty():
		bale = _bales() [0]
	_check("...and gives the body back when it is asked for", bale != null)
	_check("the bale is a prop on L_PROP",
		bale != null and (bale.collision_layer & Cfg.L_PROP) != 0)
	_check("...and NOT hay, so the belt cannot pack it at strand pitch",
		bale != null and (bale.collision_layer & Cfg.L_STRAND) == 0)
	_check("the bale knows what went into it (%d)"
		% (bale.strands if bale != null else -1),
		bale != null and bale.strands == Cfg.COMPRESSOR_BALE_STRANDS)
	_check("...and what it is worth (%.0f strand-equivalents)"
		% (bale.sale_strands() if bale != null else -1.0),
		bale != null and is_equal_approx(bale.sale_strands(),
			float(Cfg.COMPRESSOR_BALE_STRANDS) * Cfg.COMPRESSOR_BALE_RATIO))


	var skins:= _bale_skins(bale)
	_check("the bale keeps its twine outside the press (%s)"
		% ", ".join(PackedStringArray(skins.keys())),
		skins.size() == 2 and skins.has(HayBale.MAT_STRAW)
			and skins.has(HayBale.MAT_TWINE)
			and skins [HayBale.MAT_STRAW] != skins [HayBale.MAT_TWINE])


	print("\n=== conservation ===")
	var before_bales:= _bale_count()
	var batch:= Cfg.COMPRESSOR_BALE_STRANDS * 3
	made = 0
	elapsed = 0.0
	next_in = 0.0
	while elapsed < 90.0:
		await get_tree().physics_frame
		elapsed += step
		next_in -= step
		if made < batch and next_in <= 0.0:
			next_in = 0.08
			if world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.15, 0.15),
					0.22, 0.0), StrandFactory.random_strand_basis(_rng),
					Vector3.ZERO, Cfg.COL_HAY_LIGHT) != null:
				made += 1
		if made >= batch and _bale_count() - before_bales >= 3 and not press.is_pressing():
			break
	var fresh:= _bale_count() - before_bales
	print("  fed %d more strands, %d more bales" % [made, fresh])
	_check("three bales' worth of hay makes three bales (%d)" % fresh, fresh == 3)
	_check("...and no more (%d)" % fresh, fresh <= 3)


	print("\n=== full, it holds what it cannot eat ===")
	var out_axis:= press.forward()


	var blocker: HayBale = world.props.spawn("hay_bale", Transform3D(Basis(),
		press.port_out() - out_axis * 0.02 + Vector3.UP * 0.05)) as HayBale
	if blocker != null:
		blocker.freeze = true
	press.stored = press.buffer_capacity() + Tech.compressor_bale_strands()
	for i in 4:
		await get_tree().physics_frame
	_check("a full press closes its mouth", press.deck() != null and press.deck().is_blocked())


	var over_mouth:= 0
	for i in 6:
		if world.live.spawn(press.port_in() + out_axis * (0.15 + 0.08 * i)
				+ Vector3(_rng.randf_range(-0.1, 0.1), 0.22, 0.0),
				StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
				Cfg.COL_HAY_LIGHT) != null:
			over_mouth += 1
	for i in 8:
		world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.3 * i),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)


	var past_before:= _past_outfeed(press)
	var leaked_worst:= 0
	elapsed = 0.0
	while elapsed < 12.0:
		await get_tree().physics_frame
		elapsed += step
		leaked_worst = maxi(leaked_worst, _past_outfeed(press) - past_before)
	var feeder: BeltPath = world.builds.feed_run_into(press.port_in())
	print("  %d strands over the mouth of a full press: %d held on its deck, %d on the run behind"
		% [over_mouth, press.deck().riders().size(),
			feeder.riders().size() if feeder != null else -1])
	_check("nothing rides through a full press unpressed (%d past the outfeed)"
		% leaked_worst, leaked_worst == 0)
	_check("...the hay over the mouth is held there (%d riders)"
		% press.deck().riders().size(), press.deck().riders().size() >= over_mouth - 1)
	_check("...and the run behind it backs up",
		feeder != null and feeder.has_rider_waiting())

	var stored_was:= press.stored
	press.stored = 0
	if blocker != null:
		world.props.remove(blocker)
	elapsed = 0.0
	while elapsed < 6.0:
		await get_tree().physics_frame
		elapsed += step
		if press.deck().riders().is_empty() and press.stored >= over_mouth - 1:
			break
	_check("...and the mouth eats it once there is room (%d stored, deck holds %d)"
		% [press.stored, press.deck().riders().size()],
		press.stored >= over_mouth - 1 and press.deck().riders().is_empty())
	print("  buffer was %d, eaten back up to %d" % [stored_was, press.stored])


	elapsed = 0.0
	while elapsed < 15.0:
		await get_tree().physics_frame
		elapsed += step
		if press.deck().riders().is_empty() and (feeder == null or feeder.riders().is_empty()):
			break
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	print("\n=== the save ===")


	press.stored = 37


	var port_was:= press.port_in()
	var row:= press.to_dict()
	_check("the save names the type", row.get("type", "") == "hay_compressor")
	_check("the save carries the buffer (%d)" % int(row.get("stored", -1)),
		int(row.get("stored", -1)) == 37)
	var rows: Array = world.builds.to_array()
	world.builds.from_array(rows)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var reloaded: HayCompressor = world.builds.compressors [0] if not world.builds.compressors.is_empty() else null
	_check("the press came back", reloaded != null)
	_check("...with its buffer (%d)" % (reloaded.stored if reloaded != null else -1),
		reloaded != null and reloaded.stored == 37)
	_check("...and its ports where they were",
		reloaded != null and reloaded.port_in().distance_to(port_was) < 0.02)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _past_outfeed(press: HayCompressor) -> int:
	var count:= 0
	var axis:= press.forward()
	for child in world.live.get_children():
		var rb:= child as RigidBody3D
		if rb != null and rb.is_inside_tree() and (rb.global_position - press.port_out()).dot(axis) > 0.05:
			count += 1
	return count


func _bales() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayBale:
			out.append(item)
	return out


func _bale_count() -> int:
	return _bales().size() + _bale_records().size()


func _bale_records() -> Array:
	var out: Array = []
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if run.kind_of(i) == BeltRun.Kind.BALE:
				out.append(run.seq_of(i))
	return out


func _bale_seq() -> int:
	var recs:= _bale_records()
	return int(recs [0]) if not recs.is_empty() else -1


func _bale_skins(bale: HayBale) -> Dictionary:
	var out: Dictionary = { }
	if bale == null:
		return out
	var mi:= bale.find_child("Bale", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return out
	for i in mi.mesh.get_surface_count():
		var src:= mi.mesh.surface_get_material(i)
		var ov:= mi.get_surface_override_material(i)
		if src == null or ov == null:
			continue
		out [src.resource_name] = ov
	return out


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
