class_name DevRadarProbe
extends Node


var world: Node3D
var builds: BuildManager

var _pass:= 0
var _fail:= 0

const STEP:= 1.0 / 60.0

const DEPTHS:= [0.8, 1.5, 2.3]


func run() -> void:
	builds = world.get("builds") as BuildManager
	if builds == null:
		push_error("[radar] no BuildManager on the world")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	print("[radar] build: %s" % ("demo" if Cfg.DEMO else "full"))
	_check_cards()
	await _check_models()
	await _check_marks_end()
	await _check_out_of_range()
	await _check_aimed_at()
	await _check_save()
	builds.clear()
	print("\n[radar] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _place(at: Vector3, yaw: float = 0.9) -> NeedleRadar:
	builds.clear()
	var dish:= builds.add_needle_radar(at, yaw)

	dish.set_process(false)
	await get_tree().process_frame
	return dish


func _radar_at() -> Vector3:
	return Vector3(Cfg.PILE_RADIUS + 6.0, 0.0, 0.0)


func _dish_rows(data: Array) -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for d in data:
		if typeof(d) == TYPE_DICTIONARY and str((d as Dictionary).get("type", "")) == "needle_radar":
			out.append(d)
	return out


func _stand_needles() -> Array [int]:
	var field:= world.get("field") as HayField
	var here:= _radar_at()
	var spots:= [Vector3(0.0, 0.0, 0.0), Vector3(Cfg.PILE_RADIUS * 0.4, 0.0, 2.0),
		Vector3(- Cfg.PILE_RADIUS * 0.3, 0.0, -3.0)]
	var out: Array [int] = []
	var rng:= RandomNumberGenerator.new()
	rng.seed = 17
	for k in spots.size():
		var spot: Vector3 = spots [k]
		var top:= maxf(field.height_at(spot.x, spot.z), 0.0) if field != null else 0.0
		spot.y = top - float(DEPTHS [k])
		out.append(GameState.register_needle(spot, rng))
	var far:= here + Vector3(Cfg.RADAR_RANGE + 5.0, 0.0, 0.0)
	out.append(GameState.register_needle(far, rng))
	return out


func _drive(dish: NeedleRadar, limit: float = 60.0) -> Dictionary:
	var out:= { "turned_off": -1.0, "tilt": -1.0, "hyd_min": INF, "hyd_max": 0.0,
		"beamed": false, "seconds": 0.0 }
	var az:= dish.find_child(NeedleRadar.N_AZIMUTH, true, false) as Node3D
	var el:= dish.find_child(NeedleRadar.N_ELEVATION, true, false) as Node3D
	var aim:= dish.find_child(NeedleRadar.N_AIM, true, false) as Node3D
	var up:= dish.get_node_or_null("Uplink") as MeshInstance3D
	var was:= dish.phase
	var t:= 0.0
	while t < limit:
		dish.tick(STEP)
		t += STEP
		if dish.phase == NeedleRadar.Phase.TURN or dish.phase == NeedleRadar.Phase.RETURN:
			var length:= dish.hydraulic_length()
			out ["hyd_min"] = minf(float(out ["hyd_min"]), length)
			out ["hyd_max"] = maxf(float(out ["hyd_max"]), length)


		if was == NeedleRadar.Phase.TURN and dish.phase == NeedleRadar.Phase.LOCK and az != null and el != null and aim != null:
			var facing:= aim.global_position - el.global_position
			var flat:= Vector3(facing.x, 0.0, facing.z)
			var want:= dish.aim_point() - az.global_position
			want.y = 0.0
			out ["turned_off"] = rad_to_deg(flat.angle_to(want))
			out ["tilt"] = rad_to_deg(asin(clampf(facing.normalized().y, -1.0, 1.0)))
		if dish.phase == NeedleRadar.Phase.BEAM and up != null and up.visible:
			out ["beamed"] = true
		was = dish.phase
		if dish.phase == NeedleRadar.Phase.IDLE:
			break
	out ["seconds"] = t
	return out


func _check_cards() -> void:
	print("\n-- the cards --")
	for tier: Dictionary in Cfg.RADAR_TIERS:
		var id:= str(tier ["id"])
		_ok(TechTree.has_id(id), "%s is on the tree" % id)
		_ok(TechTree.is_demo(id) == Cfg.DEMO,
			"%s is %s" % [id, "a demo padlock" if Cfg.DEMO else "for sale"])
	_ok(BuildCatalog.unlock_of("needle_radar") == "radar_mk1",
		"the catalogue entry is locked behind the Mk I plans")
	_ok(CatalogPanel._icon_for("needle_radar") != null, "the catalogue entry has an icon")
	Tech.grant("scanner_mk1")
	if Cfg.DEMO:
		for tier: Dictionary in Cfg.RADAR_TIERS:
			var id:= str(tier ["id"])
			_ok(not bool(Tech.can_buy(id) ["ok"]), "the demo will not sell %s" % id)
			Tech.grant(id)
			_ok(not Tech.is_unlocked(id), "the demo will not hand over %s for free" % id)
		_ok(Tech.radar_tier() == -1, "the demo owns no dish")
		_ok(not BuildCatalog.is_unlocked("needle_radar"), "the demo cannot place a dish")
		_ok(not BuildCatalog.ordered_ids().has("needle_radar"),
			"and the build menu does not list one")
		return
	for tier: Dictionary in Cfg.RADAR_TIERS:
		Tech.grant(str(tier ["id"]), 0)
	_ok(Tech.radar_tier() == -1, "no plans, no dish")
	_ok(not BuildCatalog.is_unlocked("needle_radar"), "no plans, nothing to place")
	for t in Cfg.RADAR_TIERS.size():
		Tech.grant(str(Cfg.RADAR_TIERS [t] ["id"]))
		_ok(Tech.radar_tier() == t, "buying %s makes every dish a Mk %d" % [
			Cfg.RADAR_TIERS [t] ["id"], t + 1])
	_ok(BuildCatalog.is_unlocked("needle_radar"), "the plans unlock the catalogue entry")
	for tier: Dictionary in Cfg.RADAR_TIERS:
		Tech.grant(str(tier ["id"]), 0)


func _check_models() -> void:
	print("\n-- every model --")
	GameState.reset(5151, 0.0)
	var dish:= await _place(_radar_at())
	_ok(dish.get_node_or_null("Model") != null, "model instantiated")
	for pivot: String in [NeedleRadar.N_AZIMUTH, NeedleRadar.N_ELEVATION, NeedleRadar.N_AIM,
			NeedleRadar.N_BARREL, NeedleRadar.N_ROD, NeedleRadar.N_HYD_BASE, NeedleRadar.N_HYD_TIP]:
		_ok(dish.find_child(pivot, true, false) != null, "%s survived the import" % pivot)
	var ids:= _stand_needles()
	var far:= ids [ids.size() - 1]

	dish.tier_override = -1
	_ok(dish.activate() != "", "with no plans the dish refuses")
	_ok(dish.phase == NeedleRadar.Phase.IDLE, "...and does not move")

	for t in Cfg.RADAR_TIERS.size():
		var tier: Dictionary = Cfg.RADAR_TIERS [t]
		var mk:= "Mk %d" % (t + 1)
		dish.clear_marks()
		dish.cooldown = 0.0
		dish.tier_override = t
		_ok(dish.activate() == "", "%s starts" % mk)
		var r:= _drive(dish)
		_ok(dish.phase == NeedleRadar.Phase.IDLE,
			"%s is back at rest after %.1f s" % [mk, float(r ["seconds"])])
		_ok(float(r ["turned_off"]) >= 0.0 and float(r ["turned_off"]) < 2.0,
			"%s faced the needles before it fired (%.2f deg off)" % [mk, float(r ["turned_off"])])
		_ok(absf(float(r ["tilt"]) - Cfg.RADAR_UPLINK_ELEVATION) < 2.0,
			"%s tilted up to the satellite (%.1f deg)" % [mk, float(r ["tilt"])])
		_ok(float(r ["hyd_min"]) >= 0.7 and float(r ["hyd_max"]) <= 1.5,
			"%s kept the hydraulic on its anchors (%.2f to %.2f m)" % [
				mk, float(r ["hyd_min"]), float(r ["hyd_max"])])
		_ok(bool(r ["beamed"]), "%s beamed" % mk)
		var got:= dish.marks()
		_ok(got.size() == 3, "%s marked the three in range (%d)" % [mk, got.size()])
		var marked_far:= false
		var exact_right:= true
		var inside:= true
		var moved:= 0
		var steady:= true
		var left_right:= true
		var depth_right:= true
		var tag_right:= true
		for m in got:
			var index:= int(m ["index"])
			if index == far:
				marked_far = true
			if bool(m ["exact"]) != bool(tier ["exact"]):
				exact_right = false
			if float(m ["left"]) > float(tier ["seconds"]) or float(m ["left"]) < float(tier ["seconds"]) - 10.0:
				left_right = false
			var p:= GameState.needle_positions [index]
			var centre: Vector3 = m ["centre"]
			var off:= Vector2(centre.x - p.x, centre.z - p.z).length()
			if not bool(tier ["exact"]):
				if off > Cfg.RADAR_AREA_RADIUS:
					inside = false
				if off > 0.05:
					moved += 1
				if not centre.is_equal_approx(NeedleRadar.area_centre(p)):
					steady = false
			elif off > 0.001:
				inside = false
			if bool(m ["depth"]) != bool(tier ["depth"]):
				depth_right = false
			var k:= ids.find(index)
			if bool(tier ["depth"]) and k >= 0 and str(m ["depth_text"]) != "%.1f m deep" % float(DEPTHS [k]):
				depth_right = false
				print("        needle %d reads '%s', buried %.1f m" % [index, m ["depth_text"], DEPTHS [k]])
			var named:= NeedleTypes.name_of(GameState.type_of(index))
			var tag:= str(m ["tag"])
			if bool(tier ["depth"]) != (tag.begins_with(named + "\n") and tag.ends_with(str(m ["depth_text"]))):
				tag_right = false
				print("        needle %d tagged '%s', named %s" % [index, tag.c_escape(), named])
		_ok(not marked_far, "%s left the needle out of range alone" % mk)
		_ok(exact_right, "%s marks are %s" % [mk, "exact spots" if tier ["exact"] else "circles"])
		_ok(left_right, "%s marks stand for %d s" % [mk, int(tier ["seconds"])])
		_ok(depth_right, "%s %s the depth" % [mk, "writes" if tier ["depth"] else "does not write"])
		_ok(tag_right, "%s %s the needle's name over it" % [mk, "writes" if tier ["depth"] else "does not write"])
		if bool(tier ["exact"]):
			_ok(inside, "%s stands each beam on its needle" % mk)
		else:
			_ok(inside, "%s puts each needle inside its circle" % mk)
			_ok(moved == got.size(), "%s never centres a circle on its needle (%d of %d off)" % [
				mk, moved, got.size()])
			_ok(steady, "%s draws the same circle for the same needle every time" % mk)
		_ok(dish.cooldown > Cfg.RADAR_COOLDOWN - 15.0, "%s is recharging (%.0f s)" % [mk, dish.cooldown])
		_ok(dish.activate() != "", "%s refuses a second press while it recharges" % mk)
		_ok(dish.plate_source().begins_with("radar:cool:"), "%s plate says it is recharging" % mk)
	dish.tier_override = -1


func _check_marks_end() -> void:
	print("\n-- the marks go away --")
	GameState.reset(5152, 0.0)
	var dish:= await _place(_radar_at())
	var ids:= _stand_needles()
	dish.tier_override = 2
	dish.activate()
	_drive(dish)
	_ok(dish.marks().size() == 3, "three marks up")
	GameState.needle_taken [ids [0]] = 1
	for i in 30:
		dish.tick(STEP)
	_ok(dish.marks().size() == 2, "digging a needle up takes its mark down")
	for i in int((float(Cfg.RADAR_TIERS [2] ["seconds"]) + 1.0) / STEP):
		dish.tick(STEP)
	_ok(dish.marks().is_empty(), "the rest are gone after %d s" % int(Cfg.RADAR_TIERS [2] ["seconds"]))
	_ok(dish.find_children("Mark*", "Node3D", false, false).size() <= 3,
		"their nodes were let go of")


func _check_out_of_range() -> void:
	print("\n-- nothing in range --")
	GameState.reset(5153, 0.0)
	var dish:= await _place(Vector3(- Cfg.PILE_RADIUS - Cfg.RADAR_RANGE - 20.0, 0.0, 0.0))
	_stand_needles()
	dish.tier_override = 1
	_ok(dish.targets_in_range().is_empty(), "nothing to find from out here")
	_ok(dish.activate() == "", "it still fires")
	_drive(dish)
	_ok(dish.last_found == 0, "and finds nothing")
	_ok(is_zero_approx(dish.cooldown), "and does not charge a cooldown for nothing")
	_ok(dish.plate_source() == "radar:ready:0", "the plate says it found nothing last time")


func _check_aimed_at() -> void:
	print("\n-- E finds it --")
	GameState.reset(5154, 0.0)
	var dish:= await _place(_radar_at())
	await get_tree().physics_frame
	await get_tree().physics_frame
	var from:= dish.to_global(Vector3(4.2, 1.5, NeedleRadar.CONSOLE_AT.z))
	var look:= - dish.global_basis.x
	_ok(builds.needle_radar_under(from, look) == dish, "looking at the console finds the dish")
	_ok(builds.needle_radar_under(from, - look) == null, "looking away finds nothing")
	var far:= dish.to_global(Vector3(Cfg.RADAR_REACH + 4.0, 1.5, NeedleRadar.CONSOLE_AT.z))
	_ok(builds.needle_radar_under(far, look) == null, "from across the yard it is out of reach")
	dish.tier_override = 0
	_ok(dish.prompt() != "", "the bar offers a scan")
	dish.cooldown = 10.0
	_ok(dish.prompt() == "", "and offers nothing while it recharges")


func _check_save() -> void:
	print("\n-- save --")
	GameState.reset(5155, 0.0)
	var dish:= await _place(_radar_at(), 1.3)
	dish.cooldown = 42.0
	var data:= builds.to_array()
	var found:= false
	for d in data:
		if typeof(d) == TYPE_DICTIONARY and str((d as Dictionary).get("type", "")) == "needle_radar":
			found = true
	_ok(found, "the yard writes the dish")
	builds.clear()
	_ok(not builds.has_needle_radar(), "cleared")
	builds.from_array(data)
	await get_tree().process_frame
	if Cfg.DEMO:


		_ok(builds.needle_radars.is_empty(), "the demo does not build a saved dish")
		var rows:= _dish_rows(builds.to_array())
		_ok(rows.size() == 1, "but writes it back out (%d)" % rows.size())
		if rows.size() == 1:
			_ok(absf(float(rows [0].get("cool", 0.0)) - 42.0) < 0.1,
				"with its cooldown (%.2f s)" % float(rows [0].get("cool", 0.0)))
			_ok(Vector3(rows [0].get("position", Vector3.ZERO)).is_equal_approx(_radar_at()),
				"and where it stood")
		builds.clear()
		_ok(_dish_rows(builds.to_array()).is_empty(), "and lets it go with the yard")
		return
	_ok(builds.needle_radars.size() == 1, "the yard reads the dish back")
	if builds.needle_radars.is_empty():
		return
	var back:= builds.needle_radars [0]
	back.set_process(false)


	_ok(absf(back.cooldown - 42.0) < 0.1, "with its cooldown (%.2f s)" % back.cooldown)
	_ok(back.global_position.is_equal_approx(_radar_at()), "where it stood")
	_ok(is_equal_approx(back.global_rotation.y, 1.3), "facing the way it faced")
	_ok(back.field != null, "on the pile it reads its marks off")
	_ok(is_equal_approx(builds.demolish(back), Cfg.RADAR_COST), "taking it down pays it back")
	_ok(not builds.has_needle_radar(), "and it is gone")


	await get_tree().process_frame
	var again:= builds.add_needle_radar(_radar_at(), 1.3)
	again.set_process(false)
	again.tier_override = 1
	_ok(again.cooldown > 41.0, "a dish put back up is still recharging (%.2f s)" % again.cooldown)
	_ok(again.activate() != "", "...and refuses to fire")
	var state:= GameState.to_dict()
	GameState.radar_cooldown = 0.0
	GameState.from_dict(state)
	_ok(absf(GameState.radar_cooldown - again.cooldown) < 0.01 and GameState.radar_cooldown > 41.0,
		"the yard's cooldown is in the save (%.2f s)" % GameState.radar_cooldown)
	builds.demolish(again)
