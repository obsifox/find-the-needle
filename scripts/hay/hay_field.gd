class_name HayField
extends Node3D


signal field_carved(center: Vector3, strands: float)

signal cells_redrawn(cells: PackedInt32Array)

var heights: PackedFloat32Array = PackedFloat32Array()


var dome: PackedFloat32Array = PackedFloat32Array()


var dome_seed:= 0


var dome_from_save:= false
var chunks: Array [HayChunk] = []
var _lod_dirty: Dictionary = { }
var _lod_eye:= Vector3(INF, INF, INF)
var _lod_settings:= Vector4.ZERO


var crust_radius:= 0.0
const CRUST_RADIUS_MARGIN:= 0.5

var avalanche_vfx: AvalancheVfx

var _nv:= 0
var _nc:= 0
var _cpe:= 0

var _dirty_cells: Dictionary = { }
var _dirty_chunks: Dictionary = { }
var _cell_queue: PackedInt32Array = PackedInt32Array()
var _chunk_queue: PackedInt32Array = PackedInt32Array()


var _cell_render_h: PackedFloat32Array = PackedFloat32Array()
const CRUST_REDRAW_EPS:= 0.025


var _built_h: PackedFloat32Array = PackedFloat32Array()
const CHUNK_REBUILD_EPS:= 0.01


var _relax:= PileSettle.new()
var _last_relax_visits:= 0
var _preparing_dome:= false:
	set(value):
		_preparing_dome = value
		_relax.preparing_dome = value


var _settling_restored:= false:
	set(value):
		_settling_restored = value
		_relax.settling_restored = value


static var settle_threaded: bool = not ("--nothreadsettle" in OS.get_cmdline_user_args())

var _settle_task:= -1


var _settle_count_at_start:= 0


var _relax_on_copy:= false


var _settle_worker_us:= 0


static var redraw_threaded: bool = not ("--noredrawthreads" in OS.get_cmdline_user_args())


var _cell_cost_us:= 6.0
var _upload_cost_us:= 40.0


const RESEED_MARGIN:= 0.03


var _repose_step:= tan(Cfg.ANGLE_OF_REPOSE) * Cfg.CELL


var _dome_prep_step:= tan(deg_to_rad(Cfg.PILE_PREP_ANGLE_DEG)) * Cfg.CELL
const DOME_PREP_RATE:= 0.5
const DOME_PREP_VISIT_BUDGET:= 12000000


const FORCE_TRIES:= 400

var _rng:= RandomNumberGenerator.new()


func _ready() -> void:
	_nv = Cfg.field_verts()
	_nc = Cfg.field_cells()
	_cpe = Cfg.chunks_per_edge()


func vertex_pos(i: int, j: int) -> Vector3:
	return Vector3(
		- Cfg.FIELD_EXTENT + i * Cfg.CELL,
		heights [j * _nv + i],
		- Cfg.FIELD_EXTENT + j * Cfg.CELL
	)


func cell_center(i: int, j: int) -> Vector3:
	return Vector3(
		- Cfg.FIELD_EXTENT + (i + 0.5) * Cfg.CELL,
		0.0,
		- Cfg.FIELD_EXTENT + (j + 0.5) * Cfg.CELL
	)


func cell_at(wx: float, wz: float) -> Vector2i:
	return Vector2i(
		int(floor((wx + Cfg.FIELD_EXTENT) / Cfg.CELL)),
		int(floor((wz + Cfg.FIELD_EXTENT) / Cfg.CELL))
	)


func in_bounds_vert(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < _nv and j < _nv


func in_bounds_cell(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < _nc and j < _nc


func height_at(wx: float, wz: float) -> float:
	var fx:= (wx + Cfg.FIELD_EXTENT) / Cfg.CELL
	var fz:= (wz + Cfg.FIELD_EXTENT) / Cfg.CELL
	var i:= int(floor(fx))
	var j:= int(floor(fz))
	if i < 0 or j < 0 or i >= _nv - 1 or j >= _nv - 1:
		return 0.0
	var tx:= fx - i
	var tz:= fz - j
	var h00:= heights [j * _nv + i]
	var h10:= heights [j * _nv + i + 1]
	var h01:= heights [(j + 1) * _nv + i]
	var h11:= heights [(j + 1) * _nv + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func cell_height(i: int, j: int) -> float:
	if not in_bounds_cell(i, j):
		return 0.0
	return (heights [j * _nv + i] + heights [j * _nv + i + 1]
		+ heights [(j + 1) * _nv + i] + heights [(j + 1) * _nv + i + 1]) * 0.25


func depth_floor_at(wx: float, wz: float) -> float:
	var c:= cell_at(wx, wz)
	if not in_bounds_cell(c.x, c.y):
		return 0.0
	return minf(
		minf(heights [c.y * _nv + c.x], heights [c.y * _nv + c.x + 1]),
		minf(heights [(c.y + 1) * _nv + c.x], heights [(c.y + 1) * _nv + c.x + 1]))


func cell_slope(i: int, j: int) -> float:
	if not in_bounds_cell(i, j):
		return 0.0
	var h00:= heights [j * _nv + i]
	var h10:= heights [j * _nv + i + 1]
	var h01:= heights [(j + 1) * _nv + i]
	var h11:= heights [(j + 1) * _nv + i + 1]
	var dx:= ((h10 + h11) - (h00 + h01)) * 0.5 / Cfg.CELL
	var dz:= ((h01 + h11) - (h00 + h10)) * 0.5 / Cfg.CELL
	return sqrt(dx * dx + dz * dz)


func normal_at_scale(wx: float, wz: float, e: float) -> Vector3:
	var hl:= height_at(wx - e, wz)
	var hr:= height_at(wx + e, wz)
	var hd:= height_at(wx, wz - e)
	var hu:= height_at(wx, wz + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func normal_at(wx: float, wz: float) -> Vector3:
	var e:= Cfg.CELL
	var hl:= height_at(wx - e, wz)
	var hr:= height_at(wx + e, wz)
	var hd:= height_at(wx, wz - e)
	var hu:= height_at(wx, wz + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func _sample_vertex(i: int, j: int) -> float:
	if i < 0 or j < 0 or i >= _nv - 1 or j >= _nv - 1:
		return 0.0
	return heights [j * _nv + i]


func normal_at_vertex(i: int, j: int, span: int = 1) -> Vector3:
	return Vector3(_sample_vertex(i - span, j) - _sample_vertex(i + span, j),
		2.0 * Cfg.CELL * span,
		_sample_vertex(i, j - span) - _sample_vertex(i, j + span)).normalized()


func dug_depth_at_vertex(i: int, j: int) -> float:
	if dome.size() != heights.size() or i < 0 or j < 0 or i >= _nv - 1 or j >= _nv - 1:
		return 0.0
	var idx:= j * _nv + i
	return maxf(0.0, dome [idx] - heights [idx])


func dug_depth_at(wx: float, wz: float) -> float:
	if dome.size() != heights.size():
		return 0.0
	var fx:= (wx + Cfg.FIELD_EXTENT) / Cfg.CELL
	var fz:= (wz + Cfg.FIELD_EXTENT) / Cfg.CELL
	var i:= int(floor(fx))
	var j:= int(floor(fz))
	if i < 0 or j < 0 or i >= _nv - 1 or j >= _nv - 1:
		return 0.0
	var tx:= fx - i
	var tz:= fz - j
	var d00:= dome [j * _nv + i] - heights [j * _nv + i]
	var d10:= dome [j * _nv + i + 1] - heights [j * _nv + i + 1]
	var d01:= dome [(j + 1) * _nv + i] - heights [(j + 1) * _nv + i]
	var d11:= dome [(j + 1) * _nv + i + 1] - heights [(j + 1) * _nv + i + 1]
	return maxf(0.0, lerpf(lerpf(d00, d10, tx), lerpf(d01, d11, tx), tz))


func shell_depth_at(wx: float, wz: float, n: Vector3, known_height: float = -1.0) -> float:
	var h:= height_at(wx, wz) if known_height < 0.0 else known_height
	var d: float = minf(Cfg.HAY_SHELL_DEPTH, h * 0.9)
	var down:= Vector2(n.x, n.z)

	if d <= 0.02 or down.length_squared() < 1e-08:
		return clampf(d, 0.02, Cfg.HAY_SHELL_DEPTH)
	down = down.normalized()
	var step:= Cfg.CELL
	while step <= Cfg.HAY_SHELL_REACH:


		if step * Cfg.HAY_SHELL_GRADE >= d:
			break
		d = minf(d, height_at(wx + down.x * step, wz + down.y * step) * 0.9
			+ step * Cfg.HAY_SHELL_GRADE)
		step += Cfg.CELL
	return clampf(d, 0.02, Cfg.HAY_SHELL_DEPTH)


func shell_length_limit(wx: float, wz: float, n: Vector3, known_dug: float = -1.0) -> float:
	var depth:= dug_depth_at(wx, wz) if known_dug < 0.0 else known_dug
	var dug:= maxf(0.0, depth - Cfg.HAY_SHELL_DIG_DEADBAND)
	var by_dig:= clampf(1.0 - dug * Cfg.HAY_SHELL_DIG_K, Cfg.HAY_SHELL_DIG_FLOOR, 1.0)


	var slope:= Vector2(n.x, n.z).length() / maxf(n.y, 0.0001)
	var by_slope:= clampf(1.0 - (slope - Cfg.HAY_SHELL_STEEP_LO)
		/ maxf(Cfg.HAY_SHELL_STEEP_HI - Cfg.HAY_SHELL_STEEP_LO, 0.0001),
		Cfg.HAY_SHELL_STEEP_FLOOR, 1.0)
	return Cfg.HAY_SHELL_DEPTH * minf(by_dig, by_slope)


func chunk_index_for_cell(i: int, j: int) -> int:
	var cx:= i / Cfg.CHUNK_CELLS
	var cz:= j / Cfg.CHUNK_CELLS
	if cx < 0 or cz < 0 or cx >= _cpe or cz >= _cpe:
		return -1
	return cz * _cpe + cx


const STAGED_CHUNKS_PER_FRAME:= 6


const STAGED_SLICE_USEC:= 50000


const STAGED_RELAX_VISITS:= 4096


const RELAX_VISITS_PER_VERTEX_PER_M2:= 0.08


var _slice_start:= -1
var _shape_report:= Callable()
var _shape_reported:= -1.0

var prep_visits:= 0


func generate(seed_value: int, saved_heights: PackedFloat32Array = PackedFloat32Array(),
		saved_dome: PackedFloat32Array = PackedFloat32Array()) -> void:
	_shape(seed_value, saved_heights, true, saved_dome)
	for c in chunks:
		_rebuild_chunk(c)
		c.rebuild_all_cells()


func generate_staged(seed_value: int, saved_heights: PackedFloat32Array,
		report: Callable, shape_report: Callable = Callable(),
		saved_dome: PackedFloat32Array = PackedFloat32Array()) -> void:
	var was_processing:= is_processing()
	set_process(false)
	_shape_report = shape_report
	_shape_reported = -1.0
	_slice_start = Time.get_ticks_usec()
	await _shape(seed_value, saved_heights, true, saved_dome)
	_slice_start = -1
	_shape_report = Callable()
	set_process(was_processing)
	var n:= chunks.size()
	for i in n:
		_rebuild_chunk(chunks [i])
		chunks [i].rebuild_all_cells()
		if (i + 1) % STAGED_CHUNKS_PER_FRAME == 0 or i == n - 1:
			report.call(float(i + 1) / float(n))
			await get_tree().process_frame


func _slice_due() -> bool:
	return _slice_start >= 0 and Time.get_ticks_usec() - _slice_start >= STAGED_SLICE_USEC


func _hand_back(progress: float) -> void:
	if _shape_report.is_valid() and progress - _shape_reported >= 0.01:
		_shape_reported = progress
		_shape_report.call(progress)
	await get_tree().process_frame
	_slice_start = Time.get_ticks_usec()


func refill(seed_value: int) -> void:
	_shape(seed_value, PackedFloat32Array(), false)
	for c in chunks:
		_rebuild_chunk(c)
		c.rebuild_all_cells()


func _shape(seed_value: int, saved_heights: PackedFloat32Array,
		fresh_run: bool = true, saved_dome: PackedFloat32Array = PackedFloat32Array()) -> void:
	settle_join()
	_rng.seed = seed_value
	heights = PackedFloat32Array()
	heights.resize(_nv * _nv)
	_relax.active_mark = PackedByteArray()
	_relax.active_mark.resize(_nv * _nv)
	_relax.clear()
	_relax.rng.seed = seed_value
	_relax_rules()
	_cell_render_h = PackedFloat32Array()
	_cell_render_h.resize(_nc * _nc)
	_cell_render_h.fill(-999.0)


	_built_h = PackedFloat32Array()
	_built_h.resize(_nv * _nv)
	_built_h.fill(-999.0)
	dome = PackedFloat32Array()


	dome_seed = seed_value
	var restored:= saved_heights.size() == heights.size()
	dome_from_save = restored and _stored_dome_fits(saved_dome)
	if dome_from_save:
		heights = saved_dome.duplicate()
		print("[hay] took the starting pile from the save")
	else:
		await _shape_dome(seed_value)
		var settled_baseline:= not restored or SaveManager.current_pile_shape_version >= SaveManager.PILE_SHAPE_SETTLED
		if settled_baseline:
			await _prepare_dome()
	dome = heights.duplicate()

	if restored:
		heights = saved_heights.duplicate()


		var gone:= sweep_islands(Cfg.THIN_HAY)
		if gone > 0.0:
			GameState.lose_hay(gone)


		await _settle_restored()


		if _slice_due():
			await _hand_back(0.85)
		GameState.match_pile(measure_strands())

	_measure_crust_radius()
	await _build_chunks()

	if not restored:


		if SaveManager.block_save and SaveManager.refuse_reason != "":
			push_warning("HayField: %s. The pile stands unseeded and nothing will be saved."
				% SaveManager.refuse_reason)
			return
		if _slice_due():
			await _hand_back(0.95)
		var total:= measure_strands()
		if fresh_run:
			GameState.reset(seed_value, total)
		else:
			GameState.new_pile(seed_value, total)


		_last_of_pile_seen = INF


		_seed_needles(GameState.pile_needle_types())


func _stored_dome_fits(saved_dome: PackedFloat32Array) -> bool:
	if saved_dome.is_empty():
		return false
	if saved_dome.size() != heights.size():
		push_warning("HayField: the saved starting pile is %d points, the field is %d; shaping it instead"
			% [saved_dome.size(), heights.size()])
		return false
	for v in saved_dome:
		if not is_finite(v):
			push_warning("HayField: the saved starting pile holds a bad number; shaping it instead")
			return false


	heights = saved_dome.duplicate()
	var strands:= measure_strands()
	heights = PackedFloat32Array()
	heights.resize(_nv * _nv)
	var want:= GameState.hay_initial
	if want <= 0.0 or absf(strands - want) > maxf(1.0, want * 1e-06):
		push_warning("HayField: the saved starting pile holds %.0f strands, the run started with %.0f; shaping it instead"
			% [strands, want])
		return false
	return true


func _measure_crust_radius() -> void:
	var furthest_sq:= 0.0
	for j in _nc:
		for i in _nc:
			var h00:= heights [j * _nv + i]
			var h10:= heights [j * _nv + i + 1]
			var h01:= heights [(j + 1) * _nv + i]
			var h11:= heights [(j + 1) * _nv + i + 1]
			if maxf(maxf(h00, h10), maxf(h01, h11)) <= 0.0:
				continue
			var c:= cell_center(i, j)
			var dx:= c.x - Cfg.PILE_CENTER.x
			var dz:= c.z - Cfg.PILE_CENTER.z
			furthest_sq = maxf(furthest_sq, dx * dx + dz * dz)
	crust_radius = maxf(Cfg.settled_footprint(), sqrt(furthest_sq) + CRUST_RADIUS_MARGIN)


func _prepare_dome() -> void:
	_preparing_dome = true
	settle_join()
	for j in _nv:


		_bind_relax()
		for i in _nv:
			_relax.seed_if_unstable(i, j)
		if _slice_due():
			await _hand_back(lerpf(0.05, 0.1, float(j) / _nv))

	prep_visits = await _relax_to_rest(0.1, 0.8)
	_preparing_dome = false
	if settling_count() > 0:
		push_warning("HayField: initial dome preparation stopped with %d vertices queued"
			% settling_count())
	_clear_relax_queue()


func _settle_restored() -> void:
	_settling_restored = true
	settle_join()
	for j in _nv:

		_bind_relax()
		for i in _nv:
			_relax.seed_if_unstable(i, j)
		if _slice_due():
			await _hand_back(0.8)
	var woke:= settling_count()
	var visits: int = await _relax_to_rest(0.8, 0.88)
	_settling_restored = false
	if woke > 0:
		print("[hay] settled the restored crust: %d vertices stood too steep, %d visits"
			% [woke, visits])
	if settling_count() > 0:
		push_warning("HayField: settling the restored crust stopped with %d vertices queued"
			% settling_count())
	_clear_relax_queue()


func _relax_to_rest(from: float, to: float) -> int:
	var visits:= 0
	var expected:= maxf(1.0, float(_nv * _nv) * RELAX_VISITS_PER_VERTEX_PER_M2
		* Cfg.PILE_HEIGHT * Cfg.PILE_HEIGHT)
	while settling_count() > 0 and visits < DOME_PREP_VISIT_BUDGET:
		var budget:= DOME_PREP_VISIT_BUDGET - visits
		if _slice_start >= 0:
			budget = mini(budget, STAGED_RELAX_VISITS)
		var result:= _relax_once(budget)
		visits += int(result ["visits"])
		if int(result ["visits"]) <= 0:
			break
		if _slice_due():
			await _hand_back(lerpf(from, to, minf(1.0, float(visits) / expected)))
	return visits


func _clear_relax_queue() -> void:
	settle_join()
	_relax.clear()


func _relax_rules() -> void:
	_relax.nv = _nv
	_relax.repose_step = _repose_step
	_relax.dome_prep_step = _dome_prep_step
	_relax.reseed_margin = RESEED_MARGIN
	_relax.play_rate = Cfg.RELAX_RATE * 0.25
	_relax.prep_rate = DOME_PREP_RATE
	_relax.spill_chance = Cfg.RELAX_SPAWN_CHANCE
	_relax.cell = Cfg.CELL
	_relax.extent = Cfg.FIELD_EXTENT


func _bind_relax() -> void:
	_relax.heights = heights
	_relax.dome = dome


func _shape_dome(seed_value: int) -> void:


	var lumps:= FastNoiseLite.new()
	lumps.seed = seed_value
	lumps.noise_type = FastNoiseLite.TYPE_SIMPLEX
	lumps.frequency = 0.055

	var grain:= FastNoiseLite.new()
	grain.seed = seed_value + 7717
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grain.frequency = 0.42

	var rim:= FastNoiseLite.new()
	rim.seed = seed_value + 3391
	rim.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rim.frequency = 0.09

	for j in _nv:
		for i in _nv:
			var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
			var dx: float = wx - Cfg.PILE_CENTER.x
			var dz: float = wz - Cfg.PILE_CENTER.z
			var d:= sqrt(dx * dx + dz * dz)


			var r: float = Cfg.PILE_RADIUS * (1.0 + 0.075 * rim.get_noise_2d(wx * 2.0, wz * 2.0))
			var t:= d / maxf(r, 0.001)
			var h:= 0.0
			if t < 1.0:


				h = Cfg.PILE_HEIGHT * pow(maxf(0.0, 1.0 - pow(t, 3.0)), 0.55)
				h += lumps.get_noise_2d(wx, wz) * 0.55 * (1.0 - t * 0.6)
				h += grain.get_noise_2d(wx, wz) * 0.11
				h *= 1.0 - smoothstep(0.86, 1.0, t) * 0.12
			heights [j * _nv + i] = maxf(0.0, h)
		if _slice_due():
			await _hand_back(0.05 * float(j) / _nv)


func _build_chunks() -> void:
	for c in chunks:
		c.queue_free()
	chunks.clear()
	_lod_dirty.clear()
	_lod_eye = Vector3(INF, INF, INF)
	for cz in _cpe:
		for cx in _cpe:
			var cw: int = mini(Cfg.CHUNK_CELLS, _nc - cx * Cfg.CHUNK_CELLS)
			var chd: int = mini(Cfg.CHUNK_CELLS, _nc - cz * Cfg.CHUNK_CELLS)
			var chunk:= HayChunk.new()
			add_child(chunk)
			chunk.setup(self, cx * Cfg.CHUNK_CELLS, cz * Cfg.CHUNK_CELLS, cw, chd)
			chunks.append(chunk)
		if _slice_due():
			await _hand_back(0.9)


func measure_strands() -> float:
	var vol:= 0.0
	var area: float = Cfg.CELL * Cfg.CELL
	for j in _nc:
		for i in _nc:
			vol += cell_height(i, j) * area
	return vol * Cfg.STRANDS_PER_M3


const SITE_SHALLOW:= 0
const SITE_ANY:= 1
const SITE_DEEP:= 2


func _seed_needles(types: PackedInt32Array) -> void:
	for type in types:
		if not rebury(type):
			push_warning("HayField: nowhere in the pile to bury %s" % NeedleTypes.name_of(type))


func _needle_site(band: int = SITE_ANY) -> Vector3:
	var a:= _rng.randf_range(0.0, TAU)
	var span: float = Cfg.NEEDLE_DEEP_RADIUS if band == SITE_DEEP else 0.92
	var rad: float = sqrt(_rng.randf()) * Cfg.PILE_RADIUS * span
	var wx: float = Cfg.PILE_CENTER.x + cos(a) * rad
	var wz: float = Cfg.PILE_CENTER.z + sin(a) * rad
	var surf:= height_at(wx, wz)
	if surf < 0.6:
		return Vector3.INF
	var lo:= 0.12
	var hi:= surf - 0.25
	match band:
		SITE_DEEP:
			hi = lo + maxf(hi - lo, 0.0) * Cfg.NEEDLE_DEEP_COLUMN
		SITE_SHALLOW:
			lo = maxf(lo, surf - Cfg.NEEDLE_SHALLOW_DEPTH)
	return Vector3(wx, _rng.randf_range(lo, maxf(hi, lo)), wz)


func rebury(type: int) -> bool:
	if type < 0 or type >= NeedleTypes.count():
		return false
	var band:= NeedleTypes.site_band(type)
	for _try in FORCE_TRIES:
		var at:= _needle_site(band)
		if at == Vector3.INF:
			continue
		GameState.register_needle(at, _rng, type)
		return true


	for _try in FORCE_TRIES:
		var at:= _needle_site(SITE_ANY)
		if at == Vector3.INF:
			continue
		GameState.register_needle(at, _rng, type)
		return true
	return false


func carve_sphere(center: Vector3, radius: float, max_drop: float) -> Dictionary:
	settle_join()
	var out:= { "strands": 0.0, "volume": 0.0, "points": PackedVector3Array() }
	var lo:= cell_at(center.x - radius, center.z - radius)
	var hi:= cell_at(center.x + radius, center.z + radius)
	var area: float = Cfg.CELL * Cfg.CELL
	var r2:= radius * radius
	var volume:= 0.0
	var pts:= PackedVector3Array()

	for j in range(maxi(lo.y, 0), mini(hi.y + 2, _nv)):
		for i in range(maxi(lo.x, 0), mini(hi.x + 2, _nv)):
			var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
			var dx:= wx - center.x
			var dz:= wz - center.z
			var d2:= dx * dx + dz * dz
			if d2 > r2:
				continue
			var idx:= j * _nv + i
			var h:= heights [idx]
			if h <= 0.0:
				continue
			var target:= center.y - sqrt(r2 - d2)
			if h <= target:
				continue
			var new_h:= maxf(maxf(target, h - max_drop), 0.0)
			var drop:= h - new_h
			if drop <= 0.0001:
				continue
			heights [idx] = new_h
			volume += drop * area
			pts.append(Vector3(wx, new_h + drop * 0.5, wz))
			_touch_vertex(i, j)

	if volume <= 0.0:
		return out
	var strands:= volume * Cfg.STRANDS_PER_M3
	out ["strands"] = strands
	out ["volume"] = volume
	out ["points"] = pts
	GameState.remove_hay(strands)
	field_carved.emit(center, strands)
	return out


func can_carve_sphere(center: Vector3, radius: float, min_height: float = 0.0) -> bool:
	var lo:= cell_at(center.x - radius, center.z - radius)
	var hi:= cell_at(center.x + radius, center.z + radius)
	var r2:= radius * radius
	for j in range(maxi(lo.y, 0), mini(hi.y + 2, _nv)):
		for i in range(maxi(lo.x, 0), mini(hi.x + 2, _nv)):
			var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
			var dx:= wx - center.x
			var dz:= wz - center.z
			var d2:= dx * dx + dz * dz
			if d2 > r2:
				continue
			var h:= heights [j * _nv + i]
			if h <= min_height:
				continue
			var target:= center.y - sqrt(r2 - d2)
			if h > target + 0.0001:
				return true
	return false


func carve_column(wx: float, wz: float, drop: float) -> float:
	settle_join()
	var c:= cell_at(wx, wz)
	if not in_bounds_cell(c.x, c.y):
		return 0.0
	var removed:= 0.0
	for dj in 2:
		for di in 2:
			var i:= c.x + di
			var j:= c.y + dj
			if not in_bounds_vert(i, j):
				continue
			var idx:= j * _nv + i
			var h:= heights [idx]
			var new_h:= maxf(0.0, h - drop)
			removed += (h - new_h) * Cfg.CELL * Cfg.CELL * 0.25
			heights [idx] = new_h
			_touch_vertex(i, j)
	var strands:= removed * Cfg.STRANDS_PER_M3
	GameState.remove_hay(strands)
	return strands


func _touch_vertex(i: int, j: int) -> void:
	_seed_relax(i, j)
	_seed_uphill(i, j)


	_dirty_vertex_cells(i, j)


func _seed_uphill(i: int, j: int) -> void:
	settle_join()
	_bind_relax()
	_relax.seed_uphill(i, j)


func _seed_if_unstable(i: int, j: int) -> void:


	settle_join()
	_bind_relax()
	_relax.seed_if_unstable(i, j)


func _step_limit(high_idx: int, low_idx: int) -> float:
	settle_join()
	_bind_relax()
	return _relax.step_limit(high_idx, low_idx)


func _seed_relax(i: int, j: int) -> void:
	settle_join()
	_relax.seed_relax(i, j)


func _dirty_vertex_cells(i: int, j: int) -> void:


	var idx:= j * _nv + i
	var rebuild:= absf(heights [idx] - _built_h [idx]) >= CHUNK_REBUILD_EPS
	var chunk_cells:= Cfg.CHUNK_CELLS
	for cj in range(maxi(0, j - 1), mini(j + 1, _nc)):
		var cell_row:= cj * _nc
		var vertex_row:= cj * _nv
		var chunk_row:= (cj / chunk_cells) * _cpe
		for ci in range(maxi(0, i - 1), mini(i + 1, _nc)):
			if rebuild:
				_dirty_chunks [chunk_row + ci / chunk_cells] = true
			var gc:= cell_row + ci
			var v:= vertex_row + ci
			var h:= (heights [v] + heights [v + 1]
				+ heights [v + _nv] + heights [v + _nv + 1]) * 0.25
			if absf(h - _cell_render_h [gc]) >= CRUST_REDRAW_EPS:
				_dirty_cells [gc] = true


func _rebuild_chunk(c: HayChunk) -> void:
	_lod_dirty [c] = true
	c.rebuild_collision()


	HayContainer.pile_rebuilt(self,
		Vector2(- Cfg.FIELD_EXTENT + c.cx0 * Cfg.CELL, - Cfg.FIELD_EXTENT + c.cz0 * Cfg.CELL),
		Vector2(- Cfg.FIELD_EXTENT + (c.cx0 + c.cw) * Cfg.CELL,
			- Cfg.FIELD_EXTENT + (c.cz0 + c.ch) * Cfg.CELL))
	for lj in c.ch + 1:
		var row:= (c.cz0 + lj) * _nv + c.cx0
		for li in c.cw + 1:
			_built_h [row + li] = heights [row + li]


func mark_cell_dirty(gc: int) -> void:
	_dirty_cells [gc] = true


func _relax_once(visit_budget: int, deadline: int = 0) -> Dictionary:
	settle_join()
	_bind_relax()
	_relax.want_spill = avalanche_vfx != null
	_relax.touched = PackedInt32Array()
	_relax.spill = PackedVector3Array()
	var out:= _relax.relax_once(visit_budget, deadline)
	_apply_relax()
	return out


func _apply_relax() -> void:
	var moved:= _relax.touched
	if _relax_on_copy:
		var from:= _relax.heights
		for idx in moved:
			heights [idx] = from [idx]
		_relax_on_copy = false
		_bind_relax()
	for idx in moved:
		_dirty_vertex_cells(idx % _nv, idx / _nv)
	if avalanche_vfx != null and _relax.spill.size() > 0:
		avalanche_vfx.emit_spill(_relax.spill, self)
	_relax.touched = PackedInt32Array()
	_relax.spill = PackedVector3Array()


var _frame_spent_us:= 0


func charge_frame(us: int) -> void:
	_frame_spent_us += maxi(0, us)


func _process(delta: float) -> void:
	var started:= Time.get_ticks_usec()
	_settle()
	HotSpots.add(&"frame pile settle", started)
	var t:= Time.get_ticks_usec()
	_tick_last_of_pile(delta)
	HotSpots.add(&"frame pile last sweep", t)


	charge_frame(Time.get_ticks_usec() - started + _settle_worker_us)
	_settle_worker_us = 0
	t = Time.get_ticks_usec()
	_flush_dirty()
	HotSpots.add(&"frame pile redraw", t)


const LAST_OF_PILE_STRANDS:= 5000.0
const LAST_OF_PILE_EVERY:= 2.0
var _last_of_pile_seen:= INF
var _last_of_pile_wait:= 0.0


func _tick_last_of_pile(delta: float) -> void:
	_last_of_pile_wait -= delta
	if _last_of_pile_wait > 0.0 or _preparing_dome or _settling_restored or chunks.is_empty() or GameState.hay_initial <= 0.0:
		return
	var left:= GameState.hay_never_dug()
	if left >= _last_of_pile_seen:
		return


	_last_of_pile_wait = LAST_OF_PILE_EVERY
	if left > LAST_OF_PILE_STRANDS and not _nothing_standing():
		return
	var gone:= sweep_islands(Shovel.SWEEP_HEIGHT, true)
	if gone > 0.0:
		GameState.lose_hay(gone)
	GameState.match_pile(measure_strands())
	_last_of_pile_seen = GameState.hay_never_dug()
	GameState.check_cleared()


func _nothing_standing() -> bool:
	for c in chunks:
		if c.top_height() > Shovel.SWEEP_HEIGHT:
			return false
	return true


func _settle() -> void:
	settle_join()
	if _relax.count() == 0:
		_last_relax_visits = 0
		return
	_bind_relax()
	_relax.want_spill = avalanche_vfx != null
	if not settle_threaded:
		_relax.settle_frame(Cfg.RELAX_VERTICES_PER_FRAME, Cfg.relax_update_budget_usec,
			Cfg.RELAX_ITERATIONS_PER_FRAME)
		_last_relax_visits = _relax.last_visits
		_apply_relax()
		return
	_relax.heights = heights.duplicate()
	_relax_on_copy = true
	_settle_count_at_start = _relax.count()
	_settle_task = WorkerThreadPool.add_task(_relax.settle_frame.bind(
		Cfg.RELAX_VERTICES_PER_FRAME, Cfg.relax_update_budget_usec,
		Cfg.RELAX_ITERATIONS_PER_FRAME), false, "pile settle")


func settle_join() -> void:
	if _settle_task < 0:
		return
	var t:= Time.get_ticks_usec()
	WorkerThreadPool.wait_for_task_completion(_settle_task)
	_settle_task = -1
	HotSpots.add(&"wait pile settle", t)
	HotSpots.add_usec(&"worker pile settle", _relax.last_usec)
	_settle_worker_us += _relax.last_usec
	_last_relax_visits = _relax.last_visits
	_apply_relax()


func _exit_tree() -> void:
	settle_join()


func settling_count() -> int:
	if _settle_task >= 0:
		return _settle_count_at_start
	return _relax.count()


func last_relax_visits() -> int:
	return _last_relax_visits


func _flush_dirty() -> void:
	if _dirty_cells.size() > 0 and _cell_queue.is_empty():


		var by_chunk: Dictionary = { }
		for gc: int in _dirty_cells:
			var ck:= chunk_index_for_cell(gc % _nc, gc / _nc)
			if not by_chunk.has(ck):
				by_chunk [ck] = []
			(by_chunk [ck] as Array).append(gc)
		for cells: Array in by_chunk.values():
			_cell_queue.append_array(PackedInt32Array(cells))
		_dirty_cells.clear()
	if _dirty_chunks.size() > 0 and _chunk_queue.is_empty():
		_chunk_queue = PackedInt32Array(_dirty_chunks.keys())
		_dirty_chunks.clear()


	var cell_budget:= Cfg.cell_update_budget_usec - _frame_spent_us
	var chunk_budget:= Cfg.chunk_rebuild_budget_usec - maxi(0, _frame_spent_us - Cfg.cell_update_budget_usec)
	_frame_spent_us = 0
	if _cell_queue.size() > 0 and cell_budget > 0:
		_redraw_cells(cell_budget)

	var m: int = mini(Cfg.CHUNK_REBUILDS_PER_FRAME, _chunk_queue.size())
	if m > 0 and chunk_budget > 0:
		var chunk_started:= Time.get_ticks_usec()
		var chunk_done:= 0
		for k in m:
			_rebuild_chunk(chunks [_chunk_queue [_chunk_queue.size() - 1 - k]])
			chunk_done += 1
			if Time.get_ticks_usec() - chunk_started >= chunk_budget:
				break
		_chunk_queue.resize(_chunk_queue.size() - chunk_done)


func _redraw_cells(cell_budget: int) -> void:
	var started:= Time.get_ticks_usec()
	var n: int = mini(Cfg.CELL_UPDATES_PER_FRAME, _cell_queue.size())
	CrustCells.capture()
	var batch:= CrustCells.Batch.new()
	var job_chunks: Array [HayChunk] = []
	var job_of_chunk: Dictionary = { }


	var cell_job:= PackedInt32Array()
	var cell_pos:= PackedInt32Array()
	var taken:= 0
	var writing:= 0
	var last_ck:= -1
	for k in n:
		var gc:= _cell_queue [_cell_queue.size() - 1 - k]
		var ck:= chunk_index_for_cell(gc % _nc, gc / _nc)
		if ck != last_ck and last_ck >= 0 and (batch.jobs.size() + 1) * _upload_cost_us + writing * _cell_cost_us >= cell_budget:
			break
		last_ck = ck
		var ord_i:= -1 if ck < 0 else chunks [ck].crust_ordinal(gc)
		var j:= -1
		if ord_i >= 0:
			j = job_of_chunk.get(ck, -1)
			if j < 0:
				j = batch.jobs.size()
				job_of_chunk [ck] = j
				job_chunks.append(chunks [ck])
				var job:= chunks [ck].lend_crust()
				job.ords = PackedInt32Array()
				batch.jobs.append(job)
			batch.jobs [j].ords.append(ord_i)
			writing += 1
		cell_job.append(j if ck >= 0 else -2)
		cell_pos.append(batch.jobs [j].ords.size() - 1 if j >= 0 else 0)
		taken += 1

	var work_budget:= maxf(cell_budget - batch.jobs.size() * _upload_cost_us, 1.0)
	for job in batch.jobs:
		job.budget_us = maxi(1, int(work_budget * job.ords.size() / maxf(writing, 1.0)))
	var t:= Time.get_ticks_usec()
	if redraw_threaded and batch.jobs.size() > 1:
		var group:= WorkerThreadPool.add_group_task(batch.run, batch.jobs.size(), -1,
			true, "pile redraw")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for job in batch.jobs:
			job.write_cells()
	HotSpots.add(&"wait pile redraw", t)

	var worker_us:= 0
	var wrote:= 0
	t = Time.get_ticks_usec()
	for i in batch.jobs.size():
		var job:= batch.jobs [i]
		worker_us += job.usec
		wrote += job.done
		job_chunks [i].restore_crust()


		job_chunks [i].flush_instance_buffer()
	var upload_us:= Time.get_ticks_usec() - t
	HotSpots.add_usec(&"worker pile redraw", worker_us)
	if wrote > 0:
		_cell_cost_us = lerpf(_cell_cost_us, float(worker_us) / wrote, 0.2)
	if batch.jobs.size() > 0:
		_upload_cost_us = lerpf(_upload_cost_us, float(upload_us) / batch.jobs.size(), 0.2)

	var written_cells:= PackedInt32Array()
	var put_back:= PackedInt32Array()
	var top:= _cell_queue.size() - 1
	for k in taken:
		var gc:= _cell_queue [top - k]
		var j:= cell_job [k]
		if j >= 0 and cell_pos [k] >= batch.jobs [j].done:
			put_back.append(gc)
		elif j != -2:
			written_cells.append(gc)
			_cell_render_h [gc] = cell_height(gc % _nc, gc / _nc)


	_cell_queue.resize(_cell_queue.size() - taken)
	put_back.reverse()
	_cell_queue.append_array(put_back)


	if written_cells.size() > 0:
		cells_redrawn.emit(written_cells)
	HotSpots.add(&"frame pile cells", started)


func pluck_at(world_pos: Vector3, max_dist: float = 0.35,
		aim_from: Vector3 = Vector3.ZERO, aim_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var c:= cell_at(world_pos.x, world_pos.z)
	var ck:= chunk_index_for_cell(c.x, c.y)
	if ck < 0:
		return { }
	var result: Dictionary = chunks [ck].pluck_nearest(world_pos, max_dist, aim_from, aim_dir)
	if result.is_empty():
		return { }
	GameState.remove_hay(1.0)
	GameState.strand_plucked.emit(world_pos)
	return result


func peek_at(world_pos: Vector3, max_dist: float = 0.35,
		aim_from: Vector3 = Vector3.ZERO, aim_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var c:= cell_at(world_pos.x, world_pos.z)
	var ck:= chunk_index_for_cell(c.x, c.y)
	if ck < 0:
		return { }
	return chunks [ck].peek_nearest(world_pos, max_dist, aim_from, aim_dir)


func _chunks_near(center: Vector3, radius: float) -> PackedInt32Array:
	var seen:= { }
	var out:= PackedInt32Array()
	for dz: float in [- radius, 0.0, radius]:
		for dx: float in [- radius, 0.0, radius]:
			var c:= cell_at(center.x + dx, center.z + dz)
			var ck:= chunk_index_for_cell(c.x, c.y)
			if ck >= 0 and not seen.has(ck):
				seen [ck] = true
				out.append(ck)
	return out


func take_in_radius(center: Vector3, radius: float, budget: int) -> Array:
	var out: Array = []
	var real:= int(ceil(strands_under(center, radius)))
	budget = mini(budget, maxi(real, 1))
	for ck in _chunks_near(center, radius):
		if out.size() >= budget:
			break
		out.append_array(chunks [ck].take_in_sphere(center, radius, budget - out.size()))
	return out


func carve_volume(center: Vector3, radius: float, volume: float) -> float:
	settle_join()
	if volume <= 0.0:
		return 0.0
	var idxs:= _disc_vertices(center, radius)
	if idxs.is_empty():
		return 0.0

	var area: float = Cfg.CELL * Cfg.CELL
	var left:= volume
	var passes:= idxs.size()
	while left > volume * 1e-06 and not idxs.is_empty() and passes > 0:
		passes -= 1
		var drop: float = left / (float(idxs.size()) * area)
		var still:= PackedInt32Array()
		for idx in idxs:
			var h:= heights [idx]
			var take:= minf(h, drop)
			heights [idx] = h - take
			left -= take * area
			_touch_vertex(idx % _nv, idx / _nv)
			if heights [idx] > 0.0:
				still.append(idx)
		idxs = still
	return volume - maxf(left, 0.0)


func _disc_vertices(center: Vector3, radius: float) -> PackedInt32Array:
	var r2:= radius * radius
	var lo:= cell_at(center.x - radius, center.z - radius)
	var hi:= cell_at(center.x + radius, center.z + radius)
	var idxs:= PackedInt32Array()
	for j in range(maxi(lo.y, 0), mini(hi.y + 2, _nv)):
		for i in range(maxi(lo.x, 0), mini(hi.x + 2, _nv)):
			var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
			var dx:= wx - center.x
			var dz:= wz - center.z
			if dx * dx + dz * dz > r2:
				continue
			if heights [j * _nv + i] <= 0.0:
				continue
			idxs.append(j * _nv + i)
	if idxs.is_empty():
		var c:= cell_at(center.x, center.z)
		for dj in 2:
			for di in 2:
				var i:= c.x + di
				var j:= c.y + dj
				if in_bounds_vert(i, j) and heights [j * _nv + i] > 0.0:
					idxs.append(j * _nv + i)
	return idxs


func points_in_ring(center: Vector3, inner: float, outer: float,
		floor_h: float) -> PackedVector3Array:
	var out:= PackedVector3Array()
	var inner2:= inner * inner
	var outer2:= outer * outer
	var lo:= cell_at(center.x - outer, center.z - outer)
	var hi:= cell_at(center.x + outer, center.z + outer)
	for j in range(maxi(lo.y, 0), mini(hi.y + 2, _nv)):
		var row:= j * _nv
		var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
		var dz:= wz - center.z
		for i in range(maxi(lo.x, 0), mini(hi.x + 2, _nv)):
			var h:= heights [row + i]
			if h < floor_h:
				continue
			var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
			var dx:= wx - center.x
			var d2:= dx * dx + dz * dz
			if d2 < inner2 or d2 > outer2:
				continue
			out.append(Vector3(wx, h, wz))
	return out


func strands_under(center: Vector3, radius: float) -> float:
	var volume:= 0.0
	for idx in _disc_vertices(center, radius):
		volume += heights [idx] * Cfg.CELL * Cfg.CELL
	return volume * Cfg.PACKING / Cfg.STRAND_VOLUME


func sweep_under(center: Vector3, radius: float, max_height: float) -> float:
	settle_join()
	var volume:= 0.0
	for idx in _disc_vertices(center, radius):
		if heights [idx] > max_height:
			continue
		volume += heights [idx] * Cfg.CELL * Cfg.CELL
		heights [idx] = 0.0
		_touch_vertex(idx % _nv, idx / _nv)
	return volume * Cfg.PACKING / Cfg.STRAND_VOLUME


func sweep_islands(max_height: float, live:= false) -> float:
	settle_join()
	var n:= heights.size()
	var seen:= PackedByteArray()
	seen.resize(n)
	var stack:= PackedInt32Array()
	var volume:= 0.0
	var islands:= 0
	for start in n:
		if heights [start] <= 0.0 or seen [start] != 0:
			continue

		var members:= PackedInt32Array()
		var tallest:= 0.0
		stack.clear()
		stack.append(start)
		seen [start] = 1
		while not stack.is_empty():
			var idx:= stack [stack.size() - 1]
			stack.resize(stack.size() - 1)
			members.append(idx)
			tallest = maxf(tallest, heights [idx])
			var i:= idx % _nv
			var j:= idx / _nv
			for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var ni: int = i + step.x
				var nj: int = j + step.y
				if not in_bounds_vert(ni, nj):
					continue
				var nidx:= nj * _nv + ni
				if heights [nidx] > 0.0 and seen [nidx] == 0:
					seen [nidx] = 1
					stack.append(nidx)
		if tallest > max_height:
			continue
		for idx in members:
			volume += heights [idx] * Cfg.CELL * Cfg.CELL
			heights [idx] = 0.0
			if live:
				_touch_vertex(idx % _nv, idx / _nv)
		islands += 1
	var strands:= volume * Cfg.PACKING / Cfg.STRAND_VOLUME
	if islands > 0:
		print("[hay] swept %d islands of stubble under %.2f m, %.0f strands"
			% [islands, max_height, strands])
	return strands


func count_in_radius(center: Vector3, radius: float) -> int:
	var n:= 0
	for ck in _chunks_near(center, radius):
		n += chunks [ck].count_in_sphere(center, radius)
	return n


func update_lod(cam_pos: Vector3) -> void:
	var settings:= Vector4(Cfg.effective_lod_near(), Cfg.effective_lod_far(),
		Cfg.crust_lod_min, Cfg.crust_shadow_distance)
	if cam_pos != _lod_eye or settings != _lod_settings:
		for c in chunks:
			c.update_lod(cam_pos, settings.x, settings.y)
		_lod_eye = cam_pos
		_lod_settings = settings
	else:
		for c: HayChunk in _lod_dirty:
			c.update_lod(cam_pos, settings.x, settings.y)
	_lod_dirty.clear()


var _sweep_at:= 0
var _sweep_left:= 0


const LOD_STEP:= 0.5
const LOD_JUMP:= 8.0

const LOD_SPREAD:= 8

static var old_lod: bool = "--oldpilelod" in OS.get_cmdline_user_args()


func tick_lod(cam_pos: Vector3) -> void:
	var settings:= Vector4(Cfg.effective_lod_near(), Cfg.effective_lod_far(),
		Cfg.crust_lod_min, Cfg.crust_shadow_distance)
	var moved:= cam_pos.distance_squared_to(_lod_eye)
	if settings != _lod_settings or not (moved <= LOD_JUMP * LOD_JUMP):
		_sweep_left = 0
		update_lod(cam_pos)
		return
	if _sweep_left == 0 and moved > LOD_STEP * LOD_STEP:
		_lod_eye = cam_pos
		_sweep_left = chunks.size()
	if _sweep_left > 0:
		var n:= chunks.size()
		var per:= mini(_sweep_left, ceili(float(n) / LOD_SPREAD))
		for k in per:
			if _sweep_at >= n:
				_sweep_at = 0
			chunks [_sweep_at].update_lod(cam_pos, settings.x, settings.y)
			_sweep_at += 1
		_sweep_left -= per
	for c: HayChunk in _lod_dirty:
		c.update_lod(cam_pos, settings.x, settings.y)
	_lod_dirty.clear()


func rebuild_density() -> void:
	for c in chunks:
		c.set_density(Cfg.crust_strands_per_cell)
		_lod_dirty [c] = true


func rebuild_shells() -> int:
	StrandFactory.reset_pile_render_resources()
	var surface_material:= StrandFactory.pile_surface_material()
	var shadow_material:= StrandFactory.shadow_proxy_material()
	for c in chunks:
		c.rebuild_shell_renderer(surface_material, shadow_material)
	return chunks.size()


func rebuild_everything() -> void:
	for c in chunks:
		_rebuild_chunk(c)
		c.rebuild_all_cells()


func drawn_instance_count() -> int:
	var n:= 0
	for c in chunks:
		n += c.drawn_instances()
	return n
