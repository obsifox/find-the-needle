class_name DevCrustHealProbe
extends Node


const R:= 0.2


const PLUCKS:= 10


const SCOOP_N:= 6


const SCOOP_ROUNDS:= 10


const TOLERANCE:= 0.2
const MIN_SLACK:= 3


const FLUSH_FRAMES:= 90

var world: Node3D
var player: Player
var field: HayField

var _fails:= 0


func run() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)


	var want: int = int(Cfg.PRESETS [Cfg.Quality.HIGH] ["strands_per_cell"])
	if Cfg.crust_strands_per_cell != want:
		Cfg.crust_strands_per_cell = want
		field.rebuild_density()
	await get_tree().process_frame

	print("\n=== does the crust grow back? ===")


	await _leg("hand pluck x%d" % PLUCKS, _pick_patch(0.0), _pluck)
	await _leg("part scoop x%d, %d times" % [SCOOP_N, SCOOP_ROUNDS], _pick_patch(3.0), _scoop)

	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _pick_patch(z: float) -> Vector3:
	for step in 24:
		var x:= 7.5 - step * 0.25
		var h:= field.height_at(x, z)
		if h > 1.2:
			return Vector3(x, h, z)
	return Vector3.INF


func _stand_at(p: Vector3) -> void:
	var back:= Vector3(1.0, 0.0, 0.0) * 0.9
	player.global_position = p + back - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, PI * 0.5, 0.0)


func _count(p: Vector3) -> int:
	return field.count_in_radius(p, R)


func _pluck(p: Vector3) -> int:
	var n:= 0
	for i in PLUCKS:
		if not field.pluck_at(p, R).is_empty():
			n += 1
	return n


func _scoop(p: Vector3) -> int:
	var n:= 0
	for i in SCOOP_ROUNDS:
		var taken:= field.take_in_radius(p, Cfg.SCOOP_RADIUS, SCOOP_N)
		n += taken.size()
		GameState.remove_hay(float(taken.size()))


		if i + 1 < SCOOP_ROUNDS:
			await get_tree().process_frame
	return n


func _leg(label: String, p: Vector3, take: Callable) -> void:
	print("\n-- %s --" % label)
	if p == Vector3.INF:
		print("  FAIL  no patch of pile deep enough to test on")
		_fails += 1
		return


	_stand_at(p)
	for i in 20:
		await get_tree().process_frame

	var before:= _count(p)
	var h0:= field.height_at(p.x, p.z)

	var took: int = await take.call(p)


	var hole:= _count(p)
	for i in FLUSH_FRAMES:
		await get_tree().process_frame
	var after:= _count(p)
	var h1:= field.height_at(p.x, p.z)

	var floor_count:= before - maxi(MIN_SLACK, int(took * TOLERANCE))
	print("  patch at (%.2f, %.2f), %.2f m of pile under it" % [p.x, p.z, h0])
	print("  took %d strands; patch held %d, dropped to %d, settled at %d"
		% [took, before, hole, after])
	print("  surface %.4f m -> %.4f m (%.1f mm)" % [h0, h1, (h0 - h1) * 1000.0])
	if took <= 0:
		print("  FAIL  nothing was taken -- this leg tested nothing")
		_fails += 1
	elif hole >= before:
		print("  FAIL  the take left no hole, so there is nothing to heal")
		_fails += 1
	elif after < floor_count:
		print("  FAIL  %d strands never came back (floor %d)"
			% [before - after, floor_count])
		_fails += 1
	else:
		print("  ok    the patch is back to %d of %d" % [after, before])
