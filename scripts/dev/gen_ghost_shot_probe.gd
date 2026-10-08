class_name DevGenGhostShotProbe
extends Node


const CORNER_R:= 11.0
const CAMERA_R:= 16.0
const EYE_H:= 3.2
const AIM_H:= 1.4

var world: Node3D
var player: Player


var _stand:= Vector3.ZERO
var _yaw:= 0.0
var _eye:= Vector3.ZERO
var _look:= Vector3.ZERO
var _port_eye:= Vector3.ZERO
var _port_look:= Vector3.ZERO


func _pick_corner() -> void:
	var space:= world.get_world_3d().direct_space_state
	var mask:= Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PILE
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1),
			Vector2(-1, -1), Vector2(1, -1)]:


		var out:= Vector3(corner.x, 0.0, corner.y).normalized()
		var side:= Vector3(- out.z, 0.0, out.x)
		_stand = Vector3(corner.x * CORNER_R, 0.0, corner.y * CORNER_R)


		_yaw = atan2(- side.x, - side.z)


		_eye = Vector3(corner.x * CAMERA_R, EYE_H, corner.y * CAMERA_R)
		_look = _stand + Vector3(0.0, AIM_H, 0.0)


		_port_eye = _stand + side * 5.0 + out * 3.0 + Vector3(0.0, 2.2, 0.0)
		_port_look = _stand + side * HayGenerator.PORT_BACK + Vector3(0.0, HayGenerator.PORT_UP, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(_eye, _look, mask)
		var q2:= PhysicsRayQueryParameters3D.create(_port_eye, _port_look, mask)
		if space.intersect_ray(q).is_empty() and space.intersect_ray(q2).is_empty():
			print("[genghost] corner (%.0f, %.0f): clear" % [corner.x, corner.y])
			return
		print("[genghost] corner (%.0f, %.0f): something in the way"
			% [corner.x, corner.y])
	print("[genghost] no clear corner; using the last one anyway")


func shoot(out_dir: String) -> void:
	world.block_save = true
	_pick_corner()
	var builds: BuildManager = world.builds
	if builds == null:
		push_error("[genghost] no build manager")
		get_tree().quit(1)
		return


	var ghost:= HayGenerator.new()
	ghost.name = "GeneratorGhost"
	ghost.placement_preview = true
	world.add_child(ghost)
	ghost.global_position = _stand
	ghost.global_rotation = Vector3(0.0, _yaw, 0.0)
	await get_tree().process_frame
	await get_tree().physics_frame
	print("[genghost] ghost  port %s  head %s" % [ghost.intake_port(), ghost.belt_head()])
	print("[genghost] ghost  children: %s" % [_kids(ghost)])


	var drawn:= ghost.get_node_or_null("GhostBelt/Sections") as MultiMeshInstance3D
	if drawn != null:
		var gmm:= drawn.multimesh
		print("[genghost] ghost  belt %d segs, tail %s head %s" % [
			gmm.instance_count,
			ghost.to_global(gmm.get_instance_transform(0).origin),
			ghost.to_global(gmm.get_instance_transform(
				gmm.instance_count - 1).origin)])

	_aim(_eye, _look)
	await _capture("%s/gen_ghost_side.png" % out_dir)
	_aim(_port_eye, _port_look)
	await _capture("%s/gen_ghost_port.png" % out_dir)
	ghost.queue_free()
	await get_tree().process_frame

	var real:= builds.add_generator(_stand, _yaw, 0.0)
	if real == null:
		push_error("[genghost] could not place a generator")
		get_tree().quit(1)
		return


	for _i in 8:
		await get_tree().physics_frame
	print("[genghost] placed port %s  head %s" % [real.intake_port(), real.belt_head()])
	print("[genghost] placed children: %s" % [_kids(real)])

	_aim(_eye, _look)
	await _capture("%s/gen_real_side.png" % out_dir)
	_aim(_port_eye, _port_look)
	await _capture("%s/gen_real_port.png" % out_dir)


	real.fuel = real.capacity()


	for _i in 150:
		await get_tree().physics_frame
	var mouth:= real.to_global(HayGenerator.STEAM_AT)
	print("[genghost] burning %s, steam mouth %s" % [real.fuel > 0.0, mouth])
	_aim(_eye, mouth + Vector3(0.0, 1.0, 0.0))
	await _capture("%s/gen_steam_side.png" % out_dir)
	_aim(_port_eye, mouth + Vector3(0.0, 1.2, 0.0))
	await _capture("%s/gen_steam_port.png" % out_dir)
	print("[genghost] six pictures in %s" % out_dir)
	get_tree().quit(0)


func _kids(gen: HayGenerator) -> String:
	var names:= PackedStringArray()
	for child in gen.get_children():
		names.append(child.name)
	return ", ".join(names)


func _aim(eye: Vector3, look: Vector3) -> void:
	player.global_position = eye
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)
	if flat.length_squared() < 1e-06:
		flat = Vector3.FORWARD
	player.look_at_from_position(eye, eye + flat, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = atan2(look.y - eye.y, maxf(flat.length(), 0.001))


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png(path)
