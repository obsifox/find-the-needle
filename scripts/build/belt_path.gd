class_name BeltPath
extends Node3D


signal caught(body: RigidBody3D)


signal handed_on(body: RigidBody3D)


signal caught_record(seq: int, kind: int, strands: int)
signal handed_on_record(seq: int, kind: int, strands: int)


const META_SETTLED:= "belt_settled"


static func is_settled(rb: RigidBody3D) -> bool:
	return is_instance_valid(rb) and bool(rb.get_meta(META_SETTLED, false))


static func run_basis(from: Vector3, to: Vector3) -> Basis:
	var fwd:= to - from
	if fwd.length_squared() < 1e-08:
		fwd = Vector3.BACK
	fwd = fwd.normalized()
	var right:= Vector3.UP.cross(fwd)
	if right.length_squared() < 1e-08:
		right = Vector3.RIGHT
	right = right.normalized()
	return Basis(right, fwd.cross(right).normalized(), fwd)


var _spans: Array [Dictionary] = []


const WYE_BACK_EASE_SCALE:= 2.0


const END_DEAD_ZONE:= 0.05


const SETTLE_SPEED:= 0.12


const PROP_SETTLE_SPEED:= 0.35


const DECK_STALL_SHOW:= 0.35


const DECK_STALL_CLEAR:= DECK_STALL_SHOW * 0.4


const DECK_STALL_RELEASE:= 3.0


const DECK_MOVING_FRACTION:= 0.1


const RAIL_MIN_PIECE:= 0.12


var _line: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()


var _riders: Array [Rider] = []


var run:= BeltRun.new()


var records_props:= false


var record_only:= false


var loose_mouth:= INF
var loose_tail:= INF
var _queued_still:= false
var _queued_drive:= 0.0
var _queued_hold_line:= -1.0
static var queued_skip_enabled:= not ("--legacy-belt-queue-work" in OS.get_cmdline_user_args())


var _seg_basis: Array [Basis] = []


var _geom_epoch:= 0

var _mid:= Vector3.ZERO
var _half_len:= 0.0


class Rider:


	var body: RigidBody3D


	var reach: float

	var prop: bool


	var seq: int

	var board: float

	var s: float

	var side: float


	var slide: float


	var glide: float


	var drop: float

	var lift: float

	var rest: Basis

	var speed: float

	var ps: float

	var gap: float


	var placed_s:= -1.0
	var placed_side:= 0.0
	var placed_drop:= 0.0
	var placed_epoch:= -1

	var hold_due:= -1.0


var _seq:= 0


var drive_speed:= Cfg.BELT_SPEED


var record_boost:= 1.0:
	set(v):
		record_boost = v
		run.speed = drive_speed * v
		run.pickup = Cfg.BELT_RIDE_PICKUP * v
		run.boosted = v > 1.0


var stand_belt:= false


static var stand_keeps_straw:= true


var _catching:= true
var _path_root: Node3D


var _deck_held_by_machine:= false
var _deck_stalled:= false


var _deck_shows_held:= false

var _stall_time:= 0.0


var _deck_moved:= 0.0


var downstream: BeltPath = null:
	set(v):
		downstream = v
		_sync_run_links()


var _blocked:= false


var _shut_out: Dictionary = { }

const SHUT_OUT_STILL:= 0.0025


var _outlet_held:= false


var end_deck: BeltPath = null


var _end_feeders: Array [BeltPath] = []


var _end_shut:= false


func set_end_deck(deck: BeltPath) -> void:
	end_deck = deck
	if deck != null and not deck._end_feeders.has(self):
		deck._end_feeders.append(self)
	_sync_end_shut()


func clear_end_feeders() -> void:
	_end_feeders.clear()


func _sync_end_shut() -> void:
	var shut:= downstream == null and is_instance_valid(end_deck) and end_deck._blocked
	if shut == _end_shut:
		return
	_end_shut = shut
	_sync_run_links()
	if not shut:
		wake()


var _hold_for: Callable = Callable()


var _catch_dead_zone:= END_DEAD_ZONE


var _hold_back:= END_DEAD_ZONE


var _head_reserve:= 0.0


var _shut_mouth:= 0.0


var lay_deck:= true


var gathers_straw:= false


var open_windows: Array [Dictionary] = []


var _shared: Array [BeltPath] = []


var _foreign:= PackedFloat64Array()


var draw_curve: PackedVector3Array = PackedVector3Array()


var _swept_deck: ArrayMesh = null
var _swept_held: ArrayMesh = null


func build_path(points: PackedVector3Array, overlap: float = 0.0) -> void:
	clear_path()
	if points.size() < 2:
		return


	_line = points.duplicate()
	_cum = PackedFloat32Array()
	_cum.resize(_line.size())
	_cum [0] = 0.0
	for i in range(1, _line.size()):
		_cum [i] = _cum [i - 1] + _line [i - 1].distance_to(_line [i])
	_seg_basis.clear()
	for i in range(_line.size() - 1):
		_seg_basis.append(run_basis(_line [i], _line [i + 1]))
	_geom_epoch += 1
	_half_len = path_length() * 0.5
	_mid = _point_at(_half_len)


	run.set_line(_line)
	run.speed = drive_speed * record_boost
	run.hold_back = _hold_back
	BeltRunBatch.watch(run)

	_path_root = Node3D.new()
	_path_root.name = "Path"


	_path_root.top_level = true
	add_child(_path_root)


	var xforms: Array [Transform3D] = []


	var rail_l: Array [Transform3D] = []
	var rail_r: Array [Transform3D] = []


	var swept:= draw_curve.size() > 2

	var spans:= points.size() - 1
	for i in spans:
		var dir:= points [i + 1] - points [i]
		if dir.length_squared() < 1e-08:
			continue
		dir = dir.normalized()
		var p0: Vector3 = points [i] - dir * overlap
		var p1: Vector3 = points [i + 1] + dir * overlap
		var span_len:= p0.distance_to(p1)
		var basis:= run_basis(p0, p1)


		if not swept:
			var n:= maxi(1, int(round(span_len / Cfg.BELT_SEGMENT)))
			var scale:= Vector3(1.0, 1.0, span_len / float(n) / Cfg.BELT_SEGMENT)
			for k in n:
				xforms.append(Transform3D(basis.scaled_local(scale),
					p0.lerp(p1, (k + 0.5) / float(n))))


		var s_lo: float = _cum [i] - overlap
		if not swept:
			_tile_rail(rail_l, -1, basis, p0, dir, s_lo, span_len)
			_tile_rail(rail_r, 1, basis, p0, dir, s_lo, span_len)

		_add_span(basis, (p0 + p1) * 0.5, span_len,
			_cum [i] + ((p0 + p1) * 0.5 - points [i]).dot(dir))

	if swept:
		_lay_sweep()
	else:
		_path_root.add_child(_mm_instance("Sections", ConveyorKit.segment_mesh(),
			xforms))
		_path_root.add_child(_mm_instance("RailL", ConveyorKit.rail_mesh(-1),
			rail_l))
		_path_root.add_child(_mm_instance("RailR", ConveyorKit.rail_mesh(1),
			rail_r))


	for n: String in ["Sections", "RailL", "RailR"]:
		BeltBatch.adopt(_path_root.get_node(n) as GeometryInstance3D)


	_apply_deck_state()


	wake()


func _lay_sweep() -> void:
	var origin:= draw_curve [0]
	var local:= PackedVector3Array()
	for p in draw_curve:
		local.append(p - origin)
	var fr:= BeltSweep.frames(local)
	_swept_deck = BeltSweep.deck_mesh(fr)
	_swept_held = BeltSweep.held_copy(_swept_deck)

	var deck:= MeshInstance3D.new()
	deck.name = "Sections"
	deck.mesh = _swept_deck
	_path_root.add_child(deck)
	deck.position = origin


	var k:= BeltSweep.length_of(fr) / maxf(path_length(), 0.001)
	for side: int in [-1, 1]:
		var stretches: Array [Vector2] = []
		for seg in _closed_runs(side, 0.0, path_length()):
			if seg.y - seg.x >= RAIL_MIN_PIECE:
				stretches.append(Vector2(seg.x * k, seg.y * k))
		var rail:= MeshInstance3D.new()
		rail.name = "RailR" if side > 0 else "RailL"
		rail.mesh = BeltSweep.rail_mesh(fr, side, stretches)
		_path_root.add_child(rail)
		rail.position = origin


func _tile_rail(into: Array [Transform3D], side: int, basis: Basis, p0: Vector3,
		dir: Vector3, s_lo: float, span_len: float) -> void:
	tile_rail(into, open_windows, side, basis, p0, dir, s_lo, span_len)


static func tile_rail(into: Array [Transform3D], windows: Array [Dictionary], side: int,
		basis: Basis, p0: Vector3, dir: Vector3, s_lo: float, span_len: float) -> void:
	for seg in closed_runs(windows, side, s_lo, s_lo + span_len):
		var seg_len:= seg.y - seg.x
		if seg_len < RAIL_MIN_PIECE:
			continue
		var n:= maxi(1, int(round(seg_len / Cfg.BELT_SEGMENT)))
		var scale:= Vector3(1.0, 1.0, seg_len / float(n) / Cfg.BELT_SEGMENT)
		for k in n:
			var s: float = seg.x + seg_len * (k + 0.5) / float(n)
			into.append(Transform3D(basis.scaled_local(scale),
				p0 + dir * (s - s_lo)))


func set_belt_drawn(on: bool) -> void:
	if _path_root == null:
		return
	for n: String in ["Sections", "RailL", "RailR"]:


		var drawn:= _path_root.get_node_or_null(n) as GeometryInstance3D
		if drawn != null:
			drawn.visible = on


func _mm_instance(mm_name: String, mesh: Mesh,
		xforms: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm

	BeltBatch.keep_local(mmi, xforms)
	return mmi


func _closed_runs(side: int, lo: float, hi: float) -> Array [Vector2]:
	return closed_runs(open_windows, side, lo, hi)


static func closed_runs(windows: Array [Dictionary], side: int, lo: float,
		hi: float) -> Array [Vector2]:
	var cuts: Array [Vector2] = []
	for w in windows:
		if int(w ["side"]) != side:
			continue
		var a:= maxf(lo, float(w ["from"]))
		var b:= minf(hi, float(w ["to"]))
		if b > a:
			cuts.append(Vector2(a, b))
	var out: Array [Vector2] = []
	if cuts.is_empty():
		out.append(Vector2(lo, hi))
		return out
	cuts.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	var at:= lo
	for c in cuts:


		if c.x > at:
			out.append(Vector2(at, c.x))
		at = maxf(at, c.y)
	if hi > at:
		out.append(Vector2(at, hi))
	return out


func _init() -> void:


	run.handed_in.connect(_on_run_handed_in)
	run.handed_out.connect(_on_run_handed_out)


	run.boarded.connect(wake)


func _ready() -> void:


	set_physics_process(true)
	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_follow_tech)
	_follow_tech()


func _on_run_handed_in(seq: int, kind: int, strands: int) -> void:
	caught_record.emit(seq, kind, strands)


func _on_run_handed_out(seq: int, kind: int, strands: int) -> void:
	handed_on_record.emit(seq, kind, strands)


func _on_tech_changed(_id: String, _rank: int) -> void:
	_follow_tech()


func _follow_tech() -> void:
	set_drive_speed(Tech.stand_belt_speed() if stand_belt else Tech.belt_speed())


	if not stand_belt:
		ConveyorKit.set_belt_speed(Tech.belt_speed())


func set_drive_speed(v: float) -> void:
	if is_equal_approx(v, drive_speed):
		return
	drive_speed = v
	run.set_speed(v * record_boost)
	_apply_surface_velocity()


	wake()


func _apply_surface_velocity() -> void:
	var v:= 0.0 if _deck_shows_held else drive_speed
	for span in _spans:
		var body: StaticBody3D = span ["body"]
		if is_instance_valid(body):
			body.constant_linear_velocity = (span ["forward"] as Vector3) * v


func set_catching(on: bool) -> void:
	var opened:= on and (not _catching or not idle_fixes)
	_catching = on
	run.set_catching(on)


	if opened:
		wake()


func share_deck(others: Array [BeltPath]) -> void:
	_shared = []
	for p in others:
		if p != null and p != self:
			_shared.append(p)


	run.mouth_gate = _mouth_limit_of_siblings if not _shared.is_empty() else Callable()
	run.wye = not _shared.is_empty()


func _mouth_limit_of_siblings(reach: float, from: BeltRun) -> float:
	if _shared.is_empty() or _line.size() < 2:
		return INF
	var sender: BeltPath = null
	if from != null:
		for p in _shared:
			if is_instance_valid(p) and p.run == from:
				sender = p
				break
	var at:= _point_at(0.0)
	if sender != null:
		return - INF if _shared_occupied(at, Cfg.STRAND_THICK, sender) else INF
	var out:= INF
	for p in _shared:
		if is_instance_valid(p):
			out = minf(out, p.clearance_at(at, reach))
	return out


func shares_deck() -> bool:
	return not _shared.is_empty()


func _boards_at(at: Dictionary) -> Vector3:
	var s:= clampf(float(at ["s"]), 0.0, path_length())
	return _point_at(s) + _basis_at(s).x * float(at.get("side", 0.0))


func _shared_occupied(at: Vector3, reach: float = Cfg.STRAND_THICK,
		skip: BeltPath = null) -> bool:
	for p in _shared:
		if not is_instance_valid(p) or p == skip:
			continue
		if p.occupies_point(at, reach):
			return true
	return false


func set_foreign_loads(triples: PackedFloat64Array) -> void:
	if triples == _foreign:
		return
	_foreign = triples


	wake()


func lane_loads_before(until: float) -> PackedFloat64Array:
	var out:= PackedFloat64Array()
	for r in _riders:
		if r.s - r.reach < until and is_instance_valid(r.body):
			out.append(r.s)
			out.append(r.reach)
			out.append(r.side)
	var f:= run.first()
	for i in range(f, f + run.count()):
		var s:= run.s_of(i)
		var reach:= run.reach_of(i)
		if s - reach < until:
			out.append(s)
			out.append(reach)
			out.append(run.side_of(i))
	return out


func clearance_at(at: Vector3, reach: float) -> float:
	var out:= INF
	if run.count() > 0 and _line.size() >= 2:
		var s:= float(_nearest(at) ["s"])
		var rows:= run.rows_in(s - RECORD_WINDOW, s + RECORD_WINDOW)
		for i in range(rows.x, rows.y):
			var need:= maxf(run.reach_of(i) + reach, Cfg.STRAND_THICK * 4.0)
			out = minf(out, run.pose_of(i).origin.distance_to(at) - need)
	for r in _riders:
		var b = r.body
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		var need:= maxf(r.reach + reach, Cfg.STRAND_THICK * 4.0)
		out = minf(out, b.global_position.distance_to(at) - need)
	return out


func occupies_point(at: Vector3, reach: float) -> bool:
	if _records_at_point(at, reach):
		return true
	for r in _riders:
		var b = r.body
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		var need:= maxf(r.reach + reach, Cfg.STRAND_THICK * 4.0)
		if b.global_position.distance_to(at) < need:
			return true
	return false


func set_deck_held(on: bool) -> void:
	if _deck_held_by_machine == on:
		return
	_deck_held_by_machine = on
	_refresh_deck()


func deck_shows_held() -> bool:
	return _deck_shows_held


static func all_stopped(paths: Array) -> bool:
	var any_held:= false
	for p in paths:
		var h:= stopped_state(p)
		if h < 0:
			return false
		if h > 0:
			any_held = true
	return any_held


static func stopped_state(p: Variant) -> int:
	if not is_instance_valid(p):
		return 0
	var path:= p as BeltPath
	if path == null:
		return 0
	if path.deck_shows_held():
		return 1
	if not path._riders.is_empty() or path.run.count() > 0:
		return -1
	return 0


func _update_deck(delta: float) -> void:


	if drive_speed <= 0.0:
		return


	var moving:= not _blocked if _riders.is_empty() and run.count() == 0 else _deck_moved >= drive_speed * delta * DECK_MOVING_FRACTION
	if moving:
		_stall_time = maxf(0.0, _stall_time - delta * DECK_STALL_RELEASE)
	else:
		_stall_time = minf(DECK_STALL_SHOW * 2.0, _stall_time + delta)
	if _deck_stalled:
		if _stall_time <= DECK_STALL_CLEAR:
			_deck_stalled = false
			_refresh_deck()
	elif _stall_time >= DECK_STALL_SHOW:
		_deck_stalled = true
		_refresh_deck()


func _refresh_deck() -> void:
	var want:= _deck_held_by_machine or _deck_stalled
	if want == _deck_shows_held:
		return
	_deck_shows_held = want
	_apply_deck_state()


func _apply_deck_state() -> void:
	_apply_surface_velocity()
	if _path_root == null:
		return
	var sections:= _path_root.get_node_or_null("Sections") as GeometryInstance3D
	if sections == null:
		return


	var mmi:= sections as MultiMeshInstance3D
	if mmi != null:
		if mmi.multimesh == null:
			return
		mmi.multimesh.mesh = (ConveyorKit.held_segment_mesh() if _deck_shows_held
			else ConveyorKit.segment_mesh())
	else:
		var mi:= sections as MeshInstance3D
		if mi == null or _swept_deck == null:
			return
		mi.mesh = _swept_held if _deck_shows_held else _swept_deck


	BeltBatch.changed(sections)


func set_blocked(on: bool) -> void:
	_blocked = on
	if not on:
		_shut_out.clear()
	run.set_blocked(on)

	if _asleep:
		_show_shut_while_asleep()

	for feeder in _end_feeders:
		if is_instance_valid(feeder):
			feeder._sync_end_shut()


func is_blocked() -> bool:
	return _blocked


func set_outlet_held(on: bool) -> void:
	_outlet_held = on
	_sync_run_links()


func set_hold_filter(f: Callable) -> void:
	_hold_for = f


func holds(b: Object) -> bool:
	return not _hold_for.is_valid() or b == null or bool(_hold_for.call(b))


func set_catch_dead_zone(metres: float) -> void:
	_catch_dead_zone = maxf(metres, END_DEAD_ZONE)


func set_hold_back(metres: float) -> void:
	_hold_back = maxf(metres, END_DEAD_ZONE)
	run.hold_back = _hold_back


func reserve_head(at: Vector3, radius: float) -> void:
	if _line.size() < 2 or radius <= 0.0:
		_head_reserve = 0.0
		return
	_head_reserve = maxf(0.0, float(_nearest(at) ["s"]) + radius)


func clear_head_reserve() -> void:
	_head_reserve = 0.0


func head_reserve() -> float:
	return _head_reserve


func shut_mouth(at: Vector3) -> void:
	if _line.size() < 2:
		_shut_mouth = 0.0
		return
	_shut_mouth = maxf(0.0, float(_nearest(at) ["s"]))


func _in_shut_mouth(s: float, reach: float, rb: RigidBody3D) -> bool:
	if not _blocked or _shut_mouth <= 0.0 or not holds(rb):
		return false
	if rb.collision_layer & Cfg.L_PROP:
		reach = maxf(reach, extent_along(rb, _basis_at(s).z)) + MOUTH_CLEAR
	return s - reach < _shut_mouth


const MOUTH_CLEAR:= 0.06


static func extent_along(rb: RigidBody3D, dir: Vector3) -> float:
	var basis:= rb.global_basis.orthonormalized()
	var out:= 0.0
	for node in rb.get_children():
		var cs:= node as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var half:= _shape_half(cs.shape)
		var centre:= (basis * cs.position).dot(dir)
		var extent:= absf(basis.x.dot(dir)) * half.x + absf(basis.y.dot(dir)) * half.y + absf(basis.z.dot(dir)) * half.z
		out = maxf(out, absf(centre) + extent)
	return out


var _hold_line:= -1.0


const HOLD_SLACK:= 0.015


func open_mouth() -> void:
	_shut_mouth = 0.0


func hold_before(s: float) -> void:
	var was:= _hold_line
	_hold_line = s

	if s != was:
		run.hold_before(s)


	if s < 0.0 and was >= 0.0:
		wake()


func hold_line() -> float:
	return _hold_line


func s_near(point: Vector3) -> float:
	if _line.size() < 2:
		return 0.0
	return float(_nearest(point) ["s"])


func rider_marks() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for r in _riders:
		var b = r.body
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		out.append({ "body": b, "s": r.s, "reach": r.reach, "prop": r.prop })
	return out


func load_marks(with_pos: bool = true) -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for r in _riders:
		var b = r.body
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		var m:= { "body": b, "s": r.s, "reach": r.reach, "prop": r.prop,
			"seq": -1, "id": (b as Object).get_instance_id() }
		if with_pos:
			m ["pos"] = (b as Node3D).global_position
		out.append(m)
	var f:= run.first()
	for i in range(f, f + run.count()):
		var seq:= run.seq_of(i)
		var m:= { "body": null, "s": run.s_of(i), "reach": run.reach_of(i), "prop": true,
			"seq": seq, "id": - (seq + 1), "row": i }
		if with_pos:
			m ["pos"] = run.pose_of(i).origin
		out.append(m)
	return out


func mark_pos(m: Dictionary) -> Vector3:
	if m.has("pos"):
		return m ["pos"]
	var b = m ["body"]
	if b != null:
		return (b as Node3D).global_position if is_instance_valid(b) else Vector3.ZERO
	return run.pose_of(int(m ["row"])).origin


func pass_record_to(seq: int, other: BeltPath) -> bool:
	if other == null or other == self or not other.records_props:
		return false
	var f:= run.first()
	for i in range(f, f + run.count()):
		if run.seq_of(i) != seq:
			continue
		var rec:= run.remove_at(i)
		var s:= float(rec ["s"])
		if not other.run.board_record(rec, s, float(rec ["speed"]), false):


			var was:= run.catching
			run.catching = true
			run.board_record(rec, s, float(rec ["speed"]), false)
			run.catching = was
			return false
		_put_load(get_instance_id(), _ride_load())
		other.wake()
		_put_load(other.get_instance_id(), other._ride_load())
		return true
	return false


func pass_rider_to(body: RigidBody3D, other: BeltPath) -> bool:
	if other == null or other == self or not is_instance_valid(body):
		return false
	for k in _riders.size():
		var r: Rider = _riders [k]
		if r.body != body:
			continue
		_riders.remove_at(k)
		_put_load(get_instance_id(), _ride_load())


		r.board = other._ride_clock - (_ride_clock - r.board)
		r.hold_due = other._ride_clock + (r.hold_due - _ride_clock)
		r.seq = other._next_seq()
		r.placed_epoch = -1
		body.set_meta(LiveStrandManager.META_RIDER, other)
		other.wake()
		other._riders.append(r)
		_queued_still = false
		other._queued_still = false
		_put_load(other.get_instance_id(), other._ride_load())
		return true
	return false


func _next_seq() -> int:
	_seq += 1
	return _seq


func rider_near_end(reach: float = 0.0) -> RigidBody3D:
	var total:= path_length()
	var best: RigidBody3D = null
	var best_s:= - INF
	for r in _riders:
		var s:= r.s
		var mark:= _park_at(total, r.reach) - 0.001 - maxf(reach, 0.0)
		if s < mark or s <= best_s:
			continue
		var b = r.body
		if is_instance_valid(b) and b.is_inside_tree():
			best_s = s
			best = b
	return best


func _refused_for_good(body: Variant) -> bool:
	return downstream != null and downstream.sealed_against(body as RigidBody3D)


func sealed_against(rb: RigidBody3D) -> bool:
	return record_only and _record_kind(rb) < 0 and not rides_sealed(rb) and not _plain_straw(rb)


static func _plain_straw(rb: RigidBody3D) -> bool:
	if rb == null:
		return false
	var live:= rb.get_parent() as LiveStrandManager
	return live != null and not rb.has_meta("needle_index") and not live.is_held_by_a_tool(rb)


func waiting_rider() -> RigidBody3D:
	return rider_near_end(0.0)


func front_kind() -> int:
	var best_s:= - INF
	var kind:= -1
	var f:= run.first()
	for i in range(f, f + run.count()):
		var s:= run.s_of(i)
		if s > best_s:
			best_s = s
			kind = run.kind_of(i)
	for r in _riders:
		if r.s <= best_s:
			continue
		var b = r.body
		if is_instance_valid(b) and b.is_inside_tree():
			best_s = r.s
			kind = filter_kind(b as RigidBody3D)
	return kind


func has_rider_waiting() -> bool:
	return waiting_rider() != null


func load_near_end(reach: float = 0.0) -> bool:
	return run.front_near_end(reach) or rider_near_end(reach) != null


func has_load_waiting() -> bool:
	return load_near_end(0.0)


func waiting_gap() -> float:
	if run.has_head():
		return run.gap_of(run.first())
	var total:= path_length()
	for r in _riders:


		if r.s >= _park_at(total, r.reach) - 0.001:
			return r.gap
	return Cfg.BELT_RIDE_SPACING


func carries(body: RigidBody3D) -> bool:
	return is_instance_valid(body) and _owns(body)


static func load_shape(rb: RigidBody3D, up: Vector3 = Vector3.UP) -> Dictionary:
	var reach:= 0.0
	var low:= INF
	var low_rest:= INF


	var basis:= rb.global_basis.orthonormalized()
	for node in rb.get_children():
		var cs:= node as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var half:= _shape_half(cs.shape)
		var at:= cs.position
		reach = maxf(reach, maxf(absf(at.x) + half.x, absf(at.z) + half.z))
		var centre_y:= (basis * at).dot(up)
		var extent_y:= absf(basis.x.dot(up)) * half.x + absf(basis.y.dot(up)) * half.y + absf(basis.z.dot(up)) * half.z
		low = minf(low, centre_y - extent_y)


		low_rest = minf(low_rest, at.y - half.y)
	if reach <= 0.0:
		reach = Cfg.STRAND_THICK


	return {
		"reach": reach,
		"lift": maxf(- low if low < INF else 0.0, 0.0),
		"rest": maxf(- low_rest if low_rest < INF else 0.0, 0.0),
	}


static func _shape_half(shape: Shape3D) -> Vector3:
	var box:= shape as BoxShape3D
	if box != null:
		return box.size * 0.5
	var ball:= shape as SphereShape3D
	if ball != null:
		return Vector3.ONE * ball.radius
	var cyl:= shape as CylinderShape3D
	if cyl != null:
		return Vector3(cyl.radius, cyl.height * 0.5, cyl.radius)
	var cap:= shape as CapsuleShape3D
	if cap != null:
		return Vector3(cap.radius, cap.height * 0.5, cap.radius)
	var hull:= shape as ConvexPolygonShape3D
	if hull != null:
		var out:= Vector3.ZERO
		for v: Vector3 in hull.points:
			out = out.max(v.abs())
		return out
	return Vector3.ONE * Cfg.STRAND_THICK * 0.5


static func _ride_half_width(reach: float) -> float:
	if reach <= Cfg.STRAND_THICK * 2.0:
		return Cfg.BELT_RIDE_HALF_W
	return maxf(0.0, Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T - reach)


func accepts_handover(reach: float = Cfg.BELT_RIDE_SPACING, side: float = NAN,
		width: float = Cfg.STRAND_THICK, from: BeltPath = null,
		load: Object = null) -> bool:
	if (_blocked and holds(load)) or not _catching:
		return false
	if record_only and (load == null or sealed_against(load as RigidBody3D)):
		return false


	if record_only and _plain_straw(load as RigidBody3D):
		return _straw_room(0.0)


	if records_props and load != null:
		var kind:= _record_kind(load as RigidBody3D)
		if kind >= 0 and not run.accepts(0.0, width, reach, kind):
			return false


	if not _shared.is_empty() and _line.size() >= 2:
		var outsider:= from == null or not _shared.has(from)
		if _shared_occupied(_point_at(0.0),
				width if outsider else Cfg.STRAND_THICK, from):
			return false
	var need:= maxf(reach, Cfg.BELT_RIDE_SPACING)


	if is_nan(side) or not _shared.is_empty():
		return _clear_within(0.0, need)
	return _lane_clear_within(0.0, need, side, width)


func receive_handover(r: Rider, from: BeltPath) -> bool:
	if not _catching or not is_inside_tree() or _line.size() < 2:
		return false
	var b = r.body
	if not is_instance_valid(b) or not (b as Node).is_inside_tree():
		return false
	var rb:= b as RigidBody3D
	if sealed_against(rb):
		return false
	if record_only and _plain_straw(rb):
		return _take_straw(rb, 0.0)


	var at:= _nearest(rb.global_position)
	var s:= clampf(float(at ["s"]), 0.0, path_length())
	var side:= float(at ["side"])
	var prop:= r.prop
	var shape:= (load_shape(rb, _basis_at(s).y) if prop
		else { "reach": Cfg.STRAND_THICK, "lift": 0.0, "rest": 0.0 })
	var reach: float = shape ["reach"]


	var slide:= side
	if prop and single_file(rb):
		side = 0.0


	if _occupied(s, side, reach):
		return false
	if not _shared.is_empty() and (_shared_occupied(rb.global_position, reach, from) or _shared_occupied(_boards_at({ "s": s, "side": side }), reach, from)):
		return false


	if prop and records_props and _record_kind(rb) >= 0:
		return _board_record(rb, { "s": s, "side": side, "lift": at ["lift"] }, shape, r.speed)
	_take(rb, { "s": s, "side": side, "slide": slide, "lift": at ["lift"] }, shape,
		prop, true, r.speed)
	return true


func _clear_within(s: float, reach: float) -> bool:
	if not _records_clear(s, reach):
		return false
	for r in _riders:
		if absf(r.s - s) < maxf(reach, r.gap):
			return false
	return true


func _lane_handed(handed: Array [Vector2], side: float, width: float,
		lane_wise: bool) -> bool:


	if not lane_wise:
		return not handed.is_empty()
	for h in handed:
		if absf(h.x - side) <= maxf(h.y + width, Cfg.STRAND_THICK * 6.0):
			return true
	return false


func _lane_clear_within(s: float, reach: float, side: float, width: float) -> bool:
	if not _records_lane_clear(s, reach, side, width):
		return false
	for r in _riders:


		if absf(r.s - s) >= maxf(reach, r.gap):
			continue
		if absf(r.side - side) <= maxf(r.reach + width, Cfg.STRAND_THICK * 6.0):
			return false
	return true


func _occupied(s: float, side: float, reach: float = Cfg.STRAND_THICK) -> bool:
	if _records_occupied(s, side, reach):
		return true
	for r in _riders:


		var mine: float = r.reach
		if absf(r.s - s) > maxf(mine + reach, Cfg.STRAND_THICK * 2.0):
			continue
		if absf(r.side - side) <= maxf(mine + reach, Cfg.STRAND_THICK * 6.0):
			return true
	return false


func _behind_riders(s: float, side: float, reach: float) -> float:
	var out:= _records_behind(s, side, reach)
	for r in _riders:
		var mine: float = r.reach
		var need:= maxf(mine + reach, Cfg.STRAND_THICK * 2.0)
		if absf(r.s - s) > need:
			continue
		if absf(r.side - side) > maxf(mine + reach, Cfg.STRAND_THICK * 6.0):
			continue
		out = minf(out, r.s - need - 0.005)
	return out if out >= 0.0 else -1.0


func _lane_has_room(s: float, side: float) -> bool:


	var needed:= _records_gaps_below(s, side)
	for r in _riders:
		if r.s > s:
			continue
		if absf(r.side - side) <= Cfg.STRAND_THICK * 6.0:
			needed += r.gap


	if needed <= 0.0:
		return true


	return needed + Cfg.STRAND_THICK * 2.0 <= s


func has_room_near(point: Vector3, lead: float = 0.0) -> bool:
	if _line.size() < 2:
		return false
	var at:= _nearest(point)
	var s:= float(at ["s"])


	if not _clear_within(s, Cfg.BELT_RIDE_SPACING):
		return false
	if lead <= 0.0:
		return true


	if not _records_clear_behind(s, lead):
		return false
	for r in _riders:
		var rs:= r.s
		if rs < s and s - rs < lead + maxf(Cfg.BELT_RIDE_SPACING, r.gap):
			return false
	return true


func straw_room_at(point: Vector3) -> int:
	if _line.size() < 2:
		return 0
	var s:= float(_nearest(point) ["s"])
	var lo:= maxf(s - PERCH_TAIL, 0.0)
	var hi:= minf(s + ROOM_AHEAD, path_length() - _catch_dead_zone)
	var room:= 0
	var covered:= _records_covered(lo, hi)
	for r in _riders:
		if r.s + r.reach < lo or r.s - r.reach > hi:
			continue
		covered += minf(r.s + r.reach, hi) - maxf(r.s - r.reach, lo)
		var t = r.body
		if r.prop and is_instance_valid(t) and t is HayTuft:
			room += maxi(0, Cfg.TUFT_MAX - (t as HayTuft).strands)
	if (Cfg.belt_decay and belt_load() >= Cfg.belt_cap) or not _lane_has_room(s, 0.0):
		return room
	var widest:= HayTuft.full_collider_size()
	var clear:= hi - lo - covered
	if clear > 0.0:
		room += int(floor(clear / maxf(widest.x, widest.z))) * Cfg.TUFT_MAX
	return room


const ROOM_AHEAD:= 0.5


func landing_point(release: Vector3, speed: float) -> Vector3:
	if _line.size() < 2:
		return release
	var at:= _nearest(release)
	var height:= maxf(float(at ["lift"]), 0.0)
	var flight:= speed * sqrt(2.0 * height / 9.8)
	var s:= clampf(float(at ["s"]) + flight, 0.0, path_length())


	var basis:= _basis_at(s)
	return _point_at(s) + basis.x * float(at ["side"]) + basis.y * float(at ["lift"])


func _land_low(lead: float, reach: float) -> float:
	return maxf(lead, _head_reserve + reach)


func _land_high(reach: float) -> float:
	return path_length() - _catch_dead_zone - reach


func fits_load(lead: float, reach: float) -> bool:
	if _line.size() < 2:
		return false
	return _land_high(reach) + 0.001 >= _land_low(lead, reach) - 0.001


func usable_release(release: Vector3, speed: float, lead: float,
		reach: float) -> Vector3:
	if _line.size() < 2:
		return release
	var at:= _nearest(release)
	var height:= maxf(float(at ["lift"]), 0.0)
	var flight:= speed * sqrt(2.0 * height / 9.8)


	var lo:= _land_low(lead, reach) + 0.01
	var hi:= _land_high(reach) - 0.01
	if hi < lo:
		return release
	var s_land:= float(at ["s"]) + flight
	var shift:= clampf(s_land, lo, hi) - s_land
	if is_zero_approx(shift):
		return release
	var s:= clampf(float(at ["s"]) + shift, 0.0, path_length())
	var basis:= _basis_at(s)
	return _point_at(s) + basis.x * float(at ["side"]) + basis.y * float(at ["lift"])


func has_room_to_land(release: Vector3, speed: float, lead: float,
		reach: float, ahead: float = 0.0) -> bool:
	if _line.size() < 2:
		return false
	var at:= _nearest(release)
	var height:= maxf(float(at ["lift"]), 0.0)
	var s:= float(at ["s"]) + speed * sqrt(2.0 * height / 9.8)


	if s < _land_low(lead, reach) - 0.001 or s > _land_high(reach) + 0.001:
		return false
	s = _arriving_from(s, speed * ahead)
	return has_room_near(_point_at(s) + _basis_at(s).x * float(at ["side"]), lead)


func has_room_to_board(at: Vector3, kind: int, strands: int, clear: float,
		speed: float, ahead: float = 0.0) -> bool:
	if not records_props or _line.size() < 2:
		return false
	var shape:= shape_of_kind(kind, strands)
	if shape.is_empty():
		return false
	var reach:= float(shape ["reach"])
	var s:= float(_nearest(at) ["s"])
	if s < _land_low(0.0, clear) - 0.001 or s > _land_high(clear) + 0.001:
		return false
	s = _arriving_from(s, speed * ahead)
	return _clear_within(s, maxf(reach, clear)) and run.fits(reach, s)


const POUR_LOOK:= 1.0
const POUR_DROP:= 2.5


const POUR_MARGIN:= 0.08


enum Pour { NO_BELT, ROOM, NO_ROOM }


static func pour_verdict(release: Vector3, velocity: Vector3, reach: float) -> int:
	var g:= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var best: BeltPath = null
	var best_h:= INF
	var best_at:= { }
	var best_t:= 0.0
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		if p._line.size() < 2:
			continue
		var span:= p._half_len + POUR_LOOK + Cfg.BELT_WIDTH
		if p._mid.distance_squared_to(release) > span * span:
			continue
		var h:= float(p._nearest(release) ["lift"])
		if h < -0.05 or h > POUR_DROP or h >= best_h:
			continue


		var up:= velocity.y
		var t:= (up + sqrt(up * up + 2.0 * g * maxf(h, 0.0))) / g
		var land:= release + Vector3(velocity.x, 0.0, velocity.z) * t
		var at:= p._nearest(land)
		var s:= float(at ["s"])
		var basis:= p._basis_at(s)


		var on:= p._point_at(s) + basis.x * float(at ["side"])
		if Vector2(on.x - land.x, on.z - land.z).length() > 0.05:
			continue
		if absf(float(at ["side"])) > Cfg.BELT_WIDTH * 0.5:
			continue
		best = p
		best_h = h
		best_at = at
		best_t = t
	if best == null:
		return Pour.NO_BELT
	var s:= float(best_at ["s"])
	if s >= best.path_length() - best._catch_dead_zone:
		return Pour.NO_BELT
	if best._blocked and best._shut_mouth > 0.0 and s - reach - MOUTH_CLEAR < best._shut_mouth:
		return Pour.NO_ROOM


	var band:= _ride_half_width(reach)
	var side:= clampf(float(best_at ["side"]), - band, band)
	var from:= best._arriving_from(s, best.drive_speed * best_t)


	var need:= reach + POUR_MARGIN
	if best._occupied(s, side, need) or best._occupied(from, side, need) or not best._lane_has_room(from, side):
		return Pour.NO_ROOM
	return Pour.ROOM


func is_flowing() -> bool:
	return drive_speed > 0.0 and not _asleep and not _deck_stalled


func _arriving_from(s: float, metres: float) -> float:
	if metres <= 0.0 or s - metres < 0.0 or not is_flowing():
		return s
	return s - metres


func clear_path() -> void:


	for k in range(_riders.size() - 1, -1, -1):
		var r: Rider = _riders [k]
		_riders.remove_at(k)
		_drop(r, Vector3.ZERO)


	_spill_records()
	BeltRunBatch.unwatch(run)
	_spans.clear()
	_line = PackedVector3Array()
	_cum = PackedFloat32Array()
	_seg_basis.clear()


	downstream = null
	if _path_root == null:
		return


	var old:= _path_root
	_path_root = null
	remove_child(old)
	old.queue_free()


func _add_span(basis: Basis, centre: Vector3, length: float,
		s_centre: float) -> void:
	var t:= Cfg.BELT_RAIL_T


	var body: StaticBody3D = null
	if not lay_deck:
		var span_area:= _drive_volume(basis, centre, length, t)
		_spans.append({ "forward": basis.z, "area": span_area, "body": null })
		return

	body = StaticBody3D.new()
	body.name = "Deck"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0


	body.constant_linear_velocity = basis.z * drive_speed
	_path_root.add_child(body)
	body.global_transform = Transform3D(basis, centre)


	_shape(body, Vector3(Cfg.BELT_WIDTH, Cfg.BELT_DECK_THICK, length),
		Vector3(0, - Cfg.BELT_DECK_THICK * 0.5, 0))


	for sgn in [-1, 1]:
		for seg in _closed_runs(sgn, s_centre - length * 0.5,
				s_centre + length * 0.5):
			var seg_len:= seg.y - seg.x


			if seg_len < RAIL_MIN_PIECE:
				continue
			_shape(body, Vector3(t, Cfg.BELT_RAIL_H, seg_len),
				Vector3(sgn * (Cfg.BELT_WIDTH - t) * 0.5, Cfg.BELT_RAIL_H * 0.5,
					(seg.x + seg.y) * 0.5 - s_centre))
			if stand_belt:
				_rail_lip(body, sgn, seg_len, (seg.x + seg.y) * 0.5 - s_centre)

	_spans.append({ "forward": basis.z, "area": _drive_volume(basis, centre, length, t),
		"body": body })


const RAIL_LIP_OVERHANG:= 0.025
const RAIL_LIP_SLOPE:= 0.8727
const RAIL_LIP_THICK:= 0.01


func _rail_lip(body: StaticBody3D, sgn: int, seg_len: float, z: float) -> void:
	var inner:= Vector2(sgn * (Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T), Cfg.BELT_RAIL_H)
	var across:= Cfg.BELT_RAIL_T + RAIL_LIP_OVERHANG
	var outer:= inner + Vector2(sgn * across, across * tan(RAIL_LIP_SLOPE))
	var d:= (outer - inner).normalized()
	var up:= Vector2(- d.y, d.x)
	if up.y < 0.0:
		up = - up
	var mid:= (inner + outer) * 0.5 - up * RAIL_LIP_THICK * 0.5
	var box:= BoxShape3D.new()
	box.size = Vector3(inner.distance_to(outer), RAIL_LIP_THICK, seg_len)
	var cs:= CollisionShape3D.new()
	cs.name = "RailLip"
	cs.shape = box
	cs.transform = Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x)), Vector3(mid.x, mid.y, z))
	body.add_child(cs)


func _drive_volume(basis: Basis, centre: Vector3, length: float,
		t: float) -> Area3D:
	var area:= Area3D.new()
	area.name = "Drive"
	area.collision_layer = 0

	area.collision_mask = Cfg.L_STRAND | (Cfg.L_BELT_CATCH if cargo_physics_enabled else Cfg.L_PROP)
	area.monitorable = false
	var box:= BoxShape3D.new()


	box.size = Vector3(Cfg.BELT_WIDTH - t * 2.0, Cfg.BELT_DRIVE_H, length)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, Cfg.BELT_DRIVE_H * 0.5, 0)
	area.add_child(cs)


	area.body_entered.connect(_on_drive_entered)
	_path_root.add_child(area)
	area.global_transform = Transform3D(basis, centre)
	return area


static var _load_by_path: Dictionary = { }

static var _load_total:= 0.0
static var _load_summed_at:= -1000000
const LOAD_RESUM_TICKS:= 60


static func _put_load(id: int, value: float) -> void:
	_load_total += value - float(_load_by_path.get(id, 0.0))
	_load_by_path [id] = value


static func _drop_load(id: int) -> void:
	_load_total -= float(_load_by_path.get(id, 0.0))
	_load_by_path.erase(id)


static var _refused:= 0
static var _max_at_take:= 0


static var pushed_kinds:= 0


static func belt_load() -> int:
	var now:= Engine.get_physics_frames()
	if now - _load_summed_at >= LOAD_RESUM_TICKS or now < _load_summed_at:
		_load_summed_at = now
		var sum:= 0.0
		for k: int in _load_by_path:
			sum += float(_load_by_path [k])
		_load_total = sum
	var n:= _load_total


	return int(floor(n))


static func strand_load() -> float:
	return Cfg.BELT_RIDE_SPACING / Cfg.WAD_CLEAR


func _ride_load() -> float:
	var each:= strand_load()
	var n:= float(run.count())
	for r in _riders:
		n += 1.0 if r.prop else each
	return n


func _exit_tree() -> void:
	_live.erase(self)
	_decks.erase(self)
	_unlist_awake()
	_ticked.erase(self)
	_drop_load(get_instance_id())
	for k in range(_riders.size() - 1, -1, -1):
		var r: Rider = _riders [k]
		_riders.remove_at(k)
		_drop(r, Vector3.ZERO)
	_spill_records()
	BeltRunBatch.unwatch(run)


func _shape(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var box:= BoxShape3D.new()
	box.size = size
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = at
	body.add_child(cs)


func is_busy() -> bool:
	return not _riders.is_empty() or _took_straw or not _perched.is_empty() or not _unplaced.is_empty() or not _overlaps().is_empty()


func tick_path(delta: float) -> void:
	if _spans.is_empty():
		return


	var now:= Engine.get_physics_frames()
	var gap:= now - _seen_tick
	if gap < 1 or gap > FAR_STRIDE_TICKS:
		gap = 1
	_seen_tick = now
	_owed += delta * float(gap)
	var stride:= _tick_stride()
	var phase:= _stagger


	var busy:= is_busy()
	var strided:= false
	if FactoryClock.stride > stride and not busy:

		var full:= false
		if not coarse_far:
			phase = _factory_phase()
			full = _owner != self and FactoryClock.full_rate(_owner)
		if not full:
			stride = FactoryClock.stride
			strided = true
	if stride > 1:
		var off:= (now + phase) % stride
		if off != 0:

			_due = now + stride - off
			return


	var frame:= Engine.get_process_frames()


	var limit:= delta * 1.5
	if strided:
		limit = FactoryClock.gap_limit(null if _owner == self else _owner, delta)
	if frame_tick_enabled and frame == _stepped_frame and _owed < limit:
		return
	_stepped_frame = frame
	var dt:= _owed
	_owed = 0.0


	if stride > 1 and coarse_far:
		_due = now + stride


	var quiet:= quiet_ticks and _riders.is_empty() and not _took_straw and _perched.is_empty() and _unplaced.is_empty() and _overlaps().is_empty()
	if not quiet:
		_carry(dt)


	if run.count() > 0:
		var blockers:= _rider_blockers()
		if not _foreign.is_empty():
			blockers.append_array(_foreign)
		run.set_blockers(blockers)
		run.tick(dt)
		_ticked.append(self)
		var aboard:= float(_riders.size() + run.count())
		_deck_moved = (_deck_moved * float(_riders.size()) + run.moved_sum()) / aboard
	if quiet:

		_perch_left = PERCH_PER_PASS
	else:
		_catch()
		_tuft_perched()
		_fold_unplaced()
	_ride_clock += dt
	if _took_straw:
		_took_straw = false
		_gather_straw()
	if not quiet:
		_settle_loose()
	_wake_clock += dt
	if _wake_clock >= WAKE_EVERY:
		_wake_clock = 0.0
		_wake_sleepers()
	_shed_clock += dt
	if _shed_clock >= SHED_EVERY:
		_shed_clock = 0.0
		_shed_over_cap()
	_update_deck(dt)


	_put_load(get_instance_id(), _ride_load())

	if _riders.is_empty() and run.count() == 0 and not _deck_occupied():
		_sleep()


static var focus:= Vector3.ZERO
static var focus_set:= false


const FAR_STRIDE_2:= 30.0
const FAR_STRIDE_4:= 60.0

var coarse_far:= false

var _owed:= 0.0


var _stagger:= 0


static var frame_tick_enabled: bool = not ("--noframetick" in OS.get_cmdline_user_args())


static var quiet_ticks: bool = not ("--slowtick" in OS.get_cmdline_user_args())

static var cargo_physics_enabled: bool = not ("--legacy-belt-cargo" in OS.get_cmdline_user_args())

var _stepped_frame:= -1


func _factory_phase() -> int:
	if _phase < 0:
		var owner: Node = self
		var n:= get_parent()
		var hops:= 0
		while n != null and hops < 4:
			if n.has_method(&"factory_tick"):
				owner = n
				break
			n = n.get_parent()
			hops += 1
		_phase = FactoryClock.phase_of(owner)
		_owner = owner
	return _phase


var _phase:= -1

var _owner: Node = self


var _seen_tick:= -1
var _due:= 0

const FAR_STRIDE_TICKS:= 4


func _tick_stride() -> int:
	if not coarse_far or not focus_set or _line.size() < 2:
		return 1
	var d:= focus.distance_to(_mid) - _half_len
	if d >= FAR_STRIDE_4:
		return 4
	if d >= FAR_STRIDE_2:
		return 2
	return 1


static var _live: Array [BeltPath] = []


static var _decks: Array [BeltPath] = []


func is_hand_laid() -> bool:
	return false


static func machine_decks() -> Array [BeltPath]:
	return _decks


static func records_aboard() -> int:
	var n:= 0
	for p in _live:
		if is_instance_valid(p) and p.run != null:
			n += p.run.count()
	return n


var _asleep:= false


const SWEEP_FRAMES:= 60


const MIN_SWEEP:= 8

static var _sweep_cursor:= 0


static func sweep() -> void:
	if _live.is_empty():
		return
	var per_frame:= maxi(MIN_SWEEP, _live.size() / SWEEP_FRAMES)
	var checked:= 0
	var stale:= false
	while checked < per_frame and checked < _live.size():
		checked += 1
		_sweep_cursor += 1
		if _sweep_cursor >= _live.size():
			_sweep_cursor = 0


		var p = _live [_sweep_cursor]
		if not is_instance_valid(p) or not p.is_inside_tree():
			stale = true
			continue

		if not p._asleep:
			continue


		if not p._riders.is_empty() or p.run.count() > 0:
			p.wake()
			continue
		p._wake_sleepers()
	if stale:
		var kept: Array [BeltPath] = []
		for item in _live:
			if is_instance_valid(item) and (item as Node).is_inside_tree():
				kept.append(item)
		_live = kept
		_sweep_cursor = 0


func _deck_occupied() -> bool:
	for span in _spans:
		var area: Area3D = span ["area"]
		if is_instance_valid(area) and area.has_overlapping_bodies():
			return true
	return false


static var sleeping_enabled:= true


static var idle_fixes: bool = not ("--oldidle" in OS.get_cmdline_user_args())


static func set_sleeping_enabled(on: bool) -> void:
	sleeping_enabled = on
	if on:
		return
	for item in _live:
		if is_instance_valid(item) and (item as Node).is_inside_tree():
			(item as BeltPath).wake()


func _sleep() -> void:
	if _asleep or not sleeping_enabled:
		return
	_asleep = true
	set_physics_process(false)
	_unlist_awake()


	_drop_load(get_instance_id())


	_show_shut_while_asleep()


func _show_shut_while_asleep() -> void:
	var want:= _blocked and drive_speed > 0.0


	_stall_time = DECK_STALL_SHOW * 2.0 if want else 0.0
	if _deck_stalled != want:
		_deck_stalled = want
		_refresh_deck()


func wake() -> void:
	if not _asleep:
		return
	_asleep = false
	set_physics_process(true)
	_list_awake()


func _on_drive_entered(_body: Node3D) -> void:
	wake()


func _enter_tree() -> void:

	_phase = -1
	if not _live.has(self):
		_live.append(self)
		if not is_hand_laid():
			_decks.append(self)
		_serial = _serial_next
		_serial_next += 1
	if not _asleep:
		_list_awake()
	_stagger = get_instance_id() % 4


static func sleep_census() -> Array [int]:
	var asleep:= 0
	var live:= 0
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		live += 1
		if (item as BeltPath)._asleep:
			asleep += 1
	return [live, asleep]


const WAKE_EVERY:= 1.0
var _wake_clock:= 0.0


func _wake_sleepers() -> void:
	if not is_inside_tree():
		return
	var space:= get_world_3d().direct_space_state
	if space == null:
		return
	for span in _spans:
		var area: Area3D = span ["area"]
		if not is_instance_valid(area) or area.get_child_count() == 0:
			continue
		var cs:= area.get_child(0) as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var q:= PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		q.collision_mask = Cfg.L_BELT_CATCH if cargo_physics_enabled else Cfg.L_PROP
		q.collide_with_areas = false
		for hit in space.intersect_shape(q, 32):
			var rb:= hit.get("collider") as RigidBody3D
			if rb == null or rb.freeze:
				continue


			wake()
			if rb.sleeping:
				rb.sleeping = false


var _span_bodies: Array [Array] = []
var _span_bodies_frame:= -1


func _overlaps() -> Array [Array]:
	var frame:= Engine.get_physics_frames()
	if _span_bodies_frame == frame:
		return _span_bodies
	_span_bodies_frame = frame
	_span_bodies.clear()
	for span in _spans:
		var area: Area3D = span ["area"]
		if is_instance_valid(area) and area.has_overlapping_bodies():
			_span_bodies.append(area.get_overlapping_bodies())
	return _span_bodies


func _settle_loose() -> void:
	for bodies: Array in _overlaps():
		for node in bodies:
			var rb:= node as RigidBody3D
			if rb == null or not rb.is_inside_tree():
				continue


			if not (rb.collision_layer & (Cfg.L_PROP | Cfg.L_STRAND)):
				continue


			if rb.freeze:
				continue


			if idle_fixes and rb.sleeping and _blocked and rb.has_meta(META_SETTLED) and _shut_out.has(rb.get_instance_id()):
				continue
			if rb.collision_layer & Cfg.L_PROP:
				_centre_prop(rb)
			if _should_hold_still(rb) or _waits_in_mouth(rb):


				rb.linear_velocity = Vector3.ZERO
				rb.angular_velocity = Vector3.ZERO
				rb.sleeping = true
				rb.set_meta(META_SETTLED, true)
				continue
			if rb.has_meta(META_SETTLED):
				rb.remove_meta(META_SETTLED)
			if rb.sleeping and _deck_is_running():
				rb.sleeping = false


const PROP_CENTRE_SPEED:= 0.6


const SINGLE_FILE_SLIDE:= 0.8


const PROP_GLIDE_SPEED:= 1.4


const PROP_GLIDE_DROP_MAX:= 0.5


static func single_file(rb: RigidBody3D) -> bool:
	return rb is HayWad or record_kind(rb) >= 0


func _centre_prop(rb: RigidBody3D) -> void:
	if _line.size() < 2:
		return


	if float(rb.get_meta(META_QUEUE_BOUNCE, 0.0)) > Time.get_ticks_msec() * 0.001:
		return
	var reach: float = load_shape(rb) ["reach"]
	var at:= _nearest(rb.global_position)
	var s:= float(at ["s"])
	if s < 0.0 or s > path_length():
		return
	var side:= float(at ["side"])
	var lift:= float(at ["lift"])

	if absf(side) > Cfg.BELT_WIDTH * 0.5 or lift < -0.1 or lift > 0.5:
		return


	var off_band:= absf(side) > _ride_half_width(reach)
	var perched:= lift > Cfg.BELT_RIDE_CATCH_H and absf(side) > 0.03
	if not off_band and not perched:
		return
	var basis:= _basis_at(s)


	var item:= rb as Carryable
	if item != null:
		item.unplant()
	var v:= rb.linear_velocity
	rb.sleeping = false


	rb.linear_velocity = v - basis.x * v.dot(basis.x) + basis.x * (- signf(side)) * PROP_CENTRE_SPEED


func _deck_is_running() -> bool:
	return drive_speed > 0.0 and not _deck_shows_held


func _should_hold_still(rb: RigidBody3D) -> bool:


	if not (rb.collision_layer & Cfg.L_STRAND):
		return false


	if rb.linear_velocity.length_squared() > SETTLE_SPEED * SETTLE_SPEED:
		return false
	var at:= _nearest(rb.global_position)


	if at ["lift"] > Cfg.STRAND_THICK * 3.0 or at ["lift"] < - Cfg.BELT_DECK_THICK:
		return false


	return absf(at ["side"]) <= _ride_half_width(Cfg.STRAND_THICK)


func _waits_in_mouth(rb: RigidBody3D) -> bool:
	if not _blocked or _shut_mouth <= 0.0 or not holds(rb):
		return false


	if float(rb.get_meta(META_QUEUE_BOUNCE, 0.0)) > Time.get_ticks_msec() * 0.001:
		return false
	var at:= _nearest(rb.global_position)
	var reach:= Cfg.STRAND_THICK
	var ride:= 0.0
	if rb.collision_layer & Cfg.L_PROP:
		var shape:= load_shape(rb)
		reach = float(shape ["reach"])
		ride = float(shape ["lift"])
	if not _in_shut_mouth(float(at ["s"]), reach, rb) or float(at ["lift"]) < - Cfg.BELT_DECK_THICK:
		return false
	if float(at ["lift"]) - ride > Cfg.BELT_RIDE_CATCH_H:
		return false
	return absf(rb.linear_velocity.y) <= PROP_SETTLE_SPEED


static var straw_tufts_enabled:= true


const GATHER_FRESH:= 0.5

var _ride_clock:= 0.0


var _took_straw:= false


var _perched:= { }


const PERCH_PER_PASS:= 60
var _perch_left:= 0

const TUFT_REST:= Basis(Vector3(0.0, 0.0, -1.0), Vector3.UP, Vector3(1.0, 0.0, 0.0))


func _gather_straw() -> void:
	if not gathers_straw or not straw_tufts_enabled or _riders.size() < 2:
		return
	var straw: Array [Rider] = []
	var tufts: Array [Rider] = []
	for r in _riders:
		var b = r.body
		if not is_instance_valid(b) or not (b as Node).is_inside_tree():
			continue
		if r.prop:
			if b is HayTuft and (b as HayTuft).strands < Cfg.TUFT_MAX:
				tufts.append(r)
		elif (b as Node).get_parent() is LiveStrandManager and not (b as Object).has_meta("needle_index") and _ride_clock - float(r.board) <= GATHER_FRESH:
			straw.append(r)
	if straw.is_empty() or (tufts.is_empty() and straw.size() < Cfg.TUFT_MERGE_AT):
		return
	var gone:= { }


	for t in tufts:
		var tuft:= t.body as HayTuft
		var room:= Cfg.TUFT_MAX - tuft.strands
		var reach:= t.reach + Cfg.TUFT_ABSORB_REACH
		var into:= 0
		for r in straw:
			if room - into <= 0:
				break
			var b = r.body
			if gone.has(b) or absf(r.s - t.s) > reach or absf(r.side - t.side) > reach:
				continue
			gone [b] = true
			into += 1
		if into > 0:
			tuft.add_strands(into)

			t.reach = load_shape(tuft) ["reach"]


	var left: Array [Rider] = []
	for r in straw:
		if not gone.has(r.body):
			left.append(r)
	var made:= 0
	if left.size() >= Cfg.TUFT_MERGE_AT:
		left.sort_custom(func(x: Rider, y: Rider) -> bool:
			return x.s < y.s)
		var props:= get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager
		var i:= 0
		while props != null and i <= left.size() - Cfg.TUFT_MERGE_AT:
			var j:= i
			while j + 1 < left.size() and j + 1 - i < Cfg.TUFT_MAX and left [j + 1].s - left [i].s <= Cfg.BELT_TUFT_SPAN:
				j += 1
			if j + 1 - i < Cfg.TUFT_MERGE_AT:
				i += 1
				continue
			var run:= left.slice(i, j + 1)
			if _ride_tuft(props, run):
				for r in run:
					gone [r.body] = true
				made += 1
			i = j + 1
	if gone.is_empty():
		return

	var kept: Array [Rider] = []
	for r in _riders:
		if not gone.has(r.body):
			kept.append(r)
	_riders = kept
	_queued_still = false
	for b in gone.keys():
		if not is_instance_valid(b):
			continue
		var rb:= b as RigidBody3D
		if _owns(rb):
			rb.remove_meta(LiveStrandManager.META_RIDER)
		var live:= rb.get_parent() as LiveStrandManager
		if live != null:
			live.consume(rb)
	_put_load(get_instance_id(), _ride_load())


func _into_riding_tuft(rb: RigidBody3D, s: float, side: float) -> bool:
	var live:= rb.get_parent() as LiveStrandManager
	if live == null or rb.has_meta("needle_index") or live.is_held_by_a_tool(rb):
		return false
	for r in _riders:
		var t = r.body
		if not r.prop or not is_instance_valid(t) or t is not HayTuft:
			continue
		var tuft:= t as HayTuft
		var reach:= r.reach + Cfg.TUFT_ABSORB_REACH
		if tuft.strands >= Cfg.TUFT_MAX or absf(r.s - s) > reach or absf(r.side - side) > reach:
			continue
		if not live.consume(rb):
			return false
		tuft.add_strands(1)
		r.reach = load_shape(tuft) ["reach"]
		return true
	return false


func _perch_on_tuft(rb: RigidBody3D, s: float, side: float) -> bool:
	var live:= rb.get_parent() as LiveStrandManager
	if live == null or rb.has_meta("needle_index") or live.is_held_by_a_tool(rb):
		return false

	if _perched.has(rb.get_instance_id()):
		return true

	if _perch_left <= 0:
		return true
	if _into_riding_tuft(rb, s, side):
		_perch_left -= 1
		return true
	for r in _riders:
		var t = r.body
		if not r.prop or not is_instance_valid(t) or t is not HayTuft:
			continue
		var reach:= r.reach + Cfg.TUFT_ABSORB_REACH
		if absf(r.s - s) > reach or absf(r.side - side) > reach:
			continue
		_perched [rb.get_instance_id()] = [rb, r]
		_perch_left -= 1
		return true
	return false


func _tuft_perched() -> void:
	if _perched.is_empty():
		return
	var on_tuft:= { }
	for id: int in _perched:
		var rec: Array = _perched [id]
		var b = rec [0]
		if not is_instance_valid(b) or not (b as Node).is_inside_tree() or (b as RigidBody3D).freeze or (b as Node).get_parent() is not LiveStrandManager:
			continue
		var list: Array = on_tuft.get(rec [1], [])
		list.append(b)
		on_tuft [rec [1]] = list
	_perched.clear()
	var props:= get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager
	if props == null:
		return
	var widest:= HayTuft.full_collider_size()
	var span:= maxf(widest.x, widest.z) * 0.5
	var made:= false


	var running:= _deck_is_running()
	for under: Rider in on_tuft:
		var straw: Array = on_tuft [under]
		if not _riders.has(under):
			continue


		var used:= _into_tuft_within(straw, 0, under, PERCH_SPREAD)
		made = made or used > 0
		if straw.size() - used < Cfg.TUFT_MERGE_AT:


			if straw.size() > used:
				var further:= _into_tuft_within(straw, used, under, PERCH_TAIL)
				made = made or further > 0
				used += further
			_fold_nowhere(straw, used, running)
			continue


		var behind:= _behind_riders(under.s, under.side, span)
		var tries:= 0
		while behind >= 0.0 and tries < PERCH_WALK and _occupied(behind, under.side, span):
			behind = _behind_riders(behind, under.side, span)
			tries += 1
		if behind < 0.0 or under.s - behind > PERCH_TAIL or _occupied(behind, under.side, span) or not _lane_has_room(behind, under.side):


			var far:= _into_tuft_within(straw, used, under, PERCH_TAIL)
			made = made or far > 0
			_fold_nowhere(straw, used + far, running)
			continue
		var n:= mini(straw.size() - used, Cfg.TUFT_MAX)
		var made_tuft:= _ride_tuft_at(props, behind, under.side, n)
		if made_tuft == null:
			_fold_nowhere(straw, used, running)
			continue
		made = true
		var lost:= n - _consume_straw(straw, used, n)
		if lost > 0:
			made_tuft.set_strands(made_tuft.strands - lost)
		_fold_nowhere(straw, used + n, running)
	if made:
		_put_load(get_instance_id(), _ride_load())


const NO_ROOM_FOLD:= 1.0


var _unplaced:= { }

static var folded_straw:= 0


func _fold_unplaced() -> void:


	if not gathers_straw or not straw_tufts_enabled or not _deck_is_running() or not _shared.is_empty():
		if not _unplaced.is_empty():
			_unplaced.clear()
		return
	var seen:= { }
	for bodies: Array in _overlaps():
		for node in bodies:
			var rb:= node as RigidBody3D
			if rb == null or not rb.is_inside_tree() or rb.freeze or not (rb.collision_layer & Cfg.L_STRAND) or rb.has_meta(LiveStrandManager.META_RIDER) or rb.has_meta("needle_index"):
				continue
			var live:= rb.get_parent() as LiveStrandManager
			if live == null or live.is_held_by_a_tool(rb):
				continue
			var id:= rb.get_instance_id()
			if seen.has(id):
				continue
			var since: float = _unplaced.get(id, _ride_clock)
			if _ride_clock - since >= NO_ROOM_FOLD:


				var stand:= get_parent() if stand_belt and stand_keeps_straw else null
				if stand != null and stand.has_method("sell_loose_strand"):
					if stand.call("sell_loose_strand", rb):
						folded_straw += 1
						continue
				elif live.fold_away(rb):
					folded_straw += 1
					continue
			seen [id] = since
	_unplaced = seen


const PERCH_SPREAD:= 1.0


const PERCH_WALK:= 12
const PERCH_TAIL:= 3.0


func _tuft_with_room_near(s: float, side: float, spread:= PERCH_SPREAD) -> Rider:
	var best: Rider = null
	var best_ds:= spread
	for r in _riders:
		var t = r.body
		if not r.prop or not is_instance_valid(t) or t is not HayTuft or (t as HayTuft).strands >= Cfg.TUFT_MAX:
			continue
		var ds:= absf(r.s - s)
		if ds <= best_ds and absf(r.side - side) <= Cfg.BELT_WIDTH * 0.5:
			best_ds = ds
			best = r
	return best


func _into_tuft_within(straw: Array, from: int, under: Rider, spread: float) -> int:
	var into:= _tuft_with_room_near(under.s, under.side, spread)
	if into == null:
		return 0
	var tuft:= into.body as HayTuft
	var take:= mini(Cfg.TUFT_MAX - tuft.strands, straw.size() - from)
	var got:= _consume_straw(straw, from, take)
	if got <= 0:
		return 0
	tuft.add_strands(got)
	into.reach = load_shape(tuft) ["reach"]
	return take


func _fold_nowhere(straw: Array, from: int, running: bool) -> void:


	if not running or not _shared.is_empty():
		return
	for k in range(from, straw.size()):
		var b = straw [k]
		if not is_instance_valid(b):
			continue
		var live:= (b as Node).get_parent() as LiveStrandManager
		if live != null and live.fold_away(b):
			folded_straw += 1


static func _consume_straw(straw: Array, from: int, count: int) -> int:
	var got:= 0
	for k in range(from, from + count):
		var b: RigidBody3D = straw [k]
		var live:= b.get_parent() as LiveStrandManager
		if live != null and live.consume(b):
			got += 1
	return got


func _ride_tuft(props: PropManager, run: Array [Rider]) -> bool:
	var s:= 0.0
	var side:= 0.0
	for r in run:
		s += r.s
		side += r.side
	s /= float(run.size())
	side /= float(run.size())
	return _ride_tuft_at(props, s, side, run.size()) != null


func _ride_tuft_at(props: PropManager, s: float, side: float, strands: int) -> HayTuft:
	var basis:= _basis_at(s)
	var point:= _point_at(s) + basis.x * side


	var span:= 0.0
	if not _shared.is_empty():
		var widest:= HayTuft.full_collider_size()
		span = maxf(widest.x, widest.z) * 0.5
		for p in _shared:
			if is_instance_valid(p) and p.prop_riding_near(point, span):
				return null
	var tuft:= props.spawn("hay_tuft", Transform3D(basis * TUFT_REST, point),
		{ "strands": strands }) as HayTuft
	if tuft == null:
		return null
	_take(tuft, { "s": s, "side": side, "lift": 0.0 }, load_shape(tuft, basis.y), true, false)
	if span > 0.0:
		var room:= Cfg.TUFT_MAX - tuft.strands
		var grew:= false
		for p in _shared:
			if room <= 0:
				break
			if not is_instance_valid(p):
				continue
			var took:= p.give_up_straw_near(point, span, room)
			if took > 0:
				tuft.add_strands(took)
				room -= took
				grew = true


		if grew:
			for r in _riders:
				if r.body == tuft:
					r.reach = load_shape(tuft) ["reach"]
					break
	return tuft


func prop_riding_near(at: Vector3, reach: float) -> bool:
	if _records_at_point(at, reach):
		return true
	for r in _riders:
		if not r.prop:
			continue
		var b = r.body
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.global_position.distance_to(at) < r.reach + reach:
			return true
	return false


func give_up_straw_near(at: Vector3, reach: float, room: int) -> int:
	var gone:= { }
	for r in _riders:
		if gone.size() >= room:
			break
		if r.prop:
			continue
		var b = r.body
		if not is_instance_valid(b) or not b.is_inside_tree() or b.get_parent() is not LiveStrandManager or b.has_meta("needle_index") or b.global_position.distance_to(at) >= reach:
			continue
		gone [b] = true
	if gone.is_empty():
		return 0


	var kept: Array [Rider] = []
	for r in _riders:
		if not gone.has(r.body):
			kept.append(r)
	_riders = kept
	_queued_still = false
	var took:= 0
	for b in gone.keys():
		if not is_instance_valid(b):
			continue
		var rb:= b as RigidBody3D
		if _owns(rb):
			rb.remove_meta(LiveStrandManager.META_RIDER)
		var live:= rb.get_parent() as LiveStrandManager
		if live != null and live.consume(rb):
			took += 1
	_put_load(get_instance_id(), _ride_load())
	return took


func _carry(delta: float) -> void:
	if _riders.is_empty():
		return
	if queued_skip_enabled and _queued_still and _queue_remains_blocked():
		for r in _riders:
			if _hold_line >= 0.0 and r.ps + r.reach <= _hold_line + HOLD_SLACK:
				r.speed = 0.0
			else:
				r.speed = minf(drive_speed, move_toward(r.speed, drive_speed,
					Cfg.BELT_RIDE_PICKUP * delta))
			if _ride_clock >= r.hold_due:
				LiveStrandManager.hold(r.body)
				r.hold_due = _ride_clock + HOLD_REFRESH
		_deck_moved = 0.0
		return
	_queued_still = false
	var total:= path_length()
	var leaving: Array [Rider] = []
	var i:= 0
	while i < _riders.size():
		var r: Rider = _riders [i]


		var b = r.body


		if not is_instance_valid(b) or not b.is_inside_tree() or not is_same(b.get_meta(LiveStrandManager.META_RIDER, false), self):
			_riders.remove_at(i)
			continue


		r.speed = minf(drive_speed, move_toward(r.speed, drive_speed,
			Cfg.BELT_RIDE_PICKUP * delta))
		r.s = r.s + r.speed * delta
		if r.slide != 0.0:
			r.slide = move_toward(r.slide, 0.0, SINGLE_FILE_SLIDE * delta)
		if r.glide != 0.0:
			r.glide = move_toward(r.glide, 0.0, PROP_GLIDE_SPEED * delta)
		if r.drop != 0.0:
			r.drop = move_toward(r.drop, 0.0, PROP_GLIDE_SPEED * delta)
		i += 1


	if _hold_line >= 0.0:
		for r in _riders:
			if r.ps + r.reach <= _hold_line + HOLD_SLACK:
				r.s = r.ps
				r.speed = 0.0


	if not _ordered():
		_riders.sort_custom(_leader_first)
	for k in range(1, _riders.size()):
		var me: Rider = _riders [k]
		for j in range(k - 1, -1, -1):
			var ahead: Rider = _riders [j]


			var lead_s:= minf(ahead.s,
				maxf(total - maxf(_hold_back, ahead.reach * 2.0), 0.0))


			var need:= maxf(me.gap, ahead.reach + me.reach)
			if lead_s - me.s > maxf(need, Cfg.BELT_RIDE_SPACING):
				break
			if absf(ahead.side - me.side) > maxf(ahead.reach + me.reach,
						Cfg.STRAND_THICK * 6.0):
				continue


			var want_s:= lead_s - need
			var here:= me.s
			if want_s < here:
				me.s = (maxf(want_s, here - drive_speed * WYE_BACK_EASE_SCALE * delta) if shares_deck()
					else maxf(want_s, me.ps))
			break


	if run.count() > 0:
		for r in _riders:
			var lim:= _record_limit_ahead(r)
			if lim < r.s:
				r.s = maxf(lim, r.ps)

	if not _foreign.is_empty():
		for r in _riders:
			var lim:= _foreign_limit(r.s, r.reach, r.side, r.gap)
			if lim < r.s:
				r.s = maxf(lim, r.ps)


	var handed: Array [Vector2] = []


	var lane_wise:= downstream == null or not downstream.shares_deck()


	for k in range(_riders.size() - 1, -1, -1):
		var r: Rider = _riders [k]
		var park:= maxf(total - maxf(_hold_back, r.reach * 2.0), 0.0)
		if r.s >= park:


			if (_outlet_held and holds(r.body)) or _end_shut or _lane_handed(handed, r.side, r.reach, lane_wise) or (downstream != null
						and not _refused_for_good(r.body)
						and not downstream.accepts_handover(r.gap,
							r.side, r.reach, self, r.body)):


				r.s = (park if shares_deck()
					else minf(r.s, maxf(park, r.ps)))
				_place(r)
				continue


			if r.s < total:
				_place(r)
				continue


			r.s = total
			r.glide = 0.0
			r.drop = 0.0
			_place(r)
			handed.append(Vector2(r.side, r.reach))
			leaving.append(r)
			_riders.remove_at(k)
			continue
		_place(r)


	_deck_moved = 0.0
	if not _riders.is_empty():
		for r in _riders:
			var now_s:= r.s
			_deck_moved += now_s - r.ps
			r.ps = now_s
		_deck_moved /= float(_riders.size())
	_queued_still = coarse_far and _shared.is_empty() and not _riders.is_empty() and leaving.is_empty() and _deck_moved == 0.0
	_queued_drive = drive_speed
	_queued_hold_line = _hold_line


	for r in leaving:
		var gone = r.body
		if downstream == null or not downstream.receive_handover(r, self):
			_drop(r, _direction_at(total) * r.speed)


		if is_instance_valid(gone):
			handed_on.emit(gone)


const SHED_EVERY:= 0.5
const SHED_PER_PASS:= 2
var _shed_clock:= 0.0


const SHED_MARK_EVERY_MS:= 4000
const SHED_MARK_RANGE:= 30.0
var _shed_mark_at:= - SHED_MARK_EVERY_MS


func _mark_shed(s: float) -> void:
	var now:= Time.get_ticks_msec()
	if now - _shed_mark_at < SHED_MARK_EVERY_MS:
		return
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return
	var at:= _point_at(s) + Vector3(0, 0.6, 0)
	if cam.global_position.distance_to(at) > SHED_MARK_RANGE:
		return
	_shed_mark_at = now
	BeltShedMark.play(at, get_tree().current_scene)


func _shed_over_cap() -> void:
	if not Cfg.belt_decay or (_riders.is_empty() and run.count() == 0):
		return
	var over:= belt_load() - Cfg.belt_cap
	if over <= 0:
		return
	var props:= get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager
	var budget: int = mini(over, SHED_PER_PASS)


	var spared: Array [int] = []
	var took:= 0

	var shed_s:= -1.0
	while took < budget:
		var pick:= -1
		for k in _riders.size():
			if k in spared:
				continue
			if pick < 0 or _riders [k].s < _riders [pick].s:
				pick = k
		if pick < 0:
			break
		var r: Rider = _riders [pick]
		var body = r.body


		if not is_instance_valid(body):
			_riders.remove_at(pick)
			for i in spared.size():
				if spared [i] > pick:
					spared [i] -= 1
			continue
		var item:= body as Carryable
		if item != null and not _may_fold(item):
			spared.append(pick)
			continue


		_riders.remove_at(pick)
		_drop(r, Vector3.ZERO)

		for i in spared.size():
			if spared [i] > pick:
				spared [i] -= 1
		if item != null and props != null:
			props.fold_away(item)
		shed_s = r.s
		took += 1


	while took < budget and run.count() > 0:
		var row:= _shed_row()
		if row < 0:
			break
		var rec:= run.remove_at(row)
		GameState.return_hay(float(rec ["strands"]))
		shed_s = float(rec ["s"])
		took += 1
	if shed_s >= 0.0:
		_mark_shed(shed_s)
	if took > 0:


		_put_load(get_instance_id(), _ride_load())


func _queue_remains_blocked() -> bool:
	if not coarse_far or not _shared.is_empty() or drive_speed != _queued_drive or _hold_line != _queued_hold_line or _took_straw:
		return false
	var total:= path_length()
	var head_at_tail:= false
	for r in _riders:
		var body = r.body
		if not is_instance_valid(body) or not body.is_inside_tree() or not is_same(body.get_meta(LiveStrandManager.META_RIDER, false), self) or not r.prop or body is HayTuft or r.slide != 0.0 or r.glide != 0.0 or r.drop != 0.0 or r.placed_epoch != _geom_epoch or r.s != r.ps or r.placed_s != r.s or r.placed_side != r.side or r.placed_drop != r.drop:
			return false
		var park:= maxf(total - maxf(_hold_back, r.reach * 2.0), 0.0)
		if r.s >= park:
			head_at_tail = true
			if not ((_outlet_held and holds(body)) or _end_shut) and (downstream == null or downstream.accepts_handover(
						r.gap, r.side, r.reach, self, body)):
				return false
	return head_at_tail or drive_speed == 0.0 or _hold_line >= 0.0


func _may_fold(item: Carryable) -> bool:
	return item.hay_strands() > 0 and not item.holds_needle() and not item.is_held()


const HOLD_REFRESH:= 0.5


static func _leader_first(x: Rider, y: Rider) -> bool:
	if is_equal_approx(x.s, y.s):
		return x.seq < y.seq
	return x.s > y.s


func _ordered() -> bool:
	for k in range(1, _riders.size()):
		var front: Rider = _riders [k - 1]
		var back: Rider = _riders [k]
		if (back.seq < front.seq) if is_equal_approx(back.s, front.s) else (back.s > front.s):
			return false
	return true


func _park_at(total: float, reach: float) -> float:
	return maxf(total - maxf(_hold_back, reach * 2.0), 0.0)


func _place(r: Rider) -> void:
	var b: RigidBody3D = r.body


	var s:= r.s
	if r.glide != 0.0 and _cum.size() > 0:
		s = clampf(s + r.glide, 0.0, _cum [_cum.size() - 1])
	var drawn_side:= r.side + r.slide
	if s != r.placed_s or drawn_side != r.placed_side or r.drop != r.placed_drop or r.placed_epoch != _geom_epoch:


		var last:= _line.size() - 2
		if last < 0:
			return
		var i:= 0
		while i < last and s > _cum [i + 1]:
			i += 1
		var basis: Basis = _seg_basis [i]
		var span: float = maxf(_cum [i + 1] - _cum [i], 1e-06)
		var at: Vector3 = _line [i].lerp(_line [i + 1], clampf((s - _cum [i]) / span, 0.0, 1.0)) + basis.x * drawn_side + basis.y * (r.lift + r.drop)
		b.global_transform = Transform3D(basis * r.rest, at)
		r.placed_s = s
		r.placed_side = drawn_side
		r.placed_drop = r.drop
		r.placed_epoch = _geom_epoch


	if _ride_clock >= r.hold_due:
		LiveStrandManager.hold(b)
		r.hold_due = _ride_clock + HOLD_REFRESH


static var debug_props:= false
static var debug_last_refusal: Dictionary = { }


static func _dbg(rb: RigidBody3D, why: String) -> void:
	if debug_props:
		debug_last_refusal [rb.get_instance_id()] = why


const QUEUE_BOUNCE_CLEAR:= 0.06


const QUEUE_BOUNCE_MIN_GAP:= 0.03

const QUEUE_BOUNCE_GRACE:= 0.25
const META_QUEUE_BOUNCE:= &"belt_queue_bounce_until"


const META_JOINS_QUEUE:= &"belt_joins_queue_until"


const JOINS_QUEUE_SECONDS:= 4.0

const QUEUE_FULL_BADGE_UP:= 0.35


func _bounce_off_queue(rb: RigidBody3D, at: Dictionary) -> void:
	var now:= Time.get_ticks_msec() * 0.001
	if float(rb.get_meta(META_QUEUE_BOUNCE, 0.0)) > now:
		return
	var basis:= _basis_at(float(at ["s"]))
	var shape:= load_shape(rb, basis.y)
	if not _shared.is_empty() and _a_sibling_takes(rb, float(shape ["reach"])):
		return
	var side:= float(at.get("slide", at ["side"]))
	var out:= signf(side) if absf(side) > 0.02 else (1.0 if randf() < 0.5 else -1.0)
	var g:= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var kick:= queue_bounce_kick(shape, out * side, g)


	var dir:= basis.x * out
	if not _shared.is_empty():
		var space:= get_world_3d().direct_space_state
		var best:= INF
		var best_open:= INF
		var open_dir:= Vector3.ZERO
		for i in WYE_KICK_DIRECTIONS:
			var a:= TAU * float(i) / float(WYE_KICK_DIRECTIONS)
			var d:= Vector3(cos(a), 0.0, sin(a))
			var edge:= _deck_edge(rb.global_position, d)
			if edge < best:
				best = edge
				dir = d
			var from:= rb.global_position + Vector3.UP * WYE_KICK_RAY_UP
			var q:= PhysicsRayQueryParameters3D.create(from, from + d * (edge + 0.3),
				Cfg.L_BUILD, [rb.get_rid()])
			if space.intersect_ray(q).is_empty() and edge < best_open:
				best_open = edge
				open_dir = d
		if open_dir != Vector3.ZERO:
			best = best_open
			dir = open_dir
		kick = queue_bounce_kick(shape, 0.0, g, best)


	if not _shared.is_empty():
		PhysicsServer3D.body_set_state(rb.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
			rb.global_transform.translated(Vector3.UP * 0.03))
	rb.set_meta(META_QUEUE_BOUNCE, now + kick.z + QUEUE_BOUNCE_GRACE)


	var item:= rb as Carryable
	if item != null:
		item.unplant()
	rb.sleeping = false
	rb.linear_velocity = dir * kick.x + basis.y * kick.y


	rb.angular_velocity = dir.cross(basis.y).normalized() * 1.5


	FullBadge.flash_over(self, to_local(rb.global_position + Vector3.UP * QUEUE_FULL_BADGE_UP),
		FullBadge.NO_ROOM)


static func mark_machine_throw(rb: RigidBody3D) -> void:
	if is_instance_valid(rb):
		rb.set_meta(META_JOINS_QUEUE, Time.get_ticks_msec() * 0.001 + JOINS_QUEUE_SECONDS)
		if rb is Carryable:
			(rb as Carryable).arm_flight()


static func joins_queue(rb: RigidBody3D) -> bool:
	return float(rb.get_meta(META_JOINS_QUEUE, 0.0)) > Time.get_ticks_msec() * 0.001


static func queue_bounce_kick(shape: Dictionary, toward: float, g: float,
		edge: float = Cfg.BELT_WIDTH * 0.5) -> Vector3:
	var r: float = shape ["reach"]
	var inner:= edge - Cfg.BELT_RAIL_T
	var outer:= edge
	var d1:= maxf(inner - toward - r, QUEUE_BOUNCE_MIN_GAP)
	var d2:= maxf(outer - toward + r, d1 + Cfg.BELT_RAIL_T)
	var h:= Cfg.BELT_RAIL_H + QUEUE_BOUNCE_CLEAR

	var a:= h / (d1 * d2)
	var vx:= sqrt(g / (2.0 * a))
	var span:= d1 + d2
	return Vector3(vx, a * span * vx, span / vx)


func _wye_shut() -> bool:
	if _catching or _shared.is_empty():
		return false
	for p in _shared:
		if is_instance_valid(p) and p._catching:
			return false
	return true


func _a_sibling_takes(rb: RigidBody3D, reach: float) -> bool:
	for p in _shared:
		if not is_instance_valid(p) or not (p._catching or p._wye_shut()):
			continue
		var at:= p._nearest(rb.global_position)
		var s:= float(at ["s"])
		if absf(float(at ["side"])) > Cfg.BELT_WIDTH * 0.5 or s >= p.path_length() - p._catch_dead_zone:
			continue
		if not p._occupied(s, 0.0, reach) and p._lane_has_room(s, 0.0) and not p._in_shut_mouth(s, reach, rb):
			return true
	return false


func _deck_edge(from: Vector3, dir: Vector3) -> float:
	var space:= get_world_3d().direct_space_state
	var d:= 0.0
	while d < DECK_EDGE_MAX:
		d += DECK_EDGE_STEP
		var pt:= from + dir * d
		var q:= PhysicsRayQueryParameters3D.create(pt + Vector3.UP * Cfg.BELT_RAIL_H * 2.0,
			pt - Vector3.UP * DECK_EDGE_DROP, Cfg.L_BUILD)
		if space.intersect_ray(q).is_empty():
			return d
	return DECK_EDGE_MAX


const DECK_EDGE_STEP:= 0.05

const DECK_EDGE_DROP:= 0.3
const DECK_EDGE_MAX:= 3.0

const WYE_KICK_DIRECTIONS:= 8


const WYE_KICK_RAY_UP:= 0.25


func _catch() -> void:
	_perched.clear()
	_perch_left = PERCH_PER_PASS


	var props_only:= _wye_shut()
	if not _catching and not props_only:
		return

	var hold_until:= Time.get_ticks_msec() * 0.001 + LiveStrandManager.HOLD_GRACE
	var hold_renew_below:= hold_until - HOLD_REFRESH
	for bodies: Array in _overlaps():
		for node in bodies:


			if not _catching and not props_only:
				return
			var rb:= node as RigidBody3D
			if props_only and rb != null and not (rb.collision_layer & Cfg.L_PROP):
				continue


			if rb == null or not rb.is_inside_tree():
				continue


			if rb.freeze and not LiveStrandManager.is_pinned(rb):
				_dbg(rb, "frozen")
				continue


			var prop:= bool(rb.collision_layer & Cfg.L_PROP)
			if not prop and not (rb.collision_layer & Cfg.L_STRAND):
				continue
			if sealed_against(rb):
				_dbg(rb, "sealed run, no record kind")
				continue
			if rb.has_meta(LiveStrandManager.META_RIDER):
				_dbg(rb, "rider_meta")
				continue


			if prop and float(rb.get_meta(META_QUEUE_BOUNCE, 0.0)) > Time.get_ticks_msec() * 0.001:
				_dbg(rb, "queue_bounce")
				continue


			if prop and _blocked and _shut_out.has(rb.get_instance_id()) and (rb.sleeping or rb.linear_velocity.length_squared() < SHUT_OUT_STILL):
				if float(rb.get_meta(LiveStrandManager.META_HOLD_UNTIL, 0.0)) < hold_renew_below:
					rb.set_meta(LiveStrandManager.META_HOLD_UNTIL, hold_until)
				_dbg(rb, "run refused (still)")
				continue


			var at:= _nearest(rb.global_position)


			var shape:= (load_shape(rb, _basis_at(float(at ["s"])).y) if prop
				else { "reach": Cfg.STRAND_THICK, "lift": 0.0, "rest": 0.0 })
			var reach: float = shape ["reach"]
			var ride: float = shape ["lift"]


			if float(at ["s"]) >= path_length() - _catch_dead_zone:
				_dbg(rb, "dead_zone")
				continue


			if float(at ["s"]) > loose_mouth and float(at ["s"]) < path_length() - loose_tail:
				_dbg(rb, "sealed")
				continue


			if record_only and _plain_straw(rb):
				if float(at ["s"]) <= loose_mouth:
					_take_straw(rb, float(at ["s"]))
				continue


			if not prop and Cfg.belt_decay and belt_load() >= Cfg.belt_cap:
				_refused += 1
				continue


			if at ["lift"] < - Cfg.BELT_DECK_THICK:
				_dbg(rb, "under_deck")
				continue


			var band:= Cfg.BELT_WIDTH * 0.5 if prop and not _shared.is_empty() else _ride_half_width(reach)


			if stand_belt and stand_keeps_straw and not prop and absf(at ["side"]) > band and absf(at ["side"]) <= Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T:
				at = at.duplicate()
				at ["slide"] = at ["side"]
				at ["side"] = clampf(float(at ["side"]), - band, band)
			if absf(at ["side"]) > band:


				if not prop and gathers_straw and straw_tufts_enabled and float(at ["lift"]) <= Cfg.BELT_DRIVE_H and _perch_on_tuft(rb, float(at ["s"]), float(at ["side"])):
					continue
				_dbg(rb, "side %.2f" % float(at ["side"]))
				continue


			if prop and single_file(rb):
				at = at.duplicate()
				at ["slide"] = at ["side"]
				at ["side"] = 0.0


			if float(rb.get_meta(LiveStrandManager.META_HOLD_UNTIL, 0.0)) < hold_renew_below:
				rb.set_meta(LiveStrandManager.META_HOLD_UNTIL, hold_until)


			if _in_shut_mouth(float(at ["s"]), reach, rb):
				_dbg(rb, "shut mouth")


				if prop:
					_bounce_off_queue(rb, at)
				continue


			if prop:
				var deck_vy:= drive_speed * _basis_at(float(at ["s"])).z.y
				var settled_lo:= minf(0.0, deck_vy) - PROP_SETTLE_SPEED
				var settled_hi:= maxf(0.0, deck_vy) + PROP_SETTLE_SPEED
				if rb.linear_velocity.y < settled_lo or rb.linear_velocity.y > settled_hi:
					_dbg(rb, "settle vy %.2f outside %.2f..%.2f"
						% [rb.linear_velocity.y, settled_lo, settled_hi])
					continue


			if at ["lift"] - ride > Cfg.BELT_RIDE_CATCH_H:


				var stacked:= prop and float(at ["lift"]) - ride < 0.45 and _occupied(float(at ["s"]), float(at ["side"]), reach)
				if not stacked:


					if not prop and gathers_straw and straw_tufts_enabled and float(at ["lift"]) <= Cfg.BELT_DRIVE_H and _perch_on_tuft(rb, float(at ["s"]), float(at ["side"])):
						continue
					_dbg(rb, "height lift %.2f" % float(at ["lift"]))
					continue


			if _occupied(float(at ["s"]), float(at ["side"]), reach):


				var gathering:= gathers_straw and straw_tufts_enabled
				if not prop and gathering and _into_riding_tuft(rb, float(at ["s"]),
						float(at ["side"])):
					continue
				if not prop and not gathering:
					_dbg(rb, "occupied s %.2f" % float(at ["s"]))
					continue


				if prop and not joins_queue(rb):
					_dbg(rb, "occupied s %.2f" % float(at ["s"]))
					_bounce_off_queue(rb, at)
					continue


				var behind:= _behind_riders(float(at ["s"]), float(at ["side"]), reach)
				var tries:= 0
				while behind >= 0.0 and tries < 4 and _occupied(behind, float(at ["side"]), reach):
					behind = _behind_riders(behind, float(at ["side"]), reach)
					tries += 1
				if behind < 0.0 or _occupied(behind, float(at ["side"]), reach):
					_dbg(rb, "occupied s %.2f" % float(at ["s"]))
					if prop:
						_bounce_off_queue(rb, at)
					continue


				if _in_shut_mouth(behind, reach, rb):
					_dbg(rb, "shut mouth")
					if prop:
						_bounce_off_queue(rb, at)
					continue
				at = at.duplicate()
				at ["found_s"] = at ["s"]
				at ["s"] = behind


			if not _lane_has_room(float(at ["s"]), float(at ["side"])):
				_dbg(rb, "lane_full s %.2f" % float(at ["s"]))
				if prop:
					_bounce_off_queue(rb, at)
				continue


			if not _shared.is_empty() and (_shared_occupied(rb.global_position, reach) or _shared_occupied(_boards_at(at), reach)):
				_dbg(rb, "shared_occupied s %.2f" % float(at ["s"]))
				continue


			if prop and records_props and _record_kind(rb) >= 0:


				if not _board_record(rb, at, shape) and (props_only or (_blocked and run.holds_kind(_record_kind(rb)))):
					_bounce_off_queue(rb, at)
			else:
				_take(rb, at, shape, prop)


func _take(rb: RigidBody3D, at: Dictionary, shape: Dictionary,
		prop: bool, announce: bool = true, arriving: float = NAN) -> void:


	wake()
	_max_at_take = maxi(_max_at_take, belt_load())


	_put_load(get_instance_id(), _ride_load() + (1.0 if prop else strand_load()))
	if not prop:
		_took_straw = true
	var s: float = at ["s"]
	var basis:= _basis_at(s)


	var along: float = clampf(
		arriving if not is_nan(arriving) else rb.linear_velocity.dot(basis.z),
		0.0, drive_speed)


	LiveStrandManager.unpin(rb)


	LiveStrandManager.release_hold(rb)
	rb.set_meta(LiveStrandManager.META_RIDER, self)
	if prop and cargo_physics_enabled:
		rb.collision_layer &= ~ Cfg.L_BELT_CATCH


	var ride_mode:= RigidBody3D.FREEZE_MODE_STATIC if prop and cargo_physics_enabled else RigidBody3D.FREEZE_MODE_KINEMATIC
	var boarding:= not rb.freeze or rb.freeze_mode != ride_mode
	if boarding and not prop:
		rb.freeze_mode = ride_mode
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	if rb.continuous_cd:
		rb.continuous_cd = false
	_seq += 1
	var reach: float = shape ["reach"]


	var min_gap:= maxf(reach * 2.0, Cfg.STRAND_THICK * 2.0)
	var r:= Rider.new()
	r.body = rb


	r.reach = reach


	r.prop = prop


	r.seq = _seq

	r.board = _ride_clock
	r.s = s
	r.side = clampf(at ["side"], - _ride_half_width(reach), _ride_half_width(reach))


	var slide_half:= Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T if stand_belt and stand_keeps_straw and not prop else _ride_half_width(reach)
	r.slide = clampf(float(at.get("slide", r.side)), - slide_half, slide_half) - r.side


	r.lift = float(shape ["rest"]) if prop else Cfg.STRAND_THICK * 0.5


	if prop:
		r.glide = float(at.get("found_s", s)) - s
		r.drop = clampf(float(at.get("lift", r.lift)) - r.lift, 0.0, PROP_GLIDE_DROP_MAX)


	r.rest = ((TUFT_REST if rb is HayTuft else Basis.IDENTITY) if prop
		else basis.inverse() * rb.global_transform.basis)
	r.speed = along


	r.ps = s


	r.gap = clampf(_gap_ahead(s, at ["side"], reach), min_gap,
		maxf(Cfg.BELT_RIDE_SPACING, min_gap))


	if boarding and prop:
		_place(r)
		PhysicsServer3D.body_set_state(rb.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
			rb.global_transform)
		rb.freeze_mode = ride_mode
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	_riders.append(r)
	_queued_still = false
	BeltItemBatch.adopt(rb)
	if announce:
		caught.emit(rb)


func _gap_ahead(s: float, side: float, reach: float = Cfg.STRAND_THICK) -> float:
	var gap:= _records_gap_ahead(s, side, reach)
	for r in _riders:
		var d:= r.s - s
		if d < 0.0 or d >= gap:
			continue
		if absf(r.side - side) <= maxf(r.reach + reach, Cfg.STRAND_THICK * 6.0):
			gap = d
	return gap


func _drop(r: Rider, velocity: Vector3) -> void:
	_queued_still = false
	var b = r.body
	if not is_instance_valid(b):
		return
	BeltItemBatch.release(b)
	if _owns(b):
		b.remove_meta(LiveStrandManager.META_RIDER)
	if r.prop and cargo_physics_enabled:
		b.collision_layer |= Cfg.L_BELT_CATCH
	if not b.is_inside_tree():
		return
	b.freeze = false
	b.linear_velocity = velocity
	b.angular_velocity = Vector3.ZERO
	LiveStrandManager.hold(b)


static func release(b: RigidBody3D) -> void:
	if not is_instance_valid(b):
		return
	if not b.has_meta(LiveStrandManager.META_RIDER):
		return
	var path:= b.get_meta(LiveStrandManager.META_RIDER) as BeltPath
	if path == null:
		b.remove_meta(LiveStrandManager.META_RIDER)
		return
	path._release_one(b)


func _release_one(b: RigidBody3D) -> void:
	_queued_still = false
	for k in _riders.size():
		if _riders [k].body == b:
			var r: Rider = _riders [k]
			_riders.remove_at(k)
			_drop(r, Vector3.ZERO)
			return

	if _owns(b):
		b.remove_meta(LiveStrandManager.META_RIDER)


func _owns(b: RigidBody3D) -> bool:
	return is_same(b.get_meta(LiveStrandManager.META_RIDER, false), self)


static func is_rider(b: RigidBody3D) -> bool:
	return is_instance_valid(b) and b.has_meta(LiveStrandManager.META_RIDER)


const RECORD_WINDOW:= 1.0


static var _ticked: Array [BeltPath] = []

static var _props_ref: PropManager = null


var _eats: Callable = Callable()


var _records_held:= false


static var _kind_shapes: Dictionary = { }


func _record_kind(rb: RigidBody3D) -> int:
	if record_only and rb is HayTuft:
		return BeltRun.Kind.TUFT
	return record_kind(rb)


const SEALED_STRAW_JOIN:= 0.5


func _straw_tuft_row(at_s: float) -> int:
	if run.count() == 0:
		return -1
	var i:= run.first() + run.count() - 1
	if run.kind_of(i) != BeltRun.Kind.TUFT or run.strands_of(i) >= Cfg.TUFT_MAX or absf(run.s_of(i) - at_s) > SEALED_STRAW_JOIN:
		return -1
	return i


func _straw_room(at_s: float) -> bool:
	if _straw_tuft_row(at_s) >= 0:
		return true
	var shape:= shape_of_kind(BeltRun.Kind.TUFT, Cfg.TUFT_MAX)
	return not shape.is_empty() and run.accepts(at_s, float(shape ["reach"]),
		Cfg.BELT_RIDE_SPACING, BeltRun.Kind.TUFT)


func _take_straw(rb: RigidBody3D, at_s: float) -> bool:
	var live:= rb.get_parent() as LiveStrandManager
	if live == null:
		return false
	var i:= _straw_tuft_row(at_s)
	if i < 0:
		var shape:= shape_of_kind(BeltRun.Kind.TUFT, Cfg.TUFT_MAX)
		if shape.is_empty() or not run.accepts(at_s, float(shape ["reach"]),
				Cfg.BELT_RIDE_SPACING, BeltRun.Kind.TUFT):
			return false
		if not run.board(BeltRun.Kind.TUFT, 0, -1, float(shape ["reach"]), 0.0,
				float(shape ["rest"]), at_s, drive_speed, { "strands": 0 }):
			return false
		i = run.first() + run.count() - 1
	if rb.has_meta(LiveStrandManager.META_RIDER):
		rb.remove_meta(LiveStrandManager.META_RIDER)
	LiveStrandManager.release_hold(rb)
	if not live.consume(rb):
		return false
	run.add_strands(i, 1)
	wake()
	_put_load(get_instance_id(), _ride_load())
	return true


func _tuft_needs_body(kind: int) -> bool:
	return kind == BeltRun.Kind.TUFT and not (downstream != null
		and is_instance_valid(downstream) and downstream.record_only)


static func record_kind(rb: RigidBody3D) -> int:
	if rb == null or rb is HayTuft:
		return -1
	var item:= rb as Carryable
	if item == null:
		return -1
	return BeltRun.ITEM_IDS.find(item.item_id)


static func rides_sealed(rb: RigidBody3D) -> bool:
	return rb != null and rb.has_meta("needle_index")


static func filter_kind(rb: RigidBody3D) -> int:
	if rb is HayTuft:
		return BeltRun.Kind.TUFT
	return record_kind(rb)


static func tick_paths(delta: float) -> void:


	if quiet_ticks:
		var now:= Engine.get_physics_frames()
		_awake_i = 0
		while _awake_i < _awake.size():
			var q = _awake [_awake_i]
			_awake_i += 1
			if not is_instance_valid(q):
				continue


			if q._due > now:
				continue
			if not q.is_inside_tree():
				continue
			if not q.is_physics_processing():
				continue
			_tick_one(q, delta)
		_awake_i = -1
		return
	var i:= 0
	while i < _live.size():


		var p = _live [i]
		i += 1
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		if not p.is_physics_processing():
			continue
		_tick_one(p, delta)


static func _tick_one(p: BeltPath, delta: float) -> void:
	if FactoryClock.profile:
		var t:= Time.get_ticks_usec()
		var stride: int = p._tick_stride()
		p.tick_path(delta)


		if p._prof_stride != stride or p._prof_key.is_empty():
			p._prof_stride = stride
			p._prof_key = "belt of %s, stride %d" % [
				FactoryClock.class_of(p.get_parent()), stride]
		FactoryClock.prof_add(p._prof_key, Time.get_ticks_usec() - t)
		return
	p.tick_path(delta)


static var _awake: Array = []
static var _awake_i:= -1
static var _serial_next:= 0

var _serial:= 0
var _listed:= false

var _prof_key:= ""
var _prof_stride:= -1


func _list_awake() -> void:
	if _listed:
		return
	_listed = true


	_due = 0
	_seen_tick = -1
	var lo:= 0
	var hi:= _awake.size()
	while lo < hi:
		var mid:= (lo + hi) >> 1
		if _awake [mid]._serial < _serial:
			lo = mid + 1
		else:
			hi = mid
	_awake.insert(lo, self)
	if lo < _awake_i:
		_awake_i += 1


func _unlist_awake() -> void:
	if not _listed:
		return
	_listed = false
	var k:= _awake.find(self)
	if k < 0:
		return
	_awake.remove_at(k)
	if k < _awake_i:
		_awake_i -= 1


static func flush_runs() -> void:
	if _ticked.is_empty():
		return
	for p in _ticked:
		if is_instance_valid(p):
			p.run.flush()
	for p in _ticked:
		if is_instance_valid(p) and p.is_inside_tree():
			p._after_flush()
	_ticked.clear()


func _after_flush() -> void:
	if not run.has_head():
		return
	if _seam_carries_records() and not _tuft_needs_body(run.head_kind()):
		return
	if _end_shut or ((_records_held or _outlet_held) and run.holds_kind(run.head_kind())):
		return
	_materialize_head()


func _seam_carries_records() -> bool:
	return downstream != null and is_instance_valid(downstream) and downstream.records_props


func _sync_run_links() -> void:
	var onward: BeltRun = null
	if _seam_carries_records():
		onward = downstream.run
	if run.downstream != onward:
		run.link(onward)
	var end_held:= onward == null
	if run.end_held != end_held:
		run.set_end_held(end_held)


	var tufts_held:= _tuft_needs_body if record_only else Callable()
	if run.end_held_for != tufts_held:
		run.end_held_for = tufts_held
		run.wake()
	var held:= _outlet_held or _records_held or _end_shut
	if run.outlet_held != held:
		run.set_outlet_held(held)


func hold_records(eats: Callable) -> void:
	_eats = eats
	_records_held = true
	run.hold_for = _eats_kind
	_sync_run_links()


func _eats_kind(kind: int) -> bool:
	return not _eats.is_valid() or bool(_eats.call(kind, -1))


func take_record(eats: Callable = Callable(), lo: float = INF, hi: float = - INF) -> Dictionary:
	var filter:= eats if eats.is_valid() else _eats
	var rec: Dictionary = { }
	if _records_held:
		rec = run.take_head(filter)
	if rec.is_empty() and lo <= hi:
		rec = run.take_within(filter, lo, hi)
	if rec.is_empty():
		return rec
	_put_load(get_instance_id(), _ride_load())
	return rec


func s_at(point: Vector3) -> float:
	if _line.size() < 2:
		return 0.0
	return float(_nearest(point) ["s"])


func peek_record() -> Dictionary:
	return run.peek_head()


func has_record_head() -> bool:
	return run.has_head()


func push_record(kind: int, strands: int, needle: int, state: Variant, at: Vector3,
		speed: float = -1.0, clear: float = 0.0, seq: int = -1) -> int:
	if not records_props or _line.size() < 2:
		return -1
	if speed < 0.0:
		speed = drive_speed
	var shape:= shape_of_kind(kind, strands)
	if shape.is_empty():
		return -1
	var reach: float = shape ["reach"]
	var near:= _nearest(at)
	var s:= clampf(float(near ["s"]), 0.0, path_length())
	if not _clear_within(s, maxf(reach, clear)):
		return -1

	if not run.board(kind, strands, needle, reach, 0.0, float(shape ["rest"]), s, speed, state,
			seq, false):
		return -1
	wake()
	_max_at_take = maxi(_max_at_take, belt_load())
	_put_load(get_instance_id(), _ride_load())
	pushed_kinds |= 1 << kind
	return run.last_seq


func shape_of_kind(kind: int, strands: int = 0) -> Dictionary:
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size() or not is_inside_tree():
		return { }
	var sized:= kind == BeltRun.Kind.WAD or kind == BeltRun.Kind.TUFT
	var key:= kind + (strands * BeltRun.ITEM_IDS.size() if sized else 0)
	if _kind_shapes.has(key):
		return _kind_shapes [key]
	var proto:= ItemDb.make(BeltRun.ITEM_IDS [kind])
	if proto == null:
		return { }
	proto.collision_layer = 0
	proto.collision_mask = 0
	proto.freeze = true
	proto.visible = false
	if sized and strands > 0:
		(proto as HayWad).strands = strands


	get_tree().root.add_child(proto)
	var shape:= load_shape(proto, Vector3.UP)
	shape ["box"] = proto.ride_box()
	get_tree().root.remove_child(proto)
	proto.queue_free()
	_kind_shapes [key] = shape
	return shape


func materialize_record(i: int) -> Carryable:
	if i < run.first() or i >= run.first() + run.count():
		return null
	var props:= _props()
	if props == null:
		return null
	var rec:= run.remove_at(i)
	var item:= _spawn_record(rec, clampf(float(rec ["s"]), 0.0, path_length()))
	if item == null:


		run.board_record(rec, float(rec ["s"]), float(rec ["speed"]), false)
		return null
	_put_load(get_instance_id(), _ride_load())
	return item


func take_record_at(i: int) -> Dictionary:
	if i < run.first() or i >= run.first() + run.count():
		return { }
	var rec:= run.remove_at(i)
	_put_load(get_instance_id(), _ride_load())
	return rec


static func record_where(seq: int) -> Dictionary:
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		var f:= p.run.first()
		for i in range(f, f + p.run.count()):
			if p.run.seq_of(i) == seq:
				return { "path": p, "row": i, "pose": p.run.pose_of(i), "s": p.run.s_of(i) }
	return { }


func _rider_blockers() -> PackedFloat64Array:
	var out:= PackedFloat64Array()
	var n:= _riders.size()
	if n == 0:
		return out
	out.resize(n * 3)
	var k:= 0
	for r in _riders:
		out [k] = r.s
		out [k + 1] = r.reach
		out [k + 2] = r.side
		k += 3
	return out


func _foreign_limit(s: float, reach: float, side: float, gap: float) -> float:
	var out:= INF
	var k:= 0
	while k + 2 < _foreign.size():
		var fs:= _foreign [k]
		var fr:= _foreign [k + 1]
		if fs > s and absf(_foreign [k + 2] - side) <= maxf(fr + reach, Cfg.STRAND_THICK * 6.0):
			out = minf(out, fs - maxf(gap, fr + reach))
		k += 3
	return out


func _record_limit_ahead(r: Rider) -> float:
	var i:= run.row_behind(r.s) - 1
	var first:= run.first()
	var looked:= 0
	while i >= first and looked < 3:
		var reach:= run.reach_of(i)
		if absf(run.side_of(i) - r.side) <= maxf(reach + r.reach, Cfg.STRAND_THICK * 6.0):
			return run.s_of(i) - maxf(r.gap, reach + r.reach)
		i -= 1
		looked += 1
	return INF


func _records_clear(s: float, reach: float) -> bool:
	var rows:= run.rows_in(s - RECORD_WINDOW, s + RECORD_WINDOW)
	for i in range(rows.x, rows.y):
		if absf(run.s_of(i) - s) < maxf(reach, run.gap_of(i)):
			return false
	return true


func _records_lane_clear(s: float, reach: float, side: float, width: float) -> bool:
	var rows:= run.rows_in(s - RECORD_WINDOW, s + RECORD_WINDOW)
	for i in range(rows.x, rows.y):
		if absf(run.s_of(i) - s) >= maxf(reach, run.gap_of(i)):
			continue
		if absf(run.side_of(i) - side) <= maxf(run.reach_of(i) + width, Cfg.STRAND_THICK * 6.0):
			return false
	return true


func _records_occupied(s: float, side: float, reach: float) -> bool:
	var rows:= run.rows_in(s - RECORD_WINDOW, s + RECORD_WINDOW)
	for i in range(rows.x, rows.y):
		var mine:= run.reach_of(i)
		if absf(run.s_of(i) - s) > maxf(mine + reach, Cfg.STRAND_THICK * 2.0):
			continue
		if absf(run.side_of(i) - side) <= maxf(mine + reach, Cfg.STRAND_THICK * 6.0):
			return true
	return false


func _records_behind(s: float, side: float, reach: float) -> float:
	var out:= s
	var rows:= run.rows_in(s - RECORD_WINDOW, s + RECORD_WINDOW)
	for i in range(rows.x, rows.y):
		var mine:= run.reach_of(i)
		var need:= maxf(mine + reach, Cfg.STRAND_THICK * 2.0)
		if absf(run.s_of(i) - s) > need:
			continue
		if absf(run.side_of(i) - side) > maxf(mine + reach, Cfg.STRAND_THICK * 6.0):
			continue
		out = minf(out, run.s_of(i) - need - 0.005)
	return out


func _records_gaps_below(s: float, side: float) -> float:
	var needed:= 0.0
	var end:= run.first() + run.count()
	for i in range(run.row_behind(s), end):
		if absf(run.side_of(i) - side) <= Cfg.STRAND_THICK * 6.0:
			needed += run.gap_of(i)
	return needed


func _records_gap_ahead(s: float, side: float, reach: float) -> float:
	var gap:= Cfg.BELT_RIDE_SPACING
	var rows:= run.rows_in(s, s + gap)
	for i in range(rows.x, rows.y):
		var d:= run.s_of(i) - s
		if d < 0.0 or d >= gap:
			continue
		if absf(run.side_of(i) - side) <= maxf(run.reach_of(i) + reach, Cfg.STRAND_THICK * 6.0):
			gap = d
	return gap


func _records_clear_behind(s: float, lead: float) -> bool:
	var rows:= run.rows_in(s - lead - RECORD_WINDOW, s)
	for i in range(rows.x, rows.y):
		var rs:= run.s_of(i)
		if rs < s and s - rs < lead + maxf(Cfg.BELT_RIDE_SPACING, run.gap_of(i)):
			return false
	return true


func _records_covered(lo: float, hi: float) -> float:
	var covered:= 0.0
	var rows:= run.rows_in(lo - RECORD_WINDOW, hi + RECORD_WINDOW)
	for i in range(rows.x, rows.y):
		var s:= run.s_of(i)
		var reach:= run.reach_of(i)
		if s + reach < lo or s - reach > hi:
			continue
		covered += minf(s + reach, hi) - maxf(s - reach, lo)
	return covered


func _records_at_point(at: Vector3, reach: float) -> bool:
	if run.count() == 0 or _line.size() < 2:
		return false
	var s:= float(_nearest(at) ["s"])
	var rows:= run.rows_in(s - RECORD_WINDOW, s + RECORD_WINDOW)
	for i in range(rows.x, rows.y):
		var need:= maxf(run.reach_of(i) + reach, Cfg.STRAND_THICK * 4.0)
		if run.pose_of(i).origin.distance_to(at) < need:
			return true
	return false


func _record_row_in(at: Vector3, radius: float) -> int:
	if run.count() == 0 or _line.size() < 2:
		return -1
	var s:= float(_nearest(at) ["s"])
	var rows:= run.rows_in(s - radius, s + radius)
	for i in range(rows.x, rows.y):
		if run.pose_of(i).origin.distance_squared_to(at) <= radius * radius:
			return i
	return -1


static func record_in(at: Vector3, radius: float) -> Dictionary:
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		if p.run.count() == 0:
			continue
		var span:= p._half_len + radius
		if p._mid.distance_squared_to(at) > span * span:
			continue
		var row:= p._record_row_in(at, radius)
		if row >= 0:
			return { "path": p, "row": row, "record": p.run.record(row) }
	return { }


func _shed_row() -> int:
	var i:= run.first() + run.count() - 1
	while i >= run.first():
		if run.needle_of(i) < 0 and run.strands_of(i) > 0:
			return i
		i -= 1
	return -1


func _board_record(rb: RigidBody3D, at: Dictionary, shape: Dictionary,
		arriving: float = NAN) -> bool:
	var item:= rb as Carryable
	var kind:= _record_kind(rb)
	if item == null or kind < 0:
		return false
	var s:= clampf(float(at ["s"]), 0.0, path_length())
	var basis:= _basis_at(s)
	var reach: float = shape ["reach"]
	var half:= _ride_half_width(reach)
	var side:= clampf(float(at ["side"]), - half, half)
	var along:= clampf(arriving if not is_nan(arriving) else rb.linear_velocity.dot(basis.z),
		0.0, drive_speed)


	var state:= item.to_state()
	if item.holds_needle():
		state ["needle"] = item.needle_index


	var shut_wye:= not run.catching and _wye_shut()
	if shut_wye:
		run.catching = true
	var aboard:= run.board(kind, item.hay_strands(), item.needle_index, reach, side,
			float(shape ["rest"]), s, along, state)
	if shut_wye:
		run.catching = false
	if not aboard:
		_dbg(rb, "run refused s %.2f" % s)
		return false
	wake()
	_max_at_take = maxi(_max_at_take, belt_load())
	_put_load(get_instance_id(), _ride_load())
	caught.emit(rb)
	_retire_body(rb)
	return true


func _retire_body(rb: RigidBody3D) -> void:
	retire_body(rb, _props())


static func retire_body(rb: RigidBody3D, props: PropManager) -> void:
	BeltItemBatch.release(rb)
	LiveStrandManager.release_hold(rb)
	if rb.has_meta(LiveStrandManager.META_RIDER):
		rb.remove_meta(LiveStrandManager.META_RIDER)
	var item:= rb as Carryable
	if item != null and props != null and is_instance_valid(props) and props.items.has(item):
		props.remove(item)
		return
	var parent:= rb.get_parent()
	if parent != null:
		parent.remove_child(rb)
	rb.queue_free()


func _materialize_head() -> void:
	var rec:= run.peek_head()
	if rec.is_empty():
		return
	var s:= clampf(float(rec ["s"]), 0.0, path_length())
	if int(rec ["kind"]) == BeltRun.Kind.TUFT and int(rec ["strands"]) < Cfg.TUFT_MERGE_AT and _materialize_straw(rec, s):
		return
	var item:= _spawn_record(rec, s)
	if item == null:
		return
	run.take_head()
	var at:= { "s": s, "side": float(rec ["side"]), "lift": float(rec ["lift"]) }
	_take(item, at, load_shape(item, _basis_at(s).y), true, false, drive_speed)


static var _straw_rng:= RandomNumberGenerator.new()


func _materialize_straw(rec: Dictionary, s: float) -> bool:
	var props:= _props()
	var n:= int(rec ["strands"])
	if props == null or props.live == null or n <= 0:
		return false
	var live:= props.live
	var bodies: Array [RigidBody3D] = []
	for k in n:
		var sk:= maxf(s - float(k) * Cfg.STRAND_THICK * 3.0, 0.0)
		var basis:= _basis_at(sk)
		var point:= _point_at(sk) + basis.x * float(rec ["side"]) + basis.y * Cfg.STRAND_THICK
		var b:= live.spawn(point, StrandFactory.random_strand_basis(_straw_rng),
			Vector3.ZERO, StrandFactory.random_tint(_straw_rng))
		if b == null:
			for back in bodies:
				live.consume(back)
			return false
		bodies.append(b)
	run.take_head()
	var shape:= { "reach": Cfg.STRAND_THICK, "lift": 0.0, "rest": 0.0 }
	for k in bodies.size():
		var sk:= maxf(s - float(k) * Cfg.STRAND_THICK * 3.0, 0.0)
		_take(bodies [k], { "s": sk, "side": float(rec ["side"]), "lift": 0.0 }, shape,
			false, false, drive_speed)
	return true


func _spawn_record(rec: Dictionary, s: float) -> Carryable:
	var props:= _props()
	if props == null:
		return null
	var kind:= int(rec ["kind"])
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
		return null
	var basis:= _basis_at(s)
	var at:= _point_at(s) + basis.x * float(rec ["side"]) + basis.y * float(rec ["lift"])
	var state: Variant = rec.get("state")
	return props.spawn(BeltRun.ITEM_IDS [kind], Transform3D(basis, at),
		state if state is Dictionary else { })


func _spill_records() -> void:
	var props:= _props()
	while run.count() > 0:
		var i:= run.first() + run.count() - 1
		var rec:= run.remove_at(i)
		if props == null:


			continue
		var item:= _spawn_record(rec, clampf(float(rec ["s"]), 0.0, path_length()))
		if item != null:
			LiveStrandManager.hold(item)


func _props() -> PropManager:
	if _props_ref != null and is_instance_valid(_props_ref) and _props_ref.is_inside_tree():
		return _props_ref
	_props_ref = null
	if is_inside_tree():
		_props_ref = get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager
	return _props_ref


const SAVE_END_SLACK:= 0.02


func save_ends() -> PackedVector3Array:
	if _line.size() < 2:
		return PackedVector3Array()
	return PackedVector3Array([_line [0], _line [_line.size() - 1]])


static func _end_key(a: Vector3, b: Vector3) -> String:
	return "%d,%d,%d|%d,%d,%d" % [roundi(a.x * 100.0), roundi(a.y * 100.0),
		roundi(a.z * 100.0), roundi(b.x * 100.0), roundi(b.y * 100.0), roundi(b.z * 100.0)]


func records_to_save() -> Array:
	var out: Array = []
	var f:= run.first()
	for i in range(f, f + run.count()):
		var kind:= run.kind_of(i)
		if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
			continue
		var state: Variant = run.state_of(i)
		out.append({
			"kind": kind,
			"strands": run.strands_of(i),
			"needle": run.needle_of(i),
			"reach": run.reach_of(i),
			"side": run.side_of(i),
			"lift": run.lift_of(i),
			"s": run.s_of(i),
			"speed": run.speed_of(i),
			"state": state if state is Dictionary else { },
			"xform": run.pose_of(i),
		})
	return out


func restore_records(rows: Array, props: PropManager) -> Vector2i:
	var boarded:= 0
	var bodied:= 0
	var can:= records_props and _line.size() >= 2


	var was_catching:= run.catching
	run.catching = true
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var kind:= int(d.get("kind", -1))
		if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
			continue
		var state: Variant = d.get("state", { })
		if not (state is Dictionary):
			state = { }
		var strands:= int(d.get("strands", 0))
		var reach:= float(d.get("reach", 0.0))
		if reach <= 0.0 and can:
			reach = float(shape_of_kind(kind, strands).get("reach", 0.0))
		var ok:= false
		if can and reach > 0.0:


			ok = run.board(kind, strands, int(d.get("needle", -1)), reach,
				0.0, float(d.get("lift", 0.0)),
				clampf(float(d.get("s", 0.0)), 0.0, path_length()),
				float(d.get("speed", drive_speed)), state, -1, false)
		if ok:
			boarded += 1
			continue
		if props != null and d.get("xform") is Transform3D:
			if props.spawn(BeltRun.ITEM_IDS [kind], d ["xform"], state) != null:
				bodied += 1
	run.catching = was_catching
	if boarded > 0:
		wake()
		_max_at_take = maxi(_max_at_take, belt_load())
		_put_load(get_instance_id(), _ride_load())
	return Vector2i(boarded, bodied)


static func belts_to_array() -> Array:
	var out: Array = []
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		if p.run.count() == 0:
			continue
		var ends:= p.save_ends()
		if ends.size() < 2:
			continue
		var rows:= p.records_to_save()
		if rows.is_empty():
			continue
		out.append({ "a": ends [0], "b": ends [1], "records": rows })
	return out


static func belts_from_array(entries: Array, props: PropManager) -> Dictionary:
	var by_key: Dictionary = { }
	var standing: Array [BeltPath] = []
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		var ends:= p.save_ends()
		if ends.size() < 2:
			continue
		standing.append(p)
		var key:= _end_key(ends [0], ends [1])
		if not by_key.has(key):
			by_key [key] = p
	var boarded:= 0
	var bodied:= 0
	var lost:= 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var rows: Array = d.get("records", [])
		var a: Vector3 = d.get("a", Vector3.INF)
		var b: Vector3 = d.get("b", Vector3.INF)
		var p: BeltPath = by_key.get(_end_key(a, b))
		if p == null:


			for q in standing:
				var ends:= q.save_ends()
				if ends [0].distance_to(a) <= SAVE_END_SLACK and ends [1].distance_to(b) <= SAVE_END_SLACK:
					p = q
					break
		if p != null:
			var n:= p.restore_records(rows, props)
			boarded += n.x
			bodied += n.y
			lost += rows.size() - n.x - n.y
			continue
		for row in rows:
			var made:= false
			if typeof(row) == TYPE_DICTIONARY and props != null:
				var kind:= int(row.get("kind", -1))
				if kind >= 0 and kind < BeltRun.ITEM_IDS.size() and row.get("xform") is Transform3D:
					var state: Variant = row.get("state", { })
					made = props.spawn(BeltRun.ITEM_IDS [kind], row ["xform"],
						state if state is Dictionary else { }) != null
			if made:
				bodied += 1
			else:
				lost += 1
	return { "boarded": boarded, "bodied": bodied, "lost": lost }


static func records_to_array() -> Array:
	var out: Array = []
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		var f:= p.run.first()
		for i in range(f, f + p.run.count()):
			var kind:= p.run.kind_of(i)
			if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
				continue
			var state: Variant = p.run.state_of(i)
			out.append({
				"id": BeltRun.ITEM_IDS [kind],
				"xform": p.run.pose_of(i),
				"state": state if state is Dictionary else { },
			})
	return out


func board_body(rb: RigidBody3D, at: Vector3, speed: float = -1.0, clear: float = 0.0) -> int:
	var item:= rb as Carryable
	var kind:= record_kind(rb)
	if item == null or kind < 0 or not records_props or _line.size() < 2:
		return -1


	if not at.is_finite():
		return -1

	if record_only:
		return -1
	var shape:= shape_of_kind(kind, item.hay_strands())
	if shape.is_empty():
		return -1
	var near:= _nearest(at)
	var s:= clampf(float(near ["s"]), 0.0, path_length())
	if not _clear_within(s, maxf(float(shape ["reach"]), clear)):
		return -1
	var spot:= { "s": s, "side": float(near ["side"]), "lift": float(shape ["rest"]) }
	if not _board_record(rb, spot, shape, drive_speed if speed < 0.0 else speed):
		return -1
	return run.last_seq


static func path_under(at: Vector3, reach: float, drop: float,
		among: Array = []) -> BeltPath:
	var best: BeltPath = null
	var best_lift:= INF
	for item in (among if not among.is_empty() else _live):
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		if not p.records_props or p._line.size() < 2:
			continue
		var span:= p._half_len + drop + Cfg.BELT_WIDTH
		if p._mid.distance_squared_to(at) > span * span:
			continue
		var near:= p._nearest(at)
		var lift:= float(near ["lift"])
		var side:= float(near ["side"])
		if lift < -0.05 or lift > drop or absf(side) > _ride_half_width(reach):
			continue


		var s:= float(near ["s"])
		var basis:= p._basis_at(s)
		var on:= p._point_at(s) + basis.x * side + basis.y * lift
		if on.distance_squared_to(at) > 0.0025:
			continue
		if lift < best_lift:
			best = p
			best_lift = lift
	return best


static func paths_near(at: Vector3, radius: float) -> Array:
	var out:= []
	for item in _live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var p:= item as BeltPath
		if not p.records_props or p._line.size() < 2:
			continue
		var span:= p._half_len + radius + Cfg.BELT_WIDTH
		if p._mid.distance_squared_to(at) <= span * span:
			out.append(p)
	return out


func path_length() -> float:
	return 0.0 if _cum.size() < 2 else _cum [_cum.size() - 1]


func centre_line() -> PackedVector3Array:
	return _line


func _seg_at(s: float) -> int:
	var last:= _line.size() - 2
	if last < 0:
		return 0
	for i in range(last + 1):
		if s <= _cum [i + 1]:
			return i
	return last


func _point_at(s: float) -> Vector3:
	if _line.size() < 2:
		return global_position
	var i:= _seg_at(s)
	var span: float = maxf(_cum [i + 1] - _cum [i], 1e-06)
	return _line [i].lerp(_line [i + 1], clampf((s - _cum [i]) / span, 0.0, 1.0))


func _direction_at(s: float) -> Vector3:
	if _line.size() < 2:
		return Vector3.BACK
	return _seg_basis [_seg_at(s)].z


func basis_at(s: float) -> Basis:
	return _basis_at(s)


func _basis_at(s: float) -> Basis:
	if _line.size() < 2:
		return Basis.IDENTITY
	return _seg_basis [_seg_at(s)]


func _nearest(p: Vector3) -> Dictionary:
	var best_d2:= INF
	var best:= -1
	var best_t:= 0.0
	var best_on:= Vector3.ZERO
	for i in range(_line.size() - 1):
		var a:= _line [i]
		var ab:= _line [i + 1] - a
		var len2:= ab.length_squared()
		if len2 < 1e-08:
			continue
		var t:= clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		var on:= a + ab * t
		var d2:= p.distance_squared_to(on)
		if d2 >= best_d2:
			continue
		best_d2 = d2
		best = i
		best_t = t
		best_on = on
	if best < 0:
		return { "s": 0.0, "side": 0.0, "lift": 0.0 }
	var basis: Basis = (_seg_basis [best] if best < _seg_basis.size()
		else run_basis(_line [best], _line [best + 1]))
	var off:= p - best_on
	return {
		"s": _cum [best] + _line [best].distance_to(_line [best + 1]) * best_t,
		"side": off.dot(basis.x),
		"lift": off.dot(basis.y),
	}


func has_strands() -> bool:
	return not _riders.is_empty() or run.count() > 0


func riders_debug() -> Array:
	var out: Array = []
	for r in _riders:
		var b = r.body
		if not is_instance_valid(b):
			continue
		var item:= b as Carryable
		out.append({


			"seq": r.seq,
			"s": r.s,
			"side": r.side,
			"slide": r.slide,
			"gap": r.gap,
			"needle": item.needle_index if item != null else -1,


			"kind": item.item_id if item != null else "",
		})


	var f:= run.first()
	for i in range(f, f + run.count()):
		out.append({
			"seq": run.seq_of(i),
			"s": run.s_of(i),
			"side": run.side_of(i),
			"slide": 0.0,
			"gap": run.gap_of(i),
			"needle": run.needle_of(i),
			"kind": BeltRun.ITEM_IDS [run.kind_of(i)],
			"record": true,
		})
	return out


func riders() -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []
	for r in _riders:
		var b = r.body
		if is_instance_valid(b) and b.is_inside_tree():
			out.append(b)
	return out
