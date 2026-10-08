class_name DevPileSizeProbe
extends Node


const EDGE_MARGIN:= 2.0


const PEAK_TOLERANCE:= 0.06


const FOOTPRINT_TOLERANCE:= 1.5


const VOLUME_TOLERANCE:= 0.12

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("--- pile size probe ---")
	var was:= Cfg.pile_size_id
	_check_table()
	for spec: Dictionary in Cfg.PILE_SIZES:
		await _measure(spec)


	Cfg.apply_pile_size(was)
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_table() -> void:
	var seen: Dictionary = { }
	var ok_ids:= true
	for spec: Dictionary in Cfg.PILE_SIZES:
		var id:= str(spec.get("id", ""))
		ok_ids = ok_ids and id != "" and not seen.has(id)
		seen [id] = true
	_ok(ok_ids, "every preset has an id of its own")
	_ok(seen.has(Cfg.DEFAULT_PILE_SIZE),
		"the default (%s) is one of them" % Cfg.DEFAULT_PILE_SIZE)
	_ok(str(Cfg.pile_size_spec("no such size").get("id", "")) == Cfg.DEFAULT_PILE_SIZE,
		"a size this build has never heard of comes back as the stock pile")


func _check_start_tech(spec: Dictionary) -> void:
	var id:= str(spec.get("id", ""))
	var want: Dictionary = spec.get("start_tech", { })
	var extra: Array = []
	for node: String in Tech.ranks:
		if node == TechTree.ROOT or want.has(node):
			continue
		extra.append(node)
	_ok(extra.is_empty(),
		"%s: the run opens with nothing it was not promised%s"
			% [id, "" if extra.is_empty() else ", found " + ", ".join(extra)])
	for node: String in want:
		_ok(Tech.rank_of(node) == int(want [node]),
			"%s: opens with %s at level %d, got %d"
				% [id, TechTree.display_name(node), int(want [node]),
					Tech.rank_of(node)])
	if want.has("yard_space"):
		var levels:= float(want ["yard_space"])
		_ok(is_equal_approx(Tech.warehouse_extra(),
				Tech.YARD_METRES_PER_RANK * levels),
			"%s: the shed opens at %.1f m, %.1f m out from the %.1f m the pile "
				% [id, Cfg.yard_inner_for_pile() + Tech.warehouse_extra(),
					Tech.warehouse_extra(), Cfg.yard_inner_for_pile()]
				+ "alone asks for")


func _measure(spec: Dictionary) -> void:
	var id:= str(spec.get("id", ""))
	Cfg.apply_pile_size(id)
	print("\n%s  (r %.1f, h %.1f, extent %.1f, prep %.0f deg)"
		% [str(spec.get("name", "")), Cfg.PILE_RADIUS, Cfg.PILE_HEIGHT,
			Cfg.FIELD_EXTENT, Cfg.PILE_PREP_ANGLE_DEG])

	var field:= HayField.new()
	add_child(field)
	var t0:= Time.get_ticks_msec()
	field.generate(1234)
	var ms:= Time.get_ticks_msec() - t0

	var nv:= Cfg.field_verts()
	var peak:= 0.0
	var toe:= 0.0
	var volume:= 0.0
	var edge:= 0.0
	var uncovered_cells:= 0
	var area: float = Cfg.CELL * Cfg.CELL
	for j in nv:
		for i in nv:
			var h: float = field.heights [j * nv + i]
			if h <= 0.0:
				continue
			peak = maxf(peak, h)
			var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL


			toe = maxf(toe, sqrt(wx * wx + wz * wz))
			if i == 0 or j == 0 or i == nv - 1 or j == nv - 1:
				edge = maxf(edge, h)
	var nc:= Cfg.field_cells()
	for j in nc:
		for i in nc:
			volume += field.cell_height(i, j) * area
			var h00:= field.heights [j * nv + i]
			var h10:= field.heights [j * nv + i + 1]
			var h01:= field.heights [(j + 1) * nv + i]
			var h11:= field.heights [(j + 1) * nv + i + 1]
			if maxf(maxf(h00, h10), maxf(h01, h11)) <= 0.0:
				continue
			var chunk_i:= field.chunk_index_for_cell(i, j)
			if chunk_i < 0 or not field.chunks [chunk_i].owns_cell(j * nc + i):
				uncovered_cells += 1

	var strands:= volume * Cfg.STRANDS_PER_M3
	print("  built in %d ms   %dx%d vertices, %d chunks"
		% [ms, nv, nv, field.chunks.size()])
	print("  peak %.1f m   footprint %.1f m   %.0f m3   %s strands   %d needles"
		% [peak, toe, volume, Hud.fmt(strands), GameState.pile_needle_types().size()])
	print("  shed goes to %.1f m; estimates say footprint %.1f m, %.0f m3"
		% [Cfg.yard_inner_for_pile(), Cfg.settled_footprint(),
			Cfg.pile_volume_estimate(spec)])
	print("  crust reserved to %.1f m" % field.crust_radius)

	_ok(toe <= Cfg.FIELD_EXTENT - EDGE_MARGIN,
		"%s: the toe stops %.1f m short of the field edge" % [id, Cfg.FIELD_EXTENT - toe])
	_ok(edge <= 0.001, "%s: no hay standing on the boundary row" % id)
	_ok(field.settling_count() == 0,
		"%s: the dome arrived settled, %d vertices queued" % [id, field.settling_count()])
	_ok(peak >= Cfg.PILE_HEIGHT * (1.0 - PEAK_TOLERANCE),
		"%s: stands %.1f m against the %.0f m on the label" % [id, peak, Cfg.PILE_HEIGHT])
	_ok(absf(Cfg.settled_footprint() - toe) <= FOOTPRINT_TOLERANCE,
		"%s: footprint estimate %.1f m against %.1f m measured"
			% [id, Cfg.settled_footprint(), toe])
	_ok(absf(Cfg.pile_volume_estimate(spec) - volume) <= volume * VOLUME_TOLERANCE,
		"%s: volume estimate %.0f m3 against %.0f m3 measured"
			% [id, Cfg.pile_volume_estimate(spec), volume])
	_ok(uncovered_cells == 0,
		"%s: every raised surface cell has crust slots" % id)
	_check_start_tech(spec)

	var fresh_print:= _fingerprint(field)
	var saved:= _dug_copy(field)
	var built_dome:= field.dome.duplicate()

	field.queue_free()


	await get_tree().process_frame

	await _check_same_pile(id, fresh_print, saved, built_dome)


func _fingerprint(field: HayField) -> String:
	var ctx:= HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(field.heights.to_byte_array())
	ctx.update(field.dome.to_byte_array())
	ctx.update(PackedFloat64Array([field.crust_radius, GameState.hay_total]).to_byte_array())


	ctx.update(var_to_bytes(GameState.needle_positions))
	ctx.update(var_to_bytes(GameState.needle_type))
	return ctx.finish().hex_encode().left(16)


func _dug_copy(field: HayField) -> PackedFloat32Array:
	var saved:= field.heights.duplicate()
	var nv:= Cfg.field_verts()
	var c:= field.cell_at(Cfg.PILE_CENTER.x + Cfg.PILE_RADIUS * 0.5, Cfg.PILE_CENTER.z)
	var half:= int(round(1.0 / Cfg.CELL))
	for j in range(c.y - half, c.y + half + 1):
		for i in range(c.x - half, c.x + half + 1):
			if i >= 0 and j >= 0 and i < nv and j < nv:
				saved [j * nv + i] = 0.0
	return saved


func _check_same_pile(id: String, fresh_print: String, saved: PackedFloat32Array,
		built_dome: PackedFloat32Array) -> void:
	var restored:= HayField.new()
	add_child(restored)
	var t0:= Time.get_ticks_msec()
	restored.generate(1234, saved)
	var restored_ms:= Time.get_ticks_msec() - t0
	var restored_print:= _fingerprint(restored)
	restored.queue_free()
	await get_tree().process_frame

	var staged:= HayField.new()
	add_child(staged)
	var staged_worst:= await _staged_build(staged, PackedFloat32Array())
	var staged_print:= _fingerprint(staged)
	var visits:= staged.prep_visits
	staged.queue_free()
	await get_tree().process_frame

	var staged_restored:= HayField.new()
	add_child(staged_restored)
	var staged_restored_worst:= await _staged_build(staged_restored, saved)
	var staged_restored_print:= _fingerprint(staged_restored)
	staged_restored.queue_free()
	await get_tree().process_frame

	print("  fingerprint fresh %s   restored %s (%d ms)" % [fresh_print, restored_print, restored_ms])
	print("  staged worst frame %d ms fresh, %d ms restored   %d prep visits (%.1f a vertex)"
		% [staged_worst, staged_restored_worst, visits,
			float(visits) / float(Cfg.field_verts() * Cfg.field_verts())])
	_ok(staged_print == fresh_print,
		"%s: a staged pile is the one shot pile (%s)" % [id, staged_print])
	_ok(staged_restored_print == restored_print,
		"%s: a staged load is the one shot load (%s)" % [id, staged_restored_print])

	await _check_saved_dome(id, restored_print, restored_ms, saved, built_dome)


func _check_saved_dome(id: String, restored_print: String, restored_ms: int,
		saved: PackedFloat32Array, built_dome: PackedFloat32Array) -> void:
	var quick:= HayField.new()
	add_child(quick)
	var t0:= Time.get_ticks_msec()
	quick.generate(1234, saved, built_dome)
	var quick_ms:= Time.get_ticks_msec() - t0
	var quick_print:= _fingerprint(quick)
	var quick_used:= quick.dome_from_save
	quick.queue_free()
	await get_tree().process_frame

	var staged:= HayField.new()
	add_child(staged)
	var gap:= { "last": Time.get_ticks_usec(), "worst": 0 }
	var tick:= func() -> void:
		var now:= Time.get_ticks_usec()
		gap ["worst"] = maxi(int(gap ["worst"]), now - int(gap ["last"]))
		gap ["last"] = now
	get_tree().process_frame.connect(tick)
	await staged.generate_staged(1234, saved, func(_f: float) -> void: pass,
		Callable(), built_dome)
	tick.call()
	get_tree().process_frame.disconnect(tick)
	var staged_print:= _fingerprint(staged)
	var staged_used:= staged.dome_from_save
	staged.queue_free()
	await get_tree().process_frame

	print("  with the saved dome: %d ms against %d ms shaped, staged worst frame %d ms"
		% [quick_ms, restored_ms, int(gap ["worst"]) / 1000])
	_ok(quick_used and staged_used, "%s: a load takes the dome its save carries" % id)
	_ok(quick_print == restored_print,
		"%s: ...and leaves the pile a shaped load leaves (%s)" % [id, quick_print])
	_ok(staged_print == restored_print,
		"%s: ...staged as well (%s)" % [id, staged_print])

	if id != str(Cfg.PILE_SIZES [0].get("id", "")):
		return
	var nv:= Cfg.field_verts()
	var peak_at:= 0
	for k in built_dome.size():
		if built_dome [k] > built_dome [peak_at]:
			peak_at = k
	var short:= built_dome.duplicate()
	short.resize(built_dome.size() - 1)
	var bad_number:= built_dome.duplicate()
	bad_number [peak_at] = NAN
	var endless:= built_dome.duplicate()
	endless [peak_at] = INF
	var lighter:= built_dome.duplicate()
	lighter [peak_at] = maxf(0.0, lighter [peak_at] - 0.5)
	var other_pile:= built_dome.duplicate()
	other_pile.fill(0.0)
	var cases:= {
		"no dome": PackedFloat32Array(),
		"one point short": short,
		"a NaN in it": bad_number,
		"an INF in it": endless,
		"half a metre off one point": lighter,
		"an empty field": other_pile,
	}
	print("  %d x %d: %d refusal cases, each shaping the pile the long way"
		% [nv, nv, cases.size()])
	for what: String in cases:
		var f:= HayField.new()
		add_child(f)
		f.generate(1234, saved, cases [what])
		var p:= _fingerprint(f)
		var used:= f.dome_from_save
		f.queue_free()
		await get_tree().process_frame
		_ok(not used and p == restored_print,
			"%s: a dome with %s is turned down and the pile shaped (%s)" % [id, what, p])


	var fresh:= HayField.new()
	add_child(fresh)
	fresh.generate(1234, PackedFloat32Array(), built_dome)
	var fresh_used:= fresh.dome_from_save
	fresh.queue_free()
	await get_tree().process_frame
	_ok(not fresh_used, "%s: a new pile never takes a dome" % id)


func _staged_build(field: HayField, saved: PackedFloat32Array) -> int:
	var gap:= { "last": Time.get_ticks_usec(), "worst": 0 }
	var tick:= func() -> void:
		var now:= Time.get_ticks_usec()
		gap ["worst"] = maxi(int(gap ["worst"]), now - int(gap ["last"]))
		gap ["last"] = now
	get_tree().process_frame.connect(tick)
	await field.generate_staged(1234, saved, func(_f: float) -> void: pass)
	tick.call()
	get_tree().process_frame.disconnect(tick)
	return int(gap ["worst"]) / 1000
