class_name BeltRunBatch
extends Node3D


const INITIAL:= 16

const PAD:= 1.5


const LOD_SLICE:= 15


class KindDraw:


	var levels: Array = []

	var cuts:= PackedFloat32Array()

	var by_strands:= false

	var base_scale:= 1.0

	var rest:= Basis.IDENTITY


class Bin:
	var node: MultiMeshInstance3D
	var mm: MultiMesh

	var seqs:= PackedInt32Array()
	var kind:= 0
	var group:= 0
	var part:= 0


	var shown:= true


class Slot:
	var kind:= 0
	var scale:= 1.0
	var side:= 0.0
	var lift:= 0.0
	var rel:= 0.0
	var group:= 0


	var rest:= Basis.IDENTITY
	var locals: Array [Transform3D] = []

	var bins: Array [Bin] = []
	var slots:= PackedInt32Array()

	var drawn_s:= - INF


class RunDraw:
	var run: BeltRun
	var straight:= true
	var basis:= Basis.IDENTITY
	var origin:= Vector3.ZERO
	var end:= Vector3.ZERO
	var length:= 0.0


	var line:= PackedVector3Array()
	var cum:= PackedFloat64Array()
	var bases: Array [Basis] = []


	var bins: Dictionary = { }
	var free_bins: Array [Bin] = []
	var jam_bins: Array [Bin] = []


	var slots: Dictionary = { }
	var row_slots: Array = []

	var lod: Dictionary = { }
	var holder: Node3D


	var drawn_free:= -1.0
	var drawn_jam:= -1.0


	var dirty:= false


	var settled:= false


	var raw_free:= -1.0
	var raw_jam:= -1.0

	var active:= false


	var moved:= 0
	var out_bins: Array [Bin] = []
	var out_idx:= PackedInt32Array()
	var out_xf: Array [Transform3D] = []
	var out_rows:= 0


	var centre:= Vector3.ZERO
	var radius:= 0.0
	var phase:= 0


var _runs: Array [RunDraw] = []
var _by_run: Dictionary = { }
var _kinds: Dictionary = { }
var _draw_meshes: Dictionary = { }

var _scales: Dictionary = { }

var _spare: Array [Slot] = []

var _events: Array = []


var _queue: Array = []


var _active: Array [RunDraw] = []


var last_us:= 0
var rows_written:= 0

var _st:= PackedFloat64Array()
var _lod_cursor:= 0


static var instance: BeltRunBatch = null


static var draw_headless:= false


static var hide_empty: bool = not ("--keepemptymm" in OS.get_cmdline_user_args())


static var cull: bool = not ("--olddrawer" in OS.get_cmdline_user_args())


static var audit_switch: bool = "--drawaudit" in OS.get_cmdline_user_args()

static var _cull_on:= false
static var _eye:= Vector3.ZERO
static var _fwd:= Vector3.FORWARD
static var _half_view:= PI
static var _limit:= 0.0
static var _frame:= 0


const VIEW_MARGIN:= 0.2


const HIDE_SLACK:= 2.0

const RANGE_MARGIN:= 4.0


static func watch(run: BeltRun) -> void:
	if DisplayServer.get_name() == "headless" and not draw_headless:
		return
	if instance == null:
		var tree:= Engine.get_main_loop() as SceneTree
		var scene: Node = tree.current_scene if tree != null else null
		if scene == null:
			return
		var made:= BeltRunBatch.new()
		made.name = "BeltRunBatch"
		scene.add_child(made)
	instance.adopt(run)


static func unwatch(run: BeltRun) -> void:
	if instance != null:
		instance.drop(run)


static func stand_in(kind: int, strands: int) -> Node3D:
	var parts:= picture_of(kind, strands)
	if parts.is_empty():
		return null
	var root:= Node3D.new()
	root.name = "Record"
	for part: Dictionary in parts:
		var mi:= MeshInstance3D.new()
		mi.mesh = part ["mesh"]
		mi.transform = part ["local"]
		root.add_child(mi)
	return root


static func picture_of(kind: int, strands: int) -> Array:
	if instance == null or not is_instance_valid(instance):
		return []
	var kd:= instance._kind_draw(kind)
	var level: Array = kd.levels [0]
	if level.is_empty():
		return []
	var scale:= instance._scale_for(kd, strands)
	var scaling:= Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO)
	var rest:= Transform3D(kd.rest, Vector3.ZERO)
	var out: Array = []
	for part in level.size():
		out.append({ "mesh": level [part] ["mesh"],
			"local": rest * scaling * (level [part] ["local"] as Transform3D) })
	return out


func _enter_tree() -> void:
	if instance == null:
		instance = self
	top_level = true
	process_priority = 100
	_st.resize(10)
	if not Cfg.gfx_changed.is_connected(_on_gfx_changed):
		Cfg.gfx_changed.connect(_on_gfx_changed)
	_range_metres = Cfg.machine_distance_metres() if cull else 0.0


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if Cfg.gfx_changed.is_connected(_on_gfx_changed):
		Cfg.gfx_changed.disconnect(_on_gfx_changed)


var _range_metres:= 0.0


func _on_gfx_changed() -> void:
	var metres:= Cfg.machine_distance_metres() if cull else 0.0
	if is_equal_approx(metres, _range_metres):
		return
	_range_metres = metres
	for rd in _runs:
		var end:= _range_end(rd)
		for b: Bin in rd.bins.values():
			b.node.visibility_range_end = end
			b.node.visibility_range_end_margin = RANGE_MARGIN


func _range_end(rd: RunDraw) -> float:
	if _range_metres <= 0.0:
		return 0.0
	return _range_metres + 2.0 * rd.radius


func adopt(run: BeltRun) -> void:
	if _by_run.has(run):
		return
	var rd:= RunDraw.new()
	rd.run = run
	var line:= run.line()
	rd.straight = run.is_straight()
	rd.basis = run.basis_at_start()
	rd.origin = line [0] if line.size() > 0 else Vector3.ZERO
	rd.end = line [line.size() - 1] if line.size() > 0 else Vector3.ZERO
	rd.length = run.length()
	rd.line = line
	rd.cum = run.cum()
	rd.bases = run.seg_bases()
	var box:= _bounds(rd, false)
	rd.centre = box.get_center()
	rd.radius = box.size.length() * 0.5
	rd.phase = _runs.size() & 3
	rd.holder = Node3D.new()
	rd.holder.name = "Run%d" % _runs.size()
	add_child(rd.holder)
	_runs.append(rd)
	_by_run [run] = rd
	run.event_sink = _events
	run.draw_queue = _queue
	run.draw_queued = false
	_activate(rd)
	var f:= run.first()
	for row in range(f, f + run.count()):
		var rec:= run.record(row)
		_seat(rd, rec, run.row_group(row), run.rel_of(row))
	rd.dirty = true


func drop(run: BeltRun) -> void:
	var rd: RunDraw = _by_run.get(run)
	if rd == null:
		return
	run.event_sink = null
	run.draw_queue = null
	run.draw_queued = false
	if rd.active:
		rd.active = false
		_active.erase(rd)
	_runs.erase(rd)
	_by_run.erase(run)
	rd.holder.queue_free()


func debug_line(run: BeltRun) -> String:
	var rd: RunDraw = _by_run.get(run)
	if rd == null:
		return ""
	return "drawer straight %s drawn_jam %.3f jam_offset %.3f drawn_free %.3f free_offset %.3f dirty %s slots %d origin %s" % [
		rd.straight, rd.drawn_jam, run.jam_offset(), rd.drawn_free, run.free_offset(),
		rd.dirty, rd.slots.size(), str(rd.origin)]


func debug_drawn(run: BeltRun, seq: int) -> Array:
	var rd: RunDraw = _by_run.get(run)
	if rd == null:
		return [- INF, -1]
	var sl: Slot = rd.slots.get(seq)
	if sl == null:
		return [- INF, -1]
	if _moving(rd, sl.group) and not sl.bins.is_empty():
		return [sl.rel + (sl.bins [0].node.position as Vector3).dot(rd.basis.z), sl.group]
	return [sl.drawn_s, sl.group]


func debug_sweep() -> PackedStringArray:
	var out:= PackedStringArray()
	if not _events.is_empty():
		_apply_events()
	var records:= 0
	var wrong:= 0
	for rd in _runs:
		var run:= rd.run
		records += run.count()
		var why:= _audit(rd)
		if why != "":
			wrong += 1
			out.append("  DRAWER run from %v len %.2f: %s" % [rd.origin, rd.length, why])
		for b: Bin in rd.bins.values():
			for idx in b.seqs.size():
				var seq:= b.seqs [idx]
				var sl: Slot = rd.slots.get(seq)
				if sl == null or b.part >= sl.slots.size():
					continue
				var want:= _xform(rd, sl, b.part, _seated_s(rd, sl, seq))
				var have:= b.mm.get_instance_transform(idx)
				if have.origin.distance_to(want.origin) > 0.3:
					wrong += 1
					out.append("  BUFFER run from %v len %.2f: seq %d part %d in K%dG%dP%d slot %d drawn at %v, books say %v (group %d rel %.3f drawn_s %.3f)"
						% [rd.origin, rd.length, seq, b.part, b.kind, b.group, b.part, idx,
							have.origin, want.origin, sl.group, sl.rel, sl.drawn_s])
	out.append("drawer sweep    = %d runs, %d records, %d wrong" % [_runs.size(), records, wrong])
	return out


func drawn_free(run: BeltRun) -> float:
	var rd: RunDraw = _by_run.get(run)
	return rd.drawn_free if rd != null else 0.0


func live_bins() -> int:
	var n:= 0
	for rd in _runs:
		for b: Bin in rd.bins.values():
			if b.mm.visible_instance_count > 0:
				n += 1
	return n


func lod_census() -> Dictionary:
	var out:= { }
	for rd in _runs:
		for lvl: int in rd.lod.values():
			out [lvl] = int(out.get(lvl, 0)) + 1
	return out


func _kind_draw(kind: int) -> KindDraw:
	if _kinds.has(kind):
		return _kinds [kind]
	var kd:= KindDraw.new()
	_kinds [kind] = kd
	var body: Carryable = ItemDb.make(BeltRun.ITEM_IDS [kind])
	if body == null:
		kd.levels.append([])
		kd.cuts = PackedFloat32Array([0.0])
		return kd
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true
	body.visible = false
	add_child(body)
	if body is HayWad:
		var wad:= body as HayWad
		kd.by_strands = true
		kd.rest = BeltPath.TUFT_REST if body is HayTuft else Basis.IDENTITY
		var meshes: Array = wad._lod_meshes()
		kd.cuts = wad._lod_cuts().duplicate()
		for lvl in meshes.size():
			wad._set_lod(lvl)
			var mi: MeshInstance3D = wad._meshes [0]


			kd.levels.append([{ "mesh": _draw_mesh(mi), "local": mi.transform }])
	else:
		var inv:= body.global_transform.affine_inverse()
		var parts: Array = []
		for mi in body._meshes:
			if mi.mesh == null:
				continue
			parts.append({ "mesh": _draw_mesh(mi), "local": inv * mi.global_transform })
		kd.levels.append(parts)
		kd.cuts = PackedFloat32Array([0.0])
	remove_child(body)
	body.queue_free()
	if kd.levels.is_empty():
		kd.levels.append([])
	if kd.cuts.is_empty():
		kd.cuts = PackedFloat32Array([0.0])
	kd.base_scale = _scale_for(kd, Cfg.WAD_BASE_STRANDS)
	return kd


func _draw_mesh(mi: MeshInstance3D) -> Mesh:
	var key: Array = [mi.mesh.get_rid()]
	for i in mi.mesh.get_surface_count():
		var mat:= mi.get_active_material(i)
		key.append(mat.get_rid() if mat != null else RID())
	if _draw_meshes.has(key):
		return _draw_meshes [key]
	var mesh: Mesh = mi.mesh.duplicate()
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, mi.get_active_material(i))
	_draw_meshes [key] = mesh
	return mesh


func _scale_for(kd: KindDraw, strands: int) -> float:
	if not kd.by_strands:
		return 1.0
	var s: Variant = _scales.get(strands)
	if s == null:
		s = HayWad.scale_for(strands)
		_scales [strands] = s
	return float(s)


func _bin_key(kind: int, group: int, part: int) -> int:
	return (kind * 4 + group) * 16 + part


func _moving(rd: RunDraw, group: int) -> bool:
	return rd.straight and group != BeltRun.Group.BACK


func _bin(rd: RunDraw, kind: int, group: int, part: int) -> Bin:
	var key:= _bin_key(kind, group, part)
	if rd.bins.has(key):
		return rd.bins [key]
	var kd:= _kind_draw(kind)
	var lvl: int = rd.lod.get(kind, 0)
	rd.lod [kind] = lvl
	var b:= Bin.new()
	b.kind = kind
	b.group = group
	b.part = part
	b.mm = MultiMesh.new()
	b.mm.transform_format = MultiMesh.TRANSFORM_3D
	var level: Array = kd.levels [lvl]
	if part < level.size():
		b.mm.mesh = level [part] ["mesh"]
	b.mm.instance_count = INITIAL
	b.mm.visible_instance_count = 0
	b.mm.custom_aabb = _bounds(rd, _moving(rd, group))
	b.node = MultiMeshInstance3D.new()
	b.node.name = "K%dG%dP%d" % [kind, group, part]
	b.node.multimesh = b.mm
	b.node.top_level = true
	b.node.visibility_range_end = _range_end(rd)
	b.node.visibility_range_end_margin = RANGE_MARGIN

	b.shown = not hide_empty
	b.node.visible = b.shown
	rd.holder.add_child(b.node)
	rd.bins [key] = b
	if _moving(rd, group):
		if group == BeltRun.Group.FREE:
			rd.free_bins.append(b)
			b.node.position = rd.basis.z * maxf(rd.drawn_free, 0.0)
		else:
			rd.jam_bins.append(b)
			b.node.position = rd.basis.z * maxf(rd.drawn_jam, 0.0)
	return b


func _bounds(rd: RunDraw, moving: bool) -> AABB:
	var lo:= rd.origin
	var hi:= rd.end
	if moving:
		lo = rd.origin - rd.basis.z * rd.length
		hi = rd.origin + rd.basis.z * rd.length
	var box:= AABB(lo, Vector3.ZERO).expand(hi)
	if not rd.straight:
		for p in rd.line:
			box = box.expand(p)
	box = box.grow(PAD)
	box.size.y += PAD
	return box


func _seat(rd: RunDraw, rec: Dictionary, group: int, rel: float) -> void:
	var seq:= int(rec ["seq"])
	if rd.slots.has(seq):
		return
	var kind:= int(rec ["kind"])
	var kd:= _kind_draw(kind)
	var sl: Slot
	if _spare.is_empty():
		sl = Slot.new()
	else:
		sl = _spare.pop_back()
		sl.locals.clear()
		sl.bins.clear()
		sl.drawn_s = - INF
	sl.kind = kind
	sl.scale = _scale_for(kd, int(rec ["strands"]))
	sl.side = float(rec ["side"])
	sl.lift = float(rec ["lift"])
	sl.rel = rel
	sl.group = group
	sl.rest = kd.rest
	var level: Array = kd.levels [0]
	var scaling:= Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sl.scale), Vector3.ZERO)
	for part in level.size():
		sl.locals.append(scaling * (level [part] ["local"] as Transform3D))
	sl.slots.resize(level.size())
	var s:= rel if _moving(rd, group) else float(rec ["s"])
	for part in level.size():
		var b:= _bin(rd, kind, group, part)
		var idx:= b.seqs.size()
		b.seqs.append(seq)
		sl.bins.append(b)
		sl.slots [part] = idx
		if idx >= b.mm.instance_count:
			b.mm.instance_count *= 2


			_refresh_bin(rd, b)
		_put(rd, b, idx, _xform(rd, sl, part, s))
		b.mm.visible_instance_count = idx + 1
		_show(b)
	rd.slots [seq] = sl


func _unseat(rd: RunDraw, seq: int) -> void:
	var sl: Slot = rd.slots.get(seq)
	if sl == null:
		return
	for part in sl.slots.size():
		var b:= sl.bins [part]
		var idx:= sl.slots [part]
		var last:= b.seqs.size() - 1
		if idx != last:
			var moved_seq:= b.seqs [last]
			b.seqs [idx] = moved_seq
			var moved: Slot = rd.slots [moved_seq]
			moved.slots [part] = idx
			_put(rd, b, idx, _xform(rd, moved, part, _seated_s(rd, moved, moved_seq)))
		b.seqs.resize(last)
		b.mm.visible_instance_count = last
		if idx == last:


			b.mm.set_instance_transform(last, Transform3D())
		_show(b)
	rd.slots.erase(seq)
	_spare.append(sl)


func _show(b: Bin) -> void:
	var want:= not hide_empty or not b.seqs.is_empty()
	if b.shown != want:
		b.shown = want
		b.node.visible = want


func _row_of(rd: RunDraw, seq: int) -> int:
	var run:= rd.run
	var f:= run.first()
	for row in range(f, f + run.count()):
		if run.seq_of(row) == seq:
			return row
	return -1


func _seated_s(rd: RunDraw, sl: Slot, seq: int) -> float:
	if _moving(rd, sl.group):
		return sl.rel
	var row:= _row_of(rd, seq)
	if row >= 0:
		return rd.run.s_of(row)
	return sl.drawn_s if sl.drawn_s > - INF else sl.rel


func _xform(rd: RunDraw, sl: Slot, part: int, s: float) -> Transform3D:
	if rd.straight:
		return Transform3D(rd.basis * sl.rest,
			rd.origin + rd.basis * Vector3(sl.side, sl.lift, s)) * sl.locals [part]
	var p:= rd.run.pose_at(s, sl.side, sl.lift)
	return Transform3D(p.basis * sl.rest, p.origin) * sl.locals [part]


func _apply_events() -> void:
	for ev: Array in _events:
		var rd: RunDraw = _by_run.get(ev [0])
		if rd == null:
			continue
		rd.dirty = true
		_activate(rd)
		if _auditing:
			_remember(rd, ev)
		match int(ev [1]):
			BeltRun.Ev.BOARD:
				var rec: Dictionary = ev [2]
				_seat(rd, rec, int(rec ["group"]), float(rec ["rel"]))
			BeltRun.Ev.MOVE:
				var seq:= int(ev [2])
				var sl: Slot = rd.slots.get(seq)
				if sl == null:
					continue
				var group:= int(ev [3])
				var rel:= float(ev [4])
				if sl.group == group and _moving(rd, group):
					sl.rel = rel
					_rewrite(rd, sl, rel)
					continue
				var rec:= { "seq": seq, "kind": sl.kind, "strands": Cfg.WAD_BASE_STRANDS,
					"side": sl.side, "lift": sl.lift, "s": rel }
				var scale:= sl.scale
				var locals:= sl.locals.duplicate()
				_unseat(rd, seq)
				_seat(rd, rec, group, rel)
				var again: Slot = rd.slots [seq]
				again.scale = scale
				again.locals = locals
				_rewrite(rd, again, rel)
			BeltRun.Ev.LEAVE:
				_unseat(rd, int(ev [2]))
			BeltRun.Ev.REBASE:
				var group:= int(ev [2])
				if not _moving(rd, group):
					continue
				var run:= rd.run
				var f:= run.first()
				for row in range(f, f + run.count()):
					if run.row_group(row) != group:
						continue
					var sl: Slot = rd.slots.get(run.seq_of(row))
					if sl == null:
						continue
					sl.rel = run.rel_of(row)
					_rewrite(rd, sl, sl.rel)
	_events.clear()


func _rewrite(rd: RunDraw, sl: Slot, s: float) -> void:
	for part in sl.slots.size():
		_put(rd, sl.bins [part], sl.slots [part], _xform(rd, sl, part, s))


func _put(_rd: RunDraw, b: Bin, idx: int, xf: Transform3D) -> void:
	b.mm.set_instance_transform(idx, xf)


func _refresh_bin(rd: RunDraw, b: Bin, only: int = -1) -> void:
	var moving:= _moving(rd, b.group)
	var lo:= 0 if only < 0 else only
	var hi:= b.seqs.size() if only < 0 else mini(only + 1, b.seqs.size())
	for i in range(lo, hi):
		var sl: Slot = rd.slots.get(b.seqs [i])
		if sl == null or b.part >= sl.slots.size():
			continue
		var s: float
		if moving:
			s = sl.rel
		elif sl.drawn_s > - INF:
			s = sl.drawn_s
		else:
			s = _seated_s(rd, sl, b.seqs [i])
		b.mm.set_instance_transform(i, _xform(rd, sl, b.part, s))


static func _rebuild_rows(rd: RunDraw) -> void:
	var run:= rd.run
	var f:= run.first()
	var n:= run.count()
	rd.row_slots.resize(n)
	for k in n:
		rd.row_slots [k] = rd.slots.get(run.seq_of(f + k))


func _activate(rd: RunDraw) -> void:
	if not rd.active:
		rd.active = true
		_active.append(rd)


func _drain_queue() -> void:
	for run: BeltRun in _queue:
		run.draw_queued = false
		var rd: RunDraw = _by_run.get(run)
		if rd != null:
			_activate(rd)
	_queue.clear()


func _process(_delta: float) -> void:
	var t0:= Time.get_ticks_usec()
	_auditing = audit_switch or audit_always
	if not _events.is_empty():
		_apply_events()
	HotSpots.add(&"drawer events", t0)
	var t_a:= Time.get_ticks_usec()


	if _auditing:
		_audit_slice()
	HotSpots.add(&"drawer audit", t_a)
	if not _queue.is_empty():
		_drain_queue()
	var t_r:= Time.get_ticks_usec()
	var active:= _active
	var n_active:= active.size()
	_frac = Engine.get_physics_interpolation_fraction()
	_now_tick = Engine.get_physics_frames()
	_set_view()
	if threaded and n_active >= PAR_MIN:
		_par_active = active
		_par_tasks = mini(n_active, _pool_tasks)
		var id:= WorkerThreadPool.add_group_task(_draw_share, _par_tasks, -1, true,
			"belt drawer")
		WorkerThreadPool.wait_for_group_task_completion(id)
		_par_active = []
	else:
		for rd in active:
			_draw_run(rd, _st, _frac)
	HotSpots.add(&"drawer runs", t_r)


	var t_w:= Time.get_ticks_usec()
	rows_written = 0
	var keep:= 0
	for i in n_active:
		var rd:= active [i]
		if not rd.active:
			continue
		active [keep] = rd
		keep += 1
		_apply_run(rd)
	active.resize(keep)
	HotSpots.add(&"drawer apply", t_w)
	var t_l:= Time.get_ticks_usec()
	_lod_slice()
	HotSpots.add(&"drawer lod", t_l)
	last_us = Time.get_ticks_usec() - t0
	HotSpots.add_usec(&"frame belt drawer", last_us)


var _auditing:= false

static var audit_always:= false
var _audit_cursor:= 0

var reports:= 0

var checks:= 0
var _history:= { }
var _reported:= { }
const AUDIT_PER_FRAME:= 6
const HISTORY:= 32


const AUDIT_TOLERANCE:= 1.0


func _remember(rd: RunDraw, ev: Array) -> void:
	var h: Array = _history.get(rd, [])
	var what: String
	match int(ev [1]):
		BeltRun.Ev.BOARD:
			var rec: Dictionary = ev [2]
			what = "BOARD seq %d group %d rel %.3f s %.3f" % [int(rec ["seq"]), int(rec ["group"]),
				float(rec ["rel"]), float(rec.get("s", 0.0))]
		BeltRun.Ev.MOVE:
			what = "MOVE seq %d to group %d rel %.3f" % [int(ev [2]), int(ev [3]), float(ev [4])]
		BeltRun.Ev.LEAVE:
			what = "LEAVE seq %d%s" % [int(ev [2]), "" if rd.slots.has(int(ev [2])) else " (not held)"]
		_:
			what = "REBASE group %d" % int(ev [2])
	h.append("f%d %s" % [Engine.get_physics_frames(), what])
	if h.size() > HISTORY:
		h.remove_at(0)
	_history [rd] = h


func _audit_slice() -> void:
	var n:= _runs.size()
	if n == 0:
		return
	var redo: Array [RunDraw] = []
	for k in mini(n, AUDIT_PER_FRAME):
		_audit_cursor = (_audit_cursor + 1) % n
		var rd:= _runs [_audit_cursor]
		if rd.dirty:
			continue
		checks += 1
		var why:= _audit(rd)
		if why != "":
			redo.append(rd)
			if not _reported.has(rd.run):
				_reported [rd.run] = true
				_report(rd, why)
	for rd in redo:
		var run:= rd.run
		drop(run)
		adopt(run)
		_history.erase(rd)


func _audit(rd: RunDraw) -> String:
	var run:= rd.run
	var f:= run.first()
	var n:= run.count()
	if rd.slots.size() != n:
		return "holds %d slots for %d records" % [rd.slots.size(), n]
	for b: Bin in rd.bins.values():
		if b.mm.visible_instance_count != b.seqs.size():
			return "bin K%dG%dP%d draws %d instances for %d records" % [b.kind, b.group, b.part,
				b.mm.visible_instance_count, b.seqs.size()]
		if hide_empty and b.node.visible == b.seqs.is_empty():
			return "bin K%dG%dP%d is %s with %d records" % [b.kind, b.group, b.part,
				"shown" if b.node.visible else "hidden", b.seqs.size()]
		for seq in b.seqs:
			if not rd.slots.has(seq):
				return "bin K%dG%dP%d draws seq %d, which is not held" % [b.kind, b.group, b.part, seq]
	for row in range(f, f + n):
		var seq:= run.seq_of(row)
		var sl: Slot = rd.slots.get(seq)
		if sl == null:
			return "seq %d (row %d) is not drawn" % [seq, row]
		if sl.group != run.row_group(row):
			return "seq %d drawn in group %d, run has it in %d" % [seq, sl.group, run.row_group(row)]
		var s:= run.s_of(row)
		var drawn:= sl.drawn_s
		if _moving(rd, sl.group) and not sl.bins.is_empty():
			drawn = sl.rel + (sl.bins [0].node.position as Vector3).dot(rd.basis.z)
		elif drawn == - INF:
			continue
		if absf(drawn - s) > AUDIT_TOLERANCE:
			return "seq %d drawn at s %.3f, run has it at %.3f (group %d rel %.3f run rel %.3f)" % [
				seq, drawn, s, sl.group, sl.rel, run.rel_of(row)]
	return ""


const REPORT_LOG:= "user://logs/beltdraw.log"


func _report(rd: RunDraw, why: String) -> void:
	reports += 1
	var run:= rd.run
	var g:= run.groups()
	var lines:= PackedStringArray()
	lines.append("[beltdraw] %s run from %v len %.2f straight %s: %s" % [
		Time.get_datetime_string_from_system(), rd.origin, rd.length, rd.straight, why])
	lines.append("[beltdraw]   run jam %d free %d back %d, jam_offset %.3f drawn_jam %.3f, free_offset %.3f drawn_free %.3f, awake %s, frame %d"
		% [g.x, g.y, g.z, run.jam_offset(), rd.drawn_jam, run.free_offset(), rd.drawn_free,
			run.awake, Engine.get_physics_frames()])
	for line: String in _history.get(rd, []):
		lines.append("[beltdraw]   " + line)
	lines.append("[beltdraw]   redrawn from the run")
	for line in lines:
		print(line)
	var f:= FileAccess.open(REPORT_LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(REPORT_LOG, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		for line in lines:
			f.store_line(line)
		f.close()


static var threaded: bool = not ("--nodrawthreads" in OS.get_cmdline_user_args())

const PAR_MIN:= 16


static var _pool_tasks: int = mini(OS.get_processor_count(), 4 if OS.is_debug_build() else 8)
static var _par_active: Array [RunDraw] = []
static var _par_tasks:= 1
static var _frac:= 0.0

static var _now_tick:= 0


func _set_view() -> void:
	_frame += 1
	_cull_on = false
	if not cull or _auditing:
		return
	var cam:= get_viewport().get_camera_3d()
	if cam == null or not cam.is_inside_tree():
		return
	_cull_on = true
	_eye = cam.global_position
	_fwd = - cam.global_basis.z.normalized()
	_limit = _range_metres
	_half_view = PI
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var size:= get_viewport().get_visible_rect().size
		var aspect:= size.x / maxf(size.y, 1.0)

		var th:= tan(deg_to_rad(cam.fov) * 0.5)
		var tw:= th * aspect
		if cam.keep_aspect == Camera3D.KEEP_WIDTH:
			tw = th
			th = tw / maxf(aspect, 0.01)

		_half_view = atan(sqrt(tw * tw + th * th)) + VIEW_MARGIN


static func _unseen(rd: RunDraw) -> bool:
	var v:= rd.centre - _eye
	var d:= v.length()
	var r:= rd.radius
	if _limit > 0.0 and d > _limit + 3.0 * r + RANGE_MARGIN + HIDE_SLACK:
		return true


	if rd.dirty or (_frame + rd.phase) & 3 == 0 or d <= r:
		return false
	if _limit > 0.0 and d - r > _limit:
		return true
	if _half_view >= PI:
		return false
	var a:= acos(clampf(v.dot(_fwd) / d, -1.0, 1.0))
	return a > _half_view + asin(r / d)


static func _draw_share(k: int) -> void:
	var st:= PackedFloat64Array()
	st.resize(10)
	var runs:= _par_active
	var n:= runs.size()
	var frac:= _frac
	var i:= k
	while i < n:
		_draw_run(runs [i], st, frac)
		i += _par_tasks


static func _draw_run(rd: RunDraw, st: PackedFloat64Array, frac: float) -> void:
	var run:= rd.run


	if not rd.dirty and (run.count() == 0 or (not run.awake and rd.settled and run.jam_offset() == rd.raw_jam and run.free_offset() == rd.raw_free)):


		rd.active = false
		return
	if _cull_on and _unseen(rd):
		return
	run.draw_into(st)
	rd.settled = not run.awake
	rd.raw_free = st [0]
	rd.raw_jam = st [3]


	var dt:= run.lead_seconds(frac, _now_tick)
	frac = 1.0
	var fo:= st [0] + minf(st [1] * dt, st [2])
	var jo:= st [3] + minf(st [4] * dt, st [5])
	var head:= int(st [6])
	var je:= head + int(st [7])
	var fe:= je + int(st [8])
	var n:= int(st [9])
	if rd.straight:
		if fo != rd.drawn_free:
			rd.drawn_free = fo
			rd.moved |= 1
		if jo != rd.drawn_jam:
			rd.drawn_jam = jo
			rd.moved |= 2
		rd.dirty = false
		var row:= fe
		while row < n:
			_write_back_row(rd, run, rd.slots.get(run.seq_of(row)), row, frac, dt)
			row += 1
		return


	var dirty:= rd.dirty
	if dirty:
		_rebuild_rows(rd)
		rd.dirty = false
	var pos:= run.rel_raw()
	var rows:= rd.row_slots
	if jo != rd.drawn_jam or dirty:
		var row:= head
		while row < je:
			_write_bend(rd, rows [row - head], pos [row] + jo)
			row += 1
	if fo != rd.drawn_free or dirty:
		var row:= je
		while row < fe:
			_write_bend(rd, rows [row - head], pos [row] + fo)
			row += 1
	rd.drawn_free = fo
	rd.drawn_jam = jo
	var row:= fe
	while row < n:
		_write_back_row(rd, run, rows [row - head], row, frac, dt)
		row += 1


func _apply_run(rd: RunDraw) -> void:
	if rd.moved != 0:
		if rd.moved & 1:
			var at:= rd.basis.z * rd.drawn_free
			for b in rd.free_bins:
				b.node.position = at
		if rd.moved & 2:
			var at:= rd.basis.z * rd.drawn_jam
			for b in rd.jam_bins:
				b.node.position = at
		rd.moved = 0
	if rd.out_rows == 0:
		return
	rows_written += rd.out_rows
	rd.out_rows = 0
	var bins:= rd.out_bins
	var idx:= rd.out_idx
	var xf:= rd.out_xf
	for k in idx.size():
		_put(rd, bins [k], idx [k], xf [k])
	bins.clear()
	idx.clear()
	xf.clear()


static func _emit(rd: RunDraw, sl: Slot, pose: Transform3D) -> void:
	rd.out_rows += 1
	for part in sl.slots.size():
		rd.out_bins.append(sl.bins [part])
		rd.out_idx.append(sl.slots [part])
		rd.out_xf.append(pose * sl.locals [part])


static func _write_back_row(rd: RunDraw, run: BeltRun, sl: Slot, row: int, frac: float, dt: float) -> void:
	if sl == null:
		return
	var s:= run.s_of(row)
	var v:= run.speed_of(row)
	if v > 0.0:
		s += minf(v * frac * dt, run.row_room(row))
	if not rd.straight:
		_write_bend(rd, sl, s)
		return
	if s == sl.drawn_s:
		return
	sl.drawn_s = s
	_emit(rd, sl, Transform3D(rd.basis * sl.rest, rd.origin + rd.basis * Vector3(sl.side, sl.lift, s)))


static func _write_bend(rd: RunDraw, sl: Slot, s: float) -> void:
	if sl == null or s == sl.drawn_s:
		return
	sl.drawn_s = s
	var cum:= rd.cum
	var last:= rd.line.size() - 2
	var k:= 0
	while k < last and s > cum [k + 1]:
		k += 1
	var basis: Basis = rd.bases [k]
	var span: float = cum [k + 1] - cum [k]
	var at: Vector3 = rd.line [k].lerp(rd.line [k + 1], clampf((s - cum [k]) / span, 0.0, 1.0)) + basis.x * sl.side + basis.y * sl.lift
	_emit(rd, sl, Transform3D(basis * sl.rest, at))


func _lod_slice() -> void:
	var n:= _runs.size()
	if n == 0:
		return
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye:= cam.global_position
	var per:= mini(n, maxi(4, n / LOD_SLICE))
	for k in per:
		_lod_cursor += 1
		if _lod_cursor >= n:
			_lod_cursor = 0
		_pick_lod(_runs [_lod_cursor], eye)


func _pick_lod(rd: RunDraw, eye: Vector3) -> void:
	if rd.lod.is_empty():
		return
	var ab:= rd.end - rd.origin
	var len2:= ab.length_squared()
	var t:= 0.0 if len2 < 1e-08 else clampf((eye - rd.origin).dot(ab) / len2, 0.0, 1.0)
	var d:= eye.distance_to(rd.origin + ab * t)
	for kind: int in rd.lod.keys():
		var kd:= _kind_draw(kind)
		var lvl:= kd.cuts.size() - 1
		for i in kd.cuts.size():
			var end:= kd.cuts [i] * kd.base_scale
			if end > 0.0 and d < end:
				lvl = i
				break
		if lvl == int(rd.lod [kind]):
			continue
		rd.lod [kind] = lvl
		var level: Array = kd.levels [lvl]
		for b: Bin in rd.bins.values():
			if b.kind == kind and b.part < level.size():
				b.mm.mesh = level [b.part] ["mesh"]


				if not b.seqs.is_empty():
					_refresh_bin(rd, b, 0)
