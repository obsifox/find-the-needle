class_name PanelClose
extends RefCounted


const SIZE:= 26.0

const COL_LIT:= Color(0.95, 0.33, 0.27)

const COL_INK:= Color(0.7, 0.12, 0.08)


static func make(on_pressed: Callable, ground: Color) -> Button:
	var red:= COL_LIT if ground.get_luminance() < 0.5 else COL_INK
	var b:= Button.new()
	b.custom_minimum_size = Vector2(SIZE, SIZE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE


	b.tooltip_text = Cfg.tr("Close")
	_plate(b, red)
	b.pressed.connect(on_pressed)

	var cross:= Cross.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.colour = red
	b.add_child(cross)


	b.mouse_entered.connect(func() -> void: cross.set_colour(ground))
	b.mouse_exited.connect(func() -> void: cross.set_colour(red))
	return b


static func _plate(b: Button, red: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(2)
		sb.border_color = Color(red.r, red.g, red.b, 0.55)
		sb.bg_color = Color(red.r, red.g, red.b, 0.0)
		match state:
			"hover":
				sb.border_color = red
				sb.bg_color = red
			"pressed":
				sb.border_color = red
				sb.bg_color = red.darkened(0.25)
		b.add_theme_stylebox_override(state, sb)


class Cross extends Control:


	const ARM:= 6.5
	const THICK:= 2.4

	var colour:= Color.WHITE

	func set_colour(to: Color) -> void:
		colour = to
		queue_redraw()

	func _draw() -> void:
		var mid:= size * 0.5
		var a:= Vector2(ARM, ARM)
		var b:= Vector2(ARM, - ARM)
		draw_line(mid - a, mid + a, colour, THICK, true)
		draw_line(mid - b, mid + b, colour, THICK, true)
