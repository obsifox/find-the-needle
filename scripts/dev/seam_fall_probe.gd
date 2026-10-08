class_name DevSeamFallProbe
extends Node


var world: Node3D
var player: Node

const BELT_RANK:= 8
const WAD_STRANDS:= 60

const DECK_Y:= 6.0

const FALL_DROP:= 1.0
const WATCH_TICKS:= 480


const RISE:= 2.0

var _failed:= 0
var _passed:= 0

var _flight:= { }


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % what)
	else:
		_failed += 1
		print("  FAIL %s" % what)


func _tick(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _add(a: Vector3, b: Vector3, into: Array) -> Conveyor:
	var before: Array = world.builds.corners.duplicate()
	var c: Conveyor = world.builds.add_conveyor(a, b)
	into.append(c)
	for corner in world.builds.corners:
		if not before.has(corner) and not into.has(corner):
			into.append(corner)
	return c


func _push(p: BeltPath, s: float) -> bool:
	var at: Vector3 = p.run.pose_at(s, 0.0, 0.0).origin
	return p.push_record(BeltRun.Kind.WAD, WAD_STRANDS, -1, { "strands": WAD_STRANDS }, at) >= 0


func run() -> void:
	world.set("autosave_enabled", false)
	Tech.ranks ["belt_speed"] = BELT_RANK
	Cfg.belt_decay = false
	await _tick(2)
	print("[seamfall] belt %.2f m/s, decks at y %.1f" % [Tech.belt_speed(), DECK_Y])
	await _part_a()
	await _part_b()
	await _part_c()
	print("\n== seam fall ==")
	print("  %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _part_a() -> void:
	print("\n== part A: two records leave a bend in one tick ==")
	var paths: Array = []
	var y:= DECK_Y
	_add(Vector3(-14.0, y, 30.0), Vector3(-8.0, y, 30.0), paths)
	_add(Vector3(-8.0, y, 30.0), Vector3(-8.0, y, 36.0), paths)
	var bend: BeltPath = null
	for p in paths:
		if p is ConveyorCorner:
			bend = p
	_check(bend != null, "a bend was fitted between the two runs")
	if bend == null:
		return


	bend.set_physics_process(false)


	var batch:= BeltRunBatch.new()
	batch.name = "SeamFallBatch"
	world.add_child(batch)
	batch.adopt(bend.run)
	var length: float = bend.path_length()
	var boarded:= 0
	for s in [length * 0.2, length * 0.5, length * 0.8]:
		if _push(bend, s):
			boarded += 1
	await get_tree().process_frame
	await get_tree().process_frame
	_check(boarded == 3, "three wads pushed onto the bend as records (%d)" % boarded)
	var run: BeltRun = bend.run


	run.remove_at(run.first())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(batch._events.is_empty(), "queue drained after the front record left alone")


	var f:= run.first()
	var gone_last: int = run.seq_of(f)
	run.remove_at(f + 1)
	run.remove_at(f)
	print("  run after the pair left: first %d, rows %d, count %d" % [run.first(), run._pos.size(), run.count()])


	var rd = batch._by_run [run]
	var row: int = batch._row_of(rd, gone_last)
	var live:= row >= run.first() and row < run.first() + run.count()
	_check(row == -1 or live, "the drawer's row lookup for a seq that has left answers -1 or a live row (answered %d, run holds rows %d to %d)"
		% [row, run.first(), run.first() + run.count() - 1])
	await get_tree().process_frame
	await get_tree().process_frame
	var pending: int = batch._events.size()
	var slots: int = rd.slots.size()
	_check(pending == 0, "queue drained after two records left in one tick (%d events still queued)" % pending)
	_check(slots == 0, "every slot released (%d still seated)" % slots)
	batch.drop(run)
	batch.queue_free()
	for p in paths:
		if is_instance_valid(p) and p is Conveyor:
			world.builds.demolish(p)
	await _tick(2)


func _shapes() -> Array:
	var y:= DECK_Y
	var out:= []

	var z:= 40.0
	z += 5.0
	out.append({ "name": "flat seam",
		"runs": [[Vector3(-14.0, y, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "descent into flat",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "flat into climb",
		"runs": [[Vector3(-14.0, y, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z), Vector3(22.0, y + RISE * 5.0, z)]] })
	z += 5.0
	out.append({ "name": "descent into descent, straight on",
		"runs": [[Vector3(-14.0, y + RISE * 2.0, z), Vector3(-8.0, y + RISE, z)],
			[Vector3(-8.0, y + RISE, z), Vector3(-2.0, y, z)],
			[Vector3(-2.0, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "near miss, next run starts 2 cm on",
		"runs": [[Vector3(-14.0, y, z), Vector3(-8.0, y, z)],
			[Vector3(-7.98, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "near miss, next run starts 5 cm up",
		"runs": [[Vector3(-14.0, y, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y + 0.05, z), Vector3(22.0, y + 0.05, z)]] })
	z += 5.0
	out.append({ "name": "end onto the middle of a crossing run",
		"runs": [[Vector3(-14.0, y, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z - 2.0), Vector3(-8.0, y, z + 28.0)]] })
	z += 5.0
	out.append({ "name": "two runs ending on one point, one leaving",
		"runs": [[Vector3(-14.0, y, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z - 2.0), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "descent turning into a flat run",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y, z), Vector3(-8.0, y, z + 2.5)],
			[Vector3(-8.0, y, z + 2.5), Vector3(22.0, y, z + 2.5)]] })
	z += 5.0
	out.append({ "name": "descent, next run starts 2 cm on",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-7.98, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "descent, next run starts 5 cm down",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y - 0.05, z), Vector3(22.0, y - 0.05, z)]] })
	z += 5.0
	out.append({ "name": "descent, next run starts 5 cm up",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-8.0, y + 0.05, z), Vector3(22.0, y + 0.05, z)]] })
	z += 5.0
	out.append({ "name": "descent onto a run already passing under its end",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-8.3, y, z), Vector3(22.0, y, z)]] })
	z += 5.0
	out.append({ "name": "two descents meeting head to head, nothing leaving",
		"runs": [[Vector3(-14.0, y + RISE, z), Vector3(-8.0, y, z)],
			[Vector3(-2.0, y + RISE, z), Vector3(-8.0, y, z)]] })
	return out


func _part_b() -> void:
	print("\n== part B: three wads across each joint shape ==")
	for shape in _shapes():
		await _shape(shape)


func _shape(shape: Dictionary) -> void:
	var nm: String = shape ["name"]
	var paths: Array = []
	var lowest:= INF
	for pair in shape ["runs"]:
		_add(pair [0], pair [1], paths)
		lowest = minf(lowest, minf((pair [0] as Vector3).y, (pair [1] as Vector3).y))
	await _tick(10)
	var first: BeltPath = paths [0]
	var links:= ""
	for p in paths:
		var d: BeltPath = p.downstream
		links += " %s>%s" % [p.name, d.name if d != null else "none"]
	var items_before: Array = world.props.items.duplicate()
	var pushed:= 0
	var length: float = first.path_length()
	for s in [length * 0.3, length * 0.5, length * 0.7]:
		if _push(first, s):
			pushed += 1
	for p in paths:
		p.wake()
	await _tick(WATCH_TICKS)
	var records:= 0
	for p in paths:
		if is_instance_valid(p):
			records += p.run.count()
	var riding:= 0
	var loose:= 0
	var fallen:= 0
	var where:= ""
	for it in world.props.items:
		if items_before.has(it) or not is_instance_valid(it) or it.item_id != "hay_wad":
			continue
		var pos: Vector3 = it.global_position
		if pos.y < lowest - FALL_DROP:
			fallen += 1
			where += " fell to %.1v" % pos
		elif BeltPath.is_rider(it):
			riding += 1
		else:
			loose += 1
			where += " loose at %.1v" % pos
	var ok:= pushed == 3 and fallen == 0 and loose == 0 and records + riding == 3
	var seam: Vector3 = (shape ["runs"] [0] as Array) [1]
	var line:= "%s at %.1v: %d records, %d riding, %d loose, %d fell (links%s)%s" % [
		nm, seam, records, riding, loose, fallen, links, where]


	if nm.begins_with("two descents meeting head to head"):
		print("  note %s" % line)
		return
	_check(ok, line)

	for p in paths:
		if is_instance_valid(p) and p is Conveyor:
			world.builds.demolish(p)
	for it in world.props.items:
		if not items_before.has(it) and is_instance_valid(it) and it.item_id == "hay_wad":
			it.queue_free()
	await _tick(5)


func _part_c() -> void:
	print("\n== part C: the next belt laid onto a run with wads aboard ==")
	var y:= DECK_Y
	var z:= 120.0
	for variant: String in ["straight on", "turn", "turn off a descent", "straight on off a descent"]:
		var paths: Array = []
		var descent: bool = variant.ends_with("descent")
		var p0:= Vector3(-14.0, y + (RISE if descent else 0.0), z)
		var p1:= Vector3(-8.0, y, z)
		var p2:= Vector3(22.0, y, z) if variant.begins_with("straight") else Vector3(-8.0, y, z + 30.0)
		var first: BeltPath = _add(p0, p1, paths)
		await _tick(10)
		var items_before: Array = world.props.items.duplicate()


		var watch_flight:= func() -> void:
			for id in _flight.keys():
				var b:= instance_from_id(id) as Node3D
				if b == null or not is_instance_valid(b) or not b.is_inside_tree():
					continue
				var pos: Vector3 = b.global_position
				if pos.y > 1.0:
					_flight [id] = maxf(float(_flight [id]), Vector2(pos.x - p1.x, pos.z - p1.z).length())
		first.handed_on.connect(func(b: RigidBody3D) -> void:
			if is_instance_valid(b) and not BeltPath.is_rider(b):
				_flight [b.get_instance_id()] = 0.0)
		get_tree().physics_frame.connect(watch_flight)

		var pushed:= 0
		for k in 8:
			if _push(first, 0.4):
				pushed += 1
			first.wake()
			await _tick(30)


		var aboard: Array [int] = []
		var f: int = first.run.first()
		for row in range(f, f + first.run.count()):
			if first.run.s_of(row) < first.path_length() - 0.5:
				aboard.append(first.run.seq_of(row))
		var thrown_before:= 0
		var flew:= 0
		for id in _flight:
			thrown_before += 1


			if float(_flight [id]) > 1.0:
				flew += 1
		var worst:= 0.0
		for id in _flight:
			worst = maxf(worst, float(_flight [id]))
		_flight.clear()
		get_tree().physics_frame.disconnect(watch_flight)
		_add(p1, p2, paths)
		await _tick(300)
		var still:= 0
		var records_after:= 0
		for p in paths:
			if not is_instance_valid(p):
				continue
			var pb:= p as BeltPath
			var pf: int = pb.run.first()
			for row in range(pf, pf + pb.run.count()):
				records_after += 1
				if aboard.has(pb.run.seq_of(row)):
					still += 1
		var riding:= 0
		var loose:= 0
		var fallen:= 0
		var where:= ""
		for it in world.props.items:
			if items_before.has(it) or not is_instance_valid(it) or it.item_id != "hay_wad":
				continue
			var pos: Vector3 = it.global_position
			if pos.y < y - FALL_DROP:
				fallen += 1
			elif BeltPath.is_rider(it):
				riding += 1
			else:
				loose += 1
				where += " loose at %.1v" % pos
		_check(flew == 0, "%s: %d pushed, %d let go off the dead end before the join, %d of them got more than a metre out while in the air (worst %.2f m), %d aboard at the join"
			% [variant, pushed, thrown_before, flew, worst, aboard.size()])


		_check(records_after == aboard.size(),
			"%s: %d of %d aboard at the join are records after it (%d under their old seq); bodies now %d riding, %d loose, %d fallen%s"
			% [variant, records_after, aboard.size(), still, riding, loose, fallen, where])
		for p in paths:
			if is_instance_valid(p) and p is Conveyor:
				world.builds.demolish(p)
		for it in world.props.items:
			if not items_before.has(it) and is_instance_valid(it) and it.item_id == "hay_wad":
				it.queue_free()
		await _tick(5)
		z += 5.0
