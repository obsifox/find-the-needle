class_name LandingZone
extends Node3D


signal shown_changed(on: bool)


const HAY_EPS:= 0.02


const MARGIN:= 0.3


const HEADROOM:= 1.0


const FLOOR_SLACK:= 0.25


const CACHE_SECONDS:= 0.4


const TINT_TICK:= 0.5


const MAX_TINTED:= 4000


const LIFT:= 0.5

const OUTLINE_SAMPLES:= 256

const SHADER:= "res://assets/landing_zone.gdshader"
const TINT_SHADER:= "res://assets/landing_zone_tint.gdshader"


const STRIPE_PITCH:= 1.2
const POSTS:= 12
const POST_WIDTH:= 0.14

const EDGE_H:= 0.08


const COL_FRAME:= Color(0.95, 0.12, 0.1)

var builds: BuildManager

var _shown:= false
var _cache: Array [Node3D] = []
var _cache_at:= -1
var _barrier: Node3D


var _barrier_size:= Vector2.ZERO
var _tint: ShaderMaterial

var _tinted: Dictionary = { }
var _tint_clock:= 0.0


func _ready() -> void:
	position = Cfg.PILE_CENTER
	visible = false
	if builds != null and not builds.changed.is_connected(_invalidate):
		builds.changed.connect(_invalidate)


static func next_seed() -> int:
	return hash("%d:next load" % GameState.run_seed)


static func centre() -> Vector3:
	return Cfg.PILE_CENTER


static func radius() -> float:
	var toe:= float(Cfg.pile_size_spec(Cfg.pile_size_id).get("toe", Cfg.settled_footprint()))
	return toe + MARGIN


static func height() -> float:
	return Cfg.PILE_HEIGHT + HEADROOM


func blockers() -> Array [Node3D]:
	if _cache_at < 0 or Time.get_ticks_msec() - _cache_at > int(CACHE_SECONDS * 1000.0):
		refresh()
	var out: Array [Node3D] = []
	for building: Node3D in _cache:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			out.append(building)
	return out


func is_blocked() -> bool:
	return not blockers().is_empty()


func refresh() -> void:
	_cache.clear()
	_cache_at = Time.get_ticks_msec()
	if builds == null:
		return
	for building: Node3D in builds.all_buildings():
		if not is_instance_valid(building) or building.is_queued_for_deletion():
			continue
		if touches(building):
			_cache.append(building)


func summary() -> Array [Dictionary]:
	var counts: Dictionary = { }
	for building: Node3D in blockers():
		var what:= builds.name_of(building) if builds != null else ""
		if what == "":
			what = String(building.name)
		counts [what] = int(counts.get(what, 0)) + 1
	var out: Array [Dictionary] = []
	for what: String in counts:
		out.append({ "name": what, "count": int(counts [what]) })
	out.sort_custom(_by_count)
	return out


func _by_count(a: Dictionary, b: Dictionary) -> bool:
	if int(a ["count"]) != int(b ["count"]):
		return int(a ["count"]) > int(b ["count"])
	return str(a ["name"]) < str(b ["name"])


func _invalidate() -> void:
	_cache_at = -1


func touches(building: Node3D) -> bool:
	var shapes:= body_shapes(building)
	for cs: CollisionShape3D in shapes:
		if _shape_touches(cs):
			return true
	if not shapes.is_empty():
		return false
	var p:= building.global_position
	var c:= centre()
	return p.y < c.y + height() and Vector2(p.x - c.x, p.z - c.z).length() <= radius()


static func body_shapes(building: Node3D) -> Array [CollisionShape3D]:
	var out: Array [CollisionShape3D] = []
	if building == null or not is_instance_valid(building):
		return out
	var stack: Array [Node] = [building]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child: Node in n.get_children():
			stack.append(child)
		var cs:= n as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		if not (cs.get_parent() is PhysicsBody3D):
			continue
		out.append(cs)
	return out


func _shape_touches(cs: CollisionShape3D) -> bool:
	var local: AABB = cs.shape.get_debug_mesh().get_aabb()
	var xf:= cs.global_transform
	var corners:= PackedVector3Array()
	corners.resize(8)
	var lo_y:= INF
	var hi_y:= - INF
	for i in 8:
		var p:= local.position + Vector3(
			local.size.x if (i & 1) != 0 else 0.0,
			local.size.y if (i & 2) != 0 else 0.0,
			local.size.z if (i & 4) != 0 else 0.0)
		var w:= xf * p
		corners [i] = w
		lo_y = minf(lo_y, w.y)
		hi_y = maxf(hi_y, w.y)
	var c:= centre()
	if hi_y < c.y - FLOOR_SLACK or lo_y >= c.y + height():
		return false
	return _shadow_near(corners, Vector2(c.x, c.z), radius())


static func _shadow_near(corners: PackedVector3Array, o: Vector2, r: float) -> bool:
	for axis: int in [1, 2, 4]:
		var u_bit:= 2 if axis == 1 else 1
		var v_bit:= 2 if axis == 4 else 4
		for side: int in [0, axis]:
			var a:= _flat(corners [side])
			var eu:= _flat(corners [side | u_bit]) - a
			var ev:= _flat(corners [side | v_bit]) - a
			if _in_parallelogram(o - a, eu, ev):
				return true
	for i in 8:
		for bit: int in [1, 2, 4]:
			if (i & bit) != 0:
				continue
			if _segment_distance(o, _flat(corners [i]), _flat(corners [i | bit])) <= r:
				return true
	return false


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _in_parallelogram(p: Vector2, eu: Vector2, ev: Vector2) -> bool:
	var det:= eu.x * ev.y - eu.y * ev.x
	if absf(det) < 1e-06:
		return false
	var s:= (p.x * ev.y - p.y * ev.x) / det
	var t:= (eu.x * p.y - eu.y * p.x) / det
	return s >= 0.0 and s <= 1.0 and t >= 0.0 and t <= 1.0


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab:= b - a
	var l2:= ab.length_squared()
	if l2 < 1e-09:
		return p.distance_to(a)
	var t:= clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func is_shown() -> bool:
	return _shown


func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	visible = on
	if on:
		refresh()
		var size:= Vector2(radius(), height())
		if _barrier == null or not _barrier_size.is_equal_approx(size):
			_build_barrier()
		_retint()
		_tint_clock = 0.0
	else:
		_untint_all()
	shown_changed.emit(on)


func marks_drawn() -> int:
	return _tinted.size()


func _process(delta: float) -> void:
	if not _shown:
		return
	_tint_clock += delta
	if _tint_clock < TINT_TICK:
		return
	_tint_clock = 0.0
	refresh()
	_retint()


func _build_barrier() -> void:
	if _barrier != null:
		_barrier.queue_free()
	_barrier = Node3D.new()
	_barrier.name = "Barrier"
	add_child(_barrier)
	var r:= radius()
	var h:= height()
	_barrier_size = Vector2(r, h)

	var outline:= PackedVector2Array()
	for k in OUTLINE_SAMPLES:
		var ang:= TAU * float(k) / float(OUTLINE_SAMPLES)
		outline.append(Vector2(cos(ang), sin(ang)) * r)
	var perimeter:= 0.0
	for k in OUTLINE_SAMPLES:
		perimeter += outline [k].distance_to(outline [(k + 1) % OUTLINE_SAMPLES])

	var wall:= MeshInstance3D.new()
	wall.name = "Wall"
	wall.mesh = _ribbon(outline, 0.0, h)
	var mat:= ShaderMaterial.new()
	mat.shader = load(SHADER)


	var stripes:= maxf(1.0, round(perimeter / STRIPE_PITCH))
	mat.set_shader_parameter("height", h)
	mat.set_shader_parameter("pitch", perimeter / stripes)
	mat.set_shader_parameter("colour", COL_FRAME)
	wall.material_override = mat
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier.add_child(wall)

	var frame:= StandardMaterial3D.new()
	frame.albedo_color = COL_FRAME
	frame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frame.cull_mode = BaseMaterial3D.CULL_DISABLED

	for y0: float in [0.0, h - EDGE_H]:
		var strip:= MeshInstance3D.new()
		strip.name = "Edge"
		strip.mesh = _ribbon(outline, y0, y0 + EDGE_H)
		strip.material_override = frame
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_barrier.add_child(strip)

	var post_mesh:= BoxMesh.new()
	post_mesh.size = Vector3(POST_WIDTH, h, POST_WIDTH)
	for k in POSTS:
		var at:= outline [int(float(k) / float(POSTS) * OUTLINE_SAMPLES)]
		var post:= MeshInstance3D.new()
		post.name = "Post"
		post.mesh = post_mesh
		post.material_override = frame
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		post.position = Vector3(at.x, h * 0.5, at.y)
		_barrier.add_child(post)


static func _ribbon(outline: PackedVector2Array, y0: float, y1: float) -> ArrayMesh:
	var verts:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	var index:= PackedInt32Array()
	var n:= outline.size()
	var along:= 0.0
	for k in n + 1:
		var p:= outline [k % n]
		if k > 0:
			along += outline [k - 1].distance_to(p)
		verts.append(Vector3(p.x, y0, p.y))
		uvs.append(Vector2(along, 0.0))
		verts.append(Vector3(p.x, y1, p.y))
		uvs.append(Vector2(along, y1 - y0))
	for k in n:
		var a:= k * 2
		index.append(a)
		index.append(a + 2)
		index.append(a + 1)
		index.append(a + 1)
		index.append(a + 2)
		index.append(a + 3)
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	arrays [Mesh.ARRAY_INDEX] = index
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _retint() -> void:
	if _tint == null:
		_tint = ShaderMaterial.new()
		_tint.shader = load(TINT_SHADER)
	var batch:= BeltBatch.instance
	var want: Dictionary = { }
	var alone:= 0
	for building: Node3D in blockers():
		for surface: GeometryInstance3D in _surfaces_of(building):
			if batch == null or not batch.holds(surface):
				if alone >= MAX_TINTED:
					continue
				alone += 1
			want [surface.get_instance_id()] = surface
	for id: int in _tinted.keys():
		if not want.has(id):
			_untint(id)
	for id: int in want:
		var surface: GeometryInstance3D = want [id]
		var batched:= batch != null and batch.holds(surface)
		var rec: Dictionary = _tinted.get(id, { })
		if not rec.is_empty() and bool(rec ["batched"]) != batched:
			_clear_tint(surface)
		if batched:
			batch.set_tint(surface, _tint)
		elif surface.material_overlay != _tint:
			surface.material_overlay = _tint
		_tinted [id] = { "node": surface, "batched": batched }


static func _surfaces_of(building: Node3D) -> Array [GeometryInstance3D]:
	var out: Array [GeometryInstance3D] = []
	if building == null or not is_instance_valid(building):
		return out
	for n: Node in building.find_children("*", "GeometryInstance3D", true, false):
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			out.append(n as GeometryInstance3D)
	return out


func _untint(id: int) -> void:
	var rec: Dictionary = _tinted.get(id, { })
	_tinted.erase(id)
	if rec.is_empty():
		return
	var held: Variant = rec ["node"]
	if not is_instance_valid(held):
		return
	_clear_tint(held as GeometryInstance3D)


func _clear_tint(surface: GeometryInstance3D) -> void:
	if surface == null or _tint == null:
		return
	var batch:= BeltBatch.instance
	if batch != null and batch.tint_of(surface) == _tint:
		batch.set_tint(surface, null)
	if surface.material_overlay == _tint:
		surface.material_overlay = null


func _untint_all() -> void:
	for id: int in _tinted.keys():
		_untint(id)


func lift_loose(props: PropManager, live: LiveStrandManager, field: HayField) -> int:
	if field == null:
		return 0
	var bodies: Array [RigidBody3D] = []
	if props != null:
		for item: Carryable in props.items:
			if is_instance_valid(item) and not item.is_held():
				bodies.append(item)
	if live != null:
		for needle: RigidBody3D in live.needles:
			if is_instance_valid(needle):
				bodies.append(needle)
	var moved:= 0
	for body: RigidBody3D in bodies:
		var p:= body.global_position
		var surface:= field.height_at(p.x, p.z)
		if surface <= HAY_EPS or p.y >= surface:
			continue
		var lift:= 0.05 if body.freeze else LIFT
		body.global_position = Vector3(p.x, surface + lift, p.z)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		moved += 1
	return moved
