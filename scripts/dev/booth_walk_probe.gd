class_name DevBoothWalkProbe
extends Node


const FACE_Z:= 1.32
const BACK_Z:= -0.6

const DECK_Y:= 0.19


const START_Z:= 2.3
const TARGET_Z:= 0.4


const DOOR_X:= 1.6

const WALL_X:= -0.6

const STEPS:= 220
const SPEED:= 2.6
const GRAVITY:= 18.0

var world: Node3D
var player: Player


var shots:= ""

var _fails:= 0


func run() -> void:
	world.block_save = true
	var stand: HaySellingStand = world.stand
	if stand == null:
		push_error("DevBoothWalkProbe: the world has no selling stand")
		get_tree().quit(1)
		return

	print("\n-- through the doorway --")
	var a:= await _walk(stand, DOOR_X)
	if a.z < FACE_Z and a.z > BACK_Z:
		print("  ok    got in: local z %.2f, standing at y %.2f" % [a.z, a.y])
		if absf(a.y - DECK_Y) > 0.12:
			_fail("in, but not on the deck: y %.2f, deck is %.2f" % [a.y, DECK_Y])
	else:
		_fail("blocked at z %.2f, never got past the counter face at %.2f" % [a.z, FACE_Z])

	print("\n-- at the counter, where there is no door --")
	var b:= await _walk(stand, WALL_X)
	if b.z >= FACE_Z:
		print("  ok    stopped outside: local z %.2f" % b.z)
	else:
		_fail("walked through the counter at x %.2f: ended at z %.2f" % [WALL_X, b.z])

	if shots != "":
		await _photograph(stand)

	print("")
	if _fails > 0:
		print("[probe] %d FAILURE(S)" % _fails)
	else:
		print("[probe] booth walk ok")
	get_tree().quit(1 if _fails > 0 else 0)


func _walk(stand: HaySellingStand, x: float) -> Vector3:
	player.velocity = Vector3.ZERO
	player.global_position = stand.to_global(Vector3(x, 0.55, START_Z))
	await get_tree().physics_frame

	var step:= 1.0 / float(Engine.physics_ticks_per_second)
	var aim:= stand.to_global(Vector3(x, 0.0, TARGET_Z))
	var vy:= 0.0
	for i in STEPS:


		vy = maxf(vy - GRAVITY * step, -12.0)
		var here:= player.global_position
		var flat:= Vector3(aim.x - here.x, 0.0, aim.z - here.z)
		if flat.length() > 0.05:
			flat = flat.normalized() * SPEED * step
		else:
			flat = Vector3.ZERO
		var hit:= player.move_and_collide(flat + Vector3.UP * vy * step)
		if hit != null:
			var n:= hit.get_normal()


			if n.y > cos(player.floor_max_angle):
				vy = 0.0
			player.move_and_collide(hit.get_remainder().slide(n))
		await get_tree().physics_frame
	return stand.to_local(player.global_position)


func _fail(msg: String) -> void:
	_fails += 1
	print("  FAIL  %s" % msg)


func _photograph(stand: HaySellingStand) -> void:


	await _look(stand, Vector3(DOOR_X, 0.02, 2.7), Vector3(DOOR_X, 1.35, -0.3),
		"booth_in.png")
	await _look(stand, Vector3(DOOR_X - 0.35, DECK_Y, 0.05),
		Vector3(DOOR_X + 0.15, 1.3, 3.0), "booth_out.png")


func _look(stand: HaySellingStand, eye: Vector3, at: Vector3, name: String) -> void:
	var e:= stand.to_global(eye)
	var t:= stand.to_global(at)
	player.global_position = e
	player.look_at_from_position(e, Vector3(t.x, e.y, t.z), Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		var flat:= Vector2(t.x - e.x, t.z - e.z).length()
		player.head.rotation.x = atan2(t.y - e.y, flat)
	await get_tree().process_frame


	if player.head != null:
		var flat2:= Vector2(t.x - e.x, t.z - e.z).length()
		player.head.rotation.x = atan2(t.y - player.head.global_position.y, flat2)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [shots, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("  wrote %s" % path)
