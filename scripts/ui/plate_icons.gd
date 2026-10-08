class_name PlateIcons
extends RefCounted


const _HEAD:= "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">"
const _FOOT:= "</svg>"

const DRAWINGS:= {

	"eye": "<circle cx=\"12\" cy=\"12\" r=\"2.5\"/><path d=\"M2.5 12c2.6 -4.3 5.8 -6.5 9.5 -6.5s6.9 2.2 9.5 6.5c-2.6 4.3 -5.8 6.5 -9.5 6.5s-6.9 -2.2 -9.5 -6.5z\"/>",

	"eye_off": "<path d=\"M10.6 10.6a2 2 0 0 0 2.8 2.8\"/><path d=\"M16.7 16.7c-1.4 1.2 -3 1.8 -4.7 1.8c-3.7 0 -6.9 -2.2 -9.5 -6.5c1.3 -2.2 2.8 -3.8 4.4 -4.9m3.1 -1.4a8 8 0 0 1 2 -0.2c3.7 0 6.9 2.2 9.5 6.5c-0.7 1.2 -1.5 2.3 -2.3 3.2\"/><path d=\"M3 3l18 18\"/>",

	"pin": "<circle cx=\"12\" cy=\"10\" r=\"2.6\"/><path d=\"M12 21.5c-4.5 -4.6 -7 -8.3 -7 -11.3a7 7 0 0 1 14 0c0 3 -2.5 6.7 -7 11.3z\"/>",

	"link": "<path d=\"M9 15l6 -6\"/><path d=\"M11 6l0.5 -0.5a4 4 0 0 1 5.7 5.7l-0.5 0.5\"/><path d=\"M13 18l-0.5 0.5a4 4 0 0 1 -5.7 -5.7l0.5 -0.5\"/>",

	"take": "<path d=\"M3 12h11\"/><path d=\"M10 8l4 4l-4 4\"/><path d=\"M20 4v16\"/>",

	"put": "<path d=\"M4 4v16\"/><path d=\"M9 12h11\"/><path d=\"M16 8l4 4l-4 4\"/>",

	"zone": "<circle cx=\"12\" cy=\"12\" r=\"8\" stroke-dasharray=\"3.1 2.6\"/><circle cx=\"12\" cy=\"12\" r=\"1.2\"/>",

	"drop": "<path d=\"M12 3v13\"/><path d=\"M7 11l5 5l5 -5\"/><path d=\"M5 21h14\"/>",

	"lock": "<rect x=\"5\" y=\"11\" width=\"14\" height=\"10\" rx=\"1.5\"/><path d=\"M8 11v-4a4 4 0 0 1 8 0v4\"/><circle cx=\"12\" cy=\"16\" r=\"1\"/>",

	"upgrade": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 16.5v-9\"/><path d=\"M8 11.5l4 -4l4 4\"/>",

	"bolt": "<path d=\"M13 3v7h6l-8 11v-7h-6l8 -11z\"/>",

	"working": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M8.5 12.2l2.4 2.4l4.6 -4.8\"/>",

	"waiting": "<path d=\"M6.5 3h11\"/><path d=\"M6.5 21h11\"/><path d=\"M8 3v2.5a4 4 0 0 0 4 4a4 4 0 0 0 4 -4v-2.5\"/><path d=\"M8 21v-2.5a4 4 0 0 1 4 -4a4 4 0 0 1 4 4v2.5\"/>",

	"stopped": "<path d=\"M10.3 4.2l-7.6 13.2a2 2 0 0 0 1.7 3h15.2a2 2 0 0 0 1.7 -3l-7.6 -13.2a2 2 0 0 0 -3.4 0z\"/><path d=\"M12 9.5v4\"/><path d=\"M12 17h0.01\"/>",

	"picks": "<path d=\"M12 3v9\"/><path d=\"M8.5 6.5l3.5 -3.5l3.5 3.5\"/><path d=\"M4 14h16v7h-16z\"/><path d=\"M9.5 17.5h5\"/>",

	"route": "<circle cx=\"6\" cy=\"19\" r=\"2\"/><circle cx=\"18\" cy=\"5\" r=\"2\"/><path d=\"M8 19h8.5a3.5 3.5 0 0 0 0 -7h-9a3.5 3.5 0 0 1 0 -7h8.5\"/>",

	"order": "<path d=\"M11 6h9\"/><path d=\"M11 12h9\"/><path d=\"M12 18h8\"/><path d=\"M4 16a2 2 0 1 1 4 0c0 0.6 -0.5 1 -1 1.5l-3 2.5h4\"/><path d=\"M6 10v-6l-2 2\"/>",

	"job": "<path d=\"M7 10h3v-3l-3.5 -3.5a6 6 0 0 1 8 8l6 6a2 2 0 0 1 -3 3l-6 -6a6 6 0 0 1 -8 -8l3.5 3.5\"/>",

	"reset": "<path d=\"M20 11a8 8 0 0 0 -14.9 -3.5\"/><path d=\"M4 4v4h4\"/><path d=\"M4 13a8 8 0 0 0 14.9 3.5\"/><path d=\"M20 20v-4h-4\"/>",

	"throw": "<path d=\"M3 20c2 -10 9 -15 15 -12\"/><path d=\"M14.5 5.5l3.8 2.4l-2.3 3.8\"/><path d=\"M2 21h20\"/>",

	"angle": "<path d=\"M3 20h18\"/><path d=\"M3 20l13 -13\"/><path d=\"M10 20a7 7 0 0 0 -2 -5\"/>",

	"gauge": "<path d=\"M4.5 17a8.5 8.5 0 1 1 15 0\"/><path d=\"M12 14l4 -5\"/><circle cx=\"12\" cy=\"14\" r=\"1.4\"/>",

	"back": "<path d=\"M20 12h-15\"/><path d=\"M10 6l-6 6l6 6\"/>",
	"forward": "<path d=\"M4 12h15\"/><path d=\"M14 6l6 6l-6 6\"/>",

	"wheel": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><circle cx=\"12\" cy=\"12\" r=\"2.5\"/><path d=\"M12 3.5v6\"/><path d=\"M12 14.5v6\"/><path d=\"M3.5 12h6\"/><path d=\"M14.5 12h6\"/>",

	"tank": "<path d=\"M6 3h12v13h-12z\"/><path d=\"M6 8h12\"/><path d=\"M8 16v5\"/><path d=\"M16 16v5\"/>",

	"dial": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 12l4.5 -3\"/><path d=\"M12 3v2\"/><path d=\"M21 12h-2\"/><path d=\"M3 12h2\"/>",

	"flow": "<path d=\"M3 7h11\"/><path d=\"M3 12h15\"/><path d=\"M3 17h11\"/><path d=\"M17 14l3 -2l-3 -2\"/>",

	"bright": "<circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2\"/><path d=\"M12 20v2\"/><path d=\"M2 12h2\"/><path d=\"M20 12h2\"/><path d=\"M4.9 4.9l1.4 1.4\"/><path d=\"M17.7 17.7l1.4 1.4\"/><path d=\"M4.9 19.1l1.4 -1.4\"/><path d=\"M17.7 6.3l1.4 -1.4\"/>",

	"plug": "<path d=\"M9 3v5\"/><path d=\"M15 3v5\"/><path d=\"M6 8h12v3a6 6 0 0 1 -12 0z\"/><path d=\"M12 17v4\"/>",

	"split": "<path d=\"M12 21v-8\"/><path d=\"M12 13l-6 -6\"/><path d=\"M12 13l6 -6\"/><path d=\"M4 9v-4h4\"/><path d=\"M20 9v-4h-4\"/>",

	"cart": "<circle cx=\"9\" cy=\"20\" r=\"1.5\"/><circle cx=\"17\" cy=\"20\" r=\"1.5\"/><path d=\"M3 4h2l2.4 11h11l2 -8h-14.5\"/>",

	"moon": "<path d=\"M20 14.5a8.5 8.5 0 1 1 -10.5 -10.5a7 7 0 0 0 10.5 10.5z\"/>",

	"sun": "<circle cx=\"12\" cy=\"12\" r=\"3.5\"/><path d=\"M12 3v2\"/><path d=\"M12 19v2\"/><path d=\"M3 12h2\"/><path d=\"M19 12h2\"/><path d=\"M5.6 5.6l1.4 1.4\"/><path d=\"M17 17l1.4 1.4\"/><path d=\"M5.6 18.4l1.4 -1.4\"/><path d=\"M17 7l1.4 -1.4\"/>",


	"shovel": "<path d=\"M16.5 4.5l3 3\"/><path d=\"M10.5 13.5l7.5 -7.5\"/><path d=\"M9 12l3 3l-3.5 3.5c-1.5 1.5 -3.5 2 -4.5 1.5c-0.5 -1 0 -3 1.5 -4.5z\"/>",

	"closest": "<path d=\"M4 9h5v-5\"/><path d=\"M3 3l6 6\"/><path d=\"M4 15h5v5\"/><path d=\"M3 21l6 -6\"/><path d=\"M20 9h-5v-5\"/><path d=\"M15 9l6 -6\"/><path d=\"M20 15h-5v5\"/><path d=\"M15 15l6 6\"/>",
}

static var _cache: Dictionary = { }


static func texture(name: String, px: int) -> Texture2D:
	var key:= "%s@%d" % [name, px]
	if _cache.has(key):
		return _cache [key]
	if not DRAWINGS.has(name):
		push_warning("PlateIcons: no drawing called %s" % name)
		return null
	var img:= Image.new()


	var err:= img.load_svg_from_string(_HEAD + str(DRAWINGS [name]) + _FOOT,
		float(px) * 2.0 / 24.0)
	if err != OK or img.is_empty():
		return null
	img.generate_mipmaps()
	var tex:= ImageTexture.create_from_image(img)
	_cache [key] = tex
	return tex


static func rect(name: String, px: int, ink: Color) -> TextureRect:
	var r:= TextureRect.new()
	r.texture = texture(name, px)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.self_modulate = ink
	return r


static func on_button(b: Button, name: String, px: int, ink: Color, dim: Color) -> void:
	b.icon = texture(name, px)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", px)
	b.add_theme_constant_override("h_separation", 8)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("icon_disabled_color", dim)
