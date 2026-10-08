class_name UiFont
extends RefCounted


const OVERRIDE_PATH:= "res://assets/fonts/hud.ttf"


const FAMILIES: Array [String] = [
	"Bahnschrift",
	"Barlow Condensed",
	"Oswald",
	"Roboto Condensed",
	"Archivo Narrow",
	"Segoe UI Semibold",
	"Segoe UI",
	"Noto Sans",
	"DejaVu Sans",
]


const CAPTION_FAMILIES: Array [String] = [
	"Arial",
	"Helvetica",
	"Segoe UI",
	"Roboto",
	"Noto Sans",
	"DejaVu Sans",
]


const WATERMARK_FAMILIES: Array [String] = [
	"Impact",
	"Haettenschweiler",
	"Anton",
	"Oswald",
	"Arial Black",
	"Liberation Sans Bold",
	"DejaVu Sans",
]


const MONO_FAMILIES: Array [String] = [
	"Consolas",
	"Cascadia Mono",
	"Menlo",
	"DejaVu Sans Mono",
	"Liberation Mono",
	"Courier New",
]


const CJK_FAMILIES: Array [String] = [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"PingFang SC",
	"Noto Sans CJK SC",
	"Noto Sans SC",
	"Source Han Sans SC",
	"WenQuanYi Micro Hei",
]


const JA_FAMILIES: Array [String] = [
	"Meiryo UI",
	"Meiryo",
	"Yu Gothic UI",
	"Yu Gothic",
	"Hiragino Sans",
	"Hiragino Kaku Gothic ProN",
	"Noto Sans CJK JP",
	"Noto Sans JP",
	"Source Han Sans JP",
]


const KO_FAMILIES: Array [String] = [
	"Malgun Gothic",
	"Apple SD Gothic Neo",
	"Noto Sans CJK KR",
	"Noto Sans KR",
	"Source Han Sans KR",
	"NanumGothic",
]

static var _cache: Dictionary = { }

static var _every_cache: Dictionary = { }

static var _cjk_fonts: Array [SystemFont] = []


static var _hosts: Array [Array] = []
static var _caption_cache: Dictionary = { }
static var _watermark_cache: Font = null
static var _mono_cache: Font = null


static func regular() -> Font:
	return _face(400)


static func bold() -> Font:
	return _face(700)


static func every_script(heavy: bool = false) -> Font:
	var weight:= 700 if heavy else 400
	if _every_cache.has(weight):
		return _every_cache [weight]
	var f:= _new_face(weight)
	_with_cjk(f, weight, true)
	_every_cache [weight] = f
	return f


static func watermark() -> Font:
	if _watermark_cache != null:
		return _watermark_cache
	var sf:= SystemFont.new()
	sf.font_names = PackedStringArray(WATERMARK_FAMILIES)
	sf.font_weight = 700
	sf.allow_system_fallback = true
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_with_cjk(sf, 700)
	_watermark_cache = sf
	return sf


static func mono() -> Font:
	if _mono_cache != null:
		return _mono_cache
	var sf:= SystemFont.new()
	sf.font_names = PackedStringArray(MONO_FAMILIES)
	sf.font_weight = 400
	sf.allow_system_fallback = true
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO


	_with_cjk(sf, 400, true)
	_mono_cache = sf
	return sf


static func caption(spacing: int) -> Font:
	if _caption_cache.has(spacing):
		return _caption_cache [spacing]
	var sf:= SystemFont.new()
	sf.font_names = PackedStringArray(CAPTION_FAMILIES)
	sf.font_weight = 400
	sf.allow_system_fallback = true
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_with_cjk(sf, 400)
	var v:= FontVariation.new()
	v.base_font = sf
	v.spacing_glyph = spacing
	_caption_cache [spacing] = v
	return v


static func _face(weight: int) -> Font:
	if _cache.has(weight):
		return _cache [weight]
	var f:= _new_face(weight)
	_with_cjk(f, weight)
	_cache [weight] = f
	return f


static func _new_face(weight: int) -> Font:
	var f: Font
	if ResourceLoader.exists(OVERRIDE_PATH):
		var loaded:= load(OVERRIDE_PATH) as Font
		if loaded != null:
			f = loaded.duplicate() as Font
	if f == null:
		var sf:= SystemFont.new()
		sf.font_names = PackedStringArray(FAMILIES)
		sf.font_weight = weight

		sf.allow_system_fallback = true
		sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		f = sf
	return f


static func _with_cjk(font: Font, weight: int, always: bool = false) -> void:
	var cjk:= SystemFont.new()
	cjk.font_names = _cjk_families()
	_cjk_fonts.append(cjk)
	cjk.font_weight = weight
	cjk.allow_system_fallback = true
	cjk.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO


	var hangul:= SystemFont.new()
	hangul.font_names = PackedStringArray(KO_FAMILIES)
	hangul.font_weight = weight
	hangul.allow_system_fallback = true
	hangul.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	if always:
		var chain:= font.fallbacks.duplicate()
		chain.append(cjk)
		chain.append(hangul)
		font.fallbacks = chain
		return
	var host: Array = [font, cjk, hangul]
	_hosts.append(host)
	_sync(host)


static func _sync(host: Array) -> void:
	var font: Font = host [0]
	var chain:= font.fallbacks.duplicate()
	chain.erase(host [1])
	chain.erase(host [2])
	if _cjk_on_screen():
		chain.append(host [1])
		chain.append(host [2])
	if chain != font.fallbacks:
		font.fallbacks = chain


static func _cjk_on_screen() -> bool:
	var locale:= TranslationServer.get_locale()
	return locale.begins_with("zh") or locale.begins_with("ja") or locale.begins_with("ko")


static func _cjk_families() -> PackedStringArray:
	var names:= PackedStringArray()
	if TranslationServer.get_locale().begins_with("ja"):
		names.append_array(JA_FAMILIES)
	elif TranslationServer.get_locale().begins_with("ko"):
		names.append_array(KO_FAMILIES)
	names.append_array(CJK_FAMILIES)
	return names


static func relocale() -> void:
	var names:= _cjk_families()
	for cjk: SystemFont in _cjk_fonts:
		if cjk.font_names != names:
			cjk.font_names = names


	for host: Array in _hosts:
		_sync(host)


static var _unspaced:= RegEx.create_from_string("[\\x{3040}-\\x{30ff}\\x{4e00}-\\x{9fff}]")
static var _alnum:= RegEx.create_from_string("[A-Za-z0-9]")


const _NO_LINE_START:= "、。，．・：；？！」』）】ーぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ%"
const _NO_LINE_END:= "「『（【"
const _CLAUSE_END:= "、。，？！"


static func unspaced(text: String) -> bool:
	return _unspaced.search(text) != null


static func can_break(text: String, i: int) -> bool:
	if i <= 0 or i >= text.length():
		return false
	var before:= text [i - 1]
	var after:= text [i]
	if _NO_LINE_START.contains(after) or _NO_LINE_END.contains(before):
		return false
	return not (_alnum.search(before) != null and _alnum.search(after) != null)


static func clause_break(text: String, i: int) -> bool:
	return i > 0 and _CLAUSE_END.contains(text [i - 1])


static func wrap_unspaced(text: String, width: int) -> String:
	var out:= ""
	var line:= ""
	var used:= 0
	for i: int in text.length():
		var ch:= text [i]
		if ch == "\n":
			out += line + "\n"
			line = ""
			used = 0
			continue
		var w:= 2 if unspaced(ch) or ch.unicode_at(0) >= 65280 else 1
		if line != "" and used + w > width and can_break(text, i):
			out += line.strip_edges() + "\n"
			line = ""
			used = 0
			if ch == " ":
				continue
		line += ch
		used += w
	return out + line.strip_edges()


static func style(label: Label, size: int, colour: Color, outline: int = 5,
		heavy: bool = false) -> void:
	label.add_theme_font_override("font", bold() if heavy else regular())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", outline)


static func style_rich(label: RichTextLabel, size: int, colour: Color,
		outline: int = 5, heavy: bool = false) -> void:
	var body:= bold() if heavy else regular()
	label.add_theme_font_override("normal_font", body)


	label.add_theme_font_override("bold_font", bold())
	label.add_theme_font_override("italics_font", body)
	label.add_theme_font_override("bold_italics_font", bold())
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_color_override("default_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", outline)
