class_name LaunchArc
extends Node3D


const LIFT:= 0.05

const BAND:= 0.075


const MIN_TARGET:= 0.6


const ARC_WIDTH:= 0.05


const COL_ARC:= Color(1.0, 0.86, 0.34, 0.7)
const COL_RING:= Color(1.0, 0.86, 0.34, 0.6)

var _arc: MeshInstance3D
var _arc_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


var damped:= false

var _drawn_from:= Vector3.INF
var _drawn_vel:= Vector3.INF
var _drawn_ground:= NAN


func _ready() -> void:


	top_level = true
	_arc = _mark(COL_ARC)
	_arc_mat = _arc.material_override as StandardMaterial3D
	_ring = _mark(COL_RING)
	_ring_mat = _ring.material_override as StandardMaterial3D


func aim(from: Vector3, velocity: Vector3, ground_y: float,
		spread: float = Cfg.LAUNCHER_SPREAD) -> Vector3:
	if (from.is_equal_approx(_drawn_from) and velocity.is_equal_approx(_drawn_vel)
			and not is_nan(_drawn_ground) and absf(_drawn_ground - ground_y) < 0.001):
		return _ring.global_position
	_drawn_from = from
	_drawn_vel = velocity
	_drawn_ground = ground_y

	var points:= sample(from, velocity, ground_y, damped)
	_arc.mesh = _ribbon(points)
	var land: Vector3 = points [points.size() - 1]
	_ring.mesh = HayDrone.ring_mesh(maxf(spread, MIN_TARGET), BAND, 44)
	_ring.global_position = Vector3(land.x, ground_y + LIFT, land.z)
	return land


static func flight_time(from: Vector3, velocity: Vector3, ground_y: float,
		with_damping: bool = false) -> float:
	if with_damping:
		return float(fly(from, velocity, ground_y) ["seconds"])
	var g: float = absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))
	if g <= 0.0001:
		return 0.0
	var h: float = maxf(from.y - ground_y, 0.0)
	var disc: float = velocity.y * velocity.y + 2.0 * g * h
	return (velocity.y + sqrt(maxf(disc, 0.0))) / g


static func sample(from: Vector3, velocity: Vector3, ground_y: float,
		with_damping: bool = false) -> Array:
	if with_damping:
		return _thin(fly(from, velocity, ground_y) ["points"])
	var g: float = absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))


	var vy:= velocity.y
	var t_end: float = clampf(flight_time(from, velocity, ground_y),
		0.05, Cfg.LAUNCHER_ARC_MAX_SECONDS)

	var out: Array = []
	var steps: int = maxi(Cfg.LAUNCHER_ARC_STEPS, 2)
	for i in steps + 1:
		var t: float = t_end * float(i) / float(steps)
		out.append(Vector3(
			from.x + velocity.x * t,
			from.y + vy * t - 0.5 * g * t * t,
			from.z + velocity.z * t))


	var last: Vector3 = out [out.size() - 1]
	out [out.size() - 1] = Vector3(last.x, ground_y, last.z)
	return out


static func fly(from: Vector3, velocity: Vector3, ground_y: float) -> Dictionary:
	var g: float = absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))
	var c: float = float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	var dt: float = 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	var keep: float = maxf(0.0, 1.0 - c * dt)
	var ticks: int = ceili(Cfg.LAUNCHER_ARC_MAX_SECONDS / dt)
	var at:= from
	var v:= velocity
	var points:= PackedVector3Array([from])
	var t:= 0.0
	for _i in ticks:
		v.y -= g * dt
		v *= keep
		var next:= at + v * dt
		if next.y <= ground_y and v.y < 0.0:


			var f: float = clampf((at.y - ground_y) / maxf(at.y - next.y, 1e-06), 0.0, 1.0)
			var land:= at.lerp(next, f)
			points.append(Vector3(land.x, ground_y, land.z))
			return { "points": points, "seconds": t + dt * f }
		at = next
		t += dt
		points.append(at)


	points [points.size() - 1] = Vector3(at.x, ground_y, at.z)
	return { "points": points, "seconds": t }


static func _thin(points: PackedVector3Array) -> Array:
	var out: Array = []
	var n:= points.size()
	var steps: int = maxi(Cfg.LAUNCHER_ARC_STEPS, 2)
	if n <= steps + 1:
		for p in points:
			out.append(p)
		return out
	for i in steps + 1:
		out.append(points [roundi(float(i) * float(n - 1) / float(steps))])
	return out


func set_tint(colour: Color) -> void:
	if _arc_mat != null:
		_arc_mat.albedo_color = Color(colour.r, colour.g, colour.b, COL_ARC.a)
	if _ring_mat != null:
		_ring_mat.albedo_color = Color(colour.r, colour.g, colour.b, COL_RING.a)


func set_shown(on: bool) -> void:
	visible = on


func drawn() -> bool:
	return _arc != null and _arc.mesh != null and _ring != null and _ring.mesh != null


func landing_mark() -> Vector3:
	return _ring.global_position if _ring != null else Vector3.ZERO


func _ribbon(points: Array) -> ArrayMesh:
	var verts:= PackedVector3Array()
	var idx:= PackedInt32Array()
	var half:= ARC_WIDTH * 0.5
	for i in points.size():
		var p: Vector3 = points [i]
		var ahead: Vector3 = points [mini(i + 1, points.size() - 1)]
		var back: Vector3 = points [maxi(i - 1, 0)]
		var dir:= ahead - back
		dir.y = 0.0
		if dir.length_squared() < 1e-08:
			dir = Vector3.FORWARD
		var side:= dir.normalized().cross(Vector3.UP) * half


		verts.append(to_local(p - side))
		verts.append(to_local(p + side))
	for i in points.size() - 1:
		var o:= i * 2
		idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_INDEX] = idx
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mark(colour: Color) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m:= StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED


	m.no_depth_test = true
	m.render_priority = 1
	mi.material_override = m
	add_child(mi)
	return mi
