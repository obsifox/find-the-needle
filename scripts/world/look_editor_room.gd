@tool
class_name LookEditorRoom
extends Node3D


const GEO:= "res://scenes/dev/look_mockup_geo.scn"


const CAM_EYE:= Vector3(13.2, 1.8, 6.4)
const CAM_AIM:= Vector3(0.0, 3.2, 0.0)


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_fill()


func _fill() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var packed:= load(GEO) as PackedScene
	if packed == null:
		push_warning("[look] no mockup geometry at %s. Rebuild it with"
			% GEO + " --lookexport.")
		return
	var room:= packed.instantiate()
	room.name = "Room"
	add_child(room)


	var cam:= Camera3D.new()
	cam.name = "PreviewCam"
	cam.far = 400.0


	cam.transform = Transform3D(Basis(), CAM_EYE).looking_at(CAM_AIM, Vector3.UP)
	add_child(cam)
