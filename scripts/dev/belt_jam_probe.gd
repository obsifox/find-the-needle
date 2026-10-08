class_name DevBeltJamProbe
extends Node


const SETTLE:= 40


const FEED_SECONDS:= 19.2 / Cfg.BELT_SPEED


const FEED_EVERY:= 3
const PER_DROP:= 4

var world: Node3D
var player: Player

var _rng:= RandomNumberGenerator.new()
var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	_rng.seed = 20260824
	for i in SETTLE:
		await get_tree().process_frame


	var a:= Vector3(13.0, 0.75, -5.0)
	var b:= Vector3(13.0, 0.75, 5.0)
	player.global_position = Vector3(11.0, 0.4, 0.0)


	Cfg.belt_decay = true
	Cfg.belt_cap = Cfg.BELT_CAP_DEFAULT
	GameState.add_money(5000.0)
	var belt: Conveyor = world.builds.add_conveyor(a, b)
	if belt == null:
		print("[beltjam] could not lay the test run")
		_done(false)
		return
	for i in SETTLE:
		await get_tree().physics_frame


	var path: BeltPath = belt


	print("\n=== feeding a %.1f m run for %.0f s ===" % [path.path_length(), FEED_SECONDS])

	var ticks:= int(FEED_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var worst_back:= 0.0
	var worst_note:= ""
	var last: Dictionary = { }
	var spawned:= 0
	for tick in ticks:
		if tick % FEED_EVERY == 0:
			spawned += _drop(PER_DROP)
		await get_tree().physics_frame


		var now: Dictionary = { }
		for r in path.riders_debug():
			var seq: int = r ["seq"]
			now [seq] = r ["s"]
			if not last.has(seq):
				continue
			var back:= float(last [seq]) - float(r ["s"])
			if back > worst_back:
				worst_back = back
				worst_note = "tick %d: seq %d went %.4f -> %.4f (gap %.4f, lane %.3f)" % [
					tick, seq, float(last [seq]), float(r ["s"]),
					float(r ["gap"]), float(r ["side"])]
		last = now

	var riders:= path.riders_debug()
	riders.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["s"]) < float(y ["s"]))


	var piled:= 0
	for i in riders.size():
		if float(riders [i] ["s"]) > 0.001:
			continue
		for j in range(i + 1, riders.size()):
			if float(riders [j] ["s"]) > 0.001:
				break
			if absf(float(riders [j] ["side"]) - float(riders [i] ["side"])) <= Cfg.STRAND_THICK * 6.0:
				piled += 1
				break

	var overlaps:= 0
	var closest:= 1000000000.0
	for i in riders.size():
		for j in range(i + 1, riders.size()):
			var d: float = float(riders [j] ["s"]) - float(riders [i] ["s"])
			if d > Cfg.STRAND_THICK:
				break
			if absf(float(riders [j] ["side"]) - float(riders [i] ["side"])) > Cfg.STRAND_THICK * 6.0:
				continue
			closest = minf(closest, d)
			overlaps += 1

	print("  hay dropped on the head : %d" % spawned)
	print("  riders aboard at the end: %d" % riders.size())
	print("  same-lane pile-ups on s=0: %d" % piled)
	print("  overlapping pairs       : %d  (closest %.4f m, a strand is %.4f m thick)"
		% [overlaps, 0.0 if closest > 100000000.0 else closest, Cfg.STRAND_THICK])
	print("  worst backward step     : %.4f m in one tick" % worst_back)
	if worst_note != "":
		print("    %s" % worst_note)


	var carried:= BeltPath.belt_load()
	print("  riding across the yard  : %d  (budget %d, %d paths reporting)"
		% [carried, Cfg.belt_cap, BeltPath._load_by_path.size()])
	print("  take-ons refused        : %d" % BeltPath._refused)
	print("  worst load at a take-on : %d" % BeltPath._max_at_take)

	var ok:= true
	ok = _check(carried <= Cfg.belt_cap,
		"the belts stayed inside their rider budget") and ok
	ok = _check(carried >= mini(riders.size(), 8),
		"and are still carrying a useful amount of hay") and ok


	ok = _check(BeltPath._max_at_take < Cfg.belt_cap,
		"nothing ever boarded a belt that was already at its budget") and ok
	ok = _check(piled == 0, "no two riders sharing the start of one lane") and ok
	ok = _check(overlaps == 0, "no two riders inside each other") and ok


	ok = _check(worst_back <= Cfg.BELT_RIDE_SPACING + 0.0001,
		"no rider springs backwards further than one spacing") and ok
	_done(ok)


func _drop(count: int) -> int:
	var made:= 0
	for i in count:
		var pos:= Vector3(
			13.0 + _rng.randf_range(-0.2, 0.2),
			1.05,
			-4.6 + _rng.randf_range(-0.3, 0.3))
		var body: RigidBody3D = world.live.spawn(pos,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if body != null:
			made += 1
	return made


func _check(condition: bool, what: String) -> bool:
	if not condition:
		_fails += 1
		print("  no: %s" % what)
	return condition


func _done(ok: bool) -> void:
	print("\n[beltjam] %s" % ("PASS" if ok and _fails == 0 else "FAIL"))
	get_tree().quit()
