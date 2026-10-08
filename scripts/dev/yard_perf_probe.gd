class_name DevYardPerfProbe
extends Node


var world: Node3D
var player: Player


const SETTLE:= 45


const SAMPLE:= 90


const MIN_CLASS:= 4


const WARMUP:= 180

var _env: Environment
var _sun: DirectionalLight3D
var _cam: Camera3D
var _rows: Array [Dictionary] = []


var _hidden: Array [Node3D] = []
var _silenced: Array [Dictionary] = []


var _stilled: Array [AnimationMixer] = []

var _uncasted: Array [Dictionary] = []


var _ranged: Array [Dictionary] = []
var _graphics: Dictionary = { }
var _sample_count:= SAMPLE
var _benchmark_path:= ""
var _benchmark_source:= ""
var _benchmark_samples: Array [Dictionary] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	assert (world.block_save, "yard benchmark must block saving before initialization")
	world.block_save = true
	var ua:= OS.get_cmdline_user_args()
	Cfg.perf_scale = 1.0
	Cfg.detail_scale = 1.0
	world._apply_render_settings()
	var samples:= ua.find("--samples")
	if samples >= 0 and samples + 1 < ua.size():
		_sample_count = maxi(int(ua [samples + 1]), 90)


	world.builds.grid.unmetered = "--unmetered" in ua
	world.builds.water.unmetered = "--unmetered" in ua
	var i:= ua.find("--yardperf")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	_benchmark_source = path
	var report_at:= ua.find("--benchmark-report")
	if report_at >= 0 and report_at + 1 < ua.size():
		_benchmark_path = ProjectSettings.globalize_path(ua [report_at + 1]).replace("\\", "/").simplify_path()
		var scratch:= ProjectSettings.globalize_path("res://.scratchpad/").replace("\\", "/")
		assert (_benchmark_path.to_lower().begins_with(scratch.to_lower()),
			"benchmark reports belong in the project scratchpad")
	if path == "" or not FileAccess.file_exists(path):
		print("YARDPERF: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("YARDPERF: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	var meta: Dictionary = d.get("meta", { })
	print("YARDPERF: '%s' on %s, save version %d, %d buildings, %d props, block_save=%s"
		% [str(meta.get("name", "")), str(meta.get("map", "warehouse")),
			int(d.get("version", 0)), (d.get("buildings", []) as Array).size(),
			(d.get("props", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	if "--deterministic-benchmark" in ua:
		seed(20260917)
		world.live._rng.seed = 20260917
		world.props._spill_rng = RandomNumberGenerator.new()
		world.props._spill_rng.seed = 20260917
		print("YARDPERF: deterministic random streams, physics ticks %d" % Engine.get_physics_ticks_per_second())


	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		world.field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))


	var saved_ranks: Dictionary = (d.get("tech", { }) as Dictionary).get("ranks", { })
	if int(saved_ranks.get("belt_speed", 0)) > 0:
		Tech.ranks ["belt_speed"] = int(saved_ranks ["belt_speed"])
	world.builds.from_array(d.get("buildings", []))


	world.props.from_array(d.get("props", []))


	var belts: Dictionary = d.get("belts", { })
	if not belts.is_empty():
		var back:= BeltPath.belts_from_array(belts.get("paths", []), world.props)
		print("YARDPERF: belts section restored, %s" % str(back))


	var restored: int = world.props.items.size()
	if restored > Cfg.prop_cap:
		print("YARDPERF: prop cap lifted from %d to %d, so the yard stops draining"
			% [Cfg.prop_cap, restored])
		Cfg.prop_cap = restored
	var where: Transform3D = d.get("player", Transform3D.IDENTITY)
	for k in WARMUP:
		await get_tree().process_frame

	_open_the_taps()


	if not "--live" in ua:
		_hide_the_hud()
	var bundle:= _bundle_camera(ua)
	if bundle == Transform3D.IDENTITY:
		_park_the_camera(where)
	else:
		_park_the_camera(bundle, true)
	if not _find_the_switches():
		get_tree().quit(1)
		return
	_say_the_state()
	_count_the_yard()


	if "--nolod" in ua:
		Cfg.yard_shadow_distance = 1000000000.0
		print("YARDPERF: ShadowLod gated out, everything casts")


	if "--ambient" in ua:
		var a:= ua.find("--ambient")
		_env.ambient_light_energy = float(ua [a + 1]) if a + 1 < ua.size() else 0.35
		print("YARDPERF: ambient forced to %.2f" % _env.ambient_light_energy)


	if "--shadowdist" in ua:
		var k2:= ua.find("--shadowdist")
		_sun.directional_shadow_max_distance = float(ua [k2 + 1]) if k2 + 1 < ua.size() else 40.0
		print("YARDPERF: shadows re-aimed to %.0f m" % _sun.directional_shadow_max_distance)


	if "--sunthrough" in ua:
		var plaza: Node = world.get("plaza")
		var massing: Node = plaza.get("massing") if plaza != null else null
		var n:= 0
		if massing != null:
			var stack: Array [Node] = [massing]
			while not stack.is_empty():
				var node: Node = stack.pop_back()
				var gi:= node as GeometryInstance3D
				if gi != null:
					gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					n += 1
				for kid: Node in node.get_children():
					stack.append(kid)
		print("YARDPERF: %d massing meshes stopped casting" % n)


	if "--sunbias" in ua:
		var b:= ua.find("--sunbias")
		_sun.shadow_bias = float(ua [b + 1]) if b + 1 < ua.size() else 0.02
		_sun.shadow_normal_bias = float(ua [b + 2]) if b + 2 < ua.size() else 0.7
		print("YARDPERF: bias %.4f, normal bias %.4f"
			% [_sun.shadow_bias, _sun.shadow_normal_bias])


	if "--gi" in ua:
		_env.sdfgi_enabled = true
		print("YARDPERF: SDFGI forced on")
	if "--shot" in ua:
		var j:= ua.find("--shot")
		var dir: String = ua [j + 1] if j + 1 < ua.size() else "user://yardshot"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


		for k in 120:
			await get_tree().process_frame
		var img:= get_viewport().get_texture().get_image()
		var out:= "%s/%s.png" % [dir, str(meta.get("map", "warehouse"))]
		img.save_png(out)
		print("YARDPERF: %s" % ProjectSettings.globalize_path(out))
		get_tree().quit(0)
		return


	if "--script-profile" in ua and EngineDebugger.has_profiler("scripts"):
		EngineDebugger.profiler_enable("scripts", true)
	_capture_graphics()
	if "--autosave-every" in ua:
		_autosave_every(float(ua [ua.find("--autosave-every") + 1]))
	if "--all-model-gallery" in ua:
		await preload("res://scripts/dev/all_model_gallery_probe.gd").new().run(self)
		return
	var compare_source_culling:= "--compare-source-culling" in ua
	var compare_shadow_cascades:= "--compare-shadow-cascades" in ua

	var compare_frame_tick:= "--compare-frame-tick" in ua
	var palette_compare: RefCounted = null
	var model_compare: RefCounted = null
	if "--compare-model-surfaces" in ua:
		model_compare = preload("res://scripts/dev/yard_model_surface_compare.gd").new()
		model_compare.prepare(self)
	if "--compare-palette" in ua:
		var reference_at:= ua.find("--palette-before")
		assert (reference_at >= 0 and reference_at + 1 < ua.size(), "palette comparison needs its original scene")
		palette_compare = preload("res://scripts/dev/yard_palette_compare.gd").new()
		palette_compare.prepare(self, ua [reference_at + 1])
	var native_shadow_mode:= _sun.directional_shadow_mode
	if compare_source_culling:
		BeltBatch.source_culling_enabled = false
		if BeltBatch.instance != null:
			BeltBatch.instance.refresh_source_culling()
	print("YARDPERF: unmetered=%s, %d frames per sample"
		% [world.builds.grid.unmetered, _sample_count])
	await _row("everything on (baseline)", func() -> void: pass)


	if "--toolcost" in ua:
		await preload("res://scripts/dev/yard_tool_cost.gd").new().run(self)
		if not "--hunt" in ua:
			get_tree().quit(0)
			return


	if "--portcheck" in ua:
		var port_fails: int = await preload("res://scripts/dev/port_index_check.gd").new().run(world, player.build)
		get_tree().quit(1 if port_fails > 0 else 0)
		return


	if "--memocheck" in ua:
		var memo_fails: int = await preload("res://scripts/dev/yard_memo_check.gd").new().run(world, player.build)
		get_tree().quit(1 if memo_fails > 0 else 0)
		return


	if "--sampleevery" in ua:
		var at_s:= ua.find("--sampleevery")
		var every:= float(ua [at_s + 1]) if at_s + 1 < ua.size() else 60.0
		var times:= int(ua [at_s + 2]) if at_s + 2 < ua.size() else 10
		var t0:= Time.get_ticks_msec()
		for n in times:
			var sampler:= FrameSampler.new()
			add_child(sampler)
			await sampler.finished
			print("\n[sampleevery] t=%.0f s, live %d, props %d, on belts %d\n%s" % [
				(Time.get_ticks_msec() - t0) / 1000.0, world.live.active_count(),
				world.props.items.size(), BeltPath.records_aboard(),
				"\n".join(sampler.report())])
			sampler.queue_free()
			await get_tree().create_timer(every).timeout
		get_tree().quit(0)
		return
	if "--motioncheck" in ua:
		await preload("res://scripts/dev/yard_motion_check.gd").new().run(self)
		get_tree().quit(0)
		return
	if "--repro" in ua:
		await world._write_repro()
		print("\n[yardperf] repro written")
		get_tree().quit(0)
		return

	if "--drawcensus" in ua:
		var dc = preload("res://scripts/dev/yard_draw_census.gd").new()
		dc.run(self)
		dc.processing(self)
		dc.lights(self)
		dc.shadowed_lamps(self)
		dc.viewports(self)
		dc.heavy_meshes(self)
		get_tree().quit(0)
		return


	if "--lodpairs" in ua:
		await _settle_draws()
		var vp_l:= get_viewport()
		var was_l:= vp_l.mesh_lod_threshold
		var said_l: Array [String] = []
		for px: float in [4.0, 8.0]:
			var r_px:= await _toggle_pairs("lod threshold %d px" % int(px), 3,
				func(on: bool) -> void: vp_l.mesh_lod_threshold = px if on else was_l)
			said_l.append("lod threshold %d px: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"
				% [int(px), r_px ["saved"], r_px ["on"], r_px ["off"], r_px ["spread"]])
		print("")
		for line in said_l:
			print(line)
		get_tree().quit(0)
		return


	if "--lightpairs" in ua:
		var lc = preload("res://scripts/dev/yard_draw_census.gd").new()
		await _settle_draws()
		var tests:= [["lamp shadows off", lc.lamp_shadows], ["lamps off", lc.lamps],
			["every caster off", lc.casters]]
		var said: Array [String] = []
		for t: Array in tests:
			var fn: Callable = t [1]
			var r_t:= await _toggle_pairs(t [0], 3, func(on: bool) -> void: fn.call(self, on))
			said.append("%s: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"
				% [t [0], r_t ["saved"], r_t ["on"], r_t ["off"], r_t ["spread"]])
		print("")
		for line in said:
			print(line)
		get_tree().quit(0)
		return


	if "--genlightpairs" in ua:
		var fires: Array [OmniLight3D] = []
		for root: Node3D in world.builds.every_placed():
			if root is HayGenerator and root._fire_light != null:
				fires.append(root._fire_light)
		await _settle_draws()
		var lit:= fires.filter(func(l: OmniLight3D) -> bool: return l.visible).size()
		print("[genlightpairs] %d generator fire lights, %d lit" % [fires.size(), lit])
		var said_g: Array [String] = []
		for fade: Array in [["fade 35 m", 35.0, 10.0], ["all out", 0.0, 0.01]]:
			var r_g:= await _toggle_pairs("generator lights " + str(fade [0]), 3,
				func(on: bool) -> void:
					for l in fires:
						l.distance_fade_enabled = on
						l.distance_fade_begin = fade [1]
						l.distance_fade_length = fade [2])
			said_g.append("generator lights %s: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"
				% [fade [0], r_g ["saved"], r_g ["on"], r_g ["off"], r_g ["spread"]])
		print("")
		for line in said_g:
			print(line)
		get_tree().quit(0)
		return


	if "--nodecensus" in ua:
		var per:= { }
		var kinds:= { }
		var in_built:= 0
		for root: Node3D in world.builds.every_placed():
			var sc:= root.get_script() as Script
			var key:= sc.resource_path.get_file().get_basename() if sc != null else root.get_class()
			if not per.has(key):
				per [key] = [0, 0]
			per [key] [0] += 1
			var stack: Array [Node] = [root]
			while not stack.is_empty():
				var node: Node = stack.pop_back()
				for kid: Node in node.get_children():
					stack.append(kid)
				per [key] [1] += 1
				in_built += 1
				var c:= node.get_class()
				kinds [c] = int(kinds.get(c, 0)) + 1
				var col:= ["Area3D", "CollisionShape3D", "StaticBody3D", "MeshInstance3D", "MultiMeshInstance3D", "AnimationPlayer"].find(c)
				if col >= 0:
					if per [key].size() < 8:
						per [key].append_array([0, 0, 0, 0, 0, 0])
					per [key] [2 + col] += 1
		var total:= get_tree().get_node_count()
		print("\nNODECENSUS %d nodes in the tree, %d under placed buildings" % [total, in_built])
		var keys_n: Array = per.keys()
		keys_n.sort_custom(func(a: String, b: String) -> bool: return per [a] [1] > per [b] [1])
		for k: String in keys_n:
			var e: Array = per [k] if (per [k] as Array).size() >= 8 else per [k] + [0, 0, 0, 0, 0, 0]
			print("  %-24s %4d built %6d nodes %6.1f each | area %5.1f shape %5.1f static %5.1f mesh %5.1f mm %5.1f anim %4.1f" % [k, e [0], e [1], float(e [1]) / e [0],
				float(e [2]) / e [0], float(e [3]) / e [0], float(e [4]) / e [0], float(e [5]) / e [0], float(e [6]) / e [0], float(e [7]) / e [0]])
		var keys_c: Array = kinds.keys()
		keys_c.sort_custom(func(a: String, b: String) -> bool: return kinds [a] > kinds [b])
		print("  by class:")
		for c: String in keys_c.slice(0, 20):
			print("  %-28s %7d" % [c, kinds [c]])
		get_tree().quit(0)
		return


	if "--procpairs" in ua:
		var np:= 3
		var at_p:= ua.find("--procpairs")
		if at_p + 1 < ua.size() and ua [at_p + 1].is_valid_int():
			np = int(ua [at_p + 1])
		var groups:= { }
		var todo: Array [Node] = [get_tree().root]
		while not todo.is_empty():
			var node: Node = todo.pop_back()
			for kid: Node in node.get_children():
				todo.append(kid)
			if node == self:
				continue
			var mixer:= node as AnimationMixer
			var playing:= mixer != null and mixer.active and (mixer is AnimationTree or (mixer as AnimationPlayer).is_playing())
			var key:= ""
			if playing:
				key = "mixers of " + _owner_script(node)
			elif node.is_processing() or node.is_physics_processing():
				var sc:= node.get_script() as Script
				key = sc.resource_path.get_file().get_basename() if sc != null else node.get_class()
			else:
				continue
			if not groups.has(key):
				groups [key] = []
			(groups [key] as Array).append(node)
		var skip:= ["factory_clock", "player", "world"]
		var keys: Array = groups.keys().filter(func(k: String) -> bool: return not k in skip)
		keys.sort_custom(func(a: String, b: String) -> bool:
			return (groups [a] as Array).size() > (groups [b] as Array).size())
		await _settle_draws()
		var said_p: Array [String] = []
		for k: String in keys:
			var nodes: Array = groups [k]
			var r_p:= await _toggle_pairs("%s (%d)" % [k, nodes.size()], np,
				func(on: bool) -> void:
					if on:
						_silence_or_still(nodes))
			said_p.append("PROCPAIR %+.3f ms  spread %.3f  on %.2f off %.2f  %s (%d)"
				% [r_p ["saved"], r_p ["spread"], r_p ["on"], r_p ["off"], k, nodes.size()])
		print("")
		for line in said_p:
			print(line)
		get_tree().quit(0)
		return


	if "--leakfix" in ua:
		var census_l = preload("res://scripts/dev/yard_draw_census.gd").new()
		var lod_l = world.shadow_lod
		await _settle_draws()
		var r_l:= await _toggle_pairs("three leaks fixed", 4,
			func(on: bool) -> void:
				census_l.share(self, on)
				census_l.hide_empty(self, on)
				world.shadow_lod = null if on else lod_l)
		print("\r\nthree leaks: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"

			% [r_l ["saved"], r_l ["on"], r_l ["off"], r_l ["spread"]])
		get_tree().quit(0)
		return

	if "--emptymm" in ua:
		var census_e = preload("res://scripts/dev/yard_draw_census.gd").new()
		await _settle_draws()
		var r_e:= await _toggle_pairs("empty multimeshes hidden", 3,
			func(on: bool) -> void: census_e.hide_empty(self, on))
		print("\r\nempty multimeshes: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"

			% [r_e ["saved"], r_e ["on"], r_e ["off"], r_e ["spread"]])
		get_tree().quit(0)
		return

	if "--sharedmats" in ua:
		var census = preload("res://scripts/dev/yard_draw_census.gd").new()
		await _settle_draws()
		var r:= await _toggle_pairs("shared machine materials", 4,
			func(on: bool) -> void: census.share(self, on))
		print("\r\nshared materials: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"

			% [r ["saved"], r ["on"], r ["off"], r ["spread"]])
		print("\r\n[yardperf] done")
		get_tree().quit(0)
		return
	if "--machine-census" in ua:
		if "--machine-distance-check" in ua:
			var check = preload("res://scripts/dev/machine_draw_distance_probe.gd").new()
			var passed: bool = await check.run(self)
			get_tree().quit(0 if passed else 1)
			return
		var census = preload("res://scripts/dev/yard_machine_census.gd").new()
		var types: Array [Dictionary] = census.count(self)
		if not "--census-only" in ua:
			await census.measure(self, types)
		_report()
		get_tree().quit(0)
		return
	if "--baseline" in ua:
		var legs:= 2
		var pair_i:= ua.find("--baseline-pairs")
		if pair_i >= 0 and pair_i + 1 < ua.size():
			legs = maxi(2, int(ua [pair_i + 1]) * 2)
		for leg in range(1, legs):
			if model_compare != null:
				await _row("model surfaces %s (%d/%d)" % ["after" if leg % 2 == 1 else "before", leg + 1, legs], func() -> void: model_compare.apply(leg % 2 == 1))
			elif palette_compare != null:
				await _row("pulper palette %s (%d/%d)" % ["after" if leg % 2 == 1 else "before", leg + 1, legs], func() -> void: palette_compare.apply(leg % 2 == 1))
			elif compare_frame_tick:
				await _row("frame tick %s (%d/%d)" % ["off" if leg % 2 == 1 else "on", leg + 1, legs], func() -> void: BeltPath.frame_tick_enabled = leg % 2 == 0)
			elif compare_shadow_cascades:
				await _row("shadow cascades %s (%d/%d)" % ["two" if leg % 2 == 1 else "native", leg + 1, legs], func() -> void:
					_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if leg % 2 == 1 else native_shadow_mode)
			elif compare_source_culling:
				await _row("belt source culling %s (%d/%d)" % ["on" if leg % 2 == 1 else "off", leg + 1, legs], func() -> void:
					BeltBatch.source_culling_enabled = leg % 2 == 1
					if BeltBatch.instance != null:
						BeltBatch.instance.refresh_source_culling())
			else:
				await _row("everything on (baseline %d/%d)" % [leg + 1, legs], func() -> void: pass)
		if "--script-profile" in ua and EngineDebugger.is_profiling("scripts"):
			EngineDebugger.profiler_enable("scripts", false)
		if "--frame-shot" in ua:
			var shot_i:= ua.find("--frame-shot")
			if shot_i + 1 < ua.size():
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ua [shot_i + 1])
		print("\n[yardperf] baseline done")
		get_tree().quit(0)
		return

	if "--hunt" in ua:
		await preload("res://scripts/dev/yard_fps_hunt.gd").new().run(self)
		get_tree().quit(0)
		return


	if "--clippairs" in ua:
		await _settle_draws()
		var c:= MachineLod.census()
		print("[yardperf] machines watched %d, far now %d" % [c [0], c [1]])
		var r:= await _toggle_pairs("distant clips stopped", 8,
			func(on: bool) -> void: MachineLod.set_clip_sleep(on))
		print("\r\nclip sleep: %+.2f ms a frame saved (on %.2f, off %.2f, pair spread %.2f)"

			% [r ["saved"], r ["on"], r ["off"], r ["spread"]])
		print("\r\n[yardperf] done")
		get_tree().quit(0)
		return
	if "--class-bisect" in ua:
		await _class_bisect()
		get_tree().quit(0)
		return
	if "--diagnose" in ua:
		await _row("48 arms silenced", func() -> void:
			_silence_all(world.builds.robotic_arms))
		await _row("pile updates silenced", func() -> void:
			_silence_all([world.field]))
		await _row("belts silenced", func() -> void:
			_silence_all(_belt_nodes()))
		await _row("cargo hidden", func() -> void:
			_hide_all(_prop_nodes()))
		await _row("everything on (baseline, again)", func() -> void: pass)
		_report()
		get_tree().quit(0)
		return


	await _row("props hidden (%d)" % world.props.items.size(),
		func() -> void: _hide_all(_prop_nodes()))
	await _row("props asleep", func() -> void: _sleep_the_props())
	await _row("props gone (hidden and asleep)", func() -> void:
		_hide_all(_prop_nodes())
		_sleep_the_props())


	for entry: Array in _prop_classes():
		var kind: String = entry [0]
		var nodes: Array = entry [1]
		if nodes.size() < MIN_CLASS:
			continue
		var hide_them:= func() -> void: _hide_all(nodes)
		await _row("   %s hidden (%d)" % [kind, nodes.size()], hide_them)
		var uncast_them:= func() -> void: _uncast(nodes)
		await _row("   %s casts no shadow" % kind, uncast_them)


	var wads:= _prop_nodes()
	if _wad_levels_present(wads):
		var tighter:= func() -> void: _scale_wad_lods(0.5)
		await _row("   wad levels handed over at half the range", tighter)
		var pinned:= func() -> void: _pin_wads_to_last()
		await _row("   every wad at its coarsest level", pinned)

	await _row("belts hidden (%d runs, %d corners)"
			% [world.builds.conveyors.size(), world.builds.corners.size()],
		func() -> void: _hide_all(_belt_nodes()))
	await _row("belts silenced", func() -> void: _silence_all(_belt_nodes()))
	await _row("machines hidden (%d)" % _machine_nodes().size(),
		func() -> void: _hide_all(_machine_nodes()))
	await _row("machines silenced", func() -> void: _silence_all(_machine_nodes()))
	await _row("poles and lines hidden (%d)" % world.builds.power_poles.size(),
		func() -> void: _hide_all(_pole_nodes()))
	await _row("the pile hidden", func() -> void: _hide_all([world.field]))
	await _row("nothing built is drawn", func() -> void:
		_hide_all(_prop_nodes())
		_hide_all(_belt_nodes())
		_hide_all(_machine_nodes())
		_hide_all(_pole_nodes()))
	await _row("nothing built is drawn OR ticks", func() -> void:
		_hide_all(_prop_nodes())
		_hide_all(_belt_nodes())
		_hide_all(_machine_nodes())
		_hide_all(_pole_nodes())
		_sleep_the_props()
		_silence_all(_belt_nodes())
		_silence_all(_machine_nodes()))


	await _row("SDFGI off", func() -> void: _env.sdfgi_enabled = false)
	await _row("SSIL off", func() -> void: _env.ssil_enabled = false)
	await _row("SSAO off", func() -> void: _env.ssao_enabled = false)


	await _row("MSAA off", func() -> void:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED)
	await _row("volumetric fog off", func() -> void:
		_env.volumetric_fog_enabled = false)
	await _row("shadows to 40 m (the shed's cascade)", func() -> void:
		_sun.directional_shadow_max_distance = 40.0)
	await _row("shadows off", func() -> void: _sun.shadow_enabled = false)


	await _row("2 cascades instead of 4", func() -> void:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	await _row("1 cascade instead of 4", func() -> void:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL)
	await _row("shadows to 150 m", func() -> void:
		_sun.directional_shadow_max_distance = 150.0)
	await _row("props cast no shadow", func() -> void: _uncast(_prop_nodes()))
	await _row("belts cast no shadow", func() -> void: _uncast(_belt_nodes()))
	await _row("machines cast no shadow", func() -> void: _uncast(_machine_nodes()))
	await _row("nothing built casts a shadow", func() -> void:
		_uncast(_prop_nodes())
		_uncast(_belt_nodes())
		_uncast(_machine_nodes())
		_uncast(_pole_nodes()))
	await _row("every switch off", func() -> void:
		_env.sdfgi_enabled = false
		_env.ssil_enabled = false
		_env.ssao_enabled = false
		_sun.shadow_enabled = false)


	await _row("everything on (baseline, again)", func() -> void: pass)

	_report()
	get_tree().quit(0)


func _prop_nodes() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for item in world.props.items:
		var n:= item as Node3D
		if n != null and is_instance_valid(n) and n.is_inside_tree():
			out.append(n)
	return out


func _prop_classes() -> Array:
	var by_class: Dictionary = { }
	for n in _prop_nodes():
		var script: Script = n.get_script() as Script
		var key: String = n.get_class()
		if script != null and script.resource_path != "":
			key = script.resource_path.get_file().get_basename()
		if not by_class.has(key):
			by_class [key] = []
		(by_class [key] as Array).append(n)
	var out: Array = []
	for key: String in by_class:
		out.append([key, by_class [key]])
	var bigger:= func(a: Array, b: Array) -> bool: return (a [1] as Array).size() > (b [1] as Array).size()
	out.sort_custom(bigger)
	return out


func _wads() -> Array [HayWad]:
	var out: Array [HayWad] = []
	for n in _prop_nodes():
		var w:= n as HayWad
		if w != null:
			out.append(w)
	return out


func _wad_levels_present(nodes: Array) -> bool:
	for n in nodes:
		if is_instance_valid(n) and n is HayWad:
			return true
	return false


func _remember_scale(w: HayWad) -> void:
	_ranged.append({ "wad": w, "scale": w._draw_scale })


func _scale_wad_lods(factor: float) -> void:
	for w in _wads():
		_remember_scale(w)
		w._draw_scale *= factor
		w._pick_lod(_cam.global_position if _cam != null else Vector3.ZERO)


func _pin_wads_to_last() -> void:
	HayWad.lod_frozen = true
	for w in _wads():
		_remember_scale(w)
		w._set_lod(w._lod_meshes().size() - 1)


func _bundle_camera(ua: PackedStringArray) -> Transform3D:
	var i:= ua.find("--bundle")
	if i < 0 or i + 1 >= ua.size():
		return Transform3D.IDENTITY
	var path: String = ua [i + 1]
	if not FileAccess.file_exists(path):
		print("YARDPERF: no bundle at '%s'" % path)
		return Transform3D.IDENTITY
	var origin:= Vector3.ZERO
	var cols: Array [Vector3] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var nums:= _floats(line)
		if line.begins_with("camera_origin") and nums.size() >= 3:
			origin = Vector3(nums [0], nums [1], nums [2])
		elif line.begins_with("camera_basis") and nums.size() >= 9:


			cols.append(Vector3(nums [0], nums [1], nums [2]))
			cols.append(Vector3(nums [3], nums [4], nums [5]))
			cols.append(Vector3(nums [6], nums [7], nums [8]))
	if cols.size() < 3:
		print("YARDPERF: '%s' has no camera in it" % path)
		return Transform3D.IDENTITY
	print("YARDPERF: camera out of %s, at %v" % [path.get_file(), origin])
	return Transform3D(Basis(cols [0], cols [1], cols [2]), origin)


static func _floats(line: String) -> PackedFloat32Array:
	var out:= PackedFloat32Array()
	var re:= RegEx.create_from_string("-?[0-9]+(\\.[0-9]+)?(e-?[0-9]+)?")
	if re == null:
		return out
	for m in re.search_all(line):
		out.append(float(m.get_string()))
	return out


func _belt_nodes() -> Array [Node3D]:
	var out: Array [Node3D] = []
	var b: BuildManager = world.builds
	for c in b.conveyors:
		if is_instance_valid(c):
			out.append(c)
	for c in b.corners:
		if is_instance_valid(c):
			out.append(c)
	return out


func _machine_nodes() -> Array [Node3D]:
	var out: Array [Node3D] = []
	var b: BuildManager = world.builds
	var groups: Array = [b.robotic_arms, b.scanners, b.compressors, b.wrappers,
		b.silos, b.pelletizers, b.generators, b.tube_launchers, b.dump_hatches,
		b.hay_stairs, b.splitters, b.joiners, b.cabinets, b.paint_boards,
		b.hay_drones, b.piston_rakes, b.platforms, b.stairs, b.railings,
		b.walls, b.roofs]
	for g in groups:
		for n in g:
			var n3:= n as Node3D
			if n3 != null and is_instance_valid(n3):
				out.append(n3)
	return out


func _pole_nodes() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for p in world.builds.power_poles:
		if is_instance_valid(p):
			out.append(p)
	return out


func _uncast(nodes: Array) -> void:
	for n in nodes:


		if not is_instance_valid(n):
			continue
		var stack: Array [Node] = [n]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			var vi:= node as GeometryInstance3D
			if vi != null and vi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_uncasted.append({ "node": vi, "shadow": vi.cast_shadow })
				vi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for kid: Node in node.get_children():
				stack.append(kid)


func _hide_all(nodes: Array) -> void:
	for n in nodes:


		if not is_instance_valid(n):
			continue
		var n3:= n as Node3D
		if n3 == null or not n3.visible:
			continue
		n3.visible = false
		_hidden.append(n3)


func _class_bisect() -> void:
	await _settle_draws()
	_rows.clear()
	var by_key: Dictionary = { }
	var mixers: Array = []
	var internal: Dictionary = { }
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		if node == self:
			continue
		if node.is_processing_internal() or node.is_physics_processing_internal():
			internal [node.get_class()] = int(internal.get(node.get_class(), 0)) + 1
			var mixer:= node as AnimationMixer
			if mixer != null and mixer.active:
				mixers.append(mixer)
				var owner_key:= "anim in " + _owner_script(mixer)
				if not by_key.has(owner_key):
					by_key [owner_key] = []
				(by_key [owner_key] as Array).append(mixer)
		if not (node.is_processing() or node.is_physics_processing()):
			continue
		var key: String = node.get_class()
		var script:= node.get_script() as Script
		if script != null and script.resource_path != "":
			key = script.resource_path.get_file().get_basename()
		if not by_key.has(key):
			by_key [key] = []
		(by_key [key] as Array).append(node)
	var census: Array = internal.keys()
	census.sort_custom(func(a: String, b: String) -> bool:
		return int(internal [a]) > int(internal [b]))
	print("\r\ninternal processing nodes by class (not seen by set_process):")
	for key: String in census:
		print("  %-32s %5d" % [key, internal [key]])
	var keys: Array = by_key.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return (by_key [a] as Array).size() > (by_key [b] as Array).size())
	var results: Array [Dictionary] = []


	if "--anim-only" in OS.get_cmdline_user_args():
		for i in 120:
			for f in 60:
				await get_tree().process_frame
		keys = keys.filter(func(k: String) -> bool: return k.begins_with("anim in "))
		results.append(await _pair("every animation stilled (%d)" % mixers.size(), mixers, 8))
	else:
		results.append(await _pair("every animation stilled (%d)" % mixers.size(), mixers, 3))
	for key: String in keys:
		var nodes: Array = by_key [key]
		results.append(await _pair("%s (%d)" % [key, nodes.size()], nodes,
			4 if "--anim-only" in OS.get_cmdline_user_args() else 1))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a ["saved"]) > float(b ["saved"]))
	print("\r\npaired class bisect, ms a frame saved by silencing (on minus off):")
	for r: Dictionary in results:
		print("  %-44s %+6.2f ms   (on %.2f, off %.2f, pair spread %.2f)"
			% [r ["label"], r ["saved"], r ["on"], r ["off"], r ["spread"]])
	print("\r\n[yardperf] done")


func _pair(label: String, nodes: Array, pairs: int) -> Dictionary:
	var on:= 0.0
	var off:= 0.0
	var lo:= INF
	var hi:= - INF
	for i in pairs:


		var w_on:= 0.0
		var w_off:= 0.0
		if i % 2 == 1:
			await _row("off " + label, func() -> void: _silence_or_still(nodes))
			w_off = float(_rows [_rows.size() - 1] ["wall"])
		await _row("on  " + label, func() -> void: pass)
		w_on = float(_rows [_rows.size() - 1] ["wall"])
		if i % 2 == 0:
			await _row("off " + label, func() -> void: _silence_or_still(nodes))
			w_off = float(_rows [_rows.size() - 1] ["wall"])
		on += w_on
		off += w_off
		lo = minf(lo, w_on - w_off)
		hi = maxf(hi, w_on - w_off)
	_reset()
	return { "label": label, "on": on / pairs, "off": off / pairs,
		"saved": (on - off) / pairs, "spread": hi - lo if pairs > 1 else 0.0 }


func _toggle_pairs(label: String, pairs: int, flip: Callable) -> Dictionary:
	var with_it:= 0.0
	var without:= 0.0
	var lo:= INF
	var hi:= - INF
	for i in pairs:
		var w_with:= 0.0
		var w_without:= 0.0
		for leg in 2:
			var on:= (leg == 0) == (i % 2 == 0)
			await _row(("with    " if on else "without ") + label,
				func() -> void: flip.call(on))
			if on:
				w_with = float(_rows [_rows.size() - 1] ["wall"])
			else:
				w_without = float(_rows [_rows.size() - 1] ["wall"])
		with_it += w_with
		without += w_without
		lo = minf(lo, w_without - w_with)
		hi = maxf(hi, w_without - w_with)
	return { "on": with_it / pairs, "off": without / pairs,
		"saved": (without - with_it) / pairs, "spread": hi - lo }


func _silence_or_still(nodes: Array) -> void:
	var plain: Array = []
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var mixer:= n as AnimationMixer
		if mixer != null:
			if mixer.active:
				mixer.active = false
				_stilled.append(mixer)
		else:
			plain.append(n)
	_silence_nodes(plain)


func _owner_script(node: Node) -> String:
	var at:= node.get_parent()
	while at != null:
		var script:= at.get_script() as Script
		if script != null and script.resource_path.begins_with("res://scripts/"):
			return script.resource_path.get_file().get_basename()
		at = at.get_parent()
	return "nothing"


func _settle_draws() -> void:
	var last:= -1.0
	var steady:= 0
	var started:= Time.get_ticks_msec()
	while steady < 3 and Time.get_ticks_msec() - started < 60000:
		for i in 60:
			await get_tree().process_frame
		var draws:= Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		steady = steady + 1 if last > 0.0 and absf(draws - last) < last * 0.01 else 0
		last = draws
	print("[yardperf] draws settled at %d after %.1f s"
		% [int(last), (Time.get_ticks_msec() - started) / 1000.0])


func _render_thread_separate() -> bool:
	return not RenderingServer.is_on_render_thread()


func _silence_nodes(nodes: Array) -> void:
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var node:= n as Node
		_silenced.append({ "node": node, "process": node.is_processing(),
			"physics": node.is_physics_processing() })
		node.set_process(false)
		node.set_physics_process(false)


func _silence_all(nodes: Array) -> void:
	for n in nodes:

		if not is_instance_valid(n):
			continue
		var root:= n as Node
		if root == null:
			continue
		var stack: Array [Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for kid: Node in node.get_children():
				stack.append(kid)
			if node.is_processing() or node.is_physics_processing():
				_silenced.append({ "node": node, "process": node.is_processing(),
					"physics": node.is_physics_processing() })
				node.set_process(false)
				node.set_physics_process(false)


func _sleep_the_props() -> void:
	for item in world.props.items:
		var body:= item as RigidBody3D
		if body != null and is_instance_valid(body):
			body.sleeping = true


func _open_the_taps() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if "--noreads" in OS.get_cmdline_user_args():
		return
	RenderingServer.viewport_set_measure_render_time(
		get_viewport().get_viewport_rid(), true)


func _hide_the_hud() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		for kid: Node in node.get_children():
			stack.append(kid)


func _park_the_camera(where: Transform3D, exact:= false) -> void:
	_cam = Camera3D.new()
	_cam.name = "YardPerfCamera"
	_cam.far = 2000.0
	world.add_child(_cam)
	_cam.global_transform = where if exact else Transform3D(where.basis, where.origin + Vector3.UP * 1.6)
	_cam.current = true


	if world.field != null:
		world.field.update_lod(_cam.global_position)
	if player != null:


		player.global_position += _cam.global_position - player.eye_position()
		if not "--live" in OS.get_cmdline_user_args():
			player.set_process(false)
			player.set_physics_process(false)


func _find_the_switches() -> bool:
	var we:= world.get("env_node") as WorldEnvironment
	_env = we.environment if we != null else null
	_sun = world.get("sun") as DirectionalLight3D
	if _env == null or _sun == null:
		push_error("yardperf: no environment (%s) or sun (%s) to measure" % [_env, _sun])
		return false
	return true


func _say_the_state() -> void:
	print("--- yard perf ---")
	print("quality preset %d, render scale %.2f, msaa %d, taa %s"
		% [int(Cfg.quality), float(Cfg.gfx ["render_scale"]), int(Cfg.gfx ["msaa"]),
			"on" if Cfg.gfx ["taa"] else "off"])
	print("sdfgi %s, ssil %s, ssao %s, shadows %s to %.0f m"
		% ["on" if _env.sdfgi_enabled else "off",
			"on" if _env.ssil_enabled else "off",
			"on" if _env.ssao_enabled else "off",
			"on" if _sun.shadow_enabled else "off",
			_sun.directional_shadow_max_distance])
	print("viewport %s, camera at %v"
		% [get_viewport().get_visible_rect().size, _cam.global_position])


	print("sun: energy %.2f, angular %.3f deg, bias %.4f, normal bias %.4f, opacity %.2f"
		% [_sun.light_energy, _sun.light_angular_distance, _sun.shadow_bias,
			_sun.shadow_normal_bias, _sun.shadow_opacity])
	print("     mode %d, splits %.2f/%.2f/%.2f, blend %s, fade %.2f, aim %v"
		% [int(_sun.directional_shadow_mode), _sun.directional_shadow_split_1,
			_sun.directional_shadow_split_2, _sun.directional_shadow_split_3,
			_sun.directional_shadow_blend_splits,
			_sun.directional_shadow_fade_start,
			- _sun.global_transform.basis.z])


func _count_the_yard() -> void:
	var groups:= {
		"props": _prop_nodes(),
		"belts and corners": _belt_nodes(),
		"machines": _machine_nodes(),
		"poles and lines": _pole_nodes(),
	}
	print("--- what is standing in this yard ---")
	var total_surf:= 0
	var total_mm:= 0
	for name: String in groups:
		var meshes:= 0
		var surfaces:= 0
		var multimesh:= 0
		for root: Node3D in groups [name]:
			var stack: Array [Node] = [root]
			while not stack.is_empty():
				var node: Node = stack.pop_back()
				var mi:= node as MeshInstance3D
				if mi != null and mi.mesh != null:
					meshes += 1
					surfaces += mi.mesh.get_surface_count()
				if node is MultiMeshInstance3D:
					multimesh += 1
				for kid: Node in node.get_children():
					stack.append(kid)
		total_surf += surfaces
		total_mm += multimesh
		print("  %-18s %4d nodes, %5d mesh instances, %5d surfaces, %3d multimeshes"
			% [name, (groups [name] as Array).size(), meshes, surfaces, multimesh])
	print("  %-18s %5d surfaces and %d multimeshes, before a shadow cascade draws any of them again"
		% ["TOTAL", total_surf, total_mm])


func _row(label: String, flip: Callable) -> void:
	_reset()
	flip.call()
	for i in SETTLE:
		await get_tree().process_frame

	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	var phys:= 0.0
	var proc:= 0.0
	var draws:= 0.0
	var prims:= 0.0
	var objs:= 0.0
	var bodies:= 0.0
	var started:= Time.get_ticks_usec()
	var times:= PackedFloat64Array()
	var previous:= started


	var no_reads:= "--noreads" in OS.get_cmdline_user_args()
	var threaded:= _render_thread_separate()
	for i in _sample_count:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
		if no_reads or (threaded and i < _sample_count - 1):
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			continue
		if threaded:


			var k:= float(_sample_count)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid) * k
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) * k
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) * k
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) * k
			objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME) * k
			bodies += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS) * k
			continue
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)


		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		bodies += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)


	var wall:= float(previous - started) / 1000.0 / _sample_count
	times.sort()
	var row:= { "label": label, "wall": wall, "gpu": gpu / _sample_count, "cpu": cpu / _sample_count,
		"phys": phys / _sample_count, "proc": proc / _sample_count, "draws": draws / _sample_count,
		"prims": prims / _sample_count, "objs": objs / _sample_count, "bodies": bodies / _sample_count }
	row ["median_ms"] = times [times.size() / 2]
	row ["median_fps"] = 1000.0 / maxf(row ["median_ms"], 0.001)
	row ["p95_ms"] = times [mini(int(times.size() * 0.95), times.size() - 1)]
	row ["p99_ms"] = times [mini(int(times.size() * 0.99), times.size() - 1)]
	var slow:= 0
	for time in times:
		if time > 1000.0 / 60.0:
			slow += 1
	row ["over_budget_percent"] = float(slow) * 100.0 / times.size()
	row ["props"] = world.props.items.size()
	row ["live"] = world.live.active_count()
	row ["sample_frames"] = _sample_count
	var hay:= 0
	var needles:= 0
	for item: Carryable in world.props.items:
		if is_instance_valid(item):
			hay += item.hay_strands()
			needles += 1 if item.holds_needle() else 0
	row ["prop_hay"] = hay
	row ["prop_needles"] = needles
	_rows.append(row)
	print("  %-42s %6.2f ms (%3.0f fps) GPU %5.2f rCPU %5.2f proc %5.2f phys %5.2f draws %5.0f tris %8.0fk objs %5.0f awake %4.0f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), row ["gpu"], row ["cpu"],
			row ["proc"], row ["phys"], row ["draws"], float(row ["prims"]) / 1000.0,
			row ["objs"], row ["bodies"]])
	print("    frame median %.2f ms, p95 %.2f ms, p99 %.2f ms, props %d, live %d"
		% [times [times.size() / 2], times [mini(int(times.size() * 0.95), times.size() - 1)],
			times [mini(int(times.size() * 0.99), times.size() - 1)],
			world.props.items.size(), world.live.active_count()])
	print("BENCH_DATA " + JSON.stringify(row))
	if not _benchmark_path.is_empty():
		_benchmark_samples.append({ "summary": row, "frame_times_ms": times })
		var report:= FileAccess.open(_benchmark_path, FileAccess.WRITE)
		assert (report != null, "could not write benchmark report")
		report.store_string(JSON.stringify({
			"engine": Engine.get_version_info(),
			"source_sha256": FileAccess.get_sha256(_benchmark_source),
			"camera": str(_cam.global_transform),
			"graphics": _graphics,
			"viewport_size": str(get_viewport().get_visible_rect().size),
			"unmetered": world.builds.grid.unmetered,
			"physics_ticks": Engine.get_physics_ticks_per_second(),
			"engine_arguments": OS.get_cmdline_args(),
			"probe_arguments": OS.get_cmdline_user_args(),
			"samples": _benchmark_samples,
		}, "\t"))
		report.close()


func _reset() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	for entry in _silenced:
		var n = entry ["node"]
		if is_instance_valid(n):
			n.set_process(entry ["process"])
			n.set_physics_process(entry ["physics"])
	_silenced.clear()
	for mixer in _stilled:
		if is_instance_valid(mixer):
			mixer.active = true
	_stilled.clear()
	for entry in _uncasted:
		var g = entry ["node"]
		if is_instance_valid(g):
			g.cast_shadow = entry ["shadow"]
	_uncasted.clear()
	HayWad.lod_frozen = false
	for r in _ranged:


		var w = r ["wad"]
		if is_instance_valid(w):
			w._draw_scale = float(r ["scale"])
			w._pick_lod(_cam.global_position if _cam != null else Vector3.ZERO)
	_ranged.clear()
	for key: String in _graphics.get("environment", { }):
		_env.set(key, _graphics ["environment"] [key])
	for key: String in _graphics.get("sun", { }):
		_sun.set(key, _graphics ["sun"] [key])
	if _graphics.has("msaa"):
		get_viewport().msaa_3d = _graphics ["msaa"]


func _capture_graphics() -> void:
	_graphics = { "environment": { }, "sun": { }, "msaa": get_viewport().msaa_3d }
	for key in ["sdfgi_enabled", "ssil_enabled", "ssao_enabled", "volumetric_fog_enabled"]:
		_graphics ["environment"] [key] = _env.get(key)
	for key in ["directional_shadow_mode", "shadow_enabled", "directional_shadow_max_distance"]:
		_graphics ["sun"] [key] = _sun.get(key)


func _report() -> void:
	if _rows.is_empty():
		return
	var base: Dictionary = _rows [0]
	var last: Dictionary = _rows [_rows.size() - 1]


	var floor_ms:= (float(base ["wall"]) + float(last ["wall"])) * 0.5
	var drift: float = float(last ["wall"]) - float(base ["wall"])
	print("\nagainst the baseline, at %.2f ms (%.0f fps):"
		% [floor_ms, 1000.0 / maxf(floor_ms, 0.001)])
	print("  the two baselines are %.2f ms apart (%.2f first, %.2f last). NOTHING"
		% [absf(drift), base ["wall"], last ["wall"]])
	print("  smaller than that is a result, whichever way it points.")
	for n in range(1, _rows.size() - 1):
		var r: Dictionary = _rows [n]
		var d: float = float(r ["wall"]) - floor_ms
		print("  %-42s %+6.2f ms  %+4.0f%%%s"
			% [r ["label"], d, d / maxf(floor_ms, 0.001) * 100.0,
				"" if absf(d) > absf(drift) else "   (under the drift)"])
	print("\n[yardperf] done")


func _autosave_every(seconds: float) -> void:
	var dir:= SaveManager.use_scratch_dir("user://probe_saves/yardperf")
	if not dir.begins_with("user://probe_saves/"):
		push_error("[yardperf] scratch save dir did not take: %s" % dir)
		return
	var n:= 0
	while is_inside_tree():
		await get_tree().create_timer(maxf(seconds, 1.0)).timeout
		n += 1
		var t0:= Time.get_ticks_usec()
		world._gather_loose_needles()
		var riding:= float(world.live.active_count()) if world.live != null else 0.0
		var ok:= SaveManager.save_game(world.field.heights, world.player.global_transform,
			world.builds.to_array(), world.props.to_array(), riding, world._belts_to_dict())
		print("[yardperf] autosave %d into %s: %s, %.0f ms" % [n, SaveManager.save_dir(),
			"written" if ok else "refused", (Time.get_ticks_usec() - t0) / 1000.0])
