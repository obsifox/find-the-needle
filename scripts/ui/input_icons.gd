class_name InputIcons
extends RefCounted


const SHEET:= preload("res://assets/ui/input_prompts.png")
const COLUMNS:= 8


const SHEET_ORDER:= [
	"mouse", "mouse_left", "mouse_right", "wheel_up", "wheel_down", "mouse_move",
	"alt", "shift", "ctrl", "tab", "space", "enter", "escape", "backspace",
	"capslock", "up", "down", "left", "right",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",


	"mouse_middle",
]


const MOUSE_ART:= {
	MOUSE_BUTTON_LEFT: "mouse_left",
	MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_MIDDLE: "mouse_middle",
	MOUSE_BUTTON_WHEEL_UP: "wheel_up",
	MOUSE_BUTTON_WHEEL_DOWN: "wheel_down",
}


const KEY_ART:= {
	"alt": "alt", "shift": "shift", "ctrl": "ctrl", "control": "ctrl",
	"tab": "tab", "space": "space", "enter": "enter", "return": "enter",
	"escape": "escape", "esc": "escape", "backspace": "backspace",
	"capslock": "capslock", "caps lock": "capslock",
	"up": "up", "down": "down", "left": "left", "right": "right",
}


const KEY_W:= 96.0


const TRIM:= {
	"mouse": Rect2i(30, 20, 68, 88),
	"mouse_left": Rect2i(30, 20, 68, 88),
	"mouse_right": Rect2i(30, 20, 68, 88),
	"mouse_middle": Rect2i(30, 20, 68, 88),
	"wheel_down": Rect2i(30, 20, 68, 88),
	"wheel_up": Rect2i(30, 6, 68, 102),
	"mouse_move": Rect2i(18, 12, 92, 104),
	"alt": Rect2i(16, 28, 96, 72),
	"ctrl": Rect2i(16, 28, 96, 72),
	"tab": Rect2i(16, 28, 96, 72),
	"backspace": Rect2i(16, 28, 96, 72),
	"capslock": Rect2i(16, 28, 96, 70),
	"shift": Rect2i(16, 32, 96, 64),
	"space": Rect2i(16, 36, 96, 56),
}
const TRIM_FULL:= Rect2i(16, 16, 96, 96)


static var _cache: Dictionary = { }


static func of_action(action: String, tight:= false) -> AtlasTexture:
	return of_spec(InputSetup.spec_of(action), tight)


static func of_spec(spec: String, tight:= false) -> AtlasTexture:
	if spec == "":
		return null
	if spec.begins_with("mouse:"):
		return named(str(MOUSE_ART.get(spec.substr(6).to_int(), "mouse")), tight)


	var label:= (InputSetup.key_name(spec) if spec.begins_with("key:")
		else InputSetup.spec_label(spec)).to_lower()
	if KEY_ART.has(label):
		return named(str(KEY_ART [label]), tight)
	if label.length() == 1 and SHEET_ORDER.has(label):
		return named(label, tight)
	return null


static func rich(spec: String, height: int) -> String:
	if not spec.begins_with("mouse:"):
		return ""
	var art:= of_spec(spec)
	if art == null:
		return ""
	var r:= art.region
	return "[img width=%d height=%d region=%d,%d,%d,%d]%s[/img]" % [
		roundi(height * r.size.x / r.size.y), height,
		r.position.x, r.position.y, r.size.x, r.size.y, SHEET.resource_path]


static func is_wheel(spec: String) -> bool:
	if not spec.begins_with("mouse:"):
		return false
	return spec.substr(6).to_int() in [
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]


static func named(sprite: String, tight:= false) -> AtlasTexture:
	var key:= sprite + ("*" if tight else "")
	if _cache.has(key):
		return _cache [key]
	var i:= SHEET_ORDER.find(sprite)
	if i < 0:
		return null
	var tile:= Vector2(SHEET.get_width(), SHEET.get_height()) / Vector2(COLUMNS, ceilf(float(SHEET_ORDER.size()) / float(COLUMNS)))
	var atlas:= AtlasTexture.new()
	atlas.atlas = SHEET
	var cell:= Vector2(i % COLUMNS, i / COLUMNS) * tile
	if tight:
		var box: Rect2i = TRIM.get(sprite, TRIM_FULL)
		atlas.region = Rect2(cell + Vector2(box.position), Vector2(box.size))
	else:
		atlas.region = Rect2(cell, tile)
	_cache [key] = atlas
	return atlas


static func prompt_cap(spec: String, words: String, height: float) -> Control:
	var art: AtlasTexture = null
	if spec == "wheel":
		art = named("wheel_up", true)
	elif spec.begins_with("mouse:"):
		art = of_spec(spec, true)
	if art != null:
		var pic:= TextureRect.new()
		pic.texture = art
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(
			roundf(height * art.region.size.x / art.region.size.y), height)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pic
	var cap:= PanelContainer.new()
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.96, 1.0, 0.94)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 3.0
	cap.add_theme_stylebox_override("panel", sb)
	var key:= Label.new()
	key.text = words
	UiFont.style(key, 18, Hud.COL_PROMPT_KEY, 0, true)
	cap.add_child(key)
	return cap
