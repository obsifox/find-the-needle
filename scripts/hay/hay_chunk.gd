class_name HayChunk
extends Node3D


var field: HayField
var cx0: int
var cz0: int
var cw: int
var ch: int

var _slot_cells: PackedInt32Array = PackedInt32Array()
var _cell_ordinal: Dictionary = { }
var _cell_live: PackedInt32Array = PackedInt32Array()
var _cell_coloured: PackedInt32Array = PackedInt32Array()


var _crust:= CrustCells.new()

var _mmi: MultiMeshInstance3D
var _mm: MultiMesh


var _instance_buffer: PackedFloat32Array = PackedFloat32Array()


var _scatter_samples:= PackedFloat32Array()
var _instance_buffer_dirty:= false
var _body: StaticBody3D
var _shape: ConcavePolygonShape3D
var _coll: CollisionShape3D
var _has_collision:= false
var _surf_mi: MultiMeshInstance3D
var _surf_mm: MultiMesh
var _surf_mesh: ArrayMesh
var _shadow_mi: MeshInstance3D
var _occ_inst: OccluderInstance3D
var _occ: ArrayOccluder3D


var _strands_per_cell: int = 1
var _lod_visible_k: int = -1
var _min_h:= 0.0
var _max_h:= 0.0


static var profile_grid_usec:= 0
static var profile_shape_usec:= 0
static var profile_surface_usec:= 0
static var profile_rebuilds:= 0
static var cached_scatter_enabled:= not ("--legacy-crust-scatter" in OS.get_cmdline_user_args())


const PARK_Y:= -1000.0
const PARKED_XFORM:= Transform3D(Basis.IDENTITY, Vector3(0.0, PARK_Y, 0.0))
const INSTANCE_STRIDE:= 16


func setup(p_field: HayField, p_cx0: int, p_cz0: int, p_cw: int, p_ch: int) -> void:
	field = p_field
	cx0 = p_cx0
	cz0 = p_cz0
	cw = p_cw
	ch = p_ch
	_strands_per_cell = Cfg.crust_strands_per_cell
	name = "Chunk_%d_%d" % [cx0, cz0]

	_build_slot_table()
	_build_nodes()


func _build_slot_table() -> void:
	var nc:= Cfg.field_cells()
	var mask_r: float = field.crust_radius
	var mask_r2:= mask_r * mask_r
	for j in range(cz0, cz0 + ch):
		for i in range(cx0, cx0 + cw):
			var c:= field.cell_center(i, j)
			var dx: float = c.x - Cfg.PILE_CENTER.x
			var dz: float = c.z - Cfg.PILE_CENTER.z
			if dx * dx + dz * dz > mask_r2:
				continue
			var gc:= j * nc + i
			_cell_ordinal [gc] = _slot_cells.size()
			_slot_cells.append(gc)
	_cell_live.resize(_slot_cells.size())
	_cell_live.fill(0)
	_cell_coloured.resize(_slot_cells.size())
	_cell_coloured.fill(0)


func _build_nodes() -> void:
	_body = StaticBody3D.new()
	_body.name = "Surface"
	_body.collision_layer = Cfg.L_PILE
	_body.collision_mask = 0
	_body.physics_material_override = StrandFactory.hay_physics_material()
	_coll = CollisionShape3D.new()
	_shape = ConcavePolygonShape3D.new()
	_shape.backface_collision = false
	_coll.shape = _shape
	_body.add_child(_coll)
	add_child(_body)
	_body.set_meta("hay_chunk", self)

	if _slot_cells.is_empty():
		return


	_surf_mesh = ArrayMesh.new()
	_surf_mm = MultiMesh.new()
	_surf_mm.transform_format = MultiMesh.TRANSFORM_3D
	_surf_mm.mesh = _surf_mesh
	_surf_mm.instance_count = Cfg.HAY_SHELLS
	for k in Cfg.HAY_SHELLS:
		_surf_mm.set_instance_transform(k, Transform3D.IDENTITY)
	_surf_mi = MultiMeshInstance3D.new()
	_surf_mi.name = "Shell"
	_surf_mi.multimesh = _surf_mm
	_surf_mi.material_override = StrandFactory.pile_surface_material()


	_surf_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	_surf_mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(_surf_mi)


	_shadow_mi = MeshInstance3D.new()
	_shadow_mi.name = "ShadowProxy"
	_shadow_mi.mesh = _surf_mesh
	_shadow_mi.material_override = StrandFactory.shadow_proxy_material()
	_shadow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


	_shadow_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_shadow_mi)


	_occ = ArrayOccluder3D.new()
	_occ_inst = OccluderInstance3D.new()
	_occ_inst.name = "Occluder"
	_occ_inst.occluder = _occ
	add_child(_occ_inst)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = StrandFactory.strand_mesh()
	_mm.instance_count = _slot_cells.size() * _strands_per_cell
	_mm.visible_instance_count = 0
	_park_all_slots()
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Crust"
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


	_mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(_mmi)


func has_crust() -> bool:
	return _mm != null


func top_height() -> float:
	return _max_h


func owns_cell(gc: int) -> bool:
	return _cell_ordinal.has(gc)


func drawn_instances() -> int:
	return 0 if _mm == null else _mm.visible_instance_count


func rebuild_collision() -> void:
	var profile_t0:= Time.get_ticks_usec()
	var stride:= cw + 1
	var surface_verts:= PackedVector3Array()
	surface_verts.resize((cw + 1) * (ch + 1))
	_min_h = INF
	_max_h = - INF


	for local_j in ch + 1:
		for local_i in cw + 1:
			var k:= local_j * stride + local_i
			var v:= field.vertex_pos(cx0 + local_i, cz0 + local_j)
			surface_verts [k] = v
			var h:= v.y
			_min_h = minf(_min_h, h)
			_max_h = maxf(_max_h, h)


	_refresh_aabb()


	if _max_h <= 0.02:
		if _has_collision:
			_shape.set_faces(PackedVector3Array())
			_has_collision = false
		if _surf_mesh != null and _surf_mesh.get_surface_count() > 0:
			_surf_mesh.clear_surfaces()


		if _occ != null:
			_occ.set_arrays(PackedVector3Array(), PackedInt32Array())
		profile_grid_usec += Time.get_ticks_usec() - profile_t0
		profile_rebuilds += 1
		return

	var indices:= PackedInt32Array()
	indices.resize(cw * ch * 6)
	var faces:= PackedVector3Array()
	faces.resize(indices.size())
	var f:= 0
	for local_j in ch:
		for local_i in cw:
			var v00:= local_j * stride + local_i
			var v10:= v00 + 1
			var v01:= v00 + stride
			var v11:= v01 + 1


			if maxf(surface_verts [v00].y,
					maxf(surface_verts [v11].y, surface_verts [v01].y)) > 0.02:
				indices [f] = v00
				indices [f + 1] = v11
				indices [f + 2] = v01
				for q in 3:
					faces [f + q] = surface_verts [indices [f + q]]
				f += 3
			if maxf(surface_verts [v00].y,
					maxf(surface_verts [v10].y, surface_verts [v11].y)) > 0.02:
				indices [f] = v00
				indices [f + 1] = v10
				indices [f + 2] = v11
				for q in 3:
					faces [f + q] = surface_verts [indices [f + q]]
				f += 3
	indices.resize(f)
	faces.resize(f)
	var profile_t1:= Time.get_ticks_usec()
	_shape.set_faces(faces)
	var profile_t2:= Time.get_ticks_usec()
	_has_collision = true
	_rebuild_surface_mesh(surface_verts, indices)
	var profile_t3:= Time.get_ticks_usec()
	profile_grid_usec += profile_t1 - profile_t0
	profile_shape_usec += profile_t2 - profile_t1
	profile_surface_usec += profile_t3 - profile_t2
	profile_rebuilds += 1


func rebuild_shell_renderer(surface_material: ShaderMaterial,
		shadow_material: ShaderMaterial) -> void:
	if _surf_mi != null:
		_surf_mesh = ArrayMesh.new()
		_surf_mm = MultiMesh.new()
		_surf_mm.transform_format = MultiMesh.TRANSFORM_3D
		_surf_mm.mesh = _surf_mesh
		_surf_mm.instance_count = Cfg.HAY_SHELLS
		for k in Cfg.HAY_SHELLS:
			_surf_mm.set_instance_transform(k, Transform3D.IDENTITY)
		_surf_mi.multimesh = _surf_mm
		_surf_mi.material_override = surface_material
	if _shadow_mi != null:
		_shadow_mi.mesh = _surf_mesh
		_shadow_mi.material_override = shadow_material
	rebuild_collision()


static func reset_rebuild_profile() -> void:
	profile_grid_usec = 0
	profile_shape_usec = 0
	profile_surface_usec = 0
	profile_rebuilds = 0


func _rebuild_surface_mesh(surface_verts: PackedVector3Array,
		indices: PackedInt32Array) -> void:
	if _surf_mesh == null:
		return
	_surf_mesh.clear_surfaces()
	var verts:= surface_verts.duplicate()
	var norms:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	var tans:= PackedFloat32Array()
	var grows:= PackedFloat32Array()
	norms.resize(verts.size())
	uvs.resize(verts.size())
	tans.resize(verts.size() * 4)
	grows.resize(verts.size() * 3)
	var stride:= cw + 1
	var smooth:= int(Cfg.HAY_SHELL_SMOOTH)
	for k in verts.size():
		var v:= surface_verts [k]
		var vi:= cx0 + k % stride
		var vj:= cz0 + k / stride
		var n:= field.normal_at_vertex(vi, vj)


		var d: float = field.shell_depth_at(v.x, v.z, n, field._sample_vertex(vi, vj))


		var grow:= field.normal_at_vertex(vi, vj, smooth) if smooth > 0 and float(smooth) == Cfg.HAY_SHELL_SMOOTH else field.normal_at_scale(v.x, v.z, Cfg.CELL * Cfg.HAY_SHELL_SMOOTH)


		var crop: float = minf(1.0, field.shell_length_limit(v.x, v.z, n,
			field.dug_depth_at_vertex(vi, vj)) / maxf(d, 0.0001))


		var stack: float = d * crop
		verts [k] = v - grow * stack
		norms [k] = n


		grows [k * 3] = grow.x
		grows [k * 3 + 1] = grow.y
		grows [k * 3 + 2] = grow.z


		var t:= grow - n * n.dot(grow)
		if t.length_squared() < 1e-08:
			t = n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT)
		t = t.normalized()
		tans [k * 4] = t.x
		tans [k * 4 + 1] = t.y
		tans [k * 4 + 2] = t.z
		tans [k * 4 + 3] = 1.0


		uvs [k] = Vector2(stack / Cfg.HAY_SHELL_DEPTH, crop)
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = norms
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	arrays [Mesh.ARRAY_TANGENT] = tans
	arrays [Mesh.ARRAY_CUSTOM0] = grows
	arrays [Mesh.ARRAY_INDEX] = indices


	_surf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], { },
		Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)


	if _occ != null:
		_occ.set_arrays(verts, indices)
	if _surf_mi != null:


		var o:= field.vertex_pos(cx0, cz0)
		var pad: float = Cfg.HAY_SHELL_DEPTH + 0.5
		_surf_mi.custom_aabb = AABB(
			Vector3(o.x - pad, - pad, o.z - pad),
			Vector3(cw * Cfg.CELL + pad * 2.0, _max_h + pad * 2.0, ch * Cfg.CELL + pad * 2.0))
		_surf_mm.custom_aabb = _surf_mi.custom_aabb


func set_density(per_cell: int) -> void:
	if _mm == null or per_cell == _strands_per_cell:
		return
	_strands_per_cell = per_cell


	_mm.instance_count = _slot_cells.size() * per_cell
	_mm.visible_instance_count = 0


	_park_all_slots()
	_cell_live.fill(0)
	_cell_coloured.fill(0)
	rebuild_all_cells()


func _park_all_slots() -> void:
	var n:= _mm.instance_count
	if n <= 0:
		_instance_buffer = PackedFloat32Array()
		_scatter_samples = PackedFloat32Array()
		_instance_buffer_dirty = false
		return
	var buf:= PackedFloat32Array()
	buf.resize(n * INSTANCE_STRIDE)
	_scatter_samples = PackedFloat32Array()
	_scatter_samples.resize(n * 4)


	var c: Color = Cfg.COL_HAY_DARK.lerp(Cfg.COL_HAY_LIGHT, 0.5)
	for i in n:
		var o:= i * INSTANCE_STRIDE
		buf [o] = 1.0
		buf [o + 5] = 1.0
		buf [o + 10] = 1.0
		buf [o + 7] = PARK_Y
		buf [o + 12] = c.r
		buf [o + 13] = c.g
		buf [o + 14] = c.b
		buf [o + 15] = 1.0
	_instance_buffer = buf
	_instance_buffer_dirty = true
	flush_instance_buffer()


func _buffer_set_transform(slot: int, xf: Transform3D) -> void:
	var o:= slot * INSTANCE_STRIDE
	var b:= xf.basis
	_instance_buffer [o] = b.x.x
	_instance_buffer [o + 1] = b.y.x
	_instance_buffer [o + 2] = b.z.x
	_instance_buffer [o + 3] = xf.origin.x
	_instance_buffer [o + 4] = b.x.y
	_instance_buffer [o + 5] = b.y.y
	_instance_buffer [o + 6] = b.z.y
	_instance_buffer [o + 7] = xf.origin.y
	_instance_buffer [o + 8] = b.x.z
	_instance_buffer [o + 9] = b.y.z
	_instance_buffer [o + 10] = b.z.z
	_instance_buffer [o + 11] = xf.origin.z
	_instance_buffer_dirty = true


func _park_slot(slot: int) -> void:
	_instance_buffer [slot * INSTANCE_STRIDE + 7] = PARK_Y
	_instance_buffer_dirty = true


func _buffer_get_transform(slot: int) -> Transform3D:
	var o:= slot * INSTANCE_STRIDE
	var b:= Basis(
		Vector3(_instance_buffer [o], _instance_buffer [o + 4], _instance_buffer [o + 8]),
		Vector3(_instance_buffer [o + 1], _instance_buffer [o + 5], _instance_buffer [o + 9]),
		Vector3(_instance_buffer [o + 2], _instance_buffer [o + 6], _instance_buffer [o + 10]))
	return Transform3D(b, Vector3(
		_instance_buffer [o + 3], _instance_buffer [o + 7], _instance_buffer [o + 11]))


func _buffer_set_color(slot: int, c: Color) -> void:
	var o:= slot * INSTANCE_STRIDE + 12
	_instance_buffer [o] = c.r
	_instance_buffer [o + 1] = c.g
	_instance_buffer [o + 2] = c.b
	_instance_buffer [o + 3] = c.a
	_instance_buffer_dirty = true


func _buffer_get_color(slot: int) -> Color:
	var o:= slot * INSTANCE_STRIDE + 12
	return Color(_instance_buffer [o], _instance_buffer [o + 1],
		_instance_buffer [o + 2], _instance_buffer [o + 3])


func flush_instance_buffer() -> void:
	if not _instance_buffer_dirty or _mm == null:
		return
	_mm.buffer = _instance_buffer
	_instance_buffer_dirty = false


func rebuild_all_cells() -> void:
	if _mm == null:
		return
	CrustCells.capture()
	lend_crust()
	for ord_i in _slot_cells.size():
		_crust.write_cell(ord_i, not cached_scatter_enabled)
	restore_crust()
	flush_instance_buffer()
	_refresh_aabb()
	_lod_visible_k = -1


func update_cell(gc: int) -> void:
	if _mm == null:
		return
	if not _cell_ordinal.has(gc):
		return
	_write_cell(int(_cell_ordinal [gc]))


func crust_ordinal(gc: int) -> int:
	if _mm == null:
		return -1
	return int(_cell_ordinal.get(gc, -1))


func _write_cell(ord_i: int, legacy: bool = false) -> void:
	CrustCells.capture()
	lend_crust()
	_crust.write_cell(ord_i, legacy or not cached_scatter_enabled)
	restore_crust()


func lend_crust() -> CrustCells:
	var job:= _crust
	job.heights = field.heights
	job.dome = field.dome
	job.nv = Cfg.field_verts()
	job.nc = Cfg.field_cells()
	job.slot_cells = _slot_cells
	job.cell_live = _cell_live
	job.cell_coloured = _cell_coloured
	job.instance_buffer = _instance_buffer
	job.scatter_samples = _scatter_samples
	job.strands_per_cell = _strands_per_cell
	job.dirty = false
	_cell_live = PackedInt32Array()
	_cell_coloured = PackedInt32Array()
	_instance_buffer = PackedFloat32Array()
	_scatter_samples = PackedFloat32Array()
	return job


func restore_crust() -> void:
	var job:= _crust
	_cell_live = job.cell_live
	_cell_coloured = job.cell_coloured
	_instance_buffer = job.instance_buffer
	_scatter_samples = job.scatter_samples
	if job.dirty:
		_instance_buffer_dirty = true
	job.heights = PackedFloat32Array()
	job.dome = PackedFloat32Array()
	job.cell_live = PackedInt32Array()
	job.cell_coloured = PackedInt32Array()
	job.instance_buffer = PackedFloat32Array()
	job.scatter_samples = PackedFloat32Array()


const SLOT_BITS:= 24
const SLOT_MASK:= (1 << SLOT_BITS) - 1


func _slots_in_sphere(center: Vector3, radius: float) -> PackedInt64Array:
	var found:= PackedInt64Array()
	if _mm == null:
		return found
	var n_cells:= _slot_cells.size()
	var r2:= radius * radius


	var reach:= radius + Cfg.CELL * 0.7072
	var visible:= _mm.visible_instance_count
	var nc:= Cfg.field_cells()
	var span:= int(ceil(radius / Cfg.CELL)) + 1
	var hit_cell:= field.cell_at(center.x, center.z)
	for dj: int in range(- span, span + 1):
		for di: int in range(- span, span + 1):
			var ci: int = hit_cell.x + di
			var cj: int = hit_cell.y + dj
			if ci < 0 or cj < 0 or ci >= nc or cj >= nc:
				continue
			var gc:= cj * nc + ci
			if not _cell_ordinal.has(gc):
				continue
			var cc:= field.cell_center(ci, cj)
			var ex:= cc.x - center.x
			var ez:= cc.z - center.z
			if ex * ex + ez * ez > reach * reach:
				continue
			var ord_i:= int(_cell_ordinal [gc])
			for k in _cell_live [ord_i]:
				var slot:= k * n_cells + ord_i
				if slot >= visible:
					continue
				var o:= slot * INSTANCE_STRIDE


				var bx:= _instance_buffer [o]
				var by:= _instance_buffer [o + 4]
				var bz:= _instance_buffer [o + 8]
				if bx * bx + by * by + bz * bz < 1e-09:
					continue
				var dx:= _instance_buffer [o + 3] - center.x
				var dy:= _instance_buffer [o + 7] - center.y
				var dz:= _instance_buffer [o + 11] - center.z
				var d:= dx * dx + dy * dy + dz * dz
				if d <= r2:
					found.append((int(d * 10000000.0) << SLOT_BITS) | slot)
	found.sort()
	return found


func _note_taken(slot: int) -> void:
	var ord_i:= slot % _slot_cells.size()


	field.mark_cell_dirty(_slot_cells [ord_i])


func take_in_sphere(center: Vector3, radius: float, budget: int) -> Array:
	var out: Array = []
	if budget <= 0:
		return out
	var found:= _slots_in_sphere(center, radius)
	for i in mini(budget, found.size()):
		var slot:= int(found [i] & SLOT_MASK)
		out.append({
			"transform": _buffer_get_transform(slot),
			"color": _buffer_get_color(slot),
		})
		_park_slot(slot)
		_note_taken(slot)
	flush_instance_buffer()
	return out


func count_in_sphere(center: Vector3, radius: float) -> int:
	return _slots_in_sphere(center, radius).size()


func _nearest_slot(world_pos: Vector3, max_dist: float,
		aim_from: Vector3 = Vector3.ZERO, aim_dir: Vector3 = Vector3.ZERO) -> int:
	if _mm == null:
		return -1
	var n_cells:= _slot_cells.size()
	var best:= -1
	var max_d2:= max_dist * max_dist
	var best_score:= INF
	var by_ray:= aim_dir.length_squared() > 1e-09


	var max_t:= (world_pos - aim_from).dot(aim_dir) + 0.12
	var visible:= _mm.visible_instance_count
	var nc:= Cfg.field_cells()

	var hit_cell:= field.cell_at(world_pos.x, world_pos.z)
	for dj: int in range(-1, 2):
		for di: int in range(-1, 2):
			var ci: int = hit_cell.x + di
			var cj: int = hit_cell.y + dj
			if ci < 0 or cj < 0 or ci >= nc or cj >= nc:
				continue
			if not _cell_ordinal.has(cj * nc + ci):
				continue
			var ord_i:= int(_cell_ordinal [cj * nc + ci])
			for k in _cell_live [ord_i]:
				var slot:= k * n_cells + ord_i
				if slot >= visible:
					continue
				var xf:= _buffer_get_transform(slot)
				if xf.basis.x.length_squared() < 1e-09:
					continue
				var d:= xf.origin.distance_squared_to(world_pos)
				if d > max_d2:
					continue
				var score:= d
				if by_ray:
					var v:= xf.origin - aim_from
					var t:= v.dot(aim_dir)
					if t > max_t:
						continue


					score = (v - aim_dir * t).length_squared()
				if score < best_score:
					best_score = score
					best = slot
	return best


func pluck_nearest(world_pos: Vector3, max_dist: float,
		aim_from: Vector3 = Vector3.ZERO, aim_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var best:= _nearest_slot(world_pos, max_dist, aim_from, aim_dir)
	if best < 0:
		return { }
	var out:= {
		"transform": _buffer_get_transform(best),
		"color": _buffer_get_color(best),
	}
	_park_slot(best)
	_note_taken(best)
	flush_instance_buffer()
	return out


func peek_nearest(world_pos: Vector3, max_dist: float,
		aim_from: Vector3 = Vector3.ZERO, aim_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var best:= _nearest_slot(world_pos, max_dist, aim_from, aim_dir)
	if best < 0:
		return { }
	return {
		"transform": _buffer_get_transform(best),
		"color": _buffer_get_color(best),
	}


func update_lod(cam_pos: Vector3, near: float = -1.0, far: float = -1.0) -> void:
	if _mm == null:
		return
	var center:= field.cell_center(cx0 + cw / 2, cz0 + ch / 2)
	center.y = (_min_h + _max_h) * 0.5
	var d:= cam_pos.distance_to(center)
	if near < 0.0:
		near = Cfg.effective_lod_near()
	if far < 0.0:
		far = Cfg.effective_lod_far()
	var t:= clampf(inverse_lerp(near, far, d), 0.0, 1.0)
	var frac:= lerpf(1.0, Cfg.crust_lod_min, t)
	var k:= clampi(int(ceil(_strands_per_cell * frac)), 1, _strands_per_cell)


	var want_shadow:= d <= Cfg.crust_shadow_distance
	var mode:= GeometryInstance3D.SHADOW_CASTING_SETTING_ON if want_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mmi.cast_shadow != mode:
		_mmi.cast_shadow = mode

	if k == _lod_visible_k:
		return
	_lod_visible_k = k
	_mm.visible_instance_count = k * _slot_cells.size()


func _refresh_aabb() -> void:
	if _mmi == null:
		return
	var o:= field.vertex_pos(cx0, cz0)
	var size:= Vector3(cw * Cfg.CELL, maxf(_max_h + 0.4, 0.5), ch * Cfg.CELL)
	_mmi.custom_aabb = AABB(Vector3(o.x, -0.2, o.z), size)


	_mm.custom_aabb = _mmi.custom_aabb
