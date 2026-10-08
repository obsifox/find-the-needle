class_name DevPumpShotProbe
extends Node


const STAND:= Vector3(13.0, 0.0, 0.0)

var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in 40:
		await get_tree().process_frame
	player.global_position = STAND + Vector3(6.0, 0.4, 6.0)
	GameState.add_money(200000.0)
	for _w in 30:
		await get_tree().process_frame

	var pump: BoreholePump = world.builds.add_borehole(STAND, 0.0)
	for _w in 90:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()


	var guard:= _mesh_named(pump, "BP_Guard")
	var at:= (pump.global_position + Vector3(0.0, 1.0, 0.0) if guard == null
		else guard.global_transform * guard.get_aabb().get_center())
	print("  guard centre %s   pump at %s" % [at, pump.global_position])


	await _snap(out_dir, "pump_guard.png", at + Vector3(1.55, 0.3, 0.1), at)
	await _snap(out_dir, "pump_guard_wide.png",
		at + Vector3(3.4, 1.2, 1.9), at + Vector3(0.0, 0.3, 0.3))
	await _snap(out_dir, "pump_hero.png",
		pump.global_position + Vector3(4.35, 3.95, 2.5),
		pump.global_position + Vector3(0.05, 1.6, 0.2))

	print("[pumpshot] done")
	get_tree().quit()


func _mesh_named(pump: Node3D, mesh_name: String) -> MeshInstance3D:
	for n in pump.find_children(mesh_name, "MeshInstance3D", true, false):
		return n as MeshInstance3D
	return null


func _snap(out_dir: String, name: String, at: Vector3, aim: Vector3) -> void:
	_cam.look_at_from_position(at, aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
