extends SceneTree
## Temporary V42 RTL probe: autoload-level rtl flip on Control chain roots.


func _init() -> void:
	var fails: int = 0
	TranslationServer.set_locale("fa")

	# Simulate the cfg hook logic on a Control tree.
	var root_ctl:= Control.new()
	root_ctl.name = "SceneRoot"
	var panel:= PanelContainer.new()
	var lbl:= Label.new()
	panel.add_child(lbl)
	root_ctl.add_child(panel)
	root.call_deferred("add_child", root_ctl)
	await process_frame

	# apply the same rule cfg uses: top-of-chain Controls -> RTL
	if root_ctl.get_parent() is Control:
		print("PROBE FAIL: unexpected Control parent")
		fails += 1
	root_ctl.layout_direction = Control.LAYOUT_DIRECTION_RTL

	var eff_root: int = root_ctl.layout_direction
	var eff_panel: int = panel.layout_direction          # 0 = INHERITED
	var eff_label_is_rtl: bool = lbl.is_layout_rtl()
	print("PROBE root=", eff_root, " panel=", eff_panel, " label_rtl=", eff_label_is_rtl)
	if eff_label_is_rtl != true:
		print("PROBE FAIL: label not RTL")
		fails += 1

	# Real-world shaping path: a Label with Vazirmatn + Persian text.
	var fnt: Font = load("res://assets/fonts/Vazirmatn-Regular.ttf") as Font
	var lbl2:= Label.new()
	lbl2.text = "\u0633\u0644\u0627\u0645 \u0628\u0627\u0632\u06cc"
	lbl2.add_theme_font_override("font", fnt)
	root_ctl.add_child(lbl2)
	await process_frame
	await process_frame
	var ms: Vector2 = lbl2.get_minimum_size()
	print("PROBE label_min_size=", ms)
	if ms.x <= 4.0 or ms.y <= 4.0:
		print("PROBE FAIL: label not shaped")
		fails += 1
	var fnt_en:= Label.new()
	fnt_en.text = "hello"
	fnt_en.add_theme_font_override("font", fnt)
	root_ctl.add_child(fnt_en)
	await process_frame
	print("PROBE latin_min_size=", fnt_en.get_minimum_size())

	print("PROBE RESULT: ", "OK" if fails == 0 else "FAIL x%d" % fails)
	quit(1 if fails > 0 else 0)
