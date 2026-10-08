class_name DevArmModelsProbe
extends Node


var world: Node3D
var player: Player

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _ok(what: String, pass_: bool, detail: String = "") -> void:
	if pass_:
		print("  ok    %s%s" % [what, "" if detail == "" else "   (%s)" % detail])
	else:
		_fails += 1
		print("  FAIL  %s%s" % [what, "" if detail == "" else "   (%s)" % detail])


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	await _wait(20)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	if builds == null or tool == null:
		print("[armmodels] no build manager or no build tool")
		get_tree().quit(1)
		return
	Tech.reset()
	Tech.grant("belt")
	Tech.grant("arm_small")
	GameState.money = maxf(GameState.money, 10000000.0)

	_check_cards()
	_check_hand(tool)
	_check_variant_key(tool)
	_check_standing_arms_keep_their_model(builds)
	_check_copy(builds)
	_check_mixed_yard_saves(builds)
	await _phase_two(builds, tool)

	print("\n[armmodels] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_cards() -> void:
	print("\n=== three arm cards ===")
	var ids:= ["arm", "arm_standard", "arm_long"]
	for tier in 3:
		var id: String = ids [tier]
		_ok("%s places model %d" % [id, tier], BuildCatalog.arm_tier_of(id) == tier)
		_ok("%s is sold by %s" % [id, Cfg.ROBOT_ARM_TIERS [tier] ["id"]],
			BuildCatalog.unlock_of(id) == str(Cfg.ROBOT_ARM_TIERS [tier] ["id"]))
		_ok("%s places a robotic arm" % id,
			BuildCatalog.mode_of(id) == BuildTool.Mode.ROBOTIC_ARM)
		_ok("model %d copies back as %s" % [tier, id],
			BuildCatalog.arm_id_for_tier(tier) == id)
	_ok("a belt is not an arm", BuildCatalog.arm_tier_of("belt") == -1)
	_ok("the three are one family", BuildCatalog.family_of("arm_long") >= 0
		and BuildCatalog.family_of("arm_long") == BuildCatalog.family_of("arm"))
	_ok("the small arm's plans unlock only the small card",
		BuildCatalog.is_unlocked("arm") and not BuildCatalog.is_unlocked("arm_standard")
		and not BuildCatalog.is_unlocked("arm_long"))
	_ok("with one model there is nothing to step to",
		BuildCatalog.next_variant("arm") == "")


func _check_hand(tool: BuildTool) -> void:
	print("\n=== the card in hand is the model placed ===")
	Tech.grant("arm_standard")
	Tech.grant("arm_long")
	tool.set_active(true)
	for id: String in ["arm", "arm_standard", "arm_long"]:
		player.equip_build(id)
		var want:= BuildCatalog.arm_tier_of(id)
		_ok("holding %s, the tool places model %d" % [id, want],
			tool._arm_tier == want, "tool %d" % tool._arm_tier)
		_ok("...and the hologram is that model",
			tool._arm_ghost != null and tool._arm_ghost.tier_index == want)
	player.equip_build("arm")


	Tech.grant("arm_long", 0)
	Tech.grant("arm_long")
	_ok("buying plans leaves the small arm in hand", tool._arm_tier == 0)
	tool.set_active(false)


func _check_variant_key(tool: BuildTool) -> void:
	print("\n=== the variant key steps the models ===")
	tool.set_active(true)
	player.equip_build("arm")
	var seen: Array [String] = []
	for i in 3:
		_press_variant(tool)
		seen.append(player.build_id)
	_ok("round the three and back", str(seen) == str(["arm_standard", "arm_long", "arm"]),
		str(seen))
	_ok("the tool follows each step", tool._arm_tier == 0)
	Tech.grant("arm_standard", 0)
	player.equip_build("arm")
	_press_variant(tool)
	_ok("a model without plans is stepped over", player.build_id == "arm_long",
		player.build_id)
	Tech.grant("arm_standard")
	tool.set_active(false)


func _press_variant(tool: BuildTool) -> void:
	var press:= InputEventAction.new()
	press.action = "build_variant"
	press.pressed = true
	tool._unhandled_input(press)


func _check_standing_arms_keep_their_model(builds: BuildManager) -> void:
	print("\n=== plans do not refit a standing arm ===")
	builds.clear()
	Tech.reset()
	Tech.grant("belt")
	Tech.grant("arm_small")
	var arm: RoboticArm = builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0), 0.0, 0)
	Tech.grant("arm_standard")
	Tech.grant("arm_long")
	_ok("still the small arm after both plans", arm.tier_index == 0)
	_ok("still the small arm's reach", is_equal_approx(arm.reach_m(),
		float(Cfg.ROBOT_ARM_TIERS [0] ["reach"])))
	_ok("the yard's refit pass leaves it alone", builds.upgrade_placed_models() == 0
		and arm.tier_index == 0)
	builds.clear()


func _check_copy(builds: BuildManager) -> void:
	print("\n=== copying an arm copies its model ===")
	for tier in 3:
		var arm: RoboticArm = builds.add_robotic_arm(
			Vector3(11.8, 0.06, 4.0 + 12.0 * tier), 0.0, tier)
		_ok("model %d reads as %s" % [tier, builds.id_of(arm)],
			builds.id_of(arm) == BuildCatalog.arm_id_for_tier(tier))
	builds.clear()


func _check_mixed_yard_saves(builds: BuildManager) -> void:
	print("\n=== a yard of mixed models survives a save ===")
	for tier in 3:
		builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0 + 12.0 * tier), 0.0, tier)
	var saved:= builds.to_array()
	builds.from_array(saved)
	var tiers: Array [int] = []
	for arm in builds.robotic_arms:
		tiers.append(arm.tier_index)
	tiers.sort()
	_ok("one of each model", str(tiers) == str([0, 1, 2]), str(tiers))
	builds.clear()


func _phase_two(builds: BuildManager, tool: BuildTool) -> void:
	Tech.grant("arm_standard")
	Tech.grant("arm_long")
	_check_one_fraction()
	_check_ring_size(builds)
	await _check_show_radius(builds)
	await _check_show_radius_feeds(builds)
	await _check_plate_button(builds)
	_check_ghost_feeds(builds, tool)


func _check_one_fraction() -> void:
	print("\n=== one reach for the pickup and the drop ===")
	_ok("the fraction is the drop's 0.98, so no belt fed before is lost",
		is_equal_approx(RoboticArm.REACH_FRACTION, 0.98))
	var arm:= RoboticArm.new()
	for tier in 3:
		arm.tier_index = tier
		_ok("model %d works to %.3f m" % [tier, arm.work_reach()],
			is_equal_approx(arm.work_reach(),
				float(Cfg.ROBOT_ARM_TIERS [tier] ["reach"]) * RoboticArm.REACH_FRACTION))
	arm.free()


func _check_ring_size(builds: BuildManager) -> void:
	print("\n=== the ring is cut from the reach ===")
	for tier in 3:
		var arm: RoboticArm = builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0), 0.0, tier)
		var scale:= float(Cfg.ROBOT_ARM_TIERS [tier] ["scale"])
		var r:= float(Cfg.ROBOT_ARM_TIERS [tier] ["reach"]) * RoboticArm.REACH_FRACTION
		var h:= RoboticArm.SHOULDER_HEIGHT * scale
		var want:= sqrt(r * r - h * h)
		_ok("model %d ring radius %.3f m" % [tier, arm.ring_radius()],
			absf(arm.ring_radius() - want) < 0.001, "want %.3f" % want)
		_ok("...and no ring before anybody asks", not arm.range_lit()
			and arm.find_child("ReachRing", false, false) == null)
		arm.show_radius(true)
		var ring:= arm.find_child("ReachRing", false, false) as MeshInstance3D
		var drawn:= ring.mesh.get_aabb().size.x * 0.5 - RoboticArm.RING_BAND * 0.5 if ring != null else -1.0
		_ok("...drawn at that radius", absf(drawn - want) < 0.01, "drawn %.3f" % drawn)
		builds.demolish(arm)

	GameState.money = maxf(GameState.money, 10000000.0)
	var grown: RoboticArm = builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0), 0.0, 0)
	grown.show_radius(true)
	grown.upgrade()
	var ring:= grown.find_child("ReachRing", false, false) as MeshInstance3D
	var after:= ring.mesh.get_aabb().size.x * 0.5 - RoboticArm.RING_BAND * 0.5
	_ok("an upgraded arm's ring grows with it", absf(after - grown.ring_radius()) < 0.01,
		"%.3f against %.3f" % [after, grown.ring_radius()])
	builds.clear()


func _check_show_radius(builds: BuildManager) -> void:
	print("\n=== show radius ===")
	var arm: RoboticArm = builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0), 0.0, 1)
	await _wait(2)
	arm.show_radius(true)
	_ok("shown", arm.radius_shown() and arm.range_lit())
	_ok("for two minutes", is_equal_approx(arm.radius_seconds_left(),
		RoboticArm.RADIUS_SHOW_SECONDS))
	await _wait(60)
	var left:= arm.radius_seconds_left()
	_ok("the clock runs", left < RoboticArm.RADIUS_SHOW_SECONDS - 0.5
		and left > RoboticArm.RADIUS_SHOW_SECONDS - 5.0, "%.2f s left" % left)


	builds.show_reach(Vector3.ZERO, -1.0, "arm")
	_ok("the peek letting go leaves it up", arm.range_lit())
	_ok("pressed again it goes", not arm.toggle_radius() and not arm.range_lit())
	builds.show_reach(arm.global_position, 50.0, "arm")
	_ok("the peek still lights it on its own", arm.range_lit())
	builds.show_reach(Vector3.ZERO, -1.0, "arm")
	_ok("and puts it out", not arm.range_lit())
	arm.show_radius(true)
	arm._radius_left = 0.05
	await _wait(10)
	_ok("run out, it goes by itself", not arm.radius_shown() and not arm.range_lit())
	builds.clear()


func _check_show_radius_feeds(builds: BuildManager) -> void:
	print("\n=== show radius lights the belts ===")
	var base:= Vector3(11.8, 0.06, 4.0)
	var arm: RoboticArm = builds.add_robotic_arm(base, 0.0, 1)
	builds.add_conveyor(base + Vector3(1.8, 0.45, -10.0), base + Vector3(1.8, 0.45, 10.0))
	await _wait(2)
	_ok("nothing lit before the button", not is_instance_valid(arm._feeds)
		or not arm._feeds.visible)
	arm.show_radius(true)
	var feeds:= arm._feeds
	_ok("the belt beside it is lit", is_instance_valid(feeds) and feeds.visible
		and feeds.mesh != null)
	var first:= feeds.mesh.get_aabb() if feeds.mesh != null else AABB()
	_ok("...only the stretch in reach", first.size.z > 1.0
		and first.size.z < 2.0 * arm.work_reach(), "%.2f m" % first.size.z)
	builds.add_conveyor(base + Vector3(-1.8, 0.45, -10.0), base + Vector3(-1.8, 0.45, 10.0))
	await _wait(int(RoboticArm.FEEDS_CHECK * 60.0) + 5)
	var grown:= feeds.mesh.get_aabb() if feeds.mesh != null else AABB()
	_ok("a belt laid while it is up lights too", grown.size.x > first.size.x + 3.0,
		"%.2f m across, was %.2f" % [grown.size.x, first.size.x])
	arm.toggle_radius()
	_ok("hidden with the ring", not feeds.visible)
	builds.show_reach(arm.global_position, 50.0, "arm")
	_ok("the peek does not light belts", not feeds.visible)
	builds.show_reach(Vector3.ZERO, -1.0, "arm")
	builds.clear()


func _check_plate_button(builds: BuildManager) -> void:
	print("\n=== the plate's button ===")
	var panel: ArmPanel = player.arm_panel
	var arm: RoboticArm = builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0), 0.0, 1)
	await _wait(2)
	panel.open(arm)
	_ok("reads SHOW RADIUS", panel._radius_btn.text == tr("SHOW RADIUS"),
		panel._radius_btn.text)
	panel._radius_btn.pressed.emit()
	_ok("pressing it shows the ring", arm.radius_shown() and arm.range_lit())
	_ok("and it counts down from 2:00", panel._radius_btn.text
		== tr("HIDE RADIUS  ·  %d:%02d") % [2, 0], panel._radius_btn.text)
	panel.close()
	_ok("closing the plate leaves the ring up", arm.range_lit())
	panel.open(arm)
	panel._radius_btn.pressed.emit()
	_ok("pressing it again hides it", not arm.radius_shown() and not arm.range_lit())
	_ok("and reads SHOW RADIUS again", panel._radius_btn.text == tr("SHOW RADIUS"))
	panel.close()
	builds.clear()


	print("\n=== a refused upgrade says why on its button ===")
	var small: RoboticArm = builds.add_robotic_arm(Vector3(11.8, 0.06, 4.0), 0.0, 0)
	var hug: Conveyor = builds.add_conveyor(Vector3(12.55, 0.45, 1.0),
		Vector3(12.55, 0.45, 7.0))
	await _wait(3)
	var block:= small.upgrade_block()
	_ok("a belt against the base refuses the refit", block == tr("blocked"), block)
	panel.open(small)
	var btn: Button = panel._upgrade_btn
	_ok("the button is greyed", btn.disabled)
	_ok("and says why", btn.text == tr("Can't upgrade: %s.") % block, btn.text)
	_ok("in red", btn.get_theme_color("font_disabled_color") == ArmPanel.COL_WARN)
	var why: Label = panel._upgrade_why
	_ok("and the line under it names the belt", why.visible
		and why.text.contains(BuildCatalog.display_name("belt")), why.text)
	panel.close()
	builds.demolish(hug)
	await _wait(3)
	var free_block:= small.upgrade_block()
	panel.open(small)
	_ok("with the belt gone it offers the refit", free_block == ""
		and not btn.disabled and btn.text.begins_with(tr("UPGRADE TO %s  ·  $%s").get_slice("%", 0)),
		"%s / %s" % [free_block, btn.text])
	_ok("and the line under it goes", not why.visible, why.text)
	panel.close()


	print("\n=== walking away stops choosing belts ===")
	var links: ArmLinkMode = player.arm_links
	var stood:= player.global_position
	player.global_position = small.global_position + Vector3(3.0, 0.0, 0.0)
	links.begin(small)
	await _wait(3)
	_ok("beside the arm it keeps choosing", links.is_active() and links._hint.visible)
	player.global_position = small.global_position + Vector3(ArmLinkMode.LEAVE_DIST + 1.0,
		0.0, 0.0)
	await _wait(3)
	_ok("walked off, it stops", not links.is_active())
	_ok("and the hint goes with it", not links._hint.visible)
	player.global_position = stood


	print("\n=== the plate fits on the screen ===")
	for id in ["belt_links", "overflow_arm", "pick_order"]:
		Tech.grant(id)
	var line: Conveyor = builds.add_conveyor(small.global_position + Vector3(1.6, 0.45, -3.0),
		small.global_position + Vector3(1.6, 0.45, 3.0))
	small.set_link(line, small.global_position + Vector3(1.6, 0.45, 0.0), RoboticArm.LINK_TAKE)
	panel.open(small)
	await _wait(4)
	var card: Vector2 = panel._panel.size
	_ok("two columns wide", absf(card.x - ArmPanel.CARD_W) < 2.0,
		"%.0f against %.0f" % [card.x, ArmPanel.CARD_W])
	_ok("and short enough for a 900 line screen", card.y < 640.0, "%.0f tall" % card.y)


	var settled:= panel._panel.size.y
	panel._reset_btn.pressed.emit()
	var tallest:= panel._panel.size.y
	for i in 4:
		await get_tree().process_frame
		tallest = maxf(tallest, panel._panel.size.y)
	_ok("RESET unlinks every belt", small.links().is_empty())
	_ok("and the plate never stands taller than it was", tallest <= settled + 2.0,
		"%.0f against %.0f" % [tallest, settled])


	print("\n=== the moon ===")


	var plates_were:= Cfg.plate_dark
	var shop_was:= Cfg.shop_dark
	Cfg.plate_dark = false
	var card_box:= panel._panel.get_theme_stylebox("panel") as StyleBoxFlat
	ArmPanel.set_dark(true)
	PlateKit.sync(panel, true)
	_ok("dark: the open plate's paper goes grey",
		card_box.bg_color.is_equal_approx(ArmPanel.DARK ["COL_PAPER"]), str(card_box.bg_color))
	_ok("and its words cream", panel._state_line.get_theme_color("font_color")
		.is_equal_approx(ArmPanel.DARK ["COL_INK"]))
	ArmPanel.set_dark(false)
	PlateKit.sync(panel, false)
	_ok("light again: the paper comes back",
		card_box.bg_color.is_equal_approx(ArmPanel.LIGHT ["COL_PAPER"]), str(card_box.bg_color))
	_ok("and the words are ink", panel._state_line.get_theme_color("font_color")
		.is_equal_approx(ArmPanel.LIGHT ["COL_INK"]))
	panel.close()


	ArmPanel.set_dark(true)
	var built_dark:= ArmPanel.new()
	add_child(built_dark)
	await _wait(1)
	ArmPanel.set_dark(false)
	Cfg.plate_dark = false
	built_dark.open(small)
	await _wait(2)
	var dark_box:= built_dark._panel.get_theme_stylebox("panel") as StyleBoxFlat
	_ok("a plate built dark and opened after the switch to light comes up light",
		dark_box.bg_color.is_equal_approx(ArmPanel.LIGHT ["COL_PAPER"]), str(dark_box.bg_color))
	_ok("...words and all", built_dark._state_line.get_theme_color("font_color")
		.is_equal_approx(ArmPanel.LIGHT ["COL_INK"]))
	built_dark.close()
	built_dark.queue_free()


	print("\n=== the counter's own paper ===")
	Cfg.shop_dark = true
	var counter:= ShopMenu.new()
	add_child(counter)
	await _wait(1)
	var counter_box:= counter._panel.get_theme_stylebox("panel") as StyleBoxFlat
	_ok("the counter is built dark while the plates are light",
		counter_box.bg_color.is_equal_approx(ArmPanel.DARK ["COL_PAPER"])
		and ArmPanel.COL_PAPER.is_equal_approx(ArmPanel.LIGHT ["COL_PAPER"]),
		"%s / %s" % [counter_box.bg_color, ArmPanel.COL_PAPER])
	counter._refresh()
	_ok("and writing it leaves the plates' paper light",
		not ArmPanel.dark and ArmPanel.COL_INK.is_equal_approx(ArmPanel.LIGHT ["COL_INK"]))
	Cfg.shop_dark = false
	PlateKit.sync(counter, false)
	counter._refresh()
	_ok("the counter's switch turns it light",
		counter_box.bg_color.is_equal_approx(ArmPanel.LIGHT ["COL_PAPER"]), str(counter_box.bg_color))
	Cfg.shop_dark = true
	PlateKit.sync(counter, true)
	_ok("and dark again", counter_box.bg_color.is_equal_approx(ArmPanel.DARK ["COL_PAPER"]))
	_ok("...without touching the plates", not ArmPanel.dark)
	counter.queue_free()
	Cfg.plate_dark = plates_were
	Cfg.shop_dark = shop_was
	builds.clear()


func _check_ghost_feeds(builds: BuildManager, tool: BuildTool) -> void:
	print("\n=== the hologram lights the belts it would feed ===")
	var base:= Vector3(11.8, 0.06, 4.0)


	var belt: Conveyor = builds.add_conveyor(base + Vector3(1.8, 0.45, -10.0),
		base + Vector3(1.8, 0.45, 10.0))
	tool.set_active(true)
	player.equip_build("arm_standard")
	var tier: Dictionary = Cfg.ROBOT_ARM_TIERS [1]
	var reach:= float(tier ["reach"]) * RoboticArm.REACH_FRACTION
	var shoulder:= base + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * float(tier ["scale"])
	_ok("the hologram draws its own ring", tool._arm_ghost.range_lit())
	tool._update_arm_feeds(base)
	_ok("the belt beside it is fed", tool.arm_feeds.size() == 1
		and tool.arm_feeds [0] ["conveyor"] == belt, str(tool.arm_feeds.size()))
	var draw:= tool._arm_feed_draw
	_ok("and lit", draw != null and draw.get_surface_count() == 1)
	if draw != null and draw.get_surface_count() == 1:
		var verts: PackedVector3Array = draw.surface_get_arrays(0) [Mesh.ARRAY_VERTEX]
		var lo:= INF
		var hi:= - INF
		for v in verts:
			lo = minf(lo, v.z)
			hi = maxf(hi, v.z)
		var chord:= 2.0 * sqrt(reach * reach
			- pow(1.8, 2.0) - pow(belt.a.y + 0.26 - shoulder.y, 2.0))
		_ok("only the stretch in reach is lit (%.2f m of 20)" % (hi - lo),
			absf((hi - lo) - chord) < 0.25, "chord %.2f" % chord)
	tool._eval = tool._evaluate_arm(base, Vector3.UP, builds.arm_price(1),
		float(tier ["scale"]))
	var st:= tool.status()
	_ok("the readout counts it", int(st.get("belts", -1)) == 1
		and str(st.get("tone", "")) == "good", str(st.get("belts", -1)))
	var far:= base + Vector3(0.0, 0.0, 24.0)
	tool._update_arm_feeds(far)
	_ok("nothing to feed out there", tool.arm_feeds.is_empty())
	_ok("and nothing lit", draw.get_surface_count() == 0)
	tool._eval = tool._evaluate_arm(far, Vector3.UP, builds.arm_price(1),
		float(tier ["scale"]))
	st = tool.status()
	_ok("the readout warns", int(st.get("belts", -1)) == 0
		and str(st.get("tone", "")) == "warn")
	_ok("and does not refuse the spot", bool(st.get("ok", false)), str(st.get("reason", "")))
	tool.set_active(false)
	_ok("putting the arm away takes the light with it",
		not tool._arm_feed_mesh.is_visible_in_tree())
	builds.clear()
