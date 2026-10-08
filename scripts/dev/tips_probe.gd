class_name DevTipsProbe
extends Node


const STEP:= 0.1

var _fails:= 0
var _layer: CanvasLayer


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("--- tips probe ---")
	_layer = CanvasLayer.new()
	add_child(_layer)

	_check_table()
	_check_usable()
	_check_clock()
	_check_switches()
	_check_bag_and_wrap()
	_check_loading()

	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--shot")
	if at >= 0 and at + 1 < ua.size() and DisplayServer.get_name() != "headless":
		await _shoot(ua [at + 1])

	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _plate() -> DemoPlate:
	var stamp:= Label.new()
	stamp.text = Hud.WATERMARK_TEXT
	stamp.add_theme_font_override("font", UiFont.watermark())
	stamp.add_theme_font_size_override("font_size", 24)
	var plate:= DemoPlate.new()
	plate.stamp = stamp
	_layer.add_child(plate)
	plate.set_process(false)
	return plate


func _run(plate: DemoPlate, seconds: float, tips_on:= true, warning_up:= false) -> void:
	for i in int(round(seconds / STEP)):
		plate.step(STEP, tips_on, warning_up)


func _check_table() -> void:
	print("\n[the table]")
	_ok(GameTips.count() >= 20, "%d tips" % GameTips.count())
	var bad_keys:= []
	var bad_cards:= []
	var dashes:= []
	var unfilled:= []
	for i in GameTips.count():
		var text:= str(GameTips.TIPS [i])
		for action in GameTips.ids_in(i, "key") + GameTips.ids_in(i, "keyboard"):
			if not InputMap.has_action(action) or InputSetup.hint(action) == "":
				bad_keys.append("%d:%s" % [i, action])


		for action in GameTips.ids_in(i, "keyboard"):
			if not InputSetup.specs_of(action).has("key:%s" % GameTips.say_keyboard(action)):
				bad_keys.append("%d:%s is not on a key" % [i, action])
		for card in GameTips.ids_in(i, "card"):
			if not TechTree.has_id(card):
				bad_cards.append("%d:%s" % [i, card])
		if String.chr(8212) in text or " -- " in text or " - " in text:
			dashes.append(i)
		var said:= GameTips.say(i)
		if "{" in said or "%" in said or said == "":
			unfilled.append(i)
	_ok(bad_keys.is_empty(), "every key named is a real, bound action %s" % str(bad_keys))
	_ok(bad_cards.is_empty(), "every card named is a real tech card %s" % str(bad_cards))
	_ok(dashes.is_empty(), "no dashes as punctuation %s" % str(dashes))
	_ok(unfilled.is_empty(), "every tip comes out whole, no braces left %s" % str(unfilled))
	for i in GameTips.count():
		if not GameTips.ids_in(i, "card").is_empty():
			print("  e.g. %s" % GameTips.say(i))
			break


func _check_usable() -> void:
	print("\n[tips that do not apply]")
	var shed:= -1
	for i in GameTips.count():
		if "yard_space" in GameTips.ids_in(i, "card"):
			shed = i
	_ok(shed >= 0, "there is a tip about extending the shed")
	if shed < 0:
		return
	var was:= SaveManager.current_map
	SaveManager.current_map = "warehouse"
	var on_warehouse:= GameTips.usable(shed)
	SaveManager.current_map = "plaza"
	var on_plaza:= GameTips.usable(shed)
	SaveManager.current_map = was
	_ok(on_warehouse, "it is shown on the warehouse")
	_ok(not on_plaza, "and not on the plaza, where the card is not sold")
	_ok(GameTips.usable(0), "a tip that names no card is always shown")


func _check_clock() -> void:
	print("\n[the clock]")
	var plate:= _plate()
	_run(plate, DemoPlate.TIP_FIRST - 1.0)
	_ok(plate.showing_tip() == "", "the stamp is up for the first minute")
	_run(plate, 1.0 + DemoPlate.FADE + DemoPlate.RESIZE + 0.2)
	var tip:= plate.showing_tip()
	_ok(tip != "", "then a tip: %s" % tip)
	_run(plate, DemoPlate.FADE + 0.1)
	_run(plate, DemoPlate.TIP_SECONDS - 1.0)
	_ok(plate.showing_tip() == tip, "the same tip is still up after nineteen seconds")
	_run(plate, 1.5)
	_ok(plate.showing_tip() == "", "and it has gone after twenty")
	_run(plate, 3.0)
	var gap:= DemoPlate.TIP_EVERY - DemoPlate.TIP_SECONDS
	_ok(plate.next_tip_in() > gap - 5.0 and plate.next_tip_in() <= gap,
		"the stamp is back for about forty seconds: %.0f s to go" % plate.next_tip_in())
	_run(plate, gap)
	_ok(plate.showing_tip() != "" and plate.showing_tip() != tip,
		"and then a different tip comes up")
	plate.queue_free()


func _check_switches() -> void:
	print("\n[the switch and the power warning]")
	var off:= _plate()
	_run(off, DemoPlate.TIP_FIRST + DemoPlate.TIP_EVERY + 5.0, false)
	_ok(off.showing_tip() == "", "with tips off the stamp never leaves")

	var cut:= _plate()
	_run(cut, DemoPlate.TIP_FIRST + 2.0)
	_ok(cut.showing_tip() != "", "a tip is up")
	_run(cut, 0.2, false)
	_ok(cut.showing_tip() == "", "turning tips off takes it down at once")

	var held:= _plate()
	_run(held, DemoPlate.TIP_FIRST + 30.0, true, true)
	_ok(held.showing_tip() == "", "no tip starts while the power warning is up")
	_run(held, 2.0)
	_ok(held.showing_tip() != "", "and one starts once it has gone")
	_run(held, 0.2, true, true)
	_ok(held.showing_tip() == "", "a power warning arriving takes a tip down")
	off.queue_free()
	cut.queue_free()
	held.queue_free()


func _check_bag_and_wrap() -> void:
	print("\n[order and fit]")
	var plate:= _plate()
	var seen:= { }
	for i in GameTips.count():
		seen [plate._next_tip()] = true
	_ok(seen.size() == GameTips.count(), "every tip once before any tip twice")

	var too_wide:= []
	var too_tall:= []
	for i in GameTips.count():
		var lines:= plate._wrap(GameTips.say(i)).split("\n")
		if lines.size() > 2:
			too_tall.append(i)
		for line in lines:
			if plate._text_w(line) > DemoPlate.TIP_MAX_W:
				too_wide.append(i)
	_ok(too_tall.is_empty(), "no tip needs more than two lines %s" % str(too_tall))
	_ok(too_wide.is_empty(), "no line runs past %d px %s" % [int(DemoPlate.TIP_MAX_W), str(too_wide)])
	plate.queue_free()


func _check_loading() -> void:
	print("\n[the loading screen]")
	var table:= { }
	for i in GameTips.count():
		table [GameTips.say(i)] = true
	Loading.show_screen("FIND THE NEEDLE", "PROBE")
	var first:= Loading.showing_tip()
	if not Cfg.show_tips:
		_ok(first == "", "tips are off in this player's settings, and the loading screen shows none")
		Loading.hide_screen()
		return
	_ok(table.has(first), "a tip from the table is up at once: %s" % first)

	var hold:= Loading.tip_seconds(first)
	_run_loading(hold - 0.5)
	_ok(Loading.showing_tip() == first, "the same tip is still up after %.1f s" % (hold - 0.5))
	_run_loading(1.0)
	_ok(Loading.showing_tip() == "", "then it fades")
	_run_loading(Loading.TIP_FADE * 2.0 + 0.1)
	var second:= Loading.showing_tip()
	_ok(table.has(second) and second != first, "and a different tip comes up: %s" % second)


	var seen:= { first: true, second: true }
	var now:= second
	for n in 8:
		var waited:= 0.0
		while (Loading.showing_tip() == now or Loading.showing_tip() == "") and waited < 60.0:
			Loading.step_tip(STEP)
			waited += STEP
		now = Loading.showing_tip()
		seen [now] = true
	_ok(seen.size() == 10 and not seen.has(""), "ten changes, ten different tips (%d)" % seen.size())


	var label: Label = Loading._tip
	var was:= label.text
	var too_tall:= []
	for i in GameTips.count():
		label.text = GameTips.say(i)
		if label.get_line_count() > 2:
			too_tall.append(i)
	label.text = was
	_ok(too_tall.is_empty(), "every tip fits in two lines under the bar %s" % str(too_tall))
	Loading.hide_screen()


func _run_loading(seconds: float) -> void:
	for i in int(round(seconds / STEP)):
		Loading.step_tip(STEP)


func _shoot(dir: String) -> void:
	print("\n[shots into %s]" % dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var ground:= ColorRect.new()
	ground.color = Color(0.36, 0.33, 0.26)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(ground)

	var stamp:= Label.new()
	stamp.text = Hud.WATERMARK_TEXT
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_font_override("font", UiFont.watermark())
	stamp.add_theme_font_size_override("font_size", Hud.WATERMARK_SIZE)
	stamp.add_theme_color_override("font_color", Hud.COL_WATERMARK)
	var note:= Label.new()
	note.text = Hud.WATERMARK_NOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", UiFont.regular())
	note.add_theme_font_size_override("font_size", Hud.WATERMARK_NOTE_SIZE)
	note.add_theme_color_override("font_color", Hud.COL_WATERMARK_NOTE)
	var lines:= VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.add_child(stamp)
	lines.add_child(note)

	var box:= StyleBoxFlat.new()
	box.bg_color = Hud.COL_WATERMARK_PLATE
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 4.0
	var plate:= DemoPlate.new()
	plate.add_theme_stylebox_override("panel", box)
	plate.stamp = lines
	plate.build_name = stamp.text
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder:= VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 2
	_layer.add_child(holder)
	holder.add_child(plate)
	plate.set_process(false)

	await _frames(plate, 0.3)
	await _save(dir.path_join("tips_0_stamp.png"))

	var longest:= 0
	for i in GameTips.count():
		if GameTips.say(i).length() > GameTips.say(longest).length():
			longest = i
	plate.show_tip(longest)
	await _frames(plate, DemoPlate.FADE + DemoPlate.RESIZE * 0.5)
	await _save(dir.path_join("tips_1_swap.png"))
	await _frames(plate, DemoPlate.RESIZE + DemoPlate.FADE + 3.0)
	await _save(dir.path_join("tips_2_tip.png"))


func _frames(plate: DemoPlate, seconds: float) -> void:
	var dt:= 1.0 / 60.0
	for i in int(ceil(seconds / dt)):
		plate.step(dt, true, false)
		await get_tree().process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("  wrote %s" % path)
