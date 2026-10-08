class_name DevBeltDrumProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30


const A:= Vector3(13.0, 0.75, -5.0)
const B:= Vector3(13.0, 0.75, 5.0)

var _pass:= 0
var _fail:= 0


func _ok(label: String, good: bool, detail: String = "") -> void:
	if good:
		_pass += 1
	else:
		_fail += 1
	print("  %s %-42s %s" % ["ok  " if good else "FAIL", label, detail])


func run() -> void:
	for _i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(11.0, 0.4, 0.0)
	GameState.add_money(1000.0)
	for _i in SETTLE:
		await get_tree().process_frame

	await _case_materials()
	await _case_free_run()
	await _case_bend()
	await _case_reverse()

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _case_materials() -> void:
	print("\n=== materials ===")
	var drum:= ConveyorKit.drum_material()
	var roller:= ConveyorKit.roller_material()
	_ok("drum steel is not the roller's material", drum != roller,
		"else the splitter's flat-UV'd pulley slides too")

	var speed: float = drum.get_shader_parameter("speed")
	var want:= Tech.belt_speed()


	_ok("drum turns at belt speed", is_equal_approx(speed, want),
		"drum %.3f, belt %.3f" % [speed, want])
	_ok("still steel does not move",
		is_zero_approx(float(roller.get_shader_parameter("speed"))
			if roller.get_shader_parameter("speed") != null else 0.0))


	ConveyorKit.set_belt_speed(want * 2.0)
	_ok("a motor upgrade retimes the drums",
		is_equal_approx(float(drum.get_shader_parameter("speed")), want * 2.0),
		"drum now %.3f" % float(drum.get_shader_parameter("speed")))
	ConveyorKit.set_belt_speed(want)

	for named in [["head", true], ["tail", false]]:
		var mesh:= ConveyorKit.nose_mesh(bool(named [1]))
		_ok("%s drum mesh loaded" % named [0], mesh != null)
		if mesh == null:
			continue
		_ok("%s drum has 3 surfaces" % named [0], mesh.get_surface_count() == 3,
			"got %d" % mesh.get_surface_count())
		var mats:= { }
		for i in mesh.get_surface_count():
			mats [mesh.surface_get_material(i)] = true
		_ok("%s drum carries rubber, frame and turning steel" % named [0],
			mats.has(ConveyorKit.belt_material())
				and mats.has(ConveyorKit.frame_material())
				and mats.has(drum))


	_ok("head and tail are different meshes",
		ConveyorKit.nose_mesh(true) != ConveyorKit.nose_mesh(false))


func _case_free_run() -> void:
	print("\n=== a free run ===")
	var run:= _build(A, B)
	if run == null:
		_ok("built a test run", false)
		return
	var drums:= _drums_of(run)
	_ok("a free run grows two drums", drums.size() == 2, "got %d" % drums.size())
	if drums.size() != 2:
		_teardown()
		return

	var fwd:= (B - A).normalized()
	var head: MeshInstance3D = null
	var tail: MeshInstance3D = null
	for mi in drums:
		if mi.mesh == ConveyorKit.nose_mesh(true):
			head = mi
		else:
			tail = mi
	_ok("one head and one tail", head != null and tail != null)
	if head == null or tail == null:
		_teardown()
		return

	_ok("head stands at the laid end",
		head.global_position.distance_to(run.laid_end()) < 0.01,
		"%.3f m out" % head.global_position.distance_to(run.laid_end()))
	_ok("tail stands at the laid start",
		tail.global_position.distance_to(run.laid_start()) < 0.01,
		"%.3f m out" % tail.global_position.distance_to(run.laid_start()))


	var hz:= head.global_transform.basis.z.dot(fwd)
	var tz:= tail.global_transform.basis.z.dot(fwd)
	_ok("head faces the way the run drives", hz > 0.99, "dot %+.3f" % hz)
	_ok("tail faces back down it", tz < -0.99, "dot %+.3f" % tz)

	_ok("both stand the right way up",
		head.global_transform.basis.y.dot(tail.global_transform.basis.y) > 0.99)
	_teardown()


func _case_bend() -> void:
	print("\n=== a bend at one end ===")
	var first:= _build(A, B)
	var second:= _build(B, B + Vector3(6.0, 0.0, 0.0))
	if first == null or second == null:
		_ok("built two runs that meet", false)
		_teardown()
		return
	for _i in SETTLE:
		await get_tree().process_frame

	_ok("a corner was fitted", first.trim_end > 0.0 and second.trim_start > 0.0,
		"trims %.2f / %.2f" % [first.trim_end, second.trim_start])
	var d1:= _drums_of(first)
	var d2:= _drums_of(second)
	_ok("the run into the bend keeps only its tail", d1.size() == 1
			and d1 [0].mesh == ConveyorKit.nose_mesh(false),
		"%d drum(s)" % d1.size())
	_ok("the run out of it keeps only its head", d2.size() == 1
			and d2 [0].mesh == ConveyorKit.nose_mesh(true),
		"%d drum(s)" % d2.size())


	first.set_trim(0.0, 0.0)
	for _i in 5:
		await get_tree().process_frame
	var back:= _drums_of(first)
	_ok("the drum comes back when the bend goes", back.size() == 2,
		"%d drum(s)" % back.size())
	_teardown()


func _case_reverse() -> void:
	print("\n=== turned round ===")
	var run:= _build(A, B)
	if run == null:
		_ok("built a test run", false)
		return
	var before:= _head_of(run)
	_ok("head starts at B", before != null
			and before.global_position.distance_to(B) < 0.01)
	world.builds.reverse_conveyor(run)
	for _i in 5:
		await get_tree().process_frame
	var after:= _head_of(run)
	_ok("head moved to the other end", after != null
			and after.global_position.distance_to(A) < 0.01,
		"" if after == null else "%.3f m from A"
			% after.global_position.distance_to(A))
	_ok("still exactly two drums", _drums_of(run).size() == 2,
		"%d" % _drums_of(run).size())
	_teardown()


func _head_of(run: Conveyor) -> MeshInstance3D:
	for mi in _drums_of(run):
		if mi.mesh == ConveyorKit.nose_mesh(true):
			return mi
	return null


func _build(from: Vector3, to: Vector3) -> Conveyor:
	return world.builds.add_conveyor(from, to)


func _drums_of(run: Conveyor) -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	var root:= run.get_node_or_null("Drums")
	if root == null:
		return out
	for child in root.get_children():
		var mi:= child as MeshInstance3D
		if mi != null:
			out.append(mi)
	return out


func _teardown() -> void:
	for c in world.builds.conveyors.duplicate():
		world.builds.demolish(c)
