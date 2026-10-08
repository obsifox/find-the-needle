class_name DevForkAimProbe
extends Node


const PITCHES:= [0.1, 0.0, -0.15, -0.25, -0.4, -0.55, -0.85, -1.15]

const SETTLE:= 90


const BITES:= 4

const BETWEEN:= 45


var world: Node3D
var player: Player

var _fails: Array [String] = []


var _overlaps:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	var live: LiveStrandManager = world.live
	_clear_hay(live)
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()


	_stand_at_the_pile()
	for i in 20:
		await get_tree().physics_frame
	var fork:= player.pitchfork
	for n in BITES:
		fork.scoop()
		for i in BETWEEN:
			await get_tree().physics_frame
	for i in SETTLE:
		await get_tree().physics_frame
	var carried:= fork.carried_strands()
	print("\n=== a pitchfork carrying %d strands, out on the floor ===" % carried)
	if carried <= 0:
		print("  FAIL  the fork picked nothing up, so there is nothing to test")
		get_tree().quit(1)
		return

	_stand_on_the_floor()
	for i in 30:
		await get_tree().physics_frame


	print("  %d strands still on the tines after the walk out, standing %.3f m"
		% [fork.carried_strands(), _load_height(fork, _held_bodies(fork))])
	if fork.carried_strands() <= 0:
		print("  FAIL  the load came off on the way, so there is nothing to test")
		get_tree().quit(1)
		return

	await _sweep(fork, "open")


	_put_a_wall_in_front()
	await _sweep(fork, "close")


	fork._aim_pitch = 0.45
	await get_tree().physics_frame
	await _sweep(fork, "tilted")

	_check_the_alpha(fork)

	print("\n  the load stood inside the highlight sphere in %d rows" % _overlaps)
	if _overlaps == 0:
		_fails.append("no row put the load inside the sphere, so nothing was tested")
	for f in _fails:
		print("  FAIL  %s" % f)
	print("[probe] %s" % ("PASS" if _fails.is_empty() else "%d FAILURE(S)" % _fails.size()))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _check_the_alpha(fork: Shovel) -> void:
	var live: LiveStrandManager = world.live
	var held:= { }
	for b in _held_bodies(fork):
		held [b.get_instance_id()] = true
	var on_tool:= 0
	var on_tool_wrong:= 0
	var loose:= 0
	var loose_wrong:= 0
	for b in live._active:
		var a:= LiveStrandManager.draw_alpha(b)
		if held.has(b.get_instance_id()):
			on_tool += 1
			if a > 0.5:
				on_tool_wrong += 1
		else:
			loose += 1
			if a <= 0.5:
				loose_wrong += 1
	print("\n  drawn alpha: %d on the fork (%d still lightable), %d loose (%d dimmed)"
		% [on_tool, on_tool_wrong, loose, loose_wrong])
	if on_tool == 0:
		_fails.append("no strand on the fork was in the drawn set at all")
	if on_tool_wrong > 0:
		_fails.append("%d strands on the fork are drawn still lightable" % on_tool_wrong)
	if loose > 0 and loose_wrong > 0:
		_fails.append("%d loose strands are drawn dimmed, which would put the highlight out"
			% loose_wrong)


func _sweep(fork: Shovel, stance: String) -> void:
	print("\n  -- %s --" % stance)
	print("  pitch    hit   reach   radius   inside     lit   nearest")
	for pitch: float in PITCHES:
		player.head.rotation.x = pitch


		await get_tree().physics_frame
		await get_tree().physics_frame
		var aim:= fork.aim_point()
		var held:= _held_bodies(fork)
		if aim.is_empty():
			print("  %6.2f   none" % pitch)
			continue
		var at: Vector3 = aim ["position"]


		var radius:= Pitchfork.SCOOP_RADIUS
		if bool(aim.get("loose", false)):
			radius *= Shovel.GATHER_REACH


		var inside:= 0
		var lit:= 0
		var nearest:= 1000000000.0
		var live: LiveStrandManager = world.live
		for b in held:
			var d:= b.global_position.distance_to(at)
			nearest = minf(nearest, d)
			if d >= radius:
				continue
			inside += 1
			if not live.is_held_by_a_tool(b):
				lit += 1
		if inside > 0:
			_overlaps += 1
		var reach:= at.distance_to(player.eye_position())
		print("  %6.2f   %4s   %5.2f   %6.3f   %6d   %5d   %7.3f"
			% [pitch, "loose" if aim.get("loose", false) else "pile",
				reach, radius, inside, lit, nearest])


		if lit > 0:
			_fails.append("%s, looking %.2f rad down, lit %d of the fork's own strands"
				% [stance, pitch, lit])


func _put_a_wall_in_front() -> void:
	var wall:= StaticBody3D.new()
	wall.name = "ProbeWall"
	wall.collision_layer = Cfg.L_WORLD
	wall.collision_mask = 0
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.2)
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)


	var ahead:= - player.global_transform.basis.z
	wall.global_position = player.eye_position() + ahead * 1.2
	wall.global_rotation = Vector3(0, player.rotation.y, 0)


func _load_height(fork: Shovel, held: Array [RigidBody3D]) -> float:
	if held.is_empty():
		return 0.0
	var into:= fork.body.global_transform.orthonormalized().affine_inverse()
	var floor_y: float = (fork.pan_geometry() ["origin"] as Vector3).y
	var top:= -1000.0
	for b in held:
		top = maxf(top, (into * b.global_position).y)
	return top - floor_y


func _held_bodies(fork: Shovel) -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []
	for id: int in fork._riding:
		var b: Variant = fork._riding [id]
		if b is RigidBody3D and is_instance_valid(b) and (b as RigidBody3D).is_inside_tree():
			out.append(b as RigidBody3D)
	return out


func _clear_hay(live: LiveStrandManager) -> void:
	for b in live._active.duplicate():
		live._despawn(b)


func _stand_at_the_pile() -> void:
	player.global_position = Vector3(11.5, 0.4, 0.0)
	player.rotation = Vector3(0, PI * 0.5, 0)
	player.head.rotation.x = -0.55
	player.velocity = Vector3.ZERO


func _stand_on_the_floor() -> void:
	player.global_position = Vector3(4.0, 0.4, 0.0)
	player.rotation = Vector3(0, - PI * 0.5, 0)
	player.velocity = Vector3.ZERO
