class_name DevLodShotProbe
extends Node


const NEAR_AT:= 0.8
const FAR_AT:= 1.25


const BEARING:= Vector3(0.35, 0.26, 1.0)

var world: Node3D
var player: Player

var _cam: Camera3D


func shoot(out_dir: String) -> void:
	world.block_save = true
	world.autosave_enabled = false
	Cfg.apply_quality(Cfg.Quality.HIGH)
	for i in 30:
		await get_tree().process_frame

	GameState.add_money(60000.0)


	var builds = world.builds
	var made: Array = []
	made.append(["scanner", builds.add_scanner(Vector3(-70.0, 0.0, 62.0), 0.0)])
	made.append(["dump_hatch", builds.add_dump_hatch(Vector3(-58.0, 0.0, 62.0), 0.0)])
	made.append(["hay_stairs", builds.add_hay_stairs(Vector3(-46.0, 0.0, 62.0), 0.0)])
	for i in 30:
		await get_tree().process_frame


	_cam = Camera3D.new()


	_cam.fov = 20.0
	_cam.near = 0.05
	_cam.far = player.camera.far
	world.add_child(_cam)
	_cam.current = true

	for entry: Array in made:
		var label: String = entry [0]
		var m:= entry [1] as Node3D
		if m == null:
			print("  %s: not built, skipped" % label)
			continue
		var gate:= _gate_of(m)
		if gate <= 0.0:
			print("  %s: no far LOD, so nothing to photograph" % label)
			continue
		print("  %s: swaps at %.1f m, standing at %v" % [label, gate,
			m.global_position])
		await _look(out_dir, "lod_%s_near.png" % label, m, gate * NEAR_AT)
		await _look(out_dir, "lod_%s_far.png" % label, m, gate * FAR_AT)

	get_tree().quit(0)


func _gate_of(m: Node3D) -> float:
	for n: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi != null and mi.name == "FarLod":
			return mi.visibility_range_begin
	return 0.0


func _look(out_dir: String, shot: String, m: Node3D, away: float) -> void:


	var aim: Vector3 = m.global_position + Vector3(0.0, 1.2, 0.0)
	var at: Vector3 = aim + BEARING.normalized() * away
	_cam.look_at_from_position(at, aim, Vector3.UP)


	player.global_position = at - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO


	for i in MachineLod.SWEEP_FRAMES * 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("    wrote %s" % path)
