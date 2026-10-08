class_name Conveyor
extends BeltPath


var a: Vector3 = Vector3.ZERO
var b: Vector3 = Vector3.ZERO
var length: float = 0.0
var forward: Vector3 = Vector3.BACK

var trim_start: float = 0.0
var trim_end: float = 0.0


var paid_cost:= -1.0


var line_id:= 0


var seat_port:= Vector3.INF


const SUPPORT_TRIM_SLACK:= 0.01

var _supports: Node3D


var _built_legs: Array [Transform3D] = []
var _built_feet: Array [Transform3D] = []
var _drums: Node3D


static func cost_for(from: Vector3, to: Vector3) -> float:
	return from.distance_to(to) * Cfg.BELT_COST_PER_M * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return cost_for(a, b)


func is_hand_laid() -> bool:
	return true


func setup(from: Vector3, to: Vector3) -> void:
	a = from
	b = to
	YardPorts.touch()


	coarse_far = true
	length = a.distance_to(b)
	forward = (b - a).normalized() if length > 1e-06 else Vector3.BACK


	paid_cost = cost_for(a, b)


func laid_start() -> Vector3:
	return a + forward * trim_start


func laid_end() -> Vector3:
	return b - forward * trim_end


func set_trim(start: float, end: float) -> void:
	if is_equal_approx(start, trim_start) and is_equal_approx(end, trim_end):
		return
	trim_start = start
	trim_end = end
	if is_inside_tree():
		_lay()


func reverse() -> void:
	var was_a:= a
	a = b
	b = was_a
	YardPorts.touch()
	forward = (b - a).normalized() if length > 1e-06 else Vector3.BACK
	var was_start:= trim_start
	trim_start = trim_end
	trim_end = was_start
	if is_inside_tree():
		_lay()


func set_rail_windows(windows: Array [Dictionary]) -> void:
	if _same_windows(windows):
		return
	open_windows = windows
	if is_inside_tree():
		_lay()


func _same_windows(windows: Array [Dictionary]) -> bool:
	if windows.size() != open_windows.size():
		return false
	for i in windows.size():
		var w: Dictionary = windows [i]
		var mine: Dictionary = open_windows [i]
		if int(w ["side"]) != int(mine ["side"]) or not is_equal_approx(float(w ["from"]), float(mine ["from"])) or not is_equal_approx(float(w ["to"]), float(mine ["to"])):
			return false
	return true


func _ready() -> void:


	super ()

	gathers_straw = true


	records_props = true
	_lay()


func _lay() -> void:
	build_path(PackedVector3Array([laid_start(), laid_end()]))
	_refresh_drums()


	call_deferred("refresh_supports")


func _refresh_drums() -> void:
	if _drums != null:
		remove_child(_drums)
		_drums.queue_free()
		_drums = null
	var basis:= run_basis(laid_start(), laid_end())
	var ends: Array [Array] = []
	if trim_end <= 0.0:
		ends.append([ConveyorKit.nose_mesh(true), laid_end(), basis])
	if trim_start <= 0.0:


		ends.append([ConveyorKit.nose_mesh(false), laid_start(),
			basis.rotated(basis.y, PI)])
	if ends.is_empty():
		return
	_drums = Node3D.new()
	_drums.name = "Drums"


	_drums.top_level = true
	add_child(_drums)
	for e in ends:
		var mi:= MeshInstance3D.new()
		mi.set_meta("running_mesh", e [0])
		mi.mesh = _drum_drawn(e [0] as ArrayMesh)
		_drums.add_child(mi)
		mi.global_transform = Transform3D(e [2], e [1])


		BeltBatch.adopt(mi)


func _drum_drawn(running: ArrayMesh) -> ArrayMesh:
	return ConveyorKit.held_mesh(running) if deck_shows_held() else running


func _apply_deck_state() -> void:
	super ()
	if _drums == null:
		return
	for child in _drums.get_children():
		var mi:= child as MeshInstance3D
		if mi == null or not mi.has_meta("running_mesh"):
			continue
		var want:= _drum_drawn(mi.get_meta("running_mesh") as ArrayMesh)
		if mi.mesh != want:
			mi.mesh = want
			BeltBatch.changed(mi)


func refresh_supports() -> void:
	if not is_inside_tree():
		return
	var both:= trestles(get_world_3d().direct_space_state, a, b, support_stations(),
		_own_bodies())
	var legs: Array [Transform3D] = both [0]
	var feet: Array [Transform3D] = both [1]


	if _supports != null and legs == _built_legs and feet == _built_feet:
		return
	_built_legs = legs
	_built_feet = feet
	if _supports != null:
		remove_child(_supports)
		_supports.queue_free()
		_supports = null
	_supports = Node3D.new()
	_supports.name = "Supports"


	_supports.top_level = true
	add_child(_supports)
	_supports.add_child(_support_mm("Legs", ConveyorKit.leg_mesh(), legs))
	_supports.add_child(_support_mm("Feet", ConveyorKit.foot_mesh(), feet))


	for n: String in ["Legs", "Feet"]:
		BeltBatch.adopt(_supports.get_node(n) as GeometryInstance3D)


static func trestles(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		stations: Array [float], exclude: Array [RID],
		reject: Callable = Callable()) -> Array:
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	if from.distance_squared_to(to) < 1e-12:
		return [legs, feet]
	var dir:= (to - from).normalized()


	var frame_basis:= run_basis(from, to)
	var yaw:= _upright_basis(dir)
	for s: float in stations:


		var centre_top: Vector3 = (from + dir * s
			- frame_basis.y * Cfg.BELT_SUPPORT_ATTACH_DEPTH)


		for side: float in [-1.0, 1.0]:
			var top: Vector3 = centre_top + yaw.x * (side * Cfg.BELT_SUPPORT_HALF_WIDTH)
			var q:= PhysicsRayQueryParameters3D.create(top,
				top - Vector3(0, Cfg.BELT_SUPPORT_MAX_DROP, 0))


			q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD


			q.exclude = exclude
			var hit:= space.intersect_ray(q)


			if hit.is_empty() or not stands_on_floor(hit):
				continue
			var ground: Vector3 = hit ["position"]
			if reject.is_valid() and bool(reject.call(top, ground)):
				continue
			var drop: float = top.y - ground.y
			if drop < 0.05:
				continue


			legs.append(Transform3D(yaw.scaled_local(Vector3(1, drop, 1)), top))
			feet.append(Transform3D(yaw, ground))
	return [legs, feet]


func support_stations() -> Array [float]:
	var n:= maxi(1, int(round(length / Cfg.BELT_SUPPORT_SPACING)))
	var lo:= trim_start - SUPPORT_TRIM_SLACK
	var hi:= length - trim_end + SUPPORT_TRIM_SLACK


	var skip_a:= is_inside_tree() and ConveyorSplitter.wye_mouth_at(self, a)
	var skip_b:= is_inside_tree() and ConveyorSplitter.wye_mouth_at(self, b)
	var out: Array [float] = []
	for i in n + 1:
		if (i == 0 and skip_a) or (i == n and skip_b):
			continue
		var s:= length * float(i) / float(n)
		if s >= lo and s <= hi:
			out.append(s)
	if out.is_empty() and hi > lo:
		out.append((trim_start + length - trim_end) * 0.5)
	return out


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


static func _support_mm(mm_name: String, mesh: Mesh,
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


const FLOOR_NORMAL_Y:= 0.7


static func stands_on_floor(hit: Dictionary) -> bool:
	if hit.get("collider") is Platform:
		return true
	var rid: RID = hit.get("rid", RID())
	if not rid.is_valid():
		return false
	if PhysicsServer3D.body_get_collision_layer(rid) & Cfg.L_WORLD == 0:
		return false
	return (hit ["normal"] as Vector3).y >= FLOOR_NORMAL_Y


static func _upright_basis(dir: Vector3) -> Basis:
	var fwd:= Vector3(dir.x, 0.0, dir.z)
	if fwd.length_squared() < 1e-08:
		fwd = Vector3.BACK
	fwd = fwd.normalized()
	return Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd)


func to_dict() -> Dictionary:
	var d:= { "type": "conveyor", "a": a, "b": b, "paid": build_cost() }

	if line_id != 0:
		d ["line"] = line_id
	if seat_port.is_finite():
		d ["seat"] = seat_port
	return d
