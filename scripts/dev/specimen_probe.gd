class_name DevSpecimenProbe
extends Node


const BODKIN:= 6
const PHONOGRAPH:= 11


const HAT_PIN:= 5


func run() -> void:
	var fails:= 0
	fails += _check_table()
	fails += _check_case_not_drawers()
	fails += _check_compounding()
	fails += _check_reload()
	fails += _check_reveal()
	fails += _check_seeding()
	print("\n[specimens] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _ok(cond: bool, msg: String) -> int:
	if cond:
		print("  ok    %s" % msg)
		return 0
	return _fail(msg)


func _check_table() -> int:
	print("\n-- the table --")
	var bad:= 0
	var missing: Array [String] = []
	for type in NeedleTypes.count():
		if not NeedleTypes.has_effect(type):
			missing.append(NeedleTypes.name_of(type))
	bad += _ok(missing.is_empty(),
		"all %d types grant an effect%s" % [NeedleTypes.count(),
			"" if missing.is_empty() else ": missing " + ", ".join(missing)])


	var known:= ["dig_effort", "scoop", "pour", "carry_reach", "stamina_regen",
		"reveal_radius", "belt_speed", "build_reach", "container", "stand_belt",
		"hay_price", "build_cost", "machine_buffer", "machine_speed", "arm_speed",
		"arm_capacity", "scan_batch", "scan_speed", "scanner_bin"]
	var unread: Array [String] = []
	for type in NeedleTypes.count():
		for key: String in NeedleTypes.effect_keys(type):
			if not known.has(key) and not unread.has(key):
				unread.append(key)
	bad += _ok(unread.is_empty(),
		"every key names an effect Tech reads%s"
			% ("" if unread.is_empty() else ": " + ", ".join(unread)))

	var named:= 0
	for type in NeedleTypes.count():
		if NeedleTypes.effect_name(type) != "" and NeedleTypes.effect_text(type) != "":
			named += 1
	bad += _ok(named == NeedleTypes.count(),
		"every effect has a name and a line the player can read (%d/%d)"
			% [named, NeedleTypes.count()])
	return bad


func _check_case_not_drawers() -> int:
	print("\n-- the case grants, the drawers do not --")
	var bad:= 0
	_wipe()
	var base:= Tech.belt_speed()


	for i in 10:
		GameState.needle_stock [BODKIN] = i + 1
	bad += _ok(is_equal_approx(Tech.belt_speed(), base),
		"ten Bodkins in the drawers with an empty case change nothing")

	GameState.discover(BODKIN, Vector3.ZERO)
	var one:= Tech.belt_speed()
	bad += _ok(one > base, "the first one in the case makes belts faster")
	bad += _ok(is_equal_approx(one, base * 1.06),
		"and by exactly the 6%% the card promises (x%.4f)" % (one / base))


	GameState.discover(BODKIN, Vector3.ZERO)
	GameState.needle_stock [BODKIN] = 99
	bad += _ok(is_equal_approx(Tech.belt_speed(), one),
		"a second Bodkin, and ninety-nine in the drawer, add nothing")
	return bad


func _check_compounding() -> int:
	print("\n-- two needles on one key --")
	var bad:= 0
	_wipe()
	var base:= Tech.belt_speed()
	GameState.discover(BODKIN, Vector3.ZERO)
	GameState.discover(PHONOGRAPH, Vector3.ZERO)
	var both:= Tech.belt_speed()


	bad += _ok(is_equal_approx(both, base * 1.06 * 1.25),
		"Bodkin and Phonograph compound to x%.4f, not x1.3100" % (both / base))
	return bad


func _check_reload() -> int:
	print("\n-- a save round trip --")
	var bad:= 0
	_wipe()
	GameState.discover(BODKIN, Vector3.ZERO)
	GameState.discover(PHONOGRAPH, Vector3.ZERO)
	var before:= Tech.belt_speed()


	var saved:= GameState.to_dict().duplicate(true)
	_wipe()
	bad += _ok(is_equal_approx(Tech.belt_speed(), Cfg.BELT_SPEED),
		"wiping the case puts belts back to standard")

	GameState.from_dict(saved)
	bad += _ok(is_equal_approx(Tech.belt_speed(), before),
		"loading it back restores the effect without a fresh discovery")
	return bad


func _check_reveal() -> int:
	print("\n-- the search widens --")
	var bad:= 0
	_wipe()
	bad += _ok(is_equal_approx(Tech.needle_reveal_scale(), 1.0),
		"an empty case searches exactly the bite")
	GameState.discover(HAT_PIN, Vector3.ZERO)
	var hat:= Tech.needle_reveal_scale()
	bad += _ok(is_equal_approx(hat, 2.0), "Pinpoint doubles the radius (x%.2f)" % hat)


	print("      which is x%.1f the volume a dig searches" % pow(hat, 3.0))
	return bad


func _check_seeding() -> int:
	print("\n-- the pile --")
	var bad:= 0
	var want:= GameState.pile_needle_types()
	var buried:= GameState.needle_positions.size()
	bad += _ok(buried == want.size(),
		"the yard seeded %d needles, one for each of %d types" % [buried, want.size()])

	var tally: Dictionary = { }
	for i in GameState.needle_type.size():
		var t:= int(GameState.needle_type [i])
		tally [t] = int(tally.get(t, 0)) + 1
	var absent: Array [String] = []
	var twice: Array [String] = []
	for type in want:
		var n:= int(tally.get(type, 0))
		if n == 0:
			absent.append(NeedleTypes.name_of(type))
		elif n > 1:
			twice.append(NeedleTypes.name_of(type))
	bad += _ok(absent.is_empty(), "every type is buried somewhere%s"
		% ("" if absent.is_empty() else ": missing " + ", ".join(absent)))
	bad += _ok(twice.is_empty(), "and none of them twice%s"
		% ("" if twice.is_empty() else ": " + ", ".join(twice)))

	var stray:= 0
	for t: int in tally:
		if not want.has(t):
			stray += 1
	bad += _ok(stray == 0, "and nothing the pile is not meant to hold")
	return bad


func _wipe() -> void:
	for t in NeedleTypes.count():
		GameState.discovered [t] = 0
		GameState.needle_stock [t] = 0
	GameState.collection_loaded.emit()
