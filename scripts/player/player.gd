class_name Player
extends CharacterBody3D


const SPEED:= 4.2
const SPRINT:= 7.0


const WALK:= 1.6
const ACCEL:= 12.0
const AIR_ACCEL:= 2.5


const JUMP_VELOCITY:= 4.93
const GRAVITY:= 16.0


const FLY:= 8.0
const FLY_SPRINT:= 22.0
const FLY_ACCEL:= 10.0


const VOID_Y:= -25.0


const SAFE_SAMPLE_INTERVAL:= 0.5


const PLATFORM_ALL:= 4294967295
const EYE_HEIGHT:= 1.66


const STAND_HEIGHT:= 1.78
const CAP_RADIUS:= 0.34


const CROUCH_FOLEY_HIGH:= 0.72
const CROUCH_FOLEY_LOW:= 0.22
const MOUSE_SENS:= 0.0022
const PITCH_LIMIT:= 1.5


const LOOK_RATE_LIGHT:= 24.0
const LOOK_RATE_HEAVY:= 5.0


const SMOOTH_ACCEL_LIGHT:= 0.55
const SMOOTH_ACCEL_HEAVY:= 0.18


const STEP_DISTANCE:= 2.15


const STRIDE_EASE:= 6.0


const ROOF_PROBE_INTERVAL:= 0.3
const ROOF_PROBE_HEIGHT:= 14.0


enum Tool { HAND, SHOVEL, PITCHFORK, BROOM, TOY, DETECTOR, YARD_VAC, LIGHTER, BUILD }


const TOOL_SLOTS:= [Tool.HAND, Tool.SHOVEL, Tool.PITCHFORK, Tool.BROOM, Tool.TOY,
	Tool.DETECTOR, Tool.YARD_VAC, Tool.LIGHTER]


const HOTBAR_KEYS:= 10


static func tool_boxes_max() -> int:
	return 1 + GameState.CARRIED_TOOL_MAX


static func tool_boxes_shown() -> int:
	var n:= 0
	for i in TOOL_SLOTS.size():
		if slot_is_shown(i):
			n += 1
	return n


static func slot_count() -> int:
	return TOOL_SLOTS.size() + GameState.hotbar_size()


const TOOL_ORDER:= ["Hand", "Shovel", "Pitchfork", "Broom", "MetalDetector",
	"YardVac", "Lighter", "JetpackVfx", "AimHighlight", "BuildTool", "Carry"]


var defer_tools:= false

var head: Node3D
var camera: Camera3D
var hand: HandTool
var shovel: Shovel
var pitchfork: Pitchfork
var broom: Broom
var detector: MetalDetector
var yard_vac: YardVac
var lighter: Lighter
var aim: AimHighlight
var build: BuildTool
var carry: CarryTool
var shop: ShopMenu

var leaderboards: LeaderboardMenu


var map: MapMenu

var bay_door: BayDoor

var floor_hatch: FloorHatch


var board: DeliveryBoard

var sell_all_dialog: SellAllDialog
var catalog: CatalogPanel
var rake_panel: RakePanel
var pelletizer_panel: PelletizerPanel
var launcher_panel: LauncherPanel
var lamp_panel: LampPanel
var splitter_panel: SplitterPanel
var silo_panel: SiloPanel
var paint_panel: PaintPanel
var arm_panel: ArmPanel

var arm_links: ArmLinkMode

var drone_panel: DronePanel
var drone_zone: DroneZoneMode
var machine_panel: MachinePanel

var pole_panel: PolePanel
var tech_panel: TechPanel
var inspector: NeedleInspector

var needle_drawer: NeedleDrawer

var demo_end_dialog: DemoEndDialog
var needle_panel: NeedlePanel

var load_panel: LoadPanel
var current_tool: Tool = Tool.HAND


var build_id:= ""


var _before_build: Tool = Tool.HAND

var _pitch:= 0.0


var _yaw_owed:= 0.0
var _pitch_owed:= 0.0
var _mouse_captured:= false
var _step_accum:= 0.0

const SPENT_FLASH:= 0.7


var stamina:= Stamina.new()


var jetpack:= Jetpack.new()

var jetpack_vfx: JetpackVfx


var _sprinting:= false


var _jumps:= 0


var _spent_flash:= 0.0


var spent_refusals:= 0
var _was_airborne:= false


var warehouse: Warehouse


var respawn_fallback:= Vector3.ZERO


var keep_in_yard:= true


var _safe_spot:= Vector3.ZERO
var _safe_seeded:= false
var _safe_left:= 0.0
var _roof_probe_left:= 0.0


var scripted:= false


var scripted_move:= Vector3.ZERO
var scripted_speed:= WALK


var noclip:= false


static var eye_smoothing:= true


const EYE_TELEPORT:= 2.0

var _eye_prev:= Vector3.ZERO
var _eye_curr:= Vector3.ZERO


var _eye_back:= Vector3.ZERO

var _crouch:= 0.0


var _land_kick:= 0.0


var _gait_phase:= 0.0


var _gait_prev:= 0.0


var _stride:= 0.0
var _capsule: CapsuleShape3D
var _shape: CollisionShape3D


var _ladder: Node3D


var _climbing:= false


var _ladder_grace:= 0.0

var _rung_accum:= 0.0


var _climb_stepped_off:= false

signal tool_changed(tool: Tool)


func _ready() -> void:


	add_to_group("player")
	collision_layer = Cfg.L_PLAYER


	collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PEN
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.4

	_capsule = CapsuleShape3D.new()
	_capsule.radius = CAP_RADIUS
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.name = "Collider"
	_shape.shape = _capsule
	_shape.position = Vector3(0, STAND_HEIGHT * 0.5, 0)
	add_child(_shape)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"


	camera.fov = 70.0
	camera.near = 0.05


	camera.far = 1800.0
	head.add_child(camera)

	if defer_tools:
		return
	for which: String in TOOL_ORDER:
		add_tool(which)
	tools_built()


func add_tool(which: String) -> void:
	match which:
		"Hand":
			hand = HandTool.new()
			hand.name = "Hand"
			hand.player = self
			add_child(hand)
		"Shovel":
			shovel = Shovel.new()
			shovel.name = "Shovel"
			shovel.player = self
			add_child(shovel)
		"Pitchfork":
			pitchfork = Pitchfork.new()
			pitchfork.name = "Pitchfork"
			pitchfork.player = self
			add_child(pitchfork)
		"Broom":
			broom = Broom.new()
			broom.name = "Broom"
			broom.player = self
			add_child(broom)
		"MetalDetector":
			detector = MetalDetector.new()
			detector.name = "MetalDetector"
			detector.player = self
			add_child(detector)
		"YardVac":
			yard_vac = YardVac.new()
			yard_vac.name = "YardVac"
			yard_vac.player = self
			add_child(yard_vac)
		"Lighter":
			lighter = Lighter.new()
			lighter.name = "Lighter"
			lighter.player = self
			add_child(lighter)
		"JetpackVfx":
			jetpack.player = self
			jetpack_vfx = JetpackVfx.new()
			jetpack_vfx.name = "JetpackVfx"
			jetpack_vfx.player = self
			add_child(jetpack_vfx)
		"AimHighlight":
			aim = AimHighlight.new()
			aim.name = "AimHighlight"
			aim.player = self
			add_child(aim)
		"BuildTool":
			build = BuildTool.new()
			build.name = "BuildTool"
			build.player = self
			add_child(build)
		"Carry":
			carry = CarryTool.new()
			carry.name = "Carry"
			carry.player = self
			add_child(carry)
			carry.carry_changed.connect(_on_carry_changed)
		_:
			push_error("Player.add_tool: no tool called %s" % which)


func tools_built() -> void:
	capture_mouse(true)
	_set_tool(Tool.HAND)


func capture_mouse(on: bool) -> void:
	_mouse_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


	if not on and yard_vac != null:
		yard_vac.set_sucking(false)
		yard_vac.set_pouring(false)


func is_mouse_captured() -> bool:
	return _mouse_captured


func menu_is_up() -> bool:
	if escape_is_taken():
		return true
	for panel: Node in [shop, map, catalog, tech_panel]:
		if panel != null and panel.call("is_open"):
			return true
	return false


func escape_is_taken() -> bool:
	for panel: Node in [machine_panel, pole_panel, rake_panel, pelletizer_panel,
			launcher_panel, lamp_panel, splitter_panel, silo_panel, arm_panel,
			arm_links, drone_panel, drone_zone, paint_panel, needle_panel, load_panel,
			leaderboards, sell_all_dialog, inspector, needle_drawer, demo_end_dialog]:
		if panel != null and panel.call("is_open"):
			return true
	return false


func _accepts_input() -> bool:
	return _mouse_captured and not scripted


var free_move:= false


func _accepts_move() -> bool:
	return (_mouse_captured or free_move) and not scripted


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, - PITCH_LIMIT, PITCH_LIMIT)
	head.rotation.x = _pitch
	_yaw_owed = 0.0
	_pitch_owed = 0.0


func _unhandled_input(event: InputEvent) -> void:


	if scripted:
		return
	if shop != null and shop.is_open():
		if event.is_action_pressed("free_mouse"):
			shop.set_open(false)
			get_viewport().set_input_as_handled()
		return


	if catalog != null and catalog.is_open():
		return


	if tech_panel != null and tech_panel.is_open():
		return


	if inspector != null and inspector.is_open():
		return


	if needle_drawer != null and needle_drawer.is_open():
		return


	if sell_all_dialog != null and sell_all_dialog.is_open():
		return

	if event is InputEventMouseMotion and _mouse_captured:
		var mm:= event as InputEventMouseMotion
		var simple:= Cfg.simple_tools()
		if carry.is_carrying() and carry.held() is SandShovel and Input.is_action_pressed("secondary"):
			if not simple:
				(carry.held() as SandShovel).aim_input(mm.screen_relative)
				return


		elif carry.is_carrying() and (Input.is_action_pressed("carry_rotate")
				or Input.is_action_pressed("secondary")):


			carry.rotate_input(mm.screen_relative)
			return
		if not simple and (current_tool == Tool.SHOVEL or current_tool == Tool.PITCHFORK) and Input.is_action_pressed("secondary"):

			if current_tool == Tool.SHOVEL:
				shovel.aim_input(mm.screen_relative)
			else:
				pitchfork.aim_input(mm.screen_relative)
			return


		var sens:= MOUSE_SENS * Cfg.mouse_sensitivity
		var yaw_by:= - mm.screen_relative.x * sens
		var pitch_by:= - mm.screen_relative.y * sens
		if Cfg.invert_look_x:
			yaw_by = - yaw_by
		if Cfg.invert_look_y:
			pitch_by = - pitch_by
		if Cfg.smooth_camera:


			_yaw_owed += yaw_by
			_pitch_owed = clampf(_pitch + _pitch_owed + pitch_by,
				- PITCH_LIMIT, PITCH_LIMIT) - _pitch
			return
		rotate_y(yaw_by)
		_pitch = clampf(_pitch + pitch_by, - PITCH_LIMIT, PITCH_LIMIT)
		head.rotation.x = _pitch
		return


	if arm_links != null and arm_links.is_active():
		if arm_links.handle(event):
			get_viewport().set_input_as_handled()
		return


	if drone_zone != null and drone_zone.is_active():
		if drone_zone.handle(event):
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("free_mouse"):
		capture_mouse(not _mouse_captured)
		return
	if _slot_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_catalog"):
		if catalog != null:
			catalog.set_open(true)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tech_tree"):
		if tech_panel != null:
			tech_panel.set_open(true)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_tool"):
		drop_active_tool()
	elif event.is_action_pressed("reset_view") and (current_tool == Tool.SHOVEL or current_tool == Tool.PITCHFORK):
		if current_tool == Tool.SHOVEL:
			shovel.reset_aim()
		else:
			pitchfork.reset_aim()
	elif event.is_action_pressed("interact"):


		var handled:= false


		if try_swap_from_toy():
			handled = true


		elif carry.try_stack():
			handled = true


		elif _refuel_jetpack():
			handled = true


		elif carry.is_carrying() and not carry.toy_in_hand():


			drop_active_tool()
			handled = true


		elif not carry.is_carrying() and _open_console(_splitter_under()):
			handled = true
		elif not carry.is_carrying() and carry.try_pick():
			handled = true
		elif build.begin_reverse():


			handled = true
		else:


			handled = _interact_with_the_world()
		if handled:
			get_viewport().set_input_as_handled()

	if not _mouse_captured:
		return
	if event.is_action_pressed("throw_item"):
		throw_active_tool()
		return


	if current_tool == Tool.YARD_VAC and not carry.is_carrying():
		if _vac_button(event):
			return
	if event.is_action_pressed("primary"):
		_active_tool_primary(true)
	elif event.is_action_released("primary"):
		_active_tool_primary(false)
	elif event.is_action_pressed("secondary"):


		if _painting_at_board():
			return


		if Cfg.simple_tools():
			if carry.is_carrying() and carry.held() is SandShovel:
				(carry.held() as SandShovel).dump()
				return


			if carry.is_carrying() and not (carry.held() is HayContainer):
				carry.throw()
				return
			if current_tool == Tool.SHOVEL:
				shovel.dump()
				return
			if current_tool == Tool.PITCHFORK:
				pitchfork.dump()
				return
		if carry.is_carrying():


			if not (carry.held() is SandShovel or carry.held() is HayContainer):
				carry.throw()
		elif current_tool == Tool.DETECTOR:


			detector.toggle_power()
		elif current_tool == Tool.HAND:
			hand.throw_held()
		elif _is_build_tool(current_tool):


			build.back_out()


func _slot_input(event: InputEvent) -> bool:
	for i in HOTBAR_KEYS:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select_hotbar_key(i)
			return true
	return false


const TOOL_UNLOCKS:= {
	Tool.SHOVEL: "spade",
	Tool.PITCHFORK: "pitchfork",
	Tool.BROOM: "broom",
	Tool.TOY: "sand_shovel",
	Tool.DETECTOR: "metal_detector",
	Tool.YARD_VAC: "yard_vac",
	Tool.LIGHTER: "lighter",
}


static func tool_unlock(t: Tool) -> String:
	return str(TOOL_UNLOCKS.get(t, ""))


static func is_tool_unlocked(t: Tool) -> bool:
	var id:= tool_unlock(t)
	return id == "" or GameState.has_tool(id)


func carried_hay() -> int:
	match current_tool:
		Tool.SHOVEL:
			return shovel.carried_strands()
		Tool.PITCHFORK:
			return pitchfork.carried_strands()
		Tool.TOY:
			var held:= carry.held() if carry != null else null
			if held is SandShovel:
				return (held as SandShovel).carried_strands()
	return 0


func spill_load() -> int:
	match current_tool:
		Tool.SHOVEL:
			return shovel.spill()
		Tool.PITCHFORK:
			return pitchfork.spill()
		Tool.TOY:
			var held:= carry.held() if carry != null else null
			if held is SandShovel:
				return (held as SandShovel).spill()
	return 0


func _announce_dropped_load() -> void:


	var hud: Hud = carry.hud if carry != null else null
	if hud != null:
		hud.show_toast(tr("%s LOAD DROPPED") % Cfg.upper(_tool_noun()))


func _announce_door_locked() -> void:
	var hud: Hud = carry.hud if carry != null else null
	if hud != null:
		hud.show_toast(tr("You cannot open the door yet. Check the order on the board by the bay door."))


func _tool_noun() -> String:
	match current_tool:
		Tool.PITCHFORK:
			return tr("pitchfork")
		Tool.TOY:
			return tr("toy shovel")
	return tr("spade")


func _set_tool(t: Tool, forced:= false) -> void:


	if not is_tool_unlocked(t):
		Audio.play("build_denied")
		return


	var dropped:= spill_load() if t != current_tool else 0


	if not forced and dropped > 0:
		_announce_dropped_load()


	var switched:= t != current_tool
	if t != Tool.BUILD:
		build_id = ""


	if current_tool == Tool.TOY and t != Tool.TOY:
		_stow_toy()
	current_tool = t
	if t == Tool.TOY:
		_equip_toy()
	_sync_hands()
	if switched:


		Audio.play("ui_hotbar", -3.0)
	tool_changed.emit(t)


func equip_build(id: String) -> void:
	if not BuildCatalog.has_id(id) or not BuildCatalog.is_unlocked(id):
		Audio.play("build_denied")
		return


	if spill_load() > 0:
		_announce_dropped_load()
	var switched:= current_tool != Tool.BUILD or build_id != id


	if current_tool == Tool.TOY:
		_stow_toy()


	if current_tool != Tool.BUILD:
		_before_build = current_tool
	build_id = id
	current_tool = Tool.BUILD
	if build != null:
		build.set_mode(BuildCatalog.mode_of(id))
	_sync_hands()
	if switched:
		Audio.play("ui_hotbar", -3.0)
	tool_changed.emit(current_tool)


func put_away_build() -> void:
	if current_tool != Tool.BUILD:
		return
	var back:= _before_build
	if back == Tool.BUILD or not is_tool_unlocked(back):
		back = Tool.HAND
	_set_tool(back)


static func slot_is_shown(index: int) -> bool:
	if index < 0 or index >= slot_count():
		return false
	if index < TOOL_SLOTS.size():
		var t: Tool = TOOL_SLOTS [index]
		var id:= tool_unlock(t)
		return id == "" or GameState.has_tool(id)
	return GameState.hotbar_slot_shown(index - TOOL_SLOTS.size())


static func key_label(n: int) -> String:
	return InputSetup.hint("hotbar_%d" % (mini(n, HOTBAR_KEYS - 1) + 1))


static func favourite_key_label(fav: int) -> String:
	var n:= 0
	for i in TOOL_SLOTS.size() + fav:
		if slot_is_shown(i):
			n += 1
	return key_label(n)


static func favourite_for_key(n: int) -> int:
	var shown:= visible_slots()
	if n < shown.size():
		var slot: int = shown [n]
		if slot < TOOL_SLOTS.size():
			return -1
		return slot - TOOL_SLOTS.size()
	return GameState.first_free_hotbar_slot()


static func visible_slots() -> Array [int]:
	var out: Array [int] = []
	for i in slot_count():
		if slot_is_shown(i):
			out.append(i)
	return out


func select_hotbar_key(n: int) -> void:
	var shown:= visible_slots()
	if n < shown.size():
		select_hotbar_slot(shown [n])
		return


	var fav:= GameState.first_free_hotbar_slot()
	if fav >= 0 and catalog != null:
		catalog.open_for_slot(fav)
		return
	Audio.play("ui_error")


func select_hotbar_slot(index: int) -> void:
	if index < 0:
		return
	if index < TOOL_SLOTS.size():
		_set_tool(TOOL_SLOTS [index])
		return
	var fav:= index - TOOL_SLOTS.size()
	var id:= GameState.hotbar_slot(fav)
	if id == "":
		if catalog != null:
			catalog.open_for_slot(fav)
		else:
			Audio.play("ui_error")
		return
	equip_build(id)


func drop_active_tool() -> void:
	if carry != null and carry.is_carrying():
		var held:= carry.held()


		if held is SandShovel:


			spill_load()
			GameState.take_tool("sand_shovel")
			carry.drop()
			current_tool = Tool.HAND
			_sync_hands()
			tool_changed.emit(current_tool)
			Audio.play("ui_drop")
			return
		carry.drop()
		return
	var id:= tool_unlock(current_tool)
	if id == "" or not GameState.has_tool(id):
		return
	if not ToolProp.has_spec(id):
		return
	if _drop_tool_object(id):

		if current_tool == Tool.LIGHTER:
			lighter.let_go()
		GameState.take_tool(id)
		_set_tool(Tool.HAND, true)
		Audio.play("ui_drop")


func throw_active_tool() -> void:
	if carry != null and carry.is_carrying():
		var held:= carry.held()


		if held is SandShovel:


			spill_load()
			GameState.take_tool("sand_shovel")
			carry.throw()
			current_tool = Tool.HAND
			_sync_hands()
			tool_changed.emit(current_tool)
			return
		carry.throw()
		return


	if current_tool == Tool.HAND:
		if hand != null and hand.is_holding():
			hand.throw_held()
		return
	var id:= tool_unlock(current_tool)
	if id == "" or not GameState.has_tool(id):
		return
	if not ToolProp.has_spec(id):
		return
	if _throw_tool_object(id):
		if current_tool == Tool.LIGHTER:
			lighter.let_go()
		GameState.take_tool(id)
		_set_tool(Tool.HAND, true)
		Audio.play("item_throw", -10.0)


func _throw_tool_object(id: String) -> bool:
	var props:= _prop_manager()
	if props == null:
		return false
	var prop:= props.spawn_near(id, self, 1.0, 1.3)
	if prop == null:
		return false


	prop.linear_velocity = look_direction() * Cfg.CARRY_THROW_SPEED + Vector3(0, 1.4, 0)
	prop.angular_velocity = (global_transform.basis.x * randf_range(6.0, 10.0)
		+ Vector3(randfn(0.0, 1.2), randfn(0.0, 1.2), randfn(0.0, 1.2)))
	return true


func _drop_tool_object(id: String) -> bool:
	var props:= _prop_manager()
	if props == null:
		return false
	return props.spawn_near(id, self, 1.1) != null


func equip_tool_id(id: String) -> void:
	for t: Tool in TOOL_UNLOCKS:
		if TOOL_UNLOCKS [t] == id:
			_set_tool(t)
			return


func _prop_manager() -> PropManager:
	var world:= get_tree().current_scene
	return world.get("props") as PropManager if world != null else null


func _equip_toy() -> void:
	if carry == null or carry.is_carrying():
		return
	var props:= _prop_manager()
	if props == null:
		return
	var item:= props.spawn("sand_shovel", global_transform)
	if item == null:
		return
	carry.take(item)


func try_swap_from_toy(hand_only: bool = false) -> bool:
	if carry == null or not carry.toy_in_hand():
		return false
	var reach:= carry.target()
	if reach == null:
		return false


	if hand_only and reach.carry_mode() != Carryable.Mode.HELD:
		return false


	if spill_load() > 0:
		_announce_dropped_load()


	_stow_toy()


	if carry.try_pick(hand_only) or (is_instance_valid(reach) and reach is HayWad and carry.take(reach)):
		tool_changed.emit(current_tool)
		return true


	_equip_toy()
	return true


func _refuel_jetpack() -> bool:
	if carry == null or not (carry.held() is EcoBrick) or not jetpack.can_refill():
		return false
	var brick:= carry.held()
	carry.stow()
	var props:= _prop_manager()
	if props != null:
		props.remove(brick)
	else:
		brick.queue_free()
	jetpack.refill()
	return true


func _stow_toy() -> void:
	if carry == null or not (carry.held() is SandShovel):
		return
	var item:= carry.held()
	carry.stow()
	var props:= _prop_manager()
	if props != null:
		props.remove(item)


func _bring_toy_back() -> void:
	if current_tool != Tool.TOY or carry == null or carry.is_carrying():
		return


	if is_instance_valid(_dumped_box) or not GameState.has_tool("sand_shovel"):
		return
	_equip_toy()


var _dumped_box: HayContainer


func _auto_dump() -> void:
	if carry == null:
		return


	if _dumped_box != null:
		if not is_instance_valid(_dumped_box):
			_dumped_box = null

			_bring_toy_back()
		elif _dumped_box.docked_in == null:


			if not carry.is_carrying():
				carry.take(_dumped_box)
			_dumped_box = null
		return
	if not carry.is_carrying() or carry.toy_in_hand():
		return
	var box:= carry.held() as HayContainer
	if box == null:
		return
	var hatch: DumpHatch = null
	if build != null and build.builds != null:
		hatch = build.builds.hatch_wanting(box, global_position)
	if hatch == null:
		return


	carry.stow()
	if hatch.take(box):
		_dumped_box = box
	else:


		carry.take(box)


func _interact_with_the_world() -> bool:


	if _open_console(_console_under()):
		return true


	if _open_paint_board():
		return true
	var cabinet:= _cabinet_under()
	if cabinet != null:
		cabinet.interact()
		return true
	var dish:= _radar_under()
	if dish != null:


		if dish.activate() != "":
			Audio.play("build_denied")
		return true
	var scanner:= _scanner_under()
	if scanner != null:


		if needle_drawer != null:
			needle_drawer.open(scanner)
		else:
			scanner.dispense()
		return true
	if floor_hatch != null and floor_hatch.is_hovered(eye_position(), look_direction()):


		if floor_hatch.is_locked():
			floor_hatch.rattle()
			var hud: Hud = carry.hud if carry != null else null
			if hud != null:
				hud.show_toast(tr("Locked."))
		return true
	if board != null and board.take_press(eye_position(), look_direction()):


		return true
	var yard_gate:= warehouse.yard_fence() if warehouse != null else null
	if yard_gate != null and yard_gate.is_hovered(eye_position(), look_direction()):


		return yard_gate.toggle()
	if bay_door != null and bay_door.is_hovered(eye_position(), look_direction()):


		if bay_door.is_locked():

			if bay_door.is_outside(eye_position()):
				return bay_door.let_in()
			_announce_door_locked()
			return true
		return bay_door.toggle()


	if leaderboards != null and leaderboards.try_open():
		return true
	if shop != null:
		return shop.try_open()
	return false


func _console_under() -> Node3D:
	if build == null or build.builds == null:
		return null
	return build.builds.console_under(eye_position(), look_direction())


func _splitter_under() -> ConveyorSplitter:
	var splitter:= _console_under() as ConveyorSplitter
	if splitter == null or not splitter.has_panel():
		return null
	return splitter


func _open_paint_board() -> bool:
	if paint_panel == null or build == null or build.builds == null:
		return false
	var board:= build.builds.paint_board_under(eye_position(), look_direction())
	if board == null:
		return false
	if paint_panel.is_open() and paint_panel.board() == board:
		paint_panel.close()
	else:
		paint_panel.open(board)
	return true


func _painting_at_board() -> bool:
	if build == null or build.builds == null:
		return false
	if paint_panel != null and paint_panel.is_open():
		return false
	return build.builds.paint_board_under(eye_position(), look_direction()) != null


func _open_console(machine: Node3D) -> bool:
	if machine == null:
		return false
	var gun:= machine as TubeLauncher
	if gun != null:
		if launcher_panel != null:
			if launcher_panel.is_open() and launcher_panel.launcher() == gun:
				launcher_panel.close()
			else:
				launcher_panel.open(gun)
		return true
	var lamp:= machine as WorkLamp
	if lamp != null:
		if lamp_panel != null:
			if lamp_panel.is_open() and lamp_panel.lamp() == lamp:
				lamp_panel.close()
			else:
				lamp_panel.open(lamp)
		return true
	var tank:= machine as HaySilo
	if tank != null:
		if silo_panel != null:
			if silo_panel.is_open() and silo_panel.silo() == tank:
				silo_panel.close()
			else:
				silo_panel.open(tank)
		return true
	var rake:= machine as PistonRake
	if rake != null:
		if rake_panel != null:
			if rake_panel.is_open() and rake_panel.rake() == rake:
				rake_panel.close()
			else:
				rake_panel.open(rake)
		return true
	var mill:= machine as HayPelletizer
	if mill != null:
		if pelletizer_panel != null:
			if pelletizer_panel.is_open() and pelletizer_panel.mill() == mill:
				pelletizer_panel.close()
			else:
				pelletizer_panel.open(mill)
		return true
	var splitter:= machine as ConveyorSplitter
	if splitter != null:
		if not splitter.has_panel():
			return false
		if splitter_panel != null:
			if splitter_panel.is_open() and splitter_panel.splitter() == splitter:
				splitter_panel.close()
			else:
				splitter_panel.open(splitter)
		return true
	var robot:= machine as RoboticArm
	if robot != null:
		if arm_panel != null:
			if arm_panel.is_open() and arm_panel.arm() == robot:
				arm_panel.close()
			else:
				arm_panel.open(robot)
		return true


	var aircraft:= machine as HayDrone
	if aircraft != null and drone_panel != null:
		if drone_panel.is_open() and drone_panel.drone() == aircraft:
			drone_panel.close()
		else:
			drone_panel.open(aircraft)
		return true


	var post:= machine as PowerPole
	if post != null:
		if pole_panel != null:
			if pole_panel.is_open() and pole_panel.pole() == post:
				pole_panel.close()
			else:
				pole_panel.open(post)
		return true


	if machine_panel != null:
		if machine_panel.is_open() and machine_panel.machine() == machine:
			machine_panel.close()
		else:
			machine_panel.open(machine)
	return true


func _sync_hands() -> void:
	var free_hands:= not carry.is_carrying()
	hand.set_active(free_hands and current_tool == Tool.HAND)
	shovel.set_active(free_hands and current_tool == Tool.SHOVEL)
	pitchfork.set_active(free_hands and current_tool == Tool.PITCHFORK)
	broom.set_active(free_hands and current_tool == Tool.BROOM)
	detector.set_active(free_hands and current_tool == Tool.DETECTOR)
	yard_vac.set_active(free_hands and current_tool == Tool.YARD_VAC)
	lighter.set_active(free_hands and current_tool == Tool.LIGHTER)
	build.set_active(free_hands and _is_build_tool(current_tool))


static func _is_build_tool(t: Tool) -> bool:
	return t == Tool.BUILD


func _scanner_under() -> HaystackScanner:
	if build == null or build.builds == null:
		return null
	return build.builds.scanner_under(eye_position(), look_direction())


func _cabinet_under() -> NeedleCabinet:
	if build == null or build.builds == null:
		return null
	return build.builds.cabinet_under(eye_position(), look_direction())


func _radar_under() -> NeedleRadar:
	if build == null or build.builds == null:
		return null
	return build.builds.needle_radar_under(eye_position(), look_direction())


func _on_carry_changed(_item: Carryable) -> void:
	_sync_hands()
	if current_tool == Tool.TOY and not carry.is_carrying():
		_bring_toy_back.call_deferred()


func _vac_button(event: InputEvent) -> bool:
	if event.is_action_released("primary"):
		yard_vac.set_sucking(false)
		return true
	if event.is_action_released("secondary"):
		yard_vac.set_pouring(false)
		return true
	if event.is_action_pressed("primary"):


		if _painting_at_board():
			return true
		yard_vac.set_sucking(true)
		return true
	if event.is_action_pressed("secondary"):
		if _painting_at_board():
			return true
		yard_vac.set_pouring(true)
		return true
	return false


func left_click_throws() -> bool:
	if carry == null or not carry.is_carrying() or current_tool == Tool.HAND:
		return false
	var held:= carry.held()
	return held.carry_mode() == Carryable.Mode.HELD and held.hay_strands() > 0 and held is not ExtraLifeCoin


func _active_tool_primary(pressed: bool) -> void:
	if not pressed:


		if broom != null:
			broom.set_held(false)
		return


	if _painting_at_board():
		return


	if carry.is_carrying():
		if carry.held() is SandShovel:


			if try_swap_from_toy(true):
				return


			_dig((carry.held() as SandShovel).scoop)
			return


		if carry.try_stack():
			return


		if carry.begin_eat():
			return
		if left_click_throws():
			carry.throw()
			return
		carry.drop()
		return


	if current_tool == Tool.LIGHTER and not lighter.aim_point().is_empty():
		lighter.strike()
		return


	if carry.try_pick(true):
		return
	match current_tool:
		Tool.HAND:
			hand.primary()
		Tool.SHOVEL:
			_dig(shovel.scoop)
		Tool.PITCHFORK:
			_dig(pitchfork.scoop)
		Tool.BROOM:
			broom.set_held(true)
			broom.sweep()
		Tool.LIGHTER:

			lighter.strike()
		Tool.BUILD:
			build.primary()


func _dig(bite: Callable) -> void:
	if not stamina.can_afford(stamina.dig_cost()):

		_spent_flash = SPENT_FLASH
		spent_refusals += 1
		return
	if int(bite.call()) > 0:
		stamina.spend_dig()


func _exit_tree() -> void:
	jetpack.stop()


func _process(delta: float) -> void:
	_turn_head(delta)


	_smooth_eye()


func _turn_head(delta: float) -> void:
	if is_zero_approx(_yaw_owed) and is_zero_approx(_pitch_owed):
		return


	var k:= 1.0
	if Cfg.smooth_camera:
		k = 1.0 - exp(- lerpf(LOOK_RATE_LIGHT, LOOK_RATE_HEAVY,
			Cfg.smooth_camera_amount) * delta)
	var yaw_now:= _yaw_owed * k
	var pitch_now:= _pitch_owed * k
	_yaw_owed -= yaw_now
	_pitch_owed -= pitch_now
	rotate_y(yaw_now)
	_pitch = clampf(_pitch + pitch_now, - PITCH_LIMIT, PITCH_LIMIT)
	head.rotation.x = _pitch


func _smooth_eye() -> void:
	_eye_back = Vector3.ZERO
	if not eye_smoothing:


		camera.position = Vector3.ZERO
		return
	var step:= _eye_curr - _eye_prev


	if step.length_squared() > EYE_TELEPORT * EYE_TELEPORT:
		_eye_prev = _eye_curr
		step = Vector3.ZERO
	if step.is_zero_approx():
		if camera.position != Vector3.ZERO:
			camera.position = Vector3.ZERO
		return


	var back:= step * (Engine.get_physics_interpolation_fraction() - 1.0)
	_eye_back = back
	camera.position = head.global_transform.basis.inverse() * back


func eye_lag() -> Vector3:
	return _eye_back


func _note_step() -> void:
	_eye_prev = _eye_curr
	_eye_curr = global_position


func _physics_process(delta: float) -> void:
	_apply_crouch(delta)
	if noclip:

		jetpack.stop()
		_fly(delta)
		_note_step()
		return
	_land_kick *= exp(- Cfg.JOSTLE_LAND_DECAY * delta)
	_auto_dump()

	_ladder_grace = maxf(0.0, _ladder_grace - delta)
	var climbing:= _update_climb()


	var thrust:= jetpack.wants_thrust(is_on_floor(),
		_accepts_move() and Input.is_action_pressed("jump"),
		climbing or _ladder_grace > 0.0)

	if climbing:


		pass
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
		if thrust:
			velocity.y = jetpack.lift(velocity.y, delta)
	elif _accepts_move() and Input.is_action_pressed("jump") and _crouch < 0.5:


		if velocity.y <= 0.0:


			_jumps += 1

		velocity.y = Tech.jump_velocity(JUMP_VELOCITY, GRAVITY) * stamina.jump_scale()


	var input:= (Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if _accepts_move() else Vector2.ZERO)
	var dir:= (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized()


	var wants_sprint:= _accepts_move() and Input.is_action_pressed("sprint")
	_sprinting = stamina.sprint_allowed(wants_sprint, _sprinting)
	var base_speed:= SPRINT if _sprinting else SPEED
	var target_speed:= base_speed * Tech.move_speed_scale() * stamina.speed_scale()


	target_speed = lerpf(target_speed, Tech.crouch_speed(), _crouch)


	if scripted:
		dir = scripted_move
		dir.y = 0.0
		dir = dir.normalized()
		target_speed = scripted_speed


	var a:= ACCEL if is_on_floor() else (Cfg.JETPACK_AIR_ACCEL if thrust else AIR_ACCEL)


	if Cfg.smooth_camera:
		a *= lerpf(SMOOTH_ACCEL_LIGHT, SMOOTH_ACCEL_HEAVY, Cfg.smooth_camera_amount)
	var target:= dir * target_speed


	if carry != null:
		target = carry.hold_back(target)
	velocity.x = move_toward(velocity.x, target.x, a * delta * target_speed)
	velocity.z = move_toward(velocity.z, target.z, a * delta * target_speed)


	if climbing:
		_apply_climb(delta)


	platform_floor_layers = PLATFORM_ALL & ~ Cfg.L_BUILD if Tech.has_grippy_boots() else PLATFORM_ALL

	if carry != null:
		velocity = carry.hold_back(velocity)
	move_and_slide()


	stamina.tick(delta, _sprinting, Vector2(velocity.x, velocity.z).length())

	jetpack.tick(delta, is_on_floor())
	_spent_flash = maxf(0.0, _spent_flash - delta)
	_track_ground(delta)
	_gait_prev = _gait_phase
	_gait_phase += Vector2(velocity.x, velocity.z).length() * delta / STEP_DISTANCE * TAU
	_stride = lerpf(_stride, unrest() if is_on_floor() else 0.0,
		1.0 - exp(- STRIDE_EASE * delta))
	_footsteps(delta)
	_probe_roof(delta)
	_note_step()


func enter_ladder(ladder: Node3D) -> void:
	_ladder = ladder


func exit_ladder(ladder: Node3D) -> void:
	if _ladder != ladder:
		return
	_ladder = null
	_climbing = false
	_climb_stepped_off = false


func _update_climb() -> bool:
	if _ladder == null or not is_instance_valid(_ladder) or not _ladder.has_ladder() or not _accepts_move():
		_climbing = false
		_climb_stepped_off = false
		return false
	if _ladder_grace > 0.0:
		return false
	var face: Vector3 = _ladder.ladder_face()
	var look:= look_direction()
	look.y = 0.0
	look = look.normalized() if look.length_squared() > 1e-06 else Vector3.ZERO
	var square:= look.dot(- face) > Cfg.CLIMB_FACING
	if not _climbing:
		var take:= square and Input.is_action_pressed("move_forward")


		if not take and not is_on_floor() and velocity.y < -0.1 and _ladder.ladder_catches_a_fall():
			take = true
			_climb_stepped_off = true
		if not take:
			return false
		_climbing = true
		_rung_accum = 0.0


	if Input.is_action_pressed("jump"):
		_climbing = false
		_climb_stepped_off = false
		_ladder_grace = 0.35
		velocity = face * Cfg.CLIMB_PUSH_OFF + Vector3.UP * 2.0
		return false


	if global_position.y >= _ladder.ladder_top_y() + 0.02:
		_climbing = false
		_climb_stepped_off = false
		_ladder_grace = 0.25
		velocity = - face * Cfg.CLIMB_TOP_NUDGE
		return false
	return true


func _apply_climb(delta: float) -> void:
	var input:= Input.get_vector("move_left", "move_right",
		"move_forward", "move_back")
	velocity.y = - input.y * Cfg.CLIMB_SPEED


	if _climb_stepped_off:
		if Input.is_action_pressed("move_forward"):
			velocity.y = minf(velocity.y, 0.0)
		else:
			_climb_stepped_off = false


	if velocity.y < 0.0 and global_position.y <= _ladder.ladder_foot_y() + 0.05:
		velocity.y = 0.0
	var want:= _climb_hold()
	velocity.x = clampf((want.x - global_position.x) * 8.0, -3.0, 3.0)
	velocity.z = clampf((want.z - global_position.z) * 8.0, -3.0, 3.0)


	_rung_accum += absf(velocity.y) * delta
	if _rung_accum < Cfg.LADDER_RUNG_SPACING:
		return
	_rung_accum -= Cfg.LADDER_RUNG_SPACING
	Audio.play("step_hard", -14.0)


func _climb_hold() -> Vector3:
	var stand: Vector3 = _ladder.ladder_stand_point()
	if velocity.y < 0.0 or _climb_stepped_off:
		return stand
	var lead:= Cfg.CLIMB_EXIT_LEAD
	var t:= clampf((global_position.y - (_ladder.ladder_top_y() - lead)) / lead,
		0.0, 1.0)
	return stand.lerp(_ladder.ladder_exit_point(), t)


func set_noclip(on: bool) -> void:
	if noclip == on:
		return
	noclip = on
	velocity = Vector3.ZERO


	_shape.set_deferred("disabled", on)
	if not on:

		_was_airborne = false
		_step_accum = 0.0


func _fly(delta: float) -> void:
	var dir:= Vector3.ZERO
	var free:= _accepts_move()
	if free:
		var input:= Input.get_vector("move_left", "move_right",
			"move_forward", "move_back")
		dir = camera.global_transform.basis * Vector3(input.x, 0.0, input.y)
		if Input.is_action_pressed("jump"):
			dir += Vector3.UP
		if Input.is_action_pressed("crouch"):
			dir += Vector3.DOWN
		dir = dir.normalized()

	var speed:= FLY
	if free and Input.is_action_pressed("sprint"):
		speed = FLY_SPRINT

	velocity = velocity.move_toward(dir * speed, FLY_ACCEL * speed * delta)
	global_position += velocity * delta


	_probe_roof(delta)


func _track_ground(delta: float) -> void:


	if _out_of_bounds():
		respawn()
		return
	if is_on_floor():
		_safe_left -= delta
		if _safe_left <= 0.0 and _inside_shed():
			_safe_spot = global_position
			_safe_seeded = true
			_safe_left = SAFE_SAMPLE_INTERVAL
		return
	if global_position.y <= VOID_Y:
		respawn()


func _out_of_bounds() -> bool:
	if not keep_in_yard or noclip or warehouse == null or not warehouse.visible:
		return false
	if _inside_shed():
		return false
	var fence:= warehouse.yard_fence()
	if fence == null:
		return false
	return not fence.encloses(global_position)


func _inside_shed() -> bool:
	if warehouse == null:
		return true
	return warehouse.encloses(global_position)


func respawn(to_spawn: bool = false) -> void:
	velocity = Vector3.ZERO
	var back:= respawn_fallback if to_spawn or not _safe_seeded else _safe_spot
	global_position = back + Vector3(0.0, 0.15, 0.0)
	_step_accum = 0.0
	_safe_left = SAFE_SAMPLE_INTERVAL


func _apply_crouch(delta: float) -> void:
	var want:= 1.0 if (_accepts_move() and Input.is_action_pressed("crouch")) else 0.0


	if noclip:
		want = 0.0
	elif want < _crouch and _headroom_blocked():
		want = _crouch
	var before:= _crouch
	_crouch = lerpf(_crouch, want, 1.0 - exp(- Cfg.CROUCH_BLEND * delta))
	if absf(_crouch - want) < 0.001:
		_crouch = want
	_crouch_foley(before, _crouch)

	var h:= lerpf(STAND_HEIGHT, Cfg.CROUCH_HEIGHT, _crouch)
	_capsule.height = h
	_shape.position.y = h * 0.5
	head.position.y = lerpf(EYE_HEIGHT, Cfg.CROUCH_EYE_HEIGHT, _crouch)


func _crouch_foley(before: float, after: float) -> void:
	if before < CROUCH_FOLEY_HIGH and after >= CROUCH_FOLEY_HIGH:
		Audio.play("crouch_down", -12.0)
	elif before > CROUCH_FOLEY_LOW and after <= CROUCH_FOLEY_LOW:
		Audio.play("crouch_up", -13.0)


func _headroom_blocked() -> bool:
	var probe:= SphereShape3D.new()
	probe.radius = CAP_RADIUS
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.collide_with_areas = false
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis.IDENTITY, global_position
		+ Vector3.UP * (STAND_HEIGHT - CAP_RADIUS + Cfg.CROUCH_HEADROOM))
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func pour_intent() -> bool:


	if free_move:
		return false
	return _accepts_input() and (Input.is_action_pressed("secondary")
		or Input.is_action_pressed("carry_rotate"))


func crouch_amount() -> float:
	return _crouch


func unrest() -> float:
	var speed:= Vector2(velocity.x, velocity.z).length()
	var t:= clampf(inverse_lerp(Cfg.JOSTLE_WALK_FLOOR, Tech.jostle_speed_ref(), speed), 0.0, 1.0)
	return pow(t, Cfg.JOSTLE_CURVE) * _steadiness()


func is_sprinting() -> bool:
	return _sprinting and Vector2(velocity.x, velocity.z).length() > Stamina.REST_SPEED


func jumps_taken() -> int:
	return _jumps


func land_kick() -> float:
	return _land_kick


func gait_phase() -> float:
	return _gait_phase


func stride_phase() -> float:
	return lerpf(_gait_prev, _gait_phase, Engine.get_physics_interpolation_fraction())


func stride() -> float:
	return _stride


func stride_pose(sway: float, heave: float, nod: float, bank: float) -> Transform3D:
	var amp:= _stride
	if amp <= 0.0001:
		return Transform3D.IDENTITY
	var side:= sin(stride_phase() * 0.5)

	var dip:= side * side * 2.0 - 1.0
	return Transform3D(
		Basis.from_euler(Vector3(dip * nod * amp, 0.0, - side * bank * amp)),
		Vector3(side * sway, dip * heave, 0.0) * amp)


func _steadiness() -> float:
	return lerpf(1.0, Cfg.JOSTLE_CROUCH_FACTOR, _crouch)


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		_was_airborne = true
		return
	if _was_airborne:


		_was_airborne = false
		_step_accum = 0.0
		_land_kick = Cfg.JOSTLE_LAND_KICK * Tech.land_kick_scale() * _steadiness()
		Audio.play(_ground_key(), -4.0)
		return
	var speed:= Vector2(velocity.x, velocity.z).length()
	if speed < 0.6:
		return
	var stride:= STEP_DISTANCE * lerpf(1.0, Cfg.CROUCH_STEP_SCALE, _crouch)
	_step_accum += speed * delta
	if _step_accum < stride:
		return
	_step_accum -= stride


	Audio.play(_ground_key(), -9.0 + Cfg.CROUCH_STEP_GAIN * _crouch)


func _ground_key() -> String:
	for i in get_slide_collision_count():
		var col:= get_slide_collision(i)
		var body:= col.get_collider() as CollisionObject3D
		if body != null and (body.collision_layer & Cfg.L_PILE):
			return "step_soft"
	return "step_hard"


func _probe_roof(delta: float) -> void:
	_roof_probe_left -= delta
	if _roof_probe_left > 0.0:
		return
	_roof_probe_left = ROOF_PROBE_INTERVAL
	var from:= global_position + Vector3(0, EYE_HEIGHT, 0)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * ROOF_PROBE_HEIGHT)
	q.collision_mask = Cfg.L_WORLD
	q.collide_with_areas = false


	Audio.set_indoor(1.0 if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() else 0.0)


func eye_position() -> Vector3:
	return camera.global_position


func look_direction() -> Vector3:
	return - camera.global_transform.basis.z
