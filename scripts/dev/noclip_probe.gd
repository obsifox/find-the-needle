class_name DevNoclipProbe
extends Node


const START:= Vector3(13.0, 0.5, 10.0)


const WALL_AHEAD:= 3.0
const WALL_PAST:= 2.0

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()


func _log(msg: String) -> void:
	print("[noclip] %s" % msg)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	await _settle(10)

	_check_default()
	await _check_hover()
	await _check_stance()
	await _check_walls()
	await _check_void()
	await _check_speeds()
	await _check_landing()
	_check_menu()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check_default() -> void:
	if player.noclip:
		_fails.append("started the run already flying")
	if _shape().disabled:
		_fails.append("collider starts disabled")


func _check_hover() -> void:
	await _enter()
	if not _shape().disabled:
		_fails.append("collider still on with noclip enabled")
	var was:= player.global_position
	await _settle(60)
	var drift:= player.global_position.distance_to(was)
	if drift > 0.01:
		_fails.append("drifted %.3f m in a second of hovering" % drift)


	Input.action_press("jump")
	await _settle(40)
	Input.action_release("jump")
	var up:= player.global_position.y - was.y
	if up < 1.0:
		_fails.append("jump lifted only %.2f m in two thirds of a second" % up)
	Input.action_press("crouch")
	await _settle(60)
	Input.action_release("crouch")
	if player.global_position.y >= was.y:
		_fails.append("crouch did not descend past where the climb started")
	await _leave()


func _check_stance() -> void:
	await _enter()
	Input.action_press("crouch")
	await _settle(60)
	_near("eye stayed standing while descending", player.head.position.y,
		Player.EYE_HEIGHT, 0.02)
	_near("stance stayed standing", player.crouch_amount(), 0.0, 0.02)
	Input.action_release("crouch")
	await _leave()


func _check_walls() -> void:
	_reset()
	var wall:= StaticBody3D.new()
	wall.collision_layer = Cfg.L_WORLD
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.4)
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)

	wall.global_position = START + Vector3(0.0, 1.0, - WALL_AHEAD)
	await _settle(4)


	Input.action_press("move_forward")
	await _settle(120)
	Input.action_release("move_forward")
	var walked:= START.z - player.global_position.z
	if walked >= WALL_AHEAD:
		_fails.append("walked %.2f m through a wall %.2f m away -- the slab is "
			% [walked, WALL_AHEAD] + "not solid, so the flight proves nothing")

	await _enter()
	_reset_position()
	Input.action_press("move_forward")
	await _settle(120)
	Input.action_release("move_forward")
	var flew:= START.z - player.global_position.z
	if flew < WALL_AHEAD + WALL_PAST:
		_fails.append("flew only %.2f m into a wall %.2f m away"
			% [flew, WALL_AHEAD])
	await _leave()
	wall.queue_free()
	await _settle(4)


func _check_void() -> void:
	await _enter()
	player.global_position = Vector3(START.x, Player.VOID_Y - 5.0, START.z)
	await _settle(30)
	if player.global_position.y > Player.VOID_Y:
		_fails.append("respawned out of the void at y=%.1f -- the fly cannot go "
			% player.global_position.y + "under the shed")
	await _leave()


func _check_speeds() -> void:
	await _enter()
	var base:= await _peak(false)
	var fast:= await _peak(true)
	_log("fly speeds  base=%.2f sprint=%.2f" % [base, fast])
	_near("base fly speed", base, Player.FLY, 0.6)
	_near("sprint fly speed", fast, Player.FLY_SPRINT, 1.5)
	await _leave()


func _check_landing() -> void:
	await _enter()
	player.global_position = START + Vector3.UP * 4.0
	await _settle(10)
	await _leave()
	await _settle(180)
	if not player.is_on_floor():
		_fails.append("never landed after leaving noclip (y=%.2f)"
			% player.global_position.y)
	if _shape().disabled:
		_fails.append("collider left disabled after leaving noclip")


func _check_menu() -> void:
	var menu: DebugMenu = world.debug_menu
	if menu == null:
		_fails.append("no debug menu was built -- Cfg.debug_on said no")
		return
	var button:= _find_button(menu, "Noclip")
	if button == null:
		_fails.append("no noclip button in the debug menu")
		return
	button.pressed.emit()
	if not player.noclip:
		_fails.append("the menu button did not turn noclip on")
	if button.text.find("ON") < 0:
		_fails.append("button still reads '%s' with noclip on" % button.text)
	button.pressed.emit()
	if player.noclip:
		_fails.append("the menu button did not turn noclip off again")
	if button.text.find("OFF") < 0:
		_fails.append("button still reads '%s' with noclip off" % button.text)


func _peak(sprint: bool) -> float:
	_reset_position()
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	await _settle(60)
	var top:= 0.0
	for i in 20:
		await get_tree().physics_frame
		top = maxf(top, player.velocity.length())
	for a in ["move_forward", "sprint"]:
		Input.action_release(a)
	await _settle(6)
	return top


func _enter() -> void:
	_reset()
	player.set_noclip(true)


	await _settle(4)


func _leave() -> void:
	player.set_noclip(false)
	await _settle(4)


func _reset() -> void:
	for a in ["move_forward", "sprint", "jump", "crouch"]:
		Input.action_release(a)
	_reset_position()


func _reset_position() -> void:
	player.global_position = START
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _shape() -> CollisionShape3D:
	return player.get_node("Collider") as CollisionShape3D


func _find_button(node: Node, prefix: String) -> Button:
	var b:= node as Button
	if b != null and b.text.begins_with(prefix):
		return b
	for child in node.get_children():
		var found:= _find_button(child, prefix)
		if found != null:
			return found
	return null


func _near(what: String, got: float, want: float, tol: float) -> void:
	if absf(got - want) > tol:
		_fails.append("%s: got %.3f, wanted %.3f" % [what, got, want])
