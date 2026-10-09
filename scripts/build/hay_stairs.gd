class_name HayStairs
extends Node3D


const MODEL:= "res://assets/models/compiled/hay_stairs.scn"
const SPEC:= "res://assets/models/hay_stairs_materials.json"

const N_RIDE:= "Marker_Ride_%d"
const N_MOUTH:= "Marker_Mouth"
const N_STEP:= "Marker_Step_%d"
const N_DROP:= "Marker_BeltDrop"
const N_OUT:= "Marker_BeltOut"
const N_PANEL:= "Marker_Panel"


const STEPS:= 3


const SETTLE_SPEED:= BeltPath.PROP_SETTLE_SPEED


const RIDE_FALL_GAIN:= 2.1


const RIDE_FALL_SLOPE:= 0.75


const RIDE_TURN_RATE:= 5.0


const RIDE_TURN_REF:= 0.95


const RIDE_GAP:= 0.62


const RIDE_LIFT_MAX:= 0.45


const DECK_BACK:= 0.46


const HANDOVER_WAIT_MS:= 1500


const HEAP_OVERLAP_ALLOW:= 0.08


const STALL_HOLD_MS:= 60000


const CATCH_HALF:= Vector3(0.86, 1.215, 0.46)
const CATCH_MID_Y:= 1.835


const FRONT_LOW:= 1.15
const FRONT_HIGH:= 3.0

const FRONT_WIDTH:= 1.91
const FRONT_Z:= 0.55
const FRONT_T:= 0.08


const META_CARRIED:= "hay_stairs_carried"


signal lowered_record(seq: int)

var live: LiveStrandManager
var props: PropManager
var placement_preview:= false

var _model: Node3D
var _belt: BeltPath
var _catch: Area3D

var _ghost_belt: BeltGhost


var _line: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()


var _carried: Array [Dictionary] = []


var _handed: RigidBody3D
var _handed_msec:= 0


var _speed:= Cfg.BELT_SPEED


var _heap_check_pending:= false

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	if placement_preview:
		set_physics_process(false)


		_ghost_belt = BeltGhost.new()
		add_child(_ghost_belt)
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)


	MachineLod.adopt(self, _model, MODEL)
	_build_line()
	_build_belt()
	_build_catch()
	_build_front()
	add_to_group("hay_stairs")
	_heap_check_pending = true


	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_follow_tech)
	_follow_tech()


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayStairs: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0

	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("HayStairs: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return HayCompressor.make_material(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("HayStairs: no table entry for %s" % ", ".join(missed.keys()))


static func spec_table() -> Dictionary:
	if not _spec_cache.is_empty():
		return _spec_cache


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_spec_cache = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_spec_cache = parsed
	return _spec_cache


func _build_line() -> void:
	var pts: Array [Vector3] = []
	var n:= 0
	while true:
		var node:= _find(N_RIDE % n) as Node3D
		if node == null:
			break
		pts.append(to_local(node.global_position))
		n += 1
	if pts.size() < 2:


		push_warning("HayStairs: no %s chain in the model; falling back to the "
			% (N_RIDE % 0) + "shedding edges alone")
		pts = [_marker(N_MOUTH, Vector3(0.0, 3.02, 0.0))]
		var fallback:= [Vector3(0.03, 2.28, 0.0), Vector3(-0.03, 1.46, 0.0),
			Vector3(0.03, 0.64, 0.0)]
		for k in STEPS:
			pts.append(_marker(N_STEP % k, fallback [k] as Vector3))
		pts.append(_marker(N_DROP, Vector3(0.395, 0.43, 0.0)))

	_line = PackedVector3Array()
	for p in pts:
		_line.append(to_global(p))
	_cum = PackedFloat32Array()
	_cum.resize(_line.size())
	_cum [0] = 0.0
	for i in range(1, _line.size()):
		_cum [i] = _cum [i - 1] + _line [i - 1].distance_to(_line [i])


func _build_belt() -> void:
	_belt = BeltPath.new()
	_belt.name = "OutfeedDeck"
	add_child(_belt)
	_belt.build_path(deck_run(), Cfg.BELT_JOINT_OVERLAP)


	_belt.records_props = true


func deck_run() -> PackedVector3Array:
	var head:= to_global(_marker(N_OUT, Vector3(0.395, 0.43, 1.55)))
	var drop:= to_global(_marker(N_DROP, Vector3(0.395, 0.43, 0.0)))
	var back:= (drop - head).normalized() * DECK_BACK
	return PackedVector3Array([drop + back, head])


func _process(_delta: float) -> void:
	if _ghost_belt == null or not is_visible_in_tree():
		return
	_ghost_belt.show_belt([deck_run()], Cfg.BELT_JOINT_OVERLAP)


func _build_catch() -> void:
	_catch = Area3D.new()
	_catch.name = "Descent"
	_catch.collision_layer = 0

	_catch.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_catch.monitorable = false
	var box:= BoxShape3D.new()
	box.size = CATCH_HALF * 2.0
	var cs:= CollisionShape3D.new()
	cs.shape = box
	_catch.add_child(cs)
	add_child(_catch)
	_catch.position = Vector3(0.0, CATCH_MID_Y, 0.0)


func _build_front() -> void:
	var body:= StaticBody3D.new()
	body.name = "FrontGuard"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var box:= BoxShape3D.new()
	box.size = Vector3(FRONT_WIDTH, FRONT_HIGH - FRONT_LOW, FRONT_T)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.position = Vector3(0.0, (FRONT_LOW + FRONT_HIGH) / 2.0, FRONT_Z)


func full_rate() -> bool:
	return true


func factory_tick(delta: float) -> void:
	if _heap_check_pending:
		_heap_check_pending = false
		_thin_restored_heap()
	_claim()
	_carry(delta)


func _claim() -> void:
	if _catch == null:
		return
	for body in _catch.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		if rb.has_meta(META_CARRIED):
			continue


		if BeltPath.is_rider(rb):
			continue


		if rb.freeze:
			continue
		if rb.linear_velocity.length() > SETTLE_SPEED:
			continue
		_take(rb)


func _take(rb: RigidBody3D) -> void:
	var at:= _nearest(rb.global_position)
	var s: float = at ["s"]


	for r in _carried:
		if absf(float(r ["s"]) - s) < RIDE_GAP:
			return
	var lift:= clampf(float(at ["lift"]), 0.0, RIDE_LIFT_MAX)


	var kind:= BeltPath.record_kind(rb)
	if kind >= 0:
		var item:= rb as Carryable
		var state:= item.to_state()
		if item.holds_needle():
			state ["needle"] = item.needle_index
		var rec:= {
			"kind": kind, "strands": item.hay_strands(), "needle": item.needle_index,
			"state": state, "seq": -1, "s": 0.0, "side": 0.0, "lift": 0.0,
			"reach": 0.0, "speed": 0.0,
		}
		var basis:= rb.global_basis.orthonormalized()
		var thud:= rb.global_position
		BeltPath.retire_body(rb, props)
		_add_record_row(rec, s, lift, basis)
		Audio.play_3d("machine_thud", thud, -11.0)
		return
	rb.set_meta(META_CARRIED, self)
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	_carried.append({
		"body": rb,
		"s": s,
		"lift": lift,

		"moved_ms": Time.get_ticks_msec(),
	})
	_sort_carried()


	Audio.play_3d("machine_thud", rb.global_position, -11.0)


func _add_record_row(rec: Dictionary, s: float, lift: float, basis: Basis) -> void:
	var draw:= BeltRunBatch.stand_in(int(rec ["kind"]), int(rec ["strands"]))
	if draw != null:
		add_child(draw)
	var row:= {
		"rec": rec,
		"s": s,
		"lift": lift,
		"moved_ms": Time.get_ticks_msec(),


		"basis": basis,
		"draw": draw,
	}
	_place_record(row, s)
	_carried.append(row)
	_sort_carried()


func _place_record(r: Dictionary, s: float) -> void:
	var at:= _point_at(s) + Vector3.UP * float(r ["lift"])
	r ["at"] = at
	var xform:= Transform3D(r ["basis"], at)
	r ["xform"] = xform
	var draw = r.get("draw")
	if draw != null and is_instance_valid(draw):
		draw.global_transform = xform


func _carry(delta: float) -> void:
	if _carried.is_empty():
		return
	var total: float = _cum [_cum.size() - 1] if _cum.size() > 0 else 0.0
	for k in range(_carried.size() - 1, -1, -1):
		var r: Dictionary = _carried [k]
		var is_record:= r.has("rec")
		var b = r.get("body")


		if not is_record and (not is_instance_valid(b) or not b.is_inside_tree() or not b.has_meta(META_CARRIED) or not b.freeze):
			_forget(k)
			continue
		var s: float = float(r ["s"]) + _speed_at(float(r ["s"])) * delta


		if k + 1 < _carried.size():
			s = maxf(minf(s, float((_carried [k + 1] as Dictionary) ["s"]) - RIDE_GAP),
				float(r ["s"]))
		if s >= total:


			if is_record:
				if _release_record(k):
					continue
			elif _drop_clear(b):
				_release(k)
				continue
			s = total
		if s > float(r ["s"]) + 0.0001:
			r ["moved_ms"] = Time.get_ticks_msec()
		r ["s"] = s
		_carried [k] = r
		if is_record:


			r ["basis"] = _turn_basis(r ["basis"], s, delta)
			_place_record(r, s)
			continue
		b.global_position = _point_at(s) + Vector3.UP * float(r ["lift"])
		_turn(b, s, delta)


		if Time.get_ticks_msec() - int(r ["moved_ms"]) < STALL_HOLD_MS:
			LiveStrandManager.hold(b)


func _turn(b: Node3D, s: float, delta: float) -> void:
	b.global_basis = _turn_basis(b.global_basis, s, delta)


func _turn_basis(have_basis: Basis, s: float, delta: float) -> Basis:
	var i:= _seg_at(s)
	var from:= _line [i]
	var to:= _line [i + 1]
	var d:= to - from
	if d.length_squared() < 1e-08:
		return have_basis
	if absf(d.y) / d.length() > RIDE_FALL_SLOPE:
		return have_basis
	var want:= Quaternion(BeltPath.run_basis(from, to))
	var have:= Quaternion(have_basis.orthonormalized())
	var rate:= RIDE_TURN_RATE * _speed / RIDE_TURN_REF
	return Basis(have.slerp(want, clampf(delta * rate, 0.0, 1.0)))


func _on_tech_changed(_id: String, _rank: int) -> void:
	_follow_tech()


func _follow_tech() -> void:
	_speed = Tech.belt_speed()


func _speed_at(s: float) -> float:
	var i:= _seg_at(s)
	var d:= _line [i + 1] - _line [i]
	if d.length_squared() < 1e-08:
		return _speed
	if absf(d.y) / d.length() > RIDE_FALL_SLOPE:
		return _speed * RIDE_FALL_GAIN
	return _speed


func _drop_clear(me: Node3D) -> bool:
	if _belt == null:
		return true
	var at:= _point_at(_cum [_cum.size() - 1])
	if not _belt.has_room_near(at):
		return false
	if not is_instance_valid(_handed) or _handed == me:
		return true
	if not _handed.is_inside_tree() or BeltPath.is_rider(_handed):
		return true
	if Time.get_ticks_msec() - _handed_msec > HANDOVER_WAIT_MS:
		return true
	return _handed.global_position.distance_to(at) >= RIDE_GAP


func _seg_at(s: float) -> int:
	var d:= clampf(s, 0.0, _cum [_cum.size() - 1])
	for i in range(_line.size() - 1):
		if d <= _cum [i + 1]:
			return i
	return maxi(0, _line.size() - 2)


func _release(k: int) -> void:
	var r: Dictionary = _carried [k]
	var b = r ["body"]
	_carried.remove_at(k)
	if not is_instance_valid(b):
		return
	b.remove_meta(META_CARRIED)
	if not b.is_inside_tree():
		return
	b.global_position = _point_at(_cum [_cum.size() - 1]) + Vector3.UP * float(r ["lift"])
	b.freeze = false
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	_handed = b
	_handed_msec = Time.get_ticks_msec()


func _release_record(k: int) -> bool:
	if _belt == null or not _belt.records_props:
		return false
	var r: Dictionary = _carried [k]
	var rec: Dictionary = r ["rec"]
	var seq:= _belt.push_record(int(rec ["kind"]), int(rec ["strands"]),
		int(rec ["needle"]), rec.get("state"), _point_at(_cum [_cum.size() - 1]), -1.0,
		RIDE_GAP, int(rec.get("seq", -1)))
	if seq < 0:
		return false
	_carried.remove_at(k)
	_free_draw(r)
	lowered_record.emit(seq)
	return true


func _free_draw(r: Dictionary) -> void:
	var draw = r.get("draw")
	if draw != null and is_instance_valid(draw):
		draw.queue_free()
	r ["draw"] = null


func _spill_record(r: Dictionary) -> void:
	if props == null or not is_instance_valid(props) or not props.is_inside_tree():
		return
	var rec: Dictionary = r ["rec"]
	var kind:= int(rec ["kind"])
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
		return
	var state: Variant = rec.get("state")
	var item:= props.spawn(BeltRun.ITEM_IDS [kind],
		Transform3D((r ["basis"] as Basis).orthonormalized(), r ["at"]),
		state if state is Dictionary else { })
	if item != null:
		LiveStrandManager.hold(item)


func _forget(k: int) -> void:
	var r: Dictionary = _carried [k]
	_carried.remove_at(k)
	if r.has("rec"):
		_free_draw(r)
		_spill_record(r)
		return
	var b = r ["body"]
	if not is_instance_valid(b) or not b.has_meta(META_CARRIED):
		return
	b.remove_meta(META_CARRIED)
	if b.is_inside_tree() and b.freeze:
		b.freeze = false
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO


func _thin_restored_heap() -> void:
	if props == null:
		return
	var inside: Array [Dictionary] = []
	var lo:= CATCH_MID_Y - CATCH_HALF.y
	for item in props.items:
		if not is_instance_valid(item):
			continue
		var c:= item as Carryable
		if c == null or not c.is_inside_tree() or c.freeze:
			continue
		var l:= to_local(c.global_position)
		if absf(l.x) > CATCH_HALF.x or absf(l.z) > CATCH_HALF.z or l.y < lo or l.y > FRONT_HIGH + 0.7:
			continue
		var box:= c.ride_box()
		if box.size == Vector3.ZERO:
			box = AABB(Vector3(-0.15, -0.15, -0.15), Vector3(0.3, 0.3, 0.3))
		inside.append({ "item": c, "y": l.y,
			"box": (c.global_transform * box).grow(- HEAP_OVERLAP_ALLOW) })
	if inside.size() < 2:
		return
	inside.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["y"]) < float(y ["y"]))
	var kept: Array [AABB] = []
	var folded:= 0
	for e in inside:
		var box: AABB = e ["box"]
		var clash:= false
		for k in kept:
			if k.intersects(box):
				clash = true
				break
		if clash:
			props.fold_away(e ["item"] as Carryable)
			folded += 1
		else:
			kept.append(box)
	if folded > 0:
		print("[hay_stairs] %s: folded %d props restored inside each other" % [name, folded])


func _sort_carried() -> void:
	_carried.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["s"]) < float(y ["s"]))


func _exit_tree() -> void:
	for k in range(_carried.size() - 1, -1, -1):
		_forget(k)


func outfeed_port() -> Vector3:
	return to_global(_marker(N_OUT, Vector3(0.395, 0.43, 1.55)))


func outfeed_forward() -> Vector3:
	var d:= outfeed_port() - to_global(_marker(N_DROP, Vector3(0.395, 0.43, 0.0)))
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-08 else global_basis.z


func deck() -> BeltPath:
	return _belt


func mouth_position() -> Vector3:
	return to_global(_marker(N_MOUTH, Vector3(0.0, 3.02, 0.0)))


func mouth_radius() -> float:
	return Cfg.HAY_STAIRS_MOUTH_RADIUS


func console_position() -> Vector3:
	return to_global(_marker(N_PANEL, Vector3(-1.075, 1.7, 0.57)))


func in_transit() -> int:
	return _carried.size()


func row_of(seq: int) -> int:
	for k in _carried.size():
		var rec: Dictionary = (_carried [k] as Dictionary).get("rec", { })
		if not rec.is_empty() and int(rec.get("seq", -1)) == seq:
			return k
	return -1


func carried_record(k: int) -> Dictionary:
	return (_carried [k] as Dictionary).get("rec", { })


func carried_transform(k: int) -> Transform3D:
	var r: Dictionary = _carried [k]
	if r.has("rec"):
		return r ["xform"]
	var b = r.get("body")
	return (b as Node3D).global_transform if is_instance_valid(b) else Transform3D.IDENTITY


func carried_count(kind: int) -> int:
	var n:= 0
	for r in _carried:
		var rec: Dictionary = (r as Dictionary).get("rec", { })
		if not rec.is_empty() and int(rec ["kind"]) == kind:
			n += 1
	return n


static func rows_to_array() -> Array:
	var out: Array = []
	var tree:= Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("hay_stairs"):
		var tower:= n as HayStairs
		if tower == null or not tower.is_inside_tree():
			continue
		var rows: Array = []
		for r in tower._carried:
			var rec: Dictionary = (r as Dictionary).get("rec", { })
			if rec.is_empty():
				continue
			var kind:= int(rec ["kind"])
			if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
				continue
			var state: Variant = rec.get("state")
			var basis:= (r ["basis"] as Basis).orthonormalized()
			rows.append({
				"kind": kind,
				"strands": int(rec ["strands"]),
				"needle": int(rec ["needle"]),
				"state": state if state is Dictionary else { },
				"s": float(r ["s"]),
				"lift": float(r ["lift"]),
				"basis": basis,
				"xform": Transform3D(basis, r ["at"]),
			})
		if not rows.is_empty():
			out.append({ "at": tower.global_position, "rows": rows })
	return out


static func rows_from_array(entries: Array, props: PropManager) -> Dictionary:
	var towers: Array [HayStairs] = []
	var tree:= Engine.get_main_loop() as SceneTree
	if tree != null:
		for n in tree.get_nodes_in_group("hay_stairs"):
			var tower:= n as HayStairs
			if tower != null and tower.is_inside_tree():
				towers.append(tower)
	var boarded:= 0
	var bodied:= 0
	var lost:= 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var at: Vector3 = d.get("at", Vector3.INF)
		var tower: HayStairs = null
		for t in towers:
			if t.global_position.distance_to(at) <= BeltPath.SAVE_END_SLACK:
				tower = t
				break
		for row in d.get("rows", []):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if tower != null and tower.restore_row(row):
				boarded += 1
			elif _body_for(row, props):
				bodied += 1
			else:
				lost += 1
	return { "boarded": boarded, "bodied": bodied, "lost": lost }


static func _body_for(row: Dictionary, props: PropManager) -> bool:
	if props == null or not (row.get("xform") is Transform3D):
		return false
	var kind:= int(row.get("kind", -1))
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
		return false
	var state: Variant = row.get("state", { })
	return props.spawn(BeltRun.ITEM_IDS [kind], row ["xform"],
		state if state is Dictionary else { }) != null


func restore_row(row: Dictionary) -> bool:
	var kind:= int(row.get("kind", -1))
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size() or _cum.size() < 2:
		return false
	var state: Variant = row.get("state", { })
	var rec:= {
		"kind": kind, "strands": int(row.get("strands", 0)),
		"needle": int(row.get("needle", -1)),
		"state": state if state is Dictionary else { }, "seq": -1,
		"s": 0.0, "side": 0.0, "lift": 0.0, "reach": 0.0, "speed": 0.0,
	}
	var basis: Variant = row.get("basis")
	_add_record_row(rec, clampf(float(row.get("s", 0.0)), 0.0, _cum [_cum.size() - 1]),
		clampf(float(row.get("lift", 0.0)), 0.0, RIDE_LIFT_MAX),
		(basis as Basis).orthonormalized() if basis is Basis else global_basis)
	return true


func _point_at(s: float) -> Vector3:
	if _line.size() < 2:
		return global_position
	var total: float = _cum [_cum.size() - 1]
	var d:= clampf(s, 0.0, total)
	for i in range(_line.size() - 1):
		if d <= _cum [i + 1] or i == _line.size() - 2:
			var span: float = _cum [i + 1] - _cum [i]
			var t: float = 0.0 if span <= 1e-06 else (d - _cum [i]) / span
			return _line [i].lerp(_line [i + 1], clampf(t, 0.0, 1.0))
	return _line [_line.size() - 1]


func _nearest(p: Vector3) -> Dictionary:
	var best_d2:= INF
	var out:= { "s": 0.0, "lift": 0.0 }
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
		out ["s"] = _cum [i] + sqrt(len2) * t
		out ["lift"] = maxf(p.y - on.y, 0.0)
	return out


func _marker(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material
	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.HAY_STAIRS_COST


func to_dict() -> Dictionary:
	return {
		"type": "hay_stairs",
		"position": global_position,
		"yaw": global_rotation.y,
	}
