class_name DevDroneFleetProbe
extends Node


var world: Node3D
var player: Player

const FLEET:= 16
const STEPS: Array [int] = [4, 8, 16]


const LITTER:= 450
const SETTLE:= 90
const SAMPLE:= 300


const SPACING:= 5.5
const BALE_OFFSET:= Vector3(1.4, 0.6, 1.4)

var _drones: Array [HayDrone] = []
var _pads: Array [Vector3] = []
var _bales: Array = []
var _feeding:= true
var _ticking:= true
var _uncast:= false
var _frame:= 0
var _script_usec:= 0


var _worst_script:= 0
var _max_scans:= 0
var _litter: Array = []
var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _process(delta: float) -> void:
	_frame += 1
	if _feeding and _frame % 20 == 0:
		_feed()
	if not _ticking:
		return
	var t0:= Time.get_ticks_usec()
	var scans:= 0
	for d in _drones:
		if is_instance_valid(d):
			var before:= d._scan_left
			d._process(delta)
			if d._scan_left > before:
				scans += 1
	var spent:= Time.get_ticks_usec() - t0
	_script_usec += spent
	_worst_script = maxi(_worst_script, spent)
	_max_scans = maxi(_max_scans, scans)


func _run() -> void:
	world.block_save = true
	for i in 120:
		await get_tree().process_frame
	GameState.add_money(5000000.0)
	Cfg.prop_cap = maxi(Cfg.prop_cap, LITTER + 400)

	_choose_pads()
	if _pads.size() < FLEET:
		print("DRONEFLEET: only %d clear pads found, running with those" % _pads.size())
	_strew_litter()
	_park_the_camera()
	_open_the_taps()
	for i in 120:
		await get_tree().process_frame
	RenderingServer.frame_pre_draw.connect(_hold_uncast)
	print("DRONEFLEET: stand at %v, %d pads, %d props in the ledger, %s"
		% [world.stand.global_position if world.stand != null else Vector3.INF,
			_pads.size(), world.props.items.size(),
			"windowed" if DisplayServer.get_name() != "headless" else "HEADLESS, no draw columns"])
	print("  columns: frame ms (fps) | worst frame | GPU | render CPU | TIME_PROCESS | TIME_PHYSICS | drone script ms a frame | draw calls | tris | drones airborne")

	await _row("no drones")
	for n in STEPS:
		_add_to(n)
		if n == STEPS [0]:
			_count_one(_drones [0])
		await _row("%d drones working" % _drones.size())
	var fleet:= _drones.size()
	_census()

	_hide(true, false)
	await _row("%d drones hidden (pad, post, aircraft)" % fleet)
	_hide(false, false)
	_hide(true, true)
	await _row("%d aircraft hidden, pads and posts drawn" % fleet)
	_hide(false, true)

	_set_uncast(true)
	await _row("%d drones cast no shadow" % fleet)
	_set_uncast(false)

	_ticking = false
	await _row("%d drones silenced (drawn, not ticking)" % fleet)
	_ticking = true

	_feeding = false
	_clear_bales()
	var waited:= 0
	while waited < 4000 and not _all_parked():
		await get_tree().process_frame
		waited += 1
		if waited % 120 == 0:
			_clear_bales()
	print("  (parked after %d frames)" % waited)
	await _row("%d drones parked, landed at different times" % fleet)


	for d in _drones:
		if is_instance_valid(d):
			world.builds.demolish(d)
	_drones.clear()
	_bales.clear()
	await get_tree().process_frame
	_add_to(FLEET)
	await _row("%d drones parked, as loaded from a save" % _drones.size())

	_time_scans_against_ledger()

	for d in _drones:
		if is_instance_valid(d):
			world.builds.demolish(d)
	_drones.clear()
	await _row("no drones again (drift)")

	world.block_save = true
	get_tree().quit(0)


func _choose_pads() -> void:
	var space:= world.get_world_3d().direct_space_state
	var stand_at: Vector3 = world.stand.global_position if world.stand != null else Vector3.ZERO
	var found: Array [Vector3] = []

	var reach: float = (world.get("warehouse") as Warehouse).inner - 1.6
	var x:= - reach
	while x <= reach:
		var z:= - reach
		while z <= reach:
			var spot:= _clear_floor(space, x, z)
			if spot != Vector3.INF and spot.distance_to(stand_at) > 6.0:
				found.append(spot)
			z += SPACING
		x += SPACING
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(stand_at) < b.distance_to(stand_at))
	for i in mini(FLEET, found.size()):
		_pads.append(found [i])


func _clear_floor(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:


	var inner: float = (world.get("warehouse") as Warehouse).inner - 1.6
	if absf(x) > inner or absf(z) > inner:
		return Vector3.INF
	var floor_y:= INF
	for off: Vector3 in [Vector3.ZERO, Vector3(1.5, 0, 1.5), Vector3(-1.5, 0, 1.5),
			Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, -1.5), BALE_OFFSET * Vector3(1, 0, 1)]:
		var at:= Vector3(x, 0, z) + off
		if world.field != null and float(world.field.height_at(at.x, at.z)) > 0.05:
			return Vector3.INF
		var ray:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN)
		ray.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			return Vector3.INF
		var y: float = (hit ["position"] as Vector3).y

		if y > 0.2 or y < -0.03:
			return Vector3.INF
		floor_y = minf(floor_y, y)


	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var from:= Vector3(x, 1.0, z)
		var wall:= PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
		wall.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
		var got: Dictionary = space.intersect_ray(wall)
		if got.is_empty() or (got ["position"] as Vector3).distance_to(from) < 1.6:
			return Vector3.INF
	return Vector3(x, floor_y + 0.02, z)


func _strew_litter() -> void:
	var keep_out:= Tech.drone_radius() + 1.0
	var placed:= 0
	var x:= -18.0
	while x <= 18.0 and placed < LITTER:
		var z:= -18.0
		while z <= 18.0 and placed < LITTER:
			var inside:= false
			for p in _pads:
				if Vector2(p.x - x, p.z - z).length() < keep_out:
					inside = true
					break
			if not inside:
				var y: float = float(world.field.height_at(x, z)) if world.field != null else 0.0
				var w: Carryable = world.props.spawn("hay_wad",
					Transform3D(Basis.IDENTITY, Vector3(x, y + 0.3, z)), { "strands": 120 })
				if w != null:
					w.freeze = true
					_litter.append(w)
				placed += 1
			z += 1.3
		x += 1.3


func _add_to(n: int) -> void:
	while _drones.size() < mini(n, _pads.size()):
		var i:= _drones.size()
		var d: HayDrone = world.builds.add_hay_drone(_pads [i], 0.0, 0.0)

		d.set_process(false)

		d.power_ports()
		d.set_power(1.0)


		var home:= d.global_position
		d.set_mode(HayDrone.Mode.COLLECT)
		d.set_zone(Vector3(home.x + BALE_OFFSET.x, 0.0, home.z + BALE_OFFSET.z), 1.2)
		d.set_drop(Vector3(home.x - BALE_OFFSET.x * 1.6, 0.0, home.z - BALE_OFFSET.z * 1.6),
			HayDrone.Drop.FLOOR)
		_drones.append(d)
		_bales.append(null)
	if _feeding:
		_feed()


func _feed() -> void:
	var r:= Tech.drone_radius()
	for i in _drones.size():
		var d:= _drones [i]
		if not is_instance_valid(d):
			continue
		if d.power < 1.0:
			d.set_power(1.0)
		var b = _bales [i]


		if is_instance_valid(b) and ((b as Carryable).is_held() or ((b as Node3D).global_position
				- (_pads [i] + BALE_OFFSET)).length() < maxf(r, 1.4)):
			continue
		if is_instance_valid(b):
			world.props.remove(b)
		_bales [i] = world.props.spawn("hay_bale",
			Transform3D(Basis.IDENTITY, _pads [i] + BALE_OFFSET),
			{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })


func _clear_bales() -> void:
	var doomed: Array [Carryable] = []
	for item in world.props.items:
		if not is_instance_valid(item) or _litter.has(item):
			continue
		if not item.has_method("sale_strands") or item.is_held():
			continue
		doomed.append(item)
	for item in doomed:
		world.props.remove(item)


func _all_parked() -> bool:
	for d in _drones:
		if is_instance_valid(d) and d.busy():
			return false
	return true


func _hide(on: bool, aircraft_only: bool) -> void:
	for d in _drones:
		if not is_instance_valid(d):
			continue
		if aircraft_only:
			var m:= d.get_node_or_null("Model") as Node3D
			if m != null:
				m.visible = not on
		else:
			d.visible = not on


func _set_uncast(on: bool) -> void:
	_uncast = on
	if not on:
		for g in _geometry():
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _hold_uncast() -> void:
	if not _uncast:
		return
	for g in _geometry():
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _geometry() -> Array [GeometryInstance3D]:
	var out: Array [GeometryInstance3D] = []
	var stack: Array [Node] = []
	for d in _drones:
		if is_instance_valid(d):
			stack.append(d)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var g:= node as GeometryInstance3D
		if g != null:
			out.append(g)
		for kid: Node in node.get_children():
			stack.append(kid)
	return out


func _open_the_taps() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		for kid: Node in node.get_children():
			stack.append(kid)


func _park_the_camera() -> void:
	var c:= Vector3.ZERO
	for p in _pads:
		c += p
	c /= maxf(1.0, float(_pads.size()))
	_cam = Camera3D.new()
	_cam.name = "DroneFleetCamera"
	_cam.fov = 70.0
	_cam.far = 400.0
	world.add_child(_cam)
	_cam.look_at_from_position(c + Vector3(0.0, 20.0, 22.0), c, Vector3.UP)
	_cam.current = true
	if world.field != null:
		world.field.update_lod(_cam.global_position)
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)


func _row(label: String) -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	var proc:= 0.0
	var phys:= 0.0
	var draws:= 0.0
	var prims:= 0.0
	var airborne:= 0
	var worst:= 0
	_script_usec = 0
	_worst_script = 0
	_max_scans = 0
	var started:= Time.get_ticks_usec()
	var last:= started
	for i in SAMPLE:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		for d in _drones:
			if is_instance_valid(d) and d.busy():
				airborne += 1
	var n:= float(SAMPLE)
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / n
	print("  %-44s %6.2f ms (%4.0f fps) worst %6.2f  GPU %5.2f  rCPU %5.2f  proc %5.2f  phys %5.2f  drones %5.3f (worst %5.2f, %2d scans in one frame)  draws %5.0f  tris %6.0fk  airborne %4.1f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), float(worst) / 1000.0,
			gpu / n, cpu / n, proc / n, phys / n,
			float(_script_usec) / 1000.0 / n, float(_worst_script) / 1000.0, _max_scans,
			draws / n, prims / n / 1000.0, float(airborne) / n])


func _time_scans_against_ledger() -> void:
	if _drones.is_empty():
		return
	var calls:= 0
	var t0:= Time.get_ticks_usec()
	for k in 20:
		for d in _drones:
			d._find_pick()
			calls += 1
	var per:= float(Time.get_ticks_usec() - t0) / float(calls)
	print("  scan: _find_pick %.1f us a call over %d props; %d idle drones at 60 fps is %.3f ms a frame"
		% [per, world.props.items.size(), _drones.size(),
			per * float(_drones.size()) / (Cfg.DRONE_SCAN_INTERVAL * 60.0) / 1000.0])


func _census() -> void:
	var parts:= { "aircraft": "Model", "pad and post": "Pad" }
	for key: String in parts:
		var surfaces:= 0
		var pairs:= { }
		for d in _drones:
			if not is_instance_valid(d):
				continue
			var root: Node = d.get_node_or_null(parts [key])
			if root == null:
				continue
			for mi in HayDrone._meshes(root):
				if mi.mesh == null or not mi.visible:
					continue
				for s in mi.mesh.get_surface_count():
					surfaces += 1
					var m:= mi.get_active_material(s)
					pairs ["%d %d" % [mi.mesh.get_instance_id(),
						m.get_instance_id() if m != null else 0]] = true
		print("  fleet of %d, %-13s %5d surfaces, %5d distinct mesh and material pairs (%s)"
			% [_drones.size(), key, surfaces, pairs.size(),
				"shared" if HayCompressor.materials_shared() else "per machine"])


func _count_one(d: HayDrone) -> void:
	var parts:= { "aircraft": d.get_node_or_null("Model"), "pad and post": d.get_node_or_null("Pad") }
	for key: String in parts:
		var root: Node = parts [key]
		if root == null:
			continue
		var meshes:= 0
		var surfaces:= 0
		var tris:= 0
		var stack: Array [Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			var mi:= node as MeshInstance3D
			if mi != null and mi.mesh != null:
				meshes += 1
				surfaces += mi.mesh.get_surface_count()
				for s in mi.mesh.get_surface_count():
					var arr:= mi.mesh.surface_get_arrays(s)
					var idx = arr [Mesh.ARRAY_INDEX]
					if idx is PackedInt32Array:
						tris += (idx as PackedInt32Array).size() / 3
					else:
						tris += (arr [Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			for kid: Node in node.get_children():
				stack.append(kid)
		print("  one drone's %-13s %3d mesh instances, %3d surfaces, %6d triangles"
			% [key, meshes, surfaces, tris])
