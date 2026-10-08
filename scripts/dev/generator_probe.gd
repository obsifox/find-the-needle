class_name DevGeneratorProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40

const PATIENCE:= 400


const TEST_BRICK_STRANDS:= 45


const TEST_WAD_STRANDS:= 63

const TEST_NEEDLE:= 11

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(20000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== model ===")
	var gen: HayGenerator = world.builds.add_generator(Vector3(13.0, 0.0, 0.0), 0.0)


	if "--oldreach" in OS.get_cmdline_user_args():
		var d:= gen.to_dict()
		d.erase("port_reach")
		await world.builds.from_array([d])
		gen = world.builds.generators [0]
		print("OLDREACH: feed %.2f m" % gen.feed_length())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	_check("model instantiated", gen.get_node_or_null("Model") != null)
	_check("instruction board has a live readout", gen._fuel_readout != null)
	if gen._fuel_readout != null:
		gen.fuel = 180.0
		gen.made_kw = 3.0
		gen._update_instruction_board()
		_check("board shows a minute at three kilowatts",
			gen._fuel_readout.text == gen.tr("Fuel left: %d min %02d sec") % [1, 0])
		gen.made_kw = 6.0
		gen._update_instruction_board()
		_check("doubling demand halves the displayed duration",
			gen._fuel_readout.text == gen.tr("Fuel left: %d min %02d sec") % [0, 30])
		gen.switched_off = true
		gen._update_instruction_board()
		_check("a stopped generator does not show a countdown",
			gen._fuel_readout.text == gen.tr("Switched off"))
		gen.switched_off = false
		gen.fuel = 0.0
		gen.made_kw = 0.0
		gen._update_instruction_board()
		_check("empty board asks for hay",
			gen._fuel_readout.text == gen.tr("Out of fuel: add hay"))
	_check("marker %s" % HayGenerator.N_BELT_HEAD, gen._find(HayGenerator.N_BELT_HEAD) != null)
	_check("marker %s" % HayGenerator.N_FIRE, gen._find(HayGenerator.N_FIRE) != null)
	_check("the voltmeter is its own object", gen._volt != null)
	_check("the Run clip is there and loops", gen._clip_name() != ""
		and gen._anim.get_animation(gen._clip_name()).loop_mode == Animation.LOOP_LINEAR)


	var volt_tracks:= 0
	var clip:= gen._anim.get_animation(gen._clip_name())
	for i in clip.get_track_count():
		if str(clip.track_get_path(i)).contains(HayGenerator.N_VOLT):
			volt_tracks += 1
	_check("the clip's voltmeter track was dropped", volt_tracks == 0)


	var spec:= HayGenerator.spec_table()
	var shader: Shader = load(HayCompressor.SHADER)
	_check("the material table has both blocks",
		not (spec.get("surfaces", { }) as Dictionary).is_empty()
			and not (spec.get("flats", { }) as Dictionary).is_empty())
	_check("a `surfaces` key builds a ShaderMaterial",
		HayCompressor.make_material("M_Shell", spec, shader) is ShaderMaterial)
	_check("a `flats` key builds a StandardMaterial3D",
		HayCompressor.make_material("M_Led", spec, shader) is StandardMaterial3D)


	_check("the switchboard lamps were found and are dark",
		not gen._led_meshes.is_empty() and not gen._bulb_meshes.is_empty()
			and is_equal_approx(gen.led_energy(), HayGenerator.LED_DARK))
	_check("the fire exists and is out", gen._fire_light != null
		and gen._fire_puff != null and not gen._fire_light.visible
		and not gen._fire_puff.emitting)
	_check("the hopper heap exists and is hidden while empty",
		gen._heap != null and not gen._heap.visible)


	print("  [note] the boiler gauge needle is %s"
		% ("driven" if gen._boil != null
			else "still joined into Gen_Boiler, so the fuel gauge is dormant"))

	print("\n=== the ghost ===")


	var ghost:= HayGenerator.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.setup(Vector3(13.0, 0.0, -9.0), 0.0)
	for i in 8:
		await get_tree().physics_frame
	_check("the ghost draws a belt", ghost._ghost_belt != null
		and ghost._ghost_belt.drawn(0) > 0)


	ghost.set_preview_valid(false)
	_check("a refused ghost paints its belt too", ghost._ghost_belt != null
		and ghost._ghost_belt.material() == ConveyorKit.ghost_material(false))
	ghost.set_preview_valid(true)


	var run_now:= ghost.ghost_run()
	var start: Vector3 = run_now ["from"]
	var finish: Vector3 = run_now ["to"]
	_check("the drawn belt starts at the port (off by %.3f m)"
		% start.distance_to(ghost.intake_port()),
		start.distance_to(ghost.intake_port()) < 0.02)
	_check("...and ends at the head (off by %.3f m)"
		% finish.distance_to(ghost.belt_head()),
		finish.distance_to(ghost.belt_head()) < 0.02)
	_check("...and it lies level at the stoker (%.3f m of rise)"
		% (finish.y - start.y), absf(finish.y - start.y) < 0.02)


	_check("nothing is drawn past the port, where the stub used to be",
		ghost.to_local(start).z >= ghost.to_local(ghost.intake_port()).z - 0.01)
	_check("a placed machine publishes no ghost run at all", gen.ghost_run().is_empty())
	_check("the ghost lays no real deck and grows no mouths",
		ghost.deck() == null and ghost._intake == null and ghost._hopper == null)
	_check("the ghost is not solid", ghost._body.collision_layer == 0)
	ghost.set_preview_valid(false)
	ghost.set_preview_valid(true)
	_check("the ghost tints without complaint",
		ghost._model != null and ghost._model.get_child_count() > 0)
	_check("a ghost never reports a fault", ghost.alert_reason() == "")
	world.remove_child(ghost)
	ghost.queue_free()
	for i in 4:
		await get_tree().physics_frame

	print("\n=== geometry ===")


	var port_local:= gen.to_local(gen.port_in())
	_check("port_in agrees with PORT_BACK and PORT_UP (got %s)"
		% port_local, port_local.distance_to(
			Vector3(0.0, HayGenerator.PORT_UP, - (HayGenerator.HEAD_BACK + gen.feed_length()))) < 0.02)
	var head_local:= gen.to_local(gen.belt_head())
	_check("belt_head is feed_length() in from the port at the same height (got %s)"
		% head_local,
		absf(head_local.y - port_local.y) < 0.01
		and absf(head_local.z - port_local.z - gen.feed_length()) < 0.01)
	_check("the intake meets a standard floor belt without a climb",
		absf(head_local.y - Cfg.BELT_FRAME_DEPTH - Cfg.BELT_STAND_CLEAR) < 0.001)
	_check("the head reaches the low stoker in front of the hand hopper",
		head_local.z < HayGenerator.HOPPER_AT.z
		and head_local.y < HayGenerator.HOPPER_AT.y)


	_check("intake_port is the port itself (off by %.3f m)"
		% gen.intake_port().distance_to(gen.port_in()),
		gen.intake_port().is_equal_approx(gen.port_in()))


	_check("travel is +Z as placed", gen.forward().dot(Vector3.BACK) > 0.99)
	_check("it lays a deck of its own", gen.deck() != null)
	_check("the deck is a terminus and has no downstream",
		gen.deck().downstream == null)
	_check("the console is out beyond the switchboard end",
		(gen.console_position() - gen.global_position).dot(gen.forward()) > 2.5)

	print("\n=== the ghost stands broadside ===")


	for aim: Vector3 in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0),
			Vector3(-1, 0, 0), Vector3(0.6, 0, -0.8)]:
		var f:= HayGenerator.broadside_forward(aim)
		var basis:= Basis(Vector3.UP, atan2(f.x, f.z))


		_check("aiming %s puts the fire door square to the player (x . look = %.3f)"
			% [aim, basis.x.dot(aim.normalized())],
			basis.x.dot(aim.normalized()) < -0.999)
		_check("...and the intake runs across the view, not down it",
			absf(basis.z.dot(aim.normalized())) < 0.001)


	_check("aiming straight down still gives a heading",
		HayGenerator.broadside_forward(Vector3.DOWN).is_normalized())

	print("\n=== snapping ===")
	var near:= gen.intake_port() + Vector3(0.3, 0.0, 0.35)
	var snapped: Vector3 = world.builds.snap_endpoint(near)
	_check("a belt end near the intake snaps onto it (off by %.3f m)"
		% snapped.distance_to(gen.intake_port()),
		snapped.is_equal_approx(gen.intake_port()))
	var far:= gen.intake_port() + Vector3(5.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second generator on the same spot is refused",
		world.builds.generator_overlap(gen.global_position))


	var span:= Cfg.GENERATOR_KEEPOUT.z + Cfg.GENERATOR_KEEPOUT.w
	var line:= Cfg.GENERATOR_KEEPOUT.x + Cfg.GENERATOR_KEEPOUT.y
	_check("...and one abreast of it, inside its width, is refused",
		world.builds.generator_overlap(gen.global_position
			+ Vector3(span - 0.2, 0.0, 0.0)))
	_check("one abreast and clear of the width is allowed, at %.2f m where the "
		% (span + 0.2) + "old circle wanted 3.20",
		not world.builds.generator_overlap(gen.global_position
			+ Vector3(span + 0.2, 0.0, 0.0)))
	_check("...and nose to tail it wants %.2f m, which a width cannot say" % line,
		world.builds.generator_overlap(gen.global_position
			+ Vector3(0.0, 0.0, line - 0.3)))
	_check("...and is allowed just past it",
		not world.builds.generator_overlap(gen.global_position
			+ Vector3(0.0, 0.0, line + 0.3)))


	_check("one turned across the yard, tail into this one's flank, is refused",
		world.builds.generator_overlap(gen.global_position
			+ Vector3(1.5, 0.0, 0.0), Vector3.RIGHT))
	_check("...and the same machine a metre further out is allowed",
		not world.builds.generator_overlap(gen.global_position
			+ Vector3(2.5, 0.0, 0.0), Vector3.RIGHT))

	print("\n=== the run lands on Gen_BeltPort ===")


	var feed:= gen.intake_port() - gen.forward() * 6.0
	feed.y = deck_y
	var run: Conveyor = world.builds.add_conveyor(feed, gen.intake_port())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the feeding run hands off to the machine's deck",
		run.downstream == gen.deck())
	_check("the run was laid to the snap point and not the origin (off by %.3f m)"
		% run.b.distance_to(gen.intake_port()),
		run.b.is_equal_approx(gen.intake_port()))


	var deck_end: Vector3 = gen.deck()._line [gen.deck()._line.size() - 1]
	_check("the machine's deck ends on Gen_BeltHead (off by %.3f m)"
		% deck_end.distance_to(gen.belt_head()),
		deck_end.distance_to(gen.belt_head()) < 0.01)
	_check("...and it is one straight run, port to head", gen.deck()._line.size() == 2)


	_check("the intake is a Conveyor, the same node the player builds",
		gen.deck() is Conveyor)
	var intake:= gen.deck() as Conveyor
	intake.refresh_supports()
	_check("the intake has grounded support posts", intake._built_legs.size() >= 2)
	for i in intake._built_legs.size():
		var post: Transform3D = intake._built_legs [i]
		var foot: Transform3D = intake._built_feet [i]
		_check("intake post %d reaches the frame" % i,
			absf(post.origin.y - (gen.intake_port().y - Cfg.BELT_SUPPORT_ATTACH_DEPTH)) < 0.002)
		_check("intake post %d reaches its foot" % i,
			(post * Vector3(0, -1, 0)).distance_to(foot.origin) < 0.002)
	_check("the deck spans the whole feed run (%.2f m)"
		% gen.deck().path_length(),
		gen.deck().path_length() > gen.feed_length() - 0.02)


	var deck_bodies:= gen.deck().find_children("*", "CollisionObject3D", true, false)
	var deck_body: Node = deck_bodies [0] if not deck_bodies.is_empty() else gen.deck()
	_check("aiming at the intake finds the generator, not a conveyor (%d bodies)"
		% deck_bodies.size(), world.builds.owner_of(deck_body) == gen)


	_check("the model ships no belt of its own to fight with it",
		gen.find_children("Gen_Belt_*", "MeshInstance3D", true, false).is_empty()
		and gen.find_children("Gen_Conveyor_*", "MeshInstance3D", true, false).is_empty())

	print("\n=== placing the machine ON a run puts the port on the joint ===")


	var joint:= Vector3(-8.0, BuildTool.GENERATOR_PORT_UP, -14.0)
	var joint_fwd:= Vector3(0.0, 0.0, 1.0)
	var seated: HayGenerator = world.builds.add_generator(
		joint + joint_fwd * BuildTool.GENERATOR_PORT_BACK
			- Vector3.UP * BuildTool.GENERATOR_PORT_UP,
		atan2(joint_fwd.x, joint_fwd.z), 0.0)
	await get_tree().physics_frame
	_check("the port lands on the belt end the ghost snapped to (off by %.3f m)"
		% seated.intake_port().distance_to(joint),
		seated.intake_port().distance_to(joint) < 0.01)
	var laid_to: Vector3 = world.builds.snap_generator_port(joint, gen)
	_check("...and the belt the player laid would hand off to it",
		laid_to.is_equal_approx(seated.intake_port()))


	world.builds.demolish(seated)
	for i in 4:
		await get_tree().physics_frame
	_check("...and it comes down again cleanly",
		world.builds.generators.size() == 1)

	print("\n=== hay thrown at the machine's OWN belt ===")


	gen.fuel = 0.0
	var lob_climb_a:= gen.port_in()
	var lob_climb_b:= gen.belt_head()
	var lob_across:= BeltPath.run_basis(lob_climb_a, lob_climb_b).x
	var lob_rng:= RandomNumberGenerator.new()
	lob_rng.seed = 20260903
	var lob_lobbed: Array [RigidBody3D] = []
	var lob_below: Array [float] = []
	for i in 14:
		var lob_t:= 0.1 + 0.75 * float(i) / 13.0
		var lob_at: Vector3 = lob_climb_a.lerp(lob_climb_b, lob_t)
		lob_at += lob_across * lob_rng.randf_range(-1.0, 1.0) * Cfg.BELT_WIDTH * 0.42
		var lob_sb: RigidBody3D = world.live.spawn(lob_at + Vector3(0, 1.1, 0),
			StrandFactory.random_strand_basis(lob_rng),
			Vector3(0, - HandTool.THROW_SPEED, 0), Cfg.COL_HAY_LIGHT)
		if lob_sb == null:
			continue
		lob_lobbed.append(lob_sb)
		lob_below.append(0.0)
	if lob_lobbed.is_empty():
		_check("could spawn hay to throw at the intake", false)
		return


	var lob_peak:= 0.0
	for i in 300:
		await get_tree().physics_frame
		lob_peak = maxf(lob_peak, gen.fuel)
		for k in lob_lobbed.size():
			if not (is_instance_valid(lob_lobbed [k]) and lob_lobbed [k].is_inside_tree()):
				continue
			var lob_q: Vector3 = lob_lobbed [k].global_position
			lob_below [k] = minf(lob_below [k], lob_q.y - _nearest_on(
				PackedVector3Array([lob_climb_a, lob_climb_b]), lob_q).y)
	var lob_holed:= 0
	var lob_burnt:= 0
	var lob_riding:= 0
	var lob_dropped:= 0
	for k in lob_lobbed.size():
		if lob_below [k] < -0.3:
			lob_holed += 1
			print("   THROUGH THE BELT: %.2f m lob_below the rubber" % - lob_below [k])
		if not (is_instance_valid(lob_lobbed [k]) and lob_lobbed [k].is_inside_tree()):
			lob_burnt += 1
			continue
		var lob_q: Vector3 = lob_lobbed [k].global_position
		if lob_q.distance_to(_nearest_on(PackedVector3Array([lob_climb_a, lob_climb_b]), lob_q)) < 0.4:
			lob_riding += 1
			print("   still riding: throw %d, at %s in the machine's frame" % [k, gen.to_local(lob_q)])
		else:
			lob_dropped += 1
			print("   on the floor: throw %d, at %s in the machine's frame" % [k, gen.to_local(lob_q)])
	print("   of %d thrown at the intake: %d swallowed, %d still riding, %d on the floor"
		% [lob_lobbed.size(), lob_burnt, lob_riding, lob_dropped])
	print("   firebox peaked at %.1f kJ, holds %.1f kJ" % [lob_peak, gen.fuel])
	_check("no hay thrown at the machine's belt went through it (%d of %d)"
		% [lob_holed, lob_lobbed.size()], lob_holed == 0)
	_check("hay thrown at the machine's belt ends up in the machine (%d of %d spilled)"
		% [lob_dropped, lob_lobbed.size()], lob_dropped == 0)
	_check("...and the firebox actually gained from it (peaked at %.1f kJ)" % lob_peak,
		lob_peak > 0.0)
	for lob_b in lob_lobbed:
		if is_instance_valid(lob_b) and lob_b.is_inside_tree():
			world.live.consume(lob_b)
	gen.fuel = 0.0

	print("\n=== the burn arithmetic ===")
	var per:= Cfg.GENERATOR_KJ_PER_STRAND
	var brick:= world.props.spawn("eco_brick", Transform3D(Basis(),
		gen.global_position + Vector3(0, 6, 0)),
		{ "strands": TEST_BRICK_STRANDS }) as EcoBrick
	_check("a %d strand brick is exactly %d * %.1f * %.2f kilowatt seconds (got %.4f)"
		% [TEST_BRICK_STRANDS, TEST_BRICK_STRANDS, per, Cfg.GENERATOR_BURN_BRICK,
			HayGenerator.burn_value(brick)],
		is_equal_approx(HayGenerator.burn_value(brick),
			float(TEST_BRICK_STRANDS) * per * Cfg.GENERATOR_BURN_BRICK))
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(),
		gen.global_position + Vector3(0, 8, 0)),
		{ "strands": TEST_WAD_STRANDS }) as HayWad
	_check("a wad burns at the loose multiplier",
		is_equal_approx(HayGenerator.burn_value(wad),
			float(TEST_WAD_STRANDS) * per * Cfg.GENERATOR_BURN_LOOSE))
	var bale:= world.props.spawn("hay_bale", Transform3D(Basis(),
		gen.global_position + Vector3(0, 10, 0)),
		{ "strands": TEST_WAD_STRANDS }) as HayBale
	_check("a bale burns at %.2f" % Cfg.GENERATOR_BURN_BALE,
		is_equal_approx(HayGenerator.burn_value(bale),
			float(bale.hay_strands()) * per * Cfg.GENERATOR_BURN_BALE))
	var foil:= world.props.spawn("foiled_bale", Transform3D(Basis(),
		gen.global_position + Vector3(0, 12, 0)),
		{ "strands": TEST_WAD_STRANDS }) as FoiledBale
	_check("a foiled bale burns at %.2f" % Cfg.GENERATOR_BURN_FOIL,
		is_equal_approx(HayGenerator.burn_value(foil),
			float(foil.hay_strands()) * per * Cfg.GENERATOR_BURN_FOIL))


	for fuel: Array in [["loose", Cfg.GENERATOR_BURN_LOOSE], ["bale", Cfg.GENERATOR_BURN_BALE],
			["brick", Cfg.GENERATOR_BURN_BRICK], ["foiled bale", Cfg.GENERATOR_BURN_FOIL],
			["disc", Cfg.GENERATOR_BURN_DISC]]:
		_check("a straw in a %s is worth 1.0 kJ here (got %.2f)" % [fuel [0], float(fuel [1]) * per],
			is_equal_approx(float(fuel [1]) * per, 1.0))
	_check("a %d strand brick is %d kJ, the same as that much loose hay"
		% [TEST_BRICK_STRANDS, TEST_BRICK_STRANDS],
		is_equal_approx(HayGenerator.burn_value(brick), float(TEST_BRICK_STRANDS)))


	var bucket: Carryable = world.props.spawn("bucket", Transform3D(Basis(),
		gen.global_position + Vector3(0, 14, 0)))
	_check("a bucket is worth nothing and is not fuel",
		HayGenerator.burn_value(bucket) == 0.0)


	var disc:= world.props.spawn("feed_disc", Transform3D(Basis(),
		gen.global_position + Vector3(0, 16, 0))) as FeedDisc
	var disc_kj:= HayGenerator.burn_value(disc)
	var apart:= (float(Cfg.BRIQUETTE_BATCH_STRANDS) * Cfg.GENERATOR_BURN_LOOSE
		+ float(disc.brick_hay) * Cfg.GENERATOR_BURN_BRICK) * per
	_check("a feed disc burns (got %.1f kJ)" % disc_kj, disc_kj > 0.0)
	_check("for exactly what its hay and bricks would apart (%.1f = %.1f)"
			% [disc_kj, apart], is_equal_approx(disc_kj, apart))
	_check("and a disc record burns for the same as the body",
		is_equal_approx(HayGenerator.burn_value_of(BeltRun.Kind.DISC,
			disc.hay_strands()), disc_kj))
	for item in [brick, wad, bale, foil, bucket, disc]:
		if is_instance_valid(item):
			world.props.remove(item)
	for i in 4:
		await get_tree().physics_frame

	print("\n=== the hand feed ===")
	gen.fuel = 0.0
	var fed:= world.props.spawn("eco_brick",
		Transform3D(Basis(), gen.hopper_position()),
		{ "strands": TEST_BRICK_STRANDS }) as EcoBrick
	fed.needle_index = TEST_NEEDLE
	var want:= float(TEST_BRICK_STRANDS) * per * Cfg.GENERATOR_BURN_BRICK


	var lost: Array = []
	var heard:= func(type: int, paid: float,
			cause: GameState.NeedleLoss) -> void: lost.append([type, paid, cause])
	GameState.needle_lost.connect(heard)
	var eaten:= false
	for i in PATIENCE:
		await get_tree().physics_frame
		if gen.fuel > 0.0:
			eaten = true
			break
	_check("a brick dropped in the hopper is swallowed", eaten)
	_check("...and the firebox gained exactly its burn value (%.1f, wanted %.1f)"
		% [gen.fuel, want], absf(gen.fuel - want) < 0.5)
	GameState.needle_lost.disconnect(heard)
	_check("the needle inside it was announced as lost (%d heard)" % lost.size(),
		lost.size() == 1)
	_check("...naming the type that went in",
		lost.size() == 1 and int(lost [0] [0]) == GameState.type_of(TEST_NEEDLE))

	_check("...and paying nothing for it",
		lost.size() == 1 and is_zero_approx(float(lost [0] [1])))


	_check("...and saying it burned rather than that it was sold",
		lost.size() == 1 and int(lost [0] [2]) == GameState.NeedleLoss.BURNED)
	_check("the fire caught", gen.is_burning() and gen._fire_puff.emitting)
	_check("the switchboard lit",
		gen.led_energy() == HayGenerator.LED_LIT)


	var twin:= HayGenerator.new()
	twin.placement_preview = true
	add_child(twin)
	var shared:= HayCompressor.materials_shared()
	var worn:= not twin._led_meshes.is_empty()
	if worn:
		var a: MeshInstance3D = gen._led_meshes [0]
		var b: MeshInstance3D = twin._led_meshes [0]


		for s in a.mesh.get_surface_count():
			var mine:= a.get_surface_override_material(s)
			if mine != null and (mine == b.get_surface_override_material(s)) != shared:
				worn = false
	_check("a second generator wears %s materials" % ("the same" if shared else "its own"), worn)
	_check("...and this fire left its lamp alone", twin.led_energy() != HayGenerator.LED_LIT)
	twin.queue_free()
	_check("the heap showed up in the hopper", gen._heap.visible)
	_check("it is making %.0f kW" % Cfg.GENERATOR_OUTPUT_KW,
		is_equal_approx(gen.output_kw(), Cfg.GENERATOR_OUTPUT_KW))
	_check("it reports no fault while it is burning", gen.alert_reason() == "")

	print("\n=== the box drains in the arithmetic time ===")


	var step:= 1.0 / 60.0
	var ticks:= 0
	gen.fuel = gen.capacity()
	var box:= gen.fuel
	while gen.fuel > 0.0 and ticks < 20000:
		gen._tick_burn(step)
		ticks += 1
	var burnt:= float(ticks) * step
	var arithmetic:= box / Cfg.GENERATOR_OUTPUT_KW
	_check("a full %.0f kJ box lasts %.2f s at %.0f kW (took %.2f s)"
		% [box, arithmetic, Cfg.GENERATOR_OUTPUT_KW, burnt],
		absf(burnt - arithmetic) <= step * 1.5)


	gen._tick_burn(step)
	_check("the box is empty and the output is zero", gen.output_kw() == 0.0)
	_check("...but the fire is still shown in: an empty box on a trickle feed "
		+ "must not flicker", gen.is_burning())
	for i in int(Cfg.GENERATOR_EMBER_SECONDS / step) + 2:
		gen._tick_burn(step)
	_check("the fire went out %.0f s later" % Cfg.GENERATOR_EMBER_SECONDS,
		not gen.is_burning() and gen.output_kw() == 0.0)
	_check("the switchboard went dark",
		is_equal_approx(gen.led_energy(), HayGenerator.LED_DARK))
	_check("the heap is hidden again", not gen._heap.visible)


	gen.fuel = Cfg.GENERATOR_OUTPUT_KW * 1.0
	var waited:= 0.0
	for i in PATIENCE:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if gen.fuel <= 0.0:
			break
	_check("one second of fuel burns in one second of physics (took %.3f s)"
		% waited, absf(waited - 1.0) <= 0.05)
	for i in int(Cfg.GENERATOR_EMBER_SECONDS * 60.0) + 4:
		await get_tree().physics_frame

	print("\n=== the burn follows the load ===")
	var cap:= Tech.generator_output()
	gen.fuel = gen.capacity()
	gen.set_load(2.0)
	var before_load:= gen.fuel
	for i in 60:
		gen._tick_burn(step)
	_check("asked for 2.0 kW off a %.0f kW cap it burns 2.0 kJ a second (burnt %.2f)"
		% [cap, before_load - gen.fuel], absf((before_load - gen.fuel) - 2.0) < 0.05)
	_check("...and reports that it made 2.0 kW (%.2f)" % gen.output_kw(),
		absf(gen.output_kw() - 2.0) < 0.01)
	gen.set_load(0.0)
	before_load = gen.fuel
	for i in 60:
		gen._tick_burn(step)
	_check("asked for nothing it burns the %.1f kW pilot and keeps the fire in (burnt %.2f)"
		% [Cfg.GENERATOR_PILOT_KW, before_load - gen.fuel],
		absf((before_load - gen.fuel) - Cfg.GENERATOR_PILOT_KW) < 0.05 and gen.is_burning())
	gen.set_load(cap * 10.0)
	before_load = gen.fuel
	for i in 60:
		gen._tick_burn(step)
	_check("asked for ten times the cap it burns the cap (burnt %.2f)"
		% (before_load - gen.fuel), absf((before_load - gen.fuel) - cap) < 0.05)

	print("\n=== with the box empty, the output is the feed ===")
	gen.fuel = 0.0
	gen.set_load(cap * 10.0)
	var feed_kw:= 3.0
	for i in 60:
		gen.fuel += feed_kw * step
		gen._tick_burn(step)
	_check("fed %.1f kW against a %.0f kW cap it makes %.1f kW (%.2f)"
		% [feed_kw, cap, feed_kw, gen.output_kw()],
		absf(gen.output_kw() - feed_kw) < 0.01)
	_check("...and the box stays empty: every strand is burnt the tick it lands",
		gen.fuel < 0.001)
	_check("...and the fire is in", gen.is_burning())
	gen.set_load(-1.0)
	gen.fuel = 0.0
	for i in int(Cfg.GENERATOR_EMBER_SECONDS * 60.0) + 4:
		await get_tree().physics_frame

	print("\n=== the switch ===")
	gen.fuel = gen.capacity() * 0.5
	for i in 4:
		await get_tree().physics_frame
	_check("half a box and the fire is in", gen.is_burning() and gen.output_kw() > 0.0)
	gen.set_switched_off(true)
	for i in 4:
		await get_tree().physics_frame
	_check("switched off, the fire is out and it makes nothing",
		not gen.is_burning() and gen.output_kw() == 0.0 and gen.cap_kw() == 0.0)
	_check("...the box keeps what it had", gen.fuel > gen.capacity() * 0.45)
	_check("...the deck is held, so the belt behind it backs up", gen.deck().is_blocked())
	_check("...and it is not a fault: no sign", gen.alert_reason() == "")
	var offered:= world.props.spawn("eco_brick",
		Transform3D(Basis(), gen.hopper_position()),
		{ "strands": TEST_BRICK_STRANDS }) as EcoBrick
	var fuel_off:= gen.fuel
	for i in 30:
		await get_tree().physics_frame
	_check("a brick dropped in while it is off is left alone",
		is_instance_valid(offered) and gen.fuel <= fuel_off)
	if is_instance_valid(offered):
		world.props.remove(offered)
	_check("to_dict carries the switch", bool(gen.to_dict().get("off", false)))
	gen.set_switched_off(false)
	for i in 4:
		await get_tree().physics_frame
	_check("switched back on, it catches again on what was in the box",
		gen.is_burning() and gen.output_kw() > 0.0 and not gen.deck().is_blocked())

	print("\n=== full, and the belt behind it ===")


	gen.fuel = gen.capacity()
	for i in 4:
		await get_tree().physics_frame
	_check("a full firebox is still refusing hay four frames later",
		gen.is_full() and gen.fuel < gen.capacity())
	_check("...and holds its own deck shut, so the queue parks on it",
		gen.deck().is_blocked())
	var spare:= world.props.spawn("eco_brick",
		Transform3D(Basis(), gen.hopper_position()),
		{ "strands": TEST_BRICK_STRANDS }) as EcoBrick
	var before:= gen.fuel
	for i in 30:
		await get_tree().physics_frame
	_check("a brick offered to a full machine is left alone",
		is_instance_valid(spare) and gen.fuel < before)
	if is_instance_valid(spare):
		world.props.remove(spare)


	for i in 30:
		await get_tree().physics_frame
	_check("...and its empty intake is drawn stopped (asleep %s)" % str(gen.deck()._asleep),
		gen.deck().deck_shows_held())


	gen.fuel = gen.capacity() * Cfg.GENERATOR_REFILL_AT - 1.0
	for i in 4:
		await get_tree().physics_frame
	_check("burnt down to the refill mark, it opens up again",
		not gen.is_full() and not gen.deck().is_blocked())
	for i in 30:
		await get_tree().physics_frame
	_check("...and its intake is drawn running again", not gen.deck().deck_shows_held())

	print("\n=== only what fits goes in ===")


	gen.set_load(0.0)
	gen.fuel = gen.capacity() * (Cfg.GENERATOR_REFILL_AT - 0.02)
	var big_strands:= 150
	var brick_kj:= float(big_strands) * per * Cfg.GENERATOR_BURN_BRICK
	_check("a brick (%.0f kJ) is more than the %.0f kJ of room" % [brick_kj,
		gen.capacity() - gen.fuel], brick_kj > gen.capacity() - gen.fuel)
	var big:= world.props.spawn("eco_brick",
		Transform3D(Basis(), gen.hopper_position()),
		{ "strands": big_strands }) as EcoBrick
	var room_fuel:= gen.fuel
	for i in 30:
		await get_tree().physics_frame
	_check("a brick that does not fit is left whole rather than clipped to the brim",
		is_instance_valid(big) and gen.fuel <= room_fuel)
	_check("...and the deck is held under it, not let off the end",
		gen.deck().is_blocked())
	gen.fuel = gen.capacity() * 0.4
	var eaten_whole:= false
	for i in PATIENCE:
		await get_tree().physics_frame
		if not is_instance_valid(big) or big.is_queued_for_deletion():
			eaten_whole = true
			break
	_check("with room made, it goes in", eaten_whole)
	var gained:= gen.fuel - gen.capacity() * 0.4
	_check("...whole: the box gained its full %.0f kJ (got %.1f, less what burnt)"
		% [brick_kj, gained], gained > brick_kj - 2.0 and gained <= brick_kj + 0.01)
	_check("...and the deck runs again", not gen.deck().is_blocked())
	gen.set_load(-1.0)

	print("\n=== it says when the box is empty ===")
	gen.fuel = 0.0
	gen.starved_for = Cfg.MACHINE_STARVED_AFTER + 1.0
	for i in 2:
		await get_tree().physics_frame
	_check("a starved machine names the hopper",
		gen.alert_reason().begins_with("FIREBOX EMPTY"))
	_check("MachineWatch can see it",
		world.builds.watch != null and world.builds.generators.has(gen))

	print("\n=== a save round trip ===")
	gen.fuel = 1234.5
	var at:= gen.global_position
	var yaw:= gen.global_rotation.y
	var d:= gen.to_dict()
	_check("to_dict names the type", str(d.get("type", "")) == "hay_generator")
	for key: String in ["position", "yaw", "fuel"]:
		_check("to_dict carries %s" % key, d.has(key))


	_check("...and no ash pit, because there is not one", not d.has("needles"))
	var saved: Array = world.builds.to_array()
	world.builds.clear()
	for i in 4:
		await get_tree().physics_frame
	_check("the yard is empty after clear", world.builds.generators.is_empty())
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("one generator came back", world.builds.generators.size() == 1)
	var back: HayGenerator = world.builds.generators [0]
	_check("...where it was (off by %.3f m)" % back.global_position.distance_to(at),
		back.global_position.distance_to(at) < 0.01)
	_check("...facing the way it was", absf(back.global_rotation.y - yaw) < 0.001)


	var spent:= 1234.5 - back.fuel
	var settled:= float(SETTLE_FRAMES) / 60.0 * Cfg.GENERATOR_OUTPUT_KW
	_check("...with the firebox it had, less the %.1f kJ it has burnt since (%.1f)"
		% [spent, back.fuel], spent >= 0.0 and spent <= settled + 1.0)
	_check("the restored machine is burning what it came back with",
		back.is_burning())


	print("\n=== a save with an ash pit in it ===")
	var legacy: Array = world.builds.to_array()
	for row: Variant in legacy:
		if str((row as Dictionary).get("type", "")) == "hay_generator":
			(row as Dictionary) ["needles"] = PackedInt32Array(
				[TEST_NEEDLE, TEST_NEEDLE + 1])
	world.builds.clear()
	var old_lost: Array = []
	var old_heard:= func(type: int, _paid: float,
			_cause: GameState.NeedleLoss) -> void: old_lost.append(type)
	GameState.needle_lost.connect(old_heard)
	world.builds.from_array(legacy)
	_check("nothing is announced while the yard is still being built",
		old_lost.is_empty())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	GameState.needle_lost.disconnect(old_heard)
	_check("both banked needles are announced after the load (%d heard)"
		% old_lost.size(), old_lost.size() == 2)
	_check("...and the machine is holding none of them",
		world.builds.generators.size() == 1
			and not world.builds.generators [0].to_dict().has("needles"))

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _along(line: PackedVector3Array, t: float) -> Vector3:
	var total:= 0.0
	for i in line.size() - 1:
		total += line [i].distance_to(line [i + 1])
	var want:= clampf(t, 0.0, 1.0) * total
	for i in line.size() - 1:
		var seg:= line [i].distance_to(line [i + 1])
		if want <= seg or i == line.size() - 2:
			return line [i].lerp(line [i + 1], want / maxf(seg, 1e-06))
		want -= seg
	return line [line.size() - 1]


func _nearest_on(line: PackedVector3Array, p: Vector3) -> Vector3:
	var best:= line [0]
	var best_d:= INF
	for i in line.size() - 1:
		var ab:= line [i + 1] - line [i]
		var l2:= ab.length_squared()
		var t:= 0.0 if l2 < 1e-09 else clampf((p - line [i]).dot(ab) / l2, 0.0, 1.0)
		var q:= line [i] + ab * t
		var d:= q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


func _across(line: PackedVector3Array, at: Vector3) -> Vector3:
	var best:= Vector3.RIGHT
	var best_d:= INF
	for i in line.size() - 1:
		var mid:= (line [i] + line [i + 1]) * 0.5
		var d:= mid.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = BeltPath.run_basis(line [i], line [i + 1]).x
	return best
