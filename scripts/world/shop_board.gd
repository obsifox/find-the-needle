class_name ShopBoard
extends ChalkBoard


const WALL_X:= 2.35 - 0.045 / 2.0


const BOARD_AT:= Vector2(-0.4, 1.75)


const SIZE:= Vector2(0.75, 0.575)

const ROW_TOP:= 0.265
const ROW_PITCH:= 0.142


const LABEL_COL:= 0.4


const TICK:= 0.5


const UNSET:= "not yet"


const TITLE:= "YARD RECORDS"

var _rows: Array [Label3D] = []
var _last: PackedStringArray = PackedStringArray()
var _foot: Label3D
var _last_foot:= ""
var _clock:= 0.0


func _row_table() -> Array:


	return [
		[tr("BEST SALE"), _best_sale],
		[tr("BEST MINUTE"), _best_income],
		[tr("RICHEST"), _richest],
		[tr("HAY SOLD"), _hay_sold],
		[tr("TAKINGS"), _takings],
		[tr("NEEDLES"), _needles],
	]


func _ready() -> void:
	_build()
	_refresh()


func _build() -> void:
	half = SIZE
	hang(WALL_X, BOARD_AT)
	write_title(tr(TITLE))


	var table:= _row_table()
	var span:= half.x * 2.0 - MARGIN * 2.0
	var label_w:= span * LABEL_COL
	var value_w:= span - label_w
	for i in table.size():
		var y:= ROW_TOP - float(i) * ROW_PITCH
		var label:= write("Label%d" % i, H_LABEL, COL_LABEL,
			Vector2(- half.x + MARGIN + label_w * 0.5, y), label_w,
			HORIZONTAL_ALIGNMENT_LEFT, false)
		label.text = str(table [i] [0])
		_rows.append(write("Value%d" % i, H_VALUE, COL_CHALK,
			Vector2(half.x - MARGIN - value_w * 0.5, y), value_w,
			HORIZONTAL_ALIGNMENT_RIGHT, true))
	_last.resize(table.size())

	_foot = write("Foot", H_FOOT, COL_FOOT, Vector2(0.0, - half.y + 0.068),
		half.x * 2.0 - MARGIN * 2.0, HORIZONTAL_ALIGNMENT_CENTER, false)


func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = TICK
	_refresh()


func _refresh() -> void:
	var table:= _row_table()
	for i in mini(_rows.size(), table.size()):
		var v: Callable = table [i] [1]
		var text:= str(v.call())
		if text == _last [i]:
			continue
		_last [i] = text
		_rows [i].text = text
	if _foot == null:
		return
	var foot:= _career_line()
	if foot != _last_foot:
		_last_foot = foot
		_foot.text = foot


func row_count() -> int:
	return _rows.size()


func row_label(i: int) -> String:
	var l:= get_node_or_null("Face/Label%d" % i) as Label3D
	return l.text if l != null else ""


func row_value(i: int) -> String:
	return _rows [i].text if i >= 0 and i < _rows.size() else ""


func footer_text() -> String:
	return _foot.text if _foot != null else ""


func refresh_now() -> void:
	_clock = TICK
	_refresh()


func _best_sale() -> String:
	if GameState.best_sale <= 0.0:
		return tr(UNSET)
	return "$%s  (%s)" % [Hud.money_text(GameState.best_sale),
		Hud.fmt(GameState.best_sale_strands)]


func _best_income() -> String:
	if GameState.best_income <= 0.0:
		return tr(UNSET)
	return tr("$%s /min") % Hud.money_text(GameState.best_income)


func _richest() -> String:
	return "$%s" % Hud.money_text(maxf(GameState.money_peak, GameState.money))


func _hay_sold() -> String:
	return Hud.fmt(GameState.hay_sold)


func _takings() -> String:
	return "$%s" % Hud.money_text(GameState.money_earned)


func _needles() -> String:
	var seen:= 0
	for t in NeedleTypes.count():
		if GameState.is_discovered(t):
			seen += 1


	return tr("%d  (%d of %d)") % [GameState.needles_found, seen, NeedleTypes.count()]


func _career_line() -> String:
	var hours:= Profile.play_secs / 3600
	var mins:= (Profile.play_secs % 3600) / 60

	return tr("ALL YARDS   $%s earned   %dh %02dm played") % [Hud.money_text(Profile.money_earned), hours, mins]
