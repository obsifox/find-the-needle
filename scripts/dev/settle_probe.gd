class_name DevSettleProbe
extends Node


const HEAP:= 360

const POUR_PER_TICK:= 4

const SPOT:= Vector3(13.0, 0.0, -2.0)

const POUR_ON:= 360
const SETTLE_TICKS:= 300
const MEASURE_TICKS:= 240

var world: Node3D
var player: Player

var _live: LiveStrandManager
var _field: HayField
var _fails: PackedStringArray = PackedStringArray()
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func shoot(out_dir: String) -> void:
	call_deferred("_shoot", out_dir)


func _shoot(out_dir: String) -> void:
	reparent(get_tree().root)
	_live = world.live
	_field = world.field
	var at:= SPOT + Vector3(0.0, 0.0, 1.0)
	for leg in 2:
		_live.settle_enabled = leg == 1
		_rng.seed = 20260911
		player.global_position = at + Vector3(2.0, 0.2, 0.0)
		await _ticks(30)
		var made:= await _pour(120, at + Vector3(0.0, 0.0, -0.3), 0.3)
		made.append_array(await _pour(120, at + Vector3(0.0, 0.0, 0.35), 0.12))
		await _ticks(SETTLE_TICKS * 2)
		for view in [[1.1, "near"], [2.2, "wide"]]:
			var back: float = view [0]
			var stand:= at + Vector3(back, 0.0, 0.0)
			stand.y = 0.2
			player.global_position = stand
			await _ticks(5)
			var to:= at - player.eye_position()
			player.set_look(atan2(- to.x, - to.z),
				atan2(to.y, Vector2(to.x, to.z).length()))
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path:= "%s/settle_%s_%s.png" % [out_dir, "on" if leg == 1 else "off", view [1]]
			get_viewport().get_texture().get_image().save_png(path)
			print("wrote %s: %d settled, tufts %s" % [path, _live.settled_count(),
				_live.tuft_sizes()])
		await _clear(made)
	get_tree().quit()


func _run() -> void:
	reparent(get_tree().root)
	_live = world.live
	_field = world.field
	_rng.seed = 20260911


	_live.fold_stranded_enabled = not OS.get_cmdline_user_args().has("--nostrandfold")
	player.global_position = SPOT + Vector3(0.0, 0.2, 4.0)
	await _ticks(30)

	if OS.get_cmdline_user_args().has("--idleonly"):
		await _case_idle_heaps()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--dumponly"):
		await _case_dump_on_settled()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--timing"):
		await _case_timing()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--ontufts"):
		await _case_dump_on_riding_tufts()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--noroom"):
		await _case_no_room()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--intomachine"):
		await _case_into_machine()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--caponly"):
		await _case_floor_cap()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--pouronly"):
		await _case_container_pour()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--pourbelt"):
		await _case_pour_on_belt()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--standonly"):
		await _case_stand_load()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--twiceonly"):
		await _case_dump_twice()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--twicetool"):
		await _case_dump_twice_tool()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--junctiononly"):
		await _case_junction_load()
		_finish()
		return
	await _case_floor_cap()
	await _case_heap_cost()
	await _case_few_stay_loose()
	await _case_scatter_gathers()
	await _case_not_on_machines()
	await _case_pile_dug_out()
	await _case_pour_on_settled()
	await _case_dump_on_settled()
	await _case_belt_load()
	await _case_junction_load()
	await _case_stand_load()
	await _case_container_pour()
	await _case_no_room()
	_finish()


func _case_no_room() -> void:
	print("\n=== a forkful aimed at a run with no room ===")
	var was_mode: int = Cfg.tool_mode
	Cfg.tool_mode = Cfg.TOOL_SIMPLE
	Tech.grant_legacy()
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	var rig: Shovel = player.pitchfork
	rig.reset_aim()
	var at:= SPOT + Vector3(0.0, 0.75, -2.5)
	var belt: Conveyor = world.builds.add_conveyor(at + Vector3(0.0, 0.0, -5.0),
		at + Vector3(0.0, 0.0, 5.0))
	await _ticks(10)
	belt.set_drive_speed(0.0)
	player.global_position = Vector3(at.x + 1.3, 0.2, at.z)
	player.velocity = Vector3.ZERO
	var widest:= HayTuft.full_collider_size()
	var step:= maxf(widest.x, widest.z) + 0.01
	var s:= 0.3
	while s < belt.path_length() - 0.3:
		world.props.spawn("hay_tuft", Transform3D(Basis.IDENTITY,
			belt._point_at(s) + Vector3.UP * 0.12), { "strands": Cfg.TUFT_MAX })
		s += step
	await _ticks(60)
	var riding:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and BeltPath.is_rider(t):
			riding += 1
	print("  %d full tufts riding the run" % riding)
	var target:= belt._point_at(belt.path_length() * 0.5) + Vector3.UP * 0.1
	var to:= target - player.eye_position()
	player.set_look(atan2(- to.x, - to.z), atan2(to.y, Vector2(to.x, to.z).length()))


	await _ticks(10)
	var load:= _fill_pan(rig, mini(200, rig.capacity()))
	await _ticks(TOOL_FILL_TICKS)
	var held:= rig.carried_strands()
	print("  room under the crosshair %d, %d on the fork" % [rig.straw_room_ahead(), held])

	var sent:= rig.dump()
	await _ticks(2)
	var badge:= rig.body.get_node_or_null("FullBadge/Mark") as Label3D
	_check("nothing leaves the fork over full tufts (%d sent, %d still on)"
		% [sent, rig.carried_strands()], sent == 0 and rig.carried_strands() >= held - 3)
	_check("and it says NO ROOM", badge != null and badge.visible
		and badge.text == tr(FullBadge.NO_ROOM))

	var roomy: HayTuft = null
	var best:= INF
	for t in HayTuft.all:
		if is_instance_valid(t) and BeltPath.is_rider(t):
			var d:= t.global_position.distance_to(target)
			if d < best:
				best = d
				roomy = t
	if roomy != null:
		roomy.set_strands(Cfg.TUFT_MAX - 40)
	held = rig.carried_strands()
	var room:= rig.straw_room_ahead()
	sent = rig.dump()
	await _ticks(2)
	_check("with room for %d, that many leave (%d sent, %d of %d still on)"
		% [room, sent, rig.carried_strands(), held],
		held > 40 and room == 40 and sent == 40 and rig.carried_strands() >= held - 40 - 3)

	for t in HayTuft.all.duplicate():
		if is_instance_valid(t):
			world.props.remove(t)
	await _ticks(10)
	held = rig.carried_strands()
	sent = rig.dump()
	await _ticks(2)


	_check("on an empty run the whole load leaves (%d sent of %d)" % [sent, held],
		held > 0 and sent >= held)

	await _ticks(60)
	await _clear(load)
	world.builds.demolish(belt)
	Cfg.tool_mode = was_mode
	await _ticks(10)


const INTO_DUMPS:= 4


func _case_into_machine() -> void:
	print("\n=== forkfuls dumped where no run says NO ROOM ===")
	var was_mode: int = Cfg.tool_mode
	Cfg.tool_mode = Cfg.TOOL_SIMPLE
	Tech.grant_legacy()
	var was_rank:= Tech.rank_of("fork_size")
	Tech.grant("fork_size", 5)
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	var rig: Shovel = player.pitchfork
	rig.reset_aim()


	var scanner: HaystackScanner = world.builds.add_scanner(
		Vector3(13.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 10.0), 0.0)
	var press: HayCompressor = world.builds.add_compressor(Vector3(13.0, 0.0, 6.0), 0.0)
	await _ticks(30)
	scanner.banked.append(0)
	player.global_position = SPOT + Vector3(-2.0, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	await _ticks(30)
	var idle:= await _tick_ms(MEASURE_TICKS)
	print("  empty yard: %.2f ms a tick, %d live strands" % [idle, _live._active.size()])
	print("  %-8s %6s %6s %6s %8s %6s %9s" % ["target", "live", "awake", "near", "settled",
		"tufts", "ms/tick"])


	for leg: String in ["floor", "scanner", "press", "poured"]:
		var target:= SPOT + Vector3(0.0, 0.05, 0.0)
		var along:= Vector3.FORWARD
		var folded_was:= LiveStrandManager.folded_stranded
		var sent_total:= 0
		var sent_last:= 0
		if leg == "scanner" or leg == "poured":
			along = scanner.forward()
			target = scanner.port_in() + along * (HaystackScanner.INTAKE_LENGTH * 0.5)
		elif leg == "press":
			along = press.forward()
			target = press.port_in() + along * (HayCompressor.INTAKE_LENGTH * 0.5)
		var side:= along.cross(Vector3.UP).normalized()
		var stand:= target + side * 1.3
		stand.y = 0.2
		player.global_position = stand
		player.velocity = Vector3.ZERO
		var load: Array [RigidBody3D] = []
		for i in INTO_DUMPS:
			if leg == "press":
				press.stored = maxi(press.stored, press.buffer_capacity() * 4)
			if leg == "poured":
				load.append_array(await _pour(120, target - Vector3.UP * 0.5, 0.25))
				await _ticks(60)
				continue
			var to:= target + Vector3.UP * 0.1 - player.eye_position()
			player.set_look(atan2(- to.x, - to.z), atan2(to.y, Vector2(to.x, to.z).length()))
			await _ticks(10)


			load.append_array(_fill_pan(rig, maxi(0, rig.capacity() - rig.carried_strands())))
			await _ticks(TOOL_FILL_TICKS)
			var held:= rig.carried_strands()
			var room:= rig.straw_room_ahead()
			var sent:= rig.dump()
			sent_total += sent
			sent_last = sent
			print("    %s dump %d: %d on the fork, room %d, %d sent"
				% [leg, i + 1, held, room, sent])
			await _ticks(60)
		if leg != "floor":
			_explain_mouth(target, load)


		if rig.carried_strands() > 0:
			var away:= stand + side * 1.2 - player.eye_position()
			player.set_look(atan2(- away.x, - away.z),
				atan2(away.y, Vector2(away.x, away.z).length()))
			await _ticks(10)
			rig.dump()
			await _ticks(5)
		if leg == "press":
			press.stored = maxi(press.stored, press.buffer_capacity() * 4)
		await _ticks(180)
		var ms:= await _tick_ms(MEASURE_TICKS)
		var awake:= 0
		var near:= 0
		var settled:= 0
		for b in load:
			if not _mine(b):
				continue
			if LiveStrandManager.is_pinned(b):
				settled += 1
			elif not b.freeze and not b.sleeping:
				awake += 1
				if _flat_distance(b.global_position, target) < 1.5:
					near += 1
		var tufts:= 0
		for t in HayTuft.all:
			if is_instance_valid(t) and _flat_distance(t.global_position, target) < 2.5:
				tufts += 1
		print("  %-8s %6d %6d %6d %8d %6d %9.2f" % [leg, _live._active.size(), awake, near,
			settled, tufts, ms])
		print("    folded as stranded: %d" % (LiveStrandManager.folded_stranded - folded_was))


		if leg != "floor":
			var why:= { }
			var highest:= 0.0
			var space:= world.get_world_3d().direct_space_state
			for s in load:
				if not _mine(s) or s.freeze or s.sleeping or _flat_distance(s.global_position, target) >= 1.5:
					continue
				highest = maxf(highest, s.global_position.y - target.y)
				var reason:= ""
				if s.get_meta(LiveStrandManager.META_PROTECTED, false):
					reason = "protected"
				elif s.has_meta(LiveStrandManager.META_RIDER):
					reason = "rider"
				elif s.has_meta(LiveStrandManager.META_GLIDE):
					reason = "gliding"
				elif s.collision_layer != Cfg.L_STRAND:
					reason = "on layer %d" % s.collision_layer
				else:
					var down:= PhysicsRayQueryParameters3D.create(
						s.global_position + Vector3.UP * 0.05,
						s.global_position - Vector3.UP * LiveStrandManager.BUILT_PROBE)
					down.collision_mask = Cfg.L_BUILD | Cfg.L_WORLD | Cfg.L_PILE
					var under:= space.intersect_ray(down)
					if under.is_empty():
						reason = "nothing built within the probe"
					else:
						var col:= under ["collider"] as CollisionObject3D
						var taker:= LiveStrandManager.straw_taker_of(col)
						if not (col.collision_layer & Cfg.L_BUILD):
							reason = "floor or pile under it"
						elif taker == null:
							reason = "built, no taker: %s" % col.name
						elif int(taker.call("straw_room")) > 0:
							reason = "taker has room"
						elif not _live._stranded.has(s.get_instance_id()):
							reason = "stranded, not on the clock yet"
						else:
							var on:= _live._stranded_clock - float(_live._stranded [s.get_instance_id()])
							reason = "stranded, clock under 1.5 s" if on < LiveStrandManager.BUILT_FOLD else "stranded, clock OVER 1.5 s"
				why [reason] = int(why.get(reason, 0)) + 1
			var manager_says:= 0
			for s in load:
				if _mine(s) and not s.freeze and not s.sleeping and _flat_distance(s.global_position, target) < 1.5 and _live._is_stranded(s):
					manager_says += 1
			print("    the manager calls %d of them stranded; cursor %d of %d active, %d on the clock, %d checks so far, fold on %s"
				% [manager_says, _live._stranded_cursor, _live._active.size(),
				_live._stranded.size(), LiveStrandManager.stranded_checks,
				_live.fold_stranded_enabled])
			print("    awake at the mouth, highest %.2f m over it:" % highest)
			for r: String in why:
				print("      %4d  %s" % [int(why [r]), r])
		if leg == "scanner":
			_check("the fork stops letting go over the held scanner (last dump sent %d)"
				% sent_last, sent_last == 0)
		elif leg == "press":
			_check("the fork lets nothing go over the full press (%d sent)" % sent_total,
				sent_total == 0)
		if leg != "floor":
			_check("%s: no heap left awake at the mouth (%d)" % [leg, near], near <= 40)
			_diagnose(load)
		await _clear(load)
	scanner.banked.clear()
	world.builds.demolish(scanner)
	world.builds.demolish(press)
	Tech.grant("fork_size", was_rank)
	Cfg.tool_mode = was_mode
	await _ticks(10)


func _explain_mouth(target: Vector3, load: Array [RigidBody3D]) -> void:
	var space:= world.get_world_3d().direct_space_state
	var eye:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(eye, eye + player.look_direction() * Cfg.SCOOP_REACH)
	q.collision_mask = Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_WORLD | Cfg.L_PILE
	var hit:= space.intersect_ray(q)
	if hit.is_empty():
		print("    fork ray: nothing")
	else:
		var c:= hit ["collider"] as CollisionObject3D
		print("    fork ray: %s layer %d at %s, taker %s" % [c.get_path(), c.collision_layer,
			hit ["position"], LiveStrandManager.straw_taker_of(c)])
	var shown:= 0
	for b in load:
		if shown >= 6 or not _mine(b) or b.freeze or b.sleeping or _flat_distance(b.global_position, target) >= 1.5:
			continue
		shown += 1
		var d:= PhysicsRayQueryParameters3D.create(b.global_position + Vector3.UP * 0.05,
			b.global_position - Vector3.UP * LiveStrandManager.BUILT_PROBE)
		d.collision_mask = Cfg.L_BUILD | Cfg.L_WORLD | Cfg.L_PILE
		var under:= space.intersect_ray(d)
		var what:= "nothing"
		if not under.is_empty():
			var col:= under ["collider"] as CollisionObject3D
			var taker:= LiveStrandManager.straw_taker_of(col)
			what = "%s layer %d, taker %s room %s" % [col.get_path(), col.collision_layer,
				taker, taker.call("straw_room") if taker != null else "-"]
		var hold_left:= float(b.get_meta(LiveStrandManager.META_HOLD_UNTIL, 0.0)) - Time.get_ticks_msec() * 0.001
		print("    strand y %.2f layer %d protected %s hold %.2fs rider %s glide %s claim %s: %s"
			% [b.global_position.y, b.collision_layer,
			b.get_meta(LiveStrandManager.META_PROTECTED, false), hold_left,
			b.has_meta(LiveStrandManager.META_RIDER), b.has_meta(LiveStrandManager.META_GLIDE),
			b.get_meta(LiveStrandManager.META_CLAIM, "-"), what])


func _tick_ms(n: int) -> float:
	await get_tree().physics_frame
	var t0:= Time.get_ticks_usec()
	for i in n:
		await get_tree().physics_frame
	return float(Time.get_ticks_usec() - t0) / float(n) / 1000.0


func _state(what: String) -> void:
	var pinned:= 0
	var layers:= { }
	for b in _live._active:
		if LiveStrandManager.is_pinned(b):
			pinned += 1
		layers [b.collision_layer] = int(layers.get(b.collision_layer, 0)) + 1
	print("  [state %s] active %d pinned %d layers %s clumps %s tufts %s gliding %d pool %d"
		% [what, _live._active.size(), pinned, layers, _live.clump_sizes(),
			_live.tuft_sizes(), _live.gliding_count(), _live._pool.size()])


func _finish() -> void:
	print("")
	if _fails.is_empty():
		print("SETTLE: OK")
	else:
		for f in _fails:
			print("SETTLE FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_floor_cap() -> void:
	print("\n=== more tufts than the floor cap ===")
	const EACH:= 20
	var count:= Cfg.TUFT_FLOOR_CAP + 4
	var made: Array [HayTuft] = []
	for i in count:
		var at:= SPOT + Vector3(-1.5 + float(i % 4) * 0.9, 0.05, -1.5 + floorf(i / 4.0) * 0.9)
		made.append(world.props.spawn("hay_tuft", Transform3D(Basis.IDENTITY, at),
			{ "strands": EACH }) as HayTuft)


	for t in made:
		LiveStrandManager.release_hold(t)

	made [1].set_meta(PropManager.META_CLAIM, get_instance_id())
	var hay_was:= GameState.hay_total
	await _ticks(int(Cfg.PROP_SCAN_PERIOD * 4.0 * Engine.physics_ticks_per_second))
	var lying:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and not t.is_held() and not BeltPath.is_rider(t):
			lying += 1
	_check("the floor is down to the cap (%d lying, cap %d)" % [lying, Cfg.TUFT_FLOOR_CAP],
		lying == Cfg.TUFT_FLOOR_CAP)
	_check("the claimed one is spared", is_instance_valid(made [1]))
	_check("the oldest went first", not is_instance_valid(made [0])
		and not is_instance_valid(made [2]))
	var newest:= 0
	for i in range(count - (Cfg.TUFT_FLOOR_CAP - 1), count):
		if is_instance_valid(made [i]):
			newest += 1
	_check("the newest stayed (%d of %d)" % [newest, Cfg.TUFT_FLOOR_CAP - 1],
		newest == Cfg.TUFT_FLOOR_CAP - 1)
	var back:= GameState.hay_total - hay_was
	_check("their hay is back on the books (%.0f for %d folded)" % [back, count - lying],
		is_equal_approx(back, float(EACH * (count - lying))))
	if is_instance_valid(made [1]):
		made [1].remove_meta(PropManager.META_CLAIM)
	var none: Array [RigidBody3D] = []
	await _clear(none)


func _case_heap_cost() -> void:
	print("\n=== a poured heap, settling off and on ===")
	print("               loose  awake  settled  tufts  in tufts  max   ms/tick")
	var none: Array [RigidBody3D] = []
	var empty:= await _measure("no heap", none)
	_live.settle_enabled = false
	var off_heap:= await _pour(HEAP, SPOT, 0.18)
	await _ticks(SETTLE_TICKS)
	var off:= await _measure("off", off_heap)
	await _clear(off_heap)

	_live.settle_enabled = true
	var on_heap:= await _pour(HEAP, SPOT, 0.18)
	await _ticks(SETTLE_TICKS)
	var on:= await _measure("on", on_heap)
	_diagnose(on_heap)

	var hay:= int(on ["loose"]) + int(on ["in_tufts"])
	_check("the heap's hay is all still there (%d of %d, %d in tufts)"
		% [hay, HEAP, int(on ["in_tufts"])], hay >= HEAP - 3)
	_check("most of it snapped into tufts (%d of %d)" % [int(on ["in_tufts"]), HEAP],
		int(on ["in_tufts"]) >= HEAP * 0.7)
	_check("into big ones (biggest %d)" % int(on ["max"]), int(on ["max"]) >= Cfg.TUFT_MAX / 2)
	_check("and none past the cap (%d)" % Cfg.TUFT_MAX, int(on ["max"]) <= Cfg.TUFT_MAX)
	_check("little is left awake (%d)" % int(on ["awake"]), int(on ["awake"]) <= 20)
	var add_off:= float(off ["ms"]) - float(empty ["ms"])
	var add_on:= float(on ["ms"]) - float(empty ["ms"])
	print("  the heap adds %.2f ms a tick loose and %.2f ms as tufts" % [add_off, add_on])
	_check("it costs less than the loose heap (%.2f ms against %.2f)"
		% [float(on ["ms"]), float(off ["ms"])], float(on ["ms"]) < float(off ["ms"]))


	var resting:= 0
	var off_floor:= 0
	for t in HayTuft.all:
		if not is_instance_valid(t):
			continue
		if t.global_position.y > SPOT.y + 0.25 or t.linear_velocity.length() > 0.5:
			off_floor += 1
		else:
			resting += 1
	_check("every tuft lies on the slab or on a tuft (%d of %d not)"
		% [off_floor, resting + off_floor], off_floor == 0 and resting > 0)

	var wrong:= 0
	var floating:= 0
	for b in on_heap:
		if not _mine(b) or not LiveStrandManager.is_pinned(b) or b.has_meta(LiveStrandManager.META_GLIDE):
			continue
		if b.collision_layer != Cfg.L_SETTLED or not b.freeze or b.freeze_mode != RigidBody3D.FREEZE_MODE_STATIC:
			wrong += 1
		if _floating(b):
			floating += 1
	_check("what stays loose and settled is frozen static on L_SETTLED (%d wrong)" % wrong,
		wrong == 0)
	_check("nothing settled in mid air (%d floating)" % floating, floating == 0)
	await _clear(on_heap)


func _case_few_stay_loose() -> void:
	print("\n=== a few strands alone ===")
	var at:= SPOT + Vector3(0.0, 0.0, 1.5)
	var few:= await _pour(Cfg.TUFT_MERGE_AT - 4, at, 0.04)
	await _ticks(SETTLE_TICKS)
	var settled: Array [RigidBody3D] = []
	for b in few:
		if _mine(b) and LiveStrandManager.is_pinned(b):
			settled.append(b)
	var tufts_near:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and _flat_distance(t.global_position, at) < 0.5:
			tufts_near += 1
	_check("they settle (%d of %d)" % [settled.size(), few.size()], settled.size() >= few.size() - 1)
	_check("and make no tuft (%d)" % tufts_near, tufts_near == 0)

	var space:= world.get_world_3d().direct_space_state
	var hit:= { }
	var hit_body: RigidBody3D = null
	for b in settled:
		var q:= PhysicsRayQueryParameters3D.create(
			b.global_position + Vector3(0.0, 0.5, 0.0),
			b.global_position - Vector3(0.0, 0.05, 0.0))
		q.collision_mask = Cfg.L_PILE | Cfg.L_STRAND | Cfg.L_SETTLED
		hit = space.intersect_ray(q)
		hit_body = hit.get("collider") as RigidBody3D
		if hit_body != null and hit_body.collision_layer == Cfg.L_SETTLED:
			break
		hit_body = null
	_check("the hand's ray stops on settled straw", hit_body != null)
	if hit_body != null:
		_check("...and the hand calls it hay", player.hand.is_hay_hit(hit))
		LiveStrandManager.unpin(hit_body)
		_check("unpin puts it back on L_STRAND, loose and out of its clump",
			hit_body.collision_layer == Cfg.L_STRAND
			and hit_body.collision_mask == LiveStrandManager.STRAND_MASK
			and not hit_body.freeze
			and not hit_body.has_meta(LiveStrandManager.META_TUFT))
	await _ticks(SETTLE_TICKS)

	var woke:= _live.wake_in(at, 0.12)
	var shape:= SphereShape3D.new()
	shape.radius = 0.3
	var sq:= PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis.IDENTITY, at)
	sq.collision_mask = Cfg.L_STRAND
	var found:= space.intersect_shape(sq, 64).size()
	_check("a pickup's wake is seen by its own query on the same tick (woke %d, found %d)"
		% [woke, found], woke > 0 and found > 0)
	var wrong:= 0
	for b in few:
		if _mine(b) and (b.freeze or b.collision_layer != Cfg.L_STRAND):
			wrong += 1
	_check("and what it woke is ordinary loose straw (%d not)" % wrong, wrong == 0)
	await _ticks(SETTLE_TICKS)

	var target: RigidBody3D = null
	for b in few:
		if _mine(b) and LiveStrandManager.is_pinned(b):
			target = b
			break
	_check("it settles again", target != null)
	if target != null:
		_live.consume(target)
		_check("consumed, it is no longer settled",
			not LiveStrandManager.is_pinned(target) and target.collision_layer == Cfg.L_STRAND)
		var again: RigidBody3D = _live.spawn(at + Vector3(0.0, 1.0, 0.0), Basis(),
			Vector3.ZERO, Color.WHITE)
		_check("a fresh strand out of the pool is loose on L_STRAND",
			again != null and again.collision_layer == Cfg.L_STRAND
			and again.collision_mask == LiveStrandManager.STRAND_MASK
			and not again.freeze and not LiveStrandManager.is_pinned(again)
			and not again.has_meta(LiveStrandManager.META_TUFT)
			and not again.has_meta(LiveStrandManager.META_GLIDE))
		if again != null:
			_live.consume(again)
	await _clear(few)


func _case_scatter_gathers() -> void:
	print("\n=== scattered straw ===")
	var at:= SPOT + Vector3(0.0, 0.0, 2.5)
	player.global_position = at + Vector3(0.0, 0.2, 3.0)
	var made:= await _pour(150, at, 0.3)
	await _ticks(SETTLE_TICKS * 2)
	var sizes:= _live.tuft_sizes()
	sizes.sort()
	var total:= 0
	for n in sizes:
		total += n
	var loose:= 0
	for b in made:
		if _mine(b):
			loose += 1
	print("  tufts %s, %d strands in them, %d loose, clumps %s"
		% [sizes, total, loose, _live.clump_sizes()])
	_check("most of it is in tufts (%d of %d)" % [total, made.size()], total >= made.size() * 0.6)
	_check("the hay is all there (%d)" % (total + loose), total + loose >= made.size() - 2)


	var biggest: HayTuft = null
	for t in HayTuft.all:
		if is_instance_valid(t) and (biggest == null or t.strands > biggest.strands):
			biggest = t
	if biggest == null:
		_check("there is a tuft to drop straw on", false)
	else:
		var was:= biggest.strands
		var more:= await _pour(mini(20, Cfg.TUFT_MAX - was), biggest.global_position, 0.05)
		await _ticks(SETTLE_TICKS)
		print("  dropped %d on a tuft of %d: it holds %d" % [more.size(), was, biggest.strands])
		_check("straw dropped on a tuft goes into it (%d to %d)" % [was, biggest.strands],
			biggest.strands >= was + more.size() * 0.7)
		made.append_array(more)
	await _clear(made)


func _case_not_on_machines() -> void:
	print("\n=== on a machine ===")
	var box:= StaticBody3D.new()
	box.collision_layer = Cfg.L_BUILD
	box.collision_mask = 0
	var cs:= CollisionShape3D.new()
	var shape:= BoxShape3D.new()
	shape.size = Vector3(1.2, 0.5, 1.2)
	cs.shape = shape
	box.add_child(cs)
	world.add_child(box)
	var top:= SPOT + Vector3(3.0, 0.0, 0.0)
	box.global_position = top + Vector3(0.0, 0.25, 0.0)
	await _ticks(5)
	var made:= await _pour(30, top + Vector3(0.0, 0.5, 0.0), 0.15)
	await _ticks(SETTLE_TICKS)
	var on_top:= 0
	var frozen:= 0
	for b in made:
		if _mine(b) and b.global_position.y > 0.4:
			on_top += 1
			if LiveStrandManager.is_pinned(b):
				frozen += 1
	var tufts_up:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and t.global_position.y > 0.4:
			tufts_up += 1
	_check("hay came to rest on the machine (%d strands)" % on_top, on_top > 0)
	_check("and none of it settled (%d)" % frozen, frozen == 0)
	_check("nor made a tuft up there (%d)" % tufts_up, tufts_up == 0)
	await _clear(made)
	box.queue_free()
	await _ticks(5)


func _case_pile_dug_out() -> void:
	print("\n=== dug out from under ===")
	var at:= Vector3(2.0, 0.0, 0.0)
	at.y = _field.height_at(at.x, at.z)
	if at.y < 0.5:
		_check("there is pile at %.1v to pour onto" % at, false)
		return
	player.global_position = at + Vector3(0.0, 0.5, 3.0)
	await _ticks(10)
	var made:= await _pour(40, at + Vector3(0.0, 0.3, 0.0), 0.1)
	await _ticks(SETTLE_TICKS)
	var watched: Array [Node3D] = []
	var was_at: Array [float] = []
	for b in made:
		if _mine(b) and LiveStrandManager.is_pinned(b):
			watched.append(b)
			was_at.append(b.global_position.y)
	for t in HayTuft.all:
		if is_instance_valid(t) and _flat_distance(t.global_position, at) < 0.6:
			watched.append(t)
			was_at.append(t.global_position.y)
	_check("hay settled or tufted on the pile (%d)" % watched.size(), not watched.is_empty())
	for i in 40:
		_field.carve_sphere(at, 0.9, 1.0)
		await get_tree().physics_frame
	await _ticks(180)
	var floating:= 0
	var followed:= 0
	for i in watched.size():
		var n:= watched [i]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if n.global_position.y < was_at [i] - 0.2:
			followed += 1
		var b:= n as RigidBody3D
		if b != null and b is not HayTuft and LiveStrandManager.is_pinned(b) and _floating(b):
			floating += 1
	print("  carved %.2f m out from under it: %d followed it down, %d floating"
		% [at.y - _field.height_at(at.x, at.z), followed, floating])
	_check("the hay went down with the pile (%d)" % followed, followed > 0)
	_check("nothing is left frozen over the hole (%d)" % floating, floating == 0)
	await _clear(made)


func _case_idle_heaps() -> void:
	print("\n=== heaps left alone ===")
	var thrown:= 0
	var bursts:= 0
	var fastest:= 0.0
	for rep in IDLE_HEAPS:
		var heap:= await _pour(HEAP, SPOT, 0.18)
		var up:= { }
		for tick in IDLE_TICKS:
			await get_tree().physics_frame
			for b in heap:
				if _mine(b) and not b.freeze and b.linear_velocity.y > IDLE_THROWN:
					up [b.get_instance_id()] = true
					fastest = maxf(fastest, b.linear_velocity.length())
			for t in HayTuft.all:
				if is_instance_valid(t) and t.linear_velocity.y > IDLE_THROWN:
					up [t.get_instance_id()] = true
					fastest = maxf(fastest, t.linear_velocity.length())
		if not up.is_empty():
			print("  heap %d threw %d" % [rep, up.size()])
			bursts += 1
			thrown += up.size()
		await _clear(heap)
	print("  %d heaps: %d threw straw, %d strands in all, fastest %.1f m/s"
		% [IDLE_HEAPS, bursts, thrown, fastest])
	_check("a heap left alone throws nothing (%d strands over %d heaps)" % [thrown, IDLE_HEAPS],
		thrown <= 3)


const IDLE_HEAPS:= 24
const IDLE_TICKS:= 600

const IDLE_THROWN:= 2.0


func _case_pour_on_settled() -> void:
	print("\n=== poured onto settled straw ===")
	var at:= SPOT + Vector3(0.0, 0.0, -2.5)
	player.global_position = at + Vector3(0.0, 0.2, 3.0)
	await _ticks(10)
	_state("before the pour")
	var first:= await _pour(HEAP, at, 0.18)
	await _ticks(SETTLE_TICKS)
	print("  first heap: tufts %s, clumps %s" % [_live.tuft_sizes(), _live.clump_sizes()])


	var gone:= { }
	for b in first:
		if _mine(b):
			b.tree_exited.connect(func() -> void: gone [b.get_instance_id()] = true,
				CONNECT_ONE_SHOT)
		else:
			gone [b.get_instance_id()] = true
	var tufts: Array [RigidBody3D] = []
	for t in HayTuft.all:
		if is_instance_valid(t):
			tufts.append(t)

	var stats:= { "speed": 0.0, "rise": 0.0, "fast": { }, "high": { } }
	var second:= await _pour(POUR_ON, at, 0.18)
	for i in SETTLE_TICKS:
		await get_tree().physics_frame
		_track(first, stats, gone)
		_track(tufts, stats)
	print("  pouring on it: fastest %.1f m/s, highest %.2f m; %d went over 2 m/s, %d over 0.3 m; tufts now %s"
		% [stats ["speed"], stats ["rise"], (stats ["fast"] as Dictionary).size(),
			(stats ["high"] as Dictionary).size(), _live.tuft_sizes()])
	_check("the settled heap is not thrown by hay poured on it (%d over 2 m/s)"
		% (stats ["fast"] as Dictionary).size(), (stats ["fast"] as Dictionary).size() <= 3)
	_check("nor lifted off the floor (%d over 0.3 m)" % (stats ["high"] as Dictionary).size(),
		(stats ["high"] as Dictionary).size() <= 3)

	var both: Array [RigidBody3D] = first.duplicate()
	both.append_array(second)


	var lay:= { }
	for b in both:
		if _mine(b):
			lay [b.get_instance_id()] = b.global_position.y
	stats = { "speed": 0.0, "rise": 0.0, "fast": { }, "high": { }, "from": lay }
	_state("before the wake")
	var woke:= _live.wake_in(at, 0.3)
	for i in 120:
		await get_tree().physics_frame
		_track(both, stats)
	print("  woke %d: fastest %.1f m/s, highest %.2f m; %d went over 2 m/s, %d over 0.3 m"
		% [woke, stats ["speed"], stats ["rise"], (stats ["fast"] as Dictionary).size(),
			(stats ["high"] as Dictionary).size()])
	_check("woken straw falls in, it does not burst (%d over 2 m/s)"
		% (stats ["fast"] as Dictionary).size(), (stats ["fast"] as Dictionary).size() <= woke / 50)
	_check("nor jumps (%d over 0.3 m)" % (stats ["high"] as Dictionary).size(),
		(stats ["high"] as Dictionary).size() <= woke / 50)
	await _clear(both)


func _case_dump_on_settled() -> void:
	print("\n=== a bladeful dumped ===")
	print("  %-26s %8s %9s %8s" % ["", "thrown", "heap>2m/s", "fastest"])
	var at:= SPOT + Vector3(0.0, 0.0, -2.5)
	player.global_position = at + Vector3(3.0, 0.2, 3.0)
	await _ticks(10)
	var totals:= { }
	var surfaces:= ["bare slab", "heap coming to rest", "settled heap"]
	for surface in surfaces:
		for how in ["none", "old", "new"]:
			if how == "none" and surface == "bare slab":
				continue
			var sum:= { "up": 0, "heap_fast": 0, "speed": 0.0 }
			for rep in DUMP_REPS:
				var heap: Array [RigidBody3D] = []
				if surface != "bare slab":
					heap = await _pour(HEAP, at, 0.18)
					await _ticks(30 if surface == "heap coming to rest" else SETTLE_TICKS)
				var r:= await _dump_at(at, heap, how)
				sum ["up"] = int(sum ["up"]) + int(r ["up"])
				sum ["heap_fast"] = int(sum ["heap_fast"]) + int(r ["heap_fast"])
				sum ["speed"] = maxf(float(sum ["speed"]), float(r ["speed"]))
				await _clear(heap)
			totals ["%s %s" % [surface, how]] = sum
			print("  %-26s %8d %9d %8.1f" % ["%s, %s" % [surface, how], sum ["up"],
				sum ["heap_fast"], sum ["speed"]])
	_check("the harness still throws a heap the old way (%d strands)"
		% int(totals ["heap coming to rest old"] ["up"]),
		int(totals ["heap coming to rest old"] ["up"]) > DUMP_REPS * 50)
	for surface in surfaces:
		var old: Dictionary = totals ["%s old" % surface]
		var now: Dictionary = totals ["%s new" % surface]
		_check("a dump onto the %s throws no straw up (%d strands over %d dumps, was %d)"
			% [surface, now ["up"], DUMP_REPS, old ["up"]], int(now ["up"]) <= DUMP_REPS * DUMP_NOISE)
		_check("nor knocks the straw under it about (%d over 2 m/s, was %d)"
			% [now ["heap_fast"], old ["heap_fast"]], int(now ["heap_fast"]) <= DUMP_REPS * DUMP_NOISE)


const DUMP_REPS:= 3


const DUMP_NOISE:= 15


const DUMP_RISE_TICKS:= 12

const DUMP_THROWN:= 1.0


func _dump_at(at: Vector3, heap_poured: Array [RigidBody3D], how: String) -> Dictionary:


	var heap: Array [RigidBody3D] = []
	for b in heap_poured:
		if _mine(b):
			heap.append(b)
	var load: Array [RigidBody3D] = []
	var start:= at + Vector3(0.0, 0.8, -0.6)
	for layer in (0 if how == "none" else 3):
		for cell in 49:
			var stagger:= 0.5 if layer % 2 == 1 else 0.0
			var local:= Vector3((float(cell % 7) + 0.5 + stagger - 3.5) * Shovel.LOAD_SLOT_PITCH,
				float(layer) * Shovel.LOAD_LAYER,
				(float(cell / 7) + 0.5 - 3.5) * Shovel.LOAD_SLOT_PITCH)
			var b: RigidBody3D = _live.spawn(start + local, StrandFactory.random_strand_basis(_rng),
				Vector3.ZERO, StrandFactory.random_tint(_rng))
			if b == null:
				continue
			b.collision_mask &= ~ Shovel.BLIND_MASK
			_live.set_protected(b, true)
			load.append(b)


	var push:= (Vector3(0.0, -0.6, 0.8).normalized() + Vector3.UP * Shovel.DUMP_LIFT).normalized() * Shovel.DUMP_SPEED
	for b in load:
		Shovel.mark_let_go(b)
		b.linear_velocity = push + Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0),
			_rng.randfn(0.0, 1.0)) * push.length() * Shovel.DUMP_SPREAD
		b.angular_velocity = Vector3(_rng.randfn(0.0, 2.4), _rng.randfn(0.0, 2.4),
			_rng.randfn(0.0, 2.4))
		b.sleeping = false
	var tufts: Array [RigidBody3D] = []
	for t in HayTuft.all:
		if is_instance_valid(t):
			tufts.append(t)
	var grace:= int(Shovel.LET_GO_TIME * 60.0)
	var up:= { }
	var heap_fast:= { }
	var speed:= 0.0
	for tick in 120:
		await get_tree().physics_frame
		if tick < grace and how == "new":
			for b in load:
				_live.see_straw_again(b)
		elif tick == grace:
			for b in load:
				if _mine(b):
					b.collision_mask |= Shovel.BLIND_MASK
					_live.set_protected(b, false)
		for k in 3:
			var list: Array [RigidBody3D] = load if k == 0 else (heap if k == 1 else tufts)
			for b in list:
				if not is_instance_valid(b) or not b.is_inside_tree() or b.freeze:
					continue
				if k < 2 and not _mine(b):
					continue
				var v:= b.linear_velocity
				if tick >= DUMP_RISE_TICKS:
					speed = maxf(speed, v.length())
					if v.y > DUMP_THROWN:
						up [b.get_instance_id()] = true
				if k > 0 and v.length() > 2.0:
					heap_fast [b.get_instance_id()] = true
	await _clear(load)
	return { "up": up.size(), "heap_fast": heap_fast.size(), "speed": speed }


func _case_timing() -> void:
	print("\n=== a dumped load, tick by tick ===")
	for where in ["slab", "belt"]:
		var at:= SPOT + Vector3(0.0, 0.0, -2.5)
		var belt: Conveyor = null
		if where == "belt":
			at.y = 0.75
			belt = world.builds.add_conveyor(at + Vector3(0.0, 0.0, -5.0),
				at + Vector3(0.0, 0.0, 5.0))
		player.global_position = Vector3(at.x + 3.0, 0.2, at.z + 3.0)
		await _ticks(40)
		var load:= _deal_bladeful(at + Vector3(0.0, 0.8, -0.6), ceili(TIMING_STRANDS / 49.0),
			Vector3(0.0, 0.0, 1.0), TIMING_STRANDS)
		print("  %s, %d strands" % [where, load.size()])
		print("    tick  loose  awake  settled  gliding  riders  tufts  in tufts    ms")
		var t0:= Time.get_ticks_usec()
		var grace:= int(Shovel.LET_GO_TIME * 60.0)
		for tick in range(1, TIMING_TICKS + 1):
			await get_tree().physics_frame
			var tick_us:= Time.get_ticks_usec() - t0
			t0 = Time.get_ticks_usec()
			for b in load:
				if tick < grace:
					_live.see_straw_again(b)
				elif tick == grace and _mine(b):
					b.collision_mask |= Shovel.BLIND_MASK
					_live.set_protected(b, false)
			if tick > TIMING_DETAIL and tick % TIMING_EVERY != 0:
				continue


			var ms:= float(tick_us) / 1000.0
			var loose:= 0
			var awake:= 0
			var settled:= 0
			var gliding:= 0
			var riders:= 0
			for b in load:
				if not _mine(b):
					continue
				loose += 1
				if b.has_meta(LiveStrandManager.META_GLIDE):
					gliding += 1
				elif LiveStrandManager.is_pinned(b):
					settled += 1
				elif b.has_meta(LiveStrandManager.META_RIDER):
					riders += 1
				elif not b.sleeping and not b.freeze:
					awake += 1
			var sizes:= _live.tuft_sizes()
			var in_tufts:= 0
			for n in sizes:
				in_tufts += n
			print("    %4d %6d %6d %8d %8d %7d %6d %9d %5.2f" % [tick, loose, awake,
				settled, gliding, riders, sizes.size(), in_tufts, ms])
		_diagnose(load)
		var spots:= { }
		for b in load:
			if _mine(b) and not LiveStrandManager.is_pinned(b) and not BeltPath.is_rider(b):
				var p:= b.global_position - at
				var key:= "%s, %s" % ["on the deck" if p.y > -0.1 else "below it",
					"inside the rails" if absf(p.x) < Cfg.BELT_WIDTH * 0.5 else "off the side"]
				spots [key] = int(spots.get(key, 0)) + 1
		for key: String in spots:
			print("  where: %4d  %s" % [int(spots [key]), key])
		await _clear(load)
		if belt != null:
			world.builds.demolish(belt)
			await _ticks(10)


func _case_dump_on_riding_tufts() -> void:
	print("\n=== a forkful dumped on tufts riding a belt ===")
	var folded_at_start:= BeltPath.folded_straw
	var at:= SPOT + Vector3(0.0, 0.75, -2.5)
	var belt: Conveyor = world.builds.add_conveyor(at + Vector3(0.0, 0.0, -6.0),
		at + Vector3(0.0, 0.0, 6.0))
	player.global_position = Vector3(at.x + 3.0, 0.2, at.z + 3.0)
	await _ticks(40)
	var grace:= int(Shovel.LET_GO_TIME * 60.0)
	var first:= _deal_bladeful(at + Vector3(0.0, 0.8, -5.0), ceili(TIMING_STRANDS / 49.0),
		Vector3(0.0, 0.0, 1.0), TIMING_STRANDS)
	for tick in range(1, 91):
		await get_tree().physics_frame
		_give_sight_back(first, tick, grace)
	var centre:= Vector3.ZERO
	var riding:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and BeltPath.is_rider(t):
			centre += t.global_position
			riding += 1
	_check("the first forkful rides as tufts (%d riding)" % riding, riding > 0)
	if riding == 0:
		await _clear(first)
		world.builds.demolish(belt)
		return
	centre /= float(riding)


	var second:= _deal_bladeful(Vector3(centre.x, at.y + 0.8, centre.z - 0.6 + 0.3),
		ceili(TIMING_STRANDS / 49.0), Vector3(0.0, 0.0, 1.0), TIMING_STRANDS)
	var both: Array [RigidBody3D] = first.duplicate()
	both.append_array(second)
	var dealt:= both.size()
	print("    tick  loose  awake  riders  gliding  on top  tufts  in tufts    ms")
	var t0:= Time.get_ticks_usec()
	var total_ms:= 0.0
	var worst:= 0.0
	var on_top:= 0
	for tick in range(1, TIMING_TICKS + 1):
		await get_tree().physics_frame
		var ms:= float(Time.get_ticks_usec() - t0) / 1000.0
		total_ms += ms
		worst = maxf(worst, ms)
		_give_sight_back(second, tick, grace)


		BeltPath.debug_props = tick >= TIMING_TICKS - 5
		if tick > TIMING_DETAIL and tick % TIMING_EVERY != 0 and tick != TIMING_TICKS:
			t0 = Time.get_ticks_usec()
			continue
		var loose:= 0
		var awake:= 0
		var riders:= 0
		var gliding:= 0
		on_top = 0


		var active:= { }
		for b in _live._active:
			active [b] = true
		for b in _unique(both):
			if not active.has(b):
				continue
			loose += 1
			if b.has_meta(LiveStrandManager.META_GLIDE):
				gliding += 1
			elif b.has_meta(LiveStrandManager.META_RIDER):
				riders += 1
			elif not b.freeze:
				if not b.sleeping:
					awake += 1
				var near: Dictionary = belt._nearest(b.global_position)
				if absf(float(near ["side"])) < Cfg.BELT_WIDTH * 0.5 and float(near ["lift"]) > Cfg.BELT_RIDE_CATCH_H and float(near ["lift"]) < Cfg.BELT_DRIVE_H:
					on_top += 1
		var in_tufts:= 0
		for n in _live.tuft_sizes():
			in_tufts += n
		print("    %4d %6d %6d %7d %8d %7d %6d %9d %5.2f" % [tick, loose, awake, riders,
			gliding, on_top, HayTuft.all.size(), in_tufts, ms])
		t0 = Time.get_ticks_usec()
	var left:= 0
	for b in _live._active:
		if both.has(b):
			left += 1
	var in_tufts:= 0
	for n in _live.tuft_sizes():
		in_tufts += n
	print("  mean %.2f ms a tick, worst %.2f ms" % [total_ms / float(TIMING_TICKS), worst])

	var where:= { }
	for b in _live._active:
		if not both.has(b) or b.freeze or b.has_meta(LiveStrandManager.META_RIDER):
			continue
		var near: Dictionary = belt._nearest(b.global_position)
		var key:= "off the belt"
		if absf(float(near ["side"])) < Cfg.BELT_WIDTH * 0.5 and float(near ["lift"]) > -0.1:
			key = "over the deck, lift %.2f" % snappedf(float(near ["lift"]), 0.05)
			for t in belt.riders():
				if t is not HayTuft:
					continue
				var tn: Dictionary = belt._nearest(t.global_position)
				if absf(float(tn ["s"]) - float(near ["s"])) < 0.4 and absf(float(tn ["side"]) - float(near ["side"])) < 0.4:
					key += ", over a tuft of %d" % (t as HayTuft).strands
					break
		if _live.is_held_by_a_tool(b):
			key += ", held"
		var why:= str(BeltPath.debug_last_refusal.get(b.get_instance_id(), "no refusal"))
		key += " (%s)" % why.get_slice(" ", 0)
		where [key] = int(where.get(key, 0)) + 1
	BeltPath.debug_props = false
	BeltPath.debug_last_refusal.clear()
	for key: String in where:
		print("  where: %4d  %s" % [int(where [key]), key])
	_check("no straw left lying loose on the riding tufts (%d)" % on_top, on_top <= 5)
	var folded:= BeltPath.folded_straw - folded_at_start
	_check("and none of the hay is gone (%d strands, %d in tufts, %d folded, of %d)"
		% [left, in_tufts, folded, dealt], left + in_tufts + folded >= dealt - 5)


	print("  three more forkfuls on the same spot")
	print("    tick  over deck  riders  tufts  in tufts  folded    ms")
	var spot:= Vector3(at.x, at.y + 0.8, centre.z - 0.3)
	const EVERY:= 45
	const PILE_TICKS:= EVERY * 3 + 240
	var dropped: Array [RigidBody3D] = []
	var total2:= 0.0
	var worst2:= 0.0
	var over_deck:= 0
	var t1:= Time.get_ticks_usec()
	for tick in range(1, PILE_TICKS + 1):
		if tick <= EVERY * 3 and (tick - 1) % EVERY == 0:
			dropped = _deal_bladeful(spot, ceili(TIMING_STRANDS / 49.0),
				Vector3(0.0, 0.0, 1.0), TIMING_STRANDS)
			both.append_array(dropped)
			dealt += dropped.size()
		await get_tree().physics_frame
		var ms:= float(Time.get_ticks_usec() - t1) / 1000.0
		total2 += ms
		worst2 = maxf(worst2, ms)
		if tick <= EVERY * 3:
			_give_sight_back(dropped, ((tick - 1) % EVERY) + 1, grace)
		if tick % 15 != 0:
			t1 = Time.get_ticks_usec()
			continue
		var active:= { }
		for b in _live._active:
			active [b] = true
		over_deck = 0
		var riders:= 0
		for b in _unique(both):
			if not active.has(b) or b.freeze:
				if active.has(b) and b.has_meta(LiveStrandManager.META_RIDER):
					riders += 1
				continue
			var near: Dictionary = belt._nearest(b.global_position)
			if absf(float(near ["side"])) < Cfg.BELT_WIDTH * 0.5 and float(near ["lift"]) > - Cfg.BELT_DECK_THICK and float(near ["lift"]) < Cfg.BELT_DRIVE_H:
				over_deck += 1
		in_tufts = 0
		for n in _live.tuft_sizes():
			in_tufts += n
		print("    %4d %10d %7d %6d %9d %7d %5.2f" % [tick, over_deck, riders,
			HayTuft.all.size(), in_tufts, BeltPath.folded_straw - folded_at_start, ms])
		t1 = Time.get_ticks_usec()
	print("  mean %.2f ms a tick, worst %.2f ms" % [total2 / float(PILE_TICKS), worst2])
	left = 0
	for b in _live._active:
		if both.has(b):
			left += 1
	folded = BeltPath.folded_straw - folded_at_start
	_check("the overflow does not ride the run loose (%d over the deck)" % over_deck,
		over_deck <= 10)


	_check("and its hay is on the books (%d strands, %d in tufts, %d folded, of %d)"
		% [left, in_tufts, folded, dealt], left + in_tufts + folded >= dealt - 10)
	await _clear(both)
	world.builds.demolish(belt)
	await _ticks(10)


func _unique(load: Array [RigidBody3D]) -> Array [RigidBody3D]:
	var seen:= { }
	var out: Array [RigidBody3D] = []
	for b in load:
		if not seen.has(b):
			seen [b] = true
			out.append(b)
	return out


func _give_sight_back(load: Array [RigidBody3D], tick: int, grace: int) -> void:
	for b in load:
		if tick < grace:
			_live.see_straw_again(b)
		elif tick == grace and _mine(b):
			b.collision_mask |= Shovel.BLIND_MASK
			_live.set_protected(b, false)


func _case_belt_load() -> void:
	print("\n=== a load tipped on a running belt ===")
	var at:= SPOT + Vector3(0.0, 0.75, -2.5)
	var belt: Conveyor = world.builds.add_conveyor(at + Vector3(0.0, 0.0, -5.0),
		at + Vector3(0.0, 0.0, 5.0))
	player.global_position = Vector3(at.x + 3.0, 0.2, at.z + 3.0)
	await _ticks(40)
	var ms:= { }
	for gathering in [false, true]:
		BeltPath.straw_tufts_enabled = gathering
		var load:= _deal_bladeful(at + Vector3(0.0, 0.8, -4.0), TIMING_LAYERS)
		var grace:= int(Shovel.LET_GO_TIME * 60.0)
		for tick in range(1, BELT_LOAD_TICKS + 1):
			await get_tree().physics_frame
			for b in load:
				if tick < grace:
					_live.see_straw_again(b)
				elif tick == grace and _mine(b):
					b.collision_mask |= Shovel.BLIND_MASK
					_live.set_protected(b, false)
		var strands:= 0
		for b in load:
			if _mine(b):
				strands += 1
		var in_tufts:= 0
		for n in _live.tuft_sizes():
			in_tufts += n
		var t0:= Time.get_ticks_usec()
		for i in MEASURE_TICKS:
			await get_tree().physics_frame
		ms [gathering] = float(Time.get_ticks_usec() - t0) / float(MEASURE_TICKS) / 1000.0
		print("  gathering %-5s  %d strands, %d in tufts, %.2f ms a tick"
			% [gathering, strands, in_tufts, float(ms [gathering])])
		if gathering:
			_check("most of the load is in tufts a second after the dump (%d of %d)"
				% [in_tufts, load.size()], in_tufts >= int(load.size() * 0.85))
			_check("and none of its hay is gone (%d of %d)" % [strands + in_tufts, load.size()],
				strands + in_tufts >= load.size() - 3)
		await _clear(load)
	_check("it costs less as tufts (%.2f ms against %.2f)" % [float(ms [true]), float(ms [false])],
		float(ms [true]) < float(ms [false]))

	var trickle: Array [RigidBody3D] = []
	for i in 30:
		var b: RigidBody3D = _live.spawn(at + Vector3(0.0, 0.05, -4.5 + float(i) * Cfg.BELT_RIDE_SPACING),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, StrandFactory.random_tint(_rng))
		if b != null:
			trickle.append(b)
	await _ticks(90)
	var riding:= 0
	for b in trickle:
		if _mine(b) and BeltPath.is_rider(b):
			riding += 1
	_check("a trickle a spacing apart rides as straw (%d of %d riding, %d tufts)"
		% [riding, trickle.size(), _live.tuft_sizes().size()],
		riding >= trickle.size() - 2 and _live.tuft_sizes().is_empty())
	await _clear(trickle)
	world.builds.demolish(belt)
	await _ticks(10)


const JUNCTION_LAYERS:= 4


func _case_junction_load() -> void:
	print("\n=== a load tipped on a junction ===")
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var at:= Vector3(SPOT.x, deck_y, SPOT.z - 9.0)
	player.global_position = Vector3(at.x + 4.0, 0.2, at.z + 4.0)
	await _ticks(20)
	for kind in ["splitter", "U splitter", "joiner", "U joiner"]:
		var machine: Node3D = null
		match kind:
			"splitter":
				machine = world.builds.add_splitter(at, 0.0)
			"U splitter":
				machine = world.builds.add_u_splitter(at, 0.0)
			"joiner":
				machine = world.builds.add_joiner(at, 0.0)
			_:
				machine = world.builds.add_u_joiner(at, 0.0)
		await _ticks(30)
		var folded_was:= BeltPath.folded_straw
		var load:= _deal_bladeful(at + Vector3(0.0, 0.8, 0.0), JUNCTION_LAYERS)


		var grace:= int(Shovel.LET_GO_TIME * 60.0)
		for tick in range(1, BELT_LOAD_TICKS + 1):
			await get_tree().physics_frame
			for b in load:
				if tick < grace:
					_live.see_straw_again(b)
				elif tick == grace and _mine(b):
					b.collision_mask |= Shovel.BLIND_MASK
					_live.set_protected(b, false)
		var loose:= 0
		for b in load:
			if _mine(b):
				loose += 1
		var in_tufts:= 0
		for n in _live.tuft_sizes():
			in_tufts += n
		var riding:= 0
		var riding_tufts:= 0
		for t in HayTuft.all:
			if is_instance_valid(t) and BeltPath.is_rider(t):
				riding += t.strands
				riding_tufts += 1
		print("  %-11s %d loose, %d in tufts, %d of those riding in %d tufts"
			% [kind, loose, in_tufts, riding, riding_tufts])
		_check("the %s gathered what landed on it (%d strands riding in %d tufts)"
			% [kind, riding, riding_tufts], riding >= Cfg.TUFT_MERGE_AT)
		_check("and the %s lost none of the load (%d of %d)"
			% [kind, loose + in_tufts, load.size()],
			loose + in_tufts >= load.size() - 3)


		_check("and the %s folded none of it away (%d)"
			% [kind, BeltPath.folded_straw - folded_was], BeltPath.folded_straw == folded_was)
		await _clear(load)
		world.builds.demolish(machine)
		await _ticks(10)


func _case_stand_load() -> void:
	print("\n=== a load tipped on the selling stand's belt ===")
	var stand:= world.get("stand") as HaySellingStand
	if stand == null:
		_check("there is a selling stand", false)
		return
	var forward:= stand.intake_forward()
	var start:= stand.belt_entry_point() + forward * 0.3 + Vector3.UP * 0.8
	var side:= stand.global_basis.z.normalized()
	player.global_position = Vector3(start.x, stand.global_position.y + 0.2, start.z) + side * 2.5
	await _ticks(40)
	var ms:= { }
	var sold:= { }
	for gathering in [false, true]:
		BeltPath.straw_tufts_enabled = gathering
		var money_was:= GameState.money
		var load:= _deal_bladeful(start, TIMING_LAYERS, forward)
		var grace:= int(Shovel.LET_GO_TIME * 60.0)
		var in_tufts:= 0
		var t0:= 0
		var last:= GameState.money
		var quiet:= 0
		for tick in range(1, STAND_TICKS + 1):
			await get_tree().physics_frame
			for b in load:
				if tick < grace:
					_live.see_straw_again(b)
				elif tick == grace and _mine(b):
					b.collision_mask |= Shovel.BLIND_MASK
					_live.set_protected(b, false)
			if tick == BELT_LOAD_TICKS:
				for n in _live.tuft_sizes():
					in_tufts += n
				t0 = Time.get_ticks_usec()
			elif tick == BELT_LOAD_TICKS + STAND_TIMED_TICKS:
				ms [gathering] = float(Time.get_ticks_usec() - t0) / float(STAND_TIMED_TICKS) / 1000.0
			if tick <= BELT_LOAD_TICKS + STAND_TIMED_TICKS:
				continue
			if is_equal_approx(GameState.money, last):
				quiet += 1
			else:
				quiet = 0
				last = GameState.money
			if GameState.money > money_was and quiet >= STAND_QUIET_TICKS:
				break
		sold [gathering] = (GameState.money - money_was) / maxf(Tech.hay_price(), 0.0001)
		var riding:= 0
		for b in load:
			if _mine(b) and BeltPath.is_rider(b):
				riding += 1
		for t in HayTuft.all:
			if is_instance_valid(t) and BeltPath.is_rider(t):
				riding += 1
		print("  gathering %-5s  %d strands, %d in tufts after a second, %.2f ms a tick riding, %.0f sold, %d still riding"
			% [gathering, load.size(), in_tufts, float(ms.get(gathering, 0.0)),
				float(sold [gathering]), riding])
		if gathering:
			_check("most of the load is in tufts a second after the dump (%d of %d)"
				% [in_tufts, load.size()], in_tufts >= int(load.size() * 0.85))
			_check("and nothing is left on the belt once the till is quiet (%d)" % riding,
				riding == 0)


			_check("the till paid for nearly all of it (%.0f of %d)"
				% [float(sold [gathering]), load.size()],
				float(sold [gathering]) >= load.size() * 0.9)
		await _clear(load)
	BeltPath.straw_tufts_enabled = true
	_check("the till pays for as much as it did for loose straw (%.0f against %.0f)"
		% [float(sold [true]), float(sold [false])], float(sold [true]) >= float(sold [false]) - 3.0)
	_check("it costs less as tufts (%.2f ms against %.2f)" % [float(ms [true]), float(ms [false])],
		float(ms [true]) < float(ms [false]))


const STAND_TICKS:= 900

const STAND_TIMED_TICKS:= 60

const STAND_QUIET_TICKS:= 90


func _case_container_pour() -> void:
	print("\n=== poured out of a container ===")
	for id in ["bucket", "wheelbarrow"]:
		var at:= SPOT + Vector3(0.0, 0.0, -2.5)
		player.global_position = Vector3(at.x + 4.0, 0.2, at.z + 4.0)
		var box:= world.props.spawn(id, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.1, 0))) as HayContainer
		await _ticks(20)
		box.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		box.freeze = true
		box.warp(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(110.0)), at + Vector3(0, 0.9, 0)))
		box.stored = box.capacity()
		box._refresh_fill()
		var full:= box.stored
		print("  %s, %d strands" % [id, full])
		print("    tick  in it  loose  awake  settled  gliding  tufts  in tufts    ms  tuft v  top")
		var t0:= Time.get_ticks_usec()
		var tick:= 0
		var empty_at:= -1
		while tick < 1800:
			await get_tree().physics_frame
			tick += 1
			if empty_at < 0 and box.stored <= 0:
				empty_at = tick
			if empty_at >= 0 and tick - empty_at > POUR_TAIL_TICKS:
				break
			if tick % TIMING_EVERY != 0:
				continue
			var ms:= float(Time.get_ticks_usec() - t0) / float(TIMING_EVERY) / 1000.0
			t0 = Time.get_ticks_usec()
			var loose:= 0
			var awake:= 0
			var settled:= 0
			var gliding:= 0
			for b in _live._active:
				if b.has_meta(LiveStrandManager.META_GLIDE):
					gliding += 1
				elif LiveStrandManager.is_pinned(b):
					settled += 1
				else:
					loose += 1
					if not b.sleeping and not b.freeze:
						awake += 1
			var sizes:= _live.tuft_sizes()
			var in_tufts:= 0
			for n in sizes:
				in_tufts += n

			var tuft_v:= 0.0
			var top:= 0.0
			for t in HayTuft.all:
				if is_instance_valid(t):
					tuft_v = maxf(tuft_v, t.linear_velocity.length())
					top = maxf(top, t.global_position.y)
			print("    %4d %6d %6d %6d %8d %8d %6d %9d %5.2f %7.2f %4.2f" % [tick, box.stored,
				loose, awake, settled, gliding, sizes.size(), in_tufts, ms, tuft_v, top])
		var still: Array [RigidBody3D] = []
		for b in _live._active:
			if not LiveStrandManager.is_pinned(b) and not b.has_meta(LiveStrandManager.META_GLIDE):
				still.append(b)
		_diagnose(still)

		var on_what:= { }
		for b in still:
			var q:= PhysicsRayQueryParameters3D.create(b.global_position + Vector3(0.0, 0.02, 0.0),
				b.global_position - Vector3(0.0, 0.1, 0.0))
			q.collision_mask = Cfg.L_PROP
			q.exclude = [b.get_rid()]
			var hit:= world.get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				continue
			var c:= hit.get("collider") as Node
			var key:= "%s%s" % [c.get_class() if c.get_script() == null else
				String((c.get_script() as Script).get_global_name()),
				" (%d, frozen %s, %.2f m out)" % [(c as HayTuft).strands, (c as HayTuft).freeze,
				Vector2(c.global_position.x - at.x, c.global_position.z - at.z).length()]
				if c is HayTuft else ""]
			on_what [key] = int(on_what.get(key, 0)) + 1
		for key: String in on_what:
			print("  lying on: %4d  %s" % [int(on_what [key]), key])
		var held:= 0
		for b in still:
			if LiveStrandManager.is_on_hold(b):
				held += 1
		if held > 0:
			print("  loose: %4d  still on hold" % held)


		var laid: Array [String] = []
		for t in HayTuft.all:
			if is_instance_valid(t):
				var d:= t.global_position - at
				laid.append("%.2f/%.2f/%d" % [Vector2(d.x, d.z).length(), d.y, t.strands])
		print("  tufts (out/up/strands): %s" % ", ".join(laid))
		var in_tufts:= 0
		var top:= 0.0
		for t in HayTuft.all:
			if is_instance_valid(t):
				in_tufts += t.strands
				top = maxf(top, t.global_position.y - at.y)


		_check("a poured %s ends in tufts (%d of %d strands)" % [id, in_tufts, full],
			in_tufts >= int(full * 0.97))
		_check("with no straw left loose three seconds after (%d)" % still.size(),
			still.size() <= 10)


		var chunk:= clampi(roundi(box.pour_rate() * HayContainer.POUR_TUFT_SECONDS),
			Cfg.TUFT_MERGE_AT, Cfg.TUFT_MAX)
		_check("as tufts the size the pour makes, not handfuls (%d tufts)" % HayTuft.all.size(),
			HayTuft.all.size() <= int(ceil(float(full) / float(chunk))) + 1)


		_check("spread over the floor, not stacked in a column (top %.2f m)" % top,
			top < 0.5)
		world.props.remove(box)
		await _clear(_live._active.duplicate())


const POUR_TAIL_TICKS:= 180


func _case_pour_on_belt() -> void:
	print("\n=== poured out of a container onto a running belt ===")
	var ids:= ["bucket", "wheelbarrow"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			ids = [arg.substr(7)]
	var on_floor:= OS.get_cmdline_user_args().has("--floor")


	var stand:= world.get("stand") as HaySellingStand if OS.get_cmdline_user_args().has("--stand") else null
	for id: String in ids:
		var at:= SPOT + Vector3(0.0, 0.0 if on_floor else 0.75, -2.5)
		var pour_xf:= Transform3D(Basis(Vector3.RIGHT, deg_to_rad(110.0)), at + Vector3(0, 0.9, -2.0))
		var belt: Conveyor = null
		if stand != null:
			var forward:= stand.intake_forward()
			at = stand.belt_entry_point()
			pour_xf = Transform3D(Basis(Vector3.UP, atan2(forward.x, forward.z))
				* Basis(Vector3.RIGHT, deg_to_rad(110.0)), at + forward * 0.2 + Vector3.UP * 0.9)
		elif not on_floor:


			var rise:= 1.5 if OS.get_cmdline_user_args().has("--slope") else 0.0
			belt = world.builds.add_conveyor(at + Vector3(0.0, - rise * 0.5, -5.0),
				at + Vector3(0.0, rise * 0.5, 5.0))
		var money_was:= GameState.money
		player.global_position = Vector3(at.x + 4.0, 0.2, at.z + 4.0)
		var box:= world.props.spawn(id, Transform3D(Basis.IDENTITY, at + Vector3(2.0, 0.1, 0))) as HayContainer
		await _ticks(20)
		box.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		box.freeze = true
		box.warp(pour_xf)
		box.stored = box.capacity()
		box._refresh_fill()
		var full:= box.stored
		print("  %s, %d strands" % [id, full])
		print("    tick  in it  riders  floor  awake  gliding  tufts  riding  in tufts    ms")
		var t0:= Time.get_ticks_usec()
		var tick:= 0
		var empty_at:= -1
		var worst:= 0.0
		var over:= 0
		var total:= 0.0
		var flung:= { }
		var born:= { }
		if stand != null:
			print("  intake at %.2v, forward %.2v, container at %.2v" % [at, stand.intake_forward(),
				box.global_position])
		while tick < 1800:
			await get_tree().physics_frame
			var tick_ms:= float(Time.get_ticks_usec() - t0) / 1000.0
			t0 = Time.get_ticks_usec()
			tick += 1
			worst = maxf(worst, tick_ms)
			total += tick_ms
			if tick_ms > 16.7:
				over += 1
			if tick_ms > 8.0:
				var rode:= 0
				for t in HayTuft.all:
					if is_instance_valid(t) and BeltPath.is_rider(t):
						rode += 1
				print("    spike at tick %d: %.2f ms, %d tufts, %d riding, %d in it"
					% [tick, tick_ms, HayTuft.all.size(), rode, box.stored])


			for t in HayTuft.all:
				if not is_instance_valid(t) or flung.has(t.get_instance_id()):
					continue

				if not born.has(t.get_instance_id()):
					born [t.get_instance_id()] = tick
				if tick - int(born [t.get_instance_id()]) < 15:
					continue


				if t.linear_velocity.length() <= 4.0 and t.linear_velocity.y <= 1.5:
					continue
				flung [t.get_instance_id()] = true
				var fq:= PhysicsShapeQueryParameters3D.new()
				var fb:= BoxShape3D.new()
				fb.size = t.clearance_size() + Vector3.ONE * 0.04
				fq.shape = fb
				fq.transform = t.global_transform * Transform3D(Basis(), Vector3(0.0, t.height() * 0.5, 0.0))
				fq.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
				fq.exclude = [t.get_rid()]
				var touching: PackedStringArray = []
				for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(fq, 8):
					var c:= hit.get("collider") as Node
					if c != null:
						touching.append("%s/%s" % [c.get_parent().name if c.get_parent() else "", c.name])
				print("    flung at tick %d: tuft %d at %.2v from the intake, %.1f m/s (%.1f up), rider %s, touching %s"
					% [tick, t.strands, t.global_position - at, t.linear_velocity.length(), t.linear_velocity.y,
						BeltPath.is_rider(t), ", ".join(touching)])


			if stand != null and tick >= 20 and tick <= 140 and OS.get_cmdline_user_args().has("--mouthtrace"):
				for t in HayTuft.all:
					if not is_instance_valid(t) or not BeltPath.is_rider(t) or t.global_position.distance_to(at) > 0.3:
						continue
					var path:= t.get_meta(LiveStrandManager.META_RIDER) as BeltPath
					var rec:= "no record"
					for r in path._riders:
						if is_same(r.body, t):
							rec = "seq %d s %.3f ps %.3f placed %.3f speed %.2f gap %.2f" % [r.seq, r.s, r.ps, r.placed_s, r.speed, r.gap]
					print("    mouth %d: body %d path %s drive %.2f held %s | %s | pos %.3v v %.2v freeze %s mode %d"
						% [tick, t.get_instance_id(), path.name, path.drive_speed,
							path._deck_shows_held, rec, t.global_position - at, t.linear_velocity,
							t.freeze, t.freeze_mode])
			if empty_at < 0 and box.stored <= 0:
				empty_at = tick
			if empty_at >= 0 and tick - empty_at > (STAND_TICKS if stand != null else POUR_TAIL_TICKS):
				break
			if tick > TIMING_DETAIL and tick % TIMING_EVERY != 0:
				continue
			var riders:= 0
			var floor_loose:= 0
			var awake:= 0
			var gliding:= 0
			for b in _live._active:
				if b.has_meta(LiveStrandManager.META_GLIDE):
					gliding += 1
				elif b.has_meta(LiveStrandManager.META_RIDER):
					riders += 1
				else:
					floor_loose += 1
					if not b.sleeping and not b.freeze:
						awake += 1
			var in_tufts:= 0
			var riding:= 0
			for t in HayTuft.all:
				if is_instance_valid(t):
					in_tufts += t.strands
					if BeltPath.is_rider(t):
						riding += 1
			print("    %4d %6d %7d %6d %6d %8d %6d %7d %9d %5.2f" % [tick, box.stored, riders,
				floor_loose, awake, gliding, HayTuft.all.size(), riding, in_tufts, tick_ms])
		print("  %s: empty at tick %d, mean %.2f ms, worst %.2f ms, %d ticks over 16.7 ms"
			% [id, empty_at, total / float(tick), worst, over])
		if stand != null:
			print("  %s: the till paid for %.0f of %d strands by tick %d" % [id,
				(GameState.money - money_was) / maxf(Tech.hay_price(), 0.0001), full, tick])
		var spots:= { }
		for b in _live._active:
			if BeltPath.is_rider(b) or b.has_meta(LiveStrandManager.META_GLIDE):
				continue
			var p:= b.global_position - at
			var key:= "%s, %s" % ["on the deck" if p.y > -0.1 else "below it",
				"inside the rails" if absf(p.x) < Cfg.BELT_WIDTH * 0.5 else "off the side"]
			spots [key] = int(spots.get(key, 0)) + 1
		for key: String in spots:
			print("  where: %4d  %s" % [int(spots [key]), key])


		for t in HayTuft.all:
			if not is_instance_valid(t):
				continue
			var d:= t.global_position - at
			print("  tuft %3d  %s  up %.2f  side %.2f  along %.2f  v %.2f" % [t.strands,
				"riding " if BeltPath.is_rider(t) else "lying  ", d.y, d.x, d.z,
				t.linear_velocity.length()])
		world.props.remove(box)
		await _clear(_live._active.duplicate())
		for t in HayTuft.all.duplicate():
			if is_instance_valid(t):
				world.props.remove(t)
		if belt != null:
			world.builds.demolish(belt)
		await _ticks(10)


const BELT_LOAD_TICKS:= 60


const TIMING_LAYERS:= 6


const TOOL_RUNS:= [[0, 168, 60], [5, 300, 15], [5, 300, 60], [5, 300, 60], [5, 300, 240]]
const TOOL_WATCH:= 120
const TOOL_FILL_TICKS:= 45


func _case_dump_twice_tool() -> void:
	print("\n=== a second forkful dumped off the real fork ===")
	var was_mode: int = Cfg.tool_mode
	Cfg.tool_mode = Cfg.TOOL_SIMPLE
	Tech.grant_legacy()


	var was_rank:= Tech.rank_of("fork_size")
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	var rig: Shovel = player.pitchfork
	rig.reset_aim()
	await _ticks(10)
	print("  %-5s %-6s %8s %8s %8s %8s %8s" % ["rank", "gap", "held", "thrown", "up m/s", "top m", "m/s"])
	for run: Array in TOOL_RUNS:
		var rank:= int(run [0])
		var strands:= int(run [1])
		var gap:= int(run [2])
		var away:= run.size() > 3 and run [3] is bool and bool(run [3])
		var no_settle:= run.size() > 3 and run [3] is String and str(run [3]) == "nosettle"
		_live.settle_enabled = not no_settle
		Tech.grant("fork_size", rank)
		await _ticks(5)
		player.global_position = Vector3(11.5, 0.4, 0.0)
		player.rotation = Vector3(0, - PI * 0.5, 0)
		player.head.rotation.x = -0.55
		player.set("_pitch", -0.55)
		player.velocity = Vector3.ZERO
		await _ticks(10)
		var want:= mini(strands, rig.capacity())
		var first:= _fill_pan(rig, want)
		await _ticks(TOOL_FILL_TICKS)
		var held:= rig.carried_strands()
		rig.dump()
		var second: Array [RigidBody3D] = []
		var second_dump:= gap + TOOL_FILL_TICKS
		var up:= { }
		var top:= 0.0
		var speed:= 0.0
		var speed_at:= 0
		var rise:= 0.0
		var rise_at:= 0


		var grace:= int(Shovel.LET_GO_TIME * 60.0)
		var blind_at_grace:= [0, 0]
		var blind_prev:= { }
		var fast_were_blind:= 0
		var fast_could_see:= 0
		var fast_near_blade:= 0
		var fast_nearest:= 99.0
		var tufts_at_fastest:= [0, 0]
		for tick in range(1, second_dump + TOOL_WATCH + 1):
			await get_tree().physics_frame
			if tick == gap:
				_where_is(first, "the first load, tick %d" % tick)
				second = _fill_pan(rig, want)
			elif tick == second_dump:
				held += rig.carried_strands()
				rig.dump()
			elif tick == second_dump + TOOL_WATCH:
				_where_is(first, "the first load at the end")
				_where_is(second, "the second load at the end")
			elif tick == second_dump + 3 and away:
				player.global_position = Vector3(11.5, 0.4, 10.0)
				player.velocity = Vector3.ZERO
			var blade_at: Vector3 = rig.body.global_position
			var bodies: Array = []
			bodies.append_array(_live._active)
			bodies.append_array(HayTuft.all)
			var tufts_now:= 0
			var emerging_now:= 0
			for t in HayTuft.all:
				if is_instance_valid(t) and t.is_inside_tree():
					tufts_now += 1
					if t._emerging > 0.0:
						emerging_now += 1
			var blind_now:= { }
			for b: RigidBody3D in bodies:
				if not is_instance_valid(b) or not b.is_inside_tree() or b.freeze:
					continue
				var v:= b.linear_velocity
				var id:= b.get_instance_id()
				var blind:= b is not HayTuft and not (b.collision_mask & Cfg.L_STRAND)
				if blind:
					blind_now [id] = true
				if v.length() > 10.0 and not blind_prev.has("fast_" + str(id)):
					blind_prev ["fast_" + str(id)] = true
					if blind_prev.has(id):
						fast_were_blind += 1
					else:
						fast_could_see += 1
					var d:= b.global_position.distance_to(blade_at)
					fast_nearest = minf(fast_nearest, d)
					if d < 0.4:
						fast_near_blade += 1
				if v.length() > speed:
					speed = v.length()
					speed_at = tick
					tufts_at_fastest = [tufts_now, emerging_now]
				if v.y > rise:
					rise = v.y
					rise_at = tick
				top = maxf(top, b.global_position.y)
				if tick >= second_dump + DUMP_RISE_TICKS and v.y > DUMP_THROWN:
					up [id] = true
			if tick == grace - 1:
				blind_at_grace [0] = blind_now.size()
			elif tick == second_dump + grace - 1:
				blind_at_grace [1] = blind_now.size()
			for k in blind_prev.keys():
				if k is int:
					blind_prev.erase(k)
			for id in blind_now:
				blind_prev [id] = true
		print("  %-5d %-6d %8d %8d %8.1f %8.2f %8.1f  fork holds %d, fastest at tick %d, highest rise at %d (second dump at %d)"
			% [rank, gap, held, up.size(), rise, top, speed, rig.capacity(), speed_at, rise_at,
			second_dump])
		print("        %s; still blind when the clock ran out: %d of the first load, %d of the second; over 10 m/s: %d were blind the tick before, %d could see, %d within 0.4 m of the blade, nearest %.2f m"
			% ["settling off" if no_settle else ("fork walked away" if away else "fork stays"),
			blind_at_grace [0], blind_at_grace [1],
			fast_were_blind, fast_could_see, fast_near_blade, fast_nearest])
		print("        at the fastest tick %d tufts stood there, %d of them still emerging"
			% [tufts_at_fastest [0], tufts_at_fastest [1]])
		_check("off a rank %d fork, a second load %d ticks after the first throws no straw (%d)"
			% [rank, gap, up.size()], up.size() <= DUMP_NOISE * 2)
		await _clear(first)
		await _clear(second)
		for t in HayTuft.all.duplicate():
			if is_instance_valid(t):
				t.queue_free()
		await _ticks(30)
	Cfg.tool_mode = was_mode
	Tech.grant("fork_size", was_rank)
	_live.settle_enabled = true


func _where_is(load: Array [RigidBody3D], label: String) -> void:
	var loose:= 0
	var frozen:= 0
	var gliding:= 0
	var gone:= 0
	var poured:= 0
	for b in load:
		if not _mine(b):
			gone += 1
		elif b.freeze:
			frozen += 1
		elif _live._gliding.has(b.get_instance_id()):
			gliding += 1
		else:
			loose += 1
		if _live._poured.has(b.get_instance_id()):
			poured += 1
	var tufts:= 0
	var in_tufts:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and t.is_inside_tree():
			tufts += 1
			in_tufts += t.strands
	print("  %s: %d loose, %d frozen, %d gliding, %d gone, %d still marked poured; %d tufts holding %d"
		% [label, loose, frozen, gliding, gone, poured, tufts, in_tufts])
	_diagnose(load)


func _fill_pan(rig: Shovel, count: int) -> Array [RigidBody3D]:
	var made: Array [RigidBody3D] = []
	var at:= rig._hold_centre()
	for i in count:
		var jitter:= Vector3(_rng.randf_range(-0.05, 0.05),
			_rng.randf_range(0.01, 0.07), _rng.randf_range(-0.07, 0.07))
		var b:= _live.spawn(at + jitter, StrandFactory.random_strand_basis(_rng),
			Vector3.ZERO, StrandFactory.random_tint(_rng))
		if b != null:
			made.append(b)
	return made


const TWICE_RUNS:= [[300, 15], [300, 15, 180], [300, 40], [300, 40, 180]]


const TWICE_WATCH:= 420


func _case_dump_twice() -> void:
	print("\n=== a second bladeful dumped on the first ===")
	print("  grace is %d ticks" % int(Shovel.LET_GO_TIME * 60.0))
	print("  %-8s %-6s %8s %8s %8s %8s" % ["strands", "gap", "thrown", "up m/s", "top m", "m/s"])
	var at:= SPOT + Vector3(0.0, 0.0, -2.5)
	player.global_position = Vector3(at.x + 3.0, 0.2, at.z + 3.0)
	await _ticks(20)
	var grace:= int(Shovel.LET_GO_TIME * 60.0)
	for run: Array in TWICE_RUNS:
		var strands:= int(run [0])
		var gap:= int(run [1])
		var grace2:= int(run [2]) if run.size() > 2 else grace
		var blind_at:= 0
		var layers:= ceili(strands / 49.0)
		var start:= at + Vector3(0.0, 0.8, -0.6)
		var first:= _deal_bladeful(start, layers, Vector3(0.0, 0.0, 1.0), strands)
		var second: Array [RigidBody3D] = []
		var up:= { }
		var top:= 0.0
		var speed:= 0.0
		var speed_at:= 0
		var rise:= 0.0
		var forced:= 0
		var seen_tufts:= { }
		var emerging:= { }
		for tick in range(1, maxi(gap, 0) + TWICE_WATCH + 1):
			await get_tree().physics_frame
			if tick == gap:
				second = _deal_bladeful(start, layers, Vector3(0.0, 0.0, 1.0), strands)


			for t in HayTuft.all:
				if not is_instance_valid(t) or not t.is_inside_tree():
					continue
				var tid:= t.get_instance_id()
				seen_tufts [tid] = true
				var was:= float(emerging.get(tid, -1.0))
				var now_e: float = t._emerging
				if was > 0.0 and now_e <= 0.0 and t._straw_inside():
					forced += 1
				emerging [tid] = now_e
				var tv:= t.linear_velocity.length()
				if tv > speed:
					speed = tv
					speed_at = tick
			for k in 2:
				var load:= first if k == 0 else second
				var born:= 0 if k == 0 else gap
				var mercy:= grace if k == 0 else grace2
				var t:= tick - born
				for b in load:
					if not is_instance_valid(b) or not b.is_inside_tree():
						continue
					if t < mercy:
						_live.see_straw_again(b)
					elif t == mercy and _mine(b):
						if k == 1 and not (b.collision_mask & Cfg.L_STRAND):
							blind_at += 1
						b.collision_mask |= Shovel.BLIND_MASK
						_live.set_protected(b, false)
					if b.freeze or not _mine(b) or t < DUMP_RISE_TICKS:
						continue
					var v:= b.linear_velocity
					if v.length() > speed:
						speed = v.length()
						speed_at = tick
					rise = maxf(rise, v.y)
					top = maxf(top, b.global_position.y)
					if v.y > DUMP_THROWN:
						up [b.get_instance_id()] = true
		print("  %-8d %-6d %8d %8.1f %8.2f %8.1f at tick %d, %d tufts, %d gave up emerging, grace %d left %d blind"
			% [strands, gap, up.size(), rise, top, speed, speed_at, seen_tufts.size(), forced,
			grace2, blind_at])
		_check("%d strands, second dump %d ticks after the first, throws no straw (%d)"
			% [strands, gap, up.size()], up.size() <= DUMP_NOISE * 2)
		await _clear(first)
		await _clear(second)
		await _ticks(30)


const TIMING_STRANDS:= 360
const TIMING_TICKS:= 360
const TIMING_EVERY:= 15

const TIMING_DETAIL:= 60


func _deal_bladeful(start: Vector3, layers: int,
		forward:= Vector3(0.0, 0.0, 1.0), cap:= -1) -> Array [RigidBody3D]:
	var load: Array [RigidBody3D] = []
	for layer in layers:
		for cell in 49:
			if cap >= 0 and load.size() >= cap:
				break
			var stagger:= 0.5 if layer % 2 == 1 else 0.0
			var local:= Vector3((float(cell % 7) + 0.5 + stagger - 3.5) * Shovel.LOAD_SLOT_PITCH,
				float(layer) * Shovel.LOAD_LAYER,
				(float(cell / 7) + 0.5 - 3.5) * Shovel.LOAD_SLOT_PITCH)
			var b: RigidBody3D = _live.spawn(start + local, StrandFactory.random_strand_basis(_rng),
				Vector3.ZERO, StrandFactory.random_tint(_rng))
			if b == null:
				continue
			b.collision_mask &= ~ Shovel.BLIND_MASK
			_live.set_protected(b, true)
			load.append(b)
	var push:= (Vector3(forward.x * 0.8, -0.6, forward.z * 0.8).normalized()
		+ Vector3.UP * Shovel.DUMP_LIFT).normalized() * Shovel.DUMP_SPEED
	for b in load:
		Shovel.mark_let_go(b)
		b.linear_velocity = push + Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0),
			_rng.randfn(0.0, 1.0)) * push.length() * Shovel.DUMP_SPREAD
		b.angular_velocity = Vector3(_rng.randfn(0.0, 2.4), _rng.randfn(0.0, 2.4),
			_rng.randfn(0.0, 2.4))
		b.sleeping = false
	return load


func _track(heap: Array [RigidBody3D], stats: Dictionary, skip: Dictionary = { }) -> void:
	for b in heap:
		if not is_instance_valid(b) or not b.is_inside_tree() or b.freeze or skip.has(b.get_instance_id()):
			continue
		if b is not HayTuft and not _mine(b):
			continue
		var v:= b.linear_velocity
		var y:= b.global_position.y
		stats ["speed"] = maxf(float(stats ["speed"]), v.length())
		stats ["rise"] = maxf(float(stats ["rise"]), y)
		if v.length() > 2.0:
			(stats ["fast"] as Dictionary) [b.get_instance_id()] = true

		if stats.has("from"):
			y -= float((stats ["from"] as Dictionary).get(b.get_instance_id(), 0.0))
		if y > 0.3:
			(stats ["high"] as Dictionary) [b.get_instance_id()] = true


func _pour(count: int, at: Vector3, spread: float) -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []
	var made:= 0
	while made < count:
		for i in mini(POUR_PER_TICK, count - made):
			var p:= at + Vector3(_rng.randf_range(- spread, spread), 1.0,
				_rng.randf_range(- spread, spread))
			var b: RigidBody3D = _live.spawn(p, StrandFactory.random_strand_basis(_rng),
				Vector3(0.0, -0.5, 0.0), StrandFactory.random_tint(_rng))
			if b != null:
				out.append(b)
			made += 1
		await get_tree().physics_frame
	return out


func _measure(label: String, heap: Array [RigidBody3D]) -> Dictionary:


	await get_tree().physics_frame
	var t0:= Time.get_ticks_usec()
	for i in MEASURE_TICKS:
		await get_tree().physics_frame
	var ms:= float(Time.get_ticks_usec() - t0) / float(MEASURE_TICKS) / 1000.0
	var loose:= 0
	var awake:= 0
	var settled:= 0
	for b in heap:
		if not _mine(b):
			continue
		loose += 1
		if LiveStrandManager.is_pinned(b):
			settled += 1
		elif not b.sleeping and not b.freeze:
			awake += 1
	var sizes:= _live.tuft_sizes()
	var biggest:= 0
	var in_tufts:= 0
	for n in sizes:
		biggest = maxi(biggest, n)
		in_tufts += n
	print("  %-10s %6d %6d %8d %6d %9d %4d %9.2f"
		% [label, loose, awake, settled, sizes.size(), in_tufts, biggest, ms])
	return { "loose": loose, "awake": awake, "settled": settled, "ms": ms,
		"tufts": sizes.size(), "in_tufts": in_tufts, "max": biggest }


func _diagnose(heap: Array [RigidBody3D]) -> void:
	var why:= { }
	var space:= world.get_world_3d().direct_space_state
	for b in heap:
		if not _mine(b) or LiveStrandManager.is_pinned(b):
			continue
		var reason:= ""
		if b.freeze:
			reason = "frozen"
		elif b.collision_mask != LiveStrandManager.STRAND_MASK:
			reason = "mask %d" % b.collision_mask
		elif float(b.get_meta(LiveStrandManager.META_REST, 0.0)) < Cfg.STRAND_SLEEP_AFTER:
			reason = "not rested"
		else:
			var q:= PhysicsRayQueryParameters3D.create(b.global_position + Vector3(0.0, 0.02, 0.0),
				b.global_position - Vector3(0.0, LiveStrandManager.SETTLE_PROBE, 0.0))
			q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_STRAND | Cfg.L_SETTLED
			var skip: Array [RID] = [b.get_rid()]
			q.exclude = skip
			q.hit_from_inside = true
			var hit:= space.intersect_ray(q)
			if hit.is_empty():
				reason = "nothing under it"
			else:
				reason = "on layer %d" % (hit.get("collider") as CollisionObject3D).collision_layer
		why [reason] = int(why.get(reason, 0)) + 1
	for r: String in why:
		print("  loose: %4d  %s" % [int(why [r]), r])


func _clear(heap: Array [RigidBody3D]) -> void:
	for b in heap:
		if _mine(b):
			_live.consume(b)
	await _ticks(2)
	for t in HayTuft.all.duplicate():
		if is_instance_valid(t):
			world.props.remove(t)
	await _ticks(10)


func _mine(b: RigidBody3D) -> bool:
	return is_instance_valid(b) and b.get_parent() == _live


func _floating(b: RigidBody3D) -> bool:
	var along:= b.global_basis.z
	along.y = 0.0
	along = along.normalized() if along.length_squared() > 0.0001 else Vector3.FORWARD
	var box:= BoxShape3D.new()
	var depth:= LiveStrandManager.WAIT_PROBE + 0.01
	box.size = Vector3(0.02, depth, Cfg.STRAND_LENGTH
		* float(b.get_meta(LiveStrandManager.META_LEN, 1.0)))
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP.cross(along), Vector3.UP, along),
		b.global_position - Vector3(0.0, depth * 0.5, 0.0))
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_STRAND | Cfg.L_SETTLED
	var skip: Array [RID] = [b.get_rid()]
	q.exclude = skip
	return world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(what: String, ok: bool) -> void:


	print("  %s %s [stranded folds %d]" % ["ok  " if ok else "FAIL", what,
		LiveStrandManager.folded_stranded])
	if not ok:
		_fails.append(what)
