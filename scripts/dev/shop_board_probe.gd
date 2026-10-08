class_name DevShopBoardProbe
extends Node


const SETTLE:= 30

var world: Node3D
var player: Player

var _fail:= 0


func run() -> void:
	for i in 60:
		await get_tree().process_frame
	print("\n=== shop board ===")
	_built_case()
	_empty_case()
	_record_case()
	_save_case()
	_rank_built_case()
	_rank_state_case()
	await _rank_prompt_case()
	print("=== shop board: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func shoot(out_dir: String) -> void:
	world.block_save = true
	while Loading.is_active():
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout

	var board:= _board()
	var stand:= _stand()
	if board == null or stand == null:
		push_error("[shopboardshot] the world built no records board")
		get_tree().quit(1)
		return


	GameState.sell_hay(4200.0)
	GameState.sell_hay(11500.0)
	GameState.needles_found = 7
	board.refresh_now()


	for screen: Variant in [world.hud, world.mission_cue, world.quests]:
		var ci:= screen as CanvasItem
		if ci != null:
			ci.visible = false


	await _stand_at(stand.to_global(Vector3(0.0, 0.0, 3.1)), board.board_point())
	await _shot("%s/shop_board_counter.png" % out_dir)
	await _stand_at(stand.to_global(Vector3(0.95, 0.0, 2.95)), board.board_point())
	await _shot("%s/shop_board_bay.png" % out_dir)


	var rank:= world.rank_board as RankBoard
	var shop:= world.shop as HayShop
	if rank != null and shop != null:
		rank.show_state(RankBoard.State.RANKED, 12)
		await _stand_at(shop.interact_point(), rank.board_point())
		await _shot("%s/rank_board.png" % out_dir)
	get_tree().quit(0)


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)


func _built_case() -> void:
	var board:= _board()
	var stand:= _stand()
	if board == null:
		_bad("the world built no records board")
		return
	if stand == null:
		_bad("the world built no selling stand")
		return

	var rows:= board.row_count()
	print("  board: %d rows, footer '%s'" % [rows, board.footer_text()])
	if rows < 6:
		_bad("the board carries %d rows, expected at least the six records" % rows)
	for i in rows:
		if board.row_label(i).strip_edges().is_empty():
			_bad("row %d has no label beside its figure" % i)
		if board.row_value(i).strip_edges().is_empty():
			_bad("row %d prints nothing at all" % i)
	if board.footer_text().strip_edges().is_empty():
		_bad("the career footer is blank")


	var local:= stand.to_local(board.board_point())
	print("  hung at (%.2f, %.2f, %.2f) in the stand's own frame"
		% [local.x, local.y, local.z])
	if local.x < 1.0:
		_bad("the board is not on the right-hand wall (shop-local x %.2f)" % local.x)
	if local.x > ShopBoard.WALL_X:
		_bad("the board is outside the wall it hangs on (shop-local x %.2f)" % local.x)
	if local.y < 0.6 or local.y > 2.4:
		_bad("the board is hung at %.2f m, which is not a height anybody reads at"
			% local.y)


	if local.y - board.half.y - ChalkBoard.FRAME_W < 1.09:
		_bad("the bottom of the board is behind the counter top")


func _empty_case() -> void:
	var board:= _board()
	if board == null:
		return
	GameState.best_sale = 0.0
	GameState.best_sale_strands = 0.0
	GameState.best_income = 0.0
	board.refresh_now()
	var sale:= board.row_value(0)
	var minute:= board.row_value(1)
	print("  unset: biggest sale '%s', best minute '%s'" % [sale, minute])
	if sale != ShopBoard.UNSET or minute != ShopBoard.UNSET:
		_bad("a yard that has sold nothing shows a figure instead of '%s'"
			% ShopBoard.UNSET)


func _record_case() -> void:
	var board:= _board()
	if board == null:
		return
	GameState.best_sale = 0.0
	GameState.best_sale_strands = 0.0
	GameState.best_income = 0.0

	var small:= GameState.sell_hay(500.0)
	var big:= GameState.sell_hay(4000.0)
	GameState.sell_hay(120.0)
	board.refresh_now()
	print("  sales: %s then %s then a small one, board reads '%s'"
		% [Hud.money_text(small), Hud.money_text(big), board.row_value(0)])
	if absf(GameState.best_sale - big) > 0.005:
		_bad("the biggest sale reads %s after a %s one and a %s one"
			% [Hud.money_text(GameState.best_sale), Hud.money_text(small),
				Hud.money_text(big)])
	if absf(GameState.best_sale_strands - 4000.0) > 0.5:
		_bad("the biggest sale remembers %s strands, not the 4000 it was made of"
			% Hud.fmt(GameState.best_sale_strands))
	if board.row_value(0) == ShopBoard.UNSET:
		_bad("the board still says '%s' after three sales" % ShopBoard.UNSET)


	print("  best minute: $%s, window now $%s"
		% [Hud.money_text(GameState.best_income),
			Hud.money_text(GameState.income_per_minute())])
	if GameState.best_income + 0.005 < GameState.income_per_minute():
		_bad("the best minute is below the minute currently running")
	if GameState.best_income + 0.005 < big:
		_bad("the best minute is less than one sale inside it")


	var peak:= GameState.money_peak
	GameState.spend_money(GameState.money * 0.5)
	board.refresh_now()
	print("  richest: peak $%s, cash now $%s, board '%s'"
		% [Hud.money_text(GameState.money_peak), Hud.money_text(GameState.money),
			board.row_value(2)])
	if GameState.money_peak < peak - 0.005:
		_bad("spending money moved the richest record down")


func _save_case() -> void:
	var before:= {
		"sale": GameState.best_sale,
		"strands": GameState.best_sale_strands,
		"income": GameState.best_income,
		"peak": GameState.money_peak,
	}
	if before ["sale"] <= 0.0:
		_bad("nothing to round trip: the record case left the board empty")
		return
	var d:= GameState.to_dict()
	for key: String in ["best_sale", "best_sale_strands", "best_income", "money_peak"]:
		if not d.has(key):
			_bad("%s is not written into the save" % key)
	GameState.from_dict(d)
	print("  round trip: sale $%s, minute $%s, richest $%s"
		% [Hud.money_text(GameState.best_sale), Hud.money_text(GameState.best_income),
			Hud.money_text(GameState.money_peak)])
	if absf(GameState.best_sale - before ["sale"]) > 0.005 or absf(GameState.best_sale_strands - before ["strands"]) > 0.5 or absf(GameState.best_income - before ["income"]) > 0.005 or absf(GameState.money_peak - before ["peak"]) > 0.005:
		_bad("a record came back from the save dictionary changed")


func _rank_built_case() -> void:
	var rank:= world.rank_board as RankBoard
	var shop:= world.shop as HayShop
	if rank == null:
		_bad("the world built no standing board")
		return
	if shop == null:
		_bad("the world built no supply shop")
		return
	var local:= shop.to_local(rank.board_point())
	print("  standing board: hung at (%.2f, %.2f, %.2f) in the shop's own frame"
		% [local.x, local.y, local.z])
	if local.x < 1.0 or local.x > RankBoard.WALL_X:
		_bad("the standing board is not on the shop's right-hand wall (x %.2f)"
			% local.x)
	if local.y < 0.6 or local.y > 2.4:
		_bad("the standing board is hung at %.2f m, which is not a height anybody reads at"
			% local.y)


	print("  headless: '%s' / '%s'" % [rank.rank_text(), rank.under_text()])
	if Leaderboard.enabled:
		_bad("the leaderboard is enabled in a headless run, which it must never be")
	if rank.state() != RankBoard.State.DISABLED:
		_bad("the standing board is in state %d with the boards switched off"
			% rank.state())


func _rank_state_case() -> void:
	var rank:= world.rank_board as RankBoard
	if rank == null:
		return
	var seen:= { }
	for spec: Array in [
			[RankBoard.State.ASKING, 0], [RankBoard.State.RANKED, 12],
			[RankBoard.State.UNRANKED, 0], [RankBoard.State.OFFLINE, 0],
			[RankBoard.State.LOST, 0], [RankBoard.State.DISABLED, 0]]:
		rank.show_state(spec [0], spec [1])
		var said:= rank.rank_text()
		print("  state %d says '%s'" % [spec [0], said])
		if said.strip_edges().is_empty():
			_bad("state %d writes nothing on the wall" % spec [0])
		if seen.has(said):
			_bad("state %d says the same thing as another state: '%s'"
				% [spec [0], said])
		seen [said] = true


		if spec [0] != RankBoard.State.RANKED and said.contains("YOU ARE"):
			_bad("state %d claims a place on the boards: '%s'" % [spec [0], said])
	rank.show_state(RankBoard.State.RANKED, 12)
	if not rank.rank_text().contains("12th"):
		_bad("a rank of 12 is written as '%s'" % rank.rank_text())
	rank.show_state(RankBoard.State.RANKED, 1)
	if not rank.rank_text().contains("1st"):
		_bad("a rank of 1 is written as '%s'" % rank.rank_text())
	rank.show_state(RankBoard.State.DISABLED, 0)


func _rank_prompt_case() -> void:
	var rank:= world.rank_board as RankBoard
	if rank == null or rank.face == null or world.hud == null:
		return
	var aim:= rank.board_point()
	var out:= rank.face.global_basis.z.normalized()
	var spot:= aim + Vector3(out.x, 0.0, out.z).normalized() * 1.6
	spot.y = world.shop.global_position.y
	await _stand_at(spot, aim)


	var dir:= (aim - player.eye_position()).normalized()
	player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))
	await get_tree().physics_frame
	var wanted: String = world.hud.call("_prompt_wanted")
	print("  at the standing board: at_board %s, plate '%s'"
		% [player.leaderboards.is_at_board(), wanted])
	if not player.leaderboards.is_at_board():
		_bad("E does not reach the standing board from 1.6 m in front of it")
	elif wanted != "leaderboards":
		_bad("the walk-up plate at the standing board is '%s', not leaderboards" % wanted)


func _bad(line: String) -> void:
	print("  FAIL  %s" % line)
	_fail += 1


func _board() -> ShopBoard:
	return world.shop_board as ShopBoard


func _stand() -> HaySellingStand:
	return world.stand as HaySellingStand


func _stand_at(pos: Vector3, look_at: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(pos.x, maxf(pos.y, 0.1) + 0.9, pos.z)
	var dir:= (look_at - player.eye_position()).normalized()
	if dir.length_squared() > 0.0001:
		player.rotation.y = atan2(- dir.x, - dir.z)
		if player.head != null:
			player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))
	for i in SETTLE:
		await get_tree().physics_frame
