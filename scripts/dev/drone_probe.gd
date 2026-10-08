class_name DevDroneProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40


const ROUND_FRAMES:= 4000

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	var pad:= Vector3(13.0, 0.02, -6.0)
	player.global_position = Vector3(9.0, 0.4, -2.0)
	GameState.add_money(40000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	print("\n=== model ===")
	var drone: HayDrone = world.builds.add_hay_drone(pad, 0.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	_check("model instantiated", drone.get_node_or_null("Model") != null)
	for part in ["Drone_Body", "Hook", "Cable", "Marker_Grab", "Marker_Cargo",
			"Marker_CableTop", "Rotor_FL", "Rotor_FR", "Rotor_BL", "Rotor_BR"]:
		_check("node %s" % part,
			drone.get_node_or_null("Model") != null
				and drone.get_node("Model").find_child(part, true, false) != null)
	_check("hatch clip found",
		drone._hatch_anim != null and drone._hatch_anim.has_animation(HayDrone.CLIP_HATCH))
	_check("claw clip found",
		drone._claw_anim != null and drone._claw_anim.has_animation(HayDrone.CLIP_CLAW))


	_check("the drone is parked, not running", not drone._mech_busy())


	var players:= drone.get_node("Model").find_children("*", "AnimationPlayer", true, false)
	_check("one AnimationPlayer per mechanism and no others (%d)" % players.size(),
		players.size() == 2 and players.has(drone._hatch_anim)
			and players.has(drone._claw_anim))


	for pair in [[drone._hatch_anim, HayDrone.CLIP_HATCH],
			[drone._claw_anim, HayDrone.CLIP_CLAW]]:
		var ap: AnimationPlayer = pair [0]
		var clip: String = pair [1]
		var strays: Array [String] = []
		if ap != null and ap.has_animation(clip):
			var a:= ap.get_animation(clip)
			for i in a.get_track_count():
				var np:= a.track_get_path(i)
				var leaf: StringName = &"" if np.get_name_count() == 0 else np.get_name(np.get_name_count() - 1)
				if not (HayDrone.CLIP_PARTS [clip] as Array).has(leaf):
					strays.append(String(np))
		_check("%s drives only its own hinges (%s)"
			% [clip, "clean" if strays.is_empty() else ", ".join(strays)],
			strays.is_empty())


	print("\n=== the mechanisms against the winch ===")
	var hook: Node3D = drone.get_node("Model").find_child("Hook", true, false)
	var hatch_l: Node3D = drone.get_node("Model").find_child("Hatch_L", true, false)
	drone._winch_to(1.8, 10.0)
	var paid_out:= hook.position.y
	_check("the winch pays out (%.3f m)" % paid_out, paid_out < -0.5)
	drone._play(HayDrone.CLIP_HATCH, true)
	while drone._mech_busy():
		await get_tree().process_frame
	_check("...and the hatch does not reel it back in (%.3f m)" % hook.position.y,
		absf(hook.position.y - paid_out) < 0.001)
	var hatch_pose:= hatch_l.quaternion
	_check("...the hatch did open", hatch_pose.angle_to(Quaternion.IDENTITY) > 0.1)
	drone._play(HayDrone.CLIP_CLAW, true)
	while drone._mech_busy():
		await get_tree().process_frame
	_check("...nor does the claw (%.3f m)" % hook.position.y,
		absf(hook.position.y - paid_out) < 0.001)


	_check("...and the claw leaves the hatch open",
		hatch_l.quaternion.angle_to(hatch_pose) < 0.01)
	drone._play(HayDrone.CLIP_CLAW, false)
	drone._play(HayDrone.CLIP_HATCH, false)
	while drone._mech_busy():
		await get_tree().process_frame
	drone._winch_to(drone._stow_drop(), 10.0)


	_check("cable head read from the rig (%.3f m)" % drone._cable_top,
		drone._cable_top > 0.3)
	_check("toes hang below the hook (%.3f m)" % drone._grab_local,
		drone._grab_local < 0.0)

	_check("load rides above the toes (%.3f > %.3f)"
		% [drone._cargo_local, drone._grab_local],
		drone._cargo_local > drone._grab_local)
	_check("the pad is a dismantle target",
		world.builds.owner_of(drone.get_node_or_null("Pad")) == drone)
	_check("the aircraft carries no collider of its own",
		drone.get_node("Model").find_children("*", "CollisionObject3D", true, false).is_empty())


	print("\n=== the hologram ===")
	var ghost:= HayDrone.new()
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = pad + Vector3(0, 0, 8.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("the ghost draws its circle", ghost._ring != null)


	var drawn:= 0.0
	if ghost._ring != null and ghost._ring.mesh != null:
		var aabb: AABB = ghost._ring.mesh.get_aabb()
		drawn = maxf(aabb.size.x, aabb.size.z) * 0.5
	_check("...at the radius the drone actually works (%.2f m vs %.2f m)"
		% [drawn, Cfg.DRONE_RADIUS],
		absf(drawn - Cfg.DRONE_RADIUS) < Cfg.DRONE_RING_BAND)
	var solid:= 0
	for n in ghost.find_children("*", "CollisionObject3D", true, false):
		if (n as CollisionObject3D).collision_layer != 0:
			solid += 1
	_check("the ghost is not solid (%d live colliders)" % solid, solid == 0)
	ghost.set_preview_valid(false)
	_check("a refused ghost is painted", ghost._ring_mat != null)
	world.remove_child(ghost)
	ghost.queue_free()


	print("\n=== catalogue and tech ===")
	_check("catalogue entry exists", BuildCatalog.ids().has("drone"))
	_check("...wired to the drone mode",
		BuildCatalog.mode_of("drone") == BuildTool.Mode.HAY_DRONE)
	_check("...is a one-click placement", not BuildCatalog.is_run("drone"))
	_check("...gated behind a tech node", BuildCatalog.unlock_of("drone") != "")
	_check("the tech node exists", TechTree.ids().has("drone"))


	print("\n=== a new drone has no job ===")
	for i in 240:
		await get_tree().process_frame
	_check("a new drone is not set up", not drone.has_job())
	_check("...its sign says so (%s)" % drone.alert_reason(),
		drone.alert_reason().contains("NOT SET UP"))
	_check("...and it stays on its pad", drone._phase == HayDrone.Phase.IDLE)

	var plate_ui: DronePanel = world.drone_panel
	plate_ui.open(drone)
	_check("the plate says nothing under SHOW ZONE before it is pressed",
		not plate_ui._show_why.visible)
	plate_ui._show_btn.pressed.emit()
	_check("SHOW ZONE with no zone says it is not set up (%s)" % plate_ui._show_why.text,
		plate_ui._show_why.visible and plate_ui._show_why.text != "")
	_check("...and the button stays SHOW ZONE (%s)" % plate_ui._show_btn.text,
		plate_ui._show_btn.text == tr("SHOW ZONE"))
	plate_ui.close()


	print("\n=== the rules for a zone and a drop ===")
	var zone:= _zone_on_pile(pad)
	print("  zone on the pile at %v, %.1f m from the pad, hay %.2f m"
		% [zone, _flat(zone, pad), world.field.height_at(zone.x, zone.z)])
	_check("the pile is inside the drone's range", _flat(zone, pad) < drone.radius() - 1.0)
	var far:= pad + Vector3(drone.radius() + 2.0, 0.0, 0.0)
	_check("a zone out of range is refused (%s)" % drone.zone_refusal(far, 2.0),
		drone.set_zone(far, 2.0) == "OUT OF RANGE" and drone.zone_at == Vector3.INF)
	var plate: Vector3 = world.stand.delivery_point()
	_check("a drop on the selling stand is refused (%s)" % drone.drop_refusal(plate),
		drone.set_drop(plate, HayDrone.Drop.FLOOR) != "" and drone.drop_at == Vector3.INF)
	_check("a drop on the pile is refused (%s)" % drone.drop_refusal(zone),
		drone.drop_refusal(zone) != "")
	_check("a zone on the pile is taken", drone.set_zone(zone, 99.0) == "")
	_check("...no bigger than the card allows (%.1f m)" % drone.zone_r,
		is_equal_approx(drone.zone_r, Tech.drone_zone_max()))
	drone.set_zone(zone, 2.5)

	var keep:= [zone, pad]
	var spot:= _belt_spot(pad, 3.0, keep, [drone.zone_r + 2.5, 2.2])
	_check("a clear stretch of floor for the drop belt", not spot.is_empty())
	if spot.is_empty():
		_finish()
		return
	var belt: Conveyor = world.builds.add_conveyor(spot [0] + Vector3.UP * 0.45 - spot [1] * 3.0,
		spot [0] + Vector3.UP * 0.45 + spot [1] * 3.0)
	for i in 20:
		await get_tree().process_frame
	_check("the drop belt is down", belt != null and is_instance_valid(belt))
	var on_belt: Vector3 = belt._point_at(belt.path_length() * 0.5)
	_check("a drop on the belt is taken (%s)" % drone.drop_refusal(on_belt),
		drone.set_drop(on_belt, HayDrone.Drop.BELT) == "")
	_check("...as a belt drop, on the belt",
		drone.drop_kind == HayDrone.Drop.BELT
			and belt._point_at(belt.s_at(drone.drop_at)).distance_to(drone.drop_at) < 0.1)
	_check("the drone has a job", drone.has_job())
	_check("...and a route it can fly (%s)" % drone._route_why, drone._route_why == "")


	print("\n=== the plate's SHOW ZONE button ===")
	plate_ui.open(drone)
	_check("the open plate draws the job", drone.job_shown() and drone._job_marks.visible)
	_check("...and offers to hide it (%s)" % plate_ui._show_btn.text,
		plate_ui._show_btn.text == tr("HIDE ZONE"))
	plate_ui._show_btn.pressed.emit()
	for i in 30:
		await get_tree().process_frame
	_check("HIDE ZONE takes it off the ground with the plate still up",
		not drone.job_shown() and not drone._job_marks.visible)
	_check("...and the button says SHOW ZONE (%s)" % plate_ui._show_btn.text,
		plate_ui._show_btn.text == tr("SHOW ZONE"))
	plate_ui._show_btn.pressed.emit()
	_check("SHOW ZONE puts it back for two minutes (%.0f s)" % drone.job_seconds_left(),
		drone.job_shown() and drone._job_marks.visible and drone.job_seconds_left() > 100.0)
	_check("...with nothing missing under it", not plate_ui._show_why.visible)
	plate_ui.close()
	_check("...and it outlasts the plate", drone.job_shown())
	drone.show_job(false)
	var top:= drone._zone_top()
	print("  legs at %s, zone top %.2f m, drop hover %.2f m, lane gap %.2f m"
		% [str(drone._leg_y), top, drone._drop_hover_y, HayDrone.lane_gap()])
	var lowest:= INF
	for y in drone._leg_y:
		lowest = minf(lowest, y)
	_check("...every leg over the hay with room to spare (lowest %.2f m)" % lowest,
		lowest >= top + HayDrone.PILE_CLEAR - 0.01)


	_check("...and the two legs flown opposite ways fly at different heights where the roof leaves room (%.2f, %.2f, %d lanes)"
		% [drone._leg_y [1], drone._leg_y [2], drone.lanes_used],
		drone.lanes_used < 2 or absf(drone._leg_y [1] - drone._leg_y [2]) > HayDrone.v_sep() * 0.9)


	var pad2:= _pad_spot(pad, [zone, on_belt])
	var other: HayDrone = world.builds.add_hay_drone(pad2, 0.0)
	for i in 10:
		await get_tree().process_frame
	print("  second pad at %v" % pad2)
	_check("a second drone's zone on the first one's is refused (%s)"
		% other.zone_refusal(zone, 2.0), other.zone_refusal(zone, 2.0) == "ANOTHER DRONE WORKS HERE")
	_check("...and its drop on the first one's (%s)" % other.drop_refusal(drone.drop_at),
		other.drop_refusal(drone.drop_at) == "ANOTHER DRONE DROPS HERE")
	_check("...and a zone over the first one's drop (%s)"
		% other.zone_refusal(drone.drop_at, 1.5), other.zone_refusal(drone.drop_at, 1.5) != "")
	_check("a pad inside a drone's zone is refused by the build tool",
		world.builds.drone_overlap(zone, Cfg.DRONE_CLEAR_RADIUS))


	var marks:= HayDrone.taken_marks(other)
	var rings:= 0
	var near_zone:= false
	for mark in marks:
		if mark is MeshInstance3D:
			rings += 1
		elif mark is Label3D and HayDrone._flat(mark.position, zone) < 0.1:
			near_zone = true
	_check("setting up the second drone shows the first one's zone and drop in grey (%d rings)"
		% rings, rings == 2 and near_zone)
	_check("...and none for a drone with no job of its own",
		HayDrone.taken_marks(drone).is_empty())
	for mark in marks:
		mark.free()
	world.builds.demolish(other)
	for i in 10:
		await get_tree().process_frame


	print("\n=== digging ===")


	drone.plan_now()
	var hay0:= GameState.hay_total
	var put0: int = drone.strands_put
	var plans0: int = drone.plans
	var trips0: int = drone.trips
	var three_trips:= func() -> bool: return drone.trips >= trips0 + 3
	var dug:= await _wait_for(three_trips, 14000)
	print("  %d trips in %d frames, %d route plans, zone top %.2f -> %.2f m"
		% [drone.trips - trips0, dug, drone.plans - plans0, top, drone._zone_top()])
	_check("it carried three loads to the belt", drone.trips >= trips0 + 3)
	var held:= 0
	if drone._held != null and is_instance_valid(drone._held) and drone._held is Carryable:
		held = (drone._held as Carryable).hay_strands()
	var removed:= hay0 - GameState.hay_total
	var put: int = drone.strands_put - put0
	_check("the hay off the pile is the hay put down (%.0f off, %d put, %d on the hook)"
		% [removed, put, held], absf(removed - float(put + held)) < 1.0)
	_check("...and it was real hay, not crumbs (%d strands a load)"
		% (put / maxi(1, drone.trips - trips0)), put >= 3 * Cfg.WAD_MIN_STRANDS)
	_check("three trips, one route: no plan after the job was set (%d)"
		% (drone.plans - plans0), drone.plans - plans0 == 0)


	var aboard:= 0
	var nowhere:= 0
	for ri in range(belt.run.first(), belt.run.first() + belt.run.count()):
		aboard += 1
		if not is_finite(belt.run.s_of(ri)) or not is_finite(belt.run.side_of(ri)):
			nowhere += 1
	_check("...every load on the belt stands at a real place on it (%d of %d not)"
		% [nowhere, aboard], nowhere == 0)
	var strays:= 0
	for item: Carryable in world.props.items:
		if is_instance_valid(item) and item is HayWad and not BeltPath.is_rider(item) and not item.is_held() and _flat(item.global_position, on_belt) < 3.0 and item.global_position.y < 0.3:
			strays += 1
	_check("...and nothing it dropped missed the belt (%d on the floor)" % strays, strays == 0)
	world.builds.changed.emit()
	var plans1: int = drone.plans
	var planned_again:= func() -> bool: return drone.plans > plans1
	await _wait_for(planned_again, 6000)
	for i in 120:
		await get_tree().process_frame
	_check("something built marks the route stale, and it is planned again once (%d)"
		% (drone.plans - plans1), drone.plans - plans1 == 1)


	print("\n=== a needle in the bite ===")
	var buried:= _free_needle()
	if buried < 0:
		_check("a buried needle to test with", false)
	else:
		var bite:= drone._highest_in_zone()
		GameState.needle_positions [buried] = bite + Vector3(0.0, -0.1, 0.0)
		var loose_before: int = world.live.needles.size()
		var bitten:= drone._dig_bite(bite) as Carryable
		_check("the bite came up as a load", bitten != null)
		_check("...with the needle inside it (%d)" % (bitten.needle_index if bitten != null else -1),
			bitten != null and bitten.needle_index == buried)
		_check("...out of the ground", GameState.needle_taken [buried] == 1)
		_check("...and never a loose needle (%d loose before, %d after)"
			% [loose_before, world.live.needles.size()],
			world.live.needles.size() == loose_before and _needle_body(buried) == null)
		if bitten != null:
			bitten.global_position = pad + Vector3(0.0, 0.6, 1.8)

	print("\n=== a needle lying loose in the zone ===")
	var lying:= _free_needle()
	if lying < 0:
		_check("a second needle to test with", false)
	else:
		var at:= zone + Vector3(0.6, 0.0, 0.0)
		at.y = world.field.height_at(at.x, at.z) + 0.05
		GameState.needle_taken [lying] = 1
		var body: RigidBody3D = world.live.reveal_needle(lying, at)
		for i in 60:
			await get_tree().physics_frame
		_check("a loose needle lies in the zone",
			body != null and is_instance_valid(body) and drone._in_zone(body.global_position))
		var taken:= func() -> bool: return not is_instance_valid(body) or drone._held == body
		var gone:= await _wait_for(taken, 9000)
		_check("...and the drone took it (%d frames)" % gone,
			not is_instance_valid(body) or drone._held == body)


	print("\n=== the Drone Pickup card ===")
	var fresh:= HayDrone.new()
	_check("a new drone's job is DIG", fresh.mode == HayDrone.Mode.DIG)
	fresh.free()
	var needs: Array = TechTree.spec("drone_collect").get("requires", [])
	_check("COLLECT is its own card, after the drone and the compressor (%s)" % [needs],
		needs.has("drone") and needs.has("compressor"))
	_check("the drone card itself no longer needs the compressor",
		not (TechTree.spec("drone").get("requires", []) as Array).has("compressor"))
	var had:= Tech.rank_of("drone_collect")
	Tech.grant("drone_collect", 0)
	_check("without the card COLLECT is locked", not Tech.drone_collect_unlocked())
	Tech.grant("drone_collect", 1)
	_check("with it COLLECT is offered", Tech.drone_collect_unlocked())
	Tech.grant("drone_collect", had)


	print("\n=== collecting ===")
	var empty_hook:= func() -> bool: return drone._held == null
	await _wait_for(empty_hook, 6000)


	var bay: Vector3 = world.props.truck.bay_point() if world.props.truck != null else Vector3(999, 0, 999)
	var floor_zone:= _floor_zone(pad, 2.0, [zone, on_belt, bay],
		[drone.zone_r + 3.0, 4.0, Cfg.DELIVERY_STOCK_R + 3.0], drone)
	print("  collect zone on the floor at %v" % floor_zone)
	drone.set_mode(HayDrone.Mode.COLLECT)
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		drone.set_accepting(int(kind ["bit"]), false)
	drone.set_accepting(RoboticArm.PICK_BALE, true)
	_check("a zone on the floor is taken (%s)" % drone.zone_refusal(floor_zone, 2.0),
		floor_zone != Vector3.INF and drone.set_zone(floor_zone, 2.0) == "")
	_check("...and the route still flies (%s)" % drone._route_why, drone._route_why == "")
	var bales: Array [Carryable] = []
	var bricks: Array [Carryable] = []
	for k in 2:
		bales.append(world.props.spawn("hay_bale", Transform3D(Basis.IDENTITY,
			floor_zone + Vector3(0.9 * float(k) - 0.4, 0.6, 0.6)),
			{ "strands": Cfg.COMPRESSOR_BALE_STRANDS }))
		bricks.append(world.props.spawn("eco_brick", Transform3D(Basis.IDENTITY,
			floor_zone + Vector3(0.9 * float(k) - 0.4, 0.4, -0.7)), { }))
	var bales_out:= func() -> bool: return _outside(bales, floor_zone, drone.zone_r)
	var carried_bales:= await _wait_for(bales_out, 12000)
	_check("both bales left the zone (%d frames)" % carried_bales, bales_out.call())
	_check("...and the bricks, which were not ticked, stayed (%d)"
		% _inside_count(bricks, floor_zone, drone.zone_r),
		_inside_count(bricks, floor_zone, drone.zone_r) == 2)
	drone.set_accepting(RoboticArm.PICK_BRICK, true)
	var bricks_out:= func() -> bool: return _outside(bricks, floor_zone, drone.zone_r)
	var carried_bricks:= await _wait_for(bricks_out, 12000)
	_check("ticked, the bricks went too (%d frames)" % carried_bricks, bricks_out.call())

	print("\n=== a clawful of tufts ===")
	await _wait_for(empty_hook, 6000)
	drone.set_accepting(RoboticArm.PICK_LOOSE, true)
	var tufts: Array [Carryable] = []
	for k in 3:
		tufts.append(world.props.spawn("hay_tuft", Transform3D(Basis.IDENTITY,
			floor_zone + Vector3(0.25 * float(k), 0.3, 0.0)), { "strands": 15 }))
	var tuft_put: int = drone.strands_put
	var tuft_trips: int = drone.trips
	var tufts_out:= func() -> bool: return _outside(tufts, floor_zone, drone.zone_r)
	var cleared:= await _wait_for(tufts_out, 12000)
	await _wait_for(empty_hook, 6000)
	_check("three tufts left the zone (%d frames)" % cleared, tufts_out.call())
	_check("...in one trip, as one load of all three (%d trips, %d strands)"
		% [drone.trips - tuft_trips, drone.strands_put - tuft_put],
		drone.trips - tuft_trips == 1 and drone.strands_put - tuft_put == 45)


	print("\n=== a full drop ===")
	var full_keep:= [floor_zone, on_belt, pad, bay]
	var full_at:= _drop_spot(pad, full_keep,
		[drone.zone_r + 2.5, 4.0, 2.5, Cfg.DELIVERY_STOCK_R + 2.0], drone)
	_check("a patch of floor for a full drop", full_at != Vector3.INF)
	if full_at != Vector3.INF:
		_check("...taken as the drop (%s)" % drone.drop_refusal(full_at),
			drone.set_drop(full_at, HayDrone.Drop.FLOOR) == "")
		var lid: Platform = world.builds.add_platform(full_at + Vector3.UP * 1.4, Vector2(4.0, 4.0))
		world.builds.changed.emit()
		for k in 2:
			world.props.spawn("hay_bale", Transform3D(Basis.IDENTITY,
				floor_zone + Vector3(0.9 * float(k) - 0.45, 0.6, 0.0)),
				{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
		var full:= func() -> bool: return drone._phase == HayDrone.Phase.DELIVER and drone._wait.contains("full")
		var waiting:= await _wait_for(full, 12000)
		_check("with the drop full it waits over it (%d frames, %s)" % [waiting, drone._wait],
			full.call())
		var releases_full: int = drone._releases
		for i in 300:
			await get_tree().process_frame
		_check("...and does not let go while it waits",
			drone._releases == releases_full and drone._held != null)
		_check("...and its plate says it is waiting (%s)" % str(drone.plate_status() [1]),
			int(drone.plate_status() [0]) == HayDrone.PLATE_WAITING)
		var trips_full: int = drone.trips
		world.builds.demolish(lid)
		var went_down:= func() -> bool: return drone.trips > trips_full
		var cleared_at:= await _wait_for(went_down, 6000)
		_check("the deck taken away, it puts the load down (%d frames)" % cleared_at,
			drone.trips > trips_full)
		var put_where:= INF
		for item: Carryable in world.props.items:
			if is_instance_valid(item) and item is HayBale and not item.is_held():
				put_where = minf(put_where, _flat(item.global_position, full_at))
		_check("...on its drop (%.2f m from it)" % put_where,
			put_where <= HayDrone.FLOOR_SPREAD * 2.0 + 0.5)

	print("\n=== a drop taken down ===")
	var short_keep:= [floor_zone, on_belt, pad]
	var short_spot:= _belt_spot(pad, 1.2, short_keep, [drone.zone_r + 2.0, 3.8, 2.2])
	_check("a clear bit of floor for a short belt", not short_spot.is_empty())
	var short: Conveyor = null
	if not short_spot.is_empty():
		short = world.builds.add_conveyor(short_spot [0] + Vector3.UP * 0.45 - short_spot [1] * 1.1,
			short_spot [0] + Vector3.UP * 0.45 + short_spot [1] * 1.1)
		for i in 20:
			await get_tree().process_frame
		var short_mid: Vector3 = short._point_at(short.path_length() * 0.5)
		_check("the short belt as the drop (%s)" % drone.drop_refusal(short_mid),
			drone.set_drop(short_mid, HayDrone.Drop.BELT) == "")
		for i in 60:
			await get_tree().process_frame
		world.builds.demolish(short)
		var gone_sign:= func() -> bool: return drone._phase == HayDrone.Phase.IDLE and drone.alert_reason().contains("DROP IS GONE")
		var noticed:= await _wait_for(gone_sign, 9000)
		_check("its belt taken down, it lets go, lands and says why (%d frames, %s)"
			% [noticed, drone.alert_reason()], gone_sign.call())
		_check("...with nothing left on its hook", drone._held == null)
		var broken:= _non_finite()
		_check("nothing in the yard stands at a position that is not a number (%s)"
			% ", ".join(broken), broken.is_empty())


	print("\n=== a load taken off the hook ===")
	drone.set_drop(on_belt, HayDrone.Drop.BELT)
	for item: Carryable in world.props.items.duplicate():
		if is_instance_valid(item) and drone._in_zone(item.global_position) and not item.is_held():
			world.props.remove(item)
	var loot_bale: Carryable = world.props.spawn("hay_bale",
		Transform3D(Basis.IDENTITY, floor_zone + Vector3(0.0, 0.6, 0.0)),
		{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
	var got_loot:= func() -> bool: return drone._held == loot_bale
	await _wait_for(got_loot, 9000)
	_check("the drone picked the bale up", drone._held == loot_bale)
	var trips_before: int = drone.trips
	var released_before: int = drone._releases
	var thief:= player.global_position + Vector3(0.0, 1.2, 0.0)
	var gave_up:= false
	var steal_frames:= 0
	while steal_frames < 4000 and not gave_up:
		await get_tree().physics_frame
		steal_frames += 1
		if is_instance_valid(loot_bale):
			loot_bale.global_position = thief
		gave_up = drone._held == null
	_check("the drone noticed the load had gone (%d frames)" % steal_frames, gave_up)
	_check("...by giving it up, not delivering it (%d releases, %d trips)"
		% [drone._releases - released_before, drone.trips - trips_before],
		drone._releases == released_before and drone.trips == trips_before)
	_check("...and the bale is still solid and still held",
		is_instance_valid(loot_bale) and (loot_bale.collision_layer & Cfg.L_PROP) != 0
			and loot_bale.is_held())
	if is_instance_valid(loot_bale):
		loot_bale.release(Vector3.ZERO)
		world.props.remove(loot_bale)


	print("\n=== dismantled with a load on the hook ===")
	var bale2: Carryable = world.props.spawn("hay_bale",
		Transform3D(Basis.IDENTITY, floor_zone + Vector3(0.5, 0.6, 0.0)),
		{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
	var got_bale2:= func() -> bool: return drone._held == bale2
	await _wait_for(got_bale2, 9000)
	_check("the drone picked the second bale up", drone._held == bale2)
	if drone._held == bale2:
		world.builds.demolish(drone)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame


		_check("...and dropping the drone let the bale go",
			is_instance_valid(bale2) and not bale2.freeze)
		_check("...leaving no claim on it",
			not bale2.has_meta(HayDrone.META_CLAIM))


	print("\n=== save and reload ===")
	for d in world.builds.hay_drones.duplicate():
		world.builds.demolish(d)
	var drone3: HayDrone = world.builds.add_hay_drone(pad, 0.7)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	drone3.set_mode(HayDrone.Mode.COLLECT)
	drone3.set_accepting(RoboticArm.PICK_BRICK, false)
	var z_ok:= drone3.set_zone(floor_zone, 1.5)
	var d_ok:= drone3.set_drop(on_belt, HayDrone.Drop.BELT)
	_check("a job to save (%s, %s)" % [z_ok, d_ok], z_ok == "" and d_ok == "")
	var saved_drop:= drone3.drop_at
	var saved: Array = world.builds.to_array()
	var drone_rows:= 0
	for row: Dictionary in saved:
		if row.get("type", "") == "hay_drone":
			drone_rows += 1
	_check("the drone is written to the save (%d rows)" % drone_rows, drone_rows == 1)
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("...and comes back as exactly one drone",
		world.builds.hay_drones.size() == 1)
	var back: HayDrone = world.builds.hay_drones [0] if world.builds.hay_drones.size() > 0 else null
	_check("...on the same pad",
		back != null and back.global_position.distance_to(pad) < 0.02)
	_check("...standing on it, not hovering",
		back != null and back.get_node("Model").position.length() < 0.02)
	_check("...still knows the pile, the belts and the loose hay",
		back != null and back.field != null and back.builds != null and back.live != null)
	_check("...with its job: collecting, the same zone and the same drop",
		back != null and back.mode == HayDrone.Mode.COLLECT
			and back.zone_at.distance_to(floor_zone) < 0.01 and is_equal_approx(back.zone_r, 1.5)
			and back.drop_kind == HayDrone.Drop.BELT and back.drop_at.distance_to(saved_drop) < 0.01)
	_check("...and the same ticks (bales yes, bricks no)",
		back != null and back.accepts(RoboticArm.PICK_BALE) and not back.accepts(RoboticArm.PICK_BRICK))


	print("\n=== launching on a browned-out network ===")
	if back != null:
		back.set_power(0.55)
		var slow_bale: Carryable = world.props.spawn("hay_bale",
			Transform3D(Basis.IDENTITY, floor_zone + Vector3(0.3, 0.6, 0.0)),
			{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
		var off_pad:= func() -> bool: return back._phase != HayDrone.Phase.IDLE and back._phase != HayDrone.Phase.LAUNCH
		var slow:= await _wait_for(off_pad, 6000)
		_check("at 55%% power the drone still leaves the pad (%d frames)" % slow, off_pad.call())
		back.set_power(1.0)
		if is_instance_valid(slow_bale):
			slow_bale.queue_free()


		print("\n=== power cut in the air ===")
		var landed:= func() -> bool:
			return back._phase == HayDrone.Phase.IDLE and back.get_node("Model").position.length() < 0.02
		await _wait_for(landed, 9000)
		var cut_bale: Carryable = world.props.spawn("hay_bale",
			Transform3D(Basis.IDENTITY, floor_zone + Vector3(0.3, 0.6, 0.0)),
			{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
		var hooked:= func() -> bool: return back._held == cut_bale and back._phase == HayDrone.Phase.CLIMB
		await _wait_for(hooked, 9000)
		_check("the drone is climbing away with a bale", back._held == cut_bale)
		var cut_trips: int = back.trips
		back.set_power(0.0)
		var home:= await _wait_for(landed, 9000)
		_check("with the power cut it still took the load to the drop (%d trips)"
			% (back.trips - cut_trips), back.trips == cut_trips + 1)
		_check("...then landed on its pad (%d frames)" % home, landed.call())
		_check("...with nothing on its hook", back._held == null)
		var start_trips: int = back.trips
		for i in 120:
			await get_tree().process_frame
		_check("...and it stays there while the pad is dead",
			back._phase == HayDrone.Phase.IDLE and back.trips == start_trips)

		back.set_power(1.0)
		var out_bale: Carryable = world.props.spawn("hay_bale",
			Transform3D(Basis.IDENTITY, floor_zone + Vector3(-0.3, 0.6, 0.0)),
			{ "strands": Cfg.COMPRESSOR_BALE_STRANDS })
		var outbound:= func() -> bool: return back._phase == HayDrone.Phase.TO_PICK
		await _wait_for(outbound, 9000)
		_check("the drone is on its way out to a bale", back._phase == HayDrone.Phase.TO_PICK)
		back.set_switched_off(true)
		var back_home:= await _wait_for(landed, 9000)
		_check("switched off on the way out, it turned back and landed (%d frames)" % back_home,
			landed.call() and back._held == null)
		_check("...leaving the bale unclaimed for later",
			is_instance_valid(out_bale) and not out_bale.has_meta(HayDrone.META_CLAIM))
		back.set_switched_off(false)
		for b in [cut_bale, out_bale]:
			if is_instance_valid(b):
				world.props.remove(b)


		var ports: Array [Node3D] = back.power_ports()
		var port_ok:= ports.size() == 1
		if port_ok:
			var local:= back.to_local(ports [0].global_position)
			var out:= Vector2(local.x, local.z).length()
			print("  charging post: %.2f m out, %.2f m up" % [out, local.y])
			port_ok = out > 1.25 and local.y > 1.1
		_check("the wire ties on beside the pad, clear of the parked aircraft", port_ok)


	print("\n=== two drones, one set of materials ===")
	if back != null:
		var twin: HayDrone = world.builds.add_hay_drone(pad, 0.0)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		var shared:= HayCompressor.materials_shared()
		var same:= "the same" if shared else "their own"
		back.power_ports()
		twin.power_ports()
		back.show_range(true)
		twin.show_range(true)
		_check("two drones' aircraft wear %s materials" % same,
			_wear_alike(back.get_node("Model"), twin.get_node("Model"), shared))
		_check("...and so do their pads and posts",
			_wear_alike(back.get_node("Pad"), twin.get_node("Pad"), shared))
		_check("...and their reach rings",
			back._ring_mat != null and (back._ring_mat == twin._ring_mat) == shared)
		_check("...and their charger lamps",
			(back._charge_lamp.material_override == twin._charge_lamp.material_override) == shared)
		var ghost2:= HayDrone.new()
		ghost2.placement_preview = true
		world.add_child(ghost2)
		ghost2.set_preview_valid(false)
		_check("a hologram's ring is its own, so its tint paints no placed ring",
			ghost2._ring_mat != back._ring_mat and back._ring_mat.albedo_color == HayDrone.COL_REACH)
		world.remove_child(ghost2)
		ghost2.queue_free()
		back.set_power(1.0)
		twin.set_switched_off(true)
		print("  lamps: fed %.2f %s, switched off %.2f %s"
			% [back.lamp_energy(), back.lamp_colour(), twin.lamp_energy(), twin.lamp_colour()])
		_check("the fed drone's lamp is lit on its own post",
			absf(back.lamp_energy() - 1.4) < 0.01
			and back.lamp_colour().is_equal_approx(HayDrone.LAMP_LIT))
		_check("...and not on its switched off twin's",
			absf(twin.lamp_energy() - 0.05) < 0.01
			and twin.lamp_colour().is_equal_approx(HayDrone.LAMP_DARK))
		twin.set_switched_off(false)
		twin.set_power(0.5)
		_check("...which follows its own line (%.3f)" % twin.lamp_energy(),
			absf(twin.lamp_energy() - 0.725) < 0.01 and absf(back.lamp_energy() - 1.4) < 0.01)

	_finish()


func _wear_alike(a: Node, b: Node, shared: bool) -> bool:
	var mine:= HayDrone._meshes(a)
	var theirs:= HayDrone._meshes(b)
	if mine.size() != theirs.size() or mine.is_empty():
		return false
	var seen:= 0
	for k in mine.size():
		var ma: MeshInstance3D = mine [k]
		var mb: MeshInstance3D = theirs [k]
		if ma.mesh == null or mb.mesh == null:
			continue
		for s in ma.mesh.get_surface_count():
			var x:= ma.get_active_material(s)
			if x == null:
				continue
			seen += 1
			if (x == mb.get_active_material(s)) != shared:
				return false
	return seen > 0


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _finish() -> void:
	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _wait_for(cond: Callable, limit: int) -> int:
	var n:= 0
	while n < limit and not cond.call():
		await get_tree().process_frame
		n += 1
	return n


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _zone_on_pile(pad: Vector3) -> Vector3:
	var to_top:= Vector3(- pad.x, 0.0, - pad.z).normalized()
	var p:= pad
	for i in 200:
		p += to_top * 0.25
		if world.field.height_at(p.x, p.z) > 1.2:
			var z:= p + to_top * 1.5
			return Vector3(z.x, 0.0, z.z)
	return Vector3(p.x, 0.0, p.z)


func _belt_spot(near: Vector3, half: float, keep: Array, keep_r: Array) -> Array:
	for ring: float in [3.5, 4.5, 5.5, 7.0, 8.5]:
		for k in 24:
			var a:= TAU * float(k) / 24.0
			var c:= near + Vector3(cos(a), 0.0, sin(a)) * ring
			c.y = 0.0
			for dir: Vector3 in [Vector3(- sin(a), 0.0, cos(a)), Vector3(cos(a), 0.0, sin(a))]:
				if _line_clear(c - dir * (half + 0.4), c + dir * (half + 0.4), keep, keep_r):
					return [c, dir]
	return []


func _line_clear(a: Vector3, b: Vector3, keep: Array, keep_r: Array) -> bool:

	var inner: float = (world.get("warehouse") as Warehouse).inner - 1.2
	for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var p:= a.lerp(b, t)
		if absf(p.x) > inner or absf(p.z) > inner:
			return false
		if world.field.height_at(p.x, p.z) > 0.02:
			return false
		for i in keep.size():
			if _flat(p, keep [i]) < float(keep_r [i]):
				return false
	var box:= BoxShape3D.new()
	box.size = Vector3(1.2, 1.4, a.distance_to(b) + 0.4)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	q.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5 + Vector3.UP * 0.85)
	return world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _floor_zone(near: Vector3, r: float, keep: Array, keep_r: Array, drone: HayDrone) -> Vector3:
	for ring: float in [5.0, 6.0, 7.0, 8.0, 9.5]:
		for k in 24:
			var a:= TAU * float(k) / 24.0
			var c:= near + Vector3(cos(a), 0.0, sin(a)) * ring
			c.y = 0.0
			var ok:= true
			for i in keep.size():
				if _flat(c, keep [i]) < float(keep_r [i]):
					ok = false
			if not ok or drone.zone_refusal(c, r) != "":
				continue
			var d:= Vector3(r, 0.0, 0.0)
			if not _line_clear(c - d, c + d, [], []) or not _line_clear(c - Vector3(0.0, 0.0, r), c + Vector3(0.0, 0.0, r), [], []):
				continue
			return c
	return Vector3.INF


func _drop_spot(near: Vector3, keep: Array, keep_r: Array, drone: HayDrone) -> Vector3:
	for ring: float in [3.0, 4.0, 5.0, 6.0, 7.5, 9.0]:
		for k in 24:
			var a:= TAU * float(k) / 24.0
			var c:= near + Vector3(cos(a), 0.0, sin(a)) * ring
			c.y = 0.0
			var ok:= true
			for i in keep.size():
				if _flat(c, keep [i]) < float(keep_r [i]):
					ok = false
			if not ok or drone.drop_refusal(c) != "":
				continue
			if not _line_clear(c - Vector3(2.0, 0, 0), c + Vector3(2.0, 0, 0), [], []) or not _line_clear(c - Vector3(0, 0, 2.0), c + Vector3(0, 0, 2.0), [], []):
				continue
			return c
	return Vector3.INF


func _pad_spot(near: Vector3, keep: Array) -> Vector3:
	for ring: float in [4.0, 5.0, 6.0, 7.5]:
		for k in 24:
			var a:= TAU * float(k) / 24.0
			var c:= near + Vector3(cos(a), 0.0, sin(a)) * ring
			c.y = near.y
			var far_enough:= true
			for p: Vector3 in keep:
				if _flat(c, p) < 5.0:
					far_enough = false
			if far_enough and _line_clear(c - Vector3(0.8, 0, 0), c + Vector3(0.8, 0, 0), [], []):
				return c
	return near + Vector3(0.0, 0.0, 6.0)


func _free_needle() -> int:
	for i in GameState.needle_taken.size():
		if GameState.needle_taken [i] == 0:
			return i
	return -1


func _needle_body(idx: int) -> RigidBody3D:
	for b: RigidBody3D in world.live.needles:
		if is_instance_valid(b) and int(b.get_meta("needle_index", -1)) == idx:
			return b
	return null


static func _outside(items: Array [Carryable], at: Vector3, r: float) -> bool:
	return _inside_count(items, at, r) == 0


static func _inside_count(items: Array [Carryable], at: Vector3, r: float) -> int:
	var n:= 0
	for item in items:
		if is_instance_valid(item) and item.is_inside_tree() and _flat(item.global_position, at) <= r + 0.1:
			n += 1
	return n


func _non_finite() -> PackedStringArray:
	var out:= PackedStringArray()
	var stack: Array [Node] = [world]
	while not stack.is_empty() and out.size() < 8:
		var n: Node = stack.pop_back()
		var n3:= n as Node3D
		if n3 != null and n3.is_inside_tree() and not n3.global_transform.origin.is_finite():
			out.append("%s (%s)" % [str(n3.get_path()).get_slice("/", 3) + "/" + n3.name, n3.get_class()])
		for kid in n.get_children():
			stack.append(kid)
	return out
