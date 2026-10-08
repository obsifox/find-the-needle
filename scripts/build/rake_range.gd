class_name RakeRange
extends Node3D


const LIFT:= 0.05

const BAND:= 0.07


const MIN_TARGET:= 0.55


const COL_BITE:= Color(0.28, 1.0, 0.42, 0.55)
const COL_THROW:= Color(1.0, 0.86, 0.34, 0.6)

var _bite: MeshInstance3D
var _bite_mat: StandardMaterial3D
var _track: MeshInstance3D
var _track_mat: StandardMaterial3D
var _target: MeshInstance3D
var _target_mat: StandardMaterial3D


var _drawn_for:= NAN


func _ready() -> void:
	position.y = LIFT
	_bite = _mark(COL_BITE)
	_bite_mat = _bite.material_override as StandardMaterial3D
	_track = _mark(Color(COL_THROW.r, COL_THROW.g, COL_THROW.b, 0.22))
	_track_mat = _track.material_override as StandardMaterial3D
	_target = _mark(COL_THROW)
	_target_mat = _target.material_override as StandardMaterial3D


func set_bite_disc(reach: float, radius: float) -> void:
	_bite.mesh = _ring_at(reach, radius)


func set_throw(metres: float, spread: float) -> void:
	if not is_nan(_drawn_for) and absf(_drawn_for - metres) < 0.005:
		return
	_drawn_for = metres

	_target.position.z = - metres
	_target.mesh = HayDrone.ring_mesh(maxf(spread, MIN_TARGET), BAND, 48)
	if _track.mesh == null:
		_track.mesh = _outline(- BAND * 0.5, BAND * 0.5,
			- Cfg.RAKE_THROW_MAX, - Cfg.RAKE_THROW_MIN)


func set_throw_marks_shown(on: bool) -> void:
	_track.visible = on
	_target.visible = on


func throw_marks_shown() -> bool:
	return _target != null and _target.visible


func set_preview_valid(valid: bool) -> void:
	var tint: Color = Cfg.COL_GHOST_OK if valid else Cfg.COL_GHOST_BAD
	for mat: StandardMaterial3D in [_bite_mat, _target_mat]:
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	_track_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.2)


func bite_bounds() -> AABB:
	if _bite == null or _bite.mesh == null:
		return AABB()
	return _bite.get_aabb()


func target_offset() -> float:
	return - _target.position.z if _target != null else 0.0


func _mark(colour: Color) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:= StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


	mat.cull_mode = BaseMaterial3D.CULL_DISABLED


	mat.no_depth_test = true
	mat.albedo_color = colour


	mi.material_override = mat
	mi.sorting_offset = 0.0
	mat.render_priority = 4
	add_child(mi)
	return mi


static func _outline(x0: float, x1: float, z0: float, z1: float) -> ArrayMesh:
	var verts:= PackedVector3Array()
	var idx:= PackedInt32Array()
	var b:= BAND * 0.5
	for side: Array in [
			[x0 - b, x1 + b, z0 - b, z0 + b],
			[x0 - b, x1 + b, z1 - b, z1 + b],
			[x0 - b, x0 + b, z0 + b, z1 - b],
			[x1 - b, x1 + b, z0 + b, z1 - b]]:
		var base:= verts.size()
		verts.append(Vector3(side [0], 0.0, side [2]))
		verts.append(Vector3(side [1], 0.0, side [2]))
		verts.append(Vector3(side [1], 0.0, side [3]))
		verts.append(Vector3(side [0], 0.0, side [3]))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_INDEX] = idx
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _ring_at(at_z: float, radius: float) -> ArrayMesh:
	var mesh:= HayDrone.ring_mesh(radius, BAND, 64)
	var arrays:= mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts [i] = verts [i] + Vector3(0.0, 0.0, at_z)
	arrays [Mesh.ARRAY_VERTEX] = verts
	var out:= ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
