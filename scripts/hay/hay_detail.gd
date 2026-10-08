class_name HayDetail
extends Node3D


const TILE_CELLS:= 8
const CELLS_PER_TILE:= TILE_CELLS * TILE_CELLS


const DEPTH:= 0.1

const FLAT_SHARE:= 0.45


const WRITE_BUDGET_USEC:= 900
const CELLS_PER_FRAME_CAP:= 160

const FADE_BAND:= 1.6


const PARK_Y:= -1000.0
const INSTANCE_STRIDE:= 16


const BANK:= 4096
const NO_TILE:= Vector2i(1 << 30, 1 << 30)

var field: HayField

var last_tick_usec:= 0

var _tile_m:= 2.0
var _radius:= 0.0
var _per_cell:= 0
var _offsets: Array [Vector2i] = []
var _nodes: Array [MultiMeshInstance3D] = []
var _mms: Array [MultiMesh] = []
var _bufs: Array [PackedFloat32Array] = []
var _tile_of_node: Array [Vector2i] = []
var _node_of_tile: Dictionary = { }
var _dirty: Array [PackedByteArray] = []
var _dirty_count: PackedInt32Array = PackedInt32Array()
var _cursor: PackedInt32Array = PackedInt32Array()
var _max_h: PackedFloat32Array = PackedFloat32Array()
var _pending: PackedInt32Array = PackedInt32Array()
var _center:= NO_TILE
var _eye:= Vector3.ZERO
var _mat: ShaderMaterial
var _rng:= RandomNumberGenerator.new()
var _bank_basis:= PackedFloat32Array()
var _bank_tint:= PackedFloat32Array()
var _park_template:= PackedFloat32Array()
var _shown_scale:= -1.0
static var hidden_updates_enabled:= "--legacy-hidden-detail-work" in OS.get_cmdline_user_args()


func _ready() -> void:
	_tile_m = TILE_CELLS * Cfg.CELL
	_build_bank()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/hay_strand.gdshader")


	_mat.set_shader_parameter("highlight_radius", 0.0)
	if field != null:
		field.cells_redrawn.connect(_on_cells_redrawn)
	reconfigure()


func reconfigure() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	_mms.clear()
	_bufs.clear()
	_tile_of_node.clear()
	_node_of_tile.clear()
	_dirty.clear()
	_offsets.clear()
	_pending = PackedInt32Array()
	_center = NO_TILE
	_shown_scale = -1.0
	_per_cell = 0
	_radius = Cfg.detail_radius
	var pool: int = Cfg.detail_strands
	if pool <= 0 or _radius <= 0.0:
		return
	var reach:= int(ceil(_radius / _tile_m))


	var keep:= _radius + _tile_m * 0.71
	for dj in range(- reach, reach + 1):
		for di in range(- reach, reach + 1):
			if Vector2(di, dj).length() * _tile_m <= keep:
				_offsets.append(Vector2i(di, dj))
	_offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	var tiles:= _offsets.size()
	_per_cell = maxi(1, pool / (tiles * CELLS_PER_TILE))
	var per_tile:= _per_cell * CELLS_PER_TILE

	_park_template = PackedFloat32Array()
	_park_template.resize(per_tile * INSTANCE_STRIDE)
	var c: Color = Cfg.COL_HAY_DARK.lerp(Cfg.COL_HAY_LIGHT, 0.5)
	for i in per_tile:
		var o:= i * INSTANCE_STRIDE
		_park_template [o] = 1.0
		_park_template [o + 5] = 1.0
		_park_template [o + 10] = 1.0
		_park_template [o + 7] = PARK_Y
		_park_template [o + 12] = c.r
		_park_template [o + 13] = c.g
		_park_template [o + 14] = c.b
		_park_template [o + 15] = 1.0

	_dirty_count.resize(tiles)
	_dirty_count.fill(0)
	_cursor.resize(tiles)
	_cursor.fill(0)
	_max_h.resize(tiles)
	_max_h.fill(0.0)


	var shadows:= Cfg.crust_shadow_distance > 0.0
	for i in tiles:
		var mm:= MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = StrandFactory.strand_mesh()
		mm.instance_count = per_tile
		mm.visible_instance_count = 0
		mm.buffer = _park_template
		var mmi:= MultiMeshInstance3D.new()
		mmi.name = "Tile_%d" % i
		mmi.multimesh = mm
		mmi.material_override = _mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		mmi.custom_aabb = AABB(Vector3(0.0, PARK_Y - 1.0, 0.0), Vector3.ONE)
		add_child(mmi)
		_nodes.append(mmi)
		_mms.append(mm)
		_bufs.append(_park_template.duplicate())
		_tile_of_node.append(NO_TILE)
		var d:= PackedByteArray()
		d.resize(CELLS_PER_TILE)
		_dirty.append(d)
	_mat.set_shader_parameter("fade_inner", maxf(0.0, _radius - FADE_BAND))
	_mat.set_shader_parameter("fade_outer", _radius)


func tick(eye: Vector3) -> void:
	var t0:= Time.get_ticks_usec()
	_eye = eye
	if _per_cell > 0:
		if Cfg.detail_scale != _shown_scale:
			_apply_scale()
		if Cfg.detail_scale <= 0.0 and not hidden_updates_enabled:


			last_tick_usec = Time.get_ticks_usec() - t0
			return
		_mat.set_shader_parameter("fade_center", eye)
		var c:= _tile_of_world(eye.x, eye.z)
		if c != _center:
			_center = c
			_reassign()
		_write_some(WRITE_BUDGET_USEC, CELLS_PER_FRAME_CAP)
	last_tick_usec = Time.get_ticks_usec() - t0


func fill_now(eye: Vector3) -> int:
	tick(eye)
	return _write_some(1 << 30, 1 << 30)


func pending_cells() -> int:
	var n:= 0
	for i in _dirty_count.size():
		n += _dirty_count [i]
	return n


func drawn_instances() -> int:
	var n:= 0
	for mm in _mms:
		n += mm.visible_instance_count
	return n


func pool_size() -> int:
	return _per_cell * CELLS_PER_TILE * _offsets.size()


func tile_count() -> int:
	return _offsets.size()


func strands_per_cell() -> int:
	return _per_cell


func _tile_of_world(wx: float, wz: float) -> Vector2i:
	var fx:= (wx + Cfg.FIELD_EXTENT) / Cfg.CELL
	var fz:= (wz + Cfg.FIELD_EXTENT) / Cfg.CELL
	return Vector2i(floori(fx / float(TILE_CELLS)), floori(fz / float(TILE_CELLS)))


func _reassign() -> void:
	var want: Dictionary = { }
	for o in _offsets:
		want [_center + o] = true
	var free:= PackedInt32Array()
	for n in _nodes.size():
		var held:= _tile_of_node [n]
		if not want.has(held):
			if held != NO_TILE:
				_node_of_tile.erase(held)
			free.append(n)
	for o in _offsets:
		var target:= _center + o
		if _node_of_tile.has(target):
			continue
		var n:= free [free.size() - 1]
		free.resize(free.size() - 1)
		_retarget(n, target)
	_sort_pending()


func _retarget(n: int, t: Vector2i) -> void:
	_tile_of_node [n] = t
	_node_of_tile [t] = n
	_bufs [n] = _park_template.duplicate()
	_mms [n].buffer = _bufs [n]
	_max_h [n] = 0.0
	_cursor [n] = 0
	var nc:= Cfg.field_cells()
	var ci0:= t.x * TILE_CELLS
	var cj0:= t.y * TILE_CELLS
	var inside:= ci0 + TILE_CELLS > 0 and cj0 + TILE_CELLS > 0 and ci0 < nc and cj0 < nc
	if inside:
		_dirty [n].fill(1)
		_dirty_count [n] = CELLS_PER_TILE
		if _pending.find(n) < 0:
			_pending.append(n)
	else:
		_dirty [n].fill(0)
		_dirty_count [n] = 0
		var at:= _pending.find(n)
		if at >= 0:
			_pending.remove_at(at)
	_set_aabb(n)


func _sort_pending() -> void:
	if _pending.size() < 2:
		return
	var arr: Array = Array(_pending)
	arr.sort_custom(func(a: int, b: int) -> bool: return (_tile_of_node [a] - _center).length_squared() < (_tile_of_node [b] - _center).length_squared())
	_pending = PackedInt32Array(arr)


func _apply_scale() -> void:
	_shown_scale = Cfg.detail_scale
	var per_tile:= _per_cell * CELLS_PER_TILE
	var vis:= clampi(int(round(per_tile * _shown_scale)), 0, per_tile)
	for mm in _mms:
		mm.visible_instance_count = vis


func _set_aabb(n: int) -> void:
	var t:= _tile_of_node [n]


	var pad:= Cfg.STRAND_LEN_MAX
	var ox:= - Cfg.FIELD_EXTENT + t.x * _tile_m - pad
	var oz:= - Cfg.FIELD_EXTENT + t.y * _tile_m - pad
	_nodes [n].custom_aabb = AABB(Vector3(ox, -0.2, oz),
		Vector3(_tile_m + 2.0 * pad, maxf(_max_h [n] + 0.4, 0.5), _tile_m + 2.0 * pad))


func _on_cells_redrawn(cells: PackedInt32Array) -> void:
	if _per_cell <= 0:
		return
	var nc:= Cfg.field_cells()
	for gc in cells:
		var ci:= gc % nc
		var cj:= gc / nc
		var t:= Vector2i(ci / TILE_CELLS, cj / TILE_CELLS)
		if not _node_of_tile.has(t):
			continue
		var n: int = _node_of_tile [t]
		var cell:= (cj % TILE_CELLS) * TILE_CELLS + (ci % TILE_CELLS)
		if _dirty [n] [cell] != 0:
			continue
		_dirty [n] [cell] = 1
		_dirty_count [n] += 1
		if _pending.find(n) < 0:
			_pending.insert(0, n)


func _write_some(budget_usec: int, cap: int) -> int:
	if _pending.is_empty():
		return 0
	var t0:= Time.get_ticks_usec()
	var done:= 0
	var touched: Dictionary = { }
	while not _pending.is_empty() and done < cap:
		var n:= _pending [0]
		if _dirty_count [n] <= 0:
			_pending.remove_at(0)
			continue
		var flags:= _dirty [n]
		var cell:= _cursor [n]
		while flags [cell] == 0:
			cell = (cell + 1) % CELLS_PER_TILE
		_write_cell(n, cell)
		flags [cell] = 0
		_dirty_count [n] -= 1
		_cursor [n] = (cell + 1) % CELLS_PER_TILE
		touched [n] = true
		done += 1
		if _dirty_count [n] <= 0:
			_pending.remove_at(0)
		if Time.get_ticks_usec() - t0 >= budget_usec:
			break


	for n: int in touched:
		_mms [n].buffer = _bufs [n]
		_set_aabb(n)
	return done


func _write_cell(n: int, cell: int) -> void:
	var tile:= _tile_of_node [n]
	var ci:= tile.x * TILE_CELLS + cell % TILE_CELLS
	var cj:= tile.y * TILE_CELLS + cell / TILE_CELLS
	var buf:= _bufs [n]
	if not field.in_bounds_cell(ci, cj):
		_park_cell(buf, cell, 0)
		return
	var nv:= Cfg.field_verts()
	var heights:= field.heights
	var base_i:= cj * nv + ci
	var h00:= heights [base_i]
	var h10:= heights [base_i + 1]
	var h01:= heights [base_i + nv]
	var h11:= heights [base_i + nv + 1]
	var h:= (h00 + h10 + h01 + h11) * 0.25
	if h <= 0.03:
		_park_cell(buf, cell, 0)
		return
	var dx:= ((h10 + h11) - (h00 + h01)) * 0.5 / Cfg.CELL
	var dz:= ((h01 + h11) - (h00 + h10)) * 0.5 / Cfg.CELL


	var area_gain:= sqrt(1.0 + dx * dx + dz * dz)
	var count:= clampi(int(round(_per_cell * clampf(area_gain / 2.2, FLAT_SHARE, 1.0))),
		0, _per_cell)


	_rng.seed = hash(Vector2i(ci, cj)) ^ (GameState.run_seed * 2654435761) ^ 4028945
	var cx: float = - Cfg.FIELD_EXTENT + ci * Cfg.CELL
	var cz: float = - Cfg.FIELD_EXTENT + cj * Cfg.CELL
	var depth: float = minf(DEPTH, h)
	var top: float = _max_h [n]
	for k in _per_cell:
		var o:= (k * CELLS_PER_TILE + cell) * INSTANCE_STRIDE
		if k >= count:
			_park_slot(buf, o)
			continue
		var u:= _rng.randf()
		var v:= _rng.randf()
		var surf:= lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)
		var t:= _rng.randf()
		t = t * t
		var py:= surf - t * depth + _rng.randf_range(-0.005, 0.03)
		var bi:= (_rng.randi() % BANK) * 9
		buf [o] = _bank_basis [bi]
		buf [o + 1] = _bank_basis [bi + 1]
		buf [o + 2] = _bank_basis [bi + 2]
		buf [o + 3] = cx + u * Cfg.CELL
		buf [o + 4] = _bank_basis [bi + 3]
		buf [o + 5] = _bank_basis [bi + 4]
		buf [o + 6] = _bank_basis [bi + 5]
		buf [o + 7] = py
		buf [o + 8] = _bank_basis [bi + 6]
		buf [o + 9] = _bank_basis [bi + 7]
		buf [o + 10] = _bank_basis [bi + 8]
		buf [o + 11] = cz + v * Cfg.CELL
		var ti:= (_rng.randi() % BANK) * 3
		buf [o + 12] = _bank_tint [ti]
		buf [o + 13] = _bank_tint [ti + 1]
		buf [o + 14] = _bank_tint [ti + 2]
		buf [o + 15] = 1.0
		if py > top:
			top = py
	_max_h [n] = top


func _park_cell(buf: PackedFloat32Array, cell: int, from_k: int) -> void:
	for k in range(from_k, _per_cell):
		_park_slot(buf, (k * CELLS_PER_TILE + cell) * INSTANCE_STRIDE)


func _park_slot(buf: PackedFloat32Array, o: int) -> void:
	buf [o] = 1.0
	buf [o + 1] = 0.0
	buf [o + 2] = 0.0
	buf [o + 3] = 0.0
	buf [o + 4] = 0.0
	buf [o + 5] = 1.0
	buf [o + 6] = 0.0
	buf [o + 7] = PARK_Y
	buf [o + 8] = 0.0
	buf [o + 9] = 0.0
	buf [o + 10] = 1.0
	buf [o + 11] = 0.0


func _build_bank() -> void:
	var rng:= RandomNumberGenerator.new()
	rng.seed = 407717706257
	_bank_basis.resize(BANK * 9)
	_bank_tint.resize(BANK * 3)
	for i in BANK:
		var b:= StrandFactory.random_strand_basis(rng)
		var o:= i * 9
		_bank_basis [o] = b.x.x
		_bank_basis [o + 1] = b.y.x
		_bank_basis [o + 2] = b.z.x
		_bank_basis [o + 3] = b.x.y
		_bank_basis [o + 4] = b.y.y
		_bank_basis [o + 5] = b.z.y
		_bank_basis [o + 6] = b.x.z
		_bank_basis [o + 7] = b.y.z
		_bank_basis [o + 8] = b.z.z
		var c:= StrandFactory.random_tint(rng)
		_bank_tint [i * 3] = c.r
		_bank_tint [i * 3 + 1] = c.g
		_bank_tint [i * 3 + 2] = c.b
