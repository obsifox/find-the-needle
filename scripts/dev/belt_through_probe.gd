class_name DevBeltThroughProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 40

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var tool: BuildTool = player.build
	var builds: BuildManager = world.builds
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	GameState.add_money(1000000.0)


	tool.set_active(false)
	tool._mode = BuildTool.Mode.CONVEYOR


	var cases: Array = [
		["compressor", builds.add_compressor(Vector3(-14.0, lift, -24.0), 0.0)],
		["scanner", builds.add_scanner(Vector3(-14.0, lift, -12.0), 0.0)],
		["wrapper", builds.add_wrapper(Vector3(-14.0, lift, 0.0), 0.0)],
		["silo", builds.add_silo(Vector3(-14.0, 0.0, 12.0), 0.0)],
		["splitter", builds.add_splitter(Vector3(-22.0, lift, -24.0), 0.0)],
		["joiner", builds.add_joiner(Vector3(-22.0, lift, -12.0), 0.0)],
		["T splitter", builds.add_t_splitter(Vector3(-22.0, lift, 0.0), 0.0)],
	]
	for i in 8:
		await get_tree().physics_frame

	for c: Array in cases:
		_machine(tool, String(c [0]), c [1] as Node3D)
	_silo_tank(tool, cases [3] [1] as Node3D)

	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit()


func _machine(tool: BuildTool, label: String, machine: Node3D) -> void:
	print("\n=== %s ===" % label)
	var decks: Array [BeltPath] = []
	for n in machine.find_children("*", "BeltPath", true, false):
		var p:= n as BeltPath
		if p != null and p.centre_line().size() >= 2:
			decks.append(p)
	if decks.is_empty():
		_check("%s owns a deck to test" % label, false)
		return
	for i in decks.size():
		var deck:= decks [i]
		var line:= deck.centre_line()
		var head:= line [0]
		var tail:= line [line.size() - 1]
		var along:= (tail - head).normalized()
		var side:= along.cross(Vector3.UP).normalized()
		var mid:= (head + tail) * 0.5
		var name:= "%s deck %d (%s)" % [label, i, deck.name]
		print("  %s: %v to %v" % [name, head, tail])


		_say(tool, "%s: along it and out the far side" % name,
			head - along * 2.0, tail + along * 2.0)

		_say(tool, "%s: half way in" % name, head - along * 2.0, mid)

		_say(tool, "%s: square across the middle" % name,
			mid - side * 3.0, mid + side * 3.0)


func _silo_tank(tool: BuildTool, silo: Node3D) -> void:
	print("\n=== silo tank ===")
	var c:= silo.global_position
	var y:= 0.75
	while y <= 4.76:


		_say(tool, "across the tank (x) at %.2f" % y,
			c + Vector3(-2.5, y, 0.0), c + Vector3(2.5, y, 0.0))
		_say(tool, "across the tank (z) at %.2f" % y,
			c + Vector3(0.0, y, -4.0), c + Vector3(0.0, y, 4.0))
		y += 0.25
	_say(tool, "ramp down through the mouth",
		c + Vector3(-2.5, 5.0, 0.0), c + Vector3(2.5, 3.2, 0.0))


func _say(tool: BuildTool, label: String, from: Vector3, to: Vector3) -> void:
	var v: Dictionary = tool._evaluate(from, to, true)
	var ok:= bool(v ["ok"])
	var hit:= tool._obstruction(from, to, from.distance_to(to))
	var named:= str((hit as Node).get_path()) if hit is Node else "-"
	_check("%s is refused (%s, hit %s)"
		% [label, v ["reason"] if not ok else "GREEN", named], not ok)


func _check(label: String, good: bool) -> void:
	if not good:
		_fails += 1
	print("  %-4s %s" % ["ok" if good else "BAD", label])
