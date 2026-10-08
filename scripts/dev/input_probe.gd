class_name DevInputProbe
extends Node


const LOG:= "res://input_probe.log"


const START:= Vector3(400.0, 0.6, 410.0)
const PAD:= 40.0

const LEASH:= 12.0

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()


func _log(msg: String) -> void:
	print("[input] %s" % msg)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(msg)
	f.close()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	_log("start")
	_lay_pad()
	_reset()
	await _settle(30)
	if not player.is_on_floor():
		_fails.append("the runner never landed on its own pad")

	_log("speeds")
	await _check_speeds()
	_log("stuck crouch")
	await _check_stuck_crouch()
	_log("stuck legs")
	await _check_stuck_legs()
	_log("still usable")
	await _check_still_usable()
	_log("new default on a chosen key")
	_check_default_yields()
	_log("done")

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check_speeds() -> void:
	var plain:= await _peak_speed(30, false)
	var crouched:= await _peak_speed(30, true)
	_log("speeds  plain=%.2f crouch=%.2f" % [plain, crouched])
	_near("base speed", plain, Player.SPEED * Tech.move_speed_scale(), 0.3)
	_near("crouch speed", crouched, Tech.crouch_speed(), 0.3)
	if crouched >= plain:
		_fails.append("crouch (%.2f) is not slower than the base pace (%.2f)"
			% [crouched, plain])


func _check_stuck_crouch() -> void:
	_reset()
	Input.action_press("move_forward")
	Input.action_press("crouch")
	await _settle(30)
	if not Input.is_action_pressed("crouch"):
		_fails.append("crouch did not register as held at all")
		return

	_lose_focus()
	if Input.is_action_pressed("crouch"):
		_fails.append("crouch survived the focus loss, which is the reported bug")


	Input.action_press("move_forward")
	var speed:= await _peak(30)
	_log("after focus loss  speed=%.2f" % speed)
	_near("back to the base pace", speed, Player.SPEED * Tech.move_speed_scale(), 0.3)
	_release()


func _check_stuck_legs() -> void:
	_reset()
	Input.action_press("move_forward")
	await _settle(30)
	_lose_focus()
	if Input.is_action_pressed("move_forward"):
		_fails.append("move_forward survived the focus loss")

	await _settle(40)
	var moving:= Vector2(player.velocity.x, player.velocity.z).length()
	if moving > 0.1:
		_fails.append("still moving at %.2f m/s after the focus loss" % moving)


func _check_still_usable() -> void:
	_reset()
	_lose_focus()
	Input.action_press("move_forward")
	Input.action_press("crouch")
	var speed:= await _peak(30)
	_log("crouch after a focus loss  speed=%.2f" % speed)
	_near("crouch still works once focus is back", speed, Tech.crouch_speed(), 0.3)
	_release()


func _check_default_yields() -> void:
	var kept: Dictionary = InputSetup._override.duplicate()
	var middle:= InputSetup.spec_from_event(InputSetup.mouse_event(MOUSE_BUTTON_MIDDLE))
	var wheel:= InputSetup.spec_from_event(InputSetup.mouse_event(MOUSE_BUTTON_WHEEL_UP))
	var v_key:= InputSetup.spec_from_event(InputSetup.key_event(KEY_V))


	InputSetup._override = { "jump": middle }
	InputSetup._yield_defaults_to_choices()
	if not InputSetup.specs("pick_build").is_empty():
		_fails.append("pick_build kept the middle button jump was put on: %s"
			% [InputSetup.specs("pick_build")])
	if InputSetup.specs("jump") != PackedStringArray([middle]):
		_fails.append("jump lost the middle button it was bound to")


	InputSetup._override = { "sprint": v_key }
	InputSetup._yield_defaults_to_choices()
	if InputSetup.specs("build_further") != PackedStringArray([wheel]):
		_fails.append("build_further should be left on the wheel, has %s"
			% [InputSetup.specs("build_further")])


	InputSetup._override = { }
	InputSetup._yield_defaults_to_choices()
	if not InputSetup.is_default("pick_build"):
		_fails.append("pick_build moved off its default with nothing chosen")

	InputSetup._override = kept
	InputSetup.apply()


func _lay_pad() -> void:
	var pad:= StaticBody3D.new()
	pad.collision_layer = Cfg.L_BUILD
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(PAD, 1.0, PAD)
	cs.shape = box
	pad.add_child(cs)
	world.add_child(pad)
	pad.global_position = Vector3(START.x, -0.5, START.z)


	player.keep_in_yard = false


func _lose_focus() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)


func _peak_speed(warmup: int, crouch: bool) -> float:
	_reset()
	Input.action_press("move_forward")
	if crouch:
		Input.action_press("crouch")
	var peak:= await _peak(warmup)
	_release()
	await _settle(10)
	return peak


func _peak(warmup: int) -> float:
	await _settle(warmup)
	var peak:= 0.0
	for i in 20:
		await get_tree().physics_frame
		_leash()
		peak = maxf(peak, Vector2(player.velocity.x, player.velocity.z).length())
	return peak


func _release() -> void:
	for a in ["move_forward", "sprint", "crouch"]:
		Input.action_release(a)


func _reset() -> void:
	_release()
	player.global_position = START
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _leash() -> void:
	var here:= player.global_position
	if Vector2(here.x - START.x, here.z - START.z).length() > LEASH:
		player.global_position = Vector3(START.x, here.y, START.z)


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame
		_leash()


func _near(what: String, got: float, want: float, tol: float) -> void:
	if absf(got - want) > tol:
		_fails.append("%s: got %.3f, wanted %.3f" % [what, got, want])
