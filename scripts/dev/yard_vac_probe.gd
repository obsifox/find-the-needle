class_name DevYardVacProbe
extends Node


const HOLD:= 90
const SETTLE:= 45
const COUNT:= 24


const LEDGER_TOL:= 2.0

var world: Node3D
var player: Player

var _fail:= 0
var _pin:= Vector3.INF


func run() -> void:
	for i in 60:
		await get_tree().process_frame


	Tech.grant_legacy()
	Tech.grant("yard_vac", 1)
	GameState.grant_tool("yard_vac")
	print("\n=== yard vac ===")
	await _tuft_case()
	await _floor_case()
	await _pile_case()
	await _pile_rate_case()
	await _capacity_case()
	_ranked_bin_case()
	await _pour_case()
	await _needle_case()
	_hints_case()
	await _pour_storm_case()
	await _bin_case()
	await _dropped_case()
	print("=== yard vac: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


const TUFT_SIZES:= [12, 40, 100]


const TUFT_HOLD:= 600


func _tuft_case() -> void:
	var spot:= Vector3(13.4, 0.05, 8.0)
	_stand_at(Vector3(spot.x - 1.1, 0.0, spot.z), Vector3(1, 0, 0))
	_look_at(spot)
	var vac:= player.yard_vac
	vac.clear()
	var props: PropManager = world.props
	var tufts: Array [HayTuft] = []
	var worth:= 0
	for i in TUFT_SIZES.size():
		var at:= spot + Vector3(0.0, 0.1, (float(i) - 1.0) * 0.45)
		var made:= props.spawn("hay_tuft", Transform3D(Basis.IDENTITY, at),
			{ "strands": TUFT_SIZES [i] }) as HayTuft
		if made == null:
			print("  tufts: could not spawn one")
			_fail += 1
			return
		tufts.append(made)
		worth += made.hay_strands()
	for i in SETTLE:
		await get_tree().physics_frame

	vac.set_sucking(true)
	var ticks:= 0
	var left:= tufts.size()
	while ticks < TUFT_HOLD and left > 0:
		await get_tree().physics_frame
		ticks += 1
		left = 0
		for each in tufts:
			if is_instance_valid(each) and not each.is_queued_for_deletion():
				left += 1
	vac.set_sucking(false)
	print("  tufts: bin=%d of %d in %d tufts, %d left lying, %.1f s"
		% [vac.fill(), worth, tufts.size(), left, float(ticks) / 60.0])
	if left > 0:
		print("    FAIL: the vac left %d tufts on the slab" % left)
		_fail += 1
	if vac.fill() != worth:
		print("    FAIL: the tufts held %d strands and the bin gained %d"
			% [worth, vac.fill()])
		_fail += 1
	_release()


func _floor_case() -> void:
	var spot:= Vector3(13.4, 0.05, 8.0)
	_stand_at(Vector3(spot.x - 1.1, 0.0, spot.z), Vector3(1, 0, 0))
	_look_at(spot)
	var vac:= player.yard_vac
	vac.clear()
	var bodies:= await _drop_hay(spot, 0.18)
	if bodies.is_empty():
		print("  floor: no strands spawned, live budget?")
		_fail += 1
		return

	await _hold_suck(HOLD)
	var gone:= 0
	for b in bodies:
		if not is_instance_valid(b) or b.get_parent() == null:
			gone += 1
	print("  floor: bin=%d of %d dropped, bodies gone=%d, aim=%s"
		% [vac.fill(), bodies.size(), gone, vac.has_bite()])
	if vac.fill() <= 0:
		print("    FAIL: the vac ate nothing off the slab")
		_fail += 1
	if gone <= 0:
		print("    FAIL: the bin filled but the hay is still lying there")
		_fail += 1
	_release()


func _pile_case() -> void:
	var field: HayField = world.field
	var r:= 0.0
	for i in 60:
		var probe:= 9.5 - float(i) * 0.1
		if field.height_at(probe, 0.0) > 0.6:
			r = probe
			break
	if r <= 0.0:
		print("  pile: no deep ring found, pile shape changed?")
		_fail += 1
		return
	var spot:= Vector3(r, field.height_at(r, 0.0), 0.0)
	var stand:= Vector3(r + 1.3, 0.0, 0.0)
	stand.y = field.height_at(stand.x, stand.z)
	_stand_at(stand, (spot - stand) * Vector3(1, 0, 1))
	_look_at(spot)

	var vac:= player.yard_vac
	vac.clear()
	var hay_before:= GameState.hay_total
	await _hold_suck(HOLD)
	var took:= hay_before - GameState.hay_total


	var held:= vac.fill() + vac.inbound_count()
	print("  pile: bin=%d + %d in the air = %d, ledger fell %.1f, aim=%s pile=%s"
		% [vac.fill(), vac.inbound_count(), held, took,
			vac.has_bite(), vac.bite_is_pile()])
	if held <= 0:
		print("    FAIL: the vac took nothing out of the pile")
		_fail += 1
	elif absf(took - float(held)) > LEDGER_TOL:
		print("    FAIL: the pile lost %.1f but the vac is holding %d"
			% [took, held])
		_fail += 1


	if vac.inbound_count() <= 0 and vac.fill() <= 0:
		print("    FAIL: nothing was ever in the air between pile and bin")
		_fail += 1
	_release()


const RATE_HOLD:= 240

const RATE_FLOOR:= 0.85


func _pile_rate_case() -> void:
	var field: HayField = world.field
	var vac:= player.yard_vac
	var levels:= [0, TechTree.max_rank("vac_suction")]
	for i in levels.size():
		Tech.grant("vac_suction", levels [i])
		var dir:= Vector3(0.0, 0.0, 1.0 if i == 0 else -1.0)
		var r:= 0.0
		for k in 60:
			var probe:= 9.5 - float(k) * 0.1
			if field.height_at(dir.x * probe, dir.z * probe) > 0.6:
				r = probe
				break
		if r <= 0.0:
			print("  pile rate: no deep ring found on that side, pile shape changed?")
			_fail += 1
			continue
		var spot:= dir * r
		spot.y = field.height_at(spot.x, spot.z)
		var stand:= dir * (r + 1.3)
		stand.y = field.height_at(stand.x, stand.z)
		_stand_at(stand, (spot - stand) * Vector3(1, 0, 1))
		_look_at(spot)
		vac.clear()
		var hay_before:= GameState.hay_total
		await _hold_suck(RATE_HOLD)
		var took:= hay_before - GameState.hay_total
		var rate:= took / (float(RATE_HOLD) / 60.0)
		print("  pile rate: level %d took %.0f in %.1f s, %.0f a second against %.0f, ring %.2f m"
			% [levels [i], took, float(RATE_HOLD) / 60.0, rate, Tech.vac_suck_rate(),
				Tech.vac_bite_radius()])
		if rate < Tech.vac_suck_rate() * RATE_FLOOR:
			print("    FAIL: the pile handed over %.0f a second of the %.0f the card says"
				% [rate, Tech.vac_suck_rate()])
			_fail += 1
		_release()
		for k in 150:
			await get_tree().physics_frame
	Tech.grant("vac_suction", 0)
	vac.clear()


func _capacity_case() -> void:
	var vac:= player.yard_vac


	var spot:= Vector3(13.4, 0.05, 8.0)
	_stand_at(Vector3(spot.x - 1.1, 0.0, spot.z), Vector3(1, 0, 0))
	_look_at(spot)
	vac.clear()
	await _drop_hay(spot, 0.18)
	vac.debug_fill(Tech.vac_capacity() - 5)


	player.yard_vac.set_sucking(true)
	for i in 180:
		await get_tree().physics_frame
		if vac.is_full():
			break
	player.yard_vac.set_sucking(false)
	print("  full: bin=%d of %d, still sucking=%s"
		% [vac.fill(), Tech.vac_capacity(), vac.is_sucking()])
	if vac.fill() > Tech.vac_capacity():
		print("    FAIL: the bin went past its own capacity")
		_fail += 1
	if vac.fill() < Tech.vac_capacity():
		print("    FAIL: the bin never reached capacity at the pile face")
		_fail += 1
	if vac.is_sucking():
		print("    FAIL: a full vac is still running")
		_fail += 1
	_release()


func _ranked_bin_case() -> void:
	var vac:= player.yard_vac
	var top:= TechTree.max_rank("vac_bin")
	Tech.grant("vac_bin", top)
	vac.clear()
	vac.debug_fill(Cfg.VAC_CAPACITY * 10)
	print("  bigger bin: level %d holds %d, base %d, full=%s room=%d"
		% [top, vac.fill(), Cfg.VAC_CAPACITY, vac.is_full(), vac.room()])
	if vac.fill() <= Cfg.VAC_CAPACITY:
		print("    FAIL: the bin at the top level holds no more than the base bin")
		_fail += 1
	if vac.fill() != Tech.vac_capacity() or not vac.is_full() or vac.room() != 0:
		print("    FAIL: the bin does not stop where Tech.vac_capacity() says")
		_fail += 1
	Tech.grant("vac_bin", 0)
	vac.clear()


func _pour_case() -> void:
	var vac:= player.yard_vac
	var spot:= Vector3(13.4, 0.05, 8.0)
	_stand_at(Vector3(spot.x - 1.1, 0.0, spot.z), Vector3(1, 0, 0))
	_look_at(spot)
	vac.clear()
	var load:= 120
	vac.debug_fill(load)
	var live: LiveStrandManager = world.live
	var before:= live.active_count() + _tufted()

	player.yard_vac.set_pouring(true)
	for i in 120:
		await get_tree().physics_frame
		if vac.fill() <= 0:
			break
	player.yard_vac.set_pouring(false)
	var made:= live.active_count() + _tufted() - before
	print("  pour: bin %d -> %d, hay in the yard +%d" % [load, vac.fill(), made])
	if vac.fill() > 0:
		print("    FAIL: the bin did not empty in two seconds of pouring")
		_fail += 1
	if made != load:
		print("    FAIL: %d went into the pour and %d came out of it" % [load, made])
		_fail += 1


func _needle_case() -> void:
	var live: LiveStrandManager = world.live
	var vac:= player.yard_vac
	var spot:= Vector3(11.0, 0.05, 8.0)
	_stand_at(Vector3(spot.x - 1.1, 0.0, spot.z), Vector3(1, 0, 0))
	_look_at(spot)
	vac.clear()

	var index:= GameState.register_needle(spot)
	var needle:= live.reveal_needle(index, spot)
	if needle == null:
		print("  needle: could not put one on the floor to test with")
		_fail += 1
		return


	needle.global_position = vac.mouth_position() + Vector3(0.0, -0.05, 0.0)
	var had:= live.needles.size()


	await _drop_hay(spot, 0.15)
	await _hold_suck(HOLD)

	var alive:= is_instance_valid(needle) and live.needles.has(needle)
	print("  needle: still a needle=%s, needles %d -> %d, bin=%d"
		% [alive, had, live.needles.size(), vac.fill()])
	if not alive:
		print("    FAIL: THE VAC SWALLOWED A NEEDLE")
		_fail += 1
	if vac.fill() <= 0:
		print("    FAIL: the vac ate nothing, so this case proved nothing")
		_fail += 1
	_release()


func _hints_case() -> void:
	var hud: Hud = world.hud
	if hud == null or hud._hints == null:
		print("  hints: no hint bar in this world, nothing checked")
		_fail += 1
		return
	var vac:= player.yard_vac
	vac.clear()
	vac.debug_fill(140)
	player._set_tool(Player.Tool.YARD_VAC)
	var rows:= hud._hints._hints()
	var flat:= ""
	for row: PackedStringArray in rows:
		flat += "|".join(row) + "\n"
	var suck:= flat.findn("suck") >= 0
	var tip:= flat.findn("tip it back out") >= 0
	var load:= flat.find("140 / %d" % Tech.vac_capacity()) >= 0
	print("  hints: names the suck=%s, names the pour=%s, says the load=%s"
		% [suck, tip, load])
	if not suck:
		print("    FAIL: the bar does not say what the left button does")
		_fail += 1
	if not tip:
		print("    FAIL: a loaded vac does not offer the pour")
		_fail += 1
	if not load:
		print("    FAIL: the bar does not say what is in the bin")
		_fail += 1
	vac.clear()


func _bin_case() -> void:
	var vac:= player.yard_vac
	vac.clear()
	vac.debug_fill(Tech.vac_capacity() / 2)
	var still:= vac.drawn_fill()
	var half:= vac.fill_fraction()


	player.yard_vac.set_sucking(true)
	for i in 20:
		await get_tree().physics_frame
	var running:= vac.drawn_fill()
	player.yard_vac.set_sucking(false)
	print("  bin: drawn %.2f full standing still, %.2f with the motor on (bin %.2f)"
		% [still, running, vac.fill_fraction()])
	if absf(still - half) > 0.08:
		print("    FAIL: a half full bin is not drawn half full")
		_fail += 1
	if running < 0.25:
		print("    FAIL: the hay in the bin is wiped out while the motor runs")
		_fail += 1
	vac.clear()
	_release()


func _dropped_case() -> void:
	var prop:= ItemDb.make("yard_vac")
	if prop == null:
		print("  dropped: could not make one")
		_fail += 1
		return
	world.add_child(prop)
	prop.global_position = Vector3(11.0, 0.4, 6.0)
	await get_tree().process_frame

	var lumps:= 0
	for n in prop.find_children("YV_Eat_*", "", true, false):
		lumps += 1


	var bounds:= AABB()
	var first:= true
	for n in prop.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		var box:= mi.global_transform * mi.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var span:= maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	print("  dropped: %d clumps of hay on it, model spans %.2f m" % [lumps, span])
	if lumps > 0:
		print("    FAIL: a vac lying in the yard has hay floating beside it")
		_fail += 1
	if span > 1.8:
		print("    FAIL: the model still measures as long as the intake")
		_fail += 1
	prop.queue_free()


func _hold_suck(frames: int) -> void:
	player.yard_vac.set_sucking(true)
	for i in frames:
		await get_tree().physics_frame
	player.yard_vac.set_sucking(false)


func _release() -> void:
	player.yard_vac.set_sucking(false)
	player.yard_vac.set_pouring(false)


func _stand_at(pos: Vector3, facing: Vector3) -> void:
	_pin = Vector3(pos.x, pos.y + 0.05, pos.z)
	player.global_position = _pin
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, atan2(- facing.x, - facing.z), 0.0)
	player._set_tool(Player.Tool.YARD_VAC)
	if player.current_tool != Player.Tool.YARD_VAC:
		print("    (no vac in hand: owned=%s, licensed=%s)"
			% [GameState.has_tool("yard_vac"), Tech.is_unlocked("yard_vac")])


func _look_at(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()),
		-1.5, 1.5)


func _physics_process(_delta: float) -> void:
	if _pin != Vector3.INF:
		player.global_position = _pin
		player.velocity = Vector3.ZERO


func _drop_hay(center: Vector3, spread: float) -> Array [RigidBody3D]:
	var live: LiveStrandManager = world.live
	var out: Array [RigidBody3D] = []
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4242
	for i in COUNT:
		var p:= center + Vector3(rng.randf_range(- spread, spread),
			rng.randf() * 0.04, rng.randf_range(- spread, spread))
		var b:= live.spawn(p, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if b != null:


			LiveStrandManager.hold(b, 30.0)
			out.append(b)
	for i in SETTLE:
		await get_tree().process_frame
	return out


const QUIET:= 180


const POUR_LIMIT:= 7.0


const HEAP_BODIES:= 60

const STORM_TOL:= 2.0


func _pour_storm_case() -> void:
	var vac:= player.yard_vac
	var live: LiveStrandManager = world.live
	_stand_at(Vector3(13.4, 0.05, 8.0), Vector3(1, 0, 0))
	_look_at(Vector3(14.6, 0.05, 8.0))
	vac.clear()


	for b in live._active.duplicate():
		if is_instance_valid(b) and not live.needles.has(b):
			live.consume(b)
	for i in 60:
		await get_tree().physics_frame

	var was_live:= live.active_count()
	var was_hay: float = GameState.hay_total
	var was_returned: float = GameState.hay_returned
	var was_tufted:= _tufted()
	var was_tufts:= _tuft_count()
	vac.debug_fill(Tech.vac_capacity())
	var us:= 0
	var ticks:= 0
	var peak:= 0
	var peak_awake:= 0
	player.yard_vac.set_pouring(true)
	var last:= Time.get_ticks_usec()
	for i in 900:
		await get_tree().physics_frame
		var now:= Time.get_ticks_usec()
		us += now - last
		last = now
		ticks += 1
		peak = maxi(peak, live.active_count() - was_live)
		var awake:= 0
		for b in live._active:
			if not b.sleeping and not b.freeze:
				awake += 1
		peak_awake = maxi(peak_awake, awake)
		if vac.fill() <= 0:
			break
	player.yard_vac.set_pouring(false)
	var poured:= float(ticks) / 60.0
	var busy:= float(us) / float(maxi(ticks, 1)) * 0.001

	var quiet_us:= 0
	for i in QUIET:
		await get_tree().physics_frame
		var now:= Time.get_ticks_usec()
		quiet_us += now - last
		last = now
	var bodies:= (live.active_count() - was_live) + (_tuft_count() - was_tufts)
	var back: float = GameState.hay_total - was_hay
	var lying:= float(live.active_count() - was_live) + float(_tufted() - was_tufted)
	print("  storm: %d poured in %.1f s as %d bodies, %.0f lying, %.0f back on the books"
		% [Tech.vac_capacity(), poured, bodies, lying, back])
	print("    tick %.2f ms pouring and %.2f ms after, at most %d strands out and %d awake"
		% [busy, float(quiet_us) / float(QUIET) * 0.001, peak, peak_awake])
	print("    returned %.0f, tufts %s" % [GameState.hay_returned - was_returned,
		str(live.tuft_sizes())])
	if vac.fill() > 0:
		print("    FAIL: a full bin did not empty in fifteen seconds")
		_fail += 1
	elif poured > POUR_LIMIT:
		print("    FAIL: the bin took %.1f s to empty" % poured)
		_fail += 1
	if bodies > HEAP_BODIES:
		print("    FAIL: the pour landed as %d bodies, which is strands again" % bodies)
		_fail += 1
	if absf(back) > STORM_TOL:
		print("    FAIL: %.0f strands of the pour went back on the pile's books" % back)
		_fail += 1
	if absf(lying - float(Tech.vac_capacity())) > STORM_TOL:
		print("    FAIL: %d went into the pour and %.0f are lying in the yard"
			% [Tech.vac_capacity(), lying])
		_fail += 1


func _tuft_count() -> int:
	var n:= 0
	for t in HayTuft.all:
		if is_instance_valid(t):
			n += 1
	return n


func _tufted() -> int:
	var n:= 0
	for t in HayTuft.all:
		if is_instance_valid(t):
			n += t.strands
	return n
