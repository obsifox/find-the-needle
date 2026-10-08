class_name DevTechShotProbe
extends Node


const SURGE_FRAMES:= 24
const SURGE_GAP:= 0.03

var world: Node3D
var player: Player
var panel: TechPanel


func shoot_surge(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	Tech.reset()

	var deep:= ""
	var deepest:= -1
	for id: String in TechTree.ids():
		var d:= _depth(id)
		if d > deepest:
			deepest = d
			deep = id
	for need: String in _ancestors(deep):
		Tech.grant(need, TechTree.max_rank(need))
	_set_money(250000.0)


	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.6)

	panel.set_open(true)
	panel._select(deep)
	await get_tree().process_frame
	await get_tree().process_frame


	await _shot(out_dir, "surge_0_before.png")

	panel._buy_selected()
	for i in SURGE_FRAMES:
		await _shot(out_dir, "surge_%d.png" % (i + 1))
		await _wait(SURGE_GAP)
	get_tree().quit(0)


func shoot_search(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	Tech.reset()


	Tech.grant("spade", 1)
	Tech.grant("broom", 1)
	Tech.grant("bucket", 1)
	Tech.grant("belt", 1)
	Tech.grant("belt_speed", 2)
	Tech.grant("deck", 1)
	_set_money(6000.0)

	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.6)

	panel.set_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir, "search_0_board.png")


	panel._search.text = "belt"
	panel._apply_filter("belt")
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir, "search_1_belt.png")

	panel._search.text = "drone"
	panel._apply_filter("drone")
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir, "search_2_drone.png")

	panel._clear_filter()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir, "search_3_cleared.png")
	get_tree().quit(0)


func shoot_ring(out_dir: String) -> void:
	if world != null:
		world.block_save = true
		var director: MissionDirector = world.get("missions")
		if director != null:
			director.process_mode = Node.PROCESS_MODE_DISABLED
	Tech.reset()
	for need: String in _ancestors("belt_speed"):
		Tech.grant(need, 1)
	_set_money(400.0)

	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.6)

	panel.set_hint("belt_speed")
	panel.set_open(true)

	for i in 4:
		await get_tree().process_frame
	await _shot(out_dir, "ring_0_open.png")
	await _wait(MissionCue.PULSE * 0.5)
	await _shot(out_dir, "ring_1_half_breath.png")

	panel._fit_board()
	var fitted:= panel._zoom
	panel.set_open(false)
	await get_tree().process_frame
	panel.set_open(true)
	for i in 4:
		await get_tree().process_frame
	await _wait(MissionCue.PULSE * 0.25)
	print("ring reopen: zoom %.2f (fitted %.2f), jumped again %s, ring animating %s"
		% [panel._zoom, fitted, not is_equal_approx(panel._zoom, fitted),
		panel.is_processing()])
	await _shot(out_dir, "ring_2_reopened.png")

	Tech.grant("belt_speed", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir, "ring_3_bought.png")
	get_tree().quit(0)


func _ancestors(id: String) -> Array [String]:
	var out: Array [String] = []
	var seen:= { }
	var frontier: Array [String] = [id]
	while not frontier.is_empty():
		var next: Array [String] = []
		for node: String in frontier:
			for need: String in TechTree.requires(node):
				var s:= str(need)
				if seen.has(s):
					continue
				seen [s] = true
				out.append(s)
				next.append(s)
		frontier = next
	return out


func _depth(id: String) -> int:
	var needs:= TechTree.requires(id)
	if needs.is_empty():
		return 0
	var best:= 0
	for need: String in needs:
		best = maxi(best, _depth(str(need)) + 1)
	return best


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true


	var args:= OS.get_cmdline_user_args()
	var scale_at:= args.find("--textscale")
	if scale_at >= 0 and scale_at + 1 < args.size():
		Cfg.tech_text_scale = float(args [scale_at + 1])
		get_window().size = Vector2i(TechPanel.MIN_LAYOUT * Cfg.tech_text_scale)
		await get_tree().process_frame
		await get_tree().process_frame
		panel._apply_text_scale()
		print("text scale asked %.2f, drawn at %.2f in %s"
			% [Cfg.tech_text_scale, panel._layout_scale, panel.size])

	Tech.reset()
	_set_money(40.0)
	await _frame(out_dir, "tech_tree_start.png")


	Tech.grant("spade", 1)
	Tech.grant("broom", 1)
	Tech.grant("bucket", 1)


	GameState.grant_tool("spade")
	GameState.grant_tool("broom")
	Tech.grant("shovel_size", 2)
	Tech.grant("hay_price", 3)
	Tech.grant("work_boots", 4)
	Tech.grant("belt", 1)
	Tech.grant("belt_speed", 2)
	Tech.grant("deck", 1)
	Tech.grant("arm_small", 1)
	Tech.grant("arm_speed", 3)
	_set_money(2400.0)
	await _frame(out_dir, "tech_tree_midrun.png")

	for id: String in TechTree.ids():
		Tech.grant(id, TechTree.max_rank(id))
	_set_money(125000.0)
	await _frame(out_dir, "tech_tree_full.png")


	var seller:= ""
	for id: String in TechTree.ids():
		if not BuildCatalog.builds_for(id).is_empty():
			seller = id
			break
	if seller != "":
		panel._select(seller)
		await _frame(out_dir, "tech_tree_show_button.png")


	Tech.reset()
	Tech.grant("belt", 1)
	Tech.grant("splitter", 1)
	Tech.grant("compressor", 1)
	var dials: Array = TechTree.tuning_groups().get("compressor", [])
	if not dials.is_empty():
		Tech.grant(str(dials [0]), 2)
	_set_money(230.0)
	panel.show_node("compressor")
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir, "tech_tree_fold.png")

	get_tree().quit(0)


func _set_money(amount: float) -> void:
	GameState.add_money(amount - GameState.money)


func _frame(out_dir: String, name: String) -> void:
	panel.set_open(false)
	panel.set_open(true)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
