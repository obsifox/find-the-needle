class_name TubeLauncher
extends Node3D


const MODEL:= "res://assets/models/compiled/tube_launcher.scn"
const SPEC:= "res://assets/models/tube_launcher_materials.json"


const MIN_DITHER_FLIGHT:= 0.5

const N_BELT_IN:= "Marker_BeltIn"
const N_MUZZLE:= "Marker_Muzzle"
const N_BORE:= "Marker_Bore"
const N_PANEL:= "Marker_Panel"
const N_TILT:= "Tilt"
const N_RECOIL:= "Recoil"
const N_YAW:= "Yaw"


const N_RAM:= ["Ram_L", "Ram_R"]
const N_ROD:= ["Ram_L_Rod", "Ram_R_Rod"]
const N_CLEVIS:= ["Marker_ClevisL", "Marker_ClevisR"]


const CLIP:= "Aim"


const RECOIL_BACK:= 0.2
const RECOIL_RETURN:= 0.26


const N_LAMPS:= 5
const LAMP_MAT:= "M_TL_Glow"
const LAMP_LIT:= 1.8
const LAMP_DARK:= 0.06


const PORT_BACK:= 1.18
const PORT_UP:= 0.94


const STUB:= 0.8


const STUB_REACH:= 0.02


const INTAKE_OVER:= 0.3
const INTAKE_LENGTH:= STUB + INTAKE_OVER
const INTAKE_HEIGHT:= 0.55


const PAD_ITEMS:= 6
const PAD_RADIUS:= 1.1
const PAD_HEIGHT:= 0.8


const SLEW_GAIN:= -11.0
const SLEW_PITCH_MIN:= 0.86
const SLEW_PITCH_MAX:= 1.12


const SLEW_DEADBAND:= 0.001

signal launched(item: Carryable)

var live: LiveStrandManager


var props: PropManager
var placement_preview:= false


var aim:= Cfg.LAUNCHER_AIM_DEFAULT:
	set(value):
		aim = clampf(value, 0.0, 1.0)


var power:= Cfg.LAUNCHER_POWER_DEFAULT:
	set(value):
		power = clampf(value, 0.0, 1.0)
		_apply_lamps()


var stored:= 0


var port_reach:= STUB_REACH


var pending_needles:= PackedInt32Array()


func held_needles() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for spec: Dictionary in _queue:
		var index:= int((spec.get("state", { }) as Dictionary).get("needle", -1))
		if index >= 0:
			out.append(index)
	out.append_array(pending_needles)
	return out


var starved_for:= 0.0

var _model: Node3D
var _anim: AnimationPlayer

var _ports: Array [Node3D] = []
var _intake: Area3D
var _belt: BeltPath
var _ghost_belt: BeltGhost

var _supports: Node3D
var _body: StaticBody3D
var _arc: LaunchArc


var _aim: ThrowAim

var _tilt: Node3D
var _recoil: Node3D
var _muzzle: Node3D
var _bore: Node3D

var _lamps: Array [MeshInstance3D] = []


var _aim_at:= 0.0
var _aim_length:= 0.0

var _recoil_at:= 0.0

var _reload:= -1.0


var _queue: Array [Dictionary] = []


var _pad_probe: CylinderShape3D
var _pad_query: PhysicsShapeQueryParameters3D


var _slew_voice:= -1

static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_find_rig()
	_build_animation()
	_build_collider()
	_apply_lamps()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()


		_build_arc()
		set_preview_valid(true)
		return

	set_process(false)


	FactoryClock.join(self)
	_build_belt()
	_build_intake_area()
	_build_aim()
	add_to_group("tube_launchers")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("TubeLauncher: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for node in _model.find_children("*", "CollisionObject3D", true, false):
		var stray:= node as CollisionObject3D
		if stray == null:
			continue
		push_warning("TubeLauncher: %s ships a collider (%s); the code builds its own"
			% [MODEL, stray.name])
		stray.queue_free()
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("TubeLauncher: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	_lamps.clear()
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
					func() -> Material: return _make_surface(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])


			if key == LAMP_MAT and not _lamps.has(mesh):
				_lamps.append(mesh)


	_lamps.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return String(a.name) < String(b.name))
	if not missed.is_empty():
		push_warning("TubeLauncher: no table entry for %s" % ", ".join(missed.keys()))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= HayCompressor.make_material(key, spec, shader)
	return HayCompressor.lamp_material(made) if key == LAMP_MAT else made


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


func _find_rig() -> void:
	_tilt = _find(N_TILT) as Node3D
	_recoil = _find(N_RECOIL) as Node3D
	_muzzle = _find(N_MUZZLE) as Node3D
	_bore = _find(N_BORE) as Node3D
	if _tilt == null or _muzzle == null or _bore == null:
		push_warning("TubeLauncher: %s is missing its aim rig; the tube will not move" % MODEL)


func _build_animation() -> void:
	_anim = _find("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		push_warning("TubeLauncher: %s has no AnimationPlayer; the tube will not move" % MODEL)
		return
	var clip:= _clip_name()
	if clip == "":
		push_warning("TubeLauncher: %s has no %s clip" % [MODEL, CLIP])
		return
	var a:= _anim.get_animation(clip)
	if a != null:


		a.loop_mode = Animation.LOOP_NONE
		_aim_length = a.length
	_anim.play(clip)
	_anim.pause()
	_aim_at = _aim_length * clampf(aim, 0.0, 1.0)
	_seek_aim()


func _clip_name() -> String:
	if _anim == null:
		return ""
	for candidate: String in [CLIP, "global/" + CLIP, "" + CLIP]:
		if _anim.has_animation(candidate):
			return candidate
	for name in _anim.get_animation_list():
		if name.ends_with(CLIP):
			return name
	var list:= _anim.get_animation_list()
	return list [0] if list.size() > 0 else ""


func _build_collider() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	_body.collision_mask = 0
	add_child(_body)


	for spec: Array in [
			[Vector3(1.76, 0.48, 2.5), Vector3(0.0, 0.24, 0.0)],
			[Vector3(1.12, 1.67, 0.72), Vector3(0.0, 1.37, -0.82)],
			[Vector3(1.18, 0.86, 1.36), Vector3(0.0, 1.0, 0.2)],
			[Vector3(0.22, 0.86, 0.46), Vector3(0.74, 0.91, -0.54)]]:
		var box:= BoxShape3D.new()
		box.size = spec [0]
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.position = spec [1]
		_body.add_child(cs)


func _build_belt() -> void:
	_belt = BeltPath.new()
	_belt.name = "IntakeDeck"
	add_child(_belt)
	_belt.build_path(belt_runs() [0], Cfg.BELT_JOINT_OVERLAP)


	_belt.set_outlet_held(true)


	_belt.records_props = true
	_belt.hold_records(_eats_kind)


	call_deferred("_build_stub_legs")


func _build_stub_legs() -> void:
	if not is_inside_tree() or _belt == null:
		return
	var both:= support_xforms()
	var legs: Array [Transform3D] = both [0]
	var feet: Array [Transform3D] = both [1]
	if legs.is_empty():
		return
	if _supports != null:
		_supports.queue_free()
	_supports = Node3D.new()
	_supports.name = "StubSupports"


	_supports.top_level = true
	add_child(_supports)
	_supports.add_child(_support_mm("Legs", ConveyorKit.leg_mesh(), legs))
	_supports.add_child(_support_mm("Feet", ConveyorKit.foot_mesh(), feet))


func support_xforms() -> Array:
	var space:= get_world_3d().direct_space_state
	var own: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var col:= node as CollisionObject3D
		if col != null:
			own.append(col.get_rid())
	var across:= global_basis.x.normalized()
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []


	var deck:= intake_port() + global_basis.y * - Cfg.BELT_SUPPORT_ATTACH_DEPTH
	for side: float in [-1.0, 1.0]:
		var top: Vector3 = deck + across * (side * Cfg.BELT_SUPPORT_HALF_WIDTH)
		var q:= PhysicsRayQueryParameters3D.create(top,
			top - Vector3(0.0, Cfg.BELT_SUPPORT_MAX_DROP, 0.0))


		q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD


		q.exclude = own
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			continue
		var ground: Vector3 = hit ["position"]
		var drop: float = top.y - ground.y
		if drop < 0.05:
			continue


		var upright:= Basis.looking_at(- global_basis.z, Vector3.UP)
		legs.append(Transform3D(upright.scaled_local(Vector3(1.0, drop, 1.0)), top))
		feet.append(Transform3D(upright, ground))
	return [legs, feet]


func _support_mm(node_name: String, mesh: Mesh, at: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, at [i])
	var mi:= MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	return mi


func _build_ghost_belt() -> void:
	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([intake_port(), port_in()])]


func _process(_delta: float) -> void:
	if not placement_preview or _ghost_belt == null or not is_visible_in_tree():
		return


	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms())


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


func _build_arc() -> void:
	_arc = LaunchArc.new()
	_arc.name = "AimArc"

	_arc.damped = true
	add_child(_arc)
	_arc.set_shown(placement_preview)


func _build_aim() -> void:
	_aim = ThrowAim.new()
	_aim.name = "Aim"
	_aim.source = self
	_aim.spot_radius = maxf(Cfg.LAUNCHER_SPREAD * 2.5, 0.34)
	add_child(_aim)


func throw_aim() -> ThrowAim:
	return _aim


func pin_range(seconds: float) -> void:
	if _aim != null:
		_aim.pin(seconds)


func range_pinned_left() -> float:
	return _aim.pinned_left() if _aim != null else 0.0


func throw_path() -> Dictionary:
	return { "from": muzzle_position(), "velocity": launch_velocity(),
		"ground_y": global_position.y, "damped": true }


static func tilt_for(a: float) -> float:
	return lerpf(Cfg.LAUNCHER_TILT_MIN, Cfg.LAUNCHER_TILT_MAX, clampf(a, 0.0, 1.0))


static func speed_for(p: float) -> float:
	return lerpf(Cfg.LAUNCHER_SPEED_MIN, Cfg.LAUNCHER_SPEED_MAX, clampf(p, 0.0, 1.0))


static func aim_for_tilt(degrees: float) -> float:
	var span: float = Cfg.LAUNCHER_TILT_MAX - Cfg.LAUNCHER_TILT_MIN
	if absf(span) < 0.001:
		return 0.0
	return clampf((degrees - Cfg.LAUNCHER_TILT_MIN) / span, 0.0, 1.0)


func bore_direction() -> Vector3:
	if _muzzle == null or _bore == null:
		return - global_basis.z
	var d:= _bore.global_position - _muzzle.global_position
	if d.length_squared() < 1e-06:
		return - global_basis.z
	return d.normalized()


func muzzle_position() -> Vector3:
	if _muzzle == null:
		return to_global(Vector3(0.0, 1.26, 1.82))
	return _muzzle.global_position


func launch_velocity() -> Vector3:
	return bore_direction() * speed_for(power)


func landing_spot() -> Vector3:
	var points:= LaunchArc.sample(muzzle_position(), launch_velocity(),
		global_position.y, true)
	return points [points.size() - 1]


func range_metres() -> float:
	var at:= landing_spot()
	return Vector2(at.x - global_position.x, at.z - global_position.z).length()


func show_arc(on: bool) -> void:
	if _aim != null:
		_aim.set_panel(on)
	elif _arc != null:
		_arc.set_shown(on)


func set_preview_valid(valid: bool) -> void:
	if _arc != null:


		_arc.set_tint(Cfg.COL_GHOST_OK if valid else Cfg.COL_GHOST_BAD)


		if placement_preview:
			_aim_arc()
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func _apply_aim(delta: float) -> void:
	if _anim == null or _aim_length <= 0.0:
		_tick_slew_sound(0.0)
		return
	var want:= clampf(aim, 0.0, 1.0) * _aim_length
	_tick_slew_sound(absf(want - _aim_at))
	if absf(want - _aim_at) > 0.0001:


		var span: float = maxf(Cfg.LAUNCHER_TILT_MAX - Cfg.LAUNCHER_TILT_MIN, 0.001)
		var rate:= Cfg.LAUNCHER_SLEW_SPEED / span * _aim_length
		_aim_at = move_toward(_aim_at, want, rate * delta)
		_seek_aim()


func _tick_slew_sound(travel: float) -> void:
	if placement_preview:
		return
	if travel > SLEW_DEADBAND:
		if _slew_voice < 0:
			_slew_voice = Audio.loop_acquire("launcher_slew")
		if _slew_voice >= 0:

			var t: float = clampf(travel / maxf(_aim_length, 0.001), 0.0, 1.0)
			Audio.loop_update(_slew_voice, _tube_position(), SLEW_GAIN,
				lerpf(SLEW_PITCH_MAX, SLEW_PITCH_MIN, t))
		return
	if _slew_voice >= 0:
		Audio.loop_release(_slew_voice)
		_slew_voice = -1
		Audio.play_3d("launcher_stop", _tube_position(), -12.0)


func _tube_position() -> Vector3:
	return muzzle_position() if _muzzle != null else global_position


func _exit_tree() -> void:


	if _slew_voice >= 0:
		Audio.loop_release(_slew_voice)
		_slew_voice = -1


func _seek_aim() -> void:
	if _anim == null:
		return


	_anim.seek(_aim_at, true)


func tilt_now() -> float:
	if _aim_length <= 0.0:
		return tilt_for(aim)
	return tilt_for(_aim_at / _aim_length)


func _tick_recoil(delta: float) -> void:
	if _recoil == null:
		return
	if _recoil_at <= 0.0:
		if _recoil.position != Vector3.ZERO:
			_recoil.position = Vector3.ZERO
		return
	_recoil_at = maxf(_recoil_at - delta / maxf(RECOIL_RETURN, 0.001), 0.0)


	_recoil.position = Vector3(0.0, 0.0, - RECOIL_BACK * _recoil_at * _recoil_at)


func _apply_lamps() -> void:
	if _lamps.is_empty():
		return
	var lit:= int(ceil(power * float(N_LAMPS)))
	for i in _lamps.size():
		var segment: Array [MeshInstance3D] = [_lamps [i]]
		HayCompressor.light_lamps(segment, LAMP_LIT if i < lit else LAMP_DARK)


func lamp_energies() -> PackedFloat32Array:
	var out:= PackedFloat32Array()
	for mesh in _lamps:
		var segment: Array [MeshInstance3D] = [mesh]
		out.append(HayCompressor.lamp_energy(segment))
	return out


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


func forward() -> Vector3:
	var d:= global_position - port_in()
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, Vector3(0.9, 1.24, -0.54)))


func build_cost() -> float:
	return Cfg.LAUNCHER_COST


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


func is_full() -> bool:
	return stored >= Cfg.LAUNCHER_BUFFER and _queue.size() >= PAD_ITEMS


func straw_room() -> int:
	return maxi(0, Cfg.LAUNCHER_BUFFER - stored)


func has_load() -> bool:
	return not _queue.is_empty() or stored >= Cfg.LAUNCHER_WAD_STRANDS


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(mains, power_blocked, power_line)
	if dead != "":
		return dead


	if not _pad_clear():
		return tr("DROP FULL  ·  clear where it is aimed, or aim it somewhere else")
	if has_load():
		return ""
	if starved_for >= Cfg.MACHINE_STARVED_AFTER:
		return tr("NO LOAD  ·  nothing is reaching the intake")
	return ""


var mains:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.LAUNCHER_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 1)
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	mains = 0.0 if switched_off else line_power


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
	return "power" if MachinePower.fault(mains, power_blocked, power_line) != "" else ""


func full_rate() -> bool:
	return true


func factory_tick(delta: float) -> void:
	_apply_aim(delta)
	_tick_recoil(delta)
	_aim_arc()


	var held:= stored + _queue.size() + pending_needles.size()
	_intake_hay()
	_sync_backpressure()


	starved_for = 0.0 if (stored + _queue.size() + pending_needles.size()) > held else starved_for + delta
	_tick_reload(delta)


func _sync_backpressure() -> void:
	if _belt == null:
		return
	var shut:= stored >= Cfg.LAUNCHER_BUFFER or _queue.size() >= PAD_ITEMS
	if _belt.is_blocked() != shut:
		_belt.set_blocked(shut)


func _aim_arc() -> void:
	if _arc == null or not _arc.visible:
		return
	_arc.aim(muzzle_position(), launch_velocity(), global_position.y)


func _eats_kind(_kind: int, strands: int) -> bool:
	return strands < 0 or _queue.size() < PAD_ITEMS


func _intake_hay() -> void:
	if _intake == null:
		return


	if _belt != null and _queue.size() < PAD_ITEMS:
		var rec:= _belt.take_record(_eats_kind, 0.0, _belt.path_length())
		if not rec.is_empty():
			var state: Variant = rec.get("state")
			var spec:= { "id": BeltRun.ITEM_IDS [int(rec ["kind"])],
				"state": (state as Dictionary).duplicate() if state is Dictionary else { } }
			if int(rec ["needle"]) >= 0:
				(spec ["state"] as Dictionary) ["needle"] = int(rec ["needle"])
			_queue.append(spec)
			Audio.play_3d("machine_thud", _mouth(), -9.0)
	for body in _intake.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var item:= rb as Carryable
		if item != null and not item.item_id.is_empty():
			if _queue.size() >= PAD_ITEMS:
				continue


			if item.is_held():
				continue


			if item.freeze and not BeltPath.is_rider(item):
				continue


			var spec:= { "id": item.item_id, "state": item.to_state() }


			if item.holds_needle():
				spec ["state"] = (spec ["state"] as Dictionary).duplicate()
				spec ["state"] ["needle"] = item.needle_index
			_queue.append(spec)
			Audio.play_3d("machine_thud", _mouth(), -9.0)
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
				Audio.play_3d("machine_feed", _mouth(), -13.0)
			continue
		if live == null or stored >= Cfg.LAUNCHER_BUFFER:
			continue


		BeltPath.release(rb)
		if live.consume(rb):
			stored += 1


			Audio.play_3d("machine_feed", _mouth(), -13.0)


func _tick_reload(delta: float) -> void:
	if props == null:
		return
	if _reload >= 0.0:


		_reload -= delta * mains
		if _reload > 0.0:
			return
		_reload = -1.0


	if mains <= 0.0:
		return
	if not has_load():
		return
	if not _pad_clear():
		return
	if _fire():
		_reload = Cfg.LAUNCHER_CYCLE_SECONDS


func _fire() -> bool:
	var spec: Dictionary = { }
	if not _queue.is_empty():


		spec = _queue.pop_front()
	elif stored >= Cfg.LAUNCHER_WAD_STRANDS:


		var take: int = mini(stored, Cfg.LAUNCHER_WAD_STRANDS)
		stored -= take
		spec = { "id": "hay_wad", "state": { "strands": take } }


		if not pending_needles.is_empty():
			(spec ["state"] as Dictionary) ["needle"] = pending_needles [0]
			pending_needles.remove_at(0)
	else:
		return false

	var from:= muzzle_position()
	var item:= props.spawn(String(spec ["id"]),
		Transform3D(_tumble_basis(), from), spec ["state"]) as Carryable
	if item == null:


		_queue.push_front(spec)
		return false


	if not pending_needles.is_empty() and not item.holds_needle() and item.hay_strands() > 0:
		item.needle_index = pending_needles [0]
		pending_needles.remove_at(0)
	var rb:= item as RigidBody3D
	if rb != null:


		rb.continuous_cd = true
		rb.linear_velocity = _scattered(launch_velocity())
		rb.angular_velocity = Vector3(
			randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
	_play_fire()


	Audio.play_3d("launcher_fire", from, -6.0)
	Audio.play_3d("machine_thud", from, -8.0)
	launched.emit(item)
	return true


func _scattered(v: Vector3) -> Vector3:
	var flat:= Vector3(v.x, 0.0, v.z)
	if flat.length_squared() < 1e-06:
		return v
	flat = flat.normalized()
	var t: float = maxf(
		LaunchArc.flight_time(muzzle_position(), v, global_position.y, true),
		MIN_DITHER_FLIGHT)


	var angle:= randf() * TAU
	var r: float = sqrt(randf()) * (Cfg.LAUNCHER_SPREAD / t)
	var side:= flat.cross(Vector3.UP)
	return v + side * (cos(angle) * r) + flat * (sin(angle) * r)


func _play_fire() -> void:
	_recoil_at = 1.0


func _tumble_basis() -> Basis:
	return Basis.from_euler(Vector3(
		randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU)))


func _mouth() -> Vector3:
	if _intake == null:
		return global_position
	return _intake.global_position


func _pad_clear() -> bool:
	if props == null or not is_inside_tree():
		return true
	if _pad_probe == null:
		_pad_probe = CylinderShape3D.new()
		_pad_probe.radius = PAD_RADIUS
		_pad_probe.height = PAD_HEIGHT
		_pad_query = PhysicsShapeQueryParameters3D.new()
		_pad_query.shape = _pad_probe
		_pad_query.collision_mask = Cfg.L_PROP
		_pad_query.collide_with_areas = false
	var at:= landing_spot()
	_pad_query.transform = Transform3D(Basis(), at + Vector3(0.0, PAD_HEIGHT * 0.5, 0.0))
	var hits:= get_world_3d().direct_space_state.intersect_shape(_pad_query, PAD_ITEMS)
	return hits.size() < PAD_ITEMS


func to_dict() -> Dictionary:
	return {
		"type": "tube_launcher",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,
		"aim": aim,
		"power": power,
		"stored": stored,


		"queue": _queue.duplicate(true),


		"needles": pending_needles,


		"port_reach": port_reach,
	}


func from_dict(d: Dictionary) -> void:


	port_reach = float(d.get("port_reach", 0.0))
	power = float(d.get("power", Cfg.LAUNCHER_POWER_DEFAULT))


	aim = float(d.get("aim", d.get("power", Cfg.LAUNCHER_AIM_DEFAULT)))
	stored = int(d.get("stored", 0))


	_aim_at = _aim_length * clampf(aim, 0.0, 1.0)
	_seek_aim()


	pending_needles = PackedInt32Array()
	for n: Variant in d.get("needles", []):
		pending_needles.append(int(n))
	_queue.clear()
	for entry: Variant in d.get("queue", []):
		var spec:= entry as Dictionary
		if spec != null and spec.has("id"):
			_queue.append({ "id": String(spec ["id"]),
				"state": spec.get("state", { }) })
