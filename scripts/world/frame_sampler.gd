class_name FrameSampler
extends Node


signal finished

const FRAMES:= 180
const SKIP:= 10

var _vp_rid:= RID()
var _measuring_render:= false
var _skip:= SKIP

var _frame_start:= 0
var _proc_end:= 0
var _tick_start:= 0
var _cb_end:= 0
var _tick_open:= false

var _cur:= { }
var _frames: Array [Dictionary] = []
var _prof_ticks_from:= 0


var _stride_ticks:= { }


func _init() -> void:
	name = "FrameSampler"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 2147483000
	process_physics_priority = 2147483000


func _ready() -> void:
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_measuring_render = true
	get_tree().physics_frame.connect(_on_physics_frame)
	get_tree().process_frame.connect(_on_process_frame)
	_cur = _blank()


func _blank() -> Dictionary:
	return { "ticks": 0, "cb": 0, "step": 0, "proc": 0, "other": 0, "frame": 0 }


func _on_physics_frame() -> void:
	var t:= Time.get_ticks_usec()
	if _tick_open:
		_cur ["step"] += t - _cb_end
	elif _proc_end > 0:
		_cur ["other"] += t - _proc_end
		_proc_end = 0
	_tick_start = t
	_cb_end = t
	_tick_open = true
	_cur ["ticks"] += 1


func _physics_process(_delta: float) -> void:
	if not _tick_open:
		return
	var t:= Time.get_ticks_usec()
	_cur ["cb"] += t - _tick_start
	_stride_ticks [FactoryClock.stride] = int(_stride_ticks.get(FactoryClock.stride, 0)) + 1
	_cb_end = t


func _on_process_frame() -> void:
	var t:= Time.get_ticks_usec()
	if _tick_open:
		_cur ["step"] += t - _cb_end
		_tick_open = false
	elif _proc_end > 0:
		_cur ["other"] += t - _proc_end
		_proc_end = 0
	if _frame_start > 0:
		_cur ["frame"] = t - _frame_start
		_close_frame()
	_frame_start = t


const NO_CLOCK_PROFILE_FLAG:= "--noprof"
static var no_clock_profile: bool = NO_CLOCK_PROFILE_FLAG in OS.get_cmdline_user_args()


func _process(_delta: float) -> void:
	if _frame_start == 0:
		return
	var t:= Time.get_ticks_usec()
	_cur ["proc"] = t - _frame_start
	_proc_end = t


func _close_frame() -> void:
	var row:= _cur
	_cur = _blank()
	if _skip > 0:
		_skip -= 1
		if _skip == 0:
			FactoryClock.prof.clear()
			FactoryClock.profile = not no_clock_profile
			HotSpots.start()
			_prof_ticks_from = Engine.get_physics_frames()
		return
	_frames.append(row)
	if _frames.size() >= FRAMES:
		set_process(false)
		set_physics_process(false)
		get_tree().physics_frame.disconnect(_on_physics_frame)
		get_tree().process_frame.disconnect(_on_process_frame)
		finished.emit()


func report() -> PackedStringArray:
	var lines:= PackedStringArray()
	var ticks_sampled:= maxi(1, Engine.get_physics_frames() - _prof_ticks_from)
	FactoryClock.profile = false
	HotSpots.stop()
	var n:= _frames.size()
	lines.append("[frame timing] %d frames measured after the shot" % n)
	lines.append("render thread   = %s (chosen %s)" % [
		"on" if Cfg.running_render_thread() else "off",
		Cfg.RENDER_THREAD_NAMES [Cfg.render_thread]])
	lines.append("physics         = %d Hz, at most %d ticks a frame" % [
		Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])
	lines.append(_stride_line())
	lines.append("window        = %v, render scale %.2f, vsync %d, max_fps %d" % [
		get_viewport().get_visible_rect().size, get_viewport().scaling_3d_scale,
		DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	if n == 0:
		_stop_render_measure()
		return lines

	var frame_ms: Array [float] = []
	var sums:= { "cb": 0.0, "step": 0.0, "proc": 0.0, "other": 0.0, "frame": 0.0 }
	var by_ticks:= { }
	var ticks_total:= 0
	for row in _frames:
		frame_ms.append(row ["frame"] / 1000.0)
		for k in sums:
			sums [k] += row [k] / 1000.0
		var tk:= mini(int(row ["ticks"]), 3)
		by_ticks [tk] = int(by_ticks.get(tk, 0)) + 1
		ticks_total += int(row ["ticks"])
	frame_ms.sort()
	var median:= frame_ms [n / 2]
	var p90:= frame_ms [mini(n - 1, int(n * 0.9))]
	var mean:= float(sums ["frame"]) / n
	lines.append("frame           = median %.2f ms (%d fps), mean %.2f ms, p90 %.2f, worst %.2f" % [
		median, int(round(1000.0 / maxf(median, 0.01))), mean, p90, frame_ms [n - 1]])
	var spread:= PackedStringArray()
	for tk in [0, 1, 2, 3]:
		if by_ticks.has(tk):
			spread.append("%s ticks in %d%%" % ["3+" if tk == 3 else str(tk),
				int(round(100.0 * by_ticks [tk] / n))])
	lines.append("physics ticks   = %.2f a frame: %s" % [float(ticks_total) / n, ", ".join(spread)])
	lines.append("a frame (mean)  = physics scripts %.2f + physics step and signals %.2f + process scripts %.2f + render hand off and other %.2f ms" % [
		sums ["cb"] / n, sums ["step"] / n, sums ["proc"] / n, sums ["other"] / n])
	if ticks_total > 0:
		lines.append("a tick (mean)   = scripts %.2f + step and signals %.2f ms" % [
			sums ["cb"] / ticks_total, sums ["step"] / ticks_total])


	var tick_named:= HotSpots.total_ms("tick ", n)
	var frame_named:= HotSpots.total_ms("frame ", n)
	lines.append("named systems   = physics scripts %.2f named, %.2f unnamed; process scripts %.2f named, %.2f unnamed (ms a frame)" % [
		tick_named, sums ["cb"] / n - tick_named, frame_named, sums ["proc"] / n - frame_named])
	lines.append_array(HotSpots.lines(n))

	lines.append("render          = CPU %.2f ms, GPU %.2f ms (last frame)" % [
		RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid),
		RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)])
	_stop_render_measure()
	lines.append("draws           = %d draw calls, %d objects, %dk primitives" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000)])
	lines.append("engine monitors = process %.2f ms, physics %.2f ms, nodes %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


	var keys: Array = FactoryClock.prof.keys()
	keys.sort_custom(func(a, b) -> bool:
		return int(FactoryClock.prof [a] [0]) > int(FactoryClock.prof [b] [0]))
	var clock_total:= 0.0
	for key in keys:
		clock_total += float(FactoryClock.prof [key] [0])
	lines.append("factory clock   = %.2f ms a tick over %d ticks, costliest:" % [
		clock_total / 1000.0 / ticks_sampled, ticks_sampled])
	for i in mini(10, keys.size()):
		var row: Array = FactoryClock.prof [keys [i]]
		lines.append("    %-44s %.3f ms a tick, %d calls a tick" % [
			keys [i], float(row [0]) / 1000.0 / ticks_sampled, int(row [1]) / ticks_sampled])
	FactoryClock.prof.clear()
	return lines


func _stride_line() -> String:
	var total:= 0
	for s: int in _stride_ticks:
		total += int(_stride_ticks [s])
	var parts:= PackedStringArray()
	var keys:= _stride_ticks.keys()
	keys.sort()
	keys.reverse()
	for s: int in keys:
		var why:= ""
		if s == 1:
			why = ", pinned by --factory60"
		parts.append("%d (%d Hz%s) in %d%% of ticks" % [s,
			Engine.physics_ticks_per_second / maxi(1, s), why,
			roundi(100.0 * _stride_ticks [s] / maxi(1, total))])
	if parts.is_empty():
		return "factory stride  = %d, no ticks measured" % FactoryClock.stride
	return "factory stride  = " + ", ".join(parts)


func _stop_render_measure() -> void:
	if _measuring_render:
		RenderingServer.viewport_set_measure_render_time(_vp_rid, false)
		_measuring_render = false


func _exit_tree() -> void:
	FactoryClock.profile = false
	_stop_render_measure()
