class_name DevLedgerDriftProbe
extends Node


var world: Node3D
var player: Player

const BITES:= 400
const SCOOPS:= 400

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in 40:
		await get_tree().process_frame
	var field: HayField = world.field
	print("\n=== ledger drift ===")
	print("  fresh pile: readout %.0f, field %.0f, gap %.1f"
		% [GameState.hay_never_dug(), field.measure_strands(), _gap(field)])

	var new_leak: float = await _arm_case(field, false, 0.0)
	var old_leak: float = await _arm_case(field, true, PI)
	_check("the capped arm keeps the readout on the pile (%.0f strands over %d bites)"
		% [new_leak, BITES], absf(new_leak) < 1.0)
	print("  the old arm drifted %.0f strands over the same number of bites" % old_leak)

	var spade_leak: float = await _spade_case(field)
	_check("the spade keeps the readout on the pile (%.1f strands over %d scoops)"
		% [spade_leak, SCOOPS], absf(spade_leak) < 1.0)

	_carve_bench(field)
	await _last_of_pile_case(field)

	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--ledgerdrift")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path != "" and not path.begins_with("--"):
		await _load_case(field, path)

	print("\n=== ledger drift: %s ===" % ("ok" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _last_of_pile_case(field: HayField) -> void:
	print("\n=== the last of the pile ===")
	var nv: int = field._nv
	var c:= nv / 2
	for k in field.heights.size():
		if field.heights [k] > 0.0:
			field.heights [k] = 0.0
			field._touch_vertex(k % nv, k / nv)
	var stubble: Array [int] = [c * nv + c, c * nv + c + 1, (c + 1) * nv + c]
	for k in stubble:
		field.heights [k] = 0.02
		field._touch_vertex(k % nv, k / nv)


	var tuft: Array [int] = []
	for dj in 5:
		for di in 5:
			tuft.append((c + 20 + dj) * nv + c + di)
	for k in tuft:
		field.heights [k] = 0.25
		field._touch_vertex(k % nv, k / nv)
	var tuft_strands:= field.measure_strands() - 3.0 * 0.02 * Cfg.CELL * Cfg.CELL * Cfg.STRANDS_PER_M3
	GameState.hay_returned = 0.0
	GameState.hay_total = field.measure_strands() + 115.0
	field._last_of_pile_seen = INF
	field._last_of_pile_wait = 0.0
	for i in 10:
		await get_tree().process_frame
	var left:= 0.0
	for k in stubble:
		left += field.heights [k]
	_check("the stubble is swept (%.3f m left on it)" % left, left == 0.0)
	_check("the tuft a player can see is left standing (%.0f strands of %.0f)"
			% [field.measure_strands(), tuft_strands],
		absf(field.measure_strands() - tuft_strands) < 1.0)
	_check("the readout is the field and nothing else (%.0f, field %.0f)"
			% [GameState.hay_never_dug(), field.measure_strands()],
		absf(GameState.hay_never_dug() - field.measure_strands()) < 1.0)
	for k in tuft:
		field.heights [k] = 0.0
		field._touch_vertex(k % nv, k / nv)
	GameState.hay_total = 115.0
	GameState.hay_returned = 0.0
	for i in int(HayField.LAST_OF_PILE_EVERY * 60.0) + 10:
		await get_tree().process_frame
	_check("an empty field with a ledger over it reads 0 (%.0f)" % GameState.hay_never_dug(),
		GameState.hay_never_dug() == 0.0)


func _gap(field: HayField) -> float:
	return GameState.hay_never_dug() - field.measure_strands()


func _arm_case(field: HayField, old: bool, angle: float) -> float:
	var builds: BuildManager = world.builds
	var live: LiveStrandManager = world.live
	var at:= Cfg.PILE_CENTER + Vector3(cos(angle), 0.0, sin(angle)) * 11.5
	at.y = 0.06
	var arm: RoboticArm = builds.add_robotic_arm(at, 0.0, 1)


	arm.set_process(false)
	arm.set_physics_process(false)
	var want:= Tech.arm_capacity(int(arm.tier_data() ["capacity"]))
	var leak:= 0.0
	var bites:= 0
	var thin:= 0
	for n in BITES:
		var pick: Dictionary = arm._find_field_pickup(arm._shoulder_world())
		if pick.is_empty():
			break
		arm._pickup_source = pick ["point"]
		var radius:= 0.5 * arm.visual_scale()
		if field.strands_under(arm._pickup_source, radius) < float(want):
			thin += 1
		var before:= _gap(field)
		var bodies: Array [RigidBody3D] = []
		if old:
			_old_harvest(arm, field, want)
		else:
			bodies = arm._harvest_field_payload(want)
		leak += _gap(field) - before
		for b: RigidBody3D in bodies:
			live.consume(b)
		arm._payload_count = 0
		bites += 1


		await get_tree().physics_frame
	print("  arm%s: %d bites of %d, %d on a spot holding less than a load, drift %.0f"
		% [" (old)" if old else "", bites, want, thin, leak])
	builds.demolish(arm)
	return leak


func _old_harvest(arm: RoboticArm, field: HayField, want: int) -> void:
	var radius:= 0.5 * arm.visual_scale()
	var capacity:= mini(want, int(floor(GameState.hay_total)))
	if capacity <= 0:
		return
	var taken: Array = field.take_in_radius(arm._pickup_source, radius, capacity)
	var count:= maxi(taken.size(), capacity)
	GameState.remove_hay(float(count))
	field.carve_volume(arm._pickup_source, radius,
		float(count) * Cfg.STRAND_VOLUME / Cfg.PACKING)


func _carve_bench(field: HayField) -> void:
	var saved:= field.heights.duplicate()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 11
	var points: Array [Vector3] = []
	for n in 2000:
		var a:= rng.randf() * TAU
		var ring:= rng.randf_range(2.0, 12.5)
		var p:= Cfg.PILE_CENTER + Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		p.y = field.height_at(p.x, p.z)
		points.append(p)
	var vol:= 90.0 * Cfg.STRAND_VOLUME / Cfg.PACKING

	var t0:= Time.get_ticks_usec()
	for p: Vector3 in points:
		_flat_carve(field, p, 0.5, vol)
	var flat_us:= Time.get_ticks_usec() - t0
	field.heights = saved.duplicate()

	t0 = Time.get_ticks_usec()
	for p: Vector3 in points:
		field.carve_volume(p, 0.5, vol)
	var new_us:= Time.get_ticks_usec() - t0
	field.heights = saved

	print("  carve cost: flat %.1f us a bite, now %.1f us a bite (2000 bites)"
		% [float(flat_us) / 2000.0, float(new_us) / 2000.0])
	_check("the carve costs under 0.1 ms a bite", float(new_us) / 2000.0 < 100.0)


func _flat_carve(field: HayField, center: Vector3, radius: float, volume: float) -> void:
	var idxs:= field._disc_vertices(center, radius)
	if idxs.is_empty():
		return
	var drop: float = volume / (float(idxs.size()) * Cfg.CELL * Cfg.CELL)
	for idx in idxs:
		field.heights [idx] = maxf(0.0, field.heights [idx] - drop)
		field._touch_vertex(idx % field._nv, idx / field._nv)


func _spade_case(field: HayField) -> float:
	Tech.reset()
	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	var scoop:= Tech.scoop_max(Cfg.SCOOP_MAX, Tech.spade_scale())
	var radius:= Cfg.SCOOP_RADIUS * Tech.spade_scale()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var leak:= 0.0
	var took:= 0
	for n in SCOOPS:
		var a:= rng.randf() * TAU
		var ring:= rng.randf_range(2.0, 12.5)
		var at:= Cfg.PILE_CENTER + Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		var h:= field.height_at(at.x, at.z)
		if h <= 0.001:
			continue
		at.y = h - 0.05
		var before:= _gap(field)
		took += player.shovel.scoop_at(at, scoop, radius,
			Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.5))
		leak += _gap(field) - before
		await get_tree().physics_frame
	print("  spade: %d strands dug" % took)
	return leak


func _load_case(field: HayField, path: String) -> void:
	print("\n-- load: %s --" % path.get_file())
	if not FileAccess.file_exists(path):
		_check("the save copy exists", false)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		_check("the copy is a save", false)
		return
	var d: Dictionary = payload
	if not is_equal_approx(float(d.get("extent", -1.0)), Cfg.FIELD_EXTENT):
		print("  skipped: the copy is extent %.0f and this run is %.0f"
			% [float(d.get("extent", -1.0)), Cfg.FIELD_EXTENT])
		return
	GameState.from_dict(d.get("state", { }))
	SaveManager.current_pile_shape_version = int(d.get("pile_shape_version",
		SaveManager.PILE_SHAPE_LEGACY))
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	var readout_in_file:= GameState.hay_never_dug()
	var dug:= GameState.hay_dug
	var cleared:= GameState.pile_cleared
	var pct_old:= GameState.hay_total / maxf(GameState.hay_initial, 1.0) * 100.0

	field.generate(GameState.run_seed, heights)
	for n in 30:
		await get_tree().physics_frame

	var pile:= field.measure_strands()
	print("  in the file: readout %.0f, percent (old reading) %.1f%%"
		% [readout_in_file, pct_old])
	print("  after load:  readout %.0f, pile %.0f, percent %.1f%%"
		% [GameState.hay_never_dug(), pile, GameState.hay_left_fraction() * 100.0])
	_check("the readout is the pile after the load (gap %.1f)" % _gap(field),
		absf(_gap(field)) < 5.0)
	_check("the percent is the pile over the initial",
		absf(GameState.hay_left_fraction() - pile / GameState.hay_initial) < 0.001)
	_check("hay_dug is untouched", is_equal_approx(GameState.hay_dug, dug))
	_check("the cleared latch is untouched", GameState.pile_cleared == cleared)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1
