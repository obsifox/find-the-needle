class_name DevWorldCostProbe
extends Node


const WARM_FRAMES:= 30
const MEASURE_FRAMES:= 90

var world: Node3D
var player: Player
var field: HayField
var terrain: YardTerrain
var warehouse: Node3D
var door: Node3D

var _cam: Camera3D
var _vp_rid: RID
var _baseline:= 0.0
var _flora: Array [MultiMeshInstance3D] = []
var _ground: Node3D
var _builds: Node3D
var _props: Node3D


func run() -> void:
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)
	var want: int = int(Cfg.PRESETS [Cfg.Quality.HIGH] ["strands_per_cell"])
	if Cfg.crust_strands_per_cell != want:
		Cfg.crust_strands_per_cell = want
		field.rebuild_density()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


	if door != null and door.has_method("set_open_amount"):
		door.set_open_amount(1.0)


	player.set_physics_process(false)
	player.set_process(false)
	await get_tree().process_frame

	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)

	_ground = terrain.terrain()
	_flora = _find_mmis(_ground)
	_builds = world.get_node_or_null("Buildings")
	_props = world.get_node_or_null("Props")


	_cam = Camera3D.new()
	_cam.fov = player.camera.fov
	_cam.near = player.camera.near
	_cam.far = player.camera.far
	world.add_child(_cam)
	_cam.current = true

	print("\n=== what the yard costs the GPU, at High, %dx%d ==="
		% [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y])
	print("  camera far: %.0f m   (--gpucost measured at 320)" % _cam.far)
	print("  flora multimeshes under the terrain: %d" % _flora.size())

	var centre: Vector3 = door.global_position
	var out:= Vector3(1.0, 0.0, 0.0)


	var views:= [
		["at the pile (--gpucost's view)", Vector3(11.6, 1.7, 0.0), Vector3(2.0, 3.4, 0.0)],
		["inside, looking out the door", centre - out * 5.0 + Vector3(0.0, 1.66, 0.0),
			centre + out * 90.0 + Vector3(0.0, 6.0, 0.0)],
		["in the doorway", centre + out * 1.0 + Vector3(0.0, 1.66, 3.5),
			centre + out * 140.0 + Vector3(0.0, 8.0, 0.0)],
		["out on the track", centre + out * 60.0 + Vector3(0.0, 1.66, 0.0),
			centre + out * 300.0 + Vector3(0.0, 14.0, 0.0)],
	]


	_look(views [0] [1], views [0] [2])
	await _time("warm-up, discarded")

	for v in views:
		_look(v [1], v [2])


		for i in 20:
			await get_tree().process_frame
		print("\n  -- %s --" % v [0])
		_baseline = 0.0
		_baseline = await _time("as it ships")
		await _measure_hidden("flora off", _flora)
		await _measure_hidden("ground off (flora with it)", [_ground])
		await _measure_hidden("warehouse off", [warehouse])
		await _measure_hidden("buildings + props off", [_builds, _props])
		await _measure_hidden("pile off", [field])
		await _measure_hidden("everything but the pile off",
			[_ground, warehouse, _builds, _props])
		await _measure_hidden("everything but the yard off", [field])


	_look(views [2] [1], views [2] [2])
	for i in 20:
		await get_tree().process_frame
	print("\n  -- the far plane, from the doorway --")
	_baseline = 0.0
	_baseline = await _time("far 1800 (as it ships)")
	for f in [900.0, 450.0, 320.0, 200.0, 120.0]:
		_cam.far = f
		await _time("far %.0f" % f)
	_cam.far = player.camera.far

	print("\n--- done ---")
	get_tree().quit()


func _measure_hidden(label: String, nodes: Array) -> float:
	var touched: Array [Node3D] = []
	for n in nodes:
		var n3:= n as Node3D
		if n3 != null and n3.visible:
			n3.visible = false
			touched.append(n3)
	var ms:= await _time(label)
	for n3 in touched:
		n3.visible = true


	for i in 6:
		await get_tree().process_frame
	return ms


func _look(eye: Vector3, at: Vector3) -> void:
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	_cam.look_at_from_position(eye, at, Vector3.UP)
	field.update_lod(eye)


func _time(label: String) -> float:
	for i in WARM_FRAMES:
		await get_tree().process_frame
	var total:= 0.0
	for i in MEASURE_FRAMES:
		await get_tree().process_frame
		total += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var mean:= total / float(MEASURE_FRAMES)
	var delta:= ""
	if _baseline > 0.0 and not is_equal_approx(mean, _baseline):
		delta = "   %+.1f%%" % (100.0 * (mean - _baseline) / _baseline)
	print("  %-30s gpu %6.2f ms  (%3.0f fps)%s"
		% [label, mean, 1000.0 / maxf(mean, 0.001), delta])
	return mean


func _find_mmis(from: Node) -> Array [MultiMeshInstance3D]:
	var out: Array [MultiMeshInstance3D] = []
	if from == null:
		return out
	for child in from.get_children():
		if child is MultiMeshInstance3D:
			out.append(child)
		out.append_array(_find_mmis(child))
	return out
