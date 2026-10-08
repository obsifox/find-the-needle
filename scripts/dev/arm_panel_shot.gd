class_name DevArmPanelShot
extends Node


var world: Node3D


const DIG_AT:= Vector3(10.9, 0.06, 3.7)

const IDLE_AT:= Vector3(-13.5, 0.06, -6.0)

const DIG_SECONDS:= 30.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--armpanelshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var builds: BuildManager = world.builds
	var panel: ArmPanel = world.get("arm_panel")
	if panel == null:
		push_error("[armpanelshot] the world stood up no ArmPanel")
		get_tree().quit(1)
		return
	Tech.grant("belt")
	Tech.grant("arm_small")
	Tech.grant("arm_standard")
	GameState.money = maxf(GameState.money, 20000.0)

	var field: HayField = world.field
	var dig_at:= DIG_AT
	dig_at.y = maxf(DIG_AT.y, field.height_at(DIG_AT.x, DIG_AT.z))
	builds.add_conveyor(dig_at + Vector3(1.6, 0.45, -1.2), dig_at + Vector3(1.6, 0.45, 1.8))
	var digger:= builds.add_robotic_arm(dig_at, 0.0, 0)
	builds.add_conveyor(IDLE_AT + Vector3(-1.6, 0.45, -1.2), IDLE_AT + Vector3(-1.6, 0.45, 1.8))
	var idle:= builds.add_robotic_arm(IDLE_AT, 0.0, 1)

	var waited:= 0.0
	while waited < DIG_SECONDS and digger.completed_cycles < 3:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	print("[armpanelshot] digger: %d loads in %.1f s, %d hay a minute, %d belts" % [
		digger.completed_cycles, waited, digger.hay_per_minute(), digger.belts_in_reach()])


	Cfg.teach_hints = true
	Cfg.machines_seen.erase(ArmPanel.EXPLAIN_KEY)
	await _shoot(panel, digger, "%s/arm_panel_new.png" % out_dir)


	for _i in 4:
		builds.watch.force_sweep(MachineWatch.HOLD)
	print("[armpanelshot] idle arm: clear=%s  sign=\"%s\"" % [
		idle.is_clear(), builds.watch.alert_reason(idle)])
	await _shoot(panel, idle, "%s/arm_panel_waiting.png" % out_dir)


	panel.open(idle)
	panel._on_all(false)
	await get_tree().create_timer(1.0).timeout
	await _shoot(panel, idle, "%s/arm_panel_none.png" % out_dir)


	for id in ["belt_links", "overflow_arm", "pick_order"]:
		Tech.grant(id)
	for key in ["arm_new_links", "arm_new_overflow", "arm_new_order"]:
		Cfg.machines_seen.erase(key)
	panel._on_all(true)
	await _shoot(panel, idle, "%s/arm_panel_cards.png" % out_dir)


	var line:= builds.add_conveyor(IDLE_AT + Vector3(1.7, 0.45, -2.4),
		IDLE_AT + Vector3(1.7, 0.45, 2.4))
	idle.set_link(line, IDLE_AT + Vector3(1.7, 0.45, 0.4), RoboticArm.LINK_TAKE)
	idle.set_take_when_stuck(line, true)
	var put:= builds.conveyor_drops(idle._shoulder_world(), idle.work_reach())
	for pick in put:
		if pick ["conveyor"] != line:
			idle.set_link(pick ["conveyor"], pick ["point"], RoboticArm.LINK_PUT)
			break
	idle.accept_mask = RoboticArm.PICK_BALE | RoboticArm.PICK_NEEDLE
	idle.set_pick_order(RoboticArm.ORDER_BIG)
	await _shoot(panel, idle, "%s/arm_panel_links.png" % out_dir)


	panel.close()
	var player: Player = world.get("player")
	var mode: ArmLinkMode = world.get("arm_links")
	if player != null and mode != null:


		player.global_position = IDLE_AT + Vector3(0.0, 0.0, 6.0)
		player.set_look(deg_to_rad(-17.0), deg_to_rad(-14.0))
		mode.begin(idle)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/arm_links_world.png" % out_dir)
		print("[armpanelshot] arm_links_world.png")


		builds.add_splitter(IDLE_AT + Vector3(0.0, 0.0, 4.2), 0.0)
		player.global_position = IDLE_AT + Vector3(0.0, 0.0, 7.4)
		player.set_look(0.0, deg_to_rad(-22.0))
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/arm_links_splitter.png" % out_dir)
		print("[armpanelshot] arm_links_splitter.png  refused=%d" % mode._refused)
		mode.end(false)

	get_tree().quit()


func _shoot(panel: ArmPanel, arm: RoboticArm, path: String) -> void:
	panel.close()
	panel.open(arm)

	await get_tree().create_timer(ArmPanel.REFRESH * 2.0 + 0.05).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
	var status:= arm.plate_status(world.builds.watch.alert_reason(arm) != "")
	print("[armpanelshot] %s  %s  \"%s\"" % [path.get_file(),
		["WORKING", "WAITING", "STOPPED"] [int(status [0])], status [1]])
