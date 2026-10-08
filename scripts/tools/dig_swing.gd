class_name DigSwing
extends RefCounted


class Beat:
	var t: float
	var fwd: float
	var up: float
	var pitch: float
	var roll: float
	var curve: float

	func _init(p_t: float, p_fwd: float, p_up: float, p_pitch: float,
			p_roll: float, p_curve: float) -> void:
		t = p_t
		fwd = p_fwd
		up = p_up
		pitch = p_pitch
		roll = p_roll
		curve = p_curve

	func pose() -> Vector4:
		return Vector4(fwd, up, deg_to_rad(pitch), deg_to_rad(roll))


const JAM:= 2
const HEAVE:= 3


const LIGHT_AMPLITUDE:= 0.6


const SHUDDER:= 0.004
const SHUDDER_HZ:= 23.0
const SHUDDER_DECAY:= 28.0


static var off: bool = "--noswing" in OS.get_cmdline_user_args()

var _keys: Array [Beat] = []

var _jams:= true
var _t:= -1.0
var _from:= Vector4.ZERO
var _strength:= 1.0
var _heaved:= false
var _heave_now:= false


func _init(keys: Array [Beat], jams: bool = true) -> void:
	_keys = keys
	_jams = jams


func start(strength: float) -> void:
	if off:
		return


	if _t >= 0.0 and _t < _keys [HEAVE].t:
		return
	_from = pose()
	_strength = clampf(strength, 0.0, 1.0)
	_t = 0.0
	_heaved = false
	_heave_now = false


func stop() -> void:
	_t = -1.0
	_heave_now = false


func is_swinging() -> bool:
	return _t >= 0.0


func elapsed() -> float:
	return _t


func tick(delta: float) -> bool:
	_heave_now = false
	if _t < 0.0:
		return false
	_t += delta
	if _t >= _keys [_keys.size() - 1].t:
		_t = -1.0
		return false
	if not _heaved and _t >= _keys [HEAVE - 1].t:
		_heaved = true

		_heave_now = _strength > 0.5
	return _heave_now


func pose() -> Vector4:
	if _t < 0.0:
		return Vector4.ZERO
	var amp:= lerpf(LIGHT_AMPLITUDE, 1.0, _strength)
	var prev_t:= 0.0
	var prev:= _from
	for i in _keys.size():
		var k:= _keys [i]
		var target:= k.pose() * amp
		if _t < k.t:
			var u:= (_t - prev_t) / maxf(k.t - prev_t, 0.0001)
			var out:= prev.lerp(target, ease(u, k.curve))
			if i == JAM and _jams:


				var since:= _t - prev_t
				var s:= SHUDDER * _strength * exp(- since * SHUDDER_DECAY) * sin(since * TAU * SHUDDER_HZ)
				out.y += s
				out.w += s * 6.0
			return out
		prev_t = k.t
		prev = target
	return Vector4.ZERO


func transform(grip: Vector3, min_pitch: float = - INF) -> Transform3D:
	var p:= pose()
	var pitch:= maxf(p.z, min_pitch)
	var b:= Basis.from_euler(Vector3(pitch, 0.0, p.w))
	var travel:= Vector3(0.0, p.y, - p.x)
	return Transform3D(b, grip - b * grip + travel)


static func spade() -> DigSwing:
	return DigSwing.new([
		Beat.new(0.04, 0.0, 0.005, 2.0, 0.0, 0.5),
		Beat.new(0.11, 0.0, -0.028, -7.0, 1.0, 2.0),
		Beat.new(0.16, 0.0, -0.03, -6.0, 1.0, 0.4),
		Beat.new(0.3, 0.0, 0.02, 6.0, 1.5, 0.35),
		Beat.new(0.38, 0.0, 0.0, 0.0, 0.0, -2.0),
		Beat.new(0.45, 0.0, 0.0, 0.0, 0.0, -2.0),
	])


static func fork() -> DigSwing:
	return DigSwing.new([
		Beat.new(0.045, 0.0, 0.005, 2.0, 0.0, 0.5),
		Beat.new(0.13, 0.0, -0.028, -7.0, 1.0, 2.0),
		Beat.new(0.18, 0.0, -0.03, -6.0, 1.5, 0.4),
		Beat.new(0.34, 0.0, 0.02, 6.0, 1.5, 0.35),
		Beat.new(0.42, 0.0, 0.0, 0.0, 0.0, -2.0),
		Beat.new(0.5, 0.0, 0.0, 0.0, 0.0, -2.0),
	])


static func toss() -> DigSwing:
	return DigSwing.new([
		Beat.new(0.05, 0.0, 0.008, 4.0, 0.0, 0.5),
		Beat.new(0.13, 0.0, -0.015, -14.0, -1.5, 2.0),
		Beat.new(0.2, 0.0, -0.015, -12.0, -1.0, 0.4),
		Beat.new(0.32, 0.0, 0.0, 0.0, 0.0, -2.0),
	], false)


static func toy_toss() -> DigSwing:
	return DigSwing.new([
		Beat.new(0.04, 0.0, 0.008, 5.0, 0.0, 0.5),
		Beat.new(0.11, 0.0, -0.015, -18.0, -2.0, 2.0),
		Beat.new(0.17, 0.0, -0.015, -15.0, -1.5, 0.4),
		Beat.new(0.27, 0.0, 0.0, 0.0, 0.0, -2.0),
	], false)


static func toy() -> DigSwing:
	return DigSwing.new([
		Beat.new(0.03, 0.0, 0.01, 4.0, 0.0, 0.5),
		Beat.new(0.09, 0.0, -0.045, -10.0, 1.5, 2.0),
		Beat.new(0.13, 0.0, -0.05, -9.0, 2.0, 0.4),
		Beat.new(0.24, 0.0, 0.04, 10.0, 2.0, 0.4),
		Beat.new(0.3, 0.0, -0.005, -1.0, -0.3, -2.0),
		Beat.new(0.35, 0.0, 0.0, 0.0, 0.0, -2.0),
	])
