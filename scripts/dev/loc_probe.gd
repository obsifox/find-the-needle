class_name DevLocProbe
extends Node


const ACCENTS:= {
	"a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú",
	"A": "Á", "E": "É", "I": "Í", "O": "Ó", "U": "Ú",
}


const EXPANSION:= 1.35

const OPEN:= "«"
const CLOSE:= "»"


const PSEUDO_LOCALE:= "eo"

const POT_PATH:= "res://locale/game.pot"

var world: Node = null
var player: Node = null

var _pass:= 0
var _fail:= 0
var _translation: Translation = null
var _was_locale:= ""
var _had_settings:= false
var _saved_settings:= ""


var _seen: Array [Dictionary] = []


var _real:= ""

var _shots:= ""


func _named_locale() -> String:
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--loclang")
	if at < 0 or at + 1 >= ua.size():
		return ""
	return ua [at + 1]


func _shots_dir() -> String:
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--locshots")
	if at < 0 or at + 1 >= ua.size() or DisplayServer.get_name() == "headless":
		return ""
	DirAccess.make_dir_recursive_absolute(ua [at + 1])
	return ua [at + 1]


func run() -> void:
	print("\n--- localization ---\n")
	_keep_settings()
	_was_locale = TranslationServer.get_locale()

	var messages:= _read_pot()
	_case_pot(messages)
	_case_german()
	if messages.is_empty():
		print("\nNo messages in the .pot, so there is nothing to stand a fake on.")
		print("Run `python scripts/dev/gen_pot.py` after wrapping some strings.")
		_finish()
		return

	await _case_language_waits()


	_real = _named_locale()
	_shots = _shots_dir() if _real != "" else ""
	if _real != "":
		TranslationServer.set_locale(_real)
		BuildCatalog.invalidate()
		ItemDb.invalidate()
		TechTree.invalidate()
		print("\n  measuring the real %s catalogue, not the pseudolocale" % _real)
	else:
		_install(messages)
	await _case_panels()
	_case_world()
	_report()
	_finish()


func _read_pot() -> Dictionary:
	var out:= { }
	if not FileAccess.file_exists(POT_PATH):
		return out
	var text:= FileAccess.get_file_as_string(POT_PATH)
	var ctx:= ""
	for raw: String in text.split("\n"):
		var line:= raw.strip_edges()
		if line.begins_with("msgctxt \""):
			ctx = _unquote(line.substr(8))
		elif line.begins_with("msgid \""):
			var msgid:= _unquote(line.substr(6))
			if msgid != "":
				out [[ctx, msgid]] = msgid
			ctx = ""
		elif line.begins_with("msgid_plural \""):
			var plural:= _unquote(line.substr(13))
			if plural != "":
				out [["", plural]] = plural
	return out


func _unquote(s: String) -> String:
	var t:= s.strip_edges()
	if t.length() < 2:
		return ""
	return t.substr(1, t.length() - 2).c_unescape()


static func pseudo(src: String) -> String:
	var out:= ""
	var in_tag:= false
	for i: int in src.length():
		var ch:= src [i]
		if ch == "[":
			in_tag = true
		elif ch == "]":
			in_tag = false
		out += ch if in_tag else str(ACCENTS.get(ch, ch))


	var want:= int(ceil(src.length() * EXPANSION))
	var filler:= ""
	var pool:= ""
	for i: int in src.length():
		var ch:= src [i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
			pool += ch
	if pool == "":
		pool = "xyz"
	while out.length() + filler.length() < want:
		filler += pool [filler.length() % pool.length()]
	return OPEN + out + filler + CLOSE


func _install(messages: Dictionary) -> void:
	_translation = Translation.new()
	_translation.locale = PSEUDO_LOCALE
	for key: Array in messages:
		_translation.add_message(messages [key], pseudo(messages [key]), key [0])
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale(PSEUDO_LOCALE)


	BuildCatalog.invalidate()
	ItemDb.invalidate()
	TechTree.invalidate()


func _case_pot(messages: Dictionary) -> void:
	_ok(FileAccess.file_exists(POT_PATH),
		"locale/game.pot exists (run scripts/dev/gen_pot.py to make it)")
	print("    %d messages in the catalogue" % messages.size())


	var probe_fmt:= pseudo("$%s per metre")
	_ok(probe_fmt.contains("%s"), "the fake leaves a printf specifier alone")
	var probe_bb:= pseudo("[b]Hay[/b] wrapper")
	_ok(probe_bb.contains("[b]") and probe_bb.contains("[/b]"),
		"the fake leaves BBCode tags alone")
	_ok(pseudo("Hay").length() > 3, "the fake is longer than its source")


func _case_german() -> void:
	var before:= TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	_ok(tr("Language") == "Sprache",
		"locale/game.de.po is loaded and translating (Language -> Sprache)")
	TranslationServer.set_locale(before)

	Cfg.set_locale("de")
	Cfg.locale = ""
	Cfg.load_settings()
	_ok(Cfg.locale == "de", "the LANGUAGE row survives a write and a read")


	Cfg.set_locale("qq")
	_ok(Cfg.locale == "de", "an unknown language code is refused, not applied")


	Cfg.set_locale("en")
	var english:= BuildCatalog.display_name("belt")
	Cfg.set_locale("de")
	var german:= BuildCatalog.display_name("belt")
	_ok(english == "Conveyor Belt", "the catalogue reads English in English")
	_ok(german == "Förderband", "and rebuilds in German when the language moves")


	Cfg.set_locale("en")
	_ok(BuildCatalog.display_name("belt") == "Conveyor Belt",
		"and back again, so the drop is not a one time thaw")


	TranslationServer.set_locale("pl")
	_ok(tr("Language") == "Język",
		"locale/game.pl.po is loaded and translating (Language -> Język)")
	_ok(tr_n("%d needle", "%d needles", 5) != "%d needles",
		"a Polish count of five reads its third plural form")
	TranslationServer.set_locale(before)
	Cfg.set_locale("pl")
	_ok(BuildCatalog.display_name("belt") == "Taśmociąg",
		"and the catalogue rebuilds in Polish")


	TranslationServer.set_locale("zh")
	_ok(tr("Language") == "语言",
		"locale/game.zh.po is loaded and translating (Language -> 语言)")
	_ok(tr_n("%d needle", "%d needles", 5) != "%d needles",
		"a Chinese count of five reads its only plural form")
	TranslationServer.set_locale(before)
	Cfg.set_locale("zh")
	_ok(BuildCatalog.display_name("belt") == "传送带",
		"and the catalogue rebuilds in Chinese")


	TranslationServer.set_locale("fr")
	_ok(tr_n("%d needle", "%d needles", 0) == tr_n("%d needle", "%d needles", 1),
		"locale/game.fr.po is loaded, and a French zero reads like one")
	TranslationServer.set_locale("cs")
	_ok(tr_n("%d needle", "%d needles", 22) == tr_n("%d needle", "%d needles", 5)
		and tr_n("%d needle", "%d needles", 3) != tr_n("%d needle", "%d needles", 5),
		"locale/game.cs.po is loaded, with its three plural forms")
	TranslationServer.set_locale(before)
	Cfg.set_locale("cs")
	_ok(BuildCatalog.display_name("belt") == "Dopravní pás",
		"and the catalogue rebuilds in Czech")


	TranslationServer.set_locale("es")
	_ok(tr("Language") == "Idioma",
		"locale/game.es.po is loaded and translating (Language -> Idioma)")
	_ok(tr_n("%d needle", "%d needles", 0) == tr_n("%d needle", "%d needles", 5)
		and tr_n("%d needle", "%d needles", 1) != tr_n("%d needle", "%d needles", 5),
		"a Spanish zero reads as a plural, and one alone is the singular")
	TranslationServer.set_locale(before)
	Cfg.set_locale("es")
	_ok(BuildCatalog.display_name("belt") == "Cinta transportadora",
		"and the catalogue rebuilds in Spanish")


	TranslationServer.set_locale("pt")
	_ok(tr("Language") == "Idioma",
		"locale/game.pt_BR.po is loaded under \"pt\" (Language -> Idioma)")
	_ok(tr_n("%d needle", "%d needles", 0) == tr_n("%d needle", "%d needles", 5)
		and tr_n("%d needle", "%d needles", 1) != tr_n("%d needle", "%d needles", 5),
		"a Brazilian zero reads as a plural, and one alone is the singular")
	TranslationServer.set_locale(before)
	Cfg.set_locale("pt")
	_ok(BuildCatalog.display_name("belt") == "Esteira",
		"and the catalogue rebuilds in Portuguese")
	_ok(Cfg.lower_in_english("Balde") == "balde",
		"and a name inside a Portuguese sentence is lower case")


	TranslationServer.set_locale("ru")
	_ok(tr("Language") == "Язык",
		"locale/game.ru.po is loaded and translating (Language -> Язык)")
	_ok(tr_n("%d needle", "%d needles", 21) == tr_n("%d needle", "%d needles", 1)
		and tr_n("%d needle", "%d needles", 11) == tr_n("%d needle", "%d needles", 5),
		"a Russian 21 reads as one, and 11 reads as many")
	TranslationServer.set_locale(before)
	Cfg.set_locale("ru")
	_ok(BuildCatalog.display_name("belt") == "Конвейер",
		"and the catalogue rebuilds in Russian")


	TranslationServer.set_locale("tr")
	_ok(tr("Language") == "Dil",
		"locale/game.tr.po is loaded and translating (Language -> Dil)")
	_ok(Cfg.upper("kiriş ışık") == "KİRİŞ IŞIK",
		"Turkish capitals keep the dot: kiriş ışık -> KİRİŞ IŞIK")
	_ok(Cfg.lower_in_english("İĞNE KIRIK") == "iğne kırık",
		"and Turkish lower case keeps it off: İĞNE KIRIK -> iğne kırık")


	TranslationServer.set_locale("en")
	_ok(Cfg.upper("kiriş") == "KIRIŞ",
		"while every other language still capitalises the English way")
	Cfg.set_locale("tr")
	_ok(BuildCatalog.display_name("belt") == "Konveyör Bant",
		"and the catalogue rebuilds in Turkish")


	TranslationServer.set_locale("ja")
	_ok(tr("Language") == "言語",
		"locale/game.ja.po is loaded and translating (Language -> 言語)")
	_ok(tr_n("%d needle", "%d needles", 5) != "%d needles",
		"a Japanese count of five reads its only plural form")
	TranslationServer.set_locale(before)
	Cfg.set_locale("ja")
	_ok(BuildCatalog.display_name("belt") == "ベルトコンベア",
		"and the catalogue rebuilds in Japanese")
	_ok(UiFont._cjk_families() [0] == UiFont.JA_FAMILIES [0],
		"and the Han fallback asks for a Japanese face first")

	Cfg.set_locale("")


func _case_language_waits() -> void:
	Cfg.set_locale("en")
	var panel:= OptionsPanel.new()
	panel.quit_action = func() -> void: pass
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var before:= TranslationServer.get_locale()

	panel._pick_language("en")
	_ok(not panel.is_restart_notice_open(),
		"choosing the language already running asks for no restart")

	panel._pick_language("de")
	_ok(TranslationServer.get_locale() == before,
		"choosing German in the options leaves the running language alone")
	_ok(tr("Language") == "Language", "...so nothing on screen switches mid run")
	_ok(panel.is_restart_notice_open(), "...and the restart notice comes up")


	var later_de:= OptionsPanel._say_in(OptionsPanel.NOTICE ["later"], "de")
	_ok(later_de != OptionsPanel.NOTICE ["later"],
		"the German words can be read while the game runs in English")
	_ok(panel._restart_later.text == later_de + "\n" + OptionsPanel.NOTICE ["later"],
		"...so the notice's buttons say their word in German, then English")
	_ok(panel._restart_alt.visible, "...and the whole notice repeats in English below")
	_ok(Cfg.locale_pending(), "...and Cfg knows a switch is waiting")


	Cfg.locale = ""
	Cfg.load_settings()
	_ok(Cfg.locale == "de", "the choice was written to settings.cfg")
	Cfg.apply_locale()
	_ok(TranslationServer.get_locale().begins_with("de"),
		"and the next start comes up in German")
	_ok(not Cfg.locale_pending(), "...with nothing left waiting")

	panel.queue_free()
	Cfg.set_locale("")
	TranslationServer.set_locale(_was_locale)


func _case_panels() -> void:
	await _stand_up(OptionsPanel.new(), "OptionsPanel")
	await _stand_up(TechPanel.new(), "TechPanel")
	await _stand_up(CatalogPanel.new(), "CatalogPanel")
	await _stand_up(MapMenu.new(), "MapMenu")
	await _stand_up(CrashReportDialog.new(), "CrashReportDialog")


	if _real != "":
		await _stand_up(ShopMenu.new(), "ShopMenu")
		await _stand_up(PauseMenu.new(), "PauseMenu")
		await _stand_up(SellAllDialog.new(), "SellAllDialog")
		await _stand_up(ContractPanel.new(), "ContractPanel")
		await _stand_up(QuestPanel.new(), "QuestPanel")
		await _stand_up(DemoEndDialog.new(), "DemoEndDialog")


func _stand_up(panel: Node, label: String) -> void:
	add_child(panel)


	await get_tree().process_frame
	await get_tree().process_frame
	_walk(panel, label)
	if _shots != "":
		await _photograph(panel, label)
	panel.queue_free()


func _photograph(panel: Node, label: String) -> void:
	if panel.has_method("set_open"):
		panel.call("set_open", true)
	var tabs:= 1
	if panel is OptionsPanel:
		tabs = (panel as OptionsPanel)._pages.size()
	for t: int in tabs:
		if panel is OptionsPanel:
			(panel as OptionsPanel)._select_tab(t)
		for f: int in 20:
			await get_tree().process_frame
		var img:= get_viewport().get_texture().get_image()
		var path:= _shots.path_join("%s_%s_%d.png" % [_real, label, t])
		print("  [locshot] %s %s" % [path, "ok" if img.save_png(path) == OK else "FAILED"])
	if panel.has_method("set_open"):
		panel.call("set_open", false)


func _case_world() -> void:
	if world == null:
		return
	var hud:= world.find_child("HUD", true, false)
	if hud != null:
		_walk(hud, "HUD")


func _walk(root: Node, label: String) -> void:
	var before:= _seen.size()
	_descend(root, label)
	print("    %s: %d labels" % [label, _seen.size() - before])


static func _is_value(text: String) -> bool:
	var letters:= 0
	for i: int in text.length():
		var ch:= text [i]
		if ch.to_lower() != ch.to_upper() or _is_ideograph(ch.unicode_at(0)):
			letters += 1
	return letters <= 1


static func _is_ideograph(code: int) -> bool:
	return ((code >= 12352 and code <= 12543)
		or (code >= 13312 and code <= 19903)
		or (code >= 19968 and code <= 40959)
		or (code >= 44032 and code <= 55203))


func _is_cut(c: Control, text: String) -> bool:
	if c.size.x <= 1.0:
		return false
	var clips:= false
	if c is Label:
		var l:= c as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return false
		clips = l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	elif c is Button:
		var b:= c as Button
		if b.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return false
		clips = b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if not clips:
		return false
	var font:= c.get_theme_font("font")
	var fs:= c.get_theme_font_size("font_size")
	if font == null:
		return false
	var room:= c.size.x
	if c is Button:
		var sb:= c.get_theme_stylebox("normal")
		if sb != null:
			room -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	for line: String in text.split("\n"):
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 1.0:
			return true
	return false


func _descend(node: Node, path: String) -> void:
	var text:= ""
	if node is Label or node is Button or node is RichTextLabel or node is Label3D:
		text = str(node.get("text"))


	if text != "" and node.has_method("atr"):
		text = str(node.call("atr", text))
	if _is_value(text):
		text = ""
	if text.strip_edges() != "":


		var min_w:= -1.0
		var width:= -1.0
		var cut:= false


		var column:= -1.0
		if node is Control:
			min_w = (node as Control).get_minimum_size().x
			width = (node as Control).size.x
			cut = _is_cut(node as Control, text)
			if node is Label and (node as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
				column = (node as Control).custom_minimum_size.x
		_seen.append({
			"path": path,
			"text": text,
			"min_w": min_w,
			"width": width,
			"cut": cut,
			"column": column,
		})
	for child: Node in node.get_children():
		_descend(child, "%s/%s" % [path, child.name])


func _report() -> void:
	var missed: Array [Dictionary] = []
	var clipped: Array [Dictionary] = []
	var overflowed: Array [Dictionary] = []
	if _real != "":
		var cut: Array [Dictionary] = []
		var pushed: Array [Dictionary] = []
		for row: Dictionary in _seen:
			if bool(row ["cut"]):
				cut.append(row)
			var col:= float(row ["column"])
			if col > 1.0 and float(row ["min_w"]) > col + 1.0:
				pushed.append(row)
			var w:= float(row ["width"])
			if w > 1.0 and float(row ["min_w"]) > w + 1.0:
				overflowed.append(row)
		print("\n--- fit, %s ---\n" % _real)
		print("  %d labels measured" % _seen.size())
		_show("cut short by a clip or an ellipsis", cut)
		_show("wider than its column, so it pushes the row out of line", pushed)
		_show("too wide for the space it was given", overflowed)
		return
	for row: Dictionary in _seen:
		var text:= str(row ["text"])
		if not text.contains(OPEN):
			missed.append(row)
			continue
		if not text.contains(CLOSE):
			clipped.append(row)
		var min_w:= float(row ["min_w"])
		var width:= float(row ["width"])


		if width > 1.0 and min_w > width + 1.0:
			overflowed.append(row)

	var total:= _seen.size()
	var wrapped:= total - missed.size()
	print("\n--- coverage ---\n")
	print("  %d of %d labels went through tr()  (%d%%)"
		% [wrapped, total, 0 if total == 0 else roundi(100.0 * wrapped / total)])


	var measurable:= 0
	for row: Dictionary in _seen:
		if float(row ["width"]) > 1.0:
			measurable += 1
	print("  %d of them were laid out wide enough to judge for fit" % measurable)
	_show("never wrapped, so no translator will ever see it", missed)
	_show("truncated: the closing fence is gone", clipped)
	_show("too wide for the space it was given", overflowed)


func _show(what: String, rows: Array [Dictionary]) -> void:
	if rows.is_empty():
		return
	print("\n  %d %s:" % [rows.size(), what])


	var cap:= rows.size() if _real != "" else 15
	for i: int in mini(rows.size(), cap):
		var row: Dictionary = rows [i]
		var text:= str(row ["text"]).replace("\n", " ")
		if text.length() > 48:
			text = text.substr(0, 45) + "..."
		print("      %s   \"%s\"" % [row ["path"], text])
	if rows.size() > cap:
		print("      ... and %d more" % (rows.size() - 15))


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _keep_settings() -> void:
	_had_settings = FileAccess.file_exists(Cfg.SETTINGS_PATH)
	if _had_settings:
		_saved_settings = FileAccess.get_file_as_string(Cfg.SETTINGS_PATH)


func _give_settings_back() -> void:
	if _had_settings:
		var f:= FileAccess.open(Cfg.SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_saved_settings)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cfg.SETTINGS_PATH))
	Cfg.load_settings()
	Cfg.apply_locale()


func _finish() -> void:
	if _translation != null:
		TranslationServer.remove_translation(_translation)
	TranslationServer.set_locale(_was_locale)
	_give_settings_back()
	print("\n%d passed, %d failed\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
