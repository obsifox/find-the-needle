class_name CrashReportDialog
extends Control


const COL_ACCENT:= OptionsPanel.COL_ACCENT
const COL_TEXT:= OptionsPanel.COL_TEXT
const COL_DIM:= OptionsPanel.COL_DIM
const COL_EDGE:= OptionsPanel.COL_EDGE


const COL_ALARM:= Color(0.94, 0.66, 0.42)
const COL_GOOD:= Color(0.4, 0.87, 0.55)

const CARD_W:= 900.0
const LOG_H:= 340.0


const ASK:= "Please share this on the Discord, and tell me when it happened and what you were doing at the time."


const ASK_AFTER_COPY:= "Copied. Please paste it into the Discord, and tell me when it happened and what you were doing at the time."


const INTEL_CHANNEL_URL:= "https://discord.com/channels/1541371072824344616/1552984226230444062"


const BTN_COPY:= "Copy"
const BTN_FOLDER:= "OpenFolder"
const BTN_SEND:= "Send"
const BTN_CLOSE:= "Close"


const BTN_THREAD_OFF:= "RenderThreadOff"
const BTN_D3D12:= "SwitchToD3D12"
const BTN_VULKAN:= "SwitchToVulkan"
const BTN_INTEL:= "IntelFault"

signal closed()

var _box: TextEdit
var _status: Label
var _send: Button
var _d3d12: Button
var _vulkan: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim:= ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)


	var card:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.98)
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)

	var column:= VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(CARD_W, 0)
	card.add_child(column)

	var title:= Label.new()
	title.text = tr("THE GAME CLOSED UNEXPECTEDLY")
	UiFont.style(title, 26, COL_ALARM, 0, true)
	column.add_child(title)

	var blurb:= Label.new()
	blurb.text = tr("%s Your save is safe. Here is the crash log.") % tr(CrashReport.pending_reason)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(CARD_W, 0)
	UiFont.style(blurb, 15, COL_DIM, 0)
	column.add_child(blurb)


	if CrashReport.intel_fault != "":
		_offer(column, tr("INTEL PROCESSOR"),
			tr("Your processor (%s) has a known Intel fault that makes many games crash, not just this one. Our Discord has a channel that explains the issue.")
				% CrashReport.intel_fault,
			tr("OPEN DISCORD"), OS.shell_open.bind(INTEL_CHANNEL_URL), BTN_INTEL)


	if CrashReport.offer_d3d12:
		_d3d12 = _offer(column, tr("DIRECT3D 12"),
			"Your graphics card stopped drawing the game. Switching the renderer to Direct3D 12 can stop this from happening again. You can switch back in Options.",
			"SWITCH", _switch_renderer.bind("d3d12"), BTN_D3D12)
	elif CrashReport.offer_vulkan:
		_vulkan = _offer(column, tr("VULKAN"),
			"The game was running on Direct3D 12 when it closed. Switching the renderer to Vulkan can stop this from happening again. You can switch back in Options.",
			"SWITCH", _switch_renderer.bind("vulkan"), BTN_VULKAN)


	elif Cfg.render_thread_suspect:
		_offer(column, tr("RENDER THREAD"),
			tr("The render thread was on. It can cause crashes like this one. If they keep happening, you can turn it off in Options, on the DISPLAY page. It adds up to 30 FPS, so if it is not the cause, it is best to play with it on."),
			"", Callable(), BTN_THREAD_OFF)

	_box = TextEdit.new()
	_box.text = CrashReport.pending


	_box.editable = false
	_box.custom_minimum_size = Vector2(CARD_W, LOG_H)


	_box.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_box.add_theme_font_override("font", UiFont.mono())
	_box.add_theme_font_size_override("font_size", 13)
	_box.add_theme_color_override("font_color", COL_TEXT)
	_box.add_theme_color_override("font_readonly_color", COL_TEXT)
	var box_sb:= StyleBoxFlat.new()
	box_sb.bg_color = Color(0.02, 0.03, 0.04, 0.95)
	box_sb.border_color = COL_EDGE
	box_sb.set_border_width_all(1)
	box_sb.set_corner_radius_all(0)
	box_sb.set_content_margin_all(8.0)
	_box.add_theme_stylebox_override("normal", box_sb)
	_box.add_theme_stylebox_override("read_only", box_sb)
	_box.add_theme_stylebox_override("focus", box_sb)
	column.add_child(_box)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)


	row.add_child(_button(tr("COPY"), _on_copy, BTN_COPY))
	row.add_child(_button(tr("OPEN THE LOG FOLDER"), _on_open_folder, BTN_FOLDER))
	var spacer:= Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)


	_send = _button(tr("SEND CRASH REPORT"), _on_send, BTN_SEND)
	_send.visible = false
	row.add_child(_send)
	row.add_child(_button(tr("CLOSE"), _on_close, BTN_CLOSE))

	_status = Label.new()


	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(CARD_W, 0)
	UiFont.style(_status, 14, COL_DIM, 0)
	column.add_child(_status)


	_say(tr(ASK), COL_ACCENT)


	CrashReport.send_started.connect(_sync)
	CrashReport.send_finished.connect(func(_ok: bool, _why: String) -> void: _sync())


	CrashReport.pending_changed.connect(_on_pending_changed)
	_sync()


func _offer(column: VBoxContainer, heading: String, body: String, caption: String,
		on_press: Callable, node_name: String) -> Button:
	var panel:= PanelContainer.new()
	var psb:= StyleBoxFlat.new()
	psb.bg_color = Color(COL_ALARM, 0.1)
	psb.border_color = COL_ALARM
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(0)
	psb.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", psb)
	column.add_child(panel)
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var words:= VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	row.add_child(words)
	var head:= Label.new()
	head.text = heading
	UiFont.style(head, 18, COL_ALARM, 0, true)
	words.add_child(head)
	var why:= Label.new()
	why.text = body
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFont.style(why, 16, COL_TEXT, 0)
	words.add_child(why)
	if caption == "":
		return null
	var b:= _button(caption, on_press, node_name)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", COL_ALARM)
	for state: String in ["normal", "hover", "pressed"]:
		var bsb:= b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		bsb.border_color = COL_ALARM
		bsb.set_border_width_all(2)
		bsb.content_margin_left = 20.0
		bsb.content_margin_right = 20.0
		b.add_theme_stylebox_override(state, bsb)
	row.add_child(b)
	return b


func _on_pending_changed() -> void:
	if not is_instance_valid(self) or _box == null:
		return
	var line:= _box.scroll_vertical
	_box.text = CrashReport.pending
	_box.scroll_vertical = line


func _button(text: String, on_press: Callable, node_name: String) -> Button:
	var b:= Button.new()
	b.text = text
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_ACCENT)
	b.add_theme_color_override("font_disabled_color", COL_DIM)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = (Color(0.13, 0.17, 0.22, 0.95) if state == "hover"
			else Color(0.08, 0.1, 0.13, 0.9))
		sb.border_color = COL_EDGE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(on_press)
	return b


func _on_copy() -> void:
	DisplayServer.clipboard_set(CrashReport.pending)


	_say(tr(ASK_AFTER_COPY), COL_GOOD)


func _on_open_folder() -> void:
	var folder:= CrashReport.crash_folder()
	OS.shell_open(folder)
	_say(folder, COL_DIM)


func _sync() -> void:
	if not is_instance_valid(self) or _send == null:
		return
	_send.visible = (not CrashReport.sent and not CrashReport.sending
		and Leaderboard.enabled and CrashReport.last_error != "")


func _on_send() -> void:
	_send.disabled = true
	_say(tr("Sending..."), COL_DIM)
	var res: Dictionary = await CrashReport.submit()


	if not is_instance_valid(self):
		return
	_send.disabled = false
	if res.ok:
		_send.visible = false
		_say(tr("Sent. Thank you!"), COL_GOOD)
		return


	_say(tr("It could not be sent: %s. The COPY button still works.")
		% str(res.error), COL_ALARM)


func _switch_renderer(renderer: String) -> void:
	var button:= _d3d12 if renderer == "d3d12" else _vulkan
	button.disabled = true
	if not Cfg.set_renderer(renderer):
		button.disabled = false
		_say(tr("Could not write the setting. Is the game folder read-only?"), COL_ALARM)
		return
	_say("Switched to %s. Restarting the game..."
		% ("Direct3D 12" if renderer == "d3d12" else "Vulkan"), COL_GOOD)
	await _restart()


func _restart() -> void:
	while CrashReport.busy():
		await get_tree().process_frame

	await get_tree().create_timer(0.8).timeout
	Cfg.restart_game()


func _on_close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):


		get_viewport().set_input_as_handled()
		_on_close()


func _say(text: String, colour: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)
