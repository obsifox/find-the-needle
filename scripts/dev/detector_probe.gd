class_name DevDetectorProbe
extends Node


const STEP:= 0.5


const WALK_PAST:= 1.5


const WALK_MARGIN:= 0.4


const SWEEP_PITCH:= -35.0

const SETTLE:= 45


const MUFFLE_MIN:= 0.3

var world: Node3D
var player: Player

var _fail:= 0


var _walk_stop:= 1.2


func run() -> void:
	for i in SETTLE:
		await get_tree().process_frame


	Tech.grant_legacy()
	GameState.grant_tool("metal_detector")


	world.live.expose_uncovered = false
	player.select_hotbar_slot(Player.TOOL_SLOTS.find(Player.Tool.DETECTOR))


	player.detector.set_power(true)
	await get_tree().process_frame

	print("\n=== metal detector ===")
	print("  range %.2f m, hay costs %.1f m per metre of cover, a block costs %.0f%%"
		% [Tech.detector_range(), Cfg.DETECT_HAY_COST,
			100.0 * Cfg.DETECT_BLOCK_MUFFLE])
	if player.detector == null or not player.detector.is_active():
		print("    FAIL: the detector is not the tool in hand")
		_fail += 1
	else:
		await _pose_case()
		await _falloff_case()
		await _muffle_case()
		await _block_case()
		await _loose_case()
		await _depth_case()
	print("=== metal detector: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _pose_case() -> void:
	var det:= player.detector
	if det.visual == null:
		print("  pose: no model mounted")
		_fail += 1
		return
	_stand_at(Vector3(16.0, 0.0, -14.0), Vector3(-1, 0, 0))
	for i in 6:
		await get_tree().process_frame

	var xf:= det.visual.global_transform
	var tip:= xf * MetalDetector.HEAD_TIP
	var grip:= xf * MetalDetector.GRIP_END
	var eye:= player.camera.global_position
	var head_err:= tip.distance_to(det.coil_position())
	var span:= tip.distance_to(grip)


	var cam:= player.camera.global_transform.affine_inverse()
	var rise:= (cam * tip).y - (cam * grip).y
	var ahead:= (player.global_transform.affine_inverse() * tip).z

	print("  pose: head %.3f m off its mark, wand %.3f m long (model says %.3f)"
		% [head_err, span, MetalDetector.SHAFT_LEN])
	print("        head %.2f m below the eye, %.2f m in front, %.2f m over the grip"
		% [eye.y - tip.y, - ahead, rise])
	if head_err > 0.02:
		print("    FAIL: the mesh's search head is not where the reading is taken")
		_fail += 1
	if absf(span - MetalDetector.SHAFT_LEN) > 0.02:
		print("    FAIL: the model is being stretched or squashed by the fit")
		_fail += 1
	if rise < 0.2:
		print("    FAIL: the wand is not being carried head-up")
		_fail += 1
	if ahead > -0.4:
		print("    FAIL: the head is not out in front of the player")
		_fail += 1


	if tip.y >= eye.y:
		print("    FAIL: the head is above the eyeline even at a searching gaze")
		_fail += 1
	if tip.y - player.global_position.y < 0.2:
		print("    FAIL: the head is dragging on the floor")
		_fail += 1


	var was:= det.coil_position()
	player.set_look(player.rotation.y, deg_to_rad(SWEEP_PITCH - 25.0))
	for i in 6:
		await get_tree().process_frame
	var moved:= was.distance_to(det.coil_position())
	player.set_look(player.rotation.y, deg_to_rad(SWEEP_PITCH))
	for i in 6:
		await get_tree().process_frame
	print("        looking 25 degrees further down moves the head %.2f m" % moved)
	if moved < 0.2:
		print("    FAIL: the head does not follow where the player is looking")
		_fail += 1


	var flat:= det.coil_position() - player.global_position
	flat.y = 0.0
	_walk_stop = flat.length() + WALK_MARGIN


func _falloff_case() -> void:
	var at:= Vector3(16.0, 0.06, -14.0)
	_only_needle(at)
	var reach:= Tech.detector_range()

	var curve: PackedFloat32Array = PackedFloat32Array()
	var away:= reach + WALK_PAST
	while away >= _walk_stop:
		_stand_at(at + Vector3(away, 0.0, 0.0), Vector3(-1, 0, 0))
		curve.append(await _sample())
		away -= STEP

	print("  falloff (walking in from %.1f m to %.1f m):"
		% [reach + WALK_PAST, _walk_stop])
	var line:= ""
	for i in curve.size():
		line += "%.2f " % curve [i]
	print("    %s" % line.strip_edges())

	if curve [0] != 0.0:
		print("    FAIL: a needle %.1f m away past a %.1f m range is not silent"
			% [reach + WALK_PAST, reach])
		_fail += 1
	if curve [curve.size() - 1] <= 0.0:
		print("    FAIL: a needle %.1f m away on bare floor reads nothing" % _walk_stop)
		_fail += 1


	var started:= false
	for i in range(1, curve.size()):
		if curve [i] > 0.0:
			started = true
		if started and curve [i] < curve [i - 1] - 0.0001:
			print("    FAIL: the signal dipped between sample %d and %d (%.3f -> %.3f)"
				% [i - 1, i, curve [i - 1], curve [i]])
			_fail += 1
			break


func _muffle_case() -> void:
	var field: HayField = world.get("field") as HayField
	if field == null:
		print("  muffle: no hay field")
		_fail += 1
		return


	var col:= _deep_column(field)
	if col == Vector3.INF:
		print("  muffle: no column over 1.2 m anywhere in the pile, skipped")
		return
	var surface:= field.depth_floor_at(col.x, col.z)
	var buried:= Vector3(col.x, surface - 1.0, col.z)
	_only_needle(buried)


	_stand_at(Vector3(col.x + 2.0, 0.0, col.z), Vector3(-1, 0, 0))
	var covered:= await _sample()

	var d:= player.detector.coil_position().distance_to(buried)
	var reach:= Tech.detector_range()
	var bare:= maxf(1.0 - d / reach, 0.0)
	var cover:= maxf(surface - buried.y, 0.0)
	print("  muffle: coil %.2f m from a needle under %.2f m of hay" % [d, cover])
	print("          reads %.3f, would read %.3f with no hay term (%.0f%% lost)"
		% [covered, bare, 100.0 * (1.0 - covered / maxf(bare, 0.0001))])
	if bare <= 0.0:
		print("    FAIL: out of range even without hay, so there is nothing to compare")
		_fail += 1
		return
	if covered >= bare:
		print("    FAIL: hay is not muffling anything")
		_fail += 1
	elif (1.0 - covered / bare) < MUFFLE_MIN:
		print("    FAIL: %.2f m of hay only cost %.0f%%, wanted at least %.0f%%"
			% [cover, 100.0 * (1.0 - covered / bare), 100.0 * MUFFLE_MIN])
		_fail += 1


func _block_case() -> void:
	var props: PropManager = world.get("props") as PropManager
	if props == null:
		print("  block: no prop manager")
		_fail += 1
		return


	_only_needle(Vector3(90.0, 0.0, 90.0))

	var at:= Vector3(16.0, 0.0, -14.0)
	var bale:= props.spawn("hay_bale", Transform3D(Basis(), at + Vector3.UP * 0.3))
	if bale == null:
		print("  block: a bale would not spawn")
		_fail += 1
		return
	bale.freeze = true
	bale.needle_index = 3

	_stand_at(at + Vector3(1.5, 0.0, 0.0), Vector3(-1, 0, 0))
	var loaded:= await _sample()
	var near_d:= player.detector.coil_position().distance_to(bale.global_position)

	bale.needle_index = -1
	var empty:= await _sample()

	bale.needle_index = 3
	var far:= Tech.detector_range() * (1.0 + Cfg.DETECT_BLOCK_MUFFLE) + 1.0
	_stand_at(at + Vector3(far, 0.0, 0.0), Vector3(-1, 0, 0))
	var distant:= await _sample()

	print("  block: coil %.2f m from a bale, loaded %.3f, emptied %.3f"
		% [near_d, loaded, empty])
	print("         the same loaded bale from %.1f m reads %.3f" % [far, distant])
	if loaded <= 0.0:
		print("    FAIL: a needle inside a bale at arm's length reads nothing")
		_fail += 1
	if empty > 0.0:
		print("    FAIL: an EMPTY bale reads %.3f, so the tool is hearing hay" % empty)
		_fail += 1
	if distant > 0.0:
		print("    FAIL: a loaded bale is audible from %.1f m, so nothing is muffling it"
			% far)
		_fail += 1

	props.remove(bale)
	await get_tree().process_frame


func _loose_case() -> void:
	var live: LiveStrandManager = world.get("live") as LiveStrandManager
	if live == null:
		print("  loose: no strand manager")
		_fail += 1
		return
	_only_needle(Vector3(90.0, 0.0, 90.0))

	var at:= Vector3(16.0, 0.06, -14.0)
	var body:= live.reveal_needle(-1, at)
	if body == null:
		print("  loose: a needle body would not spawn")
		_fail += 1
		return
	body.freeze = true
	body.global_position = at

	_stand_at(at + Vector3(1.5, 0.0, 0.0), Vector3(-1, 0, 0))
	var near:= await _sample()
	var near_d:= player.detector.coil_position().distance_to(body.global_position)

	var far:= Tech.detector_range() + 1.0
	_stand_at(at + Vector3(far, 0.0, 0.0), Vector3(-1, 0, 0))
	var distant:= await _sample()

	_stand_at(at + Vector3(1.5, 0.0, 0.0), Vector3(-1, 0, 0))
	live.consume_needle(body)
	var gone:= await _sample()

	print("  loose: coil %.2f m from a dug needle reads %.3f, from %.1f m %.3f, collected %.3f"
		% [near_d, near, far, distant, gone])
	if near <= 0.0:
		print("    FAIL: a loose needle at arm's length reads nothing")
		_fail += 1
	if distant > 0.0:
		print("    FAIL: a loose needle is audible from %.1f m, past the range" % far)
		_fail += 1
	if gone > 0.0:
		print("    FAIL: a collected needle still reads %.3f" % gone)
		_fail += 1


func _deep_column(field: HayField) -> Vector3:
	var best:= Vector3.INF
	var best_h:= 1.2
	for ix in range(-12, 13):
		for iz in range(-12, 13):
			var x:= float(ix) * 0.5
			var z:= float(iz) * 0.5
			var h:= field.depth_floor_at(x, z)
			if h > best_h:
				best_h = h
				best = Vector3(x, 0.0, z)
	return best


const DEPTH_MIN:= 0.5
const DEPTH_MAX:= 4.0


const DEPTH_EPS:= 0.05


func _depth_case() -> void:
	var field: HayField = world.get("field") as HayField
	if field == null:
		return
	var col:= _deep_column(field)
	if col == Vector3.INF:
		print("  depth: no column deep enough to bury in, skipped")
		return
	var surface:= field.depth_floor_at(col.x, col.z)

	print("  depth it answers through, by coil rank:")
	var ranks:= TechTree.max_rank("detector_coil")
	var last:= 0.0
	for r in ranks + 1:
		Tech.ranks ["detector_coil"] = r
		var d:= await _max_cover(col, surface)
		print("    rank %d  range %5.2f m  hears through %.2f m of hay"
			% [r, Tech.detector_range(), d])
		if r == 0 and d < 0.6:
			print("      FAIL: a freshly bought detector cannot hear through %.2f m,"
				% d)
			print("            which is less than one scoop of cover. It would read as broken.")
			_fail += 1
		if r > 0 and d <= last + 0.01:
			print("      FAIL: rank %d buys no extra depth over rank %d" % [r, r - 1])
			_fail += 1
		last = d
	Tech.ranks ["detector_coil"] = 0


func _max_cover(col: Vector3, surface: float) -> float:


	_stand_at(Vector3(col.x, 0.0, col.z), Vector3(-1, 0, 0))
	var lo:= DEPTH_MIN
	var hi:= DEPTH_MAX
	while hi - lo > DEPTH_EPS:
		var mid:= (lo + hi) * 0.5
		_only_needle(Vector3(col.x, surface - mid, col.z))
		if await _sample() > 0.0:
			lo = mid
		else:
			hi = mid
	return lo


func _only_needle(at: Vector3) -> void:
	GameState.needle_positions = PackedVector3Array([at])
	GameState.needle_taken = PackedByteArray([0])
	GameState.needle_type = PackedByteArray([0])


func _stand_at(pos: Vector3, facing: Vector3) -> void:
	var field: HayField = world.get("field") as HayField
	var y:= field.height_at(pos.x, pos.z) if field != null else 0.0
	player.global_position = Vector3(pos.x, y, pos.z)
	player.velocity = Vector3.ZERO
	player.look_at(player.global_position + facing.normalized(), Vector3.UP)


	player.rotation.x = 0.0
	player.rotation.z = 0.0


	player.set_look(player.rotation.y, deg_to_rad(SWEEP_PITCH))


func _sample() -> float:
	for i in 8:
		await get_tree().physics_frame
	return player.detector.signal_strength()
