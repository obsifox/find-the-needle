class_name DevPowerWarningProbe
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
	print("--- power warning probe ---")
	_layer = CanvasLayer.new()
	add_child(_layer)

	_check_worst()
	_check_grid_empty()
	_check_timeline()
	_check_fixed()
	_check_duck()
	_check_feed_and_live_figure()
	_check_gas_plant_advice()

	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--shot")
	if at >= 0 and at + 1 < ua.size() and DisplayServer.get_name() != "headless":
		await _shoot(ua [at + 1])

	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


static func _net(sat: float, demand: float, cap: float) -> Dictionary:
	return { "satisfaction": sat, "demand": demand, "supply": sat * demand, "cap": cap }


func _fresh() -> PowerWarning:
	var w:= PowerWarning.new()
	_layer.add_child(w)

	w.set_process(false)
	return w


func _run(w: PowerWarning, seconds: float, nets: Array [Dictionary],
		toast:= false) -> void:
	var n:= int(round(seconds / STEP))
	for i in n:
		w.step(STEP, nets, toast, false)


func _check_worst() -> void:
	print("\n[which network]")
	var nets: Array [Dictionary] = [
		_net(0.6, 50.0, 30.0),
		_net(0.4, 50.0, 0.0),
		_net(0.5, 0.0, 30.0),
		_net(0.62, 40.0, 60.0),
	]
	var got:= PowerWarning.worst(nets, PowerWarning.WARN_BELOW)
	_ok(not got.is_empty() and is_equal_approx(float(got ["satisfaction"]), 0.6),
		"the worst network with a generator on it is picked, not the dead pole line")
	_ok(not got.is_empty() and not bool(got ["feed"]),
		"a network making all its generators can is told to build another")

	var hungry: Array [Dictionary] = [_net(0.62, 40.0, 60.0)]
	var h:= PowerWarning.worst(hungry, PowerWarning.WARN_BELOW)
	_ok(not h.is_empty() and bool(h ["feed"]),
		"a network whose generators could make enough is told to feed them")

	var fine: Array [Dictionary] = [_net(0.66, 50.0, 30.0), _net(1.0, 10.0, 30.0)]
	_ok(PowerWarning.worst(fine, PowerWarning.WARN_BELOW).is_empty(),
		"66% is not short enough to warn about")
	var edge: Array [Dictionary] = [_net(0.65, 50.0, 30.0)]
	_ok(not PowerWarning.worst(edge, PowerWarning.WARN_BELOW).is_empty(),
		"65% exactly is")


func _check_grid_empty() -> void:
	print("\n[the grid]")
	var grid:= PowerGrid.new(null)
	_ok(grid.networks().is_empty(), "a grid with no yard has no networks")
	grid.unmetered = true
	_ok(grid.networks().is_empty(), "an unmetered grid reports nothing short")


func _check_timeline() -> void:
	print("\n[when it shows]")
	var w:= _fresh()
	var short: Array [Dictionary] = [_net(0.6, 50.0, 30.0)]
	_run(w, PowerWarning.SETTLE_SECONDS - 0.3, short)
	_ok(w.showing_text() == "", "not up before the shortage has settled")
	_run(w, 0.5, short)
	var text:= w.showing_text()
	_ok(text != "", "up once it has")
	_ok("60%" in text, "it quotes the yard's figure: %s" % text.replace("\n", " / "))
	_ok("Build another hay generator" in text, "and says to build another generator")
	_ok("tech tree (Stronger Generator)" in text, "or to upgrade it, naming the card")

	_run(w, PowerWarning.SHOW_SECONDS - 0.5, short)
	_ok(w.showing_text() != "", "still up just short of fifteen seconds")
	_run(w, 0.8, short)
	_ok(w.showing_text() == "", "down after fifteen seconds")

	_run(w, 120.0, short)
	_ok(w.showing_text() == "", "not back two minutes later")
	_ok(w.repeat_in() > 0.0, "and it knows it is waiting: %.0f s to go" % w.repeat_in())
	_run(w, PowerWarning.REPEAT_SECONDS - 120.0 - PowerWarning.SHOW_SECONDS + 0.5, short)
	_ok(w.showing_text() != "", "back five minutes after it last went up")

	_run(w, 1.0, short)
	w.step(STEP, short, false, true)
	_ok(not w.visible, "camera mode hides it")
	w.queue_free()


func _check_fixed() -> void:
	print("\n[fixing the yard]")
	var w:= _fresh()
	var short: Array [Dictionary] = [_net(0.6, 50.0, 30.0)]
	var fixed: Array [Dictionary] = [_net(1.0, 50.0, 60.0)]
	_run(w, PowerWarning.SETTLE_SECONDS + 1.0, short)
	_ok(w.showing_text() != "", "up")
	_run(w, 1.0, fixed)
	_ok(w.showing_text() != "", "a second of full power does not take it down")
	_run(w, 1.0, fixed)
	_ok(w.showing_text() == "", "a second and a half does")

	var flicker: Array [Dictionary] = [_net(0.68, 50.0, 30.0)]
	var w2:= _fresh()
	_run(w2, PowerWarning.SETTLE_SECONDS + 1.0, short)
	_run(w2, 5.0, flicker)
	_ok(w2.showing_text() != "", "climbing to 68% is not fixed, so it stays up")
	w.queue_free()
	w2.queue_free()


func _check_duck() -> void:
	print("\n[under a toast]")
	var w:= _fresh()
	var short: Array [Dictionary] = [_net(0.6, 50.0, 30.0)]
	_run(w, PowerWarning.SETTLE_SECONDS + 0.5, short)
	_ok(w.showing_text() != "", "up")
	_run(w, 5.0, short, true)
	_run(w, PowerWarning.SHOW_SECONDS - 2.0, short)
	_ok(w.showing_text() != "", "five seconds under a toast do not count against it")
	_run(w, 3.0, short)
	_ok(w.showing_text() == "", "and it still comes down")

	var late:= _fresh()
	_run(late, PowerWarning.SETTLE_SECONDS + 1.0, short, true)
	_ok(late.showing_text() == "", "it does not go up while a toast is showing")
	_run(late, 0.2, short)
	_ok(late.showing_text() != "", "and goes up the moment the toast is gone")
	w.queue_free()
	late.queue_free()


func _check_feed_and_live_figure() -> void:
	print("\n[the words]")
	var w:= _fresh()
	var hungry: Array [Dictionary] = [_net(0.3, 40.0, 60.0)]
	_run(w, PowerWarning.SETTLE_SECONDS + 0.5, hungry)
	var text:= w.showing_text()
	_ok("Feed your hay generator" in text, "a hungry yard is told to feed: %s"
		% text.replace("\n", " / "))
	var worse: Array [Dictionary] = [_net(0.52, 40.0, 30.0)]
	_run(w, 1.0, worse)
	text = w.showing_text()
	_ok("52%" in text, "the figure follows the yard while it is up")
	_ok("Feed your hay generator" in text, "the advice does not flip mid read")
	_ok(not (String.chr(8212) in text or " -- " in text), "no dashes in the copy")
	var maxed:= PowerWarning.advice(false, true)
	_ok(maxed == "Build another hay generator.",
		"with the boiler maxed it does not send the player to the tree: %s" % maxed)
	_ok(not ("tech tree" in PowerWarning.advice(true, false)),
		"a hungry yard is not sent to the tree either")
	w.queue_free()


func _check_gas_plant_advice() -> void:
	print("\n[the gas plant]")
	var plant:= PowerWarning.advice(false, false, true)
	_ok(plant.begins_with("Build a Gas Plant"), "the plant advice names it: %s" % plant)
	_ok("3 times" in plant, "...and says what it is worth: %s" % plant)
	_ok(PowerWarning.advice(true, false, true) == plant,
		"a hungry line of generators is pointed at the plant too")
	_ok(not (String.chr(8212) in plant or " -- " in plant), "no dashes in it")
	var two:= _net(0.4, 40.0, 30.0)
	two ["hay_gens"] = 2
	var twos: Array [Dictionary] = [two]
	var picked:= PowerWarning.worst(twos, PowerWarning.WARN_BELOW)
	_ok(int(picked.get("hay_gens", 0)) == 2, "the worst network carries its Hay Generator count")
	var was_demo:= Cfg.DEMO
	Tech.grant("pelletizer", 1)
	Tech.grant("water_main", 1)

	Cfg.DEMO = false
	TechTree._nodes.clear()
	TechTree._order.clear()
	Tech.grant("gas_plant", 1)
	var w:= _fresh()
	_run(w, PowerWarning.SETTLE_SECONDS + 0.5, twos)
	_ok("Build a Gas Plant" in w.showing_text(),
		"two Hay Generators short, with the card owned: %s" % w.showing_text().replace("\n", " / "))
	w.queue_free()
	var one:= _net(0.4, 40.0, 30.0)
	one ["hay_gens"] = 1
	var ones: Array [Dictionary] = [one]
	w = _fresh()
	_run(w, PowerWarning.SETTLE_SECONDS + 0.5, ones)
	_ok(not ("Gas Plant" in w.showing_text()), "one generator short is not told to replace it")
	w.queue_free()

	Cfg.DEMO = true
	TechTree._nodes.clear()
	TechTree._order.clear()
	w = _fresh()
	_run(w, PowerWarning.SETTLE_SECONDS + 0.5, twos)
	_ok(not ("Gas Plant" in w.showing_text()),
		"in the demo two generators short are told to build another: %s"
			% w.showing_text().replace("\n", " / "))
	w.queue_free()
	Cfg.DEMO = was_demo
	TechTree._nodes.clear()
	TechTree._order.clear()
	Tech.reset()


func _shoot(dir: String) -> void:
	print("\n[shots into %s]" % dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var ground:= ColorRect.new()
	ground.color = Color(0.36, 0.33, 0.26)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(ground)
	var w:= PowerWarning.new()
	_layer.add_child(w)
	w.set_process(false)
	var short: Array [Dictionary] = [_net(0.6, 50.0, 30.0)]
	var marks:= [0.25, 1.2, 3.42, 6.0]
	var clock:= 0.0
	var next:= 0

	_run(w, PowerWarning.SETTLE_SECONDS - 0.05, short)
	while next < marks.size():
		var dt:= 1.0 / 60.0
		w.step(dt, short, false, false)
		clock += dt
		await get_tree().process_frame
		if clock - 0.05 >= float(marks [next]):
			await RenderingServer.frame_post_draw
			var img:= get_viewport().get_texture().get_image()
			var path:= dir.path_join("power_warning_%d.png" % next)
			img.save_png(path)
			print("  wrote %s at %.2f s" % [path, marks [next]])
			next += 1
