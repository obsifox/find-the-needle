class_name DevLauncherProbe
extends Node


var world: Node3D
var player: Player


const AT:= Vector3(6.0, 0.0, 6.0)


const MIN_RANGE:= 1.0


const ARC_TOL:= 0.001

var _pass:= 0
var _fail:= 0


func run() -> void:
	await get_tree().process_frame

	var builds: BuildManager = world.builds
	_check("the world has a build manager", builds != null)
	if builds == null:
		_finish()
		return


	var gun:= builds.add_tube_launcher(AT, 0.0)
	_check("BuildManager places a launcher", gun != null)
	if gun == null:
		_finish()
		return
	await get_tree().process_frame
	await get_tree().physics_frame


	var model:= gun.get_node_or_null("Model")
	_check("the model loads out of tube_launcher.glb", model != null)
	for node_name: String in [TubeLauncher.N_TILT, TubeLauncher.N_MUZZLE,
			TubeLauncher.N_BORE, TubeLauncher.N_BELT_IN, TubeLauncher.N_PANEL,
			"Ram_L", "Ram_R", "Ram_L_Rod", "Ram_R_Rod",
			"Marker_ClevisL", "Marker_ClevisR"]:
		_check("the model has %s" % node_name,
			model != null and model.find_child(node_name, true, false) != null)

	var spec:= TubeLauncher.spec_table()
	var surfaces: Dictionary = spec.get("surfaces", { })
	var flats: Dictionary = spec.get("flats", { })
	_check("the material table loads", not surfaces.is_empty())
	_check("the table has the frame steel", surfaces.has("M_TL_Frame"))
	_check("the table has the power lamp", flats.has(TubeLauncher.LAMP_MAT))


	var twin:= builds.add_tube_launcher(AT + Vector3(8.0, 0.0, 0.0), 0.0)
	_check("a second launcher places beside the first", twin != null)
	if twin != null:
		await get_tree().process_frame
		var shared:= HayCompressor.materials_shared()
		var ours: Array [MeshInstance3D] = gun._meshes()
		var theirs: Array [MeshInstance3D] = twin._meshes()
		var pairs:= 0
		var wrong: Array [String] = []
		for k in mini(ours.size(), theirs.size()):
			var a:= ours [k]
			var b:= theirs [k]
			if a.mesh == null or a.name != b.name:
				continue
			for s in a.mesh.get_surface_count():
				var mine:= a.get_surface_override_material(s)
				if mine == null:
					continue
				pairs += 1
				if (mine == b.get_surface_override_material(s)) != shared:
					wrong.append("%s/%d" % [a.name, s])
		_check("the two wear %s materials (%d surfaces, wrong: %s)"
			% ["the same" if shared else "their own", pairs,
				"none" if wrong.is_empty() else ", ".join(wrong)],
			pairs > 0 and ours.size() == theirs.size() and wrong.is_empty())
		_check("each has %d power segments of its own (%d, %d)"
			% [TubeLauncher.N_LAMPS, gun.lamp_energies().size(), twin.lamp_energies().size()],
			gun.lamp_energies().size() == TubeLauncher.N_LAMPS
				and twin.lamp_energies().size() == TubeLauncher.N_LAMPS)
		var was:= gun.power
		gun.power = 1.0
		twin.power = 0.0
		var full:= gun.lamp_energies()
		var dark:= twin.lamp_energies()
		var lit_ok:= true
		for e in full:
			lit_ok = lit_ok and is_equal_approx(e, TubeLauncher.LAMP_LIT)
		var dark_ok:= true
		for i in dark.size():

			dark_ok = dark_ok and is_equal_approx(dark [i], TubeLauncher.LAMP_DARK)
		_check("full power lights all five of its segments (%s)" % str(full), lit_ok)
		_check("...and not one of the other launcher's (%s)" % str(dark), dark_ok)
		gun.power = 0.4
		var part:= gun.lamp_energies()
		_check("power 0.4 lights the first two segments and no more (%s)" % str(part),
			part.size() == TubeLauncher.N_LAMPS
				and is_equal_approx(part [0], TubeLauncher.LAMP_LIT)
				and is_equal_approx(part [1], TubeLauncher.LAMP_LIT)
				and is_equal_approx(part [2], TubeLauncher.LAMP_DARK)
				and is_equal_approx(twin.lamp_energies() [0], TubeLauncher.LAMP_DARK))
		gun.power = was
		builds.demolish(twin)
		await get_tree().process_frame


	var port:= gun.intake_port()
	_check("the intake port is %.2f m up" % TubeLauncher.PORT_UP,
		absf(port.y - (AT.y + TubeLauncher.PORT_UP)) < 0.02)
	_check("the intake port is the stub's length out in front of the throat",
		absf(port.distance_to(gun.port_in()) - gun.stub()) < 0.02)
	_check("the machine lays its own stub of deck", gun.deck() != null)


	var authored:= gun.to_local(gun.port_in()).z
	_check("PORT_BACK (%.2f) matches the model's own marker (%.2f)"
		% [TubeLauncher.PORT_BACK, - authored],
		absf(- authored - TubeLauncher.PORT_BACK) < 0.01)


	await get_tree().physics_frame
	await get_tree().physics_frame
	var supports:= gun.get_node_or_null("StubSupports")
	_check("the stub grows a trestle", supports != null)
	if supports != null:
		var legs:= supports.get_node_or_null("Legs") as MultiMeshInstance3D
		var feet:= supports.get_node_or_null("Feet") as MultiMeshInstance3D
		_check("...with two posts",
			legs != null and legs.multimesh != null and legs.multimesh.instance_count == 2)
		_check("...and a foot under each",
			feet != null and feet.multimesh != null and feet.multimesh.instance_count == 2)


		_check("...built from the conveyor kit's own leg",
			legs != null and legs.multimesh != null
				and legs.multimesh.mesh == ConveyorKit.leg_mesh())


	var player_node:= gun.get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	if player_node == null and model != null:
		player_node = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the model ships an AnimationPlayer", player_node != null)
	if player_node != null:
		var clips:= player_node.get_animation_list()
		_check("it ships exactly one clip (%d)" % clips.size(), clips.size() == 1)
		var clip:= player_node.get_animation(clips [0]) if clips.size() > 0 else null
		_check("the clip is named Aim (%s)" % (clips [0] if clips.size() > 0 else "-"),
			clips.size() > 0 and String(clips [0]).ends_with(TubeLauncher.CLIP))
		if clip != null:
			_check("the clip has real length (%.2f s)" % clip.length, clip.length > 0.5)
			_check("the clip does not loop", clip.loop_mode == Animation.LOOP_NONE)


			var moved:= { }
			for i in clip.get_track_count():
				moved [String(clip.track_get_path(i)).get_file()] = true
			for part: String in ["Tilt", "Ram_L", "Ram_R", "Ram_L_Rod", "Ram_R_Rod"]:
				_check("the clip drives %s" % part, moved.has(part))


	await _settle(gun)
	_check("a fresh launcher rests aimed up (%.0f deg)" % gun.tilt_now(),
		gun.tilt_now() > 25.0)
	_check("...and its muzzle is above its own trunnion",
		gun.muzzle_position().y > AT.y + 1.6)


	gun.aim = 0.0
	await _settle(gun)
	var low_muzzle:= gun.muzzle_position().y
	var low_dir:= gun.bore_direction()
	gun.aim = 1.0
	await _settle(gun)
	var high_muzzle:= gun.muzzle_position().y
	var high_dir:= gun.bore_direction()
	_check("more angle raises the muzzle (%.2f m -> %.2f m)"
		% [low_muzzle, high_muzzle], high_muzzle > low_muzzle + 0.1)
	_check("more angle points the bore further UP (%.2f -> %.2f)"
		% [low_dir.y, high_dir.y], high_dir.y > low_dir.y + 0.1)


	_check("the bottom of the clip matches Cfg.LAUNCHER_TILT_MIN (%.1f deg)"
		% rad_to_deg(asin(clampf(low_dir.y, -1.0, 1.0))),
		absf(low_dir.y - sin(deg_to_rad(Cfg.LAUNCHER_TILT_MIN))) < 0.05)
	_check("the top of the clip matches Cfg.LAUNCHER_TILT_MAX (%.1f deg)"
		% rad_to_deg(asin(clampf(high_dir.y, -1.0, 1.0))),
		absf(high_dir.y - sin(deg_to_rad(Cfg.LAUNCHER_TILT_MAX))) < 0.05)


	var flat:= Vector3(high_dir.x, 0.0, high_dir.z).normalized()
	_check("the bore throws the way the hay was already travelling",
		flat.dot(gun.global_basis.z) > 0.99)
	_check("...which is the machine's own forward", flat.dot(gun.forward()) > 0.99)


	gun.aim = Cfg.LAUNCHER_AIM_DEFAULT
	gun.power = 0.2
	await _settle(gun)
	var tilt_low_power:= gun.tilt_now()
	var speed_low:= gun.launch_velocity().length()
	gun.power = 0.9
	await _settle(gun)
	_check("power leaves the tube where it was (%.1f deg -> %.1f deg)"
		% [tilt_low_power, gun.tilt_now()],
		absf(gun.tilt_now() - tilt_low_power) < 0.05)
	_check("...and does change the muzzle speed (%.1f -> %.1f m/s)"
		% [speed_low, gun.launch_velocity().length()],
		gun.launch_velocity().length() > speed_low + 1.0)
	var speed_held:= gun.launch_velocity().length()
	gun.aim = 0.15
	await _settle(gun)
	_check("angle leaves the muzzle speed alone (%.1f m/s)" % speed_held,
		absf(gun.launch_velocity().length() - speed_held) < 0.01)
	_check("...and does move the tube (%.1f deg)" % gun.tilt_now(),
		absf(gun.tilt_now() - tilt_low_power) > 5.0)


	gun.aim = 0.1
	await _settle(gun)


	await _rest(gun)
	var free_at_rest:= Audio.loops_available()
	gun.aim = 0.95
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("the tube holds a voice while it is winding (%d free, was %d)"
		% [Audio.loops_available(), free_at_rest],
		Audio.loops_available() == free_at_rest - 1)
	await _settle(gun)
	await _rest(gun)
	_check("...and gives it back when it gets there",
		Audio.loops_available() == free_at_rest)


	gun.aim = Cfg.LAUNCHER_AIM_DEFAULT
	var last:= -1.0
	var monotonic:= true
	var reached:= 0.0
	for i in 11:
		gun.power = float(i) / 10.0
		await _settle(gun)
		var r:= gun.range_metres()
		if r < last - 0.01:
			monotonic = false
		last = r
		reached = r
		if i == 0:
			_check("it throws clear of itself at zero power (%.2f m)" % r,
				r > MIN_RANGE)
	_check("range climbs the whole length of the power slider", monotonic)
	_check("full power throws further than half", reached > 6.0)


	gun.aim = 0.25
	gun.power = 1.0
	await _settle(gun)
	var flat_range:= gun.range_metres()
	var flat_peak:= _arc_peak(gun)
	var steep_found:= false
	var steep_peak:= 0.0


	gun.aim = 1.0
	var lo:= 0.0
	var hi:= 1.0
	for i in 24:
		gun.power = (lo + hi) * 0.5
		await _settle(gun)
		var r:= gun.range_metres()
		if absf(r - flat_range) < 0.35:
			steep_found = true
			steep_peak = _arc_peak(gun)
			break
		if r < flat_range:
			lo = gun.power
		else:
			hi = gun.power
	_check("a steep setting can reach the same %.1f m as a shallow one"
		% flat_range, steep_found)
	_check("...and gets there over a higher arc (%.2f m against %.2f m)"
		% [steep_peak, flat_peak], steep_found and steep_peak > flat_peak + 0.5)


	gun.aim = Cfg.LAUNCHER_AIM_DEFAULT
	gun.power = 0.62
	await _settle(gun)
	var drawn:= LaunchArc.sample(gun.muzzle_position(), gun.launch_velocity(),
		gun.global_position.y, true)
	var land: Vector3 = drawn [drawn.size() - 1]
	_check("the drawn arc lands where the machine says it will",
		land.distance_to(gun.landing_spot()) < ARC_TOL)
	_check("the drawn arc ends on the ground",
		absf(land.y - gun.global_position.y) < ARC_TOL)
	_check("the drawn arc starts at the muzzle",
		(drawn [0] as Vector3).distance_to(gun.muzzle_position()) < ARC_TOL)

	var peak:= 0.0
	for p: Vector3 in drawn:
		peak = maxf(peak, p.y)
	_check("the arc rises above the muzzle before it lands",
		peak > gun.muzzle_position().y + 0.2)


	var aim:= gun.throw_aim()
	_check("a placed launcher carries an arrow", aim != null)
	if aim != null:
		_check("...which is down until somebody asks", aim.mode() == ThrowAim.OFF)
		gun.show_arc(true)
		for _f in 3:
			await get_tree().process_frame
		_check("opening the panel turns it orange with its arc",
			aim.mode() == ThrowAim.PANEL and aim.arc_drawn())


		var off:= INF
		for i in drawn.size() - 1:
			var a: Vector3 = drawn [i]
			var b: Vector3 = drawn [i + 1]
			off = minf(off, aim.landing().distance_to(
				Geometry3D.get_closest_point_to_segment(aim.landing(), a, b)))
		print("  arrow at %s, %.1f m out; flat landing %.1f m out" % [aim.landing(),
			Vector2(aim.landing().x - AT.x, aim.landing().z - AT.z).length(),
			Vector2(gun.landing_spot().x - AT.x, gun.landing_spot().z - AT.z).length()])
		_check("...hanging on the machine's own flight (%.2f m off it)" % off,
			off < 0.3)
		gun.show_arc(false)
		_check("closing it takes it down", aim.mode() == ThrowAim.OFF)
		gun.pin_range(0.4)
		_check("the show range button keeps it up with the panel shut",
			aim.mode() == ThrowAim.PANEL)
		await get_tree().create_timer(0.8).timeout
		_check("...until its time runs out", aim.mode() == ThrowAim.OFF)


	var props: PropManager = world.props
	var before:= props.items.size()
	gun.stored = Cfg.LAUNCHER_WAD_STRANDS
	var thrown: Array [Carryable] = []
	gun.launched.connect(func(item: Carryable) -> void: thrown.append(item))


	var fired:= gun.call("_fire") as bool
	_check("a buffer of loose hay fires", fired)
	_check("firing spends the buffer", gun.stored == 0)
	_check("firing puts one prop in the world", props.items.size() == before + 1)
	if not thrown.is_empty():
		var wad:= thrown [0] as HayWad
		_check("loose hay leaves as a wad", wad != null)
		if wad != null:
			_check("the wad carries the hay that went in",
				wad.strands == Cfg.LAUNCHER_WAD_STRANDS)
			var v:= wad.linear_velocity


			_check("it leaves with the solved speed (%.1f m/s)" % v.length(),
				absf(v.length() - TubeLauncher.speed_for(gun.power))
					< Cfg.LAUNCHER_SPREAD / TubeLauncher.MIN_DITHER_FLIGHT)
			_check("it leaves going up", v.y > 0.0)
			props.remove(wad)


	for power: float in [0.2, 1.0]:
		gun.power = power
		await _settle(gun)
		var aimed:= gun.landing_spot()
		var worst:= 0.0
		var shots:= 0
		for _i in 12:
			gun.stored = Cfg.LAUNCHER_WAD_STRANDS
			thrown.clear()
			if not (gun.call("_fire") as bool) or thrown.is_empty():
				continue
			var shot: Carryable = thrown [0]
			if shot == null:
				continue
			shots += 1
			var arc:= LaunchArc.sample(gun.muzzle_position(), shot.linear_velocity,
				gun.global_position.y, true)
			var at: Vector3 = arc [arc.size() - 1]
			worst = maxf(worst, Vector2(at.x - aimed.x, at.z - aimed.z).length())
			props.remove(shot)
		_check("twelve shots at power %.2f all fired" % power, shots == 12)


		_check("...and land within %.2f m of the aim point (worst %.2f m)"
			% [Cfg.LAUNCHER_SPREAD, worst], worst <= Cfg.LAUNCHER_SPREAD + 0.02)


		_check("...and are not all on the same point (worst %.2f m)" % worst,
			worst > 0.01)


	for power: float in [0.35, 1.0]:
		gun.power = power
		await _settle(gun)
		var aimed:= gun.landing_spot()
		gun.stored = Cfg.LAUNCHER_WAD_STRANDS
		thrown.clear()
		if not (gun.call("_fire") as bool) or thrown.is_empty():
			_check("a shot at power %.2f fired to fly" % power, false)
			continue
		var shot:= thrown [0] as RigidBody3D


		shot.collision_layer = 0
		shot.collision_mask = 0
		var ground:= gun.global_position.y
		var crossed:= Vector3.INF
		for _i in 600:
			await get_tree().physics_frame
			if not is_instance_valid(shot):
				break
			var p:= shot.global_position
			var v:= shot.linear_velocity
			if v.y < 0.0 and p.y < ground + 0.8:
				var t:= (p.y - ground) / - v.y
				crossed = Vector3(p.x + v.x * t, ground, p.z + v.z * t)
				break
		var miss:= INF if crossed == Vector3.INF else Vector2(crossed.x - aimed.x, crossed.z - aimed.z).length()
		_check("a flown shot at power %.2f comes down on the ring (%.2f m off, %.1f m out)"
			% [power, miss, gun.range_metres()], miss <= Cfg.LAUNCHER_SPREAD + 0.25)
		if is_instance_valid(shot):
			props.remove(shot as Carryable)


	var q: Array = gun.get("_queue")
	q.append({ "id": "hay_bale", "state": { } })
	thrown.clear()
	var fired_bale:= gun.call("_fire") as bool
	_check("a queued bale fires", fired_bale)
	if not thrown.is_empty():
		_check("a bale in is a bale out", thrown [0] is HayBale)
		props.remove(thrown [0])


	gun.pending_needles = PackedInt32Array([3, 4])
	gun.stored = Cfg.LAUNCHER_WAD_STRANDS
	thrown.clear()
	_check("a launcher holding a needle fires", gun.call("_fire") as bool)
	if not thrown.is_empty():
		_check("the needle leaves inside the wad (%d)" % thrown [0].needle_index,
			thrown [0].needle_index == 3)
		props.remove(thrown [0])


	_check("...one of them, and the other waits",
		gun.pending_needles.size() == 1 and gun.pending_needles [0] == 4)
	gun.stored = Cfg.LAUNCHER_WAD_STRANDS
	thrown.clear()
	gun.call("_fire")
	if not thrown.is_empty():
		_check("the next shot carries the one that waited",
			thrown [0].needle_index == 4)
		props.remove(thrown [0])
	_check("and then the machine is empty of needles",
		gun.pending_needles.is_empty())


	gun.stored = 0
	gun.pending_needles = PackedInt32Array([6])
	gun._queue.append({ "id": "hay_wad", "state": { "strands": 30, "needle": 2 } })
	gun._queue.append({ "id": "hay_wad", "state": { "strands": 30 } })
	thrown.clear()
	gun.call("_fire")
	if not thrown.is_empty():
		_check("a queued wad with its own needle keeps it (%d)" % thrown [0].needle_index,
			thrown [0].needle_index == 2)
		props.remove(thrown [0])
	_check("...and the waiting one is not squeezed in beside it",
		gun.pending_needles.size() == 1)
	thrown.clear()
	gun.call("_fire")
	if not thrown.is_empty():
		_check("the next queued wad carries the waiting needle (%d)" % thrown [0].needle_index,
			thrown [0].needle_index == 6)
		props.remove(thrown [0])
	_check("...and the machine is empty of needles again",
		gun.pending_needles.is_empty())


	gun.aim = 0.31
	gun.power = 0.83
	q = gun.get("_queue")
	q.append({ "id": "eco_brick", "state": { "strands": 45 } })
	var saved:= gun.to_dict()


	var other:= TubeLauncher.new()
	other.from_dict(saved)
	_check("power survives a save round trip", is_equal_approx(other.power, 0.83))
	_check("...and so does the angle, separately",
		is_equal_approx(other.aim, 0.31))


	var old:= TubeLauncher.new()
	old.from_dict({ "power": 0.44 })
	_check("an old save's single setting becomes both",
		is_equal_approx(old.aim, 0.44) and is_equal_approx(old.power, 0.44))
	old.queue_free()
	var oq: Array = other.get("_queue")
	_check("a load waiting in the breech survives a save", oq.size() == 1)
	_check("...and it is still the thing that went in",
		oq.size() == 1 and String((oq [0] as Dictionary) ["id"]) == "eco_brick")


	other.queue_free()
	gun.pending_needles = PackedInt32Array([9])
	var kept:= TubeLauncher.new()
	kept.from_dict(gun.to_dict())
	_check("a needle in the machine survives a save",
		kept.pending_needles.size() == 1 and kept.pending_needles [0] == 9)
	kept.queue_free()
	gun.pending_needles = PackedInt32Array()


	var tool0: BuildTool = player.build
	if tool0 != null:
		tool0.set_mode(BuildTool.Mode.LAUNCHER)
		tool0.set_active(true)
		await get_tree().process_frame
		var ghost0:= tool0.get_node_or_null("LauncherGhost") as TubeLauncher
		if ghost0 != null:
			var solid: Array [String] = []
			for n in ghost0.find_children("*", "CollisionObject3D", true, false):
				var body:= n as CollisionObject3D
				if body != null and body.collision_layer != 0:
					solid.append("%s(layer %d)" % [body.name, body.collision_layer])
			_check("the hologram carries no solid bodies (%s)"
				% ("none" if solid.is_empty() else ", ".join(solid)), solid.is_empty())
		tool0.set_active(false)


	var bodies: Array [String] = []
	for n in gun.find_children("*", "CollisionObject3D", true, false):
		var body:= n as CollisionObject3D
		if body == null or body.collision_layer == 0:
			continue
		if gun.deck() != null and gun.deck().is_ancestor_of(body):
			continue
		bodies.append(body.name)
	_check("a placed launcher has one collider of its own (%d: %s)"
		% [bodies.size(), ", ".join(bodies)], bodies.size() == 1)


	print("\n=== a run laid at it, and a wad through it ===")
	var feed_port:= gun.intake_port()


	var loose:= feed_port - gun.forward() * 0.22 + Vector3(0.16, 0.0, 0.0)
	var snapped:= builds.snap_endpoint(loose)
	_check("a belt end near the port snaps onto it (%.2f m away)"
		% loose.distance_to(feed_port), snapped.distance_to(feed_port) < 0.01)

	var run:= builds.add_conveyor(feed_port - gun.forward() * 3.0, feed_port)
	_check("a run can be laid into the port", run != null)
	await get_tree().physics_frame
	await get_tree().physics_frame


	_check("...and the junction hands it to the launcher's own deck",
		run != null and run.downstream == gun.deck())


	var props2: PropManager = world.props
	var start:= gun.port_in() - gun.forward() * 0.35 + Vector3(0.0, 0.12, 0.0)


	var fed:= props2.spawn("hay_wad", Transform3D(Basis(), start),
		{ "strands": 30, "needle": 11 }) as HayWad
	_check("a wad can be set on the intake deck", fed != null)
	_check("...with a needle in it", fed != null and fed.needle_index == 11)

	var caught:= false
	for _i in 240:
		await get_tree().physics_frame
		if gun.get("_queue") != null and (gun.get("_queue") as Array).size() > 0:
			caught = true
			break
	_check("the launcher swallows what reaches its mouth", caught)


	var flung: Array [Carryable] = []
	gun.launched.connect(func(item: Carryable) -> void: flung.append(item))
	for _i in 240:
		await get_tree().physics_frame
		if not flung.is_empty():
			break
	_check("...and throws it back out on its own", not flung.is_empty())
	if not flung.is_empty():
		var out:= flung [0]
		_check("what comes out is the wad that went in", out is HayWad
			and (out as HayWad).strands == 30)
		_check("...still holding the needle it arrived with (%d)" % out.needle_index,
			out.needle_index == 11)
		var rb2:= out as RigidBody3D
		_check("it leaves the muzzle, not the mouth",
			rb2 != null and rb2.global_position.distance_to(gun.muzzle_position()) < 0.6)
		_check("it leaves going up and forward",
			rb2 != null and rb2.linear_velocity.y > 0.5
				and rb2.linear_velocity.dot(gun.bore_direction()) > 0.5)
		props2.remove(out)
	_check("the buffer is empty again once it has fired",
		(gun.get("_queue") as Array).is_empty())


	print("\n=== full, it holds rather than spills ===")
	gun.set_switched_off(true)
	gun.stored = Cfg.LAUNCHER_BUFFER
	for _i in 4:
		await get_tree().physics_frame
	_check("a full launcher closes its mouth", gun.deck().is_blocked())


	var on_stub:= 0
	for i in 4:
		if world.live.spawn(gun.port_in() - gun.forward() * (0.25 + 0.12 * i)
				+ Vector3.UP * 0.05, Basis.IDENTITY, Vector3.ZERO,
				Cfg.COL_HAY_LIGHT) != null:
			on_stub += 1
	for i in 6:
		world.live.spawn(feed_port - gun.forward() * (2.6 - 0.25 * i) + Vector3.UP * 0.22,
			Basis.IDENTITY, Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	for _i in 480:
		await get_tree().physics_frame
	var fallen:= 0
	for child in world.live.get_children():
		var rb:= child as RigidBody3D
		if rb != null and rb.is_inside_tree() and rb.global_position.distance_to(gun.port_in()) < 2.5 and rb.global_position.y < gun.port_in().y - 0.4:
			fallen += 1
	print("  %d strands on the stub of a full launcher: %d held there, %d on the run behind, %d on the floor"
		% [on_stub, gun.deck().riders().size(), run.riders().size(), fallen])
	_check("nothing drops at the throat of a full launcher (%d on the floor)" % fallen,
		fallen == 0)
	_check("...the stub holds what it was given (%d riders)" % gun.deck().riders().size(),
		gun.deck().riders().size() >= on_stub - 1)
	_check("...and the run behind it backs up", run.has_rider_waiting())

	gun.stored = 0
	for _i in 240:
		await get_tree().physics_frame
		if gun.deck().riders().is_empty() and gun.stored >= on_stub - 1:
			break
	_check("...and it eats them once it has room (%d stored, stub holds %d)"
		% [gun.stored, gun.deck().riders().size()],
		gun.stored >= on_stub - 1 and gun.deck().riders().is_empty())
	gun.set_switched_off(false)
	gun.stored = 0

	builds.demolish(run)


	var entries:= BuildCatalog.entries()
	_check("the catalogue lists a launcher", entries.has("launcher"))
	if entries.has("launcher"):
		var entry: Dictionary = entries ["launcher"]
		_check("its catalogue entry names the build mode",
			int(entry ["mode"]) == int(BuildTool.Mode.LAUNCHER))
		_check("its catalogue entry names a real tech node",
			TechTree.has_id(String(entry ["unlock"])))
		_check("...and that node is reachable from the tree",
			not TechTree.requires(String(entry ["unlock"])).is_empty())
	var tool: BuildTool = player.build
	_check("the player has a build tool", tool != null)
	if tool != null:
		tool.set_mode(BuildTool.Mode.LAUNCHER)
		tool.set_active(true)
		await get_tree().process_frame
		var ghost:= tool.get_node_or_null("LauncherGhost") as TubeLauncher
		_check("the tool carries a launcher hologram", ghost != null)
		if ghost != null:
			_check("the hologram is a preview and not a live machine",
				ghost.placement_preview)


			var arc:= ghost.get_node_or_null("AimArc") as LaunchArc
			_check("the hologram draws an aim arc", arc != null)
			_check("the arc is up while the hologram is", arc != null and arc.visible)


			_check("the arc has geometry in it, not just a tint",
				arc != null and arc.drawn())
			_check("the hologram lays a stub of belt to aim a run at",
				ghost.get_node_or_null("GhostBelt") != null)
			_check("the hologram reports a range to the readout",
				ghost.range_metres() > MIN_RANGE)
		tool.set_active(false)


	var panel: LauncherPanel = world.get("launcher_panel")
	_check("the world builds a launcher panel", panel != null)
	if panel != null:
		gun.aim = 0.3
		gun.power = 0.7
		await _settle(gun)
		panel.open(gun)
		await get_tree().process_frame
		_check("opening the panel leaves the angle alone (%.2f)" % gun.aim,
			is_equal_approx(gun.aim, 0.3))
		_check("...and the power (%.2f)" % gun.power,
			is_equal_approx(gun.power, 0.7))
		var angle_slider:= panel.get("_angle") as HSlider
		var power_slider:= panel.get("_power") as HSlider
		_check("the panel has two sliders",
			angle_slider != null and power_slider != null)
		if angle_slider != null and power_slider != null:


			_check("the angle slider opens showing the machine's degrees (%.1f)"
				% angle_slider.value,
				absf(angle_slider.value - TubeLauncher.tilt_for(0.3)) < 0.51)
			_check("the power slider opens showing the machine's power (%.2f)"
				% power_slider.value, absf(power_slider.value - 0.7) < 0.005)


			angle_slider.value = 20.0
			await get_tree().process_frame
			_check("dragging the angle re-aims the machine (%.1f deg asked)"
				% 20.0,
				absf(gun.aim - TubeLauncher.aim_for_tilt(20.0)) < 0.01)
			_check("...and leaves the power where it was",
				is_equal_approx(gun.power, 0.7))
			power_slider.value = 0.25
			await get_tree().process_frame
			_check("dragging the power changes it",
				absf(gun.power - 0.25) < 0.005)
			_check("...and leaves the tube pointed where it was",
				absf(gun.aim - TubeLauncher.aim_for_tilt(20.0)) < 0.01)
		panel.close()
		await get_tree().process_frame
		_check("closing the panel lets go of the machine", panel.launcher() == null)


	var refund: float = builds.demolish(gun)
	_check("dismantling refunds the build cost", refund > 0.0)
	_check("the launcher is off the ledger", builds.tube_launchers.is_empty())

	_finish()


func _arc_peak(gun: TubeLauncher) -> float:
	var peak:= 0.0
	for p: Vector3 in LaunchArc.sample(gun.muzzle_position(),
			gun.launch_velocity(), gun.global_position.y, true):
		peak = maxf(peak, p.y - gun.global_position.y)
	return peak


func _rest(gun: TubeLauncher) -> void:
	var last:= gun.tilt_now()
	var still:= 0
	for _i in 240:
		await get_tree().physics_frame
		var now:= gun.tilt_now()
		still = (still + 1) if absf(now - last) < 0.0001 else 0
		last = now
		if still >= 3:
			return


func _settle(gun: TubeLauncher) -> void:
	var want:= TubeLauncher.tilt_for(gun.aim)
	for _i in 120:
		await get_tree().physics_frame
		if absf(gun.tilt_now() - want) < 0.05:
			return


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _finish() -> void:
	print("[launcher] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
