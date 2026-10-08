class_name GameTips
extends RefCounted


const TIPS:= [

	"Running and jumping shake hay off a full tool.",
	"Standing still is the fastest way to get your stamina back.",
	"Walk up to a Dump Hatch with a full bucket or barrow. It empties it for you, no button needed.",
	"The pitchfork lifts more hay at once than any other hand tool.",

	"Press {key:build_catalog} to open the build catalog.",
	"Press {key:build_grid} to snap buildings to a grid.",
	"Press {key:build_rotate} to turn a machine before you place it.",
	"Scroll the mouse wheel to place a building further away or closer.",
	"No mouse wheel? Press {keyboard:build_further} and {keyboard:build_closer} to place a building further away or closer.",
	"In the build catalog, right click a building to pin it to your hotbar.",
	"Placing a drone, rake, arm or pelletizer? Hold the right mouse button to see where your other ones already reach.",
	"Hold {key:dismantle} on a building to take it down.",


	"Hold Shift and {key:dismantle} on a Platform to take away just one tile of it.",
	"Placing a belt? Press {key:build_no_snap} to stop it snapping onto other belts and machines.",
	"A belt bends round anything in its way by itself. Press {key:build_rotate} to send it round the other side instead.",
	"Laying a belt that turns a corner? Press {key:build_rotate} to try a different way round.",
	"A Splitter sends hay left, then right, then left. Press {key:interact} at it to adjust it.",
	"Want to clear your whole yard? Press {key:interact} at the CLEARANCE sign above the price board. You get back what you paid.",

	"Look at a power pole to see how much power your yard needs and makes. Every machine on that pole lights up too.",
	"When there is not enough power, every machine on the line slows down together.",
	"Walls block power wires, but hay does not. A Cable Box buries the wire, so nothing can block it.",
	"Press {key:interact} at a machine to turn it off. A machine that is off uses no power.",

	"A bale sells for more than the loose hay inside it.",
	"A wrapper only takes finished bales, not loose hay.",
	"A pulper needs three things at once: hay on the belt, a power wire and a water pipe.",

	"A needle can hide inside a bale or a brick, and it is gone if you sell it. Look at it and hold {key:dismantle} to rip it apart and get the needle out.",
	"The generator burns any needle hidden in its fuel. Scan your hay first.",
	"A scanner finds needles in loose hay, bales and bricks.",
	"The metal detector tells you how close a needle is, never which way. Walk around until the sound is loudest.",
	"When a scanner's beacon lights up, its drawer is full. Go and empty it.",

	"To make your yard bigger, buy {card:yard_space} in the tech tree.",
	"{card:hay_price} in the tech tree makes everything sell for more.",
	"Short on power? {card:generator_output} in the tech tree makes every generator stronger.",
	"{card:belt_speed} makes every belt faster, even the ones you already built.",
	"Out of breath? {card:strong_back} gives you more stamina, and {card:second_wind} brings it back faster.",
	"{card:work_boots} makes you walk and run faster.",
	"{card:overflow_gate} lets a Splitter fill one belt first and only send the extra down the other.",
	"{card:firebox} lets a generator hold more hay, so a short gap in its feed does not slow the yard.",
	"{card:pole_span} and {card:pole_drop} let power poles reach further, so you need fewer of them.",
	"{card:bale_quality} makes every bale you sell worth more.",

	"Press {key:toggle_debug} to see your FPS.",
	"Press {key:toggle_hud} to hide the HUD. Press it again to bring it back.",
	"Press {key:quick_save} to save your game right away.",

	"You can change the language in OPTIONS, on the DISPLAY page. Restart the game to switch.",
	"In OPTIONS, on the GAMEPLAY page, you can raise how many items can lie around the yard. Be careful: more items can lower your FPS.",
	"On the GAMEPLAY page you can also raise how many loads your belts carry. A long line full of bales costs the most FPS.",
	"With the yard cap on, when there are too many items, the ones furthest away from you turn back into hay on the pile.",
	"Floor full of hay? Press PUT LOOSE HAY BACK ON THE PILE on the GAMEPLAY page in OPTIONS. Bales turn back into plain hay.",
	"The graphics quality preset also picks how many items your yard can hold, until you move that slider yourself.",
	"Low FPS? The GRAPHICS page in OPTIONS lists the settings that help the most first.",
	"Every key can be changed in OPTIONS, on the CONTROLS page.",
	"Want a cleaner screen? Hide the tool bar or the button hints on the HUD page in OPTIONS.",
	"The hay left in the top corner can show as an amount or a percent. Pick one on the GAMEPLAY page.",
	"Do not want these tips? Turn them off in OPTIONS, on the GAMEPLAY page.",
]

static var _token: RegEx


static func count() -> int:
	return TIPS.size()


static func say(i: int) -> String:
	return fill(Cfg.tr(str(TIPS [posmod(i, TIPS.size())])))


static func fill(text: String) -> String:
	for m: RegExMatch in _tokens().search_all(text):
		var id:= m.get_string(2)
		var fill:= ""
		match m.get_string(1):
			"key":
				fill = InputSetup.hint(id)
			"keyboard":
				fill = say_keyboard(id)
			_:
				fill = TechTree.display_name(id)
		text = text.replace(m.get_string(), fill)
	return text


static func say_keyboard(action: String) -> String:
	for spec: String in InputSetup.specs_of(action):
		if spec.begins_with("key:"):
			return InputSetup.spec_label(spec)
	return InputSetup.hint(action)


static func ids_in(i: int, kind: String) -> Array [String]:
	var out: Array [String] = []
	for m: RegExMatch in _tokens().search_all(str(TIPS [posmod(i, TIPS.size())])):
		if m.get_string(1) == kind:
			out.append(m.get_string(2))
	return out


static func usable(i: int) -> bool:
	for card in ids_in(i, "card"):
		if Tech.is_maxed(card) or Tech.off_site(card):
			return false
	return true


static func draw(bag: Array [int], rng: RandomNumberGenerator) -> int:
	for pass_i in 2:
		if bag.is_empty():
			for i in TIPS.size():
				bag.append(i)
			for i in range(bag.size() - 1, 0, -1):
				var j:= rng.randi_range(0, i)
				var swap:= bag [i]
				bag [i] = bag [j]
				bag [j] = swap
		while not bag.is_empty():
			var i: int = bag.pop_back()
			if usable(i):
				return i
	return -1


static func _tokens() -> RegEx:
	if _token == null:
		_token = RegEx.create_from_string("\\{(keyboard|key|card):([a-z0-9_]+)\\}")
	return _token
