extends Node


const STARTING_MONEY:= 0.0

signal hay_changed(remaining: float, dug_total: float)
signal needle_found(index: int, position: Vector3)


signal needle_lost(type: int, paid: float, cause: NeedleLoss)


enum NeedleLoss {


	SOLD,


	SCRAPPED,

	BURNED,

	DEMOLISHED,
}


signal needle_discovered(type: int, position: Vector3)

signal needle_stock_changed(type: int, held: int)


signal debt_changed(owed: float)


signal collection_loaded()
signal strand_plucked(position: Vector3)


signal pile_replaced()


signal pile_emptied()
signal money_changed(amount: float)
signal hay_sold_changed(sold_total: float)


signal hotbar_changed()

signal tools_changed()

var hay_total: float = 0.0
var hay_initial: float = 0.0
var hay_dug: float = 0.0


var hay_returned: float = 0.0
var needles_found: int = 0


var pile_needles_found: int = 0


var run_secs: float = 0.0

var first_needle_secs: float = -1.0


var run_timed: bool = true


var first_clear_secs: float = -1.0


var pile_cleared: bool = false


var has_hatch: bool = false


var radar_cooldown: float = 0.0


var jetpack_fuel: float = Cfg.JETPACK_TANK_SECONDS


var lot_tier: int = 0


var money: float = 0.0


var debt: float = 0.0


var stacks_ordered: int = 0


func next_stack_fee() -> float:
	var shares:= Cfg.CONSIGNMENT_FEE_SHARES
	if shares.is_empty() or hay_initial <= 0.0:
		return 0.0
	var share: float = shares [mini(stacks_ordered, shares.size() - 1)]
	return roundf(hay_initial * Cfg.HAY_PRICE * share / 1000.0) * 1000.0


func credit_stack_fee() -> float:
	return roundf(next_stack_fee() * Cfg.CONSIGNMENT_CREDIT_MARKUP / 1000.0) * 1000.0


func pay_for_next_stack(pay_now: bool) -> bool:
	var fee:= next_stack_fee()
	if fee <= 0.0:
		return true
	if pay_now:
		if not spend_money(fee):
			return false
	else:
		debt += credit_stack_fee()
		debt_changed.emit(debt)
	stacks_ordered += 1
	return true


func pay_off_debt() -> float:
	var paid:= minf(debt, money)
	if paid <= 0.0:
		return 0.0


	debt = maxf(0.0, debt - paid)
	spend_money(paid)
	debt_changed.emit(debt)
	return paid


var hay_sold: float = 0.0
var money_earned: float = 0.0


var best_sale: float = 0.0
var best_sale_strands: float = 0.0
var best_income: float = 0.0
var money_peak: float = 0.0


var debug_used:= false


const INCOME_WINDOW:= 60.0


var _income_log: Array [Vector2] = []


var _income_clock:= 0.0


var _hay_samples: PackedFloat64Array = PackedFloat64Array()
var _hay_sample_due:= 0.0


var needle_positions: PackedVector3Array = PackedVector3Array()
var needle_taken: PackedByteArray = PackedByteArray()


var needle_type: PackedByteArray = PackedByteArray()


var discovered: PackedByteArray = PackedByteArray()


var needle_stock: PackedInt32Array = PackedInt32Array()


var needles_by_type: PackedInt32Array = PackedInt32Array()


var needle_out: PackedInt32Array = PackedInt32Array()


var needle_loose: PackedInt32Array = PackedInt32Array()

var needle_loose_at: PackedVector3Array = PackedVector3Array()

var run_seed: int = 0


var hotbar: PackedStringArray = default_hotbar()


const RECENT_BUILDS_MAX:= 16
var recent_builds: PackedStringArray = PackedStringArray()


var fresh_builds: PackedStringArray = PackedStringArray()


var owned_tools: Dictionary = { }


var _tools_from_tech:= false


var mission_index:= 0


var mission_earned_step:= ""
var mission_earned_from:= 0.0


var gifts: Dictionary = { }


var gifts_given: Dictionary = { }


var gift_card_due:= ""
signal gifts_changed


var purchase_log: Array = []
const PURCHASE_LOG_MAX:= 3000


var contract_index:= 0
var contract_delivered:= 0
var contracts_done: Dictionary = { }


var contract_pinned:= false

signal contract_pin_changed(pinned: bool)


signal contracts_changed()


var used_fetch:= false


func reset(seed_value: int, total_strands: float) -> void:
	run_seed = seed_value
	hay_total = total_strands
	hay_initial = total_strands
	hay_dug = 0.0
	hay_returned = 0.0
	needles_found = 0
	pile_needles_found = 0
	run_secs = 0.0
	first_needle_secs = -1.0
	run_timed = true
	first_clear_secs = -1.0
	pile_cleared = false
	radar_cooldown = 0.0
	jetpack_fuel = Cfg.JETPACK_TANK_SECONDS
	money = STARTING_MONEY
	debt = 0.0
	stacks_ordered = 0
	hay_sold = 0.0
	money_earned = 0.0
	best_sale = 0.0
	best_sale_strands = 0.0
	best_income = 0.0
	money_peak = STARTING_MONEY
	debug_used = false
	has_hatch = true
	_income_log.clear()
	_clear_hay_samples()
	needle_positions = PackedVector3Array()
	needle_taken = PackedByteArray()
	needle_type = PackedByteArray()
	lot_tier = 0
	Tech.reset()


	var start_tech:= Cfg.pile_start_tech()
	for id: String in start_tech:
		Tech.grant(id, int(start_tech [id]))


	owned_tools = { }
	_withheld_tools.clear()
	_tools_from_tech = false
	tools_changed.emit()
	mission_index = 0
	mission_earned_step = ""
	mission_earned_from = 0.0
	gifts = { }
	gifts_given = { }
	gift_card_due = ""
	gifts_changed.emit()
	purchase_log = []
	contract_index = 0
	contract_delivered = 0
	contracts_done = { }
	contracts_changed.emit()
	contract_pinned = false
	contract_pin_changed.emit(false)
	hotbar = default_hotbar()
	hotbar_changed.emit()
	recent_builds = PackedStringArray()
	fresh_builds = PackedStringArray()
	_reset_collection()
	hay_changed.emit(hay_total, hay_dug)
	money_changed.emit(money)


func _reset_collection() -> void:
	var n:= NeedleTypes.count()
	discovered = PackedByteArray()
	discovered.resize(n)
	needle_stock = PackedInt32Array()
	needle_stock.resize(n)
	needles_by_type = PackedInt32Array()
	needles_by_type.resize(n)
	needle_out = PackedInt32Array()
	needle_loose = PackedInt32Array()
	needle_loose_at = PackedVector3Array()
	collection_loaded.emit()


func register_needle(pos: Vector3, rng: RandomNumberGenerator = null,
		forced_type: int = -1) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	needle_positions.append(pos)
	needle_taken.append(0)
	var type:= forced_type
	if type < 0 or type >= NeedleTypes.count():
		type = NeedleTypes.roll(lot_tier, rng)
	needle_type.append(type)
	return needle_positions.size() - 1


func type_of(index: int) -> int:
	if index < 0 or index >= needle_type.size():
		return 0
	return int(needle_type [index])


var _hay_dirty:= false


func remove_hay(count: float) -> void:
	if count <= 0.0:
		return
	hay_total = maxf(0.0, hay_total - count)
	hay_dug += count


	_hay_dirty = true


func return_hay(count: float) -> void:
	if count <= 0.0:
		return
	hay_total += count


	hay_returned += count
	_hay_dirty = true


func lose_hay(count: float) -> void:
	if count <= 0.0:
		return
	hay_total = maxf(0.0, hay_total - count)
	_clear_hay_samples()


	hay_changed.emit(hay_total, hay_dug)


func is_pile_clear() -> bool:
	if hay_initial <= 0.0:
		return false
	return hay_never_dug() <= Cfg.PILE_CLEAR_STRANDS


func check_cleared() -> void:
	if pile_cleared or not is_pile_clear():
		return
	pile_cleared = true
	if run_timed and first_clear_secs < 0.0:
		first_clear_secs = run_secs
	pile_emptied.emit()


func hay_left_fraction() -> float:
	if hay_initial <= 0.0:
		return 0.0
	return clampf(hay_never_dug() / hay_initial, 0.0, 1.0)


func hay_never_dug() -> float:
	return maxf(0.0, hay_total - hay_returned)


func match_pile(field_strands: float) -> void:
	if hay_initial <= 0.0 or field_strands < 0.0:
		return
	hay_returned = maxf(0.0, hay_total - field_strands)
	hay_total = field_strands + hay_returned
	_clear_hay_samples()
	hay_changed.emit(hay_total, hay_dug)


func needles_buried() -> int:
	var n:= 0
	for i in needle_taken.size():
		if needle_taken [i] == 0:
			n += 1
	return n


func may_order_pile() -> bool:
	return needle_taken.size() > 0 and lot_complete(lot_tier) and not demo_holds_next_load()


func demo_holds_next_load() -> bool:
	return Cfg.demo_lot_gate and lot_tier == Cfg.DEMO_LAST_LOT


func demo_is_over() -> bool:
	return demo_holds_next_load() and lot_complete(lot_tier)


func pile_needle_types() -> PackedInt32Array:
	if demo_holds_next_load():
		return NeedleTypes.pool(Cfg.DEMO_LAST_LOT)
	var out:= PackedInt32Array()
	for type in NeedleTypes.count():
		out.append(type)
	return out


func lot_missing() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for type in NeedleTypes.pool(lot_tier):
		if not is_discovered(type):
			out.append(type)
	return out


func new_pile(seed_value: int, total_strands: float) -> void:
	run_seed = seed_value
	while lot_complete(lot_tier) and lot_tier < NeedleTypes.lot_count() - 1:
		lot_tier += 1


	hay_total = total_strands
	hay_initial = total_strands


	hay_returned = 0.0


	needle_positions = PackedVector3Array()
	needle_taken = PackedByteArray()
	needle_type = PackedByteArray()


	pile_needles_found = 0


	pile_cleared = false
	_clear_hay_samples()
	hay_changed.emit(hay_total, hay_dug)
	pile_replaced.emit()


func _process(delta: float) -> void:
	if _hay_dirty:
		_hay_dirty = false
		hay_changed.emit(hay_total, hay_dug)


	_income_clock += delta
	var cutoff:= _income_clock - INCOME_WINDOW
	while not _income_log.is_empty() and _income_log [0].x <= cutoff:
		_income_log.remove_at(0)

	if _income_clock >= _hay_sample_due:
		_hay_sample_due = _income_clock + 1.0
		_hay_samples.append(hay_never_dug())
		if _hay_samples.size() > int(INCOME_WINDOW) + 1:
			_hay_samples.remove_at(0)


func hay_removed_per_minute() -> float:
	if _hay_samples.size() < 2:
		return 0.0
	return maxf(0.0, _hay_samples [0] - _hay_samples [_hay_samples.size() - 1])


func _clear_hay_samples() -> void:
	_hay_samples.clear()
	_hay_sample_due = _income_clock


func add_money(amount: float) -> void:
	if amount == 0.0:
		return
	money += amount
	money_peak = maxf(money_peak, money)
	money_changed.emit(money)


func sell_hay(strands: float, worth: float = -1.0) -> float:
	if strands <= 0.0:
		return 0.0
	if worth < 0.0:
		worth = strands
	var amount:= worth * Tech.hay_price()
	hay_sold += strands
	money_earned += amount
	_income_log.append(Vector2(_income_clock, amount))


	if amount > best_sale:
		best_sale = amount
		best_sale_strands = strands
	best_income = maxf(best_income, income_per_minute())
	hay_sold_changed.emit(hay_sold)


	var kept:= amount
	if debt > 0.0:
		var cut:= minf(debt, amount * Cfg.CONSIGNMENT_PAYBACK_SHARE)
		debt = maxf(0.0, debt - cut)
		kept -= cut
		debt_changed.emit(debt)
	add_money(kept)
	return kept


static func capped_sold(sold: float, dug: float) -> float:
	if dug <= 0.0:
		return sold
	return minf(sold, dug)


func income_per_minute() -> float:
	var cutoff:= _income_clock - INCOME_WINDOW
	var total:= 0.0
	for sale: Vector2 in _income_log:
		if sale.x > cutoff:
			total += sale.y
	return total


func deposit_needle(index: int, pos: Vector3) -> void:
	if index >= 0 and index < needle_taken.size():
		needle_taken [index] = 1
	var type:= type_of(index)


	var out_at:= needle_out.find(index)
	if index >= 0 and out_at >= 0:
		needle_out.remove_at(out_at)
		_hold(type, 1)
		needle_found.emit(index, pos)
		return
	needles_found += 1
	pile_needles_found += 1
	if type >= 0 and type < needles_by_type.size():
		needles_by_type [type] += 1
	_hold(type, 1)
	needle_found.emit(index, pos)


func discover(type: int, pos: Vector3) -> bool:
	if type < 0 or type >= discovered.size() or discovered [type] == 1:
		return false
	discovered [type] = 1


	if run_timed and first_needle_secs < 0.0:
		first_needle_secs = run_secs
	needle_discovered.emit(type, pos)
	return true


func tick_run_clock(delta: float) -> void:
	if delta > 0.0:
		run_secs += delta


func withdraw_needle(type: int, pos: Vector3 = Vector3.ZERO) -> int:
	if type < 0 or type >= needle_stock.size() or needle_stock [type] <= 0:
		return -1
	_hold(type, -1)
	var index:= register_needle(pos, null, type)
	needle_taken [index] = 1
	needle_out.append(index)
	return index


func lose_needle(index: int, type: int, paid: float, cause: NeedleLoss) -> void:
	var out_at:= needle_out.find(index)
	if index >= 0 and out_at >= 0:
		needle_out.remove_at(out_at)
	needle_lost.emit(type, paid, cause)


func _hold(type: int, delta: int) -> void:
	if type < 0 or type >= needle_stock.size():
		return
	needle_stock [type] = maxi(0, needle_stock [type] + delta)
	needle_stock_changed.emit(type, needle_stock [type])


func is_discovered(type: int) -> bool:
	return type >= 0 and type < discovered.size() and discovered [type] == 1


func stock_of(type: int) -> int:
	if type < 0 or type >= needle_stock.size():
		return 0
	return needle_stock [type]


func found_of(type: int) -> int:
	if type < 0 or type >= needles_by_type.size():
		return 0
	return needles_by_type [type]


func collection_complete() -> bool:
	if discovered.is_empty():
		return false
	for type in discovered.size():
		if discovered [type] != 1:
			return false
	return true


func lot_complete(lot: int) -> bool:
	var ids:= NeedleTypes.pool(lot)
	if ids.is_empty():
		return false
	for type in ids:
		if not is_discovered(type):
			return false
	return true


func lot_progress(lot: int) -> Vector2i:
	var ids:= NeedleTypes.pool(lot)
	var seen:= 0
	for type in ids:
		if is_discovered(type):
			seen += 1
	return Vector2i(seen, ids.size())


func research_held() -> int:
	var total:= 0
	for t in needle_stock.size():
		total += needle_stock [t] * NeedleTypes.research_of(t)
	return total


func spend_research(amount: int) -> bool:
	if amount <= 0:
		return true
	if research_held() < amount:
		return false
	var order: Array [int] = []
	for t in needle_stock.size():
		order.append(t)
	order.sort_custom(func(a: int, b: int) -> bool:
		return NeedleTypes.research_of(a) < NeedleTypes.research_of(b))
	var left:= amount
	for t in order:
		while left > 0 and needle_stock [t] > 0:
			left -= NeedleTypes.research_of(t)
			_hold(t, -1)
		if left <= 0:
			break
	return true


func can_afford(amount: float) -> bool:


	return money >= amount - 0.001


func spend_money(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_afford(amount):
		return false
	money = maxf(0.0, money - amount)
	money_changed.emit(money)
	return true


signal purchased(kind: String, id: String)


func note_purchase(kind: String, id: String, rank: int, price: float) -> void:
	purchase_log.append([snappedf(run_secs, 0.1), kind, id, rank, snappedf(price, 0.01)])
	if purchase_log.size() > PURCHASE_LOG_MAX:
		purchase_log.resize(PURCHASE_LOG_MAX)
	purchased.emit(kind, id)


func gift_waiting(id: String) -> int:
	return int(gifts.get(id, 0))


func give_gift(id: String, count: int = 1) -> void:
	gifts [id] = gift_waiting(id) + count
	gifts_changed.emit()


func take_gift(id: String) -> bool:
	var n:= gift_waiting(id)
	if n <= 0:
		return false
	if n == 1:
		gifts.erase(id)
	else:
		gifts [id] = n - 1
	gifts_changed.emit()
	return true


func claim_needle(index: int, pos: Vector3) -> void:
	if index < 0 or index >= needle_taken.size():
		return
	if needle_taken [index] == 1:
		return
	needle_taken [index] = 1
	needles_found += 1
	pile_needles_found += 1
	needle_found.emit(index, pos)


func needles_in_sphere(center: Vector3, radius: float) -> PackedInt32Array:
	var out:= PackedInt32Array()
	var r2:= radius * radius
	for i in needle_positions.size():
		if needle_taken [i] == 1:
			continue
		if needle_positions [i].distance_squared_to(center) <= r2:
			out.append(i)
	return out


static func hotbar_size() -> int:
	return maxi(Player.HOTBAR_KEYS - 1, 0)


static func favourite_room() -> int:
	return maxi(Player.HOTBAR_KEYS - Player.tool_boxes_shown(), 0)


func hotbar_slot_shown(index: int) -> bool:
	if not _hotbar_pin_drawable(index):
		return false
	var ahead:= 0
	for i in index:
		if _hotbar_pin_drawable(i):
			ahead += 1
	return ahead < favourite_room()


func _hotbar_pin_drawable(index: int) -> bool:
	var id:= hotbar_slot(index)
	return id != "" and BuildCatalog.is_unlocked(id)


func hotbar_slot_parked(index: int) -> bool:
	return _hotbar_pin_drawable(index) and not hotbar_slot_shown(index)


func _drawable_pin_count() -> int:
	var n:= 0
	for i in hotbar.size():
		if _hotbar_pin_drawable(i):
			n += 1
	return n


const TOOL_IDS:= ["spade", "pitchfork", "broom", "sand_shovel", "metal_detector",
	"yard_vac", "lighter"]


const DEMO_WITHHELD_TOOLS:= ["lighter"]


var _withheld_tools: Array [String] = []


func resolve_legacy_tools() -> void:
	if not _tools_from_tech:
		return
	_tools_from_tech = false
	for id: String in TOOL_IDS:
		if Tech.is_unlocked(id):
			owned_tools [id] = true
	tools_changed.emit()


const LEGACY_TOOLS:= ["spade", "pitchfork", "broom"]


func has_tool(id: String) -> bool:
	return bool(owned_tools.get(id, false))


const CARRIED_TOOL_MAX:= 5


func carried_tool_count() -> int:
	var n:= 0
	for id: String in TOOL_IDS:
		if has_tool(id):
			n += 1
	return n


func can_carry_another() -> bool:
	return carried_tool_count() < CARRIED_TOOL_MAX


func grant_tool(id: String) -> bool:
	if id == "" or has_tool(id):
		return false


	if Cfg.DEMO and id in DEMO_WITHHELD_TOOLS:
		return false
	if not can_carry_another():
		return false
	owned_tools [id] = true
	tools_changed.emit()
	return true


func take_tool(id: String) -> bool:
	if not has_tool(id):
		return false
	owned_tools.erase(id)
	tools_changed.emit()
	return true


func grant_legacy_tools() -> void:
	for id: String in LEGACY_TOOLS:
		grant_tool(id)


func hotbar_slot(index: int) -> String:
	if index < 0 or index >= hotbar.size():
		return ""
	return hotbar [index]


func set_hotbar_slot(index: int, id: String) -> void:
	if index < 0 or index >= hotbar.size():
		return
	if id != "" and not BuildCatalog.has_id(id):
		return
	if hotbar [index] == id:
		return
	if id != "":
		for i in hotbar.size():
			if i != index and hotbar [i] == id:
				hotbar [i] = ""
	hotbar [index] = id
	hotbar_changed.emit()


func hotbar_index_of(id: String) -> int:
	if id == "":
		return -1
	for i in hotbar.size():
		if hotbar [i] == id:
			return i
	return -1


func first_free_hotbar_slot() -> int:
	if _drawable_pin_count() >= favourite_room():
		return -1
	for i in hotbar.size():
		if hotbar [i] == "":
			return i
	for i in hotbar.size():
		if not BuildCatalog.is_unlocked(hotbar [i]):
			return i
	return -1


func note_build_used(id: String) -> void:
	if id == "" or not BuildCatalog.has_id(id):
		return
	var fresh_at:= fresh_builds.find(id)
	if fresh_at >= 0:
		fresh_builds.remove_at(fresh_at)
	var at:= recent_builds.find(id)
	if at == 0:


		return
	if at > 0:
		recent_builds.remove_at(at)
	recent_builds.insert(0, id)
	while recent_builds.size() > RECENT_BUILDS_MAX:
		recent_builds.remove_at(recent_builds.size() - 1)


func note_builds_bought(node: String) -> void:
	var sold:= BuildCatalog.builds_for(node)
	for i in range(sold.size() - 1, -1, -1):
		var id: String = sold [i]
		var at:= fresh_builds.find(id)
		if at >= 0:
			fresh_builds.remove_at(at)
		fresh_builds.insert(0, id)


func toggle_hotbar(id: String) -> int:
	var at:= hotbar_index_of(id)
	if at >= 0:
		set_hotbar_slot(at, "")
		return -1
	var free:= first_free_hotbar_slot()
	if free < 0:
		return -1
	set_hotbar_slot(free, id)
	return free


static func default_hotbar() -> PackedStringArray:
	var out:= PackedStringArray(BuildCatalog.DEFAULT_FAVOURITES)
	out.resize(hotbar_size())
	return out


func _sanitise_hotbar() -> void:
	var want:= hotbar_size()
	if hotbar.size() != want:
		hotbar.resize(want)


	for i in hotbar.size():
		if hotbar [i] != "" and not BuildCatalog.has_id(hotbar [i]):
			hotbar [i] = ""


func contract_signed(id: String) -> bool:
	return contracts_done.has(id)


func sign_contract(id: String) -> void:
	if id.is_empty() or contracts_done.has(id):
		return
	contracts_done [id] = true
	contracts_changed.emit()


func to_dict() -> Dictionary:
	return {
		"hay_total": hay_total,
		"hay_initial": hay_initial,
		"hay_dug": hay_dug,
		"hay_returned": hay_returned,
		"needles_found": needles_found,
		"pile_needles_found": pile_needles_found,
		"run_secs": run_secs,
		"first_needle_secs": first_needle_secs,
		"run_timed": run_timed,
		"first_clear_secs": first_clear_secs,
		"pile_cleared": pile_cleared,
		"needle_positions": needle_positions,
		"needle_taken": needle_taken,
		"needle_type": needle_type,
		"discovered": discovered,
		"needle_stock": needle_stock,
		"needles_by_type": needles_by_type,
		"needle_out": needle_out,


		"needle_loose": needle_loose,
		"needle_loose_at": needle_loose_at,
		"lot_tier": lot_tier,
		"money": money,
		"debt": debt,
		"stacks_ordered": stacks_ordered,
		"hay_sold": hay_sold,
		"money_earned": money_earned,
		"best_sale": best_sale,
		"best_sale_strands": best_sale_strands,
		"best_income": best_income,
		"money_peak": money_peak,
		"debug_used": debug_used,
		"run_seed": run_seed,
		"hotbar": hotbar,
		"recent_builds": recent_builds,
		"fresh_builds": fresh_builds,
		"owned_tools": owned_tools.keys() + _withheld_tools,
		"mission_index": mission_index,


		"mission_id": MissionBook.id_at(mission_index) if mission_index < MissionBook.count() else "",
		"mission_earned_step": mission_earned_step,
		"mission_earned_from": mission_earned_from,


		"gifts": gifts.duplicate(),
		"gifts_given": gifts_given.keys(),
		"gift_card_due": gift_card_due,
		"purchase_log": purchase_log.duplicate(true),
		"contract_index": contract_index,
		"contract_delivered": contract_delivered,
		"contracts_done": contracts_done.keys(),
		"contract_pinned": contract_pinned,
		"radar_cool": radar_cooldown,
		"jetpack_fuel": jetpack_fuel,
		"floor_hatch": has_hatch,
	}


func from_dict(d: Dictionary) -> void:
	hay_total = d.get("hay_total", 0.0)
	hay_initial = d.get("hay_initial", hay_total)
	hay_dug = d.get("hay_dug", 0.0)


	hay_returned = d.get("hay_returned", 0.0)
	needles_found = d.get("needles_found", 0)


	run_timed = d.has("run_secs") and bool(d.get("run_timed", true))
	run_secs = maxf(0.0, float(d.get("run_secs", 0.0)))
	first_needle_secs = float(d.get("first_needle_secs", -1.0))
	first_clear_secs = float(d.get("first_clear_secs", -1.0))


	pile_cleared = bool(d.get("pile_cleared", is_pile_clear()))


	has_hatch = bool(d.get("floor_hatch", false))


	radar_cooldown = clampf(float(d.get("radar_cool", 0.0)), 0.0, Cfg.RADAR_COOLDOWN)


	jetpack_fuel = 0.0 if Cfg.DEMO else clampf(
		float(d.get("jetpack_fuel", Cfg.JETPACK_TANK_SECONDS)), 0.0, Cfg.JETPACK_TANK_SECONDS)
	needle_positions = d.get("needle_positions", PackedVector3Array())
	needle_taken = d.get("needle_taken", PackedByteArray())


	pile_needles_found = int(d.get("pile_needles_found", -1))
	if pile_needles_found < 0:
		var lifted:= 0
		for i in needle_taken.size():
			if needle_taken [i] == 1:
				lifted += 1
		var carried: PackedInt32Array = d.get("needle_out", PackedInt32Array())
		pile_needles_found = maxi(0, lifted - carried.size())
	lot_tier = int(d.get("lot_tier", 0))


	needle_type = d.get("needle_type", PackedByteArray())
	_reset_collection()
	var saved_seen: PackedByteArray = d.get("discovered", PackedByteArray())
	for i in mini(saved_seen.size(), discovered.size()):
		discovered [i] = saved_seen [i]
	var saved_stock: PackedInt32Array = d.get("needle_stock", PackedInt32Array())
	for i in mini(saved_stock.size(), needle_stock.size()):
		needle_stock [i] = saved_stock [i]


	var saved_found: PackedInt32Array = d.get("needles_by_type", saved_stock)
	for i in mini(saved_found.size(), needles_by_type.size()):
		needles_by_type [i] = saved_found [i]


	needle_loose = d.get("needle_loose", PackedInt32Array())
	needle_loose_at = d.get("needle_loose_at", PackedVector3Array())


	if needle_loose.size() != needle_loose_at.size():
		var n:= mini(needle_loose.size(), needle_loose_at.size())
		needle_loose = needle_loose.slice(0, n)
		needle_loose_at = needle_loose_at.slice(0, n)
	var saved_out: PackedInt32Array = d.get("needle_out", PackedInt32Array())
	needle_out = PackedInt32Array()
	for index: int in saved_out:
		if needle_loose.has(index):
			needle_out.append(index)
		else:
			_hold(type_of(index), 1)


	collection_loaded.emit()
	money = d.get("money", STARTING_MONEY)


	debt = maxf(0.0, float(d.get("debt", 0.0)))
	stacks_ordered = maxi(0, int(d.get("stacks_ordered", 0)))


	hay_sold = capped_sold(d.get("hay_sold", 0.0), hay_dug)
	money_earned = d.get("money_earned", 0.0)


	best_sale = d.get("best_sale", 0.0)
	best_sale_strands = d.get("best_sale_strands", 0.0)
	best_income = d.get("best_income", 0.0)
	money_peak = maxf(d.get("money_peak", 0.0), money)


	debug_used = bool(d.get("debug_used", false))


	_income_log.clear()
	_clear_hay_samples()
	run_seed = d.get("run_seed", 0)


	hotbar = d.get("hotbar", default_hotbar())
	_sanitise_hotbar()


	recent_builds = PackedStringArray()
	for id: String in PackedStringArray(d.get("recent_builds", PackedStringArray())):
		if BuildCatalog.has_id(id) and recent_builds.find(id) < 0:
			recent_builds.append(id)
	while recent_builds.size() > RECENT_BUILDS_MAX:
		recent_builds.remove_at(recent_builds.size() - 1)


	fresh_builds = PackedStringArray()
	for id: String in PackedStringArray(d.get("fresh_builds", PackedStringArray())):
		if BuildCatalog.has_id(id) and fresh_builds.find(id) < 0:
			fresh_builds.append(id)


	owned_tools = { }
	_withheld_tools.clear()
	_tools_from_tech = not d.has("owned_tools")
	if not _tools_from_tech:
		for id: Variant in d ["owned_tools"]:

			if Cfg.DEMO and str(id) in DEMO_WITHHELD_TOOLS:
				if not _withheld_tools.has(str(id)):
					_withheld_tools.append(str(id))
				continue
			owned_tools [str(id)] = true
	tools_changed.emit()


	mission_index = MissionBook.index_from_save(d)
	mission_earned_step = str(d.get("mission_earned_step", ""))
	mission_earned_from = float(d.get("mission_earned_from", 0.0))


	gifts = { }
	var saved_gifts: Variant = d.get("gifts", { })
	if saved_gifts is Dictionary:
		for id: Variant in saved_gifts:
			var n:= int(saved_gifts [id])
			if n > 0:
				gifts [str(id)] = n
	gifts_given = { }
	for id: Variant in d.get("gifts_given", []):
		gifts_given [str(id)] = true
	gift_card_due = str(d.get("gift_card_due", ""))
	gifts_changed.emit()
	purchase_log = []
	var saved_log: Variant = d.get("purchase_log", [])
	if saved_log is Array:
		purchase_log = (saved_log as Array).duplicate(true)


	contract_index = int(d.get("contract_index", 0))
	contract_delivered = int(d.get("contract_delivered", 0))
	contract_pinned = bool(d.get("contract_pinned", false))
	contract_pin_changed.emit(contract_pinned)
	contracts_done = { }
	for id: Variant in d.get("contracts_done", []):
		contracts_done [str(id)] = true


	var open:= DeliveryBook.first_open(contracts_done)
	if contract_index != open:
		contract_index = open
		contract_delivered = 0
	contracts_changed.emit()
	hay_changed.emit(hay_total, hay_dug)
	money_changed.emit(money)
	hotbar_changed.emit()
