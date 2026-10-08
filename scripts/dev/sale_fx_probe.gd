class_name DevSaleFxProbe
extends Node


const TIMEOUT:= 10.0

const SETTLE:= 1.2

const EYE:= Vector3(-2.1, 1.62, 5.37)
const LOOK:= Vector3(1.4, 1.05, 2.9)


const SHOTS:= [0.05, 0.14, 0.24]

var world: Node3D
var stand: HaySellingStand
var props: PropManager
var live: LiveStrandManager
var player: Player
var out_dir:= ""

var _fx: SaleFx


func run() -> void:
	world.block_save = true
	_fx = stand.get("_sale_fx") as SaleFx
	if _fx == null:
		print("  FAIL  the stand has no SaleFx")
		print("\n[probe] 1 FAILURE(S)")
		get_tree().quit(1)
		return
	_clear_yard()
	_stand_at()
	var fails:= 0
	fails += await _body_case("wad", "hay_wad", { "strands": Cfg.WAD_MAX_STRANDS })
	fails += await _body_case("bale", "hay_bale", { })
	fails += await _tool_case()
	fails += await _strand_case()
	fails += await _record_case()
	fails += await _stress_case()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _body_case(label: String, id: String, extra: Dictionary) -> int:
	print("\n-- %s on the intake --" % label)
	var at:= stand.belt_entry_point() + Vector3.UP * 0.35
	var item:= props.spawn(id, Transform3D(Basis.IDENTITY, at), extra)
	if item == null:
		return _fail("could not spawn a %s" % label)
	return await _watch(label, 1, false)


func _tool_case() -> int:
	print("\n-- spade on the intake --")
	var at:= stand.belt_entry_point() + Vector3.UP * 0.6
	var item:= props.spawn("spade", Transform3D(stand.global_transform.basis, at))
	if item == null:
		return _fail("could not spawn a spade")
	var gulps:= _fx.gulps
	var bad:= await _watch("spade", 1, false)
	if _fx.gulps != gulps:
		bad += _fail("a tool went into the bag; it belongs in the register")
	return bad


func _strand_case() -> int:
	print("\n-- loose strands on the intake --")
	var basis:= stand.global_transform.basis
	var at:= stand.belt_entry_point() + Vector3.UP * 0.12
	var made:= 0
	for i in 24:
		if live.spawn(at + basis.x * (0.2 + 0.12 * float(i)), Basis.IDENTITY,
				Vector3.ZERO, Color.WHITE) != null:
			made += 1
	if made == 0:
		return _fail("could not put strands on the belt")
	return await _watch("strands", 8, true)


func _record_case() -> int:
	print("\n-- a record off a sealed run --")
	var belt:= stand.get("_belt") as BeltPath
	if belt == null:
		return _fail("the stand has no belt")
	var flown:= _fx.flown
	var gulps:= _fx.gulps
	var rec:= { "kind": BeltRun.Kind.WAD, "strands": 40, "s": belt.run.length() - 0.3,
		"side": 0.0, "lift": 0.0 }
	_fx.swallow_record(rec, belt.run)
	var drawn:= not BeltRunBatch.picture_of(BeltRun.Kind.WAD, 40).is_empty()
	if drawn and _fx.flown == flown:
		return _fail("a record with a picture did not fly")
	if not drawn and _fx.gulps == gulps:
		return _fail("a record with no picture did not even gulp")
	print("  %s" % ("flew as its belt picture" if drawn
		else "no belt drawer here, so it gulped without a picture"))
	if drawn:
		await _photograph("record")
	return await _settle("record")


const STRESS_SECONDS:= 3.0
const STRESS_STRANDS:= 1000
const STRESS_WADS:= 300


const STRESS_BUDGET_USEC:= 1000


func _stress_case() -> int:
	print("\n-- torrent: %d strands, %d wads and a record a tick, for %.0f s --"
		% [STRESS_STRANDS, STRESS_WADS, STRESS_SECONDS])
	var belt:= stand.get("_belt") as BeltPath
	var tick_rate:= float(Engine.get_physics_ticks_per_second())
	var step:= 1.0 / tick_rate
	var mouth:= stand.mouth_centre()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var strand_owed:= 0.0
	var wad_owed:= 0.0
	var frames:= 0
	var total:= 0
	var worst:= 0
	var most_flying:= 0
	var most_strands:= 0
	var t:= 0.0
	while t < STRESS_SECONDS:
		strand_owed += STRESS_STRANDS * step
		wad_owed += STRESS_WADS * step
		var wads: Array [Carryable] = []
		while wad_owed >= 1.0:
			wad_owed -= 1.0
			var at:= mouth + Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.3, 0.3))
			var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at), { "strands": 40 })
			if wad != null:
				wads.append(wad)
		var began:= Time.get_ticks_usec()
		while strand_owed >= 1.0:
			strand_owed -= 1.0
			var at:= mouth + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.3),
				rng.randf_range(-0.3, 0.3))
			_fx.swallow_strand([Transform3D(Basis.IDENTITY, at), Color(0.9, 0.8, 0.5)])
		for wad in wads:
			_fx.swallow(wad, 40.0)
		if belt != null:
			_fx.swallow_record({ "kind": BeltRun.Kind.WAD, "strands": 40,
				"s": belt.run.length() - 0.3, "side": 0.0, "lift": 0.0 }, belt.run)
		var calls:= Time.get_ticks_usec() - began
		for wad in wads:
			props.remove(wad)
		await get_tree().physics_frame
		t += step
		_stand_at()

		var cost:= calls + _fx.tick_usec
		total += cost
		worst = maxi(worst, cost)
		frames += 1
		var flying:= 0
		for f in _fx.get("_flights"):
			if f.busy:
				flying += 1
		most_flying = maxi(most_flying, flying)
		most_strands = maxi(most_strands, int(_fx.get("_s_count")))
	var bad:= 0
	var avg:= float(total) / maxf(float(frames), 1.0)
	print("  %d frames: %.0f us a frame on average, %d us at worst" % [frames, avg, worst])
	print("  at most %d of %d loads and %d of %d strands in the air"
		% [most_flying, SaleFx.FLIGHTS, most_strands, SaleFx.STRAND_FLIGHTS])
	if most_flying > SaleFx.FLIGHTS or most_strands > SaleFx.STRAND_FLIGHTS:
		bad += _fail("a cap was passed")
	if worst > STRESS_BUDGET_USEC:
		bad += _fail("the effect took %d us in one frame, budget %d" % [worst, STRESS_BUDGET_USEC])
	bad += await _settle("torrent")
	return bad


func _watch(label: String, want: int, strands: bool) -> int:
	var flown:= _fx.flown
	var gulps:= _fx.gulps
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var t:= 0.0
	while t < TIMEOUT and _fx.flown < flown + want and _fx.gulps == gulps:
		await get_tree().physics_frame
		t += step
		_stand_at()
	if _fx.flown == flown and _fx.gulps == gulps:
		return _fail("%s: nothing sold after %.1f s" % [label, TIMEOUT])
	if _fx.flown == flown:
		if _pictures_possible():
			return _fail("%s: sold with a gulp and no flight" % label)
		print("  sold as a record after %.2f s: gulped, no picture without a drawer" % t)
		return await _settle(label)

	while strands and t < TIMEOUT and _fx.flown < flown + want:
		await get_tree().physics_frame
		t += step
		_stand_at()
	print("  launched after %.2f s" % t)
	if not strands and _fx.flown > flown and _busy_models() == 0 and not _record_in_air():
		return _fail("%s: a flight launched with nothing in it" % label)
	await _photograph(label)
	return await _settle(label)


func _pictures_possible() -> bool:
	return not BeltRunBatch.picture_of(BeltRun.Kind.WAD, 40).is_empty()


func _record_in_air() -> bool:
	for f in _fx.get("_flights"):
		if f.busy and f.model == null:
			return true
	return false


func _settle(label: String) -> int:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var t:= 0.0
	var quiet:= 0.0
	while t < TIMEOUT and quiet < SETTLE:
		await get_tree().physics_frame
		t += step
		_stand_at()
		quiet = quiet + step if not _fx.is_processing() else 0.0
	var bad:= 0
	if _fx.landed != _fx.flown:
		bad += _fail("%s: %d flown, %d landed" % [label, _fx.flown, _fx.landed])
	if _busy_models() > 0:
		bad += _fail("%s: a model is still in the air" % label)
	if _fx.sack != null and not _fx.sack.scale.is_equal_approx(Vector3.ONE):
		bad += _fail("%s: the bag was left at scale %.3v" % [label, _fx.sack.scale])
	if bad == 0:
		print("  all %d landed, bag back to its size, %d gulps so far"
			% [_fx.landed, _fx.gulps])
	return bad


func _busy_models() -> int:
	var n:= 0
	for f in _fx.get("_flights"):
		if f.busy and f.model != null:
			n += 1
	return n


func _photograph(label: String) -> void:
	if out_dir.is_empty():
		return
	var tree:= get_tree()
	var clock:= 0.0
	for i in SHOTS.size():
		while clock < float(SHOTS [i]):
			await tree.process_frame
			clock += get_process_delta_time()
			_stand_at()


		tree.paused = true
		await RenderingServer.frame_post_draw
		var path:= "%s/salefx_%s_%d.png" % [out_dir, label, i]
		get_viewport().get_texture().get_image().save_png(path)
		print("  wrote %s" % path)
		tree.paused = false


func _stand_at() -> void:
	if player == null:
		return
	var at:= stand.to_global(EYE)
	var target:= stand.to_global(LOOK)
	player.global_position = at
	player.look_at_from_position(at, Vector3(target.x, at.y, target.z), Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		var flat:= Vector2(target.x - at.x, target.z - at.z).length()
		player.head.rotation.x = atan2(target.y - at.y, flat)


func _clear_yard() -> void:
	var builds:= world.get("builds") as BuildManager
	if builds != null:
		for arm in builds.robotic_arms.duplicate():
			if is_instance_valid(arm):
				arm.queue_free()
		builds.robotic_arms.clear()
	if props != null:
		props.clear()


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1
