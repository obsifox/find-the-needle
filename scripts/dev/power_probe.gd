class_name DevPowerProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const REBUILD_FRAMES:= 8


const ROPE_SECONDS:= 4.0


const LANE_X:= 13.0


const NUDGE:= 0.15

var _pass:= 0
var _fail:= 0
var _deck_y:= 0.0


func run() -> void:
	for i in 40:
		await get_tree().process_frame

	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _case_the_model()
	await _case_the_curve()
	await _case_link_reach()
	await _case_supply_reach()
	await _case_the_cable_is_the_connection()
	await _case_the_sag_and_not_the_chord()
	await _case_satisfaction()
	await _case_a_bridge_coming_down()
	await _case_one_span_per_pole()
	await _case_a_rope_falls_once()
	await _case_a_box_bridges_too()
	await _case_a_save_round_trip()
	await _case_the_ghost_tells_the_truth()
	await _case_a_post_stands_on_the_floor()
	await _case_the_fuels()
	await _case_a_brownout_is_a_speed()
	await _case_zero_is_a_stop()
	await _case_the_sign_is_the_right_sign()
	await _case_the_other_zero()
	await _case_the_terminals_are_authored()
	await _case_the_switch()
	await _case_the_line_switch()
	await _case_the_pole_switch()
	await _case_every_machine_says_what_it_makes()
	await _case_one_utility_row()
	await _case_the_draw_and_the_way_out()
	await _case_a_feeder_slows_like_everything_else()
	await _case_a_feeder_still_needs_a_wire()
	await _case_the_draw_follows_the_model()
	await _case_a_dead_second_fire()
	await _case_a_load_too_big_for_the_box()
	await _case_a_split_to_one_fire()
	await _case_a_branch_keeps_its_other_links()
	await _case_the_line_is_dark()
	await _case_a_lorry_is_not_a_wall()
	await _case_the_ash_out_of_an_old_save()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_model() -> void:
	print("\n=== the pole ===")
	var pole: PowerPole = await _plant(Vector3(LANE_X, 0.0, 0.0))
	_check("model instantiated", pole.get_node_or_null("Model") != null
		or pole.get_child_count() > 0)
	var anchors:= pole.wire_anchors()
	_check("it offers one anchor, not two", anchors.size() == 1)


	var up:= pole.wire_point().y - pole.global_position.y
	_check("Marker_Wire is the crown insulator's groove at 3.206 m (got %.3f)" % up,
		absf(up - 3.206) < 0.02)


	var ground:= pole._find(PowerPole.N_GROUND) as Node3D
	_check("Marker_Ground is there", ground != null)
	if ground != null:
		_check("...and it restates the origin, so placement needs no offset "
			+ "(off by %.3f m)" % ground.global_position.distance_to(pole.global_position),
			ground.global_position.distance_to(pole.global_position) < 0.02)


	var bodies:= pole.find_children("*", "StaticBody3D", true, false)
	_check("the model ships its own collider, so none is built in code",
		bodies.size() > 0)
	if bodies.size() > 0:
		_check("...and it stands on L_BUILD",
			(bodies [0] as StaticBody3D).collision_layer == Cfg.L_BUILD)
	await _demolish_all_poles()


func _case_the_curve() -> void:
	print("\n=== the curve, which is one curve ===")


	var a:= Vector3(0.0, 4.0, 0.0)
	var b:= Vector3(6.5, 4.0, 0.0)
	var pts:= PowerLine.curve(a, b, 20)
	var mid:= pts [10]
	_check("the middle of a level span sits sag below the chord "
		+ "(%.4f m over 6.5 m)" % (4.0 - mid.y),
		absf((4.0 - mid.y) - 6.5 * Cfg.POLE_SAG) < 0.0005)


	_check("...which is docs/power_pole/view_span.png's 0.34 m to a tenth of a "
		+ "millimetre (%.4f m)" % (4.0 - mid.y), absf((4.0 - mid.y) - 0.34) < 0.0001)
	_check("the ends are on the anchors",
		pts [0].distance_to(a) < 0.0001 and pts [20].distance_to(b) < 0.0001)


	var short_pts:= PowerLine.curve(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), 20)
	_check("a short span sags less than a long one, because the sag is a "
		+ "fraction of the span", absf(short_pts [10].y) < absf(mid.y - 4.0))


	var root:= Node3D.new()
	world.add_child(root)
	var end_a:= _anchor(root, Vector3(LANE_X, 3.2, -3.0))
	var end_b:= _anchor(root, Vector3(LANE_X, 3.2, 3.0))
	var line:= PowerLine.hang_at(root, end_a, end_b, null)
	await _let_it_fall(line)
	_check("a hung rope falls and goes to sleep", line.is_asleep())
	var worst:= 0.0
	var want:= PowerLine.curve(end_a.global_position, end_b.global_position,
		PowerLine.POINTS - 1)
	var got:= line.points()
	for i in got.size():
		worst = maxf(worst, line.to_global(got [i]).distance_to(want [i]))
	var span_len:= end_a.global_position.distance_to(end_b.global_position)
	var lowest:= 0.0
	for i in got.size():
		lowest = maxf(lowest, end_a.global_position.y - line.to_global(got [i]).y)
	print("  [measure] span %.2f m: rope sags %.4f m (%.5f of span), the curve "
		% [span_len, lowest, lowest / span_len]
		+ "sags %.4f m (%.5f)" % [PowerLine.sag_for(span_len), Cfg.POLE_SAG])
	_check("...onto the curve the grid tested and the ghost drew "
		+ "(worst point off by %.4f m)" % worst, worst < 0.015)
	root.queue_free()
	await get_tree().process_frame


func _case_link_reach() -> void:
	print("\n=== poles find each other, out to %.1f m ===" % Cfg.POLE_LINK_R)
	var a: PowerPole = await _plant(Vector3(LANE_X, 0.0, - Cfg.POLE_LINK_R * 0.5))
	var inside: PowerPole = await _plant(Vector3(LANE_X, 0.0,
		- Cfg.POLE_LINK_R * 0.5 + Cfg.POLE_LINK_R - NUDGE))
	_check("two poles %.2f m apart are one network"
		% a.global_position.distance_to(inside.global_position),
		world.builds.grid.network_count() == 1)
	await _demolish(inside)
	var outside: PowerPole = await _plant(Vector3(LANE_X, 0.0,
		- Cfg.POLE_LINK_R * 0.5 + Cfg.POLE_LINK_R + NUDGE))
	_check("...and %.2f m apart are two"
		% a.global_position.distance_to(outside.global_position),
		world.builds.grid.network_count() == 2)
	await _demolish_all_poles()


func _case_supply_reach() -> void:
	print("\n=== a pole reaches machines out to %.1f m ===" % Cfg.POLE_SUPPLY_R)
	var press: HayCompressor = await _press_at(0.0)


	var near: PowerPole = await _plant(Vector3(LANE_X, 0.0, Cfg.POLE_SUPPLY_R - NUDGE))
	var grid: PowerGrid = world.builds.grid
	_check("a machine %.2f m away joins the pole's network"
		% absf(near.global_position.z - press.global_position.z),
		grid.network_of(press) >= 0)
	_check("...and gets a wire, hung from that pole", grid.pole_for(press) == near)
	await _demolish(near)
	var far: PowerPole = await _plant(Vector3(LANE_X, 0.0, Cfg.POLE_SUPPLY_R + NUDGE))
	_check("one %.2f m away does not"
		% absf(far.global_position.z - press.global_position.z),
		grid.network_of(press) < 0)


	_check("...and it is out of reach rather than obstructed",
		not grid.unreachable().has(press))
	_check("...so it reports no power", is_equal_approx(press.power, 0.0))
	await _clear_yard()


func _case_the_cable_is_the_connection() -> void:
	print("\n=== the cable is the connection, not the circle ===")
	var press: HayCompressor = await _press_at(0.0)


	print("  [note] the press's terminal is %s"
		% ("the model's Marker_WirePort" if press._find(HayCompressor.N_WIRE_PORT) != null
			else "a stand-in at %s, so the .glb has not been re-exported yet"
				% HayCompressor.WIRE_PORT_FALLBACK))


	var blind: PowerPole = await _plant(Vector3(LANE_X, 0.0, -5.5))
	var grid: PowerGrid = world.builds.grid
	_check("with a clear view it connects", grid.network_of(press) >= 0)

	world.builds.add_wall(Vector3(LANE_X - 3.0, 0.0, -1.5),
		Vector3(LANE_X + 3.0, 0.0, -1.5), YardWall.Bay.SOLID)
	await _settle()
	_check("a wall between them cuts the cable, and the machine leaves the "
		+ "network", grid.network_of(press) < 0)
	_check("...it reports zero", is_equal_approx(press.power, 0.0))
	_check("...it turns up in unreachable(), which is a different complaint "
		+ "from being too far away", grid.unreachable().has(press))
	_check("...and no wire is drawn from the pole that cannot see it",
		blind.wire_count() == 0)


	var seeing: PowerPole = await _plant(Vector3(LANE_X, 0.0, 3.0))
	_check("a second pole with a clear line connects it", grid.network_of(press) >= 0)
	_check("...and the wire hangs from THAT pole, not the blind one",
		grid.pole_for(press) == seeing)
	_check("...so the blind pole still draws no drop", _drops(blind) == 0)
	_check("...and the seeing one draws exactly one", _drops(seeing) == 1)
	_check("...and it is no longer reported as obstructed",
		not grid.unreachable().has(press))


	_check("the two poles are one network, over the wall", grid.network_count() == 1)
	await _clear_yard()


func _case_the_sag_and_not_the_chord() -> void:
	print("\n=== the chord is clear and the sag is not ===")


	var a:= Vector3(LANE_X, 4.0, -5.0)
	var b:= Vector3(LANE_X, 4.0, 5.0)
	var sag:= PowerLine.sag_for(a.distance_to(b))
	var top:= 4.0 - sag * 0.5
	var slab: StaticBody3D = _slab(Vector3(LANE_X, top - 0.25, 0.0), Vector3(1.2, 0.5, 1.2))
	await _settle()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var none: Array [RID] = []


	var chord:= PhysicsRayQueryParameters3D.create(a, b, PowerGrid.CABLE_MASK)
	chord.collide_with_areas = false
	_check("a straight ray between the ends sails over the slab, %.2f m under the chord"
		% (4.0 - top), space.intersect_ray(chord).is_empty())
	_check("...and the sampled wire, which dips %.2f m, does not" % sag,
		not PowerGrid.clear(space, a, b, none))


	slab.queue_free()
	await _settle()
	_check("with the slab gone the same run is clear",
		PowerGrid.clear(space, a, b, none))
	await _clear_yard()


func _case_satisfaction() -> void:
	print("\n=== supply, demand and satisfaction ===")


	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var press: HayCompressor = await _press_at(-3.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("the generator is on the network too, through its own take-off mast",
		grid.network_of(gen) >= 0)
	_check("...and the press with it", grid.network_of(press) >= 0)
	var got: Dictionary = grid.report(press)


	_check("supply is what the press asked for, %.1f kW, not the %.1f cap (got %.2f)"
		% [Cfg.COMPRESSOR_DRAW_KW, Cfg.GENERATOR_OUTPUT_KW, got ["supply"]],
		absf(float(got ["supply"]) - Cfg.COMPRESSOR_DRAW_KW) < 0.01)
	_check("...and the generator was pushed that load",
		absf(gen.demand_kw - Cfg.COMPRESSOR_DRAW_KW) < 0.01)
	_check("demand is the press's %.1f kW (got %.2f)"
		% [Cfg.COMPRESSOR_DRAW_KW, got ["demand"]],
		is_equal_approx(float(got ["demand"]), Cfg.COMPRESSOR_DRAW_KW))
	_check("with slack in the network everything runs at 100%",
		is_equal_approx(float(got ["satisfaction"]), 1.0)
			and is_equal_approx(press.power, 1.0))


	_check("spare is the %.1f cap less the %.1f draw (got %.2f)"
		% [Tech.generator_output(), Cfg.COMPRESSOR_DRAW_KW, got ["spare"]],
		absf(float(got ["spare"]) - (Tech.generator_output() - Cfg.COMPRESSOR_DRAW_KW)) < 0.01)
	_check("...and every readout reads the same figure, because they all read "
		+ "report()", is_equal_approx(float(grid.report(gen) ["satisfaction"]),
			float(got ["satisfaction"])))


	var second: HayCompressor = await _press_at(0.0)
	var third: HayCompressor = await _press_at(3.0)
	await _settle()
	var loaded: Dictionary = grid.report(press)
	var want:= Cfg.GENERATOR_OUTPUT_KW / (Cfg.COMPRESSOR_DRAW_KW * 3.0)
	_check("three presses on one generator demand %.1f kW"
		% (Cfg.COMPRESSOR_DRAW_KW * 3.0),
		is_equal_approx(float(loaded ["demand"]), Cfg.COMPRESSOR_DRAW_KW * 3.0))
	_check("...which is over the cap, so the supply is the cap, %.1f (got %.2f)"
		% [Cfg.GENERATOR_OUTPUT_KW, loaded ["supply"]],
		absf(float(loaded ["supply"]) - Cfg.GENERATOR_OUTPUT_KW) < 0.01)
	_check("satisfaction is supply over demand, %.4f (got %.4f)"
		% [want, float(loaded ["satisfaction"])],
		absf(float(loaded ["satisfaction"]) - want) < 0.0001)
	_check("...and every member was pushed it",
		absf(press.power - want) < 0.0001 and absf(second.power - want) < 0.0001
			and absf(third.power - want) < 0.0001)


	_check("the generator's voltmeter reads the network, not its own output",
		absf(gen.power - want) < 0.0001)


	gen.fuel = 0.0
	await _settle()
	_check("a dead firebox supplies nothing",
		is_equal_approx(float(grid.report(press) ["supply"]), 0.0))
	_check("...and the network browns out to zero rather than tripping",
		is_equal_approx(press.power, 0.0) and grid.network_of(press) >= 0)
	await _clear_yard()

	print("\n=== and a machine with no pole at all ===")
	var lonely: HayCompressor = await _press_at(0.0)
	await _settle()
	_check("it is on no network", world.builds.grid.network_of(lonely) < 0)
	_check("...reports zero", is_equal_approx(lonely.power, 0.0))
	_check("...and is not called obstructed, because nothing is in the way",
		not world.builds.grid.unreachable().has(lonely))
	await _clear_yard()


func _case_a_bridge_coming_down() -> void:
	print("\n=== a bridging pole coming down splits the network ===")
	var step:= Cfg.POLE_LINK_R - 1.0
	var west: PowerPole = await _plant(Vector3(LANE_X, 0.0, - step))
	var middle: PowerPole = await _plant(Vector3(LANE_X, 0.0, 0.0))
	var east: PowerPole = await _plant(Vector3(LANE_X, 0.0, step))
	var grid: PowerGrid = world.builds.grid
	_check("three poles in a line, each %.1f m from the next, are one network"
		% step, grid.network_count() == 1)
	_check("...even though the ends are %.1f m apart, well past the %.1f m reach"
		% [west.global_position.distance_to(east.global_position), Cfg.POLE_LINK_R],
		west.global_position.distance_to(east.global_position) > Cfg.POLE_LINK_R)
	await _demolish(middle)
	_check("taking the middle one out leaves two", grid.network_count() == 2)
	_check("...and the two ends are on different ones",
		grid.network_of(west) != grid.network_of(east))
	_check("...and neither is carrying a span any more",
		west.wire_count() == 0 and east.wire_count() == 0)
	await _clear_yard()


func _case_a_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	await _press_at(-3.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	var before: Dictionary = grid.report(pole)
	var nets: int = grid.network_count()

	var d:= pole.to_dict()
	_check("to_dict names the type", str(d.get("type", "")) == "power_pole")
	for key: String in ["position", "yaw"]:
		_check("to_dict carries %s" % key, d.has(key))
	var at:= pole.global_position

	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	_check("the yard is empty after clear", world.builds.power_poles.is_empty())
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()

	_check("one pole came back", world.builds.power_poles.size() == 1)
	var back: PowerPole = world.builds.power_poles [0]
	_check("...where it was (off by %.3f m)" % back.global_position.distance_to(at),
		back.global_position.distance_to(at) < 0.01)
	var after: Dictionary = grid.report(back)
	_check("the same number of networks came back (%d)" % nets,
		grid.network_count() == nets)
	_check("...with the same supply, %.2f kW" % float(before ["supply"]),
		is_equal_approx(float(after ["supply"]), float(before ["supply"])))
	_check("...the same demand, %.2f kW" % float(before ["demand"]),
		is_equal_approx(float(after ["demand"]), float(before ["demand"])))
	_check("...and the same machines on it (%d)" % int(before ["machines"]),
		int(after ["machines"]) == int(before ["machines"]))
	await _clear_yard()


func _case_the_ghost_tells_the_truth() -> void:
	print("\n=== the ghost tells the truth ===")
	var tool: BuildTool = player.build
	var grid: PowerGrid = world.builds.grid
	var spot:= Vector3(LANE_X, 0.0, 0.0)


	tool.set_mode(BuildTool.Mode.POWER_POLE)
	var neutral: Dictionary = await _survey(tool, spot)
	_check("with an empty yard the ghost links nothing",
		(neutral ["links"] as Array).is_empty())
	_check("...and the line is NEUTRAL, because the first pole in a yard has "
		+ "nothing to link to", str(_status(tool) ["tone"]) == "neutral")


	var far: PowerPole = await _plant(spot + Vector3(0.0, 0.0, Cfg.POLE_LINK_R + 2.0))
	var red: Dictionary = await _survey(tool, spot)
	_check("with a pole out of reach the ghost still links nothing",
		(red ["links"] as Array).is_empty())
	_check("...and the line goes RED, which is a warning and not a refusal",
		str(_status(tool) ["tone"]) == "bad" and bool(_status(tool) ["ok"]))
	await _demolish(far)


	var near: PowerPole = await _plant(spot + Vector3(0.0, 0.0, Cfg.POLE_LINK_R - 1.0))
	var press: HayCompressor = await _press_at(-3.0)
	var survey: Dictionary = await _survey(tool, spot)
	_check("the ghost draws a span to the pole in reach",
		(survey ["links"] as Array).size() == 1
			and (survey ["links"] as Array) [0] == near)
	_check("...a drop to the press it would pick up",
		(survey ["reaches"] as Array).size() == 1
			and (survey ["reaches"] as Array) [0] == press)
	_check("...nothing it cannot reach", (survey ["blocked"] as Array).is_empty())
	_check("...one span per wire it promised (%d)" % (survey ["spans"] as Array).size(),
		(survey ["spans"] as Array).size() == 2)
	_check("...and the line is GREEN", str(_status(tool) ["tone"]) == "good")


	var placed: PowerPole = await _plant(spot)
	_check("the placed pole links exactly the pole the ghost drew a span to",
		grid.network_of(placed) == grid.network_of(near))
	_check("...and powers exactly the machine the ghost drew a drop to",
		grid.pole_for(press) == placed)
	await _clear_yard()


	var kept: PowerPole = await _plant(spot + Vector3(0.0, 0.0, 4.0))
	var settled: HayCompressor = await _press_at(3.0)
	_check("setup: the press is on the pole beside it", grid.pole_for(settled) == kept)
	var honest: Dictionary = await _survey(tool, spot)
	_check("the ghost can see a press that has a nearer pole, and draws NO "
		+ "drop to it, because it stays where it is",
		(honest ["reaches"] as Array).is_empty())
	_check("...and does not call it blocked either",
		(honest ["blocked"] as Array).is_empty())
	_check("...so the ghost hangs the one span and nothing else (%d)"
		% (honest ["spans"] as Array).size(),
		(honest ["spans"] as Array).size() == 1)
	var kept_line: String = str(_status(tool) ["note"])
	_check("...and the line says so (%s)" % kept_line,
		kept_line.ends_with("REACHES 0 MACHINES")
			and str(_status(tool) ["tone"]) == "good")
	var beside: PowerPole = await _plant(spot)
	_check("once placed, the press is still on the pole it had",
		grid.pole_for(settled) == kept)
	_check("...and the new pole carries no drop, as the ghost said",
		_drops(beside) == 0)
	await _clear_yard()


	var old: PowerPole = await _plant(spot + Vector3(0.0, 0.0, 8.0))
	var taken: HayCompressor = await _press_at(3.0)
	_check("setup: the press is on the far pole", grid.pole_for(taken) == old)
	var steal: Dictionary = await _survey(tool, spot)
	_check("a ghost nearer than the pole a machine has draws the drop",
		(steal ["reaches"] as Array).size() == 1
			and (steal ["reaches"] as Array) [0] == taken)
	var nearer: PowerPole = await _plant(spot)
	_check("...and the placed pole takes the machine over",
		grid.pole_for(taken) == nearer)
	_check("...leaving the old pole with no drop", _drops(old) == 0)
	await _clear_yard()


	var walled: HayCompressor = await _press_at(0.0)
	world.builds.add_wall(Vector3(LANE_X - 3.0, 0.0, -1.5),
		Vector3(LANE_X + 3.0, 0.0, -1.5), YardWall.Bay.SOLID)
	await _settle()
	var behind:= Vector3(LANE_X, 0.0, -5.5)
	var amber: Dictionary = await _survey(tool, behind)
	_check("a machine the ghost cannot wire is reported as blocked",
		(amber ["blocked"] as Array).size() == 1
			and (amber ["blocked"] as Array) [0] == walled)
	_check("...and draws no ghost drop", (amber ["reaches"] as Array).is_empty())
	var st: Dictionary = _status(tool)
	_check("...and the line goes AMBER", str(st ["tone"]) == "warn")
	_check("...naming the count, so it is actionable (%s)" % str(st ["note"]),
		str(st ["note"]).begins_with("1 MACHINE OUT OF CABLE REACH"))
	_check("...and it still places, because none of the four states is a "
		+ "refusal", bool(st ["ok"]))


	var seeing: PowerPole = await _plant(Vector3(LANE_X, 0.0, 3.0))
	_check("setup: a pole on the press's side of the wall wires it",
		grid.pole_for(walled) == seeing)
	var calm: Dictionary = await _survey(tool, behind)
	_check("with the press wired from its own side, the ghost behind the wall "
		+ "no longer calls it blocked", (calm ["blocked"] as Array).is_empty())
	_check("...draws no drop to it either", (calm ["reaches"] as Array).is_empty())
	_check("...and the line is GREEN, not amber",
		str(_status(tool) ["tone"]) == "good")
	tool.set_mode(BuildTool.Mode.CONVEYOR)
	await _clear_yard()


func _case_a_post_stands_on_the_floor() -> void:
	print("\n=== a post stands on the floor ===")
	await _clear_yard()
	var tool: BuildTool = player.build
	tool.set_mode(BuildTool.Mode.POWER_POLE)
	var spot:= Vector3(LANE_X, 0.0, 0.0)

	var open: Dictionary = await _site(tool, spot)
	_check("a pole on open floor is allowed (%s)" % open ["reason"], bool(open ["ok"]))


	world.builds.add_conveyor(Vector3(LANE_X, _deck_y, -3.0),
		Vector3(LANE_X, _deck_y, 3.0))
	await _settle()
	var on_belt: Dictionary = await _site(tool, spot)
	_check("setup: the aim lands on the belt deck (y %.2f)" % float(on_belt ["y"]),
		float(on_belt ["y"]) > _deck_y - 0.1)
	_check("a pole aimed at a belt is refused (%s)" % on_belt ["reason"],
		not bool(on_belt ["ok"]) and str(on_belt ["reason"]) == "on a belt")
	tool.set_mode(BuildTool.Mode.POWER_BOX)
	var box_on_belt: Dictionary = await _site(tool, spot)
	_check("...and so is a cable box (%s)" % box_on_belt ["reason"],
		not bool(box_on_belt ["ok"]) and str(box_on_belt ["reason"]) == "on a belt")
	tool.set_mode(BuildTool.Mode.POWER_POLE)
	var beside: Dictionary = await _site(tool, spot + Vector3(1.2, 0.0, 0.0))
	_check("...but a pole on the floor beside the belt is fine (%s)" % beside ["reason"],
		bool(beside ["ok"]))
	await _clear_yard()


	world.builds.add_conveyor(Vector3(LANE_X, 2.2, -3.0), Vector3(LANE_X, 2.2, 3.0))
	await _settle()
	var under: Dictionary = await _site(tool, spot + Vector3(0.0, 0.0, 0.5), 1.5)
	_check("a pole under a raised belt is refused (%s)" % under ["reason"],
		not bool(under ["ok"]) and str(under ["reason"]) == "blocked")
	await _clear_yard()


	var press: HayCompressor = await _press_at(0.0)
	var roof: Dictionary = await _site(tool, press.global_position)
	_check("a pole aimed at a press is refused (%s, y %.2f)"
		% [roof ["reason"], float(roof ["y"])], not bool(roof ["ok"]))
	await _clear_yard()


	var wall:= _slab(Vector3(LANE_X + 0.25, 1.5, 0.0), Vector3(0.4, 3.0, 2.0))
	await _settle()
	var into: Dictionary = await _site(tool, spot)
	_check("a pole driven into the side of a wall is refused (%s)" % into ["reason"],
		not bool(into ["ok"]) and str(into ["reason"]) == "blocked")
	var near: Dictionary = await _site(tool, spot + Vector3(-0.3, 0.0, 0.0))
	_check("...but one a hand's breadth off it is fine (%s)" % near ["reason"],
		bool(near ["ok"]))


	var rail:= _slab(Vector3(LANE_X + 3.0, 1.0, 0.0), Vector3(0.1, 0.1, 2.0))
	rail.collision_layer = Cfg.L_WORLD
	await _settle()
	var perched: Dictionary = await _site(tool, Vector3(LANE_X + 3.0, 0.0, 0.0))
	_check("setup: the aim lands on the rail (y %.2f)" % float(perched ["y"]),
		float(perched ["y"]) > 1.0)
	_check("a pole balanced on a rail is refused (%s)" % perched ["reason"],
		not bool(perched ["ok"]) and str(perched ["reason"]) == "stand it on the floor")
	wall.queue_free()
	rail.queue_free()
	await _settle()


	var deck: Platform = world.builds.add_platform(Vector3(LANE_X, 2.5, 8.0), Vector2(4.0, 4.0))
	await _settle()
	var upstairs: Dictionary = await _site(tool, deck.global_position)
	_check("a pole on a deck is allowed (%s)" % upstairs ["reason"], bool(upstairs ["ok"]))
	var lip: Dictionary = await _site(tool, deck.global_position + Vector3(1.95, 0.0, 0.0))
	_check("...but not on its very edge (%s)" % lip ["reason"],
		not bool(lip ["ok"]) and str(lip ["reason"]) == "too near the edge")


	var floor_pole: PowerPole = world.builds.add_power_pole(Vector3(LANE_X + 3.0, 0.0, 0.0), 0.0)
	var deck_pole: PowerPole = world.builds.add_power_pole(deck.global_position, 0.0)
	var deck_box: PowerPole = world.builds.add_power_pole(deck.global_position + Vector3(1.0, 0.0, 1.0),
		0.0, true)
	await _settle()
	var floor_low:= _lowest_drawn(floor_pole)
	_check("setup: a pole on the floor still drives its butt in (%.3f m)" % floor_low,
		floor_low < -0.4)
	_check("a pole on a deck knows it is on one", deck_pole.on_deck and not floor_pole.on_deck)
	var deck_low:= _lowest_drawn(deck_pole)
	_check("...and draws nothing below the plate (%.3f m)" % deck_low,
		deck_low >= - Cfg.PLATFORM_PLATE_THICK and deck_low < 0.0)
	var box_low:= _lowest_drawn(deck_box)
	_check("...and neither does a cable box (%.3f m)" % box_low,
		deck_box.on_deck and box_low >= - Cfg.PLATFORM_PLATE_THICK)
	_check("...and it still wears the timber, not white plastic",
		_skinned(deck_pole))

	deck_pole.set_on_deck(false)
	_check("taken off the deck, the butt comes back (%.3f m)" % _lowest_drawn(deck_pole),
		_lowest_drawn(deck_pole) < -0.4)
	deck_pole.set_on_deck(true)


	var deck_at:= deck.global_position
	var saved: Array = world.builds.to_array()
	world.builds.from_array(saved)
	await _settle()
	var reloaded: PowerPole = null
	for post: PowerPole in world.builds.power_poles:
		if not post.buried() and post.global_position.distance_to(deck_at) < 0.1:
			reloaded = post
	_check("a pole loaded onto a deck is cut too (%s)"
		% ("%.3f m" % _lowest_drawn(reloaded) if reloaded != null else "no pole"),
		reloaded != null and reloaded.on_deck
		and _lowest_drawn(reloaded) >= - Cfg.PLATFORM_PLATE_THICK)
	await _clear_yard()


	var was:= player.global_position
	player.global_position = spot + Vector3.UP * 0.1
	await _settle()
	var feet: Dictionary = await _site(tool, spot)
	_check("a pole aimed at the player's feet is refused (%s)" % feet ["reason"],
		not bool(feet ["ok"]) and str(feet ["reason"]) == "you are in the way")
	player.global_position = was
	await _settle()
	tool.set_mode(BuildTool.Mode.CONVEYOR)


func _site(tool: BuildTool, at: Vector3, above: float = 6.0) -> Dictionary:
	await get_tree().physics_frame
	var q:= PhysicsRayQueryParameters3D.create(Vector3(at.x, above, at.z),
		Vector3(at.x, -1.0, at.z))
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	q.collide_with_areas = false
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return { "ok": false, "reason": "the ray found nothing", "y": NAN }
	var ghost: PowerPole = tool._post_ghost()
	var ground: Vector3 = hit ["position"]
	ghost.global_position = ground
	ghost.global_rotation = Vector3.ZERO
	var result: Dictionary = tool._evaluate_pole(ground, hit ["normal"], hit ["collider"])
	result ["y"] = ground.y
	return result


func _lowest_drawn(post: PowerPole) -> float:
	var low:= INF
	for instance in post._meshes():
		var mesh:= instance.mesh as ArrayMesh
		if mesh == null:
			continue
		var xf:= post._to_post(instance)
		for s in mesh.get_surface_count():
			var arrays:= mesh.surface_get_arrays(s)
			if arrays.size() != Mesh.ARRAY_MAX or arrays [Mesh.ARRAY_VERTEX] == null:
				continue
			var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
			if arrays [Mesh.ARRAY_INDEX] == null:
				for v in verts:
					low = minf(low, (xf * v).y)
				continue
			var index: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
			for i in index:
				low = minf(low, (xf * verts [i]).y)
	return low


func _skinned(post: PowerPole) -> bool:
	for instance in post._meshes():
		if instance.mesh == null:
			continue
		for s in instance.mesh.get_surface_count():
			if instance.get_surface_override_material(s) == null:
				return false
	return true


func _plant(at: Vector3) -> PowerPole:
	var pole: PowerPole = world.builds.add_power_pole(at, 0.0)
	await _settle()
	return pole


func _press_at(z: float) -> HayCompressor:
	var press: HayCompressor = world.builds.add_compressor(
		Vector3(LANE_X, _deck_y, z), 0.0)
	await _settle()
	return press


func _demolish(building: Node3D) -> void:
	world.builds._demolish(building)
	await _settle()


func _case_the_fuels() -> void:
	print("\n=== the fuels, per kilojoule ===")
	var per:= Cfg.GENERATOR_KJ_PER_STRAND
	for fuel: Array in [["loose hay", Cfg.GENERATOR_BURN_LOOSE],
			["a bale", Cfg.GENERATOR_BURN_BALE], ["a brick", Cfg.GENERATOR_BURN_BRICK],
			["a foiled bale", Cfg.GENERATOR_BURN_FOIL], ["a disc", Cfg.GENERATOR_BURN_DISC]]:
		_check("a straw in %s is worth %.1f kJ in a Hay Generator" % [fuel [0], per],
			is_equal_approx(float(fuel [1]) * per, per))
	_check("a straw in a brick is worth %.1f kJ in a Gas Plant, three times as much"
		% Cfg.GAS_PLANT_KJ_PER_STRAND,
		is_equal_approx(Cfg.GAS_PLANT_KJ_PER_STRAND, 3.0 * per))

	var loose:= 1.0 / (Cfg.GENERATOR_BURN_LOOSE * per)
	var bale:= Tech.bale_value_ratio() / (Cfg.GENERATOR_BURN_BALE * per)
	var brick:= Tech.brick_value_ratio() / (Cfg.GENERATOR_BURN_BRICK * per)
	var foil:= (Cfg.COMPRESSOR_BALE_RATIO * Cfg.WRAPPER_FOILED_RATIO
		/ (Cfg.GENERATOR_BURN_FOIL * per))
	var plant:= Tech.brick_value_ratio() / Cfg.GAS_PLANT_KJ_PER_STRAND
	_check("in a Hay Generator a bale costs more a kJ than loose hay (%.2f > %.2f)"
		% [bale, loose], bale > loose)
	_check("...so does a brick (%.2f)" % brick, brick > loose)
	_check("...and a foiled bale most of all (%.2f): never burn the premium product"
		% foil, foil > bale and foil > loose)
	_check("a brick in a Gas Plant costs less a kJ than loose hay in a generator (%.3f < %.3f)"
		% [plant, loose], plant < loose)
	Tech.grant("brick_quality", 5)
	var top:= Tech.brick_value_ratio() / Cfg.GAS_PLANT_KJ_PER_STRAND
	_check("...and at the top brick quality it is within a tenth of it (%.3f)" % top,
		top < loose * 1.1)
	_check("...where it would have lost by more at 2.5 kJ (%.3f)"
		% (Tech.brick_value_ratio() / 2.5), Tech.brick_value_ratio() / 2.5 > top)
	Tech.grant("brick_quality", 0)

	var high:= Vector3(LANE_X, 8.0, 0.0)
	for id: String in ["eco_brick", "hay_wad", "hay_bale", "foiled_bale"]:
		var body: Carryable = world.props.spawn(id, Transform3D(Basis(), high),
			{ "strands": 40 })
		high.y += 2.0
		if body == null:
			_check("spawned a %s to burn" % id, false)
			continue
		var want: float = float(body.hay_strands()) * per
		_check("a %s of %d strands is worth %.1f kJ in the box" % [id, body.hay_strands(), want],
			is_equal_approx(HayGenerator.burn_value(body), want))
		world.props.remove(body)
	for i in 4:
		await get_tree().physics_frame


func _case_a_brownout_is_a_speed() -> void:
	print("\n=== a brownout is a speed multiplier ===")
	await _clear_yard()


	Tech.grant("rake_bite", 1)
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var drone: HayDrone = world.builds.add_hay_drone(Vector3(LANE_X - 2.0, 0.0, -1.0), 0.0)
	var rake: PistonRake = world.builds.add_piston_rake(Vector3(LANE_X, 0.0, 4.0), 0.0)
	var gun: TubeLauncher = world.builds.add_tube_launcher(Vector3(LANE_X, 0.0, -3.0), 0.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	var got: Dictionary = grid.report(gun)


	var demand:= Cfg.DRONE_DRAW_KW + Tech.rake_draw_kw() + Cfg.LAUNCHER_DRAW_KW
	_check("the drone, the rake and the launcher all found the pole",
		grid.network_of(drone) >= 0 and grid.network_of(rake) >= 0
			and grid.network_of(gun) >= 0)
	_check("together they want %.1f kW off %.1f (demand %.2f)"
		% [demand, Cfg.GENERATOR_OUTPUT_KW, got ["demand"]],
		is_equal_approx(float(got ["demand"]), demand))
	var want:= Cfg.GENERATOR_OUTPUT_KW / demand
	_check("so satisfaction is exactly %.2f (got %.4f)" % [want, got ["satisfaction"]],
		absf(float(got ["satisfaction"]) - want) < 0.0001)
	_check("...and all three were pushed it",
		absf(gun.mains - want) < 0.0001 and absf(drone.power - want) < 0.0001
			and absf(rake.power - want) < 0.0001)


	var line: String = world.hud._machine_diagnostic(rake)
	var rated:= float(Tech.rake_bite_strands()) / Tech.rake_throw_seconds()
	_check("the rake's hover line quotes the rate it is AT, %.1f hay/s" % (rated * want),
		line.contains("%.1f hay/s" % (rated * want)))
	_check("...and not the rating it is missing (%.1f)" % rated,
		not line.contains("rated"))


	_check("...and the rake, which produces nothing, adds no row",
		world.hud._machine_product(rake) == "")
	_check("...nor the drone", world.hud._machine_product(drone) == "")


	_check("...and at %d%% the machine gives no warning about the network"
		% int(round(want * 100.0)),
		not line.contains("everything at") and not line.contains("SHORT ON"))
	_check("...but says what it draws and what it gets: %s" % line.get_slice("\n", 1),
		line.contains("this machine needs %.1f kW  ·  it is getting %d%% of that"
			% [Tech.rake_draw_kw(), int(round(want * 100.0))]))


	var pole_line: String = world.hud._machine_diagnostic(_pole)
	_check("the pole says so at %d%% all the same: %s"
		% [int(round(want * 100.0)), pole_line.replace("\n", "  /  ")],
		pole_line.contains("everything at %d%%" % int(round(want * 100.0)))
			and pole_line.contains("needs %.1f kW" % demand)
			and pole_line.contains("makes %.1f kW" % Cfg.GENERATOR_OUTPUT_KW)
			and pole_line.contains("SHORT %.1f kW" % (demand - Cfg.GENERATOR_OUTPUT_KW)))


	_check("...and says how many generators would cover it",
		pole_line.contains("Build 1 more hay generator."))


	var press: HayCompressor = await _press_at(1.5)
	var short:= Cfg.GENERATOR_OUTPUT_KW / (demand + Cfg.COMPRESSOR_DRAW_KW)
	line = world.hud._machine_diagnostic(rake)
	_check("a press stood by the pole is on the line too",
		is_instance_valid(press) and grid.network_of(press) == grid.network_of(rake))
	_check("...so the yard falls to %d%% (%.3f)"
		% [int(round(short * 100.0)), float(grid.report(rake) ["satisfaction"])],
		absf(float(grid.report(rake) ["satisfaction"]) - short) < 0.0001)
	_check("...and now the rake says which utility is short: %s"
		% line.get_slice("\n", 1),
		line.contains("SHORT ON POWER  ·  everything at %d%%"
			% int(round(short * 100.0))))


	_check("...on ONE row, with no kilowatts on it (%d rows)"
		% (line.count("\n") + 1),
		line.count("\n") == 1 and not line.contains("kW"))
	world.builds.demolish(press)
	await _settle()


	gun._reload = Cfg.LAUNCHER_CYCLE_SECONDS
	var frames:= 0
	while gun._reload >= 0.0 and frames < 3000:
		await get_tree().physics_frame
		frames += 1
	var took:= float(frames) / 60.0
	var slow:= Cfg.LAUNCHER_CYCLE_SECONDS / want
	_check("a %.2f s reload took %.2f s: %.3f times as long, wanted %.3f"
		% [Cfg.LAUNCHER_CYCLE_SECONDS, took, took / Cfg.LAUNCHER_CYCLE_SECONDS, 1.0 / want],
		absf(took - slow) <= 2.0 / 60.0)
	Tech.grant("rake_bite", 0)
	await _clear_yard()


func _case_the_switch() -> void:
	print("\n=== the switch ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var press: HayCompressor = await _press_at(-3.0)
	var second: HayCompressor = await _press_at(0.0)
	var third: HayCompressor = await _press_at(3.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	var three:= Cfg.COMPRESSOR_DRAW_KW * 3.0
	_check("three presses want %.1f kW off a %.1f kW fire" % [three, Cfg.GENERATOR_OUTPUT_KW],
		absf(float(grid.report(press) ["demand"]) - three) < 0.01
			and float(grid.report(press) ["satisfaction"]) < 0.999)
	third.set_switched_off(true)
	await _settle()
	var got: Dictionary = grid.report(press)
	_check("switch one off and the demand drops to %.1f (got %.2f)"
		% [Cfg.COMPRESSOR_DRAW_KW * 2.0, got ["demand"]],
		absf(float(got ["demand"]) - Cfg.COMPRESSOR_DRAW_KW * 2.0) < 0.01)
	_check("...so the other two run at 100%% (%.3f)" % float(got ["satisfaction"]),
		float(got ["satisfaction"]) > 0.999 and press.power > 0.999)
	_check("the one that is off stands at zero", third.power == 0.0)
	_check("...keeps the line's figure for when it comes back", third.line_power > 0.999)
	_check("...raises no sign: off is a decision, not a fault", third.alert_reason() == "")
	_check("...and says so on the crosshair line",
		world.hud._machine_diagnostic(third).contains("SWITCHED OFF"))
	var batch:= Tech.compressor_bale_strands()
	third.stored = batch
	for i in 60:
		await get_tree().physics_frame
	_check("...and does no work: %d strands still in the buffer" % third.stored,
		third.stored == batch and not third.is_pressing())
	_check("to_dict carries the switch", bool(third.to_dict().get("off", false)))


	var panel: MachinePanel = world.machine_panel
	_check("the world built the switch panel", panel != null)
	if panel != null:
		panel.open(third)


		_check("opened on the off press it says so and offers TURN ON",
			panel.is_open() and panel._readout.text == tr("SWITCHED OFF")
				and not panel._switch.running)


		var press_made: String = panel._product.text
		_check("...and still says what a bale is made of: %s" % press_made,
			panel._product.visible
				and press_made == "1 bale = %d hay strands" % Tech.compressor_bale_strands())


		_check("...and what it will take when it runs: %s" % panel._budget.text,
			third.draw_kw() == 0.0 and third.rated_kw() == Cfg.COMPRESSOR_DRAW_KW
				and panel._budget.text.begins_with(
					tr("this machine needs %.1f kW") % Cfg.COMPRESSOR_DRAW_KW))
		panel._on_switch()
		_check("...one press of the button turns it on, and the button turns red",
			not third.is_switched_off()
				and panel._switch.running)


		await _settle()
		panel._refresh()
		var share:= int(round(float(grid.report(third) ["satisfaction"]) * 100.0))
		_check("...and running short it says how much of that it gets: %s"
			% panel._budget.text,
			share < 100 and panel._budget.text.begins_with(
				tr("this machine needs %.1f kW  ·  it is getting %d%% of that")
					% [Cfg.COMPRESSOR_DRAW_KW, share]))
		panel._on_switch()
		_check("...and again turns it off", third.is_switched_off())
		panel.close()
		_check("the panel closed", not panel.is_open())


		panel.open(gen)
		var cap:= panel._draws_cap()
		var short_h:= panel._draws_scroll.custom_minimum_size.y
		_check("opened on the generator it lists its three presses in %.0f px" % short_h,
			panel._draws_scroll.visible and panel.draw_rows() == 3
				and is_equal_approx(short_h, minf(panel._draws.get_combined_minimum_size().y, cap)))
		var many: PackedStringArray = []
		for i in 100:
			many.append("robotic arm\t4.0 kW")
		panel._write_draws(many)
		var long_h:= panel._draws_scroll.custom_minimum_size.y
		_check("...and a hundred rows (%.0f px of text) stop at the cap: %.0f of %.0f px" % [
			panel._draws.get_combined_minimum_size().y, long_h, cap],
			is_equal_approx(long_h, cap) and cap <= MachinePanel.DRAWS_MAX_H
				and long_h < panel._draws.get_combined_minimum_size().y)
		panel.close()

	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	world.builds.from_array(saved)
	await _settle()
	await _settle()
	var back_off:= 0
	var back_on:= 0
	for machine in world.builds.compressors:
		if machine.is_switched_off():
			back_off += 1
		else:
			back_on += 1
	_check("a save round trip brings one press back off and two on (%d off, %d on)"
		% [back_off, back_on], back_off == 1 and back_on == 2)
	for machine in world.builds.compressors:
		if machine.is_switched_off():
			_check("...and the off one is standing still", machine.power == 0.0)
			machine.set_switched_off(false)
	await _settle()
	var all_on: Dictionary = grid.report(world.builds.compressors [0])
	_check("switched back on, all three draw again (%.1f kW)" % float(all_on ["demand"]),
		absf(float(all_on ["demand"]) - three) < 0.01)

	var fire: HayGenerator = world.builds.generators [0]
	fire.set_switched_off(true)
	await _settle()
	await _settle()
	var dark: Dictionary = grid.report(world.builds.compressors [0])
	_check("a switched-off generator supplies nothing (%.2f)" % float(dark ["supply"]),
		float(dark ["supply"]) < 0.001 and not fire.is_burning())
	_check("...holds its deck, so the belt behind it backs up", fire.deck().is_blocked())
	_check("...and the yard browns out to zero rather than tripping",
		world.builds.compressors [0].power == 0.0)
	fire.set_switched_off(false)
	await _settle()
	await _settle()
	_check("and back on, it catches on what was left in the box",
		fire.is_burning() and float(grid.report(world.builds.compressors [0]) ["supply"]) > 0.1)
	await _clear_yard()


func _case_the_line_switch() -> void:
	print("\n=== the line switch on a pole ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var near: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var press: HayCompressor = await _press_at(-3.0)
	var far: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 11.0))
	var other: HayCompressor = await _press_at(11.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("two poles 11 m apart make two lines", grid.network_count() == 2)
	_check("...with the press and the generator on the near one",
		grid.network_of(press) == grid.network_of(near)
			and grid.network_of(gen) == grid.network_of(near))
	_check("...and the other press on the far one",
		grid.network_of(other) == grid.network_of(far))
	var switches:= grid.switches_of(near)
	_check("the near line has two switches, the press and the generator (%d)"
		% switches.size(),
		switches.size() == 2 and switches.has(press) and switches.has(gen))


	var eye:= near.global_position + Vector3(0.0, 1.5, 1.6)
	_check("pole_under finds the pole the crosshair is on",
		world.builds.pole_under(eye, Vector3.FORWARD) == near)
	_check("...console_under hands it to the interact key",
		world.builds.console_under(eye, Vector3.FORWARD) == near)
	_check("...and looking away finds nothing",
		world.builds.pole_under(eye, Vector3.BACK) == null)

	var panel: PolePanel = world.pole_panel
	_check("the world built the pole panel", panel != null)
	if panel == null:
		await _clear_yard()
		return
	panel.open(near)
	_check("it opens on the pole and offers to turn the whole line off",
		panel.is_open() and panel.pole() == near
			and panel._switch.tooltip_text == tr("TURN OFF THE WHOLE LINE")
			and panel._switch.running)
	_check("...and reads the line's figures: %s" % panel._readout.text,
		panel._readout.text == MachinePanel._network_text(grid.report(near)))

	panel._on_switch()
	await _settle()
	await _settle()
	_check("one press turns off the press and the generator",
		press.is_switched_off() and gen.is_switched_off())
	_check("...and leaves the other line's press alone", not other.is_switched_off())
	var dark: Dictionary = grid.report(near)
	_check("...so the line wants nothing and makes nothing (%.2f / %.2f kW)"
		% [float(dark ["demand"]), float(dark ["supply"])],
		float(dark ["demand"]) < 0.001 and float(dark ["supply"]) < 0.001)
	_check("...the press stands still and raises no sign",
		press.power == 0.0 and press.alert_reason() == "")
	_check("...and the plate says everything is off, with a green TURN ON",
		panel._readout.text == tr("EVERYTHING ON THIS LINE IS SWITCHED OFF")
			and panel._switch.tooltip_text == tr("TURN ON THE WHOLE LINE")
			and not panel._switch.running)
	_check("to_dict carries the switch on both",
		bool(press.to_dict().get("off", false)) and bool(gen.to_dict().get("off", false)))

	panel._on_switch()
	await _settle()
	await _settle()
	_check("a second press turns them both back on",
		not press.is_switched_off() and not gen.is_switched_off())
	_check("...the fire catches again and the press gets power (%.3f)" % press.power,
		gen.is_burning() and press.power > 0.0)


	press.set_switched_off(true)
	panel._refresh()
	_check("with only the press off, the line still counts as running",
		grid.line_running(near) and panel._switch.running)
	panel._on_switch()
	panel._on_switch()
	_check("...and off then on brings the press back too", not press.is_switched_off())
	panel.close()
	_check("the panel closed", not panel.is_open())


	await _demolish(other)
	await _settle()
	panel.open(far)
	_check("a pole with nothing on its line offers a button that cannot be pressed",
		grid.switches_of(far).is_empty() and panel._switch.disabled
			and not grid.line_running(far))
	panel.close()
	await _clear_yard()


func _case_the_pole_switch() -> void:
	print("\n=== the pole switch ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var near: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var press: HayCompressor = await _press_at(-3.0)
	var far: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 8.0))
	var other: HayCompressor = await _press_at(8.0)
	await _settle()
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("two poles 8 m apart make one line", grid.network_count() == 1
		and grid.network_of(near) == grid.network_of(far))
	_check("...the press and the generator hang from the near pole",
		grid.pole_for(press) == near and grid.pole_for(gen) == near)
	_check("...and the other press from the far one", grid.pole_for(other) == far)
	var mine:= grid.pole_switches(near)
	_check("the near pole's own switches are the press alone, no generator (%d)"
		% mine.size(), mine.size() == 1 and mine [0] == press)

	var panel: PolePanel = world.pole_panel
	if panel == null:
		_check("the world built the pole panel", false)
		await _clear_yard()
		return
	panel.open(near)
	_check("it offers to turn off this pole's machines",
		panel._pole_switch.tooltip_text == tr("TURN OFF THIS POLE'S MACHINES")
			and not panel._pole_switch.disabled
			and panel._pole_switch.running)

	panel._on_pole_switch()
	await _settle()
	await _settle()
	_check("one press turns off the near press", press.is_switched_off())
	_check("...leaves the generator and the far press on",
		not gen.is_switched_off() and not other.is_switched_off())
	_check("...so the far press still gets power (%.3f)" % other.power,
		gen.is_burning() and other.power > 0.0)
	_check("...and the plate offers a green TURN ON, with the line still running",
		panel._pole_switch.tooltip_text == tr("TURN ON THIS POLE'S MACHINES")
			and not panel._pole_switch.running
			and panel._switch.tooltip_text == tr("TURN OFF THE WHOLE LINE"))

	panel._on_pole_switch()
	await _settle()
	await _settle()
	_check("a second press turns the near press back on (%.3f)" % press.power,
		not press.is_switched_off() and press.power > 0.0)
	panel.close()

	panel.open(far)
	panel._on_pole_switch()
	_check("the far pole's button stops only the far press",
		other.is_switched_off() and not press.is_switched_off() and not gen.is_switched_off())
	panel._on_pole_switch()
	panel.close()


	await _demolish(press)
	await _settle()
	panel.open(near)
	_check("a pole whose only drop is a generator offers a button that cannot be pressed",
		grid.pole_switches(near).is_empty() and panel._pole_switch.disabled
			and panel._pole_switch.tooltip_text == tr("NOTHING WIRED TO THIS POLE"))
	panel.close()
	await _clear_yard()


func _case_every_machine_says_what_it_makes() -> void:
	print("\n=== every machine says what it makes ===")
	await _clear_yard()
	var at:= Vector3(LANE_X, 0.0, 0.0)
	var made:= {
		"arm": world.builds.add_robotic_arm(at + Vector3(-4, 0, -8), 0.0),
		"scanner": world.builds.add_scanner(at, 0.0),
		"compressor": world.builds.add_compressor(at + Vector3(-4, 0, 4), 0.0),
		"pelletizer": world.builds.add_pelletizer(at + Vector3(-8, 0, 4), 0.0),
		"wrapper": world.builds.add_wrapper(at + Vector3(0, 0, 4), 0.0),
		"generator": world.builds.add_generator(at + Vector3(0, 0, 8), 0.0),
		"rake": world.builds.add_piston_rake(at + Vector3(-4, 0, 8), 0.0),
		"drone": world.builds.add_hay_drone(at + Vector3(-8, 0, 8), 0.0),


		"borehole": world.builds.add_borehole(at + Vector3(9, 0, -8), 0.0),
		"pulper": world.builds.add_pulper(at + Vector3(5, 0, 4), 0.0),


		"paper": world.builds.add_paper(at + Vector3(-8, 0, -8), 0.0),


		"briquette": world.builds.add_briquette(at + Vector3(-18, 0, 10), 0.0),
	}
	await _settle()


	var says:= {
		"arm": "",
		"scanner": "",
		"compressor": "1 bale = %d hay strands" % Tech.compressor_bale_strands(),
		"pelletizer": "1 brick = %d hay strands" % Tech.pellet_brick_strands(),
		"wrapper": "1 wrapped bale = 1 bale",
		"generator": "1 kW = 1 hay strand a second",
		"rake": "",
		"drone": "",


		"borehole": "1 stroke = %.0fl" % (Tech.borehole_output() * 60.0
			/ maxf(Cfg.BOREHOLE_STROKES_PER_MIN, 0.001)),


		"pulper": "1 pulp slab = %d hay strands + %.0fl" % [
			Tech.pulper_batch_strands(), Cfg.PULPER_WATER_LITRES],


		"paper": "1 paper roll = %d pulp slabs" % Cfg.PAPER_SLABS_PER_ROLL,


		"briquette": "1 feed disc = %d hay strands + %d eco bricks (%d strands each)" % [
			Tech.briquette_batch_strands(), Tech.briquette_batch_bricks(),
			Tech.pellet_brick_strands()],
	}
	for id: String in made:


		var machine: Node3D = made [id]
		_check("the yard has a %s to ask" % id, is_instance_valid(machine))
		var line: String = world.hud._machine_product(machine)
		_check("...and it says '%s'" % line, line == str(says [id]))
		_check("...with no money on it", not line.contains("$"))


		_check("...and no kilowatts", not line.contains("kW")
			or id == "generator")
	await _clear_yard()


func _case_one_utility_row() -> void:
	print("\n=== one utility row, and the right one ===")
	await _clear_yard()
	var pulper: HayPulper = world.builds.add_pulper(Vector3(LANE_X, 0.0, 4.0), 0.0)
	await _settle()


	var line: String = world.hud._machine_diagnostic(pulper)
	_check("unwired and unplumbed, it asks for the pole first: %s"
		% line.get_slice("\n", 1),
		line.contains("NOT ON A NETWORK") and line.count("\n") == 1)

	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	line = world.hud._machine_diagnostic(pulper)
	_check("wired, it asks for the pipe: %s" % line.get_slice("\n", 1),
		line.contains("NO PIPE ON IT") and line.count("\n") == 1)


	pulper.set_switched_off(true)
	await _settle()
	line = world.hud._machine_diagnostic(pulper)
	_check("switched off, it says only that: %s" % line.get_slice("\n", 1),
		line.contains("SWITCHED OFF") and line.count("\n") == 1)
	pulper.set_switched_off(false)
	await _clear_yard()


func _case_the_draw_and_the_way_out() -> void:
	print("\n=== the draw, and the way out of a short line ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var rake: PistonRake = world.builds.add_piston_rake(Vector3(LANE_X, 0.0, 4.0), 0.0)
	await _settle()
	var line: String = world.hud._machine_diagnostic(rake)
	_check("a rake on a full line says what it draws: %s" % line.get_slice("\n", 1),
		line.contains("this machine needs %.1f kW" % Tech.rake_draw_kw())
			and not line.contains("getting") and line.count("\n") == 1)
	_check("...and the generator, which draws nothing, gets no such row",
		not world.hud._machine_diagnostic(gen).contains("this machine needs"))
	var pole_line: String = world.hud._machine_diagnostic(pole)
	_check("a healthy pole gives no advice",
		not pole_line.contains("Build") and not pole_line.contains("Feed"))


	gen.fuel = 0.0
	await _settle()
	pole_line = world.hud._machine_diagnostic(pole)
	_check("an empty generator's pole says feed it: %s" % pole_line.get_slice("\n", 2),
		pole_line.contains("Feed your hay generator more hay.")
			and not pole_line.contains("more hay generator"))


	gen.fuel = gen.capacity()
	gen.set_switched_off(true)
	await _settle()
	pole_line = world.hud._machine_diagnostic(pole)
	_check("with the generator switched off the pole gives no advice: %s"
		% pole_line.replace("\n", "  /  "),
		not pole_line.contains("Build") and not pole_line.contains("Feed"))
	gen.set_switched_off(false)
	await _clear_yard()


func _case_a_feeder_slows_like_everything_else() -> void:
	print("\n=== a machine feeding a generator slows like everything else ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()


	var feed:= gen.intake_port() - gen.forward() * 6.0
	feed.y = _deck_y
	var run: Conveyor = world.builds.add_conveyor(feed, gen.intake_port())
	var beside:= (feed + gen.intake_port()) * 0.5
	beside.y = 0.0


	var arm: RoboticArm = world.builds.add_robotic_arm(
		beside + Vector3(-1.6, 0.0, 0.0), 0.0)
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))


	var _near: PowerPole = await _plant(arm.global_position + Vector3(0.0, 0.0, 3.5))

	var press: HayCompressor = await _press_at(-3.0)
	var _second: HayCompressor = await _press_at(0.0)
	var _third: HayCompressor = await _press_at(3.0)
	await _settle()
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("the arm and the presses are one network",
		grid.network_of(arm) >= 0 and grid.network_of(arm) == grid.network_of(press))
	_check("the run hands off to the generator's deck",
		run.downstream == gen.deck())
	_check("the arm is within reach of that run",
		not world.builds.conveyor_drops(arm.global_position, arm.reach_m()).is_empty())
	_check("...and the grid files it as nothing special", not grid.is_feeder(arm))
	var got: Dictionary = grid.report(press)
	_check("the network is short (everything at %d%%)"
		% int(round(float(got ["satisfaction"]) * 100.0)),
		float(got ["satisfaction"]) < 0.9)
	_check("...so the presses were slowed to it (%.3f)" % press.power,
		absf(press.power - float(got ["satisfaction"])) < 0.001)
	_check("...and so was the arm feeding the fire (%.3f)" % arm.power,
		absf(arm.power - float(got ["satisfaction"])) < 0.001)
	_check("...which counts in the demand (%.1f kW)" % float(got ["demand"]),
		absf(float(got ["demand"]) - (Cfg.COMPRESSOR_DRAW_KW * 3.0 + arm.draw_kw())) < 0.01)
	await _clear_yard()


func _case_a_feeder_still_needs_a_wire() -> void:
	print("\n=== a machine feeding a generator still needs a wire ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var feed:= gen.intake_port() - gen.forward() * 6.0
	feed.y = _deck_y
	var run: Conveyor = world.builds.add_conveyor(feed, gen.intake_port())
	var beside:= (feed + gen.intake_port()) * 0.5
	beside.y = 0.0
	var arm: RoboticArm = world.builds.add_robotic_arm(
		beside + Vector3(1.6, 0.0, 0.0), 0.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("the run hands off to the generator's deck", run.downstream == gen.deck())
	_check("with no pole in the yard the arm is on no network",
		grid.network_of(arm) < 0)
	_check("...and it was pushed 0 (%.3f)" % arm.power, arm.power == 0.0)
	_check("...and it says so: %s" % arm.alert_reason(),
		arm.alert_reason().begins_with("NO POWER"))
	_check("...and asks for the bolt", arm.alert_icon() == "power")


	gen.set_switched_off(true)
	var _pole: PowerPole = await _plant(arm.global_position + Vector3(0.0, 0.0, 3.5))
	await _settle()
	await _settle()
	var got: Dictionary = grid.report(arm)
	_check("cabled now, to a network supplying nothing (%.2f kW)" % float(got ["supply"]),
		grid.network_of(arm) >= 0 and float(got ["supply"]) < 0.001)
	_check("...so the arm stands still too (%.3f)" % arm.power, arm.power == 0.0)
	await _clear_yard()


func _case_the_draw_follows_the_model() -> void:
	print("\n=== the arm's draw follows its model ===")
	await _clear_yard()
	var want: Array [float] = [1.5, 2.5, 4.0]
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()


	var arms: Array [RoboticArm] = []
	for tier in Cfg.ROBOT_ARM_TIERS.size():
		arms.append(world.builds.add_robotic_arm(
			Vector3(LANE_X - 1.0, 0.0, -3.5 + 3.5 * tier), 0.0, tier))
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	await _settle()
	var total:= 0.0
	for tier in arms.size():
		var arm:= arms [tier]
		var row: Dictionary = Cfg.ROBOT_ARM_TIERS [tier]
		_check("%s draws %.1f kW" % [str(row ["name"]).to_lower(), want [tier]],
			absf(arm.draw_kw() - want [tier]) < 0.001
				and absf(float(row ["draw_kw"]) - want [tier]) < 0.001)
		total += want [tier]
	var grid: PowerGrid = world.builds.grid
	_check("all three are one network",
		grid.network_of(arms [0]) >= 0
			and grid.network_of(arms [0]) == grid.network_of(arms [1])
			and grid.network_of(arms [0]) == grid.network_of(arms [2]))
	var got: Dictionary = grid.report(arms [0])
	_check("...and the grid sums them to %.1f kW (got %.1f)" % [total, float(got ["demand"])],
		absf(float(got ["demand"]) - total) < 0.01)

	arms [2].set_switched_off(true)
	await _settle()
	_check("a switched-off long arm leaves the budget (%.1f kW)"
		% float(grid.report(arms [0]) ["demand"]),
		absf(float(grid.report(arms [0]) ["demand"]) - (total - want [2])) < 0.01)
	await _clear_yard()


func _case_zero_is_a_stop() -> void:
	print("\n=== zero is a stop, and it says so at once ===")
	var press: HayCompressor = await _press_at(0.0)
	await _settle()
	_check("with no pole in the yard the press was pushed 0", press.power == 0.0)
	var batch:= Tech.compressor_bale_strands()
	press.stored = batch
	for i in 120:
		await get_tree().physics_frame
	_check("...so it does no work: %d strands still in the buffer, nothing pressing"
		% press.stored, press.stored == batch and not press.is_pressing())
	_check("...and it is quiet", press._press_voice < 0)
	_check("it reports the plain fault: %s" % press.alert_reason(),
		press.alert_reason().begins_with("NO POWER"))
	_check("...and asks for the bolt", press.alert_icon() == "power")
	var watch: MachineWatch = world.builds.watch
	watch.force_sweep(0.25)
	_check("MachineWatch raised it on the first poll, with no hold",
		watch.alert_icon(press) == "power" and watch.alert_reason(press) == press.alert_reason())
	await _clear_yard()


func _case_the_sign_is_the_right_sign() -> void:
	print("\n=== the sign is the right sign ===")
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var press: HayCompressor = await _press_at(-3.0)
	await _settle()
	_check("a wired press has full power", is_equal_approx(press.power, 1.0))
	var watch: MachineWatch = world.builds.watch
	press.starved_for = Cfg.MACHINE_STARVED_AFTER
	_check("hungry, it reports hunger: %s" % press.alert_reason(),
		press.alert_reason().begins_with("NO HAY"))
	_check("...and asks for the bang", press.alert_icon() == "")
	watch.force_sweep(0.25)
	_check("a quarter of a second in there is no sign yet", watch.alert_reason(press) == "")
	watch.force_sweep(MachineWatch.HOLD)
	_check("...and after the hold there is, wearing the bang",
		watch.alert_reason(press).begins_with("NO HAY") and watch.alert_icon(press) == "")
	var before: MachineAlert = watch._tracked [press.get_instance_id()] ["sign"]


	world.builds._demolish(pole)
	await _settle()
	_check("with the pole gone the press is at 0", press.power == 0.0)
	watch.force_sweep(0.25)
	var after: MachineAlert = watch._tracked [press.get_instance_id()] ["sign"]
	_check("the words changed to the power fault: %s" % watch.alert_reason(press),
		watch.alert_reason(press).begins_with("NO POWER"))
	_check("...and the SAME sign now wears the bolt, rather than a new one going up",
		after == before and is_instance_valid(after) and watch.alert_icon(press) == "power")
	await _clear_yard()


func _case_the_other_zero() -> void:
	print("\n=== the other zero has its own words ===")
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var press: HayCompressor = await _press_at(-3.0)
	await _settle()
	_check("in the clear the press is wired", world.builds.grid.network_of(press) >= 0)


	var crown:= pole.wire_point()
	var port: Vector3 = (press.power_ports() [0] as Node3D).global_position
	var mid:= (crown + port) * 0.5
	var slab: StaticBody3D = _slab(Vector3(mid.x, 2.0, mid.z), Vector3(0.6, 4.0, 0.6))
	world.builds.changed.emit()
	await _settle()
	_check("with a wall in the way it is not", world.builds.grid.network_of(press) < 0)
	_check("...it is in unreachable()", world.builds.grid.unreachable().has(press))
	_check("...it was told so", press.power_blocked and press.power == 0.0)
	_check("...and it says the other thing: %s" % press.alert_reason(),
		press.alert_reason().begins_with("NO CABLE REACHES THIS"))
	_check("...under a bolt", press.alert_icon() == "power")
	slab.queue_free()
	await _clear_yard()


func _case_the_terminals_are_authored() -> void:
	print("\n=== the terminals are the ones in the models ===")
	var at:= Vector3(LANE_X, 0.0, 0.0)
	var made:= {
		"scanner": world.builds.add_scanner(at, 0.0),
		"wrapper": world.builds.add_wrapper(at + Vector3(0, 0, 4), 0.0),
		"silo": world.builds.add_silo(at + Vector3(0, 0, -5), 0.0),
		"launcher": world.builds.add_tube_launcher(at + Vector3(-4, 0, 0), 0.0),
		"compressor": world.builds.add_compressor(at + Vector3(-4, 0, 4), 0.0),
	}
	await _settle()
	for id: String in made:
		var machine: Node3D = made [id]
		var ports: Array [Node3D] = machine.power_ports()
		var authored:= not ports.is_empty()
		var names:= PackedStringArray()
		for port in ports:
			names.append(port.name)
			if not port.name.begins_with("Marker_WirePort"):
				authored = false
		var want:= 2 if id == "silo" else 1
		_check("the %s carries %d authored terminal%s (%s)" % [id, want,
			"s" if want > 1 else "", ", ".join(names)],
			authored and ports.size() == want)
		for port in ports:
			var up:= port.global_position.y - machine.global_position.y
			_check("...%s ties on %.2f m up, off the floor and under the crown"
				% [port.name, up], up > 0.6 and up < 3.2)


	for id: String in ["arm", "pelletizer", "rake"]:
		var machine: Node3D
		var want:= 2
		match id:
			"arm":
				machine = world.builds.add_robotic_arm(at + Vector3(4, 0, -4), 0.0, 0)
				want = 1
			"pelletizer": machine = world.builds.add_pelletizer(at + Vector3(4, 0, 0), 0.0)
			"rake": machine = world.builds.add_piston_rake(at + Vector3(4, 0, 4), 0.0)
		await _settle()
		var ports: Array [Node3D] = machine.power_ports()
		if id == "arm":


			_check("the arm carries its mast's authored Marker_WirePort (%s)"
				% ", ".join(ports.map(func(p: Node3D) -> String: return p.name)),
				ports.size() == 1 and ports [0].name == "Marker_WirePort")
		else:
			var fittings:= 0
			for port in ports:
				var holder:= port.get_parent() as Node3D
				if holder != null and holder.name.ends_with("Fitting") and holder.find_children("*", "MeshInstance3D", false, false).size() >= 8:
					fittings += 1
			_check("the %s, with no build script, carries %d code-built fitting%s (%d ports, %d fittings)"
				% [id, want, "s" if want > 1 else "", ports.size(), fittings],
				ports.size() == want and fittings == want)
		for port in ports:
			var up:= port.global_position.y - machine.global_position.y

			var lid:= 4.0 if id == "arm" else 3.2
			_check("...%s ties on %.2f m up, on the machine and %s"
				% [port.name, up, "up its mast" if id == "arm" else "under the crown"],
				up > 0.6 and up < lid)
		if id == "arm" and not ports.is_empty():


			var port: Node3D = ports [0]
			var flat:= Vector2(port.global_position.x - machine.global_position.x,
				port.global_position.z - machine.global_position.z).length()
			_check("...the arm's tie-on is over the yaw axis (%.3f m off)" % flat, flat < 0.01)
			var before: Vector3 = port.global_position
			machine._base_yaw.rotation.y += 2.4
			var moved:= before.distance_to(port.global_position)
			_check("...and the arm swinging round moves it %.3f m: the mast turns, the wire stays"
				% moved, moved < PowerLine.MOVE_EPSILON)
	await _clear_yard()


func _case_one_span_per_pole() -> void:
	print("\n=== one span per pole, to the nearest ===")
	var a: PowerPole = await _plant(Vector3(LANE_X, 0.0, 0.0))
	var b: PowerPole = await _plant(Vector3(LANE_X, 0.0, 6.0))
	var c: PowerPole = await _plant(Vector3(LANE_X + 3.0, 0.0, 3.0))
	var grid: PowerGrid = world.builds.grid
	_check("three poles all in reach of each other are one network",
		grid.network_count() == 1)
	_check("...carrying two spans between them, not three (%d)" % _spans(),
		_spans() == 2)
	_check("the third was strung to ONE of the first two, not both (%d)"
		% c.links_to.size(), c.links_to.size() == 1)

	var tool: BuildTool = world.player.build
	var spot:= Vector3(LANE_X + 2.0, 0.0, -2.0)
	var survey: Dictionary = await _survey(tool, spot)
	_check("the ghost near all three draws ONE span (%d)" % (survey ["links"] as Array).size(),
		(survey ["links"] as Array).size() == 1)
	_check("...to the nearest, which is the first pole",
		(survey ["links"] as Array) [0] == a)
	var d: PowerPole = await _plant(spot)
	_check("the placed pole is strung to exactly that one",
		d.links_to.size() == 1 and d.strung_to(a))
	_check("...so the yard carries three spans for four poles (%d)" % _spans(),
		_spans() == 3)


	await _demolish(a)


	_check("with its pole gone the fourth is tied to the line again",
		_tied(d) >= 1)
	_check("...and so is every other survivor",
		_tied(b) >= 1 and _tied(c) >= 1)
	_check("...and the yard is still one network", grid.network_count() == 1)
	_check("...on two spans for three poles, not a triangle (%d)" % _spans(),
		_spans() == 2)
	await _clear_yard()


	print("\n=== a pole in the middle bridges both sides ===")
	var gap:= Cfg.POLE_LINK_R * 2.0 - 2.0
	var west: PowerPole = await _plant(Vector3(LANE_X, 0.0, - gap * 0.5))
	var east: PowerPole = await _plant(Vector3(LANE_X, 0.0, gap * 0.5))
	_check("two poles %.1f m apart are two networks" % gap, grid.network_count() == 2)
	var mid_spot:= Vector3(LANE_X, 0.0, 0.0)
	var promise: Dictionary = await _survey(tool, mid_spot)
	_check("the ghost between them draws TWO spans, one to each side (%d)"
		% (promise ["links"] as Array).size(), (promise ["links"] as Array).size() == 2)
	var bridge: PowerPole = await _plant(mid_spot)
	_check("the bridge is strung to both", bridge.strung_to(west) and bridge.strung_to(east))
	_check("...so the yard is one network", grid.network_count() == 1)
	_check("...on two spans (%d)" % _spans(), _spans() == 2)


	var fourth: PowerPole = await _plant(mid_spot + Vector3(2.0, 0.0, 0.0))
	_check("a fourth beside the bridge gets ONE span, because it is all one line now",
		fourth.links_to.size() == 1 and fourth.strung_to(bridge))
	await _clear_yard()


func _tied(pole: PowerPole) -> int:
	var n:= pole.links_to.size()
	for other in world.builds.power_poles:
		if is_instance_valid(other) and other != pole and other.strung_to(pole):
			n += 1
	return n


func _spans() -> int:
	var n:= 0
	for pole in world.builds.power_poles:
		if is_instance_valid(pole):


			n += pole.wire_count() - _drops(pole)
	return n


func _case_a_rope_falls_once() -> void:
	print("\n=== a rope falls once ===")
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	_check("a pole beside a generator hangs one drop", pole.wires().size() == 1)
	_check("...which is falling, because it is new", not pole.wires() [0].is_asleep())
	await _let_it_fall(pole.wires() [0])
	await _press_at(-3.0)
	await _settle()
	_check("with a press as well it carries two drops (%d)"
		% pole.wires().size(), pole.wires().size() == 2)


	var awake:= 0
	for line in pole.wires():
		if not line.is_asleep():
			awake += 1
		await _let_it_fall(line)
	_check("...and exactly ONE of them fell, the new one (%d awake)" % awake, awake == 1)


	var before:= pole.wires()
	var shape_before: Array [PackedVector3Array] = []
	for line in before:
		shape_before.append(line.points())
	var slab: StaticBody3D = _slab(Vector3(LANE_X - 6.0, 1.0, 6.0), Vector3(1.0, 2.0, 1.0))
	world.builds.changed.emit()
	await _settle()
	var rehung:= pole.wires()
	var asleep:= 0
	var kept:= 0
	var worst:= 0.0
	for k in rehung.size():
		var line:= rehung [k]
		if line.is_asleep():
			asleep += 1
		var was:= before.find(line)
		if was < 0:
			continue
		kept += 1
		for i in PowerLine.POINTS:
			worst = maxf(worst, line.points() [i].distance_to(shape_before [was] [i]))
	_check("after a wall goes up elsewhere the wires are the SAME nodes, kept (%d of %d)"
		% [kept, rehung.size()], rehung.size() == 2 and kept == 2)
	_check("...and every one of them is still asleep (%d of %d)" % [asleep, rehung.size()],
		asleep == rehung.size())
	_check("...and not one point of them moved, %.4f m at worst" % worst, worst < 0.0005)

	var second: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 6.0))
	var fresh: PowerLine = null
	for line in pole.wires():
		if not line.to_anchors.is_empty() and line.to_anchors [0].is_ancestor_of(second) or (not line.to_anchors.is_empty() and second.is_ancestor_of(line.to_anchors [0])):
			fresh = line
	_check("a second pole gets a span from the first", fresh != null)
	if fresh != null:
		_check("...and that one, being new, was awake and falling",
			not fresh.is_asleep() or fresh.points() [7].y < fresh.points() [0].y - 0.01)
		await _let_it_fall(fresh)
		_check("...then slept", fresh.is_asleep())
	slab.queue_free()
	await _clear_yard()


const BOX_LANE:= Vector3(-56.0, 0.0, 17.0)


func _case_a_box_bridges_too() -> void:
	print("\n=== a cable box bridges too ===")
	var grid: PowerGrid = world.builds.grid
	for mix: Array in [["pole", "box", "pole", Cfg.POLE_LINK_R * 2.0 - 2.0],


			["box", "pole", "box", Cfg.BOX_LINK_R * 2.0 - 4.0],
			["box", "box", "box", Cfg.BOX_LINK_R * 2.0 - 4.0]]:
		var gap: float = mix [3]
		var west: PowerPole = await _post(BOX_LANE + Vector3(0.0, 0.0, - gap * 0.5), mix [0] == "box")
		var east: PowerPole = await _post(BOX_LANE + Vector3(0.0, 0.0, gap * 0.5), mix [2] == "box")
		_check("%s and %s %.0f m apart are two networks" % [mix [0], mix [2], gap],
			grid.network_count() == 2)
		var mid: PowerPole = await _post(BOX_LANE, mix [1] == "box")
		_check("a %s between them is strung to both (%d)" % [mix [1], mid.links_to.size()],
			mid.strung_to(west) and mid.strung_to(east))
		_check("...and the yard is one network", grid.network_count() == 1)
		_check("...carrying two runs (%d)" % _spans(), _spans() == 2)
		await _clear_yard()


func _post(at: Vector3, buried: bool) -> PowerPole:
	var pole: PowerPole = world.builds.add_power_pole(at, 0.0, buried)
	await _settle()
	return pole


func _demolish_all_poles() -> void:
	for pole in world.builds.power_poles.duplicate():
		world.builds._demolish(pole)
	await _settle()


func _clear_yard() -> void:
	world.builds.clear()
	await _settle()


func _settle() -> void:
	for i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _survey(tool: BuildTool, at: Vector3) -> Dictionary:
	tool._pole_ghost.global_position = at
	await get_tree().physics_frame
	tool._eval = { "ok": true, "reason": "", "length": 0.0, "cost": Cfg.POLE_COST }
	tool._pole_eval = tool._survey_pole(at)
	return tool._pole_eval


func _status(tool: BuildTool) -> Dictionary:
	return tool.status()


func _drops(pole: PowerPole) -> int:
	var n:= 0
	for line in pole.wires():
		if line.to_anchors.is_empty():
			continue
		var end:= line.to_anchors [0]
		var walk: Node = end
		var on_pole:= false
		while walk != null:
			if walk is PowerPole:
				on_pole = true
				break
			walk = walk.get_parent()
		if not on_pole:
			n += 1
	return n


func _slab(at: Vector3, size: Vector3) -> StaticBody3D:
	var body:= StaticBody3D.new()
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var box:= BoxShape3D.new()
	box.size = size
	var shape:= CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body


func _let_it_fall(line: PowerLine) -> void:
	var waited:= 0.0
	while waited < ROPE_SECONDS and not line.is_asleep():
		await get_tree().process_frame
		waited += get_process_delta_time()


func _anchor(root: Node3D, at: Vector3) -> Node3D:
	var node:= Node3D.new()
	root.add_child(node)
	node.global_position = at
	return node


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _case_a_dead_second_fire() -> void:
	print("\n=== a second fire with an empty box ===")
	await _clear_yard()
	var fed: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	fed.fuel = fed.capacity()
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))


	var press: HayCompressor = await _press_at(-2.0)
	var _second: HayCompressor = await _press_at(1.0)
	await _settle()
	var grid: PowerGrid = world.builds.grid
	var alone: Dictionary = grid.report(press)
	_check("one fed generator carries two presses (%.1f / %.1f kW, %d%%)"
		% [float(alone ["demand"]), float(alone ["supply"]),
			int(round(float(alone ["satisfaction"]) * 100.0))],
		float(alone ["satisfaction"]) > 0.999)

	var cold: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, 5.0), 0.0)
	cold.fuel = 0.0
	await _settle()
	await _settle()
	_check("the cold one joined the same network",
		grid.network_of(cold) >= 0 and grid.network_of(cold) == grid.network_of(fed))
	_check("...it can deliver nothing (%.2f kW)" % cold.deliverable_kw(),
		cold.deliverable_kw() < 0.001)
	_check("...so it is asked for nothing (%.2f kW)" % cold.demand_kw,
		cold.demand_kw < 0.001)
	_check("...and makes nothing (%.2f kW)" % cold.output_kw(),
		cold.output_kw() < 0.001)
	var pair: Dictionary = grid.report(press)
	_check("the fed one still carries the whole load (%.1f kW of %.1f)"
		% [fed.output_kw(), float(pair ["demand"])],
		absf(fed.output_kw() - float(pair ["demand"])) < 0.1)
	_check("...so the yard is still at 100%% (%d%%)"
		% int(round(float(pair ["satisfaction"]) * 100.0)),
		float(pair ["satisfaction"]) > 0.999)
	_check("...and the presses were not slowed (%.3f)" % press.power,
		press.power > 0.999)


	cold.fuel = cold.capacity()
	await _settle()
	var shared: Dictionary = grid.report(press)
	var half:= float(shared ["demand"]) * 0.5
	_check("light the second and the two share the burn (%.2f and %.2f kW, want %.2f each)"
		% [fed.output_kw(), cold.output_kw(), half],
		absf(fed.output_kw() - half) < 0.2 and absf(cold.output_kw() - half) < 0.2)
	_check("...and the yard is still at 100%% (%d%%)"
		% int(round(float(shared ["satisfaction"]) * 100.0)),
		float(shared ["satisfaction"]) > 0.999)
	await _clear_yard()


func _case_a_load_too_big_for_the_box() -> void:
	print("\n=== a load too big for the box ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	await _settle()

	var strands:= int(ceil(gen.capacity() / Cfg.GENERATOR_KJ_PER_STRAND)) + 60
	var worth:= float(strands) * Cfg.GENERATOR_KJ_PER_STRAND * Cfg.GENERATOR_BURN_LOOSE
	_check("a %d strand wad is worth %.0f kJ against a %.0f kJ box"
		% [strands, worth, gen.capacity()], worth > gen.capacity())


	gen.fuel = gen.capacity()
	var wad: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis(), gen.hopper_position()), { "strands": strands })
	for i in 12:
		await get_tree().physics_frame
	_check("with the box full the oversize wad is left alone",
		is_instance_valid(wad) and gen.fuel > gen.capacity() * 0.9)
	_check("...and the machine says why: %s" % gen.alert_reason(),
		gen.alert_reason().begins_with("TOO BIG"))
	_check("...and holds its deck rather than tipping it on the floor",
		gen.deck().is_blocked())


	gen.fuel = 0.0
	for i in 12:
		await get_tree().physics_frame
	_check("with the box empty it goes in", not is_instance_valid(wad))
	_check("...filling the box to the brim (%.0f of %.0f kJ)"
		% [gen.fuel, gen.capacity()], gen.fuel > gen.capacity() * 0.9)
	_check("...the fire is in", gen.is_burning())
	_check("...and the machine has stopped complaining (%s)"
		% ("nothing" if gen.alert_reason() == "" else gen.alert_reason()),
		gen.alert_reason() == "")


	_check("a brimming box still holds its deck, as any full box does",
		gen.deck().is_blocked())
	gen.fuel = gen.capacity() * 0.5
	for i in 4:
		await get_tree().physics_frame
	_check("...and the line runs again once it has burnt down",
		not gen.deck().is_blocked())
	await _clear_yard()


func _case_a_split_to_one_fire() -> void:
	print("\n=== one wye arm into one fire buys the line nothing ===")
	await _clear_yard()
	var wye: ConveyorSplitter = world.builds.add_splitter(
		Vector3(LANE_X, 0.0, 0.0), 0.0)
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.0, 0.0, 6.0), 0.0)
	gen.fuel = gen.capacity()
	var press: HayCompressor = world.builds.add_compressor(
		Vector3(LANE_X, _deck_y, -6.0), 0.0)
	await _settle()
	var into: Conveyor = world.builds.add_conveyor(press.port_out(), wye.port_in())
	var to_fire: Conveyor = world.builds.add_conveyor(wye.port_left(), gen.intake_port())
	var away_dir:= (wye.port_right() - wye.global_position).normalized()
	var _dead_end: Conveyor = world.builds.add_conveyor(
		wye.port_right(), wye.port_right() + away_dir * 3.0)


	for z: float in [-10.0, -13.0, -16.0]:
		var _extra: HayCompressor = await _press_at(z)
	for z: float in [-16.0, -10.0, -4.0, 4.0]:
		var _post: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, z))
	await _settle()
	await _settle()
	var grid: PowerGrid = world.builds.grid
	_check("the press hands to the run into the wye",
		press.deck() != null and press.deck().downstream == into)
	_check("the left arm runs into the fire", to_fire.downstream == gen.deck())
	_check("the press and the generator are one network",
		grid.network_of(press) >= 0
			and grid.network_of(press) == grid.network_of(gen))
	var got: Dictionary = grid.report(press)
	var sat:= float(got ["satisfaction"])
	_check("the line is short (%.1f kW wanted, %.1f made, everything at %d%%)"
		% [float(got ["demand"]), float(got ["supply"]), int(round(sat * 100.0))],
		sat < 0.95)
	for pinned: Array in [[-1, "taking them in turn"],
			[ConveyorSplitter.LEFT, "pinned to the fire"],
			[ConveyorSplitter.RIGHT, "pinned to the dead end"]]:
		wye.set_forced_side(int(pinned [0]))
		await _settle()
		await _settle()
		sat = float(grid.report(press) ["satisfaction"])
		_check("%s: the press is not exempt, it runs at the line's %.3f (%.3f)"
			% [str(pinned [1]), sat, press.power],
			not grid.is_feeder(press) and absf(press.power - sat) < 0.001)
	await _clear_yard()


func _case_a_branch_keeps_its_other_links() -> void:
	print("\n=== a demolished pole leaves every other span standing ===")
	await _clear_yard()
	var grid: PowerGrid = world.builds.grid


	var west: PowerPole = await _plant(Vector3(LANE_X - 2.0, 0.0, -8.0))
	var east: PowerPole = await _plant(Vector3(LANE_X - 2.0, 0.0, 8.0))
	var spare: PowerPole = await _plant(Vector3(LANE_X + 3.0, 0.0, 0.0))
	_check("three posts, none in reach of another: three networks (%d)"
		% grid.network_count(), grid.network_count() == 3)
	var hub: PowerPole = await _plant(Vector3(LANE_X - 2.0, 0.0, 0.0))
	_check("a hub in reach of all three is strung to all three (%d)"
		% hub.links_to.size(), hub.links_to.size() == 3)
	_check("...so the yard is one network", grid.network_count() == 1)

	await _demolish(spare)
	_check("with the spare gone the hub keeps its other two spans (%d)"
		% hub.links_to.size(), hub.links_to.size() == 2)
	_check("...to BOTH of the poles it was bridging",
		hub.strung_to(west) and hub.strung_to(east))
	_check("...so neither end went dark: still one network (%d)"
		% grid.network_count(), grid.network_count() == 1)
	await _clear_yard()


func _case_the_line_is_dark() -> void:
	print("\n=== the third zero, and a fire nobody is drawing on ===")
	await _clear_yard()
	var grid: PowerGrid = world.builds.grid
	var press: HayCompressor = await _press_at(0.0)
	_check("a press with no pole at all is not on a dark line, it is on no line",
		not grid.is_dark(press))
	_check("...so it is told to plant a pole: %s"
		% MachinePower.fault(press.power, press.power_blocked, grid.line_state(press)),
		MachinePower.fault(press.power, press.power_blocked,
			grid.line_state(press)).begins_with("NO POWER  ·  put a power pole"))
	_check("...and its own sign agrees: %s" % press.alert_reason(),
		press.alert_reason().begins_with("NO POWER  ·  put a power pole"))

	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = 0.0
	await _settle()
	_check("an empty generator with no pole is not accused of anything yet",
		not gen.alert_reason().begins_with("NO POLE"))
	gen.fuel = gen.capacity()
	for i in 4:
		await get_tree().physics_frame
	_check("...but one with a fire in it and nowhere to send the power says so: %s"
		% gen.alert_reason(), gen.alert_reason().begins_with("NO POLE"))
	_check("...and asks for the bolt, not the bang", gen.alert_icon() == "power")

	var _pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	await _settle()
	_check("wire it up and it stops saying it (%s)"
		% ("nothing" if gen.alert_reason() == "" else gen.alert_reason()),
		gen.alert_reason() == "")
	_check("the press is running on it (%.3f)" % press.power, press.power > 0.999)
	_check("...and its line is not dark", not grid.is_dark(press))


	gen.fuel = 0.0
	await _settle()
	await _settle()
	_check("burn the box out and the press is at zero (%.3f)" % press.power,
		press.power == 0.0)
	_check("...on a line the grid calls dark", grid.is_dark(press))
	_check("...and the words say to feed the fire: %s"
		% MachinePower.fault(press.power, press.power_blocked, grid.line_state(press)),
		MachinePower.fault(press.power, press.power_blocked, grid.line_state(press))
			== "NO POWER  ·  the generator is out of hay, feed it")


	_check("...and so does the press's own sign: %s" % press.alert_reason(),
		press.alert_reason() == "NO POWER  ·  the generator is out of hay, feed it")


	gen.fuel = gen.capacity()
	gen.set_switched_off(true)
	await _settle()
	await _settle()
	_check("a switched-off generator does not put the line in the dark bucket",
		not grid.is_dark(press))

	_check("...and the press's sign asks for a generator, not hay or a pole: %s"
		% press.alert_reason(), press.alert_reason()
			== "NO POWER  ·  nothing on this line makes power, build a generator or switch one on")
	await _clear_yard()


func _case_a_lorry_is_not_a_wall() -> void:
	print("\n=== a lorry is not a wall ===")
	await _clear_yard()
	var truck: DeliveryTruck = world.truck
	_check("the yard has a lorry", truck != null)
	if truck != null:
		var hull:= truck.find_child("Hull", false, false)
		_check("...and its hull is in the group a cable ignores",
			hull != null and hull.is_in_group(PowerGrid.CABLE_TRANSPARENT))
		_check("...while still standing on the world layer, so it is still solid",
			hull is CollisionObject3D)


	var press: HayCompressor = await _press_at(0.0)
	var slab:= _slab(Vector3(LANE_X + 1.2, 1.6, 0.0), Vector3(0.4, 3.2, 4.0))
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var grid: PowerGrid = world.builds.grid
	_check("a slab between the two cuts the wire", grid.pole_for(press) == null)
	slab.add_to_group(PowerGrid.CABLE_TRANSPARENT)
	world.builds.changed.emit()
	await _settle()
	await _settle()
	_check("...and the same slab in the group does not",
		grid.pole_for(press) == pole)
	_check("...so the press is back on the pole's network",
		grid.network_of(press) >= 0
			and grid.network_of(press) == grid.network_of(pole))
	slab.remove_from_group(PowerGrid.CABLE_TRANSPARENT)
	slab.queue_free()
	await _clear_yard()


func _case_the_ash_out_of_an_old_save() -> void:
	print("\n=== the ash out of a save that had an ash pit ===")
	await _clear_yard()
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	await _settle()
	var heard: Array [int] = []
	var listener:= func(kind: int, _paid: float, _why: int) -> void:
		heard.append(kind)
	GameState.needle_lost.connect(listener)
	gen.adopt_saved_ash(PackedInt32Array([0, 1]))
	_check("the indices are held rather than announced on the spot",
		heard.is_empty() and gen._saved_ash.size() == 2)
	for i in 4:
		await get_tree().physics_frame
	_check("...and go out on the next tick, with somebody listening (%d heard)"
		% heard.size(), heard.size() == 2)
	_check("...leaving nothing behind to announce twice",
		gen._saved_ash.is_empty())
	for i in 8:
		await get_tree().physics_frame
	_check("...and nothing is announced again (%d heard)" % heard.size(),
		heard.size() == 2)
	GameState.needle_lost.disconnect(listener)
	await _clear_yard()
