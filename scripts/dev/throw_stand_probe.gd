class_name DevThrowStandProbe
extends Node


var world: Node3D
var player: Node3D

const SETTLE:= 40

const WATCH_TICKS:= 1200


const QUIET_TICKS:= 120
const PER_THROW:= 3

var _fails:= 0
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var stand:= world.get("stand") as HaySellingStand
	var live:= world.get("live") as LiveStrandManager
	var belt:= stand.intake_path() if stand != null else null
	if stand == null or live == null or belt == null:
		_check("there is a selling stand with a belt", false)
		_finish()
		return
	_rng.seed = 24092026
	var knee:= float(belt._cum [1]) if belt._cum.size() > 2 else belt.path_length() * 0.3
	var slope:= lerpf(knee, belt.path_length(), 0.4)
	print("  stand belt %.2f m long, knee at %.2f, rail at +/- %.3f, lane +/- %.3f"
		% [belt.path_length(), knee, Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T, Cfg.BELT_RIDE_HALF_W])
	var inner:= Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T

	var spots:= [
		["tail, middle", 0.5, 0.0, 0.3, false],
		["tail, by the near rail", 0.5, inner - 0.03, 0.3, false],
		["tail, by the far rail", 0.5, - (inner - 0.03), 0.3, false],
		["knee, by the rail", knee, inner - 0.04, 0.3, false],
		["slope, by the rail", slope, - (inner - 0.04), 0.3, false],
		["on the near rail top", 0.6, Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T * 0.5,
			Cfg.BELT_RAIL_H + 0.12, false],
		["slope rail top", slope, Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T * 0.5,
			Cfg.BELT_RAIL_H + 0.12, false],
		["thrown across at the far rail", 0.7, - (inner - 0.05), 0.0, true],
		["thrown across onto the slope", slope, - (inner - 0.08), 0.0, true],
	]
	var old_left:= 0
	for spot: Array in spots:
		BeltPath.stand_keeps_straw = false
		var before:= await _throw(stand, live, belt, spot)
		BeltPath.stand_keeps_straw = true
		var after:= await _throw(stand, live, belt, spot)
		print("  %-32s old: %d of %d paid, %d lost, %d left lying | new: %d of %d paid, %d lost, %d left lying"
			% [spot [0], before ["paid"], PER_THROW, before ["lost"], before ["left"],
				after ["paid"], PER_THROW, after ["lost"], after ["left"]])
		old_left += PER_THROW - int(before ["paid"])
		_check("%s: all %d paid for (%d)" % [spot [0], PER_THROW, after ["paid"]],
			int(after ["paid"]) == PER_THROW and int(after ["left"]) == 0)
	print("  the old belt lost or left %d of %d" % [old_left, spots.size() * PER_THROW])
	_finish()


func _finish() -> void:
	print("\n[throwstand] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _throw(stand: HaySellingStand, live: LiveStrandManager, belt: BeltPath,
		spot: Array) -> Dictionary:
	var s: float = spot [1]
	var side: float = spot [2]
	var lift: float = spot [3]
	var thrown: bool = spot [4]
	var basis:= belt._basis_at(s)
	var target: Vector3 = belt._point_at(s) + basis.x * side + basis.y * lift
	player.global_position = belt._point_at(s) + basis.x * 3.0 + Vector3.DOWN * 0.5
	var bodies: Array [RigidBody3D] = []
	for i in PER_THROW:
		var at:= target + basis.z * (i - 1) * 0.12
		var vel:= Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
		if thrown:


			var from:= at + basis.x * 1.5 + Vector3.UP * 0.6
			var t:= 0.35
			vel = (at - from) / t
			vel.y += 9.8 * t * 0.5
			at = from
		var rot:= Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, deg_to_rad(90.0 + _rng.randf_range(-15.0, 15.0)))
		var b:= live.spawn(at, rot, vel, Color(0.85, 0.7, 0.35))
		if b != null:
			bodies.append(b)


	var seen:= { }
	var sold_was:= GameState.hay_sold
	var quiet:= 0
	for tick in WATCH_TICKS:
		await get_tree().physics_frame
		for b in bodies:
			if b.get_parent() == live and not seen.get(b.get_instance_id(), { }).get("gone", false):
				var near:= belt._nearest(b.global_position)
				seen [b.get_instance_id()] = { "at": b.global_position, "tick": tick,
					"s": float(near ["s"]), "side": float(near ["side"]), "lift": float(near ["lift"]),
					"rider": b.has_meta(LiveStrandManager.META_RIDER) }
		quiet = quiet + 1 if _in_world(live, bodies) == 0 and float(stand.get("_pending")) == 0.0 else 0
		if quiet >= QUIET_TICKS:
			break
	var left:= _in_world(live, bodies)
	var paid:= int(round(GameState.hay_sold - sold_was))
	for b in bodies:
		var last: Dictionary = seen.get(b.get_instance_id(), { })
		if b.get_parent() == live:
			print("      left at %.2v, rider %s, frozen %s" % [b.global_position,
				b.has_meta(LiveStrandManager.META_RIDER), b.freeze])
			BeltPath.release(b)
			live.fold_away(b)
		elif not last.is_empty() and paid < PER_THROW:
			print("      gone at tick %d from %.2v: s %.2f side %.3f lift %.3f rider %s"
				% [last ["tick"], last ["at"], last ["s"], last ["side"], last ["lift"], last ["rider"]])
	return { "paid": paid, "left": left, "lost": PER_THROW - paid - left }


func _in_world(live: LiveStrandManager, bodies: Array [RigidBody3D]) -> int:
	var n:= 0
	for b in bodies:
		if is_instance_valid(b) and b.get_parent() == live:
			n += 1
	return n


func _check(what: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1
