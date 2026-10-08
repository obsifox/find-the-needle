class_name DevTSplitterProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40

const CENTRE:= Vector3(-14.0, 0.0, 6.0)


const OPEN_FLOOR:= Vector3(-12.5, 0.0, 6.0)
const OPEN_YAW:= - PI * 0.5
const FEED_RUN:= 4.5
const OUT_RUN:= 3.0

const DRAIN_LIMIT:= 40.0

var _pass:= 0
var _fail:= 0


var _route_side:= { }
var _out_side:= { }

var _why:= { }

var _route_speed_max:= 0.0

var _out_frames_at: Array [int] = []


var _fed: Array [RigidBody3D] = []
var _fed_ids: Array [int] = []
var _every_prop: Array [RigidBody3D] = []
var _strands:= { }
var _seq_of:= { }
var _strands_by_seq:= { }


var _changed:= 0


var _swung_through:= 0


var _closed_ahead:= 0


var _parked_ticks:= 0
var _arm_ticks:= 0


const LIMBO_RUN:= 6
var _limbo_ticks:= 0
var _limbo_run:= 0
var _unassigned:= 0
var _hold_frames:= 0


var _lane_overlap_frames:= 0
var _lane_overlap_worst:= 0.0


var _drawn_ahead:= { }
var _snap_frames:= 0
var _snap_worst:= 0.0

var _out_frames:= 0


static func belt_secs(metres: float) -> float:
	return metres / maxf(Cfg.BELT_SPEED, 0.01)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	player.global_position = CENTRE + Vector3(4.0, 0.4, 6.0)
	GameState.add_money(50000.0)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame


	var only:= ""
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--tsplitter")
	if at >= 0 and at + 1 < args.size() and not args [at + 1].begins_with("--"):
		only = args [at + 1]

	if "--no-share-lane" in args:
		ConveyorTSplitter.share_lane_enabled = false


	if "--old-arm" in args:
		ConveyorTSplitter.old_arm = true


	var port_at:= args.find("--t-port")
	ConveyorTSplitter.placed_port_r = float(args [port_at + 1]) if port_at >= 0 and port_at + 1 < args.size() else Cfg.T_SPLITTER_PORT_R
	print("T placed with its mouths %.2f out" % ConveyorTSplitter.placed_port_r)


	player.build._make_t_splitter_ghost()


	Cfg.settings_readonly = true
	if only == "hover":
		await _hover_preview()
		_finish()
		return
	if only == "attach":
		await _attaching()
		_finish()
		return
	if only == "pastpark":
		await _both_arms_past_park()
		_finish()
		return
	if only == "merge":
		await _both_arms_past_park()
		for rank in [0, 9]:
			Tech.grant("belt_speed", rank)
			print("\n##### belt motor rank %d, %.2f m/s" % [rank, Tech.belt_speed()])
			await _merging()
		Tech.grant("belt_speed", 0)
		_finish()
		return
	if only == "place":
		await _placement()
		_finish()
		return
	if only == "pin":
		await _settings_in_flight()
		_finish()
		return
	if only == "lone":
		await _one_arm_connected()
		_finish()
		return
	if only == "rate":
		await _rate()
		_finish()
		return
	if only == "cost":
		await _cost()
		_finish()
		return
	if only == "straight":
		await _straight_first_chain()
		await _pinned_after_fold()
		_finish()
		return
	if only == "blocked":
		await _blocked_arms()
		_finish()
		return
	if only == "lane":
		await _shared_lane()
		_finish()
		return
	if only == "kinds":
		await _every_kind()
		_finish()
		return
	if only == "grid":
		await _grid_checks()
		await _grid_snap_checks()
		await _three_lengths()
		await _card_size_switch()
		_finish()
		return
	if only == "bar":
		await _settings_on_the_stem()
		await _along_the_bar()
		await _large_loads()
		_finish()
		return
	await _model_checks()
	await _attaching()
	await _orientation_checks()
	await _feed_follows_the_belt()
	await _hover_preview()
	await _placement()
	await _settings_on_the_stem()
	await _blocked_arms()
	await _shared_lane()
	await _settings_in_flight()
	await _along_the_bar()
	await _large_loads()
	await _loose_hay()
	await _grid_checks()
	await _grid_snap_checks()
	await _save_checks()
	await _three_lengths()
	await _card_size_switch()
	await _merging()
	await _one_arm_connected()
	await _every_kind()
	_finish()


func _model_checks() -> void:
	print("\n=== model ===")
	var t:= world.builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("it is filed with the splitters", world.builds.splitters.has(t))
	_check("...and in their group", t.is_in_group("conveyor_splitters"))
	_check("...and names itself as the T (%s)" % world.builds.name_of(t),
		world.builds.name_of(t) == BuildCatalog.display_name("t_splitter")
			and BuildCatalog.display_name("t_splitter") != BuildCatalog.display_name("splitter"))


	var tech_icon:= TechPanel.icon_for(str(TechTree.nodes() ["t_splitter"].get("icon", "")))
	var y_tech:= TechPanel.icon_for("splitter") as AtlasTexture
	_check("the tech card draws the T's own cell (%s)"
		% (str((tech_icon as AtlasTexture).region) if tech_icon is AtlasTexture else "none"),
		tech_icon is AtlasTexture and y_tech != null
			and (tech_icon as AtlasTexture).region != y_tech.region)
	var build_icon:= CatalogPanel.icon_for("t_splitter")
	var y_build:= CatalogPanel.icon_for("splitter")
	_check("the build menu card draws the T's own cell (%s)"
		% (str(build_icon.region) if build_icon != null else "none"),
		build_icon != null and y_build != null and build_icon.region != y_build.region)
	if build_icon != null:


		var img:= Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/ui/icons/build-menu-icons-game.png"))
		var opaque:= 0
		var r:= build_icon.region
		if img != null:
			for py in range(int(r.position.y), int(r.end.y), 8):
				for px in range(int(r.position.x), int(r.end.x), 8):
					if img.get_pixel(px, py).a > 0.9:
						opaque += 1
		_check("...and that cell has a picture in it (%d solid samples)" % opaque, opaque > 50)

	var body:= t.get_node_or_null("Body") as Node3D
	_check("the glb is instanced", body != null)
	if body == null:
		return
	_check("...with its demonstration clip taken out",
		body.find_children("*", "AnimationPlayer", true, false).is_empty())
	var pivot:= body.find_child("GuideArmPivot", true, false) as Node3D
	var arm:= body.find_child("MatchingGuideArm", true, false) as MeshInstance3D
	var mast:= body.find_child("MatchingMastAndScreen", true, false) as MeshInstance3D
	var preview:= body.find_child("ScreenPreview", true, false) as Node3D
	_check("GuideArmPivot found", pivot != null)
	_check("MatchingGuideArm hangs on it", arm != null and pivot != null and arm.get_parent() == pivot)
	_check("the mast stands still, off the pivot",
		mast != null and pivot != null and not pivot.is_ancestor_of(mast))
	_check("ScreenPreview is hidden", preview != null and not preview.visible)


	for row: Array in [["PortIn", ConveyorTSplitter.STEM], ["PortLeft", ConveyorTSplitter.BAR_POS],
			["PortRight", ConveyorTSplitter.BAR_NEG]]:
		var marker:= body.find_child(row [0], true, false) as Node3D
		var want:= t.to_global(t.mouth_of(int(row [1])))
		var off:= marker.global_position.distance_to(want) if marker != null else 99.0
		_check("%s is lane %d's mouth (%.4f off)" % [row [0], row [1], off], off < 0.002)
	_check("pivot at the configured hinge (%.4f)" % (pivot.position.z if pivot != null else -1.0),
		pivot != null and absf(pivot.global_position.z - t.global_position.z
			- Cfg.T_SPLITTER_PIVOT_Z) < 0.002)


	if arm != null and pivot != null:
		var box:= arm.mesh.get_aabb()
		print("  arm %.3f long from the hinge, %.3f wide" % [- box.position.z, box.size.x])
		_check("the arm reaches %.3f (the class says %.3f)"
			% [- box.position.z, ConveyorTSplitter.BLADE_REACH],
			absf(- box.position.z - ConveyorTSplitter.BLADE_REACH) < 0.01)
		for angle: float in [Cfg.T_SPLITTER_SWING, - Cfg.T_SPLITTER_SWING]:
			pivot.rotation.y = angle
			var tip:= t.to_local(pivot.global_transform * Vector3(0.0, 0.0, box.position.z))
			var corner:= Vector2(-0.41 * signf(angle), -0.42)
			var miss:= Vector2(tip.x, tip.z).distance_to(corner)
			_check("at %.3f the tip meets the stem's rail corner (%.3f off)" % [angle, miss],
				miss < 0.03)
		pivot.rotation.y = Cfg.T_SPLITTER_PARK
		var parked:= t.to_local(pivot.global_transform * Vector3(0.0, 0.0, box.position.z))
		_check("parked, the arm lies along the back skirt clear of the bar lane (tip %.3f, %.3f)"
			% [parked.x, parked.z], parked.z > 0.2 and parked.x < -0.8)
		t._apply_gate()


	var screen:= t.body().screen
	_check("the live screen is fitted", screen != null)
	if mast != null and screen != null:
		var glass:= INF
		var xf:= t.global_transform.affine_inverse() * mast.global_transform
		for i in mast.mesh.get_surface_count():
			var m:= mast.mesh.surface_get_material(i)
			if m == null or not m.resource_name.contains("Screen"):
				continue
			for v: Vector3 in mast.mesh.surface_get_arrays(i) [Mesh.ARRAY_VERTEX]:
				glass = minf(glass, (xf * v).z)
		var pane:= screen.position.z
		_check("the pane is in front of the glass and within 2 cm of it (pane %.4f, glass %.4f)"
			% [pane, glass], pane < glass and glass - pane < 0.02)

	await _clear()


func _orientation_checks() -> void:
	print("\n=== every bearing, every feed ===")
	var bad_routes:= 0
	var bad_bearings:= 0
	var bad_scroll:= 0
	var bad_straight:= 0
	var cases:= 0
	for q in 4:
		var yaw:= PI * 0.5 * float(q)
		for feed: int in ConveyorTSplitter.LANES:
			var t:= world.builds.add_t_splitter(_deck(CENTRE), yaw, feed) as ConveyorTSplitter
			await get_tree().physics_frame
			cases += 1
			if t.entry != feed:
				bad_routes += 1
				continue
			var inward:= (t.global_position - t.port_in()).normalized()
			if t.forward().dot(inward) < 0.999 or not world.builds.port_bearing_at(t.port_in()).is_equal_approx(t.forward()):
				bad_bearings += 1
			for side: int in ConveyorSplitter.SIDES:
				var line: PackedVector3Array = t.route(side)._line
				if not line [0].is_equal_approx(t.port_in()) or not line [line.size() - 1].is_equal_approx(t.port(side)):
					bad_routes += 1
				var out:= (t.port(side) - t.global_position).normalized()
				if t.arm_travel(side).dot(out) < 0.999:
					bad_bearings += 1
			var straight:= t.straight_side()
			var want_straight:= -1
			if feed != ConveyorTSplitter.STEM:
				want_straight = ConveyorSplitter.LEFT if feed == ConveyorTSplitter.BAR_POS else ConveyorSplitter.RIGHT
				if straight >= 0 and t.arm_travel(straight).dot(t.forward()) < 0.999:
					bad_straight += 1
			if straight != want_straight:
				bad_straight += 1
			bad_scroll += _scroll_faults(t)
			world.builds.demolish(t)
			await get_tree().physics_frame
	_check("routes run from the feed mouth to each arm mouth (%d faults in %d)"
		% [bad_routes, cases], bad_routes == 0)
	_check("forward and arm bearings agree with the mouths (%d faults)" % bad_bearings,
		bad_bearings == 0)
	_check("the straight arm is the one ahead, and only on a bar feed (%d faults)"
		% bad_straight, bad_straight == 0)
	_check("every rubber surface runs with its lane's load (%d faults)" % bad_scroll,
		bad_scroll == 0)


	var yaw_faults:= 0
	for world_dir: Vector3 in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]:
		for lane: int in ConveyorTSplitter.LANES:
			var local:= ConveyorTSplitter.lane_out(lane)
			var yaw:= BuildTool._t_yaw(world_dir, local)
			if (Basis(Vector3.UP, yaw) * local).dot(world_dir) < 0.999:
				yaw_faults += 1
	_check("the ghost's yaw puts a lane on the bearing asked for (%d faults)" % yaw_faults,
		yaw_faults == 0)


func _scroll_faults(t: ConveyorTSplitter) -> int:
	var faults:= 0
	if t.body().rubber.size() < 9:
		print("  only %d rubber surfaces found" % t.body().rubber.size())
		faults += 1
	for r: Dictionary in t.body().rubber:
		var mi:= r ["mesh"] as MeshInstance3D
		var mat:= mi.get_surface_override_material(int(r ["surface"]))
		var travel:= t._lane_travel(int(r ["lane"]))
		var run: Vector2 = r ["run"]
		var along:= run.x * travel.x + run.y * travel.z


		var sign_:= 1.0 if mat == ConveyorKit.belt_material_fast() else -1.0
		if mat != ConveyorKit.belt_material_fast() and mat != ConveyorKit.belt_material_fast_reversed():
			faults += 1
		elif along * sign_ <= 0.0:
			faults += 1
			print("  %s runs against its lane on feed %d" % [mi.name, t.entry])
	return faults


func _feed_follows_the_belt() -> void:
	print("\n=== the feed follows the belt ===")
	var t:= world.builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
	await get_tree().physics_frame
	_check("placed with no belts, it keeps the lane it was placed with", t.entry == ConveyorTSplitter.STEM)
	t.set_forced_side(ConveyorSplitter.RIGHT)
	var pinned_lane: int = ConveyorTSplitter.exits_of(t.entry) [t.forced_side]
	var into_bar:= _run_into(t, ConveyorTSplitter.BAR_POS)
	await get_tree().physics_frame
	_check("a belt arriving at BAR_POS makes it the feed (%d)" % t.entry,
		t.entry == ConveyorTSplitter.BAR_POS)
	_check("...and the pin stays on the lane it named (%d)" % t.forced_side,
		t.forced_side >= 0 and ConveyorTSplitter.exits_of(t.entry) [t.forced_side] == pinned_lane)
	_check("...the feeding run hands to a route of the T",
		into_bar.downstream == t.route(ConveyorSplitter.LEFT)
			or into_bar.downstream == t.route(ConveyorSplitter.RIGHT))
	_check("...and the panel's buttons name the straight arm",
		t.name_for(ConveyorSplitter.SET_PIN_LEFT) != tr("LEFT"))
	world.builds.demolish(into_bar)
	await get_tree().physics_frame
	_check("with that belt gone, it keeps its feed", t.entry == ConveyorTSplitter.BAR_POS)
	var into_neg:= _run_into(t, ConveyorTSplitter.BAR_NEG)
	await get_tree().physics_frame
	_check("a belt arriving at BAR_NEG makes that the feed (%d)" % t.entry,
		t.entry == ConveyorTSplitter.BAR_NEG)
	_check("...and a pin on the lane that became the feed goes back to taking turns (%d)"
		% t.forced_side, t.forced_side == -1)
	_run_into(t, ConveyorTSplitter.STEM)
	await get_tree().physics_frame

	var builds: BuildManager = world.builds
	_check("with two belts arriving it merges them into the third lane (%d joiners, %d splitters)"
		% [builds.joiners.size(), builds.splitters.size()],
		builds.splitters.is_empty() and builds.joiners.size() == 1
			and (builds.joiners [0] as ConveyorTJoiner).out_lane == ConveyorTSplitter.BAR_POS)
	await _clear()


func _hover_preview() -> void:
	print("\n=== looking at a T ===")
	var builds: BuildManager = world.builds
	var t:= builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
	for i in 4:
		await get_tree().physics_frame
	_check("placed with no belts, the way in is the stem", t.entry == ConveyorTSplitter.STEM
		and not t.fed and t.leaving.is_empty())
	_check("with no belts it has 6 setups, 3 splits and 3 joins (%d)" % t.setups().size(),
		t.setups().size() == 6)
	t.show_possible(true, 0.0)
	_check("looked at, it shows them", t.is_showing())
	_check("...with no hints, because no belt is laid yet",
		not ConveyorTSplitter.LANES.any(t.hint_shown))
	var joins:= 0
	var splits:= 0
	var chevrons_follow:= true
	for step in 6:
		var merge:= float(t.body().screen_mat.get_shader_parameter("merge"))
		var ins: Array = t.shown_setup() ["ins"]
		if merge > 0.5:
			joins += 1
		else:
			splits += 1

		var into_middle:= 0
		for chain: PackedVector3Array in BuildTool.wye_hint_chains(t) ["chains"]:
			if chain [chain.size() - 1].is_equal_approx(t.global_position):
				into_middle += 1
		chevrons_follow = chevrons_follow and into_middle == ins.size()
		t.show_possible(true, ConveyorTSplitter.SHOW_EACH + 0.01)
	_check("one look round shows 3 splits and 3 joins (%d, %d)" % [splits, joins],
		splits == 3 and joins == 3)
	_check("...and the chevrons follow every one", chevrons_follow)
	_check("...and the real way in is untouched", t.entry == ConveyorTSplitter.STEM)
	t.show_possible(false, 0.0)
	_check("looking away stops it", not t.is_showing() and t.shown_setup().is_empty()
		and float(t.body().screen_mat.get_shader_parameter("merge")) < 0.5)

	var stem_mouth:= t.to_global(t.mouth_of(ConveyorTSplitter.STEM))
	var stem_out: Conveyor = builds.add_conveyor(stem_mouth, stem_mouth
		+ ConveyorTSplitter.lane_out(ConveyorTSplitter.STEM) * OUT_RUN)
	for i in 2:
		await get_tree().physics_frame
	_check("a belt laid out of the stem moves the way in off it (%d, leaving %s)"
		% [t.entry, str(t.leaving)], t.entry != ConveyorTSplitter.STEM
			and t.leaving == [ConveyorTSplitter.STEM] and not t.fed)
	_check("...which leaves 3 setups, the stem out in all of them (%d)" % t.setups().size(),
		t.setups().size() == 3 and t.setups().all(
			func(s: Dictionary) -> bool: return not (s ["ins"] as Array).has(ConveyorTSplitter.STEM)))
	t.show_possible(true, 0.0)
	_check("...and looked at, a hint over both bar ends and none over the stem",
		t.is_showing() and not t.hint_shown(ConveyorTSplitter.STEM)
		and t.hint_shown(ConveyorTSplitter.BAR_POS) and t.hint_shown(ConveyorTSplitter.BAR_NEG))
	t.show_possible(false, 0.0)
	var second:= t.entry
	var third:= 3 - ConveyorTSplitter.STEM - second
	var second_mouth:= t.to_global(t.mouth_of(second))
	var second_out: Conveyor = builds.add_conveyor(second_mouth, second_mouth
		+ ConveyorTSplitter.lane_out(second) * OUT_RUN)
	for i in 2:
		await get_tree().physics_frame
	_check("two belts out leave the third lane as the way in (%d, want %d)" % [t.entry, third],
		t.entry == third)
	t.show_possible(true, 0.0)
	_check("...one setup left, so looking at it shows nothing", not t.is_showing())
	_run_into(t, third)
	for i in 2:
		await get_tree().physics_frame
	_check("a belt into it feeds it", t.fed and t.entry == third)
	t.show_possible(true, 0.0)
	_check("...and with all three laid, looking at it shows nothing", not t.is_showing())


	builds.demolish(second_out)
	for i in 2:
		await get_tree().physics_frame
	_check("one in and one out leave 2 setups (%d)" % t.setups().size(),
		t.fed and t.setups().size() == 2)
	t.show_possible(true, 0.0)
	_check("...looked at, it shows them, with a hint over the free lane only",
		t.is_showing() and t.hint_shown(second) and not t.hint_shown(third)
			and not t.hint_shown(ConveyorTSplitter.STEM))
	t.show_possible(true, ConveyorTSplitter.SHOW_EACH + 0.01)
	_check("...on a fed T the screen keeps its real setup through a join",
		(t.shown_setup() ["ins"] as Array).size() == 2
			and float(t.body().screen_mat.get_shader_parameter("merge")) < 0.5)
	t.show_possible(false, 0.0)
	builds.demolish(stem_out)
	for i in 2:
		await get_tree().physics_frame
	_check("one in and nothing out leave 3 setups (%d)" % t.setups().size(),
		t.fed and t.setups().size() == 3)
	t.show_possible(true, 0.0)
	_check("...with a hint over both free lanes", t.hint_shown(second)
		and t.hint_shown(ConveyorTSplitter.STEM) and not t.hint_shown(third))
	t.show_possible(false, 0.0)
	await _clear()


func _attaching() -> void:
	print("\n=== laying belts onto its mouths ===")
	var tool: BuildTool = player.build
	var builds: BuildManager = world.builds
	for feed: int in [ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_POS]:
		var t:= builds.add_t_splitter(_deck(OPEN_FLOOR), OPEN_YAW, feed) as ConveyorTSplitter
		for i in 8:
			await get_tree().physics_frame
		for lane: int in ConveyorTSplitter.LANES:
			var mouth:= t.to_global(t.mouth_of(lane))
			var out:= (t.global_basis * ConveyorTSplitter.lane_out(lane)).normalized()
			var across:= Vector3(out.z, 0.0, - out.x)

			for far: Vector3 in [mouth + out * 3.0, mouth + out * 2.0 + across * 2.0,
					mouth + out * 1.0 + across * 3.0, mouth + out * 1.0 - across * 3.0]:
				var snapped_from:= builds.snap_endpoint(mouth + out * 0.3)
				var leaving: Dictionary = tool._evaluate(snapped_from, far, true)
				var snapped_to:= builds.snap_endpoint(mouth + out * 0.3)
				var arriving: Dictionary = tool._evaluate(far, snapped_to, true)
				var bent:= "bent" if far.distance_to(mouth + out * 3.0) > 0.1 else "straight"


				var by_t:= [false, false]
				var k:= 0
				for pair: Array in [[snapped_from, far], [far, snapped_to]]:
					var hit: Object = tool._obstruction(pair [0], pair [1],
						(pair [0] as Vector3).distance_to(pair [1]))
					if hit != null:
						by_t [k] = builds.owner_of(hit as Node) == t
						if not by_t [k]:
							print("    (the yard blocks this one: %s)" % (hit as Node).name)
					k += 1
				var yard_left: bool = str(leaving ["reason"]) == tr("blocked") and not by_t [0] or str(leaving ["reason"]) == tr("in the hay")
				var yard_arrived: bool = str(arriving ["reason"]) == tr("blocked") and not by_t [1] or str(arriving ["reason"]) == tr("in the hay")
				_check("fed %d, lane %d, %s belt out of it: snaps (%.3f), the T allows it (%s)"
					% [feed, lane, bent, snapped_from.distance_to(mouth), leaving ["reason"]],
					snapped_from.is_equal_approx(mouth) and (bool(leaving ["ok"]) or yard_left))
				_check("fed %d, lane %d, %s belt into it: snaps (%.3f), the T allows it (%s)"
					% [feed, lane, bent, snapped_to.distance_to(mouth), arriving ["reason"]],
					snapped_to.is_equal_approx(mouth) and (bool(arriving ["ok"]) or yard_arrived))
		builds.demolish(t)
		for i in 4:
			await get_tree().physics_frame


	var open_at:= OPEN_FLOOR
	var tg:= builds.add_t_splitter(_deck(open_at), OPEN_YAW) as ConveyorTSplitter
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.CONVEYOR)
	tool._reach = 14.0
	for i in 8:
		await get_tree().physics_frame
	for lane: int in ConveyorTSplitter.LANES:
		var mouth:= tg.to_global(tg.mouth_of(lane))
		var out:= (tg.global_basis * ConveyorTSplitter.lane_out(lane)).normalized()
		player.global_position = Vector3(mouth.x, 0.4, mouth.z) + out * 3.0 + Vector3(out.z, 0.0, - out.x) * 1.0
		for i in 4:
			await get_tree().physics_frame
		_aim(Vector3(mouth.x, 0.0, mouth.z) + out * 0.2)
		var start:= tool._aim_point()
		print("  gesture lane %d: aimed start lands %.3f m from the mouth (%s)"
			% [lane, start.distance_to(mouth), start])
		tool._anchor = start
		tool._state = BuildTool.State.RUNNING
		_aim(Vector3(mouth.x, 0.0, mouth.z) + out * 3.5)
		var end:= tool._aim_point()
		tool._update_run(start, end, 1.0 / 60.0)
		var hit: Object = tool._obstruction(start, end, start.distance_to(end))
		var yard: bool = str(tool._eval ["reason"]) == tr("in the hay") or (hit != null and builds.owner_of(hit as Node) != tg)
		_check("gesture: a belt started on lane %d's mouth is not refused by the T (%s%s)"
			% [lane, tool._eval ["reason"], ", by the yard" if yard else ""],
			start.is_equal_approx(mouth) and (bool(tool._eval ["ok"]) or yard))
		tool._state = BuildTool.State.AIMING
	tool.set_active(false)


	var wedges:= 0
	var tried:= 0
	for lane: int in ConveyorTSplitter.LANES:
		var mouth:= tg.to_global(tg.mouth_of(lane))
		var out:= (tg.global_basis * ConveyorTSplitter.lane_out(lane)).normalized()
		var across:= Vector3(out.z, 0.0, - out.x)
		for turn_deg: float in [15.0, 30.0, 60.0, 85.0]:
			for length: float in [1.7, 2.0, 3.0]:
				var a:= deg_to_rad(turn_deg)
				var far:= mouth + (out * cos(a) + across * sin(a)) * length
				for into: bool in [true, false]:
					var pts: PackedVector3Array = tool._port_knees(far, mouth) if into else tool._port_knees(mouth, far)
					var next:= pts [2] if into else pts [1]
					var piece:= (mouth - next) if into else (next - mouth)
					tried += 1
					if piece.length() < 0.01 or absf(piece.normalized().dot(out)) < 0.999:
						wedges += 1
						print("    wedge: lane %d, %.0f degrees, %.1f m, %s"
							% [lane, turn_deg, length, "into" if into else "out of"])
	_check("a short angled belt meets every mouth square (%d of %d wedged)" % [wedges, tried],
		wedges == 0)
	builds.demolish(tg)


	var y: ConveyorSplitter = builds.add_splitter(_deck(OPEN_FLOOR), OPEN_YAW)
	for i in 8:
		await get_tree().physics_frame
	for mouth: Vector3 in y.ports():
		var out:= (mouth - y.global_position).normalized()
		var across:= Vector3(out.z, 0.0, - out.x)
		var far:= mouth + out * 2.0 + across * 2.0
		var r: Dictionary = tool._evaluate(mouth, far, true)
		print("  control: a bent belt out of a Y mouth is %s (%s)"
			% ["allowed" if r ["ok"] else "refused", r ["reason"]])


	for pair: Array in [[y.port_left(), true], [y.port_right(), true],
			[y.port_in(), false]]:
		var mouth: Vector3 = pair [0]
		var into: bool = pair [1]
		var out:= (mouth - y.global_position).normalized()
		var far:= mouth + out * 3.0
		var wrong: Dictionary = tool._evaluate(far, mouth, true) if into else tool._evaluate(mouth, far, true)
		var want:= tr("wrong side  ·  hay goes the other way here")
		_check("a belt %s a Y's %s says which side it is on (%s)"
			% ["into" if into else "out of", "arm" if into else "infeed",
				wrong ["reason"]],
			not bool(wrong ["ok"]) and str(wrong ["reason"]) == want)
		var right: Dictionary = tool._evaluate(mouth, far, true) if into else tool._evaluate(far, mouth, true)
		print("    ...and the way round that works is %s (%s)"
			% ["allowed" if right ["ok"] else "refused", right ["reason"]])
	await _clear()


func _placement() -> void:
	print("\n=== placing it: snap and R ===")
	var tool: BuildTool = player.build
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.T_SPLITTER)
	tool._reach = 14.0
	var travel:= Vector3(1.0, 0.0, 0.0)
	var left:= Vector3(travel.z, 0.0, - travel.x)
	var start:= _deck(CENTRE + Vector3(-7.0, 0.0, 0.0))
	var end:= start + travel * 4.0
	var run: Conveyor = world.builds.add_conveyor(start, end)
	for i in 8:
		await get_tree().physics_frame
	var ghost:= tool._t_splitter_ghost


	var want:= [
		[ConveyorTSplitter.STEM, Vector3.ZERO],
		[ConveyorTSplitter.BAR_NEG, left],
		[ConveyorTSplitter.STEM, Vector3.ZERO],
		[ConveyorTSplitter.BAR_POS, - left],
	]
	var stand:= Vector3(end.x - 2.5, 0.4, end.z)
	for turn in 4:
		tool._ghost_turn = turn
		player.global_position = stand
		_aim(Vector3(end.x + 0.6, 0.0, end.z))
		for i in 4:
			await get_tree().physics_frame
		_aim(Vector3(end.x + 0.6, 0.0, end.z))
		tool._update_t_splitter_ghost()
		var feed: int = want [turn] [0]
		var branch: Vector3 = want [turn] [1]
		var on_end:= ghost.port_in().distance_to(end)
		_check("turn %d: the ghost is fed by lane %d (got %d), on the belt's end (%.4f m)"
			% [turn, feed, ghost.entry, on_end], ghost.entry == feed and on_end < 0.002)
		_check("turn %d: ...carrying on the way the belt runs (%.4f)" % [turn, ghost.forward().dot(travel)],
			ghost.forward().dot(travel) > 0.999)
		if branch == Vector3.ZERO:
			_check("turn %d: ...with its arms across the line"
				% turn, absf(ghost.arm_travel(0).dot(travel)) < 0.001
					and absf(ghost.arm_travel(1).dot(travel)) < 0.001)
		else:
			var straight:= ghost.straight_side()
			var side_arm:= ConveyorSplitter.RIGHT if straight == ConveyorSplitter.LEFT else ConveyorSplitter.LEFT
			_check("turn %d: ...one arm straight on and the branch to the %s"
				% [turn, "left" if branch == left else "right"],
				straight >= 0 and ghost.arm_travel(straight).dot(travel) > 0.999
					and ghost.arm_travel(side_arm).dot(branch) > 0.999)
		_check("turn %d: ...and it may be built there (%s)" % [turn, tool._eval ["reason"]],
			bool(tool._eval ["ok"]))


	tool._ghost_turn = 1
	_aim(Vector3(end.x + 0.6, 0.0, end.z))
	tool._update_t_splitter_ghost()
	var builds: BuildManager = world.builds
	var before:= builds.splitters.size()

	var shown:= ghost.global_position
	tool._place_t_splitter()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var placed: ConveyorTSplitter = null
	if builds.splitters.size() == before + 1:
		placed = builds.splitters [builds.splitters.size() - 1] as ConveyorTSplitter
	_check("the click built a T", placed != null)
	if placed != null:
		_check("...fed by the lane the ghost showed (%d)" % placed.entry,
			placed.entry == ConveyorTSplitter.BAR_NEG)
		_check("...where the ghost stood (%.4f m)" % placed.global_position.distance_to(shown),
			placed.global_position.distance_to(shown) < 0.0001)
		_check("...and the belt now hands to it",
			run.downstream == placed.route(0) or run.downstream == placed.route(1))


	var bend_travel:= Vector3(-1.0, 0.0, 0.0)
	for last: float in [3.0, 1.2]:
		await _bent_case(tool, ghost, last, bend_travel)
	await _bumpy_ground_case(tool, ghost)
	await _placement_head(tool, ghost, travel)


func _bumpy_ground_case(tool: BuildTool, ghost: ConveyorTSplitter) -> void:
	var builds: BuildManager = world.builds
	var start:= _deck(CENTRE + Vector3(3.0, 0.0, -4.0))
	var end:= start + Vector3(-3.0, 0.0, 0.0)
	var run: Conveyor = builds.add_conveyor(start, end)
	var slab:= StaticBody3D.new()
	slab.collision_layer = Cfg.L_WORLD
	var shape:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(4.0, 0.15, 3.0)
	shape.shape = box
	slab.add_child(shape)
	world.add_child(slab)


	slab.global_position = Vector3(end.x - 2.5, 0.075, end.z)
	for i in 8:
		await get_tree().physics_frame
	tool._ghost_turn = 1
	player.global_position = Vector3(end.x + 2.5, 0.4, end.z + 0.5)
	_aim(Vector3(end.x - 0.6, 0.0, end.z))
	for i in 4:
		await get_tree().physics_frame
	_aim(Vector3(end.x - 0.6, 0.0, end.z))
	tool._update_t_splitter_ghost()
	var hit:= tool._probe_obstruction(tool._splitter_probe_query)
	_check("snapped over ground 15 cm higher than the belt's: buildable (%s%s)"
		% [tool._eval ["reason"], ", hit %s" % (hit as Node).name if hit != null else ""],
		ghost.port_in().distance_to(end) < 0.002 and bool(tool._eval ["ok"]))
	slab.queue_free()
	builds.demolish(run)
	for i in 4:
		await get_tree().physics_frame


func _bent_case(tool: BuildTool, ghost: ConveyorTSplitter, last: float,
		bend_travel: Vector3) -> void:
	var builds: BuildManager = world.builds
	var bend_a:= _deck(CENTRE + Vector3(3.0, 0.0, -9.0))
	var bend_b:= bend_a + Vector3(0.0, 0.0, 3.0)
	var bend_c:= bend_b + bend_travel * last
	var r1: Conveyor = builds.add_conveyor(bend_a, bend_b)
	var r2: Conveyor = builds.add_conveyor(bend_b, bend_c)
	for i in 8:
		await get_tree().physics_frame
	for turn: int in [1, 3]:
		tool._ghost_turn = turn
		player.global_position = Vector3(bend_c.x + 2.5, 0.4, bend_c.z + 0.5)
		_aim(Vector3(bend_c.x - 0.6, 0.0, bend_c.z))
		for i in 4:
			await get_tree().physics_frame
		_aim(Vector3(bend_c.x - 0.6, 0.0, bend_c.z))
		tool._update_t_splitter_ghost()
		var why:= str(tool._eval ["reason"])
		var probe_hit:= tool._probe_obstruction(tool._splitter_probe_query)
		_check("fed along the bar off a belt bent %.1f m from its end (turn %d): on the end (%.3f) and buildable (%s%s)"
			% [last, turn, ghost.port_in().distance_to(bend_c), why,
				", hit %s" % (probe_hit as Node).get_path() if probe_hit != null else ""],
			ghost.port_in().distance_to(bend_c) < 0.002
				and ghost.forward().dot(bend_travel) > 0.999 and bool(tool._eval ["ok"]))
	builds.demolish(r2)
	builds.demolish(r1)
	for i in 4:
		await get_tree().physics_frame


func _placement_head(tool: BuildTool, ghost: ConveyorTSplitter, travel: Vector3) -> void:
	var builds: BuildManager = world.builds


	var head_start:= _deck(CENTRE + Vector3(0.0, 0.0, -8.0))
	world.builds.add_conveyor(head_start, head_start + travel * 4.0)
	for i in 8:
		await get_tree().physics_frame
	tool._ghost_turn = 0
	player.global_position = Vector3(head_start.x - 3.0, 0.4, head_start.z)
	_aim(Vector3(head_start.x - 0.6, 0.0, head_start.z))
	for i in 4:
		await get_tree().physics_frame
	_aim(Vector3(head_start.x - 0.6, 0.0, head_start.z))
	tool._update_t_splitter_ghost()
	print("  head case: joint %s, ghost at %s fed %d, ports %s, eval %s"
		% [builds.nearest_wye_joint(_deck(Vector3(head_start.x - 0.6, 0.0, head_start.z)), 1.3),
			ghost.global_position, ghost.entry, ghost.ports(), tool._eval])
	var arm_on:= -1
	for side: int in ConveyorSplitter.SIDES:
		if ghost.port(side).distance_to(head_start) < 0.002:
			arm_on = side
	_check("on a belt's head an arm goes on it (side %d)" % arm_on, arm_on >= 0)
	_check("...leaving the way the belt runs",
		arm_on >= 0 and ghost.arm_travel(arm_on).dot(travel) > 0.999)


	player.global_position = Vector3(head_start.x - 6.0, 0.4, head_start.z)
	var seen:= { }
	var first:= -1
	for turn in BuildTool.T_LEAVING_LAYOUTS.size():
		tool._t_turn = turn
		_aim(Vector3(head_start.x - 0.6, 0.0, head_start.z))
		for i in 2:
			await get_tree().physics_frame
		_aim(Vector3(head_start.x - 0.6, 0.0, head_start.z))
		tool._update_t_splitter_ghost()
		var on_head:= ghost.lane_at(head_start)


		if turn == 0:
			first = BuildTool.T_LEAVING_LAYOUTS.find([ghost.entry, on_head])
		var want: Array = BuildTool.T_LEAVING_LAYOUTS [(maxi(first, 0) + turn) % 6]
		seen [on_head * 3 + ghost.entry] = true
		_check("R %d: fed at lane %d (got %d), belt on lane %d (got %d), buildable (%s)"
			% [turn, want [0], ghost.entry, want [1], on_head, tool._eval ["reason"]],
			ghost.entry == want [0] and on_head == want [1] and bool(tool._eval ["ok"]))
		_check("R %d: ...the belt's lane points the way it runs" % turn,
			on_head >= 0 and (ghost.global_basis * ConveyorTSplitter.lane_out(on_head))
				.normalized().dot(travel) > 0.999)
	_check("...six different layouts (%d)" % seen.size(), seen.size() == 6)
	tool._t_turn = (2 - maxi(first, 0) + 6) % 6
	tool._update_t_splitter_ghost()
	var before:= builds.splitters.size()
	tool._place_t_splitter()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var placed: ConveyorTSplitter = null
	if builds.splitters.size() == before + 1:
		placed = builds.splitters [builds.splitters.size() - 1] as ConveyorTSplitter
	_check("the click built a T with the belt on its stem",
		placed != null and placed.lane_at(head_start) == ConveyorTSplitter.STEM)
	_check("...fed along the bar (%d)" % (placed.entry if placed != null else -1),
		placed != null and placed.entry == ConveyorTSplitter.BAR_POS)
	tool.set_active(false)
	await _clear()


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _settings_on_the_stem() -> void:
	print("\n=== settings, fed at the stem ===")
	var rig:= await _rig(0.0, ConveyorTSplitter.STEM)
	var t: ConveyorTSplitter = rig ["t"]
	_check("the rig's feed was detected as the stem", t.entry == ConveyorTSplitter.STEM)

	var r:= await _flow(rig, "hay_wad", 6, 1.3)
	_expect_split(r, "turn about", 3, 3)

	t.set_forced_side(ConveyorSplitter.LEFT)
	r = await _flow(rig, "hay_wad", 4, 1.3)
	_expect_split(r, "left arm only", 4, 0)
	_check("...and the arm stands across the shut arm (%.3f)" % t.arm_angle(),
		is_equal_approx(t.arm_angle(), Cfg.T_SPLITTER_SWING))

	t.set_forced_side(ConveyorSplitter.RIGHT)
	r = await _flow(rig, "hay_wad", 4, 1.3)
	_expect_split(r, "right arm only", 0, 4)

	t.set_priority_side(ConveyorSplitter.LEFT)
	r = await _flow(rig, "hay_wad", 4, 1.3)
	_expect_split(r, "left first, left clear", 4, 0)

	t.set_priority_side(ConveyorSplitter.RIGHT)
	r = await _flow(rig, "hay_wad", 4, 1.3)
	_expect_split(r, "right first, right clear", 0, 4)
	t.set_priority_side(-1)


	Tech.grant("belt_speed", 8)
	r = await _flow(rig, "hay_wad", 10, 1.37 / Tech.belt_speed())
	_expect_split(r, "turn about at 3.22 m/s, wads 0.42 s apart", 5, 5)


	_check("...and the arm gave up steering and folded open (%d of %d ticks)"
		% [r ["parked"], r ["ticks"]], int(r ["parked"]) * 4 >= int(r ["ticks"]))


	_check("...and no load met the steel at all (%d through, %d closed in front)"
		% [r ["swung"], r ["closed"]], int(r ["swung"]) == 0 and int(r ["closed"]) == 0)
	Tech.grant("belt_speed", 0)
	await _clear()


func _blocked_arms() -> void:
	print("\n=== an arm that has backed up ===")
	var rig:= await _rig(PI * 0.5, ConveyorTSplitter.STEM)
	var t: ConveyorTSplitter = rig ["t"]
	var outs: Array = rig ["outs"]
	var left_out:= outs [ConveyorSplitter.LEFT] as Conveyor


	left_out.set_blocked(true)
	var r:= await _flow(rig, "hay_wad", 5, 1.3, false)
	print("  turn about, filling the blocked left arm: aboard %d / %d"
		% [r ["aboard"] [0], r ["aboard"] [1]])
	var was:= r
	r = await _flow(rig, "hay_wad", 4, 1.3, false, false)
	_check("turn about: with the left arm backed up the rest go right (%d left, %d right)"
		% [r ["aboard"] [0] - was ["aboard"] [0], r ["out"] [1] - was ["out"] [1]],
		r ["aboard"] [0] == was ["aboard"] [0] and r ["out"] [1] - was ["out"] [1] == 4)
	left_out.set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "turn about, blocked then cleared")


	t.set_forced_side(ConveyorSplitter.LEFT)
	left_out.set_blocked(true)
	r = await _flow(rig, "hay_wad", 6, 1.3, false)
	print("  left only, left blocked: aboard %d / %d, out %d / %d, holding %s"
		% [r ["aboard"] [0], r ["aboard"] [1], r ["out"] [0], r ["out"] [1], t.is_holding()])
	_check("left only: a backed-up left arm gives nothing to the right (%d)" % r ["aboard"] [1],
		r ["aboard"] [1] == 0 and r ["out"] [1] == 0)
	_check("...and the loads wait on the belt rather than on the floor (%d loose)"
		% _loose(rig), _loose(rig) == 0)
	left_out.set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "left only, blocked then cleared")
	_check("...and once it clears they all go left (%d of %d)" % [r ["out"] [0], r ["fed"]],
		r ["out"] [0] == r ["fed"])


	t.set_priority_side(ConveyorSplitter.LEFT)
	left_out.set_blocked(true)
	r = await _flow(rig, "hay_wad", 5, 1.3, false)
	print("  left first, filling the blocked main arm: aboard %d / %d"
		% [r ["aboard"] [0], r ["aboard"] [1]])
	was = r
	r = await _flow(rig, "hay_wad", 4, 1.3, false, false)
	_check("left first: a backed-up main arm spills the rest to the right (%d main, %d spill)"
		% [r ["aboard"] [0] - was ["aboard"] [0], r ["out"] [1] - was ["out"] [1]],
		r ["aboard"] [0] == was ["aboard"] [0] and r ["out"] [1] - was ["out"] [1] == 4)
	left_out.set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "left first, blocked then cleared")
	r = await _flow(rig, "hay_wad", 3, 1.3)
	_expect_split(r, "left first, cleared again", 3, 0)


	t.set_priority_side(-1)
	for o in outs:
		(o as Conveyor).set_blocked(true)
	r = await _flow(rig, "hay_wad", 8, 1.3, false)
	_check("both arms backed up: nothing is let go to the floor (%d loose)" % _loose(rig),
		_loose(rig) == 0)
	for o in outs:
		(o as Conveyor).set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "both blocked then cleared")
	await _clear()


func _settings_in_flight() -> void:
	print("\n=== a setting changed with a load on its way ===")
	var rig:= await _rig(0.0, ConveyorTSplitter.STEM)
	var t: ConveyorTSplitter = rig ["t"]


	await _one_caught_right(rig, "pinned left")
	t.set_forced_side(ConveyorSplitter.LEFT)
	var r:= await _flow(rig, "hay_wad", 3, 1.3, true, false)
	_expect_split(r, "pinned left with a wad on its way right", 4, 0)
	_check("...and the feed is not held once it has drained (holding %s)" % t.is_holding(),
		not t.is_holding())
	_check("...and nothing was left on the floor (%d loose)" % _loose(rig), _loose(rig) == 0)


	await _one_caught_right(rig, "left first")
	t.set_priority_side(ConveyorSplitter.LEFT)
	r = await _flow(rig, "hay_wad", 3, 1.3, true, false)
	_expect_split(r, "left first with a wad on its way right", 3, 1)
	_check("...and the feed is not held once it has drained (holding %s)" % t.is_holding(),
		not t.is_holding())
	t.set_priority_side(-1)


	var left_out:= rig ["outs"] [ConveyorSplitter.LEFT] as Conveyor
	left_out.set_blocked(true)
	r = await _flow(rig, "hay_wad", 12, 0.75, false)
	var waiting:= 0
	for m in t.route(ConveyorSplitter.LEFT).load_marks():
		if bool(m ["prop"]) and float(m ["s"]) + float(m ["reach"]) <= t.hold_s() + BeltPath.HOLD_SLACK:
			waiting += 1
	print("  turn about, left blocked, wads 0.75 s apart: aboard %d / %d, out %d / %d, holding %s"
		% [r ["aboard"] [0], r ["aboard"] [1], r ["out"] [0], r ["out"] [1], t.is_holding()])
	_check("a backed-up arm keeps no wad waiting at the hold line while the other is clear (%d waiting, holding %s)"
		% [waiting, t.is_holding()], waiting == 0 and not t.is_holding())
	_check("...and nothing is let go to the floor (%d loose)" % _loose(rig), _loose(rig) == 0)
	await _full_arm_keeps_the_other(rig, r, "turn about")
	left_out.set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "turn about, blocked close together then cleared")


	t.set_priority_side(ConveyorSplitter.LEFT)
	left_out.set_blocked(true)
	r = await _flow(rig, "hay_wad", 12, 0.6, false)
	await _full_arm_keeps_the_other(rig, r, "left first")
	left_out.set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "left first, blocked close together then cleared")
	t.set_priority_side(-1)
	await _clear()


func _full_arm_keeps_the_other(rig: Dictionary, was: Dictionary, label: String) -> void:
	var r:= await _flow(rig, "hay_wad", 6, 0.6, false, false)
	var right: int = r ["out"] [1] - was ["out"] [1]
	print("  %s, left full, 6 more wads 0.6 s apart: %d right, left aboard %d -> %d"
		% [label, right, was ["aboard"] [0], r ["aboard"] [0]])
	_check("%s: with the left arm full the right one still takes every wad (%d of 6)"
		% [label, right], right == 6 and r ["aboard"] [0] == was ["aboard"] [0])
	if right != 6:

		var t: ConveyorTSplitter = rig ["t"]
		print("    holding %s, arm at %.3f, hold line s %.2f"
			% [t.is_holding(), t.arm_angle(), t.hold_s()])
		for side in [ConveyorSplitter.LEFT, ConveyorSplitter.RIGHT]:
			for m in t.route(side).load_marks():
				if bool(m ["prop"]):
					print("    side %d: s %.2f reach %.2f" % [side, float(m ["s"]), float(m ["reach"])])
	_check("...and nothing is let go to the floor (%d loose)" % _loose(rig), _loose(rig) == 0)


func _one_caught_right(rig: Dictionary, label: String) -> void:
	var t: ConveyorTSplitter = rig ["t"]
	var feed:= rig ["feed"] as Conveyor
	t.set_forced_side(ConveyorSplitter.RIGHT)
	t.set_forced_side(-1)
	_route_side.clear()
	_out_side.clear()
	_fed.clear()
	_fed_ids.clear()
	_strands.clear()
	_seq_of.clear()
	_strands_by_seq.clear()
	_changed = 0
	_swung_through = 0
	_closed_ahead = 0
	_parked_ticks = 0
	_arm_ticks = 0
	_limbo_ticks = 0
	_limbo_run = 0
	_unassigned = 0
	_hold_frames = 0
	var body:= world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP,
		atan2(feed.forward.x, feed.forward.z)),
		feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0))) as RigidBody3D
	if body == null:
		_check("%s: a wad spawned" % label, false)
		return
	var id:= body.get_instance_id()
	_fed.append(body)
	_fed_ids.append(id)
	_every_prop.append(body)
	_strands [id] = (body as Carryable).hay_strands()
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var on_way:= false
	for k in int(belt_secs(FEED_RUN + 3.0) / step):
		await _watch(t)


		var seq: int = _seq_of.get(id, -1)
		for m in t.route(ConveyorSplitter.RIGHT).load_marks():
			if seq >= 0 and int(m ["seq"]) == seq and float(m ["s"]) + float(m ["reach"]) < t.hold_s() - 0.2:
				on_way = true
		if on_way:
			break
	_check("%s: a wad was caught for the right arm and is still on the feed" % label, on_way)


func _one_arm_connected() -> void:
	for variant: String in ["a merge that loses a belt", "laid one belt at a time"]:
		print("\n=== one arm connected: %s ===" % variant)
		var builds: BuildManager = world.builds
		var placed:= builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
		var feed:= _run_into(placed, ConveyorTSplitter.STEM)
		await get_tree().physics_frame
		var mouth:= placed.to_global(placed.mouth_of(ConveyorTSplitter.BAR_POS))
		var away:= (placed.global_basis * ConveyorTSplitter.lane_out(ConveyorTSplitter.BAR_POS)).normalized()
		var out_run: Conveyor = builds.add_conveyor(mouth, mouth + away * OUT_RUN)
		if variant == "a merge that loses a belt":
			var t0:= builds.splitters [0] as ConveyorTSplitter
			var second:= _run_into(t0, ConveyorTSplitter.BAR_NEG)
			await get_tree().physics_frame
			_check("%s: two belts in made it a merge (%d joiners)" % [variant, builds.joiners.size()],
				builds.joiners.size() == 1)
			builds.demolish(second)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		var ok:= builds.splitters.size() == 1 and builds.joiners.is_empty() and (builds.splitters [0] as ConveyorTSplitter).entry == ConveyorTSplitter.STEM
		_check("%s: one belt in, a splitter fed at the stem" % variant, ok)
		if not ok:
			await _clear()
			continue
		var t:= builds.splitters [0] as ConveyorTSplitter
		var belted:= ConveyorTSplitter.exits_of(ConveyorTSplitter.STEM).find(ConveyorTSplitter.BAR_POS)
		for side: int in ConveyorSplitter.SIDES:
			t.route(side).caught.connect(_on_route_caught.bind(side))
			t.route(side).caught_record.connect(_on_route_caught_record.bind(side))
		_follow_reroutes(t)
		out_run.caught.connect(_on_out_caught.bind(belted))
		out_run.caught_record.connect(_on_out_caught_record.bind(belted))
		var rig:= { "t": t, "feed": feed, "outs": [out_run] }


		var empty:= ConveyorSplitter._other(belted)
		var r:= await _flow(rig, "hay_wad", 6, 1.3)
		var loose:= _loose(rig)
		print("  %s, turn about: aboard %d / %d, out %d / %d, %d loose"
			% [variant, r ["aboard"] [0], r ["aboard"] [1], r ["out"] [0], r ["out"] [1], loose])
		_check("%s, turn about: one each way" % variant,
			int(r ["aboard"] [empty]) == 3 and int(r ["out"] [belted]) == 3)
		_check("%s, turn about: the empty lane's three fell off its mouth (%d loose)" % [variant, loose],
			loose == 3)
		t.set_forced_side(empty)
		r = await _flow(rig, "hay_wad", 3, 1.3)
		print("  %s, pinned to the empty lane: aboard %d / %d, %d loose"
			% [variant, r ["aboard"] [0], r ["aboard"] [1], _loose(rig) - loose])
		_check("%s, pinned to the empty lane: every wad down it" % variant,
			int(r ["aboard"] [empty]) == 3 and int(r ["aboard"] [belted]) == 0)
		_check("%s, pinned to the empty lane: they fell off its mouth (%d loose)" % [variant, _loose(rig) - loose],
			_loose(rig) - loose == 3)
		await _clear()


func _along_the_bar() -> void:
	print("\n=== fed along the bar ===")
	var rig:= await _rig(PI * 0.5, ConveyorTSplitter.BAR_POS)
	var t: ConveyorTSplitter = rig ["t"]
	_check("the rig's feed was detected as BAR_POS", t.entry == ConveyorTSplitter.BAR_POS)
	var r:= await _flow(rig, "hay_wad", 6, 1.3)
	_expect_split(r, "BAR_POS turn about (straight / stem)", 3, 3)
	t.set_forced_side(t.straight_side())
	_check("pinned straight, the caption says so (%s)" % t.setting_name(),
		t.setting_name() == tr("STRAIGHT ON"))
	r = await _flow(rig, "eco_brick", 4, 1.3)
	_expect_split(r, "straight on only, bricks", 4, 0)
	t.set_priority_side(ConveyorSplitter.RIGHT)
	r = await _flow(rig, "hay_wad", 3, 1.3)
	_expect_split(r, "stem first", 0, 3)
	t.set_priority_side(-1)
	await _clear()

	rig = await _rig(PI, ConveyorTSplitter.BAR_NEG)
	t = rig ["t"]
	_check("the rig's feed was detected as BAR_NEG", t.entry == ConveyorTSplitter.BAR_NEG)
	r = await _flow(rig, "hay_wad", 4, 1.3)
	_expect_split(r, "BAR_NEG turn about (stem / straight)", 2, 2)
	await _clear()

	rig = await _rig(PI * 1.5, ConveyorTSplitter.STEM)
	r = await _flow(rig, "hay_wad", 4, 1.3)
	_expect_split(r, "stem at the fourth bearing", 2, 2)
	await _clear()


func _watch_lane(t: ConveyorTSplitter) -> void:
	var split:= float(t._split_s)
	var lanes:= []
	for side: int in ConveyorSplitter.SIDES:
		var on: Array = []
		for m in t.route(side).load_marks():
			if float(m ["s"]) - float(m ["reach"]) < split:
				on.append(m)
		lanes.append(on)


	var dt:= get_physics_process_delta_time() * float(FactoryClock.stride)
	var now:= Engine.get_physics_frames()
	var stepped:= false
	for side: int in ConveyorSplitter.SIDES:
		if t.route(side).run.stepped_tick == now:
			stepped = true
	var ahead:= { }
	for side: int in ConveyorSplitter.SIDES:
		if not stepped:
			break
		var run:= t.route(side).run
		for i in range(run.first(), run.first() + run.count()):
			var seq:= run.seq_of(i)
			var s:= run.s_of(i)
			if _drawn_ahead.has(seq):
				var back:= float(_drawn_ahead [seq]) - s
				if back > 0.001:
					_snap_frames += 1
					_snap_worst = maxf(_snap_worst, back)
			var v:= run.speed_of(i)
			ahead [seq] = s + (minf(v * dt, run.row_room(i)) if v > 0.0 else 0.0)
	if stepped:
		_drawn_ahead = ahead
	var worst:= 0.0
	for a in lanes [0]:
		for b in lanes [1]:
			var deep:= float(a ["reach"]) + float(b ["reach"]) - absf(float(a ["s"]) - float(b ["s"]))
			worst = maxf(worst, deep)

	if worst > 0.01:
		_lane_overlap_frames += 1
		_lane_overlap_worst = maxf(_lane_overlap_worst, worst)


func _shared_lane() -> void:

	for rank in [0, 8]:
		Tech.grant("belt_speed", rank)
		await _shared_lane_at(0.6 * Cfg.BELT_SPEED / Tech.belt_speed())
	Tech.grant("belt_speed", 0)


func _shared_lane_at(gap: float) -> void:
	print("\n=== one arm full, packed feed, turn about, %.2f m/s ===" % Tech.belt_speed())
	var rig:= await _rig(PI * 0.5, ConveyorTSplitter.STEM)
	var outs: Array = rig ["outs"]
	var right_out:= outs [ConveyorSplitter.RIGHT] as Conveyor
	_lane_overlap_frames = 0
	_lane_overlap_worst = 0.0
	_snap_frames = 0
	_snap_worst = 0.0
	right_out.set_blocked(true)
	var r:= await _flow(rig, "hay_wad", 14, gap, false)
	print("  aboard %d / %d, out %d / %d, lane overlap %d ticks, deepest %.3f m"
		% [r ["aboard"] [0], r ["aboard"] [1], r ["out"] [0], r ["out"] [1],
			_lane_overlap_frames, _lane_overlap_worst])

	var t0:= Time.get_ticks_usec()
	for i in 1000:
		rig ["t"]._share_lane()
	print("  sharing the lane: %.2f us a tick with %d loads aboard"
		% [float(Time.get_ticks_usec() - t0) / 1000.0,
			rig ["t"].route(0).run.count() + rig ["t"].route(1).run.count()])
	_check("no wad drawn ahead of where the next tick put it (%d times, %.3f m)"
		% [_snap_frames, _snap_worst], _snap_frames == 0)
	_check("no two loads on the feed lane inside each other (%d ticks, %.3f m)"
		% [_lane_overlap_frames, _lane_overlap_worst], _lane_overlap_frames == 0)


	_check("the free arm keeps taking loads (%d out left of %d fed, %d right aboard)"
		% [r ["out"] [0], r ["fed"], r ["aboard"] [1]],
		r ["out"] [0] + r ["aboard"] [1] >= r ["fed"] - 1)
	right_out.set_blocked(false)
	r = await _settle_flow(r)
	_expect_whole(r, "one arm full, then cleared")
	await _clear()


func _rate() -> void:
	print("\n=== throughput, packed feed ===")
	var hz:= float(Engine.physics_ticks_per_second)
	var kind:= "hay_wad"
	for rank in [0, 1]:
		Tech.grant("belt_speed", rank)

		var gap:= 0.6 * Cfg.BELT_SPEED / Tech.belt_speed()
		print("  belt motor rank %d, %.2f m/s, a wad every %.2f s" % [rank, Tech.belt_speed(), gap])

		var a:= _deck(CENTRE) + Vector3(0.0, 0.0, - FEED_RUN)
		var b:= _deck(CENTRE)
		var feed_run: Conveyor = world.builds.add_conveyor(a, b)
		var out_run: Conveyor = world.builds.add_conveyor(b, b + Vector3(0.0, 0.0, OUT_RUN))
		out_run.caught.connect(_on_out_caught.bind(0))
		out_run.caught_record.connect(_on_out_caught_record.bind(0))
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		_out_frames_at.clear()
		var at:= feed_run.a + feed_run.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
		for i in 12:
			_every_prop.append(world.props.spawn(kind, Transform3D(Basis(Vector3.UP,
				atan2(feed_run.forward.x, feed_run.forward.z)), at)))
			for k in int(gap * hz):
				await get_tree().physics_frame
		for k in int(belt_secs(FEED_RUN + OUT_RUN) * hz):
			await get_tree().physics_frame
		print("    plain belt: out %d / 12, %.2f s a wad" % [_out_frames_at.size(), _mean_gap(hz)])
		await _clear()
		for feed in [ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_POS]:
			for mode in ["turn about", "pinned left", "left first"]:
				var rig:= await _rig(0.0, feed)
				var t: ConveyorTSplitter = rig ["t"]
				if mode == "pinned left":
					t.set_forced_side(ConveyorSplitter.LEFT)
				elif mode == "left first":
					t.set_priority_side(ConveyorSplitter.LEFT)
				_out_frames_at.clear()
				_why.clear()
				_route_speed_max = 0.0
				var r:= await _flow(rig, kind, 12, gap)
				print("    fed %s, %s: out %d / %d, held %.2f s, %.2f s a wad, fastest in the T %.2f m/s, route drive %.2f"
					% [["stem", "bar +", "bar -"] [feed], mode,
						r ["out"] [0], r ["out"] [1], r ["held_s"], _mean_gap(hz), _route_speed_max,
						t.route(ConveyorSplitter.LEFT).drive_speed])
				print("      ", _why)
				await _clear()
	Tech.grant("belt_speed", 0)


func _cost() -> void:
	print("\n=== cost of a chain of Ts, packed wads ===")
	Tech.grant("belt_speed", 8)
	var hz:= float(Engine.physics_ticks_per_second)
	var gap:= 0.6 * Cfg.BELT_SPEED / Tech.belt_speed()
	print("  %.2f m/s, a wad every %.2f s" % [Tech.belt_speed(), gap])
	for mode in ["straight first", "straight on", "turn about", "stem first"]:
		var ts: Array [ConveyorTSplitter] = []
		var at:= _deck(CENTRE) + Vector3(0.0, 0.0, -4.0)
		var feed: Conveyor = null
		var came:= Vector3.ZERO
		for i in 4:
			var t:= world.builds.add_t_splitter(at, PI * 0.5) as ConveyorTSplitter
			var mouth:= t.to_global(t.mouth_of(ConveyorTSplitter.BAR_POS))
			if i == 0:
				feed = _run_into(t, ConveyorTSplitter.BAR_POS)
			else:
				world.builds.add_conveyor(came, mouth)
			var stem:= t.to_global(t.mouth_of(ConveyorTSplitter.STEM))
			var out:= (stem - t.global_position).normalized()
			world.builds.add_conveyor(stem, stem + out * OUT_RUN)
			came = t.to_global(t.mouth_of(ConveyorTSplitter.BAR_NEG))
			var along:= (came - mouth).normalized()
			at = came + along * (1.2 + t.port_r)
			ts.append(t)
		var last:= came + (came - ts [3].global_position).normalized() * OUT_RUN
		world.builds.add_conveyor(came, last)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		for t in ts:
			var straight:= t.straight_side()
			match mode:
				"straight first":
					t.set_priority_side(straight)
				"straight on":
					t.set_forced_side(straight)
				"stem first":
					t.set_priority_side(ConveyorSplitter._other(straight))
		print("  %s: entries %s, settings %s" % [mode,
			str(ts.map(func(x: ConveyorTSplitter) -> int: return x.entry)),
			str(ts.map(func(x: ConveyorTSplitter) -> String: return x.setting_name()))])
		var spawn:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
		ConveyorTSplitter.cost_us.clear()
		ConveyorTSplitter.profile = true
		var frames:= 0
		for i in 60:
			_every_prop.append(world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP,
				atan2(feed.forward.x, feed.forward.z)), spawn)))
			for k in int(gap * hz):
				await get_tree().physics_frame
				frames += 1
		ConveyorTSplitter.profile = false
		var c:= ConveyorTSplitter.cost_us
		var ticks:= maxi(int(c.get("ticks", 0)), 1)
		var parts:= PackedStringArray()
		var total:= 0
		for part in c:
			if part == "ticks" or part == "arm_blocked calls":
				continue
			total += int(c [part])
			parts.append("%s %.1f" % [part, float(c [part]) / ticks])
		print("    %d ticks over %d frames, %.1f us a tick: %s; arm_blocked %d calls, parked %s"
			% [ticks, frames, float(total) / ticks, ", ".join(parts),
				int(c.get("arm_blocked calls", 0)),
				str(ts.map(func(x: ConveyorTSplitter) -> bool: return x.arm_parked()))])
		await _clear()
	Tech.grant("belt_speed", 0)


func _straight_first_chain() -> void:
	print("\n=== straight first, chain with the straight line clear ===")
	for rank in [0, 8]:
		Tech.grant("belt_speed", rank)
		for gap_m: float in [1.2, 0.6]:
			var gap: float = gap_m / Tech.belt_speed()
			var ts: Array [ConveyorTSplitter] = []
			var stems: Array [Conveyor] = []
			var at:= _deck(CENTRE) + Vector3(0.0, 0.0, -4.0)
			var feed: Conveyor = null
			var came:= Vector3.ZERO
			for i in 4:
				var t:= world.builds.add_t_splitter(at, PI * 0.5) as ConveyorTSplitter
				var mouth:= t.to_global(t.mouth_of(ConveyorTSplitter.BAR_POS))
				if i == 0:
					feed = _run_into(t, ConveyorTSplitter.BAR_POS)
				else:
					world.builds.add_conveyor(came, mouth)
				var stem:= t.to_global(t.mouth_of(ConveyorTSplitter.STEM))
				stems.append(world.builds.add_conveyor(stem, stem + (stem - t.global_position).normalized() * OUT_RUN))
				came = t.to_global(t.mouth_of(ConveyorTSplitter.BAR_NEG))
				at = came + (came - mouth).normalized() * (1.2 + t.port_r)
				ts.append(t)
			world.builds.add_conveyor(came, came + (came - ts [3].global_position).normalized() * 8.0)
			for i in SETTLE_FRAMES:
				await get_tree().physics_frame


			var side_caught:= [0, 0, 0, 0]
			for k in 4:
				ts [k].set_priority_side(ts [k].straight_side())
				stems [k].caught_record.connect(func(_q: int, _k: int, _n: int) -> void: side_caught [k] += 1)
			var held:= [0, 0, 0, 0]
			var stuck:= [0, 0, 0, 0]
			var stalled_side:= [0, 0, 0, 0]
			var stopped:= [0, 0, 0, 0]
			var spawn:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
			var hz:= float(Engine.physics_ticks_per_second)
			for i in 30:
				_every_prop.append(world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP,
					atan2(feed.forward.x, feed.forward.z)), spawn)))
				for f in int(gap * hz):
					await get_tree().physics_frame
					for k in 4:
						var t:= ts [k]
						var st:= t.straight_side()
						if t.is_holding():
							held [k] += 1
						if t._stuck [st]:
							stuck [k] += 1
						if float(t._stall [st]) > 0.0:
							stalled_side [k] += 1
						var run:= t.route(st).run
						for r in range(run.first(), run.first() + run.count()):
							if run.speed_of(r) < 0.05:
								stopped [k] += 1
								break
					if OS.has_environment("TRACE_STRAIGHT") and k_trace_left(ts [0], feed):
						pass
			for f in int(4.0 * hz):
				await get_tree().physics_frame
			print("  rank %d %.2f m/s, wads %.1f m apart: side %s, held ticks %s, stuck ticks %s, stall ticks %s, ticks a load stood still %s"
				% [rank, Tech.belt_speed(), gap_m, str(side_caught), str(held),
					str(stuck), str(stalled_side), str(stopped)])
			_check("rank %d, %.1f m apart: nothing turned off a clear straight line" % [rank, gap_m],
				side_caught == [0, 0, 0, 0])
			_check("rank %d, %.1f m apart: no T held its feed" % [rank, gap_m], held == [0, 0, 0, 0])
			_check("rank %d, %.1f m apart: no wad stood still on a straight arm" % [rank, gap_m],
				stopped == [0, 0, 0, 0])
			await _clear()
	Tech.grant("belt_speed", 0)


func _pinned_after_fold() -> void:
	print("\n=== a folded arm, then one way only ===")
	Tech.grant("belt_speed", 8)
	var gap:= 0.6 * Cfg.BELT_SPEED / Tech.belt_speed()
	for setting in ["stem only", "stem first", "straight only"]:
		var rig:= await _rig(PI * 0.5, ConveyorTSplitter.BAR_POS)
		var t: ConveyorTSplitter = rig ["t"]
		var feed:= rig ["feed"] as Conveyor
		var spawn:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
		var hz:= float(Engine.physics_ticks_per_second)
		var folded:= false
		var wrong:= 0
		var ever:= false
		for i in 60:
			if i == 30:
				folded = t.arm_parked()
				var stem:= ConveyorSplitter._other(t.straight_side())
				match setting:
					"stem only":
						t.set_forced_side(stem)
					"stem first":
						t.set_priority_side(stem)
					"straight only":
						t.set_forced_side(t.straight_side())
			_every_prop.append(world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP,
				atan2(feed.forward.x, feed.forward.z)), spawn)))
			for f in int(gap * hz):
				await get_tree().physics_frame
				ever = ever or t.arm_parked()

				if i >= 30 + int(2.0 / gap):
					var want:= ConveyorTSplitter.blade_angle(t.entry,
						ConveyorTSplitter.exits_of(t.entry) [t._rest_side()])
					if absf(t.arm_angle() - want) > 0.02:
						wrong += 1
		print("  %s: folded at the change %s, ever %s, ticks the arm stood off its setting %d, arm %.3f" % [
			setting, str(folded), str(ever), wrong, t.arm_angle()])
		_check("%s: the arm was folded on the packed line first" % setting, folded)
		_check("%s: the arm stands for the setting on a packed line" % setting, wrong == 0)
		await _clear()
	Tech.grant("belt_speed", 0)


var _trace_n:= 0


func k_trace_left(t: ConveyorTSplitter, feed: Conveyor) -> bool:
	var st:= t.straight_side()
	var route:= t.route(st)
	var still:= false
	for r in range(route.run.first(), route.run.first() + route.run.count()):
		if route.run.speed_of(r) < 0.05:
			still = true
	if _trace_n == 0 and not still:
		return false
	if _trace_n >= 40:
		return false
	_trace_n += 1
	var line:= "f%d hold=%s open=%d | feed %s | route %s | next %s" % [Engine.get_physics_frames(),
		str(t.is_holding()), t._open_side(), _run_text(feed.run),
		_run_text(route.run), _run_text(route.downstream.run if route.downstream != null else null)]
	print(line)
	return true


func _run_text(run: BeltRun) -> String:
	if run == null:
		return "-"
	var parts:= PackedStringArray()
	for r in range(run.first(), run.first() + run.count()):
		parts.append("%.3f:%.2f" % [run.s_of(r), run.speed_of(r)])
	return " ".join(parts)


func _mean_gap(hz: float) -> float:
	var total:= 0.0
	for i in range(4, _out_frames_at.size()):
		total += float(_out_frames_at [i] - _out_frames_at [i - 1]) / hz
	return total / maxf(_out_frames_at.size() - 4, 1.0)


func _large_loads() -> void:
	print("\n=== bales nose to tail ===")
	var rig:= await _rig(0.0, ConveyorTSplitter.STEM)
	var t: ConveyorTSplitter = rig ["t"]
	var r:= await _flow(rig, "hay_bale", 6, 1.0)
	_expect_split(r, "bales, turn about", 3, 3)
	_check("...and it let go again (holding %s)" % t.is_holding(), not t.is_holding())

	print("\n=== bales along the bar ===")
	await _clear()
	rig = await _rig(0.0, ConveyorTSplitter.BAR_NEG)
	r = await _flow(rig, "hay_bale", 6, 1.0)
	_expect_split(r, "bales along the bar", 3, 3)
	await _clear()


func _loose_hay() -> void:
	print("\n=== loose hay ===")
	var rig:= await _rig(0.0, ConveyorTSplitter.STEM)
	var t: ConveyorTSplitter = rig ["t"]
	var feed:= rig ["feed"] as Conveyor
	var rng:= RandomNumberGenerator.new()
	rng.seed = 20260916
	var got:= [0, 0]
	for side: int in ConveyorSplitter.SIDES:
		(rig ["outs"] [side] as Conveyor).caught.connect(_count_hay.bind(got, side))
	for i in 24:
		world.live.spawn(feed.a + feed.forward * (0.6 + 0.1 * float(i % 3))
			+ Vector3(rng.randf_range(-0.15, 0.15), 0.22, 0.0),
			StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		for k in int(0.5 / get_physics_process_delta_time()):
			await get_tree().physics_frame
	var paths: Array = [feed]
	for route in t.routes():
		paths.append(route)
	var drained: bool = await _drain(paths, DRAIN_LIMIT)
	print("  hay out %d left, %d right" % [got [0], got [1]])
	_check("strands carry through and the machine empties", drained)
	_check("...down both arms (%d / %d)" % [got [0], got [1]], got [0] > 0 and got [1] > 0)
	await _clear()


func _count_hay(body: RigidBody3D, got: Array, side: int) -> void:
	if body.collision_layer & Cfg.L_PROP == 0:
		got [side] += 1


func _grid_checks() -> void:
	print("\n=== grid ===")
	var t:= world.builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	_check("a new T stands its mouths %.2f out" % t.port_r,
		is_equal_approx(t.port_r, ConveyorTSplitter.placed_port_r))


	var want_off:= not is_equal_approx(ConveyorTSplitter.placed_port_r,
		roundf(ConveyorTSplitter.placed_port_r))
	var off_grid:= 0
	for lane: int in ConveyorTSplitter.LANES:
		var m:= t.to_global(t.mouth_of(lane))
		if absf(m.x - roundf(m.x)) > 0.001 or absf(m.z - roundf(m.z)) > 0.001:
			off_grid += 1
			print("    lane %d mouth at (%.3f, %.3f)" % [lane, m.x, m.z])
	_check("...and on a grid crossing all three mouths land where the length says (%d off)"
		% off_grid, off_grid == (3 if want_off else 0))
	_check("...in the current model",
		t._tbody._path == ConveyorTBody.model_for(ConveyorTSplitter.placed_port_r))
	_check("...on six legs (%d)" % _legs(t), _legs(t) == 6)


	var data: Array = world.builds.to_array()
	var wrote:= -1.0
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_t_splitter":
			wrote = float(entry.get("port_r", -1.0))
			(entry as Dictionary).erase("port_r")
	_check("it saves its mouths (%.2f)" % wrote, is_equal_approx(wrote, ConveyorTSplitter.placed_port_r))


	var two: Array = data.duplicate(true)
	for entry in two:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_t_splitter":
			(entry as Dictionary) ["port_r"] = Cfg.T_SPLITTER_PORT_R_V2
	world.builds.from_array(two)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var big:= _only_t()
	_check("a T saved at 2 m comes back at 2 m (%.2f)" % (big.port_r if big != null else -1.0),
		big != null and is_equal_approx(big.port_r, Cfg.T_SPLITTER_PORT_R_V2))
	if big != null:
		_check("...in the 2 m model", big._tbody._path == ConveyorTBody.MODEL_V2)
		_check("...with its stem mouth 2 m out (%.3f)"
			% big.port_in().distance_to(big.global_position),
			is_equal_approx(big.port_in().distance_to(big.global_position), 2.0))

	world.builds.from_array(data)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var old:= _only_t()
	_check("a T saved without port_r comes back as the first T (%.2f)"
		% (old.port_r if old != null else -1.0),
		old != null and is_equal_approx(old.port_r, Cfg.T_SPLITTER_PORT_R_V1))
	if old == null:
		await _clear()
		return
	_check("...in the first model", old._tbody._path == ConveyorTBody.MODEL_V1)
	_check("...with its stem mouth 1.5 out (%.3f)"
		% old.port_in().distance_to(old.global_position),
		is_equal_approx(old.port_in().distance_to(old.global_position), Cfg.T_SPLITTER_PORT_R_V1))
	_check("...on six legs (%d)" % _legs(old), _legs(old) == 6)


	var into:= _run_into(old, ConveyorTSplitter.STEM)
	for side: int in ConveyorSplitter.SIDES:
		var mouth:= old.port(side)
		world.builds.add_conveyor(mouth, mouth + old.arm_travel(side) * OUT_RUN)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	data = world.builds.to_array()
	world.builds.from_array(data)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	old = _only_t()
	_check("saved again, it is still the first T (%.2f)" % (old.port_r if old != null else -1.0),
		old != null and is_equal_approx(old.port_r, Cfg.T_SPLITTER_PORT_R_V1))
	if old == null:
		await _clear()
		return
	into = world.builds.feed_run_into(old.port_in())
	var outs: Array = [world.builds.run_out_of(old.port(ConveyorSplitter.LEFT)),
		world.builds.run_out_of(old.port(ConveyorSplitter.RIGHT))]
	_check("...with a belt still ending on its stem", into != null)
	_check("...and one still leaving each arm", outs [0] != null and outs [1] != null)
	if into == null or outs.has(null):
		await _clear()
		return
	var rig:= await _wire(old, into, outs)
	var got:= await _flow(rig, "hay_wad", 6, 0.8)
	var through: int = got ["out"] [0] + got ["out"] [1]
	_check("...and it still splits: 6 wads in, %d out (%d / %d), %d gone"
		% [through, got ["out"] [0], got ["out"] [1], got ["gone"]],
		through == 6 and got ["out"] [0] > 0 and got ["out"] [1] > 0 and got ["gone"] == 0)
	await _clear()


func _grid_snap_checks() -> void:
	print("\n=== snapped onto the grid ===")
	var tool: BuildTool = player.build
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.T_SPLITTER)
	tool._reach = 14.0
	tool._grid_on = true
	tool._ghost_turn = 0
	var travel:= Vector3(1.0, 0.0, 0.0)


	var r:= ConveyorTSplitter.placed_port_r
	var start:= _deck(Vector3(-21.0, 0.0, 6.0))
	var end:= _deck(Vector3(-17.5 + fposmod(r, 1.0), 0.0, 6.0))
	var run: Conveyor = world.builds.add_conveyor(start, end)
	for i in 8:
		await get_tree().physics_frame
	player.global_position = Vector3(end.x - 2.5, 0.4, end.z)
	_aim(Vector3(end.x + 0.6, 0.0, end.z))
	for i in 4:
		await get_tree().physics_frame
	_aim(Vector3(end.x + 0.6, 0.0, end.z))
	tool._update_t_splitter_ghost()
	var ghost:= tool._t_splitter_ghost
	var c:= ghost.global_position
	_check("the ghost's centre is on a crossing (%.3f, %.3f)" % [c.x, c.z],
		absf(c.x - roundf(c.x)) < 0.001 and absf(c.z - roundf(c.z)) < 0.001)
	var off:= 0
	for lane: int in ConveyorTSplitter.LANES:
		var m:= ghost.to_global(ghost.mouth_of(lane))


		var across: float = m.z if absf(m.x - c.x) > absf(m.z - c.z) else m.x
		if absf(across - roundf(across)) > 0.001:
			off += 1
	_check("...and every lane runs down a grid line (%d off)" % off, off == 0)
	_check("...with a stub to the belt (%.2f m)" % (tool._t_stub [0].distance_to(tool._t_stub [1])
			if tool._t_stub.size() == 2 else -1.0),
		tool._t_stub.size() == 2
			and is_equal_approx(tool._t_stub [0].distance_to(tool._t_stub [1]), 0.5))
	_check("...priced with the machine ($%.0f over $%.0f)"
		% [float(tool._eval ["cost"]), Cfg.T_SPLITTER_COST],
		float(tool._eval ["cost"]) > Cfg.T_SPLITTER_COST)
	_check("...and it may be built there (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))

	tool._place_t_splitter()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var t:= _only_t()
	_check("built, its centre is on a crossing", t != null
		and absf(t.global_position.x - roundf(t.global_position.x)) < 0.001
		and absf(t.global_position.z - roundf(t.global_position.z)) < 0.001)
	if t == null:
		tool._grid_on = false
		await _clear()
		return
	var stub: Conveyor = world.builds.feed_run_into(t.port_in())
	_check("...with a belt laid into its feed lane", stub != null)


	_check("...fed along the lane the belt arrives by (%d)" % t.entry,
		stub != null and PointIndex.joins(stub.b, t.to_global(t.mouth_of(t.entry))))


	var outs: Array = []
	for side: int in ConveyorSplitter.SIDES:
		var mouth:= t.port(side)
		outs.append(world.builds.add_conveyor(mouth, mouth + t.arm_travel(side) * OUT_RUN))
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var rig:= await _wire(t, run, outs)
	var got:= await _flow(rig, "hay_wad", 6, 0.9)
	var through: int = got ["out"] [0] + got ["out"] [1]
	_check("...and 6 wads fed up the belt come out of the arms (%d: %d / %d, %d gone)"
		% [through, got ["out"] [0], got ["out"] [1], got ["gone"]],
		through == 6 and got ["gone"] == 0)
	tool._grid_on = false
	tool.set_active(false)
	await _clear()


func _three_lengths() -> void:
	print("\n=== three lengths in one save ===")
	var builds: BuildManager = world.builds
	var lengths: Array [float] = [Cfg.T_SPLITTER_PORT_R, Cfg.T_SPLITTER_PORT_R_V2,
		Cfg.T_SPLITTER_PORT_R_1M]
	for k in lengths.size():
		var t:= builds.add_t_splitter(_deck(CENTRE + Vector3(0.0, 0.0, -9.0 + 9.0 * k)), 0.0,
			ConveyorTSplitter.STEM, lengths [k])
		_run_into(t, ConveyorTSplitter.STEM)
		for side: int in ConveyorSplitter.SIDES:
			var mouth:= t.port(side)
			builds.add_conveyor(mouth, mouth + t.arm_travel(side) * OUT_RUN)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	builds.from_array(builds.to_array())
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	for r: float in lengths:
		var t: ConveyorTSplitter = null
		for s in builds.splitters:
			if s is ConveyorTSplitter and is_equal_approx((s as ConveyorTSplitter).port_r, r):
				t = s
		_check("the %.1f m T came back" % r, t != null)
		if t == null:
			continue
		_check("...on %s" % t._tbody._path.get_file(), t._tbody._path == ConveyorTBody.model_for(r))
		_check("...with its stem mouth %.1f out (%.3f)" % [r, t.port_in().distance_to(t.global_position)],
			is_equal_approx(t.port_in().distance_to(t.global_position), r))
		_check("...a belt still ending on its stem", builds.feed_run_into(t.port_in()) != null)
		_check("...and one still leaving each arm",
			builds.run_out_of(t.port(ConveyorSplitter.LEFT)) != null
				and builds.run_out_of(t.port(ConveyorSplitter.RIGHT)) != null)
		_check("...on six legs (%d)" % _legs(t), _legs(t) == 6)
	await _clear()


func _card_size_switch() -> void:
	print("\n=== the card's length switch ===")
	var was_override:= ConveyorTSplitter.placed_port_r
	var was_pick:= Cfg.t_splitter_port_r
	ConveyorTSplitter.placed_port_r = NAN
	Cfg.t_splitter_port_r = Cfg.T_SPLITTER_PORT_R
	var tool: BuildTool = player.build


	var had:= { }
	for id: String in ["t_splitter", "splitter"]:
		had [id] = int(Tech.ranks.get(id, 0))
		Tech.grant(id, 1)
	player.equip_build("t_splitter")
	_check("holding the T (%s)" % player.build_id, player.build_id == "t_splitter")
	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.T_SPLITTER)
	tool._reach = 14.0
	var at:= _deck(CENTRE + Vector3(3.0, 0.0, 0.0))
	player.global_position = Vector3(at.x - 4.0, 0.4, at.z)
	_aim(Vector3(at.x, 0.0, at.z))
	for i in 4:
		await get_tree().physics_frame
	_aim(Vector3(at.x, 0.0, at.z))
	tool._update_t_splitter_ghost()
	var ghost:= tool._t_splitter_ghost
	_check("holding the T, the ghost is the 1.5 m T (%.2f)" % ghost.port_r,
		is_equal_approx(ghost.port_r, Cfg.T_SPLITTER_PORT_R))

	Cfg.set_t_splitter_port_r(Cfg.T_SPLITTER_PORT_R_1M)
	tool._update_t_splitter_ghost()
	ghost = tool._t_splitter_ghost
	_check("switched to 1 m, the ghost is the 1 m T (%.2f)" % ghost.port_r,
		is_equal_approx(ghost.port_r, Cfg.T_SPLITTER_PORT_R_1M))
	_check("...on the 1 m model", ghost._tbody != null
		and ghost._tbody._path == ConveyorTBody.MODEL_1M)
	_check("...with its mouths 1 m out (%.3f)" % ghost.port_in().distance_to(ghost.global_position),
		is_equal_approx(ghost.port_in().distance_to(ghost.global_position), 1.0))
	var ghosts:= 0
	for n in tool.get_children():
		if n is ConveyorTSplitter and not n.is_queued_for_deletion():
			ghosts += 1
	_check("...and one ghost, not two (%d)" % ghosts, ghosts == 1)
	_check("...which may be built (%s)" % tool._eval ["reason"], bool(tool._eval ["ok"]))
	var builds: BuildManager = world.builds
	var before:= builds.splitters.size()
	tool._place_t_splitter()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var placed: ConveyorTSplitter = null
	if builds.splitters.size() == before + 1:
		placed = builds.splitters [builds.splitters.size() - 1] as ConveyorTSplitter
	_check("the click built a 1 m T (%.2f)" % (placed.port_r if placed != null else -1.0),
		placed != null and is_equal_approx(placed.port_r, Cfg.T_SPLITTER_PORT_R_1M))
	if placed != null:
		_check("...on the 1 m model", placed._tbody._path == ConveyorTBody.MODEL_1M)
		_check("...refunded at the T's price ($%.0f)" % placed.build_cost(),
			is_equal_approx(placed.build_cost(), Cfg.T_SPLITTER_COST))
		_check("...and copied back as the T at 1 m", builds.id_of(placed) == "t_splitter"
			and is_equal_approx(BuildTool._t_size_of(placed), Cfg.T_SPLITTER_PORT_R_1M))


	tool.set_active(true)
	tool.set_mode(BuildTool.Mode.T_SPLITTER)
	var press:= InputEventAction.new()
	press.action = "build_variant"
	press.pressed = true
	tool._unhandled_input(press)
	_check("the variant key goes on to another piece (%s)" % player.build_id,
		player.build_id != "t_splitter")
	_check("...and the length in hand is still 1 m",
		is_equal_approx(ConveyorTSplitter.size_in_hand(), Cfg.T_SPLITTER_PORT_R_1M))
	for id: String in had:
		Tech.grant(id, int(had [id]))
	tool.set_active(false)
	Cfg.t_splitter_port_r = was_pick
	ConveyorTSplitter.placed_port_r = was_override
	tool._make_t_splitter_ghost()
	await _clear()


func _only_t() -> ConveyorTSplitter:
	for s in world.builds.splitters:
		if s is ConveyorTSplitter and is_instance_valid(s):
			return s
	return null


func _save_checks() -> void:
	print("\n=== save ===")
	var t:= world.builds.add_t_splitter(_deck(CENTRE), PI * 0.5,
		ConveyorTSplitter.BAR_NEG) as ConveyorTSplitter
	var y: ConveyorSplitter = world.builds.add_splitter(_deck(CENTRE + Vector3(0.0, 0.0, -7.0)), 0.0)
	world.builds.add_u_splitter(_deck(CENTRE + Vector3(6.0, 0.0, -7.0)), 0.0)
	y.set_forced_side(ConveyorSplitter.RIGHT)
	t.set_priority_side(ConveyorSplitter.LEFT)
	var main_lane: int = ConveyorTSplitter.exits_of(t.entry) [ConveyorSplitter.LEFT]
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var data: Array = world.builds.to_array()
	var found:= { }
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("type", "") == "conveyor_t_splitter":
			found = entry
	_check("the T is written as a T", not found.is_empty())
	_check("...with its feed (%d)" % int(found.get("entry", -1)),
		int(found.get("entry", -1)) == ConveyorTSplitter.BAR_NEG)
	world.builds.from_array(data)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var ts: Array = []
	var ys:= 0
	var us:= 0
	for s in world.builds.splitters:
		if s is ConveyorTSplitter:
			ts.append(s)
		elif s is ConveyorUSplitter:
			us += 1
		else:
			ys += 1
	_check("it comes back as one T, one U and one Y (%d, %d, %d)" % [ts.size(), us, ys],
		ts.size() == 1 and us == 1 and ys == 1)
	if ts.size() == 1:
		var back:= ts [0] as ConveyorTSplitter
		_check("...fed along the same lane (%d)" % back.entry, back.entry == ConveyorTSplitter.BAR_NEG)
		_check("...with priority on the same lane",
			back.priority_side >= 0
				and ConveyorTSplitter.exits_of(back.entry) [back.priority_side] == main_lane)
		_check("...on the same spot (%.4f off)" % back.global_position.distance_to(_deck(CENTRE)),
			back.global_position.distance_to(_deck(CENTRE)) < 0.0001)
		var turn_pts:= 4 + ConveyorTSplitter.ARC_PIECES - 1
		var shapes:= [back.route(0)._line.size(), back.route(1)._line.size()]
		_check("...with one route turning and one straight (%s)" % str(shapes),
			shapes.has(turn_pts) and shapes.has(4))
		_check("...on six legs (%d)" % _legs(back), _legs(back) == 6)
	for s in world.builds.splitters:
		if not (s is ConveyorTSplitter) and not (s is ConveyorUSplitter):
			_check("the Y kept its pin (%d)" % s.forced_side, s.forced_side == ConveyorSplitter.RIGHT)
	var refund:= 0.0
	for s in world.builds.splitters.duplicate():
		if s is ConveyorTSplitter:
			refund = world.builds.demolish(s)
	_check("dismantling the T refunds its price ($%.0f)" % refund,
		is_equal_approx(refund, Cfg.T_SPLITTER_COST))
	await _clear()


const EVERY_KIND: Array [String] = ["hay_wad", "hay_bale", "foiled_bale",
	"eco_brick", "hay_pulp", "feed_disc", "paper_roll"]

const KIND_RANKS: Array [int] = [0, 9]

const KIND_SPACING:= 0.9


var _machine_fed:= false


func _every_kind() -> void:
	_machine_fed = true
	for rank in KIND_RANKS:
		Tech.grant("belt_speed", rank)
		var gap:= KIND_SPACING / Tech.belt_speed()
		print("\n=== every kind, belt motor rank %d, %.2f m/s ===" % [rank, Tech.belt_speed()])
		for kind in EVERY_KIND:
			for feed_lane: int in [ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_POS]:
				var rig:= await _rig(0.0, feed_lane)
				var r:= await _flow(rig, kind, 6, gap)
				var out: int = int(r ["out"] [0]) + int(r ["out"] [1])
				var label:= "split %s fed %s, rank %d" % [kind,
					["stem", "bar +", "bar -"] [feed_lane], rank]
				_check("%s: all out (%d of %d, %d / %d, %d gone), none on the floor (%d)"
					% [label, out, r ["fed"], r ["out"] [0], r ["out"] [1], r ["gone"], _loose(rig)],
					out == int(r ["fed"]) and int(r ["gone"]) == 0 and _loose(rig) == 0
						and int(r ["out"] [0]) > 0 and int(r ["out"] [1]) > 0)
				await _clear()
		var pairs: Array = []
		for kind in EVERY_KIND:
			pairs.append([kind, kind])
		pairs.append(["feed_disc", "foiled_bale"])
		pairs.append(["hay_wad", "foiled_bale"])
		pairs.append(["hay_wad", "feed_disc"])
		pairs.append(["eco_brick", "hay_bale"])
		for pair in pairs:
			for outlet: int in [ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_NEG]:
				await _merge_kinds(pair [0], pair [1], outlet, gap, rank)
	Tech.grant("belt_speed", 0)
	_machine_fed = false


func _both_arms_past_park() -> void:
	var builds: BuildManager = world.builds
	var placed:= builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
	var ins: Array [int] = []
	for lane: int in ConveyorTSplitter.LANES:
		if lane != ConveyorTSplitter.STEM:
			ins.append(lane)
	var feeds: Array = [_run_into(placed, ins [0])]
	await get_tree().physics_frame
	feeds.append(_run_into(builds.splitters [0] as ConveyorTSplitter, ins [1]))
	await get_tree().physics_frame
	if builds.joiners.size() != 1:
		_check("past park: it became a merge", false)
		await _clear()
		return
	var j:= builds.joiners [0] as ConveyorTJoiner
	var mouth:= j.port_out()
	builds.add_conveyor(mouth, mouth + j.forward() * OUT_RUN)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var reach:= 0.146
	var boarded:= 0
	for side in [ConveyorTJoiner.LEFT, ConveyorTJoiner.RIGHT]:
		var arm:= j.arm(side)
		var park:= j.park_s(side)

		var at:= park + (0.08 if side == ConveyorTJoiner.RIGHT else 0.27)
		if arm != null and arm.run.board(BeltRun.Kind.WAD, 197, 0, reach, 0.0, 0.0,
				minf(at, arm.run.length() - reach), 0.0, null, -1, false):
			boarded += 1
	_check("past park: a wad boarded past the line on each arm (%d)" % boarded, boarded == 2)
	var paths: Array = j.paths()
	var drained: bool = await _drain(paths, 6.0)
	var left:= []
	for p in paths:
		left.append("%s %d" % [(p as BeltPath).name, (p as BeltPath).run.count()])
	_check("past park: both wads crossed and the T emptied (%s)" % ", ".join(left), drained)
	await _clear()


func _merge_kinds(a: String, b: String, outlet: int, gap: float, rank: int) -> void:
	var builds: BuildManager = world.builds
	var placed:= builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
	var ins: Array [int] = []
	for lane: int in ConveyorTSplitter.LANES:
		if lane != outlet:
			ins.append(lane)
	var feeds: Array = [_run_into(placed, ins [0])]
	await get_tree().physics_frame
	feeds.append(_run_into(builds.splitters [0] as ConveyorTSplitter, ins [1]))
	await get_tree().physics_frame
	var label:= "merge %s + %s out lane %d, rank %d" % [a, b, outlet, rank]
	if builds.joiners.size() != 1:
		_check("%s: it became a merge" % label, false)
		await _clear()
		return
	var j:= builds.joiners [0] as ConveyorTJoiner
	var mouth:= j.port_out()
	var out_run: Conveyor = builds.add_conveyor(mouth, mouth + j.forward() * OUT_RUN)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var origin:= { }
	var caught:= { }
	out_run.caught_record.connect(func(seq: int, _kind: int, _strands: int) -> void:
		if origin.has(seq):
			caught [seq] = true)
	for k in 2:
		var feed:= feeds [k] as Conveyor
		feed.caught.connect(func(body: RigidBody3D) -> void:
			if body.collision_layer & Cfg.L_PROP:
				origin [feed.run.last_seq] = k)
	var kinds:= [a, b]
	var fed:= 0
	var step:= maxf(get_physics_process_delta_time(), 1e-06)


	var shake:= { "back": 0, "worst": 0.0, "where": "" }
	var watched: Array = j.paths()
	var last:= { }
	var sample:= func() -> void:
		var now:= { }
		for p in watched:
			var run: BeltRun = (p as BeltPath).run
			for i in range(run.first(), run.first() + run.count()):
				var key:= "%s:%d" % [(p as BeltPath).name, run.seq_of(i)]
				var s:= run.s_of(i)
				now [key] = s
				if not last.has(key):
					continue
				var moved: float = s - float(last [key])
				if moved < -1e-05:
					shake ["back"] += 1
					if - moved > float(shake ["worst"]):
						shake ["worst"] = - moved
						shake ["where"] = "%s s %.3f" % [key, s]
		last.clear()
		last.merge(now)
	get_tree().physics_frame.connect(sample)
	for i in 4:
		for k in 2:
			var feed:= feeds [k] as Conveyor
			var body:= world.props.spawn(kinds [k], Transform3D(Basis(Vector3.UP,
				atan2(feed.forward.x, feed.forward.z)),
				feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0))) as RigidBody3D
			if body != null:
				BeltPath.mark_machine_throw(body)
				fed += 1
				_every_prop.append(body)
		for f in int(gap / step):
			await get_tree().physics_frame
	var paths: Array = feeds.duplicate()
	paths.append_array(j.paths())
	var drained: bool = await _drain(paths, DRAIN_LIMIT)
	for f in int(belt_secs(OUT_RUN + 1.0) / step):
		await get_tree().physics_frame
	var loose:= 0
	for body in _prop_bodies():
		if not BeltPath.is_rider(body) and body.global_position.distance_to(j.global_position) < 2.5:
			loose += 1
	var from:= [0, 0]
	for seq in caught:
		from [int(origin [seq])] += 1
	_check("%s: every load merged (%d of %d, %d / %d), the T emptied (%s), none on the floor (%d)"
		% [label, caught.size(), fed, from [0], from [1], drained, loose],
		caught.size() == fed and drained and loose == 0)
	get_tree().physics_frame.disconnect(sample)
	_check("%s: nothing stepped back (%d, worst %.3f) %s"
		% [label, shake ["back"], shake ["worst"], shake ["where"]],
		int(shake ["back"]) == 0)
	if not drained:
		for p in paths:
			var bp:= p as BeltPath
			print("    %s held %s outlet_held %s records %d riders %d"
				% [bp.name, bp.hold_line(), bp.run.outlet_held, bp.run.count(), bp.riders().size()])
			for m in bp.load_marks():
				print("      s %.2f reach %.2f" % [float(m ["s"]), float(m ["reach"])])
	await _clear()


func _merging() -> void:
	for outlet: int in [ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_NEG]:
		print("\n=== merging into lane %d ===" % outlet)
		var builds: BuildManager = world.builds
		var placed:= builds.add_t_splitter(_deck(CENTRE), 0.0) as ConveyorTSplitter
		var ins: Array [int] = []
		for lane: int in ConveyorTSplitter.LANES:
			if lane != outlet:
				ins.append(lane)
		var feed_a:= _run_into(placed, ins [0])
		await get_tree().physics_frame
		_check("one belt in: still a splitter, fed by lane %d" % ins [0],
			builds.splitters.size() == 1 and builds.joiners.is_empty()
				and (builds.splitters [0] as ConveyorTSplitter).entry == ins [0])
		var t0:= builds.splitters [0] as ConveyorTSplitter


		var added: Array [Node] = []
		var catch:= func(n: Node) -> void: added.append(n)
		builds.child_entered_tree.connect(catch)
		var feed_b:= _run_into(t0, ins [1])
		builds.child_entered_tree.disconnect(catch)
		var tool: BuildTool = player.build
		var shows: BuildFx = tool.show_built(added)
		var shown_t:= false
		var shown_belt:= false
		if shows != null:
			for target in shows._targets:
				shown_t = shown_t or target is ConveyorTJoiner or target is ConveyorTSplitter
				shown_belt = shown_belt or target == feed_b
		_check("laying the second belt plays the build show on the belt and not on the T (belt %s, T %s)"
			% [shown_belt, shown_t], shown_belt and not shown_t)
		await get_tree().physics_frame
		var j: ConveyorTJoiner = null
		if builds.joiners.size() == 1:
			j = builds.joiners [0] as ConveyorTJoiner
		_check("a second belt in turns it into a merge (%d splitters, %d joiners)"
			% [builds.splitters.size(), builds.joiners.size()],
			j != null and builds.splitters.is_empty())
		if j == null:
			await _clear()
			continue
		_check("...leaving by lane %d (%d)" % [outlet, j.out_lane], j.out_lane == outlet)
		_check("...on the same spot and bearing",
			j.global_position.is_equal_approx(_deck(CENTRE)) and absf(j.global_rotation.y) < 0.0001)
		_check("...still named the T splitter (%s)" % builds.name_of(j),
			builds.name_of(j) == BuildCatalog.display_name("t_splitter"))
		var mouth:= j.port_out()
		var out_run: Conveyor = builds.add_conveyor(mouth, mouth + j.forward() * OUT_RUN)
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
		_check("...and a belt out keeps it a merge",
			builds.joiners.size() == 1 and builds.joiners [0] == j)
		_check("both belts in hand to its arms",
			(feed_a.downstream == j.arm(0) or feed_a.downstream == j.arm(1))
				and (feed_b.downstream == j.arm(0) or feed_b.downstream == j.arm(1)))
		_check("its outlet hands to the belt out", j.out_path().downstream == out_run)
		_check("every rubber surface runs with its lane (%d faults)" % _scroll_faults_of(j),
			_scroll_faults_of(j) == 0)


		var origin:= { }
		var order: Array [int] = []
		var caught:= { }
		var changed:= [0]
		var out_frames: Array [int] = []
		out_run.caught_record.connect(func(seq: int, _kind: int, strands: int) -> void:
			if not origin.has(seq) or caught.has(seq):
				return
			caught [seq] = true
			order.append(int(origin [seq]))
			out_frames.append(Engine.get_physics_frames())
			if _strands_by_seq.has(seq) and int(_strands_by_seq [seq]) != strands:
				changed [0] += 1)
		_fed.clear()
		_fed_ids.clear()
		_strands.clear()
		_seq_of.clear()
		_strands_by_seq.clear()
		var swung:= 0
		var overlaps:= 0
		var gate_wrong:= 0
		var past:= { }
		var step:= maxf(get_physics_process_delta_time(), 1e-06)
		var feeds:= [feed_a, feed_b]
		for k in 2:
			var feed:= feeds [k] as Conveyor
			feed.caught.connect(func(b: RigidBody3D) -> void:
				if b is HayWad:
					origin [feed.run.last_seq] = k)
		for i in 5:
			for k in 2:
				var feed:= feeds [k] as Conveyor
				var body:= world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP,
					atan2(feed.forward.x, feed.forward.z)),
					feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0))) as RigidBody3D
				if body != null:
					_fed.append(body)
					_fed_ids.append(body.get_instance_id())
					_every_prop.append(body)
					_strands [body.get_instance_id()] = (body as Carryable).hay_strands()
			for f in int(1.1 / step):
				var faults: Array = await _watch_merge(j, past)
				swung += int(faults [0])
				overlaps += int(faults [1])
				gate_wrong += int(faults [2])
		for f in int(belt_secs(DRAIN_LIMIT) / step):
			var faults: Array = await _watch_merge(j, past)
			swung += int(faults [0])
			overlaps += int(faults [1])
			gate_wrong += int(faults [2])
			if caught.size() >= _fed.size():
				break
		var from:= [0, 0]
		var longest:= 0
		var run_len:= 0
		for n in order.size():
			from [order [n]] += 1
			run_len = run_len + 1 if n > 0 and order [n] == order [n - 1] else 1
			longest = maxi(longest, run_len)
		print("  out in order: %s" % str(order))
		_check("every wad came out, once and whole (%d of %d, %d changed)"
			% [caught.size(), _fed.size(), changed [0]],
			caught.size() == _fed.size() and changed [0] == 0)
		_check("...from both lines (%d / %d)" % [from [0], from [1]], from [0] == 5 and from [1] == 5)
		_check("...taken in turn (longest run from one line %d)" % longest, longest <= 2)
		var merge_gap:= 0.0
		for n in range(1, out_frames.size()):
			merge_gap += float(out_frames [n] - out_frames [n - 1]) / Engine.physics_ticks_per_second
		print("  merged a wad every %.2f s (fed two every 1.10 s)"
			% (merge_gap / maxf(out_frames.size() - 1, 1.0)))


		print("  steel swung through a load on %d ticks" % swung)
		_check("no two loads rode inside each other on the way out (%d ticks)" % overlaps,
			overlaps == 0)
		print("  loads past their park line with the steel not yet round: %d" % gate_wrong)


		var data: Array = builds.to_array()
		var entry:= { }
		for d in data:
			if typeof(d) == TYPE_DICTIONARY and (d as Dictionary).get("type", "") == "conveyor_t_joiner":
				entry = d
		_check("it saves as a merging T, leaving by lane %d" % int(entry.get("out_lane", -1)),
			not entry.is_empty() and int(entry.get("out_lane", -1)) == outlet)
		builds.from_array(data)
		for i in 8:
			await get_tree().physics_frame
		_check("...and loads as one (%d joiners, %d splitters, out %d)"
			% [builds.joiners.size(), builds.splitters.size(),
				(builds.joiners [0] as ConveyorTJoiner).out_lane if builds.joiners.size() == 1 else -1],
			builds.joiners.size() == 1 and builds.splitters.is_empty()
				and builds.joiners [0] is ConveyorTJoiner
				and (builds.joiners [0] as ConveyorTJoiner).out_lane == outlet)
		var second: Conveyor = null
		for c in builds.conveyors:
			var tj:= builds.joiners [0] as ConveyorTJoiner
			if c.b.is_equal_approx(tj.to_global(ConveyorTSplitter.lane_mouth(ins [1], tj.port_r))):
				second = c
		if second != null:
			builds.demolish(second)
		await get_tree().physics_frame
		_check("with one belt in again it is a splitter fed by lane %d (%d splitters, %d joiners)"
			% [ins [0], builds.splitters.size(), builds.joiners.size()],
			builds.splitters.size() == 1 and builds.joiners.is_empty()
				and (builds.splitters [0] as ConveyorTSplitter).entry == ins [0])
		await _clear()


func _watch_merge(j: ConveyorTJoiner, past: Dictionary) -> Array:
	var before:= j.arm_angle()
	await get_tree().physics_frame
	var out:= [0, 0, 0]
	if not is_instance_valid(j):
		return out
	var after:= j.arm_angle()
	var marks: Array [Dictionary] = []
	for side: int in ConveyorJoiner.SIDES:
		for m in j.arm(side).load_marks():
			if not bool(m ["prop"]):
				continue
			var id: int = m ["id"]
			if float(m ["s"]) > j.park_s(side) + 0.002:
				marks.append(m)
				if not past.has(id):
					past [id] = true
					if not is_equal_approx(after, j._angle_for(side)):
						out [2] += 1
	var on_out:= j.out_path().load_marks()
	for m in on_out:
		if bool(m ["prop"]):
			marks.append(m)
	if not is_equal_approx(before, after):
		for m in marks:
			var p:= j.to_local(m ["pos"] as Vector3)
			if ConveyorTSplitter.in_sweep(p, float(m ["reach"]) * 0.9, before, after):
				out [0] += 1
	for a in on_out.size():
		for b in range(a + 1, on_out.size()):
			var ma: Dictionary = on_out [a]
			var mb: Dictionary = on_out [b]
			if absf(float(ma ["s"]) - float(mb ["s"])) < (float(ma ["reach"]) + float(mb ["reach"])) * 0.9:
				out [1] += 1
	return out


func _scroll_faults_of(j: ConveyorTJoiner) -> int:
	var faults:= 0
	for r: Dictionary in j.body().rubber:
		var mi:= r ["mesh"] as MeshInstance3D
		var mat:= mi.get_surface_override_material(int(r ["surface"]))
		var travel:= j._lane_travel(int(r ["lane"]))
		var run: Vector2 = r ["run"]
		var along:= run.x * travel.x + run.y * travel.z
		var sign_:= 1.0 if mat == ConveyorKit.belt_material() else -1.0
		if along * sign_ <= 0.0:
			faults += 1
	return faults


func _deck(at: Vector3) -> Vector3:
	return at + Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)


func _run_into(t: ConveyorTSplitter, lane: int) -> Conveyor:
	var mouth:= t.to_global(t.mouth_of(lane))
	var out:= (t.global_basis * ConveyorTSplitter.lane_out(lane)).normalized()
	var feed: Conveyor = world.builds.add_conveyor(mouth + out * FEED_RUN, mouth)
	if feed != null:
		feed.caught.connect(_on_feed_caught.bind(feed))
	return feed


func _on_feed_caught(body: RigidBody3D, feed: Conveyor) -> void:
	if not (body.collision_layer & Cfg.L_PROP) or BeltPath.record_kind(body) < 0:
		return
	var seq: int = feed.run.last_seq
	_seq_of [body.get_instance_id()] = seq
	_strands_by_seq [seq] = (body as Carryable).hay_strands()


func _rig(yaw: float, feed: int) -> Dictionary:
	var t:= world.builds.add_t_splitter(_deck(CENTRE), yaw) as ConveyorTSplitter
	var into:= _run_into(t, feed)
	var outs: Array = []
	for side: int in ConveyorSplitter.SIDES:
		var mouth:= t.port(side)
		outs.append(world.builds.add_conveyor(mouth, mouth + t.arm_travel(side) * OUT_RUN))
	return await _wire(t, into, outs)


func _wire(t: ConveyorTSplitter, into: Conveyor, outs: Array) -> Dictionary:
	var heard:= _on_feed_caught.bind(into)
	if not into.caught.is_connected(heard):
		into.caught.connect(heard)
	for side: int in ConveyorSplitter.SIDES:
		t.route(side).caught.connect(_on_route_caught.bind(side))
		t.route(side).caught_record.connect(_on_route_caught_record.bind(side))
		(outs [side] as Conveyor).caught.connect(_on_out_caught.bind(side))
		(outs [side] as Conveyor).caught_record.connect(_on_out_caught_record.bind(side))
	_follow_reroutes(t)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	return { "t": t, "feed": into, "outs": outs }


func _on_route_caught(body: RigidBody3D, side: int) -> void:
	if body.collision_layer & Cfg.L_PROP:
		_route_side [body.get_instance_id()] = side


func _on_route_caught_record(seq: int, _kind: int, _strands: int, side: int) -> void:
	_route_side [seq] = side


func _on_rerouted_record(seq: int, side: int) -> void:
	_route_side [seq] = side


func _follow_reroutes(t: ConveyorTSplitter) -> void:
	if t.has_signal("rerouted"):
		t.connect("rerouted", _on_route_caught)
	if t.has_signal("rerouted_record"):
		t.connect("rerouted_record", _on_rerouted_record)


func _on_out_caught(body: RigidBody3D, side: int) -> void:
	if not (body.collision_layer & Cfg.L_PROP):
		return
	var id:= body.get_instance_id()
	if _fed_ids.has(id) and not _out_side.has(id):
		_out_side [id] = side
		_out_frames_at.append(Engine.get_physics_frames())


func _on_out_caught_record(seq: int, _kind: int, strands: int, side: int) -> void:
	if _out_side.has(seq):
		return
	_out_side [seq] = side
	_out_frames_at.append(Engine.get_physics_frames())
	if _strands_by_seq.has(seq) and int(_strands_by_seq [seq]) != strands:
		_changed += 1


func _flow(rig: Dictionary, kind: String, count: int, gap: float,
		drain: bool = true, fresh: bool = true) -> Dictionary:


	if fresh:
		_route_side.clear()
		_out_side.clear()
		_fed.clear()
		_fed_ids.clear()
		_strands.clear()
		_seq_of.clear()
		_strands_by_seq.clear()
		_changed = 0
		_swung_through = 0
		_closed_ahead = 0
		_parked_ticks = 0
		_arm_ticks = 0
		_limbo_ticks = 0
		_limbo_run = 0
		_unassigned = 0
		_hold_frames = 0
		_out_frames = 0
	var t: ConveyorTSplitter = rig ["t"]
	var feed:= rig ["feed"] as Conveyor
	var at:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	for i in count:
		var body:= world.props.spawn(kind, Transform3D(Basis(Vector3.UP,
			atan2(feed.forward.x, feed.forward.z)), at)) as RigidBody3D
		if body != null:
			if _machine_fed:
				BeltPath.mark_machine_throw(body)
			_fed.append(body)
			_fed_ids.append(body.get_instance_id())
			_every_prop.append(body)
			_strands [body.get_instance_id()] = (body as Carryable).hay_strands()
		for k in int(gap / step):
			await _watch(t)
			_out_frames += 1
	var limit:= int(belt_secs(DRAIN_LIMIT) / step) if drain else int(belt_secs(9.0) / step)
	for k in limit:
		await _watch(t)
		_out_frames += 1
		if drain and _out_side.size() >= _fed.size():
			break


	for k in int(belt_secs(OUT_RUN + 1.0) / step):
		await _watch(t)
	return _tally(rig)


func _settle_flow(before: Dictionary) -> Dictionary:
	var rig: Dictionary = before ["rig"]
	var t: ConveyorTSplitter = rig ["t"]
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	for k in int(belt_secs(DRAIN_LIMIT) / step):
		await _watch(t)
		if _out_side.size() >= _fed.size():
			break
	for k in int(belt_secs(OUT_RUN + 1.0) / step):
		await _watch(t)
	return _tally(rig)


func _tally(rig: Dictionary) -> Dictionary:
	var aboard:= [0, 0]
	for id in _route_side:
		aboard [int(_route_side [id])] += 1
	var out:= [0, 0]
	var strayed:= 0
	for id in _out_side:
		out [int(_out_side [id])] += 1
		if _route_side.has(id) and int(_route_side [id]) != int(_out_side [id]):
			strayed += 1


	var gone:= 0
	for k in _fed.size():
		if _seq_of.has(_fed_ids [k]):
			continue
		var body = _fed [k]
		if is_instance_valid(body) and (body as Node).is_inside_tree():
			continue
		gone += 1
	return { "rig": rig, "fed": _fed.size(), "aboard": aboard, "out": out,
		"strayed": strayed, "changed": _changed, "gone": gone,
		"swung": _swung_through, "closed": _closed_ahead,
		"parked": _parked_ticks, "ticks": _arm_ticks, "limbo": _limbo_ticks,
		"held_s": _hold_frames * get_physics_process_delta_time(),
		"took_s": _out_frames * get_physics_process_delta_time(), "unassigned": _unassigned }


func _watch(t: ConveyorTSplitter) -> void:
	var before:= t.arm_angle()
	await get_tree().physics_frame
	if not is_instance_valid(t):
		return
	for side: int in ConveyorSplitter.SIDES:
		for rider in t.route(side)._riders:
			_route_speed_max = maxf(_route_speed_max, float(rider.speed))
		var run:= t.route(side).run
		for i in range(run.first(), run.first() + run.count()):
			_route_speed_max = maxf(_route_speed_max, run.speed_of(i))
	_watch_lane(t)
	if t.is_holding():
		_hold_frames += 1
		var lead: Dictionary = { }
		for side: int in ConveyorSplitter.SIDES:
			for m in t.route(side).load_marks():
				var front:= float(m ["s"]) + float(m ["reach"])
				if front > t.hold_s() + BeltPath.HOLD_SLACK:
					continue
				if lead.is_empty() or front > float(lead ["s"]) + float(lead ["reach"]):
					lead = m
					lead ["side"] = side
		if not lead.is_empty():
			var ls:= int(lead ["side"])
			if not is_equal_approx(t.arm_angle(), ConveyorTSplitter.blade_angle(t.entry,
					ConveyorTSplitter.exits_of(t.entry) [ls])):
				var key:= "arm swinging" if absf(float(t._gate_speed)) > 0.0 else "arm waiting for the ground to clear"
				_why [key] = int(_why.get(key, 0)) + 1
			elif not t._arm_has_room_for(ls, float(lead ["reach"])):
				_why ["no room on the arm"] = int(_why.get("no room on the arm", 0)) + 1
				if not _why.has("sample"):
					var dir:= t.arm_travel(ls)
					var near:= minf(float(t._clear [ls]) + float(lead ["reach"]), t.port_r - 0.05)
					var riders:= []
					for m in t.route(ls).load_marks():
						riders.append("s %.2f reach %.2f" % [float(m ["s"]), float(m ["reach"])])
					_why ["sample"] = "hold_s %.2f clear %.2f reach %.2f near s %.2f far s %.2f riders %s" % [
						t.hold_s(), float(t._clear [ls]), float(lead ["reach"]),
						t.route(ls).s_near(t.global_position + dir * near),
						t.route(ls).s_near(t.global_position + dir * minf(near + float(lead ["reach"]) + Cfg.BELT_RIDE_SPACING, t.port_r - 0.05)),
						str(riders)]
			else:
				_why ["other"] = int(_why.get("other", 0)) + 1
	var after:= t.arm_angle()
	_arm_ticks += 1
	if t.arm_parked():
		_parked_ticks += 1
	var moved:= not is_equal_approx(before, after)
	var named:= absf(after) >= Cfg.T_SPLITTER_PARK - 0.01
	for side: int in ConveyorSplitter.SIDES:
		named = named or is_equal_approx(after,
			ConveyorTSplitter.blade_angle(t.entry, ConveyorTSplitter.exits_of(t.entry) [side]))
	if moved or named:
		_limbo_run = 0
	else:
		_limbo_run += 1
		if _limbo_run > LIMBO_RUN:
			_limbo_ticks += 1
	var marks: Array [Dictionary] = []
	for side: int in ConveyorSplitter.SIDES:
		for m in t.route(side).load_marks():
			m ["side"] = side
			marks.append(m)
	var arms:= ConveyorTSplitter.exits_of(t.entry)
	for m in marks:
		if not bool(m ["prop"]):
			continue
		var p:= t.to_local(m ["pos"] as Vector3)
		var reach:= float(m ["reach"])
		if moved and float(m ["s"]) + reach > t.hold_s() + BeltPath.HOLD_SLACK and ConveyorTSplitter.in_sweep(p, reach * 0.9, before, after):
			_swung_through += 1


		var side:= int(m ["side"])
		if float(m ["s"]) + reach > t.hold_s() + BeltPath.HOLD_SLACK and not is_equal_approx(after, ConveyorTSplitter.blade_angle(t.entry, arms [side])) and ConveyorTSplitter.in_sweep(p, reach * 0.9, after, after):
			_closed_ahead += 1


	for m in marks:
		if not bool(m ["prop"]):
			continue
		var p:= t.to_local(m ["pos"] as Vector3)
		var key: int = int(m ["seq"]) if m ["body"] == null else (m ["body"] as Object).get_instance_id()
		if absf(p.x) < ConveyorTSplitter.JUNCTION_HALF and absf(p.z) < ConveyorTSplitter.JUNCTION_HALF and absf(p.y) < 0.6 and not _route_side.has(key):
			_unassigned += 1
	for body in _fed:
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		var p:= t.to_local(body.global_position)
		if absf(p.x) < ConveyorTSplitter.JUNCTION_HALF and absf(p.z) < ConveyorTSplitter.JUNCTION_HALF and absf(p.y) < 0.6 and not _route_side.has(body.get_instance_id()):
			_unassigned += 1


func _expect_split(r: Dictionary, label: String, left: int, right: int) -> void:
	print("  %s: fed %d, aboard %d / %d, out %d / %d, held %.2f s, all out in %.2f s"
		% [label, r ["fed"], r ["aboard"] [0], r ["aboard"] [1], r ["out"] [0], r ["out"] [1],
			r ["held_s"], r ["took_s"]])
	_check("%s: %d left, %d right (want %d, %d)" % [label, r ["out"] [0], r ["out"] [1], left, right],
		int(r ["out"] [0]) == left and int(r ["out"] [1]) == right)
	_expect_whole(r, label)


func _expect_whole(r: Dictionary, label: String) -> void:
	var out: int = int(r ["out"] [0]) + int(r ["out"] [1])
	_check("%s: every load left by an arm, once and whole (%d of %d out, %d strayed, %d changed, %d gone)"
		% [label, out, r ["fed"], r ["strayed"], r ["changed"], r ["gone"]],
		out == int(r ["fed"]) and int(r ["strayed"]) == 0 and int(r ["changed"]) == 0
			and int(r ["gone"]) == 0)


	print("  %s: the arm swung through a load on %d ticks, closed in front of one on %d, folded open on %d of %d"
		% [label, r ["swung"], r ["closed"], r ["parked"], r ["ticks"]])


	_check("%s: the arm was never left at an angle that names no lane (%d ticks)"
		% [label, r ["limbo"]], int(r ["limbo"]) == 0)
	_check("%s: no load reached the junction without an arm (%d ticks)" % [label, r ["unassigned"]],
		int(r ["unassigned"]) == 0)


func _loose(rig: Dictionary) -> int:
	var t: ConveyorTSplitter = rig ["t"]
	var feed:= rig ["feed"] as Conveyor
	var n:= 0
	for body in _prop_bodies():
		if BeltPath.is_rider(body):
			continue
		var p:= body.global_position
		var near_t:= Vector2(p.x - t.global_position.x, p.z - t.global_position.z).length() < t.port_r + 1.0
		var on_feed:= Geometry3D.get_closest_point_to_segment(p, feed.a, feed.b).distance_to(p) < 1.2
		if near_t or on_feed:
			n += 1
	return n


func _prop_bodies() -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []
	for item in world.props.items:
		if not is_instance_valid(item) or not item.is_inside_tree():
			continue
		if BeltPath.record_kind(item as RigidBody3D) >= 0:
			out.append(item as RigidBody3D)
	return out


func _drain(paths: Array, limit: float) -> bool:
	var ticks:= int(belt_secs(limit) / maxf(get_physics_process_delta_time(), 1e-06))
	for i in ticks:
		await get_tree().physics_frame
		var busy:= false
		for entry in paths:
			var path:= entry as BeltPath
			if path != null and is_instance_valid(path) and (not path.riders().is_empty() or path.run.count() > 0):
				busy = true
				break
		if not busy:
			return true
	return false


func _clear() -> void:
	world.builds.from_array([])
	for body in _every_prop:
		if is_instance_valid(body) and body.is_inside_tree() and body is Carryable:
			world.props.remove(body as Carryable)
	for body in _prop_bodies():
		world.props.remove(body as Carryable)
	_every_prop.clear()
	_fed.clear()
	_fed_ids.clear()
	for i in 8:
		await get_tree().physics_frame


func _legs(wye: Node3D) -> int:
	var mmi:= wye.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		return -1
	return mmi.multimesh.instance_count


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("T SPLITTER PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)
