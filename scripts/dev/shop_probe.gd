class_name DevShopProbe
extends Node


const OUTSIDE:= 3.0
const SETTLE:= 40

var world: Node3D
var player: Player

var _fail:= 0


func run() -> void:
	for i in 60:
		await get_tree().process_frame
	print("\n=== shop ===")
	_model_case()
	_price_case()
	await _reach_case()
	await _locked_case()
	await _buy_case()
	await _layout_case()
	await _toy_case()
	print("=== shop: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func shoot(out_dir: String) -> void:
	world.block_save = true


	while Loading.is_active():
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout

	GameState.add_money(500.0)
	var menu:= _menu()
	if menu == null:
		push_error("[shopshot] the world built no counter")
		get_tree().quit(1)
		return
	await _stand_at(_shop().interact_point())
	menu.set_open(true)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/shop_menu.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


	var locked:= ""
	for k: String in menu._buy_buttons:
		if not ItemDb.is_unlocked(k):
			locked = k
			break
	if locked != "":
		menu._on_row_hover(locked, true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var hover_path:= "%s/shop_menu_hover.png" % out_dir
		get_viewport().get_texture().get_image().save_png(hover_path)
		print("wrote %s" % hover_path)

		menu._show_locked(locked)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var card_path:= "%s/shop_menu_locked.png" % out_dir
		get_viewport().get_texture().get_image().save_png(card_path)
		print("wrote %s" % card_path)
	get_tree().quit(0)


func _bad(line: String) -> void:
	print("  FAIL  %s" % line)
	_fail += 1


func _shop() -> HayShop:
	return world.shop as HayShop


func _menu() -> ShopMenu:
	return world.shop_menu as ShopMenu


func _model_case() -> void:
	var shop:= _shop()
	if shop == null:
		_bad("the world built no shop")
		return
	var model:= shop.get_node_or_null("Model")
	if model == null:
		_bad("the shop has no Model node")
		return


	var surfaces:= 0
	var unskinned:= 0
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)


			if src == null or src.resource_name.is_empty():
				continue
			surfaces += 1
			if mi.get_surface_override_material(i) == null:
				unskinned += 1
	print("  model: %d meshes, %d named surfaces, %d unskinned"
		% [model.find_children("*", "MeshInstance3D", true, false).size(),
			surfaces, unskinned])
	if surfaces == 0:
		_bad("nothing in the model carries a named material")
	if unskinned > 0:
		_bad("%d surfaces got no material from %s" % [unskinned, HayShop.SPEC])

	var displays:= shop.get_node_or_null("Displays")
	var shown:= displays.get_child_count() if displays != null else 0
	var want:= shop.display_ids().size()
	print("  stock: %d of %d display slots filled" % [shown, want])
	if want != 5:
		_bad("the display table lists %d items, expected the five ItemDb and the tech tree sell" % want)
	if shown != want:
		_bad("%d display models failed to load" % (want - shown))


	var stand_at:= shop.interact_point()
	var d:= stand_at.distance_to(shop.global_position)
	print("  doorstep: %.2f m out from the origin, at (%.2f, %.2f, %.2f)"
		% [d, stand_at.x, stand_at.y, stand_at.z])
	if d < 0.5:
		_bad("Marker_PlayerStand is on top of the shop origin -- is it in the model?")


func _price_case() -> void:
	var shop:= _shop()
	if shop == null:
		return
	for id: Variant in shop.display_ids():
		var key:= str(id)
		var painted:= shop.painted_price(key)
		var live:= HayShop.live_price(key)
		var mark:= "ok"
		if live < 0.0:
			mark = "NOT PRICED"
			_bad("%s is on the wall but nothing in the game prices it" % key)
		elif absf(painted - live) > 0.005:
			mark = "STALE"
			_bad("%s: the tag says $%s, the game charges $%s -- rebuild the model"
				% [key, Hud.money_text(painted), Hud.money_text(live)])
		var painted_name:= shop.painted_label(key)
		var live_name:= HayShop.live_label(key)
		if painted_name.to_upper() != live_name.to_upper():
			mark = "STALE"
			_bad("%s: the tag says '%s', the game calls it '%s'"
				% [key, painted_name, live_name])
		print("  tag: %-12s %-12s painted $%-8s live $%-8s %s"
			% [key, painted_name, Hud.money_text(painted), Hud.money_text(live), mark])


func _reach_case() -> void:
	var shop:= _shop()
	var menu:= _menu()
	if shop == null or menu == null:
		return

	await _stand_at(shop.interact_point())
	var near:= menu.is_at_counter()
	var opened:= menu.try_open()
	print("  at the shop counter: at it %s, E opened it %s" % [near, opened])
	if not near or not opened:
		_bad("E does not open the counter while standing at the shop's own doorstep")
	menu.set_open(false)


	await _stand_at(shop.interact_point(),
		shop.interact_point() + (shop.interact_point() - shop.focus_point()))
	var behind:= menu.is_at_counter()
	var opened_behind:= menu.try_open()
	print("  at the counter looking away: at it %s, E opened it %s"
		% [behind, opened_behind])
	if behind or opened_behind:
		_bad("the counter opens with the shop behind the player's head")
	menu.set_open(false)


	var stand:= world.stand as HaySellingStand
	if stand != null:
		await _stand_at(stand.global_position + Vector3(0, 0, 1.2))
		var near_stand:= menu.is_at_counter()
		var opened_stand:= menu.try_open()
		print("  at the selling stand: near %s, E opened it %s"
			% [near_stand, opened_stand])
		if near_stand or opened_stand:
			_bad("the counter still opens at the selling stand")
		menu.set_open(false)


	await _stand_at(shop.interact_point()
		+ Vector3(HayShop.OPEN_DISTANCE + OUTSIDE, 0, 0))
	var far_open:= menu.try_open()
	print("  %.1f m away: E opened it %s" % [HayShop.OPEN_DISTANCE + OUTSIDE, far_open])
	if far_open:
		_bad("the counter opens from outside HayShop.OPEN_DISTANCE")
	menu.set_open(false)


func _locked_case() -> void:
	var shop:= _shop()
	var menu:= _menu()
	if shop == null or menu == null:
		return
	await _stand_at(shop.interact_point())
	menu.set_open(true)
	await get_tree().process_frame

	var id:= ""
	for k: String in menu._buy_buttons:
		if not ItemDb.is_unlocked(k):
			id = k
			break
	if id == "":
		_bad("every item on the counter is already licensed: nothing to lock")
		menu.set_open(false)
		return

	var card: PanelContainer = menu._rows.get(id)
	var btn: Button = menu._buy_buttons [id]
	if card == null:
		_bad("the locked row %s is not on a card that can be lit" % id)
		menu.set_open(false)
		return

	var dark:= card.get_theme_stylebox("panel")
	menu._on_row_hover(id, true)
	var lit:= card.get_theme_stylebox("panel")
	menu._on_row_hover(id, false)
	var unlit:= card.get_theme_stylebox("panel")
	print("  locked row %s: lights on hover %s, goes back %s, button says '%s' pressable %s"
		% [id, lit != dark, unlit == dark, btn.text, not btn.disabled])
	if lit == dark or lit != menu._row_lit:
		_bad("hovering the locked row %s did not light it" % id)
	if unlit != dark:
		_bad("the locked row %s stayed lit after the pointer left" % id)
	if btn.disabled:
		_bad("the LOCKED button on %s is greyed out: the click cannot be answered" % id)
	if btn.text != "LOCKED":
		_bad("the button on the locked row %s says '%s'" % [id, btn.text])

	btn.pressed.emit()
	await get_tree().process_frame
	var node:= ItemDb.unlock_of(id)
	var key:= InputSetup.hint("tech_tree")
	var body:= menu._locked_body.text
	print("  clicked it: card up %s, shop still open %s, offers the tree %s"
		% [menu._locked_card.visible, menu.is_open(), menu._locked_tree.visible])
	if not menu._locked_card.visible:
		_bad("clicking LOCKED on %s put no card up" % id)
	if not menu.is_open():
		_bad("clicking LOCKED on %s closed the counter" % id)
	if not body.contains(key):
		_bad("the card does not name the tech tree key '%s': '%s'" % [key, body])
	if TechTree.has_id(node) and not body.contains(TechTree.display_name(node)):
		_bad("the card does not name %s, which is what sells %s" % [node, id])


	var ev:= InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	menu._input(ev)
	await get_tree().process_frame
	print("  E over the card: card up %s, shop still open %s"
		% [menu._locked_card.visible, menu.is_open()])
	if menu._locked_card.visible:
		_bad("E over the locked card left it up")
	if not menu.is_open():
		_bad("E over the locked card closed the counter behind it")


	var click:= InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu._on_row_input(click, id)
	await get_tree().process_frame
	if not menu._locked_card.visible:
		_bad("a click on the body of the locked row %s did nothing" % id)

	if menu._locked_tree.visible:
		menu._locked_tree.pressed.emit()
		await get_tree().process_frame
		var tree:= player.tech_panel
		print("  OPEN TECH TREE: shop closed %s, board open %s"
			% [not menu.is_open(), tree != null and tree.is_open()])
		if menu.is_open():
			_bad("the tech tree button left the counter open over the board")
		if tree == null or not tree.is_open():
			_bad("the tech tree button did not open the board")
		if tree != null:
			tree.set_open(false)
	menu.set_open(false)


func _buy_case() -> void:
	var shop:= _shop()
	var menu:= _menu()
	var props:= world.props as PropManager
	if shop == null or menu == null or props == null:
		return


	Tech.grant("bucket")
	GameState.add_money(1000.0)
	await _stand_at(shop.interact_point())
	if not menu.try_open():
		_bad("could not open the counter to buy across it")
		return

	var before_money:= GameState.money
	var before_count:= props.count_of("bucket")
	menu._on_buy("bucket")
	await get_tree().process_frame
	var spent:= before_money - GameState.money
	var got:= props.count_of("bucket") - before_count
	print("  bought a bucket: $%s spent, %d item(s) added" % [Hud.money_text(spent), got])
	if got != 1:
		_bad("buying a bucket produced %d items" % got)
	if absf(spent - ItemDb.price("bucket")) > 0.005:
		_bad("a bucket costing $%s took $%s"
			% [Hud.money_text(ItemDb.price("bucket")), Hud.money_text(spent)])
	menu.set_open(false)


func _toy_case() -> void:
	var shop:= _shop()
	var menu:= _menu()
	if shop == null or menu == null:
		return
	menu.set_open(false)
	Tech.grant("sand_shovel", 1)
	GameState.grant_tool("sand_shovel")
	await _stand_at(shop.interact_point())
	player.select_hotbar_slot(4)
	for i in 10:
		await get_tree().physics_frame
	if not player.carry.toy_in_hand():
		_bad("could not get the toy spade into the player's hands to test with")
		return
	var ev:= InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	player._unhandled_input(ev)
	await get_tree().process_frame
	print("  E at the counter with the toy spade out: opened %s, still holding it %s"
		% [menu.is_open(), player.carry.toy_in_hand()])
	if not menu.is_open():
		_bad("the toy spade ate the press: the counter did not open")
	if not player.carry.toy_in_hand():
		_bad("E at the counter put the toy spade down")
	menu.set_open(false)


func _layout_case() -> void:
	var menu:= _menu()
	if menu == null:
		return
	menu.set_open(true)


	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Control = null
	for n in menu.find_children("*", "PanelContainer", true, false):
		panel = n as Control
		break
	if panel == null:
		_bad("the counter has no panel to measure")
		menu.set_open(false)
		return


	var frame: Control = panel.get_parent() as Control
	var card:= panel.get_global_rect()
	var off:= card.get_center() - frame.get_global_rect().get_center()


	var design_h:= float(ProjectSettings.get_setting(
		"display/window/size/viewport_height", 900))
	print("  layout: card %.0f x %.0f, off centre by (%.0f, %.0f), %.0f to spare"
		% [card.size.x, card.size.y, off.x, off.y, design_h - card.size.y])
	if absf(off.x) > 1.0 or absf(off.y) > 1.0:
		_bad("the counter sits (%.0f, %.0f) off the middle of the screen"
			% [off.x, off.y])
	if card.size.y > design_h:
		_bad("the counter is %.0f tall and the screen is %.0f: rows fall off it"
			% [card.size.y, design_h])
	menu.set_open(false)


func _stand_at(pos: Vector3, look_at: Vector3 = Vector3.INF) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(pos.x, maxf(pos.y, 0.1) + 0.9, pos.z)
	var target:= look_at
	if target == Vector3.INF:
		var shop:= _shop()
		target = shop.focus_point() if shop != null else pos
	_aim_at(target)
	for i in SETTLE:
		await get_tree().physics_frame


func _aim_at(target: Vector3) -> void:
	var dir:= (target - player.eye_position()).normalized()
	if dir.length_squared() < 0.0001:
		return
	player.rotation.y = atan2(- dir.x, - dir.z)
	player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))
