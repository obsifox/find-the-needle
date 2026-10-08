class_name DevRoofProbe
extends Node


const SETTLE:= 8


const PATIENCE:= 480


const RANGE:= 6.0

var world: Node3D
var player: Player


var builds: BuildManager

var _fails:= 0
var _floor:= 0.0
var _origin:= Vector3.ZERO


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _same(x: Vector3, y: Vector3, what: String) -> void:
	_ok(x.distance_to(y) < 0.001,
		"%s (%.4f m apart)" % [what, x.distance_to(y)])


func run() -> void:


	world.block_save = true
	builds = world.builds
	print("--- roof probe ---")
	for i in SETTLE:
		await get_tree().process_frame
	GameState.add_money(40000.0)
	player.capture_mouse(true)
	_floor = player.global_position.y
	_origin = player.global_position + Vector3(RANGE, 0.0, 0.0)
	_origin.y = _floor

	_case_module()
	await _case_wall_socket()
	await _case_aim()
	await _case_side()
	await _case_run_grows()
	await _case_rectangle()
	await _case_lets_go()
	await _case_turn()
	await _case_turn_in_cell()
	await _case_chain()
	await _case_ridge()
	await _case_surface()
	await _case_hatch_is_a_hole()
	await _case_ladder()
	await _case_climb()
	await _case_save()
	await _case_dismantle()
	await _case_holds_an_arm()
	await _case_not_on_the_ground()
	await _case_hatch_needs_room()
	await _case_hatch_into_deck()
	await _case_hatch_into_deck_from_below()
	await _case_hatch_lying_on_a_deck()
	await _case_shift_x_takes_one_tile()
	await _case_hatch_into_a_hole()
	await _case_ghost_is_pulled_forward()
	await _case_shared_joints()

	print("--- %s ---" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _case_module() -> void:
	print("\n=== the run rounds to whole bays ===")
	var from:= Vector3.ZERO


	for pair: Array in [[2.6, 2.0], [3.4, 4.0], [5.0, 6.0], [0.4, 2.0]]:
		var dragged: float = pair [0]
		var want: float = pair [1]
		var got:= from.distance_to(
			Roof.end_for(from, Vector3(0.0, 0.0, dragged), Roof.Kind.FLAT))
		_ok(absf(got - want) < 0.001,
			"a %.1f m drag builds %.0f m (got %.2f)" % [dragged, want, got])

	var hatch:= from.distance_to(
		Roof.end_for(from, Vector3(0.0, 0.0, 9.0), Roof.Kind.HATCH))
	_ok(absf(hatch - Cfg.ROOF_BAY) < 0.001,
		"a hatch is one bay whatever the drag said (%.2f m)" % hatch)


	_ok(is_equal_approx(Cfg.ROOF_BAY, Cfg.WALL_PANEL),
		"a bay of roof is a bay of wall")


func _case_wall_socket() -> void:
	print("\n=== a roof drops into a wall's socket ===")
	var a:= _origin + Vector3(0.0, 0.0, -2.0)
	var b:= _origin + Vector3(0.0, 0.0, 2.0)
	var wall:= builds.add_wall(a, b, YardWall.Bay.SOLID)
	await _settle()


	var aimed:= Vector3(wall.a.x + 0.3, wall.a.y + Cfg.WALL_HEIGHT - 0.15,
		wall.a.z + 0.35)
	var snapped:= builds.snap_roof_point(aimed)
	_same(snapped, Vector3(wall.a.x, wall.a.y + Cfg.WALL_HEIGHT, wall.a.z),
		"an aim near the top of a wall lands on the top of its column")

	var lid:= builds.add_roof(snapped, snapped + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.FLAT, 1)
	await _settle()
	_ok(absf(lid.a.y - (wall.a.y + Cfg.WALL_HEIGHT)) < 0.001,
		"...so the eave stands at the wall's own height, with no gap")
	_ok(lid.bays == 2, "a 4 m run over a 4 m wall is two bays (got %d)" % lid.bays)


	var joints:= lid.joint_points()
	var posts:= wall.post_points()
	_ok(joints.size() == posts.size(),
		"the roof has a joint for every column (%d against %d)"
			% [joints.size(), posts.size()])
	var worst:= 0.0
	for i in mini(joints.size(), posts.size()):
		worst = maxf(worst, Vector2(joints [i].x - posts [i].x,
			joints [i].z - posts [i].z).length())
	_ok(worst < 0.001, "...and every one of them is over it (worst %.4f m)" % worst)

	builds.demolish(lid)
	builds.demolish(wall)
	await _settle()


func _case_aim() -> void:
	print("\n=== aiming at a wall top from the floor ===")
	var a:= _origin + Vector3(0.0, 0.0, -2.0)
	var wall:= builds.add_wall(a, a + Vector3(0.0, 0.0, 4.0), YardWall.Bay.SOLID)
	await _settle()
	Tech.grant(BuildCatalog.unlock_of("roof"), 1)
	player.equip_build("roof_pitch")


	var stand:= Vector3(wall.a.x + 3.0, _floor, wall.a.z + 2.0)
	var target:= Vector3(wall.a.x, wall.a.y + Cfg.WALL_HEIGHT, wall.a.z + 2.0)
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var eye:= stand + Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	var to:= target - eye
	var flat:= Vector3(to.x, 0.0, to.z)
	player.set_look(atan2(- to.x, - to.z), atan2(to.y, flat.length()))
	await _settle()

	var ghost: Roof = player.build.get("_roof_ghost")
	_ok(ghost != null and ghost.visible, "the hologram is up")
	if ghost == null:
		return
	_ok(absf(ghost.a.y - (wall.a.y + Cfg.WALL_HEIGHT)) < 0.001,
		"its eave is on top of the wall (%.2f m of %.2f m)"
			% [ghost.a.y, wall.a.y + Cfg.WALL_HEIGHT])
	_ok(Vector2(ghost.a.x - wall.a.x, 0.0).length() < 0.001,
		"...over the wall's own line")
	var status: Dictionary = player.build.status()
	_ok(bool(status ["ok"]), "and the tool will build it (%s)"
		% ("green" if status ["ok"] else str(status ["reason"])))


	_ok(absf(_reach_of(ghost).x) > Cfg.ROOF_DEPTH * 0.9,
		"the sheet reaches across the wall rather than along it")


	player.set_look(atan2(-1.0, 0.0), 0.0)
	await _settle()
	_ok(builds.aimed_roof_socket(player.eye_position(),
		player.look_direction(), 6.0) == null,
		"looking away from every wall finds no socket")
	builds.demolish(wall)
	await _settle()


func _case_side() -> void:
	print("\n=== the sheet reaches to the face you are looking at ===")
	var west:= _origin + Vector3(-2.0, 0.0, -2.0)
	var east:= _origin + Vector3(2.0, 0.0, -2.0)
	var wall:= builds.add_wall(west, west + Vector3(0.0, 0.0, 4.0),
		YardWall.Bay.SOLID)
	builds.add_wall(east, east + Vector3(0.0, 0.0, 4.0), YardWall.Bay.SOLID)
	await _settle()
	Tech.grant(BuildCatalog.unlock_of("roof"), 1)
	player.equip_build("roof_pitch")
	var eave:= Vector3(wall.a.x, wall.a.y + Cfg.WALL_HEIGHT, wall.a.z + 2.0)
	for outside: bool in [true, false]:
		var offset:= -3.0 if outside else 3.0
		await _look_at(Vector3(wall.a.x + offset, _floor, wall.a.z + 2.0), eave)
		var ghost: Roof = player.build.get("_roof_ghost")
		if ghost == null:
			_ok(false, "the hologram is up")
			return
		_ok(signf(_reach_of(ghost).x) == signf(offset),
			"from %s it reaches back over the player's own side"
				% ["outside" if outside else "inside"])
	for other in builds.walls.duplicate():
		builds.demolish(other)
	await _settle()


func _case_run_grows() -> void:
	print("\n=== a run grows a bay per column ===")
	var a:= _origin + Vector3(0.0, 0.0, -3.0)
	var wall:= builds.add_wall(a, a + Vector3(0.0, 0.0, 6.0), YardWall.Bay.SOLID)
	await _settle()
	player.equip_build("roof")
	var eave_y:= wall.a.y + Cfg.WALL_HEIGHT
	var first:= Vector3(wall.a.x, eave_y, wall.a.z)

	await _look_at(Vector3(wall.a.x + 3.0, _floor, wall.a.z), first)
	var ghost: Roof = player.build.get("_roof_ghost")
	if ghost == null:
		_ok(false, "the hologram is up")
		return
	_same(ghost.a, first, "the hologram starts on the column being looked at")
	_ok(ghost.bays == 1, "and is one bay before the click (got %d)" % ghost.bays)
	player.build.primary()
	await _settle()
	_ok(bool(player.build.status() ["placing"]), "the first click starts the run")


	var over:= first + Vector3(0.0, 0.0, Cfg.ROOF_BAY * 1.6)
	await _look_at(Vector3(wall.a.x + 3.0, _floor, wall.a.z + Cfg.ROOF_BAY),
		over)
	_same(ghost.a, first, "the anchor stays where it was put")
	_ok(ghost.bays == 2, "sweeping over the next bay makes it TWO (got %d)"
		% ghost.bays)
	_same(ghost.b, first + Vector3(0.0, 0.0, Cfg.ROOF_BAY * 2.0),
		"...so the run ends at the far side of the bay swept over")
	var status: Dictionary = player.build.status()
	_ok(absf(status ["length"] - Cfg.ROOF_BAY * 2.0) < 0.001,
		"and it is priced as %.0f m (got %.2f)" % [Cfg.ROOF_BAY * 2.0,
			status ["length"]])

	var want_a:= ghost.a
	var want_b:= ghost.b
	var want_side:= ghost.side
	player.build.primary()
	await _settle()
	_ok(builds.roofs.size() == 1, "the second click builds one run")
	if builds.roofs.is_empty():
		return
	var built: Roof = builds.roofs [0]
	_same(built.a, want_a, "what went up starts where the hologram did")
	_same(built.b, want_b, "and ends where the hologram did")
	_ok(built.side == want_side, "reaching the way the hologram reached")
	_ok(built.bays == 2, "two bays of roof, not one (got %d)" % built.bays)


	_ok(not bool(player.build.status() ["placing"]),
		"and the tool lets go of it")
	player.build.cancel()
	builds.demolish(built)
	builds.demolish(wall)
	await _settle()


func _look_at(from: Vector3, at: Vector3) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	var to:= at - (from + Vector3(0.0, Player.EYE_HEIGHT, 0.0))
	player.set_look(atan2(- to.x, - to.z),
		atan2(to.y, Vector3(to.x, 0.0, to.z).length()))
	await _settle()


func _reach_of(lid: Roof) -> Vector3:
	var dir:= lid.b - lid.a
	dir.y = 0.0
	if dir.length_squared() < 1e-06:
		return Vector3.ZERO
	dir = dir.normalized()
	return Vector3(dir.z, 0.0, - dir.x) * (float(lid.side) * Cfg.ROOF_DEPTH)


func _case_rectangle() -> void:
	print("\n=== the drag is a rectangle ===")
	var a:= _origin + Vector3(0.0, 0.0, -3.0)
	var wall:= builds.add_wall(a, a + Vector3(0.0, 0.0, 6.0), YardWall.Bay.SOLID)
	await _settle()
	player.equip_build("roof")
	var eave_y:= wall.a.y + Cfg.WALL_HEIGHT
	var first:= Vector3(wall.a.x, eave_y, wall.a.z)
	await _look_at(Vector3(wall.a.x + 3.0, _floor, wall.a.z), first)
	var ghost: Roof = player.build.get("_roof_ghost")
	if ghost == null:
		_ok(false, "the hologram is up")
		return
	_ok(ghost.rows == 1, "one bay deep before the click (got %d)" % ghost.rows)
	player.build.primary()
	await _settle()


	var reach:= (ghost.b - ghost.a).normalized()
	var into:= Vector3(reach.z, 0.0, - reach.x) * float(ghost.side)
	var target:= first + reach * (Cfg.ROOF_BAY * 1.6) + into * (Cfg.ROOF_DEPTH * 1.6)


	await _look_at(Vector3(target.x, _floor, target.z) - reach * 4.0, target)
	_ok(ghost.bays == 2, "two bays along the eave (got %d)" % ghost.bays)
	_ok(ghost.rows == 2, "and two bays deep (got %d)" % ghost.rows)
	_same(ghost.a, first, "still anchored on the bay that was clicked")
	var status: Dictionary = player.build.status()
	_ok(absf(status ["cost"] - Cfg.ROOF_BAY * 2.0 * Cfg.ROOF_COST_PER_M * 2.0)
			< 0.01,
		"priced for all four bays ($%.2f)" % status ["cost"])

	var want_rows:= ghost.rows
	var want_bays:= ghost.bays
	player.build.primary()
	await _settle()
	if builds.roofs.is_empty():
		_ok(false, "the second click builds it")
		return
	var built: Roof = builds.roofs [0]
	_ok(built.bays == want_bays and built.rows == want_rows,
		"what went up is the rectangle that was drawn (%d x %d)"
			% [built.bays, built.rows])
	_ok(absf(built.depth() - Cfg.ROOF_DEPTH * 2.0) < 0.001,
		"reaching %.0f m in (got %.2f)" % [Cfg.ROOF_DEPTH * 2.0, built.depth()])


	var written:= builds.to_array()
	builds.from_array(written)
	await _settle()
	_ok(not builds.roofs.is_empty() and builds.roofs [0].rows == want_rows,
		"and it survives a save")
	builds.clear()
	await _settle()


func _case_lets_go() -> void:
	print("\n=== two clicks lay one roof ===")
	var a:= _origin + Vector3(0.0, 0.0, -5.0)
	var wall:= builds.add_wall(a, a + Vector3(0.0, 0.0, 10.0), YardWall.Bay.SOLID)
	await _settle()
	player.equip_build("roof")

	await _aim_at_column(wall, 1)
	player.build.primary()
	await _settle()
	_ok(builds.roofs.is_empty(), "the first click builds nothing")
	_ok(bool(player.build.status() ["placing"]), "...it starts a run")
	player.build.primary()
	await _settle()
	_ok(builds.roofs.size() == 1, "the second click builds one roof")
	_ok(not bool(player.build.status() ["placing"]),
		"...and the tool lets go of it")


	await _aim_at_column(wall, 3)
	player.build.primary()
	await _settle()
	_ok(builds.roofs.size() == 1,
		"the third click builds nothing (got %d roofs)" % builds.roofs.size())
	_ok(bool(player.build.status() ["placing"]), "...it starts the next one")
	player.build.primary()
	await _settle()
	_ok(builds.roofs.size() == 2, "the fourth click builds the second roof")
	_ok(not bool(player.build.status() ["placing"]), "...and lets go again")


	player.equip_build("roof_hatch")
	await _aim_at_column(wall, 0)
	var before:= builds.roofs.size()
	player.build.primary()
	await _settle()
	_ok(builds.roofs.size() == before + 1, "a hatch still goes in on one click")
	player.build.cancel()
	builds.clear()
	await _settle()


func _aim_at_column(wall: YardWall, bay: int) -> void:
	var dir:= (wall.b - wall.a).normalized()
	var at:= wall.a + dir * (Cfg.ROOF_BAY * float(bay)) + Vector3(0.0, Cfg.WALL_HEIGHT, 0.0)
	var out:= Vector3(dir.z, 0.0, - dir.x) * 3.0
	await _look_at(Vector3(at.x, _floor, at.z) + out - dir * 2.0, at)


func _case_turn() -> void:
	print("\n=== turning the hologram ===")
	var a:= _origin + Vector3(0.0, 0.0, -2.0)
	var wall:= builds.add_wall(a, a + Vector3(0.0, 0.0, 4.0), YardWall.Bay.SOLID)
	await _settle()
	player.equip_build("roof_pitch")
	var stand:= Vector3(wall.a.x + 3.0, _floor, wall.a.z + 2.0)
	var target:= Vector3(wall.a.x, wall.a.y + Cfg.WALL_HEIGHT, wall.a.z + 2.0)
	player.global_position = stand
	var eye:= stand + Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	var to:= target - eye
	player.set_look(atan2(- to.x, - to.z),
		atan2(to.y, Vector3(to.x, 0.0, to.z).length()))
	await _settle()
	var ghost: Roof = player.build.get("_roof_ghost")
	if ghost == null:
		_ok(false, "the hologram is up")
		return
	var before:= ghost.b - ghost.a
	_press("build_rotate")
	await _settle()
	var after:= ghost.b - ghost.a


	_ok(absf(before.normalized().dot(after.normalized())) < 0.01,
		"one press turns the run a quarter turn")
	for i in 3:
		_press("build_rotate")
		await _settle()
	_ok((ghost.b - ghost.a).normalized().dot(before.normalized()) > 0.99,
		"four presses is where it started")


	player.build.primary()
	await _settle()
	var started: Dictionary = player.build.status()
	_ok(bool(started ["placing"]), "the first click starts a run (%s)"
		% ("running" if started ["placing"] else str(started ["reason"])))
	var side_before:= ghost.side
	_press("build_rotate")
	await _settle()
	_ok(ghost.side == - side_before,
		"on a started run it puts the slope on the other side (%d then %d, turn %d, placing %s)"
			% [side_before, ghost.side, int(player.build.get("_roof_turn")),
				str(player.build.status() ["placing"])])
	player.build.cancel()
	builds.demolish(wall)
	await _settle()


func _case_turn_in_cell() -> void:
	print("\n=== a bay turns inside its own square ===")
	var a:= _origin + Vector3(0.0, 0.0, -3.0)
	var wall:= builds.add_wall(a, a + Vector3(0.0, 0.0, 6.0), YardWall.Bay.SOLID)
	await _settle()
	player.equip_build("roof_hatch")
	var eave_y:= wall.a.y + Cfg.WALL_HEIGHT
	var column:= Vector3(wall.a.x, eave_y, wall.a.z + Cfg.ROOF_BAY)
	await _look_at(Vector3(wall.a.x + 3.0, _floor, wall.a.z + Cfg.ROOF_BAY),
		column)
	var ghost: Roof = player.build.get("_roof_ghost")
	if ghost == null:
		_ok(false, "the hologram is up")
		return
	var first:= _cell_of(ghost)
	_ok(absf(first.position.x - wall.a.x) < 0.001
			or absf(first.end.x - wall.a.x) < 0.001,
		"the bay has an edge on the wall")
	for turn in 3:
		_press("build_rotate")
		await _settle()
		var cell:= _cell_of(ghost)
		_ok(cell.position.distance_to(first.position) < 0.001
				and cell.size.distance_to(first.size) < 0.001,
			"turn %d covers the same square (%s against %s)"
				% [turn + 1, cell, first])
		var status: Dictionary = player.build.status()
		_ok(bool(status ["ok"]), "...and can still be built (%s)"
			% ("green" if status ["ok"] else str(status ["reason"])))
	_press("build_rotate")
	await _settle()
	_ok(_cell_of(ghost).position.distance_to(first.position) < 0.001,
		"four turns is where it started")
	player.build.cancel()
	builds.demolish(wall)
	await _settle()


func _cell_of(lid: Roof) -> Rect2:
	var reach:= _reach_of(lid)
	var out:= Rect2(Vector2(lid.a.x, lid.a.z), Vector2.ZERO)
	for c: Vector2 in [Vector2(lid.b.x, lid.b.z),
			Vector2(lid.a.x + reach.x, lid.a.z + reach.z),
			Vector2(lid.b.x + reach.x, lid.b.z + reach.z)]:
		out = out.expand(c)
	return out


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
	_ok(false, "the %s action has a key bound to press" % action)


func _case_chain() -> void:
	print("\n=== two runs share a joint ===")
	var a:= _origin + Vector3(2.0, 2.4, -2.0)
	var first:= builds.add_roof(a, a + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.FLAT, 1)
	await _settle()

	var aimed:= first.b + Vector3(0.12, 0.0, 0.2)
	var snapped:= builds.snap_roof_point(aimed)
	_same(snapped, first.b, "an aim near the end of a run lands on its joint")
	var second:= builds.add_roof(snapped, snapped + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.FLAT, 1)
	await _settle()
	_same(second.a, first.b, "...so the next run starts where the last one ended")

	_ok(builds.roof_overlap(second.a, second.b, Roof.Kind.FLAT),
		"a run laid along one already there is refused")
	builds.demolish(first)
	builds.demolish(second)
	await _settle()


func _case_ridge() -> void:
	print("\n=== two pitched runs meet at the ridge ===")
	var span:= Cfg.ROOF_DEPTH * 2.0
	var left:= _origin + Vector3(4.0, 2.4, -2.0)
	var right:= left + Vector3(span, 0.0, 0.0)
	var one:= builds.add_roof(left, left + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.PITCHED, 1)
	var two:= builds.add_roof(right, right + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.PITCHED, -1)
	await _settle()
	_same(_far_edge(one), _far_edge(two),
		"the two far edges are the same line, which is the ridge")
	_ok(absf(_far_edge(one).y - (left.y + Cfg.ROOF_RISE)) < 0.001,
		"...standing a full rise above the eaves")
	builds.demolish(one)
	builds.demolish(two)
	await _settle()


func _far_edge(lid: Roof) -> Vector3:
	return lid.to_global(Vector3(float(lid.side) * Cfg.ROOF_DEPTH,
		Cfg.ROOF_RISE if lid.pitched() else 0.0, 0.0))


func _case_surface() -> void:
	print("\n=== the sheet is a surface ===")
	_ok(StructureKit.roof_pitch() < deg_to_rad(45.0),
		"the pitch is %.0f degrees, inside what the legs will walk up"
			% rad_to_deg(StructureKit.roof_pitch()))
	var a:= _origin + Vector3(8.0, 2.4, -2.0)
	var lid:= builds.add_roof(a, a + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.PITCHED, 1)
	await _settle()
	_ok((lid.collision_layer & Cfg.L_BUILD) != 0,
		"it is on the build layer, so a belt or a deck can be aimed at it")

	var mid:= lid.to_global(Vector3(float(lid.side) * Cfg.ROOF_DEPTH * 0.5,
		Cfg.ROOF_RISE * 0.5, 0.0))
	var hit:= _drop_onto(mid + Vector3.UP * 2.0)
	_ok(not hit.is_empty() and builds.owner_of(hit.get("collider")) == lid,
		"a ray dropped onto the middle of the slope lands on it")
	if not hit.is_empty():
		_ok(absf((hit ["position"] as Vector3).y - mid.y) < 0.05,
			"...at the height the sheet is drawn (%.3f m out)"
				% absf((hit ["position"] as Vector3).y - mid.y))
	builds.demolish(lid)
	await _settle()


	for kind: Roof.Kind in [Roof.Kind.FLAT, Roof.Kind.PITCHED]:
		for side: int in [1, -1]:
			var deep:= builds.add_roof(a, a + Vector3(0.0, 0.0, 4.0), kind, side, 3)
			await _settle()
			for row in 3:
				var on:= deep.to_global(Vector3(
					float(side) * Cfg.ROOF_DEPTH * (float(row) + 0.5),
					Cfg.ROOF_RISE * (float(row) + 0.5) if deep.pitched() else 0.0, 0.0))
				var got:= _drop_onto(on + Vector3.UP * 2.0)
				_ok(not got.is_empty() and builds.owner_of(got.get("collider")) == deep
						and absf((got ["position"] as Vector3).y - on.y) < 0.05,
					"%s, side %d: row %d is solid where it is drawn"
						% ["angled" if deep.pitched() else "flat", side, row])
			builds.demolish(deep)
			await _settle()


func _case_hatch_is_a_hole() -> void:
	print("\n=== the hatch is open ===")
	var lid:= await _hatch()
	var centre:= lid.to_global(Vector3(float(lid.side) * Cfg.ROOF_DEPTH * 0.5,
		0.0, 0.0))
	var through:= _drop_onto(centre + Vector3.UP * 1.5)
	_ok(through.is_empty() or builds.owner_of(through.get("collider")) != lid,
		"a ray dropped down the middle of the bay goes through it")


	var margin:= lid.to_global(Vector3(
		float(lid.side) * (Cfg.ROOF_DEPTH - Cfg.ROOF_HATCH) * 0.25, 0.0, 0.0))
	var solid:= _drop_onto(margin + Vector3.UP * 1.5)
	_ok(not solid.is_empty()
			and builds.owner_of(solid.get("collider")) == lid,
		"...and the sheet either side of it is still solid")
	builds.demolish(lid)
	await _settle()


func _case_ladder() -> void:
	print("\n=== the ladder reaches the ground ===")
	var lid:= await _hatch()
	_ok(lid.has_ladder(), "a hatch bay has a ladder")
	var drop:= lid.ladder_top_y() - lid.ladder_foot_y()


	var under:= _floor_under(lid)
	_ok(absf(drop - (lid.ladder_top_y() - under)) < 0.15,
		"it is as long as the drop under it (%.2f m against %.2f m)"
			% [drop, lid.ladder_top_y() - under])
	_ok(lid.ladder_foot_y() <= _floor + 0.15, "...so its foot is on the floor")
	var volume:= lid.find_child("LadderVolume", true, YardWall.Bay.SOLID) as Area3D
	_ok(volume != null and volume.monitoring,
		"there is a volume in front of it that watches for a climber")
	_ok(volume != null and (volume.collision_mask & Cfg.L_PLAYER) != 0,
		"...watching for the player and nothing else")

	var plain:= builds.add_roof(lid.a + Vector3(0.0, 0.0, 4.0),
		lid.a + Vector3(0.0, 0.0, 6.0), Roof.Kind.FLAT, lid.side)
	await _settle()
	_ok(not plain.has_ladder(), "a plain bay has no ladder")
	builds.demolish(plain)
	builds.demolish(lid)
	await _settle()


func _case_climb() -> void:
	print("\n=== the player climbs it ===")
	var lid:= await _hatch()
	var face:= lid.ladder_face()
	var stand:= lid.ladder_stand_point()
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(stand.x, _floor, stand.z)


	player.set_look(atan2(face.x, face.z), 0.0)
	await _settle()
	_ok(player.get("_ladder") != null, "standing in the volume finds the ladder")

	var started:= player.global_position.y
	Input.action_press("move_forward")
	var climbed:= await _wait_until(func() -> bool:
		return player.global_position.y > started + 0.6)
	_ok(climbed, "holding forward takes the player off the floor")
	var topped:= await _wait_until(func() -> bool:
		return player.global_position.y >= lid.ladder_top_y() - 0.05)
	_ok(topped, "...and carries them up to the roof (%.2f m of %.2f m)"
		% [player.global_position.y - started, lid.ladder_top_y() - started])
	Input.action_release("move_forward")
	for i in 30:
		await get_tree().physics_frame
	_ok(player.global_position.y >= lid.ladder_top_y() - 0.1,
		"letting go at the top leaves them standing on it, not back down the hole"
			+ " (feet at %.2f m of %.2f m)"
			% [player.global_position.y, lid.ladder_top_y()])
	_ok(player.is_on_floor(), "...with something under their feet")


	player.velocity = Vector3.ZERO
	player.global_position = Vector3(stand.x, _floor, stand.z)
	await _settle()
	Input.action_press("move_forward")
	var again:= await _wait_until(func() -> bool:
		return player.global_position.y > _floor + 0.6)
	_ok(again, "the player takes hold again from the bottom")
	Input.action_press("jump")
	await _settle()
	Input.action_release("jump")
	_ok(not bool(player.get("_climbing")), "pressing jump lets go of the rungs")
	for i in 40:
		await get_tree().physics_frame
	_ok(player.global_position.distance_to(stand) > 0.5,
		"...and pushes them clear of the ladder")
	Input.action_release("move_forward")

	player.global_position = Vector3(_origin.x, _floor, _origin.z - 8.0)
	builds.demolish(lid)
	await _settle()


func _case_save() -> void:
	print("\n=== it survives a save ===")
	var a:= _origin + Vector3(-2.0, 2.4, -2.0)
	var made:= builds.add_roof(a, a + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.PITCHED, -1)
	await _settle()


	var made_a:= made.a
	var made_b:= made.b
	var written:= builds.to_array()
	var found:= { }
	for entry: Variant in written:
		var d: Dictionary = entry
		if d.get("type", "") == "roof":
			found = d
	_ok(not found.is_empty(), "a roof is written into the save")
	builds.from_array(written)
	await _settle()
	_ok(builds.roofs.size() == 1, "one roof comes back")
	if builds.roofs.is_empty():
		return
	var back: Roof = builds.roofs [0]
	_same(back.a, made_a, "the eave is where it was")
	_same(back.b, made_b, "the far end is where it was")
	_ok(back.kind == Roof.Kind.PITCHED, "it is still angled")
	_ok(back.side == -1, "it still reaches the way it was built")
	builds.clear()
	await _settle()


func _case_dismantle() -> void:
	print("\n=== it comes down again ===")
	var a:= _origin + Vector3(0.0, 2.4, -2.0)
	var lid:= builds.add_roof(a, a + Vector3(0.0, 0.0, 4.0),
		Roof.Kind.FLAT, 1)
	await _settle()
	var mid:= lid.to_global(Vector3(float(lid.side) * Cfg.ROOF_DEPTH * 0.5,
		0.0, 0.0))
	var hit:= _drop_onto(mid + Vector3.UP * 2.0)
	_ok(not hit.is_empty()
			and builds.owner_of(hit.get("collider")) == lid,
		"a collider on a roof answers as the roof")
	var worth:= lid.build_cost()
	var refund:= builds.demolish(lid)
	await _settle()


	_ok(absf(refund - worth) < 0.01,
		"taking it down refunds what it cost ($%.2f)" % refund)
	_ok(builds.roofs.is_empty(), "and it is gone from the yard")


func _case_holds_an_arm() -> void:
	print("\n=== a roof holds up what stands on it ===")
	var a:= _origin + Vector3(0.0, 2.4, -2.0)
	var lid:= builds.add_roof(a, a + Vector3(0.0, 0.0, 4.0), Roof.Kind.FLAT, 1)
	var next:= builds.add_roof(a + Vector3(0.0, 0.0, 4.0), a + Vector3(0.0, 0.0, 8.0),
		Roof.Kind.FLAT, 1)
	await _settle()
	var mid:= lid.to_global(Vector3(float(lid.side) * Cfg.ROOF_DEPTH * 0.5, 0.0, 0.0))
	_ok(lid.supports_point(mid), "a point on the sheet is on the roof")
	_ok(not lid.supports_point(mid + Vector3.DOWN * 1.0), "and one under it is not")
	_ok(builds.standing_on(lid).is_empty(),
		"the roof chained along its eave is not standing on it")
	var arm:= builds.add_robotic_arm(mid, 0.0)
	await _settle()
	_ok(builds.standing_on(lid).has(arm), "an arm on the sheet is standing on it")
	_ok(builds.demolish_blocked_reason(lid) != "",
		"so taking it down is refused (%s)" % builds.demolish_blocked_reason(lid))
	_ok(is_zero_approx(builds.demolish(lid)) and builds.roofs.has(lid),
		"and a dismantle leaves it up")
	var tool: BuildTool = player.build
	var belt:= builds.add_conveyor(_origin + Vector3(-3.0, 0.0, -2.0),
		_origin + Vector3(-3.0, 0.0, 2.0))
	await _settle()
	_ok(tool._ground_reason(lid) == "", "an arm may be founded on a roof")


	var on_belt:= _drop_onto(_origin + Vector3(-3.0, 3.0, 0.0))
	var struck: Object = on_belt.get("collider")
	_ok(struck != null and builds.owner_of(struck) == belt, "the ray lands on the belt")
	_ok(tool._ground_reason(struck) != "",
		"and not on a belt (%s)" % tool._ground_reason(struck))
	builds.demolish(arm)
	builds.demolish(belt)
	await _settle()
	_ok(builds.demolish_blocked_reason(lid) == "", "with the arm gone it comes down")
	builds.demolish(lid)
	builds.demolish(next)
	await _settle()
	_ok(builds.roofs.is_empty(), "and both roofs are gone")


func _case_not_on_the_ground() -> void:
	print("\n=== a roof does not go on the ground ===")
	var ground:= _ground_at(_origin)
	var a:= Vector3(_origin.x, ground, _origin.z - 1.0)
	for kind: Roof.Kind in [Roof.Kind.FLAT, Roof.Kind.PITCHED, Roof.Kind.HATCH]:
		_ok(builds.roof_unsupported(a, a + Vector3(0.0, 0.0, Cfg.ROOF_BAY), kind, 1),
			"kind %d laid on the dirt has nothing under its eave" % kind)

	player.equip_build("roof_hatch")
	await _look_at(Vector3(_origin.x - 4.0, _floor, _origin.z), a)
	var status: Dictionary = player.build.status()
	_ok(not bool(status ["ok"]),
		"a hatch aimed at open ground is refused (%s)" % str(status ["reason"]))
	player.build.cancel()
	await _settle()


func _case_hatch_needs_room() -> void:
	print("\n=== a hatch needs room under it ===")
	var ground:= _ground_at(_origin)
	var deck:= builds.add_platform(Vector3(_origin.x + 2.0, ground + 1.0, _origin.z),
		Vector2(6.0, 6.0))
	await _settle()
	var tile:= BuildManager.deck_tile_at(deck, deck.global_position)
	var from:= Vector3(tile.position.x, deck.top_y(), tile.position.y)
	var drop:= builds.hatch_drop(from, from + Vector3(0.0, 0.0, Cfg.ROOF_BAY), 1, deck)
	_ok(drop < Cfg.ROOF_HATCH_MIN_DROP,
		"the drop under a deck a metre up is %.2f m, short of %.1f m"
			% [drop, Cfg.ROOF_HATCH_MIN_DROP])
	player.equip_build("roof_hatch")
	var corner:= deck.global_position + Vector3(-2.0, 0.0, -2.0)
	await _look_at(corner, deck.global_position)
	var status: Dictionary = player.build.status()
	_ok(not bool(status ["ok"]),
		"...and the tool refuses it (%s)" % str(status ["reason"]))
	player.build.cancel()
	player.global_position = Vector3(_origin.x - 6.0, _floor, _origin.z)
	await _settle()
	builds.demolish(deck)
	await _settle()


func _case_hatch_into_deck() -> void:
	print("\n=== a hatch goes into a deck ===")
	var ground:= _ground_at(_origin)
	var deck:= builds.add_platform(Vector3(_origin.x + 2.0, ground + 2.6, _origin.z),
		Vector2(6.0, 6.0))
	await _settle()
	var top:= deck.top_y()
	var paid:= deck.build_cost()
	var centre:= deck.global_position
	player.equip_build("roof_hatch")

	await _look_at(centre + Vector3(-2.0, 0.0, -2.0), centre)
	var status: Dictionary = player.build.status()
	_ok(bool(status ["ok"]), "a hatch aimed at the middle of a deck is green (%s)"
		% ("green" if status ["ok"] else str(status ["reason"])))
	var hatch_price:= Roof.cost_for(Vector3.ZERO, Vector3(0.0, 0.0, Cfg.ROOF_BAY),
		Roof.Kind.HATCH)
	var tile_share:= paid / 9.0
	_ok(absf(float(status ["cost"]) - (hatch_price - tile_share)) < 0.01,
		"it is billed the hatch less the tile ($%.2f against $%.2f)"
			% [float(status ["cost"]), hatch_price - tile_share])
	var money_before:= GameState.money
	player.build.primary()
	await _settle()
	_ok(absf((money_before - GameState.money) - float(status ["cost"])) < 0.01,
		"...and that is what the click took ($%.2f)" % (money_before - GameState.money))
	_ok(builds.roofs.size() == 1, "one hatch went in")
	_ok(builds.platforms.size() == 4,
		"the deck went back down as four pieces (got %d)" % builds.platforms.size())
	if builds.roofs.is_empty():
		player.build.cancel()
		builds.clear()
		await _settle()
		return
	var lid: Roof = builds.roofs [0]
	var cell:= _cell_of(lid)
	var middle:= Rect2(Vector2(centre.x - 1.0, centre.z - 1.0), Vector2(2.0, 2.0))
	_ok(cell.position.distance_to(middle.position) < 0.001
			and cell.size.distance_to(middle.size) < 0.001,
		"it fills the middle tile (%s against %s)" % [cell, middle])
	_ok(absf(lid.a.y - top) < 0.001, "its sheet is level with the plate")
	_ok(lid.deck_style, "it is dressed in deck plate, not roof sheet")
	var area:= 0.0
	var refunds:= lid.build_cost()
	for piece: Platform in builds.platforms:
		_ok(absf(piece.top_y() - top) < 0.001, "a piece is at the deck's height")
		_ok(not piece.footprint().grow(-0.01).intersects(middle),
			"...and none of it is over the hole")
		area += piece.footprint().get_area()
		refunds += piece.build_cost()
	_ok(absf(area - 32.0) < 0.01, "the pieces cover the deck less one tile (%.1f m2)" % area)
	_ok(absf(refunds - (paid + float(status ["cost"]))) < 0.01,
		"taking it all down pays back what went in ($%.2f against $%.2f)"
			% [refunds, paid + float(status ["cost"])])
	lid.refresh_ladder(true)
	await _settle()
	var through:= _drop_onto(Vector3(centre.x, top + 1.0, centre.z))
	_ok(through.is_empty() or builds.owner_of(through.get("collider")) is not Platform,
		"a ray down the middle of the tile goes through the hole")
	_ok(lid.has_ladder(), "the hatch has a ladder")
	_ok(lid.ladder_foot_y() <= ground + 0.15,
		"...down to the floor (foot %.2f m, floor %.2f m)" % [lid.ladder_foot_y(), ground])
	player.build.cancel()
	player.global_position = Vector3(_origin.x - 6.0, _floor, _origin.z)
	builds.clear()
	await _settle()


func _case_shift_x_takes_one_tile() -> void:
	print("\n=== shift and X take one tile of a deck ===")
	var ground:= _ground_at(_origin)
	var deck:= builds.add_platform(Vector3(_origin.x + 2.0, ground + 1.0, _origin.z),
		Vector2(6.0, 6.0))
	await _settle()
	var top:= deck.top_y()
	var paid:= deck.build_cost()
	var centre:= deck.global_position
	var corner:= Vector3(centre.x - 2.0, top, centre.z - 2.0)
	var money_before:= GameState.money
	await _look_at(Vector3(centre.x - 6.0, ground, centre.z - 2.0), corner)
	_ok(player.build.dismantle_target() == deck, "the crosshair is on the deck")
	var shift:= InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	var x:= InputEventKey.new()
	x.keycode = KEY_X
	x.physical_keycode = KEY_X
	x.shift_pressed = true
	x.pressed = true
	Input.parse_input_event(x)

	var went:= await _wait_until(func() -> bool: return builds.platforms.size() > 1)
	x = x.duplicate() as InputEventKey
	x.pressed = false
	Input.parse_input_event(x)
	shift = shift.duplicate() as InputEventKey
	shift.pressed = false
	Input.parse_input_event(shift)
	await _settle()
	_ok(went, "the hold came to an end")
	var area:= 0.0
	var left:= 0.0
	var gone:= Rect2(Vector2(corner.x - 1.0, corner.z - 1.0), Vector2(2.0, 2.0))
	for piece: Platform in builds.platforms:
		area += piece.footprint().get_area()
		left += piece.build_cost()
		_ok(not piece.footprint().grow(-0.01).intersects(gone),
			"a piece stays off the tile that went")
	_ok(absf(area - 32.0) < 0.01, "the deck is still up, less one tile (%.1f m2)" % area)
	_ok(absf((GameState.money - money_before) - paid / 9.0) < 0.01,
		"the tile paid back its share ($%.2f against $%.2f)"
			% [GameState.money - money_before, paid / 9.0])
	_ok(absf(left + paid / 9.0 - paid) < 0.01, "and the rest still owes the remainder")
	player.global_position = Vector3(_origin.x - 6.0, _floor, _origin.z)
	builds.clear()
	await _settle()


func _case_hatch_into_deck_from_below() -> void:
	print("\n=== a hatch goes into a deck from below ===")
	var ground:= _ground_at(_origin)
	var deck:= builds.add_platform(Vector3(_origin.x + 2.0, ground + 2.6, _origin.z),
		Vector2(6.0, 6.0))
	await _settle()
	var top:= deck.top_y()
	var centre:= deck.global_position
	player.equip_build("roof_hatch")
	await _look_at(Vector3(centre.x - 1.6, ground, centre.z - 1.6),
		Vector3(centre.x + 0.3, top - 0.3, centre.z + 0.3))
	var status: Dictionary = player.build.status()
	_ok(bool(status ["ok"]), "a hatch aimed up at a deck's underside is green (%s)"
		% ("green" if status ["ok"] else str(status ["reason"])))
	player.build.primary()
	await _settle()
	_ok(builds.roofs.size() == 1, "one hatch went in from below")
	if not builds.roofs.is_empty():
		var lid: Roof = builds.roofs [0]
		var cell:= _cell_of(lid)
		var middle:= Rect2(Vector2(centre.x - 1.0, centre.z - 1.0), Vector2(2.0, 2.0))
		_ok(cell.position.distance_to(middle.position) < 0.001
				and cell.size.distance_to(middle.size) < 0.001,
			"it fills the tile it was aimed at (%s against %s)" % [cell, middle])
		_ok(absf(lid.a.y - top) < 0.001, "its sheet is level with the plate")
	player.build.cancel()
	player.global_position = Vector3(_origin.x - 6.0, _floor, _origin.z)
	builds.clear()
	await _settle()


func _case_hatch_lying_on_a_deck() -> void:
	print("\n=== a hatch lying on a deck ===")
	var ground:= _ground_at(_origin)
	var deck:= builds.add_platform(Vector3(_origin.x + 2.0, ground + 2.6, _origin.z),
		Vector2(6.0, 6.0))
	await _settle()
	var top:= deck.top_y()
	var from:= Vector3(deck.global_position.x - 1.0, top, deck.global_position.z - 1.0)
	var to:= from + Vector3(0.0, 0.0, Cfg.ROOF_BAY)
	var drop:= builds.hatch_drop(from, to, 1)
	_ok(drop < Cfg.ROOF_HATCH_MIN_DROP,
		"the drop under a hatch on the plate is the plate (%.2f m)" % drop)
	var lid:= builds.add_roof(from, to, Roof.Kind.HATCH, 1)
	await _settle()

	var margin:= lid.to_global(Vector3(float(lid.side) * 0.2, 0.0, 0.0))
	await _look_at(Vector3(margin.x - 2.5, top, margin.z), margin)
	var target:= player.build.dismantle_target()
	_ok(target == lid, "the dismantle ray takes the hatch, not the deck under it (%s)"
		% (target.name if target != null else "nothing"))
	builds.demolish(lid)
	await _settle()
	_ok(builds.roofs.is_empty(), "...and it comes down")
	await _look_at(Vector3(margin.x - 2.5, top, margin.z), margin)
	_ok(player.build.dismantle_target() == deck, "then the ray finds the deck again")
	player.global_position = Vector3(_origin.x - 6.0, _floor, _origin.z)
	builds.clear()
	await _settle()


func _case_hatch_into_a_hole() -> void:
	print("\n=== a hatch goes into a hole in a floor ===")
	var ground:= _ground_at(_origin)
	var deck:= builds.add_platform(Vector3(_origin.x + 2.0, ground + 2.6, _origin.z),
		Vector2(6.0, 6.0))
	await _settle()
	var top:= deck.top_y()
	var centre:= deck.global_position
	var middle:= Rect2(Vector2(centre.x - 1.0, centre.z - 1.0), Vector2(2.0, 2.0))
	builds.remove_deck_tile(deck, BuildManager.deck_tile_at(deck, centre))
	await _settle()
	_ok(builds.platforms.size() == 4, "the tile is out and four pieces ring the hole")
	var full_price:= Roof.cost_for(Vector3.ZERO, Vector3(0.0, 0.0, Cfg.ROOF_BAY),
		Roof.Kind.HATCH)
	player.equip_build("roof_hatch")
	var aims: Array = [
		["through the hole from the deck",
			centre + Vector3(-2.0, 0.0, -2.0), Vector3(centre.x, top, centre.z)],
		["at the edge of the tile beside it",
			centre + Vector3(-2.0, 0.0, -2.0), Vector3(centre.x - 1.3, top, centre.z)],
		["up through it from the floor",
			Vector3(centre.x - 1.4, ground, centre.z - 1.4),
			Vector3(centre.x + 0.2, top, centre.z + 0.2)],
	]
	for aim: Array in aims:
		var what: String = aim [0]
		await _look_at(aim [1] as Vector3, aim [2] as Vector3)
		var status: Dictionary = player.build.status()
		_ok(bool(status ["ok"]), "aimed %s the hatch is green (%s)"
			% [what, "green" if status ["ok"] else str(status ["reason"])])
		_ok(absf(float(status ["cost"]) - full_price) < 0.01,
			"...at a hatch's full price ($%.2f against $%.2f)"
				% [float(status ["cost"]), full_price])
		var money_before:= GameState.money
		player.build.primary()
		await _settle()
		_ok(builds.roofs.size() == 1, "...and one hatch went in")
		_ok(builds.platforms.size() == 4, "...with nothing cut (%d pieces)"
			% builds.platforms.size())
		_ok(absf((money_before - GameState.money) - full_price) < 0.01,
			"...for the full price ($%.2f)" % (money_before - GameState.money))
		if not builds.roofs.is_empty():
			var lid: Roof = builds.roofs [0]
			var cell:= _cell_of(lid)
			_ok(cell.position.distance_to(middle.position) < 0.001
					and cell.size.distance_to(middle.size) < 0.001,
				"...filling the hole (%s against %s)" % [cell, middle])
			_ok(absf(lid.a.y - top) < 0.001, "...level with the plate")
			builds.demolish(lid)
			await _settle()
		_ok(builds.roofs.is_empty(), "...and it comes down again")


	await _look_at(centre + Vector3(-2.0, 0.0, -2.0), Vector3(centre.x - 2.0, top, centre.z))
	var status: Dictionary = player.build.status()
	_ok(bool(status ["ok"]), "aimed at the middle of a tile beside the hole it is green")
	_ok(player.build._hatch_deck != null and not player.build._hatch_gap,
		"...and it is a cut into that tile, not a jump to the hole")

	var from:= Vector3(middle.position.x, top, middle.position.y)
	var lid:= builds.add_roof(from, from + Vector3(0.0, 0.0, Cfg.ROOF_BAY),
		Roof.Kind.HATCH, 1)
	await _settle()
	await _look_at(centre + Vector3(-2.0, 0.0, -2.0), Vector3(centre.x - 1.3, top, centre.z))
	status = player.build.status()
	_ok(not player.build._hatch_gap,
		"with a hatch in the hole, the tile's edge is the tile again")
	builds.demolish(lid)
	player.build.cancel()
	player.global_position = Vector3(_origin.x - 6.0, _floor, _origin.z)
	builds.clear()
	await _settle()


func _case_ghost_is_pulled_forward() -> void:
	print("\n=== the ghost is pulled toward the eye ===")
	for ok: bool in [true, false]:
		var m:= ConveyorKit.ghost_material(ok)
		_ok(m is ShaderMaterial and (m as ShaderMaterial).shader != null,
			"the %s ghost is a shader material" % ("green" if ok else "red"))
		var code: String = (m as ShaderMaterial).shader.code
		_ok("CAMERA_POSITION_WORLD" in code and "world_vertex_coords" in code,
			"...that moves its vertices toward the camera")
		var pull: float = m.get_shader_parameter("pull")
		_ok(pull > 0.005 and pull < 0.05, "...by %.3f m" % pull)
		var tint: Color = m.get_shader_parameter("tint")
		var want:= Cfg.COL_GHOST_OK if ok else Cfg.COL_GHOST_BAD
		_ok(tint.r == want.r and tint.g == want.g and tint.b == want.b,
			"...in the colour it always was")


func _ground_at(p: Vector3) -> float:
	var from:= Vector3(p.x, p.y + 20.0, p.z)
	var q:= PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 60.0)
	q.collision_mask = Cfg.L_WORLD
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit ["position"] as Vector3).y if not hit.is_empty() else _floor - 0.24


func _hatch() -> Roof:
	var a:= Vector3(_origin.x, _floor + Cfg.WALL_HEIGHT, _origin.z - 1.0)
	var lid:= builds.add_roof(a, a + Vector3(0.0, 0.0, Cfg.ROOF_BAY),
		Roof.Kind.HATCH, 1)
	await _settle()


	lid.refresh_ladder(true)
	await _settle()
	return lid


func _floor_under(lid: Roof) -> float:
	var from:= Vector3(lid.global_position.x, lid.ladder_top_y() - 0.05,
		lid.global_position.z)
	var q:= PhysicsRayQueryParameters3D.create(from,
		from - Vector3.UP * Cfg.LADDER_MAX_DROP)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.exclude = [lid.get_rid()]
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit ["position"] as Vector3).y if not hit.is_empty() else from.y


func _drop_onto(from: Vector3) -> Dictionary:
	var q:= PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 4.0)
	q.collision_mask = Cfg.L_BUILD
	return world.get_world_3d().direct_space_state.intersect_ray(q)


func _settle() -> void:
	for i in SETTLE:
		await get_tree().physics_frame


func _wait_until(test: Callable) -> bool:
	for i in PATIENCE:
		if bool(test.call()):
			return true
		await get_tree().physics_frame
	return false


func _case_shared_joints() -> void:
	print("\n=== a shared joint is drawn once ===")
	var a:= _origin + Vector3(0.0, 0.0, -6.0)
	var along:= builds.add_wall(a, a + Vector3(4.0, 0.0, 0.0), YardWall.Bay.SOLID)
	var across:= builds.add_wall(a + Vector3(4.0, 0.0, 0.0),
		a + Vector3(4.0, 0.0, 2.0), YardWall.Bay.SOLID)
	await _settle()
	_ok(_drawn(along, "Posts") == 3, "the first run keeps all three of its posts (%d)"
		% _drawn(along, "Posts"))
	_ok(_drawn(across, "Posts") == 1, "the second leaves the corner to it (%d)"
		% _drawn(across, "Posts"))
	builds.demolish(along)
	await _settle()
	_ok(_drawn(across, "Posts") == 2, "and gets it back when the first comes down (%d)"
		% _drawn(across, "Posts"))
	builds.demolish(across)

	var top:= a + Vector3(0.0, 2.4, 0.0)
	var one:= builds.add_roof(top, top + Vector3(2.0, 0.0, 0.0), Roof.Kind.FLAT, 1)
	var two:= builds.add_roof(top + Vector3(4.0, 0.0, 0.0), top + Vector3(2.0, 0.0, 0.0),
		Roof.Kind.FLAT, -1)
	await _settle()
	_ok(one.rafter_keys() [1] == two.rafter_keys() [1],
		"two runs butted at a joint reaching the same way share its rafter")
	_ok(_drawn(one, "Rafters") + _drawn(two, "Rafters") == 3,
		"and three rafters are drawn under two bays, not four (%d)"
		% (_drawn(one, "Rafters") + _drawn(two, "Rafters")))
	builds.demolish(one)
	builds.demolish(two)

	var rail:= a + Vector3(0.0, 0.0, 4.0)
	builds.add_wall(rail, rail + Vector3(2.0, 0.0, 0.0), YardWall.Bay.DOOR)
	_ok(builds.wall_along(rail + Vector3(2.0, 0.0, 0.0), rail),
		"a railing along a wall's line is found, either way round")
	_ok(not builds.wall_along(rail + Vector3(0.0, 0.0, 1.0),
		rail + Vector3(2.0, 0.0, 1.0)), "and one a metre off it is not")
	builds.demolish(builds.walls.back())
	await _settle()


func _drawn(node: Node, part: String) -> int:
	var mmi:= node.get_node_or_null(part) as MultiMeshInstance3D
	return mmi.multimesh.instance_count if mmi != null else -1
