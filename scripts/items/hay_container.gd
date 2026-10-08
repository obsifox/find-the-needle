class_name HayContainer
extends Carryable


const CROWN_SHARE:= 0.25


const CROWN_RISE:= 0.38


const CROWN_TAPER:= 0.72


const CROWN_BIAS:= 1.55


const CROWN_MIN:= 6


const POUR_INHERIT_MAX:= 3.0


const POUR_RIM_CLEAR:= 0.05


const POUR_TUFT_SECONDS:= 0.25


const POUR_PASS_MIN:= 0.4
const POUR_PASS_MAX:= 1.5

const POUR_TUMBLE:= 1.5

const POUR_LAND_WATCH:= 4.0

const POUR_LANDED:= 0.3

const POUR_HOP_TIME:= 0.35

const POUR_HOPS:= 2


const POUR_BELT_WAIT:= 1.0


const POUR_BELT_NUDGE:= 1.5


const FULL_BADGE_GAP:= 2.6

var live: LiveStrandManager

var stored:= 0


var docked_in: Node3D = null


var pour_boost:= 1.0

var _interior: Area3D
var _fill: MultiMeshInstance3D
var _fill_mm: MultiMesh
var _pour_accum:= 0.0
var _pour_sound:= 0.0

var _pouring:= false


var _poured_out: Dictionary = { }


var _landing: Dictionary = { }


var _belt_tuft: HayTuft = null
var _belt_tuft_age:= 0.0


var _pour_reach:= -1.0

var _belt_held:= 0.0


var _riding: Dictionary = { }
var _rng:= RandomNumberGenerator.new()


var _hold_local:= Vector3.ZERO
var _hold_radius:= 0.2


var _built_scale:= 1.0


var _mouth_centre:= Vector3.ZERO
var _mouth_reach:= 0.0


var _crown:= 0

var _badge_gap:= 0.0


static var _standing: Array [HayContainer] = []

static var _pile: HayField


var _pile_h:= NAN


const PILE_SINK:= 0.01


static func pile_rebuilt(field: HayField, lo: Vector2, hi: Vector2) -> void:
	_pile = field
	for c in _standing:
		if not c._planted or c.freeze or is_nan(c._pile_h):
			continue
		var p:= c.global_position
		if p.x < lo.x or p.x > hi.x or p.z < lo.y or p.z > hi.y:
			continue
		if absf(field.height_at(p.x, p.z) - c._pile_h) > PILE_SINK:
			c.floor_gone()


static func support_gone(at: Vector3, reach: float) -> void:
	for c in _standing:
		if not c._planted or c.freeze:
			continue
		var p:= c.global_position
		if p.y + 0.05 < at.y:
			continue
		if Vector2(p.x - at.x, p.z - at.z).length_squared() <= reach * reach:
			c.floor_gone()


func _settle() -> void:
	super ()
	_pile_h = NAN
	if _planted and _pile != null and is_instance_valid(_pile):
		var p:= global_position
		_pile_h = _pile.height_at(p.x, p.z)


func shoved_by_tools() -> bool:
	return false


func passes_through_barrows() -> bool:
	return true


func _ready() -> void:
	super ()
	_built_scale = size_scale()
	Tech.tech_changed.connect(_on_size_changed)
	Tech.tech_reset.connect(_rebuild_geometry)


	FillCount.attach(self)


func capacity() -> int:
	return 1


func pour_rate() -> float:
	return 100.0


func tip_start() -> float:
	return Cfg.BUCKET_TIP_START


func tip_full() -> float:
	return Cfg.BUCKET_TIP_FULL


func fill_instances() -> int:
	return 1


func container_noun() -> String:
	return tr("container")


func _make_interior_shape() -> CollisionShape3D:
	return null


func _load_point(_u: float, _rng_in: RandomNumberGenerator) -> Vector3:
	return Vector3.ZERO


func _load_bounds() -> AABB:
	return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))


func _lip_point(_spill: Vector3) -> Vector3:
	return Vector3.ZERO


func _build_load() -> void:
	_measure_mouth()
	_fill_mm = MultiMesh.new()
	_fill_mm.transform_format = MultiMesh.TRANSFORM_3D
	_fill_mm.use_colors = true
	_fill_mm.mesh = StrandFactory.strand_mesh()
	_fill_mm.instance_count = fill_instances()
	_fill_mm.visible_instance_count = 0

	var n:= fill_instances()


	_crown = _crown_count(n)
	var body:= n - _crown


	var s:= size_scale()
	for i in body:


		var u:= pow(float(i) / float(maxi(body - 1, 1)), 0.85)
		var b:= StrandFactory.random_strand_basis(_rng, 0.85)
		_fill_mm.set_instance_transform(i, Transform3D(b, _load_point(u, _rng) * s))
		_fill_mm.set_instance_color(i, StrandFactory.random_tint(_rng))
	for j in _crown:
		var h:= pow(float(j) / float(maxi(_crown - 1, 1)), CROWN_BIAS)


		var cb:= StrandFactory.random_strand_basis(_rng, 0.68)
		_fill_mm.set_instance_transform(body + j,
			Transform3D(cb, _crown_point(h, _rng) * s))
		_fill_mm.set_instance_color(body + j, StrandFactory.random_tint(_rng))

	_fill = MultiMeshInstance3D.new()
	_fill.name = "Load"
	_fill.multimesh = _fill_mm
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var bounds:= _load_bounds()
	if _crown > 0:


		var top: float = maxf(bounds.end.y, _mouth_centre.y + crown_rise())
		bounds.size.y = top - bounds.position.y
		bounds = bounds.grow(Cfg.STRAND_LEN_MAX * 0.5)
	_fill.custom_aabb = AABB(bounds.position * s, bounds.size * s)
	add_child(_fill)


func _measure_mouth() -> void:
	var pts: Array [Vector3] = []
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		pts.append(_lip_point(d))
	_mouth_centre = (pts [0] + pts [1] + pts [2] + pts [3]) * 0.25
	var reach:= 0.0
	for p in pts:
		reach += p.distance_to(_mouth_centre)
	_mouth_reach = reach * 0.25


func pour_point() -> Vector3:
	return global_transform * (_mouth_centre * size_scale())


func pour_reach() -> float:
	return _mouth_reach * size_scale()


func has_room() -> bool:
	return stored < capacity()


func take_out(n: int) -> int:
	var went:= clampi(n, 0, stored)
	if went <= 0:
		return 0
	stored -= went
	_refresh_fill()
	return went


func takes_loose() -> bool:
	return not is_held() and docked_in == null and _upright() >= Cfg.CONTAINER_INTAKE_UP


func put_in(n: int) -> int:
	if not takes_loose():
		return 0
	var took:= clampi(n, 0, capacity() - stored)
	if took <= 0:
		return 0
	stored += took
	_refresh_fill()
	return took


func crown_rise() -> float:
	return _mouth_reach * CROWN_RISE


func _crown_count(n: int) -> int:
	if _mouth_reach <= 0.0 or n < CROWN_MIN:
		return 0
	return clampi(int(round(float(n) * CROWN_SHARE)), 1, n - 1)


func _crown_point(h: float, rng: RandomNumberGenerator) -> Vector3:
	var a:= rng.randf() * TAU
	var rim:= _lip_point(Vector3(cos(a), 0.0, sin(a))) - _mouth_centre


	var d:= sqrt(rng.randf()) * pow(1.0 - h, CROWN_TAPER)
	return _mouth_centre + rim * d + Vector3.UP * (h * crown_rise())


func _build_interior() -> void:
	var cs:= _make_interior_shape()
	if cs == null:
		push_error("%s: no interior shape" % item_id)
		return
	_interior = Area3D.new()
	_interior.name = "Interior"
	_interior.collision_layer = 0


	_interior.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_interior.monitorable = false


	var s:= size_scale()
	cs.transform = Transform3D(cs.transform.basis, cs.position * s)
	_scale_shape(cs.shape, s)
	_interior.add_child(cs)
	add_child(_interior)


	var aabb:= cs.shape.get_debug_mesh().get_aabb() if cs.shape != null else AABB()
	_hold_local = cs.position + aabb.get_center()
	_hold_radius = maxf(aabb.size.length() * 0.5, 0.05)


static func _scale_shape(shape: Shape3D, s: float) -> void:
	if is_equal_approx(s, 1.0) or shape == null:
		return
	var hull:= shape as ConvexPolygonShape3D
	if hull != null:
		var pts:= hull.points
		for i in pts.size():
			pts [i] *= s
		hull.points = pts
		return
	var box:= shape as BoxShape3D
	if box != null:
		box.size *= s


func _refresh_fill() -> void:
	if _fill_mm == null:
		return
	_fill_mm.visible_instance_count = int(round(fill_fraction() * float(fill_instances())))


func fill_fraction() -> float:
	return clampf(float(stored) / float(capacity()), 0.0, 1.0)


func _upright() -> float:
	return global_transform.basis.y.dot(Vector3.UP)


func carry_status() -> String:
	if stored >= capacity():
		return tr("%s full, %d") % [container_noun(), stored]
	return tr("%d / %d in %s") % [stored, capacity(), container_noun()]


func flash_full() -> void:
	if _badge_gap > 0.0 or not is_inside_tree():
		return
	_badge_gap = FULL_BADGE_GAP
	FullBadge.flash_over(self, badge_point())


func badge_point() -> Vector3:
	var y: float = maxf(_load_bounds().end.y, _mouth_centre.y + crown_rise())
	return Vector3(_mouth_centre.x, y + FullBadge.CLEARANCE, _mouth_centre.z) * size_scale()


func _on_size_changed(id: String, _rank: int) -> void:
	if id != size_node() or not is_inside_tree():
		return
	if is_equal_approx(size_scale(), _built_scale):
		return
	_rebuild_geometry()


func size_node() -> String:
	return ""


func _rebuild_geometry() -> void:
	_built_scale = size_scale()
	for child in get_children():
		if child is CollisionShape3D or child == _interior or child == _fill or child == _model:
			child.queue_free()
	_interior = null
	_fill = null
	_fill_mm = null
	_model = null
	_meshes.clear()


	_rng.seed = hash(item_id)

	_build()
	_refresh_fill()


func _physics_process(delta: float) -> void:


	sync_upright_lock()
	var up:= _upright()
	_take_hay(up)
	_pour(up, delta)
	_release_poured(delta)
	_spread_poured(delta)
	_pour_sound = maxf(0.0, _pour_sound - delta)
	_badge_gap = maxf(0.0, _badge_gap - delta)


func _take_hay(up: float) -> void:
	if live == null or _interior == null:
		return
	var mouth_up:= up >= Cfg.CONTAINER_INTAKE_UP


	var claim:= up > tip_start() or (is_held() and carrier != null and not carrier.pour_intent())
	if not claim and not mouth_up:


		for id: int in _riding:
			live.set_protected(_riding [id], false)
		_riding.clear()
		return


	var took:= false


	if mouth_up:
		took = _take_riding_load()


	var refused:= false
	var now: Dictionary = { }
	for b in _interior.get_overlapping_bodies():
		var rb:= b as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		if rb.has_meta("needle_index"):


			if claim:
				LiveStrandManager.unpin(rb)
				now [rb.get_instance_id()] = rb
			continue


		if _poured_out.has(rb.get_instance_id()):
			continue


		if rb is Carryable and (rb as Carryable).passes_through_barrows():
			continue
		var taking:= mouth_up and stored < capacity()
		var wad:= rb as HayWad
		if wad != null:


			if (wad.freeze and not BeltPath.is_rider(wad)) or wad.holds_needle():
				if claim:
					now [rb.get_instance_id()] = rb
				continue
			if taking:
				var moved: int = mini(capacity() - stored, wad.strands)
				stored += moved
				took = true
				if moved >= wad.strands:


					BeltPath.release(wad)
					wad.queue_free()
					continue
				wad.set_strands(wad.strands - moved)
			elif mouth_up and not _riding.has(rb.get_instance_id()):
				refused = true
			if claim:
				now [rb.get_instance_id()] = rb
			continue
		if taking and live.consume(rb):
			stored += 1
			took = true
			continue
		if not taking and mouth_up and (rb.collision_layer & Cfg.L_STRAND) != 0 and not _riding.has(rb.get_instance_id()):
			refused = true
		if not claim:
			continue
		now [rb.get_instance_id()] = rb
		if not _riding.has(rb.get_instance_id()):
			live.set_protected(rb, true)
	for id: int in _riding:
		if not now.has(id):
			live.set_protected(_riding [id], false)
	_riding = now
	if took:
		_refresh_fill()

		if stored >= capacity():
			flash_full()
	elif refused:
		flash_full()


func _take_riding_load() -> bool:
	if _interior == null or stored >= capacity():
		return false
	var found:= BeltPath.record_in(to_global(_hold_local), _hold_radius)
	if found.is_empty():
		return false
	var rec: Dictionary = found ["record"]
	if int(rec ["needle"]) >= 0:
		return false
	var kind:= int(rec ["kind"])
	if kind != BeltRun.Kind.WAD and kind != BeltRun.Kind.TUFT:
		return false
	var path:= found ["path"] as BeltPath
	if path == null:
		return false
	var row:= int(found ["row"])
	var room:= capacity() - stored
	if int(rec ["strands"]) <= room:
		var got:= path.take_record_at(row)
		if got.is_empty():
			return false
		stored += int(got ["strands"])
		return true
	var wad:= path.materialize_record(row) as HayWad
	if wad == null:
		return false
	stored += room
	wad.set_strands(wad.strands - room)
	return true


func _pour(up: float, delta: float) -> void:
	_belt_tuft_age += delta
	if stored <= 0 or live == null or live.props == null:
		_pouring = false
		return


	if is_held() and carrier != null and not carrier.pour_intent():
		_pour_accum = 0.0
		_pouring = false
		return
	if up > tip_start():
		_pour_accum = 0.0
		_pouring = false
		return
	var t:= clampf(inverse_lerp(tip_start(), tip_full(), up), 0.0, 1.0)


	var chunk:= clampi(roundi(pour_rate() * POUR_TUFT_SECONDS), Cfg.TUFT_MERGE_AT, Cfg.TUFT_MAX)
	if not _pouring:
		_pouring = true
		_pour_accum = float(chunk)


	_pour_accum += pour_rate() * pour_boost * t * delta

	var want: int = mini(chunk, stored)
	if _pour_accum < float(want):
		return

	var xf:= global_transform


	var down_local:= xf.basis.inverse() * Vector3.DOWN
	var spill:= Vector3(down_local.x, 0.0, down_local.z)
	spill = spill.normalized() if spill.length_squared() > 1e-06 else Vector3(0, 0, 1)


	var s:= size_scale()
	var lip:= _lip_point(spill) * s


	var away:= lip - _hold_local
	away = away.normalized() if away.length_squared() > 1e-06 else spill
	var tangent:= Vector3.UP.cross(spill).normalized()
	var out:= xf.basis * away
	out.y = minf(out.y, 0.0)
	out = out.normalized() if out.length_squared() > 1e-06 else xf.basis * spill


	var thrown:= Vector3.ZERO if is_held() else linear_velocity.limit_length(POUR_INHERIT_MAX)


	var along:= _rng.randf_range(-0.045, 0.045) * s
	var pos:= xf * (lip + tangent * along + away * (POUR_RIM_CLEAR * s))
	var launch:= out * 1.1 + Vector3.DOWN * 0.35 + thrown

	var belt: int = BeltPath.Pour.NO_BELT
	if is_held():
		belt = BeltPath.pour_verdict(pos, launch, _tuft_reach())
		if _belt_holds_pour(belt, delta):
			_pour_accum = minf(_pour_accum, float(want))
			return
	_belt_held = 0.0


	var yaw:= atan2(out.x, out.z) + _rng.randf_range(-0.5, 0.5)
	var tuft:= live.props.spawn("hay_tuft", Transform3D(Basis(Vector3.UP, yaw), pos),
		{ "strands": want }) as HayTuft
	if tuft == null:
		return
	tuft.add_collision_exception_with(self)
	_poured_out [tuft.get_instance_id()] = [tuft, 0.0]
	_landing [tuft.get_instance_id()] = [tuft, 0.0, 0]


	tuft.linear_velocity = launch
	tuft.angular_velocity = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)) * POUR_TUMBLE
	_pour_reach = float(BeltPath.load_shape(tuft) ["reach"])
	_belt_tuft = tuft if belt != BeltPath.Pour.NO_BELT else null
	_belt_tuft_age = 0.0
	_pour_accum -= float(want)
	stored -= want
	_refresh_fill()
	if _pour_sound <= 0.0:
		_pour_sound = 0.28
		Audio.play_3d("hay_dump", xf.origin, -4.0)


func _belt_holds_pour(belt: int, delta: float) -> bool:
	if belt == BeltPath.Pour.NO_BELT:
		return false
	if belt == BeltPath.Pour.ROOM:
		_belt_held = 0.0
		return is_instance_valid(_belt_tuft) and _belt_tuft.is_inside_tree() and not BeltPath.is_rider(_belt_tuft) and _belt_tuft_age < POUR_BELT_WAIT
	_belt_held += delta
	if _belt_held > POUR_BELT_NUDGE and _badge_gap <= 0.0:
		_badge_gap = FULL_BADGE_GAP
		FullBadge.flash_over(self, badge_point(), FullBadge.NO_ROOM)
	return true


func _tuft_reach() -> float:
	if _pour_reach > 0.0:
		return _pour_reach
	var box:= HayTuft.full_collider_size()
	return maxf(box.x, box.z) * 0.5


func _release_poured(delta: float) -> void:
	if _poured_out.is_empty():
		return
	var inside: Dictionary = { }
	if _interior != null:
		for b in _interior.get_overlapping_bodies():
			inside [b.get_instance_id()] = true
	for id: int in _poured_out.keys():
		var rec: Array = _poured_out [id]
		var b: Variant = rec [0]
		if not is_instance_valid(b):
			_poured_out.erase(id)
			continue
		var age:= float(rec [1]) + delta
		rec [1] = age
		if age < POUR_PASS_MIN or (inside.has(id) and age < POUR_PASS_MAX):
			continue
		(b as RigidBody3D).remove_collision_exception_with(self)
		_poured_out.erase(id)


func _spread_poured(delta: float) -> void:
	if _landing.is_empty():
		return
	for id: int in _landing.keys():
		var rec: Array = _landing [id]
		var b: Variant = rec [0]
		var age:= float(rec [1]) + delta
		rec [1] = age
		if not is_instance_valid(b) or age > POUR_LAND_WATCH:
			_landing.erase(id)
			continue
		var tuft:= b as HayTuft
		if tuft == null or not tuft.is_inside_tree() or tuft.freeze or tuft.is_held() or BeltPath.is_rider(tuft):
			_landing.erase(id)
			continue
		if age < POUR_PASS_MIN or tuft.linear_velocity.length_squared() > POUR_LANDED * POUR_LANDED:
			continue
		if _lying_on(tuft) is not HayTuft:
			_landing.erase(id)
			continue
		rec [2] = int(rec [2]) + 1
		var spot:= live.free_floor_near(tuft.global_position,
			Basis(Vector3.UP, tuft.global_basis.get_euler().y))
		if spot.is_empty() or int(rec [2]) > POUR_HOPS:
			_landing.erase(id)
			continue

		var to:= (spot ["position"] as Vector3) + Vector3.UP * 0.02
		var g:= Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		tuft.linear_velocity = (to - tuft.global_position) / POUR_HOP_TIME - g * POUR_HOP_TIME * 0.5
		tuft.angular_velocity = Vector3.ZERO
		tuft.sleeping = false
		rec [1] = POUR_PASS_MIN


func _lying_on(t: HayTuft) -> Object:
	var from:= t.global_transform * Vector3(0.0, t.height() * 0.5, 0.0)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.3)
	q.collision_mask = Cfg.L_PROP | Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.exclude = [t.get_rid()]
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	return null if hit.is_empty() else hit.get("collider")


func on_carried(xform: Transform3D, moved: Transform3D, delta: float) -> void:
	if delta <= 0.0 or _riding.is_empty():
		return


	if is_held() and carrier != null and not carrier.pour_intent():
		var centre:= xform * _hold_local
		for id: int in _riding:
			var body: Variant = _riding [id]
			if is_instance_valid(body):
				HayHold.carry_body(body as RigidBody3D, moved, centre, _hold_radius, delta)
		return
	var grip:= clampf(inverse_lerp(tip_start(), Cfg.CONTAINER_INTAKE_UP,
		xform.basis.y.dot(Vector3.UP)), 0.0, 1.0)
	if grip <= 0.0:
		return
	for id: int in _riding:


		var held: Variant = _riding [id]
		if not is_instance_valid(held):
			continue
		var rb:= held as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var p:= rb.global_position
		var want:= (moved * p - p) / delta
		var v:= rb.linear_velocity
		rb.linear_velocity = Vector3(lerpf(v.x, want.x, grip), v.y,
			lerpf(v.z, want.z, grip))
		rb.sleeping = false


func _enter_tree() -> void:
	_standing.append(self)


func _exit_tree() -> void:
	_standing.erase(self)


	if live != null:
		for id: int in _riding:
			live.set_protected(_riding [id], false)
	_riding.clear()


func to_state() -> Dictionary:
	return { "stored": stored }


func from_state(state: Dictionary) -> void:
	stored = clampi(int(state.get("stored", 0)), 0, capacity())
	_refresh_fill()
