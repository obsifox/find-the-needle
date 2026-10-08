class_name DevPulperProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const LANE_X:= 13.0

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0


var _last_drop:= Vector3.INF


func run() -> void:
	_rng.seed = 20260823
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _case_the_meter()
	await _case_slabs_share()
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	pulper.slabbed.connect(_on_slabbed)
	pulper.slabbed_record.connect(_on_slabbed_record)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	await _case_the_model(pulper)
	await _case_the_clip(pulper)
	await _case_the_geometry(pulper, deck_y)
	await _case_the_hologram(pulper)
	await _case_snapping(pulper)
	await _case_the_line(pulper, deck_y)
	await _case_wads_go_in(pulper)
	await _case_dry(pulper)
	await _case_plumbed(pulper)
	await _case_the_drum_turns(pulper)
	await _case_one_slab(pulper)
	await _case_the_door(pulper)
	await _case_the_slab_rides(pulper)
	await _case_conservation(pulper)
	await _case_outfeed_blocked(pulper)
	await _case_dead(pulper)
	await _case_the_save(pulper)
	await _case_the_churn(deck_y)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_slabs_share() -> void:
	print("\r\n=== every slab wears one set of materials ===")
	var slabs: Array [HayPulp] = []
	for i in 2:
		var slab:= world.props.spawn("hay_pulp", Transform3D(Basis.IDENTITY,
			Vector3(LANE_X + 3.0 * i, 0.5, -6.0))) as HayPulp
		if slab != null:
			slabs.append(slab)
	_check("two slabs were spawned", slabs.size() == 2)
	if slabs.size() < 2:
		return
	var a:= slabs [0]._meshes
	var b:= slabs [1]._meshes
	var worn:= a.size() == 2 and a.size() == b.size()
	var surfaces:= 0
	if worn:
		for k in a.size():
			for s in a [k].mesh.get_surface_count():
				var mine:= a [k].get_active_material(s)
				surfaces += 1
				if mine == null or mine != b [k].get_active_material(s):
					worn = false
	_check("body and liquor wear the same %d materials" % surfaces, worn and surfaces >= 5)
	for slab in slabs:
		slab.queue_free()
	await get_tree().physics_frame


func _case_the_meter() -> void:
	print("\n=== the meter ===")
	var net: WaterGrid = world.builds.water
	_check("the yard has a water grid", net != null)
	_check("...and this run keeps it metered", net != null and not net.unmetered)


	_check("...while the electricity is not, so no generator is needed here",
		world.builds.grid.unmetered)
	_check("an empty yard has no water networks", net.network_count() == 0)


func _case_the_model(pulper: HayPulper) -> void:
	print("\n=== the model ===")
	_check("model instantiated", pulper.get_node_or_null("Model") != null)


	_check("it is the reference model",
		HayPulper.MODEL.ends_with("hay_pulper_reference.glb"))
	for marker in [HayPulper.N_BELT_IN, HayPulper.N_BELT_OUT, HayPulper.N_FEED,
			HayPulper.N_SLAB, HayPulper.N_PIPE_PORT, HayPulper.N_PANEL]:
		_check("marker %s" % marker, pulper._find(marker) != null)
	for part in [HayPulper.N_LEVEL, HayPulper.N_POUR, HayPulper.N_COVER,
			HayPulper.N_GATE_PIVOT, "Pulp_Rotor_Pivot", "Pulp_Drive_Pivot",
			"Pulp_FeedHead_Pivot", "Pulp_FeedTail_Pivot"]:
		_check("moving part %s" % part, pulper._find(part) != null)
	_check("the driven lamp resolved", not pulper._go_meshes.is_empty())


	_check("the intake belt is the yard's own moving rubber",
		pulper._feed_belt_mat != null
			and pulper._feed_belt_mat.shader == load(ConveyorKit.SHADER))
	if pulper._feed_belt_mat != null:


		var running: float = pulper._feed_belt_mat.get_shader_parameter("speed")
		_check("...scrolling at the speed its own drums turn (%.3f m/s at drive %.2f)"
			% [running, pulper.drive()],
			absf(absf(running) - HayPulper.FEED_BELT_MPS * pulper.drive()) < 0.001)


		_check("...and toward the hopper rather than away from it (%.3f)"
			% running, running <= 0.0 and HayPulper.FEED_BELT_SIGN < 0.0)


		_check("...and at full drive that is the yard's belt speed (%.3f against %.2f)"
			% [HayPulper.FEED_BELT_MPS, Cfg.BELT_SPEED],
			absf(HayPulper.FEED_BELT_MPS - Cfg.BELT_SPEED) < 0.02)
		_check("...with the yard's cleat pitch on it",
			absf(float(pulper._feed_belt_mat.get_shader_parameter("cleat_pitch"))
				- ConveyorKit.CLEAT_PITCH) < 0.0001)


		pulper.set_switched_off(true)
		var stopped: float = pulper._feed_belt_mat.get_shader_parameter("speed")
		pulper.set_switched_off(false)
		_check("...and stands still when the machine is switched off (%.3f)"
			% stopped, absf(stopped) < 0.0001)


	var charge:= pulper._find(HayPulper.N_LEVEL) as MeshInstance3D
	for f: float in [1.0, 0.86, 0.6, 0.25, 0.02]:
		var out:= _worst_reach(charge, f)
		_check("at %.0f%% full nothing reaches past the bore (%.4f of 1.0)"
			% [f * 100.0, out], out <= 1.0005)


	for f: float in [HayPulper.BED_CEIL, 0.3, HayPulper.BED_FLOOR]:
		var out:= _worst_reach(pulper._bed_mesh, f)
		_check("...and the pulp bed at %.0f%% (%.4f of 1.0)" % [f * 100.0, out],
			out <= 1.0005)


	for body: Node3D in [charge, pulper._bed_mesh]:
		if body == null:
			continue
		_check("%s is not scaled on Y (%.4f)" % [body.name, body.scale.y],
			absf(body.scale.y - 1.0) < 0.0001)


	var slurry: ShaderMaterial = null
	for i in charge.mesh.get_surface_count():
		var m:= charge.get_surface_override_material(i) as ShaderMaterial
		if m != null and m.resource_name == HayPulper.MAT_SLURRY:
			slurry = m
			break
	_check("the mash wears the slurry shader", slurry != null
		and slurry.shader == load(HayCompressor.SLURRY_SHADER))
	if slurry != null:
		var uniforms:= slurry.shader.get_shader_uniform_list()
		_check("...and that shader built (%d uniforms)" % uniforms.size(),
			uniforms.size() >= 8)


	_check("the drum carries an inspection lamp", pulper._drum_lamp != null)
	if pulper._drum_lamp != null:
		_check("...lit while the machine has a wire", pulper._drum_lamp.visible)


		pulper.set_switched_off(true)
		_check("...out when the machine is switched off",
			not pulper._drum_lamp.visible)
		pulper.set_switched_off(false)
		_check("...and back on when it is switched in", pulper._drum_lamp.visible)


		_check("...casting a shadow, so the shell holds the light in",
			pulper._drum_lamp.shadow_enabled)


	var ports:= pulper.power_ports()
	_check("two terminals on the model", ports.size() == 2)
	for port: Node3D in ports:
		var up:= pulper.to_local(port.global_position).y
		_check("%s ties on at insulator height (%.3f m)" % [port.name, up],
			absf(up - HayPulper.WIRE_PORT_FALLBACK_A.y) < 0.01)


	var level:= pulper._find(HayPulper.N_LEVEL) as MeshInstance3D
	var mash:= _mash_surface(level)
	_check("the mash is a rippling surface, not a flat", pulper._wave_mat != null)
	_check("...on a waterline with something to ripple (%d verts)" % mash,
		mash > 200)


	if pulper._wave_mat != null and level != null and level.mesh != null:
		var box:= level.mesh.get_aabb()
		var top: float = pulper._wave_mat.get_shader_parameter("surface_y")
		_check("...and where its surface is (%.3f m up the bore)" % top,
			absf(top - (box.position.y + box.size.y)) < 0.001)


	_check("two animation players", pulper._anim != null and pulper._door != null
		and pulper._anim != pulper._door)
	_check("...the loop is playing", pulper._anim != null and pulper._anim.is_playing())
	_check("...and the door is parked shut",
		pulper._door != null and not pulper._door.is_playing()
		and absf(pulper.gate_angle_deg()) < 1.0)


	var moving_solid:= 0
	for name in [HayPulper.N_GATE_PIVOT, "Pulp_Rotor_Pivot"]:
		var pivot:= pulper._find(name) as Node3D
		if pivot == null:
			continue
		for n in pivot.find_children("*", "CollisionObject3D", true, false):
			moving_solid += 1
	_check("no collider hangs off a moving pivot (%d)" % moving_solid,
		moving_solid == 0)


func _case_the_clip(pulper: HayPulper) -> void:
	print("\n=== the clip owns the cycle ===")
	var seconds:= pulper.door_clip_seconds()
	_check("the door clip is %.4f s, and Cfg says %.4f"
		% [seconds, Cfg.PULPER_CYCLE_SECONDS],
		absf(seconds - Cfg.PULPER_CYCLE_SECONDS) < 0.01)
	_check("...which is %.0f frames at %.0f fps"
		% [HayPulper.CYCLE_FRAMES, HayPulper.CLIP_FPS],
		absf(HayPulper.CYCLE_FRAMES / HayPulper.CLIP_FPS
			- Cfg.PULPER_CYCLE_SECONDS) < 0.001)


	_check("the release frame is inside the open dwell (%.0f, open %.0f to 76)"
		% [HayPulper.F_RELEASE, HayPulper.F_GATE_OPEN],
		HayPulper.F_RELEASE > HayPulper.F_GATE_OPEN and HayPulper.F_RELEASE < 76.0)


	var name:= HayPulper._clip_name(pulper._door, HayPulper.CLIP_DOOR)
	_check("the door clip is in the second player's library", name != "")
	if name != "":
		pulper._door.play(name)
		pulper._door.seek(Cfg.PULPER_CYCLE_SECONDS * 0.5, true)
		pulper._door.pause()
		var open:= pulper.gate_angle_deg()
		_check("the gate swings open to %.0f degrees (measured %.1f)"
			% [HayPulper.GATE_OPEN_DEG, open],
			absf(open - HayPulper.GATE_OPEN_DEG) < 2.0)
		pulper._door.seek(0.0, true)
		pulper._door.pause()
		_check("...and comes back shut (%.1f)" % pulper.gate_angle_deg(),
			absf(pulper.gate_angle_deg()) < 1.0)


func _case_the_geometry(pulper: HayPulper, deck_y: float) -> void:
	print("\n=== geometry ===")
	var span:= pulper.port_in().distance_to(pulper.port_out())


	_check("ports %.2f m apart (want %.2f)" % [span, Cfg.PULPER_LENGTH],
		absf(span - Cfg.PULPER_LENGTH) < 0.02)
	_check("...which is a whole number of belt segments",
		absf(fmod(Cfg.PULPER_LENGTH, Cfg.BELT_SEGMENT)) < 0.001)
	_check("infeed port on the deck plane (%.3f vs %.3f)"
		% [pulper.port_in().y, deck_y], absf(pulper.port_in().y - deck_y) < 0.02)


	_check("travel is +Z as placed", pulper.forward().dot(Vector3.BACK) > 0.99)

	var slab:= pulper.slab_spot()
	_check("the slab spot is downstream of centre",
		(slab - pulper.global_position).dot(pulper.forward()) > 0.3)
	_check("...and short of the outfeed face by %.2f m"
		% (pulper.port_out() - slab).dot(pulper.forward()),
		(pulper.port_out() - slab).dot(pulper.forward()) > 0.05)


	_check("there is an outfeed stub under the chute",
		pulper.outfeed_deck() != null and pulper.outfeed_deck().path_length() > 0.3)
	var along:= (slab - (pulper.port_out()
		- pulper.forward() * HayPulper.OUT_STUB)).dot(pulper.forward())
	_check("...and the slab spot is %.2f m along it, clear of both dead zones"
		% along, along > 0.1 and along < HayPulper.OUT_STUB - 0.1)


	var port_local:= pulper.to_local(pulper.water_port())
	_check("the water flange is on the -X flank (x %.2f)" % port_local.x,
		port_local.x < -0.5)
	_check("...at chest height (y %.2f)" % port_local.y, port_local.y > 0.5)
	_check("two wire terminals", pulper.power_ports().size() == 2)


func _case_the_hologram(pulper: HayPulper) -> void:
	print("\n=== the hologram ===")
	var ghost:= HayPulper.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = pulper.global_position + Vector3(0.0, 0.0, 12.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the ghost draws belt through itself", ghost._ghost_belt != null)
	_check("...and chevrons along it", ghost._ghost_flow != null
		and ghost._ghost_flow.multimesh.visible_instance_count > 0)


	var drawn:= 0.0
	if ghost._ghost_belt != null:
		drawn = ghost._ghost_belt.drawn_length
	var laid:= pulper.deck().path_length() + pulper.outfeed_deck().path_length()
	_check("the ghost draws the belt the machine lays (%.3f m drawn, %.3f m laid)"
		% [drawn, laid], absf(drawn - laid) < 0.01)
	_check("...with its rails", ghost._ghost_belt != null
		and ghost._ghost_belt.drawn(BeltGhost.RAIL_L) > 0)
	var phase_was:= ghost._flow_phase
	for i in 10:
		await get_tree().process_frame
	_check("the chevrons scroll (%.3f -> %.3f)" % [phase_was, ghost._flow_phase],
		ghost._flow_phase > phase_was)
	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_check("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	_check("...and lays no belt path of its own",
		ghost.deck() == null and ghost.outfeed_deck() == null)


	var pour:= ghost._find(HayPulper.N_POUR) as Node3D
	_check("...and carries no heap of cream on its outfeed",
		pour == null or not pour.visible)


	var ghost_bath:= ghost._find(HayPulper.N_LEVEL) as Node3D
	_check("...nor a bath standing in its drum",
		not ghost.has_liquor()
		and (ghost_bath == null or not ghost_bath.visible))
	world.remove_child(ghost)
	ghost.queue_free()


func _case_snapping(pulper: HayPulper) -> void:
	print("\n=== snapping and siting ===")
	for port: Vector3 in [pulper.port_in(), pulper.port_out()]:
		var near:= port + Vector3(0.35, 0.0, 0.4)
		var snapped: Vector3 = world.builds.snap_endpoint(near)
		_check("a belt end near a port snaps onto it (off by %.3f m)"
			% snapped.distance_to(port), snapped.is_equal_approx(port))
	var far:= pulper.port_out() + Vector3(6.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second pulper on the same spot is refused",
		world.builds.pulper_overlap(pulper.global_position))


	_check("a press on the same spot is refused too",
		world.builds.compressor_overlap(pulper.global_position))
	_check("...and a scanner, a wrapper and a silo",
		world.builds.scanner_overlap(pulper.global_position)
		and world.builds.wrapper_overlap(pulper.global_position)
		and world.builds.silo_overlap(pulper.global_position))


	_check("...and the refusal reaches %.1f m, which is this module's own half"
		% (Cfg.PULPER_LENGTH * 0.5), world.builds.pulper_overlap(
			pulper.global_position + pulper.forward() * (Cfg.PULPER_LENGTH * 0.4)))

	_check("the machine answers to the fleet walk",
		world.builds.all_buildings().has(pulper)
		and world.builds.every_placed().has(pulper))
	_check("...and it has a name off the catalogue (%s)"
		% world.builds.name_of(pulper), world.builds.name_of(pulper) != "")


func _case_the_line(pulper: HayPulper, deck_y: float) -> void:
	print("\n=== the line runs up to it ===")
	world.builds.add_conveyor(Vector3(LANE_X, deck_y, -9.0), pulper.port_in())
	world.builds.add_conveyor(pulper.port_out(),
		pulper.port_out() + Vector3(0.0, 0.0, 6.0))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the run feeding it hands hay to the infeed stub",
		world.builds.feed_run_into(pulper.port_in()) != null)


	_check("the infeed stub hands nothing on",
		pulper.deck() != null and pulper.deck().downstream == null)
	_check("...and the outfeed stub does",
		pulper.outfeed_deck() != null and pulper.outfeed_deck().downstream != null)
	var sections:= 0
	for n in pulper.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi:= n as MultiMeshInstance3D
		if mmi.name == "Sections" and mmi.multimesh != null:
			sections += mmi.multimesh.instance_count
	_check("the placed module draws its own belt at both faces (%d sections)"
		% sections, sections > 0)
	_check("the drawn belt is placed in world space, not the module's",
		pulper.deck().get_node_or_null("Path") != null
		and (pulper.deck().get_node("Path") as Node3D).top_level)


func _case_wads_go_in(pulper: HayPulper) -> void:
	print("\r\n=== wads go in ===")
	var held:= pulper.stored


	var want:= 12
	var strands:= 30
	var sent: Array [HayWad] = []


	var drop:= pulper.port_in() - pulper.forward() * 1.4 + Vector3.UP * 0.3
	for i in want:
		var wad:= world.props.spawn("hay_wad",
			Transform3D(pulper.global_basis.orthonormalized(), drop),
			{ "strands": strands }) as HayWad
		if wad != null:
			sent.append(wad)
		for _f in 55:
			await get_tree().physics_frame
	_check("%d wads were put on the run" % sent.size(), sent.size() == want)

	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0


	var strayed: Array [String] = []
	while elapsed < 45.0:
		await get_tree().physics_frame
		elapsed += step


		var standing: Array [Vector3] = []
		for w in sent:
			if is_instance_valid(w) and w.is_inside_tree():
				standing.append(w.global_position)
		for seq: int in _records_of("hay_wad"):
			var where:= BeltPath.record_where(seq)
			if not where.is_empty():
				standing.append((where ["pose"] as Transform3D).origin)
		for at: Vector3 in standing:
			var d:= at - pulper.global_position

			if d.dot(pulper.forward()) > Cfg.PULPER_LENGTH * 0.5 or d.y > 1.0:
				var tag:= "%.2f m along, %.2f m up" % [d.dot(pulper.forward()), d.y]
				if not strayed.has(tag):
					strayed.append(tag)
		if pulper.stored - held >= want * strands:
			break


	var loose:= _count("hay_wad")
	var gone:= want - loose
	print("  %d of %d wads swallowed, %d still out, buffer %d -> %d"
		% [gone, want, loose, held, pulper.stored])
	if not strayed.is_empty():
		print("  wads seen off the line:")
		for tag in strayed:
			print("    " + tag)
	_check("every wad reaches the drum (%d of %d)" % [gone, want], gone == want)
	_check("...and the hay in them is in the buffer (%d, want %d)"
		% [pulper.stored - held, want * strands],
		pulper.stored - held == want * strands)


	_check("no wad ends up off the line (%d did)" % strayed.size(),
		strayed.is_empty())


func _case_dry(pulper: HayPulper) -> void:
	print("\n=== no water ===")
	_check("nothing is plumbed to it yet", pulper.water_blocked)
	_check("...so it is dry (%.2f)" % pulper.water, is_zero_approx(pulper.water))
	_check("...and the blank cover is bolted over the flange",
		_cover_visible(pulper))
	_check("...its sign says so", pulper.alert_icon() == "water")
	_check("...in words that name the pipe (%s)" % pulper.alert_reason(),
		pulper.alert_reason().begins_with("NO WATER")
		and pulper.alert_reason().contains("pipe"))


	_check("...while the wire is fine (%.2f)" % pulper.power,
		pulper.power > 0.999)
	_check("...so `drive` is zero and nothing will turn (%.2f)" % pulper.drive(),
		is_zero_approx(pulper.drive()))


	var barrel:= pulper._find(HayPulper.N_LEVEL) as Node3D
	_check("...and there is no bath standing in the drum",
		not pulper.has_liquor() and barrel != null and not barrel.visible)


	_check("...so the swell has stopped dead (%.2f)" % _wave_flow_of(pulper),
		is_zero_approx(_wave_flow_of(pulper)))

	var made:= await _feed(pulper, Tech.pulper_batch_strands() * 2, 12.0)
	await _settle_intake(pulper)
	print("  fed %d strands to a dry pulper" % made)
	_check("a dry pulper makes no slabs (%d)" % _count("hay_pulp"),
		_count("hay_pulp") == 0)
	_check("...and does not spend the hay it swallowed (%d held)" % pulper.stored,
		pulper.stored >= Tech.pulper_batch_strands())


func _case_plumbed(pulper: HayPulper) -> void:
	print("\n=== a well on the end of a pipe ===")
	var pump: BoreholePump = world.builds.add_borehole(
		Vector3(LANE_X + 7.0, 0.0, -8.0), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the pump makes %.1f litres a second" % pump.water_lps(),
		absf(pump.water_lps() - Tech.borehole_output()) < 0.01)
	_check("the pulper wants %.2f litres a second" % pulper.water_draw_lps(),
		absf(pulper.water_draw_lps() - Cfg.PULPER_WATER_LITRES
			/ Tech.pulper_cycle_seconds()) < 0.001)


	_check("...so one base well feeds %.2f of them"
		% (Tech.borehole_output() / pulper.water_draw_lps()),
		Tech.borehole_output() / pulper.water_draw_lps() > 1.0
		and Tech.borehole_output() / pulper.water_draw_lps() < 2.0)


	var port:= pulper.water_port()
	var aimed:= port + Vector3(-0.4, -0.25, 0.2)
	_check("the pulper's flange is one the yard can find",
		world.builds.nearest_flange(port).distance_to(port) < 0.001)
	_check("...and aiming near it snaps a run end onto it",
		world.builds.snap_water_endpoint(aimed).distance_to(port) < 0.001)


	var run: WaterMain = world.builds.add_water_main(pump.water_port(), pulper.water_port())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var net: WaterGrid = world.builds.water
	var got:= net.report(pulper)
	_check("laying a run onto the flange plumbs it in", bool(got ["connected"])
		and not pulper.water_blocked)
	_check("...the pump is on the same network",
		net.network_of(pump) >= 0 and net.network_of(pump) == net.network_of(pulper))
	_check("...the cover comes off the flange", not _cover_visible(pulper))
	_check("...and it is wet (%.2f)" % pulper.water, pulper.water > 0.999)
	_check("...with the sign gone", pulper.alert_icon() == ""
		and pulper.alert_reason() == "")
	_check("...and the main it is on carries flow (%.2f)" % run.flow,
		run.flow > 0.999)


	_check("...and a second run is refused the port",
		world.builds.water_port_taken(port))


	world.builds.demolish(run)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("taking the run up puts the cover back on", _cover_visible(pulper)
		and pulper.water_blocked and is_zero_approx(pulper.water))
	world.builds.add_water_main(pump.water_port(), pulper.water_port())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("...and laying it again takes it off", not _cover_visible(pulper)
		and pulper.water > 0.999)


func _case_the_drum_turns(pulper: HayPulper) -> void:
	print("\n=== the drum turns ===")
	_check("both utilities are up, so it should be turning (%.2f)"
		% pulper.drive(), pulper.drive() > 0.999)
	var anim:= pulper._anim
	var door:= pulper._door
	if anim == null or door == null:
		_check("the machine has its two players", false)
		return


	_check("the loop's player owns one clip (%s)"
		% ", ".join(anim.get_animation_list()),
		anim.get_animation_list().size() == 1
		and anim.has_animation(HayPulper.CLIP_RUN))
	_check("...and the door's owns the other (%s)"
		% ", ".join(door.get_animation_list()),
		door.get_animation_list().size() == 1
		and door.has_animation(HayPulper.CLIP_DOOR))

	var rotor:= pulper._find("Pulp_Rotor_Pivot") as Node3D
	var feed:= pulper._find("Pulp_FeedTail_Pivot") as Node3D
	if rotor == null or feed == null:
		_check("the model has its driven pivots", false)
		return


	var rotor_from:= rotor.rotation
	var feed_from:= feed.rotation
	var rotor_moved:= 0.0
	var feed_moved:= 0.0
	for i in 240:
		await get_tree().process_frame
		rotor_moved = maxf(rotor_moved, (rotor.rotation - rotor_from).length())
		feed_moved = maxf(feed_moved, (feed.rotation - feed_from).length())
		if rotor_moved > 0.05 and feed_moved > 0.05:
			break
	print("  paddle shaft moved %.3f rad, intake pulley %.3f rad"
		% [rotor_moved, feed_moved])
	_check("the paddle shaft turns (%.3f rad)" % rotor_moved, rotor_moved > 0.02)
	_check("...and the intake pulley turns with it (%.3f rad)" % feed_moved,
		feed_moved > 0.02)


	pulper.set_switched_off(true)
	for i in 4:
		await get_tree().process_frame
	var parked:= rotor.rotation
	var drift:= 0.0
	for i in 60:
		await get_tree().process_frame
		drift = maxf(drift, (rotor.rotation - parked).length())
	_check("...and stands still once the machine is switched off (%.4f rad)"
		% drift, drift < 0.001)
	pulper.set_switched_off(false)
	for i in 4:
		await get_tree().process_frame


func _case_one_slab(pulper: HayPulper) -> void:
	print("\n=== one slab ===")


	print("  the dry run left %d strands in the buffer" % pulper.stored)
	var before:= _count("hay_pulp")
	var made:= await _feed(pulper, Tech.pulper_batch_strands(), 30.0, true)
	print("  fed %d more strands" % made)
	var fresh:= _count("hay_pulp") - before
	_check("a slab came out (%d)" % fresh, fresh >= 1)


	var slab: HayPulp = _materialize(_last_pushed_seq) as HayPulp
	if slab == null:
		slab = _materialize(_newest_seq_of("hay_pulp")) as HayPulp
	if slab == null and not _slabs().is_empty():
		slab = _slabs() [0]
	_check("the slab is a prop on L_PROP",
		slab != null and (slab.collision_layer & Cfg.L_PROP) != 0)
	_check("...and NOT hay, so the belt cannot pack it at strand pitch",
		slab != null and (slab.collision_layer & Cfg.L_STRAND) == 0)
	_check("the slab knows what went into it (%d)"
		% (slab.strands if slab != null else -1),
		slab != null and slab.strands == Tech.pulper_batch_strands())


	_check("...and what it is worth (%.0f strand-equivalents at x%.2f)"
		% [slab.sale_strands() if slab != null else -1.0, Tech.pulp_value_ratio()],
		slab != null and is_equal_approx(slab.sale_strands(),
			float(slab.strands) * Tech.pulp_value_ratio()))
	_check("...which is more than a foiled bale of the same hay (%.0f)"
		% (float(Cfg.PULPER_BATCH_STRANDS) * Tech.bale_value_ratio()
			* Tech.foil_value_ratio()),
		Tech.pulp_value_ratio() > Tech.bale_value_ratio() * Tech.foil_value_ratio())
	_check("...while the hay actually in it is unpremiumed (%d)"
		% (slab.hay_strands() if slab != null else -1),
		slab != null and slab.hay_strands() == slab.strands)


	var off:= 1000000000.0
	if _last_drop.x < 1e+30:
		off = Vector2(_last_drop.x - pulper.slab_spot().x,
			_last_drop.z - pulper.slab_spot().z).length()
	_check("...and it was set down on Marker_Slab (%.3f m off)" % off, off < 0.05)


func _case_the_churn(deck_y: float) -> void:
	print("\n=== the drum is a wet churn ===")
	_check("the loop is in the library", Audio.LOOP_LIB.has("pulper_churn"))
	_check("...and its file is on disk",
		ResourceLoader.exists(str(Audio.LOOP_LIB.get("pulper_churn", ""))))
	_check("...and it is the pulper's own, not the press's",
		str(Audio.LOOP_LIB.get("pulper_churn", ""))
		!= str(Audio.LOOP_LIB.get("motor_b", "")))

	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("a fresh pulper on the old main is wet again (%.2f)" % pulper.water,
		pulper.water > 0.999)
	_check("...and powered (%.2f)" % pulper.power, pulper.power > 0.999)
	_check("an idle machine holds no voice (%d)" % pulper._churn_voice,
		not pulper.is_running() and pulper._churn_voice < 0)
	var free_before:= Audio.loops_available()


	pulper.stored = Tech.pulper_batch_strands()
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var held:= false
	var pitched:= -1.0
	var elapsed:= 0.0
	while elapsed < 20.0:
		await get_tree().physics_frame
		elapsed += step
		if pulper.is_running() and pulper._churn_voice >= 0:
			held = true
			pitched = Audio._loops [pulper._churn_voice].pitch_scale
			break
	_check("a running batch holds a voice", held)
	_check("...one out of the pool (%d free, %d before)"
		% [Audio.loops_available(), free_before],
		Audio.loops_available() == free_before - 1)
	_check("...pitched by drive() and not power (%.2f against %.2f)"
		% [pitched, MachinePower.loop_pitch(pulper.drive())],
		absf(pitched - MachinePower.loop_pitch(pulper.drive())) < 0.01)


	var belt_now: float = pulper._feed_belt_mat.get_shader_parameter("speed")
	_check("...with its intake belt running (%.3f m/s)" % belt_now,
		absf(belt_now) > HayPulper.FEED_BELT_MPS * 0.999
			and belt_now * HayPulper.FEED_BELT_SIGN > 0.0)


	pulper.set_water(0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("the wire is still full (%.2f) and the pipe is empty (%.2f)"
		% [pulper.power, pulper.water],
		pulper.power > 0.999 and is_zero_approx(pulper.water))
	var dry_pitch: float = Audio._loops [pulper._churn_voice].pitch_scale
	_check("...so the bed sags to the floor MIN_LOOP_PITCH sets (%.2f)" % dry_pitch,
		absf(dry_pitch - MachinePower.MIN_LOOP_PITCH) < 0.01)
	pulper.set_water(1.0)


	var left:= 30.0
	while left > 0.0 and (pulper.is_running() or pulper._churn_voice >= 0):
		await get_tree().physics_frame
		left -= step
	_check("the voice goes back when the batch does (%d)" % pulper._churn_voice,
		pulper._churn_voice < 0)
	_check("...and the pool came back whole (%d of %d)"
		% [Audio.loops_available(), free_before],
		Audio.loops_available() == free_before)


	pulper.stored = Tech.pulper_batch_strands()
	elapsed = 0.0
	while elapsed < 20.0 and pulper._churn_voice < 0:
		await get_tree().physics_frame
		elapsed += step
	_check("a batch is running again (voice %d)" % pulper._churn_voice,
		pulper._churn_voice >= 0)
	_check("...and the yard would take it down mid batch, losing %s"
		% world.builds.hay_inside(pulper),
		world.builds.demolish_blocked_reason(pulper) == "")
	world.builds.clear()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	_check("...but clearing the yard under it gives every voice back (%d of %d)"
		% [Audio.loops_available(), Audio.POOL_LOOP],
		Audio.loops_available() == Audio.POOL_LOOP)


func _case_the_door(pulper: HayPulper) -> void:
	print("\n=== the door opens once per slab ===")
	var slabs_was:= pulper.slabs_made
	var swing:= 0.0
	var pour_seen:= false
	var pour_after_release:= false
	var pour_ran:= 0.0
	var wave_ran:= 0.0
	var level_seen:= 0.0


	var bath_high:= 0.0
	var bath_low:= INF


	var bed_pouring:= INF
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0
	var fed:= 0
	var next_in:= 0.0
	var want:= Tech.pulper_batch_strands()
	while elapsed < 40.0:
		await get_tree().physics_frame
		elapsed += step
		next_in -= step
		if fed < want and next_in <= 0.0:
			next_in = 0.06
			if _spawn_strand(pulper):
				fed += 1
		swing = maxf(swing, absf(pulper.gate_angle_deg()))
		level_seen = maxf(level_seen, pulper.charge_fraction())
		if pulper.charge_fraction() > 0.5:
			wave_ran = maxf(wave_ran, _wave_flow_of(pulper))
		var bath:= pulper._find(HayPulper.N_LEVEL) as Node3D
		if bath != null and bath.visible:
			var lvl:= _bath_fill_of(pulper)
			bath_high = maxf(bath_high, lvl)
			bath_low = minf(bath_low, lvl)
		var pour:= pulper._find(HayPulper.N_POUR) as Node3D
		if pour != null and pour.visible:
			pour_seen = true
			bed_pouring = minf(bed_pouring, pulper.charge_fraction())
			pour_ran = maxf(pour_ran, absf(_pour_flow_of(pulper)))
			if pulper._released:
				pour_after_release = true
		if pulper.slabs_made > slabs_was and not pulper.is_running():
			break
	var cycles:= pulper.slabs_made - slabs_was
	print("  %d batch(es), gate swung to %.0f degrees, drum filled to %.2f"
		% [cycles, swing, level_seen])
	_check("one batch, one door cycle (%d)" % cycles, cycles == 1)
	_check("...and the gate really swung (%.0f of %.0f degrees)"
		% [swing, absf(HayPulper.GATE_OPEN_DEG)],
		swing > absf(HayPulper.GATE_OPEN_DEG) * 0.8)
	_check("...the pulp bed built up in the drum (%.2f)" % level_seen,
		level_seen > 0.6)


	_check("...while the liquor stood at one level all through (%.4f..%.4f)"
		% [bath_low, bath_high],
		bath_high > 0.0 and absf(bath_high - bath_low) < 0.0005)
	_check("...at the level the machine states (%.3f of %.3f)"
		% [bath_high, HayPulper.BATH_FILL], absf(bath_high - HayPulper.BATH_FILL) < 0.001)


	_check("...with a swell running across it (%.2f)" % wave_ran,
		wave_ran > 0.001)
	_check("...at the speed drive() sets (%.2f)" % wave_ran,
		absf(wave_ran - 1.0) < 0.01)
	_check("...the cream poured out of the chute", pour_seen)


	_check("...and the bed ran out of the drum while it did (%.2f)"
		% bed_pouring, bed_pouring < 0.05)


	_check("...with its surface running down the tongue (%.2f)" % pour_ran,
		pour_ran > 0.001)
	_check("...at the speed drive() sets (%.2f of %.2f)"
		% [pour_ran, HayPulper.POUR_FLOW],
		absf(pour_ran - HayPulper.POUR_FLOW) < 0.01)


	_check("...and it stops dead when the pour is hidden",
		is_zero_approx(_pour_flow_of(pulper)))


	_check("...and it was hidden the moment the slab was set down",
		not pour_after_release)
	_check("...with the gate shut again afterwards (%.1f)"
		% pulper.gate_angle_deg(), absf(pulper.gate_angle_deg()) < 3.0)


	var bath_after:= pulper._find(HayPulper.N_LEVEL) as Node3D
	_check("...and the liquor still standing in it (%.3f)"
		% _bath_fill_of(pulper),
		bath_after != null and bath_after.visible
		and absf(_bath_fill_of(pulper) - HayPulper.BATH_FILL) < 0.001)


func _case_the_slab_rides(pulper: HayPulper) -> void:
	print("\n=== the slab rides the outgoing run ===")


	var seq:= _last_pushed_seq
	if seq < 0 or BeltPath.record_where(seq).is_empty():
		seq = _newest_seq_of("hay_pulp")
	var slab: HayPulp = null
	if seq < 0 and not _slabs().is_empty():
		slab = _slabs() [_slabs().size() - 1]
	if seq < 0 and slab == null:
		_check("there is a slab to carry away", false)
		return
	var was: Vector3 = _slab_origin(seq, slab)
	var moved:= 0.0
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0
	while elapsed < 12.0:
		await get_tree().physics_frame
		elapsed += step
		var now: Variant = _slab_origin(seq, slab)
		if now == null:
			break
		moved = ((now as Vector3) - was).dot(pulper.forward())
		if moved > 1.2:
			break
	print("  the slab travelled %.2f m downstream in %.1f s" % [moved, elapsed])
	_check("the belt carries the slab away (%.2f m)" % moved, moved > 0.6)


func _case_conservation(pulper: HayPulper) -> void:
	print("\n=== conservation ===")
	var before:= _count("hay_pulp")
	var batch:= Tech.pulper_batch_strands() * 3
	var made:= await _feed(pulper, batch, 90.0, true)
	var fresh:= _count("hay_pulp") - before
	print("  fed %d more strands, %d more slabs" % [made, fresh])
	_check("three batches' worth of hay makes three slabs (%d)" % fresh,
		fresh == 3)
	_check("...and no more (%d)" % fresh, fresh <= 3)


	var rate:= float(Tech.pulper_batch_strands()) / Tech.pulper_cycle_seconds()
	print("  the card promises %.1f hay/s at %d strands every %.2f s"
		% [rate, Tech.pulper_batch_strands(), Tech.pulper_cycle_seconds()])
	_check("the promised rate beats a press's (%.1f against %.1f hay/s)"
		% [rate, float(Tech.compressor_bale_strands())
			/ Tech.compressor_press_seconds()],
		rate > float(Tech.compressor_bale_strands()) / Tech.compressor_press_seconds())


func _case_outfeed_blocked(pulper: HayPulper) -> void:
	print("\r\n=== the outfeed is blocked ===")
	var blocker: HayPulp = world.props.spawn("hay_pulp", Transform3D(
		pulper.global_basis, pulper.slab_spot() + Vector3.UP * 0.05)) as HayPulp
	_check("a slab can be stood on the outfeed by hand", blocker != null)
	if blocker == null:
		return


	blocker.freeze = true
	var before:= _count("hay_pulp")
	var batches_before:= pulper.slabs_made
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0
	var fed:= 0
	var next_in:= 0.0
	var want:= Tech.pulper_batch_strands()
	while elapsed < 25.0:
		await get_tree().physics_frame
		elapsed += step
		next_in -= step
		if fed < want and next_in <= 0.0:
			next_in = 0.06
			if _spawn_strand(pulper):
				fed += 1
		if pulper.alert_reason().begins_with("OUTFEED") and elapsed > 15.0:
			break
	print("  fed %d strands onto a blocked outfeed" % fed)
	_check("the machine holds rather than stacking one inside the other (%d)"
		% (_count("hay_pulp") - before), _count("hay_pulp") == before)
	_check("...and says so (%s)" % pulper.alert_reason(),
		pulper.alert_reason().begins_with("OUTFEED BLOCKED"))


	_check("...and the hay it committed is not spent twice (%d batch, %d held)"
		% [pulper.slabs_made - batches_before, pulper.stored],
		pulper.slabs_made - batches_before <= 1)


	var clip:= HayPulper._clip_name(pulper._door, HayPulper.CLIP_DOOR)
	if clip != "":
		pulper._door.play(clip)
		pulper._door.seek(0.0, true)
		for i in 3:
			await get_tree().physics_frame
		_check("...with the gate wound back open every tick (%.0f degrees)"
			% pulper.gate_angle_deg(),
			absf(pulper.gate_angle_deg()) > absf(HayPulper.GATE_OPEN_DEG) * 0.8)


		_check("...by a player that is still running, not paused",
			pulper._door.is_playing())


	world.props.remove(blocker)
	elapsed = 0.0
	while elapsed < 20.0:
		await get_tree().physics_frame
		elapsed += step
		if _count("hay_pulp") > before - 1:
			break
	_check("clearing the outfeed lets the held slab down (%d)"
		% (_count("hay_pulp") - (before - 1)), _count("hay_pulp") >= before)

	elapsed = 0.0
	while elapsed < 12.0:
		await get_tree().physics_frame
		elapsed += step
		if not pulper.is_running() and absf(pulper.gate_angle_deg()) < 3.0:
			break
	_check("...and the gate closes again afterwards (%.1f)"
		% pulper.gate_angle_deg(), absf(pulper.gate_angle_deg()) < 3.0)


func _case_dead(pulper: HayPulper) -> void:
	print("\n=== no power ===")
	world.builds.grid.unmetered = false
	world.builds.grid.rebuild()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("a metered yard with no pole leaves it dead (%.2f)" % pulper.power,
		is_zero_approx(pulper.power))


	_check("...and the well dies with it, so the main empties too (%.2f)"
		% pulper.water, is_zero_approx(pulper.water))
	_check("...while the pipe is still on its flange", not pulper.water_blocked
		and bool((world.builds.water as WaterGrid).report(pulper) ["connected"]))
	_check("...so `drive` is zero (%.2f)" % pulper.drive(),
		is_zero_approx(pulper.drive()))


	_check("...and the sign is the bolt, not the drop",
		pulper.alert_icon() == "power")
	_check("...naming the pole (%s)" % pulper.alert_reason(),
		pulper.alert_reason().begins_with("NO POWER"))

	var before:= _count("hay_pulp")
	var made:= await _feed(pulper, Tech.pulper_batch_strands() * 2, 12.0)
	await _settle_intake(pulper)
	print("  fed %d strands to a dead pulper" % made)
	_check("a dead pulper makes no slabs (%d)" % (_count("hay_pulp") - before),
		_count("hay_pulp") == before)
	_check("...and does not spend the hay it swallowed (%d held)" % pulper.stored,
		pulper.stored >= Tech.pulper_batch_strands())

	world.builds.grid.unmetered = true
	world.builds.grid.rebuild()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("switching the harness meter back off restores it (%.2f)"
		% pulper.power, pulper.power > 0.999)


func _case_the_save(pulper: HayPulper) -> void:
	print("\n=== the save ===")


	var feeder: Conveyor = world.builds.feed_run_into(pulper.port_in())
	if feeder != null:
		world.builds.demolish(feeder)
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0
	while elapsed < 20.0:
		await get_tree().physics_frame
		elapsed += step
		if pulper.deck().riders().is_empty() and not pulper.is_running():
			break
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the line behind it is drained (%d on the stub)"
		% pulper.deck().riders().size(), pulper.deck().riders().is_empty())
	pulper.stored = 41
	var port_was:= pulper.port_in()
	var row:= pulper.to_dict()
	_check("the save names the type", row.get("type", "") == "hay_pulper")
	_check("the save carries the buffer (%d)" % int(row.get("stored", -1)),
		int(row.get("stored", -1)) == 41)
	var rows: Array = world.builds.to_array()
	world.builds.from_array(rows)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var back: HayPulper = world.builds.pulpers [0] if not world.builds.pulpers.is_empty() else null
	_check("the pulper came back", back != null)
	_check("...with its buffer (%d)" % (back.stored if back != null else -1),
		back != null and back.stored == 41)
	_check("...and its ports where they were",
		back != null and back.port_in().distance_to(port_was) < 0.02)


	var net: WaterGrid = world.builds.water
	_check("...still plumbed onto the same network",
		back != null and bool(net.report(back) ["connected"])
		and not back.water_blocked)
	_check("...and wet again (%.2f)" % (back.water if back != null else -1.0),
		back != null and back.water > 0.999)
	_check("...with the cover still off", back != null and not _cover_visible(back))

	print("\n=== the dismantle ===")
	if back != null:
		back.stored = 0
		var refund: float = world.builds.demolish(back)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame


		_check("it comes down for its own price ($%.0f)" % refund,
			is_equal_approx(refund, Cfg.PULPER_COST))
		_check("...leaving none in the fleet", world.builds.pulpers.is_empty())


		_check("...and the main it was on is still there",
			not world.builds.water_mains.is_empty())


func _on_slabbed(slab: Node3D) -> void:
	if slab != null and is_instance_valid(slab):
		_last_drop = slab.global_position


func _cover_visible(pulper: HayPulper) -> bool:
	var cover:= pulper._find(HayPulper.N_COVER) as Node3D
	return cover != null and cover.visible


func _pour_flow_of(pulper: HayPulper) -> float:
	return pulper.pour_flow_uv().y


func _mash_surface(level: MeshInstance3D) -> int:
	if level == null or level.mesh == null:
		return 0
	for i in level.mesh.get_surface_count():
		var mat:= level.get_surface_override_material(i)
		if mat != null and mat.resource_name == HayPulper.MAT_SLURRY:
			return level.mesh.surface_get_arrays(i) [Mesh.ARRAY_VERTEX].size()
	return 0


func _bath_fill_of(pulper: HayPulper) -> float:
	if pulper._wave_mat == null:
		return 0.0
	return pulper.wave_fill()


func _wave_flow_of(pulper: HayPulper) -> float:
	if pulper._wave_mat == null:
		return 0.0
	return pulper.wave_flow()


func _spawn_strand(pulper: HayPulper) -> bool:
	var at:= pulper.port_in() - pulper.forward() * 1.6 + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.0)
	return world.live.spawn(at, StrandFactory.random_strand_basis(_rng),
		Vector3.ZERO, Cfg.COL_HAY_LIGHT) != null


func _feed(pulper: HayPulper, want: int, timeout: float,
		until_idle: bool = false) -> int:
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0
	var fed:= 0
	var next_in:= 0.0
	while elapsed < timeout:
		await get_tree().physics_frame
		elapsed += step
		next_in -= step
		if fed < want and next_in <= 0.0:
			next_in = 0.06
			if _spawn_strand(pulper):
				fed += 1
		if fed >= want and until_idle and not pulper.is_running() and pulper.stored < Tech.pulper_batch_strands() and pulper.starved_for > INTAKE_QUIET:
			break
	return fed


const INTAKE_QUIET:= 0.5


func _settle_intake(pulper: HayPulper, timeout: float = 12.0) -> void:
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var elapsed:= 0.0
	while elapsed < timeout and pulper.starved_for <= INTAKE_QUIET:
		await get_tree().physics_frame
		elapsed += step


func _slabs() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is HayPulp:
			out.append(item)
	return out


func _count(id: String) -> int:
	var n:= 0
	for item in world.props.items:
		if is_instance_valid(item) and item.is_inside_tree() and item.item_id == id:
			n += 1
	return n + _records_of(id).size()


func _records_of(id: String) -> Array:
	var out: Array = []
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:
				out.append(run.seq_of(i))
	return out


func _newest_seq_of(id: String) -> int:
	var best:= -1
	for seq: int in _records_of(id):
		best = maxi(best, seq)
	return best


func _slab_origin(seq: int, slab: HayPulp) -> Variant:
	if seq >= 0:
		var where:= BeltPath.record_where(seq)
		if not where.is_empty():
			return (where ["pose"] as Transform3D).origin
	if slab != null and is_instance_valid(slab) and slab.is_inside_tree():
		return slab.global_position
	return null


var _last_pushed_seq:= -1
func _on_slabbed_record(seq: int) -> void:
	_last_pushed_seq = seq
	var where:= BeltPath.record_where(seq)
	if not where.is_empty():
		_last_drop = (where ["pose"] as Transform3D).origin


func _materialize(seq: int) -> Carryable:
	var where:= BeltPath.record_where(seq)
	if where.is_empty():
		return null
	return (where ["path"] as BeltPath).materialize_record(int(where ["row"]))


func _worst_reach(charge: MeshInstance3D, fill: float) -> float:
	if charge == null or charge.mesh == null:
		return 0.0
	var box:= charge.mesh.get_aabb()
	var r:= box.size.x * 0.5
	var rise:= box.size.y
	if r <= 0.0001 or rise <= 0.0001:
		return 0.0
	var wy:= rise * clampf(fill, 0.0, 1.0)
	var rim:= _bore_half(r, rise, wy)


	var worst:= 0.0
	for i in charge.mesh.get_surface_count():
		var mat:= charge.get_surface_override_material(i)
		if mat == null or mat.resource_name != HayPulper.MAT_SLURRY:
			continue
		var arrays:= charge.mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
		for v in verts:
			var x:= v.x
			var y:= v.y

			if y > wy:
				x *= rim / maxf(_bore_half(r, rise, y), 0.0001)
				y = wy


			x *= charge.scale.x
			var dy:= (y - rise) * charge.scale.y
			worst = maxf(worst, sqrt(x * x / (r * r) + dy * dy / (rise * rise)))
	return worst


func _bore_half(r: float, rise: float, h: float) -> float:
	var dy:= clampf(h, 0.0, rise) - rise
	return r * sqrt(maxf(1.0 - (dy * dy) / (rise * rise), 0.0))


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
