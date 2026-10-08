class_name DevSellTimeProbe
extends Node


var world: Node3D
var player: Player


const LOG:= "user://sell_time_probe.log"
var _log: FileAccess


const SAMPLE:= 120


func run() -> void:
	call_deferred("_run")


func _say(line: String) -> void:
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _run() -> void:
	reparent(get_tree().root)
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	player = world.player
	world.block_save = true
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--selltime")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		_say("SELLTIME: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		_say("SELLTIME: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	builds.from_array(d.get("buildings", []))
	props.from_array([] if "--nolitter" in ua else d.get("props", []))
	for k in 90:
		await get_tree().physics_frame

	_say("SELLTIME: log at %s" % ProjectSettings.globalize_path(LOG))
	_say("SELLTIME: %d buildings, %d props, %d belts, %d decks"
		% [builds.all_buildings().size(), props.items.size(),
			builds.conveyors.size(), builds.platforms.size()])

	var before:= await _sample_ticks()
	_say("  before the sale: tick mean %.2f ms, worst %.2f ms" % [before.x, before.y])


	var t:= Time.get_ticks_usec()
	var tally:= YardSale.tally(builds, props)
	var tally_ms:= (Time.get_ticks_usec() - t) / 1000.0
	_say("  YardSale.tally (E on the sign): %.1f ms for %d machines, %d structures, %d tools"
		% [tally_ms, int(tally.machines), int(tally.structures), int(tally.tools)])


	t = Time.get_ticks_usec()
	for building: Node3D in builds.all_buildings():
		builds.demolish_blocked_reason(building)
	_say("  one pass of demolish_blocked_reason over the yard: %.1f ms"
		% ((Time.get_ticks_usec() - t) / 1000.0))


	t = Time.get_ticks_usec()
	var tools:= 0
	for item: Carryable in props.items.duplicate():
		if item.is_held() or ItemDb.price(item.item_id) <= 0.0 or item.hay_strands() > 0:
			continue
		tools += 1
		BeltPath.release(item)
		props.remove(item)
	var tools_ms:= (Time.get_ticks_usec() - t) / 1000.0
	_say("  buying %d loose items: %.1f ms" % [tools, tools_ms])


	var per_kind: Dictionary = { }
	var rounds: Array [String] = []
	var sweep:= Time.get_ticks_usec()


	var batched:= not ("--oneatatime" in ua)
	if batched:
		builds.begin_sweep()
	var guard:= builds.all_buildings().size() + 1
	while guard > 0:
		guard -= 1
		var went:= 0
		var round_at:= Time.get_ticks_usec()
		var blocked_us:= 0
		for building: Node3D in builds.all_buildings():
			if not is_instance_valid(building):
				continue
			var ask:= Time.get_ticks_usec()
			var reason:= builds.demolish_blocked_reason(building)
			blocked_us += Time.get_ticks_usec() - ask
			if reason != "":
				continue
			var script:= building.get_script() as Script
			var kind: String = building.get_class() if script == null else script.get_global_name()
			var one:= Time.get_ticks_usec()
			builds.demolish(building)
			var spent:= Time.get_ticks_usec() - one
			var row: Array = per_kind.get(kind, [0, 0])
			row [0] = int(row [0]) + 1
			row [1] = int(row [1]) + spent
			per_kind [kind] = row
			went += 1
			if went % 25 == 0:
				_say("      ... %d taken, %.1f s into the round"
					% [went, (Time.get_ticks_usec() - round_at) / 1000000.0])
		rounds.append("round %d: %d taken in %.1f ms (%.1f ms of it asking whether they could go)"
			% [rounds.size() + 1, went, (Time.get_ticks_usec() - round_at) / 1000.0,
				blocked_us / 1000.0])
		if went == 0:
			break
	var refit:= Time.get_ticks_usec()
	if batched:
		builds.end_sweep()
	var refit_ms:= (Time.get_ticks_usec() - refit) / 1000.0
	var sweep_ms:= (Time.get_ticks_usec() - sweep) / 1000.0
	for line: String in rounds:
		_say("    " + line)
	_say("  the sweep: %.1f ms, of which the one refit at the end is %.1f ms"
		% [sweep_ms, refit_ms])

	var kinds:= per_kind.keys()
	kinds.sort_custom(_slowest_first.bind(per_kind))
	_say("  where the sweep went, worst kind first:")
	for kind: String in kinds:
		var row: Array = per_kind [kind]
		_say("    %-22s %4d taken, %8.1f ms total, %6.2f ms each"
			% [kind, int(row [0]), int(row [1]) / 1000.0,
				int(row [1]) / 1000.0 / maxi(int(row [0]), 1)])

	t = Time.get_ticks_usec()
	YardSale.kept_lines(builds, props)
	_say("  kept_lines on the empty yard: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	_say("  ONE PRESS TOTAL: %.1f ms" % (tally_ms + tools_ms + sweep_ms))

	var after:= await _sample_ticks()
	_say("  after the sale: tick mean %.2f ms, worst %.2f ms" % [after.x, after.y])
	get_tree().quit(0)


func _slowest_first(a: String, b: String, table: Dictionary) -> bool:
	return int((table [a] as Array) [1]) > int((table [b] as Array) [1])


func _sample_ticks() -> Vector2:
	var worst:= 0
	var total:= 0
	var last:= Time.get_ticks_usec()
	for k in SAMPLE:
		await get_tree().physics_frame
		var now:= Time.get_ticks_usec()
		var gap:= now - last
		last = now
		total += gap
		worst = maxi(worst, gap)
	return Vector2(total / 1000.0 / SAMPLE, worst / 1000.0)
