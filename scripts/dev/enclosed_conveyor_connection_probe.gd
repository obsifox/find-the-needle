extends SceneTree


var failures: Array [String] = []
var report: Array [Dictionary] = []
var asset_root: String
var kit: RefCounted


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func route(points: Array [Vector3]) -> Array:
	var runs: Array = []
	for i in points.size() - 1:
		runs.append({ "a": points [i], "b": points [i + 1] })
	return runs


func test_case(label: String, runs: Array, ports: int, bends: int, low: bool = false) -> void:
	var result: Dictionary = kit.build_network(runs, low)
	check(result.error == "", label + ": " + result.error)
	if result.root == null:
		return
	var model: Node3D = result.root
	root.add_child(model)
	var curves:= model.find_children("Bend_*", "MeshInstance3D", true, false)


	check(model.find_children("*", "AnimationPlayer", true, false).is_empty(),
		label + ": no door animation")
	check(model.find_children("Leaf", "MeshInstance3D", true, false).is_empty(),
		label + ": no door leaf")
	check(model.find_children("Terminal", "MeshInstance3D", true, false).size() == ports, label + ": endpoint frame count")
	check(model.find_children("BlackVoid_*", "MeshInstance3D", true, false).size() == ports, label + ": black backing count")
	check(curves.size() == bends, label + ": bend count")
	for curve in curves:
		var arrays: Array = curve.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays [Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
		for vertex in vertices:
			check(vertex.is_finite(), label + ": finite bend coordinates")
		for normal in normals:
			check(normal.is_finite() and absf(normal.length() - 1) < 0.001, label + ": unit normals")
		for i in range(0, indices.size(), 3):
			var a:= vertices [indices [i]]
			var b:= vertices [indices [i + 1]]
			var c:= vertices [indices [i + 2]]
			check((b - a).cross(c - a).length() > 1e-09, label + ": nondegenerate bend faces")
	report.append({ "case": label, "mouths": ports, "bends": curves.size(), "low_detail": low })
	model.free()


func _run() -> void:
	asset_root = OS.get_cmdline_user_args() [0].replace("\\", "/")
	var script: Script = load(asset_root + "/scripts/build/enclosed_conveyor_kit.gd")
	check(script != null and script.can_instantiate(), "Assembly helper compiles")
	if not failures.is_empty():
		quit(1)
		return
	var document:= GLTFDocument.new()
	var state:= GLTFState.new()
	check(document.append_from_file(asset_root + "/assets/models/enclosed_conveyor/enclosed_conveyor_kit.glb", state) == OK, "Kit imports")
	var donor:= document.generate_scene(state)
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset_root + "/assets/models/enclosed_conveyor/enclosed_conveyor_connections.json"))
	kit = script.new(donor, settings)
	donor.free()
	var a:= Vector3(0, 0.43, 0)
	test_case("joined_straights", route([a, a + Vector3(0, 0, 3), a + Vector3(0, 0, 6)]), 2, 0)
	for sign_value in [-1.0, 1.0]:
		for angle in [45.0, 90.0]:
			var joint:= a + Vector3(0, 0, 3)
			var end:= joint + Vector3(sin(deg_to_rad(angle)) * sign_value, 0, cos(deg_to_rad(angle))) * 3
			var runs:= route([a, joint, end])
			runs.reverse()
			test_case("turn_%s_%s" % [sign_value, angle], runs, 2, 1)
	var winding:= route([a, a + Vector3(0, 0, 3), a + Vector3(3.5, 0, 3), a + Vector3(3.5, 0, 6)])
	test_case("two_opposite_bends", winding, 2, 2)
	test_case("two_opposite_bends_lod", winding, 2, 2, true)
	test_case("closed_loop", route([a, a + Vector3(0, 0, 3), a + Vector3(3, 0, 3), a + Vector3(3, 0, 0), a]), 0, 4)
	var separate:= route([a, a + Vector3(0, 0, 3)])
	separate.append({ "a": a + Vector3(5, 0, 0), "b": a + Vector3(5, 0, 3) })
	test_case("disconnected_runs", separate, 4, 0)
	var short_line:= route([a, a + Vector3(0, 0, 0.5)])
	test_case("short_straight", short_line, 2, 0)


	test_case("two_runs_one_start", [{ "a": a, "b": a + Vector3(0, 0, 3) }, { "a": a, "b": a + Vector3(3, 0, 0) }], 4, 0)
	test_case("two_runs_one_end", [{ "a": a + Vector3(0, 0, 3), "b": a }, { "a": a + Vector3(3, 0, 0), "b": a }], 4, 0)


	test_case("right_angle_on_short_legs", route([a, a + Vector3(0, 0, 1), a + Vector3(1, 0, 1)]), 2, 1)


	test_case("tight_short_zigzag", route([a, a + Vector3(0, 0, 0.5), a + Vector3(0.5, 0, 0.5),
		a + Vector3(0.5, 0, 1.0)]), 2, 0)
	for invalid in [route([a, a])]:
		var result: Dictionary = kit.build_network(invalid)
		check(result.root == null and not result.error.is_empty(), "Invalid network rejected without a partial model")
	var file:= FileAccess.open(asset_root + "/docs/enclosed_conveyor/connection_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({ "cases": report, "failures": failures, "result": "PASS" if failures.is_empty() else "FAIL" }, "  ") + "\n")
	print("ENCLOSED CONNECTIONS: ", "PASS" if failures.is_empty() else "FAIL", "; ", report.size(), " valid layouts")
	quit(0 if failures.is_empty() else 1)
