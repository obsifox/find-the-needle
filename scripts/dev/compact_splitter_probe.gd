class_name DevCompactSplitterProbe
extends Node


var world: Node3D
var _failed:= 0


func _check(label: String, ok: bool) -> void:
	print("[compact splitter] %s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		_failed += 1


func run() -> void:
	Cfg.build_fx = true
	var builds: BuildManager = world.builds
	var y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var caught: Array [Node] = []
	var catch:= func(n: Node) -> void: caught.append(n)
	builds.child_entered_tree.connect(catch)
	var standard: ConveyorCompactSplitter = builds.add_compact_splitter(
		Vector3(60.0, y, 60.0), 0.0)
	var smart: ConveyorCompactSplitter = builds.add_compact_splitter(
		Vector3(66.0, y, 60.0), 0.0, true)
	builds.child_entered_tree.disconnect(catch)
	_check("standard has four ports", standard.ports().size() == 4)
	_check("standard has three routes", standard.routes().size() == 3)
	_check("smart model mode is set", smart.smart)


	await get_tree().physics_frame
	await get_tree().physics_frame
	for pair: Array in [["standard", standard], ["smart", smart]]:
		var who: ConveyorCompactSplitter = pair [1]
		var box:= who.model_box()
		var at:= who.global_position
		var space:= world.get_world_3d().direct_space_state
		var down:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0,
			at + Vector3.DOWN * 1.0, Cfg.L_BUILD)
		var roof:= space.intersect_ray(down)

		var side:= at + Vector3(0.0, box.get_center().y, 3.0)
		var across:= PhysicsRayQueryParameters3D.create(side, at, Cfg.L_BUILD)
		var wall:= space.intersect_ray(across)
		var roof_y:= (roof.get("position", Vector3.ZERO) as Vector3).y - at.y
		var wall_z:= (wall.get("position", Vector3.ZERO) as Vector3).z - at.z
		_check("%s stops a ray on its roof (%.2f of %.2f)" % [pair [0], roof_y, box.end.y],
			not roof.is_empty() and absf(roof_y - box.end.y) < 0.02)
		_check("%s stops a ray at its back wall (%.2f of %.2f)"
			% [pair [0], wall_z, box.end.z],
			not wall.is_empty() and absf(wall_z - box.end.z) < 0.02)


	_check("compact splitter has its own node", TechTree.has_id("compact_splitter")
		and BuildCatalog.unlock_of("compact_splitter") == "compact_splitter")
	_check("smart splitter has its own node after the compact one",
		TechTree.has_id("smart_splitter")
		and BuildCatalog.unlock_of("smart_splitter") == "smart_splitter"
		and TechTree.requires("smart_splitter") == ["compact_splitter"])
	_check("both cost more than a T splitter",
		standard.build_cost() > Cfg.T_SPLITTER_COST * 2.0
		and smart.build_cost() > standard.build_cost())

	_check("both have build menu and tech tree icons",
		CatalogPanel.icon_for("compact_splitter") != null
		and CatalogPanel.icon_for("smart_splitter") != null
		and TechPanel.icon_for("compact_splitter") != null
		and TechPanel.icon_for("smart_splitter") != null)


	_check("only the smart one opens the panel",
		not standard.has_panel() and smart.has_panel())
	_check("no door numbers until the panel opens",
		smart.find_children("DoorNumber*", "Label3D", true, false).is_empty())
	smart.show_door_tags(true)
	var numbers:= smart.find_children("DoorNumber*", "Label3D", true, false)
	_check("opening shows one floating number per door (%d)" % numbers.size(),
		numbers.size() == 3)
	var door2_was:= smart.filter_for(ConveyorCompactSplitter.OUT_FORWARD)
	smart.set_filter(ConveyorCompactSplitter.OUT_FORWARD, ConveyorCompactSplitter.RULE_NONE)
	var shut_tag:= smart.find_child("DoorNumber2", true, false) as Label3D
	_check("a shut door's tag carries a cross",
		shut_tag != null and shut_tag.text.contains("×"))
	smart.set_filter(ConveyorCompactSplitter.OUT_FORWARD, door2_was)
	smart.show_door_tags(false)
	await get_tree().process_frame
	_check("closing takes the numbers away",
		smart.find_children("DoorNumber*", "Label3D", true, false).is_empty())
	standard.show_door_tags(true)
	_check("standard doors carry no numbers",
		standard.find_children("DoorNumber*", "Label3D", true, false).is_empty())


	var fx: BuildFx = world.player.build.show_built(caught)
	await get_tree().process_frame
	await get_tree().process_frame
	var worn:= 0
	if fx != null:
		for g in BuildFx.meshes_of(smart):
			if g.material_override == fx._mat or g.material_overlay == fx._mat:
				worn += 1
	_check("build show is on the smart splitter's model (%d meshes)" % worn,
		fx != null and worn > 0)


	for side in ConveyorCompactSplitter.OUTPUTS:
		var mouth:= smart.port(side)
		var dir:= smart.arm_travel(side)
		dir.y = 0.0
		builds.add_conveyor(mouth, mouth + dir.normalized() * 3.0)
	_check("a door with no belt takes nothing",
		standard._choose_output(BeltRun.Kind.BALE) == -1)


	smart.set_filter(ConveyorCompactSplitter.OUT_LEFT, BeltRun.Kind.BALE)
	smart.set_filter(ConveyorCompactSplitter.OUT_FORWARD, ConveyorCompactSplitter.RULE_ANY)
	smart.set_filter(ConveyorCompactSplitter.OUT_RIGHT, ConveyorCompactSplitter.RULE_OVERFLOW)
	_check("exact item rule wins", smart._choose_output(BeltRun.Kind.BALE)
		== ConveyorCompactSplitter.OUT_LEFT)
	_check("any takes an unmatched item", smart._choose_output(BeltRun.Kind.BRICK)
		== ConveyorCompactSplitter.OUT_FORWARD)
	smart.set_filter(ConveyorCompactSplitter.OUT_FORWARD, ConveyorCompactSplitter.RULE_NONE)
	smart.set_filter(ConveyorCompactSplitter.OUT_RIGHT, ConveyorCompactSplitter.RULE_NONE)
	_check("a load no door takes is held", smart._choose_output(BeltRun.Kind.BRICK) == -1)
	_check("a named load still leaves by its door", smart._choose_output(BeltRun.Kind.BALE)
		== ConveyorCompactSplitter.OUT_LEFT)


	_check("a strand leaves by the open door",
		smart._choose_output(-1) == ConveyorCompactSplitter.OUT_LEFT)
	_check("a tuft leaves by the open door",
		smart._choose_output(BeltRun.Kind.TUFT) == ConveyorCompactSplitter.OUT_LEFT)
	_check("the throat unjam agrees a strand may use that door",
		smart._door_takes(ConveyorCompactSplitter.OUT_LEFT, -1))
	_check("a shut door still refuses a strand",
		not smart._door_takes(ConveyorCompactSplitter.OUT_FORWARD, -1))
	smart.set_filter(ConveyorCompactSplitter.OUT_LEFT, BeltRun.Kind.TUFT)
	_check("a door named for tufts gets them by name",
		smart._choose_output(BeltRun.Kind.TUFT) == ConveyorCompactSplitter.OUT_LEFT)
	smart.set_filter(ConveyorCompactSplitter.OUT_LEFT, ConveyorCompactSplitter.RULE_NONE)
	_check("every door shut holds even a strand", smart._choose_output(-1) == -1)
	smart.set_filter(ConveyorCompactSplitter.OUT_LEFT, BeltRun.Kind.BALE)


	var tuft:= HayTuft.new()
	_check("a tuft body reads as a hay tuft",
		BeltPath.filter_kind(tuft) == BeltRun.Kind.TUFT)
	_check("a tuft body still does not board as a record",
		BeltPath.record_kind(tuft) < 0)
	tuft.free()


	smart.set_filter(ConveyorCompactSplitter.OUT_RIGHT, ConveyorCompactSplitter.RULE_OVERFLOW)
	var hint:= BuildTool.wye_hint_chains(smart)
	var shades: PackedFloat32Array = hint ["alphas"]
	_check("smart hint: inlet, the bale door, the overflow door faint (%s)" % [shades],
		(hint ["chains"] as Array).size() == 3 and shades [0] == 1.0 and shades [1] == 1.0
		and is_equal_approx(shades [2], BuildTool.WYE_HINT_SPILL))
	hint = BuildTool.wye_hint_chains(standard)
	shades = hint ["alphas"]
	_check("standard hint with no belts: only a faint inlet (%s)" % [shades],
		shades.size() == 1 and is_equal_approx(shades [0], BuildTool.WYE_HINT_SPILL))
	var wye:= builds.add_splitter(Vector3(60.0, y, 90.0), 0.0)
	_check("Y hint on alternate draws all three routes",
		BuildTool.wye_hint_chains(wye) ["alphas"] == PackedFloat32Array([1.0, 1.0, 1.0]))
	wye.set_forced_side(ConveyorSplitter.LEFT)
	_check("Y hint pinned left leaves the right arm out",
		BuildTool.wye_hint_chains(wye) ["alphas"] == PackedFloat32Array([1.0, 1.0]))
	wye.set_priority_side(ConveyorSplitter.RIGHT)
	_check("Y hint with the right arm main draws the left one faint",
		BuildTool.wye_hint_chains(wye) ["alphas"]
		== PackedFloat32Array([1.0, BuildTool.WYE_HINT_SPILL, 1.0]))
	var joiner:= builds.add_joiner(Vector3(66.0, y, 90.0), 0.0)
	var jchains: Array = BuildTool.wye_hint_chains(joiner) ["chains"]
	_check("joiner hint draws both arms into the outlet",
		jchains.size() == 3 and (jchains [2] as PackedVector3Array) [0]
			.is_equal_approx(joiner.global_position))
	smart.set_filter(ConveyorCompactSplitter.OUT_RIGHT, ConveyorCompactSplitter.RULE_NONE)


	var mate:= builds.add_compact_splitter(Vector3(100.0, y, 100.0), 0.0)
	var y_ok:= true
	var t_ok:= true
	for mouth: Vector3 in mate.ports():
		var out:= (mouth - mate.global_position).normalized()
		y_ok = y_ok and not builds.splitter_overlap(mouth + out * Cfg.SPLITTER_PORT_R)
		var lane:= mouth + out * 0.5
		t_ok = t_ok and not builds.wye_overlap([Vector4(lane.x, lane.y, lane.z, 0.5)])
	_check("a Y mates on every compact mouth", y_ok)
	_check("a T lane mates on every compact mouth", t_ok)
	_check("a Y half way into a compact mouth is still refused",
		builds.splitter_overlap(mate.port_in() + mate.global_basis.z
			* Cfg.SPLITTER_PORT_R * 0.5))
	var host:= builds.add_splitter(Vector3(110.0, y, 100.0), 0.0)
	var into:= (host.port_in() - host.global_position).normalized()
	var at:= host.port_in() + into * ConveyorCompactSplitter.PORT_R
	_check("a compact mates on a Y's infeed",
		not builds.wye_overlap([Vector4(at.x, at.y, at.z, ConveyorCompactSplitter.PORT_R)]))
	await _ghost_on_outlets(builds, y)

	var saved:= smart.to_dict()
	_check("smart type is saved", saved.get("type", "") == "conveyor_smart_splitter")
	_check("three filters are saved", (saved.get("filters", []) as Array).size() == 3)
	_check("a shut door is saved", int((saved.get("filters", []) as Array) [2])
		== ConveyorCompactSplitter.RULE_NONE)


	var shell_run:= builds.add_enclosed_conveyor(Vector3(70.0, y, 70.0),
		Vector3(76.0, y, 70.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var q:= PhysicsRayQueryParameters3D.create(Vector3(73.0, y + 3.0, 70.3),
		Vector3(73.0, y - 3.0, 70.3), Cfg.L_BUILD)
	q.collide_with_areas = true
	var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
	var roof_y:= (hit.get("position", Vector3.ZERO) as Vector3).y
	_check("the dismantle ray finds the casing roof (hit at %.2f, deck %.2f)" % [roof_y, y],
		not hit.is_empty() and builds.owner_of(hit.get("collider") as Node) == shell_run
		and roof_y > y + 0.5)


	var run_caught: Array [Node] = [shell_run]
	var run_fx: BuildFx = world.player.build.show_built(run_caught)
	await get_tree().process_frame
	await get_tree().process_frame
	var swept:= 0
	if run_fx != null:
		for g in BuildFx.meshes_of(shell_run):
			if g.material_override == run_fx._mat or g.material_overlay == run_fx._mat:
				swept += 1
	_check("build show sweeps the enclosed run's shell (%d meshes)" % swept, swept > 0)
	if run_fx != null and is_instance_valid(run_fx):
		await run_fx.tree_exited
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the shell goes back into the batch after the show",
		shell_run.get_node_or_null("ShowShell") == null
		and builds._enclosed_on_show.is_empty() and builds._enclosed_visuals != null)


	var line:= builds.new_line_id()
	var open_run:= builds.add_conveyor(Vector3(80.0, y, 80.0), Vector3(86.0, y, 80.0), line)
	var closed_run:= builds.add_enclosed_conveyor(Vector3(86.0, y, 80.0),
		Vector3(86.0, y, 86.0), line)
	var open_bends:= builds.corners.filter(func(k: ConveyorCorner) -> bool:
		return is_instance_valid(k) and not k is EnclosedConveyorCorner)
	_check("open into enclosed makes an open bend (%d)" % open_bends.size(),
		open_bends.size() == 1)
	_check("both runs are trimmed back for it",
		not open_run.laid_end().is_equal_approx(open_run.b)
		and not closed_run.laid_start().is_equal_approx(closed_run.a))


	var tool: BuildTool = world.player.build
	var was: BuildTool.Mode = tool._mode
	tool._mode = BuildTool.Mode.ENCLOSED_CONVEYOR
	tool._fit_run_ghost_mesh()
	var enclosed_mesh:= tool._ghost.multimesh.mesh
	tool._mode = BuildTool.Mode.CONVEYOR
	tool._fit_run_ghost_mesh()
	var open_mesh:= tool._ghost.multimesh.mesh
	tool._mode = was
	tool._fit_run_ghost_mesh()
	_check("enclosed hologram is the shell, open is the deck",
		enclosed_mesh != null and enclosed_mesh != open_mesh
		and open_mesh == ConveyorKit.segment_mesh())

	print("[compact splitter] %d failure(s)" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _ghost_on_outlets(builds: BuildManager, y: float) -> void:
	GameState.money = maxf(GameState.money, 10000000.0)
	var tool: BuildTool = world.player.build
	var ghost:= tool._compact_splitter_ghost
	var wye:= builds.add_splitter(Vector3(150.0, y, 150.0), 0.0)
	var joiner:= builds.add_joiner(Vector3(160.0, y, 150.0), 0.0)
	var u:= builds.add_u_joiner(Vector3(170.0, y, 150.0), 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cases:= [
		["a Y's left arm", wye.port(ConveyorSplitter.LEFT), wye.arm_travel(ConveyorSplitter.LEFT)],
		["a joiner's outlet", joiner.port_out(), joiner.forward()],
		["a U joiner's outlet", u.port_out(), u.forward()],
	]
	for c: Array in cases:
		var mouth: Vector3 = c [1]
		var fwd: Vector3 = c [2]
		fwd.y = 0.0
		fwd = fwd.normalized()
		ghost.global_rotation = Vector3(0.0, atan2(- fwd.x, - fwd.z), 0.0)
		ghost.global_position = mouth + fwd * ConveyorCompactSplitter.PORT_R
		var verdict: Dictionary = tool._evaluate_u_wye(ghost, fwd, Vector3.UP, true,
			ghost.build_cost(), ConveyorCompactSplitter.PORT_R * 2.0,
			ConveyorCompactSplitter.PORT_R)
		_check("a compact ghost may stand on %s (%s)" % [c [0], verdict ["reason"]],
			bool(verdict ["ok"]) and ghost.port_in().is_equal_approx(mouth))
	ghost.global_position = u.port_out() + u.forward() * ConveyorCompactSplitter.PORT_R * 0.4
	_check("but not half way into it",
		not bool(tool._evaluate_u_wye(ghost, u.forward(), Vector3.UP, true,
			ghost.build_cost(), ConveyorCompactSplitter.PORT_R * 2.0,
			ConveyorCompactSplitter.PORT_R) ["ok"]))
	await _compact_on_compact(builds, y)


func _compact_on_compact(builds: BuildManager, y: float) -> void:
	var tool: BuildTool = world.player.build
	var r:= ConveyorCompactSplitter.PORT_R
	var host:= builds.add_compact_splitter(Vector3(190.0, y, 150.0), 0.0)
	var smart_host:= builds.add_compact_splitter(Vector3(200.0, y, 150.0), 0.0, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var belt_reason:= tool.tr("put a belt between two splitter boxes")
	for pair: Array in [["a compact", tool._compact_splitter_ghost],
			["a smart", tool._smart_splitter_ghost]]:
		var ghost: ConveyorCompactSplitter = pair [1]
		for target: Array in [["compact", host], ["smart", smart_host]]:
			var other: ConveyorCompactSplitter = target [1]
			var mouth:= other.port(ConveyorCompactSplitter.OUT_FORWARD)
			var fwd:= other.arm_travel(ConveyorCompactSplitter.OUT_FORWARD)
			ghost.global_rotation = Vector3(0.0, atan2(- fwd.x, - fwd.z), 0.0)
			ghost.global_position = mouth + fwd * r
			_check("%s ghost on a %s's outlet is refused" % [pair [0], target [0]],
				tool.compact_mouth_on_compact(ghost))

			var back:= - (other.port_in() - other.global_position).normalized()
			ghost.global_rotation = other.global_rotation
			ghost.global_position = other.global_position - back * 2.0 * r
			_check("%s ghost backed onto a %s's infeed is refused" % [pair [0], target [0]],
				tool.compact_mouth_on_compact(ghost))
		ghost.global_position = host.port_in() + Vector3(0.0, 0.0, 3.0 + r)
		_check("%s ghost a belt's length away is allowed" % pair [0],
			not tool.compact_mouth_on_compact(ghost))
	_check("the refusal is a real message", belt_reason != "")
	await _seat_on_belt_start(builds, y)


func _seat_on_belt_start(builds: BuildManager, y: float) -> void:
	var tool: BuildTool = world.player.build
	var start:= Vector3(210.0, y, 150.0)
	var along:= Vector3.RIGHT
	var right:= Vector3(- along.z, 0.0, along.x)
	var belt:= builds.add_conveyor(start, start + along * 4.0)
	await get_tree().physics_frame
	var ghost:= tool._compact_splitter_ghost
	var near:= start - along * 0.6
	var doors_used:= { }
	for c: Array in [["ahead", along], ["to the right", right], ["to the left", - right]]:
		var seat:= tool.compact_seat(near, c [1])
		if seat.is_empty():
			_check("a box aimed %s snaps to the belt start" % c [0], false)
			continue
		var fwd: Vector3 = seat ["forward"]
		ghost.global_rotation = Vector3(0.0, atan2(- fwd.x, - fwd.z), 0.0)
		ghost.global_position = seat ["centre"]
		var door:= -1
		for side in ConveyorCompactSplitter.OUTPUTS:
			if ghost.port(side).distance_to(start) < 0.01 and ghost.arm_travel(side).dot(along) > 0.99:
				door = side
		doors_used [door] = true
		var verdict: Dictionary = tool._evaluate_u_wye(ghost, fwd, Vector3.RIGHT, true,
			ghost.build_cost(), ConveyorCompactSplitter.PORT_R * 2.0,
			ConveyorCompactSplitter.PORT_R)
		_check("a box aimed %s puts door %d on the belt start (%s)"
			% [c [0], door, verdict ["reason"]], door >= 0 and bool(verdict ["ok"]))
	_check("the three aims pick three different doors (%s)" % str(doors_used.keys()),
		doors_used.size() == 3 and not doors_used.has(-1))
	var pick:= tool.compact_seat(near, right)
	var facing: Vector3 = pick ["forward"]
	var built:= builds.add_compact_splitter(pick ["centre"], atan2(- facing.x, - facing.z))
	await get_tree().physics_frame
	_check("the built box hands its left door to the belt",
		built.route(ConveyorCompactSplitter.OUT_LEFT).downstream == belt)


	ghost.global_position = Vector3(16.0, y, 30.0)
	var loose: Dictionary = tool._evaluate_u_wye(ghost, along, Vector3.RIGHT, false,
		ghost.build_cost(), ConveyorCompactSplitter.PORT_R * 2.0,
		ConveyorCompactSplitter.PORT_R)
	_check("a rail under the crosshair is not a steep floor (%s)" % loose ["reason"],
		loose ["reason"] != tool.tr("surface too steep")
		and loose ["reason"] != tool.tr("nothing to stand on"))
	await _door_bridges(builds, y)


func _door_bridges(builds: BuildManager, y: float) -> void:
	var tool: BuildTool = world.player.build
	var was: BuildTool.Mode = tool._mode
	tool._mode = BuildTool.Mode.ENCLOSED_CONVEYOR
	var gap:= 0.93
	var r:= ConveyorCompactSplitter.PORT_R
	var up:= builds.add_compact_splitter(Vector3(240.0, y, 150.0), 0.0)
	var fwd:= up.forward()
	var mouth:= up.port(ConveyorCompactSplitter.OUT_FORWARD)
	var down:= builds.add_compact_splitter(mouth + fwd * (gap + r), 0.0)
	var side:= Vector3(- fwd.z, 0.0, fwd.x)
	var skew:= builds.add_compact_splitter(Vector3(250.0, y, 150.0), 0.0)
	var skew_mouth:= skew.port(ConveyorCompactSplitter.OUT_FORWARD)
	var skew_down:= builds.add_compact_splitter(
		skew_mouth + fwd * (gap + r) + side * 0.4, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var straight:= tool._evaluate(mouth, down.port_in(), true)
	_check("a straight %.2f m bridge between two doors is allowed (%s)"
		% [gap, straight ["reason"]], bool(straight ["ok"]))


	var x:= 300.0
	for door in ConveyorCompactSplitter.OUTPUTS:
		var a:= builds.add_compact_splitter(Vector3(x, y, 150.0), 0.0)
		var out:= a.port(door)
		var travel:= a.arm_travel(door)
		var b:= builds.add_compact_splitter(out + travel * (1.16 + r),
			atan2(- travel.x, - travel.z))
		await get_tree().physics_frame
		var v:= tool._evaluate(out, b.port_in(), true)
		_check("door %d bridges 1.16 m to the next box's infeed (%s, %s, %s)"
			% [door, v ["reason"], str(builds.port_bearing_at(out)),
			str(builds.port_bearing_at(b.port_in()))], bool(v ["ok"]))
		x += 10.0


	var left_box:= builds.add_compact_splitter(Vector3(x, y, 150.0), 0.0)
	var its_out:= left_box.port(ConveyorCompactSplitter.OUT_RIGHT)
	var across:= left_box.arm_travel(ConveyorCompactSplitter.OUT_RIGHT)
	var right_box:= builds.add_compact_splitter(its_out + across * (1.16 + r), 0.0)
	await get_tree().physics_frame
	var into_out:= tool._evaluate(its_out,
		right_box.port(ConveyorCompactSplitter.OUT_LEFT), true)
	_check("side door into side door says wrong side (%s)" % into_out ["reason"],
		into_out ["reason"] == tool.tr("wrong side  ·  hay goes the other way here"))
	var bent:= tool._evaluate(skew_mouth, skew_down.port_in(), true)
	_check("the same gap off line is still too short (%s)" % bent ["reason"],
		bent ["reason"] == tool.tr("too short"))
	var bare:= Vector3(270.0, y, 150.0)
	var loose:= tool._evaluate(bare, bare + fwd * gap, true)
	_check("the same length on open floor is still too short (%s)" % loose ["reason"],
		loose ["reason"] == tool.tr("too short"))
	var open_short:= tool._evaluate(mouth, mouth + fwd * 0.5, true)
	_check("under the open belt's floor is too short even on a door (%s)"
		% open_short ["reason"], open_short ["reason"] == tool.tr("too short"))
	_check("a too short run says what it needs (%.2f)" % float(loose.get("need", NAN)),
		is_equal_approx(float(loose.get("need", NAN)), Cfg.ENCLOSED_BELT_MIN_LENGTH))


	var aim:= mouth + side * 0.6
	_check("a door never pulls its own run's far end back onto it",
		not builds.snap_endpoint(aim, null, mouth).is_equal_approx(mouth)
		and builds.snap_endpoint(aim).is_equal_approx(mouth))
	var near_down:= down.port_in() - fwd * 0.3
	_check("the door across the gap is still snapped to",
		builds.snap_endpoint(near_down, null, mouth).is_equal_approx(down.port_in()))
	tool._lay_run(mouth, down.port_in())
	await get_tree().physics_frame
	var bridge:= up.route(ConveyorCompactSplitter.OUT_FORWARD).downstream
	_check("the bridge is laid and fed by the upper box",
		bridge is EnclosedConveyor and bridge.a.is_equal_approx(mouth))


	var p:= Vector3(280.0, y, 150.0)
	var piece:= builds.add_enclosed_conveyor(p, p + fwd * gap)
	await get_tree().physics_frame
	_check("a run turning off a short piece is refused",
		tool._bends_short_piece(PackedVector3Array([piece.b, piece.b + side * 3.0])))
	_check("a run turning into a short piece is refused",
		tool._bends_short_piece(PackedVector3Array([piece.a - side * 3.0, piece.a])))
	_check("a run carrying straight on from a short piece is fine",
		not tool._bends_short_piece(PackedVector3Array([piece.b, piece.b + fwd * 3.0])))
	tool._mode = was
