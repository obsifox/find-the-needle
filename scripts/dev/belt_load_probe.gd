class_name DevBeltLoadProbe
extends Node


const COUNTS:= [60, 150, 300]


const PAIRS:= 2
const TICKS:= 600
const SETTLE:= 180
const DT:= 1.0 / 60.0

const RUN_LEN:= 24.0
const SPEED:= 3.2

const PER_RUN:= 36

const LANES:= [10.5, 12.1, 13.7, 15.3]
const DECK_Y:= 0.75
const Z0:= -12.0

var world: Node3D
var player: Player

var _paths: Array [BeltPath] = []

var _z0:= Z0

var _legs:= { }

var _laps:= { }
var _notes:= { }


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(0.0, 0.4, -16.0)
	GameState.add_money(500000.0)
	Cfg.prop_decay = false
	Cfg.belt_decay = false
	if "--isolate" in OS.get_cmdline_user_args():
		await _isolate()
		return
	print("\n[beltload] wads %s, %d ticks a leg, %d pairs, belt %.1f m/s, pile r %.1f"
		% [str(COUNTS), TICKS, PAIRS, SPEED, Cfg.PILE_RADIUS])

	await _settle(SETTLE)
	_legs ["empty"] = await _time(TICKS)

	for pair in PAIRS:
		for n: int in COUNTS:
			await _loose_leg(n)
			await _belt_leg(n)
	_report()
	get_tree().quit(0)


func _loose_leg(n: int) -> void:
	var props: PropManager = world.props
	var made:= 0
	for side in [-1.0, 1.0]:
		for col in 7:
			for row in 30:
				if made >= n:
					break
				var x: float = side * (10.2 + float(col) * 0.85)
				var z:= Z0 + float(row) * 0.8
				props.spawn("hay_wad", Transform3D(Basis(), Vector3(x, 0.35, z)),
					{ "strands": 60 })
				made += 1
	await _settle(SETTLE)
	var asleep:= 0
	for item in props.items:
		if is_instance_valid(item) and item.sleeping:
			asleep += 1
	_note("loose/%d" % n, "%d props, %d asleep" % [props.items.size(), asleep])
	_pool("loose/%d" % n, await _time(TICKS))
	props.clear()
	await _settle(40)


func _belt_leg(n: int) -> void:
	var props: PropManager = world.props
	var runs:= _lay_runs(n)
	_seed_bodies(n)
	await _settle(SETTLE + 60)
	var key:= "belt/%d" % n
	_note(key, "%d runs, %d riding, %d props" % [runs, _riding(), props.items.size()])
	_pool(key, await _time(TICKS))


	for p in _paths:
		p.set_physics_process(false)
	await _settle(20)
	_note(key + "/silent", "%d riding" % _riding())
	_pool(key + "/silent", await _time(TICKS))


	var carry: Array [float] = []
	var records: Array [float] = []
	var catch: Array [float] = []
	var settle: Array [float] = []
	var deck: Array [float] = []
	var whole: Array [float] = []
	var none:= PackedFloat64Array()
	var last:= Time.get_ticks_usec()
	for tick in TICKS:
		await get_tree().physics_frame
		var t0:= Time.get_ticks_usec()
		whole.append(float(t0 - last))
		for p in _paths:
			p._carry(DT)
		var t1:= Time.get_ticks_usec()
		for p in _paths:
			p.run.set_blockers(none)
			p.run.tick(DT)
		for p in _paths:
			p.run.flush()
		var t2:= Time.get_ticks_usec()
		for p in _paths:
			p._catch()
		var t3:= Time.get_ticks_usec()
		for p in _paths:
			p._settle_loose()
		var t4:= Time.get_ticks_usec()
		for p in _paths:
			p._update_deck(DT)
		var t5:= Time.get_ticks_usec()
		carry.append(float(t1 - t0))
		records.append(float(t2 - t1))
		catch.append(float(t3 - t2))
		settle.append(float(t4 - t3))
		deck.append(float(t5 - t4))
		last = t0
	_pool(key + "/lapped", whole)
	_lap(key, "carry", carry)
	_lap(key, "run", records)
	_lap(key, "catch", catch)
	_lap(key, "settle_loose", settle)
	_lap(key, "update_deck", deck)
	_note(key + "/lapped", "%d riding" % _riding())

	await _tear_down()


func _lay_runs(n: int) -> int:
	var runs:= int(ceil(float(n) / float(_per_run)))
	_paths.clear()
	for k in runs:
		var side:= -1.0 if k % 2 == 0 else 1.0
		var x: float = side * float(LANES [(k / 2) % LANES.size()])
		var tier:= k / (LANES.size() * 2)
		var head:= Vector3(x, DECK_Y + 1.8 * float(tier), _z0)
		var c: Conveyor = world.builds.add_conveyor(head, head + Vector3(0.0, 0.0, RUN_LEN))
		if c == null:
			print("[beltload] could not lay run %d at x %.1f" % [k, x])
			get_tree().quit(1)
			return runs
		c.set_drive_speed(SPEED)
		c.handed_on.connect(_on_off_end.bind(head))
		_paths.append(c)
	return runs


func _seed_bodies(n: int) -> void:
	var props: PropManager = world.props
	var made:= 0
	for c in _paths:
		var head: Vector3 = c.a
		var here:= mini(_per_run, n - made)
		for j in here:
			var at:= head + Vector3(0.0, 0.3, 0.3 + float(j) * (RUN_LEN - 0.6) / float(_per_run))
			props.spawn("hay_wad", Transform3D(Basis(), at), { "strands": 60 })
			made += 1


func _seed_records(n: int) -> int:
	var made:= 0
	for c in _paths:
		var here:= mini(_per_run, n - made)
		for j in range(here - 1, -1, -1):
			var s:= 0.3 + float(j) * (RUN_LEN - 0.6) / float(_per_run)
			var state: Variant = { "strands": Cfg.WAD_BASE_STRANDS } if _kind == BeltRun.Kind.WAD else null
			if c.run.board(_kind, Cfg.WAD_BASE_STRANDS, -1, _wad_reach, 0.0,
					_wad_lift, s, SPEED, state):
				made += 1
	return made


func _on_off_end(b: RigidBody3D, head: Vector3) -> void:
	if not is_instance_valid(b) or BeltPath.is_rider(b):
		return
	b.global_transform = Transform3D(Basis(), head + Vector3(0.0, 0.3, 0.3))
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO


func _riding() -> int:
	var t:= 0
	for p in _paths:
		if is_instance_valid(p):
			t += p.riders().size() + p.run.count()
	return t


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _time(ticks: int) -> Array [float]:
	var us: Array [float] = []
	var last:= Time.get_ticks_usec()
	for i in ticks:
		await get_tree().physics_frame
		var now:= Time.get_ticks_usec()
		us.append(float(now - last))
		last = now
	return us


func _lap(key: String, part: String, v: Array [float]) -> void:
	var k:= key + ":" + part
	var have: Array [float] = []
	have.assign(_laps.get(k, []))
	have.append_array(v)
	_laps [k] = have


func _note(key: String, text: String) -> void:
	_notes [key] = text


func _report() -> void:
	var empty:= _mean(_legs ["empty"])
	print("\n=== ms per tick (physics step plus process), empty yard %.2f ms ===" % (empty / 1000.0))
	print("  wads   loose   riding   riding,scripts off   riding,lapped  | per wad over empty: loose  riding")
	for n: int in COUNTS:
		var lo:= _mean(_legs ["loose/%d" % n])
		var be:= _mean(_legs ["belt/%d" % n])
		var si:= _mean(_legs ["belt/%d/silent" % n])
		var la:= _mean(_legs ["belt/%d/lapped" % n])
		print("  %4d  %6.2f  %7.2f  %19.2f  %14.2f  | %24.1f us %6.1f us"
			% [n, lo / 1000.0, be / 1000.0, si / 1000.0, la / 1000.0,
				(lo - empty) / float(n), (be - empty) / float(n)])
	print("\n=== the belt tick, lapped (ms per tick, all runs together) ===")
	for n: int in COUNTS:
		var key:= "belt/%d" % n
		var parts:= ""
		for part in ["carry", "run", "catch", "settle_loose", "update_deck"]:
			parts += "  %s %.2f" % [part, _mean(_laps [key + ":" + part]) / 1000.0]
		print("  %4d wads:%s   99th tick %.2f ms" % [n, parts, _pct(_legs [key], 0.99) / 1000.0])
	print("\n=== notes ===")
	var keys:= _notes.keys()
	keys.sort()
	for k in keys:
		print("  %-20s %s" % [k, _notes [k]])


static func _mean(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var t:= 0.0
	for x in v:
		t += float(x)
	return t / float(v.size())


static func _pct(v: Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var s:= v.duplicate()
	s.sort()
	return float(s [clampi(int(round(p * (s.size() - 1))), 0, s.size() - 1)])


const ISO_COUNTS:= [3000, 5000]
const ISO_PAIRS:= 2
const ISO_ROWS:= ["records", "runs_only"]
const GATE_MS:= { 3000: 2.0, 5000: 3.0 }

var _cols:= { }
var _pending_cols:= { }
var _cam: Camera3D


var _hand_tick:= false


var _wad_reach:= 0.22
var _wad_lift:= 0.2
var _gate_ok:= true


const KIND_NAMES:= { "wad": BeltRun.Kind.WAD, "bale": BeltRun.Kind.BALE,
	"foiled": BeltRun.Kind.FOILED_BALE, "brick": BeltRun.Kind.BRICK,
	"pulp": BeltRun.Kind.PULP, "roll": BeltRun.Kind.ROLL, "disc": BeltRun.Kind.DISC }
var _kind: int = BeltRun.Kind.WAD
var _kind_label:= "wad"
var _per_run:= PER_RUN


func _physics_process(_delta: float) -> void:
	if not _hand_tick:
		return
	var none:= PackedFloat64Array()
	for p in _paths:
		if is_instance_valid(p):
			p.run.set_blockers(none)
			p.run.tick(DT)
	for p in _paths:
		if is_instance_valid(p):
			p.run.flush()


func _isolate() -> void:
	var windowed:= DisplayServer.get_name() != "headless"


	world.stand.set_physics_process(false)
	var ticks:= _option_int("--ticks", TICKS)
	var pairs:= _option_int("--pairs", ISO_PAIRS)
	if windowed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(
			get_viewport().get_viewport_rid(), true)
		_hide_hud()
		_cam = Camera3D.new()
		_cam.far = 2000.0
		world.add_child(_cam)


		_cam.global_position = Vector3(12.9, 4.5, -9.0)
		_cam.look_at(Vector3(12.9, 1.0, 10.0))
		_cam.current = true


	var far:= "--far" in OS.get_cmdline_user_args()
	if far:
		_z0 = Z0 + 100.0
	_measure_wad()
	print("\n[beltload --isolate] wads %s, %d ticks a row, %d pairs, belt %.1f m/s, %s%s, wad reach %.3f lift %.3f"
		% [str(_iso_counts()), ticks, pairs, SPEED, "windowed" if windowed else "headless",
			", player 100 m off" if far else "", _wad_reach, _wad_lift])
	await _settle(SETTLE)
	_pool("empty", await _sample(ticks, windowed))
	if not "--skip-integrate" in OS.get_cmdline_user_args():
		await _integrate_check()
	for kind_label: String in _iso_kinds():
		_kind_label = kind_label
		_kind = KIND_NAMES.get(kind_label, BeltRun.Kind.WAD)
		_measure_wad()
		print("[beltload] kind %s: reach %.3f lift %.3f, %d a run" % [kind_label, _wad_reach, _wad_lift, _per_run])
		await _isolate_kind(ticks, pairs, windowed)
	_report_iso(windowed)
	get_tree().quit(0 if _gate_ok else 1)


func _isolate_kind(ticks: int, pairs: int, windowed: bool) -> void:
	for pair in pairs:
		for n: int in _iso_counts():
			var runs:= _lay_runs(n)
			await _settle(60)
			_pool("%s%d/empty_runs" % [_kind_prefix(), n], await _sample(ticks, windowed))
			var boarded:= _seed_records(n)


			for p in _paths:
				p.downstream = p
			await _settle(SETTLE)
			if boarded != n or _riding() != n:
				for p in _paths:
					print("[beltload] path %s length %.2f aboard %d" % [p._mid, p.path_length(), p.run.count()])
				push_error("beltload: expected %d records, boarded %d, aboard %d" % [n, boarded, _riding()])
				get_tree().quit(1)
				return
			var strides:= { }
			for p in _paths:
				var k:= p._tick_stride()
				strides [k] = int(strides.get(k, 0)) + 1
			_note("%s%d" % [_kind_prefix(), n], "%d runs, %d records, tick strides %s, focus %s %s, mid %s" % [runs,
				_riding(), str(strides), str(BeltPath.focus_set), str(BeltPath.focus),
				str(_paths [0]._mid)])
			for row: String in _iso_rows():
				_apply_row(row, true)
				await _settle(30)
				var key:= "%s%d/%s" % [_kind_prefix(), n, row]
				var before:= _riding()
				var handed:= _handed()
				_pool(key, await _sample(ticks, windowed))
				print("[beltload] pair %d %s %.2f ms, %d aboard, %d hand overs in %d ticks" % [pair + 1, key,
					_mean(_legs [key]) / 1000.0, _riding(), _handed() - handed, ticks])
				if windowed and row == "records" and pair == 0:
					get_viewport().get_texture().get_image().save_png(
						"user://beltload_%s%d.png" % [_kind_prefix().replace(" ", "_"), n])
				_note(key, "aboard %d -> %d" % [before, _riding()])
				_apply_row(row, false)
				await _settle(10)
			await _tear_down()


func _measure_wad() -> void:
	var props: PropManager = world.props
	var body:= props.spawn(BeltRun.ITEM_IDS [_kind], Transform3D(Basis(), Vector3(0.0, 30.0, 0.0)),
		{ "strands": Cfg.WAD_BASE_STRANDS })
	if body == null:
		return
	var shape:= BeltPath.load_shape(body)
	_wad_reach = float(shape ["reach"])
	_wad_lift = float(shape ["rest"])
	props.remove(body)


	var pitch:= maxf(maxf(_wad_reach * 2.0, Cfg.BELT_RIDE_SPACING), Cfg.STRAND_THICK * 2.0) + 0.02
	_per_run = mini(PER_RUN, int(floor((RUN_LEN - 0.6) / pitch)))


func _kind_prefix() -> String:
	return "" if _iso_kinds() == ["wad"] else _kind_label + " "


func _iso_kinds() -> Array:
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--kinds")
	if i < 0 or i + 1 >= ua.size():
		return ["wad"]
	return Array(ua [i + 1].split(","))


func _handed() -> int:
	var t:= 0
	for p in _paths:
		if is_instance_valid(p):
			t += p.run.handed
	return t


func _apply_row(row: String, on: bool) -> void:


	if row.begins_with("lod") or row == "no_shadow":
		_apply_draw_row(row, on)
		return
	if row != "runs_only":
		return
	for p in _paths:
		if is_instance_valid(p):
			p.set_physics_process(not on)
	_hand_tick = on


var _saved_cuts:= PackedFloat32Array()


func _apply_draw_row(row: String, on: bool) -> void:
	var batch:= BeltRunBatch.instance
	if batch == null:
		return
	if row == "no_shadow":
		for rd in batch._runs:
			for b in rd.bins.values():
				if is_instance_valid(b.node):
					b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
	var kd = batch._kind_draw(_kind)
	if on:
		_saved_cuts = kd.cuts.duplicate()
		var want:= int(row.substr(3))
		var cuts:= PackedFloat32Array()
		for i in kd.cuts.size():


			cuts.append(0.0001 if i < want else (1000000000.0 if i == want else 0.0))
		kd.cuts = cuts
	else:
		kd.cuts = _saved_cuts

	var cam:= get_viewport().get_camera_3d()
	if cam != null:
		for rd in batch._runs:
			batch._pick_lod(rd, cam.global_position)


func _tear_down() -> void:
	_hand_tick = false
	for p in _paths:
		if is_instance_valid(p):
			p.handed_on.disconnect(_on_off_end)


			p.run.clear()
	for c in world.builds.conveyors.duplicate():
		if is_instance_valid(c):
			world.builds.demolish(c)
	world.props.clear()
	_paths.clear()
	await _settle(40)


func _sample(ticks: int, windowed: bool) -> Array [float]:
	if not windowed:
		return await _time(ticks)
	var rid:= get_viewport().get_viewport_rid()
	var wall: Array [float] = []
	var cols:= { "proc": [], "phys": [], "rcpu": [], "gpu": [], "draws": [], "prims": [] }
	var last:= Time.get_ticks_usec()
	for i in ticks:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		wall.append(float(now - last))
		last = now
		cols ["proc"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		cols ["phys"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		cols ["rcpu"].append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		cols ["gpu"].append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cols ["draws"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cols ["prims"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_pending_cols = cols
	return wall


func _pool(key: String, v: Array [float]) -> void:
	var have: Array [float] = []
	have.assign(_legs.get(key, []))
	have.append_array(v)
	_legs [key] = have
	if _pending_cols.is_empty():
		return
	var mine: Dictionary = _cols.get(key, { })
	for c: String in _pending_cols:
		var arr: Array = mine.get(c, [])
		arr.append_array(_pending_cols [c])
		mine [c] = arr
	_cols [key] = mine
	_pending_cols = { }


func _integrate_check() -> void:
	var moved:= IntegrateProbe.new()
	var still:= IntegrateProbe.new()
	var loose:= IntegrateProbe.new()
	for b: IntegrateProbe in [moved, still, loose]:
		var cs:= CollisionShape3D.new()
		var box:= BoxShape3D.new()
		box.size = Vector3(0.2, 0.2, 0.2)
		cs.shape = box
		b.add_child(cs)
		b.collision_layer = Cfg.L_PROP
		b.collision_mask = 0
		world.add_child(b)
	moved.global_position = Vector3(0.0, 30.0, 0.0)
	still.global_position = Vector3(5.0, 30.0, 0.0)
	loose.global_position = Vector3(10.0, 30.0, 0.0)
	for b: IntegrateProbe in [moved, still]:
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		b.freeze = true
	loose.gravity_scale = 0.0
	await _settle(30)
	loose.sleeping = true
	moved.calls = 0
	still.calls = 0
	loose.calls = 0
	for i in 60:
		await get_tree().physics_frame
		moved.global_position += Vector3(0.001, 0.0, 0.0)
	print("\n=== _integrate_forces calls in 60 steps ===")
	print("  frozen kinematic, moved each step   %d" % moved.calls)
	print("  frozen kinematic, never moved       %d" % still.calls)
	print("  loose body, asleep                  %d" % loose.calls)
	for b: IntegrateProbe in [moved, still, loose]:
		b.queue_free()
	await _settle(5)
	await _integrate_bench()


func _integrate_bench() -> void:
	const N:= 500
	const STEPS:= 300
	var cost:= { "scripted": [], "plain": [] }
	for pair in 2:
		for kind: String in ["scripted", "plain"]:
			var bodies: Array [RigidBody3D] = []
			for i in N:
				var b: RigidBody3D = IntegrateProbe.new() if kind == "scripted" else RigidBody3D.new()
				var cs:= CollisionShape3D.new()
				var box:= BoxShape3D.new()
				box.size = Vector3(0.2, 0.2, 0.2)
				cs.shape = box
				b.add_child(cs)
				b.collision_layer = Cfg.L_PROP
				b.collision_mask = 0
				world.add_child(b)
				b.global_position = Vector3(float(i % 25) * 0.5 - 6.0, 30.0, float(i / 25) * 0.5)
				b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				b.freeze = true
				bodies.append(b)
			await _settle(30)
			var us: Array [float] = []
			var last:= Time.get_ticks_usec()
			for step in STEPS:
				await get_tree().physics_frame
				var now:= Time.get_ticks_usec()
				us.append(float(now - last))
				last = now
				for b in bodies:
					b.global_position += Vector3(0.001, 0.0, 0.0)
			cost [kind].append_array(us)
			for b in bodies:
				b.queue_free()
			await _settle(10)
	var scripted:= _mean(cost ["scripted"])
	var plain:= _mean(cost ["plain"])
	print("\n=== %d frozen kinematic bodies moved a step, ms per tick ===" % N)
	print("  with _integrate_forces overridden   %5.2f" % (scripted / 1000.0))
	print("  plain RigidBody3D                   %5.2f" % (plain / 1000.0))
	print("  the override, per body per tick     %5.2f us" % ((scripted - plain) / float(N)))


class IntegrateProbe extends RigidBody3D:
	var calls:= 0

	func _integrate_forces(_state: PhysicsDirectBodyState3D) -> void:
		calls += 1


func _hide_hud() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		for kid: Node in node.get_children():
			stack.append(kid)


func _report_iso(windowed: bool) -> void:
	var empty:= _mean(_legs ["empty"])
	print("\n=== ms per %s, empty yard %.2f ms ===" % [
		"process frame (windowed, vsync off)" if windowed else "physics tick (headless)", empty / 1000.0])
	if windowed:
		print("  %-16s %7s %7s | %6s %6s %6s %6s %6s %8s" % ["row", "mean", "99th",
			"proc", "phys", "rCPU", "GPU", "draws", "tris"])
	else:
		print("  %-16s %7s %7s %10s %12s" % ["row", "mean", "99th", "over empty", "per record"])
	for kind_label: String in _iso_kinds():
		_kind_label = kind_label
		for n: int in _iso_counts():
			_report_count(n, windowed, empty)
	if not windowed:
		for n: int in _iso_counts():
			var key:= "%s%d/records" % [_kind_prefix(), n]
			if _kind_prefix() != "":
				continue
			if not _legs.has(key) or not GATE_MS.has(n):
				continue
			var over:= (_mean(_legs [key]) - empty) / 1000.0
			var limit: float = GATE_MS [n]
			var ok:= over < limit
			_gate_ok = _gate_ok and ok
			print("  %s GATE records: %d moving on %d runs, %.2f ms a tick over the empty yard, limit %.1f"
				% ["ok  " if ok else "FAIL", n, int(ceil(float(n) / float(PER_RUN))), over, limit])
	print("\n=== notes ===")
	var keys:= _notes.keys()
	keys.sort()
	for k in keys:
		print("  %-16s %s" % [k, _notes [k]])


func _report_count(n: int, windowed: bool, empty: float) -> void:
	for row: String in ["empty_runs"] + _iso_rows():
		var key:= "%s%d/%s" % [_kind_prefix(), n, row]
		if not _legs.has(key):
			continue
		var m:= _mean(_legs [key])
		var p99:= _pct(_legs [key], 0.99)
		if windowed:
			var c: Dictionary = _cols.get(key, { })
			print("  %-16s %7.2f %7.2f | %6.2f %6.2f %6.2f %6.2f %6.0f %7.0fk" % [key,
				m / 1000.0, p99 / 1000.0, _mean(c.get("proc", [])), _mean(c.get("phys", [])),
				_mean(c.get("rcpu", [])), _mean(c.get("gpu", [])), _mean(c.get("draws", [])),
				_mean(c.get("prims", [])) / 1000.0])
		else:
			print("  %-16s %7.2f %7.2f %+9.2f %9.2f us" % [key, m / 1000.0, p99 / 1000.0,
				(m - empty) / 1000.0, (m - empty) / float(n)])
	print("")


func _iso_counts() -> Array:
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--counts")
	if i < 0 or i + 1 >= ua.size():
		return ISO_COUNTS
	var out:= []
	for part in ua [i + 1].split(","):
		out.append(int(part))
	return out


func _option_int(flag: String, fallback: int) -> int:
	var args:= OS.get_cmdline_user_args()
	var at:= args.find(flag)
	return maxi(1, int(args [at + 1])) if at >= 0 and at + 1 < args.size() else fallback


func _iso_rows() -> Array:
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--rows")
	return Array(args [at + 1].split(",")) if at >= 0 and at + 1 < args.size() else ISO_ROWS
