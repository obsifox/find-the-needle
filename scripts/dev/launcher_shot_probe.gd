class_name DevLauncherShotProbe
extends Node


const CORNER_R:= 11.0
const CAMERA_R:= 16.0
const EYE_H:= 2.8
const AIM_H:= 1.5


const FIRE_EYE:= Vector3(16.6, 3.9, 16.1)
const FIRE_LOOK:= Vector3(10.0, 2.3, 5.0)


const FIRING_AIM:= 0.45
const FIRING_POWER:= 0.45


const SHOTS:= [
	{ "aim": Cfg.LAUNCHER_AIM_DEFAULT, "name": "launcher_rest.png" },
	{ "aim": 0.0, "name": "launcher_low.png" },
	{ "aim": 1.0, "name": "launcher_full.png" },
]

var world: Node3D
var player: Player


var _at:= Vector3.ZERO
var _yaw:= 0.0
var _eye:= Vector3.ZERO
var _look:= Vector3.ZERO
var _fire_eye:= Vector3.ZERO
var _fire_look:= Vector3.ZERO


func _pick_corner() -> void:
	var space:= world.get_world_3d().direct_space_state
	var mask:= Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PILE
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1),
			Vector2(-1, -1), Vector2(1, -1)]:
		var at:= Vector3(corner.x * CORNER_R, 0.0, corner.y * CORNER_R)
		var eye:= Vector3(corner.x * CAMERA_R, EYE_H, corner.y * (CAMERA_R - 0.8))
		_at = at


		_yaw = 0.0 if corner.y < 0.0 else PI
		_eye = eye
		_look = at + Vector3(0.0, AIM_H, 0.0)


		_fire_eye = eye
		_fire_look = at + Vector3(0.0, AIM_H, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(
			eye, at + Vector3(0.0, AIM_H, 0.0), mask)
		if space.intersect_ray(q).is_empty():
			print("[launchershot] corner (%.0f, %.0f): clear" % [corner.x, corner.y])
			return
		print("[launchershot] corner (%.0f, %.0f): something in the way"
			% [corner.x, corner.y])
	print("[launchershot] no clear corner; using the last one anyway")


func shoot(out_dir: String) -> void:
	world.block_save = true
	_pick_corner()
	var builds: BuildManager = world.builds
	if builds == null:
		push_error("[launchershot] no build manager")
		get_tree().quit(1)
		return


	var gun:= builds.add_tube_launcher(_at, _yaw)
	if gun == null:
		push_error("[launchershot] could not place a launcher")
		get_tree().quit(1)
		return
	gun.show_arc(true)
	await get_tree().process_frame

	_aim_player(_eye, _look)


	var feed:= gun.intake_port()
	var run:= builds.add_conveyor(feed - gun.forward() * 3.2, feed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	gun.aim = FIRING_AIM
	gun.power = FIRING_POWER
	await _settled(gun)
	var props: PropManager = world.props
	for i in 4:
		props.spawn("hay_wad",
			Transform3D(Basis(), gun.port_in() - gun.forward() * (0.3 + i * 0.55)
				+ Vector3(0.0, 0.14, 0.0)), { "strands": 30 })
	var airborne: Array [Carryable] = []
	gun.launched.connect(func(item: Carryable) -> void: airborne.append(item))
	for _i in 400:
		await get_tree().physics_frame


		if not airborne.is_empty():
			for _k in 9:
				await get_tree().physics_frame
			break
	_aim_player(_fire_eye, _fire_look)
	await _capture("%s/launcher_firing.png" % out_dir)
	print("[launchershot] launcher_firing.png  %d thrown, %d props in the yard"
		% [airborne.size(), props.items.size()])
	if run != null:
		builds.demolish(run)


	var panel: LauncherPanel = world.get("launcher_panel")
	if panel != null:
		gun.aim = Cfg.LAUNCHER_AIM_DEFAULT
		gun.power = Cfg.LAUNCHER_POWER_DEFAULT
		await _settled(gun)
		_aim_player(_eye, _look)
		panel.open(gun)
		await get_tree().process_frame
		await _capture("%s/launcher_panel.png" % out_dir)
		print("[launchershot] launcher_panel.png  %.0f deg, power %.0f%%, %.1f m"
			% [gun.tilt_now(), gun.power * 100.0, gun.range_metres()])
		panel.close()
		await get_tree().process_frame

	for shot: Dictionary in SHOTS:
		gun.aim = float(shot ["aim"])
		gun.power = Cfg.LAUNCHER_POWER_DEFAULT


		await _settled(gun)
		await _capture("%s/%s" % [out_dir, shot ["name"]])
		print("[launchershot] %s  power %.0f%%  tilt %.0f deg  range %.1f m" % [
			shot ["name"], gun.power * 100.0,
			gun.tilt_now(), gun.range_metres()])
	get_tree().quit(0)


func _aim_player(eye: Vector3, look: Vector3) -> void:
	player.global_position = eye
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)
	if flat.length_squared() < 1e-06:
		flat = Vector3.FORWARD
	player.look_at_from_position(eye, eye + flat, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = atan2(look.y - eye.y, maxf(flat.length(), 0.001))


func _settled(gun: TubeLauncher) -> void:
	var want:= TubeLauncher.tilt_for(gun.aim)
	for _i in 160:
		await get_tree().physics_frame
		if absf(gun.tilt_now() - want) < 0.05:
			break

	await get_tree().process_frame
	await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
