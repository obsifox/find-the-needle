class_name DevBriquetteWireShotProbe
extends Node


const LANE_X:= 22.0
const REBUILD_FRAMES:= 8

const ROPE_SECONDS:= 4.0

var world: Node3D
var player: Player

var _cam: Camera3D
var _press: BriquettePress


func shoot(out_dir: String) -> void:
	world.block_save = true
	for _w in 40:
		await get_tree().process_frame
	player.global_position = Vector3(LANE_X - 12.0, 0.4, 0.0)
	_press = world.builds.add_briquette(Vector3(LANE_X, 0.0, 0.0), 0.0)
	for _w in 60:
		await get_tree().physics_frame

	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.far = 4000.0
	world.add_child(_cam)
	_cam.make_current()
	Cfg.set_no_hud(true)


	var phases: Array = [
		["pack", Vector3(5.0, 0.0, 1.0), [
			["close", Vector3(2.55, 2.25, 1.35), Vector3(1.48, 1.65, -0.04)],
			["level", Vector3(3.2, 1.62, -0.04), Vector3(1.48, 1.62, -0.04)],
			["wide", Vector3(6.5, 3.4, 5.0), Vector3(2.8, 1.9, 0.3)]]],
		["grinder", Vector3(-3.5, 0.0, 4.0), [
			["close", Vector3(-2.5, 2.3, 1.55), Vector3(-1.39, 1.7, 0.44)],
			["level", Vector3(-1.39, 1.66, 2.3), Vector3(-1.39, 1.66, 0.44)],
			["wide", Vector3(-3.9, 3.4, 7.5), Vector3(-1.8, 1.8, 1.2)]]]]
	for phase: Array in phases:
		var label: String = phase [0]
		var offset: Vector3 = phase [1]
		var pole: PowerPole = world.builds.add_power_pole(
			_press.global_position + offset, 0.0)
		await _settle_frames()
		await _settle_rope()
		_report(label)
		for shot: Array in phase [2]:
			var eye: Vector3 = shot [1]
			var aim: Vector3 = shot [2]
			await _snap(out_dir, "briquette_wire_%s_%s.png" % [label, shot [0]],
				eye, aim)
		world.builds._demolish(pole)
		await _settle_frames()

	print("[briquettewireshot] done")
	get_tree().quit()


func _report(label: String) -> void:
	var grid: PowerGrid = world.builds.grid
	var port:= grid.port_for(_press)
	if port == null:
		print("  %-8s NO DROP: the grid wired nothing to the press" % label)
		return
	var model:= _press.get_node_or_null("Model") as Node3D
	var base:= port.get_parent() as Node3D
	var local:= model.to_local(base.global_position) if model != null else Vector3.ZERO
	print("  %-8s drop to %s, tie at %s, base in the model's frame %s"
		% [label, port.name, port.global_position, local])


func _settle_frames() -> void:
	for _i in REBUILD_FRAMES:
		await get_tree().process_frame
		await get_tree().physics_frame


func _settle_rope() -> void:
	var t:= 0.0
	while t < ROPE_SECONDS:
		await get_tree().process_frame
		t += get_process_delta_time()


func _snap(out_dir: String, file: String, eye: Vector3, aim: Vector3) -> void:
	var origin:= _press.global_position
	_cam.look_at_from_position(origin + eye, origin + aim, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, file]
	img.save_png(path)
	print("wrote %s" % path)
