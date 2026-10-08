class_name DevSplitterProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const FED:= 40


const CARRY_SECONDS:= 25.6 / Cfg.BELT_SPEED


const OUT_RUN:= 3.0

const WALL_MARGIN:= 1.0

var _rng:= RandomNumberGenerator.new()
var _pass:= 0
var _fail:= 0

var _caught:= [0, 0]


var _arrived:= [0, 0]


var _caught_hay:= [0, 0]
var _arrived_hay:= [0, 0]


var _route_of: Dictionary = { }
var _strayed:= 0
var _agreed:= 0


static func belt_secs(metres: float) -> float:
	return metres / maxf(Cfg.BELT_SPEED, 0.01)


func run() -> void:
	_rng.seed = 20260823
	for i in 40:
		await get_tree().process_frame


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var feed_a:= Vector3(-13.0, deck_y, -8.0)
	var feed_b:= Vector3(-13.0, deck_y, -2.0)
	player.global_position = Vector3(-10.5, 0.4, 0.0)
	GameState.add_money(5000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	print("\n=== model ===")
	var splitter: ConveyorSplitter = world.builds.add_splitter(
		feed_b + Vector3(0, 0, Cfg.SPLITTER_PORT_R), 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var body:= splitter.get_node_or_null("Body") as MeshInstance3D
	var gate:= splitter.get_node_or_null("Gate") as MeshInstance3D
	_check("wye mesh instantiated", body != null and body.mesh != null)
	_check("blade mesh instantiated", gate != null and gate.mesh != null)


	if body != null and body.mesh != null:
		_check("wye has 3 surfaces (rubber, frame, roller), got %d"
			% body.mesh.get_surface_count(), body.mesh.get_surface_count() == 3)
	if gate != null and gate.mesh != null:
		_check("blade has 2 surfaces (rubber, frame), got %d"
			% gate.mesh.get_surface_count(), gate.mesh.get_surface_count() == 2)


	var readout:= splitter.get_node_or_null("Readout") as MeshInstance3D
	_check("readout mesh instantiated", readout != null and readout.mesh != null)
	if readout != null and readout.mesh != null:
		_check("readout has 3 surfaces (frame, screen, roller), got %d"
			% readout.mesh.get_surface_count(),
			readout.mesh.get_surface_count() == 3)


	var screen:= readout.get_node_or_null("Screen") as MeshInstance3D if readout != null else null
	_check("the pane is stood over the glass", screen != null
		and screen.material_override is ShaderMaterial)


	if screen != null and readout != null and readout.mesh != null:


		var glass_z:= INF
		for i in readout.mesh.get_surface_count():
			if readout.mesh.surface_get_material(i) != ConveyorKit.screen_material():
				continue
			var verts: PackedVector3Array = readout.mesh.surface_get_arrays(i) [Mesh.ARRAY_VERTEX]
			for v in verts:
				glass_z = minf(glass_z, v.z)
		var proud:= glass_z - screen.position.z
		_check("the pane sits %.2f mm proud of the glass" % (proud * 1000.0),
			glass_z < INF and proud > 0.0002 and proud < 0.004)
		_check("...and faces upstream, at the player",
			(screen.global_basis.z.normalized()).dot(splitter.forward()) < -0.99)


	var caption: Label3D = null
	if readout != null:
		caption = readout.get_node_or_null("Caption") as Label3D
	_check("the glass carries the setting in words", caption != null)
	if caption != null:


		var was_next:= splitter.next_side
		for want in [ConveyorSplitter.SET_MAIN_LEFT, ConveyorSplitter.SET_PIN_RIGHT,
				ConveyorSplitter.SET_TURN]:
			if want == ConveyorSplitter.SET_MAIN_LEFT:
				splitter.set_priority_side(ConveyorSplitter.LEFT)
			elif want == ConveyorSplitter.SET_PIN_RIGHT:
				splitter.set_forced_side(ConveyorSplitter.RIGHT)
			else:
				splitter.set_forced_side(-1)
				splitter.set_priority_side(-1)
			_check("...it reads '%s' on %s" % [caption.text, want],
				caption.text == ConveyorSplitter.SET_NAMES [want]
					and caption.text == splitter.setting_name())
		splitter.set_forced_side(-1)
		splitter.set_priority_side(-1)
		splitter.next_side = was_next

	_check("blade stands on the nose apex (%.3f vs %.3f)"
		% [gate.position.z if gate != null else -1.0, Cfg.SPLITTER_GATE_PIVOT],
		gate != null and absf(gate.position.z - Cfg.SPLITTER_GATE_PIVOT) < 0.001)


	var open:= 0
	for side in ConveyorSplitter.SIDES:
		var route:= splitter._routes.get(side) as BeltPath
		_check("route %d laid" % side, route != null)
		if route != null and route._catching:
			open += 1
	_check("exactly one route open, got %d" % open, open == 1)


	for side in ConveyorSplitter.SIDES:
		var route:= splitter._routes.get(side) as BeltPath
		if route == null:
			continue
		var line: PackedVector3Array = route._line
		var want:= splitter.port(side)
		var tail:= line [line.size() - 1] if line.size() > 0 else Vector3.ZERO
		_check("route %d: %d points, ends %.3f m from its own mouth"
			% [side, line.size(), tail.distance_to(want)],
			line.size() == 3
				and line [0].is_equal_approx(splitter.port_in())
				and line [1].is_equal_approx(splitter.global_position)
				and tail.is_equal_approx(want))

	print("\n=== scroll direction ===")


	var reference:= _scroll_gradient(ConveyorKit.segment_mesh(), Vector3.ZERO,
		Vector3.BACK)
	print("  the belt section reads dV/d(travel) = %+.2f -- that is the convention"
		% reference)
	_check("the reference section has a scroll direction at all (%+.2f)" % reference,
		absf(reference) > 0.9)
	for lane in [["infeed", Vector3(0.0, 0.0, -0.75), Vector3(0.0, 0.0, 1.0)],
			["left arm", ConveyorSplitter._arm_local(1.0) * 0.72,
				ConveyorSplitter._arm_local(1.0).normalized()],
			["right arm", ConveyorSplitter._arm_local(-1.0) * 0.72,
				ConveyorSplitter._arm_local(-1.0).normalized()]]:
		var g:= _scroll_gradient(ConveyorKit.splitter_mesh(), lane [1], lane [2])
		_check("%s scrolls with the load, not against it (dV/d(travel) = %+.2f)"
			% [lane [0], g], absf(g) > 0.9 and signf(g) == signf(reference))

	print("\n=== geometry ===")
	for pair in [["infeed", splitter.port_in()], ["left", splitter.port_left()],
			["right", splitter.port_right()]]:
		var label: String = pair [0]
		var mouth: Vector3 = pair [1]
		var r:= splitter.global_position.distance_to(mouth)
		_check("%s mouth %.3f m out (want %.2f)" % [label, r, Cfg.SPLITTER_PORT_R],
			absf(r - Cfg.SPLITTER_PORT_R) < 0.01)


		_check("...on the deck plane (%.3f vs %.3f)" % [mouth.y, deck_y],
			absf(mouth.y - deck_y) < 0.02)


	_check("travel is +Z as placed", splitter.forward().dot(Vector3.BACK) > 0.99)


	var to_left:= (splitter.port_left() - splitter.global_position).normalized()
	var splay:= to_left.angle_to(splitter.forward())
	_check("arms splay %.1f deg (want %.1f)"
		% [rad_to_deg(splay), rad_to_deg(Cfg.SPLITTER_SPLAY)],
		absf(splay - Cfg.SPLITTER_SPLAY) < 0.01)


	_check("left mouth is on the load's left (+X)",
		splitter.port_left().x > splitter.global_position.x)

	print("\n=== snapping ===")
	for pair in [["infeed", splitter.port_in()], ["left", splitter.port_left()],
			["right", splitter.port_right()]]:
		var label: String = pair [0]
		var mouth: Vector3 = pair [1]
		var near: Vector3 = mouth + Vector3(0.3, 0.0, 0.35)
		var snapped: Vector3 = world.builds.snap_endpoint(near)
		_check("belt end snaps to the %s mouth (off by %.3f m)"
			% [label, snapped.distance_to(mouth)], snapped.is_equal_approx(mouth))
	var far:= splitter.global_position + Vector3(6.0, 0.0, 0.0)
	_check("a belt end well clear is left alone",
		world.builds.snap_endpoint(far).is_equal_approx(far))
	_check("a second splitter on the same spot is refused",
		world.builds.splitter_overlap(splitter.global_position))


	var low:= Vector3(30.0, 0.8, 0.0)
	var high:= Vector3(30.0, 2.8, 8.0)
	var climb: Conveyor = world.builds.add_conveyor(low, high)
	var offered: Dictionary = world.builds.nearest_wye_joint(high + Vector3(0.2, 0.0, 0.2),
		Cfg.SPLITTER_SNAP_RADIUS)
	_check("a climbing run's end is offered to a wye", not offered.is_empty()
		and (offered ["point"] as Vector3).is_equal_approx(high))
	if not offered.is_empty():
		var along: Vector3 = offered ["forward"]
		_check("the offered direction is level (y %.3f)" % along.y, absf(along.y) < 1e-05)
		var centre:= high + along * Cfg.SPLITTER_PORT_R
		var infeed:= centre + Basis(Vector3.UP, atan2(along.x, along.z)) * Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R)
		_check("a splitter snapped there has its infeed on the run end (off by %.3f m)"
			% infeed.distance_to(high), infeed.distance_to(high) < 0.001)
	world.builds.demolish(climb)

	print("\n=== transport and division ===")


	var in_belt: Conveyor = world.builds.add_conveyor(feed_a, splitter.port_in())
	var left_dir:= (splitter.port_left() - splitter.global_position).normalized()
	var right_dir:= (splitter.port_right() - splitter.global_position).normalized()
	var left_end:= splitter.port_left() + left_dir * OUT_RUN
	var right_end:= splitter.port_right() + right_dir * OUT_RUN
	for pair in [["left", left_end], ["right", right_end]]:
		var end: Vector3 = pair [1]
		var room:= Warehouse.INNER - WALL_MARGIN
		_check("the %s outfeed run stays inside the shed (%.2f, %.2f)"
			% [pair [0], end.x, end.z],
			absf(end.x) < room and absf(end.z) < room)
	var out_belt:= {
		ConveyorSplitter.LEFT: world.builds.add_conveyor(splitter.port_left(), left_end),
		ConveyorSplitter.RIGHT: world.builds.add_conveyor(splitter.port_right(), right_end),
	}


	for pair in [["infeed", splitter.port_in()], ["left", splitter.port_left()],
			["right", splitter.port_right()]]:
		var mouth: Vector3 = pair [1]
		var near: Vector3 = mouth + Vector3(0.3, 0.0, 0.35)
		_check("a %s mouth with a belt on it does not pull the aim" % pair [0],
			not world.builds.snap_endpoint(near).is_equal_approx(mouth))
	_check("...but moving that belt's own end still finds its mouth",
		world.builds.snap_endpoint(splitter.port_left() + Vector3(0.3, 0.0, 0.35),
			out_belt [ConveyorSplitter.LEFT]).is_equal_approx(splitter.port_left()))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	for side in ConveyorSplitter.SIDES:
		var route:= splitter._routes.get(side) as BeltPath
		if route != null:
			route.caught.connect(func(b: RigidBody3D) -> void:
				_caught [side] += 1
				_caught_hay [side] += (b as HayWad).strands if b is HayWad else 1
				_route_of [_key(route, b)] = side)
			route.caught_record.connect(func(seq: int, _kind: int, strands: int) -> void:
				_caught [side] += 1
				_caught_hay [side] += strands
				_route_of [seq] = side)
		var belt:= out_belt [side] as Conveyor
		if belt != null:
			belt.caught.connect(func(b: RigidBody3D) -> void:
				_arrived [side] += 1
				_arrived_hay [side] += (b as HayWad).strands if b is HayWad else 1
				_arrived_from(_route_of.get(b.get_instance_id(), -1), side))
			belt.caught_record.connect(func(seq: int, _kind: int, strands: int) -> void:
				_arrived [side] += 1
				_arrived_hay [side] += strands
				_arrived_from(_route_of.get(seq, -1), side))

	var fed: Array [RigidBody3D] = []
	for i in FED:
		var at:= feed_a + Vector3(_rng.randf_range(-0.2, 0.2), 0.22,
			_rng.randf_range(0.0, 1.6))
		var strand: RigidBody3D = world.live.spawn(at,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if strand != null:
			fed.append(strand)


	var blade_wrong:= 0
	var streak:= 0
	var blade_samples:= 0
	var ticks:= int(CARRY_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
		if not is_instance_valid(splitter) or gate == null:
			continue
		var want: int = splitter._imminent_side()


		var angle: float = splitter._gate_angle
		var aimed_left: bool = angle > 0.0


		if absf(absf(angle) - Cfg.SPLITTER_GATE_SWING) >= 0.02:
			streak = 0
			continue
		blade_samples += 1
		if aimed_left == (want == ConveyorSplitter.LEFT):
			streak = 0
			continue
		streak += 1
		blade_wrong = maxi(blade_wrong, streak)


	var alive:= 0
	for strand in fed:
		if is_instance_valid(strand) and strand.is_inside_tree():
			alive += 1

	print("  fed %d, still loose in the world afterwards %d" % [fed.size(), alive])
	print("  the module TOOK ON %d left, %d right"
		% [_caught [ConveyorSplitter.LEFT], _caught [ConveyorSplitter.RIGHT]])
	print("  the arms RECEIVED %d left, %d right"
		% [_arrived [ConveyorSplitter.LEFT], _arrived [ConveyorSplitter.RIGHT]])

	var took: int = _caught_hay [ConveyorSplitter.LEFT] + _caught_hay [ConveyorSplitter.RIGHT]
	var got: int = _arrived_hay [ConveyorSplitter.LEFT] + _arrived_hay [ConveyorSplitter.RIGHT]


	_check("the module took on most of the feed (%d of %d)" % [took, fed.size()],
		took >= int(fed.size() * 0.7))


	_check("everything it took on came out of an arm (%d in, %d out)" % [took, got],
		got >= took - 1)


	var lean:= absi(_caught_hay [ConveyorSplitter.LEFT] - _caught_hay [ConveyorSplitter.RIGHT])


	var least: int = mini(_caught_hay [ConveyorSplitter.LEFT], _caught_hay [ConveyorSplitter.RIGHT])
	_check("it kept both arms working (%d / %d, lean %d, least %d of %d)"
		% [_caught_hay [ConveyorSplitter.LEFT], _caught_hay [ConveyorSplitter.RIGHT],
			lean, least, took],
		least >= int(took * 0.2))
	_check("and both arms received (%d / %d)"
		% [_arrived [ConveyorSplitter.LEFT], _arrived [ConveyorSplitter.RIGHT]],
		mini(_arrived [ConveyorSplitter.LEFT], _arrived [ConveyorSplitter.RIGHT]) > 0)


	_check("every load came out of the arm it was put on (%d kept, %d strayed)"
		% [_agreed, _strayed], _strayed == 0 and _agreed > 0)


	_check("the blade never sat facing the wrong arm (longest run %d ticks, %d samples, limit %d)"
		% [blade_wrong, blade_samples, FactoryClock.stride + 1],
		blade_wrong <= FactoryClock.stride + 1)


	var quiet_left: int = _caught [ConveyorSplitter.LEFT]
	var quiet_right: int = _caught [ConveyorSplitter.RIGHT]
	for i in 12:
		var at:= feed_a + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.0)
		world.live.spawn(at, StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
			Cfg.COL_HAY_LIGHT)

		for k in int(1.0 / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
	for i in int(4.0 / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	var quiet_l: int = _caught [ConveyorSplitter.LEFT] - quiet_left
	var quiet_r: int = _caught [ConveyorSplitter.RIGHT] - quiet_right
	_check("fed one at a time, it divides them exactly (%d / %d)" % [quiet_l, quiet_r],
		quiet_l + quiet_r >= 8 and absi(quiet_l - quiet_r) <= 1)

	print("\n=== pinned to one arm ===")


	splitter.set_forced_side(ConveyorSplitter.RIGHT)
	var pin_left: int = _caught [ConveyorSplitter.LEFT]
	var pin_right: int = _caught [ConveyorSplitter.RIGHT]
	for i in 8:
		world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.0),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		for k in int(1.0 / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
	for i in int(3.0 / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	var pinned_l: int = _caught [ConveyorSplitter.LEFT] - pin_left
	var pinned_r: int = _caught [ConveyorSplitter.RIGHT] - pin_right
	_check("pinned right, every load went right (%d right, %d left)"
		% [pinned_r, pinned_l], pinned_r >= 6 and pinned_l == 0)


	_check("...and the blade sits across the shut arm (%.3f rad)"
		% (gate.rotation.y if gate != null else 0.0),
		gate != null and gate.rotation.y < - Cfg.SPLITTER_GATE_SWING + 0.02)
	splitter.set_forced_side(-1)
	var back_left: int = _caught [ConveyorSplitter.LEFT]
	var back_right: int = _caught [ConveyorSplitter.RIGHT]
	for i in 6:
		world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.0),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		for k in int(1.0 / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
	for i in int(3.0 / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	var undone_l: int = _caught [ConveyorSplitter.LEFT] - back_left
	var undone_r: int = _caught [ConveyorSplitter.RIGHT] - back_right


	_check("unpinned, it divides them again (%d / %d)" % [undone_l, undone_r],
		undone_l + undone_r >= 4 and absi(undone_l - undone_r) <= 1)

	print("\n=== one arm first, the other on overflow ===")


	var ov_left:= out_belt [ConveyorSplitter.LEFT] as Conveyor
	var ov_right:= out_belt [ConveyorSplitter.RIGHT] as Conveyor
	var ov_paths: Array = [in_belt, splitter.route(ConveyorSplitter.LEFT),
		splitter.route(ConveyorSplitter.RIGHT), ov_left, ov_right]

	splitter.set_priority_side(ConveyorSplitter.LEFT)
	_check("the machine says which setting it is on (%s)" % splitter.setting(),
		splitter.setting() == ConveyorSplitter.SET_MAIN_LEFT)


	_check("...and the prompt reads: sends %s" % splitter.mode_label(),
		splitter.mode_label() == "left side first, right when it backs up")


	var ov_main: int = _caught [ConveyorSplitter.LEFT]
	var ov_spill: int = _caught [ConveyorSplitter.RIGHT]
	await _feed_line(feed_a, 8)
	var clear_main: int = _caught [ConveyorSplitter.LEFT] - ov_main
	var clear_spill: int = _caught [ConveyorSplitter.RIGHT] - ov_spill
	_check("with the main arm clear, every load went down it (%d main, %d spill)"
		% [clear_main, clear_spill], clear_main >= 6 and clear_spill == 0)


	ov_left.set_blocked(true)
	ov_main = _caught [ConveyorSplitter.LEFT]
	ov_spill = _caught [ConveyorSplitter.RIGHT]
	await _feed_line(feed_a, 18, 0.35, 2.0)


	var filled: bool = await _drain([in_belt], 40.0)
	_check("the line in front cleared while the main arm filled", filled)
	print("  filling the blocked main arm took %d loads, %d had to spill"
		% [_caught [ConveyorSplitter.LEFT] - ov_main,
			_caught [ConveyorSplitter.RIGHT] - ov_spill])
	ov_main = _caught [ConveyorSplitter.LEFT]
	ov_spill = _caught [ConveyorSplitter.RIGHT]
	await _feed_line(feed_a, 6)
	var jam_main: int = _caught [ConveyorSplitter.LEFT] - ov_main
	var jam_spill: int = _caught [ConveyorSplitter.RIGHT] - ov_spill
	_check("with the main arm backed up, every load went to the spill (%d spill, %d main)"
		% [jam_spill, jam_main], jam_spill >= 5 and jam_main == 0)


	ov_left.set_blocked(false)
	var cleared: bool = await _drain(ov_paths, 60.0)
	_check("the blocked arm drained before the next case", cleared)
	ov_main = _caught [ConveyorSplitter.LEFT]
	ov_spill = _caught [ConveyorSplitter.RIGHT]
	await _feed_line(feed_a, 4)
	var back_main: int = _caught [ConveyorSplitter.LEFT] - ov_main
	var back_spill: int = _caught [ConveyorSplitter.RIGHT] - ov_spill
	_check("unblocked, the next loads went back down the main arm (%d main, %d spill)"
		% [back_main, back_spill], back_main >= 3 and back_spill == 0)


	ov_left.set_blocked(true)
	ov_right.set_blocked(true)


	for i in 26:
		world.live.spawn(feed_a + Vector3(_rng.randf_range(-0.2, 0.2), 0.22,
			_rng.randf_range(0.0, 1.6)), StrandFactory.random_strand_basis(_rng),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	for i in int(belt_secs(12.8) / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame


	var clear_deck:= feed_a + Vector3(0.0, 0.0, 2.5)
	ov_main = _caught [ConveyorSplitter.LEFT]
	ov_spill = _caught [ConveyorSplitter.RIGHT]
	await _feed_line(clear_deck, 12, 0.5)
	var still_taking: int = _caught [ConveyorSplitter.LEFT] - ov_main + _caught [ConveyorSplitter.RIGHT] - ov_spill
	var queued: int = _aboard(in_belt)
	var loose_on_run:= 0
	var loose_at_module:= 0
	for child in world.live.get_children():
		var rb:= child as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var p:= rb.global_position
		if absf(p.x + 13.0) < 1.2 and p.z > -8.6 and p.z < -2.2:
			loose_on_run += 1
		if p.distance_to(splitter.global_position) < 2.2:
			loose_at_module += 1
	print("  with both arms blocked: %d aboard the run in front, %d and %d on the arms, %d and %d on the outfeeds"
		% [queued, _aboard(splitter.route(ConveyorSplitter.LEFT)),
			_aboard(splitter.route(ConveyorSplitter.RIGHT)),
			_aboard(ov_left), _aboard(ov_right)])
	_check("with both arms backed up it takes nothing more on (%d)" % still_taking,
		still_taking == 0)


	_check("...and it has no route open at all (%d)" % splitter._open_side(),
		splitter._open_side() == -1)


	print("  the hay it would not take: %d round the module, %d loose along the run in front, %d aboard it, %d live in the yard"
		% [loose_at_module, loose_on_run, queued, world.live.get_child_count()])
	_check("...and the run in front of it fills instead (%d aboard)" % queued,
		queued >= 6)
	ov_left.set_blocked(false)
	ov_right.set_blocked(false)
	splitter.set_priority_side(-1)
	_check("clearing the main arm leaves the machine taking turns again (%s)"
		% splitter.setting(), splitter.setting() == ConveyorSplitter.SET_TURN)


	var emptied: bool = await _drain(ov_paths, 90.0)
	_check("the yard drained before the panel case", emptied)


	var swept:= await _swept_clear(splitter.global_position, 2.2, 4, 40.0)
	_check("...and the heap at the mouth was swept out (%d still round it)" % swept,
		swept <= 4)

	print("\n=== the panel ===")


	var panel: SplitterPanel = world.splitter_panel
	_check("the panel exists", panel != null)
	if panel != null:


		Tech.grant("overflow_gate", 0)
		splitter.set_forced_side(ConveyorSplitter.LEFT)
		panel.open(splitter)
		await get_tree().process_frame
		_check("the gate card is not there until the node is bought",
			not panel._gate_panel.visible)
		Tech.grant("overflow_gate", 1)
		panel.open(splitter)
		await get_tree().process_frame


		_check("...and it is there once the node is bought",
			panel._gate_panel.visible)


		_check("the machine wears the box once the node is bought",
			readout != null and readout.visible)


		for id: String in panel._buttons:
			_check("the %s button and the glass agree on its name ('%s')"
				% [id, (panel._buttons [id] as Button).text],
				(panel._buttons [id] as Button).text
					== ConveyorSplitter.SET_NAMES [id])
		_check("opening it leaves the machine's setting alone (%d)"
			% splitter.forced_side, splitter.forced_side == ConveyorSplitter.LEFT)
		_check("...and it lights the arm the machine is pinned to",
			(panel._buttons [ConveyorSplitter.SET_PIN_LEFT] as Button).button_pressed
				and not (panel._buttons [ConveyorSplitter.SET_TURN] as Button).button_pressed)
		(panel._buttons [ConveyorSplitter.SET_PIN_RIGHT] as Button).emit_signal("pressed")
		_check("clicking the other arm pins the machine to it (%d)"
			% splitter.forced_side, splitter.forced_side == ConveyorSplitter.RIGHT)


		(panel._buttons [ConveyorSplitter.SET_MAIN_LEFT] as Button).emit_signal("pressed")
		_check("clicking LEFT FIRST makes that arm the main line (%d)"
			% splitter.priority_side,
			splitter.priority_side == ConveyorSplitter.LEFT)
		_check("...and clears the pin it was on (%d)" % splitter.forced_side,
			splitter.forced_side == -1)
		_check("...and lights LEFT FIRST rather than LEFT ARM",
			(panel._buttons [ConveyorSplitter.SET_MAIN_LEFT] as Button).button_pressed
				and not (panel._buttons [ConveyorSplitter.SET_PIN_LEFT] as Button).button_pressed)


		(panel._buttons [ConveyorSplitter.SET_MAIN_LEFT] as Button).emit_signal("pressed")
		_check("clicking LEFT FIRST again turns the gate off (%s)"
			% splitter.setting(), splitter.priority_side == -1
				and splitter.setting() == ConveyorSplitter.SET_TURN)
		(panel._buttons [ConveyorSplitter.SET_MAIN_LEFT] as Button).emit_signal("pressed")
		(panel._buttons [ConveyorSplitter.SET_PIN_RIGHT] as Button).emit_signal("pressed")
		_check("...and pinning back over it clears the main arm (%d)"
			% splitter.priority_side, splitter.priority_side == -1
				and splitter.forced_side == ConveyorSplitter.RIGHT)
		(panel._buttons [ConveyorSplitter.SET_TURN] as Button).emit_signal("pressed")
		_check("clicking TURN ABOUT clears both (%d pinned, %d main)"
			% [splitter.forced_side, splitter.priority_side],
			splitter.forced_side == -1 and splitter.priority_side == -1)
		panel.close()
		_check("...and it closes", not panel.is_open())

	print("\n=== wads divide too ===")


	var wads_by:= [0, 0]
	for side in ConveyorSplitter.SIDES:
		var route:= splitter.route(side)
		if route != null:
			route.caught.connect(func(b: RigidBody3D) -> void:
				if b.collision_layer & Cfg.L_PROP:
					wads_by [side] += 1)
			route.caught_record.connect(func(_seq: int, kind: int, _strands: int) -> void:
				if kind == BeltRun.Kind.WAD:
					wads_by [side] += 1)
	for i in 6:
		world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
			feed_a + Vector3(0.0, 0.35, 0.0)))


		for k in int(belt_secs(2.24) / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
	for i in int(belt_secs(6.4) / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	var wads_took: int = wads_by [ConveyorSplitter.LEFT] + wads_by [ConveyorSplitter.RIGHT]
	print("  the module took %d wads aboard: %d left, %d right"
		% [wads_took, wads_by [ConveyorSplitter.LEFT], wads_by [ConveyorSplitter.RIGHT]])
	_check("it takes wads aboard at all (%d of 6)" % wads_took, wads_took >= 4)
	_check("...and sends them one each way (%d / %d)"
		% [wads_by [ConveyorSplitter.LEFT], wads_by [ConveyorSplitter.RIGHT]],
		mini(wads_by [ConveyorSplitter.LEFT], wads_by [ConveyorSplitter.RIGHT]) >= 2)


	print("\n=== a main line fed a packed line of wads ===")
	await _drain([in_belt, splitter.route(ConveyorSplitter.LEFT),
		splitter.route(ConveyorSplitter.RIGHT)], 40.0)
	splitter.set_priority_side(ConveyorSplitter.LEFT)
	var pk_main: int = wads_by [ConveyorSplitter.LEFT]
	var pk_spill: int = wads_by [ConveyorSplitter.RIGHT]
	var pk_step:= maxf(get_physics_process_delta_time(), 1e-06)
	var pk_ticks:= 0
	var pk_stalled:= 0
	var pk_shut:= 0
	for i in 12:
		world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
			feed_a + Vector3(0.0, 0.35, 0.0)))
		for k in int(0.8 / pk_step):
			await get_tree().physics_frame
			pk_ticks += 1
			if splitter._stalled(ConveyorSplitter.LEFT):
				pk_stalled += 1
			if splitter._open_side() != ConveyorSplitter.LEFT:
				pk_shut += 1
	for i in int(belt_secs(8.0) / pk_step):
		await get_tree().physics_frame
	var pk_l: int = wads_by [ConveyorSplitter.LEFT] - pk_main
	var pk_r: int = wads_by [ConveyorSplitter.RIGHT] - pk_spill
	print("  12 wads 0.8 s apart on LEFT FIRST: %d main, %d spill; main arm read stalled %d of %d ticks, shut %d"
		% [pk_l, pk_r, pk_stalled, pk_ticks, pk_shut])
	_check("a main arm keeping up with a packed line takes every wad (%d main, %d spill)"
		% [pk_l, pk_r], pk_l >= 11 and pk_r == 0)
	splitter.set_priority_side(-1)


	await _drain([in_belt, splitter.route(ConveyorSplitter.LEFT),
		splitter.route(ConveyorSplitter.RIGHT), out_belt [ConveyorSplitter.LEFT],
		out_belt [ConveyorSplitter.RIGHT]], 60.0)


	var carried_seq:= [-1]
	var note_seq:= func(b: RigidBody3D) -> void:
		if b is HayWad and carried_seq [0] < 0:
			carried_seq [0] = in_belt.run.last_seq
	in_belt.caught.connect(note_seq)
	world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY, feed_a + Vector3(0.0, 0.35, 0.0)))
	for i in int(belt_secs(2.56) / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
	in_belt.caught.disconnect(note_seq)
	var where: Dictionary = BeltPath.record_where(carried_seq [0]) if carried_seq [0] >= 0 else { }
	_check("a wad set down on a belt is taken aboard (seq %d)" % carried_seq [0],
		not where.is_empty())
	var carried: Carryable = null
	if not where.is_empty():
		carried = (where ["path"] as BeltPath).materialize_record(int(where ["row"]))
	_check("...and the probe's hand gets a body back off the run", carried != null)
	if carried != null:


		carried.pick_up()
		var away:= feed_a + Vector3(3.0, 1.0, 3.0)
		carried.global_position = away
		carried.release(Vector3.ZERO)
		for i in 30:
			await get_tree().physics_frame
		var drift:= Vector2(carried.global_position.x - away.x,
			carried.global_position.z - away.z).length()
		_check("...and once picked up and thrown clear it stays clear (%.2f m)"
			% drift, drift < 1.0)

	print("\n=== a blocked arm ===")


	var blocked:= out_belt [ConveyorSplitter.LEFT] as Conveyor
	blocked.set_blocked(true)
	var before_right: int = _caught [ConveyorSplitter.RIGHT]
	var before_left: int = _caught [ConveyorSplitter.LEFT]
	for i in FED:
		var at:= feed_a + Vector3(_rng.randf_range(-0.2, 0.2), 0.22,
			_rng.randf_range(0.0, 1.6))
		world.live.spawn(at, StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
			Cfg.COL_HAY_LIGHT)
	var jam_ticks:= int(belt_secs(12.8) / maxf(get_physics_process_delta_time(), 1e-06))
	var crowded:= 0
	for i in jam_ticks:
		await get_tree().physics_frame


		var left_route:= splitter.route(ConveyorSplitter.LEFT)
		var right_route:= splitter.route(ConveyorSplitter.RIGHT)
		if left_route == null or right_route == null:
			continue

		var on_right:= right_route.load_marks()
		for a in left_route.load_marks():
			for b in on_right:
				if (a ["pos"] as Vector3).distance_to(b ["pos"] as Vector3) < Cfg.STRAND_THICK * 2.0:
					crowded += 1
					if crowded <= 4:
						var local: Vector3 = splitter.to_local(a ["pos"] as Vector3)
						print("    a %s over a %s at x=%+.2f z=%+.2f (s %.2f and %.2f)"
							% [_mark_name(a), _mark_name(b), local.x, local.z,
								float(a ["s"]), float(b ["s"])])
	var went_right: int = _caught [ConveyorSplitter.RIGHT] - before_right
	var went_left: int = _caught [ConveyorSplitter.LEFT] - before_left
	_check("the open arm kept running with the other one blocked (%d right)"
		% went_right, went_right >= 10)


	_check("...and the blocked one took only what filled it (%d left, %d right)"
		% [went_left, went_right],
		went_left <= 14 and went_right > went_left)


	_check("...with no load left written on top of another (%d)" % crowded,
		crowded <= 2)
	blocked.set_blocked(false)

	print("\n=== wads against a full splitter ===")


	for side in ConveyorSplitter.SIDES:
		(out_belt [side] as Conveyor).set_blocked(true)
	var full_wads: Array [RigidBody3D] = []


	var full_seqs: Array [int] = []
	var note_full:= func(b: RigidBody3D) -> void:
		if b is HayWad:
			full_seqs.append(in_belt.run.last_seq)
	in_belt.caught.connect(note_full)
	for i in 6:
		var wad:= world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
			feed_a + Vector3(0.0, 0.35, 0.0))) as RigidBody3D
		if wad != null:
			full_wads.append(wad)
		for k in int(belt_secs(1.4) / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
	var fallen_worst:= 0
	var watch:= int(belt_secs(9.0) / maxf(get_physics_process_delta_time(), 1e-06))
	for i in watch:
		await get_tree().physics_frame
		if i % 12 != 0:
			continue
		var fallen:= 0
		for w in full_wads:
			if is_instance_valid(w) and w.is_inside_tree() and w.global_position.y < splitter.global_position.y - 0.3:
				fallen += 1
		fallen_worst = maxi(fallen_worst, fallen)
	in_belt.caught.disconnect(note_full)
	var riding:= 0
	for w in full_wads:
		if is_instance_valid(w) and w.is_inside_tree() and BeltPath.is_rider(w):
			riding += 1
	for seq in full_seqs:
		if not BeltPath.record_where(seq).is_empty():
			riding += 1
	print("  %d wads fed at a splitter with both arms shut: %d carried, %d aboard the run in front, %d and %d on the arms"
		% [full_wads.size(), riding, _aboard(in_belt),
			_aboard(splitter.route(ConveyorSplitter.LEFT)),
			_aboard(splitter.route(ConveyorSplitter.RIGHT))])
	_check("no wad leaves the belt at a splitter that is full (%d on the floor)"
		% fallen_worst, fallen_worst == 0)
	_check("...every one of them is still being carried (%d of %d)"
		% [riding, full_wads.size()], riding == full_wads.size())
	_check("...and the run in front holds a queue of them (%d aboard)"
		% _aboard(in_belt), in_belt.has_load_waiting())
	for side in ConveyorSplitter.SIDES:
		(out_belt [side] as Conveyor).set_blocked(false)


	var fallen_release:= 0
	var loose_longest:= 0
	var loose_streak:= { }
	for i in int(belt_secs(10.0) / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
		if i % 12 != 0:
			continue


		for w in _wad_bodies():
			if not is_instance_valid(w) or not w.is_inside_tree():
				continue
			var id:= w.get_instance_id()
			var near:= w.global_position.distance_to(splitter.global_position) < 2.5
			if near and w.global_position.y < splitter.global_position.y - 0.3:
				fallen_release += 1
			if near and not BeltPath.is_rider(w):
				loose_streak [id] = int(loose_streak.get(id, 0)) + 1
				loose_longest = maxi(loose_longest, int(loose_streak [id]))
			else:
				loose_streak [id] = 0
	_check("...and when the arms open the queue releases without a wad falling (%d)"
		% fallen_release, fallen_release == 0)
	_check("...or riding the module loose (longest %d samples)" % loose_longest,
		loose_longest <= 2)


	await _drain(ov_paths, 60.0)
	for w in full_wads:
		if is_instance_valid(w) and w.is_inside_tree():
			world.props.remove(w as Carryable)

	print("\n=== save ===")


	splitter.set_forced_side(ConveyorSplitter.LEFT)
	var before: int = splitter.next_side
	var data: Array = world.builds.to_array()
	var found:= { }
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_splitter":
			found = entry
	_check("the splitter is written to the save", not found.is_empty())
	_check("...with the arm it owes the next load (%d)" % before,
		int(found.get("next_side", -1)) == before)
	_check("...and with the arm the player pinned it to (%d)"
		% int(found.get("forced_side", -99)),
		int(found.get("forced_side", -99)) == ConveyorSplitter.LEFT)
	world.builds.from_array(data)


	var restored: int = world.builds.splitters [0].next_side if world.builds.splitters.size() == 1 else -1
	var restored_pin: int = world.builds.splitters [0].forced_side if world.builds.splitters.size() == 1 else -99
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("...and comes back as exactly one splitter",
		world.builds.splitters.size() == 1)
	if world.builds.splitters.size() == 1:
		var reloaded: ConveyorSplitter = world.builds.splitters [0]
		_check("...still owing the same arm", restored == before)


		_check("...and still pinned to the same arm (%d)" % restored_pin,
			restored_pin == ConveyorSplitter.LEFT)
		var reopened:= 0
		var laid:= 0
		for side in ConveyorSplitter.SIDES:
			var route:= reloaded._routes.get(side) as BeltPath
			if route == null:
				continue
			laid += 1
			if route._catching:
				reopened += 1


		_check("...with both routes laid again (%d)" % laid, laid == 2)
		_check("...and never more than one of them catching, got %d" % reopened,
			reopened <= 1)


		reloaded.set_priority_side(ConveyorSplitter.RIGHT)
		var main_data: Array = world.builds.to_array()
		var main_entry:= { }
		for entry in main_data:
			if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_splitter":
				main_entry = entry
		_check("the main arm is written to the save (%d)"
			% int(main_entry.get("priority_side", -99)),
			int(main_entry.get("priority_side", -99)) == ConveyorSplitter.RIGHT)


		_check("...and the pin it cleared is written as cleared (%d)"
			% int(main_entry.get("forced_side", -99)),
			int(main_entry.get("forced_side", -99)) == -1)
		world.builds.from_array(main_data)
		var came_back: int = world.builds.splitters [0].priority_side if world.builds.splitters.size() == 1 else -99
		var came_back_pin: int = world.builds.splitters [0].forced_side if world.builds.splitters.size() == 1 else -99
		_check("...and it comes back on the same arm (%d)" % came_back,
			came_back == ConveyorSplitter.RIGHT and came_back_pin == -1)


		var old_save: Array = main_data.duplicate(true)
		for entry in old_save:
			if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_splitter":
				(entry as Dictionary).erase("priority_side")
		world.builds.from_array(old_save)
		var old_pri: int = world.builds.splitters [0].priority_side if world.builds.splitters.size() == 1 else -99
		_check("a save with no such key loads as no main arm (%d)" % old_pri,
			old_pri == -1)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("SPLITTER PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)


func _feed_line(at: Vector3, count: int, gap: float = 1.0,
		tail: float = -1.0) -> void:


	var wait_for:= tail if tail >= 0.0 else belt_secs(8.0)
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	for i in count:
		world.live.spawn(at + Vector3(_rng.randf_range(-0.15, 0.15), 0.22, 0.0),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		for k in int(gap / step):
			await get_tree().physics_frame
	for i in int(wait_for / step):
		await get_tree().physics_frame


func _drain(paths: Array, limit: float) -> bool:
	var ticks:= int(belt_secs(limit) / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
		var busy:= false
		for entry in paths:
			var path:= entry as BeltPath
			if path != null and _aboard(path) > 0:
				busy = true
				break
		if not busy:
			return true
	return false


static func _aboard(path: BeltPath) -> int:
	return path.riders().size() + path.run.count() if path != null else 0


static func _key(path: BeltPath, b: RigidBody3D) -> int:
	if path.records_props and BeltPath.record_kind(b) >= 0:
		return path.run.last_seq
	return b.get_instance_id()


func _arrived_from(put_on: int, side: int) -> void:
	if put_on < 0:
		return
	if put_on == side:
		_agreed += 1
	else:
		_strayed += 1


static func _mark_name(m: Dictionary) -> String:
	if m ["body"] == null:
		return "record seq %d" % int(m ["seq"])
	if m ["body"] is HayTuft:
		return "tuft"
	return (m ["body"] as Object).get_class()


func _wad_bodies() -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []
	for item in world.props.items:
		if item is HayWad and is_instance_valid(item):
			out.append(item as RigidBody3D)
	return out


func _swept_clear(centre: Vector3, radius: float, want: int,
		limit: float) -> int:
	var left:= 0
	var ticks:= int(belt_secs(limit) / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
		if i % 12 != 0:
			continue
		left = 0
		for child in world.live.get_children():
			var rb:= child as RigidBody3D
			if rb != null and rb.is_inside_tree() and rb.global_position.distance_to(centre) < radius:
				left += 1
		if left <= want:
			return left
	return left


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


static func _scroll_gradient(mesh: ArrayMesh, sample: Vector3, travel: Vector3,
		rubber: Material = null) -> float:
	if mesh == null:
		return 0.0
	var belt: Material = rubber if rubber != null else ConveyorKit.belt_material()
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) != belt:
			continue
		var arr:= mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arr [Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arr [Mesh.ARRAY_TEX_UV]
		var normals: PackedVector3Array = arr [Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr [Mesh.ARRAY_INDEX]
		var best:= INF
		var out:= 0.0
		var t:= 0
		while t + 2 < idx.size():
			var a:= idx [t]
			var b:= idx [t + 1]
			var c:= idx [t + 2]
			t += 3

			if normals [a].y < 0.99 or absf(verts [a].y) > 0.001:
				continue
			var centre:= (verts [a] + verts [b] + verts [c]) / 3.0
			var d:= Vector2(centre.x - sample.x, centre.z - sample.z).length()
			if d >= best:
				continue

			var e1:= verts [b] - verts [a]
			var e2:= verts [c] - verts [a]
			var det:= e1.x * e2.z - e2.x * e1.z
			if absf(det) < 1e-09:
				continue
			var c1:= uvs [b].y - uvs [a].y
			var c2:= uvs [c].y - uvs [a].y
			var gx:= (c1 * e2.z - c2 * e1.z) / det
			var gz:= (e1.x * c2 - e2.x * c1) / det
			best = d
			out = gx * travel.x + gz * travel.z
		if best < INF:
			return out
	return 0.0
