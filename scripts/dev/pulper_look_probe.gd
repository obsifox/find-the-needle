class_name DevPulperLookProbe
extends Node


const LANE_X:= 13.0


const SETTLE_FRAMES:= 90


const SAMPLE_FRAMES:= 240


const PROBE_MARGIN:= 3.2


const VARIANTS:= ["baseline", "probe", "ssr", "both"]


const MEASURE_EYE:= Vector3(1.7, 0.78, 2.9)
const MEASURE_AIM:= Vector3(0.0, 0.8, 0.3)

var world: Node3D
var player: Player

var _cam: Camera3D
var _probe: ReflectionProbe
var _rows: Array [Dictionary] = []


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in 40:
		await get_tree().process_frame
	player.global_position = Vector3(9.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	for _w in 30:
		await get_tree().process_frame

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	for _w in 60:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()


	pulper.stored = Tech.pulper_batch_strands() * 6
	await _wait_running(pulper)


	var vp:= get_viewport()
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)

	for variant in VARIANTS:
		_apply(variant, pulper)
		for _w in SETTLE_FRAMES:
			await get_tree().process_frame


		_cam.look_at_from_position(pulper.to_global(MEASURE_EYE),
			pulper.to_global(MEASURE_AIM), Vector3.UP)
		for _w in 20:
			await get_tree().process_frame
		var row:= await _measure(variant)
		_rows.append(row)


		await _snap(out_dir, "look_%s_flank.png" % variant,
			pulper.to_global(MEASURE_EYE), pulper.to_global(MEASURE_AIM))


		await _snap(out_dir, "look_%s_console.png" % variant,
			pulper.global_position + Vector3(1.55, 1.05, -1.05),
			pulper.global_position + Vector3(0.6, 0.72, -1.2))


		await _snap(out_dir, "look_%s_wide.png" % variant,
			pulper.global_position + Vector3(3.4, 1.6, 2.2),
			pulper.global_position + Vector3(0.0, 0.7, 0.4))

	_report()
	print("[pulperlook] done")
	get_tree().quit()


func _apply(variant: String, pulper: HayPulper) -> void:
	var e: Environment = world.env_node.environment
	var want_probe:= variant in ["probe", "both"]
	var want_ssr:= variant in ["ssr", "both"]

	if want_probe and _probe == null:
		_build_machine_probe(pulper)
	if _probe != null:
		_probe.visible = want_probe
		if want_probe:


			_probe.update_mode = ReflectionProbe.UPDATE_ONCE

	e.ssr_enabled = want_ssr
	print("[pulperlook] %s: probe=%s ssr=%s" % [variant, want_probe, want_ssr])


func _build_machine_probe(pulper: HayPulper) -> void:
	var box:= AABB()
	var first:= true
	for n in pulper.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		var world_box:= mi.global_transform * mi.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	if first:
		return
	_probe = ReflectionProbe.new()
	_probe.name = "PulperProbe"
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.box_projection = true
	_probe.enable_shadows = true
	_probe.interior = false
	_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	_probe.max_distance = 120.0
	world.add_child(_probe)
	_probe.global_position = box.get_center()
	_probe.size = box.size * PROBE_MARGIN


func _measure(variant: String) -> Dictionary:
	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	for _s in SAMPLE_FRAMES:
		_unpause()
		await RenderingServer.frame_post_draw
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	return {
		"variant": variant,
		"gpu_ms": gpu / float(SAMPLE_FRAMES),
		"cpu_ms": cpu / float(SAMPLE_FRAMES),
	}


func _report() -> void:
	if _rows.is_empty():
		return
	var base: float = _rows [0] ["gpu_ms"]
	print("\n=== what each way of reflecting costs ===")
	print("  %-10s %10s %10s %12s" % ["variant", "gpu ms", "cpu ms", "vs baseline"])
	for row in _rows:
		var delta: float = row ["gpu_ms"] - base
		print("  %-10s %10.3f %10.3f %+11.3f" % [row ["variant"], row ["gpu_ms"],
			row ["cpu_ms"], delta])
	print("  (gpu ms is the frame's render time. 16.7 is one frame at 60 fps.)")


func _wait_running(pulper: HayPulper) -> void:
	for _w in 900:
		if pulper.is_running():
			return
		await get_tree().physics_frame
	print("[pulperlook] WARNING: the machine never started")


func _unpause() -> void:
	if world.pause_menu != null and world.pause_menu.is_open():
		world.pause_menu.set_open(false)
		print("[pulperlook] the pause menu was open, shut it")
	if get_tree().paused:
		get_tree().paused = false


func _snap(out_dir: String, name: String, at: Vector3, aim: Vector3) -> void:
	_unpause()
	_cam.look_at_from_position(at, aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
