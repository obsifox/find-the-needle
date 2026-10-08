class_name RangePinButton
extends RefCounted


const COL_IDLE:= Color(0.92, 0.94, 0.98)
const COL_PINNED:= Color(1.0, 0.62, 0.22)


static func make(on_pressed: Callable) -> Button:
	var b:= MachineSwitch.make(on_pressed)
	write(b, 0.0)
	return b


static func toggle(machine: Node) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var left: float = machine.call("range_pinned_left")
	machine.call("pin_range", 0.0 if left > 0.0 else Cfg.RANGE_PIN_SECONDS)


static func write(b: Button, left: float) -> void:
	if b == null:
		return
	var colour:= COL_IDLE
	var text:= Cfg.tr("Show Range")
	if left > 0.0:
		var whole:= ceili(left)
		text = Cfg.tr("Hide Range (%s)") % ("%d:%02d" % [whole / 60, whole % 60])
		colour = COL_PINNED


	if b.text == text and b.has_theme_color_override("font_color"):
		return
	b.text = text
	for state: String in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, colour)
