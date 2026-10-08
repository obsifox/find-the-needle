class_name DevRestoreSliceProbe
extends Node


const SLICE:= 50000


const SETTLE:= 10

var world: Node3D

var _worst_usec:= 0
var _frame_usec:= 0


func run() -> void:
	world.block_save = true


	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--restoreslice")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("RESTORESLICE: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("RESTORESLICE: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		world.field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))
	var buildings: Array = d.get("buildings", [])
	var builds: BuildManager = world.builds
	print("RESTORESLICE: %d buildings, slice %d ms, block_save=%s"
		% [buildings.size(), SLICE / 1000, world.block_save])

	builds.restore_slice_usec = 0
	var t:= Time.get_ticks_usec()
	builds.from_array(buildings)
	print("RESTORESLICE: one call, %.0f ms in one frame" % ((Time.get_ticks_usec() - t) / 1000.0))
	await _settle()
	var whole:= var_to_str(builds.to_array())

	builds.restore_slice_usec = SLICE
	_worst_usec = 0
	_frame_usec = Time.get_ticks_usec()
	get_tree().process_frame.connect(_on_frame)
	t = Time.get_ticks_usec()
	await builds.from_array(buildings)
	_on_frame()
	builds.restore_slice_usec = 0
	print("RESTORESLICE: sliced, %.0f ms over several frames, worst frame %.0f ms"
		% [(Time.get_ticks_usec() - t) / 1000.0, _worst_usec / 1000.0])


	_worst_usec = 0
	await _settle()
	get_tree().process_frame.disconnect(_on_frame)
	print("RESTORESLICE: the frames after it, worst %.0f ms" % (_worst_usec / 1000.0))
	var sliced:= var_to_str(builds.to_array())

	var same:= whole == sliced
	if not same:
		_print_first_difference(whole, sliced)
	print("\n[probe] %s" % ("PASS" if same else "FAIL: the sliced restore is a different yard"))
	get_tree().quit(0 if same else 1)


func _on_frame() -> void:
	var now:= Time.get_ticks_usec()
	_worst_usec = maxi(_worst_usec, now - _frame_usec)
	_frame_usec = now


func _settle() -> void:
	for n in SETTLE:
		await get_tree().physics_frame
		await get_tree().process_frame


func _print_first_difference(a: String, b: String) -> void:
	var la:= a.split("\n")
	var lb:= b.split("\n")
	for n in mini(la.size(), lb.size()):
		if la [n] != lb [n]:
			print("  first difference at line %d:\n    one call: %s\n    sliced:   %s"
				% [n, la [n].left(200), lb [n].left(200)])
			return
	print("  one is a prefix of the other: %d lines against %d" % [la.size(), lb.size()])
