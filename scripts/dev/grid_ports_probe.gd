class_name DevGridPortsProbe
extends Node


var world: Node3D
var player: Player


const BASE:= Vector3(-13.0, 6.0, -1.0)
const LIFT_SECTIONS:= 2
const EPS:= 0.002


const OLD:= {
	"pelletizer": [["in", 0.0, -1.8]],
	"generator": [["in", 0.0, -2.62]],
	"launcher": [["in", 0.0, -1.98]],
	"paper": [["in", 0.0, -3.5], ["out", 0.0, 3.0]],
	"briquette": [["wad", -2.6, -0.92], ["brick", 0.0, -3.9], ["disc", 0.0, 1.7]],
	"lift": [["in", 0.0, -2.28], ["out", 0.0, 2.38]],
}

var _failures: Array [String] = []
var _checks:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for k in 10:
		await get_tree().physics_frame
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--scan")
	if at >= 0 and at + 1 < ua.size():
		await _scan(ua [at + 1])
		return
	print("GRIDPORTS: %d machines, belt minimum %.2f m" % [OLD.size(), Cfg.BELT_MIN_LENGTH])
	for kind: String in OLD:
		for quarter in 4:
			await _check_grid(kind, quarter * PI * 0.5)
		await _check_old(kind)
		await _check_save(kind)
	print("\nGRIDPORTS: %d checks, %d failed" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL %s" % f)
	print("[gridports] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _make(kind: String, at: Vector3, yaw: float) -> Node3D:
	var b: BuildManager = world.builds
	match kind:
		"pelletizer":
			return b.add_pelletizer(at, yaw)
		"generator":
			return b.add_generator(at, yaw)
		"launcher":
			return b.add_tube_launcher(at, yaw)
		"paper":
			return b.add_paper(at, yaw)
		"briquette":
			return b.add_briquette(at, yaw)
		"lift":
			return b.add_hay_lift(at, yaw, LIFT_SECTIONS)
	return null


func _ports(kind: String, node: Node3D) -> Array:
	var z:= node.global_basis.z.normalized()
	var x:= node.global_basis.x.normalized()
	match kind:
		"pelletizer", "generator", "launcher":
			return [["in", node.call("intake_port"), - z, true, node.call("deck")]]
		"paper":
			var p:= node as PaperMachine
			return [["in", p.port_in(), - z, true, p.deck()],
				["out", p.port_out(), z, false, p.outfeed_deck()]]
		"briquette":
			var bp:= node as BriquettePress
			return [["wad", bp.port_wad(), - x, true, bp.wad_deck()],
				["brick", bp.port_brick(), - z, true, bp.brick_deck()],
				["disc", bp.port_out(), z, false, bp.outfeed_deck()]]
		"lift":
			var l:= node as HayLift
			return [["in", l.port_in(), - z, true, l.deck()],
				["out", l.port_out(), z, false, l.outfeed_deck()]]
	return []


static func _off_grid(v: float) -> float:
	return absf(v - roundf(v))


func _clear() -> void:
	var b: BuildManager = world.builds
	for list: Array in [b.pelletizers, b.generators, b.tube_launchers, b.papers,
			b.briquette_presses, b.hay_lifts, b.conveyors]:
		for node in list.duplicate():
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				b.demolish(node)
	await get_tree().physics_frame


func _check_grid(kind: String, yaw: float) -> void:
	var node:= _make(kind, BASE, yaw)
	await get_tree().physics_frame
	var deg:= int(round(rad_to_deg(yaw)))
	for p: Array in _ports(kind, node):
		var label: String = p [0]
		var port: Vector3 = p [1]
		var out: Vector3 = p [2]
		var along_x:= absf(out.x) > 0.5
		var along: float = port.x if along_x else port.z
		var across: float = port.z if along_x else port.x
		var tag:= "%s.%s yaw %d" % [kind, label, deg]
		_check(_off_grid(along) < EPS,
			"GRID %s: port on a whole metre along its bearing (off %.3f)" % [tag, _off_grid(along)])


		if kind == "briquette" and label == "wad":
			print("       %s: across the bearing off %.3f, as authored" % [tag, _off_grid(across)])
		else:
			_check(_off_grid(across) < EPS,
				"GRID %s: port on a grid line across its bearing (off %.3f)" % [tag, _off_grid(across)])

		var cross:= port + out * 1.0
		cross = Vector3(roundf(cross.x), port.y, roundf(cross.z))
		var length:= Vector2(cross.x - port.x, cross.z - port.z).length()
		_check(length >= Cfg.BELT_MIN_LENGTH - 0.001,
			"GRID %s: next crossing %.2f m out, at least %.2f" % [tag, length, Cfg.BELT_MIN_LENGTH])
		var deck: BeltPath = p [4]
		var run: Conveyor = null
		if bool(p [3]):
			run = world.builds.add_conveyor(cross, port)
		else:
			run = world.builds.add_conveyor(port, cross)
		await get_tree().physics_frame
		if bool(p [3]):
			_check(run != null and run.downstream == deck,
				"GRID %s: a belt from the crossing hands on to the machine" % tag)
		else:
			_check(run != null and deck != null and deck.downstream == run,
				"GRID %s: the machine hands on to a belt to the crossing" % tag)
	await _clear()


func _check_old(kind: String) -> void:
	var node:= _make(kind, BASE, 0.0)
	var d: Dictionary = node.call("to_dict")
	await _clear()
	_check(d.has("port_reach"), "SAVE %s: a machine built now writes port_reach" % kind)
	d.erase("port_reach")
	await world.builds.from_array([d])
	await get_tree().physics_frame
	var old:= _only(kind)
	if old == null:
		_check(false, "OLD %s: restored from an old save" % kind)
		return
	var want: Array = OLD [kind]
	var got:= _ports(kind, old)
	for i in want.size():
		var w:= Vector3(float(want [i] [1]), 0.0, float(want [i] [2]))
		var p: Vector3 = got [i] [1] - BASE
		var miss:= Vector2(p.x - w.x, p.z - w.z).length()
		_check(miss < EPS, "OLD %s.%s: port where old saves' belts end (%.3f, %.3f), off %.3f"
			% [kind, String(want [i] [0]), w.x, w.z, miss])
	await _clear()


func _check_save(kind: String) -> void:
	var node:= _make(kind, BASE, 0.0)
	var before: Array = []
	for p: Array in _ports(kind, node):
		before.append(p [1])
	var d: Dictionary = node.call("to_dict")
	await _clear()
	await world.builds.from_array([d])
	await get_tree().physics_frame
	var back:= _only(kind)
	if back == null:
		_check(false, "SAVE %s: restored from its own save" % kind)
		return
	var got:= _ports(kind, back)
	for i in before.size():
		var miss:= (got [i] [1] as Vector3).distance_to(before [i])
		_check(miss < EPS, "SAVE %s.%s: new port survives a save and load (off %.3f)"
			% [kind, String(got [i] [0]), miss])
	await _clear()


func _only(kind: String) -> Node3D:
	var b: BuildManager = world.builds
	var list: Array = { "pelletizer": b.pelletizers, "generator": b.generators,
		"launcher": b.tube_launchers, "paper": b.papers,
		"briquette": b.briquette_presses, "lift": b.hay_lifts } [kind]
	for node in list:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
	return null


func _scan(dir: String) -> void:
	var files:= DirAccess.get_files_at(dir)
	var machines:= 0
	var belted:= 0
	var linked:= 0
	for file in files:
		if not file.ends_with(".dat"):
			continue
		var f:= SaveManager.open_for_read(dir.path_join(file))
		if f == null:
			continue
		var payload: Variant = f.get_var(true)
		f.close()
		if typeof(payload) != TYPE_DICTIONARY:
			print("SCAN %s: not a save" % file)
			continue
		var d: Dictionary = payload
		await world.builds.from_array(d.get("buildings", []))
		for k in 3:
			await get_tree().physics_frame
		var here:= [0, 0, 0]
		for kind: String in OLD:
			for node: Node3D in _all(kind):
				here [0] += 1
				var reach: Variant = node.get("port_reach")
				var zero:= true
				if reach is Array:
					for r: Variant in reach:
						zero = zero and is_zero_approx(float(r))
				else:
					zero = is_zero_approx(float(reach))
				_check(zero, "SCAN %s %s: restored with no reach (old ports)" % [file, node.name])
				for p: Array in _ports(kind, node):
					var port: Vector3 = p [1]
					var deck: BeltPath = p [4]
					for c: Conveyor in world.builds.conveyors:
						if not is_instance_valid(c):
							continue
						if bool(p [3]) and c.b.distance_to(port) < 0.01:
							here [1] += 1
							var ok:= c.downstream == deck
							here [2] += int(ok)
							_check(ok, "SCAN %s %s.%s: belt ending on it hands on" % [
								file, node.name, String(p [0])])
						elif not bool(p [3]) and c.a.distance_to(port) < 0.01:
							here [1] += 1
							var ok:= deck != null and deck.downstream == c
							here [2] += int(ok)
							_check(ok, "SCAN %s %s.%s: belt starting on it is fed" % [
								file, node.name, String(p [0])])
		print("SCAN %s: %d machines touched by this change, %d belts on their ports, %d linked"
			% [file, here [0], here [1], here [2]])
		machines += here [0]
		belted += here [1]
		linked += here [2]
	print("\nGRIDPORTS SCAN: %d machines, %d belts on their ports, %d linked, %d checks, %d failed"
		% [machines, belted, linked, _checks, _failures.size()])
	for f in _failures:
		print("  FAIL %s" % f)
	print("[gridports] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _all(kind: String) -> Array:
	var b: BuildManager = world.builds
	var list: Array = { "pelletizer": b.pelletizers, "generator": b.generators,
		"launcher": b.tube_launchers, "paper": b.papers,
		"briquette": b.briquette_presses, "lift": b.hay_lifts } [kind]
	return list.filter(func(n: Variant) -> bool:
		return is_instance_valid(n) and not (n as Node).is_queued_for_deletion())
