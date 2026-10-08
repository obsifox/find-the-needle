class_name DevClipProbe
extends Node


const FPS:= 60.0


const SETTLE:= 40

var world: Node3D
var player: Player

var _clip:= ""


func run(clip: String) -> void:
	_clip = clip
	call_deferred("_run")


func _run() -> void:


	world.block_save = true
	Cfg.perf_scale = 1.0
	Tech.grant_legacy()
	GameState.add_money(50000.0)
	player.capture_mouse(true)


	Cfg.set_no_hud(false)

	for i in SETTLE:
		await get_tree().process_frame

	match _clip:
		"bucket_to_belt":
			await _bucket_to_belt()
		"barrow_to_belt":
			await _barrow_to_belt()
		_:
			push_error("[clip] unknown clip '%s'" % _clip)


	await _hold(0.6)
	get_tree().quit(0)


func _bucket_to_belt() -> void:
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var belt_a:= Vector3(13.0, lift, -4.0)
	var belt_b:= Vector3(13.0, lift, 3.0)
	world.builds.add_conveyor(belt_a, belt_b)

	var bucket:= await _spawn_full("bucket", Vector3(11.4, 1.0, 1.8))
	if bucket == null:
		return
	await _hold(0.5)


	_place(Vector3(10.4, 0.4, 3.8), bucket.global_position)
	await _hold(0.8)
	await _walk(Vector3(11.1, 0.4, 3.0), bucket.global_position, 1.1)
	await _pick(bucket)
	await _hold(0.5)


	var down_run:= Vector3(13.0, lift + 0.1, -1.4)
	await _walk(Vector3(11.7, 0.4, 1.4), down_run, 1.5)
	await _hold(0.4)
	await _pour(2.6)

	await _turn(belt_a + Vector3(0.0, 0.35, 0.0), 1.2)
	await _hold(1.4)


func _barrow_to_belt() -> void:
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var belt_a:= Vector3(13.0, lift, -4.0)
	var belt_b:= Vector3(13.0, lift, 3.0)
	world.builds.add_conveyor(belt_a, belt_b)

	var barrow:= await _spawn_full("wheelbarrow", Vector3(11.4, 1.0, 1.8))
	if barrow == null:
		return

	_place(Vector3(10.4, 0.4, 3.8), barrow.global_position)
	await _hold(0.8)
	await _walk(Vector3(11.1, 0.4, 3.0), barrow.global_position, 1.2)
	await _pick(barrow)
	await _hold(0.5)
	await _walk(Vector3(11.7, 0.4, 1.4), Vector3(13.0, lift + 0.1, -1.4), 1.6)
	await _hold(0.4)
	await _pour(3.4)
	await _turn(belt_a + Vector3(0.0, 0.3, 0.0), 1.2)
	await _hold(1.6)


func _pick(item: Carryable) -> void:


	await _turn(item.global_position, 0.35)
	var took:= player.carry.try_pick()
	var held:= player.carry.held()
	if not took or held != item:
		push_error("[clip] %s: pick FAILED (took=%s held=%s) at %.2f m; eye %s dir %s item %s reach %.2f"
			% [_clip, str(took), str(held), player.global_position.distance_to(
				item.global_position), str(player.eye_position().snappedf(0.01)),
				str(player.look_direction().snappedf(0.01)),
				str(item.global_position.snappedf(0.01)), Tech.carry_reach()])
	else:
		print("[clip] %s: carrying %s" % [_clip, item.name])


func _spawn_full(id: String, at: Vector3) -> Carryable:
	var item: Carryable = world.props.spawn(id, Transform3D(Basis.IDENTITY, at))
	if item == null:
		push_error("[clip] could not spawn '%s'" % id)
		return null
	var box:= item as HayContainer
	if box != null:
		box.stored = box.capacity()


	for i in SETTLE:
		await get_tree().physics_frame
	return item


func _aim(from: Vector3, target: Vector3) -> Vector2:
	var d:= target - (from + Vector3.UP * (player.eye_position().y - player.global_position.y))
	var flat:= Vector2(d.x, d.z).length()
	return Vector2(atan2(- d.x, - d.z), atan2(d.y, maxf(flat, 0.001)))


func _place(at: Vector3, target: Vector3) -> void:
	player.global_position = at
	var a:= _aim(at, target)
	player.rotation = Vector3(0.0, a.x, 0.0)
	if player.head != null:
		player.head.rotation.x = a.y


func _walk(to: Vector3, target: Vector3, seconds: float) -> void:
	var from:= player.global_position
	var a0:= Vector2(player.rotation.y, player.head.rotation.x if player.head else 0.0)
	var a1:= _aim(to, target)

	a1.x = a0.x + wrapf(a1.x - a0.x, - PI, PI)
	var frames:= int(seconds * FPS)
	for f in frames:
		var t:= smoothstep(0.0, 1.0, float(f + 1) / float(frames))
		player.global_position = from.lerp(to, t)
		player.rotation = Vector3(0.0, lerpf(a0.x, a1.x, t), 0.0)
		if player.head != null:
			player.head.rotation.x = lerpf(a0.y, a1.y, t)
		await get_tree().process_frame


func _turn(target: Vector3, seconds: float) -> void:
	await _walk(player.global_position, target, seconds)


func _hold(seconds: float) -> void:
	for f in int(seconds * FPS):
		await get_tree().process_frame


func _pour(seconds: float) -> void:
	Input.action_press("carry_rotate")
	var frames:= int(seconds * FPS)
	for f in frames:


		player.carry.rotate_input(Vector2(0.0, 4.5))
		await get_tree().process_frame
	Input.action_release("carry_rotate")

	await _hold(0.5)
