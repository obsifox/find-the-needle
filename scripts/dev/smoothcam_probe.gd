class_name DevSmoothCamProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 20

const DT:= 1.0 / 60.0


const CATCHUP_FRAMES:= 180


const EPS:= 0.0002

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame

	player.capture_mouse(true)
	var was_on: bool = Cfg.smooth_camera
	var was_amount: float = Cfg.smooth_camera_amount

	print("\n[smoothcam] off -- the game as it shipped")
	Cfg.smooth_camera = false
	_reset()
	var want:= 120.0 * Player.MOUSE_SENS * Cfg.mouse_sensitivity
	_look(-120.0, 0.0)
	_near("yaw lands on the same frame", player.rotation.y, want)
	_near("nothing is left owed", player._yaw_owed, 0.0)


	player._process(DT)
	_near("still there a frame later", player.rotation.y, want)

	print("\n[smoothcam] on -- lags, then arrives")
	Cfg.smooth_camera = true
	Cfg.smooth_camera_amount = 1.0
	_reset()
	_look(-120.0, 0.0)
	_near("nothing moves on the input frame", player.rotation.y, 0.0)
	player._process(DT)
	var after_one: float = player.rotation.y
	if absf(after_one) < EPS or absf(after_one) > absf(want) - EPS:
		_fail("one frame should be a fraction of the pan, got %.5f of %.5f"
			% [after_one, want])
	else:
		print("  ok   one frame moves part of the way (%.1f%%)"
			% [after_one / want * 100.0])
	for i in CATCHUP_FRAMES:
		player._process(DT)
	_near("the whole pan arrives", player.rotation.y, want)


	_reset()
	Cfg.smooth_camera_amount = 0.0
	_look(-120.0, 0.0)
	player._process(DT)
	var light: float = player.rotation.y
	if absf(light) > absf(after_one) + EPS:
		print("  ok   0%% smoothing is faster than 100%% (%.1f%% vs %.1f%%)"
			% [light / want * 100.0, after_one / want * 100.0])
	else:
		_fail("the slider does nothing: %.5f at 0%%, %.5f at 100%%" % [light, after_one])

	print("\n[smoothcam] switched off mid-pan")
	_reset()
	Cfg.smooth_camera_amount = 1.0
	_look(-120.0, 0.0)
	player._process(DT)
	Cfg.smooth_camera = false
	player._process(DT)
	_near("the debt is settled, not dropped", player.rotation.y, want)

	print("\n[smoothcam] the pitch limit")
	Cfg.smooth_camera = true
	Cfg.smooth_camera_amount = 1.0
	_reset()


	_look(0.0, -4000.0)
	for i in CATCHUP_FRAMES:
		player._process(DT)
	_near("a huge flick stops at the limit", player._pitch, Player.PITCH_LIMIT)
	_look(0.0, 400.0)
	for i in CATCHUP_FRAMES:
		player._process(DT)
	var back:= Player.PITCH_LIMIT - 400.0 * Player.MOUSE_SENS * Cfg.mouse_sensitivity
	_near("and comes straight back down", player._pitch, back)

	print("\n[smoothcam] invert look")


	Cfg.smooth_camera = false
	Cfg.invert_look_x = true
	_reset()
	_look(-120.0, 40.0)
	_near("inverted left and right turns the other way", player.rotation.y, - want)
	_near("and leaves up and down as it was", player._pitch,
		-40.0 * Player.MOUSE_SENS * Cfg.mouse_sensitivity)
	Cfg.invert_look_x = false
	Cfg.invert_look_y = true
	_reset()
	_look(-120.0, 40.0)
	_near("inverted up and down tips the other way", player._pitch,
		40.0 * Player.MOUSE_SENS * Cfg.mouse_sensitivity)
	_near("and leaves left and right as it was", player.rotation.y, want)
	Cfg.invert_look_y = false

	Cfg.smooth_camera = was_on
	Cfg.smooth_camera_amount = was_amount
	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _reset() -> void:
	player.rotation.y = 0.0
	player._pitch = 0.0
	player.head.rotation.x = 0.0
	player._yaw_owed = 0.0
	player._pitch_owed = 0.0


func _look(dx: float, dy: float) -> void:
	var mm:= InputEventMouseMotion.new()


	mm.relative = Vector2(dx, dy)
	mm.screen_relative = Vector2(dx, dy)
	player._unhandled_input(mm)


func _near(label: String, got: float, want: float) -> void:
	if absf(got - want) <= EPS:
		print("  ok   %s (%.5f)" % [label, got])
		return
	_fails += 1
	print("  FAIL %s: got %.5f, wanted %.5f" % [label, got, want])


func _fail(msg: String) -> void:
	_fails += 1
	print("  FAIL %s" % msg)
