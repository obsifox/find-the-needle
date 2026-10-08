class_name DevArmOverflowProbe
extends Node


var world: Node3D


const FEED_FRAMES:= 120
const RUN_FRAMES:= 1500
const JAM_FRAMES:= 2400

const SETTLE_FRAMES:= 900

var _failures:= 0
var _fed:= 0
var _carried:= { }


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	for id in ["belt", "arm_small", "arm_standard", "belt_links", "overflow_arm"]:
		Tech.grant(id)
	var builds: BuildManager = world.builds
	builds.clear()
	var base:= Vector3(0.0, 0.06, 14.0)
	var line:= builds.add_conveyor(base + Vector3(-3.4, 0.45, -1.8),
		base + Vector3(3.4, 0.45, -1.8))
	var out:= builds.add_conveyor(base + Vector3(-2.0, 0.45, 1.8),
		base + Vector3(2.0, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	arm.accept_mask = RoboticArm.PICK_WAD | RoboticArm.PICK_NEEDLE
	arm.set_link(line, base + Vector3(1.4, 0.45, -1.8), RoboticArm.LINK_TAKE)
	arm.set_link(out, base + Vector3(0.0, 0.45, 1.8), RoboticArm.LINK_PUT)
	arm.set_take_when_stuck(line, true)
	_is("the take link is ticked", arm.takes_when_stuck(line), true)
	var head:= base + Vector3(-3.2, 0.55, -1.8)

	print("\n=== while the line runs, the arm leaves it alone ===")
	await _feed(line, head, arm, RUN_FRAMES)
	print("  fed %d, carried %d" % [_fed, _carried.size()])
	_is("nothing was taken off a running line", _carried.size(), 0)
	_is("and the plate says why", str(arm.plate_status(false) [1]).contains("stuck"), true)

	print("\n=== jammed, it helps ===")
	line.set_outlet_held(true)
	var before:= _carried.size()
	var put_down:= { "n": 0 }
	var on_drop:= func(seq: int) -> void:
		var where:= BeltPath.record_where(seq)
		if not where.is_empty() and where ["path"] == out:
			put_down ["n"] += 1
	arm.dropped_record.connect(on_drop)
	await _feed(line, head, arm, JAM_FRAMES)
	var jam_took:= _carried.size() - before

	var link_s:= line.s_at(base + Vector3(1.4, 0.45, -1.8))
	var rows:= line.run.rows_in(link_s - RoboticArm.STUCK_SPAN, link_s + RoboticArm.STUCK_SPAN)
	for i in range(rows.x, rows.y):
		print("    row %d s=%.2f speed=%.3f group=%d kind=%d" % [i, line.run.s_of(i),
			line.run.speed_of(i), line.run.row_group(i), line.run.kind_of(i)])
	print("    link s=%.2f phase=%d clear=%s stall=\"%s\" flowing=%s" % [link_s,
		arm._phase, arm._clear, arm._stall, line.is_flowing()])
	print("  fed %d, carried %d while jammed, %d put on the other belt, line holds %d" % [
		_fed, jam_took, put_down ["n"], line.run.count()])
	_is("it took loads off the stuck line", jam_took >= 2, true)
	_is("and put them on the other belt", put_down ["n"] >= 2, true)

	print("\n=== running again, it stops ===")
	line.set_outlet_held(false)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
		if arm._phase == RoboticArm.Phase.IDLE and arm._payload_prop == null:
			break
	var settled:= _carried.size()
	await _feed(line, head, arm, RUN_FRAMES)
	print("  fed %d, carried %d after the line ran again" % [_fed, _carried.size() - settled])
	_is("nothing more came off the running line", _carried.size() - settled, 0)
	arm.dropped_record.disconnect(on_drop)

	print("\n=== the tick survives a save ===")
	var saved:= builds.to_array()
	var row: Dictionary = { }
	for d: Variant in saved:
		if d is Dictionary and str((d as Dictionary).get("type", "")) == "robotic_arm":
			row = d
	print("  the file says links = %s" % str(row.get("links", [])))
	builds.clear()
	await get_tree().physics_frame
	builds.from_array(saved)
	await get_tree().physics_frame
	var back: RoboticArm = builds.robotic_arms [0] if not builds.robotic_arms.is_empty() else null
	var ticked:= false
	if back != null:
		for link: Dictionary in back.links():
			if int(link ["role"]) == RoboticArm.LINK_TAKE:
				ticked = back.takes_when_stuck(back._link_run(link))
	_is("the reloaded take link is still ticked", ticked, true)

	print("\n[arm-overflow] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _feed(line: Conveyor, head: Vector3, arm: RoboticArm, frames: int) -> void:
	for i in frames:
		if i % FEED_FRAMES == 0 and line.push_record(BeltRun.Kind.WAD, 40, -1, { "strands": 40 }, head) >= 0:
			_fed += 1
		await get_tree().physics_frame
		var held:= arm._payload_prop
		if held != null and is_instance_valid(held):
			_carried [held.get_instance_id()] = true


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
