class_name DevMissionsProbe
extends Node


const TAUGHT:= ["open_tech", "find_shop", "pick_up_shovel", "scoop",
	"throw_hay", "stack_scoop", "tilt_pour", "drop_tool",
	"bring_to_me"]


const EARNED_EARLY:= ["pick_up_shovel"]


const STAND_CLEARANCE:= 1.0


const CUED_LATE:= ["open_build", "build_cabinet", "reverse_belt", "dismantle",
	"build_rake", "rake_throw", "bank_needle"]

var world: Node3D
var player: Player

var _fails:= 0


var _tip_phase:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true


	Cfg.set_no_hud(false)


	var kept_missions:= Cfg.show_missions
	Cfg.set_show_missions(true)
	var missions: MissionDirector = world.missions
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	for i in 40:
		await get_tree().process_frame

	print("\n=== the book is well formed ===")
	_ok(MissionBook.count() >= 20,
		"the chain is %d steps long" % MissionBook.count())
	var ids:= { }
	var bad:= 0
	for i in MissionBook.count():
		var s:= MissionBook.step(i)
		var id:= str(s.get("id", ""))
		if id == "" or ids.has(id):
			bad += 1
		ids [id] = true
		if str(s.get("title", "")) == "":
			bad += 1
	_ok(bad == 0, "every step has a unique id and a title")


	var unresolved:= PackedStringArray()
	var typed:= PackedStringArray()
	for i in MissionBook.count():


		var earning: bool = str(MissionBook.step(i).get("goal_kind", "")) == "money"
		for field: String in ["detail", "detail_pinned", "title"]:
			var raw:= str(MissionBook.step(i).get(field, ""))
			if raw == "":
				continue
			var said:= MissionBook.expand(raw)
			if "?" in said:
				unresolved.append("%s.%s" % [MissionBook.id_at(i), field])
			if "dollar" in said.to_lower() and not earning:
				typed.append("%s.%s" % [MissionBook.id_at(i), field])
	_ok(unresolved.is_empty(), "every price token names a real card or constant%s"
		% ("" if unresolved.is_empty() else ": " + ", ".join(unresolved)))
	_ok(typed.is_empty(), "no card carries a price typed in words%s"
		% ("" if typed.is_empty() else ": " + ", ".join(typed)))


	var power_i:= MissionBook.index_of("power_up")
	var promise:= MissionBook.reward_text(power_i) if power_i >= 0 else ""
	_ok(promise != "" and BuildCatalog.display_name("rake") in promise,
		"the power card promises the rake: %s" % promise)


	var cab_i:= MissionBook.index_of("bring_to_me")
	_ok(cab_i >= 0 and BuildCatalog.display_name("cabinet") in MissionBook.reward_text(cab_i),
		"the fetch card promises the cabinet: %s" % MissionBook.reward_text(cab_i))
	_ok(cab_i + 1 == MissionBook.index_of("open_build"),
		"and the catalogue card comes straight after it")
	var rake_i:= MissionBook.index_of("build_rake")
	_ok(rake_i > power_i and MissionBook.index_of("build_power") > rake_i,
		"power, then the gift placed, then the pole")


	var stale:= PackedStringArray()
	for i in MissionBook.count():
		var after:= str(MissionBook.step(i).get("cue_after", ""))
		if after == "":
			continue
		if not TechTree.has_id(after):
			stale.append("%s -> %s" % [MissionBook.id_at(i), after])
		elif str(MissionBook.step(i).get("cue_then", "")) == "":
			stale.append("%s has no second key" % MissionBook.id_at(i))
	_ok(stale.is_empty(), "every two part step names a node that exists%s"
		% ("" if stale.is_empty() else ": " + ", ".join(stale)))

	print("\n=== every step can be finished ===")

	GameState.reset(1234, 1000000.0)
	GameState.mission_index = 0
	player.global_position = Vector3(13.0, 0.4, 2.0)
	for i in 5:
		await get_tree().physics_frame

	var reached:= 0
	for i in MissionBook.count():
		var id:= MissionBook.id_at(i)


		var premature: bool = missions.is_done(id)
		await _satisfy(id, builds, props)
		for f in 3:
			await get_tree().physics_frame
		var now: bool = missions.is_done(id)


		if premature and Cfg.DEMO and bool(MissionBook.step(i).get("full_only", false)):
			reached += 1
			print("  ok   %-18s is a full game step, done on arrival in the demo" % id)
			continue
		if premature:
			_fails += 1
			print("  FAIL %-18s was already true before anything was done" % id)
		elif not now:
			_fails += 1
			print("  FAIL %-18s cannot be finished (nothing satisfies it)" % id)
			if id == "tilt_pour":
				print("    tilts=%d of %d  held=%s  pour_intent=%s"
					% [missions._tilt_count(), int(MissionBook.goal_of(id)),
						str(player.carry.held()), player.pour_intent()])
				print("    live=%d run=%d  index=%d step=%d  live_lesson=%s"
					% [missions._tilts_live, missions._tilts,
						GameState.mission_index, MissionBook.index_of("tilt_pour"),
						MissionDirector.is_live_lesson("tilt_pour")])
			if id == "drop_tool":
				print("    latches: dropped=%s | tools owned now=%d"
					% [missions._live.has("dropped_tool"), missions._last_owned])
			if id == "pin_contract":
				print("    pinned=%s live=%s stale=%s  index=%d step=%d"
					% [GameState.contract_pinned, missions._live.has("pin"),
						missions._stale.has("pin"), GameState.mission_index,
						MissionBook.index_of(id)])
		else:
			reached += 1
	print("  %d of %d steps reachable" % [reached, MissionBook.count()])

	print("\n=== the opening steps refuse to be skipped ===")


	missions._seen.clear()
	missions._tilts = 0

	missions._open_step()
	missions._watch()
	for id: String in TAUGHT:
		_ok(MissionDirector.is_live_lesson(id),
			"'%s' is inside the window" % id)
		_ok(not missions.is_done(id),
			"...and a finished yard does not finish it")

	print("\n=== nor tick before their card has been read ===")


	var driver:= missions.player
	missions.player = null


	world.quests._hold = 0.0
	world.quests._shown = -1
	world.quests.show_step(0)
	_ok(not missions._has_been_read(0),
		"a card that has just gone up cannot tick yet")
	var wait:= MissionDirector.READ_TIME + 0.2
	while wait > 0.0:
		wait -= get_process_delta_time()
		await get_tree().process_frame
	_ok(missions._has_been_read(0), "and can once it has been up long enough")
	_ok(missions._has_been_read(MissionBook.count() - 1),
		"a step past the window never waits at all")
	missions.player = driver

	print("\n=== and past them the chain walks itself forward ===")


	GameState.mission_index = MissionBook.LIVE_COUNT


	var parked: Array [String] = []
	for pass_i in 8:
		for i in 40:
			await get_tree().process_frame
		if GameState.mission_index >= MissionBook.count():
			break
		var here:= MissionBook.id_at(GameState.mission_index)
		if not MissionDirector.is_live_lesson(here):
			break
		parked.append(here)
		await _satisfy(here, builds, props)
	if not parked.is_empty():
		print("    live steps that held the walk: %s" % ", ".join(parked))
	_ok(parked.has("pin_contract"),
		"the pin step stops a finished yard until the docket is actually pinned")
	if GameState.mission_index < MissionBook.count():
		var stuck:= MissionBook.id_at(GameState.mission_index)
		print("    stuck on '%s'" % stuck)
		print("    owns spade=%s toy=%s | earned=$%.2f dug=%.0f | loose tools=%d"
			% [GameState.has_tool("spade"), GameState.has_tool("sand_shovel"),
				GameState.money_earned, GameState.hay_dug,
				props.count_of("spade") + props.count_of("broom")
					+ props.count_of("pitchfork") + props.count_of("sand_shovel")])
	_ok(GameState.mission_index == MissionBook.count(),
		"a finished yard lands on step %d of %d, not step %d"
			% [GameState.mission_index, MissionBook.count(),
				MissionBook.LIVE_COUNT + 1])


	var hold:= QuestPanel.TICK_HOLD + 0.6
	while hold > 0.0:
		hold -= get_process_delta_time()
		await get_tree().process_frame
	_ok(not world.quests.visible,
		"and the card takes itself off the screen once the chain is done")

	print("\n=== the drill has to actually be done ===")


	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("tilt_pour")
	missions._open_step()
	player._set_tool(Player.Tool.HAND)
	if player.carry.is_carrying():
		player.carry.drop()
	var toy:= props.spawn("sand_shovel",
		Transform3D(Basis(), player.global_position + Vector3(0, 0.5, 0)))
	if toy != null:
		player.carry.take(toy)
	var tilt_goal:= int(MissionBook.goal_of("tilt_pour"))
	await _tip_it(tilt_goal - 1)
	_ok(not missions.is_done("tilt_pour"),
		"%d tips of the blade is not the tipping drill" % (tilt_goal - 1))
	await _tip_it(1)
	_ok(missions.is_done("tilt_pour"), "...and %d is" % tilt_goal)


	missions._open_step()
	await _tip_it(1)
	var settled:= missions._tilt_count()
	_wobble_in_place(12)
	_ok(missions._tilt_count() == settled,
		"wobbling where the blade already is adds nothing (%d, still)" % settled)

	print("\r\n=== a blade takes more than one bite ===")


	GameState.mission_index = MissionBook.index_of("stack_scoop")
	missions._open_step()


	missions._clock = 999.0
	var toy_again:= player.carry.held() as SandShovel
	var stack_goal:= int(MissionBook.goal_of("stack_scoop"))
	if toy_again == null:
		_ok(false, "the toy shovel is still in hand for the stacking drill")
	else:


		missions._watch()
		for i in stack_goal - 1:
			toy_again.stacked_scoops += 1
			missions._watch()
		_ok(not missions.is_done("stack_scoop"),
			"%d more dig is not the stacking drill" % (stack_goal - 1))
		toy_again.stacked_scoops += 1
		missions._watch()
		_ok(missions.is_done("stack_scoop"), "...and %d is" % stack_goal)

	print("\r\n=== and a straw is thrown rather than carried ===")


	GameState.mission_index = MissionBook.index_of("throw_hay")
	missions._open_step()
	missions._clock = 999.0
	missions._watch()
	_ok(not missions.is_done("throw_hay"),
		"a hand that has thrown nothing does not finish the step")
	player.hand.throws += 1
	missions._watch()
	_ok(missions.is_done("throw_hay"), "...and one throw does")

	if player.carry.is_carrying():
		player.carry.drop()

	print("\n=== the docket has to be pinned with the card up ===")


	GameState.mission_index = MissionBook.index_of("pin_contract")
	GameState.contract_pinned = false
	missions._open_step()


	missions._clock = 999.0


	for i in 3:
		await get_tree().process_frame
	_ok(not missions.is_done("pin_contract"),
		"an unpinned board does not tick the step on its own")
	_press_board_contract()
	for i in 3:
		await get_tree().process_frame
	_ok(GameState.contract_pinned, "E on the sheet pins it")
	_ok(missions.is_done("pin_contract"), "...and that finishes the step")


	missions._open_step()
	for i in 3:
		await get_tree().process_frame
	_ok(not missions.is_done("pin_contract"),
		"a save that arrives already pinned does not tick it off unread")
	_press_board_contract()
	for i in 3:
		await get_tree().process_frame
	_ok(not GameState.contract_pinned and not missions.is_done("pin_contract"),
		"taking it down is half the drill and does not finish it")
	_press_board_contract()
	for i in 3:
		await get_tree().process_frame
	_ok(GameState.contract_pinned and missions.is_done("pin_contract"),
		"...putting it back does")


	var pin_i:= MissionBook.index_of("pin_contract")
	var pinned_say:= MissionBook.say(pin_i, "detail")
	var pinned_note:= MissionBook.say(pin_i, "cue_note")
	GameState.contract_pinned = false
	var fresh_say:= MissionBook.say(pin_i, "detail")
	_ok(pinned_say != fresh_say,
		"an already pinned board is asked for the drill in its own words")
	_ok(pinned_note != MissionBook.say(pin_i, "cue_note"),
		"...and the picture under the title says it too")
	_ok(not fresh_say.is_empty() and not pinned_say.is_empty(),
		"neither wording came back empty")

	GameState.contract_pinned = true

	print("\n=== a lesson done once already can still be earned ===")


	GameState.grant_tool("sand_shovel")
	player.select_hotbar_slot(4)
	for f in 3:
		await get_tree().physics_frame

	for id: String in TAUGHT:


		GameState.mission_index = 0
		missions._open_step()
		missions._watch()
		await _satisfy(id, builds, props)

		GameState.mission_index = MissionBook.index_of(id)
		missions._open_step()
		missions._watch()
		var early: bool = missions.is_done(id)
		await _satisfy(id, builds, props)
		var earned: bool = missions.is_done(id)
		if early and not (id in EARNED_EARLY):
			_fails += 1
			print("  FAIL %-14s arrived finished after one early try" % id)
		elif not earned:
			_fails += 1
			print("  FAIL %-14s cannot be earned a second time" % id)
		else:
			print("  ok   %-14s survives having been done once already%s"
				% [id, "  (and legitimately arrives done)" if early else ""])

	print("\n=== the picture and the card agree about the gesture ===")


	var mismatched:= PackedStringArray()
	for i in MissionBook.count():
		if not MissionBook.has_cue(i):
			continue
		var control:= MissionBook.cue_action(i)
		var line:= str(MissionBook.step(i).get("detail", "")).to_lower()
		var says_hold: bool = ("hold {%s}" % control) in line
		var drawn_hold: bool = bool(MissionBook.step(i).get("cue_hold", false))
		if says_hold != drawn_hold:
			mismatched.append("%s (card says %s, picture says %s)"
				% [MissionBook.id_at(i), "hold" if says_hold else "press",
					"HOLD" if drawn_hold else "PRESS"])
	_ok(mismatched.is_empty(), "every cued step words it the same way twice%s"
		% ("" if mismatched.is_empty() else ": " + ", ".join(mismatched)))

	print("\n=== a prompt that is waiting on money gives up ===")


	var cue_gives_up: MissionCue = world.mission_cue
	var rationed:= MissionBook.index_of("upgrade_belt")
	_ok(MissionBook.cue_repeat(rationed) > 0,
		"the belt upgrade card is rationed (%d showings)"
			% MissionBook.cue_repeat(rationed))
	cue_gives_up.show_step(-1)
	cue_gives_up.show_step(rationed)
	_ok(cue_gives_up.visible, "...it goes up to begin with")
	var span:= MissionCue.HOLD + MissionCue.GAP
	for i in MissionBook.cue_repeat(rationed) - 1:
		cue_gives_up._process(span)
	_ok(cue_gives_up.visible, "...is still there one showing short of the limit")
	cue_gives_up._process(span)
	_ok(not cue_gives_up.visible, "...and takes itself off after the last one")


	cue_gives_up.visible = true
	cue_gives_up._process(0.016)
	_ok(not cue_gives_up.visible, "...and will not be talked back onto the screen")


	cue_gives_up.show_step(-1)
	var tilt:= MissionBook.index_of("tilt_pour")
	cue_gives_up.show_step(tilt)
	for i in MissionBook.CUE_SHOWINGS - 1:
		cue_gives_up._process(span)
	_ok(cue_gives_up.visible, "a lesson about a new control is still up at two")
	cue_gives_up._process(span)
	_ok(not cue_gives_up.visible, "...and gives up after three like everything else")
	cue_gives_up.show_step(-1)

	var unrationed: PackedStringArray = PackedStringArray()
	for i in MissionBook.STEPS.size():
		if MissionBook.has_cue(i) and MissionBook.cue_repeat(i) <= 0:
			unrationed.append(MissionBook.id_at(i))
	_ok(unrationed.is_empty(), "no cued step pulses forever%s"
		% ("" if unrationed.is_empty() else ": " + ", ".join(unrationed)))

	print("\n=== a two part step moves its prompt to the second half ===")


	var two_part:= MissionBook.index_of("buy_spade")
	Tech.reset()
	cue_gives_up.show_step(-1)
	cue_gives_up.show_step(two_part)
	_ok(MissionBook.cue_action(two_part) == "tech_tree",
		"before the card is bought it asks for the research board (%s)"
			% MissionBook.cue_action(two_part))
	_ok(cue_gives_up.visible and cue_gives_up._keys == "{tech_tree}",
		"...and the picture is drawing that key")


	Tech.grant("spade", 1)
	cue_gives_up.show_step(two_part)
	_ok(MissionBook.cue_action(two_part) == "interact",
		"buying the card moves the prompt to the shop (%s)"
			% MissionBook.cue_action(two_part))
	_ok(cue_gives_up.visible and cue_gives_up._keys == "{interact}",
		"...and the picture followed it without the step moving")


	var card_keys:= MissionBook.keys_of(two_part)
	_ok(card_keys == "{interact}",
		"the cap on the quest card says the same thing (%s)" % card_keys)
	_ok(MissionBook.cue_action(MissionBook.index_of("build_cabinet")) == "build_catalog",
		"the cabinet, a gift now, asks for the catalogue from the start")


	Tech.reset()
	cue_gives_up.show_step(-1)
	var spade_step:= MissionBook.index_of("buy_spade")
	cue_gives_up.show_step(spade_step)
	for i in MissionBook.cue_repeat(spade_step):
		cue_gives_up._process(span)
	_ok(not cue_gives_up.visible, "the spade prompt has said its piece")
	Tech.grant("spade", 1)
	cue_gives_up.show_step(spade_step)
	_ok(MissionBook.cue_action(spade_step) == "interact",
		"buying the card points it at the shop instead (%s)"
			% MissionBook.cue_action(spade_step))
	_ok(cue_gives_up.visible and cue_gives_up._keys == "{interact}",
		"...and that gets a showing of its own rather than the board's leftovers")
	Tech.reset()
	cue_gives_up.show_step(-1)

	print("\n=== the ghost slides both ways or not at all ===")


	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("build_distance")


	for arm in builds.robotic_arms.duplicate():
		builds.demolish(arm)
	missions._open_step()
	missions._watch()
	_roll_the_wheel("build_further", 12)
	_ok(not missions.is_done("build_distance"),
		"rolling it out and never back is not the lesson (out %.1f m, in %.1f m)"
			% [missions._rolled_out, missions._rolled_in])
	_roll_the_wheel("build_closer", 12)
	_ok(missions.is_done("build_distance"),
		"...and bringing it back finishes it (out %.1f m, in %.1f m)"
			% [missions._rolled_out, missions._rolled_in])


	GameState.mission_index = MissionBook.index_of("build_distance")
	_roll_the_wheel("build_further", 60)
	missions._open_step()
	missions._watch()
	_ok(not missions.is_done("build_distance"),
		"parked at the far end, the drill starts from nothing")
	_roll_the_wheel("build_closer", 5)
	_roll_the_wheel("build_further", 5)
	_ok(missions.is_done("build_distance"),
		"...and can still be finished from there (out %.1f m, in %.1f m)"
			% [missions._rolled_out, missions._rolled_in])

	print("\n=== the awkward corners ===")


	GameState.mission_index = MissionBook.index_of("drop_tool")
	for item in props.items.duplicate():
		if item.item_id in GameState.TOOL_IDS:
			props.remove(item)
	GameState.grant_tool("broom")
	missions._open_step()
	missions._watch()
	props.spawn_at_feet("broom", player)
	missions._watch()
	_ok(not missions.is_done("drop_tool"),
		"a purchase landing at your feet is not putting a tool down")


	var drop_was:= InputSetup.binding("drop_tool")
	InputSetup.bind("drop_tool", "")
	_ok(InputSetup.hint("drop_tool") == InputSetup.UNBOUND,
		"a control can be left unbound")
	var cue_now: MissionCue = world.mission_cue
	cue_now.show_step(MissionBook.index_of("drop_tool"))
	_ok(not cue_now.visible,
		"and the prompt does not then ask for a key that is not there")
	InputSetup.bind("drop_tool", drop_was)
	cue_now.show_step(-1)
	cue_now.show_step(MissionBook.index_of("drop_tool"))
	_ok(cue_now.visible, "...but comes straight back when it is bound again")

	print("\n=== the two new build lessons ===")


	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("dismantle")


	for arm in builds.robotic_arms.duplicate():
		builds.demolish(arm)
	missions._open_step()
	missions._watch()
	_ok(not missions.is_done("dismantle"),
		"a yard full of buildings does not count as having taken one down")
	var standing:= builds.cabinets.size()
	_pull_something_down(builds)
	_ok(missions.is_done("dismantle"), "...and knocking one down does")
	_ok(builds.cabinets.size() == standing,
		"and the yard is left as it was found (%d cabinets)" % builds.cabinets.size())

	print("\n=== turning a belt round ===")


	GameState.mission_index = MissionBook.index_of("reverse_belt")
	for arm2 in builds.robotic_arms.duplicate():
		builds.demolish(arm2)
	missions._open_step()
	missions._watch()
	_ok(not missions.is_done("reverse_belt"),
		"a yard full of belts does not count as having turned one")
	var run:= builds.add_conveyor(Vector3(16.0, 0.75, -4.0), Vector3(16.0, 0.75, 4.0))
	var belts:= builds.conveyors.size()
	var was_a:= run.a if run != null else Vector3.ZERO
	_turn_a_belt_round(run)
	_ok(missions.is_done("reverse_belt"), "...and turning one does")
	_ok(builds.conveyors.size() == belts and run != null and run.b == was_a,
		"and the belt is still standing, pointed the other way")

	print("\n=== a belt reaches the stand from whichever side it comes ===")


	GameState.mission_index = MissionBook.index_of("belt_feeds_stand")
	for belt in builds.conveyors.duplicate():
		builds.demolish(belt)
	missions._open_step()
	missions._watch()
	_ok(not missions.is_done("belt_feeds_stand"),
		"an empty yard is not a belt at the stand")
	var stand: HaySellingStand = world.stand


	var plan:= stand.footprint()
	var mid:= plan.get_center()
	var sides:= {
		"the intake bay": stand.belt_entry_point(),
		"the counter": stand.delivery_point(),
		"the near wall": stand.to_global(
			Vector3(mid.x, 0.75, plan.position.y - STAND_CLEARANCE)),
		"the far wall": stand.to_global(
			Vector3(mid.x, 0.75, plan.end.y + STAND_CLEARANCE)),
		"the west end": stand.to_global(
			Vector3(plan.position.x - STAND_CLEARANCE, 0.75, mid.y)),
		"the east end": stand.to_global(
			Vector3(plan.end.x + STAND_CLEARANCE, 0.75, mid.y)),
	}
	for where: String in sides:
		for old in builds.conveyors.duplicate():
			builds.demolish(old)
		missions._open_step()
		var at: Vector3 = sides [where]


		var from:= at + stand.global_transform.basis.x * -6.0
		builds.add_conveyor(Vector3(from.x, 0.75, from.z), Vector3(at.x, 0.75, at.z))
		builds.rebuild_junctions()
		missions._watch()
		_ok(missions.is_done("belt_feeds_stand"),
			"a belt ending at %s counts (%.2f m off the building)"
				% [where, stand.floor_distance(at)])


	for old2 in builds.conveyors.duplicate():
		builds.demolish(old2)
	missions._open_step()
	var bay:= stand.belt_entry_point()
	var away:= bay + stand.global_transform.basis.x * -6.0
	builds.add_conveyor(Vector3(bay.x, 0.75, bay.z), Vector3(away.x, 0.75, away.z))
	builds.rebuild_junctions()
	missions._watch()
	_ok(missions.is_done("belt_feeds_stand"),
		"and so does one laid stand-first, pointing away")

	for old3 in builds.conveyors.duplicate():
		builds.demolish(old3)
	missions._open_step()
	builds.add_conveyor(Vector3(0.0, 0.75, 0.0), Vector3(0.0, 0.75, 6.0))
	builds.rebuild_junctions()
	missions._watch()
	_ok(not missions.is_done("belt_feeds_stand"),
		"a belt out in the middle of the yard does not")
	for old4 in builds.conveyors.duplicate():
		builds.demolish(old4)

	print("\n=== a yard with tools already lying in it ===")


	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("drop_tool")
	for item in props.items.duplicate():
		if item.item_id in GameState.TOOL_IDS:
			props.remove(item)
	props.spawn("sand_shovel", Transform3D(Basis(), Vector3(12.0, 0.4, 5.0)))
	props.spawn("spade", Transform3D(Basis(), Vector3(12.0, 0.4, 6.0)))


	missions._open_step()
	missions._watch()
	_ok(not missions.is_done("drop_tool"),
		"two tools already down does not finish the step by itself")
	_put_a_tool_down(props)
	_ok(missions.is_done("drop_tool"),
		"...and putting one more down finishes it, cluttered yard and all")
	for item in props.items.duplicate():
		if item.item_id in GameState.TOOL_IDS:
			props.remove(item)

	print("\n=== the button being asked for is drawn ===")
	_ok(MissionBook.has_cue(MissionBook.index_of("tilt_pour")),
		"the drill gets a cue")
	_ok(not MissionBook.has_cue(MissionBook.index_of("buy_bucket")),
		"a step about a purchase does not")
	for id: String in CUED_LATE:
		_ok(MissionBook.has_cue(MissionBook.index_of(id)),
			"'%s' is past the window and still gets one" % id)
	_ok(not MissionBook.has_cue(MissionBook.index_of("build_belt")),
		"and a step whose key the one before it just taught opts out")


	var artless:= PackedStringArray()
	for i in MissionBook.count():
		var control:= MissionBook.cue_action(i)
		if MissionBook.has_cue(i) and InputIcons.of_action(control) == null:
			artless.append(control)
	_ok(artless.is_empty(), "every cued control has art on the sheet%s"
		% ("" if artless.is_empty() else " (missing %s)" % ", ".join(artless)))
	var cue: MissionCue = world.mission_cue
	cue.show_step(MissionBook.index_of("tilt_pour"))
	_ok(cue.visible, "the cue goes up for a step that has one")
	cue.show_step(MissionBook.index_of("buy_bucket"))
	_ok(not cue.visible, "and comes off for a step that does not")

	print("\n=== a step with a number draws its progress ===")
	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("twenty_dollars")


	missions._open_index = -1

	for f in 2:
		await get_tree().process_frame
	GameState.sell_hay(250.0)
	var p:= missions.progress_of("twenty_dollars")
	var need:= MissionBook.goal_of("twenty_dollars")
	_ok(not p.is_empty(), "the cash step reports progress")
	if not p.is_empty():
		print("    reads: %s" % p ["text"])
		_ok(is_equal_approx(float(p ["need"]), need),
			"counting toward the goal ($%.0f)" % need)
		_ok(float(p ["have"]) > 0.0 and float(p ["have"]) < need,
			"and part way there ($%.2f)" % p ["have"])
		world.quests.show_step(GameState.mission_index)
		world.quests.show_progress(p)
		for f in 3:
			await get_tree().process_frame
		var fill: ColorRect = world.quests._bar_fill
		var track: ColorRect = world.quests._bar_back
		var ratio:= fill.size.x / maxf(track.size.x, 1.0)
		_ok(track.visible and fill.size.x > 0.0 and ratio <= 1.0,
			"the bar is drawn and fits its track (%.0f%% of %.0f px)"
				% [ratio * 100.0, track.size.x])
	_ok(missions.progress_of("first_hay").is_empty(),
		"a step with no number reports none")


	var run_need:= MissionBook.goal_of("run")
	missions._sprint_time = run_need * 0.5
	var run_bar:= missions.progress_of("run")
	_ok(not run_bar.is_empty() and is_equal_approx(float(run_bar ["have"]), run_need * 0.5)
		and is_equal_approx(float(run_bar ["need"]), run_need) and str(run_bar ["text"]) == "",
		"the run card fills a bare bar with running time (%s)" % run_bar)
	missions._sprint_time = 0.0

	print("\n=== a cash card reads the bank, not lifetime takings ===")


	for cash_id: String in ["first_dollar"]:
		GameState.reset(1234, 1000000.0)
		var goal:= MissionBook.goal_of(cash_id)
		GameState.sell_hay(goal * 1.5 / Tech.hay_price())
		GameState.spend_money(goal)
		_ok(GameState.money_earned >= goal and GameState.money < goal,
			"%s: earned $%.2f, spent down to $%.2f" % [cash_id, GameState.money_earned, GameState.money])
		_ok(not missions.is_done(cash_id), "%s stays open over a short bank" % cash_id)
		var bank:= missions.progress_of(cash_id)
		_ok(not bank.is_empty() and is_equal_approx(float(bank ["have"]), GameState.money),
			"%s's bar shows the bank" % cash_id)
		GameState.add_money(goal)
		_ok(missions.is_done(cash_id), "%s ticks once the bank holds the goal" % cash_id)

	print("\n=== the spade's card counts takings, so buying never sets it back ===")


	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("twenty_dollars")
	missions._open_index = -1

	for f in 2:
		await get_tree().process_frame
	var spade_goal:= MissionBook.goal_of("twenty_dollars")
	GameState.sell_hay(spade_goal * 0.5 / Tech.hay_price())
	var half:= float(missions.progress_of("twenty_dollars").get("have", 0.0))
	GameState.spend_money(GameState.money * 0.8)
	var after_buy:= float(missions.progress_of("twenty_dollars").get("have", 0.0))
	_ok(half > spade_goal * 0.4 and is_equal_approx(half, after_buy),
		"a purchase leaves the bar where it was ($%.2f before, $%.2f after)" % [half, after_buy])
	GameState.sell_hay(spade_goal * 0.6 / Tech.hay_price())
	_ok(missions.is_done("twenty_dollars") and GameState.money < spade_goal,
		"and the step ticks on takings with a short bank ($%.2f in hand)" % GameState.money)

	print("\n=== the first sale asks for exactly one Bigger Handful ===")


	var sell_goal:= MissionBook.goal_of("first_dollar")
	var handful_cost:= TechTree.cost_at("hand_carry", 0)
	_ok(is_equal_approx(sell_goal, handful_cost),
		"the first sale is the price of Bigger Handful ($%.2f, prices say $%.2f)" % [sell_goal, handful_cost])

	print("\n=== the Toy Shovel card counts the bank toward card and shovel ===")


	var toy_goal:= MissionBook.goal_of("buy_toy_licence")
	var toy_cost:= TechTree.cost_at("sand_shovel", 0) + Cfg.PRICE_SAND_SHOVEL
	_ok(is_equal_approx(toy_goal, toy_cost),
		"the goal is the card plus the shovel ($%.2f, prices say $%.2f)" % [toy_goal, toy_cost])
	GameState.reset(1234, 1000000.0)
	Tech.reset()
	GameState.add_money(0.15)
	var toy_bar:= missions.progress_of("buy_toy_licence")
	_ok(not toy_bar.is_empty() and is_equal_approx(float(toy_bar ["have"]), GameState.money),
		"its bar shows the bank: %s" % toy_bar.get("text", "none"))


	var toy_index:= MissionBook.index_of("buy_toy_licence")
	_ok(not missions._cue_due(toy_index), "short of the goal the key is not pictured")
	GameState.add_money(toy_goal)
	_ok(missions._cue_due(toy_index), "...and a full bar pictures it")
	_ok(missions._cue_due(MissionBook.index_of("open_tech")),
		"a step without the flag is pictured whatever the bank says")
	_ok(not missions.is_done("buy_toy_licence"), "a full bar does not buy the card")
	_ok(Tech.buy("sand_shovel"), "the card can be bought off a full bar")
	_ok(missions.is_done("buy_toy_licence"), "and buying it ticks the step")
	_ok(GameState.money >= Cfg.PRICE_SAND_SHOVEL, "with the shovel's price left over ($%.2f)" % GameState.money)
	Tech.reset()

	print("\n=== and 'Fill the bucket' waits for a full one ===")


	GameState.reset(1234, 1000000.0)
	GameState.mission_index = MissionBook.index_of("fill_bucket")
	missions._seen.erase("filled_bucket")
	missions._live.erase("filled_bucket")
	for item in props.items.duplicate():
		props.remove(item)
	var pail:= props.spawn("bucket",
		Transform3D(Basis(), Vector3(13.0, 0.4, 7.0))) as HayContainer
	if pail == null:
		_ok(false, "a bucket to fill")
	else:
		pail.stored = int(round(float(pail.capacity()) * 0.6))
		missions._watch()
		print("    reads: %s" % missions.progress_of("fill_bucket").get("text", ""))
		_ok(not missions.is_done("fill_bucket"),
			"%d of %d strands is not a filled bucket" % [pail.stored, pail.capacity()])
		pail.stored = pail.capacity()
		missions._watch()
		_ok(missions.is_done("fill_bucket"), "and to the brim is")
		props.remove(pail)

	print("\n=== the pin step survives a filled delivery book ===")


	GameState.reset(1234, 1000000.0)
	for i in DeliveryBook.count():
		GameState.sign_contract(DeliveryBook.id_at(i))
	GameState.contract_index = DeliveryBook.count()
	GameState.contract_pinned = false
	GameState.contract_pin_changed.emit(false)


	await get_tree().create_timer(DeliveryDirector.POLL * 2.0).timeout
	var cork: DeliveryBoard = world.delivery_board
	_ok(cork != null and cork.docket_visible(),
		"the docket stays on the cork with every order signed")
	GameState.mission_index = MissionBook.index_of("pin_contract")
	missions._open_step()


	missions._clock = 999.0


	for _i in 3:
		await get_tree().process_frame
	_press_board_contract()
	for _i in 3:
		await get_tree().process_frame
	_ok(GameState.contract_pinned, "E on it still pins the order")
	_ok(missions.is_done("pin_contract"),
		"so the step can be finished with nothing left to deliver")

	print("\n=== the save remembers where you were ===")
	GameState.mission_index = 7
	var d:= GameState.to_dict()
	GameState.mission_index = 0
	GameState.from_dict(d)
	_ok(GameState.mission_index == 7, "the step survives a save and load")


	print("\n=== missions can be put away without being skipped ===")
	GameState.reset(1234, 1000000.0)


	GameState.mission_index = MissionBook.index_of("open_build")
	world.quests.show_step(GameState.mission_index)
	cue.show_step(GameState.mission_index)
	await get_tree().process_frame
	Cfg.set_show_missions(false)
	_ok(not world.quests._panel.visible, "off takes the card off the screen")
	_ok(not cue._root.visible, "and the key cue with it")
	_ok(world.quests.visible,
		"but the node stays live, so the director can still read it back")
	var was_at:= GameState.mission_index


	missions._saw("build_menu", true)


	missions._clock = MissionDirector.POLL


	await get_tree().create_timer(MissionDirector.POLL * 3.0).timeout
	_ok(GameState.mission_index > was_at,
		"the chain moves on behind a hidden card (step %d)"
			% (GameState.mission_index + 1))
	Cfg.set_show_missions(true)
	_ok(world.quests._panel.visible and cue._root.visible,
		"and on brings both back")


	Cfg.set_no_hud(true)
	_ok(not world.quests._panel.visible,
		"camera mode still hides it with missions left on")
	Cfg.set_no_hud(false)
	Cfg.set_show_missions(kept_missions)

	print("\n[missions] %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit()


func _satisfy(id: String, builds: BuildManager, props: PropManager) -> void:
	var missions: MissionDirector = world.missions
	match id:
		"first_hay":
			GameState.remove_hay(5.0)
		"first_dollar":
			GameState.sell_hay(120.0)
		"find_shop":


			missions._saw("shop", true)
		"buy_toy_licence":
			Tech.grant("sand_shovel", 1)
		"buy_handful":
			Tech.grant("hand_carry", 1)
		"buy_toy_shovel":


			GameState.grant_tool("sand_shovel")
		"pick_up_shovel":
			player.select_hotbar_slot(4)
		"scoop":
			missions._saw("scoop", true)
		"throw_hay":
			missions._saw("threw_hay", true)
		"run":


			missions._sprint_time = MissionBook.goal_of("run") + 0.1
		"grid_place":


			player.build.grids += 1
		"turn_build":
			player.build.turns += 1
		"copy_build":
			player.build.copied += 1
		"stack_scoop":


			missions._stacks_live = int(MissionBook.goal_of(id))
			missions._stacks = missions._stacks_live
		"tilt_pour":


			await _tip_it(int(MissionBook.goal_of(id)))
		"twenty_dollars":
			GameState.sell_hay(2000.0)
		"open_tech":
			missions._saw("tech", true)
		"open_build":
			missions._saw("build_menu", true)
		"dismantle":


			_pull_something_down(builds)
		"buy_spade":


			Tech.grant("spade", 1)
			GameState.grant_tool("spade")
		"drop_tool":


			_put_a_tool_down(props)
		"buy_bucket":
			props.spawn("bucket", Transform3D(Basis(), Vector3(13.0, 0.4, 7.0)))
		"fill_bucket":
			for item in props.items:
				var box:= item as HayContainer
				if box != null:
					box.stored = box.capacity()
		"bring_to_me":


			_fetch_a_tool(props)
		"pour_bucket":


			_pour_a_bucket_at_the_stand(props)
		"power_up":


			var gen: HayGenerator = builds.add_generator(Vector3(3.0, 0.0, 14.0), 0.0)
			gen.fuel = 10.0
		"build_distance":
			_roll_the_wheel("build_further", 5)
			_roll_the_wheel("build_closer", 5)
		"build_belt":


			builds.add_conveyor(Vector3(-13.0, 0.75, -5.0), Vector3(-13.0, 0.75, 5.0))
		"belt_feeds_stand":
			_join_a_belt_to_the_stand(builds)
		"reverse_belt":


			_turn_a_belt_round(builds.add_conveyor(
				Vector3(16.0, 0.75, -4.0), Vector3(16.0, 0.75, 4.0)))
		"first_needle":
			GameState.needles_found += 1
		"build_cabinet":
			builds.add_cabinet(Vector3(9.0, 0.05, 12.0), 0.0)
		"bank_needle":


			GameState.discover(0, Vector3.ZERO)
		"build_arm":
			builds.add_robotic_arm(Vector3(6.0, 0.05, 8.0), 0.0)
		"build_rake":
			builds.add_piston_rake(Vector3(3.0, 0.05, 8.0), 0.0)
		"build_power":


			if builds.generators.is_empty():
				builds.add_generator(Vector3(3.0, 0.0, 14.0), 0.0)
			builds.add_power_pole(Vector3(3.0, 0.0, 11.0), 0.0)
			for _i in 8:
				await get_tree().process_frame
				await get_tree().physics_frame
		"upgrade_belt":
			Tech.grant("belt_speed", 1)
		"rake_throw":


			player._open_console(builds.piston_rakes [0])
			for _i in 2:
				await get_tree().process_frame
			player.rake_panel.close()
		"buy_detector":
			GameState.grant_tool("metal_detector")
		"detector_power":


			var det: MetalDetector = player.detector
			det.set_active(true)
			for _flip in 3:
				det.toggle_power()
				await get_tree().process_frame
				det.toggle_power()
				await get_tree().process_frame


			det.set_active(false)
		"extend_shed":


			Tech.grant("deck", 1)
			Tech.grant("yard_space", 1)
		"pin_contract":


			var director: MissionDirector = world.missions
			for _attempt in 3:
				if director.is_done(id):
					break
				if GameState.contract_pinned:
					_press_board_contract()
					for _i in 2:
						await get_tree().process_frame
				_press_board_contract()
				for _i in 2:
					await get_tree().process_frame
		"first_contract":
			GameState.sign_contract(DeliveryBook.CONTRACTS [0] ["id"])
		"build_scanner":
			builds.add_scanner(Vector3(-6.0, 0.05, 12.0), 0.0)
		"wrapped_order":
			GameState.sign_contract(DeliveryBook.id_at(1))
		"build_drone":
			builds.add_hay_drone(Vector3(-12.0, 0.05, -8.0), 0.0)
		"build_gas_plant":
			var _plant: GasPlant = builds.add_gas_plant(Vector3(13.0, 0.0, -9.0), 0.0)
		"feed_gas_plant":
			for gen in builds.generators:
				if gen is GasPlant:
					gen.fuel = float(Cfg.PELLETIZER_BRICK_STRANDS) * Cfg.GAS_PLANT_KJ_PER_STRAND


func _press_board_contract() -> void:
	var board: DeliveryBoard = world.delivery_board
	if board == null:
		return
	var at:= board.docket_point()
	player.global_position = at + Vector3(0.0, 0.0, 1.6)
	board.take_press(player.eye_position(), (at - player.eye_position()).normalized())


func _roll_the_wheel(action: String, notches: int) -> void:
	var missions: MissionDirector = world.missions
	var tool_node: BuildTool = player.build
	if tool_node == null:
		return
	_hold_a_ghost()
	var ev:= InputSetup.event_from_spec(InputSetup.spec_of(action))
	if ev == null:
		print("    (%s is not bound to anything)" % action)
		return
	if player.current_tool != Player.Tool.BUILD:
		print("    (nothing could be equipped, so there is no ghost to slide)")
		return


	missions._watch()
	for i in notches:
		var press:= ev.duplicate() as InputEventMouseButton
		press.pressed = true
		tool_node._unhandled_input(press)
		missions._watch()


func _hold_a_ghost() -> void:
	if player.current_tool == Player.Tool.BUILD:
		return
	var pick:= _first_unlocked()
	if pick == "":
		Tech.grant("belt", 1)
		pick = _first_unlocked()
	if pick != "":
		player.equip_build(pick)


func _first_unlocked() -> String:
	for id: String in BuildCatalog.ids():
		if BuildCatalog.is_unlocked(str(id)):
			return str(id)
	return ""


func _put_a_tool_down(props: PropManager) -> void:
	var missions: MissionDirector = world.missions
	if player.carry.is_carrying():
		player.carry.drop()
	GameState.grant_tool("broom")
	player.select_hotbar_slot(3)

	missions._watch()
	player.drop_active_tool()
	missions._watch()


	for item in props.items.duplicate():
		if item.item_id == "broom":
			props.remove(item)


func _fetch_a_tool(props: PropManager) -> void:
	var missions: MissionDirector = world.missions
	var shop: ShopMenu = world.shop_menu
	if shop == null:
		return
	props.spawn("broom", Transform3D(Basis(), Vector3(18.0, 0.4, 18.0)))


	missions._watch()


	var was:= player.global_position
	player.global_position = (world.shop as HayShop).interact_point()
	if player.carry.is_carrying():
		player.carry.drop()
	shop.set_open(true)
	var before:= shop.fetched
	shop._on_fetch("broom")
	if shop.fetched == before:
		print("    (fetch refused: open=%s brooms=%d  ·  %s)"
			% [shop.is_open(), props.count_of("broom"), shop._status_label.text])
	shop.set_open(false)
	player.global_position = was
	missions._watch()


func _turn_a_belt_round(run: Conveyor) -> void:
	var missions: MissionDirector = world.missions
	missions._watch()
	if run == null:
		print("    (a belt could not be laid to turn round)")
		return
	player.build.reverse(run)
	missions._watch()


func _pull_something_down(builds: BuildManager) -> void:
	var missions: MissionDirector = world.missions
	var doomed:= builds.add_cabinet(Vector3(-4.0, 0.05, 12.0), 0.0)
	missions._watch()
	if doomed == null:
		print("    (a cabinet could not be built to knock down)")
		return
	player.build.dismantle(doomed)
	missions._watch()


func _wobble_in_place(times: int) -> void:
	var missions: MissionDirector = world.missions
	var held:= player.carry.held()
	if held == null:
		return
	Input.action_press("secondary")
	var rest:= held.global_transform
	for i in times:


		_lean_blade(held, rest, _tip_phase - 1, PI * (0.3 + 0.02 * float(i % 3)))
		missions._watch()
	held.global_transform = rest
	Input.action_release("secondary")


func _tip_it(times: int) -> void:
	var missions: MissionDirector = world.missions
	var toy:= player.carry.held()
	if toy == null:
		return
	if Cfg.simple_tools():


		var was:= missions.is_processing()
		missions.set_process(false)
		for i in times:
			await _fill_and_dump(toy as SandShovel)
			missions._watch()
		missions.set_process(was)


		missions._clock = MissionDirector.POLL
		return
	Input.action_press("secondary")
	var rest:= toy.global_transform
	for i in times:
		_lean_blade(toy, rest, _tip_phase)
		_tip_phase += 1
		missions._watch()
	toy.global_transform = rest
	Input.action_release("secondary")


func _fill_and_dump(toy: SandShovel) -> void:
	if toy == null or world.live == null:
		return
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4242
	var mine: Array [RigidBody3D] = []
	for i in 6:


		var b: RigidBody3D = world.live.spawn(toy._hold_centre()
			+ Vector3(rng.randf_range(-0.03, 0.03), 0.02, rng.randf_range(-0.03, 0.03)),
			StrandFactory.random_strand_basis(rng), Vector3.ZERO,
			StrandFactory.random_tint(rng))
		if b != null:
			mine.append(b)


	for f in 8:
		await get_tree().physics_frame
	var sent:= toy.dump()
	if sent <= 0:
		print("    (dump sent nothing: riding=%d held=%s)"
			% [toy.carried_strands(), str(toy.is_held())])


	for b in mine:
		if is_instance_valid(b):
			b.global_position = Vector3(0.0, -60.0, 0.0)
			b.linear_velocity = Vector3.ZERO
	for f in 2:
		await get_tree().physics_frame


func _lean_blade(tool_node: Node3D, rest: Transform3D, phase: int,
		roll: float = PI * 0.35) -> void:
	var axis:= Vector3(cos(float(phase) * PI), 0.0, sin(float(phase) * PI))
	tool_node.global_transform = Transform3D(
		Basis(axis, roll) * rest.basis, rest.origin)


func _pour_a_bucket_at_the_stand(props: PropManager) -> void:
	var missions: MissionDirector = world.missions
	var stand: HaySellingStand = world.stand
	var bucket: HayContainer = null
	for item in props.items:
		var box:= item as HayContainer
		if box != null:
			bucket = box
			break
	if bucket == null or stand == null:
		return
	player.global_position = stand.mouth_centre() + Vector3(0, 0, 1.6)


	player._set_tool(Player.Tool.HAND)
	if player.carry.is_carrying():
		player.carry.drop()
	player.carry.take(bucket)
	bucket.stored = 200
	missions._watch()

	for i in 30:
		bucket.stored = maxi(0, bucket.stored - 3)
		missions._watch()
	player.carry.drop()


func _join_a_belt_to_the_stand(builds: BuildManager) -> void:
	var stand: HaySellingStand = world.stand
	var intake:= stand.intake_path()
	if intake == null:
		return
	var head: Vector3 = stand.belt_entry_point()
	var from:= head + Vector3(0, 0, 1.0).rotated(Vector3.UP, stand.rotation.y) * 6.0
	builds.add_conveyor(Vector3(from.x, head.y, from.z), head)
	builds.rebuild_junctions()
