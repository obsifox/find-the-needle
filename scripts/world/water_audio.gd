class_name WaterAudio
extends Node


const AUDIBLE:= 2


const RANGE:= 14.0
const RESORT_INTERVAL:= 0.4


const WATER_DB:= -17.0


const FLOW_SAG:= 9.0


const FLOW_FLOOR:= 0.02
const SILENT_DB:= -80.0
const RAMP_DB:= 90.0

var builds: BuildManager
var player: Player


var _voice: Dictionary = { }
var _run: Dictionary = { }
var _gain: Dictionary = { }
var _target: Dictionary = { }

var _resort_left:= 0.0


const RANK_SLICE:= 8
var _rank_at:= -1
var _near_run: Dictionary = { }
var _near_d: Dictionary = { }


func _process(delta: float) -> void:
	if builds == null or builds.water == null or player == null:
		return
	var ear:= player.eye_position()

	_resort_left -= delta
	if _resort_left <= 0.0 and _rank_at < 0:
		_resort_left = RESORT_INTERVAL
		_rank_at = 0
		_near_run.clear()
		_near_d.clear()
	if _rank_at >= 0:
		_rank_step(ear)

	for id: int in _voice.keys():


		var candidate: Variant = _run.get(id)
		if not is_instance_valid(candidate):
			_drop(id)
			continue
		var run:= candidate as WaterMain
		var g: float = move_toward(_gain [id], _target [id], RAMP_DB * delta)
		_gain [id] = g
		if g <= SILENT_DB + 0.5 and _target [id] <= SILENT_DB:
			_drop(id)
			continue
		Audio.loop_update(_voice [id], _nearest_point(run, ear), g,
			MachinePower.loop_pitch(_flow(run)))


func _rank_step(ear: Vector3) -> void:
	var grid:= builds.water
	var list:= builds.water_mains
	var n:= list.size()
	var end:= mini(n, _rank_at + maxi(16, ceili(float(n) / RANK_SLICE)))
	for i in range(_rank_at, end):
		var candidate: Variant = list [i]
		if not is_instance_valid(candidate):
			continue
		var run:= candidate as WaterMain
		var d:= _nearest_point(run, ear).distance_to(ear)
		if d > RANGE:
			continue
		var net:= grid.network_of(run)
		if net < 0:
			continue
		if not _near_d.has(net) or d < float(_near_d [net]):
			_near_run [net] = run
			_near_d [net] = d
	_rank_at = end
	if end < n:
		return
	_rank_at = -1
	_rank()


func _rank() -> void:


	var ranked: Array = []
	for net: int in _near_d.keys():
		if is_instance_valid(_near_run [net]):
			ranked.append(net)
	ranked.sort_custom(func(a, b): return float(_near_d [a]) < float(_near_d [b]))

	var want: Dictionary = { }
	for i in mini(AUDIBLE, ranked.size()):
		var run:= _near_run [ranked [i]] as WaterMain


		if _flow(run) <= FLOW_FLOOR:
			continue
		want [run.get_instance_id()] = run

	for id: int in _voice.keys():


		var candidate: Variant = _run.get(id)
		if not is_instance_valid(candidate):
			_target [id] = SILENT_DB
			continue
		_target [id] = _level(candidate as WaterMain) if want.has(id) else SILENT_DB

	for id: int in want.keys():
		if _voice.has(id):
			continue
		var h:= Audio.loop_acquire("water_flow")
		if h < 0:
			continue
		_voice [id] = h
		_run [id] = want [id]
		_gain [id] = SILENT_DB
		_target [id] = _level(want [id])


func _drop(id: int) -> void:
	Audio.loop_release(_voice [id])
	_voice.erase(id)
	_run.erase(id)
	_gain.erase(id)
	_target.erase(id)


func _flow(run: WaterMain) -> float:
	return 0.0 if not is_instance_valid(run) else run.flow


func _level(run: WaterMain) -> float:
	return WATER_DB - FLOW_SAG * (1.0 - clampf(_flow(run), 0.0, 1.0))


func _nearest_point(run: WaterMain, p: Vector3) -> Vector3:
	var a:= run.laid_start()
	var b:= run.laid_end()
	var ab:= b - a
	var len2:= ab.length_squared()
	if len2 < 1e-06:
		return a
	return a + ab * clampf((p - a).dot(ab) / len2, 0.0, 1.0)


func clear() -> void:
	for id: int in _voice.keys():
		Audio.loop_release(_voice [id])
	_voice.clear()
	_run.clear()
	_gain.clear()
	_target.clear()
