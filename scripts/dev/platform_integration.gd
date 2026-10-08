extends Node3D


var _pass:= 0
var _fail:= 0


func _ready() -> void:
	_floor()
	var builds:= BuildManager.new()
	add_child(builds)
	await get_tree().process_frame
	await get_tree().physics_frame


	var deck:= builds.add_platform(Vector3(0.0, 4.0, 0.0), Vector2(8.0, 8.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var deck_top:= deck.top_y()
	var belt_y:= deck_top + Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var belt:= builds.add_conveyor(Vector3(-3.0, belt_y, 0.0), Vector3(3.0, belt_y, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


	var post:= Vector3(0.0, belt_y - Cfg.BELT_SUPPORT_ATTACH_DEPTH, 0.0)
	var q:= PhysicsRayQueryParameters3D.create(post,
		post - Vector3(0.0, Cfg.BELT_SUPPORT_MAX_DROP, 0.0))
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.exclude = belt._own_bodies()
	var under: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	_is("belt trestle lands on the deck",
		"%.2f" % (under ["position"].y if not under.is_empty() else -99.0),
		"%.2f" % deck_top)


	_is("owner_of a deck collider resolves to the deck",
		builds.owner_of(deck.get_node("DeckCollision")), deck)


	_is("belt on the deck counts as standing on it",
		builds.standing_on(deck), [belt] as Array [Node3D])
	_is("loaded deck refuses demolition",
		builds.demolish_blocked_reason(deck), "clear 1 from the deck first")
	_is("refused demolition refunds nothing", builds.demolish(deck), 0.0)
	_is("deck survived the refusal", builds.platforms.size(), 1)

	var belt_refund:= builds.demolish(belt)
	_is("belt refunds its full price", "%.1f" % belt_refund,
		"%.1f" % Conveyor.cost_for(Vector3(-3.0, belt_y, 0.0), Vector3(3.0, belt_y, 0.0)))
	_is("empty deck allows demolition", builds.demolish_blocked_reason(deck), "")


	_is("a deck on top of the first is rejected",
		builds.deck_overlap(Rect2(Vector2(-2, -2), Vector2(4, 4)), 4.0), true)
	_is("a deck beside it is allowed",
		builds.deck_overlap(Rect2(Vector2(5, -2), Vector2(4, 4)), 4.0), false)
	_is("a deck a storey above is allowed",
		builds.deck_overlap(Rect2(Vector2(-2, -2), Vector2(4, 4)), 8.0), false)


	_is("a near corner snaps flush to the deck edge",
		builds.snap_deck_corner(Vector2(4.6, 0.0), 4.0), Vector2(4.0, 0.0))
	_is("a far corner is left alone",
		builds.snap_deck_corner(Vector2(7.0, 0.0), 4.0), Vector2(7.0, 0.0))
	_is("a corner at another height does not snap",
		builds.snap_deck_corner(Vector2(4.6, 0.0), 8.0), Vector2(4.6, 0.0))


	var upper:= builds.add_platform(Vector3(0.0, 10.0, 0.0), Vector2(4.0, 4.0))
	await get_tree().physics_frame
	var middle:= builds.add_platform(Vector3(0.0, 7.0, 0.0), Vector2(4.0, 4.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_is("a deck with a storey over it can still be dismantled",
		builds.demolish_blocked_reason(deck), "")
	_is("and so can the one in between", builds.demolish_blocked_reason(middle), "")
	_is("taking the middle one out refunds it",
		builds.demolish(middle) > 0.0, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	builds.demolish(upper)
	await get_tree().physics_frame
	_is("and only the first deck is left", builds.platforms.size(), 1)


	builds.add_robotic_arm(Vector3(0.0, 0.0, 0.0), 0.0, 1)
	await get_tree().process_frame
	_is("a second arm beside the first still conflicts",
		builds.arm_reach_conflict(Vector3(1.5, 0.0, 0.0), 1), true)
	_is("an arm a deck above does not conflict",
		builds.arm_reach_conflict(Vector3(1.5, 4.0, 0.0), 1), false)


	builds.add_conveyor(Vector3(-3.0, belt_y, 0.0), Vector3(3.0, belt_y, 0.0))
	builds.add_platform(Vector3(0.0, 8.0, 0.0), Vector2(4.0, 4.0))
	var saved:= builds.to_array()
	_is("platforms are written before what stands on them",
		[saved [0] ["type"], saved [1] ["type"], saved [2] ["type"], saved [3] ["type"]],
		["platform", "platform", "conveyor", "robotic_arm"])
	_is("decks are written low to high",
		[saved [0] ["position"].y, saved [1] ["position"].y], [4.0, 8.0])

	builds.from_array(saved)
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	_is("round trip restores every deck", builds.platforms.size(), 2)
	_is("round trip restores the belt", builds.conveyors.size(), 1)
	_is("round trip restores the arm", builds.robotic_arms.size(), 1)
	_is("round trip keeps the deck span", builds.platforms [0].span, Vector2(8.0, 8.0))
	_is("round trip keeps the deck height", builds.platforms [1].top_y(), 8.0)


	_is("pointing at a deck gives that deck's own height",
		builds.deck_height_at(builds.platforms [0].get_node("DeckCollision")), 4.0)
	_is("pointing at anything else gives no height",
		builds.deck_height_at(null), null)


	_is("one axis snaps without disturbing the other",
		builds.snap_deck_axis(4.55, 0, 4.0), 4.0)


	_is("and leaves a coordinate nowhere near an edge alone",
		builds.snap_deck_axis(6.0, 1, 4.0), 6.0)
	_is("a coordinate at another height never snaps",
		builds.snap_deck_axis(4.05, 0, 9.0), 4.05)


	_is("dragging forward keeps the tile's near edge",
		builds.deck_extent(24.5, 20.0, 2.0, 0, 99.0), Vector2(20.0, 24.0))
	_is("dragging backward keeps the tile's FAR edge",
		builds.deck_extent(17.5, 20.0, 2.0, 0, 99.0), Vector2(18.0, 22.0))
	_is("a crosshair still inside the tile leaves it alone",
		builds.deck_extent(21.0, 20.0, 2.0, 0, 99.0), Vector2(20.0, 22.0))


	_is("just past the far edge is still one tile",
		builds.deck_extent(22.001, 20.0, 2.0, 0, 99.0), Vector2(20.0, 22.0))
	_is("just short of the near edge is still one tile",
		builds.deck_extent(19.999, 20.0, 2.0, 0, 99.0), Vector2(20.0, 22.0))


	_is("a quantised far edge still lands flush on a neighbour",
		builds.deck_extent(4.1, 6.0, 2.0, 0, 4.0), Vector2(4.0, 8.0))


	_is("snapping never collapses a deck below the minimum",
		builds.deck_extent(3.4, 3.5, 2.0, 0, 4.0), Vector2(3.5, 5.5))


	_is("a low lip takes the neighbour's far edge",
		builds.snap_deck_axis(3.5, 0, 4.0, 1), 4.0)
	_is("...and is not dragged onto its near edge instead",
		builds.snap_deck_axis(-3.5, 0, 4.0, 1), -3.5)
	_is("a high lip takes the neighbour's near edge",
		builds.snap_deck_axis(-3.5, 0, 4.0, -1), -4.0)
	_is("...and is not dragged onto its far edge instead",
		builds.snap_deck_axis(3.5, 0, 4.0, -1), 3.5)


	_is("a deck alongside in the other axis still snaps",
		builds.snap_deck_axis(4.4, 0, 4.0, 1, Vector2(-2.0, 2.0)), 4.0)
	_is("a deck nowhere near in the other axis does not",
		builds.snap_deck_axis(4.4, 0, 4.0, 1, Vector2(38.0, 42.0)), 4.4)


	var band:= Cfg.PLATFORM_THICK * 0.5
	_is("a deck a hair out of level still counts as a neighbour",
		builds.snap_deck_axis(4.4, 0, 4.0 + band, 1), 4.0)
	_is("...and that is the same band overlap refuses within",
		builds.deck_overlap(Rect2(Vector2(-2, -2), Vector2(4, 4)), 4.0 + band), true)
	_is("a deck a whole storey out is still not one",
		builds.snap_deck_axis(4.4, 0, 9.0, 1), 4.4)


	_is("ground beside a deck adopts that deck's surface",
		builds.snap_deck_height(Vector3(4.6, 4.0 + band, 0.0)), 4.0)


	_is("...but only within reach of it",
		"%.2f" % builds.snap_deck_height(Vector3(40.0, 4.0 + band, 0.0)),
		"%.2f" % (4.0 + band))
	_is("...and never across a storey",
		builds.snap_deck_height(Vector3(4.6, 9.0, 0.0)), 9.0)


	builds.from_array([])
	await get_tree().process_frame
	var a:= builds.add_platform(Vector3(0.0, 4.0, 0.0), Vector2(8.0, 8.0))
	await get_tree().process_frame
	_is("a new deck carries no railing", a.get_node_or_null("Railings"), null)
	_is("and none appear when a neighbour is butted onto it",
		builds.add_platform(Vector3(8.0, 4.0, 0.0), Vector2(8.0, 8.0))
			.get_node_or_null("Railings"), null)


	var r0:= builds.snap_railing_point(Vector3(-4.3, 4.0, -3.6))
	var r1:= builds.snap_railing_point(Vector3(-3.7, 4.0, 4.4))
	_is("a rough end snaps to the deck corner", r0, Vector3(-4.0, 4.0, -4.0))
	_is("and so does the other", r1, Vector3(-4.0, 4.0, 4.0))
	_is("an end out in the open is left alone",
		builds.snap_railing_point(Vector3(-20.0, 4.0, 0.0)),
		Vector3(-20.0, 4.0, 0.0))


	_is("mid-edge falls back to the edge line",
		builds.snap_railing_point(Vector3(-4.4, 4.0, 0.0)),
		Vector3(-4.0, 4.0, 0.0))


	var here:= Vector3(0.0, 4.0, 0.0)
	var stub:= Railing.new()
	stub.placement_preview = true
	stub.aim_marker = true
	add_child(stub)
	stub.set_shape(here, here)
	await get_tree().process_frame
	_is("the aim marker is a single post",
		(stub.get_node("Posts") as MultiMeshInstance3D).multimesh.instance_count, 1)
	_is("...standing on the aim point itself", stub.global_position, here)
	_is("...with no rail hanging off it", stub.get_node("Rail").visible, false)


	stub.set_aim_marker(false)
	stub.set_shape(here, here + Vector3(3.0, 0.0, 0.0))
	_is("a run anchored from it stands its posts",
		(stub.get_node("Posts") as MultiMeshInstance3D).multimesh.instance_count, 3)
	_is("...and runs a rail across them", stub.get_node("Rail").visible, true)


	stub.set_aim_marker(true)
	stub.set_shape(here, here)
	_is("...and going back to one post does not need the shape to move",
		(stub.get_node("Posts") as MultiMeshInstance3D).multimesh.instance_count, 1)
	_is("...nor to leave the rail behind", stub.get_node("Rail").visible, false)
	stub.queue_free()

	var rail:= builds.add_railing(r0, r1)
	await get_tree().process_frame
	await get_tree().physics_frame
	_is("a railing is 8 m of rail", "%.2f" % rail.length, "8.00")
	_is("and is priced by the metre", "%.1f" % rail.build_cost(),
		"%.1f" % (8.0 * Cfg.RAILING_COST_PER_M))


	_is("a railing has a collider", rail.get_node_or_null("BarrierCollision") != null, true)
	_is("its collider is a full-height wall along the run",
		(rail.get_node("BarrierCollision").shape as BoxShape3D).size,
		Vector3(Railing.COLLIDER_THICK, Cfg.PLATFORM_RAIL_H, 8.0))
	_is("and it is on the layer buildings collide on", rail.collision_layer, Cfg.L_BUILD)


	_is("its collider stands on the deck, not in it",
		"%.3f" % (rail.get_node("BarrierCollision").global_position.y - 4.0),
		"%.3f" % (Cfg.PLATFORM_RAIL_H * 0.5))


	_is("a rail along the deck edge is supported",
		builds.railing_unsupported(r0, r1), false)
	_is("a rail on the floor is supported",
		builds.railing_unsupported(Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)),
		false)
	_is("a rail out over open air is refused",
		builds.railing_unsupported(Vector3(-30.0, 4.0, 0.0), Vector3(-26.0, 4.0, 0.0)),
		true)


	_is("a rail running off the end of the deck is refused",
		builds.railing_unsupported(Vector3(0.0, 4.0, 0.0), Vector3(14.0, 4.0, 0.0)),
		true)


	_is("a rail slung below the deck is refused",
		builds.railing_unsupported(Vector3(-2.0, 2.0, 0.0), Vector3(2.0, 2.0, 0.0)),
		true)

	_is("a second rail on the same line is refused",
		builds.railing_overlap(r0, r1), true)
	_is("but one along a different edge is not",
		builds.railing_overlap(Vector3(4.0, 4.0, -4.0), Vector3(4.0, 4.0, 4.0)), false)


	var edge_a:= Vector3(-4.0, 4.0, -4.0)
	var edge_b:= Vector3(4.0, 4.0, -4.0)
	_is("a rail meeting another at a corner is not blocked",
		builds.railing_blocked(edge_a, edge_b), false)
	var across:= builds.add_wall(Vector3(0.0, 4.0, -5.0), Vector3(0.0, 4.0, -3.0),
		YardWall.Bay.SOLID)
	await get_tree().process_frame
	await get_tree().physics_frame
	_is("a rail through a wall is blocked",
		builds.railing_blocked(edge_a, edge_b), true)
	builds.demolish(across)
	await get_tree().process_frame
	await get_tree().physics_frame
	_is("and clear again once the wall is gone",
		builds.railing_blocked(edge_a, edge_b), false)


	_is("a roof reaching off the deck edge is not through it",
		builds.roof_through_deck(edge_a, edge_b, Roof.Kind.FLAT, 1), false)
	_is("a roof reaching in over the deck is",
		builds.roof_through_deck(edge_a, edge_b, Roof.Kind.FLAT, -1), true)
	_is("and so is an angled one",
		builds.roof_through_deck(edge_a, edge_b, Roof.Kind.PITCHED, -1), true)


	_is("a roof over open air is not blocked",
		builds.roof_blocked(edge_a, edge_b, Roof.Kind.FLAT, 1), false)
	var low_wall:= builds.add_wall(Vector3(-2.0, 2.0, -5.0), Vector3(2.0, 2.0, -5.0),
		YardWall.Bay.SOLID)
	await get_tree().process_frame
	await get_tree().physics_frame
	_is("a flat roof through a wall top is blocked",
		builds.roof_blocked(edge_a, edge_b, Roof.Kind.FLAT, 1), true)
	_is("an angled roof clearing the same wall is not",
		builds.roof_blocked(edge_a, edge_b, Roof.Kind.PITCHED, 1), false)
	builds.demolish(low_wall)
	await get_tree().process_frame
	await get_tree().physics_frame


	_is("a wall stood up through a deck is blocked",
		builds.wall_blocked(Vector3(0.0, 2.0, -2.0), Vector3(0.0, 2.0, 2.0)), true)
	_is("a wall holding up the deck's edge is not",
		builds.wall_blocked(Vector3(-4.0, 1.6, -2.0), Vector3(-4.0, 1.6, 2.0)), false)
	_is("nor one holding up its middle",
		builds.wall_blocked(Vector3(0.0, 1.6, -2.0), Vector3(0.0, 1.6, 2.0)), false)

	_is("a railing on a deck blocks its demolition",
		builds.demolish_blocked_reason(a) != "", true)
	_is("dismantling a railing refunds it in full",
		"%.1f" % builds.demolish(rail), "%.1f" % (8.0 * Cfg.RAILING_COST_PER_M))
	_is("and the deck is then clear", builds.demolish_blocked_reason(a), "")


	var edge: Dictionary = a.nearest_edge(Vector3(-9.0, 4.0, 0.0))
	_is("the near edge of a deck is its -X side", edge ["outward"], Vector3.LEFT)
	_is("and the head sits on that edge", edge ["point"], Vector3(-4.0, 4.0, 0.0))

	var yaw:= atan2(- edge ["outward"].x, - edge ["outward"].z)
	var flight:= builds.add_stair(edge ["point"], yaw, 4.0)
	await get_tree().process_frame
	await get_tree().physics_frame
	_is("a flight lands at the floor", "%.2f" % flight.foot().y, "0.00")
	_is("and reaches out by rise / pitch",
		"%.2f" % flight.foot().x, "%.2f" % (-4.0 - 4.0 / Cfg.STAIR_PITCH))
	_is("a flight is priced along its slope", "%.1f" % flight.build_cost(),
		"%.1f" % (sqrt(pow(4.0 / Cfg.STAIR_PITCH, 2.0) + 16.0) * Cfg.STAIR_COST_PER_M))


	var shallow:= builds.add_stair(
		Vector3(-4.0, 4.0, 3.0), yaw, 4.0, Cfg.STAIR_PITCH_MIN)
	await get_tree().process_frame
	await get_tree().physics_frame
	_is("a shallow flight reaches out by rise / its OWN pitch",
		"%.2f" % shallow.foot().x, "%.2f" % (-4.0 - 4.0 / Cfg.STAIR_PITCH_MIN))
	_is("and still lands at the floor", "%.2f" % shallow.foot().y, "0.00")
	_is("and costs more than the steeper flight for the same drop",
		shallow.build_cost() > flight.build_cost(), true)
	_is("a pitch outside the band is clamped rather than obeyed",
		builds.add_stair(Vector3(-4.0, 4.0, -3.0), yaw, 4.0, 9.0).pitch,
		Cfg.STAIR_PITCH_MAX)
	builds.demolish(shallow)
	builds.demolish(builds.stairs [builds.stairs.size() - 1])

	_is("a stair on a deck blocks its demolition",
		builds.demolish_blocked_reason(a) != "", true)
	var flight_cost:= flight.build_cost()
	_is("dismantling a flight refunds it in full",
		"%.1f" % builds.demolish(flight), "%.1f" % flight_cost)
	_is("and the deck is then clear again", builds.demolish_blocked_reason(a), "")


	builds.add_stair(edge ["point"], yaw, 4.0, Cfg.STAIR_PITCH_MAX)
	builds.add_railing(r0, r1)
	var saved2:= builds.to_array()


	_is("everything is written after the decks it stands on",
		[saved2 [0] ["type"], saved2 [1] ["type"], saved2 [2] ["type"], saved2 [3] ["type"]],
		["platform", "platform", "stair", "railing"])
	builds.from_array(saved2)
	for _j in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	_is("round trip restores the stair", builds.stairs.size(), 1)
	_is("round trip keeps its rise", builds.stairs [0].rise, 4.0)
	_is("round trip keeps its pitch", builds.stairs [0].pitch, Cfg.STAIR_PITCH_MAX)
	_is("round trip restores the railing", builds.railings.size(), 1)
	_is("round trip keeps its ends",
		[builds.railings [0].a, builds.railings [0].b], [r0, r1])
	_is("and rebuilds its collider",
		builds.railings [0].get_node_or_null("BarrierCollision") != null, true)


	builds.from_array([])
	await get_tree().process_frame
	var tiles: Array [Platform] = []
	for ix in 4:
		for iz in 2:
			tiles.append(builds.add_platform(
				Vector3(21.0 + 2.0 * ix, 4.0, 21.0 + 2.0 * iz), Vector2(2.0, 2.0)))
	for _k in 3:
		await get_tree().process_frame
		await get_tree().physics_frame
	var standing:= 0
	for tile in tiles:

		var legs:= tile.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
		standing += legs.multimesh.instance_count if legs != null else 0
	_is("a floor of eight tiles stands on one grid of legs", standing, 4)
	var whole:= builds.add_platform(Vector3(-20.0, 4.0, -20.0), Vector2(8.0, 4.0))
	for _k in 3:
		await get_tree().process_frame
		await get_tree().physics_frame
	_is("...the same legs a single deck that size gets",
		(whole.get_node("Supports/Legs") as MultiMeshInstance3D).multimesh.instance_count, 4)


	for tile in tiles.slice(1):
		builds.demolish(tile)
	for _k in 3:
		await get_tree().process_frame
		await get_tree().physics_frame
	_is("a tile left alone stands on its own four",
		(tiles [0].get_node("Supports/Legs") as MultiMeshInstance3D).multimesh.instance_count, 4)

	print("\n%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _floor() -> void:
	var body:= StaticBody3D.new()
	body.collision_layer = Cfg.L_WORLD
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)


func _is(what: String, got: Variant, want: Variant) -> void:
	if got == want:
		_pass += 1
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("  FAIL %s\n         got  %s\n         want %s" % [what, got, want])
