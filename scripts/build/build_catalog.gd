class_name BuildCatalog
extends RefCounted


const CATEGORIES:= [
	{ "id": "excavation", "name": "Excavation" },
	{ "id": "haulage", "name": "Haulage" },
	{ "id": "processing", "name": "Processing" },
	{ "id": "power", "name": "Power" },


	{ "id": "water", "name": "Water" },
	{ "id": "structure", "name": "Structure" },
	{ "id": "prospecting", "name": "Prospecting" },
]


const DEFAULT_FAVOURITES:= ["belt", "arm", "deck", "stair", "scanner"]

static var _entries: Dictionary = { }


static func _arm_entry(tier: int, name: String, short: String, unlock: String) -> Dictionary:
	var model: Dictionary = Cfg.ROBOT_ARM_TIERS [tier]
	return {
		"name": name,
		"unlock": unlock,
		"short": short,
		"category": "excavation",
		"mode": BuildTool.Mode.ROBOTIC_ARM,
		"arm_tier": tier,
		"cost": Cfg.tr("from $%d") % int(model ["cost"]),
		"blurb": (Cfg.tr("Picks up hay and puts it on a belt. Reaches %.1f m. The first %d cost the normal price, then each one costs more. Max %d.")
			% [float(model ["reach"]), Cfg.ARM_COST_FREE, Cfg.ARM_LIMIT]),
		"upgrades": ["arm_payload", "arm_speed"],
		"place": Cfg.tr("Place robotic arm"),
	}


static func entries() -> Dictionary:
	if _entries.is_empty():
		_entries = {
			"belt": {
				"name": Cfg.tr("Conveyor Belt"),
				"unlock": "belt",
				"short": Cfg.tr("BELT"),
				"category": "haulage",
				"mode": BuildTool.Mode.CONVEYOR,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.BELT_COST_PER_M),
				"blurb": Cfg.tr("Carries loose hay along the floor. Click one end, then the other."),


				"run_start": Cfg.tr("Start run"),
				"run_place": Cfg.tr("Place run"),
			},
			"enclosed_belt": {
				"name": Cfg.tr("Enclosed Conveyor"),
				"unlock": "enclosed_belt",
				"short": Cfg.tr("TUNNEL"),
				"category": "haulage",
				"mode": BuildTool.Mode.ENCLOSED_CONVEYOR,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.ENCLOSED_BELT_COST_PER_M),
				"blurb": Cfg.tr("Hides packaged cargo inside a sealed tunnel to save performance. Loose hay cannot enter."),
				"run_start": Cfg.tr("Start run"),
				"run_place": Cfg.tr("Place run"),
			},


			"arm": _arm_entry(0, Cfg.tr("Small Arm"), Cfg.tr("ARM"), "arm_small"),
			"arm_standard": _arm_entry(1, Cfg.tr("Standard Arm"), Cfg.tr("STD ARM"),
				"arm_standard"),
			"arm_long": _arm_entry(2, Cfg.tr("Long-Reach Arm"), Cfg.tr("LONG ARM"),
				"arm_long"),
			"drone": {
				"name": Cfg.tr("Hay Drone"),
				"unlock": "drone",
				"short": Cfg.tr("DRONE"),
				"category": "haulage",
				"mode": BuildTool.Mode.HAY_DRONE,


				"cost": Cfg.tr("from $%d") % int(Cfg.DRONE_COST),
				"blurb": (Cfg.tr("Digs the pile in a zone you choose and flies the hay to a drop point, up to %.0f m from its pad. Each one costs more than the last. Max %d.")
					% [Cfg.DRONE_RADIUS, Cfg.DRONE_LIMIT]),
				"place": Cfg.tr("Place drone"),
				"note": Cfg.tr("works the circle drawn on the ground"),
			},
			"deck": {
				"name": Cfg.tr("Platform"),
				"unlock": "deck",
				"short": Cfg.tr("DECK"),
				"category": "structure",
				"mode": BuildTool.Mode.PLATFORM,
				"cost": Cfg.tr("$%d per m2") % int(Cfg.PLATFORM_COST_PER_M2),
				"blurb": Cfg.tr("A floor you can walk on. Click two corners."),
				"run_start": Cfg.tr("Start corner"),
				"run_place": Cfg.tr("Place deck"),
			},
			"stair": {
				"name": Cfg.tr("Stair"),
				"unlock": "access",
				"short": Cfg.tr("STAIR"),
				"category": "structure",
				"mode": BuildTool.Mode.STAIR,
				"cost": Cfg.tr("$%d per metre of rise") % int(Cfg.STAIR_COST_PER_M),
				"blurb": Cfg.tr("Climbs from the floor to a deck. Click the deck edge it comes off, then the spot on the ground it lands on."),
				"run_start": Cfg.tr("Start on deck edge"),
				"run_place": Cfg.tr("Land stair"),
			},
			"wall": {
				"name": Cfg.tr("Wall"),
				"unlock": "wall",
				"short": Cfg.tr("WALL"),
				"category": "structure",
				"mode": BuildTool.Mode.WALL,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.WALL_COST_PER_M),
				"blurb": Cfg.tr("A solid steel wall, %.1f m tall. Built in %.0f m sections.") % [
					Cfg.WALL_HEIGHT, Cfg.WALL_PANEL],
				"run_start": Cfg.tr("Start wall"),
				"run_place": Cfg.tr("Place wall"),
			},
			"wall_window": {
				"name": Cfg.tr("Window Wall"),
				"unlock": "wall",
				"short": Cfg.tr("WINDOW"),
				"category": "structure",
				"mode": BuildTool.Mode.WALL_WINDOW,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.WALL_COST_PER_M),


				"blurb": Cfg.tr("A wall with a %.1f m hole in each section. Hay, belts and people can go through.") % Cfg.WALL_WINDOW_WIDTH,
				"run_start": Cfg.tr("Start wall"),
				"run_place": Cfg.tr("Place wall"),
			},


			"wall_door": {
				"name": Cfg.tr("Doorway"),
				"unlock": "wall",
				"short": Cfg.tr("DOOR"),
				"category": "structure",
				"mode": BuildTool.Mode.WALL_DOOR,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.WALL_COST_PER_M),
				"blurb": Cfg.tr("One wall section with a %.1f m doorway. Snaps into a wall you already built.") % Cfg.WALL_DOOR_WIDTH,
				"run_start": Cfg.tr("Start doorway"),
				"run_place": Cfg.tr("Place doorway"),
			},


			"roof": {
				"name": Cfg.tr("Roof"),
				"unlock": "roof",
				"short": Cfg.tr("ROOF"),
				"category": "structure",
				"mode": BuildTool.Mode.ROOF,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.ROOF_COST_PER_M),
				"blurb": Cfg.tr("A flat roof, built in %.0f m sections along the top of a wall. Reaches %.0f m in.") % [
					Cfg.ROOF_BAY, Cfg.ROOF_DEPTH],
				"run_start": Cfg.tr("Start roof"),
				"run_place": Cfg.tr("Place roof"),
				"turn": Cfg.tr("Other side"),
			},
			"roof_pitch": {
				"name": Cfg.tr("Angled Roof"),
				"unlock": "roof",
				"short": Cfg.tr("PITCH"),
				"category": "structure",
				"mode": BuildTool.Mode.ROOF_PITCH,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.ROOF_COST_PER_M),
				"blurb": Cfg.tr("A sloped roof that rises %.1f m. Two of them facing each other across a %.0f m building meet in the middle.") % [
					Cfg.ROOF_RISE, Cfg.ROOF_DEPTH * 2.0],
				"run_start": Cfg.tr("Start roof"),
				"run_place": Cfg.tr("Place roof"),
				"turn": Cfg.tr("Slope the other way"),
			},
			"roof_hatch": {
				"name": Cfg.tr("Roof Hatch"),
				"unlock": "roof",
				"short": Cfg.tr("HATCH"),
				"category": "structure",
				"mode": BuildTool.Mode.ROOF_HATCH,
				"cost": Cfg.tr("$%d per bay") % int(Cfg.ROOF_BAY * Cfg.ROOF_COST_PER_M
					+ Cfg.ROOF_HATCH_COST),
				"blurb": Cfg.tr("A roof section with a %.1f m hole and a ladder. Use it to get onto the roof.") % Cfg.ROOF_HATCH,
				"place": Cfg.tr("Place hatch"),
				"turn": Cfg.tr("Turn the hatch"),
				"note": Cfg.tr("lines itself up with the bays either side"),
			},
			"rail": {
				"name": Cfg.tr("Railing"),
				"unlock": "access",
				"short": Cfg.tr("RAIL"),
				"category": "structure",
				"mode": BuildTool.Mode.RAILING,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.RAILING_COST_PER_M),
				"blurb": Cfg.tr("A railing along the edge of a platform."),
				"run_start": Cfg.tr("Start rail"),
				"run_place": Cfg.tr("Place rail"),
			},
			"splitter": {
				"name": Cfg.tr("Belt Splitter"),
				"unlock": "splitter",
				"short": Cfg.tr("SPLIT"),
				"category": "haulage",
				"mode": BuildTool.Mode.SPLITTER,
				"cost": Cfg.tr("$%d") % int(Cfg.SPLITTER_COST),
				"blurb": Cfg.tr("Splits one belt into two, one load each way."),
				"place": Cfg.tr("Place splitter"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},
			"compact_splitter": {
				"name": Cfg.tr("Compact Splitter"),
				"unlock": "compact_splitter",
				"short": Cfg.tr("3 WAY"),
				"category": "haulage",
				"mode": BuildTool.Mode.COMPACT_SPLITTER,
				"cost": Cfg.tr("$%d") % int(Cfg.COMPACT_SPLITTER_COST),
				"blurb": Cfg.tr("Splits one belt evenly across three outputs."),
				"place": Cfg.tr("Place compact splitter"),
				"note": Cfg.tr("snaps to an open or covered belt end"),
			},
			"smart_splitter": {
				"name": Cfg.tr("Smart Splitter"),
				"unlock": "smart_splitter",
				"short": Cfg.tr("SMART"),
				"category": "haulage",
				"mode": BuildTool.Mode.SMART_SPLITTER,
				"cost": Cfg.tr("$%d") % int(Cfg.SMART_SPLITTER_COST),
				"blurb": Cfg.tr("Routes items by type, with undefined and overflow rules."),
				"place": Cfg.tr("Place smart splitter"),
				"note": Cfg.tr("snaps to an open or covered belt end"),
			},


			"u_splitter": {
				"name": Cfg.tr("U Splitter"),
				"unlock": "splitter",
				"short": Cfg.tr("U SPLIT"),
				"category": "haulage",
				"mode": BuildTool.Mode.U_SPLITTER,
				"cost": Cfg.tr("$%d") % int(Cfg.SPLITTER_COST),
				"blurb": Cfg.tr("Splits one belt into two belts side by side, going the same way."),
				"place": Cfg.tr("Place U splitter"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},


			"t_splitter": {
				"name": Cfg.tr("T Junction"),
				"unlock": "t_splitter",
				"short": Cfg.tr("T JUNCT"),
				"category": "haulage",
				"mode": BuildTool.Mode.T_SPLITTER,
				"cost": Cfg.tr("$%d") % int(Cfg.T_SPLITTER_COST),
				"blurb": Cfg.tr("Sets itself up from its belts: one belt in splits into two, two belts in join into one."),
				"place": Cfg.tr("Place T junction"),
				"note": Cfg.tr("snaps to a belt end  ·  R picks which end the belt goes in"),
			},
			"joiner": {
				"name": Cfg.tr("Belt Joiner"),
				"unlock": "joiner",
				"short": Cfg.tr("JOIN"),
				"category": "haulage",
				"mode": BuildTool.Mode.JOINER,
				"cost": Cfg.tr("$%d") % int(Cfg.JOINER_COST),
				"blurb": Cfg.tr("Merges two belts into one, one load from each in turn."),
				"place": Cfg.tr("Place joiner"),
				"note": Cfg.tr("snaps a belt onto the side you face away from"),
			},
			"u_joiner": {
				"name": Cfg.tr("U Joiner"),
				"unlock": "joiner",
				"short": Cfg.tr("U JOIN"),
				"category": "haulage",
				"mode": BuildTool.Mode.U_JOINER,
				"cost": Cfg.tr("$%d") % int(Cfg.JOINER_COST),
				"blurb": Cfg.tr("Merges two side by side belts into one."),
				"place": Cfg.tr("Place U joiner"),
				"note": Cfg.tr("snaps to the end of a belt run on the side you aim at"),
			},
			"scanner": {
				"name": Cfg.tr("Haystack Scanner"),
				"unlock": "scanner_mk1",
				"short": Cfg.tr("SCANNER"),
				"category": "prospecting",
				"mode": BuildTool.Mode.SCANNER,
				"cost": Cfg.tr("from $%d") % int(Cfg.SCANNER_TIERS [0] ["cost"]),
				"blurb": Cfg.tr("Checks everything on a belt for needles and keeps them in its drawer. The Mk I stops the belt until you empty it."),
				"upgrades": ["scan_batch", "scan_speed", "scan_solids", "drawer_space"],
				"place": Cfg.tr("Place scanner"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},
			"compressor": {
				"name": Cfg.tr("Hay Compressor"),
				"unlock": "compressor",
				"short": Cfg.tr("PRESS"),
				"category": "processing",
				"mode": BuildTool.Mode.COMPRESSOR,
				"cost": Cfg.tr("$%d") % int(Cfg.COMPRESSOR_COST),
				"blurb": Cfg.tr("Presses %d strands into a bale worth %.1fx loose hay.") % [
					Cfg.COMPRESSOR_BALE_STRANDS, Cfg.COMPRESSOR_BALE_RATIO],
				"upgrades": ["compressor_batch", "compressor_speed", "bale_quality"],
				"place": Cfg.tr("Place compressor"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},
			"wrapper": {
				"name": Cfg.tr("Hay Wrapper"),
				"unlock": "wrapper",
				"short": Cfg.tr("WRAP"),
				"category": "processing",
				"mode": BuildTool.Mode.WRAPPER,
				"cost": Cfg.tr("$%d") % int(Cfg.WRAPPER_COST),
				"blurb": Cfg.tr("Wraps bales. Takes bales only, so put it after a compressor. Wrapped bales sell for %.2fx a bale.") % Cfg.WRAPPER_FOILED_RATIO,
				"upgrades": ["wrapper_speed", "foil_quality"],
				"place": Cfg.tr("Place wrapper"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},


			"pulper": {
				"name": Cfg.tr("Hay Pulper"),
				"unlock": "pulper",
				"short": Cfg.tr("PULP"),
				"category": "processing",
				"mode": BuildTool.Mode.PULPER,
				"cost": Cfg.tr("$%d") % int(Cfg.PULPER_COST),


				"blurb": _pulper_blurb(),
				"upgrades": ["pulper_batch", "pulper_speed", "pulp_quality"],
				"place": Cfg.tr("Place pulper"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},


			"paper_machine": {
				"name": Cfg.tr("Paper Mill"),
				"unlock": "paper_machine",
				"short": Cfg.tr("PAPER"),
				"category": "processing",
				"mode": BuildTool.Mode.PAPER,
				"cost": Cfg.tr("$%d") % int(Cfg.PAPER_COST),


				"blurb": _paper_blurb(),
				"upgrades": ["paper_speed", "paper_quality"],
				"place": Cfg.tr("Place paper mill"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},


			"briquette_press": {
				"name": Cfg.tr("Feed Disc Press"),
				"unlock": "briquette_press",


				"short": Cfg.tr("DISCS"),
				"category": "processing",
				"mode": BuildTool.Mode.BRIQUETTE,
				"cost": Cfg.tr("$%d") % int(Cfg.BRIQUETTE_COST),


				"blurb": Cfg.tr("Presses hay from one belt and eco bricks from another into feed discs worth %.2fx the hay. Uses %d straw and %d bricks a disc and stops if either belt runs out. Any size of brick counts as one brick. It is %d m long with an input on the side, so leave room beside it. Uses %.1f kW.") % [
					Cfg.BRIQUETTE_DISC_RATIO, Cfg.BRIQUETTE_BATCH_STRANDS,
					Cfg.BRIQUETTE_BATCH_BRICKS, int(Cfg.BRIQUETTE_LENGTH),
					Cfg.BRIQUETTE_DRAW_KW],
				"upgrades": ["briquette_speed", "briquette_quality"],
				"place": Cfg.tr("Place feed disc press"),


				"note": Cfg.tr("snaps to a belt; run the second belt to the side input after"),
			},
			"rake": {
				"name": Cfg.tr("Piston Rake"),
				"unlock": "piston_rake",
				"short": Cfg.tr("RAKE"),


				"category": "excavation",
				"mode": BuildTool.Mode.PISTON_RAKE,


				"cost": Cfg.tr("from $%d") % int(Cfg.RAKE_COST),
				"blurb": (Cfg.tr("Digs the pile in front of it and throws the hay behind it. Keep the area behind it clear. The first %d cost the normal price, then each one costs more. Max %d.")
					% [Cfg.RAKE_COST_FREE, Cfg.RAKE_LIMIT]),
				"upgrades": ["rake_bite", "rake_speed"],
				"place": Cfg.tr("Place rake"),
			},
			"pelletizer": {
				"name": Cfg.tr("Hay Pelletizer"),
				"unlock": "pelletizer",
				"short": Cfg.tr("MILL"),
				"category": "processing",
				"mode": BuildTool.Mode.PELLETIZER,
				"cost": Cfg.tr("$%d") % int(Cfg.PELLETIZER_COST),


				"blurb": Cfg.tr("Turns loose hay into fuel bricks worth %.1fx the hay and throws them out.") % Cfg.PELLETIZER_BRICK_RATIO,
				"upgrades": ["pellet_batch", "pellet_speed", "brick_quality"],
				"place": Cfg.tr("Place pelletizer"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},
			"generator": {
				"name": Cfg.tr("Hay Generator"),
				"unlock": "electricity",
				"short": Cfg.tr("POWER"),


				"category": "power",


				"cost": Cfg.tr("$%d") % int(Cfg.GENERATOR_COST),
				"mode": BuildTool.Mode.GENERATOR,
				"blurb": Cfg.tr("Burns hay to make up to %.0f kW. More hay means more power, up to the max. Every straw gives the same power, loose or pressed. If it runs out of hay, machines on its line slow down.") % Tech.generator_output(),
				"place": Cfg.tr("Place generator"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},


			"gas_plant": {
				"name": Cfg.tr("Gas Plant"),
				"unlock": "gas_plant",
				"short": Cfg.tr("GAS"),
				"category": "power",
				"cost": Cfg.tr("$%d") % int(Cfg.GAS_PLANT_COST),
				"mode": BuildTool.Mode.GAS_PLANT,
				"blurb": Cfg.tr("Burns eco bricks only and makes up to %.0f kW, %d times the power a Hay Generator gets from the same straw. Needs a water pipe from a pump. Its tank holds %d seconds of water, so it can start without one.") % [
					Tech.gas_plant_output(),
					int(Cfg.GAS_PLANT_KJ_PER_STRAND / Cfg.GENERATOR_KJ_PER_STRAND),
					int(Cfg.GAS_PLANT_TANK_SECONDS)],
				"upgrades": ["gas_plant_output"],
				"place": Cfg.tr("Place gas plant"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},
			"borehole": {
				"name": Cfg.tr("Borehole Pump"),
				"unlock": "borehole",
				"short": Cfg.tr("PUMP"),
				"category": "water",
				"mode": BuildTool.Mode.BOREHOLE,
				"cost": Cfg.tr("$%d") % int(Cfg.BOREHOLE_COST),


				"blurb": Cfg.tr("Pumps %.0f litres of water a second and uses %.0f kW. Pipe the water to a pulper.") % [
					Tech.borehole_output(), Cfg.BOREHOLE_DRAW_KW],
				"upgrades": ["pump_output"],
				"place": Cfg.tr("Sink borehole"),
				"note": Cfg.tr("one click, anywhere flat"),
			},
			"pipe": {
				"name": Cfg.tr("Water Pipe"),
				"unlock": "water_main",
				"short": Cfg.tr("PIPE"),
				"category": "water",
				"mode": BuildTool.Mode.WATER_PIPE,
				"cost": Cfg.tr("$%d per metre") % int(Cfg.PIPE_COST_PER_M),


				"blurb": Cfg.tr("Carries water from a pump to a machine. Click the shiny flange on one machine, then on the other. Both ends must be on a flange."),


				"run_start": Cfg.tr("Start pipe"),
				"run_place": Cfg.tr("Place pipe"),
			},
			"water_splitter": {
				"name": Cfg.tr("Water Splitter"),


				"unlock": "water_main",
				"short": Cfg.tr("WYE"),
				"category": "water",
				"mode": BuildTool.Mode.WATER_SPLITTER,
				"cost": Cfg.tr("$%d") % int(Cfg.PIPE_SPLITTER_COST),


				"blurb": Cfg.tr("Splits one water pipe into two. Turn it to face where the water goes, then connect pipes to all three flanges."),
				"place": Cfg.tr("Place splitter"),
				"note": Cfg.tr("one click, anywhere flat"),
			},
			"pole": {
				"name": Cfg.tr("Power Pole"),
				"unlock": "power_pole",
				"short": Cfg.tr("POWER"),
				"category": "power",
				"mode": BuildTool.Mode.POWER_POLE,
				"cost": Cfg.tr("$%d") % int(Cfg.POLE_COST),


				"blurb": Cfg.tr("Carries power. Poles up to %d m apart connect. Machines within %d m get power if nothing blocks the wire.") % [int(Cfg.POLE_LINK_R), int(Cfg.POLE_SUPPLY_R)],
				"place": Cfg.tr("Plant pole"),
				"note": Cfg.tr("one click, anywhere flat"),
				"upgrades": ["pole_span", "pole_drop"],
			},
			"box": {
				"name": Cfg.tr("Cable Box"),
				"unlock": "underground_power",
				"short": Cfg.tr("CABLE"),
				"category": "power",
				"mode": BuildTool.Mode.POWER_BOX,
				"cost": Cfg.tr("$%d") % int(Cfg.BOX_COST),


				"blurb": Cfg.tr("Works like a power pole, but the cable is underground so nothing blocks it. Connects up to %d m away and powers machines within %d m. Hold one to see the cables.") % [int(Cfg.BOX_LINK_R), int(Cfg.BOX_SUPPLY_R)],
				"place": Cfg.tr("Set box"),
				"note": Cfg.tr("one click, anywhere flat"),
				"upgrades": ["pole_span", "pole_drop"],
			},


			"paintboard": {
				"name": Cfg.tr("Paint Board"),
				"unlock": "paint_board",
				"short": Cfg.tr("BOARD"),
				"category": "structure",
				"mode": BuildTool.Mode.PAINT_BOARD,
				"cost": Cfg.tr("$%d") % int(Cfg.PAINT_BOARD_COST),


				"blurb": Cfg.tr("A whiteboard you can draw on. Hold left click to draw and right click to erase. Press %s at it to pick colours and save drawings.") % InputSetup.hint("interact"),
				"place": Cfg.tr("Stand board"),
				"note": Cfg.tr("one click, anywhere flat"),
			},


			"worklamp": {
				"name": Cfg.tr("Work Lamp"),
				"unlock": "work_lamp",
				"short": Cfg.tr("LAMP"),
				"category": "structure",
				"mode": BuildTool.Mode.WORK_LAMP,
				"cost": Cfg.tr("$%d") % int(Cfg.WORK_LAMP_COST),


				"blurb": Cfg.tr("A lamp that lights up to %d m in the direction you face when you place it. Press %s at it to change the brightness. Needs no power, and its battery never runs out.") % [
					int(Cfg.WORK_LAMP_RANGE), InputSetup.hint("interact")],
				"place": Cfg.tr("Stand lamp"),


				"note": Cfg.tr("one click, anywhere flat"),
			},
			"hatch": {
				"name": Cfg.tr("Dump Hatch"),
				"unlock": "dump_hatch",
				"short": Cfg.tr("TIPPER"),


				"category": "haulage",
				"mode": BuildTool.Mode.DUMP_HATCH,
				"cost": Cfg.tr("$%d") % int(Cfg.DUMP_HATCH_COST),
				"blurb": Cfg.tr("Put it over a belt. Walk up with a full bucket or barrow and it empties it onto the belt."),
				"place": Cfg.tr("Place dump hatch"),
				"note": Cfg.tr("stand it over a belt, facing the way you want it to tip"),
			},
			"launcher": {
				"name": Cfg.tr("Tube Launcher"),
				"unlock": "launcher",
				"short": Cfg.tr("LAUNCH"),
				"category": "haulage",
				"mode": BuildTool.Mode.LAUNCHER,
				"cost": Cfg.tr("$%d") % int(Cfg.LAUNCHER_COST),


				"blurb": Cfg.tr("Throws whatever a belt brings it. Press %s at it to set the angle and power.") % InputSetup.hint("interact"),
				"place": Cfg.tr("Place launcher"),
				"note": Cfg.tr("snaps to the end of a belt run"),
			},
			"silo": {
				"name": Cfg.tr("Hay Silo"),
				"unlock": "silo",
				"short": Cfg.tr("SILO"),
				"category": "processing",
				"mode": BuildTool.Mode.SILO,
				"cost": Cfg.tr("$%d") % int(Cfg.SILO_COST),


				"blurb": Cfg.tr("Stores hay in a belt line. Press %s at it to set how fast hay comes out. Holds %d loads.") % [
					InputSetup.hint("interact"), Cfg.SILO_CAPACITY],
				"place": Cfg.tr("Place silo"),


				"note": Cfg.tr("the bottom snaps to a belt; the top opening is %.1f m up") % HaySilo.F_BELT_IN.y,
			},


			"haystairs": {
				"name": Cfg.tr("Hay Stairs"),
				"unlock": "haystairs",
				"short": Cfg.tr("HAYSTAIRS"),
				"category": "haulage",
				"mode": BuildTool.Mode.HAY_STAIRS,
				"cost": Cfg.tr("$%d") % int(Cfg.HAY_STAIRS_COST),
				"blurb": Cfg.tr("Brings hay down to the floor. Drop hay in the top. Belts cannot go down slopes steeper than %d degrees.") % int(rad_to_deg(Cfg.BELT_MAX_SLOPE)),
				"place": Cfg.tr("Place hay stairs"),
				"note": Cfg.tr("run a belt off the bottom; drop into the top from anywhere"),
			},


			"haylift": {
				"name": Cfg.tr("Hay Lift"),
				"unlock": "haylift",
				"short": Cfg.tr("HAYLIFT"),
				"category": "haulage",
				"mode": BuildTool.Mode.HAY_LIFT,


				"cost": Cfg.tr("from $%d") % int(Cfg.HAY_LIFT_COST),


				"blurb": Cfg.tr("Carries hay up. Belts cannot climb slopes steeper than %d degrees. Click the bottom, then look up and click the top. Lifts %s m, each extra metre costs $%d, up to %s m.") % [
					int(rad_to_deg(Cfg.BELT_MAX_SLOPE)), HayLift.metres(Cfg.HAY_LIFT_BASE_RISE),
					int(Cfg.HAY_LIFT_SECTION_COST),
					HayLift.metres(HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX))],
				"place": Cfg.tr("Place hay lift"),
				"note": Cfg.tr("both ends snap to a belt run; the top one is as high as you built it"),
			},
			"cabinet": {
				"name": Cfg.tr("Needle Cabinet"),
				"unlock": "cabinet",
				"short": Cfg.tr("CABINET"),
				"category": "prospecting",
				"mode": BuildTool.Mode.CABINET,
				"cost": Cfg.tr("$%d") % int(Cfg.CABINET_COST),
				"blurb": Cfg.tr("Holds one of each kind of needle you find. One per yard."),
				"place": Cfg.tr("Place cabinet"),
			},
			"needle_radar": {
				"name": Cfg.tr("Satellite Dish"),
				"unlock": "radar_mk1",
				"short": Cfg.tr("DISH"),
				"category": "prospecting",
				"mode": BuildTool.Mode.NEEDLE_RADAR,
				"cost": Cfg.tr("$%d") % int(Cfg.RADAR_COST),
				"blurb": Cfg.tr("Scans the pile and marks buried needles within %d m. One per yard.") % int(Cfg.RADAR_RANGE),
				"place": Cfg.tr("Place satellite dish"),
			},
		}
	return _entries


static func invalidate() -> void:
	_entries = { }


static func ids() -> Array:
	return entries().keys()


static func ordered_ids() -> Array:
	var out: Array = []
	for cat: Dictionary in CATEGORIES:
		out.append_array(ids_in(str(cat ["id"])))
	for id: String in ids():
		if not out.has(id) and not is_withheld(id):
			out.append(id)
	return out


static func ids_in(category: String) -> Array:
	var out: Array = []
	for id: String in ids():
		if category_of(id) == category and not is_withheld(id):
			out.append(id)
	return out


static func is_withheld(id: String) -> bool:
	return TechTree.is_demo(unlock_of(id))


static func has_id(id: String) -> bool:
	return entries().has(id)


static func spec(id: String) -> Dictionary:
	return entries().get(id, { })


static func display_name(id: String) -> String:
	var text:= str(spec(id).get("name", ""))
	return Cfg.tr(text) if text != "" else id


static func short_name(id: String) -> String:
	return str(spec(id).get("short", Cfg.upper(display_name(id))))


static func category_of(id: String) -> String:
	return str(spec(id).get("category", ""))


static func category_name(category: String) -> String:
	for cat: Dictionary in CATEGORIES:
		if str(cat ["id"]) == category:
			return Cfg.tr(str(cat ["name"]))
	return category.capitalize()


static func cost_text(id: String) -> String:


	var gifts:= GameState.gift_waiting(id)
	if gifts > 0:
		return Cfg.tr("FREE x%d") % gifts
	return str(spec(id).get("cost", ""))


static func has_gift(id: String) -> bool:
	return GameState.gift_waiting(id) > 0


static func upgrades_of(id: String) -> Array:
	return spec(id).get("upgrades", [])


static func blurb(id: String) -> String:


	match id:
		"pulper":
			return _pulper_blurb()
		"paper_machine":
			return _paper_blurb()
	var text:= str(spec(id).get("blurb", ""))
	return "" if text == "" else Cfg.tr(text)


static func _pulper_blurb() -> String:
	return Cfg.tr("Mixes %d strands with %.0f litres of water into a pulp slab worth %.1fx the hay. Needs power and a water pipe. It is a long machine, so leave room.") % [
		Tech.pulper_batch_strands(), Cfg.PULPER_WATER_LITRES,
		Tech.pulp_value_ratio()]


static func _paper_blurb() -> String:
	return Cfg.tr("Turns %d pulp slabs into a paper roll worth %.2fx the slabs. It is %d m long and uses %.0f kW. Takes slabs only.") % [
		Cfg.PAPER_SLABS_PER_ROLL, Tech.paper_value_ratio(),
		int(Cfg.PAPER_LENGTH), Cfg.PAPER_DRAW_KW]


static func mode_of(id: String) -> BuildTool.Mode:
	return spec(id).get("mode", BuildTool.Mode.CONVEYOR)


static func is_run(id: String) -> bool:
	return spec(id).has("run_start")


static func unlock_of(id: String) -> String:
	return str(spec(id).get("unlock", ""))


static func builds_for(node: String) -> Array:
	var out: Array = []
	if node == "":
		return out
	for id: String in ordered_ids():
		if unlock_of(id) == node:
			out.append(id)
	return out


static func is_unlocked(id: String) -> bool:
	if is_withheld(id):
		return false
	var node:= unlock_of(id)
	return node == "" or Tech.is_unlocked(node)


const FAMILIES: Array = [
	["splitter", "u_splitter", "t_splitter", "compact_splitter", "smart_splitter"],
	["joiner", "u_joiner", "t_splitter"],
	["belt", "enclosed_belt"],
	["wall", "wall_window", "wall_door"],
	["roof", "roof_pitch", "roof_hatch"],
	["haystairs", "haylift"],
	["arm", "arm_standard", "arm_long"],
]


static func arm_tier_of(id: String) -> int:
	return int(spec(id).get("arm_tier", -1))


static func arm_id_for_tier(tier: int) -> String:
	for id: String in ids():
		if arm_tier_of(id) == tier:
			return id
	return "arm"


static func family_of(id: String, prefer: int = -1) -> int:
	if prefer >= 0 and prefer < FAMILIES.size() and FAMILIES [prefer].has(id):
		return prefer
	for i in FAMILIES.size():
		if FAMILIES [i].has(id):
			return i
	return -1


static func next_variant(id: String, family: int = -1) -> String:
	var f:= family_of(id, family)
	if f < 0:
		return ""
	var list: Array = FAMILIES [f]
	var at:= list.find(id)
	for step in range(1, list.size()):
		var other: String = list [(at + step) % list.size()]
		if has_id(other) and is_unlocked(other):
			return other
	return ""


static func first_unlocked() -> String:
	for id: String in ordered_ids():
		if is_unlocked(id):
			return id
	return ""
