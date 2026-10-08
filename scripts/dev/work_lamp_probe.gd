class_name DevWorkLampProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const REBUILD_FRAMES:= 8

const LANE_X:= 13.0

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _case_the_model()
	await _case_the_lights()
	await _case_the_aim()
	await _case_no_shadows()
	await _case_the_dial()
	await _case_the_switch()
	await _case_the_reach()
	await _case_the_panel()
	await _case_the_hologram()
	await _case_no_power()
	await _case_the_money()
	await _case_the_card()
	await _case_a_save_round_trip()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_model() -> void:
	print("\n=== the model ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	_check("the model loads", lamp._model != null)
	for marker: String in WorkLamp.N_LAMPS:
		_check("the model ships %s" % marker,
			lamp._model != null and lamp._model.find_child(marker, true, false) != null)


	var heads:= lamp._head_points()
	_check("both heads resolve", heads.size() == 2)
	if heads.size() == 2:
		for i in 2:
			var off: float = heads [i].distance_to(WorkLamp.FALLBACK_LAMPS [i])
			_check("head %d is where FALLBACK_LAMPS says (off by %.3f m)" % [i, off],
				off < 0.03)


		_check("...and they are at head height, %.2f m" % heads [0].y,
			heads [0].y > 1.7 and heads [0].y < 2.1)

	var bodies:= lamp.find_children("*", "StaticBody3D", true, false)
	_check("the model ships its colliders (%d of them)" % bodies.size(),
		bodies.size() >= 2)
	var wrong:= 0
	for n in bodies:
		if (n as StaticBody3D).collision_layer != Cfg.L_BUILD:
			wrong += 1
	_check("...all of them on L_BUILD, so the crosshair can reach the lamp",
		wrong == 0)
	_check("the crosshair resolves the lamp through its colliders",
		bodies.is_empty() or world.builds.owner_of(bodies [0]) == lamp)


	_check("the material table loads", not lamp.spec_table().is_empty())
	var surfaces: Dictionary = lamp.spec_table().get("surfaces", { })
	var flats: Dictionary = lamp.spec_table().get("flats", { })
	_check("...with the yellow in it", surfaces.has("M_LampYellow"))
	_check("...and the lit glass", flats.has("M_LampGlass")
		and float(flats ["M_LampGlass"].get("emit", 0.0)) > 0.0)
	await _clear_yard()


func _case_the_lights() -> void:
	print("\n=== three lights: two heads and the spill ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var spots:= _spots(lamp)
	var omnis:= _omnis(lamp)
	_check("two spots, one per head", spots.size() == 2)
	_check("one omni for the spill", omnis.size() == 1)
	if spots.size() != 2 or omnis.size() != 1:
		await _clear_yard()
		return

	for spot in spots:
		_check("a head reaches Cfg.WORK_LAMP_RANGE (%.0f m)" % spot.spot_range,
			absf(spot.spot_range - Cfg.WORK_LAMP_RANGE) < 0.01)


		_check("...over a flood's cone, %.0f degrees" % spot.spot_angle,
			spot.spot_angle >= 45.0)


		_check("...lit to Cfg.WORK_LAMP_ENERGY x the dial's default",
			absf(spot.light_energy
				- Cfg.WORK_LAMP_ENERGY * Cfg.WORK_LAMP_BRIGHT_DEFAULT) < 0.01)


	var apart:= spots [0].position.distance_to(spots [1].position)
	_check("the two heads are apart (%.2f m)" % apart, apart > 0.3)


	var culled:= 0
	for light in _lights(lamp):
		if light.distance_fade_enabled:
			culled += 1
	_check("every light has a distance cull on it (%d of 3)" % culled, culled == 3)
	_check("...and it fades rather than popping",
		spots [0].distance_fade_length > 1.0)
	_check("...past the range it lights, so a lamp never goes out in view",
		Cfg.WORK_LAMP_CULL > Cfg.WORK_LAMP_RANGE)
	await _clear_yard()


func _case_the_aim() -> void:
	print("\n=== the light goes where the glass looks ===")


	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var spots:= _spots(lamp)
	if spots.size() != 2:
		await _clear_yard()
		return


	for spot in spots:
		var beam:= - spot.global_transform.basis.z
		_check("a head shines the way the glass faces (dot %.3f)"
			% beam.dot(Vector3.BACK), beam.dot(Vector3.BACK) > 0.99)


	await _clear_yard()
	var turned:= await _stand(Vector3(LANE_X, 0.0, 0.0), PI * 0.5)
	var turned_spots:= _spots(turned)
	if turned_spots.size() == 2:
		var beam:= - turned_spots [0].global_transform.basis.z
		_check("turning the lamp turns the beam (dot %.3f with +X)"
			% beam.dot(Vector3.RIGHT), beam.dot(Vector3.RIGHT) > 0.99)
	await _clear_yard()


func _case_no_shadows() -> void:
	print("\n=== nothing on this lamp casts a shadow ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var casting:= 0
	for light in _lights(lamp):
		if light.shadow_enabled:
			casting += 1
	_check("no light on the lamp casts (%d do)" % casting, casting == 0)


	print("  (the sun's cascades were 6,120 draw calls against 1,977 without:")
	print("   see ShadowLod. A lit cone is another pass over everything in it.)")
	await _clear_yard()


func _case_the_dial() -> void:
	print("\n=== the dial ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)


	_check("a new lamp comes up at Cfg.WORK_LAMP_BRIGHT_DEFAULT (%.2f)"
		% lamp.brightness,
		absf(lamp.brightness - Cfg.WORK_LAMP_BRIGHT_DEFAULT) < 0.001)
	_check("...which is not flat out", Cfg.WORK_LAMP_BRIGHT_DEFAULT < 1.0)
	_check("...and whose panel reads Cfg.WORK_LAMP_LIT_DEFAULT (%.2f m)"
		% lamp.lit_metres(),
		absf(lamp.lit_metres() - Cfg.WORK_LAMP_LIT_DEFAULT) < 0.01)
	_check("...which is still above the bottom of the dial",
		Cfg.WORK_LAMP_BRIGHT_DEFAULT >= Cfg.WORK_LAMP_BRIGHT_MIN)

	lamp.set_brightness(1.0)
	var spots:= _spots(lamp)
	var omnis:= _omnis(lamp)
	if spots.size() != 2 or omnis.size() != 1:
		await _clear_yard()
		return
	_check("full turns the heads up to Cfg.WORK_LAMP_ENERGY",
		absf(spots [0].light_energy - Cfg.WORK_LAMP_ENERGY) < 0.01)
	_check("...and the spill to Cfg.WORK_LAMP_SPILL_ENERGY",
		absf(omnis [0].light_energy - Cfg.WORK_LAMP_SPILL_ENERGY) < 0.01)
	var bright_glass:= _glass_emit(lamp)

	lamp.set_brightness(0.25)
	_check("a quarter is a quarter of the light on both heads (%.2f)"
		% spots [0].light_energy,
		absf(spots [0].light_energy - Cfg.WORK_LAMP_ENERGY * 0.25) < 0.01
		and absf(spots [1].light_energy - Cfg.WORK_LAMP_ENERGY * 0.25) < 0.01)
	_check("...and a quarter of the spill",
		absf(omnis [0].light_energy - Cfg.WORK_LAMP_SPILL_ENERGY * 0.25) < 0.01)


	var dim_glass:= _glass_emit(lamp)
	_check("the glass dims with it (%.2f against %.2f)" % [dim_glass, bright_glass],
		dim_glass < bright_glass - 0.01)
	_check("...but does not go out, so it still reads as glass", dim_glass > 0.0)


	lamp.set_brightness(-3.0)
	_check("the dial will not go below Cfg.WORK_LAMP_BRIGHT_MIN (%.2f)"
		% lamp.brightness,
		absf(lamp.brightness - Cfg.WORK_LAMP_BRIGHT_MIN) < 0.001)
	_check("...which is not zero", Cfg.WORK_LAMP_BRIGHT_MIN > 0.0)
	lamp.set_brightness(9.0)
	_check("and not above full", absf(lamp.brightness - 1.0) < 0.001)


	_check("the battery reads Cfg.WORK_LAMP_CHARGE (%.0f%%)" % (lamp.charge() * 100.0),
		absf(lamp.charge() - Cfg.WORK_LAMP_CHARGE) < 0.001)
	_check("...which is full", absf(Cfg.WORK_LAMP_CHARGE - 1.0) < 0.001)
	var was:= lamp.charge()
	lamp.set_brightness(1.0)
	_check("...and the dial does not touch it", absf(lamp.charge() - was) < 0.001)


	lamp.set_brightness(1.0)
	_check("at full it lights Cfg.WORK_LAMP_RANGE (%.0f m)" % lamp.lit_metres(),
		absf(lamp.lit_metres() - Cfg.WORK_LAMP_RANGE) < 0.01)
	lamp.set_brightness(0.25)
	_check("at a quarter it lights half of it (%.0f m), not a quarter"
		% lamp.lit_metres(),
		absf(lamp.lit_metres() - Cfg.WORK_LAMP_RANGE * 0.5) < 0.01)


	var other:= await _stand(Vector3(LANE_X, 0.0, 4.0), 0.0)
	other.set_brightness(1.0)
	lamp.set_brightness(0.25)
	var shared:= HayCompressor.materials_shared()
	var worn: bool = not lamp._glass_meshes.is_empty() and not other._glass_meshes.is_empty()
	var mine:= lamp._meshes()
	var theirs:= other._meshes()
	worn = worn and mine.size() == theirs.size()
	if worn:
		for k in mine.size():
			var a:= mine [k]
			var b:= theirs [k]
			if a.mesh == null:
				continue
			for s in a.mesh.get_surface_count():
				var m:= a.get_surface_override_material(s)
				if m != null and (m == b.get_surface_override_material(s)) != shared:
					worn = false
	_check("a second lamp wears %s materials" % ("the same" if shared else "its own"), worn)
	_check("...and this lamp's dial is not on its glass (%.2f, other %.2f)"
		% [_glass_emit(lamp), _glass_emit(other)],
		_glass_emit(lamp) > 0.0 and _glass_emit(other) > _glass_emit(lamp) + 0.01)
	await _clear_yard()


func _case_the_switch() -> void:
	print("\n=== the red switch ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	lamp.set_brightness(0.8)
	_check("a new lamp is on", not lamp.is_switched_off())
	lamp.set_switched_off(true)
	var dark:= 0
	for light in _lights(lamp):
		if is_zero_approx(light.light_energy):
			dark += 1
	_check("switched off, every light is dark (%d of 3)" % dark, dark == 3)
	_check("...and the glass with them", is_zero_approx(_glass_emit(lamp)))
	_check("...and it says it lights nothing", is_zero_approx(lamp.lit_metres()))


	_check("...but the dial is still where it was (%.2f)" % lamp.brightness,
		absf(lamp.brightness - 0.8) < 0.001)
	lamp.set_switched_off(false)
	_check("switched back on it comes up at the same setting",
		absf(_spots(lamp) [0].light_energy - Cfg.WORK_LAMP_ENERGY * 0.8) < 0.01)
	await _clear_yard()


func _case_the_reach() -> void:
	print("\n=== walking up to it ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	var builds:= world.builds as BuildManager


	var eye:= lamp.console_position() + Vector3(1.4, 0.0, 0.0)
	_check("aimed at it, the crosshair resolves it",
		builds.lamp_under(eye, Vector3.LEFT) == lamp)


	_check("stood beside it looking away, it does not",
		builds.lamp_under(eye, Vector3.RIGHT) == null)
	var far:= lamp.console_position() + Vector3(
		Cfg.WORK_LAMP_CONSOLE_REACH * 2.5, 0.0, 0.0)
	_check("aimed at it from well back, it does not",
		builds.lamp_under(far, Vector3.LEFT) == null)

	_check("console_under hands it to the interact key",
		builds.console_under(eye, Vector3.LEFT) == lamp)
	_check("...and hands nothing over while looking away",
		builds.console_under(eye, Vector3.RIGHT) == null)
	await _clear_yard()


func _case_the_panel() -> void:
	print("\n=== the panel does not move the dial on the way in ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	lamp.set_brightness(0.42)
	var panel:= LampPanel.new()
	panel.player = player
	world.add_child(panel)
	await _settle()
	panel.open(lamp)
	await _settle()


	_check("opening the panel leaves the lamp where it was (%.2f)"
		% lamp.brightness, absf(lamp.brightness - 0.42) < 0.001)
	_check("...and the panel knows which lamp it is on", panel.lamp() == lamp)
	_check("...and is open", panel.is_open())
	panel.close()
	_check("closing lets go of the lamp", panel.lamp() == null)
	_check("...and the lamp is untouched", absf(lamp.brightness - 0.42) < 0.001)
	panel.queue_free()
	await _settle()
	await _clear_yard()


func _case_the_hologram() -> void:
	print("\n=== the hologram is dark ===")
	var ghost:= WorkLamp.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	await _settle()
	var lit:= 0
	for light in _lights(ghost):
		if light.visible:
			lit += 1
	_check("a preview lamp lights nothing (%d of its lights are on)" % lit,
		lit == 0)
	_check("...and it still has the lights, ready for when it is placed",
		_lights(ghost).size() == 3)
	var layered:= 0
	for n in ghost.find_children("*", "StaticBody3D", true, false):
		if (n as StaticBody3D).collision_layer != 0:
			layered += 1
	_check("...and nothing to walk into", layered == 0)
	ghost.queue_free()
	await _settle()


func _case_no_power() -> void:
	print("\n=== it works with the power out ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)


	_check("the yard has no generator", world.builds.generators.is_empty())
	_check("the yard has no pole", world.builds.power_poles.is_empty())
	var lit:= 0
	for light in _lights(lamp):
		if light.visible:
			lit += 1
	_check("the lamp is lit anyway (%d of 3)" % lit, lit == 3)


	_check("it draws nothing from the grid", not lamp.has_method("draw_kw"))
	_check("it is not on the machine fleet",
		not world.builds.grid.machines().has(lamp))
	await _clear_yard()


func _case_the_money() -> void:
	print("\n=== what it costs and what it gives back ===")
	var before:= GameState.money
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 0.0), 0.0)
	_check("it knows its own price ($%s)" % lamp.build_cost(),
		absf(lamp.build_cost() - Cfg.WORK_LAMP_COST) < 0.01)
	var back: float = world.builds.demolish(lamp)
	await _settle()
	_check("dismantling pays back what it cost (%.2f)" % back,
		absf(back - Cfg.WORK_LAMP_COST) < 0.01)
	_check("...and the lamp is gone", world.builds.work_lamps.is_empty())
	GameState.add_money(before - GameState.money)
	await _clear_yard()


func _case_the_card() -> void:
	print("\n=== the card promises what the yard delivers ===")
	_check("the catalogue has it", BuildCatalog.has_id("worklamp"))
	_check("...filed with the other furniture, in structure",
		BuildCatalog.category_of("worklamp") == "structure")
	_check("...placed by BuildTool.Mode.WORK_LAMP",
		BuildCatalog.mode_of("worklamp") == BuildTool.Mode.WORK_LAMP)
	_check("...one click, not a run", not BuildCatalog.is_run("worklamp"))
	_check("...behind a tech node", BuildCatalog.unlock_of("worklamp") == "work_lamp")
	_check("...which the tree actually has", TechTree.has_id("work_lamp"))
	_check("...behind the roof, which is what makes the dark",
		TechTree.requires("work_lamp").has("roof"))
	_check("...and the node sells it back",
		BuildCatalog.builds_for("work_lamp").has("worklamp"))
	var blurb:= BuildCatalog.blurb("worklamp")


	_check("the blurb quotes the reach it has (%d m)" % int(Cfg.WORK_LAMP_RANGE),
		blurb.contains("%d m" % int(Cfg.WORK_LAMP_RANGE)))
	_check("...and says outright that it needs no power",
		blurb.to_lower().contains("no power"))


	_check("...and that the battery never goes flat",
		blurb.to_lower().contains("never runs out"))
	_check("the cost line quotes Cfg.WORK_LAMP_COST",
		BuildCatalog.cost_text("worklamp") == "$%d" % int(Cfg.WORK_LAMP_COST))


func _case_a_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	var lamp:= await _stand(Vector3(LANE_X, 0.0, 4.0), 1.1)


	lamp.set_brightness(0.37)
	var d:= lamp.to_dict()
	_check("to_dict names the type", str(d.get("type", "")) == "work_lamp")
	for key: String in ["position", "yaw", "bright", "off"]:
		_check("to_dict carries %s" % key, d.has(key))
	var at:= lamp.global_position
	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	_check("the yard is empty after clear", world.builds.work_lamps.is_empty())
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()

	_check("one lamp came back", world.builds.work_lamps.size() == 1)
	if world.builds.work_lamps.is_empty():
		return
	var back: WorkLamp = world.builds.work_lamps [0]
	_check("...where it was (off by %.3f m)" % back.global_position.distance_to(at),
		back.global_position.distance_to(at) < 0.01)
	_check("...facing the way it faced (%.3f rad)" % back.global_rotation.y,
		absf(back.global_rotation.y - 1.1) < 0.01)


	_check("...with its three lights, all on", _lights(back).size() == 3
		and _lights(back).all(func(l: Light3D) -> bool: return l.visible))


	_check("...and the dial where they left it (%.2f)" % back.brightness,
		absf(back.brightness - 0.37) < 0.001)
	_check("...so the light is at that setting too",
		absf(_spots(back) [0].light_energy - Cfg.WORK_LAMP_ENERGY * 0.37) < 0.01)
	await _clear_yard()


func _stand(at: Vector3, yaw: float) -> WorkLamp:
	var lamp: WorkLamp = world.builds.add_work_lamp(at, yaw)
	await _settle()
	return lamp


func _lights(lamp: WorkLamp) -> Array [Light3D]:
	var out: Array [Light3D] = []
	for child in lamp.get_children():
		var light:= child as Light3D
		if light != null:
			out.append(light)
	return out


func _spots(lamp: WorkLamp) -> Array [SpotLight3D]:
	var out: Array [SpotLight3D] = []
	for light in _lights(lamp):
		if light is SpotLight3D:
			out.append(light as SpotLight3D)
	return out


func _glass_emit(lamp: WorkLamp) -> float:
	return lamp.glass_energy()


func _omnis(lamp: WorkLamp) -> Array [OmniLight3D]:
	var out: Array [OmniLight3D] = []
	for light in _lights(lamp):
		if light is OmniLight3D:
			out.append(light as OmniLight3D)
	return out


func _clear_yard() -> void:
	world.builds.clear()
	await _settle()


func _settle() -> void:
	for i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
