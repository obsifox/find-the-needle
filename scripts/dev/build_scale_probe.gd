class_name DevBuildScaleProbe
extends Node


const SETTLE:= 40


const SAMPLE:= 70


const BELT_STAGES: Array [int] = [60, 150, 320, 640, 1000]
const RUN_LENGTH:= 8.0


const GRID_ORIGIN:= Vector3(-70.0, 0.0, 60.0)
const ROW_PITCH:= 3.0
const RUNS_PER_ROW:= 20


const RAKES:= 8
const SCANNERS:= 24
const DOCKS:= 24
const STAIRS:= 24


const EYE:= Vector3(-74.0, 26.0, 116.0)
const AIM:= Vector3(-34.0, 0.0, 66.0)

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D
var _rows: Array [Dictionary] = []
var _hidden: Array [Node3D] = []
var _silenced: Array [Node] = []
var _scale:= 1
var _belt_metres:= 0.0
var _runs:= 0


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

	for i in 90:
		await get_tree().process_frame

	print("\n=== what a yard costs as it grows, at High, pile out of frame ===")
	print("  scale x%d, %0.f m per run\n" % [_scale, RUN_LENGTH])
	await _row("warm-up, discarded")
	_rows.clear()

	await _row("BASELINE: empty ground")

	var laid:= 0
	for want_runs in BELT_STAGES:
		var target: int = want_runs * _scale
		_lay_belts(target - laid)
		laid = target
		await _row("%d belt runs (%.0f m)" % [_runs, _belt_metres])

	_add_arms()
	await _row("+ %d robotic arms (the Cfg cap)" % _arms_wanted())
	_add_rakes()
	await _row("+ %d piston rakes (the Cfg cap)" % (RAKES * _scale))
	_add_scanners()
	await _row("+ %d scanners" % (SCANNERS * _scale))
	_add_docks()
	await _row("+ %d dump hatches" % (DOCKS * _scale))
	await _row("+ %d stair towers" % (STAIRS * _scale), func() -> void: _add_stairs())


	print("\n  -- the same yard, one group taken out at a time --")
	await _row("belts hidden", func() -> void: _hide(_group("conveyors")))
	await _row("belts silenced", func() -> void: _silence(_group("conveyors")))
	await _row("arms hidden", func() -> void: _hide(_group("robotic_arms")))
	await _row("arms silenced", func() -> void: _silence(_group("robotic_arms")))
	await _row("rakes hidden", func() -> void: _hide(_group("piston_rakes")))
	await _row("scanners hidden", func() -> void: _hide(_group("scanners")))
	await _row("docks hidden", func() -> void: _hide(_group("dump_hatches")))
	await _row("stairs hidden", func() -> void: _hide(_group("hay_stairs")))
	await _row("everything hidden", func() -> void: _hide(_everything()))
	await _row("everything silenced", func() -> void: _silence(_everything()))
	await _row("everything hidden AND silenced", func() -> void:
		_hide(_everything())
		_silence(_everything()))

	await _row("CONTROL: the whole yard again")
	await _belt_sleep_pairs()
	_report()
	get_tree().quit(0)


const SLEEP_PAIRS:= 3


func _belt_sleep_pairs() -> void:
	var census:= BeltPath.sleep_census()
	print("\n  -- what the idle belt tick costs: %d of %d runs asleep --"
		% [census [1], census [0]])
	var awake: Array [Dictionary] = []
	var sleeping: Array [Dictionary] = []
	for i in SLEEP_PAIRS:
		BeltPath.set_sleeping_enabled(false)


		await _row("  every run ticking (%d of %d awake)"
			% [census [0] - BeltPath.sleep_census() [1], census [0]])
		awake.append(_rows [_rows.size() - 1])
		BeltPath.set_sleeping_enabled(true)
		await _row("  empty runs asleep (%d)" % (i + 1))
		sleeping.append(_rows [_rows.size() - 1])


	_paired("wall clock", awake, sleeping, "wall")
	_paired("of which GPU", awake, sleeping, "gpu")
	_paired("physics step", awake, sleeping, "phys")


func _paired(what: String, awake: Array [Dictionary],
		sleeping: Array [Dictionary], key: String) -> void:
	var total:= 0.0
	var worst:= -1000000000.0
	var best:= 1000000000.0
	for i in awake.size():
		var d: float = float(awake [i] [key]) - float(sleeping [i] [key])
		total += d
		worst = maxf(worst, d)
		best = minf(best, d)
	print("  saved by the sleep, %-12s %+6.2f ms   mean of %d pairs (%+.2f to %+.2f)"
		% [what, total / float(awake.size()), awake.size(), best, worst])


func _lay_belts(count: int) -> void:
	if count <= 0:
		return
	var builds = world.get("builds")
	for i in count:
		var n:= _runs
		var row:= n / RUNS_PER_ROW
		var col:= n % RUNS_PER_ROW


		var x: float = GRID_ORIGIN.x + float(col) * RUN_LENGTH
		if row % 2 == 1:
			x = GRID_ORIGIN.x + float(RUNS_PER_ROW - 1 - col) * RUN_LENGTH
		var z: float = GRID_ORIGIN.z - float(row) * ROW_PITCH
		var from:= Vector3(x, 0.0, z)
		var to:= from + Vector3(RUN_LENGTH if row % 2 == 0 else - RUN_LENGTH, 0.0, 0.0)
		var c:= Conveyor.new()
		c.name = "Conveyor%d" % builds.conveyors.size()
		c.setup(from, to)
		builds.conveyors.append(c)
		builds.add_child(c)
		_runs += 1
		_belt_metres += RUN_LENGTH
	builds.rebuild_junctions()
	builds.changed.emit()


func _arms_wanted() -> int:
	return Cfg.ARM_LIMIT * _scale


func _add_arms() -> void:
	var builds = world.get("builds")
	for i in _arms_wanted():
		builds.add_robotic_arm(_spot(i, 5.0), 0.0)


func _add_rakes() -> void:
	var builds = world.get("builds")
	for i in RAKES * _scale:
		builds.add_piston_rake(_spot(i, 9.0), 0.0)


func _add_scanners() -> void:
	var builds = world.get("builds")
	for i in SCANNERS * _scale:
		builds.add_scanner(_spot(i, 13.0), 0.0)


func _add_docks() -> void:
	var builds = world.get("builds")
	for i in DOCKS * _scale:
		builds.add_dump_hatch(_spot(i, 17.0), 0.0)


func _add_stairs() -> void:
	var builds = world.get("builds")
	for i in STAIRS * _scale:
		builds.add_hay_stairs(_spot(i, 21.0), 0.0)


func _spot(i: int, lane: float) -> Vector3:
	return Vector3(GRID_ORIGIN.x + 2.0 + float(i) * 2.6, 0.0,
		GRID_ORIGIN.z + lane)


func _group(list_name: String) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var builds = world.get("builds")
	var list = builds.get(list_name)
	if list == null:
		return out
	for n in list:
		if is_instance_valid(n):
			out.append(n)
	return out


func _everything() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for name in ["conveyors", "robotic_arms", "piston_rakes", "scanners",
			"dump_hatches", "hay_stairs"]:
		out.append_array(_group(name))
	return out


func _row(label: String, flip: Callable = Callable()) -> void:
	_reset()
	if flip.is_valid():
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
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE
	_rows.append({ "label": label, "wall": wall, "gpu": gpu / SAMPLE,
		"cpu": cpu / SAMPLE, "phys": phys / SAMPLE, "proc": proc / SAMPLE,
		"draws": draws / SAMPLE, "prims": prims / SAMPLE, "runs": _runs })
	print("  %-40s %7.2f ms (%4.0f fps) GPU %6.2f rCPU %5.2f proc %6.1f phys %5.2f draws %6.0f tris %9.0f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), gpu / SAMPLE, cpu / SAMPLE,
			proc / SAMPLE, phys / SAMPLE, draws / SAMPLE, prims / SAMPLE])


func _hide(group: Array [Node3D]) -> void:
	for n in group:
		if is_instance_valid(n) and n.visible:
			n.visible = false
			_hidden.append(n)


func _silence(group: Array [Node3D]) -> void:
	for n in group:
		if is_instance_valid(n):
			n.set_process(false)
			n.set_physics_process(false)
			_silenced.append(n)


func _reset() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	for n in _silenced:
		if is_instance_valid(n):
			n.set_process(true)
			n.set_physics_process(true)
	_silenced.clear()


func _report() -> void:
	if _rows.size() < 3:
		return
	print("\ncost per belt run, stage by stage:")
	var prev: Dictionary = _rows [0]
	for r: Dictionary in _rows:
		var added: int = int(r ["runs"]) - int(prev ["runs"])
		if added <= 0:
			continue
		var d: float = float(r ["wall"]) - float(prev ["wall"])
		print("  %5d -> %5d runs   %+6.2f ms over %4d runs   %6.4f ms per run"
			% [prev ["runs"], r ["runs"], d, added, d / float(added)])
		prev = r


	var census:= BeltPath.sleep_census()
	print("\nbelt runs asleep: %d of %d" % [census [1], census [0]])
	var lod:= MachineLod.census()
	print("machines on their far mesh: %d of %d" % [lod [1], lod [0]])
	if BeltBatch.instance != null:
		var b:= BeltBatch.instance.census()
		print("belt drawn in %d calls over %d instances, from %d run nodes"
			% [b [0], b [1], b [2]])
	print("\n[buildscale] done")
