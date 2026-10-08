class_name MissionBook
extends RefCounted


const LIVE_COUNT:= 20


const CUE_SHOWINGS:= 3


const STEPS:= [
	{
		"id": "first_hay",
		"title": "Pick up some hay",
		"detail": "Look at the haystack. Hold {primary} to pull out hay. Your hand takes only one straw at a time. A shovel takes much more.",
		"keys": "{primary}",
		"cue_hold": true,
	},
	{
		"id": "throw_hay",
		"title": "Throw the hay",
		"detail": "Press {secondary} to throw the hay you are holding.",
		"keys": "{secondary}",
		"cue_note": "Look where you want it, then let go",
	},


	{
		"id": "run",
		"title": "Run",
		"detail": "Hold {sprint} while you walk to run. Running tires you out. Walk for a moment and you can run again.",
		"keys": "{sprint}",
		"cue_hold": true,
		"cue_note": "Hold it while you walk",


		"goal": 1.5, "goal_kind": "bar",
	},
	{
		"id": "first_dollar",
		"title": "Sell hay at the stand",
		"detail": "The selling stand is in the far corner. Walk there. Stand at the open bay and press {primary} to drop the hay in. You get money for it.",
		"keys": "",


		"goal": 0.1, "goal_kind": "money",
	},
	{
		"id": "open_tech",
		"title": "Open the tech tree",
		"detail": "Press {tech_tree} to open the tech tree. Buy machines and upgrades here. Press {tech_tree} again to close it.",
		"keys": "{tech_tree}",
	},


	{
		"id": "buy_handful",
		"title": "Buy Bigger Handful",
		"detail": "Press {tech_tree}. Find the Bigger Handful card and click it. It costs {cost:hand_carry}. Now your hand holds two straws at a time. Buy more levels to hold even more.",
		"keys": "{tech_tree}",
		"board": ["hand_carry"],
	},


	{
		"id": "buy_toy_licence",
		"title": "Buy the Toy Shovel card",
		"detail": "Sell hay until the bar is full. Every level of Bigger Handful you buy on the way fills it faster. Then press {tech_tree}. Find the Toy Shovel card and click it. It costs {cost:sand_shovel}. The card does not give you a shovel. It puts one in the shop, and the {price:sand_shovel} you have left buys it.",
		"keys": "{tech_tree}",
		"board": ["sand_shovel"],
		"goal": 3.25, "goal_kind": "money",


		"cue_when_paid": true,
	},
	{
		"id": "find_shop",
		"title": "Find the supply shop",
		"detail": "The shop is the other corner building. Walk to the counter. Press {interact} to open the shop.",
		"keys": "{interact}",
	},
	{
		"id": "buy_toy_shovel",
		"title": "Buy the toy shovel",
		"detail": "Click Toy Shovel to buy it.",
		"keys": "",
	},
	{
		"id": "pick_up_shovel",
		"title": "Pick the shovel up",
		"detail": "The shop drops what you buy at your feet. Look down at the shovel. Press {interact} to pick it up. It takes the second box on the bar, next to your hand. Press {hotbar_2} to take it out again, and {hotbar_1} to go back to bare hands.",
		"keys": "{interact}",
	},
	{
		"id": "scoop",
		"title": "Dig a scoop",
		"detail": "Point at the haystack. Press {primary} to dig. The hay sits on the blade and stays there. Now you can carry it anywhere.",
		"keys": "{primary}",
	},
	{
		"id": "stack_scoop",
		"title": "Take a second scoop",
		"detail": "Press {primary} two more times. Each dig adds more hay to the shovel.",
		"keys": "{primary}",
		"goal": 2.0, "goal_kind": "count",
		"cue_note": "The shovel keeps what it has",


		"cue": false,
	},
	{
		"id": "tilt_pour",
		"title": "Practise tipping",
		"detail": "Hold {secondary} and move the mouse to tip the shovel. Do this ten times.",
		"keys": "{secondary}",
		"goal": 10.0, "goal_kind": "count",
		"cue_hold": true, "cue_sway": true,


		"simple": {
			"title": "Empty the blade",
			"detail": "Point where you want the hay. Press {secondary}. The whole load goes there. Do this three times.",
			"goal": 3.0,
			"cue_hold": false, "cue_sway": false,
		},
	},


	{
		"id": "buy_bucket",
		"title": "Get a bucket",
		"detail": "Press {tech_tree}. Buy the Bucket Licence for {cost:bucket}. Then buy the bucket in the shop for {price:bucket}. It holds much more hay than a shovel.",
		"keys": "",
		"board": ["bucket"],

		"plead": false,
	},
	{
		"id": "fill_bucket",
		"title": "Fill the bucket",
		"detail": "Put the bucket on the ground. Press {primary} to dig hay. Now AIM AT THE BUCKET and hold {secondary}, turning the blade over. The hay drops in.",
		"keys": "{secondary}",
		"goal": 1.0, "goal_kind": "fraction",
		"cue_hold": true, "cue_sway": true,
		"cue_note": "Aim at the bucket, then let the hay go",


		"simple": {
			"detail": "Put the bucket on the ground. Press {primary} to dig hay. Now AIM AT THE BUCKET and press {secondary}. The whole load goes where you are looking.",
			"cue_hold": false, "cue_sway": false,
		},
	},
	{
		"id": "pour_bucket",
		"title": "Empty it into the stand",
		"detail": "Press {interact} to pick the bucket up. Carry it to the stand. Stand at the open bay. Hold {secondary} to tip the hay in.",
		"keys": "{secondary}",
		"cue_hold": true, "cue_sway": true,
		"cue_note": "The bucket empties only when you tilt it",
	},


	{
		"id": "twenty_dollars",
		"title": "Earn thirty dollars",
		"detail": "Sell hay until the bar is full. Buying things on the way does not slow the bar down. The spade costs {cost:spade} for the card and {price:spade} for the spade itself.",
		"keys": "",
		"goal": 30.0, "goal_kind": "money", "goal_from": "earned",
	},
	{
		"id": "buy_spade",
		"title": "Buy the spade",
		"detail": "Press {tech_tree}. Buy the Spade card for {cost:spade}. Then buy the spade in the shop for {price:spade}. Press {interact} to pick it up. It goes in the next free box on your bar.",
		"keys": "{tech_tree}",
		"cue_after": "spade", "cue_then": "{interact}",
		"cue_note": "The card is in the tech tree, the spade is in the shop",
	},
	{
		"id": "drop_tool",
		"title": "Put a tool down",
		"detail": "Take a tool in your hands. Press {drop_tool} to put it on the ground, or {throw_item} to throw it. It stays there. Walk to it and press {interact} to pick it up again.",
		"keys": "{drop_tool}",
	},
	{
		"id": "bring_to_me",
		"title": "Fetch a lost tool",
		"detail": "Press {drop_tool} to put a tool on the ground. Walk to the shop counter and press {interact}. Click BRING TO ME next to that tool. It comes back to your feet.",
		"keys": "{drop_tool}",


		"cue": false,


		"reward": "cabinet",
	},


	{
		"id": "open_build",
		"title": "Open the build catalogue",
		"detail": "Press {build_catalog} to open the build catalogue. Buy things in the tech tree, then build them from here.",
		"keys": "{build_catalog}",
	},
	{
		"id": "build_cabinet",
		"title": "Build the needle cabinet",
		"detail": "Press {build_catalog} and pick the needle cabinet. It is free. Click a place on the floor to build it.",
		"keys": "{build_catalog}",
		"cue_note": "Your first building is a gift",
	},
	{
		"id": "build_belt",
		"title": "Lay your first conveyor",
		"detail": "Press {tech_tree}. Buy Conveyor Plans for {cost:belt}. Press {build_catalog} and pick the belt. Click once for the start. Click again for the end. Hay on a belt moves by itself.",
		"keys": "{build_catalog}",
		"board": ["belt"],


		"cue": false,
	},
	{


		"id": "build_distance",
		"title": "Move it closer or further",
		"detail": "Press {build_catalog} and pick anything. You now see a copy of it on your cursor. Roll the mouse wheel, or press {build_closer|keys} and {build_further|keys}. The copy moves closer to you and further away.",
		"keys": "{build_further}",
		"cue_alt": "{build_closer}",
		"cue_note": "Move it away, then bring it back",
		"goal": 2.0, "goal_kind": "count",
	},


	{
		"id": "grid_place",
		"title": "Line it up on the grid",
		"detail": "Press {build_catalog} and pick a belt or a machine. Press {build_grid}. Squares appear on the floor and your building lines up with them. Press {build_grid} again to turn the grid off.",
		"keys": "{build_grid}",
		"cue_note": "Neat rows are easier to join up",
	},
	{
		"id": "belt_feeds_stand",
		"title": "Run a belt to the stand",
		"detail": "Press {build_catalog} and pick the belt. End the belt at the stand's open bay. Now hay on that belt sells by itself.",
		"keys": "",
	},
	{


		"id": "reverse_belt",
		"title": "Turn a belt round",
		"detail": "A belt carries hay one way only. Look at a belt you built. Arrows appear on it showing which way the hay goes. Hold {interact} until they swing round. The belt now runs the other way. It costs nothing and you keep the belt.",
		"keys": "{interact}",
		"cue_hold": true,
		"cue_note": "The arrows show which way the hay goes",
	},


	{
		"id": "copy_build",
		"title": "Copy a building",
		"detail": "Look at your needle cabinet and press {pick_build}. Now you hold one just like it, ready to build. This works on anything you built.",
		"keys": "{pick_build}",
		"cue_note": "Quicker than finding it in the list",
	},
	{
		"id": "dismantle",
		"title": "Take something down again",
		"detail": "Point at anything you built. Hold {dismantle} until it comes down. You get all your money back.",
		"keys": "{dismantle}",
		"cue_hold": true,
	},


	{
		"id": "turn_build",
		"title": "Turn it round",
		"detail": "Press {build_catalog} and pick something to build. Press {build_rotate}. Each press turns it a quarter.",
		"keys": "{build_rotate}",
		"cue_note": "Machines work only when they face the right way",
	},


	{
		"id": "power_up",
		"title": "Get the power running",
		"detail": "Buy Electricity and build a Hay Generator. Put hay in it to burn.",
		"keys": "",
		"board": ["electricity"],
		"reward": "rake",

		"plead": false,
	},
	{
		"id": "build_rake",
		"title": "Place your free rake",
		"detail": "Press {build_catalog} and pick the Piston Rake. It is free. Put it in front of the haystack, facing the hay.",
		"keys": "{build_catalog}",
		"cue_note": "Face it at the hay",
		"reward": "pole",
	},


	{
		"id": "build_power",
		"title": "Connect the rake with a power pole",
		"detail": "Build a Power Pole within {num:POLE_SUPPLY_R} metres of the rake and the generator. Then the rake starts working.",
		"keys": "{build_catalog}",
		"cue": false,
	},


	{
		"id": "rake_throw",
		"title": "Set how far the rake throws",
		"detail": "Press {interact} at the rake. Drag the slider to choose where the hay lands. Make it land on your conveyor, or in a bucket or wheelbarrow.",
		"keys": "{interact}",
		"cue_note": "The marks show where the hay lands",
	},


	{
		"id": "upgrade_belt",
		"title": "Make your belts faster",
		"detail": "Your belts move hay slowly. Press {tech_tree} and buy the first level of Faster Belt Motor for {cost:belt_speed}. Every belt gets faster, even the ones you already built.",
		"keys": "{tech_tree}",
		"board": ["belt_speed"],

		"plead": false,
	},
	{
		"id": "build_arm",
		"title": "Build a robotic arm",
		"detail": "Press {tech_tree}. Buy Small Arm Plans for {cost:arm_small}. Press {build_catalog} and place the arm between the haystack and a belt, {price:arm} to build, with a pole near it. It digs and puts the hay on the belt.",
		"keys": "",
		"board": ["arm_small"],
		"plead": false,
	},


	{
		"id": "buy_detector",
		"title": "Buy the metal detector",
		"detail": "Press {tech_tree} and buy the Metal Detector card for {cost:metal_detector}. Then buy the detector in the shop for {price:detector}. It beeps faster the closer you are to a needle. Walk over the pile and listen.",
		"keys": "",
		"board": ["metal_detector"],
		"plead": false,
	},


	{
		"id": "detector_power",
		"title": "Switch the detector on and off",
		"detail": "Hold the detector. Press {secondary} to turn it on and again to turn it off. Do this three times.",
		"keys": "{secondary}",
		"goal": 3.0, "goal_kind": "count",
		"cue_note": "Down is on, up is off",
	},
	{
		"id": "pin_contract",
		"title": "Pin the delivery order",
		"detail": "The board by the bay door has an order on it. Look at the big sheet on the left and press {interact}. It shows in the corner of your screen.",


		"detail_pinned": "Press {interact} at the sheet to take the order off your screen, then press {interact} again to put it back.",
		"keys": "{interact}",


		"live": true,
		"cue_note": "The order stays on your screen",
		"cue_note_pinned": "Take the copy down, then put it back up",
	},
	{
		"id": "first_contract",
		"title": "Fill the first order",
		"detail": "The order wants twenty pressed bales on the truck. Press {tech_tree} and buy Alternating Splitter, then Compressor Plans for {cost:compressor}. Press {build_catalog} and build the press on a belt, {price:compressor} to build, with a pole near it. It presses hay into bales, and bales sell for more. Stack what it makes on the truck bed. The truck comes when you make your first bale.",
		"keys": "",
		"board": ["splitter", "compressor"],


		"plead": false,
	},
	{
		"id": "build_scanner",
		"title": "Build a haystack scanner",
		"detail": "That order unlocked Scanner Mk I Plans. Press {tech_tree}, buy them for {cost:scanner_mk1}, then press {build_catalog} and place the scanner on a belt, {price:scanner} to build. It finds the needles in the hay that goes past.",
		"keys": "",
		"board": ["scanner_mk1"],
		"plead": false,
	},


	{
		"id": "wrapped_order",
		"title": "Fill the wrapped order",
		"detail": "The next order on the board wants eighteen wrapped bales. Press {tech_tree} and buy Wrapper Plans for {cost:wrapper}. Press {build_catalog} and build the wrapper on the belt after the press, {price:wrapper} to build. It wraps each bale. Stack the wrapped bales on the truck.",
		"keys": "",
		"board": ["wrapper"],
		"plead": false,
	},
	{
		"id": "build_drone",
		"title": "Build the hay drone",
		"detail": "That order unlocked Hay Drone Plans. You also need Long-Reach Arm Plans. Press {tech_tree} and buy those, then Hay Drone Plans for {cost:drone}. Press {build_catalog} to place the drone, {price:drone} to build. Then press {interact} on its pad and give it a zone and a drop. It digs or collects there and flies it all to the drop. No belts needed.",
		"keys": "",
		"board": ["arm_long", "drone"],
		"plead": false,
	},
	{
		"id": "extend_shed",
		"title": "Extend the shed",
		"detail": "Press {tech_tree}. Buy Extend the Shed. Each level makes the shed bigger.",
		"keys": "",
		"board": ["yard_space"],
		"plead": false,
	},
	{
		"id": "first_needle",
		"title": "Find a needle",


		"keys": "",


		"plead": false,
	},
	{
		"id": "bank_needle",
		"title": "Put a needle in the case",
		"detail": "Carry the needle to the cabinet. Press {interact} to open it. Click the slot that matches your needle.",
		"keys": "{interact}",
	},


	{
		"id": "build_gas_plant",
		"full_only": true,
		"title": "Build a gas plant",
		"detail": "Hay Generators get 1 kJ from each straw. A Gas Plant gets 3 kJ from each straw in an eco brick. Press {tech_tree} and buy Gas Plant Plans for {cost:gas_plant}. Press {build_catalog} and build it for {price:gas_plant}. Lay a water pipe from a borehole pump to its flange.",
		"keys": "",
		"board": ["gas_plant"],
		"plead": false,
	},
	{
		"id": "feed_gas_plant",
		"full_only": true,
		"title": "Feed it bricks",
		"detail": "Run a belt from a pelletizer into the gas plant, or carry bricks to it. It burns eco bricks and nothing else. Put a power pole near it to carry the power.",
		"keys": "",
		"plead": false,
	},
]


static func say(index: int, field: String) -> String:
	return expand(field_of(index, field))


static func field_of(index: int, field: String) -> String:
	var s:= step(index)
	var alt:= str(s.get(field + "_pinned", ""))
	if alt != "" and GameState.contract_pinned:
		return _translate(alt)
	return _translate(str(s.get(field, "")))


static func _translate(text: String) -> String:
	if text == "":
		return ""
	return Cfg.tr(text)


static func expand(text: String) -> String:
	var out:= ""
	var rest:= text
	while true:
		var open:= rest.find("{")
		if open < 0:
			return out + rest
		var close:= rest.find("}", open)
		if close < 0:
			return out + rest
		out += rest.substr(0, open)
		out += _resolve(rest.substr(open + 1, close - open - 1))
		rest = rest.substr(close + 1)
	return out


const PRICES:= {
	"sand_shovel": "PRICE_SAND_SHOVEL",
	"spade": "PRICE_SPADE",
	"bucket": "PRICE_BUCKET",
	"rake": "RAKE_COST",
	"generator": "GENERATOR_COST",
	"gas_plant": "GAS_PLANT_COST",
	"pole": "POLE_COST",
	"compressor": "COMPRESSOR_COST",
	"wrapper": "WRAPPER_COST",
	"drone": "DRONE_COST",
	"cabinet": "CABINET_COST",
	"detector": "PRICE_METAL_DETECTOR",
}


static func is_figure(token: String) -> bool:
	return token.begins_with("cost:") or token.begins_with("price:") or token.begins_with("num:")


static func _resolve(token: String) -> String:
	if not is_figure(token):
		return _named(token)
	var colon:= token.find(":")
	var kind:= token.substr(0, colon)
	var name:= token.substr(colon + 1)
	match kind:
		"cost":
			if not TechTree.has_id(name):
				return "?"
			return _dollars(TechTree.cost_at(name, 0))
		"price":
			match name:
				"arm":
					return _dollars(float(Cfg.ROBOT_ARM_TIERS [0] ["cost"]))
				"scanner":
					return _dollars(float(Cfg.SCANNER_TIERS [0] ["cost"]))
			if not PRICES.has(name):
				return "?"
			var price: Variant = _cfg(PRICES [name])
			return "?" if price == null else _dollars(float(price))
		"num":
			var v: Variant = _cfg(name)
			if v == null:
				return "?"
			if typeof(v) == TYPE_FLOAT and is_equal_approx(float(v), roundf(float(v))):
				return str(int(roundf(float(v))))
			return str(v)
	return "?"


static func _dollars(amount: float) -> String:
	if amount < 1.0:
		return "$%.2f" % amount
	return "$%d" % int(round(amount))


static func _cfg(name: String) -> Variant:
	var consts: Dictionary = Cfg.get_script().get_script_constant_map()
	if consts.has(name):
		return consts [name]
	return Cfg.get(name)


static func _named(token: String) -> String:
	var bar:= token.find("|")
	if bar < 0:
		return InputSetup.hint(token)
	var action:= token.substr(0, bar)
	if token.substr(bar + 1) == "keys":
		for spec: String in InputSetup.specs_of(action):
			if spec.begins_with("key:"):
				return InputSetup.spec_label(spec)
	return InputSetup.hint(action)


const CAP_COL:= "ffdb57"


static func say_rich(index: int, field: String) -> String:
	var text:= field_of(index, field).replace("[", "[lb]")
	var out:= ""
	var rest:= text
	while true:
		var open:= rest.find("{")
		if open < 0:
			return out + rest
		var close:= rest.find("}", open)
		if close < 0:
			return out + rest
		out += rest.substr(0, open)
		var token:= rest.substr(open + 1, close - open - 1)


		if is_figure(token):
			out += _resolve(token)
		else:
			var pic:= _pictured(token)
			out += pic if pic != "" else cap(_named(token))
		rest = rest.substr(close + 1)
	return out


static func _pictured(token: String) -> String:
	if token.contains("|"):
		return ""
	return InputIcons.rich(InputSetup.spec_of(token), 22)


static func cap(key: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [CAP_COL, key]


static func goal_of(id: String) -> float:
	return float(step(index_of(id)).get("goal", 0.0))


static func has_cue(index: int) -> bool:
	return cue_action(index) != "" and bool(step(index).get("cue", true))


static func cue_action(index: int) -> String:
	return _first_action(keys_of(index))


static func keys_of(index: int) -> String:
	var s:= step(index)
	var after:= str(s.get("cue_after", ""))
	if after != "" and Tech.is_unlocked(after):
		return str(s.get("cue_then", ""))
	return str(s.get("keys", ""))


static func cue_repeat(index: int) -> int:
	return int(step(index).get("cue_repeat", CUE_SHOWINGS))


static func board_node(index: int) -> String:
	var s:= step(index)
	var wanted: Array = s.get("board", [])
	if wanted.is_empty() and str(s.get("cue_after", "")) != "":
		wanted = [str(s ["cue_after"])]
	for id: Variant in wanted:
		if TechTree.has_id(str(id)) and Tech.rank_of(str(id)) == 0:
			return str(id)
	return ""


static func cue_alt_action(index: int) -> String:
	return _first_action(str(step(index).get("cue_alt", "")))


static func _first_action(text: String) -> String:
	var open:= text.find("{")
	if open < 0:
		return ""
	var close:= text.find("}", open)
	if close < 0:
		return ""


	return text.substr(open + 1, close - open - 1).split("|") [0]


static func count() -> int:
	return STEPS.size()


const ORDER_BEFORE_IDS:= ["first_hay", "throw_hay", "first_dollar", "open_tech",
	"buy_toy_licence", "find_shop", "buy_toy_shovel", "pick_up_shovel", "scoop",
	"stack_scoop", "tilt_pour", "twenty_dollars", "buy_spade", "drop_tool",
	"bring_to_me", "buy_bucket", "fill_bucket", "pour_bucket", "hundred",
	"open_build", "build_cabinet", "build_belt", "build_distance",
	"belt_feeds_stand", "reverse_belt", "dismantle", "build_rake", "build_power",
	"rake_throw", "upgrade_belt", "build_arm", "buy_detector", "detector_power",
	"pin_contract", "first_contract", "build_scanner", "wrapped_order",
	"build_drone", "extend_shed", "first_needle", "bank_needle"]


static func index_from_save(d: Dictionary) -> int:
	if d.has("mission_id"):
		var id:= String(d ["mission_id"])
		if id == "":
			return count()
		id = str(MOVED.get(id, id))
		var at:= index_of(id)


		return at if at >= 0 else clampi(int(d.get("mission_index", 0)), 0, count())
	var old:= int(d.get("mission_index", 0))
	if old >= ORDER_BEFORE_IDS.size():
		return count()
	var mapped:= index_of(ORDER_BEFORE_IDS [maxi(old, 0)])
	return mapped if mapped >= 0 else clampi(old, 0, count())


const MOVED:= { "hundred": "open_build" }


static func reward_text(index: int) -> String:
	var id:= str(step(index).get("reward", ""))
	if id == "" or not BuildCatalog.has_id(id):
		return ""
	return Cfg.tr("Reward: %s (free)") % BuildCatalog.display_name(id)


static func step(index: int) -> Dictionary:
	if index < 0 or index >= STEPS.size():
		return { }
	var s: Dictionary = STEPS [index]
	var alt: Variant = s.get("simple")
	if alt is Dictionary and Cfg.simple_tools():
		var merged:= s.duplicate()
		merged.merge(alt as Dictionary, true)
		return merged
	return s


static func pleads(index: int) -> bool:
	return bool(step(index).get("plead", true))


static func id_at(index: int) -> String:
	return str(step(index).get("id", ""))


static func index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS [i] ["id"] == id:
			return i
	return -1


static func reached(id: String) -> bool:
	var i:= index_of(id)
	return i < 0 or GameState.mission_index >= i
