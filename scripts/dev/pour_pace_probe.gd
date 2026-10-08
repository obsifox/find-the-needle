class_name DevPourPaceProbe
extends Node


var world: Node3D
var player: Node3D

const SETTLE:= 40

const POUR_TICKS:= 2400

const QUIET_TICKS:= 120

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var stand:= world.get("stand") as HaySellingStand
	if stand == null:
		_check("there is a selling stand", false)
		_finish()
		return
	BeltPath.debug_props = true
	for id: String in ["bucket", "wheelbarrow"]:
		var loose:= await _pour(stand, id, false, false, false)
		var held:= await _pour(stand, id, true, false, false)
		print("  %s loose: %d over the rail, %.0f of %d sold, empty at %.1f s"
			% [id, loose ["bounced"], loose ["sold"], loose ["full"], loose ["empty_s"]])
		print("  %s held:  %d over the rail, %.0f of %d sold, empty at %.1f s"
			% [id, held ["bounced"], held ["sold"], held ["full"], held ["empty_s"]])
		_check("%s held: nothing kicked over the rail (%d)" % [id, held ["bounced"]],
			int(held ["bounced"]) == 0)
		_check("%s held: the till paid for nearly all of it (%.0f of %d)"
			% [id, held ["sold"], held ["full"]], float(held ["sold"]) >= float(held ["full"]) * 0.95)
		_check("%s held: it empties (%.1f s)" % [id, held ["empty_s"]], float(held ["empty_s"]) > 0.0)

		var shut:= await _pour(stand, id, true, true, false)
		print("  %s held over a shut belt: %d over the rail, %d of %d still in it, badge %s"
			% [id, shut ["bounced"], shut ["left"], shut ["full"], shut ["badge"]])
		_check("%s shut: nothing kicked over the rail (%d)" % [id, shut ["bounced"]],
			int(shut ["bounced"]) == 0)
		_check("%s shut: it kept its hay (%d of %d)" % [id, shut ["left"], shut ["full"]],
			int(shut ["left"]) > 0)
		_check("%s shut: it said NO ROOM" % id, bool(shut ["badge"]))

		var floor_loose:= await _pour(stand, id, false, false, true)
		var floor_held:= await _pour(stand, id, true, false, true)
		print("  %s over the floor: loose empty at %.1f s, held at %.1f s"
			% [id, floor_loose ["empty_s"], floor_held ["empty_s"]])
		_check("%s floor: held pours as fast as loose (%.1f s against %.1f s)"
			% [id, floor_held ["empty_s"], floor_loose ["empty_s"]],
			float(floor_held ["empty_s"]) > 0.0
			and float(floor_held ["empty_s"]) <= float(floor_loose ["empty_s"]) + 0.1)
	_finish()


func _finish() -> void:
	print("\n[pourpace] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _pour(stand: HaySellingStand, id: String, held: bool, shut: bool,
		on_floor: bool) -> Dictionary:
	var forward:= stand.intake_forward()
	var at:= stand.belt_entry_point()
	var side:= stand.global_basis.z.normalized()
	if on_floor:
		at += side * 3.0
	var pour_xf:= Transform3D(Basis(Vector3.UP, atan2(forward.x, forward.z))
		* Basis(Vector3.RIGHT, deg_to_rad(110.0)), at + forward * 0.2 + Vector3.UP * 0.9)
	player.global_position = Vector3(at.x, stand.global_position.y + 0.2, at.z) + side * 5.0
	var belt:= stand.get_node_or_null("StandBelt") as BeltPath
	if belt == null:
		belt = stand.get("_belt") as BeltPath
	if shut and belt != null:
		belt.set_outlet_held(true)
	var box:= world.props.spawn(id, Transform3D(Basis.IDENTITY, at + side * 2.0 + Vector3.UP * 0.1)) as HayContainer
	for i in 20:
		await get_tree().physics_frame
	box.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	box.freeze = true
	box.warp(pour_xf)
	box.set("_held", held)
	box.stored = box.capacity()
	box._refresh_fill()
	var full:= box.stored
	var money_was:= GameState.money
	var bounced:= { }
	var badge:= false
	var empty_at:= -1
	var last:= GameState.money
	var quiet:= 0
	for tick in range(1, POUR_TICKS + 1):
		await get_tree().physics_frame
		for t in HayTuft.all:
			if is_instance_valid(t) and t.has_meta(BeltPath.META_QUEUE_BOUNCE) and not bounced.has(t.get_instance_id()):
				bounced [t.get_instance_id()] = true
				print("    tick %d: %s kicked over the rail at %.2v, refused '%s', riders %s" % [tick, t.name,
					t.global_position, BeltPath.debug_last_refusal.get(t.get_instance_id(), ""),
					str(belt._riders.map(func(r): return "%s@%.2f" % [(r.body as Node).name if is_instance_valid(r.body) else "?", r.s]))])
		var mark:= box.get_node_or_null("FullBadge") as FullBadge
		if mark != null and mark._word == FullBadge.NO_ROOM and mark.is_processing():
			badge = true
		if empty_at < 0 and box.stored <= 0:
			empty_at = tick
		if shut:
			continue
		if is_equal_approx(GameState.money, last):
			quiet += 1
		else:
			quiet = 0
			last = GameState.money
		var belt_empty:= belt == null or (belt._riders.is_empty() and belt.run.count() == 0)
		if box.stored <= 0 and (on_floor or (belt_empty and quiet >= QUIET_TICKS)):
			break
	var out:= {
		"full": full,
		"left": box.stored,
		"bounced": bounced.size(),
		"sold": (GameState.money - money_was) / maxf(Tech.hay_price(), 0.0001),
		"empty_s": float(empty_at) / 60.0 if empty_at > 0 else -1.0,
		"badge": badge,
	}
	if shut and belt != null:
		belt.set_outlet_held(false)
	box.set("_held", false)
	world.props.remove(box)

	for t in HayTuft.all.duplicate():
		if is_instance_valid(t):
			BeltPath.release(t)
			world.props.remove(t)
	for i in 60:
		await get_tree().physics_frame
	return out


func _check(what: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1
