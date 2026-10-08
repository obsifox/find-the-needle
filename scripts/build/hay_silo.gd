class_name HaySilo
extends Node3D


const MODEL:= "res://assets/models/hay_silo.glb"


const SPEC:= "res://assets/models/hay_silo_materials.json"


const SHADER:= "res://assets/stand_surface.gdshader"

const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"
const N_DECK_START:= "Marker_DeckStart"
const N_TOP_FEED:= "Marker_TopFeed"
const N_MOUTH:= "Marker_Mouth"
const N_DISCHARGE:= "Marker_Discharge"
const N_PANEL:= "Marker_Panel"
const N_LADDER_FOOT:= "Marker_LadderFoot"
const N_LADDER_TOP:= "Marker_LadderTop"
const N_ROTOR:= "Silo_Rotor"
const N_FAN:= "Silo_Fan"
const N_KNOB:= "Silo_Knob"
const N_NEEDLE_RATE:= "Silo_NeedleRate"
const N_NEEDLE_LEVEL:= "Silo_NeedleLevel"
const N_COWL:= "Silo_Cowl"
const N_HEAP:= "Silo_Heap"


const FAN_RATIO:= 18.0


const GAUGE_SWEEP:= 250.0
const KNOB_SWEEP:= 260.0


const READOUT_SHADER:= "res://assets/silo_readout.gdshader"
const READOUT_DIGITS:= 3


const READOUT_DH:= 0.052
const READOUT_DW:= 0.052 * 0.56
const READOUT_GAP:= 0.014
const READOUT_T:= 0.052 * 0.11


const READOUT_BAR_LEN:= 0.86
const READOUT_POST_LEN:= 0.44


const READOUT_AT:= Vector3(1.7345, 1.57, -0.22)


const READOUT_MARGIN:= 1.3


const COWL_SPEED:= 25.0


const F_BELT_IN:= Vector3(0.0, 5.0, -3.05)
const F_BELT_OUT:= Vector3(0.0, 0.0, 1.0)
const F_DECK_START:= Vector3(0.0, 0.0, -0.78)
const F_TOP_FEED:= Vector3(0.0, 5.0, -0.05)
const F_MOUTH:= Vector3(0.0, 4.28, 0.0)
const F_DISCHARGE:= Vector3(0.0, 0.44, 0.02)
const F_PANEL:= Vector3(1.75, 1.56, -0.2)
const F_LADDER_FOOT:= Vector3(-1.47, -0.4, 0.5575)
const F_LADDER_TOP:= Vector3(-1.47, 5.09, 0.5575)


const MAT_GO:= "M_SL_LampGo"
const MAT_WARN:= "M_SL_LampWarn"
const MAT_STOP:= "M_SL_LampStop"


const MAT_SEGMENT:= "M_SL_Segment"
const MAT_PLASTIC:= "M_SL_Plastic"
const LAMP_DARK:= 0.04
const LAMP_LIT:= 1.5


const MOUTH_RADIUS:= 0.88
const MOUTH_HEIGHT:= 0.95


const DROP_LIFT:= 0.06

const BELT_HEADROOM:= 0.9


const HEAP_SCALE_MIN:= 0.42
const HEAP_SCALE_MAX:= 1.0


const DRIVE_LOOP:= "motor_b"
const DRIVE_DB:= -15.0
const DRIVE_SILENT:= -80.0
const DRIVE_RAMP:= 140.0
const DRIVE_HEIGHT:= 1.1


const PITCH_AT_MIN:= 0.74
const PITCH_AT_MAX:= 1.42


const MEASURE_KEEP:= 40.0


signal discharged(load_out: Carryable)


signal discharged_record(seq: int)


var props: PropManager

var live: LiveStrandManager
var placement_preview:= false


var discharge_rate:= Cfg.SILO_RATE_DEFAULT


var resume_rate:= Cfg.SILO_RATE_DEFAULT


var queued: Array [Dictionary] = []


var stored:= 0


var pending_needles:= PackedInt32Array()


func held_needles() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for spec: Dictionary in queued:
		var index:= int((spec.get("state", { }) as Dictionary).get("needle", -1))
		if index >= 0:
			out.append(index)
	out.append_array(pending_needles)
	return out


var starved_for:= 0.0

var blocked_for:= 0.0

var _model: Node3D

var _ports: Array [Node3D] = []


var _movers: Dictionary = { }
var _rotor: Node3D
var _heap: Node3D
var _heap_rest:= Transform3D()


var _cowl:= 0.0
var _feed: BeltPath
var _belt: BeltPath
var _mouth_area: Area3D


var _climb_area: Area3D
var _supports: Node3D


var _ghost_belt: BeltGhost

var _lamps: Dictionary = { }

var _lamp_mats: Dictionary = { }

var _lamp_lit: Dictionary = { }


var _readout: MeshInstance3D
var _readout_shows:= -1


var _spin:= 0.0


var _owed:= 0.0


var _left_at: Array [float] = []


var _clock:= 0.0


var _room_probe: BoxShape3D
var _room_query: PhysicsShapeQueryParameters3D

var _drive_voice:= -1
var _drive_gain:= DRIVE_SILENT
var _drive_target:= DRIVE_SILENT

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_find_moving_parts()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belts()
		set_preview_valid(true)
		return


	set_process(FactoryClock.stride > 1)


	FactoryClock.join(self)
	_build_belts()
	_build_mouth()
	_build_climb_volume()
	add_to_group("hay_silos")
	_build_readout()
	_apply_lamps()
	_apply_heap()


	_apply_dials()
	_apply_readout()


	call_deferred("refresh_supports")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HaySilo: cannot load %s" % MODEL)
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
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("HaySilo: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	_lamps.clear()
	_lamp_mats.clear()
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
					func() -> Material: return HayCompressor.make_material(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key in [MAT_GO, MAT_WARN, MAT_STOP]:
				var slots: Array = _lamps.get_or_add(key, [])
				slots.append([mesh, i])
	for key: String in _lamps:
		_lamp_mats [key] = [_lamp_variant(key, spec, shader, LAMP_DARK),
			_lamp_variant(key, spec, shader, LAMP_LIT)]
	if not missed.is_empty():
		push_warning("HaySilo: no table entry for %s" % ", ".join(missed.keys()))


static func _lamp_variant(key: String, spec: Dictionary, shader: Shader,
		energy: float) -> Material:
	var build:= func() -> Material:
		var made:= HayCompressor.make_material(key, spec, shader)
		var flat:= made as StandardMaterial3D
		if flat != null:
			flat.emission_energy_multiplier = energy
		return made
	return HayCompressor.shared_material(MODEL, "%s@%s" % [key, energy], build)


static func spec_table() -> Dictionary:
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


func _find_moving_parts() -> void:
	for part: String in [N_ROTOR, N_FAN, N_KNOB, N_NEEDLE_RATE, N_NEEDLE_LEVEL,
			N_COWL]:
		var node:= _find(part) as Node3D
		if node == null:
			push_warning("HaySilo: %s has no %s; that part will not move"
				% [MODEL, part])
			continue
		_movers [part] = { "node": node, "rest": node.transform.basis }
	_rotor = _movers [N_ROTOR] ["node"] if _movers.has(N_ROTOR) else null
	_heap = _find(N_HEAP) as Node3D
	if _heap == null:
		push_warning("HaySilo: %s has no %s; the fill cue is missing" % [MODEL, N_HEAP])
	else:
		_heap_rest = _heap.transform


func _turn(part: String, axis: Vector3, angle: float) -> void:
	var entry: Dictionary = _movers.get(part, { })
	if entry.is_empty():
		return
	var node: Node3D = entry ["node"]
	node.transform.basis = Basis(axis, angle) * (entry ["rest"] as Basis)


func port_in() -> Vector3:
	return to_global(_marker_local(N_BELT_IN, F_BELT_IN))


func port_out() -> Vector3:
	return to_global(_marker_local(N_BELT_OUT, F_BELT_OUT))


func top_feed() -> Vector3:
	return to_global(_marker_local(N_TOP_FEED, F_TOP_FEED))


func deck_start() -> Vector3:
	return to_global(_marker_local(N_DECK_START, F_DECK_START))


func deck() -> BeltPath:
	return _belt


func feed_deck() -> BeltPath:
	return _feed


func forward() -> Vector3:
	var d:= port_out() - deck_start()
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func discharge_point() -> Vector3:
	return to_global(_marker_local(N_DISCHARGE, F_DISCHARGE))


func mouth_position() -> Vector3:
	return to_global(_marker_local(N_MOUTH, F_MOUTH))


func mouth_radius() -> float:
	return MOUTH_RADIUS


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, F_PANEL))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


func _build_belts() -> void:


	_belt = BeltPath.new()
	_belt.name = "ModuleBelt"
	add_child(_belt)
	var runs:= belt_runs()
	_belt.build_path(runs [0], Cfg.BELT_JOINT_OVERLAP)


	_belt.records_props = true

	_feed = BeltPath.new()
	_feed.name = "FeedDeck"
	add_child(_feed)
	_feed.build_path(runs [1], Cfg.BELT_JOINT_OVERLAP)


	_feed.records_props = true
	_feed.hold_records(_eats_kind)


func _build_mouth() -> void:
	_mouth_area = Area3D.new()
	_mouth_area.name = "Mouth"
	_mouth_area.collision_layer = 0


	_mouth_area.collision_mask = Cfg.L_PROP | Cfg.L_STRAND
	_mouth_area.monitorable = false
	var cyl:= CylinderShape3D.new()
	cyl.radius = MOUTH_RADIUS
	cyl.height = MOUTH_HEIGHT
	var cs:= CollisionShape3D.new()
	cs.shape = cyl
	_mouth_area.add_child(cs)
	add_child(_mouth_area)
	_mouth_area.position = _marker_local(N_MOUTH, F_MOUTH)


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([deck_start(), port_out()]),
		PackedVector3Array([port_in(), top_feed()])]


func ghost_runs() -> Array [Array]:
	var out: Array [Array] = []
	for run: PackedVector3Array in belt_runs():
		out.append([to_local(run [0]), to_local(run [1])])
	return out


func _build_ghost_belts() -> void:
	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


func _process(delta: float) -> void:
	if not placement_preview:
		_draw_spin()
		return
	if not is_visible_in_tree():
		return


	if _ghost_belt != null:
		_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms())


	_spin = fposmod(_spin + vane_pitch() * Cfg.SILO_RATE_DEFAULT * delta, TAU)
	_apply_spin()
	_apply_dials()
	_tick_cowl(delta)


func pose_for_shot(fullness: float = 0.65) -> void:
	var want:= int(round(float(capacity()) * clampf(fullness, 0.0, 1.0)))
	queued.clear()
	stored = 0
	for i in want:
		queued.append({ "id": "hay_wad", "state": { "strands": Tech.silo_wad_strands() } })
	_apply_heap()
	_apply_dials()
	_apply_readout()
	_apply_lamps()


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


const LADDER_STANDOFF:= 0.32


const LADDER_SIDESTEP:= 0.16


const LADDER_TOP_LIFT:= 0.7


const LADDER_REACH_W:= 0.8
const LADDER_REACH_D:= 0.8


func has_ladder() -> bool:
	return _climb_area != null


func ladder_face() -> Vector3:
	return global_basis.z.normalized()


func ladder_stand_point() -> Vector3:
	return to_global(_marker_local(N_LADDER_FOOT, F_LADDER_FOOT)) + ladder_face() * LADDER_STANDOFF - global_basis.x.normalized() * LADDER_SIDESTEP


func ladder_exit_point() -> Vector3:
	return to_global(_marker_local(N_LADDER_TOP, F_LADDER_TOP)) - ladder_face() * (LADDER_STANDOFF + 0.35) - global_basis.x.normalized() * LADDER_SIDESTEP


func ladder_top_y() -> float:
	return to_global(_marker_local(N_LADDER_TOP, F_LADDER_TOP)).y + LADDER_TOP_LIFT


func ladder_foot_y() -> float:
	return to_global(_marker_local(N_LADDER_FOOT, F_LADDER_FOOT)).y


func ladder_catches_a_fall() -> bool:
	return true


func _build_climb_volume() -> void:
	var foot:= _marker_local(N_LADDER_FOOT, F_LADDER_FOOT)
	var top:= _marker_local(N_LADDER_TOP, F_LADDER_TOP)
	var height:= top.y + LADDER_TOP_LIFT - foot.y
	if height < 0.5:
		push_warning("HaySilo: the ladder markers are %.2f m apart" % height)
		return
	_climb_area = Area3D.new()
	_climb_area.name = "LadderVolume"
	_climb_area.collision_layer = 0
	_climb_area.collision_mask = Cfg.L_PLAYER
	var box:= BoxShape3D.new()
	box.size = Vector3(LADDER_REACH_W, height, LADDER_REACH_D)
	var shape:= CollisionShape3D.new()
	shape.name = "LadderReach"
	shape.shape = box
	shape.position = Vector3(foot.x - LADDER_SIDESTEP, foot.y + height * 0.5,
		foot.z + LADDER_STANDOFF + 0.07)
	_climb_area.add_child(shape)
	add_child(_climb_area)
	_climb_area.body_entered.connect(_on_climber_entered)
	_climb_area.body_exited.connect(_on_climber_exited)


func _on_climber_entered(body: Node3D) -> void:
	if body.has_method("enter_ladder"):
		body.enter_ladder(self)


func _on_climber_exited(body: Node3D) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder(self)


func support_tops() -> Array [Vector3]:
	var yaw:= global_basis
	var tops: Array [Vector3] = []
	for port: Vector3 in [deck_start(), port_out()]:
		var centre_top:= port - Vector3.UP * Cfg.BELT_SUPPORT_ATTACH_DEPTH
		for side: float in [-1.0, 1.0]:
			tops.append(centre_top + yaw.x * (side * Cfg.BELT_SUPPORT_HALF_WIDTH))
	return tops


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
	for top: Vector3 in support_tops():
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


func rate_min() -> float:
	return Cfg.SILO_RATE_MIN


func rate_max() -> float:
	return maxf(Cfg.SILO_RATE_MIN, ceiling())


static func belt_limit() -> float:
	var v:= maxf(Tech.belt_speed(), 0.001)
	var wait:= 2.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	return BELT_HEADROOM / (Cfg.SILO_PRODUCT_CLEAR * 0.5 / v + wait)


static func ceiling() -> float:
	var top:= minf(Tech.silo_max_rate(), belt_limit())
	var notch:= maxf(Cfg.SILO_RATE_STEP_PER_MIN, 0.001)
	return floor(top * 60.0 / notch + 0.001) * notch / 60.0


static func belt_caps_dial() -> bool:
	return belt_limit() < Tech.silo_max_rate() - 0.001


func rate() -> float:
	return clampf(discharge_rate, rate_min(), rate_max())


func rate_step_up() -> float:
	return minf(rate() + Cfg.SILO_RATE_STEP, rate_max())


func rate_step_down() -> float:
	return maxf(rate() - Cfg.SILO_RATE_STEP, rate_min())


func set_rate(loads_per_second: float) -> void:
	discharge_rate = clampf(loads_per_second, rate_min(), rate_max())
	if discharge_rate > 0.0:
		resume_rate = discharge_rate


func stop() -> void:
	set_rate(0.0)


func start() -> void:
	set_rate(maxf(resume_rate, Cfg.SILO_RATE_STEP))


func rate_per_minute() -> float:
	return rate() * 60.0


func rate_max_per_minute() -> float:
	return rate_max() * 60.0


func set_rate_per_minute(loads_per_minute: float) -> void:
	var notch:= maxf(Cfg.SILO_RATE_STEP_PER_MIN, 0.001)
	set_rate(round(loads_per_minute / notch) * notch / 60.0)


func is_running() -> bool:
	return rate() > 0.0


func is_shut() -> bool:
	return switched_off or not is_running()


func vane_pitch() -> float:
	return TAU / float(maxi(1, Cfg.SILO_ROTOR_VANES))


func measured_rate() -> float:
	var n:= _left_at.size()
	if n == 0:
		return 0.0
	var since:= _clock - _left_at [n - 1]

	var ceiling:= 1.0 / maxf(since, 0.001)


	if n < 2:
		return minf(1.0 / MEASURE_KEEP, ceiling)
	var span:= _left_at [n - 1] - _left_at [0]
	if span <= 0.0:
		return ceiling
	return minf(float(n - 1) / span, ceiling)


func measured_per_minute() -> float:
	return measured_rate() * 60.0


func capacity() -> int:
	return Tech.silo_capacity()


func held() -> int:
	return queued.size() + int(floor(float(stored) / float(maxi(1, Tech.silo_wad_strands()))))


func is_full() -> bool:
	return held() >= capacity()


func straw_room() -> int:
	return maxi(0, (capacity() - held()) * maxi(1, Tech.silo_wad_strands()))


func is_empty() -> bool:
	return queued.is_empty() and stored <= 0


func has_load() -> bool:
	return not queued.is_empty() or stored >= Tech.silo_wad_strands()


func contents() -> Dictionary:
	var out: Dictionary = { }
	for spec: Dictionary in queued:
		var id:= String(spec.get("id", ""))
		out [id] = int(out.get(id, 0)) + 1
	return out


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead


	if not is_running():
		if is_full():


			return tr("STOPPED  ·  it is full and nothing is coming out, press START")
		return ""
	if blocked_for >= Cfg.MACHINE_STARVED_AFTER:


		return tr("OUTFEED BLOCKED  ·  clear the belt below it")
	if has_load():
		return ""
	if starved_for >= Cfg.MACHINE_STARVED_AFTER:


		if _feed_joined():
			return tr("NOTHING COMING IN  ·  nothing is arriving on the feed belt")
		return tr("NOTHING COMING IN  ·  no belt reaches the top opening")
	return ""


var _feed_joined_at:= - INF
var _feed_joined_was:= false


func _feed_joined() -> bool:
	var now:= Time.get_ticks_msec() * 0.001
	if now - _feed_joined_at < 1.0:
		return _feed_joined_was
	_feed_joined_at = now
	_feed_joined_was = false
	var builds:= get_parent() as BuildManager
	if builds == null or _feed == null:
		return false
	for run: BeltPath in builds.conveyors:
		if is_instance_valid(run) and run.downstream == _feed:
			_feed_joined_was = true
			return true
	for run: BeltPath in builds.corners:
		if is_instance_valid(run) and run.downstream == _feed:
			_feed_joined_was = true
			return true


	for building: Node in builds.all_buildings():
		if building == self or not is_instance_valid(building) or not building.has_method("outfeed_deck"):
			continue
		var deck:= building.call("outfeed_deck") as BeltPath
		if deck != null and deck.downstream == _feed:
			_feed_joined_was = true
			return true
	return false


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.SILO_DRAW_KW


func draw_kw() -> float:
	if is_shut():
		return 0.0
	return rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2)
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power


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


func fill() -> float:
	return clampf(float(held()) / float(maxi(1, capacity())), 0.0, 1.0)


func factory_tick(delta: float) -> void:
	var before:= queued.size() + stored
	_swallow()


	starved_for = 0.0 if queued.size() + stored > before else starved_for + delta
	_spin_tick = Engine.get_physics_frames()
	_turn_star(delta)
	_sync_backpressure()
	_apply_lamps()
	_apply_heap()
	_apply_dials()
	_apply_readout()
	_tick_cowl(delta)
	_tick_drive(delta)
	_age_measurements(delta)


func _eats_kind(_kind: int, strands: int) -> bool:
	return strands < 0 or not is_full()


func _swallow() -> void:
	if _mouth_area == null:
		return


	if _feed != null and not is_full():
		var rec:= _feed.take_record(_eats_kind, 0.0, _feed.path_length())
		if not rec.is_empty():
			var state: Variant = rec.get("state")
			var spec:= { "id": BeltRun.ITEM_IDS [int(rec ["kind"])],
				"state": (state as Dictionary).duplicate() if state is Dictionary else { } }
			if int(rec ["needle"]) >= 0:
				(spec ["state"] as Dictionary) ["needle"] = int(rec ["needle"])
			queued.append(spec)
			Audio.play_3d("machine_thud", mouth_position(), -9.0)
	for body in _mouth_area.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		if is_full():
			continue
		var item:= rb as Carryable
		if item != null and not item.item_id.is_empty():


			if item.is_held():
				continue


			if item.freeze and not BeltPath.is_rider(item):
				continue


			var spec:= { "id": item.item_id, "state": item.to_state() }


			if item.holds_needle():
				spec ["state"] = (spec ["state"] as Dictionary).duplicate()
				spec ["state"] ["needle"] = item.needle_index


			BeltPath.release(item)
			queued.append(spec)


			Audio.play_3d("machine_thud", mouth_position(), -9.0)
			if props != null:
				props.remove(item)
			else:
				item.queue_free()
			continue
		if not (rb.collision_layer & Cfg.L_STRAND):
			continue


		if rb.freeze and not BeltPath.is_rider(rb):
			continue


		if rb.has_meta("needle_index"):
			if live == null:
				continue
			BeltPath.release(rb)
			var index:= int(rb.get_meta("needle_index", -1))
			if live.consume_needle(rb):
				pending_needles.append(index)
				Audio.play_3d("machine_feed", mouth_position(), -13.0)
			continue
		if live == null:
			continue
		BeltPath.release(rb)
		if live.consume(rb):
			stored += 1


			Audio.play_3d("machine_feed", mouth_position(), -13.0)


func _turn_star(delta: float) -> void:
	if is_shut() or not has_load():


		blocked_for = 0.0
		_spin_speed = 0.0
		if is_shut():
			_owed = 0.0
		return
	var pitch:= vane_pitch()


	var travel:= rate() * pitch * delta * power
	_spin_speed = rate() * pitch * power
	_spin = fposmod(_spin + travel, TAU)
	_apply_spin()


	_owed = minf(_owed + travel, pitch * 2.0)
	var moved:= false
	while _owed >= pitch:
		if not _discharge():
			break
		_owed -= pitch
		moved = true
	if moved:
		blocked_for = 0.0
	elif _owed >= pitch:
		blocked_for += delta
	else:
		blocked_for = 0.0


func _discharge() -> bool:
	if props == null:


		push_warning("HaySilo: no PropManager; nothing can leave the star")
		return false
	var at:= discharge_point()
	if not _outfeed_room(at):
		return false

	var spec: Dictionary = { }


	var from_queue:= false
	if not queued.is_empty():


		spec = queued.pop_front()
		from_queue = true
	elif stored >= Tech.silo_wad_strands():
		var take: int = mini(stored, Tech.silo_wad_strands())
		stored -= take
		spec = { "id": "hay_wad", "state": { "strands": take } }


		if not pending_needles.is_empty():
			(spec ["state"] as Dictionary) ["needle"] = pending_needles [0]
			pending_needles.remove_at(0)
	else:
		return false


	var kind:= BeltRun.ITEM_IDS.find(String(spec ["id"]))
	if kind >= 0 and _belt != null and _belt.records_props:
		var state: Dictionary = (spec ["state"] as Dictionary).duplicate()
		var strands:= int(state.get("strands", 0))
		var needle:= int(state.get("needle", -1))
		var from_pending:= needle < 0 and not pending_needles.is_empty() and strands > 0
		if from_pending:
			needle = pending_needles [0]
			state ["needle"] = needle


		var seq:= _belt.push_record(kind, strands, needle, state, at, -1.0,
			Cfg.SILO_PRODUCT_CLEAR * 0.5)
		if seq < 0:
			_put_back(spec, from_queue)
			return false
		if from_pending:
			pending_needles.remove_at(0)
		Audio.play_3d("machine_clunk", at, -16.0)
		Audio.play_3d_delayed("item_drop", at, 0.06, -12.0)
		_left_at.append(_clock)
		discharged_record.emit(seq)
		return true
	var item:= props.spawn(String(spec ["id"]),
		Transform3D(global_basis, at + Vector3.UP * DROP_LIFT),
		spec ["state"] as Dictionary) as Carryable
	if item == null:


		_put_back(spec, from_queue)
		return false
	_carry_waiting_needle(item)
	var rb:= item as RigidBody3D
	if rb != null:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO


	Audio.play_3d("machine_clunk", at, -16.0)
	Audio.play_3d_delayed("item_drop", at, 0.06, -12.0)
	_left_at.append(_clock)
	discharged.emit(item)
	return true


func _carry_waiting_needle(item: Carryable) -> void:
	if pending_needles.is_empty() or item.holds_needle() or item.hay_strands() <= 0:
		return
	item.needle_index = pending_needles [0]
	pending_needles.remove_at(0)


func _put_back(spec: Dictionary, from_queue: bool) -> void:
	if from_queue:
		queued.push_front(spec)
		return
	var state: Dictionary = spec.get("state", { })
	stored += int(state.get("strands", 0))
	if state.has("needle"):


		pending_needles.insert(0, int(state ["needle"]))


func _outfeed_room(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	if _room_probe == null:
		_room_probe = BoxShape3D.new()
		_room_probe.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
			Cfg.SILO_PRODUCT_CLEAR, Cfg.SILO_PRODUCT_CLEAR)
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = _room_probe
		_room_query.collision_mask = Cfg.L_PROP
		_room_query.collide_with_areas = false
	_room_query.transform = Transform3D(global_basis,
		at + Vector3.UP * Cfg.SILO_PRODUCT_CLEAR * 0.5)
	return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


func _sync_backpressure() -> void:
	if _feed == null:
		return
	var full:= is_full()
	if _feed.is_blocked() == full:
		return
	_feed.set_blocked(full)
	_feed.set_outlet_held(full)


func _apply_spin() -> void:
	_turn(N_ROTOR, Vector3.RIGHT, _spin)
	_turn(N_FAN, Vector3.RIGHT, fposmod(_spin * FAN_RATIO, TAU))


var _spin_speed:= 0.0
var _spin_tick:= 0


func _draw_spin() -> void:
	if _spin_speed <= 0.0:
		return
	var tps:= float(Engine.physics_ticks_per_second)
	var lead:= clampf((float(Engine.get_physics_frames() - _spin_tick)
		+ Engine.get_physics_interpolation_fraction()) / tps,
		0.0, float(FactoryClock.stride) / tps)
	var at:= fposmod(_spin + _spin_speed * lead, TAU)
	_turn(N_ROTOR, Vector3.RIGHT, at)
	_turn(N_FAN, Vector3.RIGHT, fposmod(at * FAN_RATIO, TAU))


func _tick_cowl(delta: float) -> void:
	_cowl = fposmod(_cowl + deg_to_rad(COWL_SPEED) * delta, TAU)
	_turn(N_COWL, Vector3.UP, _cowl)


static func scale_top() -> float:
	return Cfg.SILO_RATE_BASE_MAX + Cfg.SILO_RATE_PER_RANK * float(TechTree.max_rank("silo_rate"))


static func _scale_fraction(value: float) -> float:
	return clampf((value - Cfg.SILO_RATE_MIN)
		/ maxf(scale_top() - Cfg.SILO_RATE_MIN, 0.001), 0.0, 1.0)


func _apply_dials() -> void:
	var f:= _scale_fraction(rate())
	_turn(N_KNOB, Vector3.RIGHT,
		deg_to_rad(KNOB_SWEEP * 0.5 - KNOB_SWEEP * f))
	_turn(N_NEEDLE_RATE, Vector3.RIGHT,
		deg_to_rad(GAUGE_SWEEP * 0.5 - GAUGE_SWEEP * f))


	_turn(N_NEEDLE_LEVEL, Vector3.RIGHT,
		deg_to_rad(GAUGE_SWEEP * 0.5 - GAUGE_SWEEP * fill()))


func _build_readout() -> void:
	var face:= _readout_material()
	if face == null:
		push_warning("HaySilo: no %s; the console display will keep its modelled number"
			% READOUT_SHADER)
		return
	var pane:= MeshInstance3D.new()
	pane.name = "ReadoutPane"
	pane.mesh = _readout_quad()
	pane.material_override = face
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	pane.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), READOUT_AT)


	add_child(pane)
	_readout = pane


static func _readout_material() -> ShaderMaterial:
	return HayCompressor.shared_material(MODEL, "readout", _make_readout) as ShaderMaterial


static func _make_readout() -> Material:
	var shader: Shader = load(READOUT_SHADER)
	if shader == null:
		return null
	var pitch:= READOUT_DW + READOUT_GAP
	var tall:= READOUT_DH * READOUT_MARGIN
	var m:= ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("cells", float(READOUT_DIGITS))


	m.set_shader_parameter("glyph", Vector2(READOUT_DW / pitch, READOUT_DH / tall))
	m.set_shader_parameter("bar_thick", READOUT_T / READOUT_DH)
	m.set_shader_parameter("bar_len", READOUT_BAR_LEN)
	m.set_shader_parameter("post_thick", READOUT_T / READOUT_DW)
	m.set_shader_parameter("post_len", READOUT_POST_LEN)


	var flats: Dictionary = spec_table().get("flats", { })
	_readout_flat(m, flats, MAT_SEGMENT, "on_color", "on_rough", "on_emit")
	_readout_flat(m, flats, MAT_PLASTIC, "off_color", "off_rough", "")
	return m


static var _quad: QuadMesh


static func _readout_quad() -> QuadMesh:
	if _quad != null and HayCompressor.materials_shared():
		return _quad
	var pitch:= READOUT_DW + READOUT_GAP
	var quad:= QuadMesh.new()
	quad.size = Vector2(pitch * float(READOUT_DIGITS), READOUT_DH * READOUT_MARGIN)
	_quad = quad
	return quad


static func _readout_flat(m: ShaderMaterial, flats: Dictionary, key: String,
		colour: String, rough: String, emit: String) -> void:
	if not flats.has(key):
		return
	var f: Dictionary = flats [key]
	var c: Array = f.get("color", [])
	if c.size() >= 3:
		m.set_shader_parameter(colour,
			Vector3(float(c [0]), float(c [1]), float(c [2])))
	m.set_shader_parameter(rough, float(f.get("rough", 0.4)))
	if emit != "":
		m.set_shader_parameter(emit, float(f.get("emit", 0.0)))


func _apply_readout() -> void:
	if _readout == null:
		return
	var want:= int(round(rate_per_minute()))
	if want == _readout_shows:
		return
	_readout_shows = want
	HayCompressor.drive_instance(_readout, &"value", want)


func _apply_heap() -> void:
	if _heap == null:
		return
	var showing:= not is_empty()
	_heap.visible = showing
	if not showing:
		return
	var s:= lerpf(HEAP_SCALE_MIN, HEAP_SCALE_MAX, fill())


	_heap.transform = Transform3D(
		_heap_rest.basis.scaled(Vector3(lerpf(0.78, 1.0, fill()), s,
			lerpf(0.78, 1.0, fill()))),
		_heap_rest.origin)


func _apply_lamps() -> void:
	var stopped:= is_shut()
	_lamp(MAT_GO, not stopped and has_load() and blocked_for <= 0.0)
	_lamp(MAT_WARN, is_full())
	_lamp(MAT_STOP, stopped or blocked_for > 0.0)


func _lamp(key: String, lit: bool) -> void:
	var pair: Array = _lamp_mats.get(key, [])
	if pair.is_empty() or pair [1 if lit else 0] == null:
		return
	if _lamp_lit.get(key, not lit) == lit:
		return
	_lamp_lit [key] = lit
	for slot: Array in _lamps [key]:
		(slot [0] as MeshInstance3D).set_surface_override_material(slot [1], pair [1 if lit else 0])


func lamp_lit(key: String) -> Variant:
	return _lamp_lit.get(key, null)


func lamp_worn(key: String) -> Material:
	var slots: Array = _lamps.get(key, [])
	if slots.is_empty():
		return null
	return (slots [0] [0] as MeshInstance3D).get_surface_override_material(slots [0] [1])


func _emitter() -> Vector3:
	return global_position + Vector3(0, DRIVE_HEIGHT, 0)


func _drive_pitch() -> float:
	return lerpf(PITCH_AT_MIN, PITCH_AT_MAX, _scale_fraction(rate()))


func _tick_drive(delta: float) -> void:


	_drive_target = DRIVE_DB if has_load() and not is_shut() else DRIVE_SILENT
	if _drive_voice < 0:
		if _drive_target <= DRIVE_SILENT:
			return
		_drive_voice = Audio.loop_acquire(DRIVE_LOOP)
		_drive_gain = DRIVE_SILENT
		if _drive_voice < 0:
			return
	_drive_gain = move_toward(_drive_gain, _drive_target, DRIVE_RAMP * delta)
	if _drive_target <= DRIVE_SILENT and _drive_gain <= DRIVE_SILENT + 0.5:
		_release_drive()
		return


	Audio.loop_update(_drive_voice, _emitter(), _drive_gain,
		_drive_pitch() * MachinePower.loop_pitch(power))


func _release_drive() -> void:
	if _drive_voice < 0:
		return
	Audio.loop_release(_drive_voice)
	_drive_voice = -1
	_drive_gain = DRIVE_SILENT
	_drive_target = DRIVE_SILENT


func _age_measurements(delta: float) -> void:
	_clock += delta
	var drop:= 0
	while drop < _left_at.size() and _clock - _left_at [drop] > MEASURE_KEEP:
		drop += 1
	if drop > 0:


		_left_at = _left_at.slice(drop)


func _exit_tree() -> void:
	_release_drive()


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.SILO_COST


func to_dict() -> Dictionary:
	return {
		"type": "hay_silo",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"rate": discharge_rate,


		"resume": resume_rate,


		"queued": queued.duplicate(true),
		"stored": stored,
		"needles": pending_needles,
	}


func from_dict(d: Dictionary) -> void:


	discharge_rate = float(d.get("rate", Cfg.SILO_RATE_DEFAULT))


	resume_rate = float(d.get("resume", maxf(discharge_rate, Cfg.SILO_RATE_DEFAULT)))
	queued.clear()
	for one: Variant in d.get("queued", []):
		if typeof(one) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = one
		if not spec.has("id"):
			continue
		queued.append({
			"id": String(spec ["id"]),
			"state": spec.get("state", { }) as Dictionary,
		})
	stored = maxi(0, int(d.get("stored", 0)))
	pending_needles = PackedInt32Array()
	for n: Variant in d.get("needles", []):
		pending_needles.append(int(n))


	while queued.size() > capacity():
		queued.pop_back()
