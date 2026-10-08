class_name SackFlyer
extends Node3D


const GRAVITY:= 9.81


const LOAD_WIDE:= 1.26
const LOAD_TALL:= 0.6


const LOAD_SINK:= 0.03


const SNAP:= 0.07


const STRETCH:= 0.015
const STRETCH_MAX:= 0.22


const WOBBLE_AMP:= 0.2
const WOBBLE_HZ:= 3.1
const WOBBLE_DECAY:= 3.2


const SPIN_RATE:= 5.4
const SPIN_DRAG:= 0.5


const SPIN_AXIS:= Vector3(1.0, 0.22, 0.3)


const POP:= 0.17

const STAR:= 0.34
const STAR_IN:= 0.09

enum { LOADING, FLYING, POPPING }

var _body: Node3D
var _star: Node3D
var _rest:= Transform3D.IDENTITY
var _state:= LOADING
var _clock:= 0.0
var _load_time:= 0.2
var _base_y:= 0.0
var _vel:= Vector3.ZERO
var _spin:= SPIN_RATE
var _orient:= Quaternion.IDENTITY
var _pop_from:= Vector3.ONE


func carry(model: Node3D, body: Node3D, star: Node3D, wind_up: float) -> void:
	add_child(model)
	_body = body
	_star = star
	_load_time = maxf(wind_up, 0.01)
	if _body != null:
		_rest = _body.transform
	if _star != null:
		_star.position = Vector3.ZERO
		_star.scale = Vector3.ZERO
	_base_y = position.y
	_state = LOADING
	_clock = 0.0
	_shape(1.0, 1.0)


func release(vel: Vector3) -> void:
	if _state != LOADING:
		return
	_vel = vel
	_state = FLYING
	_clock = 0.0
	_spin = SPIN_RATE


func _physics_process(delta: float) -> void:
	match _state:
		LOADING:
			_tick_load(delta)
		FLYING:
			_tick_flight(delta)
		POPPING:
			_tick_pop(delta)


func _tick_load(delta: float) -> void:
	_clock += delta
	var k:= clampf(_clock / _load_time, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	position.y = _base_y - LOAD_SINK * k
	_shape(lerpf(1.0, LOAD_WIDE, k), lerpf(1.0, LOAD_TALL, k))


func _tick_flight(delta: float) -> void:
	_clock += delta
	_vel.y -= GRAVITY * delta
	position += _vel * delta

	_spin *= exp(- SPIN_DRAG * delta)
	_orient = Quaternion(SPIN_AXIS.normalized(), _spin * delta) * _orient


	var tall:= 1.0 + clampf(_vel.y * STRETCH, - STRETCH_MAX, STRETCH_MAX) + WOBBLE_AMP * exp(- WOBBLE_DECAY * _clock) * sin(TAU * WOBBLE_HZ * _clock)
	tall = maxf(tall, 0.4)
	var wide:= 1.0 / sqrt(tall)


	if _clock < SNAP:
		var k:= _clock / SNAP
		wide = lerpf(LOAD_WIDE, wide, k)
		tall = lerpf(LOAD_TALL, tall, k)
	_shape(wide, tall)

	if _vel.y <= 0.0:
		_state = POPPING
		_clock = 0.0
		_pop_from = Vector3(wide, tall, wide)


func _tick_pop(delta: float) -> void:
	_clock += delta


	_vel.y -= GRAVITY * delta
	position += _vel * delta * 0.5

	var k:= clampf(_clock / POP, 0.0, 1.0)
	if k < 0.45:
		var a:= k / 0.45
		_shape(lerpf(_pop_from.x, 1.16, a), lerpf(_pop_from.y, 0.86, a))
	else:
		var a:= (k - 0.45) / 0.55
		_shape(lerpf(1.16, 0.02, a), lerpf(0.86, 0.02, a))

	if _star != null:
		var s:= _clock - STAR_IN
		if s > 0.0:
			_star.scale = Vector3.ONE * _twinkle(s / STAR)
			_star.rotate_y(1.6 * delta)

	if _clock >= STAR_IN + STAR:
		queue_free()


func _twinkle(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.3:
		return lerpf(0.0, 1.3, t / 0.3)
	if t < 0.5:
		return lerpf(1.3, 0.85, (t - 0.3) / 0.2)
	return lerpf(0.85, 0.0, (t - 0.5) / 0.5)


func _shape(wide: float, tall: float) -> void:
	if _body == null:
		return
	_body.transform = Transform3D(
		Basis(_orient) * _rest.basis * Basis.from_scale(Vector3(wide, tall, wide)),
		_rest.origin)
