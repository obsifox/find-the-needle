class_name ConveyorTBody
extends Node3D


const MODEL_V1:= "res://assets/models/simple_arm_splitter.glb"
const MODEL_V2:= "res://assets/models/simple_arm_splitter_2m.glb"

const MODEL_1M:= "res://assets/models/simple_arm_splitter_1m.glb"


static func model_for(port_r: float) -> String:
	if is_equal_approx(port_r, Cfg.T_SPLITTER_PORT_R_1M):
		return MODEL_1M
	return MODEL_V1 if is_equal_approx(port_r, Cfg.T_SPLITTER_PORT_R_V1) else MODEL_V2


const SCREEN_AT:= Vector3(0.0, 0.875, 0.2168)

var pivot: Node3D
var meshes: Array [MeshInstance3D] = []

var rubber: Array [Dictionary] = []

var drums: Array [Dictionary] = []


var fast:= false
var screen: MeshInstance3D
var screen_mat: ShaderMaterial
var caption: Label3D

var _model: Node3D

var _path:= ""


static var _uv_run:= { }


func build(preview: bool, port_r: float) -> void:
	var path:= model_for(port_r)
	var packed:= load(path) as PackedScene
	if packed == null:
		push_error("ConveyorTBody: cannot load %s" % path)
		return
	_path = path
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for node in _model.find_children("*", "AnimationPlayer", true, false):
		node.get_parent().remove_child(node)
		node.free()
	pivot = _model.find_child("GuideArmPivot", true, false) as Node3D
	if pivot == null:
		push_error("ConveyorTBody: %s has no GuideArmPivot" % path)
	for node in _model.find_children("*", "Node3D", true, false):
		var n:= String(node.name)


		if n == "ScreenPreview" or n.contains("_Leg") or n.contains("_Foot"):
			(node as Node3D).visible = false
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		if mi.is_visible_in_tree():
			meshes.append(mi)
	_dress()
	_build_screen()
	if preview:
		for mi in meshes:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_arm_angle(angle: float) -> void:
	if pivot == null:
		return

	if _arm_ease == null:
		_arm_ease = StepEase.attach(pivot)
	_arm_ease.go(angle)


var _arm_ease: StepEase


func set_ghost(valid: bool) -> void:
	var material:= ConveyorKit.ghost_material(valid)
	for mi in meshes:
		mi.material_overlay = material
	if screen != null:
		screen.material_overlay = material


func apply_scroll(travel: Dictionary, held:= false) -> void:
	var reversed:= { }
	for r in rubber:
		var t: Vector3 = travel.get(int(r ["lane"]), Vector3.ZERO)
		var run: Vector2 = r ["run"]
		var backwards:= run.x * t.x + run.y * t.z < 0.0
		var mi:= r ["mesh"] as MeshInstance3D
		var belt:= ConveyorKit.belt_material_held() if held else _rubber(backwards)
		mi.set_surface_override_material(int(r ["surface"]), belt)
		reversed [mi] = backwards
	for d in drums:
		var mi:= d ["mesh"] as MeshInstance3D
		var drum:= ConveyorKit.roller_material() if held else _steel(bool(reversed.get(mi, false)))
		mi.set_surface_override_material(int(d ["surface"]), drum)


func _rubber(backwards: bool) -> ShaderMaterial:
	if fast:
		return ConveyorKit.belt_material_fast_reversed() if backwards else ConveyorKit.belt_material_fast()
	return ConveyorKit.belt_material_reversed() if backwards else ConveyorKit.belt_material()


func _steel(backwards: bool) -> ShaderMaterial:
	if fast:
		return ConveyorKit.drum_material_fast_reversed() if backwards else ConveyorKit.drum_material_fast()
	return ConveyorKit.drum_material_reversed() if backwards else ConveyorKit.drum_material()


func show_split(mode: float, entry: int, left: int, right: int, words: String) -> void:
	if screen_mat != null:
		screen_mat.set_shader_parameter("merge", 0.0)
		screen_mat.set_shader_parameter("mode", mode)
		screen_mat.set_shader_parameter("entry_seg", float(entry))
		screen_mat.set_shader_parameter("left_seg", float(left))
		screen_mat.set_shader_parameter("right_seg", float(right))
	if caption != null:
		caption.text = words


func show_merge(out_seg: int, serving: int, words: String) -> void:
	if screen_mat != null:
		screen_mat.set_shader_parameter("merge", 1.0)
		screen_mat.set_shader_parameter("mode", 0.0)
		screen_mat.set_shader_parameter("out_seg", float(out_seg))
		screen_mat.set_shader_parameter("serving_seg", float(serving))
	if caption != null:
		caption.text = words


static func floor_body(half: float) -> StaticBody3D:
	var body:= WyeSweep.infill_outline_body(PackedVector2Array([
		Vector2(- half, - half), Vector2(half, - half), Vector2(half, half), Vector2(- half, half)]))
	var wall:= BoxShape3D.new()


	wall.size = Vector3(0.964, Cfg.BELT_RAIL_H, 0.077)
	var cs:= CollisionShape3D.new()
	cs.name = "BackSkirt"
	cs.shape = wall
	cs.position = Vector3(0.0, Cfg.BELT_RAIL_H * 0.5, 0.4435)
	body.add_child(cs)
	return body


func _dress() -> void:
	for mi in meshes:
		if mi.mesh == null:
			continue
		var lane:= _lane_of(mi)
		for i in mi.mesh.get_surface_count():
			var mat:= mi.mesh.surface_get_material(i)
			var id:= mat.resource_name if mat != null else ""
			if id.contains("BeltRubber"):


				if lane < 0:
					mi.set_surface_override_material(i, ConveyorKit.belt_material_held())
					continue
				rubber.append({ "mesh": mi, "surface": i, "lane": lane,
					"run": _uv_direction(mi, i) })
			elif id.contains("Drum"):
				drums.append({ "mesh": mi, "surface": i, "lane": lane })
			elif id.contains("Roller") or id.contains("Frame") or id.contains("Screen"):
				mi.set_surface_override_material(i, ConveyorKit._material_named(id))


func _lane_of(mi: Node) -> int:
	var node: Node = mi
	while node != null and node != _model:
		var n:= String(node.name)
		if n.begins_with("LaneIn") or n == "CentreIn":
			return ConveyorTSplitter.STEM
		if n.begins_with("LaneLeft") or n == "CentreLeft":
			return ConveyorTSplitter.BAR_POS
		if n.begins_with("LaneRight") or n == "CentreRight":
			return ConveyorTSplitter.BAR_NEG
		node = node.get_parent()
	return -1


func _uv_direction(mi: MeshInstance3D, surface: int) -> Vector2:
	var key:= "%s:%s:%d" % [_path, String(_model.get_path_to(mi)), surface]
	if _uv_run.has(key):
		return _uv_run [key]
	var xf:= Transform3D.IDENTITY
	var node: Node = mi
	while node != null and node != _model:
		xf = (node as Node3D).transform * xf
		node = node.get_parent()
	var arrays:= mi.mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays [Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays [Mesh.ARRAY_TEX_UV]


	var pts: Array [Vector3] = []
	for k in verts.size():
		if (xf.basis * normals [k]).normalized().y < 0.3 or (xf * verts [k]).y < -0.05:
			continue
		var p:= xf * verts [k]
		pts.append(Vector3(p.x, p.z, uvs [k].y))
	var run:= Vector2.ZERO
	if pts.size() >= 3:
		var mean:= Vector3.ZERO
		for p in pts:
			mean += p
		mean /= float(pts.size())
		var xx:= 0.0
		var xz:= 0.0
		var zz:= 0.0
		var xv:= 0.0
		var zv:= 0.0
		for p in pts:
			var d:= p - mean
			xx += d.x * d.x
			xz += d.x * d.y
			zz += d.y * d.y
			xv += d.x * d.z
			zv += d.y * d.z
		var det:= xx * zz - xz * xz
		if absf(det) > 1e-09:
			run = Vector2((xv * zz - zv * xz) / det, (zv * xx - xv * xz) / det)
		elif xx > zz:
			run = Vector2(xv / maxf(xx, 1e-09), 0.0)
		else:
			run = Vector2(0.0, zv / maxf(zz, 1e-09))
	_uv_run [key] = run
	return run


func _build_screen() -> void:
	var shader: Shader = load(ConveyorSplitter.READOUT_SHADER)
	if shader == null:
		push_warning("ConveyorTBody: no %s; the screen will stay dark"
			% ConveyorSplitter.READOUT_SHADER)
		return
	var size:= ConveyorSplitter.SCREEN_SIZE
	var quad:= QuadMesh.new()
	quad.size = size
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = shader
	screen_mat.set_shader_parameter("aspect", size.x / size.y)
	screen_mat.set_shader_parameter("ground", Cfg.COL_SPLITTER_SCREEN)
	screen_mat.set_shader_parameter("layout", 1.0)
	screen = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = quad
	screen.material_override = screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.transform = Transform3D(Basis(Vector3.UP, PI), SCREEN_AT)
	add_child(screen)

	caption = Label3D.new()
	caption.name = "Caption"
	caption.font = UiFont.bold()
	caption.font_size = 64
	caption.pixel_size = 0.0004
	caption.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	caption.shaded = false
	caption.double_sided = false
	caption.modulate = Cfg.COL_SPLITTER_LIT
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.transform = Transform3D(Basis(Vector3.UP, PI),
		SCREEN_AT + Vector3(0.0, ConveyorSplitter.CAPTION_DY, -0.0006))
	add_child(caption)
