class_name CableTrace
extends Node3D


const GROUP:= "cable_traces"


const RADIUS:= 0.035

const GHOST_R:= 0.05


const COLOUR:= Color(1.0, 0.58, 0.1, 0.92)


static var _reasons: Dictionary = { }
static var _material: StandardMaterial3D = null


var _path:= PackedVector3Array()
var _mesh: MeshInstance3D = null


static func hang(parent: Node3D, from_ground: Vector3, to_ground: Vector3,
		riser_to: Vector3 = Vector3.INF) -> CableTrace:
	var trace:= CableTrace.new()
	trace.name = "CableTrace"
	trace._path = path(from_ground, to_ground, riser_to)
	parent.add_child(trace)
	return trace


static func path(from_ground: Vector3, to_ground: Vector3,
		riser_to: Vector3 = Vector3.INF) -> PackedVector3Array:
	var down:= Vector3.DOWN * Cfg.CABLE_DEPTH
	var out:= PackedVector3Array()
	out.append(from_ground)
	out.append(from_ground + down)
	out.append(to_ground + down)
	out.append(to_ground)
	if riser_to.is_finite():
		out.append(riser_to)
	return out


static func ghost_mesh(paths: Array) -> ArrayMesh:
	if paths.is_empty():
		return null
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pts: PackedVector3Array in paths:
		PowerLine.sweep(st, pts, GHOST_R)
	st.generate_normals()
	return st.commit()


static func reveal(tree: SceneTree, reason: String, on: bool) -> void:
	if on:
		_reasons [reason] = true
	else:
		_reasons.erase(reason)
	if tree == null:
		return
	var show:= revealed()
	for node in tree.get_nodes_in_group(GROUP):
		if node is CableTrace:
			(node as CableTrace).visible = show


static func revealed() -> bool:
	return not _reasons.is_empty()


static func x_ray_material() -> StandardMaterial3D:
	if _material != null:
		return _material
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOUR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.render_priority = 3
	return _material


func _ready() -> void:
	add_to_group(GROUP)


	top_level = false
	_mesh = MeshInstance3D.new()
	_mesh.name = "Trace"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = x_ray_material()
	add_child(_mesh)
	_remesh()
	visible = revealed()


func _remesh() -> void:
	if _path.size() < 2:
		_mesh.mesh = null
		return
	var local:= PackedVector3Array()
	for p in _path:
		local.append(to_local(p))
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PowerLine.sweep(st, local, RADIUS)
	st.generate_normals()
	_mesh.mesh = st.commit()


func points() -> PackedVector3Array:
	return _path


func end_point() -> Vector3:
	return _path [_path.size() - 1] if not _path.is_empty() else global_position
