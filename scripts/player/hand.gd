class_name HandTool
extends Node3D


const REACH:= 3.2
const HOLD_FORWARD:= 0.52
const HOLD_DOWN:= 0.13
const THROW_SPEED:= 6.5


const FLY_SECONDS:= Vector2(0.3, 0.5)


const FLY_LIFT:= 0.26


const FLY_TURNS:= 0.75


const FAN_STEP:= 0.11


const FAN_SPAN:= FAN_STEP * 9.0


const FAN_DEPTH:= 0.004


const FAN_EASE:= 14.0


const DROP_SCATTER:= 0.35
const THROW_SCATTER:= 0.7

const HAY_LAYERS:= Cfg.L_STRAND | Cfg.L_SETTLED


class Held:
	var body: RigidBody3D


	var from: Transform3D
	var age:= 0.0
	var seconds:= 0.3
	var lift:= 0.0


	var spin:= 1.0

	var slot:= 0.0

	var tilt:= 0.0

var player: Player
var field: HayField
var live: LiveStrandManager

var _held: Array [Held] = []
var _active:= true
var _rng:= RandomNumberGenerator.new()


var throws:= 0


func _ready() -> void:
	_rng.randomize()


func set_active(on: bool) -> void:
	_active = on
	if not on:
		drop_held()


func is_holding() -> bool:
	_prune()
	return not _held.is_empty()


func count() -> int:
	_prune()
	return _held.size()


func capacity() -> int:
	return Tech.hand_capacity()


func is_full() -> bool:
	return is_holding_needle() or count() >= capacity()


func holds(body: Object) -> bool:
	for h in _held:
		if h.body == body:
			return true
	return false


func held_bodies() -> Array [RigidBody3D]:
	_prune()
	var out: Array [RigidBody3D] = []
	for h in _held:
		out.append(h.body)
	return out


func landed() -> bool:
	_prune()
	for h in _held:
		if h.age < h.seconds:
			return false
	return true


func hold_pose(i: int) -> Transform3D:
	_prune()
	if player == null or i < 0 or i >= _held.size():
		return Transform3D.IDENTITY
	return _pose(player.camera.global_transform, _held [i], _held.size())


func primary() -> void:
	if not _active:
		return
	if is_holding():


		var cab:= deposit_target()
		if cab != null and deposit_into(cab):
			return


		if not is_holding_needle():
			var hit:= aim_hit()
			if is_hay_hit(hit):
				if not is_full():
					_take(hit)
				return
		drop_held()
		return


	if _click_ending():
		return


	if _click_case():
		return
	_take(aim_hit())


func _take(hit: Dictionary) -> bool:
	if not _pluck(hit):
		return false
	for i in Tech.hand_grab() - 1:
		if is_full():
			break
		var next:= aim_hit()
		if not is_hay_hit(next) or not _pluck(next, false):
			break
	return true


func aim_hit() -> Dictionary:
	if player == null or not is_inside_tree():
		return { }
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * REACH)

	q.collision_mask = Cfg.L_PILE | Cfg.L_STRAND | Cfg.L_SETTLED
	q.collide_with_areas = false
	var skip: Array [RID] = []
	for h in _held:
		if is_instance_valid(h.body):
			skip.append(h.body.get_rid())
	q.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(q)


func is_hay_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	if collider is RigidBody3D and (collider as RigidBody3D).collision_layer & HAY_LAYERS:
		return int(collider.get_meta("needle_index", -1)) < 0 or not is_holding()
	return true


const END_BTN_R:= 0.085


func ending_target() -> NeedleCabinet:
	if is_holding() or player == null:
		return null
	var from:= player.eye_position()
	var dir:= player.look_direction()
	var q:= PhysicsRayQueryParameters3D.create(from, from + dir * REACH)
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var n: Node = hit.get("collider") as Node
	while n != null and n is not NeedleCabinet:
		n = n.get_parent()
	var cab:= n as NeedleCabinet
	if cab == null or cab.placement_preview or not cab.ending_armed():
		return null
	var to_btn:= cab.ending_button_at() - from
	var along:= to_btn.dot(dir)


	if along <= 0.0:
		return null
	if (to_btn - dir * along).length() > END_BTN_R:
		return null
	return cab


func _click_ending() -> bool:
	var cab:= ending_target()
	return cab != null and cab.press_ending()


func case_target() -> Dictionary:
	if is_holding() or player == null:
		return { }
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * REACH)
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return { }
	var n: Node = hit.get("collider") as Node
	while n != null and n is not NeedleCabinet:
		n = n.get_parent()
	var cab:= n as NeedleCabinet
	if cab == null or cab.placement_preview or not cab.is_open():
		return { }


	if cab.ending_covered():
		return { }
	var type: int = cab.slot_at(hit ["position"], player.look_direction())
	if type < 0:
		return { }
	if cab.has_specimen(type):
		return { "cabinet": cab, "type": type, "action": "inspect" }
	if cab.can_take(type):
		return { "cabinet": cab, "type": type, "action": "take" }
	return { }


func _click_case() -> bool:
	var target: Dictionary = case_target()
	if target.is_empty():
		return false
	var cab: NeedleCabinet = target ["cabinet"]
	var type: int = target ["type"]
	if String(target ["action"]) == "inspect":
		if player.inspector == null:
			return false
		player.inspector.open(type, cab)
		return true
	return withdraw_from(cab, type)


func withdraw_from(cab: NeedleCabinet, type: int) -> bool:
	if live == null or cab == null or is_holding():
		return false
	var index:= cab.withdraw(type)
	if index < 0:
		return false


	if not take_needle(index, cab.slot_position(type)):


		GameState.deposit_needle(index, cab.slot_position(type))
		return false
	return true


func take_needle(index: int, at: Vector3) -> bool:
	if live == null or is_holding():
		return false
	var body:= live.reveal_needle(index, at)
	if body == null:
		return false
	_grab(body)
	return true


func held_needle_index() -> int:
	_prune()
	if _held.is_empty():
		return -1
	return int(_held [0].body.get_meta("needle_index", -1))


func is_holding_needle() -> bool:
	return held_needle_index() >= 0


func deposit_target() -> NeedleCabinet:
	if not is_holding_needle() or player == null:
		return null
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * REACH)


	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var n: Node = hit.get("collider") as Node
	while n != null and n is not NeedleCabinet:
		n = n.get_parent()
	var cab:= n as NeedleCabinet
	if cab == null or cab.placement_preview or not cab.is_open():
		return null


	if cab.ending_covered():
		return null
	return cab


func deposit_into(cab: NeedleCabinet) -> bool:
	var index:= held_needle_index()
	if index < 0 or cab == null or live == null:
		return false
	var b:= _held [0].body


	_held.clear()
	if not live.consume_needle(b):
		return false
	cab.accept(index)
	return true


func _pluck(hit: Dictionary, sound:= true) -> bool:
	if field == null or live == null or player == null or hit.is_empty():
		return false
	if is_full():
		return false

	var collider: Object = hit.get("collider")


	if collider is RigidBody3D and (collider as RigidBody3D).collision_layer & HAY_LAYERS:
		if not is_hay_hit(hit):
			return false
		_grab(collider as RigidBody3D, sound)
		return true


	var from:= player.eye_position()
	var dir:= player.look_direction()
	var result:= field.pluck_at(hit ["position"], 0.45, from, dir)
	if result.is_empty():


		result = field.pluck_at(hit ["position"] + Vector3(0, 0.06, 0), 0.7, from, dir)
		if result.is_empty():
			return false
	var body:= live.spawn_plucked(result ["transform"], result ["color"])
	if body == null:
		return false
	_grab(body, sound)
	return true


func _grab(body: RigidBody3D, sound:= true) -> void:
	if body == null or holds(body):
		return


	if sound:
		Audio.play_3d("hay_pick", body.global_position, -4.0)


	BeltPath.release(body)


	LiveStrandManager.unpin(body)

	var h:= Held.new()
	h.body = body
	h.from = body.global_transform.orthonormalized()
	var reach:= 1.0
	if player != null:
		reach = clampf(body.global_position.distance_to(player.eye_position()) / REACH,
			0.0, 1.0)
	h.seconds = lerpf(FLY_SECONDS.x, FLY_SECONDS.y, reach)
	h.lift = FLY_LIFT * reach
	h.spin = 1.0 if _rng.randf() < 0.5 else -1.0

	h.slot = float(_held.size())
	h.tilt = _rng.randfn(0.0, 0.05)
	_held.append(h)

	live.set_protected(body, true)
	live.set_ccd(body, true)
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true


func drop_held() -> void:


	var let_go:= _release_all(false)
	var scatter:= DROP_SCATTER if let_go.size() > 1 else 0.0
	for b in let_go:
		b.linear_velocity = Vector3(_rng.randfn(0.0, scatter), -0.2,
			_rng.randfn(0.0, scatter))


func throw_held() -> void:
	var let_go:= _release_all(true)
	if let_go.is_empty():
		return
	throws += 1
	Audio.play("hay_rustle", -8.0)
	var scatter:= THROW_SCATTER if let_go.size() > 1 else 0.0
	var dir:= player.look_direction()
	for b in let_go:
		b.linear_velocity = dir * THROW_SPEED + Vector3(0, 1.2, 0) + Vector3(
			_rng.randfn(0.0, scatter), _rng.randfn(0.0, scatter), _rng.randfn(0.0, scatter))
		b.angular_velocity = Vector3(randfn(0.0, 8.0), randfn(0.0, 8.0), randfn(0.0, 8.0))


func _release_all(to_fist: bool) -> Array [RigidBody3D]:
	_prune()
	var out: Array [RigidBody3D] = []
	if _held.is_empty():
		return out
	if to_fist and player != null and player.camera != null:
		var cam:= player.camera.global_transform
		var n:= _held.size()
		for i in n:
			_held [i].slot = float(i)
			_held [i].body.global_transform = _pose(cam, _held [i], n)
	for h in _held:
		out.append(h.body)
	_held.clear()
	for b in out:
		b.freeze = false


		live.set_ccd(b, true)
		live.set_protected(b, false)
	return out


func _prune() -> void:
	for i in range(_held.size() - 1, -1, -1):
		if not is_instance_valid(_held [i].body):
			_held.remove_at(i)


func _physics_process(delta: float) -> void:
	_prune()
	if _held.is_empty() or player == null:
		return
	var shuffle:= 1.0 - exp(- FAN_EASE * delta)
	for i in _held.size():
		var h:= _held [i]
		h.slot = lerpf(h.slot, float(i), shuffle)
		if h.age < h.seconds:
			h.age += delta
	_place(player.camera.global_transform)


func _process(_delta: float) -> void:
	_prune()
	if _held.is_empty() or player == null:
		return
	_place(player.camera.global_transform)


func _place(cam: Transform3D) -> void:
	var n:= _held.size()
	for h in _held:
		var to:= _pose(cam, h, n)
		h.body.global_transform = to if h.age >= h.seconds else _fly(h, to)


func _pose(cam: Transform3D, h: Held, n: int) -> Transform3D:
	var fwd:= (- cam.basis.z).normalized()
	var pos:= cam.origin + fwd * (HOLD_FORWARD + FAN_DEPTH * h.slot) + (- cam.basis.y) * HOLD_DOWN


	var b:= Basis(cam.basis.y, - cam.basis.z, cam.basis.x)
	var step:= minf(FAN_STEP, FAN_SPAN / maxf(float(n - 1), 1.0))
	var turn:= (h.slot - float(n - 1) * 0.5) * step + h.tilt
	return Transform3D(Basis(fwd, turn) * b, pos)


func _fly(h: Held, to: Transform3D) -> Transform3D:
	var k:= clampf(h.age / maxf(h.seconds, 0.001), 0.0, 1.0)
	var e:= k * k * (3.0 - 2.0 * k)
	var pos:= h.from.origin.lerp(to.origin, e) + Vector3.UP * (h.lift * sin(PI * e))
	var q:= h.from.basis.get_rotation_quaternion().slerp(
		to.basis.get_rotation_quaternion(), e)
	var turn:= TAU * FLY_TURNS * h.spin * (1.0 - e)
	return Transform3D(Basis(q) * Basis(Vector3.RIGHT, turn), pos)
