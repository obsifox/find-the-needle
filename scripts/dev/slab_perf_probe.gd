class_name DevSlabPerfProbe
extends Node


const LANE_X:= -13.0
const EYE:= Vector3(LANE_X, 3.2, 11.0)
const AIM:= Vector3(LANE_X, 0.6, 0.0)
const PITCH:= -14.0

const ACROSS:= 10
const DEEP:= 10
const BLOCK_Z:= 6.0
const WARM_FRAMES:= 90
const LEG_FRAMES:= 300
const PAIRS:= 3

var world: Node3D
var player: Player

var _slabs: Array [HayPulp] = []
var _shared: Dictionary = { }


func run(count: int) -> void:
	world.block_save = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for i in 30:
		await get_tree().process_frame
	player.set_physics_process(false)
	player.global_position = EYE
	player.look_at_from_position(EYE, AIM, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = deg_to_rad(PITCH)

	_stand(count)
	for i in 10:
		await get_tree().physics_frame

	print("\n[slabperf] %d slabs, render thread %s" % [_slabs.size(),
		ProjectSettings.get_setting("rendering/driver/threads/thread_model")])
	var legs: Array [Dictionary] = []
	legs.append(await _leg("none"))
	for p in PAIRS:
		legs.append(await _leg("shared"))
		legs.append(await _leg("own"))

	var sums:= { }
	for leg in legs:
		var s: Dictionary = sums.get_or_add(leg ["mode"], { "ms": 0.0, "n": 0, "draws": 0, "gpu": 0.0, "cpu": 0.0 })
		s ["ms"] += leg ["ms"]
		s ["gpu"] += leg ["gpu"]
		s ["cpu"] += leg ["cpu"]
		s ["draws"] = leg ["draws"]
		s ["n"] += 1
	print("\n[slabperf] means")
	for mode in ["none", "shared", "own"]:
		var s: Dictionary = sums [mode]
		var ms: float = s ["ms"] / s ["n"]
		print("  %-7s  frame %6.2f ms  %6.1f fps   gpu %6.2f ms   render cpu %6.2f ms   draws %d"
			% [mode, ms, 1000.0 / ms, s ["gpu"] / s ["n"], s ["cpu"] / s ["n"], s ["draws"]])
	var own_ms: float = sums ["own"] ["ms"] / sums ["own"] ["n"]
	var shared_ms: float = sums ["shared"] ["ms"] / sums ["shared"] ["n"]
	print("  sharing saves %.2f ms a frame (%.1f to %.1f fps)"
		% [own_ms - shared_ms, 1000.0 / own_ms, 1000.0 / shared_ms])
	get_tree().quit(0)


func _stand(count: int) -> void:
	var size:= Cfg.PULPER_SLAB_SIZE
	var step:= Vector3(size.x + 0.03, size.y + 0.01, size.z + 0.03)
	var x0:= LANE_X - step.x * (ACROSS - 1) * 0.5
	for n in count:
		var ix:= n % ACROSS
		var iz:= (n / ACROSS) % DEEP
		var iy:= n / (ACROSS * DEEP)
		var slab:= HayPulp.new()
		slab.freeze = true
		slab.position = Vector3(x0 + ix * step.x, iy * step.y, BLOCK_Z - iz * step.z)
		world.add_child(slab)
		slab.collision_layer = 0
		slab.collision_mask = 0
		_slabs.append(slab)
		for mi in slab._meshes:
			var mats: Array [Material] = []
			for s in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(s))
			_shared [mi] = mats


func _wear(mode: String) -> void:
	for slab in _slabs:
		slab.visible = mode != "none"
		for mi: MeshInstance3D in slab._meshes:
			var mats: Array [Material] = _shared [mi]
			for s in mats.size():
				var m:= mats [s]
				if mode == "own" and m != null:
					m = m.duplicate() as Material
				mi.set_surface_override_material(s, m)


func _leg(mode: String) -> Dictionary:
	_wear(mode)
	for i in WARM_FRAMES:
		await get_tree().process_frame
	var vp:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	var samples:= 0
	var t0:= Time.get_ticks_usec()
	for i in LEG_FRAMES:
		await get_tree().process_frame


		if i % 30 == 29:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			samples += 1
	var ms:= (Time.get_ticks_usec() - t0) / 1000.0 / LEG_FRAMES
	var draws:= int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var out:= { "mode": mode, "ms": ms, "gpu": gpu / samples, "cpu": cpu / samples, "draws": draws }
	print("  %-7s  frame %6.2f ms  gpu %6.2f  render cpu %6.2f  draws %d"
		% [mode, ms, out ["gpu"], out ["cpu"], draws])
	return out
