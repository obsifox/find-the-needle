class_name Stamina
extends RefCounted


const BASE_MAX:= 100.0


const DIG_COST:= 12.0


const SPRINT_DRAIN:= 12.0

const REGEN:= 22.0

const REST_BONUS:= 1.5

const REST_SPEED:= 0.4


const REGEN_DELAY:= 0.55


const SPRINT_FLOOR:= 0.15


const SPRINT_EMPTY:= 0.0


const EXTRA_LIFE_RUSH:= 10.0


const RUSH_JUMP_HEIGHT:= 3.0

const RUSH_SPEED:= 1.5

const EXTRA_LIFE_GLOW:= EXTRA_LIFE_RUSH

var current:= BASE_MAX

var glow:= 0.0

var rush:= 0.0
var _quiet:= 0.0


var _sprint_locked:= false


var ran_dry:= 0


var ran_low:= 0
var low_msec:= -1
var _low_latched:= false


const LOW:= 0.2
const LOW_REARM:= 0.4


func maximum() -> float:
	return BASE_MAX * Tech.stamina_scale()


func fraction() -> float:
	var m:= maximum()
	return clampf(current / m, 0.0, 1.0) if m > 0.0 else 0.0


func can_afford(amount: float) -> bool:
	return rush > 0.0 or current >= amount


func dig_cost() -> float:
	return DIG_COST * Tech.dig_effort_scale()


func spend_dig() -> bool:
	return spend(dig_cost())


func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if rush > 0.0:
		return true
	if current < amount:
		return false
	current -= amount
	_quiet = 0.0
	return true


func sprint_allowed(wants: bool, already: bool) -> bool:
	if not wants:
		_sprint_locked = false
		return false
	if rush > 0.0:
		_sprint_locked = false
		return true
	if _sprint_locked:
		return false
	if current <= maximum() * SPRINT_EMPTY:
		_sprint_locked = true
		ran_dry += 1
		return false
	if not already and current < maximum() * SPRINT_FLOOR:
		return false
	return true


func tick(delta: float, sprinting: bool, speed: float) -> void:
	if delta <= 0.0:
		return
	_watch_low()
	glow = maxf(0.0, glow - delta)
	if rush > 0.0:
		rush = maxf(0.0, rush - delta)

		current = maximum()
		return
	if sprinting and speed > REST_SPEED:
		current = maxf(0.0, current - SPRINT_DRAIN * delta)
		_quiet = 0.0
		return
	_quiet += delta
	if _quiet < REGEN_DELAY:
		return
	var rate:= REGEN * Tech.stamina_regen_scale()
	if speed <= REST_SPEED:
		rate *= REST_BONUS
	current = minf(maximum(), current + rate * delta)


func _watch_low() -> void:
	var f:= fraction()
	if _low_latched:
		if f > LOW_REARM:
			_low_latched = false
		return
	if f < LOW and rush <= 0.0:
		_low_latched = true
		ran_low += 1
		low_msec = Time.get_ticks_msec()


func since_low() -> float:
	if low_msec < 0:
		return INF
	return float(Time.get_ticks_msec() - low_msec) / 1000.0


func refill() -> void:
	current = maximum()


func extra_life() -> void:
	refill()
	rush = EXTRA_LIFE_RUSH
	glow = EXTRA_LIFE_GLOW


func rushing() -> bool:
	return rush > 0.0


func jump_scale() -> float:
	return sqrt(RUSH_JUMP_HEIGHT) if rush > 0.0 else 1.0


func speed_scale() -> float:
	return RUSH_SPEED if rush > 0.0 else 1.0


func clamp_to_max() -> void:
	current = minf(current, maximum())
