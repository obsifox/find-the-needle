class_name DevFactoryFullProbe
extends Node


const TRACK_LEN:= 24.0
const TRACK_GAP:= 1.6
const TRACK_PITCH:= 4.0
const TRACKS_PER_TIER:= 6
const TIER_RISE:= 1.8
const DECK_Y:= 0.75
const TRACK_X0:= 22.0

const SEED_PITCH:= 0.32

const STREET_Z:= 26.0
const STREET_X0:= -24.0
const STREET_PITCH:= 7.0
const SPUR:= 4.0
const CHAIN:= 3.0

const WAD_STRANDS:= 60
const BELT_RANK:= 8
const ARMS:= 6
const FEED_PERIOD:= 1.0
const SINK_ZONE:= 0.6
const TIDY_TICKS:= 60

const DEFAULT_LOADS:= 3000
const DEFAULT_SECONDS:= 40
const DEFAULT_FRAMES:= 600
const WARMUP_FRAMES:= 240
const WINDOW:= Vector2i(1600, 900)
const FRAME_BUDGET_MS:= 1000.0 / 60.0

var world: Node3D
var player: Player

var _loads:= DEFAULT_LOADS
var _seconds:= DEFAULT_SECONDS
var _frames:= DEFAULT_FRAMES
var _windowed:= false

var _tracks: Array [Conveyor] = []
var _seeded:= 0

var _feeders: Array [Dictionary] = []

var _sinks: Array [Dictionary] = []
var _sunk: Dictionary = { }
var _made: Dictionary = { }
var _kinds_placed: Array [String] = []
var _kinds_missing: Array [String] = []
var _arms: Array [RoboticArm] = []
var _stairs: Array [HayStairs] = []
var _feed_clock:= 0.0
var _tick:= 0
var _tidied:= 0
var _fails: Array [String] = []
var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)

	set_physics_process(false)
	world.block_save = true
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0
	Cfg.detail_scale = 1.0
	_windowed = DisplayServer.get_name() != "headless"
	var ua:= OS.get_cmdline_user_args()
	_loads = _option_int(ua, "--loads", DEFAULT_LOADS)
	_seconds = _option_int(ua, "--seconds", DEFAULT_SECONDS)
	_frames = _option_int(ua, "--frames", DEFAULT_FRAMES)


	Tech.ranks ["belt_speed"] = BELT_RANK


	Cfg.belt_decay = false
	print("[factoryfull] %s, %d loads, %d s of production, %d %s timed, belt %.2f m/s, pile r %.1f"
		% ["windowed" if _windowed else "headless", _loads, _seconds, _frames,
			"frames" if _windowed else "ticks", Tech.belt_speed(), Cfg.PILE_RADIUS])

	if _windowed:
		DisplayServer.window_set_size(WINDOW)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		RenderingServer.viewport_set_measure_render_time(
			get_viewport().get_viewport_rid(), true)
		Cfg.apply_quality(Cfg.Quality.HIGH)
		world.call("_apply_render_settings")
		_hide_hud()

	if "--particles" in ua:
		var particles:= DevParticleStressProbe.new()
		particles.world = world
		particles.player = player
		add_child(particles)
		await particles.run(_frames)
		get_tree().quit(0)
		return

	var t0:= Time.get_ticks_usec()
	_build_street()
	_build_arms()
	_build_tracks()
	for i in 10:
		await get_tree().physics_frame
	_seeded = _seed_tracks()
	print("[factoryfull] built in %.1f s: %d conveyors, %d corners, %d racetracks, %d seeded riding, %d feeders, %d sinks"
		% [(Time.get_ticks_usec() - t0) / 1000000.0, _builds().conveyors.size(),
			_builds().corners.size(), _tracks.size() / 4, _seeded, _feeders.size(),
			_sinks.size()])
	if not _kinds_missing.is_empty():
		_fail("machine kinds refused: %s" % ", ".join(_kinds_missing))
	if _seeded < _loads:
		_fail("only %d of %d loads could be seeded" % [_seeded, _loads])


	if "--portcheck" in OS.get_cmdline_user_args():
		var port_fails: int = await preload("res://scripts/dev/port_index_check.gd").new().run(world, player.build)
		get_tree().quit(1 if port_fails > 0 else 0)
		return


	if "--memocheck" in OS.get_cmdline_user_args():
		var memo_fails: int = await preload("res://scripts/dev/yard_memo_check.gd").new().run(world, player.build)
		get_tree().quit(1 if memo_fails > 0 else 0)
		return

	if _windowed:
		_place_camera()


	set_physics_process(true)
	var ticks:= _seconds * 60
	for i in ticks:
		await get_tree().physics_frame
	_report_yard("after %d s of production" % _seconds)


	if _windowed:
		for i in WARMUP_FRAMES:
			await get_tree().process_frame
		var wall:= await _sample_frames(_frames)
		_report_frames(wall)
	else:
		var us:= await _time_ticks(_frames)
		_report_ticks(us)
	_report_yard("after the timing")
	_verdict()


func _physics_process(delta: float) -> void:
	_tick += 1
	_feed_clock += delta
	if _feed_clock >= FEED_PERIOD:
		_feed_clock -= FEED_PERIOD
		_feed()
	_sink()
	if _tick % TIDY_TICKS == 0:
		_tidy()


func _builds() -> BuildManager:
	return world.builds


func _props() -> PropManager:
	return world.props


func _build_street() -> void:
	var builds:= _builds()
	var slot:= 0

	var press: HayCompressor = builds.add_compressor(_slot(slot), 0.0)
	_placed("compressor", press)
	if press != null:
		press.baled_record.connect(func(_seq: int) -> void: _count("compressor bale"))
		_feed_into(press.port_in(), press.forward(), BeltRun.Kind.WAD, "compressor")
		var wrap: HayWrapper = builds.add_wrapper(_after(press.port_out(), press.forward()), 0.0)
		_placed("wrapper", wrap)
		if wrap != null:
			wrap.wrapped_record.connect(func(_seq: int) -> void: _count("wrapper foiled bale"))
			builds.add_conveyor(press.port_out(), wrap.port_in())
			_sink_from(wrap.port_out(), wrap.forward(), "wrapper")
	slot += 1


	var pulper: HayPulper = builds.add_pulper(_slot(slot), 0.0)
	_placed("pulper", pulper)
	if pulper != null:
		pulper.slabbed_record.connect(func(_seq: int) -> void: _count("pulper slab"))
		_feed_into(pulper.port_in(), pulper.forward(), BeltRun.Kind.WAD, "pulper")
		var mill: PaperMachine = builds.add_paper(_after(pulper.port_out(), pulper.forward()), 0.0)
		_placed("paper machine", mill)
		if mill != null:
			mill.rolled_record.connect(func(_seq: int) -> void: _count("paper roll"))
			builds.add_conveyor(pulper.port_out(), mill.port_in())
			_sink_from(mill.port_out(), mill.forward(), "paper machine")
	slot += 1


	var bp: BriquettePress = builds.add_briquette(_slot(slot), 0.0)
	_placed("briquette press", bp)
	if bp != null:
		bp.pressed_record.connect(func(_seq: int) -> void: _count("briquette disc"))
		_feed_into(bp.port_wad(), bp.bearing_at(bp.port_wad()), BeltRun.Kind.WAD, "briquette wad arm")
		_feed_into(bp.port_brick(), bp.bearing_at(bp.port_brick()), BeltRun.Kind.BRICK,
			"briquette brick arm")
		_sink_from(bp.port_out(), bp.bearing_at(bp.port_out()), "briquette press")
	slot += 1


	var mill2: HayPelletizer = builds.add_pelletizer(_slot(slot), 0.0)
	_placed("pelletizer", mill2)
	if mill2 != null:
		mill2.bricked.connect(func(_b: Variant) -> void: _count("pelletizer brick"))
		_feed_into(mill2.intake_port(), mill2.forward(), BeltRun.Kind.WAD, "pelletizer")
	slot += 1
	var gen: HayGenerator = builds.add_generator(_slot(slot), 0.0)
	_placed("generator", gen)
	if gen != null:
		gen.fired.connect(func() -> void: _count("generator fired"))
		_feed_into(gen.intake_port(), gen.forward(), BeltRun.Kind.BRICK, "generator")
	slot += 1
	var gun: TubeLauncher = builds.add_tube_launcher(_slot(slot), 0.0)
	_placed("tube launcher", gun)
	if gun != null:
		gun.launched.connect(func(_item: Variant) -> void: _count("launcher throw"))
		_feed_into(gun.intake_port(), gun.forward(), BeltRun.Kind.WAD, "tube launcher")
	slot += 1


	var tank: HaySilo = builds.add_silo(_slot(slot), 0.0)
	_placed("silo", tank)
	if tank != null:
		tank.discharged_record.connect(func(_seq: int) -> void: _count("silo discharge"))
		_feed_into(tank.port_in(), tank.forward(), BeltRun.Kind.WAD, "silo")
		_sink_from(tank.port_out(), tank.forward(), "silo")
	slot += 1
	var scanner: HaystackScanner = builds.add_scanner(_slot(slot), 0.0)
	_placed("scanner", scanner)
	if scanner != null:
		scanner.dispensed.connect(func(_n: int) -> void: _count("scanner batch"))
		_feed_into(scanner.port_in(), scanner.forward(), BeltRun.Kind.WAD, "scanner")
		_sink_from(scanner.port_out(), scanner.forward(), "scanner")
	slot += 1
	var lift: HayLift = builds.add_hay_lift(_slot(slot), 0.0, 2)
	_placed("lift", lift)
	if lift != null:
		lift.lifted_record.connect(func(_seq: int) -> void: _count("lift up"))
		_feed_into(lift.port_in(), lift.forward(), BeltRun.Kind.WAD, "lift")
		_sink_from(lift.port_out(), lift.forward(), "lift")
	slot += 1
	var tower: HayStairs = builds.add_hay_stairs(_slot(slot), 0.0)
	_placed("stairs", tower)
	if tower != null:
		_stairs.append(tower)
		tower.lowered_record.connect(func(_seq: int) -> void: _count("stairs down"))


		var mouth:= tower.mouth_position() + Vector3(0.0, 0.6, 0.0)
		_feed_into(mouth, Vector3(0.0, 0.0, 1.0), BeltRun.Kind.WAD, "stairs")
		_sink_from(tower.outfeed_port(), tower.outfeed_forward(), "stairs")
	slot += 1


	var y_split: ConveyorSplitter = builds.add_splitter(_slot(slot), 0.0)
	_placed("splitter", y_split)
	if y_split != null:
		_feed_into(y_split.port_in(), y_split.forward(), BeltRun.Kind.WAD, "splitter")
		for side in [ConveyorSplitter.LEFT, ConveyorSplitter.RIGHT]:
			var out:= (y_split.port(side) - y_split.global_position)
			out.y = 0.0
			_sink_from(y_split.port(side), out.normalized(), "splitter")
	slot += 1
	var y_join: ConveyorJoiner = builds.add_joiner(_slot(slot), 0.0)
	_placed("joiner", y_join)
	if y_join != null:
		for side in ConveyorJoiner.SIDES:
			_feed_into(y_join.port(side), y_join.arm_travel(side), BeltRun.Kind.WAD, "joiner")
		_sink_from(y_join.port_out(), y_join.forward(), "joiner")
	slot += 1
	var t_split: ConveyorTSplitter = builds.add_t_splitter(_slot(slot), 0.0)
	_placed("T splitter", t_split)
	if t_split != null:
		_feed_into(t_split.port_in(), t_split.forward(), BeltRun.Kind.WAD, "T splitter")
		for side in [ConveyorSplitter.LEFT, ConveyorSplitter.RIGHT]:
			_sink_from(t_split.port(side), t_split.arm_travel(side), "T splitter")
	slot += 1


	var t_join: ConveyorTSplitter = builds.add_t_splitter(_slot(slot), 0.0)
	_placed("T joiner (as a T)", t_join)
	if t_join != null:
		for side in [ConveyorSplitter.LEFT, ConveyorSplitter.RIGHT]:
			_feed_into(t_join.port(side), - t_join.arm_travel(side), BeltRun.Kind.WAD, "T joiner")
		_sink_from(t_join.port_in(), - t_join.forward(), "T joiner")
	slot += 1
	var u_split: ConveyorUSplitter = builds.add_u_splitter(_slot(slot), 0.0)
	_placed("U splitter", u_split)
	if u_split != null:
		_feed_into(u_split.port_in(), u_split.forward(), BeltRun.Kind.WAD, "U splitter")
		for side in [ConveyorSplitter.LEFT, ConveyorSplitter.RIGHT]:
			_sink_from(u_split.port(side), u_split.forward(), "U splitter")
	slot += 1
	var u_join: ConveyorUJoiner = builds.add_u_joiner(_slot(slot), 0.0)
	_placed("U joiner", u_join)
	if u_join != null:
		for side in ConveyorJoiner.SIDES:
			_feed_into(u_join.port(side), u_join.arm_travel(side), BeltRun.Kind.WAD, "U joiner")
		_sink_from(u_join.port_out(), u_join.forward(), "U joiner")
	slot += 1


	var stand: HaySellingStand = world.stand
	if stand != null:
		stand.sold.connect(func(_n: int, _amount: float) -> void: _count("stand sale"))
		var port: Vector3 = stand.belt_entry_point()
		var along: Vector3 = stand.intake_forward()
		var from:= port - along * 5.0
		from.y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
		var run: Conveyor = builds.add_conveyor(from, port)
		if run != null:
			_feeders.append({ "run": run, "kind": BeltRun.Kind.WAD, "strands": WAD_STRANDS,
				"name": "stand" })
			_kinds_placed.append("selling stand")
		else:
			_kinds_missing.append("selling stand run")


func _slot(i: int) -> Vector3:
	return Vector3(STREET_X0 + STREET_PITCH * float(i), 0.0, STREET_Z)


func _after(port_out: Vector3, forward: Vector3) -> Vector3:
	var at:= port_out + forward * (CHAIN + 1.6)
	at.y = 0.0
	return at


func _placed(kind: String, node: Node) -> void:
	if node != null:
		_kinds_placed.append(kind)
	else:
		_kinds_missing.append(kind)


func _feed_into(port: Vector3, forward: Vector3, kind: int, name: String) -> void:
	var run: Conveyor = _builds().add_conveyor(port - forward.normalized() * SPUR, port)
	if run == null:
		_kinds_missing.append("%s infeed" % name)
		return
	_feeders.append({ "run": run, "kind": kind,
		"strands": WAD_STRANDS if kind == BeltRun.Kind.WAD else Cfg.PELLETIZER_BRICK_STRANDS,
		"name": name })


func _sink_from(port: Vector3, forward: Vector3, name: String) -> void:
	var run: Conveyor = _builds().add_conveyor(port, port + forward.normalized() * SPUR)
	if run == null:
		_kinds_missing.append("%s outfeed" % name)
		return
	_sinks.append({ "run": run, "name": name })


func _build_arms() -> void:
	var builds:= _builds()
	var r:= Cfg.PILE_RADIUS + 1.8
	for i in ARMS:
		var t:= TAU * float(i) / float(ARMS) + 0.3
		var u:= Vector3(sin(t), 0.0, cos(t))
		var v:= Vector3(cos(t), 0.0, - sin(t))
		var at:= u * r + Vector3(0.0, 0.06, 0.0)
		var arm: RoboticArm = builds.add_robotic_arm(at, PI * 0.5 - t, 1)
		if arm == null:
			_kinds_missing.append("arm %d" % i)
			continue
		_arms.append(arm)
		var head:= at + u * 1.8 + Vector3(0.0, 0.39, 0.0)
		var run: Conveyor = builds.add_conveyor(head - v * 1.2, head + v * 2.4)
		if run == null:
			_kinds_missing.append("arm %d belt" % i)
			continue
		_sinks.append({ "run": run, "name": "arm" })
	if not _arms.is_empty():
		_kinds_placed.append("robotic arm")


func _build_tracks() -> void:
	var builds:= _builds()


	var per_track:= int(floor(2.0 * (TRACK_LEN - 1.0) / SEED_PITCH) * 0.9)
	var wanted:= int(ceil(float(_loads) / float(per_track)))
	for k in wanted:
		var col:= k % TRACKS_PER_TIER
		var tier:= k / TRACKS_PER_TIER
		var x:= TRACK_X0 + TRACK_PITCH * float(col)
		var y:= DECK_Y + TIER_RISE * float(tier)
		var z0:= - TRACK_LEN * 0.5
		var z1:= TRACK_LEN * 0.5
		var a:= Vector3(x, y, z0)
		var b:= Vector3(x, y, z1)
		var c:= Vector3(x + TRACK_GAP, y, z1)
		var d:= Vector3(x + TRACK_GAP, y, z0)
		var legs: Array [Conveyor] = []
		for pair: Array in [[a, b], [b, c], [c, d], [d, a]]:
			var run: Conveyor = builds.add_conveyor(pair [0] as Vector3, pair [1] as Vector3)
			if run == null:
				_fail("racetrack %d could not be laid at x %.1f, y %.1f" % [k, x, y])
				break
			legs.append(run)
		_tracks.append_array(legs)


func _seed_tracks() -> int:
	var made:= 0
	var per_leg:= 0
	var long_legs: Array [Conveyor] = []
	for run in _tracks:
		if run.path_length() > TRACK_LEN * 0.5:
			long_legs.append(run)
	if long_legs.is_empty():
		return 0
	per_leg = int(ceil(float(_loads) / float(long_legs.size())))
	for run in long_legs:
		var shape:= run.shape_of_kind(BeltRun.Kind.WAD, WAD_STRANDS)
		if shape.is_empty():
			break
		var reach: float = shape ["reach"]
		var lift: float = shape ["rest"]
		var length:= run.path_length()
		var here:= mini(per_leg, _loads - made)
		var span:= length - 1.0
		var pitch:= maxf(SEED_PITCH, span / float(maxi(here, 1)))
		var n:= mini(here, int(floor(span / pitch)) + 1)
		for j in range(n - 1, -1, -1):
			var s:= 0.5 + float(j) * pitch
			if run.run.board(BeltRun.Kind.WAD, WAD_STRANDS, -1, reach, 0.0, lift, s,
					run.drive_speed, { "strands": WAD_STRANDS }):
				made += 1
		run.wake()
	return made


func _feed() -> void:
	for f in _feeders:
		var run: Conveyor = f ["run"]
		if not is_instance_valid(run) or not run.is_inside_tree():
			continue
		var kind: int = f ["kind"]
		var strands: int = f ["strands"]
		var at:= run.run.pose_at(0.6, 0.0, 0.0).origin
		if run.push_record(kind, strands, -1, { "strands": strands }, at) >= 0:
			_made ["fed"] = int(_made.get("fed", 0)) + 1


func _sink() -> void:
	for s in _sinks:
		var run: Conveyor = s ["run"]
		if not is_instance_valid(run) or not run.is_inside_tree():
			continue
		var br: BeltRun = run.run
		if br.count() == 0:
			continue
		var limit:= run.path_length() - SINK_ZONE
		var i:= br.first() + br.count() - 1
		var took:= 0
		while i >= br.first():
			if br.s_of(i) >= limit:
				var was_head:= i == br.first()
				run.take_record_at(i)
				took += 1
				if was_head:
					break
			i -= 1
		if took > 0:
			var name: String = s ["name"]
			_sunk [name] = int(_sunk.get(name, 0)) + took


func _tidy() -> void:
	var props:= _props()
	var gone: Array [Carryable] = []
	for item in props.items:
		var rb:= item as Carryable
		if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
			continue
		if BeltPath.record_kind(rb) < 0 or rb.freeze or BeltPath.is_rider(rb):
			continue
		if rb.has_meta(HayLift.META_CARRIED) or rb.has_meta(HayStairs.META_CARRIED):
			continue
		if not rb.sleeping and rb.linear_velocity.length() > 0.05:
			continue
		var in_funnel:= false
		for tower in _stairs:
			if is_instance_valid(tower) and rb.global_position.distance_to(tower.mouth_position()) < 3.0:
				in_funnel = true
				break
		if in_funnel:
			continue
		gone.append(rb)
	for rb in gone:
		props.remove(rb)
		_tidied += 1


func _count(what: String) -> void:
	_made [what] = int(_made.get(what, 0)) + 1


func _time_ticks(ticks: int) -> Array [float]:
	var us: Array [float] = []
	var last:= Time.get_ticks_usec()
	var moves:= 0
	BeltRun.tick_usec = 0
	BeltRun.tick_calls = 0
	HotSpots.start()
	for i in ticks:
		await get_tree().physics_frame
		var now:= Time.get_ticks_usec()
		us.append(float(now - last))
		moves += FactoryClock.last_runs_usec
		last = now

	print("  belts move %.3f ms a tick, of which run.tick %.3f over %.1f runs a tick"
		% [moves / 1000.0 / ticks, BeltRun.tick_usec / 1000.0 / ticks,
		float(BeltRun.tick_calls) / ticks])
	HotSpots.stop()
	print("  every named system, a tick:")
	for line in HotSpots.lines(ticks):
		print(line)
	return us


func _sample_frames(frames: int) -> Dictionary:
	var rid:= get_viewport().get_viewport_rid()
	var wall: Array [float] = []
	var gpu:= 0.0
	var cpu:= 0.0
	var phys:= 0.0
	var proc:= 0.0
	var draws:= 0.0
	var last:= Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		wall.append(float(now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return { "wall": wall, "gpu": gpu / frames, "cpu": cpu / frames, "phys": phys / frames,
		"proc": proc / frames, "draws": draws / frames }


func _report_ticks(us: Array [float]) -> void:
	var sorted: Array [float] = us.duplicate()
	sorted.sort()
	var sum:= 0.0
	for v in us:
		sum += v
	var mean:= sum / maxf(float(us.size()), 1.0) / 1000.0
	var p99: float = sorted [mini(int(sorted.size() * 0.99), sorted.size() - 1)] / 1000.0
	var median: float = sorted [sorted.size() / 2] / 1000.0
	var worst: float = sorted [sorted.size() - 1] / 1000.0
	print("\n=== ms per physics tick (headless), %d ticks, %d riding ===" % [us.size(), BeltPath.belt_load()])
	print("  mean %.2f   median %.2f   99th %.2f   worst %.2f" % [mean, median, p99, worst])
	print("  GATE tick: %.2f ms mean against the %.2f ms frame" % [mean, FRAME_BUDGET_MS])


func _report_frames(row: Dictionary) -> void:
	var wall: Array [float] = row ["wall"]
	var sorted:= wall.duplicate()
	sorted.sort()
	var median: float = sorted [sorted.size() / 2]
	var p95: float = sorted [mini(int(sorted.size() * 0.95), sorted.size() - 1)]
	var p99: float = sorted [mini(int(sorted.size() * 0.99), sorted.size() - 1)]
	var slow:= 0
	for v in wall:
		if v > FRAME_BUDGET_MS:
			slow += 1
	print("\n=== ms per frame (windowed %dx%d, dial off, High), %d frames, %d riding ==="
		% [WINDOW.x, WINDOW.y, wall.size(), BeltPath.belt_load()])
	print("  median %.2f (%.1f fps)   p95 %.2f   p99 %.2f   over budget %d of %d"
		% [median, 1000.0 / maxf(median, 0.001), p95, p99, slow, wall.size()])
	print("  physics %.2f   process %.2f   render cpu %.2f   gpu %.2f   draw calls %d"
		% [row ["phys"], row ["proc"], row ["cpu"], row ["gpu"], int(row ["draws"])])
	if median > FRAME_BUDGET_MS:
		_fail("median frame %.2f ms is over the %.2f ms of 60 fps (%.1f fps)"
			% [median, FRAME_BUDGET_MS, 1000.0 / median])
	else:
		print("  ok   GATE frame: median %.2f ms, under the %.2f ms of 60 fps"
			% [median, FRAME_BUDGET_MS])


func _riding_on_tracks() -> int:
	var n:= 0
	for run in _tracks:
		if is_instance_valid(run) and run.is_inside_tree():
			n += run.run.count()
	for c in _builds().corners:
		var corner:= c as ConveyorCorner
		if corner != null and is_instance_valid(corner) and corner.is_inside_tree():
			n += corner.run.count()
	return n


func _report_yard(when: String) -> void:
	var cycles:= 0
	for arm in _arms:
		if is_instance_valid(arm):
			cycles += arm.completed_cycles
	print("\n=== the yard %s ===" % when)
	print("  riding on the racetracks %d of %d seeded, riding everywhere %d, loose bodies %d, tidied %d"
		% [_riding_on_tracks(), _seeded, BeltPath.belt_load(), _props().items.size(), _tidied])
	print("  fed %d records onto the infeeds, arm cycles %d" % [int(_made.get("fed", 0)), cycles])
	var names: Array = _made.keys()
	names.sort()
	for name in names:
		if name == "fed":
			continue
		print("  made  %-24s %d" % [name, int(_made [name])])
	var sinks: Array = _sunk.keys()
	sinks.sort()
	for name in sinks:
		print("  sunk  %-24s %d" % [name, int(_sunk [name])])


func _verdict() -> void:
	var on_tracks:= _riding_on_tracks()
	if on_tracks < int(float(_seeded) * 0.98):
		_fail("the racetracks lost loads: %d of %d still riding" % [on_tracks, _seeded])


	for what in ["compressor bale", "silo discharge", "lift up", "stairs down", "stand sale"]:
		if int(_made.get(what, 0)) < 1:
			_fail("nothing made: %s" % what)


	for name in ["scanner", "splitter", "joiner", "T splitter", "U splitter", "U joiner"]:
		if int(_sunk.get(name, 0)) < 1:
			_fail("nothing came out of the %s" % name)
	var cycles:= 0
	for arm in _arms:
		if is_instance_valid(arm):
			cycles += arm.completed_cycles
	if cycles < 1:
		_fail("no arm completed a cycle")


	var t_joiners:= 0
	for j in _builds().joiners:
		if j is ConveyorTJoiner:
			t_joiners += 1
	if t_joiners > 0:
		_kinds_placed.append("T joiner")
	else:
		_fail("the T with two feeds was not made a T joiner")
	print("\n  machine kinds placed: %s" % ", ".join(_kinds_placed))
	if _fails.is_empty():
		print("\n[factoryfull] PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("  FAIL  %s" % f)
		print("\n[factoryfull] FAIL: %d" % _fails.size())
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_fails.append(msg)


func _option_int(ua: PackedStringArray, flag: String, fallback: int) -> int:
	var i:= ua.find(flag)
	if i >= 0 and i + 1 < ua.size():
		return int(ua [i + 1])
	return fallback


func _hide_hud() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		for kid: Node in node.get_children():
			stack.append(kid)


func _place_camera() -> void:
	var eye:= Vector3(58.0, 20.0, 46.0)
	var aim:= Vector3(24.0, 2.0, 6.0)
	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.05
	_cam.far = player.camera.far if player != null and player.camera != null else 2000.0
	world.add_child(_cam)
	_cam.look_at_from_position(eye, aim, Vector3.UP)
	_cam.current = true
	if player != null:
		player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
		player.velocity = Vector3.ZERO
	if world.field != null:
		world.field.update_lod(eye)
