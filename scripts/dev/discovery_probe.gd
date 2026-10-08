class_name DevDiscoveryProbe
extends Node


var world: Node3D
var builds: BuildManager
var player: Player
var card: DiscoveryCard
var inspector: NeedleInspector

var _pass:= 0
var _fail:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func run() -> void:
	world.set("block_save", true)
	print("--- discovery probe ---")
	await get_tree().process_frame
	await _check_wiring()
	await _check_inspector()
	await _check_specimens()
	print("\n[discovery] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check_wiring() -> void:
	print("\n-- the card --")
	GameState.reset(2211, 0.0)
	_ok(card != null and inspector != null, "the world built both panels")
	if card == null:
		return
	var cab:= builds.add_cabinet(Vector3(3.0, 0.0, 3.0), 0.0)
	await get_tree().process_frame
	cab.open_doors()

	var t:= 3
	_ok(not card.is_playing(), "nothing on screen to start with")
	var idx:= GameState.register_needle(Vector3.ZERO, null, t)
	cab.accept(idx)


	await get_tree().process_frame
	_ok(not card.is_playing(), "...and not while the mote is still flying")
	var guard:= 0
	while not card.is_playing() and guard < 400:
		await get_tree().process_frame
		guard += 1
	_ok(card.is_playing(), "the card came up when the specimen landed")
	_ok(GameState.is_discovered(t), "...for a type that is now in the case")


	card.dismiss()
	for i in 40:
		await get_tree().process_frame
	var again:= GameState.register_needle(Vector3.ZERO, null, t)
	cab.accept(again)
	for i in 90:
		await get_tree().process_frame
	_ok(not card.is_playing(), "a duplicate got no card")
	builds.clear()
	await get_tree().process_frame


func _check_inspector() -> void:
	print("\n-- the inspector --")
	if inspector == null:
		return
	_ok(not inspector.is_open(), "starts shut")
	inspector.open(9)
	await get_tree().process_frame
	_ok(inspector.is_open() and inspector.visible, "opens on a type")

	_ok(player != null and not player.is_mouse_captured(),
		"...and hands the mouse back")


	_ok(player != null and player.inspector == inspector,
		"the player knows to stand down while it is up")


	var before:= inspector.specimen_yaw()
	await _drag(inspector.size * 0.5, Vector2(inspector.size.x * 0.4, 0.0))
	_ok(not is_equal_approx(inspector.specimen_yaw(), before),
		"dragging over the specimen turns it (%.3f -> %.3f)"
		% [before, inspector.specimen_yaw()])


	await _press("interact")
	_ok(not inspector.is_open(), "E closes it")
	_ok(player != null and player.is_mouse_captured(),
		"...and takes the mouse back")


	inspector.open(9)
	await get_tree().process_frame
	await _click(inspector.size * 0.5, MOUSE_BUTTON_RIGHT)
	_ok(not inspector.is_open(), "the right button closes it")


	var pause: PauseMenu = world.get("pause_menu") as PauseMenu
	if pause != null:
		inspector.open(9)
		await get_tree().process_frame
		await _press("free_mouse")
		_ok(not inspector.is_open(), "Escape closes it")
		_ok(not pause.is_open(), "...without raising the pause menu")
		await _press("free_mouse")
		_ok(pause.is_open(), "the next Escape is the menu")
		pause.set_open(false)
		await get_tree().process_frame


func _press(action: String) -> void:
	var ev:= InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_viewport().push_input(ev)
	await get_tree().process_frame


func _click(at: Vector2, button: MouseButton) -> void:
	for down: bool in [true, false]:
		var ev:= InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = down
		ev.position = at
		get_viewport().push_input(ev)
		await get_tree().process_frame


func _drag(at: Vector2, by: Vector2) -> void:
	var down:= InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	get_viewport().push_input(down)
	await get_tree().process_frame
	var move:= InputEventMouseMotion.new()
	move.position = at + by
	move.relative = by
	get_viewport().push_input(move)
	await get_tree().process_frame
	var up:= InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at + by
	get_viewport().push_input(up)
	await get_tree().process_frame


func _check_specimens() -> void:
	print("\n-- specimens --")
	var missing:= PackedStringArray()
	for t in NeedleTypes.count():
		if StrandFactory.needle_model(t) == null:
			missing.append(NeedleTypes.name_of(t))
	_ok(missing.is_empty(), "all %d specimens have a mesh to draw%s"
		% [NeedleTypes.count(),
			"" if missing.is_empty() else " (missing %s)" % ", ".join(missing)])


func shoot(out_dir: String) -> void:
	world.set("block_save", true)
	GameState.reset(2212, 0.0)
	var cab:= builds.add_cabinet(Vector3(3.0, 0.0, 3.0), 0.0)
	await get_tree().process_frame
	cab.open_doors()
	if player != null:
		player.global_position = cab.read_position() - Vector3(0, 1.35, 0)


	var t:= NeedleTypes.count() - 1
	card.play(t)

	for i in 55:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var a:= "%s/discovery_card.png" % out_dir
	get_viewport().get_texture().get_image().save_png(a)
	print("wrote %s" % a)

	card.dismiss()
	inspector.open(t)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var b:= "%s/needle_inspector.png" % out_dir
	get_viewport().get_texture().get_image().save_png(b)
	print("wrote %s" % b)
	get_tree().quit(0)
