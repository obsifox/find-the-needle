class_name DevVacPourProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 40

const POUR_TICKS:= 3600

const QUIET_TICKS:= 150

const BUSY_HELD:= 300

var _fails:= 0
var _pin:= Vector3.INF
var _sold:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	Tech.grant_legacy()
	Tech.grant("yard_vac", 1)
	GameState.grant_tool("yard_vac")
	var stand:= world.get("stand") as HaySellingStand
	if stand == null:
		_check("there is a selling stand", false)
		_finish()
		return
	stand.sold.connect(func(n: int, _amount: float) -> void: _sold += n)

	if "tipper" in OS.get_cmdline_user_args():
		var only:= await _hatch_case(stand)
		print("  tipper: %s" % str(only))
		_finish()
		return

	for top in [false, true]:
		Tech.grant("vac_bin", TechTree.max_rank("vac_bin") if top else 0)
		var tag:= "top bin" if top else "base bin"
		print("\n=== %s, %d strands ===" % [tag, Tech.vac_capacity()])
		var belt:= await _belt_case(stand)
		print("  belt: %d poured, %d sold, %d back on the pile, %d over the rail, empty at %.1f s"
			% [belt ["full"], belt ["sold"], belt ["back"], belt ["bounced"], belt ["empty_s"]])
		_check("%s belt: nothing went back on the pile (%d)" % [tag, belt ["back"]],
			int(belt ["back"]) <= 2)
		_check("%s belt: nothing kicked over the rail (%d)" % [tag, belt ["bounced"]],
			int(belt ["bounced"]) == 0)
		_check("%s belt: the till paid for nearly all of it (%d of %d)"
			% [tag, belt ["sold"], belt ["full"]],
			float(belt ["sold"]) >= float(belt ["full"]) * 0.95)

		if "belt" in OS.get_cmdline_user_args():
			_finish()
			return

	Tech.grant("vac_bin", 0)
	print("\n=== a busy yard ===")
	var busy:= await _busy_case()
	print("  busy: %d poured, %d lying in the yard after, %d back on the pile, empty at %.1f s"
		% [busy ["full"], busy ["lying"], busy ["back"], busy ["empty_s"]])
	_check("busy: the bin empties (%.1f s)" % busy ["empty_s"], float(busy ["empty_s"]) > 0.0)
	_check("busy: nothing went back on the pile (%d)" % busy ["back"], int(busy ["back"]) <= 2)
	_check("busy: the load is lying in the yard (%d of %d)" % [busy ["lying"], busy ["full"]],
		absi(int(busy ["lying"]) - int(busy ["full"])) <= 2)

	print("\n=== a tipper ===")
	var tip:= await _hatch_case(stand)
	print("  tipper: %d in the bin, hopper peaked %d above, emptied in %.1f s, %d sold, %d back on the pile"
		% [tip ["full"], tip ["hopper"], tip ["into_s"], tip ["sold"], tip ["back"]])
	_check("tipper: the load went into the hopper (peak %d of %d)"
		% [tip ["hopper"], tip ["full"]], int(tip ["hopper"]) > 0)
	_check("tipper: it took under three seconds (%.1f s)" % tip ["into_s"],
		float(tip ["into_s"]) > 0.0 and float(tip ["into_s"]) < 3.0)
	_check("tipper: the till paid for nearly all of it (%d of %d)" % [tip ["sold"], tip ["full"]],
		float(tip ["sold"]) >= float(tip ["full"]) * 0.95)

	print("\n=== a wheelbarrow ===")
	var barrow:= await _barrow_case()
	print("  barrow: %d in the bin, barrow %d of %d after, %d left in the vac"
		% [barrow ["full"], barrow ["in_barrow"], barrow ["holds"], barrow ["left"]])
	_check("barrow: the barrow was filled (%d of %d)" % [barrow ["in_barrow"], barrow ["holds"]],
		int(barrow ["in_barrow"]) == mini(int(barrow ["full"]), int(barrow ["holds"])))
	_check("barrow: nothing was lost (%d + %d of %d)"
		% [barrow ["in_barrow"], barrow ["left"], barrow ["full"]],
		int(barrow ["in_barrow"]) + int(barrow ["left"]) == int(barrow ["full"]))
	_finish()


func _finish() -> void:
	print("\n[vacpour] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _belt_off() -> float:
	var args:= OS.get_cmdline_user_args()
	var i:= args.find("belt")
	if i >= 0 and i + 1 < args.size() and args [i + 1].is_valid_float():
		return args [i + 1].to_float()
	return 1.55


func _belt_case(stand: HaySellingStand) -> Dictionary:
	var at:= stand.belt_entry_point()
	var side:= stand.global_basis.z.normalized()
	var aim:= at + stand.intake_forward() * 0.35
	_stand_at(Vector3(aim.x, stand.global_position.y, aim.z) + side * _belt_off(), aim)
	var vac:= player.yard_vac
	vac.clear()
	vac.debug_fill(Tech.vac_capacity())
	var full:= vac.fill()
	var belt:= stand.get_node_or_null("StandBelt") as BeltPath
	if belt == null:
		belt = stand.get("_belt") as BeltPath
	BeltPath.debug_props = true
	var hay_was:= GameState.hay_total
	_sold = 0
	var bounced:= { }
	var empty_at:= -1
	var quiet:= 0
	var last:= 0
	await get_tree().physics_frame
	vac.set_pouring(true)
	for tick in range(1, POUR_TICKS + 1):
		await get_tree().physics_frame
		for t in HayTuft.all:
			if is_instance_valid(t) and t.has_meta(BeltPath.META_QUEUE_BOUNCE):
				bounced [t.get_instance_id()] = true
		if empty_at < 0 and vac.fill() <= 0:
			empty_at = tick
			vac.set_pouring(false)
		if _sold == last:
			quiet += 1
		else:
			quiet = 0
			last = _sold
		var belt_empty:= belt == null or (belt._riders.is_empty() and belt.run.count() == 0)
		if empty_at > 0 and belt_empty and quiet >= QUIET_TICKS:
			break
	vac.set_pouring(false)
	var out:= {
		"full": full,
		"sold": _sold,
		"back": int(round(GameState.hay_total - hay_was)),
		"bounced": bounced.size(),
		"empty_s": float(empty_at) / 60.0 if empty_at > 0 else -1.0,
	}
	await _clear_yard()
	return out


func _busy_case() -> Dictionary:
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 77
	var held: Array [RigidBody3D] = []
	var far:= Vector3(-12.0, 0.1, 10.0)
	for i in BUSY_HELD:
		var p:= far + Vector3(rng.randf_range(-2.0, 2.0), rng.randf() * 0.3,
			rng.randf_range(-2.0, 2.0))
		var b:= live.spawn(p, Basis.IDENTITY, Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if b != null:
			LiveStrandManager.hold(b, 120.0)
			held.append(b)
	for i in 30:
		await get_tree().physics_frame
	var spot:= Vector3(13.4, 0.05, 8.0)
	_stand_at(Vector3(spot.x - 1.6, 0.0, spot.z), spot)
	var vac:= player.yard_vac
	vac.clear()
	vac.debug_fill(Tech.vac_capacity())
	var full:= vac.fill()
	var hay_was:= GameState.hay_total
	var live_was:= live.active_count()
	var tufted_was:= _tufted()
	var empty_at:= -1
	vac.set_pouring(true)
	for tick in range(1, POUR_TICKS + 1):
		await get_tree().physics_frame
		if vac.fill() <= 0:
			empty_at = tick
			break
	vac.set_pouring(false)
	for i in 120:
		await get_tree().physics_frame
	var lying:= (live.active_count() - live_was) + (_tufted() - tufted_was)
	var out:= {
		"full": full,
		"lying": lying,
		"back": int(round(GameState.hay_total - hay_was)),
		"empty_s": float(empty_at) / 60.0 if empty_at > 0 else -1.0,
	}
	for b in held:
		if is_instance_valid(b):
			LiveStrandManager.release_hold(b)
	await _clear_yard()
	return out


func _hatch_case(stand: HaySellingStand) -> Dictionary:
	var builds: BuildManager = world.builds
	var seat:= stand.to_global(Vector3(-2.85, 0.0, 3.88))
	var hatch: DumpHatch = builds.add_dump_hatch(seat, stand.global_rotation.y)
	for i in SETTLE:
		await get_tree().physics_frame
	var target:= hatch.to_global(DumpHatch.AIM_CENTRE)
	var from:= hatch.approach_point()
	_stand_at(Vector3(from.x, stand.global_position.y, from.z), target)
	var vac:= player.yard_vac
	vac.clear()
	vac.debug_fill(Tech.vac_capacity())
	var full:= vac.fill()
	var hopper_was:= hatch.stored
	var hay_was:= GameState.hay_total
	_sold = 0
	var into_at:= -1


	var hopper:= 0
	vac.set_pouring(true)
	for tick in range(1, 600):
		await get_tree().physics_frame
		hopper = maxi(hopper, hatch.stored - hopper_was)
		if vac.fill() <= 0:
			into_at = tick
			break
	vac.set_pouring(false)


	var belt:= stand.get_node_or_null("StandBelt") as BeltPath
	if belt == null:
		belt = stand.get("_belt") as BeltPath
	var quiet:= 0
	var last:= -1
	for tick in POUR_TICKS:
		await get_tree().physics_frame
		if _sold == last:
			quiet += 1
		else:
			quiet = 0
			last = _sold
		var belt_empty:= belt == null or (belt._riders.is_empty() and belt.run.count() == 0)
		if hatch.stored <= 0 and belt_empty and quiet >= QUIET_TICKS:
			break

	var lying:= 0
	var bounced:= 0
	for n in get_tree().root.find_children("*", "HayWad", true, false):
		var w:= n as HayWad
		if w == null or w.is_queued_for_deletion() or BeltPath.is_rider(w):
			continue
		lying += w.hay_strands()
		if w.has_meta(BeltPath.META_QUEUE_BOUNCE):
			bounced += 1
	if lying > 0:
		print("    left lying off the belt: %d strands, %d wads kicked off a queue"
			% [lying, bounced])


	var out:= {
		"full": full,
		"hopper": hopper,
		"into_s": float(into_at) / 60.0 if into_at > 0 else -1.0,
		"sold": _sold,
		"back": int(round(GameState.hay_total - hay_was)),
	}
	builds.demolish(hatch)
	await _clear_yard()
	return out


func _barrow_case() -> Dictionary:
	var spot:= Vector3(13.4, 0.0, 6.0)
	var box:= world.props.spawn("wheelbarrow",
		Transform3D(Basis.IDENTITY, spot + Vector3.UP * 0.1)) as HayContainer
	for i in 60:
		await get_tree().physics_frame
	_stand_at(Vector3(spot.x - 1.5, 0.0, spot.z), box.global_position + Vector3.UP * 0.4)
	var vac:= player.yard_vac
	vac.clear()
	vac.debug_fill(Tech.vac_capacity())
	var full:= vac.fill()
	vac.set_pouring(true)
	for tick in 600:
		await get_tree().physics_frame
		if vac.fill() <= 0:
			break
	vac.set_pouring(false)
	for i in 60:
		await get_tree().physics_frame
	var out:= {
		"full": full,
		"in_barrow": box.stored,
		"holds": box.capacity(),
		"left": vac.fill(),
	}
	world.props.remove(box)
	vac.clear()
	await _clear_yard()
	return out


func _stand_at(pos: Vector3, at: Vector3) -> void:
	_pin = Vector3(pos.x, pos.y + 0.05, pos.z)
	player.global_position = _pin
	player.velocity = Vector3.ZERO
	var facing:= (at - pos) * Vector3(1, 0, 1)
	player.rotation = Vector3(0.0, atan2(- facing.x, - facing.z), 0.0)
	player.force_update_transform()
	player._set_tool(Player.Tool.YARD_VAC)
	if player.current_tool != Player.Tool.YARD_VAC:
		print("    (no vac in hand: owned=%s, licensed=%s)"
			% [GameState.has_tool("yard_vac"), Tech.is_unlocked("yard_vac")])
	var to:= at - player.eye_position()
	player.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.5, 1.5)


func _physics_process(_delta: float) -> void:
	if _pin != Vector3.INF:
		player.global_position = _pin
		player.velocity = Vector3.ZERO


func _clear_yard() -> void:
	for t in HayTuft.all.duplicate():
		if is_instance_valid(t):
			BeltPath.release(t)
			world.props.remove(t)
	var live: LiveStrandManager = world.live
	for b in live._active.duplicate():
		if is_instance_valid(b):
			live.consume(b)
	for i in 60:
		await get_tree().physics_frame


func _tufted() -> int:
	var n:= 0
	for t in HayTuft.all:
		if is_instance_valid(t):
			n += t.strands
	return n


func _check(what: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1
