class_name DevRakeProbe
extends Node


const CONSERVE_STROKES:= 10


const LEDGER_EPS:= 0.5


const FULL_YARD_FRAMES:= 900


const HEAP_WADS:= 12

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0
var _peak_live:= 0


func run() -> void:
	await get_tree().process_frame


	if "--landing" in OS.get_cmdline_user_args():
		await _ring_matches_landing()
		print("[rake] %d passed, %d failed" % [_pass, _fail])
		get_tree().quit(1 if _fail > 0 else 0)
		return


	if "--drive" in OS.get_cmdline_user_args():
		await _drives()
		Tech.reset()
		print("[rake] %d passed, %d failed" % [_pass, _fail])
		get_tree().quit(1 if _fail > 0 else 0)
		return


	if "--mountain" in OS.get_cmdline_user_args():
		await _mountain_face()
		Tech.reset()
		print("[rake] %d passed, %d failed" % [_pass, _fail])
		get_tree().quit(1 if _fail > 0 else 0)
		return

	_tree_shape()
	_wad_curve()
	_speed_curve()
	_bite_matches_throw()
	await _siting()
	await _machine_small_wad()
	await _machine_wad()
	await _every_throw_departs()
	await _the_stroke_conserves()
	await _a_short_bite_is_held()
	await _a_full_yard_does_not_stop_it()
	await _heaped_discharge_keeps_working()
	await _gathers_wads_in_front()
	await _needle_in_the_bite()
	await _dismantle()
	await _throw_range()
	await _edge_of_face()
	await _worn_middle()
	await _walled_in()
	await _range_marks()
	await _ring_matches_landing()
	await _console_reach()
	await _drives()

	Tech.reset()
	print("[rake] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _tree_shape() -> void:
	for id: String in ["piston_rake", "rake_bite", "rake_speed"]:
		_check("%s is in the tree" % id, TechTree.has_id(id))
		_check("%s is not a demo card" % id, not TechTree.is_demo(id))

	var nodes: Dictionary = TechTree.nodes()
	_check("rake_bite hangs off the machine",
		"piston_rake" in nodes ["rake_bite"] ["requires"])
	_check("rake_speed hangs off the head",
		"rake_bite" in nodes ["rake_speed"] ["requires"])


	for id: String in nodes.keys():
		for req: String in nodes [id] ["requires"]:
			_check("%s requires a node that exists (%s)" % [id, req],
				TechTree.has_id(req))


func _wad_curve() -> void:
	Tech.reset()
	_check("rank 0 throws a small wad of %d" % Cfg.RAKE_SMALL_WAD_STRANDS,
		Tech.rake_wad_strands() == Cfg.RAKE_SMALL_WAD_STRANDS)
	_check("...which is big enough to be a wad",
		HayWad.split(Tech.rake_wad_strands()).size() == 1)
	var base:= _last_int(String(TechTree.nodes() ["rake_bite"].get("base", "")))
	_check("the card's base says %d and the getter agrees (%d)"
		% [base, Tech.rake_wad_strands()], base == Tech.rake_wad_strands())

	var card: Array = TechTree.nodes() ["rake_bite"] ["values"]
	for r in range(1, card.size() + 1):
		Tech.grant("rake_bite", r)
		_check("rank %d wad is bigger than rank 0's" % r,
			Tech.rake_wad_strands() > Cfg.RAKE_SMALL_WAD_STRANDS)

		var printed:= _last_int(String(card [r - 1]))
		_check("rank %d card says %d and the getter agrees (%d)"
			% [r, printed, Tech.rake_wad_strands()],
			printed == Tech.rake_wad_strands())

	Tech.grant("rake_bite", 1)
	_check("the first rank is a plain wad, not a grown one",
		Tech.rake_wad_strands() == Cfg.WAD_BASE_STRANDS)
	Tech.reset()


func _speed_curve() -> void:
	Tech.reset()
	var base:= Tech.rake_throw_seconds()
	_check("rank 0 strokes every %.2f s" % Cfg.RAKE_THROW_SECONDS,
		is_equal_approx(base, Cfg.RAKE_THROW_SECONDS))

	var card: Array = TechTree.nodes() ["rake_speed"] ["values"]
	for r in range(1, card.size() + 1):
		Tech.grant("rake_speed", r)
		var period:= Tech.rake_throw_seconds()
		_check("rank %d is sooner than rank %d" % [r, r - 1], period < base)

		var printed:= String(card [r - 1]).to_float()
		_check("rank %d card says %.2f s and the rake strokes every %.2f s"
			% [r, printed, period], absf(period - printed) <= 0.005)
	Tech.reset()


func _bite_matches_throw() -> void:
	Tech.reset()
	_check("rank 0 carves what it throws",
		Tech.rake_bite_strands() == Tech.rake_wad_strands())
	_check("rank 0 bite is at or above the wad floor",
		Tech.rake_bite_strands() >= Cfg.WAD_MIN_STRANDS)
	for r in [1, 3, 5]:
		Tech.grant("rake_bite", r)
		_check("wad mode at rank %d carves what it flings" % r,
			Tech.rake_bite_strands() == Tech.rake_wad_strands())
		_check("rank %d bite is above the wad floor" % r,
			Tech.rake_bite_strands() >= Cfg.WAD_MIN_STRANDS)
	Tech.reset()


func _siting() -> void:
	GameState.add_money(5000.0)
	var field: HayField = world.field
	var tool: BuildTool = player.build
	var site:= _site()
	_check("found a spot on the floor facing the pile", not site.is_empty())
	if site.is_empty():
		return
	var at: Vector3 = site [0]
	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var good: Dictionary = tool._evaluate_rake(at, Vector3.UP, fwd)
	_check("...and the build tool agrees it is buildable (%s)"
		% ("ok" if good ["ok"] else str(good ["reason"])), good ["ok"])


	var crown:= at + fwd * (Cfg.RAKE_REACH * 2.0)
	crown.y = field.height_at(crown.x, crown.z)
	_check("a spot up the face stands on %.2f m of hay" % crown.y,
		crown.y > Cfg.RAKE_STAND_CLEAR + 0.2)
	var high: Dictionary = tool._evaluate_rake(crown, Vector3.UP, fwd)
	_check("...so it is refused (%s)" % str(high ["reason"]), not high ["ok"])
	_check("...and the reason names the floor rather than the hay",
		str(high ["reason"]).contains("floor"))


	var buried:= at
	var nose_at: float = PistonRake.BODY_Z + PistonRake.BODY_L * 0.5
	for _step in 20:
		buried += fwd * 0.25
		buried.y = field.height_at(buried.x, buried.z)
		if buried.y > Cfg.RAKE_STAND_CLEAR:
			buried = Vector3.ZERO
			break
		var nose:= buried + fwd * nose_at
		if field.height_at(nose.x, nose.z) - buried.y > Cfg.RAKE_STAND_CLEAR:
			break
	if buried != Vector3.ZERO:
		var deep: float = tool._rake_hay_over_chassis(buried, fwd, field)
		_check("found a spot on the floor with %.2f m of hay over the chassis" % deep,
			deep > Cfg.RAKE_STAND_CLEAR)
		var sunk: Dictionary = tool._evaluate_rake(buried, Vector3.UP, fwd)
		_check("...so it is refused (%s)" % str(sunk ["reason"]), not sunk ["ok"])
		_check("...and the reason is that it is too close to the hay",
			str(sunk ["reason"]).contains("too close"))


	var across:= Vector3(fwd.z, 0.0, - fwd.x)
	var belt: Conveyor = world.builds.add_conveyor(
		at + across * 2.0 + Vector3.UP * 0.45, at - across * 2.0 + Vector3.UP * 0.45)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fouled: Dictionary = tool._evaluate_rake(at, Vector3.UP, fwd)
	_check("a belt run through the same spot blocks it (%s)" % str(fouled ["reason"]),
		not fouled ["ok"])
	world.builds.demolish(belt)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var clear: Dictionary = tool._evaluate_rake(at, Vector3.UP, fwd)
	_check("...and taking the belt down gives the spot back (%s)"
		% ("ok" if clear ["ok"] else str(clear ["reason"])), clear ["ok"])


func _clear_behind(at: Vector3, inward: Vector3, metres: float) -> bool:
	var box:= BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, metres - 1.8)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	var mid:= at - inward * (1.8 + (metres - 1.8) * 0.5) + Vector3.UP * 1.8
	q.transform = Transform3D(Basis.looking_at(inward, Vector3.UP), mid)
	return world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _site(behind_clear: float = 0.0) -> Array:
	var field: HayField = world.field


	for ring_step in range(12, 30):
		var ring:= float(ring_step) * 0.5
		for step in 24:
			var a:= TAU * float(step) / 24.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			at.y = field.height_at(at.x, at.z)
			if at.y > 0.1:
				continue
			var inward:= Vector3(- cos(a), 0.0, - sin(a)).normalized()


			if player.build._rake_hay_over_chassis(at, inward, field) > Cfg.RAKE_STAND_CLEAR:
				continue
			var face:= at + inward * Cfg.RAKE_REACH
			if field.height_at(face.x, face.z) > at.y + 0.25:
				if behind_clear > 0.0 and not _clear_behind(at, inward, behind_clear):
					continue
				return [at, atan2(inward.x, inward.z)]
	return []


func _one_stroke(rake: PistonRake, stop_at_throw: bool = false) -> float:
	var field: HayField = world.field
	var before:= field.measure_strands()


	var settle:= 0
	for _i in 200:
		await get_tree().process_frame
		if stop_at_throw and rake.last_thrown > 0:
			settle += 1
			if settle >= 4:
				break


		_peak_live = maxi(_peak_live, world.live.active_count())
	return before - field.measure_strands()


func _machine_small_wad() -> void:
	Tech.reset()
	var site:= _site()
	_check("found a spot facing the pile to stand a rake on", not site.is_empty())
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	await get_tree().process_frame

	_check("the model loaded out of piston_rake.glb", rake.get_child_count() > 0)
	var anim:= rake.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the GLB carries an AnimationPlayer", anim != null)
	if anim != null:
		_check("...with the merged '%s' clip on it" % PistonRake.CLIP,
			anim.has_animation(PistonRake.CLIP))
	_check("Marker_Head survived the export",
		rake.find_child(PistonRake.N_HEAD, true, false) != null)


	var fwd: Vector3 = rake.global_position.direction_to(
		(rake.find_child(PistonRake.N_HEAD, true, false) as Node3D).global_position)
	var aim:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	_check("the rake head points the way the machine was sited",
		Vector2(fwd.x, fwd.z).normalized().dot(Vector2(aim.x, aim.z).normalized()) > 0.7)

	var wads_before:= _wads_near(rake.global_position, 12.0)
	await _one_stroke(rake, true)
	_check("rank 0 bites the pile (%.1f straw)" % rake.last_bite, rake.last_bite > 0.5)
	_check("rank 0 throws one body (%d thrown)" % rake.last_thrown,
		rake.last_thrown == 1)
	var fresh:= _wad_list(rake.global_position, 12.0)
	_check("...and it is a wad, not loose straw (%d new wads)"
		% (fresh.size() - wads_before), fresh.size() - wads_before == 1)
	var small:= 0
	for w in fresh:
		if (w as HayWad).strands == Cfg.RAKE_SMALL_WAD_STRANDS:
			small += 1
	_check("...of %d straw" % Cfg.RAKE_SMALL_WAD_STRANDS, small >= 1)
	world.builds.demolish(rake)
	for w in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(w)
	await get_tree().process_frame


func _machine_wad() -> void:
	Tech.reset()
	Tech.grant("rake_bite", 2)
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	var before:= _wads_near(rake.global_position, 12.0)
	await _one_stroke(rake, true)
	_check("ranked up it bites more (%.1f straw)" % rake.last_bite,
		rake.last_bite >= float(Cfg.WAD_MIN_STRANDS))
	var wads:= _wads_near(rake.global_position, 12.0) - before
	_check("...and throws ONE wad instead of a scatter (%d)" % wads, wads == 1)


	for _i in 90:
		await get_tree().process_frame
	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var behind:= 0
	for w in _wad_list(rake.global_position, 12.0):
		if (w.global_position - rake.global_position).dot(fwd) < 0.0:
			behind += 1
	_check("the wad landed behind the machine, not in front", behind >= 1)
	world.builds.demolish(rake)


	for w in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(w)
	await get_tree().process_frame


func _every_throw_departs() -> void:
	Tech.reset()
	Tech.grant("rake_bite", 2)
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	var props: PropManager = world.props
	var seen:= { }
	for item in props.items:
		seen [item.get_instance_id()] = true


	var fresh: Array [HayWad] = []
	var thrown:= 0
	var stuck:= 0
	var slowest:= 999.0
	for _f in 2400:
		await get_tree().physics_frame
		for wad in fresh:
			if not is_instance_valid(wad):
				continue
			thrown += 1


			var flat:= Vector2(wad.linear_velocity.x, wad.linear_velocity.z).length()
			slowest = minf(slowest, flat)
			if flat < 1.0:
				stuck += 1
		fresh = []
		for item in props.items:
			var id: int = item.get_instance_id()
			if seen.has(id):
				continue
			seen [id] = true
			if item is HayWad:
				fresh.append(item as HayWad)


		for item in props.items.duplicate():
			var landed:= item as HayWad
			if landed == null or not is_instance_valid(landed) or landed in fresh:
				continue
			if landed.linear_velocity.length() < 0.5:
				props.remove(landed)

	_check("a swept rake keeps stroking (%d wads thrown)" % thrown, thrown >= 10)
	_check("every thrown wad was moving a frame later (slowest %.2f m/s, %d stuck)"
		% [slowest, stuck], stuck == 0)
	world.builds.demolish(rake)
	await get_tree().process_frame


func _the_stroke_conserves() -> void:
	Tech.reset()
	Tech.grant("rake_bite", 2)
	var site:= _site()
	_check("found a spot to measure a stroke's books at", not site.is_empty())
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	var props: PropManager = world.props


	var seen:= { }
	for item in props.items:
		seen [item.get_instance_id()] = true

	var dug_before:= GameState.hay_dug
	var back_before:= GameState.hay_returned
	var landed:= 0.0
	var strokes:= 0
	var was_biting:= rake._did_bite
	for _f in 3000:
		await get_tree().physics_frame


		if rake._did_bite and not was_biting:
			strokes += 1
		was_biting = rake._did_bite
		if strokes >= CONSERVE_STROKES and rake._did_throw:
			break
		for item in props.items.duplicate():
			var wad:= item as HayWad
			if wad == null or not is_instance_valid(wad):
				continue
			if seen.has(wad.get_instance_id()):
				continue


			if wad.linear_velocity.length() >= 0.5:
				continue
			seen [wad.get_instance_id()] = true
			landed += float(wad.hay_strands())
			props.remove(wad)

	for item in props.items.duplicate():
		var wad:= item as HayWad
		if wad == null or not is_instance_valid(wad) or seen.has(wad.get_instance_id()):
			continue
		seen [wad.get_instance_id()] = true
		landed += float(wad.hay_strands())
		props.remove(wad)

	var dug:= GameState.hay_dug - dug_before


	var back:= GameState.hay_returned - back_before + rake._held
	_check("the rake took %d strokes to measure" % strokes,
		strokes >= CONSERVE_STROKES)
	print("[rake]      carved %.1f  ·  landed %.1f  ·  handed back %.1f  ·  lost %.1f"
		% [dug, landed, back, dug - landed - back])
	_check("a stroke carves something worth counting (%.1f straw)" % dug,
		dug > 1.0)


	_check("every straw carved was thrown or handed back (%.1f unaccounted)"
		% (dug - landed - back), absf(dug - landed - back) < LEDGER_EPS)


	_check("...and there was an overshoot to hand back (%.1f straw)" % back,
		back > 0.0)
	world.builds.demolish(rake)
	await get_tree().process_frame


func _a_short_bite_is_held() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	var live: LiveStrandManager = world.live
	var scraps:= float(Cfg.WAD_MIN_STRANDS) * 0.6

	var strands_before:= live.active_count()
	var wads_before:= _wads_near(rake.global_position, 12.0)
	var back_before:= GameState.hay_returned
	rake._thrown_total = scraps
	rake._throw()
	_check("a short stroke throws nothing (%d thrown)" % rake.last_thrown,
		rake.last_thrown == 0)
	_check("...no loose straw (%d new strands)" % (live.active_count() - strands_before),
		live.active_count() == strands_before)
	_check("...and no wad", _wads_near(rake.global_position, 12.0) == wads_before)
	_check("...and keeps the %.0f straw in the head (%.1f)" % [scraps, rake._held],
		is_equal_approx(rake._held, scraps))
	_check("...rather than handing it back (%.1f returned)"
		% (GameState.hay_returned - back_before),
		GameState.hay_returned - back_before < LEDGER_EPS)
	_check("...and does not count as a dry stroke (%d)" % rake._dry_strokes,
		rake._dry_strokes == 0)

	rake._bite()
	_check("the next bite starts from the scraps (%.1f in hand, %.1f carved)"
		% [rake._thrown_total, rake.last_bite],
		is_equal_approx(rake._thrown_total - rake.last_bite, scraps))
	_check("...and the head is empty again", rake._held == 0.0)
	rake._throw()
	_check("...and that stroke throws its wad (%d)" % rake.last_thrown,
		rake.last_thrown == 1)


	rake.set_process(false)
	var owed:= 7.0
	rake._held = owed
	var back_again:= GameState.hay_returned
	world.builds.demolish(rake)
	await get_tree().process_frame
	_check("a rake taken down hands its scraps back (%.1f of %.1f)"
		% [GameState.hay_returned - back_again, owed],
		absf(GameState.hay_returned - back_again - owed) < LEDGER_EPS)
	for w in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(w)
	await get_tree().process_frame


func _a_full_yard_does_not_stop_it() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	var live: LiveStrandManager = world.live


	var was_budget:= Cfg.live_strand_budget
	Cfg.live_strand_budget = live.active_count()
	_check("the yard reads as full of loose hay", not live.has_headroom())

	var dug_before:= GameState.hay_dug
	var wads_before:= _wads_near(rake.global_position, 12.0)
	for _f in FULL_YARD_FRAMES:
		await get_tree().physics_frame
	var thrown:= _wads_near(rake.global_position, 12.0) - wads_before
	Cfg.live_strand_budget = was_budget
	_check("...and the rake goes on carving (%.1f straw)"
		% (GameState.hay_dug - dug_before), GameState.hay_dug > dug_before)
	_check("...and throwing wads (%d)" % thrown, thrown > 0)
	_check("...with no sign over it: %s"
		% ["quiet" if rake.alert_reason() == "" else rake.alert_reason()],
		rake.alert_reason() == "")
	world.builds.demolish(rake)
	for w in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(w)
	await get_tree().process_frame


func _heaped_discharge_keeps_working() -> void:
	Tech.reset()
	Tech.grant("rake_bite", 2)
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame


	var at:= rake.discharge_spot()
	var r:= PropManager.WORK_SPOT_R
	var heap: Array [Carryable] = []
	for i in HEAP_WADS:
		var ring:= 0.45 if i % 2 == 0 else 1.0
		var a:= TAU * float(i) / float(HEAP_WADS)
		var w: Carryable = world.props.spawn("hay_wad", Transform3D(Basis(),
			at + Vector3(cos(a) * ring, 0.35, sin(a) * ring)), { "strands": 40 })
		if w != null:
			LiveStrandManager.release_hold(w)
			heap.append(w)
	for _f in 60:
		await get_tree().physics_frame
	var on_pad:= 0
	for w in heap:
		if is_instance_valid(w) and w.global_position.distance_to(at) < r:
			on_pad += 1
	_check("a heap stands where the rake throws (%d wads)" % on_pad,
		on_pad > Cfg.RAKE_PAD_WADS)

	var back_before:= GameState.hay_returned
	var strokes:= await _strokes_in(rake, 900)
	_check("...and the rake goes on stroking onto it (%d strokes)" % strokes,
		strokes > 0)
	var reason:= rake.alert_reason()
	_check("...without a sign over it", not reason.contains("DISCHARGE"), reason)

	var gone:= 0
	for w in heap:
		if not is_instance_valid(w):
			gone += 1
	_check("...and the oldest wads were cleared off it (%d of %d)"
		% [gone, heap.size()], gone >= on_pad - Cfg.RAKE_PAD_WADS)
	_check("...with their hay handed back (%.1f straw)"
		% (GameState.hay_returned - back_before),
		GameState.hay_returned > back_before)


	var loose:= 0
	for item in world.props.items:
		if is_instance_valid(item) and item.hay_strands() > 0 and item.global_position.distance_to(at) < r and not world.props.is_spoken_for(item):
			loose += 1
	_check("...and never holds more than %d (%d now)" % [Cfg.RAKE_PAD_WADS, loose],
		loose <= Cfg.RAKE_PAD_WADS)

	world.builds.demolish(rake)
	await get_tree().process_frame

	for wad in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(wad)
	await get_tree().process_frame


func _gathers_wads_in_front() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	rake.set_process(false)
	await get_tree().process_frame
	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var field: HayField = world.field

	var laid: Array [HayWad] = []
	var strands_in:= 0
	for offset: int in [-6, 0, 6]:
		var at:= rake.bite_point(offset)
		at.y = field.height_at(at.x, at.z) + 0.35
		var w:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
			{ "strands": 40 }) as HayWad
		if w != null:
			LiveStrandManager.release_hold(w)
			laid.append(w)
			strands_in += w.strands
	for _f in 60:
		await get_tree().physics_frame
	var seen:= rake._gatherable()
	var lying:= 0
	for w in laid:
		if w in seen:
			lying += 1
	_check("three wads lie on the ground the head works (%d)" % lying,
		lying == laid.size())

	rake.set_process(true)
	var carried:= false
	for _f in 400:
		await get_tree().process_frame
		if not rake._gathered.is_empty():
			carried = true
		if rake.last_gathered > 0:
			break
	_check("...the stroke picks them up onto the head", carried)
	_check("...and throws them with its load (%d)" % rake.last_gathered,
		rake.last_gathered == laid.size())
	rake.set_process(false)
	for _f in 120:
		await get_tree().physics_frame
	var behind:= 0
	var loose:= 0
	var strands_out:= 0
	for w in laid:
		if not is_instance_valid(w):
			continue
		strands_out += w.strands
		if (w.global_position - rake.global_position).dot(fwd) < 0.0:
			behind += 1
		if not w.is_held() and not w.freeze and not w.has_meta(PropManager.META_CLAIM):
			loose += 1
	_check("...they land behind the machine (%d of %d)" % [behind, laid.size()],
		behind == laid.size())
	_check("...let go and unclaimed (%d of %d)" % [loose, laid.size()],
		loose == laid.size())
	_check("...with every straw still in them (%d of %d)" % [strands_out, strands_in],
		strands_out == strands_in)


	for w in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(w)
	await get_tree().process_frame
	var spot:= rake.bite_point(0)
	spot.y = field.height_at(spot.x, spot.z) + 0.35
	var last:= world.props.spawn("hay_wad", Transform3D(Basis(), spot),
		{ "strands": 40 }) as HayWad
	LiveStrandManager.release_hold(last)
	for _f in 60:
		await get_tree().physics_frame
	rake.set_process(true)
	var on_head:= false
	for _f in 400:
		await get_tree().process_frame
		if not rake._gathered.is_empty():
			on_head = true
			break
	rake.set_process(false)
	_check("a lone wad goes onto the head", on_head)
	world.builds.demolish(rake)
	await get_tree().process_frame
	_check("...and a rake taken down mid stroke lets it go",
		is_instance_valid(last) and not last.is_held() and not last.freeze
		and not last.has_meta(PropManager.META_CLAIM))
	for w in _wad_list(site [0] as Vector3, 30.0):
		world.props.remove(w)
	await get_tree().process_frame


const MOUNTAIN_STROKES:= 30


func _mountain_face() -> void:
	if Cfg.pile_size_id != "mountain":
		_check("run with --pile mountain (the pile is %s)" % Cfg.pile_size_id, false)
		return
	var ua:= OS.get_cmdline_user_args()
	Tech.reset()
	Tech.grant("rake_bite", _arg_int(ua, "--bite", 2))
	Tech.grant("rake_speed", _arg_int(ua, "--speed", 5))
	GameState.add_money(50000.0)


	var want:= maxi(1, _arg_int(ua, "--strokes", MOUNTAIN_STROKES))
	var row:= maxi(1, _arg_int(ua, "--row", 1))


	var site:= _mountain_site(Cfg.RAKE_THROW_DISTANCE + 1.0)
	if site.is_empty():
		site = _mountain_site()
	_check("found a buildable spot at the mountain's toe", not site.is_empty())
	if site.is_empty():
		return
	var at: Vector3 = site [0]
	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var field: HayField = world.field
	var tail:= PistonRake.BODY_L * 0.5 - PistonRake.BODY_Z
	print("[rake] site %s, %.2f m from the pile centre, a stroke every %.2f s"
		% [at, Vector2(at.x - Cfg.PILE_CENTER.x, at.z - Cfg.PILE_CENTER.z).length(),
		Tech.rake_throw_seconds()])
	var profile:= PackedStringArray()
	for d: float in [1.8, 2.0, 2.3, 2.55, 3.0, 3.5]:
		var p:= at + fwd * d
		profile.append("%.2f m %.2f" % [d, field.height_at(p.x, p.z) - at.y])
	print("[rake] hay ahead of the origin: ", ", ".join(profile))
	for m: float in [3.0, 5.5, 8.0]:
		print("[rake] clear air behind to %.1f m: %s" % [m, _clear_behind(at, fwd, m)])

	var rake: PistonRake = world.builds.add_piston_rake(at, site [1])
	await get_tree().process_frame


	var rakes: Array [PistonRake] = [rake]
	var right:= Vector3(fwd.z, 0.0, - fwd.x)
	var tool: BuildTool = player.build
	for k in range(1, row):
		var side:= 1.0 if k % 2 == 1 else -1.0
		var lateral:= at + right * (side * float(ceili(k / 2.0)) * (Cfg.RAKE_HALF_WIDTH * 2.0 + 0.05))
		var spot_ok:= Vector3.INF
		for step in 25:
			var spot:= lateral - fwd * 3.0 + fwd * (float(step) * 0.25)
			spot.y = field.height_at(spot.x, spot.z)
			if spot.y > 0.1:
				break
			var verdict: Dictionary = tool._evaluate_rake(spot, Vector3.UP, fwd)
			if verdict ["ok"]:
				spot_ok = spot
		if spot_ok == Vector3.INF:
			print("[rake] row: no spot for rake %d" % k)
			continue
		rakes.append(world.builds.add_piston_rake(spot_ok, site [1]))
		print("[rake] row: rake %d at %s" % [rakes.size() - 1, spot_ok])
		await get_tree().process_frame
	var row_peak: Array [int] = []
	var row_alert: Array [String] = []
	for _r in rakes:
		row_peak.append(0)
		row_alert.append("")


	var heap:= _arg_int(ua, "--tuftheap", 0)
	if heap > 0:
		for rr in rakes:
			rr.set_process(false)
		var laid:= 0
		for rr in rakes:
			var rf:= rr._forward()
			var rs:= Vector3(rf.z, 0.0, - rf.x)
			var n:= 0
			for d: float in [1.95, 2.4, 2.85]:
				for l: float in [0.0, 0.45, -0.45, 0.9, -0.9]:
					if n >= heap:
						continue
					var p:= rr.global_position + rf * d + rs * l
					p.y = maxf(rr.global_position.y, field.height_at(p.x, p.z)) + 0.25
					if world.props.spawn("hay_tuft", Transform3D(Basis(), p), { "strands": 40 }) != null:
						n += 1
			laid += n
		for _f in 90:
			await get_tree().physics_frame
		print("[rake] heap: laid %d tufts, in front of each head now: %s" % [laid,
			", ".join(rakes.map(func(rr: PistonRake) -> String: return str(rr._gatherable().size())))])
		for rr in rakes:
			rr.set_process(true)

	var strokes:= 0
	var dry_peak:= 0
	var first_alert:= ""
	var stalled_before:= false
	var threw:= false
	var flying: Array [HayWad] = []
	var prev_release:= Vector3.INF
	var landed_behind:= 0
	var landed_short:= 0
	var empty_bites:= 0
	var stalls:= 0
	var frames_left:= int(float(want) * Tech.rake_throw_seconds() * 60.0 * 2.0) + 600


	var hitch_ms:= _arg_int(ua, "--hitch", 0)
	var hitched:= false
	while strokes < want and frames_left > 0:
		frames_left -= 1
		await get_tree().process_frame
		if hitch_ms > 0:
			if rake._clock < 0.0:
				hitched = false
			elif not hitched and rake._clock >= PistonRake.F_RELEASE - 6.0:
				hitched = true
				OS.delay_msec(hitch_ms)
		dry_peak = maxi(dry_peak, rake._dry_strokes)
		for ri in rakes.size():
			var rr:= rakes [ri]
			if rr._dry_strokes > row_peak [ri]:
				row_peak [ri] = rr._dry_strokes
				if rr._dry_strokes >= PistonRake.DRY_STROKES_BEFORE_FAULT and (rr._dry_strokes <= 4 or rr._dry_strokes % 20 == 0):
					print("[rake] row %d dry %d at stroke %d: bite %.1f thrown %d gathered %d held %.1f front %d | release %s | last load: %s"
						% [ri, rr._dry_strokes, strokes, rr.last_bite, rr.last_thrown,
						rr.last_gathered, rr._held, rr._gatherable().size(),
						rr._release_at - rr.global_position, _load_where(rr)])
			var rw:= rr.alert_reason()
			if rw != "" and row_alert [ri] == "":
				row_alert [ri] = "%s (stroke %d)" % [rw, strokes]
		var why:= rake.alert_reason()
		if why != "" and first_alert == "":
			first_alert = "%s (after %d strokes)" % [why, strokes]


		if rake._clock >= 0.0 and not rake._did_throw:
			stalled_before = rake._load_stalled()
		var throw_now:= rake._did_throw and not threw
		threw = rake._did_throw
		if not throw_now:
			continue
		strokes += 1
		if strokes % 25 == 0:
			var fronts:= PackedStringArray()
			for rr in rakes:
				fronts.append("%d/%d" % [rr._gatherable().size(), rr._dry_strokes])
			print("[rake] row at %d strokes, wads in front/dry: %s" % [strokes, ", ".join(fronts)])
		var short_before:= landed_short
		var rest:= PackedStringArray()
		for w in flying:
			if not is_instance_valid(w):
				rest.append("gone")
				continue
			var o:= w.global_position - rake.global_position
			var ahead:= o.dot(fwd)
			if ahead < - tail:
				landed_behind += 1
			else:
				landed_short += 1
			rest.append("fwd %.2f up %.2f from release %.2f v %.2f%s%s" % [ahead, o.y,
				w.global_position.distance_to(prev_release), w.linear_velocity.length(),
				" frozen" if w.freeze else "", " held" if w.is_held() else ""])
		if rake.last_bite <= 0.0:
			empty_bites += 1
		if stalled_before:
			stalls += 1
		var quiet:= strokes > 5 and strokes % 25 != 0 and rake.last_bite > 0.0 and not stalled_before and rake._dry_strokes == 0 and landed_short == short_before
		if quiet:
			flying = rake._last_load.duplicate()
			prev_release = rake._release_at
			continue
		var rel:= rake._release_at - rake.global_position
		var head:= rake._head_point()
		print("[rake] #%02d bite %.1f thrown %d gathered %d held %.1f stalled %s dry %d"
			% [strokes, rake.last_bite, rake.last_thrown, rake.last_gathered, rake._held,
			stalled_before, rake._dry_strokes]
			+ " | release fwd %.2f up %.2f, hay under it %.2f | face at reach %.2f"
			% [rel.dot(fwd), rel.y,
			field.height_at(rake._release_at.x, rake._release_at.z) - at.y,
			field.height_at(head.x, head.z) - at.y]
			+ " | last load: " + ("-" if rest.is_empty() else "; ".join(rest)))
		flying = rake._last_load.duplicate()
		prev_release = rake._release_at

	print("[rake] hay over the chassis after: %.2f m, wads in front of the head: %d"
		% [player.build._rake_hay_over_chassis(at, fwd, field), rake._gatherable().size()])
	if strokes < want:
		print("[rake] stopped stroking after %d: %s" % [strokes, rake.alert_reason()])
	_check("the rake kept stroking (%d of %d)" % [strokes, want], strokes >= want)
	_check("no bite came back empty (%d empty)" % empty_bites, empty_bites == 0)
	_check("no load stayed in the mouth (%d stalled)" % stalls, stalls == 0)
	_check("every load landed past the tail (%d behind, %d short)"
		% [landed_behind, landed_short], landed_short == 0)
	_check("it never said STROKING BUT EMPTY (peak dry %d, first alert: %s)"
		% [dry_peak, first_alert if first_alert != "" else "none"],
		dry_peak < PistonRake.DRY_STROKES_BEFORE_FAULT)
	for ri in range(1, rakes.size()):
		_check("row rake %d never said STROKING BUT EMPTY (peak dry %d, first alert: %s)"
			% [ri, row_peak [ri], row_alert [ri] if row_alert [ri] != "" else "none"],
			row_peak [ri] < PistonRake.DRY_STROKES_BEFORE_FAULT)
		world.builds.demolish(rakes [ri])
	world.builds.demolish(rake)
	await get_tree().process_frame


func _arg_int(ua: PackedStringArray, flag: String, fallback: int) -> int:
	var i:= ua.find(flag)
	if i >= 0 and i + 1 < ua.size():
		return int(ua [i + 1])
	return fallback


func _load_where(rr: PistonRake) -> String:
	var out:= PackedStringArray()
	var f:= rr._forward()
	for w in rr._last_load:
		if not is_instance_valid(w):
			out.append("gone")
			continue
		var o:= w.global_position - rr.global_position
		out.append("%s fwd %.2f up %.2f from release %.2f v %.2f%s%s" % [
			"tuft" if w is HayTuft else "wad", o.dot(f), o.y,
			w.global_position.distance_to(rr._release_at), w.linear_velocity.length(),
			" frozen" if w.freeze else "", " held" if w.is_held() else ""])
	return "-" if out.is_empty() else "; ".join(out)


func _mountain_site(behind:= 0.0) -> Array:
	var field: HayField = world.field
	var tool: BuildTool = player.build
	var c:= Cfg.PILE_CENTER
	for step in 48:
		var a:= TAU * float(step) / 48.0
		var out:= Vector3(cos(a), 0.0, sin(a))
		var best: Array = []
		var ring:= Cfg.FIELD_EXTENT - 1.0
		while ring > 15.0:
			var spot:= Vector3(c.x, 0.0, c.z) + out * ring
			spot.y = field.height_at(spot.x, spot.z)
			if spot.y > 0.1:
				break
			var verdict: Dictionary = tool._evaluate_rake(spot, Vector3.UP, - out)
			if verdict ["ok"] and (behind <= 0.0 or _clear_behind(spot, - out, behind)):
				best = [spot, atan2(- out.x, - out.z)]
			elif not best.is_empty():
				break
			ring -= 0.25
		if not best.is_empty():
			return best
	return []


func _strokes_in(rake: PistonRake, frames: int) -> int:
	var strokes:= 0
	var idle:= rake._clock < 0.0
	for _f in frames:
		await get_tree().physics_frame
		var now_idle:= rake._clock < 0.0
		if idle and not now_idle:
			strokes += 1
		idle = now_idle
	return strokes


func _needle_in_the_bite() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame

	var field: HayField = world.field
	var at:= rake.bite_point(0)
	at.y = field.height_at(at.x, at.z)
	var from: Vector3 = rake.global_position + Vector3(0.0, 1.2, 0.0)
	var index:= GameState.register_needle(at, null, 0)


	rake._bite_sites = []
	for _i in 200:
		rake._throw_needle(from)
	_check("a stroke that carved nothing turns up nothing",
		GameState.needle_taken [index] == 0)


	rake._bite_sites = [at]
	var before: int = world.live.needles.size()
	for _i in 200:
		rake._throw_needle(from)
		if GameState.needle_taken [index] == 1:
			break
	_check("a needle in the carved bite comes up",
		GameState.needle_taken [index] == 1)

	var body: RigidBody3D = null
	if world.live.needles.size() > before:
		body = world.live.needles [before]
	_check("...as a real body in the world", body != null)
	if body != null:
		_check("...lifted onto the head rather than left in the hole",
			body.global_position.distance_to(from) < 0.5)


		var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
		_check("...and thrown backwards with the load (%.1f m/s)"
			% body.linear_velocity.length(),
			body.linear_velocity.length() > 0.5
			and body.linear_velocity.dot(fwd) < 0.0)


		body.global_position = at
		body.linear_velocity = Vector3.ZERO
		world.live.pin_needle(body)
		rake._bite_sites = [at]
		rake._throw_needle(from)
		_check("a needle lying pinned in the bite goes on the FIRST stroke",
			body.global_position.distance_to(from) < 0.5)
		_check("...and is handed back to physics, not thrown still frozen",
			not body.freeze)

	world.builds.demolish(rake)
	await get_tree().process_frame


func _dismantle() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame

	var body: StaticBody3D = null
	for c in rake.get_children():
		if c is StaticBody3D:
			body = c
	_check("the rake has a collider", body != null)
	if body != null:
		_check("...on the build layer the dismantle ray tests",
			(body.collision_layer & Cfg.L_BUILD) != 0)
		_check("...and BuildManager can trace it back to the machine",
			world.builds.owner_of(body) == rake)

	var purse: float = GameState.money
	var refund: float = world.builds.demolish(rake)
	_check("dismantling refunds the build cost ($%.0f)" % refund,
		is_equal_approx(refund, Cfg.RAKE_COST))
	_check("...and the machine is off the ledger",
		not world.builds.piston_rakes.has(rake))
	GameState.add_money(purse - GameState.money)
	await get_tree().process_frame


func _throw_range() -> void:
	Tech.reset()
	Tech.grant("rake_bite", 1)
	var near:= await _land_distance(Cfg.RAKE_THROW_MIN)
	var far:= await _land_distance(Cfg.RAKE_THROW_MAX)


	var tail:= PistonRake.BODY_L * 0.5 - PistonRake.BODY_Z
	_check("even the shortest setting lands past the tail (%.1f m, tail %.1f m)"
		% [near, tail], near > tail + 0.3)
	_check("a long setting lands further out (%.1f m vs %.1f m)" % [far, near],
		far > near + 1.0)
	Tech.reset()


func _ring_matches_landing() -> void:
	Tech.reset()
	Tech.grant("rake_bite", 1)

	for metres: float in [Cfg.RAKE_THROW_MAX, 7.0, 5.5, 4.0, 3.25, Cfg.RAKE_THROW_MIN]:
		var site:= _site(Cfg.RAKE_THROW_MAX + 1.0)
		if site.is_empty():
			_check("found a spot to throw from", false)
			break
		var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
		rake.throw_distance = metres
		rake.show_range(true)
		await get_tree().process_frame
		var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
		var origin: Vector3 = rake.global_position
		var before: Array = _wad_list(origin, 40.0)
		var down: Dictionary = { }
		var prev: Dictionary = { }
		for _i in 600:
			await get_tree().physics_frame
			for w in _wad_list(origin, 40.0):
				if w in before or down.has(w):
					continue
				var wad:= w as HayWad
				var y: float = wad.global_position.y


				if prev.has(wad) and wad.linear_velocity.y > float(prev [wad]) + 0.5 and float(prev [wad]) < -1.0:
					down [wad] = - (wad.global_position - origin).dot(fwd)
				prev [wad] = wad.linear_velocity.y
				if y < origin.y - 1.0:
					down [wad] = NAN
			if rake.last_thrown > 0 and not down.is_empty() and down.size() >= prev.size():
				break
		var aim: float = - (rake.discharge_spot() - origin).dot(fwd)
		var ring: float = (rake.find_child("Range", false, false) as RakeRange).target_offset()
		var sum:= 0.0
		var n:= 0
		for k in down.keys():
			var d: float = down [k]
			if not is_nan(d):
				sum += d
				n += 1
		var landed: float = sum / float(n) if n > 0 else NAN
		print("[rake]      setting %.2f  ring %.2f  aimed %.2f  touched down %.2f  (%d wads)"
			% [metres, ring, aim, landed, n])
		_check("the ring at %.2f m sits where the wad comes down (%.2f vs %.2f)"
			% [metres, ring, landed], n > 0 and absf(ring - landed) < 0.4)


		var arrow: float = - (rake.throw_aim().landing() - origin).dot(fwd)
		_check("the arrow at %.2f m hangs where the wad comes down (%.2f vs %.2f)"
			% [metres, arrow, landed], n > 0 and absf(arrow - landed) < 0.4)
		world.builds.demolish(rake)
		await get_tree().process_frame
	Tech.reset()


func _edge_of_face() -> void:
	Tech.reset()
	var site:= _edge_site()
	_check("found a face that runs out under one side of the head",
		not site.is_empty())
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	_check("the machine thinks it has a face to work: %s"
		% ["yes" if rake.alert_reason() == "" else rake.alert_reason()],
		rake.alert_reason() == "")
	await _one_stroke(rake)
	_check("a rake at the end of a face still carves (%.1f straw)" % rake.last_bite,
		rake.last_bite > 0.0)
	_check("...and still throws what it carved (%d)" % rake.last_thrown,
		rake.last_thrown > 0)
	_check("...and does not call itself faulty for it: %s"
		% ["quiet" if rake.alert_reason() == "" else rake.alert_reason()],
		rake.alert_reason() == "")
	world.builds.demolish(rake)


func _worn_middle() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame


	var field: HayField = world.field
	var mid:= rake.bite_point(0)
	var step: float = Cfg.CELL * 0.5
	var clear_radius:= 0.5
	var n:= int(ceil(clear_radius / step))
	for a in range(- n, n + 1):
		for b in range(- n, n + 1):
			var p:= mid + Vector3(a * step, 0.0, b * step)
			if mid.distance_to(p) > clear_radius:
				continue
			field.carve_column(p.x, p.z, 50.0)

	_check("the trench leaves hay under the ends of the head", rake._has_face())
	rake._bite()
	_check("a rake in its own trench still reaches the face (%.1f straw)"
		% rake.last_bite, rake.last_bite > 0.0)


	var strokes:= 0
	var dry:= 0
	while rake._has_face() and strokes < 400:
		rake._bite()
		strokes += 1
		if rake.last_bite <= 0.0:
			dry += 1


	_check("it never strokes empty while it has a face (%d strokes, %d dry)"
		% [strokes, dry], dry == 0)
	world.builds.demolish(rake)
	await get_tree().process_frame


func _walled_in() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame


	var field: HayField = world.field
	var half_w: float = Cfg.RAKE_HALF_WIDTH * 0.7 + Cfg.RAKE_BITE_RADIUS
	var half_l: float = Cfg.RAKE_BITE_RADIUS
	var step: float = Cfg.CELL * 0.5
	var across: int = int(ceil(half_w / step))
	var along: int = int(ceil(half_l / step))
	for a in range(- across, across + 1):
		for b in range(- along, along + 1):
			var p: Vector3 = rake.to_global(Vector3(a * step, 0.0,
				Cfg.RAKE_REACH + b * step))
			field.carve_column(p.x, p.z, 50.0)

	_check("the old reach line is scraped to the floor",
		field.height_at(rake.bite_point(0).x, rake.bite_point(0).z) < 0.01)
	_check("...and the machine still finds hay off it", rake._has_face())
	rake._bite()
	_check("...and still takes some (%.1f straw)" % rake.last_bite,
		rake.last_bite > 0.0)
	world.builds.demolish(rake)
	await get_tree().process_frame


func _edge_site() -> Array:
	var field: HayField = world.field
	for ring_step in range(12, 30):
		var ring:= float(ring_step) * 0.5
		for step in 36:
			var a:= TAU * float(step) / 36.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			at.y = field.height_at(at.x, at.z)
			if at.y > 0.1:
				continue
			for turn in 36:
				var yaw:= TAU * float(turn) / 36.0
				var fwd:= Vector3(sin(yaw), 0.0, cos(yaw))
				var head:= at + fwd * Cfg.RAKE_REACH
				if field.height_at(head.x, head.z) <= at.y + 0.25:
					continue


				var across:= Vector3(cos(yaw), 0.0, - sin(yaw))
				var arm:= Cfg.RAKE_HALF_WIDTH * 0.7
				var left:= head - across * arm
				var right:= head + across * arm
				var l:= field.height_at(left.x, left.z) > at.y + 0.06
				var r:= field.height_at(right.x, right.z) > at.y + 0.06
				if l != r:
					return [at, yaw]
	return []


func _range_marks() -> void:
	Tech.reset()
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	var marks:= rake.find_child("Range", false, false) as RakeRange
	_check("a placed rake carries reach marks", marks != null)
	if marks == null:
		return
	_check("...which are off until somebody asks", not marks.visible)

	var bounds:= marks.bite_bounds()
	var half:= PistonRake.BITE_PASSES / 2
	var covered:= true
	for offset: int in [- half, - half / 2, 0, half / 2, half]:
		var local: Vector3 = rake.to_local(rake.bite_point(offset))


		if not bounds.has_point(Vector3(local.x, bounds.position.y + bounds.size.y * 0.5,
				local.z)):
			covered = false
	_check("every pass the head takes falls inside the mark", covered)


	var want: float = PistonRake.bite_disc_radius() + Cfg.RAKE_BITE_RADIUS
	_check("...and the mark is that wide and no wider (%.2f vs %.2f)"
		% [bounds.size.x * 0.5, want], absf(bounds.size.x * 0.5 - want) < 0.15)


	_check("...and it is a circle, not a band (%.2f x %.2f)"
		% [bounds.size.x, bounds.size.z], absf(bounds.size.x - bounds.size.z) < 0.05)
	_check("...centred on the head, one reach in front (%.2f)"
		% (bounds.position.z + bounds.size.z * 0.5),
		absf(bounds.position.z + bounds.size.z * 0.5 - Cfg.RAKE_REACH) < 0.05)


	rake.throw_distance = Cfg.RAKE_THROW_MIN
	rake.show_range(true)
	_check("the marks come on when asked", marks.visible)
	_check("the landing ring sits where the throw lands (%.2f)" % marks.target_offset(),
		absf(marks.target_offset() - Cfg.RAKE_THROW_MIN) < 0.01)
	rake.throw_distance = Cfg.RAKE_THROW_MAX
	rake.show_range(true)
	_check("...and moves with the slider (%.2f)" % marks.target_offset(),
		absf(marks.target_offset() - Cfg.RAKE_THROW_MAX) < 0.01)


	var other: PistonRake = world.builds.add_piston_rake(
		site [0] + Vector3(6.0, 0.0, 0.0), site [1])
	await get_tree().process_frame
	var other_marks:= other.find_child("Range", false, false) as RakeRange
	world.builds.show_rake_range(other)
	_check("showing one rake's marks takes the other's away", not marks.visible)
	_check("...and puts them under the one being asked about", other_marks.visible)
	world.builds.show_rake_range(null)
	_check("nothing being asked shows none", not other_marks.visible)


	var panel: RakePanel = player.rake_panel
	_check("the player has a throw panel", panel != null)
	if panel != null:


		rake.throw_distance = 6.75
		panel.open(rake)
		await get_tree().process_frame
		_check("opening the panel leaves the throw alone (%.2f m)" % rake.throw_distance,
			absf(rake.throw_distance - 6.75) < 0.01)
		_check("...and the panel is showing that same number",
			absf(marks.target_offset() - 6.75) < 0.01)
		_check("opening the throw panel draws that rake's marks", marks.visible)
		_check("...and only that one's", not other_marks.visible)
		_check("...and turns its arrow orange", rake.throw_aim().mode() == ThrowAim.PANEL)
		_check("...with the arc drawn", rake.throw_aim().arc_drawn())
		panel.close()
		await get_tree().process_frame
		_check("closing it takes them away again", not marks.visible)


		panel.open(rake)
		await get_tree().process_frame
		panel._on_pin()
		panel.close()
		await get_tree().process_frame
		_check("the show range button keeps the marks up with the panel shut",
			marks.visible and rake.throw_aim().mode() == ThrowAim.PANEL)
		_check("...for two minutes (%.0f s left)" % rake.range_pinned_left(),
			rake.range_pinned_left() > Cfg.RANGE_PIN_SECONDS - 5.0)
		rake.pin_range(0.4)
		await get_tree().create_timer(0.8).timeout
		_check("...and takes them down when the time is up",
			not marks.visible and rake.throw_aim().mode() != ThrowAim.PANEL)


	var aim:= rake.throw_aim()
	var other_aim:= other.throw_aim()
	_check("a placed rake carries an arrow", aim != null and other_aim != null)
	if aim != null and other_aim != null:
		_check("...which is off until somebody looks", aim.mode() == ThrowAim.OFF)
		_check("...and the flat landing ring is not drawn under it",
			not marks.throw_marks_shown())
		ThrowAim.set_hovered(rake.throw_aim())
		_check("looking at a rake shows its gray arrow", aim.mode() == ThrowAim.HOVER)
		ThrowAim.set_hovered(other.throw_aim())
		_check("looking away moves it to the other one",
			aim.mode() == ThrowAim.OFF and other_aim.mode() == ThrowAim.HOVER)
		rake.show_range(true)
		_check("the panel's orange wins over a gray arrow elsewhere",
			aim.mode() == ThrowAim.PANEL and other_aim.mode() == ThrowAim.HOVER)
		ThrowAim.set_hovered(rake.throw_aim())
		rake.show_range(false)
		_check("...and shutting the panel on a hovered rake leaves it gray",
			aim.mode() == ThrowAim.HOVER)
		ThrowAim.set_hovered(null)
		_check("looking at nothing shows none",
			aim.mode() == ThrowAim.OFF and other_aim.mode() == ThrowAim.OFF)


		var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
		var at_setting: Array [float] = []
		for metres: float in [Cfg.RAKE_THROW_MIN + 0.5, Cfg.RAKE_THROW_MAX - 0.5]:
			rake.throw_distance = metres
			rake.show_range(true)
			for _f in 3:
				await get_tree().process_frame
			at_setting.append(- (aim.landing() - rake.global_position).dot(fwd))
		rake.show_range(false)
		_check("...and the arrow follows the slider (%.2f then %.2f)"
			% [at_setting [0], at_setting [1]], at_setting [1] - at_setting [0] > 3.0)

	world.builds.demolish(other)
	world.builds.demolish(rake)


func _console_reach() -> void:
	var site:= _site()
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	await get_tree().process_frame
	await get_tree().process_frame
	var builds: BuildManager = world.builds
	var mid:= rake.global_position + Vector3(0.0, 1.0, 0.0)
	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var side:= fwd.cross(Vector3.UP).normalized()


	for named: Array in [["the flank", side], ["the far flank", - side],
			["behind it", - fwd]]:
		var eye: Vector3 = mid + (named [1] as Vector3) * 2.0
		_check("aiming at the rake from %s offers the panel" % named [0],
			builds.rake_under(eye, mid - eye) == rake)


	_check("standing at the console looking away does not offer it",
		builds.rake_under(rake.console_position() + Vector3(0.0, 0.6, 0.0),
			Vector3.UP) == null)
	var away: Vector3 = mid - side * 2.5
	_check("looking away from a rake beside you does not offer it",
		builds.rake_under(away, - side) == null)
	var distant: Vector3 = mid + side * (Cfg.RAKE_CONSOLE_REACH + 4.0)
	_check("aiming at a rake from across the yard does not offer it",
		builds.rake_under(distant, mid - distant) == null)


	if player != null:
		player.global_position = rake.console_position()


		for i in 4:
			var to:= mid - player.eye_position()
			player.rotation.y = atan2(- to.x, - to.z)
			player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
			await get_tree().process_frame
		_check("the hint strip names the panel at the console, looking at the rake",
			_hint_says("Set the rake"))
		player.global_position = mid + side * (Cfg.RAKE_CONSOLE_REACH + 8.0)
		for i in 4:
			await get_tree().process_frame
		_check("...and stops naming it from across the yard",
			not _hint_says("Set the rake"))

	world.builds.demolish(rake)


func _hint_says(text: String) -> bool:
	var hud: Hud = world.get("hud") as Hud
	if hud == null or hud._hints == null:
		return false
	for row: PackedStringArray in hud._hints._hints():
		for cell in row:
			if cell.findn(text) >= 0:
				return true
	return false


func _land_distance(metres: float) -> float:
	var site:= _site()
	if site.is_empty():
		return 0.0
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])
	rake.throw_distance = metres
	await get_tree().process_frame
	var before: Array = _wad_list(rake.global_position, 30.0)
	await _one_stroke(rake)


	for _i in 400:
		var moving:= false
		for w in _wad_list(rake.global_position, 40.0):
			if not (w in before) and w.linear_velocity.length() > 0.4:
				moving = true
				break
		if not moving:
			break
		await get_tree().process_frame
	var fwd:= Vector3(sin(site [1]), 0.0, cos(site [1]))
	var best:= 0.0
	for w in _wad_list(rake.global_position, 40.0):
		if w in before:
			continue

		var d: float = - (w.global_position - rake.global_position).dot(fwd)
		best = maxf(best, d)
	world.builds.demolish(rake)
	await get_tree().process_frame
	return best


func _wad_list(centre: Vector3, radius: float) -> Array:
	var out: Array = []
	for item in world.props.items:
		if item is HayWad and is_instance_valid(item) and item.global_position.distance_to(centre) < radius:
			out.append(item)
	return out


func _wads_near(centre: Vector3, radius: float) -> int:
	return _wad_list(centre, radius).size()


func _last_int(s: String) -> int:
	var out:= ""
	for i in s.length():
		var c:= s [i]
		if c >= "0" and c <= "9":
			out += c
		elif not out.is_empty() and (c == " " or c == "%"):

			if i + 1 < s.length():
				var rest:= s.substr(i + 1)
				var has_more:= false
				for j in rest.length():
					if rest [j] >= "0" and rest [j] <= "9":
						has_more = true
						break
				if has_more:
					out = ""
	return -1 if out.is_empty() else out.to_int()


func _drives() -> void:
	Tech.reset()
	var tool: BuildTool = player.build

	_check("Rake Wheels is in the tree", TechTree.has_id("rake_wheels"))
	_check("...hanging off the rake", TechTree.requires("rake_wheels").has("piston_rake"))
	_check("...and a fresh run has not got it", not Tech.rake_wheels_unlocked())
	var site:= _site(14.0)
	_check("found a spot to drive a rake from", not site.is_empty())
	if site.is_empty():
		return
	var rake: PistonRake = world.builds.add_piston_rake(site [0], site [1])


	rake.set_switched_off(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fwd: Vector3 = rake.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var yaw:= rake.global_rotation.y


	var wheels: Array [Node3D] = []
	for wheel_name in PistonRake.N_WHEELS:
		var w:= rake.find_child(wheel_name, true, false) as Node3D
		if w != null:
			wheels.append(w)
	_check("the model carries both road wheels (%d)" % wheels.size(), wheels.size() == 2)
	var hub_before: Array [Vector3] = []
	var turn_before: Array [Basis] = []
	for w in wheels:
		hub_before.append(rake.to_local(w.global_position))
		turn_before.append(w.global_basis.orthonormalized())

	var back:= await _drive_and_wait(rake, -1.0)
	var roll:= PistonRake.DRIVE_STEP / PistonRake.WHEEL_RADIUS
	for i in wheels.size():
		var w:= wheels [i]
		var turned:= (turn_before [i].inverse() * w.global_basis.orthonormalized()).get_rotation_quaternion()
		_check("wheel %s turned %.2f rad for half a metre (%.2f)"
			% [w.name, roll, turned.get_angle()], absf(turned.get_angle() - roll) < 0.02)


		var axis: Vector3 = turn_before [i] * turned.get_axis()
		var rolls:= Vector3.UP.cross(- fwd).normalized()
		_check("...about its axle, rolling backwards (%.3f)" % axis.dot(rolls),
			axis.dot(rolls) > 0.999)
		_check("...and in place on its hub (%.3f m)"
			% rake.to_local(w.global_position).distance_to(hub_before [i]),
			rake.to_local(w.global_position).distance_to(hub_before [i]) < 0.001)
	_check("the drive loop is let go when it stops", rake._drive_voice < 0)
	_check("Back drives it half a metre back (%.3f m)" % back,
		absf(back + PistonRake.DRIVE_STEP) < 0.01, rake.drive_blocked)
	_check("...without turning it", absf(rake.global_rotation.y - yaw) < 0.001)
	var ahead:= await _drive_and_wait(rake, 1.0)
	_check("Forward drives it half a metre ahead (%.3f m)" % ahead,
		absf(ahead - PistonRake.DRIVE_STEP) < 0.01, rake.drive_blocked)


	var across:= Vector3(fwd.z, 0.0, - fwd.x)
	var tail:= rake.global_position - fwd * (PistonRake.BODY_L * 0.5
		- PistonRake.BODY_Z + Cfg.RAKE_SITE_MARGIN + Cfg.BELT_WIDTH * 0.5 + 0.25)
	var belt: Conveyor = world.builds.add_conveyor(
		tail + across * 2.0 + Vector3.UP * 0.45, tail - across * 2.0 + Vector3.UP * 0.45)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var short:= await _drive_and_wait(rake, -1.0)
	_check("a belt behind it stops it short (%.3f m)" % short,
		short > - PistonRake.DRIVE_STEP + 0.01)
	_check("...because it is blocked (%s)" % rake.drive_blocked,
		rake.drive_blocked == tr("blocked"))
	_check("...and the chassis is not in the belt", not _chassis_hits(rake))
	world.builds.demolish(belt)
	await get_tree().physics_frame


	var went:= 0.0
	for _i in 40:
		went += await _drive_and_wait(rake, 1.0)
		if rake.drive_blocked != "":
			break
	_check("driven at the pile it stops (%.2f m in)" % went, rake.drive_blocked != "")
	_check("...because it is at the hay (%s)" % rake.drive_blocked,
		rake.drive_blocked == tr("too close to the hay"))
	var deep: float = tool._rake_hay_over_chassis(rake.global_position, fwd, world.field)
	_check("...with the straw no deeper over the chassis than a new one allows (%.2f m)"
		% deep, deep <= Cfg.RAKE_STAND_CLEAR + 0.02)
	world.builds.demolish(rake)
	await get_tree().physics_frame


	var deck_at: Vector3 = site [0] - fwd * 9.0 + Vector3.UP * 2.0
	var deck: Platform = world.builds.add_platform(deck_at, Vector2(6.0, 6.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nose:= PistonRake.BODY_Z + PistonRake.BODY_L * 0.5
	var on_deck: PistonRake = world.builds.add_piston_rake(
		deck_at + Vector3(0.0, 0.0, 3.0 - nose - 0.25), 0.0)
	on_deck.set_switched_off(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var over: Vector3 = on_deck.global_position + Vector3(0.0, 0.0, 1.0)
	_check("a spot past the deck edge is refused as no ground (%s)"
		% tool.rake_drive_reason(on_deck, over),
		tool.rake_drive_reason(on_deck, over) == tr("no ground under it"))
	var edge:= await _drive_and_wait(on_deck, 1.0)
	_check("driven at the edge it stops short (%.3f m)" % edge,
		edge < PistonRake.DRIVE_STEP - 0.01, on_deck.drive_blocked)
	_check("...with its nose still over the deck (%.2f of 3.00 m)"
		% (on_deck.global_position.z - deck_at.z + nose - 0.1),
		on_deck.global_position.z - deck_at.z + nose - 0.1 <= 3.0)
	_check("...and it did not sink or climb", absf(on_deck.global_position.y - deck_at.y) < 0.001)
	world.builds.demolish(on_deck)
	world.builds.demolish(deck)
	await get_tree().physics_frame


func _drive_and_wait(rake: PistonRake, direction: float) -> float:
	var from:= rake.global_position
	rake.drive(direction, player.build.rake_drive_reason)
	for _i in 600:
		await get_tree().process_frame
		if not rake.is_driving():
			break
	var fwd: Vector3 = rake.global_basis.z
	fwd.y = 0.0
	return (rake.global_position - from).dot(fwd.normalized())


func _chassis_hits(rake: PistonRake) -> bool:
	var box:= BoxShape3D.new()
	box.size = Vector3(PistonRake.BODY_W, PistonRake.BODY_H - 0.2, PistonRake.BODY_L)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	q.transform = rake.global_transform * Transform3D(Basis(),
		Vector3(0.0, PistonRake.BODY_H * 0.5, PistonRake.BODY_Z))
	var own: Array [RID] = []
	for child in rake.get_children():
		if child is CollisionObject3D:
			own.append((child as CollisionObject3D).get_rid())
	q.exclude = own
	return not world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("[rake] ok   %s" % what)
	else:
		_fail += 1
		printerr("[rake] FAIL %s%s" % [what,
			"" if detail == "" else "  (%s)" % detail])
