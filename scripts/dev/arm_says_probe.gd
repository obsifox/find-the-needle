class_name DevArmSaysProbe
extends Node


var world: Node3D

const SETTLE:= 30


const LOAD:= 60
const LOOSE:= 10

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	await _check_no_belt()
	await _check_machine_beside()
	await _check_junction_beside()
	await _check_too_short()
	await _check_out_of_reach()
	await _check_no_room()
	print("\n[armsays] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		_fail(label)


func _arm(where: Vector3) -> RoboticArm:
	var builds: BuildManager = world.builds
	builds.clear()
	for i in SETTLE:
		await get_tree().physics_frame
	var arm:= builds.add_robotic_arm(where, 0.0, 1)
	for i in SETTLE:
		await get_tree().physics_frame
	return arm


func _deck_y() -> float:
	return Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR


func _ask(arm: RoboticArm, load: int = LOAD) -> Dictionary:
	var choice:= arm._choose_drop(load)
	return { "found": not choice.is_empty(), "says": arm.drop_fault_text() }


func _check_no_belt() -> void:
	print("\n=== nothing to put it on ===")
	var arm:= await _arm(Vector3(6.0, 0.0, -6.0))
	var said:= _ask(arm)
	print("        %s" % said ["says"])
	_check("no belt in reach is refused", not said ["found"])
	_check("...and the arm says which", "NO BELT IN REACH" in said ["says"])


func _check_machine_beside() -> void:
	print("\n=== beside a generator, no belt ===")
	var arm:= await _arm(Vector3(6.0, 0.0, -6.0))
	world.builds.add_generator(Vector3(9.0, 0.0, -6.0), 0.0, 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	var said:= _ask(arm)
	print("        %s" % said ["says"])
	_check("no belt beside a machine is refused", not said ["found"])
	_check("...and the sign says belts, not machines",
		"ARMS DROP ONTO BELTS, NOT MACHINES" in said ["says"])
	var called:= Cfg.lower_in_english(BuildCatalog.display_name("generator"))
	_check("...and names the generator", called in said ["says"])
	var plate:= arm._fault_sentence()
	print("        %s" % plate)
	_check("...and the plate says it too", "not machines" in plate and called in plate)


func _check_junction_beside() -> void:
	var cases:= [
		["belt splitter", "splitter", "SPLITTERS", "belt splitter"],
		["U splitter", "u_splitter", "SPLITTERS", "U splitter"],
		["T junction", "t_splitter", "SPLITTERS", "T junction"],
		["belt joiner", "joiner", "JOINERS", "belt joiner"],
		["U joiner", "u_joiner", "JOINERS", "U joiner"],
	]
	for c: Array in cases:
		print("\n=== beside a %s, no belt ===" % c [0])
		var arm:= await _arm(Vector3(6.0, 0.0, -6.0))
		var builds: BuildManager = world.builds
		var at:= Vector3(9.0, 0.0, -6.0)
		match str(c [1]):
			"splitter":
				builds.add_splitter(at, 0.0)
			"u_splitter":
				builds.add_u_splitter(at, 0.0)
			"t_splitter":
				builds.add_t_splitter(at, 0.0)
			"joiner":
				builds.add_joiner(at, 0.0)
			"u_joiner":
				builds.add_u_joiner(at, 0.0)
		for i in SETTLE:
			await get_tree().physics_frame
		var said:= _ask(arm)
		print("        %s" % said ["says"])
		_check("no belt beside a %s is refused" % c [0], not said ["found"])
		_check("...and the sign says NOT %s" % c [2],
			("ARMS DROP ONTO BELTS, NOT %s" % c [2]) in said ["says"])
		_check("...and names the %s" % c [3], ("into the %s" % c [3]) in said ["says"])
		var plate:= arm._fault_sentence()
		print("        %s" % plate)
		_check("...and the plate says it too", ("into the %s." % c [3]) in plate
			and ("not %s" % str(c [2]).to_lower()) in plate)


func _check_too_short() -> void:
	print("\n=== a stub of belt in reach ===")
	var builds: BuildManager = world.builds
	var arm:= await _arm(Vector3(6.0, 0.0, -6.0))


	var a:= Vector3(6.0, _deck_y(), -4.8)
	var run:= builds.add_conveyor(a, a + Vector3(Cfg.BELT_MIN_LENGTH, 0.0, 0.0))
	for i in SETTLE:
		await get_tree().physics_frame
	var path:= run as BeltPath
	var half:= arm._footprint(LOAD)
	print("        run %.2f m, load %.2f m of deck, settling room %.2f m"
		% [path.path_length(), half * 2.0, arm._drop_lead()])


	var said:= _ask(arm)
	_check("a fresh yard still gets a load onto it", said ["found"])
	Tech.grant("belt_speed", TechTree.max_rank("belt_speed"))
	for i in SETTLE:
		await get_tree().physics_frame


	said = _ask(arm)
	print("        at %.2f m/s, a wad: %s"
		% [Tech.belt_speed(), said ["says"] if not said ["found"] else "still takes it"])
	_check("upgraded belts still take a wad", said ["found"])
	said = _ask(arm, LOOSE)
	print("        at %.2f m/s, loose straw: %s"
		% [Tech.belt_speed(), said ["says"] if not said ["found"] else "still takes it"])
	_check("upgraded belts leave it too short for loose straw", not said ["found"])
	_check("...and the arm says so rather than NOWHERE TO PUT IT",
		"BELT TOO SHORT" in said ["says"])
	Tech.grant("belt_speed", 0)
	for i in SETTLE:
		await get_tree().physics_frame


func _check_out_of_reach() -> void:
	print("\n=== a belt it can see and cannot drop on ===")
	var builds: BuildManager = world.builds
	var arm:= await _arm(Vector3(6.0, 0.0, -6.0))


	var reach:= arm.reach_m()
	var shoulder:= arm._shoulder_world()
	var rise:= shoulder.y - _deck_y()
	var inside:= arm.work_reach() - 0.03
	var tip:= Vector3(6.0, _deck_y(),
		shoulder.z + sqrt(inside * inside - rise * rise))
	var run:= builds.add_conveyor(tip + Vector3(0.0, 0.0, 8.0), tip)
	for i in SETTLE:
		await get_tree().physics_frame
	var path:= run as BeltPath
	print("        run %.2f m, reach %.2f m, its end %.2f m from the shoulder"
		% [path.path_length(), reach, tip.distance_to(arm._shoulder_world())])
	var said:= _ask(arm)
	print("        %s" % said ["says"])
	_check("a spot it cannot get to is refused", not said ["found"])
	_check("...and the arm says the belt is out of reach",
		"OUT OF REACH" in said ["says"])


func _check_no_room() -> void:
	print("\n=== a belt in reach with something on it ===")
	var builds: BuildManager = world.builds
	var arm:= await _arm(Vector3(6.0, 0.0, -6.0))
	var a:= Vector3(6.0, _deck_y(), -4.8)
	builds.add_conveyor(a - Vector3(3.0, 0.0, 0.0), a + Vector3(3.0, 0.0, 0.0))
	for i in SETTLE:
		await get_tree().physics_frame
	var said:= _ask(arm)
	_check("an empty belt in reach is taken", said ["found"])
	if not said ["found"]:
		print("        %s" % said ["says"])
		return


	var blockers: Array [StaticBody3D] = []
	for i in 13:
		var blocker:= StaticBody3D.new()
		blocker.collision_layer = Cfg.L_PROP
		blocker.collision_mask = 0
		var shape:= CollisionShape3D.new()
		var box:= BoxShape3D.new()
		box.size = Vector3(0.6, 0.6, 0.6)
		shape.shape = box
		blocker.add_child(shape)
		world.add_child(blocker)
		blocker.global_position = a + Vector3(float(i) * 0.5 - 3.0, 0.3, 0.0)
		blockers.append(blocker)
	for i in SETTLE:
		await get_tree().physics_frame
	said = _ask(arm)
	print("        %s" % said ["says"])
	_check("a covered belt is refused", not said ["found"])
	_check("...and the arm still says NOWHERE TO PUT IT",
		"NOWHERE TO PUT IT" in said ["says"])
	for blocker in blockers:
		blocker.queue_free()
