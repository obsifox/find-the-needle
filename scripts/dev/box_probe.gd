class_name DevBoxProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 40
const REBUILD_FRAMES:= 8
const LANE_X:= 13.0
const NUDGE:= 0.15

var _pass:= 0
var _fail:= 0
var _deck_y:= 0.0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(10.5, 0.4, 0.0)
	GameState.add_money(200000.0)


	Tech.grant("pole_span", 0)
	Tech.grant("pole_drop", 0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _case_the_model()
	await _case_a_box_is_a_pole()
	await _case_under_the_wall()
	await _case_the_reveal()
	await _case_the_long_reach()
	await _case_the_ranks()
	await _case_a_save_round_trip()
	await _case_the_ghost_tells_the_truth()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _case_the_model() -> void:
	print("\n=== the model ===")
	var box: PowerPole = await _plant(Vector3(LANE_X, 0.0, 0.0), true)
	_check("a buried post is a PowerBox", box is PowerBox)
	_check("...and says so", box.buried())
	_check("...at the box's price", is_equal_approx(box.build_cost(), Cfg.BOX_COST))
	_check("the model ships Marker_Wire", box._find(PowerPole.N_WIRE) != null)
	_check("the model ships a collider",
		not box.find_children("*", "StaticBody3D", true, false).is_empty())
	var crown:= box.wire_point()
	_check("the insulator is knee to hip high, %.2f m" % crown.y,
		crown.y > 0.6 and crown.y < 1.5)
	_check("it reaches %.1f m for a post" % box.link_reach(),
		is_equal_approx(box.link_reach(), Cfg.BOX_LINK_R))
	_check("...and %.1f m for a machine" % box.supply_reach(),
		is_equal_approx(box.supply_reach(), Cfg.BOX_SUPPLY_R))
	await _clear_yard()


func _case_a_box_is_a_pole() -> void:
	print("\n=== a box is a pole ===")
	var grid: PowerGrid = world.builds.grid
	var pole: PowerPole = await _plant(Vector3(LANE_X, 0.0, -4.0))
	var box: PowerPole = await _plant(Vector3(LANE_X, 0.0, 4.0), true)
	_check("a box in a pole's reach joins its network", grid.network_count() == 1)
	_check("...and is strung to it", box.strung_to(pole))
	_check("the run between a pole and a box is IN THE AIR: the pole hangs a "
		+ "drop to the box's lid", pole.wires().size() == 1 and box.traces().is_empty())
	var press: HayCompressor = await _press_at(8.0)
	_check("a press in the box's circle and outside the pole's is powered",
		grid.network_of(press) >= 0)
	_check("...off the box", grid.pole_for(press) == box)
	_check("...through a buried run and not a wire",
		box.traces().size() == 1 and box.wires().is_empty())
	var port:= grid.port_for(press)
	var trace: CableTrace = box.traces() [0]
	_check("...that comes up at the terminal the grid chose",
		port != null and trace.end_point().distance_to(port.global_position) < 0.01)
	_check("...and goes under the ground on the way",
		trace.points() [1].y < box.global_position.y - Cfg.CABLE_DEPTH + 0.01)
	_check("the grid reports the box on the network with the press",
		int(grid.report(box) ["machines"]) == 1 and int(grid.report(box) ["poles"]) == 2)
	var served:= grid.served_by(box)
	_check("served_by(box) lists the press", served.size() == 1 and served [0] == press)
	await _demolish(box)
	_check("taking the box down takes its run with it and the press goes dark",
		grid.network_of(press) < 0 and is_equal_approx(press.power, 0.0))
	await _clear_yard()


func _case_under_the_wall() -> void:
	print("\n=== a buried cable goes under the wall ===")
	var grid: PowerGrid = world.builds.grid
	var press: HayCompressor = await _press_at(0.0)


	var blind: PowerPole = await _plant(Vector3(LANE_X, 0.0, -5.5))
	world.builds.add_wall(Vector3(LANE_X - 3.0, 0.0, -1.5),
		Vector3(LANE_X + 3.0, 0.0, -1.5), YardWall.Bay.SOLID)
	await _settle()
	_check("the wall cuts the pole's drop, as --power proves",
		grid.network_of(press) < 0 and grid.unreachable().has(press))


	var box: PowerPole = await _plant(Vector3(LANE_X - 2.0, 0.0, -7.0), true)
	_check("a box behind the same wall powers the press",
		grid.network_of(press) >= 0)
	_check("...through the box", grid.pole_for(press) == box)
	_check("...and the press is no longer obstructed", not grid.unreachable().has(press))
	_check("...the blind pole still hangs no drop", blind.wire_count() == 0
		or _drops(blind) == 0)
	_check("the box's run to the press exists", box.traces().size() == 1)
	_check("box and pole are one network", grid.network_count() == 1)
	await _clear_yard()


func _case_the_reveal() -> void:
	print("\n=== the cables show only while something asks ===")
	CableTrace.reveal(get_tree(), "held", false)
	CableTrace.reveal(get_tree(), "aimed", false)
	var a: PowerPole = await _plant(Vector3(LANE_X, 0.0, -4.0), true)
	await _plant(Vector3(LANE_X, 0.0, 4.0), true)
	_check("two boxes draw one run between them", a.traces().size() == 1)
	var trace: CableTrace = a.traces() [0]
	_check("a fresh run is hidden", not trace.visible)
	CableTrace.reveal(get_tree(), "held", true)
	_check("holding a box shows it", trace.visible)
	CableTrace.reveal(get_tree(), "aimed", true)
	CableTrace.reveal(get_tree(), "held", false)
	_check("putting the box away while the crosshair is on one keeps it shown",
		trace.visible)
	CableTrace.reveal(get_tree(), "aimed", false)
	_check("letting go of the last reason hides it", not trace.visible)

	CableTrace.reveal(get_tree(), "held", true)
	await _press_at(0.0)


	var shown:= true
	var runs:= 0
	for post in world.builds.power_poles:
		for t in post.traces():
			shown = shown and t.visible
			runs += 1
	_check("runs hung while a box is held arrive shown", shown and runs == 2)
	CableTrace.reveal(get_tree(), "held", false)
	await _clear_yard()


func _case_the_long_reach() -> void:
	print("\n=== a box reaches %.0f m for a post and %.0f m for a machine ==="
		% [Cfg.BOX_LINK_R, Cfg.BOX_SUPPLY_R])
	var grid: PowerGrid = world.builds.grid

	var box: PowerPole = await _plant(Vector3(LANE_X, 0.0, -9.0), true)
	var pole: PowerPole = await _plant(Vector3(LANE_X, 0.0, 5.0))
	_check("a pole planted 14 m from a box is strung to it, though a pole "
		+ "reaches only %.0f" % Cfg.POLE_LINK_R, pole.strung_to(box)
			and grid.network_count() == 1)
	await _demolish(pole)

	var near: PowerPole = await _plant(
		Vector3(LANE_X, 0.0, -9.0 + Cfg.BOX_LINK_R - NUDGE), true)
	_check("a box just inside reach links", near.strung_to(box)
		and grid.network_count() == 1)
	await _demolish(near)
	var far: PowerPole = await _plant(
		Vector3(LANE_X, 0.0, -9.0 + Cfg.BOX_LINK_R + NUDGE), true)
	_check("a box just outside does not", not far.strung_to(box)
		and grid.network_count() == 2)
	await _demolish(far)

	var press: HayCompressor = await _press_at(-9.0 + Cfg.BOX_SUPPLY_R - NUDGE)
	_check("a press just inside the box's circle is powered",
		grid.pole_for(press) == box)
	await _demolish(press)
	var out: HayCompressor = await _press_at(-9.0 + Cfg.BOX_SUPPLY_R + NUDGE)
	_check("...and one just outside is not", grid.network_of(out) < 0)
	await _clear_yard()


func _case_the_ranks() -> void:
	print("\n=== the two reach ranks move the yard ===")
	var grid: PowerGrid = world.builds.grid
	_check("at rank 0 a pole links at %.1f m" % Tech.pole_link_r(),
		is_equal_approx(Tech.pole_link_r(), Cfg.POLE_LINK_R))
	var west: PowerPole = await _plant(Vector3(LANE_X, 0.0, -5.0))
	var east: PowerPole = await _plant(Vector3(LANE_X, 0.0, 5.0))
	_check("two poles 10 m apart are two networks", grid.network_count() == 2)
	Tech.grant("pole_span", 1)
	await _settle()
	_check("the first span rank reaches %.1f m" % Tech.pole_link_r(),
		is_equal_approx(Tech.pole_link_r(), 10.5))
	_check("...and the standing poles join up on their own",
		grid.network_count() == 1 and (west.strung_to(east) or east.strung_to(west)))
	_check("...and a box gets the same metres, %.1f m" % Tech.box_link_r(),
		is_equal_approx(Tech.box_link_r(), Cfg.BOX_LINK_R + 1.5))
	var d:= west.to_dict()
	_check("the new link is saved", (d.get("links", []) as Array).size() == 1
		or (east.to_dict().get("links", []) as Array).size() == 1)
	await _clear_yard()

	var pole: PowerPole = await _plant(Vector3(LANE_X, 0.0, -6.5))
	var press: HayCompressor = await _press_at(0.0)
	_check("a press 6.5 m from a pole is outside its %.0f m circle"
		% Cfg.POLE_SUPPLY_R, grid.network_of(press) < 0)
	Tech.grant("pole_drop", 1)
	await _settle()
	_check("the first drop rank reaches %.1f m" % Tech.pole_supply_r(),
		is_equal_approx(Tech.pole_supply_r(), 7.0))
	_check("...and the press is picked up without a new pole",
		grid.pole_for(press) == pole)
	Tech.grant("pole_span", 0)
	Tech.grant("pole_drop", 0)
	await _settle()
	_check("taking the rank away drops it again (the ranks are read live)",
		grid.network_of(press) < 0)
	await _clear_yard()


func _case_a_save_round_trip() -> void:
	print("\n=== a save round trip ===")
	var grid: PowerGrid = world.builds.grid
	var gen: HayGenerator = world.builds.add_generator(
		Vector3(LANE_X + 2.5, 0.0, -5.0), 0.0)
	gen.fuel = gen.capacity()
	var box: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 0.0), true)
	var pole: PowerPole = await _plant(Vector3(LANE_X + 2.5, 0.0, 7.0))
	await _press_at(-3.0)
	await _settle()
	var before: Dictionary = grid.report(box)
	var nets:= grid.network_count()
	var d:= box.to_dict()
	_check("to_dict names the box", str(d.get("type", "")) == "power_box")
	_check("...and carries its link", (d.get("links", []) as Array).size() >= 1
		or (pole.to_dict().get("links", []) as Array).size() >= 1)

	var saved: Array = world.builds.to_array()
	world.builds.clear()
	await _settle()
	world.builds.from_array(saved)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle()

	var boxes:= 0
	var back: PowerPole = null
	for p in world.builds.power_poles:
		if p is PowerBox:
			boxes += 1
			back = p
	_check("one box and one pole came back", boxes == 1
		and world.builds.power_poles.size() == 2)
	var after: Dictionary = grid.report(back)
	_check("the same number of networks (%d)" % nets, grid.network_count() == nets)
	_check("the same supply, %.2f kW" % float(before ["supply"]),
		is_equal_approx(float(after ["supply"]), float(before ["supply"])))
	_check("the same machines on it (%d)" % int(before ["machines"]),
		int(after ["machines"]) == int(before ["machines"]))
	_check("the buried run came back", back.traces().size() >= 1)
	await _clear_yard()


func _case_the_ghost_tells_the_truth() -> void:
	print("\n=== the box ghost tells the truth ===")
	var tool: BuildTool = player.build
	var grid: PowerGrid = world.builds.grid
	var spot:= Vector3(LANE_X, 0.0, 0.0)
	tool.set_mode(BuildTool.Mode.POWER_BOX)
	_check("holding a box asks for the cables", CableTrace.revealed()
		or not tool.is_active())

	var other: PowerPole = await _plant(spot + Vector3(0.0, 0.0, 14.0), true)
	var pole: PowerPole = await _plant(spot + Vector3(0.0, 0.0, -8.0))
	var press: HayCompressor = await _press_at(-3.0)


	var survey: Dictionary = await _survey(tool, spot)
	_check("the ghost links the box 14 m away and the pole 8 m away",
		(survey ["links"] as Array).size() == 2)
	_check("...draws the box run under the ground and the pole run in the air",
		(survey ["traces"] as Array).size() >= 1 and (survey ["spans"] as Array).size() == 1)
	_check("...and a buried drop to the press", (survey ["reaches"] as Array).has(press))
	_check("...nothing blocked, ever", (survey ["blocked"] as Array).is_empty())
	var st: Dictionary = tool.status()
	_check("the line quotes the box's price", is_equal_approx(float(st ["cost"]), Cfg.BOX_COST))
	_check("...and is green", str(st ["tone"]) == "good")

	var placed: PowerPole = await _plant(spot, true)
	_check("the placed box is strung to both", placed.strung_to(other)
		and placed.strung_to(pole) and grid.network_count() == 1)
	_check("...and powers the press", grid.pole_for(press) == placed)
	tool.set_mode(BuildTool.Mode.CONVEYOR)
	await _clear_yard()


func _plant(at: Vector3, buried: bool = false) -> PowerPole:
	var pole: PowerPole = world.builds.add_power_pole(at, 0.0, buried)
	await _settle()
	return pole


func _press_at(z: float) -> HayCompressor:
	var press: HayCompressor = world.builds.add_compressor(
		Vector3(LANE_X, _deck_y, z), 0.0)
	await _settle()
	return press


func _demolish(building: Node3D) -> void:
	world.builds._demolish(building)
	await _settle()


func _clear_yard() -> void:
	world.builds.clear()
	await _settle()


func _settle() -> void:
	for i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _survey(tool: BuildTool, at: Vector3) -> Dictionary:
	tool._post_ghost().global_position = at
	await get_tree().physics_frame
	tool._eval = { "ok": true, "reason": "", "length": 0.0, "cost": Cfg.BOX_COST }
	tool._pole_eval = tool._survey_pole(at)
	return tool._pole_eval


func _drops(pole: PowerPole) -> int:
	var n:= 0
	for line in pole.wires():
		if line.to_anchors.is_empty():
			continue
		var walk: Node = line.to_anchors [0]
		var on_pole:= false
		while walk != null:
			if walk is PowerPole:
				on_pole = true
				break
			walk = walk.get_parent()
		if not on_pole:
			n += 1
	return n


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
