class_name ConveyorTSplitter
extends ConveyorSplitter


signal rerouted(body: RigidBody3D, side: int)

signal rerouted_record(seq: int, side: int)


const STEM:= 0
const BAR_POS:= 1
const BAR_NEG:= 2
const LANES: Array [int] = [STEM, BAR_POS, BAR_NEG]


const JUNCTION_HALF:= 0.45


const ARC_R:= 0.3
const ARC_PIECES:= 4


const BLADE_REACH:= 0.906
const BLADE_HALF:= 0.05


const LEG_HALF:= 0.428
const LEG_DEPTH:= 0.17

const HUB_R:= 0.64


var entry:= STEM


var fed:= false


var leaving: Array [int] = []

var arriving: Array [int] = []


var _showing:= false
var _show_t:= 0.0
var _show_i:= 0


var _shown_setup: Dictionary = { }


var _hints: Dictionary = { }

const SHOW_EACH:= 1.2


var port_r:= Cfg.T_SPLITTER_PORT_R


static var placed_port_r:= NAN


static func size_in_hand() -> float:
	return Cfg.t_splitter_port_r if is_nan(placed_port_r) else placed_port_r


var _tbody: ConveyorTBody


var _hold_s:= 0.0


var _split_s:= 0.0


static var share_lane_enabled:= true


var _clear:= [0.0, 0.0]
var _holding:= false

var _marks: Array [Dictionary] = []

var _last_s:= { }

var _stuck:= [false, false]


var _route_local:= { }

var _gate_speed:= 0.0

var _swing_t:= 0.0


var _ground_d:= 0.0


var _step_dt:= 1.0 / 60.0

var _parked:= false


var _tight_t:= 0.0
var _loose_t:= 0.0


var _last_want:= NAN
var _same_way_t:= 0.0


var _lead_id:= 0
var _since_lead:= 0.0
var _arrival:= INF


static var old_arm:= false


static func lane_mouth(lane: int, r: float) -> Vector3:
	return lane_out(lane) * r


func mouth_of(lane: int) -> Vector3:
	return lane_out(lane) * port_r


static func leg_inset(r: float) -> float:
	return r - 0.36


static func lane_out(lane: int) -> Vector3:
	match lane:
		BAR_POS:
			return Vector3(1.0, 0.0, 0.0)
		BAR_NEG:
			return Vector3(-1.0, 0.0, 0.0)
		_:
			return Vector3(0.0, 0.0, -1.0)


static func exits_of(feed: int) -> Array [int]:
	match feed:
		BAR_POS:
			return [BAR_NEG, STEM]
		BAR_NEG:
			return [STEM, BAR_POS]
		_:
			return [BAR_POS, BAR_NEG]


static func blade_angle(feed: int, arm: int) -> float:
	match feed:
		BAR_POS:
			return Cfg.T_SPLITTER_SWING if arm == STEM else Cfg.T_SPLITTER_PARK
		BAR_NEG:
			return - Cfg.T_SPLITTER_SWING if arm == STEM else - Cfg.T_SPLITTER_PARK
		_:
			return Cfg.T_SPLITTER_SWING if arm == BAR_POS else - Cfg.T_SPLITTER_SWING


static func names_a_lane(feed: int, angle: float) -> bool:
	if is_equal_approx(absf(angle), Cfg.T_SPLITTER_PARK):
		return true
	for arm: int in exits_of(feed):
		if is_equal_approx(angle, blade_angle(feed, arm)):
			return true
	return false


static func in_sweep(p: Vector3, reach: float, from: float, to: float) -> bool:
	var q:= Vector2(p.x, p.z - Cfg.T_SPLITTER_PIVOT_Z)
	var r:= q.length()
	var pad:= reach + BLADE_HALF
	if r > BLADE_REACH + pad:
		return false
	if r <= pad:
		return true
	var phi:= atan2(- q.x, - q.y)
	var widen:= asin(clampf(pad / r, 0.0, 1.0))
	return phi >= minf(from, to) - widen and phi <= maxf(from, to) + widen


static func in_swing(p: Vector3, reach: float, from: float, to: float) -> bool:
	var q:= Vector2(p.x, p.z - Cfg.T_SPLITTER_PIVOT_Z)
	var r:= q.length()
	var pad:= reach + BLADE_HALF
	if r > BLADE_REACH + pad:
		return false
	var phi:= atan2(- q.x, - q.y)
	if r <= pad:

		return (phi - from) * (to - from) > 0.0
	var widen:= asin(clampf(pad / r, 0.0, 1.0))
	if to >= from:
		return phi >= from and phi <= to + widen
	return phi <= from and phi >= to - widen


func port_in() -> Vector3:
	return to_global(mouth_of(entry))


func port_left() -> Vector3:
	return to_global(mouth_of(exits_of(entry) [LEFT]))


func port_right() -> Vector3:
	return to_global(mouth_of(exits_of(entry) [RIGHT]))


func forward() -> Vector3:
	return (global_basis * - lane_out(entry)).normalized()


func arm_travel(side: int) -> Vector3:
	return (global_basis * lane_out(exits_of(entry) [side])).normalized()


func straight_side() -> int:
	if entry == BAR_POS:
		return LEFT
	if entry == BAR_NEG:
		return RIGHT
	return -1


func lane_at(point: Vector3) -> int:
	for lane in LANES:
		if PointIndex.joins(to_global(mouth_of(lane)), point):
			return lane
	return -1


func _mouths() -> Array:
	return [mouth_of(STEM), mouth_of(BAR_POS), mouth_of(BAR_NEG)]


func _lanes() -> Array:
	var out: Array = []
	for lane in LANES:
		out.append({ "mouth": mouth_of(lane), "travel": _lane_travel(lane) })
	return out


func _sweep_lanes() -> Array:
	return _lanes()


func _lane_travel(lane: int) -> Vector3:
	return - lane_out(lane) if lane == entry else lane_out(lane)


func setups() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	var order: Array [int] = [entry]
	for lane in LANES:
		if lane != entry:
			order.append(lane)
	for lane in order:
		if not leaving.has(lane) and arriving.all(func(a: int) -> bool: return a == lane):
			out.append({ "ins": [lane] })
	for lane in LANES:
		var ins: Array [int] = []
		for other in LANES:
			if other != lane:
				ins.append(other)
		if not leaving.has(ins [0]) and not leaving.has(ins [1]) and not arriving.has(lane):
			out.append({ "ins": ins, "out": lane })
	return out


func show_possible(on: bool, delta: float) -> void:
	var all: Array [Dictionary] = []
	if on and not placement_preview and _tbody != null:
		all = setups()
	if all.size() < 2:
		if _showing:
			_showing = false
			_shown_setup = { }
			_show_hints(false)
			_refresh_readout()
			_apply_scroll()
		return
	if not _showing:
		_showing = true
		_show_i = 0
		_show_t = 0.0
		_show_hints(true)
		_draw_setup(all [0])
		return
	_show_t += delta
	if _show_t < SHOW_EACH:
		return
	_show_t = fmod(_show_t, SHOW_EACH)
	_show_i = (_show_i + 1) % all.size()
	_draw_setup(all [_show_i])


func is_showing() -> bool:
	return _showing


func shown_setup() -> Dictionary:
	return _shown_setup


func hint_shown(lane: int) -> bool:
	var hint:= _hints.get(lane) as Node3D
	return hint != null and hint.visible


func _draw_setup(setup: Dictionary) -> void:
	_shown_setup = setup
	if fed:
		return
	var ins: Array = setup ["ins"]
	var travel:= { }
	for lane in LANES:
		travel [lane] = - lane_out(lane) if ins.has(lane) else lane_out(lane)
	_tbody.apply_scroll(travel, false)
	if ins.size() == 1:
		var arms:= exits_of(int(ins [0]))
		_tbody.show_split(0.0, int(ins [0]), arms [LEFT], arms [RIGHT], tr("ONE IN, TWO OUT"))
	else:
		_tbody.show_merge(int(setup ["out"]), int(ins [0]), tr("TWO IN, ONE OUT"))


func _show_hints(on: bool) -> void:
	var laid:= not leaving.is_empty() or not arriving.is_empty()
	if on and laid and _hints.is_empty():
		_make_hints()
	for lane: int in _hints:
		(_hints [lane] as Node3D).visible = on and laid and not leaving.has(lane) and not arriving.has(lane)


func _make_hints() -> void:
	for lane in LANES:
		var hint:= Node3D.new()
		hint.name = "Hint%d" % lane
		hint.position = mouth_of(lane) + lane_out(lane) * 0.12 + Vector3(0.0, 0.2, 0.0)
		hint.visible = false
		hint.add_child(_hint_label("?", 72, Vector3(0.0, 0.09, 0.0)))
		hint.add_child(_hint_label(tr("Connect belt IN or OUT"), 38, Vector3.ZERO))
		add_child(hint)
		_hints [lane] = hint


static func _hint_label(words: String, size: int, at: Vector3) -> Label3D:
	var label:= Label3D.new()
	label.text = words
	label.font = UiFont.bold()
	label.font_size = size
	label.pixel_size = 0.0025
	label.outline_size = 12
	label.outline_modulate = Color(0.08, 0.08, 0.08, 0.85)
	label.modulate = Color(0.96, 0.96, 0.93)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = at
	return label


func _pad_centre(lane: Dictionary) -> Vector3:
	var mouth: Vector3 = lane ["mouth"]
	return mouth.normalized() * leg_inset(port_r) + Vector3.DOWN * LEG_DEPTH


func _leg_half_width() -> float:
	return LEG_HALF


func footprint() -> Array [Vector4]:
	return footprint_of(self)


static func footprint_of(t: Node3D) -> Array [Vector4]:
	var out: Array [Vector4] = []
	var c:= t.global_position
	out.append(Vector4(c.x, c.y, c.z, HUB_R))
	var r: float = t.get("port_r")


	for lane in LANES:
		var d:= r - 0.5
		while true:
			var p:= t.to_global(lane_out(lane) * d)
			out.append(Vector4(p.x, p.y, p.z, 0.5))
			d -= 0.5
			if d < HUB_R:
				break
	return out


func build_cost() -> float:
	return Cfg.T_SPLITTER_COST


func to_dict() -> Dictionary:
	var d:= super ()
	d ["type"] = "conveyor_t_splitter"
	d ["entry"] = entry
	d ["port_r"] = port_r
	return d


func set_entry(feed: int) -> void:
	feed = clampi(feed, STEM, BAR_NEG)
	if feed == entry:
		return
	var old:= exits_of(entry)
	var pinned:= old [forced_side] if forced_side >= 0 else -1
	var main:= old [priority_side] if priority_side >= 0 else -1
	var turn_lane:= old [next_side]
	entry = feed
	YardPorts.touch()
	var now:= exits_of(entry)
	forced_side = now.find(pinned)
	priority_side = now.find(main)
	next_side = maxi(now.find(turn_lane), LEFT)
	if forced_side >= 0:
		next_side = forced_side
	elif priority_side >= 0:
		next_side = priority_side
	_refresh_readout()
	_apply_scroll()


	_parked = false
	_tight_t = 0.0
	_loose_t = 0.0
	_lead_id = 0
	_since_lead = 0.0
	_arrival = INF
	if _routes.is_empty():
		_gate_angle = _gate_target()
		_apply_gate()
		return
	_set_hold(false)
	_build_routes()
	_sync_feeder()
	call_deferred("refresh_supports")


func _build_model() -> void:
	_tbody = ConveyorTBody.new()
	_tbody.name = "Body"

	_tbody.fast = true
	add_child(_tbody)
	_tbody.build(placement_preview, port_r)
	_apply_scroll()
	_refresh_readout()
	if placement_preview:
		_gate_angle = _gate_target()
		_apply_gate()


func _apply_scroll() -> void:


	if _tbody == null or (_showing and not fed):
		return
	var travel:= { }
	for lane in LANES:
		travel [lane] = _lane_travel(lane)
	_tbody.apply_scroll(travel, _drawn_held)


func _show_held() -> void:
	_apply_scroll()


func set_fed(on: bool) -> void:
	if on == fed:
		return
	fed = on


	show_possible(false, 0.0)
	_refresh_readout()


func _refresh_readout() -> void:
	if _tbody == null or (_showing and not fed):
		return
	var arms:= exits_of(entry)


	var words:= setting_name() if fed or placement_preview else tr("NO BELT IN")
	_tbody.show_split(_screen_mode(), entry, arms [LEFT], arms [RIGHT], words)


func name_for(id: String) -> String:
	var straight:= straight_side()
	if straight >= 0:
		if id == (SET_PIN_LEFT if straight == LEFT else SET_PIN_RIGHT):
			return tr("STRAIGHT ON")
		if id == (SET_MAIN_LEFT if straight == LEFT else SET_MAIN_RIGHT):
			return tr("STRAIGHT FIRST")
	return super (id)


func mode_label() -> String:
	var straight:= straight_side()
	if straight < 0:
		return super ()


	if forced_side == straight:
		return tr("straight on only")
	if forced_side >= 0:
		return tr("left side only") if straight == RIGHT else tr("right side only")
	if priority_side == straight:
		return tr("straight on first, left when it backs up") if straight == RIGHT else tr("straight on first, right when it backs up")
	if priority_side >= 0:
		return tr("left side first, straight on when it backs up") if straight == RIGHT else tr("right side first, straight on when it backs up")
	return super ()


func _make_infill() -> MeshInstance3D:


	var mi:= MeshInstance3D.new()
	mi.name = "Infill"
	return mi


func _make_infill_body() -> StaticBody3D:
	return ConveyorTBody.floor_body(JUNCTION_HALF)


func _make_sweep() -> Area3D:
	return WyeSweep.make_lane_area(_sweep_lanes(), HUB_R)


func _build_routes() -> void:
	for side in SIDES:
		var route:= _routes.get(side) as BeltPath
		var fresh:= route == null
		if fresh:
			route = BeltPath.new()
			route.name = "Route%s" % ("Left" if side == LEFT else "Right")

			route.records_props = true
			route.record_boost = route_boost
		var points:= _route_points(side)
		route.open_windows = _junction_windows(points)
		if fresh:
			add_child(route)
			route.gathers_straw = true
			route.caught.connect(_on_caught.bind(side))
			route.caught_record.connect(_on_caught_record.bind(side))
			_routes [side] = route
		route.build_path(points, Cfg.BELT_JOINT_OVERLAP)
		route.set_belt_drawn(false)
	for side in SIDES:
		var route:= _routes.get(side) as BeltPath
		if route != null:
			route.share_deck([_routes.get(_other(side)) as BeltPath])
	_measure_arm()
	_apply_catching()


func _route_points(side: int) -> PackedVector3Array:
	var arm:= exits_of(entry) [side]
	var d_in:= - lane_out(entry)
	var d_out:= lane_out(arm)
	var local:= PackedVector3Array([mouth_of(entry), - d_in * ARC_R])
	if not d_out.is_equal_approx(d_in):
		var start:= - d_in * ARC_R
		var centre:= start + d_out * ARC_R
		for k in range(1, ARC_PIECES):
			var t:= PI * 0.5 * float(k) / float(ARC_PIECES)
			local.append(centre - d_out * (ARC_R * cos(t)) + d_in * (ARC_R * sin(t)))
	local.append(d_out * ARC_R)
	local.append(mouth_of(arm))
	_route_local [side] = local
	var out:= PackedVector3Array()
	for p in local:
		out.append(to_global(p))

	out [0] = port_in()
	out [out.size() - 1] = port(side)
	return out


func _junction_windows(points: PackedVector3Array) -> Array [Dictionary]:
	var length:= 0.0
	for i in range(1, points.size()):
		length += points [i - 1].distance_to(points [i])
	var lane:= port_r - JUNCTION_HALF
	var out: Array [Dictionary] = []
	for sgn in [-1, 1]:
		out.append({ "side": sgn, "from": lane, "to": length - lane })
	return out


func _measure_arm() -> void:
	var arms:= exits_of(entry)
	var a0:= blade_angle(entry, arms [LEFT])
	var a1:= blade_angle(entry, arms [RIGHT])
	_swing_t = swing_time(a1 - a0)
	const STEP:= 0.01
	var r:= port_r


	_split_s = r - ARC_R
	_hold_s = _split_s
	var d:= r
	while d > ARC_R:
		if in_sweep(lane_out(entry) * d, 0.0, a0, a1):
			_hold_s = maxf(0.0, r - d - STEP)
			break
		d -= STEP
	for side in SIDES:
		var out:= lane_out(arms [side])
		_clear [side] = 0.0
		d = r
		while d > 0.0:
			if in_sweep(out * d, 0.0, a0, a1):
				_clear [side] = d + STEP
				break
			d -= STEP


	_ground_d = maxf(r + maxf(_clear [LEFT], _clear [RIGHT]) - _hold_s, 0.0)


func factory_tick(delta: float) -> void:
	_step_dt = delta
	var t:= Time.get_ticks_usec() if profile else 0
	if profile:
		cost_us ["ticks"] = int(cost_us.get("ticks", 0)) + 1
	_reroute()
	t = _lap("reroute", t)
	_note_motion()
	t = _lap("note_motion", t)
	_tick_stalls(delta)
	t = _lap("tick_stalls", t)
	_apply_catching()
	t = _lap("apply_catching", t)
	_refresh_held()
	t = _lap("refresh_held", t)
	var side:= _open_side()
	if side < 0:
		side = _rest_side()


	if _sweep != null and _sweep.has_overlapping_bodies():
		WyeSweep.run(_sweep, self, _sweep_lanes(), Cfg.BELT_SPEED,
			lane_out(exits_of(entry) [side]))
	t = _lap("sweep", t)
	_steer(delta)
	t = _lap("steer", t)
	_share_lane()
	_lap("share_lane", t)


static var profile:= false
static var cost_us:= { }


func _lap(part: String, since: int) -> int:
	if not profile:
		return 0
	var now:= Time.get_ticks_usec()
	cost_us [part] = int(cost_us.get(part, 0)) + now - since
	return now


func _share_lane() -> void:
	var left:= _routes.get(LEFT) as BeltPath
	var right:= _routes.get(RIGHT) as BeltPath
	if left == null or right == null:
		return
	if not share_lane_enabled:
		left.set_foreign_loads(PackedFloat64Array())
		right.set_foreign_loads(PackedFloat64Array())
		return
	var on_left:= left.lane_loads_before(_split_s)
	left.set_foreign_loads(right.lane_loads_before(_split_s))
	right.set_foreign_loads(on_left)


func _share_now() -> void:
	_share_lane()


func _steer(delta: float) -> void:
	var marks:= _marks


	var lead: Dictionary = { }
	var lead_front:= - INF
	for m in marks:
		var front:= float(m ["s"]) + float(m ["reach"])
		if front > _hold_s + BeltPath.HOLD_SLACK:
			continue
		if front > lead_front:
			lead = m
			lead_front = front
	var want:= _gate_target()
	if forced_side < 0 and not lead.is_empty():
		want = blade_angle(entry, exits_of(entry) [int(lead ["side"])])
	_note_traffic(want, _headway(lead, delta), delta)
	if _parked:
		want = _open_angle()


		if not is_zero_approx(_gate_speed) and names_a_lane(entry, _swing_goal) and not is_equal_approx(_swing_goal, want) and not old_arm:
			want = _swing_goal
	if is_equal_approx(_gate_angle, want):
		_gate_speed = 0.0
	elif (not is_zero_approx(_gate_speed) or not names_a_lane(entry, _gate_angle)) and not old_arm:


		_swing_to(want, delta)
	elif _parked and (_arm_blocked(marks, want, _lane_speed())
			or _arm_late(lead, want, _lane_speed())):


		_gate_speed = 0.0
	elif _arm_blocked(marks, want) and not _arm_late(lead, want):
		_gate_speed = 0.0
	else:
		_swing_to(want, delta)


	var hold:= false
	if not lead.is_empty() and bool(lead ["prop"]):
		var front:= float(lead ["s"]) + float(lead ["reach"])
		var look:= _lane_speed() * delta * 2.0 + BeltPath.HOLD_SLACK
		if front >= _hold_s - look:
			var lead_side:= int(lead ["side"])
			if not _arm_has_room_for(lead_side, float(lead ["reach"])):
				hold = true

				_give_to_other(lead)
	_set_hold(hold)


const PARK_AFTER:= 0.25
const UNPARK_AFTER:= 1.0


func _headway(lead: Dictionary, delta: float) -> float:
	_since_lead += delta
	if not lead.is_empty():
		var id:= int(lead ["id"])
		if id != _lead_id:
			if _lead_id != 0:
				_arrival = _since_lead
			_lead_id = id
			_since_lead = 0.0
	return maxf(_arrival, _since_lead)


func _note_traffic(want: float, head: float, delta: float) -> void:
	if old_arm:
		return


	var room:= head >= _swing_t + _ground_d / maxf(Tech.belt_speed(), 0.01) + _late(_step_dt)


	if _stuck [LEFT] or _stuck [RIGHT]:
		room = false
	if is_equal_approx(want, _last_want):
		_same_way_t += delta
	else:
		_last_want = want
		_same_way_t = 0.0
	if _parked:


		_loose_t = _loose_t + delta if room else 0.0


		var steady:= forced_side >= 0 or _same_way_t >= UNPARK_AFTER
		if _loose_t >= UNPARK_AFTER or steady:
			_parked = false
			_tight_t = 0.0
		return


	var steady:= forced_side >= 0 or _same_way_t >= UNPARK_AFTER
	_tight_t = 0.0 if room or steady or is_equal_approx(_gate_angle, want) else _tight_t + delta
	if _tight_t >= PARK_AFTER:
		_parked = true
		_loose_t = 0.0


func _open_angle() -> float:
	match entry:
		BAR_POS:
			return Cfg.T_SPLITTER_PARK
		BAR_NEG:
			return - Cfg.T_SPLITTER_PARK
		_:
			return Cfg.T_SPLITTER_PARK if _gate_angle >= 0.0 else - Cfg.T_SPLITTER_PARK


var _swing_goal:= 0.0


func _swing_to(to: float, delta: float) -> void:
	_swing_goal = to
	var step:= arm_step(_gate_angle, _gate_speed, to, delta)
	_gate_angle = step.x
	_gate_speed = step.y
	_apply_gate()


static func swing_time(span: float) -> float:
	span = absf(span)
	var v:= Cfg.T_SPLITTER_ARM_SPEED
	var a:= Cfg.T_SPLITTER_ARM_ACCEL
	if span <= v * v / a:
		return 2.0 * sqrt(span / a)
	return span / v + v / a


func _lane_speed() -> float:
	return Tech.belt_speed() * route_boost


func _arm_late(lead: Dictionary, to: float, ride:= -1.0) -> bool:
	if lead.is_empty():
		return false
	var front:= float(lead ["s"]) + float(lead ["reach"])
	var at:= ride if ride > 0.0 else Tech.belt_speed()
	var arrive:= maxf(_hold_s - front, 0.0) / maxf(at, 0.01)
	var swing:= absf(to - _gate_angle) / Cfg.T_SPLITTER_ARM_SPEED + Cfg.T_SPLITTER_ARM_SPEED / Cfg.T_SPLITTER_ARM_ACCEL + _late(_step_dt)
	return arrive <= swing


func _give_to_other(lead: Dictionary) -> bool:
	if forced_side >= 0:
		return false
	var from_side:= int(lead ["side"])
	var onto_side:= _other(from_side)
	var from:= _routes.get(from_side) as BeltPath
	var onto:= _routes.get(onto_side) as BeltPath
	if from == null or onto == null:
		return false
	if not _arm_has_room_for(onto_side, float(lead ["reach"])):
		return false
	return _pass(lead, from, onto, onto_side)


func _pass(m: Dictionary, from: BeltPath, onto: BeltPath, onto_side: int) -> bool:
	if m ["body"] == null:
		var seq:= int(m ["seq"])
		if not from.pass_record_to(seq, onto):
			return false
		rerouted_record.emit(seq, onto_side)
		_share_now()
		return true
	if not is_instance_valid(m ["body"]):
		return false
	var body:= m ["body"] as RigidBody3D
	if body == null or not from.pass_rider_to(body, onto):
		return false
	rerouted.emit(body, onto_side)
	_share_now()
	return true


static func arm_step(angle: float, speed: float, to: float, delta: float) -> Vector2:
	var left:= to - angle
	var brake:= sqrt(2.0 * Cfg.T_SPLITTER_ARM_ACCEL * absf(left))
	var wanted:= signf(left) * minf(Cfg.T_SPLITTER_ARM_SPEED, brake)
	speed = move_toward(speed, wanted, Cfg.T_SPLITTER_ARM_ACCEL * delta)
	var moved:= speed * delta
	if absf(moved) >= absf(left) or (absf(left) < 0.002 and absf(speed) < 0.2):
		return Vector2(to, 0.0)
	return Vector2(angle + moved, speed)


func _arm_blocked(marks: Array [Dictionary], to: float, ride:= -1.0) -> bool:
	const DT:= 1.0 / 30.0
	const STEP:= 0.05

	var belt:= ride if ride > 0.0 else Tech.belt_speed()
	if profile:
		cost_us ["arm_blocked calls"] = int(cost_us.get("arm_blocked calls", 0)) + 1
	for m in marks:
		if not bool(m ["prop"]):
			continue
		var s:= float(m ["s"])
		var reach:= float(m ["reach"])
		if s + reach <= _hold_s + BeltPath.HOLD_SLACK:
			continue
		var side:= int(m ["side"])
		var line: PackedVector3Array = _route_local.get(side, PackedVector3Array())
		var length:= _line_length(line)

		var p:= to_local((_routes [side] as BeltPath).mark_pos(m))
		var at_rest:= bool(_stuck [side])
		if at_rest:
			if in_sweep(p, reach, _gate_angle, to):
				return true
		else:
			var angle:= _gate_angle
			var speed:= _gate_speed


			var lag:= _late(_step_dt)
			var t:= lag
			while not is_equal_approx(angle, to) and t < 3.0 + lag:
				var step:= arm_step(angle, speed, to, DT)
				t += DT


				var here:= p if t <= DT + lag else _line_point(line, s + belt * t)
				if in_swing(here, reach, angle, step.x):
					return true
				angle = step.x
				speed = step.y
			s += belt * t


		if is_equal_approx(blade_angle(entry, exits_of(entry) [side]), to):
			continue
		while s < length:
			if in_sweep(_line_point(line, s), reach, to, to):
				return true
			s += STEP
	return false


static func _line_length(line: PackedVector3Array) -> float:
	var length:= 0.0
	for i in range(1, line.size()):
		length += line [i - 1].distance_to(line [i])
	return length


static func _line_point(line: PackedVector3Array, s: float) -> Vector3:
	if line.is_empty():
		return Vector3.ZERO
	for i in range(1, line.size()):
		var span:= line [i - 1].distance_to(line [i])
		if s <= span:
			return line [i - 1].lerp(line [i], s / maxf(span, 1e-06))
		s -= span
	return line [line.size() - 1]


func _arm_has_room_for(side: int, reach: float) -> bool:
	var route:= _routes.get(side) as BeltPath
	if route == null:
		return false
	if _has_room(side):
		return true
	var dir:= arm_travel(side)
	var far:= port_r - 0.05
	var near:= minf(float(_clear [side]) + reach, far)
	return route.has_room_near(global_position + dir * near) and route.has_room_near(global_position
			+ dir * minf(near + reach + Cfg.BELT_RIDE_SPACING, far))


func _set_hold(on: bool) -> void:
	if on == _holding:
		return
	_holding = on
	for route in routes():
		route.hold_before(_hold_s if on else -1.0)


func is_holding() -> bool:
	return _holding


func hold_s() -> float:
	return _hold_s


func arm_angle() -> float:
	return _gate_angle


func arm_parked() -> bool:
	return _parked


func _has_room(side: int) -> bool:
	if _routes.get(side) == null:
		return false
	return not bool(_stuck [side])


func _backed_up(side: int) -> bool:
	return not _has_room(side)


func _queue_at_throat(_side: int) -> bool:
	return false


func _unjam_throat() -> void:
	pass


func _throat_parked(_side: int) -> bool:
	return false


func _note_motion() -> void:
	_marks.clear()
	_stuck = [false, false]
	var seen:= { }
	for side in SIDES:
		var route:= _routes.get(side) as BeltPath
		if route == null:
			continue
		for m in route.load_marks(false):
			m ["side"] = side
			_marks.append(m)
			var id: int = m ["id"]
			var s:= float(m ["s"])


			if s + float(m ["reach"]) > _hold_s + BeltPath.HOLD_SLACK and s - float(m ["reach"]) >= _split_s and _last_s.has(id) and s <= float(_last_s [id]) + 1e-05:
				_stuck [side] = true
				if OS.has_environment("TRACE_T"):
					var nxt:= route.downstream
					var ahead:= -1.0
					if nxt != null:
						for n in nxt.load_marks():
							if ahead < 0.0 or float(n ["s"]) < ahead:
								ahead = float(n ["s"])
					var r:= route.run
					var d:= r.downstream
					var why:= "no_downstream"
					if d != null:
						why = "catching=%s blocked=%s gate=%s gate_ok=%s limit=%.3f" % [str(d.catching), str(d.blocked),
							str(d.mouth_gate.is_valid()),
							str(float(d.mouth_gate.call(float(m ["reach"]), r))) if d.mouth_gate.is_valid() else "-",
							d.mouth_limit(float(m ["reach"]), Cfg.BELT_RIDE_SPACING, 0, r)]
					print("STUCK f%d side=%d s=%.3f len=%.3f next_first=%.3f %s | jam=%d free=%d parked=%s jam_limit=%.3f hold_line=%.3f blockers=%d head=%d n=%d jam_speed=%.3f spd=%.3f park=%.3f" % [
						Engine.get_physics_frames(), side, s, route.path_length(), ahead, why,
						r._jam, r._free, str(r._jam_parked), r._jam_limit, r._hold_line, r._blockers.size(),
						r._head, r._pos.size(), r._jam_speed, r.speed, r._park_s(float(m ["reach"]))])
			seen [id] = s
	_last_s = seen


func _gate_target() -> float:
	return blade_angle(entry, exits_of(entry) [_rest_side()])


func _only_side() -> int:
	return forced_side


func _rest_side() -> int:
	var only:= _only_side()
	return only if only >= 0 else next_side


func _sync_feeder(open: int = -2) -> void:
	var side: int = _open_side() if open == -2 else open
	super (side if side >= 0 else _only_side())


func _reroute() -> void:
	var only:= _only_side()
	if only < 0 or _routes.size() < 2:
		return
	var from:= _routes.get(_other(only)) as BeltPath
	var onto:= _routes.get(only) as BeltPath
	if from == null or onto == null:
		return
	for m in from.load_marks(false):
		if float(m ["s"]) + float(m ["reach"]) > _hold_s + BeltPath.HOLD_SLACK:
			continue
		_pass(m, from, onto, only)


func _apply_gate() -> void:
	if _tbody != null:
		_tbody.set_arm_angle(_gate_angle)


func set_preview_valid(valid: bool) -> void:
	if placement_preview and _tbody != null:
		_tbody.set_ghost(valid)


func body() -> ConveyorTBody:
	return _tbody


func _idle_key() -> Array:
	var key:= super ()
	key.append_array([entry, _clear [0], _clear [1], _holding, _marks.size(),
		_stuck [0], _stuck [1], _gate_speed, _hold_s, _parked])
	return key
