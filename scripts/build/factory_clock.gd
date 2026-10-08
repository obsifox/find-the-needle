class_name FactoryClock
extends Node


const BEFORE_THE_MACHINES:= -100


static var last_runs_usec:= 0
static var last_flush_usec:= 0
static var last_machines_usec:= 0
static var last_called:= 0
static var last_waiting:= 0


static var profile:= false
static var prof: Dictionary = { }


static var waiting_enabled: bool = not ("--oldidle" in OS.get_cmdline_user_args())


static func idle_router(paths: Array, key: Array, memo: Array) -> bool:
	if not waiting_enabled:
		return false
	for p in paths:
		if p != null and is_instance_valid(p) and not (p as BeltPath)._asleep:
			memo.clear()
			return false
	if not memo.is_empty() and memo [0] == key:
		return true
	memo.clear()
	memo.append(key)
	return false


static func prof_add(key: String, us: int) -> void:
	var row: Array = prof.get(key, [0, 0])
	row [0] += us
	row [1] += 1
	prof [key] = row


static func class_of(n: Object) -> String:
	var s: Script = n.get_script()
	if s == null:
		return n.get_class()
	var g:= s.get_global_name()
	return String(g) if g != &"" else s.resource_path.get_file().get_basename()


const SWEEP_EVERY:= 1.0


static var _machines: Array = []


static var _walking:= false
static var _joined: Array = []
static var _left: Array = []

static var _owed_by: Dictionary = { }


static func join(m: Node) -> void:
	m.set_physics_process(true)
	if _walking:
		_joined.append(m)
		return
	if not _machines.has(m):
		_machines.append(m)


static func leave(m: Node) -> void:
	if _walking:
		_left.append(m)
		return
	_machines.erase(m)


func _ready() -> void:
	process_physics_priority = BEFORE_THE_MACHINES


var _sweep_clock:= 0.0


var _machines_owed:= 0.0
var _machines_frame:= -1
var _sweep_owed:= false


var _sweep_left:= 0


static var stride: int = 1 if "--factory60" in OS.get_cmdline_user_args() else STRIDE_FAST


const STRIDE_FAST:= 2
static var forced_60: bool = "--factory60" in OS.get_cmdline_user_args()


const LONG_GAP:= 4


static func gap_limit(m: Object, delta: float) -> float:
	if m == null:
		return delta * (float(LONG_GAP) - 0.5)
	var id:= m.get_instance_id()
	var gap = _gap_of.get(id)
	if gap == null:
		gap = int(m.step_gap_ticks()) if m.has_method(&"step_gap_ticks") else LONG_GAP
		_gap_of [id] = gap
	return delta * (float(gap) - 0.5)


static var _gap_of: Dictionary = { }


static func phase_of(n: Object) -> int:
	return hash(n.get_instance_id()) & 1


static func full_rate(m: Object) -> bool:
	var id:= m.get_instance_id()
	var able = _rate_able.get(id)
	if able == null:
		able = m.has_method(&"full_rate")
		_rate_able [id] = able
	return able and m.full_rate()


static var _rate_able: Dictionary = { }


static var _frame_of: Dictionary = { }


static var _traits_of: Dictionary = { }
const T_PHASE:= 1
const T_RATE:= 2
const T_WAITS:= 4
const T_GAP_SHIFT:= 3


static func _traits(m: Object, id: int) -> int:
	var t:= phase_of(m)
	if m.has_method(&"full_rate"):
		t |= T_RATE
	if m.has_method(&"is_waiting"):
		t |= T_WAITS
	var gap:= int(m.step_gap_ticks()) if m.has_method(&"step_gap_ticks") else LONG_GAP
	t |= gap << T_GAP_SHIFT
	_traits_of [id] = t
	return t


func _physics_process(delta: float) -> void:
	_sweep_clock += delta
	if _sweep_clock >= SWEEP_EVERY:
		_sweep_clock = 0.0
		_sweep_owed = true
	var t0:= Time.get_ticks_usec()
	var run_us:= BeltRun.tick_usec
	BeltPath.tick_paths(delta)
	var t1:= Time.get_ticks_usec()


	HotSpots.add_usec(&"  of which run.tick", BeltRun.tick_usec - run_us)
	BeltPath.flush_runs()
	var t2:= Time.get_ticks_usec()
	_machines_owed += delta
	var frame:= Engine.get_process_frames()
	if stride > 1:


		var carried:= _machines_owed - delta
		_machines_owed = 0.0
		if carried > 0.0:
			for m in _machines:
				if is_instance_valid(m):
					var id: int = m.get_instance_id()
					_owed_by [id] = float(_owed_by.get(id, 0.0)) + carried
		if _sweep_owed:
			_sweep_owed = false
			_sweep_left = stride
		_tick_machines_strided(delta, _sweep_left > 0)
		_sweep_left -= 1
	elif not BeltPath.frame_tick_enabled or frame != _machines_frame or _machines_owed >= delta * 1.5:
		_machines_frame = frame
		var dt:= _machines_owed
		_machines_owed = 0.0
		var sweep:= _sweep_owed
		_sweep_owed = false
		_tick_machines(dt, sweep)
	else:
		last_called = 0
	last_runs_usec = t1 - t0
	last_flush_usec = t2 - t1
	last_machines_usec = Time.get_ticks_usec() - t2
	HotSpots.add_usec(&"tick belts move", last_runs_usec)
	HotSpots.add_usec(&"tick belts flush", last_flush_usec)
	HotSpots.add_usec(&"tick machines", last_machines_usec)


func _tick_machines(delta: float, sweep: bool) -> void:
	_walking = true
	var called:= 0
	var waiting:= 0
	var stale:= false
	var i:= 0
	while i < _machines.size():
		var m = _machines [i]
		i += 1
		if not is_instance_valid(m) or not (m as Node).is_inside_tree():
			stale = true
			continue
		if not m.is_physics_processing():
			continue


		if not sweep and m.has_method(&"is_waiting") and m.is_waiting():
			waiting += 1
			var id: int = m.get_instance_id()
			_owed_by [id] = float(_owed_by.get(id, 0.0)) + delta
			continue
		called += 1


		var dt:= delta
		if not _owed_by.is_empty():
			dt += float(_owed_by.get(m.get_instance_id(), 0.0))
			_owed_by.erase(m.get_instance_id())
		if profile:
			var t:= Time.get_ticks_usec()
			m.factory_tick(dt)
			prof_add("machine " + class_of(m), Time.get_ticks_usec() - t)
			continue
		m.factory_tick(dt)
	_walking = false
	last_called = called
	last_waiting = waiting
	for m in _joined:
		if not _machines.has(m):
			_machines.append(m)
	_joined.clear()
	for m in _left:
		_machines.erase(m)
	_left.clear()
	if stale:
		_drop_stale()


static func _drop_stale() -> void:
	var keep: Array = []
	var owed:= { }
	for m in _machines:
		if is_instance_valid(m) and (m as Node).is_inside_tree():
			keep.append(m)
			var id: int = m.get_instance_id()
			if _owed_by.has(id):
				owed [id] = _owed_by [id]
	_machines = keep


	_owed_by = owed
	_frame_of.clear()
	_rate_able.clear()
	_gap_of.clear()
	_traits_of.clear()


func _tick_machines_strided(delta: float, sweep: bool) -> void:
	_walking = true
	var called:= 0
	var waiting:= 0
	var stale:= false
	var now:= Engine.get_physics_frames()
	var frame:= Engine.get_process_frames()
	var frame_rule:= BeltPath.frame_tick_enabled


	var i:= 0
	while i < _machines.size():
		var m = _machines [i]
		i += 1
		if not is_instance_valid(m) or not (m as Node).is_inside_tree():
			stale = true
			continue
		if not m.is_physics_processing():
			continue
		var id: int = m.get_instance_id()
		var known = _traits_of.get(id)
		var bits: int = _traits(m, id) if known == null else known
		var dt: float = float(_owed_by.get(id, 0.0)) + delta


		if (bits & T_RATE) != 0 and m.full_rate():
			if frame_rule and dt < delta * 1.5 and int(_frame_of.get(id, -1)) == frame:
				_owed_by [id] = dt
				continue
		elif (now + (bits & T_PHASE)) % stride != 0 or (frame_rule and int(_frame_of.get(id, -1)) == frame and dt < delta * (float(bits >> T_GAP_SHIFT) - 0.5)):
			_owed_by [id] = dt
			continue
		if not sweep and (bits & T_WAITS) != 0 and m.is_waiting():
			waiting += 1
			_owed_by [id] = dt
			continue
		_owed_by.erase(id)
		_frame_of [id] = frame
		called += 1
		if profile:
			var t:= Time.get_ticks_usec()
			m.factory_tick(dt)
			prof_add("machine " + class_of(m), Time.get_ticks_usec() - t)
			continue
		m.factory_tick(dt)
	_walking = false
	last_called = called
	last_waiting = waiting
	for m in _joined:
		if not _machines.has(m):
			_machines.append(m)
	_joined.clear()
	for m in _left:
		_machines.erase(m)
	_left.clear()
	if stale:
		_drop_stale()


static func machine_census() -> Array [int]:
	var live:= 0
	for m in _machines:
		if is_instance_valid(m) and (m as Node).is_inside_tree():
			live += 1
	return [live, last_called, last_waiting]
