class_name DevRakeScaleProbe
extends Node


const SETTLE:= 30
const SAMPLE:= 120
const PAIRS:= 3
const STAGES: Array [int] = [4, 8, 12, 16, 24, 32]


const SPACING:= 2.35


const STAND_OFF:= 1.0
const CALM_WINDOW:= 60
const CALM_TOLERANCE:= 0.05
const CALM_LIMIT:= 3000

var world: Node3D
var player: Player
var field: HayField

var _subject: Array [PistonRake] = []
var _spots: Array [Vector3] = []
var _hidden: Array [Node3D] = []
var _silenced: Array [Node] = []
var _wall_log: Array [float] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0
	Cfg.apply_quality(Cfg.Quality.HIGH)
	Engine.max_fps = 0
	var top:= "top" in OS.get_cmdline_user_args()
	Tech.grant("piston_rake", 1)
	if top:
		Tech.grant("rake_bite", 5)
		Tech.grant("rake_speed", 5)
	print("\n=== what a piston rake costs (%s), headless ===" % ("top ranks" if top else "rank 0"))
	print("  bite %d strands, stroke %.2f s, so %.1f strands a second a rake at full power"
		% [Tech.rake_bite_strands(), Tech.rake_throw_seconds(),
			float(Tech.rake_bite_strands()) / Tech.rake_throw_seconds()])
	print("  prop cap %d, pile %.0f strands, crust radius %.2f m"
		% [Cfg.prop_cap, float(GameState.hay_total), field.crust_radius])

	await _wait_for_calm()
	_plan_ring()
	var table: Array [Dictionary] = []
	for want in STAGES:
		if want > _spots.size():
			break
		table.append(await _stage(want))
	if _spots.size() > STAGES [STAGES.size() - 1]:
		table.append(await _stage(_spots.size()))
	_report(table)
	print("\n[rakescale] done")
	get_tree().quit(0)


func _wait_for_calm() -> void:
	var waited:= 0
	var previous:= -1.0
	while waited < CALM_LIMIT:
		var started:= Time.get_ticks_usec()
		for i in CALM_WINDOW:
			await get_tree().process_frame
		waited += CALM_WINDOW
		var ms:= float(Time.get_ticks_usec() - started) / 1000.0 / CALM_WINDOW
		var preparing: bool = bool(field.get("_preparing_dome"))
		if not preparing and previous > 0.0 and absf(ms - previous) <= previous * CALM_TOLERANCE:
			print("  the yard went still after %d frames, at %.2f ms." % [waited, ms])
			return
		previous = ms
	print("  the yard never went still: gave up after %d frames." % waited)


func _plan_ring() -> void:
	var r:= field.crust_radius + STAND_OFF
	var count:= int(floor(TAU * r / SPACING))
	var order: Array [int] = []
	var step:= count
	var seen:= { }
	while step >= 1:
		for i in range(0, count, step):
			if not seen.has(i):
				seen [i] = true
				order.append(i)
		step /= 2
	for i in order:
		var t:= TAU * float(i) / float(count)
		_spots.append(Vector3(sin(t), 0.0, cos(t)) * r)
	print("  %d rakes fit round the pile at %.2f m spacing on a %.2f m ring."
		% [count, SPACING, r])
	print("  that is the most rakes that can ever work this pile at once.")


	var eye:= Vector3(0.0, r * 1.1, r + 10.0)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	field.update_lod(eye)


func _stage(want: int) -> Dictionary:
	var builds: BuildManager = world.get("builds")
	while _subject.size() < want:
		var at: Vector3 = _spots [_subject.size()]
		var inward:= - at.normalized()
		var rake: PistonRake = builds.add_piston_rake(at, atan2(inward.x, inward.z))
		_subject.append(rake)
	builds.rebuild_junctions()
	builds.changed.emit()


	for i in 240:
		await get_tree().process_frame
	print("\n--- %d rakes ---" % want)
	print("  %-14s %8s %6s %7s %7s %7s %7s %9s %9s"
		% ["", "ms", "fps", "proc", "phys", "active", "props", "strand/s", "striking"])
	var diffs: Array [float] = []
	var live_ms:= 0.0
	var dug:= 0.0
	var active:= 0.0
	for i in PAIRS:
		var live:= await _read("live")
		var dead:= await _read("neutralised", true)
		diffs.append(float(live ["wall"]) - float(dead ["wall"]))
		live_ms += float(live ["wall"])
		dug += float(live ["dug"])
		active += float(live ["active"])
	var mean:= 0.0
	var lo:= 1000000000.0
	var hi:= -1000000000.0
	for d in diffs:
		mean += d
		lo = minf(lo, d)
		hi = maxf(hi, d)
	mean /= float(diffs.size())
	print("    => %+.2f ms for %d rakes (%+.2f to %+.2f over %d pairs), %.0f strands a second dug"
		% [mean, want, lo, hi, PAIRS, dug / float(PAIRS)])
	if lo < 0.0 and hi > 0.0:
		print("    the pairs disagree in sign, so this is noise and not a cost.")
	return { "rakes": want, "cost": mean, "live": live_ms / float(PAIRS),
		"dug": dug / float(PAIRS), "active": active / float(PAIRS) }


func _read(label: String, neutral: bool = false) -> Dictionary:
	if neutral:
		_neutralise()
	for i in SETTLE:
		await get_tree().process_frame
	var phys:= 0.0
	var proc:= 0.0
	var active:= 0.0
	var striking:= 0.0
	var dug0:= float(GameState.hay_dug)
	var props: PropManager = world.get("props")
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		active += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		striking += float(_striking())
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE

	var dug:= (float(GameState.hay_dug) - dug0) / (float(SAMPLE) / 60.0)
	if neutral:
		_restore()
	var row:= { "wall": wall, "phys": phys / SAMPLE, "proc": proc / SAMPLE,
		"active": active / SAMPLE, "dug": dug, "striking": striking / SAMPLE }
	_wall_log.append(wall)
	print("  %-14s %8.2f %6.0f %7.2f %7.2f %7.0f %7d %9.0f %9.1f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), row ["proc"], row ["phys"],
			row ["active"], props.items.size(), dug, row ["striking"]])
	return row


func _neutralise() -> void:
	for r: PistonRake in _subject:
		if not is_instance_valid(r):
			continue
		if r.visible:
			r.visible = false
			_hidden.append(r)
		r.set_process(false)
		r.set_physics_process(false)
		_silenced.append(r)


func _restore() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	for n in _silenced:
		if is_instance_valid(n):
			n.set_process(true)
			n.set_physics_process(true)
	_silenced.clear()


func _striking() -> int:
	var n:= 0
	for r: PistonRake in _subject:
		if is_instance_valid(r) and float(r.get("_clock")) >= 0.0:
			n += 1
	return n


func _report(table: Array [Dictionary]) -> void:
	if table.is_empty():
		return
	print("\nwhat the ring sweep found:")
	print("  %-6s %10s %11s %11s %10s %12s" % ["rakes", "cost ms", "ms/rake", "marginal", "strand/s", "active bodies"])
	var prev: Dictionary = { "rakes": 0, "cost": 0.0 }
	for r: Dictionary in table:
		var n:= int(r ["rakes"])
		var added:= n - int(prev ["rakes"])
		var marginal:= 0.0
		if added > 0:
			marginal = (float(r ["cost"]) - float(prev ["cost"])) / float(added)
		print("  %-6d %10.2f %11.3f %11.3f %10.0f %12.0f"
			% [n, float(r ["cost"]), float(r ["cost"]) / float(maxi(n, 1)), marginal,
				float(r ["dug"]), float(r ["active"])])
		prev = r
	var lo:= 1000000000.0
	var hi:= -1000000000.0
	for w in _wall_log:
		lo = minf(lo, w)
		hi = maxf(hi, w)
	print("\n  across %d readings the frame wandered between %.2f and %.2f ms."
		% [_wall_log.size(), lo, hi])
	print("  pile left: %.0f strands" % float(GameState.hay_total))
