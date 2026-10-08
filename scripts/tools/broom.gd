class_name Broom
extends Node3D


const MODEL_PATH:= "res://assets/models/broom.glb"


const HEAD_W:= 0.59
const HEAD_D:= 0.111


const HANDLE_LEN:= 1.503


const HEAD_CLEAR:= 0.025
const HEAD_FORWARD:= 1.02
const HEAD_SIDE:= 0.15


const HAND_SIDE:= 0.3
const HAND_FORWARD:= 0.55
const HAND_BELOW_EYE:= 0.3


const HAND_COUNTER:= 0.09

const STROKE_TIME:= 0.4


const WINDUP_TIME:= 0.16
const RETURN_TIME:= 0.22


const CARRY_LIFT:= 0.09


const RUN_LIFT:= 0.1
const RUN_SWAY:= 0.07
const RUN_BOUNCE:= 0.03
const RUN_HAND_HEAVE:= 0.015
const RUN_BLEND:= 7.0


const REST_POSE:= Vector4(HEAD_SIDE, HEAD_FORWARD, 0.0, 0.0)


const SWING:= 0.46

const PUSH_OUT:= 0.16


const WORK_FROM:= 0.12
const WORK_TO:= 0.92


const SWEEP_SPEED:= 6.6


const FORWARD_BIAS:= 0.62


const UP_KICK:= 0.85


const GATHER:= 1.6


const REACH_H:= 0.42


const PILE_IGNORE_H:= 0.1


const PILE_SURFACE_TOL:= LiveStrandManager.BURIED_DEPTH


const LOAD_SWEEP_SCALE:= 0.8


const LOAD_HEFT_MIN:= 0.6


const LOAD_UP_KICK:= 0.12


const MERGE_WATCH:= 1.5


const MERGE_TOUCH:= 1.25


const MERGE_RISE:= 0.3


const MAX_PER_STROKE:= 320

var player: Player
var field: HayField
var live: LiveStrandManager
var world_root: Node3D

var visual: Node3D
var sweep_area: Area3D


var _sweep_shape: BoxShape3D
var _sweep_cs: CollisionShape3D
var _shape_scale:= -1.0

var _active:= false


var _cycle:= -1.0

var _run_w:= 1.0


var _from:= REST_POSE


var _dir:= 1.0

var _swept: Dictionary = { }
var _rustled:= false
var _prev_head:= Vector3.ZERO
var _have_prev:= false

var _holding:= false


var poll_button:= true


var _merge_until: Dictionary = { }
var _clock:= 0.0


var merged_count:= 0
var stroke_count:= 0


func setup(p_world: Node3D, p_field: HayField, p_live: LiveStrandManager) -> void:
	world_root = p_world
	field = p_field
	live = p_live
	_build_body()
	set_active(false)


func _build_body() -> void:


	sweep_area = Area3D.new()
	sweep_area.name = "BroomSweepZone"
	sweep_area.top_level = true
	sweep_area.collision_layer = 0


	sweep_area.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	sweep_area.monitorable = false
	_sweep_cs = CollisionShape3D.new()
	_sweep_shape = BoxShape3D.new()
	_sweep_cs.shape = _sweep_shape
	_fit_sweep_shape()
	sweep_area.add_child(_sweep_cs)
	world_root.add_child(sweep_area)

	_mount_mesh()
	sweep_area.global_transform = _sweep_transform(_held_transform())


func _fit_sweep_shape() -> void:
	var k:= _reach_scale()
	if _sweep_shape == null or is_equal_approx(k, _shape_scale):
		return
	_shape_scale = k
	var deep:= 1.0 + (k - 1.0) * 0.5
	_sweep_shape.size = Vector3(HEAD_W * 1.25 * k, REACH_H * 1.6, HEAD_D * 5.4 * deep)
	_sweep_cs.position = Vector3(0.0, REACH_H * 0.45,
		HEAD_D * 0.9 - HEAD_D * 5.4 * (deep - 1.0) * 0.5)


func _sweep_transform(head: Transform3D) -> Transform3D:
	if player == null:
		return head
	var fwd:= - player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return head
	return Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), head.origin)


static func _reach_scale() -> float:
	return Tech.broom_reach_scale()


static func sweep_width() -> float:
	return SWING * 2.0 + HEAD_W * _reach_scale()


func _mount_mesh() -> void:
	visual = Node3D.new()
	visual.name = "BroomVisual"
	add_child(visual)

	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("Broom: could not load %s" % MODEL_PATH)
		return
	var inst: Node3D = packed.instantiate()
	_ground_materials(inst)
	visual.add_child(inst)
	_update_visual_pose(0.0)


func _ground_materials(inst: Node3D) -> void:
	var meshes:= inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)
	for child in meshes:
		var mi:= child as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(s)
			if src is not StandardMaterial3D:
				continue
			var m:= (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.metallic = minf(m.metallic, 0.2)
			m.roughness = maxf(m.roughness, 0.62)
			mi.set_surface_override_material(s, m)


func set_active(on: bool) -> void:
	_active = on
	if sweep_area == null:
		return
	if visual != null:
		visual.visible = on
	sweep_area.monitoring = on
	_cycle = -1.0
	_from = REST_POSE
	_have_prev = false
	_holding = false
	if on:
		_update_visual_pose(0.0)
		sweep_area.global_transform = _sweep_transform(_held_transform())


func sweep() -> void:
	if not _active or is_sweeping() or (_cycle >= 0.0 and _cycle < WINDUP_TIME):
		return

	_from = _cycle_pose(_cycle)
	_begin_stroke(0.0)


func set_held(on: bool) -> void:
	_holding = on and _active


func is_held_down() -> bool:
	return _holding


func _begin_stroke(at: float) -> void:
	stroke_count += 1
	_cycle = at
	_swept.clear()
	_rustled = false
	_dir = - _dir


	Audio.play_3d("broom_sweep", head_position(), -7.0)


func is_active() -> bool:
	return _active


func _wad_ref_mass() -> float:
	return clampf(float(Cfg.WAD_BASE_STRANDS) * Cfg.WAD_MASS_PER_STRAND,
		Cfg.WAD_MASS_MIN, Cfg.WAD_MASS_MAX)


func is_sweeping() -> bool:
	var p:= _cycle - WINDUP_TIME
	return _cycle >= 0.0 and p >= 0.0 and p < STROKE_TIME


func is_stroking() -> bool:
	return _cycle >= 0.0


func head_position() -> Vector3:
	return _held_transform().origin


func swept_count() -> int:
	return _swept.size()


func _swing_pose(p: float) -> Vector4:
	var s:= lerpf(1.0, -1.0, smoothstep(0.0, 1.0, p)) * _dir
	return Vector4(
		s * SWING,
		HEAD_FORWARD + PUSH_OUT * sin(PI * p),


		0.035 * (1.0 - sin(PI * p)),
		s)


func _carry(a: Vector4, b: Vector4, k: float) -> Vector4:
	var pose:= a.lerp(b, k)
	pose.z += CARRY_LIFT * sin(PI * k)
	return pose


func _cycle_pose(t: float) -> Vector4:
	if t < 0.0:
		return REST_POSE
	if t < WINDUP_TIME:
		return _carry(_from, _swing_pose(0.0), smoothstep(0.0, 1.0, t / WINDUP_TIME))
	var st:= t - WINDUP_TIME
	if st < STROKE_TIME:
		return _swing_pose(st / STROKE_TIME)
	var k:= clampf((st - STROKE_TIME) / RETURN_TIME, 0.0, 1.0)
	return _carry(_swing_pose(1.0), REST_POSE, smoothstep(0.0, 1.0, k))


func _local_pose(t: float) -> Transform3D:
	var q:= _cycle_pose(t)
	var across:= q.x
	var out:= q.y
	var s:= q.w

	var head:= Vector3(across, HEAD_CLEAR + q.z, - out)
	var eye:= player.head.position.y if player != null else Player.EYE_HEIGHT
	var hand:= Vector3(HAND_SIDE - s * HAND_COUNTER, eye - HAND_BELOW_EYE,
		- HAND_FORWARD)


	if player != null and _run_w > 0.0:
		var amp:= player.stride() * _run_w
		var side:= sin(player.stride_phase() * 0.5)
		var bounce:= side * side * 2.0 - 1.0
		head += Vector3(side * RUN_SWAY, RUN_LIFT + bounce * RUN_BOUNCE, 0.0) * amp
		hand.y += bounce * RUN_HAND_HEAVE * amp


	var up:= (hand - head).normalized()
	var right:= up.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	return Transform3D(Basis(right, up, right.cross(up)), head)


func _update_visual_pose(t: float) -> void:
	if visual != null:
		var lag:= player.eye_lag() if player != null else Vector3.ZERO
		visual.transform = Transform3D(Basis.IDENTITY,
			global_transform.basis.inverse() * lag) * _local_pose(t)


func _held_transform() -> Transform3D:
	return global_transform * _local_pose(_cycle)


func _process(delta: float) -> void:
	if not _active:
		return
	if _holding and poll_button and (not Input.is_action_pressed("primary")
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		_holding = false
	_run_w = move_toward(_run_w, 0.0 if _cycle >= 0.0 else 1.0, delta * RUN_BLEND)
	if _cycle >= 0.0:
		_cycle += delta
		var swing_end:= WINDUP_TIME + STROKE_TIME
		if _holding and _cycle >= swing_end:


			_begin_stroke(WINDUP_TIME + minf(_cycle - swing_end, STROKE_TIME * 0.5))
		elif _cycle >= swing_end + RETURN_TIME:

			_cycle = -1.0
	_update_visual_pose(_cycle)


func _physics_process(delta: float) -> void:
	_clock += delta


	if not _merge_until.is_empty():
		_merge_pass()
	if not _active or sweep_area == null or player == null:
		return
	_fit_sweep_shape()
	var xf:= _held_transform()
	sweep_area.global_transform = _sweep_transform(xf)
	if is_sweeping():
		_do_sweep(xf, delta)
	_prev_head = xf.origin
	_have_prev = true


func _do_sweep(xf: Transform3D, delta: float) -> void:
	if field == null:
		return

	var feet:= player.global_position
	if field.height_at(feet.x, feet.z) > PILE_IGNORE_H:
		return
	var p:= (_cycle - WINDUP_TIME) / STROKE_TIME
	if p < WORK_FROM or p > WORK_TO or not _have_prev or delta <= 0.0:
		return
	if _swept.size() >= MAX_PER_STROKE:
		return


	var travel:= (xf.origin - _prev_head) / delta
	travel.y = 0.0
	var forward:= - player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var push:= forward * FORWARD_BIAS
	if travel.length() > 0.05:
		push += travel.normalized() * (1.0 - FORWARD_BIAS)
	if push.length() < 0.001:
		return
	push = push.normalized()


	var power: float = sin(PI * clampf(inverse_lerp(WORK_FROM, WORK_TO, p), 0.0, 1.0))
	var speed:= SWEEP_SPEED * power
	var head_y:= xf.origin.y
	var centre:= xf.origin


	var side:= sweep_area.global_transform.basis.x.normalized()
	var moved:= 0


	if live != null:
		live.wake_in(centre, HEAD_W * 0.7 * _reach_scale())

	for b in sweep_area.get_overlapping_bodies():
		if b is not RigidBody3D:
			continue
		var rb:= b as RigidBody3D
		var item:= rb as Carryable


		if item == null:
			if not (rb.collision_layer & Cfg.L_STRAND):
				continue
		elif item.hay_strands() <= 0:
			continue


		if item != null and (item.freeze or item.is_held()
				or item.has_meta(PropManager.META_CLAIM) or BeltPath.is_rider(item)):
			continue


		if not rb.is_inside_tree():
			continue
		var pos:= rb.global_position

		if pos.y - head_y > REACH_H or pos.y - head_y < - REACH_H:
			continue


		var surf:= field.height_at(pos.x, pos.z)
		if surf > PILE_IGNORE_H and pos.y > surf - PILE_SURFACE_TOL:
			continue


		var heft:= 1.0
		var kick:= UP_KICK
		if item != null:
			heft = LOAD_SWEEP_SCALE * clampf(_wad_ref_mass() / maxf(item.mass, 0.01),
				LOAD_HEFT_MIN, 1.0)
			kick = LOAD_UP_KICK
			if item is HayTuft:
				_merge_until [item.get_instance_id()] = _clock + MERGE_WATCH

		var offset:= (pos - centre).dot(side)
		var gather:= - side * clampf(offset, -1.0, 1.0) * GATHER * power * heft
		rb.linear_velocity = push * speed * heft + gather + Vector3.UP * kick * power
		rb.sleeping = false
		moved += 1
		_swept [rb.get_instance_id()] = true
		if _swept.size() >= MAX_PER_STROKE:
			break


	if moved > 0 and not _rustled:
		_rustled = true
		Audio.play_3d("hay_rustle", xf.origin, -5.0)


func _merge_pass() -> void:
	var props: PropManager = live.props if live != null else null
	if props == null:
		_merge_until.clear()
		return
	for id in _merge_until.keys():
		var t:= instance_from_id(id) as HayTuft
		if t == null or _clock > float(_merge_until [id]) or not _may_pour(t):
			_merge_until.erase(id)
			continue
		var into:= _tuft_touching(t)
		if into == null:
			continue
		var from:= t
		if into.strands < t.strands:
			from = into
			into = t
		var took:= into.add_strands(from.strands)
		if took <= 0:
			continue
		merged_count += 1

		_merge_until [into.get_instance_id()] = maxf(
			float(_merge_until.get(into.get_instance_id(), 0.0)), _clock + MERGE_WATCH * 0.5)
		if took >= from.strands:
			_merge_until.erase(from.get_instance_id())
			props.remove(from)
		else:
			from.set_strands(from.strands - took)


func _tuft_touching(t: HayTuft) -> HayTuft:
	var at:= t.global_position
	var best: HayTuft = null
	var best_d:= INF
	for other in HayTuft.all:
		if other == t or not is_instance_valid(other) or not _may_pour(other):
			continue
		var p:= other.global_position
		if absf(p.y - at.y) > MERGE_RISE:
			continue
		var d:= Vector2(p.x - at.x, p.z - at.z).length()
		if d > (t.reach() + other.reach()) * MERGE_TOUCH or d >= best_d:
			continue

		var bigger:= other if other.strands >= t.strands else t
		if bigger.strands >= Cfg.TUFT_MAX:
			continue
		best = other
		best_d = d
	return best


func _may_pour(t: HayTuft) -> bool:
	return t.is_inside_tree() and not t.is_held() and not t.freeze and not t.has_meta(PropManager.META_CLAIM) and not BeltPath.is_rider(t) and t.needle_index < 0
