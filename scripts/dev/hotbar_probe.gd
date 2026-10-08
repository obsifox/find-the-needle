class_name DevHotbarProbe
extends Node


var world: Node3D
var player: Player
var catalog: CatalogPanel

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:


	world.block_save = true
	print("--- hotbar probe ---")
	var tools:= Player.TOOL_SLOTS.size()
	var favs:= GameState.hotbar_size()


	GameState.hotbar = GameState.default_hotbar()
	GameState.hotbar_changed.emit()


	Tech.grant_legacy()


	for id: String in GameState.TOOL_IDS:
		GameState.grant_tool(id)

	_ok(GameState.hotbar_size() == Player.HOTBAR_KEYS - 1,
		"the bar stores a pin for every key but the hands (%d)" % GameState.hotbar_size())


	var room:= GameState.favourite_room()
	_ok(room == Player.HOTBAR_KEYS - Player.tool_boxes_max(),
		"full pockets leave %d keys for buildings" % room)
	_ok(GameState.carried_tool_count() == GameState.CARRIED_TOOL_MAX,
		"and the loop above filled the player's pockets rather than overflowing them")
	_ok(not GameState.has_tool("yard_vac"),
		"the sixth tool was refused, because there was nowhere to put it")


	_ok(not GameState.has_tool("lighter"),
		"and so was the seventh, the lighter")
	_ok(Player.visible_slots().size() <= Player.HOTBAR_KEYS,
		"and no more boxes are drawn than there are number keys")


	_ok(Array(GameState.hotbar) == Array(GameState.default_hotbar()),
		"fresh run gets the default favourites, cut to the %d slots there are" % favs)
	var sold:= BuildCatalog.ids().filter(func(id: String) -> bool: return not BuildCatalog.is_withheld(id))
	_ok(BuildCatalog.ordered_ids().size() == sold.size(),
		"every catalogue entry this build sells is filed under a real category")
	var every_build_has_icon:= true
	for id: String in BuildCatalog.ids():
		if CatalogPanel._icon_for(id) == null:
			every_build_has_icon = false
			break
	_ok(every_build_has_icon, "every catalogue entry has a B-menu icon")

	player.select_hotbar_slot(1)
	_ok(player.current_tool == Player.Tool.SHOVEL and player.build_id == "",
		"key 2 equips the spade and clears the build id")

	player.select_hotbar_slot(tools)
	_ok(player.current_tool == Player.Tool.BUILD and player.build_id == "belt",
		"key 5 equips the belt")
	_ok(player.build._mode == BuildTool.Mode.CONVEYOR, "build tool is in belt mode")


	var parked_id:= GameState.hotbar_slot(room)
	_ok(parked_id != "" and GameState.hotbar_slot_parked(room)
		and not Player.slot_is_shown(tools + room),
		"with full pockets the fifth default (%s) is parked off the bar" % parked_id)


	var last_id:= GameState.hotbar_slot(room - 1)
	player.select_hotbar_slot(tools + room - 1)
	_ok(player.build_id == last_id,
		"the last favourite key equips what is pinned there (%s)" % last_id)


	GameState.set_hotbar_slot(0, last_id)
	_ok(GameState.hotbar_slot(0) == last_id and GameState.hotbar_slot(room - 1) == "",
		"repinning a structure vacates its old slot")
	_ok(not GameState.hotbar_slot_parked(room),
		"...and the parked pin behind it moves up into the gap")


	GameState.hotbar = GameState.default_hotbar()
	GameState.hotbar_changed.emit()
	_ok(GameState.hotbar_index_of("cabinet") < 0 and GameState.hotbar.has(""),
		"the bar is full, the cabinet is off it, and the store still has blanks")
	_ok(GameState.toggle_hotbar("cabinet") == -1 and GameState.hotbar_index_of("cabinet") < 0,
		"a full bar will not take another pin")


	var freed:= GameState.hotbar_index_of("arm")
	_ok(GameState.toggle_hotbar("arm") == -1 and GameState.hotbar_index_of("arm") < 0,
		"right-clicking a pinned structure unpins it")
	_ok(not GameState.hotbar_slot_parked(GameState.hotbar_index_of(parked_id)),
		"...and the parked %s takes the box it left" % parked_id)
	_ok(GameState.toggle_hotbar("cabinet") == -1,
		"so the bar is still full")

	GameState.toggle_hotbar("deck")
	_ok(GameState.toggle_hotbar("cabinet") == freed, "the freed slot is the one that fills")


	GameState.set_hotbar_slot(2, "")
	player.select_hotbar_slot(tools + 2)
	_ok(catalog.is_open() and catalog._pending_slot == 2,
		"an empty favourite opens the catalogue for that slot")
	catalog._pick("rail")
	_ok(not catalog.is_open(), "picking a card closes the panel")
	_ok(GameState.hotbar_slot(2) == "rail" and player.build_id == "rail",
		"the pick both fills the slot and goes into the player's hands")


	var before:= Array(GameState.hotbar)
	var saved:= GameState.to_dict()
	GameState.hotbar = PackedStringArray([])
	GameState.from_dict(saved)
	_ok(Array(GameState.hotbar) == before, "the bar survives a save and load")


	var stale:= GameState.to_dict()
	stale ["hotbar"] = PackedStringArray(["belt", "auger", "deck", "", "", "", "", ""])
	GameState.from_dict(stale)
	_ok(GameState.hotbar_slot(1) == "", "an unknown id loads as an empty slot")
	_ok(GameState.hotbar.size() == favs,
		"a short or long saved bar is resized to %d" % favs)

	_keys_follow_the_boxes()
	_catalogue_agrees_with_the_bar()
	_search_filters_and_resets()

	print("--- %s ---" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _keys_follow_the_boxes() -> void:
	Tech.reset()
	for id: String in GameState.TOOL_IDS:
		GameState.take_tool(id)
	GameState.hotbar = PackedStringArray(["", "", "", "", ""])
	GameState.hotbar_changed.emit()
	GameState.grant_tool("sand_shovel")


	_ok(Array(Player.visible_slots()) == [0, 4],
		"an unowned, unlicensed tool is off the bar entirely")
	player.select_hotbar_key(1)
	_ok(player.current_tool == Player.Tool.TOY,
		"the second key equips the second box, not the second slot")


	player.drop_active_tool()
	_ok(not GameState.has_tool("sand_shovel"),
		"putting a tool down gives up owning it")
	_ok(Array(Player.visible_slots()) == [0],
		"and the bar is back to one box")
	player.select_hotbar_key(1)
	_ok(player.current_tool != Player.Tool.TOY,
		"a dropped tool cannot be conjured back out of its old key")

	_the_toy_spade_lets_go_of_the_bar()


func _the_toy_spade_lets_go_of_the_bar() -> void:
	Tech.reset()
	Tech.grant("belt", 1)
	GameState.grant_tool("sand_shovel")


	var floor_toys:= _saved_toys()
	player.equip_tool_id("sand_shovel")
	_ok(player.current_tool == Player.Tool.TOY, "the toy spade is out")
	_ok(player.carry.is_carrying(), "...and is genuinely in the player's hands")


	var extra:= _saved_toys() - floor_toys
	_ok(extra == 0, "the toy spade in the hands is not saved as a prop (%d extra)" % extra)

	player.equip_build("belt")
	_ok(player.current_tool == Player.Tool.BUILD,
		"a structure key still switches while the toy spade is out")
	_ok(not player.carry.is_carrying(),
		"...by putting the spade down rather than holding both")


	_ok(player.build != null and player.build.is_active(),
		"...so the hologram is up, which is the whole point of pressing the key")

	_the_unlocked_tab()
	_the_two_views()
	_a_locked_card_points_at_the_tree()


func _saved_toys() -> int:
	var n:= 0
	for row: Dictionary in (world.get("props") as PropManager).to_array():
		if row.get("id", "") == "sand_shovel":
			n += 1
	return n


func _search_filters_and_resets() -> void:
	catalog._select_category("")
	catalog.set_open(true)
	var all: int = catalog._shown_count()
	var key:= InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_B
	key.unicode = "b".unicode_at(0)
	key.physical_keycode = KEY_B
	_ok(catalog._is_typing(key), "a letter counts as typing")
	catalog._input(key)
	_ok(not catalog.is_open(), "B closes the catalogue while the search is not in use")
	catalog.set_open(true)
	catalog._search.grab_focus()
	catalog._input(key)
	_ok(catalog.is_open(), "B does not close it once the search box has the keyboard")
	catalog._search.release_focus()
	catalog._search.text = "conveyor belt"
	catalog._on_search_changed(catalog._search.text)
	var some: int = catalog._shown_count()
	_ok(some > 0 and some < all, "a search narrows the list (%d of %d)" % [some, all])
	_ok(catalog._cards ["belt"].visible, "searching for the belt shows the belt")
	catalog._search.text = "zzzz"
	catalog._on_search_changed(catalog._search.text)
	_ok(catalog._shown_count() == 0, "a search matching nothing shows nothing")
	catalog.set_open(false)
	catalog.set_open(true)
	_ok(catalog._search.text == "" and catalog._shown_count() == all
		and catalog._cards ["belt"].visible, "reopening starts with an empty search")
	catalog.set_open(false)


func _the_two_views() -> void:
	var was: bool = catalog._grid_view
	var ids:= BuildCatalog.ordered_ids()
	var missing:= 0
	for id: String in ids:
		if not catalog._tiles.has(id):
			missing += 1
	_ok(missing == 0, "every structure has a tile as well as a row")

	Tech.reset()
	Tech.grant("belt", 1)
	catalog._select_category(CatalogPanel.TAB_UNLOCKED)
	var rows:= _cards_on_screen()
	var tiles:= _tiles_on_screen()
	_ok(rows == tiles, "a tab hides the same structures in both views (%d)"
		% rows.size())


	var locked:= ""
	for id: String in ids:
		if not BuildCatalog.is_unlocked(id):
			locked = id
			break
	catalog._select_category("")
	var lock_on_tile: TextureRect = catalog._tiles [locked].get_node_or_null("Body/Art/Lock")
	var lock_on_belt: TextureRect = catalog._tiles ["belt"].get_node_or_null("Body/Art/Lock")
	_ok(lock_on_tile != null and lock_on_tile.visible,
		"a locked tile wears the padlock (%s)" % locked)
	_ok(lock_on_belt != null and not lock_on_belt.visible,
		"...and an unlocked one does not")


	catalog._grid_view = true
	catalog._apply_view()
	catalog.set_open(true)
	catalog._pick("belt")
	_ok(not catalog.is_open() and player.build_id == "belt",
		"a tile equips the same as a row does")
	var pinned:= GameState.hotbar_index_of("belt")
	var pin_tag: Label = catalog._tiles ["belt"].get_node_or_null("Body/Art/Pin")
	_ok(pin_tag != null and pin_tag.visible == (pinned >= 0),
		"a tile shows its KEY tag exactly when it is on the bar")
	catalog._grid_view = was
	catalog._apply_view()


func _tiles_on_screen() -> Array:
	var out:= []
	for id: String in catalog._tiles:
		if (catalog._tiles [id] as CanvasItem).visible:
			out.append(id)
	out.sort()
	return out


func _a_locked_card_points_at_the_tree() -> void:
	var tree:= player.tech_panel
	if tree == null:
		_ok(false, "the catalogue has no tech tree to point a locked card at")
		return
	Tech.reset()
	var locked:= ""
	for id: String in BuildCatalog.ids():
		if not BuildCatalog.is_unlocked(id) and TechTree.has_id(BuildCatalog.unlock_of(id)):
			locked = id
			break
	if locked == "":
		_ok(false, "a bare tree left nothing in the catalogue locked")
		return

	var held:= player.build_id
	catalog.set_open(true)
	catalog._pick(locked)
	_ok(not catalog.is_open(), "clicking a locked card closes the catalogue")
	_ok(tree.is_open(), "...and opens the tech tree")
	_ok(tree._selected == BuildCatalog.unlock_of(locked),
		"...on %s, the node that sells %s" % [BuildCatalog.unlock_of(locked), locked])
	_ok(player.build_id == held, "...without equipping the thing it refused")
	tree.set_open(false)


func _the_unlocked_tab() -> void:
	Tech.reset()
	Tech.grant("belt", 1)
	catalog._select_category(CatalogPanel.TAB_UNLOCKED)
	var listed:= _cards_on_screen()
	var want:= []
	for id: String in BuildCatalog.ids():
		if BuildCatalog.is_unlocked(id):
			want.append(id)
	want.sort()
	_ok(listed == want, "the Unlocked tab lists exactly what is unlocked (%d)"
		% listed.size())
	_ok(listed.size() < BuildCatalog.ids().size(),
		"...which mid-run is fewer than everything")


	Tech.grant("drone", 1)
	catalog.set_open(false)
	catalog.set_open(true)
	_ok(_cards_on_screen().has("drone"),
		"a structure bought while the panel was shut shows up on reopening")
	catalog.set_open(false)


	catalog._select_category("")
	_ok(_cards_on_screen().size() == BuildCatalog.ordered_ids().size(),
		"and Everything still lists the locked ones too")
	_the_hotkeyed_tab()
	_sorting_by_last_used()


func _sorting_by_last_used() -> void:
	var was: bool = catalog._sort_recent
	Tech.reset()
	Tech.grant("belt", 1)
	Tech.grant("splitter", 1)
	GameState.recent_builds = PackedStringArray()
	GameState.fresh_builds = PackedStringArray()
	var gifts_were:= GameState.gifts.duplicate()
	GameState.gifts.clear()

	catalog._sort_recent = false
	catalog._apply_order()
	var owned_first:= []
	for id: String in BuildCatalog.ordered_ids():
		if BuildCatalog.is_unlocked(id):
			owned_first.append(id)
	for id: String in BuildCatalog.ordered_ids():
		if not owned_first.has(id):
			owned_first.append(id)
	_ok(catalog._ordered_ids() == owned_first,
		"switched off, the list is the catalogue's own order, owned before locked")


	player.equip_build("belt")
	catalog.set_open(true)
	catalog._pick("splitter")
	_ok(GameState.recent_builds.is_empty(),
		"equipping and picking a card record nothing")

	GameState.note_build_used("splitter")
	GameState.note_build_used("belt")
	catalog._sort_recent = true
	catalog._apply_order()
	var order:= catalog._ordered_ids()
	_ok(order [0] == "belt" and order [1] == "splitter",
		"the last two built lead the list, newest first")
	_ok(order.size() == BuildCatalog.ordered_ids().size(),
		"...and everything else is still on it exactly once (%d)" % order.size())


	GameState.note_build_used("splitter")
	_ok(GameState.recent_builds.count("splitter") == 1,
		"building the same thing twice is one entry, not two")
	_ok(catalog._ordered_ids() [0] == "splitter", "...moved back to the front")


	catalog._apply_order()
	var first:= catalog._list.get_child(0) as Control
	_ok(first != null and first.name == "splitter",
		"the first row in the list is the one the order names")


	var saved:= GameState.to_dict()
	saved ["recent_builds"] = PackedStringArray(["auger", "belt", "belt"])
	GameState.from_dict(saved)
	_ok(Array(GameState.recent_builds) == ["belt"],
		"an unknown id and a duplicate are both dropped on load")


	Tech.grant("cabinet", 1)
	GameState.give_gift("cabinet")
	var order_gift:= catalog._ordered_ids()
	_ok(order_gift [0] == "cabinet" and order_gift [1] == "belt",
		"a waiting gift leads the list, above the last thing built")
	GameState.take_gift("cabinet")
	_ok(catalog._ordered_ids() [0] == "belt", "...and drops back once it is placed")


	GameState.note_builds_bought("splitter")
	_ok(catalog._ordered_ids() [0] == "splitter",
		"a structure just bought leads the list")
	GameState.note_build_used("belt")
	_ok(catalog._ordered_ids() [0] == "splitter",
		"...and stays there while other things are built")

	GameState.note_build_used("splitter")
	_ok(Array(GameState.fresh_builds) == ["u_splitter"],
		"placing it clears it and leaves the other card the node sold (%s)"
		% [GameState.fresh_builds])
	GameState.fresh_builds = PackedStringArray()
	var locked_at:= -1
	var order_now:= catalog._ordered_ids()
	for i in order_now.size():
		if not BuildCatalog.is_unlocked(order_now [i]):
			locked_at = i
			break
	var tail_locked:= true
	if locked_at >= 0:
		for i in range(locked_at, order_now.size()):
			if BuildCatalog.is_unlocked(order_now [i]):
				tail_locked = false
	_ok(tail_locked, "every locked card sits below every owned one")


	GameState.note_builds_bought("cabinet")
	catalog.set_open(false)
	catalog._announced.clear()
	catalog.set_open(true)
	_ok(catalog._found == "cabinet", "opening lights the new card")
	catalog.set_open(false)
	catalog.set_open(true)
	_ok(catalog._found == "", "...once, not at every open")
	catalog.set_open(false)
	GameState.fresh_builds = PackedStringArray()
	GameState.gifts = gifts_were

	catalog._sort_recent = was
	catalog._apply_order()


func _the_hotkeyed_tab() -> void:
	Tech.reset()
	Tech.grant("belt", 1)
	Tech.grant("splitter", 1)
	GameState.hotbar = GameState.default_hotbar()
	GameState.hotbar_changed.emit()
	catalog._select_category(CatalogPanel.TAB_HOTKEYED)
	var listed:= _cards_on_screen()
	var want:= []
	for id: String in BuildCatalog.ids():
		if GameState.hotbar_index_of(id) >= 0 and BuildCatalog.is_unlocked(id):
			want.append(id)
	want.sort()
	_ok(listed == want, "the Hotkeyed tab lists exactly what the bar draws (%d)"
		% listed.size())
	var locked_fav:= ""
	for i in GameState.hotbar_size():
		var id:= GameState.hotbar_slot(i)
		if id != "" and not BuildCatalog.is_unlocked(id):
			locked_fav = id
			break
	if locked_fav != "":
		_ok(not listed.has(locked_fav),
			"...and not a pinned structure the tree has not sold (%s)" % locked_fav)


	_ok(not listed.has("splitter"), "the splitter is not on the bar to start with")
	GameState.toggle_hotbar("splitter")
	_ok(_cards_on_screen().has("splitter"),
		"pinning while the tab is up adds the row without reselecting the tab")
	GameState.toggle_hotbar("splitter")
	_ok(not _cards_on_screen().has("splitter"), "...and unpinning takes it away again")


	GameState.set_hotbar_slot(0, "")
	catalog.set_open(false)
	catalog.set_open(true)
	_ok(not _cards_on_screen().has("belt"),
		"a slot emptied while the panel was shut is gone on reopening")
	catalog.set_open(false)
	catalog._select_category("")


func _cards_on_screen() -> Array:
	var out:= []
	for id: String in catalog._cards:
		if (catalog._cards [id] as CanvasItem).visible:
			out.append(id)
	out.sort()
	return out


func _catalogue_agrees_with_the_bar() -> void:
	Tech.reset()
	for id: String in GameState.TOOL_IDS:
		GameState.take_tool(id)
	Tech.grant(Player.tool_unlock(Player.Tool.SHOVEL), 1)
	Tech.grant(Player.tool_unlock(Player.Tool.PITCHFORK), 1)


	GameState.grant_tool(Player.tool_unlock(Player.Tool.SHOVEL))
	GameState.grant_tool(Player.tool_unlock(Player.Tool.PITCHFORK))
	Tech.grant("belt", 1)
	GameState.hotbar = GameState.default_hotbar()
	GameState.hotbar_changed.emit()

	var tools:= Player.TOOL_SLOTS.size()
	_ok(Array(Player.visible_slots()) == [0, 1, 2, tools],
		"hand, spade, pitchfork and the belt are the four boxes on the bar")


	_ok(catalog._slot_key(0) == Player.key_label(3),
		"the catalogue calls the conveyor key 4, the same as the box under it")
	_ok(Player.favourite_for_key(3) == 0,
		"and pressing that key binds the conveyor's slot, not nothing")
	for p in 3:
		_ok(Player.favourite_for_key(p) == -1,
			"key %d is a held tool and the catalogue cannot rebind it" % (p + 1))


	var free:= GameState.first_free_hotbar_slot()
	var first_blank:= GameState.hotbar.find("")
	_ok(free == first_blank, "a pin goes in the first blank slot (got %d)" % free)
	var cabinet_node:= BuildCatalog.unlock_of("cabinet")
	if cabinet_node != "":
		Tech.grant(cabinet_node, 1)
	var got:= GameState.toggle_hotbar("cabinet")
	_ok(got == first_blank, "pinning with the defaults still in place lands in that slot")
	_ok(GameState.hotbar_slot(0) == "belt",
		"and does not evict the one default the player can actually use")
	_ok(catalog._slot_key(got) == Player.key_label(4),
		"the newly pinned card reads key 5, straight after the belt")
	var saved_bar:= GameState.hotbar.duplicate()
	for i in GameState.hotbar_size():
		if GameState.hotbar_slot(i) == "":
			GameState.hotbar [i] = BuildCatalog.DEFAULT_FAVOURITES [1]


	var yielded:= GameState.first_free_hotbar_slot()
	_ok(yielded >= 0 and not BuildCatalog.is_unlocked(GameState.hotbar_slot(yielded)),
		"with no blanks left, a slot holding a locked building counts as free (got %d)" % yielded)
	GameState.hotbar = saved_bar
	GameState.hotbar_changed.emit()


	var shown:= Player.visible_slots()
	var agree:= true
	for p in shown.size():
		var slot: int = shown [p]
		if slot < tools:
			continue
		var fav:= slot - tools
		if catalog._slot_key(fav) != Player.key_label(p) or Player.favourite_for_key(p) != fav:
			agree = false
	_ok(agree, "every favourite on the bar labels and binds to the same key")

	_tools_make_room_for_buildings()


func _tools_make_room_for_buildings() -> void:
	Tech.grant_legacy()
	for id: String in GameState.TOOL_IDS:
		GameState.take_tool(id)
	var spade:= Player.tool_unlock(Player.Tool.SHOVEL)
	var fork:= Player.tool_unlock(Player.Tool.PITCHFORK)
	GameState.grant_tool(spade)
	var blank:= PackedStringArray()
	blank.resize(GameState.hotbar_size())
	GameState.hotbar = blank
	GameState.hotbar_changed.emit()

	var ids: Array [String] = []
	for id: String in BuildCatalog.ids():
		if BuildCatalog.is_unlocked(id):
			ids.append(id)
		if ids.size() == GameState.hotbar_size():
			break
	if ids.size() < GameState.hotbar_size():
		_ok(false, "the legacy tree unlocked only %d structures" % ids.size())
		return

	_ok(GameState.favourite_room() == Player.HOTBAR_KEYS - 2,
		"hands and a spade leave eight keys for buildings")
	var landed:= 0
	for i in 8:
		if GameState.toggle_hotbar(ids [i]) >= 0:
			landed += 1
	_ok(landed == 8, "eight buildings pin (got %d)" % landed)
	_ok(Player.visible_slots().size() == Player.HOTBAR_KEYS,
		"and the bar draws all ten boxes")

	catalog._toggle_pin(ids [8])
	_ok(GameState.hotbar_index_of(ids [8]) < 0, "the ninth does not fit")
	_ok(not catalog._footer.text.contains(tr("%s unpinned") % BuildCatalog.display_name(ids [8])),
		"...and the catalogue does not claim it was unpinned")

	_ok(catalog._footer.text == tr("Every slot is taken. Put a tool down to make room, or hover a card and press the key of the box you want it to replace"),
		"...it says the bar is full and a tool is using the room (%s)" % catalog._footer.text)


	var eighth:= ids [7]
	var at:= GameState.hotbar_index_of(eighth)
	GameState.grant_tool(fork)
	_ok(GameState.hotbar_index_of(eighth) == at and GameState.hotbar_slot_parked(at),
		"picking a tool up parks the last building and keeps its pin")
	_ok(Player.visible_slots().size() == Player.HOTBAR_KEYS,
		"...so the bar still draws ten boxes, not eleven")
	catalog._paint(eighth)
	var tag:= (catalog._cards [eighth] as Control).get_node_or_null("Row/Pin") as Label
	_ok(tag != null and tag.text == tr("BAR FULL"),
		"...and its catalogue card says BAR FULL rather than a key")

	GameState.take_tool(fork)
	_ok(not GameState.hotbar_slot_parked(at) and Player.slot_is_shown(Player.TOOL_SLOTS.size() + at),
		"putting the tool down brings the building straight back")


	GameState.take_tool(spade)
	_ok(GameState.toggle_hotbar(ids [8]) >= 0, "with no tools, a ninth building pins")
	player.select_hotbar_key(Player.HOTBAR_KEYS - 1)
	_ok(player.current_tool == Player.Tool.BUILD and player.build_id == ids [8],
		"and the last key on the bar equips it")


	for id: String in GameState.TOOL_IDS:
		GameState.grant_tool(id)
	var parked:= 0
	for i in GameState.hotbar_size():
		if GameState.hotbar_slot_parked(i):
			parked += 1
	_ok(parked == 5 and Player.visible_slots().size() == Player.HOTBAR_KEYS,
		"full pockets draw four buildings and park the other five (parked %d)" % parked)
	_ok(GameState.first_free_hotbar_slot() == -1 and Player.favourite_for_key(Player.HOTBAR_KEYS) == -1,
		"...and there is nowhere to pin a tenth")


func shoot(out_dir: String) -> void:
	world.block_save = true


	while Loading.is_active():
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout

	Tech.reset()
	for id: String in GameState.TOOL_IDS:
		GameState.take_tool(id)
	Tech.grant(Player.tool_unlock(Player.Tool.SHOVEL), 1)
	Tech.grant(Player.tool_unlock(Player.Tool.PITCHFORK), 1)


	GameState.grant_tool(Player.tool_unlock(Player.Tool.SHOVEL))
	GameState.grant_tool(Player.tool_unlock(Player.Tool.PITCHFORK))
	Tech.grant("belt", 1)
	GameState.hotbar = GameState.default_hotbar()
	GameState.hotbar_changed.emit()


	catalog._grid_view = false
	catalog._apply_view()

	catalog.set_open(true)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/catalog_panel.png" % out_dir
	img.save_png(path)
	print("wrote %s" % path)


	catalog._grid_view = true
	catalog._apply_view()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var grid:= get_viewport().get_texture().get_image()
	var grid_path:= "%s/catalog_grid.png" % out_dir
	grid.save_png(grid_path)
	print("wrote %s" % grid_path)


	catalog._grid_view = false
	catalog._apply_view()


	catalog.show_entry("belt")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var lit:= get_viewport().get_texture().get_image()
	var lit_path:= "%s/catalog_lit_row.png" % out_dir
	lit.save_png(lit_path)
	print("wrote %s" % lit_path)

	catalog.set_open(false)


	if world.hud != null:
		world.hud._set_no_hud(false)


	for i in range(1, GameState.hotbar_size()):
		GameState.set_hotbar_slot(i, "")
	player.select_hotbar_slot(Player.TOOL_SLOTS.size())
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bar:= get_viewport().get_texture().get_image()
	var bar_path:= "%s/hotbar.png" % out_dir
	bar.save_png(bar_path)
	print("wrote %s" % bar_path)


	var locked:= ""
	for id: String in BuildCatalog.ids():
		if not BuildCatalog.is_unlocked(id) and TechTree.has_id(BuildCatalog.unlock_of(id)):
			locked = id
			break
	if locked != "" and player.tech_panel != null:
		catalog.set_open(true)
		await get_tree().process_frame
		catalog._pick(locked)


		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var jump:= get_viewport().get_texture().get_image()
		var jump_path:= "%s/catalog_to_tech.png" % out_dir
		jump.save_png(jump_path)
		print("wrote %s (from the %s row)" % [jump_path, locked])
	get_tree().quit(0)
