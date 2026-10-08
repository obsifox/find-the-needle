extends Node


const BINDINGS:= {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL],


	"hotbar_1": [KEY_1],
	"hotbar_2": [KEY_2],
	"hotbar_3": [KEY_3],
	"hotbar_4": [KEY_4],
	"hotbar_5": [KEY_5],
	"hotbar_6": [KEY_6],
	"hotbar_7": [KEY_7],
	"hotbar_8": [KEY_8],
	"hotbar_9": [KEY_9],
	"hotbar_10": [KEY_0],
	"build_catalog": [KEY_B],


	"tech_tree": [KEY_TAB, KEY_T],
	"drop_tool": [KEY_Q],
	"build_cancel": [KEY_Q],
	"dismantle": [KEY_X],


	"interact": [KEY_E],
	"reset_view": [KEY_R],


	"carry_rotate": [KEY_R],


	"build_rotate": [KEY_R],


	"build_further": [KEY_V],
	"build_closer": [KEY_C],


	"build_grid": [KEY_G],


	"build_variant": [KEY_Z],


	"inspect_needle": [KEY_F],


	"throw_item": [KEY_F],


	"build_no_snap": [KEY_F],


	"toggle_hud": [KEY_F4],
	"toggle_debug": [KEY_F3],
	"debug_menu": [KEY_F1],
	"screenshot": [KEY_F12],
	"quick_save": [KEY_F5],
	"free_mouse": [KEY_ESCAPE],
}

const MOUSE_BINDINGS:= {
	"primary": MOUSE_BUTTON_LEFT,
	"secondary": MOUSE_BUTTON_RIGHT,


	"build_further": MOUSE_BUTTON_WHEEL_UP,
	"build_closer": MOUSE_BUTTON_WHEEL_DOWN,


	"pick_build": MOUSE_BUTTON_MIDDLE,
}


const ROWS: Array [Dictionary] = [
	{ "group": "MOVEMENT", "label": "Forward", "actions": ["move_forward"] },
	{ "group": "MOVEMENT", "label": "Back", "actions": ["move_back"] },
	{ "group": "MOVEMENT", "label": "Left", "actions": ["move_left"] },
	{ "group": "MOVEMENT", "label": "Right", "actions": ["move_right"] },
	{ "group": "MOVEMENT", "label": "Jump", "actions": ["jump"] },
	{ "group": "MOVEMENT", "label": "Sprint", "actions": ["sprint"] },
	{ "group": "MOVEMENT", "label": "Crouch", "actions": ["crouch"] },

	{ "group": "HANDS", "label": "Use", "actions": ["primary"] },
	{ "group": "HANDS", "label": "Aim / throw", "actions": ["secondary"] },
	{ "group": "HANDS", "label": "Interact", "actions": ["interact"] },
	{ "group": "HANDS", "label": "Throw / inspect / no snap", "actions": ["throw_item", "inspect_needle", "build_no_snap"] },
	{ "group": "HANDS", "label": "Reset aim / turn", "actions": ["reset_view", "carry_rotate", "build_rotate"] },
	{ "group": "HANDS", "label": "Drop / cancel", "actions": ["drop_tool", "build_cancel"] },

	{ "group": "BUILDING", "label": "Build catalogue", "actions": ["build_catalog"] },
	{ "group": "BUILDING", "label": "Tech tree", "actions": ["tech_tree"] },
	{ "group": "BUILDING", "label": "Dismantle", "actions": ["dismantle"] },
	{ "group": "BUILDING", "label": "Copy a building", "actions": ["pick_build"] },
	{ "group": "BUILDING", "label": "Place further", "actions": ["build_further"] },
	{ "group": "BUILDING", "label": "Place closer", "actions": ["build_closer"] },
	{ "group": "BUILDING", "label": "Snap to grid", "actions": ["build_grid"] },
	{ "group": "BUILDING", "label": "Next type", "actions": ["build_variant"] },

	{ "group": "HOTBAR", "label": "Slot 1", "actions": ["hotbar_1"] },
	{ "group": "HOTBAR", "label": "Slot 2", "actions": ["hotbar_2"] },
	{ "group": "HOTBAR", "label": "Slot 3", "actions": ["hotbar_3"] },
	{ "group": "HOTBAR", "label": "Slot 4", "actions": ["hotbar_4"] },
	{ "group": "HOTBAR", "label": "Slot 5", "actions": ["hotbar_5"] },
	{ "group": "HOTBAR", "label": "Slot 6", "actions": ["hotbar_6"] },
	{ "group": "HOTBAR", "label": "Slot 7", "actions": ["hotbar_7"] },
	{ "group": "HOTBAR", "label": "Slot 8", "actions": ["hotbar_8"] },
	{ "group": "HOTBAR", "label": "Slot 9", "actions": ["hotbar_9"] },
	{ "group": "HOTBAR", "label": "Slot 10", "actions": ["hotbar_10"] },

	{ "group": "SYSTEM", "label": "Quick save", "actions": ["quick_save"] },


	{ "group": "SYSTEM", "label": "Save a bug report", "actions": ["screenshot"], "dev": true },
	{ "group": "SYSTEM", "label": "Hide the HUD", "actions": ["toggle_hud"] },
	{ "group": "SYSTEM", "label": "Debug readout", "actions": ["toggle_debug"] },
]


const OVERRIDE_PATH:= "user://controls.cfg"


const MOUSE_NAMES:= {
	MOUSE_BUTTON_LEFT: "LMB",
	MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel left",
	MOUSE_BUTTON_WHEEL_RIGHT: "Wheel right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}


const UNBOUND:= "?"


var _override: Dictionary = { }

var _row_of: Dictionary = { }


signal changed


func offered_rows() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for row: Dictionary in ROWS:
		if bool(row.get("dev", false)) and not Cfg.debug_on():
			continue
		out.append(row)
	return out


func _enter_tree() -> void:
	for row: Dictionary in ROWS:
		for action: String in row ["actions"]:
			_row_of [action] = str(row ["actions"] [0])
	_load()
	apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_held()


func release_held() -> void:
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)


func apply() -> void:
	for action: String in BINDINGS:


		if action == "debug_menu" and not Cfg.debug_on():
			continue
		_install(action)
	for action: String in MOUSE_BINDINGS:
		_install(action)


func _install(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for ev: InputEvent in _events_for(action):
		InputMap.action_add_event(action, ev)


func _events_for(action: String) -> Array [InputEvent]:
	var out: Array [InputEvent] = []
	var row:= str(_row_of.get(action, ""))
	if row != "" and _override.has(row):
		var ev:= event_from_spec(str(_override [row]))
		if ev != null:
			out.append(ev)
		return out


	if MOUSE_BINDINGS.has(action):
		out.append(mouse_event(MOUSE_BINDINGS [action]))
	if BINDINGS.has(action):
		for keycode: int in BINDINGS [action]:
			out.append(key_event(keycode))
	return out


func binding(row: String) -> String:
	if _override.has(row):
		return str(_override [row])
	return default_binding(row)


func specs(row: String) -> PackedStringArray:
	if _override.has(row):
		var spec:= str(_override [row])
		return PackedStringArray() if spec == "" else PackedStringArray([spec])
	return default_specs(row)


func specs_of(action: String) -> PackedStringArray:
	return specs(str(_row_of.get(action, action)))


static func default_specs(row: String) -> PackedStringArray:
	var out:= PackedStringArray()
	if MOUSE_BINDINGS.has(row):
		out.append(spec_from_event(mouse_event(MOUSE_BINDINGS [row])))
	if BINDINGS.has(row):
		for keycode: int in BINDINGS [row]:
			out.append(spec_from_event(key_event(keycode)))
	return out


func default_binding(row: String) -> String:
	var all:= default_specs(row)
	return "" if all.is_empty() else all [0]


func is_default(row: String) -> bool:
	return specs(row) == default_specs(row)


func is_customised() -> bool:
	for row: String in _override:
		if not is_default(row):
			return true
	return false


func hint(action: String) -> String:
	return spec_label(spec_of(action))


func spec_of(action: String) -> String:
	return binding(str(_row_of.get(action, action)))


func label(row: String) -> String:
	var parts:= PackedStringArray()
	for spec: String in specs(row):
		parts.append(spec_label(spec))
	if parts.is_empty():
		return UNBOUND
	return " / ".join(parts)


func holder(spec: String, ignoring: String = "") -> String:
	if spec == "":
		return ""
	for row: Dictionary in ROWS:
		var id:= str(row ["actions"] [0])
		if id == ignoring:
			continue


		if spec in specs(id):
			return id
	return ""


func row_label(row: String) -> String:
	for r: Dictionary in ROWS:
		if str(r ["actions"] [0]) == row:
			return tr(str(r ["label"]))
	return row


static func group_label(group: String) -> String:
	return Cfg.tr(group)


func bind(row: String, spec: String) -> PackedStringArray:
	var taken:= PackedStringArray()
	if spec != "":
		for other: Dictionary in ROWS:
			var id:= str(other ["actions"] [0])
			if id == row or not (spec in specs(id)):
				continue


			taken.append(tr(str(other ["label"])))


			var left:= specs(id)
			left.remove_at(left.find(spec))
			_remember(id, "" if left.is_empty() else left [0])
	_remember(row, spec)
	apply()
	_save()
	changed.emit()
	return taken


func clear(row: String) -> void:
	bind(row, "")


func reset(row: String) -> void:
	_override.erase(row)
	apply()
	_save()
	changed.emit()


func reset_all() -> void:
	_override.clear()
	apply()
	_save()
	changed.emit()


func _remember(row: String, spec: String) -> void:


	var defaults:= default_specs(row)
	if defaults.size() == 1 and spec == defaults [0]:
		_override.erase(row)
	else:
		_override [row] = spec


static func key_event(keycode: int) -> InputEventKey:
	var ev:= InputEventKey.new()


	ev.physical_keycode = keycode
	return ev


static func mouse_event(button: int) -> InputEventMouseButton:
	var mb:= InputEventMouseButton.new()
	mb.button_index = button
	return mb


static func spec_from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var k:= event as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == 0:
			return ""
		return "key:%s" % OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


static func event_from_spec(spec: String) -> InputEvent:
	if spec.begins_with("key:"):
		var code:= OS.find_keycode_from_string(spec.substr(4))
		if code == KEY_NONE:
			return null
		return key_event(code)
	if spec.begins_with("mouse:"):
		var button:= spec.substr(6).to_int()
		if button <= 0:
			return null
		return mouse_event(button)
	return null


static func spec_label(spec: String) -> String:
	if spec == "":
		return UNBOUND
	if spec.begins_with("mouse:"):
		var button:= spec.substr(6).to_int()
		if MOUSE_NAMES.has(button):
			return Cfg.tr(str(MOUSE_NAMES [button]))
		return Cfg.tr("Mouse %d") % button
	var code:= _shown_keycode(spec)
	if code == KEY_NONE:
		return UNBOUND
	var cap:= key_cap(code)
	return cap if cap != "" else OS.get_keycode_string(code)


static func key_name(spec: String) -> String:
	if not spec.begins_with("key:"):
		return ""
	var code:= _shown_keycode(spec)
	return "" if code == KEY_NONE else OS.get_keycode_string(code)


static func _shown_keycode(spec: String) -> int:
	var code:= OS.find_keycode_from_string(spec.substr(4))
	if code == KEY_NONE or not _has_layout():
		return code
	var shown:= DisplayServer.keyboard_get_keycode_from_physical(code)
	return shown if shown != KEY_NONE else code


static func key_cap(code: int) -> String:
	match code:
		KEY_SPACE: return Cfg.tr("Space", "key")
		KEY_SHIFT: return Cfg.tr("Shift", "key")
		KEY_CTRL: return Cfg.tr("Ctrl", "key")
		KEY_ALT: return Cfg.tr("Alt", "key")
		KEY_TAB: return Cfg.tr("Tab", "key")
		KEY_ENTER: return Cfg.tr("Enter", "key")
		KEY_BACKSPACE: return Cfg.tr("Backspace", "key")
		KEY_ESCAPE: return Cfg.tr("Escape", "key")
		KEY_DELETE: return Cfg.tr("Delete", "key")
		KEY_INSERT: return Cfg.tr("Insert", "key")
		KEY_HOME: return Cfg.tr("Home", "key")
		KEY_END: return Cfg.tr("End", "key")
		KEY_PAGEUP: return Cfg.tr("PageUp", "key")
		KEY_PAGEDOWN: return Cfg.tr("PageDown", "key")
		KEY_CAPSLOCK: return Cfg.tr("CapsLock", "key")
		KEY_UP: return Cfg.tr("Up", "key")
		KEY_DOWN: return Cfg.tr("Down", "key")
		KEY_LEFT: return Cfg.tr("Left", "key")
		KEY_RIGHT: return Cfg.tr("Right", "key")
	return ""


static func _has_layout() -> bool:
	if _layout_checked == 0:
		_layout_checked = 1 if DisplayServer.get_name() in ["headless", "dummy"] else 2
	return _layout_checked == 2


static var _layout_checked:= 0


func _load() -> void:
	_override.clear()
	var cf:= ConfigFile.new()
	if cf.load(OVERRIDE_PATH) != OK:
		return
	if not cf.has_section("bindings"):
		return
	for row: String in cf.get_section_keys("bindings"):


		if not _row_of.has(row):
			continue
		var spec:= str(cf.get_value("bindings", row, ""))
		if spec != "" and event_from_spec(spec) == null:
			continue
		_override [row] = spec
	_yield_defaults_to_choices()


func _yield_defaults_to_choices() -> void:
	var chosen:= PackedStringArray()
	for row: String in _override:
		if str(_override [row]) != "":
			chosen.append(str(_override [row]))
	if chosen.is_empty():
		return
	for r: Dictionary in ROWS:
		var id:= str(r ["actions"] [0])
		if _override.has(id):
			continue
		var left:= default_specs(id)
		var had:= left.size()
		for spec: String in chosen:
			var at:= left.find(spec)
			if at >= 0:
				left.remove_at(at)
		if left.size() != had:
			_override [id] = "" if left.is_empty() else left [0]


func _save() -> void:
	var cf:= ConfigFile.new()
	for row: String in _override:
		cf.set_value("bindings", row, _override [row])
	cf.save(OVERRIDE_PATH)
