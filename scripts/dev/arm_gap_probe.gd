class_name DevArmGapProbe
extends Node


var world: Node3D

const SETTLE:= 30

const WATCH_FRAMES:= 3600


const SPACING_MIN:= 0.6
const SPACING_MAX:= 1.8


const WAIT_FRAMES:= 12000

const HOLD_LIMIT:= 8.0

var _rng:= RandomNumberGenerator.new()
var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	_rng.seed = 20260919
	var ua:= OS.get_cmdline_user_args()
	var motor:= 0
	var at_flag:= ua.find("--motor")
	if at_flag >= 0 and at_flag + 1 < ua.size():
		motor = int(ua [at_flag + 1])
	Tech.grant("belt_speed", motor)
	var speed:= Tech.belt_speed()
	print("  belt motor rank %d, %.2f m/s" % [motor, speed])
	if "--bend" in ua:
		await _bend()
		_finish()
		return
	if "--cost" in ua:
		await _cost()
		_finish()
		return
	if "--armsign" in ua:
		await _sign()
		_finish()
		return
	if "--room" in ua:
		await _room()
		_finish()
		return


	if "--busy" in ua:
		Tech.grant("arm_payload", 6)
	if "--chase" in ua:
		RoboticArm.wait_in_place = false
	var builds: BuildManager = world.builds

	var base:= Vector3(11.8, 0.06, 4.0)
	var head:= base + Vector3(1.8, 0.45, -6.0)
	var tail:= base + Vector3(1.8, 0.45, 4.0)


	var line: Conveyor = null
	if "--seam" in ua:
		var mid:= base + Vector3(1.8, 0.45, 2.5)
		builds.add_conveyor(head, mid)
		line = builds.add_conveyor(mid, tail)
	else:
		line = builds.add_conveyor(head, tail)
	var arm:= builds.add_robotic_arm(base, 0.0, 1)


	if "--noarm" in ua and arm != null:
		arm.accept_mask = 0
	var gap_min:= SPACING_MIN * (0.6 if "--dense" in ua else 1.0)
	var gap_max:= SPACING_MAX * (0.7 if "--dense" in ua else 1.0)
	for i in SETTLE:
		await get_tree().physics_frame
	if line == null or arm == null:
		_fail("the belt and the arm were built")
		_finish()
		return

	var fwd:= (tail - head).normalized()
	var next_spawn:= 0
	var spawned:= 0
	var cycles_before:= arm.completed_cycles
	var hold_frames:= 0
	var hold_run:= 0
	var longest:= 0
	var swings:= 0
	var was_phase:= arm._phase
	var spilled:= { }
	var as_records:= [0]
	arm.dropped_record.connect(func(_seq: int) -> void: as_records [0] += 1)
	for f in WATCH_FRAMES:
		if f % 15 == 0:
			_note_spills(builds, spilled)
		if arm._phase == RoboticArm.Phase.SWING_DROP and was_phase != RoboticArm.Phase.SWING_DROP:
			swings += 1
		was_phase = arm._phase
		if f >= next_spawn:
			var at:= head + fwd * 0.4 + Vector3.UP * 0.05
			if world.props.spawn("hay_wad", Transform3D(Basis(), at),
					{ "strands": 60 }) != null:
				spawned += 1
			next_spawn = f + int(_rng.randf_range(gap_min, gap_max) / speed * 60.0)
		var holding:= arm._payload_count > 0 and (arm._phase == RoboticArm.Phase.PARK_HOLD or (arm._phase == RoboticArm.Phase.DESCEND_DROP and arm._hold_since > 0.0))
		if holding:
			hold_frames += 1
			hold_run += 1
			longest = maxi(longest, hold_run)
		else:
			hold_run = 0
		await get_tree().physics_frame

	var loads:= arm.completed_cycles - cycles_before
	print("\n=== one minute beside a moving belt ===")
	print("  %d wads sent down the line" % spawned)
	print("  %d loads put on by the arm" % loads)
	print("  %d swings over the belt, %.2f a load" % [swings, float(swings) / maxf(loads, 1)])
	print("  %.1f s spent holding, longest hold %.1f s"
		% [hold_frames / 60.0, longest / 60.0])
	var theirs:= 0
	for id in spilled:
		if int(spilled [id]) != 60:
			theirs += 1
	print("  %d let go as records, %d as bodies" % [as_records [0], loads - as_records [0]])
	print("  %d wads knocked off the side of the belt, %d of them the arm's"
		% [spilled.size(), theirs])


	if theirs > 0:
		_fail("%d of the arm's loads came off the side of the belt" % theirs)
	if loads <= 0 and not "--noarm" in ua:
		_fail("the arm put nothing on a belt with gaps in it")
	if loads > 0 and swings > loads + 2:
		_fail("the arm swung %d times for %d loads, chasing gaps" % [swings, loads])
	if longest / 60.0 > HOLD_LIMIT:
		_fail("a hold lasted %.1f s, over %.1f" % [longest / 60.0, HOLD_LIMIT])
	_finish()


func _note_spills(builds: BuildManager, seen: Dictionary) -> void:
	for item in world.props.items:
		var wad:= item as HayWad
		if wad == null or not is_instance_valid(wad) or seen.has(wad.get_instance_id()):
			continue
		if wad.is_held() or BeltPath.is_rider(wad):
			continue
		for c in builds.conveyors:
			var belt:= c as BeltPath
			var at:= belt._nearest(wad.global_position)
			var s:= float(at ["s"])
			if s < SPILL_HEAD or s > belt.path_length() - SPILL_TAIL:
				continue
			if float(at ["lift"]) > -0.2 or absf(float(at ["side"])) > 1.5:
				continue
			seen [wad.get_instance_id()] = wad.strands
			break


const SPILL_HEAD:= 1.0
const SPILL_TAIL:= 0.8


func _sign() -> void:
	var builds: BuildManager = world.builds
	var watch: MachineWatch = builds.watch
	var base:= Vector3(11.8, 0.06, 4.0)
	var line:= builds.add_conveyor(base + Vector3(1.8, 0.45, -1.2),
		base + Vector3(1.8, 0.45, 1.8))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE:
		await get_tree().physics_frame
	if line == null or arm == null or watch == null:
		_fail("the belt, the arm and the watch are all there")
		return
	_is("nothing wrong with it yet", arm.alert_reason(), "")


	var carrying:= false
	for i in 900:
		if arm._payload_count > 0 and arm._phase == RoboticArm.Phase.LIFT:
			carrying = true
			break
		await get_tree().physics_frame
	if not carrying:
		_fail("the arm picked a load up")
		return
	var along:= 0.0
	while along <= line.path_length():
		var blocker:= world.props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, line._point_at(along) + Vector3.UP * 0.26),
			{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
		along += 0.3
		if blocker != null:
			blocker.freeze = true
			blocker.set_meta(PropManager.META_CLAIM, get_instance_id())


	var said:= 0.0
	var start:= Time.get_ticks_msec()
	for i in WAIT_FRAMES:
		await get_tree().physics_frame
		if arm.alert_reason() != "":
			said = float(Time.get_ticks_msec() - start) / 1000.0
			break
	if said <= 0.0:
		_fail("the arm said what was wrong")
		return
	print("  it spoke up after %.1f s, on attempt %d" % [said, arm._hold_tries])
	_is("it names the belt", arm.alert_reason().begins_with("BELT FULL"), true)
	_is("and asks for the jam sign", arm.alert_icon(), "jam")
	_is("after two failed attempts, not one", arm._hold_tries >= RoboticArm.ALERT_TRIES, true)

	watch.force_sweep(MachineWatch.POLL)
	_is("a sign is standing over it", watch.alert_icon(arm), "jam")
	_is("...saying what the machine says", watch.alert_reason(arm), arm.alert_reason())
	print("  sign text: %s" % watch.alert_reason(arm))


	for i in 120:
		await get_tree().physics_frame
	_is("it waits at home holding the load", arm._phase == RoboticArm.Phase.PARK_HOLD
		and arm._payload_count > 0, true)
	_is("...and the sign stays up while it waits", arm.alert_reason().begins_with("BELT FULL"), true)


func _room() -> void:
	var builds: BuildManager = world.builds
	var base:= Vector3(11.8, 0.06, 4.0)
	var line:= builds.add_conveyor(base + Vector3(1.8, 0.45, -6.0),
		base + Vector3(1.8, 0.45, 4.0))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	if "--busy" in OS.get_cmdline_user_args():
		Tech.grant("arm_payload", 6)
	for i in SETTLE:
		await get_tree().physics_frame
	if line == null or arm == null:
		_fail("the belt and the arm were built")
		return
	var count:= Tech.arm_capacity(int(arm.tier_data() ["capacity"]))
	var pick:= arm._choose_drop(count)
	if pick.is_empty():
		_fail("an empty belt has room for a load")
		return
	var release: Vector3 = pick ["point"]
	var speed:= Tech.belt_speed()


	var down:= release if arm._boards_as_record(line, count) else line.landing_point(release, speed)
	var s_land:= float(line._nearest(down) ["s"])


	var half:= float(line.shape_of_kind(BeltRun.Kind.WAD, count) ["reach"])
	print("\n=== the belt the arm asks for around one drop ===")
	print("  load %d strands, %.3f m long on the belt, charged %.3f by the claw, landing at s %.2f"
		% [count, half * 2.0, arm._footprint(count) * 2.0, s_land])
	for strands in [60, count, Cfg.WAD_MAX_STRANDS]:
		var reach:= float(line.shape_of_kind(BeltRun.Kind.WAD, strands) ["reach"])
		var ahead:= _nearest_allowed(line, arm, release, count, s_land, strands, 1.0)
		var behind:= _nearest_allowed(line, arm, release, count, s_land, strands, -1.0)
		if ahead < 0.0 or behind < 0.0:
			_fail("a neighbour of %d strands was placed both sides" % strands)
			continue
		var clear:= ahead + behind - reach * 2.0
		print("  beside %3d strand wads (%.3f m): ahead %.2f, behind %.2f, window %.2f m centre to centre, %.2f m clear deck for %.3f m of load (%.2f m spare)"
			% [strands, reach * 2.0, ahead, behind, ahead + behind, clear,
				half * 2.0, clear - half * 2.0])


		if ahead < reach + half - 0.005 or behind < reach + half - 0.005:
			_fail("the arm would let go overlapping a %d strand neighbour" % strands)


func _nearest_allowed(line: Conveyor, arm: RoboticArm, release: Vector3,
		count: int, s_land: float, strands: int, dir: float) -> float:
	var best:= -1.0
	for cm in range(250, 1, -1):
		var d:= float(cm) * 0.01
		var s:= s_land + dir * d
		if s < 0.0 or s > line.path_length():
			continue
		var seq:= line.push_record(BeltRun.Kind.WAD, strands, 0, null,
			line._point_at(s), 0.0)
		if seq < 0:
			continue
		var ok:= arm._room_on(line, release, count)
		for i in range(line.run.first(), line.run.first() + line.run.count()):
			if line.run.seq_of(i) == seq:
				line.take_record_at(i)
				break
		if not ok:
			break
		best = d
	return best


func _cost() -> void:
	var builds: BuildManager = world.builds
	var arms: Array [RoboticArm] = []


	for i in 8:
		var base:= Vector3(-14.0 + float(i) * 4.0, 0.06, -6.0)
		var apex:= base + Vector3(1.6, 0.45, 0.0)
		builds.add_conveyor(apex + Vector3(0.0, 0.0, -3.0), apex)
		builds.add_conveyor(apex, apex + Vector3(3.0, 0.0, 0.0))
		var arm:= builds.add_robotic_arm(base, 0.0, 1)
		if arm != null:
			arms.append(arm)
	for i in SETTLE:
		await get_tree().physics_frame
	print("  %d arms, %d runs, %d bends"
		% [arms.size(), builds.conveyors.size(), builds.corners.size()])
	if arms.is_empty():
		_fail("the fixture stood its arms up")
		return

	for leg in ["--oldaim (before)", "the gap aim and bends"]:
		BuildManager.legacy_arm_aim = leg.begins_with("--oldaim")

		for pass_i in 2:
			var t:= Time.get_ticks_usec()
			for i in CALLS:
				var arm: RoboticArm = arms [i % arms.size()]
				builds.conveyor_drops(arm._shoulder_world(), arm.reach_m() * 0.98)
			var list_us:= float(Time.get_ticks_usec() - t) / float(CALLS)
			t = Time.get_ticks_usec()
			for i in CALLS:
				var arm: RoboticArm = arms [i % arms.size()]
				arm._choose_drop(60)
			var choose_us:= float(Time.get_ticks_usec() - t) / float(CALLS)
			if pass_i == 1:
				print("  %-22s  list %6.1f us   choose a spot %7.1f us"
					% [leg, list_us, choose_us])


	for i in 60:
		var apex:= Vector3(-30.0 + float(i % 20) * 3.0, 0.45, 20.0 + float(i / 20) * 4.0)
		builds.add_conveyor(apex + Vector3(0.0, 0.0, -2.5), apex)
		builds.add_conveyor(apex, apex + Vector3(2.5, 0.0, 0.0))
	for i in SETTLE:
		await get_tree().physics_frame
	print("  then %d runs and %d bends, most of them far away"
		% [builds.conveyors.size(), builds.corners.size()])
	for leg in ["--oldaim (before)", "the gap aim and bends"]:
		BuildManager.legacy_arm_aim = leg.begins_with("--oldaim")
		for pass_i in 2:
			var t:= Time.get_ticks_usec()
			for i in CALLS:
				var arm: RoboticArm = arms [i % arms.size()]
				builds.conveyor_drops(arm._shoulder_world(), arm.reach_m() * 0.98)
			var list_us:= float(Time.get_ticks_usec() - t) / float(CALLS)
			if pass_i == 1:
				print("  %-22s  list %6.1f us" % [leg, list_us])
	BuildManager.legacy_arm_aim = false


const CALLS:= 2000


func _bend() -> void:
	var builds: BuildManager = world.builds
	var base:= Vector3(11.8, 0.06, 4.0)
	var apex:= base + Vector3(1.6, 0.45, 0.0)
	builds.add_conveyor(apex + Vector3(0.0, 0.0, -4.0), apex)
	builds.add_conveyor(apex, apex + Vector3(4.0, 0.0, 0.0))
	var arm:= builds.add_robotic_arm(base, 0.0, 1)
	for i in SETTLE:
		await get_tree().physics_frame
	if builds.corners.is_empty() or arm == null:
		_fail("the L was built with a bend in it, and the arm")
		return
	var corner: ConveyorCorner = builds.corners [0]
	var seen:= false
	for pick in builds.conveyor_drops(arm._shoulder_world(), arm.reach_m() * 0.98):
		if pick ["conveyor"] == corner:
			seen = true
			print("  the bend is %.2f m from the shoulder"
				% sqrt(float(pick ["distance2"])))
	if not seen:
		_fail("the bend is on the arm's list of places to drop")
		return
	print("  ok    the bend is on the arm's list of places to drop")
	if arm._choose_drop(60, null, corner).is_empty():
		_fail("an empty bend has room for a load")
		return
	print("  ok    an empty bend has room for a load")


	var onto_bend:= 0
	var loads:= 0
	var was:= arm._phase
	for f in 2400:
		if was == RoboticArm.Phase.DESCEND_DROP and arm._phase == RoboticArm.Phase.OPEN_CLAWS:
			loads += 1
			if arm._drop_run == corner:
				onto_bend += 1
		was = arm._phase
		await get_tree().physics_frame
	print("  %d loads let go, %d of them onto the bend" % [loads, onto_bend])
	if onto_bend == 0:
		_fail("the arm put a load on the bend")


	var mid:= corner._point_at(corner.path_length() * 0.5)
	var loose:= 0
	for body in world.props.get_children():
		if not body is HayWad:
			continue
		var at:= (body as HayWad).global_position
		if at.y < apex.y - 0.2 and Vector2(at.x - mid.x, at.z - mid.z).length() < 1.0:
			loose += 1
	print("  %d wads lying on the floor under the bend" % loose)
	if loose > 0:
		_fail("a load let go over the bend missed the deck")


func _finish() -> void:
	print("\n[arm-gap] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	print("  FAIL  %s" % message)
	_failures += 1


func _is(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok    %s = %s" % [label, got])
	else:
		_fail("%s = %s, expected %s" % [label, got, want])
