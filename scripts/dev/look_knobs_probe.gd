class_name DevLookKnobsProbe
extends Node


var world: Node3D

const SETTLE:= 12


func run() -> void:
	for _i in SETTLE:
		await get_tree().process_frame

	var menu: DebugMenu = world.debug_menu
	if menu == null:
		print("[lookknobs] FAIL: no debug menu in this world")
		get_tree().quit(1)
		return
	var env:= (world.get_node("Environment") as WorldEnvironment).environment
	var sun:= world.get_node("Sun") as DirectionalLight3D

	var was:= {
		"exposure": env.tonemap_exposure,
		"fog_density": env.fog_density,
		"sun_energy": sun.light_energy,
		"sun_dir": sun.global_transform.basis.z,
		"saturation": env.adjustment_saturation,
	}
	var settings_before:= _settings_bytes()

	menu._open_look_panel()
	var bad:= 0
	if menu._look_panel == null:
		print("  FAIL  the panel did not build")
		get_tree().quit(1)
		return


	menu._set_gfx_live("exposure", 1.42)
	world._apply_render_settings()
	bad += _check("exposure survives a render settings pass",
		is_equal_approx(env.tonemap_exposure, 1.42))
	bad += _check("and it did not become a saved override",
		not Cfg._gfx_user.has("exposure"))


	env.fog_density = 0.031
	world._apply_render_settings()
	bad += _check("fog density stands", is_equal_approx(env.fog_density, 0.031))


	menu._set_sun_elev(20.0)
	menu._set_sun_azim(-90.0)
	var travel:= - sun.global_transform.basis.z
	bad += _check("the sun still shines downward", travel.y < 0.0)
	bad += _check("at the elevation asked for",
		is_equal_approx(rad_to_deg(asin(- travel.y)), 20.0))
	sun.light_energy = 5.5


	menu._on_look_copy()


	for line: String in menu._look_text().split("\n"):
		if not line.begins_with("transform = "):
			continue
		var back: Variant = str_to_var(line.substr(12))
		bad += _check("the transform survives being pasted",
			back is Transform3D and (back as Transform3D).is_equal_approx(
				sun.transform))


	menu._set_sun_rot(-35.0, Vector3.AXIS_X)
	menu._set_sun_rot(120.0, Vector3.AXIS_Y)
	bad += _check("rotation X landed",
		is_equal_approx(sun.rotation_degrees.x, -35.0))
	bad += _check("rotation Y landed",
		is_equal_approx(sun.rotation_degrees.y, 120.0))
	bad += _check("and the elevation row followed it",
		is_equal_approx(menu._sun_elev, rad_to_deg(asin(
			sun.global_transform.basis.z.normalized().y))))


	menu._set_gfx_live("white", 11.0)
	menu._set_gfx_live("ssao", not bool(Cfg.gfx ["ssao"]))
	env.adjustment_saturation = 1.7
	sun.light_energy = 6.5
	var undone:= 0


	for node: Node in menu._look_panel.find_children("*", "Button", true, false):
		var b:= node as Button
		if b.text != menu._undo_glyph():
			continue
		b.pressed.emit()
		undone += 1
	bad += _check("every row has an undo (found %d)" % undone, undone >= 25)
	var want:= Cfg.authored_gfx()
	bad += _check("white point back", is_equal_approx(env.tonemap_white,
		float(want ["white"])))
	bad += _check("the occlusion switch back",
		bool(Cfg.gfx ["ssao"]) == bool(want ["ssao"]))
	bad += _check("saturation back", is_equal_approx(
		env.adjustment_saturation, float(was ["saturation"])))
	bad += _check("sun energy back from its own button",
		is_equal_approx(sun.light_energy, float(was ["sun_energy"])))
	bad += _check("and the sun is aimed where it was authored",
		sun.global_transform.basis.z.dot(was ["sun_dir"]) > 0.999)


	var sky:= env.sky.sky_material as ShaderMaterial
	var sky_was: Variant = sky.get_shader_parameter("rayleigh_strength")
	sky.set_shader_parameter("rayleigh_strength", 3.3)
	menu._on_look_revert()
	bad += _check("exposure back", is_equal_approx(env.tonemap_exposure,
		float(was ["exposure"])))
	bad += _check("fog back", is_equal_approx(env.fog_density,
		float(was ["fog_density"])))
	bad += _check("sun energy back", is_equal_approx(sun.light_energy,
		float(was ["sun_energy"])))
	bad += _check("sun aimed back", sun.global_transform.basis.z.dot(
		was ["sun_dir"]) > 0.9999)
	bad += _check("and the sky came back with it", is_equal_approx(
		float(sky.get_shader_parameter("rayleigh_strength")),
		float(sky_was)))


	bad += _check("settings.cfg untouched",
		_settings_bytes() == settings_before)


	menu.set_open(true)
	menu._open_look_panel()
	menu.set_open(false)
	menu.set_open(true)
	bad += _check("the menu comes back after F1 over the look panel",
		menu._panel.visible and not menu._look_modal.visible)
	menu.set_open(false)


	menu.set_open(true)
	var player:= world.player as Player
	bad += _check("the menu leaves the legs on", player.free_move
		and player._accepts_move() and not player.is_mouse_captured())
	bad += _check("and nothing pours while it is up", not player.pour_intent())
	menu.set_open(false)
	bad += _check("the legs go back to the mouse on close",
		not player.free_move and player.is_mouse_captured())

	if bad == 0:
		print("[lookknobs] PASS")
	else:
		print("[lookknobs] FAIL: %d" % bad)
	get_tree().quit(0 if bad == 0 else 1)


func _check(what: String, ok: bool) -> int:
	if ok:
		print("  ok    %s" % what)
		return 0
	print("  FAIL  %s" % what)
	return 1


func _settings_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(Cfg.SETTINGS_PATH):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(Cfg.SETTINGS_PATH)
