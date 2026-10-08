class_name DevFactoryPerfProbe
extends Node


const OUT_DIR:= "res://captures"


const SETTLE:= 45


const SAMPLE:= 90


const WARMUP:= 240


const RING:= 14.0


const ARMS:= 20


const MODULES_EACH:= 2


const SPUR:= 3.0


const WADS_PER_ARM:= 3


const EYE:= Vector3(12.5, 1.7, 12.5)
const AIM:= Vector3(-13.0, 1.2, 13.5)

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D
var _rows: Array [Dictionary] = []
var _hidden: Array [Node3D] = []
var _silenced: Array [Node] = []


var _tris_cache: Dictionary = { }

var _belt_metres:= 0.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(
		get_viewport().get_viewport_rid(), true)

	_hide_the_hud()
	await _build_the_line()

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

	for i in WARMUP:
		await get_tree().process_frame

	_census()


	await _row("warm-up, discarded", func() -> void: pass)
	_rows.clear()

	print("\n=== what the line costs, at High, standing on it ===")
	await _row("BASELINE: everything standing", func() -> void: pass)

	await _row("belts hidden", func() -> void: _hide(_belts()))
	await _row("belts silenced", func() -> void: _silence(_belts()))
	await _row("arms hidden", func() -> void: _hide(_arms()))
	await _row("arms silenced", func() -> void: _silence(_arms()))
	await _row("modules hidden", func() -> void: _hide(_modules()))
	await _row("modules silenced", func() -> void: _silence(_modules()))
	await _row("wads hidden", func() -> void: _hide(_wads()))
	await _row("every machine hidden", func() -> void: _hide(_everything()))
	await _row("every machine silenced", func() -> void: _silence(_everything()))
	await _row("every machine hidden AND silenced", func() -> void:
		_hide(_everything())
		_silence(_everything()))


	await _row("the PILE hidden (machines all standing)",
		func() -> void: _hide([field] as Array [Node3D]))
	await _row("pile hidden AND every machine hidden", func() -> void:
		_hide([field] as Array [Node3D])
		_hide(_everything()))


	await _row("CONTROL: everything standing again", func() -> void: pass)

	_report()
	get_tree().quit(0)


func _build_the_line() -> void:
	var builds = world.get("builds")
	var props = world.get("props")


	var corners: Array [Vector3] = [
		Vector3(- RING, 0.0, - RING), Vector3(RING, 0.0, - RING),
		Vector3(RING, 0.0, RING), Vector3(- RING, 0.0, RING),
	]
	for i in corners.size():
		var a: Vector3 = corners [i]
		var b: Vector3 = corners [(i + 1) % corners.size()]
		builds.add_conveyor(a, b)
		_belt_metres += a.distance_to(b)


	for i in ARMS:
		var t:= TAU * float(i) / float(ARMS)
		var at:= Vector3(sin(t), 0.0, cos(t)) * (RING - 1.4)
		builds.add_robotic_arm(at, atan2(- at.x, - at.z) + PI)


		for k in WADS_PER_ARM:
			var drop:= at + Vector3(sin(t), 0.0, cos(t)) * -0.9 + Vector3(randf_range(-0.4, 0.4), 0.35, randf_range(-0.4, 0.4))
			props.spawn("hay_wad", Transform3D(Basis.IDENTITY, drop),
				{ "strands": 60 })


	var kinds:= ["compressor", "wrapper", "splitter", "joiner"]
	var slot:= 0
	for kind in kinds:
		for n in MODULES_EACH:
			var x:= -10.5 + 3.0 * float(slot)
			var at:= Vector3(x, 0.0, RING - 3.5)
			var made: Node3D = null
			match kind:
				"compressor": made = builds.add_compressor(at, 0.0)
				"wrapper": made = builds.add_wrapper(at, 0.0)
				"splitter": made = builds.add_splitter(at, 0.0)
				"joiner": made = builds.add_joiner(at, 0.0)
			slot += 1
			if made == null:
				continue
			_spur(builds, made)

	builds.rebuild_junctions()
	if builds.grid != null:
		builds.grid.rebuild()
	await get_tree().process_frame


func _spur(builds, made: Node3D) -> void:
	var ins: Array [Vector3] = []
	var outs: Array [Vector3] = []
	if made.has_method("port_in"):
		ins.append(made.call("port_in"))
	if made.has_method("port_out"):
		outs.append(made.call("port_out"))
	if made is ConveyorSplitter:
		outs.append(made.call("port_left"))
		outs.append(made.call("port_right"))
	if made is ConveyorJoiner:
		ins.append(made.call("port_left"))
		ins.append(made.call("port_right"))
	for p: Vector3 in ins:
		var from:= p + Vector3(0.0, 0.0, - SPUR)
		builds.add_conveyor(from, p)
		_belt_metres += SPUR
	for p: Vector3 in outs:
		var to:= p + Vector3(0.0, 0.0, SPUR)
		builds.add_conveyor(p, to)
		_belt_metres += SPUR


func _belts() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for c in world.get("builds").conveyors:
		if is_instance_valid(c):
			out.append(c)
	return out


func _arms() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for a in world.get("builds").robotic_arms:
		if is_instance_valid(a):
			out.append(a)
	return out


func _modules() -> Array [Node3D]:
	var builds = world.get("builds")
	var out: Array [Node3D] = []
	for list in [builds.compressors, builds.wrappers, builds.splitters,
			builds.joiners]:
		for m in list:
			if is_instance_valid(m):
				out.append(m)
	return out


func _wads() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for it in world.get("props").items:
		if is_instance_valid(it):
			out.append(it)
	return out


func _everything() -> Array [Node3D]:
	var out: Array [Node3D] = []
	out.append_array(_belts())
	out.append_array(_arms())
	out.append_array(_modules())
	out.append_array(_wads())
	return out


func _census() -> void:
	print("\n=== what is standing in the yard ===")
	print("  %.0f metres of belt, %d arms, %d inline modules, %d loose props"
		% [_belt_metres, _arms().size(), _modules().size(), _wads().size()])
	print("")
	print("  %-12s %5s %8s %8s %10s %10s"
		% ["group", "count", "meshes", "surfaces", "triangles", "tris each"])
	for pair in [["belts", _belts()], ["arms", _arms()],
			["modules", _modules()], ["wads", _wads()]]:
		var group: Array [Node3D] = pair [1]
		var meshes:= 0
		var surfaces:= 0
		var tris:= 0
		for n in group:
			var c:= _count(n)
			meshes += int(c ["meshes"])
			surfaces += int(c ["surfaces"])
			tris += int(c ["tris"])
		var each:= 0 if group.is_empty() else tris / group.size()
		print("  %-12s %5d %8d %8d %10d %10d"
			% [pair [0], group.size(), meshes, surfaces, tris, each])


func _count(root: Node) -> Dictionary:
	var meshes:= 0
	var surfaces:= 0
	var tris:= 0
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			if m != null:
				meshes += 1
				surfaces += m.get_surface_count()
				tris += _tris_of(m)
		elif n is MultiMeshInstance3D:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				meshes += 1
				surfaces += mm.mesh.get_surface_count()
				var live: int = mm.visible_instance_count
				if live < 0:
					live = mm.instance_count
				tris += _tris_of(mm.mesh) * live
	return { "meshes": meshes, "surfaces": surfaces, "tris": tris }


func _tris_of(m: Mesh) -> int:
	var key:= m.get_rid()
	if _tris_cache.has(key):
		return int(_tris_cache [key])


	var n: int = m.get_faces().size() / 3
	_tris_cache [key] = n
	return n


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
	var bodies:= 0.0
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		bodies += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE
	var row:= { "label": label, "wall": wall, "gpu": gpu / SAMPLE,
		"cpu": cpu / SAMPLE, "phys": phys / SAMPLE, "proc": proc / SAMPLE,
		"draws": draws / SAMPLE, "prims": prims / SAMPLE,
		"bodies": bodies / SAMPLE }
	_rows.append(row)
	print("  %-38s %6.2f ms (%3.0f fps) GPU %5.2f rCPU %5.2f proc %5.2f phys %5.2f draws %5.0f tris %8.0f awake %4.0f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), row ["gpu"], row ["cpu"],
			row ["proc"], row ["phys"], row ["draws"], row ["prims"],
			row ["bodies"]])


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


func _hide_the_hud() -> void:
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false


func _report() -> void:
	if _rows.size() < 2:
		return
	var base: Dictionary = _rows [0]
	var last: Dictionary = _rows [_rows.size() - 1]
	var floor_ms:= (float(base ["wall"]) + float(last ["wall"])) * 0.5
	var drift: float = float(last ["wall"]) - float(base ["wall"])
	print("\nagainst the baseline, at %.2f ms (%.0f fps):"
		% [floor_ms, 1000.0 / maxf(floor_ms, 0.001)])
	print("  the two baselines are %.2f ms apart (%.2f first, %.2f last)."
		% [absf(drift), base ["wall"], last ["wall"]])
	print("  NOTHING smaller than that is a result, whichever way it points.")
	for n in range(1, _rows.size() - 1):
		var r: Dictionary = _rows [n]
		var d: float = float(r ["wall"]) - floor_ms
		print("  %-38s %+6.2f ms  %+4.0f%%%s"
			% [r ["label"], d, d / maxf(floor_ms, 0.001) * 100.0,
				"" if absf(d) > absf(drift) else "   (under the drift)"])


	print("\nwhat one of each costs, taken off the rows above:")
	_per_unit("belts", "per 10 m of belt", _belt_metres / 10.0)
	_per_unit("arms", "per arm", float(_arms().size()))
	_per_unit("modules", "per module", float(_modules().size()))
	print("\n[factoryperf] done")


func _per_unit(group: String, unit: String, count: float) -> void:
	if count <= 0.0:
		return
	var base: Dictionary = _rows [0]
	var last: Dictionary = _rows [_rows.size() - 1]
	var floor_ms:= (float(base ["wall"]) + float(last ["wall"])) * 0.5
	var draw:= 0.0
	var think:= 0.0
	for r: Dictionary in _rows:
		var label: String = r ["label"]
		if label == "%s hidden" % group:
			draw = floor_ms - float(r ["wall"])
		elif label == "%s silenced" % group:
			think = floor_ms - float(r ["wall"])
	print("  %-16s draw %+6.3f ms %s, think %+6.3f ms %s"
		% [group, draw / count, unit, think / count, unit])
