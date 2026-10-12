extends SceneTree
## Temporary V42 probe: fa.po + Vazirmatn + translation + plural sanity.


func _init() -> void:
	var fails: int = 0

	# 1) fa.po loads and translates
	var fa: Translation = load("res://locale/game.fa.po") as Translation
	if fa == null:
		print("PROBE FAIL: fa.po did not load")
		fails += 1
	else:
		TranslationServer.add_translation(fa)
		TranslationServer.set_locale("fa")
		var quit_tr: String = TranslationServer.translate("QUIT")
		var small_tr: String = TranslationServer.translate("SMALL")
		print("PROBE QUIT -> ", quit_tr)
		print("PROBE SMALL -> ", small_tr)
		if quit_tr == "QUIT" or quit_tr.is_empty():
			print("PROBE FAIL: QUIT untranslated")
			fails += 1
		if small_tr == "SMALL" or small_tr.is_empty():
			print("PROBE FAIL: SMALL untranslated")
			fails += 1
		var plural_one: String = TranslationServer.translate("collect %d needle")
		print("PROBE PLURAL0 -> ", plural_one)
		if not plural_one.contains("%d"):
			print("PROBE FAIL: placeholder lost in plural")
			fails += 1

	# 2) Vazirmatn covers Persian glyphs
	var reg: FontFile = load("res://assets/fonts/Vazirmatn-Regular.ttf") as FontFile
	if reg == null:
		print("PROBE FAIL: Vazirmatn-Regular did not load")
		fails += 1
	else:
		var shint: bool = reg.has_char(0x0634)  # ش
		var zwnj: bool = reg.has_char(0x200C)  # ZWNJ
		var latin: bool = reg.has_char(0x0041)  # A
		print("PROBE FONT sh=", shint, " zwnj=", zwnj, " A=", latin)
		if not shint or not zwnj or not latin:
			print("PROBE FAIL: glyph coverage")
			fails += 1

	# 3) Persian entry count via po re-parse (spot: no empty msgstr except header)
	var raw: PackedStringArray = FileAccess.get_file_as_string("res://locale/game.fa.po").split("\n")
	var entries: int = 0
	for line: String in raw:
		if line.begins_with("msgid ") and not line.begins_with('msgid ""'):
			entries += 1
	print("PROBE PO entries=", entries)
	if entries < 2800:
		print("PROBE FAIL: too few entries")
		fails += 1

	print("PROBE RESULT: ", "OK" if fails == 0 else "FAIL x%d" % fails)
	quit(1 if fails > 0 else 0)
