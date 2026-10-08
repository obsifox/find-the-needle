class_name ConveyorTJoiner
extends ConveyorJoiner


const HUB_R:= ConveyorTSplitter.HUB_R


const PARK_D:= 0.4


var out_lane:= ConveyorTSplitter.STEM


var port_r:= Cfg.T_SPLITTER_PORT_R

var _tbody: ConveyorTBody
var _gate_angle:= 0.0
var _gate_speed:= 0.0


var _parked:= false
var _tight_t:= 0.0
var _loose_t:= 0.0


var _asked:= -1
var _since_ask:= 0.0
var _swap_t:= INF


var _steel_to:= 0


var _park_d:= [0.9, 0.9]
var _park_s:= [0.6, 0.6]
var _shown_serving:= -1


static func inlets_of(outlet: int) -> Array [int]:
	var d:= ConveyorTSplitter.lane_out(outlet)
	var left:= Vector3(d.z, 0.0, - d.x)
	var others: Array [int] = []
	for lane: int in ConveyorTSplitter.LANES:
		if lane != outlet:
			others.append(lane)
	if ConveyorTSplitter.lane_out(others [0]).dot(left) >= ConveyorTSplitter.lane_out(others [1]).dot(left):
		return others
	return [others [1], others [0]]


func inlet(side: int) -> int:
	return inlets_of(out_lane) [side]


func port_out() -> Vector3:
	return to_global(ConveyorTSplitter.lane_mouth(out_lane, port_r))


func port_left() -> Vector3:
	return to_global(ConveyorTSplitter.lane_mouth(inlet(LEFT), port_r))


func port_right() -> Vector3:
	return to_global(ConveyorTSplitter.lane_mouth(inlet(RIGHT), port_r))


func forward() -> Vector3:
	return (global_basis * ConveyorTSplitter.lane_out(out_lane)).normalized()


func arm_travel(side: int) -> Vector3:
	return (global_basis * - ConveyorTSplitter.lane_out(inlet(side))).normalized()


func lane_at(point: Vector3) -> int:
	for lane: int in ConveyorTSplitter.LANES:
		if PointIndex.joins(to_global(ConveyorTSplitter.lane_mouth(lane, port_r)), point):
			return lane
	return -1


func _mouths() -> Array:
	return [ConveyorTSplitter.lane_mouth(ConveyorTSplitter.STEM, port_r),
		ConveyorTSplitter.lane_mouth(ConveyorTSplitter.BAR_POS, port_r),
		ConveyorTSplitter.lane_mouth(ConveyorTSplitter.BAR_NEG, port_r)]


func _lane_travel(lane: int) -> Vector3:
	var out:= ConveyorTSplitter.lane_out(lane)
	return out if lane == out_lane else - out


func _lanes() -> Array:
	var out: Array = []
	for lane: int in ConveyorTSplitter.LANES:
		out.append({ "mouth": ConveyorTSplitter.lane_mouth(lane, port_r), "travel": _lane_travel(lane) })
	return out


func _sweep_lanes() -> Array:
	return _lanes()


func _pad_centre(lane: Dictionary) -> Vector3:
	var mouth: Vector3 = lane ["mouth"]
	return mouth.normalized() * ConveyorTSplitter.leg_inset(port_r) + Vector3.DOWN * ConveyorTSplitter.LEG_DEPTH


func _leg_half_width() -> float:
	return ConveyorTSplitter.LEG_HALF


func footprint() -> Array [Vector4]:
	return ConveyorTSplitter.footprint_of(self)


func build_cost() -> float:
	return Cfg.T_SPLITTER_COST


func to_dict() -> Dictionary:
	var d:= super ()
	d ["type"] = "conveyor_t_joiner"
	d ["out_lane"] = out_lane
	d ["port_r"] = port_r
	return d


func set_out(outlet: int) -> void:
	outlet = clampi(outlet, ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_NEG)
	if outlet == out_lane:
		return
	out_lane = outlet
	YardPorts.touch()
	next_side = LEFT
	_offer = null


	_parked = false
	_tight_t = 0.0
	_loose_t = 0.0
	_asked = -1
	_since_ask = 0.0
	_swap_t = INF
	_apply_scroll()
	_refresh_readout(true)
	if _out == null:
		_steel_to = LEFT
		_gate_angle = _angle_for(LEFT)
		_apply_gate()
		return
	_build_paths()
	call_deferred("refresh_supports")


func _build_model() -> void:
	_tbody = ConveyorTBody.new()
	_tbody.name = "Body"
	add_child(_tbody)
	_tbody.build(placement_preview, port_r)
	_apply_scroll()
	_steel_to = next_side
	_gate_angle = _angle_for(next_side)
	_apply_gate()
	_refresh_readout(true)


func _apply_scroll() -> void:
	if _tbody == null:
		return
	var travel:= { }
	for lane: int in ConveyorTSplitter.LANES:
		travel [lane] = _lane_travel(lane)
	_tbody.apply_scroll(travel, _drawn_held)


func _show_held() -> void:
	_apply_scroll()


func _make_infill() -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.name = "Infill"
	return mi


func _make_infill_body() -> StaticBody3D:
	return ConveyorTBody.floor_body(ConveyorTSplitter.JUNCTION_HALF)


func _make_sweep() -> Area3D:
	return WyeSweep.make_lane_area(_sweep_lanes(), HUB_R)


func _build_paths() -> void:
	_measure()
	var lane:= port_r - ConveyorTSplitter.JUNCTION_HALF
	var fresh:= _out == null
	if fresh:
		_out = BeltPath.new()
		_out.name = "Out"

		_out.records_props = true
		add_child(_out)
		_out.gathers_straw = true

	_out.open_windows = _windows(0.0, ConveyorTSplitter.JUNCTION_HALF)
	_out.build_path(PackedVector3Array([global_position, port_out()]),
		Cfg.BELT_JOINT_OVERLAP)
	_hide_sections(_out)

	for side in SIDES:
		var arm:= _arms.get(side) as BeltPath
		if arm == null:
			arm = BeltPath.new()
			arm.name = "Arm%s" % ("Left" if side == LEFT else "Right")
			arm.records_props = true
			add_child(arm)
			arm.gathers_straw = true
			arm.handed_on.connect(_on_arm_gave.bind(side))
			arm.handed_on_record.connect(_on_arm_gave_record.bind(side))
			_arms [side] = arm
		arm.hold_before(-1.0)
		arm.open_windows = _windows(lane, port_r)
		arm.build_path(_arm_points(side), Cfg.BELT_JOINT_OVERLAP)
		_hide_sections(arm)
		arm.downstream = _out
		arm.set_catch_dead_zone(Cfg.JOINER_ARM_DEAD_ZONE)

		arm.set_hold_back(float(_park_d [side]))
	var all:= paths()
	for p in all:
		p.share_deck(all)
	_serve()


func _windows(from: float, to: float) -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for sgn in [-1, 1]:
		out.append({ "side": sgn, "from": from, "to": to })
	return out


func _measure() -> void:
	var r:= port_r
	for side in SIDES:
		var park:= minf(PARK_D, r - 0.05)
		_park_d [side] = park
		_park_s [side] = r - park


func factory_tick(delta: float) -> void:
	_serve()
	_refresh_held()
	_steer(delta)

	if _sweep != null and _sweep.has_overlapping_bodies():
		WyeSweep.run(_sweep, self, _sweep_lanes(), Cfg.BELT_SPEED,
			ConveyorTSplitter.lane_out(out_lane))
	_refresh_readout(false)


func _serve() -> void:
	if _arms.is_empty():
		return
	var crossing:= _crossing()
	var want:= next_side
	if not _due(want) and _due(_other(want)):
		want = _other(want)


	var committed:= -1
	var deepest:= 0.0
	for s in SIDES:
		var depth:= _past_park(s)
		if depth > deepest:
			deepest = depth
			committed = s
	var side:= committed if committed >= 0 else want
	_serving = side


	for s in SIDES:
		var arm:= _arms.get(s) as BeltPath
		if arm == null:
			continue
		if s != side:
			arm.set_outlet_held(true)
			arm.hold_before(-1.0)
		elif committed >= 0:


			arm.set_outlet_held(false)
			arm.hold_before(float(_park_s [s]) if want != s else -1.0)
		else:
			arm.hold_before(-1.0)
			arm.set_outlet_held(crossing)


func _past_park(side: int) -> float:
	var arm:= _arms.get(side) as BeltPath
	if arm == null:
		return 0.0
	var depth:= 0.0
	for m in arm.load_marks():
		depth = maxf(depth, float(m ["s"]) - float(_park_s [side]) - 0.002)
	return depth


func _angle_for(side: int) -> float:
	return ConveyorTSplitter.blade_angle(inlet(side), out_lane)


func _steer(delta: float) -> void:
	_steel_to = _steel_side()
	var want:= _angle_for(_steel_to)
	if _fold(delta):
		want = _open_angle()
	if is_equal_approx(_gate_angle, want):
		_gate_speed = 0.0
		return


	var named:= is_equal_approx(_gate_angle, _angle_for(LEFT)) or is_equal_approx(_gate_angle, _angle_for(RIGHT)) or is_equal_approx(absf(_gate_angle), Cfg.T_SPLITTER_PARK)
	if is_zero_approx(_gate_speed) and named and _arm_blocked(want) and not _has_load(_steel_to):
		_gate_speed = 0.0
		return
	var step:= ConveyorTSplitter.arm_step(_gate_angle, _gate_speed, want, delta)
	_gate_angle = step.x
	_gate_speed = step.y
	_apply_gate()


func _fold(delta: float) -> bool:
	if ConveyorTSplitter.old_arm:
		return false
	_since_ask += delta
	if _steel_to != _asked:
		if _asked >= 0:
			_swap_t = _since_ask
		_asked = _steel_to
		_since_ask = 0.0

	var need:= ConveyorTSplitter.swing_time(_angle_for(LEFT) - _angle_for(RIGHT)) + (port_r + PARK_D) / maxf(Tech.belt_speed(), 0.01)
	var room:= maxf(_swap_t, _since_ask) >= need
	if _parked:
		_loose_t = _loose_t + delta if room else 0.0
		if _loose_t >= ConveyorTSplitter.UNPARK_AFTER:
			_parked = false
			_tight_t = 0.0
	else:
		_tight_t = 0.0 if room else _tight_t + delta
		if _tight_t >= ConveyorTSplitter.PARK_AFTER:
			_parked = true
			_loose_t = 0.0
	return _parked


func _open_angle() -> float:
	return Cfg.T_SPLITTER_PARK if _gate_angle >= 0.0 else - Cfg.T_SPLITTER_PARK


func _steel_side() -> int:
	if _has_load(_serving):
		return _serving
	if _has_load(_other(_serving)):
		return _other(_serving)
	return _steel_to


func _has_load(side: int) -> bool:
	var arm:= _arms.get(side) as BeltPath
	return arm != null and not arm.load_marks().is_empty()


func _arm_blocked(to: float) -> bool:
	var marks: Array [Dictionary] = []
	if _out != null:
		marks.append_array(_out.load_marks())
	for s in SIDES:
		var arm:= _arms.get(s) as BeltPath
		if arm == null:
			continue
		for m in arm.load_marks():
			if float(m ["s"]) + float(m ["reach"]) > float(_park_s [s]):
				marks.append(m)
	for m in marks:
		if not bool(m ["prop"]):
			continue

		if ConveyorTSplitter.in_sweep(to_local(m ["pos"] as Vector3),
				float(m ["reach"]), _gate_angle, to):
			return true
	return false


func _apply_gate() -> void:
	if _tbody != null:
		_tbody.set_arm_angle(_gate_angle)


func _refresh_readout(force: bool) -> void:
	if _tbody == null or (not force and _serving == _shown_serving):
		return
	_shown_serving = _serving
	_tbody.show_merge(out_lane, inlet(_serving), tr("JOINING"))


func set_preview_valid(valid: bool) -> void:
	if placement_preview and _tbody != null:
		_tbody.set_ghost(valid)


func body() -> ConveyorTBody:
	return _tbody


func arm_angle() -> float:
	return _gate_angle


func arm_parked() -> bool:
	return _parked


func serving() -> int:
	return _serving


func park_s(side: int) -> float:
	return float(_park_s [side])


func _idle_key() -> Array:
	var key:= super ()
	key.append_array([out_lane, _gate_angle, _gate_speed, _steel_to, _shown_serving,
		_parked])
	return key
