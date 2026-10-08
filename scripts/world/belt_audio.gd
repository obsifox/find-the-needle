class_name BeltAudio
extends Node


const AUDIBLE:= 4

const RANGE:= 20.0


const RESORT_INTERVAL:= 0.4

const BELT_VOLUME_DB:= -13.0
const SILENT_DB:= -80.0


const RAMP_DB:= 90.0

var builds: BuildManager
var player: Player


var _voice: Dictionary = { }
var _belt: Dictionary = { }
var _gain: Dictionary = { }
var _target: Dictionary = { }

var _resort_left:= 0.0


const RANK_SLICE:= 8


var _rank_at:= -1
var _best: Array = []
var _best_d:= PackedFloat32Array()


func _process(delta: float) -> void:
	if builds == null or player == null:
		return
	var ear:= player.eye_position()

	_resort_left -= delta
	if _resort_left <= 0.0 and _rank_at < 0:
		_resort_left = RESORT_INTERVAL
		_rank_at = 0
		_best.clear()
		_best_d.clear()
	if _rank_at >= 0:
		_rank_step(ear)

	for id: int in _voice.keys():


		var candidate: Variant = _belt.get(id)
		if not is_instance_valid(candidate):
			_drop(id)
			continue
		var c:= candidate as Conveyor
		var g: float = move_toward(_gain [id], _target [id], RAMP_DB * delta)
		_gain [id] = g
		if g <= SILENT_DB + 0.5 and _target [id] <= SILENT_DB:
			_drop(id)
			continue


		var detune:= 0.94 + float(id % 13) * 0.01
		Audio.loop_update(_voice [id], _nearest_point(c, ear), g, detune)


func _rank_step(ear: Vector3) -> void:
	var list:= builds.conveyors
	var n:= list.size()
	var end:= mini(n, _rank_at + maxi(16, ceili(float(n) / RANK_SLICE)))
	for i in range(_rank_at, end):
		var candidate: Variant = list [i]
		if not is_instance_valid(candidate):
			continue
		var c:= candidate as Conveyor
		var d:= _nearest_point(c, ear).distance_to(ear)
		if d > RANGE or (_best.size() >= AUDIBLE and d >= _best_d [AUDIBLE - 1]):
			continue
		var at:= _best.size()
		while at > 0 and _best_d [at - 1] > d:
			at -= 1
		_best.insert(at, c)
		_best_d.insert(at, d)
		if _best.size() > AUDIBLE:
			_best.resize(AUDIBLE)
			_best_d.resize(AUDIBLE)
	_rank_at = end
	if end < n:
		return
	_rank_at = -1
	_rank()


func _rank() -> void:
	var want: Dictionary = { }
	for candidate: Variant in _best:
		if is_instance_valid(candidate):
			want [(candidate as Object).get_instance_id()] = candidate
	_best.clear()
	_best_d.clear()

	for id: int in _voice.keys():
		_target [id] = BELT_VOLUME_DB if want.has(id) else SILENT_DB

	for id: int in want.keys():
		if _voice.has(id):
			continue
		var h:= Audio.loop_acquire("belt")
		if h < 0:
			continue
		_voice [id] = h
		_belt [id] = want [id]
		_gain [id] = SILENT_DB
		_target [id] = BELT_VOLUME_DB


func _drop(id: int) -> void:
	Audio.loop_release(_voice [id])
	_voice.erase(id)
	_belt.erase(id)
	_gain.erase(id)
	_target.erase(id)


func _nearest_point(c: Conveyor, p: Vector3) -> Vector3:
	var a:= c.laid_start()
	var b:= c.laid_end()
	var ab:= b - a
	var len2:= ab.length_squared()
	if len2 < 1e-06:
		return a
	return a + ab * clampf((p - a).dot(ab) / len2, 0.0, 1.0)


func clear() -> void:
	for id: int in _voice.keys():
		Audio.loop_release(_voice [id])
	_voice.clear()
	_belt.clear()
	_gain.clear()
	_target.clear()
