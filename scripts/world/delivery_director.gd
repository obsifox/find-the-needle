class_name DeliveryDirector
extends Node


const POLL:= 0.25


const T_SIGN_OFF:= 1.6


var call_wait:= 60.0

var truck: DeliveryTruck
var board: DeliveryBoard
var panel: ContractPanel
var props: PropManager

var _clock:= 0.0


var _sign_off:= 0.0


var _call_in:= -1.0


func _ready() -> void:
	set_process(true)


	BeltPath.pushed_kinds = 0


	if truck != null and _open_index() >= 0 and GameState.contract_delivered > 0:
		truck.snap_parked()
	_restate()


func _process(delta: float) -> void:
	_clock += delta
	if _clock < POLL:
		return
	_clock = 0.0
	_tick()


func _tick() -> void:
	var index:= _open_index()
	if index < 0:
		if board != null:
			board.show_finished()
		if panel != null:
			panel.show_finished()
		return
	if _sign_off > 0.0:
		_sign_off = maxf(0.0, _sign_off - POLL)
		if _sign_off <= 0.0:
			_close(index)
			return
	elif truck != null:
		if truck.is_away():
			_maybe_call(index)
		elif truck.is_parked():
			_collect(index)
	_restate()


func _open_index() -> int:
	var i:= GameState.contract_index
	return i if i >= 0 and i < DeliveryBook.count() else -1


func _maybe_call(index: int) -> void:
	if _call_in < 0.0:
		if props == null or not _yard_has(index):
			return
		_call_in = call_wait
	_call_in = maxf(0.0, _call_in - POLL)
	if _call_in <= 0.0:
		_call_in = -1.0
		truck.arrive()


func _yard_has(index: int) -> bool:
	var c:= DeliveryBook.contract(index)
	if c.is_empty():
		return false
	var want:= str(c.get("want", ""))
	if props.count_of(want) > 0 or _pushed(want):
		return true
	var also:= str(c.get("also", ""))
	return not also.is_empty() and (props.count_of(also) > 0 or _pushed(also))


func _pushed(item_id: String) -> bool:
	var kind:= BeltRun.ITEM_IDS.find(item_id)
	return kind >= 0 and (BeltPath.pushed_kinds & (1 << kind)) != 0


func _collect(index: int) -> void:
	var need:= DeliveryBook.needed(index)
	if GameState.contract_delivered >= need:
		_sign_off = T_SIGN_OFF
		return
	for item in truck.settled_items():
		if not DeliveryBook.accepts(index, item.item_id):
			continue
		GameState.contract_delivered += 1
		truck.stack_one(item.item_id)
		Audio.play_3d(item.impact_sfx(), item.global_position, 0.0)


		if item.holds_needle():
			GameState.lose_needle(
				item.needle_index, GameState.type_of(item.needle_index), 0.0,
				GameState.NeedleLoss.SOLD)
		props.remove(item)
		if GameState.contract_delivered >= need:
			_sign_off = T_SIGN_OFF
		return


func _close(index: int) -> void:
	var c:= DeliveryBook.contract(index)
	GameState.add_money(float(c.get("pay", 0.0)))
	GameState.sign_contract(DeliveryBook.id_at(index))
	GameState.contract_index = index + 1
	GameState.contract_delivered = 0


	_call_in = -1.0
	BeltPath.pushed_kinds = 0
	Audio.play("sell_register", -2.0)
	Audio.play_delayed("coins", 0.18, -3.0)
	if panel != null:
		panel.mark_complete(DeliveryBook.title_of(index))
	if truck != null:
		truck.depart()
	_restate()


func _restate() -> void:
	var index:= _open_index()
	if index < 0:
		if board != null:
			board.show_finished()
		if panel != null:
			panel.show_finished()
		return
	var have:= GameState.contract_delivered
	var need:= DeliveryBook.needed(index)
	var line:= state_line(index)
	if board != null:
		board.show_contract(index, have, need, line)
	if panel != null:
		panel.show_contract(index, have, need, line)


func state_line(index: int) -> String:
	if _sign_off > 0.0:
		return tr("SIGNED OFF")
	if truck == null or truck.is_away():
		if _call_in >= 0.0:


			return tr("TRUCK ON ITS WAY: %s") % _clock_text(_call_in)
		var c:= DeliveryBook.contract(index)


		return tr("TRUCK DUE ON THE FIRST %s") % Cfg.upper(ItemDb.display_name(
			str(c.get("want", ""))))
	if truck.is_parked():
		return tr("TRUCK AT THE DOOR")
	return tr("TRUCK ARRIVING")


static func _clock_text(left: float) -> String:
	var secs:= int(ceilf(left))
	return "%d:%02d" % [secs / 60, secs % 60]


func progress() -> Dictionary:
	var index:= _open_index()
	if index < 0:
		return { }
	return { "have": GameState.contract_delivered,
		"need": DeliveryBook.needed(index) }
