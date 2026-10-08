class_name ArmPanel
extends Control


const PANEL_W:= 480.0

const PAD:= 18.0

const RULE:= 3.0


const COL_W:= PANEL_W - PAD * 2.0 - RULE * 2.0
const COL_GAP:= 30.0
const CARD_W:= COL_W * 2.0 + COL_GAP + PAD * 2.0 + RULE * 2.0


static var COL_PAPER:= Color(0.94, 0.93, 0.9)
static var COL_INK:= Color(0.07, 0.07, 0.08)
static var COL_INK_SOFT:= Color(0.36, 0.36, 0.38)


static var COL_HOVER:= Color(0.87, 0.86, 0.82)


static var COL_WARN:= Color(0.7, 0.12, 0.08)

static var COL_WAIT:= Color(0.6, 0.38, 0.02)

static var COL_GO:= Color(0.08, 0.46, 0.16)

static var COL_LOCKED:= Color(0.55, 0.55, 0.56)


static var COL_TAKE_INK:= Color(0.82, 0.36, 0.0)
static var COL_PUT_INK:= Color(0.08, 0.4, 0.84)

static var COL_NEW:= Color(0.9, 0.42, 0.04)


static var COL_STRIP:= Color(0.905, 0.89, 0.847)


static var COL_TILE:= Color(0.97, 0.96, 0.94)
static var COL_TILE_EDGE:= Color(0.79, 0.77, 0.73)

static var COL_TILE_ON:= Color(0.886, 0.867, 0.812)


static var COL_EDGE:= Color(0.09, 0.09, 0.1)


const LIGHT:= {
	"COL_PAPER": Color(0.94, 0.93, 0.9),
	"COL_INK": Color(0.07, 0.07, 0.08),
	"COL_INK_SOFT": Color(0.36, 0.36, 0.38),
	"COL_HOVER": Color(0.87, 0.86, 0.82),
	"COL_WARN": Color(0.7, 0.12, 0.08),
	"COL_WAIT": Color(0.6, 0.38, 0.02),
	"COL_GO": Color(0.08, 0.46, 0.16),
	"COL_LOCKED": Color(0.55, 0.55, 0.56),
	"COL_TAKE_INK": Color(0.82, 0.36, 0.0),
	"COL_PUT_INK": Color(0.08, 0.4, 0.84),
	"COL_NEW": Color(0.9, 0.42, 0.04),
	"COL_STRIP": Color(0.905, 0.89, 0.847),
	"COL_TILE": Color(0.97, 0.96, 0.94),
	"COL_TILE_EDGE": Color(0.79, 0.77, 0.73),
	"COL_TILE_ON": Color(0.886, 0.867, 0.812),
	"COL_EDGE": Color(0.09, 0.09, 0.1),
}


const DARK:= {
	"COL_PAPER": Color(0.165, 0.16, 0.15),
	"COL_INK": Color(0.93, 0.91, 0.86),
	"COL_INK_SOFT": Color(0.68, 0.66, 0.62),
	"COL_HOVER": Color(0.245, 0.235, 0.22),
	"COL_WARN": Color(0.96, 0.45, 0.38),
	"COL_WAIT": Color(0.94, 0.7, 0.3),
	"COL_GO": Color(0.48, 0.84, 0.48),
	"COL_LOCKED": Color(0.46, 0.45, 0.43),
	"COL_TAKE_INK": Color(0.98, 0.58, 0.22),
	"COL_PUT_INK": Color(0.46, 0.67, 1.0),
	"COL_NEW": Color(0.91, 0.43, 0.05),
	"COL_STRIP": Color(0.205, 0.198, 0.186),
	"COL_TILE": Color(0.195, 0.19, 0.18),
	"COL_TILE_EDGE": Color(0.36, 0.35, 0.33),
	"COL_TILE_ON": Color(0.29, 0.28, 0.26),
	"COL_EDGE": Color(0.64, 0.59, 0.48),
}


static var dark:= false

static var _mode_read:= false


static func set_dark(on: bool) -> void:
	_mode_read = true
	dark = on
	var set: Dictionary = DARK if on else LIGHT
	COL_PAPER = set ["COL_PAPER"]
	COL_INK = set ["COL_INK"]
	COL_INK_SOFT = set ["COL_INK_SOFT"]
	COL_HOVER = set ["COL_HOVER"]
	COL_WARN = set ["COL_WARN"]
	COL_WAIT = set ["COL_WAIT"]
	COL_GO = set ["COL_GO"]
	COL_LOCKED = set ["COL_LOCKED"]
	COL_TAKE_INK = set ["COL_TAKE_INK"]
	COL_PUT_INK = set ["COL_PUT_INK"]
	COL_NEW = set ["COL_NEW"]
	COL_STRIP = set ["COL_STRIP"]
	COL_TILE = set ["COL_TILE"]
	COL_TILE_EDGE = set ["COL_TILE_EDGE"]
	COL_TILE_ON = set ["COL_TILE_ON"]
	COL_EDGE = set ["COL_EDGE"]


static func ensure_mode() -> void:
	if not _mode_read:
		set_dark(mode_of(SCOPE_PLATES))


const SCOPE_PLATES:= "plates"
const SCOPE_SHOP:= "shop"


static func mode_of(scope: String) -> bool:
	var args:= OS.get_cmdline_user_args()
	if scope == SCOPE_SHOP:
		return Cfg.shop_dark and not "--shoplight" in args
	return Cfg.plate_dark or "--platedark" in args


static func push_palette(on: bool) -> bool:
	ensure_mode()
	var was:= dark
	if on != dark:
		set_dark(on)
	return was


static func pop_palette(was: bool) -> void:
	if was != dark:
		set_dark(was)


const TILE_GAP:= 6
const TILE_ICON:= 46.0


const NEW_KEYS:= { 2: ["arm_new_links", "arm_new_overflow"], 3: ["arm_new_order"] }


const RADIUS:= 0


const ROW_H:= 30.0


const REFRESH:= 0.25

const EXPLAIN_KEY:= "arm_plate"

const PILE_ICON:= "res://assets/ui/icons/arm_pile.png"

var player: Player

var _arm: RoboticArm
var _open:= false
var _panel: PanelContainer

var _badge: Label
var _state_word: Label
var _state_line: Label

var _explain: Label

var _power: Label

var _power_chip: Control
var _power_word: Label

var _state_sign: TextureRect

var _belts: Label

var _links_locked: Control


var _links_box: VBoxContainer

var _links_key:= ""
var _choose_btn: Button

var _reset_btn: Button

var _choose_row: Control

var _order_step: Control
var _order_box: VBoxContainer
var _order_locked: Control


var _order_rows: Dictionary = { }
var _order_dots: Dictionary = { }
var _order_whys: Dictionary = { }


var _order_why: Label

var _headings: Dictionary = { }
var _stamps: Dictionary = { }


var _boxes: Dictionary = { }


var _ticks: Dictionary = { }

var _switch: PowerToggle

var _radius_btn: Button

var _upgrade_btn: Button

var _upgrade_why: Label
var _timer:= 0.0

var _refit:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return _open


func arm() -> RoboticArm:
	return _arm


func open(from: RoboticArm) -> void:
	if from == null:
		return
	if is_instance_valid(_arm) and _arm != from:
		_arm.show_plate(false)
	_arm = from


	_arm.show_plate(true)
	_links_key = ""
	_write_explainer()
	_refresh()
	_write_new()


	_panel.modulate.a = 0.0
	_timer = 0.0
	_set_open(true)


func close() -> void:
	_set_open(false)


func _set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	set_process(on)
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if not on:
		if is_instance_valid(_arm):
			_arm.show_plate(false)
		_arm = null


func _process(delta: float) -> void:
	if not _open:
		return


	if _refit:
		_refit = false
		_fit()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_write_live()
	_panel.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _on_tick(on: bool, bit: int) -> void:
	if is_instance_valid(_arm):
		_arm.set_accepting(bit, on)
	_refresh()


func _on_all(on: bool) -> void:
	if is_instance_valid(_arm):
		for kind: Dictionary in RoboticArm.PICK_KINDS:
			_arm.set_accepting(int(kind ["bit"]), on)
	_refresh()


func _on_switch() -> void:
	if is_instance_valid(_arm):
		_arm.set_switched_off(not _arm.is_switched_off())
	_refresh()


func _on_radius() -> void:
	if is_instance_valid(_arm):
		_arm.toggle_radius()
	_write_radius()


func _on_upgrade() -> void:
	if is_instance_valid(_arm) and _arm.upgrade():
		Audio.play("tech_buy")
	_refresh()


func _refresh() -> void:
	if _state_word == null or not is_instance_valid(_arm):
		return
	_refit = true
	_switch.set_running(not _arm.is_switched_off())
	for bit: int in _boxes:
		var on:= _arm.accepts(bit)
		(_boxes [bit] as Button).set_pressed_no_signal(on)
		(_ticks [bit] as TileMark).set_on(on)
	_badge.text = _badge_name(int(_arm.tier_index))
	_write_live()


func _write_live() -> void:
	if not is_instance_valid(_arm):
		return
	_write_status()
	_write_belts()
	_write_order()
	_write_upgrade()
	_write_radius()
	_write_power()
	_fit()


func _write_status() -> void:
	var watch: MachineWatch = _arm.builds.watch if _arm.builds != null else null
	var sign_up:= watch != null and watch.alert_reason(_arm) != ""
	var status:= _arm.plate_status(sign_up)
	write_state(_state_word, _state_sign, int(status [0]))
	_state_line.text = str(status [1])
	write_power_chip(_power_chip, _power_word,
		MachinePower.power_share_for(_arm, player))


static func write_power_chip(chip: Control, word: Label, share: float) -> void:
	chip.visible = share < 0.999
	if chip.visible:
		word.text = Cfg.tr("LOW POWER  ·  %d%%") % int(round(share * 100.0))


func _write_belts() -> void:
	var on:= RoboticArm.links_unlocked()
	(_headings [2] as Label).text = tr("WHERE IT TAKES AND PUTS") if on else tr("WHERE IT PUTS IT")
	_belts.visible = not on
	_links_locked.visible = not on
	_links_box.visible = on
	_choose_row.visible = on
	if on:
		_write_links()
		_reset_btn.visible = not _arm.links().is_empty()
		return
	var n:= _arm.belts_in_reach()
	if n == 0:
		_belts.text = tr("Any belt in its radius. There is none yet, so lay one beside it.")
	elif n == 1:
		_belts.text = tr("Any belt in its radius. 1 belt right now.")
	else:
		_belts.text = tr_n("Any belt in its radius. %d belt right now, taking turns.",
			"Any belt in its radius. %d belts right now, taking turns.", n) % n


func _write_links() -> void:
	var links:= _arm.links()
	var overflow:= Tech.overflow_arm_unlocked()
	var key:= "o" if overflow else ""
	for link: Dictionary in links:
		key += "%d %s %s;" % [int(link ["role"]), str(link ["at"]), link.get("stuck", false)]
	var puts:= 0
	for link: Dictionary in links:
		if int(link ["role"]) == RoboticArm.LINK_PUT:
			puts += 1

	if puts == 0:
		key += "n%d" % _arm.belts_in_reach()
	if key == _links_key:
		return
	_links_key = key


	for child in _links_box.get_children():
		_links_box.remove_child(child)
		child.queue_free()
	var takes:= 0
	for link: Dictionary in links:
		if int(link ["role"]) == RoboticArm.LINK_TAKE:
			takes += 1
			_links_box.add_child(_link_row(RoboticArm.LINK_TAKE, link))


			if overflow:
				_links_box.add_child(_stuck_row(_arm._link_run(link)))
	if takes == 0:
		_links_box.add_child(_link_row(RoboticArm.LINK_TAKE, { },
			tr("Anything it picks up in its radius.")))

	if not overflow:
		_links_box.add_child(_locked_line(
			tr("Only when this belt is stuck unlocks with Overflow Arm on the tech tree.")))
	for link: Dictionary in links:
		if int(link ["role"]) == RoboticArm.LINK_PUT:
			_links_box.add_child(_link_row(RoboticArm.LINK_PUT, link))
	if puts == 0:
		var n:= _arm.belts_in_reach()
		_links_box.add_child(_link_row(RoboticArm.LINK_PUT, { },
			tr("Any belt in its radius. %d right now.") % n))


func _stuck_row(run: BeltPath) -> Control:
	var on:= _arm.takes_when_stuck(run)
	var row:= Button.new()
	row.toggle_mode = true
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	row.tooltip_text = tr("Leave it alone while it moves. Help out when it jams.")
	row.set_pressed_no_signal(on)
	for state: String in ["normal", "pressed", "focus", "disabled"]:
		row.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var hover:= StyleBoxFlat.new()
	hover.bg_color = COL_HOVER
	hover.set_corner_radius_all(RADIUS)
	for state: String in ["hover", "hover_pressed"]:
		row.add_theme_stylebox_override(state, hover)
	row.toggled.connect(_on_stuck.bind(run))
	var line:= HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder:= _holder(row, line)
	var indent:= Control.new()
	indent.custom_minimum_size.x = 26.0
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(indent)
	var tick:= TickBox.new()
	tick.ink = COL_INK
	tick.dim = COL_INK_SOFT
	tick.ground = COL_PAPER
	tick.set_on(on)
	line.add_child(tick)
	var head:= _label(tr("Only when this belt is stuck"), 14, COL_INK if on else COL_INK_SOFT,
		true)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


	head.custom_minimum_size.x = COL_W - 70.0
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(head)
	return holder


func _on_stuck(on: bool, run: Variant) -> void:
	if is_instance_valid(_arm) and run != null and is_instance_valid(run):
		_arm.set_take_when_stuck(run as BeltPath, on)
	_refresh()


func _link_row(role: int, link: Dictionary, none: String = "") -> Control:
	var ink:= COL_TAKE_INK if role == RoboticArm.LINK_TAKE else COL_PUT_INK
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = ROW_H
	row.add_child(letter_badge("" if link.is_empty() else _arm.link_letter(link), ink))
	row.add_child(PlateIcons.rect("take" if role == RoboticArm.LINK_TAKE else "put", 20, ink))
	var word:= _label(tr("TAKE FROM") if role == RoboticArm.LINK_TAKE else tr("PUT ON"),
		15, ink, true)
	word.custom_minimum_size.x = 96.0
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(word)
	var what:= _label("", 15, COL_INK if not link.is_empty() else COL_INK_SOFT)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


	what.custom_minimum_size.x = 150.0
	row.add_child(what)
	if link.is_empty():
		what.text = none
		return row
	var at: Vector3 = link ["at"]
	var flat:= Vector2(at.x - _arm.global_position.x, at.z - _arm.global_position.z)
	what.text = tr("Belt, %.1f m away") % flat.length()
	var run: Variant = link.get("run")
	var cross:= _link("×", _on_unlink.bind(run))
	cross.add_theme_font_size_override("font_size", 20)
	cross.underline = LinkButton.UNDERLINE_MODE_NEVER
	cross.tooltip_text = tr("Unlink this belt")
	row.add_child(cross)
	return row


func _on_choose() -> void:
	var target:= _arm
	close()
	if player != null and player.arm_links != null and is_instance_valid(target):
		player.arm_links.begin(target)


func _on_reset() -> void:
	if is_instance_valid(_arm):
		_arm.unlink_all()
		Audio.play("ui_click")
	_refresh()


func _on_unlink(run: Variant) -> void:
	if is_instance_valid(_arm) and run != null and is_instance_valid(run):
		_arm.unlink(run as BeltPath)
	_refresh()


func _write_new() -> void:
	for number: int in _stamps:
		var show:= false
		for id: String in NEW_KEYS.get(number, []):
			if _feature_unlocked(id) and not Cfg.machine_seen(id):
				show = true
				Cfg.see_machine(id)
		(_stamps [number] as Control).visible = show


func _feature_unlocked(id: String) -> bool:
	match id:
		"arm_new_links":
			return RoboticArm.links_unlocked()
		"arm_new_overflow":
			return Tech.overflow_arm_unlocked()
		"arm_new_order":
			return Tech.pick_order_unlocked()
	return false


func _write_order() -> void:
	var on:= Tech.pick_order_unlocked()
	var next:= not on and RoboticArm.links_unlocked() and Tech.overflow_arm_unlocked()
	_order_step.visible = on or next
	_order_box.visible = on
	_order_locked.visible = next
	if not on:
		return
	var chosen:= _arm.pick_order_now()
	for order: int in _order_rows:
		(_order_rows [order] as Button).set_pressed_no_signal(order == chosen)
		(_order_dots [order] as TileMark).set_on(order == chosen)
	if _order_matters():
		_order_why.text = str(_order_whys.get(chosen, ""))
		_order_why.add_theme_color_override("font_color", COL_INK_SOFT)
	else:
		_order_why.text = tr("Nothing to choose right now. This only matters when it picks up loose hay and bigger things off the floor.")
		_order_why.add_theme_color_override("font_color", COL_WAIT)


func _order_matters() -> bool:
	if _arm._takes_from_belts() or not _arm.accepts(RoboticArm.PICK_LOOSE):
		return false
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		var bit:= int(kind ["bit"])
		if bit in [RoboticArm.PICK_NEEDLE, RoboticArm.PICK_LOOSE, RoboticArm.PICK_PILE]:
			continue
		if _arm.accepts(bit):
			return true
	return false


func _order_row(order: int, answer: String, why: String) -> Control:


	var pic: Texture2D = PlateIcons.texture("closest", 30)
	var tint:= COL_INK
	if order == RoboticArm.ORDER_LOOSE:
		pic = kind_icon("loose")
		tint = Color.WHITE
	elif order == RoboticArm.ORDER_BIG:
		pic = kind_icon("bale")
		tint = Color.WHITE
	var t:= tile(pic, answer, _tile_w(3), false, "", 30.0, tint)
	var row: Button = t ["button"]
	row.tooltip_text = why
	row.pressed.connect(_on_order.bind(order))
	_order_rows [order] = row
	_order_dots [order] = t ["mark"]
	_order_whys [order] = why
	return t ["holder"]


func _holder(button: Button, content: Control) -> Control:
	var holder:= MarginContainer.new()
	holder.add_child(button)
	holder.add_child(content)
	return holder


func _on_order(order: int) -> void:
	if is_instance_valid(_arm):
		_arm.set_pick_order(order)
	_refresh()


func _write_upgrade() -> void:
	var price:= _arm.upgrade_price()
	var block:= _arm.upgrade_block()
	_upgrade_why.visible = false
	if price < 0.0:
		_upgrade_btn.text = tr("BIGGEST MODEL")
		_upgrade_btn.icon = PlateIcons.texture("upgrade", 20)
		_upgrade_btn.disabled = true
		_ink_refused(false)
		return
	_upgrade_btn.disabled = block != ""
	_ink_refused(block != "")
	var why:= _arm.upgrade_detail() if block != "" else ""
	_upgrade_why.text = why
	_upgrade_why.visible = why != ""
	_upgrade_btn.icon = PlateIcons.texture("lock" if block != "" else "upgrade", 20)
	if block != "":
		_upgrade_btn.text = tr("Can't upgrade: %s.") % block
		return


	_upgrade_btn.text = tr("UPGRADE TO %s  ·  $%s") % [
		_badge_name(int(_arm.tier_index) + 1), Hud.fmt(price)]


func _ink_refused(refused: bool) -> void:
	var ink:= COL_WARN if refused else COL_LOCKED
	_upgrade_btn.add_theme_color_override("font_disabled_color", ink)
	_upgrade_btn.add_theme_color_override("icon_disabled_color", ink)
	var sb:= _upgrade_btn.get_theme_stylebox("disabled") as StyleBoxFlat
	if sb != null:
		sb.border_color = ink


func _write_radius() -> void:
	if _radius_btn == null or not is_instance_valid(_arm):
		return
	var on:= _arm.radius_shown()
	if on:
		var left:= int(ceil(_arm.radius_seconds_left()))
		_radius_btn.text = tr("HIDE RADIUS  ·  %d:%02d") % [left / 60, left % 60]
	else:
		_radius_btn.text = tr("SHOW RADIUS")
	_radius_btn.icon = PlateIcons.texture("eye_off" if on else "eye", 20)
	light_button(_radius_btn, on)


static func light_button(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb:= b.get_theme_stylebox(state) as StyleBoxFlat
		if sb == null:
			continue
		if on:
			sb.bg_color = COL_TILE_ON
		else:
			sb.bg_color = COL_HOVER if state == "hover" else COL_PAPER
		sb.set_border_width_all(3 if on else 2)


func _write_power() -> void:
	if _power == null:
		return
	_power.text = MachinePower.rating_line_for(_arm, player)
	_power.visible = _power.text != ""


func _write_explainer() -> void:
	_explain.visible = Cfg.teach_hints and not Cfg.machine_seen(EXPLAIN_KEY)
	if _explain.visible:
		Cfg.see_machine(EXPLAIN_KEY)


func _fit() -> void:
	if _panel == null:
		return
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _badge_name(tier: int) -> String:
	if tier < 0 or tier >= Cfg.ROBOT_ARM_TIERS.size():
		return ""
	match str(Cfg.ROBOT_ARM_TIERS [tier].get("id", "")):
		"arm_small":
			return tr("SMALL")
		"arm_standard":
			return tr("STANDARD")
		"arm_long":
			return tr("LONG-REACH")
	return tr(str(Cfg.ROBOT_ARM_TIERS [tier].get("name", "")))


static func kind_icon(id: String) -> Texture2D:
	match id:
		"needle":
			return TechPanel.icon_for("needle")
		"pile":
			return _tight(load(PILE_ICON) as Texture2D)
		"loose", "disc":


			return _tight(SplitterPanel._item_icon(BeltRun.ITEM_IDS.find(
				"hay_tuft" if id == "loose" else "feed_disc")))
	var item:= ""
	match id:
		"loose":
			item = "hay_tuft"
		"wad":
			item = "hay_wad"
		"bale":
			item = "hay_bale"
		"brick":
			item = "eco_brick"
		"foiled":
			item = "foiled_bale"
		"pulp":
			item = "hay_pulp"
		"roll":
			item = "paper_roll"
		"disc":
			item = "feed_disc"
	var index:= BeltRun.ITEM_IDS.find(item)
	return SplitterPanel._item_icon(index) if index >= 0 else null


static var _tight_cache: Dictionary = { }


static func _tight(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _tight_cache.has(tex):
		return _tight_cache [tex]
	var img:= tex.get_image()
	if img == null or img.is_empty():
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	var used:= img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return tex
	var side:= int(ceil(maxf(used.size.x, used.size.y) * 1.08))
	var square:= Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	square.blit_rect(img, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
	square.generate_mipmaps()
	var out:= ImageTexture.create_from_image(square)
	_tight_cache [tex] = out
	return out


func _build() -> void:
	_panel = _card()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var whole:= VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	_panel.add_child(whole)
	_switch = PowerToggle.new()
	_switch.pressed.connect(_on_switch)
	whole.add_child(_band(tr("ROBOTIC ARM"),
		tr("%s or ESC to close") % InputSetup.hint("interact"), close))
	whole.add_child(_rule())
	whole.add_child(_status_strip())
	whole.add_child(_rule())
	var cols:= _inset(whole)
	var col:= _column(cols)
	cols.add_child(_column_rule())
	var right:= _column(cols)

	_explain = _body_label()
	_explain.text = tr("It lifts what you tick inside its radius onto a nearby belt.")
	_explain.add_theme_color_override("font_color", COL_INK)
	_explain.add_theme_font_size_override("font_size", 14)
	col.add_child(_explain)

	col.add_child(_step(1, tr("WHAT IT PICKS UP"), true, "picks"))
	var grid:= GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	col.add_child(grid)
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		grid.add_child(_kind_cell(kind))


	right.add_child(_step(2, tr("WHERE IT PUTS IT"), false, "route"))
	_belts = _body_label()
	_belts.add_theme_color_override("font_color", COL_INK)
	right.add_child(_belts)
	_links_locked = _locked_line(
		tr("Choosing belts unlocks with Belt Links on the tech tree."))
	right.add_child(_links_locked)
	_links_box = VBoxContainer.new()
	_links_box.add_theme_constant_override("separation", 2)
	right.add_child(_links_box)
	var choose_row:= HBoxContainer.new()
	choose_row.add_theme_constant_override("separation", 8)
	_choose_row = choose_row
	right.add_child(choose_row)
	_choose_btn = _plate_button(_on_choose)
	_choose_btn.text = tr("CHOOSE BELTS")
	PlateIcons.on_button(_choose_btn, "link", 20, COL_INK, COL_LOCKED)
	choose_row.add_child(_choose_btn)
	_reset_btn = _plate_button(_on_reset)
	_reset_btn.text = tr("RESET")
	_reset_btn.tooltip_text = tr("Unlink every belt. It goes back to any belt in its radius.")
	_reset_btn.size_flags_horizontal = Control.SIZE_FILL
	_reset_btn.custom_minimum_size.x = 130.0
	PlateIcons.on_button(_reset_btn, "reset", 20, COL_INK, COL_LOCKED)
	choose_row.add_child(_reset_btn)


	_order_step = _step(3, tr("WHAT SHOULD IT GRAB FIRST?"), false, "order")
	right.add_child(_order_step)
	_order_box = VBoxContainer.new()
	_order_box.add_theme_constant_override("separation", 6)
	right.add_child(_order_box)
	var answers:= HBoxContainer.new()
	answers.add_theme_constant_override("separation", TILE_GAP)
	_order_box.add_child(answers)
	for answer: Array in [
		[RoboticArm.ORDER_LOOSE, tr("Loose hay first"),
			tr("Keeps the floor tidy. Wads and bales wait until the loose hay is gone.")],
		[RoboticArm.ORDER_BIG, tr("Big things first"),
			tr("Bales and wads before loose hay, the biggest first. More hay in every swing.")],
		[RoboticArm.ORDER_CLOSEST, tr("Whatever is closest"),
			tr("Less swinging, so more loads a minute. The pile still comes last.")],
	]:
		answers.add_child(_order_row(int(answer [0]), str(answer [1]), str(answer [2])))
	_order_why = _body_label()
	_order_why.add_theme_font_size_override("font_size", 14)
	_order_box.add_child(_order_why)
	var needles:= _label(tr("Needles always come first, whatever you pick."), 13, COL_INK_SOFT)
	_order_box.add_child(needles)
	_order_locked = _locked_line(
		tr("Choosing what it grabs first unlocks with Pick Order on the tech tree."))
	right.add_child(_order_locked)


	whole.add_child(_rule())
	var foot:= _foot(whole)
	_radius_btn = _plate_button(_on_radius)
	PlateIcons.on_button(_radius_btn, "eye", 20, COL_INK, COL_LOCKED)
	_radius_btn.custom_minimum_size.x = 220.0
	_radius_btn.size_flags_horizontal = Control.SIZE_FILL
	_radius_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	foot.add_child(_radius_btn)
	_power = _label("", 13, COL_INK_SOFT)
	_power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power.custom_minimum_size.y = MachineSwitch.HEIGHT
	_power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_power)
	var upgrade:= VBoxContainer.new()
	upgrade.custom_minimum_size.x = 340.0
	upgrade.add_theme_constant_override("separation", 2)
	foot.add_child(upgrade)
	_upgrade_btn = _plate_button(_on_upgrade)
	PlateIcons.on_button(_upgrade_btn, "upgrade", 20, COL_INK, COL_LOCKED)
	_upgrade_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade.add_child(_upgrade_btn)
	_upgrade_why = _label("", 12, COL_WARN)
	_upgrade_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_why.custom_minimum_size.x = 340.0
	_upgrade_why.visible = false
	upgrade.add_child(_upgrade_why)


func _card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0.0)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_PAPER
	sb.border_color = COL_EDGE
	sb.set_border_width_all(int(RULE))
	sb.set_corner_radius_all(RADIUS)


	sb.set_content_margin_all(RULE)
	card.add_theme_stylebox_override("panel", sb)
	return card


func _band(title: String, aside: String, closer: Callable) -> Control:
	var parts:= band(title, aside, closer, _switch, true, "arm")
	_badge = parts [1]
	return parts [0]


static func band(title: String, aside: String, closer: Callable,
		toggle: Control, badged: bool, tile: String = "",
		scope: String = SCOPE_PLATES) -> Array:
	ensure_mode()
	var strip:= PanelContainer.new()
	strip.add_theme_stylebox_override("panel", box(COL_PAPER, PAD, 8.0))
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	strip.add_child(row)


	var pic:= PlateKit.photo(tile) if tile != "" else null
	if pic != null:
		row.add_child(pic)
	var name_label:= label(title, 21, COL_INK, true)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var badge: Label = null
	if badged:
		var chip:= PanelContainer.new()
		var edge:= box(COL_PAPER, 7.0, 1.0)
		edge.border_color = COL_INK
		edge.set_border_width_all(2)
		chip.add_theme_stylebox_override("panel", edge)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge = label("", 13, COL_INK, true)
		chip.add_child(badge)
		row.add_child(chip)
	var fill:= Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	var small:= label(aside, 12, COL_INK_SOFT)
	small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(small)


	row.add_child(MoonToggle.new(scope))
	if toggle != null:
		row.add_child(toggle)


	if closer.is_valid():
		row.add_child(PanelClose.make(closer, COL_PAPER))
	return [strip, badge, name_label, pic]


func _status_strip() -> Control:
	var parts:= status_strip()
	_state_word = parts [1]
	_state_line = parts [2]
	_power_chip = parts [3]
	_power_word = parts [4]
	_state_sign = parts [5]
	return parts [0]


static func status_strip() -> Array:
	var strip:= PanelContainer.new()
	strip.add_theme_stylebox_override("panel", box(COL_STRIP, PAD, 10.0))
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	strip.add_child(row)
	var sign:= PlateIcons.rect("working", 22, COL_INK)
	sign.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(sign)
	var word:= label("", 18, COL_INK, true)
	word.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(word)
	var line:= label("", 15, COL_INK)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	var chip:= PanelContainer.new()
	var edge:= box(COL_STRIP, 8.0, 2.0)
	edge.border_color = COL_WAIT
	edge.set_border_width_all(2)
	chip.add_theme_stylebox_override("panel", edge)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.visible = false
	var inside:= HBoxContainer.new()
	inside.add_theme_constant_override("separation", 4)
	chip.add_child(inside)
	inside.add_child(PlateIcons.rect("bolt", 18, COL_WAIT))
	var chip_word:= label("", 14, COL_WAIT, true)
	inside.add_child(chip_word)
	row.add_child(chip)
	return [strip, word, line, chip, chip_word, sign]


static func write_state(word: Label, sign: TextureRect, state: int) -> void:
	var ink:= COL_WARN
	var drawing:= "stopped"
	match state:
		0:
			word.text = Cfg.tr("WORKING")
			ink = COL_GO
			drawing = "working"
		1:
			word.text = Cfg.tr("WAITING")
			ink = COL_WAIT
			drawing = "waiting"
		_:
			word.text = Cfg.tr("STOPPED")
	word.add_theme_color_override("font_color", ink)
	sign.texture = PlateIcons.texture(drawing, 22)
	sign.self_modulate = ink


func _foot(whole: VBoxContainer) -> HBoxContainer:
	return foot(whole)


static func foot(whole: VBoxContainer) -> HBoxContainer:
	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(PAD))
	inset.add_theme_constant_override("margin_right", int(PAD))
	inset.add_theme_constant_override("margin_top", int(PAD) - 6)
	inset.add_theme_constant_override("margin_bottom", int(PAD) - 6)
	whole.add_child(inset)
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	inset.add_child(row)
	return row


func _inset(whole: VBoxContainer) -> HBoxContainer:
	var inset:= MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(PAD))
	inset.add_theme_constant_override("margin_right", int(PAD))
	inset.add_theme_constant_override("margin_top", int(PAD) - 4)
	inset.add_theme_constant_override("margin_bottom", int(PAD))
	whole.add_child(inset)
	var cols:= HBoxContainer.new()
	cols.add_theme_constant_override("separation", int((COL_GAP - 2.0) * 0.5))
	inset.add_child(cols)
	return cols


func _column(cols: HBoxContainer) -> VBoxContainer:
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = COL_W
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col)
	return col


func _column_rule() -> Control:
	var line:= ColorRect.new()
	line.color = Color(COL_INK, 0.25)
	line.custom_minimum_size = Vector2(2.0, 0.0)
	return line


func _step(number: int, title: String, links: bool, icon: String = "") -> Control:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(PlateIcons.rect(icon, 22, COL_INK))
	var heading:= _label(title, 16, COL_INK, true)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)
	_headings [number] = heading


	var stamp:= PanelContainer.new()
	stamp.add_theme_stylebox_override("panel", _box(COL_NEW, 6.0, 1.0))
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stamp.add_child(_label(tr("NEW"), 12, COL_PAPER, true))
	stamp.visible = false
	row.add_child(stamp)
	_stamps [number] = stamp
	var fill:= Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	if links:
		row.add_child(_link(tr("All"), _on_all.bind(true)))
		row.add_child(_link(tr("None"), _on_all.bind(false)))


	var gap:= MarginContainer.new()
	gap.add_theme_constant_override("margin_top", 6)
	gap.add_child(row)
	return gap


static func letter_badge(letter: String, ink: Color, solid: bool = false,
		icon: String = "") -> Control:
	var square:= PanelContainer.new()
	var filled:= solid or letter != ""
	var ground:= box(ink if filled else COL_PAPER, 0.0, 0.0)
	if not filled:
		ground.border_color = ink
		ground.set_border_width_all(2)
	square.add_theme_stylebox_override("panel", ground)
	square.custom_minimum_size = Vector2(26.0, 26.0)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon != "":
		square.add_child(PlateIcons.rect(icon, 18, COL_PAPER if filled else ink))
		return square
	var mark:= label(letter, 15, COL_PAPER, true)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	square.add_child(mark)
	return square


func _link(text: String, on_pressed: Callable) -> LinkButton:
	var l:= LinkButton.new()
	l.text = text
	l.focus_mode = Control.FOCUS_NONE
	l.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_override("font", UiFont.bold())
	l.add_theme_font_size_override("font_size", 14)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		l.add_theme_color_override(state, COL_INK if state != "font_hover_color" else COL_INK_SOFT)
	l.pressed.connect(on_pressed)
	return l


func _locked_line(text: String) -> Control:
	var box:= DashedBox.new()
	box.ink = COL_LOCKED
	var l:= _body_label()
	l.custom_minimum_size.x -= 20.0
	l.text = text
	l.add_theme_color_override("font_color", COL_LOCKED)
	l.add_theme_font_size_override("font_size", 14)
	box.add_child(l)
	return box


func _plate_button(on_pressed: Callable) -> Button:
	var b:= Button.new()
	b.custom_minimum_size = Vector2(0.0, MachineSwitch.HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFont.bold())
	b.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(RADIUS)
		sb.set_border_width_all(2)
		sb.border_color = COL_LOCKED if state == "disabled" else COL_INK
		sb.bg_color = COL_HOVER if state == "hover" else COL_PAPER
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		b.add_theme_stylebox_override(state, sb)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		b.add_theme_color_override(colour, COL_INK)
	b.add_theme_color_override("font_disabled_color", COL_LOCKED)
	b.pressed.connect(on_pressed)
	return b


func _box(ground: Color, side: float, top: float) -> StyleBoxFlat:
	return box(ground, side, top)


static func box(ground: Color, side: float, top: float) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = ground
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = side
	sb.content_margin_right = side
	sb.content_margin_top = top
	sb.content_margin_bottom = top
	return sb


func _rule() -> Control:
	var line:= ColorRect.new()
	line.color = COL_EDGE
	line.custom_minimum_size = Vector2(0.0, 2.0)
	return line


func _body_label() -> Label:
	var l:= _label("", 15, COL_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - RULE * 2.0, 0.0)
	return l


func _kind_cell(kind: Dictionary) -> Control:
	var bit:= int(kind ["bit"])
	var fixed:= RoboticArm.locked(bit)
	var t:= tile(kind_icon(str(kind ["id"])), tr(str(kind ["name"])), _tile_w(5),
		fixed, tr("always") if fixed else "")
	var row: Button = t ["button"]
	row.tooltip_text = tr(str(kind ["note"]))
	if fixed:


		row.disabled = true
		row.set_pressed_no_signal(true)
	row.toggled.connect(_on_tick.bind(bit))
	_boxes [bit] = row
	_ticks [bit] = t ["mark"]
	return t ["holder"]


static func _tile_w(across: int) -> float:
	return floorf((COL_W - float(TILE_GAP * (across - 1))) / float(across))


static func tile(icon: Texture2D, words: String, width: float, fixed: bool = false,
		aside: String = "", icon_px: float = TILE_ICON, tint: Color = Color.WHITE) -> Dictionary:
	var b:= Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	tile_styles(b)
	var holder:= MarginContainer.new()
	holder.custom_minimum_size.x = width
	holder.add_child(b)
	var pad:= MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_right", 4)
	pad.add_theme_constant_override("margin_top", 8 if icon != null else 7)
	pad.add_theme_constant_override("margin_bottom", 6 if icon != null else 7)
	holder.add_child(pad)
	var stack:= VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)


	stack.alignment = BoxContainer.ALIGNMENT_BEGIN if icon != null else BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(stack)
	if icon != null:
		var pic:= TextureRect.new()
		pic.texture = icon
		pic.custom_minimum_size = Vector2(icon_px, icon_px)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE


		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.self_modulate = tint
		if fixed:
			pic.modulate = Color(1, 1, 1, 0.6)
		stack.add_child(pic)
	var name_label:= label(words, 13 if icon != null else 14,
		COL_LOCKED if fixed else COL_INK, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = width - 8.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)
	if aside != "":
		var small:= label(aside, 12, COL_LOCKED)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(small)
	var mark:= TileMark.new()
	mark.ink = COL_LOCKED if fixed else COL_GO
	mark.set_on(fixed)


	mark.visible = icon != null and icon_px >= TILE_ICON
	holder.add_child(mark)
	return { "holder": holder, "button": b, "mark": mark }


static func tile_styles(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb:= StyleBoxFlat.new()
		sb.set_corner_radius_all(RADIUS)
		match state:
			"normal":
				sb.bg_color = COL_TILE
				sb.border_color = COL_TILE_EDGE
				sb.set_border_width_all(1)
			"hover":
				sb.bg_color = COL_TILE
				sb.border_color = COL_INK
				sb.set_border_width_all(2)
			"pressed", "hover_pressed":
				sb.bg_color = COL_TILE_ON if state == "pressed" else COL_HOVER
				sb.border_color = COL_INK
				sb.set_border_width_all(3)
			"disabled":
				sb.bg_color = COL_TILE_ON
				sb.border_color = COL_LOCKED
				sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	return label(text, size, colour, heavy)


static func label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	UiFont.style(l, size, colour, 0, heavy)
	l.text = text
	return l


class TileMark extends Control:
	const SIZE:= 14.0
	const INSET:= 5.0
	const STROKE:= 3.0
	var on:= false
	var ink:= Color.BLACK

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(value: bool) -> void:
		if value == on:
			return
		on = value
		queue_redraw()

	func _draw() -> void:
		if not on:
			return
		var o:= Vector2(size.x - SIZE - INSET, INSET)
		draw_polyline(PackedVector2Array([
			o + Vector2(SIZE * 0.08, SIZE * 0.55),
			o + Vector2(SIZE * 0.38, SIZE * 0.85),
			o + Vector2(SIZE * 0.95, SIZE * 0.15),
		]), ink, STROKE, true)


class PowerToggle extends Button:
	const TRACK:= Vector2(42.0, 22.0)
	const EDGE:= 2.0
	var running:= true

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(100.0, 30.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)


	func set_running(value: bool, tip: String = "") -> void:
		running = value
		if tip != "":
			tooltip_text = tip
		else:
			tooltip_text = tr("TURN OFF") if running else tr("TURN ON")
		queue_redraw()


	func set_dead(value: bool) -> void:
		if disabled == value:
			return
		disabled = value
		mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_POINTING_HAND
		queue_redraw()

	func _draw() -> void:
		if is_hovered() and not disabled:
			draw_rect(Rect2(Vector2.ZERO, size), ArmPanel.COL_HOVER)
		var tint:= ArmPanel.COL_GO if running else ArmPanel.COL_WARN
		if disabled:
			tint = ArmPanel.COL_LOCKED
		var track:= Rect2(Vector2(size.x - TRACK.x - 4.0, (size.y - TRACK.y) * 0.5), TRACK)
		var font:= UiFont.bold()
		var fs:= 15
		var word:= tr("ON") if running else tr("OFF")
		var w:= font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base:= size.y * 0.5 + font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.5
		draw_string(font, Vector2(track.position.x - 8.0 - w, base), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)
		var knob:= TRACK.y - EDGE * 2.0 - 4.0
		if running:
			draw_rect(track, tint)
			draw_rect(Rect2(track.end - Vector2(knob + EDGE + 2.0, knob + EDGE + 2.0),
				Vector2(knob, knob)), ArmPanel.COL_PAPER)
		else:
			draw_rect(track.grow(- EDGE * 0.5), tint, false, EDGE)
			draw_rect(Rect2(track.position + Vector2(EDGE + 2.0, EDGE + 2.0),
				Vector2(knob, knob)), tint)


class DashedBox extends PanelContainer:
	const DASH:= 6.0
	const EDGE:= 2.0
	var ink:= Color.GRAY

	func _init() -> void:
		var sb:= StyleBoxEmpty.new()
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 7.0
		sb.content_margin_bottom = 7.0
		add_theme_stylebox_override("panel", sb)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r:= Rect2(Vector2.ONE * EDGE * 0.5, size - Vector2.ONE * EDGE)
		var corners:= [r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(corners [i], corners [(i + 1) % 4], ink, EDGE, DASH)


class TickBox extends Control:
	const SIZE:= 22.0


	const EDGE:= 2.0
	const STROKE:= 3.0

	var on:= false


	var ink:= Color.WHITE
	var dim:= Color.GRAY
	var ground:= Color.BLACK

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(value: bool) -> void:
		if value == on:
			return
		on = value
		queue_redraw()

	func _draw() -> void:
		var box:= Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
		if on:
			draw_rect(box, ink)
		else:


			draw_rect(box.grow(- EDGE * 0.5), dim, false, EDGE)
			return


		draw_polyline(PackedVector2Array([
			Vector2(SIZE * 0.24, SIZE * 0.52),
			Vector2(SIZE * 0.44, SIZE * 0.72),
			Vector2(SIZE * 0.77, SIZE * 0.28),
		]), ground, STROKE, true)


class MoonToggle extends Button:
	const SIDE:= 30.0
	var scope:= ArmPanel.SCOPE_PLATES

	func _init(which: String = ArmPanel.SCOPE_PLATES) -> void:
		scope = which
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(SIDE, SIDE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		pressed.connect(_flip)
		visibility_changed.connect(_on_shown)
		_write_tip()

	func is_dark() -> bool:
		return ArmPanel.mode_of(scope)

	func _flip() -> void:
		if scope == ArmPanel.SCOPE_SHOP:
			Cfg.set_shop_dark(not Cfg.shop_dark)
		else:
			ArmPanel.set_dark(not ArmPanel.dark)
			Cfg.set_plate_dark(ArmPanel.dark)
		_write_tip()
		PlateKit.sync(PlateKit.root_of(self), is_dark())

	func _on_shown() -> void:
		if is_visible_in_tree():
			_write_tip()
			PlateKit.sync(PlateKit.root_of(self), is_dark())

	func _write_tip() -> void:
		tooltip_text = tr("Light plates") if is_dark() else tr("Dark plates")
		queue_redraw()

	func _draw() -> void:
		var paper: Dictionary = ArmPanel.DARK if is_dark() else ArmPanel.LIGHT
		if is_hovered():
			draw_rect(Rect2(Vector2.ZERO, size), paper ["COL_HOVER"])
		var tex:= PlateIcons.texture("sun" if is_dark() else "moon", 20)
		if tex == null:
			return
		var at:= (size - Vector2(20.0, 20.0)) * 0.5
		draw_texture_rect(tex, Rect2(at, Vector2(20.0, 20.0)), false, paper ["COL_INK"])
