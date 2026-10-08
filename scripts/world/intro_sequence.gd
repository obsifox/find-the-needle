class_name IntroSequence
extends Node


signal finished


const START_OUTBOARD:= 7.0


const START_PITCH:= 0.14


const WALK_DISTANCE:= 12.5


const ROOM_NOMINAL:= WALK_DISTANCE - START_OUTBOARD


const ROOM_MIN:= 2.0


const ROOM_CLEARANCE:= 1.2


const ROOM_HAY_DEPTH:= 0.25


const WALK_SPEED:= 2.0

const BRAKE_DISTANCE:= 1.1


const ARRIVE_EPSILON:= 0.18


const STALL_PATIENCE:= 1.5

const STALL_PROGRESS:= 0.05


const T_RISE_START:= 0.3
const T_WALK_START:= 1.4


const T_HOLD:= 0.55


const T_TURN_AFTER_SLAM:= 0.08


const D_TURN:= 0.32


const T_SETTLE:= 0.45
const D_HUD_FADE:= 0.6


const SFX_BOOST_DB:= 4.0

const BAR_FRACTION:= 0.125
const D_BARS_IN:= 0.7
const D_BARS_OUT:= 0.5


const BAR_LAYER:= 64


const TURN_SIGN:= -1.0


enum Look { AHEAD, SHOP, STAND }


const LOOK_KEYS:= [
	[0.0, Look.AHEAD],
	[0.3, Look.SHOP],
	[1.9, Look.STAND],
	[3.7, Look.AHEAD],
]


const LOOK_SMOOTH:= 0.22


const LOOK_DAMPING:= 0.75


const LOOK_RATE:= 3.75


const LOOK_STEP:= 1.0 / 120.0


const LOOK_MAX:= 0.87


const LOOK_FALLBACK:= { Look.SHOP: 1.0, Look.STAND: -1.0 }

enum Phase { WAIT, RISE, WALK, HOLD, SLAM, TURN, SETTLE, DONE }

var player: Player
var door: BayDoor
var hud: Control
var quests: Control


var cue: Control


var contracts: ContractPanel
var missions: Node


var shop: Node3D
var stand: Node3D


var field: HayField


var walk_dir:= Vector3.FORWARD

var _phase: Phase = Phase.DONE

var _clock:= 0.0
var _mark:= Vector3.ZERO


var _walk_distance:= WALK_DISTANCE


var _look_scale:= 1.0


var _base_yaw:= 0.0


var _look_yaw:= 0.0
var _look_vel:= 0.0
var _yaw_from:= 0.0
var _yaw_to:= 0.0
var _turn_t:= 0.0
var _pitch_to:= 0.0

var _closest:= INF
var _stalled:= 0.0


var _sfx_bus:= -1
var _sfx_base_db:= 0.0

var _bars: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _bar_tween: Tween


func _ready() -> void:
	set_process(false)
	_build_bars()


func _build_bars() -> void:
	_bars = CanvasLayer.new()
	_bars.name = "Letterbox"
	_bars.layer = BAR_LAYER
	add_child(_bars)
	_bar_top = _make_bar(Control.PRESET_TOP_WIDE)
	_bar_bottom = _make_bar(Control.PRESET_BOTTOM_WIDE)
	_bars.visible = false


func _make_bar(preset: Control.LayoutPreset) -> ColorRect:
	var r:= ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.set_anchors_and_offsets_preset(preset)


	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_bottom = r.anchor_top
	if preset == Control.PRESET_BOTTOM_WIDE:
		r.anchor_top = r.anchor_bottom
	_bars.add_child(r)
	return r


func _boost_sfx(on: bool) -> void:
	if on:
		if _sfx_bus >= 0:
			return
		_sfx_bus = AudioServer.get_bus_index(Audio.BUS_SFX)
		if _sfx_bus < 0:
			return
		_sfx_base_db = AudioServer.get_bus_volume_db(_sfx_bus)
		AudioServer.set_bus_volume_db(_sfx_bus, _sfx_base_db + SFX_BOOST_DB)
		return
	if _sfx_bus < 0:
		return
	AudioServer.set_bus_volume_db(_sfx_bus, _sfx_base_db)
	_sfx_bus = -1


func _set_bars(fraction: float, seconds: float) -> void:
	if _bars == null:
		return
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bars.visible = true
	if seconds <= 0.0:
		_bar_top.anchor_bottom = fraction
		_bar_bottom.anchor_top = 1.0 - fraction
		_bars.visible = fraction > 0.0
		return
	_bar_tween = create_tween().set_parallel(true)
	_bar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_property(_bar_top, "anchor_bottom", fraction, seconds)
	_bar_tween.tween_property(_bar_bottom, "anchor_top", 1.0 - fraction, seconds)
	if fraction <= 0.0:
		_bar_tween.chain().tween_callback(func() -> void: _bars.visible = false)


func is_running() -> bool:
	return _phase != Phase.DONE


func begin() -> void:
	if player == null or door == null:
		push_warning("IntroSequence: nothing to drive, skipping")
		_finish()
		return


	walk_dir = door.global_basis.z.normalized()
	walk_dir.y = 0.0
	walk_dir = walk_dir.normalized()
	var start:= door.inboard_point(- START_OUTBOARD)
	var room:= _room_inside(start)
	_walk_distance = START_OUTBOARD + room
	_look_scale = room / ROOM_NOMINAL
	_mark = start + walk_dir * _walk_distance
	player.global_position = start
	player.scripted = true
	player.scripted_move = Vector3.ZERO
	player.scripted_speed = WALK_SPEED


	_base_yaw = _yaw_facing(walk_dir)
	player.set_look(_base_yaw, START_PITCH)
	door.snap_shut()
	_set_ui(false)
	_set_bars(0.0, 0.0)
	_set_bars(BAR_FRACTION, D_BARS_IN)
	_boost_sfx(true)
	if missions != null:


		missions.process_mode = Node.PROCESS_MODE_DISABLED
	_phase = Phase.WAIT
	_clock = 0.0
	_look_yaw = 0.0
	_look_vel = 0.0
	_closest = INF
	_stalled = 0.0
	set_process(true)


func _room_inside(start: Vector3) -> float:
	if field == null:
		return ROOM_NOMINAL
	var step:= Cfg.CELL


	var d:= ROOM_MIN
	while d <= ROOM_NOMINAL + ROOM_CLEARANCE:
		var p:= start + walk_dir * (START_OUTBOARD + d)
		if field.depth_floor_at(p.x, p.z) > ROOM_HAY_DEPTH:
			return maxf(ROOM_MIN, d - ROOM_CLEARANCE)
		d += step
	return ROOM_NOMINAL


func abort() -> void:
	if _phase == Phase.DONE:
		return
	door.snap_shut()
	player.global_position = _mark
	player.velocity = Vector3.ZERO
	player.set_look(_yaw_facing(_to_door()), 0.0)
	_finish()


func _process(delta: float) -> void:
	_clock += delta
	match _phase:
		Phase.WAIT:
			if _clock >= T_RISE_START:
				door.open()
				_to(Phase.RISE)
		Phase.RISE:
			if _clock >= T_WALK_START - T_RISE_START:
				_to(Phase.WALK)
		Phase.WALK:
			_walk(delta)
		Phase.HOLD:
			if _clock >= T_HOLD:
				door.slam()
				_begin_turn()
				_to(Phase.SLAM)
		Phase.SLAM:
			if _clock >= T_TURN_AFTER_SLAM:
				_to(Phase.TURN)
		Phase.TURN:
			_turn(delta)
		Phase.SETTLE:
			if _clock >= T_SETTLE:
				_finish()
		Phase.DONE:
			pass


func _to(next: Phase) -> void:
	_phase = next
	_clock = 0.0


func _walk(delta: float) -> void:
	var to_mark:= _mark - player.global_position
	to_mark.y = 0.0
	var left:= to_mark.length()
	if left < _closest - STALL_PROGRESS:
		_closest = left
		_stalled = 0.0
	else:
		_stalled += delta
	if left <= ARRIVE_EPSILON or _stalled >= STALL_PATIENCE:
		player.scripted_move = Vector3.ZERO


		if _outboard():
			push_warning("IntroSequence: the walk in never made the doorway, "
				+ "standing the player on the mark")
			player.global_position = _mark
			player.velocity = Vector3.ZERO
		_to(Phase.HOLD)
		return
	player.scripted_move = to_mark


	player.scripted_speed = WALK_SPEED * clampf(left / BRAKE_DISTANCE, 0.22, 1.0)


	var gone:= 1.0 - clampf(left / _walk_distance, 0.0, 1.0)


	var past:= (_walk_distance - left) - START_OUTBOARD
	_drive_look(_look_wanted(past), delta)
	player.set_look(_base_yaw + _look_yaw,
		lerpf(START_PITCH, 0.0, clampf(gone / 0.66, 0.0, 1.0)))


func _look_wanted(past: float) -> float:
	var want: int = LOOK_KEYS [0] [1]
	for key: Array in LOOK_KEYS:
		if past < float(key [0]) * _look_scale:
			break
		want = key [1]
	return _look_offset(want)


func _drive_look(target: float, delta: float) -> void:
	var omega:= 2.0 / LOOK_SMOOTH
	var remaining:= delta
	while remaining > 0.0:
		var h:= minf(remaining, LOOK_STEP)
		remaining -= h
		var accel:= omega * omega * (target - _look_yaw) - 2.0 * LOOK_DAMPING * omega * _look_vel
		_look_vel = clampf(_look_vel + accel * h, - LOOK_RATE, LOOK_RATE)
		_look_yaw += _look_vel * h


func _look_offset(what: int) -> float:
	if what == Look.AHEAD:
		return 0.0
	var node: Node3D = shop if what == Look.SHOP else stand
	if node == null or not node.is_inside_tree():
		return float(LOOK_FALLBACK [what]) * LOOK_MAX
	var to_it:= node.global_position - player.global_position
	to_it.y = 0.0
	if to_it.length_squared() < 0.01:
		return 0.0
	return clampf(wrapf(_yaw_facing(to_it) - _base_yaw, - PI, PI),
		- LOOK_MAX, LOOK_MAX)


func _begin_turn() -> void:
	_yaw_from = player.rotation.y
	var want:= _yaw_facing(_to_door())


	var gap:= wrapf(want - _yaw_from, - TAU, 0.0) if TURN_SIGN < 0.0 else wrapf(want - _yaw_from, 0.0, TAU)
	_yaw_to = _yaw_from + gap
	var d:= _to_door()
	_pitch_to = atan2(d.y, Vector2(d.x, d.z).length())
	_turn_t = 0.0


func _turn(delta: float) -> void:
	_turn_t = minf(_turn_t + delta / D_TURN, 1.0)
	var k: float = Tween.interpolate_value(0.0, 1.0, _turn_t, 1.0,
		Tween.TRANS_BACK, Tween.EASE_OUT)
	player.set_look(lerpf(_yaw_from, _yaw_to, k), lerpf(0.0, _pitch_to, k))
	if _turn_t >= 1.0:
		_to(Phase.SETTLE)


func _finish() -> void:
	_phase = Phase.DONE
	set_process(false)
	if player != null:
		player.scripted = false
		player.scripted_move = Vector3.ZERO
	if door != null:
		door.snap_shut()
	if missions != null:
		missions.process_mode = Node.PROCESS_MODE_INHERIT
	_boost_sfx(false)
	_set_ui(true)


	_set_bars(0.0, D_BARS_OUT)
	finished.emit()


func _set_ui(on: bool) -> void:
	if contracts != null:
		contracts.set_suppressed(not on)
	for c: Control in [hud, quests, cue]:
		if c == null:
			continue
		if not on:
			c.modulate.a = 0.0
			c.visible = false
			continue
		c.visible = true
		var t:= create_tween()
		t.tween_property(c, "modulate:a", 1.0, D_HUD_FADE)


static func _yaw_facing(dir: Vector3) -> float:
	if Vector2(dir.x, dir.z).length_squared() < 1e-06:
		return 0.0
	return atan2(- dir.x, - dir.z)


func _to_door() -> Vector3:
	return door.focus_point() - player.eye_position()


func _outboard() -> bool:
	var past:= (player.global_position - door.inboard_point(0.0)).dot(walk_dir)
	return past < 0.0
