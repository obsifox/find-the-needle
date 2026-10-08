class_name PaperMachine
extends Node3D


const MODEL:= "res://assets/models/paper_machine.glb"


const SPEC:= "res://assets/models/paper_machine_materials.json"


const SHADER:= "res://assets/stand_surface.gdshader"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"
const TEX_MAPS:= {
	"albedo": "diff",
	"normal": "nor_gl",
	"rough": "rough",
}

const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"


const N_FEED:= "Marker_Feed"


const N_RELEASE:= "Marker_Release"
const N_PANEL:= "Marker_Panel"


const N_CLIP_PULP:= "Press_pulp"
const N_CLIP_ROLL:= "Wound_roll"

const CLIP:= "ProductionCycle"


const CYCLE_FRAMES:= 331.0
const CLIP_FPS:= 30.0


const F_RELEASE:= 280.0


const OUT_STUB:= 1.0


const OUT_INSET:= 0.5


const PORT_REACH:= 0.5


const INTAKE_LENGTH:= 1.2
const INTAKE_HEIGHT:= 0.6

const SUPPORT_HALF_WIDTH:= Cfg.BELT_SUPPORT_HALF_WIDTH


const MAT_BELT:= "M_PM_Belt"


const FEED_DRUM_RADIUS:= 0.076
const FEED_DRUM_TURNS:= 6.0
const FEED_BELT_MPS:= FEED_DRUM_TURNS / 4.0 * TAU * FEED_DRUM_RADIUS


const PRESS_BED_ABOVE_DECK:= 0.5825


const FEED_BELT_SIGN:= -1.0


const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06
const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 16
const ARROW_SPEED:= 0.9


const DRYER_LOOP:= "motor_a"
const DRYER_LOOP_DB:= -15.0
const DRYER_LOOP_SILENT:= -80.0
const DRYER_LOOP_RAMP:= 140.0
const DRYER_LOOP_HEIGHT:= 1.2


signal rolled(roll: Node3D)


signal rolled_record(seq: int)


var props: PropManager


var live: LiveStrandManager
var placement_preview:= false


var queued: Array [int] = []


var queued_needles: Array [int] = []


var pending_needles:= PackedInt32Array()


var port_reach:= PORT_REACH

var starved_for:= 0.0


var arrival_gap:= -1.0
var _seen_arrival:= false


var _batch:= Cfg.PULPER_BATCH_STRANDS
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


var _body: StaticBody3D
var _anim: AnimationPlayer
var _clip_pulp: Node3D
var _clip_roll: Node3D


var _feed_belt_mat: ShaderMaterial

var _feed_held:= false
var _ports: Array [Node3D] = []
var _belt: BeltPath
var _out_belt: BeltPath
var _intake: Area3D
var _supports: Node3D
var _drums: Node3D
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D
var _flow_phase:= 0.0


var _run:= -1.0
var _released:= false

var _room_probe: BoxShape3D
var _room_query: PhysicsShapeQueryParameters3D

var _dryer_voice:= -1
var _dryer_gain:= DRYER_LOOP_SILENT
var _dryer_target:= DRYER_LOOP_SILENT


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_build_collider()
	_skin()
	_build_animation()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)
	_build_belts()
	_refresh_drums()
	_build_intake_area()
	add_to_group("paper_machines")


	call_deferred("refresh_supports")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("PaperMachine: cannot load %s" % MODEL)
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
	_show_clip_props(false)


func _build_collider() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	_body.collision_mask = 0
	add_child(_body)
	for spec: Array in [


			[Vector3(1.52, 0.74, 0.78), Vector3(0.0, 0.37, -2.53)],


			[Vector3(1.72, 2.16, 0.86), Vector3(0.09, 1.08, -2.02)],

			[Vector3(0.44, 1.0, 0.8), Vector3(0.94, 0.5, -2.4)],

			[Vector3(2.04, 1.72, 2.46), Vector3(0.02, 0.86, -0.37)],


			[Vector3(0.42, 1.2, 1.0), Vector3(1.06, 0.75, 0.1)],


			[Vector3(0.36, 0.8, 0.86), Vector3(0.0, 1.75, 0.0)],


			[Vector3(2.1, 0.98, 1.6), Vector3(0.17, 0.49, 1.66)]]:
		var box:= BoxShape3D.new()
		box.size = spec [0]
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.position = spec [1]
		_body.add_child(cs)


func _skin() -> void:
	if _model == null:
		return
	_feed_belt_mat = ConveyorKit.own_belt_material(belt_scroll())
	var found:= false
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			if src.resource_name.begins_with("M_HP_"):
				var pulp:= _pulp_mat(src.resource_name)
				if pulp != null:
					mesh.set_surface_override_material(i, pulp)
				continue
			if src.resource_name != MAT_BELT:
				continue
			mesh.set_surface_override_material(i, _feed_belt_mat)
			found = true
	if not found:
		push_warning("PaperMachine: %s has no '%s' surface; the intake belt will not scroll"
			% [MODEL, MAT_BELT])
	_apply_belt_speed()


static var _pulp_mats: Dictionary = { }


static func _pulp_mat(key: String) -> Material:
	if _pulp_mats.has(key):
		return _pulp_mats [key]
	var mat: Material = null
	var spec:= HayPulp.spec_table()
	var shader: Shader = load(HayCompressor.SHADER)
	if not spec.is_empty() and shader != null:
		mat = HayCompressor.make_material(key, spec, shader)
	_pulp_mats [key] = mat
	return mat


func belt_scroll() -> float:
	return FEED_BELT_SIGN * FEED_BELT_MPS * power


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
		push_warning("PaperMachine: %s has no AnimationPlayer; nothing will move" % MODEL)
		return
	_anim = src
	var clip:= _driving_clip(_anim, CLIP)


	for library_name: StringName in _anim.get_animation_library_list():
		_anim.remove_animation_library(library_name)
	if clip == null:
		push_warning("PaperMachine: %s has no '%s' clip; nothing will move"
			% [MODEL, CLIP])
		return
	clip.loop_mode = Animation.LOOP_NONE
	var lib:= AnimationLibrary.new()
	lib.add_animation(CLIP, clip)
	_anim.add_animation_library("", lib)


	_anim.play(CLIP)
	_anim.seek(0.0, true)
	_anim.pause()


static var _clip_cache: Dictionary = { }


static func _driving_clip(player: AnimationPlayer, want: String) -> Animation:
	if _clip_cache.has(want):
		return _clip_cache [want]
	var found:= _clip_name(player, want)
	if found == "":
		return null
	var src:= player.get_animation(found)
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
	for n in player.get_animation_list():
		if n.ends_with(want):
			return n
	return ""


func clip_seconds() -> float:
	if _anim == null:
		return 0.0
	var found:= _clip_name(_anim, CLIP)
	if found == "":
		return 0.0
	var clip:= _anim.get_animation(found)
	return 0.0 if clip == null else clip.length


func _show_clip_props(on: bool) -> void:
	if _clip_pulp == null:
		_clip_pulp = _find(N_CLIP_PULP) as Node3D
	if _clip_roll == null:
		_clip_roll = _find(N_CLIP_ROLL) as Node3D
	if _clip_pulp != null:
		_clip_pulp.visible = on
	if _clip_roll != null:
		_clip_roll.visible = on


const SHOT_FRAME:= 160.0


func pose_for_shot(frame: float = SHOT_FRAME) -> void:
	if _anim == null or not _anim.has_animation(CLIP):
		return
	_show_clip_props(true)
	_anim.play(CLIP)
	_anim.seek(frame / CLIP_FPS, true)
	_anim.pause()


func port_in() -> Vector3:
	return to_global(_marker_local(N_BELT_IN, Vector3(0, 0, - Cfg.PAPER_LENGTH * 0.5))
		- Vector3(0, 0, port_reach))


func port_out() -> Vector3:
	return to_global(_marker_local(N_BELT_OUT, Vector3(0, 0, Cfg.PAPER_LENGTH * 0.5))
		- Vector3(0, 0, OUT_INSET))


func feed_point() -> Vector3:
	var local:= _marker_local(N_FEED, Vector3(0, 0, - Cfg.PAPER_LENGTH * 0.5 + 0.56))
	return to_global(Vector3(local.x, 0.0, local.z))


func intake_length() -> float:
	return INTAKE_LENGTH + port_reach


func deck() -> BeltPath:
	return _belt


func outfeed_deck() -> BeltPath:
	return _out_belt


func forward() -> Vector3:
	var d:= port_out() - port_in()
	return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
	return to_global(_marker_local(N_PANEL, Vector3(0.99, 0.63, 0.56)))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


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


	_out_belt.reserve_head(product_spot(), outfeed_reserve())


	_out_belt.records_props = true


func _build_intake_area() -> void:
	_intake = Area3D.new()
	_intake.name = "IntakeMouth"
	_intake.collision_layer = 0


	_intake.collision_mask = Cfg.L_PROP | Cfg.L_STRAND
	_intake.monitorable = false
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
		INTAKE_HEIGHT, intake_length())
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
	_intake.add_child(cs)
	add_child(_intake)


	_intake.position = to_local(feed_point() - forward() * (intake_length() * 0.5))


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
	_shape_flow(Cfg.PAPER_LENGTH)


func belt_runs() -> Array [PackedVector3Array]:
	var out_end:= port_out()
	return [PackedVector3Array([port_in(), feed_point()]),
		PackedVector3Array([out_end - forward() * OUT_STUB, out_end])]


func _process(delta: float) -> void:
	if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
		return
	_flow_phase += delta * ARROW_SPEED
	_shape_flow(Cfg.PAPER_LENGTH)


	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms(), [],
		drum_ends())


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


func _refresh_drums() -> void:
	if _drums != null:
		remove_child(_drums)
		_drums.queue_free()
		_drums = null
	if placement_preview:
		return
	_drums = Node3D.new()
	_drums.name = "Drums"


	_drums.top_level = true
	add_child(_drums)
	for e: Array in drum_ends():
		var mi:= MeshInstance3D.new()
		mi.mesh = ConveyorKit.nose_mesh(bool(e [0]))
		_drums.add_child(mi)
		mi.global_transform = Transform3D(e [2] as Basis, e [1] as Vector3)


		BeltBatch.adopt(mi)


func drum_ends() -> Array:
	var out_end:= port_out()
	var out_basis:= BeltPath.run_basis(out_end - forward() * OUT_STUB, out_end)
	var in_start:= port_in()
	var in_basis:= BeltPath.run_basis(in_start, feed_point())
	return [[true, out_end, out_basis],
		[false, in_start, in_basis.rotated(in_basis.y, PI)]]


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


func buffer_capacity() -> int:
	return Tech.paper_buffer()


func is_full() -> bool:
	return queued.size() >= buffer_capacity()


func is_running() -> bool:
	return _run >= 0.0


func cycle_seconds() -> float:
	return maxf(Tech.paper_cycle_seconds(), 0.001)


func alert_reason() -> String:
	if placement_preview:
		return ""

	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead
	if _run >= 0.0:


		if not _released and _run >= _release_at():
			return tr("OUTFEED BLOCKED  ·  move the paper roll off the deck")


	var stuck:= _jammed_load()
	if stuck != "":
		return tr("WRONG LOAD  ·  take the %s out of the intake") % stuck
	if _run >= 0.0:
		return ""


	var hungry:= Cfg.MACHINE_STARVED_AFTER if queued.is_empty() else charge_wait()
	if starved_for >= hungry:
		return tr("NO PULP  ·  nothing is reaching the intake")
	return ""


func _jammed_load() -> String:
	if _belt == null:
		return ""
	var rb:= _belt.waiting_rider()
	if rb == null or not _blocks_mouth(rb):
		return ""
	var item:= rb as Carryable
	return Cfg.lower_in_english(item.display_name) if item != null else tr("load")


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.PAPER_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2)
	return _ports


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_apply_cycle_speed()
	_apply_belt_speed()


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


func _apply_cycle_speed() -> void:
	if _anim != null:
		_anim.speed_scale = power * (Cfg.PAPER_CYCLE_SECONDS / cycle_seconds())


func run_progress() -> float:
	if _run < 0.0:
		return 0.0
	return clampf(_run / cycle_seconds(), 0.0, 1.0)


func factory_tick(delta: float) -> void:
	var held:= queued.size()
	_intake_slabs()


	if queued.size() > held:
		_note_arrival()
		starved_for = 0.0
	else:
		starved_for += delta
	_tick_run(delta)
	_sync_backpressure()
	_follow_feed_hold()
	_tick_dryer_loop(delta)


func charge_wait() -> float:
	var pace:= Tech.pulper_cycle_seconds()
	var gap:= pace if arrival_gap < 0.0 else arrival_gap
	return clampf(gap * Cfg.PAPER_CHARGE_WAIT_GAPS, pace, Cfg.PAPER_CHARGE_WAIT_MAX)


func _note_arrival() -> void:
	if not _seen_arrival:
		_seen_arrival = true
		return
	var sample:= minf(starved_for, Cfg.PAPER_CHARGE_WAIT_MAX)
	arrival_gap = sample if arrival_gap < 0.0 else lerpf(arrival_gap, sample, 0.35)


func _eats(body: Object) -> bool:
	var rb:= body as RigidBody3D
	if rb == null:
		return false


	if rb is PaperRoll:
		return false
	if rb is HayPulp:
		return true

	return rb.has_meta("needle_index") and bool(rb.collision_layer & Cfg.L_STRAND)


func _eats_kind(kind: int, _strands: int) -> bool:
	return kind == BeltRun.Kind.PULP


func _blocks_mouth(body: Object) -> bool:
	var rb:= body as RigidBody3D
	return rb != null and bool(rb.collision_layer & Cfg.L_PROP) and not _eats(rb)


func _intake_slabs() -> void:
	if _intake == null:
		return


	if _belt != null and not is_full():
		var m:= _belt.s_at(_intake.global_position)
		var rec:= _belt.take_record(Callable(), m - intake_length() * 0.5, m + intake_length() * 0.5)
		if not rec.is_empty():
			queued.append(int(rec ["strands"]))
			queued_needles.append(int(rec ["needle"]))
			Audio.play_3d("machine_thud", _intake.global_position, -9.0)
	for body in _intake.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		if not _eats(rb):
			continue
		var slab:= rb as HayPulp
		if slab == null:


			_swallow_needle(rb)
			continue
		if is_full():
			continue


		if slab.freeze and not BeltPath.is_rider(slab):
			continue


		BeltPath.release(slab)
		queued.append(slab.strands)


		queued_needles.append(slab.needle_index)


		Audio.play_3d("machine_thud", _mouth(), -9.0)
		if props != null:
			props.remove(slab)
		else:
			slab.queue_free()


func _swallow_needle(rb: RigidBody3D) -> void:
	if live == null or not rb.has_meta("needle_index"):
		return
	if not (rb.collision_layer & Cfg.L_STRAND):
		return


	if rb.freeze and not BeltPath.is_rider(rb) and not LiveStrandManager.is_pinned(rb):
		return


	BeltPath.release(rb)
	var index:= int(rb.get_meta("needle_index", -1))
	if not live.consume_needle(rb):
		return
	pending_needles.append(index)


	Audio.play_3d("machine_feed", _mouth(), -13.0)


func _mouth() -> Vector3:
	if _intake == null:
		return global_position
	return _intake.global_position


func _tick_run(delta: float) -> void:
	if _run < 0.0:


		if power <= 0.0:
			return


		if queued.size() >= Cfg.PAPER_SLABS_PER_ROLL or (not queued.is_empty() and starved_for >= charge_wait()):
			_start_run()
		return


	_run += delta * power
	if not _released and _run >= _release_at():
		_release_product()
	if _run >= cycle_seconds():
		_finish_run()


func _release_at() -> float:
	return cycle_seconds() * (F_RELEASE / CYCLE_FRAMES)


func _start_run() -> void:


	_batch = 0
	_batch_needle = -1
	for i in mini(Cfg.PAPER_SLABS_PER_ROLL, queued.size()):
		_batch += queued.pop_front()
		var carried: int = queued_needles.pop_front() if not queued_needles.is_empty() else -1
		if carried < 0:
			continue
		if _batch_needle < 0:
			_batch_needle = carried
		else:
			pending_needles.append(carried)
	_run = 0.0
	_released = false
	_show_clip_props(true)
	if _anim != null and _anim.has_animation(CLIP):
		_apply_cycle_speed()
		_anim.play(CLIP)
		_anim.seek(0.0, true)
	if _dryer_voice < 0:
		_dryer_voice = Audio.loop_acquire(DRYER_LOOP)
		_dryer_gain = DRYER_LOOP_SILENT
	_dryer_target = DRYER_LOOP_DB


	Audio.play_3d("machine_clunk", _emitter(), -8.0)


func _finish_run() -> void:


	if not _released:
		_run = _release_at()
		_release_product()
		return
	_run = -1.0


	_batch_needle = -1
	_dryer_target = DRYER_LOOP_SILENT
	if _anim != null:
		_anim.pause()
		_anim.seek(0.0, true)


	_show_clip_props(false)


func product_spot() -> Vector3:
	var at:= _marker_local(N_RELEASE,
		Vector3(0, Cfg.PAPER_ROLL_SIZE.y * 0.5, Cfg.PAPER_LENGTH * 0.5 - 0.73))
	return to_global(Vector3(at.x, at.y - Cfg.PAPER_ROLL_SIZE.y * 0.5, at.z))


func outfeed_reserve() -> float:
	return Cfg.PAPER_ROLL_CLEAR * 0.5


func _release_product() -> void:
	if props == null:


		push_warning("PaperMachine: no PropManager; the roll cannot be created")
		_released = true
		_orphan_batch_needle()
		return
	var at:= product_spot()
	if not _product_room(at):
		return


	if _out_belt != null and _out_belt.records_props:
		var needle:= _batch_needle
		var from_pending:= needle < 0 and not pending_needles.is_empty()
		if from_pending:
			needle = pending_needles [0]
		var state:= { "strands": _batch }
		if needle >= 0:
			state ["needle"] = needle
		var seq:= _out_belt.push_record(BeltRun.Kind.ROLL, _batch, needle, state, at)
		if seq < 0:
			return
		if from_pending:
			pending_needles.remove_at(0)
		_batch_needle = -1
		_released = true
		if _clip_roll == null:
			_clip_roll = _find(N_CLIP_ROLL) as Node3D
		if _clip_roll != null:
			_clip_roll.visible = false
		Audio.play_3d("machine_clunk", at, -13.0)
		Audio.play_3d_delayed("machine_vent", at, 0.12, -8.0)
		Audio.play_3d_delayed("machine_thud", at, 0.26, -6.0)
		rolled_record.emit(seq)
		return


	var product:= props.spawn("paper_roll",
		Transform3D(global_basis, at + Vector3.UP * (Cfg.PAPER_ROLL_SIZE.y * 0.04))) as PaperRoll
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


	if _clip_roll == null:
		_clip_roll = _find(N_CLIP_ROLL) as Node3D
	if _clip_roll != null:
		_clip_roll.visible = false


	Audio.play_3d("machine_clunk", at, -13.0)
	Audio.play_3d_delayed("machine_vent", at, 0.12, -8.0)
	Audio.play_3d_delayed("machine_thud", at, 0.26, -6.0)
	rolled.emit(product)


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
		_room_probe.size = Vector3(Cfg.PAPER_ROLL_SIZE.x,
			Cfg.PAPER_ROLL_SIZE.y, Cfg.PAPER_ROLL_CLEAR)
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = _room_probe
		_room_query.collision_mask = Cfg.L_PROP
		_room_query.collide_with_areas = false
	_room_query.transform = Transform3D(global_basis,
		at + Vector3.UP * Cfg.PAPER_ROLL_SIZE.y * 0.5)
	return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


func _sync_backpressure() -> void:
	if _belt == null:
		return
	var full:= is_full()
	if _belt.is_blocked() != full:
		_belt.set_blocked(full)


func _emitter() -> Vector3:
	return global_position + Vector3(0, DRYER_LOOP_HEIGHT, 0)


func _tick_dryer_loop(delta: float) -> void:
	if _dryer_voice < 0:
		return
	_dryer_gain = move_toward(_dryer_gain, _dryer_target, DRYER_LOOP_RAMP * delta)
	if _dryer_target <= DRYER_LOOP_SILENT and _dryer_gain <= DRYER_LOOP_SILENT + 0.5:
		_release_dryer_loop()
		return

	Audio.loop_update(_dryer_voice, _emitter(), _dryer_gain,
		MachinePower.loop_pitch(power))


func _release_dryer_loop() -> void:
	if _dryer_voice < 0:
		return
	Audio.loop_release(_dryer_voice)
	_dryer_voice = -1
	_dryer_gain = DRYER_LOOP_SILENT
	_dryer_target = DRYER_LOOP_SILENT


func _exit_tree() -> void:
	_release_dryer_loop()


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.PAPER_COST


func to_dict() -> Dictionary:
	return {
		"type": "paper_machine",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"queued": queued.duplicate(),
		"queued_needles": queued_needles.duplicate(),


		"running_needle": _batch_needle,
		"pending_needles": pending_needles,


		"port_reach": port_reach,
	}


func from_dict(d: Dictionary) -> void:


	port_reach = float(d.get("port_reach", 0.0))
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


	var running:= int(d.get("running_needle", -1))
	if running >= 0:
		pending_needles.append(running)
