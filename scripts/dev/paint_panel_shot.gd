class_name DevPaintPanelShot
extends Node


var world: Node3D
var player: Player


const BOARD_AT:= Vector3(13.0, 0.06, 5.0)


const STAND_BACK:= 3.2


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--paintpanelshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)

	GameState.add_money(200000.0)
	var builds: BuildManager = world.builds
	var board:= builds.add_paint_board(BOARD_AT, 0.0)
	var panel: PaintPanel = world.get("paint_panel")
	if panel == null:
		push_error("[paintpanelshot] the world stood up no PaintPanel")
		get_tree().quit(1)
		return
	for _i in 12:
		await get_tree().process_frame


	for i in 4:
		board.set_picture(_drawing(i))
		board.keep(["A face", "Waves", "The shed", "Hay, roughly"] [i])
	board.show_kept(0)


	board.tool = PaintBoard.Tool.PEN
	board.width_step = 2
	board.ink = PaintBoard.SWATCHES [3]
	await _shot(panel, board, "%s/paint_panel_tools.png" % out_dir)


	board.tool = PaintBoard.Tool.ERASER
	board.width_step = 3
	board.ink = PaintBoard.SWATCHES [7]
	await _shot(panel, board, "%s/paint_panel_rubber.png" % out_dir)


	await _shot(panel, board, "%s/paint_panel_gallery.png" % out_dir, 1)

	panel.close()
	for _i in 6:
		await get_tree().process_frame


	board.set_picture(_drawing(0))
	await _board_shot(board, "%s/paint_board_in_yard.png" % out_dir)


	Tech.grant("paint_board", 1)
	player.equip_build("paintboard")
	var ahead:= player.global_position + player.look_direction() * 4.0
	player.look_at_from_position(player.global_position,
		Vector3(ahead.x, 0.0, ahead.z), Vector3.UP)
	player.rotation.x = 0.0
	player.set_look(player.rotation.y, -0.34)
	for _i in 10:
		await get_tree().physics_frame
	await _capture("%s/paint_board_hologram.png" % out_dir)
	print("[paintpanelshot] paint_board_hologram.png  %s"
		% player.build.status().get("kind", "?"))

	get_tree().quit()


func _shot(panel: PaintPanel, board: PaintBoard, path: String,
		tab: int = 0) -> void:
	panel.close()
	panel.open(board)
	panel.show_tab(tab)
	for _i in 4:
		await get_tree().physics_frame
	await _capture(path)
	print("[paintpanelshot] %s  tab %d, %d kept, tool %d"
		% [path.get_file(), tab, Sketchbook.count(), int(board.tool)])


func _board_shot(board: PaintBoard, path: String) -> void:
	var mid:= board.to_global(Vector3(0.0, 1.57, 0.0))
	var eye:= mid + board.global_transform.basis.z * STAND_BACK
	var head: float = player.head.position.y if player.head != null else 1.6
	var stand:= eye - Vector3.UP * head
	player.global_position = stand


	player.look_at_from_position(stand, mid, Vector3.UP)
	player.rotation.x = 0.0
	var to_aim:= mid - eye
	player.set_look(player.rotation.y,
		atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))
	for _i in 6:
		await get_tree().physics_frame
	await _capture(path)
	print("[paintpanelshot] %s  from %.1f m out" % [path.get_file(), STAND_BACK])


func _capture(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)


func _drawing(which: int) -> Array:
	var ink: Color = PaintBoard.SWATCHES [[0, 7, 6, 4] [which]]
	var w: float = PaintBoard.WIDTHS [2]
	match which:
		0:
			return [
				_s(PaintBoard.Tool.ELLIPSE, ink, w, [Vector2(0.28, 0.18),
					Vector2(0.72, 0.82)]),
				_s(PaintBoard.Tool.ELLIPSE, ink, w, [Vector2(0.4, 0.36),
					Vector2(0.45, 0.45)]),
				_s(PaintBoard.Tool.ELLIPSE, ink, w, [Vector2(0.55, 0.36),
					Vector2(0.6, 0.45)]),
				_s(PaintBoard.Tool.PEN, ink, w, [Vector2(0.38, 0.58),
					Vector2(0.46, 0.68), Vector2(0.56, 0.68),
					Vector2(0.63, 0.58)]),
			]
		1:
			var out: Array = []
			for row in 4:
				var pts: Array [Vector2] = []
				for i in 21:
					var t:= float(i) / 20.0
					pts.append(Vector2(0.12 + t * 0.76,
						0.28 + float(row) * 0.14 + sin(t * TAU * 1.5) * 0.05))
				out.append(_s(PaintBoard.Tool.PEN, ink, w, pts))
			return out
		2:
			return [
				_s(PaintBoard.Tool.RECT, ink, w, [Vector2(0.22, 0.42),
					Vector2(0.78, 0.8)]),
				_s(PaintBoard.Tool.PEN, ink, w, [Vector2(0.18, 0.44),
					Vector2(0.5, 0.2), Vector2(0.82, 0.44)]),
				_s(PaintBoard.Tool.RECT, ink, w, [Vector2(0.44, 0.58),
					Vector2(0.58, 0.8)]),
			]
		_:
			var out2: Array = []
			for i in 9:
				var x:= 0.18 + float(i) * 0.08
				out2.append(_s(PaintBoard.Tool.LINE, ink, w,
					[Vector2(x, 0.74), Vector2(x + 0.05, 0.3)]))
			return out2


func _s(tool: PaintBoard.Tool, ink: Color, w: float, pts: Array) -> Dictionary:
	var p:= PackedVector2Array()
	for v: Vector2 in pts:
		p.append(v)
	return { "t": int(tool), "c": ink, "w": w, "p": p }
