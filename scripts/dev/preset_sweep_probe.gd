class_name DevPresetSweepProbe
extends Node


const OUT_DIR:= "res://captures"
const SETTLE_FRAMES:= 60
const SHOT_FRAMES:= 45

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D


func run() -> void:


	world.set("block_save", true)
	world.set("autosave_enabled", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var started: int = Cfg.quality
	print("\n=== the game started on %s ===" % Cfg.PRESETS [started] ["name"])

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.01
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true

	var at:= _deepest_dig()
	if at == Vector3.INF:
		print("  this pile has not been dug into -- run with --usesave")
		get_tree().quit(1)
		return
	at.y = field.height_at(at.x, at.z)
	var out:= (Vector3(at.x, 0.0, at.z) - Cfg.PILE_CENTER).normalized()
	var eye: Vector3 = at + out * 1.2 + Vector3(0.0, 1.5, 0.0)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	_cam.look_at_from_position(eye, at, Vector3.UP)


	await _shoot(eye, at, "sweep_boot_%s" % _slug(started))

	print("\n=== and now switched, one preset at a time ===")
	for level: int in Cfg.Quality.values():
		Cfg.set_quality(level)
		Cfg.perf_scale = 1.0
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		field.update_lod(eye)
		await _shoot(eye, at, "sweep_switch_%s" % _slug(level))

	print("\n=== and what a preset switch does to a hand-set override ===")


	Cfg.set_gfx("hay_density", 400)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	field.update_lod(eye)
	print("  set hay_density by hand -> %d, drawn %d"
		% [int(Cfg.gfx ["hay_density"]), field.drawn_instance_count()])
	await _shoot(eye, at, "sweep_override_400")


	var other: int = Cfg.Quality.HIGH if Cfg.quality != Cfg.Quality.HIGH else Cfg.Quality.MEDIUM
	print("  moving the dial from %s to %s"
		% [Cfg.PRESETS [Cfg.quality] ["name"], Cfg.PRESETS [other] ["name"]])
	Cfg.set_quality(other)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	field.update_lod(eye)
	print("  then moved the quality dial -> %d, drawn %d"
		% [int(Cfg.gfx ["hay_density"]), field.drawn_instance_count()])
	await _shoot(eye, at, "sweep_override_after_switch")

	print("\nBoot frame vs switched frame at the SAME preset is the whole")
	print("question of whether switching applies what starting applies.")
	print("  -> %s" % OUT_DIR)
	get_tree().quit(0)


func _slug(level: int) -> String:
	return String(Cfg.PRESETS [level] ["name"]).to_lower()


func _shoot(eye: Vector3, look: Vector3, name: String) -> void:
	_cam.look_at_from_position(eye, look, Vector3.UP)
	for i in SHOT_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, name])
	var vp:= get_viewport()
	var e: Environment = world.get_node("Environment").environment
	print("  %-24s drawn %8d  lod_min %.2f  ssil %s  taa %s  msaa %d"
		% [name, field.drawn_instance_count(), Cfg.crust_lod_min,
			"on " if e.ssil_enabled else "off", "on " if vp.use_taa else "off",
			int(vp.msaa_3d)])


func _deepest_dig() -> Vector3:
	var nc:= Cfg.field_cells()
	var best:= 0.0
	var at:= Vector3.INF
	for j in nc:
		for i in nc:
			var c:= field.cell_center(i, j)
			var dug:= field.dug_depth_at(c.x, c.z)
			if dug > best:
				best = dug
				at = c
	if best <= Cfg.HAY_SHELL_DIG_DEADBAND:
		return Vector3.INF
	print("  deepest dig %.2f m at %.1v" % [best, at])
	return at
