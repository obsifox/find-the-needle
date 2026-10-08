class_name DevEconomyProbe
extends Node


const EXPECTED_TECH_TOTAL:= 162441.35


const EXPECTED_PHYSICAL_FLOOR:= 3594.25
const MAX_EARLY_PAYBACK_MINUTES:= 20.0
const MAX_PROCESSOR_PAYBACK_MINUTES:= 45.0


const MAX_WATER_CHAIN_PAYBACK_MINUTES:= 90.0


const WATER_CHAIN_PIPE_M:= 12.0


func run() -> void:
	var saved_ranks:= Tech.ranks.duplicate()
	var failures:= 0
	Tech.reset()
	failures += _check_totals()
	failures += _check_payback()
	failures += _check_chain()
	failures += _check_hay_left()
	failures += _check_sold_count()
	failures += _check_fees()
	Tech.ranks = saved_ranks
	Tech.tech_reset.emit()
	print("\n[economy] %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _fail(message: String) -> int:
	print("  FAIL  %s" % message)
	return 1


func _tech_total() -> float:
	var total:= 0.0
	for id: String in TechTree.ids():
		if id == TechTree.ROOT:
			continue
		for rank in TechTree.max_rank(id):
			total += TechTree.cost_at(id, rank)
	return total


func _physical_floor() -> float:
	var total:= Cfg.PRICE_SAND_SHOVEL + Cfg.PRICE_BUCKET + Cfg.PRICE_WHEELBARROW
	total += 20.0 * Cfg.BELT_COST_PER_M
	total += 4.0 * Cfg.PLATFORM_COST_PER_M2
	total += 2.0 * Cfg.STAIR_COST_PER_M
	total += 4.0 * Cfg.RAILING_COST_PER_M


	total += Cfg.SPLITTER_COST + Cfg.JOINER_COST + Cfg.CABINET_COST
	for tier: Dictionary in Cfg.ROBOT_ARM_TIERS:
		total += float(tier ["cost"])
	for tier: Dictionary in Cfg.SCANNER_TIERS:
		total += float(tier ["cost"])
	total += Cfg.COMPRESSOR_COST + Cfg.PELLETIZER_COST + Cfg.DRONE_COST
	return total


func _check_totals() -> int:
	print("\n=== economy totals ===")
	var failures:= 0
	var tech_total:= _tech_total()
	var physical:= _physical_floor()
	var completion:= tech_total + physical
	print("  tech $%s  physical floor $%s  completion floor $%s" % [
		Hud.money_text(tech_total), Hud.money_text(physical), Hud.money_text(completion)])
	if not is_equal_approx(tech_total, EXPECTED_TECH_TOTAL):
		failures += _fail("tech tree is $%s, expected $%s" % [
			Hud.money_text(tech_total), Hud.money_text(EXPECTED_TECH_TOTAL)])
	if not is_equal_approx(physical, EXPECTED_PHYSICAL_FLOOR):
		failures += _fail("physical floor is $%s, expected $%s" % [
			Hud.money_text(physical), Hud.money_text(EXPECTED_PHYSICAL_FLOOR)])


	for pair: Array in [["u_splitter", "splitter"], ["u_joiner", "joiner"]]:
		var u_cost:= BuildCatalog.cost_text(str(pair [0]))
		var y_cost:= BuildCatalog.cost_text(str(pair [1]))
		if u_cost == "" or u_cost != y_cost:
			failures += _fail("the %s card says '%s' and the %s card says '%s'"
				% [pair [0], u_cost, pair [1], y_cost])
		else:
			print("  %s and %s both %s" % [pair [0], pair [1], u_cost])
	if GameState.hay_initial > 0.0:
		var conservative_pile_value:= GameState.hay_initial * Cfg.HAY_PRICE
		print("  generated pile raw value $%s" % Hud.money_text(conservative_pile_value))
		if completion > conservative_pile_value:
			failures += _fail("completion floor exceeds the generated pile's raw value")
	return failures


func _minutes_to_repay(cost: float, extra_income_per_hour: float) -> float:
	return cost / maxf(extra_income_per_hour, 0.001) * 60.0


func _check_payback() -> int:
	print("\n=== investment payback ===")
	var failures:= 0
	var arm_rate:= Tech.arm_throughput(0)
	var raw_hour:= Tech.income_per_minute(arm_rate) * 60.0
	var arm_cost:= TechTree.cost_at("arm_small", 0) + float(Cfg.ROBOT_ARM_TIERS [0] ["cost"])
	var compressor_cost:= TechTree.cost_at("compressor", 0) + Cfg.COMPRESSOR_COST
	var pelletizer_cost:= TechTree.cost_at("pelletizer", 0) + Cfg.PELLETIZER_COST
	var arm_minutes:= _minutes_to_repay(arm_cost, raw_hour)
	var compressor_minutes:= _minutes_to_repay(compressor_cost,
		raw_hour * (Tech.bale_value_ratio() - 1.0))
	var pelletizer_minutes:= _minutes_to_repay(pelletizer_cost,
		raw_hour * (Tech.brick_value_ratio() - 1.0))


	var water_cost:= TechTree.cost_at("borehole", 0) + Cfg.BOREHOLE_COST + TechTree.cost_at("water_main", 0) + WATER_CHAIN_PIPE_M * Cfg.PIPE_COST_PER_M + TechTree.cost_at("pulper", 0) + Cfg.PULPER_COST
	var water_minutes:= _minutes_to_repay(water_cost,
		raw_hour * (Tech.pulp_value_ratio() - 1.0))
	print("  small arm %.1f min  compressor %.1f min  pelletizer %.1f min" % [
		arm_minutes, compressor_minutes, pelletizer_minutes])
	print("  water chain $%s -> %.1f min" % [
		Hud.money_text(water_cost), water_minutes])
	if arm_minutes > MAX_EARLY_PAYBACK_MINUTES:
		failures += _fail("small arm payback exceeds %.0f minutes" % MAX_EARLY_PAYBACK_MINUTES)
	if compressor_minutes > MAX_PROCESSOR_PAYBACK_MINUTES:
		failures += _fail("compressor payback exceeds %.0f minutes" % MAX_PROCESSOR_PAYBACK_MINUTES)
	if pelletizer_minutes > MAX_PROCESSOR_PAYBACK_MINUTES:
		failures += _fail("pelletizer payback exceeds %.0f minutes" % MAX_PROCESSOR_PAYBACK_MINUTES)
	if water_minutes > MAX_WATER_CHAIN_PAYBACK_MINUTES:
		failures += _fail("water chain payback exceeds %.0f minutes"
			% MAX_WATER_CHAIN_PAYBACK_MINUTES)


	if water_minutes < compressor_minutes:
		failures += _fail("the water chain repays sooner than a compressor")
	return failures


func _check_chain() -> int:
	print("\n=== throughput chain ===")
	var failures:= 0


	for tier_index in Cfg.ROBOT_ARM_TIERS.size():
		var arm: Dictionary = Cfg.ROBOT_ARM_TIERS [tier_index]
		var scanner: Dictionary = Cfg.SCANNER_TIERS [
			clampi(tier_index, 0, Cfg.SCANNER_TIERS.size() - 1)]
		var load:= Tech.arm_capacity(int(arm ["capacity"]))
		var arm_rate:= Tech.arm_throughput(tier_index)
		var scan_rate:= float(Tech.scan_batch(int(scanner ["batch"]))) / Tech.scan_seconds(float(scanner ["scan_seconds"]))
		print("  tier %d  arm %d @ %.1f/s  scanner %.1f/s buffer %d" % [
			tier_index + 1, load, arm_rate, scan_rate,
			Tech.scanner_buffer(int(scanner ["buffer"]))])
		if Tech.scanner_buffer(int(scanner ["buffer"])) < load:
			failures += _fail("scanner tier %d cannot accept its arm's load" % (tier_index + 1))
		if scan_rate < arm_rate:
			failures += _fail("scanner tier %d is slower than its arm" % (tier_index + 1))
	Tech.grant("arm_payload", TechTree.max_rank("arm_payload"))
	Tech.grant("arm_speed", TechTree.max_rank("arm_speed"))
	Tech.grant("compressor_batch", TechTree.max_rank("compressor_batch"))
	Tech.grant("compressor_speed", TechTree.max_rank("compressor_speed"))
	Tech.grant("bale_quality", TechTree.max_rank("bale_quality"))
	Tech.grant("pellet_batch", TechTree.max_rank("pellet_batch"))
	Tech.grant("pellet_speed", TechTree.max_rank("pellet_speed"))
	Tech.grant("brick_quality", TechTree.max_rank("brick_quality"))
	Tech.grant("pulper_batch", TechTree.max_rank("pulper_batch"))
	Tech.grant("pulper_speed", TechTree.max_rank("pulper_speed"))
	Tech.grant("pulp_quality", TechTree.max_rank("pulp_quality"))
	Tech.grant("foil_quality", TechTree.max_rank("foil_quality"))
	Tech.grant("wrapper_speed", TechTree.max_rank("wrapper_speed"))
	var max_arm_load:= Tech.arm_capacity(int(Cfg.ROBOT_ARM_TIERS [2] ["capacity"]))
	var max_arm_rate:= Tech.arm_throughput(2)
	var press_rate:= float(Tech.compressor_bale_strands()) / Tech.compressor_press_seconds()
	var mill_rate:= float(Tech.pellet_brick_strands()) / Tech.pellet_cycle_seconds()
	var pulp_rate:= float(Tech.pulper_batch_strands()) / Tech.pulper_cycle_seconds()
	print("  max long arm %d @ %.1f/s  max press %.1f/s  max pelletizer %.1f/s  max pulper %.1f/s" % [
		max_arm_load, max_arm_rate, press_rate, mill_rate, pulp_rate])
	if max_arm_load > Cfg.WAD_MAX_STRANDS:
		failures += _fail("max long-arm load crosses the one-wad limit")
	if press_rate < max_arm_rate:
		failures += _fail("max compressor cannot keep up with one max long arm")
	if mill_rate < max_arm_rate:
		failures += _fail("max pelletizer cannot keep up with one max long arm")


	var press_bales:= 1.0 / Tech.compressor_press_seconds()
	var wrap_bales:= 1.0 / Tech.wrapper_seconds()
	print("  max press %.3f bales/s  max wrapper %.3f bales/s" % [press_bales, wrap_bales])
	if wrap_bales < press_bales * 0.99:
		failures += _fail("max wrapper cannot keep up with one max compressor")
	if not is_equal_approx(Tech.bale_value_ratio(), 2.75):
		failures += _fail("max bale quality is not x2.75")
	if not is_equal_approx(Tech.brick_value_ratio(), 3.25):
		failures += _fail("max brick quality is not x3.25")
	if pulp_rate < max_arm_rate:
		failures += _fail("max pulper cannot keep up with one max long arm")


	var foil_max:= Tech.bale_value_ratio() * Tech.foil_value_ratio()
	print("  max slab x%.2f against a max foiled bale x%.2f (base x%.2f against x%.2f)"
		% [Tech.pulp_value_ratio(), foil_max, Cfg.PULPER_PULP_RATIO,
			Cfg.COMPRESSOR_BALE_RATIO * Cfg.WRAPPER_FOILED_RATIO])
	if Cfg.PULPER_PULP_RATIO <= Cfg.COMPRESSOR_BALE_RATIO * Cfg.WRAPPER_FOILED_RATIO:
		failures += _fail("a base slab does not beat a base foiled bale")
	if Tech.pulp_value_ratio() <= foil_max:
		failures += _fail("a fully ranked slab does not beat a fully ranked foiled bale")


	if Cfg.PULPER_PULP_RATIO >= Cfg.COMPRESSOR_BALE_RATIO * 2.0:
		failures += _fail("a slab is worth twice a bale, which retires the press")
	return failures


func _check_hay_left() -> int:
	print("\n=== hay-left readout ===")
	var failures:= 0
	var saved:= [GameState.hay_total, GameState.hay_initial, GameState.hay_dug,
		GameState.hay_sold, GameState.hay_returned]

	GameState.hay_returned = 0.0
	GameState.hay_initial = 1000.0
	GameState.hay_total = 1000.0
	GameState.hay_dug = 0.0
	GameState.hay_sold = 0.0
	if not is_equal_approx(GameState.hay_left_fraction(), 1.0):
		failures += _fail("an untouched lot does not read 100%")


	GameState.remove_hay(400.0)
	if not is_equal_approx(GameState.hay_left_fraction(), 0.6):
		failures += _fail("400 of 1000 dug does not read 60%%, it reads %.0f%%"
			% (GameState.hay_left_fraction() * 100.0))
	GameState.hay_sold = 400.0
	if not is_equal_approx(GameState.hay_left_fraction(), 0.6):
		failures += _fail("selling what was already dug moved the readout again")


	GameState.lose_hay(GameState.hay_total * 0.5)
	if not is_equal_approx(GameState.hay_left_fraction(), 0.3):
		failures += _fail("halving the pile does not show up: %.0f%% left"
			% (GameState.hay_left_fraction() * 100.0))
	if not is_equal_approx(GameState.hay_dug, 400.0):
		failures += _fail("losing hay counted as digging, which would fire missions")
	print("  1000 strands: 400 dug and sold, then the pile halved -> %.0f%% left"
		% (GameState.hay_left_fraction() * 100.0))


	GameState.hay_total = 250.0
	GameState.hay_dug = 0.0
	GameState.hay_sold = 0.0
	if not is_equal_approx(GameState.hay_left_fraction(), 0.25):
		failures += _fail("a pile that shrank before the ledger existed reads %.0f%%"
			% (GameState.hay_left_fraction() * 100.0))


	GameState.hay_total = 0.0
	if not is_equal_approx(GameState.hay_left_fraction(), 0.0):
		failures += _fail("a bare floor does not read 0%")
	GameState.hay_initial = 0.0
	if not is_equal_approx(GameState.hay_left_fraction(), 0.0):
		failures += _fail("a lot with no initial pile does not read 0%")

	GameState.hay_total = saved [0]
	GameState.hay_initial = saved [1]
	GameState.hay_dug = saved [2]
	GameState.hay_sold = saved [3]
	GameState.hay_returned = saved [4]
	return failures


func _check_sold_count() -> int:
	print("\n=== hay sold counts hay ===")
	var failures:= 0
	var saved:= [GameState.hay_sold, GameState.money, GameState.money_earned,
		GameState.best_sale, GameState.best_sale_strands, GameState.debt]

	GameState.debt = 0.0
	GameState.hay_sold = 0.0
	GameState.best_sale = 0.0
	GameState.best_sale_strands = 0.0


	var worth:= 100.0 * Tech.brick_value_ratio()
	var paid:= GameState.sell_hay(100.0, worth)
	if not is_equal_approx(GameState.hay_sold, 100.0):
		failures += _fail("a brick holding 100 strands counted %.0f sold"
			% GameState.hay_sold)
	if not is_equal_approx(paid, worth * Tech.hay_price()):
		failures += _fail("the premium did not reach the till: $%.2f paid for %.0f strand-equivalents"
			% [paid, worth])
	if not is_equal_approx(GameState.best_sale_strands, 100.0):
		failures += _fail("the records board credits that sale with %.0f strands, which is its price and not its hay"
			% GameState.best_sale_strands)


	GameState.hay_sold = 0.0
	var loose:= GameState.sell_hay(100.0)
	if not is_equal_approx(GameState.hay_sold, 100.0) or not is_equal_approx(loose, 100.0 * Tech.hay_price()):
		failures += _fail("100 loose strands counted %.0f and paid $%.2f"
			% [GameState.hay_sold, loose])


	GameState.hay_sold = 0.0
	var pile:= 1000.0
	var chain:= Tech.pulp_value_ratio() * Tech.paper_value_ratio()
	GameState.sell_hay(pile, pile * chain)
	if GameState.hay_sold > pile:
		failures += _fail("a pile of %.0f strands sold as paper counted %.0f"
			% [pile, GameState.hay_sold])
	print("  a 100-strand brick counts 100 and pays $%.2f; a pile sold as paper (x%.2f) counts the pile"
		% [worth * Tech.hay_price(), chain])


	if not is_equal_approx(GameState.capped_sold(300351890.0, 111000000.0), 111000000.0):
		failures += _fail("a save claiming more sold than it ever dug loads unchanged")
	if not is_equal_approx(GameState.capped_sold(4000.0, 5000.0), 4000.0):
		failures += _fail("a yard that sold less than it dug had its figure moved")
	if not is_equal_approx(GameState.capped_sold(4000.0, 4000.0), 4000.0):
		failures += _fail("a yard that sold exactly what it dug had its figure moved")

	if not is_equal_approx(GameState.capped_sold(12345.0, 0.0), 12345.0):
		failures += _fail("a save with no dig total came back having sold nothing")

	GameState.hay_sold = saved [0]
	GameState.money = saved [1]
	GameState.money_earned = saved [2]
	GameState.best_sale = saved [3]
	GameState.best_sale_strands = saved [4]
	GameState.debt = saved [5]
	return failures


func _check_fees() -> int:
	print("\n=== stack fees ===")
	var failures:= 0
	var raw:= GameState.hay_initial * Cfg.HAY_PRICE
	if raw <= 0.0:
		print("  no pile to price against")
		return 0
	var ceiling:= raw * 2.75 * 0.8
	var saved_ordered:= GameState.stacks_ordered
	var saved_debt:= GameState.debt
	var saved_money:= GameState.money
	var saved_earned:= GameState.money_earned
	var saved_sold:= GameState.hay_sold
	var fees: Array [float] = []
	var credits: Array [float] = []
	for n in Cfg.CONSIGNMENT_FEE_SHARES.size():
		GameState.stacks_ordered = n
		fees.append(GameState.next_stack_fee())
		credits.append(GameState.credit_stack_fee())
	var line:= ""
	for f in fees:
		line += "$%s  " % Hud.money_text(f)
	print("  loose value of this pile $%s, fees by stack: %s" % [Hud.money_text(raw), line.strip_edges()])
	for i in fees.size():
		if fees [i] <= 0.0:
			failures += _fail("stack %d is free" % (i + 2))
		if i > 0 and fees [i] <= fees [i - 1]:
			failures += _fail("stack %d is no dearer than stack %d" % [i + 2, i + 1])
		if fees [i] > ceiling:
			failures += _fail("stack %d at $%s costs more than a pile grosses on top bales ($%s with a fifth spare)"
				% [i + 2, Hud.money_text(fees [i]), Hud.money_text(ceiling)])


		if credits [i] <= fees [i]:
			failures += _fail("stack %d costs no more paid later ($%s) than paid now ($%s)"
				% [i + 2, Hud.money_text(credits [i]), Hud.money_text(fees [i])])
		if credits [i] > ceiling:
			failures += _fail("stack %d paid later at $%s costs more than a pile grosses on top bales ($%s with a fifth spare)"
				% [i + 2, Hud.money_text(credits [i]), Hud.money_text(ceiling)])
	var later:= ""
	for c in credits:
		later += "$%s  " % Hud.money_text(c)
	print("  paid later instead: %s" % later.strip_edges())
	failures += _check_paying()

	GameState.stacks_ordered = 0
	GameState.debt = 100.0
	GameState.money = 0.0
	var kept:= GameState.sell_hay(1000.0)
	var gross:= 1000.0 * Tech.hay_price()
	if not is_equal_approx(kept, gross * (1.0 - Cfg.CONSIGNMENT_PAYBACK_SHARE)):
		failures += _fail("a sale in debt kept $%.2f of $%.2f, expected the payback share held back"
			% [kept, gross])
	if not is_equal_approx(GameState.debt, 100.0 - gross * Cfg.CONSIGNMENT_PAYBACK_SHARE):
		failures += _fail("the slate is $%.2f after the sale" % GameState.debt)
	GameState.debt = 1.0
	kept = GameState.sell_hay(1000.0)
	if not is_equal_approx(kept, gross - 1.0) or GameState.debt != 0.0:
		failures += _fail("clearing the last dollar of debt kept $%.2f and left $%.2f owed"
			% [kept, GameState.debt])
	print("  a $%.2f sale in debt keeps $%.2f; the last dollar owed clears cleanly" % [gross, gross * (1.0 - Cfg.CONSIGNMENT_PAYBACK_SHARE)])
	GameState.stacks_ordered = saved_ordered
	GameState.debt = saved_debt
	GameState.money = saved_money
	GameState.money_earned = saved_earned
	GameState.hay_sold = saved_sold
	return failures


func _check_paying() -> int:
	var failures:= 0
	GameState.stacks_ordered = 0
	GameState.debt = 0.0
	var fee:= GameState.next_stack_fee()

	var fee_later:= GameState.credit_stack_fee()


	GameState.money = fee - 1.0
	if GameState.pay_for_next_stack(true):
		failures += _fail("paying now went through a dollar short")
	if GameState.stacks_ordered != 0 or GameState.debt != 0.0 or not is_equal_approx(GameState.money, fee - 1.0):
		failures += _fail("a refused pay now still moved something: %d ordered, $%.2f owed, $%.2f banked"
			% [GameState.stacks_ordered, GameState.debt, GameState.money])


	GameState.money = fee + 10.0
	if not GameState.pay_for_next_stack(true) or not is_equal_approx(GameState.money, 10.0) or GameState.debt != 0.0 or GameState.stacks_ordered != 1:
		failures += _fail("paying $%.0f now left $%.2f banked, $%.2f owed, %d ordered"
			% [fee, GameState.money, GameState.debt, GameState.stacks_ordered])


	GameState.money = 0.0
	var credit:= GameState.credit_stack_fee()
	if not GameState.pay_for_next_stack(false) or not is_equal_approx(GameState.debt, credit) or GameState.money != 0.0 or GameState.stacks_ordered != 2:
		failures += _fail("paying later with an empty bank owes $%.2f of $%.2f, banked $%.2f, %d ordered"
			% [GameState.debt, credit, GameState.money, GameState.stacks_ordered])


	GameState.money = credit * 0.25
	var paid:= GameState.pay_off_debt()
	if not is_equal_approx(paid, credit * 0.25) or GameState.money > 0.001 or not is_equal_approx(GameState.debt, credit * 0.75):
		failures += _fail("paying off with a quarter banked paid $%.2f and left $%.2f owed"
			% [paid, GameState.debt])
	GameState.money = credit
	paid = GameState.pay_off_debt()
	if not is_equal_approx(paid, credit * 0.75) or GameState.debt != 0.0 or not is_equal_approx(GameState.money, credit * 0.25):
		failures += _fail("paying off with plenty banked paid $%.2f, left $%.2f owed and $%.2f banked"
			% [paid, GameState.debt, GameState.money])
	if GameState.pay_off_debt() != 0.0:
		failures += _fail("paying off with nothing owed still took money")
	print("  one load: pay now $%s or later $%s; a short bank is refused, and the slate pays off in part or whole"
		% [Hud.money_text(fee), Hud.money_text(fee_later)])
	return failures
