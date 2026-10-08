class_name DevBeltRouteProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 40


const CLUTTER:= 150

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	var tool: BuildTool = player.build
	var builds: BuildManager = world.builds
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	GameState.add_money(100000.0)


	tool.set_active(false)
	tool._mode = BuildTool.Mode.CONVEYOR


	await _inlet_start_case(tool, builds, lift)
	await _wall_case(tool, builds, lift)
	await _boxed_case(tool, lift)
	await _doubling_back_case(tool, builds, lift)
	await _port_case(tool, builds, lift)
	await _timing(tool, builds, lift)

	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit()


func _glow_case(tool: BuildTool) -> void:
	print("\n=== the bar offers the way round, glowing ===")
	var strip: ControlHints = null
	if world.hud != null:
		strip = world.hud.get_node_or_null("ControlHints") as ControlHints
	if strip == null:
		_check("the hint strip is in the HUD", false)
		return
	var was_id:= player.build_id
	var was_tool:= player.current_tool
	var was_captured:= player.is_mouse_captured()
	player.build_id = "belt"
	player.current_tool = Player.Tool.BUILD
	player._mouse_captured = true
	tool._active = true

	var row:= _rotate_row(strip)
	_check("the bar offers the rotate key (%s)" % ", ".join(row), row.size() >= 3)
	if row.size() >= 3:
		_check("worded as another way round (%s)" % row [1],
			row [1] == tr("Go another way"))
		_check("and marked to glow (%s)" % row [2], row [2] == "glow")


	var kept:= tool._route
	tool._route = PackedVector3Array()
	_check("and offers nothing with no way round", _rotate_row(strip).is_empty())
	tool._route = kept

	tool._active = false
	player._mouse_captured = was_captured
	player.current_tool = was_tool
	player.build_id = was_id


func _rotate_row(strip: ControlHints) -> PackedStringArray:
	var want:= ControlHints._key("build_rotate")
	for row: PackedStringArray in strip.call("_hints") as Array:
		if row.size() >= 2 and row [0] == want:
			return row
	return PackedStringArray()


func _wall_case(tool: BuildTool, builds: BuildManager, lift: float) -> void:
	print("\n=== a wall across the line ===")
	var from:= Vector3(-13.5, lift, -5.0)
	var to:= Vector3(-13.5, lift, 0.0)
	_check("the straight run is clear before the wall goes up%s" % _blocker(tool, from, to),
		bool(tool._evaluate(from, to, true) ["ok"]))
	var wall_at:= Vector3(-13.5, 1.0, -2.5)
	var wall_size:= Vector3(2.0, 2.0, 0.3)
	await _wall(wall_at, wall_size)
	var straight:= tool._evaluate(from, to, true)
	_check("the wall blocks the straight run (%s)" % straight ["reason"],
		not bool(straight ["ok"]))

	print("\n=== the stub never routes ===")
	tool._state = BuildTool.State.AIMING
	tool._update_run(from, to, 0.016)
	_check("nothing routed before the anchor click", tool._route.is_empty())

	tool._state = BuildTool.State.RUNNING
	tool._anchor = from
	tool._update_run(from, to, 0.016)
	var route:= tool._route
	print("  route %s  sig %s  %s" % [route, tool._route_sig, tool.status()])
	_check("a way round is found and it is green", bool(tool._eval ["ok"])
		and route.size() > 2)
	if route.size() < 3:
		tool._state = BuildTool.State.AIMING
		return
	_check("it runs from the anchor to the aim",
		route [0].is_equal_approx(from) and route [route.size() - 1].is_equal_approx(to))
	_check("the readout counts its corners", int(tool.status() ["bends"]) == route.size() - 2)
	_legs_pass(tool, route)
	_check("no leg crosses the wall's footprint", not _crosses(route, wall_at, wall_size))

	print("\n=== the route holds still while the aim drifts ===")
	var sig:= tool._route_sig
	var steady:= true
	for k in 12:
		var drift:= to + Vector3(0.0, 0.0, 0.03 * float(k % 4))


		tool._update_run(from, drift, 0.3 if k % 3 == 0 else 0.02)
		if tool._route_sig != sig or not tool._route [tool._route.size() - 1].is_equal_approx(drift):
			steady = false
	_check("same shape through twelve drifting frames (%s)" % sig, steady)
	tool._update_run(from, to, 0.3)

	print("\n=== the rotate key picks another way ===")
	var choices:= tool.route_choices()
	_check("more than one way round (%d)" % choices, choices > 1)
	if choices > 1:
		var before:= tool._route_sig
		_check("next_route answers", tool.next_route())
		_check("and shows a different shape (%s)" % tool._route_sig, tool._route_sig != before)
		_legs_pass(tool, tool._route)
		tool._update_run(from, to, 0.02)
		_check("a picked route survives the next frame", tool._route_sig != before
			and tool._route_pinned)
		_glow_case(tool)

	print("\n=== the click lays what was shown ===")
	route = tool._route
	var preview:= tool._route_preview_points(route)
	var runs_before:= builds.conveyors.size()
	var corners_before:= builds.corners.size()
	var money_before:= GameState.money
	var cost: float = tool._eval ["cost"]
	var bends_drawn:= 0
	for i in range(1, route.size() - 1):
		var a:= route [i - 1]
		var p:= route [i]
		var b:= route [i + 1]
		if BuildManager.corner_tangent((p - a).normalized(), a.distance_to(p),
				(b - p).normalized(), p.distance_to(b)) > 0.0:
			bends_drawn += 1
	tool._active = true
	tool.primary()
	tool._active = false
	var laid:= builds.conveyors.size() - runs_before
	print("  %d legs, %d preview points, laid %d runs, %d new bends, charged %.2f of %.2f"
		% [route.size() - 1, preview.size(), laid, builds.corners.size() - corners_before,
			money_before - GameState.money, cost])
	_check("one run per leg", laid == route.size() - 1)
	_check("one bend per rounded corner in the preview",
		builds.corners.size() - corners_before == bends_drawn)
	_check("charged once, for the whole route", absf(money_before - GameState.money - cost) < 0.01)
	_check("the next run chains on from the aim", tool._anchor.is_equal_approx(to))
	_check("the route is spent", tool._route.is_empty())
	tool._state = BuildTool.State.AIMING

	print("\n=== and it comes down as one belt ===")
	var legs: Array [Conveyor] = []
	for k in range(runs_before, builds.conveyors.size()):
		legs.append(builds.conveyors [k])
	var id:= legs [0].line_id if not legs.is_empty() else 0
	var shared:= id != 0
	for leg in legs:
		shared = shared and leg.line_id == id
	_check("every leg carries the same belt id (%d)" % id, shared)
	_check("line_of finds them all from the last one",
		builds.line_of(legs [legs.size() - 1]).size() == legs.size())
	_check("the id goes into the save", int(legs [legs.size() - 1].to_dict().get("line", 0)) == id)
	_check("the first and last leg are one building to a hold",
		builds.same_building(legs [0], legs [legs.size() - 1]))
	var cash:= GameState.money
	tool.dismantle(legs [1])
	var gone:= true
	for leg in legs:
		gone = gone and not builds.conveyors.has(leg)
	_check("one dismantle takes every leg", gone)
	_check("and pays the whole route back (%.2f of %.2f)" % [GameState.money - cash, cost],
		absf(GameState.money - cash - cost) < 0.01)
	_check("and its bends go with it", builds.corners.size() == corners_before)


func _boxed_case(tool: BuildTool, lift: float) -> void:
	print("\n=== a target walled in ===")
	var from:= Vector3(-14.0, lift, 4.0)
	var to:= Vector3(-14.0, lift, 7.5)
	_check("the straight run is clear before the walls go up%s" % _blocker(tool, from, to),
		bool(tool._evaluate(from, to, true) ["ok"]))
	await _box_round(to, 1.4)
	tool._state = BuildTool.State.RUNNING
	tool._anchor = from
	tool._update_run(from, to, 0.016)
	print("  %s" % tool.status())
	_check("still red", not bool(tool._eval ["ok"]))
	_check("with the straight run's reason (%s)" % tool._eval ["reason"],
		str(tool._eval ["reason"]) in BuildTool.ROUTABLE)
	_check("and no route drawn", tool._route.is_empty())
	tool._state = BuildTool.State.AIMING
	tool._drop_route()


func _doubling_back_case(tool: BuildTool, builds: BuildManager, lift: float) -> void:
	print("\n=== aiming back past the belt this run continues ===")
	var feed: Conveyor = builds.add_conveyor(Vector3(-13.0, lift, 16.0), Vector3(-13.0, lift, 12.0))
	for i in 4:
		await get_tree().physics_frame
	var from:= feed.b
	var to:= Vector3(-11.0, lift, 15.0)
	var straight:= tool._evaluate(from, to, true)
	_check("the straight run is refused (%s)" % straight ["reason"], not bool(straight ["ok"]))
	tool._state = BuildTool.State.RUNNING
	tool._anchor = from
	tool._update_run(from, to, 0.016)
	var route:= tool._route
	print("  route %s  sig %s" % [route, tool._route_sig])
	_check("a way round is found and it is green", bool(tool._eval ["ok"]) and route.size() > 2)
	if route.size() > 2:
		var first:= (route [1] - route [0]).normalized()
		_check("the first leg leaves the belt no sharper than square",
			first.dot(feed.forward) > -0.02)
		_legs_pass(tool, route)
		var corners_before:= builds.corners.size()
		var runs_before:= builds.conveyors.size()
		tool._active = true
		tool.primary()
		tool._active = false
		_check("the turn off the belt gets its bend too",
			builds.corners.size() - corners_before == route.size() - 1)
		var legs: Array [Conveyor] = []
		for k in range(runs_before, builds.conveyors.size()):
			legs.append(builds.conveyors [k])
		_check("the belt it continues is still a belt of its own",
			feed.line_id == 0 and not builds.same_building(feed, legs [0]))
		var starts: Array [Vector3] = []
		for leg in legs:
			starts.append(leg.a)
		_check("reversing one leg answers", builds.reverse_conveyor(legs [legs.size() - 1]))
		var turned:= true
		for k in legs.size():
			turned = turned and legs [k].b.is_equal_approx(starts [k])
		_check("and turns every leg of the belt", turned)
		_check("but not the belt it continues", feed.b.is_equal_approx(from))
	tool._state = BuildTool.State.AIMING
	tool._drop_route()


func _inlet_start_case(tool: BuildTool, builds: BuildManager, lift: float) -> void:
	print("\n=== a belt started on an inlet runs into it ===")
	var press: HayCompressor = builds.add_compressor(Vector3(-13.5, lift, 10.0), 0.0)
	for i in 4:
		await get_tree().physics_frame
	var inlet:= press.port_in()
	var outlet:= press.port_out()
	_check("an empty inlet starts upstream", tool._starts_upstream(inlet))
	_check("an outlet does not", not tool._starts_upstream(outlet))
	var far:= inlet - press.forward() * 4.0
	tool._state = BuildTool.State.RUNNING
	tool._anchor = inlet
	tool._upstream = tool._starts_upstream(inlet)
	tool._update_run(far, inlet, 0.016)
	print("  inlet %s  forward %s  far %s" % [inlet, press.forward(), far])
	_check("the run from the yard into it is green (%s)%s" % [tool._eval ["reason"],
		_blocker(tool, far, inlet)],
		bool(tool._eval ["ok"]))
	tool._lay_run(far, inlet)
	_check("and it arrives on the inlet", builds.feed_run_into(inlet) != null)
	_check("a fed inlet no longer starts upstream", not tool._starts_upstream(inlet))

	var feed:= builds.feed_run_into(inlet)
	while feed != null:
		builds.demolish(feed)
		feed = builds.feed_run_into(inlet)
	builds.demolish(press)
	for i in 4:
		await get_tree().physics_frame
	tool._state = BuildTool.State.AIMING
	tool._upstream = false
	tool._drop_route()


func _port_case(tool: BuildTool, builds: BuildManager, lift: float) -> void:
	print("\n=== a machine intake from its far end ===")
	var scanner: HaystackScanner = builds.add_scanner(Vector3(14.0, lift, 0.0), 0.0)
	for i in 4:
		await get_tree().physics_frame
	var to:= scanner.port_in()
	var along:= scanner.forward()
	var from:= scanner.port_out() + along * 3.0
	await _wall(scanner.port_out() + along * 1.5 + Vector3.UP * 0.6, Vector3(2.0, 2.0, 0.3))
	print("  port_in %s  forward %s  bearing %s" % [to, along, builds.port_bearing_at(to)])
	var straight:= tool._evaluate(from, to, true)
	_check("the straight run is refused (%s)" % straight ["reason"], not bool(straight ["ok"]))
	tool._state = BuildTool.State.RUNNING
	tool._anchor = from
	tool._update_run(from, to, 0.016)
	var route:= tool._route
	print("  route %s  sig %s" % [route, tool._route_sig])
	_check("a way round is found and it is green", bool(tool._eval ["ok"]) and route.size() > 2)
	if route.size() > 2:
		var last:= (route [route.size() - 1] - route [route.size() - 2]).normalized()
		_check("the last leg arrives along the intake (%.4f)" % last.dot(along),
			last.dot(along) > 0.999)
		_legs_pass(tool, route)
		var runs_before:= builds.conveyors.size()
		tool._active = true
		tool.primary()
		tool._active = false
		_check("no knee cut into it: one run per leg",
			builds.conveyors.size() - runs_before == route.size() - 1)
		_check("and the last run ends on the intake",
			builds.feed_run_into(to) != null)
	tool._state = BuildTool.State.AIMING
	tool._drop_route()

	print("\n=== a click cut at a port knee is one belt too ===")


	var side: HaystackScanner = builds.add_scanner(Vector3(14.0, lift, -8.0), 0.0)
	for i in 4:
		await get_tree().physics_frame
	var mouth:= side.port_in()
	var start:= mouth + Vector3(-3.5, 0.0, 0.0)

	var bill:= float(tool._evaluate(start, mouth, true) ["cost"])
	var count:= builds.conveyors.size()
	tool._lay_run(start, mouth)
	var cut:= builds.conveyors.size() - count
	_check("laid in %d pieces" % cut, cut == 2)
	if cut == 2:
		var p: Conveyor = builds.conveyors [count]
		var q: Conveyor = builds.conveyors [count + 1]
		_check("sharing one belt id (%d, %d)" % [p.line_id, q.line_id],
			p.line_id != 0 and p.line_id == q.line_id)


		_check("the bill covers the knee ($%.2f against $%.2f straight)"
			% [bill, Conveyor.cost_for(start, mouth)], bill > Conveyor.cost_for(start, mouth) + 0.01)
		var refund:= builds.demolish(p)
		_check("taking it up pays back the bill ($%.2f billed, $%.2f back)" % [bill, refund],
			absf(bill - refund) < 0.001)
	count = builds.conveyors.size()
	tool._lay_run(Vector3(-11.0, mouth.y, -15.0), Vector3(-9.0, mouth.y, -15.0))
	_check("a click that lays one run leaves it a belt of its own",
		builds.conveyors.size() == count + 1
			and (builds.conveyors [count] as Conveyor).line_id == 0)


func _terminus_knees(tool: BuildTool, builds: BuildManager) -> void:
	print("\n=== a run aimed across a terminus is cut at a knee ===")
	var cases: Array = [
		["silo intake", builds.add_silo(Vector3(24.0, 0.0, -20.0), 0.0), true],
		["pelletizer", builds.add_pelletizer(Vector3(24.0, 0.0, -8.0), 0.0), true],
		["generator", builds.add_generator(Vector3(24.0, 0.0, 4.0), 0.0), true],
		["launcher", builds.add_tube_launcher(Vector3(24.0, 0.0, 16.0), 0.0), true],
		["stairs outfeed", builds.add_hay_stairs(Vector3(24.0, 0.0, 28.0), 0.0), false],
	]
	for i in 4:
		await get_tree().physics_frame
	for c: Array in cases:
		var label: String = c [0]
		var machine: Node3D = c [1]
		var into: bool = c [2]
		var port: Vector3
		if machine is HaySilo:
			port = (machine as HaySilo).port_in()
		elif machine is HayStairs:
			port = (machine as HayStairs).outfeed_port()
		else:
			port = machine.call("intake_port")
		var bearing:= builds.port_bearing_at(port)
		_check("%s has a bearing %s" % [label, bearing], bearing != Vector3.ZERO)
		if bearing == Vector3.ZERO:
			continue
		var slant:= bearing.rotated(Vector3.UP, PI * 0.25) * 4.0
		var count:= builds.conveyors.size()
		if into:
			tool._lay_run(port - slant, port)
		else:
			tool._lay_run(port, port + slant)
		var cut:= builds.conveyors.size() - count
		_check("%s: laid in %d pieces" % [label, cut], cut == 2)
		if cut != 2:
			continue
		var touching: Conveyor = builds.conveyors [count + 1 if into else count]
		var dot:= touching.forward.dot(bearing)
		_check("%s: the piece on the port lies along it (%.4f, %.2f m)"
			% [label, dot, touching.length], dot > 0.999)


func _timing(tool: BuildTool, builds: BuildManager, lift: float) -> void:
	print("\n=== what a search costs ===")
	await _terminus_knees(tool, builds)
	for i in CLUTTER:
		var y:= 4.0 + float(i) * 0.5
		builds.add_conveyor(Vector3(-15.5, y, -15.5), Vector3(-15.5, y, -13.5))
	for i in 4:
		await get_tree().physics_frame
	var router:= BeltRouter.new(tool)
	var from:= Vector3(-13.5, lift, -12.0)
	var to:= Vector3(-13.5, lift, -7.0)
	await _wall(Vector3(-13.5, 1.0, -9.5), Vector3(1.6, 2.0, 0.3))
	var cases:= [["wall", from, to], ["walled in", Vector3(-14.0, lift, 4.0),
		Vector3(-14.0, lift, 7.5)]]
	for c: Array in cases:
		var a: Vector3 = c [1]
		var b: Vector3 = c [2]
		var reps:= 10
		var t0:= Time.get_ticks_usec()
		var found:= 0
		for r in reps:
			found = router.find(a, b).size()
		var ms:= float(Time.get_ticks_usec() - t0) / 1000.0 / float(reps)
		print("  %-10s %d runs in the yard  %.2f ms a search  %d ways round"
			% [c [0], builds.conveyors.size(), ms, found])


		_check("%s search under 12 ms" % c [0], ms < 12.0)


static func _blocker(tool: BuildTool, from: Vector3, to: Vector3) -> String:
	var r:= tool._evaluate(from, to, true)
	if bool(r ["ok"]):
		return ""
	var hit:= tool._obstruction(from, to, from.distance_to(to)) as Node
	return "  (%s: %s)" % [r ["reason"], hit.get_path() if hit != null else "no body"]


func _legs_pass(tool: BuildTool, route: PackedVector3Array) -> void:
	var bad:= ""
	for i in route.size() - 1:
		var length:= route [i].distance_to(route [i + 1])
		var why: String = tool._leg_shape_reason(route [i], route [i + 1], length)
		if why == "":
			why = tool._leg_clear_reason(route [i], route [i + 1], length)
		if why != "":
			bad += " leg %d: %s" % [i, why]
	_check("every leg would pass laid by hand%s" % bad, bad == "")


static func _crosses(route: PackedVector3Array, at: Vector3, size: Vector3) -> bool:
	var half:= Vector2(size.x, size.z) * 0.5 + Vector2.ONE * Cfg.BELT_WIDTH * 0.4
	for i in route.size() - 1:
		for k in 41:
			var p:= route [i].lerp(route [i + 1], float(k) / 40.0)
			if absf(p.x - at.x) < half.x and absf(p.z - at.z) < half.y:
				return true
	return false


func _box_round(centre: Vector3, r: float) -> void:
	await _wall(Vector3(centre.x - r, 1.0, centre.z), Vector3(0.3, 2.0, r * 2.0 + 0.3))
	await _wall(Vector3(centre.x + r, 1.0, centre.z), Vector3(0.3, 2.0, r * 2.0 + 0.3))
	await _wall(Vector3(centre.x, 1.0, centre.z - r), Vector3(r * 2.0 + 0.3, 2.0, 0.3))
	await _wall(Vector3(centre.x, 1.0, centre.z + r), Vector3(r * 2.0 + 0.3, 2.0, 0.3))


func _wall(at: Vector3, size: Vector3) -> void:
	var wall:= StaticBody3D.new()
	wall.name = "ProbeWall"
	wall.collision_layer = Cfg.L_WORLD
	wall.collision_mask = 0
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = size
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)
	wall.global_position = at
	for i in 2:
		await get_tree().physics_frame


func _check(label: String, good: bool) -> void:
	if not good:
		_fails += 1
	print("  %-4s %s" % ["ok" if good else "BAD", label])
