class_name Jetpack
extends RefCounted


var player: Player


var _latched:= false
var _thrusting:= false

var _grounded_for:= 0.0

var _voice:= -1


const THRUST_DB:= -12.0


func owned() -> bool:
	return Tech.has_jetpack()


func fuel() -> float:
	return GameState.jetpack_fuel


func fraction() -> float:
	return clampf(GameState.jetpack_fuel / Cfg.JETPACK_TANK_SECONDS, 0.0, 1.0)


func is_full() -> bool:
	return GameState.jetpack_fuel >= Cfg.JETPACK_TANK_SECONDS - 0.001


func is_thrusting() -> bool:
	return _thrusting


func is_recharging() -> bool:
	return owned() and not is_full() and _grounded_for >= Cfg.JETPACK_RECHARGE_DELAY


func can_refill() -> bool:
	return owned() and not is_full()


func refill() -> void:
	GameState.jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	Audio.play("jetpack_refuel", -4.0)


func wants_thrust(on_floor: bool, jump_held: bool, blocked: bool) -> bool:
	if not jump_held:
		_latched = false
	elif on_floor or blocked:
		_latched = true
	var want:= jump_held and not on_floor and not _latched and not blocked and owned() and GameState.jetpack_fuel > 0.0
	_set_thrusting(want)
	return want


func lift(vy: float, delta: float) -> float:
	GameState.jetpack_fuel = maxf(0.0, GameState.jetpack_fuel - delta)
	if vy < Cfg.JETPACK_CLIMB_MAX:
		vy = minf(vy + Cfg.JETPACK_THRUST * delta, Cfg.JETPACK_CLIMB_MAX)
	return vy


func tick(delta: float, on_floor: bool) -> void:
	if on_floor:
		_grounded_for += delta
	else:
		_grounded_for = 0.0
	if on_floor and owned() and not is_full() and _grounded_for >= Cfg.JETPACK_RECHARGE_DELAY:
		GameState.jetpack_fuel = minf(Cfg.JETPACK_TANK_SECONDS, GameState.jetpack_fuel
			+ Cfg.JETPACK_TANK_SECONDS / Cfg.JETPACK_RECHARGE_SECONDS * delta)
	if _voice >= 0 and player != null:
		Audio.loop_update(_voice, player.global_position, THRUST_DB)


func stop() -> void:
	_set_thrusting(false)


func _set_thrusting(on: bool) -> void:
	if on == _thrusting:
		return
	_thrusting = on
	if on:
		Audio.play("jetpack_start", -6.0)
		if _voice < 0:
			_voice = Audio.loop_acquire("jetpack_thrust")
	else:
		if _voice >= 0:
			Audio.loop_release(_voice)
			_voice = -1
		Audio.play("jetpack_stop", -8.0)
