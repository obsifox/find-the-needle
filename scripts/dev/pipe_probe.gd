class_name DevPipeProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const REBUILD_FRAMES:= 8

const LANE_X:= 13.0

var _pass:= 0
var _fail:= 0


var _lane_y:= Cfg.PIPE_RUN_HEIGHT


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	Tech.grant("steel_saving", 0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	_lane_y = _ground_at(-12.0) + Cfg.PIPE_RUN_HEIGHT
	print("[pipe] the lane runs at y %.3f" % _lane_y)

	await _case_the_kit()
	await _case_a_straight_run()
	await _case_the_trestles()
	await _case_a_belt_underneath()
	await _case_the_window()
	await _case_a_corner()
	await _case_a_slope()
	await _case_a_hairpin()
	await _case_a_flange()
	await _case_square_onto_a_flange()
	await _case_the_wye()
	await _case_the_wye_snapping()
	await _case_a_wye_onto_a_wye()
	await _case_the_money()
	await _case_a_save_round_trip()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_kit() -> void:
	print("\n=== the kit ===")
	var parts:= {
		"Pipe_Section": [PipeKit.section_mesh(), 4],
		"Pipe_Window": [PipeKit.window_mesh(), 5],
		"Pipe_Water": [PipeKit.water_mesh(), 1],
		"Pipe_Saddle": [PipeKit.saddle_mesh(), 2],
		"Pipe_Leg": [PipeKit.leg_mesh(), 1],
		"Pipe_Foot": [PipeKit.foot_mesh(), 1],
	}
	for id: String in parts:
		var mesh: ArrayMesh = parts [id] [0]
		_check("the kit ships %s" % id, mesh != null)
		if mesh == null:
			continue


		_check("...with its %d surfaces" % int(parts [id] [1]),
			mesh.get_surface_count() == int(parts [id] [1]))


	var dressed:= true
	for id: String in ["Pipe_Section", "Pipe_Window", "Pipe_Saddle"]:
		var mesh: ArrayMesh = parts [id] [0]
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m:= mesh.surface_get_material(i)
			if m == null or not (m is ShaderMaterial or m is StandardMaterial3D):
				dressed = false
	_check("every surface was rebuilt from the material table", dressed)


	var water: ArrayMesh = parts ["Pipe_Water"] [0]
	var wm: ShaderMaterial = null if water == null else water.surface_get_material(0) as ShaderMaterial
	_check("the water column wears a shader", wm != null)
	if wm != null:
		_check("...and it is water_flow.gdshader",
			wm.shader != null and wm.shader.resource_path == PipeKit.FLOW_SHADER)


	var one:= PipeKit.make_flow_material()
	var two:= PipeKit.make_flow_material()
	_check("every run gets a flow material of its own", one != two)


	var flats: Dictionary = PipeKit.spec_table().get("flats", { })
	_check("the table carries M_WP_Water", flats.has(PipeKit.MAT_WATER))
	if flats.has(PipeKit.MAT_WATER):
		var d: Dictionary = flats [PipeKit.MAT_WATER]
		for key: String in ["still", "color", "foam", "foam_share"]:
			_check("...with its %s" % key, d.has(key))


func _case_a_straight_run() -> void:
	print("\n=== a straight run ===")
	var run:= await _lay(_at(0.0), _at(9.0))
	_check("the run knows its length (%.2f m)" % run.length,
		absf(run.length - 9.0) < 0.01)
	_check("...and its heading", run.forward.dot(Vector3.BACK) > 0.99)
	_check("...with no bend on it", is_zero_approx(run.bend_tangent))
	_check("...so the laid line is two points", run.centreline().size() == 2)

	var sections:= run.find_child("Sections", true, false) as MultiMeshInstance3D
	_check("the pipe is drawn as a MultiMesh", sections != null)
	if sections != null:


		_check("...nine metres is nine sections (%d + a window)"
			% sections.multimesh.instance_count,
			sections.multimesh.instance_count == 8)

	var bodies:= run.find_children("*", "StaticBody3D", true, false)
	_check("the run is solid (%d bodies)" % bodies.size(), bodies.size() >= 1)
	var on_build:= true
	for node in bodies:
		if (node as StaticBody3D).collision_layer != Cfg.L_BUILD:
			on_build = false
	_check("...on L_BUILD with everything else the player placed", on_build)


	_check("the crosshair resolves a body back to the run",
		bodies.is_empty() or world.builds.owner_of(bodies [0]) == run)
	_check("...and names it the way the catalogue does",
		world.builds.name_of(run) == BuildCatalog.display_name("pipe"))
	await _clear_yard()


	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)


	var clear_y:= _ground_probe(LANE_X, -30.0) + Cfg.PIPE_RUN_HEIGHT
	var clear_from:= Vector3(LANE_X, clear_y, -30.0)
	var clear_to:= Vector3(LANE_X, clear_y, -24.0)
	var eval: Dictionary = tool._evaluate_pipe(clear_from, clear_to, true)
	_check("the build tool would lay a run on clear ground ('%s')"
		% str(eval ["reason"]), bool(eval ["ok"]))
	_check("...and quotes the run's own price ($%.2f)" % float(eval ["cost"]),
		absf(float(eval ["cost"]) - WaterMain.cost_for(clear_from, clear_to)) < 0.01)


	var blocker: BoreholePump = world.builds.add_borehole(
		Vector3(LANE_X, clear_y - Cfg.PIPE_RUN_HEIGHT, -27.0), 0.0)
	await _settle()
	var into: Dictionary = tool._evaluate_pipe(clear_from, clear_to, true)
	_check("...and refuses one run straight through a machine ('%s')"
		% str(into ["reason"]), not bool(into ["ok"]))
	world.builds.demolish(blocker)
	await _clear_yard()


func _case_the_trestles() -> void:
	print("\n=== the trestles ===")
	var run:= await _lay(_at(0.0), _at(12.0))
	var stations:= run.support_stations()
	_check("a twelve metre run grows trestles (%d)" % stations.size(),
		stations.size() >= 4)


	var bell:= _socket_span()
	_check("the socket is measurable on the section (%.3f..%.3f)"
		% [bell.x, bell.y], bell.y > bell.x)
	var on_barrel:= true
	var worst:= 0.0
	for s: float in stations:
		var i:= _nearest_section(run, s)
		if i < 0:
			continue
		var pitch: float = run.section_pitches [i]
		var local: float = s - run.section_stations [i]


		if local - PipeKit.CLAMP_HALF < bell.y * pitch and local + PipeKit.CLAMP_HALF > bell.x * pitch:
			on_barrel = false
			worst = local
	_check("no clamp overlaps a socket (worst station %.3f into its metre)"
		% worst, on_barrel)


	var even:= true
	for i in range(1, stations.size()):
		var gap: float = stations [i] - stations [i - 1]
		if absf(gap - Cfg.PIPE_SUPPORT_SPACING) > 0.05:
			even = false
	_check("...and the pitch is still %.1f m after the slide"
		% Cfg.PIPE_SUPPORT_SPACING, even)

	var saddles:= run.find_child("Saddles", true, false) as MultiMeshInstance3D
	var legs:= run.find_child("Legs", true, false) as MultiMeshInstance3D
	var feet:= run.find_child("Feet", true, false) as MultiMeshInstance3D
	_check("a station is a saddle, a leg and a foot",
		saddles != null and legs != null and feet != null)
	if saddles != null and legs != null and feet != null:
		_check("...one of each, %d saddles / %d legs / %d feet"
			% [saddles.multimesh.instance_count, legs.multimesh.instance_count,
				feet.multimesh.instance_count],
			saddles.multimesh.instance_count == legs.multimesh.instance_count
			and legs.multimesh.instance_count == feet.multimesh.instance_count)


		_check("...one post per station, not the belt's pair",
			legs.multimesh.instance_count == stations.size())
	await _clear_yard()


func _case_a_belt_underneath() -> void:
	print("\n=== a belt underneath ===")


	var ground:= _ground_probe(LANE_X, -26.0)
	var up:= Vector3(0.0, 2.0, 0.0)
	var from:= Vector3(LANE_X, ground + Cfg.PIPE_RUN_HEIGHT, -30.0)
	var run:= await _lay(from + up, from + up + Vector3(0.0, 0.0, 9.0))
	var wanted:= run.support_stations()
	var target: float = wanted [int(wanted.size() * 0.5)]
	_check("before the belt, the middle trestle stands where it was wanted (%.2f)"
		% target, _has_station(run.placed_stations, target))

	var cross: Vector3 = run.laid_start() + run.forward * target
	var belt: Conveyor = world.builds.add_conveyor(
		Vector3(LANE_X - 3.0, from.y, cross.z), Vector3(LANE_X + 3.0, from.y, cross.z))
	await _settle()

	var placed:= run.placed_stations
	var clear:= true
	var nearest:= INF
	for s: float in placed:
		var z: float = (run.laid_start() + run.forward * s).z

		if absf(z - cross.z) < Cfg.BELT_WIDTH * 0.5 + WaterMain.BELT_CLEAR:
			clear = false
		nearest = minf(nearest, absf(s - target))
	_check("with a belt laid under it, no trestle stands on the belt", clear)
	_check("...the one that was there moved beside it (%.2f m away)" % nearest,
		nearest > 0.01 and nearest <= Cfg.PIPE_SUPPORT_SPACING * 0.5)
	_check("...rather than going missing (%d of %d)" % [placed.size(), wanted.size()],
		placed.size() == wanted.size())
	var legs:= run.find_child("Legs", true, false) as MultiMeshInstance3D
	_check("...and every placed station grew its leg",
		legs != null and legs.multimesh.instance_count == placed.size())

	world.builds.demolish(belt)
	await _settle()
	_check("with the belt taken up, the trestle goes back where it was wanted",
		_has_station(run.placed_stations, target))
	await _clear_yard()


func _has_station(stations: Array [float], s: float) -> bool:
	for got: float in stations:
		if absf(got - s) < 0.01:
			return true
	return false


func _case_the_window() -> void:
	print("\n=== the window ===")
	for metres: float in [3.0, 9.0, 20.0]:
		var run:= await _lay(_at(0.0), _at(metres))
		var win:= run.find_child("Window", true, false) as MultiMeshInstance3D
		_check("a %.0f m run has exactly one window" % metres,
			win != null and win.multimesh.instance_count == 1)
		var water:= run.find_child("Water", true, false) as MeshInstance3D
		_check("...with a column of water in it", water != null)
		if water != null:


			var i:= _nearest_section(run, run.centreline_length() * 0.5)
			var want: Vector3 = run.laid_start() + run.forward * run.section_stations [i]
			_check("...standing in the glass (off by %.3f m)"
				% water.global_position.distance_to(want),
				water.global_position.distance_to(want) < 0.02)
		await _clear_yard()


	var run:= await _lay(_at(0.0), _at(9.0))
	run.set_flow(0.6)
	var water:= run.find_child("Water", true, false) as MeshInstance3D
	var mat: ShaderMaterial = null if water == null else water.material_override as ShaderMaterial
	_check("the run's own material carries the flow", mat != null
		and absf(float(mat.get_shader_parameter("flow")) - 0.6) < 0.001)

	var dry:= await _lay(_at(-4.0), _at(-1.0))
	_check("a fresh run starts empty", is_zero_approx(dry.flow))
	await _clear_yard()


func _case_a_corner() -> void:
	print("\n=== a corner ===")
	var first:= await _lay(_at(0.0), _at(8.0))
	var knee:= _at(8.0)
	var second:= await _lay(knee, knee + Vector3(6.0, 0.0, 0.0))


	_check("the incoming run grew a bend (%.2f m tangent)" % first.bend_tangent,
		first.bend_tangent > 0.05)
	_check("...aimed at the run it bends into",
		first.bend_out.dot(second.forward) > 0.99)
	_check("...and the outgoing run was trimmed to match (%.2f m)"
		% second.trim_start, absf(second.trim_start - first.bend_tangent) < 0.001)
	_check("the bend is drawn as a polyline", first.centreline().size() > 3)


	var line:= first.centreline()
	var leaves:= (line [1] - line [0]).normalized()
	var arrives:= (line [line.size() - 1] - line [line.size() - 2]).normalized()
	_check("...leaving along the run it came from (%.3f)" % leaves.dot(first.forward),
		leaves.dot(first.forward) > 0.9)
	_check("...and arriving along the run it goes to (%.3f)"
		% arrives.dot(second.forward), arrives.dot(second.forward) > 0.9)


	var past:= false
	var total: float = first.centreline_length()
	for s: float in first.support_stations():
		if s < -0.01 or s > total + 0.01:
			past = true
	_check("no trestle stands off the end of the laid run", not past)


	world.builds.demolish(second)
	await _settle()
	_check("taking the second run up straightens the first",
		is_zero_approx(first.bend_tangent))
	_check("...back to two points", first.centreline().size() == 2)


	var straight:= await _lay(_at(8.0), _at(14.0))
	_check("two runs in line are butted, not filleted",
		is_zero_approx(first.bend_tangent) and is_zero_approx(straight.trim_start))
	await _clear_yard()


func _case_a_slope() -> void:
	print("\n=== up a slope ===")
	var low:= _at(0.0)
	var high:= _at(8.0) + Vector3(0.0, 3.0, 0.0)
	var run:= await _lay(low, high)
	_check("a climbing run keeps its two ends", run.a.is_equal_approx(low)
		and run.b.is_equal_approx(high))
	_check("...and its length is the slope, not the plan (%.2f m)" % run.length,
		absf(run.length - low.distance_to(high)) < 0.01)
	var legs:= run.find_child("Legs", true, false) as MultiMeshInstance3D
	_check("...and it still grows trestles", legs != null)


	var over:= Cfg.BELT_MAX_SLOPE + 0.2
	var rise:= tan(over) * 6.0
	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)
	var eval: Dictionary = tool._evaluate_pipe(_at(0.0),
		_at(6.0) + Vector3(0.0, rise, 0.0), true)
	_check("a run steeper than the belt's limit is refused: '%s'"
		% str(eval ["reason"]), not bool(eval ["ok"]))
	await _clear_yard()


func _case_a_hairpin() -> void:
	print("\n=== a hairpin ===")
	await _lay(_at(0.0), _at(8.0))
	var knee:= _at(8.0)
	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)
	var refusal:= tool.tr("turn further off the pipe")

	var back: Dictionary = tool._evaluate_pipe(knee,
		knee + Vector3(0.6, 1.2, -3.0), true)
	_check("a run climbing back over the main it leaves is refused: '%s'"
		% str(back ["reason"]), str(back ["reason"]) == refusal)
	var square: Dictionary = tool._evaluate_pipe(knee,
		knee + Vector3(6.0, 0.0, 0.0), true)
	_check("...where a square turn off the same joint is not: '%s'"
		% str(square ["reason"]), str(square ["reason"]) != refusal)


	var onto: Dictionary = tool._evaluate_pipe(
		_at(4.0) + Vector3(0.5, 1.0, 0.0), _at(0.0), true)
	_check("a run arriving back along a main's end is refused: '%s'"
		% str(onto ["reason"]), str(onto ["reason"]) == refusal)
	await _clear_yard()


func _case_a_flange() -> void:
	print("\n=== onto a flange ===")
	var pump: BoreholePump = world.builds.add_borehole(Vector3(LANE_X, 0.0, -6.0), 0.0)
	await _settle()
	var flange:= pump.water_port()


	var near:= flange + Vector3(0.35, 0.05, 0.2)
	var snapped: Vector3 = world.builds.snap_water_endpoint(near)
	_check("an endpoint near the flange snaps onto it (off by %.4f m)"
		% snapped.distance_to(flange), snapped.distance_to(flange) < 0.001)
	var far:= flange + Vector3(4.0, 0.0, 0.0)
	_check("...and one nowhere near it is left where it was",
		world.builds.snap_water_endpoint(far).is_equal_approx(far))

	_check("nothing is on the flange yet", not world.builds.water_port_taken(flange))
	var run:= await _lay(flange, flange + Vector3(0.0, 0.0, -6.0))
	_check("a run may be laid off it", run != null)
	_check("...and then the flange is taken",
		world.builds.water_port_taken(flange))


	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)
	var eval: Dictionary = tool._evaluate_pipe(flange,
		flange + Vector3(6.0, 0.0, 0.0), true)
	_check("a second run on the same flange is refused: '%s'" % str(eval ["reason"]),
		not bool(eval ["ok"]) and str(eval ["reason"]).contains("flange"))


	tool._state = BuildTool.State.RUNNING
	tool._chain_on(flange, true)
	_check("a line that ends on a flange stops there",
		tool._state == BuildTool.State.AIMING)
	var stub:= flange + Vector3(1.6, 0.0, 0.0)
	tool._eval = tool._evaluate_pipe(flange, stub, false)
	_check("...the aim still on it is told the pipe is connected, not refused",
		tool._finished_here(flange))
	tool._eval = tool._evaluate_pipe(far, far + Vector3(1.6, 0.0, 0.0), false)
	_check("...and it lets go once the aim is somewhere else",
		not tool._finished_here(far) and tool._finished_at == Vector3.INF)
	tool._eval = tool._evaluate_pipe(flange, stub, false)
	_check("...so coming back to the flange later gets the ordinary refusal",
		not tool._finished_here(flange))
	tool._state = BuildTool.State.RUNNING
	tool._chain_on(far, false)
	_check("a line ending in open ground chains on",
		tool._state == BuildTool.State.RUNNING and tool._anchor.is_equal_approx(far))
	tool.cancel()


	_check("...but a run END is not a taken port, so a run may branch off it",
		not world.builds.water_port_taken(run.b))


	_check("the flange sits at a run's own height (%.3f m against %.3f)"
		% [flange.y, Cfg.PIPE_RUN_HEIGHT],
		absf(flange.y - Cfg.PIPE_RUN_HEIGHT) < 0.02)
	await _clear_yard()


func _case_square_onto_a_flange() -> void:
	print("\n=== square onto a flange ===")
	var pulper: HayPulper = world.builds.add_pulper(Vector3(LANE_X, _lane_y, -4.0), 0.0)
	await _settle()
	var flange:= pulper.water_port()
	var bearing: Vector3 = world.builds.water_port_bearing_at(flange)


	_check("the pulper's flange looks out of its -X flank (%s)" % bearing,
		bearing.is_equal_approx(Vector3.LEFT))
	_check("...and a point off the flange has no bearing",
		world.builds.water_port_bearing_at(flange + Vector3(0.0, 0.0, 2.0)) == Vector3.ZERO)

	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)


	var from:= Vector3(flange.x - 5.0, _lane_y, flange.z + 5.0)
	var points: PackedVector3Array = tool._pipe_knees(from, flange)
	var knee:= flange + bearing * Cfg.PIPE_PORT_STUB
	_check("a run coming in at an angle gets a knee a stub out from the flange",
		points [2].is_equal_approx(knee) and points [3].is_equal_approx(flange))
	_check("...and none at its open end", points [1].is_equal_approx(from))
	var on_axis:= flange + bearing * 4.0
	_check("a run already on the axis is laid whole",
		tool._pipe_knees(on_axis, flange) [2].is_equal_approx(flange))
	var short:= flange + bearing * 1.2 + Vector3(0.0, 0.0, 0.8)
	_check("a run too short to keep a piece behind the stub is laid whole",
		tool._pipe_knees(short, flange) [2].is_equal_approx(flange))

	var away:= Vector3(flange.x - 5.0, _lane_y, flange.z - 5.0)
	_check("a run leaving a flange at an angle gets its knee at the start",
		tool._pipe_knees(flange, away) [1].is_equal_approx(knee))


	tool._state = BuildTool.State.RUNNING
	var preview: PackedVector3Array = tool._pipe_preview_points(from, flange)
	_check("the hologram bends at the knee (%d points)" % preview.size(), preview.size() > 4)
	var arrives:= (preview [preview.size() - 1] - preview [preview.size() - 2]).normalized()
	_check("...and arrives along the flange's axis (%.3f)" % arrives.dot(- bearing),
		arrives.dot(- bearing) > 0.999)
	var eval: Dictionary = tool._evaluate_pipe(from, flange, true)
	tool.cancel()


	var before: int = world.builds.water_mains.size()
	tool._lay_pipe(from, flange)
	await _settle()
	var laid: Array = world.builds.water_mains.slice(before)
	_check("the click lays two runs (%d)" % laid.size(), laid.size() == 2)
	if laid.size() == 2:
		var leg: WaterMain = laid [0]
		var stub: WaterMain = laid [1]
		_check("the stub ends on the flange, and takes it",
			stub.b.is_equal_approx(flange) and world.builds.water_port_taken(flange))
		_check("...runs along the flange's axis (%.3f)" % stub.forward.dot(- bearing),
			stub.forward.dot(- bearing) > 0.999)
		_check("...and is level with it", absf(stub.a.y - flange.y) < 0.0001)
		_check("the leg bends into the stub (%.2f m tangent)" % leg.bend_tangent,
			leg.bend_tangent > 0.05 and absf(stub.trim_start - leg.bend_tangent) < 0.001)
		_check("the stub knows another run ends where it starts", stub.joined_start)
		var first:= -1.0
		if not stub.support_stations().is_empty():
			first = stub.support_stations() [0]
		_check("...so it stands no trestle of its own on the knee (first at %.2f m)" % first,
			first < 0.0 or first > 0.3)
		var paid:= leg.build_cost() + stub.build_cost()
		_check("the bill is what the two runs refund (%.2f against %.2f)"
			% [float(eval ["cost"]), paid], absf(float(eval ["cost"]) - paid) < 0.01)
	await _clear_yard()


func _case_the_wye() -> void:
	print("\n=== the wye ===")
	var builds: BuildManager = world.builds


	var centre:= _at(0.0)
	var yaw:= PI * 0.5
	var wye: WaterSplitter = builds.add_water_splitter(centre, yaw)
	await _settle()
	_check("a wye stands where it was put (off by %.4f m)"
		% wye.global_position.distance_to(centre),
		wye.global_position.distance_to(centre) < 0.001)
	_check("...facing where it was turned (%.3f rad)" % wye.global_rotation.y,
		absf(angle_difference(wye.global_rotation.y, yaw)) < 0.001)


	_check("...at a run's own axis height (%.3f m against %.3f)"
		% [wye.global_position.y, _lane_y], absf(wye.global_position.y - _lane_y) < 0.01)


	var ports:= wye.water_ports()
	_check("it answers the flange contract with three ports", ports.size() == 3)
	var off_model:= true
	for port: Node3D in ports:
		if port.get_parent() == wye:
			off_model = false
	_check("...and all three are the model's markers, not the fallbacks", off_model)


	var spread:= true
	for at: Vector3 in wye.ports():
		if absf(at.distance_to(centre) - Cfg.PIPE_SPLITTER_PORT_R) > 0.005:
			spread = false
	_check("every mouth is %.2f m from the crotch" % Cfg.PIPE_SPLITTER_PORT_R, spread)


	_check("...and the two outlets are apart (%.3f m)"
		% wye.port_left().distance_to(wye.port_right()),
		wye.port_left().distance_to(wye.port_right()) > 0.5)


	_check("...and the turn carried the inlet round with it",
		absf((wye.port_in() - centre).normalized().dot(Vector3.LEFT) - 1.0) < 0.02)


	var tool:= player.build
	tool.set_mode(BuildTool.Mode.WATER_PIPE)
	var outlets: Dictionary = tool._evaluate_pipe(wye.port_left(), wye.port_right(), true)
	_check("a run from one outlet to the other is refused: '%s'" % str(outlets ["reason"]),
		not bool(outlets ["ok"]) and str(outlets ["reason"]).contains("same piece"))
	var inlet: Dictionary = tool._evaluate_pipe(wye.port_in(), wye.port_left(), true)
	_check("...and so is one from the inlet to an outlet: '%s'" % str(inlet ["reason"]),
		not bool(inlet ["ok"]) and str(inlet ["reason"]).contains("same piece"))


	var away:= wye.port_left() + (wye.port_left() - centre).normalized() * 5.0
	var outward: Dictionary = tool._evaluate_pipe(wye.port_left(), away, true)
	_check("...but a run off a mouth into the yard is not: '%s'" % str(outward ["reason"]),
		not str(outward ["reason"]).contains("same piece"))


	var laid: Array [WaterMain] = []
	for at: Vector3 in wye.ports():
		var near:= at + Vector3(0.22, 0.06, 0.18)
		var snapped: Vector3 = builds.snap_water_endpoint(near)
		_check("a click near a mouth snaps onto it (off by %.4f m)"
			% snapped.distance_to(at), snapped.distance_to(at) < 0.001)
		_check("...and nothing is on it yet", not builds.water_port_taken(at))
		var run:= await _lay(at, at + (at - centre).normalized() * 5.0)
		laid.append(run)
		_check("...and a run may be laid off it", run != null)
	_check("all three ports carry a run", laid.size() == 3)
	for at: Vector3 in wye.ports():
		_check("...and each of them is now taken", builds.water_port_taken(at))


	tool.set_mode(BuildTool.Mode.WATER_PIPE)
	var taken: Dictionary = tool._evaluate_pipe(wye.port_in(),
		wye.port_in() + Vector3(6.0, 0.0, 0.0), true)
	_check("a second run on a taken mouth is refused: '%s'" % str(taken ["reason"]),
		not bool(taken ["ok"]) and str(taken ["reason"]).contains("flange"))


	_check("...but a run end out on the line is still free to branch",
		not builds.water_port_taken(laid [1].b))


	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.WATER_SPLITTER)
	_aim(_at(-5.0) - Vector3(0.0, Cfg.PIPE_RUN_HEIGHT, 0.0))
	await _settle()
	tool._update_water_splitter_ghost()
	_check("the hologram is up", tool._wye_ghost.visible)


	var under:= _ground_probe(tool._wye_ghost.global_position.x,
		tool._wye_ghost.global_position.z)
	_check("...standing a run's own height above the ground under it (%.3f over %.3f)"
		% [tool._wye_ghost.global_position.y, under],
		absf(tool._wye_ghost.global_position.y - (under + Cfg.PIPE_RUN_HEIGHT)) < 0.02)
	_check("...on clear ground it is green: '%s'" % str(tool._eval ["reason"]),
		bool(tool._eval ["ok"]))
	_check("...quoting the wye's own price ($%.2f)" % float(tool._eval ["cost"]),
		absf(float(tool._eval ["cost"]) - WaterSplitter.cost_for()) < 0.01)
	var kind:= str(tool.status().get("kind", ""))
	_check("...and the readout knows what is in hand ('%s')" % kind,
		kind == "water_splitter")


	var purse:= GameState.money
	var quoted:= float(tool._eval ["cost"])
	var standing:= builds.water_splitters.size()
	tool._place_water_splitter()
	await _settle()
	_check("a click puts one down (%d standing)" % builds.water_splitters.size(),
		builds.water_splitters.size() == standing + 1)
	_check("...and the till took the quoted price ($%.2f)" % (purse - GameState.money),
		absf((purse - GameState.money) - quoted) < 0.01)
	if builds.water_splitters.size() > standing:
		var placed: WaterSplitter = builds.water_splitters [standing]
		_check("...which is what the piece wrote down ($%.2f)" % placed.build_cost(),
			absf(placed.build_cost() - quoted) < 0.01)
		builds.demolish(placed)
		await _settle()
	tool.set_active(false)


	tool.set_mode(BuildTool.Mode.WATER_SPLITTER)
	var on_top: Dictionary = tool._evaluate_water_splitter(centre, Vector3.BACK,
		Vector3.UP, WaterSplitter.cost_for(), false)
	_check("a second wye on top of the first is refused: '%s'" % str(on_top ["reason"]),
		not bool(on_top ["ok"]))


	var clear_of_it:= _at(-5.0)
	var elsewhere: Dictionary = tool._evaluate_water_splitter(clear_of_it,
		Vector3.BACK, Vector3.UP, WaterSplitter.cost_for(), false)
	_check("...and one down the clear end of the lane is not: '%s'"
		% str(elsewhere ["reason"]), bool(elsewhere ["ok"]))
	await _clear_yard()


	Tech.grant("steel_saving", 0)
	var list:= WaterSplitter.cost_for()
	_check("a wye lists at $%.0f" % list,
		absf(list - Cfg.PIPE_SPLITTER_COST) < 0.01)
	Tech.grant("steel_saving", 3)
	var discounted:= WaterSplitter.cost_for()
	_check("the discount reaches the price ($%.2f against $%.2f)"
		% [discounted, list], discounted < list - 0.01)
	var bought: WaterSplitter = builds.add_water_splitter(_at(0.0), 0.0)
	await _settle()
	_check("...and the piece remembers what it was quoted ($%.2f)"
		% bought.build_cost(), absf(bought.build_cost() - discounted) < 0.01)


	Tech.grant("steel_saving", 0)
	_check("a rank lost later does not move the refund ($%.2f)"
		% bought.build_cost(), absf(bought.build_cost() - discounted) < 0.01)
	var back: float = builds.demolish(bought)
	await _settle()
	_check("...and it pays back exactly that ($%.2f)" % back,
		absf(back - discounted) < 0.01)
	_check("...and the yard has no wye left", builds.water_splitters.is_empty())


	Tech.grant("steel_saving", 2)
	var kept: WaterSplitter = builds.add_water_splitter(_at(3.0), PI * 0.25)
	await _settle()
	var paid:= kept.build_cost()
	var stood:= kept.global_position
	var faced:= kept.global_rotation.y
	var d:= kept.to_dict()
	_check("to_dict names the type", str(d.get("type", "")) == "water_splitter")
	for key: String in ["position", "yaw", "paid"]:
		_check("to_dict carries %s" % key, d.has(key))
	var saved: Array = builds.to_array()
	builds.clear()
	await _settle()
	_check("the yard is empty after clear", builds.water_splitters.is_empty())
	builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()
	_check("one wye came back", builds.water_splitters.size() == 1)
	if builds.water_splitters.size() == 1:
		var again: WaterSplitter = builds.water_splitters [0]
		_check("...where it was (off by %.4f m)" % again.global_position.distance_to(stood),
			again.global_position.distance_to(stood) < 0.001)
		_check("...facing the way it was (%.3f rad)" % again.global_rotation.y,
			absf(angle_difference(again.global_rotation.y, faced)) < 0.001)
		_check("...for what it cost ($%.2f)" % again.build_cost(),
			absf(again.build_cost() - paid) < 0.01)
		_check("...with its three ports back on it",
			again.water_ports().size() == 3)
	Tech.grant("steel_saving", 0)
	await _clear_yard()


func _case_the_wye_snapping() -> void:
	print("\n=== the wye onto the pipe ===")
	var builds: BuildManager = world.builds
	var tool:= player.build
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.WATER_SPLITTER)


	var run:= await _lay(_at(-6.0), _at(-3.0))


	_aim(_at(-3.0) + Vector3(0.34, - Cfg.PIPE_RUN_HEIGHT, 0.22))
	await _settle()
	tool._update_water_splitter_ghost()
	var ghost: WaterSplitter = tool._wye_ghost
	_check("the hologram took the end of the run (off by %.4f m)"
		% ghost.port_in().distance_to(run.b),
		ghost.port_in().distance_to(run.b) <= Cfg.PIPE_JOIN_TOLERANCE)


	_check("...on the INLET, with both outlets clear of it",
		ghost.port_left().distance_to(run.b) > 0.5
		and ghost.port_right().distance_to(run.b) > 0.5)


	_check("...turned onto the run's own bearing (%.3f m from the end)"
		% ghost.global_position.distance_to(run.b),
		absf(ghost.global_position.distance_to(run.b) - Cfg.PIPE_SPLITTER_PORT_R) < 0.01)
	_check("...and it is green: '%s'" % str(tool._eval ["reason"]),
		bool(tool._eval ["ok"]))


	tool._place_water_splitter()
	await _settle()
	_check("a click puts one down", builds.water_splitters.size() == 1)
	if builds.water_splitters.size() == 1:
		var placed: WaterSplitter = builds.water_splitters [0]
		_check("...with the run still on its inlet (off by %.4f m)"
			% placed.port_in().distance_to(run.b),
			placed.port_in().distance_to(run.b) <= Cfg.PIPE_JOIN_TOLERANCE)


		_check("...which is what makes the flange taken",
			builds.water_port_taken(placed.port_in()))


		var branch:= await _lay(placed.port_left(),
			placed.port_left() + (placed.port_left()
				- placed.global_position).normalized() * 4.0)
		var net: WaterGrid = builds.water
		_check("...and the pipe the wye snapped to is one network with the "
			+ "branch off it (%d network(s))" % net.network_count(),
			net.network_count() == 1
			and net.network_of(run) >= 0
			and net.network_of(run) == net.network_of(branch))


	player.global_position = Vector3(LANE_X + 3.0, 0.4, -6.5)
	await _settle()
	_aim(_at(-6.0) + Vector3(-0.3, - Cfg.PIPE_RUN_HEIGHT, -0.18))
	await _settle()
	tool._update_water_splitter_ghost()
	_check("the far end of the same run snaps too (off by %.4f m)"
		% ghost.port_in().distance_to(run.a),
		ghost.port_in().distance_to(run.a) <= Cfg.PIPE_JOIN_TOLERANCE)


	_check("...opening away from the pipe rather than into it",
		(ghost.global_position - run.a).normalized().dot(run.forward) < -0.99)


	var pump: BoreholePump = builds.add_borehole(Vector3(LANE_X + 8.0, 0.0, -6.0), 0.0)
	await _settle()
	var flange:= pump.water_port()
	player.global_position = flange + Vector3(0.0, 0.0, -2.6)
	await _settle()
	_aim(flange - Vector3(0.0, Cfg.PIPE_RUN_HEIGHT, 0.0))
	await _settle()
	tool._update_water_splitter_ghost()


	_check("the hologram is being sited at the pump's flange (%.2f m)"
		% ghost.global_position.distance_to(flange),
		ghost.global_position.distance_to(flange) < 1.5)
	_check("...and the flange does not pull the inlet onto it (%.2f m away)"
		% ghost.port_in().distance_to(flange),
		ghost.port_in().distance_to(flange) > Cfg.PIPE_JOIN_TOLERANCE)

	tool.set_active(false)


	player.global_position = Vector3(10.5, 0.4, 0.0)
	await _settle()
	await _clear_yard()


func _case_a_wye_onto_a_wye() -> void:
	print("\n=== a wye bolted onto a wye ===")
	await _clear_yard()
	var builds: BuildManager = world.builds
	var tool:= player.build
	player.global_position = Vector3(10.5, 0.4, 0.0)
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.WATER_SPLITTER)
	var first: WaterSplitter = builds.add_water_splitter(_at(-4.0), 0.0)
	await _settle()
	var flange:= first.port_left()
	var away:= first.water_port_bearing(first.water_ports() [1])


	_aim(flange + away * 0.3 - Vector3(0.0, Cfg.PIPE_RUN_HEIGHT, 0.0))
	await _settle()
	tool._update_water_splitter_ghost()
	var ghost: WaterSplitter = tool._wye_ghost
	_check("the hologram takes the free flange (off by %.4f m)"
		% ghost.port_in().distance_to(flange),
		ghost.port_in().distance_to(flange) <= Cfg.PIPE_JOIN_TOLERANCE)
	_check("...turned straight out of it (%.3f m from the first's crotch)"
		% ghost.global_position.distance_to(first.global_position),
		absf(ghost.global_position.distance_to(first.global_position)
			- Cfg.PIPE_SPLITTER_PORT_R * 2.0) < 0.01)
	_check("...and it is green: '%s'" % str(tool._eval ["reason"]),
		bool(tool._eval ["ok"]))


	var loose: Dictionary = tool._evaluate_water_splitter(ghost.global_position,
		away, Vector3.UP, WaterSplitter.cost_for(), true)
	_check("...where a loose wye on that spot is still refused: '%s'"
		% str(loose ["reason"]), not bool(loose ["ok"]))

	tool._place_water_splitter()
	await _settle()
	_check("a click bolts it on (%d wyes)" % builds.water_splitters.size(),
		builds.water_splitters.size() == 2)
	if builds.water_splitters.size() != 2:
		tool.set_active(false)
		await _clear_yard()
		return
	var second: WaterSplitter = builds.water_splitters [1]
	_check("the bolted flange is taken", builds.water_port_taken(flange))
	_check("...and a run is not offered it",
		not builds.nearest_flange(flange).is_equal_approx(flange))


	var into:= await _lay(_at(-9.0), first.port_in())
	var onward:= await _lay(second.port_left(), second.port_left()
		+ second.water_port_bearing(second.water_ports() [1]) * 4.0)
	var net: WaterGrid = builds.water
	_check("pipe into one and out of the other is ONE network (%d)"
		% net.network_count(),
		net.network_of(into) >= 0 and net.network_of(into) == net.network_of(onward))
	builds.demolish(second)
	await _settle()
	_check("...and taking the second up parts them",
		net.network_of(into) != net.network_of(onward))
	tool.set_active(false)
	await _clear_yard()


func _case_the_money() -> void:
	print("\n=== the money ===")
	var metres:= 10.0
	Tech.grant("steel_saving", 0)
	var list:= WaterMain.cost_for(_at(0.0), _at(metres))
	_check("a %.0f m run is %.0f x $%.0f = $%.0f"
		% [metres, metres, Cfg.PIPE_COST_PER_M, list],
		absf(list - metres * Cfg.PIPE_COST_PER_M) < 0.01)


	_check("...and it is dearer than a belt of the same length",
		Cfg.PIPE_COST_PER_M > Cfg.BELT_COST_PER_M)


	Tech.grant("steel_saving", 3)
	var discounted:= WaterMain.cost_for(_at(0.0), _at(metres))
	_check("the discount reaches the price ($%.2f against $%.2f)"
		% [discounted, list], discounted < list - 0.01)
	var run:= await _lay(_at(0.0), _at(metres))
	_check("...and the run remembers what it was quoted ($%.2f)"
		% run.build_cost(), absf(run.build_cost() - discounted) < 0.01)
	var back: float = world.builds.demolish(run)
	await _settle()
	_check("...and pays back exactly that ($%.2f)" % back,
		absf(back - discounted) < 0.01)


	var again:= await _lay(_at(0.0), _at(metres))
	var was:= again.build_cost()
	Tech.grant("steel_saving", 0)
	_check("a rank lost later does not move the refund ($%.2f)"
		% again.build_cost(), absf(again.build_cost() - was) < 0.01)
	var late: float = world.builds.demolish(again)
	await _settle()
	_check("...and the till agrees ($%.2f)" % late, absf(late - was) < 0.01)
	await _clear_yard()


func _case_a_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	var first:= await _lay(_at(0.0), _at(7.0))
	var knee:= _at(7.0)
	var second:= await _lay(knee, knee + Vector3(5.0, 0.0, 0.0))
	var paid:= first.build_cost()

	var d:= first.to_dict()
	_check("to_dict names the type", str(d.get("type", "")) == "water_main")
	for key: String in ["a", "b", "paid"]:
		_check("to_dict carries %s" % key, d.has(key))

	var a:= first.a
	var b:= first.b
	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	_check("the yard is empty after clear", world.builds.water_mains.is_empty())
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()

	_check("two runs came back", world.builds.water_mains.size() == 2)
	if world.builds.water_mains.size() < 2:
		return
	var back: WaterMain = world.builds.water_mains [0]
	_check("...where they were (off by %.4f m)" % back.a.distance_to(a),
		back.a.distance_to(a) < 0.001 and back.b.distance_to(b) < 0.001)
	_check("...for what they cost ($%.2f)" % back.build_cost(),
		absf(back.build_cost() - paid) < 0.01)


	_check("...and the bend was worked out again from the geometry",
		back.bend_tangent > 0.05)
	await _clear_yard()


func _nearest_section(run: WaterMain, s: float) -> int:
	var best:= -1
	for i in run.section_stations.size():
		if best < 0 or absf(run.section_stations [i] - s) < absf(run.section_stations [best] - s):
			best = i
	return best


func _socket_span() -> Vector2:
	var mesh:= PipeKit.section_mesh()
	if mesh == null:
		return Vector2.ZERO
	for i in mesh.get_surface_count():
		var m:= mesh.surface_get_material(i)
		if m == null or m.resource_name != "M_WP_Fitting":
			continue
		var arrays: Array = mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			return Vector2.ZERO
		var lo: float = verts [0].z
		var hi: float = verts [0].z
		for v: Vector3 in verts:
			lo = minf(lo, v.z)
			hi = maxf(hi, v.z)
		return Vector2(lo, hi)
	return Vector2.ZERO


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


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


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
