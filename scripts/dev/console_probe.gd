class_name DevConsoleProbe
extends Node


const SETTLE:= 8

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  [pass] %s" % what)
	else:
		_fail += 1
		print("  [FAIL] %s" % what)


func run() -> void:


	world.block_save = true
	print("--- console probe ---")
	for i in SETTLE:
		await get_tree().process_frame
	GameState.add_money(200000.0)
	player.capture_mouse(true)
	for i in SETTLE:
		await get_tree().process_frame

	await _case_generator_behind_a_splitter()
	await _case_splitter_still_answers()
	await _case_nothing_aimed_offers_nothing()
	await _case_scanner_has_a_plate()
	await _case_escape_closes_the_console()

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])


	get_tree().quit(1 if _fail > 0 else 0)


func _case_generator_behind_a_splitter() -> void:
	print("\n=== a generator with a splitter beside it ===")
	var here:= Vector3(-11.0, 0.4, 6.0)
	player.global_position = here
	var boiler: HayGenerator = world.builds.add_generator(here + Vector3(0.0, 0.0, -2.6), 0.0)


	var splitter: ConveyorSplitter = world.builds.add_splitter(here + Vector3(1.4, 0.0, 0.4), 0.0)
	for i in 20:
		await get_tree().physics_frame
	_ok(boiler != null and splitter != null, "a generator and a splitter are stood in the yard")
	if boiler == null or splitter == null:
		return
	_ok(player.eye_position().distance_to(splitter.global_position)
		< Cfg.SPLITTER_CONSOLE_REACH,
		"the splitter is inside its own reach of the player (%.2f m)"
			% player.eye_position().distance_to(splitter.global_position))

	await _aim_at(boiler.global_position + Vector3.UP * 1.0)
	var aimed: Node3D = world.builds.console_under(player.eye_position(), player.look_direction())
	_ok(aimed == boiler, "aiming at the generator resolves the GENERATOR, got %s"
		% _name_of(aimed))
	_ok(world.hud == null or world.hud._prompt_wanted() == "machine",
		"...and the plate over the crosshair says MACHINE SWITCH, got '%s'"
			% (world.hud._prompt_wanted() if world.hud != null else "no hud"))


	player._interact_with_the_world()
	await get_tree().process_frame
	_ok(player.machine_panel != null and player.machine_panel.is_open()
		and player.machine_panel.machine() == boiler,
		"...and E opens the switch panel on the generator")
	_ok(player.splitter_panel == null or not player.splitter_panel.is_open(),
		"...and never the splitter's")
	if player.machine_panel != null and player.machine_panel.is_open():
		player.machine_panel.close()
	await get_tree().process_frame


func _case_splitter_still_answers() -> void:
	print("\n=== the splitter, looked at ===")
	var all_splitters: Array = world.builds.splitters
	var splitter: ConveyorSplitter = null
	if not all_splitters.is_empty():
		splitter = all_splitters [all_splitters.size() - 1] as ConveyorSplitter
	if splitter == null:
		_ok(false, "there is a splitter to aim at")
		return
	await _aim_at(splitter.global_position + Vector3.UP * 0.2)
	var aimed: Node3D = world.builds.console_under(player.eye_position(), player.look_direction())
	_ok(aimed == splitter, "aiming at the splitter resolves the SPLITTER, got %s"
		% _name_of(aimed))
	_ok(world.hud == null or world.hud._prompt_wanted() == "splitter",
		"...and the plate says ADJUST SPLITTER, got '%s'"
			% (world.hud._prompt_wanted() if world.hud != null else "no hud"))
	player._interact_with_the_world()
	await get_tree().process_frame
	_ok(player.splitter_panel != null and player.splitter_panel.is_open()
		and player.splitter_panel.splitter() == splitter,
		"...and E opens the splitter's panel")
	if player.splitter_panel != null and player.splitter_panel.is_open():
		player.splitter_panel.close()
	await get_tree().process_frame


func _case_nothing_aimed_offers_nothing() -> void:
	print("\n=== nothing under the crosshair ===")
	player.set_look(player.rotation.y, 1.2)
	for i in 3:
		await get_tree().physics_frame
	var aimed: Node3D = world.builds.console_under(player.eye_position(), player.look_direction())
	_ok(aimed == null, "nothing is under the crosshair, got %s" % _name_of(aimed))
	_ok(world.hud == null or world.hud._prompt_wanted() != "splitter",
		"...and the plate does not say ADJUST SPLITTER, got '%s'"
			% (world.hud._prompt_wanted() if world.hud != null else "no hud"))
	player._interact_with_the_world()
	await get_tree().process_frame
	_ok(player.splitter_panel == null or not player.splitter_panel.is_open(),
		"...and E does not open the splitter's panel")
	if player.splitter_panel != null and player.splitter_panel.is_open():
		player.splitter_panel.close()
	player.set_look(player.rotation.y, 0.0)
	for i in 3:
		await get_tree().physics_frame


func _case_scanner_has_a_plate() -> void:
	print("\n=== the scanner's plate ===")
	var scanner: HaystackScanner = world.builds.add_scanner(
		player.global_position + Vector3(-2.6, 0.0, 0.0), 0.0)
	for i in SETTLE:
		await get_tree().physics_frame
	if scanner == null or world.hud == null:
		_ok(false, "a scanner and a HUD to read it off")
		return


	var screen:= scanner.console_position()
	var out:= screen - scanner.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	player.global_position = Vector3(screen.x, player.global_position.y, screen.z) + out * 1.4
	for i in 4:
		await get_tree().physics_frame
	await _aim_at(screen)
	var under: Node3D = world.builds.scanner_under(player.eye_position(), player.look_direction())
	_ok(under == scanner, "aiming at the scanner resolves it (%.2f m to its screen), got %s"
		% [player.eye_position().distance_to(scanner.console_position()), _name_of(under)])
	for i in 3:
		await get_tree().process_frame
	_ok(world.hud._prompt_wanted() == "scanner:empty",
		"...and the plate is up for an empty scanner, got '%s'" % world.hud._prompt_wanted())
	_ok(world.hud._prompt_title.text == "NEEDLE SCANNER",
		"...naming the machine, got '%s'" % world.hud._prompt_title.text)
	_ok(not world.hud._prompt_cap.visible
		and (world.hud._prompt_icon == null or not world.hud._prompt_icon.visible),
		"...with no key on it, because E has nothing to do there")
	player.set_look(player.rotation.y, 1.2)
	for i in 3:
		await get_tree().physics_frame
	_ok(not world.hud._prompt_wanted().begins_with("scanner"),
		"looking away takes the scanner's plate down, got '%s'" % world.hud._prompt_wanted())
	player.set_look(player.rotation.y, 0.0)
	world.builds.demolish(scanner)
	for i in SETTLE:
		await get_tree().physics_frame


func _case_escape_closes_the_console() -> void:
	print("\n=== escape, at an open console ===")
	var pause: PauseMenu = world.get("pause_menu")
	if pause == null:
		_ok(false, "there is a pause menu to test against")
		return
	var boiler: HayGenerator = null
	if not world.builds.generators.is_empty():
		boiler = world.builds.generators [0] as HayGenerator
	if boiler == null:
		_ok(false, "there is a generator to open")
		return

	player.machine_panel.open(boiler)
	await get_tree().process_frame
	_ok(player.machine_panel.is_open(), "the switch panel is up")
	await _escape()
	_ok(not player.machine_panel.is_open(), "escape shuts the switch panel")
	_ok(not pause.is_open(), "...and does not raise the pause menu over it")
	if pause.is_open():
		pause.set_open(false)
		await get_tree().process_frame

	var splitter: ConveyorSplitter = null
	if not world.builds.splitters.is_empty():
		splitter = world.builds.splitters [0] as ConveyorSplitter
	if splitter != null:
		player.splitter_panel.open(splitter)
		await get_tree().process_frame
		await _escape()
		_ok(not player.splitter_panel.is_open(), "escape shuts the splitter's panel")
		_ok(not pause.is_open(), "...and does not raise the pause menu over it")
		if pause.is_open():
			pause.set_open(false)
			await get_tree().process_frame


	var here:= player.global_position
	var rake: PistonRake = world.builds.add_piston_rake(here + Vector3(6.0, 0.0, -6.0), 0.0)
	var gun: TubeLauncher = world.builds.add_tube_launcher(here + Vector3(-6.0, 0.0, -6.0), 0.0)
	var tank: HaySilo = world.builds.add_silo(here + Vector3(6.0, 0.0, 6.0), 0.0)
	var robot: RoboticArm = world.builds.add_robotic_arm(here + Vector3(-6.0, 0.0, 6.0), 0.0)
	var board: PaintBoard = world.builds.add_paint_board(here + Vector3(0.0, 0.0, 8.0), 0.0)
	var mill: HayPelletizer = world.builds.add_pelletizer(here + Vector3(0.0, 0.0, -9.0), 0.0)
	for i in 10:
		await get_tree().physics_frame
	for row: Dictionary in [
			{ "what": "the rake's", "panel": player.rake_panel, "on": rake },
			{ "what": "the launcher's", "panel": player.launcher_panel, "on": gun },
			{ "what": "the silo's", "panel": player.silo_panel, "on": tank },
			{ "what": "the arm's", "panel": player.arm_panel, "on": robot },
			{ "what": "the paint board's", "panel": player.paint_panel, "on": board },
			{ "what": "the mill's", "panel": player.pelletizer_panel, "on": mill }]:
		var panel: Node = row ["panel"]
		var on: Node = row ["on"]
		if panel == null or on == null:
			_ok(false, "%s panel and the machine it opens on both exist" % row ["what"])
			continue
		panel.call("open", on)
		await get_tree().process_frame
		await _escape()
		_ok(not panel.call("is_open"), "escape shuts %s panel" % row ["what"])
		_ok(not pause.is_open(), "...and does not raise the pause menu over it")
		if panel.call("is_open"):
			panel.call("close")
		if pause.is_open():
			pause.set_open(false)
		await get_tree().process_frame


	if player.needle_panel != null:
		player.needle_panel.open()
		await get_tree().process_frame
		await _escape()
		_ok(not player.needle_panel.is_open(), "escape shuts the needles sheet")
		_ok(not pause.is_open(), "...and does not raise the pause menu over it")
		if player.needle_panel.is_open():
			player.needle_panel.set_open(false)
		if pause.is_open():
			pause.set_open(false)
		await get_tree().process_frame


	await _escape()
	_ok(pause.is_open(), "with no panel up, escape raises the pause menu")
	if pause.is_open():
		pause.set_open(false)
		await get_tree().process_frame


func _escape() -> void:
	var ev:= InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	get_viewport().push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _aim_at(target: Vector3) -> void:
	var eye:= player.camera.global_position
	var flat:= Vector2(target.x - eye.x, target.z - eye.z).length()
	player.set_look(atan2(target.x - eye.x, target.z - eye.z) + PI,
		atan2(target.y - eye.y, maxf(flat, 0.001)))
	for i in 3:
		await get_tree().physics_frame


func _name_of(machine: Node) -> String:
	return "nothing" if machine == null else machine.get_class() + "/" + str(machine)
