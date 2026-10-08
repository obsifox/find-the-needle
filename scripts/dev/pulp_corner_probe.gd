class_name DevPulpCornerProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const WATCH_SECONDS:= 14.0


const LIFT_LIMIT:= 0.05


const A:= Vector3(13.0, 0.75, -1.0)
const B:= Vector3(13.0, 0.75, 5.0)


const CASES:= [
	{ "name": "45 flat", "turn": 45.0, "climb": 0.0, "rise": 0.0 },
	{ "name": "45 rising", "turn": 45.0, "climb": 0.0, "rise": 2.4 },
	{ "name": "45 climb then flat", "turn": 45.0, "climb": 3.0, "rise": 0.0 },
	{ "name": "90 climb then flat", "turn": 90.0, "climb": 3.0, "rise": 0.0 },


	{ "name": "90 crest, as built", "turn": 90.0, "climb": 3.85, "rise": -0.7 },

	{ "name": "90 steepest climb", "turn": 90.0, "climb": 4.2, "rise": 0.0 },
]

var _fails:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(11.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	print("  lane between rails: %.3f m" % (Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0))

	BeltPath.debug_props = true

	for case: Dictionary in CASES:
		await _bend(case)

	print("\n=== result ===")
	print("  %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _bend(case: Dictionary) -> void:
	var turn: float = deg_to_rad(float(case ["turn"]))
	var run:= 6.0


	var dir:= Vector3(- sin(turn), 0.0, cos(turn))
	var a:= A
	var b: Vector3 = B + Vector3.UP * float(case ["climb"])
	var c: Vector3 = b + dir * run + Vector3.UP * float(case ["rise"])
	print("\n########  %s  ########" % case ["name"])
	print("  A %.2v -> B %.2v -> C %.2v   (pitch in %.1f, out %.1f)"
		% [a, b, c,
			rad_to_deg(atan2(b.y - a.y, Vector2(b.x - a.x, b.z - a.z).length())),
			rad_to_deg(atan2(c.y - b.y, Vector2(c.x - b.x, c.z - b.z).length()))])
	for pair: Array in [[a, b], [b, c]]:
		var check: Dictionary = player.build._evaluate(pair [0], pair [1], true)
		if not bool(check ["ok"]):
			print("  the yard refuses %.2v -> %.2v (%s), skipped"
				% [pair [0], pair [1], str(check ["reason"])])
			return
	var run_a: Conveyor = world.builds.add_conveyor(a, b)
	var run_b: Conveyor = world.builds.add_conveyor(b, c)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	print("  runs %d, corners %d" % [world.builds.conveyors.size(),
		world.builds.corners.size()])
	for corner in world.builds.corners:
		print("    apex %.2v  from %.2v  to %.2v"
			% [corner.apex, corner.from_point, corner.to_point])

	for id in ["hay_wad", "hay_pulp"]:
		await _one(id, run_a, run_b)

	world.builds.demolish(run_b)
	world.builds.demolish(run_a)
	for i in 20:
		await get_tree().physics_frame


func _one(id: String, run_a: Conveyor, run_b: Conveyor) -> void:
	print("\n=== %s ===" % id)
	var item: Carryable = world.props.spawn(id,
		Transform3D(Basis(), run_a.a + run_a.forward * 0.9 + Vector3.UP * 0.35))
	if item == null:
		print("  cannot spawn %s" % id)
		_fails += 1
		return


	print("  reach %.3f, own lift %.3f"
		% [float(BeltPath.load_shape(item) ["reach"]),
			float(BeltPath.load_shape(item) ["lift"])])


	for i in 60:
		await get_tree().physics_frame
	if is_instance_valid(item) and item.is_inside_tree():
		print("  rests %.3f above the deck" % _above_deck_at(item.global_position))

	var ticks:= int(WATCH_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var trace: Array [Dictionary] = []
	var worst:= - INF
	var worst_k:= 0


	var loose:= 0
	var airborne:= - INF
	var seq:= -1
	for k in ticks:
		await get_tree().physics_frame
		if seq < 0:
			seq = _seq_of(id)
		var where:= BeltPath.record_where(seq) if seq >= 0 else { }
		if not where.is_empty():

			var origin:= (where ["pose"] as Transform3D).origin
			var rlift:= _above_deck_at(origin)
			trace.append({
				"y": rlift,
				"at": origin,
				"vy": 0.0,
				"owner": (where ["path"] as Node).name,
				"frozen": true,
			})
			if rlift > worst:
				worst = rlift
				worst_k = trace.size() - 1
			continue
		if not is_instance_valid(item) or not item.is_inside_tree():
			break
		var lift:= _above_deck_at(item.global_position)
		trace.append({
			"y": lift,
			"at": item.global_position,
			"vy": item.linear_velocity.y,
			"owner": _owner_name(item),
			"frozen": item.freeze,
		})
		if lift > worst:
			worst = lift
			worst_k = trace.size() - 1
		if not item.freeze:
			loose += 1
			airborne = maxf(airborne, lift)
	if trace.is_empty():
		print("  the load went away before it was measured")
		_fails += 1
		return

	var last: Dictionary = trace [trace.size() - 1]
	print("  ended at %.2v, %s"
		% [last ["at"], "carried by " + str(last ["owner"]) if last ["owner"] != ""
			else "loose"])
	print("  highest above the deck: %.3f m at tick %d" % [worst, worst_k])
	print("  ticks nothing was carrying it: %d of %d, highest while loose %.3f m"
		% [loose, trace.size(), airborne if not is_inf(airborne) else 0.0])
	if is_instance_valid(item) and BeltPath.debug_last_refusal.has(item.get_instance_id()):
		print("  last time a belt turned it away: %s"
			% str(BeltPath.debug_last_refusal [item.get_instance_id()]))
	_dump(trace, worst_k)


	for k in trace.size():
		if float((trace [k] as Dictionary) ["y"]) > LIFT_LIMIT:
			print("  first left the deck at tick %d, %.2v, owner %s"
				% [k, (trace [k] as Dictionary) ["at"],
					str((trace [k] as Dictionary) ["owner"])])
			break
	if worst > LIFT_LIMIT:
		print("  FAIL: a load riding a belt left it")
		_fails += 1
	else:
		print("  ok: stayed on the deck")
	if is_instance_valid(item):
		BeltPath.release(item)
		item.queue_free()
	_clear_records(id)
	for i in 20:
		await get_tree().physics_frame


func _dump(trace: Array [Dictionary], centre: int) -> void:
	var from:= maxi(0, centre - 14)
	var to:= mini(trace.size(), centre + 10)
	print("  tick |  lift |    vy | frozen | owner            | position")
	for k in range(from, to):
		var t: Dictionary = trace [k]
		print("  %4d | %5.3f | %5.2f | %-6s | %-16s | %.2v"
			% [k, float(t ["y"]), float(t ["vy"]), str(t ["frozen"]),
				str(t ["owner"]), t ["at"]])


func _above_deck_at(p: Vector3) -> float:
	var best:= INF
	for path: BeltPath in _paths():
		var at: Dictionary = path._nearest(p)
		if absf(float(at ["lift"])) < absf(best):
			best = float(at ["lift"])
	return 0.0 if is_inf(best) else best


func _seq_of(id: String) -> int:
	for path: BeltPath in _paths():
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
				return run.seq_of(i)
	return -1


func _clear_records(id: String) -> void:
	for path: BeltPath in _paths():
		var run: BeltRun = path.run
		var i:= run.first() + run.count() - 1
		while i >= run.first():
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:


				var was_head:= i == run.first()
				run.remove_at(i)
				if was_head:
					break
			i -= 1


func _paths() -> Array [BeltPath]:
	var out: Array [BeltPath] = []
	for c: Conveyor in world.builds.conveyors:
		out.append(c)
	for c: ConveyorCorner in world.builds.corners:
		out.append(c)
	return out


func _owner_name(item: Node) -> String:
	if not item.has_meta(LiveStrandManager.META_RIDER):
		return ""
	var path:= item.get_meta(LiveStrandManager.META_RIDER) as BeltPath
	return "<dead>" if path == null else path.name
