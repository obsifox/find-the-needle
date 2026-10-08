class_name DevGpuProbe
extends Node


const WARMUP:= 120
const SAMPLE:= 180


const VIEWS:= [
	[Vector3(0.0, 12.5, 15.5), Vector3(0.0, 3.0, 0.0), "wide_room   "],
	[Vector3(12.0, 1.7, 1.0), Vector3(6.0, 2.4, 0.5), "pile_face   "],
	[Vector3(13.2, 1.8, 6.4), Vector3(0.0, 3.2, 0.0), "establishing"],
]

var world: Node3D
var player: Player

var _cam: Camera3D


func run() -> void:


	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Cfg.perf_scale = 1.0

	_cam = Camera3D.new()
	_cam.fov = player.camera.fov
	_cam.near = player.camera.near
	_cam.far = player.camera.far
	world.add_child(_cam)
	_cam.current = true

	for i in WARMUP:
		await get_tree().process_frame


	print("\n=== render probe (%d frames per view) ===" % SAMPLE)
	for mode in ["OLD (pre-review settings)", "NEW (current settings)"]:
		if mode.begins_with("OLD"):
			_apply_old_settings()
		else:
			_apply_new_settings()


		for i in 45:
			await get_tree().process_frame
		print("\n  -- %s" % mode)
		print("  view           ms/frame   p95 ms    draws   prims(M)   objects")
		print("  ---------------------------------------------------------------")
		for v: Array in VIEWS:
			await _measure(v [0], v [1], v [2])
	print("  ---------------------------------------------------------------")
	print("  preset: %s   strands/cell: %d" % [Cfg.preset() ["name"], Cfg.crust_strands_per_cell])
	get_tree().quit()


func _env() -> Environment:
	return (world.get_node("Environment") as WorldEnvironment).environment


func _apply_old_settings() -> void:
	var e:= _env()
	e.ssil_enabled = false
	e.volumetric_fog_enabled = false
	e.ssao_radius = 0.55
	e.ssao_intensity = 1.1
	e.fog_enabled = false
	world.get_viewport().use_taa = false
	world.sun.directional_shadow_max_distance = 62.0
	world.sun.directional_shadow_split_1 = 0.06
	world.sun.directional_shadow_split_2 = 0.16
	world.sun.directional_shadow_split_3 = 0.42
	world.fill.visible = false

	Cfg.crust_shadow_distance = 32.0
	_set_proxies(false)


func _apply_new_settings() -> void:
	var e:= _env()
	var p:= Cfg.preset()
	e.ssil_enabled = p ["ssil"]
	e.volumetric_fog_enabled = p ["vfog"]
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.8
	e.fog_enabled = true
	world.get_viewport().use_taa = p ["taa"]
	world.sun.directional_shadow_max_distance = 40.0
	world.sun.directional_shadow_split_1 = 0.1
	world.sun.directional_shadow_split_2 = 0.28
	world.sun.directional_shadow_split_3 = 0.6
	world.fill.visible = true
	Cfg.crust_shadow_distance = p ["shadow_distance"]
	_set_proxies(true)


func _set_proxies(on: bool) -> void:
	var mode:= GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in (world.get_node("HayField") as HayField).chunks:
		var proxy:= c.get_node_or_null("ShadowProxy") as MeshInstance3D
		if proxy != null:
			proxy.cast_shadow = mode


func _measure(pos: Vector3, look: Vector3, label: String) -> void:
	_cam.look_at_from_position(pos, look, Vector3.UP)


	player.global_position = pos
	for i in 30:
		await get_tree().process_frame

	var times:= PackedFloat64Array()
	var draws:= 0.0
	var prims:= 0.0
	var objs:= 0.0
	for i in SAMPLE:
		var t0:= Time.get_ticks_usec()
		await get_tree().process_frame
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

	var sorted:= times.duplicate()
	sorted.sort()
	var mean:= 0.0
	for t in times:
		mean += t
	mean /= float(times.size())
	var p95: float = sorted [int(float(sorted.size()) * 0.95)]
	var n:= float(SAMPLE)
	print("  %s   %7.2f   %7.2f   %6d   %7.2f   %7d"
		% [label, mean, p95, int(draws / n), prims / n / 1000000.0, int(objs / n)])
