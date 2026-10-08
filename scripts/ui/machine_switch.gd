class_name MachineSwitch
extends RefCounted


const COL_STOP:= Color(1.0, 0.46, 0.38)
const COL_GO:= Color(0.44, 0.84, 0.46)


const COL_STOP_INK:= Color(0.7, 0.12, 0.08)
const COL_GO_INK:= Color(0.08, 0.46, 0.16)


const META_PAPER:= &"machine_switch_paper"


const META_RUNNING:= &"machine_switch_running"
const COL_HEAD:= Color(0.125, 0.135, 0.155, 0.98)
const COL_FOOT:= Color(0.05, 0.055, 0.068, 0.97)
const COL_EDGE:= Color(0.34, 0.37, 0.42)
const HEIGHT:= 44.0


static func make(on_pressed: Callable) -> Button:
	var b:= Button.new()
	b.custom_minimum_size = Vector2(0.0, HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 17)
	_plate(b)
	b.pressed.connect(on_pressed)
	style(b, true)
	return b


static func style(b: Button, running: bool) -> void:
	if b == null:
		return


	b.text = Cfg.tr("TURN OFF") if running else Cfg.tr("TURN ON")
	b.set_meta(META_RUNNING, running)
	var printed: bool = b.get_meta(META_PAPER, false)
	var colour: Color
	if printed:
		colour = COL_STOP_INK if running else COL_GO_INK
	else:
		colour = COL_STOP if running else COL_GO
	for state: String in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(state, colour)
	b.add_theme_color_override("font_disabled_color", colour.darkened(0.55))


static func paper(b: Button, ground: Color, ink: Color, hover: Color) -> void:
	if b == null:
		return
	b.set_meta(META_PAPER, true)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(2)
		sb.border_color = ink
		sb.bg_color = ground
		match state:
			"hover":
				sb.bg_color = hover
			"pressed", "disabled":
				sb.bg_color = hover
		b.add_theme_stylebox_override(state, sb)


	style(b, bool(b.get_meta(META_RUNNING, true)))


static func _plate(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(2)
		sb.border_color = COL_EDGE
		sb.bg_color = COL_HEAD
		match state:
			"hover":
				sb.bg_color = COL_HEAD.lightened(0.1)
				sb.border_color = COL_EDGE.lightened(0.25)
			"pressed":
				sb.bg_color = COL_FOOT
			"disabled":
				sb.bg_color = COL_FOOT
		b.add_theme_stylebox_override(state, sb)
