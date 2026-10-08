class_name DevJointCostProbe
extends Node


const SPAN:= 24.0
const SWEEP:= [1, 2, 3, 6, 12]


const SPEED:= 3.2

const SETTLE:= 40


const TICKS:= 1200
const WARMUP:= 540

const FEED_EVERY:= 12

const POUR:= 10

const PAIRS:= 3

const HEAD:= Vector3(13.0, 0.75, -12.0)
const TAIL:= Vector3(13.0, 0.75, 12.0)

var world: Node3D
var player: Player


var _legs:= { }

var _handed:= 0
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = Vector3(6.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	_rng.seed = 20260912

	print("\n[jointcost] %.0f m of belt driven at %.1f m/s, %d ticks a leg, %d pairs"
		% [SPAN, SPEED, TICKS, PAIRS])
	print("[jointcost] the same span laid in %s pieces in turn" % str(SWEEP))

	await _freeze_bench()
	for kind in ["wad", "straw"]:
		for pair in PAIRS:
			for n: int in SWEEP:
				await _leg(kind, str(n), n)
	_sweep_report("wad")
	_sweep_report("straw")
	get_tree().quit(0)


const BENCH_BODIES:= 20
const BENCH_TICKS:= 300


func _freeze_bench() -> void:
	print("\n=== what the freeze toggle costs, on its own ===")


	var floor_at: Array [Vector3] = []
	for i in BENCH_BODIES:
		floor_at.append(Vector3(9.0 + float(i % 5) * 0.9, 0.5,
			-12.0 + float(i / 5) * 0.9))
	await _bench_case("on bare floor", floor_at)


	var seams: Array [Vector3] = []
	var mid: Array [Vector3] = []
	for i in BENCH_BODIES:
		var c: Conveyor = world.builds.add_conveyor(
			HEAD + Vector3(float(i) * 1.6, 0.0, 0.0),
			HEAD + Vector3(float(i) * 1.6, 0.0, 4.0))
		var d: Conveyor = world.builds.add_conveyor(
			HEAD + Vector3(float(i) * 1.6, 0.0, 4.0),
			HEAD + Vector3(float(i) * 1.6, 0.0, 8.0))
		if c == null or d == null:
			print("  could not lay the seam bench runs")
			return
		seams.append(HEAD + Vector3(float(i) * 1.6, 0.35, 4.0))
		mid.append(HEAD + Vector3(float(i) * 1.6, 0.35, 2.0))
	for i in SETTLE:
		await get_tree().physics_frame
	await _bench_case("mid-deck, one belt under it", mid)
	await _bench_case("ON A SEAM, two belts under it", seams)
	for c in world.builds.conveyors.duplicate():
		if is_instance_valid(c):
			world.builds.demolish(c)
	for i in SETTLE:
		await get_tree().physics_frame


func _bench_case(where: String, at: Array [Vector3]) -> void:
	var bodies: Array [RigidBody3D] = []
	for p in at:
		var b:= RigidBody3D.new()
		var shape:= CollisionShape3D.new()
		var box:= BoxShape3D.new()
		box.size = Cfg.WAD_BASE_SIZE
		shape.shape = box
		b.add_child(shape)
		b.collision_layer = Cfg.L_PROP
		b.collision_mask = Cfg.L_PROP | Cfg.L_WORLD
		add_child(b)
		b.global_position = p
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		b.freeze = true
		bodies.append(b)
	for i in SETTLE:
		await get_tree().physics_frame
	var still:= await _bench_ticks(bodies, false)
	var toggled:= await _bench_ticks(bodies, true)
	for b in bodies:
		b.queue_free()
	for i in SETTLE:
		await get_tree().physics_frame
	print("  %-30s: still %5.0f us, toggled %5.0f us  ->  %.0f us a body"
		% [where, still, toggled,
			(toggled - still) / float(maxi(bodies.size(), 1))])


func _bench_ticks(bodies: Array [RigidBody3D], toggle: bool) -> float:
	var us: Array [float] = []
	var last:= Time.get_ticks_usec()
	for tick in BENCH_TICKS:
		if toggle:
			for b in bodies:
				b.freeze = false
		await get_tree().physics_frame
		if toggle:
			for b in bodies:
				b.freeze = true
		var now:= Time.get_ticks_usec()
		us.append(now - last)
		last = now
	return _mean(us)


func _leg(kind: String, shape: String, pieces: int) -> void:
	var paths: Array [BeltPath] = []
	for i in pieces:
		var a:= HEAD.lerp(TAIL, float(i) / float(pieces))
		var b:= HEAD.lerp(TAIL, float(i + 1) / float(pieces))
		var c: Conveyor = world.builds.add_conveyor(a, b)
		if c == null:
			print("[jointcost] could not lay piece %d of the %s leg" % [i, shape])
			get_tree().quit(1)
			return
		paths.append(c)


	for k in world.builds.corners:
		if is_instance_valid(k):
			paths.append(k)
	for p in paths:
		p.set_drive_speed(SPEED)
		p.handed_on.connect(_on_handed)
		p.caught.connect(_on_caught)
	_loose.clear()
	_latency.clear()

	for i in SETTLE:
		await get_tree().physics_frame

	var props: PropManager = world.props
	var key:= "%s/%s" % [kind, shape]
	var samples: Array = _legs.get(key, [])
	_handed = 0
	_boarded = 0
	_let_go = 0
	_direct = 0
	_dropped = 0
	var last:= Time.get_ticks_usec()
	for tick in TICKS:
		if tick % FEED_EVERY == 0:
			_feed(kind)
		await get_tree().physics_frame
		_tick = tick
		var now:= Time.get_ticks_usec()
		var riding:= 0
		for p in paths:
			if is_instance_valid(p):
				riding += p.riders().size()
		if tick >= WARMUP:
			samples.append({ "us": now - last, "handed": _handed, "riding": riding })
		_handed = 0
		last = now
	_legs [key] = samples


	print("  %s: %d loads fed, %d boardings, %d let go (%d straight across, %d dropped at the seam)"
		% [key, TICKS / FEED_EVERY * (POUR if kind == "straw" else 1),
			_boarded, _let_go, _direct, _dropped])

	if not _latency.is_empty():
		var lat: Array [float] = []
		for v: float in _latency:
			lat.append(v)
		print("  %s: %d loads let go and caught again, %.1f ticks loose on average, worst %.0f"
			% [key, lat.size(), _mean(lat), _pct(lat, 1.0)])
	for p in paths:
		if is_instance_valid(p):
			p.handed_on.disconnect(_on_handed)
			p.caught.disconnect(_on_caught)
	for c in world.builds.conveyors.duplicate():
		if is_instance_valid(c):
			world.builds.demolish(c)
	props.clear()
	for i in SETTLE:
		await get_tree().physics_frame


func _feed(kind: String) -> void:
	if kind == "wad":
		(world.props as PropManager).spawn("hay_wad",
			Transform3D(Basis(), HEAD + Vector3(0.0, 0.25, 0.0)), { "strands": 60 })
		return


	for i in POUR:
		world.live.spawn(HEAD + Vector3(_rng.randf_range(-0.12, 0.12), 0.2,
				_rng.randf_range(-0.12, 0.12)),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)


var _loose:= { }
var _latency: Array [float] = []
var _tick:= 0

var _boarded:= 0
var _let_go:= 0

var _direct:= 0
var _dropped:= 0


func _on_handed(b: RigidBody3D) -> void:
	_handed += 1
	_let_go += 1
	if not is_instance_valid(b):
		return


	if BeltPath.is_rider(b):
		_direct += 1
	else:
		_dropped += 1
	_loose [b.get_instance_id()] = _tick


func _on_caught(b: RigidBody3D) -> void:
	_boarded += 1
	if not is_instance_valid(b):
		return
	var id:= b.get_instance_id()
	if _loose.has(id):
		_latency.append(float(_tick - int(_loose [id])))
		_loose.erase(id)


func _sweep_report(kind: String) -> void:
	print("\n=== %s: the same %.0f m of belt, cut into more and more pieces ==="
		% [kind.to_upper(), SPAN])
	print("  pieces  seams  hand-overs/s  riding   tick mean   median      99th"
		+ "    quiet    on a hand-over   vs one piece")
	var base:= 0.0
	for n: int in SWEEP:
		var s: Array = _legs ["%s/%d" % [kind, n]]
		var quiet: Array [float] = []
		var busy: Array [float] = []
		var all: Array [float] = []
		var handed:= 0
		var riding:= 0.0
		for row: Dictionary in s:
			var us:= float(row ["us"])
			all.append(us)
			if int(row ["handed"]) > 0:
				busy.append(us)
			else:
				quiet.append(us)
			handed += int(row ["handed"])
			riding += float(row ["riding"])
		var mean:= _mean(all)
		if n == 1:
			base = mean
		print("  %6d %6d %13.1f %7.1f %9.0f %9.0f %9.0f %8.0f %16.0f %13s"
			% [n, n - 1, float(handed) / (float(s.size()) / 60.0),
				riding / float(s.size()), mean, _pct(all, 0.5), _pct(all, 0.99),
				_mean(quiet), _mean(busy),
				("--" if n == 1 else "%+.1f%%" % ((mean / maxf(base, 1e-06) - 1.0) * 100.0))])
	print("\n  the marginal cost of a hand-over, read within each leg:")
	for n: int in SWEEP:
		if n == 1:
			continue
		print("    %d pieces:" % n)
		_by_handed(_legs ["%s/%d" % [kind, n]])


func _by_handed(s: Array) -> void:
	var buckets:= { }
	for row: Dictionary in s:
		var n: int = mini(int(row ["handed"]), 3)
		var b: Array [float] = buckets.get(n, [] as Array [float])
		b.append(float(row ["us"]))
		buckets [n] = b
	var keys:= buckets.keys()
	keys.sort()
	var base:= 0.0
	for n: int in keys:
		var b: Array [float] = buckets [n]
		if b.size() < 20:
			continue
		var m:= _mean(b)
		if n == 0:
			base = m
		print("      %d hand-overs on the tick : %6.0f us over %4d ticks%s"
			% [n, m, b.size(),
				("" if n == 0 or base == 0.0 else "   %+.0f us, %+.0f each"
					% [m - base, (m - base) / float(n)])])


static func _mean(v: Array [float]) -> float:
	if v.is_empty():
		return 0.0
	var t:= 0.0
	for x in v:
		t += x
	return t / float(v.size())


static func _pct(v: Array [float], p: float) -> float:
	if v.is_empty():
		return 0.0
	var s:= v.duplicate()
	s.sort()
	return s [clampi(int(round(p * (s.size() - 1))), 0, s.size() - 1)]
