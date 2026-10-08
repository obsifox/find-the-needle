class_name SandShovel
extends Carryable


const MODEL:= "res://assets/models/sand_shovel.glb"


const SCALE:= 0.0769
const YAW:= PI
const OFFSET:= Vector3(0.0, 0.0313, 0.0748)


const BLADE_SIZE:= Vector3(0.277, 0.1, 0.267)
const BLADE_POS:= Vector3(0.0, 0.0587, -0.1664)
const SHAFT_SIZE:= Vector3(0.08, 0.035, 0.188)
const SHAFT_POS:= Vector3(0.0, 0.09, 0.0563)
const GRIP_SIZE:= Vector3(0.195, 0.03, 0.15)
const GRIP_POS:= Vector3(0.0, 0.087, 0.2251)

const MASS:= 0.55


const SCOOP_RADIUS:= Cfg.SCOOP_RADIUS * 0.72
const SCOOP_MAX:= 18


const TOY_LOAD_DEPTH:= 0.6


const DISH_CELL:= 0.01


const DISH_MIN:= Vector2(-0.16, -0.34)
const DISH_CELLS:= Vector2i(33, 37)


const DISH_CLEAR:= Cfg.STRAND_THICK * 0.75


static var _dish:= PackedFloat32Array()

var _player: Player
var _basin: Area3D
var _riding: Dictionary = { }


var _tick_xform:= Transform3D()
var _load_held:= false


var _let_go: Dictionary = { }


var _ride_local: Dictionary = { }

var _ride_from: Dictionary = { }

var _ride_count:= 0
var _badge_gap:= 0.0
var _was_full:= false


var _shed_debt:= 0.0
var _seen_jumps:= -1


var _landed: Dictionary = { }

var _shed_said:= 0
var dumps:= 0


var stacked_scoops:= 0
var _aim_yaw:= 0.0
var _aim_pitch:= 0.0


var _swing: DigSwing = DigSwing.toy()

var _toss: DigSwing = DigSwing.toy_toss()


func _process(delta: float) -> void:
	if not is_held():
		return
	_toss.tick(delta)
	if _swing.tick(delta) and _player != null and _player.shovel != null and _player.shovel.vfx != null and not _riding.is_empty():


		var g:= pan_geometry()
		var at: Vector3 = (g ["xf"] as Transform3D) * (g ["origin"] as Vector3)
		_player.shovel.vfx.shake_off(at, - global_transform.basis.z,
			mini(6, 2 + _riding.size() / 6))
		Audio.play_3d("hay_shift", at, -20.0)


func _ready() -> void:
	super._ready()
	_basin = Area3D.new()
	_basin.name = "Basin"
	_basin.collision_layer = 0
	_basin.collision_mask = Cfg.L_STRAND
	_basin.monitorable = false
	var cs:= CollisionShape3D.new()
	var shape:= BoxShape3D.new()


	shape.size = Vector3(BLADE_SIZE.x * 1.08, 0.24, BLADE_SIZE.z * 1.08)
	cs.shape = shape
	cs.position = BLADE_POS + Vector3(0, 0.12, 0)
	_basin.add_child(cs)
	add_child(_basin)


var _loose_layer:= 0
var _loose_mask:= 0


func pick_up() -> void:
	var was_held:= is_held()
	super.pick_up()
	if was_held:
		return
	_loose_layer = collision_layer
	_loose_mask = collision_mask
	collision_layer = Cfg.L_TOOL
	collision_mask = _loose_mask & ~ Cfg.L_PROP


func release(velocity: Vector3, angular: Vector3 = Vector3.ZERO) -> void:


	_swing.stop()
	_toss.stop()
	_release_riding()
	if _basin != null:
		_basin.monitoring = false


	if is_held() and _loose_layer != 0:
		collision_layer = _loose_layer
		collision_mask = _loose_mask
	super.release(velocity, angular)


func impact_sfx() -> String:
	return "plastic_drop"


func passes_through_barrows() -> bool:
	return true


func _build_model() -> void:
	mass = MASS
	var pm:= PhysicsMaterial.new()
	pm.friction = 0.75
	pm.bounce = 0.05
	physics_material_override = pm
	_mount_model(MODEL, Transform3D(Basis(Vector3.UP, YAW).scaled(Vector3.ONE * SCALE), OFFSET))


	_ground_materials({ "yellow": { "metallic": 0.0, "roughness": 0.74, "albedo": 0.72 } })
	_build_dish()


func _build_dish() -> void:
	if not _dish.is_empty() or _meshes.is_empty():
		return
	var grid:= PackedFloat32Array()
	grid.resize(DISH_CELLS.x * DISH_CELLS.y)
	grid.fill(- INF)
	for mi: MeshInstance3D in _meshes:
		if mi.mesh == null:
			continue


		var to_item:= Transform3D.IDENTITY
		var n: Node = mi
		while n != self and n is Node3D:
			to_item = (n as Node3D).transform * to_item
			n = n.get_parent()
		for surf in mi.mesh.get_surface_count():
			var arrays:= mi.mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays [Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx [i] = i
			for t in range(0, idx.size() - 2, 3):
				_dish_triangle(grid, to_item * verts [idx [t]],
					to_item * verts [idx [t + 1]], to_item * verts [idx [t + 2]])
	_dish = grid


func _dish_triangle(grid: PackedFloat32Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p: Vector3 in [a, b, c]:
		var cx:= floori((p.x - DISH_MIN.x) / DISH_CELL)
		var cz:= floori((p.z - DISH_MIN.y) / DISH_CELL)
		if cx >= 0 and cz >= 0 and cx < DISH_CELLS.x and cz < DISH_CELLS.y:
			var k:= cz * DISH_CELLS.x + cx
			grid [k] = maxf(grid [k], p.y)
	var d:= (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 1e-10:
		return
	var x0:= maxi(0, ceili((minf(a.x, minf(b.x, c.x)) - DISH_MIN.x) / DISH_CELL - 0.5))
	var x1:= mini(DISH_CELLS.x - 1, floori((maxf(a.x, maxf(b.x, c.x)) - DISH_MIN.x) / DISH_CELL - 0.5))
	var z0:= maxi(0, ceili((minf(a.z, minf(b.z, c.z)) - DISH_MIN.y) / DISH_CELL - 0.5))
	var z1:= mini(DISH_CELLS.y - 1, floori((maxf(a.z, maxf(b.z, c.z)) - DISH_MIN.y) / DISH_CELL - 0.5))
	for cz in range(z0, z1 + 1):
		var pz:= DISH_MIN.y + (float(cz) + 0.5) * DISH_CELL
		for cx in range(x0, x1 + 1):
			var px:= DISH_MIN.x + (float(cx) + 0.5) * DISH_CELL
			var w1:= ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / d
			var w2:= ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / d
			var w3:= 1.0 - w1 - w2
			if w1 < -0.0001 or w2 < -0.0001 or w3 < -0.0001:
				continue
			var k:= cz * DISH_CELLS.x + cx
			grid [k] = maxf(grid [k], w1 * a.y + w2 * b.y + w3 * c.y)


static func _dish_top(x: float, z: float) -> float:
	if _dish.is_empty():
		return - INF
	var fx:= (x - DISH_MIN.x) / DISH_CELL - 0.5
	var fz:= (z - DISH_MIN.y) / DISH_CELL - 0.5
	var cx:= floori(fx)
	var cz:= floori(fz)
	var top:= - INF
	for dz in 2:
		for dx in 2:
			var ix:= cx + dx
			var iz:= cz + dz
			if ix >= 0 and iz >= 0 and ix < DISH_CELLS.x and iz < DISH_CELLS.y:
				top = maxf(top, _dish [iz * DISH_CELLS.x + ix])
	return top


static func _clear_dish(rb: RigidBody3D, slot: Transform3D) -> Transform3D:
	slot.origin.y += dish_lift(rb, slot)
	return slot


static func dish_lift(rb: RigidBody3D, slot: Transform3D) -> float:
	if rb is HayWad or not rb.has_meta(LiveStrandManager.META_LEN):
		return 0.0
	var half:= Cfg.STRAND_LENGTH * float(rb.get_meta(LiveStrandManager.META_LEN, 1.0)) * 0.5
	var dir:= slot.basis.z.normalized()
	var steps:= maxi(2, ceili(half * 2.0 / DISH_CELL))
	var lift:= 0.0
	for i in steps + 1:
		var p:= slot.origin + dir * lerpf(- half, half, float(i) / float(steps))
		lift = maxf(lift, _dish_top(p.x, p.z) + DISH_CLEAR - p.y)
	return lift


func _build_shapes() -> void:
	_shape_box(BLADE_SIZE, BLADE_POS)
	_shape_box(SHAFT_SIZE, SHAFT_POS)
	_shape_box(GRIP_SIZE, GRIP_POS)


func carry_pivot() -> Vector3:
	var p:= _swing.pose() + _toss.pose()
	return SHAFT_POS - Vector3(0.0, p.y, - p.x)


func carry_aim() -> Basis:
	var p:= _swing.pose() + _toss.pose()
	return Basis.from_euler(Vector3(_aim_pitch + p.z, _aim_yaw, p.w))


func carry_pitches() -> bool:
	return true


func attach_player(p: Player) -> void:
	_player = p
	_aim_yaw = 0.0
	_aim_pitch = 0.0
	if _basin != null:
		_basin.monitoring = true


func aim_input(rel: Vector2) -> void:
	if not is_held() or Cfg.simple_tools():
		return
	_aim_yaw = clampf(_aim_yaw - rel.x * 0.004, -1.1, 1.1)
	_aim_pitch = clampf(_aim_pitch - rel.y * 0.004, -1.35, 1.0)


func aim_point() -> Dictionary:
	if _player == null or not is_held():
		return { }
	return Shovel.aim_from(_player.eye_position(), _player.look_direction(),
		get_world_3d().direct_space_state, _player.shovel.field)


func bundle_under_aim() -> HayWad:
	if _player == null or not is_held() or _player.shovel == null:
		return null
	return _player.shovel.bundle_at(aim_point(), float(pan_geometry() ["radius"]))


func scoop() -> int:
	if _player == null or not is_held() or _player.shovel == null:
		return 0


	var most:= -1
	if Cfg.simple_tools():
		most = capacity() - _riding.size() - _landed_count() - _player.shovel.flying_to(self)
		if is_full() or most <= 0:
			_say_full()
			return 0
	var aim:= aim_point()
	if aim.is_empty():

		return 0
	var g:= pan_geometry()
	most = int(g ["max"]) if most < 0 else mini(int(g ["max"]), most)

	var had:= _riding.size()
	var got:= 0


	if bool(aim.get("loose", false)):
		got = _player.shovel.gather_at(aim ["position"], most,
			float(g ["radius"]), g ["xf"], g ["origin"], float(g ["w"]),
			float(g ["d"]), self)
		if got > 0:
			_swing.start(0.6)
	else:
		got = _player.shovel.scoop_at(aim ["position"], most,
			float(g ["radius"]), g ["xf"], g ["origin"], float(g ["w"]),
			float(g ["d"]), String(g ["track"]), self)
		if got > 0:
			_swing.start(clampf(float(got) / float(SCOOP_MAX), 0.4, 1.0))
	if got > 0 and had > 0:
		stacked_scoops += 1
	return got


func pan_geometry() -> Dictionary:
	var s:= Tech.toy_shovel_scale()
	return {
		"xf": global_transform,
		"origin": (BLADE_POS + Vector3(0, BLADE_SIZE.y * 0.85, 0)) * s,
		"w": BLADE_SIZE.x * s,
		"d": BLADE_SIZE.z * s,
		"max": Tech.scoop_max(SCOOP_MAX, s),
		"radius": SCOOP_RADIUS * s,
		"track": "toy_shovel_size",
	}


func needle_landing_now() -> Vector3:
	if _player == null or _player.shovel == null:
		return global_position
	var g:= pan_geometry()
	return _player.shovel.needle_landing(g ["xf"], g ["origin"], float(g ["w"]),
		float(g ["d"]))


func carried_strands() -> int:
	return _riding.size()


func take_landed(rb: RigidBody3D) -> void:
	if rb != null and is_held():
		_landed [rb.get_instance_id()] = rb


func _landed_count() -> int:
	var n:= 0
	for id: int in _landed:
		if not _riding.has(id) and is_instance_valid(_landed [id]):
			n += 1
	return n


func capacity() -> int:
	return Shovel.LOAD_BITES * Tech.scoop_max(SCOOP_MAX, Tech.toy_shovel_scale())


func is_full() -> bool:
	var cap:= capacity()
	return cap > 0 and _riding.size() >= cap


func fill_fraction() -> float:
	var cap:= capacity()
	return clampf(float(_riding.size()) / float(cap), 0.0, 1.0) if cap > 0 else 0.0


func dump() -> int:
	if _player == null or not is_held() or _player.shovel == null:
		return 0
	if _riding.is_empty():
		return 0


	var into:= _player.shovel.pour_target()
	var push:= _player.shovel.dump_push()
	var sent:= 0
	for id: int in _riding.keys():
		var held: Variant = _riding [id]
		if not is_instance_valid(held):
			continue
		var rb:= held as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue


		_let_go [id] = [Shovel.LET_GO_TIME, rb]
		_riding.erase(id)
		_ride_local.erase(id)
		if into != null:
			_player.shovel.lob_into(rb, into)
		else:
			_player.shovel.push_strand(rb, push)
		sent += 1
	if sent > 0:
		dumps += 1
		Audio.play_3d("hay_dump", global_position, -12.0)
		_toss.start(1.0)
	return sent


func spill() -> int:
	if _player == null or _player.shovel == null or _riding.is_empty():
		return 0
	var push:= _player.shovel.spill_push()
	var sent:= 0
	for id: int in _riding.keys():
		var held: Variant = _riding [id]
		if not is_instance_valid(held):
			continue
		var rb:= held as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		_let_go [id] = [Shovel.LET_GO_TIME, rb]
		_riding.erase(id)
		_ride_local.erase(id)
		_player.shovel.push_strand(rb, push)
		sent += 1
	if sent > 0:
		Audio.play_3d("hay_dump", global_position, -18.0)
	return sent


func _say_full() -> void:
	if _badge_gap > 0.0 or not is_inside_tree():
		return
	_badge_gap = Shovel.FULL_BADGE_GAP
	var s:= Tech.toy_shovel_scale()
	FullBadge.flash_over(self, (BLADE_POS + Vector3(0.0,
		BLADE_SIZE.y * 0.5 + FullBadge.CLEARANCE, 0.0)) * s)
	Audio.play_3d("hay_shift", global_position, -18.0)


func _hold_centre() -> Vector3:
	return global_transform * ((BLADE_POS + Vector3(0, 0.06, 0)) * Tech.toy_shovel_scale())


func _hold_radius() -> float:
	return Vector2(BLADE_SIZE.x, BLADE_SIZE.z).length() * 0.5 * Tech.toy_shovel_scale() + 0.05


func on_drawn() -> void:
	if not _load_held or _riding.is_empty() or _player == null or _player.hand == null or _player.hand.live == null:
		return
	_player.hand.live.draw_load_shifted(_riding, global_transform.orthonormalized()
		* _tick_xform.orthonormalized().affine_inverse())


func on_carried(_xform: Transform3D, moved: Transform3D, delta: float) -> void:
	if _basin == null or _player == null or _player.hand == null:
		return
	var live:= _player.hand.live
	if live == null:
		return
	var simple:= Cfg.simple_tools()


	for id: int in _let_go.keys():
		var rec: Array = _let_go [id]
		rec [0] = float(rec [0]) - delta
		if float(rec [0]) <= 0.0:
			_unblind(rec [1], live)
			_let_go.erase(id)
		elif is_instance_valid(rec [1]) and rec [1] is RigidBody3D and rec [1] is not HayWad:
			live.see_straw_again(rec [1])


	var holding:= simple or (not _player.pour_intent()
			and _xform.basis.y.dot(Vector3.UP) > Shovel.TIP_POUR)
	var shed_left:= _shed_count(delta) if holding else 0
	var shed_want:= shed_left
	_tick_xform = _xform
	_load_held = holding and delta > 0.0

	var now: Dictionary = { }


	var candidates: Array = _basin.get_overlapping_bodies()
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


	if simple:
		for id: int in _landed:
			var got: Variant = _landed [id]
			if is_instance_valid(got) and not _riding.has(id) and not candidates.has(got):
				candidates.append(got)
	_landed.clear()
	for body in candidates:
		if not body is RigidBody3D:
			continue
		var rb:= body as RigidBody3D
		if not (rb.collision_layer & Cfg.L_STRAND) or not rb.is_inside_tree():
			continue


		if _let_go.has(rb.get_instance_id()) or (not _riding.has(rb.get_instance_id())
					and Shovel.let_go_recently(rb)):
			continue
		now [rb.get_instance_id()] = rb


		LiveStrandManager.unpin(rb)
		if not _riding.has(rb.get_instance_id()):
			live.set_protected(rb, true)


			if simple:
				rb.collision_mask &= ~ Shovel.BLIND_MASK


				rb.add_collision_exception_with(self)


				rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				rb.freeze = true


		if simple and not _ride_local.has(rb.get_instance_id()):
			_ride_local [rb.get_instance_id()] = _pan_slot(_xform, rb)
		if delta <= 0.0:
			continue


		if shed_left > 0 and not (rb is HayWad) and _riding.has(rb.get_instance_id()):
			shed_left -= 1
			_shed_strand(rb, _xform)
			now.erase(rb.get_instance_id())
			continue


		if simple or (not _player.pour_intent() and _xform.basis.y.dot(Vector3.UP) > Shovel.TIP_POUR):


			if simple:
				Shovel.weld_local(rb, _xform, Shovel.ride_pose(_ride_from,
					rb.get_instance_id(), _ride_local [rb.get_instance_id()], delta))
				continue
			HayHold.carry_body(rb, moved, _hold_centre(), _hold_radius(), delta,
				_xform.basis.y)
			continue


		var slide:= Shovel.downhill(_xform.basis.y)
		if slide != Vector3.ZERO:
			rb.linear_velocity = Shovel.pour_velocity(rb.linear_velocity, slide,
				_xform.basis.y)
		rb.sleeping = false
	for id: int in _riding:
		if not now.has(id):


			if _let_go.has(id):
				continue
			_ride_local.erase(id)
			live.set_protected(_riding [id], false)
			_unblind(_riding [id], live)
	_riding = now


	_badge_gap = maxf(0.0, _badge_gap - delta)


	_shed_said += shed_want - shed_left
	if _shed_said >= Shovel.SHIFT_STRANDS:
		_shed_said = 0
		Audio.play_3d("hay_shift", global_position, -23.0)
	var full_now:= simple and is_full()
	if full_now and not _was_full:
		_say_full()
	_was_full = full_now


func _shed_count(delta: float) -> int:
	if _player == null or _riding.is_empty():
		return 0
	var jumps:= _player.jumps_taken()
	var jumped:= _seen_jumps >= 0 and jumps > _seen_jumps
	_seen_jumps = jumps
	var share:= Shovel.shed_share(_player, delta, jumped)
	if share <= 0.0:
		_shed_debt = 0.0
		return 0
	_shed_debt += float(_riding.size()) * share
	var n:= int(floor(_shed_debt))
	_shed_debt -= float(n)
	return n


func _shed_strand(rb: RigidBody3D, xf: Transform3D) -> void:
	rb.freeze = false
	_let_go [rb.get_instance_id()] = [Shovel.LET_GO_TIME, rb]
	_ride_local.erase(rb.get_instance_id())
	var out:= rb.global_position - _hold_centre()
	out -= xf.basis.y * out.dot(xf.basis.y)
	var away:= out.normalized() if out.length_squared() > 1e-06 else xf.basis.z
	rb.linear_velocity += (away + xf.basis.y * 0.35).normalized() * Shovel.SHED_SPEED
	rb.sleeping = false


func _pan_slot(xf: Transform3D, rb: RigidBody3D) -> Transform3D:
	var s:= Tech.toy_shovel_scale()
	var local:= xf.orthonormalized().affine_inverse() * rb.global_transform
	var mid:= BLADE_POS * s


	var floor_y:= mid.y - BLADE_SIZE.y * 0.5 * s + Shovel.SIMPLE_FLOOR * s


	_ride_from [rb.get_instance_id()] = [local, 0.0]
	if _ride_local.is_empty():
		_ride_count = 0
	_ride_count += 1


	return _clear_dish(rb, Shovel.lay_in_pan(rb, local, mid, BLADE_SIZE.x * 0.5 * s,
		BLADE_SIZE.z * 0.5 * s, floor_y, floor_y + BLADE_SIZE.y * TOY_LOAD_DEPTH * s,
		_ride_count - 1, _heap_room()))


func _heap_room() -> int:
	var s:= Tech.toy_shovel_scale()
	return maxi(capacity(), Shovel.capacity_for(BLADE_SIZE.x * s, BLADE_SIZE.z * s,
		BLADE_SIZE.y * TOY_LOAD_DEPTH * s))


func _unblind(b: Variant, live: LiveStrandManager) -> void:
	if not is_instance_valid(b):
		return
	var rb:= b as RigidBody3D
	if rb == null:
		return


	rb.freeze = false
	rb.sleeping = false
	rb.collision_mask |= Shovel.BLIND_MASK


	rb.remove_collision_exception_with(self)
	if live != null:
		live.set_protected(rb, false)


func _release_riding() -> void:
	_was_full = false
	_badge_gap = 0.0
	var live: LiveStrandManager = null
	if _player != null and _player.hand != null:
		live = _player.hand.live


	for id: int in _let_go:
		_unblind((_let_go [id] as Array) [1], live)
	_let_go.clear()


	for id: int in _landed:
		if not _riding.has(id):
			_unblind(_landed [id], live)
	_landed.clear()
	for id: int in _riding:
		_unblind(_riding [id], live)
	_riding.clear()
	_ride_local.clear()
	_ride_from.clear()


	_shed_debt = 0.0
	_seen_jumps = -1
	_shed_said = 0
