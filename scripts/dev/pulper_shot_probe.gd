class_name DevPulperShotProbe
extends Node


const LANE_X:= 13.0


const WINDOW_AT:= Vector3(0.53, 0.83, 0.54)


const WINDOW_BACK:= 0.78

var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in 40:
		await get_tree().process_frame
	player.global_position = Vector3(9.0, 0.4, 0.0)
	GameState.add_money(200000.0)
	for _w in 30:
		await get_tree().process_frame

	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var pulper: HayPulper = world.builds.add_pulper(
		Vector3(LANE_X, deck_y, 0.0), 0.0)
	for _w in 60:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()


	pulper.stored = Tech.pulper_batch_strands() * 6
	await _wait_running(pulper)


	await _wait_bed(pulper, 0.85)
	_report(pulper, "flank")
	await _snap_from(out_dir, "pulper_flank.png",
		pulper.global_position + Vector3(-2.3, 1.15, 2.6),
		pulper.global_position + Vector3(0.0, 0.72, 0.3))


	await _snap_from(out_dir, "pulper_discharge.png",
		pulper.global_position + Vector3(1.9, 1.05, 3.1),
		pulper.global_position + Vector3(0.0, 0.45, 1.7))


	for i in 3:
		_report(pulper, "window_%d" % i)
		await _snap_window(out_dir, "pulper_window_%d.png" % i, pulper)


		await _snap_from(out_dir, "pulper_wide_%d.png" % i,
			pulper.global_position + Vector3(3.4, 1.6, 2.2),
			pulper.global_position + Vector3(0.0, 0.7, 0.4))
		for _w in 20:
			await get_tree().process_frame


	await _wait_bed(pulper, 0.4)
	_report(pulper, "flank_low")
	await _snap_from(out_dir, "pulper_flank_low.png",
		pulper.global_position + Vector3(1.6, 0.75, 0.55),
		pulper.global_position + Vector3(0.0, 0.7, 0.55))


	await _wait_pouring(pulper)
	await _snap_from(out_dir, "pulper_pour.png",
		pulper.global_position + Vector3(-1.6, 1.05, 2.9),
		pulper.global_position + Vector3(0.0, 0.5, 1.6))
	await _snap_window(out_dir, "pulper_window_pouring.png", pulper)

	print("[pulpershot] done")
	get_tree().quit()


func _wait_running(pulper: HayPulper) -> void:
	for _w in 900:
		if pulper.is_running():
			return
		await get_tree().physics_frame
	print("[pulpershot] WARNING: the machine never started")


func _wait_bed(pulper: HayPulper, want: float) -> void:
	for _w in 3600:
		if pulper.charge_fraction() >= want:
			return
		await get_tree().physics_frame
	print("[pulpershot] WARNING: the bed never reached %.2f (%.2f)"
		% [want, pulper.charge_fraction()])


func _wait_pouring(pulper: HayPulper) -> void:
	for _w in 1800:
		if absf(pulper.gate_angle_deg()) > absf(HayPulper.GATE_OPEN_DEG) * 0.6:
			return
		await get_tree().physics_frame
	print("[pulpershot] WARNING: the gate never opened")


func _snap_window(out_dir: String, name: String, pulper: HayPulper) -> void:
	var centre:= pulper.to_global(WINDOW_AT)


	var eye:= centre + Vector3(WINDOW_BACK, 0.1, 0.0)
	await _snap_from(out_dir, name, eye, centre)


func _report(pulper: HayPulper, label: String) -> void:
	var lv:= pulper._find(HayPulper.N_LEVEL) as MeshInstance3D
	if lv == null:
		return
	var box:= lv.get_aabb()
	var xf:= pulper.global_transform.affine_inverse() * lv.global_transform
	var lo:= xf * box.position
	var hi:= xf * box.end


	var rotor:= pulper._find("Pulp_Rotor_Pivot") as Node3D
	var spin:= 0.0 if rotor == null else rad_to_deg(rotor.rotation.z)
	var bed:= pulper._bed_mesh
	print("  %-18s bed %.2f (%s, y %.3f)  bath %s at %.3f  y %.3f..%.3f  rotor %+7.1f deg  drive %.2f"
		% [label, pulper.charge_fraction(),
			"shown" if bed != null and bed.visible else "hidden",
			0.0 if bed == null else bed.scale.y,
			"shown" if lv.visible else "hidden", lv.scale.y,
			minf(lo.y, hi.y), maxf(lo.y, hi.y), spin, pulper.drive()])


func _snap_from(out_dir: String, name: String, at: Vector3,
		aim: Vector3) -> void:
	_cam.look_at_from_position(at, aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
