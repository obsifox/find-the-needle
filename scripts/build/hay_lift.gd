class_name HayLift
extends Node3D


const MODEL:= "res://assets/models/compiled/hay_lift.scn"
const SPEC:= "res://assets/models/hay_lift_materials.json"

const N_BOOT:= "Lift_boot"
const N_SECTION:= "Lift_section"
const N_SPACER:= "Lift_spacer"
const N_HEAD:= "Lift_head"
const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"
const N_NIP:= "Marker_Nip"
const N_PANEL:= "Marker_Panel"


const N_BOOT_DRUM:= "Lift_boot_drum"


const CLIP:= "Run"


const MAT_BELT:= "M_HL_Belt"

const MAT_FRAME:= "M_HL_Frame"


const CUT_PLATE_DROP:= 0.03
const CUT_PLATE_T:= 0.03


const MODEL_DECK:= 0.31


const BOOT_FLANGE:= 0.985


const HEAD_TANGENT:= 0.35


const SPACER:= 0.21


const BEND_R:= 0.72


const HALF_NIP:= Cfg.HAY_LIFT_NIP * 0.5


const BEND_IN_Z:= - BEND_R


const MOUTH_Z:= -1.07


const MODEL_CUT_Z:= MOUTH_Z + Cfg.BELT_JOINT_OVERLAP


const OUT_Z:= 1.98


const HEAD_TOP:= 1.766
const HEAD_REACH:= 2.152


const HEAD_BEND_CLEAR:= 0.72


const HEAD_UNDER:= 0.37

const CASING:= 1.1


const BEND_STEPS:= 8


const SETTLE_SPEED:= BeltPath.PROP_SETTLE_SPEED


const RIDE_GAP:= Cfg.HAY_LIFT_GAP


const STALL_HOLD_MS:= HayStairs.STALL_HOLD_MS


const RIDE_TURN_RATE:= 5.0


const RIDE_SIDE_CLEAR:= 0.08


const NIP_CLOSE_FALLBACK:= 1.34


const NIP_CLOSE_MIN:= 0.3


const NIP_OPEN_BACK:= 0.6


const OUT_DECK_BACK:= 0.2


const MOUTH_REACH:= 0.4


const META_CARRIED:= "hay_lift_carried"


signal lifted_record(seq: int)


const STRAW_WAIT:= 1.0


const STRAW_LYING:= 0.12


var sections:= 3


var riser:= SPACER


var port_reach: Array = PORT_REACH.duplicate()

var live: LiveStrandManager
var props: PropManager
var placement_preview:= false

var _model: Node3D
var _boot: Node3D
var _head: Node3D


var _proto: Node3D

var _spacer: Node3D

var _sections: Array [Node3D] = []
var _anim: AnimationPlayer
var _in_belt: BeltPath
var _out_belt: BeltPath

var _ghost_belt: BeltGhost
var _mouth: Area3D


var _hulls: Array [StaticBody3D] = []


var _line: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()


var _sink_in:= 0.0
var _sink_out:= 0.0


var _carried: Array [Dictionary] = []


var _straw_wait:= 0.0
var _straw_seen:= 0


var _speed:= Cfg.HAY_LIFT_SPEED


var _belt_mat: ShaderMaterial

static var _spec_cache: Dictionary = { }

static var _trimmed_boot: ArrayMesh


func setup(at: Vector3, yaw: float, n: int, r: float = SPACER) -> void:
	position = at
	rotation.y = yaw
	sections = clampi(n, 0, Cfg.HAY_LIFT_SECTIONS_MAX)
	riser = SPACER if r > 0.0 else 0.0


static func rise_for(n: int, r: float = SPACER) -> float:
	return Cfg.HAY_LIFT_BASE_RISE - SPACER + r + Cfg.HAY_LIFT_SECTION * float(n)


static func sections_for(rise: float, r: float = SPACER) -> int:
	return clampi(int(roundf((rise - rise_for(0, r))
		/ Cfg.HAY_LIFT_SECTION)), 0, Cfg.HAY_LIFT_SECTIONS_MAX)


static func deck_top_for(floor_y: float, n: int, r: float = SPACER) -> float:
	return floor_y + Cfg.HAY_LIFT_DECK + rise_for(n, r) - (Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)


static func sections_to_deck(floor_y: float, top: float) -> int:
	for r in [SPACER, 0.0]:
		var n:= int(roundf((top - deck_top_for(floor_y, 0, r)) / Cfg.HAY_LIFT_SECTION))
		if n < 0 or n > Cfg.HAY_LIFT_SECTIONS_MAX:
			continue
		if absf(deck_top_for(floor_y, n, r) - top) <= 0.01:
			return n
	return -1


static func riser_for_climb(climb: float) -> float:
	for n in Cfg.HAY_LIFT_SECTIONS_MAX + 1:
		if absf(rise_for(n, SPACER) - climb) <= 0.01:
			return SPACER
	for n in Cfg.HAY_LIFT_SECTIONS_MAX + 1:
		if absf(rise_for(n, 0.0) - climb) <= 0.01:
			return 0.0
	return SPACER


static func sections_reaching(climb: float, r: float = SPACER) -> int:
	return maxi(0, ceili((climb - rise_for(0, r)) / Cfg.HAY_LIFT_SECTION - 0.01))


static func cost_for(n: int) -> float:
	return Cfg.HAY_LIFT_COST + Cfg.HAY_LIFT_SECTION_COST * float(clampi(n, 0, Cfg.HAY_LIFT_SECTIONS_MAX))


const PLAN_X:= Vector2(-0.82, 0.71)
const PLAN_Z:= Vector2(-2.28, 2.38)


const PORT_REACH:= [0.72, 0.62]


static func plan_rect(at: Vector3, forward: Vector3, reach: Array = PORT_REACH) -> Array:
	var z:= Vector2(forward.x, forward.z).normalized()
	if z == Vector2.ZERO:
		z = Vector2(0.0, 1.0)


	var x:= Vector2(z.y, - z.x)
	var pz:= Vector2(PLAN_Z.x - float(reach [0]), PLAN_Z.y + float(reach [1]))
	var mid:= Vector2((PLAN_X.x + PLAN_X.y) * 0.5, (pz.x + pz.y) * 0.5)
	var centre:= Vector2(at.x, at.z) + x * mid.x + z * mid.y
	return [centre, x, z, Vector2((PLAN_X.y - PLAN_X.x) * 0.5, (pz.y - pz.x) * 0.5)]


static func plan_rects_overlap(a: Array, b: Array) -> bool:
	var d: Vector2 = (b [0] as Vector2) - (a [0] as Vector2)
	for axis: Vector2 in [a [1], a [2], b [1], b [2]]:
		var ra: float = absf((a [1] as Vector2).dot(axis)) * (a [3] as Vector2).x + absf((a [2] as Vector2).dot(axis)) * (a [3] as Vector2).y
		var rb: float = absf((b [1] as Vector2).dot(axis)) * (b [3] as Vector2).x + absf((b [2] as Vector2).dot(axis)) * (b [3] as Vector2).y
		if absf(d.dot(axis)) >= ra + rb:
			return false
	return true


static func metres(v: float) -> String:
	var whole:= roundf(v)
	if absf(v - whole) < 0.005:
		return "%d" % int(whole)
	return "%.2f" % v


func rise() -> float:
	return rise_for(sections, riser)


func head_flange() -> float:
	return BOOT_FLANGE + Cfg.HAY_LIFT_SECTION * float(sections) + riser


func build_cost() -> float:
	return cost_for(sections)


func _ready() -> void:
	_build_model()
	_stack()
	_skin()
	if placement_preview:
		set_physics_process(false)
		set_preview_valid(true)
		return

	set_process(false)


	FactoryClock.join(self)
	_play()


	MachineLod.adopt(self, _model, "%s#%d#%d" % [MODEL, sections, int(riser > 0.0)])
	_build_line()
	_build_decks()
	_build_mouth()
	_build_hulls()
	add_to_group("hay_lifts")


	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_follow_tech)
	_follow_tech()


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("HayLift: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	_model.position.y = - MODEL_DECK
	_boot = _model.find_child(N_BOOT, true, false) as Node3D
	_head = _model.find_child(N_HEAD, true, false) as Node3D
	_spacer = _model.find_child(N_SPACER, true, false) as Node3D
	if _spacer == null:
		push_error("HayLift: %s is missing %s" % [MODEL, N_SPACER])
	if _boot == null or _head == null:
		push_error("HayLift: %s is missing %s or %s" % [MODEL, N_BOOT, N_HEAD])
	_trim_boot()
	if placement_preview:
		_build_ghost_belt()
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _trim_boot() -> void:
	var mi:= _boot as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	if _trimmed_boot == null:


		var into:= mi.global_transform.affine_inverse() * global_transform
		var keep:= (into.basis * Vector3(0.0, 0.0, 1.0)).normalized()
		_trimmed_boot = _clip_mesh(mi.mesh,
			Plane(keep, into * Vector3(0.0, 0.0, MODEL_CUT_Z)))
	mi.mesh = _trimmed_boot
	var drum:= _boot.find_child(N_BOOT_DRUM, true, false) as Node3D
	if drum != null:
		drum.visible = false
	_close_cut(mi)


func _close_cut(boot: MeshInstance3D) -> void:
	var frame: Material = null
	for i in boot.mesh.get_surface_count():
		var m:= boot.mesh.surface_get_material(i)
		if m != null and m.resource_name == MAT_FRAME:
			frame = m
			break
	var box:= BoxMesh.new()
	box.size = Vector3(CASING, MODEL_DECK - CUT_PLATE_DROP, CUT_PLATE_T)
	var plate:= MeshInstance3D.new()
	plate.name = "InfeedBulkhead"
	plate.mesh = box
	if frame != null:
		plate.set_surface_override_material(0, frame)
	boot.add_child(plate)
	plate.global_transform = global_transform.translated_local(Vector3(0.0,
		- (MODEL_DECK + CUT_PLATE_DROP) * 0.5, MODEL_CUT_Z + CUT_PLATE_T * 0.5))


static func _clip_mesh(src: Mesh, plane: Plane) -> ArrayMesh:
	var out:= ArrayMesh.new()
	for i in src.get_surface_count():
		if src.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays:= src.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
		var has_n: bool = arrays [Mesh.ARRAY_NORMAL] != null
		var has_uv: bool = arrays [Mesh.ARRAY_TEX_UV] != null
		var norms: PackedVector3Array = arrays [Mesh.ARRAY_NORMAL] if has_n else PackedVector3Array()
		var uvs: PackedVector2Array = arrays [Mesh.ARRAY_TEX_UV] if has_uv else PackedVector2Array()
		var idx: PackedInt32Array = arrays [Mesh.ARRAY_INDEX] if arrays [Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for k in verts.size():
				idx [k] = k
		var dist:= PackedFloat32Array()
		dist.resize(verts.size())
		for k in verts.size():
			dist [k] = plane.distance_to(verts [k])


		var o_verts:= PackedVector3Array()
		var o_norms:= PackedVector3Array()
		var o_uvs:= PackedVector2Array()
		var o_idx:= PackedInt32Array()
		var remap:= PackedInt32Array()
		remap.resize(verts.size())
		remap.fill(-1)
		var cuts: Dictionary = { }
		for t in range(0, idx.size() - 2, 3):
			var tri:= [idx [t], idx [t + 1], idx [t + 2]]
			var inside:= 0
			for v: int in tri:
				if dist [v] >= 0.0:
					inside += 1
			if inside == 0:
				continue


			var poly:= PackedInt32Array()
			for e in 3:
				var a: int = tri [e]
				var b: int = tri [(e + 1) % 3]
				var a_in:= dist [a] >= 0.0
				var b_in:= dist [b] >= 0.0
				if a_in:
					if remap [a] < 0:
						remap [a] = o_verts.size()
						o_verts.append(verts [a])
						if has_n:
							o_norms.append(norms [a])
						if has_uv:
							o_uvs.append(uvs [a])
					poly.append(remap [a])
				if a_in != b_in:
					var key:= Vector2i(mini(a, b), maxi(a, b))
					if not cuts.has(key):
						var f:= dist [a] / (dist [a] - dist [b])
						cuts [key] = o_verts.size()
						o_verts.append(verts [a].lerp(verts [b], f))
						if has_n:
							o_norms.append(norms [a].lerp(norms [b], f).normalized())
						if has_uv:
							o_uvs.append(uvs [a].lerp(uvs [b], f))
					poly.append(cuts [key])
			for k in range(1, poly.size() - 1):
				o_idx.append(poly [0])
				o_idx.append(poly [k])
				o_idx.append(poly [k + 1])
		if o_idx.is_empty():
			continue
		var built: Array = []
		built.resize(Mesh.ARRAY_MAX)
		built [Mesh.ARRAY_VERTEX] = o_verts
		if has_n:
			built [Mesh.ARRAY_NORMAL] = o_norms
		if has_uv:
			built [Mesh.ARRAY_TEX_UV] = o_uvs
		built [Mesh.ARRAY_INDEX] = o_idx
		var j:= out.get_surface_count()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
		out.surface_set_material(j, src.surface_get_material(i))
		if src is ArrayMesh:
			out.surface_set_name(j, (src as ArrayMesh).surface_get_name(i))
	return out


func _build_ghost_belt() -> void:
	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


func belt_runs() -> Array [PackedVector3Array]:
	var let_go:= to_global(Vector3(0.0, head_flange() + HEAD_TANGENT + BEND_R, OUT_Z))
	var drop:= let_go - global_basis.y * HALF_NIP
	var back:= forward() * OUT_DECK_BACK
	return [PackedVector3Array([port_in(), to_global(Vector3(0.0, 0.0, MOUTH_Z))]),
		PackedVector3Array([drop - back, port_out()])]


func _process(_delta: float) -> void:
	if not placement_preview or _ghost_belt == null or not is_visible_in_tree():
		return
	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP)


func _stack() -> void:
	if _model == null:
		return
	var original:= _model.find_child(N_SECTION, true, false) as Node3D
	if original == null:
		push_error("HayLift: %s is missing %s; the tower cannot be built" % [MODEL, N_SECTION])
		return


	_proto = original
	if _proto.get_parent() != null:
		_proto.get_parent().remove_child(_proto)
	_sections.clear()
	_restack()


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("HayLift: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
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
			if key.is_empty():
				continue
			var scrolls:= key == MAT_BELT and _has_uvs(mesh.mesh, i)
			var slot:= key + ("#scroll" if scrolls else "")
			if not built.has(slot):
				built [slot] = _belt_material() if scrolls else HayCompressor.shared_material(MODEL, key,
						func() -> Material: return HayCompressor.make_material(key, spec, shader))
			if built [slot] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [slot])
	if not missed.is_empty():
		push_warning("HayLift: no table entry for %s" % ", ".join(missed.keys()))


func _belt_material() -> ShaderMaterial:
	_belt_mat = ConveyorKit.own_belt_material(_speed)
	_belt_mat.resource_name = MAT_BELT
	return _belt_mat


static func _has_uvs(mesh: Mesh, surface: int) -> bool:
	return (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV) != 0


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


func _play() -> void:
	if _model == null:
		return
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("HayLift: %s has no AnimationPlayer; nothing will turn" % MODEL)
		return
	var lib:= _anim.get_animation(CLIP)
	if lib == null:
		push_warning("HayLift: %s has no '%s' clip" % [MODEL, CLIP])
		return
	lib.loop_mode = Animation.LOOP_LINEAR
	_anim.play(CLIP)


func ride_speed() -> float:
	return _speed


func _on_tech_changed(_id: String, _rank: int) -> void:
	_follow_tech()


func _follow_tech() -> void:
	_speed = Tech.belt_speed()
	if _anim != null:
		_anim.speed_scale = _speed / Cfg.HAY_LIFT_SPEED
	if _belt_mat != null:
		_belt_mat.set_shader_parameter("speed", _speed)


func _build_line() -> void:
	var pts: Array [Vector3] = []

	pts.append(Vector3(0.0, HALF_NIP, MOUTH_Z))
	pts.append(Vector3(0.0, HALF_NIP, BEND_IN_Z))


	var bottom:= Vector3(0.0, BOOT_FLANGE, BEND_IN_Z)
	for i in range(1, BEND_STEPS + 1):
		var a:= PI * 0.5 * float(i) / float(BEND_STEPS)
		pts.append(bottom + Vector3(0.0, - BEND_R * cos(a), BEND_R * sin(a)))


	var flange:= head_flange()
	pts.append(Vector3(0.0, flange + HEAD_TANGENT, 0.0))

	var top:= Vector3(0.0, flange + HEAD_TANGENT, BEND_R)
	for i in range(1, BEND_STEPS + 1):
		var a:= PI * 0.5 * float(i) / float(BEND_STEPS)
		pts.append(top + Vector3(0.0, BEND_R * sin(a), - BEND_R * cos(a)))

	pts.append(Vector3(0.0, flange + HEAD_TANGENT + BEND_R, OUT_Z))

	_line = PackedVector3Array()
	for p in pts:
		_line.append(to_global(p))
	_cum = PackedFloat32Array()
	_cum.resize(_line.size())
	_cum [0] = 0.0
	for i in range(1, _line.size()):
		_cum [i] = _cum [i - 1] + _line [i - 1].distance_to(_line [i])


	var nip:= _find(N_NIP) as Node3D
	_sink_in = NIP_CLOSE_FALLBACK
	if nip != null:
		_sink_in = _cum [0] + _line [0].distance_to(nip.global_position)
	_sink_in = clampf(_sink_in, 0.05, total_length())
	_sink_out = maxf(_sink_in, total_length() - NIP_OPEN_BACK)


func _build_decks() -> void:
	_in_belt = BeltPath.new()
	_in_belt.name = "InfeedDeck"
	add_child(_in_belt)


	var runs:= belt_runs()
	_in_belt.build_path(runs [0], Cfg.BELT_JOINT_OVERLAP)


	_in_belt.records_props = true
	_in_belt.hold_records(_eats)


	_out_belt = BeltPath.new()
	_out_belt.name = "DischargeDeck"
	add_child(_out_belt)
	_out_belt.build_path(runs [1], Cfg.BELT_JOINT_OVERLAP)


	_out_belt.records_props = true


func _eats(_kind: int, _strands: int) -> bool:
	return true


func _build_mouth() -> void:
	_mouth = Area3D.new()
	_mouth.name = "Mouth"
	_mouth.collision_layer = 0


	_mouth.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	_mouth.monitorable = false


	var tall:= Cfg.HAY_LIFT_DECK + Cfg.HAY_LIFT_NIP
	var back:= MOUTH_Z - MOUTH_REACH
	var front:= - CASING * 0.5
	var box:= BoxShape3D.new()
	box.size = Vector3(Cfg.HAY_LIFT_NIP + 0.3, tall, front - back)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0.0, tall * 0.5 - Cfg.HAY_LIFT_DECK, (front + back) * 0.5)
	_mouth.add_child(cs)
	add_child(_mouth)


func _build_hulls() -> void:
	var flange:= head_flange()


	_add_hull("Tower", Vector3(CASING, flange + MODEL_DECK, CASING),
		Vector3(0.0, (flange - MODEL_DECK) * 0.5, 0.0))


	var run:= - CASING * 0.5 - MODEL_CUT_Z
	_add_hull("Infeed", Vector3(CASING, MODEL_DECK, run),
		Vector3(0.0, - MODEL_DECK * 0.5, MODEL_CUT_Z + run * 0.5))


	var belt:= rise()
	var reach:= HEAD_REACH - CASING * 0.5
	_add_hull("HeadOver",
		Vector3(CASING, flange + HEAD_TOP - (belt + Cfg.HAY_LIFT_NIP), HEAD_REACH),
		Vector3(0.0, (belt + Cfg.HAY_LIFT_NIP + flange + HEAD_TOP) * 0.5,
			HEAD_REACH * 0.5 - CASING * 0.5))


	_add_hull("HeadBend", Vector3(CASING, belt - 0.04 - flange, HEAD_BEND_CLEAR - CASING * 0.5),
		Vector3(0.0, (belt - 0.04 + flange) * 0.5, (HEAD_BEND_CLEAR + CASING * 0.5) * 0.5))
	var outfeed:= HEAD_REACH - HEAD_BEND_CLEAR
	_add_hull("HeadUnder", Vector3(CASING, HEAD_UNDER - 0.04, outfeed),
		Vector3(0.0, belt - HEAD_UNDER * 0.5 - 0.02, HEAD_BEND_CLEAR + outfeed * 0.5))


func hull_over(body: CollisionObject3D, top_y: float) -> bool:
	if body == null or not is_ancestor_of(body):
		return false
	var any:= false
	for cs in body.find_children("*", "CollisionShape3D", false, false):
		var shape:= (cs as CollisionShape3D).shape
		if shape == null:
			continue
		var box: AABB = (cs as CollisionShape3D).global_transform * shape.get_debug_mesh().get_aabb()
		if box.position.y < top_y - 0.005:
			return false
		any = true
	return any


func _add_hull(hull_name: String, size: Vector3, at: Vector3) -> void:
	var body:= StaticBody3D.new()
	body.name = hull_name
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var box:= BoxShape3D.new()
	box.size = size
	var cs:= CollisionShape3D.new()
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.position = at
	_hulls.append(body)


func full_rate() -> bool:
	return true


func factory_tick(delta: float) -> void:
	_claim(delta)
	_carry(delta)


	_sync_backpressure()


func _sync_backpressure() -> void:
	if _in_belt == null:
		return


	_in_belt.set_outlet_held(_lowest_s() < RIDE_GAP)


func _claim(delta: float) -> void:
	_claim_record()
	if _mouth == null:
		return
	var straw: Array [Dictionary] = []
	for body in _mouth.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		if rb.has_meta(META_CARRIED):
			continue


		if BeltPath.is_rider(rb) and rb.get_meta(LiveStrandManager.META_RIDER) != _in_belt:
			continue


		if rb.freeze and not BeltPath.is_rider(rb):
			continue


		if not BeltPath.is_rider(rb) and rb.linear_velocity.length() > SETTLE_SPEED:
			continue
		var at:= _nearest(rb.global_position)

		if _is_loose_straw(rb):
			if float(at ["sink"]) >= HALF_NIP - STRAW_LYING:
				straw.append({ "body": rb, "s": at ["s"], "sink": at ["sink"] })
			continue


		if not _room_at(float(at ["s"])):
			continue
		_take(rb, at)
	_gather_straw(straw, delta)


func _is_loose_straw(rb: RigidBody3D) -> bool:
	return BeltPath.straw_tufts_enabled and props != null and live != null and rb.get_parent() == live and not rb.has_meta("needle_index") and not live.is_held_by_a_tool(rb)


func _claim_record() -> void:
	if _in_belt == null or not _in_belt.records_props:
		return
	var head:= _in_belt.peek_record()
	if not head.is_empty():
		var at:= _nearest(_record_origin(head))
		if _room_at(float(at ["s"])):
			_take_record(_in_belt.take_record(), at, _in_belt.basis_at(float(head ["s"])))
		return
	if _lowest_s() < RIDE_GAP:
		return
	var lo:= _in_belt.s_at(to_global(Vector3(0.0, 0.0, MOUTH_Z - MOUTH_REACH)))
	var rec:= _in_belt.take_record(Callable(), lo, _in_belt.path_length())
	if rec.is_empty():
		return
	_take_record(rec, _nearest(_record_origin(rec)), _in_belt.basis_at(float(rec ["s"])))


func _record_origin(rec: Dictionary) -> Vector3:
	return _in_belt.run.pose_at(float(rec ["s"]), float(rec ["side"]), float(rec ["lift"])).origin


func _lowest_s() -> float:
	var lowest:= INF
	for r in _carried:
		lowest = minf(lowest, float(r ["s"]))
	return lowest


func _gather_straw(straw: Array [Dictionary], delta: float) -> void:
	if straw.is_empty():
		_straw_wait = 0.0
		_straw_seen = 0
		return
	straw.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["s"]) > float(y ["s"]))
	var rows: Array [Dictionary] = []
	for row in straw:
		if not _into_carried_tuft(row):
			rows.append(row)
	if rows.size() != _straw_seen:
		_straw_seen = rows.size()
		_straw_wait = 0.0
	else:
		_straw_wait += delta
	var i:= 0
	while i < rows.size():
		var lead:= float(rows [i] ["s"])
		var j:= i
		while j + 1 < rows.size() and j + 1 - i < Cfg.TUFT_MAX and lead - float(rows [j + 1] ["s"]) < RIDE_GAP:
			j += 1
		var run:= rows.slice(i, j + 1)
		if run.size() < Cfg.TUFT_MERGE_AT and _straw_wait < STRAW_WAIT:
			return
		if not _lift_straw(run):
			return
		i = j + 1


func _lift_straw(run: Array [Dictionary]) -> bool:
	var s:= 0.0
	var sink:= 0.0
	for row in run:
		s += float(row ["s"])
		sink += float(row ["sink"])
	s /= float(run.size())
	sink = clampf(sink / float(run.size()), 0.0, HALF_NIP)
	if not _room_at(s):
		return false
	if run.size() == 1:
		_take(run [0] ["body"], run [0])
		return true
	var tuft:= props.spawn("hay_tuft",
		Transform3D(_ride_basis_at(s), _point_at(s) - global_basis.y * sink),
		{ "strands": run.size() }) as HayTuft
	if tuft == null:
		return false
	for row in run:
		var rb:= row ["body"] as RigidBody3D
		BeltPath.release(rb)
		live.consume(rb)
	_take(tuft, { "s": s, "sink": sink })
	return true


func _into_carried_tuft(row: Dictionary) -> bool:
	var s:= float(row ["s"])
	for r in _carried:
		var b = r.get("body")
		if not is_instance_valid(b) or b is not HayTuft:
			continue
		var tuft: HayTuft = b
		if tuft.strands >= Cfg.TUFT_MAX or float(r ["s"]) >= maxf(_sink_in, float(r ["from"]) + NIP_CLOSE_MIN) or absf(float(r ["s"]) - s) > tuft.reach() + Cfg.TUFT_ABSORB_REACH:
			continue
		var rb:= row ["body"] as RigidBody3D
		BeltPath.release(rb)
		if not live.consume(rb):
			return false
		tuft.add_strands(1)

		var box:= tuft.ride_box()
		r ["centre"] = box.position.y + box.size.y * 0.5
		return true
	return false


func _room_at(s: float) -> bool:
	for r in _carried:
		var ahead:= float(r ["s"]) - s
		if ahead >= 0.0 and ahead < RIDE_GAP:
			return false
	return true


func _take(rb: RigidBody3D, at: Dictionary) -> void:


	BeltPath.release(rb)


	var kind:= BeltPath.record_kind(rb)
	if kind >= 0:
		_take_body_as_record(rb, at, kind)
		return
	rb.set_meta(META_CARRIED, self)
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO


	var item:= rb as Carryable
	var box:= item.ride_box() if item != null else AABB()
	var fit:= _ride_fit(box) if item != null and box.size.y > 0.0001 else 1.0


	var s0:= float(at ["s"])
	_carried.append({
		"body": rb,
		"s": s0,


		"from": s0,


		"centre": box.position.y + box.size.y * 0.5,


		"fit": fit,


		"sink": clampf(float(at ["sink"]), 0.0, HALF_NIP),

		"moved_ms": Time.get_ticks_msec(),
	})
	_sort_carried()


	Audio.play_3d("machine_thud", rb.global_position, -11.0)


func _take_body_as_record(rb: RigidBody3D, at: Dictionary, kind: int) -> void:
	var item:= rb as Carryable
	var state:= item.to_state()
	if item.holds_needle():
		state ["needle"] = item.needle_index
	var rec:= {
		"kind": kind, "strands": item.hay_strands(), "needle": item.needle_index,
		"state": state, "seq": -1, "s": 0.0, "side": 0.0, "lift": 0.0,
		"reach": 0.0, "speed": 0.0,
	}
	var basis:= rb.global_basis.orthonormalized()
	BeltPath.retire_body(rb, props)
	_take_record(rec, at, basis)


func _take_record(rec: Dictionary, at: Dictionary, basis: Basis, from: float = NAN,
		quiet: bool = false) -> void:
	if rec.is_empty():
		return
	var kind:= int(rec ["kind"])
	var strands:= int(rec ["strands"])
	var shape: Dictionary = _in_belt.shape_of_kind(kind, strands) if _in_belt != null else { }
	var box: AABB = shape.get("box", AABB())
	var fit:= _ride_fit(box) if box.size.y > 0.0001 else 1.0
	var s0:= float(at ["s"])
	var draw:= BeltRunBatch.stand_in(kind, strands)
	if draw != null:
		add_child(draw)
	var r:= {
		"rec": rec,
		"s": s0,
		"from": s0 if is_nan(from) else from,
		"centre": box.position.y + box.size.y * 0.5,
		"fit": fit,
		"sink": clampf(float(at ["sink"]), 0.0, HALF_NIP),
		"moved_ms": Time.get_ticks_msec(),


		"basis": basis,
		"draw": draw,
	}
	_place_record(r, s0, 1.0)
	_carried.append(r)
	_sort_carried()
	if not quiet:
		Audio.play_3d("machine_thud", r ["at"], -11.0)


func _place_record(r: Dictionary, s: float, squeeze: float) -> void:
	var basis: Basis = r ["basis"]
	var at:= _ride_point(s, float(r ["sink"]), float(r ["centre"]) * squeeze, basis.y,
		float(r ["from"]))
	r ["at"] = at
	var xform:= Transform3D(basis.scaled(Vector3.ONE * squeeze), at)
	r ["xform"] = xform
	var draw = r.get("draw")
	if draw != null and is_instance_valid(draw):
		draw.global_transform = xform


func _carry(delta: float) -> void:
	if _carried.is_empty():
		return
	var total:= total_length()
	for k in range(_carried.size() - 1, -1, -1):
		var r: Dictionary = _carried [k]
		var is_record:= r.has("rec")
		var b = r.get("body")


		if not is_record and (not is_instance_valid(b) or not b.is_inside_tree() or not b.has_meta(META_CARRIED) or not b.freeze):
			_forget(k)
			continue
		var s: float = float(r ["s"]) + _speed * delta


		if k + 1 < _carried.size():
			s = minf(s, maxf(float(r ["s"]),
				float((_carried [k + 1] as Dictionary) ["s"]) - RIDE_GAP))
		if s >= total:


			if is_record:
				if _release_record(k):
					continue
			elif _drop_clear(b):
				_release(k)
				continue
			s = total
		if s > float(r ["s"]) + 0.0001:
			r ["moved_ms"] = Time.get_ticks_msec()
		r ["s"] = s
		_carried [k] = r


		var squeeze:= 1.0
		if float(r ["fit"]) < 1.0:
			squeeze = _ride_squeeze(s, float(r ["fit"]), float(r ["from"]))
			var item: Carryable = b as Carryable
			if item != null:
				item.set_ride_scale(squeeze)
		if is_record:


			r ["basis"] = _turn_basis(r ["basis"], s, delta)
			_place_record(r, s, squeeze)
			continue


		_turn(b, s, delta)
		b.global_position = _ride_point(s, float(r ["sink"]),
			float(r ["centre"]) * squeeze, b.global_basis.y, float(r ["from"]))


		if Time.get_ticks_msec() - int(r ["moved_ms"]) < STALL_HOLD_MS:
			LiveStrandManager.hold(b)


func _turn(b: Node3D, s: float, delta: float) -> void:
	b.global_basis = _turn_basis(b.global_basis, s, delta)


func _turn_basis(have_basis: Basis, s: float, delta: float) -> Basis:
	var want:= Quaternion(_ride_basis_at(s))
	var have:= Quaternion(have_basis.orthonormalized())


	var rate:= RIDE_TURN_RATE * _speed / Cfg.HAY_LIFT_SPEED
	return Basis(have.slerp(want, clampf(delta * rate, 0.0, 1.0)))


func _ride_basis_at(s: float) -> Basis:
	if _line.size() < 2:
		return global_basis
	var i:= _seg_at(s)
	return _ride_basis(_line [i], _line [i + 1])


func _ride_basis(from: Vector3, to: Vector3) -> Basis:
	var fwd:= to - from
	if fwd.length_squared() < 1e-08:
		return global_basis
	fwd = fwd.normalized()
	var right:= global_basis.x.normalized()


	if absf(right.dot(fwd)) > 0.999:
		right = global_basis.z.normalized()
	var up:= fwd.cross(right).normalized()
	return Basis(up.cross(fwd).normalized(), up, fwd)


func _ride_squeeze(s: float, fit: float, from:= 0.0) -> float:
	if fit >= 1.0:
		return 1.0
	return fit + (1.0 - fit) * _sink_fade(s, from)


func _ride_fit(box: AABB) -> float:
	var fit:= 1.0
	if box.size.y > 0.0001:
		fit = minf(fit, Cfg.HAY_LIFT_NIP / box.size.y)
	if box.size.x > 0.0001:
		fit = minf(fit, (CASING - RIDE_SIDE_CLEAR) / box.size.x)
	return clampf(fit, 0.05, 1.0)


func _drop_clear(me: Node3D) -> bool:
	if _out_belt == null or props == null:
		return true
	var at:= _point_at(total_length())
	for item in props.items:
		var rb:= item as RigidBody3D
		if rb == null or rb == me or not rb.is_inside_tree():
			continue
		if rb.global_position.distance_to(at) < RIDE_GAP:
			return false
	return true


func _release(k: int) -> void:
	var r: Dictionary = _carried [k]
	var b = r ["body"]
	_carried.remove_at(k)
	if not is_instance_valid(b):
		return
	b.remove_meta(META_CARRIED)
	_unfit(r)
	if not b.is_inside_tree():
		return
	b.global_position = _ride_point(total_length(), float(r ["sink"]),
		float(r ["centre"]), b.global_basis.y)
	b.freeze = false
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO


func _release_record(k: int) -> bool:
	if _out_belt == null or not _out_belt.records_props:
		return false
	var r: Dictionary = _carried [k]
	var rec: Dictionary = r ["rec"]
	var seq:= _out_belt.push_record(int(rec ["kind"]), int(rec ["strands"]),
		int(rec ["needle"]), rec.get("state"), _point_at(total_length()), -1.0,
		RIDE_GAP, int(rec.get("seq", -1)))
	if seq < 0:
		return false
	_carried.remove_at(k)
	_free_draw(r)
	lifted_record.emit(seq)
	return true


func _free_draw(r: Dictionary) -> void:
	var draw = r.get("draw")
	if draw != null and is_instance_valid(draw):
		draw.queue_free()
	r ["draw"] = null


func _spill_record(r: Dictionary) -> void:
	if props == null or not is_instance_valid(props) or not props.is_inside_tree():
		return
	var rec: Dictionary = r ["rec"]
	var kind:= int(rec ["kind"])
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
		return
	var state: Variant = rec.get("state")
	var item:= props.spawn(BeltRun.ITEM_IDS [kind],
		Transform3D((r ["basis"] as Basis).orthonormalized(), r ["at"]),
		state if state is Dictionary else { })
	if item != null:
		LiveStrandManager.hold(item)


func _forget(k: int) -> void:
	var r: Dictionary = _carried [k]
	_carried.remove_at(k)
	if r.has("rec"):
		_free_draw(r)
		_spill_record(r)
		return
	var b = r ["body"]
	_unfit(r)
	if not is_instance_valid(b) or not b.has_meta(META_CARRIED):
		return
	b.remove_meta(META_CARRIED)
	if b.is_inside_tree() and b.freeze:
		b.freeze = false
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO


func _unfit(r: Dictionary) -> void:
	if float(r.get("fit", 1.0)) >= 1.0:
		return
	var b = r ["body"]
	if not is_instance_valid(b):
		return
	var item: Carryable = b as Carryable
	if item != null:
		item.set_ride_scale(1.0)


func _sort_carried() -> void:
	_carried.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["s"]) < float(y ["s"]))


func _exit_tree() -> void:
	for k in range(_carried.size() - 1, -1, -1):
		_forget(k)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_proto) and _proto.get_parent() == null:
		_proto.free()


func port_in() -> Vector3:
	return to_global(_marker(N_BELT_IN, Vector3(0.0, 0.0, MOUTH_Z - 0.22))
		- Vector3(0.0, 0.0, float(port_reach [0])))


func port_out() -> Vector3:
	if _head != null:
		var marker:= _find(N_BELT_OUT) as Node3D
		if marker != null:
			return marker.global_position + forward() * float(port_reach [1])
	return to_global(Vector3(0.0, rise(), OUT_Z + 0.4 + float(port_reach [1])))


func forward() -> Vector3:
	return global_basis.z.normalized()


func deck() -> BeltPath:
	return _in_belt


func outfeed_deck() -> BeltPath:
	return _out_belt


func console_position() -> Vector3:
	return to_global(_marker(N_PANEL, Vector3(-0.76, 0.55, 0.28)))


func in_transit() -> int:
	return _carried.size()


func row_of(seq: int) -> int:
	for k in _carried.size():
		var rec: Dictionary = (_carried [k] as Dictionary).get("rec", { })
		if not rec.is_empty() and int(rec.get("seq", -1)) == seq:
			return k
	return -1


func carries(seq: int) -> bool:
	return row_of(seq) >= 0


func carried_record(k: int) -> Dictionary:
	return (_carried [k] as Dictionary).get("rec", { })


func carried_transform(k: int) -> Transform3D:
	var r: Dictionary = _carried [k]
	if r.has("rec"):
		return r ["xform"]
	var b = r.get("body")
	return (b as Node3D).global_transform if is_instance_valid(b) else Transform3D.IDENTITY


func carried_box(k: int) -> AABB:
	var r: Dictionary = _carried [k]
	if r.has("rec"):
		var rec: Dictionary = r ["rec"]
		var shape: Dictionary = _in_belt.shape_of_kind(int(rec ["kind"]), int(rec ["strands"])) if _in_belt != null else { }
		return shape.get("box", AABB())
	var b = r.get("body")
	return (b as Carryable).ride_box() if is_instance_valid(b) and b is Carryable else AABB()


func carried_count(kind: int) -> int:
	var n:= 0
	for r in _carried:
		var rec: Dictionary = (r as Dictionary).get("rec", { })
		if not rec.is_empty() and int(rec ["kind"]) == kind:
			n += 1
	return n


static func rows_to_array() -> Array:
	var out: Array = []
	var tree:= Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("hay_lifts"):
		var lift:= n as HayLift
		if lift == null or not lift.is_inside_tree():
			continue
		var rows: Array = []
		for r in lift._carried:
			var rec: Dictionary = (r as Dictionary).get("rec", { })
			if rec.is_empty():
				continue
			var kind:= int(rec ["kind"])
			if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
				continue
			var state: Variant = rec.get("state")
			var basis:= (r ["basis"] as Basis).orthonormalized()
			rows.append({
				"kind": kind,
				"strands": int(rec ["strands"]),
				"needle": int(rec ["needle"]),
				"state": state if state is Dictionary else { },
				"s": float(r ["s"]),
				"from": float(r ["from"]),
				"sink": float(r ["sink"]),
				"basis": basis,
				"xform": Transform3D(basis, r ["at"]),
			})
		if not rows.is_empty():
			out.append({ "at": lift.global_position, "rows": rows })
	return out


static func rows_from_array(entries: Array, props: PropManager) -> Dictionary:
	var lifts: Array [HayLift] = []
	var tree:= Engine.get_main_loop() as SceneTree
	if tree != null:
		for n in tree.get_nodes_in_group("hay_lifts"):
			var lift:= n as HayLift
			if lift != null and lift.is_inside_tree():
				lifts.append(lift)
	var boarded:= 0
	var bodied:= 0
	var lost:= 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var at: Vector3 = d.get("at", Vector3.INF)
		var lift: HayLift = null
		for l in lifts:
			if l.global_position.distance_to(at) <= BeltPath.SAVE_END_SLACK:
				lift = l
				break
		for row in d.get("rows", []):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			if lift != null and lift.restore_row(row):
				boarded += 1
			elif _body_for(row, props):
				bodied += 1
			else:
				lost += 1
	return { "boarded": boarded, "bodied": bodied, "lost": lost }


static func _body_for(row: Dictionary, props: PropManager) -> bool:
	if props == null or not (row.get("xform") is Transform3D):
		return false
	var kind:= int(row.get("kind", -1))
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size():
		return false
	var state: Variant = row.get("state", { })
	return props.spawn(BeltRun.ITEM_IDS [kind], row ["xform"],
		state if state is Dictionary else { }) != null


func restore_row(row: Dictionary) -> bool:
	var kind:= int(row.get("kind", -1))
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size() or _line.size() < 2:
		return false
	var state: Variant = row.get("state", { })
	var rec:= {
		"kind": kind, "strands": int(row.get("strands", 0)),
		"needle": int(row.get("needle", -1)),
		"state": state if state is Dictionary else { }, "seq": -1,
		"s": 0.0, "side": 0.0, "lift": 0.0, "reach": 0.0, "speed": 0.0,
	}
	var s:= clampf(float(row.get("s", 0.0)), 0.0, total_length())
	var basis: Variant = row.get("basis")
	_take_record(rec, { "s": s, "sink": float(row.get("sink", 0.0)) },
		(basis as Basis).orthonormalized() if basis is Basis else global_basis,
		clampf(float(row.get("from", s)), 0.0, total_length()), true)
	return true


func total_length() -> float:
	return _cum [_cum.size() - 1] if _cum.size() > 0 else 0.0


func _point_at(s: float) -> Vector3:
	if _line.size() < 2:
		return global_position

	if s < 0.0:
		return _line [0] + (_line [1] - _line [0]).normalized() * s
	var total:= total_length()
	var d:= clampf(s, 0.0, total)
	for i in range(_line.size() - 1):
		if d <= _cum [i + 1] or i == _line.size() - 2:
			var span: float = _cum [i + 1] - _cum [i]
			var t: float = 0.0 if span <= 1e-06 else (d - _cum [i]) / span
			return _line [i].lerp(_line [i + 1], clampf(t, 0.0, 1.0))
	return _line [_line.size() - 1]


func _ride_point(s: float, sink: float, centre: float, up: Vector3,
		from:= 0.0) -> Vector3:
	var fade:= _sink_fade(s, from)
	return _point_at(s) - global_basis.y * (sink * fade) - up.normalized() * (centre * (1.0 - fade))


func _sink_fade(s: float, from:= 0.0) -> float:
	if s <= from:
		return 1.0
	var close:= minf(maxf(_sink_in, from + NIP_CLOSE_MIN), _sink_out)
	if s < close:
		return 1.0 - (s - from) / (close - from)
	if s <= _sink_out:
		return 0.0
	var span:= maxf(total_length() - _sink_out, 0.0001)
	return clampf((s - _sink_out) / span, 0.0, 1.0)


func _seg_at(s: float) -> int:
	var d:= clampf(s, 0.0, total_length())
	for i in range(_line.size() - 1):
		if d <= _cum [i + 1]:
			return i
	return maxi(0, _line.size() - 2)


func _nearest(p: Vector3) -> Dictionary:
	var best_d2:= INF
	var out:= { "s": 0.0, "sink": 0.0 }
	for i in range(_line.size() - 1):
		var a:= _line [i]
		var ab:= _line [i + 1] - a
		var len2:= ab.length_squared()
		if len2 < 1e-08:
			continue


		var t:= clampf((p - a).dot(ab) / len2, - INF if i == 0 else 0.0, 1.0)
		var on:= a + ab * t
		var d2:= p.distance_squared_to(on)
		if d2 >= best_d2:
			continue
		best_d2 = d2
		out ["s"] = _cum [i] + sqrt(len2) * t
		out ["sink"] = maxf(on.y - p.y, 0.0)
	return out


func _marker(node_name: String, fallback: Vector3) -> Vector3:
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
	if _proto != null and _proto.get_parent() == null:
		if _proto is MeshInstance3D:
			out.append(_proto as MeshInstance3D)
		for n in _proto.find_children("*", "MeshInstance3D", true, false):
			out.append(n as MeshInstance3D)
	return out


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func set_sections(n: int) -> void:
	var want:= clampi(n, 0, Cfg.HAY_LIFT_SECTIONS_MAX)
	if _model == null or want == sections:
		return
	sections = want
	_restack()


func set_riser(r: float) -> void:
	var want:= SPACER if r > 0.0 else 0.0
	if want == riser:
		return
	riser = want
	if _model != null:
		_restack()


func _restack() -> void:
	if _model == null or _proto == null:
		return
	while _sections.size() > sections:
		var extra: Node3D = _sections.pop_back()
		if extra.get_parent() != null:
			extra.get_parent().remove_child(extra)


		if extra != _proto:
			extra.queue_free()
	while _sections.size() < sections:
		var k:= _sections.size()


		var part: Node3D = _proto if k == 0 else _proto.duplicate() as Node3D
		part.name = "Lift_section_%d" % k
		_model.add_child(part)
		_sections.append(part)
	for k in _sections.size():
		(_sections [k] as Node3D).position = Vector3(0.0,
			MODEL_DECK + BOOT_FLANGE + Cfg.HAY_LIFT_SECTION * float(k), 0.0)
	var top:= MODEL_DECK + BOOT_FLANGE + Cfg.HAY_LIFT_SECTION * float(sections)
	if _spacer != null:
		if riser > 0.0:
			_spacer.visible = true
			_spacer.position = Vector3(0.0, top, 0.0)
		elif placement_preview:


			_spacer.visible = false
		else:


			_spacer.get_parent().remove_child(_spacer)
			_spacer.queue_free()
			_spacer = null
	if _head != null:


		_head.position = Vector3(0.0, top + riser, 0.0)


func to_dict() -> Dictionary:
	return {
		"type": "hay_lift",
		"position": global_position,
		"yaw": global_rotation.y,
		"sections": sections,
		"riser": riser,


		"port_reach": port_reach.duplicate(),
	}
