class_name HaystackScanner
extends Node3D


const MODEL:= "res://assets/models/haystack_scanner.glb"
const PING_SHADER:= "res://assets/scanner_ping.gdshader"


const SPEC:= "res://assets/models/haystack_scanner_materials.json"


const SHADER:= "res://assets/stand_surface.gdshader"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"
const TEX_MAPS:= {
	"albedo": "diff", "normal": "nor_gl", "rough": "rough", "ao": "ao",
}

const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"
const N_SCAN_VOLUME:= "Marker_ScanVolume"
const N_BIN:= "Marker_Bin"
const N_SCREEN:= "Marker_Screen"


const ANIM_SCAN:= "Scan"
const ANIM_MAGNET:= "MagnetSweep"
const ANIM_DRAWER:= "DrawerOpen"


const CLIP_TARGET:= {
	ANIM_SCAN: "Scan_Sweep",
	ANIM_MAGNET: "Scan_PickHead",
	ANIM_DRAWER: "Scan_Drawer",
}


const MAT_GLOW:= "M_SC_Glow"
const MAT_LASER:= "M_SC_Laser"
const MAT_BEAM:= "M_SC_Beam"

const MAT_LENS:= "M_SC_Lens"


const DRIVEN_KEYS: PackedStringArray = [MAT_GLOW, MAT_LASER, MAT_BEAM, MAT_LENS]


const GLOW_ENERGY:= 1.6
const LASER_ENERGY:= 3.0


const BEACON_REST_ENERGY:= 0.65


const BEAM_ENERGY:= 0.2


const BEAM_IDLE:= 0.3
const FLASH_GAIN:= 2.4


const INTAKE_LENGTH:= Cfg.SCANNER_LENGTH * 0.5
const INTAKE_HEIGHT:= 0.5


const OUTPUT_LEAD:= 0.3


const OUTPUT_LIFT:= 0.06


const SCREEN_PIXEL:= 0.00058
const SCREEN_FONT:= 96


const SCREEN_MAX_CHARS:= 6


const WORD_BY_ID:= {
	"hay_bale": "BALE",
	"foiled_bale": "WRAP",
	"eco_brick": "BRICK",
}


const TRAY_INNER_X:= 0.36
const TRAY_INNER_Z:= 0.42
const TRAY_WALL_H:= 0.09
const TRAY_WALL_T:= 0.025
const TRAY_FLOOR_T:= 0.02

const TRAY_MARKER_LIFT:= 0.02


const FLIGHT_STAGGER:= 0.12


const PLAYER_CATCH_HEIGHT:= 1.25


const SUPPORT_HALF_WIDTH:= Cfg.BELT_SUPPORT_HALF_WIDTH


const SCAN_LOOP_DB:= -15.0
const SCAN_LOOP_SILENT:= -80.0


const SCAN_LOOP_RAMP:= 140.0
const SCAN_LOOP_HEIGHT:= 1.15


const ALARM_DB:= -6.0


const ALARM_REACH:= Cfg.SCANNER_ALARM_RANGE
const ALARM_CLEAR:= Cfg.SCANNER_ALARM_RANGE + 2.5

signal caught(index: int, position: Vector3)
signal dispensed(count: int)

var live: LiveStrandManager


var props: PropManager
var placement_preview:= false
var tier_index:= Cfg.SCANNER_DEFAULT_TIER


var paid_cost:= -1.0


var banked: PackedInt32Array = PackedInt32Array()


var stored:= 0


var blocks: Array [Dictionary] = []

var starved_for:= 0.0

var _model: Node3D

var _scan_player: AnimationPlayer
var _magnet_player: AnimationPlayer

var _ports: Array [Node3D] = []
var _drawer_player: AnimationPlayer
var _belt: BeltPath
var _scan_area: Area3D
var _screen: Label3D

var _driven: Dictionary = { }
var _supports: Node3D

var _ghost_belt: BeltGhost
var _flash:= 0.0


var _beacon_turning:= false


static var old_beacon: bool = "--oldbeacon" in OS.get_cmdline_user_args()
var _alarm:= 0.0
var _alarm_angle:= 0.0
var _alarm_pivot: Node3D


var _player_near:= false

var _beacon_meshes: Array [MeshInstance3D] = []


var _arm: Node3D
var _ping_root: Node3D
var _pings: Array [MeshInstance3D] = []
var _ping_age: Array [float] = []


var _ping_side:= 0
var _drawer_open:= false
var _busy:= false


var _outgoing:= 0

var _cycle_left:= 0.0


var _emit_left:= 0.0


var _rng:= RandomNumberGenerator.new()


var _pending: PackedInt32Array = PackedInt32Array()


var _flying: PackedInt32Array = PackedInt32Array()


func held_needles() -> PackedInt32Array:
	var out:= PackedInt32Array()
	out.append_array(banked)
	out.append_array(_pending)
	out.append_array(_flying)
	for record: Dictionary in blocks:
		var index:= int(record.get("needle", -1))
		if index >= 0:
			out.append(index)
	return out


var _scan_voice:= -1
var _scan_gain:= SCAN_LOOP_SILENT
var _scan_target:= SCAN_LOOP_SILENT


func setup(at: Vector3, yaw: float, tier: int = Cfg.SCANNER_DEFAULT_TIER) -> void:
	tier_index = clampi(tier, 0, Cfg.SCANNER_TIERS.size() - 1)
	paid_cost = float(tier_data() ["cost"])
	position = at
	rotation.y = yaw


func set_tier(tier: int) -> bool:
	var next:= clampi(tier, 0, Cfg.SCANNER_TIERS.size() - 1)
	if next == tier_index:
		return false
	tier_index = next
	return true


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	_mount_pings()
	if placement_preview:
		set_physics_process(false)


		_build_preview_deck()
		set_preview_valid(true)
		return

	set_process(false)


	FactoryClock.join(self)


	MachineLod.adopt(self, _model, MODEL)
	_build_belt()
	_build_intake_area()
	_build_tray()
	_build_screen()
	_build_alarm()
	add_to_group("haystack_scanners")
	_refresh_screen()


	_apply_lamps()


	_drive_beacon(0.0)


	call_deferred("refresh_supports")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HaystackScanner: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0

	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= _load_spec()
	if spec.is_empty():
		push_warning("HaystackScanner: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue


			var key:= src.resource_name
			if src.get_meta("immutable_palette", false):
				preload("res://assets/models/machine_palette.gd").validate_import(src, spec)
				continue


			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return _surface(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key in DRIVEN_KEYS:
				if not _driven.has(key):
					var fresh: Array [MeshInstance3D] = []
					_driven [key] = fresh
				var worn: Array [MeshInstance3D] = _driven [key]
				if not worn.has(mesh):
					worn.append(mesh)
	if not missed.is_empty():
		push_warning("HaystackScanner: no table entry for %s" % ", ".join(missed.keys()))


func _load_spec() -> Dictionary:


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		return res.data
	if not FileAccess.file_exists(SPEC):
		return { }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= _make_surface(key, spec, shader)
	return HayCompressor.lamp_material(made) if key in DRIVEN_KEYS else made


func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var surfaces: Dictionary = spec.get("surfaces", { })
	if surfaces.has(key):
		var d: Dictionary = surfaces [key]
		var asset: String = d ["asset"]
		var m:= ShaderMaterial.new()
		m.shader = shader
		m.resource_name = key
		for slot: String in TEX_MAPS:
			var suffix: String = TEX_MAPS [slot]
			var path: String = TEX % [asset, asset, suffix]


			if ResourceLoader.exists(path):
				m.set_shader_parameter("tex_" + slot, load(path))
		m.set_shader_parameter("per_metre", float(d ["per_metre"]))
		m.set_shader_parameter("tint", _col(d ["tint"]))
		m.set_shader_parameter("saturation", float(d.get("sat", 1.0)))
		var rough: Array = d ["rough"]
		m.set_shader_parameter("rough_min", float(rough [0]))
		m.set_shader_parameter("rough_max", float(rough [1]))
		m.set_shader_parameter("metallic_amount", float(d.get("metal", 0.0)))
		m.set_shader_parameter("normal_strength", float(d.get("nor", 1.0)))
		m.set_shader_parameter("ao_strength", float(d.get("ao", 0.0)))
		return m

	var flats: Dictionary = spec.get("flats", { })
	if flats.has(key):
		var f: Dictionary = flats [key]
		var sm:= StandardMaterial3D.new()
		sm.resource_name = key
		var colour:= _col(f ["color"])
		var alpha:= float(f.get("alpha", 1.0))
		sm.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
		sm.roughness = float(f.get("rough", 0.6))
		sm.metallic = float(f.get("metal", 0.0))
		sm.metallic_specular = 0.4
		var emit:= float(f.get("emit", 0.0))
		if emit > 0.0:
			sm.emission_enabled = true
			sm.emission = colour
			sm.emission_energy_multiplier = emit
		if alpha < 1.0:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		return sm
	return null


func _col(a: Variant) -> Color:
	var v: Array = a
	return Color(float(v [0]), float(v [1]), float(v [2]))


func _build_animation() -> void:
	if _model == null:
		return
	_scan_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _scan_player == null:
		push_warning("HaystackScanner: %s has no AnimationPlayer; the machine will not move" % MODEL)
		return


	_scan_player.active = false
	var source:= _scan_player
	_scan_player = _solo_player(source, "ScanPlayer", ANIM_SCAN)
	_magnet_player = _solo_player(source, "MagnetPlayer", ANIM_MAGNET)
	_drawer_player = _solo_player(source, "DrawerPlayer", ANIM_DRAWER)


	if _scan_player != null:
		_scan_player.get_animation(ANIM_SCAN).loop_mode = Animation.LOOP_LINEAR
	if _magnet_player != null:
		_magnet_player.get_animation(ANIM_MAGNET).loop_mode = Animation.LOOP_LINEAR

	if placement_preview:


		return


func _solo_player(src: AnimationPlayer, node_name: String, clip: String) -> AnimationPlayer:
	var source_anim:= _find_animation(src, clip)
	if source_anim == null:
		return null
	var anim: Animation = source_anim.duplicate(true)
	var target: String = CLIP_TARGET.get(clip, "")
	if target != "":

		for i in range(anim.get_track_count() - 1, -1, -1):
			if not String(anim.track_get_path(i)).contains(target):
				anim.remove_track(i)
	var lib:= AnimationLibrary.new()
	lib.add_animation(clip, anim)
	var p:= AnimationPlayer.new()
	p.name = node_name
	src.get_parent().add_child(p)
	p.add_animation_library("", lib)


	p.root_node = p.get_path_to(src.get_node(src.root_node))
	return p


func _find_animation(p: AnimationPlayer, clip: String) -> Animation:
	for name in p.get_animation_list():
		if name == clip or name.ends_with("/" + clip):
			return p.get_animation(name)
	push_warning("HaystackScanner: %s has no '%s' clip" % [MODEL, clip])
	return null


func _run_instruments() -> void:
	_loop_instrument(_scan_player, ANIM_SCAN, true)
	_loop_instrument(_magnet_player, ANIM_MAGNET, true)


func _park_instruments() -> void:
	_loop_instrument(_scan_player, ANIM_SCAN, false)
	_loop_instrument(_magnet_player, ANIM_MAGNET, false)


func _loop_instrument(p: AnimationPlayer, clip: String, looping: bool) -> void:
	if p == null:
		return
	var anim:= _find_animation(p, clip)
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	if looping and not p.is_playing():
		_play(p, clip)


func _play(p: AnimationPlayer, clip: String) -> void:
	if p == null:
		return
	for name in p.get_animation_list():
		if name == clip or name.ends_with("/" + clip):
			p.play(name)
			return


func port_in() -> Vector3:
	return to_global(_marker_local(N_BELT_IN, Vector3(0, 0, - Cfg.SCANNER_LENGTH * 0.5)))


func port_out() -> Vector3:
	return to_global(_marker_local(N_BELT_OUT, Vector3(0, 0, Cfg.SCANNER_LENGTH * 0.5)))


func deck() -> BeltPath:
	return _belt


func forward() -> Vector3:
	var d:= port_out() - port_in()
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


func _build_belt() -> void:
	_belt = BeltPath.new()
	_belt.name = "ModuleBelt"
	add_child(_belt)


	_belt.build_path(belt_runs() [0], Cfg.BELT_JOINT_OVERLAP)


	_belt.shut_mouth(port_in() + forward() * INTAKE_LENGTH)


	_belt.records_props = true


func _build_preview_deck() -> void:
	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([port_in(), port_out()])]


func _process(delta: float) -> void:
	if _beacon_turning:
		_drive_alarm(delta)
		return
	if not placement_preview or _ghost_belt == null or not is_visible_in_tree():
		return
	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms())


func _build_intake_area() -> void:
	_scan_area = Area3D.new()
	_scan_area.name = "IntakeMouth"
	_scan_area.collision_layer = 0


	_scan_area.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_scan_area.monitorable = false
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
		INTAKE_HEIGHT, INTAKE_LENGTH)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
	_scan_area.add_child(cs)
	add_child(_scan_area)


	_scan_area.position = to_local(port_in() + forward() * (INTAKE_LENGTH * 0.5))


	_scan_area.position.y = 0.0


func _build_tray() -> void:
	var drawer:= _find("Scan_Drawer") as Node3D
	var bin:= _find(N_BIN) as Node3D
	if drawer == null or bin == null:
		push_warning("HaystackScanner: %s has no drawer or bin marker; dispensed needles will fall through it" % MODEL)
		return
	var body:= AnimatableBody3D.new()
	body.name = "TrayCollision"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	body.sync_to_physics = true
	drawer.add_child(body)
	body.global_position = bin.global_position

	var floor_y:= - TRAY_MARKER_LIFT - TRAY_FLOOR_T * 0.5
	var wall_y:= - TRAY_MARKER_LIFT + TRAY_WALL_H * 0.5
	_tray_box(body, Vector3(TRAY_INNER_X, TRAY_FLOOR_T, TRAY_INNER_Z),
		Vector3(0, floor_y, 0))
	for side: float in [-1.0, 1.0]:
		_tray_box(body, Vector3(TRAY_WALL_T, TRAY_WALL_H, TRAY_INNER_Z),
			Vector3(side * (TRAY_INNER_X + TRAY_WALL_T) * 0.5, wall_y, 0))
		_tray_box(body, Vector3(TRAY_INNER_X, TRAY_WALL_H, TRAY_WALL_T),
			Vector3(0, wall_y, side * (TRAY_INNER_Z + TRAY_WALL_T) * 0.5))


func _tray_box(body: AnimatableBody3D, size: Vector3, at: Vector3) -> void:
	var box:= BoxShape3D.new()
	box.size = size
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = at
	body.add_child(cs)


func _build_screen() -> void:
	var anchor:= _find(N_SCREEN) as Node3D
	if anchor == null:
		return
	_screen = Label3D.new()
	_screen.name = "Readout"
	_screen.pixel_size = SCREEN_PIXEL
	_screen.font_size = SCREEN_FONT
	_screen.outline_size = 0
	_screen.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_screen.shaded = false
	_screen.double_sided = false
	_screen.modulate = Cfg.COL_SCAN_IDLE
	_screen.autowrap_mode = TextServer.AUTOWRAP_OFF
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_screen.no_depth_test = false
	add_child(_screen)
	_screen.global_position = anchor.global_position


	_screen.global_rotation = Vector3(0.0, global_rotation.y - PI * 0.5, 0.0)


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func refresh_supports() -> void:
	if not is_inside_tree() or placement_preview:
		return
	if _supports != null:
		remove_child(_supports)
		_supports.queue_free()
		_supports = null
	var both:= support_xforms()
	var legs: Array [Transform3D] = both [0]
	var feet: Array [Transform3D] = both [1]
	_supports = Node3D.new()
	_supports.name = "Supports"
	_supports.top_level = true
	add_child(_supports)
	_supports.add_child(Conveyor._support_mm("Legs", ConveyorKit.leg_mesh(), legs))
	_supports.add_child(Conveyor._support_mm("Feet", ConveyorKit.foot_mesh(), feet))


func support_xforms() -> Array:
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	var yaw:= global_basis
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	for port: Vector3 in [port_in(), port_out()]:
		var centre_top:= port - Vector3.UP * Cfg.BELT_SUPPORT_ATTACH_DEPTH
		for side: float in [-1.0, 1.0]:
			var top: Vector3 = centre_top + yaw.x * (side * SUPPORT_HALF_WIDTH)
			var q:= PhysicsRayQueryParameters3D.create(top,
				top - Vector3(0, Cfg.BELT_SUPPORT_MAX_DROP, 0))
			q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
			q.exclude = own
			var hit:= space.intersect_ray(q)
			if hit.is_empty():
				continue
			var ground: Vector3 = hit ["position"]
			var drop: float = top.y - ground.y
			if drop < 0.05:
				continue
			legs.append(Transform3D(yaw.scaled_local(Vector3(1, drop, 1)), top))
			feet.append(Transform3D(yaw, ground))
	return [legs, feet]


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


func factory_tick(delta: float) -> void:
	var held:= stored
	_intake()


	starved_for = 0.0 if stored > held or not _pending.is_empty() or has_block() else starved_for + delta
	_tick_cycle(delta)
	_tick_block(delta)
	_tick_emit(delta)
	_sync_backpressure()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_apply_lamps()


	if _alarm > 0.0:
		_alarm = maxf(0.0, _alarm - delta)
	_tick_reach()
	_drive_beacon(delta)
	_tick_pings(delta)
	_tick_scan_loop(delta)
	_refresh_screen()


func full_rate() -> bool:
	if old_beacon and (_alarm > 0.0 or not banked.is_empty()):
		return true
	for age in _ping_age:
		if age >= 0.0:
			return true
	return false


func is_waiting() -> bool:
	if stored > 0 or not blocks.is_empty() or not _pending.is_empty() or not _flying.is_empty() or _outgoing > 0 or (_scan_area != null and _scan_area.has_overlapping_bodies()):
		_idle_memo.clear()
		return false


	if not banked.is_empty() and _reach_moved():
		_idle_memo.clear()
		return false


	var key:= [_cycle_left, _emit_left, _flash, _alarm,
		_alarm_angle if old_beacon else 0.0,
		banked.size(), _pings.size(), _scan_voice, _scan_gain, _scan_target,
		_busy, _drawer_open, power, power_blocked, switched_off, line_power,
		tier_index, is_held()]
	return FactoryClock.idle_router([_belt], key, _idle_memo)


func _reach_moved() -> bool:
	var d:= _player_distance()
	return d > ALARM_CLEAR if _player_near else d <= ALARM_REACH


var _idle_memo: Array = []


func _scan_emitter() -> Vector3:
	return global_position + Vector3(0, SCAN_LOOP_HEIGHT, 0)


func _tick_scan_loop(delta: float) -> void:
	if _scan_voice < 0:
		return
	_scan_gain = move_toward(_scan_gain, _scan_target, SCAN_LOOP_RAMP * delta)
	if _scan_target <= SCAN_LOOP_SILENT and _scan_gain <= SCAN_LOOP_SILENT + 0.5:
		_release_scan_loop()
		return

	Audio.loop_update(_scan_voice, _scan_emitter(), _scan_gain,
		MachinePower.loop_pitch(power))


func _release_scan_loop() -> void:
	if _scan_voice < 0:
		return
	Audio.loop_release(_scan_voice)
	_scan_voice = -1
	_scan_gain = SCAN_LOOP_SILENT
	_scan_target = SCAN_LOOP_SILENT


func _exit_tree() -> void:
	_release_scan_loop()


	if _belt != null:
		_belt.set_blocked(false)
		_belt.downstream = null


func scan_seconds() -> float:
	return Tech.scan_seconds(float(tier_data() ["scan_seconds"]))


func tier_data() -> Dictionary:
	return Cfg.SCANNER_TIERS [clampi(tier_index, 0, Cfg.SCANNER_TIERS.size() - 1)]


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.SCANNER_MK2_DRAW_KW if tier_index >= 1 else Cfg.SCANNER_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2)
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_apply_instrument_speed()


func set_switched_off(off: bool) -> void:
	switched_off = off
	set_power(line_power)


func is_switched_off() -> bool:
	return switched_off


func set_power_line(line: int) -> void:
	power_line = line


func set_power_blocked(b: bool) -> void:
	power_blocked = b


func alert_icon() -> String:
	return "power" if MachinePower.fault(power, power_blocked, power_line) != "" else ""


func _apply_instrument_speed() -> void:
	if _scan_player != null:
		_scan_player.speed_scale = power
	if _magnet_player != null:
		_magnet_player.speed_scale = power


func batch_size() -> int:
	return Tech.scan_batch(int(tier_data() ["batch"]))


func buffer_capacity() -> int:
	return Tech.scanner_buffer(int(tier_data() ["buffer"]))


func throughput() -> float:
	return float(batch_size()) / maxf(scan_seconds(), 0.001)


func is_full() -> bool:
	return stored >= buffer_capacity()


func straw_room() -> int:
	return maxi(0, buffer_capacity() - stored)


func halts_on_find() -> bool:
	return bool(tier_data().get("halt", false))


func is_held() -> bool:
	return halts_on_find() and not banked.is_empty()


func block_seconds() -> float:
	var base:= float(Cfg.SCANNER_TIERS [0] ["scan_seconds"])
	var ratio:= float(tier_data() ["scan_seconds"]) / maxf(base, 0.001)
	return Tech.scanner_block_seconds(Cfg.SCANNER_BLOCK_SECONDS * ratio)


func has_block() -> bool:
	return not blocks.is_empty()


func _block_waiting() -> bool:
	if blocks.is_empty():
		return false
	return float(blocks [0].get("left", 0.0)) <= 0.0


func is_scanning() -> bool:
	return _cycle_left > 0.0


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead


	if is_held():
		return tr("NEEDLE FOUND  ·  the line is held until you empty the drawer")
	if is_scanning():
		return ""


	if _outgoing >= batch_size() or _block_waiting():
		return tr("OUTFEED BACKED UP  ·  the belt out of here is not moving")
	if starved_for >= Cfg.MACHINE_STARVED_AFTER:
		return tr("NO HAY  ·  nothing is reaching the intake")
	return ""


func alert_tip() -> String:
	if not is_held():
		return ""
	return tr("TIP  ·  a %s does not stop the belt") % tr(str(
		Cfg.SCANNER_TIERS [Cfg.SCANNER_TIERS.size() - 1] ["name"]))


func _has_work() -> bool:


	if is_held():
		return false
	if _outgoing >= batch_size():
		return false
	return stored > 0 or not _pending.is_empty()


func _maybe_start_cycle() -> void:
	if _cycle_left <= 0.0 and _has_work():
		_start_cycle()


func _brought_in(rb: RigidBody3D) -> bool:
	return BeltPath.is_rider(rb) and rb.get_meta(LiveStrandManager.META_RIDER) == _belt


func _eats_record(_kind: int, _strands: int) -> bool:
	return true


func _intake_records() -> void:
	if _belt == null or not _belt.records_props:
		return
	var rec:= _belt.take_record(_eats_record, 0.0,
		_belt.s_at(port_in() + forward() * INTAKE_LENGTH))
	if rec.is_empty():
		return
	var kind:= int(rec ["kind"])
	var needle:= int(rec ["needle"])
	if kind == BeltRun.Kind.WAD or kind == BeltRun.Kind.TUFT:
		stored += int(rec ["strands"])
		if needle >= 0:
			_pending.append(needle)
		_maybe_start_cycle()
		return


	var state: Variant = rec.get("state")
	var spec: Dictionary = (state as Dictionary).duplicate() if state is Dictionary else { }
	spec.erase("needle")
	blocks.append({
		"id": BeltRun.ITEM_IDS [kind],
		"state": spec,
		"strands": int(rec ["strands"]),
		"needle": needle,
		"left": block_seconds(),
	})
	Audio.play_3d("machine_thud", port_in(), -9.0)
	_sync_backpressure()


func _intake() -> void:
	if live == null or _scan_area == null:
		return


	_intake_records()


	if not _scan_area.has_overlapping_bodies():
		return
	for body in _scan_area.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		var wad:= rb as HayWad
		var solid:= rb as Carryable
		if wad == null and solid != null and solid.can_rip():


			if has_block() and not _brought_in(solid):
				continue
			_take_block(solid)
			continue
		if wad != null:
			if wad.freeze and not BeltPath.is_rider(wad):
				continue


			if is_full() and not _brought_in(wad):
				continue
			stored += wad.strands


			if wad.holds_needle():
				_pending.append(wad.needle_index)


			BeltPath.release(wad)
			if props != null:
				props.remove(wad)
			else:
				wad.queue_free()
			_maybe_start_cycle()
			continue
		if not (rb.collision_layer & Cfg.L_STRAND):
			continue


		if rb.freeze and not BeltPath.is_rider(rb) and not LiveStrandManager.is_pinned(rb):
			continue
		var is_needle:= rb.has_meta("needle_index")


		if is_full() and not is_needle and not _brought_in(rb):
			continue


		BeltPath.release(rb)
		if is_needle:
			var index:= int(rb.get_meta("needle_index", -1))
			if live.consume_needle(rb):
				_pending.append(index)


				_maybe_start_cycle()
			continue
		if live.consume(rb):
			stored += 1

			_maybe_start_cycle()


func _start_cycle() -> void:
	_cycle_left = scan_seconds()


	_apply_lamps()


	if _scan_voice < 0:
		_scan_voice = Audio.loop_acquire("scanner")
		_scan_gain = SCAN_LOOP_SILENT
		Audio.play_3d("machine_clunk", _scan_emitter(), -11.0)
	_scan_target = SCAN_LOOP_DB


	_run_instruments()


func _tick_cycle(delta: float) -> void:
	if _cycle_left <= 0.0:
		_maybe_start_cycle()
		return


	_cycle_left -= delta * power
	if _cycle_left > 0.0:
		return
	_cycle_left = 0.0
	var took:= mini(batch_size(), stored)
	stored -= took
	_outgoing += took


	for index in _pending:
		_bank(index)
	_pending = PackedInt32Array()
	if _has_work():
		_start_cycle()
		return


	_scan_target = SCAN_LOOP_SILENT
	Audio.play_3d("machine_vent", _scan_emitter(), -15.0)
	_park_instruments()
	_apply_lamps()


func _take_block(item: Carryable) -> void:


	if item.freeze and not BeltPath.is_rider(item):
		return


	BeltPath.release(item)
	var state: Dictionary = item.to_state()
	blocks.append({
		"id": item.item_id,
		"state": state,


		"strands": item.hay_strands(),
		"needle": item.needle_index,
		"left": block_seconds(),
	})
	if props != null:
		props.remove(item)
	else:
		item.queue_free()


	Audio.play_3d("machine_thud", port_in(), -9.0)
	_sync_backpressure()


func _tick_block(delta: float) -> void:
	if blocks.is_empty():
		return
	var head: Dictionary = blocks [0]
	var left:= float(head.get("left", 0.0))
	if left > 0.0:


		head ["left"] = maxf(left - delta * power, 0.0)
		if head ["left"] > 0.0:
			return


	var index:= int(head.get("needle", -1))
	if index >= 0:
		_bank(index)
		head ["needle"] = -1


	if is_held():
		return
	if props == null:
		return


	var at:= port_out() - forward() * OUTPUT_LEAD + Vector3.UP * OUTPUT_LIFT
	if _belt != null and not _belt.has_room_near(at):
		return
	if not HayWad.room_at(_space(), at, Cfg.WAD_MAX_STRANDS):
		return


	if _belt != null and _belt.records_props:
		var kind:= BeltRun.ITEM_IDS.find(String(head.get("id", "")))
		if kind >= 0:
			var state: Variant = head.get("state", { })
			var spec: Dictionary = (state as Dictionary).duplicate() if state is Dictionary else { }
			spec.erase("needle")
			var strands:= int(head.get("strands", spec.get("strands", 0)))
			var seq:= _belt.push_record(kind, strands, -1, spec, at,
				Tech.belt_speed() * 0.5)
			if seq < 0:
				return
			blocks.remove_at(0)
			_sync_backpressure()
			return
	var item:= props.spawn(String(head.get("id", "")),
		Transform3D(global_basis.orthonormalized(), at),
		head.get("state", { }))
	if item == null:
		return
	item.linear_velocity = forward() * Tech.belt_speed() * 0.5
	blocks.remove_at(0)
	_sync_backpressure()


func _tick_emit(delta: float) -> void:
	if _outgoing <= 0:
		return


	if is_held():
		return
	_emit_left -= delta
	if _emit_left > 0.0:
		return
	var at:= port_out() - forward() * OUTPUT_LEAD + Vector3.UP * OUTPUT_LIFT


	var count: int = mini(_outgoing, Cfg.WAD_MAX_STRANDS)
	if count >= Cfg.WAD_MIN_STRANDS and props != null:


		if _belt != null and not _belt.has_room_near(at):
			return
		if not HayWad.room_at(_space(), at, count):
			return
		if _belt != null and _belt.records_props:


			if _belt.push_record(BeltRun.Kind.WAD, count, -1, { "strands": count }, at,
					Tech.belt_speed() * 0.5) < 0:
				return
		else:
			var wad:= props.spawn("hay_wad", Transform3D(global_basis.orthonormalized(), at),
				{ "strands": count }) as HayWad
			if wad == null:
				return
			wad.linear_velocity = forward() * Tech.belt_speed() * 0.5
		_outgoing -= count


		_emit_left = (Cfg.WAD_CLEAR * HayWad.scale_for(count)
			/ maxf(Tech.belt_speed(), 0.001))
		return
	if live == null:
		return


	if not live.has_headroom():
		return
	if _belt != null and not _belt.has_room_near(at):
		return
	var body:= live.spawn(at, StrandFactory.random_strand_basis(_rng),
		forward() * Tech.belt_speed() * 0.5, StrandFactory.random_tint(_rng))
	if body == null:
		return
	_outgoing -= 1
	_emit_left = Tech.scanner_output_spacing()


func _space() -> PhysicsDirectSpaceState3D:
	if not is_inside_tree():
		return null
	return get_world_3d().direct_space_state


func _sync_backpressure() -> void:
	if _belt == null:
		return
	var held:= is_held()
	var shut:= is_full() or has_block() or held
	if _belt.is_blocked() != shut:
		_belt.set_blocked(shut)
		_show_belt_held(shut)
	_belt.set_outlet_held(held)


func _show_belt_held(held: bool) -> void:
	if _belt == null:
		return
	_belt.set_deck_held(held)


func _bank(index: int) -> void:
	banked.append(index)
	_flash = Cfg.SCANNER_FIND_FLASH
	_apply_lamps()


	if _player_near:
		_sound_alarm()
	else:
		_alarm = Cfg.SCANNER_ALARM_SECONDS
		_set_alarm_visible(true)


	_emit_ping()


	Audio.play_3d("needle_ting", global_position + Vector3(0, 1.2, 0), -4.0)
	caught.emit(index, global_position + Vector3(0, 1.2, 0))


func _apply_lamps() -> void:
	var lit:= _flash > 0.0 or not banked.is_empty()
	var colour:= Cfg.COL_SCAN_FIND if lit else Cfg.COL_SCAN_IDLE
	var gain:= FLASH_GAIN if lit else 1.0
	_set_lamp(MAT_GLOW, colour, GLOW_ENERGY * gain)
	_set_lamp(MAT_LASER, colour, LASER_ENERGY * gain)


	_set_lamp(MAT_BEAM, colour,
		BEAM_ENERGY * gain * (1.0 if is_scanning() else BEAM_IDLE))
	if _screen != null:
		_screen.modulate = colour


const PING_COUNT:= 3

const PING_LIFE:= 0.7


const PING_SIZE:= 1.1


const PING_LOCAL:= Vector3(0.0, -0.61, 0.0)

const N_ARM:= "Scan_PickHead"


func _mount_pings() -> void:
	if placement_preview:
		return


	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return
	if _model != null:
		_arm = _model.find_child(N_ARM, true, false) as Node3D
	if _arm == null:


		push_warning("HaystackScanner: %s has no %s; no ping" % [MODEL, N_ARM])
		return
	var shader: Shader = load(PING_SHADER)
	if shader == null:
		push_error("HaystackScanner: could not load %s" % PING_SHADER)
		return
	_ping_root = Node3D.new()
	_ping_root.name = "ScannerPings"
	add_child(_ping_root)

	var quad:= QuadMesh.new()
	quad.size = Vector2(PING_SIZE, PING_SIZE)
	for i in PING_COUNT:
		var mi:= MeshInstance3D.new()
		mi.name = "Ping%d" % i
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


		mi.extra_cull_margin = PING_SIZE
		var mat:= ShaderMaterial.new()
		mat.shader = shader
		mi.material_override = mat
		mi.visible = false
		_ping_root.add_child(mi)
		_pings.append(mi)
		_ping_age.append(-1.0)


func _pole_point() -> Vector3:
	if _arm == null:
		return global_position
	return _arm.global_transform * PING_LOCAL


func _tick_pings(delta: float) -> void:
	if _pings.is_empty():
		return


	if _arm != null and _magnet_player != null and _magnet_player.is_playing():


		var across:= to_local(_pole_point()).x
		var side:= 0
		if absf(across) > 0.004:
			side = 1 if across > 0.0 else -1
		if side != 0 and _ping_side != 0 and side != _ping_side:
			_emit_ping()
		if side != 0:
			_ping_side = side
	for i in _pings.size():
		if _ping_age [i] < 0.0:
			continue
		_ping_age [i] += delta
		if _ping_age [i] >= PING_LIFE:
			_ping_age [i] = -1.0
			_pings [i].visible = false
			continue
		_face_ping(_pings [i])
		_write_ping(i)


func _emit_ping() -> void:
	if _pings.is_empty():
		return
	var pick:= 0
	var oldest:= -1.0
	for i in _pings.size():
		if _ping_age [i] < 0.0:
			pick = i
			oldest = -1.0
			break
		if _ping_age [i] > oldest:
			oldest = _ping_age [i]
			pick = i
	_ping_age [pick] = 0.0
	_pings [pick].visible = true
	_pings [pick].global_position = _pole_point()
	_face_ping(_pings [pick])
	_write_ping(pick)


func _face_ping(mi: MeshInstance3D) -> void:
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam:= cam.global_position - mi.global_position
	if to_cam.length_squared() < 0.0001:
		return


	var up:= Vector3.UP
	if absf(to_cam.normalized().dot(up)) > 0.999:
		up = Vector3.FORWARD
	mi.look_at(cam.global_position, up)


func _write_ping(i: int) -> void:
	var mat:= _pings [i].material_override as ShaderMaterial
	if mat == null:
		return
	var t: float = clampf(_ping_age [i] / PING_LIFE, 0.0, 1.0)
	mat.set_shader_parameter("radius", lerpf(0.05, 1.0, t))
	mat.set_shader_parameter("width", lerpf(0.12, 0.035, t))
	mat.set_shader_parameter("feather", lerpf(0.1, 0.05, t))
	mat.set_shader_parameter("strength", lerpf(0.024, 0.003, t))


	mat.set_shader_parameter("fade", (1.0 - t) * (1.0 - 0.35 * t))


func _build_alarm() -> void:
	var dome:= _find_mesh("Scan_Beacon")
	if dome == null:
		push_warning("HaystackScanner: model has no Scan_Beacon; no find alarm")
		return
	var lens:= dome.get_active_material(0)
	if lens != null and not lens.get_meta(&"lamp", false):
		dome.set_surface_override_material(0, HayCompressor.lamp_material(lens))
	_beacon_meshes.clear()
	_beacon_meshes.append(dome)


	_alarm_pivot = Node3D.new()
	_alarm_pivot.name = "AlarmSpindle"
	add_child(_alarm_pivot)
	_alarm_pivot.global_position = dome.global_position

	for i in 2:
		var lobe:= SpotLight3D.new()
		lobe.name = "AlarmLobe%d" % i
		lobe.light_color = Cfg.COL_SCAN_ALARM_A if i == 0 else Cfg.COL_SCAN_ALARM_B
		lobe.light_energy = Cfg.SCANNER_ALARM_ENERGY
		lobe.spot_range = Cfg.SCANNER_ALARM_RANGE
		lobe.spot_angle = 26.0
		lobe.spot_angle_attenuation = 0.6


		lobe.shadow_enabled = false
		_alarm_pivot.add_child(lobe)


		lobe.rotation = Vector3(deg_to_rad(-12.0), PI * float(i), 0.0)
	_set_alarm_visible(false)


func _set_alarm_visible(on: bool) -> void:
	if _alarm_pivot != null and _alarm_pivot.visible != on:
		_alarm_pivot.visible = on


func _tick_reach() -> void:
	var d:= _player_distance()
	if banked.is_empty():
		_player_near = d <= ALARM_REACH
		return
	if _player_near:
		if d > ALARM_CLEAR:
			_player_near = false
		return
	if d > ALARM_REACH:
		return
	_player_near = true
	_sound_alarm()


func _player_distance() -> float:
	var found:= get_tree().get_first_node_in_group("player") as Node3D
	if found == null:
		return INF
	return found.global_position.distance_to(global_position)


func _sound_alarm() -> void:
	_alarm = Cfg.SCANNER_ALARM_SECONDS
	_set_alarm_visible(true)
	Audio.play_3d("needle", _alarm_emitter(), ALARM_DB)


func _alarm_emitter() -> Vector3:
	if _alarm_pivot != null:
		return _alarm_pivot.global_position
	return global_position + Vector3(0, 1.2, 0)


func _hush_alarm() -> void:
	if banked.is_empty():
		_alarm = 0.0


func _drive_beacon(delta: float) -> void:
	if _alarm_pivot == null:
		return
	if _alarm > 0.0 or not banked.is_empty():
		_set_alarm_visible(true)
		if old_beacon or placement_preview:
			_drive_alarm(delta)
		elif not _beacon_turning:
			_beacon_turning = true
			set_process(true)
	elif _alarm_pivot.visible:
		_set_alarm_visible(false)
		_rest_beacon()
		if _beacon_turning:
			_beacon_turning = false
			set_process(false)


func _drive_alarm(delta: float) -> void:
	if _alarm_pivot == null:
		return
	_alarm_angle = fmod(_alarm_angle + TAU * Cfg.SCANNER_ALARM_RPM * delta, TAU)
	_alarm_pivot.rotation.y = _alarm_angle
	if _beacon_meshes.is_empty():
		return
	var t:= (sin(_alarm_angle) + 1.0) * 0.5
	var colour:= Cfg.COL_SCAN_ALARM_B.lerp(Cfg.COL_SCAN_ALARM_A, t)
	HayCompressor.tint_lamps(_beacon_meshes, colour)
	HayCompressor.light_lamps(_beacon_meshes, GLOW_ENERGY * FLASH_GAIN)


func _rest_beacon() -> void:
	HayCompressor.tint_lamps(_beacon_meshes, Cfg.COL_SCAN_BEACON_REST)
	HayCompressor.light_lamps(_beacon_meshes, BEACON_REST_ENERGY)


func _find_mesh(node_name: String) -> MeshInstance3D:
	var n:= _find(node_name)
	if n is MeshInstance3D:
		return n as MeshInstance3D
	if n != null:
		for child in n.find_children("*", "MeshInstance3D", true, false):
			return child as MeshInstance3D
	return null


func _set_lamp(key: String, colour: Color, energy: float) -> void:
	if not _driven.has(key):
		return
	var meshes: Array [MeshInstance3D] = _driven [key]
	HayCompressor.tint_lamps(meshes, colour)
	HayCompressor.light_lamps(meshes, energy)


func lamp_colour(key: String) -> Color:
	if not _driven.has(key):
		return Color(0, 0, 0, 0)
	var meshes: Array [MeshInstance3D] = _driven [key]
	if meshes.is_empty():
		return Color(0, 0, 0, 0)
	return HayCompressor.driven(meshes [0], HayCompressor.LAMP_COLOUR_PARAM, Color(0, 0, 0, 0))


func beacon_colour() -> Color:
	if _beacon_meshes.is_empty():
		return Color(0, 0, 0, 0)
	return HayCompressor.driven(_beacon_meshes [0], HayCompressor.LAMP_COLOUR_PARAM, Color(0, 0, 0, 0))


func _block_word() -> String:
	if blocks.is_empty():
		return ""
	var word: String = WORD_BY_ID.get(str(blocks [0].get("id", "")), "")
	word = tr(word) if word != "" else tr("BLOCK")
	return word if blocks.size() <= 1 else "%s %d" % [word, blocks.size()]


func _refresh_screen() -> void:
	if _screen == null:
		return


	var top:= ""


	if is_held():
		top = tr("STOP", "scanner screen")
	elif is_full():
		top = tr("FULL")
	elif stored > 0 or _cycle_left > 0.0:
		top = "%d/%d" % [stored, buffer_capacity()]


	elif has_block():
		top = _block_word()
	else:
		top = tr("READY")


	var bottom:= ""
	if banked.size() >= Tech.scanner_bin_capacity():
		bottom = tr("%d FULL") % banked.size()
	elif banked.size() > 0:
		bottom = tr("%d HELD") % banked.size()
	elif _cycle_left > 0.0:
		bottom = "%.1f" % _cycle_left


	elif has_block():
		bottom = "%.1f" % float(blocks [0].get("left", 0.0))
	var line:= top if bottom.is_empty() else "%s\n%s" % [top, bottom]
	if _screen.text != line:
		_screen.text = line


func has_bank() -> bool:
	return banked.size() > 0


func is_drawer_open() -> bool:
	return _drawer_open


func prompt() -> String:
	if _drawer_open:
		return tr("close the drawer")
	if banked.is_empty():
		return ""
	var take:= tr_n("collect %d needle", "collect %d needles", banked.size()) % banked.size()


	return tr("%s and start the line") % take if is_held() else take


func console_position() -> Vector3:
	var anchor:= _find(N_SCREEN) as Node3D
	return anchor.global_position if anchor != null else global_position


func dispense() -> void:
	if placement_preview or _busy:
		return
	if _drawer_open:
		close_drawer()
		return
	if banked.is_empty():
		return
	await open_drawer()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_spill()


func open_drawer() -> void:
	if placement_preview or _busy or _drawer_open:
		return
	_busy = true
	_drawer_open = true
	_play(_drawer_player, ANIM_DRAWER)
	Audio.play_3d("build_place", console_position(), -6.0)


	if _drawer_player != null and _drawer_player.is_playing():
		await _drawer_player.animation_finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_busy = false


func bin_position() -> Vector3:
	var bin:= _find(N_BIN) as Node3D
	return bin.global_position if bin != null else console_position()


func take_banked(index: int) -> bool:
	var at:= banked.find(index)
	if at < 0:
		return false
	banked.remove_at(at)
	_refresh_screen()

	_apply_lamps()
	_hush_alarm()
	return true


func rebank(index: int) -> void:
	if banked.has(index):
		return
	banked.append(index)
	_refresh_screen()
	_apply_lamps()


func close_drawer() -> void:
	if _drawer_player == null:
		_drawer_open = false
		return
	_busy = true

	for name in _drawer_player.get_animation_list():
		if name == ANIM_DRAWER or name.ends_with("/" + ANIM_DRAWER):
			_drawer_player.play_backwards(name)
			break
	if _drawer_player.is_playing():
		await _drawer_player.animation_finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_drawer_open = false
	_busy = false


func _spill() -> void:
	if banked.is_empty():
		return
	var at:= bin_position()
	var n:= banked.size()
	var owed:= banked


	banked = PackedInt32Array()


	_flying.append_array(owed)
	_refresh_screen()

	_apply_lamps()
	_hush_alarm()
	for i in owed.size():
		_fly_to_player(owed [i], at, float(i) * FLIGHT_STAGGER)
	Audio.play_3d("needle_ting", at, -6.0)
	dispensed.emit(n)


func _fly_to_player(index: int, from: Vector3, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self) or not is_inside_tree():


			return
	var target:= _player_chest()
	var flight:= DiscoveryFlight.spawn(self, GameState.type_of(index), from,
		target, NeedleCabinet.type_colour(GameState.type_of(index)))


	flight.arrived.connect(func(_t: int) -> void:
		GameState.deposit_needle(index, target)
		_landed(index))


func _landed(index: int) -> void:
	var at:= _flying.find(index)
	if at >= 0:
		_flying.remove_at(at)


func _player_chest() -> Vector3:
	var found:= get_tree().get_first_node_in_group("player") as Node3D
	if found == null:
		return console_position()
	return found.global_position + Vector3(0, PLAYER_CATCH_HEIGHT, 0)


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return float(tier_data() ["cost"])


func to_dict() -> Dictionary:
	return {
		"type": "haystack_scanner",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,
		"tier": tier_index,
		"paid": build_cost(),


		"banked": _all_needles(),


		"stored": stored + _outgoing,


		"blocks": blocks,
	}


func _all_needles() -> PackedInt32Array:
	var out:= PackedInt32Array()
	out.append_array(banked)
	out.append_array(_pending)
	out.append_array(_flying)
	return out
