class_name DevDroneScaleProbe
extends Node


const STAGES: Array [int] = [8, 12, 16]
const PAIRS:= 3
const SETTLE:= 60
const SAMPLE:= 240
const LITTER:= 450


const SPACING:= 4.0
const BALE_OFFSET:= Vector3(1.4, 0.6, 1.4)
const CALM_WINDOW:= 60
const CALM_TOLERANCE:= 0.05
const CALM_LIMIT:= 4000

var world: Node3D
var player: Player

var _drones: Array [HayDrone] = []
var _pads: Array [Vector3] = []
var _bales: Array = []
var _litter: Array = []
var _ticking:= true
var _frame:= 0
var _script_usec:= 0
var _worst_script:= 0
var _scans:= 0
var _max_scans:= 0
var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _process(delta: float) -> void:
	_frame += 1
	if _frame % 20 == 0:
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
	_scans += scans
	_max_scans = maxi(_max_scans, scans)


func _run() -> void:
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	GameState.add_money(5000000.0)
	Cfg.prop_cap = maxi(Cfg.prop_cap, LITTER + 400)
	var field: HayField = world.get("field")
	print("\n=== what a drone fleet costs, %s pile, %s ===" % [Cfg.pile_size_id,
		"windowed" if DisplayServer.get_name() != "headless" else "headless, no draw columns"])
	await _wait_for_calm(field)
	_choose_pads(field)
	_strew_litter(field)
	_park_the_camera()
	print("  %d pads, %d props in the ledger, stand at %v, peak %.1f m"
		% [_pads.size(), (world.get("props") as PropManager).items.size(),
			(world.get("stand") as Node3D).global_position, field.height_at(0.0, 0.0)])
	for i in 120:
		await get_tree().process_frame

	var table: Array [Dictionary] = []
	for want in STAGES:
		if want > _pads.size():
			print("  only %d pads fit; stopping before %d" % [_pads.size(), want])
			break
		table.append(await _stage(want))
	_report(table)
	print("\n[dronescale] done")
	world.set("block_save", true)
	get_tree().quit(0)


func _wait_for_calm(field: HayField) -> void:
	var waited:= 0
	var previous:= -1.0
	while waited < CALM_LIMIT:
		var started:= Time.get_ticks_usec()
		for i in CALM_WINDOW:
			await get_tree().process_frame
		waited += CALM_WINDOW
		var ms:= float(Time.get_ticks_usec() - started) / 1000.0 / CALM_WINDOW
		var preparing: bool = bool(field.get("_preparing_dome"))
		if not preparing and previous > 0.0 and absf(ms - previous) <= previous * CALM_TOLERANCE:
			print("  the yard went still after %d frames, at %.2f ms." % [waited, ms])
			return
		previous = ms
	print("  the yard never went still: gave up after %d frames." % waited)


func _stage(want: int) -> Dictionary:
	_add_to(want)

	for i in 300:
		await get_tree().process_frame
	print("\n--- %d drones ---" % want)
	print("  %-12s %7s %6s %7s %6s %6s %6s %7s %7s %6s %9s"
		% ["", "ms", "fps", "worst", "GPU", "rCPU", "proc", "script", "sworst", "scans", "airborne"])
	var diffs: Array [float] = []
	var gpu_diffs: Array [float] = []
	var live_sum:= { }
	for i in PAIRS:
		var live:= await _read("live")
		var dead:= await _read("neutralised", true)
		diffs.append(float(live ["wall"]) - float(dead ["wall"]))
		gpu_diffs.append(float(live ["gpu"]) - float(dead ["gpu"]))
		for k: String in live:
			live_sum [k] = float(live_sum.get(k, 0.0)) + float(live [k]) / float(PAIRS)
	var scan_us:= _time_scans()
	var loaded:= await _reload()
	var mean:= _mean(diffs)
	var lo: float = diffs.min()
	var hi: float = diffs.max()
	print("    => %+.2f ms for %d drones (%+.2f to %+.2f over %d pairs); GPU %+.2f ms"
		% [mean, want, lo, hi, PAIRS, _mean(gpu_diffs)])
	if lo < 0.0 and hi > 0.0:
		print("    the pairs disagree in sign, so the frame cost is inside the noise.")
	print("    scan %.1f us a call; rebuilt in one frame as a save load does: worst frame %.2f ms, drone script worst %.2f ms, %d scans in one frame"
		% [scan_us, loaded ["worst"], loaded ["sworst"], int(loaded ["scans"])])
	return { "drones": want, "cost": mean, "lo": lo, "hi": hi, "gpu": _mean(gpu_diffs),
		"live": live_sum, "scan_us": scan_us, "loaded": loaded }


func _read(label: String, neutral: bool = false) -> Dictionary:
	if neutral:
		_neutralise(true)
	for i in SETTLE:
		await get_tree().process_frame
	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var rcpu:= 0.0
	var proc:= 0.0
	var airborne:= 0
	var worst:= 0
	_script_usec = 0
	_worst_script = 0
	_scans = 0
	_max_scans = 0
	var started:= Time.get_ticks_usec()
	var last:= started
	for i in SAMPLE:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		for d in _drones:
			if is_instance_valid(d) and d.busy():
				airborne += 1
	var n:= float(SAMPLE)
	var row:= { "wall": float(Time.get_ticks_usec() - started) / 1000.0 / n,
		"worst": float(worst) / 1000.0, "gpu": gpu / n, "rcpu": rcpu / n, "proc": proc / n,
		"script": float(_script_usec) / 1000.0 / n, "sworst": float(_worst_script) / 1000.0,
		"scans": float(_scans) / n, "airborne": float(airborne) / n }
	if neutral:
		_neutralise(false)
	print("  %-12s %7.2f %6.0f %7.2f %6.2f %6.2f %6.2f %7.3f %7.2f %6.2f %9.1f"
		% [label, row ["wall"], 1000.0 / maxf(row ["wall"], 0.001), row ["worst"], row ["gpu"],
			row ["rcpu"], row ["proc"], row ["script"], row ["sworst"], row ["scans"], row ["airborne"]])
	return row


func _neutralise(on: bool) -> void:
	_ticking = not on
	for d in _drones:
		if is_instance_valid(d):
			d.visible = not on


func _time_scans() -> float:
	var calls:= 0
	var t0:= Time.get_ticks_usec()
	for k in 20:
		for d in _drones:
			if is_instance_valid(d):
				d._find_pick()
				calls += 1
	return float(Time.get_ticks_usec() - t0) / float(maxi(1, calls))


func _reload() -> Dictionary:
	var n:= _drones.size()
	var builds: BuildManager = world.get("builds")
	for d in _drones:
		if is_instance_valid(d):
			builds.demolish(d)
	_drones.clear()
	_bales.clear()
	_clear_bales()
	await get_tree().process_frame
	_add_to(n, false)
	_script_usec = 0
	_worst_script = 0
	_max_scans = 0
	var worst:= 0
	var last:= Time.get_ticks_usec()
	for i in 240:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	return { "worst": float(worst) / 1000.0, "sworst": float(_worst_script) / 1000.0,
		"scans": _max_scans }


func _choose_pads(field: HayField) -> void:
	var space:= world.get_world_3d().direct_space_state
	var stand_at: Vector3 = (world.get("stand") as Node3D).global_position
	var reach:= Cfg.yard_inner_for_pile() + 12.0
	var found: Array [Vector3] = []
	var x:= - reach
	while x <= reach:
		var z:= - reach
		while z <= reach:
			var spot:= _clear_floor(space, field, x, z)
			if spot != Vector3.INF and spot.distance_to(stand_at) > 6.0:
				found.append(spot)
			z += SPACING
		x += SPACING
	if found.is_empty():
		return
	var nearer:= func(a: Vector3, b: Vector3) -> bool: return a.distance_to(stand_at) < b.distance_to(stand_at)
	found.sort_custom(nearer)
	_pads.append(found.pop_front())
	while not found.is_empty() and _pads.size() < STAGES [STAGES.size() - 1]:
		var best:= 0
		var best_d:= -1.0
		for i in found.size():
			var near:= INF
			for p in _pads:
				near = minf(near, found [i].distance_to(p))
			if near > best_d:
				best_d = near
				best = i
		_pads.append(found [best])
		found.remove_at(best)


func _clear_floor(space: PhysicsDirectSpaceState3D, field: HayField, x: float, z: float) -> Vector3:


	var inner: float = (world.get("warehouse") as Warehouse).inner - 1.6
	if absf(x) > inner or absf(z) > inner:
		return Vector3.INF
	var floor_y:= INF
	for off: Vector3 in [Vector3.ZERO, Vector3(1.5, 0, 1.5), Vector3(-1.5, 0, 1.5),
			Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, -1.5), BALE_OFFSET * Vector3(1, 0, 1)]:
		var at:= Vector3(x, 0, z) + off
		if field.height_at(at.x, at.z) > 0.05:
			return Vector3.INF
		var ray:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at + Vector3.DOWN)
		ray.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			return Vector3.INF
		var y: float = (hit ["position"] as Vector3).y
		if y > 0.2:
			return Vector3.INF
		floor_y = minf(floor_y, y)


	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var from:= Vector3(x, 1.0, z)
		var ray:= PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
		ray.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or (hit ["position"] as Vector3).distance_to(from) < 2.0:
			return Vector3.INF
	return Vector3(x, floor_y + 0.02, z)


func _strew_litter(field: HayField) -> void:
	var keep_out:= Tech.drone_radius() + 1.0
	var reach:= Cfg.yard_inner_for_pile() - 1.0
	var props: PropManager = world.get("props")
	var placed:= 0
	var x:= - reach
	while x <= reach and placed < LITTER:
		var z:= - reach
		while z <= reach and placed < LITTER:
			var inside:= false
			for p in _pads:
				if Vector2(p.x - x, p.z - z).length() < keep_out:
					inside = true
					break
			if not inside:
				var y:= field.height_at(x, z)
				var w: Carryable = props.spawn("hay_wad",
					Transform3D(Basis.IDENTITY, Vector3(x, y + 0.3, z)), { "strands": 120 })
				if w != null:
					w.freeze = true
					_litter.append(w)
				placed += 1
			z += 1.3
		x += 1.3


func _add_to(n: int, feed: bool = true) -> void:
	var builds: BuildManager = world.get("builds")
	while _drones.size() < mini(n, _pads.size()):
		var d: HayDrone = builds.add_hay_drone(_pads [_drones.size()], 0.0, 0.0)
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
	if feed:
		_feed()


func _feed() -> void:
	var r:= Tech.drone_radius()
	var props: PropManager = world.get("props")
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
			props.remove(b)
		_bales [i] = props.spawn("hay_bale",
			Transform3D(Basis.IDENTITY, _pads [i] + BALE_OFFSET),
			{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })


func _clear_bales() -> void:
	var props: PropManager = world.get("props")
	var doomed: Array [Carryable] = []
	for item in props.items:
		if not is_instance_valid(item) or _litter.has(item):
			continue
		if not item.has_method("sale_strands") or item.is_held():
			continue
		doomed.append(item)
	for item in doomed:
		props.remove(item)


func _park_the_camera() -> void:
	var reach:= Cfg.yard_inner_for_pile()
	_cam = Camera3D.new()
	_cam.name = "DroneScaleCamera"
	_cam.fov = 70.0
	_cam.far = 600.0
	world.add_child(_cam)
	var eye:= Vector3(0.0, Cfg.PILE_HEIGHT + reach * 0.9, reach * 1.6)
	_cam.look_at_from_position(eye, Vector3.ZERO, Vector3.UP)
	_cam.current = true
	(world.get("field") as HayField).update_lod(eye)
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)


func _mean(xs: Array [float]) -> float:
	var s:= 0.0
	for x in xs:
		s += x
	return s / float(maxi(1, xs.size()))


func _report(table: Array [Dictionary]) -> void:
	if table.is_empty():
		return
	print("\nwhat the drone sweep found (%s pile):" % Cfg.pile_size_id)
	print("  %-6s %9s %17s %8s %9s %9s %8s %9s %12s"
		% ["drones", "cost ms", "pairs", "GPU ms", "live ms", "worst ms", "script", "scan us", "loaded worst"])
	for r: Dictionary in table:
		var live: Dictionary = r ["live"]
		var loaded: Dictionary = r ["loaded"]
		print("  %-6d %+9.2f %+8.2f..%+6.2f %+8.2f %9.2f %9.2f %8.3f %9.1f %12.2f"
			% [int(r ["drones"]), float(r ["cost"]), float(r ["lo"]), float(r ["hi"]), float(r ["gpu"]),
				float(live ["wall"]), float(live ["worst"]), float(live ["script"]),
				float(r ["scan_us"]), float(loaded ["worst"])])
