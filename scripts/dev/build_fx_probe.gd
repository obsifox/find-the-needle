class_name DevBuildFxProbe
extends Node


var STAND:= Vector3(11.0, 0.0, 11.0)
var EYE:= Vector3(17.0, 3.6, 17.0)

var world: Node3D
var player: Player
var _fails:= 0


func _pick_view() -> void:
	var space:= world.get_world_3d().direct_space_state
	var mask:= Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PILE
	var wall:= Warehouse.INNER - 1.5
	for i in 24:
		var corner:= Vector2.from_angle(TAU * float(i % 8) / 8.0)
		var out:= Vector3(corner.x, 0.0, corner.y)
		STAND = out * [11.0, 9.0, 13.0] [i / 8]


		EYE = STAND + out * 4.0 + Vector3(- out.z, 0.0, out.x) * 3.0
		EYE = Vector3(clampf(EYE.x, - wall, wall), 3.2, clampf(EYE.z, - wall, wall))
		var look:= STAND + Vector3(0.0, 1.4, 0.0)
		var clear:= true
		for probe_at: Vector3 in [look, STAND + Vector3(0.0, 0.3, 0.0),
				STAND + Vector3(0.0, 3.0, 0.0)]:
			var q:= PhysicsRayQueryParameters3D.create(EYE, probe_at, mask)
			if not space.intersect_ray(q).is_empty():
				clear = false
				break
		if clear:
			print("[buildfx] view from corner %s is clear" % [corner])
			return
	print("[buildfx] no clear view; using the last one anyway")


func run(out_dir: String) -> void:
	world.block_save = true


	Cfg.build_fx = true
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	await get_tree().process_frame
	if out_dir == "survey":
		await _survey()
		get_tree().quit(0)
		return
	if out_dir.begins_with("belt="):
		if DisplayServer.get_name() != "headless":
			await _belt_shots(out_dir.substr(5))
		get_tree().quit(0)
		return
	if out_dir.begins_with("splitters="):
		await _splitters(out_dir.substr(10))
		get_tree().quit(0)
		return
	if out_dir == "belts":
		await _belt_teardown()
		get_tree().quit(0)
		return
	if out_dir == "enclosed":
		await _enclosed_teardown()
		get_tree().quit(1 if _fails > 0 else 0)
		return
	if out_dir.begins_with("slope"):
		await _belt_slope_teardown(out_dir.contains("nofx"))
		get_tree().quit(0)
		return
	var shots:= out_dir != "" and DisplayServer.get_name() != "headless"
	_pick_view()
	_aim(EYE, STAND + Vector3(0.0, 1.4, 0.0))
	await get_tree().process_frame


	var caught: Array [Node] = []
	var catch:= func(n: Node) -> void: caught.append(n)
	builds.child_entered_tree.connect(catch)
	var press:= builds.add_compressor(STAND, 0.6)
	builds.child_entered_tree.disconnect(catch)
	_check(press != null, "compressor placed")

	var shadows:= _shadows(press)
	var fx:= tool.show_built(caught)
	_check(fx != null, "a click's worth of nodes starts the build show")

	var build_mat: Material = fx._mat if fx != null else null
	await get_tree().process_frame
	_check(fx != null and fx.progress() == 0.0 and _count(press, build_mat) > 0,
		"machine is hologram while the sparks are still in the air")
	await _until(fx, 0.35)
	_check(_ours(press, fx) > 0, "build overlay on the machine mid show (%d meshes)"
		% _ours(press, fx))
	if shots:
		await _capture(out_dir + "/build_35.png")
	await _until(fx, 0.75)
	if shots:
		await _capture(out_dir + "/build_75.png")
	await _until(fx, 1.0)
	for _i in 4:
		await get_tree().process_frame
	if shots:
		await _capture(out_dir + "/build_flash.png")
	await _gone(fx, 4.0)
	_check(not is_instance_valid(fx), "build show freed itself")


	_check(_count(press, build_mat) == 0, "no build material left on the machine")
	var after:= _shadows(press)
	_check(after.slice(0, shadows.size()) == shadows,
		"every shadow setting back after the build")
	var before:= _overlays(press)
	if shots:
		await _capture(out_dir + "/build_done.png")


	caught.clear()
	builds.child_entered_tree.connect(catch)
	var a:= STAND + Vector3(-4.0, 0.0, -3.0)
	var line:= 987001
	var first_run:= builds.add_conveyor(a, a + Vector3(4.0, 0.0, 0.0), line)
	builds.add_conveyor(a + Vector3(4.0, 0.0, 0.0), a + Vector3(4.0, 0.0, -4.0), line)
	builds.child_entered_tree.disconnect(catch)
	var belt_fx:= tool.show_built(caught)
	_check(belt_fx != null, "a laid run starts a show")
	if belt_fx != null:
		print("[buildfx] run caught %d nodes, show covers %d pieces"
			% [caught.size(), belt_fx._targets.size()])


	await get_tree().process_frame
	var deck:= first_run.get_node_or_null("Path/Sections") as GeometryInstance3D
	_check(deck != null and BeltBatch.instance != null and not BeltBatch.instance.holds(deck)
		and deck.layers != 0 and deck.material_override == belt_fx._mat,
		"belt deck lifted out of the batch mid show, wearing the hologram")
	caught.clear()
	builds.child_entered_tree.connect(catch)
	builds.rebuild_junctions()
	builds.child_entered_tree.disconnect(catch)
	print("[buildfx] bend rebuild added %d nodes" % caught.size())
	_check(tool.show_built(caught) == null, "a bend rebuild on its own starts nothing")
	await _gone(belt_fx, 4.0)
	deck = first_run.get_node_or_null("Path/Sections") as GeometryInstance3D
	_check(deck != null and BeltBatch.instance.holds(deck) and deck.layers == 0
		and deck.material_override == null, "belt deck back in the batch after the show")


	tool._wreck = press
	tool._wreck_time = BuildTool.DISMANTLE_HOLD * 0.8
	tool._tick_wreck_glow()
	_check(_count(press, tool._glow_mat) > 0, "hold glow on the machine")
	if shots:
		await _capture(out_dir + "/hold_glow.png")
	tool._wreck = null
	tool._tick_wreck_glow()
	_check(_overlays(press) == before, "every overlay back after the hold")


	var shown:= _shows()
	var refused:= BuildFx.wreck(world, [press] as Array [Node3D], player.camera)
	refused.abandon()
	await get_tree().process_frame
	_check(not is_instance_valid(refused), "an abandoned wreck frees itself")
	_check(_shows() == shown, "and leaves no show behind")


	caught.clear()
	builds.child_entered_tree.connect(catch)
	var brief:= builds.add_compressor(STAND + Vector3(0.0, 0.0, -5.0), 0.6)
	builds.child_entered_tree.disconnect(catch)
	var brief_fx:= tool.show_built(caught)
	_check(brief_fx != null, "a second machine starts its own build show")
	await get_tree().process_frame


	var doomed:= BuildFx.meshes_of(brief)
	tool.dismantle(brief)
	_check(not is_instance_valid(brief) or brief.is_queued_for_deletion(),
		"it is dismantled while its build show is still running")


	var still: int = 0
	for g in doomed:
		if is_instance_valid(g) and g.material_override == brief_fx._mat:
			still += 1
	_check(still == 0, "no show material left on a machine dismantled mid show (%d of %d)"
		% [still, doomed.size()])
	await _gone(brief_fx, 4.0)
	_check(not is_instance_valid(brief_fx), "the build show of a dismantled machine still ends")


	shown = _shows()
	tool._wreck = press
	tool._wreck_time = BuildTool.DISMANTLE_HOLD
	tool._tick_wreck_glow()
	var held:= BuildFx.meshes_of(press)
	var glow: ShaderMaterial = tool._glow_mat
	tool.dismantle(press)
	var lit: int = 0
	for g in held:
		if is_instance_valid(g) and g.material_overlay == glow:
			lit += 1
	_check(lit == 0, "no hold glow left on a machine that went down under it (%d of %d)"
		% [lit, held.size()])
	_check(not is_instance_valid(press) or press.is_queued_for_deletion(),
		"dismantle took the machine")
	var wreck: BuildFx = null
	for s in _shows():
		if not shown.has(s):
			wreck = s
	_check(wreck != null and wreck._copies.size() > 0,
		"dismantle left a hologram copy (%d meshes)"
		% (wreck._copies.size() if wreck != null else 0))
	await _until(wreck, 0.3)
	if shots:
		await _capture(out_dir + "/wreck_30.png")
	await _until(wreck, 0.7)
	if shots:
		await _capture(out_dir + "/wreck_70.png")
	await _gone(wreck, 4.0)
	_check(not is_instance_valid(wreck), "wreck show freed itself")

	print("[buildfx] %s, %d failed" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _belt_teardown() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	_pick_view()
	_aim(EYE, STAND)
	var lines: Array [Conveyor] = []
	for i in 5:
		var caught: Array [Node] = []
		var catch:= func(n: Node) -> void: caught.append(n)
		builds.child_entered_tree.connect(catch)
		var a:= STAND + Vector3(-6.0 + 2.5 * i, 0.0, -4.0)
		var line:= 987100 + i
		var first:= builds.add_conveyor(a, a + Vector3(0.0, 0.0, 4.0), line)
		builds.add_conveyor(a + Vector3(0.0, 0.0, 4.0), a + Vector3(1.5, 0.0, 6.0), line)
		builds.add_conveyor(a + Vector3(1.5, 0.0, 6.0), a + Vector3(1.5, 0.0, 9.0), line)
		builds.child_entered_tree.disconnect(catch)
		tool.show_built(caught)
		lines.append(first)
		await get_tree().process_frame
	print("[buildfx] belts: %d runs, %d bends" % [builds.conveyors.size(), builds.corners.size()])

	print("[buildfx] dismantle while its show runs")
	tool.dismantle(lines [4])
	await get_tree().process_frame
	for _i in 120:
		await get_tree().process_frame

	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	for i in 4:
		var a:= lines [i].a
		for k in 6:
			var at:= a + Vector3(0.0, 0.6, 0.6 + 0.6 * k)
			world.props.spawn("hay_wad", Transform3D(Basis(), at))
			world.live.spawn(at + Vector3(0.0, 0.4, 0.3),
				StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	for _i in 180:
		await get_tree().process_frame
	var riding:= 0
	for p in BeltPath._live:
		riding += (p as BeltPath)._riders.size()
	print("[buildfx] %d riders on the belts" % riding)
	print("[buildfx] dismantle one")
	tool.dismantle(lines [0])
	await get_tree().process_frame
	print("[buildfx] dismantle the next frame")
	tool.dismantle(lines [1])
	print("[buildfx] dismantle two in one frame")
	tool.dismantle(lines [2])
	tool.dismantle(lines [3])
	for _i in 240:
		await get_tree().process_frame
	print("[buildfx] belts: %d runs, %d bends left" % [builds.conveyors.size(), builds.corners.size()])


func _enclosed_teardown() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	_pick_view()
	_aim(EYE, STAND)
	var y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= STAND + Vector3(-5.0, y, -4.0)
	var line:= builds.new_line_id()
	var first:= builds.add_enclosed_conveyor(a, a + Vector3(0.0, 0.0, 5.0), line)
	builds.add_enclosed_conveyor(a + Vector3(0.0, 0.0, 5.0),
		a + Vector3(4.0, 0.0, 9.0), line)
	await get_tree().process_frame

	tool._wreck = first
	tool._tick_wreck_glow()
	_check(first.get_node_or_null("ShowShell") != null,
		"the hold gives the sealed line a shell of its own")
	var lit:= 0
	for g in BuildFx.meshes_of(first):
		if g.material_overlay != null:
			lit += 1
	_check(lit > 0, "the casing wears the hold glow (%d meshes)" % lit)

	tool._wreck = null
	tool._tick_wreck_glow()
	_check(first.get_node_or_null("ShowShell") == null,
		"the casing goes back into the yard's shell when the hold is let go")
	_check(builds._enclosed_visuals != null, "the yard's shell is back")

	tool.dismantle(first)
	var fx:= builds.get_parent().find_child("WreckFx", false, false) as BuildFx
	_check(fx != null and fx.get_child_count() > 0,
		"the wreck show copies the casing (%d meshes)"
			% (fx.get_child_count() if fx != null else 0))
	for _i in 4:
		await get_tree().process_frame
	_check(builds.conveyors.is_empty(), "the whole sealed line came down")
	_check(builds._enclosed_visuals == null,
		"no shell is left standing where the line was")
	if fx != null:
		await _gone(fx, 4.0)
	_check(not is_instance_valid(fx), "the wreck show freed itself")


func _belt_shots(dir: String) -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	_pick_view()
	var look:= STAND + Vector3(0.0, 0.5, 0.0)
	_aim(EYE, look)
	await get_tree().process_frame
	var side:= EYE - STAND
	side.y = 0.0
	var across:= Vector3(- side.z, 0.0, side.x).normalized()

	var deck:= Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)
	var caught: Array [Node] = []
	var catch:= func(n: Node) -> void: caught.append(n)
	builds.child_entered_tree.connect(catch)
	tool._lay_run(STAND - across * 2.5 + deck, STAND + across * 2.5 + deck)
	builds.child_entered_tree.disconnect(catch)
	var fx:= tool.show_built(caught)
	caught.clear()
	builds.child_entered_tree.connect(catch)
	builds.add_compressor(STAND - side.normalized() * 3.5, 0.0)
	builds.child_entered_tree.disconnect(catch)
	var press_fx:= tool.show_built(caught)
	if fx == null or press_fx == null:
		print("[buildfx] belt: NO SHOW (belt %s, press %s)" % [fx, press_fx])
		return
	await get_tree().process_frame
	await get_tree().process_frame
	print("[buildfx] belt axis %s  base %.2f  top %.2f  duration %.2f  lead %.2f  boxes %d"
		% [fx._axis, fx._base, fx._top, fx._duration, fx._lead, fx._boxes.size()])


	for show: BuildFx in [fx, press_fx]:
		show.set_process(false)
		show._mat.set_shader_parameter("front", show._top + 1.0)
	await _capture_at(dir + "/frozen_full.png", look)
	for show: BuildFx in [fx, press_fx]:
		show._mat.set_shader_parameter("front", (show._base + show._top) * 0.5)
	await _capture_at(dir + "/frozen_half.png", look)


	for n in world.find_children("*", "GeometryInstance3D", true, false):
		var g:= n as GeometryInstance3D
		if g is GPUParticles3D:
			continue
		var box:= g.global_transform * g.get_aabb()
		if box.get_center().distance_to(STAND) > 5.0 and g.global_position.distance_to(STAND) > 5.0:
			continue
		var mat:= "ours" if g.material_override == fx._mat or g.material_override == press_fx._mat else str(g.material_override)
		print("[buildfx]   %s  %s  vis %s  override %s  overlay %s  shadow %d  transp %.2f  layers %d"
			% [world.get_path_to(g), g.get_class(), g.is_visible_in_tree(), mat,
			g.material_overlay, g.cast_shadow, g.transparency, g.layers])

	for show: BuildFx in [fx, press_fx]:
		show.set_process(true)
	for mark: float in [0.3, 0.6, 0.9]:
		await _until(fx, mark)
		await _capture_at(dir + "/belt_%02d.png" % int(mark * 100.0), look)
	await _gone(fx, 4.0)
	await _capture_at(dir + "/belt_done.png", look)


func _survey() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	var belt:= Vector3(-12.0, 0.0, 10.0)
	var kinds: Array = [
		["belt", func(_at: Vector3) -> void: tool._lay_run(belt, belt + Vector3(4.0, 0.0, 0.0))],
		["belt chained leg", func(_at: Vector3) -> void: tool._lay_run(belt + Vector3(4.0, 0.0, 0.0), belt + Vector3(4.0, 0.0, 4.0))],
		["belt straight on", func(_at: Vector3) -> void: tool._lay_run(belt + Vector3(4.0, 0.0, 4.0), belt + Vector3(4.0, 0.0, 7.0))],
		["splitter", func(at: Vector3) -> void: builds.add_splitter(at, 0.0)],
		["joiner", func(at: Vector3) -> void: builds.add_joiner(at, 0.0)],
		["u splitter", func(at: Vector3) -> void: builds.add_u_splitter(at, 0.0)],
		["u joiner", func(at: Vector3) -> void: builds.add_u_joiner(at, 0.0)],
		["compressor", func(at: Vector3) -> void: builds.add_compressor(at, 0.0)],
		["pulper", func(at: Vector3) -> void: builds.add_pulper(at, 0.0)],
		["paper", func(at: Vector3) -> void: builds.add_paper(at, 0.0)],
		["briquette", func(at: Vector3) -> void: builds.add_briquette(at, 0.0)],
		["wrapper", func(at: Vector3) -> void: builds.add_wrapper(at, 0.0)],
		["silo", func(at: Vector3) -> void: builds.add_silo(at, 0.0)],
		["piston rake", func(at: Vector3) -> void: builds.add_piston_rake(at, 0.0)],
		["pelletizer", func(at: Vector3) -> void: builds.add_pelletizer(at, 0.0)],
		["hay stairs", func(at: Vector3) -> void: builds.add_hay_stairs(at, 0.0)],
		["hay lift", func(at: Vector3) -> void: builds.add_hay_lift(at, 0.0, 2)],
		["generator", func(at: Vector3) -> void: builds.add_generator(at, 0.0)],
		["borehole", func(at: Vector3) -> void: builds.add_borehole(at, 0.0)],
		["water main", func(at: Vector3) -> void: builds.add_water_main(at, at + Vector3(3.0, 0.0, 0.0))],
		["water splitter", func(at: Vector3) -> void: builds.add_water_splitter(at, 0.0)],
		["power pole", func(at: Vector3) -> void: builds.add_power_pole(at, 0.0)],
		["tube launcher", func(at: Vector3) -> void: builds.add_tube_launcher(at, 0.0)],
		["dump hatch", func(at: Vector3) -> void: builds.add_dump_hatch(at, 0.0)],
		["hay drone", func(at: Vector3) -> void: builds.add_hay_drone(at, 0.0)],
		["cabinet", func(at: Vector3) -> void: builds.add_cabinet(at, 0.0)],
		["needle radar", func(at: Vector3) -> void: builds.add_needle_radar(at, 0.0)],
		["paint board", func(at: Vector3) -> void: builds.add_paint_board(at, 0.0)],
		["work lamp", func(at: Vector3) -> void: builds.add_work_lamp(at, 0.0)],
		["robotic arm", func(at: Vector3) -> void: builds.add_robotic_arm(at, 0.0)],
		["scanner", func(at: Vector3) -> void: builds.add_scanner(at, 0.0)],
		["platform", func(at: Vector3) -> void: builds.add_platform(at + Vector3(0.0, 2.0, 0.0), Vector2(4.0, 4.0))],
		["railing", func(at: Vector3) -> void: builds.add_railing(at, at + Vector3(3.0, 0.0, 0.0))],
		["wall", func(at: Vector3) -> void: builds.add_wall(at, at + Vector3(3.0, 0.0, 0.0), YardWall.Bay.values() [0] as YardWall.Bay)],
		["roof", func(at: Vector3) -> void: builds.add_roof(at + Vector3(0.0, 3.0, 0.0), at + Vector3(3.0, 3.0, 0.0), Roof.Kind.values() [0] as Roof.Kind, 1)],
		["stair", func(at: Vector3) -> void: builds.add_stair(at + Vector3(0.0, 2.0, 0.0), 0.0, 2.0)],
	]
	for i in kinds.size():
		var what: String = kinds [i] [0]
		var at:= Vector3(-12.0 + float(i % 7) * 4.0, 0.0, -12.0 + float(i / 7) * 4.0)
		var caught: Array [Node] = []
		var catch:= func(n: Node) -> void: caught.append(n)
		builds.child_entered_tree.connect(catch)
		(kinds [i] [1] as Callable).call(at)
		builds.child_entered_tree.disconnect(catch)
		var fx:= tool.show_built(caught)
		if fx == null:
			print("[buildfx] survey %-18s NO SHOW  caught %d nodes" % [what, caught.size()])
			continue
		var mat: Material = fx._mat
		var frames:= 0
		var bare_frames:= 0
		var bare_max:= 0
		var lo:= 1 << 30
		var hi:= 0
		var bare_names:= { }
		while is_instance_valid(fx) and fx.progress() < 1.0:
			await get_tree().process_frame
			if not is_instance_valid(fx):
				break
			frames += 1
			var total:= 0
			var bare:= 0
			for t in fx._targets:
				if not is_instance_valid(t):
					continue
				for g in BuildFx.meshes_of(t):
					total += 1
					if g.material_override != mat and g.material_overlay != mat:
						bare += 1
						bare_names [String(t.name) + "/" + String(t.get_path_to(g))] = true
			lo = mini(lo, total)
			hi = maxi(hi, total)
			if bare > 0:
				bare_frames += 1
				bare_max = maxi(bare_max, bare)
		var travel:= (fx._top - fx._base) if is_instance_valid(fx) else -1.0
		var axis: Vector3 = fx._axis if is_instance_valid(fx) else Vector3.ZERO
		print("[buildfx] survey %-18s caught %d  pieces %d  meshes %d..%d  bare on %d/%d frames (max %d)  travel %.2f along %s  %s"
			% [what, caught.size(), fx._targets.size() if is_instance_valid(fx) else -1, lo, hi,
			bare_frames, frames, bare_max, travel, axis.snappedf(0.01),
			", ".join(bare_names.keys().slice(0, 4))])
		await _gone(fx, 4.0)


func _splitters(spec: String) -> void:


	var parts:= spec.split("|")
	var path:= parts [0]
	_noshow = parts.has("noshow")
	_trace = parts.has("trace")
	var out:= FileAccess.open(path, FileAccess.WRITE)
	_out = out
	_start_watchdog()
	_place_markers()
	if _trace:

		get_tree().process_frame.connect(_drive_shows)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	GameState.add_money(100000.0)
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.SPLITTER)
	tool._reach = 14.0
	_step(out, "start  display %s" % DisplayServer.get_name())

	for i in 4:
		var spot:= Vector3(-14.0 + 4.0 * float(i), 0.0, -11.0)
		await _click_splitter(out, "apart %d" % (i + 1), spot, spot + Vector3(0.0, 0.4, 3.0))
	await _watch_frames(out, "apart")


	var first:= Vector3(-14.0, 0.0, -4.0)
	await _click_splitter(out, "chain 1", first, first + Vector3(0.0, 0.4, -3.0))
	for i in 3:
		if builds.splitters.is_empty():
			break
		var prev: ConveyorSplitter = builds.splitters [builds.splitters.size() - 1]
		var mouth:= prev.port_left()
		var along:= prev.arm_travel(ConveyorSplitter.LEFT)
		var aim:= Vector3(mouth.x, 0.0, mouth.z) + along * 0.4
		var stand:= aim - along * 3.0 + Vector3(0.0, 0.4, 0.0)
		await _click_splitter(out, "chain %d" % (i + 2), aim, stand)
	await _watch_frames(out, "chain")


func _click_splitter(out: FileAccess, label: String, spot: Vector3, stand: Vector3) -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	player.global_position = stand
	_aim_eye(spot)
	for _f in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	var hit:= tool._raw_surface_hit()
	var hit_on: Node = hit.get("collider") as Node
	_step(out, "%s  ray on %s  normal %s  ghost ok=%s reason '%s'" % [label,
		hit_on.name if hit_on != null else "nothing",
		(hit.get("normal", Vector3.ZERO) as Vector3).snappedf(0.01),
		tool._eval.get("ok", false), tool._eval.get("reason", "")])
	var before:= builds.splitters.size()
	var t0:= Time.get_ticks_usec()
	if _noshow:
		tool._primary()
	else:
		tool.primary()
	_step(out, "%s  splitters %d -> %d  in %.1f ms  show %s" % [label, before,
		builds.splitters.size(), float(Time.get_ticks_usec() - t0) / 1000.0,
		"off" if _noshow else "on"])
	if _trace:
		_adopt_shows()


	_add_marker(world, "after the nodes %s added" % label)
	var tail: Array [String] = []
	var kids:= world.get_children()
	for k in range(maxi(0, kids.size() - 8), kids.size()):
		tail.append(String(kids [k].name))
	_step(out, "%s  world ends with: %s" % [label, ", ".join(tail)])
	await get_tree().process_frame
	_step(out, "%s  next frame reached" % label)


func _watch_frames(out: FileAccess, label: String) -> void:
	var last:= Time.get_ticks_usec()
	var worst:= 0.0
	for f in 600:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		var ms:= float(now - last) / 1000.0
		last = now
		worst = maxf(worst, ms)
		if ms > 50.0:
			_step(out, "frame %d took %.0f ms  shows alive %d" % [f, ms, _shows().size()])
	_step(out, "done  worst frame %.0f ms  shows alive %d" % [worst, _shows().size()])


func _aim_eye(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _step(out: FileAccess, line: String) -> void:
	print("[buildfx] " + line)
	if out == null:
		return
	_out_lock.lock()
	out.store_line(line)
	out.flush()
	_out_lock.unlock()


var _out: FileAccess
var _out_lock:= Mutex.new()

var _beat:= "none"
var _beat_at:= 0
var _beat_lock:= Mutex.new()
var _dog: Thread
var _dog_stop:= false
var _noshow:= false
var _trace:= false


class Marker extends Node:
	var probe: DevBuildFxProbe
	var label:= ""

	func _process(_delta: float) -> void:
		probe._mark(label)


func _place_markers() -> void:
	_interleave(get_tree().root, "/root")
	_interleave(world, "world")


func _interleave(parent: Node, where: String) -> void:
	var kids:= parent.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var k: Node = kids [i]
		if k is Marker:
			continue
		var m:= _new_marker("after %s/%s" % [where, k.name])
		parent.add_child(m)
		parent.move_child(m, k.get_index() + 1)
	var first:= _new_marker("start of %s" % where)
	parent.add_child(first)
	parent.move_child(first, 0)


var _driven: Array = []


func _adopt_shows() -> void:
	for c in world.get_children():
		var fx:= c as BuildFx
		if fx != null and not _driven.has(fx):
			fx.set_process(false)
			_driven.append(fx)


func _drive_shows() -> void:
	var delta:= get_process_delta_time()
	for n in _driven.size():

		var held = _driven [n]
		if not is_instance_valid(held) or (held as Node).is_queued_for_deletion():
			continue
		_drive_one(held as BuildFx, n + 1, delta)
	_mark("every show driven (its children process next)")


func _drive_one(fx: BuildFx, n: int, delta: float) -> void:
	var tag:= "show %d" % n
	fx._t += delta
	var aim:= fx._t / fx._duration
	var p:= (fx._t - fx._lead) / fx._duration
	fx._rescan_clock += delta
	if p < 1.0 and (fx._rescans < BuildFx.RESCAN_EAGER or fx._rescan_clock >= BuildFx.RESCAN):
		fx._rescans += 1
		fx._rescan_clock = 0.0
		_traced_rescan(fx, tag)
		_mark(tag + " _measure")
		fx._measure()
	if aim < 1.0:
		_mark(tag + " _spark_along_front")
		fx._spark_along_front(delta, fx._front_at(aim))
	elif fx._sparks.emitting:
		_mark(tag + " sparks off")
		fx._sparks.emitting = false
	_mark(tag + " set front")
	if p < 1.0:
		fx._set_front(maxf(p, 0.0))
		return
	var f:= (fx._t - fx._lead - fx._duration) / BuildFx.WRECK_TURN
	if f < 1.0:
		fx._set_front(1.0)
		fx._mat.set_shader_parameter("flash", f)
		return
	_traced_land(fx, tag)
	var s:= (f - 1.0) * BuildFx.WRECK_TURN / BuildFx.SETTLE
	if s < 1.0:
		fx._mat.set_shader_parameter("fade", pow(1.0 - s, 1.6) * 0.8)
		return
	_mark(tag + " _restore")
	fx._restore()
	_mark(tag + " queue_free")
	fx.queue_free()


func _traced_land(fx: BuildFx, tag: String) -> void:
	if fx._landed:
		return
	fx._landed = true
	_mark(tag + " _land shader parameters")
	fx._mat.set_shader_parameter("front", -10000.0)
	fx._mat.set_shader_parameter("dir", 1.0)
	fx._mat.set_shader_parameter("edge_gain", 0.0)
	fx._mat.set_shader_parameter("body", 0.0)
	fx._mat.set_shader_parameter("flash", 1.0)
	fx._mat.set_shader_parameter("fade", 0.8)
	_mark("%s _land _forget_gone (%d kept)" % [tag, fx._prev.size()])
	fx._forget_gone()
	_mark("%s _land walk (%d kept)" % [tag, fx._prev.size()])
	for k in fx._prev.keys():
		if not is_instance_valid(k):
			continue
		var g:= k as GeometryInstance3D
		var what:= "%s _land %s" % [tag, String(g.get_path())]
		var was: Array = fx._prev [k]
		_mark(what + " override")
		if g.material_override == fx._mat:
			g.material_override = was [0]
			if g.material_overlay == null:
				_mark(what + " overlay")
				g.material_overlay = fx._mat
		_mark(what + " cast_shadow")
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			g.cast_shadow = was [2]
	_mark(tag + " _land done")


func _traced_rescan(fx: BuildFx, tag: String) -> void:
	fx._boxes.clear()
	for ti in fx._targets.size():
		var b = fx._targets [ti]
		if not is_instance_valid(b):
			continue
		_mark("%s rescan target %d meshes_of" % [tag, ti])
		for g in BuildFx.meshes_of(b as Node):
			var what:= "%s rescan %s" % [tag, String((b as Node).get_path_to(g))]
			_mark(what + " _add_box (get_aabb)")
			fx._add_box(g)
			if fx._prev.has(g):
				continue
			_mark(what + " stash")
			fx._prev [g] = [g.material_override, g.material_overlay, g.cast_shadow]
			if BeltBatch.instance != null and BeltBatch.instance.holds(g):
				_mark(what + " BeltBatch.drop")
				BeltBatch.instance.drop(g)
				fx._lifted.append(g)
			_mark(what + " material_override")
			g.material_override = fx._mat
			g.material_overlay = null
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark(tag + " rescan done")


func _add_marker(parent: Node, label: String) -> void:
	parent.add_child(_new_marker(label))


func _new_marker(label: String) -> Marker:
	var m:= Marker.new()
	m.name = "WatchMarker"
	m.probe = self
	m.label = label
	return m


func _start_watchdog() -> void:
	get_tree().process_frame.connect(func() -> void: _mark("process_frame (node _process next)"))
	get_tree().physics_frame.connect(func() -> void: _mark("physics_frame (node _physics_process and the step next)"))
	RenderingServer.frame_pre_draw.connect(func() -> void: _mark("frame_pre_draw (drawing)"))
	RenderingServer.frame_post_draw.connect(func() -> void: _mark("frame_post_draw (drawn)"))
	_mark("watchdog start")
	_dog = Thread.new()
	_dog.start(_watch)


func _mark(what: String) -> void:
	_beat_lock.lock()
	_beat = what
	_beat_at = Time.get_ticks_usec()
	_beat_lock.unlock()


func _watch() -> void:
	var told:= 0
	while not _dog_stop:
		OS.delay_msec(250)
		_beat_lock.lock()
		var what:= _beat
		var at:= _beat_at
		_beat_lock.unlock()
		var stalled:= float(Time.get_ticks_usec() - at) / 1000000.0
		if stalled < 3.0:
			told = 0
			continue


		if told == 0 or stalled >= 3.0 + 5.0 * float(told):
			told += 1
			_step(_out, "STALL  main thread %.1f s past '%s'" % [stalled, what])


func _exit_tree() -> void:
	_dog_stop = true
	if _dog != null and _dog.is_started():
		_dog.wait_to_finish()


func _check(ok: bool, what: String) -> void:
	print("[buildfx] %6d ms  %s  %s" % [Time.get_ticks_msec(), "ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _shows() -> Array [BuildFx]:
	var out: Array [BuildFx] = []
	for n in world.get_children():
		if n is BuildFx and not n.is_queued_for_deletion():
			out.append(n as BuildFx)
	return out


func _overlays(root: Node) -> Array:
	var out:= []
	for g in BuildFx.meshes_of(root):
		out.append(g.material_overlay)
	return out


func _shadows(root: Node) -> Array:
	var out:= []
	for g in BuildFx.meshes_of(root):
		out.append(g.cast_shadow)
	return out


func _ours(root: Node, fx: BuildFx) -> int:
	if not is_instance_valid(fx):
		return 0
	return _count(root, fx._mat)


func _count(root: Node, mat: Material) -> int:
	var n:= 0
	for g in BuildFx.meshes_of(root):
		if mat != null and (g.material_overlay == mat or g.material_override == mat):
			n += 1
	return n


func _until(fx: BuildFx, p: float) -> void:
	for _i in 600:
		if not is_instance_valid(fx) or fx.progress() >= p:
			return
		await get_tree().process_frame


func _gone(fx: BuildFx, seconds: float) -> void:
	var start:= Time.get_ticks_msec()
	while is_instance_valid(fx) and Time.get_ticks_msec() - start < seconds * 1000.0 * 4.0:
		await get_tree().process_frame


func _aim(eye: Vector3, look: Vector3) -> void:
	player.global_position = eye
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)
	if flat.length_squared() < 1e-06:
		flat = Vector3.FORWARD
	player.look_at_from_position(eye, eye + flat, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = atan2(look.y - eye.y, maxf(flat.length(), 0.001))


func _capture(path: String) -> void:
	await _capture_at(path, STAND + Vector3(0.0, 1.4, 0.0))


func _capture_at(path: String, look: Vector3) -> void:
	_aim(EYE, look)
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[buildfx] shot %s" % path)


func _belt_slope_teardown(no_fx: bool) -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	Cfg.build_fx = not no_fx
	_pick_view()
	_aim(EYE, STAND)
	var props: PropManager = world.props
	print("[slope] build_fx=%s" % Cfg.build_fx)
	for pass_i in 2:
		var kind:= "hay_tuft" if pass_i == 0 else "eco_brick"
		var caught: Array [Node] = []
		var catch:= func(n: Node) -> void: caught.append(n)
		builds.child_entered_tree.connect(catch)


		var base:= STAND + Vector3(-5.0 + 7.0 * pass_i, 0.35, -5.0)
		var line:= 987200 + pass_i
		var p0:= base
		var p1:= base + Vector3(0.0, 0.9, 4.0)
		var p2:= base + Vector3(1.2, 1.9, 7.5)
		var p3:= base + Vector3(1.2, 2.6, 11.0)
		var p4:= base + Vector3(3.0, 3.4, 14.0)
		var p5:= base + Vector3(3.0, 4.0, 17.0)
		var first:= builds.add_conveyor(p0, p1, line)
		var second:= builds.add_conveyor(p1, p2, line)
		builds.add_conveyor(p2, p3, line)
		builds.add_conveyor(p3, p4, line)
		builds.add_conveyor(p4, p5, line)
		builds.child_entered_tree.disconnect(catch)
		tool.show_built(caught)
		for _i in 90:
			await get_tree().process_frame

		for k in 24:
			var t: float = float(k % 12) / 12.0
			var at: Vector3 = p0.lerp(p5, t) + Vector3(0.0, 0.5, 0.0)
			var made:= props.spawn(kind, Transform3D(Basis(), at),
				{ "strands": 40 } if kind == "hay_tuft" else { })
			if made == null:
				print("[slope] %s would not spawn" % kind)
			for _i in 6:
				await get_tree().process_frame
		for _i in 120:
			await get_tree().process_frame
		var riding:= 0
		for p in BeltPath._live:
			riding += (p as BeltPath)._riders.size()
		print("[slope] %s: %d riders on the climb, %d runs, %d bends"
			% [kind, riding, builds.conveyors.size(), builds.corners.size()])
		print("[slope] dismantle the climb with %s on it" % kind)


		tool._wreck = first
		tool._wreck_time = BuildTool.DISMANTLE_HOLD * 0.9
		tool._tick_wreck_glow()
		print("[slope] glow on %d meshes" % tool._glow_prev.size())


		for k in 4:
			props.spawn(kind, Transform3D(Basis(), p0 + Vector3(0.0, 0.6, 0.0)),
				{ "strands": 40 } if kind == "hay_tuft" else { })
			await get_tree().process_frame
		tool.dismantle(first)


		print("[slope] second helping: valid=%s queued=%s inside=%s"
			% [is_instance_valid(second), second.is_queued_for_deletion(),
				second.is_inside_tree()])
		builds.demolish(second)
		print("[slope] second helping done")
		tool._wreck = null
		tool._tick_wreck_glow()
		for _i in 240:
			await get_tree().process_frame
		print("[slope] %s: survived, %d runs, %d bends left"
			% [kind, builds.conveyors.size(), builds.corners.size()])
	print("[slope] done")
