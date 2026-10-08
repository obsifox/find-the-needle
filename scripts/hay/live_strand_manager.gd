class_name LiveStrandManager
extends Node3D


var field: HayField
var player_ref: Node3D

var _pool: Array [RigidBody3D] = []
var _active: Array [RigidBody3D] = []
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _phys_mat: PhysicsMaterial
var _rng:= RandomNumberGenerator.new()
var _capacity:= 0
var _next_bucket:= 0


const META_PROTECTED:= "protected"

const META_LOCAL_VISUAL:= "local_straw_visual"
var _local_visual_count:= 0
const META_COLOR:= "tint"


const META_LEN:= "len_scale"
const META_REST:= "rest_time"
const META_ARM_IGNORE_UNTIL:= "robot_arm_ignore_until"


const META_CLAIM:= "machine_claim"


const META_RIDER:= "belt_rider"


const STRAND_MASK:= (Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_STRAND | Cfg.L_TOOL
	| Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_SETTLED)
const META_HOLD_UNTIL:= "hold_until"

const HOLD_GRACE:= 1.5


const META_PINNED:= "needle_pinned"


const META_TUFT:= "clump"


const META_PIN_CHECK:= "needle_pin_check"


const FLOOR_Y:= 0.0
const SINK_TOLERANCE:= 0.01


const BURIED_DEPTH:= 1.2

const CCD_REST_TIME:= 0.5


const SUPPORT_PROBE:= 0.35

const NEEDLE_RESCUE_DROP:= 1.0


const NEEDLE_SNAP_CLEAR:= 0.006


const NEEDLE_SUNK:= 0.08


const NEEDLE_PIN_REST:= 0.4

const NEEDLE_PIN_SPEED:= 0.4


const NEEDLE_SUPPORT_CHECK:= 0.4

const NEEDLE_SUPPORT_PROBE:= 0.25


const NEEDLE_EXPOSE_INTERVAL:= 1.0


const NEEDLE_EXPOSE_MARGIN:= 0.05
var _expose_clock:= 0.0


var expose_uncovered:= true

var needles: Array [RigidBody3D] = []


func _ready() -> void:


	process_priority = 10
	_rng.randomize()
	_phys_mat = StrandFactory.hay_physics_material()
	_build_multimesh()
	_grow_pool(Cfg.live_strand_budget)
	Cfg.quality_changed.connect(_on_quality_changed)


	HayTuft.warm_up()


func _on_quality_changed(_level: int) -> void:
	if Cfg.live_strand_budget <= _capacity:
		return
	_capacity = Cfg.live_strand_budget
	_mm.instance_count = _capacity


	_mm.visible_instance_count = 0
	_grow_pool(_capacity)


func _build_multimesh() -> void:
	_capacity = Cfg.live_strand_budget
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = StrandFactory.strand_mesh()
	_mm.instance_count = _capacity
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "LiveCrust"
	_mmi.multimesh = _mm

	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


	_mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC


	_mmi.custom_aabb = AABB(Vector3(- Cfg.FIELD_EXTENT, -1, - Cfg.FIELD_EXTENT),
		Vector3(Cfg.FIELD_EXTENT * 2, Cfg.PILE_HEIGHT + 6.0, Cfg.FIELD_EXTENT * 2))
	_mm.custom_aabb = _mmi.custom_aabb
	add_child(_mmi)


func _exit_tree() -> void:


	for b in _pool:
		if is_instance_valid(b):
			b.free()
	_pool.clear()


func _grow_pool(target: int) -> void:
	while _pool.size() + _active.size() < target:


		_pool.append(_make_body(_next_bucket))
		_next_bucket = (_next_bucket + 1) % Cfg.STRAND_LEN_BUCKETS


func _make_body(bucket: int) -> RigidBody3D:
	var length:= StrandFactory.bucket_length(bucket)
	var len_scale:= length / Cfg.STRAND_LENGTH
	var b:= RigidBody3D.new()


	b.mass = Cfg.STRAND_MASS * len_scale
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = Cfg.STRAND_LINEAR_DAMP
	b.angular_damp = Cfg.STRAND_ANGULAR_DAMP
	b.physics_material_override = _phys_mat
	b.continuous_cd = false
	b.can_sleep = true
	b.max_contacts_reported = 0
	b.collision_layer = Cfg.L_STRAND
	b.collision_mask = STRAND_MASK
	var cs:= CollisionShape3D.new()
	cs.shape = StrandFactory.strand_shape(bucket)
	b.add_child(cs)
	b.set_meta(META_LEN, len_scale)
	b.set_meta(META_PROTECTED, false)
	b.set_meta(META_REST, 0.0)
	return b


func active_count() -> int:
	return _active.size()


func nearest_available_hay(center: Vector3, max_distance: float,
		min_distance: float = 0.0) -> RigidBody3D:
	var best: RigidBody3D
	var best_d2:= max_distance * max_distance
	var min_d2:= min_distance * min_distance
	var now:= Time.get_ticks_msec() * 0.001
	for body in _active:

		if body.is_inside_tree():
			var near:= body.global_position.distance_squared_to(center)
			if near < min_d2 or near >= best_d2:
				continue
		if body.get_meta(META_PROTECTED, false):
			continue
		if float(body.get_meta(META_ARM_IGNORE_UNTIL, 0.0)) > now:
			continue


		if body.has_meta(META_RIDER):
			continue
		if body.linear_velocity.length_squared() > 0.81:
			continue
		var d2:= body.global_position.distance_squared_to(center)
		if d2 < min_d2 or d2 >= best_d2:
			continue
		best_d2 = d2
		best = body
	return best


func claim_hay_near(center: Vector3, radius: float, max_count: int) -> Array [RigidBody3D]:
	var candidates: Array [RigidBody3D] = []
	var radius2:= radius * radius
	var now:= Time.get_ticks_msec() * 0.001
	for body in _active:
		if body.get_meta(META_PROTECTED, false):
			continue
		if float(body.get_meta(META_ARM_IGNORE_UNTIL, 0.0)) > now:
			continue


		if body.has_meta(META_RIDER):
			continue
		if body.global_position.distance_squared_to(center) <= radius2:
			candidates.append(body)
	candidates.sort_custom(func(a: RigidBody3D, b: RigidBody3D) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	var claimed: Array [RigidBody3D] = []
	for i in mini(max_count, candidates.size()):
		var body:= candidates [i]


		unpin(body)
		set_protected(body, true)
		claimed.append(body)
	return claimed


func has_headroom() -> bool:
	return _active.size() < Cfg.live_strand_budget


func spawn(pos: Vector3, basis: Basis, velocity: Vector3, tint: Color,
		visual_only: bool = false) -> RigidBody3D:
	var b:= _take_body()
	if b == null:
		return null
	b.set_meta(META_COLOR, tint)
	b.set_meta(META_PROTECTED, visual_only)
	b.set_meta(META_REST, 0.0)


	if b.has_meta(META_RIDER):
		b.remove_meta(META_RIDER)


	if b.has_meta(Shovel.META_LET_GO):
		b.remove_meta(Shovel.META_LET_GO)


	if b.has_meta(META_PINNED):
		b.remove_meta(META_PINNED)
	if b.has_meta(META_TUFT):
		b.remove_meta(META_TUFT)


	_poured.erase(b.get_instance_id())


	release_hold(b)
	b.collision_layer = 0 if visual_only else Cfg.L_STRAND
	if visual_only:
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	b.freeze = visual_only


	b.collision_mask = 0 if visual_only else STRAND_MASK


	b.continuous_cd = not visual_only
	add_child(b)
	if visual_only:


		PhysicsServer3D.body_set_space(b.get_rid(), RID())


	b.global_transform = Transform3D(basis.orthonormalized(), pos)
	b.linear_velocity = velocity
	b.angular_velocity = Vector3.ZERO if visual_only else Vector3(
		_rng.randfn(0.0, 2.2), _rng.randfn(0.0, 2.2), _rng.randfn(0.0, 2.2))
	b.sleeping = visual_only
	_active.append(b)
	return b


func _take_body() -> RigidBody3D:
	if not _pool.is_empty():
		return _pool.pop_back()


	var limit: int = mini(_active.size(), 32)
	for i in limit:
		var b:= _active [i]
		if not _is_held(b):


			_retire(b, false)
			return _pool.pop_back()
	return null


func spawn_from_carve(points: PackedVector3Array, count: float, base_velocity: Vector3) -> int:
	if points.is_empty():
		return 0
	var want: int = mini(int(min(count, float(Cfg.SHOVEL_MAX_SPAWN_PER_DIG))), Cfg.SHOVEL_MAX_SPAWN_PER_DIG)
	want = mini(want, Cfg.live_strand_budget - _active.size())
	var made:= 0
	for n in want:
		var p:= points [_rng.randi_range(0, points.size() - 1)]
		p += Vector3(
			_rng.randf_range(-0.5, 0.5) * Cfg.CELL,
			_rng.randf_range(-0.1, 0.1),
			_rng.randf_range(-0.5, 0.5) * Cfg.CELL)
		var v:= base_velocity + Vector3(
			_rng.randfn(0.0, 0.35), _rng.randf_range(0.0, 0.5), _rng.randfn(0.0, 0.35))
		if spawn(p, StrandFactory.random_strand_basis(_rng), v,
				StrandFactory.random_tint(_rng)) != null:
			made += 1
	return made


func spawn_plucked(xform: Transform3D, tint: Color) -> RigidBody3D:
	var b:= spawn(xform.origin, xform.basis, Vector3.ZERO, tint)
	if b != null:
		set_protected(b, true)
		set_ccd(b, true)
	return b


func is_held_by_a_tool(b: Variant) -> bool:
	return b is Object and is_instance_valid(b as Object) and bool((b as Object).get_meta(META_PROTECTED, false))


func set_protected(b: Variant, value: bool) -> void:
	if is_instance_valid(b):
		(b as Object).set_meta(META_PROTECTED, value)


static func hold(b: RigidBody3D, seconds: float = HOLD_GRACE) -> void:
	if is_instance_valid(b):
		b.set_meta(META_HOLD_UNTIL, Time.get_ticks_msec() * 0.001 + seconds)


static func release_hold(b: Object) -> void:
	if is_instance_valid(b) and b.has_meta(META_HOLD_UNTIL):
		b.remove_meta(META_HOLD_UNTIL)


static func is_on_hold(b: Object) -> bool:
	return is_instance_valid(b) and float(b.get_meta(META_HOLD_UNTIL, 0.0)) > Time.get_ticks_msec() * 0.001


static func _is_held(b: RigidBody3D) -> bool:
	if b.get_meta(META_PROTECTED, false):
		return true
	return is_on_hold(b)


func set_ccd(b: RigidBody3D, value: bool) -> void:
	if is_instance_valid(b):
		b.continuous_cd = value


func _retire(b: RigidBody3D, fold: bool) -> void:
	if not (fold and _absorb_into_pile(b)):
		GameState.return_hay(1.0)
	_despawn(b)


func _despawn(b: RigidBody3D) -> void:
	set_local_visual(b, false)
	var i:= _active.find(b)
	if i >= 0:
		_active.remove_at(i)
	if b.get_parent() == self:
		remove_child(b)


	_stranded.erase(b.get_instance_id())
	_clear_settled(b)
	_lift_apart(b)
	b.freeze = true
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.continuous_cd = false
	_pool.append(b)


func consume(b: RigidBody3D) -> bool:
	if not is_instance_valid(b) or b.get_parent() != self:
		return false
	_despawn(b)
	return true


func fold_away(b: RigidBody3D) -> bool:
	if not is_instance_valid(b) or b.get_parent() != self or b.has_meta("needle_index"):
		return false
	_retire(b, false)
	return true


func consume_needle(b: RigidBody3D) -> bool:
	var i:= needles.find(b)
	if i < 0:
		return false
	needles.remove_at(i)
	b.queue_free()
	return true


var _scan_cursor:= 0


func _absorb_into_pile(b: RigidBody3D) -> bool:
	if field == null:
		return false
	var p:= b.global_position
	var surf:= field.height_at(p.x, p.z)
	if surf < 0.05:
		return false
	if p.y > surf + 0.25:
		return false
	var c:= field.cell_at(p.x, p.z)
	if not field.in_bounds_cell(c.x, c.y):
		return false
	var rise: float = Cfg.STRAND_VOLUME / Cfg.PACKING / (Cfg.CELL * Cfg.CELL)
	var nv:= Cfg.field_verts()

	field.settle_join()
	for dj in 2:
		for di in 2:
			var i:= c.x + di
			var j:= c.y + dj
			if field.in_bounds_vert(i, j):
				field.heights [j * nv + i] += rise * 0.25
	field._touch_vertex(c.x, c.y)
	GameState.hay_total += 1.0
	return true


func _process(delta: float) -> void:
	var t:= Time.get_ticks_usec()
	_update_rest_timers(delta)
	_rescue_needles()
	_expose_needles(delta)
	_settle_needles(delta)
	HotSpots.add(&"frame straw timers and needles", t)
	t = Time.get_ticks_usec()
	_push_to_multimesh()
	HotSpots.add(&"frame straw draw", t)


func _physics_process(delta: float) -> void:
	var t:= Time.get_ticks_usec()
	_reclaim_pass()
	HotSpots.add(&"tick straw reclaim", t)
	t = Time.get_ticks_usec()
	_fold_stranded(delta)
	HotSpots.add(&"tick straw fold", t)
	t = Time.get_ticks_usec()
	_tick_tufts(delta)
	HotSpots.add(&"tick straw tufts", t)


const BUILT_FOLD:= 1.5

const BUILT_CHECK:= 0.25


const BUILT_PROBE:= 0.6


var _stranded: Dictionary = { }
var _stranded_clock:= 0.0
var _stranded_cursor:= 0
var _built_query: PhysicsRayQueryParameters3D

static var folded_stranded:= 0


static func straw_taker_of(node: Node) -> Node:
	while node != null:
		if node.has_method("straw_room"):
			return node
		node = node.get_parent()
	return null


var fold_stranded_enabled:= true

static var stranded_checks:= 0


func _fold_stranded(delta: float) -> void:
	_stranded_clock += delta
	var n:= _active.size()
	if n == 0 or not fold_stranded_enabled:
		if not _stranded.is_empty():
			_stranded.clear()
		return


	var budget: int = mini(n, maxi(8, ceili(float(n) / (BUILT_CHECK * Engine.physics_ticks_per_second))))
	var doomed: Array [RigidBody3D] = []
	for _i in budget:
		if _stranded_cursor >= _active.size():
			_stranded_cursor = 0
		var b:= _active [_stranded_cursor]
		_stranded_cursor += 1
		stranded_checks += 1
		var id:= b.get_instance_id()
		if not _is_stranded(b):
			_stranded.erase(id)
			continue
		var since: float = _stranded.get(id, -1.0)
		if since < 0.0:
			_stranded [id] = _stranded_clock
		elif _stranded_clock - since >= BUILT_FOLD:
			_stranded.erase(id)
			doomed.append(b)

	for b in doomed:
		var stand:= _stand_belt_under(b)
		if stand != null:
			if stand.call("sell_loose_strand", b):
				folded_stranded += 1
		elif fold_away(b):
			folded_stranded += 1


func _stand_belt_under(b: RigidBody3D) -> Node:
	if _built_query == null:
		return null
	var p:= b.global_position
	_built_query.from = p + Vector3.UP * 0.05
	_built_query.to = p - Vector3.UP * BUILT_PROBE
	var hit:= get_world_3d().direct_space_state.intersect_ray(_built_query)
	var node:= hit.get("collider") as Node
	while node != null:
		if node is BeltPath:
			if not (node as BeltPath).stand_belt or not BeltPath.stand_keeps_straw:
				return null
			var stand:= node.get_parent()
			return stand if stand != null and stand.has_method("sell_loose_strand") else null
		node = node.get_parent()
	return null


func _is_stranded(b: RigidBody3D) -> bool:

	if b.get_parent() != self or b.freeze or b.collision_layer != Cfg.L_STRAND or b.get_meta(META_PROTECTED, false) or b.has_meta(META_RIDER) or b.has_meta("needle_index") or b.has_meta(META_GLIDE):
		return false
	if _built_query == null:
		_built_query = PhysicsRayQueryParameters3D.new()


		_built_query.collision_mask = Cfg.L_BUILD | Cfg.L_WORLD | Cfg.L_PILE
		_built_query.collide_with_areas = false
	var p:= b.global_position

	_built_query.from = p + Vector3.UP * 0.05
	_built_query.to = p - Vector3.UP * BUILT_PROBE
	var hit:= get_world_3d().direct_space_state.intersect_ray(_built_query)
	if hit.is_empty():
		return false
	var col:= hit.get("collider") as CollisionObject3D
	if col == null or not (col.collision_layer & Cfg.L_BUILD) or _is_deck(col):
		return false
	var node: Node = col
	while node != null:


		if node is ConveyorSplitter or node is ConveyorJoiner:
			return false
		if node is BeltPath:


			if (node as BeltPath).stand_belt and BeltPath.stand_keeps_straw:
				return not is_on_hold(b)
			if (node as BeltPath).gathers_straw:
				return false
			break
		node = node.get_parent()
	var taker:= straw_taker_of(col)
	if taker != null:


		return int(taker.call("straw_room")) <= 0

	return not b.sleeping and not is_on_hold(b)


func _rescue_needles() -> void:
	for b in needles:
		if not is_instance_valid(b):
			continue


		if (b.freeze and not is_pinned(b)) or b.has_meta(META_RIDER) or _is_held(b):
			continue
		var p:= b.global_position
		if p.y < FLOOR_Y - NEEDLE_RESCUE_DROP:
			_put_back(b, p)
			continue
		if field == null:
			continue


		if p.y >= field.depth_floor_at(p.x, p.z) - NEEDLE_SUNK:
			continue
		if _on_built_surface(p):
			continue
		_put_back(b, p)


func _expose_needles(delta: float) -> int:
	if not expose_uncovered:
		return 0
	_expose_clock += delta
	if _expose_clock < NEEDLE_EXPOSE_INTERVAL:
		return 0
	_expose_clock = 0.0
	return expose_uncovered_needles()


func expose_uncovered_needles() -> int:
	if field == null:
		return 0
	var surfaced:= 0
	for idx in GameState.needle_positions.size():
		if GameState.needle_taken [idx] == 1:
			continue
		var p:= GameState.needle_positions [idx]
		if p.y <= field.height_at(p.x, p.z) + NEEDLE_EXPOSE_MARGIN:
			continue
		var body:= reveal_needle(idx, p)
		GameState.needle_taken [idx] = 1
		if body != null:
			surfaced += 1
			Audio.play_3d("needle_ting", p, -10.0)
	return surfaced


func _put_back(b: RigidBody3D, at: Vector3) -> void:
	unpin(b)
	var x:= clampf(at.x, - Cfg.FIELD_EXTENT, Cfg.FIELD_EXTENT)
	var z:= clampf(at.z, - Cfg.FIELD_EXTENT, Cfg.FIELD_EXTENT)


	var spot:= Vector3(x, (field.height_at(x, z) if field != null else 0.0)
		+ NEEDLE_SNAP_CLEAR, z)
	b.global_position = spot
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	pin_needle(b)


func _update_rest_timers(delta: float) -> void:
	var lost: Array [RigidBody3D] = []
	var settling: Array [RigidBody3D] = []
	for b in _active:


		if b.collision_layer != Cfg.L_STRAND:
			if b.freeze:
				continue


			_clear_settled(b)


		if b.freeze:
			b.set_meta(META_REST, 0.0)
		elif b.sleeping or b.linear_velocity.length_squared() < 0.01 or (settle_enabled and _staying_put(b)):
			var rest:= float(b.get_meta(META_REST, 0.0)) + delta
			b.set_meta(META_REST, rest)


			if rest > CCD_REST_TIME and b.continuous_cd and not settle_enabled:
				b.continuous_cd = false
			if rest >= Cfg.STRAND_SLEEP_AFTER and settle_enabled:
				settling.append(b)
		else:
			b.set_meta(META_REST, 0.0)
		if _is_lost(b):
			lost.append(b)
		if settle_enabled and not b.freeze:
			_track_rest_spot(b)

	for b in lost:
		_retire(b, true)


	var still: Array [RigidBody3D] = []
	for b in settling:
		if b.get_parent() == self:
			still.append(b)
	settling = still


	if settling.size() > 1:
		settling.sort_custom(func(x: RigidBody3D, y: RigidBody3D) -> bool:
			return x.global_position.y < y.global_position.y)
	for b in settling:
		if b.get_parent() == self:
			_try_settle(b, delta)


func _is_lost(b: RigidBody3D) -> bool:
	if b.get_meta(META_PROTECTED, false):
		return false
	if b.has_meta(META_RIDER):
		return false
	var p:= b.global_position
	if p.y < FLOOR_Y - SINK_TOLERANCE:
		return true
	if field == null:
		return false


	if p.y >= field.depth_floor_at(p.x, p.z) - BURIED_DEPTH:
		return false


	return not _on_built_surface(p)


func _on_built_surface(p: Vector3) -> bool:


	var from:= p + Vector3(0, Cfg.STRAND_LEN_MAX * 0.5, 0)
	var q:= PhysicsRayQueryParameters3D.create(from, p + Vector3(0, - SUPPORT_PROBE, 0))
	q.collision_mask = Cfg.L_BUILD | Cfg.L_PROP
	q.collide_with_areas = false
	q.hit_from_inside = true
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _reclaim_pass() -> void:
	var n:= _active.size()
	if n == 0:
		return

	var here:= player_ref.global_position if is_instance_valid(player_ref) else Vector3.ZERO
	var over: int = n - _local_visual_count - Cfg.LIVE_SOFT_CAP
	if over > 0:


		var budget: int = clampi(over / 8, 8, 32)


		var retired:= _drain(budget, here, Cfg.STRAND_KEEP_DIST)
		if retired < budget:
			_drain(budget - retired, here, 0.0)
		return

	var despawn_d2: float = Cfg.STRAND_DESPAWN_DIST * Cfg.STRAND_DESPAWN_DIST
	var doomed: Array [RigidBody3D] = []
	for _i in mini(96, n):
		if _scan_cursor >= _active.size():
			_scan_cursor = 0
		var b:= _active [_scan_cursor]
		_scan_cursor += 1
		if _is_held(b):
			continue
		if float(b.get_meta(META_REST, 0.0)) < Cfg.STRAND_RECLAIM_REST:
			continue
		if b.global_position.distance_squared_to(here) < despawn_d2:
			continue
		doomed.append(b)
		if doomed.size() >= 6:
			break
	for b in doomed:
		_retire(b, true)


func drain_to(ceiling: int, budget: int) -> int:


	var over: int = _active.size() - _gliding.size() - _local_visual_count - ceiling
	if over <= 0 or budget <= 0:
		return 0
	var want: int = mini(over, budget)
	var here:= player_ref.global_position if is_instance_valid(player_ref) else Vector3.ZERO
	var took:= _drain(want, here, Cfg.STRAND_KEEP_DIST)
	if took < want:
		took += _drain(want - took, here, 0.0)
	return took


func sweep_floor() -> int:
	var took:= 0

	for b in _active.duplicate():
		if not is_instance_valid(b):
			continue
		if _is_held(b) or b.has_meta(META_GLIDE) or b.has_meta(META_RIDER):
			continue
		_retire(b, float(b.get_meta(META_REST, 0.0)) >= Cfg.STRAND_RECLAIM_REST)
		took += 1
	return took


func _drain(budget: int, here: Vector3, keep: float) -> int:
	var keep2:= keep * keep
	var retired:= 0
	var i:= 0
	while retired < budget and i < _active.size():
		var b:= _active [i]


		if _is_held(b) or b.has_meta(META_GLIDE) or _poured.has(b.get_instance_id()) or (keep2 > 0.0 and b.global_position.distance_squared_to(here) < keep2):
			i += 1
			continue


		_retire(b, float(b.get_meta(META_REST, 0.0)) >= Cfg.STRAND_RECLAIM_REST)
		retired += 1
	return retired


func set_local_visual(body: RigidBody3D, enabled: bool) -> void:
	if body.has_meta(META_LOCAL_VISUAL) == enabled:
		return
	_local_visual_count += 1 if enabled else -1
	if enabled:
		body.set_meta(META_LOCAL_VISUAL, true)
	else:
		body.remove_meta(META_LOCAL_VISUAL)


static func draw_alpha(b: Object) -> float:
	return 0.0 if b.get_meta(META_PROTECTED, false) else 1.0


func _push_to_multimesh() -> void:
	var shifting:= not _load_shifts.is_empty()
	if shifting or not _shifted_wads.is_empty():
		_shift_wads()
	var n: int = mini(_active.size(), _capacity)
	if _drawn.size() != _capacity:
		_drawn.resize(_capacity)
		_drawn.fill(0)
		_drawn_at.resize(_capacity)
		_drawn_at.fill(Vector3.ZERO)
	var lo:= Vector3.INF
	var hi:= - Vector3.INF
	for i in n:
		var b:= _active [i]


		var id:= b.get_instance_id()
		if b.has_meta(META_LOCAL_VISUAL):
			if _drawn [i] != - id:
				_mm.set_instance_transform(i, HayChunk.PARKED_XFORM)
				_drawn [i] = - id
			continue
		if _drawn [i] == id and b.collision_layer == Cfg.L_SETTLED:
			var at:= _drawn_at [i]
			lo = lo.min(at)
			hi = hi.max(at)
			continue
		_drawn [i] = id


		var xf:= b.get_global_transform_interpolated()


		var alpha:= draw_alpha(b)
		if shifting and alpha == 0.0:
			for ride: Array in _load_shifts:
				if (ride [0] as Dictionary).has(id):
					xf = (ride [1] as Transform3D) * xf


					_drawn [i] = 0
					break

		xf.basis.z *= float(b.get_meta(META_LEN, 1.0))
		_mm.set_instance_transform(i, xf)
		_drawn_at [i] = xf.origin
		lo = lo.min(xf.origin)
		hi = hi.max(xf.origin)


		var tint: Color = b.get_meta(META_COLOR, Color.WHITE)
		tint.a = alpha
		_mm.set_instance_color(i, tint)
	_mm.visible_instance_count = n
	if lo.is_finite():
		var pad:= Vector3.ONE * (Cfg.STRAND_LEN_MAX * 0.5)


		var box: AABB = _mmi.global_transform.affine_inverse() * AABB(lo - pad, hi - lo + pad * 2.0)


		if not box.is_equal_approx(_mmi.custom_aabb):
			_mmi.custom_aabb = box
			_mm.custom_aabb = box


	_load_shifts.clear()


var _load_shifts: Array = []


var _shifted_wads: Dictionary = { }


func draw_load_shifted(bodies: Dictionary, shift: Transform3D) -> void:
	if not bodies.is_empty():
		_load_shifts.append([bodies, shift])


func _shift_wads() -> void:
	var now: Dictionary = { }
	for ride: Array in _load_shifts:
		var shift:= ride [1] as Transform3D
		var bodies:= ride [0] as Dictionary
		for id: int in bodies:
			var w: Variant = bodies [id]
			if is_instance_valid(w) and w is HayWad:
				(w as HayWad).draw_shifted(shift)
				now [id] = w
	for id: int in _shifted_wads:
		if not now.has(id):
			var w: Variant = _shifted_wads [id]
			if is_instance_valid(w):
				(w as HayWad).draw_shifted(Transform3D.IDENTITY)
	_shifted_wads = now


func reveal_needle(index: int, pos: Vector3) -> RigidBody3D:
	if index >= 0:
		for existing in needles:
			if not is_instance_valid(existing):
				continue
			if int(existing.get_meta("needle_index", -1)) == index:
				push_warning("LiveStrandManager: needle %d is already in the world"
					% index)
				return null
	var b:= RigidBody3D.new()
	b.mass = 0.004
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.6
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 1.2
	b.collision_layer = Cfg.L_STRAND
	b.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_TOOL | Cfg.L_BUILD | Cfg.L_PROP
	b.physics_material_override = _phys_mat


	b.continuous_cd = true


	var type:= GameState.type_of(index)
	var cs:= CollisionShape3D.new()
	var sh:= BoxShape3D.new()
	sh.size = StrandFactory.needle_extents(type) * 2.0
	cs.shape = sh
	b.add_child(cs)
	var mi:= MeshInstance3D.new()
	mi.mesh = StrandFactory.needle_model(type)


	mi.transform = StrandFactory.needle_visual_xform(type)


	var mats:= StrandFactory.needle_surface_materials(type)
	for s in mats.size():
		mi.set_surface_override_material(s, mats [s])
	b.add_child(mi)
	b.set_meta("needle_index", index)
	b.set_meta("needle_type", type)
	add_child(b)
	b.global_position = pos
	b.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
	needles.append(b)
	return b


func reveal_needles_in(center: Vector3, radius: float,
		landing: Callable = Callable(),
		out: Array [RigidBody3D] = []) -> int:


	var lifted:= 0
	if landing.is_valid():
		lifted += lift_loose_needles_in(center, radius, landing, out)
	else:
		wake_needles_in(center, radius + 0.5)


	var search:= radius * Tech.needle_reveal_scale()
	for idx in GameState.needles_in_sphere(center, search):
		var at:= GameState.needle_positions [idx] + Vector3(0, 0.06, 0)
		if landing.is_valid():
			at = landing.call()
		var body:= reveal_needle(idx, at)
		GameState.needle_taken [idx] = 1


		if landing.is_valid() and body != null:
			hold(body)
		if body != null:
			out.append(body)
		lifted += 1
	return lifted


func lift_loose_needles_in(center: Vector3, radius: float, landing: Callable,
		out: Array [RigidBody3D] = []) -> int:
	if not landing.is_valid():
		return 0
	var loose: Array [RigidBody3D] = []
	var r2:= radius * radius
	for b in needles:
		if not is_instance_valid(b):
			continue
		if b.freeze and not is_pinned(b):
			continue
		if b.get_meta(META_PROTECTED, false) or b.has_meta(META_RIDER):
			continue
		if b.global_position.distance_squared_to(center) <= r2:
			loose.append(b)


	wake_needles_in(center, radius + 0.5)
	for b in loose:


		b.global_position = landing.call()
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		b.sleeping = false
		hold(b)
		out.append(b)
	return loose.size()


const NEEDLE_HEADROOM:= 0.25


const NEEDLE_FLOOR:= 0.06


func settle_buried_needles(scale: float) -> Dictionary:
	var out:= { "sunk": 0, "surfaced": 0 }
	if field == null:
		return out
	for i in GameState.needle_positions.size():
		if i >= GameState.needle_taken.size() or GameState.needle_taken [i] != 0:
			continue
		var p:= GameState.needle_positions [i]
		var room:= field.depth_floor_at(p.x, p.z) - NEEDLE_HEADROOM
		if room < NEEDLE_FLOOR:
			var at:= Vector3(p.x, field.height_at(p.x, p.z) + NEEDLE_HEADROOM, p.z)
			reveal_needle(i, at)
			GameState.needle_positions [i] = at
			GameState.needle_taken [i] = 1
			out ["surfaced"] = int(out ["surfaced"]) + 1
			continue
		var y:= clampf(p.y * scale, NEEDLE_FLOOR, room)
		if not is_equal_approx(y, p.y):
			GameState.needle_positions [i] = Vector3(p.x, y, p.z)
			out ["sunk"] = int(out ["sunk"]) + 1
	return out


static func is_pinned(rb: RigidBody3D) -> bool:
	return is_instance_valid(rb) and bool(rb.get_meta(META_PINNED, false))


static func unpin(rb: RigidBody3D) -> void:
	if not is_pinned(rb):
		return
	_clear_settled(rb)
	rb.remove_meta(META_PINNED)
	rb.set_meta(META_REST, 0.0)


	rb.set_meta(META_PIN_CHECK, 0.0)
	rb.freeze = false


	rb.continuous_cd = true
	rb.sleeping = false


func pin_needle(b: RigidBody3D) -> void:
	if not is_instance_valid(b) or b.freeze:
		return
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	b.freeze = true
	b.continuous_cd = false
	b.set_meta(META_PINNED, true)
	b.set_meta(META_PIN_CHECK, NEEDLE_SUPPORT_CHECK)


func loose_undiscovered_types() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for b in needles:
		if not is_instance_valid(b):
			continue
		if not b.has_meta("needle_index"):
			continue
		var type:= GameState.type_of(int(b.get_meta("needle_index")))
		if GameState.is_discovered(type):
			continue
		out.append(type)
	return out


func nearest_available_needle(center: Vector3, max_distance: float,
		min_distance: float = 0.0, by_id: int = 0) -> RigidBody3D:
	var best: RigidBody3D
	var best_d2:= max_distance * max_distance
	var min_d2:= min_distance * min_distance
	var now:= Time.get_ticks_msec() * 0.001
	for b in needles:
		if not is_instance_valid(b):
			continue


		if b.is_inside_tree():
			var near:= b.global_position.distance_squared_to(center)
			if near < min_d2 or near >= best_d2:
				continue

		if b.get_meta(META_PROTECTED, false):
			continue


		if float(b.get_meta(META_ARM_IGNORE_UNTIL, 0.0)) > now:
			continue

		if b.has_meta(META_RIDER):
			continue
		if b.freeze and not is_pinned(b):
			continue
		if by_id != 0 and _claimed_elsewhere(b, by_id):
			continue


		if b.linear_velocity.length_squared() > 0.81:
			continue
		var d2:= b.global_position.distance_squared_to(center)
		if d2 < min_d2 or d2 >= best_d2:
			continue
		best_d2 = d2
		best = b
	return best


static func _claimed_elsewhere(b: Object, by_id: int) -> bool:
	if not b.has_meta(META_CLAIM):
		return false
	var owner_id:= int(b.get_meta(META_CLAIM))
	if owner_id == by_id:
		return false
	var owner:= instance_from_id(owner_id)
	return owner != null and is_instance_valid(owner)


func wake_needles_in(center: Vector3, radius: float) -> void:
	var r2:= radius * radius
	for b in needles:
		if is_pinned(b) and b.global_position.distance_squared_to(center) <= r2:
			unpin(b)


func _settle_needles(delta: float) -> void:
	for b in needles:
		if not is_instance_valid(b):
			continue
		if is_pinned(b):
			if _due(b, delta) and not _has_support(b):
				unpin(b)
			continue


		if b.freeze:
			b.set_meta(META_REST, 0.0)
			continue


		if _is_held(b):
			b.set_meta(META_REST, 0.0)
			continue
		if b.linear_velocity.length_squared() > NEEDLE_PIN_SPEED * NEEDLE_PIN_SPEED:
			b.set_meta(META_REST, 0.0)
			continue
		var rest:= float(b.get_meta(META_REST, 0.0)) + delta
		b.set_meta(META_REST, rest)
		if rest < NEEDLE_PIN_REST:
			continue


		if _due(b, delta) and _has_support(b):
			pin_needle(b)


func _due(b: RigidBody3D, delta: float, every: float = NEEDLE_SUPPORT_CHECK) -> bool:
	var left:= float(b.get_meta(META_PIN_CHECK, 0.0)) - delta
	if left > 0.0:
		b.set_meta(META_PIN_CHECK, left)
		return false
	b.set_meta(META_PIN_CHECK, every)
	return true


func _has_support(b: RigidBody3D) -> bool:
	var p:= b.global_position
	var q:= PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.05, 0),
		p + Vector3(0, - NEEDLE_SUPPORT_PROBE, 0))


	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_SETTLED
	q.collide_with_areas = false
	q.hit_from_inside = true
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


var settle_enabled:= true

var tufts_enabled:= true


var props: PropManager


const SETTLE_PROBE:= 0.04


const WAIT_PROBE:= SETTLE_PROBE + 0.01


const SETTLE_FLAT:= 0.7


const SETTLE_RETRY:= 0.1

const CLUMP_MEMBER_CHECKS:= 3


const META_GLIDE:= "tuft_glide"


class Clump:
	var id:= 0

	var centre:= Vector3.ZERO
	var cell:= Vector2i.ZERO
	var members: Array [RigidBody3D] = []


class Merge:
	var xf:= Transform3D.IDENTITY
	var waiting:= 0
	var arrived:= 0

	var let_go:= 0.0


var _clumps: Dictionary = { }
var _clump_cells: Dictionary = { }
var _next_clump:= 1


var _clock:= 0.0

var _drawn:= PackedInt64Array()


var _drawn_at:= PackedVector3Array()
var _loose_query:= PhysicsShapeQueryParameters3D.new()


var _gliding: Dictionary = { }

var _new_tufts: Array = []

var _incoming: Dictionary = { }

var _test_shapes: Dictionary = { }
var _sweep: Array = []
var _hooked_field: HayField


func settled_count() -> int:
	var n:= 0
	for b in _active:
		if is_pinned(b):
			n += 1
	return n


func tuft_sizes() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for t in HayTuft.all:
		if is_instance_valid(t):
			out.append(t.strands)
	return out


func clump_sizes() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for id: int in _clumps.keys():
		var n:= _prune_clump(_clumps [id])
		if n > 0:
			out.append(n)
	return out


func gliding_count() -> int:
	return _gliding.size()


func wake_in(center: Vector3, radius: float) -> int:
	if _clumps.is_empty():
		return 0
	var reach:= radius + Cfg.STRAND_LEN_MAX * 0.5 + Cfg.TUFT_RADIUS
	var c:= _cell_of(center)
	var span:= int(ceil(reach / Cfg.CELL))
	var woke:= 0
	for dj in range(- span, span + 1):
		for di in range(- span, span + 1):
			var key:= c + Vector2i(di, dj)
			if not _clump_cells.has(key):
				continue
			for id: int in (_clump_cells [key] as Array).duplicate():
				var k: Clump = _clumps.get(id)
				if k != null and k.centre.distance_squared_to(center) <= reach * reach:
					woke += _wake_clump(k)
	return woke


func _try_settle(b: RigidBody3D, delta: float) -> void:
	if b.freeze or _is_held(b) or b.has_meta(META_RIDER):
		return


	if b.collision_mask != STRAND_MASK:
		return
	if (b.linear_velocity.length_squared() > Cfg.STRAND_REST_SPEED * Cfg.STRAND_REST_SPEED
			or b.angular_velocity.length_squared() > Cfg.STRAND_REST_SPIN * Cfg.STRAND_REST_SPIN) and not _staying_put(b):
		return


	if not _due(b, delta, SETTLE_RETRY):
		return


	if tufts_enabled and props != null:
		var tuft:= _tuft_taking(b.global_position)
		if tuft != null:
			_glide(b, tuft)
			return
	var hit:= _lying_on(b, SETTLE_PROBE, true)
	if hit.is_empty():
		return
	_settle(b, hit)


const META_REST_AT:= "rest_at"


const REST_DRIFT:= 0.005


func _staying_put(b: RigidBody3D) -> bool:
	return b.has_meta(META_REST_AT) and (b.get_meta(META_REST_AT) as Vector3).distance_squared_to(b.global_position) <= REST_DRIFT * REST_DRIFT


func _track_rest_spot(b: RigidBody3D) -> void:
	if not _staying_put(b):
		b.set_meta(META_REST_AT, b.global_position)


func _lying_on(b: RigidBody3D, depth: float, loose_blocks: bool) -> Dictionary:
	var self_rid: Array [RID] = [b.get_rid()]
	var half:= b.global_basis.z.normalized() * (_strand_length(b) * 0.4)
	var p:= b.global_position
	for at: Vector3 in [p, p - half, p + half]:
		var hit:= _support_under(at, self_rid, depth, loose_blocks)
		if not hit.is_empty():
			return hit
	return { }


func _support_under(p: Vector3, exclude: Array [RID], depth: float,
		loose_blocks: bool) -> Dictionary:


	var q:= PhysicsRayQueryParameters3D.create(p + Vector3(0, Cfg.STRAND_THICK * 0.5, 0),
		p - Vector3(0, depth, 0))


	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_SETTLED | (Cfg.L_STRAND if loose_blocks else 0)
	q.collide_with_areas = false
	q.hit_from_inside = true
	q.exclude = exclude
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return { }
	var col:= hit.get("collider") as CollisionObject3D
	if col == null:
		return { }
	return hit if _is_ground(col, hit ["normal"] as Vector3) else { }


func _is_ground(col: CollisionObject3D, normal: Vector3) -> bool:
	var layer:= col.collision_layer
	if layer & (Cfg.L_PILE | Cfg.L_SETTLED):
		return true


	if col is HayTuft:
		return normal.y >= SETTLE_FLAT and not (col as HayTuft).is_held() and not (col as HayTuft).freeze
	if layer & (Cfg.L_PROP | Cfg.L_STRAND):
		return false
	if normal.y < SETTLE_FLAT:
		return false
	if layer & Cfg.L_BUILD:
		return _is_deck(col)
	return layer & Cfg.L_WORLD != 0 and not _rides_a_vehicle(col)


static func _is_deck(col: Node) -> bool:
	return col is Platform


static func _rides_a_vehicle(col: Node) -> bool:
	var n:= col
	for i in 4:
		if n == null:
			return false
		if n is DeliveryTruck:
			return true
		n = n.get_parent()
	return false


func _settle(b: RigidBody3D, hit: Dictionary) -> void:
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO


	b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	b.freeze = true
	b.continuous_cd = false
	b.collision_layer = Cfg.L_SETTLED

	b.collision_mask = Cfg.L_STRAND
	b.set_meta(META_PINNED, true)


	b.set_meta(META_REST, maxf(float(b.get_meta(META_REST, 0.0)), Cfg.STRAND_RECLAIM_REST))
	_join_clump(b)


func _join_clump(b: RigidBody3D) -> void:
	var p:= b.global_position
	var k:= _nearest_clump(p)
	if k == null:
		k = Clump.new()
		k.id = _next_clump
		_next_clump += 1
		k.centre = p
		k.cell = _cell_of(p)
		_clumps [k.id] = k
		_list_clump(k)
	else:


		var n:= float(k.members.size())
		k.centre = (k.centre * n + p) / (n + 1.0)
		var cell:= _cell_of(k.centre)
		if cell != k.cell:
			_unlist_clump(k)
			k.cell = cell
			_list_clump(k)
	k.members.append(b)
	b.set_meta(META_TUFT, k.id)
	if tufts_enabled and props != null and k.members.size() >= Cfg.TUFT_MERGE_AT:
		_merge(k)


func _nearest_clump(p: Vector3) -> Clump:
	var best: Clump = null
	var best_d2:= Cfg.TUFT_RADIUS * Cfg.TUFT_RADIUS
	var c:= _cell_of(p)
	var span:= int(ceil(Cfg.TUFT_RADIUS / Cfg.CELL))
	for dj in range(- span, span + 1):
		for di in range(- span, span + 1):
			var key:= c + Vector2i(di, dj)
			if not _clump_cells.has(key):
				continue
			for id: int in (_clump_cells [key] as Array).duplicate():
				var k: Clump = _clumps.get(id)
				if k == null or absf(p.y - k.centre.y) > Cfg.TUFT_STEP:
					continue
				var flat:= Vector2(p.x - k.centre.x, p.z - k.centre.z).length_squared()
				if flat > best_d2 or _prune_clump(k) <= 0:
					continue
				best_d2 = flat
				best = k
	return best


func _merge(k: Clump) -> void:
	if _prune_clump(k) < Cfg.TUFT_MERGE_AT:
		return
	var members:= k.members.duplicate()
	if _merge_straw(members) != null:
		_drop_clump(k)


func _merge_straw(members: Array, spread:= false) -> Merge:
	var centre:= Vector3.ZERO
	var grain:= Vector2.ZERO
	for member: RigidBody3D in members:
		centre += member.global_position


		var z:= member.global_basis.z
		var a:= atan2(z.x, z.z) * 2.0
		grain += Vector2(cos(a), sin(a))
	centre /= float(members.size())
	var yaw:= atan2(grain.y, grain.x) * 0.5

	var basis:= Basis(Vector3.UP, yaw - PI * 0.5)
	var ground:= _pour_spot(centre, basis) if spread else { }
	if ground.is_empty():
		ground = _ground_under(centre)
	if ground.is_empty():
		return null
	var merge:= Merge.new()
	merge.xf = Transform3D(basis, (ground ["position"] as Vector3) + Vector3.UP * 0.005)
	for b: RigidBody3D in members:
		merge.waiting += 1
		_glide(b, merge)
	if spread:
		_merging.append(merge)
	return merge


var _poured: Dictionary = { }


var _merging: Array [Merge] = []
var _pour_gather_left:= 0.0


const POUR_FRESH:= 3.0


const POUR_LANDED_SPEED:= 0.8

const POUR_GATHER_EVERY:= 0.05

const POUR_SPAN:= Cfg.TUFT_RADIUS


const POUR_RISE:= 0.3


func mark_poured(b: RigidBody3D) -> void:
	if is_instance_valid(b):
		_poured [b.get_instance_id()] = [b, _clock]


func _gather_poured(delta: float) -> void:
	for i in range(_merging.size() - 1, -1, -1):
		if _merging [i].waiting <= 0:
			_merging.remove_at(i)
	if _poured.is_empty():
		return
	_pour_gather_left -= delta
	if _pour_gather_left > 0.0:
		return
	_pour_gather_left = POUR_GATHER_EVERY
	var gather:= settle_enabled and tufts_enabled and props != null
	var landed: Array [RigidBody3D] = []
	for id: int in _poured.keys():
		var rec: Array = _poured [id]
		var b: Variant = rec [0]
		if not is_instance_valid(b) or (b as Node).get_parent() != self or _clock - float(rec [1]) > POUR_FRESH:
			_poured.erase(id)
			continue
		var rb:= b as RigidBody3D


		if rb.freeze or rb.has_meta(META_RIDER):
			_poured.erase(id)
			continue


		if not gather or _is_held(rb) or rb.collision_mask != STRAND_MASK or rb.linear_velocity.length_squared() > POUR_LANDED_SPEED * POUR_LANDED_SPEED:
			continue
		landed.append(rb)
	if landed.is_empty():
		return
	var loose: Array [RigidBody3D] = []
	for b in landed:
		var p:= b.global_position


		var into: Variant = _pour_taking(p)
		if into == null:
			pass
		elif into is Merge:
			_poured.erase(b.get_instance_id())
			(into as Merge).waiting += 1
			_glide(b, into)
			continue
		else:
			_poured.erase(b.get_instance_id())
			_glide(b, into)
			continue


		if _ground_under(p).is_empty():
			continue
		loose.append(b)
	if loose.size() < Cfg.TUFT_MERGE_AT:
		return
	_group_poured(loose)


func _group_poured(loose: Array [RigidBody3D]) -> void:
	var cells: Dictionary = { }
	for b in loose:
		var p:= b.global_position
		var key:= Vector2i(int(floor(p.x / POUR_SPAN)), int(floor(p.z / POUR_SPAN)))
		var list: Array = cells.get(key, [])
		list.append(b)
		cells [key] = list
	var order: Array = cells.keys()
	order.sort_custom(func(x: Vector2i, y: Vector2i) -> bool:
		return (cells [x] as Array).size() > (cells [y] as Array).size())
	var taken: Dictionary = { }
	for key: Vector2i in order:
		var centre:= Vector3.ZERO
		var n:= 0
		for b: RigidBody3D in cells [key]:
			if not taken.has(b):
				centre += b.global_position
				n += 1
		if n == 0:
			continue
		centre /= float(n)
		var group: Array = []
		for dj in range(-1, 2):
			for di in range(-1, 2):
				for b: RigidBody3D in cells.get(key + Vector2i(di, dj), []):
					if group.size() >= Cfg.TUFT_MAX or taken.has(b):
						continue
					var p:= b.global_position
					if Vector2(p.x - centre.x, p.z - centre.z).length() <= POUR_SPAN and absf(p.y - centre.y) <= POUR_RISE:
						group.append(b)
		if group.size() < Cfg.TUFT_MERGE_AT:
			continue
		if _merge_straw(group, true) == null:
			continue
		for b: RigidBody3D in group:
			taken [b] = true
			_poured.erase(b.get_instance_id())


const POUR_SPREAD:= 1.0

const POUR_RING_STEP:= 0.3


func _pour_spot(centre: Vector3, basis: Basis) -> Dictionary:
	var under:= _floor_under(centre)
	if under.is_empty():
		return { }
	var base:= (under ["position"] as Vector3).y
	var size:= HayTuft.full_collider_size()
	var ring:= 0
	var r:= 0.0
	while r <= POUR_SPREAD:
		var n:= 1 if ring == 0 else 6 * ring
		var turn:= _rng.randf() * TAU
		for i in n:
			var a:= turn + TAU * float(i) / float(n)
			var hit:= _floor_under(Vector3(centre.x + cos(a) * r, base, centre.z + sin(a) * r))
			if hit.is_empty():
				continue
			var at:= hit ["position"] as Vector3
			if absf(at.y - base) <= POUR_RISE and _tuft_fits(at, basis, size):
				return hit
		ring += 1
		r += POUR_RING_STEP
	return { }


func free_floor_near(centre: Vector3, basis: Basis) -> Dictionary:
	return _pour_spot(centre, basis)


func _floor_under(p: Vector3) -> Dictionary:
	var q:= PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p - Vector3.UP * 1.0)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return { }
	var col:= hit.get("collider") as CollisionObject3D
	if col == null or not _is_ground(col, hit ["normal"] as Vector3):
		return { }
	return hit


var _fit_query: PhysicsShapeQueryParameters3D


func _tuft_fits(at: Vector3, basis: Basis, size: Vector3) -> bool:
	var reach:= maxf(size.x, size.z)
	for m in _merging:
		if m.waiting > 0 and Vector2(at.x - m.xf.origin.x, at.z - m.xf.origin.z).length() < reach:
			return false
	if _fit_query == null:
		_fit_query = PhysicsShapeQueryParameters3D.new()
		_fit_query.shape = BoxShape3D.new()
		_fit_query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
		_fit_query.collide_with_areas = false
	(_fit_query.shape as BoxShape3D).size = size

	_fit_query.transform = Transform3D(basis, at + Vector3.UP * (size.y * 0.5 + 0.02))
	return get_world_3d().direct_space_state.intersect_shape(_fit_query, 1).is_empty()


func _pour_taking(p: Vector3) -> Variant:
	var best: Variant = null
	var best_d:= POUR_SPREAD
	for m in _merging:
		if m.waiting <= 0 or m.waiting + m.arrived >= Cfg.TUFT_MAX:
			continue
		var at:= m.xf.origin
		var d:= Vector2(p.x - at.x, p.z - at.z).length()
		if absf(p.y - at.y) <= POUR_RISE and d <= best_d:
			best_d = d
			best = m
	for t in HayTuft.all:
		if not is_instance_valid(t) or not t.takes_straw() or _room_in(t) <= 0:
			continue
		var at:= t.global_position
		var d:= Vector2(p.x - at.x, p.z - at.z).length()
		if absf(p.y - at.y) <= POUR_RISE and d <= best_d:
			best_d = d
			best = t
	return best


func _ground_under(p: Vector3) -> Dictionary:
	var q:= PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.15, p - Vector3.UP * 0.5)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PROP
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return { }
	var col:= hit.get("collider") as CollisionObject3D
	if col == null or not _is_ground(col, hit ["normal"] as Vector3):
		return { }
	return hit


func _prune_clump(k: Clump) -> int:
	for i in range(k.members.size() - 1, -1, -1):
		var m: Variant = k.members [i]
		if is_instance_valid(m) and (m as Node).get_parent() == self and is_pinned(m as RigidBody3D) and int((m as Object).get_meta(META_TUFT, -1)) == k.id:
			continue
		k.members.remove_at(i)
	if k.members.is_empty():
		_drop_clump(k)
	return k.members.size()


func _list_clump(k: Clump) -> void:
	var ids: Array = _clump_cells.get(k.cell, [])
	ids.append(k.id)
	_clump_cells [k.cell] = ids


func _unlist_clump(k: Clump) -> void:
	if not _clump_cells.has(k.cell):
		return
	var ids: Array = _clump_cells [k.cell]
	ids.erase(k.id)
	if ids.is_empty():
		_clump_cells.erase(k.cell)


func _drop_clump(k: Clump) -> void:
	_clumps.erase(k.id)
	_unlist_clump(k)


func _wake_clump(k: Clump) -> int:
	_prune_clump(k)
	var members:= k.members.duplicate()
	_drop_clump(k)
	for m: RigidBody3D in members:
		unpin(m)
	return members.size()


static func _clear_settled(rb: RigidBody3D) -> void:
	if not rb.has_meta(META_TUFT) and not rb.has_meta(META_GLIDE) and rb.collision_layer != Cfg.L_SETTLED:
		return
	for key in [META_TUFT, META_GLIDE, META_PINNED]:
		if rb.has_meta(key):
			rb.remove_meta(key)
	rb.collision_layer = Cfg.L_STRAND
	rb.collision_mask = STRAND_MASK


static func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x + Cfg.FIELD_EXTENT) / Cfg.CELL)),
		int(floor((p.z + Cfg.FIELD_EXTENT) / Cfg.CELL)))


static func _strand_length(b: RigidBody3D) -> float:
	return Cfg.STRAND_LENGTH * float(b.get_meta(META_LEN, 1.0))


func _tuft_taking(p: Vector3) -> HayTuft:
	var best: HayTuft = null
	var best_gap:= Cfg.TUFT_ABSORB_REACH
	for t in HayTuft.all:
		if not is_instance_valid(t) or not t.takes_straw() or _room_in(t) <= 0:
			continue
		var at:= t.global_position
		var rise:= p.y - at.y
		if rise < - Cfg.TUFT_STEP or rise > t.height() + Cfg.TUFT_STEP:
			continue
		var gap:= Vector2(p.x - at.x, p.z - at.z).length() - t.reach()
		if gap <= best_gap:
			best_gap = gap
			best = t
	return best


func _room_in(t: HayTuft) -> int:
	return Cfg.TUFT_MAX - t.strands - int(_incoming.get(t.get_instance_id(), 0))


func _glide(b: RigidBody3D, target: Variant) -> void:
	var key:= 0
	if target is HayTuft:
		key = (target as HayTuft).get_instance_id()
		_incoming [key] = int(_incoming.get(key, 0)) + 1
	_pass_let_go(b, target)
	if b.has_meta(META_TUFT):
		b.remove_meta(META_TUFT)
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	b.continuous_cd = false
	b.collision_layer = 0
	b.collision_mask = 0
	b.set_meta(META_PINNED, true)
	b.set_meta(META_GLIDE, true)
	_gliding [b.get_instance_id()] = [b, b.global_transform.orthonormalized(), 0.0, target, key]


func _pass_let_go(b: RigidBody3D, target: Variant) -> void:
	var until:= float(b.get_meta(Shovel.META_LET_GO, 0.0))
	if until <= 0.0:
		return
	if target is HayTuft:
		var t:= target as HayTuft
		t.set_meta(Shovel.META_LET_GO,
			maxf(until, float(t.get_meta(Shovel.META_LET_GO, 0.0))))
	elif target is Merge:
		(target as Merge).let_go = maxf((target as Merge).let_go, until)


func _tick_glides(delta: float) -> void:
	if _gliding.is_empty():
		return
	var done: Array [int] = []
	for id: int in _gliding:
		var rec: Array = _gliding [id]
		var target: Variant = rec [3]
		var key:= int(rec [4])
		var b: Variant = rec [0]


		if not is_instance_valid(b) or (b as Node).get_parent() != self or not (b as Object).has_meta(META_GLIDE):
			done.append(id)
			_arrived(target, key, false)
			continue
		var rb:= b as RigidBody3D


		if key != 0 and (not is_instance_valid(target)
				or not (target as HayTuft).is_inside_tree()
				or (target as HayTuft).is_held() or (target as HayTuft).freeze):
			done.append(id)
			_arrived(target, key, false)
			unpin(rb)
			continue
		rec [2] = float(rec [2]) + delta
		var k:= clampf(float(rec [2]) / Cfg.TUFT_GATHER_SECONDS, 0.0, 1.0)
		var e:= k * k
		var start: Transform3D = rec [1]
		var to:= _glide_point(target)
		rb.global_transform = Transform3D(start.basis, start.origin.lerp(to, e))
		if k < 1.0:
			continue
		done.append(id)
		_arrived(target, key, consume(rb))
	for id in done:
		_gliding.erase(id)
	for t in _new_tufts:
		if is_instance_valid(t):
			_gather_clumps_into(t)
	_new_tufts.clear()


func _glide_point(target: Variant) -> Vector3:
	if target is HayTuft and is_instance_valid(target):
		var t:= target as HayTuft
		return t.global_position + Vector3.UP * (t.height() * 0.5)
	return (target as Merge).xf.origin + Vector3.UP * 0.03


func _arrived(target: Variant, key: int, got_there: bool) -> void:
	if key != 0:
		if _incoming.has(key):
			_incoming [key] = int(_incoming [key]) - 1
			if int(_incoming [key]) <= 0:
				_incoming.erase(key)
		if not got_there:
			return
		if not is_instance_valid(target) or (target as HayTuft).add_strands(1) < 1:


			GameState.return_hay(1.0)
		return
	var m:= target as Merge
	m.waiting -= 1
	if got_there:
		m.arrived += 1
	if m.waiting > 0 or m.arrived <= 0:
		return
	if props == null:
		GameState.return_hay(float(m.arrived))
		return
	var tuft:= props.spawn("hay_tuft", m.xf, { "strands": m.arrived }) as HayTuft
	if tuft == null:
		GameState.return_hay(float(m.arrived))
		return
	if m.let_go > 0.0:
		tuft.set_meta(Shovel.META_LET_GO, m.let_go)


	_new_tufts.append(tuft)


func _gather_clumps_into(t: HayTuft) -> void:
	var at:= t.global_position
	var reach:= t.reach() + Cfg.TUFT_ABSORB_REACH + Cfg.TUFT_RADIUS * 0.5
	var c:= _cell_of(at)
	var span:= int(ceil(reach / Cfg.CELL))
	for dj in range(- span, span + 1):
		for di in range(- span, span + 1):
			var key:= c + Vector2i(di, dj)
			if not _clump_cells.has(key):
				continue
			for id: int in (_clump_cells [key] as Array).duplicate():
				var k: Clump = _clumps.get(id)
				if k == null or absf(k.centre.y - at.y) > t.height() + Cfg.TUFT_STEP:
					continue
				if Vector2(k.centre.x - at.x, k.centre.z - at.z).length() > reach:
					continue
				_prune_clump(k)
				var room:= _room_in(t)
				if room < k.members.size():
					continue
				var members:= k.members.duplicate()
				_drop_clump(k)
				for b: RigidBody3D in members:
					_glide(b, t)


func _tick_tufts(delta: float) -> void:
	_clock += delta
	if field != _hooked_field and field != null:
		field.cells_redrawn.connect(_on_cells_redrawn)
		_hooked_field = field
	_tick_glides(delta)
	_gather_poured(delta)
	_sweep_support()


func see_straw_again(rb: RigidBody3D) -> bool:
	if not is_instance_valid(rb) or not rb.is_inside_tree():
		return false
	if rb.collision_mask & Cfg.L_STRAND:
		return true
	var q:= _loose_query
	q.shape = _see_shape(rb)
	q.transform = rb.global_transform
	q.collision_mask = Cfg.L_STRAND
	q.collide_with_areas = false
	var skip: Array [RID] = [rb.get_rid()]
	q.exclude = skip


	var space:= get_world_3d().direct_space_state
	var first:= space.intersect_shape(q, 1)
	if first.is_empty():
		rb.collision_mask |= Shovel.BLIND_MASK
		return true
	var near:= first [0].get("collider") as CollisionObject3D
	if near != null and not (near.collision_mask & Cfg.L_STRAND):
		return false
	for hit: Dictionary in space.intersect_shape(q, 16):
		var other:= hit.get("collider") as CollisionObject3D
		if other != null and not (other.collision_mask & Cfg.L_STRAND):
			return false
	rb.collision_mask |= Shovel.BLIND_MASK
	return true


func land_apart(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	if not (rb.collision_mask & Cfg.L_STRAND):
		var q:= _loose_query
		q.shape = _see_shape(rb)
		q.transform = rb.global_transform
		q.collision_mask = Cfg.L_STRAND
		q.collide_with_areas = false
		var skip: Array [RID] = [rb.get_rid()]
		q.exclude = skip
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 16):
			var other:= hit.get("collider") as RigidBody3D
			if other == null or (other.collision_mask & Cfg.L_STRAND):
				continue
			rb.add_collision_exception_with(other)
			_note_apart(rb, other)
			_note_apart(other, rb)
	rb.collision_mask |= Shovel.BLIND_MASK


var _apart: Dictionary = { }


func _note_apart(b: RigidBody3D, other: RigidBody3D) -> void:
	var list: Array = _apart.get(b.get_instance_id(), [])
	if not list.has(other):
		list.append(other)
	_apart [b.get_instance_id()] = list


func _lift_apart(b: RigidBody3D) -> void:
	var id:= b.get_instance_id()
	if not _apart.has(id):
		return
	for other: Variant in _apart [id]:
		if is_instance_valid(other):
			b.remove_collision_exception_with(other)
			var back: Array = _apart.get((other as Object).get_instance_id(), [])
			back.erase(b)
	_apart.erase(id)


const SEE_AGAIN_THICK:= 0.5
const SEE_AGAIN_LONG:= 0.98


var _see_shapes: Dictionary = { }


func _see_shape(b: RigidBody3D) -> Shape3D:
	var len_scale:= float(b.get_meta(META_LEN, 1.0))
	var box: Shape3D = _see_shapes.get(len_scale)
	if box == null:
		box = _test_shape(b, SEE_AGAIN_THICK, SEE_AGAIN_LONG)
		_see_shapes [len_scale] = box
	return box


func _test_shape(b: RigidBody3D, thick: float, long: float) -> BoxShape3D:
	var len_scale:= float(b.get_meta(META_LEN, 1.0))
	var key:= "%.3f %.3f %.3f" % [len_scale, thick, long]
	if not _test_shapes.has(key):
		var box:= BoxShape3D.new()
		box.size = Vector3(Cfg.STRAND_THICK * thick, Cfg.STRAND_THICK * thick,
			Cfg.STRAND_LENGTH * len_scale * long)
		_test_shapes [key] = box
	return _test_shapes [key]


func _sweep_support() -> void:
	if _clumps.is_empty():
		return
	var refilled:= false
	var asked:= 0
	while asked < Cfg.TUFT_SUPPORT_CHECKS:
		if _sweep.is_empty():
			if refilled:
				return
			_sweep = _clumps.keys()
			refilled = true
			if _sweep.is_empty():
				return
		var k: Clump = _clumps.get(_sweep.pop_back())
		asked += 1
		if k != null:
			_check_support(k)


func _check_support(k: Clump) -> void:
	if _prune_clump(k) == 0:
		return
	for i in mini(CLUMP_MEMBER_CHECKS, k.members.size()):
		var m:= k.members [_rng.randi_range(0, k.members.size() - 1)]
		if _lying_on(m, WAIT_PROBE, false).is_empty():
			unpin(m)


func _on_cells_redrawn(cells: PackedInt32Array) -> void:
	var nc:= Cfg.field_cells()


	if not HayTuft.all.is_empty():
		var redrawn:= { }
		for gc in cells:
			redrawn [Vector2i(gc % nc, gc / nc)] = true
		for t in HayTuft.all:
			if is_instance_valid(t) and t.sleeping and redrawn.has(_cell_of(t.global_position)):
				t.sleeping = false
	if _clumps.is_empty():
		return
	for gc in cells:
		var key:= Vector2i(gc % nc, gc / nc)
		if not _clump_cells.has(key):
			continue
		for id: int in (_clump_cells [key] as Array).duplicate():
			var k: Clump = _clumps.get(id)
			if k != null:


				_prune_clump(k)
				for m in k.members.duplicate():
					if _lying_on(m, WAIT_PROBE, false).is_empty():
						unpin(m)
