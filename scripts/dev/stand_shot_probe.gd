class_name DevStandShotProbe
extends Node


const DIG_STAND:= 1.5

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().physics_frame

	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var bad:= 0
	bad += _clearance("stand", world.stand, true)
	bad += _clearance("shop", world.shop, true)
	await _walk(out_dir, "stand_walk.png")
	await _outside(out_dir, "stand_outside.png")
	await _plan(out_dir, "stand_plan.png")


	Tech.grant("yard_space", TechTree.max_rank("yard_space"))
	await get_tree().process_frame
	await get_tree().process_frame
	bad += _clearance("stand, extended", world.stand, false)
	bad += _clearance("shop, extended", world.shop, false)
	await _plan(out_dir, "stand_plan_extended.png")
	print("[standshot] %s  (pile %s)" % ["PASS" if bad == 0 else "%d FAILURE(S)" % bad,
		Cfg.pile_size_id])
	get_tree().quit(0)


func _clearance(what: String, building: Node3D, hay_too: bool) -> int:
	var shed: Warehouse = world.warehouse

	var steel:= Warehouse.COL_HALF * 2.0
	var wall:= INF
	var hay:= INF
	var to_world:= building.global_transform
	for mi: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var box:= building.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		var lo:= box.position
		var hi:= box.end
		var nx:= maxi(1, ceili((hi.x - lo.x) / 0.5))
		var nz:= maxi(1, ceili((hi.z - lo.z) / 0.5))
		for i in nx + 1:
			for j in nz + 1:
				var p:= to_world * Vector3(lerpf(lo.x, hi.x, float(i) / nx), lo.y,
					lerpf(lo.z, hi.z, float(j) / nz))
				wall = minf(wall, minf(shed.inner - absf(p.x),
					minf(shed.inner - p.z, p.z - shed.z_lo())))


				if hay_too and lo.y < 0.6:
					var h: float = world.field.height_at(p.x, p.z)
					if h > 0.05:
						hay = minf(hay, - h)
					else:
						hay = minf(hay, _hay_gap(p))
	var fails:= 0
	var line:= "[standshot] %s: %.2f m to the nearest wall (%.2f m past the columns)" % [what, wall, wall - steel]
	if hay_too:
		line += ", %.2f m from the hay" % hay
	print(line)
	if wall - steel < 0.0:
		print("  FAIL %s reaches into the wall or its columns" % what)
		fails += 1
	if hay_too and hay < 0.0:
		print("  FAIL %s stands in the hay" % what)
		fails += 1
	return fails


func _hay_gap(p: Vector3) -> float:
	var flat:= Vector2(p.x, p.z)
	var dir:= flat.normalized()
	return flat.length() - _edge(world.field, dir)


func _walk(out_dir: String, name: String) -> void:
	var stand: HaySellingStand = world.stand
	var tail: Vector3 = stand.to_global(stand._belt_tail)
	var dir:= Vector2(tail.x, tail.z).normalized()
	var edge:= _edge(world.field, dir)
	var foot:= dir * (edge + DIG_STAND)
	var at:= Vector3(foot.x, 1.66, foot.y)
	player.global_position = at
	player.look_at_from_position(at, Vector3(tail.x, at.y, tail.z), Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = deg_to_rad(-6.0)
	await _save(out_dir, name, "from the hay, %.1f m to the intake"
		% (Vector2(tail.x, tail.z).length() - edge - DIG_STAND))


func _outside(out_dir: String, name: String) -> void:
	var shed: Warehouse = world.warehouse
	var half:= shed.inner
	var cam:= Camera3D.new()
	cam.fov = 55.0
	cam.far = 4000.0
	world.add_child(cam)
	var at:= Vector3(half * 1.9, half * 0.7, shed.z_lo() - half * 1.1)
	cam.look_at_from_position(at, Vector3(0.0, half * 0.2, shed.z_mid()), Vector3.UP)
	cam.make_current()
	await _save(out_dir, name, "outside")
	cam.queue_free()
	player.camera.make_current()


func _plan(out_dir: String, name: String) -> void:
	var shed: Warehouse = world.warehouse
	for child in shed.get_children():
		var n:= child as Node3D
		if n == null:
			continue
		var roof:= n.name.begins_with("Shell") or n.name.begins_with("Gable") or n.name in ["Ribs", "Purlins", "Verges", "EavesRail"] or n.position.y > Warehouse.WALL_H - 0.5
		if roof:
			n.visible = false
	var cam:= Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(shed.span_z(), shed.inner * 2.0) + 6.0
	cam.far = 200.0
	world.add_child(cam)
	cam.position = Vector3(0.0, 45.0, shed.z_mid())
	cam.rotation = Vector3(- PI * 0.5, 0.0, 0.0)
	cam.make_current()
	await _save(out_dir, name, "plan, %.1f by %.1f m inside"
		% [shed.inner * 2.0, shed.span_z()])
	cam.queue_free()
	player.camera.make_current()


func _save(out_dir: String, name: String, what: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("[standshot] wrote %s  (%s)" % [path, what])


func _edge(field: HayField, dir: Vector2) -> float:
	var r:= 0.0
	while r < 40.0:
		var p:= dir * r
		if field.height_at(p.x, p.y) < 0.05:
			return r
		r += 0.05
	return r
