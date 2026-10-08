class_name DevSplitterPanelShot
extends Node


var world: Node3D


const SPLITTER_AT:= Vector3(13.0, 0.0, 5.0)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--splitterpanelshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var builds: BuildManager = world.builds


	if args.has("smart"):
		var smart:= builds.add_compact_splitter(
			SPLITTER_AT + Vector3(0.0, deck_y, 0.0), 0.0, true)
		smart.set_filter(ConveyorCompactSplitter.OUT_LEFT, BeltRun.Kind.BALE)
		smart.set_filter(ConveyorCompactSplitter.OUT_RIGHT,
			ConveyorCompactSplitter.RULE_NONE)
		var smart_panel: SplitterPanel = world.get("splitter_panel")
		_stand_behind(smart)
		for _i in 12:
			await get_tree().process_frame
		await _shot(smart_panel, smart, "%s/smart_panel.png" % out_dir)
		if args.has("ui-review"):
			for kind in range(BeltRun.ITEM_IDS.size()):
				var pick:= smart_panel._filter_picks [0]
				for index in range(pick.item_count):
					if int(pick.get_item_metadata(index)) == kind:
						smart_panel._on_filter_pick(index, 0)
						assert (smart.filter_for(0) == kind)
						assert (pick.get_item_icon(index) != null)
				await _shot(smart_panel, smart, "%s/item_%s.png" % [out_dir, BeltRun.ITEM_IDS [kind]])
				assert (smart.filter_for(0) == kind)
				assert (smart_panel._door_map.item_icons [0] != null)
			for side in ConveyorCompactSplitter.OUTPUTS:
				smart.set_filter(side, [BeltRun.Kind.BALE, BeltRun.Kind.WAD, BeltRun.Kind.BRICK] [side])
			await _shot(smart_panel, smart, "%s/smart_port_icons.png" % out_dir)
			smart.set_filter(0, ConveyorCompactSplitter.RULE_UNDEFINED)
			smart.set_filter(1, ConveyorCompactSplitter.RULE_OVERFLOW)
			smart.set_filter(2, ConveyorCompactSplitter.RULE_NONE)
			await _shot(smart_panel, smart, "%s/smart_rules.png" % out_dir)
			assert (smart_panel._door_map.item_icons == [null, null, null])
			smart_panel._door_map.output_pressed.emit(0)
			assert (smart_panel._filter_picks [0].get_popup().visible)
			await _capture("%s/smart_menu.png" % out_dir)
			smart_panel._filter_picks [0].get_popup().hide()
			TranslationServer.set_locale("de")
			var german:= SplitterPanel.new()
			smart_panel.get_parent().add_child(german)
			smart_panel.close()
			await _shot(german, smart, "%s/smart_german.png" % out_dir)
			german.close()
			german.queue_free()
			TranslationServer.set_locale("en")
			smart_panel.size.x = 600
			smart_panel._layout_smart()
			await _shot(smart_panel, smart, "%s/smart_narrow.png" % out_dir)
		smart_panel.close()
		await _machine(smart, "%s/smart_machine.png" % out_dir)
		get_tree().quit()
		return
	var splitter: ConveyorSplitter = builds.add_splitter(
		SPLITTER_AT + Vector3(0.0, deck_y, 0.0), 0.0)
	var panel: SplitterPanel = world.get("splitter_panel")
	if panel == null or splitter == null:
		push_error("[splitterpanelshot] the world stood up no splitter or no panel")
		get_tree().quit(1)
		return


	_stand_behind(splitter)
	for _i in 12:
		await get_tree().process_frame


	Tech.grant("overflow_gate", 0)
	splitter.set_forced_side(-1)
	await _shot(panel, splitter, "%s/splitter_panel_plain.png" % out_dir)


	splitter.set_forced_side(ConveyorSplitter.LEFT)
	await _shot(panel, splitter, "%s/splitter_panel_pinned.png" % out_dir)


	Tech.grant("overflow_gate", 1)
	splitter.set_forced_side(-1)
	await _shot(panel, splitter, "%s/splitter_panel_gate_idle.png" % out_dir)


	splitter.set_priority_side(ConveyorSplitter.LEFT)
	await _shot(panel, splitter, "%s/splitter_panel_gate_left.png" % out_dir)

	panel.close()


	Tech.grant("overflow_gate", 0)


	splitter.set_forced_side(-1)
	splitter.set_priority_side(-1)
	await _machine(splitter, "%s/splitter_machine_bare.png" % out_dir)
	Tech.grant("overflow_gate", 1)
	await _machine(splitter, "%s/splitter_machine_gate_idle.png" % out_dir)
	splitter.set_priority_side(ConveyorSplitter.LEFT)
	await _machine(splitter, "%s/splitter_machine_left.png" % out_dir)
	splitter.set_priority_side(ConveyorSplitter.RIGHT)
	await _machine(splitter, "%s/splitter_machine_right.png" % out_dir)
	splitter.set_forced_side(ConveyorSplitter.LEFT)
	await _machine(splitter, "%s/splitter_machine_pin_left.png" % out_dir)


	splitter.set_priority_side(ConveyorSplitter.LEFT)
	await _machine(splitter, "%s/splitter_glass_main_left.png" % out_dir, 0.62)
	splitter.set_forced_side(ConveyorSplitter.LEFT)
	await _machine(splitter, "%s/splitter_glass_pin_left.png" % out_dir, 0.62)
	splitter.set_forced_side(-1)
	splitter.set_priority_side(-1)
	await _machine(splitter, "%s/splitter_glass_turn.png" % out_dir, 0.62)

	get_tree().quit()


func _machine(splitter: ConveyorSplitter, path: String,
		range_m: float = 1.35) -> void:
	var player: Player = world.get("player")
	if player == null:
		return


	var glass:= splitter.to_global(ConveyorSplitter.SCREEN_AT)
	var stand:= glass - splitter.forward() * range_m
	stand.y = 0.0
	player.global_position = stand
	var eye:= stand + Vector3.UP * (player.head.position.y if player.head != null else 1.6)
	player.look_at_from_position(stand, glass, Vector3.UP)
	player.rotation.x = 0.0
	var to_aim:= glass - eye
	player.set_look(player.rotation.y,
		atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))
	for _i in 4:
		await get_tree().physics_frame
	await _capture(path)
	var box:= splitter.get_node_or_null("Readout") as MeshInstance3D


	var screen:= box.get_node_or_null("Screen") as MeshInstance3D if box != null else null
	var drawn:= "-"
	if screen != null and screen.material_override is ShaderMaterial:
		drawn = str((screen.material_override as ShaderMaterial)
			.get_shader_parameter("mode"))
	print("[splitterpanelshot] %s  box %s, setting %s, glass mode %s" % [
		path.get_file(), "fitted" if box != null and box.visible else "not fitted",
		splitter.setting(), drawn])


func _stand_behind(splitter: ConveyorSplitter) -> void:
	var player: Player = world.get("player")
	if player == null:
		return
	var back:= splitter.global_position - splitter.forward() * 2.6
	back.y = 0.0
	player.global_position = back


	var eye:= back + Vector3.UP * (player.head.position.y if player.head != null else 1.6)
	var to_aim:= splitter.global_position - eye
	player.look_at_from_position(back, splitter.global_position, Vector3.UP)
	player.rotation.x = 0.0
	player.set_look(player.rotation.y,
		atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))


func _shot(panel: SplitterPanel, splitter: ConveyorSplitter, path: String) -> void:


	panel.close()
	panel.open(splitter)
	for _i in 3:
		await get_tree().physics_frame
	await _capture(path)
	print("[splitterpanelshot] %s  setting %s, gate card %s" % [
		path.get_file(), splitter.setting(),
		"up" if panel._gate_panel.visible else "down"])


func _capture(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
