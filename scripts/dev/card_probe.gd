class_name DevCardProbe
extends Node


const TOL:= 0.0005


func run() -> void:
	var bad:= 0
	Tech.reset()
	for entry: Dictionary in _ladders():
		bad += _check_ladder(entry)
	print("\n[probe] %s" % ("PASS" if bad == 0 else "%d FAILURE(S)" % bad))
	Tech.reset()
	get_tree().quit(1 if bad > 0 else 0)


func _check_ladder(entry: Dictionary) -> int:
	var id:= str(entry ["id"])
	if bool(entry.get("full", false)) and Cfg.DEMO and not TechTree.has_id(id):
		print("  skip  '%s' is a full game card and this is the demo" % id)
		return 0
	if not TechTree.has_id(id):
		print("  FAIL  '%s' is not in the tree" % id)
		return 1
	var read: Callable = entry ["read"]
	var spec:= TechTree.spec(id)
	var printed: Array = spec.get("values", [])
	var top:= TechTree.max_rank(id)

	var want:= PackedStringArray()
	for rank in range(0, top + 1):
		Tech.grant(id, rank)
		want.append(_render(read.call(), entry))
	Tech.grant(id, 0)

	var said:= PackedStringArray()
	said.append(str(spec.get("base", "")))
	for v: Variant in printed:
		said.append(str(v))

	if said == want:
		print("  ok    %-18s %s" % [id, " -> ".join(want)])
		return 0
	print("  FAIL  %s prints %s" % [id, " -> ".join(said)])
	print("        the yard does %s" % " -> ".join(want))
	print("        \"base\": \"%s\"," % want [0])
	print("        \"values\": [%s]," % ", ".join(
		Array(want.slice(1)).map(func(s: String) -> String: return "\"%s\"" % s)))
	return 1


func _render(value: float, entry: Dictionary) -> String:
	var fmt:= str(entry.get("fmt", "%.2f"))
	if entry.get("group", false):
		return _grouped(int(round(value)))
	if fmt.contains("%d"):
		return fmt % int(round(value))
	return fmt % value


func _grouped(n: int) -> String:
	var digits:= str(absi(n))
	var out:= ""
	var count:= 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits [i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _ladders() -> Array:
	return [
		{ "id": "hand_carry", "fmt": "%d straw",
			"read": func() -> float: return float(Tech.hand_capacity()) },
		{ "id": "arm_load", "fmt": "%d",
			"read": func() -> float: return float(Tech.carry_stack()) },
		{ "id": "toy_shovel_size", "fmt": "%d straw",
			"read": func() -> float:
				return float(Tech.scoop_max(SandShovel.SCOOP_MAX, Tech.toy_shovel_scale())) },
		{ "id": "shovel_size", "fmt": "%d straw",
			"read": func() -> float:
				return float(Tech.scoop_max(Cfg.SCOOP_MAX, Tech.spade_scale())) },
		{ "id": "fork_size", "fmt": "%d straw",
			"read": func() -> float:
				return float(Tech.scoop_max(Pitchfork.SCOOP_MAX, Tech.fork_scale())) },
		{ "id": "broom_bristles", "fmt": "%.1f",
			"read": func() -> float: return Broom.sweep_width() },
		{ "id": "bucket_size", "group": true,
			"read": func() -> float: return float(Tech.bucket_capacity()) },
		{ "id": "barrow_size", "group": true,
			"read": func() -> float: return float(Tech.barrow_capacity()) },
		{ "id": "smooth_pour", "fmt": "%d",
			"read": func() -> float: return Tech.bucket_pour_rate() },
		{ "id": "vac_bin", "group": true,
			"read": func() -> float: return float(Tech.vac_capacity()) },
		{ "id": "vac_suction", "fmt": "%d",
			"read": func() -> float: return Tech.vac_suck_rate() },
		{ "id": "belt_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.belt_speed() },
		{ "id": "compressor_batch", "fmt": "%d straw",
			"read": func() -> float: return float(Tech.compressor_bale_strands()) },
		{ "id": "compressor_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.compressor_press_seconds() },
		{ "id": "bale_quality", "fmt": "x%.2f",
			"read": func() -> float: return Tech.bale_value_ratio() },
		{ "id": "wrapper_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.wrapper_seconds() },
		{ "id": "foil_quality", "fmt": "x%.2f",
			"read": func() -> float: return Tech.foil_value_ratio() },
		{ "id": "pellet_batch", "fmt": "%d straw",
			"read": func() -> float: return float(Tech.pellet_brick_strands()) },
		{ "id": "pellet_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.pellet_cycle_seconds() },
		{ "id": "brick_quality", "fmt": "x%.2f",
			"read": func() -> float: return Tech.brick_value_ratio() },


		{ "id": "paper_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.paper_cycle_seconds() },
		{ "id": "paper_quality", "fmt": "x%.2f",
			"read": func() -> float: return Tech.paper_value_ratio() },


		{ "id": "briquette_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.briquette_cycle_seconds() },
		{ "id": "briquette_quality", "fmt": "x%.2f",
			"read": func() -> float: return Tech.disc_value_ratio() },


		{ "id": "silo_rate", "fmt": "%d",
			"read": func() -> float: return Tech.silo_max_rate() * 60.0 },
		{ "id": "silo_capacity", "fmt": "%d",
			"read": func() -> float: return float(Tech.silo_capacity()) },
		{ "id": "silo_bulk", "fmt": "%d straw",
			"read": func() -> float: return float(Tech.silo_wad_strands()) },
		{ "id": "yard_space", "fmt": "%d",
			"read": func() -> float:
				return 2.0 * (Cfg.yard_inner_for_pile() + Tech.warehouse_extra()) },
		{ "id": "rake_speed", "fmt": "%.2f",
			"read": func() -> float: return Tech.rake_throw_seconds() },
		{ "id": "detector_coil", "fmt": "%.1f m",
			"read": func() -> float: return Tech.detector_range() },
		{ "id": "drawer_space", "fmt": "%d",
			"read": func() -> float: return float(Tech.scanner_bin_capacity()) },
		{ "id": "hay_price", "fmt": "x%.2f",
			"read": func() -> float: return Tech.hay_price() / Cfg.HAY_PRICE },
		{ "id": "work_boots", "fmt": "%.2f",
			"read": func() -> float: return Player.SPEED * Tech.move_speed_scale() },
		{ "id": "strong_back", "fmt": "%d",
			"read": func() -> float: return Stamina.BASE_MAX * Tech.stamina_scale() },
		{ "id": "second_wind", "fmt": "%.1f",
			"read": func() -> float: return Stamina.REGEN * Tech.stamina_regen_scale() },
		{ "id": "easy_swing", "fmt": "%.1f",
			"read": func() -> float: return Stamina.DIG_COST * Tech.dig_effort_scale() },
		{ "id": "careful_steps", "fmt": "%.2f",
			"read": func() -> float: return Tech.crouch_speed() },
		{ "id": "grab_reach", "fmt": "%.2f",
			"read": func() -> float: return Tech.carry_reach() },
		{ "id": "build_reach", "fmt": "%.1f",
			"read": func() -> float: return Cfg.BUILD_REACH + Tech.build_reach_bonus() },
		{ "id": "jump_height", "fmt": "%.2f",
			"read": func() -> float:
				var v:= Tech.jump_velocity(Player.JUMP_VELOCITY, Player.GRAVITY)
				return v * v / (2.0 * Player.GRAVITY) },
		{ "id": "scan_solids", "fmt": "%.1f",
			"read": func() -> float:
				return Tech.scanner_block_seconds(Cfg.SCANNER_BLOCK_SECONDS) },


		{ "id": "generator_output", "fmt": "%.1f",
			"read": func() -> float: return Tech.generator_output() },
		{ "id": "firebox", "fmt": "%d straw",
			"read": func() -> float:
				return Tech.generator_firebox_kj() / Cfg.GENERATOR_KJ_PER_STRAND },


		{ "id": "gas_plant_output", "fmt": "%.0f", "full": true,
			"read": func() -> float: return Tech.gas_plant_output() },


		{ "id": "pole_span", "fmt": "%.1f",
			"read": func() -> float: return Tech.pole_link_r() },
		{ "id": "pole_drop", "fmt": "%.1f",
			"read": func() -> float: return Tech.pole_supply_r() },
	]
