class_name DevBoreholeProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const REBUILD_FRAMES:= 8

const LANE_X:= 13.0


const RATE_TOLERANCE:= 0.15

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)


	Tech.grant("pump_output", 0)
	Tech.grant("generator_output", 0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _case_the_model()
	await _case_the_clip()
	await _case_on_the_wire()
	await _case_the_brownout()
	await _case_the_dial()
	await _case_the_switch()
	await _case_no_pole()
	await _case_the_money()
	await _case_the_card()
	await _case_the_stroke()
	await _case_a_save_round_trip()
	await _case_the_paint()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_model() -> void:
	print("\n=== the model ===")
	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	_check("the model loads", pump._model != null)
	for marker: String in [BoreholePump.N_WIRE_PORT, BoreholePump.N_WATER_OUT,
			BoreholePump.N_NEEDLE, BoreholePump.N_PANEL]:
		_check("the model ships %s" % marker, pump._find(marker) != null)


	var wire:= pump.to_local(pump.power_ports() [0].global_position)
	_check("the terminal is where WIRE_PORT_FALLBACK says (off by %.3f m)"
		% wire.distance_to(BoreholePump.WIRE_PORT_FALLBACK),
		wire.distance_to(BoreholePump.WIRE_PORT_FALLBACK) < 0.02)
	var flange:= pump.to_local(pump.water_port())
	_check("the delivery flange is where WATER_OUT_FALLBACK says (off by %.3f m)"
		% flange.distance_to(BoreholePump.WATER_OUT_FALLBACK),
		flange.distance_to(BoreholePump.WATER_OUT_FALLBACK) < 0.02)


	_check("...at a run's own height, %.3f m against the pipe's 0.430" % flange.y,
		absf(flange.y - 0.43) < 0.02)

	var bodies:= pump.find_children("*", "StaticBody3D", true, false)
	_check("the model ships its colliders (%d of them)" % bodies.size(),
		bodies.size() >= 8)
	var wrong:= 0
	for n in bodies:
		if (n as StaticBody3D).collision_layer != Cfg.L_BUILD:
			wrong += 1
	_check("...all of them on L_BUILD, so the crosshair can reach the machine",
		wrong == 0)


	var movers:= ["Pump_Beam", "Pump_Crank", "Pump_Pitman", "Pump_Rod",
		"Pump_Pulley", "Pump_Needle"]
	var mounted:= ""
	for n in bodies:
		var walk: Node = n
		while walk != null and walk != pump:
			if movers.has(str(walk.name)):
				mounted = "%s under %s" % [n.name, walk.name]
				break
			walk = walk.get_parent()
	_check("no collider is bolted to a moving part%s"
		% ("" if mounted == "" else ", but %s is" % mounted), mounted == "")

	_check("the crosshair resolves the machine through its colliders",
		bodies.is_empty() or world.builds.owner_of(bodies [0]) == pump)
	await _clear_yard()


func _case_the_clip() -> void:
	print("\n=== the clip is one stroke, and the game owns the rate ===")
	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	_check("the model ships an AnimationPlayer", pump._anim != null)
	var name:= pump._clip_name()
	_check("...with a %s clip on it" % BoreholePump.CLIP, name != "")
	if name == "":
		await _clear_yard()
		return
	var clip:= pump._anim.get_animation(name)
	_check("it loops", clip.loop_mode == Animation.LOOP_LINEAR)
	_check("it is playing", pump._anim.is_playing())


	var seconds:= pump.clip_seconds()
	var wanted:= 60.0 / Cfg.BOREHOLE_STROKES_PER_MIN
	_check("it is one stroke long: %.2f s against the %.2f s "
		% [seconds, wanted] + "Cfg.BOREHOLE_STROKES_PER_MIN implies",
		absf(seconds - wanted) < 0.35)


	var keyed:= 0
	for i in clip.get_track_count():
		if str(clip.track_get_path(i)).contains(BoreholePump.N_NEEDLE):
			keyed += 1
	_check("no track keys the pressure needle", keyed == 0)


	pump.set_power(1.0)
	var scale:= pump._anim.speed_scale
	_check("at full power the clip plays at %.3f, which is %.1f strokes a minute"
		% [scale, scale / seconds * 60.0],
		absf(scale / seconds * 60.0 - Cfg.BOREHOLE_STROKES_PER_MIN) < 0.3)
	await _clear_yard()


func _case_on_the_wire() -> void:
	print("\n=== on the wire ===")
	var gen:= await _generator_at(-6.0)
	var pole:= await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var pump:= await _sink(Vector3(LANE_X, 0.0, 4.0))
	await _settle()
	var grid: PowerGrid = world.builds.grid

	_check("the pump is on the generator's network", grid.network_of(pump) >= 0)
	_check("...through a wire off the pole", grid.pole_for(pump) == pole)
	_check("...landing on its own terminal",
		grid.port_for(pump) == pump.power_ports() [0])
	var got: Dictionary = grid.report(pump)


	_check("it draws %.1f kW and the network says so (%.2f)"
		% [Cfg.BOREHOLE_DRAW_KW, got ["demand"]],
		absf(float(got ["demand"]) - Cfg.BOREHOLE_DRAW_KW) < 0.2)
	_check("...and the network is satisfied (%.2f)" % got ["satisfaction"],
		float(got ["satisfaction"]) > 0.99)
	_check("a satisfied pump runs at full power", pump.power > 0.99)
	_check("...and delivers its rated %.1f litres a second (%.2f)"
		% [Tech.borehole_output(), pump.water_lps()],
		absf(pump.water_lps() - Tech.borehole_output()) < 0.05)
	_check("...nodding %.0f times a minute" % pump.strokes_per_minute(),
		absf(pump.strokes_per_minute() - Cfg.BOREHOLE_STROKES_PER_MIN) < 0.1)
	_check("a working pump raises no sign", pump.alert_reason() == "")
	_check("the machine watch has the pump on its fleet",
		world.builds.watch._fleet().has(pump))


	_check("a pump with no Gas Plant on its pipes is not exempt",
		not world.builds.grid.is_feeder(pump))
	_check("the generator is burning for it (%.2f kW)" % gen.output_kw(),
		gen.output_kw() > 0.0)
	await _clear_yard()


func _case_the_brownout() -> void:
	print("\n=== one brownout, felt twice ===")


	var gen:= await _generator_at(-6.0)
	await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var pump:= await _sink(Vector3(LANE_X, 0.0, 4.0))
	world.builds.add_piston_rake(Vector3(LANE_X + 4.0, 0.0, 2.0), 0.0)
	await _settle()
	await _settle()
	var grid: PowerGrid = world.builds.grid
	var got: Dictionary = grid.report(pump)
	var f:= float(got ["satisfaction"])
	_check("the yard wants %.1f kW and makes %.1f, so it runs at %d%%"
		% [got ["demand"], got ["supply"], int(round(f * 100.0))], f < 0.9 and f > 0.4)
	_check("the pump is browned out with everything else (%.2f)" % pump.power,
		absf(pump.power - f) < 0.02)


	var strokes:= pump.strokes_per_minute()
	var litres:= pump.water_lps()
	_check("the beam slows to %.1f strokes a minute" % strokes,
		absf(strokes - Cfg.BOREHOLE_STROKES_PER_MIN * f) < RATE_TOLERANCE)
	_check("...and the well gives %.1f litres a second" % litres,
		absf(litres - Tech.borehole_output() * f) < RATE_TOLERANCE)


	var per_stroke_full:= Tech.borehole_output() * 60.0 / Cfg.BOREHOLE_STROKES_PER_MIN
	var per_stroke_now:= litres * 60.0 / maxf(strokes, 0.001)
	_check("litres a stroke does not move: %.1f browned out against %.1f full"
		% [per_stroke_now, per_stroke_full],
		absf(per_stroke_now - per_stroke_full) < 1.0)


	gen.fuel = 0.0
	await _settle()
	await _settle()
	_check("a yard with no fire gives the pump nothing (%.2f)" % pump.power,
		pump.power < 0.01)
	_check("...so the beam stands still", pump.strokes_per_minute() < 0.01)
	_check("...and the well delivers nothing", pump.water_lps() < 0.01)
	await _clear_yard()


func _case_the_stroke() -> void:
	print("\n=== the stroke is a cue, not a bed ===")
	_check("the yard knows the cue", Audio.SFX_LIB.has("pump_stroke"))
	for path: String in Audio.SFX_LIB.get("pump_stroke", []):
		_check("...%s is on disk" % path.get_file(), ResourceLoader.exists(path))

	var gen:= await _generator_at(-6.0)
	await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	await _settle()
	await _settle()
	_check("the pump is on a healthy line (%.2f)" % pump.power, pump.power > 0.95)


	var heard:= await _knocks_over(1.4)
	_check("a nodding pump knocks (%d in one stroke and a bit)" % heard, heard >= 1)


	pump.set_switched_off(true)
	await _settle()
	var quiet:= await _knocks_over(1.4)
	_check("a switched-off pump is silent (%d knocks)" % quiet, quiet == 0)

	pump.set_switched_off(false)
	await _settle()
	var back:= await _knocks_over(1.4)
	_check("...and it comes back when the switch does (%d knocks)" % back, back >= 1)


	var full:= await _knocks_over(4.0)
	pump.set_power(0.5)
	await _settle()
	var half:= await _knocks_over(4.0)
	_check("%d knocks over four strokes at full, %d at half" % [full, half],
		full >= 3 and half < full)
	await _clear_yard()


func _knocks_over(strokes: float) -> int:
	var left:= strokes * 60.0 / Cfg.BOREHOLE_STROKES_PER_MIN
	var last: int = Audio._last_play.get("pump_stroke", -1000000)
	var heard:= 0
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		var now: int = Audio._last_play.get("pump_stroke", -1000000)
		if now != last:
			heard += 1
			last = now
	return heard


func _case_the_dial() -> void:
	print("\n=== the pressure dial ===")


	_check("an empty network points the needle to the bottom of the sweep (%.1f deg)"
		% BoreholePump.needle_angle(0.0),
		is_equal_approx(BoreholePump.needle_angle(0.0),
			- BoreholePump.GAUGE_SWEEP / 2.0))
	_check("a satisfied one points it to the top (%.1f deg)"
		% BoreholePump.needle_angle(1.0),
		is_equal_approx(BoreholePump.needle_angle(1.0),
			BoreholePump.GAUGE_SWEEP / 2.0))
	_check("...and half way is straight up, which is the pose it is modelled in",
		is_equal_approx(BoreholePump.needle_angle(0.5), 0.0))
	_check("the sweep is the one the model was drawn at",
		is_equal_approx(BoreholePump.GAUGE_SWEEP, 250.0))

	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	var rest: Basis = pump._needle.transform.basis
	pump.set_power(1.0)
	pump._apply_gauge(0.0)
	var high: Basis = pump._needle.transform.basis
	pump.set_power(0.0)
	pump._apply_gauge(0.0)
	var low: Basis = pump._needle.transform.basis
	_check("the needle actually turns between the two ends of the sweep",
		not high.is_equal_approx(low))
	_check("...and it started in the middle, not at an end",
		not rest.is_equal_approx(high) and not rest.is_equal_approx(low))


	pump.set_power(0.5)
	pump._apply_gauge(0.0)
	var mid: Basis = pump._needle.transform.basis
	pump.set_power(0.6)
	pump._apply_gauge(0.0)
	var stepped: Basis = pump._needle.transform.basis
	var swung:= (stepped * mid.inverse()).get_euler()
	var wanted:= BoreholePump.needle_angle(0.6) - BoreholePump.needle_angle(0.5)
	_check("a tenth more satisfaction swings it %.1f deg about +X, and %.1f is "
		% [rad_to_deg(swung.x), wanted] + "what needle_angle asks for",
		absf(rad_to_deg(swung.x) - wanted) < 0.5)
	_check("...with nothing about the other two axes (%.2f, %.2f deg)"
		% [rad_to_deg(swung.y), rad_to_deg(swung.z)],
		absf(rad_to_deg(swung.y)) < 0.5 and absf(rad_to_deg(swung.z)) < 0.5)
	await _clear_yard()


func _case_the_switch() -> void:
	print("\n=== the switch ===")
	await _generator_at(-6.0)
	await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var pump:= await _sink(Vector3(LANE_X, 0.0, 4.0))
	await _settle()
	var grid: PowerGrid = world.builds.grid

	pump.set_switched_off(true)
	await _settle()
	await _settle()
	_check("a switched-off pump draws nothing", is_zero_approx(pump.draw_kw()))
	_check("...and leaves the budget at once (%.2f kW demanded)"
		% grid.report(pump) ["demand"],
		float(grid.report(pump) ["demand"]) < 0.1)
	_check("...delivers no water", is_zero_approx(pump.water_lps()))
	_check("...stands still", is_zero_approx(pump.strokes_per_minute()))
	_check("...and raises NO sign, because off is a decision and not a fault",
		pump.alert_reason() == "")


	_check("...but the dial still reads the network (%.2f)" % pump._gauge,
		pump._gauge > 0.99)

	pump.set_switched_off(false)
	await _settle()
	await _settle()
	_check("switching it back on restores it without waiting for a push",
		pump.power > 0.99 and pump.water_lps() > 0.0)
	_check("the panel knows what to call it",
		MachinePanel._name_of(pump) == BuildCatalog.display_name("borehole").to_upper())
	await _clear_yard()


func _case_no_pole() -> void:
	print("\n=== a pump nobody wired ===")
	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	await _settle()
	await _settle()
	_check("a pump on no network gets nothing", pump.power < 0.01)
	_check("...so it stands still", is_zero_approx(pump.strokes_per_minute()))
	_check("...and delivers nothing", is_zero_approx(pump.water_lps()))
	var reason:= pump.alert_reason()
	_check("...and says why: %s" % reason, reason.begins_with("NO POWER"))
	_check("...under the bolt and not the bang", pump.alert_icon() == "power")


	pump.set_power_blocked(true)
	_check("a blocked cable is named as one, not as a missing pole",
		pump.alert_reason().begins_with("NO CABLE REACHES THIS"))
	pump.set_power_blocked(false)
	await _clear_yard()


func _case_the_money() -> void:
	print("\n=== the money ===")
	var before:= GameState.money
	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	_check("a well costs $%d" % int(Cfg.BOREHOLE_COST),
		is_equal_approx(pump.build_cost(), Cfg.BOREHOLE_COST))


	var second:= await _sink(Vector3(LANE_X, 0.0, 8.0))
	_check("...and so does the next one, because the price does not climb",
		is_equal_approx(second.build_cost(), Cfg.BOREHOLE_COST))
	_check("the catalogue quotes the same price",
		str(BuildCatalog.spec("borehole").get("cost", "")).contains(
			str(int(Cfg.BOREHOLE_COST))))
	_check("...and files it under Water",
		str(BuildCatalog.spec("borehole").get("category", "")) == "water")
	_check("...behind the borehole node",
		BuildCatalog.unlock_of("borehole") == "borehole")

	GameState.add_money(- GameState.money + before)
	var paid:= GameState.money
	world.builds._demolish(pump)
	await _settle()
	_check("taking one down pays back exactly what it cost",
		is_equal_approx(GameState.money - paid, Cfg.BOREHOLE_COST)
			or GameState.money == paid)
	await _clear_yard()


func _case_the_card() -> void:
	print("\n=== the card does not lie ===")
	_check("the base output is the one Cfg names (%.1f litres/s)"
		% Tech.borehole_output(),
		is_equal_approx(Tech.borehole_output(), Cfg.BOREHOLE_OUTPUT_LPS))
	var values: Array = TechTree.spec("pump_output").get("values", [])
	_check("the rank card lists %d ranks" % values.size(),
		values.size() == Tech.PUMP_OUTPUT_RANKS.size())
	var wrong:= ""
	for r in range(1, values.size() + 1):
		Tech.grant("pump_output", r)
		var promised:= float(str(values [r - 1]))
		if not is_equal_approx(Tech.borehole_output(), promised):
			wrong = "rank %d promises %.1f and delivers %.1f" % [
				r, promised, Tech.borehole_output()]
			break
	_check("every rank delivers what its card promises%s"
		% ("" if wrong == "" else ", but %s" % wrong), wrong == "")


	Tech.grant("pump_output", Tech.PUMP_OUTPUT_RANKS.size())
	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	pump.set_power(1.0)
	_check("a fully ranked pump still nods %.0f times a minute"
		% pump.strokes_per_minute(),
		absf(pump.strokes_per_minute() - Cfg.BOREHOLE_STROKES_PER_MIN) < 0.1)
	_check("...and still draws %.1f kW" % pump.draw_kw(),
		is_equal_approx(pump.draw_kw(), Cfg.BOREHOLE_DRAW_KW))
	_check("...but delivers %.1f litres a second" % pump.water_lps(),
		pump.water_lps() > Cfg.BOREHOLE_OUTPUT_LPS)
	Tech.grant("pump_output", 0)
	await _clear_yard()


func _case_a_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	await _generator_at(-6.0)
	await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0))
	var pump:= await _sink(Vector3(LANE_X, 0.0, 4.0))
	pump.rotation.y = 1.1
	pump.set_switched_off(true)
	await _settle()

	var d:= pump.to_dict()
	_check("to_dict names the type", str(d.get("type", "")) == "borehole_pump")
	for key: String in ["position", "yaw", "off"]:
		_check("to_dict carries %s" % key, d.has(key))
	var at:= pump.global_position
	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	_check("the yard is empty after clear", world.builds.boreholes.is_empty())
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()

	_check("one pump came back", world.builds.boreholes.size() == 1)
	var back: BoreholePump = world.builds.boreholes [0]
	_check("...where it was (off by %.3f m)" % back.global_position.distance_to(at),
		back.global_position.distance_to(at) < 0.01)
	_check("...facing the way it faced (%.3f rad)" % back.global_rotation.y,
		absf(back.global_rotation.y - 1.1) < 0.01)


	_check("...still switched off", back.is_switched_off())
	_check("...and still drawing nothing", is_zero_approx(back.draw_kw()))
	back.set_switched_off(false)
	await _settle()
	await _settle()
	_check("switched back on it rejoins the network",
		world.builds.grid.network_of(back) >= 0 and back.power > 0.99)
	await _clear_yard()


func _sink(at: Vector3) -> BoreholePump:
	var pump: BoreholePump = world.builds.add_borehole(at, 0.0)
	await _settle()
	return pump


func _generator_at(z: float) -> HayGenerator:
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, z), 0.0)
	gen.fuel = gen.capacity()
	await _settle()
	return gen


func _plant(at: Vector3) -> PowerPole:
	var pole: PowerPole = world.builds.add_power_pole(at, 0.0)
	await _settle()
	return pole


func _clear_yard() -> void:
	world.builds.clear()
	await _settle()


func _settle() -> void:
	for i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _case_the_paint() -> void:
	print("\n=== the paint stays under the bloom ===")
	var env:= (world.env_node as WorldEnvironment).environment
	var sun:= world.sun as DirectionalLight3D
	var lit: float = sun.light_energy * env.tonemap_exposure
	var ceiling: float = env.glow_hdr_threshold * 0.8
	_check("the yard's own numbers came back (sun %.2f, exposure %.2f, threshold %.2f)"
		% [sun.light_energy, env.tonemap_exposure, env.glow_hdr_threshold],
		lit > 0.1 and env.glow_hdr_threshold > 0.1)

	var spec: Dictionary = BoreholePump.spec_table()
	var surfaces: Dictionary = spec.get("surfaces", { })


	var pump:= await _sink(Vector3(LANE_X, 0.0, 0.0))
	var worn: Array [String] = []
	for mesh in pump._meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null or src.resource_name.is_empty():
				continue
			if src.get_meta("immutable_palette", false):
				for key: String in src.get_meta("palette_entries", []):
					if not worn.has(key):
						worn.append(key)
				continue
			if not worn.has(src.resource_name):
				worn.append(src.resource_name)
	worn.sort()
	_check("the machine wears %d materials" % worn.size(), worn.size() >= 20)


	var flats: Dictionary = spec.get("flats", { })
	var orphans: Array [String] = []
	for key: String in worn:
		if not surfaces.has(key) and not flats.has(key):
			orphans.append(key)
	_check("every one of them has a table entry%s"
		% ("" if orphans.is_empty() else ", but %s has none" % ", ".join(orphans)),
		orphans.is_empty())

	for key: String in worn:
		if not surfaces.has(key):
			continue
		var d: Dictionary = surfaces [key]
		var base:= _base_colour(d)
		var hot: float = maxf(base.x, maxf(base.y, base.z)) * lit
		_check("%s renders at %.2f in full sun, under %.2f (albedo %.3f, %.3f, %.3f)"
			% [key, hot, ceiling, base.x, base.y, base.z], hot < ceiling)
	await _clear_yard()


func _base_colour(d: Dictionary) -> Vector3:
	var mean:= _scan_mean(str(d ["asset"]))
	var lum:= mean.dot(Vector3(0.2126, 0.7152, 0.0722))
	var sat:= float(d.get("sat", 1.0))
	var flat:= Vector3(lum, lum, lum).lerp(mean, sat)
	var ao:= float(d.get("ao", 0.0))
	var tint: Array = d ["tint"]
	var k:= (1.0 - ao * 0.2)
	return Vector3(flat.x * k * float(tint [0]), flat.y * k * float(tint [1]),
		flat.z * k * float(tint [2]))


static var _scan_cache: Dictionary = { }


func _scan_mean(asset: String) -> Vector3:
	if _scan_cache.has(asset):
		return _scan_cache [asset]
	var path: String = HayCompressor.TEX % [asset, asset, "diff"]
	var tex: Texture2D = load(path)
	if tex == null:
		push_error("--borehole: no albedo for %s at %s" % [asset, path])
		return Vector3.ONE
	var img:= tex.get_image()
	if img.is_compressed():
		img.decompress()


	var total:= Vector3.ZERO
	var n:= 0
	var x:= 0
	while x < img.get_width():
		var y:= 0
		while y < img.get_height():
			var c:= img.get_pixel(x, y)


			var l:= c.srgb_to_linear()
			total += Vector3(l.r, l.g, l.b)
			n += 1
			y += 16
		x += 16
	var mean:= total / maxf(float(n), 1.0)
	_scan_cache [asset] = mean
	return mean


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
