class_name DevBroomProbe
extends Node


const COUNT:= 24
const SETTLE:= 45
const AFTER:= 50

const MOVED:= 0.25

const STILL:= 0.05

var world: Node3D
var player: Player

var _fail:= 0

var _pin:= Vector3.INF


func run() -> void:
	for i in 60:
		await get_tree().process_frame


	Tech.grant_legacy()
	print("\n=== broom ===")
	await _floor_case()
	await _wad_case()
	await _products_case()
	await _hold_case()
	await _merge_case()
	await _width_case()
	await _pile_case()
	await _mound_case()
	print("=== broom: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _floor_case() -> void:
	var spot:= Vector3(13.4, 0.05, 8.0)


	_stand_at(Vector3(spot.x - Broom.HEAD_FORWARD, 0.0, spot.z), Vector3(1, 0, 0))
	var bodies:= await _drop_hay(spot, 0.2)
	if bodies.is_empty():
		print("  floor: no strands spawned -- live budget?")
		_fail += 1
		return
	var before:= _centroid(bodies)
	var hay_before:= GameState.hay_total

	player.broom.sweep()
	await _after_stroke()
	var after:= _centroid(bodies)
	var swept:= player.broom.swept_count()

	var moved:= (after - before)
	var along:= moved.dot(Vector3(1, 0, 0))
	print("  floor  n=%d  swept %d  moved %.3f m  (%.3f m along the facing)"
		% [bodies.size(), swept, Vector3(moved.x, 0.0, moved.z).length(), along])
	if swept < bodies.size() / 2:
		print("    FAIL: the stroke passed over the hay and only took %d of %d"
			% [swept, bodies.size()])
		_fail += 1
	if along < MOVED:
		print("    FAIL: a stroke did not push the hay forward")
		_fail += 1
	if absf(GameState.hay_total - hay_before) > 0.001:
		print("    FAIL: sweeping the floor changed the pile total by %.3f"
			% (GameState.hay_total - hay_before))
		_fail += 1
	_clear(bodies)


func _wad_case() -> void:
	var spot:= Vector3(13.4, 0.03, 8.0)
	_stand_at(Vector3(spot.x - Broom.HEAD_FORWARD, 0.0, spot.z), Vector3(1, 0, 0))
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), spot),
		{ "strands": Cfg.WAD_BASE_STRANDS }) as HayWad
	if wad == null:
		print("  wad: could not spawn one")
		_fail += 1
		return
	for i in SETTLE:
		await get_tree().process_frame


	_look_at(wad.global_position + Vector3(0.0, 0.08, 0.0))
	for i in 12:
		await get_tree().process_frame


	var refused:= player.carry.target()
	var took:= player.carry.try_pick(true)
	if took:
		player.carry.drop()


	player._set_tool(Player.Tool.BUILD)
	for i in 12:
		await get_tree().process_frame
	var building:= player.build.is_active()
	var build_target:= player.carry.target()
	var build_took:= player.carry.try_pick(true) or player.carry.try_pick()
	if build_took:
		player.carry.drop()
	print("  wad    build tool out=%s  target=%s  took=%s"
		% [building, build_target, build_took])
	if not building:
		print("    FAIL: the build tool never came out, so this run proves nothing")
		_fail += 1
	if build_target != null or build_took:
		print("    FAIL: the build tool picked the wad up instead of leaving it")
		_fail += 1


	player._set_tool(Player.Tool.HAND)
	for i in 12:
		await get_tree().process_frame
	var offered:= player.carry.target()
	_stand_at(Vector3(spot.x - Broom.HEAD_FORWARD, 0.0, spot.z), Vector3(1, 0, 0))
	for i in 12:
		await get_tree().process_frame

	print("  wad    %.1f kg  broom target=%s  hand target=%s"
		% [wad.mass, refused, offered])
	if refused != null or took:
		print("    FAIL: the broom picked the wad up instead of sweeping it")
		_fail += 1
	if offered != wad:
		print("    FAIL: the hand cannot pick the wad up either -- this run proves nothing")
		_fail += 1

	var before:= wad.global_position
	var head:= player.broom.head_position()
	if absf(before.y - head.y) > Broom.REACH_H:
		print("    FAIL: the wad is out of the head's reach -- this run proves nothing")
		_fail += 1
	player.broom.sweep()
	await _after_stroke()
	var moved:= wad.global_position - before
	var along:= moved.dot(Vector3(1, 0, 0))
	print("  wad    swept %d  moved %.3f m  (%.3f m along the facing)"
		% [player.broom.swept_count(), Vector3(moved.x, 0.0, moved.z).length(), along])
	if player.broom.swept_count() < 1:
		print("    FAIL: the stroke passed over the wad without taking it")
		_fail += 1
	if along < MOVED:
		print("    FAIL: a stroke did not push the wad forward")
		_fail += 1
	world.props.remove(wad)
	for i in 10:
		await get_tree().process_frame


func _products_case() -> void:
	var spot:= Vector3(13.4, 0.2, 8.0)
	for id in ["hay_tuft", "hay_bale", "foiled_bale", "eco_brick", "hay_pulp",
			"paper_roll", "feed_disc"]:
		_stand_at(Vector3(spot.x - Broom.HEAD_FORWARD, 0.0, spot.z), Vector3(1, 0, 0))
		var state:= { "strands": 40 } if id == "hay_tuft" else { }
		var item: Carryable = world.props.spawn(id, Transform3D(Basis(), spot), state)
		if item == null:
			print("  %s: could not spawn one" % id)
			_fail += 1
			continue
		for i in SETTLE:
			await get_tree().process_frame
		_look_at(item.global_position)
		for i in 6:
			await get_tree().process_frame
		var target:= player.carry.target()
		_stand_at(Vector3(spot.x - Broom.HEAD_FORWARD, 0.0, spot.z), Vector3(1, 0, 0))
		var before:= item.global_position
		var head:= player.broom.head_position()
		player.broom.sweep()
		await _after_stroke()
		var moved:= item.global_position - before
		var along:= moved.dot(Vector3(1, 0, 0))
		print("  %-11s %5.1f kg  %+.2f m vs the head  swept %d  moved %.3f m along  target=%s"
			% [id, item.mass, before.y - head.y, player.broom.swept_count(), along, target])
		if target != null:
			print("    FAIL: with the broom out the hands still offered to pick it up")
			_fail += 1
		if player.broom.swept_count() < 1:
			print("    FAIL: the stroke passed over it without taking it")
			_fail += 1
		if along < MOVED:
			print("    FAIL: a stroke did not push it forward")
			_fail += 1
		if is_instance_valid(item):
			world.props.remove(item)
		for i in 10:
			await get_tree().process_frame


func _hold_case() -> void:
	var broom:= player.broom
	_stand_at(Vector3(12.4, 0.0, 8.0), Vector3(1, 0, 0))
	for i in 5:
		await get_tree().process_frame
	broom.poll_button = true
	broom.set_held(true)
	for i in 2:
		await get_tree().process_frame
	var polled:= broom.is_held_down()

	broom.poll_button = false
	var from:= broom.stroke_count
	broom.set_held(true)
	broom.sweep()

	var hz:= Engine.physics_ticks_per_second
	for i in 2 * hz:
		await get_tree().physics_frame
	var strokes:= broom.stroke_count - from
	broom.set_held(false)
	var ticks:= 0
	while broom.is_stroking() and ticks < 3 * hz:
		await get_tree().physics_frame
		ticks += 1
	var stop_ms:= ticks * 1000 / hz
	broom.poll_button = true


	print("  hold   button up lets go=%s  %d strokes in 2.0 s held  back at rest %d ms after release"
		% [not polled, strokes, stop_ms])
	if polled:
		print("    FAIL: the hold outlived a button that is not down")
		_fail += 1
	if strokes < 4:
		print("    FAIL: holding the button did not keep the broom sweeping")
		_fail += 1
	if broom.is_stroking():
		print("    FAIL: letting go did not stop the broom")
		_fail += 1


func _merge_case() -> void:
	var broom:= player.broom
	var spot:= Vector3(13.4, 0.1, 8.0)
	var a:= world.props.spawn("hay_tuft", Transform3D(Basis(), spot),
		{ "strands": 30 }) as HayTuft
	var b:= world.props.spawn("hay_tuft", Transform3D(Basis(), spot + Vector3(1.4, 0, 0.15)),
		{ "strands": 40 }) as HayTuft
	if a == null or b == null:
		print("  merge: could not spawn the tufts")
		_fail += 1
		return
	for i in SETTLE:
		await get_tree().process_frame
	var tufts_before:= _tuft_count()
	var strands_before:= _tuft_strands()
	var merged_from:= broom.merged_count

	_stand_at(Vector3(spot.x - Broom.HEAD_FORWARD, 0.0, spot.z), Vector3(1, 0, 0))
	broom.poll_button = false
	broom.set_held(true)
	broom.sweep()

	var closest:= INF
	var reach:= a.reach() + b.reach()
	for i in 3 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		_pin.x += 0.9 / float(Engine.physics_ticks_per_second)
		if is_instance_valid(a) and is_instance_valid(b) and a.is_inside_tree() and b.is_inside_tree():
			var d:= a.global_position - b.global_position
			closest = minf(closest, Vector2(d.x, d.z).length())
	print("  merge  closest the two came %.2f m, touching at %.2f m"
		% [closest, reach * Broom.MERGE_TOUCH])
	broom.set_held(false)
	broom.poll_button = true
	await _after_stroke()
	for i in 90:
		await get_tree().physics_frame

	var merges:= broom.merged_count - merged_from
	var tufts_after:= _tuft_count()
	var strands_after:= _tuft_strands()
	print("  merge  tufts %d -> %d  strands %d -> %d  merges %d"
		% [tufts_before, tufts_after, strands_before, strands_after, merges])
	if merges < 1 or tufts_after >= tufts_before:
		print("    FAIL: two tufts swept into each other stayed two")
		_fail += 1
	if strands_after != strands_before:
		print("    FAIL: pouring one tuft into the other changed the hay by %d strands"
			% (strands_after - strands_before))
		_fail += 1
	for t in HayTuft.all.duplicate():
		if is_instance_valid(t):
			world.props.remove(t)
	for i in 10:
		await get_tree().process_frame


func _width_case() -> void:
	var facing:= Vector3(1, 0, 0)
	var stand:= Vector3(12.4, 0.0, 8.0)


	var spot:= Vector3(stand.x + Broom.HEAD_FORWARD, 0.03, stand.z - 1.05)
	var out:= { }
	for rank in [0, 3]:
		Tech.grant("broom_bristles", rank)
		_stand_at(stand, facing)
		for i in 5:
			await get_tree().physics_frame
		var bodies:= await _drop_hay(spot, 0.05)
		player.broom.sweep()
		await _after_stroke()
		out [rank] = [player.broom.swept_count(), bodies.size(), Broom.sweep_width()]
		_clear(bodies)
	Tech.grant("broom_bristles", 0)
	print("  width  rank 0: %.1f m, swept %d of %d   rank 3: %.1f m, swept %d of %d"
		% [out [0] [2], out [0] [0], out [0] [1], out [3] [2], out [3] [0], out [3] [1]])
	if out [0] [0] > out [0] [1] / 4:
		print("    FAIL: a new broom already reached hay past the edge of its swathe")
		_fail += 1
	if out [3] [0] < out [3] [1] / 2:
		print("    FAIL: the top rank did not reach the hay a new broom missed")
		_fail += 1


func _tuft_count() -> int:
	var n:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and t.is_inside_tree():
			n += 1
	return n


func _tuft_strands() -> int:
	var n:= 0
	for t in HayTuft.all:
		if is_instance_valid(t) and t.is_inside_tree():
			n += t.strands
	return n


func _pile_case() -> void:
	var field: HayField = world.field


	var r:= 0.0
	for i in 60:
		var probe:= 9.5 - float(i) * 0.1
		var h:= field.height_at(probe, 0.0)
		if h > 0.6 and absf(h - field.height_at(probe, 1.0)) < 0.25:
			r = probe
			break
	if r <= 0.0:
		print("  pile: no flat ring found -- pile shape changed?")
		_fail += 1
		return

	var h:= field.height_at(r, 0.0)

	var a:= Broom.HEAD_FORWARD / r
	var stand:= Vector3(r * cos(a), 0.0, r * sin(a))
	stand.y = field.height_at(stand.x, stand.z)
	var spot:= Vector3(r, h + 0.06, 0.0)
	_stand_at(stand, (spot - stand) * Vector3(1, 0, 1))
	var bodies:= await _drop_hay(spot, 0.12, true)
	if bodies.is_empty():
		print("  pile: no strands spawned -- live budget?")
		_fail += 1
		return
	var before:= _centroid(bodies)
	var hay_before:= GameState.hay_total


	var head_y:= player.broom.head_position().y
	var surf:= field.height_at(before.x, before.z)
	print("  pile   n=%d  r=%.2f  surface %.2f m  hay %+.3f m vs the head (reach %.2f), %+.3f m vs the surface"
		% [bodies.size(), r, h, before.y - head_y, Broom.REACH_H, before.y - surf])
	if absf(before.y - head_y) > Broom.REACH_H:
		print("    FAIL: the hay is out of the head's reach -- this run proves nothing")
		_fail += 1
	if before.y < surf - Broom.PILE_SURFACE_TOL:
		print("    FAIL: the hay sank into the pile -- this run proves nothing")
		_fail += 1


	for i in AFTER:
		await get_tree().process_frame
	var idle:= _centroid(bodies)
	var creep:= Vector3(idle.x - before.x, 0.0, idle.z - before.z).length()

	player.broom.sweep()
	await _after_stroke()
	var after:= _centroid(bodies)
	var swept:= player.broom.swept_count()
	var drift:= Vector3(after.x - idle.x, 0.0, after.z - idle.z).length()

	print("  pile   swept %d  drift %.3f m  (creeps %.3f m on its own)"
		% [swept, drift, creep])
	if swept > 0:
		print("    FAIL: the broom swept %d strands lying on the pile" % swept)
		_fail += 1
	if drift > creep + STILL:
		print("    FAIL: the broom moved hay lying on the pile")
		_fail += 1
	if absf(GameState.hay_total - hay_before) > 0.001:
		print("    FAIL: sweeping at the pile changed the pile total by %.3f"
			% (GameState.hay_total - hay_before))
		_fail += 1
	_clear(bodies)


func _mound_case() -> void:
	var field: HayField = world.field
	var centre:= Vector3(13.4, 0.0, 8.0)
	_raise_mound(field, centre, 0.9, 0.22)
	for i in 30:
		await get_tree().process_frame
	var top:= field.height_at(centre.x, centre.z)
	if top < Broom.PILE_IGNORE_H:
		print("  mound: raised to %.2f m, which is under the rule's floor" % top)
		_fail += 1
		return

	_stand_at(Vector3(centre.x - Broom.HEAD_FORWARD, 0.0, centre.z), Vector3(1, 0, 0))
	var bodies:= await _drop_hay(Vector3(centre.x, top + 0.05, centre.z), 0.1)
	if bodies.is_empty():
		print("  mound: no strands spawned -- live budget?")
		_fail += 1
		return
	var before:= _centroid(bodies)
	var hay_before:= GameState.hay_total
	var head_y:= player.broom.head_position().y
	var surf:= field.height_at(before.x, before.z)
	print("  mound  n=%d  top %.2f m  hay %+.3f m vs the head (reach %.2f), %+.3f m vs the surface"
		% [bodies.size(), top, before.y - head_y, Broom.REACH_H, before.y - surf])
	if absf(before.y - head_y) > Broom.REACH_H:
		print("    FAIL: the hay is out of the head's reach -- this run proves nothing")
		_fail += 1
	if surf < Broom.PILE_IGNORE_H:
		print("    FAIL: the hay slid off the mound -- this run proves nothing")
		_fail += 1

	for i in AFTER:
		await get_tree().process_frame
	var idle:= _centroid(bodies)
	var creep:= Vector3(idle.x - before.x, 0.0, idle.z - before.z).length()

	player.broom.sweep()
	await _after_stroke()
	var swept:= player.broom.swept_count()
	var after:= _centroid(bodies)
	var drift:= Vector3(after.x - idle.x, 0.0, after.z - idle.z).length()
	print("  mound  swept %d  drift %.3f m  (creeps %.3f m on its own)"
		% [swept, drift, creep])
	if drift > creep + STILL:
		print("    FAIL: the broom moved hay lying on the mound")
		_fail += 1
	if swept > 0:
		print("    FAIL: the broom swept %d strands lying on the mound" % swept)
		_fail += 1
	if absf(GameState.hay_total - hay_before) > 0.001:
		print("    FAIL: sweeping at the mound changed the pile total by %.3f"
			% (GameState.hay_total - hay_before))
		_fail += 1
	_clear(bodies)


func _raise_mound(field: HayField, centre: Vector3, radius: float, height: float) -> void:
	var nv:= Cfg.field_verts()
	var c:= field.cell_at(centre.x, centre.z)
	var span:= int(ceil(radius / Cfg.CELL)) + 1
	for dj in range(- span, span + 1):
		for di in range(- span, span + 1):
			var i:= c.x + di
			var j:= c.y + dj
			if not field.in_bounds_vert(i, j):
				continue
			var v:= field.vertex_pos(i, j)
			if Vector2(v.x - centre.x, v.z - centre.z).length() > radius:
				continue
			field.heights [j * nv + i] = maxf(field.heights [j * nv + i], height)
			field._touch_vertex(i, j)


func _stand_at(pos: Vector3, facing: Vector3) -> void:
	_pin = Vector3(pos.x, pos.y + 0.05, pos.z)
	player.global_position = _pin
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, atan2(- facing.x, - facing.z), 0.0)
	player.head.rotation.x = -0.5
	player._set_tool(Player.Tool.BROOM)
	if player.current_tool != Player.Tool.BROOM:
		print("    (no broom in hand: owned=%s, licensed=%s)"
			% [GameState.has_tool("broom"), Tech.is_unlocked("broom")])


func _look_at(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()),
		-1.5, 1.5)


func _physics_process(_delta: float) -> void:
	if _pin != Vector3.INF:
		player.global_position = _pin
		player.velocity = Vector3.ZERO


func _drop_hay(center: Vector3, spread: float,
		frozen: bool = false) -> Array [RigidBody3D]:
	var live: LiveStrandManager = world.live
	var out: Array [RigidBody3D] = []
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4242
	for i in COUNT:
		var p:= center + Vector3(rng.randf_range(- spread, spread), rng.randf() * 0.04,
			rng.randf_range(- spread, spread))
		var b:= live.spawn(p, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		if b != null:


			live.set_protected(b, true)
			b.freeze = frozen
			out.append(b)
	for i in SETTLE:
		await get_tree().process_frame
	return out


func _centroid(bodies: Array [RigidBody3D]) -> Vector3:
	var sum:= Vector3.ZERO
	var n:= 0
	for b in bodies:
		if is_instance_valid(b) and b.is_inside_tree():
			sum += b.global_position
			n += 1
	return sum / maxf(float(n), 1.0)


func _clear(bodies: Array [RigidBody3D]) -> void:
	for b in bodies:
		if is_instance_valid(b):
			world.live.set_protected(b, false)
			world.live.consume(b)


func _after_stroke() -> void:
	while player.broom.is_stroking():
		await get_tree().process_frame
	for i in AFTER:
		await get_tree().process_frame
