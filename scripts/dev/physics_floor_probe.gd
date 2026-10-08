class_name DevPhysicsFloorProbe
extends Node


const WARM_WINDOW:= 120
const WARM_MAX:= 5400

const SETTLE:= 60

const SAMPLE:= 300


const SPIKE_SAMPLE:= 900
const SPIKE_MS:= 25.0

var world: Node3D
var player: Node3D


var _t_phys:= 0
var _t_first:= 0
var _t_last:= 0
var _t_proc:= 0
var _sampling:= false
var _n:= 0
var _proc_frames:= 0
var _cb:= 0
var _step:= 0
var _rest:= 0
var _total:= 0


var _groups: Dictionary = { }

var _classes: Dictionary = { }

var _other_names: Dictionary = { }

var _silenced: Array [Node] = []

var _areas_off: Array [Dictionary] = []
var _colls_off: Array [CollisionShape3D] = []
var _slept:= false
var _rows: Array [Dictionary] = []
var _tail: Node

var _spike_mode:= false
var _tick_total:= PackedFloat32Array()
var _tick_cb:= PackedFloat32Array()
var _tick_step:= PackedFloat32Array()
var _tick_rest:= PackedFloat32Array()


class Tail extends Node:
	var probe: Node

	func _physics_process(_delta: float) -> void:
		probe._t_last = Time.get_ticks_usec()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	player = world.player
	world.block_save = true
	process_physics_priority = -1000000
	_tail = Tail.new()
	_tail.name = "Tail"
	_tail.probe = self
	_tail.process_physics_priority = 1000000
	add_child(_tail)
	get_tree().physics_frame.connect(_on_physics_frame)
	get_tree().process_frame.connect(_on_process_frame)

	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--physfloor")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("PHYSFLOOR: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("PHYSFLOOR: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	var meta: Dictionary = d.get("meta", { })
	print("PHYSFLOOR: '%s' on %s, save version %d, %d buildings, %d props, block_save=%s"
		% [str(meta.get("name", "")), str(meta.get("map", "warehouse")),
			int(d.get("version", 0)), (d.get("buildings", []) as Array).size(),
			(d.get("props", []) as Array).size(), world.block_save])


	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		world.field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))
	var restored: int = world.props.items.size()


	if restored > Cfg.prop_cap and not ("--spikes" in ua):
		print("PHYSFLOOR: prop cap lifted from %d to %d, so the yard stops draining"
			% [Cfg.prop_cap, restored])
		Cfg.prop_cap = restored
	_count_unstable()


	if "--still" in ua:
		_file_the_tree()
		_silence(_groups.get("the placed buildings", []))
		_silenced.clear()
		_groups.erase("the placed buildings")
		_classes.clear()
		print("PHYSFLOOR: --still, the placed buildings are silenced before the warm up")
	await _warm_up()

	if _groups.is_empty():
		_file_the_tree()
	_count_the_space()
	if "--spikes" in ua:
		await _spike_table()
		get_tree().quit(0)
		return
	if "--funcs" in ua:
		await _funcs_table()
		get_tree().quit(0)
		return
	if "--clock" in ua:
		await _clock_table()
		get_tree().quit(0)
		return
	if "--income" in ua:
		await _income_run()
		get_tree().quit(0)
		return
	if "--reloadcheck" in ua:
		await _reload_check()
		return

	await _row("everything on (baseline)", func() -> void: pass)
	for key: String in _group_order():
		var nodes: Array = _groups.get(key, [])
		if nodes.is_empty():
			continue
		var silence_them:= func() -> void: _silence(nodes)
		await _row("%s silenced (%d)" % [key, nodes.size()], silence_them)
		if key != "the placed buildings":
			continue
		var names: Array = _classes.keys()
		var bigger:= func(a: String, b: String) -> bool: return (_classes [a] as Array).size() > (_classes [b] as Array).size()
		names.sort_custom(bigger)
		for ck: String in names:
			var these: Array = _classes [ck]
			var silence_these:= func() -> void: _silence(these)
			await _row("%s silenced (%d)" % [ck, these.size()], silence_these)
	await _row("every callback silenced", _silence_everything)


	await _row("every callback silenced + areas off", func() -> void:
		_silence_everything()
		_areas_off_now())
	await _row("props asleep", _sleep_the_props)
	await _row("every callback silenced + areas off + props asleep", func() -> void:
		_silence_everything()
		_areas_off_now()
		_sleep_the_props())
	await _row("everything on (baseline, again)", func() -> void: pass)

	await _row("crust colliders off", _crust_colliders_off)
	await _row("every callback silenced + areas off + props asleep + crust off",
		func() -> void:
			_silence_everything()
			_areas_off_now()
			_sleep_the_props()
			_crust_colliders_off())

	_report()
	get_tree().quit(0)


func _count_unstable() -> void:
	var field: HayField = world.field
	var nv: int = field.get("_nv")
	var heights: PackedFloat32Array = field.heights
	var unstable:= 0
	var worst:= 0.0
	for j in nv:
		for i in nv:
			var idx:= j * nv + i
			var h:= heights [idx]
			if h <= 0.0:
				continue
			for n in 4:
				var ni:= i + (1 if n == 0 else (-1 if n == 1 else 0))
				var nj:= j + (1 if n == 2 else (-1 if n == 3 else 0))
				if ni < 0 or nj < 0 or ni >= nv or nj >= nv:
					continue
				var nidx:= nj * nv + ni
				var over: float = h - heights [nidx] - field._step_limit(idx, nidx)
				if over > HayField.RESEED_MARGIN:
					unstable += 1
					worst = maxf(worst, over)
					break
	print("PHYSFLOOR: %d of %d vertices are steeper than the rule as loaded (worst by %.3f m)"
		% [unstable, nv * nv, worst])


func _warm_up() -> void:
	var field: HayField = world.field
	var last:= -1.0
	var spent:= 0
	print("--- warm up (%d-tick windows) ---" % WARM_WINDOW)
	while spent < WARM_MAX:
		_n = 0
		_total = 0
		_cb = 0
		_step = 0
		_rest = 0
		_sampling = true
		for i in WARM_WINDOW:
			await get_tree().physics_frame
		_sampling = false
		spent += WARM_WINDOW
		var n:= maxi(_n, 1)
		var now:= _total / 1000.0 / n
		print("  %5.1f s   tick %6.2f ms = callbacks %5.2f + step %5.2f + rest %5.2f   field settling %d"
			% [spent / 60.0, now, _cb / 1000.0 / n, _step / 1000.0 / n,
				_rest / 1000.0 / n, field.settling_count()])
		var steady:= last > 0.0 and absf(now - last) < 0.08 * last
		last = now
		if steady and field.settling_count() == 0 and spent >= WARM_WINDOW * 3:
			break
	print("  warmed up after %.1f s" % (spent / 60.0))


func _on_physics_frame() -> void:
	if _funcs_on:
		_funcs_silence()
	var now:= Time.get_ticks_usec()


	if _all_silenced and _sampling:
		_silence_everything()
	if _sampling and _t_phys > 0 and _t_first >= _t_phys and _t_last >= _t_first and _t_proc >= _t_last:
		_cb += _t_last - _t_first
		_step += _t_proc - _t_last
		_rest += now - _t_proc
		_total += now - _t_phys
		_n += 1
		if _spike_mode:
			_tick_total.append((now - _t_phys) / 1000.0)
			_tick_cb.append((_t_last - _t_first) / 1000.0)
			_tick_step.append((_t_proc - _t_last) / 1000.0)
			_tick_rest.append((now - _t_proc) / 1000.0)
	_t_phys = now


func _physics_process(delta: float) -> void:
	_t_first = Time.get_ticks_usec()
	if _funcs_on:
		_funcs_tick(delta)


func _process(delta: float) -> void:
	if not _funcs_on:
		return
	for item in _f_arms:
		if is_instance_valid(item) and (item as Node).is_inside_tree():
			_drive_arm(item as RoboticArm, delta)


func _income_run() -> void:
	var ua:= OS.get_cmdline_user_args()
	var seconds:= 600.0
	var at:= ua.find("--seconds")
	if at >= 0 and at + 1 < ua.size():
		seconds = float(ua [at + 1])
	var ticks:= int(seconds * Engine.physics_ticks_per_second)
	var money0:= GameState.money_earned
	var sold0:= GameState.hay_sold
	var cash0:= GameState.money
	var seq0:= BeltRun._next_seq
	var needles0:= GameState.needles_found
	var frame0:= Engine.get_process_frames()
	var called:= 0
	var t0:= Time.get_ticks_usec()
	for k in ticks:
		await get_tree().physics_frame
		called += FactoryClock.last_called
	var wall:= Time.get_ticks_usec() - t0
	var frames:= maxi(Engine.get_process_frames() - frame0, 1)
	print("INCOME: %.0f s simulated, %d ticks in %d frames, frame tick %s" % [
		seconds, ticks, frames, BeltPath.frame_tick_enabled])
	print("INCOME: earned %.2f, hay sold %.2f, cash %+.2f, loads boarded %d, needles %d" % [
		GameState.money_earned - money0, GameState.hay_sold - sold0,
		GameState.money - cash0, BeltRun._next_seq - seq0,
		GameState.needles_found - needles0])
	print("INCOME: wall %.2f ms a tick, %.2f ms a frame, machine calls %.1f a tick" % [
		wall / 1000.0 / ticks, wall / 1000.0 / frames, float(called) / ticks])


static var _reload_pass:= 0
static var _reload_earned: Array [float] = []
static var _reload_fails:= 0
const RELOADS:= 2


func _reload_check() -> void:
	var ua:= OS.get_cmdline_user_args()
	var seconds:= 60.0
	var at:= ua.find("--seconds")
	if at >= 0 and at + 1 < ua.size():
		seconds = float(ua [at + 1])
	var pass_no:= _reload_pass
	print("\nRELOAD: pass %d, clock stride %d" % [pass_no, FactoryClock.stride])
	for k in 5:
		await get_tree().physics_frame


	var stale_machines:= 0
	for m in FactoryClock._machines:
		if not is_instance_valid(m) or not (m as Node).is_inside_tree():
			stale_machines += 1
	var live_ids:= { }
	for m in FactoryClock._machines:
		if is_instance_valid(m):
			live_ids [m.get_instance_id()] = true
	var stale_owed:= 0
	for id in FactoryClock._owed_by:
		if not live_ids.has(id):
			stale_owed += 1
	var stale_awake:= 0
	for q in BeltPath._awake:
		if not is_instance_valid(q) or not (q as Node).is_inside_tree():
			stale_awake += 1
	var stale_loads:= 0
	for id in BeltPath._load_by_path:
		var o:= instance_from_id(id)
		if o == null or not (o as Node).is_inside_tree():
			stale_loads += 1
	var sum:= 0.0
	for id in BeltPath._load_by_path:
		sum += float(BeltPath._load_by_path [id])
	var total_gap:= absf(sum - BeltPath._load_total)
	print("RELOAD:   machines on the clock %d (%d stale), owed %d (%d stale), awake paths %d (%d stale), load table %d (%d stale), total off by %.6f"
		% [FactoryClock._machines.size(), stale_machines, FactoryClock._owed_by.size(),
			stale_owed, BeltPath._awake.size(), stale_awake,
			BeltPath._load_by_path.size(), stale_loads, total_gap])
	if pass_no > 0:
		_reload_ok("no machine of the old scene is still on the clock", stale_machines == 0)
		_reload_ok("no owed time is kept for a machine that is gone", stale_owed == 0)
		_reload_ok("no path of the old scene is still listed awake", stale_awake == 0)
		_reload_ok("no load is still counted for a path that is gone", stale_loads == 0)
	_reload_ok("the running belt total matches the table", total_gap < 0.001)
	var money0:= GameState.money_earned
	var seq0:= BeltRun._next_seq
	for k in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	var earned:= GameState.money_earned - money0
	_reload_earned.append(earned)
	print("RELOAD:   earned %.2f in %.0f s, loads boarded %d, props %d"
		% [earned, seconds, BeltRun._next_seq - seq0, world.props.items.size()])
	if pass_no > 0:
		_reload_ok("the factory earns after the reload (%.2f, first pass %.2f)"
			% [earned, _reload_earned [0]], earned > 0.25 * _reload_earned [0])
	if pass_no >= RELOADS:
		print("\n[reloadcheck] %s" % ("PASS" if _reload_fails == 0 else "FAIL (%d)" % _reload_fails))
		get_tree().quit(0 if _reload_fails == 0 else 1)
		return
	_reload_pass += 1

	get_tree().reload_current_scene()


func _reload_ok(what: String, ok: bool) -> void:
	print("RELOAD:   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_reload_fails += 1


var _waited:= 0


func _clock_table() -> void:
	var n:= FUNC_SAMPLE
	FactoryClock.prof.clear()
	FactoryClock.profile = not ("--noprof" in OS.get_cmdline_user_args())
	var runs:= 0
	var flush:= 0
	var machines:= 0
	var ticks:= 0
	var t_start:= Time.get_ticks_usec()
	BeltRun.tick_usec = 0
	BeltRun.tick_calls = 0
	for k in n:
		await get_tree().physics_frame
		runs += FactoryClock.last_runs_usec
		flush += FactoryClock.last_flush_usec
		machines += FactoryClock.last_machines_usec
		_waited += FactoryClock.last_waiting
		ticks += 1
	var wall:= Time.get_ticks_usec() - t_start
	FactoryClock.profile = false
	var bands:= { }
	for m in FactoryClock._machines:
		if not is_instance_valid(m) or not (m is Node3D):
			continue
		var d:= (m as Node3D).global_position.distance_to(BeltPath.focus)
		var band:= "%3d-%3d m" % [int(d / 15.0) * 15, int(d / 15.0) * 15 + 15]
		bands [band] = int(bands.get(band, 0)) + 1
	var bk: Array = bands.keys()
	bk.sort()
	print("  machines by distance from the player at %s:" % BeltPath.focus)
	for b in bk:
		print("    %s  %d" % [b, bands [b]])
	for p in BeltPath._live:
		if is_instance_valid(p) and (p as BeltPath).get_parent() is HayGenerator and p.is_physics_processing():
			print("  generator belt %s riders %d records %d asleep %s" % [
				p.get_path(), p._riders.size(), p.run.count(), p._asleep])
	print("--- clock: %d ticks, %d belts live, wall %.2f ms a tick ---"
		% [ticks, BeltPath._live.size(), wall / 1000.0 / ticks])
	var owned:= { }
	for bp in BeltPath._live:
		if is_instance_valid(bp) and bp.is_inside_tree():
			var par = bp.get_parent()
			var row: Array = owned.get(par, [0, 0])
			row [0] += 1
			if bp._asleep:
				row [1] += 1
			owned [par] = row
	var idle_by:= { }
	for m in FactoryClock._machines:
		if not is_instance_valid(m) or not owned.has(m):
			continue
		var r: Array = owned [m]
		var c:= FactoryClock.class_of(m)
		var t: Array = idle_by.get(c, [0, 0])
		t [0] += 1
		if r [0] == r [1]:
			t [1] += 1
		idle_by [c] = t
	print("  machines with every own path asleep [owning, idle]: %s" % idle_by)
	print("  belt census [live, asleep] %s, machines waiting %.1f a tick" % [BeltPath.sleep_census(), float(_waited) / ticks])
	print("  run.tick %.3f ms a tick over %.1f runs a tick, %.2f us a run" % [
		BeltRun.tick_usec / 1000.0 / ticks, float(BeltRun.tick_calls) / ticks,
		float(BeltRun.tick_usec) / maxi(BeltRun.tick_calls, 1)])
	print("  clock runs %.3f + flush %.3f + machines %.3f ms a tick" % [
		runs / 1000.0 / ticks, flush / 1000.0 / ticks, machines / 1000.0 / ticks])
	var keys: Array = FactoryClock.prof.keys()
	var costlier:= func(x, y) -> bool: return int(FactoryClock.prof [x] [0]) > int(FactoryClock.prof [y] [0])
	keys.sort_custom(costlier)
	print("  %-52s %9s %9s %9s" % ["what", "ms a tick", "us a call", "calls/tick"])
	for key: String in keys:
		var row: Array = FactoryClock.prof [key]
		print("  %-52s %9.3f %9.1f %9.1f" % [key, row [0] / 1000.0 / ticks,
			float(row [0]) / maxi(row [1], 1), float(row [1]) / ticks])


const FUNC_SAMPLE:= 1800

var _funcs_on:= false
var _f_splitters: Array = []
var _f_generators: Array = []
var _f_arms: Array = []


var _f_driven: Dictionary = { }
var _f_us: Dictionary = { }
var _f_calls: Dictionary = { }
var _f_riders:= 0
var _f_belt_steps:= 0
var _f_stalls: Dictionary = { }


func _funcs_table() -> void:
	var b: BuildManager = world.builds
	_f_splitters = b.splitters.duplicate()
	_f_generators = b.generators.duplicate()
	_f_arms = b.robotic_arms.duplicate()
	print("--- funcs: %d ticks, %d splitters, %d generators, %d arms, %d belts ---"
		% [FUNC_SAMPLE, _f_splitters.size(), _f_generators.size(), _f_arms.size(),
			BeltPath._live.size()])
	_funcs_on = true
	for k in FUNC_SAMPLE:
		await get_tree().physics_frame
	_funcs_on = false
	for item in _f_driven.values():
		if is_instance_valid(item) and not (item as BeltPath)._asleep:
			(item as Node).set_physics_process(true)
	for item in _f_splitters + _f_generators:
		if is_instance_valid(item):
			(item as Node).set_physics_process(true)
	for item in _f_arms:
		if is_instance_valid(item):
			(item as Node).set_process(true)

	var keys: Array = _f_us.keys()
	keys.sort_custom(func(x, y) -> bool: return int(_f_us [x]) > int(_f_us [y]))
	print("  %-48s %9s %11s %9s" % ["step", "ms a tick", "us a call", "calls"])
	for key: String in keys:
		var us:= float(_f_us [key])
		var calls:= maxi(int(_f_calls [key]), 1)
		print("  %-48s %9.3f %11.1f %9d" % [key, us / 1000.0 / FUNC_SAMPLE, us / calls, calls])
	print("  belts stepped %.1f a tick, carrying %.1f riders a tick between them"
		% [float(_f_belt_steps) / FUNC_SAMPLE, float(_f_riders) / FUNC_SAMPLE])
	print("  what the arms' scans ended on:")
	for reason: String in _f_stalls:
		print("    %5d  %s" % [int(_f_stalls [reason]), reason if reason != "" else "(started a cycle)"])
	print("\n[physfloor] funcs done")


func _lap(key: String, since: int) -> int:
	var now:= Time.get_ticks_usec()
	_f_us [key] = int(_f_us.get(key, 0)) + now - since
	_f_calls [key] = int(_f_calls.get(key, 0)) + 1
	return Time.get_ticks_usec()


func _funcs_silence() -> void:
	for item in BeltPath._live:
		if not is_instance_valid(item):
			continue
		var node:= item as Node
		if node.is_physics_processing():
			node.set_physics_process(false)
			_f_driven [node.get_instance_id()] = node
	for item in _f_splitters + _f_generators:
		if is_instance_valid(item):
			(item as Node).set_physics_process(false)
	for item in _f_arms:
		if is_instance_valid(item):
			(item as Node).set_process(false)


func _funcs_tick(delta: float) -> void:
	for item in _f_splitters:
		if is_instance_valid(item) and (item as Node).is_inside_tree():
			_drive_splitter(item as ConveyorSplitter, delta)
	for item in _f_generators:
		if is_instance_valid(item) and (item as Node).is_inside_tree():
			_drive_generator(item as HayGenerator, delta)
	for item in _f_driven.values():
		if is_instance_valid(item) and (item as Node).is_inside_tree() and not (item as BeltPath)._asleep:
			_drive_belt(item as BeltPath, delta)


func _drive_belt(bp: BeltPath, delta: float) -> void:
	if bp._spans.is_empty():
		return
	bp._owed += delta
	var stride:= bp._tick_stride()
	if stride > 1 and (Engine.get_physics_frames() + bp._stagger) % stride != 0:
		return
	var whole:= Time.get_ticks_usec()
	_f_belt_steps += 1
	_f_riders += bp._riders.size()
	var dt: float = bp._owed
	bp._owed = 0.0
	var t:= Time.get_ticks_usec()
	bp._carry(dt)
	t = _lap("belt _carry", t)
	bp._catch()
	t = _lap("belt _catch", t)
	bp._tuft_perched()
	t = _lap("belt _tuft_perched", t)
	bp._fold_unplaced()
	t = _lap("belt _fold_unplaced", t)
	bp._ride_clock += dt
	if bp._took_straw:
		bp._took_straw = false
		bp._gather_straw()
		t = _lap("belt _gather_straw", t)
	bp._settle_loose()
	t = _lap("belt _settle_loose", t)
	bp._wake_clock += dt
	if bp._wake_clock >= BeltPath.WAKE_EVERY:
		bp._wake_clock = 0.0
		bp._wake_sleepers()
		t = _lap("belt _wake_sleepers", t)
	bp._shed_clock += dt
	if bp._shed_clock >= BeltPath.SHED_EVERY:
		bp._shed_clock = 0.0
		bp._shed_over_cap()
		t = _lap("belt _shed_over_cap", t)
	bp._update_deck(dt)
	t = _lap("belt _update_deck", t)
	BeltPath._put_load(bp.get_instance_id(), bp._ride_load())
	t = _lap("belt _ride_load", t)
	if bp._riders.is_empty() and not bp._deck_occupied():
		bp._sleep()
	t = _lap("belt sleep test", t)
	_lap("belt whole tick: %s" % _class_of(bp), whole)


func _drive_splitter(s: ConveyorSplitter, delta: float) -> void:
	var t:= Time.get_ticks_usec()
	s._tick_stalls(delta)
	t = _lap("splitter _tick_stalls", t)
	s._apply_catching()
	t = _lap("splitter _apply_catching", t)
	var side:= s._open_side()
	if side < 0:
		side = s.next_side
	t = _lap("splitter _open_side", t)
	var lanes:= s._sweep_lanes()
	t = _lap("splitter _sweep_lanes", t)
	var exit_dir:= s._arm_local(1.0 if side == ConveyorSplitter.LEFT else -1.0).normalized()
	WyeSweep.run(s._sweep, s, lanes, Cfg.BELT_SPEED, exit_dir)
	t = _lap("splitter WyeSweep.run", t)
	var target:= s._gate_target()
	t = _lap("splitter _gate_target", t)
	if not is_equal_approx(s._gate_angle, target):
		s._gate_angle = move_toward(s._gate_angle, target, Cfg.SPLITTER_GATE_SPEED * delta)
		s._apply_gate()
	_lap("splitter gate", t)


func _drive_generator(g: HayGenerator, delta: float) -> void:
	var t:= Time.get_ticks_usec()
	g._drain_saved_ash()
	t = _lap("generator _drain_saved_ash", t)
	var held: float = g.fuel
	g._fed_kj = 0.0
	g._refused = false
	g._oversize = false
	g._intake_fuel()
	t = _lap("generator _intake_fuel", t)
	g.starved_for = 0.0 if g.fuel > held else g.starved_for + delta
	if delta > 0.0:
		g.fed_kw = lerpf(g.fed_kw, g._fed_kj / delta, minf(1.0, delta * HayGenerator.FEED_SMOOTHING))
	g._latch_full()
	t = _lap("generator _latch_full", t)
	g._tick_burn(delta)
	t = _lap("generator _tick_burn", t)
	g._sync_backpressure()
	t = _lap("generator _sync_backpressure", t)
	g._tick_fire(delta)
	t = _lap("generator _tick_fire", t)
	g._tick_steam(delta)
	t = _lap("generator _tick_steam", t)
	g._tick_loop(delta)
	_lap("generator _tick_loop", t)


func _drive_arm(a: RoboticArm, delta: float) -> void:
	if a.placement_preview or a._base_yaw == null:
		return
	var t:= Time.get_ticks_usec()
	if a._phase == RoboticArm.Phase.IDLE:
		a._scan_left -= delta * a.power
		if a._scan_left <= 0.0 and a._take_scan_turn():
			a._scan_left = RoboticArm.SCAN_INTERVAL
			_time_arm_searches(a)
			t = Time.get_ticks_usec()
			a._try_start_cycle()
			t = _lap("arm _try_start_cycle (the real scan)", t)
			_f_stalls [a._stall] = int(_f_stalls.get(a._stall, 0)) + 1
		a._update_payload()
		_lap("arm _update_payload", t)
		return
	a._phase_elapsed += delta * a.power
	var amount:= clampf(a._phase_elapsed / maxf(a._phase_duration, 0.001), 0.0, 1.0)
	var eased:= amount * amount * (3.0 - 2.0 * amount)
	if a._phase == RoboticArm.Phase.CLOSE_CLAWS or a._phase == RoboticArm.Phase.OPEN_CLAWS:
		a._apply_claw(lerpf(a._claw_from, a._claw_to, eased))
	else:
		a._apply_angles(a._lerp_angles(a._pose_from, a._pose_to, eased))
	t = _lap("arm pose", t)
	a._update_payload()
	t = _lap("arm _update_payload", t)
	if amount >= 1.0:
		a._finish_phase()
		_lap("arm _finish_phase", t)


func _time_arm_searches(a: RoboticArm) -> void:
	var sh:= a.global_position + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * a.visual_scale()
	var reach:= a.reach_m() * 0.96
	var lo:= RoboticArm.MIN_REACH * a.visual_scale()
	var t:= Time.get_ticks_usec()
	a.live.nearest_available_needle(sh, reach, lo, a.get_instance_id())
	t = _lap("  scan: nearest_available_needle", t)
	a.live.nearest_available_hay(sh, reach, lo)
	t = _lap("  scan: nearest_available_hay", t)
	a._find_prop_pickup(sh)
	t = _lap("  scan: _find_prop_pickup", t)
	a._find_field_pickup(sh)
	t = _lap("  scan: _find_field_pickup", t)
	a.builds.conveyor_drops(a._shoulder_world(), a.reach_m() * 0.98)
	t = _lap("  scan: conveyor_drops", t)
	var cursor: int = a._next_drop
	a._choose_drop(60)
	a._next_drop = cursor
	_lap("  scan: _choose_drop(60)", t)


func _on_process_frame() -> void:
	_t_proc = Time.get_ticks_usec()
	if _sampling:
		_proc_frames += 1


func _file_the_tree() -> void:
	var prop_ids: Dictionary = { }
	var props: PropManager = world.props
	for item in props.items:
		if is_instance_valid(item):
			prop_ids [item.get_instance_id()] = true
	var built_ids: Dictionary = { }
	var builds: BuildManager = world.builds
	for root in builds.every_placed():
		if is_instance_valid(root):
			built_ids [root.get_instance_id()] = true
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self:
			continue
		for kid: Node in node.get_children():
			stack.append(kid)


		if not (node.is_processing() or node.is_physics_processing()
				or _silenced.has(node)):
			continue
		var key:= _owner_of(node, prop_ids, built_ids)
		if not _groups.has(key):
			_groups [key] = []
		(_groups [key] as Array).append(node)


		if key == "the placed buildings":
			var ck:= "   " + _class_of(node)
			if not _classes.has(ck):
				_classes [ck] = []
			(_classes [ck] as Array).append(node)


func _class_of(node: Node) -> String:
	var name:= _script_name(node)
	if node is BeltPath:
		var p:= node.get_parent()
		if p != null:
			name += " of " + _script_name(p)
	return name


func _script_name(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path != "":
		return script.resource_path.get_file().get_basename()
	return node.get_class()


func _owner_of(node: Node, prop_ids: Dictionary, built_ids: Dictionary) -> String:
	if node == world:
		return "the world itself"
	var a: Node = node
	var top: Node = null
	while a != null:
		if a == player:
			return "the player"
		if a == world.live:
			return "the live strands"
		if a == world.field:
			return "the field"
		if prop_ids.has(a.get_instance_id()):
			return "the props' own ticks"
		if a == world.props:
			return "the prop manager"
		if built_ids.has(a.get_instance_id()):
			return "the placed buildings"
		if a == world.builds:
			return "the build manager"
		if a.get_parent() == world:
			top = a
		if a == world:
			break
		a = a.get_parent()
	if a == null:
		return "the autoloads"
	if top != null:
		_other_names [top.name] = int(_other_names.get(top.name, 0)) + 1
	return "the world's other children"


func _group_order() -> Array [String]:
	return ["the placed buildings", "the live strands", "the player",
		"the props' own ticks", "the prop manager", "the field",
		"the world's other children", "the world itself", "the build manager",
		"the autoloads"]


func _count_the_space() -> void:
	var bodies:= 0
	var awake:= 0
	var areas:= 0
	var monitoring:= 0
	var shapes:= 0
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		var rb:= node as RigidBody3D
		if rb != null:
			bodies += 1
			if not rb.sleeping and not rb.freeze:
				awake += 1
		var ar:= node as Area3D
		if ar != null:
			areas += 1
			if ar.monitoring:
				monitoring += 1
		var cs:= node as CollisionShape3D
		if cs != null and not cs.disabled:
			shapes += 1
	var field: HayField = world.field
	var live: Node = world.live
	var active: Variant = live.get("_active") if live != null else null
	var n_live: int = (active as Array).size() if active is Array else -1
	print("--- what is in the space ---")
	print("  %d rigid bodies (%d awake and unfrozen), %d areas (%d monitoring), %d enabled collision shapes"
		% [bodies, awake, areas, monitoring, shapes])
	print("  %d crust chunks, %d live strands, %d props, %d placed buildings"
		% [field.chunks.size(), n_live, (world.props as PropManager).items.size(),
			(world.builds as BuildManager).every_placed().size()])
	print("--- who is ticking ---")
	for key: String in _group_order():
		var nodes: Array = _groups.get(key, [])
		if nodes.is_empty():
			continue
		var phys:= 0
		for n in nodes:
			if (n as Node).is_physics_processing():
				phys += 1
		var extra:= ""
		if key == "the world's other children":
			var parts: Array [String] = []
			for name: String in _other_names:
				parts.append("%s x%d" % [name, _other_names [name]])
			extra = "  [" + ", ".join(parts) + "]"
		print("  %-28s %4d nodes, %4d of them on the physics clock%s"
			% [key, nodes.size(), phys, extra])


func _silence(nodes: Array) -> void:
	for n in nodes:


		if not is_instance_valid(n):
			continue
		var node:= n as Node
		if node == null:
			continue
		if node.is_processing() or node.is_physics_processing():
			node.set_process(false)
			node.set_physics_process(false)
			_silenced.append(node)


var _all_silenced:= false


func _silence_everything() -> void:
	_all_silenced = true
	for key: String in _groups:
		_silence(_groups [key])


func _areas_off_now() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		var ar:= node as Area3D
		if ar == null or not (ar.monitoring or ar.monitorable):
			continue
		_areas_off.append({ "area": ar, "monitoring": ar.monitoring,
			"monitorable": ar.monitorable })
		ar.monitoring = false
		ar.monitorable = false


func _sleep_the_props() -> void:
	_slept = true
	var props: PropManager = world.props
	for item in props.items:
		var body:= item as RigidBody3D
		if body != null and is_instance_valid(body):
			body.sleeping = true


func _crust_colliders_off() -> void:
	var field: HayField = world.field
	for c in field.chunks:
		if not is_instance_valid(c):
			continue
		var coll: CollisionShape3D = c.get("_coll")
		if coll != null and not coll.disabled:
			coll.disabled = true
			_colls_off.append(coll)


func _reset() -> void:
	_all_silenced = false
	for n in _silenced:
		if is_instance_valid(n):
			n.set_process(true)
			n.set_physics_process(true)
	_silenced.clear()
	for rec in _areas_off:
		var ar: Area3D = rec ["area"]
		if is_instance_valid(ar):
			ar.monitoring = bool(rec ["monitoring"])
			ar.monitorable = bool(rec ["monitorable"])
	_areas_off.clear()
	for c in _colls_off:
		if is_instance_valid(c):
			c.disabled = false
	_colls_off.clear()
	if _slept:


		_slept = false
		var props: PropManager = world.props
		for item in props.items:
			var body:= item as RigidBody3D
			if body != null and is_instance_valid(body) and not body.freeze:
				body.sleeping = false


func _row(label: String, flip: Callable) -> void:
	_reset()
	flip.call()
	for i in SETTLE:
		await get_tree().physics_frame
	if _all_silenced:


		_groups.clear()
		_classes.clear()
		_other_names.clear()
		_file_the_tree()
		_silence_everything()
	_n = 0
	_proc_frames = 0
	_cb = 0
	_step = 0
	_rest = 0
	_total = 0
	_sampling = true
	for i in SAMPLE:
		await get_tree().physics_frame
	_sampling = false
	var n:= maxi(_n, 1)


	var row:= { "label": label, "total": _total / 1000.0 / n, "cb": _cb / 1000.0 / n,
		"step": _step / 1000.0 / n, "rest": _rest / 1000.0 / n, "awake": _awake_props(),
		"ticks": _n, "frames": _proc_frames }
	_rows.append(row)
	print("  %-62s tick %6.2f ms = callbacks %5.2f + step %5.2f + rest %5.2f   awake %4d  (%d ticks, %d frames)"
		% [label, row ["total"], row ["cb"], row ["step"], row ["rest"], row ["awake"],
			row ["ticks"], row ["frames"]])


func _spike_table() -> void:
	print("--- spikes: ticks over %.0f ms, %d ticks a row ---" % [SPIKE_MS, SPIKE_SAMPLE])
	await _spike_row("everything on (baseline)", func() -> void: pass)
	var buildings: Array = _groups.get("the placed buildings", [])
	if not buildings.is_empty():
		var silence_buildings:= func() -> void: _silence(buildings)
		await _spike_row("the placed buildings silenced (%d)" % buildings.size(), silence_buildings)
	var names: Array = _classes.keys()
	var bigger:= func(a: String, b: String) -> bool: return (_classes [a] as Array).size() > (_classes [b] as Array).size()
	names.sort_custom(bigger)
	for ck: String in names:
		var these: Array = _classes [ck]
		var silence_these:= func() -> void: _silence(these)
		await _spike_row("%s silenced (%d)" % [ck, these.size()], silence_these)
	for key: String in _group_order():
		if key == "the placed buildings":
			continue
		var nodes: Array = _groups.get(key, [])
		if nodes.is_empty():
			continue
		var silence_them:= func() -> void: _silence(nodes)
		await _spike_row("%s silenced (%d)" % [key, nodes.size()], silence_them)
	await _spike_row("everything on (baseline, again)", func() -> void: pass)
	print("\n[physfloor] spikes done")


func _spike_row(label: String, flip: Callable) -> void:
	_reset()
	flip.call()
	for s in SETTLE:
		await get_tree().physics_frame
	_tick_total.clear()
	_tick_cb.clear()
	_tick_step.clear()
	_tick_rest.clear()
	_n = 0
	_cb = 0
	_step = 0
	_rest = 0
	_total = 0
	_spike_mode = true
	_sampling = true
	for s in SPIKE_SAMPLE:
		await get_tree().physics_frame
	_sampling = false
	_spike_mode = false

	var long_at:= PackedInt32Array()
	var worst:= -1
	for k in _tick_total.size():
		if _tick_total [k] >= SPIKE_MS:
			long_at.append(k)
		if worst < 0 or _tick_total [k] > _tick_total [worst]:
			worst = k
	var sorted:= _tick_total.duplicate()
	sorted.sort()
	var median: float = sorted [sorted.size() / 2] if sorted.size() > 0 else 0.0
	var gaps:= PackedInt32Array()
	for g in range(1, mini(long_at.size(), 13)):
		gaps.append(long_at [g] - long_at [g - 1])
	var split:= ""
	if worst >= 0:
		split = "worst %5.1f ms (callbacks %.1f, step %.1f, rest %.1f)" % [_tick_total [worst],
			_tick_cb [worst], _tick_step [worst], _tick_rest [worst]]
	print("  %-44s median %5.2f ms  %3d over %.0f ms  %s  gaps %s"
		% [label, median, long_at.size(), SPIKE_MS, split, str(gaps)])


func _awake_props() -> int:
	var awake:= 0
	var props: PropManager = world.props
	for item in props.items:
		var body:= item as RigidBody3D
		if body != null and is_instance_valid(body) and not body.sleeping and not body.freeze:
			awake += 1
	return awake


func _report() -> void:
	if _rows.size() < 2:
		return
	var base: Dictionary = _rows [0]
	var last: Dictionary = { }
	for r in _rows:
		if r ["label"] == "everything on (baseline, again)":
			last = r
	if last.is_empty():
		last = base
	var floor_ms:= (float(base ["total"]) + float(last ["total"])) * 0.5
	var drift: float = absf(float(last ["total"]) - float(base ["total"]))
	print("\nagainst the baseline tick of %.2f ms (callbacks %.2f, step %.2f, rest %.2f):"
		% [floor_ms, (float(base ["cb"]) + float(last ["cb"])) * 0.5,
			(float(base ["step"]) + float(last ["step"])) * 0.5,
			(float(base ["rest"]) + float(last ["rest"])) * 0.5])
	print("  the two baselines are %.2f ms apart. NOTHING smaller than that is a result."
		% drift)
	for r in _rows:
		if r == base or r == last:
			continue
		var dt: float = float(r ["total"]) - floor_ms
		var dc: float = float(r ["cb"]) - (float(base ["cb"]) + float(last ["cb"])) * 0.5
		var ds: float = float(r ["step"]) - (float(base ["step"]) + float(last ["step"])) * 0.5
		var dr: float = float(r ["rest"]) - (float(base ["rest"]) + float(last ["rest"])) * 0.5
		print("  %-62s %+6.2f ms  (callbacks %+5.2f, step %+5.2f, rest %+5.2f)%s"
			% [r ["label"], dt, dc, ds, dr,
				"" if absf(dt) > drift else "   (under the drift)"])
	print("\n[physfloor] done")
