class_name StepEase
extends Node


var part: Node3D
var _to:= 0.0
var _speed:= 0.0
var _moving:= false


static func attach(target: Node3D) -> StepEase:
	var e:= StepEase.new()
	e.name = "StepEase"
	e.part = target
	target.add_child(e)
	return e


func _ready() -> void:

	set_process(_moving)


func go(angle: float) -> void:
	if part == null:
		return
	_to = angle
	var gap:= absf(angle - part.rotation.y)
	if FactoryClock.stride <= 1 or not is_inside_tree() or gap < 0.0001:
		part.rotation.y = angle
		_moving = false
		set_process(false)
		return

	_speed = gap * float(Engine.physics_ticks_per_second) / float(FactoryClock.stride)
	_moving = true
	set_process(true)


func _process(delta: float) -> void:
	if part == null or not _moving:
		_moving = false
		set_process(false)
		return
	var y:= move_toward(part.rotation.y, _to, _speed * delta)
	part.rotation.y = y
	if y == _to:
		_moving = false
		set_process(false)
