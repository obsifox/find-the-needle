class_name DevDigShotProbe
extends Node


const EYE:= Vector3(0.0, 2.4, 9.5)
const PITCH:= -26.0


const FORK_PITCH:= -38.0

var world: Node3D
var player: Player
var props: PropManager
var field: HayField


func shoot(out_dir: String) -> void:
	world.block_save = true
	Tech.reset()


	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	_aim()


	for _w in 90:
		await get_tree().process_frame

	Tech.grant("shovel_size", 1)
	await _dig(player.shovel)
	await _snap(out_dir, "dig_rank1_loose.png")
	Tech.grant("shovel_size", 3)
	await _dig(player.shovel)
	await _snap(out_dir, "dig_rank3_balls.png")
	await _fork_shot(out_dir)
	await _full_shot(out_dir, Player.Tool.SHOVEL, -3.0)
	await _full_shot(out_dir, Player.Tool.PITCHFORK, 0.0)
	GameState.grant_tool("sand_shovel")
	await _full_shot(out_dir, Player.Tool.TOY, 3.0)
	get_tree().quit(0)


func _full_shot(out_dir: String, tool: int, dx: float) -> void:
	_aim()
	player._set_tool(tool)
	player.global_position = EYE + Vector3(dx, 0.0, 0.0)
	player.rotation.y += PI
	if player.head != null:
		player.head.rotation.x = deg_to_rad(-30.0)
	for _w in 30:
		await get_tree().process_frame
	var g: Dictionary
	var cap:= 0
	var label:= ""
	match tool:
		Player.Tool.SHOVEL:
			g = player.shovel.pan_geometry()
			cap = player.shovel.capacity()
			label = "spade"
		Player.Tool.PITCHFORK:
			g = player.pitchfork.pan_geometry()
			cap = player.pitchfork.capacity()
			label = "fork"
		_:
			var toy:= player.carry.held() as SandShovel
			if toy == null:
				print("  no toy spade in the hands")
				return
			g = toy.pan_geometry()
			cap = toy.capacity()
			label = "toy"
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 12345
	var w:= float(g ["w"]) * 0.3
	var d:= float(g ["d"]) * 0.3
	var made:= 0
	while made < cap:

		var xf: Transform3D = _pan_xf(tool, g)
		var origin: Vector3 = g ["origin"]
		for i in mini(12, cap - made):
			var local:= Vector3(rng.randf_range(- w, w), 0.04,
				rng.randf_range(- d, d)) + origin
			live.spawn(xf * local, StrandFactory.random_strand_basis(rng),
				Vector3.ZERO, StrandFactory.random_tint(rng))
			made += 1
		for _i in 4:
			await get_tree().physics_frame
	for _i in 45:
		await get_tree().physics_frame
	await _snap(out_dir, "full_%s.png" % label)
	print("  %s holds %d of %d" % [label, _held(tool), cap])


func _pan_xf(tool: int, g: Dictionary) -> Transform3D:
	match tool:
		Player.Tool.SHOVEL:
			return player.shovel.pan_geometry() ["xf"]
		Player.Tool.PITCHFORK:
			return player.pitchfork.pan_geometry() ["xf"]
	var toy:= player.carry.held() as SandShovel
	return toy.pan_geometry() ["xf"] if toy != null else g ["xf"]


func _held(tool: int) -> int:
	match tool:
		Player.Tool.SHOVEL:
			return player.shovel.carried_strands()
		Player.Tool.PITCHFORK:
			return player.pitchfork.carried_strands()
	var toy:= player.carry.held() as SandShovel
	return toy.carried_strands() if toy != null else 0


func _fork_shot(out_dir: String) -> void:
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for _w in 30:
		await get_tree().process_frame
	await _dig(player.pitchfork)
	player.rotation.y += PI
	if player.head != null:
		player.head.rotation.x = deg_to_rad(FORK_PITCH)
	for _w in 30:
		await get_tree().process_frame
	await _snap(out_dir, "dig_fork.png")
	_report_clearance(player.pitchfork)


func _report_clearance(fork: Pitchfork) -> void:
	if fork == null or fork.body == null:
		return
	var into:= fork.body.global_transform.orthonormalized().affine_inverse()
	var s:= fork.blade_scale()
	var low:= INF
	for id: int in fork._riding:
		var b: Variant = fork._riding [id]
		if b is not RigidBody3D or not is_instance_valid(b):
			continue
		var rb:= b as RigidBody3D
		if rb.is_inside_tree():
			low = minf(low, (into * rb.global_position).y)
	if is_inf(low):
		print("  nothing on the tines to measure")
		return
	print("  %d strands on the tines, the lowest %.3f m over them"
		% [fork._riding.size(), low - Pitchfork.TINE_H * 0.5 * s])


func _aim() -> void:
	player.global_position = EYE
	player.look_at_from_position(EYE, Vector3(0, 1.2, 0), Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = deg_to_rad(PITCH)
	player.select_hotbar_slot(1)


func _dig(blade: Shovel) -> void:
	var g:= blade.pan_geometry()


	var took:= 0
	for step in 6:
		var at:= Vector3(float(step - 3) * 0.5, 0.0, 3.4)
		at.y = field.height_at(at.x, at.z) - 0.05
		took += blade.scoop_at(at, int(g ["max"]), float(g ["radius"]),
			blade.body.global_transform.orthonormalized(),
			g ["origin"] as Vector3, float(g ["w"]), float(g ["d"]))
		if took > 0:
			break
	print("  dug %d strands" % took)


	for _i in 40:
		await get_tree().physics_frame


func _snap(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
