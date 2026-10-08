class_name DevSiloProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const PATIENCE:= 400


const TEST_STRANDS:= 77

var _pass:= 0
var _fail:= 0


var _out:= 0


var _rode:= 0
var _fell:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var out_port:= Vector3(13.0, deck_y, -1.0)
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(20000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== model ===")
	var tank: HaySilo = world.builds.add_silo(
		out_port - Vector3(0, 0, Cfg.SILO_LENGTH * 0.5), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	_check("model instantiated", tank.get_node_or_null("Model") != null)
	for marker in ["Marker_BeltIn", "Marker_BeltOut", "Marker_DeckStart",
			"Marker_TopFeed", "Marker_Mouth", "Marker_Discharge",
			"Marker_Panel", "Marker_PlayerStand", "Marker_Alert"]:
		_check("marker %s" % marker, tank._find(marker) != null)


	for part: String in [HaySilo.N_ROTOR, HaySilo.N_FAN, HaySilo.N_KNOB,
			HaySilo.N_NEEDLE_RATE, HaySilo.N_NEEDLE_LEVEL, HaySilo.N_COWL]:
		_check("driven part %s" % part, tank._movers.has(part))
	_check("the heap is there", tank._heap != null)
	_check("no clip was exported (the rate would be baked into one)",
		tank._model != null
			and tank._model.find_child("AnimationPlayer", true, false) == null)


	for lamp: String in [HaySilo.MAT_GO, HaySilo.MAT_WARN, HaySilo.MAT_STOP]:
		_check("driven lamp %s resolved" % lamp, tank._lamps.has(lamp))

	print("\n=== the hologram ===")
	var ghost:= HaySilo.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = tank.global_position + Vector3(0, 0, 8.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	var lays: Array [Array] = [
		[tank.to_local(tank.deck_start()), tank.to_local(tank.port_out())],
		[tank.to_local(tank.port_in()), tank.to_local(tank.top_feed())],
	]
	var runs:= ghost.ghost_runs()
	var same:= runs.size() == lays.size()
	for r in mini(runs.size(), lays.size()):
		for end in 2:
			var drawn: Vector3 = runs [r] [end]
			var laid: Vector3 = lays [r] [end]
			same = same and drawn.distance_to(laid) < 0.01
	_check("the ghost draws the floor deck and the feed run, end to end", same)
	_check("...as belt with a rail down each side",
		ghost.find_child("GhostBelt", true, false) is BeltGhost
			and (ghost.find_child("GhostBelt", true, false) as BeltGhost).drawn(BeltGhost.RAIL_L) > 0
			and (ghost.find_child("GhostBelt", true, false) as BeltGhost).drawn(BeltGhost.RAIL_R) > 0)
	_check("...and no chevrons", ghost.find_child("GhostFlow", true, false) == null)
	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_check("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	_check("...and lays no belt path of its own", ghost.deck() == null)
	_check("...and no feed path either", ghost.feed_deck() == null)
	world.remove_child(ghost)
	ghost.queue_free()

	print("\n=== geometry ===")
	_check("outfeed port on the deck plane (%.3f vs %.3f)"
		% [tank.port_out().y, deck_y], absf(tank.port_out().y - deck_y) < 0.02)


	var climb:= tank.port_in().y - tank.port_out().y
	_check("the intake is up in the air (%.2f m over the outfeed)" % climb,
		climb > 4.0)


	var lift_climb:= HayLift.rise_for(3)
	_check("...on a lift's third storey (%.2f m, lift reaches %.2f)"
		% [climb, lift_climb], absf(climb - lift_climb) < 0.01)
	_check("...and it is upstream of the machine",
		(tank.port_in() - tank.global_position).dot(tank.forward()) < -1.0)


	_check("travel is +Z as placed", tank.forward().dot(Vector3.BACK) > 0.99)
	_check("the level run over the mouth is level (%.3f m of fall)"
		% absf(tank.port_in().y - tank.top_feed().y),
		absf(tank.port_in().y - tank.top_feed().y) < 0.02)
	_check("...and it ends over the mouth (%.2f m off the axis)"
		% Vector2(tank.top_feed().x - tank.mouth_position().x,
			tank.top_feed().z - tank.mouth_position().z).length(),
		Vector2(tank.top_feed().x - tank.mouth_position().x,
			tank.top_feed().z - tank.mouth_position().z).length()
			< tank.mouth_radius())
	_check("the discharge is under the star, near the deck (%.2f m up)"
		% (tank.discharge_point().y - tank.port_out().y),
		tank.discharge_point().y - tank.port_out().y < 0.8)

	print("\n=== two decks, and only one of them hands on ===")
	_check("the module lays a floor deck", tank.deck() != null)
	_check("...and a feed run over its mouth", tank.feed_deck() != null)
	_check("the feed run spans the gantry (%.2f m)"
		% tank.port_in().distance_to(tank.top_feed()),
		tank.port_in().distance_to(tank.top_feed()) > 2.0)


	_check("the feed run hands on to NOTHING, so its loads fall in",
		tank.feed_deck() != null and tank.feed_deck().downstream == null)

	print("\n=== it stands on its own base plates ===")
	for foot: String in ["Marker_Foot00", "Marker_Foot01", "Marker_Foot10",
			"Marker_Foot11"]:
		_check("base plate %s" % foot, tank._find(foot) != null)
	tank.refresh_supports()
	for i in 4:
		await get_tree().physics_frame


	var tops:= tank.support_tops()
	_check("four trestles wanted, at the deck's two ends (%d)" % tops.size(),
		tops.size() == 4)
	var high:= 0
	for top: Vector3 in tops:
		if top.y > tank.global_position.y + 1.0:
			high += 1
	_check("...and none of them under the gantry four metres up (%d)" % high,
		high == 0)

	print("\n=== snapping ===")

	for port: Vector3 in [tank.port_in(), tank.port_out()]:
		var near:= port + Vector3(0.35, 0.0, 0.4)
		var snapped: Vector3 = world.builds.snap_endpoint(near)
		_check("a belt end near a port snaps onto it (off by %.3f m)"
			% snapped.distance_to(port), snapped.is_equal_approx(port))
	var far:= tank.port_out() + Vector3(5.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second silo on the same spot is refused",
		world.builds.silo_overlap(tank.global_position))


	_check("a press on the same spot is refused too",
		world.builds.compressor_overlap(tank.global_position))
	_check("...and a wrapper", world.builds.wrapper_overlap(tank.global_position))
	_check("...and a scanner", world.builds.scanner_overlap(tank.global_position))

	await _case_ladder(tank)

	print("\n=== the line runs through it ===")
	var out_end:= tank.port_out() + Vector3(0, 0, 8.0)
	world.builds.add_conveyor(tank.port_out(), out_end)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the floor deck knows what comes after it",
		tank.deck() != null and tank.deck().downstream != null)
	_check("...and the feed run still hands on to nothing",
		tank.feed_deck() != null and tank.feed_deck().downstream == null)


	print("\n=== a load rides in over the top and falls in ===")
	var feed_from:= tank.port_in() - tank.forward() * 6.0
	world.builds.add_conveyor(feed_from, tank.port_in())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var feeder: Conveyor = world.builds.feed_run_into(tank.port_in())
	_check("the run knows the silo comes after it",
		feeder != null and feeder.downstream == tank.feed_deck())
	var far_bale: HayBale = world.props.spawn("hay_bale",
		Transform3D(Basis(), feed_from + tank.forward() * 0.6 + Vector3.UP * 0.08)) as HayBale
	if far_bale != null:
		far_bale.strands = TEST_STRANDS
	var rode:= 0.0
	var stride:= maxf(get_physics_process_delta_time(), 1e-06)
	while rode < 60.0 and tank.queued.is_empty():
		await get_tree().physics_frame
		rode += stride
	_check("a bale laid on the run reached the mouth on its own (%.1f s)" % rode,
		not tank.queued.is_empty())
	_check("...and arrived with its count intact (%d)"
		% (int((tank.queued [0] ["state"] as Dictionary).get("strands", -1))
			if not tank.queued.is_empty() else -1),
		not tank.queued.is_empty()
			and int((tank.queued [0] ["state"] as Dictionary).get("strands", -1))
				== TEST_STRANDS)
	tank.queued.clear()
	_clear_props()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	Tech.grant("belt_speed", TechTree.max_rank("belt_speed"))
	await get_tree().physics_frame
	print("\n=== the dial ===")
	_check("a fresh silo starts off both ends of its range (%.1f)"
		% tank.rate(),
		tank.rate() > tank.rate_min() and tank.rate() < tank.rate_max())
	tank.set_rate(999.0)
	_check("the dial cannot be driven past its ceiling (%.1f, max %.1f)"
		% [tank.rate(), tank.rate_max()],
		is_equal_approx(tank.rate(), tank.rate_max()))
	_check("...and the top notch is the top (%.1f)" % tank.rate_step_up(),
		is_equal_approx(tank.rate_step_up(), tank.rate_max()))
	tank.set_rate(-5.0)
	_check("...nor below its floor (%.1f, min %.1f)"
		% [tank.rate(), tank.rate_min()],
		is_equal_approx(tank.rate(), tank.rate_min()))
	_check("...and the bottom notch is the bottom (%.1f)" % tank.rate_step_down(),
		is_equal_approx(tank.rate_step_down(), tank.rate_min()))
	tank.set_rate(2.0)
	_check("one notch up is one step (%.2f -> %.2f)"
		% [tank.rate(), tank.rate_step_up()],
		is_equal_approx(tank.rate_step_up(), 2.0 + Cfg.SILO_RATE_STEP))


	print("\n=== the console says the setting ===")
	var pane:= tank.get_node_or_null("ReadoutPane") as MeshInstance3D
	_check("the console carries a driven display", pane != null)
	var face:= (pane.material_override if pane != null else null) as ShaderMaterial
	_check("...on the readout material", face != null)


	_check("...standing on the console door (%.3f m off the marker)"
		% (pane.global_position.distance_to(tank.console_position()) if pane != null else -1.0),
		pane != null and pane.global_position.distance_to(tank.console_position()) < 0.06)
	for want: float in [10.0, 180.0, 900.0]:
		tank.set_rate_per_minute(want)

		for k in FactoryClock.stride:
			await get_tree().physics_frame
		var says:= int(HayCompressor.driven(pane, &"value", -1))
		_check("...reading %d when the dial is on %d a minute (%d)"
			% [int(minf(want, tank.rate_max_per_minute())), int(want), says],
			says == int(round(tank.rate_per_minute())))
	tank.set_rate(3.0)


	print("\n=== two silos, one set of materials ===")
	var shared:= HayCompressor.materials_shared()
	var twin: HaySilo = world.builds.add_silo(
		tank.global_position + Vector3(0, 0, -8.0), 0.0)
	tank.set_rate_per_minute(60.0)
	twin.set_rate_per_minute(240.0)
	for i in 4:
		await get_tree().physics_frame
	var worn:= true
	var compared:= 0
	var mine_meshes:= tank._meshes()
	var twin_meshes:= twin._meshes()
	worn = worn and mine_meshes.size() == twin_meshes.size()
	for m in mini(mine_meshes.size(), twin_meshes.size()):
		var a: MeshInstance3D = mine_meshes [m]
		var b: MeshInstance3D = twin_meshes [m]
		if a.mesh == null:
			continue
		for i in a.mesh.get_surface_count():
			var mine:= a.get_surface_override_material(i)
			if mine == null or _is_lamp_slot(tank, a, i):
				continue
			compared += 1
			if (mine == b.get_surface_override_material(i)) != shared:
				worn = false
	_check("the twin wears %s body materials (%d surfaces)"
		% ["the same" if shared else "its own", compared], worn and compared > 0)
	var twin_pane:= twin.get_node_or_null("ReadoutPane") as MeshInstance3D
	_check("...and %s readout material" % ["the same" if shared else "its own"],
		twin_pane != null and pane != null
			and (twin_pane.material_override == pane.material_override) == shared)
	_check("...and %s pane mesh" % ["the same" if shared else "its own"],
		twin_pane != null and pane != null and (twin_pane.mesh == pane.mesh) == shared)
	var twin_says:= int(HayCompressor.driven(twin_pane, &"value", -1))
	_check("each pane says its own silo's number (%d, twin %d)"
		% [int(HayCompressor.driven(pane, &"value", -1)), twin_says],
		int(HayCompressor.driven(pane, &"value", -1)) == 60 and twin_says == 240)
	tank.set_rate_per_minute(120.0)
	for i in 2:
		await get_tree().physics_frame
	_check("...and turning one silo's dial leaves the other's display (%d)"
		% int(HayCompressor.driven(twin_pane, &"value", -1)),
		int(HayCompressor.driven(pane, &"value", -1)) == 120
			and int(HayCompressor.driven(twin_pane, &"value", -1)) == 240)
	_check("...and the material carries no number of its own",
		face != null and face.get_shader_parameter("value") == null)
	tank.stop()
	for i in 2:
		await get_tree().physics_frame
	_check("a stopped silo lights its red lamp and the running twin does not",
		tank.lamp_lit(HaySilo.MAT_STOP) == true and twin.lamp_lit(HaySilo.MAT_STOP) == false)
	_check("...on a different material from the twin's",
		tank.lamp_worn(HaySilo.MAT_STOP) != null
			and tank.lamp_worn(HaySilo.MAT_STOP) != twin.lamp_worn(HaySilo.MAT_STOP))
	_check("...and a lamp in the same state on both is %s material"
		% ("the same" if shared else "its own"),
		tank.lamp_lit(HaySilo.MAT_WARN) == twin.lamp_lit(HaySilo.MAT_WARN)
			and tank.lamp_worn(HaySilo.MAT_WARN) != null
			and (tank.lamp_worn(HaySilo.MAT_WARN) == twin.lamp_worn(HaySilo.MAT_WARN)) == shared)
	tank.start()
	world.builds.demolish(twin)
	tank.set_rate(3.0)


	print("\n=== the dial is set a minute and run a second ===")
	tank.set_rate(2.0)
	_check("the minute reading is sixty times the second one (%.0f)"
		% tank.rate_per_minute(), is_equal_approx(tank.rate_per_minute(), 120.0))
	tank.set_rate_per_minute(90.0)
	_check("...and setting it a minute lands on the second (%.2f)" % tank.rate(),
		is_equal_approx(tank.rate(), 1.5))


	tank.set_rate_per_minute(97.0)
	_check("...snapped to a whole notch (%.0f a minute)" % tank.rate_per_minute(),
		is_equal_approx(tank.rate_per_minute(), 100.0))
	_check("the ceiling is quoted in the same unit (%.0f)"
		% tank.rate_max_per_minute(),
		is_equal_approx(tank.rate_max_per_minute(), tank.rate_max() * 60.0))
	tank.set_rate(3.0)


	print("\n=== the tree raises the ceiling, not the dial ===")
	var ceiling_was:= tank.rate_max()
	var set_was:= tank.rate()
	Tech.grant("silo")
	Tech.grant("silo_rate")
	_check("a rank raised the ceiling (%.1f -> %.1f)"
		% [ceiling_was, tank.rate_max()], tank.rate_max() > ceiling_was)
	_check("...and left the machine where the player set it (%.1f)" % tank.rate(),
		is_equal_approx(tank.rate(), set_was))
	var cap_was:= tank.capacity()
	Tech.grant("silo_capacity")
	_check("a capacity rank makes the vessel bigger (%d -> %d)"
		% [cap_was, tank.capacity()], tank.capacity() > cap_was)
	var bulk_was:= Tech.silo_wad_strands()
	Tech.grant("silo_bulk")
	_check("a bulk rank makes each load of loose hay fuller (%d -> %d)"
		% [bulk_was, Tech.silo_wad_strands()],
		Tech.silo_wad_strands() > bulk_was)

	var step:= maxf(get_physics_process_delta_time(), 1e-06)


	print("\n=== zero is a setting, and it stops the machine ===")
	var running_was:= tank.rate()
	tank.stop()
	_check("the dial reaches zero", is_equal_approx(tank.rate(), 0.0))
	_check("...and the machine says so", not tank.is_running())
	tank.queued.append({ "id": "hay_wad", "state": { "strands": 10 } })
	for i in 4:
		await get_tree().physics_frame
	var shut_turn: float = await _spin_over(tank, 0.4, step)
	_check("...a stopped star stands still with a load in the tank (%.2f deg)"
		% rad_to_deg(shut_turn), shut_turn < 0.01)


	_check("...and a stop on its own raises no fault sign",
		tank.alert_reason() == "")
	var shut_queue:= tank.queued.duplicate(true)
	for i in tank.capacity():
		tank.queued.append({ "id": "hay_wad", "state": { "strands": 10 } })


	_check("...and one that has backed the line up does",
		tank.alert_reason().begins_with("STOPPED"))
	tank.queued = shut_queue
	_check("...and the drive is silent",
		tank._drive_target <= HaySilo.DRIVE_SILENT)
	tank.queued.clear()
	for i in 4:
		await get_tree().physics_frame

	tank.start()
	_check("...and starting goes back to the pace it was on (%.2f)" % tank.rate(),
		is_equal_approx(tank.rate(), running_was))
	_clear_props()


	print("\n=== the power switch ===")
	var pace_was:= tank.rate()
	tank.queued.append({ "id": "hay_wad", "state": { "strands": 10 } })
	var panel:= SiloPanel.new()
	world.add_child(panel)
	panel.open(tank)
	panel._power_switch.pressed.emit()
	_check("the panel's power button switches the silo off", tank.is_switched_off())
	_check("...and leaves the dial where it was (%.2f)" % tank.rate(),
		is_equal_approx(tank.rate(), pace_was))
	_check("...and the machine counts as shut", tank.is_shut())
	_check("...and draws nothing", is_equal_approx(tank.draw_kw(), 0.0))
	_check("...and the panel says so", panel._pill_text.text == tr("SWITCHED OFF"))
	_check("...and its switch in the band reads OFF", not panel._power_switch.running)
	for i in 4:
		await get_tree().physics_frame
	var off_turn: float = await _spin_over(tank, 0.4, step)
	_check("...a switched-off star stands still with a load in the tank (%.2f deg)"
		% rad_to_deg(off_turn), off_turn < 0.01)
	_check("...and the drive is silent", tank._drive_target <= HaySilo.DRIVE_SILENT)
	_check("...and the green lamp is dark and the red one lit",
		tank.lamp_lit(HaySilo.MAT_GO) == false and tank.lamp_lit(HaySilo.MAT_STOP) == true)
	_check("...and it raises no fault sign", tank.alert_reason() == "")
	_check("...and the save remembers it", bool(tank.to_dict().get("off", false)))
	panel._power_switch.pressed.emit()
	_check("pressing it again switches the silo back on", not tank.is_switched_off())
	_check("...and the panel says RUNNING again", panel._pill_text.text == tr("RUNNING"))
	var on_turn: float = await _spin_over(tank, 0.4, step)
	_check("...and the star turns again (%.2f deg)" % rad_to_deg(on_turn),
		on_turn > 0.01)
	panel.close()
	panel.queue_free()
	tank.queued.clear()
	_clear_props()

	print("\n=== the star is the clock ===")


	tank.set_rate(4.0)
	var idle_turn: float = await _spin_over(tank, 0.5, step)
	_check("an empty silo's star stands still (%.2f deg)"
		% rad_to_deg(idle_turn), idle_turn < 0.01)


	tank.stored = Tech.silo_wad_strands() * 400
	tank.set_rate(1.0)
	var slow: float = await _spin_over(tank, 1.0, step)
	tank.set_rate(3.0)
	var fast: float = await _spin_over(tank, 1.0, step)
	_check("a loaded star turns (%.0f deg/s at rate 1)" % rad_to_deg(slow),
		slow > 0.01)
	var ratio:= fast / maxf(slow, 1e-06)
	_check("three times the dial is three times the speed (%.2fx)" % ratio,
		absf(ratio - 3.0) < 0.25)


	var vanes:= slow / tank.vane_pitch()
	_check("a second at rate 1 passes one vane (%.2f)" % vanes,
		absf(vanes - 1.0) < 0.25)

	print("\n=== the fan, the vent and the dials ===")


	var fan:= tank._movers [HaySilo.N_FAN] ["node"] as Node3D
	var rotor:= tank._movers [HaySilo.N_ROTOR] ["node"] as Node3D
	var before_fan:= _x_angle(fan)
	var before_rotor:= _x_angle(rotor)
	for k in FactoryClock.stride:
		await get_tree().physics_frame
	var fan_moved:= absf(wrapf(_x_angle(fan) - before_fan, - PI, PI))
	var rotor_moved:= absf(wrapf(_x_angle(rotor) - before_rotor, - PI, PI))
	_check("the fan outruns the star (%.1fx, want about %.0fx)"
		% [fan_moved / maxf(rotor_moved, 1e-06), HaySilo.FAN_RATIO],
		fan_moved > rotor_moved * 4.0)


	tank.stored = 0
	tank.queued.clear()
	var cowl:= tank._movers [HaySilo.N_COWL] ["node"] as Node3D
	var cowl_from:= _y_angle(cowl)
	var stalled:= 0.0
	while stalled < 0.5:
		await get_tree().physics_frame
		stalled += step
	_check("the vent keeps turning over a stopped machine",
		absf(wrapf(_y_angle(cowl) - cowl_from, - PI, PI)) > 0.05)
	_check("...while the star does not", (await _spin_over(tank, 0.3, step)) < 0.01)


	var needle:= tank._movers [HaySilo.N_NEEDLE_RATE] ["node"] as Node3D
	var knob:= tank._movers [HaySilo.N_KNOB] ["node"] as Node3D
	tank.set_rate(tank.rate_min())
	await get_tree().physics_frame
	var low_needle:= _x_angle(needle)
	var low_knob:= _x_angle(knob)
	tank.set_rate(tank.rate_max())
	await get_tree().physics_frame
	_check("the rate needle moves with the dial",
		absf(wrapf(_x_angle(needle) - low_needle, - PI, PI)) > 0.1)
	_check("...and so does the knob on the door",
		absf(wrapf(_x_angle(knob) - low_knob, - PI, PI)) > 0.1)
	var pegged:= _x_angle(needle)
	var ceiling_before:= tank.rate_max()
	Tech.grant("silo_rate", TechTree.max_rank("silo_rate"))
	await get_tree().physics_frame
	_check("a rank raises the ceiling again (%.0f -> %.0f)"
		% [ceiling_before, tank.rate_max()], tank.rate_max() > ceiling_before)
	_check("...and the needle does not move, because the setting did not",
		absf(wrapf(_x_angle(needle) - pegged, - PI, PI)) < 0.0001)


	_check("full scale is the whole tree (%.0f, ceiling now %.0f)"
		% [HaySilo.scale_top(), tank.rate_max()],
		is_equal_approx(HaySilo.scale_top(), tank.rate_max()))


	var level:= tank._movers [HaySilo.N_NEEDLE_LEVEL] ["node"] as Node3D
	var empty_at:= _x_angle(level)
	tank.queued.clear()
	for i in tank.capacity():
		tank.queued.append({ "id": "hay_wad", "state": { "strands": 10 } })
	await get_tree().physics_frame
	var swing:= absf(wrapf(_x_angle(level) - empty_at, - PI, PI))
	_check("the level needle reads the tank (%.0f deg of swing)"
		% rad_to_deg(swing), swing > 1.0)
	tank.queued.clear()
	_clear_props()

	print("\n=== it lets out what it was set to ===")


	tank.discharged.connect(_on_discharged)
	tank.discharged_record.connect(_on_discharged_record)
	tank.stored = Tech.silo_wad_strands() * 400
	tank.set_rate(3.0)
	var got:= await _count_over(tank, 2.0, step)
	_check("a dial of 3 delivers about 3 a second on a clear deck (%.1f)"
		% (got / 2.0), absf(got / 2.0 - 3.0) < 0.8)
	tank.set_rate(1.0)
	got = await _count_over(tank, 2.0, step)
	_check("...and a dial of 1 delivers about 1 (%.1f)" % (got / 2.0),
		absf(got / 2.0 - 1.0) < 0.5)


	print("\n=== the readout agrees at both ends of the dial ===")
	for want: float in [10.0, 60.0, 300.0]:
		tank.set_rate_per_minute(want)
		_left_clear(tank)


		var listened:= 0.0
		while listened < 26.0:
			await get_tree().physics_frame
			listened += step
			_clear_props()
		var says:= tank.measured_per_minute()
		_check("a dial of %d a minute reads back as %d (%.1f)"
			% [int(want), int(want), says], absf(says - want) <= maxf(want * 0.12, 1.5))


	print("\n=== the dial stops at what the belt can carry ===")
	for motor: int in [0, TechTree.max_rank("belt_speed")]:
		Tech.grant("belt_speed", motor)
		var top:= tank.rate_max_per_minute()
		var belt_takes:= HaySilo.belt_limit() * 60.0
		var tree_sells:= Tech.silo_max_rate() * 60.0
		_check("motor rank %d: the dial stops at the belt or the tree (%.0f a minute, belt %.0f, tree %.0f)"
			% [motor, top, belt_takes, tree_sells],
			top <= minf(belt_takes, tree_sells) + 0.001
				and top > minf(belt_takes, tree_sells) - Cfg.SILO_RATE_STEP_PER_MIN)


		tank.stop()
		var most: float = await _carried_per_minute(tank, belt_takes * 1.25, 20.0, step, true)
		_check("...the belt really carries %.0f a minute, and the dial is not over it"
			% most, top <= most * 1.03)


		if HaySilo.belt_caps_dial():
			_check("...nor set short of it for nothing (%.0f under)" % (most - top),
				top >= most * HaySilo.BELT_HEADROOM - Cfg.SILO_RATE_STEP_PER_MIN - 0.001)

		tank.set_rate(999.0)
		var carried: float = await _carried_per_minute(tank, 0.0, 20.0, step, false)
		_check("...and wound to the top the belt keeps up (%.0f a minute carried, dial %.0f, panel %.0f, power %.2f, blocked %.2f s)"
			% [carried, tank.rate_per_minute(), tank.measured_per_minute(), tank.power, tank.blocked_for],
			carried >= tank.rate_per_minute() * 0.92
				and tank.measured_per_minute() >= tank.rate_per_minute() * 0.92)
	_clear_props()

	print("\n=== loose hay goes out as wads, straw for straw ===")
	tank.stored = Tech.silo_wad_strands() * 6
	tank.queued.clear()
	var straw_in:= tank.stored
	var straw_out:= 0
	tank.set_rate(8.0)
	var drained:= 0.0
	while drained < 12.0 and tank.has_load():
		await get_tree().physics_frame
		drained += step
		straw_out += _drain_wads()
	_check("the vessel emptied (%d straw left)" % tank.stored, not tank.has_load())
	_check("every straw came back out (%d in, %d out)" % [straw_in, straw_out],
		straw_out == straw_in)
	tank.discharged.disconnect(_on_discharged)
	tank.discharged_record.disconnect(_on_discharged_record)
	_clear_props()

	print("\n=== a bale goes in and the same bale comes out ===")
	_drop_bale(tank, TEST_STRANDS)
	var swallowed:= 0.0
	while swallowed < 6.0 and tank.queued.is_empty():
		await get_tree().physics_frame
		swallowed += step
	_check("the mouth swallowed it (%.1f s)" % swallowed, not tank.queued.is_empty())
	_check("...and the heap is showing", tank._heap != null and tank._heap.visible)
	tank.set_rate(8.0)
	var shipped:= 0.0
	while shipped < 8.0 and _bale_count() == 0:
		await get_tree().physics_frame
		shipped += step
	_check("one bale came back out (%d)" % _bale_count(), _bale_count() == 1)


	var bale_bodies:= _bales_in_hand()
	var product: HayBale = bale_bodies [0] if not bale_bodies.is_empty() else null
	_check("...carrying its own count (%d, want %d)"
		% [product.strands if product != null else -1, TEST_STRANDS],
		product != null and product.strands == TEST_STRANDS)
	_check("...and no wad was made out of it (%d)" % _wad_count(),
		_wad_count() == 0)
	_clear_props()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("an empty vessel hides the heap again",
		tank._heap != null and not tank._heap.visible)


	print("\n=== a waiting needle goes out in the next load ===")
	_clear_props()
	tank.stored = 0
	tank.queued.clear()
	tank.pending_needles = PackedInt32Array([21])
	tank.queued.append({ "id": "hay_bale", "state": { "strands": TEST_STRANDS, "needle": 5 } })
	tank.queued.append({ "id": "hay_bale", "state": { "strands": TEST_STRANDS } })
	tank.set_rate(8.0)
	var carried_for:= 0.0
	while carried_for < 10.0 and _bale_count() < 2:
		await get_tree().physics_frame
		carried_for += step

	var out_bales:= _bales_in_hand()
	var first_needle:= (out_bales [0] as HayBale).needle_index if out_bales.size() > 0 else -1
	var second_needle:= (out_bales [1] as HayBale).needle_index if out_bales.size() > 1 else -1
	_check("two bales came out (%d)" % out_bales.size(), out_bales.size() == 2)
	_check("...the one that went in with a needle keeps its own (%d)" % first_needle,
		first_needle == 5)
	_check("...and the waiting needle rides out in the next (%d)" % second_needle,
		second_needle == 21)
	_check("...so the tank is not holding it any more",
		tank.pending_needles.is_empty())
	tank.pending_needles = PackedInt32Array()
	_clear_props()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	print("\n=== backpressure lands on the feed run ===")
	_check("the feed run is open while there is room",
		tank.feed_deck() != null and not tank.feed_deck().is_blocked())
	tank.queued.clear()
	tank.stored = 0


	var rate_was:= tank.rate()


	tank.stop()


	tank.set_physics_process(false)
	var waiter: HayBale = world.props.spawn("hay_bale", Transform3D(Basis(),
		tank.port_in() + tank.forward() * 0.3 + Vector3.UP * 0.08)) as HayBale


	var boarded:= 0.0
	while boarded < 3.0 and not _aboard(tank.feed_deck()):
		await get_tree().physics_frame
		boarded += step
	_check("a load is aboard the feed deck with the tank still empty",
		_aboard(tank.feed_deck()) and not tank.is_full())

	for i in tank.capacity():
		tank.queued.append({ "id": "hay_wad", "state": { "strands": 10 } })
	_check("a full vessel reports full", tank.is_full())


	tank.set_physics_process(true)
	for i in 4:
		await get_tree().physics_frame


	_check("...and closes the run arriving over the top",
		tank.feed_deck() != null and tank.feed_deck().is_blocked())


	_check("...and holds what is already on it, so the loads QUEUE",
		tank.feed_deck() != null and tank.feed_deck()._outlet_held)
	_check("...and leaves the deck underneath running",
		tank.deck() != null and not tank.deck().is_blocked())


	var was_in:= tank.queued.size()
	var waited:= 0.0
	while waited < 8.0:
		await get_tree().physics_frame
		waited += step
	_check("the load already on the deck of a FULL silo is not swallowed (%d -> %d)"
		% [was_in, tank.queued.size()], tank.queued.size() == was_in)
	_check("...it waits on the belt instead", _aboard(tank.feed_deck()))
	if is_instance_valid(waiter):
		world.props.remove(waiter)
	_clear_all_records()
	tank.set_rate(rate_was)

	tank.queued.clear()
	for i in 4:
		await get_tree().physics_frame
	_check("...and opens it again when it drains",
		tank.feed_deck() != null and not tank.feed_deck().is_blocked())
	_check("...both of them",
		tank.feed_deck() != null and not tank.feed_deck()._outlet_held)
	_clear_props()

	print("\n=== a blocked outfeed holds rather than stacking ===")


	var blocker: Carryable = world.props.spawn("hay_bale",
		Transform3D(Basis(), tank.discharge_point())) as Carryable
	if blocker != null:
		blocker.freeze = true
	tank.stored = Tech.silo_wad_strands() * 4
	tank.set_rate(8.0)
	var held:= 0.0
	while held < 6.0:
		await get_tree().physics_frame
		held += step
	_check("nothing new is set down on a blocked outfeed (%d wads)"
		% _wad_count(), _wad_count() == 0)
	_check("...and the machine still has its hay (%d straw)" % tank.stored,
		tank.stored >= Tech.silo_wad_strands() * 4)
	_check("...and the star kept turning, which is what a rotary valve does",
		(await _spin_over(tank, 0.3, step)) > 0.01)
	_check("...and it says why", tank.alert_reason().begins_with("OUTFEED BLOCKED"))
	if blocker != null:
		world.props.remove(blocker)
	var freed:= 0.0
	while freed < 6.0 and _wad_count() == 0:
		await get_tree().physics_frame
		freed += step
	_check("...and it ships the moment the deck clears (%d)" % _wad_count(),
		_wad_count() > 0)
	_clear_props()

	print("\n=== save ===")
	tank.queued.clear()
	tank.stored = 55
	tank.queued.append({ "id": "hay_bale", "state": { "strands": 41 } })
	tank.queued.append({ "id": "hay_bale", "state": { "strands": 62 } })
	tank.set_rate(2.0)
	var port_was:= tank.port_in()
	var row:= tank.to_dict()
	_check("the save names the type", row.get("type", "") == "hay_silo")


	_check("the save carries the dial (%.1f)" % float(row.get("rate", -1.0)),
		is_equal_approx(float(row.get("rate", -1.0)), 2.0))
	var rows: Array = world.builds.to_array()
	world.builds.from_array(rows)


	var back: HaySilo = world.builds.silos [0] if not world.builds.silos.is_empty() else null
	_check("the silo came back", back != null)
	_check("...still set where the player left it (%.1f)"
		% (back.rate() if back != null else -1.0),
		back != null and is_equal_approx(back.rate(), 2.0))
	_check("...with its loose hay (%d)" % (back.stored if back != null else -1),
		back != null and back.stored == 55)


	var first:= -1
	var count:= 0
	if back != null:
		count = back.queued.size()
		if count > 0:
			first = int((back.queued [0] ["state"] as Dictionary).get("strands", -1))
	_check("...holding both bales still (%d)" % count, count == 2)
	_check("...and 41 is still first, not 62 (%d)" % first, first == 41)
	_check("...and its ports where they were",
		back != null and back.port_in().distance_to(port_was) < 0.02)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_ladder(tank: HaySilo) -> void:
	print("\n=== the ladder up to the deck ===")
	for marker: String in [HaySilo.N_LADDER_FOOT, HaySilo.N_LADDER_TOP]:
		_check("marker %s" % marker, tank._find(marker) != null)
	_check("the machine offers a ladder", tank.has_ladder())
	_check("...and hangs a reach volume in front of the rungs",
		tank._climb_area != null)
	var stand:= tank.ladder_stand_point()
	var face:= tank.ladder_face()
	var grating:= tank.to_global(tank._marker_local(
		HaySilo.N_LADDER_TOP, HaySilo.F_LADDER_TOP)).y
	_check("its foot is down on the concrete (%.2f m up)" % tank.ladder_foot_y(),
		tank.ladder_foot_y() < 0.2)
	_check("...and the climb runs a step PAST the grating (%.2f m)"
		% (tank.ladder_top_y() - grating),
		tank.ladder_top_y() - grating > 0.2)


	var ball:= SphereShape3D.new()
	ball.radius = 0.34
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = Cfg.L_BUILD


	var fouled:= ""
	for h: float in [0.6, 1.6, 2.6, 3.6, 4.6, 5.4]:
		q.transform = Transform3D(Basis(), Vector3(stand.x, h, stand.z))
		for hit: Dictionary in tank.get_world_3d().direct_space_state.intersect_shape(q, 4):
			fouled += " %s at %.1f m" % [str((hit ["collider"] as Node).name), h]
	_check("a climber's capsule stands clear of the machine's own steel%s"
		% fouled, fouled == "")


	var exit:= tank.ladder_exit_point()
	_check("...and the exit point is inboard of the rungs (%.2f m)"
		% (stand - exit).dot(face), (stand - exit).dot(face) > 0.6)

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(stand.x, 0.1, stand.z)


	player.set_look(atan2(face.x, face.z), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("standing at the foot of it finds the ladder",
		player.get("_ladder") == tank)

	Input.action_press("move_forward")
	_check("holding forward takes them off the floor",
		await _wait_until(func() -> bool: return player.global_position.y > 1.5))


	var topped:= await _wait_until(func() -> bool:
		return player.global_position.y > grating and not bool(player.get("_climbing")))
	Input.action_release("move_forward")
	_check("...and carries them over the lip and off the rungs (%.2f m of %.2f m)"
		% [player.global_position.y, grating], topped)
	for i in 40:
		await get_tree().physics_frame


	_check("letting go at the top leaves them ON the grating (feet at %.2f m of %.2f m)"
		% [player.global_position.y, grating],
		absf(player.global_position.y - grating) < 0.2)
	_check("...with something under their feet", player.is_on_floor())
	_check("...and inboard of the rungs they came up",
		(stand - player.global_position).dot(face) > 0.3)


	player.set_look(atan2(- face.x, - face.z), 0.0)
	for i in 10:
		await get_tree().physics_frame
	_check("...and they are OFF the rungs, standing", not bool(player.get("_climbing")))
	Input.action_press("move_forward")
	_check("walking off the edge puts them back on the rungs",
		await _wait_until(func() -> bool: return bool(player.get("_climbing"))))


	for i in 40:
		await get_tree().physics_frame
	_check("...and the key that took them there does not climb them back up (%.2f m)"
		% (player.global_position.y - grating),
		player.global_position.y < grating + 0.05)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var rode:= await _wait_until(func() -> bool:
		return player.global_position.y < grating - 2.0)
	_check("back walks them down it", rode)


	_check("...on the ladder, not off it", bool(player.get("_climbing")))
	var landed:= await _wait_until(func() -> bool:
		return player.global_position.y < tank.ladder_foot_y() + 0.3)
	Input.action_release("move_back")
	_check("...and it carries them all the way back to the concrete (%.2f m)"
		% player.global_position.y, landed)


	Input.action_press("jump")
	for i in 10:
		await get_tree().physics_frame
	Input.action_release("jump")
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(10.5, 0.4, 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


func _wait_until(test: Callable) -> bool:
	for i in PATIENCE:
		if bool(test.call()):
			return true
		await get_tree().physics_frame
	return false


func _on_discharged(_item: Carryable) -> void:
	_out += 1


func _left_clear(tank: HaySilo) -> void:
	tank._left_at.clear()


func _x_angle(node: Node3D) -> float:
	var b:= node.transform.basis
	return atan2(b.y.z, b.y.y)


func _y_angle(node: Node3D) -> float:
	var b:= node.transform.basis
	return atan2(- b.x.z, b.x.x)


func _spin_over(tank: HaySilo, seconds: float, step: float) -> float:
	var last:= tank._spin
	var turned:= 0.0
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += step
		turned += absf(wrapf(tank._spin - last, - PI, PI))
		last = tank._spin
	return turned


func _count_over(tank: HaySilo, seconds: float, step: float) -> float:
	_out = 0
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += step
		_clear_props()
	return float(_out)


func _carried_per_minute(tank: HaySilo, per_minute: float, seconds: float,
		step: float, by_hand: bool) -> float:
	_clear_props()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	tank.queued.clear()
	tank.stored = Tech.silo_wad_strands() * 400
	_left_clear(tank)
	_out = 0
	_rode = 0
	_fell = 0
	var owed:= 0.0
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += step
		if by_hand:
			owed = minf(owed + per_minute / 60.0 * step, 2.0)
			while owed >= 1.0 and tank._discharge():
				owed -= 1.0
		_clear_ridden_off(tank)


	return float(_rode) * 60.0 / maxf(seconds - 1.5 / maxf(Tech.belt_speed(), 0.01), 1.0)


func _clear_ridden_off(tank: HaySilo) -> void:
	var at:= tank.discharge_point()
	var run:= (tank.port_out() - tank.deck_start()).normalized()
	for item in world.props.items.duplicate():
		if not is_instance_valid(item):
			continue
		var p: Vector3 = (item as Node3D).global_position


		if p.y < tank.port_out().y - 0.3:
			_fell += 1
			world.props.remove(item)
		elif (p - at).dot(run) > 1.5:
			_rode += 1
			world.props.remove(item)


	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var prun: BeltRun = path.run
		var i:= prun.first() + prun.count() - 1
		while i >= prun.first():
			if (prun.pose_of(i).origin - at).dot(run) > 1.5:
				_rode += 1
				var was_head:= i == prun.first()
				prun.remove_at(i)
				if was_head:
					break
			i -= 1


func _drop_bale(tank: HaySilo, strands: int) -> void:
	var bale: HayBale = world.props.spawn("hay_bale",
		Transform3D(Basis(), tank.mouth_position())) as HayBale
	if bale != null:
		bale.strands = strands


func _bales() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayBale:
			out.append(item)
	return out


func _wads() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayWad:
			out.append(item)
	return out


func _clear_props() -> void:
	for item in world.props.items.duplicate():
		if is_instance_valid(item):
			world.props.remove(item)
	_clear_all_records()


func _on_discharged_record(_seq: int) -> void:
	_out += 1


func _records_of(id: String) -> Array:
	var out: Array = []
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
				out.append([path, i])
	return out


func _count(id: String) -> int:
	var n:= 0
	for item in world.props.items:
		if is_instance_valid(item) and item.is_inside_tree() and item.item_id == id:
			n += 1
	return n + _records_of(id).size()


func _wad_count() -> int:
	return _count("hay_wad")


func _bale_count() -> int:
	return _count("hay_bale")


func _drain_wads() -> int:
	var strands:= 0
	for wad in _wads():
		strands += (wad as HayWad).hay_strands()
		world.props.remove(wad)
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		var i:= run.first() + run.count() - 1
		while i >= run.first():
			if run.kind_of(i) == BeltRun.Kind.WAD:
				strands += run.strands_of(i)


				var was_head:= i == run.first()
				run.remove_at(i)
				if was_head:
					break
			i -= 1
	return strands


func _bales_in_hand() -> Array:
	for pair: Array in _records_of("hay_bale"):
		var path: BeltPath = pair [0]
		var where:= BeltPath.record_where(path.run.seq_of(int(pair [1])))
		if not where.is_empty():
			(where ["path"] as BeltPath).materialize_record(int(where ["row"]))
	return _bales()


func _aboard(path: BeltPath) -> bool:
	return path != null and (not path.riders().is_empty() or path.run.count() > 0)


func _clear_all_records() -> void:
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		while run.count() > 0:
			run.remove_at(run.first() + run.count() - 1)


func _is_lamp_slot(tank: HaySilo, mesh: MeshInstance3D, surface: int) -> bool:
	for key: String in tank._lamps:
		for slot: Array in tank._lamps [key]:
			if slot [0] == mesh and slot [1] == surface:
				return true
	return false


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
