class_name HayPulper
extends Node3D


const MODEL:= "res://assets/models/hay_pulper_reference.glb"


const SPEC:= "res://assets/models/hay_pulper_reference_materials.json"

const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"


const N_FEED:= "Marker_Feed"


const N_SLAB:= "Marker_Slab"


const N_PIPE_PORT:= "Marker_PipePort"
const N_PANEL:= "Marker_Panel"


const MAT_POUR:= "M_PU_Pulp"


const MAT_SLURRY:= "M_PU_Slurry"


const BATH_FILL:= 0.86


const BED_FLOOR:= 0.04
const BED_CEIL:= 0.46


const BED_INSET:= 0.985


const BATH_CLEAR:= Color(0.19, 0.31, 0.38)
const BATH_THICK:= Color(0.36, 0.34, 0.2)
const BATH_ALPHA_CLEAR:= 0.55
const BATH_ALPHA_THICK:= 0.64


const BED_TINT:= Color(0.62, 0.5, 0.26)
const BED_ALPHA:= 0.97
const BED_WAVE_AMP:= 0.006
const BED_WAVE_SPEED:= 0.22


const POUR_FLOW:= 6.0


const N_LEVEL:= "Pulp_Level"
const N_POUR:= "Pulp_Pour"
const N_COVER:= "Pulp_Cover"
const N_GATE_PIVOT:= "Pulp_Gate_Pivot"


const WIRE_PORT_FALLBACK_A:= Vector3(0.7, 0.89, 0.85)
const WIRE_PORT_FALLBACK_B:= Vector3(-0.7, 0.89, 0.85)


const FEED_BELT_MPS:= 0.707


const FEED_BELT_SIGN:= -1.0

const CLIP_RUN:= "RunLoop"
const CLIP_DOOR:= "DoorCycle"


const CLIP_FPS:= 30.0
const CYCLE_FRAMES:= 121.0


const F_GATE_LIFT:= 16.0
const F_GATE_OPEN:= 46.0


const F_RELEASE:= 61.0


const GATE_OPEN_DEG:= -105.0


const MAT_GO:= "M_PU_LampGo"


const MAT_BELT:= "M_PU_Belt"
const GO_IDLE:= 0.45
const GO_RUNNING:= 1.9


const CHURN_DB:= -13.0
const CHURN_SILENT:= -80.0
const CHURN_RAMP:= 140.0


const CHURN_HEIGHT:= 1.3


const OUT_STUB:= 0.6


const INTAKE_LENGTH:= 1.2
const INTAKE_HEIGHT:= 0.55

const SUPPORT_HALF_WIDTH:= Cfg.BELT_SUPPORT_HALF_WIDTH


const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06
const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 16
const ARROW_SPEED:= 0.9


signal slabbed(slab: Node3D)


signal slabbed_record(seq: int)

var live: LiveStrandManager


var props: PropManager
var placement_preview:= false


var stored:= 0


var pending_needles:= PackedInt32Array()


var starved_for:= 0.0


var slabs_made:= 0


var _batch:= Cfg.PULPER_BATCH_STRANDS
var _cycle:= Cfg.PULPER_CYCLE_SECONDS

var _model: Node3D

var _anim: AnimationPlayer

var _door: AnimationPlayer
var _belt: BeltPath
var _out_belt: BeltPath
var _intake: Area3D
var _supports: Node3D
var _level: Node3D
var _pour: Node3D


var _pour_meshes: Array [MeshInstance3D] = []


var _wave_mat: ShaderMaterial
var _wave_mesh: MeshInstance3D


var _bed_mesh: MeshInstance3D
var _bed_mat: ShaderMaterial


var _bed:= 0.0
var _cover: Node3D
var _gate_pivot: Node3D

var _go_meshes: Array [MeshInstance3D] = []


var _feed_belt_mat: ShaderMaterial

var _feed_held:= false

var _drum_lamp: OmniLight3D
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D
var _flow_phase:= 0.0

var _run:= -1.0

var _released:= false


var _door_held:= false

var _churn_voice:= -1
var _churn_gain:= CHURN_SILENT
var _churn_target:= CHURN_SILENT


var _room_probe: BoxShape3D
var _room_query: PhysicsShapeQueryParameters3D


var _ports: Array [Node3D] = []

var _water_ports: Array [Node3D] = []


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	_build_instruments()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)
	_build_belts()
	_build_intake_area()
	add_to_group("hay_pulpers")
	_apply_lamp()
	_apply_charge()
	_apply_cover()
	_apply_drive_speed()


	call_deferred("refresh_supports")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayPulper: cannot load %s" % MODEL)
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
		push_warning("HayPulper: no material table at %s, the model will render untextured" % SPEC)
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
			if spec.get("palettes", { }).has(key):
				if src.get_meta("palette_entries", []) != spec ["palettes"] [key] ["entries"]:
					push_error("HayPulper palette layout changed; reimport the GLB before applying its new material table")

				continue


			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = _material_for(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
			if key == MAT_GO and not _go_meshes.has(mesh):
				_go_meshes.append(mesh)
	_feed_belt_mat = built.get(MAT_BELT, null) as ShaderMaterial
	_apply_belt_speed()
	if not missed.is_empty():
		push_warning("HayPulper: no table entry for %s" % ", ".join(missed.keys()))


func _material_for(key: String, spec: Dictionary, shader: Shader) -> Material:
	if key == MAT_BELT:
		return ConveyorKit.own_belt_material(belt_scroll())
	return HayCompressor.shared_material(MODEL, key,
		func() -> Material: return _make_surface(key, spec, shader))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var made:= HayCompressor.make_material(key, spec, shader)
	return HayCompressor.lamp_material(made) if key == MAT_GO else made


func belt_scroll() -> float:
	return FEED_BELT_SIGN * FEED_BELT_MPS * drive()


func _apply_belt_speed() -> void:
	if _feed_belt_mat != null:
		_feed_belt_mat.set_shader_parameter("speed", 0.0 if _feed_held else belt_scroll())


func _follow_feed_hold() -> void:
	var held:= _belt != null and _belt.deck_shows_held()
	if held != _feed_held:
		_feed_held = held
		_apply_belt_speed()


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


func _build_animation() -> void:
	if _model == null:
		return
	var src:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		push_warning("HayPulper: %s has no AnimationPlayer; nothing will move" % MODEL)
		return
	_anim = src


	var run_clip:= _driving_clip(_anim, CLIP_RUN)
	var door_clip:= _driving_clip(_anim, CLIP_DOOR)
	for library_name: StringName in _anim.get_animation_library_list():
		_anim.remove_animation_library(library_name)
	if run_clip != null:
		run_clip.loop_mode = Animation.LOOP_LINEAR
		var run_lib:= AnimationLibrary.new()
		run_lib.add_animation(CLIP_RUN, run_clip)
		_anim.add_animation_library("", run_lib)
		if not placement_preview:
			_anim.play(CLIP_RUN)
	else:
		push_warning("HayPulper: %s has no '%s' clip; the drum will not turn"
			% [MODEL, CLIP_RUN])

	_door = AnimationPlayer.new()
	_door.name = "DoorPlayer"
	var host:= _anim.get_parent()
	if host == null:
		host = _model
	host.add_child(_door)
	_door.root_node = _door.get_path_to(_anim.get_node(_anim.root_node))
	if door_clip == null:
		push_warning("HayPulper: %s has no '%s' clip; the gate will not swing"
			% [MODEL, CLIP_DOOR])
		return
	door_clip.loop_mode = Animation.LOOP_NONE
	var door_lib:= AnimationLibrary.new()
	door_lib.add_animation(CLIP_DOOR, door_clip)
	_door.add_animation_library("", door_lib)
	var door:= CLIP_DOOR


	_door.play(door)
	_door.seek(0.0, true)
	_door.pause()


static var _clip_cache: Dictionary = { }


static func _driving_clip(player: AnimationPlayer, want: String) -> Animation:
	if _clip_cache.has(want):
		return _clip_cache [want]
	var name:= _clip_name(player, want)
	if name == "":
		return null
	var src:= player.get_animation(name)
	if src == null:
		return null
	var out:= src.duplicate(true) as Animation
	for i in range(out.get_track_count() - 1, -1, -1):
		if out.track_get_key_count(i) < 2:
			out.remove_track(i)
	if out.get_track_count() == 0:
		out = src
	_clip_cache [want] = out
	return out


static func _clip_name(player: AnimationPlayer, want: String) -> String:
	if player == null:
		return ""
	if player.has_animation(want):
		return want
	for name in player.get_animation_list():
		if name.ends_with(want):
			return name
	return ""


func door_clip_seconds() -> float:
	if _door == null:
		return 0.0
	var name:= _clip_name(_door, CLIP_DOOR)
	if name == "":
		return 0.0
	var clip:= _door.get_animation(name)
	return 0.0 if clip == null else clip.length


func _build_instruments() -> void:
	_build_drum_lamp()


	_level = _find(N_LEVEL) as Node3D
	_pour = _find(N_POUR) as Node3D
	_cover = _find(N_COVER) as Node3D
	_gate_pivot = _find(N_GATE_PIVOT) as Node3D


	if _pour != null:
		_pour.visible = false
	_build_pour_flow()
	_build_wave_surface()
	_build_pulp_bed()


	_apply_charge()


const LAMP_AT:= Vector3(0.33, 1.0, 0.28)
const LAMP_RANGE:= 1.7
const LAMP_ENERGY:= 2.1


func _build_drum_lamp() -> void:
	if _model == null or _drum_lamp != null:
		return
	_drum_lamp = OmniLight3D.new()
	_drum_lamp.name = "DrumLamp"
	_drum_lamp.position = LAMP_AT
	_drum_lamp.omni_range = LAMP_RANGE
	_drum_lamp.light_energy = LAMP_ENERGY


	_drum_lamp.light_color = Color(1.0, 0.9, 0.74)


	_drum_lamp.shadow_enabled = "--keeplampshadows" in OS.get_cmdline_user_args()
	_drum_lamp.distance_fade_enabled = true


	_drum_lamp.distance_fade_begin = 18.0
	_drum_lamp.distance_fade_length = 6.0

	_drum_lamp.visible = not placement_preview
	_model.add_child(_drum_lamp)
	_apply_drum_lamp()


func _apply_drum_lamp() -> void:
	if _drum_lamp == null:
		return
	var lit:= not placement_preview and not switched_off and power_ports_live()
	_drum_lamp.visible = lit
	if lit:
		_drum_lamp.light_energy = LAMP_ENERGY * clampf(line_power, 0.25, 1.0)


func power_ports_live() -> bool:
	return not power_blocked and line_power > 0.001


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _build_pour_flow() -> void:
	_pour_meshes.clear()
	if _pour == null:
		return
	var pours: Array [Node] = [_pour]
	pours.append_array(_pour.find_children("*", "MeshInstance3D", true, false))
	for node in pours:
		var mesh:= node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat:= mesh.get_surface_override_material(i) as ShaderMaterial
			if mat == null or mat.resource_name != MAT_POUR:
				continue
			mesh.set_surface_override_material(i, HayCompressor.shared_material(MODEL,
				MAT_POUR + "#flowing", func() -> Material: return _flowing(mat)))
			if not _pour_meshes.has(mesh):
				_pour_meshes.append(mesh)


static func _flowing(from: ShaderMaterial) -> Material:
	var m:= ShaderMaterial.new()
	m.shader = HayCompressor.flowing_shader()
	m.resource_name = from.resource_name
	for u: Dictionary in from.shader.get_shader_uniform_list():
		var n: String = u ["name"]
		if n != "flow_uv":
			m.set_shader_parameter(n, from.get_shader_parameter(n))
	return m


func _build_wave_surface() -> void:
	_wave_mat = null
	_wave_mesh = null
	if _level == null:
		return
	var mesh:= _level as MeshInstance3D
	if mesh == null or mesh.mesh == null:
		return
	var box:= mesh.mesh.get_aabb()
	for i in mesh.mesh.get_surface_count():
		var mat:= mesh.get_surface_override_material(i) as ShaderMaterial
		if mat == null or mat.resource_name != MAT_SLURRY:
			continue
		mat.set_shader_parameter("surface_y", box.position.y + box.size.y)
		mat.set_shader_parameter("half_x", maxf(box.size.x * 0.5, 0.01))
		mat.set_shader_parameter("half_z", maxf(box.size.z * 0.5, 0.01))
		_wave_mat = mat
		_wave_mesh = mesh
		break
	_set_wave_flow()


func _build_pulp_bed() -> void:
	_bed_mesh = null
	_bed_mat = null
	var src:= _level as MeshInstance3D
	if src == null or src.mesh == null:
		return
	var bed:= MeshInstance3D.new()
	bed.name = "PulpBed"
	bed.mesh = src.mesh
	bed.transform = src.transform


	bed.scale = Vector3(src.scale.x * BED_INSET, src.scale.y,
		src.scale.z * BED_INSET)
	bed.layers = src.layers
	bed.cast_shadow = src.cast_shadow
	bed.sorting_offset = -0.35
	for i in src.mesh.get_surface_count():
		var mat:= src.get_surface_override_material(i)
		if mat == null:
			continue
		var slurry:= mat as ShaderMaterial
		if slurry != null and slurry.resource_name == MAT_SLURRY:
			_bed_mat = HayCompressor.shared_material(MODEL, MAT_SLURRY + "#bed",
				func() -> Material: return _bed_surface(slurry)) as ShaderMaterial
			bed.set_surface_override_material(i, _bed_mat)
		else:


			bed.set_surface_override_material(i, mat)
	bed.visible = false
	var host:= src.get_parent()
	if host == null:
		host = _model
	host.add_child(bed)
	_bed_mesh = bed


static func _bed_surface(slurry: ShaderMaterial) -> Material:
	var own:= slurry.duplicate() as ShaderMaterial
	own.set_shader_parameter("tint", BED_TINT)
	own.set_shader_parameter("base_alpha", BED_ALPHA)
	own.set_shader_parameter("amplitude", BED_WAVE_AMP)
	own.set_shader_parameter("wave_speed", BED_WAVE_SPEED)
	return own


func _set_wave_flow() -> void:
	var running:= clampf(drive(), 0.0, 1.0)
	if _wave_mesh != null:
		var wet:= _level != null and _level.visible
		HayCompressor.drive_instance(_wave_mesh, &"flow", running if wet else 0.0)
	if _bed_mat != null:
		var bedded:= _bed_mesh != null and _bed_mesh.visible
		HayCompressor.drive_instance(_bed_mesh, &"flow", running if bedded else 0.0)


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position) if is_inside_tree() else marker.position


func port_in() -> Vector3:
	return to_global(_marker_local(N_BELT_IN, Vector3(0, 0, - Cfg.PULPER_LENGTH * 0.5)))


func port_out() -> Vector3:
	return to_global(_marker_local(N_BELT_OUT, Vector3(0, 0, Cfg.PULPER_LENGTH * 0.5)))


func feed_point() -> Vector3:
	var local:= _marker_local(N_FEED, Vector3(0, 0, - Cfg.PULPER_LENGTH * 0.5 + 0.22))
	return to_global(Vector3(local.x, 0.0, local.z))


func deck() -> BeltPath:
	return _belt


func outfeed_deck() -> BeltPath:
	return _out_belt


func forward() -> Vector3:
	var d:= port_out() - port_in()
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, Vector3(0.92, 0.68, 1.2)))


func _build_belts() -> void:
	_belt = BeltPath.new()
	_belt.name = "InfeedStub"
	add_child(_belt)


	var runs:= belt_runs()
	_belt.build_path(runs [0], Cfg.BELT_JOINT_OVERLAP)


	_belt.set_outlet_held(true)
	_belt.set_hold_filter(func(b: Object) -> bool:
		return is_full() or _blocks_mouth(b))


	_belt.records_props = true
	_belt.hold_records(_eats_kind)

	_out_belt = BeltPath.new()
	_out_belt.name = "OutfeedStub"
	add_child(_out_belt)
	_out_belt.build_path(runs [1], Cfg.BELT_JOINT_OVERLAP)


	_out_belt.reserve_head(slab_spot(), outfeed_reserve())


	_out_belt.records_props = true


func _build_intake_area() -> void:
	_intake = Area3D.new()
	_intake.name = "IntakeMouth"
	_intake.collision_layer = 0


	_intake.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_intake.monitorable = false
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
		INTAKE_HEIGHT, INTAKE_LENGTH)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
	_intake.add_child(cs)
	add_child(_intake)


	_intake.position = to_local(feed_point() - forward() * (INTAKE_LENGTH * 0.5))


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
	_shape_flow(Cfg.PULPER_LENGTH)


func belt_runs() -> Array [PackedVector3Array]:
	var out_end:= port_out()
	return [PackedVector3Array([port_in(), feed_point()]),
		PackedVector3Array([out_end - forward() * OUT_STUB, out_end])]


func _process(delta: float) -> void:
	if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
		return
	_flow_phase += delta * ARROW_SPEED
	_shape_flow(Cfg.PULPER_LENGTH)


	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms())


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


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.PULPER_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2,
			[WIRE_PORT_FALLBACK_A, WIRE_PORT_FALLBACK_B])
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_apply_drive_speed()


func set_switched_off(off: bool) -> void:
	switched_off = off
	set_power(line_power)


func is_switched_off() -> bool:
	return switched_off


func set_power_line(line: int) -> void:
	power_line = line


func set_power_blocked(b: bool) -> void:
	power_blocked = b


	_apply_drum_lamp()


var water:= 1.0


var water_blocked:= true


func water_draw_lps() -> float:
	if switched_off:
		return 0.0
	return Cfg.PULPER_WATER_LITRES / maxf(Tech.pulper_cycle_seconds(), 0.001)


func water_ports() -> Array [Node3D]:
	if _water_ports.is_empty():
		var node:= _find(N_PIPE_PORT) as Node3D
		if node == null:
			var stand_in:= Node3D.new()
			stand_in.name = N_PIPE_PORT
			stand_in.position = Vector3(-0.98, 0.78, 0.88)
			add_child(stand_in)
			node = stand_in
		_water_ports.append(node)
	return _water_ports


func water_port() -> Vector3:
	var ports:= water_ports()
	return global_position if ports.is_empty() else ports [0].global_position


func set_water(f: float) -> void:
	water = clampf(f, 0.0, 1.0)
	_apply_drive_speed()


func set_water_blocked(b: bool) -> void:
	water_blocked = b
	_apply_cover()


var water_pumpless:= false


func set_water_pumpless(b: bool) -> void:
	water_pumpless = b


func drive() -> float:
	return minf(power, water)


func buffer_capacity() -> int:
	return Tech.pulper_buffer()


func is_full() -> bool:
	return stored >= buffer_capacity()


func straw_room() -> int:
	return maxi(0, buffer_capacity() - stored)


func is_running() -> bool:
	return _run >= 0.0


func held_needles() -> PackedInt32Array:
	return pending_needles


func batch_progress() -> float:
	if _run < 0.0:
		return 0.0
	return clampf(_run / _cycle, 0.0, 1.0)


func alert_icon() -> String:
	if placement_preview or switched_off:
		return ""
	if MachinePower.fault(power, power_blocked, power_line) != "":
		return "power"
	return "water" if _water_fault() != "" else ""


func _water_fault() -> String:
	if water > 0.0:
		return ""
	if water_blocked:
		return tr("NO WATER  ·  run a water pipe onto its flange")
	if water_pumpless:
		return tr("NO WATER  ·  no pump is on this pipe, build a borehole pump on it")
	return tr("NO WATER  ·  the main it is on is empty, check the pump")


func alert_reason() -> String:
	if placement_preview:
		return ""

	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead


	var dry:= _water_fault()
	if dry != "":
		return dry
	if _run >= 0.0:


		if not _released and _run >= _release_at():
			return tr("OUTFEED BLOCKED  ·  move the slab off the deck")


	var stuck:= _jammed_load()
	if stuck != "":
		return tr("WRONG LOAD  ·  take the %s out of the intake") % stuck
	if _run >= 0.0:
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


func factory_tick(delta: float) -> void:
	var held:= stored
	_intake_hay()
	starved_for = 0.0 if stored > held else starved_for + delta
	_tick_batch(delta)
	_sync_backpressure()
	_follow_feed_hold()
	_tick_churn_loop(delta)


func is_waiting() -> bool:
	if _run >= 0.0 or not pending_needles.is_empty() or (_intake != null and _intake.has_overlapping_bodies()):
		_idle_memo.clear()
		return false
	var key:= [stored, Tech.pulper_batch_strands(), drive(), _released,
		_door_held, _feed_held, _churn_voice, _churn_gain, _churn_target,
		is_full(), power, power_blocked, switched_off, line_power, water,
		water_blocked]
	return FactoryClock.idle_router([_belt], key, _idle_memo)


var _idle_memo: Array = []


func _eats(body: Object) -> bool:
	var rb:= body as RigidBody3D
	if rb == null:
		return false


	if rb is HayWad:
		return true


	return bool(rb.collision_layer & Cfg.L_STRAND)


func _eats_kind(kind: int, _strands: int) -> bool:
	return kind == BeltRun.Kind.WAD


func _blocks_mouth(body: Object) -> bool:
	var rb:= body as RigidBody3D
	return rb != null and bool(rb.collision_layer & Cfg.L_PROP) and not _eats(rb)


func _intake_hay() -> void:
	if live == null or _intake == null:
		return


	if _belt != null and not is_full():
		var m:= _belt.s_at(_mouth())
		var rec:= _belt.take_record(Callable(), m - INTAKE_LENGTH * 0.5, m + INTAKE_LENGTH * 0.5)
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


func _tick_batch(delta: float) -> void:
	var drive_now:= drive()
	if _run < 0.0:


		if drive_now <= 0.0:
			return
		if stored >= Tech.pulper_batch_strands():
			_start_batch()
		return


	_run += delta * drive_now


	_tick_bed(delta)
	_apply_charge()
	_apply_pour()
	if not _released and _run >= _release_at():
		_release_slab()
	if _run >= _cycle:
		_finish_batch()
	_hold_door(not _released and _run >= _release_at())


func _release_at() -> float:
	return _cycle * (F_RELEASE / CYCLE_FRAMES)


func _start_batch() -> void:


	_batch = Tech.pulper_batch_strands()
	_cycle = Tech.pulper_cycle_seconds()
	stored -= _batch
	_run = 0.0
	_released = false
	slabs_made += 1
	_apply_drive_speed()
	if _door != null:
		var name:= _clip_name(_door, CLIP_DOOR)
		if name != "":
			_door.play(name)
			_door.seek(0.0, true)
	if _churn_voice < 0:


		_churn_voice = Audio.loop_acquire("pulper_churn")
		_churn_gain = CHURN_SILENT
	_churn_target = CHURN_DB

	Audio.play_3d("machine_clunk", _emitter(), -9.0)
	_apply_lamp()
	_apply_charge()


func _finish_batch() -> void:


	if not _released:
		_run = _release_at()
		_release_slab()
		return
	_run = -1.0
	_churn_target = CHURN_SILENT
	_apply_lamp()
	_apply_charge()
	_apply_pour()


func slab_spot() -> Vector3:
	return to_global(_marker_local(N_SLAB, Vector3(0, 0, Cfg.PULPER_LENGTH * 0.5 - 0.22)))


func outfeed_reserve() -> float:
	return Cfg.PULPER_SLAB_CLEAR * 0.5


func _release_slab() -> void:
	if props == null:


		push_warning("HayPulper: no PropManager; the slab cannot be created")
		_released = true
		_apply_pour()
		return
	var at:= slab_spot()
	if not _slab_room(at):
		return


	if _out_belt != null and _out_belt.records_props:
		var needle:= pending_needles [0] if not pending_needles.is_empty() else -1
		var state:= { "strands": _batch }
		if needle >= 0:
			state ["needle"] = needle
		var seq:= _out_belt.push_record(BeltRun.Kind.PULP, _batch, needle, state, at)
		if seq < 0:
			return
		if needle >= 0:
			pending_needles.remove_at(0)
		_released = true
		_apply_pour()
		Audio.play_3d("machine_vent", at, -7.0)
		Audio.play_3d_delayed("machine_thud", at, 0.12, -5.0)
		slabbed_record.emit(seq)
		return


	var slab:= props.spawn("hay_pulp", Transform3D(global_basis,
		at + Vector3.UP * (Cfg.PULPER_SLAB_SIZE.y * 0.06))) as HayPulp
	if slab == null:
		_released = true
		_apply_pour()
		return
	slab.strands = _batch


	if not pending_needles.is_empty():
		slab.needle_index = pending_needles [0]
		pending_needles.remove_at(0)
	_released = true


	_apply_pour()


	Audio.play_3d("machine_vent", at, -7.0)
	Audio.play_3d_delayed("machine_thud", at, 0.12, -5.0)
	slabbed.emit(slab)


func _slab_room(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	if _room_probe == null:
		_room_probe = BoxShape3D.new()
		_room_probe.size = Vector3(Cfg.PULPER_SLAB_SIZE.x,
			Cfg.PULPER_SLAB_SIZE.y, Cfg.PULPER_SLAB_CLEAR)
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = _room_probe
		_room_query.collision_mask = Cfg.L_PROP
		_room_query.collide_with_areas = false
	_room_query.transform = Transform3D(global_basis,
		at + Vector3.UP * Cfg.PULPER_SLAB_SIZE.y * 0.5)
	return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


func _sync_backpressure() -> void:
	if _belt == null:
		return
	var full:= is_full()
	if _belt.is_blocked() != full:
		_belt.set_blocked(full)


func _apply_drive_speed() -> void:
	var f:= drive()
	if _anim != null:
		_anim.speed_scale = f
	if _door != null and _cycle > 0.0:
		_door.speed_scale = f * Cfg.PULPER_CYCLE_SECONDS / maxf(_cycle, 0.001)
	_apply_belt_speed()
	_apply_drum_lamp()


	_apply_charge()


func _hold_door(held: bool) -> void:
	if _door == null:
		return
	if not held:


		_door_held = false
		return
	var name:= _clip_name(_door, CLIP_DOOR)
	if name == "":
		return
	if not _door.is_playing():
		_door.play(name)
	_door.seek(door_clip_seconds() * (F_RELEASE / CYCLE_FRAMES), true)
	_door_held = true


func has_liquor() -> bool:
	return not placement_preview and water > 0.001


func charge_fraction() -> float:
	return _bed


func _tick_bed(delta: float) -> void:
	var f:= drive()
	if _run < 0.0 or _cycle <= 0.0 or f <= 0.0:
		return
	var pour_span:= maxf(_release_at() - _cycle * (F_GATE_LIFT / CYCLE_FRAMES), 0.001)
	if _pouring():
		_bed = move_toward(_bed, 0.0, delta * f / pour_span)
	else:
		_bed = move_toward(_bed, 1.0, delta * f / maxf(_cycle - pour_span, 0.001))


func _pouring() -> bool:
	if _run < 0.0 or _released or _cycle <= 0.0:
		return false
	return _run >= _cycle * (F_GATE_LIFT / CYCLE_FRAMES)


func _apply_charge() -> void:
	var f:= charge_fraction()
	if _level != null:


		_level.visible = has_liquor()
		if _wave_mesh != null:
			HayCompressor.drive_instance(_wave_mesh, &"fill", BATH_FILL)


			var liquor:= BATH_CLEAR.lerp(BATH_THICK, f)
			liquor.a = lerpf(BATH_ALPHA_CLEAR, BATH_ALPHA_THICK, f)
			HayCompressor.drive_instance(_wave_mesh, &"liquor", liquor)
	if _bed_mesh != null:
		_bed_mesh.visible = has_liquor() and f > 0.001
		if _bed_mat != null:
			HayCompressor.drive_instance(_bed_mesh, &"fill", lerpf(BED_FLOOR, BED_CEIL, f))


	_set_wave_flow()


func _apply_pour() -> void:
	if _pour == null:
		return
	_pour.visible = _pouring()
	_set_pour_flow(drive() if _pour.visible else 0.0)


func _set_pour_flow(f: float) -> void:


	var uv:= Vector2(0.0, - POUR_FLOW * clampf(f, 0.0, 1.0))
	for mesh in _pour_meshes:
		HayCompressor.drive_instance(mesh, &"flow_uv", uv)


func pour_flow_uv() -> Vector2:
	if _pour_meshes.is_empty():
		return Vector2.ZERO
	return HayCompressor.driven(_pour_meshes [0], &"flow_uv", Vector2.ZERO)


func wave_fill() -> float:
	return float(HayCompressor.driven(_wave_mesh, &"fill", 1.0))


func wave_flow() -> float:
	return float(HayCompressor.driven(_wave_mesh, &"flow", 0.0))


func _apply_cover() -> void:
	if _cover != null:
		_cover.visible = water_blocked


func _apply_lamp() -> void:
	HayCompressor.light_lamps(_go_meshes, GO_RUNNING if is_running() else GO_IDLE)


func go_energy() -> float:
	return HayCompressor.lamp_energy(_go_meshes)


func gate_angle_deg() -> float:
	if _gate_pivot == null:
		return 0.0
	return rad_to_deg(_gate_pivot.rotation.x)


func _emitter() -> Vector3:
	return global_position + Vector3(0, CHURN_HEIGHT, 0)


func _tick_churn_loop(delta: float) -> void:
	if _churn_voice < 0:
		return
	_churn_gain = move_toward(_churn_gain, _churn_target, CHURN_RAMP * delta)
	if _churn_target <= CHURN_SILENT and _churn_gain <= CHURN_SILENT + 0.5:
		_release_churn_loop()
		return
	Audio.loop_update(_churn_voice, _emitter(), _churn_gain,
		MachinePower.loop_pitch(drive()))


func _release_churn_loop() -> void:
	if _churn_voice < 0:
		return
	Audio.loop_release(_churn_voice)
	_churn_voice = -1
	_churn_gain = CHURN_SILENT
	_churn_target = CHURN_SILENT


func _exit_tree() -> void:
	_release_churn_loop()


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.PULPER_COST


func to_dict() -> Dictionary:
	return {
		"type": "hay_pulper",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"stored": stored,

		"needles": pending_needles,
	}
