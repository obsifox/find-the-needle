class_name DevCapture
extends Node


const OUT_DIR:= "res://captures"


const BOX:= Rect2i(560, 640, 340, 170)

var world: Node3D
var player: Player

var _cam: Camera3D


const SHOTS:= [
	[Vector3(13.2, 1.8, 6.4), Vector3(0.0, 3.2, 0.0), "01_establishing", "none"],
	[Vector3(11.4, 1.7, 1.2), Vector3(4.0, 3.4, 0.0), "02_pile_face", "none"],


	[Vector3(11.6, 1.7, 6.6), Vector3(0.0, 6.8, 0.0), "03_up_the_dome", "none"],
	[Vector3(13.4, 1.6, 0.0), Vector3(9.9, 0.2, 0.0), "04_base_and_slab", "none"],
	[Vector3(12.0, 1.7, 1.0), Vector3(6.0, 2.4, 0.5), "05_shovel", "shovel"],
	[Vector3(13.0, 1.7, 3.0), Vector3(7.0, 1.6, 1.5), "06_strand_in_hand", "strand"],
	[Vector3(0.0, 12.5, 15.5), Vector3(0.0, 3.0, 0.0), "07_wide_room", "none"],
	[Vector3(12.9, 0.85, 2.4), Vector3(10.2, 0.3, 1.1), "08_rim_wall", "none"],
	[Vector3(11.9, 1.05, 0.9), Vector3(10.15, 0.35, 0.35), "09_rim_close", "none"],
]


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


	world.set("block_save", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


	Cfg.perf_scale = 0.45 if "--lodstress" in OS.get_cmdline_user_args() else 1.0
	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.01
	_cam.far = 320.0
	world.add_child(_cam)


	for i in 90:
		await get_tree().process_frame

	var args:= OS.get_cmdline_user_args()
	if "--reproshot" in args:
		await _repro_shot()
	elif "--shadowspots" in args:
		await _shadow_spot_shots()
	elif "--blowout" in args:
		await _blowout_shots()
	elif "--blobhunt" in args:
		await _blob_hunt()
	elif "--rimdig" in args:
		await _rimdig_shots()
	elif "--crater" in args:
		await _crater_shots()
	elif "--hollow" in args:
		await _hollow_shots()
	elif "--dugface" in args:
		await _dugface_shot()
	elif "--churn" in args:
		await _churn_shots()
	elif "--scoop" in args:
		await _scoop_shots()
	elif "--shellonly" in args:
		for c in (world.get_node("HayField") as HayField).chunks:
			var crust:= c.get_node_or_null("Crust")
			if crust != null:
				crust.visible = false
		await _free_shot(SHOTS [0] [0], SHOTS [0] [1], "shell_only")
	elif "--conveyor" in args:
		await _conveyor_shots()
	elif "--generator" in args:
		await _generator_shots()
	elif "--firebox" in args:
		await _firebox_shots()
	elif "--hopper" in args:
		await _hopper_shots()
	elif "--railing" in args:
		await _railing_shots()
	elif "--wallshot" in args:
		await _wall_shots()
	elif "--roofshot" in args:
		await _roof_shots()
	elif "--sellstand" in args:
		await _sell_stand_shots()
	elif "--supply" in args:
		await _supply_shots()
	elif "--items" in args:
		await _item_shots()
	elif "--pitchfork" in args:
		await _pitchfork_shot()
	elif "--broom" in args:
		await _broom_shots()
	elif "--models" in args:
		await _model_sheet()
	elif "--armmast" in args:
		await _arm_mast_shots()
	elif "--debugmenu" in args:
		await _debug_menu_shots()
	elif "--wallhack" in args:
		await _wallhack_shots()
	elif "--glintclose" in args:
		await _needle_glint_shots()
	elif "--deposit" in args:
		await _deposit_shots()
	elif "--sparks" in args:
		await _spark_shots()
	elif "--payout" in args:
		await _payout_shots()
	elif "--press" in args:
		await _compressor_shots()
	elif "--scannerline" in args:
		await _scanner_line_shots()
	elif "--needleline" in args:
		await _needle_line_shots()
	elif "--lookpass" in args:
		await _look_pass_shots()
	else:
		for shot: Array in SHOTS:
			await _player_shot(shot [0], shot [1], shot [2], shot [3])

	print("[capture] done -> %s" % OUT_DIR)
	get_tree().quit()


const LOOK_STATES:= [
	{ "label": "a_flat", "gi": false, "reflect_probe": false, "dust": false },
	{ "label": "b_bounce", "gi": true, "reflect_probe": false, "dust": false },
	{ "label": "c_probe", "gi": true, "reflect_probe": true, "dust": false },
	{ "label": "d_dust", "gi": true, "reflect_probe": true, "dust": true },


	{ "label": "e_notaa", "gi": true, "reflect_probe": true, "dust": true, "taa": false },
]


const LOOK_VIEWS:= [
	[Vector3(13.2, 1.8, 6.4), Vector3(0.0, 3.2, 0.0), "room"],
	[Vector3(0.0, 12.5, 15.5), Vector3(0.0, 3.0, 0.0), "wide"],
	[Vector3(12.0, 1.6, 7.5), Vector3(12.6, 0.7, -9.0), "wall"],


	[Vector3(-12.5, 1.7, 10.5), Vector3(2.0, 9.0, -3.0), "beam"],
]


const LOOK_SETTLE:= 60


func _look_pass_shots() -> void:
	var was_auto: bool = Cfg.gfx.get("auto_exposure", true)
	var was_taa: bool = Cfg.gfx.get("taa", true)
	Cfg.gfx ["auto_exposure"] = false
	for state: Dictionary in LOOK_STATES:


		Cfg.gfx ["taa"] = was_taa
		for key: String in state:
			if key != "label":
				Cfg.gfx [key] = state [key]
		world.call("_apply_render_settings")
		for _i in LOOK_SETTLE:
			await get_tree().process_frame
		for view: Array in LOOK_VIEWS:


			_cam.current = true
			_cam.look_at_from_position(view [0], view [1], Vector3.UP)
			for _i in LOOK_SETTLE:
				await get_tree().process_frame
			await _write("look_%s_%s" % [view [2], state ["label"]])
	Cfg.gfx ["auto_exposure"] = was_auto
	Cfg.gfx ["taa"] = was_taa
	world.call("_apply_render_settings")


func _needle_line_shots() -> void:
	var live: LiveStrandManager = world.get("live")
	var origin:= Vector3(13.0, 0.0, -2.0)
	var pitch:= 0.3
	for t in NeedleTypes.count():
		var at:= origin + Vector3(float(t % 6) * pitch, 0.1,
			float(t / 6) * pitch)
		var index:= GameState.register_needle(at, null, t)
		GameState.needle_taken [index] = 1
		var n:= live.reveal_needle(index, at)


		n.freeze = true
		n.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), at)
	for i in 30:
		await get_tree().process_frame
	var centre:= origin + Vector3(pitch * 2.5, 0.02, pitch * 1.5)
	await _free_shot(centre + Vector3(0.0, 1.55, 0.02), centre, "n1_loose_all")
	await _free_shot(centre + Vector3(-0.55, 0.6, 0.7),
		centre + Vector3(-0.2, 0.0, 0.0), "n2_loose_angle")


	var lot0:= origin + Vector3(pitch * 2.5, 0.02, 0.0)
	await _free_shot(lot0 + Vector3(0.0, 0.78, 0.01), lot0, "n3_loose_lot0")


func _generator_shots() -> void:
	var builds: BuildManager = world.builds
	Tech.grant(BuildCatalog.unlock_of("generator"), 1)
	GameState.add_money(40000.0)
	for i in 20:
		await get_tree().process_frame


	await _player_shot(Vector3(12.6, 1.75, 9.6), Vector3(12.6, 0.0, 6.6),
		"g1_ghost_broadside", "generator")


	await _free_shot(Vector3(6.4, 7.6, 12.4), Vector3(12.6, 0.8, 6.1),
		"g2_ghost_broadside_over")


	builds.add_conveyor(Vector3(12.6, 0.75, 10.5), Vector3(12.6, 0.75, 6.5))
	for i in 20:
		await get_tree().process_frame
	await _player_shot(Vector3(12.6, 1.75, 9.6), Vector3(12.6, 0.0, 6.6),
		"g3_ghost_snapped", "generator")
	await _free_shot(Vector3(6.4, 7.6, 12.4), Vector3(12.6, 0.8, 6.1),
		"g4_ghost_snapped_over")


func _firebox_shots() -> void:
	var gen: HayGenerator = world.builds.add_generator(Vector3(13.0, 0.0, 0.0), 0.0)
	gen.fuel = gen.capacity() * 0.8


	for i in 90:
		await get_tree().process_frame
	var door:= gen.to_global(Vector3(0.44, 0.72, -0.3))
	await _free_shot(door + Vector3(1.05, 0.25, 0.15), door, "f1_firebox_close")
	await _free_shot(door + Vector3(2.6, 0.7, 1.4), door, "f2_firebox_face")
	await _free_shot(door + Vector3(0.6, 0.15, 1.1), door, "f3_firebox_oblique")
	var board:= gen.to_global(Vector3(0.6, 1.4, -0.94))
	await _free_shot(board + Vector3(0.82, 0.02, 0.05), board, "f4_generator_instructions")
	var cabinet:= gen.to_global(Vector3(0.25, 1.18, 2.12))
	await _free_shot(cabinet + Vector3(0.4, 0.12, 0.9), cabinet, "f5_generator_label_bulb")


func _hopper_shots() -> void:
	var gen: HayGenerator = world.builds.add_generator(Vector3(13.0, 0.0, 0.0), 0.0)

	for i in 20:
		await get_tree().process_frame
	var mouth:= gen.to_global(HayGenerator.HOPPER_AT)
	for step: Array in [[0.15, "empty"], [0.45, "part"], [0.75, "most"], [1.0, "full"]]:
		gen.fuel = gen.capacity() * float(step [0])
		for i in 4:
			await get_tree().process_frame
		await _free_shot(mouth + Vector3(1.15, 0.62, 0.95), mouth,
			"h1_hopper_%s" % step [1])


	await _free_shot(mouth + Vector3(1.35, 0.16, -0.55), mouth, "h2_hopper_eye")
	await _free_shot(mouth + Vector3(3.0, 1.5, 2.6), mouth, "h3_hopper_range")


func _free_shot(pos: Vector3, look: Vector3, label: String) -> void:
	_cam.current = true
	_cam.look_at_from_position(pos, look, Vector3.UP)
	await _write(label)


func _player_shot(eye: Vector3, look: Vector3, label: String, holding: String) -> void:
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(look.y - eye.y, maxf(flat.length(), 0.001))
	player.velocity = Vector3.ZERO
	player.camera.current = true

	match holding:
		"shovel":
			player._set_tool(Player.Tool.SHOVEL)
		"pitchfork":
			player._set_tool(Player.Tool.PITCHFORK)
		"broom":
			player._set_tool(Player.Tool.BROOM)
		"strand":
			player._set_tool(Player.Tool.HAND)
			player.hand._pluck(player.hand.aim_hit())
		"conveyor":
			player.equip_build("belt")
		"railing":
			player.equip_build("rail")
		"wall":
			player.equip_build("wall")
		"roof":
			player.equip_build("roof_pitch")
		"hatch":
			player.equip_build("roof_hatch")
		"generator":
			player.equip_build("generator")
		_:
			player._set_tool(Player.Tool.HAND)

	await _write(label)


func _broom_shots() -> void:
	var spill:= Vector3(13.6, 0.06, 6.2)
	_spill_hay(spill, 90)
	var eye:= spill + Vector3(-1.5, Player.EYE_HEIGHT, 0.0)
	await _player_shot(eye, spill + Vector3(0.6, 0.0, 0.0), "broom_1_held", "broom")


	_freeze_stroke(Broom.STROKE_TIME * 0.5)
	await _write("broom_2_mid_stroke")
	player.broom.process_mode = Node.PROCESS_MODE_INHERIT

	player.broom.sweep()
	for i in 90:
		await get_tree().process_frame
	await _write("broom_3_swept")


	player.broom.sweep()
	for i in 6:
		await get_tree().process_frame
	await _crouch_hold(24)
	await _write("broom_4_crouched")


	await _player_shot(spill + Vector3(-2.6, Player.EYE_HEIGHT, 0.0),
		spill + Vector3(3.0, Player.EYE_HEIGHT - 0.15, 0.0), "broom_6_level_gaze", "broom")


	await _player_shot(Vector3(11.1, Player.EYE_HEIGHT, 0.4),
		Vector3(9.6, 0.3, 0.3), "broom_5_at_pile", "broom")


func _spill_hay(centre: Vector3, count: int) -> void:
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210
	for i in count:
		var p:= centre + Vector3(rng.randf_range(-0.55, 0.55), rng.randf() * 0.05,
			rng.randf_range(-0.55, 0.55))
		live.spawn(p, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)


func _freeze_stroke(t: float) -> void:
	var broom: Broom = player.broom
	broom.sweep()
	broom._stroke = t
	broom._update_visual_pose(t)
	broom.process_mode = Node.PROCESS_MODE_DISABLED


func _crouch_hold(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		player._crouch = 1.0
		player._apply_crouch(0.0)


func _pitchfork_shot() -> void:


	GameState.grant_tool("pitchfork")
	var eye:= Vector3(11.6, 1.7, 0.6)
	var look:= Vector3(9.2, 1.35, 0.3)
	await _player_shot(eye, look, "pitchfork_1_aimed", "pitchfork")

	var fork: Pitchfork = player.pitchfork
	var aim:= fork.aim_point()
	if aim.is_empty():
		push_error("capture: pitchfork has no pile aim point")
		return
	var lifted:= fork.scoop()
	print("[capture] pitchfork lifted %d strands" % lifted)
	for i in 60:
		await get_tree().physics_frame
	await _write("pitchfork_held_hay_loaded")


	await _player_shot(Vector3(14.6, 1.7, 7.4), Vector3(13.0, 1.15, 5.8),
		"pitchfork_2_held_hay", "pitchfork")
	await _verify_tool_drop_keys()


func _verify_tool_drop_keys() -> void:
	for tool in [Player.Tool.PITCHFORK, Player.Tool.SHOVEL]:
		player._set_tool(tool)
		var pressed:= InputEventKey.new()
		pressed.physical_keycode = KEY_Q
		pressed.pressed = true
		Input.parse_input_event(pressed)
		await get_tree().process_frame
		var released:= InputEventKey.new()
		released.physical_keycode = KEY_Q
		released.pressed = false
		Input.parse_input_event(released)
		await get_tree().process_frame
		if player.current_tool != Player.Tool.HAND:
			push_error("capture: Q did not drop tool %s" % Player.Tool.keys() [tool])
			return
	print("[capture] Q-drop passed for pitchfork and shovel")


func out_run_unblock(scanner: HaystackScanner) -> void:
	scanner.stored = int(scanner.buffer_capacity() * 0.6)


func _riders_on(builds: BuildManager) -> int:
	var n:= 0
	for c in builds.conveyors:
		n += c.riders().size()
	for c in builds.corners:
		n += c.riders().size()
	return n


func _compressor_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR

	var mid:= Vector3(14.5, deck_y, 0.0)
	var press: HayCompressor = builds.add_compressor(mid, 0.0)
	for i in 30:
		await get_tree().process_frame


	await _free_shot(mid + Vector3(-2.6, 1.1, -2.6), mid + Vector3(0, 0.15, 0),
		"press_01_alone")
	await _free_shot(mid + Vector3(-0.2, 0.85, -3.2), mid + Vector3(0, 0.1, 0),
		"press_02_infeed_end")
	await _free_shot(mid + Vector3(-2.2, 2.4, 0.0), mid + Vector3(0, 0.2, 0),
		"press_03_over_the_deck")


	builds.add_conveyor(press.port_in() - Vector3(0, 0, 5.0), press.port_in())
	builds.add_conveyor(press.port_out(), press.port_out() + Vector3(0, 0, 5.0))
	for i in 30:
		await get_tree().process_frame
	await _free_shot(mid + Vector3(-3.0, 1.45, -3.4), mid + Vector3(0, 0.15, 0),
		"press_04_spliced_in")


func _arm_mast_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	var at:= Vector3(14.5, 0.0, 0.0)
	var arm: RoboticArm = builds.add_robotic_arm(at, 0.0, 1)
	arm.builds = builds
	for i in 30:
		await get_tree().process_frame
	await _free_shot(at + Vector3(-1.6, 1.6, -1.9), at + Vector3(0, 1.0, -0.3),
		"armmast_01_foot")
	await _free_shot(at + Vector3(-1.2, 1.3, 1.3), at + Vector3(0, 1.0, 0.2),
		"armmast_02_foot_front")
	await _free_shot(at + Vector3(-4.5, 2.6, -3.5), at + Vector3(0, 2.2, 0),
		"armmast_03_whole")
	await _free_shot(at + Vector3(-1.4, 4.9, -1.2), at + Vector3(0, 4.2, 0),
		"armmast_04_top")


	var mill: HayPelletizer = world.builds.add_pelletizer(Vector3(14.5, 0.0, 7.0), 0.0)
	var rake: PistonRake = world.builds.add_piston_rake(Vector3(14.5, 0.0, -7.0), 0.0)
	for i in 30:
		await get_tree().process_frame
	var mill_port: Vector3 = mill.power_ports() [0].global_position
	await _free_shot(mill_port + Vector3(-1.3, 0.5, -1.0), mill_port - Vector3(0, 0.25, 0),
		"armmast_05_mill_fitting")
	var rake_port: Vector3 = rake.power_ports() [0].global_position
	await _free_shot(rake_port + Vector3(-1.3, 0.6, -1.0), rake_port - Vector3(0, 0.25, 0),
		"armmast_06_rake_fitting")


func _scanner_line_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	var live: LiveStrandManager = world.get_node("LiveStrands")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR


	var far_a:= Vector3(9.5, deck_y, -6.0)
	var bend:= Vector3(14.5, deck_y, -6.0)
	var mid:= Vector3(14.5, deck_y, 1.0)

	var scanner: HaystackScanner = builds.add_scanner(
		Vector3(14.5, deck_y, 1.0 + Cfg.SCANNER_LENGTH * 0.5), 0.0)
	scanner.live = live
	builds.add_conveyor(far_a, bend)


	builds.add_conveyor(bend, scanner.port_in())
	builds.add_conveyor(scanner.port_out(), scanner.port_out() + Vector3(0, 0, 5.0))


	var arm: RoboticArm = builds.add_robotic_arm(
		Vector3(12.0, 0.0, -4.5), 0.0)
	arm.live = live
	arm.builds = builds
	arm.field = world.get_node("HayField") as HayField
	for i in 30:
		await get_tree().process_frame


	scanner.stored = scanner.buffer_capacity()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210
	var gap:= 0.0
	var fed:= 0
	var secs:= 0.0
	while secs < 34.0:
		await get_tree().process_frame
		var dt:= get_process_delta_time()
		secs += dt
		gap -= dt
		if gap <= 0.0 and fed < 260:
			gap = 0.09
			if live.spawn(far_a + Vector3(0.0, 0.22, rng.randf_range(-0.12, 0.12)),
					StrandFactory.random_strand_basis(rng), Vector3.ZERO,
					Cfg.COL_HAY_LIGHT) != null:
				fed += 1
	print("[capture] fed %d strands; buffer %d/%d; %d standing on the line"
		% [fed, scanner.stored, scanner.buffer_capacity(), _riders_on(builds)])


	await _free_shot(Vector3(9.0, 3.6, -10.5), Vector3(14.5, 0.5, -1.0),
		"scanner_line_1_jammed")


	await _free_shot(Vector3(12.6, 1.85, -2.4), Vector3(14.5, 0.44, -2.9),
		"scanner_line_2_packed")

	await _free_shot(scanner.console_position() + Vector3(-1.5, 0.45, -0.6),
		scanner.console_position(), "scanner_line_3_console")


	out_run_unblock(scanner)
	for i in 90:
		await get_tree().process_frame
	await _free_shot(scanner.console_position() + Vector3(-1.1, 0.35, -0.45),
		scanner.console_position(), "scanner_line_4_queue")


	player.global_position = Vector3(5.2, 0.4, 8.2)
	player.velocity = Vector3.ZERO
	player.camera.current = true


	GameState.add_money(5000.0)
	player.equip_build("scanner")


	var aim:= Vector3(9.5, 0.05, 11.5)
	var eye:= player.eye_position()
	var flat:= Vector3(aim.x - eye.x, 0.0, aim.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(aim.y - eye.y, maxf(flat.length(), 0.001))
	for i in 40:
		await get_tree().process_frame
	await _write("scanner_line_5_ghost")


	var lone: HaystackScanner = builds.add_scanner(Vector3(9.5, deck_y, 12.5), 0.0)
	lone.live = live
	for i in 30:
		await get_tree().process_frame
	var sections:= lone.deck().get_node_or_null("Path/Sections") as MultiMeshInstance3D


	print("[capture] lone module deck: %d sections"
		% (sections.multimesh.instance_count if sections != null else 0))
	player._set_tool(Player.Tool.HAND)


	await _free_shot(Vector3(12.6, 1.15, 12.5), Vector3(9.5, 0.5, 12.5),
		"scanner_line_6_lone")
	await _free_shot(Vector3(9.5, 1.5, 8.6), Vector3(9.5, 0.45, 12.5),
		"scanner_line_7_down_the_deck")


	lone.stored = 20
	for i in 20:
		await get_tree().process_frame
	await _free_shot(Vector3(9.5, 1.5, 8.6), Vector3(9.5, 0.45, 12.5),
		"scanner_line_8_scanning")


	_cam.current = true
	_cam.look_at_from_position(Vector3(9.5, 1.3, 9.4), Vector3(9.5, 0.8, 12.5),
		Vector3.UP)
	for i in 45:
		await get_tree().process_frame
	lone._emit_ping()
	for i in 26:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"%s/scanner_line_9_ping.png" % OUT_DIR)
	print("[capture] scanner_line_9_ping")


func _deposit_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	var live: LiveStrandManager = world.get_node("LiveStrands")


	var cab: NeedleCabinet = builds.add_cabinet(Vector3(14.0, 0.0, 0.0), - PI * 0.5)
	for i in 20:
		await get_tree().process_frame


	var type:= 23
	var at:= cab.read_position() + Vector3(0, 0.9, 0)
	var index:= GameState.register_needle(at, null, type)
	GameState.needle_taken [index] = 1
	var needle:= live.reveal_needle(index, at)

	player._set_tool(Player.Tool.HAND)


	var back:= (cab.read_position() - cab.global_position)
	back.y = 0.0
	player.global_position = cab.read_position() - Vector3(0, Player.EYE_HEIGHT, 0) + back.normalized() * 0.85
	player.velocity = Vector3.ZERO
	player.camera.current = true
	player.hand._grab(needle)
	cab.open_doors()


	for i in 120:
		await get_tree().process_frame

	var slot:= cab.slot_position(type)
	var eye:= player.eye_position()
	var flat:= Vector3(slot.x - eye.x, 0.0, slot.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(slot.y - eye.y, maxf(flat.length(), 0.001))
	await _write("cabinet_deposit")


func _spark_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")


	var cab: NeedleCabinet = builds.add_cabinet(Vector3(14.0, 0.0, 0.0), - PI * 0.5)
	for i in 20:
		await get_tree().process_frame

	var type:= 23
	var back:= (cab.read_position() - cab.global_position)
	back.y = 0.0
	player._set_tool(Player.Tool.HAND)
	player.global_position = cab.read_position() - Vector3(0, Player.EYE_HEIGHT, 0) + back.normalized() * 0.85
	player.velocity = Vector3.ZERO
	player.camera.current = true
	cab.open_doors()
	var slot:= cab.slot_position(type)
	var eye:= player.eye_position()
	var flat:= Vector3(slot.x - eye.x, 0.0, slot.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(slot.y - eye.y, maxf(flat.length(), 0.001))

	for i in 140:
		await get_tree().process_frame

	GameState.discovered [type] = 1
	cab.reveal(type)
	var at:= 0
	for mark in [5, 16, 34]:
		while at < mark:
			await get_tree().process_frame
			at += 1
		await RenderingServer.frame_post_draw
		var img:= get_viewport().get_texture().get_image()
		img.save_png("%s/reveal_sparks_%02d.png" % [OUT_DIR, mark])
		print("[capture] reveal_sparks_%02d" % mark)


const PAYOUT_AMOUNTS:= [[0.02, "small"], [40.0, "big"]]


func _payout_shots() -> void:
	var st: HaySellingStand = world.get_node("SellingStand")
	var till: Vector3 = st.to_global(Vector3(0.02, 1.39, 1.25))
	var bay: Vector3 = st.to_global(Vector3(-2.1, 1.18, 3.05))


	var front:= (bay - till)
	front.y = 0.0
	var eye:= till + front.normalized() * 1.6 + Vector3(0, 0.3, 0)
	player._set_tool(Player.Tool.HAND)
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	player.velocity = Vector3.ZERO
	player.camera.current = true
	var flat:= Vector3(till.x - eye.x, 0.0, till.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(till.y - eye.y, maxf(flat.length(), 0.001))


	for i in 140:
		await get_tree().process_frame

	for entry: Array in PAYOUT_AMOUNTS:
		var amount: float = entry [0]
		var tag: String = entry [1]


		st._payout(amount, "+$%s" % Hud.money_text(amount), HaySellingStand.COL_PAY)
		var at:= 0
		for mark in [4, 14, 30]:
			while at < mark:
				await get_tree().process_frame
				at += 1
			await RenderingServer.frame_post_draw
			var img:= get_viewport().get_texture().get_image()
			img.save_png("%s/payout_%s_%02d.png" % [OUT_DIR, tag, mark])
			print("[capture] payout_%s_%02d" % [tag, mark])


		for i in 160:
			await get_tree().process_frame


	var anchor: Vector3 = st._popup_at
	var out:= (anchor - st.global_position)
	out.y = 0.0
	_cam.current = true
	_cam.look_at_from_position(anchor + out.normalized() * 1.5 + Vector3(0, 0.45, 0),
		anchor + Vector3(0, 0.35, 0), Vector3.UP)
	for i in 90:
		await get_tree().process_frame
	st._payout(0.02, "+$%s" % Hud.money_text(0.02), HaySellingStand.COL_PAY)


	for i in 22:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot:= get_viewport().get_texture().get_image()
	shot.save_png("%s/payout_number.png" % OUT_DIR)
	print("[capture] payout_number")


func _debug_menu_shots() -> void:
	var menu: DebugMenu = world.debug_menu
	if menu == null:
		push_error("capture: no debug menu -- Cfg.DEBUG is off")
		return
	menu.set_open(true)
	await _write("debug_menu")


	menu.scroll_to_foot()
	await _write("debug_menu_foot")
	menu.scroll_to_head()
	menu._open_needle_picker()
	await _write("debug_menu_needle_picker")
	menu.set_open(false)


func _wallhack_shots() -> void:
	var hack: NeedleWallhack = world.needle_wallhack
	if hack == null:
		push_error("capture: no wallhack -- Cfg.DEBUG is off")
		return
	hack.set_enabled(true)


	var live: LiveStrandManager = world.get_node("LiveStrands")
	var at:= Vector3(11.5, 0.4, 3.2)
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	live.reveal_needle(index, at)
	await _player_shot(Vector3(14.5, 1.8, 7.0), Vector3(0.0, 4.0, 0.0),
		"wallhack_over_the_pile", "none")
	await _player_shot(Vector3(12.6, 1.7, 4.6), Vector3(10.4, 0.35, 2.6),
		"wallhack_loose_needle", "none")
	hack.set_enabled(false)


func _needle_glint_shots() -> void:
	var live: LiveStrandManager = world.get_node("LiveStrands")
	var glints: NeedleGlints = world.needle_glints
	if glints == null:
		push_error("capture: no needle glints on the world")
		return


	var at:= Vector3(11.9, 0.02, 0.6)
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	var needle:= live.reveal_needle(index, at)
	if needle == null:
		push_error("capture: no needle to photograph")
		return


	for i in 120:
		await get_tree().process_frame


	_look_at_needle(needle, 2.0)
	await _blink_rhythm(glints, 8.0, needle)


	await _shoot_when(glints, needle, true, "needle_glint_flash")
	await _shoot_when(glints, needle, false, "needle_glint_between")


	glints.process_mode = Node.PROCESS_MODE_DISABLED
	glints.visible = false
	_look_at_needle(needle, 2.0)
	await _write("needle_glint_none")
	glints.visible = true
	glints.process_mode = Node.PROCESS_MODE_INHERIT


	var field: HayField = world.get_node("HayField")
	var on_pile:= Vector3(7.4, 0.0, 3.2)
	on_pile.y = field.height_at(on_pile.x, on_pile.z) - 0.06
	world.live.unpin(needle)
	needle.global_position = on_pile
	needle.linear_velocity = Vector3.ZERO
	for i in 30:
		await get_tree().process_frame
	print("[capture] in the hay: %.2f m of crust over it"
		% (field.height_at(on_pile.x, on_pile.z) - needle.global_position.y))
	await _shoot_when(glints, needle, true, "needle_glint_hay_flash")
	await _shoot_when(glints, needle, false, "needle_glint_hay_between")


func _blink_rhythm(glints: NeedleGlints, seconds: float,
		needle: RigidBody3D) -> void:
	var t:= 0.0
	var last:= 0.0
	var rising:= false
	var top:= 0.0
	var top_at:= 0.0
	var previous:= -1.0
	print("[capture] blink rhythm over %.0fs at 2 m:" % seconds)
	while t < seconds:
		await get_tree().process_frame
		_look_at_needle(needle, 2.0)
		var dt:= get_process_delta_time()
		t += dt
		var now:= glints.peak()
		if now > last and now > 0.25:
			rising = true
			if now > top:
				top = now
				top_at = t
		elif rising and now < last:

			var gap:= "" if previous < 0.0 else "  (%.2fs since the last)" % (top_at - previous)
			print("[capture]   flash at %5.2fs  peak %.2f%s" % [top_at, top, gap])
			previous = top_at
			rising = false
			top = 0.0
		last = now


func _shoot_when(glints: NeedleGlints, needle: RigidBody3D, lit: bool,
		label: String) -> void:
	var waited:= 0
	while waited < 900:
		await get_tree().process_frame


		_look_at_needle(needle, 2.0)
		waited += 1
		var p:= glints.peak()
		if (lit and p > 0.55) or (not lit and p < 0.06):


			for q in glints.get_children():
				var mi:= q as MeshInstance3D
				if mi == null or not mi.visible:
					continue
				print("[capture]   quad at %.3v scale %.2f -> screen %.0v"
					% [mi.global_position, mi.scale.x,
						player.camera.unproject_position(mi.global_position)])
			for k in (6 if lit else 1):
				await RenderingServer.frame_post_draw
				var img:= get_viewport().get_texture().get_image()
				var name:= label if not lit else "%s_%d" % [label, k]
				img.save_png("%s/%s.png" % [OUT_DIR, name])
				print("[capture] %s at peak %.3f" % [name, glints.peak()])
			return
	push_error("capture: the blink never reached the state for %s" % label)


func _look_at_needle(needle: RigidBody3D, back: float) -> void:
	var lies:= _needle_visual(needle)
	var away:= Vector3(0.74, 0.0, 0.67).normalized() * back
	player.global_position = Vector3(lies.x + away.x, lies.y, lies.z + away.z)
	player.velocity = Vector3.ZERO
	var eye:= player.eye_position()
	var flat:= Vector3(lies.x - eye.x, 0.0, lies.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(lies.y - eye.y, maxf(flat.length(), 0.001))
	player.camera.current = true


func _needle_visual(needle: RigidBody3D) -> Vector3:
	for c in needle.get_children():
		if c is MeshInstance3D:
			return (c as MeshInstance3D).global_position
	return needle.global_position


func _write(label: String) -> void:


	for i in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, label])
	print("[capture] %s" % label)


func _conveyor_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	var live: LiveStrandManager = world.get_node("LiveStrands")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 909


	builds.add_conveyor(Vector3(13.0, 0.75, -6.0), Vector3(13.0, 0.75, 4.0))
	builds.add_conveyor(Vector3(13.0, 0.75, 4.0), Vector3(10.6, 2.15, 6.4))
	for i in 20:
		await get_tree().process_frame
	await _free_shot(Vector3(15.8, 2.7, -1.0), Vector3(12.6, 0.9, 0.5), "c1_conveyor_run")
	await _free_shot(Vector3(15.2, 2.4, 7.4), Vector3(11.8, 1.5, 5.2), "c2_conveyor_climb")


	await _free_shot(Vector3(13.1, 3.1, 4.1), Vector3(12.7, 0.75, 4.6), "c2b_corner_top")

	for k in 40:
		live.spawn(
			Vector3(13.0 + rng.randf_range(-0.2, 0.2), 1.0, -5.4 + rng.randf_range(-0.6, 0.6)),
			StrandFactory.random_strand_basis(rng), Vector3.ZERO,
			StrandFactory.random_tint(rng))
	for i in 60:
		await get_tree().process_frame
	await _free_shot(Vector3(14.4, 1.4, -3.2), Vector3(13.0, 0.85, -0.8), "c3_hay_riding")


	await _player_shot(Vector3(14.9, 1.7, 9.6), Vector3(14.9, 0.4, 5.0),
		"c4_ghost_green", "conveyor")


	player.build.primary()
	player.rotation.y += 0.62
	player.build._reach = 9.0
	await _write("c5_run_in_progress")


	player.build.cancel()
	var had:= GameState.money
	GameState.add_money(- had)
	await _write("c6_ghost_red")
	GameState.add_money(had)


func _railing_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")


	Tech.grant(BuildCatalog.unlock_of("rail"), 1)
	GameState.add_money(5000.0)


	builds.add_platform(Vector3(13.0, 0.6, 0.0), Vector2(8.0, 8.0))
	for i in 20:
		await get_tree().process_frame


	await _player_shot(Vector3(12.0, 0.6 + Player.EYE_HEIGHT, 0.6),
		Vector3(12.4, 0.6, 3.6), "r1_rail_stub", "railing")


	player.build.primary()
	player.rotation.y += 0.75
	await _write("r2_rail_run_in_progress")
	player.build.cancel()


func _wall_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	Tech.grant(BuildCatalog.unlock_of("wall"), 1)
	GameState.add_money(5000.0)


	var deck:= builds.add_platform(Vector3(14.0, 0.6, 2.0), Vector2(6.0, 10.0))
	for i in 20:
		await get_tree().process_frame
	var top:= deck.top_y()


	builds.add_wall(Vector3(11.0, top, 7.0), Vector3(17.0, top, 7.0),
		YardWall.Bay.SOLID)
	builds.add_wall(Vector3(11.0, top, 7.0), Vector3(11.0, top, 1.0),
		YardWall.Bay.WINDOW)


	builds.add_wall(Vector3(11.0, top + Cfg.WALL_COURSE, 7.0),
		Vector3(17.0, top + Cfg.WALL_COURSE, 7.0), YardWall.Bay.WINDOW)
	for i in 20:
		await get_tree().process_frame

	await _free_shot(Vector3(16.6, top + 3.2, -1.6), Vector3(12.4, top + 1.1, 5.4),
		"w1_wall_and_deck")


	var band:= top + (Cfg.WALL_WINDOW_SILL + Cfg.WALL_WINDOW_HEAD) * 0.5
	await _free_shot(Vector3(13.6, band, 4.0), Vector3(11.0, band, 4.0),
		"w2_through_the_window")


	await _player_shot(Vector3(14.6, top + Player.EYE_HEIGHT, -1.4),
		Vector3(14.6, top, 2.6), "w3_wall_ghost", "wall")
	player.build.primary()
	player.rotation.y += 0.5
	await _write("w4_wall_run_in_progress")
	player.build.cancel()


	await _free_shot(Vector3(14.0, top + 2.4, 1.4), Vector3(14.0, top + 2.2, 7.0),
		"w5_two_courses")


func _aim_from(eye: Vector3, look: Vector3) -> void:
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)


	player.set_look(atan2(- flat.x, - flat.z),
		atan2(look.y - eye.y, maxf(flat.length(), 0.001)))
	player.velocity = Vector3.ZERO
	for i in 12:
		await get_tree().process_frame


func _aim_shot(eye: Vector3, look: Vector3, label: String) -> void:
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)
	player.set_look(atan2(- flat.x, - flat.z),
		atan2(look.y - eye.y, maxf(flat.length(), 0.001)))
	player.velocity = Vector3.ZERO
	player.camera.current = true
	await _write(label)


func _tap(action: String) -> void:
	for e in InputMap.action_get_events(action):
		var key:= e as InputEventKey
		if key == null:
			continue
		for down: bool in [true, false]:
			var ev:= key.duplicate() as InputEventKey
			ev.pressed = down
			Input.parse_input_event(ev)
		return


func _roof_shots() -> void:
	var builds: BuildManager = world.get_node("Buildings")
	Tech.grant(BuildCatalog.unlock_of("wall"), 1)
	Tech.grant(BuildCatalog.unlock_of("roof"), 1)
	GameState.add_money(9000.0)


	var deck:= builds.add_platform(Vector3(14.0, 0.6, 2.0), Vector2(6.0, 10.0))
	for i in 20:
		await get_tree().process_frame
	var top:= deck.top_y()
	var eave:= top + Cfg.WALL_HEIGHT


	builds.add_wall(Vector3(12.0, top, 1.0), Vector3(12.0, top, 7.0), YardWall.Bay.SOLID)
	builds.add_wall(Vector3(16.0, top, 1.0), Vector3(16.0, top, 7.0), YardWall.Bay.SOLID)
	for i in 20:
		await get_tree().process_frame


	await _player_shot(Vector3(15.6, top + Player.EYE_HEIGHT, 0.4),
		Vector3(12.0, eave, 4.6), "rf6_roof_ghost", "roof")


	for i in 2:
		_tap("build_rotate")
		for j in 4:
			await get_tree().process_frame
	await _write("rf7_turned_out_over_the_yard")
	player._set_tool(Player.Tool.HAND)


	await _player_shot(Vector3(14.5, top + Player.EYE_HEIGHT, 1.0),
		Vector3(12.0, eave, 1.0), "rf8_run_first_click", "roof")
	player.build.primary()
	for i in 6:
		await get_tree().process_frame
	await _aim_shot(Vector3(14.5, top + Player.EYE_HEIGHT, 3.0),
		Vector3(12.0, eave, 3.0), "rf9_run_grown_to_two_bays")
	player.build.primary()


	player.build.cancel()
	player._set_tool(Player.Tool.HAND)
	for i in 20:
		await get_tree().process_frame
	await _free_shot(Vector3(14.2, eave + 3.4, -4.6), Vector3(13.0, eave, 3.4),
		"rf10_run_as_built")
	for lid in builds.roofs.duplicate():
		builds.demolish(lid)
	for i in 10:
		await get_tree().process_frame


	player.equip_build("roof")
	await _aim_from(Vector3(14.5, top + Player.EYE_HEIGHT, 1.0),
		Vector3(12.0, eave, 1.0))
	await _free_shot(Vector3(14.6, eave + 3.0, -4.4), Vector3(13.0, eave, 3.0),
		"rf12_drag_first_bay")
	player.build.primary()
	for i in 6:
		await get_tree().process_frame


	await _aim_from(Vector3(15.4, top + Player.EYE_HEIGHT, -2.0),
		Vector3(15.4, eave, 5.6))
	await _free_shot(Vector3(14.6, eave + 3.0, -4.4), Vector3(13.0, eave, 3.0),
		"rf13_drag_three_by_two")
	player.build.primary()
	player.build.cancel()
	player._set_tool(Player.Tool.HAND)
	for i in 20:
		await get_tree().process_frame
	await _free_shot(Vector3(14.6, eave + 3.0, -4.4), Vector3(13.0, eave, 3.0),
		"rf14_rectangle_as_built")
	for lid in builds.roofs.duplicate():
		builds.demolish(lid)
	for i in 10:
		await get_tree().process_frame


	player.equip_build("roof_hatch")
	await _aim_from(Vector3(14.5, top + Player.EYE_HEIGHT, 3.0),
		Vector3(12.0, eave, 3.0))
	for turn in 4:
		if turn > 0:
			_tap("build_rotate")
			for i in 6:
				await get_tree().process_frame
		await _free_shot(Vector3(16.8, eave + 4.2, 0.4),
			Vector3(13.0, eave, 3.6), "rf11_hatch_turn_%d" % turn)
	player._set_tool(Player.Tool.HAND)
	for i in 10:
		await get_tree().process_frame

	builds.add_roof(Vector3(12.0, eave, 1.0), Vector3(12.0, eave, 7.0),
		Roof.Kind.PITCHED, 1)
	builds.add_roof(Vector3(16.0, eave, 1.0), Vector3(16.0, eave, 7.0),
		Roof.Kind.PITCHED, -1)


	builds.add_wall(Vector3(12.0, top, -3.0), Vector3(12.0, top, -1.0), YardWall.Bay.SOLID)
	builds.add_wall(Vector3(16.0, top, -3.0), Vector3(16.0, top, -1.0), YardWall.Bay.SOLID)
	builds.add_roof(Vector3(12.0, eave, -3.0), Vector3(12.0, eave, -1.0),
		Roof.Kind.FLAT, 1)
	builds.add_roof(Vector3(16.0, eave, -3.0), Vector3(16.0, eave, -1.0),
		Roof.Kind.HATCH, -1)
	for i in 20:
		await get_tree().process_frame

	var ridge:= eave + Cfg.ROOF_RISE
	await _free_shot(Vector3(10.2, ridge + 1.4, -6.0), Vector3(14.0, eave, 3.0),
		"rf1_gable_on_its_walls")


	await _free_shot(Vector3(14.0, eave + 0.4, 11.0), Vector3(14.0, eave + 0.4, 3.0),
		"rf2_the_ridge_closes")


	await _free_shot(Vector3(9.6, eave - 0.5, 4.0), Vector3(12.6, eave + 0.1, 4.0),
		"rf3_eave_on_the_wall")

	await _free_shot(Vector3(13.2, top + 1.5, -5.0), Vector3(15.0, eave, -2.0),
		"rf4_the_way_up")

	await _free_shot(Vector3(15.0, eave + 2.6, -5.4), Vector3(15.0, eave, -2.0),
		"rf5_the_hatch_from_above")


func _item_shots() -> void:
	var props: PropManager = world.get_node("Props")
	var floor_y:= 0.06
	var spot:= Vector3(13.0, floor_y + 0.05, 3.0)

	var bucket: Bucket = props.spawn("bucket", Transform3D(Basis(), spot)) as Bucket
	props.spawn("sand_shovel",
		Transform3D(Basis(Vector3.UP, 0.7), spot + Vector3(0.75, 0.06, 0.25)))
	for i in 60:
		await get_tree().process_frame


	await _free_shot(spot + Vector3(1.15, 0.62, 1.05), spot + Vector3(0, 0.22, 0),
		"i1_items_on_floor")

	bucket.from_state({ "stored": Cfg.BUCKET_CAPACITY })
	for i in 5:
		await get_tree().process_frame
	await _free_shot(spot + Vector3(0.55, 0.78, 0.55), spot + Vector3(0, 0.28, 0),
		"i2_bucket_full")


	var eye:= spot + Vector3(-1.0, Player.EYE_HEIGHT, 0.0)
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	player.velocity = Vector3.ZERO
	player.camera.current = true
	var to_it:= (spot + Vector3(0, Bucket.RIM_Y * 0.5, 0)) - player.eye_position()
	player.rotation = Vector3(0, atan2(- to_it.x, - to_it.z), 0)
	player.head.rotation.x = atan2(to_it.y, Vector2(to_it.x, to_it.z).length())
	await get_tree().physics_frame
	if not player.carry.try_pick():
		push_warning("capture: could not pick the bucket up for the held shot")
	player.head.rotation.x = -0.22
	await _write("i3_bucket_held")


	player.head.rotation.x = -0.62
	Input.action_press("carry_rotate")
	for k in 40:
		player.carry.rotate_input(Vector2(0.0, -60.0))
	for i in 70:
		await get_tree().process_frame
	await _write("i4_bucket_pouring")


	var mouth:= bucket.pour_point()
	var side:= player.global_transform.basis.x.normalized()
	await _free_shot(mouth + side * 1.3 + Vector3(0, 0.15, 0),
		mouth + Vector3(0, -0.3, 0), "i4b_bucket_pouring_side")
	player.camera.current = true


	for look: Array in [[-0.15, "i4c_bucket_pouring_level"], [-1.05, "i4d_bucket_pouring_steep"]]:
		player.head.rotation.x = look [0]
		await _write(look [1])
	Input.action_release("carry_rotate")
	print("[capture] bucket held %d strands after pouring" % bucket.stored)
	player.carry.drop()


	var barrow: Wheelbarrow = props.spawn("wheelbarrow",
		Transform3D(Basis(), spot + Vector3(-1.6, 0.05, 0.6))) as Wheelbarrow
	for i in 60:
		await get_tree().process_frame
	await _free_shot(barrow.global_position + Vector3(1.5, 1.15, 1.5),
		barrow.global_position + Vector3(0, 0.35, 0), "i5_barrow_parked")


	var stand_at:= barrow.to_global(Vector3(0, 0, Wheelbarrow.GRIP.z + 1.2))
	player.global_position = Vector3(stand_at.x, barrow.global_position.y, stand_at.z)
	player.velocity = Vector3.ZERO
	player.camera.current = true
	var look:= barrow.to_global(Vector3(0, Wheelbarrow.RIM_Y, -0.2)) - player.eye_position()
	player.rotation = Vector3(0, atan2(- look.x, - look.z), 0)
	player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	for i in 12:
		await get_tree().process_frame
	await _write("i6_barrow_hover")

	if not player.carry.try_pick():
		push_warning("capture: could not take hold of the barrow")
	barrow.from_state({ "stored": Cfg.BARROW_CAPACITY })
	player.head.rotation.x = -0.3
	for i in 20:
		await get_tree().process_frame
	await _write("i7_barrow_driven")

	Input.action_press("carry_rotate")
	for k in 40:
		player.carry.rotate_input(Vector2(0.0, -60.0))
	for i in 45:
		await get_tree().process_frame
	await _write("i8_barrow_tipping")
	Input.action_release("carry_rotate")
	print("[capture] barrow held %d strands after tipping" % barrow.stored)


func _supply_shots() -> void:


	var was_no_hud:= Cfg.no_hud
	Cfg.set_no_hud(false)

	var shop: HayShop = world.get_node("SupplyShop")
	var door:= shop.interact_point()
	var counter: Vector3 = shop.to_global(Vector3(0.0, 1.15, 1.05))

	await _free_shot(shop.global_position + Vector3(-5.6, 5.2, -6.4),
		shop.global_position + Vector3(0, 1.5, 0), "u1_shop_in_room")


	var approach:= (door - shop.global_position)
	approach.y = 0.0
	approach = approach.normalized()
	var spawn: Vector3 = world.get("SPAWN_POS")
	await _player_shot(Vector3(spawn.x, Player.EYE_HEIGHT, spawn.z),
		shop.global_position + Vector3(0, 1.4, 0), "u2_walking_up", "none")
	await _player_shot(door + approach * 0.6 + Vector3(0, Player.EYE_HEIGHT, 0),
		counter, "u3_prompt", "none")


	var menu: ShopMenu = world.get("shop_menu")
	await _player_shot(door + Vector3(0, Player.EYE_HEIGHT, 0), counter,
		"u4_counter", "none")
	if menu != null and not menu.try_open():
		print("[capture] the counter would not open on the doorstep")
	await _write("u5_counter_open")
	if menu != null:
		menu.set_open(false)
		player.capture_mouse(true)


	await _free_shot(shop.to_global(Vector3(-1.85, 1.48, 3.6)),
		shop.to_global(Vector3(-1.45, 1.12, 0.9)), "u6_counter_stock")
	await _free_shot(shop.to_global(Vector3(1.25, 1.95, 5.1)),
		shop.to_global(Vector3(1.35, 1.25, 0.2)), "u7_tool_wall")
	await _free_shot(shop.to_global(Vector3(5.2, 1.55, 6.0)),
		shop.to_global(Vector3(2.9, 0.5, 2.4)), "u8_barrow")
	Cfg.set_no_hud(was_no_hud)


func _sell_stand_shots() -> void:
	var st: HaySellingStand = world.get_node("SellingStand")
	var live: LiveStrandManager = world.get_node("LiveStrands")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 5150


	var bay: Vector3 = st.to_global(Vector3(-2.1, 1.18, 3.05))
	var belt_feed: Vector3 = st.to_global(Vector3(-2.1, 0.62, 3.05))
	var lip: Vector3 = st.to_global(Vector3(-2.1, 0.02, 5.2))
	var board: Vector3 = st.to_global(Vector3(4.25, 0.8, 2.53))
	var till: Vector3 = st.to_global(Vector3(0.02, 1.39, 1.25))

	await _free_shot(Vector3(3.5, 7.4, -4.6), st.global_position + Vector3(0, 1.6, 0),
		"s1_stand_in_room")
	await _player_shot(lip + Vector3(0, 1.66, 0), bay, "s2_at_the_lip", "shovel")
	await _free_shot(board + (board - till).normalized() * 2.2 + Vector3(0, 0.35, 0),
		board, "s3_price_board")


	for k in 60:
		live.spawn(st.to_global(Vector3(-2.1 + rng.randf_range(-0.5, 0.5),
			rng.randf_range(0.52, 0.82), 3.05 + rng.randf_range(-0.4, 0.4))),
			StrandFactory.random_strand_basis(rng), Vector3(0, -1.0, 0),
			StrandFactory.random_tint(rng))


	for i in 240:
		await get_tree().process_frame
	await _player_shot(lip + Vector3(0, 1.66, 0), bay + Vector3(0, 0.9, 0),
		"s4_payout", "shovel")

	var front:= (bay - till)
	front.y = 0.0
	await _free_shot(till + front.normalized() * 2.4 + Vector3(0, 0.45, 0), till, "s5_till")
	print("[capture] money now $%.2f, sold %d strands" % [GameState.money, int(GameState.hay_sold)])


	var before:= GameState.money
	var found:= GameState.needles_found
	live.reveal_needle(0, belt_feed)
	for i in 240:
		await get_tree().process_frame
	print("[capture] needle scrapped for $%.2f (expected $%.2f), needles found %d -> %d"
		% [GameState.money - before, Cfg.NEEDLE_SCRAP_PRICE, found, GameState.needles_found])


	var sales: Array [int] = []
	st.sold.connect(func(n: int, _amount: float) -> void: sales.append(n))
	for wave in 8:
		for k in 25:
			live.spawn(st.to_global(Vector3(-2.1 + rng.randf_range(-0.5, 0.5), 0.62,
				3.05 + rng.randf_range(-0.4, 0.4))),
				StrandFactory.random_strand_basis(rng), Vector3.ZERO,
				StrandFactory.random_tint(rng))
		for i in 8:
			await get_tree().process_frame
	for i in 360:
		await get_tree().process_frame
	print("[capture] 200 strands fed continuously -> %d payouts %s, %d strands sold total"
		% [sales.size(), str(sales), int(GameState.hay_sold)])


func _model_sheet() -> void:
	var live: LiveStrandManager = world.get_node("LiveStrands")
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4242


	var origin:= Vector3(13.0, 1.1, 11.0)


	var key:= OmniLight3D.new()
	key.light_energy = 9.0
	key.omni_range = 7.0
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = true
	world.add_child(key)
	key.global_position = origin + Vector3(0.6, 1.3, 0.9)
	var fill:= OmniLight3D.new()
	fill.light_energy = 3.0
	fill.omni_range = 8.0
	fill.light_color = Color(0.72, 0.78, 0.92)
	world.add_child(fill)
	fill.global_position = origin + Vector3(-1.6, 0.9, -1.4)

	_pin(live, origin, Basis(Vector3.UP, 0.55), rng)
	await _free_shot(origin + Vector3(0.2, 0.06, 0.16), origin, "m1_hay_strand")


	for k in 5:
		_pin(live, origin + Vector3(0, 0, 0.07 * (k + 1)),
			Basis(Vector3.UP, 0.55 + 0.05 * k), rng)
	await _free_shot(origin + Vector3(0.42, 0.16, 0.21), origin + Vector3(0, 0, 0.18),
		"m2_strand_colour_range")


	var npos:= origin + Vector3(0.0, 0.0, -0.55)
	var needle:= live.reveal_needle(-1, npos)
	needle.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	needle.freeze = true
	needle.global_transform = Transform3D(Basis(Vector3.UP, 0.6), npos)
	await _free_shot(npos + Vector3(0.11, 0.035, 0.07), npos, "m3_needle_macro")
	await _free_shot(npos + Vector3(0.3, 0.09, 0.19), npos, "m4_needle_vs_strand")


	player._set_tool(Player.Tool.SHOVEL)
	var sb:= player.shovel.body
	player.shovel._active = false
	sb.freeze = true
	var spade_at:= origin + Vector3(-0.1, 0.05, 0.0)

	sb.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, 2.5, 0.0)), spade_at)
	await _free_shot(spade_at + Vector3(0.55, 0.62, 0.85), spade_at, "m5_spade_3q")

	sb.global_transform = Transform3D(Basis.from_euler(Vector3(-0.5, 2.1, 0.0)), spade_at)
	await _free_shot(spade_at + Vector3(0.3, 0.34, 0.42), spade_at + Vector3(-0.12, 0.0, -0.1),
		"m6_spade_blade")


func _pin(live: LiveStrandManager, pos: Vector3, b: Basis, rng: RandomNumberGenerator) -> void:
	var s:= live.spawn(pos, b, Vector3.ZERO, StrandFactory.random_tint(rng))
	if s == null:
		return
	s.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	s.freeze = true
	s.global_transform = Transform3D(b, pos)


func _scoop_shots() -> void:
	var field: HayField = world.get_node("HayField")
	var eye:= Vector3(11.6, 1.7, 0.6)
	var look:= Vector3(9.2, 1.35, 0.3)
	await _player_shot(eye, look, "scoop_1_aimed", "shovel")

	var sh: Shovel = player.shovel
	var aim: Dictionary = sh.aim_point()
	if aim.is_empty():
		print("[scoop] no aim point -- blade is not pointing at the pile")
		return
	var centre: Vector3 = aim ["position"]
	print("[scoop] aim at %v" % centre)
	print("[scoop] strands inside the highlight: %d"
		% field.count_in_radius(centre, Cfg.SCOOP_RADIUS))
	var before:= GameState.hay_total
	var lifted:= sh.scoop()
	print("[scoop] lifted onto the blade : %d strands" % lifted)
	print("[scoop] hay removed from pile : %.1f" % (before - GameState.hay_total))
	print("[scoop] live bodies active    : %d" % world.live.active_count())

	for i in 40:
		await get_tree().process_frame
	print("[scoop] carried in the pan after settling: %d" % sh.carried_strands())
	await _player_shot(eye, look, "scoop_2_after", "shovel")


func _crater_shots() -> void:
	var eye:= Vector3(11.6, 1.7, 0.6)
	var look:= Vector3(9.2, 1.35, 0.3)
	await _player_shot(eye, look, "crater_0_before", "shovel")
	for n in 10:
		player.shovel.scoop()
		for i in 12:
			await get_tree().process_frame
	for i in 60:
		await get_tree().process_frame
	await _player_shot(eye, look, "crater_1_dug", "shovel")

	await _player_shot(Vector3(10.4, 2.9, 0.4), Vector3(9.0, 0.6, 0.2),
		"crater_2_looking_down", "shovel")


	await _player_shot(Vector3(11.9, 1.05, 0.9), Vector3(10.15, 0.35, 0.35),
		"crater_3_rim", "none")


func _churn_shots() -> void:
	var field: HayField = world.get_node("HayField")
	var live: LiveStrandManager = world.live


	for lap in 3:
		for k in 20:
			var a:= TAU * (float(k) + 0.5 * float(lap)) / 20.0
			var r:= 8.6 - 0.7 * float(lap)
			var at:= Vector3(cos(a) * r, 0.0, sin(a) * r)
			at.y = field.height_at(at.x, at.z) - 0.4
			if at.y < 0.3:
				continue
			var carved:= field.carve_sphere(at, 1.1, 1.2)
			live.spawn_from_carve(carved ["points"], carved ["strands"],
				Vector3(0, 0.6, 0))
			for i in 6:
				await get_tree().process_frame

	for i in 240:
		await get_tree().process_frame

	var eye:= Vector3(13.5, 2.4, 0.0)
	var look:= Vector3(7.0, 2.2, 0.0)
	var vp:= get_viewport()
	var occ_was: bool = vp.use_occlusion_culling
	vp.use_occlusion_culling = true
	await _free_shot(eye, look, "churn_1_live_occlusion_on")
	vp.use_occlusion_culling = false
	await _free_shot(eye, look, "churn_1_live_occlusion_off")
	vp.use_occlusion_culling = occ_was


	var crusts: Array [Node] = []
	var shells: Array [Node] = []
	for c in field.chunks:
		var cr:= c.get_node_or_null("Crust")
		if cr != null:
			crusts.append(cr)
		var sh:= c.get_node_or_null("Shell")
		if sh != null:
			shells.append(sh)
	for n: Node in crusts:
		(n as Node3D).visible = false
	await _free_shot(eye, look, "churn_2_shell_only")
	for n: Node in crusts:
		(n as Node3D).visible = true
	for n: Node in shells:
		(n as Node3D).visible = false
	await _free_shot(eye, look, "churn_3_crust_only")
	for n: Node in shells:
		(n as Node3D).visible = true


	for b in live._active.duplicate():
		live.consume(b)
	await _free_shot(eye, look, "churn_4_no_live")


	var nc:= Cfg.field_cells()
	var over:= [0, 0, 0, 0]
	var worst:= 0.0
	for cj in nc:
		for ci in nc:
			if field.cell_height(ci, cj) < 0.05:
				continue
			var drift: float = absf(field.cell_height(ci, cj)
				- field._cell_render_h [cj * nc + ci])
			worst = maxf(worst, drift)
			if drift >= 0.025:
				over [0] += 1
			if drift >= 0.05:
				over [1] += 1
			if drift >= 0.1:
				over [2] += 1
			if drift >= 0.2:
				over [3] += 1
	print("[churn] crust drift: >=2.5cm %d, >=5cm %d, >=10cm %d, >=20cm %d, worst %.3f m"
		% [over [0], over [1], over [2], over [3], worst])


	var bad_visible:= 0
	var above_aabb:= 0
	var worst_over:= 0.0
	for c in field.chunks:
		if c._mm == null:
			continue
		var expect: int = c._lod_visible_k * c._slot_cells.size()
		if c._lod_visible_k > 0 and c._mm.visible_instance_count != expect:
			bad_visible += 1
		var box: AABB = c._mmi.custom_aabb
		var top: float = box.position.y + box.size.y
		if c._max_h > top:
			above_aabb += 1
			worst_over = maxf(worst_over, c._max_h - top)
	print("[churn] chunks with stale visible count: %d" % bad_visible)
	print("[churn] chunks with hay above their AABB: %d (worst %.2f m over)"
		% [above_aabb, worst_over])


	for c in field.chunks:
		c._refresh_aabb()
		c._lod_visible_k = -1
	field.update_lod(eye)
	for i in 5:
		await get_tree().process_frame
	await _free_shot(eye, look, "churn_4b_aabb_lod")


	print("[churn] crust drawn before any rebuild: %d" % field.drawn_instance_count())
	for c in field.chunks:
		c.rebuild_all_cells()
	for i in 10:
		await get_tree().process_frame
	print("[churn] crust drawn after crust-only rebuild: %d" % field.drawn_instance_count())
	await _free_shot(eye, look, "churn_5_crust_rebuilt")

	for c in field.chunks:
		c.rebuild_collision()
	for i in 10:
		await get_tree().process_frame
	await _free_shot(eye, look, "churn_6_shell_rebuilt")


func _dugface_shot() -> void:
	var field: HayField = world.get_node("HayField")
	var nc:= Cfg.field_cells()
	var best:= 0.0
	var at:= Vector3.ZERO
	for j in nc:
		for i in nc:
			var c:= field.cell_center(i, j)
			var dug:= field.dug_depth_at(c.x, c.z)
			if dug > best:
				best = dug
				at = c
	at.y = field.height_at(at.x, at.z)
	print("[capture] deepest dig is %.2f m at %.1v" % [best, at])


	var out:= Vector3(at.x, 0.0, at.z) - Cfg.PILE_CENTER
	if out.length_squared() < 1.0:
		out = Vector3.RIGHT
	out = out.normalized()


	for dist: float in [1.2, 2.4]:
		var eye: Vector3 = at + out * dist + Vector3(0, dist * 0.9 + 0.4, 0)
		await _free_shot(eye, at, "dugface_%.1fm" % dist)


func _hollow_shots() -> void:
	var field: HayField = world.get_node("HayField")


	var at:= Vector3(8.4, 0.0, 0.0)
	at.y = field.height_at(at.x, at.z)
	var eye:= Vector3(12.4, 1.6, 0.0)
	var look:= Vector3(at.x - 0.6, 1.0, 0.0)
	await _free_shot(eye, look, "hollow_0_before")


	for k in 16:
		var a:= TAU * float(k) / 16.0
		field.carve_sphere(at + Vector3(cos(a), 0.0, sin(a)) * 1.0, 1.2, 1.9)
	field.carve_sphere(at, 1.5, 2.1)
	for i in 90:
		await get_tree().process_frame

	await _free_shot(eye, look, "hollow_1_face")

	await _free_shot(Vector3(11.0, 1.5, 0.0), Vector3(at.x - 0.4, 1.1, 0.0),
		"hollow_2_close")


func _rimdig_shots() -> void:
	var eye:= Vector3(12.3, 1.35, 0.5)
	var look:= Vector3(10.1, 0.32, 0.2)
	await _player_shot(eye, look, "rimdig_0_before", "shovel")


	for n in 22:
		var z: float = -1.2 + 0.12 * float(n)
		var e:= Vector3(12.3, 1.35, z + 0.35)
		var l:= Vector3(10.1, 0.3, z)
		player.global_position = e - Vector3(0, Player.EYE_HEIGHT, 0)
		var flat:= Vector3(l.x - e.x, 0.0, l.z - e.z)
		player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
		player.head.rotation.x = atan2(l.y - e.y, maxf(flat.length(), 0.001))
		for i in 3:
			await get_tree().process_frame
		player.shovel.scoop()
		for i in 8:
			await get_tree().process_frame
	for i in 90:
		await get_tree().process_frame

	await _player_shot(eye, look, "rimdig_1_after", "shovel")
	await _player_shot(Vector3(12.6, 1.05, 0.2), Vector3(10.0, 0.28, 0.0),
		"rimdig_2_low", "none")
	await _player_shot(Vector3(11.6, 2.2, 1.6), Vector3(9.8, 0.3, 0.1),
		"rimdig_3_above", "none")


func _repro_shot() -> void:
	var origin:= Vector3(2.241122, 1.661097, -11.917944)
	var b:= Basis(
		Vector3(-0.972663, 0.0, -0.232222),
		Vector3(0.05772, 0.968618, -0.241759),
		Vector3(0.224935, -0.248553, -0.942139))
	Cfg.perf_scale = 0.88
	world.field.update_lod(origin)
	_cam.current = true
	_cam.global_transform = Transform3D(b, origin)
	var vp:= get_viewport()
	var occ_was: bool = vp.use_occlusion_culling
	vp.use_occlusion_culling = true
	await _write("repro_exact_occlusion_on")
	vp.use_occlusion_culling = false
	await _write("repro_exact_occlusion_off")
	vp.use_occlusion_culling = occ_was


	for step: float in [-2.0, 2.0, 4.0]:
		var fwd:= - b.z
		var p:= origin + fwd * step
		_cam.global_transform = Transform3D(b, p)
		world.field.update_lod(p)
		await _write("repro_dist_%+.0f" % step)


func _shadow_spot_shots() -> void:
	var sun:= world.get_node("Sun") as DirectionalLight3D
	var field:= world.get_node("HayField") as HayField
	_cam.current = true
	_cam.global_transform = Transform3D(
		Basis(Vector3(-0.789195, 0.0, -0.614143),
			Vector3(-0.375387, 0.791447, 0.482385),
			Vector3(0.486062, 0.611237, -0.624606)),
		Vector3(-4.571328, 1.660846, -10.225988))
	field.update_lod(_cam.global_position)
	sun.shadow_blur = 0.0

	var crusts: Array [MultiMeshInstance3D] = []
	var proxies: Array [MeshInstance3D] = []
	var crust_modes: Array [int] = []
	var proxy_modes: Array [int] = []
	for chunk in field.chunks:
		var crust:= chunk.get_node_or_null("Crust") as MultiMeshInstance3D
		var proxy:= chunk.get_node_or_null("ShadowProxy") as MeshInstance3D
		if crust != null:
			crusts.append(crust)
			crust_modes.append(crust.cast_shadow)
		if proxy != null:
			proxies.append(proxy)
			proxy_modes.append(proxy.cast_shadow)

	await _write("shadowspots_0_all")
	sun.shadow_enabled = false
	await _write("shadowspots_1_no_sun_shadow")
	sun.shadow_enabled = true

	for crust in crusts:
		crust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _write("shadowspots_2_no_crust_shadow")
	for i in crusts.size():
		crusts [i].cast_shadow = crust_modes [i]

	for proxy in proxies:
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _write("shadowspots_3_no_proxy_shadow")
	for i in proxies.size():
		proxies [i].cast_shadow = proxy_modes [i]


	field.heights.fill(0.0)
	var forward:= Vector2(-0.486062, 0.624606).normalized()
	var side:= Vector2(- forward.y, forward.x)
	var origin:= Vector2(-4.571328, -10.225988)
	var patches:= [
		[origin + forward * 3.8 + side * 1.3, 0.22, 0.75],
		[origin + forward * 5.2 - side * 0.8, 0.42, 0.9],
		[origin + forward * 6.6 + side * 0.7, 0.68, 1.05],
		[origin + forward * 8.0 - side * 1.0, 0.95, 1.2],
	]
	var nv:= Cfg.field_verts()
	for j in nv:
		for i in nv:
			var p:= Vector2(- Cfg.FIELD_EXTENT + i * Cfg.CELL,
				- Cfg.FIELD_EXTENT + j * Cfg.CELL)
			var h:= 0.0
			for spec in patches:
				var distance: float = p.distance_to(spec [0])
				var radius: float = spec [2]
				if distance < radius:
					var t: float = 1.0 - distance / radius
					h = maxf(h, float(spec [1]) * t * t)
			field.heights [j * nv + i] = h
	field.dome = field.heights.duplicate()
	field.rebuild_everything()
	field.update_lod(_cam.global_position)
	for i in 30:
		await get_tree().process_frame
	sun.shadow_enabled = false
	var shell_mat:= StrandFactory.pile_surface_material()
	shell_mat.set_shader_parameter("solid_core", true)
	await _write("shadowspots_4_remnants_core")
	shell_mat.set_shader_parameter("solid_core", false)
	await _write("shadowspots_5_remnants_no_core")
	for crust in crusts:
		crust.visible = false
	await _write("shadowspots_6_remnants_shells_no_core")


	for crust in crusts:
		crust.visible = true
	var sun_energy:= sun.light_energy
	sun.light_energy = 0.0
	shell_mat.set_shader_parameter("solid_core", true)
	await _write("shadowspots_7_remnants_ambient_core")
	shell_mat.set_shader_parameter("solid_core", false)
	await _write("shadowspots_8_remnants_ambient_no_core")
	for crust in crusts:
		crust.visible = false
	shell_mat.set_shader_parameter("solid_core", true)
	await _write("shadowspots_9_remnants_ambient_shell_core")
	shell_mat.set_shader_parameter("solid_core", false)
	await _write("shadowspots_10_remnants_ambient_shell_no_core")
	sun.light_energy = sun_energy


func _blowout_shots() -> void:
	var env: Environment = (world.get_node("Environment") as WorldEnvironment).environment
	var terrain:= world.get_node("YardTerrain") as Node3D
	var mat:= StrandFactory.hay_material()
	var glow_was:= env.glow_enabled
	var thresh_was:= env.glow_hdr_threshold


	var aniso_read: Variant = mat.get_shader_parameter("anisotropy")
	var spec_read: Variant = mat.get_shader_parameter("gloss_specular")
	var aniso_was: float = 0.2 if aniso_read == null else float(aniso_read)
	var spec_was: float = 0.28 if spec_read == null else float(spec_read)


	var bundle:= Transform3D(
		Basis(Vector3(0.065125, 0.0, 0.997877),
			Vector3(-0.100781, 0.994887, 0.006577),
			Vector3(-0.992775, -0.100996, 0.064792)),
		Vector3(-10.149891, -0.06807, -5.869812))


	var face:= _look_at_xform(Vector3(11.4, 1.7, 1.2), Vector3(4.0, 3.4, 0.0))
	var yard:= _look_at_xform(Vector3(-18.0, 1.0, -6.0), Vector3(-6.0, -1.4, -5.0))
	var above:= _look_at_xform(Vector3(-16.0, 8.0, -18.0), Vector3(-6.0, -1.4, -4.0))

	_cam.current = true
	for framing: Array in [[bundle, "bundle"], [yard, "yard"], [above, "above"], [face, "face"]]:
		var xform: Transform3D = framing [0]
		var where: String = framing [1]
		_cam.global_transform = xform
		world.field.update_lod(xform.origin)

		await _write("blow_%s_1_asis" % where)

		env.glow_enabled = false
		await _write("blow_%s_2_glow_off" % where)
		env.glow_enabled = glow_was


		terrain.visible = false
		await _write("blow_%s_3_terrain_off" % where)
		terrain.visible = true

		mat.set_shader_parameter("anisotropy", 0.0)
		mat.set_shader_parameter("gloss_specular", 0.0)
		await _write("blow_%s_4_gloss_off" % where)
		mat.set_shader_parameter("anisotropy", aniso_was)
		mat.set_shader_parameter("gloss_specular", spec_was)

		env.glow_hdr_threshold = 1.9
		await _write("blow_%s_5_threshold_1v9" % where)
		env.glow_hdr_threshold = thresh_was


func _blob_hunt() -> void:
	var env: Environment = (world.get_node("Environment") as WorldEnvironment).environment
	_cam.current = true
	_cam.global_transform = Transform3D(
		Basis(Vector3(0.142491, 0.0, 0.989796),
			Vector3(-0.008714, 0.999961, 0.001254),
			Vector3(-0.989758, -0.008803, 0.142485)),
		Vector3(-11.67844, -0.094972, -6.866073))
	world.field.update_lod(_cam.global_position)

	var base:= await _blown_pixels("hunt_0_asis")
	print("\r\n-- the disc, measured in its own box --")
	print("  %7d as-is" % base)

	env.glow_enabled = false
	print("  %7d with glow off" % await _blown_pixels("hunt_1_glow_off"))
	env.glow_enabled = true

	print("\r\n-- how bright the source is --")


	var bloom_was:= env.glow_bloom
	var thresh_was:= env.glow_hdr_threshold
	env.glow_bloom = 0.0
	print("  %7d with glow_bloom 0, threshold at %.2f" % [
		await _blown_pixels("hunt_nobloom"), thresh_was])
	for t: float in [2.0, 4.0, 8.0, 16.0]:
		env.glow_hdr_threshold = t
		print("  %7d and threshold %5.2f" % [
			await _blown_pixels("hunt_t_%05.2f" % t), t])
	env.glow_hdr_threshold = thresh_was
	env.glow_bloom = bloom_was


	print("\n-- the shell material's own terms --")
	var shell_mat:= StrandFactory.pile_surface_material()


	for term: String in ["anisotropy", "gloss_specular"]:
		var was: Variant = shell_mat.get_shader_parameter(term)
		shell_mat.set_shader_parameter(term, 0.0)
		print("  %7d with the shell's %s at 0" % [
			await _blown_pixels("hunt_shell_no_%s" % term), term])
		shell_mat.set_shader_parameter(term, was)


	print("\r\n-- which half of the pile --")
	var crusts: Array [Node3D] = []
	var shells: Array [Node3D] = []
	for chunk in (world.get_node("HayField") as HayField).chunks:
		var c:= chunk.get_node_or_null("Crust") as Node3D
		if c != null and c.visible:
			crusts.append(c)
		for name: String in ["Shell", "Surface", "Shells"]:
			var sh:= chunk.get_node_or_null(name) as Node3D
			if sh != null and sh.visible:
				shells.append(sh)
	for group: Array in [[crusts, "crust"], [shells, "shell/surface"]]:
		var nodes: Array = group [0]
		if nodes.is_empty():
			print("  (no %s nodes found to hide)" % group [1])
			continue
		for n: Node3D in nodes:
			n.visible = false
		print("  %7d  without the %s (%d nodes)" % [
			await _blown_pixels("hunt_no_%s" % String(group [1]).replace("/", "_")),
			group [1], nodes.size()])
		for n: Node3D in nodes:
			n.visible = true

	print("\r\n-- which node --")
	var rows:= []
	for child in world.get_children():
		var node:= child as Node3D
		if node == null or not node.visible or node == _cam:
			continue
		node.visible = false
		rows.append([await _blown_pixels("hunt_no_%s" % node.name), node.name])
		node.visible = true
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a [0] < b [0])
	for r: Array in rows:
		print("  %7d  (%+6.1f%%)  without %s" % [
			r [0], 100.0 * (float(r [0]) - float(base)) / maxf(float(base), 1.0), r [1]])
	print("")


func _blown_pixels(label: String) -> int:


	var best:= 0
	for pass_i in 3:
		for i in (45 if pass_i == 0 else 17):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img:= get_viewport().get_texture().get_image()
		var n:= 0


		for y in range(BOX.position.y, BOX.end.y, 2):
			for x in range(BOX.position.x, BOX.end.x, 2):


				var c:= img.get_pixel(x, y)
				if (c.r + c.g + c.b) / 3.0 > 0.9:
					n += 1
		if n >= best:
			best = n
			img.save_png("%s/%s.png" % [OUT_DIR, label])
	return best * 4


func _look_at_xform(eye: Vector3, target: Vector3) -> Transform3D:
	var back:= (eye - target).normalized()
	var right:= Vector3.UP.cross(back).normalized()
	return Transform3D(Basis(right, back.cross(right), back), eye)
