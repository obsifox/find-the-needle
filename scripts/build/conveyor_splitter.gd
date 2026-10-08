class_name ConveyorSplitter
extends Node3D


const LEFT:= 0
const RIGHT:= 1
const SIDES:= [LEFT, RIGHT]


const SET_TURN:= "turn"
const SET_PIN_LEFT:= "pin_left"
const SET_PIN_RIGHT:= "pin_right"
const SET_MAIN_LEFT:= "main_left"
const SET_MAIN_RIGHT:= "main_right"


const SET_NAMES:= {
	SET_PIN_LEFT: "LEFT",
	SET_TURN: "ALTERNATE",
	SET_PIN_RIGHT: "RIGHT",
	SET_MAIN_LEFT: "LEFT FIRST",
	SET_MAIN_RIGHT: "RIGHT FIRST",
}


var next_side:= LEFT


var forced_side:= -1


var priority_side:= -1

var placement_preview:= false


static var share_feed_enabled:= true


static var old_blade:= false


static var route_boost:= 1.0 if "--oldsplit" in OS.get_cmdline_user_args() else 1.5


static var old_throat:= "--oldsplit" in OS.get_cmdline_user_args()


const BLADE_GROUND:= 0.4


const BLADE_SPAN:= 0.9
const BLADE_EDGE:= 0.03


const BATCH:= 8


const BATCH_AFTER:= 0.25
const UNBATCH_AFTER:= 1.0


var _batching:= false

var _batch_n:= 0
var _tight_for:= 0.0
var _loose_for:= 0.0


var _last_catch_at:= - INF
var _catch_gap:= INF


var _parked_under:= PackedFloat32Array()

var _gate_goal:= 0.0


const READOUT_SHADER:= "res://assets/splitter_readout.gdshader"


const SCREEN_SIZE:= Vector2(0.312, 0.187)


const SCREEN_AT:= Vector3(0.0, 0.875, 0.3998)


const CAPTION_DY:= -0.06


const LEG_PAD_INSET:= 0.27
const LEG_PAD_HALF_WIDTH:= 0.38
const LEG_PAD_DEPTH:= 0.176

var _body: MeshInstance3D
var _gate: MeshInstance3D

var _readout: MeshInstance3D
var _screen: MeshInstance3D
var _screen_mat: ShaderMaterial

var _caption: Label3D

var _infill: MeshInstance3D
var _routes: Dictionary = { }
var _supports: Node3D
var _gate_angle:= 0.0


var _sweep: Area3D


var _feeder: BeltPath

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
	_build_routes()


	add_child(_make_infill_body())
	_sweep = _make_sweep()
	add_child(_sweep)
	add_to_group("conveyor_splitters")

	forget_mouths()
	_gate_angle = _gate_target()
	_gate_goal = _gate_angle
	_apply_gate()


	call_deferred("refresh_supports")


func _exit_tree() -> void:
	forget_mouths()


func _build_model() -> void:
	var shell:= _body_mesh()
	if shell == null:
		push_error("ConveyorSplitter %s: the kit has no body mesh for it" % name)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = shell
	add_child(_body)

	_gate = MeshInstance3D.new()
	_gate.name = "Gate"
	_gate.mesh = ConveyorKit.splitter_gate_mesh()


	_gate.position = Vector3(0.0, 0.0, Cfg.SPLITTER_GATE_PIVOT)
	add_child(_gate)


	_infill = _make_infill()
	add_child(_infill)

	_build_readout()

	if placement_preview:
		for mesh in [_body, _gate, _infill]:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _body_mesh() -> ArrayMesh:
	return ConveyorKit.fast_mesh(ConveyorKit.splitter_mesh())


func _make_infill() -> MeshInstance3D:
	return WyeSweep.infill(_mouths())


func _make_infill_body() -> StaticBody3D:
	return WyeSweep.infill_body(_mouths())


func _make_sweep() -> Area3D:
	return WyeSweep.make_area(Cfg.SPLITTER_PORT_R)


func _route_points(side: int) -> PackedVector3Array:
	return PackedVector3Array([port_in(), global_position, port(side)])


func _sweep_lanes() -> Array:
	return _lanes()


func _pad_centre(lane: Dictionary) -> Vector3:
	return leg_pad_centre(lane ["mouth"])


func arm_travel(side: int) -> Vector3:
	return (port(side) - global_position).normalized()


func footprint() -> Array [Vector4]:
	var c:= global_position
	return [Vector4(c.x, c.y, c.z, Cfg.SPLITTER_PORT_R)]


func _build_readout() -> void:
	var case_mesh:= ConveyorKit.splitter_readout_mesh()
	if case_mesh == null:
		push_error("ConveyorSplitter: conveyorbelt.blend has no ConveyorSplitterReadout mesh")
		return
	_readout = MeshInstance3D.new()
	_readout.name = "Readout"
	_readout.mesh = case_mesh
	add_child(_readout)

	var shader: Shader = load(READOUT_SHADER)
	if shader == null:
		push_warning("ConveyorSplitter: no %s; the screen will stay dark plastic"
			% READOUT_SHADER)
	else:
		var quad:= QuadMesh.new()
		quad.size = SCREEN_SIZE
		_screen_mat = ShaderMaterial.new()
		_screen_mat.shader = shader
		_screen_mat.set_shader_parameter("aspect", SCREEN_SIZE.x / SCREEN_SIZE.y)
		_screen_mat.set_shader_parameter("ground", Cfg.COL_SPLITTER_SCREEN)
		_screen = MeshInstance3D.new()
		_screen.name = "Screen"
		_screen.mesh = quad
		_screen.material_override = _screen_mat
		_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


		_screen.transform = Transform3D(Basis(Vector3.UP, PI), SCREEN_AT)
		_readout.add_child(_screen)


		_caption = Label3D.new()
		_caption.name = "Caption"
		_caption.font = UiFont.bold()
		_caption.font_size = 64


		_caption.pixel_size = 0.0004
		_caption.billboard = BaseMaterial3D.BILLBOARD_DISABLED


		_caption.shaded = false
		_caption.double_sided = false
		_caption.modulate = Cfg.COL_SPLITTER_LIT
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


		_caption.transform = Transform3D(Basis(Vector3.UP, PI),
			SCREEN_AT + Vector3(0.0, CAPTION_DY, -0.0006))
		_readout.add_child(_caption)

	_refresh_readout()
	if placement_preview:
		return


	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_refresh_readout)


func _on_tech_changed(_id: String, _rank: int) -> void:
	_refresh_readout()


func _refresh_readout() -> void:
	if _readout == null or not is_instance_valid(_readout):
		return
	_readout.visible = Tech.priority_arm_unlocked()
	if _screen_mat != null:
		_screen_mat.set_shader_parameter("mode", _screen_mode())
	if _caption != null:
		_caption.text = setting_name()


func setting_name() -> String:
	return name_for(setting())


func name_for(id: String) -> String:


	var raw:= str(SET_NAMES.get(id, ""))
	return tr(raw) if raw != "" else ""


func _screen_mode() -> float:
	match setting():
		SET_PIN_LEFT:
			return 1.0
		SET_PIN_RIGHT:
			return 2.0
		SET_MAIN_LEFT:
			return 3.0
		SET_MAIN_RIGHT:
			return 4.0
		_:
			return 0.0


func _build_routes() -> void:
	for side in SIDES:
		var route:= BeltPath.new()
		route.name = "Route%s" % ("Left" if side == LEFT else "Right")


		route.records_props = true
		route.record_boost = route_boost
		add_child(route)
		route.build_path(_route_points(side), Cfg.BELT_JOINT_OVERLAP)


		route.set_belt_drawn(false)


		route.gathers_straw = true
		route.caught.connect(_on_caught.bind(side))
		route.caught_record.connect(_on_caught_record.bind(side))
		_routes [side] = route


	for side in SIDES:
		var route:= _routes.get(side) as BeltPath
		if route != null:
			route.share_deck([_routes.get(_other(side)) as BeltPath])
	_apply_catching()


func port_in() -> Vector3:
	return to_global(Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R))


func port_left() -> Vector3:
	return to_global(_arm_local(1.0))


func port_right() -> Vector3:
	return to_global(_arm_local(-1.0))


func port(side: int) -> Vector3:
	return port_left() if side == LEFT else port_right()


func ports() -> Array [Vector3]:
	return [port_in(), port_left(), port_right()]


func _mouths() -> Array:
	return [Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R), _arm_local(1.0), _arm_local(-1.0)]


func _lanes() -> Array:
	var into:= Vector3(0.0, 0.0, - Cfg.SPLITTER_PORT_R)
	return [
		{ "mouth": into, "travel": Vector3(0.0, 0.0, 1.0) },
		{ "mouth": _arm_local(1.0), "travel": _arm_local(1.0).normalized() },
		{ "mouth": _arm_local(-1.0), "travel": _arm_local(-1.0).normalized() },
	]


func forward() -> Vector3:
	return global_basis.z.normalized()


static func _arm_local(hand: float) -> Vector3:
	return Vector3(hand * sin(Cfg.SPLITTER_SPLAY), 0.0, cos(Cfg.SPLITTER_SPLAY)) * Cfg.SPLITTER_PORT_R


func _on_caught(_rb: RigidBody3D, side: int) -> void:
	_note_catch(side)
	_flip(side)
	_share_now()


func _on_caught_record(_seq: int, _kind: int, _strands: int, side: int) -> void:
	_note_catch(side)
	_flip(side)
	_share_now()


func _share_now() -> void:
	_share_feed()


func _note_catch(_side: int) -> void:
	var now:= _physics_now()
	_catch_gap = now - _last_catch_at
	_last_catch_at = now


static func _physics_now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _flip(side: int) -> void:


	if forced_side >= 0:
		next_side = forced_side
	elif priority_side >= 0:
		next_side = priority_side
	elif _batching:


		_batch_n = _batch_n + 1 if next_side == side else 1
		next_side = side if _batch_n < BATCH else _other(side)
		if _batch_n >= BATCH:
			_batch_n = 0
	else:
		_batch_n = 0
		next_side = _other(side)
	_apply_catching()


func _apply_catching() -> void:
	var open:= _open_side()


	var wait:= open >= 0 and _throat_parked(_other(open))
	for side in SIDES:
		var route:= _routes.get(side) as BeltPath
		if route != null:
			route.set_catching(side == open and not wait)
	_sync_feeder(open)


var _stall:= [0.0, 0.0]


const STALL_SECONDS:= 0.8


func _open_side() -> int:


	if forced_side >= 0:
		return forced_side if not _stalled(forced_side) else -1


	if priority_side >= 0:
		if not _stalled(priority_side):
			return priority_side
		var spill:= _other(priority_side)
		return spill if not _stalled(spill) else -1
	if not _stalled(next_side):
		return next_side
	var other:= _other(next_side)
	return other if not _stalled(other) else -1


func _tick_stalls(delta: float) -> void:
	_note_handed()
	for side in SIDES:
		_stall [side] = float(_stall [side]) + delta if _backed_up(side) else 0.0


var _handed_seen:= { }
var _handed_now:= { }


func _note_handed() -> void:
	for side in _routes:
		var route:= _routes [side] as BeltPath
		if route == null or not is_instance_valid(route):
			continue
		var handed:= route.run.handed
		_handed_now [side] = handed != int(_handed_seen.get(side, handed))
		_handed_seen [side] = handed


func _backed_up(side: int) -> bool:
	var route:= _routes.get(side) as BeltPath
	if route == null:
		return true
	if old_throat:
		return route.has_load_waiting()
	return route.has_load_waiting() and not bool(_handed_now.get(side, false))


func _stalled(side: int) -> bool:
	var route:= _routes.get(side) as BeltPath
	if route == null:
		return true
	var scale: float = maxf(1.0, route.waiting_gap() / Cfg.BELT_RIDE_SPACING)


	scale *= Cfg.BELT_SPEED / maxf(route.drive_speed, Cfg.BELT_SPEED)
	return float(_stall [side]) > STALL_SECONDS * scale


func _unjam_throat() -> void:
	var open:= _open_side()
	if open < 0:
		return
	var shut:= _other(open)
	var from:= _routes.get(shut) as BeltPath
	var onto:= _routes.get(open) as BeltPath
	if from == null or onto == null or from._catching:
		return
	if not _throat_parked(shut):
		return
	var r:= from.run
	var o:= onto.run


	var take:= 0
	while take < r.count() - 1:
		var row:= r.first() + r.count() - 1 - take
		if not _blocks_other(shut, r.s_of(row), r.reach_of(row)):
			break
		take += 1
	if take == 0:
		return


	var loads: Array [Vector3] = []


	var was_s:= { }
	var top:= - INF
	for k in take:
		var row:= r.first() + r.count() - 1 - k
		var at:= float(onto._nearest(from._point_at(r.s_of(row))) ["s"])
		loads.append(Vector3(at, r.reach_of(row), -1 - row))
		was_s [-1 - row] = r.s_of(row)
		top = maxf(top, at)
	var mine:= 0
	while mine < o.count():
		var row:= o.first() + o.count() - 1 - mine
		if o.s_of(row) > top + o.spacing:
			break
		loads.append(Vector3(o.s_of(row), o.reach_of(row), row))
		mine += 1
	loads.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)


	var stay:= r.count() - take
	var end:= onto.path_length()
	var at_s:= PackedFloat64Array()
	for k in loads.size():
		var s:= maxf(loads [k].x, 0.0)
		if k > 0:
			s = maxf(s, at_s [k - 1] + maxf(o.spacing, loads [k].y + loads [k - 1].y) + 0.002)
		while s <= end and _touches(r, stay, onto._point_at(s), loads [k].y):
			s += 0.02
		at_s.append(s)


	var last:= loads.size() - 1
	if at_s [last] > onto.path_length():
		return
	if mine < o.count():
		var ahead:= o.first() + o.count() - 1 - mine
		if o.s_of(ahead) - at_s [last] < maxf(o.spacing, o.reach_of(ahead) + loads [last].y):
			return


	var recs:= { }
	for k in take:
		var row:= r.first() + r.count() - 1
		recs [-1 - row] = r.remove_at(row)
	for k in mine:
		var row:= o.first() + o.count() - 1
		recs [row] = o.remove_at(row)
	var was:= o.catching
	o.catching = true
	for k in range(last, -1, -1):
		var rec: Dictionary = recs [int(loads [k].z)]
		if o.board_record(rec, at_s [k], 0.0, false):
			continue


		var back:= from if loads [k].z < 0.0 else onto
		var back_s: float = was_s.get(int(loads [k].z), loads [k].x)
		back.run.catching = true
		var put:= back.run.board_record(rec, back_s, 0.0, false)
		back.run.catching = back == onto and was
		if not put:

			push_warning("%s: unjam could not put seq %d back" % [name, int(rec.get("seq", -1))])
			back._spawn_record(rec, back_s)
	o.catching = was
	onto.wake()
	from.wake()
	_share_now()


static func _touches(run: BeltRun, rows: int, at: Vector3, reach: float) -> bool:
	for i in range(run.first(), run.first() + rows):
		if run.pose_of(i).origin.distance_to(at) < run.reach_of(i) + reach:
			return true
	return false


func _throat_parked(side: int) -> bool:
	var route:= _routes.get(side) as BeltPath
	if route == null or route._catching or not route.has_load_waiting():
		return false
	if not _stalled(side):
		return false
	var r:= route.run
	if r.count() < 2:
		return false
	var rear:= r.first() + r.count() - 1
	return _blocks_other(side, r.s_of(rear), r.reach_of(rear))


func _fork_s(side: int) -> float:
	var known = _fork_at.get(side)
	if known != null:
		return known
	var a:= _routes.get(side) as BeltPath
	var b:= _routes.get(_other(side)) as BeltPath
	var fork:= 0.0
	var s:= 0.0
	var total:= a.path_length()
	while s <= total:
		var p:= a._point_at(s)
		var q:= b._point_at(float(b._nearest(p) ["s"]))
		if p.distance_to(q) > 0.02:
			break
		fork = s
		s += 0.02
	_fork_at [side] = fork
	return fork


var _fork_at: Dictionary = { }


func _queue_at_throat(side: int) -> bool:
	var route:= _routes.get(side) as BeltPath
	if route == null:
		return true
	var dir:= global_basis * _arm_local(1.0 if side == LEFT else -1.0).normalized()
	return not route.has_room_near(global_position + dir * Cfg.SPLITTER_ARM_CLEAR)


func _has_room(side: int) -> bool:
	var route:= _routes.get(side) as BeltPath
	if route == null:
		return false


	if route.has_load_waiting():
		return false


	var dir:= global_basis * _arm_local(1.0 if side == LEFT else -1.0).normalized()
	return route.has_room_near(global_position + dir * Cfg.SPLITTER_ARM_CLEAR)


static func _other(side: int) -> int:
	return RIGHT if side == LEFT else LEFT


func set_forced_side(side: int) -> void:
	forced_side = side if side == LEFT or side == RIGHT else -1
	if forced_side >= 0:


		priority_side = -1
		next_side = forced_side


	_refresh_readout()
	if _routes.is_empty():
		return
	_apply_catching()


func set_priority_side(side: int) -> void:
	priority_side = side if side == LEFT or side == RIGHT else -1
	if priority_side >= 0:
		forced_side = -1
		next_side = priority_side
	_refresh_readout()
	if _routes.is_empty():
		return
	_apply_catching()


func straight_side() -> int:
	return -1


func mode_label() -> String:
	if forced_side == LEFT:
		return tr("left side only")
	if forced_side == RIGHT:
		return tr("right side only")
	if priority_side == LEFT:
		return tr("left side first, right when it backs up")
	if priority_side == RIGHT:
		return tr("right side first, left when it backs up")
	return tr("both sides, alternating")


func setting() -> String:
	if forced_side == LEFT:
		return SET_PIN_LEFT
	if forced_side == RIGHT:
		return SET_PIN_RIGHT
	if priority_side == LEFT:
		return SET_MAIN_LEFT
	if priority_side == RIGHT:
		return SET_MAIN_RIGHT
	return SET_TURN


func route(side: int) -> BeltPath:
	return _routes.get(side) as BeltPath


func routes() -> Array [BeltPath]:
	var out: Array [BeltPath] = []
	for side in SIDES:
		var r:= _routes.get(side) as BeltPath
		if r != null:
			out.append(r)
	return out


func output_sides() -> Array:
	return SIDES


func has_panel() -> bool:
	return true


func set_feeder(run: BeltPath) -> void:
	_feeder = run
	_sync_feeder()


func feeder() -> BeltPath:
	return _feeder if is_instance_valid(_feeder) else null


func _sync_feeder(open: int = -2) -> void:
	if _feeder == null or not is_instance_valid(_feeder):
		return
	var side: int = _open_side() if open == -2 else open


	if side < 0:
		side = next_side
	_feeder.downstream = _routes.get(side) as BeltPath


func step_gap_ticks() -> int:
	return 2


func full_rate() -> bool:
	if _sweep != null and _sweep.has_overlapping_bodies():
		return true
	for r in routes():
		if r.is_busy():
			return true
	return false


func factory_tick(delta: float) -> void:


	_tick_stalls(delta)
	_apply_catching()
	_unjam_throat()
	_share_feed()
	_refresh_held()


	var side:= _open_side()
	if side < 0:
		side = next_side


	if _sweep != null and _sweep.has_overlapping_bodies():
		WyeSweep.run(_sweep, self, _sweep_lanes(), Cfg.BELT_SPEED,
			_arm_local(1.0 if side == LEFT else -1.0).normalized())
	_note_feed_traffic(delta)


	if old_blade or forced_side >= 0 or is_equal_approx(_gate_angle, _gate_goal):
		_gate_goal = _gate_target()
	if is_equal_approx(_gate_angle, _gate_goal):
		return
	_gate_angle = move_toward(_gate_angle, _gate_goal, Cfg.SPLITTER_GATE_SPEED * delta)
	_apply_gate()


func _share_feed() -> void:
	var left:= _routes.get(LEFT) as BeltPath
	var right:= _routes.get(RIGHT) as BeltPath
	if left == null or right == null:
		return
	if not share_feed_enabled:
		left.set_foreign_loads(PackedFloat64Array())
		right.set_foreign_loads(PackedFloat64Array())
		return
	if old_throat:
		var until:= _fork_s(LEFT)
		var was_left:= left.lane_loads_before(until)
		left.set_foreign_loads(right.lane_loads_before(until))
		right.set_foreign_loads(was_left)
		return
	var on_left:= _lane_loads(LEFT)
	left.set_foreign_loads(_lane_loads(RIGHT))
	right.set_foreign_loads(on_left)


func _lane_loads(side: int) -> PackedFloat64Array:
	var route:= _routes.get(side) as BeltPath
	if route == null:
		return PackedFloat64Array()
	var out:= route.lane_loads_before(INF)
	for k in range(0, out.size() - 2, 3):
		var gap:= _lane_gap(side, out [k])
		if gap > LANE_GAP_SHARED:
			out [k + 2] = gap
	return out


const LANE_GAP_SHARED:= 0.02


func _lane_gap(side: int, s: float) -> float:
	var table: PackedFloat32Array = _lane_gaps.get(side, PackedFloat32Array())
	if table.is_empty():
		var a:= _routes.get(side) as BeltPath
		var b:= _routes.get(_other(side)) as BeltPath
		if a == null or b == null:
			return 0.0
		var at:= 0.0
		var total:= a.path_length()
		while at <= total + 0.02:
			var p:= a._point_at(minf(at, total))
			table.append(p.distance_to(b._point_at(float(b._nearest(p) ["s"]))))
			at += 0.02
		_lane_gaps [side] = table
	return table [clampi(int(s / 0.02), 0, table.size() - 1)]


var _lane_gaps: Dictionary = { }


func _blocks_other(side: int, s: float, reach: float) -> bool:
	if old_throat:
		return s - reach < _fork_s(side)
	var other:= _routes.get(_other(side)) as BeltPath
	var theirs:= reach
	if other != null and other.run.count() > 0:
		theirs = other.run.reach_of(other.run.first() + other.run.count() - 1)
	return _lane_gap(side, s) <= reach + theirs


static func _late(dt: float) -> float:
	return maxf(dt - 1.0 / float(Engine.physics_ticks_per_second), 0.0)


func _note_feed_traffic(delta: float) -> void:

	if old_blade or forced_side >= 0 or priority_side >= 0:
		_batching = false
		_tight_for = 0.0
		return
	var swing:= 2.0 * Cfg.SPLITTER_GATE_SWING / Cfg.SPLITTER_GATE_SPEED
	var bar:= swing + BLADE_GROUND / maxf(Tech.belt_speed(), 0.01) + _late(delta)

	var head:= maxf(_catch_gap, _physics_now() - _last_catch_at)
	var room:= head >= bar


	for side in SIDES:
		if float(_stall [side]) > 0.0 and _queue_at_throat(side):
			room = false
	if _batching:
		_loose_for = _loose_for + delta if room else 0.0
		if _loose_for >= UNBATCH_AFTER:
			_batching = false
			_tight_for = 0.0
		return
	_tight_for = 0.0 if room else _tight_for + delta
	if _tight_for >= BATCH_AFTER:
		_batching = true
		_loose_for = 0.0


func is_waiting() -> bool:
	if _sweep != null and _sweep.has_overlapping_bodies():
		_idle_memo.clear()
		return false
	var paths: Array = routes()
	paths.append(feeder())
	return FactoryClock.idle_router(paths, _idle_key(), _idle_memo)


var _idle_memo: Array = []


func _idle_key() -> Array:
	return [next_side, forced_side, priority_side, _stall [0], _stall [1],
		_gate_angle, _drawn_held, _batching]


func _refresh_held() -> void:
	var held:= false
	var moving:= false
	for side in _routes:
		var h:= BeltPath.stopped_state(_routes [side])
		if h < 0:
			moving = true
			break
		held = held or h > 0
	if not moving:
		var f:= BeltPath.stopped_state(feeder())
		if f < 0:
			moving = true
		held = held or f > 0
	held = held and not moving
	if held == _drawn_held:
		return
	_drawn_held = held
	_show_held()


func _show_held() -> void:
	if _body != null:
		_body.mesh = ConveyorKit.held_mesh(_body_mesh()) if _drawn_held else _body_mesh()


func _gate_target() -> float:


	if forced_side >= 0:
		return Cfg.SPLITTER_GATE_SWING if forced_side == LEFT else - Cfg.SPLITTER_GATE_SWING
	var side:= _imminent_side()
	var want:= Cfg.SPLITTER_GATE_SWING if side == LEFT else - Cfg.SPLITTER_GATE_SWING


	var here_end:= Cfg.SPLITTER_GATE_SWING * signf(_gate_angle)
	if _stalled(LEFT) and _stalled(RIGHT) and not is_zero_approx(here_end):
		if _blade_depth(- here_end) < _blade_depth(here_end):
			return - here_end
		return here_end


	if not _parked_under.is_empty():
		var here:= _blade_depth(want)
		if here > 0.0 and _blade_depth(- want) < here:
			return - want
	return want


func _blade_depth(angle: float) -> float:
	var pivot:= Vector2(0.0, Cfg.SPLITTER_GATE_PIVOT)
	var tip:= pivot + Vector2(0.0, - BLADE_SPAN).rotated(- angle)
	var depth:= 0.0
	for k in range(0, _parked_under.size(), 3):
		var p:= Vector2(_parked_under [k], _parked_under [k + 1])
		var q:= Geometry2D.get_closest_point_to_segment(p, pivot, tip)
		depth += maxf(_parked_under [k + 2] + BLADE_EDGE - p.distance_to(q), 0.0)
	return depth


func _imminent_side() -> int:
	var centre:= global_position
	var fwd:= forward()
	var clear:= 0.0 if old_blade else BLADE_GROUND
	_parked_under.clear()


	var reach_from:= Cfg.SPLITTER_GATE_PIVOT - BLADE_SPAN - 0.3
	var best:= - INF
	var out:= next_side
	for side in SIDES:
		var route:= _routes.get(side) as BeltPath
		if route == null:
			continue


		var moving:= _batching and float(_stall [side]) <= 0.0
		for rb in route.riders():
			var t:= (rb.global_position - centre).dot(fwd)
			if t > reach_from and t < clear and float(_stall [side]) > 0.0:
				_note_parked(rb.global_position, float(BeltPath.load_shape(rb) ["reach"]))
			if t >= clear or t <= best:
				continue
			if t >= 0.0 and moving:
				continue
			best = t
			out = side

		var run:= route.run
		var f:= run.first()
		for i in range(f, f + run.count()):
			var at:= run.pose_of(i).origin
			var t:= (at - centre).dot(fwd)
			if t > reach_from and t < clear and float(_stall [side]) > 0.0:
				_note_parked(at, run.reach_of(i))
			if t >= clear or t <= best:
				continue
			if t >= 0.0 and moving:
				continue
			best = t
			out = side
	return out


func _note_parked(at: Vector3, reach: float) -> void:
	var p:= to_local(at)
	_parked_under.append_array([p.x, p.z, reach])


func _apply_gate() -> void:
	if _gate == null:
		return

	if _gate_ease == null:
		_gate_ease = StepEase.attach(_gate)
	_gate_ease.go(_gate_angle)


var _gate_ease: StepEase


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

		if PointIndex.joins(mouth, port_in()) and wye_outlet_at(self, mouth):
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
	return LEG_PAD_HALF_WIDTH


static func leg_pad_centre(mouth: Vector3) -> Vector3:
	return mouth - mouth.normalized() * LEG_PAD_INSET + Vector3.DOWN * LEG_PAD_DEPTH


static func wye_outlet_at(asker: Node, point: Vector3) -> bool:
	var tree:= asker.get_tree()
	for node in tree.get_nodes_in_group("conveyor_splitters"):
		var splitter:= node as ConveyorSplitter
		if splitter == null or splitter == asker:
			continue
		for side: int in splitter.output_sides():
			if PointIndex.joins(splitter.port(side), point):
				return true
	for node in tree.get_nodes_in_group("conveyor_joiners"):
		var joiner:= node as ConveyorJoiner
		if joiner != null and joiner != asker and PointIndex.joins(joiner.port_out(), point):
			return true
	return false


static var _mouth_cache: PointIndex = null


static func forget_mouths() -> void:
	_mouth_cache = null


static func _mouth_index(tree: SceneTree) -> PointIndex:
	if _mouth_cache != null:
		return _mouth_cache
	var idx:= PointIndex.new()
	var wyes: Array [Node] = tree.get_nodes_in_group("conveyor_splitters")
	wyes.append_array(tree.get_nodes_in_group("conveyor_joiners"))
	for wye: Node in wyes:
		for mouth: Vector3 in wye.call("ports"):
			idx.add(mouth, wye, 0)
	_mouth_cache = idx
	return _mouth_cache


static func wye_mouth_at(asker: Node, point: Vector3) -> bool:
	return not _mouth_index(asker.get_tree()).best(point).is_empty()


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


func set_preview_valid(valid: bool) -> void:
	if not placement_preview:
		return
	var material:= ConveyorKit.ghost_material(valid)


	for mesh: MeshInstance3D in [_body, _gate, _infill, _readout]:
		if mesh != null:
			mesh.material_overlay = material


func build_cost() -> float:
	return Cfg.SPLITTER_COST


func to_dict() -> Dictionary:
	return {
		"type": "conveyor_splitter",
		"position": global_position,
		"yaw": global_rotation.y,
		"next_side": int(next_side),
		"forced_side": int(forced_side),
		"priority_side": int(priority_side),
	}
