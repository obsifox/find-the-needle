class_name DevAnimCostProbe
extends Node


const SETTLE:= 30
const SAMPLE:= 60


const PAIRS:= 3


const PER_KIND:= 12


const GRID:= Vector3(-60.0, 0.0, 55.0)
const PITCH:= Vector3(4.5, 0.0, 5.0)
const PER_ROW:= 8
const EYE:= Vector3(-42.0, 12.0, 82.0)
const AIM:= Vector3(-42.0, 1.0, 45.0)

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D
var _players: Array [AnimationPlayer] = []
var _machines: Array [Node3D] = []
var _scale:= 1
var _on: Array [float] = []
var _off: Array [float] = []
var _on_cpu: Array [float] = []
var _off_cpu: Array [float] = []


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

	_build()
	for i in 90:
		await get_tree().process_frame
	_collect_players()

	print("\n=== what animating machines cost, at High ===")
	print("  %d machines, %d AnimationPlayers, all forced to play and loop\n"
		% [_machines.size(), _players.size()])

	await _row("warm-up, discarded")

	for p in PAIRS:
		_set_active(true)
		var on:= await _row("pair %d: animating" % (p + 1))
		_on.append(on [0])
		_on_cpu.append(on [1])
		_set_active(false)
		var off:= await _row("pair %d: animation stopped" % (p + 1))
		_off.append(off [0])
		_off_cpu.append(off [1])

	_set_active(true)
	_report()
	get_tree().quit(0)


func _build() -> void:
	var builds = world.get("builds")
	var n:= 0
	for kind in ["compressor", "wrapper", "pelletizer", "scanner"]:
		for i in PER_KIND * _scale:
			var at:= GRID + Vector3(float(n % PER_ROW) * PITCH.x, 0.0,
				- float(n / PER_ROW) * PITCH.z)
			var made: Node3D = null
			match kind:
				"compressor": made = builds.add_compressor(at, 0.0)
				"wrapper": made = builds.add_wrapper(at, 0.0)
				"pelletizer": made = builds.add_pelletizer(at, 0.0)
				"scanner": made = builds.add_scanner(at, 0.0)
			if made != null:
				_machines.append(made)
			n += 1


func _collect_players() -> void:
	for m in _machines:
		for node in m.find_children("*", "AnimationPlayer", true, false):
			var ap:= node as AnimationPlayer
			if ap == null:
				continue
			var list:= ap.get_animation_list()
			if list.is_empty():
				continue
			var clip: Animation = ap.get_animation(list [0])
			if clip != null:
				clip.loop_mode = Animation.LOOP_LINEAR
			ap.active = true
			ap.play(list [0])
			_players.append(ap)


func _set_active(on: bool) -> void:
	for ap in _players:
		if is_instance_valid(ap):
			ap.active = on
			if on and not ap.is_playing():
				var list:= ap.get_animation_list()
				if not list.is_empty():
					ap.play(list [0])


func _row(label: String) -> Array:
	for i in SETTLE:
		await get_tree().process_frame
	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	var proc:= 0.0
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE
	print("  %-34s %7.2f ms (%4.0f fps) GPU %6.2f rCPU %5.2f proc %7.1f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), gpu / SAMPLE,
			cpu / SAMPLE, proc / SAMPLE])
	return [wall, cpu / SAMPLE]


func _report() -> void:
	if _on.is_empty():
		return
	var diffs: Array [float] = []
	var diffs_cpu: Array [float] = []
	for i in _on.size():
		diffs.append(_on [i] - _off [i])
		diffs_cpu.append(_on_cpu [i] - _off_cpu [i])
	var mean:= 0.0
	for d in diffs:
		mean += d
	mean /= float(diffs.size())
	var mean_cpu:= 0.0
	for d in diffs_cpu:
		mean_cpu += d
	mean_cpu /= float(diffs_cpu.size())
	var lo: float = diffs [0]
	var hi: float = diffs [0]
	for d in diffs:
		lo = minf(lo, d)
		hi = maxf(hi, d)

	print("\nwhat the animation costs, as the mean of %d paired differences:"
		% diffs.size())
	print("  frame      %+6.3f ms   (pairs ran %+.3f to %+.3f)" % [mean, lo, hi])
	print("  render CPU %+6.3f ms" % mean_cpu)
	print("  that is %.4f ms per animating machine, over %d of them"
		% [mean / maxf(float(_machines.size()), 1.0), _machines.size()])
	if absf(mean) < (hi - lo):
		print("  THE SPREAD IS WIDER THAN THE MEAN. There is no result here.")
	print("\n[animcost] done")
