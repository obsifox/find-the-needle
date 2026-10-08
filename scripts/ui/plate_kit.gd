class_name PlateKit
extends RefCounted


const GLASS:= 0.95


static func card(width: float, alpha: float = 1.0) -> PanelContainer:
	var c:= PanelContainer.new()
	c.custom_minimum_size = Vector2(width, 0.0)
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(ArmPanel.COL_PAPER, alpha)
	sb.border_color = ArmPanel.COL_EDGE
	sb.set_border_width_all(int(ArmPanel.RULE))
	sb.set_corner_radius_all(0)


	sb.set_content_margin_all(ArmPanel.RULE)
	c.add_theme_stylebox_override("panel", sb)
	return c


static func photo(tile: String) -> Control:
	var tex:= TechPanel.icon_for(tile) if tile != "*" else null
	if tex == null and tile != "*":
		return null
	var frame:= PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb:= StyleBoxFlat.new()
	sb.bg_color = ArmPanel.COL_TILE_ON
	sb.border_color = ArmPanel.COL_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(2.0)
	frame.add_theme_stylebox_override("panel", sb)
	var pic:= TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(42.0, 42.0)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	frame.visible = tex != null
	return frame


static func set_photo(frame: Control, tile: String) -> void:
	if frame == null:
		return
	var tex:= TechPanel.icon_for(tile) if tile != "" else null
	(frame.get_child(0) as TextureRect).texture = tex
	frame.visible = tex != null


static func top(whole: VBoxContainer, title: String, tile: String, closer: Callable,
		toggle: Control, badged: bool = false) -> Dictionary:
	var band:= ArmPanel.band(title, Cfg.tr("%s or ESC to close") % InputSetup.hint("interact"),
		closer, toggle, badged, tile)
	whole.add_child(band [0])
	whole.add_child(rule())
	var strip:= ArmPanel.status_strip()
	whole.add_child(strip [0])
	whole.add_child(rule())
	return { "badge": band [1], "name": band [2], "photo": band [3], "word": strip [1],
		"line": strip [2], "chip": strip [3], "chip_word": strip [4], "sign": strip [5] }


static func body(whole: VBoxContainer, width: float) -> VBoxContainer:
	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(ArmPanel.PAD))
	inset.add_theme_constant_override("margin_right", int(ArmPanel.PAD))
	inset.add_theme_constant_override("margin_top", int(ArmPanel.PAD) - 4)
	inset.add_theme_constant_override("margin_bottom", int(ArmPanel.PAD))
	whole.add_child(inset)
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = width - ArmPanel.PAD * 2.0 - ArmPanel.RULE * 2.0
	inset.add_child(col)
	return col


static func rule() -> Control:
	var line:= ColorRect.new()
	line.color = ArmPanel.COL_EDGE
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func heading(title: String, icon: String) -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(PlateIcons.rect(icon, 22, ArmPanel.COL_INK))
	var l:= ArmPanel.label(title, 16, ArmPanel.COL_INK, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var gap:= MarginContainer.new()
	gap.add_theme_constant_override("margin_top", 4)
	gap.add_child(row)
	return gap


static func note(text: String, width: float, size: int = 14) -> Label:
	var l:= ArmPanel.label(text, size, ArmPanel.COL_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


	l.custom_minimum_size.x = width
	return l


static func write_status(top_parts: Dictionary, machine: Node, calm: String,
		player: Player) -> void:
	var word: Label = top_parts ["word"]
	var sign: TextureRect = top_parts ["sign"]
	var line: Label = top_parts ["line"]
	ArmPanel.write_power_chip(top_parts ["chip"], top_parts ["chip_word"],
		MachinePower.power_share_for(machine, player))
	if machine == null or not is_instance_valid(machine):
		return
	var off: bool = machine.has_method("is_switched_off") and bool(machine.call("is_switched_off"))
	var alert:= ""
	if not off and machine.has_method("alert_reason"):
		alert = str(machine.call("alert_reason"))
	if off:
		ArmPanel.write_state(word, sign, 2)
		word.text = Cfg.tr("SWITCHED OFF")
		line.text = calm
		return
	if alert != "":
		ArmPanel.write_state(word, sign, 2)
		var cut:= alert.find("  ·  ")
		word.text = alert.substr(0, cut) if cut >= 0 else alert
		line.text = alert.substr(cut + 5) if cut >= 0 else ""
		return
	ArmPanel.write_state(word, sign, 0)
	line.text = calm


static func slider(s: HSlider) -> void:
	var track:= StyleBoxFlat.new()
	track.bg_color = ArmPanel.COL_TILE
	track.border_color = ArmPanel.COL_TILE_EDGE
	track.set_border_width_all(2)
	track.set_corner_radius_all(0)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	s.add_theme_stylebox_override("slider", track)
	var lit:= StyleBoxFlat.new()
	lit.bg_color = ArmPanel.COL_TAKE_INK
	lit.set_corner_radius_all(0)
	lit.content_margin_top = 7.0
	lit.content_margin_bottom = 7.0
	s.add_theme_stylebox_override("grabber_area", lit)
	var hot:= lit.duplicate() as StyleBoxFlat
	hot.bg_color = ArmPanel.COL_TAKE_INK.lightened(0.12)
	s.add_theme_stylebox_override("grabber_area_highlight", hot)
	s.add_theme_icon_override("grabber", _grabber(ArmPanel.COL_INK))
	s.add_theme_icon_override("grabber_highlight", _grabber(ArmPanel.COL_INK_SOFT))
	s.add_theme_icon_override("grabber_disabled", _grabber(ArmPanel.COL_LOCKED))
	s.custom_minimum_size.y = maxf(s.custom_minimum_size.y, 28.0)
	s.focus_mode = Control.FOCUS_NONE


static var _grabbers: Dictionary = { }


static func _grabber(ink: Color) -> Texture2D:
	if _grabbers.has(ink):
		return _grabbers [ink]
	var img:= Image.create_empty(14, 28, false, Image.FORMAT_RGBA8)
	img.fill(ink)
	for y in range(7, 21):
		img.set_pixel(6, y, ArmPanel.COL_PAPER)
		img.set_pixel(7, y, ArmPanel.COL_PAPER)
	var tex:= ImageTexture.create_from_image(img)
	_grabbers [ink] = tex
	return tex


static func button(text: String, icon: String, on_pressed: Callable) -> Button:
	var b:= Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, MachineSwitch.HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(2)
		sb.border_color = ArmPanel.COL_LOCKED if state == "disabled" else ArmPanel.COL_INK
		sb.bg_color = ArmPanel.COL_HOVER if state == "hover" else ArmPanel.COL_PAPER
		if state == "pressed":
			sb.bg_color = ArmPanel.COL_TILE_ON
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		b.add_theme_stylebox_override(state, sb)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(colour, ArmPanel.COL_INK)
	b.add_theme_color_override("font_disabled_color", ArmPanel.COL_LOCKED)
	if icon != "":
		PlateIcons.on_button(b, icon, 20, ArmPanel.COL_INK, ArmPanel.COL_LOCKED)
	b.pressed.connect(on_pressed)
	return b


static func write_pin(b: Button, left: float) -> void:
	if b == null:
		return
	var text:= Cfg.tr("Show Range")
	if left > 0.0:
		var whole:= ceili(left)
		text = Cfg.tr("Hide Range (%s)") % ("%d:%02d" % [whole / 60, whole % 60])
	if b.text == text:
		return
	b.text = text
	b.icon = PlateIcons.texture("eye_off" if left > 0.0 else "eye", 20)
	ArmPanel.light_button(b, left > 0.0)


static func foot(whole: VBoxContainer) -> HBoxContainer:
	whole.add_child(rule())
	return ArmPanel.foot(whole)


static func power_line() -> Label:
	var l:= ArmPanel.label("", 13, ArmPanel.COL_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160.0, MachineSwitch.HEIGHT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func sync(root: Node, dark: bool) -> void:
	if root == null:
		return
	var want:= dark
	var old: Dictionary = ArmPanel.LIGHT if want else ArmPanel.DARK
	var new: Dictionary = ArmPanel.DARK if want else ArmPanel.LIGHT
	var map:= { }
	for key: String in old:
		map [_key(old [key])] = new [key]
	var seen:= { }
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		var item:= n as CanvasItem
		if item == null:
			continue
		item.self_modulate = _swap(item.self_modulate, map)
		item.modulate = _swap(item.modulate, map)
		if item is ColorRect:
			(item as ColorRect).color = _swap((item as ColorRect).color, map)
		for p: Dictionary in item.get_property_list():
			var prop: String = p ["name"]
			if prop.begins_with("theme_override_colors/"):
				var c: Variant = item.get(prop)
				if c is Color:
					item.set(prop, _swap(c, map))
			elif prop.begins_with("theme_override_styles/"):
				var sb:= item.get(prop) as StyleBoxFlat
				if sb != null and not seen.has(sb):
					seen [sb] = true
					sb.bg_color = _swap(sb.bg_color, map)
					sb.border_color = _swap(sb.border_color, map)
			elif int(p ["type"]) == TYPE_COLOR and (int(p ["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				item.set(prop, _swap(item.get(prop), map))
		if item is HSlider:
			slider(item as HSlider)
		item.queue_redraw()


static func root_of(node: Node) -> Node:
	var top: Node = node
	while top.get_parent() is Control:
		top = top.get_parent()
	return top


static func _key(c: Color) -> String:
	return "%d,%d,%d" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]


static func _swap(c: Color, map: Dictionary) -> Color:
	var k:= _key(c)
	if not map.has(k):
		return c
	var out: Color = map [k]
	out.a = c.a
	return out
