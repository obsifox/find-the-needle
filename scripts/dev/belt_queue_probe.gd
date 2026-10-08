class_name DevBeltQueueProbe
extends Node


const SETTLE:= 40


const RUN_SECONDS:= 17.6 / Cfg.BELT_SPEED


const LOADS:= 6


const FEED_EVERY_M:= 0.69


const TRACE_TICKS:= 90


const FILL_SECONDS:= 48.0 / Cfg.BELT_SPEED


const FILL_EVERY_M:= 1.07


const FILL_SHUT_M:= 3.0


const SEAM_LOADS:= 14


const SEAM_REACH:= 1.5


const SEAM_DOWN_LENGTH:= 2.5


const PRESS_SECONDS:= 70.0


const WRAP_SECONDS:= 60.0


const WRAP_EVERY_M:= 1.6


const JOINER_REACH:= 6.0

var world: Node3D
var player: Player

var _fails:= 0


static func _every(metres: float) -> int:
	return maxi(1, int(round(metres / maxf(Cfg.BELT_SPEED, 0.01)
		* float(Engine.physics_ticks_per_second))))


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame

	player.global_position = Vector3(11.0, 0.4, 0.0)
	GameState.add_money(20000.0)


	var ok:= await _case("wad", "hay_wad", { "strands": 60 },
		Cfg.WAD_BASE_SIZE.x * Cfg.WAD_COLLIDER_SHRINK * HayWad.scale_for(60),
		Vector3(13.0, 0.75, -6.0), Vector3(13.0, 0.75, 6.0), 0.22)


	ok = await _case("bale", "hay_bale", { },
		Cfg.COMPRESSOR_BALE_SIZE.z,
		Vector3(15.0, 0.75, -6.0), Vector3(15.0, 0.75, 6.0)) and ok


	ok = await _backs_up(Vector3(-6.0, 0.75, -12.5), Vector3(6.0, 0.75, -12.5)) and ok


	ok = await _across_a_seam() and ok


	ok = await _press_stops() and ok

	ok = await _wrapper_eats() and ok

	ok = await _joiner_merges() and ok
	_done(ok)


func _joiner_merges() -> bool:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var centre:= Vector3(-4.0, deck_y, 6.0)
	var joiner: ConveyorJoiner = world.builds.add_joiner(centre, 0.0)
	if joiner == null:
		print("[beltqueue] could not place the joiner")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame


	var feeds: Array [Conveyor] = []
	var heads: Array [Vector3] = []
	for side: int in ConveyorJoiner.SIDES:
		var port:= joiner.port(side)
		var head:= port - joiner.arm_travel(side).normalized() * 5.0
		var run: Conveyor = world.builds.add_conveyor(head, port)
		if run == null:
			print("[beltqueue] could not lay the arm %d feed" % side)
			_fails += 1
			return false
		feeds.append(run)
		heads.append(head)
	var out: Conveyor = world.builds.add_conveyor(joiner.port_out(),
		joiner.port_out() + (joiner.port_out() - centre).normalized() * 5.0)
	if out == null:
		print("[beltqueue] could not lay the joiner outfeed")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame
	out.set_outlet_held(true)

	print("\n=== bales merging at a joiner, outfeed held ===")
	print("  arms wired to the outfeed: %s"
		% str(joiner.arm(ConveyorJoiner.SIDES [0]).downstream == joiner.out_path()))

	var ticks:= int(WRAP_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var fed:= 0
	var wrap_every:= _every(WRAP_EVERY_M)
	var last:= [- wrap_every, - wrap_every]
	var worst:= INF
	var worst_pair:= ""
	for tick in ticks:
		for i in feeds.size():
			if tick - int(last [i]) >= wrap_every and _room_to_drop(heads [i], joiner.port(ConveyorJoiner.SIDES [i]), feeds [i]):
				if _drop("hay_bale", { }, heads [i],
						joiner.port(ConveyorJoiner.SIDES [i]),
						Cfg.COMPRESSOR_BALE_SIZE.z):
					fed += 1
					last [i] = tick
		await get_tree().physics_frame
		var now:= _closest_over(centre, JOINER_REACH)
		if now < worst:
			worst = now
			worst_pair = _closest_named

	print("  bales fed onto the two arms: %d" % fed)
	print("  standing around the wye    : %d" % _count_over(centre, JOINER_REACH))
	print("  closest two, either arm or the merge: %.3f m (nose to tail is %.3f)"
		% [0.0 if worst > 100000000.0 else worst, Cfg.COMPRESSOR_BALE_SIZE.z])
	if worst_pair != "":
		print("  ...which were %s" % worst_pair)

	var ok:= _check(fed >= 4, "both arms delivered bales into the merge")
	ok = _check(worst >= Cfg.COMPRESSOR_BALE_SIZE.z * 0.95,
		"no two bales were ever standing inside each other at the junction") and ok
	return ok


func _closest_over(centre: Vector3, reach: float) -> float:
	var bales:= _bales_near(centre, reach)
	var best:= INF
	for i in bales.size():
		for j in range(i + 1, bales.size()):
			var p:= bales [i].global_position
			var q:= bales [j].global_position
			var d:= Vector2(p.x - q.x, p.z - q.z).length()
			if d < best:
				best = d
				_closest_named = "%s at (%.2f, %.2f, %.2f) and %s at (%.2f, %.2f, %.2f)" % [
					bales [i].name, p.x, p.y, p.z, bales [j].name, q.x, q.y, q.z]
	return best


var _closest_named:= ""


func _count_over(centre: Vector3, reach: float) -> int:
	return _bales_near(centre, reach).size()


func _bales_near(centre: Vector3, reach: float) -> Array [Node3D]:
	var props: PropManager = world.props
	var out: Array [Node3D] = []
	for item in props.items:
		if not (item is HayBale) or not is_instance_valid(item) or not item.is_inside_tree():
			continue
		var p: Vector3 = (item as Node3D).global_position
		if Vector2(p.x - centre.x, p.z - centre.z).length() <= reach:
			out.append(item as Node3D)
	return out


func _wrapper_eats() -> bool:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var wrap: HayWrapper = world.builds.add_wrapper(Vector3(-9.0, deck_y, 8.0), 0.0)
	if wrap == null:
		print("[beltqueue] could not place the wrapper")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame


	var feed_a: Vector3 = wrap.port_in() - Vector3(0.0, 0.0, 7.0)
	var feed: Conveyor = world.builds.add_conveyor(feed_a, wrap.port_in())
	if feed == null:
		print("[beltqueue] could not lay the wrapper's feed run")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== a wrapper fed bales down a %.1f m run ===" % feed.path_length())
	print("  the run hands to the wrapper's deck: %s"
		% str(feed.downstream == wrap.deck()))

	var ticks:= int(WRAP_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var fed:= 0
	var wrap_every:= _every(WRAP_EVERY_M)
	var last_fed:= - wrap_every
	var wrapped:= 0
	var peak_queue:= 0
	var worst_loose:= INF
	var worst_any:= INF
	for tick in ticks:


		if tick - last_fed >= wrap_every and _room_to_drop(feed_a, wrap.port_in(), feed):
			if _drop("hay_bale", { }, feed_a, wrap.port_in(),
					Cfg.COMPRESSOR_BALE_SIZE.z):
				fed += 1
				last_fed = tick
		await get_tree().physics_frame
		peak_queue = maxi(peak_queue, wrap.queued.size())
		worst_loose = minf(worst_loose, _closest_loose_pair(feed_a, wrap.port_in()))


		var any:= _closest_bales(feed_a, wrap.port_out())
		if not any.is_empty():
			worst_any = minf(worst_any, float(any ["d"]))


	var left:= 0
	var props: PropManager = world.props
	for item in props.items:
		if item is HayBale and is_instance_valid(item) and item.is_inside_tree() and _off_segment((item as Node3D).global_position, feed_a,
					wrap.port_in()) <= SEAM_REACH:
			left += 1
	wrapped = fed - left

	print("  bales fed                : %d over %.0f s" % [fed, WRAP_SECONDS])
	print("  still on the line        : %d" % left)
	print("  taken in by the wrapper  : %d" % wrapped)
	print("  deepest its queue got    : %d of %d" % [peak_queue, wrap.buffer_capacity()])
	print("  its deck closed          : %s" % str(wrap.deck().is_blocked()))
	print("  closest LOOSE bale to another: %.3f m (nose to tail is %.3f)"
		% [0.0 if worst_loose > 100000000.0 else worst_loose, Cfg.COMPRESSOR_BALE_SIZE.z])
	print("  closest ANY two, run and deck : %.3f m"
		% (0.0 if worst_any > 100000000.0 else worst_any))

	var ok:= _check(wrapped > 0,
		"the wrapper actually took bales off the belt")
	ok = _check(peak_queue >= wrap.buffer_capacity(),
		"...enough of them to fill its buffer, which is what backs the line up") and ok
	ok = _check(worst_loose >= Cfg.COMPRESSOR_BALE_SIZE.z * 0.95,
		"...and no loose bale was ever wedged inside another one") and ok
	ok = _check(worst_any >= Cfg.COMPRESSOR_BALE_SIZE.z * 0.95,
		"...nor any two at all, across the joint into the machine") and ok
	return ok


func _closest_loose_pair(from: Vector3, to: Vector3) -> float:
	var props: PropManager = world.props
	var bales: Array [RigidBody3D] = []
	for item in props.items:
		if not (item is HayBale) or not is_instance_valid(item) or not item.is_inside_tree():
			continue
		if _off_segment((item as Node3D).global_position, from, to) > SEAM_REACH:
			continue
		bales.append(item as RigidBody3D)
	var best:= INF
	for i in bales.size():
		for j in range(i + 1, bales.size()):
			if BeltPath.is_rider(bales [i]) and BeltPath.is_rider(bales [j]):
				continue
			var p:= bales [i].global_position
			var q:= bales [j].global_position
			best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


func _press_stops() -> bool:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var press: HayCompressor = world.builds.add_compressor(
		Vector3(9.0, deck_y, 8.0), 0.0)
	if press == null:
		print("[beltqueue] could not place the press")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame


	var out: Conveyor = world.builds.add_conveyor(press.port_out(),
		press.port_out() + Vector3(0.0, 0.0, 6.0))
	if out == null:
		print("[beltqueue] could not lay the outfeed run")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame
	out.set_outlet_held(true)

	print("\n=== a press feeding a %.1f m run whose far end is jammed ==="

		% out.path_length())

	var ticks:= int(PRESS_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))

	BeltPath.debug_props = true
	for tick in ticks:


		press.stored = maxi(press.stored, Tech.compressor_bale_strands() * 2)
		await get_tree().physics_frame


	var made:= 0
	var riding:= 0
	var loose:= 0
	var props: PropManager = world.props
	for item in props.items:
		if not (item is HayBale) or not is_instance_valid(item) or not item.is_inside_tree():
			continue
		var body:= item as RigidBody3D
		if _off_segment(body.global_position, out.a, out.b) > SEAM_REACH:
			continue
		made += 1
		if BeltPath.is_rider(body):
			riding += 1
		else:
			loose += 1
			var at:= out._nearest(body.global_position)
			print("  a loose bale at s %.2f side %.2f lift %.2f, refused because: %s"
				% [float(at ["s"]), float(at ["side"]), float(at ["lift"]),
					BeltPath.debug_last_refusal.get(body.get_instance_id(), "never looked at")])
			for r: Dictionary in out.riders_debug():
				print("      the run holds seq %d at s %.2f side %.2f gap %.2f%s"
					% [int(r ["seq"]), float(r ["s"]), float(r ["side"]), float(r ["gap"]),
						" (record)" if r.get("record", false) else ""])
	BeltPath.debug_props = false
	made += out.run.count()
	riding += out.run.count()

	var room:= int(floor(out.path_length() / Cfg.COMPRESSOR_BALE_SIZE.x))
	print("  bales the press made     : %d over %.0f s" % [made, PRESS_SECONDS])
	print("  riding the outfeed       : %d  (it has room for about %d)" % [riding, room])
	print("  lying loose on the deck  : %d" % loose)
	print("  the press says           : %s"
		% ("\"" + press.alert_reason() + "\"" if press.alert_reason() != "" else "nothing"))

	var ok:= _check(made > 0, "the press produced at all")


	ok = _check(loose == 0,
		"every bale it made was taken by the belt, none left lying loose") and ok
	ok = _check(made <= room + 2,
		"...and it stopped at %d rather than filling the yard" % made) and ok
	return ok


func _across_a_seam() -> bool:
	var mid:= Vector3(-13.0, 0.75, 0.0)
	var up: Conveyor = world.builds.add_conveyor(Vector3(-13.0, 0.75, -7.0), mid)


	var down: Conveyor = world.builds.add_conveyor(mid,
		mid + Vector3(0.0, 0.0, SEAM_DOWN_LENGTH))
	if up == null or down == null:
		print("[beltqueue] could not lay the jointed pair")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame


	down.set_outlet_held(true)

	print("\n=== bales across a SEAM, %.1f m into %.1f m, far end held ==="
		% [up.path_length(), down.path_length()])
	print("  linked: %s" % str(up.downstream == down))

	var ticks:= int(FILL_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var fed:= 0
	var fill_every:= _every(FILL_EVERY_M)
	var last_fed:= - fill_every
	var worst:= INF
	var worst_note:= ""
	for tick in ticks:
		if tick - last_fed >= fill_every and fed < SEAM_LOADS:
			if _drop("hay_bale", { }, Vector3(-13.0, 0.75, -7.0), mid,
					Cfg.COMPRESSOR_BALE_SIZE.z):
				fed += 1
				last_fed = tick
		await get_tree().physics_frame
		var pair:= _closest_bales(Vector3(-13.0, 0.75, -7.0), Vector3(-13.0, 0.75, 5.0))
		if pair.is_empty():
			continue
		if float(pair ["d"]) < worst:
			worst = float(pair ["d"])
			worst_note = String(pair ["where"])


	var solid:= Cfg.COMPRESSOR_BALE_SIZE.z
	print("  bales fed                : %d" % fed)
	print("  riding upstream          : %d" % up.riders_debug().size())
	print("  riding downstream        : %d" % down.riders_debug().size())
	print("  closest two bales ever   : %.3f m  (%s)"
		% [0.0 if worst > 100000000.0 else worst, worst_note])
	print("  two nose to tail would be: %.3f m" % solid)

	var ok:= _check(up.riders_debug().size() + down.riders_debug().size() >= 4,
		"the line took a queue's worth of bales across the seam")
	ok = _check(worst >= solid * 0.95,
		"no two bales were ever standing inside each other, anywhere on the line") and ok
	return ok


func _closest_bales(from: Vector3, to: Vector3) -> Dictionary:
	var props: PropManager = world.props
	var bales: Array [Node3D] = []
	for item in props.items:
		if not (item is HayBale) or not is_instance_valid(item) or not item.is_inside_tree():
			continue
		if _off_segment((item as Node3D).global_position, from, to) > SEAM_REACH:
			continue
		bales.append(item as Node3D)
	if bales.size() < 2:
		return { }
	var best:= INF
	var note:= ""
	for i in bales.size():
		for j in range(i + 1, bales.size()):
			var p: Vector3 = bales [i].global_position
			var q: Vector3 = bales [j].global_position


			var d:= Vector2(p.x - q.x, p.z - q.z).length()
			if d < best:
				best = d
				note = "at z %+.2f and %+.2f" % [p.z, q.z]
	return { "d": best, "where": note }


func _backs_up(a: Vector3, b: Vector3) -> bool:
	var belt: Conveyor = world.builds.add_conveyor(a, b)
	if belt == null:
		print("[beltqueue] could not lay the backpressure test run")
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame
	var path: BeltPath = belt
	path.set_outlet_held(true)

	var gap:= Cfg.COMPRESSOR_BALE_SIZE.x
	var half:= Cfg.COMPRESSOR_BALE_SIZE.x * 0.5
	print("\n=== filling a %.1f m held run until it refuses ===" % path.path_length())

	var ticks:= int(FILL_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var fed:= 0
	var shut_at:= -1
	var fill_every:= _every(FILL_EVERY_M)
	var last_fed:= - fill_every


	var shut_for:= 0
	for tick in ticks:
		if path.accepts_handover(gap, 0.0, half):
			shut_for = 0


			if tick - last_fed >= fill_every:
				if _drop("hay_bale", { }, a, b, Cfg.COMPRESSOR_BALE_SIZE.z):
					fed += 1
					last_fed = tick
		else:
			shut_for += 1
			if shut_for >= _every(FILL_SHUT_M):
				shut_at = fed
				break
		await get_tree().physics_frame

	var riders:= path.riders_debug()
	var reach:= 0.0
	for r in riders:
		reach = maxf(reach, float(r ["s"]))


	var room:= int(floor((path.path_length() - Cfg.BELT_RIDE_SPACING) / gap))
	print("  a bale occupies %.2f m, so this run has room for about %d"
		% [gap, room])
	print("  bales offered before it shut    : %d" % shut_at)
	print("  aboard                          : %d" % riders.size())
	print("  belt they are standing on       : %.2f m of %.2f m"
		% [reach, path.path_length()])

	var ok:= _check(shut_at >= 0, "the run stopped accepting bales at all")


	ok = _check(riders.size() >= room / 2 and riders.size() <= room + 2,
		"...holding %d bales, which is the %d a run this long has room for"
			% [riders.size(), room]) and ok
	ok = _check(reach >= path.path_length() * 0.7,
		"...with the queue standing along the whole run rather than heaped at one end") and ok
	return ok


func _widest_loose_offset(path: BeltPath, item: String) -> float:
	var widest:= 0.0
	var total:= path.path_length()
	for p in world.props.items:
		if not is_instance_valid(p) or not p.is_inside_tree() or p.item_id != item or BeltPath.is_rider(p):
			continue
		var at:= path._nearest(p.global_position)
		var s:= float(at ["s"])
		if s <= 0.0 or s >= total or absf(float(at ["lift"])) > 0.4:
			continue
		widest = maxf(widest, absf(float(at ["side"])))
	return widest


func _case(label: String, item: String, state: Dictionary, solid: float,
		a: Vector3, b: Vector3, across: float = 0.0) -> bool:
	var belt: Conveyor = world.builds.add_conveyor(a, b)
	if belt == null:
		print("[beltqueue] could not lay the %s test run" % label)
		_fails += 1
		return false
	for i in SETTLE:
		await get_tree().physics_frame

	var path: BeltPath = belt


	path.set_outlet_held(true)

	print("\n=== %d %ss onto a %.1f m run whose outlet is held ==="
		% [LOADS, label, path.path_length()])
	print("  one is %.3f m along the belt, the nominal rider spacing is %.3f m"
		% [solid, Cfg.BELT_RIDE_SPACING])

	var ticks:= int(RUN_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var dropped:= 0


	var worst_bite:= 0.0
	var worst_pitch:= INF


	var trace: Array [String] = []
	var last_pitch:= -1.0


	var widest_slide:= 0.0


	var widest_landing:= 0.0
	for tick in ticks:
		if tick % _every(FEED_EVERY_M) == 0 and dropped < LOADS:
			if _drop(item, state, a, b, solid,
					across * (1.0 if dropped % 2 == 0 else -1.0)):
				dropped += 1
		await get_tree().physics_frame
		widest_landing = maxf(widest_landing, _widest_loose_offset(path, item))
		var now:= path.riders_debug()
		for r: Dictionary in now:
			widest_slide = maxf(widest_slide, absf(float(r ["slide"])))
		now.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			return float(x ["s"]) > float(y ["s"]))
		if now.size() >= 2:
			var pitch: float = float(now [0] ["s"]) - float(now [1] ["s"])


			if absf(pitch - last_pitch) > 0.0001 and trace.size() < TRACE_TICKS:
				trace.append("t%4d  lead %.4f  next %.4f  pitch %.4f"
					% [tick, float(now [0] ["s"]), float(now [1] ["s"]), pitch])
			last_pitch = pitch
		var sample:= _closest_pair(now)
		if sample.is_empty():
			continue
		worst_bite = maxf(worst_bite, float(sample ["bite"]))
		worst_pitch = minf(worst_pitch, float(sample ["pitch"]))

	var riders:= path.riders_debug()
	print("\n  loads set down           : %d" % dropped)
	print("  aboard at the end        : %d" % riders.size())
	print("  gap each one asked for   : %s"
		% ", ".join(riders.map(func(r: Dictionary) -> String:
			return "%.2f" % float(r ["gap"]))))
	print("  closest neighbours ever  : %.3f m"
		% (0.0 if worst_pitch > 100000000.0 else worst_pitch))
	print("  worst bite into the gap  : %.0f%%" % (worst_bite * 100.0))

	_report(riders)

	var ok:= _check(dropped >= LOADS, "the %s feed delivered its whole load" % label)
	ok = _check(riders.size() >= LOADS,
		"and the belt took it all aboard rather than refusing it") and ok


	ok = _check(worst_bite <= 0.02,
		"no %s ever rode into the gap the one in front asked for" % label) and ok
	ok = _check(worst_pitch >= solid * 0.98,
		"and no two were ever closer than %.3f m, which is what one occupies"
			% solid) and ok
	if across > 0.0:
		var off_lane:= riders.filter(func(r: Dictionary) -> bool:
			return absf(float(r ["side"])) > 0.001).size()
		var off_drawn:= riders.filter(func(r: Dictionary) -> bool:
			return absf(float(r ["side"]) + float(r ["slide"])) > 0.005).size()
		ok = _check(maxf(widest_landing, widest_slide) > across * 0.5,
			"the %ss landed off the centreline (%.2f m out at the widest, drawn %.2f off it at most)"
				% [label, widest_landing, widest_slide]) and ok
		ok = _check(off_lane == 0,
			"...and every one rides it, single file (%d in another lane)"
				% off_lane) and ok
		ok = _check(off_drawn == 0,
			"...and is drawn on it once it has slid across (%d still off)"
				% off_drawn) and ok


	if not ok:
		print("\n  the head pair, every tick its spacing changed:")
		for line in trace:
			print("    %s" % line)
	return ok


func _drop(item: String, state: Dictionary, head: Vector3, tail: Vector3,
		solid: float, across: float = 0.0) -> bool:


	var along:= (tail - head).normalized()
	var at:= head + Vector3(0.0, 0.1, 0.0) + along * (solid * 0.6) + Vector3(along.z, 0.0, - along.x) * across


	var props: PropManager = world.props
	return props.spawn(item, Transform3D(Basis(), at), state) != null


func _closest_pair(riders: Array) -> Dictionary:
	if riders.size() < 2:
		return { }
	riders.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["s"]) < float(y ["s"]))
	var out: Dictionary = { }
	for i in riders.size() - 1:
		var me: Dictionary = riders [i]
		var ahead: Dictionary = riders [i + 1]


		if absf(float(ahead ["side"]) - float(me ["side"])) > Cfg.STRAND_THICK * 6.0:
			continue
		var pitch: float = float(ahead ["s"]) - float(me ["s"])
		var want: float = float(me ["gap"])
		var bite: float = clampf(1.0 - pitch / maxf(want, 1e-06), 0.0, 1.0)
		if out.is_empty() or bite > float(out ["bite"]):
			out = { "pitch": pitch, "bite": bite }
	return out


func _report(riders: Array) -> void:
	riders.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["s"]) > float(y ["s"]))
	print("\n  where the line came to rest, leader first:")
	for i in riders.size():
		var r: Dictionary = riders [i]
		var pitch:= ""
		if i > 0:
			pitch = "  (%.3f m behind the one in front, wanted %.3f)" % [float(riders [i - 1] ["s"]) - float(r ["s"]), float(r ["gap"])]
		print("    s %.3f  side %+.3f%s" % [float(r ["s"]), float(r ["side"]), pitch])


func _check(ok: bool, what: String) -> bool:
	print("  %s %s" % ["[ok]  " if ok else "[FAIL]", what])
	if not ok:
		_fails += 1
	return ok


func _done(ok: bool) -> void:
	print("\n[beltqueue] %s (%d failed)" % ["PASS" if ok and _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if ok and _fails == 0 else 1)


static func _off_segment(p: Vector3, from: Vector3, to: Vector3) -> float:
	var a:= Vector2(from.x, from.z)
	var b:= Vector2(to.x, to.z)
	var q:= Vector2(p.x, p.z)
	var ab:= b - a
	if ab.length_squared() < 1e-06:
		return q.distance_to(a)
	var t:= clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return q.distance_to(a + ab * t)


func _room_to_drop(head: Vector3, tail: Vector3, run: BeltPath = null) -> bool:
	var along:= (tail - head).normalized()
	var at:= head + Vector3(0.0, 0.1, 0.0) + along * (Cfg.COMPRESSOR_BALE_SIZE.z * 0.6)
	if run != null and not run.has_room_near(at):
		return false
	var props: PropManager = world.props
	for item in props.items:
		if not (item is HayBale) or not is_instance_valid(item) or not item.is_inside_tree():
			continue
		var p: Vector3 = (item as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < Cfg.COMPRESSOR_BALE_SIZE.x:
			return false
	return true
