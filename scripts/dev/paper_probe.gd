class_name DevPaperProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const LANE_X:= 13.0

var _pass:= 0
var _fail:= 0


var _last_drop:= Vector3.INF
var _rolls_seen:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var mill: PaperMachine = world.builds.add_paper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	mill.rolled.connect(_on_rolled)
	mill.rolled_record.connect(_on_rolled_record)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	await _case_the_model(mill)
	await _case_the_clip(mill)
	await _case_the_geometry(mill, deck_y)
	await _case_the_hologram(mill)
	await _case_snapping(mill)
	await _case_the_stubs(mill, deck_y)
	await _case_the_intake(mill)
	await _case_slabs_go_in(mill)
	await _case_one_roll(mill)
	await _case_conservation(mill)
	await _case_three_slabs(mill)
	await _case_waits_for_a_charge(mill, 0)
	await _case_waits_for_a_charge(mill, TechTree.max_rank("pulper_speed"))
	_case_the_cards()
	await _case_a_bare_needle(mill)
	await _case_it_refuses_its_own(mill)
	await _case_the_roll_rides(mill)
	await _case_outfeed_blocked(mill)
	await _case_dead(mill)
	await _case_the_save(mill)

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_model(mill: PaperMachine) -> void:
	print("\n=== the model ===")
	var model:= mill.get_node_or_null("Model")
	_check("the mill has a model", model != null)
	if model == null:
		return
	for marker: String in [PaperMachine.N_BELT_IN, PaperMachine.N_BELT_OUT,
			PaperMachine.N_FEED, PaperMachine.N_RELEASE, PaperMachine.N_PANEL]:
		_check("...and a '%s' on it" % marker,
			model.find_child(marker, true, false) != null)


	for node_name: String in [PaperMachine.N_CLIP_PULP, PaperMachine.N_CLIP_ROLL]:
		_check("...and a '%s' for the clip to drive" % node_name,
			model.find_child(node_name, true, false) != null)


	var ports:= mill.power_ports()
	_check("it offers two wire terminals, got %d" % ports.size(),
		ports.size() == 2)
	var modelled:= 0
	for port: Node3D in ports:
		if port != null and model.is_ancestor_of(port):
			modelled += 1
	_check("...and both are the model's own, not stand-ins (%d)" % modelled,
		modelled == 2)


	_check("an idle mill shows no slab in the press",
		not _visible(model, PaperMachine.N_CLIP_PULP))
	_check("...and no roll on the winder",
		not _visible(model, PaperMachine.N_CLIP_ROLL))


func _case_the_clip(mill: PaperMachine) -> void:
	print("\n=== the clip ===")
	var seconds:= mill.clip_seconds()
	_check("the model ships a '%s' clip" % PaperMachine.CLIP, seconds > 0.0)


	_check("...%.3f s long, and Cfg.PAPER_CYCLE_SECONDS says %.3f"
		% [seconds, Cfg.PAPER_CYCLE_SECONDS],
		absf(seconds - Cfg.PAPER_CYCLE_SECONDS) < 0.02)
	_check("...which is %.0f frames at %.0f fps"
		% [PaperMachine.CYCLE_FRAMES, PaperMachine.CLIP_FPS],
		absf(Cfg.PAPER_CYCLE_SECONDS
			- PaperMachine.CYCLE_FRAMES / PaperMachine.CLIP_FPS) < 0.001)


	_check("the release frame %.0f is inside the clip" % PaperMachine.F_RELEASE,
		PaperMachine.F_RELEASE > 0.0
			and PaperMachine.F_RELEASE < PaperMachine.CYCLE_FRAMES)
	_check("...and in the last quarter of it, after the cradle has tipped",
		PaperMachine.F_RELEASE > PaperMachine.CYCLE_FRAMES * 0.75)


func _case_the_geometry(mill: PaperMachine, deck_y: float) -> void:
	print("\n=== the geometry ===")
	var a:= mill.port_in()
	var b:= mill.port_out()
	var span:= a.distance_to(b)


	var want:= Cfg.PAPER_LENGTH - PaperMachine.OUT_INSET + mill.port_reach
	_check(("the ports are %.3f m apart: Cfg.PAPER_LENGTH %.2f less the %.2f the outfeed"
		+ " is set in, and the %.2f the infeed reaches out") % [span, Cfg.PAPER_LENGTH,
		PaperMachine.OUT_INSET, mill.port_reach], absf(span - want) < 0.02)


	var segments:= Cfg.PAPER_LENGTH / Cfg.BELT_SEGMENT
	_check("...which is %.2f belt segments, a whole number" % segments,
		absf(segments - roundf(segments)) < 0.001)


	_check("the infeed port is on the deck plane (%.3f, want %.3f)"
		% [a.y, deck_y], absf(a.y - deck_y) < 0.02)
	_check("...and so is the outfeed port (%.3f)" % b.y,
		absf(b.y - deck_y) < 0.02)
	_check("...and the machine's own feed point (%.3f)" % mill.feed_point().y,
		absf(mill.feed_point().y - deck_y) < 0.02)


	var spot:= mill.product_spot()
	_check("a finished roll rests on the deck (%.3f, want %.3f)"
		% [spot.y, deck_y], absf(spot.y - deck_y) < 0.03)


	var out_deck:= mill.outfeed_deck()
	_check("the mill lays an outfeed stub", out_deck != null)
	var back:= b.distance_to(spot)
	_check("...and the roll lands %.2f m inside it, which is under the %.2f it runs"
		% [back, PaperMachine.OUT_STUB], back < PaperMachine.OUT_STUB - 0.05)


	var stub:= a.distance_to(mill.feed_point())
	_check("the infeed stub is %.2f m, long enough to be a deck" % stub,
		stub > 0.3)
	_check("the mill lays an infeed stub too", mill.deck() != null)


func _case_the_hologram(mill: PaperMachine) -> void:
	print("\n=== the hologram ===")
	var ghost:= PaperMachine.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = Vector3(LANE_X, 0.43, -20.0)
	for i in 10:
		await get_tree().process_frame
	_check("a preview mill builds without a belt of its own",
		ghost.deck() == null and ghost.outfeed_deck() == null)
	_check("...and shows neither the clip's slab nor its roll",
		not _visible(ghost.get_node_or_null("Model"), PaperMachine.N_CLIP_PULP))
	ghost.set_preview_valid(false)
	ghost.set_preview_valid(true)
	_check("...and takes both ghost colours without complaint", true)
	world.remove_child(ghost)
	ghost.queue_free()


func _case_snapping(mill: PaperMachine) -> void:
	print("\n=== snapping ===")
	var builds: BuildManager = world.builds


	for named: Array in [["infeed", mill.port_in()], ["outfeed", mill.port_out()]]:
		var want: Vector3 = named [1]
		var near:= want + Vector3(0.2, 0.0, 0.0)
		var got: Vector3 = builds.snap_paper_port(near)
		_check("a point near the %s snaps to it" % named [0],
			got.distance_to(want) < 0.01)


		var endpoint: Vector3 = builds.snap_endpoint(near)
		_check("...and so does the endpoint walk every belt route uses",
			endpoint.distance_to(want) < 0.01)
	var far:= mill.port_in() + Vector3(6.0, 0.0, 0.0)
	_check("a point well clear of both is left alone",
		builds.snap_paper_port(far).distance_to(far) < 0.001)

	_check("a mill placed on top of this one is refused",
		builds.paper_overlap(mill.global_position + Vector3(1.0, 0.0, 0.0)))
	_check("...and one seven metres clear is allowed",
		not builds.paper_overlap(
			mill.global_position + Vector3(0.0, 0.0, Cfg.PAPER_LENGTH + 1.0)))


	var span:= Cfg.PAPER_HALF_WIDTH * 2.0
	_check("a mill abreast of this one, inside its width, is refused",
		builds.paper_overlap(mill.global_position + Vector3(span - 0.4, 0.0, 0.0)))
	_check("...and one just clear of the width is allowed, at %.2f m where the "
		% (span + 0.2) + "old circle wanted %.2f" % Cfg.PAPER_LENGTH,
		not builds.paper_overlap(mill.global_position + Vector3(span + 0.2, 0.0, 0.0)))


	_check("a mill lying across this one's nose is refused",
		builds.paper_overlap(mill.global_position + Vector3(0.0, 0.0, 3.0),
			Vector3.RIGHT))
	_check("...and one lying across it two metres further out is allowed",
		not builds.paper_overlap(mill.global_position + Vector3(0.0, 0.0, 5.0),
			Vector3.RIGHT))


	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, 0.43, -14.0), 0.0)
	await _settle()
	var half:= (Cfg.PAPER_LENGTH + Cfg.PULPER_LENGTH) * 0.5
	_check("a mill inside a pulper's half-length is refused",
		builds.paper_overlap(pulper.global_position
			+ Vector3(0.0, 0.0, half - 0.5)))
	_check("...and one clear of it is allowed",
		not builds.paper_overlap(pulper.global_position
			+ Vector3(0.0, 0.0, half + 0.5)))


	_check("a pulper inside a mill's half-length is refused too",
		builds.pulper_overlap(mill.global_position
			+ Vector3(0.0, 0.0, half - 0.5)))
	builds.demolish(pulper)
	await _settle()


func _case_the_stubs(mill: PaperMachine, deck_y: float) -> void:
	print("\n=== the stubs ===")
	var builds: BuildManager = world.builds
	var forward:= mill.forward()
	var feed: Conveyor = builds.add_conveyor(
		mill.port_in() - forward * 4.0, mill.port_in())
	var away: Conveyor = builds.add_conveyor(
		mill.port_out(), mill.port_out() + forward * 4.0)
	await _settle()
	_check("a run laid to the infeed exists", feed != null)
	_check("a run laid off the outfeed exists", away != null)


	_check("the arriving run hands its load to the mill's infeed stub",
		feed != null and feed.downstream == mill.deck())


	_check("the mill's outfeed stub feeds the run leaving it",
		mill.outfeed_deck() != null and mill.outfeed_deck().downstream == away)
	_check("...and its infeed stub does NOT",
		mill.deck() != null and mill.deck().downstream != away)


	_check("the run beyond reserves the square the roll lands on",
		away != null and away.head_reserve() > 0.0)
	builds.demolish(feed)
	builds.demolish(away)
	await _settle()


func _case_the_intake(mill: PaperMachine) -> void:
	print("\n=== the intake climbs ===")
	var model:= mill.get_node_or_null("Model")
	if model == null:
		_check("the mill has a model to check the intake on", false)
		return
	_check("no cleat is modelled any more, the shader draws them",
		model.find_child("Feed_cleat*", true, false) == null)

	var surface:= _belt_surface(mill)
	var mesh:= surface [0] as MeshInstance3D
	var index:= int(surface [1])
	_check("the model carries a '%s' surface" % PaperMachine.MAT_BELT, mesh != null)
	if mesh == null:
		return
	var painted:= mesh.get_surface_override_material(index) as ShaderMaterial
	_check("...wearing the yard's own belt rather than a flat off the table",
		painted != null and painted.shader == load(ConveyorKit.SHADER))
	if painted != null:
		_check("...with its cleats on", float(painted.get_shader_parameter("cleat")) > 0.5)
		_check("...at the pitch every other belt in the yard uses",
			is_equal_approx(float(painted.get_shader_parameter("cleat_pitch")),
				ConveyorKit.CLEAT_PITCH))
		_check("...scrolling at the rate the clip carries the slab (%.3f m/s)"
			% mill.belt_scroll(),
			is_equal_approx(float(painted.get_shader_parameter("speed")),
				mill.belt_scroll()))


	var arrays: Array = mesh.mesh.surface_get_arrays(index)
	var uv: PackedVector2Array = arrays [Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	_check("the belt has a UV layer at all (the active_render trap)",
		not uv.is_empty())
	if uv.is_empty() or verts.is_empty():
		return


	var into:= mill.global_transform.affine_inverse() * mesh.global_transform
	var lo:= uv [0]
	var hi:= uv [0]
	var box:= AABB(into * verts [0], Vector3.ZERO)
	for i in uv.size():
		lo = lo.min(uv [i])
		hi = hi.max(uv [i])
		box = box.expand(into * verts [i])
	var across:= hi.x - lo.x
	var along:= hi.y - lo.y
	_check("...measured across the belt in metres (%.3f against %.3f)"
		% [across, box.size.x], absf(across - box.size.x) < 0.01)


	var climb:= Vector2(box.size.y, box.size.z).length()
	_check("...and up the climb in metres (%.3f against %.3f)" % [along, climb],
		absf(along - climb) < 0.02)


	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()
	var pulp:= model.find_child(PaperMachine.N_CLIP_PULP, true, false) as Node3D
	_drop_slab(mill, 100, -1)
	await _wait_for(func() -> bool: return mill.is_running(), 8.0)
	await get_tree().physics_frame
	var start:= mill.to_local(pulp.global_position)
	var bed:= PaperMachine.PRESS_BED_ABOVE_DECK
	_check("the slab starts the cycle on the deck plane (%.2f m up)" % start.y,
		start.y < 0.15)
	_check("...at the mouth and not inside the press (%.2f m in)" % start.z,
		absf(start.z - mill.to_local(mill.feed_point()).z) < 0.15)


	var drum:= model.find_child("Feed_drum_Pivot", true, false) as Node3D
	_check("the model still names the head drum", drum != null)
	var drum_z: float = mill.to_local(drum.global_position).z if drum != null else 0.0
	var upright:= 0.0
	var turned_from_drum:= 0.0
	var went_flat:= false
	var flat_y:= 0.0
	var wander:= 0.0
	var top:= 0.0
	for i in 180:
		var at:= mill.to_local(pulp.global_position)
		var tilt:= absf(pulp.rotation.x)
		upright = maxf(upright, tilt)


		if tilt > 0.02 and tilt < upright - 0.02:
			turned_from_drum = maxf(turned_from_drum, absf(at.z - drum_z))
		elif tilt <= 0.02 and at.y > 0.3:
			if not went_flat:
				went_flat = true
				flat_y = at.y
			wander = maxf(wander, absf(at.y - flat_y))
		top = maxf(top, at.y)
		await get_tree().physics_frame
	_check("it rides up square on the belt (%.0f degrees)" % rad_to_deg(upright),
		upright > 0.6)
	_check("...and only turns while it is on the head drum (%.2f m from it)"
		% turned_from_drum, turned_from_drum < 0.36)
	_check("...and lands flat rather than arriving flat", went_flat)
	_check("...and never rises or drops again once it is flat (%.3f m)" % wander,
		wander < 0.01)


	_check("...and is on the press bed by the end of it (%.2f m up)" % top,
		top > bed - 0.05)


func _belt_surface(mill: PaperMachine) -> Array:
	var model:= mill.get_node_or_null("Model")
	if model == null:
		return [null, -1]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh:= node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.mesh.surface_get_material(i)
			if src != null and src.resource_name == PaperMachine.MAT_BELT:
				return [mesh, i]
	return [null, -1]


func _case_slabs_go_in(mill: PaperMachine) -> void:
	print("\n=== slabs go in ===")
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()
	var slab:= _drop_slab(mill, 120, 7)
	_check("a slab was spawned at the mouth", slab != null)


	var took:= func() -> bool:
		return mill.queued.has(120) or (mill.is_running() and mill._batch == 120)
	await _wait_for(took, 8.0)
	_check("...and the mill swallowed it (queue %s, pressing %d)"
		% [str(mill.queued), mill._batch], bool(took.call()))

	_check("...and the needle that was inside it went with it",
		mill.queued_needles.has(7) or mill._batch_needle == 7)
	_check("...and the slab itself is gone off the deck",
		slab == null or not is_instance_valid(slab))


	var cap:= mill.buffer_capacity()
	for i in cap + 2:
		_drop_slab(mill, 90, -1)
		await _settle(6)
	await _settle(30)
	_check("the queue never grows past its capacity (%d/%d)"
		% [mill.queued.size(), cap], mill.queued.size() <= cap)


func _case_one_roll(mill: PaperMachine) -> void:
	print("\n=== one slab, one roll ===")
	_clear_rolls()
	_rolls_seen = 0

	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()
	_drop_slab(mill, 150, 3)
	await _wait_for(func() -> bool: return _rolls_seen > 0,
		Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)
	_check("one slab made one roll (%d)" % _rolls_seen, _rolls_seen == 1)


	if _last_drop != Vector3.INF:
		var want:= mill.product_spot()
		var off:= Vector2(_last_drop.x - want.x, _last_drop.z - want.z).length()
		_check("...set down within 5 cm of Marker_Release (%.3f m off)" % off, off < 0.05)


	_check("the modelled roll is hidden once the real one exists",
		not _visible(mill.get_node_or_null("Model"), PaperMachine.N_CLIP_ROLL))
	await _settle(40)
	_check("...and no second roll appears from the same slab (%d)" % _rolls_seen,
		_rolls_seen == 1)


func _case_three_slabs(mill: PaperMachine) -> void:
	print("\n=== three slabs, one roll ===")
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill.pending_needles = PackedInt32Array()
	mill._run = -1.0
	await _settle()
	mill.queued.append_array([100, 120, 140])
	mill.queued_needles.append_array([-1, 7, 9])
	await _wait_for(func() -> bool: return _rolls_seen > 0,
		Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)
	var made:= _rolls_in_hand()
	_check("three slabs made one roll (%d)" % _rolls_seen, _rolls_seen == 1)
	_check("...and the queue is empty behind it (%d)" % mill.queued.size(),
		mill.queued.is_empty())
	if made.is_empty():
		return
	var roll: PaperRoll = made [0]
	_check("...holding all 360 strands that went in (%d)" % roll.strands,
		roll.strands == 360)
	_check("...and the first needle of the charge (%d)" % roll.needle_index,
		roll.needle_index == 7)
	_check("...with the other one waiting for the next roll (%s)"
		% str(Array(mill.pending_needles)),
		Array(mill.pending_needles) == [9])
	await _settle(40)
	_check("...and no second roll appears from the same charge (%d)" % _rolls_seen,
		_rolls_seen == 1)
	mill.pending_needles = PackedInt32Array()


func _case_waits_for_a_charge(mill: PaperMachine, speed_rank: int) -> void:
	Tech.grant("pulper_speed", speed_rank)
	var pace:= Tech.pulper_cycle_seconds()
	print("\n=== slabs at a pulper's pace (Faster Drum %d, one every %.2f s) ==="
		% [speed_rank, pace])
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill.pending_needles = PackedInt32Array()
	mill._run = -1.0


	mill.arrival_gap = -1.0
	mill._seen_arrival = false
	await _wait_for(func() -> bool: return not mill.is_running(),
		Cfg.PAPER_CYCLE_SECONDS * 2.0)
	await _settle()
	var frames:= int(round(pace * 60.0))
	for i in Cfg.PAPER_SLABS_PER_ROLL:
		_drop_slab(mill, 100 + i, -1)
		if i < Cfg.PAPER_SLABS_PER_ROLL - 1:
			await _settle(frames)
	await _wait_for(func() -> bool: return _rolls_seen > 0,
		Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)
	var made:= _rolls_in_hand()
	_check("the slabs made one roll (%d)" % _rolls_seen, _rolls_seen == 1)
	if not made.is_empty():
		var roll: PaperRoll = made [0]
		_check("...holding all three slabs, 303 strands (%d)" % roll.strands,
			roll.strands == 303)
	_check("...and the mill measured the line's pace, %.2f s against %.2f"
		% [mill.arrival_gap, pace], absf(mill.arrival_gap - pace) < 0.25)
	_check("...so it waits %.2f s for a short charge, longer than that pace"
		% mill.charge_wait(), mill.charge_wait() > pace)
	await _settle(40)
	Tech.grant("pulper_speed", 0)


func _case_the_cards() -> void:
	print("\n=== the cards follow the ranks ===")
	TechTree.nodes()
	BuildCatalog.entries()
	Tech.grant("pulper_batch", TechTree.max_rank("pulper_batch"))
	Tech.grant("pulp_quality", TechTree.max_rank("pulp_quality"))
	Tech.grant("paper_quality", TechTree.max_rank("paper_quality"))
	var straw:= "%d" % Tech.pulper_batch_strands()
	var pulp:= "%.1fx" % Tech.pulp_value_ratio()
	var paper:= "%.2fx" % Tech.paper_value_ratio()
	var plans:= TechTree.blurb("pulper")
	_check("the Pulper Plans card says %s straw and %s" % [straw, pulp],
		plans.contains(straw) and plans.contains(pulp))
	var build:= BuildCatalog.blurb("pulper")
	_check("...and so does the pulper's build card", build.contains(straw) and build.contains(pulp))
	_check("the Paper Mill Plans card says %s" % paper, TechTree.blurb("paper_machine").contains(paper))
	var mill:= BuildCatalog.blurb("paper_machine")
	_check("...and so does the mill's build card, with %d slabs to a roll" % Cfg.PAPER_SLABS_PER_ROLL,
		mill.contains(paper) and mill.contains("%d" % Cfg.PAPER_SLABS_PER_ROLL))
	Tech.grant("pulper_batch", 0)
	Tech.grant("pulp_quality", 0)
	Tech.grant("paper_quality", 0)


func _case_conservation(mill: PaperMachine) -> void:
	print("\n=== the count travels through ===")
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()
	_drop_slab(mill, 211, 5)
	await _wait_for(func() -> bool: return _rolls_seen > 0,
		Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)
	var made:= _rolls_in_hand()
	_check("a roll came out", made.size() > 0)
	if made.is_empty():
		return
	var roll: PaperRoll = made [0]


	_check("...holding the 211 strands that went in (%d)" % roll.strands,
		roll.strands == 211)
	_check("...and the needle that was in the slab (%d)" % roll.needle_index,
		roll.needle_index == 5)


	var want:= 211.0 * Tech.pulp_value_ratio() * Tech.paper_value_ratio()
	_check("...worth %.1f, the pulp ratio times the paper one (%.1f)"
		% [roll.sale_strands(), want],
		absf(roll.sale_strands() - want) < 0.01)
	_check("...while the hay actually in it is still 211 (%d)"
		% roll.hay_strands(), roll.hay_strands() == 211)


	_check("...and a roll beats the slab it was made from",
		Tech.paper_value_ratio() > 1.0)


func _case_a_bare_needle(mill: PaperMachine) -> void:
	print("\r\n=== a bare needle goes in too ===")
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill.pending_needles = PackedInt32Array()
	mill._run = -1.0
	await _settle()

	var at: Vector3 = mill.feed_point() + Vector3(0.0, 0.1, 0.0)
	var index:= GameState.register_needle(at, null, 0)
	GameState.needle_taken [index] = 1
	var needle: RigidBody3D = world.live.reveal_needle(index, at)
	_check("a needle was laid on the mill's own deck", needle != null)
	if needle == null:
		return


	await _wait_for(func() -> bool: return not is_instance_valid(needle), 6.0)
	_check("the mill swallowed it", not is_instance_valid(needle))
	_check("...and is holding it for the next roll (%s)"
		% str(Array(mill.pending_needles)),
		Array(mill.pending_needles).has(index))
	_check("...without putting anything in the queue (%d)" % mill.queued.size(),
		mill.queued.is_empty())


	var wad: HayWad = world.props.spawn("hay_wad",
		Transform3D(Basis(), at), { "strands": 30 }) as HayWad
	_check("a wad was stood at the mouth", wad != null)
	await _settle(60)


	_check("...and the mill left it alone (%d wads in the world)" % _count("hay_wad"),
		_count("hay_wad") == 1)
	_clear_kind("hay_wad")
	await _settle()


	_drop_slab(mill, 120, -1)
	await _wait_for(func() -> bool: return _rolls_seen > 0,
		Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)
	var made:= _rolls_in_hand()
	_check("a roll came out", made.size() > 0)
	if made.is_empty():
		return
	var roll: PaperRoll = made [0]
	_check("...carrying the needle that arrived on its own (%d)"
		% roll.needle_index, roll.needle_index == index)
	_check("...and the mill is not still holding it",
		not Array(mill.pending_needles).has(index))


	mill.queued.clear()
	mill.queued_needles.clear()
	mill.queued.append(60)
	mill.queued_needles.append(7)
	mill.pending_needles = PackedInt32Array([9])
	mill._batch_needle = 8
	var held:= Array(mill.held_needles())
	_check("a mill names every needle in it (%s)" % str(held),
		held.has(7) and held.has(8) and held.has(9) and held.size() == 3)
	mill.queued.clear()
	mill.queued_needles.clear()
	mill.pending_needles = PackedInt32Array()
	mill._batch_needle = -1
	_clear_rolls()
	await _settle()


func _case_it_refuses_its_own(mill: PaperMachine) -> void:
	print("\n=== it refuses its own product ===")
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()
	var before:= mill.queued.size()

	var roll:= world.props.spawn("paper_roll",
		Transform3D(Basis(), mill.feed_point() + Vector3(0, 0.15, 0))) as PaperRoll
	_check("a roll was stood at the mouth", roll != null)
	await _settle(60)
	_check("...and the mill did not swallow it (queue %d)" % mill.queued.size(),
		mill.queued.size() == before)

	_clear_rolls()
	await _settle()


func _case_the_roll_rides(mill: PaperMachine) -> void:
	print("\n=== the roll rides away ===")
	var builds: BuildManager = world.builds
	var away: Conveyor = builds.add_conveyor(
		mill.port_out(), mill.port_out() + mill.forward() * 6.0)
	await _settle()
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()
	_drop_slab(mill, 90, -1)
	await _wait_for(func() -> bool: return _rolls_seen > 0,
		Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)


	var seq:= _last_pushed_seq
	var where:= BeltPath.record_where(seq) if seq >= 0 else { }
	_check("a roll came out to ride", not where.is_empty())
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
		return travelled [0] > 1.0
	await _wait_for(moved, 12.0)
	_check("...and travelled %.2f m down the run" % travelled [0], travelled [0] > 1.0)
	builds.demolish(away)
	await _settle()


func _case_outfeed_blocked(mill: PaperMachine) -> void:
	print("\n=== a blocked outfeed stops the machine ===")
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()


	var blocker:= world.props.spawn("paper_roll", Transform3D(
		mill.global_basis, mill.product_spot() + Vector3.UP * 0.02)) as PaperRoll
	_check("a roll is standing on the outfeed", blocker != null)
	if blocker == null:
		return


	blocker.freeze = true
	await _settle()
	_drop_slab(mill, 90, -1)
	var jammed:= func() -> bool: return mill.alert_reason().begins_with("OUTFEED")
	await _wait_for(jammed, Cfg.PAPER_CYCLE_SECONDS * 3.0 + 8.0)


	_check("the mill says its outfeed is blocked ('%s')" % mill.alert_reason(),
		mill.alert_reason().begins_with("OUTFEED"))
	_check("...and has made no roll (%d)" % _rolls_seen, _rolls_seen == 0)
	_check("...and is still holding the cycle", mill.is_running())
	if blocker != null and is_instance_valid(blocker):
		world.props.remove(blocker)


	await _wait_for(func() -> bool: return _rolls_seen > 0, 12.0)
	print("  after the deck cleared: %d rolls in the world, %d records on the stub, running %s, says '%s'"
		% [_count("paper_roll"), mill._out_belt.run.count(), str(mill.is_running()),
			mill.alert_reason()])
	_check("...and delivers as soon as the deck is clear (%d)" % _rolls_seen,
		_rolls_seen == 1)


func _case_dead(mill: PaperMachine) -> void:
	print("\n=== a dead mill stands still ===")
	_clear_rolls()
	_rolls_seen = 0
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	await _settle()


	var was: bool = world.builds.grid.unmetered
	world.builds.grid.unmetered = false
	world.builds.grid.rebuild()
	await _settle(20)
	_check("with nothing wired, the mill has no power (%.2f)" % mill.power,
		mill.power <= 0.0)
	_check("...and says so rather than blaming the belt ('%s')"
		% mill.alert_reason(), mill.alert_reason() != ""
			and not mill.alert_reason().begins_with("NO PULP"))
	_check("...and its alert icon is the power one", mill.alert_icon() == "power")
	_drop_slab(mill, 90, -1)
	await _settle(90)


	_check("...and it starts no cycle with a slab waiting",
		not mill.is_running())
	_check("...and makes no roll (%d)" % _rolls_seen, _rolls_seen == 0)
	_check("...and draws nothing while switched off",
		_draw_switched_off(mill) == 0.0)
	world.builds.grid.unmetered = was
	world.builds.grid.rebuild()
	await _settle(20)
	_check("...and comes back when the meter does (%.2f)" % mill.power,
		mill.power > 0.0)


func _case_the_save(mill: PaperMachine) -> void:
	print("\n=== save and load ===")
	mill.queued.clear()
	mill.queued_needles.clear()
	mill._run = -1.0
	mill.pending_needles = PackedInt32Array()
	mill.queued.append(131)
	mill.queued.append(97)
	mill.queued_needles.append(11)
	mill.queued_needles.append(-1)
	var d:= mill.to_dict()
	_check("the mill saves under its own type", str(d.get("type", "")) == "paper_machine")
	var back:= PaperMachine.new()
	back.from_dict(d)
	_check("...and the queue comes back as it went in (%s)" % str(back.queued),
		back.queued == mill.queued)
	_check("...and so do the needles (%s)" % str(back.queued_needles),
		back.queued_needles == mill.queued_needles)


	var older:= d.duplicate(true)
	older.erase("queued_needles")
	var old_load:= PaperMachine.new()
	old_load.from_dict(older)
	_check("a save written before needles existed loads with none",
		old_load.queued_needles.size() == old_load.queued.size()
			and not old_load.queued_needles.has(11))


	var fat:= d.duplicate(true)
	var many: Array = []
	for i in mill.buffer_capacity() + 4:
		many.append(90)
	fat ["queued"] = many
	fat ["queued_needles"] = []
	var fat_load:= PaperMachine.new()
	fat_load.from_dict(fat)
	_check("an over-full save is trimmed to capacity (%d/%d)"
		% [fat_load.queued.size(), fat_load.buffer_capacity()],
		fat_load.queued.size() == fat_load.buffer_capacity())


	var mid:= d.duplicate(true)
	mid ["running_needle"] = 42
	var mid_load:= PaperMachine.new()
	mid_load.from_dict(mid)
	_check("a needle in the press comes back on the orphan list",
		Array(mid_load.pending_needles).has(42))
	back.queue_free()
	old_load.queue_free()
	fat_load.queue_free()
	mid_load.queue_free()


func _on_rolled(roll: Node3D) -> void:
	_rolls_seen += 1
	_last_drop = roll.global_position


func _drop_slab(mill: PaperMachine, strands: int, needle: int) -> HayPulp:
	var at:= mill.feed_point() + Vector3(0.0, 0.12, 0.0)
	var slab:= world.props.spawn("hay_pulp",
		Transform3D(Basis(), at)) as HayPulp
	if slab != null:
		slab.strands = strands
		slab.needle_index = needle
	return slab


func _rolls() -> Array:
	var out: Array = []
	for item in world.props.items:
		if is_instance_valid(item) and item is PaperRoll:
			out.append(item)
	return out


func _clear_rolls() -> void:
	for roll: PaperRoll in _rolls():
		world.props.remove(roll)
	_clear_records("paper_roll")
	_last_drop = Vector3.INF


var _last_pushed_seq:= -1
func _on_rolled_record(seq: int) -> void:
	_rolls_seen += 1
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


func _rolls_in_hand() -> Array:
	for seq: int in _records_of("paper_roll"):
		var where:= BeltPath.record_where(seq)
		if not where.is_empty():
			(where ["path"] as BeltPath).materialize_record(int(where ["row"]))
	return _rolls()


func _draw_switched_off(mill: PaperMachine) -> float:
	var was:= mill.is_switched_off()
	mill.set_switched_off(true)
	var kw:= mill.draw_kw()
	mill.set_switched_off(was)
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


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
