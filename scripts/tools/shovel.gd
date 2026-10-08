class_name Shovel
extends Node3D


const SPADE_PATH:= "res://assets/downloaded/models/rusted_spade_01/rusted_spade_01_1k.gltf"
const SPADE_BLADE_Y0:= -0.5032
const SPADE_BLADE_Y1:= -0.22
const SPADE_TOP_Y:= 0.5977

const BLADE_W:= 0.168
const BLADE_D:= 0.283
const WALL_H:= 0.055
const PLATE_T:= 0.014
const SHAFT_LEN:= 0.74
const MASS:= 2.4


const LOAD_SLOT_PITCH:= 0.035
const LOAD_SLOTS_MIN:= 3


const LOAD_SLOTS_MAX:= 7


const LOAD_BITES:= 3


const LOAD_LAYER:= 0.016


const LOAD_SPREAD:= 0.82


const LOAD_CLEAR:= 0.03


const LOAD_ROOF:= LOAD_LAYER


const REST_FORWARD:= 0.78
const REST_DOWN:= 0.3


const RUN_SWAY:= 0.035
const RUN_HEAVE:= 0.012
const RUN_NOD:= 0.02
const RUN_BANK:= 0.06
const RUN_TUCK_DOWN:= 0.04
const RUN_TUCK_BACK:= 0.03


const CARRY_GRIP:= 0.84


const CARRY_VERTICAL_GRIP:= 0.72


const CARRY_UP_FULL:= 0.78
const CARRY_UP_NONE:= 0.35


const TIP_POUR:= 0.6


const HOLD_MARGIN:= 0.06


const POUR_SPEED:= 2.2


const POUR_SPEED_FLOOR:= 0.25


const POUR_LIFT:= 0.35


const POUR_FRICTION:= 0.02


const DUMP_LEVEL:= 0.45
const DUMP_STRANDS:= 4
const SHIFT_STRANDS:= 2


const GRIP_SPRINT_SCALE:= 0.72
const GRIP_CROUCH_SCALE:= 1.18


const SHED_SPRINT_RATE:= 0.2


const SHED_JUMP_FRACTION:= 0.2


const BLIND_MASK:= Cfg.L_STRAND | Cfg.L_TOOL


const LET_GO_TIME:= 0.55


const META_LET_GO:= &"tool_let_go"


const LET_GO_GRACE:= 6.0


const SHED_SPEED:= 0.9


const DUMP_SPEED:= 2.6


const DUMP_LIFT:= 0.3


const DUMP_SPREAD:= 0.22


const SPILL_SPEED:= DUMP_SPEED * 0.62


const DUMP_POUR_RANGE:= 2.4


const POUR_FLIGHT:= 0.4


const POUR_SCATTER:= 0.22


const POUR_INSET:= 0.45


const FULL_BADGE_GAP:= 2.6


const SIMPLE_FLOOR:= PLATE_T
const SIMPLE_ROOF:= WALL_H * 1.6


const HEAP_SPREAD:= 1.0


const HEAP_ROUND:= 0.85

const HEAP_HEIGHT:= 0.75


const HEAP_CORE:= 0.55


const HEAP_DEPTH_JITTER:= 0.12


const HEAP_LIFT:= 0.26


const RIDE_SETTLE:= 0.14


const GATHER_REACH:= 2.4


const BARE_HAY:= 0.03


const SWEEP_HEIGHT:= 0.12


const FLIGHT_PER_M:= 0.13
const FLIGHT_MIN:= 0.13
const FLIGHT_MAX:= 0.34


const FLIGHT_JITTER:= 0.22


const THROW_ARC:= 0.16


const EASE_POWER:= 3.0


const CATCH_SPIN_KEEP:= 0.3


const FLIGHT_CLAIM:= 0.9


const SAMPLES_X:= 5
const SAMPLES_Z:= 4

var player: Player
var field: HayField
var live: LiveStrandManager
var world_root: Node3D


var props: PropManager

var body: AnimatableBody3D
var visual: Node3D
var basin: Area3D


var _basin_shape: CollisionShape3D


var _pour_mat: PhysicsMaterial
var _pouring:= false

var _active:= false
var _aim_yaw:= 0.0
var _aim_pitch:= 0.0
var _carried:= 0
var _prev_carried:= 0
var _prev_blade_xform:= Transform3D()
var _have_prev:= false


var _load_held:= false


const EMPTY_LOAD:= -1000.0
var _load_top:= EMPTY_LOAD


var _riding: Dictionary = { }


const GROUP:= "blades"


func _enter_tree() -> void:
	add_to_group(GROUP)


func carries(rb: RigidBody3D) -> bool:
	var id:= rb.get_instance_id()
	return _riding.has(id) and not _let_go.has(id)


var _let_go: Dictionary = { }


var _passing: Dictionary = { }


var _ride_local: Dictionary = { }


var _ride_from: Dictionary = { }


var _ride_count:= 0


var _shed_debt:= 0.0


var _seen_jumps:= -1


var _shed_said:= 0


var dumps:= 0

var _badge_gap:= 0.0


var _was_full:= false


var _in_flight: Dictionary = { }


var flown_ticks:= 0


var vfx: ScoopVfx


var _swing: DigSwing = DigSwing.spade()


var _toss: DigSwing = DigSwing.toss()


const SWING_GRIP:= Vector3(0.06, -0.3, -0.55)


const SWING_TIP_MARGIN:= 0.03
var _sample_offsets: PackedVector3Array = PackedVector3Array()
var _rng:= RandomNumberGenerator.new()


func setup(p_world: Node3D, p_field: HayField, p_live: LiveStrandManager,
		p_props: PropManager = null) -> void:
	world_root = p_world
	props = p_props
	field = p_field
	live = p_live
	_rng.randomize()
	_build_samples()
	_build_body()
	_build_vfx()
	set_active(false)


func _build_vfx() -> void:
	if world_root == null:
		return
	vfx = ScoopVfx.new()
	vfx.name = "%sChaff" % name
	world_root.add_child(vfx)


func _build_samples() -> void:
	for j in SAMPLES_Z:
		for i in SAMPLES_X:
			var x:= lerpf(- BLADE_W * 0.46, BLADE_W * 0.46, float(i) / float(SAMPLES_X - 1))
			var z:= lerpf(- BLADE_D * 0.48, BLADE_D * 0.46, float(j) / float(SAMPLES_Z - 1))
			_sample_offsets.append(Vector3(x, 0.0, z))


func _build_body() -> void:


	body = AnimatableBody3D.new()
	body.name = "ShovelCollider"
	body.sync_to_physics = false
	body.collision_layer = Cfg.L_TOOL


	body.collision_mask = Cfg.L_WORLD | Cfg.L_STRAND | Cfg.L_BUILD

	_build_collider()
	_pour_mat = PhysicsMaterial.new()
	_pour_mat.friction = POUR_FRICTION
	_pour_mat.bounce = 0.0


	basin = Area3D.new()
	basin.name = "Basin"
	basin.collision_layer = 0


	basin.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	basin.monitorable = false


	_basin_shape = CollisionShape3D.new()
	var bshape:= BoxShape3D.new()
	bshape.size = Vector3(BLADE_W, WALL_H * 2.6, BLADE_D)
	_basin_shape.shape = bshape
	_basin_shape.position = Vector3(0, WALL_H * 1.2, 0)
	basin.add_child(_basin_shape)
	body.add_child(basin)

	world_root.add_child(body)
	_mount_spade_mesh()
	body.global_transform = _held_transform()


func _mount_spade_mesh() -> void:
	visual = Node3D.new()
	visual.name = "ShovelVisual"
	player.camera.add_child(visual)

	var packed: PackedScene = load(SPADE_PATH)
	if packed == null:
		push_error("Shovel: could not load %s" % SPADE_PATH)
		return
	var inst: Node3D = packed.instantiate()


	var b:= Basis(Vector3.BACK, PI) * Basis(Vector3.RIGHT, PI * 0.5)
	var blade_mid:= (SPADE_BLADE_Y0 + SPADE_BLADE_Y1) * 0.5
	inst.transform = Transform3D(b, - (b * Vector3(0.0, blade_mid, 0.0)))
	_ground_spade_materials(inst)
	visual.add_child(inst)
	_update_visual_pose()


func _ground_spade_materials(inst: Node3D) -> void:
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
			m.albedo_color = Color(0.78, 0.73, 0.66)
			m.metallic = 0.45
			m.roughness = 0.55
			mi.set_surface_override_material(s, m)


func _build_collider() -> void:
	var half_w:= BLADE_W * 0.5
	_shape_box(Vector3(BLADE_W, PLATE_T, BLADE_D), Vector3(0, 0, 0))
	_shape_box(Vector3(0.01, WALL_H, BLADE_D), Vector3(- half_w, WALL_H * 0.45, 0))
	_shape_box(Vector3(0.01, WALL_H, BLADE_D), Vector3(half_w, WALL_H * 0.45, 0))
	_shape_box(Vector3(BLADE_W, WALL_H * 1.1, 0.012), Vector3(0, WALL_H * 0.5, BLADE_D * 0.5))
	_shape_box(Vector3(0.034, 0.034, SHAFT_LEN),
		Vector3(0, WALL_H * 0.5, BLADE_D * 0.5 + SHAFT_LEN * 0.5))
	_shape_box(Vector3(0.132, 0.03, 0.06),
		Vector3(0, WALL_H * 0.5, BLADE_D * 0.5 + SHAFT_LEN))


func _shape_box(size: Vector3, pos: Vector3) -> void:
	var cs:= CollisionShape3D.new()
	var shape:= BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


func set_active(on: bool) -> void:
	_active = on
	if body == null:
		return
	if visual != null:
		visual.visible = on
	body.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	basin.monitoring = on
	if on:
		_update_visual_pose()
		body.global_transform = _held_transform()
		body.reset_physics_interpolation()
		_have_prev = false
	else:


		FullBadge.snuff_on(body)
		_release_all()

		_swing.stop()
		_toss.stop()


func aim_input(rel: Vector2) -> void:
	if Cfg.simple_tools():
		return
	_aim_yaw = clampf(_aim_yaw - rel.x * 0.004, -1.1, 1.1)
	_aim_pitch = clampf(_aim_pitch - rel.y * 0.004, -1.35, 1.0)


func reset_aim() -> void:
	_aim_yaw = 0.0
	_aim_pitch = 0.0


func carried_strands() -> int:
	return _carried


func flight_time(from: Vector3, to: Vector3) -> float:
	var t:= clampf(from.distance_to(to) * FLIGHT_PER_M, FLIGHT_MIN, FLIGHT_MAX)
	return maxf(FLIGHT_MIN * 0.5, t * (1.0 + _rng.randfn(0.0, FLIGHT_JITTER * 0.5)))


func _throw_strand(b: RigidBody3D, from: Vector3, to: Vector3,
		frame: Node3D = null) -> void:
	if b == null or not is_instance_valid(b):
		return


	b.remove_meta(META_LET_GO)
	LiveStrandManager.hold(b, FLIGHT_CLAIM)


	b.collision_mask &= ~ (Cfg.L_STRAND | Cfg.L_TOOL)
	var seconds:= flight_time(from, to)


	var rec:= [b, from, to, 0.0, seconds, null, Vector3.ZERO, frame]
	if frame != null and frame.is_inside_tree() and not DigSwing.off:
		rec [5] = frame
		rec [6] = frame.global_transform.orthonormalized().affine_inverse() * to
	_in_flight [b.get_instance_id()] = rec


	b.linear_velocity = ((to - from) + Vector3.UP * (4.0 * THROW_ARC)) * (EASE_POWER / seconds)


func _fly(xf: Transform3D, delta: float) -> void:
	if _in_flight.is_empty() or delta <= 0.0:
		return
	var landed: Array [int] = []
	for id: int in _in_flight:
		var rec: Array = _in_flight [id]
		var b: Variant = rec [0]
		if not is_instance_valid(b) or not (b as RigidBody3D).is_inside_tree():
			landed.append(id)
			continue
		var rb:= b as RigidBody3D
		var from: Vector3 = rec [1]
		var to: Vector3 = rec [2]
		var seconds: float = rec [4]


		var frame: Variant = rec [5]
		if frame != null and is_instance_valid(frame) and (frame as Node3D).is_inside_tree():
			to = (frame as Node3D).global_transform.orthonormalized() * (rec [6] as Vector3)
			rec [2] = to
		rec [3] = float(rec [3]) + delta
		var u:= clampf(float(rec [3]) / seconds, 0.0, 1.0)
		if u >= 1.0:


			rb.linear_velocity = _pan_velocity(xf, to, delta)
			rb.angular_velocity *= CATCH_SPIN_KEEP
			if Cfg.simple_tools():


				LiveStrandManager.unpin(rb)
				if rb is HayWad:


					_land(rb)
				else:
					live.set_protected(rb, true)
				_catch(rec, id, rb)
				landed.append(id)
				continue


			rb.collision_mask |= Cfg.L_TOOL | Cfg.L_STRAND
			LiveStrandManager.unpin(rb)


			if rb is not HayWad:
				live.set_protected(rb, true)
			_catch(rec, id, rb)
			landed.append(id)
			continue


		var e:= 1.0 - pow(1.0 - u, EASE_POWER)
		var want:= from.lerp(to, e) + Vector3.UP * (THROW_ARC * 4.0 * e * (1.0 - e))
		rb.linear_velocity = (want - rb.global_position) / delta - HayHold.gravity_on(rb) * delta
		rb.sleeping = false

		LiveStrandManager.hold(rb, FLIGHT_CLAIM)
		flown_ticks += 1
	for id: int in landed:
		_in_flight.erase(id)


func _catch(rec: Array, id: int, rb: RigidBody3D) -> void:
	var to: Variant = rec [7] if rec.size() > 7 else null
	if to != null and is_instance_valid(to) and to != body and (to as Object).has_method("take_landed"):
		(to as Object).call("take_landed", rb)
		return
	_riding [id] = rb


func _pan_velocity(xf: Transform3D, at: Vector3, delta: float) -> Vector3:
	if not _have_prev or delta <= 0.0:
		return Vector3.ZERO
	var moved:= xf * _prev_blade_xform.affine_inverse()
	return (moved * at - at) / delta


func _land(b: Variant) -> void:
	if b is RigidBody3D and is_instance_valid(b):
		(b as RigidBody3D).collision_mask |= Cfg.L_STRAND | Cfg.L_TOOL


static func weld_local(rb: RigidBody3D, xf: Transform3D,
		local: Transform3D) -> void:
	if not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	rb.global_transform = xf.orthonormalized() * local
	LiveStrandManager.hold(rb)


static func ride_pose(settling: Dictionary, id: int, target: Transform3D,
		delta: float) -> Transform3D:
	if not settling.has(id):
		return target
	var rec: Array = settling [id]
	rec [1] = float(rec [1]) + delta
	var u:= clampf(float(rec [1]) / RIDE_SETTLE, 0.0, 1.0)
	if u >= 1.0:
		settling.erase(id)
		return target
	return (rec [0] as Transform3D).interpolate_with(target, 1.0 - pow(1.0 - u, 3.0))


static func lay_in_pan(rb: RigidBody3D, local: Transform3D, mid: Vector3,
		half_w: float, half_d: float, floor_y: float, roof_y: float,
		index: int, capacity: int) -> Transform3D:
	if rb is HayWad or not rb.has_meta(LiveStrandManager.META_LEN):
		local.origin = Vector3(
			clampf(local.origin.x, mid.x - half_w, mid.x + half_w),
			clampf(local.origin.y, floor_y, maxf(floor_y, roof_y)),
			clampf(local.origin.z, mid.z - half_d, mid.z + half_d))
		return local
	var length:= Cfg.STRAND_LENGTH * float(rb.get_meta(LiveStrandManager.META_LEN, 1.0))
	var big:= maxf(half_w, half_d)
	var a:= maxf(half_w, big * HEAP_ROUND) * HEAP_SPREAD
	var b:= maxf(half_d, big * HEAP_ROUND) * HEAP_SPREAD
	var h:= (a + b) * 0.5 * HEAP_HEIGHT


	var k:= float(index)
	var fill:= clampf((k + 0.5) / float(maxi(capacity, 1)), 0.0, 1.0)
	var shell:= lerpf(HEAP_CORE, 1.0, pow(fill, 1.0 / 3.0)) * (1.0 + (fposmod(k * 0.5698403, 1.0) - 0.5) * HEAP_DEPTH_JITTER)
	var up:= lerpf(0.08, 1.0, fposmod(k * 0.7548777, 1.0))
	var ang:= k * 2.3999632
	var ring:= sqrt(1.0 - up * up)
	var n0:= Vector3(ring * cos(ang), up, ring * sin(ang))
	var at:= Vector3(mid.x + a * shell * n0.x, floor_y + h * shell * n0.y,
		mid.z + b * shell * n0.z)


	var normal:= Vector3(n0.x / a, n0.y / h, n0.z / b).normalized()
	var t1:= normal.cross(Vector3.UP)
	t1 = t1.normalized() if t1.length_squared() > 1e-06 else Vector3.RIGHT
	var t2:= normal.cross(t1).normalized()
	var psi:= float(rb.get_instance_id() % 1013) * 2.3999632
	var lift:= (fposmod(k * 0.3183099, 1.0) - 0.5) * 2.0 * HEAP_LIFT
	var dir:= (t1 * cos(psi) + t2 * sin(psi)) * cos(lift) + normal * sin(lift)


	dir.y *= up
	dir = dir.normalized()
	at.y = maxf(at.y, floor_y + absf(dir.y) * length * 0.5)
	var side:= Vector3.UP.cross(dir)
	side = side.normalized() if side.length_squared() > 1e-06 else Vector3.RIGHT


	var spin:= float(rb.get_instance_id() % 997) * 2.39996
	local.basis = Basis(side, dir.cross(side).normalized(), dir).rotated(dir, spin)
	local.origin = at
	return local


func _pan_slot(xf: Transform3D, rb: RigidBody3D) -> Transform3D:
	var g:= pan_geometry()
	var local:= xf.orthonormalized().affine_inverse() * rb.global_transform
	var origin:= g ["origin"] as Vector3
	_ride_from [rb.get_instance_id()] = [local, 0.0]
	if _ride_local.is_empty():
		_ride_count = 0
	_ride_count += 1
	return lay_in_pan(rb, local, origin, float(g ["w"]) * 0.5, float(g ["d"]) * 0.5,
		load_base(origin), load_ceiling(origin), _ride_count - 1, capacity())


func _blind(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb):
		return
	if rb is not HayWad:
		rb.collision_mask &= ~ BLIND_MASK


	rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.freeze = true


func _unblind(b: Variant) -> void:
	if not is_instance_valid(b):
		return
	var rb:= b as RigidBody3D
	if rb == null:
		return


	rb.freeze = false
	rb.sleeping = false
	if rb is HayWad:
		return


	if live != null:
		live.land_apart(rb)
		live.set_protected(rb, false)
	else:
		_land(rb)


func _pass_through(rb: RigidBody3D) -> void:
	if rb is not HayWad or not is_instance_valid(rb) or body == null:
		return
	rb.add_collision_exception_with(body)
	_passing [rb.get_instance_id()] = rb


func _end_pass(b: Variant) -> void:
	if is_instance_valid(b) and b is RigidBody3D and body != null:
		(b as RigidBody3D).remove_collision_exception_with(body)


func _tick_passing() -> void:
	if _passing.is_empty():
		return
	var inside: Dictionary = { }
	for b in basin.get_overlapping_bodies():
		inside [b.get_instance_id()] = true
	for id: int in _passing.keys():
		var rb: Variant = _passing [id]
		if not is_instance_valid(rb):
			_passing.erase(id)
			continue

		if _let_go.has(id) or (inside.has(id) and not _riding.has(id)):
			continue
		_end_pass(rb)
		_passing.erase(id)


func _local_pose() -> Transform3D:
	return Transform3D(
		Basis.from_euler(Vector3(_aim_pitch, _aim_yaw, 0.0)),
		Vector3(0.0, - REST_DOWN, - REST_FORWARD))


func blade_scale() -> float:
	return Tech.spade_scale()


func size_node() -> String:
	return "shovel_size"


func _hold_centre() -> Vector3:
	if _basin_shape == null:
		return basin.global_position if basin != null else Vector3.ZERO
	return _basin_shape.global_position


func _hold_radius() -> float:
	var box:= _basin_shape.shape as BoxShape3D if _basin_shape != null else null
	if box == null:
		return BLADE_D * blade_scale()
	return Vector2(box.size.x, box.size.z).length() * 0.5 * blade_scale() + HOLD_MARGIN


func _update_visual_pose() -> void:
	if visual != null:
		visual.transform = _run_pose() * _swing_pose() * _local_pose()
		visual.scale = Vector3.ONE * blade_scale()


func _run_pose() -> Transform3D:
	if player == null:
		return Transform3D.IDENTITY
	var s:= player.stride()
	var swing:= player.stride_pose(RUN_SWAY, RUN_HEAVE, RUN_NOD, RUN_BANK)
	return Transform3D(swing.basis, swing.origin + Vector3(0.0, - RUN_TUCK_DOWN, RUN_TUCK_BACK) * s)


func _swing_pose() -> Transform3D:
	if not _swing.is_swinging():
		if _toss.is_swinging():
			return _toss.transform(swing_grip())
		return Transform3D.IDENTITY
	var floor_pitch:= - INF
	if _carried > 0 and not Cfg.simple_tools() and player != null and player.camera != null:
		var rest_up:= (player.camera.global_transform.basis
			* _local_pose().basis).y.normalized().dot(Vector3.UP)


		var room:= acos(clampf(TIP_POUR, -1.0, 1.0)) - acos(clampf(rest_up, -1.0, 1.0)) - SWING_TIP_MARGIN
		floor_pitch = - maxf(room, 0.0)
	var pose:= _swing.transform(swing_grip(), floor_pitch)
	if _toss.is_swinging():
		pose = pose * _toss.transform(swing_grip())
	return pose


func swing_grip() -> Vector3:
	return SWING_GRIP


func swing(strength: float) -> void:
	_swing.start(strength)


func _on_heave() -> void:
	if _carried <= 0:
		return
	if vfx != null:
		var xf:= _held_transform()
		vfx.shake_off(_hold_centre(), - xf.basis.z, mini(8, 2 + _carried / 8))
	Audio.play_3d("hay_shift", _hold_centre(), -20.0)


func _held_transform() -> Transform3D:
	if visual != null:
		return visual.global_transform
	return player.camera.global_transform * _local_pose()


func _process(delta: float) -> void:
	if _active:
		if _swing.tick(delta):
			_on_heave()
		_toss.tick(delta)
		_update_visual_pose()
		_draw_load_with_blade()


func _draw_load_with_blade() -> void:
	if not _load_held or not _have_prev or visual == null or live == null or _riding.is_empty():
		return
	live.draw_load_shifted(_riding, visual.global_transform.orthonormalized()
		* _prev_blade_xform.orthonormalized().affine_inverse())


func _physics_process(delta: float) -> void:
	if body == null or player == null:
		return
	if not _active:


		_fly(body.global_transform, delta)
		return


	var xf:= _held_transform()
	body.global_transform = xf


	if live != null and _have_prev and xf.origin.distance_squared_to(_prev_blade_xform.origin) > 1e-06:
		var g:= pan_geometry()
		live.wake_in((g ["xf"] as Transform3D) * (g ["origin"] as Vector3),
			maxf(float(g ["w"]), float(g ["d"])) * 0.75)
	_carry_load(xf, delta)


	_fly(xf, delta)
	_prev_blade_xform = xf
	_have_prev = true


func aim_point() -> Dictionary:
	if field == null or player == null or not _active:
		return { }
	return aim_from(player.eye_position(), player.look_direction(),
		get_world_3d().direct_space_state, field)


static func aim_from(from: Vector3, dir: Vector3,
		space: PhysicsDirectSpaceState3D, field: HayField = null,
		reach: float = Cfg.SCOOP_REACH) -> Dictionary:
	var to:= from + dir * reach
	var q:= PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Cfg.L_PILE
	q.collide_with_areas = false
	var hit:= space.intersect_ray(q)
	if not hit.is_empty():
		var at: Vector3 = hit ["position"]


		if field == null or field.height_at(at.x, at.z) > BARE_HAY:
			return { "position": at }


	q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_STRAND | Cfg.L_BUILD | Cfg.L_SETTLED
	q.collide_with_areas = false
	hit = space.intersect_ray(q)
	if hit.is_empty():
		return { }
	var floor_at: Vector3 = hit ["position"]


	if field != null and not (hit.get("collider") is RigidBody3D) and (field.count_in_radius(floor_at, Cfg.SCOOP_RADIUS) > 0
				or field.strands_under(floor_at, Cfg.CELL) >= 1.0):
		return { "position": Vector3(floor_at.x,
			field.height_at(floor_at.x, floor_at.z), floor_at.z) }
	return { "position": floor_at, "loose": true }


func scoop() -> int:
	if not _active or field == null or live == null:
		return 0


	var bite:= -1
	if Cfg.simple_tools():
		var left:= room_left()
		if is_full() or left <= 0:
			_say_full()
			return 0
		bite = left
	var aim:= aim_point()
	if aim.is_empty():


		return 0
	var g:= pan_geometry()
	var most:= int(g ["max"]) if bite < 0 else mini(int(g ["max"]), bite)
	var n:= 0


	if bool(aim.get("loose", false)):
		n = gather_at(aim ["position"], most, float(g ["radius"]),
			g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]), body)


		if n > 0:
			_swing.start(0.6)
	else:
		n = scoop_at(aim ["position"], most, float(g ["radius"]),
			g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]),
			String(g ["track"]), body)
		if n > 0:
			_swing.start(clampf(float(n) / float(Cfg.SCOOP_TARGET), 0.4, 1.0))
	return n


func dump() -> int:
	if not _active or _riding.is_empty():
		return 0


	var into:= pour_target()
	var room:= straw_room_ahead() if into == null else -1
	var kept:= 0
	var push:= dump_push()
	var sent:= 0
	for id: int in _riding.keys():
		var held: Variant = _riding [id]
		if not is_instance_valid(held):
			continue
		var rb:= held as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		if room >= 0 and _is_plain_straw(rb):
			if room == 0:
				kept += 1
				continue
			room -= 1


		_let_go [id] = [LET_GO_TIME, rb]
		_pass_through(rb)
		_riding.erase(id)
		_ride_local.erase(id)
		if into != null:
			lob_into(rb, into)
		else:
			push_strand(rb, push)
		sent += 1
	if sent > 0:
		dumps += 1


		Audio.play_3d("hay_dump", body.global_position, -12.0)
		_toss.start(1.0)
	if kept > 0:
		_say_no_room()


		if into == null and is_instance_valid(_room_taker) and _room_taker.has_method("refuse_straw"):
			_room_taker.call("refuse_straw")
	return sent


func straw_room_ahead() -> int:
	_room_taker = null
	if player == null or body == null or not body.is_inside_tree():
		return -1
	var eye:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(eye,
		eye + player.look_direction() * Cfg.SCOOP_REACH)
	q.collision_mask = Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_WORLD | Cfg.L_PILE
	q.collide_with_areas = false


	var skip: Array [RID] = []
	for held: Variant in _riding.values():
		if is_instance_valid(held) and held is HayWad:
			skip.append((held as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1
	var collider:= hit.get("collider") as Node
	var belt:= _belt_of(collider)
	if belt != null and belt.gathers_straw and BeltPath.straw_tufts_enabled:
		return belt.straw_room_at(hit ["position"])


	var taker:= LiveStrandManager.straw_taker_of(belt if belt != null else collider)
	if taker != null:
		_room_taker = taker
		return maxi(0, int(taker.call("straw_room")))
	return -1


var _room_taker: Node = null


static func _belt_of(node: Node) -> BeltPath:
	if node != null and node.has_meta(LiveStrandManager.META_RIDER):
		var carrier: Variant = node.get_meta(LiveStrandManager.META_RIDER)
		if is_instance_valid(carrier) and carrier is BeltPath:
			return carrier as BeltPath
	while node != null:
		if node is BeltPath:
			return node as BeltPath
		node = node.get_parent()
	return null


static func _is_plain_straw(rb: RigidBody3D) -> bool:
	return rb is not HayWad and rb.get_parent() is LiveStrandManager and not rb.has_meta("needle_index")


func _say_no_room() -> void:
	if body == null or not body.is_inside_tree():
		return
	FullBadge.flash_over(body, _badge_point(), FullBadge.NO_ROOM)
	Audio.play_3d("hay_shift", body.global_position, -18.0)


func push_strand(rb: RigidBody3D, push: Vector3) -> void:
	if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
		return


	rb.freeze = false


	mark_let_go(rb)


	LiveStrandManager.release_hold(rb)


	if live != null and rb is not HayWad:
		live.mark_poured(rb)
	var spread:= Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0),
		_rng.randfn(0.0, 1.0)) * push.length() * DUMP_SPREAD
	rb.linear_velocity += push + spread


	rb.angular_velocity += Vector3(_rng.randfn(0.0, 2.4), _rng.randfn(0.0, 2.4),
		_rng.randfn(0.0, 2.4))
	rb.sleeping = false


func pour_target() -> HayContainer:
	if player == null:
		return null
	var eye:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(eye,
		eye + player.look_direction() * DUMP_POUR_RANGE)
	q.collision_mask = Cfg.L_PROP | Cfg.L_BUILD | Cfg.L_WORLD
	q.collide_with_areas = false


	var own: Array [RID] = []
	for id: int in _riding:
		var rider: Variant = _riding [id]
		if is_instance_valid(rider) and rider is HayWad:
			own.append((rider as HayWad).get_rid())
	q.exclude = own
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c:= hit ["collider"] as HayContainer
	if c == null or not c.has_room():
		return null
	return c


func lob_into(rb: RigidBody3D, into: HayContainer) -> void:
	if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	rb.freeze = false


	var basis:= into.global_transform.basis.orthonormalized()
	var reach:= into.pour_reach() * POUR_SCATTER
	var to:= into.pour_point() - basis.y * (into.pour_reach() * POUR_INSET) + basis.x * (_rng.randfn(0.0, 1.0) * reach) + basis.z * (_rng.randfn(0.0, 1.0) * reach)
	var g:= HayHold.gravity_on(rb)


	var dt:= 1.0 / float(Engine.physics_ticks_per_second)
	var n:= maxf(1.0, roundf(POUR_FLIGHT / dt))
	var f:= clampf(1.0 - rb.linear_damp * dt, 0.0, 1.0)
	var s1:= n
	var s2:= n * (n + 1.0) * 0.5
	if f < 0.999999:
		s1 = f * (1.0 - pow(f, n)) / (1.0 - f)
		s2 = f * (n - s1) / (1.0 - f)
	rb.linear_velocity = (to - rb.global_position - g * dt * dt * s2) / (dt * s1)
	rb.angular_velocity = Vector3(_rng.randfn(0.0, 2.0), _rng.randfn(0.0, 2.0),
		_rng.randfn(0.0, 2.0))
	rb.sleeping = false


static func mark_let_go(rb: RigidBody3D, grace: float = LET_GO_GRACE) -> void:
	if is_instance_valid(rb):
		var until:= Time.get_ticks_msec() * 0.001 + grace
		rb.set_meta(META_LET_GO, maxf(until, float(rb.get_meta(META_LET_GO, 0.0))))


static func let_go_recently(rb: RigidBody3D) -> bool:
	return is_instance_valid(rb) and float(rb.get_meta(META_LET_GO, 0.0)) > Time.get_ticks_msec() * 0.001


func dump_push() -> Vector3:
	var dir:= player.look_direction() if player != null else Vector3.FORWARD
	return (dir + Vector3.UP * DUMP_LIFT).normalized() * DUMP_SPEED


func spill_push() -> Vector3:
	var dir:= player.look_direction() if player != null else Vector3.FORWARD
	return (dir + Vector3.UP * DUMP_LIFT).normalized() * SPILL_SPEED


func spill() -> int:
	if _riding.is_empty():
		return 0
	var push:= spill_push()
	var sent:= 0
	for id: int in _riding.keys():
		var held: Variant = _riding [id]
		if not is_instance_valid(held):
			continue
		var rb:= held as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		_let_go [id] = [LET_GO_TIME, rb]
		_pass_through(rb)
		_riding.erase(id)
		_ride_local.erase(id)
		push_strand(rb, push)
		sent += 1
	if sent > 0:


		Audio.play_3d("hay_dump", body.global_position, -18.0)
	return sent


func pan_geometry() -> Dictionary:
	var s:= blade_scale()
	return {
		"xf": body.global_transform.orthonormalized(),
		"origin": Vector3.ZERO,
		"w": BLADE_W * s,
		"d": BLADE_D * s,
		"max": Tech.scoop_max(Cfg.SCOOP_MAX, s),
		"radius": Cfg.SCOOP_RADIUS * s,
		"track": "",
	}


func needle_landing_now() -> Vector3:
	var g:= pan_geometry()
	return needle_landing(g ["xf"], g ["origin"], float(g ["w"]), float(g ["d"]))


func gather_at(center: Vector3, max_count: int, radius: float, xf: Transform3D,
		load_origin: Vector3 = Vector3.ZERO, blade_w: float = BLADE_W,
		blade_d: float = BLADE_D, frame: Node3D = null) -> int:
	if live == null or max_count <= 0:
		return 0


	var reach:= radius * GATHER_REACH

	live.wake_in(center, reach)
	var shape:= SphereShape3D.new()
	shape.radius = reach
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = Cfg.L_STRAND
	q.collide_with_areas = false
	var found:= get_world_3d().direct_space_state.intersect_shape(q, max_count * 2)

	var made:= 0
	for hit: Dictionary in found:
		if made >= max_count:
			break
		var rb:= hit.get("collider") as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		if rb.freeze or live.is_held_by_a_tool(rb):
			continue


		if rb.has_meta("needle_index"):
			continue


		var local:= Vector3(
			_rng.randf_range(-0.38, 0.38) * blade_w,
			WALL_H * 1.6 + _rng.randf() * 0.05,
			_rng.randf_range(-0.38, 0.38) * blade_d) + load_origin
		LiveStrandManager.unpin(rb)
		rb.angular_velocity = Vector3(
			_rng.randfn(0.0, 2.2), _rng.randfn(0.0, 2.2), _rng.randfn(0.0, 2.2))
		rb.sleeping = false


		live.set_ccd(rb, true)
		_throw_strand(rb, rb.global_position, xf * local, frame)
		made += 1


	var room:= max_count - made
	for wad: HayWad in _bundles_near(center, reach):
		if made > 0 and wad.strands > room:
			continue
		var above:= WALL_H * 1.6 + wad.clearance_size().y * 0.5
		wad.sleeping = false
		_throw_strand(wad, wad.global_position,
			xf * (load_origin + Vector3.UP * above), frame)
		room -= wad.strands
		made += 1


	made += _lift_needles(center, reach, needle_landing.bind(xf, load_origin,
		blade_w, blade_d), xf)
	if made == 0:
		return 0


	Audio.play_3d("hay_rustle", center, -9.0)
	return made


func _bundles_near(center: Vector3, reach: float) -> Array [HayWad]:
	var out: Array [HayWad] = []
	var shape:= SphereShape3D.new()
	shape.radius = reach
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = Cfg.L_PROP
	q.collide_with_areas = false
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var wad:= hit.get("collider") as HayWad
		if wad == null or not wad.is_inside_tree() or wad.freeze or wad.is_held():
			continue
		if BeltPath.is_rider(wad) or wad.has_meta(PropManager.META_CLAIM) or live.is_held_by_a_tool(wad) or let_go_recently(wad) or _in_flight.has(wad.get_instance_id()):
			continue
		out.append(wad)
	var nearer:= func(a: HayWad, b: HayWad) -> bool: return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center)
	out.sort_custom(nearer)
	return out


func bundle_under_aim() -> HayWad:
	if not _active:
		return null
	return bundle_at(aim_point(), float(pan_geometry() ["radius"]))


func bundle_at(aim: Dictionary, radius: float) -> HayWad:
	if live == null or not bool(aim.get("loose", false)):
		return null
	var near:= _bundles_near(aim ["position"], radius * GATHER_REACH)
	return null if near.is_empty() else near [0]


func scoop_at(center: Vector3, max_count: int, radius: float,
		xf: Transform3D, load_origin: Vector3 = Vector3.ZERO,
		blade_w: float = BLADE_W, blade_d: float = BLADE_D,
		track: String = "", frame: Node3D = null) -> int:
	if field == null or live == null:
		return 0


	var taken:= field.take_in_radius(center, radius, max_count)
	var n:= taken.size()
	GameState.remove_hay(float(n))
	field.carve_volume(center, radius, float(n) * Cfg.STRAND_VOLUME / Cfg.PACKING)


	var room:= max_count - n
	var reach:= maxf(radius, Cfg.CELL)
	var under:= field.strands_under(center, reach)
	if room > 0 and under > 0.0:
		var swept:= 0


		if under <= float(room) + 0.5:
			swept = int(round(field.sweep_under(center, reach, SWEEP_HEIGHT)))
		elif n == 0:


			swept = room
			field.carve_volume(center, reach, float(room) * Cfg.STRAND_VOLUME / Cfg.PACKING)
		if swept > 0:
			GameState.remove_hay(float(swept))
			for k in swept:
				var at:= center + Vector3(_rng.randf_range(- radius, radius), 0.02,
					_rng.randf_range(- radius, radius))
				taken.append({
					"transform": Transform3D(StrandFactory.random_strand_basis(_rng), at),
					"color": StrandFactory.random_tint(_rng),
				})
			n += swept
	if taken.is_empty():
		return 0


	var onto:= needle_landing.bind(xf, load_origin, blade_w, blade_d)
	var made:= 0


	var floor_y:= load_base(load_origin)
	var base_y:= clampf(maxf(floor_y, _load_top + LOAD_CLEAR),
		floor_y, load_ceiling(load_origin))
	var grid:= load_grid(blade_w, blade_d)
	var per_layer:= grid.x * grid.y
	var slot:= 0
	var top_y:= base_y
	for t: Dictionary in taken:
		var was:= t ["transform"] as Transform3D


		var layer:= slot / per_layer
		var cell:= slot % per_layer
		var stagger:= 0.5 if layer % 2 == 1 else 0.0
		var fx:= (float(cell % grid.x) + 0.5 + stagger) / float(grid.x)
		var fz:= (float(cell / grid.x) + 0.5) / float(grid.y)
		var jitter:= LOAD_LAYER * 0.4
		var y:= base_y + float(layer) * LOAD_LAYER
		var local:= Vector3(
			(fract_centred(fx) + _rng.randf_range(-0.06, 0.06)) * blade_w * LOAD_SPREAD,
			y,
			(fract_centred(fz) + _rng.randf_range(-0.06, 0.06)) * blade_d * LOAD_SPREAD) + Vector3(0.0, _rng.randf_range(- jitter, jitter), 0.0) + load_origin


		var b:= live.spawn(was.origin, was.basis, Vector3.ZERO, t ["color"])
		if b != null:
			_throw_strand(b, was.origin, xf * local, frame)
			made += 1
			top_y = maxf(top_y, y)
			slot += 1


	_load_top = maxf(_load_top, top_y)
	_lift_needles(center, radius, onto, xf)


	if vfx != null and made > 0:
		var strength:= float(made) / float(Cfg.SCOOP_TARGET)
		vfx.burst(center, xf * load_origin - center, strength)


		vfx.bite(center, radius, strength)


	Audio.play_3d("dig", xf.origin)
	Audio.play_3d("hay_rustle", center, -11.0)
	return made


static func fract_centred(f: float) -> float:
	return f - 0.5


func load_roof() -> float:
	var box:= _basin_shape.shape as BoxShape3D if _basin_shape != null else null
	if box == null:
		return WALL_H * 3.0
	return (_basin_shape.position.y + box.size.y * 0.5) * blade_scale() + LOAD_ROOF


func load_base(load_origin: Vector3) -> float:
	if Cfg.simple_tools():
		return load_origin.y + SIMPLE_FLOOR * blade_scale()
	return load_origin.y + WALL_H * 1.6


func load_ceiling(load_origin: Vector3) -> float:
	if Cfg.simple_tools():
		return load_origin.y + SIMPLE_ROOF * blade_scale()
	return load_roof()


static func load_grid(blade_w: float, blade_d: float) -> Vector2i:
	return Vector2i(
		clampi(int(round(blade_w * LOAD_SPREAD / LOAD_SLOT_PITCH)),
			LOAD_SLOTS_MIN, LOAD_SLOTS_MAX),
		clampi(int(round(blade_d * LOAD_SPREAD / LOAD_SLOT_PITCH)),
			LOAD_SLOTS_MIN, LOAD_SLOTS_MAX))


func capacity() -> int:
	if body == null or _basin_shape == null:
		return 0
	return LOAD_BITES * int(pan_geometry() ["max"])


static func capacity_for(head_w: float, head_d: float, depth: float) -> int:
	var grid:= load_grid(head_w, head_d)
	return grid.x * grid.y * maxi(1, int(floor(depth / LOAD_LAYER)))


func is_full() -> bool:
	var cap:= capacity()
	return cap > 0 and _carried >= cap


func flying_to(frame: Node3D) -> int:
	if frame == null:
		return 0
	var n:= 0
	for id: int in _in_flight:
		var rec: Array = _in_flight [id]
		if rec.size() < 8 or rec [7] != frame or not is_instance_valid(rec [0]):
			continue
		var ball:= rec [0] as HayWad
		n += ball.strands if ball != null else 1
	return n


func room_left() -> int:
	var cap:= capacity()
	if cap <= 0:
		return 1 << 30
	return maxi(0, cap - _carried - flying_to(body))


func fill_fraction() -> float:
	var cap:= capacity()
	return clampf(float(_carried) / float(cap), 0.0, 1.0) if cap > 0 else 0.0


func _say_full() -> void:
	if _badge_gap > 0.0 or body == null or not body.is_inside_tree():
		return
	_badge_gap = FULL_BADGE_GAP
	FullBadge.flash_over(body, _badge_point())


	Audio.play_3d("hay_shift", body.global_position, -18.0)


func _badge_point() -> Vector3:
	if _basin_shape == null:
		return Vector3(0.0, FullBadge.CLEARANCE, 0.0)
	var box:= _basin_shape.shape as BoxShape3D
	var top: float = _basin_shape.position.y + (box.size.y * 0.5 if box != null else 0.0)
	return Vector3(_basin_shape.position.x, top + FullBadge.CLEARANCE,
		_basin_shape.position.z)


func needle_landing(xf: Transform3D, load_origin: Vector3, blade_w: float,
		blade_d: float) -> Vector3:
	var local:= Vector3(
		_rng.randf_range(-0.22, 0.22) * blade_w,
		WALL_H * 1.4 + _rng.randf() * 0.02,
		_rng.randf_range(-0.22, 0.22) * blade_d) + load_origin
	return xf * local


func _lift_needles(center: Vector3, radius: float, onto: Callable,
		xf: Transform3D) -> int:
	var n:= live.reveal_needles_in(center, radius, onto)
	if n > 0:
		Audio.play_3d("needle_ting", xf.origin, -4.0)
	return n


func _carry_load(xf: Transform3D, delta: float) -> void:


	var level:= 0.0
	if _have_prev and delta > 0.0:
		var up_dot:= xf.basis.y.dot(Vector3.UP)
		level = clampf(inverse_lerp(CARRY_UP_NONE, CARRY_UP_FULL, up_dot), 0.0, 1.0)

	var moved:= xf * _prev_blade_xform.affine_inverse()


	var simple:= Cfg.simple_tools()
	var holding:= _have_prev and delta > 0.0
	if not simple:
		holding = holding and (player == null or not player.pour_intent()) and xf.basis.y.dot(Vector3.UP) > TIP_POUR


	_set_pouring(not simple and _have_prev and delta > 0.0 and not holding)
	_load_held = holding


	for id: int in _let_go.keys():
		var rec: Array = _let_go [id]
		rec [0] = float(rec [0]) - delta
		if float(rec [0]) <= 0.0:
			_unblind(rec [1])
			_let_go.erase(id)
		elif live != null and is_instance_valid(rec [1]) and rec [1] is RigidBody3D and rec [1] is not HayWad:
			live.see_straw_again(rec [1])
	_tick_passing()


	var shed_left:= _shed_count(delta) if holding else 0
	var shed_want:= shed_left

	var now: Dictionary = { }


	var candidates: Array = basin.get_overlapping_bodies()
	if simple and not _riding.is_empty():
		var reported: Dictionary = { }
		for b in candidates:
			if b is RigidBody3D:
				reported [(b as RigidBody3D).get_instance_id()] = true
		for id: int in _riding:
			if reported.has(id):
				continue
			var kept: Variant = _riding [id]
			if is_instance_valid(kept):
				candidates.append(kept)
	for b in candidates:
		if b is not RigidBody3D:
			continue
		var rb:= b as RigidBody3D
		var ball:= rb as HayWad
		if ball == null and not (rb.collision_layer & Cfg.L_STRAND):
			continue


		if not rb.is_inside_tree():
			continue


		var rid:= rb.get_instance_id()
		if _let_go.has(rid) or (not _riding.has(rid) and let_go_recently(rb)):
			continue
		now [rb.get_instance_id()] = rb


		LiveStrandManager.unpin(rb)


		if ball == null and not _riding.has(rb.get_instance_id()):
			live.set_protected(rb, true)


			if simple:
				_blind(rb)


		if simple and not _ride_local.has(rb.get_instance_id()):
			_ride_local [rb.get_instance_id()] = _pan_slot(xf, rb)
		if holding:


			if shed_left > 0 and ball == null:
				shed_left -= 1
				_shed_strand(rb, xf)
				now.erase(rb.get_instance_id())
				continue
			if simple:
				weld_local(rb, xf, ride_pose(_ride_from, rb.get_instance_id(),
					_ride_local [rb.get_instance_id()], delta))
				continue


			HayHold.carry_body(rb, moved, _hold_centre(), _hold_radius(), delta,
				xf.basis.y)
			continue


		var slide:= downhill(xf.basis.y)
		if slide != Vector3.ZERO:
			rb.linear_velocity = pour_velocity(rb.linear_velocity, slide,
				xf.basis.y)
		rb.sleeping = false
		continue

	for id: int in _riding:
		if not now.has(id):


			if _let_go.has(id):
				continue


			var gone: Variant = _riding [id]
			if not is_instance_valid(gone):
				continue
			_ride_local.erase(id)
			var body:= gone as RigidBody3D
			if body != null and body is not HayWad:
				live.set_protected(body, false)


				_land(body)


				LiveStrandManager.release_hold(body)
				live.mark_poured(body)
	_riding = now


	_carried = 0


	var into_blade:= xf.orthonormalized().affine_inverse()
	var top:= EMPTY_LOAD
	for id: int in now:
		var held:= now [id] as RigidBody3D
		var as_ball:= held as HayWad
		_carried += as_ball.strands if as_ball != null else 1
		top = maxf(top, (into_blade * held.global_position).y)


	for id: int in _in_flight:
		var rec: Array = _in_flight [id]
		top = maxf(top, (into_blade * (rec [2] as Vector3)).y)
	_load_top = top


	var lost:= _prev_carried - _carried


	_shed_said += shed_want - shed_left
	if _shed_said >= SHIFT_STRANDS:


		_shed_said = 0
		Audio.play_3d("hay_shift", xf.origin, -23.0)
	elif simple:


		pass
	elif lost >= DUMP_STRANDS and level <= DUMP_LEVEL:
		Audio.play_3d("hay_dump", xf.origin, -12.0)
	elif lost >= SHIFT_STRANDS:


		Audio.play_3d("hay_shift", xf.origin, -23.0)
	_prev_carried = _carried


	_badge_gap = maxf(0.0, _badge_gap - delta)
	var full_now:= simple and is_full()
	if full_now and not _was_full:
		_say_full()
	_was_full = full_now


static func pour_velocity(current: Vector3, slide: Vector3, up: Vector3) -> Vector3:
	var tip:= clampf(1.0 - up.dot(Vector3.UP), 0.0, 1.0)
	var want:= POUR_SPEED * lerpf(POUR_SPEED_FLOOR, 1.0, tip)
	var out:= current
	var along:= out.dot(slide)

	if along < want:
		out += slide * (want - along)


	var off:= out.dot(up)
	if off < POUR_LIFT:
		out += up * (POUR_LIFT - off)
	return out


static func downhill(up: Vector3) -> Vector3:
	var slope:= Vector3.DOWN - up * Vector3.DOWN.dot(up)
	return slope.normalized() if slope.length_squared() > 1e-06 else Vector3.ZERO


func _set_pouring(on: bool) -> void:
	if on == _pouring or body == null:
		return
	_pouring = on
	body.physics_material_override = _pour_mat if on else null


func _stance_grip() -> float:
	if player == null:
		return 1.0
	return lerpf(lerpf(1.0, GRIP_SPRINT_SCALE, player.unrest()),
		GRIP_CROUCH_SCALE, player.crouch_amount())


static func shed_share(who: Player, delta: float, jumped: bool) -> float:
	if who == null:
		return 0.0
	var share:= 0.0
	if who.is_sprinting():


		share += SHED_SPRINT_RATE * Tech.jostle_scale() * delta
	if jumped:
		share += SHED_JUMP_FRACTION * Tech.land_kick_scale()
	if share <= 0.0:
		return 0.0


	return share * lerpf(1.0, Cfg.JOSTLE_CROUCH_FACTOR, who.crouch_amount())


func _shed_count(delta: float) -> int:
	if player == null:
		return 0


	var jumps:= player.jumps_taken()
	var jumped:= _seen_jumps >= 0 and jumps > _seen_jumps
	_seen_jumps = jumps
	var share:= shed_share(player, delta, jumped)
	if share <= 0.0:


		_shed_debt = 0.0
		return 0
	_shed_debt += float(_carried) * share
	var n:= int(floor(_shed_debt))
	_shed_debt -= float(n)
	return n


func _shed_strand(rb: RigidBody3D, xf: Transform3D) -> void:

	rb.freeze = false
	_let_go [rb.get_instance_id()] = [LET_GO_TIME, rb]
	_ride_local.erase(rb.get_instance_id())


	var out:= rb.global_position - _hold_centre()
	out -= xf.basis.y * out.dot(xf.basis.y)
	var away:= out.normalized() if out.length_squared() > 1e-06 else xf.basis.z
	rb.linear_velocity += (away + xf.basis.y * 0.35).normalized() * SHED_SPEED
	rb.sleeping = false


func _release_all() -> void:
	_set_pouring(false)


	for id: int in _riding:
		_unblind(_riding [id])
	_riding.clear()


	for id: int in _in_flight:
		_land((_in_flight [id] as Array) [0])
	_in_flight.clear()
	_carried = 0


	for id: int in _let_go:
		_unblind((_let_go [id] as Array) [1])
	_let_go.clear()


	for id: int in _passing:
		_end_pass(_passing [id])
	_passing.clear()
	_ride_local.clear()
	_ride_from.clear()
	_shed_debt = 0.0


	_seen_jumps = -1
	_shed_said = 0
	_was_full = false
	_badge_gap = 0.0
