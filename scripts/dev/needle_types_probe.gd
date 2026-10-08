class_name DevNeedleTypesProbe
extends Node


var world: Node3D


func run() -> void:
	var fails:= 0
	fails += _check_table()
	fails += _check_rolls()
	fails += _check_ledger()
	fails += _check_depths()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_table() -> int:
	print("\n-- table --")
	var bad:= 0
	var n:= NeedleTypes.count()
	if n != 24:
		bad += _fail("expected 24 types, got %d" % n)
	if NeedleTypes.lot_count() != 4:
		bad += _fail("expected 4 lots, got %d" % NeedleTypes.lot_count())
	for lot in NeedleTypes.lot_count():
		var ids:= NeedleTypes.pool(lot)
		var p:= 0.0
		for id in ids:
			p += 1.0 / float(NeedleTypes.one_in(id))
		print("  lot %d: %d types, P=%.4f" % [lot, ids.size(), p])
		if ids.size() != 6:
			bad += _fail("lot %d has %d types, expected 6" % [lot, ids.size()])


		if absf(p - 1.0) > 0.0005:
			bad += _fail("lot %d odds sum to %.4f, not 1" % [lot, p])
	return bad


func _check_rolls() -> int:
	print("\n-- rolls --")
	var bad:= 0
	var rng:= RandomNumberGenerator.new()
	rng.seed = 12345
	for lot in NeedleTypes.lot_count():
		var allowed:= NeedleTypes.pool(lot)
		var seen:= { }
		for i in 20000:
			var t:= NeedleTypes.roll(lot, rng)
			if not allowed.has(t):
				bad += _fail("lot %d rolled type %d, not in its pool" % [lot, t])
				break
			seen [t] = int(seen.get(t, 0)) + 1
		var parts: Array [String] = []
		for id in allowed:
			var got:= float(seen.get(id, 0)) / 20000.0
			var want:= 1.0 / float(NeedleTypes.one_in(id))
			parts.append("%s %.3f/%.3f" % [NeedleTypes.name_of(id), got, want])

			if absf(got - want) > 0.02:
				bad += _fail("%s drew %.3f, expected %.3f"
					% [NeedleTypes.name_of(id), got, want])
		print("  lot %d: %s" % [lot, ", ".join(parts)])
	return bad


func _check_ledger() -> int:
	print("\n-- ledger --")
	var bad:= 0
	GameState.reset(99, 1000.0)
	if GameState.research_held() != 0:
		bad += _fail("a fresh run starts with research in the drawers")

	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var idx:= GameState.register_needle(Vector3.ZERO, rng)
	var t:= GameState.type_of(idx)
	if not NeedleTypes.pool(0).has(t):
		bad += _fail("lot 0 buried a type from another lot")


	GameState.deposit_needle(idx, Vector3.ZERO)
	if GameState.is_discovered(t):
		bad += _fail("banking a needle discovered it without a cabinet")
	if GameState.stock_of(t) != 1:
		bad += _fail("stock is %d after one deposit" % GameState.stock_of(t))

	if not GameState.discover(t, Vector3.ZERO):
		bad += _fail("the first of a type did not report as a discovery")
	if not GameState.is_discovered(t):
		bad += _fail("discovering did not set the flag")


	var idx2:= GameState.register_needle(Vector3.ZERO, rng)
	GameState.needle_type [idx2] = t
	GameState.deposit_needle(idx2, Vector3.ZERO)
	if GameState.discover(t, Vector3.ZERO):
		bad += _fail("a duplicate reported as a fresh discovery")
	if GameState.stock_of(t) != 2:
		bad += _fail("stock is %d after two deposits" % GameState.stock_of(t))

	var worth:= NeedleTypes.research_of(t)
	if GameState.research_held() != worth * 2:
		bad += _fail("research_held is %d, expected %d"
			% [GameState.research_held(), worth * 2])


	if not GameState.spend_research(worth * 2):
		bad += _fail("could not spend research the drawers hold")
	if GameState.stock_of(t) != 0:
		bad += _fail("spending left %d in the drawer" % GameState.stock_of(t))
	if not GameState.is_discovered(t):
		bad += _fail("spending cleared the specimen out of the case")
	if GameState.spend_research(1):
		bad += _fail("spent research that was not there")
	print("  deposit/duplicate/spend all behaved; case survived the spend")


	var before:= GameState.money
	var idx3:= GameState.register_needle(Vector3.ZERO, rng)
	GameState.deposit_needle(idx3, Vector3.ZERO)
	if not is_equal_approx(GameState.money, before):
		bad += _fail("depositing a needle changed the money by %.2f"
			% (GameState.money - before))
	print("  depositing paid no cash")


	var t3:= GameState.type_of(idx3)
	GameState.discover(t3, Vector3.ZERO)
	var held:= GameState.stock_of(t3)
	var lifetime:= GameState.found_of(t3)
	var total:= GameState.needles_found
	var out:= GameState.withdraw_needle(t3, Vector3.ZERO)
	if out < 0:
		bad += _fail("could not withdraw a needle the drawers hold")
	if GameState.type_of(out) != t3:
		bad += _fail("the withdrawn needle came out as the wrong type")
	if GameState.stock_of(t3) != held - 1:
		bad += _fail("withdrawing left %d of %d in the drawer"
			% [GameState.stock_of(t3), held])
	if not GameState.is_discovered(t3):
		bad += _fail("withdrawing cleared the specimen out of the case")


	GameState.deposit_needle(out, Vector3.ZERO)
	if GameState.stock_of(t3) != held:
		bad += _fail("putting it back left %d of %d in the drawer"
			% [GameState.stock_of(t3), held])
	if GameState.found_of(t3) != lifetime or GameState.needles_found != total:
		bad += _fail("a round trip counted as a find (%d/%d, expected %d/%d)"
			% [GameState.found_of(t3), GameState.needles_found, lifetime, total])

	while GameState.stock_of(t3) > 0:
		GameState.withdraw_needle(t3, Vector3.ZERO)
	if GameState.withdraw_needle(t3, Vector3.ZERO) >= 0:
		bad += _fail("withdrew a needle the drawers did not have")
	print("  withdrawing drained the drawer, kept the counters and left the case alone")


	GameState.reset(31, 100.0)
	var idx4:= GameState.register_needle(Vector3.ZERO, rng)
	var t4:= GameState.type_of(idx4)
	GameState.deposit_needle(idx4, Vector3.ZERO)
	GameState.withdraw_needle(t4, Vector3.ZERO)
	if GameState.stock_of(t4) != 0:
		bad += _fail("the withdrawn needle was still in the drawer")
	var saved:= GameState.to_dict()
	GameState.reset(1, 100.0)
	GameState.from_dict(saved)
	if GameState.stock_of(t4) != 1:
		bad += _fail("a needle out of the drawers at save time was lost (%d held)"
			% GameState.stock_of(t4))
	print("  a save taken mid-withdrawal put the specimen back")
	return bad


func _check_depths() -> int:
	print("\n-- depths --")
	var bad:= 0
	for lot in NeedleTypes.lot_count():
		var shallow:= NeedleTypes.shallow_pool(lot)
		var deep:= NeedleTypes.deep_pool(lot)
		if shallow.size() != NeedleTypes.SHALLOW_PER_LOT:
			bad += _fail("lot %d shallow pool holds %d types, expected %d"
				% [lot, shallow.size(), NeedleTypes.SHALLOW_PER_LOT])
		for t in shallow:
			if t in deep:
				bad += _fail("lot %d type %d is both shallow and deep" % [lot, t])
			if NeedleTypes.site_band(t) != HayField.SITE_SHALLOW:
				bad += _fail("lot %d type %d is in the shallow pool but not sited shallow" % [lot, t])


		var rarest_shallow:= 0
		for t in shallow:
			rarest_shallow = maxi(rarest_shallow, NeedleTypes.one_in(t))
		for t in NeedleTypes.pool(lot):
			if not (t in shallow) and NeedleTypes.one_in(t) < rarest_shallow:
				bad += _fail("lot %d keeps a 1:%d type out of the shallow pool while a 1:%d is in it"
					% [lot, NeedleTypes.one_in(t), rarest_shallow])
		print("  lot %d: shallow %s  deep %s" % [lot, shallow, deep])
	if world == null or world.get("field") == null:
		print("  (no field to sample; band geometry not checked)")
		return bad
	var field: HayField = world.field
	var samples:= 400
	var worst:= { "shallow": 0.0, "deep_frac": 0.0, "deep_rad": 0.0, "any_lo": INF, "any_hi": 0.0 }
	var counted:= { "shallow": 0, "deep": 0, "any": 0 }
	for _i in samples:
		var s: Vector3 = field._needle_site(HayField.SITE_SHALLOW)
		if s != Vector3.INF:
			counted ["shallow"] += 1
			var cover: float = field.height_at(s.x, s.z) - s.y
			worst ["shallow"] = maxf(worst ["shallow"], cover)
			if cover < 0.25 - 0.001 or cover > Cfg.NEEDLE_SHALLOW_DEPTH + 0.001:
				bad += _fail("a shallow site sits under %.2f m of hay" % cover)
		var d: Vector3 = field._needle_site(HayField.SITE_DEEP)
		if d != Vector3.INF:
			counted ["deep"] += 1
			var surf: float = field.height_at(d.x, d.z)
			var frac: float = (d.y - 0.12) / maxf(surf - 0.25 - 0.12, 0.001)
			worst ["deep_frac"] = maxf(worst ["deep_frac"], frac)
			var rad: float = Vector2(d.x - Cfg.PILE_CENTER.x, d.z - Cfg.PILE_CENTER.z).length()
			worst ["deep_rad"] = maxf(worst ["deep_rad"], rad)
			if frac > Cfg.NEEDLE_DEEP_COLUMN + 0.001:
				bad += _fail("a deep site sits %.0f%% of the way up its column" % (frac * 100.0))
			if rad > Cfg.PILE_RADIUS * Cfg.NEEDLE_DEEP_RADIUS + 0.001:
				bad += _fail("a deep site sits %.2f m out, past the inner footprint" % rad)
		var a: Vector3 = field._needle_site(HayField.SITE_ANY)
		if a != Vector3.INF:
			counted ["any"] += 1
			var cover_a: float = field.height_at(a.x, a.z) - a.y
			worst ["any_lo"] = minf(worst ["any_lo"], cover_a)
			worst ["any_hi"] = maxf(worst ["any_hi"], cover_a)
			if cover_a < 0.25 - 0.001 or a.y < 0.12 - 0.001:
				bad += _fail("an ordinary site breaks the floor or the cover rule (%.2f m under)" % cover_a)
	print("  %d shallow sites: deepest cover %.2f m (detector hears through about 1.10 m)"
		% [counted ["shallow"], worst ["shallow"]])
	print("  %d deep sites: highest %.0f%% up the column, furthest %.2f m out"
		% [counted ["deep"], worst ["deep_frac"] * 100.0, worst ["deep_rad"]])
	print("  %d ordinary sites: cover %.2f m to %.2f m"
		% [counted ["any"], worst ["any_lo"], worst ["any_hi"]])
	if counted ["shallow"] < samples / 2 or counted ["deep"] < samples / 4:
		bad += _fail("the dome refused too many sites to trust the sample")
	if worst ["shallow"] > 1.1:
		bad += _fail("the shallow band reaches past the detector's 1.10 m of hay")
	return bad
