class_name ControlHints
extends HBoxContainer


const KEY_SIZE:= 17
const ACTION_SIZE:= 17


const ICON_H:= 30
const ICON_W:= 34


const HOLD_SIZE:= 13
const COL_KEY:= Color(0.94, 0.96, 1.0)
const COL_ACTION:= Color(1, 1, 1, 0.78)
const COL_INFO:= Color(0.86, 0.93, 0.72)


const COL_LIVE:= Color(1.0, 0.8, 0.68)
const COL_LIVE_EDGE:= Color(0.96, 0.44, 0.28, 0.95)


const COL_NEW:= Color(1.0, 0.86, 0.36)


const NEW_PULSE:= 3.2

var player: Player

var _signature:= ""
var _chip: StyleBoxFlat
var _chip_live: StyleBoxFlat
var _chip_art: StyleBoxFlat
var _chip_new: StyleBoxFlat


var _shown_actions:= PackedStringArray()

var _new_tags: Array [Label] = []


var _glowing:= false
var _pulse_t:= 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)


	offset_top = -60
	offset_bottom = -22
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 22)

	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(0, 0, 0, 0.55)
	_chip.border_color = Color(1, 1, 1, 0.2)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(0)
	_chip.content_margin_left = 7.0
	_chip.content_margin_right = 7.0
	_chip.content_margin_top = 3.0
	_chip.content_margin_bottom = 3.0

	_chip_live = _chip.duplicate()
	_chip_live.bg_color = Color(0.035, 0.045, 0.042, 0.82)
	_chip_live.border_color = COL_LIVE_EDGE
	_chip_live.set_border_width_all(2)


	_chip_art = _chip.duplicate()
	_chip_art.bg_color = Color(0, 0, 0, 0)
	_chip_art.border_color = Color(0, 0, 0, 0)
	_chip_art.set_border_width_all(0)
	_chip_art.content_margin_left = 2.0
	_chip_art.content_margin_right = 2.0


	_chip_new = _chip.duplicate()
	_chip_new.bg_color = Color(0.05, 0.045, 0.02, 0.7)
	_chip_new.border_color = COL_NEW
	_chip_new.set_border_width_all(2)


const REFRESH:= 0.1
var _refresh_left:= 0.0
var _refresh_due:= true
var _context:= 0


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		_refresh_due = true


func _context_key() -> int:
	if player == null:
		return 0
	var key:= 1 if player.is_mouse_captured() else 2
	key = key * 31 + int(player.current_tool)
	if player.carry != null:
		var held:= player.carry.held()
		var reach:= player.carry.target()
		key = key * 31 + (held.get_instance_id() if held != null else 0)
		key = key * 31 + (reach.get_instance_id() if reach != null else 0)
	return key


func _process(delta: float) -> void:
	_note_presses()
	_pulse_new(delta)
	_refresh_left -= delta
	var context:= _context_key()
	if not _refresh_due and _refresh_left > 0.0 and context == _context:
		return
	_refresh_due = false
	_refresh_left = REFRESH
	_context = context
	var hints:= _hints()
	var sig:= ""
	for h in hints:


		sig += "%s~%s/" % ["|".join(h), _words(h [0])]
	if sig == _signature:
		return
	_signature = sig
	_rebuild(hints)


func _blade_rows(out: Array, tool_node: Shovel, noun: String) -> void:
	if Cfg.simple_tools():
		out.append(PackedStringArray([_key("secondary"), tr("Empty it")]))
		out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))
		if tool_node != null:
			_load_row(out, tool_node.carried_strands(), tool_node.capacity(), noun)
		return
	out.append(PackedStringArray([_hold("secondary"), _aim_label(noun)]))
	out.append(PackedStringArray([_key("reset_view"), tr("Reset aim")]))
	out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))
	if tool_node != null:
		_load_row(out, tool_node.carried_strands(), 0, noun)


func _aim_label(noun: String) -> String:
	if noun == "fork":
		return tr("Aim fork")
	return tr("Aim spade")


func _load_row(out: Array, carried: int, cap: int, noun: String) -> void:
	var fork:= noun == "fork"
	if cap > 0 and carried >= cap:
		out.append(PackedStringArray(["",
			(tr("fork full, %d") if fork else tr("spade full, %d")) % carried]))
	elif carried > 0 and cap > 0:
		out.append(PackedStringArray(["",
			(tr("%d / %d on fork") if fork else tr("%d / %d on spade"))
				% [carried, cap]]))
	elif carried > 0:
		out.append(PackedStringArray(["",
			(tr("%d on fork") if fork else tr("%d on spade")) % carried]))


func _vac_rows(out: Array) -> void:
	var vac: YardVac = player.yard_vac
	out.append(PackedStringArray([_hold("primary"), tr("Suck up hay")]))


	if vac != null and vac.fill() > 0:
		out.append(PackedStringArray([_hold("secondary"),
			tr("Empty it in here") if vac.unload_target() != null else tr("Tip it back out")]))
	out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))
	if vac == null:
		return


	var carried:= vac.fill()
	if vac.is_full():
		out.append(PackedStringArray(["", tr("the vac is full, %d") % carried]))
	elif carried > 0:
		out.append(PackedStringArray(["",
			tr("%d / %d in the vac") % [carried, Tech.vac_capacity()]]))


func _lighter_rows(out: Array) -> void:
	var l: Lighter = player.lighter
	if l == null:
		return
	var left:= l.cooldown_left()
	if left > 0.0:
		out.append(PackedStringArray(["", tr("lighter ready in %d s") % ceili(left)]))
	elif l.has_target():
		out.append(PackedStringArray([_key("primary"), tr("Light the hay")]))
	else:
		out.append(PackedStringArray(["", tr("point it at hay to light it")]))
	out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))


func _add_rip(out: Array) -> void:
	if player == null or player.carry == null:
		return
	var item:= player.carry.rip_target()
	if item == null:
		return


	var chip:= PackedStringArray([_hold("dismantle"), item.rip_label()])
	if player.carry.rip_progress() >= 0.0:
		chip.append("lit")
	out.append(chip)


func _add_dismantle(out: Array) -> void:
	if player == null or player.build == null:
		return


	if player.carry != null and player.carry.rip_target() != null:
		return
	var target:= player.build.dismantle_target()
	if target == null:
		return
	var label:= tr("Dismantle")


	var deck:= target as Platform
	if deck != null and Platform.tiles_across(deck.span.x) * Platform.tiles_across(deck.span.y) > 1:
		out.append(PackedStringArray([_hold_with(KEY_SHIFT, "dismantle"),
			tr("Remove one tile")]))
	if player.build.builds != null:


		if player.build.builds.demolish_blocked_reason(target) != "":
			return
		var lost: String = player.build.builds.hay_inside(target)
		if lost != "":
			label = tr("Dismantle (lose %s)") % lost


		elif target.get("gift") == true:
			label = tr("Dismantle (gift: $0 back, place it again free)")
	var chip:= PackedStringArray([_hold("dismantle"), label])
	if player.build.dismantle_progress() >= 0.0:
		chip.append("lit")
	out.append(chip)


func _add_copy(out: Array) -> void:
	if player == null or player.build == null or player.build.builds == null:
		return
	var id: String = player.build.copy_id()
	if id == "" or not BuildCatalog.is_unlocked(id):
		return
	out.append(PackedStringArray([_key("pick_build"),
		tr("Copy %s") % _lower_in_english(BuildCatalog.display_name(id))]))


func _add_scoop(out: Array, verb: String) -> void:
	if player == null or player.aim == null or not player.aim.scoop_lit():
		return
	out.append(PackedStringArray([_key("primary"), verb]))


func _add_drop(out: Array) -> void:
	if player == null:
		return
	var id:= Player.tool_unlock(player.current_tool)
	if id == "" or not GameState.has_tool(id) or not ToolProp.has_spec(id):
		return


	out.append(PackedStringArray([_key("drop_tool"),
		tr("Drop %s") % _lower_in_english(ToolProp.display_name_of(id))]))


static func _key(action: String) -> String:
	return "press:%s" % action


static func _hold(action: String) -> String:
	return "hold:%s" % action


static func _wheel() -> String:
	return "roll:build_further,build_closer"


static func _specs(token: String) -> PackedStringArray:
	var out:= PackedStringArray()
	for want_mouse: bool in [true, false]:
		for a in _actions_of(token):


			var specs:= PackedStringArray([a]) if a.begins_with("key:") else InputSetup.specs_of(a)
			for spec: String in specs:
				if spec.begins_with("mouse:") == want_mouse:
					out.append(spec)
	return out


static func _actions_of(token: String) -> PackedStringArray:
	var colon:= token.find(":")
	if colon < 0:
		return PackedStringArray()
	return token.substr(colon + 1).replace("+", ",").split(",", false)


static func _is_combo(token: String) -> bool:
	return token.contains("+")


static func _hold_with(key: Key, action: String) -> String:
	return "hold:key:%s+%s" % [OS.get_keycode_string(key), action]


static func _words(token: String) -> String:
	var actions:= _actions_of(token)
	if actions.is_empty():
		return ""
	var parts:= PackedStringArray()
	var said_wheel:= false
	for spec: String in _specs(token):


		if InputIcons.is_wheel(spec):
			if said_wheel:
				continue
			said_wheel = true


			parts.append(Cfg.tr("Wheel"))
			continue
		parts.append(InputSetup.spec_label(spec))
	if parts.is_empty():
		parts.append(InputSetup.UNBOUND)
	var text:= (" + " if _is_combo(token) else " / ").join(parts)
	if token.begins_with("hold:"):
		return Cfg.tr("Hold %s") % text
	return text


static func _art(token: String) -> Array [AtlasTexture]:
	var out: Array [AtlasTexture] = []
	var specs:= _specs(token)
	if specs.is_empty():
		return out
	for spec: String in specs:
		var art:= InputIcons.of_spec(spec)
		if art == null:
			return []
		out.append(art)
	return out


func _hints() -> Array [PackedStringArray]:
	var out: Array [PackedStringArray] = []
	if player == null:
		return out


	if not player.is_mouse_captured():
		return out


	if player.arm_links != null and player.arm_links.is_active():
		return out


	if player.carry != null and player.carry.is_carrying():
		var item:= player.carry.held()
		if item is SandShovel:
			var toy:= item as SandShovel


			var reach:= player.carry.target()
			if reach != null:
				out.append(PackedStringArray([_key(reach.interact_action()),
					"%s %s" % [reach.interact_verb(), reach.display_name]]))


			out.append(PackedStringArray([_key("drop_tool"),
				tr("Drop %s") % _lower_in_english(item.display_name)]))
			out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))


			if reach == null or reach.carry_mode() != Carryable.Mode.HELD:
				_add_scoop(out, tr("Scoop"))
			if Cfg.simple_tools():
				out.append(PackedStringArray([_key("secondary"), tr("Empty it")]))
				_load_row(out, toy.carried_strands(), toy.capacity(), "spade")
			else:
				out.append(PackedStringArray([_hold("secondary"), tr("Aim blade")]))
				_load_row(out, toy.carried_strands(), 0, "spade")
			_add_rip(out)
			_add_dismantle(out)


			if reach == null:
				_add_interact_row(out, false)
			return out
		var pushing:= item.carry_mode() == Carryable.Mode.PUSHED


		var more:= player.carry.stack_target()
		if more != null:
			out.append(PackedStringArray([_key("interact,primary"),
				tr("Stack %s (%d/%d)") % [_lower_in_english(more.display_name),
					player.carry.carried_count() + 1, player.carry.stack_capacity()]]))
		elif item is EcoBrick and player.jetpack.can_refill():
			out.append(PackedStringArray([_key("interact"),
				tr("Fill jetpack (%d%%)") % int(round(player.jetpack.fraction() * 100.0))]))
		else:
			out.append(PackedStringArray([_key("interact"),
				tr("Let go") if pushing else
				(tr("Put down") if player.carry.carried_count() < 2
					else tr("Put the top one down"))]))


		if not pushing:
			var tips: bool = item is HayContainer or item is SandShovel
			var keys:= "throw_item" if tips else "throw_item,secondary"


			if player.left_click_throws():
				keys += ",primary"
			out.append(PackedStringArray([_key(keys), tr("Throw")]))


			if item is ExtraLifeCoin:
				out.append(PackedStringArray([_hold("primary"), tr("Eat it: power rush")]))


		if item is HayContainer:
			out.append(PackedStringArray([_hold("secondary"), tr("Tilt / pour")]))


		if item is HayContainer and (item as HayContainer).stored > 0:
			out.append(PackedStringArray(["",
				tr("the load is held until you tilt")]))
		var status:= item.carry_status()
		if status != "":
			out.append(PackedStringArray(["", status]))


		if player.carry.carried_count() > 1:
			var n:= player.carry.carried_count()
			out.append(PackedStringArray(["",
				tr_n("%d block in your arms", "%d blocks in your arms", n) % n]))
		_add_rip(out)
		_add_dismantle(out)
		return out


	var lighting:= player.current_tool == Player.Tool.LIGHTER and player.lighter != null and not player.lighter.aim_point().is_empty()
	if player.carry != null and player.carry.target() != null and not lighting:
		var t:= player.carry.target()
		out.append(PackedStringArray([_key(t.interact_action()),
			"%s %s" % [t.interact_verb(), t.display_name]]))
		_add_rip(out)
		_add_dismantle(out)
		return out

	match player.current_tool:
		Player.Tool.HAND:
			if player.hand != null and player.hand.is_holding_needle():


				var into:= player.hand.deposit_target()
				if into != null:
					out.append(PackedStringArray([_key("primary"),
						tr("Put %s in the case") % NeedleTypes.name_of(
							GameState.type_of(player.hand.held_needle_index()))]))
				else:
					out.append(PackedStringArray([_key("primary"), tr("Drop")]))
				out.append(PackedStringArray([_key("secondary"), tr("Throw")]))
			elif player.hand != null and player.hand.is_holding():


				var n: int = player.hand.count()
				var cap: int = player.hand.capacity()
				if player.aim != null and player.aim.hay_aimed():
					if player.hand.is_full():
						out.append(PackedStringArray(["",
							tr("Hands full (%d/%d)") % [n, cap]]))
					elif player.aim.strand_lit():
						out.append(PackedStringArray([_key("primary"),
							tr("Pick up more (%d/%d)") % [n, cap]]))
				else:
					out.append(PackedStringArray([_key("primary"),
						tr("Drop") if n == 1 else tr("Drop all (%d)") % n]))
				out.append(PackedStringArray([_key("secondary"),
					tr("Throw") if n == 1 else tr("Throw all (%d)") % n]))
			elif player.aim != null and player.aim.strand_lit():


				out.append(PackedStringArray([_key("primary"),
					tr("Pick the needle up") if player.aim.needle_lit()
					else tr("Pluck strand")]))
		Player.Tool.SHOVEL:
			_add_scoop(out, tr("Scoop"))
			_blade_rows(out, player.shovel, "spade")
		Player.Tool.PITCHFORK:
			_add_scoop(out, tr("Fork hay"))
			_blade_rows(out, player.pitchfork, "fork")
		Player.Tool.BROOM:
			out.append(PackedStringArray([_key("primary"), tr("Sweep")]))
			out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))


			out.append(PackedStringArray(["", tr("loose hay on the floor only")]))
		Player.Tool.DETECTOR:
			var on: bool = player.detector != null and player.detector.is_powered()
			out.append(PackedStringArray([_key("secondary"),
				tr("Switch off") if on else tr("Switch on")]))
			out.append(PackedStringArray([_key("throw_item"), tr("Throw")]))


			out.append(PackedStringArray(["",
				tr("shows how close, not which way; walk until it is loudest")]))
		Player.Tool.YARD_VAC:
			_vac_rows(out)
		Player.Tool.LIGHTER:
			_lighter_rows(out)
		Player.Tool.BUILD:


			var id:= player.build_id
			var spec:= BuildCatalog.spec(id)
			var placing:= false
			if player.build != null:
				placing = bool(player.build.status() ["placing"])


			if BuildCatalog.is_run(id) and not placing:
				out.append(PackedStringArray([_key("primary"), tr("Start")]))
			else:
				out.append(PackedStringArray([_key("primary"), tr("Place")]))


			out.append(PackedStringArray([_key("secondary"), tr("Cancel")]))


			var turn:= tr("Rotate") if spec.has("turn") else ""
			var glows:= false
			if turn == "" and player.build != null and player.build.can_turn():
				turn = tr("Rotate")


			if turn == "" and player.build != null and player.build.route_choices() > 1:
				turn = tr("Go another way")
				glows = true
			if turn != "":
				var row:= PackedStringArray([_key("build_rotate"), turn])
				if glows:
					row.append("glow")
				out.append(row)
			if BuildCatalog.next_variant(id) != "":
				out.append(PackedStringArray([_key("build_variant"), tr("Next type")]))


			if player.build != null and player.build.snaps_to_grid():
				out.append(PackedStringArray([_key("build_grid"),
					tr("Grid off") if player.build.grid_snapping()
					else tr("Grid on")]))

			if player.build != null and player.build.can_stop_snapping():
				out.append(PackedStringArray([_key("build_no_snap"),
					tr("Snap on") if player.build.snap_stopped()
					else tr("Snap off")]))
			out.append(PackedStringArray([_wheel(), tr("Distance")]))

	_add_drop(out)


	_add_rip(out)
	_add_dismantle(out)
	_add_copy(out)
	out.append(PackedStringArray([_key("build_catalog"), tr("Build catalogue")]))


	if player.hand != null and player.hand.ending_target() != null:
		out.append(PackedStringArray([_key("primary"), tr("Press it")]))
	_add_interact_row(out, true)
	return out


func _add_interact_row(out: Array, compartments: bool) -> void:
	if player == null:
		return


	if _add_reverse(out):
		return
	var scanner:= _scanner_under()
	var cabinet:= _cabinet_under()
	var dish:= _radar_under()


	var console:= _console_row(_console_under())
	if console != "":
		out.append(PackedStringArray([_key("interact"), console]))
	elif cabinet != null and cabinet.prompt() != "":
		out.append(PackedStringArray([_key("interact"), cabinet.prompt()]))


		if compartments:
			out.append_array(_compartment_hint())
	elif dish != null and dish.prompt() != "":
		out.append(PackedStringArray([_key("interact"), dish.prompt()]))
	elif scanner != null and scanner.prompt() != "":
		out.append(PackedStringArray([_key("interact"), _title_in_english(scanner.prompt())]))
	elif scanner != null:

		out.append(PackedStringArray([_key("interact"),
			tr("Turn the machine on") if scanner.is_switched_off() else tr("Machine switch")]))
	elif player.bay_door != null and player.bay_door.prompt(
			player.eye_position(), player.look_direction()) != "":


		out.append(PackedStringArray([_key("interact"),
			player.bay_door.prompt(player.eye_position(), player.look_direction())]))
	elif player.leaderboards != null and player.leaderboards.is_at_board():


		out.append(PackedStringArray([_key("interact"), tr("Open leaderboards")]))
	elif player.shop != null and player.shop.is_at_counter():
		out.append(PackedStringArray([_key("interact"), tr("Open shop")]))


func _add_reverse(out: Array) -> bool:
	if player.build == null or player.build.reverse_target() == null:
		return false
	var chip:= PackedStringArray([_hold("interact"), tr("Reverse belt")])
	if player.build.reverse_progress() >= 0.0:
		chip.append("lit")
	out.append(chip)
	return true


func _console_under() -> Node3D:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.console_under(
		player.eye_position(), player.look_direction())


func _console_row(machine: Node3D) -> String:
	if machine == null:
		return ""
	if machine is TubeLauncher:
		return tr("Set the launcher's power")
	if machine is HaySilo:
		return tr("Set the silo's speed")
	if machine is PistonRake:
		return tr("Set the rake's throw")
	if machine is ConveyorSplitter:
		if not (machine as ConveyorSplitter).has_panel():
			return ""
		return tr("Adjust splitter")
	if machine is RoboticArm:
		return tr("Set what the arm picks up")

	if machine is HayDrone:
		return tr("Set the drone's zone and drop")
	if machine is PowerPole:
		var grid:= player.build.builds.grid if player.build.builds != null else null
		if grid != null and not grid.switches_of(machine).is_empty() and not grid.line_running(machine):
			return tr("Turn the line on")
		return tr("Line switch")


	if machine.has_method("is_switched_off") and bool(machine.call("is_switched_off")):
		return tr("Turn the machine on")
	return tr("Machine switch")


func _scanner_under() -> HaystackScanner:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.scanner_under(player.eye_position(), player.look_direction())


func _cabinet_under() -> NeedleCabinet:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.cabinet_under(player.eye_position(), player.look_direction())


func _radar_under() -> NeedleRadar:
	if player == null or player.build == null or player.build.builds == null:
		return null
	return player.build.builds.needle_radar_under(player.eye_position(), player.look_direction())


func _compartment_hint() -> Array [PackedStringArray]:
	var out: Array [PackedStringArray] = []
	if player == null or player.aim == null:
		return out
	var type:= player.aim.marked_type()
	if type < 0:
		return out
	var name:= _title_in_english(NeedleTypes.name_of(type))
	match player.aim.marked_action():
		"inspect":
			out.append(PackedStringArray([_key("primary"),
				tr("Look at the %s") % name]))
		"take":
			out.append(PackedStringArray([_key("primary"),
				tr("Take %s  (%d in the drawer)")
					% [name, GameState.stock_of(type)]]))


	return out


static func _speaks_english() -> bool:
	return TranslationServer.get_locale().begins_with("en")


static func _lower_in_english(text: String) -> String:
	return text.to_lower() if _speaks_english() else text


static func _title_in_english(text: String) -> String:
	return text.capitalize() if _speaks_english() else text


func _rebuild(hints: Array [PackedStringArray]) -> void:
	for c in get_children():
		c.queue_free()
	_new_tags.clear()
	_shown_actions.clear()
	_glowing = false
	for h in hints:
		for a in _actions_of(h [0]):
			if not a.begins_with("key:"):
				_shown_actions.append(a)
		add_child(_entry(h [0], h [1], h [2] if h.size() > 2 else ""))


func _note_presses() -> void:
	if not Cfg.teach_hints:
		return
	var learned:= false
	for a in _shown_actions:
		if not Cfg.key_used(a) and InputMap.has_action(a) and Input.is_action_just_pressed(a):
			Cfg.use_key(a)
			learned = true
	if learned:
		_signature = ""


func _is_new(key: String) -> bool:
	if not Cfg.teach_hints:
		return false
	var any:= false
	for a in _actions_of(key):
		if a.begins_with("key:"):
			continue
		if Cfg.key_used(a):
			return false
		any = true
	return any


func _pulse_new(delta: float) -> void:
	if not _glowing:
		return
	_pulse_t = fmod(_pulse_t + delta * NEW_PULSE, TAU)
	var k:= 0.5 + 0.5 * sin(_pulse_t)
	_chip_new.border_color = Color(COL_NEW, lerpf(0.35, 1.0, k))
	for tag in _new_tags:
		tag.modulate.a = lerpf(0.55, 1.0, k)


func _entry(key: String, action: String, mark:= "") -> Control:
	var row:= HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var lit:= mark == "lit"
	var fresh:= key != "" and not lit and _is_new(key)
	var glow:= fresh or (key != "" and not lit and mark == "glow")
	if key != "":
		var art:= _art(key)
		var chip:= PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plate:= _chip
		if lit:
			plate = _chip_live
		elif glow:
			plate = _chip_new
		elif not art.is_empty():
			plate = _chip_art
		chip.add_theme_stylebox_override("panel", plate)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(_cap(key, art, lit))
		row.add_child(chip)

	var al:= Label.new()
	var col:= COL_INFO if key == "" else COL_ACTION
	UiFont.style(al, ACTION_SIZE, COL_LIVE if lit else (COL_NEW if glow else col), 4)
	al.text = action
	al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(al)

	if fresh:
		var tag:= Label.new()
		UiFont.style(tag, HOLD_SIZE, COL_NEW, 4, true)
		tag.text = tr("NEW", "key hint")
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		_new_tags.append(tag)


	if glow:
		_glowing = true
	return row


func _cap(key: String, art: Array [AtlasTexture], lit: bool) -> Control:
	var box:= HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	if art.is_empty():
		var kl:= Label.new()


		UiFont.style(kl, KEY_SIZE, COL_LIVE if lit else COL_KEY, 0, true)
		kl.text = _words(key)
		box.add_child(kl)
		return box


	if key.begins_with("hold:"):
		var hl:= Label.new()
		UiFont.style(hl, HOLD_SIZE, COL_LIVE if lit else COL_KEY, 0, true)
		hl.text = tr("Hold")
		hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(hl)

	for i in art.size():
		var a:= art [i]


		if i > 0 and _is_combo(key):
			var plus:= Label.new()
			UiFont.style(plus, HOLD_SIZE, COL_LIVE if lit else COL_KEY, 0, true)
			plus.text = "+"
			plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box.add_child(plus)
		var pic:= TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = a
		pic.custom_minimum_size = Vector2(ICON_W, ICON_H)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER


		if lit:
			pic.modulate = COL_LIVE
		box.add_child(pic)
	return box
