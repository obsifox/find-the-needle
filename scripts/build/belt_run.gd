class_name BeltRun
extends RefCounted


signal arrived


signal room_freed


signal fell_off(rec: Dictionary)


signal boarded

signal handed_in(seq: int, kind: int, strands: int)


signal handed_out(seq: int, kind: int, strands: int)


enum Kind { WAD, TUFT, BALE, FOILED_BALE, BRICK, PULP, DISC, ROLL }


enum Group { JAM, FREE, BACK }


enum Ev { BOARD, MOVE, LEAVE, REBASE }


const ITEM_IDS: Array [String] = ["hay_wad", "hay_tuft", "hay_bale", "foiled_bale",
	"eco_brick", "hay_pulp", "feed_disc", "paper_roll"]


const END_DEAD_ZONE:= 0.05


const HOLD_SLACK:= 0.015


const EPS:= 1e-07


const COMPACT_AT:= 64


var _line: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat64Array = PackedFloat64Array()
var _seg_basis: Array [Basis] = []
var _length:= 0.0


var speed: float = Cfg.BELT_SPEED

var pickup: float = Cfg.BELT_RIDE_PICKUP


var spacing: float = Cfg.BELT_RIDE_SPACING


var downstream: BeltRun = null

var catching:= true


var blocked:= false


var outlet_held:= false


var hold_for: Callable = Callable()


var mouth_gate: Callable = Callable()


static var gate_follows:= not ("--oldsplit" in OS.get_cmdline_user_args())


var boosted:= false


var wye:= false


var end_held:= false


var end_held_for: Callable = Callable()


var hold_back:= END_DEAD_ZONE


var _hold_line:= -1.0


var _pos:= PackedFloat64Array()
var _reach:= PackedFloat32Array()
var _gap:= PackedFloat32Array()
var _side:= PackedFloat32Array()
var _lift:= PackedFloat32Array()
var _spd:= PackedFloat32Array()
var _kind:= PackedInt32Array()
var _strands:= PackedInt32Array()
var _needle:= PackedInt32Array()
var _seq:= PackedInt32Array()


var _state: Array = []


var _head:= 0
var _jam:= 0
var _free:= 0


var _jam_offset:= 0.0:
	set(v):
		_jam_offset = v
		if not draw_queued and draw_queue != null:
			draw_queued = true
			draw_queue.append(self)
var _free_offset:= 0.0:
	set(v):
		_free_offset = v
		if not draw_queued and draw_queue != null:
			draw_queued = true
			draw_queue.append(self)


var _jam_speed:= 0.0
var _free_speed:= 0.0


var _jam_parked:= false


var _jam_limit:= INF


var _jam_step:= 0.0


var _resolved:= false


var awake:= true:
	set(v):
		awake = v
		if v and not draw_queued and draw_queue != null:
			draw_queued = true
			draw_queue.append(self)

var handed:= 0


var last_seq:= -1


var event_sink = null


var draw_queue = null
var draw_queued:= false

var last_dt:= 0.0


var stepped_tick:= 0


func lead_seconds(frac: float, now: int) -> float:
	var tps:= float(Engine.physics_ticks_per_second)
	var since:= float(now - stepped_tick) + frac


	return clampf(since / tps, 0.0, maxf(last_dt, float(FactoryClock.STRIDE_FAST) / tps))

var _live_back:= false

var _moved:= 0.0


var _woken:= false
var _room_was:= true
var _arrived_was:= false


static var _next_seq:= 1


func set_line(points: PackedVector3Array) -> void:
	_line = points
	_cum = PackedFloat64Array()
	_seg_basis = []
	_cum.append(0.0)
	var total:= 0.0
	for i in range(points.size() - 1):
		total += points [i].distance_to(points [i + 1])
		_cum.append(total)
		_seg_basis.append(BeltPath.run_basis(points [i], points [i + 1]))
	_length = total


func set_length(metres: float) -> void:
	set_line(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, metres)]))


func length() -> float:
	return _length


func line() -> PackedVector3Array:
	return _line


func cum() -> PackedFloat64Array:
	return _cum


func seg_bases() -> Array [Basis]:
	return _seg_basis


func is_straight() -> bool:
	return _line.size() == 2


func basis_at_start() -> Basis:
	return _seg_basis [0] if not _seg_basis.is_empty() else Basis.IDENTITY


func link(next: BeltRun) -> void:
	if downstream != null and downstream.room_freed.is_connected(wake):
		downstream.room_freed.disconnect(wake)
	downstream = next
	if next != null:
		next.room_freed.connect(wake)
	wake()


func count() -> int:
	return _pos.size() - _head


func groups() -> Vector3i:
	return Vector3i(_jam, _free, _pos.size() - _head - _jam - _free)


func s_of(i: int) -> float:
	if i < _head + _jam:
		return _pos [i] + _jam_offset
	if i < _head + _jam + _free:
		return _pos [i] + _free_offset
	return _pos [i]


func first() -> int:
	return _head


func kind_of(i: int) -> int:
	return _kind [i]


func seq_of(i: int) -> int:
	return _seq [i]


func reach_of(i: int) -> float:
	return _reach [i]


func gap_of(i: int) -> float:
	return _gap [i]


func speed_of(i: int) -> float:
	if i < _head + _jam:
		return 0.0 if _jam_parked else _jam_speed
	if i < _head + _jam + _free:
		return _free_speed
	return _spd [i]


func row_group(i: int) -> int:
	if i < _head + _jam:
		return Group.JAM
	if i < _head + _jam + _free:
		return Group.FREE
	return Group.BACK


func rel_of(i: int) -> float:
	return _pos [i]


func side_of(i: int) -> float:
	return _side [i]


func lift_of(i: int) -> float:
	return _lift [i]


func strands_of(i: int) -> int:
	return _strands [i]


func add_strands(i: int, n: int) -> void:
	_strands [i] += n
	if _state [i] is Dictionary:
		(_state [i] as Dictionary) ["strands"] = _strands [i]


func needle_of(i: int) -> int:
	return _needle [i]


func state_of(i: int) -> Variant:
	return _state [i]


func row_behind(at_s: float) -> int:
	return _row_behind(at_s)


func rows_in(lo: float, hi: float) -> Vector2i:
	return Vector2i(_row_behind(hi), _row_behind(lo - EPS))


func moved_sum() -> float:
	return _moved


func free_offset() -> float:
	return _free_offset


func free_speed() -> float:
	return _free_speed if _free > 0 else 0.0


func jam_offset() -> float:
	return _jam_offset


func jam_speed() -> float:
	return 0.0 if _jam == 0 or _jam_parked else _jam_speed


func free_room() -> float:
	if _free == 0:
		return 0.0
	var i:= _head + _jam
	var fa:= _pos [i] + _free_offset
	if _jam > 0:
		if not _jam_parked:
			return INF
		var jb:= i - 1
		return maxf(_pos [jb] + _jam_offset - _need(jb, i) - fa, 0.0)
	var park:= _park_s(_reach [i])
	var room:= INF if fa >= park - EPS else park - fa


	if wye and _free > 1:
		room = maxf(park - fa, 0.0)
	return minf(room, _blocker_room(i, i + _free, _free_offset))


func jam_room() -> float:
	if _jam == 0 or _jam_parked:
		return 0.0
	var fa:= _pos [_head] + _jam_offset
	var park:= _park_s(_reach [_head])
	var room:= INF if fa >= park - EPS else park - fa

	if wye and (_jam > 1 or _free > 0):
		room = maxf(park - fa, 0.0)
	return minf(room, _blocker_room(_head, _head + _jam, _jam_offset))


const NEAR_BLOCK:= 1.5


func _blocker_room(from: int, to: int, offset: float) -> float:
	var room:= INF
	if _blockers.is_empty() or from >= to:
		return room


	var rear:= _pos [to - 1] + offset
	var reach_ahead:= _pos [from] + offset + NEAR_BLOCK
	var k:= 0
	while k + 2 < _blockers.size():
		var bs:= _blockers [k]
		var br:= _blockers [k + 1]
		var bside:= _blockers [k + 2]
		k += 3
		if bs <= rear or bs > reach_ahead:
			continue
		var row:= _row_behind(bs)
		if row < from or row >= to:
			continue
		if absf(_side [row] - bside) > maxf(br + _reach [row], Cfg.STRAND_THICK * 6.0):
			continue
		var limit:= bs - maxf(_gap [row], br + _reach [row])
		room = minf(room, maxf(limit - (_pos [row] + offset), 0.0))
	return room


func row_room(i: int) -> float:
	var s:= _pos [i]
	if i < _head + _jam + _free:
		return free_room() if i >= _head + _jam else jam_room()
	if _hold_line >= 0.0 and s + _reach [i] <= _hold_line + HOLD_SLACK:
		return 0.0
	return maxf(_back_limit(i, s) - s, 0.0)


func _back_limit(i: int, s: float) -> float:
	var limit: float
	if i == _head:
		limit = _park_s(_reach [i])
	else:
		limit = s_of(i - 1) - _need(i - 1, i)


		if wye:
			limit = minf(limit, _park_s(_reach [i - 1]) - _need(i - 1, i))
	if not _blockers.is_empty():
		limit = minf(limit, _blocker_limit(i, s))
	return limit


func draw_into(out: PackedFloat64Array) -> void:
	out [0] = _free_offset
	out [1] = _free_speed if _free > 0 else 0.0
	out [2] = free_room() if _free > 0 else 0.0
	out [3] = _jam_offset
	var moving:= _jam > 0 and not _jam_parked
	out [4] = _jam_speed if moving else 0.0
	out [5] = jam_room() if moving else 0.0
	out [6] = _head
	out [7] = _jam
	out [8] = _free
	out [9] = _pos.size()


func rel_raw() -> PackedFloat64Array:
	return _pos


func _ev_board(k: int) -> void:
	if event_sink == null:
		return
	var rec:= record(k)
	rec ["group"] = row_group(k)
	rec ["rel"] = _pos [k]
	event_sink.append([self, Ev.BOARD, rec])


func _ev_move(k: int, group: int) -> void:
	if event_sink != null:
		event_sink.append([self, Ev.MOVE, _seq [k], group, _pos [k]])


func _ev_leave(seq: int) -> void:
	if event_sink != null:
		event_sink.append([self, Ev.LEAVE, seq])


func _ev_rebase(group: int) -> void:
	if event_sink != null:
		event_sink.append([self, Ev.REBASE, group])


func positions() -> PackedFloat64Array:
	var out:= PackedFloat64Array()
	var n:= _pos.size()
	out.resize(n - _head)
	for i in range(_head, n):
		out [i - _head] = s_of(i)
	return out


func seqs() -> PackedInt32Array:
	return _seq.slice(_head)


func record(i: int) -> Dictionary:
	return {
		"kind": _kind [i], "strands": _strands [i], "needle": _needle [i],
		"reach": _reach [i], "side": _side [i], "lift": _lift [i],
		"seq": _seq [i], "state": _state [i], "s": s_of(i),
		"speed": speed_of(i),
	}


func accepts(at_s: float, reach: float, gap: float, kind: int) -> bool:
	return at_s <= mouth_limit(reach, gap, kind) + EPS


func front_near_end(reach: float = 0.0) -> bool:
	if _pos.size() == _head:
		return false
	return s_of(_head) >= _park_s(_reach [_head]) - 0.001 - maxf(reach, 0.0)


func front_past_park() -> bool:
	if _pos.size() == _head:
		return false
	return s_of(_head) > _park_s(_reach [_head]) + 0.002


func front_past_park_by() -> float:
	if _pos.size() == _head:
		return 0.0
	return maxf(s_of(_head) - _park_s(_reach [_head]) - 0.002, 0.0)


func mouth_limit(reach: float, gap: float, kind: int, from: BeltRun = null) -> float:
	if not catching:
		return - INF
	if blocked and _holds(kind):
		return - INF


	var g:= INF
	if mouth_gate.is_valid():
		g = float(mouth_gate.call(reach, from))
		if g == - INF or (g < 0.0 and not gate_follows):
			return - INF
	var n:= _pos.size()
	if n == _head:
		return g
	var rear:= n - 1
	var need:= maxf(maxf(gap, reach + _reach [rear]), maxf(_gap [rear], spacing))
	return minf(s_of(rear) - need, g)


func fits(reach: float, at_s: float) -> bool:
	if not catching:
		return false
	var n:= _pos.size()
	if n == _head:
		return true
	var nominal:= maxf(spacing, maxf(reach * 2.0, Cfg.STRAND_THICK * 2.0))
	var k:= n
	var d_ahead:= INF
	var rear_s:= s_of(n - 1)
	if at_s <= rear_s + EPS:
		d_ahead = rear_s - at_s
	else:
		k = _row_behind(at_s)
		if k > _head:
			d_ahead = s_of(k - 1) - at_s
		if k < n and at_s - s_of(k) < maxf(_gap [k], reach + _reach [k]) - EPS:
			return false
	if k > _head:
		var need:= maxf(maxf(nominal, reach + _reach [k - 1]), spacing)
		if d_ahead < need - EPS:
			return false
	return true


func board(kind: int, strands: int, needle: int, reach: float, side: float,
		lift: float, at_s: float = 0.0, spd: float = 0.0, state: Variant = null,
		seq: int = -1, mouth: bool = true) -> bool:
	if not catching:
		return false
	if blocked and mouth and _holds(kind):
		return false
	var n:= _pos.size()
	var min_gap:= maxf(reach * 2.0, Cfg.STRAND_THICK * 2.0)
	var nominal:= maxf(spacing, min_gap)
	var k:= n
	var d_ahead:= INF
	if n > _head:
		var rear_s:= s_of(n - 1)
		if at_s <= rear_s + EPS:
			d_ahead = rear_s - at_s
		else:
			k = _row_behind(at_s)
			if k > _head:
				d_ahead = s_of(k - 1) - at_s
			if k < n and at_s - s_of(k) < maxf(_gap [k], reach + _reach [k]) - EPS:
				return false
	if k > _head:
		var a:= k - 1


		var need:= maxf(maxf(nominal, reach + _reach [a]), spacing)
		if d_ahead < need - EPS:
			return false
	var gap:= clampf(minf(d_ahead, spacing), min_gap, nominal)
	if seq < 0:
		seq = _next_seq
		_next_seq += 1
	last_seq = seq
	spd = minf(spd, speed)
	if boosted and spd > 0.0:
		spd = speed
	var held:= _hold_line >= 0.0 and at_s + reach <= _hold_line + HOLD_SLACK
	if held:
		spd = 0.0
	var fs:= _head + _jam
	var fe:= fs + _free
	var pos:= at_s
	if k < fs:


		pos = at_s - _jam_offset
		_jam += 1
	elif k < fe:
		if not held and spd >= _free_speed - EPS:
			pos = at_s - _free_offset
			_free += 1
		else:


			for i in range(k, fe):
				_pos [i] = _pos [i] + _free_offset
				_spd [i] = _free_speed
				_ev_move(i, Group.BACK)
			_free = k - fs
	elif k == fe and n == fe and not held and (_free == 0 or spd >= _free_speed - EPS):

		if _free == 0:
			_free_offset = 0.0
			_free_speed = spd
		pos = at_s - _free_offset
		_free += 1
	_insert_row(k, pos, reach, gap, side, lift, spd, kind, strands, needle, seq, state)
	_ev_board(k)
	wake()
	boarded.emit()
	return true


func board_record(rec: Dictionary, at_s: float = 0.0, spd: float = 0.0,
		mouth: bool = true) -> bool:
	return board(int(rec ["kind"]), int(rec ["strands"]), int(rec ["needle"]),
		float(rec ["reach"]), float(rec ["side"]), float(rec ["lift"]), at_s, spd,
		rec.get("state"), int(rec.get("seq", -1)), mouth)


func _row_behind(at_s: float) -> int:
	var lo:= _head
	var hi:= _pos.size()
	while lo < hi:
		var mid:= (lo + hi) >> 1
		if s_of(mid) <= at_s:
			hi = mid
		else:
			lo = mid + 1
	return lo


func _insert_row(k: int, pos: float, reach: float, gap: float, side: float,
		lift: float, spd: float, kind: int, strands: int, needle: int, seq: int,
		state: Variant) -> void:
	if k == _pos.size():
		_pos.append(pos)
		_reach.append(reach)
		_gap.append(gap)
		_side.append(side)
		_lift.append(lift)
		_spd.append(spd)
		_kind.append(kind)
		_strands.append(strands)
		_needle.append(needle)
		_seq.append(seq)
		_state.append(state)
		return
	_pos.insert(k, pos)
	_reach.insert(k, reach)
	_gap.insert(k, gap)
	_side.insert(k, side)
	_lift.insert(k, lift)
	_spd.insert(k, spd)
	_kind.insert(k, kind)
	_strands.insert(k, strands)
	_needle.insert(k, needle)
	_seq.insert(k, seq)
	_state.insert(k, state)


func _remove_row(k: int) -> void:
	_pos.remove_at(k)
	_reach.remove_at(k)
	_gap.remove_at(k)
	_side.remove_at(k)
	_lift.remove_at(k)
	_spd.remove_at(k)
	_kind.remove_at(k)
	_strands.remove_at(k)
	_needle.remove_at(k)
	_seq.remove_at(k)
	_state.remove_at(k)


func _compact() -> void:
	if _head < COMPACT_AT or _head * 2 < _pos.size():
		return
	_pos = _pos.slice(_head)
	_reach = _reach.slice(_head)
	_gap = _gap.slice(_head)
	_side = _side.slice(_head)
	_lift = _lift.slice(_head)
	_spd = _spd.slice(_head)
	_kind = _kind.slice(_head)
	_strands = _strands.slice(_head)
	_needle = _needle.slice(_head)
	_seq = _seq.slice(_head)
	_state = _state.slice(_head)
	_head = 0


func has_head() -> bool:
	return _jam > 0 and _jam_parked


func head_kind() -> int:
	return _kind [_head] if has_head() else -1


func peek_head() -> Dictionary:
	return record(_head) if has_head() else { }


func take_head(filter: Callable = Callable()) -> Dictionary:
	if not has_head():
		return { }
	var i:= _head
	if filter.is_valid() and not bool(filter.call(_kind [i], _strands [i])):
		return { }
	var rec:= record(i)
	_ev_leave(_seq [i])
	_head += 1
	_jam -= 1
	_jam_parked = false
	_jam_limit = INF
	wake()
	_compact()
	return rec


func take_within(filter: Callable, lo: float, hi: float) -> Dictionary:
	for i in range(_head, _pos.size()):
		var s:= s_of(i)
		if s < lo or s > hi:
			continue
		if filter.is_valid() and not bool(filter.call(_kind [i], _strands [i])):
			continue
		return remove_at(i)
	return { }


func clear() -> void:
	for i in range(_head, _pos.size()):
		_ev_leave(_seq [i])
	_pos = PackedFloat64Array()
	_reach = PackedFloat32Array()
	_gap = PackedFloat32Array()
	_side = PackedFloat32Array()
	_lift = PackedFloat32Array()
	_spd = PackedFloat32Array()
	_kind = PackedInt32Array()
	_strands = PackedInt32Array()
	_needle = PackedInt32Array()
	_seq = PackedInt32Array()
	_state = []
	_head = 0
	_jam = 0
	_free = 0
	_jam_offset = 0.0
	_free_offset = 0.0
	_jam_parked = false
	_jam_limit = INF
	wake()


func remove_at(i: int) -> Dictionary:
	var rec:= record(i)
	_ev_leave(_seq [i])
	var je:= _head + _jam
	if i < je:
		if i > _head:


			for j in range(i + 1, je):
				_pos [j] = _pos [j] + _jam_offset - _free_offset
				_ev_move(j, Group.FREE)
			_free += je - i - 1
			_jam = i - _head
		else:
			_jam -= 1
			_jam_parked = false
			_jam_limit = INF
	elif i < je + _free:
		_free -= 1
	if i == _head:
		_head += 1
		_compact()
	else:
		_remove_row(i)
	wake()
	return rec


func set_blocked(on: bool) -> void:
	var was:= blocked
	blocked = on
	if was and not on:
		room_freed.emit()


func set_outlet_held(on: bool) -> void:
	outlet_held = on
	if not on:
		wake()


func set_end_held(on: bool) -> void:
	end_held = on
	if not on:
		wake()


func holds_kind(kind: int) -> bool:
	return _holds(kind)


func set_catching(on: bool) -> void:
	var was:= catching
	catching = on
	if on and not was:
		room_freed.emit()


func set_speed(v: float) -> void:
	speed = v
	wake()


func hold_before(s: float) -> void:
	var was:= _hold_line
	_hold_line = s
	if s < 0.0:
		if was >= 0.0:


			if _jam > 0 and _jam_parked:
				var fa:= _pos [_head] + _jam_offset
				if fa < _park_s(_reach [_head]) - EPS and fa < _jam_limit - EPS:
					_jam_parked = false
			wake()
		return
	var fs:= _head + _jam
	var fe:= fs + _free
	var jam_cut:= fs
	while jam_cut > _head and s_of(jam_cut - 1) + _reach [jam_cut - 1] <= s + HOLD_SLACK:
		jam_cut -= 1
	if jam_cut < fs:


		for i in range(jam_cut, fs):
			_pos [i] = _pos [i] + _jam_offset
			_spd [i] = 0.0
			_ev_move(i, Group.BACK)
		for i in range(fs, fe):
			_pos [i] = _pos [i] + _free_offset
			_spd [i] = _free_speed
			_ev_move(i, Group.BACK)
		_jam = jam_cut - _head
		_free = 0
		_free_offset = 0.0
		fs = _head + _jam
		fe = fs


	var cut:= fe
	while cut > fs and s_of(cut - 1) + _reach [cut - 1] <= s + HOLD_SLACK:
		cut -= 1
	for i in range(cut, fe):
		_pos [i] = _pos [i] + _free_offset
		_spd [i] = 0.0
		_ev_move(i, Group.BACK)
	_free = cut - fs
	for i in range(fe, _pos.size()):
		if _pos [i] + _reach [i] <= s + HOLD_SLACK:
			_spd [i] = 0.0


func hold_line() -> float:
	return _hold_line


func wake() -> void:
	awake = true
	_woken = true


func _holds(kind: int) -> bool:
	return not hold_for.is_valid() or bool(hold_for.call(kind))


var _blockers:= PackedFloat64Array()


func set_blockers(triples: PackedFloat64Array) -> void:
	_blockers = triples


func _blocker_limit(i: int, s: float) -> float:
	var out:= INF
	var n:= _blockers.size()
	var k:= 0
	while k + 2 < n:
		var bs:= _blockers [k]
		if bs > s and absf(_blockers [k + 2] - _side [i]) <= maxf(_blockers [k + 1] + _reach [i], Cfg.STRAND_THICK * 6.0):
			out = minf(out, bs - maxf(_gap [i], _blockers [k + 1] + _reach [i]))
		k += 3
	return out


func _apply_blockers(jam_step: float, free_step: float) -> void:
	var n:= _blockers.size()
	var k:= 0
	while k + 2 < n:
		var bs:= _blockers [k]
		var br:= _blockers [k + 1]
		var bside:= _blockers [k + 2]
		k += 3
		var row:= _row_behind(bs)
		var je:= _head + _jam
		var fe:= je + _free

		if row >= fe:
			continue
		if absf(_side [row] - bside) > maxf(br + _reach [row], Cfg.STRAND_THICK * 6.0):
			continue
		var limit:= bs - maxf(_gap [row], br + _reach [row])
		var in_jam:= row < je
		if in_jam and _jam_parked:
			continue
		if in_jam and row == _head:
			var fa:= _pos [row] + _jam_offset
			if fa > limit:
				var pull:= minf(fa - limit, jam_step)
				_jam_offset -= pull
				_moved -= pull * _jam
			continue
		var step:= jam_step if in_jam else free_step
		var fa:= _pos [row] + (_jam_offset if in_jam else _free_offset)


		if fa <= limit:
			continue
		var pull:= minf(fa - limit, step)
		if in_jam:
			for j in range(row, je):
				_pos [j] = _pos [j] + _jam_offset - pull
				_spd [j] = _jam_speed
				_ev_move(j, Group.BACK)
			for j in range(je, fe):
				_pos [j] = _pos [j] + _free_offset
				_spd [j] = _free_speed
				_ev_move(j, Group.BACK)
			_moved -= pull * float(je - row)
			_jam = row - _head
			_free = 0
			_free_offset = 0.0
		else:
			for j in range(row, fe):
				_pos [j] = _pos [j] + _free_offset - pull
				_spd [j] = _free_speed
				_ev_move(j, Group.BACK)
			_moved -= pull * float(fe - row)
			_free = row - je
			if _free == 0:
				_free_offset = 0.0


func _need(ahead: int, me: int) -> float:
	return maxf(_gap [me], _reach [ahead] + _reach [me])


func _park_s(reach: float) -> float:
	return maxf(_length - maxf(hold_back, reach * 2.0), 0.0)


func _outlet_limit(i: int) -> float:
	if end_held or (outlet_held and _holds(_kind [i])) or (end_held_for.is_valid() and bool(end_held_for.call(_kind [i]))):
		return _park_s(_reach [i])
	if downstream == null:
		return INF
	var m:= downstream.mouth_limit(_reach [i], _gap [i], _kind [i], self)
	return _park_s(_reach [i]) if m == - INF else _length + m


func tick(dt: float) -> void:
	var t0:= Time.get_ticks_usec()
	_tick(dt)
	tick_usec += Time.get_ticks_usec() - t0
	tick_calls += 1


static var tick_usec:= 0
static var tick_calls:= 0


func _tick(dt: float) -> void:
	last_dt = dt
	stepped_tick = Engine.get_physics_frames()
	_resolved = false
	_moved = 0.0
	var n:= _pos.size()
	if n == _head:
		return
	_jam_speed = minf(speed, move_toward(_jam_speed, speed, pickup * dt))
	_free_speed = minf(speed, move_toward(_free_speed, speed, pickup * dt))
	if wye:
		_wye_split()
	if boosted and _jam > 0 and _jam_parked:


		var limit:= _outlet_limit(_head)
		if limit > _pos [_head] + _jam_offset + EPS:
			_jam_parked = false
			_jam_limit = limit
	var jam_step:= 0.0
	var free_step:= 0.0
	_jam_step = 0.0
	if _jam > 0 and not _jam_parked:
		jam_step = _advance_jam(dt)
		_jam_step = jam_step
	if _free > 0:
		free_step = _advance_free(dt)
	if not _blockers.is_empty():
		_apply_blockers(jam_step, free_step)
	if _free > 0:
		_settle_free()
	_live_back = false
	if _pos.size() > _head + _jam + _free:
		_live_back = _advance_back(dt)


func _wye_split() -> void:
	var n:= _pos.size()
	if n - _head < 2:
		return
	var fs:= _head + _jam
	var fe:= fs + _free
	if _jam > 0:
		if _jam < 2 and _free == 0:
			return
		if _pos [_head] + _jam_offset < _park_s(_reach [_head]) - EPS:
			return
		for i in range(_head + 1, fs):
			_pos [i] = _pos [i] + _jam_offset
			_spd [i] = _jam_speed
			_ev_move(i, Group.BACK)
		for i in range(fs, fe):
			_pos [i] = _pos [i] + _free_offset
			_spd [i] = _free_speed
			_ev_move(i, Group.BACK)
		_jam = 1
		_free = 0
		_free_offset = 0.0
	elif _free > 1:
		if _pos [_head] + _free_offset < _park_s(_reach [_head]) - EPS:
			return
		for i in range(_head + 1, fe):
			_pos [i] = _pos [i] + _free_offset
			_spd [i] = _free_speed
			_ev_move(i, Group.BACK)
		_free = 1


func flush() -> void:
	if _resolved:
		return
	_resolved = true
	var ahead: Array [BeltRun] = []
	var r:= downstream
	while r != null and not r._resolved:
		r._resolved = true
		ahead.append(r)
		r = r.downstream
	for k in range(ahead.size() - 1, -1, -1):
		ahead [k]._flush_self()
	_flush_self()


func _flush_self() -> void:
	if _pos.size() > _head:
		_resolve_front()
	_events()
	awake = _woken or _free > 0 or _live_back or (_jam > 0 and not _jam_parked)
	_woken = false


func _advance_jam(dt: float) -> float:
	var i:= _head
	if _jam_offset > _length and _length > 0.0:


		for j in range(_head, _head + _jam):
			_pos [j] += _length
		_jam_offset -= _length
		_ev_rebase(Group.JAM)
	var fa:= _pos [i] + _jam_offset
	if _hold_line >= 0.0 and fa + _reach [i] <= _hold_line + HOLD_SLACK:
		_jam_parked = true
		return 0.0
	var step:= minf(_jam_speed * dt, maxf(_jam_limit - fa, 0.0))
	_jam_offset += step
	_moved += step * _jam
	return step


func _advance_free(dt: float) -> float:
	var step:= _free_speed * dt
	_free_offset += step
	_moved += step * _free
	if _free_offset > _length and _length > 0.0:

		for j in range(_head + _jam, _head + _jam + _free):
			_pos [j] += _length
		_free_offset -= _length
		_ev_rebase(Group.FREE)
	return step


func _settle_free() -> void:
	while _free > 0 and _jam > 0:
		var i:= _head + _jam
		var fa:= _pos [i] + _free_offset
		var jb:= i - 1
		var limit:= _pos [jb] + _jam_offset - _need(jb, i)
		if fa < limit - EPS:
			break
		_pos [i] = limit - _jam_offset
		_jam += 1
		_free -= 1
		_ev_move(i, Group.JAM)
	if _free == 0:
		_free_offset = 0.0


const NEAR_END:= 2.0


func _resolve_front() -> void:
	var i:= _head
	var in_jam:= _jam > 0


	var in_free:= not in_jam and _free > 0
	var fa:= _pos [i] + (_jam_offset if in_jam else (_free_offset if in_free else 0.0))
	var park:= _park_s(_reach [i])
	if fa < minf(park, _length - NEAR_END) - EPS:
		return
	var spd:= _jam_speed if in_jam else (_free_speed if in_free else _spd [i])
	var step:= spd * last_dt
	var limit:= _outlet_limit(i)
	if fa > limit + EPS:
		if in_jam:


			var at:= maxf(limit, fa - _jam_step)
			_jam_offset += at - fa
			_moved += (at - fa) * _jam
			_jam_limit = at
			_jam_parked = true
		else:


			var at:= maxf(limit, fa - step)
			_moved += at - fa
			_start_jam(i, at)
		_settle_free()
		return
	if fa >= _length - EPS:
		if _leave_front(i, fa - _length, spd):
			if in_jam:
				_jam -= 1
				_jam_limit = INF
			elif in_free:
				_free -= 1
				if _free == 0:
					_free_offset = 0.0
			return


		if in_jam:


			_jam_offset -= _jam_step
			_jam_limit = fa - _jam_step
			_jam_parked = true
		else:
			_start_jam(i, maxf(park, fa - step))
		_settle_free()
		return
	if in_jam:
		_jam_limit = limit
		_jam_parked = fa >= limit - EPS


func _start_jam(i: int, at: float) -> void:
	_jam_offset = 0.0
	_jam_speed = _free_speed if _free > 0 else _spd [i]
	_jam_limit = at
	_pos [i] = at
	_jam = 1
	if _free > 0:
		_free -= 1
		if _free == 0:
			_free_offset = 0.0
	_jam_parked = true
	_ev_move(i, Group.JAM)


func _leave_front(i: int, over: float, spd: float) -> bool:
	var next:= downstream
	if next != null:
		if not next.board(_kind [i], _strands [i], _needle [i], _reach [i],
				_side [i], _lift [i], over, spd, _state [i], _seq [i]):
			return false
	else:
		var rec:= record(i)
		rec ["s"] = _length + over
		fell_off.emit(rec)
	var seq:= _seq [i]
	var kind:= _kind [i]
	var strands:= _strands [i]
	_ev_leave(seq)
	_head += 1
	handed += 1
	_compact()


	handed_out.emit(seq, kind, strands)
	if next != null:
		next.handed_in.emit(seq, kind, strands)
	return true


func _advance_back(dt: float) -> bool:
	var n:= _pos.size()
	var fb:= _head + _jam + _free
	var live:= false
	for i in range(fb, n):
		var s:= _pos [i]
		if _hold_line >= 0.0 and s + _reach [i] <= _hold_line + HOLD_SLACK:
			_spd [i] = 0.0
			continue
		live = true
		var v:= minf(speed, move_toward(_spd [i], speed, pickup * dt))
		_spd [i] = v
		var target:= s + v * dt
		var limit:= _back_limit(i, s)
		if target > limit:
			target = maxf(limit, s)
		if target > s:
			_moved += target - s
			_pos [i] = target
	while fb < n:
		var i:= fb
		if _hold_line >= 0.0 and _pos [i] + _reach [i] <= _hold_line + HOLD_SLACK:
			break


		if not _blockers.is_empty() and _pos [i] >= _blocker_limit(i, _pos [i]) - EPS:
			break


		if wye and fb > _head and s_of(_head) >= _park_s(_reach [_head]) - EPS:
			break
		if _free == 0:
			_free_offset = 0.0
			_free_speed = _spd [i]
		elif _spd [i] < _free_speed - EPS:
			break
		_pos [i] = _pos [i] - _free_offset
		_free += 1
		_ev_move(i, Group.FREE)
		fb += 1
	return live


func _room_at_start() -> bool:
	var n:= _pos.size()
	if n == _head:
		return true
	var rear:= n - 1
	return s_of(rear) >= maxf(_gap [rear], spacing) - EPS


func _events() -> void:
	var room:= _room_at_start()
	if room and not _room_was:
		room_freed.emit()
	_room_was = room
	var avail:= _jam > 0 and _jam_parked
	if avail and not _arrived_was:
		arrived.emit()
	_arrived_was = avail


func record_at(point: Vector3, radius: float) -> int:
	if _line.size() < 2:
		return -1
	var s:= float(_nearest(point) ["s"])
	for i in range(_head, _pos.size()):
		if absf(s_of(i) - s) <= _reach [i] + radius:
			return i
	return -1


func pose_of(i: int) -> Transform3D:
	return pose_at(s_of(i), _side [i], _lift [i])


func pose_at(s: float, side: float, lift: float) -> Transform3D:
	var last:= _line.size() - 2
	if last < 0:
		return Transform3D.IDENTITY
	var k:= 0
	while k < last and s > _cum [k + 1]:
		k += 1
	var basis: Basis = _seg_basis [k]
	var span: float = maxf(_cum [k + 1] - _cum [k], 1e-06)
	var at: Vector3 = _line [k].lerp(_line [k + 1], clampf((s - _cum [k]) / span, 0.0, 1.0)) + basis.x * side + basis.y * lift
	return Transform3D(basis, at)


func _nearest(p: Vector3) -> Dictionary:
	var best_d2:= INF
	var best:= -1
	var best_t:= 0.0
	var best_on:= Vector3.ZERO
	for i in range(_line.size() - 1):
		var a:= _line [i]
		var ab:= _line [i + 1] - a
		var len2:= ab.length_squared()
		if len2 < 1e-08:
			continue
		var t:= clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		var on:= a + ab * t
		var d2:= p.distance_squared_to(on)
		if d2 >= best_d2:
			continue
		best_d2 = d2
		best = i
		best_t = t
		best_on = on
	if best < 0:
		return { "s": 0.0, "side": 0.0, "lift": 0.0 }
	var basis: Basis = _seg_basis [best]
	var off:= p - best_on
	return {
		"s": _cum [best] + _line [best].distance_to(_line [best + 1]) * best_t,
		"side": off.dot(basis.x),
		"lift": off.dot(basis.y),
	}
