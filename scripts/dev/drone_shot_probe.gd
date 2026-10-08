class_name DevDroneShotProbe
extends Node


var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.near = 0.05
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true
	for i in 90:
		await get_tree().process_frame

	GameState.add_money(40000.0)
	var pad:= Vector3(13.0, 0.02, -6.0)
	player.global_position = Vector3(9.0, 0.4, -2.0)
	var drone: HayDrone = world.builds.add_hay_drone(pad, 0.0)
	drone.power_ports()
	drone.set_power(1.0)
	for i in 30:
		await get_tree().physics_frame


	var to_top:= Vector3(- pad.x, 0.0, - pad.z).normalized()
	var zone:= pad
	for i in 200:
		zone += to_top * 0.25
		if world.field.height_at(zone.x, zone.z) > 1.2:
			zone += to_top * 1.5
			break
	zone.y = 0.0
	var across:= Vector3(- to_top.z, 0.0, to_top.x)
	var zone_said:= drone.set_zone(zone, 2.5)


	var drop_said:= "no belt fits"
	for k in 16:
		var a:= TAU * float(k) / 16.0 + 0.2
		var mid:= pad + Vector3(cos(a), 0.0, sin(a)) * 5.0
		var along:= Vector3(- sin(a), 0.0, cos(a))
		var belt: Conveyor = world.builds.add_conveyor(Vector3(mid.x, 0.45, mid.z) - along * 3.0,
			Vector3(mid.x, 0.45, mid.z) + along * 3.0)
		if belt == null:
			continue
		for i in 6:
			await get_tree().process_frame
		drop_said = drone.set_drop(belt._point_at(belt.path_length() * 0.5), HayDrone.Drop.BELT)
		if drop_said == "" and drone._route_why == "":
			break
		world.builds.demolish(belt)
		drop_said = "refused"
	print("  zone %s, drop %s, route %s" % [zone_said, drop_said, drone._route_why])


	drone.show_job(true)
	for i in 20:
		await get_tree().process_frame
	await _look(out_dir, "marks_overview.png", pad + across * 7.0 + Vector3(0.0, 7.5, 0.0) - to_top * 3.0,
		(pad + zone) * 0.5 + Vector3(0.0, 2.0, 0.0), 60.0)
	await _look(out_dir, "zone_ring_on_pile.png", zone - to_top * 5.0 + Vector3(0.0, 4.0, 0.0) + across * 2.0,
		zone + Vector3(0.0, world.field.height_at(zone.x, zone.z), 0.0), 55.0)


	world.drone_panel.open(drone)
	for i in 30:
		await get_tree().process_frame
	await _look(out_dir, "plate.png", pad + across * 6.0 + Vector3(0.0, 3.0, 0.0), pad, 55.0)
	world.drone_panel.close()


	player.camera.current = true
	player.global_position = pad - to_top * 1.5 + Vector3(0.0, 0.4, 0.0)
	var eye:= player.camera.global_position
	var aim:= zone + Vector3(across.x * 2.0, world.field.height_at(zone.x + across.x * 2.0, zone.z + across.z * 2.0), across.z * 2.0)
	var flat:= Vector2(aim.x - eye.x, aim.z - eye.z).length()
	player.set_look(atan2(aim.x - eye.x, aim.z - eye.z) + PI, atan2(aim.y - eye.y, maxf(flat, 0.001)))
	world.drone_zone.begin(drone)
	for i in 30:
		await get_tree().process_frame
	await _snap(out_dir, "zone_mode.png")
	world.drone_zone.end()
	_cam.current = true


	var carried:= 0
	while carried < 6000 and not (drone._held != null and drone._phase == HayDrone.Phase.TO_DROP):
		await get_tree().process_frame
		carried += 1
	var at:= drone._model.global_position
	await _look(out_dir, "carrying.png", at + across * 4.0 + Vector3(0.0, 1.5, 0.0) - to_top * 2.0, at, 50.0)
	while carried < 9000 and drone._phase != HayDrone.Phase.DELIVER:
		await get_tree().process_frame
		carried += 1
	for i in 60:
		await get_tree().process_frame
	at = drone._model.global_position
	await _look(out_dir, "delivering.png", at + across * 3.5 + Vector3(0.0, 0.5, 0.0), at + Vector3(0.0, -1.2, 0.0), 55.0)
	get_tree().quit(0)


func _look(out_dir: String, shot: String, eye: Vector3, target: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, target, Vector3.UP)
	await _snap(out_dir, shot)


func _snap(out_dir: String, shot: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
	print("  wrote %s" % ProjectSettings.globalize_path(path))
