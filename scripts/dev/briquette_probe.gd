class_name DevBriquetteProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const LANE_X:= 22.0


const _MATERIAL: Array [String] = [
	BriquettePress.N_CLIP_SPOUT, BriquettePress.N_CLIP_FALL,
	BriquettePress.N_CLIP_MILL_BED, BriquettePress.N_CLIP_CHAFF,
	BriquettePress.N_CLIP_GRIND_BED, BriquettePress.N_CLIP_GRIND_TURN,
	BriquettePress.N_CLIP_CHARGE, BriquettePress.N_CLIP_DISC,
]

var _pass:= 0
var _fail:= 0


var _last_drop:= Vector3.INF
var _discs_seen:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(LANE_X - 8.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	var press: BriquettePress = world.builds.add_briquette(
		Vector3(LANE_X, 0.0, 0.0), 0.0)
	press.pressed.connect(_on_pressed)
	press.pressed_record.connect(_on_pressed_record)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	await _case_the_model(press)
	await _case_the_clips(press)
	await _case_the_geometry(press)
	await _case_the_hologram(press)
	await _case_open_floor(press)
	await _case_snapping(press)
	await _case_the_two_infeeds(press)
	await _case_wads_go_in(press)
	await _case_bricks_go_in(press)
	await _case_the_wrong_arm(press)
	await _case_one_disc(press)
	await _case_conservation(press)
	await _case_brick_size(press)
	await _case_a_bare_needle(press)
	await _case_it_refuses_its_own(press)
	await _case_the_starve_read(press)
	await _case_the_machinery_moves(press)
	await _case_the_material_moves(press)
	await _case_the_disc_rides(press)
	await _case_outfeed_blocked(press)
	await _case_dead(press)
	await _case_the_save(press)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_model(press: BriquettePress) -> void:
	print("\n=== the model ===")
	var model:= press.get_node_or_null("Model")
	_check("the press has a model", model != null)
	if model == null:
		return
	for marker: String in [BriquettePress.N_PORT_WAD, BriquettePress.N_PORT_BRICK,
			BriquettePress.N_PORT_DISC]:
		_check("...and a '%s' empty on it" % marker,
			model.find_child(marker, true, false) != null)


	for node_name: String in _MATERIAL:
		_check("...and a '%s' for the clip to drive" % node_name,
			model.find_child(node_name, true, false) != null)


	var shown:= model.find_child(BriquettePress.N_CLIP_DISC, true, false) as MeshInstance3D
	_check("the disc the press forms wears the shipped feed disc mesh",
		shown != null and shown.mesh != null and shown.mesh == FeedDisc.shared_mesh())


	var heap:= model.find_child(BriquettePress.N_CLIP_CHARGE, true, false) as MeshInstance3D
	var grained:= 0
	var flat:= 0
	if heap != null and heap.mesh != null:
		for i in heap.mesh.get_surface_count():
			var imported:= heap.mesh.surface_get_material(i).resource_name
			if not BriquettePress.CHARGE_WEARS.has(imported):
				continue
			var worn:= heap.get_active_material(i) as BaseMaterial3D
			if worn != null and worn.albedo_texture != null and worn.uv1_triplanar:
				grained += 1
			else:
				flat += 1
	_check("the heap's pellets wear the disc's grain (%d grained, %d still flat)"
		% [grained, flat], grained > 0 and flat == 0)


	for arm: String in ["Belt_BaleInput_Mesh", "Belt_HayInput_Mesh",
			"Belt_CakeOutput_Mesh"]:
		_check("the game model carries no modelled '%s'" % arm,
			model.find_child(arm, true, false) == null)


	for node_name: String in _MATERIAL:
		_check("an idle press shows no '%s'" % node_name,
			not _visible(model, node_name))
	var ports:= press.power_ports()
	_check("it offers two wire terminals, got %d" % ports.size(),
		ports.size() == 2)


	var hud: Hud = world.hud
	if hud != null:
		var line:= hud._machine_diagnostic(press)
		_check("the crosshair row names the machine ('%s')" % line,
			line.contains("FEED DISC PRESS"))
		_check("...and counts BOTH buffers on it, because either can be the one that is empty",
			line.contains("hay") and line.contains("bricks"))
		_check("...and says what a disc is worth",
			line.contains("x%.2f" % Tech.disc_value_ratio()))


	var card: Dictionary = BuildCatalog.entries().get("briquette_press", { })
	_check("the build catalogue carries a card for it", not card.is_empty())
	if not card.is_empty():
		_check("...naming the machine ('%s')" % str(card.get("name", "")),
			str(card.get("name", "")) != "")
		_check("...pointing at the press's own build mode",
			int(card.get("mode", -1)) == BuildTool.Mode.BRIQUETTE)


		var blurb:= str(card.get("blurb", ""))
		_check("...and warning about BOTH belts before the money is spent",
			blurb.contains("one belt") and blurb.contains("another"))
		_check("...and about the footprint, which is the paper mill's courtesy",
			blurb.contains("m long"))


		_check("...and the note tells the player to lay the side arm afterwards",
			str(card.get("note", "")).contains("second belt"))


		_check("...and says a brick of any size counts as one",
			blurb.contains("Any size of brick counts as one brick"))
	_check("the Feed Disc Press tech card says a brick of any size counts as one",
		TechTree.blurb("briquette_press").contains("Any size of brick counts as one brick"))
	_check("the Bigger Brick Die card says it makes a feed disc worth more",
		TechTree.blurb("pellet_batch").contains("feed disc still takes %d bricks"
			% Tech.briquette_batch_bricks()))
	if hud != null:
		var product:= hud._machine_product(press)
		_check("the recipe row says how big a brick is today ('%s')" % product,
			product.contains("(%d strands each)" % Tech.pellet_brick_strands()))


func _case_the_clips(press: BriquettePress) -> void:
	print("\n=== the three clips ===")
	var seconds:= press.clip_seconds()
	_check("the model ships a '%s' clip" % BriquettePress.CLIP_PRESS, seconds > 0.0)


	_check("...%.3f s long, and Cfg.BRIQUETTE_CYCLE_SECONDS says %.3f"
		% [seconds, Cfg.BRIQUETTE_CYCLE_SECONDS],
		absf(seconds - Cfg.BRIQUETTE_CYCLE_SECONDS) < 0.02)
	_check("...which is %.0f frames at %.0f fps"
		% [BriquettePress.CYCLE_FRAMES, BriquettePress.CLIP_FPS],
		absf(Cfg.BRIQUETTE_CYCLE_SECONDS
			- BriquettePress.CYCLE_FRAMES / BriquettePress.CLIP_FPS) < 0.001)


	_check("the release frame %.0f is inside the clip" % BriquettePress.F_RELEASE,
		BriquettePress.F_RELEASE > 0.0
			and BriquettePress.F_RELEASE < BriquettePress.CYCLE_FRAMES)
	_check("...and after the dwell rather than during the squeeze",
		BriquettePress.F_RELEASE > BriquettePress.CYCLE_FRAMES * 0.5)


	_check("the mill turns on a clip of its own, so the two sides stop separately",
		press.mill_has_own_clip())


func _case_the_geometry(press: BriquettePress) -> void:
	print("\n=== the geometry ===")
	var wad:= press.port_wad()
	var brick:= press.port_brick()
	var disc:= press.port_out()
	var feet:= press.global_position.y


	for named: Array in [["wad", wad], ["brick", brick], ["disc", disc]]:
		var at: Vector3 = named [1]
		_check("the %s port stands %.3f m over the feet, want %.2f"
			% [named [0], at.y - feet, Cfg.BRIQUETTE_PORT_UP],
			absf(at.y - feet - Cfg.BRIQUETTE_PORT_UP) < 0.02)


	var inline:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	_check("...which is deliberately not the inline modules' %.2f" % inline,
		absf(Cfg.BRIQUETTE_PORT_UP - inline) > 0.2)


	var span:= brick.distance_to(disc)
	var spine:= Cfg.BRIQUETTE_LENGTH + float(press.port_reach [BriquettePress.REACH_BRICK]) + float(press.port_reach [BriquettePress.REACH_DISC])
	_check("the spine is %.2f m, and Cfg.BRIQUETTE_LENGTH and the reach say %.2f"
		% [span, spine], absf(span - spine) < 0.02)


	var across:= press.bearing_at(wad)
	var along:= press.bearing_at(brick)
	_check("the wad arm's bearing is a quarter turn off the spine (%.2f)"
		% across.dot(along), absf(across.dot(along)) < 0.02)
	_check("...and the disc port runs the same way as the brick port",
		press.bearing_at(disc).dot(along) > 0.98)
	_check("...and a point that is no port at all answers with nothing",
		press.bearing_at(press.global_position) == Vector3.ZERO)


	_check("the press lays a wad belt", press.wad_deck() != null)
	_check("...a brick belt", press.brick_deck() != null)
	_check("...and a disc belt", press.outfeed_deck() != null)
	_check("...and all three are different paths",
		press.wad_deck() != press.brick_deck()
			and press.brick_deck() != press.outfeed_deck()
			and press.wad_deck() != press.outfeed_deck())


	_check("...and deck() answers with an infeed, never the outfeed",
		press.deck() == press.wad_deck())


	var spot:= press.disc_spot()
	_check("a finished disc rests on the deck (%.3f over the feet)"
		% (spot.y - feet), absf(spot.y - feet - Cfg.BRIQUETTE_PORT_UP) < 0.03)
	var into:= press.to_local(spot).z
	_check("...at %.2f m, which is past the outfeed belt's start at %.2f"
		% [into, BriquettePress.DISC_HEAD_Z],
		into > BriquettePress.DISC_HEAD_Z + Cfg.FEED_DISC_SIZE.z * 0.5 - 0.05)
	_check("...and well short of the port it rides out of (%.2f)"
		% Cfg.BRIQUETTE_PORT_DISC, into < Cfg.BRIQUETTE_PORT_DISC - 0.5)


func _case_the_hologram(press: BriquettePress) -> void:
	print("\n=== the hologram ===")
	var ghost:= BriquettePress.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = Vector3(LANE_X, 0.0, -26.0)
	for i in 10:
		await get_tree().process_frame
	_check("a preview press builds without belts of its own",
		ghost.wad_deck() == null and ghost.brick_deck() == null
			and ghost.outfeed_deck() == null)
	_check("...and shows no pellets in its spout",
		not _visible(ghost.get_node_or_null("Model"), BriquettePress.N_CLIP_SPOUT))


	_check("...and draws its own arms, so the T reads before it is bought",
		ghost.get_node_or_null("GhostBelt") != null)


	var arms: Array [Array] = ghost._ghost_arms()
	var names:= ["wad infeed", "brick infeed", "disc outfeed"]
	for i in arms.size():
		var from: Vector3 = arms [i] [0]
		var to: Vector3 = arms [i] [1]
		var travel:= (to - from).normalized()
		var point:= BriquettePress.chevron_basis(from, to).z.normalized()
		var flat:= Vector3(1.0, 0.0, 1.0)
		var inward:= (from * flat).length() > (to * flat).length()
		_check("the %s chevrons point the way they crawl (dot %.2f)"
			% [names [i], point.dot(travel)], point.dot(travel) > 0.99)
		_check("...and that way is %s the press"
			% ["out of" if i == 2 else "into"], inward == (i != 2))


	var shared:= HayCompressor.materials_shared()


	var road: MeshInstance3D = null
	var road_at:= -1
	var road_src: Material = null
	for piece: Array in BriquettePress.ROAD_PIECES:
		var m:= press._road_mesh(str(piece [0]))
		if m == null or m.mesh == null or road != null:
			continue
		for i in m.mesh.get_surface_count():
			var worn_now:= m.get_surface_override_material(i)
			if worn_now != null and worn_now.resource_name.ends_with("_Road"):
				road = m
				road_at = i
				road_src = m.mesh.surface_get_material(i)
				var skinned:= BriquettePress._override_for(road_src.resource_name)
				if skinned != null:
					road_src = skinned
				break
	var twin:= BriquettePress._road_material(road_src)
	_check("a road twin is %s material every press asks for" % ("one" if shared else "a new"),
		twin != null and (twin == BriquettePress._road_material(road_src)) == shared)
	_check("...and the placed press wears %s" % ("that one" if shared else "its own"),
		twin != null and (road.get_surface_override_material(road_at) == twin) == shared)
	var fit_a: Dictionary = BriquettePress._fitting_materials()
	var fit_b: Dictionary = BriquettePress._fitting_materials()
	_check("the wire fittings are %s" % ("shared" if shared else "built per press"),
		fit_a.has("steel") and (fit_a ["steel"] == fit_b ["steel"]) == shared)
	ghost.set_preview_valid(false)
	ghost.set_preview_valid(true)
	_check("...and takes both ghost colours without complaint", true)
	world.remove_child(ghost)
	ghost.queue_free()


func _case_open_floor(press: BriquettePress) -> void:
	print("\n=== the hologram on open floor ===")
	var tool: BuildTool = player.build


	var origin:= press.global_position + Vector3(0.0, 0.0, 8.0)
	var fwd:= Vector3.BACK


	var down:= PhysicsRayQueryParameters3D.create(origin + Vector3.UP,
		origin - Vector3.UP)
	down.collision_mask = Cfg.L_WORLD
	var floor_hit:= player.get_world_3d().direct_space_state.intersect_ray(down)
	_check("there is floor under the spot to stand it on",
		not floor_hit.is_empty() and absf((floor_hit ["position"] as Vector3).y - origin.y) < 0.01)
	var e: Dictionary = tool._evaluate_briquette(origin, fwd, Vector3.UP, false)
	_check("bare floor is a place it can go (%s)" % e ["reason"], bool(e ["ok"]))
	var level:= true
	for dy: float in [-0.004, -0.001, 0.001, 0.004]:
		var shifted:= tool._evaluate_briquette(origin + Vector3.UP * dy, fwd,
			Vector3.UP, false) as Dictionary
		level = level and bool(shifted ["ok"])
	_check("...and a few millimetres of floor either way does not change that", level)

	var wad:= press.port_wad() - press.global_position
	var crate:= _crate(origin + Vector3(wad.x * 0.8, 0.25, wad.z))
	await get_tree().physics_frame
	e = tool._evaluate_briquette(origin, fwd, Vector3.UP, false)
	_check("a knee high crate across the side arm is seen (%s)" % e ["reason"],
		not bool(e ["ok"]) and str(e ["reason"]) == "the side input is blocked")
	crate.global_position = origin + Vector3(0.0, 0.25, -1.0)
	await get_tree().physics_frame
	e = tool._evaluate_briquette(origin, fwd, Vector3.UP, false)
	_check("...and one on the spine is too (%s)" % e ["reason"],
		not bool(e ["ok"]) and str(e ["reason"]) == "blocked")
	crate.queue_free()
	await get_tree().physics_frame


	player.set_look(PI, -0.5)
	tool.set_mode(BuildTool.Mode.BRIQUETTE)
	tool.set_active(true)
	tool._ghost_turn = 2
	var verdicts:= { }
	for i in 30:
		await get_tree().physics_frame
		await get_tree().process_frame
		verdicts ["%s %s" % [tool._eval ["ok"], tool._eval ["reason"]]] = true
	_check("held still over bare floor it says one thing, and that is yes (%s)"
		% ", ".join(verdicts.keys()), verdicts.size() == 1 and verdicts.has("true "))
	tool._ghost_turn = 0
	tool.set_active(false)


func _crate(at: Vector3) -> StaticBody3D:
	var body:= StaticBody3D.new()
	body.collision_layer = Cfg.L_WORLD
	body.collision_mask = 0
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	cs.shape = box
	body.add_child(cs)
	world.add_child(body)
	body.global_position = at
	return body


func _case_snapping(press: BriquettePress) -> void:
	print("\n=== snapping, three ports ===")
	var builds: BuildManager = world.builds
	for named: Array in [["wad", press.port_wad()], ["brick", press.port_brick()],
			["disc", press.port_out()]]:
		var want: Vector3 = named [1]
		var near:= want + Vector3(0.0, 0.15, 0.0)
		var got: Vector3 = builds.snap_briquette_port(near)
		_check("a point near the %s port snaps to it" % named [0],
			got.distance_to(want) < 0.01)


		var endpoint: Vector3 = builds.snap_endpoint(near)
		_check("...and so does the endpoint walk every belt route uses",
			endpoint.distance_to(want) < 0.01)

		_check("...and the yard knows which way hay travels there",
			builds.port_bearing_at(want).dot(press.bearing_at(want)) > 0.98)
	var far:= press.port_wad() + Vector3(0.0, 0.0, 9.0)
	_check("a point well clear of all three is left alone",
		builds.snap_briquette_port(far).distance_to(far) < 0.001)
	_check("a press placed on top of this one is refused",
		builds.briquette_overlap(press.global_position + Vector3(1.0, 0.0, 0.0)))
	_check("...and one a full length clear is allowed",
		not builds.briquette_overlap(press.global_position
			+ Vector3(0.0, 0.0, Cfg.BRIQUETTE_LENGTH + 1.0)))


	var span:= Cfg.BRIQUETTE_HALF_WIDTH * 2.0
	_check("a press abreast of this one, inside its width, is refused",
		builds.briquette_overlap(press.global_position
			+ Vector3(span - 0.4, 0.0, 0.0)))
	_check("...and one just clear of the width is allowed, though it is well "
		+ "inside a full length",
		not builds.briquette_overlap(press.global_position
			+ Vector3(span + 0.2, 0.0, 0.0)))


	var mill: PaperMachine = world.builds.add_paper(
		Vector3(LANE_X, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, -18.0), 0.0)
	await _settle()


	var behind:= Cfg.BRIQUETTE_PORT_BRICK + Cfg.PAPER_LENGTH * 0.5
	var ahead:= Cfg.BRIQUETTE_PORT_DISC + Cfg.PAPER_LENGTH * 0.5
	_check("a press whose brick arm reaches into a paper mill is refused",
		builds.briquette_overlap(mill.global_position
			+ Vector3(0.0, 0.0, behind - 0.5)))
	_check("...and one whose arm stops short of it is allowed",
		not builds.briquette_overlap(mill.global_position
			+ Vector3(0.0, 0.0, behind + 0.5)))
	_check("...and the short end needs %.2f m less, not the same" % (behind - ahead),
		not builds.briquette_overlap(mill.global_position
			+ Vector3(0.0, 0.0, - (ahead + 0.5))))
	_check("a paper mill inside a press's own reach is refused too",
		builds.paper_overlap(press.global_position + Vector3(0.0, 0.0, ahead - 0.5)))
	builds.demolish(mill)
	await _settle()


func _case_the_two_infeeds(press: BriquettePress) -> void:
	print("\n=== two runs in, one out ===")
	var builds: BuildManager = world.builds
	var wad_port:= press.port_wad()
	var brick_port:= press.port_brick()
	var disc_port:= press.port_out()
	var hay_run: Conveyor = builds.add_conveyor(
		wad_port - press.bearing_at(wad_port) * 4.0, wad_port)
	var brick_run: Conveyor = builds.add_conveyor(
		brick_port - press.bearing_at(brick_port) * 4.0, brick_port)
	var away: Conveyor = builds.add_conveyor(
		disc_port, disc_port + press.bearing_at(disc_port) * 4.0)
	await _settle()
	_check("a run laid to the wad port exists", hay_run != null)
	_check("a run laid to the brick port exists", brick_run != null)
	_check("a run laid off the disc port exists", away != null)
	_check("the wad run hands its load to the WAD belt",
		hay_run != null and hay_run.downstream == press.wad_deck())
	_check("the brick run hands its load to the BRICK belt",
		brick_run != null and brick_run.downstream == press.brick_deck())

	_check("...and neither of them to the other's",
		hay_run != null and brick_run != null
			and hay_run.downstream != brick_run.downstream)


	_check("the disc belt feeds the run leaving the machine",
		press.outfeed_deck() != null and press.outfeed_deck().downstream == away)
	_check("...and neither infeed does",
		press.wad_deck().downstream != away and press.brick_deck().downstream != away)


	_check("the run beyond reserves the square the disc lands on",
		away != null and away.head_reserve() > 0.0)
	builds.demolish(hay_run)
	builds.demolish(brick_run)
	builds.demolish(away)
	await _settle()


func _case_wads_go_in(press: BriquettePress) -> void:
	print("\n=== hay goes in on the wad arm ===")
	_reset(press)
	var wad:= _drop_wad(press, 40, 7)
	_check("a wad was spawned at the grinder", wad != null)
	await _wait_for(func() -> bool: return press.stored_strands >= 40, 8.0)
	_check("...and the press swallowed it (%d strands)" % press.stored_strands,
		press.stored_strands >= 40)
	_check("...and the needle that was inside it went with it (%s)"
		% str(Array(press.pending_needles)),
		Array(press.pending_needles).has(7))
	_check("...and the wad itself is gone off the deck",
		wad == null or not is_instance_valid(wad))


	var cap:= press.strand_capacity()
	for i in 12:
		_drop_wad(press, Cfg.WAD_MAX_STRANDS, -1)
		await _settle(6)
	await _settle(30)
	_check("the hay buffer stops within a wad of its capacity (%d/%d)"
		% [press.stored_strands, cap],
		press.stored_strands <= cap + Cfg.WAD_MAX_STRANDS)
	_check("...and does stop, rather than taking everything offered (%d)"
		% press.stored_strands,
		press.stored_strands < cap + Cfg.WAD_MAX_STRANDS * 2)
	_reset(press)


func _case_bricks_go_in(press: BriquettePress) -> void:
	print("\n=== eco bricks go in on the brick arm ===")
	_reset(press)
	var brick:= _drop_brick(press, 5)
	_check("a brick was spawned at the mill feed", brick != null)
	await _wait_for(func() -> bool: return press.stored_bricks >= 1, 8.0)
	_check("...and the press swallowed it (%d bricks)" % press.stored_bricks,
		press.stored_bricks >= 1)
	_check("...and the needle that was inside it went with it (%s)"
		% str(Array(press.pending_needles)),
		Array(press.pending_needles).has(5))
	_check("...and the brick itself is gone off the deck",
		brick == null or not is_instance_valid(brick))
	var cap:= press.brick_capacity()
	for i in cap + 4:
		_drop_brick(press, -1)
		await _settle(6)
	await _settle(30)
	_check("the brick buffer never grows past its capacity (%d/%d)"
		% [press.stored_bricks, cap], press.stored_bricks <= cap)
	_reset(press)


func _case_the_wrong_arm(press: BriquettePress) -> void:
	print("\n=== each arm eats its own ===")
	_reset(press)


	var brick:= world.props.spawn("eco_brick",
		Transform3D(Basis(), _wad_mouth(press))) as EcoBrick
	_check("an eco brick was stood at the grinder", brick != null)
	await _settle(60)
	_check("...and the grinder did not swallow it (%d bricks, %d strands)"
		% [press.stored_bricks, press.stored_strands],
		press.stored_bricks == 0 and press.stored_strands == 0)

	_clear_kind("eco_brick")
	await _settle()


	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), _brick_mouth(press)), { "strands": 30 }) as HayWad
	_check("a hay wad was stood at the mill feed", wad != null)
	await _settle(60)
	_check("...and the mill did not swallow it (%d strands)"
		% press.stored_strands, press.stored_strands == 0)
	_clear_kind("hay_wad")
	_reset(press)


func _case_one_disc(press: BriquettePress) -> void:
	print("\n=== one charge, one disc ===")
	_reset(press)
	_discs_seen = 0


	press.stored_strands = Tech.briquette_batch_strands() * 2
	await _settle(60)
	_check("hay alone presses nothing (%d discs)" % _discs_seen, _discs_seen == 0)
	_check("...and the machine is not running", not press.is_running())
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool: return _discs_seen > 0,
		Cfg.BRIQUETTE_CYCLE_SECONDS * 3.0 + 8.0)
	_check("both together press one disc (%d)" % _discs_seen, _discs_seen == 1)
	if _last_drop != Vector3.INF:
		var want:= press.disc_spot()
		_check("...set down within 5 cm of the outfeed's head (%.3f m off)"
			% _last_drop.distance_to(want), _last_drop.distance_to(want) < 0.05)

	_check("...taking %d strands out of the hay buffer (%d left, want %d)"
		% [Tech.briquette_batch_strands(), press.stored_strands,
			Tech.briquette_batch_strands()],
		press.stored_strands == Tech.briquette_batch_strands())
	_check("...and every brick out of the brick buffer (%d left)"
		% press.stored_bricks, press.stored_bricks == 0)
	await _settle(60)
	_check("...and no second disc appears from the same charge (%d)" % _discs_seen,
		_discs_seen == 1)
	_reset(press)


func _case_brick_size(press: BriquettePress) -> void:
	print("\n=== a brick of any size is one brick ===")
	_reset(press)
	_clear_discs()
	_discs_seen = 0
	var sizes:= [60, 100]
	for s: int in sizes:
		_drop_brick(press, -1, s)
		await _settle(6)
	await _wait_for(func() -> bool: return press.stored_bricks >= 2, 8.0)
	_check("bricks of %d and %d straw count as two bricks (%d)"
		% [sizes [0], sizes [1], press.stored_bricks], press.stored_bricks == 2)
	_check("...and the press remembers what is in each (%s)"
		% str(Array(press.brick_hay)), Array(press.brick_hay) == sizes)
	press.stored_strands = Tech.briquette_batch_strands()
	await _wait_for(func() -> bool: return _discs_seen > 0,
		Cfg.BRIQUETTE_CYCLE_SECONDS * 3.0 + 8.0)
	_check("they press one disc between them (%d)" % _discs_seen, _discs_seen == 1)
	var made:= _discs_in_hand()
	if made.is_empty():
		_reset(press)
		return
	var disc: FeedDisc = made [0]
	var want: int = Tech.briquette_batch_strands() + int(sizes [0]) + int(sizes [1])
	var at_die: int = Tech.briquette_batch_strands() + Tech.briquette_batch_bricks() * Tech.pellet_brick_strands()
	_check("...holding the hay those bricks really had (%d, want %d, the die alone would say %d)"
		% [disc.strands, want, at_die], disc.strands == want)
	_check("...and nothing is left on the list (%s)" % str(Array(press.brick_hay)),
		press.brick_hay.is_empty())
	_clear_discs()
	_reset(press)


func _case_conservation(press: BriquettePress) -> void:
	print("\n=== both halves travel through ===")
	_reset(press)
	_discs_seen = 0
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool: return _discs_seen > 0,
		Cfg.BRIQUETTE_CYCLE_SECONDS * 3.0 + 8.0)
	var made:= _discs_in_hand()
	_check("a disc came out", made.size() > 0)
	if made.is_empty():
		return
	var disc: FeedDisc = made [0]


	var want:= Tech.briquette_batch_strands() + Tech.briquette_batch_bricks() * Tech.pellet_brick_strands()
	_check("...holding %d strands, the loose batch AND the bricks' own (%d)"
		% [disc.strands, want], disc.strands == want)


	var brick_hay:= Tech.briquette_batch_bricks() * Tech.pellet_brick_strands()
	var loose:= want - brick_hay
	var worth:= float(loose) * Tech.disc_value_ratio() + float(brick_hay) * Tech.brick_value_ratio()
	_check("...worth %.1f: %d loose at x%.2f plus %d of brick at x%.2f"
		% [disc.sale_strands(), loose, Tech.disc_value_ratio(), brick_hay,
			Tech.brick_value_ratio()],
		absf(disc.sale_strands() - worth) < 0.01)
	_check("...and it remembers which %d of those strands came in as brick (%d)"
		% [brick_hay, disc.brick_hay], disc.brick_hay == brick_hay)
	_check("...while the hay actually in it is still %d (%d)"
		% [want, disc.hay_strands()], disc.hay_strands() == want)


	_check("...and the brick half is not paid the disc ratio",
		absf(disc.sale_strands() - float(want) * Tech.disc_value_ratio()) > 1.0)
	_check("...nor the two ratios multiplied",
		absf(disc.sale_strands()
			- float(want) * Tech.disc_value_ratio() * Tech.brick_value_ratio()) > 1.0)

	var held_rank:= Tech.rank_of("brick_quality")
	Tech.grant("brick_quality", TechTree.max_rank("brick_quality"))
	var better:= FeedDisc.new()
	better.strands = disc.strands
	better.brick_hay = disc.brick_hay
	better.brick_worth = float(disc.brick_hay) * Tech.brick_value_ratio()
	_check("...and five ranks of Raise Brick Quality lift a disc (%.1f -> %.1f)"
		% [disc.sale_strands(), better.sale_strands()],
		better.sale_strands() > disc.sale_strands() + 1.0)
	better.free()
	Tech.grant("brick_quality", held_rank)


	var roll:= Tech.pulp_value_ratio() * Tech.paper_value_ratio()
	_check("...and a disc still does not beat a paper roll (x%.2f against x%.2f)"
		% [Tech.disc_value_ratio(), roll], Tech.disc_value_ratio() < roll)
	_clear_discs()
	_reset(press)


func _case_a_bare_needle(press: BriquettePress) -> void:
	print("\n=== a bare needle on either arm ===")


	_reset(press)
	for arm: Array in [["the wad arm", _wad_mouth(press)],
			["the brick arm", _brick_mouth(press)]]:
		var at: Vector3 = (arm [1] as Vector3) + Vector3(0.0, 0.1, 0.0)
		var index:= GameState.register_needle(at, null, 0)
		GameState.needle_taken [index] = 1
		var needle: RigidBody3D = world.live.reveal_needle(index, at)
		_check("a needle was laid on %s" % arm [0], needle != null)
		if needle == null:
			continue
		await _wait_for(func() -> bool: return not is_instance_valid(needle), 6.0)
		_check("...and the press swallowed it", not is_instance_valid(needle))
		_check("...and is holding it for the next disc (%s)"
			% str(Array(press.pending_needles)),
			Array(press.pending_needles).has(index))


		_check("...without putting anything in either buffer (%d, %d)"
			% [press.stored_strands, press.stored_bricks],
			press.stored_strands == 0 and press.stored_bricks == 0)


	_discs_seen = 0
	_clear_discs()
	var held:= Array(press.pending_needles)
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool: return _discs_seen > 0,
		Cfg.BRIQUETTE_CYCLE_SECONDS * 3.0 + 8.0)
	var made:= _discs_in_hand()
	_check("a disc came out", made.size() > 0)
	if not made.is_empty():
		var disc: FeedDisc = made [0]
		_check("...carrying the needle that arrived on its own (%d)"
			% disc.needle_index, held.has(disc.needle_index))


		_check("...and exactly one, with the other still held (%d left)"
			% press.pending_needles.size(), press.pending_needles.size() == 1)


	press.pending_needles = PackedInt32Array([9, 11])
	var names:= Array(press.held_needles())
	_check("a press names every needle in it (%s)" % str(names),
		names.has(9) and names.has(11) and names.size() == 2)
	_clear_discs()
	_reset(press)


func _case_it_refuses_its_own(press: BriquettePress) -> void:
	print("\n=== it refuses its own product ===")
	_reset(press)


	var disc:= world.props.spawn("feed_disc",
		Transform3D(Basis(), _wad_mouth(press))) as FeedDisc
	_check("a feed disc was stood at the grinder", disc != null)
	await _settle(60)
	_check("...and the press did not swallow it (%d strands)"
		% press.stored_strands, press.stored_strands == 0)


	_check("...and it is still standing there to be picked up (%d in the world)"
		% _count("feed_disc"), _count("feed_disc") == 1)
	_clear_kind("feed_disc")
	_reset(press)


func _case_the_starve_read(press: BriquettePress) -> void:
	print("\n=== which belt has run dry ===")
	_reset(press)
	await _wait_roads_clear(press)

	press.stored_strands = Tech.briquette_batch_strands() * 3
	await _wait_for(func() -> bool: return press.grinder_spin() > 0.9,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)
	_check("with hay and no bricks the grinder turns (%.2f)" % press.grinder_spin(),
		press.grinder_spin() > 0.9)
	_check("...and the ring die stands still (%.2f)" % press.mill_spin(),
		press.mill_spin() < 0.05)
	_check("...and the sign names the belt that is empty ('%s')"
		% press.alert_reason(), press.alert_reason().begins_with("NO BRICKS"))


	var model:= press.get_node_or_null("Model")
	_check("...and no pellets are standing in the spout",
		not _visible(model, BriquettePress.N_CLIP_SPOUT))
	_check("...nor on the road in from the mill",
		not _visible(model, BriquettePress.N_CLIP_MILL_BED))
	_check("...while the rotors are throwing hay onto the bed",
		_visible(model, BriquettePress.N_CLIP_CHAFF)
			and _visible(model, BriquettePress.N_CLIP_GRIND_BED)
			and _visible(model, BriquettePress.N_CLIP_GRIND_TURN))


	_reset(press)


	await _wait_roads_clear(press)
	press.stored_bricks = Tech.briquette_batch_bricks() * 3
	await _wait_for(func() -> bool: return press.mill_spin() > 0.9,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)

	await _wait_for(func() -> bool: return press.road_arrived(BriquettePress.SIDE_MILL),
		press.road_seconds(BriquettePress.SIDE_MILL) + 1.0)
	_check("with bricks and no hay the ring die turns (%.2f)" % press.mill_spin(),
		press.mill_spin() > 0.9)
	_check("...and the grinder stands still (%.2f)" % press.grinder_spin(),
		press.grinder_spin() < 0.05)
	_check("...and the sign names the other belt ('%s')" % press.alert_reason(),
		press.alert_reason().begins_with("NO HAY"))
	model = press.get_node_or_null("Model")
	_check("...and the pellets are showing, because the mill is milling",
		_visible(model, BriquettePress.N_CLIP_SPOUT))
	_check("...all the way down the road to the die",
		_visible(model, BriquettePress.N_CLIP_MILL_BED))
	_check("...over a feed bed with no hay on it at all",
		not _visible(model, BriquettePress.N_CLIP_CHAFF)
			and not _visible(model, BriquettePress.N_CLIP_GRIND_BED)
			and not _visible(model, BriquettePress.N_CLIP_GRIND_TURN))


	_reset(press)
	await _settle(int(Cfg.MACHINE_STARVED_AFTER * 60.0) + 40)
	_check("with neither it says so once rather than naming one ('%s')"
		% press.alert_reason(), press.alert_reason().begins_with("NOT FED"))
	_check("...and both sides have coasted to a stop (%.2f, %.2f)"
		% [press.grinder_spin(), press.mill_spin()],
		press.grinder_spin() < 0.05 and press.mill_spin() < 0.05)


	_reset(press)
	press.stored_strands = Tech.briquette_batch_strands() * 3
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("...and a side that has just been fed is still winding up (%.2f)"
		% press.grinder_spin(), press.grinder_spin() < 0.5)
	_reset(press)


func _case_the_machinery_moves(press: BriquettePress) -> void:
	print("\n=== the machinery actually moves ===")
	var model:= press.get_node_or_null("Model")
	if model == null:
		_check("the press has a model to watch", false)
		return
	var ram:= model.find_child("Press_Ram", true, false) as Node3D
	var sleeve:= model.find_child("Forming_Sleeve", true, false) as Node3D
	var rotor:= model.find_child("GrinderRotor_0", true, false) as Node3D
	var die:= model.find_child("Mill_RingDie", true, false) as Node3D
	_check("the four pivots a player watches are all in the model",
		ram != null and sleeve != null and rotor != null and die != null)
	if ram == null or sleeve == null or rotor == null or die == null:
		return


	_reset(press)
	_discs_seen = 0
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool: return press.is_running(), 6.0)
	var ram_lo:= ram.position.y
	var ram_hi:= ram.position.y
	var sleeve_lo:= sleeve.position.y
	var sleeve_hi:= sleeve.position.y
	for i in int(Cfg.BRIQUETTE_CYCLE_SECONDS * 60.0) + 20:
		ram_lo = minf(ram_lo, ram.position.y)
		ram_hi = maxf(ram_hi, ram.position.y)
		sleeve_lo = minf(sleeve_lo, sleeve.position.y)
		sleeve_hi = maxf(sleeve_hi, sleeve.position.y)
		await get_tree().physics_frame


	_check("the ram travels its stroke while a disc is pressed (%.3f m)"
		% (ram_hi - ram_lo), ram_hi - ram_lo > 0.35)
	_check("...and the forming sleeve drops and lifts with it (%.3f m)"
		% (sleeve_hi - sleeve_lo), sleeve_hi - sleeve_lo > 0.28)


	_reset(press)
	press.stored_strands = Tech.briquette_batch_strands() * 3
	await _wait_for(func() -> bool: return press.grinder_spin() > 0.9,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)
	var rotor_was:= rotor.rotation
	var die_was:= die.rotation
	await _settle(30)
	_check("the grinder rotor is turning while it has hay (%.3f rad)"
		% rotor.rotation.distance_to(rotor_was),
		rotor.rotation.distance_to(rotor_was) > 0.2)

	_check("...and the ring die is standing still beside it (%.4f rad)"
		% die.rotation.distance_to(die_was),
		die.rotation.distance_to(die_was) < 0.001)


	_reset(press)
	await _wait_for(func() -> bool: return press.grinder_spin() < 0.01,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)
	press.stored_bricks = Tech.briquette_batch_bricks() * 3
	await _wait_for(func() -> bool: return press.mill_spin() > 0.9,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)
	rotor_was = rotor.rotation
	die_was = die.rotation
	await _settle(30)
	_check("the ring die is turning while it has bricks (%.3f rad)"
		% die.rotation.distance_to(die_was),
		die.rotation.distance_to(die_was) > 0.2)
	_check("...and the grinder rotor is standing still beside it (%.4f rad)"
		% rotor.rotation.distance_to(rotor_was),
		rotor.rotation.distance_to(rotor_was) < 0.001)
	_clear_discs()
	_reset(press)


func _case_the_material_moves(press: BriquettePress) -> void:
	print("\n=== the material actually moves ===")
	var model:= press.get_node_or_null("Model")
	if model == null:
		_check("the press has a model to watch", false)
		return
	var bed:= model.find_child(BriquettePress.N_CLIP_GRIND_BED, true, false) as Node3D
	var charge:= model.find_child(BriquettePress.N_CLIP_CHARGE, true, false) as Node3D
	if bed == null or charge == null:
		_check("the model carries its hay bed and its charge", false)
		return


	_reset(press)
	await _wait_roads_clear(press)
	press.stored_strands = Tech.briquette_batch_strands() * 3
	await _wait_for(func() -> bool: return press.grinder_spin() > 0.9,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)
	var bed_was:= bed.position


	var hay_end:= BriquettePress.ROAD_END [BriquettePress.SIDE_GRIND]
	var front:= press.road_front(BriquettePress.SIDE_GRIND)
	_check("the hay has only just left the rotors when they reach speed (%.2f of %.2f m)"
		% [front, hay_end], front >= 0.0 and front < hay_end * 0.5)
	_check("...so none of it is at the die yet",
		not press.road_arrived(BriquettePress.SIDE_GRIND))
	_check("...and nothing is heaped under the press (%.2f)" % press.charge_drawn(),
		press.charge_drawn() < BriquettePress.CHARGE_SHOW_AT)


	var bed_mesh:= bed as MeshInstance3D
	var told: Variant = null
	if bed_mesh != null:


		told = HayCompressor.driven(bed_mesh, &"road_seg_a", null)
	_check("...and the bed's material carries that front (%s)" % str(told),
		told is Vector2 and absf((told as Vector2).y - front) < 0.001)
	await _settle(60)
	_check("the hay on the feed bed creeps while the rotors turn (%.4f m)"
		% bed.position.distance_to(bed_was),
		bed.position.distance_to(bed_was) > 0.002)
	await _wait_for(func() -> bool: return press.road_arrived(BriquettePress.SIDE_GRIND),
		press.road_seconds(BriquettePress.SIDE_GRIND) + 1.0)
	_check("...and it runs down the bed into the die (front %.2f m)"
		% press.road_front(BriquettePress.SIDE_GRIND),
		press.road_arrived(BriquettePress.SIDE_GRIND))
	await _settle(30)


	_check("...and a heap is standing on the die mouth before any stroke",
		_visible(model, BriquettePress.N_CLIP_CHARGE))
	_check("...with no disc under a ram that has not come down",
		not _visible(model, BriquettePress.N_CLIP_DISC))


	press.stored_strands = 0
	await _wait_for(func() -> bool: return press.grinder_spin() < BriquettePress.ROAD_SOURCE_SPIN,
		Cfg.BRIQUETTE_SPIN_SECONDS * 3.0 + 2.0)
	await _settle(10)
	_check("when the rotors stop, the hay already on the bed is still there",
		press.road_busy(BriquettePress.SIDE_GRIND)
			and _visible(model, BriquettePress.N_CLIP_GRIND_TURN))
	await _wait_roads_clear(press)
	_check("...until it has run into the die",
		not press.road_busy(BriquettePress.SIDE_GRIND)
			and not _visible(model, BriquettePress.N_CLIP_GRIND_BED))


	var creep:= int(60.0 / BriquettePress.CHARGE_GROW) + 20


	var hay_creep:= creep + int(60.0 * (Cfg.BRIQUETTE_SPIN_SECONDS
		+ press.road_seconds(BriquettePress.SIDE_GRIND)))
	var pellet_creep:= creep + int(60.0 * (Cfg.BRIQUETTE_SPIN_SECONDS
		+ press.road_seconds(BriquettePress.SIDE_MILL)))
	_reset(press)
	press.stored_strands = 0
	press.stored_bricks = 0
	await _settle(creep)
	_check("an empty machine has no heap at all (fill %.2f)"
		% press.charge_fill(),
		not _visible(model, BriquettePress.N_CLIP_CHARGE))


	press.stored_strands = Tech.briquette_batch_strands() * 3
	await _settle(hay_creep)
	var half:= press.charge_drawn()
	_check("hay alone stands at about half a heap (fill %.2f, drawn %.2f)"
		% [press.charge_fill(), half], absf(press.charge_fill() - 0.5) < 0.01)
	_check("...and the heap has caught up with it (drawn %.2f)" % half,
		absf(half - 0.5) < 0.05)
	_check("...and it is showing", _visible(model, BriquettePress.N_CLIP_CHARGE))


	press.stored_bricks = maxi(1, Tech.briquette_batch_bricks() - 1)
	await get_tree().physics_frame
	var stepped:= press.charge_drawn()
	_check("...and a brick landing does not jump the heap (%.2f to %.2f)"
		% [half, stepped], stepped < half + 0.1)
	_check("...on a press that has not started a stroke on it",
		not press.is_running())
	await _settle(pellet_creep)
	var full:= press.charge_drawn()
	_check("...and the bricks arriving grow it (%.2f to %.2f)" % [half, full],
		full > half + 0.2)


	var charge_mesh:= charge as MeshInstance3D
	if charge_mesh != null:
		var wide:= charge_mesh.get_aabb().size.x * BriquettePress.LUMP_SIZE.x
		_check("...and a full lump stands narrower than the disc it is pressed into (%.2f m against %.2f)"
			% [wide, Cfg.FEED_DISC_SIZE.x], wide < Cfg.FEED_DISC_SIZE.x)
	_clear_discs()
	_reset(press)


	_reset(press)
	_discs_seen = 0
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool: return press.is_running(), 6.0)
	var charge_seen:= false
	var disc_seen:= false
	var both_at_once:= false


	var tallest:= 0.0
	var last_seen:= 0.0
	for i in int(Cfg.BRIQUETTE_CYCLE_SECONDS * 60.0) + 20:
		var c:= _visible(model, BriquettePress.N_CLIP_CHARGE)
		var d:= _visible(model, BriquettePress.N_CLIP_DISC)
		charge_seen = charge_seen or c
		disc_seen = disc_seen or d
		both_at_once = both_at_once or (c and d)
		if c:
			tallest = maxf(tallest, charge.scale.y)
			last_seen = charge.scale.y
		await get_tree().physics_frame
	_check("the charge is shown while the ram is coming down", charge_seen)
	_check("...and is squashed under the ram to x%.2f of its height"
		% (last_seen / maxf(tallest, 0.001)),
		tallest > 0.0 and last_seen < tallest * 0.85)
	_check("...and the disc is shown once the ram lifts off it", disc_seen)
	_check("...and the two are never both in the die at once", not both_at_once)
	_check("...and a disc came out of it (%d)" % _discs_seen, _discs_seen == 1)


	_check("...leaving nothing standing in the die afterwards",
		not _visible(model, BriquettePress.N_CLIP_DISC))
	_clear_discs()
	_reset(press)


func _case_the_disc_rides(press: BriquettePress) -> void:
	print("\n=== the disc rides away ===")
	var builds: BuildManager = world.builds
	var disc_port:= press.port_out()
	var away: Conveyor = builds.add_conveyor(
		disc_port, disc_port + press.bearing_at(disc_port) * 6.0)
	await _settle()
	_reset(press)
	_discs_seen = 0
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool: return _discs_seen > 0,
		Cfg.BRIQUETTE_CYCLE_SECONDS * 3.0 + 8.0)


	var seq:= _last_pushed_seq
	var where:= BeltPath.record_where(seq) if seq >= 0 else { }
	_check("a disc came out to ride", not where.is_empty())
	if where.is_empty():
		builds.demolish(away)
		return
	var start: Vector3 = (where ["pose"] as Transform3D).origin


	var travelled:= [-1.0]
	var moved:= func() -> bool:
		var now:= BeltPath.record_where(seq)
		if now.is_empty():
			return false
		travelled [0] = (now ["pose"] as Transform3D).origin.distance_to(start)
		return travelled [0] > 2.0
	await _wait_for(moved, 16.0)
	_check("...and travelled %.2f m out of the machine and down the run"
		% travelled [0], travelled [0] > 2.0)
	builds.demolish(away)
	_clear_discs()
	_reset(press)
	await _settle()


func _case_outfeed_blocked(press: BriquettePress) -> void:
	print("\n=== a blocked outfeed stops the machine ===")
	_reset(press)
	_discs_seen = 0


	var blocker:= world.props.spawn("feed_disc", Transform3D(
		press.global_basis, press.disc_spot() + Vector3.UP * 0.02)) as FeedDisc
	_check("a disc is standing on the outfeed", blocker != null)
	if blocker == null:
		return
	blocker.freeze = true
	await _settle()
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _wait_for(func() -> bool:
		return press.alert_reason().begins_with("OUTFEED"), 8.0)


	_check("the press says its outfeed is blocked ('%s')" % press.alert_reason(),
		press.alert_reason().begins_with("OUTFEED"))
	_check("...and has made no disc (%d)" % _discs_seen, _discs_seen == 0)
	_check("...and has spent neither buffer (%d, %d)"
		% [press.stored_strands, press.stored_bricks],
		press.stored_strands == Tech.briquette_batch_strands()
			and press.stored_bricks == Tech.briquette_batch_bricks())
	if blocker != null and is_instance_valid(blocker):
		world.props.remove(blocker)

	await _wait_for(func() -> bool: return _discs_seen > 0,
		Cfg.BRIQUETTE_CYCLE_SECONDS * 3.0 + 8.0)
	_check("...and delivers as soon as the deck is clear (%d)" % _discs_seen,
		_discs_seen == 1)
	_clear_discs()
	_reset(press)


func _case_dead(press: BriquettePress) -> void:
	print("\n=== a dead press stands still ===")
	_reset(press)
	_discs_seen = 0
	var was: bool = world.builds.grid.unmetered
	world.builds.grid.unmetered = false
	world.builds.grid.rebuild()
	await _settle(20)
	_check("with nothing wired, the press has no power (%.2f)" % press.power,
		press.power <= 0.0)


	var said:= press.alert_reason()
	_check("...and says so rather than blaming a belt ('%s')" % said,
		said != "" and not said.begins_with("NO HAY")
			and not said.begins_with("NO BRICKS")
			and not said.begins_with("NOT FED"))
	_check("...and its alert icon is the power one", press.alert_icon() == "power")
	press.stored_strands = Tech.briquette_batch_strands()
	press.stored_bricks = Tech.briquette_batch_bricks()
	await _settle(90)


	_check("...and it starts no cycle with a full charge waiting",
		not press.is_running())
	_check("...and makes no disc (%d)" % _discs_seen, _discs_seen == 0)


	_check("...and neither side turns (%.2f, %.2f)"
		% [press.grinder_spin(), press.mill_spin()],
		press.grinder_spin() < 0.05 and press.mill_spin() < 0.05)
	_check("...and draws nothing while switched off",
		_draw_switched_off(press) == 0.0)
	world.builds.grid.unmetered = was
	world.builds.grid.rebuild()
	await _settle(20)
	_check("...and comes back when the meter does (%.2f)" % press.power,
		press.power > 0.0)
	_clear_discs()
	_reset(press)


func _case_the_save(press: BriquettePress) -> void:
	print("\n=== save and load ===")
	_reset(press)
	press.stored_strands = 137
	press.stored_bricks = 3
	press.brick_hay = PackedInt32Array([50, 70, 90])
	press.pending_needles = PackedInt32Array([4, 19])
	var d:= press.to_dict()
	_check("the press saves under its own type",
		str(d.get("type", "")) == "briquette_press")
	var back:= BriquettePress.new()
	back.from_dict(d)


	_check("...and the hay comes back as hay (%d)" % back.stored_strands,
		back.stored_strands == 137)
	_check("...and the bricks come back as bricks (%d)" % back.stored_bricks,
		back.stored_bricks == 3)


	_check("...and the hay inside each brick (%s)" % str(Array(back.brick_hay)),
		Array(back.brick_hay) == [50, 70, 90])
	_check("...and every needle with them (%s)" % str(Array(back.pending_needles)),
		Array(back.pending_needles) == [4, 19])


	var older:= d.duplicate(true)
	older.erase("bricks")
	older.erase("brick_hay")
	older.erase("needles")
	var old_load:= BriquettePress.new()
	old_load.from_dict(older)
	_check("a save with no brick count loads with none (%d)"
		% old_load.stored_bricks, old_load.stored_bricks == 0)
	_check("...and no brick sizes either (%s)" % str(Array(old_load.brick_hay)),
		old_load.brick_hay.is_empty())


	var fat:= d.duplicate(true)
	fat ["strands"] = Cfg.BRIQUETTE_BUFFER_STRANDS * 10
	fat ["bricks"] = Cfg.BRIQUETTE_BUFFER_BRICKS * 10
	var fat_load:= BriquettePress.new()
	fat_load.from_dict(fat)


	_check("an over-full save is clamped to capacity (%d/%d, %d/%d)"
		% [fat_load.stored_strands, fat_load.strand_capacity(),
			fat_load.stored_bricks, fat_load.brick_capacity()],
		fat_load.stored_strands
				== fat_load.strand_capacity() + Cfg.WAD_MAX_STRANDS
			and fat_load.stored_bricks == fat_load.brick_capacity())
	back.queue_free()
	old_load.queue_free()
	fat_load.queue_free()


	var builds: BuildManager = world.builds
	var where:= press.global_position
	press.stored_strands = 88
	press.stored_bricks = 2
	press.pending_needles = PackedInt32Array([13])
	var saved:= builds.to_array()
	builds.clear()
	await _settle()
	builds.from_array(saved)
	await _settle()
	var found: BriquettePress = null
	for machine in builds.briquette_presses:
		found = machine
		break
	_check("the press comes back out of a yard save", found != null)
	if found == null:
		return
	_check("...standing where it stood (%.2f m off)"
		% found.global_position.distance_to(where),
		found.global_position.distance_to(where) < 0.05)
	_check("...with its hay (%d) and its bricks (%d)"
		% [found.stored_strands, found.stored_bricks],
		found.stored_strands == 88 and found.stored_bricks == 2)
	_check("...and the needle it was holding (%s)"
		% str(Array(found.pending_needles)),
		Array(found.pending_needles).has(13))
	_check("...and its three belts laid again",
		found.wad_deck() != null and found.brick_deck() != null
			and found.outfeed_deck() != null)


	_check("...as three different paths",
		found.wad_deck() != found.brick_deck()
			and found.brick_deck() != found.outfeed_deck())


func _on_pressed(disc: FeedDisc) -> void:
	_discs_seen += 1
	_last_drop = disc.global_position


func _wad_mouth(press: BriquettePress) -> Vector3:
	return press.to_global(Vector3(
		BriquettePress.WAD_MOUTH_X - 0.4, Cfg.BRIQUETTE_PORT_UP + 0.12,
		Cfg.BRIQUETTE_PORT_WAD_OFFSET))


func _brick_mouth(press: BriquettePress) -> Vector3:
	return press.to_global(Vector3(
		0.0, Cfg.BRIQUETTE_PORT_UP + 0.12, BriquettePress.BRICK_MOUTH_Z - 0.4))


func _drop_wad(press: BriquettePress, strands: int, needle: int) -> HayWad:
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), _wad_mouth(press))) as HayWad
	if wad != null:
		wad.strands = strands
		wad.needle_index = needle
	return wad


func _drop_brick(press: BriquettePress, needle: int, strands:= -1) -> EcoBrick:
	var brick:= world.props.spawn("eco_brick",
		Transform3D(Basis(), _brick_mouth(press))) as EcoBrick
	if brick != null:
		brick.needle_index = needle
		if strands > 0:
			brick.strands = strands
	return brick


func _discs() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is FeedDisc:
			out.append(item)
	return out


func _clear_discs() -> void:
	for disc: FeedDisc in _discs():
		world.props.remove(disc)
	_clear_records("feed_disc")
	_last_drop = Vector3.INF


var _last_pushed_seq:= -1
func _on_pressed_record(seq: int) -> void:
	_discs_seen += 1
	_last_pushed_seq = seq
	var where:= BeltPath.record_where(seq)
	if not where.is_empty():
		_last_drop = (where ["pose"] as Transform3D).origin


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


func _clear_records(id: String) -> void:
	for path in BeltPath._live:
		if not is_instance_valid(path) or not path.is_inside_tree():
			continue
		var run: BeltRun = path.run
		var i:= run.first() + run.count() - 1
		while i >= run.first():
			if BeltRun.ITEM_IDS [run.kind_of(i)] == id:


				var was_head:= i == run.first()
				run.remove_at(i)
				if was_head:
					break
			i -= 1


func _clear_kind(id: String) -> void:
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and item.item_id == id:
			world.props.remove(item)
	_clear_records(id)


func _discs_in_hand() -> Array:
	for seq: int in _records_of("feed_disc"):
		var where:= BeltPath.record_where(seq)
		if not where.is_empty():
			(where ["path"] as BeltPath).materialize_record(int(where ["row"]))
	return _discs()


func _reset(press: BriquettePress) -> void:
	press.stored_strands = 0
	press.stored_bricks = 0
	press.brick_hay = PackedInt32Array()
	press.pending_needles = PackedInt32Array()
	press._run = -1.0
	press._released = false
	for item in world.props.items.duplicate():
		if is_instance_valid(item) and (item is HayWad or item is EcoBrick):
			world.props.remove(item)
	_clear_records("hay_wad")
	_clear_records("eco_brick")
	await _settle(10)


func _draw_switched_off(press: BriquettePress) -> float:
	var was:= press.is_switched_off()
	press.set_switched_off(true)
	var kw:= press.draw_kw()
	press.set_switched_off(was)
	return kw


func _visible(model: Node, node_name: String) -> bool:
	if model == null:
		return false
	var node:= model.find_child(node_name, true, false) as Node3D
	return node != null and node.visible


func _settle(frames: int = SETTLE_FRAMES) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait_for(cond: Callable, timeout: float) -> void:
	var spent:= 0.0
	while spent < timeout:
		if bool(cond.call()):
			return
		await get_tree().physics_frame
		spent += 1.0 / 60.0


func _wait_roads_clear(press: BriquettePress) -> void:
	var longest:= maxf(press.road_seconds(BriquettePress.SIDE_GRIND, true),
		press.road_seconds(BriquettePress.SIDE_MILL, true))
	await _wait_for(func() -> bool: return not press.road_busy(BriquettePress.SIDE_GRIND) and not press.road_busy(BriquettePress.SIDE_MILL),
		longest + Cfg.BRIQUETTE_SPIN_SECONDS * 2.0 + 1.0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
