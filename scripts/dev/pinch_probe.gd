class_name DevPinchProbe
extends Node

## V40.1 regression probe: verify the tech-board pinch zoom end to end by
## pushing raw InputEventScreenTouch / InputEventScreenDrag pairs (and an
## InputEventMagnifyGesture) through the REAL input pipeline while the tech
## menu is open. Run headless:  godot --headless -- --pinchprobe

var world: Node3D
var player: Node

var _fail: int = 0


func run() -> void:
	print("\n=== pinch zoom ===")
	await _case_raw_touch(false)
	await _case_raw_touch(true)
	await _case_magnify()
	print("=== pinch zoom: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _panel() -> Node:
	return world.get("tech_panel")


func _case_raw_touch(emulated_mouse: bool) -> void:
	var panel: Node = _panel()
	if panel == null:
		_bad("no tech panel on the world")
		return
	panel.call("set_open", true)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.emulate_mouse_from_touch = emulated_mouse
	var z0: float = panel.get("_zoom")
	_push_touch(0, Vector2(600, 450), true)
	_push_touch(1, Vector2(760, 620), true)
	await get_tree().process_frame
	_push_drag(0, Vector2(540, 450))
	_push_drag(1, Vector2(820, 620))
	await get_tree().process_frame
	await get_tree().process_frame
	var z1: float = panel.get("_zoom")
	if absf(z1 - z0) < 0.001:
		_bad("spread did not change zoom (emulate_mouse=%s): %.4f -> %.4f" % [emulated_mouse, z0, z1])
	else:
		print("spread (emulate_mouse=%s): zoom %.4f -> %.4f" % [emulated_mouse, z0, z1])
	var z2: float = z1
	_push_drag(0, Vector2(600, 450))
	_push_drag(1, Vector2(700, 560))
	await get_tree().process_frame
	await get_tree().process_frame
	var z3: float = panel.get("_zoom")
	if absf(z3 - z2) < 0.001:
		_bad("close did not change zoom (emulate_mouse=%s)" % emulated_mouse)
	else:
		print("close  (emulate_mouse=%s): zoom %.4f -> %.4f" % [emulated_mouse, z2, z3])
	_push_touch(0, Vector2(600, 450), false)
	_push_touch(1, Vector2(700, 560), false)
	await get_tree().process_frame
	panel.call("set_open", false)
	await get_tree().process_frame


func _case_magnify() -> void:
	var panel: Node = _panel()
	if panel == null:
		_bad("no tech panel for magnify case")
		return
	panel.call("set_open", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var z0: float = panel.get("_zoom")
	var mg:= InputEventMagnifyGesture.new()
	mg.position = Vector2(600, 450)
	mg.factor = 1.35
	Input.parse_input_event(mg)
	await get_tree().process_frame
	await get_tree().process_frame
	var z1: float = panel.get("_zoom")
	if absf(z1 - z0) < 0.001:
		_bad("magnify gesture did not change zoom")
	else:
		print("magnify: zoom %.4f -> %.4f" % [z0, z1])
	panel.call("set_open", false)
	await get_tree().process_frame


func _push_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev:= InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _push_drag(index: int, pos: Vector2) -> void:
	var ev:= InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = Vector2.ZERO
	Input.parse_input_event(ev)


func _bad(what: String) -> void:
	_fail += 1
	print("  BAD: %s" % what)
