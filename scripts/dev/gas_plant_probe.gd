class_name DevGasPlantProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40

const REBUILD_FRAMES:= 8
const LANE_X:= 13.0
const BRICK_STRANDS:= 45

var _pass:= 0
var _fail:= 0
var _deck_y:= 0.0


func run() -> void:
	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	player.global_position = Vector3(8.5, 0.4, 16.0)
	GameState.add_money(100000.0)


	var was_demo:= Cfg.DEMO
	Cfg.DEMO = false
	_rebuild_tech_table()
	Tech.grant("pelletizer", 1)
	Tech.grant("water_main", 1)
	Tech.grant("gas_plant", 1)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	await _case_the_card()
	await _case_the_machine()
	await _case_bricks_only()
	await _case_the_blade()
	await _case_output_follows_the_feed()
	await _case_half_water()
	await _case_dry()
	await _case_the_flange()
	await _case_the_pump_is_a_feeder()
	await _case_a_cold_start_on_a_dark_line()
	await _case_the_stuck_state()
	await _case_the_dead_yard()
	await _case_money()
	await _case_save_round_trip()

	Cfg.DEMO = was_demo
	print("\n[gasplant] %d passed, %d failed" % [_pass, _fail])
	print("[gasplant] %s" % ("PASS" if _fail == 0 else "FAIL"))
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_card() -> void:
	print("\n=== the card ===")
	var needs:= TechTree.requires("gas_plant")
	_check("it needs the pelletizer and the water main (%s)" % [needs],
		needs.has("pelletizer") and needs.has("water_main"))
	_check("the card costs $%d" % int(Cfg.GAS_PLANT_CARD_COST),
		is_equal_approx(TechTree.cost_at("gas_plant", 0), Cfg.GAS_PLANT_CARD_COST))
	_check("it sells the Gas Plant", BuildCatalog.builds_for("gas_plant").has("gas_plant"))
	_check("owned in the full game, it can be built", Tech.has_gas_plant()
		and BuildCatalog.is_unlocked("gas_plant"))

	var spec:= TechTree.spec("gas_plant_output")
	var values: Array = spec.get("values", [])
	_check("the rank card starts at %s kW" % str(spec.get("base", "")),
		str(spec.get("base", "")) == "%.0f" % Tech.gas_plant_output())
	for r in values.size():
		Tech.grant("gas_plant_output", r + 1)
		_check("rank %d: the card says %s and a plant makes %.0f"
			% [r + 1, str(values [r]), Tech.gas_plant_output()],
			str(values [r]) == "%.0f" % Tech.gas_plant_output())
	_check("the top rank is 250 kW", is_equal_approx(Tech.gas_plant_output(), 250.0))
	Tech.grant("gas_plant_output", 0)


	var was_demo:= Cfg.DEMO
	Cfg.DEMO = true
	_rebuild_tech_table()
	_check("in the demo the card is a padlock (kind %s)" % TechTree.kind_of("gas_plant"),
		TechTree.is_demo("gas_plant"))
	_check("...with no price on it", (TechTree.spec("gas_plant").get("costs", [0]) as Array).is_empty())
	_check("...and no Bigger Gas Plant folded under it", not TechTree.has_id("gas_plant_output"))
	_check("...and the catalogue withholds the machine",
		BuildCatalog.is_withheld("gas_plant") and not BuildCatalog.is_unlocked("gas_plant"))
	_check("...even for a full game save that owns the card (rank %d)" % Tech.rank_of("gas_plant"),
		Tech.rank_of("gas_plant") > 0 and not Tech.has_gas_plant())


	await _clear_yard()
	world.builds.from_array([{ "type": "gas_plant",
		"position": Vector3(LANE_X, 0.0, 0.0), "yaw": 0.0, "fuel": 77.0 }])
	await _settle()
	_check("...and a full save's plant is not built in the demo",
		not world.builds.generators.any(func(g: Node) -> bool: return g is GasPlant))
	var rows: Array = world.builds.to_array().filter(func(r: Variant) -> bool:
		return typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("type", "")) == "gas_plant")
	_check("...but is written back out with its hopper (%d row)" % rows.size(),
		rows.size() == 1 and is_equal_approx(float((rows [0] as Dictionary).get("fuel", 0.0)), 77.0))
	await _clear_yard()
	Cfg.DEMO = was_demo
	_rebuild_tech_table()
	_check("back in the full game it is a card again", not TechTree.is_demo("gas_plant")
		and Tech.has_gas_plant())


func _rebuild_tech_table() -> void:
	TechTree._nodes.clear()
	TechTree._order.clear()
	var _nodes:= TechTree.nodes()


func _case_the_machine() -> void:
	print("\n=== the machine ===")
	await _clear_yard()
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	_check("it stands in the generators list", world.builds.generators.has(plant))
	if plant._model == null:
		print("  [note] the model is not on disk; the markers' fallbacks are in use")
	else:
		for marker: String in [GasPlant.N_BELT_IN, GasPlant.N_PLANT_BELT_HEAD,
				GasPlant.N_WATER_IN, GasPlant.N_POWER_OUT, GasPlant.N_HEARTH]:
			_check("the model has %s" % marker, plant._find(marker) != null)
	var port:= plant.to_local(plant.intake_port())
	_check("its port is the generator's: PORT_BACK back, PORT_UP up (%s)" % port,
		port.distance_to(Vector3(0.0, HayGenerator.PORT_UP, - HayGenerator.PORT_BACK)) < 0.01)
	_check("its feed is marker to marker, 0.70 m (%.3f)" % plant.feed_length(),
		absf(plant.feed_length() - 0.7) < 0.01)
	_check("travel is +Z as placed", plant.forward().dot(Vector3.BACK) > 0.99)
	_check("it lays a deck of its own, a terminus",
		plant.deck() != null and plant.deck().downstream == null)
	_check("its deck gathers no tufts, so a blade asks the plant",
		not plant.deck().gathers_straw
			and LiveStrandManager.straw_taker_of(plant.deck()) == plant)
	_check("it has one power port, on the take-off (%s)" % plant.to_local(plant.power_ports() [0].global_position),
		plant.power_ports().size() == 1
			and plant.to_local(plant.power_ports() [0].global_position).distance_to(GasPlant.POWER_OUT_AT) < 0.05)
	_check("it has one flange, at the back of the skid",
		plant.water_ports().size() == 1
			and plant.to_local(plant.water_port()).distance_to(GasPlant.WATER_IN_AT) < 0.05)
	_check("the flange faces out of the bore, along +Z",
		plant.water_port_bearing(plant.water_ports() [0]).dot(Vector3.BACK) > 0.99)
	_check("a new plant is delivered with its tank full (%.1f of %.1f l)"
		% [plant.tank, plant.tank_capacity()],
		is_equal_approx(plant.tank, plant.tank_capacity()))
	_check("sixty seconds of tank at the cap (%.1f s)" % plant.tank_seconds(),
		absf(plant.tank_seconds() - Cfg.GAS_PLANT_TANK_SECONDS) < 0.01)
	_check("it is its own catalogue entry (%s)" % world.builds.id_of(plant),
		world.builds.id_of(plant) == "gas_plant")
	_check("a generator cannot stand inside it",
		world.builds.generator_overlap(Vector3(LANE_X, 0.0, 2.0), Vector3.BACK))
	_check("...nor another plant beside it, a metre off",
		world.builds.generator_overlap(Vector3(LANE_X + 2.0, 0.0, 0.0), Vector3.BACK, null, true))
	_check("...but one clear of its skid can",
		not world.builds.generator_overlap(Vector3(LANE_X - 3.2, 0.0, 0.0), Vector3.BACK, null, true))


	var ghost:= GasPlant.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.setup(Vector3(LANE_X, 0.0, -9.0), 0.0)
	for i in 8:
		await get_tree().physics_frame
	var drawn:= ghost.ghost_run()
	_check("the ghost draws its intake from the port to the head",
		not drawn.is_empty()
			and (drawn ["from"] as Vector3).distance_to(ghost.intake_port()) < 0.02
			and (drawn ["to"] as Vector3).distance_to(ghost.belt_head()) < 0.02)
	_check("the ghost is not solid and grows no mouths",
		ghost._body.collision_layer == 0 and ghost.deck() == null and ghost._intake == null)
	_check("a ghost never reports a fault", ghost.alert_reason() == "")
	ghost.queue_free()
	await _clear_yard()


func _case_bricks_only() -> void:
	print("\n=== bricks only ===")
	await _clear_yard()
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	var start:= plant.intake_port() - plant.forward() * 4.0
	start.y = _deck_y
	var run: Conveyor = world.builds.add_conveyor(start, plant.intake_port())
	await _settle()
	_check("the run hands to the plant's deck", run.downstream == plant.deck())
	_check("a brick record is fuel, at 3 kJ a straw",
		is_equal_approx(plant.worth_of(BeltRun.Kind.BRICK, BRICK_STRANDS), BRICK_STRANDS * 3.0))
	for kind: int in [BeltRun.Kind.WAD, BeltRun.Kind.BALE, BeltRun.Kind.FOILED_BALE,
			BeltRun.Kind.DISC]:
		_check("record kind %d is worth nothing here" % kind, plant.worth_of(kind, 60) == 0.0)
	_check("loose straw is worth nothing here", plant.loose_worth() == 0.0)


	plant.fuel = 0.0
	for i in 3:
		var _b: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
			start + plant.forward() * (0.4 + 0.9 * i) + Vector3.UP * 0.4),
			{ "strands": BRICK_STRANDS })
	var want:= 3.0 * BRICK_STRANDS * Cfg.GAS_PLANT_KJ_PER_STRAND
	var got:= await _until(func() -> bool: return plant.fuel >= want * 0.98, 20.0)
	_check("three bricks by belt are %.0f kJ in the hopper (%.1f)" % [want, plant.fuel], got)

	var before:= plant.fuel
	var _hand: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
		plant.hopper_position() + Vector3.UP * 0.9), { "strands": BRICK_STRANDS })
	var in_by_hand:= func() -> bool: return plant.fuel >= before + BRICK_STRANDS * 3.0 * 0.98
	got = await _until(in_by_hand, 8.0)
	_check("a brick by hand is %.0f kJ (%.1f)" % [BRICK_STRANDS * 3.0, plant.fuel - before], got)


	var kinds:= { "hay_wad": BeltRun.Kind.WAD, "hay_bale": BeltRun.Kind.BALE,
		"foiled_bale": BeltRun.Kind.FOILED_BALE, "feed_disc": BeltRun.Kind.DISC }
	for id: String in kinds:
		var held:= plant.fuel
		var item: Carryable = world.props.spawn(id, Transform3D(Basis(),
			start + plant.forward() * 0.6 + Vector3.UP * 0.5), { "strands": 40 })
		if item == null:
			_check("spawned a %s" % id, false)
			continue
		var name:= Cfg.lower_in_english(item.display_name)
		var sign_up:= func() -> bool: return plant.alert_reason().begins_with("BRICKS ONLY")
		var signed:= await _until(sign_up, 15.0)
		_check("a %s is refused with the sign: %s" % [id, plant.alert_reason()],
			signed and plant.alert_reason().contains(name))
		_check("...the jam sign, up at once", plant.alert_icon() == "jam")
		_check("...the deck is held behind it", plant.deck().is_blocked())
		_check("...it waits at the front of the deck, not burnt (kind %d)" % plant.deck().front_kind(),
			plant.deck().front_kind() == int(kinds [id]))
		_check("...and nothing went in (%.1f kJ, was %.1f)" % [plant.fuel, held],
			plant.fuel <= held + 0.01)

		var any:= func(_k: int, _s: int) -> bool: return true
		var _off:= plant.deck().take_record(any, 0.0, plant.deck().path_length())
		var rider:= plant.deck().waiting_rider()
		if rider is Carryable:
			world.props.remove(rider as Carryable)
		await _frames(int(GasPlant.WRONG_FUEL_SHOW * 60.0) + 30)
		_check("...and once it is taken away the sign comes down (%s)" % plant.alert_reason(),
			not plant.alert_reason().begins_with("BRICKS ONLY"))


	var rng:= RandomNumberGenerator.new()
	rng.seed = 20260923
	var loose: Array [RigidBody3D] = []
	var held_loose:= plant.fuel
	for i in 12:
		var sb: RigidBody3D = world.live.spawn(plant.intake_port()
			+ plant.forward() * rng.randf_range(0.1, 0.6)
			+ Vector3(rng.randf_range(-0.2, 0.2), 0.5, 0.0),
			StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if sb != null:
			loose.append(sb)
	var loose_sign:= func() -> bool: return plant.alert_reason().begins_with("BRICKS ONLY")
	var signed_loose:= await _until(loose_sign, 8.0)
	_check("loose straw at the mouth is refused with the sign", signed_loose)
	var eaten:= 0
	for sb in loose:
		if not is_instance_valid(sb) or not sb.is_inside_tree():
			eaten += 1
	_check("...and none of it was eaten (%d of %d)" % [eaten, loose.size()],
		eaten == 0 and plant.fuel <= held_loose + 0.01)
	for sb in loose:
		if is_instance_valid(sb) and sb.is_inside_tree():
			world.live.consume(sb)
	await _clear_yard()


func _case_the_blade() -> void:
	print("\n=== a blade of loose hay ===")
	await _clear_yard()
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	var taker:= LiveStrandManager.straw_taker_of(plant.deck())
	_check("the blade asks the plant, not its deck", taker == plant)
	_check("...and is told there is no room, ever (%d)" % plant.straw_room(),
		plant.straw_room() == 0)

	_check("...and it answers the blade's refusal", plant.has_method("refuse_straw"))
	plant.refuse_straw()
	_check("...so the plant puts BRICKS ONLY up: %s" % plant.alert_reason(),
		plant.alert_reason().begins_with("BRICKS ONLY")
			and plant.alert_reason().contains("eco bricks"))
	_check("...with the jam sign, at once", plant.alert_icon() == "jam")
	await _frames(int(GasPlant.WRONG_FUEL_SHOW * 60.0) + 30)
	_check("...and it comes down again", not plant.alert_reason().begins_with("BRICKS ONLY"))
	await _clear_yard()


func _case_output_follows_the_feed() -> void:
	print("\n=== the output is the brick feed times 3.0, up to the cap ===")
	await _clear_yard()
	world.builds.grid.unmetered = true
	world.builds.water.unmetered = true
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	plant.fuel = 0.0


	var fed:= await _feed_rate(plant, 30.0, 12.0)
	_check("30 straws a second of brick makes 90 kW (%.1f)" % fed, absf(fed - 90.0) < 9.0)
	plant.fuel = 0.0
	fed = await _feed_rate(plant, 60.0, 12.0)
	_check("60 a second is 180 kW of fuel, and the cap holds it at 100 (%.1f)" % fed,
		absf(fed - 100.0) < 3.0)
	Tech.grant("gas_plant_output", 6)
	plant.fuel = plant.capacity()
	await _frames(90)
	_check("a full hopper at the top rank makes 250 kW (%.1f)" % plant.output_kw(),
		absf(plant.output_kw() - 250.0) < 1.0)
	Tech.grant("gas_plant_output", 0)
	world.builds.grid.unmetered = false
	world.builds.water.unmetered = false
	await _clear_yard()


func _feed_rate(plant: GasPlant, strands_per_s: float, seconds: float) -> float:
	var every:= float(BRICK_STRANDS) / strands_per_s
	var clock:= 0.0
	var sum:= 0.0
	var n:= 0
	var frames:= int(seconds * 60.0)
	for f in frames:
		clock += 1.0 / 60.0
		if clock >= every:
			clock -= every
			var _b: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
				plant.hopper_position() + Vector3.UP * 0.8), { "strands": BRICK_STRANDS })
		await get_tree().physics_frame
		if f > frames / 2:
			sum += plant.output_kw()
			n += 1
	return sum / maxf(float(n), 1.0)


func _case_half_water() -> void:
	print("\n=== half watered, it makes half ===")
	await _clear_yard()
	world.builds.grid.unmetered = true
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	plant.fuel = plant.capacity()
	plant.tank = 0.0
	var low:= INF
	var high:= 0.0
	for f in 240:
		plant.set_water(0.5)
		plant.fuel = plant.capacity()
		await get_tree().physics_frame
		if f > 60:
			low = minf(low, plant.output_kw())
			high = maxf(high, plant.output_kw())
	_check("half the water makes half the cap (%.1f to %.1f kW)" % [low, high],
		absf(low - 50.0) < 1.5 and absf(high - 50.0) < 1.5)
	_check("...and the grid is told it can deliver half (%.1f)" % plant.deliverable_kw(),
		absf(plant.deliverable_kw() - 50.0) < 1.5)
	world.builds.grid.unmetered = false
	await _clear_yard()


func _case_dry() -> void:
	print("\n=== a dry plant runs on its tank, then stops ===")
	await _clear_yard()
	world.builds.grid.unmetered = true
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	_check("with no pipe on its flange the grid pushes it no water",
		plant.water == 0.0 and plant.water_blocked)
	plant.fuel = plant.capacity()
	await _frames(60)
	_check("...and it runs on its tank at the cap (%.1f kW, %.0f s left)"
		% [plant.output_kw(), plant.tank_seconds()],
		absf(plant.output_kw() - plant.rated_output_kw()) < 1.0)
	_check("...with no sign while the tank lasts", plant.alert_reason() == "")
	var ran:= 1.0
	while plant.tank > 0.0 and ran < 75.0:
		plant.fuel = plant.capacity()
		await get_tree().physics_frame
		ran += 1.0 / 60.0
	_check("the tank lasted about a minute at the cap (%.1f s)" % ran,
		absf(ran - Cfg.GAS_PLANT_TANK_SECONDS) < 2.0)
	await _frames(20)
	_check("then it stops (%.2f kW)" % plant.output_kw(), plant.output_kw() < 0.01)
	_check("...and says so: %s" % plant.alert_reason(),
		plant.alert_reason() == "NO WATER  ·  run a water pipe onto its flange")
	_check("...under the water sign", plant.alert_icon() == "water")
	world.builds.grid.unmetered = false
	await _clear_yard()


func _case_the_flange() -> void:
	print("\n=== the flange ===")
	await _clear_yard()
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var pump: BoreholePump = world.builds.add_borehole(Vector3(LANE_X, 0.0, 9.0), 0.0)
	await _settle()
	var near:= plant.water_port() + Vector3(0.25, 0.1, 0.2)
	_check("a run end dropped near the flange snaps onto it",
		world.builds.snap_water_endpoint(near).distance_to(plant.water_port()) < 0.001)
	_check("...and the flange is where BuildManager looks for one",
		world.builds.nearest_flange(near).distance_to(plant.water_port()) < 0.001)
	_check("...facing out along +Z, so the last stub runs straight onto it",
		world.builds.water_port_bearing_at(plant.water_port()).dot(Vector3.BACK) > 0.99)
	var _main: WaterMain = world.builds.add_water_main(pump.water_port(), plant.water_port())
	await _settle()
	await _settle()
	var net: int = world.builds.water.network_of(plant)
	_check("a main from the pump puts the plant on the pump's network",
		net >= 0 and net == world.builds.water.network_of(pump))
	_check("...and the plant is no longer blocked", not plant.water_blocked)
	await _clear_yard()


func _case_the_pump_is_a_feeder() -> void:
	print("\n=== a pump plumbed to a plant is a feeder ===")
	await _clear_yard()
	var yard:= await _plant_yard()
	var plant: GasPlant = yard ["plant"]
	var pump: BoreholePump = yard ["pump"]
	var press: HayCompressor = yard ["press"]
	var grid: PowerGrid = world.builds.grid
	_check("the pump, the press and the plant are one network",
		grid.network_of(pump) >= 0 and grid.network_of(pump) == grid.network_of(press)
			and grid.network_of(pump) == grid.network_of(plant))
	_check("the pump is filed as a feeder", grid.is_feeder(pump))
	_check("the press is not", not grid.is_feeder(press))
	for f in 240:
		plant.fuel += 6.0 / 60.0
		await get_tree().physics_frame
	var got: Dictionary = grid.report(press)
	_check("the line is short (everything at %d%%)" % int(round(float(got ["satisfaction"]) * 100.0)),
		float(got ["satisfaction"]) < 0.9)
	_check("...so the press is slowed to it (%.3f)" % press.power, press.power < 0.9)
	_check("...and the pump is NOT: it runs at 1.0 (%.3f)" % pump.power, pump.power > 0.999)
	await _clear_yard()


func _case_a_cold_start_on_a_dark_line() -> void:
	print("\n=== a cold plant starts on a dark line ===")
	await _clear_yard()
	var yard:= await _plant_yard()
	var plant: GasPlant = yard ["plant"]
	var pump: BoreholePump = yard ["pump"]
	var press: HayCompressor = yard ["press"]
	var grid: PowerGrid = world.builds.grid
	await _frames(60)
	_check("the line is dark: nothing makes anything (%.2f kW)" % float(grid.report(press) ["supply"]),
		float(grid.report(press) ["supply"]) <= 0.0 and press.power == 0.0 and pump.power == 0.0)
	_check("...and the plant is cold with a full tank",
		plant.fuel <= 0.0 and is_equal_approx(plant.tank, plant.tank_capacity()))
	for i in 3:
		var _b: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
			plant.hopper_position() + Vector3.UP * (0.8 + 0.4 * i)), { "strands": BRICK_STRANDS })
	var lit:= await _until(func() -> bool: return press.power > 0.99, 10.0)
	_check("three bricks by hand light it and the line comes up (press %.2f)" % press.power, lit)
	_check("...the pump runs at once, a feeder (%.2f)" % pump.power, pump.power > 0.99)
	var flowing:= await _until(func() -> bool: return plant.water > 0.99, 5.0)
	_check("...and water reaches the plant (%.2f)" % plant.water, flowing)

	await _clear_yard()


func _case_the_stuck_state() -> void:
	print("\n=== the stuck state, and the way out ===")
	await _clear_yard()
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var press: HayCompressor = world.builds.add_compressor(Vector3(LANE_X, _deck_y, -5.0), 0.0)

	var pump: BoreholePump = world.builds.add_borehole(Vector3(LANE_X, 0.0, -12.0), 0.0)
	var gen: HayGenerator = world.builds.add_generator(Vector3(9.5, 0.0, -13.0), 0.0)
	await _settle()
	plant.fuel = 0.0
	gen.fuel = 0.0
	var _main: WaterMain = world.builds.add_water_main(pump.water_port(), plant.water_port())
	var _p1: PowerPole = await _pole(Vector3(LANE_X + 2.8, 0.0, 1.0))
	var _p2: PowerPole = await _pole(Vector3(LANE_X + 2.8, 0.0, -4.5))
	var _p3: PowerPole = await _pole(Vector3(11.2, 0.0, -13.8))
	await _settle()
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("the pump and the Hay Generator are one line, the plant and the press another (%d %d / %d %d)"
		% [grid.network_of(pump), grid.network_of(gen), grid.network_of(plant), grid.network_of(press)],
		grid.network_of(pump) >= 0 and grid.network_of(pump) == grid.network_of(gen)
			and grid.network_of(plant) == grid.network_of(press)
			and grid.network_of(pump) != grid.network_of(plant))
	_check("the pump is plumbed to the plant, so it is the plant's feeder",
		world.builds.water.network_of(pump) == world.builds.water.network_of(plant)
			and grid.is_feeder(pump))


	plant.tank = 0.4
	for i in 2:
		var _b: Carryable = world.props.spawn("eco_brick", Transform3D(Basis(),
			plant.hopper_position() + Vector3.UP * (0.8 + 0.4 * i)), { "strands": BRICK_STRANDS })
	var ran:= await _until(func() -> bool: return press.power > 0.99, 8.0)
	_check("it runs on what is in its tank (press %.2f)" % press.power, ran)
	var dry:= await _until(func() -> bool: return plant.output_kw() <= 0.0, 30.0)
	await _frames(30)
	_check("then the tank is empty and it stops, bricks still in it (%.2f kW, %.0f kJ)"
		% [plant.output_kw(), plant.fuel], dry and plant.fuel > 0.0 and press.power <= 0.0)
	_check("...and says what to do: %s" % plant.alert_reason(),
		plant.alert_reason() == "NO WATER  ·  get the pump running, feed a Hay Generator on its line")
	_check("...under the water sign", plant.alert_icon() == "water")
	await _fork_into(gen)
	var saved:= await _until(func() -> bool: return plant.output_kw() > 1.0, 20.0)
	_check("one forkful into the Hay Generator on the pump's line: the pump runs and the plant starts (%.1f kW)"
		% plant.output_kw(), saved)
	_check("...and the press on the plant's line is back (%.2f)" % press.power, press.power > 0.99)
	await _clear_yard()


func _plant_yard() -> Dictionary:
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var pump: BoreholePump = world.builds.add_borehole(Vector3(LANE_X, 0.0, 9.0), 0.0)
	var press: HayCompressor = world.builds.add_compressor(Vector3(LANE_X, _deck_y, -6.0), 0.0)
	await _settle()
	plant.fuel = 0.0
	var _main: WaterMain = world.builds.add_water_main(pump.water_port(), plant.water_port())
	for z: float in [-6.0, 1.0, 8.0]:
		var _p: PowerPole = await _pole(Vector3(LANE_X + 2.8, 0.0, z))
	await _settle()
	await _settle()
	return { "plant": plant, "pump": pump, "press": press }


func _case_the_dead_yard() -> void:
	print("\n=== a dead yard, and one forkful ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(Vector3(LANE_X, 0.0, 9.0), 0.0)
	var tank: HaySilo = world.builds.add_silo(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var press: HayCompressor = world.builds.add_compressor(Vector3(LANE_X, _deck_y, -7.0), 0.0)
	await _settle()
	tank.stop()
	gen.fuel = 0.0
	var out: Conveyor = world.builds.add_conveyor(tank.port_out(), gen.intake_port())
	for z: float in [-6.0, 0.0, 6.0, 10.0]:
		var _p: PowerPole = await _pole(Vector3(LANE_X + 2.8, 0.0, z))
	await _settle()
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("the silo empties into the generator", tank.deck().downstream == out
		and out.downstream == gen.deck())
	_check("...and is not exempt from the line for it", not grid.is_feeder(tank))

	tank.stored = 2400
	tank.set_rate(tank.rate_max())
	await _frames(180)
	_check("the yard is dead: generator %.2f kW, press %.2f, silo %.2f"
		% [gen.output_kw(), press.power, tank.power],
		gen.output_kw() <= 0.0 and press.power == 0.0 and tank.power == 0.0)
	_check("...and the silo, with 2400 straws in it, has let none out (%d)" % tank.stored,
		tank.stored == 2400)
	await _fork_into(gen)
	var fired:= await _until(func() -> bool: return gen.is_burning(), 6.0)
	_check("one forkful into the hopper lights it", fired)
	var fed:= await _until(func() -> bool: return tank.stored < 2400, 6.0)
	_check("...the silo runs at once (%.2f) and lets hay out (%d)"
		% [tank.power, tank.stored], fed and tank.power > 0.0)
	var back:= await _until(func() -> bool: return press.power > 0.99, 30.0)
	_check("...and the whole yard comes back on its own (press %.2f, generator %.1f kW)"
		% [press.power, gen.output_kw()], back)
	await _frames(600)
	_check("ten seconds on it is still running off the silo, not the fork (%.1f kJ in the box)"
		% gen.fuel, press.power > 0.99 and gen.is_burning())
	await _clear_yard()


func _fork_into(gen: HayGenerator) -> void:
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7011
	var over:= gen.hopper_position() + Vector3.UP * 0.7
	for i in 100:
		var _sb: RigidBody3D = world.live.spawn(over + Vector3(rng.randf_range(-0.3, 0.3),
			rng.randf_range(0.0, 0.5), rng.randf_range(-0.2, 0.2)),
			StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	await _frames(10)


func _case_money() -> void:
	print("\n=== flat prices ===")
	await _clear_yard()
	_check("a Gas Plant is $%d" % int(Cfg.GAS_PLANT_COST),
		is_equal_approx(world.builds.gas_plant_price(), Cfg.GAS_PLANT_COST))
	var bills: Array [float] = []
	for i in 6:
		var gen: HayGenerator = world.builds.add_generator(
			Vector3(LANE_X - 1.0 + 2.0 * float(i % 2), 0.0, -12.0 + 5.0 * float(i / 2)), 0.0)
		bills.append(gen.build_cost())
	_check("six Hay Generators cost $150 each, however many stand (%s)" % [bills],
		bills.count(Cfg.GENERATOR_COST) == 6
			and is_equal_approx(world.builds.generator_price(), Cfg.GENERATOR_COST))
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 9.0), 0.0)
	await _settle()
	_check("the plant was billed its own price", is_equal_approx(plant.build_cost(), Cfg.GAS_PLANT_COST))
	var refund: float = world.builds._demolish(world.builds.generators [0])
	_check("a generator taken down beside a plant refunds $150, not the plant's bill ($%.0f)" % refund,
		is_equal_approx(refund, Cfg.GENERATOR_COST))
	refund = world.builds._demolish(plant)
	_check("the plant refunds its own $%d ($%.0f)" % [int(Cfg.GAS_PLANT_COST), refund],
		is_equal_approx(refund, Cfg.GAS_PLANT_COST))
	await _clear_yard()


func _case_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	await _clear_yard()
	_check("the save format is version 11", SaveManager.FORMAT_VERSION == 11)
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 0.0), 0.0)
	await _settle()
	plant.fuel = 1234.0
	plant.tank = 12.5
	plant.set_switched_off(true)
	var d:= plant.to_dict()
	_check("it saves as a gas_plant", str(d.get("type", "")) == "gas_plant")
	_check("...with no port reach, the model's own port", not d.has("port_reach"))
	var rows: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	world.builds.from_array(rows)
	await _settle()
	var back: GasPlant = null
	for gen in world.builds.generators:
		if gen is GasPlant:
			back = gen
	_check("it comes back as a Gas Plant", back != null)
	if back != null:
		_check("...with its hopper (%.1f)" % back.fuel, is_equal_approx(back.fuel, 1234.0))
		_check("...its tank (%.2f)" % back.tank, absf(back.tank - 12.5) < 0.01)
		_check("...its bill", is_equal_approx(back.build_cost(), Cfg.GAS_PLANT_COST))
		_check("...and its switch", back.is_switched_off())
		_check("...in the same place", back.global_position.distance_to(Vector3(LANE_X, 0.0, 0.0)) < 0.01)


	world.builds.clear()
	await _settle()
	world.builds.from_array([{ "type": "hay_generator", "position": Vector3(LANE_X, 0.0, 0.0),
		"yaw": 0.0, "paid": 2500000.0, "fuel": 0.0, "port_reach": HayGenerator.PORT_REACH }])
	await _settle()
	var old: HayGenerator = world.builds.generators [0] if not world.builds.generators.is_empty() else null
	_check("an old generator billed $2,500,000 loads", old != null and not (old is GasPlant))
	if old != null:
		_check("...with its bill clamped to $150 ($%.0f)" % old.paid_cost,
			is_equal_approx(old.paid_cost, Cfg.GENERATOR_COST))
		var refund: float = world.builds._demolish(old)
		_check("...so taking it down refunds $150 ($%.0f)" % refund,
			is_equal_approx(refund, Cfg.GENERATOR_COST))
	await _clear_yard()


func _pole(at: Vector3) -> PowerPole:
	var pole: PowerPole = world.builds.add_power_pole(at, 0.0)
	await _settle()
	return pole


func _clear_yard() -> void:
	world.builds.clear()
	world.props.clear()
	await _settle()


func _settle() -> void:
	for i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(test: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if bool(test.call()):
			return true
		await get_tree().physics_frame
	return bool(test.call())


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
