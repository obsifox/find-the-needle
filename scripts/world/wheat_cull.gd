class_name WheatCull
extends RefCounted


const WHEAT_ID:= 3


const MARGIN:= 1.2

var terrain: Terrain3D
var warehouse: Warehouse


var pad: Node3D


func cull() -> int:
	if terrain == null or terrain.data == null or warehouse == null:
		return 0
	var half:= warehouse.inner + Warehouse.WALL_T + MARGIN
	var to_shed:= warehouse.global_transform.affine_inverse()
	var to_pad:= pad.global_transform.affine_inverse() if pad != null else Transform3D()
	var gone:= 0
	for loc in terrain.data.get_region_locations():
		var region: Terrain3DRegion = terrain.data.get_region(loc)
		if region == null:
			continue
		var inst: Dictionary = region.get_instances()
		if inst.is_empty():
			continue


		var origin:= Vector3(float(loc.x), 0.0, float(loc.y)) * float(terrain.get_region_size()) * terrain.get_vertex_spacing()
		var touched:= false
		for id in inst.keys():
			var cells: Dictionary = inst [id]
			var gone_here:= _cull_cells(cells, origin, to_shed, half, to_pad)
			if gone_here == 0:
				continue
			gone += gone_here
			touched = true
			if cells.is_empty():
				inst.erase(id)
			else:
				inst [id] = cells
		if not touched:
			continue
		region.set_instances(inst)
		_forget(region)
	if gone > 0:
		terrain.instancer.update_mmis(true)
	return gone


func _cull_cells(cells: Dictionary, origin: Vector3, to_shed: Transform3D,
		half: float, to_pad: Transform3D) -> int:
	var gone:= 0
	for cell in cells.keys():
		var entry: Array = cells [cell]
		var kept: Array [Transform3D] = []
		var tints:= PackedColorArray()
		var i:= 0
		for xf in entry [0]:
			var at: Vector3 = origin + xf.origin
			if _swallowed(at, to_shed, half, to_pad):
				gone += 1
			else:
				kept.append(xf)
				tints.append(entry [1] [i] if i < entry [1].size() else Color.WHITE)
			i += 1
		if kept.size() == entry [0].size():
			continue
		if kept.is_empty():
			cells.erase(cell)
		else:
			cells [cell] = [kept, tints, entry [2]]
	return gone


func _swallowed(at: Vector3, to_shed: Transform3D, half: float,
		to_pad: Transform3D) -> bool:
	var s:= to_shed * at


	if warehouse.encloses(s, half - warehouse.inner):
		return true
	if pad == null:
		return false
	var p:= to_pad * at
	return absf(p.x) <= YardGround.PAD_HALF + MARGIN and p.z >= - MARGIN and p.z <= YardGround.PAD_OUT + MARGIN


func _forget(region: Terrain3DRegion) -> void:
	region.set_modified(false)
	region.set_edited(false)
