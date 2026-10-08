class_name DevYardProbe
extends Node


var world: Node3D
var player: Player
var warehouse: Warehouse
var door: BayDoor
var terrain: YardTerrain


const REGIONS:= 16


func run() -> void:
	if world != null:
		world.block_save = true
	var fails:= 0
	fails += _check_terrain()
	fails += _check_flat()
	fails += _check_paint()
	fails += _check_flora()
	fails += await _check_standing()
	fails += _check_extension()
	Tech.reset()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_terrain() -> int:
	print("\n-- terrain --")
	if terrain == null:
		return _fail("no terrain was handed to the probe")
	var t:= terrain.terrain()
	if t == null or t.data == null:
		return _fail("the terrain built no Terrain3D data")
	var regions: int = t.data.get_region_count()
	if regions != REGIONS:
		return _fail("%d regions loaded out of %s, not %d"
			% [regions, YardTerrain.DATA_DIR, REGIONS])
	if t.region_size != YardTerrain.REGION_SIZE or not is_equal_approx(t.vertex_spacing, YardTerrain.CELL):
		return _fail("the terrain is %d vertex regions at %.2f m, not %d at %.2f"
			% [t.region_size, t.vertex_spacing, YardTerrain.REGION_SIZE, YardTerrain.CELL])
	print("  %d regions of %d vertices at %.1f m, %.0f m of ground across"
		% [regions, t.region_size, t.vertex_spacing, YardTerrain.HALF * 2.0])


	if not t.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return _fail("the terrain has been moved off the origin: %s" % t.global_transform)


	var bad:= 0
	if t.collision_mode != Terrain3DCollision.DISABLED:
		bad += _fail("the plugin is colliding the terrain itself (mode %d), on top of YardTerrain's ground"
			% t.collision_mode)
	var solid:= terrain.solid()
	if solid == null or solid.collision_layer != Cfg.L_WORLD:
		bad += _fail("YardTerrain built no solid ground on the world layer")
	else:
		var reach:= (YardTerrain.SOLID_SAMPLES - 1) * 0.5 * YardTerrain.CELL
		var widest:= Cfg.yard_inner_for_pile() + Tech.YARD_METRES_PER_RANK * float(TechTree.max_rank("yard_space"))
		var gate:= widest + Warehouse.WALL_T + YardGround.CORRIDOR_OUT
		var back:= widest + Warehouse.long_for(widest) + Warehouse.WALL_T + YardFence.SHED_GAP
		if reach < maxf(gate, back) + 10.0:
			bad += _fail("the solid ground reaches %.0f m and the widest yard's gate is %.0f m out, its back %.0f m"
				% [reach, gate, back])
		else:
			print("  solid ground %.0f m each way; the widest yard's gate is %.0f m out, its back %.0f m"
				% [reach, gate, back])


	var params: Dictionary = t.material.get("_shader_parameters") if t.material != null else { }
	if t.material == null:
		bad += _fail("the terrain has no material")
	elif not params.has("blend_sharpness") or not params.has("noise1_scale"):
		bad += _fail("the material's shader parameters are empty: the scene was written "
			+ "from a material that was never attached to a live terrain")
	else:
		print("  %d shader parameters on the material" % params.size())


	var lo:= 1000000000.0
	var hi:= -1000000000.0
	for i in 64:
		var a:= TAU * i / 64.0
		var at:= Vector3(cos(a), 0.0, sin(a)) * 300.0
		var h:= terrain.height_at(at)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if hi - lo < 4.0:
		return _fail("the ground at 300 m only moves %.2f m: there are no hills" % (hi - lo))
	print("  at 300 m out the ground runs from %.1f m to %.1f m" % [lo, hi])
	return bad


func _check_flat() -> int:
	print("\r\n-- level ground --")
	var bad:= 0
	var yaw:= terrain.track_yaw
	var out:= Vector3(sin(yaw), 0.0, cos(yaw))
	var across:= Vector3(cos(yaw), 0.0, - sin(yaw))
	var need_flat:= YardTerrain.required_flat()
	var need_run:= YardTerrain.required_run()

	if YardTerrain.FLAT_R < need_flat:
		bad += _fail("the terrain was baked level to %.0f m and the widest shed needs %.0f m"
			% [YardTerrain.FLAT_R, need_flat])
	if YardTerrain.TRACK_RUN < need_run:
		bad += _fail("the corridor was baked %.0f m long and the longest track needs %.0f m"
			% [YardTerrain.TRACK_RUN, need_run])

	var worst:= 0.0
	for i in 48:
		var a:= TAU * i / 48.0
		var at:= Vector3(cos(a), 0.0, sin(a)) * need_flat
		worst = maxf(worst, absf(terrain.height_at(at) - YardGround.GROUND_Y))
	if worst > 0.01:
		bad += _fail("the ground moves %.3f m inside the %.0f m the widest shed needs"
			% [worst, need_flat])
	else:
		print("  level to %.4f m out to the %.0f m the widest shed needs" % [worst, need_flat])

	worst = 0.0
	var u:= 0.0
	while u < need_run:
		for v: float in [-6.0, 0.0, 6.0]:
			var at:= out * u + across * v
			worst = maxf(worst, absf(terrain.height_at(at) - YardGround.GROUND_Y))
		u += 5.0
	if worst > 0.01:
		bad += _fail("the track corridor moves %.3f m over the %.0f m it is built along"
			% [worst, need_run])
	else:
		print("  the track corridor is level to %.4f m over %.0f m" % [worst, need_run])
	return bad


func _check_paint() -> int:
	print("\n-- what the ground is made of --")
	var data:= terrain.terrain().data
	var yaw:= terrain.track_yaw
	var out:= Vector3(sin(yaw), 0.0, cos(yaw))
	var bad:= 0


	var gravel:= 0
	var samples:= 0
	var u:= 40.0
	while u < YardGround.ROAD_END:
		var c: int = data.get_control(out * u)
		samples += 1
		if Terrain3DUtil.get_overlay(c) == YardFlora.TEX_TRACK and Terrain3DUtil.get_blend(c) > 150:
			gravel += 1
		u += 6.0
	if gravel < int(samples * 0.85):
		bad += _fail("only %d of %d samples down the track are painted gravel"
			% [gravel, samples])
	else:
		print("  %d of %d samples down the track are gravel" % [gravel, samples])


	var seen:= { }
	for i in 512:
		var a:= TAU * i / 512.0
		var r:= 140.0 + fmod(i * 37.0, 300.0)
		var c: int = data.get_control(Vector3(cos(a), 0.0, sin(a)) * r)
		seen [Terrain3DUtil.get_base(c)] = true
	if seen.size() < 2:
		bad += _fail("every field on the map is growing the same thing (%s)" % seen.keys())
	else:
		print("  %d crops in the fields: %s" % [seen.size(), seen.keys()])
	return bad


func _check_flora() -> int:
	print("\n-- what is growing on it --")
	var bad:= 0


	var assets:= terrain.terrain().assets
	if assets == null:
		return _fail("the terrain has no asset library")


	if assets.resource_path != YardFlora.LIBRARY:
		bad += _fail("the scene carries its own copy of the library, not %s"
			% YardFlora.LIBRARY)
	else:
		print("  the scene points at %s" % YardFlora.LIBRARY)


	var on_disk: Terrain3DAssets = ResourceLoader.load(
		YardFlora.LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE)
	if on_disk == null:
		bad += _fail("%s will not load" % YardFlora.LIBRARY)
	else:
		var meshes: int = on_disk.get_mesh_list().size()
		var textures: int = on_disk.get_texture_list().size()


		if meshes < 3 or textures < 4:
			bad += _fail("the library file holds %d meshes and %d ground textures, fewer than the 3 and 4 the yard needs"
				% [meshes, textures])
		else:
			print("  holding %d plants and props and %d ground textures"
				% [meshes, textures])


	for slot: int in [YardFlora.MESH_TREE, YardFlora.MESH_BUSH, YardFlora.MESH_GRASS]:
		if not ResourceLoader.exists(YardFlora.plant_path(slot)):
			bad += _fail("%s was never written" % YardFlora.plant_path(slot))


	var need:= YardTerrain.required_flat()
	var worst:= 1.0
	for i in 256:
		var a:= TAU * i / 256.0
		worst = minf(worst, YardTerrain.relief_at(
			Vector3(cos(a), 0.0, sin(a)) * (need - 1.0), terrain.track_yaw))
	if worst > 0.0:
		bad += _fail("growth is allowed within %.0f m, and the widest shed needs that clear"
			% need)
	else:
		print("  the planting mask is closed out to the %.0f m the widest shed needs" % need)
	return bad


func _check_standing() -> int:
	print("\n-- standing on it --")
	if player == null or door == null:
		return _fail("no player or door was handed to the probe")
	var bad:= 0


	var gate:= YardGround.CORRIDOR_OUT - 1.0
	for out: float in [3.0, 12.0, 20.0, 26.0, 40.0, 60.0, gate]:
		var at:= door.inboard_point(- out)
		var hit: Dictionary = _ground_under(Vector3(at.x, 40.0, at.z))
		if hit.is_empty():
			bad += _fail("%.0f m out of the doorway there is nothing under foot" % out)
			continue
		var y: float = hit ["position"].y
		var drawn:= terrain.height_at(at)
		if hit ["collider"] == terrain.solid() and absf(y - drawn) > 0.01:
			bad += _fail("%.0f m out the ground is solid at %.3f m and drawn at %.3f m"
				% [out, y, drawn])
			continue
		print("  %5.0f m out: ground at %.2f m (drawn at %.2f), on %s"
			% [out, y, drawn, hit ["collider"]])
	var stood:= await _stand_at(door.inboard_point(- gate) + Vector3(0.0, 3.0, 0.0))
	if not player.is_on_floor():
		bad += _fail("dropped at the gate %.0f m out, the player is on nothing at y %.2f"
			% [gate, stood.y])
	else:
		print("  dropped at the gate %.0f m out, the player is standing at y %.2f"
			% [gate, stood.y])
	return bad


func _ground_under(from: Vector3) -> Dictionary:
	var space:= world.get_world_3d().direct_space_state
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0)
	q.collision_mask = Cfg.L_WORLD
	return space.intersect_ray(q)


func _stand_at(at: Vector3) -> Vector3:
	player.velocity = Vector3.ZERO
	player.global_position = at
	for _i in 40:
		await get_tree().physics_frame
	return player.global_position


func _check_extension() -> int:
	print("\n-- after an extension --")
	var bad:= 0
	Tech.reset()
	var before:= terrain.get_instance_id()
	var stock:= _yard_ground()
	if stock == null:
		return _fail("the shed built no YardGround outside its doorway")

	Tech.grant("yard_space", TechTree.max_rank("yard_space"))
	var grown:= _yard_ground()
	if grown == null:
		return _fail("after the extension the shed has no YardGround")
	if terrain.get_instance_id() != before:
		bad += _fail("the landscape was rebuilt by a tech purchase")
	var face:= warehouse.inner + Warehouse.WALL_T
	if not is_equal_approx(grown.global_position.x, face):
		bad += _fail("the yard is seated at x %.2f, and the wall is at %.2f"
			% [grown.global_position.x, face])
	else:
		print("  the wall moved to %.1f m and the yard came with it" % face)
	if absf(grown.global_position.z - door.global_position.z) > 0.01:
		bad += _fail("the track is at z %.2f and the doorway at %.2f"
			% [grown.global_position.z, door.global_position.z])
	else:
		print("  the track is still on the doorway's centreline")
	Tech.reset()
	return bad


func _yard_ground() -> YardGround:
	for child in warehouse.get_children():
		if child is YardGround:
			return child
	return null


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true
	Tech.reset()
	door.set_open_amount(1.0)
	await get_tree().process_frame


	player.set_physics_process(false)
	player.set_process(false)

	var centre:= door.global_position
	var out:= Vector3(1.0, 0.0, 0.0)


	await _look_from(centre - out * 5.0 + Vector3(0.0, 1.66, 0.0),
		centre + out * 90.0 + Vector3(0.0, 6.0, 0.0))
	await _shot(out_dir, "yard_from_inside.png")


	await _look_from(centre + out * 1.0 + Vector3(0.0, 1.66, 3.5),
		centre + out * 140.0 + Vector3(0.0, 8.0, 0.0))
	await _shot(out_dir, "yard_from_door.png")


	await _look_from(centre + out * 60.0 + Vector3(0.0, 1.66, 0.0),
		centre + out * 300.0 + Vector3(0.0, 14.0, 0.0))
	await _shot(out_dir, "yard_down_track.png")
	await _look_from(centre + out * 46.0 + Vector3(0.0, 1.66, 6.0), centre + Vector3(0.0, 4.0, 0.0))
	await _shot(out_dir, "yard_back_at_shed.png")


	await _look_from(centre + out * 120.0 + Vector3(0.0, 55.0, 0.0),
		centre + out * 260.0 + Vector3(0.0, 0.0, 0.0))
	await _shot(out_dir, "yard_from_above.png")
	get_tree().quit(0)


func _look_from(eye: Vector3, at: Vector3) -> void:
	player.global_position = eye
	player.look_at_from_position(eye, at, Vector3.UP)
	player.rotation.x = 0.0
	var to_at:= at - eye
	player.head.rotation.x = atan2(to_at.y, Vector2(to_at.x, to_at.z).length())
	await get_tree().process_frame


func _shot(out_dir: String, shot_name: String) -> void:
	for _i in 16:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, shot_name]
	img.save_png(path)
	print("[yardshot] wrote %s" % path)
