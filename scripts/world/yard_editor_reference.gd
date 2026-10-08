@tool
class_name YardEditorReference
extends Node3D


const GEO:= "res://scenes/dev/yard_reference_geo.scn"


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
		push_warning("[yardref] no reference geometry at %s. Rebuild it with"
			% GEO + " --yardref.")
		return
	var geo:= packed.instantiate()
	geo.name = "Reference"
	add_child(geo)
