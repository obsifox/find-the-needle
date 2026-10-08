class_name BeltBatch
extends Node3D


const TILE:= 32.0


static var instance: BeltBatch = null


var _records: Dictionary = { }


var _buckets: Dictionary = { }


var _dirty: Dictionary = { }


var _tints: Dictionary = { }


var _tint_dirty: Dictionary = { }
static var source_culling_enabled:= not ("--legacy-belt-source-culling" in OS.get_cmdline_user_args())


func _init() -> void:


	top_level = true


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func adopt(node: GeometryInstance3D) -> void:
	if instance == null:
		if node == null or not node.is_inside_tree():
			return
		var scene:= node.get_tree().current_scene
		if scene == null:
			return
		var made:= BeltBatch.new()
		made.name = "BeltBatch"
		scene.add_child(made)
	instance.add(node)


static func set_layers(node: GeometryInstance3D, mask: int) -> void:
	if node == null or node.layers == mask:
		return
	var rid:= node.get_instance()
	if not rid.is_valid() or not node.is_inside_tree():
		node.layers = mask
		return
	RenderingServer.instance_set_visible(rid, false)
	node.layers = mask
	RenderingServer.instance_set_visible(rid, node.is_visible_in_tree())


static func changed(node: GeometryInstance3D) -> void:
	if instance != null:
		instance.touch(node)


static func keep_local(mmi: MultiMeshInstance3D, xforms: Array [Transform3D]) -> void:
	mmi.set_meta(LOCAL_META, xforms.duplicate())


const LOCAL_META:= &"belt_batch_local"


static var handed_over_enabled: bool = not ("--oldbatch" in OS.get_cmdline_user_args())


func add(node: GeometryInstance3D) -> void:
	if node == null or _records.has(node.get_instance_id()):
		return
	_records [node.get_instance_id()] = { "node": node, "keys": [] as Array [String] }


	set_layers(node, 0)
	if source_culling_enabled:
		RenderingServer.instance_set_visible(node.get_instance(), false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	node.visibility_changed.connect(_on_record_visibility.bind(node))
	node.tree_exiting.connect(_on_record_leaving.bind(node))
	touch(node)


func touch(node: GeometryInstance3D) -> void:
	if node == null:
		return
	var id:= node.get_instance_id()
	var rec: Dictionary = _records.get(id, { })
	if rec.is_empty():
		return
	_withdraw(id, rec)
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree():
		return
	var keys: Array [String] = []
	for pair in _instances_of(node, rec):
		var xf: Transform3D = pair [0]
		var mesh: Mesh = pair [1]
		if mesh == null:
			continue
		var key:= _key(xf.origin, mesh)
		var bucket: Dictionary = _buckets.get(key, { })
		if bucket.is_empty():
			bucket = { "mmi": null, "mesh": mesh, "by": { } }
			_buckets [key] = bucket
		var by: Dictionary = bucket ["by"]
		if not by.has(id):
			by [id] = [] as Array [Transform3D]
			keys.append(key)
		(by [id] as Array [Transform3D]).append(xf)
		_dirty [key] = true
	rec ["keys"] = keys


func drop(node: GeometryInstance3D) -> void:
	if node == null:
		return
	var id:= node.get_instance_id()
	var rec: Dictionary = _records.get(id, { })
	if rec.is_empty():
		return
	_withdraw(id, rec)
	_records.erase(id)
	_tints.erase(id)
	if is_instance_valid(node):
		set_layers(node, 1)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if node.is_inside_tree():
			RenderingServer.instance_set_visible(node.get_instance(), node.is_visible_in_tree())
		var visibility_callback:= _on_record_visibility.bind(node)
		var leaving_callback:= _on_record_leaving.bind(node)
		if node.visibility_changed.is_connected(visibility_callback):
			node.visibility_changed.disconnect(visibility_callback)
		if node.tree_exiting.is_connected(leaving_callback):
			node.tree_exiting.disconnect(leaving_callback)


func holds(node: GeometryInstance3D) -> bool:
	return node != null and _records.has(node.get_instance_id())


func set_tint(node: GeometryInstance3D, material: Material) -> bool:
	if node == null:
		return false
	var id:= node.get_instance_id()
	var rec: Dictionary = _records.get(id, { })
	if rec.is_empty():
		return false
	var had: Variant = _tints.get(id)
	if had == material:
		return true
	if material == null:
		_tints.erase(id)
	else:
		_tints [id] = material
	for key: String in (rec ["keys"] as Array [String]):
		_tint_dirty [key] = true
	return true


func tint_of(node: GeometryInstance3D) -> Material:
	if node == null:
		return null
	return _tints.get(node.get_instance_id()) as Material


func _on_record_visibility(node: GeometryInstance3D) -> void:
	touch(node)
	if source_culling_enabled and holds(node):
		RenderingServer.instance_set_visible(node.get_instance(), false)


func refresh_source_culling() -> void:
	for record: Dictionary in _records.values():
		var node: GeometryInstance3D = record ["node"]
		if is_instance_valid(node) and node.is_inside_tree():
			RenderingServer.instance_set_visible(node.get_instance(),
				not source_culling_enabled and node.is_visible_in_tree())


func _on_record_leaving(node: GeometryInstance3D) -> void:
	drop(node)


func _instances_of(node: GeometryInstance3D, rec: Dictionary) -> Array:
	var out: Array = []
	var mmi:= node as MultiMeshInstance3D
	if mmi != null:
		var mm:= mmi.multimesh
		if mm == null or mm.mesh == null:
			return out


		var at:= mmi.global_transform
		var local: Array = rec.get("local", [])
		if local.size() != mm.instance_count:
			local = _handed_over(mmi, mm)
			rec ["local"] = local
		for xf: Transform3D in local:
			out.append([at * xf, mm.mesh])
		return out
	var mi:= node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append([mi.global_transform, mi.mesh])
	return out


func _handed_over(mmi: MultiMeshInstance3D, mm: MultiMesh) -> Array:
	var kept: Variant = mmi.get_meta(LOCAL_META, null) if handed_over_enabled else null
	if kept is Array and (kept as Array).size() == mm.instance_count:
		return kept
	var out: Array = []
	for i in mm.instance_count:
		out.append(mm.get_instance_transform(i))
	return out


func _key(at: Vector3, mesh: Mesh) -> String:


	return "%d_%d_%d" % [floori(at.x / TILE), floori(at.z / TILE),
		mesh.get_instance_id()]


func _withdraw(id: int, rec: Dictionary) -> void:
	for key: String in (rec ["keys"] as Array [String]):
		var bucket: Dictionary = _buckets.get(key, { })
		if bucket.is_empty():
			continue
		(bucket ["by"] as Dictionary).erase(id)
		_dirty [key] = true
	rec ["keys"] = [] as Array [String]


func _process(_delta: float) -> void:
	if _dirty.is_empty() and _tint_dirty.is_empty():
		return
	var t:= Time.get_ticks_usec()
	var keys:= _dirty.keys()
	_dirty.clear()
	for key: String in keys:
		_flush(key)
		_tint_dirty [key] = true
	var tinted:= _tint_dirty.keys()
	_tint_dirty.clear()
	for key: String in tinted:
		_flush_tint(key)
	HotSpots.add(&"frame belt tiles", t)


func _flush(key: String) -> void:
	var bucket: Dictionary = _buckets.get(key, { })
	if bucket.is_empty():
		return
	var by: Dictionary = bucket ["by"]
	var total:= 0
	for id: int in by:
		total += (by [id] as Array [Transform3D]).size()


	var held = bucket ["mmi"]
	var mmi:= held as MultiMeshInstance3D if is_instance_valid(held) else null
	if total == 0:


		_free_node(mmi)
		var tints: Dictionary = bucket.get("tint", { })
		for mat_id: int in tints:
			_free_node(tints [mat_id])
		_buckets.erase(key)
		return
	var packed:= _pack(by, by.keys(), (bucket ["mesh"] as Mesh).get_aabb())
	if mmi == null:
		mmi = _new_tile(bucket ["mesh"], "Tile_" + key)
		bucket ["mmi"] = mmi
	_write_tile(mmi, packed)


func _flush_tint(key: String) -> void:
	var bucket: Dictionary = _buckets.get(key, { })
	if bucket.is_empty():
		return
	var tints: Dictionary = bucket.get("tint", { })
	if tints.is_empty() and _tints.is_empty():
		return
	var by: Dictionary = bucket ["by"]

	var groups: Dictionary = { }
	if not _tints.is_empty():
		for id: int in by:
			var mat: Material = _tints.get(id) as Material
			if mat == null:
				continue
			var mat_id:= mat.get_instance_id()
			if not groups.has(mat_id):
				groups [mat_id] = [mat, []]
			(groups [mat_id] [1] as Array).append(id)
	for mat_id: int in tints.keys():
		if not groups.has(mat_id):
			_free_node(tints [mat_id])
			tints.erase(mat_id)
	if groups.is_empty():
		bucket.erase("tint")
		return
	var mesh_box: AABB = (bucket ["mesh"] as Mesh).get_aabb()
	for mat_id: int in groups:
		var mat: Material = groups [mat_id] [0]
		var packed:= _pack(by, groups [mat_id] [1], mesh_box)
		var held = tints.get(mat_id)
		var mmi:= held as MultiMeshInstance3D if is_instance_valid(held) else null
		if mmi == null:
			mmi = _new_tile(bucket ["mesh"], "Tint_%s_%d" % [key, mat_id])


			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			tints [mat_id] = mmi
		if mmi.material_override != mat:
			mmi.material_override = mat
		_write_tile(mmi, packed)
	bucket ["tint"] = tints


func _pack(by: Dictionary, ids: Array, mesh_box: AABB) -> Array:
	var total:= 0
	for id: int in ids:
		total += (by [id] as Array [Transform3D]).size()
	var data:= PackedFloat32Array()
	data.resize(total * 12)
	var w:= 0


	var box:= AABB()
	var first:= true
	for id: int in ids:
		for xf: Transform3D in (by [id] as Array [Transform3D]):
			var b:= xf.basis
			var o:= xf.origin
			data [w] = b.x.x; data [w + 1] = b.y.x; data [w + 2] = b.z.x; data [w + 3] = o.x
			data [w + 4] = b.x.y; data [w + 5] = b.y.y; data [w + 6] = b.z.y; data [w + 7] = o.y
			data [w + 8] = b.x.z; data [w + 9] = b.y.z; data [w + 10] = b.z.z; data [w + 11] = o.z
			w += 12
			var here:= xf * mesh_box
			box = here if first else box.merge(here)
			first = false
	return [data, total, box]


func _new_tile(mesh: Mesh, called: String) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = called
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


func _write_tile(mmi: MultiMeshInstance3D, packed: Array) -> void:
	var box: AABB = packed [2]
	mmi.multimesh.instance_count = int(packed [1])
	mmi.multimesh.buffer = packed [0]
	mmi.custom_aabb = box
	mmi.multimesh.custom_aabb = box


func _free_node(held: Variant) -> void:
	if not is_instance_valid(held):
		return
	var node:= held as Node
	if node.get_parent() == self:
		remove_child(node)
	node.queue_free()


func census() -> Array [int]:
	var instances:= 0
	for key: String in _buckets:
		var by: Dictionary = (_buckets [key] as Dictionary) ["by"]
		for id: int in by:
			instances += (by [id] as Array [Transform3D]).size()
	return [_buckets.size(), instances, _records.size()]
