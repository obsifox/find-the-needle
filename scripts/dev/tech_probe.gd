class_name DevTechProbe
extends Node


var warehouse: Warehouse

func run() -> void:
	var fails:= 0
	fails += _check_table()
	fails += _check_tuning()
	fails += _check_reachable()
	fails += _check_buying()
	fails += _check_effects()
	fails += _check_wiring()
	fails += _check_warehouse()
	fails += _check_site()
	fails += _check_save()
	fails += _check_layout()
	fails += _check_surge()
	fails += _check_clicks()
	fails += _check_search()
	fails += _check_jump()
	fails += _check_show()
	fails += _check_contract_gate()
	fails += await _check_text_scale()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _check_text_scale() -> int:
	print("\n=== text scale ===")
	var bad:= 0

	var caps: Array = [
		[Vector2(1920, 1080), 2.0, 1.5],
		[Vector2(1920, 1080), 1.25, 1.25],
		[Vector2(1920, 1200), 2.0, 1.5],
		[Vector2(2560, 1440), 2.0, 2.0],
		[Vector2(3840, 2160), 2.0, 2.0],
		[Vector2(1280, 720), 2.0, 1.0],
		[Vector2(1024, 600), 1.5, 1.0],
		[Vector2(1920, 1080), 1.0, 1.0],
	]
	for cap: Array in caps:
		var got:= TechPanel.layout_scale_for(cap [0], cap [1])
		if not is_equal_approx(got, cap [2]):
			bad += _fail("a %s window asking %.2f draws at %.3f, expected %.2f"
				% [cap [0], cap [1], got, cap [2]])
		var room: Vector2 = cap [0] / got
		if got > 1.0 and (room.x < TechPanel.MIN_LAYOUT.x - 0.5
				or room.y < TechPanel.MIN_LAYOUT.y - 0.5):
			bad += _fail("a %s window at %.3f leaves %s to lay out in" % [cap [0], got, room])

	var asked_before:= Cfg.tech_text_scale
	var locale_before:= TranslationServer.get_locale()
	var window:= TechPanel.MIN_LAYOUT * 1.5
	for locale: String in ["en", "de", "pl"]:
		TranslationServer.set_locale(locale)
		Cfg.tech_text_scale = 1.5
		var host:= Control.new()
		host.size = window
		add_child(host)
		var panel:= TechPanel.new()
		host.add_child(panel)
		panel.set_open(true)
		for i in 3:
			await get_tree().process_frame
		if not is_equal_approx(panel._layout_scale, 1.5):
			bad += _fail("[%s] drawn at %.3f in a %s window, expected 1.5"
				% [locale, panel._layout_scale, window])

		var worst:= Vector2.ZERO
		var worst_id:= ""
		var grew:= 0
		for id: String in TechTree.ids():
			panel._select(id)
			for i in 3:
				await get_tree().process_frame
			var over:= panel._root.size - TechPanel.MIN_LAYOUT
			if over.x > 0.5 or over.y > 0.5:
				grew += 1
				if over.x + over.y > worst.x + worst.y:
					worst = over
					worst_id = id
			var drawn:= panel._root.size * panel._root.scale
			if drawn.x > window.x + 0.5 or drawn.y > window.y + 0.5:
				bad += _fail("[%s] %s: the panel draws %s in a %s window"
					% [locale, id, drawn, window])
		if grew > 0:
			bad += _fail("[%s] %d cards made the panel grow past %s, worst %s by %s"
				% [locale, grew, TechPanel.MIN_LAYOUT, worst_id, worst])
		elif panel._ins_name.get_combined_minimum_size().y <= 0.0:
			bad += _fail("[%s] the inspector title measured nothing, so nothing was measured"
				% locale)
		if panel._viewport.size.x < 200.0:
			bad += _fail("[%s] the board is left %.0f px wide" % [locale, panel._viewport.size.x])

		var squeezed: Array [String] = []
		for id: String in panel._cards:
			var want:= panel.card_rect(id).size
			var need: Vector2 = (panel._cards [id] as Control).get_combined_minimum_size()
			if need.x > want.x + 0.5 or need.y > want.y + 0.5:
				var parts: Dictionary = panel._parts.get(id, { })
				var says: Array [String] = []
				for part: String in ["meta", "name", "cost", "rank"]:
					var l: Label = parts.get(part)
					if l != null and l.visible and l.text != "":
						says.append("%s '%s' %s" % [part, l.text, l.get_combined_minimum_size()])
				squeezed.append("%s wants %s in %s (%s)" % [id, need, want, ", ".join(says)])
		if not squeezed.is_empty():
			bad += _fail("[%s] %d cards are too small for their words: %s"
				% [locale, squeezed.size(), "; ".join(squeezed)])

		var bold:= UiFont.bold()
		for lane: Dictionary in panel._lanes:
			var lane_name:= TechTree.branch_name(str(lane ["branch"])).to_upper()
			var w:= bold.get_string_size(lane_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			if w > TechPanel.RAIL_W - 24.0:
				bad += _fail("[%s] the rail's %s is %.0f px in %.0f"
					% [locale, lane_name, w, TechPanel.RAIL_W - 24.0])

		if grew == 0 and squeezed.is_empty():
			print("  ok    [%s] every card fits the panel at 1.5 in %s, and every card fits its words"
				% [locale, window])
		panel.set_open(false)
		host.queue_free()
		await get_tree().process_frame
	Cfg.tech_text_scale = asked_before
	TranslationServer.set_locale(locale_before)
	return bad


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _check_tuning() -> int:
	print("\n=== tuning fold ===")
	var bad:= 0
	var groups:= TechTree.tuning_groups()
	var strips:= 0
	for id: String in TechTree.ids():
		if not TechTree.is_tuning(id):
			for need: String in TechTree.requires(id):
				if TechTree.is_tuning(need):
					bad += _fail("%s requires %s, which is a strip of a folded card"
						% [id, need])
			continue
		strips += 1
		var needs: Array = TechTree.requires(id)
		if needs.size() != 1:
			bad += _fail("%s is a tuning node with %d requirements, the fold draws one wire"
				% [id, needs.size()])
			continue


		var above:= str(needs [0])
		var machine:= TechTree.tuned_machine(id)
		if machine == "":
			bad += _fail("%s hangs off %s and the chain reaches no machine"
				% [id, above])
			continue
		if TechTree.is_tuning(above) and TechTree.tuned_machine(above) != machine:
			bad += _fail("%s hangs off %s, a strip on another machine's card"
				% [id, above])
		if TechTree.branch_of(machine) != TechTree.branch_of(id):
			bad += _fail("%s is filed under %s and its machine %s under %s"
				% [id, TechTree.branch_of(id), machine, TechTree.branch_of(machine)])

		var licenses_tool:= ItemDb.ids().any(
			func(item: String) -> bool: return ItemDb.unlock_of(item) == machine)
		if BuildCatalog.builds_for(machine).is_empty() and not licenses_tool:
			bad += _fail("%s tunes %s, which builds nothing and licenses no tool"
				% [id, machine])
	print("  %d strips folded onto %d machines" % [strips, groups.size()])
	for machine: String in groups:
		print("  %-14s %s" % [machine, ", ".join(groups [machine])])
	if bad == 0:
		print("  ok    every tuning node hangs off one machine in its own lane")
	return bad


func _check_layout() -> int:
	print("\n=== board layout ===")
	var panel:= TechPanel.new()
	add_child(panel)
	var bad:= 0
	var rects: Array [Rect2] = []
	for id: String in panel._pos:


		rects.append(panel.card_rect(id))
	var crossings:= 0
	var checked:= 0
	for seg: Dictionary in panel._wires.segments:
		var pts: PackedVector2Array = seg ["points"]
		var from_id:= str(seg ["from"])
		var to_id:= str(seg ["to"])
		for i in range(pts.size() - 1):
			checked += 1
			var run:= Rect2(pts [i], Vector2.ZERO).expand(pts [i + 1])
			for j in rects.size():
				var card: Rect2 = rects [j]
				var owner_id:= ""
				var k:= 0
				for id2: String in panel._pos:
					if k == j:
						owner_id = id2
						break
					k += 1


				if owner_id == from_id or owner_id == to_id:
					continue

				var inner:= card.grow(-3.0)
				if inner.intersects(run):
					crossings += 1
					if crossings <= 5:
						bad += _fail("the wire %s -> %s runs over %s"
							% [from_id, to_id, owner_id])
					break
	print("  %d wire runs checked against %d cards" % [checked, rects.size()])
	if crossings > 5:
		print("  ...and %d more" % (crossings - 5))
	if crossings == 0:
		print("  ok    no wire passes over a card it does not belong to")
	bad += _check_stacking(panel)
	panel.queue_free()
	return bad


func _check_stacking(panel: TechPanel) -> int:
	var vertical: Array = []
	var horizontal: Array = []
	for seg: Dictionary in panel._wires.segments:
		var pts: PackedVector2Array = seg ["points"]
		for i in range(pts.size() - 1):
			var a: Vector2 = pts [i]
			var b: Vector2 = pts [i + 1]
			if is_equal_approx(a.x, b.x) and absf(a.y - b.y) > 1.0:
				vertical.append([a.x, minf(a.y, b.y), maxf(a.y, b.y),
					str(seg ["from"]), str(seg ["to"])])
			elif is_equal_approx(a.y, b.y) and absf(a.x - b.x) > 1.0:
				horizontal.append([a.y, minf(a.x, b.x), maxf(a.x, b.x),
					str(seg ["from"]), str(seg ["to"])])
	var stacked:= 0
	stacked += _count_overlaps(vertical, "vertical")
	stacked += _count_overlaps(horizontal, "horizontal")
	if stacked == 0:
		print("  ok    %d vertical and %d horizontal runs, none drawn over another"
			% [vertical.size(), horizontal.size()])
		return 0
	return _fail("%d pair(s) of wires share a line" % stacked)


func _count_overlaps(runs: Array, kind: String) -> int:
	var hits:= 0
	for i in runs.size():
		for j in range(i + 1, runs.size()):
			var a: Array = runs [i]
			var b: Array = runs [j]
			if not is_equal_approx(float(a [0]), float(b [0])):
				continue


			if a [3] == b [3] or a [4] == b [4] or a [3] == b [4] or a [4] == b [3]:
				continue
			if float(a [1]) < float(b [2]) - 1.0 and float(b [1]) < float(a [2]) - 1.0:
				hits += 1
				if hits <= 4:
					print("  %s overlap at %.0f: %s->%s and %s->%s"
						% [kind, float(a [0]), a [3], a [4], b [3], b [4]])
	return hits


func _check_surge() -> int:
	print("\n-- purchase surge --")
	var bad:= 0
	var panel:= TechPanel.new()
	add_child(panel)


	var deep:= ""
	var deepest:= -1
	for id: String in TechTree.ids():
		var d:= _depth_of(id)
		if d > deepest:
			deepest = d
			deep = id
	print("  deepest node: %s, %d level(s) above the root" % [deep, deepest])


	var want:= { }
	var frontier: Array [String] = [deep]
	for _hop in TechPanel.SPARK_HOPS:
		var next: Array [String] = []
		for child: String in frontier:
			for need: String in TechTree.requires(child):
				if want.has(need) or need == deep:
					continue
				want [need] = true
				next.append(need)
		frontier = next

	panel._surge(deep)
	if panel._sparks.is_empty():
		panel.queue_free()
		return _fail("buying %s sent no current anywhere" % deep)

	var targets:= { }
	for spark: Dictionary in panel._sparks:
		var to:= str(spark ["to"])
		if targets.has(to):
			bad += _fail("two sparks are heading for %s -- the `seen` guard "
				% to + "is not holding")
		targets [to] = true


		var pts: PackedVector2Array = spark ["points"]
		var card:= panel.card_rect(to).grow(2.0)
		if not card.has_point(pts [pts.size() - 1]):
			bad += _fail("the spark for %s ends at %v, which is not on its card "
				% [to, pts [pts.size() - 1]] + "-- the path is the wrong way round")
	if targets.size() != want.size():
		bad += _fail("the cascade lit %d card(s), the table says %d"
			% [targets.size(), want.size()])
	for id: String in want:
		if not targets.has(id):
			bad += _fail("nothing reached %s, which %s stands on" % [id, deep])
	if bad == 0:
		print("  ok    %d spark(s), one per ancestor, every one pointed at its card"
			% targets.size())


	var expected:= targets.duplicate()
	var steps:= int((TechPanel.HOP * float(TechPanel.SPARK_HOPS + 1)) * 60.0)
	for _f in steps:
		panel._process(1.0 / 60.0)
	if not panel._sparks.is_empty():
		bad += _fail("%d spark(s) never arrived" % panel._sparks.size())
	for id: String in expected:
		if not panel._ignites.has(id):
			bad += _fail("the current reached %s but the card never lit" % id)

	if panel.is_processing():
		bad += _fail("the board is still processing with nothing left in flight")
	panel._clear_surge()
	for id: String in panel._cards:
		var card2: PanelContainer = panel._cards [id]
		if card2.modulate != Color.WHITE or card2.scale != Vector2.ONE:
			bad += _fail("%s was left mid-flash after the board closed" % id)
			break
	if bad == 0:
		print("  ok    every spark landed, lit its card, and put itself away")
	panel.queue_free()
	return bad


func _check_jump() -> int:
	print("\n-- jump height --")
	var bad:= 0
	Tech.reset()

	if not is_equal_approx(Tech.jump_velocity(Player.JUMP_VELOCITY, Player.GRAVITY),
			Player.JUMP_VELOCITY):
		bad += _fail("an unbought tree already changes the jump")

	var top:= TechTree.max_rank("jump_height")
	var apex:= 0.0
	for rank in range(1, top + 1):
		Tech.grant("jump_height", rank)
		var v:= Tech.jump_velocity(Player.JUMP_VELOCITY, Player.GRAVITY)
		apex = v * v / (2.0 * Player.GRAVITY)

		var printed:= TechTree.value_at("jump_height", rank).replace(" m", "")
		var claim:= float(printed)
		if absf(apex - claim) > 0.006:
			bad += _fail("level %d jumps %.3f m, but its card says %s"
				% [rank, apex, printed])
	print("  %d level(s), apex %.2f m -> %.2f m"
		% [top, Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * Player.GRAVITY), apex])

	if apex >= Cfg.PLATFORM_RAIL_H:
		bad += _fail("a fully bought jump reaches %.2f m, which clears the "
			% apex + "%.2f m deck railing -- the ladder is one rank too long"
			% Cfg.PLATFORM_RAIL_H)
	if bad == 0:
		print("  ok    every card matches the physics, and the top of the "
			+ "ladder stays under the railing")
	Tech.reset()
	return bad


func _check_clicks() -> int:
	print("\n-- click gesture --")
	var bad:= 0
	var panel:= TechPanel.new()
	add_child(panel)
	Tech.reset()
	GameState.add_money(500000.0 - GameState.money)

	var id:= ""
	for candidate: String in TechTree.ids():
		if Tech.can_buy(candidate) ["ok"] and Tech.rank_of(candidate) == 0:
			id = candidate
			break
	if id == "":
		panel.queue_free()
		return _fail("nothing on the board is buyable with half a million dollars")

	panel._on_card_input(_click(false), id)
	if panel._selected != id:
		bad += _fail("one click did not select %s" % id)
	if Tech.rank_of(id) != 0:
		bad += _fail("one click on %s BOUGHT it" % id)

	panel._on_card_input(_click(false), id)
	if Tech.rank_of(id) != 0:
		bad += _fail("a second separate click on %s bought it -- " % id
			+ "the board is spending money on single clicks again")

	panel._on_card_input(_click(true), id)
	if Tech.rank_of(id) != 1:
		bad += _fail("double-clicking %s did not buy it" % id)


	panel._on_card_input(_click(false), id)
	panel._on_viewport_input(_board_press(Vector2(100, 100), true))
	panel._on_viewport_input(_board_press(Vector2(140, 100), false))
	if panel._selected != id:
		bad += _fail("a drag across the board cleared the selection")
	panel._on_viewport_input(_board_press(Vector2(100, 100), true))
	panel._on_viewport_input(_board_press(Vector2(102, 101), false))
	if panel._selected != "":
		bad += _fail("a click on empty board did not clear the selection")
	if panel._ins_frame.visible:
		bad += _fail("the inspector stayed up with nothing selected")
	panel._on_card_input(_click(false), id)
	if panel._selected != id or not panel._ins_frame.visible:
		bad += _fail("clicking a card after the inspector was put away did not bring it back")


	for button: int in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		panel._on_viewport_input(_board_press(Vector2(100, 100), true, button))
		if not panel._panning or panel._pan_button != button:
			bad += _fail("button %d did not take hold of the board" % button)
		panel._on_viewport_input(_board_drag(Vector2(180, 140), Vector2(80, 40)))
		panel._on_viewport_input(_board_press(Vector2(180, 140), false, button))
		if panel._selected != id or not panel._ins_frame.visible:
			bad += _fail("a drag on button %d closed the inspector" % button)
		if panel._panning:
			bad += _fail("button %d kept panning after it came up" % button)

	panel._on_viewport_input(_board_press(Vector2(100, 100), true))
	panel._on_viewport_input(_board_drag(Vector2(180, 140), Vector2(80, 40)))
	panel._on_viewport_input(_board_press(Vector2(180, 140), false))
	if panel._selected != "" or panel._ins_frame.visible:
		bad += _fail("a left drag left the inspector sitting over the board")
	panel._on_card_input(_click(false), id)


	panel._on_viewport_input(_board_press(Vector2(100, 100), true))
	panel._on_viewport_input(_board_press(Vector2(100, 100), false))
	panel.set_open(false)
	panel.set_open(true)
	if panel._selected != "" or panel._ins_frame.visible:
		bad += _fail("the inspector came back on reopen after the player had put it away")
	panel.set_open(false)

	if bad == 0:
		print("  ok    %s: click selects, clicking again does nothing, " % id
			+ "double-click buys, empty board clears, a left drag folds the "
			+ "inspector and a right or middle one does not")
	panel.queue_free()
	return bad


func _board_press(at: Vector2, down: bool,
		button: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var ev:= InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = at
	return ev


func _board_drag(at: Vector2, by: Vector2) -> InputEventMouseMotion:
	var ev:= InputEventMouseMotion.new()
	ev.position = at
	ev.relative = by
	return ev


func _check_contract_gate() -> int:
	print("\n-- contract-gated cards --")
	var bad:= 0
	Tech.reset()
	GameState.contracts_done.clear()

	var gated:= ""
	for id: String in TechTree.ids():
		if DeliveryBook.gate_for(id) >= 0:
			gated = id
			break
	if gated == "":
		return bad + _fail("no node on the board is gated by a delivery")
	var order:= DeliveryBook.id_at(DeliveryBook.gate_for(gated))
	print("  %s stands behind the %s order" % [gated, order])

	var panel:= TechPanel.new()
	add_child(panel)
	GameState.add_money(500000.0 - GameState.money)
	panel._paint(gated)
	var parts: Dictionary = panel._parts.get(gated, { })
	var pill: Button = parts.get("gate")
	var cost: Label = parts.get("cost")


	var strip:= bool(parts.get("compact", false))
	if pill == null and not strip:
		panel.queue_free()
		return bad + _fail("%s is gated by an order and its card has no pill" % gated)
	if strip:
		if cost.text != "CONTRACT":
			bad += _fail("%s cannot be bought and its strip still prints '%s'"
				% [gated, cost.text])
	else:
		if not pill.visible:
			bad += _fail("%s cannot be bought and its card still prints a price" % gated)
		if cost.visible:
			bad += _fail("%s shows a price and a CONTRACT pill in the same slot" % gated)


	if Tech.can_buy(gated) ["ok"]:
		bad += _fail("%s could be bought with the order still open" % gated)


	if strip:
		panel._select(gated)
	else:
		pill.pressed.emit()
	if panel._selected != gated:
		bad += _fail("pressing the pill did not select %s" % gated)
	var says:= panel._ins_reason.text
	print("  it says: %s" % says)
	if says.length() < 40:
		bad += _fail("the explanation is %d characters, which is the terse one"
			% says.length())


	if not says.contains(DeliveryBook.title_quiet_of(DeliveryBook.gate_for(gated))):
		bad += _fail("the explanation does not name the order that gates it")


	GameState.sign_contract(order)
	panel._paint(gated)
	panel._select(gated)
	if strip:
		if cost.text == "CONTRACT":
			bad += _fail("%s still says CONTRACT after the order was filled" % gated)
	else:
		if pill.visible:
			bad += _fail("%s kept its pill after the order was filled" % gated)
		if not cost.visible:
			bad += _fail("%s did not get its price back when the order was filled" % gated)


	if TechPanel.contract_gate_text(gated) != "":
		bad += _fail("%s still reads as gated with its order signed off" % gated)
	if panel._ins_reason.text == says:
		bad += _fail("the inspector still blames the order that has been filled")
	panel.queue_free()
	GameState.contracts_done.clear()
	return bad


func _check_show() -> int:
	print("\n-- show in catalogue --")
	var bad:= 0
	Tech.reset()


	for build_id: String in BuildCatalog.ids():
		var node:= BuildCatalog.unlock_of(build_id)

		if node == "" or BuildCatalog.is_withheld(build_id):
			continue
		if not BuildCatalog.builds_for(node).has(build_id):
			bad += _fail("%s is unlocked by %s, but builds_for(%s) does not list it"
				% [build_id, node, node])
	if not BuildCatalog.builds_for("nonsense_node").is_empty():
		bad += _fail("builds_for answered a node that is not on the board")


	var seller:= ""
	for id: String in TechTree.ids():
		if not BuildCatalog.builds_for(id).is_empty():
			seller = id
			break
	var upgrade:= ""
	for id: String in TechTree.ids():
		if BuildCatalog.builds_for(id).is_empty():
			upgrade = id
			break
	if seller == "":
		return bad + _fail("no node on the board sells a structure")

	var panel:= TechPanel.new()
	add_child(panel)
	panel._select(seller)
	if panel._ins_show.visible:
		bad += _fail("%s offers SHOW before it has been bought" % seller)

	GameState.add_money(500000.0 - GameState.money)
	Tech.grant(seller)
	panel._select(seller)
	if not panel._ins_show.visible:
		bad += _fail("%s is bought and sells %s, but there is no SHOW button"
			% [seller, str(BuildCatalog.builds_for(seller) [0])])

	if upgrade != "":
		Tech.grant(upgrade)
		panel._select(upgrade)
		if panel._ins_show.visible:
			bad += _fail("%s sells no structure and still offers SHOW" % upgrade)
		if panel._parts.get(upgrade, { }).get("show") != null:
			bad += _fail("%s sells no structure and still built a card pill" % upgrade)


	var pill: Button = panel._parts.get(seller, { }).get("show")
	if pill == null:
		bad += _fail("%s sells a structure and its card has no SHOW pill" % seller)
	else:
		var cost: Label = panel._parts [seller] ["cost"]
		if not pill.visible:
			bad += _fail("%s is bought and its card still hides SHOW" % seller)
		if cost.visible:
			bad += _fail("%s prints a price and a SHOW pill in the same slot" % seller)
		Tech.reset()
		panel._paint(seller)
		if pill.visible:
			bad += _fail("%s offers SHOW on its card before it is bought" % seller)
		if not cost.visible:
			bad += _fail("%s lost its price when the pill went away" % seller)
		GameState.add_money(500000.0 - GameState.money)
		Tech.grant(seller)
		panel._paint(seller)
	panel.queue_free()


	var wanted:= str(BuildCatalog.builds_for(seller) [0])
	var cat:= CatalogPanel.new()
	add_child(cat)
	cat.show_entry(wanted)
	if not cat.is_open():
		bad += _fail("show_entry did not open the catalogue")
	if cat._found != wanted:
		bad += _fail("show_entry did not light %s" % wanted)
	cat.set_open(false)
	if cat._found != "":
		bad += _fail("the lit row survived the catalogue closing")
	cat.queue_free()

	if bad == 0:
		print("  ok    %s -> %s, and every catalogue entry comes back out of its node"
			% [seller, wanted])
	return bad


func _check_search() -> int:
	print("\n-- search --")
	var bad:= 0
	var panel:= TechPanel.new()
	add_child(panel)
	Tech.reset()


	var deep:= ""
	var deepest:= -1
	for id: String in TechTree.ids():
		var d:= _depth_of(id)
		if d > deepest:
			deepest = d
			deep = id
	var query:= TechTree.display_name(deep)
	panel._apply_filter(query)

	if not panel._hits.has(deep):
		bad += _fail("\"%s\" is the name on %s and searching it does not match"
			% [query, deep])
	var chain:= _ancestors_of(deep)
	for need: String in chain:
		if not panel._shown.has(need):
			bad += _fail("%s stands between the player and %s, and the filter "
				% [need, deep] + "hid it")


	var stranger:= ""
	for id: String in TechTree.ids():
		if not panel._shown.has(id):
			stranger = id
			break
	if stranger == "":
		bad += _fail("a search for one card left every card on the board")
	elif (panel._cards [stranger] as Control).visible:
		bad += _fail("%s matches nothing and is on no path, and it is still "
			% stranger + "drawn")
	for id: String in panel._shown:
		if not (panel._cards [id] as Control).visible:
			bad += _fail("%s is on the path to %s and is not drawn" % [id, deep])
	for seg: Dictionary in panel._wires.segments:
		var live: bool = panel._shown.has(str(seg ["from"])) and panel._shown.has(str(seg ["to"]))
		if bool(seg.get("hidden", false)) == live:
			bad += _fail("the wire %s -> %s is drawn against the cards that "
				% [seg ["from"], seg ["to"]] + "are on the board")
	print("  \"%s\": %d match(es), %d card(s) on the board of %d"
		% [query, panel._hits.size(), panel._shown.size(), panel._cards.size()])


	panel._apply_filter("qzxjv")
	if not panel._hits.is_empty():
		bad += _fail("a nonsense query matched %d card(s)" % panel._hits.size())
	for id: String in panel._cards:
		if (panel._cards [id] as Control).visible:
			bad += _fail("a nonsense query left %s on the board" % id)
			break

	panel._apply_filter("")
	if not panel._hits.is_empty() or not panel._shown.is_empty():
		bad += _fail("clearing the box left the filter behind")
	for id: String in panel._cards:
		if not (panel._cards [id] as Control).visible:
			bad += _fail("clearing the box did not bring %s back" % id)
			break
	for seg: Dictionary in panel._wires.segments:
		if bool(seg.get("hidden", false)):
			bad += _fail("clearing the box left the wire %s -> %s off the board"
				% [seg ["from"], seg ["to"]])
			break


	panel.set_open(true)
	panel._focus_search()
	if not panel._search.has_focus():
		bad += _fail("the search box would not take the caret")
	else:
		panel._input(_key(KEY_T))
		if not panel.is_open():
			bad += _fail("typing a t into the search box shut the board")
		panel._search.text = "belt"
		panel._apply_filter("belt")
		panel._input(_key(KEY_ESCAPE))
		if panel._search.text != "" or panel._filter != "":
			bad += _fail("escape did not empty the search box")
		if not panel.is_open():
			bad += _fail("escape shut the board with a filter still in the box")
		panel._input(_key(KEY_ESCAPE))
		if panel.is_open():
			bad += _fail("escape did not shut an unfiltered board")

	if bad == 0:
		print("  ok    a match keeps its whole chain, everything else goes, "
			+ "and clearing the box puts the tree back")
	panel.set_open(false)
	panel.queue_free()
	return bad


func _key(code: Key) -> InputEventKey:
	var ev:= InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _ancestors_of(id: String) -> Array:
	var out: Array = []
	for need: String in TechTree.requires(id):
		if not out.has(need):
			out.append(need)
		for up: String in _ancestors_of(str(need)):
			if not out.has(up):
				out.append(up)
	return out


func _click(double: bool) -> InputEventMouseButton:
	var ev:= InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = double
	return ev


func _depth_of(id: String) -> int:
	var needs:= TechTree.requires(id)
	if needs.is_empty():
		return 0
	var best:= 0
	for need: String in needs:
		best = maxi(best, _depth_of(str(need)) + 1)
	return best


func _check_table() -> int:
	print("\n-- table --")
	var bad:= 0
	var ids:= TechTree.ids()
	print("  %d nodes across %d branches" % [ids.size(), TechTree.BRANCHES.size()])
	var per_branch: Dictionary = { }
	for id: String in ids:
		var branch:= TechTree.branch_of(id)
		per_branch [branch] = int(per_branch.get(branch, 0)) + 1
		var icon_name:= TechTree.icon_of(id)
		if icon_name == "":
			bad += _fail("%s has no tech icon" % id)
		elif TechPanel.icon_for(icon_name) == null:
			bad += _fail("%s names missing icon '%s'" % [id, icon_name])


		if TechTree.is_demo(id):
			if icon_name != TechTree.DEMO_ICON:
				bad += _fail("%s is a demo node but draws '%s'" % [id, icon_name])
			if not (TechTree.spec(id).get("costs", []) as Array).is_empty():
				bad += _fail("%s is a demo node with a price on it" % id)
			continue


		if TechTree.is_bundled(id):
			if TechTree.bundled_with(id) == "":
				bad += _fail("%s is bundled with nothing" % id)
			if bool(Tech.can_buy(id) ["ok"]):
				bad += _fail("%s is bundled and can be bought" % id)
		else:
			for rank in TechTree.max_rank(id):
				if id != TechTree.ROOT and TechTree.cost_at(id, rank) <= 0.0:
					bad += _fail("%s rank %d is free" % [id, rank + 1])


		if TechTree.kind_of(id) == "ranked":
			var values: Array = TechTree.spec(id).get("values", [])
			if values.size() != TechTree.max_rank(id):
				bad += _fail("%s has %d prices but %d printed values"
					% [id, TechTree.max_rank(id), values.size()])


		for rank in range(1, TechTree.max_rank(id)):
			if TechTree.cost_at(id, rank) <= TechTree.cost_at(id, rank - 1):
				bad += _fail("%s rank %d is not dearer than rank %d"
					% [id, rank + 1, rank])
	for b: Dictionary in TechTree.BRANCHES:
		var branch:= str(b ["id"])
		print("  %-12s %d" % [branch, int(per_branch.get(branch, 0))])
		if not per_branch.has(branch):
			bad += _fail("branch '%s' has no nodes" % branch)
	for id: String in ids:
		if not TechTree.BRANCHES.any(func(b: Dictionary) -> bool:
				return str(b ["id"]) == TechTree.branch_of(id)):
			bad += _fail("%s is filed under unknown branch '%s'"
				% [id, TechTree.branch_of(id)])
	return bad


func _check_reachable() -> int:
	print("\n-- reachability --")
	var bad:= 0
	for id: String in TechTree.ids():
		for need: String in TechTree.requires(id):
			if not TechTree.has_id(need):
				bad += _fail("%s requires '%s', which is not in the table" % [id, need])
	var reached:= { TechTree.ROOT: true }
	var moved:= true
	while moved:
		moved = false
		for id: String in TechTree.ids():
			if reached.has(id):
				continue
			var ok:= true
			for need: String in TechTree.requires(id):
				if not reached.has(need):
					ok = false
					break
			if ok:
				reached [id] = true
				moved = true
	for id: String in TechTree.ids():
		if not reached.has(id):
			bad += _fail("%s can never be reached from the root" % id)
	print("  %d of %d nodes reachable" % [reached.size(), TechTree.ids().size()])
	return bad


func _check_buying() -> int:
	print("\n-- buying --")
	var bad:= 0
	Tech.reset()
	GameState.money = 0.0

	if not Tech.is_unlocked(TechTree.ROOT):
		bad += _fail("the root is not held after a reset")


	var check:= Tech.can_buy("spade")
	if check ["ok"]:
		bad += _fail("spade sold with no money")
	if Tech.buy("spade"):
		bad += _fail("buy() succeeded with no money")
	if Tech.is_unlocked("spade"):
		bad += _fail("a refused purchase still granted the rank")
	print("  broke: %s" % check ["reason"])


	GameState.money = 100000.0
	if Tech.can_buy("pitchfork") ["ok"]:
		bad += _fail("pitchfork sold before the spade")
	print("  no prerequisite: %s" % Tech.can_buy("pitchfork") ["reason"])


	var before:= GameState.money
	var cost:= Tech.next_cost("spade")
	if not Tech.buy("spade"):
		bad += _fail("spade refused with the money in hand")
	if not is_equal_approx(GameState.money, before - cost):
		bad += _fail("spade cost $%.2f but the wallet moved $%.2f"
			% [cost, before - GameState.money])
	if Tech.rank_of("spade") != 1:
		bad += _fail("spade is at rank %d after one purchase" % Tech.rank_of("spade"))

	if Tech.buy("spade"):
		bad += _fail("spade sold twice")
	print("  spade bought for $%.2f, second purchase refused" % cost)


	GameState.money = 10000000.0
	var spent:= 0.0
	for _i in TechTree.max_rank("work_boots") + 3:
		var next:= Tech.next_cost("work_boots")
		if Tech.buy("work_boots"):
			spent += next
	if Tech.rank_of("work_boots") != TechTree.max_rank("work_boots"):
		bad += _fail("work_boots stopped at rank %d of %d"
			% [Tech.rank_of("work_boots"), TechTree.max_rank("work_boots")])
	if not Tech.is_maxed("work_boots"):
		bad += _fail("work_boots is not reported as maxed")
	print("  work_boots: %d ranks for $%s"
		% [Tech.rank_of("work_boots"), Hud.money_text(spent)])
	return bad


func _check_effects() -> int:
	print("\n-- effects --")
	var bad:= 0
	Tech.reset()

	if not is_equal_approx(Tech.belt_speed(), Cfg.BELT_SPEED):
		bad += _fail("an unbought tree already changes the belt speed")
	if Tech.bucket_capacity() != Cfg.BUCKET_CAPACITY:
		bad += _fail("an unbought tree already changes the bucket")
	if Tech.max_arm_tier() != 0 or Tech.max_scanner_tier() != 0:
		bad += _fail("an unbought tree already offers a better model")

	Tech.grant("belt_speed", 5)


	if not is_equal_approx(Tech.belt_speed(), Cfg.BELT_SPEED * 3.25):
		bad += _fail("belt at 5 ranks is %.3f, expected %.3f"
			% [Tech.belt_speed(), Cfg.BELT_SPEED * 3.25])

	if not is_equal_approx(Tech.scanner_output_spacing(),
			Cfg.BELT_RIDE_SPACING / Tech.belt_speed()):
		bad += _fail("scanner output spacing did not follow the belt speed")
	print("  belt %.2f -> %.2f m/s, spacing %.4f -> %.4f s"
		% [Cfg.BELT_SPEED, Tech.belt_speed(),
			Cfg.BELT_RIDE_SPACING / Cfg.BELT_SPEED, Tech.scanner_output_spacing()])


	Tech.grant("bucket_size", 5)
	var want:= int(round(float(Cfg.BUCKET_CAPACITY) * pow(1.1, 15.0)))
	if Tech.bucket_capacity() != want:
		bad += _fail("bucket at 5 ranks holds %d, expected %d"
			% [Tech.bucket_capacity(), want])
	print("  bucket %d -> %d pieces at %.0f%% size"
		% [Cfg.BUCKET_CAPACITY, Tech.bucket_capacity(), Tech.bucket_scale() * 100.0])

	Tech.grant("barrow_size", 5)
	print("  barrow %d -> %d pieces at %.0f%% size"
		% [Cfg.BARROW_CAPACITY, Tech.barrow_capacity(), Tech.barrow_scale() * 100.0])


	Tech.grant("arm_small", 1)
	Tech.grant("arm_standard", 1)
	if Tech.max_arm_tier() != 1:
		bad += _fail("standard arm unlocked but max tier is %d" % Tech.max_arm_tier())
	Tech.grant("arm_long", 1)
	if Tech.max_arm_tier() != 2:
		bad += _fail("long arm unlocked but max tier is %d" % Tech.max_arm_tier())
	Tech.grant("arm_payload", TechTree.max_rank("arm_payload"))
	Tech.grant("arm_speed", TechTree.max_rank("arm_speed"))
	for tier in Cfg.ROBOT_ARM_TIERS.size():
		var base:= int(Cfg.ROBOT_ARM_TIERS [tier] ["capacity"])
		print("  arm tier %d: %d -> %d pieces (claw shows %d), cycle x%.3f"
			% [tier, base, Tech.arm_capacity(base),
				mini(Tech.arm_capacity(base), Tech.arm_visual_cap()), Tech.arm_cycle_scale()])
	if Tech.arm_capacity(int(Cfg.ROBOT_ARM_TIERS [0] ["capacity"])) <= int(Cfg.ROBOT_ARM_TIERS [0] ["capacity"]):
		bad += _fail("eight payload ranks did not grow the load")
	if Tech.arm_cycle_scale() >= 1.0:
		bad += _fail("eight speed ranks did not shorten the cycle")


	var full:= Tech.arm_capacity(int(Cfg.ROBOT_ARM_TIERS [2] ["capacity"]))
	if HayWad.split(full).size() != 1:
		bad += _fail("a full arm load of %d is %d wads, not one"
			% [full, HayWad.split(full).size()])


	Tech.grant("scanner_mk1", 1)
	Tech.grant("scan_batch", TechTree.max_rank("scan_batch"))
	Tech.grant("scan_speed", TechTree.max_rank("scan_speed"))
	var best: Dictionary = Cfg.SCANNER_TIERS [Cfg.SCANNER_TIERS.size() - 1]
	var scan_rate:= (float(Tech.scan_batch(int(best ["batch"])))
		/ maxf(Tech.scan_seconds(float(best ["scan_seconds"])), 0.001))


	var arm_rate:= Tech.arm_throughput(2)
	print("  max arm %.1f strands/s, max scanner %.1f strands/s (%.2f arms)"
		% [arm_rate, scan_rate, scan_rate / maxf(arm_rate, 0.001)])
	if scan_rate < arm_rate:
		bad += _fail("a full scanner (%.1f/s) cannot keep up with one full arm (%.1f/s)"
			% [scan_rate, arm_rate])
	if Tech.scanner_buffer(int(best ["buffer"])) < full:
		bad += _fail("a full scanner buffers %d, less than one arm load of %d"
			% [Tech.scanner_buffer(int(best ["buffer"])), full])


	if Tech.pellet_brick_strands() != Cfg.PELLETIZER_BRICK_STRANDS:
		bad += _fail("an unbought tree already changes the brick die")
	if not is_equal_approx(Tech.pellet_cycle_seconds(), Cfg.PELLETIZER_CYCLE_SECONDS):
		bad += _fail("an unbought tree already changes the grind")
	Tech.grant("pelletizer", 1)
	Tech.grant("pellet_batch", TechTree.max_rank("pellet_batch"))
	Tech.grant("pellet_speed", TechTree.max_rank("pellet_speed"))
	var mill_rate:= (float(Tech.pellet_brick_strands())
		/ maxf(Tech.pellet_cycle_seconds(), 0.001))
	print("  max mill %.1f strands/s (%.2f arms), %d strands a brick every %.2f s"
		% [mill_rate, mill_rate / maxf(arm_rate, 0.001),
			Tech.pellet_brick_strands(), Tech.pellet_cycle_seconds()])
	if mill_rate < arm_rate:
		bad += _fail("a full mill (%.1f/s) cannot keep up with one full arm (%.1f/s)"
			% [mill_rate, arm_rate])
	if Tech.pellet_buffer() < full:
		bad += _fail("a full mill buffers %d, less than one arm load of %d"
			% [Tech.pellet_buffer(), full])


	if Tech.pellet_cycle_seconds() < 1.0:
		bad += _fail("a full mill fires a brick every %.2f s, too fast to be worth"
			% Tech.pellet_cycle_seconds()
			+ " keeping as free bodies -- move throughput onto the batch")


	Tech.grant("shovel_size", TechTree.max_rank("shovel_size"))
	var scooped:= Tech.scoop_max(Cfg.SCOOP_MAX, Tech.spade_scale())
	print("  spade %d -> %d strands a scoop at %.0f%% size"
		% [Cfg.SCOOP_MAX, scooped, Tech.spade_scale() * 100.0])
	if scooped > Cfg.SHOVEL_MAX_SPAWN_PER_DIG:
		bad += _fail("a full spade scoops %d, past the %d cap"
			% [scooped, Cfg.SHOVEL_MAX_SPAWN_PER_DIG])

	Tech.grant("steel_saving", 3)
	if not is_equal_approx(Tech.build_cost_scale(), 0.85):
		bad += _fail("three material ranks give x%.3f, expected x0.85"
			% Tech.build_cost_scale())

	Tech.grant("drawer_space", 3)
	if Tech.scanner_bin_capacity() != Cfg.SCANNER_BIN_CAPACITY + 12:
		bad += _fail("drawer holds %d, expected %d"
			% [Tech.scanner_bin_capacity(), Cfg.SCANNER_BIN_CAPACITY + 12])


	Tech.grant("work_boots", TechTree.max_rank("work_boots"))
	if not is_equal_approx(Tech.jostle_speed_ref(), Cfg.JOSTLE_SPEED_REF * 1.2):
		bad += _fail("the sway reference did not follow the boots")
	return bad


func _check_wiring() -> int:
	print("\n-- wiring --")
	var bad:= 0
	Tech.reset()


	GameState.owned_tools = { }
	GameState.tools_changed.emit()


	for id: String in BuildCatalog.ids():
		if BuildCatalog.is_unlocked(id):
			bad += _fail("'%s' is buildable on a fresh run" % id)
	for id: String in ItemDb.ids():
		if ItemDb.price(id) > 0.0 and ItemDb.is_unlocked(id):
			bad += _fail("'%s' is on the counter on a fresh run" % id)
	if not Player.is_tool_unlocked(Player.Tool.HAND):
		bad += _fail("the player cannot use their own hands")
	for t: Player.Tool in [Player.Tool.SHOVEL, Player.Tool.PITCHFORK, Player.Tool.BROOM]:
		if Player.is_tool_unlocked(t):
			bad += _fail("tool %d is in hand before it is bought" % int(t))
	print("  fresh run: nothing buildable, nothing for sale, hands only")


	Tech.grant("belt", 1)
	if not BuildCatalog.is_unlocked("belt"):
		bad += _fail("the belt is still locked after buying its plans")
	if BuildCatalog.is_unlocked("deck"):
		bad += _fail("the platform unlocked off the belt's node")


	Tech.grant("spade", 1)
	if not ItemDb.is_unlocked("spade"):
		bad += _fail("the spade licence did not reach the counter")
	if Player.is_tool_unlocked(Player.Tool.SHOVEL):
		bad += _fail("the spade's card handed one over instead of licensing it")
	if ItemDb.is_unlocked("broom"):
		bad += _fail("the broom unlocked off the spade's node")
	Tech.grant("bucket", 1)
	if not ItemDb.is_unlocked("bucket"):
		bad += _fail("the bucket licence did not reach the counter")
	print("  each gate opens only for its own node")


	Tech.reset()
	GameState.money = 0.0
	GameState.hay_sold = 0.0
	var plain:= GameState.sell_hay(1000.0)
	Tech.grant("hay_price", 5)
	GameState.money = 0.0
	var raised:= GameState.sell_hay(1000.0)
	if not is_equal_approx(raised, plain * 1.25):
		bad += _fail("1000 hay paid $%.4f at five bargaining ranks, expected $%.4f"
			% [raised, plain * 1.25])
	print("  1000 hay: $%.2f -> $%.2f at five bargaining ranks" % [plain, raised])


	var pail:= Bucket.new()
	Tech.reset()
	var small:= pail.capacity()
	Tech.grant("bucket_size", 5)
	var large:= pail.capacity()
	if large != Tech.bucket_capacity() or large <= small:
		bad += _fail("bucket reports %d, Tech says %d" % [large, Tech.bucket_capacity()])
	print("  bucket through the item: %d -> %d" % [small, large])
	pail.free()


	var run:= BeltPath.new()
	Tech.reset()
	add_child(run)
	var before:= run.drive_speed
	Tech.grant("belt_speed", 5)
	var after:= run.drive_speed
	if not is_equal_approx(after, Tech.belt_speed()) or after <= before:
		bad += _fail("a standing belt runs at %.3f, expected %.3f" % [after, Tech.belt_speed()])
	print("  belt already laid: %.2f -> %.2f m/s" % [before, after])


	var till:= BeltPath.new()
	till.stand_belt = true
	add_child(till)
	if not is_equal_approx(till.drive_speed, Tech.stand_belt_speed()):
		bad += _fail("the stand belt runs at %.3f, expected %.3f"
			% [till.drive_speed, Tech.stand_belt_speed()])
	Tech.grant("belt_speed", 6)
	if not is_equal_approx(till.drive_speed, run.drive_speed):
		bad += _fail("the stand belt runs at %.3f, the yard belt at %.3f"
			% [till.drive_speed, run.drive_speed])
	print("  stand belt %.2f m/s vs yard belt %.2f m/s"
		% [till.drive_speed, run.drive_speed])
	run.queue_free()
	till.queue_free()
	return bad


func _check_warehouse() -> int:
	print("\n-- warehouse --")
	var bad:= 0
	if warehouse == null:
		return _fail("no warehouse was handed to the probe")

	Tech.reset()
	if not is_equal_approx(warehouse.inner, Warehouse.INNER):
		bad += _fail("a fresh run starts %.1f m from the middle, expected %.1f"
			% [warehouse.inner, Warehouse.INNER])
	var stock:= _floor_span()
	if not is_equal_approx(stock, Warehouse.INNER * 2.0):
		bad += _fail("stock floor measures %.1f m, expected %.1f"
			% [stock, Warehouse.INNER * 2.0])

	var long_want:= Warehouse.INNER * 2.0 + Warehouse.long_for(Warehouse.INNER)
	if not is_equal_approx(_floor_length, long_want):
		bad += _fail("stock floor runs %.2f m down Z, expected %.2f"
			% [_floor_length, long_want])

	var top:= TechTree.max_rank("yard_space")
	Tech.grant("yard_space", top)
	var want:= Warehouse.INNER + Tech.YARD_METRES_PER_RANK * float(top)
	if not is_equal_approx(warehouse.inner, want):
		bad += _fail("at %d levels the shed is %.1f m, expected %.1f"
			% [top, warehouse.inner, want])
	var grown:= _floor_span()
	if not is_equal_approx(grown, want * 2.0):
		bad += _fail("grown floor measures %.1f m, expected %.1f"
			% [grown, want * 2.0])
	print("  floor %.0f m -> %.0f m across (%.1fx the area) over %d levels"
			% [stock, grown, (grown * grown) / (stock * stock), top])


	Tech.reset()
	if not is_equal_approx(_floor_span(), Warehouse.INNER * 2.0):
		bad += _fail("the shed did not shrink back on a reset")
	print("  reset returns it to %.0f m across" % (Warehouse.INNER * 2.0))
	return bad


func _check_site() -> int:
	print("\n-- site gate --")
	var bad:= 0
	var was:= SaveManager.current_map
	Tech.reset()
	if Tech.off_site("yard_space"):
		bad += _fail("the warehouse will not sell its own shed extension")

	SaveManager.current_map = "brutalist_plaza"
	if not Tech.off_site("yard_space"):
		bad += _fail("the plaza still counts as a site that sells the shed")
	var check:= Tech.can_buy("yard_space")
	if bool(check ["ok"]):
		bad += _fail("Extend the Shed is still buyable on the plaza")
	if str(check ["reason"]) != TechTree.SITE_TEXT:
		bad += _fail("the refusal reads '%s', expected '%s'"
			% [check ["reason"], TechTree.SITE_TEXT])


	Tech.grant("yard_space", 1)
	if Tech.rank_of("yard_space") != 0:
		bad += _fail("a grant put a level on a card the site does not sell")


	if Tech.off_site("deck"):
		bad += _fail("the plaza stopped selling Platform Plans as well")
	print("  on the plaza: %s -- %s" % [TechTree.display_name("yard_space"),
		TechTree.SITE_TEXT])

	SaveManager.current_map = was
	Tech.reset()
	if Tech.off_site("yard_space"):
		bad += _fail("the site was not put back")
	return bad


func _floor_span() -> float:
	var widest:= 0.0
	for box in warehouse.get_children():
		for shape: CollisionShape3D in _shapes_in(box):
			var form:= shape.shape as BoxShape3D


			var centre:= shape.global_position
			if form != null and form.size.y < 1.0 and form.size.z > 1.0 and absf(centre.x) < 0.01 and absf(centre.z - warehouse.z_mid()) < 0.01:
				widest = maxf(widest, form.size.x)
				_floor_length = form.size.z
	return widest


var _floor_length:= 0.0


func _shapes_in(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is CollisionShape3D:
			out.append(child)
		out.append_array(_shapes_in(child))
	return out


func _check_save() -> int:
	print("\n-- save --")
	var bad:= 0
	Tech.reset()
	Tech.grant("belt", 1)
	Tech.grant("belt_speed", 3)
	Tech.grant("arm_small", 1)
	var written:= Tech.to_dict()

	Tech.reset()
	if Tech.rank_of("belt_speed") != 0:
		bad += _fail("reset did not clear the sheet")
	Tech.from_dict(written)
	if Tech.rank_of("belt_speed") != 3 or not Tech.is_unlocked("arm_small"):
		bad += _fail("the sheet did not survive a round trip")
	if not Tech.is_unlocked(TechTree.ROOT):
		bad += _fail("the root was lost in the round trip")
	print("  round trip kept %d nodes" % Tech.ranks.size())


	Tech.from_dict({ "ranks": { "belt_speed": 99, "a_node_that_left": 4 } })
	if Tech.rank_of("belt_speed") != TechTree.max_rank("belt_speed"):
		bad += _fail("an over-large rank was not clamped")
	if Tech.ranks.has("a_node_that_left"):
		bad += _fail("a node outside the table was kept")
	print("  clamped an over-large rank and dropped an unknown node")

	GameState.money = 0.0
	Tech.from_dict({ "ranks": { "work_boots": 10 } }, true)
	var expected_refund:= 1200.0 + 2200.0 + 4000.0 + 7000.0 + 12000.0
	if Tech.rank_of("work_boots") != TechTree.max_rank("work_boots"):
		bad += _fail("a shortened version-5 ladder was not clamped")
	if not is_equal_approx(GameState.money, expected_refund):
		bad += _fail("removed version-5 ranks refunded $%s, expected $%s" % [
			Hud.money_text(GameState.money), Hud.money_text(expected_refund)])
	print("  shortened version-5 ranks refunded $%s" % Hud.money_text(GameState.money))


	GameState.money = 0.0
	Tech.from_dict({ "ranks": { "quick_till": 4 } })
	var tally_refund:= 10.0 + 20.0 + 40.0 + 108.0
	if Tech.ranks.has("quick_till"):
		bad += _fail("a removed card was kept")
	if not is_equal_approx(GameState.money, tally_refund):
		bad += _fail("a removed card refunded $%s, expected $%s" % [
			Hud.money_text(GameState.money), Hud.money_text(tally_refund)])
	print("  removed Quick Tally ranks refunded $%s" % Hud.money_text(GameState.money))


	Tech.grant_legacy()
	var unlocks:= 0
	var ranked:= 0
	for id: String in TechTree.ids():
		if TechTree.is_demo(id):
			if Tech.is_unlocked(id):
				bad += _fail("legacy save unlocked the demo node '%s'" % id)
		elif TechTree.kind_of(id) == "ranked":
			if Tech.rank_of(id) != 0:
				ranked += 1
		elif not Tech.is_unlocked(id):
			bad += _fail("legacy save did not grant '%s'" % id)
		else:
			unlocks += 1
	if ranked > 0:
		bad += _fail("legacy save granted %d ranked levels" % ranked)
	print("  legacy save: %d unlocks granted, no ranks" % unlocks)
	return bad
