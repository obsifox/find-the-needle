class_name DevEyeSmoothProbe
extends Node


const LEG:= 600


const SETTLE_MAX:= 3000
const STEADY:= 120


const STEADY_MS:= 25.0


const SPAN:= 8.0
const MARGIN:= 2.0

var world: Node3D
var player: Player

var _axis:= Vector3.RIGHT
var _t:= PackedFloat64Array()
var _x:= PackedFloat64Array()


var _b:= PackedFloat64Array()
var _f:= PackedFloat64Array()
var _p:= PackedInt64Array()


var _c:= PackedFloat64Array()
var _s:= PackedFloat64Array()


static var trace:= "--eyetrace" in OS.get_cmdline_user_args()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)

	process_priority = 500
	if player == null:
		print("EYESMOOTH: no player")
		get_tree().quit(1)
		return


	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_tree().paused = false
	await _settle()
	_pick_axis()
	print("EYESMOOTH: physics %d Hz, walking at %.1f m/s, %d frames a leg"
		% [Engine.physics_ticks_per_second, Player.SPEED, LEG])
	print("  a stepping eye strays half a step of travel: %.0f mm"
		% (Player.SPEED / float(Engine.physics_ticks_per_second) * 500.0))
	print("%-18s %8s %8s %8s %9s %9s %9s %9s" % ["leg", "frames", "fps", "m/s",
		"stray_mm", "worst_mm", "body_mm", "frame_ms"])


	await _leg("warm up", false, 0.5, 1.0, false)
	var dir:= -1.0
	for pass_no in 2:
		for leg: Array in [["as it was", false, 0.5], ["jitter fix off", false, 0.0],
				["smooth eye", true, 0.0], ["smooth, fix on", true, 0.5]]:
			await _leg(leg [0], leg [1], leg [2], dir)
			dir = - dir
	player.scripted = false
	get_tree().quit()


func _settle() -> void:
	var steady:= 0
	var last:= Time.get_ticks_usec()
	for i in SETTLE_MAX:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		var ms:= float(now - last) * 0.001
		last = now
		steady = steady + 1 if ms <= STEADY_MS else 0
		if steady >= STEADY:
			print("EYESMOOTH: yard settled after %d frames, %.1f ms a frame"
				% [i + 1, ms])
			return
	print("EYESMOOTH: yard never settled in %d frames, measuring anyway"
		% SETTLE_MAX)


func _pick_axis() -> void:
	var eye:= player.eye_position()
	var space:= player.get_world_3d().direct_space_state
	var best:= -1.0
	for axis in [Vector3.RIGHT, Vector3.BACK]:
		var both:= 1000000000.0
		for s in [1.0, -1.0]:
			var to: Vector3 = eye + axis * s * 30.0
			var q:= PhysicsRayQueryParameters3D.create(eye, to)
			q.collision_mask = Cfg.L_WORLD
			q.collide_with_areas = false
			var hit:= space.intersect_ray(q)
			var d: float = 30.0 if hit.is_empty() else eye.distance_to(hit ["position"] as Vector3)
			both = minf(both, d)
		if both > best:
			best = both
			_axis = axis
	print("EYESMOOTH: walking along %s, %.1f m of room either way"
		% [_axis, best])


func _leg(label: String, smooth: bool, jitter: float, sign: float,
		report:= true) -> void:
	Player.eye_smoothing = smooth
	Engine.physics_jitter_fix = jitter
	var dir: Vector3 = _axis * sign
	var room:= _room(dir)
	player.scripted = true
	player.scripted_move = dir
	player.scripted_speed = Player.SPEED
	_t.clear()
	_x.clear()
	_b.clear()
	_f.clear()
	_p.clear()
	_c.clear()
	_s.clear()
	var from:= player.global_position
	var run_up: float = room * 0.25
	var frames:= 0
	var ticks0:= Engine.get_physics_frames()
	while frames < LEG:


		await RenderingServer.frame_pre_draw
		frames += 1
		var gone:= player.global_position.distance_to(from)


		if gone < run_up or player.velocity.length() < Player.SPEED * 0.98:
			continue
		if gone > room:
			break
		_t.append(float(Time.get_ticks_usec()) * 1e-06)
		_x.append(player.eye_position().dot(dir))
		_b.append(player.global_position.dot(dir))
		_f.append(Engine.get_physics_interpolation_fraction())
		_p.append(Engine.get_physics_frames())
		_c.append((player.head.global_transform.basis * player.camera.position).dot(dir) * 1000.0)
		_s.append((player._eye_curr - player._eye_prev).length() * 1000.0)
	var walked:= player.global_position.distance_to(from)
	var ticks:= Engine.get_physics_frames() - ticks0
	player.scripted_move = Vector3.ZERO
	if report:
		_report(label)
	if walked < 1.0:
		print("  WARNING: the player only moved %.2f m on that leg, %d physics steps, vel %.2f"
			% [walked, ticks, player.velocity.length()])

	for i in 60:
		await get_tree().process_frame


func _room(dir: Vector3) -> float:
	var eye:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(eye, eye + dir * 40.0)
	q.collision_mask = Cfg.L_WORLD
	q.collide_with_areas = false
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	var d:= 40.0
	if not hit.is_empty():
		d = eye.distance_to(hit ["position"] as Vector3)
	return clampf(d - MARGIN, 1.0, SPAN)


func _report(label: String) -> void:
	var n:= _t.size()
	if n < 30:
		print("%-18s too few frames (%d)" % [label, n])
		return
	var eye:= _fit(_x)
	var body:= _fit(_b)
	var span: float = _t [n - 1] - _t [0]

	var gaps:= []
	for i in range(1, n):
		gaps.append((_t [i] - _t [i - 1]) * 1000.0)
	gaps.sort()
	var median: float = gaps [gaps.size() / 2]
	print("%-18s %8d %8.0f %8.2f %9.1f %9.1f %9.1f %9.2f" % [label, n,
		float(n) / maxf(span, 1e-06), absf(eye [0]), eye [1], eye [2], body [1],
		median])
	if not trace:
		return
	print("    %6s %7s %6s %9s %9s %8s %8s"
		% ["ms", "step", "frac", "eye_mm", "body_mm", "off_mm", "stp_mm"])
	for i in mini(n, 26):
		print("    %6.1f %7d %6.3f %9.1f %9.1f %8.1f %8.1f" % [
			(_t [i] - _t [0]) * 1000.0, _p [i] - _p [0], _f [i],
			(_x [i] - (eye [3] + eye [0] * (_t [i] - _t [0]))) * 1000.0,
			(_b [i] - (body [3] + body [0] * (_t [i] - _t [0]))) * 1000.0,
			_c [i], _s [i]])


func _fit(x: PackedFloat64Array) -> Array:
	var n:= _t.size()
	var t0: float = _t [0]
	var st:= 0.0
	var sx:= 0.0
	for i in n:
		st += _t [i] - t0
		sx += x [i]
	var mt:= st / n
	var mx:= sx / n
	var num:= 0.0
	var den:= 0.0
	for i in n:
		var dt:= (_t [i] - t0) - mt
		num += dt * (x [i] - mx)
		den += dt * dt
	var speed: float = 0.0 if den <= 0.0 else num / den
	var sum2:= 0.0
	var worst:= 0.0
	for i in n:
		var r: float = x [i] - (mx + speed * ((_t [i] - t0) - mt))
		sum2 += r * r
		worst = maxf(worst, absf(r))
	return [speed, sqrt(sum2 / n) * 1000.0, worst * 1000.0, mx - speed * mt]
