class_name HayDrone
extends Node3D


const PAD_RADIUS:= 1.15


const POST_RADIUS:= 1.42


const POST_HEIGHT:= 1.1


const LAUNCH_SPIN:= 0.65


const AIM_HEIGHT:= 1.3
const AIM_RADIUS:= PAD_RADIUS

const MODEL:= "res://assets/models/compiled/hay_drone.scn"


const SPEC:= "res://assets/models/hay_drone_materials.json"


const SHADER:= "res://assets/stand_surface.gdshader"


const MARK_HALF_W:= 0.34
const MARK_HALF_H:= 0.46
const MARK_STROKE:= 0.135
const MARK_THICK:= 0.04
const MARK_Y:= 0.11

const N_BODY:= "Drone_Body"
const N_HOOK:= "Hook"
const N_CABLE:= "Cable"
const N_CABLE_TOP:= "Marker_CableTop"
const N_CARGO:= "Marker_Cargo"
const N_GRAB:= "Marker_Grab"
const ROTORS:= ["Rotor_FL", "Rotor_FR", "Rotor_BL", "Rotor_BR"]


const ROTOR_SPIN:= { "Rotor_FL": 1.0, "Rotor_BR": 1.0, "Rotor_FR": -1.0, "Rotor_BL": -1.0 }

const CLIP_HATCH:= "HatchOpen"
const CLIP_CLAW:= "ClawOpen"


const CLIP_PARTS:= {
	CLIP_HATCH: ["Hatch_L", "Hatch_R"],
	CLIP_CLAW: ["Claw_1", "Claw_2", "Claw_3"],
}


const META_CLAIM:= PropManager.META_CLAIM


const ARRIVE_XZ:= 0.12


const ARRIVE_Y:= 0.04


const G:= 9.8


const STILL_SPEED:= 0.35
const STILL_SPIN:= 1.2


const STOLEN_GAP:= 0.35


const STOLEN_FRAMES:= 12


const HOLD_TOLERANCE:= 0.8


const HOVER_GAP:= 2.0


const PILE_CLEAR:= 2.2

const PLAN_OVERHEAD:= "overhead"
const PLAN_COVERED:= "covered"
const PLAN_NO_WAY:= "no way"
const PLAN_DROP:= "drop"


const REFUSED_RETRY:= 30.0


const ROUND_RISE:= 12.0
const ROUND_STEP:= 0.5


const REFUSED_WAIT:= 2.0

const COVERED_MSEC:= 10000


const LIFT_OFF:= 0.05

const SHAFT_WIDTH:= 0.7
const SHAFT_START:= 0.8


const AIR_SLACK:= 0.02


const CLEAR_STEP:= Cfg.CELL * 4.0

enum Phase {
	IDLE, LAUNCH, TO_PICK, DESCEND, LOWER, GRAB, LIFT, CLIMB,
	TO_DROP, DROP_DOWN, DELIVER, RELEASE, RECOVER, RISE, HOME, LAND,
}


enum Mode { DIG, COLLECT }


enum Drop { NONE, BELT, STAIRS, FLOOR }


const COLLECT_KINDS:= ["loose", "wad", "bale", "brick", "foiled", "pulp", "roll", "disc"]


const ZONE_STEP:= 0.5

const ZONE_MIN:= 1.5


const H_SEP:= 3.2
const HARD_SEP:= 2.3


const WAY_SEP:= 3.1


const LOOK:= 16.0
const CPA_HORIZON:= 2.5


const POINT_GAP:= 3.6


const DROP_GAP:= 1.2


const DODGE_AFTER:= 2.0


const IDLE_LOOK:= 2.5


const FLOOR_SPREAD:= 0.7
const FLOOR_HEAP:= 1.1


const DIG_FLOOR:= 0.03


var placement_preview:= false


var props: PropManager


var stand: HaySellingStand


var field: HayField


var builds: BuildManager

var live: LiveStrandManager


var mode: int = Mode.DIG
var zone_at:= Vector3.INF
var zone_r:= 3.0
var drop_at:= Vector3.INF
var drop_kind: int = Drop.NONE

var takes: int = 0

var trips:= 0


var plans:= 0
var near_misses:= 0
var held_for:= 0.0

var strands_put:= 0

var lanes_used:= 0


static var cost_plan_us:= 0
static var cost_plan_worst:= 0
static var cost_pick_us:= 0
static var cost_pick_worst:= 0
static var cost_traffic_us:= 0
static var cost_traffic_worst:= 0

static var cost_frame_us:= 0


var paid_cost:= -1.0

var _model: Node3D
var _hook: Node3D
var _cable: Node3D
var _cargo: Node3D
var _grab: Node3D

var _hatch_anim: AnimationPlayer
var _claw_anim: AnimationPlayer
var _rotors: Array [Node3D] = []


var _body: Node3D


var _body_rest:= Transform3D.IDENTITY
var _pad_body: StaticBody3D
var _ring: MeshInstance3D


var _ring_mat: StandardMaterial3D


var _cable_top:= 0.66
var _hook_stow:= 0.5

var _phase: Phase = Phase.IDLE
var _scan_left:= 0.0


static var _scan_frame:= -1
static var _plan_frame:= -1

static var _fleet: Array [HayDrone] = []
static var _traffic_frame:= -1


var _leg_y:= PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _drop_hover_y:= 0.0
var _route_dirty:= true

var _route_why:= ""


var _pick:= Vector3.INF
var _pick_dig:= false

var _pick_hover:= 0.0

var _cruise_y:= 0.0

var _spot:= Vector3.INF

var _wait_traffic:= false

static var _close: Dictionary = { }

var _rise_y:= 0.0
var _after_rise: Phase = Phase.HOME

var _at_drop:= false

var _col_ok:= false


var _covered:= { }


var _clock:= 0.0

var _drop_run: BeltPath

var _floor_slot:= 0

var _wait:= ""


var _cap:= INF
var _blocker: HayDrone = null
var _goal_dir:= Vector2.ZERO

var _goal_left:= 0.0
var _blocked_for:= 0.0
var _dodge:= 0.0
var _dodge_want:= 0.0


var _detour:= Vector3.INF
var _unblocked_for:= 0.0


var _job_marks: Node3D
var _job_key:= ""
var _job_left:= 0.0
var _job_shown:= false
var _job_redraw:= 0.0
static var _job_mats: Dictionary = { }


static var _air_size:= Vector3.ZERO
static var _air_centre:= Vector3.ZERO


var _stall:= ""
var _drop:= 0.0


var _grab_local:= -0.327
var _cargo_local:= -0.237
var _rotor_rate:= 0.0
var _rotor_target:= 0.0


var _throttle:= 1.0


var _vel:= Vector3.ZERO


var _flew_xz:= false
var _flew_y:= false

var _last_vel:= Vector3.ZERO


var _lean:= Vector3.ZERO


var _bob:= 0.0


var _fly_voice:= -1

var _ports: Array [Node3D] = []
var _fly_gain:= ROTOR_SILENT_DB


var _claw_state:= false
var _hatch_state:= false
var _heading:= 0.0
var _target: Node3D = null
var _held: Node3D = null

var _held_layer:= 0


var _carry_mark:= Vector3.INF
var _stolen_for:= 0


var _releases:= 0


const FLY_RANGE:= 24.0


const FLY_RESERVE:= 4
const ROTOR_DB:= -11.0
const ROTOR_SILENT_DB:= -80.0


const ROTOR_RAMP_DB:= 60.0


const ROTOR_PITCH_IDLE:= 0.72
const ROTOR_PITCH_FULL:= 1.0


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()


	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_rebuild_ring)
	if placement_preview:
		set_process(false)
		set_physics_process(false)
		_build_ring()
		set_preview_valid(true)
		return
	_build_pad()
	_build_aim_volume()
	add_to_group("hay_drones")
	_apply_winch()
	_measure_airframe()
	if takes == 0:
		takes = collect_all()
	_fleet.append(self)


	if builds != null and not builds.changed.is_connected(_on_yard_changed):
		builds.changed.connect(_on_yard_changed)


	_scan_left = randf() * Cfg.DRONE_SCAN_INTERVAL


func _exit_tree() -> void:


	_let_go(Vector3.ZERO)
	_unclaim(_target)
	_fleet.erase(self)


	_release_fly_loop()


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_warning("HayDrone: no model at %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	_skin()

	_body = _model.find_child(N_BODY, true, false) as Node3D
	if _body != null:
		_body_rest = _body.transform
	_hook = _model.find_child(N_HOOK, true, false) as Node3D
	_cable = _model.find_child(N_CABLE, true, false) as Node3D
	_cargo = _model.find_child(N_CARGO, true, false) as Node3D
	_grab = _model.find_child(N_GRAB, true, false) as Node3D
	for n in ROTORS:
		var r:= _model.find_child(n, true, false) as Node3D
		if r != null:
			_rotors.append(r)

	var top:= _model.find_child(N_CABLE_TOP, true, false) as Node3D
	if top != null:
		_cable_top = top.position.y
	if _hook != null:
		_hook_stow = _hook.position.y
	if _grab != null:
		_grab_local = _grab.position.y
	if _cargo != null:
		_cargo_local = _cargo.position.y
	_drop = maxf(_cable_top - _hook_stow, 0.001)
	_bob = float(get_instance_id() % 977) * 0.0143

	_split_players()


func _split_players() -> void:
	var src:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		push_warning("HayDrone: the model arrived without an AnimationPlayer")
		return
	src.stop()
	_hatch_anim = _lift_clip(src, CLIP_HATCH)
	_claw_anim = _lift_clip(src, CLIP_CLAW)


	src.get_parent().remove_child(src)
	src.queue_free()


func _lift_clip(src: AnimationPlayer, clip: String) -> AnimationPlayer:
	if not src.has_animation(clip):
		push_warning("HayDrone: the model has no %s clip" % clip)
		return null
	var anim: Animation = src.get_animation(clip).duplicate(true)
	_trim(anim, CLIP_PARTS.get(clip, []))
	var lib:= AnimationLibrary.new()
	lib.add_animation(clip, anim)
	var root:= src.get_node_or_null(src.root_node)
	var ap:= AnimationPlayer.new()
	ap.name = "Anim_%s" % clip
	src.get_parent().add_child(ap)
	if root != null:
		ap.root_node = ap.get_path_to(root)
	ap.add_animation_library("", lib)
	return ap


static func _trim(anim: Animation, parts: Array) -> void:
	for i in range(anim.get_track_count() - 1, -1, -1):
		var np:= anim.track_get_path(i)
		var leaf: StringName = &"" if np.get_name_count() == 0 else np.get_name(np.get_name_count() - 1)
		if not parts.has(leaf):
			anim.remove_track(i)


func _skin() -> void:
	if _model == null:
		return
	var spec:= _spec_table()
	if spec.is_empty():
		push_warning("HayDrone: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for mesh in _meshes(_model):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = _surface(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("HayDrone: no table entry for %s" % ", ".join(missed.keys()))


static func _surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	return HayCompressor.shared_material(MODEL, key,
		func() -> Material: return HayCompressor.make_material(key, spec, shader))


static func _lamp_surface(spec: Dictionary, shader: Shader) -> Material:
	var build:= func() -> Material:
		return HayCompressor.lamp_material(HayCompressor.make_material("M_DR_Glow", spec, shader))
	return HayCompressor.shared_material(MODEL, "lamp M_DR_Glow", build)


static var _parts: Dictionary = { }


static func _part(key: String, build: Callable) -> Mesh:
	if not HayCompressor.materials_shared():
		return build.call()
	if not _parts.has(key):
		_parts [key] = build.call()
	return _parts [key]


static var _spec_cache: Dictionary = { }


static func _spec_table() -> Dictionary:
	if not _spec_cache.is_empty():
		return _spec_cache


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_spec_cache = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_spec_cache = parsed
	return _spec_cache


static func _meshes(root: Node) -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		for c in n.get_children():
			stack.append(c)
	return out


func _build_pad() -> void:
	_pad_body = StaticBody3D.new()
	_pad_body.name = "Pad"
	_pad_body.collision_layer = Cfg.L_BUILD
	_pad_body.collision_mask = 0
	add_child(_pad_body)

	var shape:= CollisionShape3D.new()
	var cyl:= CylinderShape3D.new()
	cyl.radius = PAD_RADIUS
	cyl.height = 0.12
	shape.shape = cyl
	shape.position.y = 0.06
	_pad_body.add_child(shape)

	var spec:= _spec_table()
	var shader: Shader = load(SHADER)
	var deck:= MeshInstance3D.new()
	var cut_disc:= func() -> Mesh:
		var disc:= CylinderMesh.new()
		disc.top_radius = PAD_RADIUS
		disc.bottom_radius = 1.22
		disc.height = 0.12
		disc.radial_segments = 28
		return disc
	deck.mesh = _part("pad deck", cut_disc)
	deck.position.y = 0.06
	var frame:= _surface("M_DR_Frame", spec, shader)
	if frame != null:
		deck.material_override = frame
	_pad_body.add_child(deck)

	var mark:= MeshInstance3D.new()
	var cut_band:= func() -> Mesh:
		var band:= TorusMesh.new()
		band.inner_radius = 0.72
		band.outer_radius = 0.88
		band.rings = 24
		band.ring_segments = 8
		return band
	mark.mesh = _part("pad band", cut_band)
	mark.position.y = 0.125
	var trim:= _surface("M_DR_Trim", spec, shader)
	if trim != null:
		mark.material_override = trim
	_pad_body.add_child(mark)


	var paint:= _surface("M_DR_Mark", spec, shader)
	var leg:= Vector3(MARK_STROKE, MARK_THICK, MARK_HALF_H * 2.0)
	var centres: Array [Vector3] = [
		Vector3(- MARK_HALF_W, MARK_Y, 0.0),
		Vector3(MARK_HALF_W, MARK_Y, 0.0),
		Vector3(0.0, MARK_Y, 0.0),
	]
	var sizes: Array [Vector3] = [
		leg, leg, Vector3(MARK_HALF_W * 2.0, MARK_THICK, MARK_STROKE),
	]
	for i in centres.size():
		var glyph:= MeshInstance3D.new()
		glyph.mesh = _box(sizes [i])
		glyph.position = centres [i]
		if paint != null:
			glyph.material_override = paint
		_pad_body.add_child(glyph)


func _build_aim_volume() -> void:
	var cyl:= CylinderShape3D.new()
	cyl.radius = AIM_RADIUS
	cyl.height = AIM_HEIGHT
	var shape:= CollisionShape3D.new()
	shape.name = "AimShape"
	shape.shape = cyl
	shape.position.y = AIM_HEIGHT * 0.5

	var aim:= Area3D.new()
	aim.name = "AimVolume"
	aim.collision_layer = Cfg.L_BUILD
	aim.collision_mask = 0
	aim.monitoring = false
	aim.add_child(shape)
	add_child(aim)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "RadiusRing"
	_ring.mesh = _ring_part(radius())
	_ring.position.y = Cfg.DRONE_RING_LIFT


	if placement_preview:
		_ring_mat = _new_ring_mat(COL_REACH)
	else:
		_ring_mat = HayCompressor.shared_material(MODEL, "reach ring",
			func() -> Material: return _new_ring_mat(COL_REACH)) as StandardMaterial3D
	_ring.material_override = _ring_mat
	add_child(_ring)


static func _new_ring_mat(colour: Color) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = colour
	return m


static func _ring_part(r: float) -> Mesh:
	return _part("ring %.4f %.4f" % [r, Cfg.DRONE_RING_BAND],
		func() -> Mesh: return ring_mesh(r, Cfg.DRONE_RING_BAND))


func _on_tech_changed(_id: String, _rank: int) -> void:
	_rebuild_ring()


func _rebuild_ring() -> void:
	if not is_instance_valid(_ring):
		return
	_ring.mesh = _ring_part(radius())


const COL_REACH:= Color(0.4, 0.78, 1.0, 0.42)


func show_range(on: bool) -> void:
	if not on:
		if is_instance_valid(_ring):
			_ring.visible = false
		return
	if not is_instance_valid(_ring):
		_build_ring()
	_ring.visible = true


static func ring_mesh(radius: float, band: float, segments: int = 96) -> ArrayMesh:
	var verts:= PackedVector3Array()
	var idx:= PackedInt32Array()
	var inner:= maxf(radius - band * 0.5, 0.01)
	var outer:= radius + band * 0.5
	for i in segments + 1:
		var a:= TAU * float(i) / float(segments)
		var c:= Vector3(cos(a), 0.0, sin(a))
		verts.append(c * inner)
		verts.append(c * outer)
	for i in segments:
		var o:= i * 2
		idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_INDEX] = idx
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func set_preview_valid(valid: bool) -> void:
	var tint: Color = Cfg.COL_GHOST_OK if valid else Cfg.COL_GHOST_BAD

	if _ring_mat != null and placement_preview:
		_ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	if _model == null:
		return
	var ghost:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes(_model):
		mesh.material_overlay = ghost


func _process(delta: float) -> void:
	if _model == null:
		return
	var frame_began:= Time.get_ticks_usec()
	_frame(delta)
	cost_frame_us += Time.get_ticks_usec() - frame_began


func _frame(delta: float) -> void:
	_clock += delta
	_flew_xz = false
	_flew_y = false


	_power_out()
	var work:= delta * _drive()


	var frame:= Engine.get_process_frames()
	if _traffic_frame != frame:
		_traffic_frame = frame
		var began:= Time.get_ticks_usec()
		_traffic(delta)
		var took:= Time.get_ticks_usec() - began
		cost_traffic_us += took
		cost_traffic_worst = maxi(cost_traffic_worst, took)
	_spin_rotors(delta)
	_tick_fly_loop(delta)
	_tick_job_marks(delta)
	match _phase:
		Phase.IDLE: _tick_idle(work)
		Phase.LAUNCH: _tick_launch(work)
		Phase.TO_PICK: _tick_to_pick(work)
		Phase.DESCEND: _tick_descend(work)
		Phase.LOWER: _tick_lower(work)
		Phase.GRAB: _tick_grab(work)
		Phase.LIFT: _tick_lift(work)
		Phase.CLIMB: _tick_climb(work)
		Phase.TO_DROP: _tick_to_drop(work)
		Phase.DROP_DOWN: _tick_drop_down(work)
		Phase.DELIVER: _tick_deliver(work)
		Phase.RELEASE: _tick_release(work)
		Phase.RECOVER: _tick_recover(work)
		Phase.RISE: _tick_rise(work)
		Phase.HOME: _tick_home(work)
		Phase.LAND: _tick_land(work)


	_coast(work)
	_model.position += _vel * work
	_attitude(work)
	_carry()


func _go(p: Phase) -> void:
	_phase = p
	_col_ok = false
	_detour = Vector3.INF


func _tick_idle(delta: float) -> void:
	_rotor_target = 0.0
	_scan_left -= delta
	if _scan_left > 0.0:
		return


	var frame:= Engine.get_process_frames()
	if _scan_frame == frame:
		return
	_scan_frame = frame
	_scan_left = IDLE_LOOK
	var fault:= _job_fault()
	if fault != "":
		_stall = fault
		return
	if _route_dirty or _route_why != "":
		_plan_route()


		if _route_why != "":
			_stall = _route_sign()
			_scan_left = REFUSED_RETRY
		else:
			_scan_left = 0.0
		return
	var pick:= _find_pick()
	if pick.is_empty():


		_stall = ""
		return
	_stall = ""
	_start_trip(pick)
	_cruise_y = _leg_y [0]
	_go(Phase.LAUNCH)


func _tick_launch(delta: float) -> void:
	_rotor_target = 1.0


	if power <= 0.0 or _rotor_rate < LAUNCH_SPIN * power:
		return
	if not _pick_alive():
		_unclaim(_target)
		_target = null
		_go(Phase.LAND)
		return
	if not _column_clear(_model.global_position.y, _cruise_y):
		return
	if _climb_to(_cruise_y - global_position.y, delta):
		_go(Phase.TO_PICK)


func _tick_to_pick(delta: float) -> void:
	if not _pick_alive():
		_abort()
		return
	_cruise(delta)
	if _fly_leg(_pick_point(), delta):
		_go(Phase.DESCEND)


func _tick_descend(delta: float) -> void:
	if not _pick_alive():
		_abort()
		return


	var at:= _pick_point()
	_fly_to(at, delta)
	var want:= _pick_hover
	if not _column_clear(_model.global_position.y, want):
		return
	if _climb_to(want - global_position.y, delta):
		_go(Phase.LOWER)
		_play(CLIP_HATCH, true)


func _tick_lower(delta: float) -> void:
	if not _pick_alive():
		_abort()
		return
	if _mech_busy():
		return
	if not _claw_state:
		_play(CLIP_CLAW, true)
		return


	if _pick_dig and field != null:
		_pick.y = _ground_at(_pick)
	var reach:= _drop_for(_grab_local, _pick_point().y)
	if _winch_to(reach, delta):
		_go(Phase.GRAB)
		_play(CLIP_CLAW, false)


func _tick_grab(_delta: float) -> void:
	if _mech_busy():
		return
	var got: Node3D = null
	if _pick_dig:
		got = _dig_bite(_pick)
	elif _still_valid(_target):
		got = _gather(_target)
	if got == null:
		_abort()
		return
	_take(got)
	_at_drop = false
	_go(Phase.LIFT)


func _tick_lift(delta: float) -> void:
	if _winch_to(_stow_drop(), delta):
		_go(Phase.CLIMB)


func _tick_climb(delta: float) -> void:

	if not _column_clear(_model.global_position.y, _leg_y [1]):
		return
	if _climb_to(_leg_y [1] - global_position.y, delta):
		_cruise_y = _leg_y [1]
		_go(Phase.TO_DROP)


func _tick_to_drop(delta: float) -> void:
	var at:= _drop_point()
	if at == Vector3.INF:


		_let_go(Vector3.ZERO)
		_at_drop = false
		_go(Phase.RECOVER)
		return
	_cruise(delta)
	if _fly_leg(at, delta):
		_go(Phase.DROP_DOWN)


func _tick_drop_down(delta: float) -> void:
	var at:= _drop_point()
	if at == Vector3.INF:
		_let_go(Vector3.ZERO)
		_at_drop = true
		_go(Phase.RECOVER)
		return
	_fly_to(at, delta)
	if not _column_clear(_model.global_position.y, _drop_hover_y):
		return
	if _climb_to(_drop_hover_y - global_position.y, delta):


		_spot = Vector3.INF
		_go(Phase.DELIVER)


func _tick_deliver(delta: float) -> void:
	var at:= _drop_point()
	if at == Vector3.INF:
		_let_go(Vector3.ZERO)
		_at_drop = true
		_go(Phase.RECOVER)
		return
	if _spot == Vector3.INF:
		_spot = _choose_spot()
		if _spot == Vector3.INF:


			_wait = tr("The drop is full. Clear some space under it.")
			_fly_to(at, delta)
			return
	var over:= _fly_to(_spot, delta)
	var reach:= _drop_for(_cargo_local, _spot.y + Cfg.DRONE_DROP_CLEAR + _load_half())
	if not _winch_to(reach, delta) or not over:
		return
	if not _has_room():
		_wait = tr("No room at the drop. It waits for a gap.")
		return
	_wait = ""
	_go(Phase.RELEASE)


func _tick_release(_delta: float) -> void:
	if _mech_busy():
		return
	if not _claw_state:
		_play(CLIP_CLAW, true)
		return


	if _held != null and is_instance_valid(_held) and _cargo != null:
		if _held.global_position.distance_to(_cargo.global_position) > HOLD_TOLERANCE:
			_lose_load()
			_at_drop = true
			return
	if _held != null:
		_put_down()
		trips += 1
	_at_drop = true
	_go(Phase.RECOVER)


func _tick_recover(delta: float) -> void:
	if not _winch_to(_stow_drop(), delta):
		return
	if _mech_busy():
		return
	if _claw_state:
		_play(CLIP_CLAW, false)
		return
	if _hatch_state:
		_play(CLIP_HATCH, false)
		return
	_next_trip()


func _clock_ms() -> int:
	return int(_clock * 1000.0)


func _next_trip() -> void:
	var frame:= Engine.get_process_frames()
	if _scan_frame == frame:
		return
	_scan_frame = frame
	if _job_fault() != "" or power <= 0.0:
		_head_home()
		return


	if _route_dirty:
		_plan_route()
		if _route_why != "":
			_head_home()
		return
	if _route_why != "":
		_head_home()
		return
	var pick:= _find_pick()
	if pick.is_empty():
		_head_home()
		return
	_start_trip(pick)
	_rise_y = _safe_rise(_leg_y [2])
	_after_rise = Phase.TO_PICK
	_go(Phase.RISE)


func _head_home() -> void:
	_unclaim(_target)
	_target = null
	_rise_y = _safe_rise(_leg_y [3] if _at_drop else _leg_y [0])
	_after_rise = Phase.HOME
	_go(Phase.RISE)


func _safe_rise(want: float) -> float:
	var here:= _model.global_position
	if _at_drop:
		return want
	if want < here.y:
		return here.y
	if _sweep_clear(get_world_3d().direct_space_state, _own_bodies(), here,
			Vector3(here.x, want, here.z), _heading):
		return want
	return here.y


func _tick_rise(delta: float) -> void:
	if not _column_clear(_model.global_position.y, _rise_y):
		return
	if _climb_to(_rise_y - global_position.y, delta):
		_cruise_y = _rise_y
		_go(_after_rise)


func _tick_home(delta: float) -> void:
	_cruise(delta)
	if _fly_leg(global_position, delta):
		_go(Phase.LAND)


func _tick_land(delta: float) -> void:
	if not _column_clear(_model.global_position.y, global_position.y):
		return
	if _climb_to(0.0, delta):
		_rotor_target = 0.0
		if _rotor_rate <= 0.02:
			_go(Phase.IDLE)
			_scan_left = Cfg.DRONE_SCAN_INTERVAL


func _cruise(delta: float) -> void:
	_climb_to(_cruise_y + _dodge - global_position.y, delta)


func _job_fault() -> String:
	if zone_at == Vector3.INF or drop_at == Vector3.INF:
		return tr("NOT SET UP  ·  open its pad to give it a zone and a drop")
	if _drop_point() == Vector3.INF:
		return tr("DROP IS GONE  ·  what it dropped on was taken down, set a new drop")
	return ""


func _route_sign() -> String:
	match _route_why:
		PLAN_OVERHEAD:
			return tr("CAN'T TAKE OFF  ·  something is in the way above the pad")
		PLAN_COVERED:
			return tr("ZONE IS COVERED  ·  something is built over the zone")
		PLAN_DROP:
			return tr("CAN'T REACH THE DROP  ·  something is built over the drop")
	return tr("NO WAY THROUGH  ·  something is too tall between the pad, the zone and the drop")


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead
	if _phase != Phase.IDLE:
		return ""
	return _stall


const PLATE_WORKING:= 0
const PLATE_WAITING:= 1
const PLATE_STOPPED:= 2


func plate_status() -> Array:
	if switched_off:
		return [PLATE_STOPPED, tr("Switched off. Press the button to start it.")]
	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return [PLATE_STOPPED, dead]
	if zone_at == Vector3.INF or drop_at == Vector3.INF:
		return [PLATE_STOPPED, tr("Give it a zone to work and a drop point, with SET ZONE AND DROP.")]
	if _drop_point() == Vector3.INF:
		return [PLATE_STOPPED, tr("What it dropped on was taken down. Set a new drop point.")]
	if _route_why != "" and not _route_dirty:
		match _route_why:
			PLAN_OVERHEAD:
				return [PLATE_STOPPED, tr("Something is built over its pad, so it can't take off.")]
			PLAN_COVERED:
				return [PLATE_STOPPED, tr("Something is built over its zone, so it can't get down to it.")]
			PLAN_DROP:
				return [PLATE_STOPPED, tr("Something is built over its drop, so it can't get down to it.")]
		return [PLATE_STOPPED, tr("Something too tall stands in its way. Move the zone or the drop.")]
	if _wait_traffic:
		return [PLATE_WAITING, tr("Waiting for another drone to pass.")]
	if _wait != "":
		return [PLATE_WAITING, _wait]
	match _phase:
		Phase.IDLE:
			if mode == Mode.DIG:
				return [PLATE_WAITING, tr("Its zone is dug out. Move the zone to keep digging.")]
			return [PLATE_WAITING, tr("Nothing to pick up in its zone right now. It keeps looking.")]
		Phase.TO_DROP, Phase.DROP_DOWN, Phase.DELIVER, Phase.RELEASE:
			return [PLATE_WORKING, tr("Taking a load to the drop.")]
		Phase.HOME, Phase.LAND:
			return [PLATE_WORKING, tr("Flying home to wait for work.")]
	if mode == Mode.DIG:
		return [PLATE_WORKING, tr("Digging hay off the pile.")]
	return [PLATE_WORKING, tr("Collecting from its zone.")]


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


var _charge_lamp: MeshInstance3D = null
var _charge_glow: OmniLight3D = null


const LAMP_DARK:= Color(0.02, 0.05, 0.07)
const LAMP_LIT:= Color(0.16, 0.7, 0.95)


func lamp_energy() -> float:
	if not is_instance_valid(_charge_lamp):
		return -1.0
	var lamp: Array [MeshInstance3D] = [_charge_lamp]
	return HayCompressor.lamp_energy(lamp)


func lamp_colour() -> Color:
	return HayCompressor.driven(_charge_lamp, HayCompressor.LAMP_COLOUR_PARAM, Color.BLACK)


func rated_kw() -> float:
	return Cfg.DRONE_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		var host: Node3D = _pad_body if _pad_body != null else self
		_build_post(host)
		_ports = MachinePower.terminals(host, null, 1,
			[Vector3(POST_RADIUS, POST_HEIGHT, 0.0)])
	return _ports


func _build_post(host: Node3D) -> void:
	var post:= Node3D.new()
	post.name = "ChargePost"
	post.position = Vector3(POST_RADIUS, 0.0, 0.0)
	host.add_child(post)

	var spec:= _spec_table()
	var shader: Shader = load(SHADER)
	var frame:= _surface("M_DR_Frame", spec, shader)
	var steel:= _surface("M_DR_Steel", spec, shader)
	var shell:= _surface("M_DR_Shell", spec, shader)
	var trim:= _surface("M_DR_Trim", spec, shader)
	var cable:= _surface("M_DR_Cable", spec, shader)
	var warn:= _surface("M_DR_Warn", spec, shader)
	var lens:= _surface("M_DR_Lens", spec, shader)
	var mark:= _surface("M_DR_Mark", spec, shader)


	_post_cyl(post, 0.152, 0.18, 0.04, Vector3(0.0, 0.02, 0.0), steel)
	_post_cyl(post, 0.066, 0.152, 0.07, Vector3(0.0, 0.075, 0.0), steel)
	for k in 4:
		var a:= TAU * (float(k) + 0.5) / 4.0
		var at:= Vector3(cos(a) * 0.132, 0.0, sin(a) * 0.132)


		_post_cyl(post, 0.018, 0.018, 0.018, at + Vector3(0.0, 0.049, 0.0), steel, 6)
		_post_cyl(post, 0.008, 0.008, 0.014, at + Vector3(0.0, 0.065, 0.0), steel, 8)


	var shaft_top:= POST_HEIGHT - 0.016
	_post_cyl(post, 0.048, 0.064, shaft_top - 0.1,
		Vector3(0.0, (shaft_top + 0.1) * 0.5, 0.0), frame)


	_post_cyl(post, 0.0634, 0.0642, 0.05, Vector3(0.0, 0.21, 0.0), warn)
	_post_cyl(post, 0.0621, 0.0629, 0.05, Vector3(0.0, 0.29, 0.0), warn)


	_post_torus(post, 0.048, 0.062, Vector3(0.0, 1.045, 0.0), trim)
	_post_cyl(post, 0.074, 0.074, 0.016, Vector3(0.0, POST_HEIGHT - 0.008, 0.0), steel)


	_post_cyl(post, 0.027, 0.027, 0.026, Vector3(-0.074, 0.13, 0.0), steel, 6)
	_post_cyl(post, 0.018, 0.018, 0.475, Vector3(-0.074, 0.3525, 0.0), cable, 16)
	for y in [0.34, 0.5]:
		_post_box(post, Vector3(0.014, 0.026, 0.056), Vector3(-0.062, y, 0.0), steel)


	_post_box(post, Vector3(0.078, 0.26, 0.19), Vector3(-0.09, 0.715, 0.0), shell)
	_post_box(post, Vector3(0.095, 0.012, 0.205), Vector3(-0.093, 0.852, 0.0), frame)
	_post_box(post, Vector3(0.018, 0.224, 0.158), Vector3(-0.135, 0.715, 0.0), frame)
	for sy in [-1.0, 1.0]:
		_post_cyl(post, 0.01, 0.01, 0.036,
			Vector3(-0.128, 0.715 + sy * 0.085, 0.083), steel, 12,
			Vector3(PI * 0.5, 0.0, 0.0))
		for sz in [-1.0, 1.0]:
			_post_cyl(post, 0.0065, 0.0065, 0.01,
				Vector3(-0.147, 0.715 + sy * 0.096, sz * 0.062), steel, 8,
				Vector3(0.0, 0.0, PI * 0.5))
	_post_box(post, Vector3(0.004, 0.048, 0.096), Vector3(-0.146, 0.645, 0.0), mark)
	_post_cyl(post, 0.021, 0.021, 0.012, Vector3(-0.15, 0.8, 0.0), lens, 20,
		Vector3(0.0, 0.0, PI * 0.5))
	_charge_lamp = _post_cyl(post, 0.015, 0.015, 0.006,
		Vector3(-0.1545, 0.8, 0.0),
		_lamp_surface(spec, shader), 20,
		Vector3(0.0, 0.0, PI * 0.5))


	_charge_glow = OmniLight3D.new()
	_charge_glow.name = "ChargeGlow"
	_charge_glow.position = Vector3(-0.175, 0.8, 0.0)
	_charge_glow.omni_range = 0.85
	_charge_glow.light_color = Color(0.16, 0.7, 0.95)
	_charge_glow.shadow_enabled = false
	post.add_child(_charge_glow)
	_set_lamp()


func _post_cyl(under: Node3D, top_r: float, bottom_r: float, h: float,
		at: Vector3, m: Material, segs: int = 32,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key:= "cyl %.4f %.4f %.4f %d" % [top_r, bottom_r, h, segs]
	var cut:= func() -> Mesh:
		var cyl:= CylinderMesh.new()
		cyl.top_radius = top_r
		cyl.bottom_radius = bottom_r
		cyl.height = h
		cyl.radial_segments = segs


		cyl.rings = 1
		return cyl
	var mesh:= _part(key, cut)
	return _post_mesh(under, mesh, at, m, rot)


func _post_box(under: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	return _post_mesh(under, _box(size), at, m)


static func _box(size: Vector3) -> Mesh:
	var cut:= func() -> Mesh:
		var box:= BoxMesh.new()
		box.size = size
		return box
	return _part("box %.4f %.4f %.4f" % [size.x, size.y, size.z], cut)


func _post_torus(under: Node3D, inner: float, outer: float, at: Vector3,
		m: Material) -> MeshInstance3D:
	var cut:= func() -> Mesh:
		var torus:= TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = outer
		torus.rings = 32
		torus.ring_segments = 10
		return torus
	var mesh:= _part("torus %.4f %.4f" % [inner, outer], cut)
	return _post_mesh(under, mesh, at, m)


func _post_mesh(under: Node3D, mesh: Mesh, at: Vector3, m: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst:= MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.rotation = rot


	if m != null:
		inst.material_override = m
	under.add_child(inst)
	return inst


func _set_lamp() -> void:
	if not is_instance_valid(_charge_lamp):
		return
	var lit:= 0.0 if switched_off else clampf(power, 0.0, 1.0)
	var lamp: Array [MeshInstance3D] = [_charge_lamp]
	HayCompressor.tint_lamps(lamp, LAMP_DARK.lerp(LAMP_LIT, lit))
	HayCompressor.light_lamps(lamp, 0.05 + 1.35 * lit)
	if is_instance_valid(_charge_glow):
		_charge_glow.light_energy = 0.7 * lit
		_charge_glow.visible = lit > 0.01


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_set_lamp()


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


func _abort() -> void:
	_unclaim(_target)
	_target = null
	_at_drop = false
	_go(Phase.RECOVER)


func _power_out() -> void:
	if power > 0.0:
		return
	match _phase:
		Phase.LAUNCH:
			_unclaim(_target)
			_target = null
			_go(Phase.LAND)
		Phase.TO_PICK, Phase.DESCEND, Phase.LOWER:
			_abort()
		Phase.RISE:
			if _after_rise == Phase.TO_PICK:
				_head_home()


func _drive() -> float:
	if power <= 0.0 and _phase != Phase.IDLE:
		return 1.0
	return power


func _spin_rotors(delta: float) -> void:


	_rotor_rate = move_toward(_rotor_rate, _rotor_target * _drive(), delta * 0.5)


	_throttle = move_toward(_throttle,
		1.0 + clampf(_vel.y / Cfg.DRONE_CLIMB, -1.0, 1.0) * Cfg.DRONE_ROTOR_THROTTLE,
		delta * 2.0)
	if _rotor_rate <= 0.0:
		return
	var step:= Cfg.DRONE_ROTOR_SPEED * _rotor_rate * _throttle * delta
	for r in _rotors:
		r.rotate_y(step * float(ROTOR_SPIN.get(r.name, 1.0)))


func _tick_fly_loop(delta: float) -> void:
	var ear:= _ear()
	var flying:= _rotor_rate > 0.01 and not placement_preview
	var near:= ear != Vector3.INF and _model.global_position.distance_to(ear) <= FLY_RANGE

	if flying and near and _fly_voice < 0 and Audio.loops_available() > FLY_RESERVE:
		_fly_voice = Audio.loop_acquire("drone")
		_fly_gain = ROTOR_SILENT_DB
	if _fly_voice < 0:
		return


	var want:= ROTOR_SILENT_DB
	if flying and near:
		want = lerpf(ROTOR_SILENT_DB, ROTOR_DB, minf(_rotor_rate * 2.0, 1.0))
	_fly_gain = move_toward(_fly_gain, want, ROTOR_RAMP_DB * delta)
	if want <= ROTOR_SILENT_DB and _fly_gain <= ROTOR_SILENT_DB + 0.5:
		_release_fly_loop()
		return


	Audio.loop_update(_fly_voice, _model.global_position, _fly_gain,
		lerpf(ROTOR_PITCH_IDLE, ROTOR_PITCH_FULL, _rotor_rate) * _throttle)


func _ear() -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var cam:= get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	return cam.global_position


func _release_fly_loop() -> void:
	if _fly_voice < 0:
		return
	Audio.loop_release(_fly_voice)
	_fly_voice = -1
	_fly_gain = ROTOR_SILENT_DB


func _fly_to(world: Vector3, delta: float) -> bool:
	_flew_xz = true
	var goal:= to_local(world)
	var here:= _model.position
	var d:= Vector2(goal.x - here.x, goal.z - here.z)
	var gap:= d.length()
	_goal_left = gap
	var v:= Vector2(_vel.x, _vel.z)
	if gap <= maxf(v.length() * delta, ARRIVE_XZ):
		_model.position.x = goal.x
		_model.position.z = goal.z
		_vel.x = 0.0
		_vel.z = 0.0
		return true


	var want:= minf(Tech.drone_speed(), sqrt(2.0 * Cfg.DRONE_ACCEL * gap))


	var world_dir:= global_basis * Vector3(d.x, 0.0, d.y)
	_goal_dir = Vector2(world_dir.x, world_dir.z).normalized()
	want = minf(want, _cap)
	v = v.move_toward(d / gap * want, Cfg.DRONE_ACCEL * delta)
	_vel.x = v.x
	_vel.z = v.y


	if v.length() > 0.25:
		_heading = lerp_angle(_heading, atan2(- v.x, - v.y), clampf(delta * 3.0, 0.0, 1.0))
		_model.rotation.y = _heading
	return false


func _plan_route() -> void:
	var began:= Time.get_ticks_usec()
	_plan_route_now()
	var took:= Time.get_ticks_usec() - began
	cost_plan_us += took
	cost_plan_worst = maxi(cost_plan_worst, took)


func _plan_route_now() -> void:
	_route_dirty = false
	_route_why = ""
	plans += 1
	if _model == null or not has_job():
		_route_why = PLAN_NO_WAY
		return
	var at_drop:= _drop_point()
	if at_drop == Vector3.INF:
		_route_why = PLAN_NO_WAY
		return
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	var pad:= global_position
	var zone:= Vector3(zone_at.x, _zone_floor(), zone_at.z)


	var hay_near:= _highest_in_zone([], air_reach())
	var base:= maxf(pad.y + Cfg.DRONE_CRUISE_H,
		maxf(_zone_top(), hay_near.y if hay_near != Vector3.INF else - INF) + PILE_CLEAR)
	var ends: Array = [[pad, zone], [zone, at_drop], [at_drop, zone], [at_drop, pad]]
	for leg: Array in ends:
		base = maxf(base, _hay_under(leg [0], leg [1], zone_r) + PILE_CLEAR)


	var gap:= lane_gap()
	var ceiling:= minf(_ceiling_over(space, own, pad, base),
		minf(_ceiling_over(space, own, zone, base), _ceiling_over(space, own, at_drop, base)))
	var lanes:= clampi(int(floor((ceiling - base) / gap)) + 1, 1, 4)
	if lanes == 3:
		lanes = 2
	lanes_used = lanes
	for i in ends.size():
		var a: Vector3 = ends [i] [0]
		var b: Vector3 = ends [i] [1]
		var y:= _clear_height(space, own, a, b, base + gap * float(_lane_of(a, b, lanes)), base,
			maxf(ceiling, base))
		if is_nan(y):
			_route_why = PLAN_NO_WAY
			return
		_leg_y [i] = y


	var up_yaw:= _heading
	if not _sweep_clear(space, own, Vector3(pad.x, pad.y + LIFT_OFF, pad.z),
			Vector3(pad.x, maxf(_leg_y [0], _leg_y [3]), pad.z), up_yaw):
		_route_why = PLAN_OVERHEAD
		return


	var top:= maxf(_leg_y [1], maxf(_leg_y [2], _leg_y [3]))
	var hover:= _lowest_clear(space, own, at_drop, top, at_drop.y + HOVER_GAP,
		_yaw_along(zone, at_drop))
	var reach:= hover + _cable_top + _cargo_local - (at_drop.y + Cfg.DRONE_DROP_CLEAR + 0.4)
	if reach > Cfg.DRONE_WINCH_MAX:
		_route_why = PLAN_DROP
		return
	_drop_hover_y = hover


	for i: int in [1, 2, 3]:
		if _leg_y [i] < hover:
			_leg_y [i] = hover
			var a: Vector3 = ends [i] [0]
			var b: Vector3 = ends [i] [1]
			if not _leg_clear(space, own, a, b, hover):
				_route_why = PLAN_DROP
				return


func _clear_height(space: PhysicsDirectSpaceState3D, own: Array [RID], a: Vector3,
		b: Vector3, want: float, base: float, top: float) -> float:
	var y:= want
	while y <= minf(base + ROUND_RISE, top):
		if _leg_clear(space, own, a, b, y):
			return y
		y += ROUND_STEP
	y = want - ROUND_STEP
	while y >= base:
		if _leg_clear(space, own, a, b, y):
			return y
		y -= ROUND_STEP
	return NAN


static func _lane_of(a: Vector3, b: Vector3, lanes: int = 4) -> int:
	var d:= Vector2(b.x - a.x, b.z - a.z)
	if d.length_squared() < 1e-06 or lanes <= 1:
		return 0
	if lanes < 4:
		return 0 if d.x >= 0.0 else 1
	var angle:= atan2(d.x, - d.y)
	return int(floor((angle + TAU + PI * 0.25) / (PI * 0.5))) % 4


func _ceiling_over(space: PhysicsDirectSpaceState3D, own: Array [RID], p: Vector3,
		from_y: float) -> float:
	var reach:= ROUND_RISE + lane_gap() * 4.0
	var q:= _air_query(own, true)
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, from_y, p.z)) * Transform3D(Basis.IDENTITY, _air_centre)
	if not space.intersect_shape(q, 1).is_empty():
		return from_y
	q.motion = Vector3(0.0, reach, 0.0)
	var hit:= space.cast_motion(q)
	if hit.size() < 1:
		return from_y + reach
	return from_y + reach * hit [0]


static func v_sep() -> float:
	return maxf(_air_size.y, 0.6) + 1.0


static func lane_gap() -> float:
	return v_sep() + 0.1


func _hay_under(a: Vector3, b: Vector3, extra: float = 0.0) -> float:
	if field == null:
		return - INF
	var span:= Vector2(b.x - a.x, b.z - a.z)
	var length:= span.length()
	var side:= Vector2.ZERO
	var wide:= Vector2.ZERO
	if length > 0.001:
		var across:= Vector2(- span.y, span.x) / length
		side = across * _air_half_width()
		wide = across * (_air_half_width() + extra)
	var steps:= maxi(1, int(ceil(length / CLEAR_STEP)))
	var worst:= - INF
	for i in steps + 1:
		var t:= float(i) / float(steps)
		var p:= Vector2(a.x, a.z) + span * t
		for off: Vector2 in [Vector2.ZERO, side, - side, wide, - wide]:
			worst = maxf(worst, field.height_at(p.x + off.x, p.y + off.y))
	return worst


func _leg_clear(space: PhysicsDirectSpaceState3D, own: Array [RID], a: Vector3,
		b: Vector3, y: float) -> bool:
	var flat:= Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length:= flat.length()


	var trim:= air_reach()
	if length <= trim * 2.0:
		return true
	var dir:= flat / length
	var from:= Vector3(a.x, y, a.z) + dir * trim
	var to:= Vector3(b.x, y, b.z) - dir * trim
	return _sweep_clear(space, own, from, to, atan2(- dir.x, - dir.z))


func _sweep_clear(space: PhysicsDirectSpaceState3D, own: Array [RID], from: Vector3,
		to: Vector3, yaw: float) -> bool:


	var q:= _air_query(own, true)
	q.transform = Transform3D(Basis(Vector3.UP, yaw), from) * Transform3D(Basis.IDENTITY, _air_centre)


	if not space.intersect_shape(q, 1).is_empty():
		return false
	q.motion = to - from
	if q.motion.length_squared() < 1e-06:
		return true
	var hit:= space.cast_motion(q)
	return hit.size() < 1 or hit [0] >= 1.0


func _lowest_clear(space: PhysicsDirectSpaceState3D, own: Array [RID], at: Vector3,
		from_y: float, want_y: float, yaw: float) -> float:
	if from_y <= want_y:
		return from_y
	var q:= _air_query(own, true)
	var start:= Vector3(at.x, from_y, at.z)
	q.transform = Transform3D(Basis(Vector3.UP, yaw), start) * Transform3D(Basis.IDENTITY, _air_centre)


	if not space.intersect_shape(q, 1).is_empty():
		return from_y
	q.motion = Vector3(0.0, want_y - from_y, 0.0)
	var hit:= space.cast_motion(q)
	if hit.size() < 1 or hit [0] >= 1.0:
		return want_y
	return from_y + (want_y - from_y) * hit [0]


func _shaft_clear(space: PhysicsDirectSpaceState3D, own: Array [RID], at: Vector3,
		y: float) -> bool:
	var shaft:= BoxShape3D.new()
	shaft.size = Vector3(SHAFT_WIDTH, 0.2, SHAFT_WIDTH)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = shaft
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	q.exclude = own
	var start:= Vector3(at.x, at.y + SHAFT_START, at.z)
	q.transform = Transform3D(Basis.IDENTITY, start)
	q.motion = Vector3(0.0, maxf(0.0, y + _air_size.y - start.y), 0.0)
	var hit:= space.cast_motion(q)
	return hit.size() < 1 or hit [0] >= 1.0


func _air_query(own: Array [RID], round: bool = false) -> PhysicsShapeQueryParameters3D:
	var q:= PhysicsShapeQueryParameters3D.new()
	if round:
		var cyl:= CylinderShape3D.new()
		cyl.radius = maxf(air_reach() - AIR_SLACK, 0.05)
		cyl.height = maxf(_air_size.y - AIR_SLACK * 2.0, 0.05)
		q.shape = cyl
	else:
		var box:= BoxShape3D.new()
		box.size = (_air_size - Vector3.ONE * AIR_SLACK * 2.0).max(Vector3.ONE * 0.05)
		q.shape = box
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	q.exclude = own
	return q


static func air_reach() -> float:
	return Vector2(_air_size.x, _air_size.z).length() * 0.5


func _air_half_width() -> float:
	return maxf(_air_size.x, _air_size.z) * 0.5


static func _yaw_along(a: Vector3, b: Vector3) -> float:
	var d:= Vector2(b.x - a.x, b.z - a.z)
	if d.length_squared() < 1e-06:
		return 0.0
	return atan2(- d.x, - d.y)


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	var stack: Array [Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var co:= node as CollisionObject3D
		if co != null:
			out.append(co.get_rid())
		for kid: Node in node.get_children():
			stack.append(kid)
	return out


func _measure_airframe() -> void:
	if _air_size != Vector3.ZERO or _model == null:
		return
	var inv:= _model.global_transform.affine_inverse()
	var box:= AABB()
	var first:= true
	var stack: Array [Node] = [_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == N_HOOK or node.name == N_CABLE:
			continue
		var mi:= node as MeshInstance3D
		if mi != null and mi.mesh != null:
			var local:= (inv * mi.global_transform) * mi.mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		for kid: Node in node.get_children():
			stack.append(kid)
	if first:
		return
	_air_size = box.size
	_air_centre = box.get_center()


func _climb_to(y: float, delta: float) -> bool:
	_flew_y = true
	var dy:= y - _model.position.y
	if absf(dy) <= maxf(absf(_vel.y) * delta, ARRIVE_Y):
		_model.position.y = y
		_vel.y = 0.0
		return true
	var want:= clampf(signf(dy) * sqrt(2.0 * Cfg.DRONE_CLIMB_ACCEL * absf(dy)),
		- Cfg.DRONE_CLIMB, Cfg.DRONE_CLIMB)
	_vel.y = move_toward(_vel.y, want, Cfg.DRONE_CLIMB_ACCEL * delta)
	return false


func _coast(delta: float) -> void:
	if not _flew_xz:
		_vel.x = move_toward(_vel.x, 0.0, Cfg.DRONE_ACCEL * delta)
		_vel.z = move_toward(_vel.z, 0.0, Cfg.DRONE_ACCEL * delta)
	if not _flew_y:
		_vel.y = move_toward(_vel.y, 0.0, Cfg.DRONE_CLIMB_ACCEL * delta)


func _attitude(delta: float) -> void:
	if _body == null:
		return


	var accel:= (_vel - _last_vel) / maxf(delta, 0.0001)
	_last_vel = _vel


	accel.y = 0.0
	accel = accel.limit_length(Cfg.DRONE_ACCEL)
	_lean = _lean.lerp(accel, clampf(delta * Cfg.DRONE_TILT_EASE, 0.0, 1.0))


	_lean = _lean.limit_length(G * tan(deg_to_rad(Cfg.DRONE_TILT_MAX_DEG)))


	var fwd:= Vector3(- sin(_heading), 0.0, - cos(_heading))
	var right:= Vector3(cos(_heading), 0.0, - sin(_heading))


	var pitch:= - atan2(_lean.dot(fwd), G)
	var roll:= - atan2(_lean.dot(right), G)


	_bob += delta
	var wob:= deg_to_rad(Cfg.DRONE_BOB_TILT_DEG) * _rotor_rate
	var heave:= sin(_bob * TAU / Cfg.DRONE_BOB_PERIOD) * Cfg.DRONE_BOB_HEAVE * _rotor_rate
	var tilt:= Basis.from_euler(Vector3(
		pitch + sin(_bob * TAU / Cfg.DRONE_BOB_PITCH_PERIOD) * wob,
		0.0,
		roll + cos(_bob * TAU / Cfg.DRONE_BOB_ROLL_PERIOD) * wob))
	_body.transform = Transform3D(tilt, Vector3(0.0, heave, 0.0)) * _body_rest


func _winch_to(metres: float, delta: float) -> bool:
	var want:= clampf(metres, 0.001, Cfg.DRONE_WINCH_MAX)
	var step:= Cfg.DRONE_WINCH_SPEED * delta
	var d:= want - _drop
	if absf(d) <= step:
		_drop = want
		_apply_winch()
		return true
	_drop += signf(d) * step
	_apply_winch()
	return false


func _apply_winch() -> void:
	if _hook != null:
		_hook.position.y = _cable_top - _drop
	if _cable != null:
		_cable.scale.y = maxf(_drop, 0.001)


func _drop_for(marker_local: float, world_y: float) -> float:
	var aircraft:= _model.global_position.y
	return clampf(aircraft + _cable_top + marker_local - world_y,
		0.001, Cfg.DRONE_WINCH_MAX)


func _stow_drop() -> float:
	return maxf(_cable_top - _hook_stow, 0.001)


func _play(clip: String, open: bool) -> void:


	if clip == CLIP_CLAW:
		_claw_state = open
	elif clip == CLIP_HATCH:
		_hatch_state = open
	var ap:= _player_for(clip)
	if ap == null:
		return
	if open:
		ap.play(clip)
	else:
		ap.play_backwards(clip)


func _player_for(clip: String) -> AnimationPlayer:
	if clip == CLIP_CLAW:
		return _claw_anim
	if clip == CLIP_HATCH:
		return _hatch_anim
	return null


func _mech_busy() -> bool:
	if _hatch_anim != null and _hatch_anim.is_playing():
		return true
	if _claw_anim != null and _claw_anim.is_playing():
		return true
	return false


func _claw_open() -> bool:
	return _claw_state


func _hatch_open() -> bool:
	return _hatch_state


func _find_pick() -> Dictionary:
	var began:= Time.get_ticks_usec()
	var found:= _find_pick_now()
	var took:= Time.get_ticks_usec() - began
	cost_pick_us += took
	cost_pick_worst = maxi(cost_pick_worst, took)
	return found


func _find_pick_now() -> Dictionary:
	_wait = ""
	var needle:= _loose_needle_in_zone()
	if needle != null:
		var np:= needle.global_position
		if _trip_clear(np):
			if mode == Mode.DIG:
				return { "point": Vector3(np.x, _ground_at(np), np.z), "item": null, "dig": true }
			return { "point": np, "item": needle, "dig": false }
		_covered [needle.get_instance_id()] = _clock_ms() + COVERED_MSEC
	if mode == Mode.DIG:
		return _find_dig()
	return _find_collect()


func _find_dig() -> Dictionary:
	var now:= _clock_ms()
	var skip: Array [Vector3] = []
	for key: Variant in _covered.keys():
		if typeof(key) == TYPE_VECTOR3 and int(_covered [key]) > now:
			skip.append(key as Vector3)
	var candidates:= _dig_candidates(skip)
	if candidates.is_empty():
		if skip.is_empty():
			_wait = tr("Its zone is dug out. Move the zone to keep digging.")
		else:
			_wait = tr("Part of its zone is too close to something built, so it can't get down there.")
		return { }
	var steep:= 0
	var tried:= 0
	var passed: Array [Vector3] = []
	for p: Vector3 in candidates:
		if _near_any(passed, p.x, p.z):
			continue
		passed.append(p)
		var hover:= _hover_over(p)
		if hover + _cable_top + _grab_local - p.y > Cfg.DRONE_WINCH_MAX:
			steep += 1
			continue
		tried += 1
		if _trip_clear(p, hover):
			return { "point": p, "item": null, "dig": true, "hover": hover }
		_covered [p.snapped(Vector3(0.5, 100.0, 0.5))] = now + COVERED_MSEC
		if tried >= 4:
			break
	if tried == 0 and steep > 0:
		_wait = tr("Its zone is too steep to dig from above. Move it lower down the pile.")
	else:
		_wait = tr("Part of its zone is too close to something built, so it can't get down there.")
	return { }


func _hover_over(p: Vector3) -> float:
	var hover:= p.y + HOVER_GAP
	if field == null:
		return hover
	var r:= air_reach() + 0.1
	var top:= field.height_at(p.x, p.z)
	for k in 12:
		var a:= TAU * float(k) / 12.0
		for f: float in [0.5, 1.0]:
			top = maxf(top, field.height_at(p.x + cos(a) * r * f, p.z + sin(a) * r * f))
	return maxf(hover, top + 0.4)


func _dig_candidates(skip: Array [Vector3]) -> Array [Vector3]:
	var out: Array [Vector3] = []
	if field == null or zone_at == Vector3.INF:
		return out
	var nv:= Cfg.field_verts()
	var lo:= field.cell_at(zone_at.x - zone_r, zone_at.z - zone_r)
	var hi:= field.cell_at(zone_at.x + zone_r, zone_at.z + zone_r)
	var r2:= zone_r * zone_r
	for stride: int in [2, 1]:
		var j:= maxi(lo.y, 0)
		while j <= mini(hi.y + 1, nv - 1):
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
			var dz:= wz - zone_at.z
			var i:= maxi(lo.x, 0)
			while i <= mini(hi.x + 1, nv - 1):
				var h: float = field.heights [j * nv + i]
				if h >= DIG_FLOOR:
					var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
					var dx:= wx - zone_at.x
					if dx * dx + dz * dz <= r2 and not _near_any(skip, wx, wz):
						out.append(Vector3(wx, h, wz))
				i += stride
			j += stride
		if not out.is_empty():
			break
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	return out


func _find_collect() -> Dictionary:
	if props == null:
		return { }
	var now:= _clock_ms()
	var here:= _model.global_position
	var drop:= _drop_point()
	var plate:= _plate_point()
	var r2:= zone_r * zone_r
	var covered:= 0
	for attempt in 4:
		var best: Carryable = null
		var best_cost:= INF


		for item: Carryable in props.items:
			if not is_instance_valid(item):
				continue
			var p:= item.global_position
			var dx:= p.x - zone_at.x
			var dz:= p.z - zone_at.z
			if dx * dx + dz * dz > r2:
				continue
			if not _is_prize(item):
				continue


			if plate != Vector3.INF and p.distance_to(plate) < Cfg.DRONE_TILL_CLEAR:
				continue
			if props.is_order_stock(item):
				continue
			var id:= item.get_instance_id()
			if _covered.has(id) and int(_covered [id]) > now:
				covered += 1
				continue
			var cost:= here.distance_to(p) + (p.distance_to(drop) if drop != Vector3.INF else 0.0)
			if cost < best_cost:
				best = item
				best_cost = cost
		if best == null:
			break
		if _trip_clear(best.global_position):
			return { "point": best.global_position, "item": best, "dig": false }
		_covered [best.get_instance_id()] = now + COVERED_MSEC
		covered += 1
	if covered > 0:
		_wait = tr("Part of its zone is too close to something built, so it can't get down there.")
	else:
		_wait = tr("Nothing to pick up in its zone right now. It keeps looking.")
	return { }


func _trip_clear(p: Vector3, hover: float = NAN) -> bool:
	if _model == null or not is_inside_tree():
		return false
	if is_nan(hover):
		hover = _hover_over(p)
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	var from:= _model.global_position
	var y_in:= _leg_y [0] if _phase == Phase.IDLE else _leg_y [2]
	if not _leg_clear(space, own, from, p, y_in):
		return false
	if not _shaft_clear(space, own, p, maxf(y_in, _leg_y [1])):
		return false


	if not _sweep_clear(space, own, Vector3(p.x, maxf(y_in, _leg_y [1]), p.z),
			Vector3(p.x, hover, p.z), _yaw_along(from, p)):
		return false
	var drop:= _drop_point()
	if drop != Vector3.INF and not _leg_clear(space, own, p, drop, _leg_y [1]):
		return false
	return true


func _start_trip(pick: Dictionary) -> void:
	_pick = pick ["point"]
	_pick_dig = bool(pick ["dig"])
	_target = pick ["item"]
	_pick_hover = float(pick.get("hover", _hover_over(_pick)))
	if _target != null:
		_claim(_target)


func _pick_alive() -> bool:
	if not _in_zone(_pick_point()):
		return false
	if _pick_dig:
		return true
	return _still_valid(_target)


func _pick_point() -> Vector3:
	if _target != null and is_instance_valid(_target) and not _pick_dig:
		return _target.global_position
	return _pick


func _in_zone(p: Vector3) -> bool:
	if zone_at == Vector3.INF or p == Vector3.INF:
		return false
	return Vector2(p.x - zone_at.x, p.z - zone_at.z).length() <= zone_r + 0.05


func _highest_in_zone(skip: Array [Vector3] = [], extra: float = 0.0) -> Vector3:
	if field == null or zone_at == Vector3.INF:
		return Vector3.INF
	var nv:= Cfg.field_verts()
	var reach:= zone_r + extra
	var lo:= field.cell_at(zone_at.x - reach, zone_at.z - reach)
	var hi:= field.cell_at(zone_at.x + reach, zone_at.z + reach)
	var r2:= reach * reach
	for stride: int in [2, 1]:
		var best:= Vector3.INF
		var j:= maxi(lo.y, 0)
		while j <= mini(hi.y + 1, nv - 1):
			var wz: float = - Cfg.FIELD_EXTENT + j * Cfg.CELL
			var dz:= wz - zone_at.z
			var i:= maxi(lo.x, 0)
			while i <= mini(hi.x + 1, nv - 1):
				var h: float = field.heights [j * nv + i]
				if h >= DIG_FLOOR and (best == Vector3.INF or h > best.y):
					var wx: float = - Cfg.FIELD_EXTENT + i * Cfg.CELL
					var dx:= wx - zone_at.x
					if dx * dx + dz * dz <= r2 and not _near_any(skip, wx, wz):
						best = Vector3(wx, h, wz)
				i += stride
			j += stride
		if best != Vector3.INF:
			return best
	return Vector3.INF


static func _near_any(points: Array [Vector3], x: float, z: float) -> bool:
	for p in points:
		if Vector2(p.x - x, p.z - z).length_squared() < 1.0:
			return true
	return false


func _zone_top() -> float:
	var p:= _highest_in_zone()
	return maxf(p.y, _zone_floor()) if p != Vector3.INF else _zone_floor()


func _zone_floor() -> float:
	return zone_at.y if zone_at != Vector3.INF else global_position.y


func _ground_at(p: Vector3) -> float:
	var h:= field.height_at(p.x, p.z) if field != null else - INF
	return maxf(h, minf(_zone_floor(), p.y))


func _dig_bite(p: Vector3) -> Node3D:
	if props == null:
		return null
	var r:= Cfg.DRONE_DIG_RADIUS
	var count:= 0
	if field != null:
		var started:= Time.get_ticks_usec()
		var under:= int(floor(field.strands_under(p, r)))
		var want:= mini(Cfg.DRONE_DIG_STRANDS, int(floor(GameState.hay_total)))
		count = maxi(0, mini(want, under))
		if count > 0:
			GameState.remove_hay(float(count))
			field.carve_volume(p, r, float(count) * Cfg.STRAND_VOLUME / Cfg.PACKING)
		var room:= want - count
		var rest:= field.strands_under(p, r)
		if room > 0 and rest > 0.0 and rest <= float(room) + 0.5:
			var swept:= int(round(field.sweep_under(p, r, Shovel.SWEEP_HEIGHT)))
			if swept > 0:
				GameState.remove_hay(float(swept))
				count += swept
		field.charge_frame(Time.get_ticks_usec() - started)
	if count <= 0:


		var lone:= _loose_needle_near(p, r)
		return lone
	var needle:= _bite_needle(p, r)
	var at:= _cargo.global_position if _cargo != null else p + Vector3.UP
	var state:= { "strands": count }
	if needle >= 0:
		state ["needle"] = needle
	var lifted:= props.spawn("hay_wad" if count >= Cfg.WAD_MIN_STRANDS else "hay_tuft",
		Transform3D(Basis(), at), state)
	if lifted == null:


		GameState.return_hay(float(count))
		if needle >= 0:
			GameState.needle_taken [needle] = 0
		return null
	return lifted


func _bite_needle(p: Vector3, r: float) -> int:
	for idx in GameState.needles_in_sphere(p, r * Tech.needle_reveal_scale()):
		GameState.needle_taken [idx] = 1
		return idx
	var lone:= _loose_needle_near(p, r)
	if lone != null and live != null:
		var idx:= int(lone.get_meta("needle_index", -1))
		if idx >= 0 and live.consume_needle(lone):
			return idx
	return -1


func _loose_needle_in_zone() -> RigidBody3D:
	if live == null or zone_at == Vector3.INF:
		return null
	var now:= _clock_ms()
	for b: RigidBody3D in live.needles:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if not _in_zone(b.global_position) or not _needle_free(b):
			continue
		var id:= b.get_instance_id()
		if _covered.has(id) and int(_covered [id]) > now:
			continue
		return b
	return null


func _loose_needle_near(p: Vector3, r: float) -> RigidBody3D:
	if live == null:
		return null
	for b: RigidBody3D in live.needles:
		if not is_instance_valid(b) or not b.is_inside_tree() or not _needle_free(b):
			continue
		var q:= b.global_position
		if Vector2(q.x - p.x, q.z - p.z).length() <= r + 0.15 and absf(q.y - p.y) < 0.8:
			return b
	return null


func _needle_free(b: RigidBody3D) -> bool:
	if BeltPath.is_rider(b):
		return false
	if b.get_meta(LiveStrandManager.META_PROTECTED, false):
		return false
	if b.freeze and not LiveStrandManager.is_pinned(b):
		return false
	if b.has_meta(LiveStrandManager.META_CLAIM) and int(b.get_meta(LiveStrandManager.META_CLAIM)) != get_instance_id():
		var other:= instance_from_id(int(b.get_meta(LiveStrandManager.META_CLAIM)))
		if other != null and is_instance_valid(other):
			return false
	return b.freeze or _settled(b)


func _gather(item: Node3D) -> Node3D:
	var tuft:= item as HayTuft
	if tuft == null or props == null:
		return item
	var total:= tuft.hay_strands()
	var needle:= tuft.needle_index
	var others: Array [HayTuft] = []
	for prop: Carryable in props.items:
		var other:= prop as HayTuft
		if other == null or other == tuft or not is_instance_valid(other):
			continue
		if other.global_position.distance_to(tuft.global_position) > Cfg.DRONE_DIG_RADIUS + 0.2:
			continue
		if not _is_prize(other):
			continue
		if total + other.hay_strands() > Cfg.WAD_MAX_STRANDS:
			continue

		if other.needle_index >= 0:
			if needle >= 0:
				continue
			needle = other.needle_index
		others.append(other)
		total += other.hay_strands()
	if others.is_empty() or total < Cfg.WAD_MIN_STRANDS:
		return tuft
	var at:= tuft.global_position + Vector3.UP * 0.1
	_unclaim(tuft)
	props.remove(tuft)
	for other in others:
		props.remove(other)
	var state:= { "strands": total }
	if needle >= 0:
		state ["needle"] = needle
	var wad:= props.spawn("hay_wad", Transform3D(Basis(), at), state)
	return wad


static func _kind_bit(prop: Carryable) -> int:
	if prop is HayTuft:
		return RoboticArm.PICK_LOOSE
	return RoboticArm._kind_of(prop)


func _is_prize(item: Node) -> bool:
	var prop:= item as Carryable
	if prop == null or not is_instance_valid(prop):
		return false
	var bit:= _kind_bit(prop)
	if bit == 0 or (takes & bit) == 0:
		return false


	if prop.is_held():
		return false


	if BeltPath.is_rider(prop):
		return false
	if not prop.freeze and not _settled(prop):
		return false
	if prop.has_meta(META_CLAIM) and int(prop.get_meta(META_CLAIM)) != get_instance_id():
		var other:= instance_from_id(int(prop.get_meta(META_CLAIM)))
		if other != null and is_instance_valid(other):
			return false
	return true


func _settled(rb: RigidBody3D) -> bool:
	if rb.linear_velocity.length_squared() > STILL_SPEED * STILL_SPEED:
		return false
	if rb.angular_velocity.length_squared() > STILL_SPIN * STILL_SPIN:
		return false
	return true


func _still_valid(item) -> bool:
	if item == null or not is_instance_valid(item) or not (item as Node).is_inside_tree():
		return false
	if _held != null:
		return true
	var rb:= item as RigidBody3D
	if rb == null:
		return false
	if BeltPath.is_rider(rb):
		return false
	return rb.freeze or _settled(rb)


static func _claim_key(item: Node) -> String:
	return LiveStrandManager.META_CLAIM if item.has_meta("needle_index") else META_CLAIM


func _claim(item: Node) -> void:
	if item != null and is_instance_valid(item):
		item.set_meta(_claim_key(item), get_instance_id())


func _unclaim(item) -> void:
	if item == null or not is_instance_valid(item):
		return
	var key:= _claim_key(item)
	if item.has_meta(key) and int(item.get_meta(key)) == get_instance_id():
		item.remove_meta(key)


func _take(item: Node3D) -> void:
	if item == null or not is_instance_valid(item):
		return


	if _held != null:
		_let_go(Vector3.ZERO)


	BeltPath.release(item)
	var rb:= item as RigidBody3D
	if item.has_meta("needle_index") and rb != null:


		LiveStrandManager.unpin(rb)
		if live != null:
			live.set_protected(rb, true)
			live.set_ccd(rb, true)
		_claim(rb)
	if item.has_method("pick_up"):
		item.call("pick_up")
	elif rb != null:
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO


	if rb != null:
		_held_layer = rb.collision_layer
		rb.collision_layer = 0
	_held = item


func _let_go(velocity: Vector3) -> void:
	if _held == null or not is_instance_valid(_held):
		_held = null
		return
	var item:= _held
	_held = null
	_carry_mark = Vector3.INF
	_stolen_for = 0
	_releases += 1
	_unclaim(item)
	var body:= item as RigidBody3D
	if body != null and _held_layer != 0:
		body.collision_layer = _held_layer
		_held_layer = 0
	if item.has_meta("needle_index") and body != null:


		if live != null:
			live.set_protected(body, false)
			live.set_ccd(body, true)
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = velocity
		body.angular_velocity = Vector3.ZERO
		LiveStrandManager.hold(body, 0.6)
	elif item.has_method("release"):
		item.call("release", velocity, Vector3.ZERO)
	elif body != null:
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = velocity
	if item == _target:
		_target = null


func _carry() -> void:
	if _held == null or not is_instance_valid(_held) or _cargo == null:
		return
	var t:= _held as Node3D
	if t == null:
		return


	var want:= _cargo.global_position
	if _carry_mark != Vector3.INF and t.global_position.distance_to(_carry_mark) > STOLEN_GAP:


		_stolen_for += 2
		if _stolen_for >= STOLEN_FRAMES:
			_lose_load()
			return
	else:
		_stolen_for = maxi(0, _stolen_for - 1)
	t.global_position = want
	_carry_mark = want


func _lose_load() -> void:
	var item:= _held
	_held = null
	_carry_mark = Vector3.INF
	_stolen_for = 0
	if item != null and is_instance_valid(item):
		var body:= item as RigidBody3D
		if body != null and _held_layer != 0:
			body.collision_layer = _held_layer
		_unclaim(item)
	_held_layer = 0
	_target = null
	_at_drop = false
	_go(Phase.RECOVER)


func _plate_point() -> Vector3:
	if stand == null or not is_instance_valid(stand):
		return Vector3.INF
	return stand.delivery_point()


func _drop_point() -> Vector3:
	match drop_kind:
		Drop.BELT:
			return drop_at if _drop_belt() != null else Vector3.INF
		Drop.STAIRS:
			var tower:= _drop_stairs()
			return tower.mouth_position() if tower != null else Vector3.INF
		Drop.FLOOR:
			return drop_at
	return Vector3.INF


func _drop_belt() -> BeltPath:
	if drop_kind != Drop.BELT or drop_at == Vector3.INF:
		return null
	if _drop_run != null and is_instance_valid(_drop_run) and _drop_run.is_inside_tree() and not _drop_run.is_queued_for_deletion():
		return _drop_run
	_drop_run = belt_at(builds, drop_at)
	return _drop_run


static func belt_at(manager: BuildManager, at: Vector3) -> BeltPath:
	if manager == null:
		return null
	var best: BeltPath = null
	var best_d:= RoboticArm.LINK_SNAP
	for list: Array in [manager.conveyors, manager.corners]:
		for item: Variant in list:
			if item == null or not is_instance_valid(item):
				continue
			var run:= item as BeltPath
			if not RoboticArm.linkable(run) or not run.is_inside_tree() or run.is_queued_for_deletion() or run.path_length() <= 0.0:
				continue
			var d:= run._point_at(run.s_at(at)).distance_to(at)
			if d <= best_d:
				best_d = d
				best = run
	return best


func _drop_stairs() -> HayStairs:
	if drop_kind != Drop.STAIRS or builds == null:
		return null
	for tower: HayStairs in builds.hay_stairs:
		if is_instance_valid(tower) and tower.is_inside_tree() and Vector2(tower.mouth_position().x - drop_at.x,
					tower.mouth_position().z - drop_at.z).length() < 0.8:
			return tower
	return null


func _choose_spot() -> Vector3:
	if drop_kind == Drop.FLOOR:
		return _floor_spot()
	return _drop_point()


func _floor_spot() -> Vector3:
	var slots: Array [Vector2] = [Vector2.ZERO]
	for ring in [1, 2]:
		var count: int = ring * 6
		for k in count:
			var a:= TAU * float(k) / float(count) + (0.26 if ring == 2 else 0.0)
			slots.append(Vector2(cos(a), sin(a)) * FLOOR_SPREAD * float(ring))
	var space:= get_world_3d().direct_space_state
	var ex: Array [RID] = []
	if _held != null and is_instance_valid(_held) and _held is CollisionObject3D:
		ex.append((_held as CollisionObject3D).get_rid())
	for n in slots.size():
		var k:= (_floor_slot + n) % slots.size()
		var p:= Vector3(drop_at.x + slots [k].x, drop_at.y, drop_at.z + slots [k].y)
		var q:= PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 0.3,
			Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_PILE)
		q.exclude = ex
		var hit:= space.intersect_ray(q)
		var top:= float((hit ["position"] as Vector3).y) if not hit.is_empty() else drop_at.y


		if top - drop_at.y <= FLOOR_HEAP and not _air_touches(p, _drop_hover_y):
			_floor_slot = k + 1
			return Vector3(p.x, top, p.z)
	return Vector3.INF


func _load_half() -> float:
	var prop:= _held as Carryable
	if prop != null and is_instance_valid(prop):
		return prop.clearance_size().y * 0.5
	return 0.05


func _load_reach() -> float:
	var prop:= _held as Carryable
	if prop != null and is_instance_valid(prop):
		var size:= prop.clearance_size()
		return maxf(size.x, size.z) * 0.5
	return Cfg.STRAND_THICK


func _has_room() -> bool:
	match drop_kind:
		Drop.BELT:
			var run:= _drop_belt()
			if run == null:
				return false
			var prop:= _held as Carryable
			var kind:= BeltPath.record_kind(prop) if prop != null else -1
			if run.records_props and not run.record_only and kind >= 0:
				return run.has_room_to_board(_spot, kind, prop.hay_strands(), _load_reach(),
					Tech.belt_speed())
			var lead:= maxf(0.0, Tech.belt_speed() * RoboticArm.DROP_SETTLE_SECONDS)
			return run.has_room_to_land(_held.global_position, 0.0, lead, _load_reach())
		Drop.STAIRS:
			return _stairs_room()
	return true


func _stairs_room() -> bool:
	var tower:= _drop_stairs()
	if tower == null:
		return false
	var ball:= SphereShape3D.new()
	ball.radius = tower.mouth_radius()
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = Cfg.L_PROP
	q.transform = Transform3D(Basis(), tower.mouth_position() + Vector3.DOWN * 0.4)
	if _held != null and is_instance_valid(_held) and _held is CollisionObject3D:
		q.exclude = [(_held as CollisionObject3D).get_rid()]
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var rb:= hit.get("collider") as RigidBody3D
		if rb != null and _settled(rb):
			return false
	return true


func _put_down() -> void:
	var prop:= _held as Carryable
	if prop != null and is_instance_valid(prop):
		strands_put += prop.hay_strands()
	var run:= _drop_belt()
	var at:= _spot if _spot.is_finite() else _drop_point()
	if run != null and prop != null and run.records_props and not run.record_only and BeltPath.record_kind(prop) >= 0 and at.is_finite():
		var reach:= _load_reach()
		_let_go(Vector3.ZERO)
		if is_instance_valid(prop) and prop.is_inside_tree():
			run.board_body(prop, at, -1.0, reach)
		return
	_let_go(Vector3.ZERO)


static func _traffic(delta: float) -> void:
	var n:= _fleet.size()
	for d: HayDrone in _fleet:
		d._cap = INF
		d._blocker = null
	var sep:= v_sep()
	for i in n:
		var a:= _fleet [i]
		if not is_instance_valid(a) or not a._airborne():
			continue
		var pa:= a._model.global_position
		for j in range(i + 1, n):
			var b:= _fleet [j]
			if not is_instance_valid(b) or not b._airborne():
				continue
			var pb:= b._model.global_position
			if absf(pa.y - pb.y) >= sep:
				_near_pair(a, b, false)
				continue
			var rel:= Vector2(pb.x - pa.x, pb.z - pa.z)
			var dist:= rel.length()
			_near_pair(a, b, dist < HARD_SEP)
			if dist > LOOK:
				continue
			a._yield_to(b, rel)
			b._yield_to(a, - rel)
	for d: HayDrone in _fleet:
		if is_instance_valid(d):
			d._after_traffic(delta)


func _yield_to(o: HayDrone, rel: Vector2) -> void:
	if not _cruising():
		return
	var u:= _goal_dir
	if u.length_squared() < 0.5:
		return


	var cap: float
	if _gives_way_to(o):
		cap = _stop_short_of(rel, u, _goal_left, H_SEP)
		if o._cruising():
			var ov:= o._world_vel()
			var speed:= ov.length()
			if speed > 0.3:
				cap = minf(cap, _stop_short_of(rel + ov * (speed / (2.0 * Cfg.DRONE_ACCEL)), u,
					_goal_left, H_SEP))
			if o._goal_left < 10.0:
				cap = minf(cap, _stop_short_of(rel + o._goal_dir * o._goal_left, u,
					_goal_left, H_SEP))


			var vr:= ov - _world_vel()
			var vv:= vr.length_squared()
			if vv > 0.01:
				var t:= clampf(- rel.dot(vr) / vv, 0.0, CPA_HORIZON)
				if t > 0.0 and (rel + vr * t).length() < H_SEP:
					cap = 0.0
	else:
		cap = _stop_short_of(rel, u, _goal_left, WAY_SEP)
	if cap < _cap:
		_cap = cap
		_blocker = o


static func _stop_short_of(q: Vector2, u: Vector2, left: float, gap: float) -> float:
	var along:= q.dot(u)
	var lateral:= absf(q.x * u.y - q.y * u.x)
	if lateral >= gap or along <= 0.0 or along > left + gap:
		return INF

	var room:= along - sqrt(gap * gap - lateral * lateral)
	return sqrt(2.0 * Cfg.DRONE_ACCEL * maxf(0.0, room))


func _after_traffic(delta: float) -> void:
	if _cruising() and _cap < 0.25:
		_blocked_for += delta
		held_for += delta
		_unblocked_for = 0.0
		_wait_traffic = true
		var mutual:= _blocker != null and is_instance_valid(_blocker) and _blocker._blocker == self and _gives_way_to(_blocker)
		if is_zero_approx(_dodge_want) and _detour == Vector3.INF and ((mutual and _blocked_for > DODGE_AFTER) or _blocked_for > DODGE_AFTER * 3.0):
			var step:= v_sep() + 0.2
			if _dodge_clear(step):
				_dodge_want = step
			elif _dodge_clear(- step):
				_dodge_want = - step
			else:

				_sidestep()
	else:
		_blocked_for = 0.0
		_unblocked_for += delta
		if not _vertical_phase():
			_wait_traffic = false
		if _unblocked_for > 3.0:
			_dodge_want = 0.0
	if not _cruising():
		_dodge_want = 0.0
		_dodge = 0.0
		return
	_dodge = move_toward(_dodge, _dodge_want, Cfg.DRONE_CLIMB * delta)


func _sidestep() -> void:
	if _blocker == null or not is_instance_valid(_blocker):
		return
	var here:= _model.global_position
	var there:= _blocker._model.global_position
	var d:= Vector2(here.x - there.x, here.z - there.z)
	if d.length_squared() < 0.0001:
		d = Vector2(1.0, 0.0)
	d = d.normalized()
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	for side: float in [1.0, -1.0]:
		var n:= Vector2(- d.y, d.x) * side
		var to:= here + Vector3(n.x, 0.0, n.y) * (H_SEP + 0.8)
		if _hay_under(here, to) + PILE_CLEAR > here.y:
			continue
		if _air_touches(to, here.y) or not _leg_clear(space, own, here, to, here.y):
			continue
		var crowded:= false
		for o: HayDrone in _fleet:
			if o != self and is_instance_valid(o) and o._airborne() and absf(o._model.global_position.y - here.y) < v_sep() and _flat(o._model.global_position, to) < H_SEP:
				crowded = true
		if not crowded:
			_detour = to
			return


func _fly_leg(goal: Vector3, delta: float) -> bool:
	if _detour != Vector3.INF:
		if _fly_to(_detour, delta):
			_detour = Vector3.INF
		return false
	return _fly_to(goal, delta)


func _dodge_clear(by: float) -> bool:
	var here:= _model.global_position
	var to:= here + Vector3.UP * by
	var lo:= minf(here.y, to.y) - v_sep()
	var hi:= maxf(here.y, to.y) + v_sep()
	for o: HayDrone in _fleet:
		if o == self or not is_instance_valid(o) or not o._airborne():
			continue
		var p:= o._model.global_position
		if p.y > lo and p.y < hi and p.y != here.y and Vector2(p.x - here.x, p.z - here.z).length() < H_SEP:
			return false
	var goal:= here + Vector3(_goal_dir.x, 0.0, _goal_dir.y) * _goal_left
	if by < 0.0 and _hay_under(here, goal) + PILE_CLEAR > to.y:
		return false
	var space:= get_world_3d().direct_space_state
	var own:= _own_bodies()
	if not _sweep_clear(space, own, here, to, _heading):
		return false
	return _leg_clear(space, own, to, Vector3(goal.x, to.y, goal.z), to.y)


func _column_clear(from_y: float, to_y: float) -> bool:
	if _col_ok:
		return true
	var here:= _model.global_position
	var sep:= v_sep()
	var lo:= minf(from_y, to_y) - sep
	var hi:= maxf(from_y, to_y) + sep
	for o: HayDrone in _fleet:
		if o == self or not is_instance_valid(o) or not o._airborne():
			continue
		var p:= o._model.global_position
		if p.y < lo or p.y > hi:
			continue
		var rel:= Vector2(p.x - here.x, p.z - here.z)
		var d:= rel.length()
		if o._cruising():
			var ov:= o._world_vel()
			var vv:= ov.length_squared()
			if vv < 0.09:
				if d < HARD_SEP + 0.3:
					_wait_traffic = true
					return false
				continue
			var t:= clampf(- rel.dot(ov) / vv, 0.0, CPA_HORIZON)
			if (rel + ov * t).length() < H_SEP:
				_wait_traffic = true
				return false
		elif d < H_SEP:
			var waiting:= o._vertical_phase() and not o._col_ok
			if not waiting or o.get_instance_id() < get_instance_id():
				_wait_traffic = true
				return false
	_col_ok = true
	_wait_traffic = false
	return true


static func _near_pair(a: HayDrone, b: HayDrone, close: bool) -> void:
	var key:= a.get_instance_id() * 31 + b.get_instance_id()
	if close:
		if not _close.has(key):
			_close [key] = true
			a.near_misses += 1
			b.near_misses += 1
	elif _close.has(key):
		_close.erase(key)


func _airborne() -> bool:
	return _phase != Phase.IDLE and _model != null and _model.position.y > 0.25


func _cruising() -> bool:
	return _phase == Phase.TO_PICK or _phase == Phase.TO_DROP or _phase == Phase.HOME


func _vertical_phase() -> bool:
	match _phase:
		Phase.LAUNCH, Phase.DESCEND, Phase.CLIMB, Phase.DROP_DOWN, Phase.RISE, Phase.LAND:
			return true
	return false


func _gives_way_to(o: HayDrone) -> bool:
	return get_instance_id() > o.get_instance_id()


func _world_vel() -> Vector2:
	var w:= global_basis * _vel
	return Vector2(w.x, w.z)


static func collect_all() -> int:
	var bits:= 0
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		if COLLECT_KINDS.has(str(kind ["id"])):
			bits |= int(kind ["bit"])
	return bits


func accepts(bit: int) -> bool:
	return (takes & bit) != 0


func set_accepting(bit: int, on: bool) -> void:
	if (collect_all() & bit) == 0:
		return
	takes = (takes | bit) if on else (takes & ~ bit)
	_covered.clear()


func set_mode(m: int) -> void:
	if m == mode:
		return
	mode = m
	_covered.clear()


func has_job() -> bool:
	return zone_at != Vector3.INF and drop_at != Vector3.INF


func zone_max() -> float:
	return Tech.drone_zone_max()


func zone_refusal(at: Vector3, r: float) -> String:
	if _flat(at, global_position) > radius():
		return tr("OUT OF RANGE")
	if drop_at != Vector3.INF and _flat(at, drop_at) < r + DROP_GAP:
		return tr("TOO CLOSE TO ITS DROP")
	for o: HayDrone in _fleet:
		if o == self or not is_instance_valid(o):
			continue
		if o.zone_at != Vector3.INF and _flat(at, o.zone_at) < r + o.zone_r + 1.0:
			return tr("ANOTHER DRONE WORKS HERE")
		if o.drop_at != Vector3.INF and _flat(at, o.drop_at) < r + POINT_GAP:
			return tr("ANOTHER DRONE DROPS HERE")
		if _flat(at, o.global_position) < r + PAD_RADIUS + 0.5:
			return tr("TOO CLOSE TO ANOTHER PAD")
	return ""


func drop_refusal(at: Vector3) -> String:
	if _flat(at, global_position) > radius():
		return tr("OUT OF RANGE")
	var plate:= _plate_point()
	if plate != Vector3.INF and _flat(at, plate) < Cfg.DRONE_TILL_CLEAR + 1.0:
		return tr("NOT THE SELLING STAND")

	if field != null and field.height_at(at.x, at.z) > at.y + 0.1:
		return tr("NOT ON THE PILE")


	if not _room_to_hover(at):
		return tr("NO ROOM TO FLY HERE")
	if zone_at != Vector3.INF and _flat(at, zone_at) < zone_r + DROP_GAP:
		return tr("INSIDE ITS OWN ZONE")
	for o: HayDrone in _fleet:
		if o == self or not is_instance_valid(o):
			continue
		if o.drop_at != Vector3.INF and _flat(at, o.drop_at) < POINT_GAP:
			return tr("ANOTHER DRONE DROPS HERE")
		if o.zone_at != Vector3.INF and _flat(at, o.zone_at) < o.zone_r + POINT_GAP:
			return tr("ANOTHER DRONE WORKS HERE")
		if _flat(at, o.global_position) < H_SEP:
			return tr("TOO CLOSE TO ANOTHER PAD")
	return ""


static func pad_refusal(at: Vector3) -> String:
	for o: HayDrone in _fleet:
		if not is_instance_valid(o):
			continue
		if o.zone_at != Vector3.INF and _flat(at, o.zone_at) < o.zone_r + PAD_RADIUS + 0.5:
			return "zone"
		if o.drop_at != Vector3.INF and _flat(at, o.drop_at) < H_SEP:
			return "drop"
	return ""


func _room_to_hover(at: Vector3) -> bool:
	if _air_size == Vector3.ZERO or not is_inside_tree():
		return true


	var cyl:= CylinderShape3D.new()
	cyl.radius = air_reach() + 0.05
	cyl.height = 6.0
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	q.exclude = _own_bodies()
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (HOVER_GAP + 3.0))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _air_touches(p: Vector3, y: float) -> bool:
	var q:= _air_query(_own_bodies(), true)
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, y, p.z)) * Transform3D(Basis.IDENTITY, _air_centre)
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func set_zone(at: Vector3, r: float) -> String:
	r = clampf(r, ZONE_MIN, zone_max())
	var why:= zone_refusal(at, r)
	if why != "":
		return why
	zone_at = at
	zone_r = r
	_job_changed()
	return ""


func set_drop(at: Vector3, kind: int) -> String:
	if kind == Drop.BELT:
		var run:= belt_at(builds, at)
		if run == null:
			return tr("NOT HERE")
		at = run.usable_release(run._point_at(run.s_at(at)), 0.0, 0.0, 0.35)
	var why:= drop_refusal(at)
	if why != "":
		return why
	drop_at = at
	drop_kind = kind
	_drop_run = null
	_job_changed()
	return ""


func clear_zone() -> void:
	zone_at = Vector3.INF
	_job_changed()


func clear_drop() -> void:
	drop_at = Vector3.INF
	drop_kind = Drop.NONE
	_drop_run = null
	_job_changed()


func _job_changed() -> void:
	_covered.clear()
	_floor_slot = 0
	_route_dirty = true
	_job_key = ""
	_stall = ""
	if has_job() and is_inside_tree():
		_plan_route()
	_scan_left = 0.0


func _on_yard_changed() -> void:
	_route_dirty = true


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func plan_now() -> String:
	if not has_job():
		return ""
	_plan_route()
	if _route_why == "":
		return ""
	return str(plate_status() [1])


func route_points() -> PackedVector3Array:
	var out:= PackedVector3Array()
	var drop:= _drop_point()
	if not has_job() or drop == Vector3.INF or _route_dirty or _route_why != "":
		return out
	var pad:= global_position
	var zone:= Vector3(zone_at.x, _zone_top(), zone_at.z)
	out.append(pad)
	out.append(Vector3(pad.x, _leg_y [0], pad.z))
	out.append(Vector3(zone.x, _leg_y [0], zone.z))
	out.append(Vector3(zone.x, maxf(_leg_y [0], _leg_y [1]), zone.z))
	out.append(Vector3(zone.x, _leg_y [1], zone.z))
	out.append(Vector3(drop.x, _leg_y [1], drop.z))
	out.append(Vector3(drop.x, maxf(_leg_y [1], _leg_y [3]), drop.z))
	out.append(Vector3(drop.x, _leg_y [3], drop.z))
	out.append(Vector3(pad.x, _leg_y [3], pad.z))
	out.append(pad)
	return out


const COL_ZONE:= Color(1.0, 0.52, 0.1, 0.85)
const COL_DROP:= Color(0.26, 0.6, 1.0, 0.9)
const COL_ROUTE:= Color(1.0, 1.0, 1.0, 0.55)


func show_job(on: bool, seconds: float = 0.0) -> void:
	if not on:
		_job_shown = false
		_job_left = 0.0
		if is_instance_valid(_job_marks):
			_job_marks.visible = false
		return
	_job_shown = true
	_job_left = seconds
	_job_key = ""
	_draw_job()


func job_shown() -> bool:
	return _job_shown


func job_seconds_left() -> float:
	return _job_left


func _tick_job_marks(delta: float) -> void:
	if not _job_shown:
		return
	if _job_left > 0.0:
		_job_left -= delta
		if _job_left <= 0.0:
			show_job(false)
			return


	_job_redraw -= delta
	if _job_redraw <= 0.0:
		_job_redraw = 2.0
		_job_key = ""
	_draw_job()


func _draw_job() -> void:
	var key:= "%s %.2f %s %d %s %d" % [zone_at, zone_r, drop_at, mode,
		_route_why, int(_route_dirty)]
	if key == _job_key and is_instance_valid(_job_marks):
		_job_marks.visible = true
		return
	_job_key = key
	if not is_instance_valid(_job_marks):
		_job_marks = Node3D.new()
		_job_marks.name = "JobMarks"
		_job_marks.top_level = true
		add_child(_job_marks)
	for kid in _job_marks.get_children():
		kid.queue_free()
	_job_marks.global_transform = Transform3D.IDENTITY
	_job_marks.visible = true
	if zone_at != Vector3.INF:
		_job_marks.add_child(_surface_ring(zone_at, zone_r, COL_ZONE))
		_job_marks.add_child(_tag(tr("DIG") if mode == Mode.DIG else tr("COLLECT"),
			Vector3(zone_at.x, _zone_top() + 1.0, zone_at.z), COL_ZONE))
	var drop:= _drop_point()
	if drop != Vector3.INF:
		_job_marks.add_child(_surface_ring(drop, 0.5, COL_DROP))
		_job_marks.add_child(_tag(tr("DROP"), drop + Vector3.UP * 1.0, COL_DROP))
	var route:= route_points()
	if route.size() >= 2:
		var line:= MeshInstance3D.new()
		line.mesh = _dashes(route, 0.05)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.material_override = _job_mat(COL_ROUTE, true)
		_job_marks.add_child(line)


func _surface_ring(at: Vector3, r: float, colour: Color) -> MeshInstance3D:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs:= 64
	var band:= 0.14
	var pts: Array [Vector3] = []
	for i in segs + 1:
		var a:= TAU * float(i) / float(segs)
		var c:= Vector3(at.x + cos(a) * r, 0.0, at.z + sin(a) * r)
		var h:= field.height_at(c.x, c.z) if field != null else - INF
		c.y = maxf(h, at.y) + 0.07
		pts.append(c)
	for i in segs:
		RoboticArm._ribbon(st, pts [i], pts [i + 1], Vector3.UP, band)
	var mi:= MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _job_mat(colour, false)
	return mi


static func _dashes(pts: PackedVector3Array, width: float) -> ArrayMesh:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a:= pts [i]
		var b:= pts [i + 1]
		var span:= a.distance_to(b)
		if span < 0.01:
			continue
		var t:= 0.0
		while t < span:
			var t1:= minf(t + 0.35, span)
			var p0:= a.lerp(b, t / span)
			var p1:= a.lerp(b, t1 / span)
			var dir:= (b - a) / span
			var n1:= Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
			var n2:= dir.cross(n1).normalized()
			RoboticArm._ribbon(st, p0, p1, n1, width)
			RoboticArm._ribbon(st, p0, p1, n2, width)
			t = t1 + 0.2
	return st.commit()


func _tag(text: String, at: Vector3, colour: Color) -> Label3D:
	var tag:= Label3D.new()
	tag.text = text
	tag.font = UiFont.bold()


	tag.fixed_size = true
	tag.font_size = 44
	tag.pixel_size = 0.0011
	tag.outline_size = 10
	tag.modulate = colour
	tag.outline_modulate = Color(0.03, 0.04, 0.06, 0.9)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = at
	return tag


static func _job_mat(colour: Color, through: bool) -> StandardMaterial3D:
	var key:= "%s %s" % [colour.to_html(), through]
	if not _job_mats.has(key):
		var m:= _new_ring_mat(colour)
		m.no_depth_test = through
		m.render_priority = 2 if through else 1
		_job_mats [key] = m
	return _job_mats [key]


const COL_TAKEN:= Color(0.62, 0.64, 0.67, 0.8)


static func taken_marks(except: HayDrone) -> Array [Node3D]:
	var out: Array [Node3D] = []
	for o: HayDrone in _fleet:
		if o == except or not is_instance_valid(o) or not o.is_inside_tree():
			continue
		if o.zone_at != Vector3.INF:
			out.append(o._surface_ring(o.zone_at, o.zone_r, COL_TAKEN))
			out.append(o._tag(o.tr("DIG") if o.mode == Mode.DIG else o.tr("COLLECT"),
				Vector3(o.zone_at.x, o._zone_top() + 1.0, o.zone_at.z), COL_TAKEN))
		var drop:= o._drop_point()
		if drop != Vector3.INF:
			out.append(o._surface_ring(drop, 0.5, COL_TAKEN))
			out.append(o._tag(o.tr("DROP"), drop + Vector3.UP * 1.0, COL_TAKEN))


	for mark in out:
		if mark is Label3D:
			(mark as Label3D).font_size = 32
	return out


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return Cfg.DRONE_COST


func radius() -> float:
	return Tech.drone_radius()


func busy() -> bool:
	return _phase != Phase.IDLE


const MODE_WORDS:= ["dig", "collect"]
const DROP_WORDS:= ["", "belt", "stairs", "floor"]


func to_dict() -> Dictionary:


	var out:= {
		"type": "hay_drone",
		"off": switched_off,
		"position": position,
		"yaw": rotation.y,


		"paid": build_cost(),
		"mode": MODE_WORDS [mode],
		"trips": trips,
	}
	if zone_at != Vector3.INF:
		out ["zone"] = zone_at
		out ["zone_r"] = zone_r
	if drop_at != Vector3.INF:
		out ["drop"] = drop_at
		out ["drop_kind"] = DROP_WORDS [drop_kind]


	var ids: Array = []
	for kind: Dictionary in RoboticArm.PICK_KINDS:
		if COLLECT_KINDS.has(str(kind ["id"])) and accepts(int(kind ["bit"])):
			ids.append(str(kind ["id"]))
	out ["takes"] = ids
	return out


func restore_job(d: Dictionary) -> void:
	mode = Mode.COLLECT if str(d.get("mode", "dig")) == "collect" else Mode.DIG
	trips = int(d.get("trips", 0))
	if d.has("zone"):
		zone_at = d ["zone"] as Vector3
		zone_r = float(d.get("zone_r", 3.0))
	var word:= str(d.get("drop_kind", ""))
	if d.has("drop") and DROP_WORDS.has(word) and word != "":
		drop_at = d ["drop"] as Vector3
		drop_kind = DROP_WORDS.find(word)
	if d.has("takes"):
		takes = 0
		for kind: Dictionary in RoboticArm.PICK_KINDS:
			if (d ["takes"] as Array).has(str(kind ["id"])):
				takes |= int(kind ["bit"])
		takes &= collect_all()


		if takes == 0:
			takes = NOTHING
	_route_dirty = true


const NOTHING:= 1 << 30
