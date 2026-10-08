class_name DevArmScaleProbe
extends Node


const SETTLE:= 30


const SAMPLE:= 75


const PAIRS:= 3


const STAGES: Array [int] = [8, 16, 24, 32, 48, 64, 96, 128]


const PITCH:= 4.5


const PER_ROW:= 12


const ORIGIN:= Vector3(-70.0, 0.0, 60.0)


const BELT_OFFSET:= 1.6


const RING_SPACING:= 3.6
const RING_BELT_GAP:= 1.6


const WAD_STRANDS:= 60


const FEED_INTERVAL:= 0.75


const MS_60:= 1000.0 / 60.0
const MS_30:= 1000.0 / 30.0


const CALM_WINDOW:= 60
const CALM_TOLERANCE:= 0.04
const CALM_LIMIT:= 3000

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D
var _top:= 0
var _feed_left:= 0.0
var _feeding:= false


var _subject: Array [RoboticArm] = []
var _hidden: Array [Node3D] = []
var _silenced: Array [Node] = []

var _standing:= 0
var _grid_metres:= 0.0

var _wall_log: Array [float] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)

	_top = STAGES [STAGES.size() - 1]
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			_top = maxi(STAGES [0], arg.to_int())


	Cfg.prop_cap = clampi(_top * 3, Cfg.PROP_CAP_MIN, Cfg.PROP_CAP_MAX)

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
	_cam.current = true

	print("\n=== what a robotic arm costs, at High, %d x %d ==="
		% [get_viewport().size.x, get_viewport().size.y])
	await _wait_for_calm()

	await _ring_phase()
	await _grid_phase()

	print("\n[armscale] done")
	get_tree().quit(0)


func _wait_for_calm() -> void:
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
			print("  the yard went still after %d frames, at %.2f ms."
				% [waited, ms])
			return
		previous = ms
	print("  the yard never went still: gave up after %d frames." % waited)
	print("  READ THE SPREADS BELOW BEFORE BELIEVING ANY OF IT.")


func _ring_phase() -> void:
	var builds: BuildManager = world.get("builds")
	var r_arm: float = field.crust_radius + 0.5
	var count:= int(floor(TAU * r_arm / RING_SPACING))
	var r_belt:= r_arm + RING_BELT_GAP

	var made: Array [RoboticArm] = []
	var belts: Array [Conveyor] = []
	for i in count:
		var t:= TAU * float(i) / float(count)
		var dir:= Vector3(sin(t), 0.0, cos(t))


		made.append(builds.add_robotic_arm(dir * r_arm, atan2(dir.x, dir.z)))
		var t2:= TAU * float(i + 1) / float(count)
		var dir2:= Vector3(sin(t2), 0.0, cos(t2))
		belts.append(_lay(builds, dir * r_belt, dir2 * r_belt))
	builds.rebuild_junctions()
	builds.changed.emit()


	var eye:= Vector3(0.0, r_belt * 0.75, r_belt + 14.0)
	_look(eye, Vector3(0.0, 2.0, 0.0))

	_subject = made
	print("\n--- the RING: %d arms round the pile, digging it ---" % count)
	print("  %d is not a chosen number. It is how many fit at %.1f m spacing"
		% [count, RING_SPACING])
	print("  round a crust of %.1f m, which is the most that can ever dig at once."
		% field.crust_radius)
	await _wait_for_calm()
	var cost:= await _paired("%d digging arms" % count, count)
	print("  a DIGGING arm costs %.3f ms, and %d of them cost %.2f ms."
		% [cost / float(maxi(count, 1)), count, cost])


	for arm in made:
		if is_instance_valid(arm):
			builds.demolish(arm)
	for c in belts:
		if is_instance_valid(c):
			builds.demolish(c)
	builds.rebuild_junctions()
	builds.changed.emit()
	_subject = []


func _grid_phase() -> void:
	_lay_grid_belts()
	var rows:= ceili(float(_top) / float(PER_ROW))
	var centre:= ORIGIN + Vector3(float(PER_ROW - 1) * PITCH * 0.5, 0.0,
		- float(rows - 1) * PITCH * 0.5)


	var span:= maxf(float(PER_ROW) * PITCH, float(rows) * PITCH)
	_look(centre + Vector3(0.0, span * 0.62, span * 0.95), centre)
	_feeding = true

	print("\n--- the GRID: arms picking wads onto belts ---")
	print("  %d stations on a %.1f m grid, %.0f m of belt laid before the first"
		% [_top, PITCH, _grid_metres])
	print("  reading, so only the arm count moves between rows. Prop cap %d."
		% Cfg.prop_cap)
	await _wait_for_calm()

	var table: Array [Dictionary] = []
	for want in STAGES:
		if want > _top:
			break
		_add_arms_to(want)
		table.append({ "arms": _standing,
			"cost": await _paired("%d arms" % _standing, _standing) })
	if _standing < _top:
		_add_arms_to(_top)
		table.append({ "arms": _standing,
			"cost": await _paired("%d arms" % _standing, _standing) })

	_report(table)


func _lay_grid_belts() -> void:
	var builds: BuildManager = world.get("builds")
	for i in _top:
		var at:= _station(i)
		_lay(builds, at + Vector3(- PITCH * 0.5, 0.0, BELT_OFFSET),
			at + Vector3(PITCH * 0.5, 0.0, BELT_OFFSET))
		_grid_metres += PITCH
	builds.rebuild_junctions()
	builds.changed.emit()


func _station(i: int) -> Vector3:
	var row:= i / PER_ROW
	var col:= i % PER_ROW
	return ORIGIN + Vector3(float(col) * PITCH, 0.0, - float(row) * PITCH)


func _add_arms_to(want: int) -> void:
	var builds: BuildManager = world.get("builds")
	var props: PropManager = world.get("props")
	while _standing < want:
		var at:= _station(_standing)


		_subject.append(builds.add_robotic_arm(at, 0.0))
		props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.35, -1.1)),
			{ "strands": WAD_STRANDS })
		_standing += 1
	builds.rebuild_junctions()
	builds.changed.emit()


func _process(delta: float) -> void:
	if not _feeding:
		return
	_feed_left -= delta
	if _feed_left > 0.0:
		return
	_feed_left = FEED_INTERVAL
	_feed()


func _feed() -> void:
	var props: PropManager = world.get("props")
	var loose: Array [Vector3] = []
	for it: Carryable in props.items:
		if is_instance_valid(it) and it.hay_strands() > 0:
			loose.append(it.global_position)
	for arm: RoboticArm in _subject:
		if not is_instance_valid(arm):
			continue
		var feet:= arm.global_position
		var r:= arm.reach_m()
		var fed:= false
		for p in loose:
			if p.distance_to(feet) <= r:
				fed = true
				break
		if fed:
			continue
		props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, feet + Vector3(0.0, 0.35, -1.1)),
			{ "strands": WAD_STRANDS })


func _paired(label: String, count: int) -> float:
	print("  %-22s %8s %6s %7s %7s %7s %7s %8s %10s"
		% [label, "ms", "fps", "GPU", "rCPU", "proc", "phys", "draws", "cycling"])
	var diffs: Array [float] = []
	var live_ms:= 0.0
	var busy:= 0.0
	for i in PAIRS:
		var live:= await _read("    live")
		var dead:= await _read("    neutralised", true)
		diffs.append(float(live ["wall"]) - float(dead ["wall"]))
		live_ms += float(live ["wall"])
		busy += float(live ["busy"])
	var mean:= 0.0
	var best:= 1000000000.0
	var worst:= -1000000000.0
	for d in diffs:
		mean += d
		best = minf(best, d)
		worst = maxf(worst, d)
	mean /= float(diffs.size())
	live_ms /= float(PAIRS)
	busy /= float(PAIRS)
	var share:= 0.0 if count <= 0 else busy / float(count) * 100.0
	print("    => %+.2f ms for %d arms (%+.2f to %+.2f over %d pairs), %.0f%% working, %d in frame"
		% [mean, count, best, worst, PAIRS, share, _in_frame()])


	if best < 0.0 and worst > 0.0:
		print("    the pairs disagree in sign, so this is noise and not a cost.")
	return mean


func _read(label: String, neutral: bool = false) -> Dictionary:
	if neutral:
		_neutralise()
	for i in SETTLE:
		await get_tree().process_frame

	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	var phys:= 0.0
	var proc:= 0.0
	var draws:= 0.0
	var busy:= 0.0
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		busy += float(_cycling())
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE
	if neutral:
		_restore()
	var row:= { "wall": wall, "gpu": gpu / SAMPLE, "cpu": cpu / SAMPLE,
		"phys": phys / SAMPLE, "proc": proc / SAMPLE, "draws": draws / SAMPLE,
		"busy": busy / SAMPLE }
	_wall_log.append(wall)
	print("  %-22s %8.2f %6.0f %7.2f %7.2f %7.2f %7.2f %8.0f %10.0f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), row ["gpu"], row ["cpu"],
			row ["proc"], row ["phys"], row ["draws"], row ["busy"]])
	return row


func _neutralise() -> void:
	for arm: RoboticArm in _subject:
		if not is_instance_valid(arm):
			continue
		if arm.visible:
			arm.visible = false
			_hidden.append(arm)
		arm.set_process(false)
		arm.set_physics_process(false)
		_silenced.append(arm)


func _restore() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	for n in _silenced:
		if is_instance_valid(n):
			n.set_process(true)
			n.set_physics_process(true)
	_silenced.clear()


func _cycling() -> int:
	var n:= 0
	for a: RoboticArm in _subject:
		if is_instance_valid(a) and a.get("_phase") != RoboticArm.Phase.IDLE:
			n += 1
	return n


func _in_frame() -> int:
	var n:= 0
	for a: RoboticArm in _subject:
		if not is_instance_valid(a):
			continue
		var shoulder:= a.global_position + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * a.visual_scale()
		if _cam.is_position_in_frustum(shoulder):
			n += 1
	return n


func _look(eye: Vector3, at: Vector3) -> void:
	_cam.look_at_from_position(eye, at, Vector3.UP)


	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	field.update_lod(eye)


func _lay(builds: BuildManager, from: Vector3, to: Vector3) -> Conveyor:
	var c:= Conveyor.new()
	c.name = "Conveyor%d" % builds.conveyors.size()
	c.setup(from, to)
	builds.conveyors.append(c)
	builds.add_child(c)
	return c


func _report(table: Array [Dictionary]) -> void:
	if table.is_empty():
		return
	print("\nwhat the grid sweep found:")
	print("  %-8s %12s %13s %14s"
		% ["arms", "cost ms", "ms per arm", "marginal"])
	var prev: Dictionary = { "arms": 0, "cost": 0.0 }
	for r: Dictionary in table:
		var arms:= int(r ["arms"])
		var cost: float = float(r ["cost"])
		var added: int = arms - int(prev ["arms"])
		var marginal:= 0.0
		if added > 0:
			marginal = (cost - float(prev ["cost"])) / float(added)
		print("  %-8d %12.2f %13.3f %14.3f"
			% [arms, cost, cost / float(maxi(arms, 1)), marginal])
		prev = r


	var last: Dictionary = table [table.size() - 1]
	var each: float = float(last ["cost"]) / float(maxi(int(last ["arms"]), 1))
	print("\n  one grid arm costs %.3f ms at the top of the sweep." % each)
	if each <= 0.0:
		print("  THAT IS NOT A COST. The arms did not read as more expensive than")
		print("  no arms at all, which means the frame at this count is being set")
		print("  by something else and the cap is not a frame rate question yet.")
	else:
		print("  a whole 60 fps frame is %.2f ms, so arms alone would fill one at"
			% MS_60)
		print("  about %d of them, and a tenth of one at about %d."
			% [int(MS_60 / each), int(MS_60 * 0.1 / each)])


	if _wall_log.size() >= 2:
		var lo:= 1000000000.0
		var hi:= -1000000000.0
		for w in _wall_log:
			lo = minf(lo, w)
			hi = maxf(hi, w)
		print("\n  across %d readings the frame wandered between %.2f and %.2f ms."
			% [_wall_log.size(), lo, hi])
		print("  the pairs are immune to a slope in that, and not to a jump.")
