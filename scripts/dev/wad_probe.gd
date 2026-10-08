class_name DevWadProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 6.0)
	GameState.add_money(200000.0)


	Tech.ranks ["arm_small"] = 1
	Tech.ranks ["arm_payload"] = 8

	BeltPath.debug_props = true
	for i in SETTLE:
		await get_tree().process_frame

	await _check_model()
	await _check_split()
	await _check_arm_conservation()
	await _check_belt_ride()
	await _check_overlapped_pair()
	await _check_rail_wad()
	await _check_landing_room()
	await _check_bucket_intake()
	await _check_save()
	await _check_lods()

	print("\n=== wad probe: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check_lods() -> void:
	print("\r\n=== levels of detail ===")
	var meshes:= HayWad.shared_meshes()
	_ok("every level came out of the model", meshes.size() >= 4)
	if meshes.size() < 2:
		return
	var tris: Array [int] = []
	for mesh in meshes:
		var n:= 0
		for i in mesh.get_surface_count():
			n += mesh.surface_get_arrays(i) [Mesh.ARRAY_INDEX].size() / 3
		tris.append(n)
	print("      triangles: %s" % [tris])
	var falling:= true
	for i in range(1, tris.size()):
		falling = falling and tris [i] < tris [i - 1]
	_ok("each level is cheaper than the one before it", falling)

	_ok("the close level stays within 12400 triangles", tris [0] <= 12400)
	_ok("the far level stays within 450 triangles", tris [-1] <= 450)

	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(12.0, 1.0, 8.0)), { "strands": 50 }) as HayWad
	if wad == null:
		_ok("a wad to read the ranges off", false)
		return
	_ok("one instance, whatever the level", wad._meshes.size() == 1)
	var cuts: PackedFloat32Array = wad._lod_cuts()
	_ok("a cut per level", cuts.size() == meshes.size())
	_ok("the last one runs to the horizon", not cuts.is_empty() and is_zero_approx(cuts [-1]))


	var scale: float = wad._lod_scale()
	var each_band:= true
	var prev:= 0.0
	for i in cuts.size():
		var end: float = cuts [i] * scale
		var d: float = (prev + end) * 0.5 if end > 0.0 else prev + 10.0
		wad._pick_lod(wad.global_position + Vector3(d, 0.0, 0.0))
		each_band = each_band and wad._lod == i
		prev = end
	_ok("each level shows in its own band of distance", each_band)
	_ok("the instance carries the level picked", wad._meshes [0].mesh == meshes [wad._lod])


	var mid: float = (cuts [0] + cuts [1]) * 0.5 * scale
	var eye:= wad.global_position + Vector3(mid, 0.0, 0.0)
	wad._pick_lod(eye)
	var base_lod: int = wad._lod
	wad.set_strands(Cfg.WAD_BASE_STRANDS * 8)
	wad._pick_lod(eye)
	_ok("a bigger wad holds its detail further out",
		base_lod == 1 and wad._lod == 0
		and absf(wad._lod_scale() / maxf(scale, 0.001) - 2.0) < 0.01)
	world.props.remove(wad)


func _check_model() -> void:
	print("\n=== model ===")
	_ok("shared mesh loads", HayWad.shared_mesh() != null)
	_ok("material table loads", not HayWad.spec_table().is_empty())
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(12.0, 1.0, 6.0)), { "strands": 50 }) as HayWad
	_ok("spawns as a HayWad", wad != null)
	if wad == null:
		return
	_ok("carries its count", wad.strands == 50)
	_ok("is a prop, not a strand",
		(wad.collision_layer & Cfg.L_PROP) != 0
		and (wad.collision_layer & Cfg.L_STRAND) == 0)


	_ok("base scale is the pack density",
		is_equal_approx(HayWad.scale_for(Cfg.WAD_BASE_STRANDS), Cfg.WAD_PACK))
	_ok("scale is a cube root",
		absf(HayWad.scale_for(Cfg.WAD_BASE_STRANDS * 8)
			/ HayWad.scale_for(Cfg.WAD_BASE_STRANDS) - 2.0) < 0.001)


	_ok("a base wad fits in one hand",
		Cfg.WAD_BASE_SIZE.x * HayWad.scale_for(Cfg.WAD_BASE_STRANDS) < 0.25)
	var big:= world.props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(13.5, 1.0, 6.0)), { "strands": 191 }) as HayWad
	if big != null:
		_ok("a bigger wad is heavier", big.mass > wad.mass)
		_ok("mass is capped", big.mass <= Cfg.WAD_MASS_MAX + 0.001)
		world.props.remove(big)
	world.props.remove(wad)


func _check_split() -> void:
	print("\n=== splitting a load into wads ===")
	_ok("a tiny load is not wadded",
		HayWad.split(Cfg.WAD_MIN_STRANDS - 1).is_empty())
	_ok("the smallest wad is one object",
		HayWad.split(Cfg.WAD_MIN_STRANDS).size() == 1)


	var full:= Tech.arm_capacity(int(Cfg.ROBOT_ARM_TIERS [2] ["capacity"]))
	_ok("a full arm load is one wad (%d strands)" % full,
		HayWad.split(full).size() == 1)
	for n in [Cfg.WAD_MIN_STRANDS, 50, 137, 191, 200, 201, 640]:
		var parts:= HayWad.split(n)
		var total:= 0
		for c in parts:
			total += c
		_ok("split(%d) conserves the count" % n, total == n)
		var oversize:= false
		for c in parts:
			if c > Cfg.WAD_MAX_STRANDS:
				oversize = true
		_ok("split(%d) makes no oversize wad" % n, not oversize)


func _check_arm_conservation() -> void:
	print("\n=== arm conservation at full payload ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(9.0, deck_y, -6.0)
	var b:= Vector3(9.0, deck_y, 2.0)
	world.builds.add_conveyor(a, b)
	var arm: RoboticArm = world.builds.add_robotic_arm(
		Vector3(11.2, 0.0, -2.0), 0.0, 2)
	_ok("arm was handed a PropManager", arm.props != null)
	for i in SETTLE:
		await get_tree().physics_frame


	var dug_before:= GameState.hay_dug
	var held_before:= _hay_outside_pile()
	var cycles_before:= arm.completed_cycles

	for i in 900:
		await get_tree().physics_frame
		if arm.completed_cycles - cycles_before >= 3:
			break
	var done:= arm.completed_cycles - cycles_before
	_ok("the arm completed cycles (%d)" % done, done > 0)
	var dug:= GameState.hay_dug - dug_before
	var held:= _hay_outside_pile() - held_before
	_ok("the arm actually dug (%.0f strands)" % dug, dug > 0.0)


	_ok("hay is conserved: dug %.0f, held %.0f" % [dug, held],
		held >= dug * 0.95)


	var loads:= _wad_loads()
	_ok("the load was put down as wads (%d, %d of them bodies)"
		% [loads.size(), _wads().size()], loads.size() > 0)

	_ok("no more wads than cycles run", loads.size() <= done + 1)
	if not loads.is_empty():
		_ok("a wad holds a real load (%d strands)" % loads [0],
			loads [0] >= Cfg.WAD_MIN_STRANDS)


func _check_belt_ride() -> void:
	print("\r\n=== a wad rides a belt ===")


	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(-9.0, deck_y, -8.0)
	var b:= Vector3(-9.0, deck_y, 4.0)
	var conv: Conveyor = world.builds.add_conveyor(a, b)
	for i in SETTLE:
		await get_tree().physics_frame

	var run: BeltPath = conv
	_ok("the test belt has a path", run != null)
	if run == null:
		return
	print("  belt drive speed %.2f m/s" % run.drive_speed)

	var at:= a + Vector3(0.0, 0.02, 1.0)
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
		{ "strands": 60 }) as HayWad
	_ok("a wad was placed on the deck", wad != null)
	if wad == null:
		return


	var seq:= -1
	for i in 60:
		await get_tree().physics_frame
		if run.run.count() > 0:
			seq = run.run.seq_of(run.run.first())
			break
	_ok("the belt took the wad aboard as a record", seq >= 0)
	if seq < 0:
		if is_instance_valid(wad):
			world.props.remove(wad)
		return
	var where:= BeltPath.record_where(seq)
	var from_s:= float(where ["s"])
	var from: Vector3 = (where ["pose"] as Transform3D).origin
	print("  boarded %.2f m up the run, at %.2f, %.2f, %.2f"
		% [from_s, from.x, from.y, from.z])
	var moved:= 0.0
	for i in 240:
		await get_tree().physics_frame
		where = BeltPath.record_where(seq)
		if where.is_empty():
			break
		moved = float(where ["s"]) - from_s
		if moved > 1.0:
			break
	if where.is_empty():
		_ok("the wad travelled and was taken downstream", true)
		return
	var to: Vector3 = (where ["pose"] as Transform3D).origin
	print("  now %.2f m up the run, at %.2f, %.2f, %.2f" % [float(where ["s"]), to.x, to.y, to.z])
	_ok("the wad moved along the deck (%.2f m)" % moved, moved > 0.5)


	var along:= (b - a).normalized().dot(to - from)
	_ok("it moved downstream (%.2f m along the run)" % along, along > 0.5)
	_clear_records(run)


func _check_overlapped_pair() -> void:
	print("\n=== two wads inside each other are both taken ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(-6.0, deck_y, -8.0)
	var mid:= Vector3(-6.0, deck_y, -2.0)
	var b:= Vector3(-6.0, deck_y, 4.0)

	var first: Conveyor = world.builds.add_conveyor(a, mid)
	var second: Conveyor = world.builds.add_conveyor(mid, b)
	for i in SETTLE:
		await get_tree().physics_frame
	if first == null or second == null:
		_ok("the two test belts have paths", false)
		return


	var w1:= world.props.spawn("hay_wad", Transform3D(Basis(), a + Vector3(0.0, 0.02, 1.0)),
		{ "strands": 197 }) as HayWad
	var w2:= world.props.spawn("hay_wad", Transform3D(Basis(), a + Vector3(0.0, 0.02, 1.05)),
		{ "strands": 197 }) as HayWad
	if w1 == null or w2 == null:
		_ok("two wads were placed inside each other", false)
		return


	var both:= false
	var seqs:= PackedInt32Array()
	for i in 90:
		await get_tree().physics_frame
		seqs = _record_seqs([first, second])
		if seqs.size() >= 2:
			both = true
			break
	_ok("both are taken aboard", both)
	if not both:
		if is_instance_valid(w1):
			world.props.remove(w1)
		if is_instance_valid(w2):
			world.props.remove(w2)
		_clear_records(first)
		_clear_records(second)
		return
	await get_tree().physics_frame
	var p1:= BeltPath.record_where(seqs [0])
	var p2:= BeltPath.record_where(seqs [1])
	var apart:= _record_gap(p1, p2)
	var need:= _record_reach(p1) + _record_reach(p2)
	_ok("...one behind the other (%.2f m apart, need %.2f)" % [apart, need], apart >= need - 0.01)


	var dir:= (b - mid).normalized()
	var steps:= int((7.0 / maxf(first.drive_speed, 0.01)) / maxf(get_physics_process_delta_time(), 1e-06))
	var closest:= INF
	var past:= false
	for i in steps:
		await get_tree().physics_frame
		p1 = BeltPath.record_where(seqs [0])
		p2 = BeltPath.record_where(seqs [1])
		if p1.is_empty() or p2.is_empty():
			break
		closest = minf(closest, _record_gap(p1, p2))
		if ((p1 ["pose"] as Transform3D).origin - mid).dot(dir) > 1.0 and ((p2 ["pose"] as Transform3D).origin - mid).dot(dir) > 1.0:
			past = true
			break
	var on_belt:= not p1.is_empty() and not p2.is_empty()
	_ok("...and both cross the seam still on the belt", on_belt)
	_ok("...never inside each other on the way (closest %.2f m)" % closest, closest >= need - 0.03)
	_ok("...and both still carried past it", on_belt and past)
	_clear_records(first)
	_clear_records(second)


func _record_gap(p1: Dictionary, p2: Dictionary) -> float:
	if p1.is_empty() or p2.is_empty():
		return NAN
	return (p1 ["pose"] as Transform3D).origin.distance_to((p2 ["pose"] as Transform3D).origin)


func _record_reach(p: Dictionary) -> float:
	if p.is_empty():
		return 0.0
	return float((p ["path"] as BeltPath).run.reach_of(int(p ["row"])))


func _check_rail_wad() -> void:
	print("\n=== a wad on the rail is pulled back in ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(-3.0, deck_y, -8.0)
	var b:= Vector3(-3.0, deck_y, 4.0)
	var conv: Conveyor = world.builds.add_conveyor(a, b)
	for i in SETTLE:
		await get_tree().physics_frame
	if conv == null:
		_ok("the test belt has a path", false)
		return


	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), a + Vector3(0.36, 0.15, 1.0)),
		{ "strands": 197 }) as HayWad
	if wad == null:
		_ok("a wad was placed on the rail", false)
		return
	var band: float = BeltPath._ride_half_width(float(BeltPath.load_shape(wad) ["reach"]))
	var wad_id:= wad.get_instance_id()


	var taken:= false
	var side:= NAN
	var elapsed:= 0.0
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	while elapsed < 6.0:
		await get_tree().physics_frame
		elapsed += step
		if conv.run.count() > 0:
			taken = true
			side = absf(conv.run.side_of(conv.run.first()))
			break
	print("  taken after %.1f s, centre %.2f m off the line (band %.2f), last refused for: %s"
		% [elapsed, side, band, str(BeltPath.debug_last_refusal.get(wad_id, "never asked"))])
	_ok("a wad left on the rail is taken within a few seconds", taken)
	if taken:
		_ok("...inside the ride band", side <= band + 0.02)
	if is_instance_valid(wad):
		world.props.remove(wad)


	_clear_records(conv)
	world.builds.demolish(conv)


func _check_landing_room() -> void:
	print("\n=== room to land ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var a:= Vector3(-3.0, deck_y, -8.0)
	var b:= Vector3(-3.0, deck_y, 4.0)
	var conv: Conveyor = world.builds.add_conveyor(a, b)
	for i in SETTLE:
		await get_tree().physics_frame
	var run: BeltPath = conv
	if run == null:
		_ok("the test belt has a path", false)
		return
	var half:= Cfg.WAD_BASE_SIZE.x * 0.5 * HayWad.scale_for(197)
	var fwd:= (b - a).normalized()
	var mid:= a + fwd * 6.0 + Vector3.UP * 0.26
	_ok("an empty run has room to land in the middle", run.has_room_to_land(mid, 0.0, 0.5, half))
	_ok("...but not in its far dead zone, which the next belt owns",
		not run.has_room_to_land(b - fwd * 0.03 + Vector3.UP * 0.26, 0.0, 0.0, half))
	_ok("...nor closer to its start than the lead it needs behind it",
		not run.has_room_to_land(a + fwd * 0.3 + Vector3.UP * 0.26, 0.0, 1.0, half))


	var speed:= 3.2
	var flight:= speed * sqrt(2.0 * 0.26 / 9.8)
	print("  at %.1f m/s a load let go 26 cm up flies %.2f m" % [speed, flight])
	_ok("a fast release near the end lands in the dead zone and is refused",
		not run.has_room_to_land(b - fwd * (flight * 0.5) + Vector3.UP * 0.26, speed, 0.0, half))
	_ok("...and the same release well back is fine",
		run.has_room_to_land(a + fwd * 4.0 + Vector3.UP * 0.26, speed, 0.5, half))


	conv.set_drive_speed(0.0)
	var behind:= world.props.spawn("hay_wad",
		Transform3D(Basis(), a + fwd * 5.2 + Vector3.UP * 0.02), { "strands": 60 }) as HayWad


	var parked:= false
	for i in 60:
		await get_tree().physics_frame
		if run.run.count() > 0:
			parked = true
			break
	_ok("a wad parked 80 cm behind the spot is aboard as a record", parked)
	if parked:
		_ok("...and refuses a landing that needs a metre behind it",
			not run.has_room_to_land(mid, 0.0, 1.0, half))
		_ok("...but not one that needs 20 cm",
			run.has_room_to_land(mid, 0.0, 0.2, half))
	if behind != null and is_instance_valid(behind):
		world.props.remove(behind)
	_clear_records(run)
	conv.set_drive_speed(Tech.belt_speed())


func _check_bucket_intake() -> void:
	print("\n=== a bucket takes a wad ===")
	var spot:= Vector3(14.0, 0.0, 8.0)
	var bucket: Bucket = world.props.spawn("bucket", Transform3D(Basis(), spot)) as Bucket
	if bucket == null:
		_ok("SKIPPED: no bucket", true)
		return
	for i in SETTLE:
		await get_tree().physics_frame


	var over:= Cfg.BUCKET_CAPACITY + 120
	bucket.stored = Cfg.BUCKET_CAPACITY - 40
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), bucket.global_position + Vector3(0, 0.6, 0)),
		{ "strands": mini(over, Cfg.WAD_MAX_STRANDS) }) as HayWad
	var put: int = wad.strands if wad != null else 0
	var had:= bucket.stored
	for i in 120:
		await get_tree().physics_frame
	var gained:= bucket.stored - had
	_ok("the bucket took hay from the wad (%d)" % gained, gained > 0)
	_ok("it took only what fits", bucket.stored <= Cfg.BUCKET_CAPACITY)
	var left: int = wad.strands if is_instance_valid(wad) else 0
	_ok("the remainder stayed in the wad (%d + %d == %d)" % [gained, left, put],
		gained + left == put)
	if is_instance_valid(wad):
		world.props.remove(wad)
	world.props.remove(bucket)


func _check_save() -> void:
	print("\n=== a wad survives a save ===")
	var wad:= world.props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(15.0, 1.0, 10.0)), { "strands": 137 }) as HayWad
	if wad == null:
		_ok("SKIPPED: no wad", true)
		return
	var state:= wad.to_state()
	_ok("state carries the count", int(state.get("strands", 0)) == 137)
	world.props.remove(wad)
	var back:= world.props.spawn("hay_wad",
		Transform3D(Basis(), Vector3(15.0, 1.0, 10.0)), state) as HayWad
	_ok("it comes back with the same count",
		back != null and back.strands == 137)
	if back != null:

		_ok("and at the size that count implies",
			absf(HayWad.scale_for(back.strands) - HayWad.scale_for(137)) < 0.0001)
		world.props.remove(back)


func _hay_outside_pile() -> float:
	var n:= float(world.live.active_count())
	for item in world.props.items:
		if item is HayWad:
			n += float((item as HayWad).strands)
		elif item is HayBale:
			n += float((item as HayBale).strands)


	for c in world.builds.conveyors:
		var run: BeltRun = (c as BeltPath).run
		for i in range(run.first(), run.first() + run.count()):
			n += float(run.strands_of(i))
	for s2 in world.builds.scanners:
		n += float(s2.stored + s2._outgoing)
	for p2 in world.builds.compressors:
		n += float(p2.stored)
	return n


func _wad_loads() -> Array [int]:
	var out: Array [int] = []
	for w in _wads():
		out.append(w.strands)
	for c in world.builds.conveyors:
		var run: BeltRun = (c as BeltPath).run
		for i in range(run.first(), run.first() + run.count()):
			if run.kind_of(i) == BeltRun.Kind.WAD:
				out.append(run.strands_of(i))
	return out


func _record_seqs(paths: Array) -> PackedInt32Array:
	var out:= PackedInt32Array()
	for p in paths:
		var run: BeltRun = (p as BeltPath).run
		for i in range(run.first(), run.first() + run.count()):
			out.append(run.seq_of(i))
	return out


func _clear_records(p: BeltPath) -> void:
	while p.run.count() > 0:
		p.take_record_at(p.run.first())


func _wads() -> Array [HayWad]:
	var out: Array [HayWad] = []
	for item in world.props.items:
		if item is HayWad:
			out.append(item as HayWad)
	return out


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
