class_name ChalkBoard
extends Node3D


const PIXEL:= 0.0004


const INK_OUT:= 0.0007


const H_TITLE:= 0.072
const H_LABEL:= 0.046
const H_VALUE:= 0.058
const H_FOOT:= 0.036


const COL_CHALK:= Color(0.8, 0.79, 0.73)


const COL_LABEL:= Color(0.56, 0.55, 0.51)
const COL_FOOT:= Color(0.46, 0.46, 0.43)
const COL_SLATE:= Color(0.052, 0.058, 0.055)

const COL_TIMBER:= Color(0.3, 0.22, 0.15)


const STAND_OFF:= 0.055
const SLATE_T:= 0.026

const FRAME_W:= 0.065
const FRAME_T:= 0.042

const LEDGE_D:= 0.055
const LEDGE_T:= 0.028

const MARGIN:= 0.07


var half:= Vector2(0.75, 0.575)


var face: Node3D


static func booth_to_local(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, - p.y)


func hang(wall_x: float, at: Vector2) -> void:
	face = Node3D.new()
	face.name = "Face"
	face.position = booth_to_local(Vector3(wall_x - STAND_OFF, at.x, at.y))
	face.rotation.y = deg_to_rad(-90.0)
	add_child(face)

	var slate:= MeshInstance3D.new()
	slate.name = "Slate"
	var box:= BoxMesh.new()
	box.size = Vector3(half.x * 2.0, half.y * 2.0, SLATE_T)
	slate.mesh = box
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_SLATE
	mat.roughness = 0.86
	mat.metallic = 0.0
	slate.material_override = mat
	face.add_child(slate)

	_build_frame()


func _build_frame() -> void:
	var timber:= StandardMaterial3D.new()
	timber.albedo_color = COL_TIMBER
	timber.roughness = 0.94
	timber.metallic = 0.0

	var w:= half.x * 2.0 + FRAME_W * 2.0
	var h:= half.y * 2.0 + FRAME_W * 2.0
	var rails:= {
		"Frame_Top": [Vector3(w, FRAME_W, FRAME_T),
			Vector3(0.0, half.y + FRAME_W * 0.5, 0.0)],
		"Frame_Bottom": [Vector3(w, FRAME_W, FRAME_T),
			Vector3(0.0, - half.y - FRAME_W * 0.5, 0.0)],
		"Frame_Left": [Vector3(FRAME_W, h, FRAME_T),
			Vector3(- half.x - FRAME_W * 0.5, 0.0, 0.0)],
		"Frame_Right": [Vector3(FRAME_W, h, FRAME_T),
			Vector3(half.x + FRAME_W * 0.5, 0.0, 0.0)],


		"Frame_Ledge": [Vector3(w, LEDGE_T, LEDGE_D),
			Vector3(0.0, - half.y - FRAME_W + LEDGE_T * 0.5,
				(LEDGE_D - FRAME_T) * 0.5)],
	}
	for rail_name: String in rails:
		var spec: Array = rails [rail_name]
		var mi:= MeshInstance3D.new()
		mi.name = rail_name
		var box:= BoxMesh.new()
		box.size = spec [0]
		mi.mesh = box
		mi.material_override = timber
		mi.position = spec [1]
		face.add_child(mi)


func write_title(text: String) -> Label3D:
	var l:= write("Title", H_TITLE, COL_CHALK, Vector2(0.0, half.y - 0.1),
		half.x * 2.0 - MARGIN * 2.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.text = text

	var rule:= MeshInstance3D.new()
	rule.name = "Rule"
	var quad:= QuadMesh.new()
	quad.size = Vector2(half.x * 2.0 - MARGIN * 3.0, 0.006)
	rule.mesh = quad
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = COL_LABEL
	mat.roughness = 0.9
	rule.material_override = mat
	rule.position = Vector3(0.0, half.y - 0.163, SLATE_T / 2.0 + INK_OUT)
	face.add_child(rule)
	return l


func write(node_name: String, cap: float, colour: Color, at: Vector2,
		width: float, align: HorizontalAlignment, heavy: bool) -> Label3D:
	var l:= Label3D.new()
	l.name = node_name
	l.pixel_size = PIXEL
	l.font_size = int(round(cap / PIXEL))
	l.outline_size = 0
	l.modulate = colour
	l.width = width / PIXEL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector3(at.x, at.y, SLATE_T / 2.0 + INK_OUT)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = false
	l.font = UiFont.bold() if heavy else UiFont.regular()
	face.add_child(l)
	return l


func board_point() -> Vector3:
	return face.global_position if face != null else global_position
