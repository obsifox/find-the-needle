class_name HayPelletizer
extends Node3D


const MODEL:= "res://assets/models/hay_pelletizer.glb"
const SPEC:= "res://assets/models/hay_pelletizer_materials.json"

const N_BELT_IN:= "Marker_BeltIn"
const N_SPOUT:= "Marker_Spout"
const N_PANEL:= "Marker_Panel"

const CLIP:= "Run"


const MAT_GO:= "M_HP_LampGo"
const GO_IDLE:= 0.35
const GO_RUNNING:= 1.8


const STUB:= 1.0


const STUB_REACH:= 0.2


const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06
const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 10
const ARROW_SPEED:= 0.9


const INTAKE_OVER:= 0.3
const INTAKE_LENGTH:= STUB + INTAKE_OVER
const INTAKE_HEIGHT:= 0.55


const MUZZLE:= Vector3(0.395, 0.695, 0.601)


const MUZZLE_CLEAR:= 0.22


const PORT_BACK:= 0.8
const PORT_UP:= 0.94

const GRIND_LOOP_DB:= -14.0
const GRIND_LOOP_SILENT:= -80.0
const GRIND_LOOP_RAMP:= 140.0
const GRIND_LOOP_HEIGHT:= 1.2

signal bricked(brick: EcoBrick)

var live: LiveStrandManager


var props: PropManager
var placement_preview:= false


var stored:= 0


var pending_needles:= PackedInt32Array()

var starved_for:= 0.0


var throw_distance:= Cfg.PELLETIZER_THROW_DISTANCE


var port_reach:= STUB_REACH


func held_needles() -> PackedInt32Array:
	return pending_needles


var _model: Node3D
var _anim: AnimationPlayer
var _intake: Area3D
var _belt: BeltPath
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D
var _flow_phase:= 0.0
var _launcher: BrickLauncher

var _arc: LaunchArc


var _aim: ThrowAim

var _go_meshes: Array [MeshInstance3D] = []
var _body: StaticBody3D


var _grind:= -1.0


var _batch:= 0
var _cycle:= 0.0


var _holding:= false


var _aim_belt: BeltPath = null
var _aim_at:= Vector3.ZERO
var _aim_flight:= 0.0
var _aim_stamp:= - AIM_RESOLVE_MS

var _hold_recheck:= 0.0

var _loop_voice:= -1
var _loop_gain:= GRIND_LOOP_SILENT
var _loop_target:= GRIND_LOOP_SILENT


var _ports: Array [Node3D] = []

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	_build_collider()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()


		_build_launcher()
		_build_arc()
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)
	_build_belt()
	_build_intake_area()
	_build_launcher()
	_build_aim()
	add_to_group("hay_pelletizers")
	_apply_lamp()


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayPelletizer: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("HayPelletizer: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	_go_meshes.clear()
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
				built [key] = _material(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key == MAT_GO and not _go_meshes.has(mesh):
				_go_meshes.append(mesh)
	if not missed.is_empty():
		push_warning("HayPelletizer: no table entry for %s" % ", ".join(missed.keys()))


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


func _build_animation() -> void:
	_anim = _find("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		return
	var clip:= _clip_name()
	if clip == "":
		return
	var a:= _anim.get_animation(clip)
	if a != null:


		a.loop_mode = Animation.LOOP_LINEAR


func _clip_name() -> String:
	if _anim == null:
		return ""
	if _anim.has_animation(CLIP):
		return CLIP
	for name in _anim.get_animation_list():
		if name.ends_with(CLIP):
			return name
	return ""


func _build_collider() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	_body.collision_mask = 0
	add_child(_body)

	for spec: Array in [
			[Vector3(1.58, 1.18, 1.48), Vector3(0.0, 0.71, 0.0)],
			[Vector3(1.88, 0.1, 1.76), Vector3(0.0, 0.05, 0.0)],
			[Vector3(1.7, 0.5, 1.6), Vector3(0.0, 1.54, 0.0)],
			[Vector3(1.24, 0.74, 1.24), Vector3(0.0, 2.16, 0.0)]]:
		var box:= BoxShape3D.new()
		box.size = spec [0]
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.position = spec [1]
		_body.add_child(cs)

	var pipe:= CylinderShape3D.new()
	pipe.radius = 0.3
	pipe.height = 1.72
	var pcs:= CollisionShape3D.new()
	pcs.shape = pipe
	var dir:= MUZZLE.normalized()
	var start:= Vector3(0.82, 0.42, 0.44)
	pcs.position = start + dir * (pipe.height * 0.5)

	pcs.basis = Basis(Quaternion(Vector3.UP, dir))
	_body.add_child(pcs)


func _build_belt() -> void:
	_belt = BeltPath.new()
	_belt.name = "IntakeDeck"
	add_child(_belt)
	_belt.build_path(belt_runs() [0], Cfg.BELT_JOINT_OVERLAP)


	_belt.set_outlet_held(true)
	_belt.set_hold_filter(func(b: Object) -> bool:
		return is_full() or _blocks_mouth(b))


	_belt.records_props = true
	_belt.hold_records(_eats_kind)


func _eats_kind(kind: int, _strands: int) -> bool:
	return kind == BeltRun.Kind.WAD


func _build_ghost_belt() -> void:
	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


	var fmm:= MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = ConveyorKit.flow_arrow_mesh()
	fmm.instance_count = ARROW_CAPACITY
	fmm.visible_instance_count = 0
	_ghost_flow = MultiMeshInstance3D.new()
	_ghost_flow.name = "GhostFlow"
	_ghost_flow.multimesh = fmm
	_ghost_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_flow.material_override = ConveyorKit.flow_material()
	add_child(_ghost_flow)
	_shape_flow()


func _process(delta: float) -> void:
	if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
		return
	_flow_phase += delta * ARROW_SPEED
	_shape_flow()


	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, [])


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([intake_port(), port_in()])]


func _shape_flow() -> void:
	var length:= stub()
	var mm:= _ghost_flow.multimesh
	var n:= clampi(maxi(1, int(round(length / ARROW_PITCH))), 1, ARROW_CAPACITY)
	var pitch:= length / n
	var phase:= fmod(_flow_phase, pitch)
	var near:= - PORT_BACK
	for i in n:


		var along:= fmod(i * pitch + phase, length)
		mm.set_instance_transform(i, Transform3D(Basis(),
			Vector3(0.0, PORT_UP + ARROW_LIFT, near - length + along)))
		var fade:= (clampf(along / ARROW_FADE, 0.0, 1.0)
			* clampf((length - along) / ARROW_FADE, 0.0, 1.0))
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, fade))
	mm.visible_instance_count = n


func _build_intake_area() -> void:
	_intake = Area3D.new()
	_intake.name = "IntakeMouth"
	_intake.collision_layer = 0

	_intake.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_intake.monitorable = false
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
		INTAKE_HEIGHT, intake_length())
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
	_intake.add_child(cs)
	add_child(_intake)


	_intake.position = to_local(port_in() - forward() * (intake_length() * 0.5))
	_intake.position.y = PORT_UP


func _build_launcher() -> void:
	_launcher = BrickLauncher.new()
	_launcher.name = "Discharge"
	add_child(_launcher)
	_launcher.position = _marker_local(N_SPOUT, Vector3(1.5, 1.61, 1.47))
	_launcher.ground_y = global_position.y
	_launcher.muzzle_clearance = MUZZLE_CLEAR
	_launcher.throw_distance = throw_distance


	_launcher.aim_along(global_basis * MUZZLE.normalized())


func _build_arc() -> void:
	_arc = LaunchArc.new()
	_arc.name = "ThrowArc"
	add_child(_arc)
	_arc.set_shown(true)


func show_range(on: bool) -> void:
	if _aim != null:
		_aim.set_panel(on)
		return
	if not on:
		if _arc != null:
			_arc.set_shown(false)
		return
	if _arc == null:
		_build_arc()


	_aim_arc()
	_arc.set_shown(true)


func range_shown() -> bool:
	if _aim != null:
		return _aim.mode() == ThrowAim.PANEL and _aim.arc_drawn()
	return _arc != null and _arc.visible and _arc.drawn()


func _build_aim() -> void:
	_aim = ThrowAim.new()
	_aim.name = "Aim"
	_aim.source = self
	_aim.spot_radius = Cfg.PELLETIZER_PAD_RADIUS
	add_child(_aim)


func throw_aim() -> ThrowAim:
	return _aim


func pin_range(seconds: float) -> void:
	if _aim != null:
		_aim.pin(seconds)


func range_pinned_left() -> float:
	return _aim.pinned_left() if _aim != null else 0.0


func throw_path() -> Dictionary:
	if _launcher == null:
		return { }
	_launcher.ground_y = global_position.y
	_launcher.muzzle_clearance = MUZZLE_CLEAR
	_launcher.throw_distance = throw_distance
	_launcher.aim_along(global_basis * MUZZLE.normalized())
	return { "from": _launcher.release_point(), "velocity": _launcher.aim_velocity(),
		"ground_y": _launcher.ground_y, "damped": false }


func _aim_arc() -> void:
	if _arc == null or _launcher == null:
		return
	_launcher.ground_y = global_position.y
	_launcher.muzzle_clearance = MUZZLE_CLEAR
	_launcher.throw_distance = throw_distance
	_launcher.aim_along(global_basis * MUZZLE.normalized())


	_arc.aim(_launcher.release_point(), _launcher.aim_velocity(),
		_launcher.ground_y, Cfg.PELLETIZER_PAD_RADIUS)


func throw_target() -> Vector3:
	return _launcher.landing_spot() if _launcher != null else global_position


func set_throw_distance(metres: float) -> void:
	throw_distance = clampf(metres,
		Cfg.PELLETIZER_THROW_MIN, Cfg.PELLETIZER_THROW_MAX)
	if _launcher != null:
		_launcher.throw_distance = throw_distance

	_aim_stamp = - AIM_RESOLVE_MS
	if _arc != null:
		_aim_arc()


func port_in() -> Vector3:
	return to_global(_marker_local(N_BELT_IN, Vector3(0, PORT_UP, - PORT_BACK)))


func intake_port() -> Vector3:
	var local:= _marker_local(N_BELT_IN, Vector3(0, PORT_UP, - PORT_BACK))
	return to_global(local - Vector3(0, 0, stub()))


func stub() -> float:
	return STUB + port_reach


func intake_length() -> float:
	return stub() + INTAKE_OVER


func deck() -> BeltPath:
	return _belt


static func default_forward(look: Vector3) -> Vector3:
	var flat:= Vector3(look.x, 0.0, look.z)
	if flat.length_squared() < 1e-06:
		return Vector3.BACK
	return flat.normalized()


func forward() -> Vector3:
	var d:= global_position - port_in()
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, Vector3(-0.95, 0.92, 0.42)))


func spout_position() -> Vector3:
	return to_global(_marker_local(N_SPOUT, Vector3(1.5, 1.61, 1.47)))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


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


func buffer_capacity() -> int:
	return Tech.pellet_buffer()


func is_full() -> bool:
	return stored >= buffer_capacity()


func straw_room() -> int:
	return maxi(0, buffer_capacity() - stored)


func is_running() -> bool:
	return _grind >= 0.0 and not _holding


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead


	var stuck:= _jammed_load()
	if stuck != "":
		return tr("WRONG LOAD  ·  take the %s out of the intake") % stuck
	if _holding:
		return tr("BELT FULL  ·  no room where the bricks land")
	if _grind >= 0.0:
		return ""
	if starved_for >= Cfg.MACHINE_STARVED_AFTER:
		return tr("NO HAY  ·  nothing is reaching the intake")
	return ""


func _jammed_load() -> String:
	if _belt == null:
		return ""
	var rb:= _belt.waiting_rider()
	if rb == null or not _blocks_mouth(rb):
		return ""
	var item:= rb as Carryable
	return Cfg.lower_in_english(item.display_name) if item != null else tr("load")


func grind_progress() -> float:
	if _grind < 0.0:
		return 0.0
	return clampf(_grind / maxf(_cycle, 0.001), 0.0, 1.0)


func factory_tick(delta: float) -> void:
	var held:= stored
	_intake_hay()


	starved_for = 0.0 if stored > held else starved_for + delta
	_tick_grind(delta)
	_sync_backpressure()
	_tick_loop(delta)


func _eats(body: Object) -> bool:
	var rb:= body as RigidBody3D
	if rb == null:
		return false


	if rb is EcoBrick or rb is HayBale:
		return false


	if rb is HayWad:
		return true
	return bool(rb.collision_layer & Cfg.L_STRAND)


func _blocks_mouth(body: Object) -> bool:
	var rb:= body as RigidBody3D
	return rb != null and bool(rb.collision_layer & Cfg.L_PROP) and not _eats(rb)


func _intake_hay() -> void:
	if live == null or _intake == null:
		return


	if _belt != null and not is_full():
		var m:= _belt.s_at(_mouth())
		var rec:= _belt.take_record(Callable(), m - intake_length() * 0.5, m + intake_length() * 0.5)
		if not rec.is_empty():
			stored += int(rec ["strands"])
			if int(rec ["needle"]) >= 0:
				pending_needles.append(int(rec ["needle"]))
			Audio.play_3d("machine_thud", _mouth(), -9.0)
	for body in _intake.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		if not _eats(rb):
			continue
		var wad:= rb as HayWad
		if wad != null:
			if (wad.freeze and not BeltPath.is_rider(wad)) or is_full():
				continue


			BeltPath.release(wad)
			stored += wad.strands


			if wad.holds_needle():
				pending_needles.append(wad.needle_index)


			Audio.play_3d("machine_thud", _mouth(), -9.0)
			if props != null:
				props.remove(wad)
			else:
				wad.queue_free()
			continue


		if rb.freeze and not BeltPath.is_rider(rb):
			continue


		if rb.has_meta("needle_index"):
			BeltPath.release(rb)
			var index:= int(rb.get_meta("needle_index", -1))
			if live.consume_needle(rb):
				pending_needles.append(index)
			continue
		if is_full():
			continue


		BeltPath.release(rb)
		if live.consume(rb):
			stored += 1


			Audio.play_3d("machine_feed", _mouth(), -13.0)


func _mouth() -> Vector3:
	if _intake == null:
		return global_position
	return _intake.global_position


func _tick_grind(delta: float) -> void:
	if _grind < 0.0:


		if power <= 0.0:
			return
		if stored >= Tech.pellet_brick_strands():


			_clear_old_pad()
			_start_grind()
		return


	_grind = minf(_grind + delta * power, _cycle)
	if _grind >= _cycle and _outfeed_clear(delta):
		_finish_grind()


func _outfeed_clear(delta: float) -> bool:
	if _holding:
		_hold_recheck -= delta
		if _hold_recheck > 0.0:
			return false
		_hold_recheck = HOLD_RECHECK

	var now:= Time.get_ticks_msec()
	var stale:= _aim_belt != null and not is_instance_valid(_aim_belt)
	if stale or now - _aim_stamp >= AIM_RESOLVE_MS:
		_aim_stamp = now
		_resolve_aim()
	var clear:= true
	if _aim_belt != null and is_instance_valid(_aim_belt):
		clear = _deck_takes(_aim_belt)
	if not clear and not _holding:
		_holding = true
		_hold_recheck = HOLD_RECHECK
		if _anim != null:
			_anim.pause()
		_loop_target = GRIND_LOOP_SILENT
		_apply_lamp()
	elif clear:
		_holding = false
	return clear


func _deck_takes(belt: BeltPath) -> bool:
	var paths: Array [BeltPath] = [belt]
	paths.append_array(belt._shared)
	var catching:= false
	for p in paths:
		if not is_instance_valid(p):
			continue
		if p.is_blocked() or not p.has_room_near(_aim_at, p.drive_speed * _aim_flight):
			return false
		catching = catching or p._catching
	return catching


func _resolve_aim() -> void:
	_aim_belt = null
	if _launcher == null:
		return
	var land:= _launcher.belt_landing(BRICK_REACH)
	if land.is_empty():
		return
	_aim_belt = land ["belt"]
	_aim_at = land ["at"]
	_aim_flight = land ["t"]


const BRICK_REACH:= 0.11

const HOLD_RECHECK:= 0.2


const AIM_RESOLVE_MS:= 5000


func _start_grind() -> void:


	_batch = Tech.pellet_brick_strands()
	_cycle = maxf(Tech.pellet_cycle_seconds(), 0.001)
	stored -= _batch
	_grind = 0.0
	if _anim != null and _clip_name() != "":
		_apply_grind_speed()
		_anim.play(_clip_name())
	if _loop_voice < 0:


		_loop_voice = Audio.loop_acquire("motor_a")
		_loop_gain = GRIND_LOOP_SILENT
	_loop_target = GRIND_LOOP_DB


	Audio.play_3d("machine_clunk", _emitter(), -12.0)
	_apply_lamp()


func _finish_grind() -> void:
	_grind = -1.0
	if _anim != null:
		_anim.pause()
	_loop_target = GRIND_LOOP_SILENT
	_throw_brick()
	_apply_lamp()


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.PELLETIZER_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


const WIRE_PORT_FALLBACKS: Array [Vector3] = [
	Vector3(-0.75, 1.79, 0.0), Vector3(0.75, 1.79, 0.0)]


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2, WIRE_PORT_FALLBACKS,
			_fitting_materials())
	return _ports


func _fitting_materials() -> Dictionary:
	var spec:= spec_table()
	if spec.is_empty():
		return { }
	var shader: Shader = load(HayCompressor.SHADER)
	return {
		"steel": _material("M_HP_Frame", spec, shader),
		"porcelain": _material("M_HP_Porcelain", spec, shader),
		"copper": _material("M_HP_Copper", spec, shader),
	}


static func _material(key: String, spec: Dictionary, shader: Shader) -> Material:
	return HayCompressor.shared_material(MODEL, key,
		func() -> Material: return _make_surface(key, spec, shader))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= HayCompressor.make_material(key, spec, shader)
	return HayCompressor.lamp_material(made) if key == MAT_GO else made


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_apply_grind_speed()


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


func _apply_grind_speed() -> void:
	if _anim != null:
		_anim.speed_scale = power


func _clear_old_pad() -> void:
	if props == null:
		return
	var spot:= throw_target()
	var r2:= PropManager.WORK_SPOT_R * PropManager.WORK_SPOT_R
	var heap: Array [Carryable] = []

	for item in props.items:
		if not is_instance_valid(item) or item.hay_strands() <= 0:
			continue
		if item.global_position.distance_squared_to(spot) >= r2:
			continue
		if props.is_spoken_for(item):
			continue
		heap.append(item)
	for i in heap.size() - Cfg.PELLETIZER_PAD_BRICKS:
		props.fold_away(heap [i])


func _throw_brick() -> void:
	if props == null:


		push_warning("HayPelletizer: no PropManager; the brick cannot be created")
		return
	if _launcher == null:
		return
	var brick:= _launcher.discharge(props, _batch)
	if brick == null:
		return


	if not pending_needles.is_empty():
		brick.needle_index = pending_needles [0]
		pending_needles.remove_at(0)


	Audio.play_3d("machine_vent", _launcher.global_position, -4.0)
	Audio.play_3d_delayed("machine_clunk", _launcher.global_position, 0.05, -9.0)
	bricked.emit(brick)


func _sync_backpressure() -> void:
	if _belt == null:
		return
	var full:= is_full()
	if _belt.is_blocked() != full:
		_belt.set_blocked(full)


func _apply_lamp() -> void:
	HayCompressor.light_lamps(_go_meshes, GO_RUNNING if is_running() else GO_IDLE)


func go_energy() -> float:
	return HayCompressor.lamp_energy(_go_meshes)


func _emitter() -> Vector3:
	return global_position + Vector3(0, GRIND_LOOP_HEIGHT, 0)


func _tick_loop(delta: float) -> void:
	if _loop_voice < 0:
		return
	_loop_gain = move_toward(_loop_gain, _loop_target, GRIND_LOOP_RAMP * delta)
	if _loop_target <= GRIND_LOOP_SILENT and _loop_gain <= GRIND_LOOP_SILENT + 0.5:
		_release_loop()
		return

	Audio.loop_update(_loop_voice, _emitter(), _loop_gain,
		MachinePower.loop_pitch(power))


func _release_loop() -> void:
	if _loop_voice < 0:
		return
	Audio.loop_release(_loop_voice)
	_loop_voice = -1
	_loop_gain = GRIND_LOOP_SILENT
	_loop_target = GRIND_LOOP_SILENT


func _exit_tree() -> void:
	_release_loop()


func set_preview_valid(valid: bool) -> void:
	if _arc != null and placement_preview:


		_arc.set_tint(Cfg.COL_GHOST_OK if valid else Cfg.COL_GHOST_BAD)
		_aim_arc()
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.PELLETIZER_COST


func to_dict() -> Dictionary:
	return {
		"type": "hay_pelletizer",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"stored": stored,


		"throw": throw_distance,

		"needles": pending_needles,


		"port_reach": port_reach,
	}
