class_name DevWorkCostProbe
extends Node


const SETTLE:= 30
const SAMPLE:= 150

const PAIRS:= 2


const DRIFT_LEGS:= 6


const PER_KIND:= 8


const GRID:= Vector3(-60.0, 0.0, 55.0)
const PITCH:= Vector3(5.0, 0.0, 6.0)
const PER_ROW:= 4
const EYE:= Vector3(-52.0, 9.0, 78.0)
const AIM:= Vector3(-52.0, 1.0, 46.0)


const SPAWN_BATCH:= 100
const SPAWN_ROUNDS:= 3


const SKINS:= [
	{ "name": "hay bale", "table": "compressor",
		"keys": ["M_HC_Straw", "M_HC_Twine"] },


	{ "name": "hay wad", "table": "wad",
		"keys": ["M_HW_Bulk", "M_HW_Straw", "M_HW_Tuft", "M_HW_TuftDark",
			"M_HW_TuftPale"] },


	{ "name": "foiled bale", "table": "wrapper", "keys": ["M_HW_Straw"] },
	{ "name": "eco brick", "table": "brick",
		"keys": ["M_EB_Brick", "M_EB_Stamp"] },
]

const SKIN_ROUNDS:= 5


const LITTER:= 200

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D
var _scale:= 1
var _presses: Array [HayCompressor] = []
var _wrappers: Array [HayWrapper] = []
var _feeding:= false

var _pairs: Dictionary = { }


var _births: Dictionary = { }


var _work_dirties:= 0
var _work_births: Dictionary = { }


var _dirties:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)

	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			_scale = maxi(1, arg.to_int())

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(
		get_viewport().get_viewport_rid(), true)
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.05
	_cam.far = player.camera.far
	world.add_child(_cam)
	_cam.look_at_from_position(EYE, AIM, Vector3.UP)
	_cam.current = true
	player.global_position = EYE - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	field.update_lod(EYE)

	_build()
	for i in 120:
		await get_tree().process_frame

	print("\n=== what a working machine costs, at High ===")
	print("  %d presses and %d wrappers, all of them in frame\n"
		% [_presses.size(), _wrappers.size()])


	_set_working(true)
	for i in DRIFT_LEGS:
		await _leg("working, unchanged (%d of %d)" % [i + 1, DRIFT_LEGS])
	print("")

	for variant: String in ["standing idle", "working, clips stopped",
			"working, spouts off"]:
		for p in PAIRS:
			_set_working(true)
			_set_clips(true)
			_set_spouts(true)
			var on:= await _leg("working (for '%s')" % variant)
			match variant:
				"standing idle": _set_working(false)
				"working, clips stopped": _set_clips(false)
				"working, spouts off": _set_spouts(false)
			var off:= await _leg(variant)
			if not _pairs.has(variant):
				_pairs [variant] = []
			(_pairs [variant] as Array).append([on, off])

	_set_working(true)
	_set_clips(true)
	_set_spouts(true)


	_work_dirties = _dirties
	_work_births = _births.duplicate()

	_report()
	await _price_the_product()
	_price_the_skin()
	await _price_the_shadow_sweep()

	get_tree().quit(0)


func _build() -> void:
	var builds = world.get("builds")
	var n:= 0
	for kind: String in ["compressor", "wrapper"]:
		for i in PER_KIND * _scale:
			var at:= GRID + Vector3(float(n % PER_ROW) * PITCH.x, 0.0,
				- float(n / PER_ROW) * PITCH.z)
			match kind:
				"compressor":
					var c:= builds.add_compressor(at, 0.0) as HayCompressor
					if c != null:
						_presses.append(c)
						c.baled.connect(_take_away)
				"wrapper":
					var w:= builds.add_wrapper(at, 0.0) as HayWrapper
					if w != null:
						_wrappers.append(w)
						w.wrapped.connect(_take_away)
			n += 1
	builds.rebuild_junctions()
	var props = world.get("props")
	if props != null:
		props.changed.connect(func() -> void: _dirties += 1)
		props.item_added.connect(_tally.bind("born"))
		props.item_removed.connect(_tally.bind("died"))


func _take_away(item: Carryable) -> void:
	if item == null or not is_instance_valid(item):
		return
	item.queue_free()


func _physics_process(_delta: float) -> void:
	if not _feeding:
		return
	for c in _presses:
		if is_instance_valid(c):
			c.stored = maxi(c.stored, Tech.compressor_bale_strands())
	for w in _wrappers:
		if is_instance_valid(w) and w.queued.is_empty():
			w.queued.append(Tech.compressor_bale_strands())
			w.queued_needles.append(-1)


func _set_working(on: bool) -> void:
	_feeding = on
	for m: Node in _machines():
		m.call("set_power", 1.0 if on else 0.0)
	if on:
		return


	for c in _presses:
		if is_instance_valid(c):
			c.stored = 0
	for w in _wrappers:
		if is_instance_valid(w):
			w.queued.clear()
			w.queued_needles.clear()


func _set_clips(on: bool) -> void:
	for m: Node in _machines():
		for node in m.find_children("*", "AnimationPlayer", true, false):
			(node as AnimationPlayer).active = on


func _set_spouts(on: bool) -> void:
	for m: Node in _machines():
		for node in m.find_children("*", "GPUParticles3D", true, false):
			var p:= node as GPUParticles3D


			if not on:
				p.emitting = false


func _machines() -> Array [Node]:
	var out: Array [Node] = []
	for c in _presses:
		if is_instance_valid(c):
			out.append(c)
	for w in _wrappers:
		if is_instance_valid(w):
			out.append(w)
	return out


func _leg(label: String) -> Dictionary:
	for i in SETTLE:
		await get_tree().process_frame

	var rid:= get_viewport().get_viewport_rid()
	var frames: Array [float] = []
	var gpu:= 0.0
	_dirties = 0
	_births.clear()
	var last:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)

	frames.sort()
	var mean:= 0.0
	for f in frames:
		mean += f
	mean /= float(frames.size())
	var row:= {
		"mean": mean,
		"p95": frames [int(float(frames.size()) * 0.95)],
		"p99": frames [mini(int(float(frames.size()) * 0.99), frames.size() - 1)],
		"max": frames [frames.size() - 1],
		"gpu": gpu / float(SAMPLE),
	}


	print("  %-34s mean %6.2f ms (%3.0f fps)  p95 %6.2f  p99 %6.2f  worst %6.2f  GPU %5.2f  objs %6d  orph %4d  bodies %4d  draws %5d"
		% [label, row ["mean"], 1000.0 / maxf(row ["mean"], 0.001),
			row ["p95"], row ["p99"], row ["max"], row ["gpu"],
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	return row


func _report() -> void:
	print("\n=== the paired differences, working MINUS the variant ===")
	print("  a positive number is what the variant GIVES BACK.\n")
	for variant: String in _pairs.keys():
		var rows: Array = _pairs [variant]
		var d_mean:= 0.0
		var d_p99:= 0.0
		var d_max:= 0.0
		var spread: Array [float] = []
		for pair: Array in rows:
			var on: Dictionary = pair [0]
			var off: Dictionary = pair [1]
			d_mean += float(on ["mean"]) - float(off ["mean"])
			d_p99 += float(on ["p99"]) - float(off ["p99"])
			d_max += float(on ["max"]) - float(off ["max"])
			spread.append(float(on ["mean"]) - float(off ["mean"]))
		var n:= float(rows.size())
		print("  %-28s mean %+6.2f ms   p99 %+6.2f ms   worst %+6.2f ms   (pairs: %s)"
			% [variant, d_mean / n, d_p99 / n, d_max / n,
				", ".join(spread.map(func(v: float) -> String:
					return "%+.2f" % v))])
	print("")


func _price_the_product() -> void:
	var props = world.get("props")
	if props == null:
		return
	print("=== what one product costs to create ===\n")
	for id: String in ["hay_bale", "foiled_bale", "hay_wad"]:
		var rounds: Array [float] = []
		for r in SPAWN_ROUNDS:
			var made: Array [Carryable] = []
			var started:= Time.get_ticks_usec()
			for i in SPAWN_BATCH:
				var at:= Vector3(-200.0 + float(i) * 0.6, 1.0, -200.0)
				var item:= props.spawn(id,
					Transform3D(Basis.IDENTITY, at)) as Carryable
				if item != null:
					made.append(item)
			var spent:= float(Time.get_ticks_usec() - started) / 1000.0
			rounds.append(spent / float(maxi(made.size(), 1)))
			for item in made:
				item.queue_free()
			await get_tree().process_frame
			await get_tree().physics_frame
		print("  %-14s %s ms each   (%.2f ms for a batch of %d, warm)"
			% [id, ", ".join(rounds.map(func(v: float) -> String:
				return "%.3f" % v)),
				rounds [rounds.size() - 1] * float(SPAWN_BATCH), SPAWN_BATCH])
	print("")


func _price_the_skin() -> void:
	print("=== what a product's materials cost to build ===\n")
	print("  %-14s %9s %11s %11s" % ["prop", "surfaces", "cold", "warm"])
	for row: Dictionary in SKINS:
		var keys: Array = row ["keys"]
		var spec:= _table(String(row ["table"]))
		if spec.is_empty():
			print("  %-14s (no table on disk)" % row ["name"])
			continue
		var shader: Shader = load(HayCompressor.SHADER)
		print("  %-14s %9d %9.2f ms %9.3f ms"
			% [row ["name"], keys.size(), _time_skin(keys, spec, shader, true),
				_time_skin(keys, spec, shader, false)])
	print("\n[workcost] done")


func _time_skin(keys: Array, spec: Dictionary, shader: Shader,
		drop: bool) -> float:
	var best:= INF
	for r in SKIN_ROUNDS:
		var kept: Array [Material] = []
		var started:= Time.get_ticks_usec()
		for key: String in keys:
			var m:= HayCompressor.make_material(key, spec, shader)
			if m != null:
				kept.append(m)
		best = minf(best, float(Time.get_ticks_usec() - started) / 1000.0)
		if drop:
			kept.clear()
	return best


func _table(which: String) -> Dictionary:
	match which:
		"compressor": return HayCompressor.spec_table()
		"wrapper": return HayWrapper.spec_table()
		"wad": return HayWad.spec_table()
		"brick": return EcoBrick.spec_table()
	return { }


func _price_the_shadow_sweep() -> void:
	var sweep = world.get("shadow_lod")
	var props = world.get("props")
	if sweep == null or props == null:
		return
	print("\n=== what one shadow sweep rebuild costs ===\n")
	print("  the yard dirtied it %d times over %d frames of working, so a"
		% [_work_dirties, SAMPLE])
	print("  rebuild on up to %d of them: `mark_dirty` coalesces into one a frame."
		% mini(_work_dirties, SAMPLE))
	var what: Array [String] = []
	for key: String in _work_births.keys():
		what.append("%s x%d" % [key, int(_work_births [key])])
	print("  what changed: %s" % ("nothing" if what.is_empty() else ", ".join(what)))


	for i in LITTER:
		var at:= Vector3(-70.0 + fmod(float(i), 20.0) * 1.2, 0.6,
			40.0 + floor(float(i) / 20.0) * 1.2)
		props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at), { "strands": 60 })
	await get_tree().process_frame
	print("  %-46s %8s %9s" % ["yard", "casters", "rebuild"])
	print("  %-46s %8d %7.3f ms"
		% ["%d machines, %d props" % [_machines().size(), props.items.size()],
			int(sweep.call("caster_count")), _time_rebuild(sweep)])
	print("")


func _time_rebuild(sweep: Object) -> float:
	var best:= INF
	for r in SKIN_ROUNDS:
		sweep.call("mark_dirty")
		var started:= Time.get_ticks_usec()
		sweep.call("_rebuild")
		best = minf(best, float(Time.get_ticks_usec() - started) / 1000.0)
	return best


func _tally(item: Carryable, when: String) -> void:
	var key:= "%s %s" % ["?" if item == null else item.item_id, when]
	_births [key] = int(_births.get(key, 0)) + 1
