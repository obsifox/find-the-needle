class_name HayWrapper
extends Node3D


const MODEL:= "res://assets/models/compiled/hay_wrapper.scn"


const SPEC:= "res://assets/models/hay_wrapper_materials.json"


const SHADER:= "res://assets/stand_surface.gdshader"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"
const TEX_MAPS:= {
	"albedo": "diff", "normal": "nor_gl", "rough": "rough", "ao": "ao",
}


const N_CLIP_BALE:= "Wrapper_Bale"

const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"
const N_BALE_OUT:= "Marker_BaleOut"
const N_PANEL:= "Marker_Panel"

const CLIP:= "Cycle"


const CYCLE_FRAMES:= 126.0
const CLIP_FPS:= 24.0


const F_RELEASE:= 120.0


const MAT_GO:= "M_HW_LampGo"
const GO_IDLE:= 0.45
const GO_RUNNING:= 1.6


const CLIP_PROPS:= ["Wrapper_Bale", "Wrapper_Foiled", "Wrapper_Film",
	"Wrapper_Web0", "Wrapper_Web1"]


const INTAKE_LENGTH:= Cfg.WRAPPER_LENGTH * 0.5


const INTAKE_HEIGHT:= 0.6

const SUPPORT_HALF_WIDTH:= Cfg.BELT_SUPPORT_HALF_WIDTH


const LEG_MARKERS:= ["Marker_Leg00", "Marker_Leg01", "Marker_Leg10", "Marker_Leg11"]


const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06
const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 12
const ARROW_SPEED:= 0.9


const RING_LOOP_DB:= -14.0
const RING_LOOP_SILENT:= -80.0
const RING_LOOP_RAMP:= 140.0
const RING_LOOP_HEIGHT:= 0.9


signal wrapped(product: FoiledBale)


signal wrapped_record(seq: int)


var props: PropManager
var placement_preview:= false


var queued: Array [int] = []


var queued_needles: Array [int] = []


var pending_needles:= PackedInt32Array()


var starved_for:= 0.0


var _batch:= Cfg.COMPRESSOR_BALE_STRANDS


var _batch_needle:= -1


func held_needles() -> PackedInt32Array:
	var out:= PackedInt32Array()
	for index in queued_needles:
		if index >= 0:
			out.append(index)
	if _batch_needle >= 0:
		out.append(_batch_needle)
	out.append_array(pending_needles)
	return out


var _model: Node3D
var _anim: AnimationPlayer


var _clip_bale: Node3D

var _ports: Array [Node3D] = []
var _belt: BeltPath
var _intake: Area3D
var _supports: Node3D
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D
var _flow_phase:= 0.0

var _go_meshes: Array [MeshInstance3D] = []


var _wrap:= -1.0


var _rate:= 1.0

var _released:= false


var _room_probe: BoxShape3D
var _room_query: PhysicsShapeQueryParameters3D

var _ring_voice:= -1
var _ring_gain:= RING_LOOP_SILENT
var _ring_target:= RING_LOOP_SILENT


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)
	_build_belt()
	_build_intake_area()
	add_to_group("hay_wrappers")
	_apply_lamp()


	call_deferred("refresh_supports")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayWrapper: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0

	if placement_preview:
		for node_name: String in CLIP_PROPS:
			var shipped:= _find(node_name) as Node3D
			if shipped != null:
				shipped.visible = false
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("HayWrapper: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
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
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return _make_surface(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key == MAT_GO and not _go_meshes.has(mesh):
				_go_meshes.append(mesh)
	if not missed.is_empty():
		push_warning("HayWrapper: no table entry for %s" % ", ".join(missed.keys()))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= make_material(key, spec, shader)
	return HayCompressor.lamp_material(made) if key == MAT_GO else made


static var _spec_cache: Dictionary = { }


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


static func make_material(key: String, spec: Dictionary, shader: Shader) -> Material:
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
		if f.get("linear_color", false):
			colour = colour.linear_to_srgb()
		var alpha:= float(f.get("alpha", 1.0))
		sm.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
		sm.roughness = float(f.get("rough", 0.6))
		sm.metallic = float(f.get("metal", 0.0))
		sm.metallic_specular = 0.4
		if f.has("coat"):
			sm.clearcoat_enabled = true
			sm.clearcoat = float(f ["coat"])
			sm.clearcoat_roughness = 0.18
		if f.has("normal"):
			sm.normal_enabled = true
			sm.normal_texture = load(f ["normal"])
		var emit:= float(f.get("emit", 0.0))
		if emit > 0.0:
			sm.emission_enabled = true
			sm.emission = colour
			sm.emission_energy_multiplier = emit
		if alpha < 1.0:

			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if f.get("double_sided", true):
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		return sm
	return null


static func _col(a: Variant) -> Color:
	var arr: Array = a
	if arr.size() < 3:
		return Color.WHITE
	return Color(float(arr [0]), float(arr [1]), float(arr [2]))


func _build_animation() -> void:
	if _model == null:
		return
	var src:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		push_warning("HayWrapper: %s has no AnimationPlayer; the ring will not turn" % MODEL)
		return
	_anim = src
	var clip:= _find_clip()
	if clip == null:
		push_warning("HayWrapper: %s has no '%s' clip" % [MODEL, CLIP])
		return
	clip.loop_mode = Animation.LOOP_NONE


	_anim.play(_clip_name())
	_anim.seek(0.0, true)
	_anim.pause()
	_show_clip_bale(false)


const SHOT_FRAME:= 66.0


func pose_for_shot(frame: float = SHOT_FRAME) -> void:
	if _anim == null or _clip_name() == "":
		return
	_show_clip_bale(true)
	_anim.play(_clip_name())
	_anim.seek(frame / CLIP_FPS, true)
	_anim.pause()


	HayCompressor.light_lamps(_go_meshes, GO_RUNNING)


func _show_clip_bale(on: bool) -> void:
	if _clip_bale == null:
		_clip_bale = _find(N_CLIP_BALE) as Node3D
	if _clip_bale != null:
		_clip_bale.visible = on


func _find_clip() -> Animation:
	if _anim == null:
		return null
	var clip_name:= _clip_name()
	return _anim.get_animation(clip_name) if clip_name != "" else null


func _clip_name() -> String:
	if _anim == null:
		return ""
	for candidate: String in [CLIP, "global/" + CLIP, "" + CLIP]:
		if _anim.has_animation(candidate):
			return candidate
	var list:= _anim.get_animation_list()
	if list.size() > 0:
		return list [0]
	return ""


func port_in() -> Vector3:
	return to_global(_marker_local(N_BELT_IN, Vector3(0, 0, - Cfg.WRAPPER_LENGTH * 0.5)))


func port_out() -> Vector3:
	return to_global(_marker_local(N_BELT_OUT, Vector3(0, 0, Cfg.WRAPPER_LENGTH * 0.5)))


func deck() -> BeltPath:
	return _belt


func forward() -> Vector3:
	var d:= port_out() - port_in()
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, Vector3(0.99, 0.52, 0.5)))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


static func belt_windows() -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for side in [-1, 1]:
		out.append({ "side": side, "from": 0.2, "to": Cfg.WRAPPER_LENGTH - 0.2 })
	return out


func _build_belt() -> void:
	_belt = BeltPath.new()
	_belt.name = "ModuleBelt"
	add_child(_belt)
	_belt.open_windows.assign(belt_windows())


	_belt.build_path(belt_runs() [0], Cfg.BELT_JOINT_OVERLAP)


	_belt.set_hold_back(Cfg.WRAPPER_LENGTH - INTAKE_LENGTH * 0.5)


	_belt.set_hold_filter(func(b: Object) -> bool: return b is HayBale)


	_belt.records_props = true
	_belt.hold_records(_eats)


func _eats(kind: int, _strands: int) -> bool:
	return kind == BeltRun.Kind.BALE


func _outfeed() -> BeltPath:
	if _belt == null:
		return null
	var out:= _belt.downstream
	if out == null or not is_instance_valid(out) or not out.records_props:
		return null
	return out


func _build_intake_area() -> void:
	_intake = Area3D.new()
	_intake.name = "IntakeMouth"
	_intake.collision_layer = 0


	_intake.collision_mask = Cfg.L_PROP
	_intake.monitorable = false
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
		INTAKE_HEIGHT, INTAKE_LENGTH)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
	_intake.add_child(cs)
	add_child(_intake)
	_intake.position = to_local(port_in() + forward() * (INTAKE_LENGTH * 0.5))


	_intake.position.y = 0.0


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
	_shape_flow(Cfg.WRAPPER_LENGTH)


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([port_in(), port_out()])]


func _process(delta: float) -> void:
	if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
		return
	_flow_phase += delta * ARROW_SPEED
	_shape_flow(Cfg.WRAPPER_LENGTH)


	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms(),
		[belt_windows()])


func _shape_flow(length: float) -> void:
	var mm:= _ghost_flow.multimesh
	if length < 0.0001:
		mm.visible_instance_count = 0
		return


	var n:= clampi(maxi(1, int(round(length / ARROW_PITCH))), 1, ARROW_CAPACITY)
	var pitch:= length / n
	var phase:= fmod(_flow_phase, pitch)
	for i in n:
		var along:= fmod(i * pitch + phase, length)
		mm.set_instance_transform(i, Transform3D(Basis(),
			Vector3(0.0, ARROW_LIFT, - length * 0.5 + along)))
		var fade:= (clampf(along / ARROW_FADE, 0.0, 1.0)
			* clampf((length - along) / ARROW_FADE, 0.0, 1.0))
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, fade))
	mm.visible_instance_count = n


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


func support_tops() -> Array [Vector3]:
	var yaw:= global_basis
	var tops: Array [Vector3] = []
	for port: Vector3 in [port_in(), port_out()]:
		var centre_top:= port - Vector3.UP * Cfg.BELT_SUPPORT_ATTACH_DEPTH
		for side: float in [-1.0, 1.0]:
			tops.append(centre_top + yaw.x * (side * SUPPORT_HALF_WIDTH))
	for socket: String in LEG_MARKERS:
		var marker:= _find(socket) as Node3D
		if marker == null:


			push_warning("HayWrapper: %s has no %s; the gantry has no leg there"
				% [MODEL, socket])
			continue
		tops.append(marker.global_position)
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


func buffer_capacity() -> int:
	return Cfg.WRAPPER_BUFFER


func is_full() -> bool:
	return queued.size() >= buffer_capacity()


func is_wrapping() -> bool:
	return _wrap >= 0.0


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead
	if _wrap >= 0.0:


		if not _released and _wrap >= _release_at():
			return tr("OUTFEED BLOCKED  ·  move the wrapped bale off the deck")
		return ""
	if starved_for >= Cfg.MACHINE_STARVED_AFTER:
		return tr("NO BALES  ·  nothing is reaching the intake")
	return ""


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.WRAPPER_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2)
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_apply_wrap_speed()


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


func _apply_wrap_speed() -> void:
	if _anim != null:
		_anim.speed_scale = power * _rate


func wrap_progress() -> float:
	if _wrap < 0.0:
		return 0.0
	return clampf(_wrap / Cfg.WRAPPER_SECONDS, 0.0, 1.0)


func factory_tick(delta: float) -> void:
	var held:= queued.size()
	_intake_bales()


	starved_for = 0.0 if queued.size() > held else starved_for + delta
	_tick_wrap(delta)
	_sync_backpressure()
	_tick_ring_loop(delta)


func _intake_bales() -> void:
	if _intake == null:
		return


	if _belt != null and not is_full():
		var m:= _belt.s_at(_mouth())
		var rec:= _belt.take_record(Callable(), m - INTAKE_LENGTH * 0.5, m + INTAKE_LENGTH * 0.5)
		if not rec.is_empty():
			queued.append(int(rec ["strands"]))
			queued_needles.append(int(rec ["needle"]))
			Audio.play_3d("machine_thud", _mouth(), -9.0)
	for body in _intake.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		if rb is FoiledBale:
			continue
		var bale:= rb as HayBale
		if bale == null:
			continue
		if is_full():
			continue


		if bale.freeze and not BeltPath.is_rider(bale):
			continue


		BeltPath.release(bale)
		queued.append(bale.strands)


		queued_needles.append(bale.needle_index)


		Audio.play_3d("machine_thud", _mouth(), -9.0)
		if props != null:
			props.remove(bale)
		else:
			bale.queue_free()


func _mouth() -> Vector3:
	if _intake == null:
		return global_position
	return _intake.global_position


func _tick_wrap(delta: float) -> void:
	if _wrap < 0.0:


		if power <= 0.0:
			return
		if not queued.is_empty():
			_start_wrap()
		return


	_wrap += delta * power * _rate
	if not _released and _wrap >= _release_at():
		_release_product()
	if _wrap >= Cfg.WRAPPER_SECONDS:
		_finish_wrap()


func _release_at() -> float:
	return Cfg.WRAPPER_SECONDS * (F_RELEASE / CYCLE_FRAMES)


func _start_wrap() -> void:


	_batch = queued.pop_front()
	_batch_needle = queued_needles.pop_front() if not queued_needles.is_empty() else -1
	_wrap = 0.0
	_rate = Tech.wrapper_speed()
	_released = false
	_show_clip_bale(true)
	if _anim != null and _clip_name() != "":
		_apply_wrap_speed()
		_anim.play(_clip_name())
		_anim.seek(0.0, true)
	if _ring_voice < 0:
		_ring_voice = Audio.loop_acquire("motor_a")
		_ring_gain = RING_LOOP_SILENT
	_ring_target = RING_LOOP_DB


	Audio.play_3d("machine_clunk", _emitter(), -10.0)
	_apply_lamp()


func _finish_wrap() -> void:


	if not _released:
		_wrap = _release_at()
		_release_product()
		return
	_wrap = -1.0


	_batch_needle = -1
	_ring_target = RING_LOOP_SILENT
	if _anim != null:
		_anim.pause()


	_show_clip_bale(false)
	_apply_lamp()


func product_spot() -> Vector3:
	return to_global(_marker_local(N_BALE_OUT, Vector3(0, 0, 0.98)))


func outfeed_reserve() -> float:
	return Cfg.WRAPPER_PRODUCT_CLEAR * 0.5


func _release_product() -> void:
	if props == null:


		push_warning("HayWrapper: no PropManager; the foiled bale cannot be created")
		_released = true


		_orphan_batch_needle()
		return
	var at:= product_spot()
	if not _product_room(at):
		return


	var out:= _outfeed()
	if out != null:
		var needle:= _batch_needle
		var from_pending:= needle < 0 and not pending_needles.is_empty()
		if from_pending:
			needle = pending_needles [0]
		var state:= { "strands": _batch }
		if needle >= 0:
			state ["needle"] = needle
		var seq:= out.push_record(BeltRun.Kind.FOILED_BALE, _batch, needle, state, at)
		if seq < 0:
			return
		if from_pending:
			pending_needles.remove_at(0)
		_batch_needle = -1
		_released = true
		Audio.play_3d("plastic_drop", at, -9.0)
		Audio.play_3d_delayed("machine_vent", at, 0.1, -8.0)
		Audio.play_3d_delayed("machine_thud", at, 0.22, -5.0)
		wrapped_record.emit(seq)
		return
	var b:= global_basis
	var product:= props.spawn("foiled_bale",
		Transform3D(b, at + Vector3.UP * (Cfg.WRAPPER_FOILED_SIZE.y * 0.06))) as FoiledBale
	if product == null:
		_released = true


		_orphan_batch_needle()
		return


	product.strands = _batch


	if _batch_needle < 0 and not pending_needles.is_empty():
		_batch_needle = pending_needles [0]
		pending_needles.remove_at(0)
	product.needle_index = _batch_needle


	_batch_needle = -1
	_released = true


	Audio.play_3d("plastic_drop", at, -9.0)
	Audio.play_3d_delayed("machine_vent", at, 0.1, -8.0)
	Audio.play_3d_delayed("machine_thud", at, 0.22, -5.0)
	wrapped.emit(product)


func _orphan_batch_needle() -> void:
	if _batch_needle < 0:
		return
	pending_needles.append(_batch_needle)
	_batch_needle = -1


func _product_room(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	if _room_probe == null:
		_room_probe = BoxShape3D.new()
		_room_probe.size = Vector3(Cfg.WRAPPER_FOILED_SIZE.x,
			Cfg.WRAPPER_FOILED_SIZE.y, Cfg.WRAPPER_PRODUCT_CLEAR)
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = _room_probe
		_room_query.collision_mask = Cfg.L_PROP
		_room_query.collide_with_areas = false
	_room_query.transform = Transform3D(global_basis,
		at + Vector3.UP * Cfg.WRAPPER_FOILED_SIZE.y * 0.5)
	return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


func _sync_backpressure() -> void:
	if _belt == null:
		return
	var full:= is_full()
	if _belt.is_blocked() != full:
		_belt.set_blocked(full)


	_belt.set_outlet_held(full)


func _apply_lamp() -> void:
	HayCompressor.light_lamps(_go_meshes, GO_RUNNING if is_wrapping() else GO_IDLE)


func go_energy() -> float:
	return HayCompressor.lamp_energy(_go_meshes)


func _emitter() -> Vector3:
	return global_position + Vector3(0, RING_LOOP_HEIGHT, 0)


func _tick_ring_loop(delta: float) -> void:
	if _ring_voice < 0:
		return
	_ring_gain = move_toward(_ring_gain, _ring_target, RING_LOOP_RAMP * delta)
	if _ring_target <= RING_LOOP_SILENT and _ring_gain <= RING_LOOP_SILENT + 0.5:
		_release_ring_loop()
		return

	Audio.loop_update(_ring_voice, _emitter(), _ring_gain,
		MachinePower.loop_pitch(power))


func _release_ring_loop() -> void:
	if _ring_voice < 0:
		return
	Audio.loop_release(_ring_voice)
	_ring_voice = -1
	_ring_gain = RING_LOOP_SILENT
	_ring_target = RING_LOOP_SILENT


func _exit_tree() -> void:
	_release_ring_loop()


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.WRAPPER_COST


func to_dict() -> Dictionary:
	return {
		"type": "hay_wrapper",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"queued": queued.duplicate(),


		"queued_needles": queued_needles.duplicate(),


		"wrapping_needle": _batch_needle,
		"pending_needles": pending_needles,
	}


func from_dict(d: Dictionary) -> void:
	queued.clear()
	for n: Variant in d.get("queued", []):
		queued.append(int(n))
	queued_needles.clear()
	for n: Variant in d.get("queued_needles", []):
		queued_needles.append(int(n))


	while queued_needles.size() < queued.size():
		queued_needles.append(-1)


	while queued.size() > buffer_capacity():
		queued.pop_back()
	while queued_needles.size() > queued.size():
		queued_needles.pop_back()
	pending_needles = PackedInt32Array()
	for n: Variant in d.get("pending_needles", []):
		pending_needles.append(int(n))


	var wrapping:= int(d.get("wrapping_needle", -1))
	if wrapping >= 0:
		pending_needles.append(wrapping)
