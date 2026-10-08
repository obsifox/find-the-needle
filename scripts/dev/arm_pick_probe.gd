class_name DevArmPickProbe
extends Node


var world: Node3D

const SETTLE_FRAMES:= 30


const CYCLE_FRAMES:= 1200

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	await _check_takes("hay_bale", RoboticArm.PICK_BALE, Vector3(-11.8, 0.06, 4.0))
	await _check_takes("eco_brick", RoboticArm.PICK_BRICK, Vector3(11.8, 0.06, 4.0))
	await _check_takes("foiled_bale", RoboticArm.PICK_FOILED,
		Vector3(-4.0, 0.06, -13.0))


	await _check_takes("hay_pulp", RoboticArm.PICK_PULP, Vector3(4.0, 0.06, -13.0))


	await _check_takes("paper_roll", RoboticArm.PICK_ROLL, Vector3(-4.0, 0.06, 12.0))

	await _check_takes("feed_disc", RoboticArm.PICK_DISC, Vector3(4.0, 0.06, 12.0))
	await _check_left_alone()
	await _check_all_off()
	_check_round_trip()
	_check_needle_locked()
	await _check_panel()
	print("\n[arm-pick] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])


func _check_takes(id: String, bit: int, base: Vector3) -> void:
	print("\n=== an arm set to take %s picks one up ===" % id)
	var builds: BuildManager = world.builds
	builds.clear()
	var belt:= builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	arm.accept_mask = bit
	var props: PropManager = world.props
	var block: Carryable = props.spawn(id,
		Transform3D(Basis.IDENTITY, base + Vector3(-1.6, 0.35, 0.0)))
	if block == null:
		_fail("could not spawn a %s to test with" % id)
		return
	var held: int = block.hay_strands()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame

	var lifted:= false
	for i in CYCLE_FRAMES:
		if arm._payload_prop == block:
			lifted = true
			break
		await get_tree().physics_frame
	_is("the %s ends up in the claw" % id, lifted, true)
	if not lifted:
		return


	_is("carried at its own strand count", arm._payload_count, held)

	var placed:= false
	for i in CYCLE_FRAMES:
		if arm.completed_cycles > 0:
			placed = true
			break
		await get_tree().physics_frame
	_is("and is put down again", placed, true)
	if not placed:
		return


	var seq:= arm.last_record_seq
	_is("put down on the belt as a record", seq >= 0, true)
	if seq < 0:
		return
	var where:= BeltPath.record_where(seq)
	_is("the record is on this belt", where.get("path") == belt, true)
	if where.is_empty():
		return
	var run: BeltRun = (where ["path"] as BeltPath).run
	_is("holding what it held", run.strands_of(int(where ["row"])), held)
	_is("nobody is holding it", arm._payload_prop == null, true)
	var at:= (where ["pose"] as Transform3D).origin
	var deck:= (belt.a + belt.b) * 0.5
	var off:= Vector2(at.x - deck.x, at.z - deck.z)
	print("  %s is %.2f m from the middle of the run" % [id, off.length()])
	_is("and it stands on the belt", off.length() < 2.0, true)


func _check_left_alone() -> void:
	print("\n=== and leaves one it is set not to take ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(-11.8, 0.06, -6.0)
	builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2), base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)


	arm.accept_mask = RoboticArm.PICK_WAD
	var at:= base + Vector3(-1.6, 0.35, 0.0)
	var props: PropManager = world.props
	var bale: Carryable = props.spawn("hay_bale", Transform3D(Basis.IDENTITY, at))
	if bale == null:
		_fail("could not spawn a bale to test with")
		return
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var rest: Vector3 = bale.global_position

	for i in CYCLE_FRAMES:
		await get_tree().physics_frame
	_is("the bale was never in the claw", arm._payload_prop == null, true)
	_is("the arm still has it unclaimed",
		bale.has_meta(PropManager.META_CLAIM), false)


	print("  bale moved %.3f m" % rest.distance_to(bale.global_position))
	_is("and it is still lying where it fell",
		rest.distance_to(bale.global_position) < 0.25, true)


func _check_all_off() -> void:
	print("\n=== an arm set to take nothing says so ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(11.8, 0.06, -6.0)
	builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2), base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	arm.accept_mask = 0
	var props: PropManager = world.props
	props.spawn("hay_bale",
		Transform3D(Basis.IDENTITY, base + Vector3(-1.6, 0.35, 0.0)))
	for i in SETTLE_FRAMES * 4:
		await get_tree().physics_frame
	_is("it completed no cycles", arm.completed_cycles, 0)
	print("  it reports: %s" % arm.alert_reason())
	_is("and the reason names the setting",
		arm.alert_reason().begins_with("SET TO TAKE NOTHING"), true)
	_is("the label reads as nothing", arm.accept_label(), "nothing")


	arm.set_accepting(RoboticArm.PICK_BALE, true)
	var worked:= false
	for i in CYCLE_FRAMES:
		if arm.completed_cycles > 0:
			worked = true
			break
		await get_tree().physics_frame
	_is("ticking a box starts it working", worked, true)


func _check_round_trip() -> void:
	print("\n=== the setting survives a save ===")
	var builds: BuildManager = world.builds
	builds.clear()


	var mask:= RoboticArm.PICK_BALE | RoboticArm.PICK_NEEDLE | RoboticArm.PICK_WAD | RoboticArm.PICK_BRICK | RoboticArm.PICK_FOILED
	var arm:= builds.add_robotic_arm(Vector3(0.0, 0.06, 14.0), 0.0, 1)
	arm.accept_mask = mask
	var saved:= builds.to_array()
	builds.clear()
	builds.from_array(saved)
	_is("one arm came back", builds.robotic_arms.size(), 1)
	if builds.robotic_arms.is_empty():
		return
	_is("with the same setting", builds.robotic_arms [0].accept_mask, mask)


	var written:= saved [0].get("refuses", []) as PackedStringArray
	print("  the file says refuses = %s" % str(written))
	_is("it names what is switched off, not what is on",
		"pile" in written and "loose" in written, true)
	_is("and says nothing about what it takes", "bale" in written, false)


	_is("an arm from a save with no filter at all takes everything",
		_reloaded_mask(builds, saved, ["refuses"]), RoboticArm.PICK_ALL)


	var legacy: Dictionary = (saved [0] as Dictionary).duplicate()
	legacy.erase("refuses")
	legacy ["accepts"] = 63
	builds.clear()
	builds.from_array([legacy])
	if builds.robotic_arms.is_empty():
		_fail("the legacy arm did not load at all")
		return
	_is("a legacy mask still digs the pile",
		builds.robotic_arms [0].accepts(RoboticArm.PICK_PILE), true)
	_is("and takes the kind that did not exist when it was written",
		builds.robotic_arms [0].accepts(RoboticArm.PICK_FOILED), true)
	_is("while keeping what it did say",
		builds.robotic_arms [0].accepts(RoboticArm.PICK_BALE), true)
	_is("a legacy mask with a kind switched off keeps it off",
		_legacy_takes(builds, saved [0], 63 & ~ RoboticArm.PICK_LOOSE,
			RoboticArm.PICK_LOOSE), false)


func _reloaded_mask(builds: BuildManager, saved: Array,
		drop: Array) -> int:
	var copy:= (saved [0] as Dictionary).duplicate()
	for key: String in drop:
		copy.erase(key)
	builds.clear()
	builds.from_array([copy])
	if builds.robotic_arms.is_empty():
		_fail("that arm did not load at all")
		return -1
	return builds.robotic_arms [0].accept_mask


func _legacy_takes(builds: BuildManager, saved: Dictionary, mask: int,
		bit: int) -> bool:
	var copy:= saved.duplicate()
	copy.erase("refuses")
	copy ["accepts"] = mask
	builds.clear()
	builds.from_array([copy])
	if builds.robotic_arms.is_empty():
		_fail("that arm did not load at all")
		return false
	return builds.robotic_arms [0].accepts(bit)


func _check_needle_locked() -> void:
	print("\n=== needles cannot be switched off ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var arm:= builds.add_robotic_arm(Vector3(6.0, 0.06, 14.0), 0.0, 1)
	arm.set_accepting(RoboticArm.PICK_NEEDLE, false)
	_is("asking for it off leaves it on",
		arm.accepts(RoboticArm.PICK_NEEDLE), true)


	arm.set_accepting(RoboticArm.PICK_LOOSE, false)
	_is("and the kinds beside it still switch",
		arm.accepts(RoboticArm.PICK_LOOSE), false)

	var saved:= builds.to_array()
	var written:= saved [0].get("refuses", []) as PackedStringArray
	print("  the file says refuses = %s" % str(written))
	_is("the save never claims it is refused", "needle" in written, false)


	var doctored: Dictionary = (saved [0] as Dictionary).duplicate()
	doctored ["refuses"] = PackedStringArray(["needle", "loose"])
	builds.clear()
	builds.from_array([doctored])
	if builds.robotic_arms.is_empty():
		_fail("that arm did not load at all")
		return
	var back:= builds.robotic_arms [0]
	_is("a save that refuses needles loads taking them",
		back.accepts(RoboticArm.PICK_NEEDLE), true)
	_is("without turning its other refusals back on",
		back.accepts(RoboticArm.PICK_LOOSE), false)
	_is("a legacy mask with the bit cleared takes them too",
		_legacy_takes(builds, saved [0], 63 & ~ RoboticArm.PICK_NEEDLE,
			RoboticArm.PICK_NEEDLE), true)


func _check_panel() -> void:
	print("\r\n=== the panel drives the machine ===")
	var builds: BuildManager = world.builds
	builds.clear()
	var arm:= builds.add_robotic_arm(Vector3(0.0, 0.06, 14.0), 0.0, 1)
	var panel:= ArmPanel.new()


	add_child(panel)
	await get_tree().process_frame
	panel.open(arm)
	_is("it opened on that arm", panel.arm() == arm, true)
	_is("a box for every kind", panel._boxes.size(), RoboticArm.PICK_KINDS.size())

	var box:= panel._boxes [RoboticArm.PICK_BALE] as Button
	_is("the bale box starts ticked", box.button_pressed, true)
	box.button_pressed = false
	_is("clearing it clears the bit", arm.accepts(RoboticArm.PICK_BALE), false)
	_is("and leaves the others alone", arm.accepts(RoboticArm.PICK_WAD), true)
	box.button_pressed = true
	_is("ticking it puts the bit back", arm.accepts(RoboticArm.PICK_BALE), true)


	var pin:= panel._boxes [RoboticArm.PICK_NEEDLE] as Button
	_is("the needle row is listed", pin != null, true)
	_is("and takes no click", pin.disabled, true)
	_is("and is ticked", pin.button_pressed, true)
	pin.button_pressed = false
	_is("forcing it off leaves the machine taking needles",
		arm.accepts(RoboticArm.PICK_NEEDLE), true)


	var other:= builds.add_robotic_arm(Vector3(4.0, 0.06, 14.0), 0.0, 1)
	other.accept_mask = RoboticArm.PICK_NEEDLE
	panel.close()
	panel.open(other)
	_is("the boxes follow the machine", box.button_pressed, false)
	_is("and the one it does take is ticked",
		(panel._boxes [RoboticArm.PICK_NEEDLE] as Button).button_pressed, true)
	panel.close()
	panel.queue_free()
