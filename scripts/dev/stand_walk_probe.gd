class_name DevStandWalkProbe
extends Node


const PLUCK_S:= 0.25

const THROW_REACH:= 5.0

const DUMP_REACH:= 3.0

const POUR_REACH:= 1.5

const DIG_STAND:= 1.5

const SWING_S:= 0.45


const BLADE_DUMP_S:= 0.6
const CONTAINER_HANDLING_S:= 2.0
const POUR_AIM_S:= 1.0


const SPADE_BITE:= 54
const SPADE_BLADE:= SPADE_BITE * Shovel.LOAD_BITES
const TOY_BITE:= 18
const TOY_BLADE:= TOY_BITE * Shovel.LOAD_BITES

var _world: Node


func run() -> void:
	_world = get_parent()
	for i in 10:
		await get_tree().physics_frame
	var stand: HaySellingStand = _world.stand
	var field: HayField = _world.field
	var tail: Vector3 = stand.to_global(stand._belt_tail)
	var flat:= Vector2(tail.x, tail.z)
	var dir:= flat.normalized()
	var edge:= _edge(field, dir)
	print("[standwalk] stand at (%.2f, %.2f), intake tail at (%.2f, %.2f), %.2f m from the pile centre"
		% [stand.global_position.x, stand.global_position.z, tail.x, tail.z, flat.length()])
	print("[standwalk] hay edge on that line at %.2f m, so the tail is %.2f m past it"
		% [edge, flat.length() - edge])
	for dug: float in [0.0, 3.0, 6.0]:
		var from_edge:= flat.length() - (edge - dug) - DIG_STAND
		_report(dug, from_edge)
	print("\n[standwalk] PASS")
	get_tree().quit(0)


func _edge(field: HayField, dir: Vector2) -> float:
	var r:= 0.0
	while r < 40.0:
		var p:= dir * r
		if field.height_at(p.x, p.y) < 0.05:
			return r
		r += 0.05
	return r


func _report(dug: float, d: float) -> void:
	var price:= Tech.hay_price()
	print("\n  pile dug back %.0f m: %.1f m from where you dig to the intake tail" % [dug, d])
	print("    %-26s %8s %8s %9s %8s" % ["way of carrying", "strands", "trip s", "$/min", "x hand5"])
	var rows: Array = []
	for rank: int in [0, 5, 9]:
		rows.append(["bare hand, %d straw%s" % [1 + rank, "" if rank == 0 else "s"],
			_hand(1 + rank, d)])
	rows.append(["toy shovel, blade only", _blade(TOY_BITE, TOY_BLADE, d)])
	rows.append(["spade, blade only", _blade(SPADE_BITE, SPADE_BLADE, d)])
	rows.append(["spade into bucket", _container(Cfg.BUCKET_CAPACITY, Cfg.BUCKET_POUR_RATE, d)])
	rows.append(["spade into barrow", _container(Cfg.BARROW_CAPACITY, Cfg.BARROW_POUR_RATE, d)])
	var hand5: float = rows [1] [1].y / rows [1] [1].x
	for row: Array in rows:
		var trip: Vector2 = row [1]
		var per_s:= trip.y / trip.x
		print("    %-26s %8d %8.1f %9s %7.1fx" % [row [0], int(trip.y), trip.x,
			"$%.2f" % (per_s * price * 60.0), per_s / hand5])


func _hand(n: int, d: float) -> Vector2:
	var walk:= maxf(0.0, d - THROW_REACH)
	return Vector2(n * PLUCK_S + 2.0 * walk / Player.SPEED + 0.3, n)


func _blade(bite: int, blade: int, d: float) -> Vector2:
	var bites:= ceili(float(blade) / bite)
	var walk:= maxf(0.0, d - DUMP_REACH)
	var t_walk:= 2.0 * walk / Player.SPEED
	return Vector2(_dig_time(bites, t_walk) + t_walk + BLADE_DUMP_S, blade)


func _container(cap: int, pour_rate: float, d: float) -> Vector2:
	var bites:= ceili(float(cap) / SPADE_BITE)
	var dumps:= ceili(float(cap) / SPADE_BLADE)
	var walk:= maxf(0.0, d - POUR_REACH)
	var t_walk:= 2.0 * walk / Player.SPEED
	var t:= _dig_time(bites, t_walk) + dumps * BLADE_DUMP_S
	t += CONTAINER_HANDLING_S + t_walk + POUR_AIM_S + cap / pour_rate
	return Vector2(t, cap)


func _dig_time(bites: int, rest: float) -> float:
	var bank:= minf(Stamina.BASE_MAX, maxf(0.0, rest - Stamina.REGEN_DELAY) * Stamina.REGEN)
	var free:= mini(bites, int(bank / Stamina.DIG_COST))
	var slow:= bites - free


	var per_slow:= Stamina.DIG_COST / (Stamina.REGEN * Stamina.REST_BONUS) + Stamina.REGEN_DELAY
	return free * SWING_S + slow * maxf(SWING_S, per_slow)
