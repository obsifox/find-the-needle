class_name DevSiloPerfProbe
extends Node


const EYE:= Vector3(-42.0, 14.0, 88.0)
const AIM:= Vector3(-42.0, 2.0, 45.0)
const SPACING:= 9.0
const PAIRS:= 3
const SETTLE:= 30
const SAMPLE:= 180

var world: Node3D
var player: Player

var _silos: Array [HaySilo] = []
var _count:= 16


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
			_count = maxi(1, arg.to_int())

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(
		get_viewport().get_viewport_rid(), true)
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false

	var cam:= Camera3D.new()
	cam.fov = 74.0
	cam.far = player.camera.far
	world.add_child(cam)
	cam.look_at_from_position(EYE, AIM, Vector3.UP)
	cam.current = true
	player.global_position = EYE - Vector3(0.0, Player.EYE_HEIGHT, 0.0)

	print("\n=== what silos cost, at High ===")
	await _row("no silos yet")
	await _row("no silos yet")
	var builds = world.get("builds")
	var side:= int(ceil(sqrt(float(_count))))
	for i in _count:
		var at:= AIM + Vector3(
			(float(i % side) - float(side - 1) * 0.5) * SPACING, - AIM.y,
			- float(i / side) * SPACING)
		_silos.append(builds.add_silo(at, 0.0))

	var fill:= "--empty" not in OS.get_cmdline_user_args()
	for i in 30:
		await get_tree().process_frame
	if fill:
		for s in _silos:
			s.stop()
			s.pose_for_shot(1.0)
	for i in 90:
		await get_tree().process_frame
	print("  %d silos placed, %s\n" % [_silos.size(),
		"full and stopped" if fill else "empty"])

	await _row("warm-up, discarded")
	var full: Array [float] = []
	var hid: Array [float] = []
	var still: Array [float] = []
	for p in PAIRS:
		full.append((await _row("pair %d: silos as built" % (p + 1))) [0])
		_set_visible(false)
		hid.append((await _row("pair %d: silos hidden" % (p + 1))) [0])
		_set_visible(true)
		_set_ticking(false)
		still.append((await _row("pair %d: silos not ticking" % (p + 1))) [0])
		_set_ticking(true)

	print("\n  drawing %d silos:  %.2f ms a frame" % [_count, _mean(full) - _mean(hid)])
	print("  ticking %d silos:  %.2f ms a frame" % [_count, _mean(full) - _mean(still)])
	get_tree().quit()


func _set_visible(on: bool) -> void:
	for s in _silos:
		s.visible = on


func _set_ticking(on: bool) -> void:
	for s in _silos:
		if on:
			FactoryClock.join(s)
		else:
			FactoryClock.leave(s)


func _mean(a: Array [float]) -> float:
	var t:= 0.0
	for v in a:
		t += v
	return t / maxf(float(a.size()), 1.0)


func _row(label: String) -> Array:
	for i in SETTLE:
		await get_tree().process_frame
	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var rcpu:= 0.0
	var phys:= 0.0
	var draws:= 0.0
	var prims:= 0.0
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE
	var held:= 0
	for s in _silos:
		held += s.held()
	var props_live: int = world.find_children("*", "RigidBody3D", true, false).size()
	print("  %-30s %6.2f ms (%4.0f fps) GPU %6.2f rCPU %5.2f phys %5.2f draws %6.0f tris %8.0fk held %d props %d"
		% [label, wall, 1000.0 / maxf(wall, 0.001), gpu / SAMPLE, rcpu / SAMPLE,
			phys / SAMPLE, draws / SAMPLE, prims / SAMPLE / 1000.0, held, props_live])
	return [wall]
