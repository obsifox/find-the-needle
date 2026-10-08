class_name DevWaterProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const REBUILD_FRAMES:= 8


const LANE_X:= 13.0

var _pass:= 0
var _fail:= 0


var _lane_y:= Cfg.PIPE_RUN_HEIGHT


class Sink extends BoreholePump:


	var wants:= 8.0

	var got:= 1.0


	var plumbed:= true

	func water_lps() -> float:
		return 0.0

	func water_draw_lps() -> float:
		return 0.0 if switched_off else wants

	func set_water(f: float) -> void:
		got = f

	func set_water_blocked(b: bool) -> void:
		plumbed = not b


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	_lane_y = _ground_at(-12.0) + Cfg.PIPE_RUN_HEIGHT
	print("[water] the lane runs at y %.3f" % _lane_y)

	await _case_the_meter()
	await _case_one_network()
	await _case_two_networks()
	await _case_the_wye()
	await _case_two_wyes_bolted()
	await _case_a_pump_and_a_sink()
	await _case_a_gas_plant()
	await _case_across_networks()
	await _case_a_brownout()
	await _case_nothing_plumbed()
	await _case_a_run_taken_up()
	await _case_a_switch()
	await _case_the_window()
	await _case_the_sound()
	await _case_a_save_round_trip()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_meter() -> void:
	print("\n=== the meter ===")
	var net: WaterGrid = world.builds.water
	_check("the yard has a water grid", net != null)
	_check("...and this run keeps it metered", net != null and not net.unmetered)


	_check("...while the electricity is not, so no generator is needed here",
		world.builds.grid.unmetered)
	_check("an empty yard has no water networks", net.network_count() == 0)


func _case_one_network() -> void:
	print("\n=== two runs that touch ===")
	var net: WaterGrid = world.builds.water
	var first:= await _lay(_at(0.0), _at(6.0))
	_check("one run is one network", net.network_count() == 1)

	var second:= await _lay(_at(6.0), _at(12.0))
	_check("a run laid off the end of it is the same network",
		net.network_count() == 1)
	_check("...and both runs say so",
		net.network_of(first) >= 0 and net.network_of(first) == net.network_of(second))
	_check("...and the network holds both", net.mains_of(first).size() == 2)


	var nudged:= _at(12.0) + Vector3(Cfg.PIPE_JOIN_TOLERANCE * 0.5, 0.0, 0.0)
	var third:= await _lay(nudged, _at(18.0))
	_check("a joint half a tolerance out still holds (%.4f m)"
		% Cfg.PIPE_JOIN_TOLERANCE, net.network_count() == 1
		and net.network_of(third) == net.network_of(first))


	var wide:= _at(18.0) + Vector3(Cfg.PIPE_JOIN_TOLERANCE * 20.0, 0.0, 0.0)
	var fourth:= await _lay(wide, wide + Vector3(0.0, 0.0, 6.0))
	_check("a joint twenty tolerances out does not",
		net.network_of(fourth) != net.network_of(third))
	await _clear_yard()


func _case_two_networks() -> void:
	print("\n=== two runs that do not ===")
	var net: WaterGrid = world.builds.water
	var here:= await _lay(_at(0.0), _at(6.0))
	var far:= await _lay(_at(20.0), _at(26.0))
	_check("two runs that do not touch are two networks",
		net.network_count() == 2)
	_check("...and they are not the same one",
		net.network_of(here) != net.network_of(far))
	_check("a run reports the network it is on",
		bool(net.report(here) ["connected"]))


	var bridge:= await _lay(_at(6.0), _at(20.0))
	_check("a run laid between them joins the two into one",
		net.network_count() == 1 and net.network_of(here) == net.network_of(far))
	_check("...and the bridge is on it", net.network_of(bridge) == net.network_of(here))
	await _clear_yard()


func _case_the_wye() -> void:
	print("\n=== a wye ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 8.0)
	var wye: WaterSplitter = world.builds.add_water_splitter(_at(0.0), 0.0)
	await _settle()


	var feed:= await _lay(pump.water_port(), wye.port_in())
	var left:= await _lay(wye.port_left(), sink.water_port())
	var spur:= await _lay(wye.port_right(), _at(6.0) + Vector3(3.0, 0.0, 0.0))


	_check("three runs on three mouths are ONE network (%d)" % net.network_count(),
		net.network_count() == 1)
	_check("...and all three say so",
		net.network_of(feed) >= 0 and net.network_of(feed) == net.network_of(left)
		and net.network_of(left) == net.network_of(spur))


	var got:= net.report(sink)
	_check("the sink is on a network", bool(got ["connected"]))
	_check("...the same one the pump is on",
		net.network_of(pump) >= 0 and net.network_of(pump) == net.network_of(sink))
	_check("...supply crossed the wye (%.1f l/s)" % float(got ["supply"]),
		absf(float(got ["supply"]) - Tech.borehole_output()) < 0.01)
	_check("...and the machine is running (%.2f)" % sink.got,
		absf(sink.got - 1.0) < 0.001)


	_check("the wye is not itself on a network", net.network_of(wye) < 0)
	var loose_names: Array = []
	for machine: Node3D in net.unplumbed():
		loose_names.append(machine.name)
	_check("...and it is not reported unplumbed (%s)" % str(loose_names),
		not net.unplumbed().has(wye))


	world.builds.demolish(wye)
	await _settle()
	_check("taking the wye up leaves three networks (%d)" % net.network_count(),
		net.network_count() == 3)
	_check("...and the sink is off the pump's",
		net.network_of(sink) != net.network_of(pump))
	_check("...and it is pushed nothing (%.2f)" % sink.got,
		absf(sink.got) < 0.001)
	await _remove_sink(sink)
	await _clear_yard()


func _case_two_wyes_bolted() -> void:
	print("\n=== two wyes bolted face to face ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 8.0)
	var first: WaterSplitter = world.builds.add_water_splitter(_at(-1.0), 0.0)
	await _settle()


	var flange:= first.port_left()
	var away:= first.water_port_bearing(first.water_ports() [1])
	var second: WaterSplitter = world.builds.add_water_splitter(
		flange + away * Cfg.PIPE_SPLITTER_PORT_R, atan2(away.x, away.z))
	await _settle()
	_check("the second's inlet is on the first's outlet (off by %.4f m)"
		% second.port_in().distance_to(flange),
		second.port_in().distance_to(flange) <= Cfg.PIPE_JOIN_TOLERANCE)

	var feed:= await _lay(pump.water_port(), first.port_in())
	var out:= await _lay(second.port_right(), sink.water_port())
	_check("pipe into one wye and out of the other is ONE network",
		net.network_of(feed) >= 0 and net.network_of(feed) == net.network_of(out))
	var got:= net.report(sink)
	_check("...the sink is on the pump's network",
		net.network_of(pump) >= 0 and net.network_of(pump) == net.network_of(sink))
	_check("...water crossed both castings (%.1f l/s)" % float(got ["supply"]),
		absf(float(got ["supply"]) - Tech.borehole_output()) < 0.01)
	_check("...and the machine is running (%.2f)" % sink.got,
		absf(sink.got - 1.0) < 0.001)

	world.builds.demolish(second)
	await _settle()
	_check("taking the second wye up leaves the sink dry (%.2f)" % sink.got,
		net.network_of(sink) != net.network_of(pump) and absf(sink.got) < 0.001)
	await _remove_sink(sink)
	await _clear_yard()


func _case_a_pump_and_a_sink() -> void:
	print("\n=== a pump and a sink ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 8.0)
	_check("the pump makes %.1f litres a second" % pump.water_lps(),
		absf(pump.water_lps() - Tech.borehole_output()) < 0.01)


	var run:= await _lay(pump.water_port(), sink.water_port())
	var got:= net.report(sink)
	_check("the sink is on a network", bool(got ["connected"]))
	_check("...the pump is on the same one",
		net.network_of(pump) >= 0 and net.network_of(pump) == net.network_of(sink))
	_check("...supply is the pump's output (%.1f l/s)" % float(got ["supply"]),
		absf(float(got ["supply"]) - Tech.borehole_output()) < 0.01)
	_check("...demand is what the sink asked for (%.1f l/s)" % float(got ["demand"]),
		absf(float(got ["demand"]) - 8.0) < 0.01)
	_check("...and with slack in it, everything runs at full speed",
		absf(float(got ["satisfaction"]) - 1.0) < 0.001 and absf(sink.got - 1.0) < 0.001)
	_check("the grid knows which run lands on the sink",
		net.main_for(sink) == run)
	_check("...and which flange it lands on",
		net.port_for(sink) == sink.water_ports() [0])
	_check("...and the run knows both machines are on it",
		net.served_by(run).size() == 2)
	_check("nothing is unplumbed", net.unplumbed().is_empty())
	_check("...so the sink was told it is plumbed in", sink.plumbed)
	await _clear_yard()


func _case_a_gas_plant() -> void:
	print("\n=== a gas plant on the main ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var plant: GasPlant = world.builds.add_gas_plant(Vector3(LANE_X, 0.0, 6.0), 0.0)
	await _settle()
	var _run:= await _lay(pump.water_port(), plant.water_port())
	_check("the plant is gathered as a water machine", net.machines().has(plant))
	_check("...on the pump's network",
		net.network_of(plant) >= 0 and net.network_of(plant) == net.network_of(pump))
	_check("...plumbed, not blocked", not plant.water_blocked and net.unplumbed().is_empty())
	_check("with its tank full and its engine cold it asks for nothing (%.2f l/s)"
		% plant.water_draw_lps(), plant.water_draw_lps() == 0.0)
	plant.tank = plant.tank_capacity() * 0.5
	for i in 4:
		await get_tree().physics_frame
	var got:= net.report(plant)
	var rating:= Tech.gas_plant_output() * Cfg.GAS_PLANT_LPS_PER_KW
	_check("topping its tank up it asks for its rating, %.1f l/s (%.2f)"
		% [rating, float(got ["demand"])], absf(float(got ["demand"]) - rating) < 0.01)
	_check("...and with a pump behind it the water comes (%.2f)" % plant.water,
		plant.water > 0.999)
	var filled:= false
	for i in 60 * 40:
		await get_tree().physics_frame
		if plant.tank >= plant.tank_capacity() - 0.01:
			filled = true
			break
	_check("...and the tank fills (%.1f of %.1f l)" % [plant.tank, plant.tank_capacity()], filled)
	await _clear_yard()


func _case_across_networks() -> void:
	print("\n=== a pump does not water another network ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var near:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 6.0)
	var away:= await _add_sink(Vector3(LANE_X + 9.0, 0.0, 8.0), 6.0)
	await _lay(pump.water_port(), near.water_port())

	await _lay(away.water_port(), away.water_port() + Vector3(0.0, 0.0, -5.0))

	_check("both sinks are plumbed to something",
		near.plumbed and away.plumbed)
	_check("...but not to each other",
		net.network_of(near) != net.network_of(away))
	_check("the one on the pump's network runs (%.2f)" % near.got,
		absf(near.got - 1.0) < 0.001)


	_check("the one on its own network gets nothing (%.2f)" % away.got,
		is_zero_approx(away.got))
	_check("...and it is NOT reported as unplumbed, because it is plumbed",
		away.plumbed and not net.unplumbed().has(away))
	_check("...its network has supply zero and demand six",
		is_zero_approx(float(net.report(away) ["supply"]))
		and absf(float(net.report(away) ["demand"]) - 6.0) < 0.01)
	await _clear_yard()


func _case_a_brownout() -> void:
	print("\n=== a brownout ===")
	var net: WaterGrid = world.builds.water
	var supply:= Tech.borehole_output()
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))


	var want:= supply * 0.75
	var one:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), want)
	var two:= await _add_sink(Vector3(LANE_X + 9.0, 0.0, 8.0), want)


	var knee:= _at(0.0)
	await _lay(pump.water_port(), knee)
	await _lay(knee, one.water_port())
	await _lay(knee, two.water_port())

	var got:= net.report(one)
	var expect:= supply / (want * 2.0)
	_check("all three are one network", net.network_count() == 1
		and int(got ["machines"]) == 3)
	_check("demand is %.1f against a supply of %.1f"
		% [float(got ["demand"]), float(got ["supply"])],
		absf(float(got ["demand"]) - want * 2.0) < 0.01)
	_check("satisfaction is supply over demand (%.3f, wanted %.3f)"
		% [float(got ["satisfaction"]), expect],
		absf(float(got ["satisfaction"]) - expect) < 0.001)


	_check("...and BOTH sinks were pushed it (%.3f and %.3f)" % [one.got, two.got],
		absf(one.got - expect) < 0.001 and absf(two.got - expect) < 0.001)


	one.wants = 0.0
	await _settle()
	_check("with one of them idle the other runs at full speed (%.2f)" % two.got,
		absf(two.got - 1.0) < 0.001)
	_check("...and nothing drawing is not a brownout",
		absf(float(net.report(two) ["satisfaction"]) - 1.0) < 0.001)
	await _clear_yard()


func _case_nothing_plumbed() -> void:
	print("\n=== nothing plumbed ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 8.0)
	_check("a machine with no pipe on it is on no network",
		not bool(net.report(sink) ["connected"]))
	_check("...it turns up in unplumbed()", net.unplumbed().has(sink)
		and net.unplumbed().has(pump))
	_check("...it was told so, which is not the same as being told zero",
		not sink.plumbed)
	_check("...and it gets nothing (%.2f)" % sink.got, is_zero_approx(sink.got))
	_check("everything zeroes out for a machine on no network",
		is_zero_approx(float(net.report(sink) ["supply"]))
		and is_zero_approx(float(net.report(sink) ["demand"])))


	await _lay(pump.water_port(), sink.water_port())
	_check("laying a run onto the flange plumbs it in", sink.plumbed
		and bool(net.report(sink) ["connected"]))
	_check("...and unplumbed() is empty again", net.unplumbed().is_empty())
	await _clear_yard()


func _case_a_run_taken_up() -> void:
	print("\n=== a run taken up ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 8.0)
	var knee:= _at(0.0)
	await _lay(pump.water_port(), knee)
	var second:= await _lay(knee, sink.water_port())
	_check("the pump and the sink are one network",
		net.network_count() == 1 and net.network_of(pump) == net.network_of(sink))
	_check("...and the sink is running", absf(sink.got - 1.0) < 0.001)

	world.builds.demolish(second)
	await _settle()
	_check("taking the second run up disconnects the sink",
		not bool(net.report(sink) ["connected"]))
	_check("...it is unplumbed again", not sink.plumbed and net.unplumbed().has(sink))
	_check("...and it gets nothing (%.2f)" % sink.got, is_zero_approx(sink.got))


	_check("the pump is still on the run it kept",
		bool(net.report(pump) ["connected"]) and net.network_count() == 1)
	await _clear_yard()


func _case_a_switch() -> void:
	print("\n=== the switch ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), 8.0)
	var run:= await _lay(pump.water_port(), sink.water_port())
	_check("the sink runs while the pump does", absf(sink.got - 1.0) < 0.001)


	pump.set_switched_off(true)
	await _settle()
	_check("switching the pump off empties the network (%.1f l/s)"
		% float(net.report(sink) ["supply"]),
		is_zero_approx(float(net.report(sink) ["supply"])))
	_check("...so the sink stands still (%.2f)" % sink.got, is_zero_approx(sink.got))
	_check("...and the window goes still with it (%.2f)" % run.flow,
		is_zero_approx(run.flow))
	_check("...but it is still plumbed in, which is the whole difference",
		sink.plumbed and bool(net.report(sink) ["connected"]))

	pump.set_switched_off(false)
	await _settle()
	_check("switching it back on fills the network again",
		absf(sink.got - 1.0) < 0.001 and absf(run.flow - 1.0) < 0.001)
	await _clear_yard()


func _case_the_window() -> void:
	print("\n=== the window ===")
	var net: WaterGrid = world.builds.water


	var dry:= await _lay(_at(0.0), _at(6.0))
	_check("a run with nothing on it is satisfied",
		absf(float(net.report(dry) ["satisfaction"]) - 1.0) < 0.001)
	_check("...and is still empty, because the window is not the gauge (%.2f)"
		% dry.flow, is_zero_approx(dry.flow))

	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var run:= await _lay(pump.water_port(), _at(-4.0))
	_check("a run off a working pump is full (%.2f)" % run.flow,
		absf(run.flow - 1.0) < 0.001)
	_check("...and the flow reached the run's own material",
		absf(_flow_of(run) - 1.0) < 0.001)


	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 4.0), Tech.borehole_output() * 2.0)
	var second:= await _lay(_at(-4.0), sink.water_port())
	_check("...and under a brownout it crawls at the fraction (%.2f)" % run.flow,
		absf(run.flow - 0.5) < 0.01)


	_check("...on the run at the far end of the network too (%.2f)" % second.flow,
		absf(_flow_of(second) - 0.5) < 0.01)
	_check("...while the run on nobody's network is still empty (%.2f)" % dry.flow,
		is_zero_approx(dry.flow))
	await _clear_yard()


func _case_the_sound() -> void:
	print("\n=== the sound of a network ===")
	var audio: WaterAudio = world.water_audio
	_check("the yard built a WaterAudio", audio != null)
	if audio == null:
		return
	_check("the loop is in the library", Audio.LOOP_LIB.has("water_flow"))
	_check("...and its file is on disk",
		ResourceLoader.exists(str(Audio.LOOP_LIB.get("water_flow", ""))))

	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	await _lay(pump.water_port(), _at(-4.0))
	var middle:= await _lay(_at(-4.0), _at(0.0))
	await _lay(_at(0.0), _at(4.0))
	await _lay(_at(4.0), _at(8.0))
	_check("four runs off one well make one network",
		world.builds.water.network_count() == 1)
	_check("...carrying water (%.2f)" % middle.flow, middle.flow > 0.9)

	player.global_position = _at(0.0) + Vector3(1.6, -0.1, 0.0)
	await _listen()
	_check("...heard ONCE and not four times (%d voice)" % audio._voice.size(),
		audio._voice.size() == 1)


	var handle: int = audio._voice.values() [0]
	var emitter: Vector3 = Audio._loops [handle].global_position
	_check("...from the nearest point of pipe, %.2f m off the ear"
		% emitter.distance_to(player.eye_position()),
		emitter.distance_to(player.eye_position()) < 3.0)


	player.global_position = _at(0.0) + Vector3(WaterAudio.RANGE + 12.0, -0.1, 0.0)
	await _listen()
	await _listen()
	_check("walking away hands the voice back (%d held)" % audio._voice.size(),
		audio._voice.is_empty())


	await _clear_yard()
	var dry:= await _lay(_at(0.0), _at(6.0))
	player.global_position = _at(3.0) + Vector3(1.6, -0.1, 0.0)
	await _listen()
	_check("an empty run is silent and holds nothing (flow %.2f, %d voices)"
		% [dry.flow, audio._voice.size()], audio._voice.is_empty())


	await _clear_yard()
	await _listen()
	_check("a demolished network leaves no voice behind (%d held)"
		% audio._voice.size(), audio._voice.is_empty())
	_check("...and the pool came back whole (%d of %d)"
		% [Audio.loops_available(), Audio.POOL_LOOP],
		Audio.loops_available() == Audio.POOL_LOOP)


func _listen() -> void:
	for i in 90:
		await get_tree().process_frame


func _case_a_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	var net: WaterGrid = world.builds.water
	var pump:= await _add_pump(Vector3(LANE_X, 0.0, -8.0))
	var sink:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), Tech.borehole_output() * 2.0)
	var flange:= pump.water_port()
	var knee:= _at(0.0)
	await _lay(flange, knee)
	await _lay(knee, sink.water_port())
	var before:= float(net.report(sink) ["satisfaction"])
	_check("the yard is browned out before the save (%.2f)" % before,
		absf(before - 0.5) < 0.01)

	await _remove_sink(sink)
	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	_check("the yard is empty after a clear",
		world.builds.water_mains.is_empty() and net.network_count() == 0)

	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()
	_check("two runs and a pump came back", world.builds.water_mains.size() == 2
		and world.builds.boreholes.size() == 1)
	var back: BoreholePump = world.builds.boreholes [0]
	_check("...as one network", net.network_count() == 1)
	_check("...with the pump plumbed onto it", bool(net.report(back) ["connected"]))
	_check("...supplying what it did (%.1f l/s)"
		% float(net.report(back) ["supply"]),
		absf(float(net.report(back) ["supply"]) - Tech.borehole_output()) < 0.01)
	_check("...and the mains full again",
		absf(world.builds.water_mains [0].flow - 1.0) < 0.001)


	var again:= await _add_sink(Vector3(LANE_X, 0.0, 8.0), Tech.borehole_output() * 2.0)
	_check("standing the sink back on the end of the run plumbs it in again",
		again.plumbed and bool(net.report(again) ["connected"]))
	_check("...and it browns out exactly as it did before the save (%.2f)"
		% float(net.report(again) ["satisfaction"]),
		absf(float(net.report(again) ["satisfaction"]) - before) < 0.01)
	await _clear_yard()


func _flow_of(run: WaterMain) -> float:
	var water:= run.find_child("Water", true, false) as MeshInstance3D
	if water == null:
		return -1.0
	var mat:= water.material_override as ShaderMaterial
	if mat == null:
		return -1.0
	return float(mat.get_shader_parameter("flow"))


func _add_pump(at: Vector3) -> BoreholePump:
	var pump: BoreholePump = world.builds.add_borehole(at, 0.0)
	await _settle()
	return pump


func _add_sink(at: Vector3, wants: float) -> Sink:
	var sink:= Sink.new()
	sink.name = "WaterSink%d" % world.builds.boreholes.size()
	sink.wants = wants
	sink.setup(at, 0.0)
	world.builds.boreholes.append(sink)
	world.builds.add_child(sink)
	world.builds.changed.emit()
	await _settle()
	return sink


func _remove_sink(sink: Sink) -> void:
	world.builds.boreholes.erase(sink)
	world.builds.remove_child(sink)
	sink.queue_free()
	world.builds.changed.emit()
	await _settle()


func _ground_probe(x: float, z: float) -> float:
	var from:= Vector3(x, 2.5, z)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
	q.collision_mask = Cfg.L_WORLD
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	return 0.0 if hit.is_empty() else float((hit ["position"] as Vector3).y)


func _ground_at(z: float) -> float:
	return _ground_probe(LANE_X, z)


func _at(z: float) -> Vector3:
	return Vector3(LANE_X, _lane_y, z)


func _lay(from: Vector3, to: Vector3) -> WaterMain:
	var run: WaterMain = world.builds.add_water_main(from, to)
	await _settle()
	return run


func _clear_yard() -> void:
	world.builds.clear()
	await _settle()


func _settle() -> void:
	for i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
