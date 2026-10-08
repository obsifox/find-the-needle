extends RefCounted


const CALLS:= 20


const SETTLE:= 8

var p: Node
var world: Node3D


func run(probe: Node) -> void:
	p = probe
	world = p.world
	_aim_like_the_bundle()
	if "--toolparts" in OS.get_cmdline_user_args():
		await _parts()
		return
	await _systems()
	await _tools()


func _parts() -> void:
	var tool: BuildTool = world.player.build
	var builds: BuildManager = world.builds
	var dt:= 1.0 / 60.0
	print("\n=== the pieces of a ghost's frame ===")
	print("TOOLPARTS: %d conveyors, %d buildings" % [builds.conveyors.size(), builds.all_buildings().size()])
	tool.set_active(false)
	for _k in SETTLE:
		await p.get_tree().process_frame
	_part("idle: whole _process, tool away", func() -> void: tool._process(dt))
	_part("idle: _tick_dismantle", func() -> void: tool._tick_dismantle(dt))
	_part("idle: _tick_wreck_glow", func() -> void: tool._tick_wreck_glow())
	_part("idle: _tick_reverse", func() -> void: tool._tick_reverse(dt))
	_part("idle: _tick_peek", func() -> void: tool._tick_peek())
	_part("idle: _tick_enclosed_hint", func() -> void: tool._tick_enclosed_hint(dt))
	for key: String in ["CONVEYOR", "ENCLOSED_CONVEYOR"]:
		tool.set_active(true)
		tool.set_mode(BuildTool.Mode [key])
		for _k in SETTLE:
			await p.get_tree().process_frame
		var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
		var raw: Vector3 = tool._surface_point(lift)
		var point: Vector3 = tool._aim_point()
		var dir:= world.player.look_direction() as Vector3
		dir.y = 0.0
		dir = dir.normalized()
		var to: Vector3 = point + dir * BuildTool.STUB_LENGTH
		print("TOOLPARTS: %s aim %v, raw %v" % [key, point, raw])
		_part(key + ": whole _process", func() -> void: tool._process(dt))
		_part(key + ": _update_grid", func() -> void: tool._update_grid())
		_part(key + ": _surface_hit", func() -> void: tool._surface_hit())
		_part(key + ": snap_endpoint", func() -> void: builds.snap_endpoint(raw, null, Vector3.INF))
		_part(key + ": _aim_point", func() -> void: tool._aim_point())
		_part(key + ": _free_tail", func() -> void: tool._free_tail(point))
		_part(key + ": _free_intake", func() -> void: tool._free_intake(point))
		_part(key + ": _run_cost", func() -> void: tool._run_cost(point, to))
		_part(key + ": _joint_taken", func() -> void: tool._joint_taken(point, true))
		_part(key + ": _evaluate", func() -> void: tool._evaluate(point, to, false))
		_part(key + ": _shape_ghost", func() -> void: tool._shape_ghost(point, to))
	for key: String in ["COMPRESSOR", "LAUNCHER"]:
		var mode: int = BuildTool.Mode [key]
		tool.set_active(true)
		tool.set_mode(mode)
		for _k in SETTLE:
			await p.get_tree().process_frame
		var hit: Dictionary = tool._surface_hit()
		var spec: Dictionary = tool._seat_spec(mode)
		_part(key + ": whole _process", func() -> void: tool._process(dt))
		if hit.is_empty():
			print("TOOLPARTS: %s aims at nothing" % key)
			continue
		var feet: Vector3 = hit ["position"]
		_part(key + ": _seat_on_line", func() -> void: tool._seat_on_line(feet, Cfg.COMPRESSOR_SNAP_RADIUS, spec))
		_part(key + ": _seat_draw", func() -> void: tool._seat_draw())
	await _own_search_parts(tool, builds)
	tool.set_active(false)
	_grid_parts(builds.grid)


func _grid_parts(grid: PowerGrid) -> void:
	if grid == null:
		return
	print("\n=== the pieces of a power rebuild ===")
	var sums:= { }
	var order: Array [String] = []
	var clock:= func(label: String, fn: Callable) -> void:
		var t:= Time.get_ticks_usec()
		fn.call()
		if not sums.has(label):
			sums [label] = 0.0
			order.append(label)
		sums [label] += float(Time.get_ticks_usec() - t)
	const RUNS:= 3
	for _r in RUNS:

		var ctx:= { "poles": [] as Array [PowerPole] }
		clock.call("clear and _poles", func() -> void:
			grid._nets.clear()
			grid._net_of_pole.clear()
			grid._link.clear()
			grid._unreachable.clear()
			grid._pushed.clear()
			grid._pushed_line.clear()
			grid._span_ok.clear()
			ctx ["poles"] = grid._poles())
		var poles: Array [PowerPole] = grid._poles()
		clock.call("_resolve_links", func() -> void: grid._resolve_links(poles))
		clock.call("begin_restring", func() -> void:
			for pole in poles:
				pole.begin_restring())
		clock.call("_build_networks", func() -> void: grid._build_networks(poles))
		clock.call("_attach_machines", func() -> void: grid._attach_machines(poles))
		clock.call("_string_wires", func() -> void: grid._string_wires(poles))
		clock.call("end_restring", func() -> void:
			for pole in poles:
				pole.end_restring())
		clock.call("_find_loose", func() -> void: grid._find_loose())
		clock.call("_find_feeders", func() -> void: grid._find_feeders())
		clock.call("_push_blocked", func() -> void: grid._push_blocked())
		clock.call("tick", func() -> void: grid.tick())
		clock.call("machines()", func() -> void: grid.machines())
	var total:= 0.0
	for label: String in order:
		if label != "machines()":
			total += sums [label]
		print("GRIDPART %-20s %8.3f ms a rebuild" % [label, sums [label] / RUNS / 1000.0])
	print("GRIDPART %-20s %8.3f ms a rebuild" % ["TOTAL", total / RUNS / 1000.0])
	var t:= Time.get_ticks_usec()
	grid.rebuild()
	print("GRIDPART %-20s %8.3f ms" % ["rebuild() itself", float(Time.get_ticks_usec() - t) / 1000.0])

	var before:= { }
	for pole in grid._poles():
		for line in pole.find_children("*", "PowerLine", false, false):
			before [line.get_instance_id()] = true
	t = Time.get_ticks_usec()
	grid.rebuild()
	var rebuild_ms:= float(Time.get_ticks_usec() - t) / 1000.0
	var kept_n:= 0
	var new_n:= 0
	for pole in grid._poles():
		for line in pole.find_children("*", "PowerLine", false, false):
			if before.has(line.get_instance_id()):
				kept_n += 1
			else:
				new_n += 1
	print("GRIDPART wires across a rebuild (%.3f ms): %d reused, %d hung again, %d before"
		% [rebuild_ms, kept_n, new_n, before.size()])

	var ps:= grid._poles()
	t = Time.get_ticks_usec()
	var strung:= 0
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			if grid._strung(ps [i], ps [j]):
				strung += 1
	print("GRIDPART string: pair test %8.3f ms (%d strung)" % [float(Time.get_ticks_usec() - t) / 1000.0, strung])
	t = Time.get_ticks_usec()
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			if PowerGrid.linked(ps [i], ps [j]):
				PowerLine.anchors_of(ps [i])
				PowerLine.anchors_of(ps [j])
	print("GRIDPART string: anchors_of per span %8.3f ms" % (float(Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	for record: Dictionary in grid._link.values():
		(record ["pole"] as PowerPole).wire_anchors()
	print("GRIDPART string: %d drops, wire_anchors %8.3f ms" % [grid._link.size(), float(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	for pole in ps:
		pole.begin_restring()
	grid._string_wires(ps)
	for pole in ps:
		pole.end_restring()
	print("GRIDPART string: whole with restring %8.3f ms" % (float(Time.get_ticks_usec() - t) / 1000.0))

	var ms:= grid.machines()
	t = Time.get_ticks_usec()
	var nbodies:= 0
	for m in ms:
		nbodies += PowerGrid.own_bodies(m).size()
	print("GRIDPART own_bodies x %d machines %8.3f ms (%d bodies)"
		% [ms.size(), float(Time.get_ticks_usec() - t) / 1000.0, nbodies])
	t = Time.get_ticks_usec()
	var clear_group:= PowerGrid.transparent_bodies(world.builds)
	print("GRIDPART transparent_bodies %8.3f ms, %d bodies"
		% [float(Time.get_ticks_usec() - t) / 1000.0, clear_group.size()])
	var poles:= grid._poles()
	t = Time.get_ticks_usec()
	var nports:= 0
	for pole in poles:
		pole.own_bodies()
	print("GRIDPART own_bodies x %d poles %8.3f ms" % [poles.size(), float(Time.get_ticks_usec() - t) / 1000.0])
	var pairs:= 0
	for m in ms:
		for pole in poles:
			if PowerGrid.in_reach(pole, m.global_position):
				pairs += 1
				nports += PowerGrid.ports_of(m).size()
	print("GRIDPART %d machine and pole pairs in reach, %d port rays" % [pairs, nports])


func _own_search_parts(tool: BuildTool, builds: BuildManager) -> void:
	var dt:= 1.0 / 60.0
	print("TOOLPARTS: %d arms, %d decks, %d poles, %d mains, %d U splitters, %d U joiners"
		% [builds.robotic_arms.size(), builds.platforms.size(), builds.power_poles.size(),
		builds.water_mains.size() if "water_mains" in builds else -1,
		builds.u_splitters.size() if "u_splitters" in builds else -1,
		builds.u_joiners.size() if "u_joiners" in builds else -1])
	for key: String in ["ROBOTIC_ARM", "POWER_BOX", "POWER_POLE", "U_SPLITTER", "U_JOINER", "WATER_PIPE"]:
		tool.set_active(true)
		tool.set_mode(BuildTool.Mode [key])
		for _k in SETTLE:
			await p.get_tree().process_frame
		_part(key + ": whole _process", func() -> void: tool._process(dt))
		_part(key + ": _update_grid", func() -> void: tool._update_grid())
		_part(key + ": _surface_hit", func() -> void: tool._surface_hit())
		var hit: Dictionary = tool._surface_hit()
		if hit.is_empty() and key != "WATER_PIPE":
			print("TOOLPARTS: %s aims at nothing" % key)
			continue
		var point: Vector3 = hit.get("position", Vector3.ZERO)
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		var surface: Object = hit.get("collider")
		print("TOOLPARTS: %s aim %v" % [key, point])
		match key:
			"ROBOTIC_ARM":
				var tier: int = tool._arm_tier
				var scale:= float(Cfg.ROBOT_ARM_TIERS [tier] ["scale"])
				_part(key + ": arm_price", func() -> void: builds.arm_price(tier))
				_part(key + ": _footing_reason", func() -> void: tool._footing_reason(point))
				_part(key + ": _ground_reason", func() -> void: tool._ground_reason(surface))
				_part(key + ": arm_reach_conflict", func() -> void: builds.arm_reach_conflict(point, tier))
				_part(key + ": deck_through_arm", func() -> void: builds.deck_through_arm(point, tier))
				_part(key + ": _evaluate_arm", func() -> void:
					tool._evaluate_arm(point, normal, 0.0, scale, surface))
				_part(key + ": set_preview_valid", func() -> void: tool._arm_ghost.set_preview_valid(true))
			"POWER_BOX", "POWER_POLE":
				var ghost: PowerPole = tool._post_ghost()
				_part(key + ": deck_under", func() -> void: builds.deck_under(point))
				_part(key + ": _evaluate_pole", func() -> void: tool._evaluate_pole(point, normal, surface))
				_part(key + ": _survey_pole", func() -> void: tool._survey_pole(point))
				_part(key + ": poles_to_string_to", func() -> void:
					builds.poles_to_string_to(point, ghost.link_reach(), null, ghost))
				_part(key + ": own_bodies", func() -> void: ghost.own_bodies())
				_part(key + ": grid.machines", func() -> void: builds.grid.machines())
				var candidates: Array [PowerPole] = []
				for pole in builds.power_poles:
					if is_instance_valid(pole):
						candidates.append(pole)
				candidates.append(ghost)
				var near: Array [Node3D] = []
				for machine in builds.grid.machines():
					if PowerGrid.in_reach(ghost, machine.global_position):
						near.append(machine)
				print("TOOLPARTS: %s %d machines in the circle" % [key, near.size()])
				_part(key + ": grid.attach(near)", func() -> void: builds.grid.attach(candidates, near))
				_part(key + ": _draw_pole_ghost_wires", func() -> void: tool._draw_pole_ghost_wires())
			"U_SPLITTER", "U_JOINER":
				var ghost: Node3D = tool._u_splitter_ghost if key == "U_SPLITTER" else tool._u_joiner_ghost
				var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
				var deck: Vector3 = point + normal * lift
				_part(key + ": nearest_wye_joint", func() -> void:
					builds.nearest_wye_joint(deck, Cfg.SPLITTER_SNAP_RADIUS))
				_part(key + ": _floor_reason", func() -> void: tool._floor_reason(ghost.global_position))
				_part(key + ": wye_overlap", func() -> void: builds.wye_overlap(ghost.call("footprint"), ghost))
				_part(key + ": _evaluate_u_wye", func() -> void:
					tool._evaluate_u_wye(ghost, Vector3.FORWARD, normal, false, 0.0, 1.0))
				_part(key + ": set_preview_valid", func() -> void: ghost.call("set_preview_valid", true))
			"WATER_PIPE":
				var raw: Vector3 = tool._surface_point(Cfg.PIPE_RUN_HEIGHT)
				var at: Vector3 = tool._pipe_aim_point()
				_part(key + ": _pipe_aim_point", func() -> void: tool._pipe_aim_point())
				_part(key + ": snap_water_endpoint", func() -> void: builds.snap_water_endpoint(raw))
				_part(key + ": water_port_bearing_at", func() -> void: builds.water_port_bearing_at(at))
				_part(key + ": water_port_taken", func() -> void: builds.water_port_taken(at))
				_part(key + ": _evaluate_pipe stub", func() -> void:
					tool._evaluate_pipe(at, at + Vector3.FORWARD * BuildTool.STUB_LENGTH, false))
				_part(key + ": _finished_here", func() -> void: tool._finished_here(at))
				_part(key + ": _update_pipe_ghost", func() -> void: tool._update_pipe_ghost())


func _part(label: String, fn: Callable) -> void:
	world.builds.ghost_reading = true
	var ms:= _us(fn, CALLS) / 1000.0
	world.builds.ghost_reading = false
	print("TOOLPART %-40s %8.3f ms a call" % [label, ms])


func _aim_like_the_bundle() -> void:
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--bundle")
	if i < 0 or i + 1 >= ua.size() or not FileAccess.file_exists(ua [i + 1]):
		print("TOOLCOST: no bundle, aiming where the save left the player")
		return
	var yaw:= NAN
	var pitch:= NAN
	for line in FileAccess.get_file_as_string(ua [i + 1]).split("\n"):
		var parts:= line.split("=")
		if parts.size() < 2:
			continue
		if line.begins_with("player_yaw"):
			yaw = float(parts [1].strip_edges())
		elif line.begins_with("head_pitch"):
			pitch = float(parts [1].strip_edges())
	if is_nan(yaw) or is_nan(pitch) or world.player == null:
		return
	world.player.set_look(yaw, pitch)
	print("TOOLCOST: player turned to yaw %.3f pitch %.3f" % [yaw, pitch])


func _systems() -> void:
	var grid: PowerGrid = world.builds.grid
	var water: WaterGrid = world.builds.water
	print("\n=== the networks ===")
	if grid != null:
		print("TOOLCOST: power %d networks, %d machines on a grid, unmetered %s"
			% [grid._nets.size(), grid.machines().size(), grid.unmetered])
		print("TOOLCOST: power tick   %8.1f us a call (the per frame cost)" % _us(grid.tick, 200))
		print("TOOLCOST: power rebuild %7.2f ms a call (paid 2 frames after every placement)"
			% (_us(grid.rebuild, 3) / 1000.0))


		for on: bool in [false, true, false, true]:
			BuildManager.yard_memo_enabled = on
			var total:= 0.0
			for _k in 3:
				YardPorts.touch()
				total += _us(grid.rebuild, 1)
			print("TOOLCOST: power rebuild after a change, memo %s %7.2f ms"
				% ["on " if on else "off", total / 3.0 / 1000.0])
		BuildManager.yard_memo_enabled = true
	if water != null:
		print("TOOLCOST: water %d machines" % water.machines().size())
		print("TOOLCOST: water tick   %8.1f us a call (the per frame cost)" % _us(water.tick, 200))
		print("TOOLCOST: water rebuild %7.2f ms a call" % (_us(water.rebuild, 3) / 1000.0))
	await p._settle_draws()
	var r: Dictionary = await p._toggle_pairs("power and water ticks off", 3,
		func(on: bool) -> void: world.builds.set_process(not on))
	print("TOOLPAIR %+.3f ms  spread %.3f  on %.2f off %.2f  power and water ticks off"
		% [r ["saved"], r ["spread"], r ["on"], r ["off"]])


func _tools() -> void:
	var tool: BuildTool = world.player.build if world.player != null else null
	if tool == null:
		print("TOOLCOST: no build tool on the player")
		return
	print("\n=== what holding each build tool costs, a frame ===")
	var out: Array [Array] = []
	for key: String in BuildTool.Mode.keys():
		var mode: int = BuildTool.Mode [key]
		tool.set_active(true)
		tool.set_mode(mode)
		for _k in SETTLE:
			await p.get_tree().process_frame

		var table: Array = await _time_process(tool)
		BuildManager.port_index_enabled = false
		var walks: Array = await _time_process(tool)
		BuildManager.port_index_enabled = true

		BuildManager.yard_memo_enabled = false
		var unkept: Array = await _time_process(tool)
		BuildManager.yard_memo_enabled = true
		out.append([key, table [0], table [1], walks [0], unkept [0]])
		print("TOOLCOST: %-20s %7.3f ms a frame, worst %7.3f   (walks %7.3f, memo off %7.3f)"
			% [key, table [0], table [1], walks [0], unkept [0]])
	tool.set_active(false)
	out.sort_custom(func(a: Array, b: Array) -> bool: return a [1] > b [1])
	print("\n=== build tools, dearest first ===")
	for row in out:
		print("TOOLRANK %-20s %7.3f ms a frame, worst %7.3f   (walks %7.3f, memo off %7.3f)"
			% [row [0], row [1], row [2], row [3], row [4]])


	await p._settle_draws()
	var pair_modes: Array [String] = ["CONVEYOR"]
	if out [0] [0] != "CONVEYOR":
		pair_modes.append(out [0] [0])
	for pk: String in pair_modes:
		var pm: int = BuildTool.Mode [pk]
		var r: Dictionary = await p._toggle_pairs("%s tool out" % pk, 3,
			func(on: bool) -> void:
				tool.set_active(false)
				tool.set_active(on)
				if on:
					tool.set_mode(pm))
		print("TOOLPAIR %+.3f ms  spread %.3f  on %.2f off %.2f  %s tool put away"
			% [- r ["saved"], r ["spread"], r ["on"], r ["off"], pk])


	for mk: String in ["ROBOTIC_ARM", "POWER_BOX", "POWER_POLE", "U_SPLITTER", "WATER_PIPE"]:
		tool.set_active(true)
		tool.set_mode(BuildTool.Mode [mk])
		var rm: Dictionary = await p._toggle_pairs("yard memo off, %s out" % mk, 3,
			func(on: bool) -> void: BuildManager.yard_memo_enabled = not on)
		BuildManager.yard_memo_enabled = true
		print("TOOLPAIR %+.3f ms  spread %.3f  on %.2f off %.2f  yard memo saves, %s out"
			% [- float(rm ["saved"]), rm ["spread"], rm ["on"], rm ["off"], mk])

	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.CONVEYOR)
	var rt: Dictionary = await p._toggle_pairs("port table off, CONVEYOR out", 3,
		func(on: bool) -> void: BuildManager.port_index_enabled = not on)
	BuildManager.port_index_enabled = true
	print("TOOLPAIR %+.3f ms  spread %.3f  on %.2f off %.2f  port table saves, CONVEYOR out"
		% [- float(rt ["saved"]), rt ["spread"], rt ["on"], rt ["off"]])
	tool.set_active(false)


func _time_process(tool: BuildTool) -> Array:
	var worst:= 0.0
	var total:= 0.0
	for _k in CALLS:
		var t:= Time.get_ticks_usec()
		tool._process(1.0 / 60.0)
		var us:= float(Time.get_ticks_usec() - t)
		total += us
		worst = maxf(worst, us)
		await p.get_tree().process_frame
	return [total / CALLS / 1000.0, worst / 1000.0]


func _us(fn: Callable, n: int) -> float:
	var t:= Time.get_ticks_usec()
	for _k in n:
		fn.call()
	return float(Time.get_ticks_usec() - t) / n
