class_name SegmentReadout
extends Node3D


const LETTERS:= { "H": "bcefg", "I": "ef", "-": "g" }


var cells:= 4
var digit_height:= 0.03
var lit_material: Material
var dim_material: Material


var dim_offset:= 0.001
var lit_offset:= 0.002

var _dim: MeshInstance3D
var _lit: MeshInstance3D


var _shown:= ""


func _ready() -> void:
	_dim = _layer("Ghost", dim_offset)
	CountdownBoard._wear(_dim, _mesh("8".repeat(cells)), dim_material)
	_lit = _layer("Digits", lit_offset)
	CountdownBoard._wear(_lit, _mesh(_shown), lit_material)


func show_text(text: String) -> void:
	if text == _shown:
		return
	_shown = text
	if _lit != null:
		CountdownBoard._wear(_lit, _mesh(text), lit_material)


func reading() -> String:
	return _shown


func width() -> float:
	return (CountdownBoard.CELL_W * cells
		+ CountdownBoard.CELL_GAP * (cells - 1)) * digit_height


func _layer(node_name: String, z: float) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.name = node_name
	mi.position.z = z

	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _mesh(text: String) -> ArrayMesh:
	var h:= digit_height
	var w:= CountdownBoard.CELL_W * h
	var step:= w + CountdownBoard.CELL_GAP * h
	var left:= - width() * 0.5
	var bottom:= - h * 0.5
	var padded:= text.lpad(cells).right(cells)
	var verts:= PackedVector3Array()
	var normals:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	for i in cells:
		var ch:= padded [i]
		var lit:= str(CountdownBoard.GLYPH.get(ch, LETTERS.get(ch, "")))
		var x0:= left + step * i
		for key: String in CountdownBoard.SEG_KEYS:
			if lit.contains(key):
				CountdownBoard._polygon(verts, normals, uvs,
					CountdownBoard.segment(key), x0, bottom, w, h)
	var mesh:= ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
