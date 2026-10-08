class_name DevBuildHitchProbe
extends Node


var world: Node3D
var player: Player


const PLACEMENTS:= 8


const AFTER:= 12


const TEST_ORIGIN:= Vector3(-46.0, 0.0, 34.0)
const RUN_LENGTH:= 8.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--buildhitch")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("BUILDHITCH: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("BUILDHITCH: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array([])
	for _k in 60:
		await get_tree().physics_frame

	var b: BuildManager = world.builds
	print("BUILDHITCH: block_save=%s  %d runs, %d corners, %d splitters, %d arms, %d launchers, %d poles"
		% [world.block_save, b.conveyors.size(), b.corners.size(), b.splitters.size(),
			b.robotic_arms.size(), b.tube_launchers.size(), b.power_poles.size()])


	var t_answer:= Time.get_ticks_usec()
	b.grid._find_feeders()
	var ms_answer:= _ms(t_answer)
	var fed:= PackedStringArray()
	for machine in b.grid.machines():
		if b.grid.is_feeder(machine):
			fed.append("%s/%s" % [machine.get_parent().name, machine.name])
	fed.sort()
	print("FEEDERS: %d of %d machines, found in %.2f ms" % [fed.size(), b.grid.machines().size(), ms_answer])
	for line in fed:
		print("FEEDER %s" % line)
	if "feedersonly" in ua:
		get_tree().quit(0)
		return


	print("")
	print("=== what one rebuild_junctions costs on this yard ===")


	var was:= { }
	for k in b.corners:
		was [k.get_instance_id()] = true
	for _pass in 3:
		var t_corners:= Time.get_ticks_usec()
		b.rebuild_junctions()
		var ms_all:= _ms(t_corners)
		var fresh:= 0
		var now:= { }
		for k in b.corners:
			now [k.get_instance_id()] = true
			if not was.has(k.get_instance_id()):
				fresh += 1
		was = now
		print("  %d bends standing, %d of them rebuilt this pass"
			% [b.corners.size(), fresh])
		var t_rail:= Time.get_ticks_usec()
		b._rebuild_rail_windows()
		var ms_rail:= _ms(t_rail)


		var t_wire:= Time.get_ticks_usec()
		var links:= b._run_ends()
		b._rewire_downstream(links [0], links [1])
		var ms_wire:= _ms(t_wire)
		var t_heads:= Time.get_ticks_usec()
		b._reserve_machine_heads()
		var ms_heads:= _ms(t_heads)
		print("  rebuild_junctions %7.2f ms   (of which rail windows %.2f, rewire %.2f, heads %.2f, bends %.2f)"
			% [ms_all, ms_rail, ms_wire, ms_heads,
				ms_all - ms_rail - ms_wire - ms_heads])
		await get_tree().physics_frame


	print("")
	print("=== what run_out_of and feed_run_into cost ===")
	var mouths:= PackedVector3Array()
	for group: Array in [b.scanners, b.compressors, b.pulpers, b.papers,
			b.briquette_presses, b.wrappers, b.silos, b.pelletizers, b.hay_lifts]:
		for m in group:
			if is_instance_valid(m) and m.has_method("port_out"):
				mouths.append(m.call("port_out"))
	for splitter in b.splitters:
		if is_instance_valid(splitter):
			for side: int in splitter.output_sides():
				mouths.append(splitter.port(side))
	for _pass in 2:
		var t_scan:= Time.get_ticks_usec()
		for mouth: Vector3 in mouths:
			b.run_out_of(mouth)
			b.feed_run_into(mouth)
		print("  %d mouths, one of each: %.2f ms over %d runs"
			% [mouths.size(), _ms(t_scan), b.conveyors.size()])
		await get_tree().physics_frame

	print("")
	print("=== what the two grids cost ===")
	for _pass in 3:
		var t_grid:= Time.get_ticks_usec()
		b.grid.rebuild()
		var ms_grid:= _ms(t_grid)
		var t_water:= Time.get_ticks_usec()
		if b.water != null:
			b.water.rebuild()
		var ms_water:= _ms(t_water)
		print("  PowerGrid.rebuild %7.2f ms   WaterGrid.rebuild %.2f ms" % [ms_grid, ms_water])
		await get_tree().physics_frame

	print("")
	print("=== inside PowerGrid.rebuild, phase by phase ===")
	for _pass in 2:
		var poles:= b.grid._poles()
		var t_links:= Time.get_ticks_usec()
		b.grid._resolve_links(poles)
		var ms_links:= _ms(t_links)
		var t_nets:= Time.get_ticks_usec()
		b.grid._build_networks(poles)
		var ms_nets:= _ms(t_nets)
		var t_attach:= Time.get_ticks_usec()
		b.grid._attach_machines(poles)
		var ms_attach:= _ms(t_attach)


		var t_wires:= Time.get_ticks_usec()
		for pole in poles:
			pole.begin_restring()
		b.grid._string_wires(poles)
		for pole in poles:
			pole.end_restring()
		var ms_wires:= _ms(t_wires)
		var t_loose:= Time.get_ticks_usec()
		b.grid._find_loose()
		var ms_loose:= _ms(t_loose)
		var t_feed:= Time.get_ticks_usec()
		b.grid._find_feeders()
		var ms_feed:= _ms(t_feed)
		var t_blocked:= Time.get_ticks_usec()
		b.grid._push_blocked()
		var ms_blocked:= _ms(t_blocked)
		var t_tick:= Time.get_ticks_usec()
		b.grid.tick()
		var ms_tick:= _ms(t_tick)
		print("  links %.2f  networks %.2f  attach %.2f  wires %.2f  loose %.2f  FEEDERS %.2f  blocked %.2f  tick %.2f"
			% [ms_links, ms_nets, ms_attach, ms_wires, ms_loose, ms_feed, ms_blocked, ms_tick])
		await get_tree().physics_frame

	print("")
	print("=== what the deferred support refresh costs ===")
	for _pass in 3:
		var t_sup:= Time.get_ticks_usec()
		for c in b.conveyors:
			if is_instance_valid(c):
				c.refresh_supports()
		var ms_belts:= _ms(t_sup)
		var t_wye:= Time.get_ticks_usec()
		b._refresh_wye_supports()
		print("  refresh_supports on %d runs %7.2f ms   wyes %.2f ms"
			% [b.conveyors.size(), ms_belts, _ms(t_wye)])
		await get_tree().physics_frame


	for _pass in 2:
		var ms_own:= 0.0
		var ms_stations:= 0.0
		var rays:= 0
		var space:= world.get_world_3d().direct_space_state
		var ms_rays:= 0.0
		for c: Conveyor in b.conveyors:
			if not is_instance_valid(c):
				continue
			var t0:= Time.get_ticks_usec()
			var own:= c._own_bodies()
			ms_own += _ms(t0)
			var t1:= Time.get_ticks_usec()
			var stations:= c.support_stations()
			ms_stations += _ms(t1)
			var t2:= Time.get_ticks_usec()
			for s: float in stations:
				for side in 2:
					var top:= c.a + c.forward * s + Vector3(0.0, 1.0, 0.0) * float(side)
					var q:= PhysicsRayQueryParameters3D.create(top,
						top - Vector3(0, Cfg.BELT_SUPPORT_MAX_DROP, 0))
					q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
					q.exclude = own
					space.intersect_ray(q)
					rays += 1
			ms_rays += _ms(t2)
		print("  of which: _own_bodies %.2f ms, support_stations %.2f ms, %d rays %.2f ms"
			% [ms_own, ms_stations, rays, ms_rays])
		await get_tree().physics_frame

	print("")
	print("=== what else a click wakes up ===")
	var mdd:= world.get_node_or_null("MachineDrawDistance")
	for _pass in 2:
		var ms_mdd:= 0.0
		if mdd != null:
			var t_mdd:= Time.get_ticks_usec()
			mdd._refresh()
			ms_mdd = _ms(t_mdd)
		var t_placed:= Time.get_ticks_usec()
		var placed:= b.every_placed()
		var ms_placed:= _ms(t_placed)
		print("  MachineDrawDistance._refresh %.2f ms   every_placed (%d) %.2f ms"
			% [ms_mdd, placed.size(), ms_placed])
		await get_tree().physics_frame


	print("")
	print("=== what holding the pole ghost costs, a frame ===")
	var tool: BuildTool = player.build
	if tool != null:
		tool.set_mode(BuildTool.Mode.POWER_POLE)
		for _k in 4:
			await get_tree().process_frame


		var ghost_pole: PowerPole = tool._post_ghost()
		var spots: Array [Vector3] = [ghost_pole.global_position]
		for pole in b.power_poles:
			if is_instance_valid(pole) and spots.size() < 12:
				spots.append(pole.global_position + Vector3(2.5, 0.0, 2.5))
		var mismatched:= 0
		var compared:= 0
		for spot: Vector3 in spots:
			ghost_pole.global_position = spot
			var cands: Array [PowerPole] = []
			for pole in b.power_poles:
				if is_instance_valid(pole):
					cands.append(pole)
			cands.append(ghost_pole)
			var near: Array [Node3D] = []
			for m in b.grid.machines():
				if PowerGrid.in_reach(ghost_pole, m.global_position):
					near.append(m)
			var whole: Dictionary = b.grid.attach(cands)
			var scoped: Dictionary = b.grid.attach(cands, near)


			var reach_whole:= _drops_on(whole, ghost_pole)
			var reach_scoped:= _drops_on(scoped, ghost_pole)
			var blocked_whole:= _blocked_near(whole, ghost_pole)
			var blocked_scoped:= _blocked_near(scoped, ghost_pole)
			compared += 1
			if reach_whole != reach_scoped or blocked_whole != blocked_scoped:
				mismatched += 1
				print("    MISMATCH at %v: drops %s vs %s, blocked %s vs %s"
					% [spot, reach_whole, reach_scoped, blocked_whole, blocked_scoped])
		print("  scoped survey against the whole yard: %d of %d aim points differ  %s"
			% [mismatched, compared, "ok" if mismatched == 0 else "FAIL"])
		await get_tree().process_frame
		for _pass in 3:
			var t_ghost:= Time.get_ticks_usec()
			for _k in 10:
				tool._update_pole_ghost()
			var ms_ghost:= _ms(t_ghost) / 10.0

			var at: Vector3 = tool._post_ghost().global_position
			var t_survey:= Time.get_ticks_usec()
			for _k in 10:
				tool._survey_pole(at)
			var ms_survey:= _ms(t_survey) / 10.0
			var cands: Array [PowerPole] = []
			for pole in b.power_poles:
				if is_instance_valid(pole):
					cands.append(pole)
			var t_attach:= Time.get_ticks_usec()
			for _k in 10:
				b.grid.attach(cands)
			var ms_attach:= _ms(t_attach) / 10.0
			var t_wires:= Time.get_ticks_usec()
			for _k in 10:
				tool._draw_pole_ghost_wires()
			var ms_wires:= _ms(t_wires) / 10.0


			var t_list:= Time.get_ticks_usec()
			for _k in 10:
				b.grid.machines()
			var ms_list:= _ms(t_list) / 10.0
			var mach: Array = b.grid.machines()
			var t_bodies:= Time.get_ticks_usec()
			for m in mach:
				PowerGrid.own_bodies(m)
			var ms_bodies:= _ms(t_bodies)
			print("  _update_pole_ghost %6.2f ms a frame   (survey %.2f, ghost wires %.2f)"
				% [ms_ghost, ms_survey, ms_wires])


			print("      a whole yard attach, for comparison: %.2f ms (machines() %.2f for %d, own_bodies on all of them %.2f, the rest %.2f)"
				% [ms_attach, ms_list, mach.size(), ms_bodies,
					ms_attach - ms_list - ms_bodies])
			await get_tree().process_frame
		tool.set_mode(BuildTool.Mode.CONVEYOR)
		for _k in 4:
			await get_tree().process_frame

	print("")
	print("=== what the enclosed shell costs ===")
	var enclosed: Array [Conveyor] = []
	for c in b.conveyors:
		if is_instance_valid(c) and c is EnclosedConveyor:
			enclosed.append(c)
	print("  %d enclosed runs of %d runs" % [enclosed.size(), b.conveyors.size()])


	b._index_enclosed()
	var disagreed:= 0
	for c in enclosed:
		for at: Vector3 in [c.a, c.b, c.laid_start(), c.laid_end()]:
			var walk_s: Conveyor = null
			var walk_e: Conveyor = null
			for other in b.conveyors:
				if not (other is EnclosedConveyor and is_instance_valid(other)):
					continue
				if walk_s == null and (PointIndex.joins(other.a, at)
						or PointIndex.joins(other.laid_start(), at)):
					walk_s = other
				if walk_e == null and (PointIndex.joins(other.b, at)
						or PointIndex.joins(other.laid_end(), at)):
					walk_e = other
			if b._enclosed_starting_at(at) != walk_s or b._enclosed_ending_at(at) != walk_e:
				disagreed += 1
	print("  index against the walk: %d of %d ends disagree  %s"
		% [disagreed, enclosed.size() * 4, "ok" if disagreed == 0 else "FAIL"])
	if not enclosed.is_empty():
		if b._enclosed_kit == null:
			b._enclosed_kit = EnclosedConveyorKit.new()
		for _pass in 3:
			var t_ends:= Time.get_ticks_usec()
			b._index_enclosed()
			for c in enclosed:
				(c as EnclosedConveyor).set_open_ends(
					b._enclosed_ending_at(c.a) == null,
					b._enclosed_starting_at(c.b) == null)
			var ms_ends:= _ms(t_ends)
			var t_specs:= Time.get_ticks_usec()
			var specs: Array = []
			for c in enclosed:
				specs.append(b._enclosed_spec(c))
			var ms_specs:= _ms(t_specs)
			var t_net:= Time.get_ticks_usec()
			var built: Dictionary = b._enclosed_kit.build_network(specs)
			var ms_net:= _ms(t_net)
			var root:= built.get("root") as Node3D
			var kids:= root.get_child_count() if root != null else 0
			if root != null:
				root.free()
			b._enclosed_built = PackedVector3Array()
			var t_whole:= Time.get_ticks_usec()
			b._rebuild_enclosed_visuals()
			var ms_whole:= _ms(t_whole)
			var t_again:= Time.get_ticks_usec()
			b._rebuild_enclosed_visuals()
			var ms_again:= _ms(t_again)
			print("  open ends %6.2f  specs %.2f  build_network %7.2f (%d nodes)  whole rebuild %7.2f  unchanged rebuild %.2f ms"
				% [ms_ends, ms_specs, ms_net, kids, ms_whole, ms_again])
			await get_tree().physics_frame


		print("")
		print("=== how build_network grows ===")
		var all_specs: Array = []
		for c in enclosed:
			all_specs.append(b._enclosed_spec(c))
		for share: float in [0.25, 0.5, 0.75, 1.0]:
			var cut: Array = all_specs.slice(0, int(ceil(all_specs.size() * share)))


			b._enclosed_kit._bends.clear()
			var t_cut:= Time.get_ticks_usec()
			var out: Dictionary = b._enclosed_kit.build_network(cut)
			var ms_cut:= _ms(t_cut)
			var cut_root:= out.get("root") as Node3D
			var bends:= 0
			if cut_root != null:
				for kid in cut_root.get_children():
					if String(kid.name).begins_with("Bend_"):
						bends += 1
				cut_root.free()
			print("  %3d runs  %7.2f ms  %d swept bends  (%.3f ms a run)"
				% [cut.size(), ms_cut, bends, ms_cut / maxf(cut.size(), 1.0)])
			await get_tree().physics_frame


		var probe_arc: Dictionary = b._enclosed_kit._arc(
			Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 2))
		var t_bend:= Time.get_ticks_usec()
		for _k in 20:
			b._enclosed_kit._bend(probe_arc, false)
		print("  one swept bend mesh %.3f ms" % (_ms(t_bend) / 20.0))
		var t_curve:= Time.get_ticks_usec()
		for _k in 20:
			b._enclosed_kit._curve_error(Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 2))
		print("  one _curve_error    %.3f ms" % (_ms(t_curve) / 20.0))
		var dedup: Array [Vector3] = []
		var t_vertex:= Time.get_ticks_usec()
		for spec: Dictionary in all_specs:
			b._enclosed_kit._vertex(dedup, spec ["a"])
			b._enclosed_kit._vertex(dedup, spec ["b"])
		print("  the _vertex dedup   %.3f ms over %d endpoints, %d distinct"
			% [_ms(t_vertex), all_specs.size() * 2, dedup.size()])
		await get_tree().physics_frame


		print("")
		print("=== laying one enclosed run, part by part ===")
		var head:= TEST_ORIGIN + Vector3(14.0, 0.0, 0.0)
		for n in 3:
			var from:= head + Vector3(0.0, 0.0, - RUN_LENGTH * float(n))
			var to:= from + Vector3(0.0, 0.0, - RUN_LENGTH)
			var t_add:= Time.get_ticks_usec()
			var run:= b.add_enclosed_conveyor(from, to)
			var ms_add:= _ms(t_add)
			var t_apart:= Time.get_ticks_usec()
			var apart:= b.show_enclosed_apart([run] as Array [Node3D])
			var ms_apart:= _ms(t_apart)
			var t_back:= Time.get_ticks_usec()
			b.end_enclosed_show(apart)
			var ms_back:= _ms(t_back)


			var live:= 0
			if b._enclosed_visuals != null and is_instance_valid(b._enclosed_visuals):
				for kid in b._enclosed_visuals.get_children():
					if String(kid.name).begins_with("Bend_"):
						live += 1
			print("  #%d  add_enclosed_conveyor %7.2f   show_enclosed_apart %7.2f   end_enclosed_show %7.2f ms   = %.2f ms of one click   cache %d bends, %d standing, %.1f MB"
				% [n + 1, ms_add, ms_apart, ms_back, ms_add + ms_apart + ms_back,
					b._enclosed_kit._bends.size(), live,
					b._enclosed_kit._bends.size() * 117.4 / 1024.0])
			await get_tree().physics_frame

	print("")
	print("=== laying %d runs, one at a time ===" % PLACEMENTS)
	print("  #   runs   add_conveyor    worst of the %d frames after   (frame)" % AFTER)
	for n in PLACEMENTS:
		var from:= TEST_ORIGIN + Vector3(0.0, 0.0, - RUN_LENGTH * float(n))
		var to:= from + Vector3(0.0, 0.0, - RUN_LENGTH)
		var t_add:= Time.get_ticks_usec()
		b.add_conveyor(from, to)
		var ms_add:= _ms(t_add)


		if n >= PLACEMENTS / 2:
			b._grid_settle = 0
		var worst:= 0.0
		var worst_at:= -1
		var profile:= PackedStringArray()
		for k in AFTER:
			var t_frame:= Time.get_ticks_usec()
			await get_tree().physics_frame
			var ms_frame:= _ms(t_frame)
			profile.append("%.1f" % ms_frame)
			if ms_frame > worst:
				worst = ms_frame
				worst_at = k
		print("  %-3d %-6d %8.2f ms %18.2f ms %14d   %s"
			% [n + 1, b.conveyors.size(), ms_add, worst, worst_at,
				"GRID OFF  " if n >= PLACEMENTS / 2 else "grid on   "]
				+ " ".join(profile))


	print("")
	print("=== placing and dismantling other things ===")
	print("  case                         call ms   worst after   grid")
	for grid_on in [true, false]:
		var arm_at:= TEST_ORIGIN + Vector3(4.0, 0.0, -4.0 - (0.0 if grid_on else 6.0))
		var t_arm:= Time.get_ticks_usec()
		var arm:= b.add_robotic_arm(arm_at, 0.0)
		await _after_click("place arm", _ms(t_arm), grid_on)
		var t_arm_off:= Time.get_ticks_usec()
		b.demolish(arm)
		await _after_click("dismantle that arm", _ms(t_arm_off), grid_on)
		var run: Conveyor = null
		for c in b.conveyors:
			if is_instance_valid(c) and c.line_id == 0 and not (c is EnclosedConveyor) and c.global_position.distance_to(TEST_ORIGIN) > 20.0:
				run = c
				break
		if run != null:
			var t_run:= Time.get_ticks_usec()
			b.demolish(run)
			await _after_click("dismantle a yard belt", _ms(t_run), grid_on)
		var old_arm: RoboticArm = null
		for a in b.robotic_arms:
			if is_instance_valid(a):
				old_arm = a
				break
		if old_arm != null:
			var t_old:= Time.get_ticks_usec()
			b.demolish(old_arm)
			await _after_click("dismantle a yard arm", _ms(t_old), grid_on)
		var split: Node3D = null
		for s in b.splitters:
			if is_instance_valid(s):
				split = s
				break
		if split != null:
			var t_split:= Time.get_ticks_usec()
			b.demolish(split)
			await _after_click("dismantle a splitter", _ms(t_split), grid_on)


	print("")
	print("=== a new machine gets its draw distance ===")
	var mdd2:= world.get_node_or_null("MachineDrawDistance")
	var lamp:= b.add_work_lamp(TEST_ORIGIN + Vector3(6.0, 0.0, 6.0), 0.0)
	for _k in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	var parts:= 0
	var capped:= 0
	for node in lamp.find_children("*", "GeometryInstance3D", true, false):
		var g:= node as GeometryInstance3D
		if g == null:
			continue
		parts += 1
		if g.visibility_range_end > 0.0:
			capped += 1
	print("  distance setting %.0f m, lamp has %d visual parts, %d given a cutoff"
		% [Cfg.machine_distance_metres(), parts, capped])
	print("  %s" % ["ok" if (capped > 0 or Cfg.machine_distance_metres() == 0.0)
		else "FAIL: a newly placed machine was never walked"])
	if mdd2 != null:
		print("  root marked swept: %s" % mdd2._swept.has(lamp.get_instance_id()))


	print("")
	print("PIECES: a click lays one run per knee in its route, and every piece "
		+ "pays the whole table above again.")
	print("BUILDHITCH: done")
	get_tree().quit(0)


func _drops_on(survey: Dictionary, ghost: PowerPole) -> PackedStringArray:
	var out:= PackedStringArray()
	for record: Dictionary in (survey ["found"] as Dictionary).values():
		if record ["pole"] == ghost:
			out.append(String((record ["machine"] as Node3D).name))
	out.sort()
	return out


func _blocked_near(survey: Dictionary, ghost: PowerPole) -> PackedStringArray:
	var out:= PackedStringArray()
	for machine in survey ["unreachable"] as Array [Node3D]:
		if PowerGrid.in_reach(ghost, machine.global_position):
			out.append(String(machine.name))
	out.sort()
	return out


func _after_click(label: String, ms_call: float, grid_on: bool) -> void:
	var b: BuildManager = world.builds
	if not grid_on:
		b._grid_settle = 0
	var worst:= 0.0
	for _k in AFTER:
		var t_frame:= Time.get_ticks_usec()
		await get_tree().physics_frame
		worst = maxf(worst, _ms(t_frame))
	print("  %-26s %9.2f %12.2f   %s" % [label, ms_call, worst, "on" if grid_on else "OFF"])


func _ms(since_usec: int) -> float:
	return float(Time.get_ticks_usec() - since_usec) / 1000.0
