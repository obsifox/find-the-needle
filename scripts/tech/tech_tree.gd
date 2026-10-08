class_name TechTree
extends RefCounted


const BRANCHES:= [
	{ "id": "handling", "name": "Hand Work", "subtitle": "shovels, buckets and barrows",
		"colour": Color(0.847, 0.541, 0.196) },
	{ "id": "fitness", "name": "Fitness", "subtitle": "running, carrying and reaching",
		"colour": Color(0.663, 0.545, 0.408) },
	{ "id": "selling", "name": "Selling", "subtitle": "getting more for the hay",
		"colour": Color(0.82, 0.6, 0.52) },
	{ "id": "structures", "name": "Yard Building", "subtitle": "platforms, walls and roofs",
		"colour": Color(0.518, 0.6, 0.639) },
	{ "id": "lines", "name": "Hay Lines", "subtitle": "belts, splitters and the launcher",
		"colour": Color(0.56, 0.69, 0.47) },
	{ "id": "power", "name": "Power", "subtitle": "the generator and its wires",
		"colour": Color(0.9, 0.76, 0.28) },
	{ "id": "plant", "name": "Processing", "subtitle": "bales, wraps, bricks and the silo",
		"colour": Color(0.42, 0.68, 0.64) },
	{ "id": "automation", "name": "Automation", "subtitle": "rakes, arms and the drone",
		"colour": Color(0.784, 0.353, 0.204) },


	{ "id": "water", "name": "Water", "subtitle": "the well, the mains and the pulper",
		"colour": Color(0.38, 0.64, 0.8) },
	{ "id": "prospecting", "name": "Prospecting", "subtitle": "finding and scanning needles",
		"colour": Color(0.72, 0.56, 0.78) },
]


const TUNING_TITLES:= {
	"arm_small": "Arm upgrades",
	"piston_rake": "Rake upgrades",
	"electricity": "Generator upgrades",
	"scanner_mk1": "Scanner upgrades",
	"belt": "Belt upgrades",
}


const ROOT:= "yard"


const DEMO_TEXT:= "Not available in Demo"


const DEMO_ICON:= "lock"


const SITE_TEXT:= "Not on this site"

static var _nodes: Dictionary = { }
static var _order: Array = []


static func nodes() -> Dictionary:
	if _nodes.is_empty():
		_build()
	return _nodes


static func _add(id: String, spec_in: Dictionary) -> void:
	_nodes [id] = spec_in
	_order.append(id)


static func _straw(n: int) -> String:
	return Cfg.tr_n("%d straw", "%d straw", n) % n


static func _straws(counts: Array) -> Array:
	var out: Array = []
	for n: int in counts:
		out.append(_straw(n))
	return out


static func _wad(n: int) -> String:
	return Cfg.tr_n("1 wad · %d straw", "1 wad · %d straw", n) % n


static func _build() -> void:

	_add(ROOT, {
		"name": Cfg.tr("Bare Hands"), "icon": "hands",
		"branch": "handling", "kind": "root",
		"costs": [0.0], "requires": [],
		"blurb": Cfg.tr("Pick up hay with your hands and carry it to the selling stand."),
		"reward": Cfg.tr("Pick up and carry hay"),
	})


	_add("hand_carry", {
		"name": Cfg.tr("Bigger Handful"), "branch": "handling", "kind": "ranked", "icon": "gloves+more",
		"costs": [0.1, 0.15, 0.25, 0.35, 0.5], "requires": [ROOT],
		"flat": true,
		"blurb": Cfg.tr("Each level lets you hold more hay and grab more with each click, up to fifteen pieces."),
		"base": _straw(1),
		"values": _straws(Cfg.HAND_HOLD_RANKS),
		"unit": Cfg.tr(" in hand"),
	})


	_add("sand_shovel", {
		"name": Cfg.tr("Toy Shovel"), "branch": "handling", "kind": "unlock", "icon": "toy_shovel",
		"costs": [3.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks the toy shovel in the shop. Digs %d straw at a time.") % SandShovel.SCOOP_MAX,


		"reward": Cfg.tr("SHOP · Toy Shovel · $%.2f") % Cfg.PRICE_SAND_SHOVEL,
	})


	_add("toy_shovel_size", {
		"name": Cfg.tr("Bigger Toy Shovel"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "toy_shovel+more",
		"costs": [2.0, 4.0, 7.0], "requires": ["sand_shovel"],
		"blurb": Cfg.tr("Each level digs 3 more straw."),
		"base": _straw(18), "values": _straws([21, 24, 27]), "unit": Cfg.tr(" a dig"),
	})


	_add("spade", {
		"name": Cfg.tr("Spade"), "branch": "handling", "kind": "unlock", "icon": "spade",
		"costs": [18.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks the spade in the shop. Digs %d straw at a time.") % Cfg.SCOOP_MAX,
		"reward": Cfg.tr("SHOP · Spade · $%d") % int(Cfg.PRICE_SPADE),
	})


	_add("shovel_size", {
		"name": Cfg.tr("Bigger Spade"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "spade+more",
		"costs": [15.0, 30.0], "requires": ["spade"],
		"blurb": Cfg.tr("Each level digs about 12% more straw."),
		"base": _straw(54),
		"values": _straws([61, 68]), "unit": Cfg.tr(" a dig"),
	})
	_add("pitchfork", {
		"name": Cfg.tr("Pitchfork"), "branch": "handling", "kind": "unlock", "icon": "pitchfork",
		"costs": [25.0], "requires": ["spade"],
		"blurb": Cfg.tr("Unlocks the pitchfork in the shop. Lifts %d straw at a time.") % Pitchfork.SCOOP_MAX,
		"reward": Cfg.tr("SHOP · Pitchfork · $%d") % int(Cfg.PRICE_PITCHFORK),
	})
	_add("fork_size", {
		"name": Cfg.tr("Bigger Pitchfork"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "pitchfork+more",
		"costs": [20.0, 40.0, 70.0, 120.0, 200.0], "requires": ["pitchfork"],
		"blurb": Cfg.tr("Each level lifts about 12% more straw."),
		"base": _straw(62),
		"values": _straws([70, 78, 88, 99, 111]), "unit": Cfg.tr(" a dig"),
	})
	_add("broom", {
		"name": Cfg.tr("Broom"), "branch": "handling", "kind": "unlock", "icon": "broom",
		"costs": [10.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks the broom in the shop. Pushes loose hay along the floor at %.1f m/s.") % Broom.SWEEP_SPEED,
		"reward": Cfg.tr("SHOP · Broom · $%d") % int(Cfg.PRICE_BROOM),
	})
	_add("broom_bristles", {
		"name": Cfg.tr("Better Broom"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "broom+range",
		"costs": [15.0, 35.0, 70.0], "requires": ["broom"],
		"blurb": Cfg.tr("Each level lets the broom sweep a wider patch of floor."),
		"base": "1.5", "values": ["1.8", "2.1", "2.4"], "unit": " m",
	})
	_add("bucket", {
		"name": Cfg.tr("Bucket Licence"), "branch": "handling", "kind": "unlock", "icon": "bucket",
		"costs": [15.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks the bucket in the shop. Holds %d pieces of hay and empties at %d a second.") % [Cfg.BUCKET_CAPACITY, int(Cfg.BUCKET_POUR_RATE)],
		"reward": Cfg.tr("SHOP · Bucket · $%d") % int(Cfg.PRICE_BUCKET),
	})


	_add("bucket_size", {
		"name": Cfg.tr("Bigger Bucket"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "bucket+more",
		"costs": [25.0, 60.0, 130.0, 260.0, 500.0], "requires": ["bucket"],
		"blurb": Cfg.tr("Each level lets the bucket hold about a third more hay."),
		"base": "600",
		"values": ["799", "1,063", "1,415", "1,883", "2,506"], "unit": Cfg.tr(" pieces"),
	})


	_add("wheelbarrow", {
		"name": Cfg.tr("Wheelbarrow Licence"), "branch": "handling", "kind": "unlock", "icon": "wheelbarrow",
		"costs": [40.0], "requires": ["bucket"],
		"blurb": Cfg.tr("Unlocks the wheelbarrow in the shop. Holds %d pieces and empties at %d a second. A bucket empties at %d.") % [Cfg.BARROW_CAPACITY, int(Cfg.BARROW_POUR_RATE), int(Cfg.BUCKET_POUR_RATE)],
		"reward": Cfg.tr("SHOP · Wheelbarrow · $%d") % int(Cfg.PRICE_WHEELBARROW),
	})


	_add("barrow_size", {
		"name": Cfg.tr("Bigger Wheelbarrow"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "wheelbarrow+more",
		"costs": [80.0, 180.0, 350.0, 650.0, 1100.0], "requires": ["wheelbarrow"],
		"blurb": Cfg.tr("Each level lets the wheelbarrow hold about a fifth more hay."),
		"base": "2,100",
		"values": ["2,501", "2,979", "3,548", "4,226", "5,033"], "unit": Cfg.tr(" pieces"),
	})


	_add("dump_hatch", {
		"name": Cfg.tr("Dump Hatch Plans"), "branch": "handling",


		"kind": "unlock", "icon": "dump_hatch",


		"costs": [40.0], "requires": ["wheelbarrow"],
		"blurb": Cfg.tr("Unlocks the Dump Hatch, $%d each. Walk up to it with a full bucket or barrow and it empties it onto the belt below for you.") % int(Cfg.DUMP_HATCH_COST),
		"reward": Cfg.tr("BUILD · Dump Hatch · $%d") % int(Cfg.DUMP_HATCH_COST),
	})
	_add("smooth_pour", {
		"name": Cfg.tr("Smooth Pouring"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "bucket_pour+speed",
		"costs": [25.0, 60.0, 120.0], "requires": ["bucket"],
		"blurb": Cfg.tr("Each level makes buckets and barrows empty 12% faster. The numbers below are for the bucket."),
		"base": "190", "values": ["213", "236", "258"], "unit": Cfg.tr(" a second"),
	})


	_add("yard_vac", {
		"name": Cfg.tr("Yard Vac Licence"), "branch": "handling", "kind": "unlock",
		"icon": "yard_vac",
		"costs": [600.0], "requires": ["dump_hatch"],
		"blurb": Cfg.tr("Unlocks the yard vac in the shop, $%d. Hold left click to suck up hay from the floor or the pile at %d a second. Holds %d pieces. Hold right click to pour it out, or aim at a tipper, a bucket or a barrow to empty it straight in.") % [int(Cfg.PRICE_YARD_VAC), int(Cfg.VAC_SUCK_RATE), Cfg.VAC_CAPACITY],
		"reward": Cfg.tr("SHOP · Yard Vac · $%d") % int(Cfg.PRICE_YARD_VAC),
	})


	_add("vac_bin", {
		"name": Cfg.tr("Bigger Vac Bin"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "yard_vac+more",
		"costs": [100.0, 200.0, 350.0], "requires": ["yard_vac"],
		"blurb": Cfg.tr("Each level lets the yard vac hold 500 more pieces."),
		"base": "1,500",
		"values": ["2,000", "2,500", "3,000"], "unit": Cfg.tr(" pieces"),
	})


	_add("vac_suction", {
		"name": Cfg.tr("Stronger Suction"), "tuning": true, "branch": "handling", "kind": "ranked", "icon": "yard_vac+speed",
		"costs": [100.0, 200.0, 350.0], "requires": ["yard_vac"],
		"blurb": Cfg.tr("Each level makes the yard vac suck up hay 25% faster, from a wider patch."),
		"base": "100",
		"values": ["125", "150", "175"], "unit": Cfg.tr(" a second"),
	})


	_add("lighter", {
		"name": Cfg.tr("Lighter Licence"), "branch": "handling",
		"kind": "demo" if Cfg.DEMO else "unlock",
		"icon": DEMO_ICON if Cfg.DEMO else "lighter",
		"costs": [] if Cfg.DEMO else [Cfg.LIGHTER_LICENCE_COST], "requires": ["yard_vac"],
		"blurb": Cfg.tr("Unlocks the lighter in the shop, $%d. Burns about %d strands. Can be used every %d seconds.") % [int(Cfg.PRICE_LIGHTER), Cfg.LIGHTER_BURN_STRANDS, int(Cfg.LIGHTER_COOLDOWN)],
		"reward": Cfg.tr("SHOP · Lighter · $%d") % int(Cfg.PRICE_LIGHTER),
	})


	_add("belt", {
		"name": Cfg.tr("Conveyor Plans"), "branch": "lines", "kind": "unlock", "icon": "belt",
		"costs": [40.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks conveyor belts, $%d a metre. Belts move hay at %.1f m/s.") % [int(Cfg.BELT_COST_PER_M), Cfg.BELT_SPEED],
		"reward": Cfg.tr("BUILD · Conveyor Belt · $%d per metre") % int(Cfg.BELT_COST_PER_M),
	})
	_add("enclosed_belt", {
		"name": Cfg.tr("Enclosed Conveyor Plans"), "branch": "lines",
		"kind": "unlock", "icon": "enclosed_belt",
		"costs": [120.0], "requires": ["belt"],
		"blurb": Cfg.tr("Unlocks enclosed conveyors, $%d a metre. Packaged cargo travels without visible moving objects, which saves performance in large factories. Loose hay cannot enter.") % int(Cfg.ENCLOSED_BELT_COST_PER_M),
		"reward": Cfg.tr("BUILD · Enclosed Conveyor · $%d per metre") % int(Cfg.ENCLOSED_BELT_COST_PER_M),
	})
	_add("belt_speed", {
		"name": Cfg.tr("Faster Belt Motor"), "tuning": true, "branch": "lines", "kind": "ranked", "icon": "belt_loaded+speed",


		"costs": [15.0, 30.0, 55.0, 90.0, 140.0, 210.0, 300.0, 430.0],
		"requires": ["belt"],
		"blurb": Cfg.tr("Each level makes all belts 45% faster, including ones already built."),
		"base": "0.70",
		"values": ["1.01", "1.33", "1.65", "1.96", "2.27", "2.59", "2.91", "3.22"],
		"unit": " m/s",
	})
	_add("deck", {
		"name": Cfg.tr("Platform Plans"), "branch": "structures", "kind": "unlock", "icon": "platform",
		"costs": [60.0], "requires": ["belt"],
		"blurb": Cfg.tr("Unlocks platforms, $%d a square metre. You and your machines can stand on them.") % int(Cfg.PLATFORM_COST_PER_M2),
		"reward": Cfg.tr("BUILD · Platform · $%d per m2") % int(Cfg.PLATFORM_COST_PER_M2),
	})
	_add("access", {
		"name": Cfg.tr("Stairs and Railings"), "branch": "structures", "kind": "unlock", "icon": "stairs",
		"costs": [60.0], "requires": ["deck"],
		"blurb": Cfg.tr("Unlocks stairs ($%d a metre of height) and railings ($%d a metre). Railings are %.2f m tall.") % [int(Cfg.STAIR_COST_PER_M), int(Cfg.RAILING_COST_PER_M), Cfg.PLATFORM_RAIL_H],
		"reward": Cfg.tr("BUILD · Stair $%d/m rise · Railing $%d/m") % [
			int(Cfg.STAIR_COST_PER_M), int(Cfg.RAILING_COST_PER_M)],
	})


	_add("paint_board", {
		"name": Cfg.tr("Paint Board"), "branch": "structures", "kind": "unlock",
		"icon": "paint_board",
		"costs": [40.0], "requires": ["deck"],
		"blurb": Cfg.tr("Unlocks the Paint Board, $%d. Hold left click to draw and right click to erase.") % int(Cfg.PAINT_BOARD_COST),
		"reward": Cfg.tr("BUILD · Paint Board · $%d") % int(Cfg.PAINT_BOARD_COST),
	})


	_add("wall", {
		"name": Cfg.tr("Wall Plans"), "branch": "structures", "kind": "unlock",
		"icon": "wall",
		"costs": [80.0], "requires": ["deck"],
		"blurb": Cfg.tr("Unlocks walls, window walls and doorways, $%d a metre.") % int(Cfg.WALL_COST_PER_M),
		"reward": Cfg.tr("BUILD · Wall · Window Wall · $%d per metre") % int(Cfg.WALL_COST_PER_M),
	})


	_add("roof", {
		"name": Cfg.tr("Roof Plans"), "branch": "structures", "kind": "unlock",
		"icon": "roof",
		"costs": [120.0], "requires": ["wall"],
		"blurb": Cfg.tr("Unlocks flat roofs, angled roofs and roof hatches, $%d a metre. Climb onto the roof through a hatch.") % int(Cfg.ROOF_COST_PER_M),
		"reward": Cfg.tr("BUILD · Roof · Angled Roof · Roof Hatch · $%d per metre") % int(Cfg.ROOF_COST_PER_M),
	})


	_add("work_lamp", {
		"name": Cfg.tr("Work Lamp"), "branch": "structures", "kind": "unlock",
		"icon": "work_lamp",
		"costs": [90.0], "requires": ["roof"],
		"blurb": Cfg.tr("Unlocks the Work Lamp. Lights up to %d m. Press %s at it to change the brightness. Needs no power. $%d each.") % [
			int(Cfg.WORK_LAMP_RANGE), InputSetup.hint("interact"),
			int(Cfg.WORK_LAMP_COST)],
		"reward": Cfg.tr("BUILD · Work Lamp · $%d") % int(Cfg.WORK_LAMP_COST),
	})


	_add("splitter", {
		"name": Cfg.tr("Alternating Splitter"), "branch": "lines", "kind": "unlock", "icon": "splitter",
		"costs": [60.0], "requires": ["belt"],
		"blurb": Cfg.tr("Unlocks the splitter, $%d. Splits one belt into two: one load left, the next load right. It can also send everything one way.") % int(Cfg.SPLITTER_COST),
		"reward": Cfg.tr("BUILD · Belt Splitter · $%d") % int(Cfg.SPLITTER_COST),
	})


	_add("overflow_gate", {
		"name": Cfg.tr("Splitter Priority"), "branch": "lines", "kind": "unlock",


		"icon": "splitter+overflow",
		"costs": [120.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Adds a priority setting to every splitter. The chosen side gets all the hay. The other side only gets hay when the first one is backed up."),
		"reward": Cfg.tr("SPLITTERS · Priority · one side gets hay first"),
	})


	_add("t_splitter", {
		"name": Cfg.tr("T Junction"), "branch": "lines", "kind": "unlock",
		"icon": "t_splitter",
		"costs": [80.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Unlocks the T Junction, $%d. It sets itself up from the belts you connect: bring one belt in and it splits it into two, bring two belts in and it joins them into one.") % int(Cfg.T_SPLITTER_COST),
		"reward": Cfg.tr("BUILD · T Junction · $%d") % int(Cfg.T_SPLITTER_COST),
	})


	_add("compact_splitter", {
		"name": Cfg.tr("Compact Splitter Plans"), "branch": "lines", "kind": "unlock",
		"icon": "compact_splitter",
		"costs": [900.0], "requires": ["enclosed_belt", "t_splitter"],
		"blurb": Cfg.tr("Unlocks the Compact Splitter, $%d. Shares one belt between three belts, taking turns. Works with open and enclosed belts.") % int(Cfg.COMPACT_SPLITTER_COST),
		"reward": Cfg.tr("BUILD · Compact Splitter · $%d") % int(Cfg.COMPACT_SPLITTER_COST),
	})
	_add("smart_splitter", {
		"name": Cfg.tr("Smart Splitter Plans"), "branch": "lines", "kind": "unlock",
		"icon": "smart_splitter",


		"costs": [1500.0], "requires": ["compact_splitter"],
		"blurb": Cfg.tr("Unlocks the Smart Splitter, $%d. You pick what may leave through each of its three outputs, so one belt can be sorted by type.") % int(Cfg.SMART_SPLITTER_COST),
		"reward": Cfg.tr("BUILD · Smart Splitter · $%d") % int(Cfg.SMART_SPLITTER_COST),
	})


	_add("joiner", {
		"name": Cfg.tr("Belt Joiner"), "branch": "lines", "kind": "unlock",
		"icon": "joiner",
		"costs": [60.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Unlocks the joiner, $%d. Merges two belts into one.") % int(Cfg.JOINER_COST),
		"reward": Cfg.tr("BUILD · Belt Joiner · $%d") % int(Cfg.JOINER_COST),
	})


	_add("compressor", {
		"name": Cfg.tr("Compressor Plans"), "branch": "plant", "kind": "unlock", "icon": "compressor",
		"costs": [150.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Unlocks the Hay Compressor, $%d. Presses %d straw into a bale every %.1f seconds. Bales sell for %.1fx the price of loose hay.") % [int(Cfg.COMPRESSOR_COST), Cfg.COMPRESSOR_BALE_STRANDS, Cfg.COMPRESSOR_PRESS_SECONDS, Cfg.COMPRESSOR_BALE_RATIO],
		"reward": Cfg.tr("BUILD · Hay Compressor · $%d") % int(Cfg.COMPRESSOR_COST),
	})
	_add("compressor_batch", {
		"name": Cfg.tr("Larger Bale Chamber"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "compressor+more",
		"costs": [50.0, 100.0, 180.0, 300.0, 500.0, 800.0],
		"requires": ["compressor"],
		"blurb": Cfg.tr("Each level puts 25% more hay into every bale, so each bale is worth more."),
		"base": _straw(60),
		"values": _straws([75, 94, 117, 146, 183, 229]),
		"unit": Cfg.tr(" a bale"),
	})
	_add("compressor_speed", {
		"name": Cfg.tr("Faster Bale Press"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "compressor+speed",
		"costs": [50.0, 100.0, 180.0, 300.0, 500.0, 800.0],
		"requires": ["compressor"],
		"blurb": Cfg.tr("Each level makes every compressor 8% faster."),
		"base": "4.00",
		"values": ["3.68", "3.39", "3.11", "2.87", "2.64", "2.43"],
		"unit": Cfg.tr(" s a bale"),
	})
	_add("bale_quality", {
		"name": Cfg.tr("Raise Bale Quality"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "compressor+quality",
		"costs": [50.0, 100.0, 180.0, 300.0, 500.0],
		"requires": ["compressor"],
		"blurb": Cfg.tr("Each level makes bales sell for about 7% more."),
		"base": "x2.00",
		"values": ["x2.15", "x2.30", "x2.45", "x2.60", "x2.75"],
		"unit": Cfg.tr(" the hay value"),
	})


	_add("wrapper", {
		"name": Cfg.tr("Wrapper Plans"), "branch": "plant", "kind": "unlock",
		"icon": "wrapper",


		"costs": [150.0], "requires": ["compressor"],
		"blurb": Cfg.tr("Unlocks the Hay Wrapper, $%d. Wraps a bale every %.2f seconds. Takes bales only. Wrapped bales sell for %.2fx a bale, which is %.2fx the price of loose hay.") % [int(Cfg.WRAPPER_COST), Cfg.WRAPPER_SECONDS, Cfg.WRAPPER_FOILED_RATIO, Cfg.COMPRESSOR_BALE_RATIO * Cfg.WRAPPER_FOILED_RATIO],
		"reward": Cfg.tr("BUILD · Hay Wrapper · $%d") % int(Cfg.WRAPPER_COST),
	})


	_add("wrapper_speed", {
		"name": Cfg.tr("Faster Wrapper"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "wrapper+speed",
		"costs": [50.0, 100.0, 180.0, 300.0, 500.0, 800.0],
		"requires": ["wrapper"],
		"blurb": Cfg.tr("Each level makes every wrapper 12% faster. At the top it keeps up with a fully upgraded compressor."),
		"base": "5.25",
		"values": ["4.62", "4.07", "3.58", "3.15", "2.77", "2.44"],
		"unit": Cfg.tr(" s a bale"),
	})


	_add("foil_quality", {
		"name": Cfg.tr("Better Wrap"), "tuning": true, "branch": "plant", "kind": "ranked",
		"icon": "wrapper+quality",
		"costs": [70.0, 140.0, 250.0, 420.0, 700.0],
		"requires": ["wrapper"],
		"blurb": Cfg.tr("Each level makes wrapped bales sell for more."),
		"base": "x1.45",
		"values": ["x1.50", "x1.55", "x1.60", "x1.65", "x1.70"],
		"unit": Cfg.tr(" the bale value"),
	})


	_add("silo", {
		"name": Cfg.tr("Hay Silo Plans"), "branch": "plant", "kind": "unlock",
		"icon": "silo",


		"costs": [200.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Unlocks the Hay Silo, $%d. Put it in a belt line to store hay. Press %s at it to set how fast hay comes out, up to %d loads a minute. Holds %d loads.") % [
			int(Cfg.SILO_COST), InputSetup.hint("interact"),
			int(Cfg.SILO_RATE_BASE_MAX * 60.0), Cfg.SILO_CAPACITY],
		"reward": Cfg.tr("BUILD · Hay Silo · $%d") % int(Cfg.SILO_COST),
	})


	_add("silo_rate", {
		"name": Cfg.tr("Faster Silo Output"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "silo+speed",
		"costs": [70.0, 140.0, 250.0, 420.0, 700.0],
		"requires": ["silo"],
		"blurb": Cfg.tr("Each level raises the silo's top speed by 20 loads a minute."),
		"base": "300",
		"values": ["320", "340", "360", "380", "400"],
		"unit": Cfg.tr(" loads a minute"),
	})


	_add("silo_capacity", {
		"name": Cfg.tr("Bigger Silo"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "silo+more",
		"costs": [70.0, 140.0, 250.0, 420.0, 700.0],
		"requires": ["silo"],
		"blurb": Cfg.tr("Each level lets a silo hold about a quarter more."),
		"base": "300",
		"values": ["400", "500", "625", "800", "1000"],
		"unit": Cfg.tr(" loads"),
	})


	_add("silo_bulk", {
		"name": Cfg.tr("Fuller Silo Loads"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "silo+more",
		"costs": [70.0, 140.0, 250.0, 420.0, 700.0, 1100.0],
		"requires": ["silo"],
		"blurb": Cfg.tr("Each level puts 25% more loose hay into every load the silo lets out. Bales and bricks do not change."),
		"base": _straw(24),
		"values": _straws([30, 38, 47, 59, 73, 92]),
		"unit": Cfg.tr(" a load"),
	})


	_add("haystairs", {
		"name": Cfg.tr("Hay Stairs"), "branch": "structures", "kind": "unlock",
		"icon": "hay_stairs",
		"costs": [140.0], "requires": ["deck"],
		"blurb": Cfg.tr("Unlocks Hay Stairs, $%d. Belts cannot go down slopes steeper than %d degrees. Drop hay in the top and it comes out on a belt at the bottom.") % [int(Cfg.HAY_STAIRS_COST), int(rad_to_deg(Cfg.BELT_MAX_SLOPE))],
		"reward": Cfg.tr("BUILD · Hay Stairs · $%d") % int(Cfg.HAY_STAIRS_COST),
	})


	_add("haylift", {
		"name": Cfg.tr("Hay Lift"), "branch": "structures", "kind": "unlock",
		"icon": "hay_lift",
		"costs": [220.0], "requires": ["haystairs"],
		"blurb": Cfg.tr("Unlocks the Hay Lift, from $%d. Carries hay straight up. Click the bottom, look up and click the top. Lifts %s m, and each extra metre costs $%d.") % [
			int(Cfg.HAY_LIFT_COST), HayLift.metres(Cfg.HAY_LIFT_BASE_RISE),
			int(Cfg.HAY_LIFT_SECTION_COST)],
		"reward": Cfg.tr("BUILD · Hay Lift · from $%d") % int(Cfg.HAY_LIFT_COST),
	})


	_add("pelletizer", {
		"name": Cfg.tr("Pelletizer Plans"), "branch": "plant", "kind": "unlock",
		"icon": "pelletizer",
		"costs": [300.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Unlocks the Hay Pelletizer, $%d. Turns %d straw into a fuel brick every %.1f seconds and throws it out. Bricks sell for %.1fx the price of loose hay.") % [int(Cfg.PELLETIZER_COST), Cfg.PELLETIZER_BRICK_STRANDS, Cfg.PELLETIZER_CYCLE_SECONDS, Cfg.PELLETIZER_BRICK_RATIO],
		"reward": Cfg.tr("BUILD · Hay Pelletizer · $%d") % int(Cfg.PELLETIZER_COST),
	})


	_add("launcher", {
		"name": Cfg.tr("Tube Launcher Plans"), "branch": "lines", "kind": "unlock",
		"icon": "launcher",
		"costs": [260.0], "requires": ["splitter"],
		"blurb": Cfg.tr("Unlocks the Tube Launcher, $%d. Throws whatever a belt brings it. Set the angle and power at the machine.") % int(Cfg.LAUNCHER_COST),
		"reward": Cfg.tr("BUILD · Tube Launcher · $%d") % int(Cfg.LAUNCHER_COST),
	})


	_add("electricity", {
		"name": Cfg.tr("Electricity"), "branch": "power", "kind": "unlock",
		"icon": "electricity",
		"costs": [90.0], "requires": ["belt"],
		"blurb": Cfg.tr("Unlocks the Hay Generator ($%d) and Power Poles ($%d). The generator burns hay and makes %.0f kW. Machines within %d m of a pole get power. Belts do not need power.") % [
			int(Cfg.GENERATOR_COST), int(Cfg.POLE_COST), Cfg.GENERATOR_OUTPUT_KW,
			int(Cfg.POLE_SUPPLY_R)],
		"reward": Cfg.tr("BUILD · Hay Generator · $%d · Power Pole · $%d") % [
			int(Cfg.GENERATOR_COST), int(Cfg.POLE_COST)],


		"grants": ["power_pole"],
	})


	_add("power_pole", {
		"name": Cfg.tr("Power Pole"), "branch": "power", "kind": "unlock",
		"icon": "power_pole",
		"costs": [0.0], "requires": ["electricity"], "bundled": true,
		"blurb": Cfg.tr("Carries power. Poles up to %d m apart connect. Machines within %d m get power if nothing blocks the wire. Comes with Electricity.") % [
			int(Cfg.POLE_LINK_R), int(Cfg.POLE_SUPPLY_R)],
		"reward": Cfg.tr("BUILD · Power Pole · $%d") % int(Cfg.POLE_COST),
	})


	_add("generator_output", {
		"name": Cfg.tr("Stronger Generator"), "tuning": true, "branch": "power", "kind": "ranked",
		"icon": "generator+power",
		"costs": [80.0, 140.0, 230.0, 360.0, 540.0, 780.0],
		"requires": ["electricity"],
		"blurb": Cfg.tr("Each level raises how much power a generator can make. It still needs enough hay to get there."),
		"base": "6.0",
		"values": ["7.5", "9.0", "10.5", "12.0", "13.5", "15.0"],
		"unit": " kW",
	})


	_add("borehole", {
		"name": Cfg.tr("Borehole Plans"), "branch": "water", "kind": "unlock",
		"icon": "borehole",
		"costs": [220.0], "requires": ["electricity"],
		"blurb": Cfg.tr("Unlocks the Borehole Pump, $%d. Pumps %.0f litres of water a second and uses %.0f kW. Pipe the water to a pulper.") % [
			int(Cfg.BOREHOLE_COST), Cfg.BOREHOLE_OUTPUT_LPS, Cfg.BOREHOLE_DRAW_KW],
		"reward": Cfg.tr("BUILD · Borehole Pump · $%d") % int(Cfg.BOREHOLE_COST),
	})


	_add("pump_output", {
		"name": Cfg.tr("Deeper Bore"), "tuning": true, "branch": "water", "kind": "ranked",
		"icon": "borehole+more",
		"costs": [90.0, 160.0, 260.0, 400.0, 600.0, 860.0],
		"requires": ["borehole"],
		"blurb": Cfg.tr("Each level makes every pump bring up more water. It does not use more power."),
		"base": "12",
		"values": ["14", "16", "18", "20", "22", "24"],
		"unit": Cfg.tr(" litres a second"),
	})


	_add("water_main", {
		"name": Cfg.tr("Water Mains"), "branch": "water", "kind": "unlock",
		"icon": "water_main",
		"costs": [180.0], "requires": ["borehole"],
		"blurb": Cfg.tr("Unlocks water pipes, $%d a metre. Click the shiny flange on one machine, then on another. Both ends must be on a flange.") % int(Cfg.PIPE_COST_PER_M),
		"reward": Cfg.tr("BUILD · Water Pipe · $%d/m") % int(Cfg.PIPE_COST_PER_M),
	})


	_add("gas_plant", {
		"name": Cfg.tr("Gas Plant Plans"), "branch": "power",
		"kind": "demo" if Cfg.DEMO else "unlock",
		"icon": DEMO_ICON if Cfg.DEMO else "gas_plant",
		"costs": [] if Cfg.DEMO else [Cfg.GAS_PLANT_CARD_COST],
		"requires": ["pelletizer", "water_main"],
		"blurb": Cfg.tr("Unlocks the Gas Plant, $%d. It burns only eco bricks and gets %d times as much power from each straw as a Hay Generator. Makes up to %.0f kW and needs %.0f litres of water a second, so pipe it from a pump.") % [
			int(Cfg.GAS_PLANT_COST), int(Cfg.GAS_PLANT_KJ_PER_STRAND / Cfg.GENERATOR_KJ_PER_STRAND),
			Cfg.GAS_PLANT_OUTPUT_KW, Cfg.GAS_PLANT_OUTPUT_KW * Cfg.GAS_PLANT_LPS_PER_KW],
		"reward": Cfg.tr("BUILD · Gas Plant · $%d") % int(Cfg.GAS_PLANT_COST),
	})


	if not Cfg.DEMO:
		_add("gas_plant_output", {
			"name": Cfg.tr("Bigger Gas Plant"), "tuning": true, "branch": "power", "kind": "ranked",
			"icon": "gas_plant+power",
			"costs": [800.0, 1200.0, 1800.0, 2600.0, 3600.0, 5000.0],
			"requires": ["gas_plant"],
			"blurb": Cfg.tr("Each level raises how much power a gas plant can make. It needs more bricks and more water to get there."),
			"base": "100",
			"values": ["125", "150", "175", "200", "225", "250"],
			"unit": " kW",
		})


	_add("pole_span", {
		"name": Cfg.tr("Longer Spans"), "tuning": true, "branch": "power", "kind": "ranked",
		"icon": "power_pole+span",
		"costs": [100.0, 180.0, 320.0, 560.0, 900.0],
		"requires": ["power_pole"],
		"blurb": Cfg.tr("Each level lets poles and cable boxes connect from 1.5 m further apart."),
		"base": "9.0",
		"values": ["10.5", "12.0", "13.5", "15.0", "16.5"],
		"unit": Cfg.tr(" m between poles"),
	})
	_add("pole_drop", {
		"name": Cfg.tr("Longer Drops"), "tuning": true, "branch": "power", "kind": "ranked",
		"icon": "power_pole+range",
		"costs": [90.0, 160.0, 290.0, 500.0],
		"requires": ["power_pole"],
		"blurb": Cfg.tr("Each level lets poles and cable boxes power machines 1 m further away."),
		"base": "6.0",
		"values": ["7.0", "8.0", "9.0", "10.0"],
		"unit": Cfg.tr(" m to a machine"),
	})


	_add("underground_power", {
		"name": Cfg.tr("Underground Cable"), "branch": "power", "kind": "unlock",
		"icon": "power_pole+underground",
		"costs": [3000.0], "requires": ["power_pole"],
		"blurb": Cfg.tr("Unlocks Cable Boxes, $%d. Works like a pole, but the cable is underground so walls cannot block it. Connects up to %d m away and powers machines within %d m. Hold one to see the cables.") % [
			int(Cfg.BOX_COST), int(Cfg.BOX_LINK_R), int(Cfg.BOX_SUPPLY_R)],
		"reward": Cfg.tr("BUILD · Cable Box · $%d") % int(Cfg.BOX_COST),
	})
	_add("firebox", {
		"name": Cfg.tr("Bigger Firebox"), "tuning": true, "branch": "power", "kind": "ranked",
		"icon": "generator+more",
		"costs": [60.0, 110.0, 190.0, 300.0, 450.0],
		"requires": ["electricity"],
		"blurb": Cfg.tr("Each level lets generators hold 25%% more hay. A full generator now lasts %d minutes at full power, and about %d minutes at max level.") % [
			int(round(Cfg.GENERATOR_FIREBOX_KJ / Cfg.GENERATOR_OUTPUT_KW / 60.0)),
			int(round(Cfg.GENERATOR_FIREBOX_KJ * pow(1.25, 5.0) / Cfg.GENERATOR_OUTPUT_KW / 60.0))],
		"base": _straw(720),
		"values": _straws([900, 1125, 1406, 1758, 2197]),
		"unit": Cfg.tr(" in the box"),
	})


	_add("pellet_batch", {
		"name": Cfg.tr("Bigger Brick Die"), "tuning": true, "branch": "plant", "kind": "ranked",
		"icon": "pelletizer+more",
		"costs": [60.0, 120.0, 220.0, 380.0, 620.0, 1000.0],
		"requires": ["pelletizer"],


		"blurb": Cfg.tr("Each level puts 25%% more hay into every brick, so bricks sell for more and burn longer. A feed disc still takes %d bricks, so discs are worth more too.") % Cfg.BRIQUETTE_BATCH_BRICKS,
		"base": _straw(45),
		"values": _straws([56, 70, 88, 110, 137, 172]),
		"unit": Cfg.tr(" a brick"),
	})
	_add("pellet_speed", {
		"name": Cfg.tr("Faster Grinding"), "tuning": true, "branch": "plant", "kind": "ranked",
		"icon": "pelletizer+speed",
		"costs": [60.0, 120.0, 220.0, 380.0, 620.0, 1000.0],
		"requires": ["pelletizer"],
		"blurb": Cfg.tr("Each level makes every pelletizer 8% faster."),
		"base": "3.00",
		"values": ["2.76", "2.54", "2.34", "2.15", "1.98", "1.82"],
		"unit": Cfg.tr(" s a brick"),
	})
	_add("brick_quality", {
		"name": Cfg.tr("Raise Brick Quality"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "pelletizer+quality",
		"costs": [50.0, 100.0, 180.0, 300.0, 500.0],
		"requires": ["pelletizer"],
		"blurb": Cfg.tr("Each level makes bricks sell for about 6% more."),
		"base": "x2.50",
		"values": ["x2.65", "x2.80", "x2.95", "x3.10", "x3.25"],
		"unit": Cfg.tr(" the hay value"),
	})


	_add("pulper", {
		"name": Cfg.tr("Pulper Plans"), "branch": "plant", "kind": "unlock",
		"icon": "pulper",
		"costs": [380.0], "requires": ["water_main", "splitter"],
		"blurb": _pulper_blurb(),
		"reward": Cfg.tr("BUILD · Hay Pulper · $%d") % int(Cfg.PULPER_COST),
	})


	_add("pulper_batch", {
		"name": Cfg.tr("Bigger Pulp Slabs"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "pulper+more",
		"costs": [80.0, 150.0, 270.0, 450.0, 720.0, 1150.0],
		"requires": ["pulper"],
		"blurb": Cfg.tr("Each level puts 25% more hay into every slab. Slabs sell for more and use the same water."),
		"base": _straw(90),
		"values": _straws([113, 141, 176, 220, 275, 343]),
		"unit": Cfg.tr(" a slab"),
	})


	_add("pulper_speed", {
		"name": Cfg.tr("Faster Drum"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "pulper+speed",
		"costs": [80.0, 150.0, 270.0, 450.0, 720.0, 1150.0],
		"requires": ["pulper"],
		"blurb": Cfg.tr("Each level makes every pulper 8% faster. A faster pulper also uses water faster."),
		"base": "4.03",
		"values": ["3.71", "3.41", "3.14", "2.89", "2.66", "2.45"],
		"unit": Cfg.tr(" s a slab"),
	})


	_add("pulp_quality", {
		"name": Cfg.tr("Raise Pulp Quality"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "pulper+quality",
		"costs": [110.0, 210.0, 380.0, 640.0, 1050.0],
		"requires": ["pulper"],
		"blurb": Cfg.tr("Each level makes slabs sell for more."),
		"base": "x3.60",
		"values": ["x3.90", "x4.20", "x4.50", "x4.80", "x5.10"],
		"unit": Cfg.tr(" the hay value"),
	})


	_add("paper_machine", {
		"name": Cfg.tr("Paper Mill Plans"), "branch": "plant", "kind": "unlock",
		"icon": "paper_machine",
		"costs": [520.0], "requires": ["pulper"],
		"blurb": _paper_blurb(),
		"reward": Cfg.tr("BUILD · Paper Mill · $%d") % int(Cfg.PAPER_COST),
	})


	_add("paper_speed", {
		"name": Cfg.tr("Faster Winder"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "paper_machine+speed",
		"costs": [100.0, 190.0, 340.0, 570.0, 900.0, 1400.0],
		"requires": ["paper_machine"],
		"blurb": Cfg.tr("Each level makes every paper mill 8% faster. It also uses slabs faster."),
		"base": "11.03",
		"values": ["10.15", "9.34", "8.59", "7.90", "7.27", "6.69"],
		"unit": Cfg.tr(" s a roll"),
	})


	_add("paper_quality", {
		"name": Cfg.tr("Finer Paper"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "paper_machine+quality",
		"costs": [140.0, 260.0, 470.0, 790.0, 1300.0],
		"requires": ["paper_machine"],
		"blurb": Cfg.tr("Each level makes paper rolls sell for more."),
		"base": "x1.35",
		"values": ["x1.40", "x1.45", "x1.50", "x1.55", "x1.60"],
		"unit": Cfg.tr(" the slab value"),
	})


	_add("briquette_press", {
		"name": Cfg.tr("Feed Disc Press Plans"), "branch": "plant",
		"kind": "unlock", "icon": "briquette_press",
		"costs": [600.0], "requires": ["pelletizer"],
		"blurb": Cfg.tr("Unlocks the Feed Disc Press, $%d. Presses hay from one belt and eco bricks from another into feed discs. Discs sell for %.2fx the price of loose hay. Each disc uses %d straw and %d bricks. Any size of brick counts as one brick. It is %d m long, has a side input and uses %.1f kW.") % [
			int(Cfg.BRIQUETTE_COST), Cfg.BRIQUETTE_DISC_RATIO,
			Cfg.BRIQUETTE_BATCH_STRANDS, Cfg.BRIQUETTE_BATCH_BRICKS,
			int(Cfg.BRIQUETTE_LENGTH), Cfg.BRIQUETTE_DRAW_KW],
		"reward": Cfg.tr("BUILD · Feed Disc Press · $%d") % int(Cfg.BRIQUETTE_COST),
	})


	_add("briquette_speed", {
		"name": Cfg.tr("Faster Disc Press"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "briquette_press+speed",
		"costs": [110.0, 210.0, 380.0, 630.0, 1000.0, 1600.0],
		"requires": ["briquette_press"],
		"blurb": Cfg.tr("Each level makes every disc press 8% faster. It also uses hay and bricks faster."),
		"base": "4.03",
		"values": ["3.71", "3.41", "3.14", "2.89", "2.66", "2.45"],
		"unit": Cfg.tr(" s a disc"),
	})


	_add("briquette_quality", {
		"name": Cfg.tr("Better Feed"), "tuning": true, "branch": "plant",
		"kind": "ranked", "icon": "briquette_press+quality",
		"costs": [150.0, 280.0, 500.0, 840.0, 1350.0],
		"requires": ["briquette_press"],
		"blurb": Cfg.tr("Each level makes feed discs sell for more."),
		"base": "x4.20",
		"values": ["x4.30", "x4.40", "x4.50", "x4.60", "x4.70"],
		"unit": Cfg.tr(" the loose hay value"),
	})


	_add("yard_space", {
		"name": Cfg.tr("Extend the Shed"), "branch": "structures",
		"kind": "ranked", "icon": "building_plan", "site": "warehouse",
		"costs": [150.0, 250.0, 400.0, 650.0, 1000.0, 1500.0],
		"requires": [ROOT],
		"blurb": Cfg.tr("Each level makes the shed 6 m wider and 6 m longer."),
		"base": "34",
		"values": ["40", "46", "52", "58", "64", "70"],
		"unit": Cfg.tr(" m across"),
	})


	_add("steel_saving", {
		"name": Cfg.tr("Waste Less Material"), "branch": "structures", "kind": "ranked", "icon": "material_saving",
		"costs": [100.0, 200.0, 350.0], "requires": ["deck"],
		"blurb": Cfg.tr("Each level takes 5% off the price of belts, platforms, stairs, railings, walls and roofs. Machines still cost full price."),
		"values": ["-5%", "-10%", "-15%"],
	})


	_add("piston_rake", {
		"name": Cfg.tr("Hay Piston Rake"), "branch": "automation", "kind": "unlock",
		"icon": "piston_rake",
		"costs": [60.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks the Piston Rake, $%d. Digs into the pile and throws the hay behind it every %.1f seconds. Throws %d straw at a time and uses %.0f kW, or %.0f kW with Wider Rake Head. Must face the pile.") % [int(Cfg.RAKE_COST), Cfg.RAKE_THROW_SECONDS, Cfg.RAKE_SMALL_WAD_STRANDS, Cfg.RAKE_DRAW_KW_NARROW, Cfg.RAKE_DRAW_KW],
		"reward": Cfg.tr("BUILD · Piston Rake · $%d") % int(Cfg.RAKE_COST),
	})


	_add("rake_bite", {
		"name": Cfg.tr("Wider Rake Head"), "tuning": true, "branch": "automation",
		"kind": "ranked", "icon": "rake_head+more",
		"costs": [25.0, 100.0, 280.0, 480.0, 800.0],
		"requires": ["piston_rake"],
		"blurb": Cfg.tr("Level 1 raises each throw from %d straw to 50, and each rake then uses %.0f kW instead of %.0f kW. Each level after that adds 25%%.") % [Cfg.RAKE_SMALL_WAD_STRANDS, Cfg.RAKE_DRAW_KW, Cfg.RAKE_DRAW_KW_NARROW],
		"base": _wad(Cfg.RAKE_SMALL_WAD_STRANDS),
		"values": [_wad(50), _wad(63), _wad(78), _wad(98), _wad(122)],
		"unit": Cfg.tr(" a stroke"),
	})


	_add("rake_speed", {
		"name": Cfg.tr("Faster Rake"), "tuning": true, "branch": "automation",
		"kind": "ranked", "icon": "rake_drive+speed",
		"costs": [90.0, 160.0, 280.0, 480.0, 800.0],
		"requires": ["rake_bite"],
		"blurb": Cfg.tr("Each level makes every rake 8% faster."),
		"base": "2.40",
		"values": ["2.21", "2.03", "1.87", "1.72", "1.58"],
		"unit": Cfg.tr(" s a stroke"),
	})


	_add("rake_wheels", {
		"name": Cfg.tr("Rake Wheels"), "branch": "automation", "kind": "unlock",

		"icon": "piston_rake+wheels",
		"costs": [80.0], "requires": ["piston_rake"],
		"blurb": Cfg.tr("Adds Forward and Back buttons to every piston rake. Move a rake a little closer to the pile without taking it down. It stops by itself if something is in the way."),
		"reward": Cfg.tr("RAKES · Forward and Back · move without taking down"),
	})


	var arm_cycle: Array [float] = []
	var arm_rate: Array [float] = []
	for tier: Dictionary in Cfg.ROBOT_ARM_TIERS:
		var secs: float = Cfg.ROBOT_ARM_WORK_SECONDS * float(tier ["cycle_scale"]) + Cfg.ROBOT_ARM_IDLE_SECONDS
		arm_cycle.append(secs)
		arm_rate.append(float(tier ["capacity"]) / secs)


	_add("arm_small", {
		"name": Cfg.tr("Small Arm Plans"), "branch": "automation", "kind": "unlock", "icon": "arm",
		"costs": [90.0], "requires": ["belt"],
		"blurb": (Cfg.tr("Unlocks the Small Arm, $%d. Reaches %.2f m and moves %d straw every %.2f seconds (%.1f a second).")
			% [int(Cfg.ROBOT_ARM_TIERS [0] ["cost"]), float(Cfg.ROBOT_ARM_TIERS [0] ["reach"]),
				int(Cfg.ROBOT_ARM_TIERS [0] ["capacity"]), arm_cycle [0], arm_rate [0]]),
		"reward": Cfg.tr("BUILD · Small Arm · $%d") % int(Cfg.ROBOT_ARM_TIERS [0] ["cost"]),
	})
	_add("arm_standard", {
		"name": Cfg.tr("Standard Arm Plans"), "branch": "automation", "kind": "unlock", "icon": "arm+mk2",
		"costs": [150.0], "requires": ["arm_small"],
		"blurb": (Cfg.tr("Unlocks the Standard Arm, $%d. Reaches %.2f m and moves %d straw every %.2f seconds (%.1f a second, %d%% more). Uses %.1f kW instead of %.1f. Arms you already built stay the size they are.")
			% [int(Cfg.ROBOT_ARM_TIERS [1] ["cost"]), float(Cfg.ROBOT_ARM_TIERS [1] ["reach"]),
				int(Cfg.ROBOT_ARM_TIERS [1] ["capacity"]), arm_cycle [1], arm_rate [1],
				int(round((arm_rate [1] / arm_rate [0] - 1.0) * 100.0)),
				float(Cfg.ROBOT_ARM_TIERS [1] ["draw_kw"]), float(Cfg.ROBOT_ARM_TIERS [0] ["draw_kw"])]),
		"reward": Cfg.tr("BUILD · Standard Arm · $%d") % int(Cfg.ROBOT_ARM_TIERS [1] ["cost"]),
	})
	_add("arm_long", {
		"name": Cfg.tr("Long-Reach Arm Plans"), "branch": "automation", "kind": "unlock", "icon": "arm+mk3",
		"costs": [300.0], "requires": ["arm_standard"],
		"blurb": (Cfg.tr("Unlocks the Long-Reach Arm, $%d. Reaches %.2f m and moves %d straw every %.2f seconds (%.1f a second, %d%% more). Uses %.1f kW instead of %.1f. Arms you already built stay the size they are.")
			% [int(Cfg.ROBOT_ARM_TIERS [2] ["cost"]), float(Cfg.ROBOT_ARM_TIERS [2] ["reach"]),
				int(Cfg.ROBOT_ARM_TIERS [2] ["capacity"]), arm_cycle [2], arm_rate [2],
				int(round((arm_rate [2] / arm_rate [1] - 1.0) * 100.0)),
				float(Cfg.ROBOT_ARM_TIERS [2] ["draw_kw"]), float(Cfg.ROBOT_ARM_TIERS [1] ["draw_kw"])]),
		"reward": Cfg.tr("BUILD · Long-Reach Arm · $%d") % int(Cfg.ROBOT_ARM_TIERS [2] ["cost"]),
	})


	_add("belt_links", {
		"name": Cfg.tr("Belt Links"), "branch": "automation", "kind": "unlock", "icon": "arm+link",
		"costs": [250.0], "requires": ["arm_standard"],
		"blurb": Cfg.tr("Choose the belts an arm works with. It takes from one belt and puts on another. Tick one kind on its plate and it sorts that kind off the belt."),
		"reward": Cfg.tr("ARMS · Belt Links · choose where it takes and puts"),
	})


	_add("overflow_arm", {
		"name": Cfg.tr("Overflow Arm"), "branch": "automation", "kind": "unlock", "icon": "arm+overflow",
		"costs": [350.0], "requires": ["belt_links"],
		"blurb": Cfg.tr("An arm can leave a belt alone while it moves, and only take from it when the belt gets stuck. Tick it under TAKE FROM on the arm."),
		"reward": Cfg.tr("ARMS · Overflow · helps out when a belt gets stuck"),
	})


	_add("pick_order", {
		"name": Cfg.tr("Pick Order"), "branch": "automation", "kind": "unlock", "icon": "arm+order",
		"costs": [200.0], "requires": ["arm_standard"],
		"blurb": Cfg.tr("Choose what each arm grabs first: loose hay, the biggest things, or whatever is closest. Needles always come first."),
		"reward": Cfg.tr("ARMS · Pick Order · choose what it grabs first"),
	})


	_add("drone", {
		"name": Cfg.tr("Hay Drone Plans"), "branch": "automation", "kind": "unlock", "icon": "drone",
		"costs": [320.0], "requires": ["arm_long"],
		"blurb": (Cfg.tr("Unlocks the Hay Drone, $%d. Each extra drone costs %.2fx the last. Give it a zone on the pile and a drop point up to %.0f m away: it digs the zone and flies the hay to the drop.")
			% [int(Cfg.DRONE_COST), Cfg.DRONE_COST_GROWTH, Cfg.DRONE_RADIUS]),
		"reward": Cfg.tr("BUILD · Hay Drone · $%d") % int(Cfg.DRONE_COST),
	})


	_add("drone_collect", {
		"name": Cfg.tr("Drone Pickup"), "branch": "automation", "kind": "unlock", "icon": "drone+pickup",
		"costs": [280.0], "requires": ["drone", "compressor"],
		"blurb": Cfg.tr("Drones can collect things as well as dig. Tick what a drone picks up (wads, bales, bricks and more) and it carries them from its zone to its drop."),
		"reward": Cfg.tr("DRONES · Pickup · collect what you tick"),
	})


	_add("drone_radius", {
		"name": Cfg.tr("Longer Range"), "tuning": true, "branch": "automation", "kind": "ranked",
		"icon": "drone+range",
		"costs": [90.0, 180.0, 320.0, 540.0, 900.0],
		"requires": ["drone"],
		"blurb": Cfg.tr("Each level lets every drone work %.1f m farther from its pad, and makes its zone %.1f m bigger.") % [Cfg.DRONE_RADIUS_STEP, Cfg.DRONE_ZONE_STEP],
		"base": "12.0",
		"values": ["15.6", "19.2", "22.8", "26.4", "30.0"],
		"unit": Cfg.tr(" m reach"),
	})
	_add("drone_speed", {
		"name": Cfg.tr("Faster Rotors"), "tuning": true, "branch": "automation", "kind": "ranked",
		"icon": "drone+speed",
		"costs": [90.0, 180.0, 320.0, 540.0, 900.0],
		"requires": ["drone"],
		"blurb": Cfg.tr("Each level makes every drone fly 8% faster."),
		"base": "6.50",
		"values": ["7.02", "7.58", "8.19", "8.84", "9.55"],
		"unit": " m/s",
	})
	_add("arm_speed", {
		"name": Cfg.tr("Arm Speed"), "tuning": true, "branch": "automation", "kind": "ranked", "icon": "arm+speed",
		"costs": [30.0, 60.0, 100.0, 160.0, 250.0, 380.0, 550.0, 800.0],
		"requires": ["arm_small"],
		"blurb": Cfg.tr("Each level makes every arm 8% faster."),
		"values": ["+9%", "+18%", "+28%", "+39%", "+52%", "+65%", "+79%", "+95%"],
		"suffix": Cfg.tr(" faster"),
	})


	_add("arm_payload", {
		"name": Cfg.tr("Arm Carry Size"), "tuning": true, "branch": "automation", "kind": "ranked", "icon": "arm_carry+more",
		"costs": [30.0, 60.0, 100.0, 160.0, 250.0, 380.0, 550.0, 800.0],
		"requires": ["arm_small"],
		"blurb": Cfg.tr("Each level lets every arm carry 8% more."),
		"values": ["+8%", "+16%", "+24%", "+32%", "+40%", "+48%", "+56%", "+64%"],
	})


	var mk1_rate: float = float(Cfg.SCANNER_TIERS [0] ["batch"]) / float(Cfg.SCANNER_TIERS [0] ["scan_seconds"])
	var mk2_rate: float = float(Cfg.SCANNER_TIERS [1] ["batch"]) / float(Cfg.SCANNER_TIERS [1] ["scan_seconds"])
	var mk2_block: float = Cfg.SCANNER_BLOCK_SECONDS * float(Cfg.SCANNER_TIERS [1] ["scan_seconds"]) / float(Cfg.SCANNER_TIERS [0] ["scan_seconds"])

	_add("scanner_mk1", {
		"name": Cfg.tr("Scanner Mk I Plans"), "branch": "prospecting", "kind": "unlock", "icon": "scanner",
		"costs": [100.0], "requires": ["belt"],
		"blurb": (Cfg.tr("Unlocks the Scanner Mk I, $%d. Put it on a belt. Checks %d straw every %.1f seconds (%.1f a second) for needles. Stops the belt when it finds one, until you empty the drawer. The drawer holds %d.")
			% [int(Cfg.SCANNER_TIERS [0] ["cost"]), int(Cfg.SCANNER_TIERS [0] ["batch"]),
				float(Cfg.SCANNER_TIERS [0] ["scan_seconds"]), mk1_rate, Cfg.SCANNER_BIN_CAPACITY]),
		"reward": Cfg.tr("BUILD · Scanner Mk I · $%d") % int(Cfg.SCANNER_TIERS [0] ["cost"]),
	})


	_add("cabinet", {
		"name": Cfg.tr("Needle Cabinet"), "branch": "prospecting", "kind": "unlock", "icon": "cabinet",
		"costs": [10.0], "requires": [ROOT],
		"blurb": Cfg.tr("Unlocks the Needle Cabinet, $%d. One per yard. Has a slot for each of the %d kinds of needle.") % [int(Cfg.CABINET_COST), NeedleTypes.count()],
		"reward": Cfg.tr("BUILD · Needle Cabinet · $%d") % int(Cfg.CABINET_COST),
	})


	_add("scanner_mk2", {
		"name": Cfg.tr("Scanner Mk II Plans"), "branch": "prospecting", "kind": "unlock", "icon": "scanner+mk2",
		"costs": [300.0], "requires": ["scanner_mk1"],
		"blurb": (Cfg.tr("Upgrades all scanners to Mk II, $%d. Does not stop the belt when it finds a needle. Checks %.1f straw a second (Mk I: %.1f, so %d%% faster) and a bale in %.1f seconds (Mk I: %.1f).")
			% [int(Cfg.SCANNER_TIERS [1] ["cost"]), mk2_rate, mk1_rate,
				int(round((mk2_rate / mk1_rate - 1.0) * 100.0)),
				mk2_block, Cfg.SCANNER_BLOCK_SECONDS]),
		"reward": Cfg.tr("UPGRADE · Scanner Mk II · $%d  ·  every scanner you own") % int(Cfg.SCANNER_TIERS [1] ["cost"]),
	})


	var dish_kind:= "demo" if Cfg.DEMO else "unlock"
	var dish_icon:= DEMO_ICON if Cfg.DEMO else "needle_radar"
	_add("radar_mk1", {
		"name": Cfg.tr("Satellite Dish Mk I Plans"), "branch": "prospecting", "kind": dish_kind, "icon": dish_icon,
		"costs": [] if Cfg.DEMO else [float(Cfg.RADAR_TIERS [0] ["plans"])], "requires": ["scanner_mk1"],
		"blurb": (Cfg.tr("Unlocks the Satellite Dish, $%d. One per yard. Scans the pile and puts a circle around every needle within %d m for %d seconds. Recharges in %d seconds.")
			% [int(Cfg.RADAR_COST), int(Cfg.RADAR_RANGE),
				int(Cfg.RADAR_TIERS [0] ["seconds"]), int(Cfg.RADAR_COOLDOWN)]),
		"reward": Cfg.tr("BUILD · Satellite Dish · $%d") % int(Cfg.RADAR_COST),
	})
	_add("radar_mk2", {
		"name": Cfg.tr("Satellite Dish Mk II Plans"), "branch": "prospecting", "kind": dish_kind, "icon": DEMO_ICON if Cfg.DEMO else "needle_radar+mk2",
		"costs": [] if Cfg.DEMO else [float(Cfg.RADAR_TIERS [1] ["plans"])], "requires": ["radar_mk1"],
		"blurb": (Cfg.tr("Upgrades the dish. Shows the exact spot of every needle in range for %d seconds.")
			% int(Cfg.RADAR_TIERS [1] ["seconds"])),
		"reward": Cfg.tr("UPGRADE · Satellite Dish Mk II  ·  exact spots"),
	})
	_add("radar_mk3", {
		"name": Cfg.tr("Satellite Dish Mk III Plans"), "branch": "prospecting", "kind": dish_kind, "icon": DEMO_ICON if Cfg.DEMO else "needle_radar+mk3",
		"costs": [] if Cfg.DEMO else [float(Cfg.RADAR_TIERS [2] ["plans"])], "requires": ["radar_mk2"],
		"blurb": (Cfg.tr("Upgrades the dish. Needle markers last %d seconds instead of %d.")
			% [int(Cfg.RADAR_TIERS [2] ["seconds"]), int(Cfg.RADAR_TIERS [1] ["seconds"])]),
		"reward": Cfg.tr("UPGRADE · Satellite Dish Mk III  ·  markers last %d s") % int(Cfg.RADAR_TIERS [2] ["seconds"]),
	})
	_add("radar_mk4", {
		"name": Cfg.tr("Satellite Dish Mk IV Plans"), "branch": "prospecting", "kind": dish_kind, "icon": DEMO_ICON if Cfg.DEMO else "needle_radar+mk4",
		"costs": [] if Cfg.DEMO else [float(Cfg.RADAR_TIERS [3] ["plans"])], "requires": ["radar_mk3"],
		"blurb": (Cfg.tr("Upgrades the dish. Markers also show how deep each needle is. They last %d seconds.")
			% int(Cfg.RADAR_TIERS [3] ["seconds"])),
		"reward": Cfg.tr("UPGRADE · Satellite Dish Mk IV  ·  shows depth"),
	})


	_add("scan_batch", {
		"name": Cfg.tr("Scan Batch Size"), "tuning": true, "branch": "prospecting", "kind": "ranked", "icon": "scanner+more",
		"costs": [40.0, 80.0, 150.0, 280.0, 500.0],
		"requires": ["scanner_mk1"],
		"blurb": Cfg.tr("Each level lets scanners check 25% more hay at once."),
		"values": ["+25%", "+56%", "+95%", "+144%", "+205%"],
	})
	_add("scan_speed", {
		"name": Cfg.tr("Scan Cycle Speed"), "tuning": true, "branch": "prospecting", "kind": "ranked", "icon": "scanner+speed",
		"costs": [40.0, 80.0, 150.0, 280.0, 500.0],
		"requires": ["scanner_mk1"],
		"blurb": Cfg.tr("Each level makes scanners check loose hay 8% faster. Bales and bricks do not change."),
		"values": ["+9%", "+18%", "+28%", "+39%", "+52%"],
		"suffix": Cfg.tr(" faster"),
	})


	_add("scan_solids", {
		"name": Cfg.tr("Scan Bigger Blocks"), "branch": "prospecting", "kind": "ranked", "icon": "scanner+block",
		"costs": [50.0, 100.0, 180.0, 300.0, 500.0, 800.0],
		"requires": ["scanner_mk1", "splitter"],
		"blurb": (Cfg.tr("Scanners check bales and bricks one at a time: %.1f seconds each on a Mk I, %.1f on a Mk II. Each level makes this 12%% faster.")
			% [Cfg.SCANNER_BLOCK_SECONDS, mk2_block]),
		"base": "6.0",
		"values": ["5.3", "4.6", "4.1", "3.6", "3.2", "2.8"],
		"unit": Cfg.tr(" s a block"),
	})


	_add("metal_detector", {
		"name": Cfg.tr("Metal Detector"), "branch": "prospecting", "kind": "unlock",
		"icon": "metal_detector",
		"costs": [130.0], "requires": ["cabinet"],
		"blurb": Cfg.tr("Unlocks the metal detector in the shop, $%d. Beeps faster the closer you are to a needle, but does not show which way. Reaches %.1f m, less through hay.") % [int(Cfg.PRICE_METAL_DETECTOR), Cfg.DETECT_RANGE],
		"reward": Cfg.tr("SHOP · Metal Detector · $%d") % int(Cfg.PRICE_METAL_DETECTOR),
	})


	_add("detector_coil", {
		"name": Cfg.tr("Bigger Coil"), "tuning": true, "branch": "prospecting", "kind": "ranked",
		"icon": "metal_detector+range",
		"costs": [90.0, 200.0, 420.0], "requires": ["metal_detector"],
		"blurb": Cfg.tr("Each level makes the metal detector reach 18% further."),
		"base": "7.0 m",
		"values": ["8.3 m", "9.5 m", "10.8 m"], "unit": Cfg.tr(" in the open"),
	})


	_add("drawer_space", {
		"name": Cfg.tr("Bigger Drawer"), "tuning": true, "branch": "prospecting", "kind": "ranked", "icon": "scanner+more",
		"costs": [50.0, 100.0, 200.0], "requires": ["scanner_mk1"],
		"blurb": Cfg.tr("Each level lets scanner drawers hold 4 more needles."),
		"base": "8", "values": ["12", "16", "20"], "unit": Cfg.tr(" needles"),
	})


	_add("hay_price", {
		"name": Cfg.tr("Better Bargaining"), "branch": "selling", "kind": "ranked", "icon": "hay_value",
		"costs": [10.0, 25.0, 50.0, 100.0, 200.0], "requires": [ROOT],
		"blurb": Cfg.tr("Each level makes everything sell for 5% more."),
		"base": "x1.00",
		"values": ["x1.05", "x1.10", "x1.15", "x1.20", "x1.25"],
		"unit": Cfg.tr(" the base price"),
	})


	_add("work_boots", {
		"name": Cfg.tr("Yard Boots"), "branch": "fitness", "kind": "ranked", "icon": "boots+speed",
		"costs": [30.0, 60.0, 120.0, 220.0, 400.0],
		"requires": [ROOT],
		"blurb": Cfg.tr("Each level makes you walk and run 4% faster."),
		"base": "4.20",
		"values": ["4.37", "4.54", "4.70", "4.87", "5.04"],
		"unit": Cfg.tr(" m/s walking"),
	})


	_add("strong_back", {
		"name": Cfg.tr("Strong Back"), "branch": "fitness", "kind": "ranked", "icon": "strong_back",
		"costs": [40.0, 80.0, 160.0, 300.0, 550.0], "requires": [ROOT],
		"blurb": Cfg.tr("Each level gives you 15% more stamina."),
		"base": "100",
		"values": ["115", "130", "145", "160", "175"], "unit": Cfg.tr(" stamina"),
	})


	_add("arm_load", {
		"name": Cfg.tr("Carry More"), "branch": "fitness", "kind": "ranked", "icon": "arm_load",
		"costs": [60.0, 140.0, 300.0, 650.0], "requires": ["strong_back"],
		"blurb": Cfg.tr("Each level lets you carry one more bale, wad or brick. They stack up in your arms, and E puts the top one down."),
		"base": "1",
		"values": ["2", "3", "4", "5"],
		"unit": Cfg.tr(" in your arms"),
	})
	_add("second_wind", {
		"name": Cfg.tr("Second Wind"), "branch": "fitness", "kind": "ranked", "icon": "second_wind",
		"costs": [50.0, 100.0, 200.0, 380.0, 700.0], "requires": [ROOT],
		"blurb": Cfg.tr("Each level makes stamina come back 18% faster."),
		"base": "22.0",
		"values": ["26.0", "29.9", "33.9", "37.8", "41.8"], "unit": Cfg.tr(" a second"),
	})
	_add("easy_swing", {
		"name": Cfg.tr("Easy Swing"), "branch": "fitness", "kind": "ranked", "icon": "easy_swing",
		"costs": [60.0, 120.0, 240.0, 450.0, 850.0], "requires": ["strong_back"],
		"blurb": Cfg.tr("Each level makes digging use 8% less stamina."),
		"base": "12.0",
		"values": ["11.0", "10.1", "9.1", "8.2", "7.2"], "unit": Cfg.tr(" a dig"),
	})


	_add("steady_carry", {
		"name": Cfg.tr("Steady Hands"), "branch": "fitness", "kind": "ranked", "icon": "bucket+level",
		"costs": [30.0, 60.0, 120.0, 220.0, 400.0],
		"requires": ["work_boots"],
		"blurb": Cfg.tr("Each level makes you spill 8% less hay while running."),
		"values": ["-8%", "-16%", "-24%", "-32%", "-40%"],
		"suffix": Cfg.tr(" sway and spill"),
	})
	_add("careful_steps", {
		"name": Cfg.tr("Careful Steps"), "branch": "fitness", "kind": "ranked", "icon": "careful_steps",
		"costs": [20.0, 40.0, 80.0, 150.0, 250.0], "requires": ["steady_carry"],
		"blurb": Cfg.tr("Each level makes you walk 5% faster while crouching."),
		"base": "1.90",
		"values": ["1.99", "2.09", "2.18", "2.28", "2.38"], "unit": Cfg.tr(" m/s crouching"),
	})
	_add("grab_reach", {
		"name": Cfg.tr("Longer Reach"), "branch": "fitness", "kind": "ranked", "icon": "grab_reach",
		"costs": [30.0, 60.0, 120.0, 220.0, 400.0],
		"requires": [ROOT],
		"blurb": Cfg.tr("Each level lets you pick things up from 30 cm further away."),
		"base": "2.80",
		"values": ["3.10", "3.40", "3.70", "4.00", "4.30"],
		"unit": " m",
	})


	_add("jump_height", {
		"name": Cfg.tr("Spring Heels"), "branch": "fitness", "kind": "ranked", "icon": "jump_height",
		"costs": [25.0, 50.0, 100.0, 180.0, 320.0], "requires": ["work_boots"],
		"blurb": Cfg.tr("Each level makes you jump 5 cm higher."),
		"base": "0.76",
		"values": ["0.81", "0.86", "0.91", "0.96", "1.01"], "unit": " m",
	})


	_add("jetpack", {
		"name": Cfg.tr("Jetpack"), "branch": "fitness",
		"kind": "demo" if Cfg.DEMO else "unlock",
		"icon": DEMO_ICON if Cfg.DEMO else "jetpack",
		"costs": [] if Cfg.DEMO else [Cfg.JETPACK_CARD_COST], "requires": ["jump_height"],
		"blurb": Cfg.tr("You wear a jetpack. Jump, then hold jump in the air to fly. A full tank lasts %d seconds and refills in about %d seconds after you land. Hold an eco brick and press E to refill it at once.") % [int(Cfg.JETPACK_TANK_SECONDS), int(Cfg.JETPACK_RECHARGE_SECONDS)],
		"reward": Cfg.tr("WORN · Jetpack · jump, then jump again to fly"),
	})


	_add("grippy_boots", {
		"name": Cfg.tr("Grippy Boots"), "branch": "fitness",
		"kind": "demo" if Cfg.DEMO else "unlock",
		"icon": DEMO_ICON if Cfg.DEMO else "boots+grip",
		"costs": [] if Cfg.DEMO else [Cfg.GRIPPY_BOOTS_CARD_COST], "requires": ["work_boots"],
		"blurb": Cfg.tr("Your boots grip the rubber, so a running belt no longer pushes you along. Walk on your belts any way you like."),
		"reward": Cfg.tr("WORN · Grippy Boots · belts no longer carry you"),
	})
	_add("soft_landings", {
		"name": Cfg.tr("Soft Landings"), "branch": "fitness", "kind": "ranked", "icon": "soft_landing",
		"costs": [15.0, 30.0, 60.0, 120.0, 200.0], "requires": ["work_boots"],
		"blurb": Cfg.tr("Each level makes you spill 10% less hay when you jump."),
		"values": ["-10%", "-20%", "-30%", "-40%", "-50%"], "suffix": Cfg.tr(" jump jolt"),
	})
	_add("build_reach", {
		"name": Cfg.tr("Longer Tape Measure"), "branch": "fitness", "kind": "ranked", "icon": "build_reach",
		"costs": [20.0, 40.0, 80.0, 150.0, 250.0], "requires": ["grab_reach", "belt"],
		"blurb": Cfg.tr("Each level lets you place buildings 50 cm further away."),
		"base": "6.0",
		"values": ["6.5", "7.0", "7.5", "8.0", "8.5"], "unit": " m",
	})


static func invalidate() -> void:
	_nodes = { }
	_order = []


static func ids() -> Array:
	nodes()
	return _order


static func has_id(id: String) -> bool:
	return nodes().has(id)


static func spec(id: String) -> Dictionary:
	return nodes().get(id, { })


static func display_name(id: String) -> String:
	var text:= str(spec(id).get("name", ""))
	return Cfg.tr(text) if text != "" else id


static func branch_of(id: String) -> String:
	return str(spec(id).get("branch", ""))


static var _depth: Dictionary = { }

static func depth_of(id: String) -> int:
	if id == ROOT or not has_id(id):
		return 0
	if _depth.has(id):
		return int(_depth [id])
	var deepest:= 0
	for need: String in requires(id):
		deepest = maxi(deepest, depth_of(need))
	_depth [id] = deepest + 1
	return deepest + 1


static func stage_of(id: String) -> int:
	return maxi(depth_of(id) - 1, 0)


static func stage_count() -> int:
	var n:= 0
	for id: String in ids():
		n = maxi(n, stage_of(id) + 1)
	return n


static func stage_name(k: int) -> String:
	return Cfg.tr("1 step") if k == 0 else Cfg.tr("%d steps") % (k + 1)


static func kind_of(id: String) -> String:
	return str(spec(id).get("kind", "unlock"))


static func is_demo(id: String) -> bool:
	return kind_of(id) == "demo"


static func site_of(id: String) -> String:
	return str(spec(id).get("site", ""))


static func blurb(id: String) -> String:


	match id:
		"pulper":
			return _pulper_blurb()
		"paper_machine":
			return _paper_blurb()
	var text:= str(spec(id).get("blurb", ""))
	return "" if text == "" else Cfg.tr(text)


static func _pulper_blurb() -> String:
	return Cfg.tr("Unlocks the Hay Pulper, $%d. Mixes %d straw with %.0f litres of water into a pulp slab. Slabs sell for %.1fx the price of loose hay. Needs hay, power and a water pipe.") % [
		int(Cfg.PULPER_COST), Tech.pulper_batch_strands(),
		Cfg.PULPER_WATER_LITRES, Tech.pulp_value_ratio()]


static func _paper_blurb() -> String:
	return Cfg.tr("Unlocks the Paper Mill, $%d. Turns %d pulp slabs into a paper roll worth %.2fx the slabs. It is %d m long and uses %.0f kW.") % [
		int(Cfg.PAPER_COST), Cfg.PAPER_SLABS_PER_ROLL, Tech.paper_value_ratio(),
		int(Cfg.PAPER_LENGTH), Cfg.PAPER_DRAW_KW]


static func reward(id: String) -> String:
	var text:= str(spec(id).get("reward", ""))
	return "" if text == "" else Cfg.tr(text)


static func icon_of(id: String) -> String:
	return str(spec(id).get("icon", ""))


static func requires(id: String) -> Array:
	return spec(id).get("requires", [])


static func max_rank(id: String) -> int:
	var costs: Array = spec(id).get("costs", [])
	return maxi(costs.size(), 1)


const LATE_RANK_MIN_LADDER:= 4


static func cost_at(id: String, rank: int) -> float:
	var costs: Array = spec(id).get("costs", [])
	if rank < 0 or rank >= costs.size():
		return 0.0
	var base:= float(costs [rank])


	if costs.size() < LATE_RANK_MIN_LADDER or bool(spec(id).get("flat", false)):
		return base
	var first_late: int = int(ceil(float(costs.size()) / 2.0))
	if rank < first_late:
		return base
	return roundf(base * pow(Cfg.TECH_LATE_RANK_SCALE, float(rank - first_late + 1)))


static func value_at(id: String, rank: int) -> String:
	var values: Array = spec(id).get("values", [])
	var tail:= str(spec(id).get("unit", spec(id).get("suffix", "")))
	if rank == 0:
		var base:= str(spec(id).get("base", ""))
		return "" if base == "" else "%s%s" % [base, tail]
	if rank < 0 or rank > values.size():
		return ""
	return "%s%s" % [str(values [rank - 1]), tail]


static func branch_name(branch: String) -> String:
	for b: Dictionary in BRANCHES:
		if str(b ["id"]) == branch:
			return Cfg.tr(str(b ["name"]))
	return branch.capitalize()


static func branch_subtitle(branch: String) -> String:
	for b: Dictionary in BRANCHES:
		if str(b ["id"]) == branch:
			var text:= str(b.get("subtitle", ""))
			return "" if text == "" else Cfg.tr(text)
	return ""


static func branch_colour(branch: String) -> Color:
	for b: Dictionary in BRANCHES:
		if str(b ["id"]) == branch:
			return b ["colour"]
	return Color.WHITE


static func ids_in(branch: String) -> Array:
	var out: Array = []
	for id: String in ids():
		if branch_of(id) == branch:
			out.append(id)
	return out


static func is_tuning(id: String) -> bool:
	return bool(spec(id).get("tuning", false))


static func grants(id: String) -> Array:
	return spec(id).get("grants", [])


static func is_bundled(id: String) -> bool:
	return bool(spec(id).get("bundled", false))


static func bundled_with(id: String) -> String:
	for other: String in ids():
		if grants(other).has(id):
			return other
	return ""


static func tuned_machine(id: String) -> String:
	if not is_tuning(id):
		return ""
	var at:= id


	for _step in ids().size():
		var needs: Array = requires(at)
		if needs.is_empty():
			return ""
		at = str(needs [0])
		if not is_tuning(at):
			return at
	return ""


static func tuning_groups() -> Dictionary:
	var out: Dictionary = { }
	for id: String in ids():
		var machine:= tuned_machine(id)
		if machine == "":
			continue
		if not out.has(machine):
			out [machine] = []
		(out [machine] as Array).append(id)
	return out


static func tuning_title(machine: String) -> String:
	if TUNING_TITLES.has(machine):
		return Cfg.tr(str(TUNING_TITLES [machine]))
	var base:= str(spec(machine).get("name", machine))


	for suffix: String in [" Plans", " Licence"]:
		if base.ends_with(suffix):
			base = base.left(base.length() - suffix.length())
	return Cfg.tr("%s upgrades") % Cfg.tr(base)


static func children_of(id: String) -> Array:
	var out: Array = []
	for other: String in ids():
		if requires(other).has(id):
			out.append(other)
	return out
