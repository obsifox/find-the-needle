class_name BeltShedMark
extends Label3D


const RISE:= 0.7
const LIFE:= 1.6
const COLOUR:= MachineAlert.COL_HAZARD


static func play(at: Vector3, parent: Node) -> BeltShedMark:
	if parent == null or not parent.is_inside_tree():
		return null
	var l:= BeltShedMark.new()
	l.text = parent.tr("BELTS FULL")
	l.font = UiFont.bold()
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = COLOUR
	l.outline_size = 22
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.double_sided = true
	l.render_priority = 4
	l.outline_render_priority = 3
	parent.add_child(l)
	l.global_position = at


	l.transparency = 1.0
	var t:= l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position", at + Vector3(0, RISE, 0), LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "transparency", 0.0, 0.15)
	t.tween_property(l, "transparency", 1.0, LIFE * 0.4).set_delay(LIFE * 0.6)
	t.chain().tween_callback(l.queue_free)
	return l
