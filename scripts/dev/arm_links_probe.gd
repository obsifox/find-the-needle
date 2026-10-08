class_name DevArmLinksProbe
extends Node


var world: Node3D

const SETTLE_FRAMES:= 30


const RUN_FRAMES:= 2700

const FEED_FRAMES:= 150
const FEED_LOADS:= 8

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	Tech.grant("belt")
	Tech.grant("arm_small")
	Tech.grant("arm_standard")
	Tech.grant("belt_links")
	_check_clicks()
	await _check_sorter()
	await _check_unlinked()
	await _check_round_trip()
	print("\n[arm-links] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])


func _yard() -> Dictionary:
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(0.0, 0.06, 14.0)
	var line:= builds.add_conveyor(base + Vector3(-3.4, 0.45, -1.8),
		base + Vector3(3.4, 0.45, -1.8))
	var out:= builds.add_conveyor(base + Vector3(-2.0, 0.45, 1.8),
		base + Vector3(2.0, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	return { "base": base, "line": line, "out": out, "arm": arm }


static func _count(path: BeltPath, kind: int) -> int:
	var n:= 0
	var belt:= path.run
	for i in range(belt.first(), belt.first() + belt.count()):
		if belt.kind_of(i) == kind:
			n += 1
	return n


func _board_bale(path: BeltPath, at: Vector3) -> bool:
	var props: PropManager = world.props
	var bale: Carryable = props.spawn("hay_bale", Transform3D(Basis.IDENTITY, at))
	if bale == null:
		return false
	return path.board_body(bale, at, 0.0) >= 0


func _check_clicks() -> void:
	print("\n=== a click links, the other button swaps, the same one unlinks ===")
	var y:= _yard()
	var arm: RoboticArm = y ["arm"]
	var line: Conveyor = y ["line"]
	var at: Vector3 = (y ["base"] as Vector3) + Vector3(0.0, 0.45, -1.8)
	_is("in reach", arm.link_in_reach(line._point_at(line.s_at(at))), true)
	_is("left click takes from it", arm.set_link(line, at, RoboticArm.LINK_TAKE),
		RoboticArm.LINK_TAKE)
	_is("right click swaps it to put", arm.set_link(line, at, RoboticArm.LINK_PUT),
		RoboticArm.LINK_PUT)
	_is("right click again unlinks it", arm.set_link(line, at, RoboticArm.LINK_PUT),
		RoboticArm.LINK_NONE)
	_is("and it has no links", arm.links().size(), 0)
	var builds: BuildManager = world.builds
	var far:= builds.add_conveyor(Vector3(-2.0, 0.51, 24.0), Vector3(2.0, 0.51, 24.0))
	_is("a belt out of reach is refused",
		arm.set_link(far, Vector3(0.0, 0.51, 24.0), RoboticArm.LINK_TAKE),
		RoboticArm.LINK_NONE)
	_is("and nothing was linked", arm.links().size(), 0)


func _check_sorter() -> void:
	print("\n=== a sorter takes the ticked kind and lets the rest ride ===")
	var y:= _yard()
	var arm: RoboticArm = y ["arm"]
	var line: Conveyor = y ["line"]
	var out: Conveyor = y ["out"]
	var base: Vector3 = y ["base"]
	arm.accept_mask = RoboticArm.PICK_BALE | RoboticArm.PICK_NEEDLE
	arm.set_link(line, base + Vector3(-0.6, 0.45, -1.8), RoboticArm.LINK_TAKE)
	arm.set_link(out, base + Vector3(0.0, 0.45, 1.8), RoboticArm.LINK_PUT)
	var head:= base + Vector3(-3.2, 0.55, -1.8)
	var fed:= { "wad": 0, "bale": 0 }
	var carried:= { }
	var landed:= { "out": 0, "elsewhere": 0, "wrong": 0 }
	var on_drop:= func(seq: int) -> void:
		var where:= BeltPath.record_where(seq)
		if where.is_empty():
			landed ["elsewhere"] += 1
			return
		var p:= where ["path"] as BeltPath
		if p != out:
			landed ["elsewhere"] += 1
		elif p.run.kind_of(int(where ["row"])) != BeltRun.Kind.BALE:
			landed ["wrong"] += 1
		else:
			landed ["out"] += 1
	arm.dropped_record.connect(on_drop)
	var loads:= 0
	for i in RUN_FRAMES:
		if i % FEED_FRAMES == 0 and loads < FEED_LOADS:
			if loads % 2 == 0:
				if line.push_record(BeltRun.Kind.WAD, 40, -1, { "strands": 40 }, head) >= 0:
					fed ["wad"] += 1
			elif _board_bale(line, head):
				fed ["bale"] += 1
			loads += 1
		await get_tree().physics_frame
		var held:= arm._payload_prop
		if held != null and is_instance_valid(held):
			carried [held.get_instance_id()] = held.item_id
		var put_down: int = landed ["out"] + landed ["elsewhere"] + landed ["wrong"]
		if loads >= FEED_LOADS and put_down >= int(fed ["bale"]) and arm._phase == RoboticArm.Phase.IDLE:
			break
	arm.dropped_record.disconnect(on_drop)
	var kinds:= { }
	for id: int in carried:
		kinds [carried [id]] = int(kinds.get(carried [id], 0)) + 1
	print("  fed %s, the claw carried %s, landed %s, %d cycles" % [
		str(fed), str(kinds), str(landed), arm.completed_cycles])
	_is("the line was fed both kinds", fed ["wad"] > 0 and fed ["bale"] > 0, true)
	_is("the claw never carried a wad", int(kinds.get("hay_wad", 0)), 0)
	_is("it carried bales", int(kinds.get("hay_bale", 0)) > 0, true)
	_is("every bale fed was taken", int(kinds.get("hay_bale", 0)), fed ["bale"])
	_is("every load it put down went on the put belt", landed ["elsewhere"], 0)
	_is("and every one of them is a bale", landed ["wrong"], 0)
	_is("and nothing is left in the claw", arm._payload_prop == null, true)


func _check_unlinked() -> void:
	print("\n=== an arm with no links works exactly as before ===")
	var y:= _yard()
	var arm: RoboticArm = y ["arm"]
	var line: Conveyor = y ["line"]
	var base: Vector3 = y ["base"]
	arm.accept_mask = RoboticArm.PICK_BALE | RoboticArm.PICK_WAD | RoboticArm.PICK_NEEDLE
	var wads:= 0
	for k in 3:
		if line.push_record(BeltRun.Kind.WAD, 40, -1, { "strands": 40 },
				base + Vector3(-3.2 + 1.2 * float(k), 0.55, -1.8)) >= 0:
			wads += 1
	var props: PropManager = world.props
	var bale: Carryable = props.spawn("hay_bale",
		Transform3D(Basis.IDENTITY, base + Vector3(-1.9, 0.35, 0.3)))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var lifted:= false
	for i in RUN_FRAMES:
		await get_tree().physics_frame
		if arm._payload_prop == bale:
			lifted = true
		if lifted and arm.completed_cycles > 0 and arm._phase == RoboticArm.Phase.IDLE:
			break
	_is("the bale on the floor was lifted", lifted, true)
	_is("and put down", arm.completed_cycles > 0, true)
	var where:= BeltPath.record_where(arm.last_record_seq)
	_is("on a belt beside it", not where.is_empty(), true)
	_is("the wads on the running line were left alone",
		_count(line, BeltRun.Kind.WAD) + _count(y ["out"] as BeltPath, BeltRun.Kind.WAD), wads)


func _check_round_trip() -> void:
	print("\n=== links survive a save, and go with a removed belt ===")
	var y:= _yard()
	var arm: RoboticArm = y ["arm"]
	var line: Conveyor = y ["line"]
	var out: Conveyor = y ["out"]
	var base: Vector3 = y ["base"]
	arm.set_link(line, base + Vector3(0.4, 0.45, -1.8), RoboticArm.LINK_TAKE)
	arm.set_link(out, base + Vector3(-0.5, 0.45, 1.8), RoboticArm.LINK_PUT)
	var builds: BuildManager = world.builds

	var line_a:= line.a
	var out_a:= out.a
	var saved:= builds.to_array()
	var row: Dictionary = { }
	for d: Variant in saved:
		if d is Dictionary and str((d as Dictionary).get("type", "")) == "robotic_arm":
			row = d
	var written: Array = row.get("links", [])
	print("  the file says links = %s" % str(written))
	_is("the save names two links", written.size(), 2)


	var arms_first: Array = []
	for d: Variant in saved:
		if d is Dictionary and str((d as Dictionary).get("type", "")) == "robotic_arm":
			arms_first.push_front(d)
		else:
			arms_first.append(d)
	builds.clear()
	await get_tree().physics_frame
	builds.from_array(arms_first)
	await get_tree().physics_frame
	_is("one arm came back", builds.robotic_arms.size(), 1)
	if builds.robotic_arms.is_empty():
		return
	var back: RoboticArm = builds.robotic_arms [0]
	var links:= back.links()
	_is("with both links", links.size(), 2)
	var take_run: BeltPath = null
	var put_run: BeltPath = null
	for link: Dictionary in links:
		var r:= back._link_run(link)
		if int(link ["role"]) == RoboticArm.LINK_TAKE:
			take_run = r
		else:
			put_run = r
	_is("the take link found its belt", take_run != null, true)
	_is("the put link found its belt", put_run != null, true)
	if take_run == null or put_run == null:
		return
	_is("the take belt is the line", (take_run as Conveyor).a.distance_to(line_a) < 0.01
		if take_run is Conveyor else false, true)
	_is("the put belt is the other one", (put_run as Conveyor).a.distance_to(out_a) < 0.01
		if put_run is Conveyor else false, true)

	builds.demolish(put_run)
	await get_tree().physics_frame
	await get_tree().physics_frame
	links = back.links()
	_is("a removed belt drops its link", links.size(), 1)
	_is("and the one left is the take", int(links [0] ["role"]) if links.size() > 0 else -1,
		RoboticArm.LINK_TAKE)
	_is("and the save says so", (back.to_dict().get("links", []) as Array).size(), 1)
