class_name ConveyorJoiner
extends Node3D


const LEFT:= 0
const RIGHT:= 1
const SIDES:= [LEFT, RIGHT]


var next_side:= LEFT

var placement_preview:= false

var _body: MeshInstance3D

var _infill: MeshInstance3D
var _arms: Dictionary = { }
var _out: BeltPath


var _serving:= LEFT


var _offer: RigidBody3D


var _flight:= 0


var _sweep: Area3D


const FLIGHT_LIMIT:= 20
var _supports: Node3D

var _drawn_held:= false


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	if placement_preview:
		set_physics_process(false)
		set_preview_valid(true)
		return


	FactoryClock.join(self)
	_build_paths()


	add_child(_make_infill_body())
	_sweep = _make_sweep()
	add_child(_sweep)
	add_to_group("conveyor_joiners")


	ConveyorSplitter.forget_mouths()


	call_deferred("refresh_supports")


func _exit_tree() -> void:
	ConveyorSplitter.forget_mouths()


func _build_model() -> void:
	var shell:= _body_mesh()
	if shell == null:
		push_error("ConveyorJoiner %s: the kit has no body mesh for it" % name)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = shell


	_body.rotation.y = PI
	add_child(_body)


	_infill = _make_infill()
	add_child(_infill)

	if placement_preview:
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_infill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _body_mesh() -> ArrayMesh:
	return ConveyorKit.joiner_mesh()


func _make_infill() -> MeshInstance3D:
	return WyeSweep.infill(_mouths())


func _make_infill_body() -> StaticBody3D:
	return WyeSweep.infill_body(_mouths())


func _make_sweep() -> Area3D:
	return WyeSweep.make_area(Cfg.JOINER_PORT_R)


func _arm_points(side: int) -> PackedVector3Array:
	return PackedVector3Array([port(side), global_position])


func _sweep_lanes() -> Array:
	return _lanes()


func _pad_centre(lane: Dictionary) -> Vector3:
	return ConveyorSplitter.leg_pad_centre(lane ["mouth"])


func footprint() -> Array [Vector4]:
	var c:= global_position
	return [Vector4(c.x, c.y, c.z, Cfg.JOINER_PORT_R)]


func _build_paths() -> void:
	_out = BeltPath.new()
	_out.name = "Out"


	_out.records_props = true
	add_child(_out)
	_out.build_path(PackedVector3Array([global_position, port_out()]),
		Cfg.BELT_JOINT_OVERLAP)
	_hide_sections(_out)


	_out.gathers_straw = true

	for side in SIDES:
		var arm:= BeltPath.new()
		arm.name = "Arm%s" % ("Left" if side == LEFT else "Right")
		arm.records_props = true
		add_child(arm)
		arm.build_path(_arm_points(side), Cfg.BELT_JOINT_OVERLAP)
		_hide_sections(arm)
		arm.gathers_straw = true


		arm.downstream = _out


		arm.set_catch_dead_zone(Cfg.JOINER_ARM_DEAD_ZONE)


		arm.set_hold_back(Cfg.JOINER_ARM_DEAD_ZONE)


		arm.handed_on.connect(_on_arm_gave.bind(side))
		arm.handed_on_record.connect(_on_arm_gave_record.bind(side))
		_arms [side] = arm


	var all:= paths()
	for p in all:
		p.share_deck(all)
	_serve()


static func _hide_sections(path: BeltPath) -> void:
	path.set_belt_drawn(false)


func port_out() -> Vector3:
	return to_global(Vector3(0.0, 0.0, Cfg.JOINER_PORT_R))


func port_left() -> Vector3:
	return to_global(_arm_local(1.0))


func port_right() -> Vector3:
	return to_global(_arm_local(-1.0))


func port(side: int) -> Vector3:
	return port_left() if side == LEFT else port_right()


func ports() -> Array [Vector3]:
	return [port_left(), port_right(), port_out()]


func _mouths() -> Array:
	return [_arm_local(1.0), _arm_local(-1.0),
		Vector3(0.0, 0.0, Cfg.JOINER_PORT_R)]


func _lanes() -> Array:
	return [
		{ "mouth": _arm_local(1.0), "travel": - _arm_local(1.0).normalized() },
		{ "mouth": _arm_local(-1.0), "travel": - _arm_local(-1.0).normalized() },
		{ "mouth": Vector3(0.0, 0.0, Cfg.JOINER_PORT_R), "travel": Vector3(0.0, 0.0, 1.0) },
	]


func forward() -> Vector3:
	return global_basis.z.normalized()


static func _arm_local(hand: float) -> Vector3:
	return Vector3(hand * sin(Cfg.JOINER_SPLAY), 0.0, - cos(Cfg.JOINER_SPLAY)) * Cfg.JOINER_PORT_R


func arm_travel(side: int) -> Vector3:
	return (global_position - port(side)).normalized()


func step_gap_ticks() -> int:
	return 2


func full_rate() -> bool:
	if _offer != null or (_sweep != null and _sweep.has_overlapping_bodies()):
		return true
	for p in paths():
		if p.is_busy():
			return true
	return false


func factory_tick(_delta: float) -> void:
	_serve()
	_refresh_held()


	if _sweep != null and _sweep.has_overlapping_bodies():
		WyeSweep.run(_sweep, self, _sweep_lanes(), Cfg.BELT_SPEED, Vector3(0.0, 0.0, 1.0))


func is_waiting() -> bool:
	if _offer != null or (_sweep != null and _sweep.has_overlapping_bodies()):
		_idle_memo.clear()
		return false
	return FactoryClock.idle_router(paths(), _idle_key(), _idle_memo)


var _idle_memo: Array = []


func _idle_key() -> Array:
	return [next_side, _serving, _flight, _drawn_held]


func _refresh_held() -> void:
	var held:= false
	var moving:= false
	for side in _arms:
		var h:= BeltPath.stopped_state(_arms [side])
		if h < 0:
			moving = true
			break
		held = held or h > 0
	if not moving:
		var o:= BeltPath.stopped_state(_out)
		if o < 0:
			moving = true
		held = held or o > 0
	held = held and not moving
	if held == _drawn_held:
		return
	_drawn_held = held
	_show_held()


func _show_held() -> void:
	if _body != null:
		_body.mesh = ConveyorKit.held_mesh(_body_mesh()) if _drawn_held else _body_mesh()


func _serve() -> void:
	if _crossing():


		for s in SIDES:
			var held:= _arms.get(s) as BeltPath
			if held != null:
				held.set_outlet_held(true)
		return
	var side:= next_side


	if not _due(side) and _due(_other(side)):
		side = _other(side)


	var mine:= _committed_by(_serving)
	var theirs:= _committed_by(_other(_serving))
	if mine > 0.0 or theirs > 0.0:
		side = _serving if mine >= theirs else _other(_serving)
	_serving = side
	for s in SIDES:
		var arm:= _arms.get(s) as BeltPath
		if arm != null:
			arm.set_outlet_held(s != side)


func _on_arm_gave(body: RigidBody3D, side: int) -> void:
	next_side = _other(side)
	_offer = body
	_flight = Engine.get_physics_frames()
	_hold_arm(side)


func _on_arm_gave_record(_seq: int, _kind: int, _strands: int, side: int) -> void:
	next_side = _other(side)
	_offer = null
	_flight = Engine.get_physics_frames()
	_hold_arm(side)


func _hold_arm(side: int) -> void:
	var a:= _arms.get(side) as BeltPath
	if a != null:
		a.set_outlet_held(true)


func _crossing() -> bool:
	if _offer == null:
		return false
	if not is_instance_valid(_offer) or (_out != null and _out.carries(_offer)):
		_offer = null
		return false
	if Engine.get_physics_frames() - _flight <= FLIGHT_LIMIT:
		return true


	_offer = null
	return false


func _due(side: int) -> bool:
	var arm:= _arms.get(side) as BeltPath
	return arm.load_near_end(Cfg.BELT_RIDE_SPACING) if arm != null else false


func _committed_by(side: int) -> float:
	var arm:= _arms.get(side) as BeltPath
	return arm.run.front_past_park_by() if arm != null else 0.0


static func _other(side: int) -> int:
	return RIGHT if side == LEFT else LEFT


func arm(side: int) -> BeltPath:
	return _arms.get(side) as BeltPath


func out_path() -> BeltPath:
	return _out


func paths() -> Array [BeltPath]:
	var out: Array [BeltPath] = []
	for side in SIDES:
		var a:= _arms.get(side) as BeltPath
		if a != null:
			out.append(a)
	if _out != null:
		out.append(_out)
	return out


func refresh_supports() -> void:
	if not is_inside_tree() or placement_preview:
		return
	if _supports != null:
		remove_child(_supports)
		_supports.queue_free()
		_supports = null
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	for lane: Dictionary in _lanes():
		var mouth:= to_global(lane ["mouth"])


		if not PointIndex.joins(mouth, port_out()) and ConveyorSplitter.wye_outlet_at(self, mouth):
			continue


		var yaw:= Conveyor._upright_basis(global_basis * (lane ["travel"] as Vector3))
		var centre_top:= to_global(_pad_centre(lane))
		for side: float in [-1.0, 1.0]:
			var top: Vector3 = centre_top + yaw.x * (side * _leg_half_width())
			var q:= PhysicsRayQueryParameters3D.create(top,
				top - Vector3(0, Cfg.BELT_SUPPORT_MAX_DROP, 0))


			q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
			q.exclude = own
			var hit:= space.intersect_ray(q)

			if hit.is_empty() or not Conveyor.stands_on_floor(hit):
				continue
			var ground: Vector3 = hit ["position"]
			var drop: float = top.y - ground.y
			if drop < 0.05:
				continue
			legs.append(Transform3D(yaw.scaled_local(Vector3(1, drop, 1)), top))
			feet.append(Transform3D(yaw, ground))

	_supports = Node3D.new()
	_supports.name = "Supports"
	_supports.top_level = true
	add_child(_supports)
	_supports.add_child(Conveyor._support_mm("Legs", ConveyorKit.leg_mesh(), legs))
	_supports.add_child(Conveyor._support_mm("Feet", ConveyorKit.foot_mesh(), feet))


func _leg_half_width() -> float:
	return ConveyorSplitter.LEG_PAD_HALF_WIDTH


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _body == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh: MeshInstance3D in [_body, _infill]:
		if mesh != null:
			mesh.material_overlay = material


func build_cost() -> float:
	return Cfg.JOINER_COST


func to_dict() -> Dictionary:
	return {
		"type": "conveyor_joiner",
		"position": global_position,
		"yaw": global_rotation.y,
		"next_side": int(next_side),
	}
