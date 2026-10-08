class_name DevStoreyProbe
extends Node


var world: Node3D
var player: Player


const SPOT:= Vector3(14.0, 0.0, 0.0)

var _pass:= 0
var _fail:= 0


func run() -> void:
	await get_tree().process_frame
	var tool: BuildTool = player.build
	if tool == null:
		_check("the player has a build tool", false)
		_finish()
		return
	GameState.add_money(100000.0)
	Tech.grant("deck")
	Tech.grant("access")
	Tech.grant("haystairs")
	Tech.grant("haylift")

	_case_lattice()
	var deck:= await _case_air_deck(tool)
	if deck != null:
		await _case_real_lift(deck)
		await _case_aimed_lift(tool, deck)
		await _case_lift_clip(tool, deck)
		await _case_lift_snap(tool, deck)
		await _case_stair(tool, deck)
	await _case_old_deck(tool)
	await _case_from_concrete(tool)
	await _case_head_over_deck(tool)
	await _case_tower(tool)
	_finish()


func _case_head_over_deck(tool: BuildTool) -> void:
	print("\n=== the head over a deck ===")

	var base:= Vector3(15.0, 0.0, 1.8)
	var floor_y:= tool._world_floor_y(base)
	var at:= Vector3(base.x, floor_y + Cfg.HAY_LIFT_DECK, base.z)
	var top:= floor_y + 2.0
	player.equip_build("haylift")
	for _f in 4:
		await get_tree().process_frame
	tool._lift_ghost.set_riser(HayLift.SPACER)

	for gap: float in [0.8, 0.4]:
		var deck: Platform = world.builds.add_platform(
			Vector3(base.x, top, base.z + gap + 1.0), Vector2(2.0, 2.0))
		for _f in 4:
			await get_tree().process_frame
		var fits:= gap >= HayLift.HEAD_BEND_CLEAR
		var blocked:= tool._lift_blocked(at, Vector3.BACK, 0)
		if blocked:
			var by:= tool._probe_obstruction(tool._lift_probe_query) as Node
			print("[storey] lift blocked by %s under %s, box %s at %s, deck top %.3f" % [
				by.name if by else "-",
				by.get_parent().name if by and by.get_parent() else "-",
				str(tool._lift_probe.size), str(tool._lift_probe_query.transform.origin), top])
			for cs in (by as Node).find_children("*", "CollisionShape3D", true, false):
				var s:= (cs as CollisionShape3D).shape
				print("    shape %s %s aabb %s disabled %s" % [cs.name, s.get_class(),
					str((cs as CollisionShape3D).global_transform * s.get_debug_mesh().get_aabb()),
					str((cs as CollisionShape3D).disabled)])
		_check("a lift with a deck %.2f m off its axis is %s (%s)"
			% [gap, "allowed" if fits else "refused", "refused" if blocked else "allowed"],
			blocked != fits)
		world.builds.demolish(deck)
		await get_tree().process_frame
	tool.cancel()

	var lift: HayLift = world.builds.add_hay_lift(at, 0.0, 0)
	for _f in 8:
		await get_tree().physics_frame
	_check("the lift faces +Z (%s)" % str(lift.forward()),
		lift.forward().is_equal_approx(Vector3.BACK))
	player.equip_build("deck")
	for _f in 4:
		await get_tree().process_frame
	for gap: float in [0.8, 0.4]:
		var st: Dictionary = tool._evaluate_deck(
			Vector3(base.x, top, base.z + gap + 1.0), Vector2(2.0, 2.0))
		var fits:= gap >= HayLift.HEAD_BEND_CLEAR
		if not bool(st ["ok"]):
			var hits:= get_viewport().get_world_3d().direct_space_state.intersect_shape(
				tool._deck_probe_query, 16)
			for h in hits:
				var n:= h ["collider"] as Node
				print("[storey] deck probe hits %s under %s" % [n.name,
					n.get_parent().name if n.get_parent() else "-"])
		_check("a deck laid under the head %.2f m off its axis is %s (%s)"
			% [gap, "allowed" if fits else "refused", str(st ["reason"])],
			bool(st ["ok"]) == fits)
	var port:= lift.port_out()
	_check("...and the head's port is on that deck's belt plane (%.3f vs %.3f)"
		% [port.y, top + Cfg.HAY_LIFT_DECK], absf(port.y - (top + Cfg.HAY_LIFT_DECK)) < 0.01)
	tool.cancel()
	world.builds.demolish(lift)
	await get_tree().process_frame


func _case_from_concrete(tool: BuildTool) -> void:
	print("\n=== counted from the concrete ===")
	var c:= Vector3(15.0, 0.0, 5.5)
	var floor_y:= tool._world_floor_y(c)
	_check("the shed floor there is flat, so a deck lies flush (%.3f)"
		% (tool._ground_rest_y(c) - floor_y),
		is_equal_approx(tool._ground_rest_y(c), floor_y + Cfg.PLATFORM_FLUSH_LIFT))
	var st: Dictionary = tool._evaluate_deck(
		Vector3(c.x, floor_y + Cfg.PLATFORM_FLUSH_LIFT, c.z), Vector2(2.0, 2.0))
	_check("...and the bare floor is not read as hay (%s)" % str(st ["reason"]),
		str(st ["reason"]) != "in the hay")


	var old: Platform = world.builds.add_platform(
		Vector3(c.x, floor_y + Cfg.PLATFORM_THICK, c.z), Vector2(2.0, 2.0))
	for _f in 4:
		await get_tree().process_frame
	var over:= tool._deck_level(Vector3(c.x, floor_y + 2.3, c.z))
	var beside:= tool._deck_level(Vector3(c.x + 6.0, floor_y + 2.3, c.z))
	_check("over an old ground deck the level is a whole 2 m (%.3f)" % (over - floor_y),
		absf(over - (floor_y + 2.0)) < 0.001)
	_check("...the same as beside it (%.3f)" % (beside - floor_y),
		absf(over - beside) < 0.001)
	_check("...and a lift on the concrete meets it",
		HayLift.sections_to_deck(floor_y, over) == 0)
	_check("...and the old deck counts as floor for the readout",
		absf(tool._storey_base_y(Vector3(c.x, over, c.z)) - floor_y) < 0.001)
	world.builds.demolish(old)


	var odd: Platform = world.builds.add_platform(
		Vector3(c.x + 0.5, floor_y + 2.0, c.z), Vector2(2.0, 2.0))
	for _f in 4:
		await get_tree().process_frame
	var lip:= odd.footprint().end.x
	var tile:= tool._snap_tile(Vector3(lip + 1.0, floor_y + 2.0, c.z), Vector2(2.0, 2.0))
	_check("a tile flush on an off-lattice deck stays flush (lip %.2f, deck %.2f)"
		% [tile.x - 1.0, lip], absf((tile.x - 1.0) - lip) < 0.001)
	world.builds.demolish(odd)


	player.equip_build("belt")
	for _f in 4:
		await get_tree().process_frame
	if not tool.grid_snapping():
		_press("build_grid")
		for _f in 4:
			await get_tree().process_frame
	await _aim(tool, Vector3(c.x, floor_y + 1.7, c.z),
		Vector3(c.x, floor_y + 4.3, c.z + 0.4), 0.0)
	var deck_lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	if tool._raw_surface_hit().is_empty():
		var air:= tool._surface_point(deck_lift)
		var surface:= air.y - deck_lift - floor_y
		_check("an open air belt end rides a whole metre's belt plane (%.3f + %.2f)"
			% [surface, deck_lift], absf(surface - roundf(surface)) < 0.001)
	else:
		_check("the open air aim reached nothing", false)
	tool.cancel()


func _case_lattice() -> void:
	print("\n=== the heights a lift meets ===")
	_check("a belt on a deck stands as high over it as a lift's mouth over the floor",
		is_equal_approx(Cfg.HAY_LIFT_DECK, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR))
	for floor_y: float in [0.0, -0.11]:
		for n: int in [0, 3, Cfg.HAY_LIFT_SECTIONS_MAX]:
			var top:= HayLift.deck_top_for(floor_y, n)
			_check("floor %.2f, %d sections: deck at %.2f, and back to %d"
				% [floor_y, n, top, HayLift.sections_to_deck(floor_y, top)],
				is_equal_approx(top, floor_y + HayLift.rise_for(n))
				and HayLift.sections_to_deck(floor_y, top) == n)
	_check("a deck between two heights has no lift",
		HayLift.sections_to_deck(0.0, 2.5) == -1)
	_check("...nor does one above the tallest tower",
		HayLift.sections_to_deck(0.0,
			HayLift.deck_top_for(0.0, Cfg.HAY_LIFT_SECTIONS_MAX + 1)) == -1)


func _case_air_deck(tool: BuildTool) -> Platform:
	print("\n=== a deck in the air ===")
	player.equip_build("deck")
	for _f in 4:
		await get_tree().process_frame
	_check("the tool comes up holding a deck", player.build_id == "deck")
	_check("the grid key answers on a deck", tool.snaps_to_grid())

	var eye_at:= SPOT + Vector3(0.0, 1.7, 6.5)

	var air:= Vector3(SPOT.x + 0.37, 3.2, SPOT.z + 0.41)
	await _aim(tool, eye_at, air, 0.0)
	var free_y:= tool._deck_ghost.global_position.y
	var floor_y:= tool._world_floor_y(tool._deck_ghost.global_position)
	print("[storey] floor %.3f, free deck at %.3f" % [floor_y, free_y])
	_check("the floor is found under the spot", not is_nan(floor_y))
	_check("free-aimed, the deck stands where the crosshair is (%.3f)" % free_y,
		absf(free_y - air.y) < 0.01)
	var st:= tool.status()
	_check("...and the readout says how high (%.2f m up)" % float(st.get("up", NAN)),
		absf(float(st.get("up", NAN)) - (free_y - floor_y)) < 0.01)
	_check("...and that no lift meets it (%d)" % int(st.get("lift", 99)),
		int(st.get("lift", 99)) == -1)

	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("the key switches the grid on", tool.grid_snapping())

	var plate: MeshInstance3D = tool.get_node_or_null("BuildGrid")
	var last_y:= NAN
	for y: float in [3.2, 4.4, 6.1]:
		air.y = y
		await _aim(tool, eye_at, air, 0.0)
		var first:= floor_y + HayLift.rise_for(0)
		var n:= int(roundf(y - first))
		var want:= first + float(n)
		var got:= tool._deck_ghost.global_position.y
		_check("aimed at %.2f, the deck goes to %.3f (want %.3f)" % [y, got, want],
			absf(got - want) < 0.001)
		_check("...which is the NEAREST height, not a tidier one (%.2f m)"
			% absf(got - y), absf(got - y) <= Cfg.HAY_LIFT_SECTION * 0.5 + 0.001)
		st = tool.status()
		_check("...and the readout names a %d section lift (%d)"
			% [n, int(st.get("lift", -1))], int(st.get("lift", -1)) == n)
		if plate != null:
			_check("...with the grid drawn on the deck's own plane (%.3f)"
				% plate.global_position.y, plate.visible
				and absf(plate.global_position.y - (got + Cfg.BUILD_GRID_LIFT)) < 0.001)
		if is_equal_approx(y, 3.2):
			last_y = got


	await _aim(tool, eye_at, Vector3(SPOT.x + 0.37, 0.0, SPOT.z + 3.41), 0.0)
	var low:= tool._deck_ghost.global_position.y

	_check("aimed at the floor, it lies flush in it (%.3f)" % low,
		absf(low - (floor_y + Cfg.PLATFORM_FLUSH_LIFT)) < 0.001)
	st = tool.status()
	_check("...and the readout has no height on it", is_nan(float(st.get("up", 0.0))))

	tool.cancel()
	var deck: Platform = world.builds.add_platform(
		Vector3(SPOT.x, last_y, SPOT.z - 1.0), Vector2(4.0, 4.0))
	for _f in 4:
		await get_tree().process_frame
	_check("a deck is built at the snapped height (%.3f)" % deck.top_y(),
		absf(deck.top_y() - last_y) < 0.001)
	return deck


func _case_real_lift(deck: Platform) -> void:
	print("\n=== a real lift against it ===")
	var floor_y:= player.build._world_floor_y(deck.global_position)
	var n:= HayLift.sections_to_deck(floor_y, deck.top_y())
	_check("the deck has a lift (%d sections)" % n, n >= 0)
	if n < 0:
		return
	var at:= Vector3(deck.global_position.x, floor_y + Cfg.HAY_LIFT_DECK,
		deck.global_position.z + 6.0)
	var lift: HayLift = world.builds.add_hay_lift(at, 0.0, n)
	for _f in 10:
		await get_tree().process_frame
	var belt_y:= deck.top_y() + Cfg.HAY_LIFT_DECK
	print("[storey] lift in %.3f out %.3f, deck belt %.3f"
		% [lift.port_in().y, lift.port_out().y, belt_y])
	_check("its mouth is on the floor's belt plane (%.3f against %.3f)"
		% [lift.port_in().y, at.y], absf(lift.port_in().y - at.y) < 0.01)
	_check("its top port is on the deck's belt plane (%.3f against %.3f)"
		% [lift.port_out().y, belt_y], absf(lift.port_out().y - belt_y) < 0.01)
	world.builds.demolish(lift)
	for _f in 2:
		await get_tree().process_frame


func _case_aimed_lift(tool: BuildTool, deck: Platform) -> void:
	print("\n=== a lift aimed at it from the floor ===")
	var floor_y:= tool._world_floor_y(deck.global_position)
	var n:= HayLift.sections_to_deck(floor_y, deck.top_y())
	player.equip_build("haylift")
	var c:= deck.global_position
	var base:= Vector3(c.x, floor_y, c.z + 5.5)
	var eye_at:= base + Vector3(0.0, 1.7, 2.5)
	await _aim(tool, eye_at, base, 0.5)
	var st:= tool.status()
	_check("the base is accepted (%s)" % st.get("reason", ""), bool(st.get("ok", false)))
	tool.primary()
	for _f in 4:
		await get_tree().process_frame
	_check("...and pinned", bool(tool.status().get("placing", false)))


	await _aim(tool, eye_at, Vector3(c.x, deck.top_y() - 0.1, c.z + 1.2), 1.0)
	st = tool.status()
	print("[storey] aimed: %d sections, gap %s" % [int(st.get("sections", -1)),
		str(st.get("deck_gap", "none"))])
	_check("looking up at the deck gives the lift that meets it (%d, want %d)"
		% [int(st.get("sections", -1)), n], int(st.get("sections", -1)) == n)
	var gap: float = st.get("deck_gap", NAN)
	_check("...and the readout says it meets the deck (%.3f m)" % gap,
		not is_nan(gap) and absf(gap) < 0.01)
	tool.cancel()
	for _f in 2:
		await get_tree().process_frame


func _case_lift_clip(tool: BuildTool, deck: Platform) -> void:
	print("\n=== a lift too close to the deck ===")
	var floor_y:= tool._world_floor_y(deck.global_position)
	player.equip_build("haylift")
	var c:= deck.global_position
	var base:= Vector3(c.x, floor_y, c.z + 2.0 + 1.0)
	var eye_at:= base + Vector3(0.0, 1.7, 3.0)
	await _aim(tool, eye_at, base, 0.5)
	var st:= tool.status()
	_check("a lift whose head would sit in the deck is refused (%s)"
		% st.get("reason", ""), not bool(st.get("ok", true)))
	tool.cancel()

	var n:= HayLift.sections_to_deck(floor_y, deck.top_y())
	var lift: HayLift = world.builds.add_hay_lift(
		base + Vector3.UP * Cfg.HAY_LIFT_DECK, PI, n)
	for _f in 6:
		await get_tree().physics_frame
	var inside:= _hulls_in(lift, deck)
	print("[storey] clip hulls inside the deck: %s" % str(inside))
	world.builds.demolish(lift)
	for _f in 2:
		await get_tree().process_frame


func _case_lift_snap(tool: BuildTool, deck: Platform) -> void:
	print("\n=== a lift snapped to the deck edge ===")
	var floor_y:= tool._world_floor_y(deck.global_position)
	var n:= HayLift.sections_to_deck(floor_y, deck.top_y())
	var c:= deck.global_position
	var edge_z:= c.z + 2.0
	var along:= c.x + 0.63
	player.equip_build("haylift")
	var eye_at:= Vector3(along, floor_y + 1.7, edge_z + 4.0)
	await _aim(tool, eye_at, Vector3(along, deck.top_y() - 0.1, edge_z - 0.3), 1.0)
	var st:= tool.status()
	var ghost: HayLift = tool._lift_ghost
	var at:= ghost.global_position
	print("[storey] snap: ok %s (%s) %d sections gap %s at %s yaw %.1f" % [
		str(st.get("ok")), st.get("reason", ""), int(st.get("sections", -1)),
		str(st.get("deck_gap")), str(at), rad_to_deg(ghost.global_rotation.y)])
	_check("looking up at the deck snaps the lift to it",
		bool(st.get("deck_snap", false)))
	_check("...and it is green (%s)" % st.get("reason", ""), bool(st.get("ok", false)))
	_check("...with the sections that meet it (%d, want %d)"
		% [int(st.get("sections", -1)), n], int(st.get("sections", -1)) == n)
	_check("...and says it meets the deck",
		absf(float(st.get("deck_gap", NAN))) < 0.01)
	var want_z:= edge_z + HayLift.HEAD_REACH + BuildTool.LIFT_EDGE_CLEAR
	_check("...standing off the edge by the head's reach (z %.3f, want %.3f)"
		% [at.z, want_z], absf(at.z - want_z) < 0.001)
	_check("...where the player looked along it (x %.3f)" % at.x,
		absf(at.x - along) < 0.001)
	_check("...on the floor", absf(at.y - (floor_y + Cfg.HAY_LIFT_DECK)) < 0.01)
	var fwd:= ghost.global_basis.z
	_check("...facing onto the deck (%s)" % str(fwd), fwd.dot(Vector3.BACK) < -0.999)

	var before: int = world.builds.hay_lifts.size()
	var purse:= GameState.money
	tool.primary()
	for _f in 10:
		await get_tree().physics_frame
	_check("one click builds it (%d -> %d)" % [before, world.builds.hay_lifts.size()],
		world.builds.hay_lifts.size() == before + 1)
	if world.builds.hay_lifts.size() == before + 1:
		var lift: HayLift = world.builds.hay_lifts [before]
		_check("...and charges its price ($%.0f)" % (purse - GameState.money),
			is_equal_approx(purse - GameState.money, HayLift.cost_for(n)))
		var inside:= _hulls_in(lift, deck)
		_check("...with nothing of it inside the deck %s" % str(inside), inside.is_empty())
		var port:= lift.port_out()
		_check("...its top port on the deck, %.2f m in (%s)" % [edge_z - port.z, str(port)],
			port.z < edge_z - 0.1 and deck.footprint().has_point(Vector2(port.x, port.z)))
		_check("...at the deck's belt height (%.3f against %.3f)"
			% [port.y, deck.top_y() + Cfg.HAY_LIFT_DECK],
			absf(port.y - (deck.top_y() + Cfg.HAY_LIFT_DECK)) < 0.01)
		world.builds.demolish(lift)


	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	await _aim(tool, eye_at, Vector3(along, deck.top_y() - 0.1, edge_z - 0.3), 1.0)
	_check("with the grid on it goes to a whole metre along the edge (x %.3f)"
		% tool._lift_ghost.global_position.x,
		absf(tool._lift_ghost.global_position.x - roundf(along)) < 0.001)


	player.equip_build("haylift")
	await _aim(tool, Vector3(c.x - 1.0, deck.top_y() + 1.7, c.z - 1.0),
		Vector3(c.x + 0.5, deck.top_y(), c.z), 0.5)
	st = tool.status()
	_check("looking down on a deck does not snap to its edge",
		not bool(st.get("deck_snap", true)))
	_check("...it stands on the deck (%.3f)" % tool._lift_ghost.global_position.y,
		absf(tool._lift_ghost.global_position.y - (deck.top_y() + Cfg.HAY_LIFT_DECK)) < 0.01)
	tool.cancel()
	for _f in 2:
		await get_tree().process_frame


func _hulls_in(lift: HayLift, deck: Platform) -> PackedStringArray:
	var out:= PackedStringArray()
	var space:= lift.get_world_3d().direct_space_state
	for hull in lift._hulls:
		var body:= hull as StaticBody3D
		var cs:= body.get_child(0) as CollisionShape3D
		var q:= PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		q.collision_mask = Cfg.L_BUILD
		for r in space.intersect_shape(q, 16):
			if r ["collider"] == deck:
				out.append(body.name)
	return out


func _case_stair(tool: BuildTool, deck: Platform) -> void:
	print("\n=== a stair off it, squared ===")
	player.equip_build("stair")
	for _f in 4:
		await get_tree().process_frame
	_check("the grid key answers on a stair", tool.snaps_to_grid())
	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("...and switches on", tool.grid_snapping())

	var floor_y:= tool._world_floor_y(deck.global_position)
	var c:= deck.global_position

	var edge_z:= c.z - 2.0
	var eye_at:= Vector3(c.x - 0.37, floor_y + 1.7, edge_z - 3.5)
	await _aim(tool, eye_at, Vector3(c.x - 0.37, deck.top_y() - 0.1, edge_z + 0.05), 1.0)
	var head:= tool._stair_ghost.global_position
	print("[storey] head %s" % str(head))
	_check("the head is on the edge it was aimed at (%.3f)" % head.z,
		absf(head.z - edge_z) < 0.001)
	_check("...on a whole metre along it (%.3f)" % head.x,
		absf(head.x - roundf(head.x)) < 0.001)
	_check("...at the deck's height", absf(head.y - deck.top_y()) < 0.001)
	tool.primary()
	for _f in 4:
		await get_tree().process_frame
	_check("...and pinned", bool(tool.status().get("placing", false)))


	var foot_eye:= Vector3(head.x + 2.5, floor_y + 1.7, edge_z - 0.5)
	await _aim(tool, foot_eye, Vector3(head.x + 0.8, floor_y, edge_z - 4.4), 1.0)
	var flight:= tool._stair_ghost
	var run:= flight.rise / flight.pitch
	var yaw:= rad_to_deg(flight.global_rotation.y)
	print("[storey] rise %.3f pitch %.3f run %.3f yaw %.1f"
		% [flight.rise, flight.pitch, run, yaw])
	_check("the flight comes straight off the edge (%.1f deg)" % yaw,
		absf(yaw) < 0.1)
	_check("...and runs a whole number of metres (%.3f)" % run,
		absf(run - 4.0) < 0.01)
	var foot_floor:= tool._world_floor_y(Vector3(head.x, floor_y, edge_z - 4.0))
	_check("...down to the floor (%.3f rise)" % flight.rise,
		absf(flight.rise - (deck.top_y() - foot_floor)) < 0.02)
	tool.cancel()
	for _f in 2:
		await get_tree().process_frame


func _case_old_deck(tool: BuildTool) -> void:
	print("\n=== a deck from an old save ===")

	var c:= Vector3(15.0, 0.0, 5.5)
	var floor_y:= tool._world_floor_y(c)

	var old_top:= floor_y + 2.85
	var old: Platform = world.builds.add_platform(
		Vector3(c.x, old_top, c.z), Vector2(2.0, 2.0))
	for _f in 4:
		await get_tree().process_frame
	player.equip_build("deck")
	for _f in 4:
		await get_tree().process_frame
	_press("build_grid")
	for _f in 4:
		await get_tree().process_frame
	_check("the grid is on for it", tool.grid_snapping())

	var eye_at:= Vector3(c.x + 0.2, floor_y + 1.7, 1.5)

	await _aim(tool, eye_at, Vector3(c.x + 0.2, old_top + 0.07, c.z - 1.9), 0.0)
	var near:= tool._deck_ghost.global_position.y
	_check("aimed just off its height, the new deck joins it (%.3f)" % near,
		absf(near - old_top) < 0.001)

	await _aim(tool, eye_at, Vector3(c.x + 0.2, old_top + 0.25, c.z - 1.9), 0.0)
	var offered:= tool._deck_ghost.global_position.y
	_check("aimed further off, the level it snaps to still joins it (%.3f)" % offered,
		absf(offered - old_top) < 0.001)
	tool.cancel()

	player.equip_build("haylift")
	var base:= Vector3(16.3, floor_y, 2.6)
	var lift_eye:= Vector3(16.3, floor_y + 1.7, 0.2)
	await _aim(tool, lift_eye, base, 0.5)
	tool.primary()
	for _f in 4:
		await get_tree().process_frame
	await _aim(tool, lift_eye, Vector3(c.x + 0.5, old_top - 0.1, c.z - 0.6), 1.0)
	var gap: float = tool.status().get("deck_gap", NAN)
	var want:= (floor_y + Cfg.HAY_LIFT_DECK
		+ HayLift.rise_for(HayLift.sections_for(old_top - floor_y))) - (old_top + Cfg.HAY_LIFT_DECK)
	_check("a lift aimed at it says it misses (%.3f m, want %.3f)" % [gap, want],
		not is_nan(gap) and absf(gap - want) < 0.001 and absf(gap) > 0.05)
	tool.cancel()
	world.builds.demolish(old)


func _case_tower(tool: BuildTool) -> void:
	print("\n=== a tower of decks ===")
	player.equip_build("deck")
	for _f in 4:
		await get_tree().process_frame
	var span:= Vector2(4.0, 4.0)


	var storey:= HayLift.rise_for(Cfg.HAY_LIFT_SECTIONS_MAX)
	var spot:= _open_air_spot(tool, span, storey)
	_check("there is open sky outside the shed to build it under", spot != Vector3.INF)
	if spot == Vector3.INF:
		return
	var floor_y:= spot.y
	var built: Array [Platform] = []
	var top:= floor_y

	for i in 5:
		var at:= Vector3(spot.x, top + storey, spot.z)
		var st: Dictionary = tool._evaluate_deck(at, span)
		_check("storey %d, %.0f m up, is allowed (%s)" % [i + 1, at.y - floor_y,
			str(st ["reason"])], bool(st ["ok"]))
		var deck: Platform = world.builds.add_platform(at, span)
		built.append(deck)
		for _f in 4:
			await get_tree().physics_frame


		var feet:= _feet_count(deck)
		var hits:= _leg_hits(deck)
		var below: Object = null if i == 0 else built [i - 1]
		var on:= 0
		for h in hits:
			if (i == 0 and not (h is Platform)) or (i > 0 and h == below):
				on += 1
		_check("...its legs stand on %s (%d feet, %d of %d rays on it)"
			% ["the floor" if i == 0 else "the storey below", feet, on, hits.size()],
			feet > 0 and feet == hits.size() and on == hits.size())
		top = deck.top_y()


	for up: float in [30.0, 60.0]:
		var beside:= Vector3(spot.x + span.x, floor_y + up, spot.z)
		var st: Dictionary = tool._evaluate_deck(beside, span)
		_check("a deck beside the tower, %.0f m over bare floor, is allowed (%s)"
			% [up, str(st ["reason"])], bool(st ["ok"]))


	var eye_at:= Vector3(spot.x, top + Player.EYE_HEIGHT, spot.z)
	var far:= eye_at + Vector3(0.0, 15.0, 20.0)
	player.global_position = eye_at - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	for _i in 40:
		var to:= far - player.eye_position()
		player.set_look(atan2(- to.x, - to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		_press("build_further")
		await get_tree().process_frame
	for _f in 4:
		await get_tree().process_frame
	var cap:= Cfg.BUILD_REACH_MAX + Tech.build_reach_bonus()
	_check("the reach winds out no further than %.1f m (%.2f)" % [cap, tool._reach],
		tool._reach <= cap + 0.001)
	var eye:= player.eye_position()
	_check("the player is stood on the top storey (eye %.2f m up)" % (eye.y - floor_y),
		absf(eye.y - eye_at.y) < 0.3)
	var ghost:= tool._deck_ghost.global_position
	var dist:= eye.distance_to(ghost)
	_check("aimed 25 m off, the deck lands within reach (%.2f m from the eye)" % dist,
		dist <= tool._reach + Cfg.PLATFORM_TILE)
	var st: Dictionary = tool.status()
	_check("...and it is allowed, %.0f m up (%s)" % [ghost.y - floor_y,
		str(st.get("reason", ""))], bool(st.get("ok", false)))


	far = eye_at + Vector3(0.0, 12.0, 0.3)
	for _i in 6:
		var to:= far - player.eye_position()
		player.set_look(atan2(- to.x, - to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		await get_tree().process_frame
	ghost = tool._deck_ghost.global_position
	st = tool.status()
	_check("aimed up, the deck is over the top storey (%s)" % str(ghost),
		built [-1].footprint().has_point(Vector2(ghost.x, ghost.z)))
	var up:= float(st.get("up", NAN))
	_check("the readout counts from the storey below (%.2f m up, want %.2f)"
		% [up, ghost.y - top], absf(up - (ghost.y - top)) < 0.01)


	if not tool.grid_snapping():
		_press("build_grid")
	for _i in 8:
		_press("build_closer")
		await get_tree().process_frame
	for _i in 6:
		var to:= far - player.eye_position()
		player.set_look(atan2(- to.x, - to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		await get_tree().process_frame
	_check("the grid is on for the tower", tool.grid_snapping())
	var snapped:= tool._deck_ghost.global_position
	st = tool.status()
	var n:= int(st.get("lift", -1))
	_check("on the grid it goes to a lift height over the top storey (%.3f, %d sections)"
		% [snapped.y, n],
		n >= 0 and absf(snapped.y - HayLift.deck_top_for(top, n)) < 0.001)
	if n >= 0:
		var foot:= Vector3(spot.x, top + Cfg.HAY_LIFT_DECK, spot.z - 1.0)
		var lift: HayLift = world.builds.add_hay_lift(foot, 0.0, n)
		for _f in 10:
			await get_tree().process_frame
		var belt_y:= snapped.y + Cfg.HAY_LIFT_DECK
		_check("a lift stood on the top storey takes its hay in there (%.3f against %.3f)"
			% [lift.port_in().y, foot.y], absf(lift.port_in().y - foot.y) < 0.01)
		_check("...and hands it onto the snapped deck's belt plane (%.3f against %.3f)"
			% [lift.port_out().y, belt_y], absf(lift.port_out().y - belt_y) < 0.01)
		world.builds.demolish(lift)
		for _f in 2:
			await get_tree().process_frame
	tool.cancel()

	for i in range(built.size() - 1, -1, -1):
		world.builds.demolish(built [i])


func _open_air_spot(tool: BuildTool, span: Vector2, up: float) -> Vector3:
	var out:= player.warehouse.inner + 10.0
	for c: Vector3 in [Vector3(out, 0.0, 0.0), Vector3(- out, 0.0, 0.0),
			Vector3(0.0, 0.0, out), Vector3(0.0, 0.0, - out)]:
		var floor_y:= tool._world_floor_y(c + Vector3.UP * 80.0)
		if is_nan(floor_y):
			continue
		var st: Dictionary = tool._evaluate_deck(Vector3(c.x, floor_y + up, c.z), span)
		print("[storey] tower spot %s: floor %.3f, %s" % [str(c), floor_y,
			"ok" if bool(st ["ok"]) else str(st ["reason"])])
		if bool(st ["ok"]):
			return Vector3(c.x, floor_y, c.z)
	return Vector3.INF


func _feet_count(deck: Platform) -> int:
	if deck._supports == null:
		return 0
	var mmi:= deck._supports.get_node_or_null("Feet") as MultiMeshInstance3D
	return 0 if mmi == null or mmi.multimesh == null else mmi.multimesh.instance_count


func _leg_hits(deck: Platform) -> Array [Object]:
	var out: Array [Object] = []
	var space:= deck.get_world_3d().direct_space_state
	for top in deck._leg_tops():
		var from:= deck.global_position + top + Vector3(0.0, - Cfg.PLATFORM_THICK, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(from,
			from - Vector3(0.0, Cfg.PLATFORM_LEG_MAX_DROP, 0.0))
		q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
		q.exclude = [deck.get_rid()]
		var hit:= space.intersect_ray(q)
		if not hit.is_empty():
			out.append(hit ["collider"])
	return out


func _aim(tool: BuildTool, eye_at: Vector3, at: Vector3, beyond: float) -> void:
	player.global_position = eye_at - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	for _i in 4:
		var eye:= player.eye_position()
		var to:= at - eye
		player.set_look(atan2(- to.x, - to.z),
			atan2(to.y, Vector2(to.x, to.z).length()))
		tool._reach = eye.distance_to(at) + beyond
		for _f in 4:
			await get_tree().process_frame
	var eye:= player.eye_position()
	var off:= rad_to_deg(player.look_direction().angle_to(at - eye))
	if off > 0.2:
		print("[storey] aim is %.2f deg off (eye %s)" % [off, str(eye)])
	tool._reach = eye.distance_to(at) + beyond
	for _f in 3:
		await get_tree().process_frame
	var hit:= tool._raw_surface_hit()
	if not hit.is_empty():
		print("[storey] aim at %s hits %s at %s" % [str(at),
			(hit ["collider"] as Node).name, str(hit ["position"])])


func _press(action: String) -> void:
	for e in InputMap.action_get_events(action):
		var key:= e as InputEventKey
		if key == null:
			continue
		for down: bool in [true, false]:
			var ev:= key.duplicate() as InputEventKey
			ev.pressed = down
			Input.parse_input_event(ev)
		return
	_check("the %s action has a key bound to press" % action, false)


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _finish() -> void:
	print("[storey] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
