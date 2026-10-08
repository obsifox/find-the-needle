class_name DevWheatProbe
extends Node


var world: Node3D
var warehouse: Warehouse
var terrain: YardTerrain


func run() -> void:
	if world != null:
		world.block_save = true
	_report_space()
	var fails:= await _check_cull()
	Tech.reset()
	print("\r\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_cull() -> int:
	print("\r\n-- cull --")
	var fails:= 0
	var top:= TechTree.max_rank("yard_space")

	var widest:= Cfg.yard_inner_for_pile() + Tech.YARD_METRES_PER_RANK * float(top) + Warehouse.WALL_T
	var doomed:= _standing_inside(widest)
	var before:= _total()
	var drawn_before:= _drawn()
	print("  %d stalks on the map, %d of them inside the widest shed (%.1f m)"
		% [before, doomed, widest])
	var props_doomed:= _painted_inside(widest) - doomed
	print("  %d other painted props (bales, windrows) inside the widest shed"
		% props_doomed)
	if doomed == 0:
		fails += _fail("no painted wheat stands where the shed ever reaches, so"
			+ " this run proves nothing. Has the wheat moved, or the id?")
	if _standing_inside(warehouse.inner + Warehouse.WALL_T) != 0:
		fails += _fail("wheat inside the STOCK shed before any rank was bought:"
			+ " the cull is not running at startup")

	Tech.grant("yard_space", top)
	await get_tree().process_frame
	var inside:= _standing_inside(warehouse.inner + Warehouse.WALL_T)
	var after:= _total()
	print("  shed at rank %d: half width %.1f m, %d stalks left, %d taken"
		% [top, warehouse.inner, after, before - after])
	if inside != 0:
		fails += _fail("%d stalks still standing inside the shed" % inside)
	var props_inside:= _painted_inside(warehouse.inner + Warehouse.WALL_T)
	print("  %d painted props of any kind left inside it" % props_inside)
	if props_inside != 0:
		fails += _fail("%d painted props (bales, windrows) still standing inside the shed"
			% props_inside)
	if before - after == 0:
		fails += _fail("the rank up took nothing out at all")
	if after < before - doomed - 4000:
		fails += _fail("%d stalks went and only %d were in the way: the cull is"
			+ " eating the field" % [before - after, doomed])


	var drawn_after:= _drawn()
	if drawn_before == 0:
		print("  nothing is drawing wheat, so the renderer half is untested."
			+ " Run --wheat windowed as well as headless.")
	else:
		print("  the renderer held %d stalks and now holds %d"
			% [drawn_before, drawn_after])
		if drawn_after >= drawn_before:
			fails += _fail("the multimeshes never lost a stalk: the data was"
				+ " edited and the renderer was not told")
	return fails


func _report_space() -> void:
	var t3d:= terrain.terrain()
	print("\n-- terrain --")
	print("  region size %d, vertex spacing %.2f, locations %s"
		% [t3d.get_region_size(), t3d.get_vertex_spacing(),
			t3d.data.get_region_locations()])

	print("\n-- mmis --")
	var mmis:= _find_mmis(t3d)
	for i in mini(6, mmis.size()):
		var mmi:= mmis [i]
		print("  %s at %s, %d instances"
			% [mmi.name, mmi.global_transform.origin,
				mmi.multimesh.instance_count if mmi.multimesh != null else -1])
	print("  %d multimesh instances in total, %d stalks handed to the renderer"
		% [mmis.size(), _drawn()])

	print("\n-- wheat, as the region files hold it --")
	for loc in t3d.data.get_region_locations():
		var region:= t3d.data.get_region(loc)
		var inst: Dictionary = region.get_instances()
		if not inst.has(WheatCull.WHEAT_ID):
			continue
		var cells: Dictionary = inst [WheatCull.WHEAT_ID]
		var lo:= Vector3(1000000000.0, 1000000000.0, 1000000000.0)
		var hi:= - lo
		var n:= 0
		for cell in cells:
			for xf in cells [cell] [0]:
				lo = lo.min(xf.origin)
				hi = hi.max(xf.origin)
				n += 1
		print("  region %s: %d cells, %d stalks, x[%.1f %.1f] z[%.1f %.1f]"
			% [loc, cells.size(), n, lo.x, hi.x, lo.z, hi.z])


func _standing_inside(half: float) -> int:
	var t3d:= terrain.terrain()
	var to_shed:= warehouse.global_transform.affine_inverse()
	var n:= 0
	for loc in t3d.data.get_region_locations():
		var region: Terrain3DRegion = t3d.data.get_region(loc)
		var inst: Dictionary = region.get_instances()
		if not inst.has(WheatCull.WHEAT_ID):
			continue
		var origin:= Vector3(float(loc.x), 0.0, float(loc.y)) * float(t3d.get_region_size()) * t3d.get_vertex_spacing()
		for cell in inst [WheatCull.WHEAT_ID]:
			for xf in inst [WheatCull.WHEAT_ID] [cell] [0]:
				var s: Vector3 = to_shed * (origin + xf.origin)
				if _in_shed(s, half):
					n += 1
	return n


func _painted_inside(half: float) -> int:
	var t3d:= terrain.terrain()
	var to_shed:= warehouse.global_transform.affine_inverse()
	var n:= 0
	for loc in t3d.data.get_region_locations():
		var inst: Dictionary = t3d.data.get_region(loc).get_instances()
		var origin:= Vector3(float(loc.x), 0.0, float(loc.y)) * float(t3d.get_region_size()) * t3d.get_vertex_spacing()
		for id in inst:
			for cell in inst [id]:
				for xf in inst [id] [cell] [0]:
					var s: Vector3 = to_shed * (origin + xf.origin)
					if _in_shed(s, half):
						n += 1
	return n


func _total() -> int:
	var t3d:= terrain.terrain()
	var n:= 0
	for loc in t3d.data.get_region_locations():
		var inst: Dictionary = t3d.data.get_region(loc).get_instances()
		if not inst.has(WheatCull.WHEAT_ID):
			continue
		for cell in inst [WheatCull.WHEAT_ID]:
			n += inst [WheatCull.WHEAT_ID] [cell] [0].size()
	return n


func _find_mmis(from: Node) -> Array [MultiMeshInstance3D]:
	var out: Array [MultiMeshInstance3D] = []
	for child in from.get_children():
		if child is MultiMeshInstance3D:
			out.append(child)
		out.append_array(_find_mmis(child))
	return out


func _drawn() -> int:
	var n:= 0
	for mmi in _find_mmis(terrain.terrain()):


		if not mmi.name.ends_with("_M%d_L0" % WheatCull.WHEAT_ID):
			continue
		if mmi.multimesh != null:
			n += mmi.multimesh.instance_count
	return n


func _in_shed(s: Vector3, half: float) -> bool:
	var long:= Warehouse.long_for(half - Warehouse.WALL_T)
	return absf(s.x) <= half and s.z <= half and s.z >= - half - long
