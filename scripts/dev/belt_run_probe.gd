class_name DevBeltRunProbe
extends Node


const DT:= 1.0 / 60.0


const WAD_REACH:= 0.22
const STRAND_REACH:= Cfg.STRAND_THICK
const FAST:= 3.2
const RUNS:= 100
const LOAD:= 5000
const GATE_MOVING_US:= 1000.0
const GATE_JAM_US:= 100.0
const GATE_BATCH_US:= 1000.0

const DRAW_ROWS:= 60
const DRAW_LENGTH:= 30.0
const DRAW_PITCH:= 1.0
const DRAW_LOAD:= 3000

const DRAW_AT:= Vector3(-15.0, 24.0, -30.0)

var world: Node3D
var player: Player
var _fails:= 0
var _rng:= RandomNumberGenerator.new()

var _arrivals:= 0
var _room_events:= 0
var _fell:= 0
var _fell_ticks: PackedInt32Array = PackedInt32Array()
var _tick_no:= 0

var _draw_runs: Array [BeltRun] = []
var _draw_tick_us:= PackedFloat64Array()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_rng.seed = 20260917
	print("\n[beltrun] BeltRun on its own, %d Hz ticks by hand" % int(round(1.0 / DT)))
	_kinematics()
	_queue()
	_take()
	_mouth()
	_throughput()
	_hold()
	_mid_board()
	_remove()
	_conservation()
	_timing()
	await _drawing()
	print("\n[beltrun] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _physics_process(delta: float) -> void:
	if _draw_runs.is_empty():
		return
	var t0:= Time.get_ticks_usec()
	for r in _draw_runs:
		if r.awake:
			r.tick(delta)
	for r in _draw_runs:
		if r.awake:
			r.flush()
	_draw_tick_us.append(float(Time.get_ticks_usec() - t0))


func _chain(n: int, length: float, spd: float, ring: bool) -> Array [BeltRun]:
	var runs: Array [BeltRun] = []
	for i in n:
		var r:= BeltRun.new()
		r.set_line(PackedVector3Array([Vector3(0.0, 0.0, i * length),
			Vector3(0.0, 0.0, (i + 1) * length)]))
		r.speed = spd
		runs.append(r)
	for i in n - 1:
		runs [i].link(runs [i + 1])
	if ring:
		runs [n - 1].link(runs [0])
	return runs


func _one(length: float, spd: float) -> BeltRun:
	var r:= BeltRun.new()
	r.set_length(length)
	r.speed = spd
	return r


func _tick(runs: Array [BeltRun]) -> void:
	for r in runs:
		if r.awake:
			r.tick(DT)
	for r in runs:
		if r.awake:
			r.flush()
	_tick_no += 1


func _settle(runs: Array [BeltRun], cap: int) -> int:
	for t in cap:
		var any:= false
		for r in runs:
			if r.awake:
				any = true
				break
		if not any:
			return t
		_tick(runs)
	return -1


func _wad(r: BeltRun, at_s: float, spd: float) -> bool:
	return r.board(BeltRun.Kind.WAD, 50, -1, WAD_REACH, 0.0, 0.0, at_s, spd)


func _strand(r: BeltRun, at_s: float, spd: float) -> bool:
	return r.board(BeltRun.Kind.TUFT, 1, -1, STRAND_REACH, 0.0, 0.0, at_s, spd)


func _nominal(reach: float) -> float:
	return maxf(Cfg.BELT_RIDE_SPACING, reach * 2.0)


func _total(runs: Array [BeltRun]) -> int:
	var n:= 0
	for r in runs:
		n += r.count()
	return n


func _well_ordered(r: BeltRun, what: String) -> bool:
	var f:= r.first()
	for i in range(f + 1, f + r.count()):
		var ahead:= r.s_of(i - 1)
		var me:= r.s_of(i)
		var need:= maxf(r.gap_of(i), r.reach_of(i - 1) + r.reach_of(i))
		if ahead - me < need - 1e-06:
			_check(false, "%s: rows %d and %d are %.4f m apart, need %.4f" % [what, i - 1, i, ahead - me, need])
			return false
	return true


func _on_arrived() -> void:
	_arrivals += 1


func _on_room() -> void:
	_room_events += 1


func _on_fell(_rec: Dictionary) -> void:
	_fell += 1
	_fell_ticks.append(_tick_no)


func _check(ok: bool, what: String) -> bool:
	if not ok:
		_fails += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	return ok


func _kinematics() -> void:
	print("\n[beltrun] kinematics")
	var runs:= _chain(RUNS, 10.0, FAST, false)
	_wad(runs [0], 0.0, FAST)
	var ticks:= 10000
	for t in ticks:
		_tick(runs)
	var travel:= -1.0
	var seams:= 0
	for i in RUNS:
		if runs [i].count() == 1:
			travel = i * 10.0 + runs [i].s_of(runs [i].first())
			seams = i
	var expected:= FAST * ticks * DT
	_check(absf(travel - expected) < 1e-06,
		"one wad, %d ticks, %d seams: travelled %.9f m for %.9f m of belt" % [ticks, seams, travel, expected])

	for spd in [Cfg.BELT_SPEED, FAST]:
		var r:= _one(100.0, spd)
		_wad(r, 0.0, 0.0)
		var ref_s:= 0.0
		var ref_v:= 0.0
		var n:= 0
		for t in 120:
			r.tick(DT)
			ref_v = minf(spd, move_toward(ref_v, spd, Cfg.BELT_RIDE_PICKUP * DT))
			ref_s += ref_v * DT
			n += 1
		var got_s:= r.s_of(r.first())
		var got_v:= r.speed_of(r.first())
		_check(absf(got_s - ref_s) < 1e-09 and absf(got_v - ref_v) < 1e-09 and got_v == spd,
			"from rest at %.1f m/s: %.6f m and %.3f m/s after %d ticks, rider rule says %.6f m and %.3f m/s"
			% [spd, got_s, got_v, n, ref_s, ref_v])
		_check(r.groups() == Vector3i(0, 1, 0), "at speed it is a free record: groups %s" % r.groups())


func _queue() -> void:
	print("\n[beltrun] queue")
	var r:= _one(10.0, FAST)
	r.set_outlet_held(true)
	_arrivals = 0
	r.arrived.connect(_on_arrived)
	var s:= 9.0
	var boarded:= 0
	while s > 0.3:
		if _wad(r, s, FAST):
			boarded += 1
		s -= _nominal(WAD_REACH) + _rng.randf_range(0.0, 0.3)
	_check(boarded >= 12, "boarded %d wads with slack" % boarded)
	var last:= { }
	var backwards:= 0.0
	var runs: Array [BeltRun] = [r]
	var t:= 0
	while t < 2000 and r.awake:
		_tick(runs)
		t += 1
		for i in range(r.first(), r.first() + r.count()):
			var q:= r.seq_of(i)
			var p:= r.s_of(i)
			if last.has(q):
				backwards = maxf(backwards, float(last [q]) - p)
			last [q] = p
	_check(not r.awake, "asleep after %d ticks" % t)
	_check(backwards <= 0.0, "worst backward step %.6f m" % backwards)
	_check(r.groups() == Vector3i(boarded, 0, 0), "all parked: groups %s" % r.groups())
	var park:= 10.0 - WAD_REACH * 2.0
	_check(absf(r.s_of(r.first()) - park) < 1e-06, "front parked at %.4f, park is %.4f" % [r.s_of(r.first()), park])
	var pitch_ok:= true
	var seq_ok:= true
	for i in range(r.first() + 1, r.first() + r.count()):
		if absf(r.s_of(i - 1) - r.s_of(i) - _nominal(WAD_REACH)) > 1e-06:
			pitch_ok = false
		if r.seq_of(i) < r.seq_of(i - 1):
			seq_ok = false
	_check(pitch_ok, "packed at %.2f m pitch" % _nominal(WAD_REACH))
	_check(seq_ok, "boarding order kept")
	_check(_arrivals == 1, "arrived fired %d time(s)" % _arrivals)
	_check(r.has_head() and r.peek_head() ["seq"] == r.seq_of(r.first()), "the front is what take_head offers")


	_fell = 0
	_fell_ticks = PackedInt32Array()
	_tick_no = 0
	r.fell_off.connect(_on_fell)
	r.set_outlet_held(false)
	t = 0
	while t < 400 and r.count() > 0:
		_tick(runs)
		t += 1
	_check(_fell == boarded, "%d fell off the open end" % _fell)
	var pitch_ticks:= _nominal(WAD_REACH) / FAST / DT
	var expect_last:= int(ceil(boarded * pitch_ticks - 1e-09))
	_check(_fell_ticks.size() == boarded and absf(float(_fell_ticks [boarded - 1]) - expect_last) <= 1.0,
		"the last left on tick %d, %d expected at %.2f ticks a load" % [_fell_ticks [boarded - 1], expect_last, pitch_ticks])
	r.fell_off.disconnect(_on_fell)
	r.arrived.disconnect(_on_arrived)


func _take() -> void:
	print("\n[beltrun] take")
	var r:= _one(10.0, FAST)
	r.set_outlet_held(true)
	_arrivals = 0
	r.arrived.connect(_on_arrived)
	var park:= 10.0 - WAD_REACH * 2.0
	for k in 12:
		_wad(r, park - k * _nominal(WAD_REACH), FAST)
	var runs: Array [BeltRun] = [r]
	var t:= _settle(runs, 100)
	_check(t >= 0 and r.groups() == Vector3i(12, 0, 0), "packed jam of 12 after %d tick(s): %s" % [t, r.groups()])
	var first_seq:= r.seq_of(r.first())
	var wrong:= func(kind: int, _strands: int) -> bool: return kind != BeltRun.Kind.WAD
	_check(r.take_head(wrong).is_empty() and r.count() == 12, "a filter that refuses wads takes nothing")
	var rec:= r.take_head()
	_check(int(rec.get("seq", -1)) == first_seq and absf(float(rec ["s"]) - park) < 1e-06,
		"take_head gave seq %d at %.4f" % [int(rec.get("seq", -1)), float(rec.get("s", -1.0))])
	_check(r.count() == 11 and r.awake, "11 left and the run is awake")
	t = _settle(runs, 100)
	_check(t >= 0 and absf(r.s_of(r.first()) - park) < 1e-06 and r.groups() == Vector3i(11, 0, 0),
		"the jam shuffled up one load in %d ticks (%.2f expected) and parked again" % [t, _nominal(WAD_REACH) / FAST / DT])
	_check(_well_ordered(r, "jam after a take"), "still packed")
	_check(_arrivals == 2, "arrived fired %d times for two arrivals" % _arrivals)
	var pose:= r.pose_of(r.first())
	_check(absf(pose.origin.z - park) < 1e-06 and pose.basis.z.is_equal_approx(Vector3.BACK),
		"pose_of the front: origin %s along +Z" % pose.origin)
	_check(r.record_at(Vector3(0.0, 0.0, park - 0.1), 0.05) == r.first()
		and r.record_at(Vector3(0.0, 0.0, 2.0), 0.05) == -1, "record_at finds the front and nothing on clear belt")
	r.arrived.disconnect(_on_arrived)


func _mouth() -> void:
	print("\n[beltrun] mouth")
	var runs:= _chain(2, 10.0, FAST, false)
	var a:= runs [0]
	var b:= runs [1]
	b.set_outlet_held(true)
	var boarded:= 0
	for t in 3000:
		if a.accepts(0.0, WAD_REACH, _nominal(WAD_REACH), BeltRun.Kind.WAD) and boarded < 40:
			_wad(a, 0.0, FAST)
			boarded += 1
		_tick(runs)
		if boarded == 40 and not a.awake and not b.awake:
			break
	var park:= 10.0 - WAD_REACH * 2.0
	var fit:= int(floor(park / _nominal(WAD_REACH))) + 1
	_check(b.count() == fit and b.groups() == Vector3i(fit, 0, 0), "B holds %d packed (%d fit)" % [b.count(), fit])
	_check(a.count() == 40 - fit and a.groups() == Vector3i(40 - fit, 0, 0), "A parks the other %d" % a.count())
	_check(not b.accepts(0.0, WAD_REACH, _nominal(WAD_REACH), BeltRun.Kind.WAD), "B refuses at the mouth")
	_check(not a.awake and not b.awake, "both asleep")
	_room_events = 0
	b.room_freed.connect(_on_room)
	for t in 30:
		_tick(runs)
	_check(_room_events == 0 and not a.awake and not b.awake, "nothing stirs while B is full: no room_freed in half a second")
	var taken:= b.take_head()
	_check(not taken.is_empty(), "B's machine takes one")
	var t:= 0
	while t < 60 and a.count() == 40 - fit:
		_tick(runs)
		t += 1
	var rear_was:= b.s_of(b.first() + b.count() - 1)


	_check(a.count() == 40 - fit - 1 and b.count() == fit and t <= 10,
		"A's front boarded B after %d ticks (%.2f from the parking spot to the seam)" % [t, _nominal(WAD_REACH) / FAST / DT])
	_check(_room_events == 1, "room_freed fired once, and woke A")
	_check(rear_was >= 0.0 and rear_was <= FAST * DT + 1e-06, "the new rear boarded at %.4f, with the overshoot" % rear_was)
	_check(a.count() + b.count() + 1 == 40, "conserved: %d + %d + 1 taken = 40" % [a.count(), b.count()])
	_check(_well_ordered(a, "A") and _well_ordered(b, "B"), "both runs well ordered")
	b.room_freed.disconnect(_on_room)


func _throughput() -> void:
	print("\n[beltrun] throughput")


	var rows:= [
		["wads", WAD_REACH, FAST, 10.0],
		["strand sized", STRAND_REACH, FAST, 10.0],
		["strand sized", STRAND_REACH, Cfg.BELT_SPEED, 10.0],
	]
	for row in rows:
		var what: String = row [0]
		var reach: float = row [1]
		var spd: float = row [2]
		var seconds: float = row [3]
		var r:= _one(40.0, spd)
		r.set_outlet_held(true)
		var runs: Array [BeltRun] = [r]
		var kind:= BeltRun.Kind.WAD if reach == WAD_REACH else BeltRun.Kind.TUFT
		var full:= false
		var filled:= 0
		for t in 40000:
			if r.accepts(0.0, reach, _nominal(reach), kind):
				r.board(kind, 1, -1, reach, 0.0, 0.0, 0.0, spd)
			_tick(runs)
			filled = t
			if not r.awake and not r.accepts(0.0, reach, _nominal(reach), kind):
				full = true
				break
		var aboard:= r.count()
		if not full:
			var f:= r.first()
			print("    not full after %d ticks: awake %s, groups %s, front %.3f, rear %.3f, mouth %s, first gaps %.3f %.3f %.3f"
				% [filled, r.awake, r.groups(), r.s_of(f), r.s_of(f + aboard - 1),
					r.accepts(0.0, reach, _nominal(reach), kind), r.s_of(f) - r.s_of(f + 1),
					r.s_of(f + 1) - r.s_of(f + 2), r.s_of(f + 2) - r.s_of(f + 3)])
		_fell = 0
		_tick_no = 0
		r.fell_off.connect(_on_fell)
		r.set_outlet_held(false)
		var ticks:= int(round(seconds / DT))
		for t in ticks:
			_tick(runs)
		r.fell_off.disconnect(_on_fell)
		var pitch:= _nominal(reach)
		var expected:= spd / pitch * seconds
		_check(full and absf(float(_fell) - expected) <= 1.0,
			"%s at %.1f m/s, %d packed at %.2f m: %d left in %.0f s, %.2f a second, %.2f expected"
			% [what, spd, aboard, pitch, _fell, seconds, _fell / seconds, spd / pitch])


func _hold() -> void:
	print("\n[beltrun] hold")
	var r:= _one(20.0, FAST)
	r.set_outlet_held(true)
	for s in [17.0, 14.0, 11.0, 8.0, 5.0, 2.0]:
		_wad(r, s, FAST)
	var runs: Array [BeltRun] = [r]
	_tick(runs)
	var before:= r.positions()
	r.hold_before(10.0)
	_check(r.groups() == Vector3i(0, 3, 3), "three frozen behind the line, three free past it: %s" % r.groups())
	for t in 60:
		_tick(runs)
	var after:= r.positions()
	var frozen_ok:= true
	var moved_ok:= true
	for i in 6:
		if before [i] + WAD_REACH <= 10.0 + BeltRun.HOLD_SLACK:
			if after [i] != before [i]:
				frozen_ok = false
		elif after [i] <= before [i]:
			moved_ok = false
	_check(frozen_ok, "the three behind the line did not move in a second")
	_check(moved_ok, "the three past it did")
	_check(r.speed_of(r.first() + 5) == 0.0, "a frozen load reads as standing still")
	r.hold_before(-1.0)
	_tick(runs)
	var v1:= r.speed_of(r.first() + r.count() - 1)
	_check(absf(v1 - Cfg.BELT_RIDE_PICKUP * DT) < 1e-06, "released, the rearmost is at %.4f m/s after one tick" % v1)
	var t:= 0
	while t < 400 and r.groups().z > 0:
		_tick(runs)
		t += 1
	_check(r.groups().z == 0, "the frozen ones came up to speed and folded into the block in %d ticks" % t)
	_check(_well_ordered(r, "after a hold"), "well ordered")


func _mid_board() -> void:
	print("\n[beltrun] mid board")
	var r:= _one(40.0, FAST)
	for s in [8.0, 6.0, 4.0]:
		_wad(r, s, FAST)
	var runs: Array [BeltRun] = [r]
	for t in 10:
		_tick(runs)
	var mid:= r.s_of(r.first() + 1)
	_check(not _wad(r, mid + 0.2, 0.0), "refused on top of a moving load")
	_check(_wad(r, mid + 0.5, 0.0), "boarded from rest half a metre ahead of it")
	_check(r.groups() == Vector3i(0, 1, 3), "the block splits at the drop: %s" % r.groups())
	var last:= { }
	var backwards:= 0.0
	var ordered:= true
	var t:= 0
	while t < 120:
		_tick(runs)
		t += 1
		if not _well_ordered(r, "mid board tick %d" % t):
			ordered = false
			break
		for i in range(r.first(), r.first() + r.count()):
			var q:= r.seq_of(i)
			var p:= r.s_of(i)
			if last.has(q):
				backwards = maxf(backwards, float(last [q]) - p)
			last [q] = p
	_check(ordered, "never closer than the follow distance while the dropped load came up to speed")
	_check(backwards <= 0.0, "worst backward step %.6f m" % backwards)
	_check(r.groups() == Vector3i(0, 4, 0), "one block again after two seconds: %s" % r.groups())


func _remove() -> void:
	print("\n[beltrun] remove")
	var r:= _one(10.0, FAST)
	r.set_outlet_held(true)
	var park:= 10.0 - WAD_REACH * 2.0
	for k in 6:
		_wad(r, park - k * _nominal(WAD_REACH), FAST)
	var runs: Array [BeltRun] = [r]
	_settle(runs, 100)
	var third:= r.seq_of(r.first() + 2)
	var rec:= r.remove_at(r.first() + 2)
	_check(int(rec ["seq"]) == third and absf(float(rec ["s"]) - (park - 2.0 * _nominal(WAD_REACH))) < 1e-06
		and r.count() == 5, "took the third out of a packed jam, seq %d at %.4f" % [int(rec ["seq"]), float(rec ["s"])])
	_check(r.groups() == Vector3i(2, 3, 0), "the three behind it are free to close up: %s" % r.groups())
	var t:= _settle(runs, 100)
	_check(t >= 0 and r.groups() == Vector3i(5, 0, 0) and _well_ordered(r, "closed up"),
		"closed up and parked again in %d ticks" % t)
	var pitch_ok:= true
	for i in range(r.first() + 1, r.first() + r.count()):
		if absf(r.s_of(i - 1) - r.s_of(i) - _nominal(WAD_REACH)) > 1e-06:
			pitch_ok = false
	_check(pitch_ok, "packed at pitch again")

	var f:= _one(40.0, FAST)
	for s in [30.0, 20.0, 10.0]:
		_wad(f, s, FAST)
	var fruns: Array [BeltRun] = [f]
	for i in 5:
		_tick(fruns)
	f.remove_at(f.first() + 1)
	for i in 5:
		_tick(fruns)
	_check(f.count() == 2 and absf(f.s_of(f.first()) - f.s_of(f.first() + 1) - 20.0) < 1e-09,
		"a hole in a moving block stays a hole: %.3f m apart" % (f.s_of(f.first()) - f.s_of(f.first() + 1)))


func _seed(runs: Array [BeltRun], spd: float, per_run: int) -> int:
	var boarded:= 0
	for r in runs:
		var s:= r.length() - 0.5
		for k in per_run:
			if _wad(r, s, spd):
				boarded += 1
			s -= _nominal(WAD_REACH) + _rng.randf_range(0.05, 0.3)
	return boarded


func _conservation() -> void:
	print("\n[beltrun] conservation")
	var runs:= _chain(RUNS, 40.0, FAST, true)
	var boarded:= _seed(runs, FAST, LOAD / RUNS)
	_fell = 0
	for r in runs:
		r.fell_off.connect(_on_fell)
	var ticks:= 10000
	var bad:= 0
	var ordered:= true
	for t in ticks:
		_tick(runs)
		if _total(runs) != boarded:
			bad += 1
		if t % 500 == 499:
			for r in runs:
				if not _well_ordered(r, "ring tick %d" % t):
					ordered = false
	for r in runs:
		r.fell_off.disconnect(_on_fell)
	var handed:= 0
	for r in runs:
		handed += r.handed
	_check(boarded == LOAD, "%d boarded on a ring of %d runs" % [boarded, RUNS])
	_check(bad == 0 and _fell == 0, "GATE conservation: %d aboard on every one of %d ticks, %d hand overs, none lost" % [boarded, ticks, handed])
	_check(ordered, "every run well ordered at every 500th tick")


	var short:= 10
	var chain:= _chain(short, 10.0, FAST, false)
	chain [short - 1].set_outlet_held(true)
	var fed:= 0
	var taken:= 0
	for t in ticks:
		if chain [0].accepts(0.0, WAD_REACH, _nominal(WAD_REACH), BeltRun.Kind.WAD):
			if _wad(chain [0], 0.0, FAST):
				fed += 1
		if t % 20 == 19 and not chain [short - 1].take_head().is_empty():
			taken += 1
		_tick(chain)
	_check(fed == _total(chain) + taken and taken > 0 and not chain [0].accepts(0.0, WAD_REACH, _nominal(WAD_REACH), BeltRun.Kind.WAD),
		"fed %d at one end of %d runs, took %d at the other, %d aboard, backed up to the feeder: exact" % [fed, short, taken, _total(chain)])


func _stats(us: PackedFloat64Array) -> Dictionary:
	var sorted:= us.duplicate()
	sorted.sort()
	var sum:= 0.0
	for v in sorted:
		sum += v
	var n:= sorted.size()
	return {
		"mean": sum / n, "median": sorted [n / 2], "p95": sorted [int(n * 0.95)],
		"max": sorted [n - 1],
	}


func _time(runs: Array [BeltRun], ticks: int, gated: bool) -> Dictionary:
	var us:= PackedFloat64Array()
	us.resize(ticks)
	for t in ticks:
		var t0:= Time.get_ticks_usec()
		if gated:
			for r in runs:
				if r.awake:
					r.tick(DT)
			for r in runs:
				if r.awake:
					r.flush()
		else:
			for r in runs:
				r.tick(DT)
			for r in runs:
				r.flush()
		us [t] = float(Time.get_ticks_usec() - t0)
	return _stats(us)


func _row(what: String, st: Dictionary) -> String:
	return "%-52s mean %7.1f us  median %7.1f  p95 %7.1f  max %7.1f" % [what, st ["mean"], st ["median"], st ["p95"], st ["max"]]


func _timing() -> void:
	print("\n[beltrun] timing, %d runs, %d records, 300 ticks warm up then 1000 timed" % [RUNS, LOAD])
	for spd in [FAST, Cfg.BELT_SPEED]:
		var runs:= _chain(RUNS, 40.0, spd, true)
		var boarded:= _seed(runs, spd, LOAD / RUNS)
		for t in 300:
			_tick(runs)
		var h0:= 0
		for r in runs:
			h0 += r.handed
		var st:= _time(runs, 1000, true)
		var h1:= 0
		for r in runs:
			h1 += r.handed
		var what:= "moving ring at %.1f m/s, %d aboard, %.1f hand overs a tick" % [spd, boarded, (h1 - h0) / 1000.0]
		print("  " + _row(what, st))
		if spd == FAST:
			_check(float(st ["mean"]) < GATE_MOVING_US,
				"GATE moving: %d records on %d runs at %.1f m/s, mean %.1f us a tick, limit %.0f" % [boarded, RUNS, spd, st ["mean"], GATE_MOVING_US])
		_check(_total(runs) == boarded, "%d still aboard" % _total(runs))


	var chain:= _chain(RUNS, 22.0, FAST, false)
	chain [RUNS - 1].set_outlet_held(true)
	var park:= 22.0 - WAD_REACH * 2.0
	var packed:= 0
	for r in chain:
		for k in LOAD / RUNS:
			if _wad(r, park - k * _nominal(WAD_REACH), FAST):
				packed += 1
	var t:= _settle(chain, 200)
	var all_jam:= true
	for r in chain:
		if r.groups() != Vector3i(LOAD / RUNS, 0, 0):
			all_jam = false
	_check(packed == LOAD and t >= 0 and all_jam, "%d packed on %d runs, every one a parked jam, asleep after %d tick(s)" % [packed, RUNS, t])
	var asleep:= _time(chain, 1000, true)
	print("  " + _row("jam of %d, runs asleep" % packed, asleep))
	_check(float(asleep ["mean"]) < GATE_JAM_US,
		"GATE jam: %d parked on %d runs, mean %.1f us a tick, limit %.0f" % [packed, RUNS, asleep ["mean"], GATE_JAM_US])


	var polled:= _time(chain, 1000, false)
	print("  " + _row("jam of %d, every run ticked and flushed anyway" % packed, polled))


	var us:= PackedFloat64Array()
	us.resize(3000)
	var taken:= 0
	for k in 3000:
		var t0:= Time.get_ticks_usec()
		if k % 30 == 0 and not chain [RUNS - 1].take_head().is_empty():
			taken += 1
		for r in chain:
			if r.awake:
				r.tick(DT)
		for r in chain:
			if r.awake:
				r.flush()
		us [k] = float(Time.get_ticks_usec() - t0)
	var creeping:= _stats(us)
	print("  " + _row("jam of %d, one taken every 30 ticks (%d taken)" % [packed, taken], creeping))
	_check(_total(chain) + taken == packed, "conserved through the takes: %d aboard + %d taken" % [_total(chain), taken])
	_check(float(creeping ["mean"]) < GATE_MOVING_US, "a creeping jam stays under the moving limit: mean %.1f us" % creeping ["mean"])


func _field(rows: int, length: float, pitch: float, at: Vector3, spd: float) -> Array [BeltRun]:
	var runs: Array [BeltRun] = []
	for i in rows:
		var z:= at.z + i * pitch
		var dir:= 1.0 if i % 2 == 0 else -1.0
		var x0:= at.x + (0.0 if dir > 0.0 else length)
		var x1:= at.x + (length if dir > 0.0 else 0.0)
		var straight:= BeltRun.new()
		straight.set_line(PackedVector3Array([Vector3(x0, at.y, z), Vector3(x1, at.y, z)]))
		straight.speed = spd
		runs.append(straight)
		var joint:= BeltRun.new()
		if i + 1 < rows:
			var nz:= z + pitch
			joint.set_line(PackedVector3Array([Vector3(x1, at.y, z),
				Vector3(x1 + dir * pitch * 0.5, at.y, (z + nz) * 0.5), Vector3(x1, at.y, nz)]))
		else:
			joint.set_line(PackedVector3Array([Vector3(x1, at.y, z), Vector3(at.x, at.y, at.z)]))
		joint.speed = spd
		runs.append(joint)
	for i in runs.size():
		runs [i].link(runs [(i + 1) % runs.size()])
	return runs


func _frames(n: int, batch: BeltRunBatch, watch: BeltRun) -> Dictionary:
	var rid:= get_viewport().get_viewport_rid()
	var batch_us:= PackedFloat64Array()
	var rows:= PackedFloat64Array()
	var draws:= PackedFloat64Array()
	var wall:= PackedFloat64Array()
	var gpu:= PackedFloat64Array()
	var dev:= PackedFloat64Array()
	var backwards:= 0
	var still:= 0
	var empty:= 0
	var prev_fo:= batch.drawn_free(watch)
	var prev_dt:= get_process_delta_time()
	var last:= Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		wall.append(float(now - last) / 1000.0)
		last = now
		batch_us.append(float(batch.last_us))
		rows.append(float(batch.rows_written))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))


		var fo:= batch.drawn_free(watch)
		var d:= fo - prev_fo
		if d < - watch.length() * 0.5:
			d += watch.length()
		prev_fo = fo
		if watch.free_speed() <= 0.0:
			empty += 1
		elif d < -1e-09:
			backwards += 1
		elif prev_dt < 0.001:


			pass
		elif d < 1e-09:
			still += 1
		else:
			dev.append(absf(d / watch.speed - prev_dt) / prev_dt)
		prev_dt = get_process_delta_time()
	return {
		"batch": _stats(batch_us), "rows": _stats(rows), "draws": _stats(draws),
		"wall": _stats(wall), "gpu": _stats(gpu),
		"dev": _stats(dev) if not dev.is_empty() else { },
		"backwards": backwards, "still": still, "empty": empty,
	}


func _wad_cuts() -> PackedFloat32Array:
	HayWad.shared_meshes()
	var out:= PackedFloat32Array()
	for c in HayWad._lod_ends:
		out.append(c * HayWad.scale_for(Cfg.WAD_BASE_STRANDS))
	return out


func _drawing() -> void:
	if DisplayServer.get_name() == "headless":
		print("\n[beltrun] drawing: skipped headless, run windowed for stage 3's gate")
		return


	DisplayServer.window_set_size(Vector2i(1600, 900))
	await get_tree().process_frame
	await get_tree().process_frame
	print("\n[beltrun] drawing, windowed at %s" % str(DisplayServer.window_get_size()))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rid:= get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var cam:= Camera3D.new()
	cam.far = 2000.0
	world.add_child(cam)


	cam.global_position = DRAW_AT + Vector3(DRAW_LENGTH * 0.5, 1.4, -1.4)
	cam.look_at(DRAW_AT + Vector3(DRAW_LENGTH * 0.5, 0.0, DRAW_ROWS * DRAW_PITCH * 0.3))
	cam.current = true
	var shots:= ""
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--shots")
	if at >= 0 and at + 1 < ua.size():
		shots = ua [at + 1]

	var runs:= _field(DRAW_ROWS, DRAW_LENGTH, DRAW_PITCH, DRAW_AT, FAST)
	var batch:= BeltRunBatch.new()
	batch.name = "BeltRunBatch"
	world.add_child(batch)
	for r in runs:
		batch.adopt(r)
	for i in 30:
		await get_tree().process_frame
	var empty:= await _frames(120, batch, runs [0])
	print("  empty field: %.0f draw calls, %.2f ms gpu, batch %.1f us"
		% [empty ["draws"] ["median"], empty ["gpu"] ["median"], empty ["batch"] ["mean"]])


	var total:= 0.0
	for r in runs:
		total += r.length() - 0.6
	var pitch:= total / DRAW_LOAD
	var boarded:= 0
	var per_run: Array [int] = []
	for r in runs:
		var s:= r.length() - 0.3
		var n0:= boarded
		while s > 0.3:
			if r.board(BeltRun.Kind.WAD, _rng.randi_range(Cfg.WAD_MIN_STRANDS, Cfg.WAD_MAX_STRANDS),
					-1, WAD_REACH, 0.0, 0.0, s, FAST):
				boarded += 1
			s -= pitch + _rng.randf_range(-0.04, 0.04)
		per_run.append(boarded - n0)
	_check(boarded >= DRAW_LOAD and per_run [runs.size() - 1] > 50,
		"%d wads boarded over %d runs at %.2f m: %d on the first row, %d on its hairpin, %d on the return leg"
		% [boarded, runs.size(), pitch, per_run [0], per_run [1], per_run [runs.size() - 1]])
	var watch:= runs [0]
	var jitter:= Engine.physics_jitter_fix
	print("  wad cuts at a base wad's size: %s; physics jitter fix %.2f" % [str(_wad_cuts()), jitter])
	var fixed:= "--fixed-fps" in OS.get_cmdline_args()
	for rate in [60, 30]:
		Engine.physics_ticks_per_second = rate
		_draw_runs = runs


		for jf in [jitter, 0.0]:
			Engine.physics_jitter_fix = jf
			_draw_tick_us = PackedFloat64Array()
			for i in 90:
				await get_tree().process_frame
			_draw_tick_us = PackedFloat64Array()
			var st:= await _frames(600, batch, watch)
			var ticks:= _stats(_draw_tick_us) if not _draw_tick_us.is_empty() else { "mean": 0.0, "max": 0.0 }
			var census:= Vector3i.ZERO
			for r in runs:
				census += r.groups()
			print("  simulation at %d Hz%s, jitter fix %.2f: %d aboard (jam %d, free %d, back %d), %d ticks in %d frames, %d MultiMeshes live, levels in use %s"
				% [rate, " with --fixed-fps" if fixed else "", jf, _total(runs), census.x, census.y, census.z,
					_draw_tick_us.size(), 600, batch.live_bins(), str(batch.lod_census())])
			print("    frame %.2f ms median (%.0f fps), gpu %.2f ms, draw calls %.0f median (%.0f empty)"
				% [st ["wall"] ["median"], 1000.0 / maxf(float(st ["wall"] ["median"]), 0.001),
					st ["gpu"] ["median"], st ["draws"] ["median"], empty ["draws"] ["median"]])
			print("    sim tick %.1f us mean, %.1f max; batch %.1f us mean, %.1f p95, %.1f max a frame, %.0f records written one by one"
				% [ticks ["mean"], ticks ["max"], st ["batch"] ["mean"], st ["batch"] ["p95"], st ["batch"] ["max"], st ["rows"] ["mean"]])
			var dev: Dictionary = st ["dev"]
			print("    drawn offset against frame time: deviation %.3f median, %.3f p95, %.3f max; %d frames backwards, %d still, %d with the row empty"
				% [dev.get("median", 0.0), dev.get("p95", 0.0), dev.get("max", 0.0), st ["backwards"], st ["still"], st ["empty"]])
			_check(float(st ["batch"] ["mean"]) < GATE_BATCH_US,
				"GATE drawing at %d Hz, jitter fix %.2f: %d moving records, batch %.1f us a frame, limit %.0f" % [rate, jf, _total(runs), st ["batch"] ["mean"], GATE_BATCH_US])
			if jf == 0.0 and fixed:


				_check(st ["backwards"] == 0 and int(st ["still"]) == 0 and int(st ["empty"]) == 0
					and float(dev.get("max", 1.0)) < 0.01,
					"GATE smooth at %d Hz under --fixed-fps: no frame moved the belt backwards, %d of 600 left it still, worst deviation %.3f"
					% [rate, st ["still"], dev.get("max", 1.0)])
			elif jf == 0.0:
				_check(st ["backwards"] == 0 and int(st ["empty"]) == 0,
					"real time at %d Hz: no frame moved the belt backwards, %d of 600 left it still (the engine's pacing; the gate is the --fixed-fps run)"
					% [rate, st ["still"]])
		Engine.physics_jitter_fix = jitter
		if shots != "":
			await RenderingServer.frame_post_draw
			var path:= shots.path_join("beltrun_draw_%dhz.png" % rate)
			get_viewport().get_texture().get_image().save_png(path)
			print("    saved %s" % path)
	_check(_total(runs) == boarded, "%d still aboard after both rates" % _total(runs))
	_draw_runs = []
	Engine.physics_ticks_per_second = 60
	var census:= batch.lod_census()
	_check(census.size() >= 2, "more than one level in use across the field: %s" % str(census))
