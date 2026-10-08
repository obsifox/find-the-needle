class_name DevBeltFuzzProbe
extends Node


var world: Node3D
var player: Player

const RUNS:= 6
const DT:= 1.0 / 60.0
const REACH:= 0.146


const SLACK:= 0.02

var _rng:= RandomNumberGenerator.new()
var _runs: Array [BeltRun] = []
var _batch: BeltRunBatch
var _frames:= 0
var _frames_wanted:= 12000
var _ticks:= 0
var _ticks_this_frame:= 1
var _fell:= 0
var _ops:= 0
var _op_log: Array [String] = []

var _relay_later: Array = []
var _ev_log:= { }
var _failed:= false
var _checked:= 0
var _worst:= 0.0


var _cull:= false
var _lagged:= 0


var _tick_hist:= PackedInt32Array()
var _kinds:= { }


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	world.block_save = true
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--beltfuzz")
	var seed:= 1
	if i >= 0 and i + 1 < ua.size() and ua [i + 1].is_valid_int():
		seed = int(ua [i + 1])
	if i >= 0 and i + 2 < ua.size() and ua [i + 2].is_valid_int():
		_frames_wanted = int(ua [i + 2])
	_cull = i >= 0 and i + 3 < ua.size() and ua [i + 3] == "cull"
	_rng.seed = seed
	BeltRunBatch.draw_headless = true
	_batch = BeltRunBatch.new()
	_batch.name = "FuzzBatch"
	world.add_child(_batch)
	_build_runs()
	if _cull:
		BeltRunBatch.cull = true
		var cam:= Camera3D.new()
		cam.name = "FuzzEye"
		world.add_child(cam)
		cam.global_position = Vector3(0.0, 2.0, 0.0)
		cam.look_at(Vector3(0.0, 2.0, 10.0))
		cam.make_current()


	process_priority = 200
	get_tree().process_frame.connect(_on_frame_start)
	print("BELTFUZZ: seed %d, %d frames, %d runs, debug_on %s, audit_always %s" % [
		seed, _frames_wanted, _runs.size(), str(Cfg.debug_on()), str(BeltRunBatch.audit_always)])


func _build_runs() -> void:
	for k in RUNS:
		var r:= BeltRun.new()
		var origin:= Vector3(_rng.randf_range(-20.0, 20.0), 0.43, _rng.randf_range(-20.0, 20.0))
		var yaw:= _rng.randf_range(0.0, TAU)
		var dir:= Vector3(sin(yaw), 0.0, cos(yaw))
		var length:= _rng.randf_range(1.2, 4.0)
		var pts:= PackedVector3Array([origin, origin + dir * length])
		if k == 2:

			var turn:= Vector3(cos(yaw), 0.0, - sin(yaw))
			pts = PackedVector3Array([origin, origin + dir * length * 0.6,
				origin + dir * length * 0.6 + turn * length * 0.4])
		r.set_line(pts)
		r.speed = 3.22
		r.pickup = Cfg.BELT_RIDE_PICKUP
		r.spacing = Cfg.BELT_RIDE_SPACING
		r.fell_off.connect(_on_fell)
		_runs.append(r)
	for k in RUNS - 1:
		_runs [k].link(_runs [k + 1])
	_runs [RUNS - 1].end_held = true

	_runs [3].wye = true
	for r in _runs:
		BeltRunBatch.watch(r)


func _on_fell(_rec: Dictionary) -> void:
	_fell += 1


func _log(what: String) -> void:
	_ops += 1
	_op_log.append("t%d %s" % [_ticks, what])
	if _op_log.size() > 60:
		_op_log.remove_at(0)


func _physics_process(_delta: float) -> void:
	if _failed:
		return
	var ticks:= 1
	var roll:= _rng.randf()
	if roll < 0.15:
		ticks = 3
	elif roll < 0.45:
		ticks = 2
	_ticks_this_frame = ticks
	_tick_hist.append(ticks)
	if _tick_hist.size() > 4:
		_tick_hist.remove_at(0)
	for _t in ticks:
		_ticks += 1
		for r in _runs:
			if r.count() > 0:
				r.tick(DT)
		for r in _runs:
			r.flush()
		_random_ops()


func _pick_run() -> int:
	return _rng.randi_range(0, RUNS - 1)


func _pick_row(r: BeltRun) -> int:
	if r.count() == 0:
		return -1
	return r.first() + _rng.randi_range(0, r.count() - 1)


func _random_ops() -> void:

	if _rng.randf() < 0.35:
		var r:= _runs [0]
		var spd:= [0.0, 3.22, 1.5, 3.22] [_rng.randi_range(0, 3)] as float
		var side:= _rng.randf_range(-0.03, 0.03)
		var strands:= 197 if _rng.randf() < 0.9 else 40
		var reach:= REACH if strands == 197 else 0.086
		if r.board(BeltRun.Kind.WAD, strands, 0, reach, side, 0.0, 0.0, spd):
			_log("board r0 seq %d spd %.2f" % [r.last_seq, spd])

	if _rng.randf() < 0.04:
		var k:= _pick_run()
		var r:= _runs [k]
		var s:= _rng.randf_range(0.0, r.length())
		if r.board(BeltRun.Kind.WAD, 197, 0, REACH, 0.0, 0.0, s, 0.0):
			_log("board r%d seq %d at s %.2f" % [k, r.last_seq, s])

	if _rng.randf() < 0.25:
		var r:= _runs [RUNS - 1]
		if r.has_head():
			var rec:= r.take_head()
			_log("take_head r%d seq %d" % [RUNS - 1, int(rec ["seq"])])

	if _rng.randf() < 0.03:
		var k:= _pick_run()
		var r:= _runs [k]
		var lo:= _rng.randf_range(0.0, r.length())
		var rec:= r.take_within(Callable(), lo, lo + 0.4)
		if not rec.is_empty():
			_log("take_within r%d seq %d s %.2f" % [k, int(rec ["seq"]), float(rec ["s"])])

	if _rng.randf() < 0.05:
		var k:= _pick_run()
		var r:= _runs [k]
		var row:= _pick_row(r)
		if row >= 0:
			var rec:= r.remove_at(row)
			_log("remove_at r%d row %d seq %d s %.2f group %d" % [k, row, int(rec ["seq"]),
				float(rec ["s"]), int(rec.get("group", -1))])


			var roll:= _rng.randf()
			if roll < 0.3:
				if r.board_record(rec, float(rec ["s"]), float(rec ["speed"]), false):
					_log("put back r%d seq %d s %.2f" % [k, int(rec ["seq"]), float(rec ["s"])])
			elif roll < 0.5:
				var j:= _pick_run()
				var s:= _rng.randf_range(0.0, _runs [j].length())
				if _runs [j].board_record(rec, s, float(rec ["speed"]), false):
					_log("pass r%d seq %d to r%d s %.2f" % [k, int(rec ["seq"]), j, s])

	if _rng.randf() < 0.02:
		var k:= _pick_run()
		var r:= _runs [k]
		var s:= _rng.randf_range(0.2, r.length()) if _rng.randf() < 0.6 else -1.0
		r.hold_before(s)
		_log("hold_before r%d %.2f" % [k, s])

	if _rng.randf() < 0.04:
		var k:= _pick_run()
		var r:= _runs [k]
		var triples:= PackedFloat64Array()
		var nb:= _rng.randi_range(0, 2)
		for _b in nb:
			triples.append(_rng.randf_range(0.0, r.length()))
			triples.append(0.15)
			triples.append(0.0)
		r.set_blockers(triples)
		_log("blockers r%d %d" % [k, nb])

	if _rng.randf() < 0.02:
		var k:= _pick_run()
		var r:= _runs [k]
		r.set_outlet_held(not r.outlet_held)
		_log("outlet_held r%d %s" % [k, str(r.outlet_held)])
	if _rng.randf() < 0.01:
		var r:= _runs [RUNS - 1]
		r.set_end_held(not r.end_held)
		_log("end_held r%d %s" % [RUNS - 1, str(r.end_held)])
	if _rng.randf() < 0.01:
		var k:= _pick_run()
		var r:= _runs [k]
		r.set_catching(not r.catching)
		_log("catching r%d %s" % [k, str(r.catching)])
	if _rng.randf() < 0.01:
		var k:= _pick_run()
		var r:= _runs [k]
		r.set_blocked(not r.blocked)
		_log("blocked r%d %s" % [k, str(r.blocked)])
	if _rng.randf() < 0.005:
		var k:= _pick_run()
		var v:= [0.7, 1.5, 3.22] [_rng.randi_range(0, 2)] as float
		_runs [k].set_speed(v)
		_log("speed r%d %.2f" % [k, v])


	if _rng.randf() < 0.004:
		var k:= _pick_run()
		var r:= _runs [k]
		var spilled: Array = []
		while r.count() > 0:
			var i:= r.first() + r.count() - 1
			spilled.append(r.remove_at(i))
		BeltRunBatch.unwatch(r)
		r.set_line(r.line())
		BeltRunBatch.watch(r)
		var back:= 0
		for rec in spilled:
			if _rng.randf() < 0.7:
				if r.board_record(rec, clampf(float(rec ["s"]), 0.0, r.length()), 0.0, false):
					back += 1
			else:
				_relay_later.append([r, rec, _ticks + _rng.randi_range(1, 30)])
		_log("relay r%d spilled %d, %d straight back, %d later" % [k, spilled.size(), back,
			spilled.size() - back])
	for j in range(_relay_later.size() - 1, -1, -1):
		var item: Array = _relay_later [j]
		if _ticks >= int(item [2]):
			_relay_later.remove_at(j)
			var r: BeltRun = item [0]
			var rec: Dictionary = item [1]
			if r.board_record(rec, clampf(float(rec ["s"]), 0.0, r.length()), 0.0, false):
				_log("caught back r%d seq %d s %.2f" % [_runs.find(r), int(rec ["seq"]), float(rec ["s"])])


func _on_frame_start() -> void:
	if _failed:
		return
	for ev: Array in _batch._events:
		var r: BeltRun = ev [0]
		var h: Array = _ev_log.get(r, [])
		var what: String
		match int(ev [1]):
			BeltRun.Ev.BOARD:
				var rec: Dictionary = ev [2]
				what = "BOARD seq %d group %d rel %.3f s %.3f" % [int(rec ["seq"]),
					int(rec ["group"]), float(rec ["rel"]), float(rec.get("s", 0.0))]
			BeltRun.Ev.MOVE:
				what = "MOVE seq %d to group %d rel %.3f" % [int(ev [2]), int(ev [3]), float(ev [4])]
			BeltRun.Ev.LEAVE:
				what = "LEAVE seq %d" % int(ev [2])
			_:
				what = "REBASE group %d" % int(ev [2])
		h.append("t%d %s" % [_ticks, what])
		if h.size() > 80:
			h.remove_at(0)
		_ev_log [r] = h


func _process(_delta: float) -> void:
	_check()


func _check() -> void:
	if _failed:
		return
	_frames += 1
	for rd in _batch._runs:
		var r: BeltRun = rd.run
		var k:= _runs.find(r)
		var why: String = _batch._audit(rd)
		if why != "":
			_fail(k, rd, "self check: " + why)
			return
		var f:= r.first()
		for row in range(f, f + r.count()):
			var seq:= r.seq_of(row)
			var d: Array = _batch.debug_drawn(r, seq)
			var drawn:= float(d [0])
			var truth:= r.s_of(row)
			if drawn == - INF and _cull:


				_lagged += 1
				continue
			if drawn == - INF:
				_fail(k, rd, "seq %d row %d never written (group %d)" % [seq, row, int(d [1])])
				return
			var err:= absf(drawn - truth)
			_checked += 1
			_worst = maxf(_worst, err)


			var allow:= r.speed * DT * _ticks_this_frame + SLACK
			if _cull:
				if err > allow:
					_lagged += 1
				var behind:= 0
				for t in _tick_hist:
					behind += t
				allow = r.speed * DT * maxi(behind, 1) + SLACK
			if err > allow:
				_fail(k, rd, "seq %d row %d drawn at %.3f, run has it at %.3f (off by %.3f, group %d run group %d, rel %.3f run rel %.3f)"
					% [seq, row, drawn, truth, err, int(d [1]), r.row_group(row),
						(rd.slots [seq] as BeltRunBatch.Slot).rel, r.rel_of(row)])
				return
	if _frames >= _frames_wanted:
		if _cull and _lagged == 0:
			print("BELTFUZZ: FAIL, culling asked for and nothing was ever drawn late")
			get_tree().quit(1)
			return
		print("BELTFUZZ: PASS, %d frames, %d ops, %d records checked, worst %.3f m off, %d fell off the end, %d self check reports%s"
			% [_frames, _ops, _checked, _worst, _fell, _batch.reports,
				(", %d checks drawn late by the cull" % _lagged) if _cull else ""])
		get_tree().quit(0)


func _fail(k: int, rd: BeltRunBatch.RunDraw, why: String) -> void:
	_failed = true
	var r: BeltRun = rd.run
	var g:= r.groups()
	print("BELTFUZZ: FAIL at frame %d tick %d on r%d (len %.2f straight %s): %s" % [
		_frames, _ticks, k, r.length(), str(rd.straight), why])
	print("  run jam %d free %d back %d, jam_offset %.3f drawn_jam %.3f, free_offset %.3f drawn_free %.3f, awake %s dirty %s, hold %.2f"
		% [g.x, g.y, g.z, r.jam_offset(), rd.drawn_jam, r.free_offset(), rd.drawn_free,
			str(r.awake), str(rd.dirty), r.hold_line()])
	var f:= r.first()
	for row in range(f, f + r.count()):
		var seq:= r.seq_of(row)
		var d: Array = _batch.debug_drawn(r, seq)
		var sl: BeltRunBatch.Slot = rd.slots.get(seq)
		print("  row %d seq %d s %.3f group %d rel %.3f | drawn %.3f group %d rel %s" % [
			row, seq, r.s_of(row), r.row_group(row), r.rel_of(row), float(d [0]), int(d [1]),
			("%.3f" % sl.rel) if sl != null else "none"])
	print("  events on r%d:" % k)
	for line: String in _ev_log.get(r, []):
		print("    " + line)
	print("  last ops:")
	for line in _op_log:
		print("    " + line)
	get_tree().quit(1)
