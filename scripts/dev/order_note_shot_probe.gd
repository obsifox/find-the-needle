class_name DevOrderNoteShotProbe
extends Node


const READING:= 1.5


const ACROSS:= 4.5


const WHOLE_BOARD:= 1.9


var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame

	GameState.add_money(184320.0)


	var was_missions:= Cfg.show_missions
	Cfg.show_missions = false
	Cfg.show_missions_changed.emit(false)


	_look_at("contract", READING)
	await _shot(out_dir, "docket_picked.png", "the crosshair on the contract")
	world.delivery_board.take_press(player.eye_position(), player.look_direction())
	await _shot(out_dir, "docket_pinned.png", "pinned, card in the corner")

	_look_at("note", READING)
	await _shot(out_dir, "note_waiting.png", "the note with nothing ticked")


	world.load_panel.open()
	await _shot(out_dir, "note_panel.png", "E pressed too early")
	world.load_panel.set_open(false)


	GameState.hay_total = GameState.hay_initial * 0.06


	for type in NeedleTypes.pool(GameState.lot_tier):
		GameState.discover(int(type), Vector3.ZERO)
	await _shot(out_dir, "note_offering.png", "case full, crosshair on the note")


	_look_at("note", 0.55)
	await _shot(out_dir, "note_close.png", "the offering note, read up close")
	_look_at("note", READING)


	GameState.debt = 64000.0
	GameState.debt_changed.emit(GameState.debt)
	world.load_panel.open()
	await _shot(out_dir, "note_panel_ready.png", "E pressed on a full case")
	world.load_panel.set_open(false)
	GameState.debt = 0.0
	GameState.debt_changed.emit(0.0)

	_look_at("note", ACROSS)
	await _shot(out_dir, "note_from_afar.png", "the amber offer from across the bay")


	var was_mode: int = Cfg.hay_readout
	for mode: int in [Cfg.HayReadout.PERCENT, Cfg.HayReadout.AMOUNT]:


		Cfg.hay_readout = mode
		Cfg.hay_readout_changed.emit(mode)
		_look_at_point(_cork_middle(), WHOLE_BOARD)


		for i in 24:
			await get_tree().process_frame
		await _shot(out_dir, "board_%s.png" % str(Cfg.HAY_READOUT_NAMES [mode]).to_lower(),
			"the whole board, hay left as %s" % Cfg.HAY_READOUT_NAMES [mode])
	Cfg.hay_readout = was_mode
	Cfg.hay_readout_changed.emit(was_mode)
	Cfg.show_missions = was_missions
	Cfg.show_missions_changed.emit(was_missions)

	get_tree().quit(0)


func _look_at(sheet: String, back: float) -> void:
	var board: DeliveryBoard = world.delivery_board
	var at: Vector3 = board.docket_point() if sheet == "contract" else board.note_point()
	_look_at_point(at, back)


func _look_at_point(at: Vector3, back: float) -> void:
	var board: DeliveryBoard = world.delivery_board


	var out:= board.global_transform.basis * DeliveryBoard.face_normal()
	out.y = 0.0
	var stand:= at + out.normalized() * back
	stand.y = 0.2
	player.global_position = stand
	var to_sheet:= at - player.eye_position()
	player.set_look(atan2(- to_sheet.x, - to_sheet.z),
		atan2(to_sheet.y, Vector2(to_sheet.x, to_sheet.z).length()))


func _cork_middle() -> Vector3:
	var board: DeliveryBoard = world.delivery_board
	return board.to_global(DeliveryBoard.board_to_local(
		Vector3(0.0, DeliveryBoard.CORK_Y, 1.3)))


func _shot(out_dir: String, shot: String, why: String) -> void:
	var board: DeliveryBoard = world.delivery_board
	board._refresh_note()


	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s  ·  %s, picked=%s, offering=%s"
		% [path, why,
			board.hovered_sheet(player.eye_position(), player.look_direction()),
			str(board.can_order())])
