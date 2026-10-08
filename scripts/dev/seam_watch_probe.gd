class_name DevSeamWatchProbe
extends Node


var world: Node3D
var player: Node
var _paths: Array = []
var _names: Array = []


var _audited:= 0
var _asleep_ticks:= 0
var _still_ticks:= 0
var _shouts:= 0
var _stalled_on:= { }


var _last_s:= { }
var _still:= { }


const STILL_TICKS:= 4


func _where(wad) -> String:
	for i in _paths.size():
		var p: BeltPath = _paths [i]
		if not is_instance_valid(p):
			continue
		if p.run.count() > 0:
			var row: int = p.run.first()
			return "%s s=%.3f v=%.3f (path ticking %s, asleep %s, run awake %s)" % [
				_names [i], p.run.s_of(row), p.run.speed_of(row),
				p.is_physics_processing(), p._asleep, p.run.awake]
	if wad != null and is_instance_valid(wad) and wad is Node3D:
		return "body at %.2v vel %.2f" % [wad.global_position, wad.linear_velocity.length()]
	return "no record, body freed"


func _wads() -> int:
	var n:= 0
	for p in _paths:
		if is_instance_valid(p):
			n += p.run.count()
	return n


func _add(a: Vector3, b: Vector3, nm: String) -> BeltPath:
	var before: Array = world.builds.corners.duplicate()
	var c: BeltPath = world.builds.add_conveyor(a, b)
	_paths.append(c)
	_names.append(nm)

	for corner in world.builds.corners:
		if not before.has(corner) and not _paths.has(corner):
			_paths.append(corner)
			_names.append("corner")
	return c


func _audit() -> void:
	if _paths.is_empty():
		return
	_audited += 1
	var asleep:= false
	var still:= false
	for i in _paths.size():


		var p = _paths [i]
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		var id: int = p.get_instance_id()
		if p.run.count() <= 0:
			_last_s.erase(id)
			_still.erase(id)
			continue
		var nm: String = _names [i]


		if p._asleep:
			asleep = true
			_stalled_on [nm] = int(_stalled_on.get(nm, 0)) + 1
		var row: int = p.run.first()
		var here: float = p.run.s_of(row)
		var v: float = p.run.speed_of(row)


		if v <= 0.05:
			_last_s [id] = here
			_still [id] = 0
			continue
		if _last_s.has(id) and absf(here - float(_last_s [id])) < 0.0001:
			_still [id] = int(_still.get(id, 0)) + 1
			if int(_still [id]) == STILL_TICKS:
				still = true
				if _shouts < 8:
					_shouts += 1
					print("  STALL: %s s=%.3f v=%.3f still %d ticks (asleep %s)" % [
						nm, here, v, STILL_TICKS, p._asleep])
		else:
			_still [id] = 0
		_last_s [id] = here
	if asleep:
		_asleep_ticks += 1
	if still:
		_still_ticks += 1


func _trace(wad, seconds: float, tag: String) -> void:
	var last:= ""
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var line:= _where(wad)
		if line != last:
			print("  [%s] t=%5.2f %s" % [tag, t, line])
		last = line


func run() -> void:
	get_tree().physics_frame.connect(_audit)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var y: float = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(4.0, y, 45.0)
	var b:= Vector3(8.0, y, 45.0)
	var c:= Vector3(12.0, y, 45.0)
	print("== phase 1: plain seam ==")
	_add(a, b, "AB")
	_add(b, c, "BC")
	for i in 20:
		await get_tree().physics_frame
	var wad: Node3D = world.props.spawn("hay_wad", Transform3D(Basis(), a + Vector3(0.6, 0.4, 0.0)), { })

	var last:= ""
	var t:= 0.0
	var census:= 0.0
	while t < 6.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		census += 1.0 / 60.0
		if census >= 0.5:
			census = 0.0
			var parts:= ""
			for i in _paths.size():
				var pp: BeltPath = _paths [i]
				parts += " %s:%d rec %d riders%s" % [_names [i], pp.run.count(), pp.riders().size(), " asleep" if pp._asleep else ""]
			print("  census t=%.1f%s, conveyors %d" % [t, parts, world.builds.conveyors.size()])
		var line:= _where(wad)
		var s_on_ab:= line.begins_with("AB") and line.find("s=3.9") >= 0
		var early_bc:= line.begins_with("BC") and (line.find("s=0.0") >= 0 or line.find("s=0.1") >= 0)
		if line != last and (s_on_ab or early_bc or not line.begins_with("AB") and not line.begins_with("BC")):
			print("  t=%5.2f %s" % [t, line])
		last = line
	print("  records on my paths after phase 1: %d (wad body valid %s)" % [_wads(), is_instance_valid(wad)])

	print("\n== phase 2a: straight section added while a wad rides the end ==")
	var d:= Vector3(16.0, y, 45.0)
	var wad2: Node3D = world.props.spawn("hay_wad", Transform3D(Basis(), b + Vector3(1.0, 0.4, 0.0)), { })
	await _trace(wad2, 2.0, "before")
	print("  adding CD straight on; BC length before %.2f" % (_paths [_names.find("BC")] as BeltPath).path_length())
	_add(c, d, "CD")
	print("  BC length after %.2f, BC records %d" % [(_paths [_names.find("BC")] as BeltPath).path_length(), (_paths [_names.find("BC")] as BeltPath).run.count()])
	await _trace(wad2, 4.0, "after")
	print("  records on my paths after phase 2a: %d (wad2 body valid %s)" % [_wads(), is_instance_valid(wad2)])

	print("\n== phase 2b: a turn added while a wad rides the last section ==")
	var e:= Vector3(16.0, y, 49.0)
	var wad3: Node3D = world.props.spawn("hay_wad", Transform3D(Basis(), c + Vector3(1.0, 0.4, 0.0)), { })
	await _trace(wad3, 2.0, "before")
	print("  adding DE with a corner; CD length before %.2f, CD records %d" % [(_paths [_names.find("CD")] as BeltPath).path_length(), (_paths [_names.find("CD")] as BeltPath).run.count()])
	_add(d, e, "DE")
	var cd: BeltPath = _paths [_names.find("CD")]
	print("  CD length after %.2f, CD records %d, corners now %d" % [cd.path_length(), cd.run.count(), world.builds.corners.size()])
	await _trace(wad3, 6.0, "after")
	print("  records on my paths after phase 2b: %d (wad3 body valid %s)" % [_wads(), is_instance_valid(wad3)])

	print("\n== phase 2c: five wads across the trim zone when a corner is fitted ==")
	var f:= Vector3(4.0, y, 15.0)
	var g:= Vector3(12.0, y, 15.0)
	var h:= Vector3(12.0, y, 19.0)
	var before_items: Array = world.props.items.duplicate()
	var fg: BeltPath = _add(f, g, "FG")
	for i in 20:
		await get_tree().physics_frame
	for x in [8.4, 9.2, 10.0, 10.8, 11.6]:
		world.props.spawn("hay_wad", Transform3D(Basis(), Vector3(x, y + 0.4, 15.0)), { })
	for i in 40:
		await get_tree().physics_frame
	print("  FG length %.2f, records %d, riders %d before the turn is added" % [fg.path_length(), fg.run.count(), fg.riders().size()])
	_add(g, h, "GH")
	print("  FG length %.2f, records %d, riders %d just after" % [fg.path_length(), fg.run.count(), fg.riders().size()])
	for i in 240:
		await get_tree().physics_frame
	var riding:= 0
	var fallen:= 0
	var loose:= 0
	for it in world.props.items:
		if before_items.has(it) or not is_instance_valid(it) or it.item_id != "hay_wad":
			continue
		var pos: Vector3 = it.global_position
		if pos.y < y - 0.3 or absf(pos.z - 15.0) > 0.7 and absf(pos.x - 12.0) > 0.7:
			fallen += 1
			print("  fallen body at %.2v" % pos)
		else:
			loose += 1
			print("  loose body on the deck at %.2v, %s" % [pos, "riding" if BeltPath.is_rider(it) else "not riding"])
	for i in _paths.size():
		if _names [i] in ["FG", "GH"] or i >= _paths.size() - 2:
			riding += (_paths [i] as BeltPath).run.count()
	print("  4 s after the turn: %d records riding FG/GH/its corner, %d loose bodies, %d fallen (of 5)" % [riding, loose, fallen])

	print("\n== phase 2d: three wads parked at a dead end, then the belt is extended ==")
	for variant in ["straight", "turn"]:
		var z:= 25.0 if variant == "straight" else 31.0
		var p0:= Vector3(4.0, y, z)
		var p1:= Vector3(10.0, y, z)
		var p2:= Vector3(16.0, y, z) if variant == "straight" else Vector3(10.0, y, z + 5.0)
		var items_before: Array = world.props.items.duplicate()
		var first: BeltPath = _add(p0, p1, "P" + variant)
		for i in 20:
			await get_tree().physics_frame
		for x in [7.0, 7.8, 8.6]:
			world.props.spawn("hay_wad", Transform3D(Basis(), Vector3(x, y + 0.4, z)), { })

		for i in 360:
			await get_tree().physics_frame
		var parked:= 0
		for it in world.props.items:
			if not items_before.has(it) and is_instance_valid(it) and it.item_id == "hay_wad":
				parked += 1
				print("  [%s] before extending: body at %.2v, %s" % [variant, it.global_position, "riding" if BeltPath.is_rider(it) else "not riding"])
		print("  [%s] before extending: %d records, %d riders, %d bodies" % [variant, first.run.count(), first.riders().size(), parked])
		_add(p1, p2, "Q" + variant)
		for i in 300:
			await get_tree().physics_frame
		var fell:= 0
		var kept:= 0
		for it in world.props.items:
			if not items_before.has(it) and is_instance_valid(it) and it.item_id == "hay_wad":
				var pos: Vector3 = it.global_position
				var off:= pos.y < y - 0.3
				if variant == "straight":
					off = off or absf(pos.z - z) > 0.7
				else:
					off = off or (absf(pos.z - z) > 0.7 and absf(pos.x - 10.0) > 0.7)
				if off:
					fell += 1
					print("  [%s] FELL: body at %.2v" % [variant, pos])
				else:
					kept += 1
					print("  [%s] kept: body at %.2v, %s" % [variant, pos, "riding" if BeltPath.is_rider(it) else "not riding"])
		var recs:= 0
		for i in _paths.size():
			if String(_names [i]).ends_with(variant) or i >= _paths.size() - 3:
				recs += (_paths [i] as BeltPath).run.count()
		print("  [%s] 5 s after extending: %d records riding, %d bodies kept, %d FELL (of 3)" % [variant, recs, kept, fell])
	_verdict()


func _verdict() -> void:
	print("\n== seam watch ==")
	print("  ticks audited: %d" % _audited)
	print("  carrying sleepers: %d ticks" % _asleep_ticks)
	print("  records still on a running belt: %d ticks" % _still_ticks)
	if _asleep_ticks == 0 and _still_ticks == 0:
		print("  1 passed, 0 failed")
		get_tree().quit()
		return
	for nm: String in _stalled_on:
		print("    asleep while carrying on %s: %d ticks" % [nm, int(_stalled_on [nm])])
	print("  FAIL: a path was not being ticked while it carried a record.")
	print("  See BeltRun.boarded and BeltPath.wake.")
	print("  0 passed, 1 failed")
	get_tree().quit(1)
