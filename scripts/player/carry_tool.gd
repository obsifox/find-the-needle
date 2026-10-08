class_name CarryTool
extends Node3D


const TARGET_REFRESH:= 0.06


const PROBE_SKIPS:= 4


const RECORD_REACH:= 0.45


const OVER_DECK:= 1.5


const LET_GO_BLIND:= 0.25


const LET_GO_PAN:= 1.0


const RIP_HOLD:= BuildTool.DISMANTLE_HOLD


var _rip: Carryable = null
var _rip_time:= 0.0

var player: Player


var hud: Hud


var _held: Carryable = null


var _pile: Array [Carryable] = []


var _lifts: PackedFloat32Array = PackedFloat32Array()
var _target: Carryable = null
var _since:= 0.0


var arms_full:= 0

var full_msec:= -1


var full_cap:= 0
var _full_latched:= false

var _tilt_pitch:= 0.0
var _tilt_roll:= 0.0


var _sway_pitch:= 0.0
var _sway_roll:= 0.0


var _prev_xform:= Transform3D.IDENTITY
var _have_prev:= false


var _ground_y:= 0.0
var _have_ground:= false

signal carry_changed(item: Carryable)


func is_carrying() -> bool:
	return is_instance_valid(_held)


func held() -> Carryable:
	return _held if is_instance_valid(_held) else null


func stack_capacity() -> int:
	return maxi(Tech.carry_stack(), 1)


func carried_count() -> int:
	return _pile.size()


func pile_up() -> Vector3:
	if not is_carrying():
		return Vector3.UP
	return _hold_basis(false).y.normalized()


func stack_has_room() -> bool:
	return (is_carrying() and _held.stacks_in_arms()
		and _pile.size() < stack_capacity())


func can_stack(item: Carryable) -> bool:
	return (item != null and is_instance_valid(item) and stack_has_room()
		and item.stacks_in_arms() and not _refused(item))


func stack_target() -> Carryable:
	var item:= target()
	return item if can_stack(item) else null


func try_stack() -> bool:
	if not stack_has_room() or player == null:
		return false
	var item:= _probe(true)
	if item == null:
		return _pick_record(true)
	return stack_on(item)


func stack_on(item: Carryable) -> bool:
	if not can_stack(item):
		return false
	item.set_highlighted(false)
	item.carrier = player
	item.pick_up()
	_keep_apart(item)
	_pile.append(item)
	_held = item
	_restack()


	item.warp(_pose_of(item, _lifts [_lifts.size() - 1]))
	_set_target(null)
	carry_changed.emit(item)
	return true


func _pop() -> Carryable:
	if not is_carrying():
		return null
	var item:= _held
	_pile.remove_at(_pile.size() - 1)
	_held = _pile [_pile.size() - 1] if not _pile.is_empty() else null
	_restack()


	for other in _pile:
		_parting.append([item, other])


	_have_prev = false
	return item


func _keep_apart(item: Carryable) -> void:
	for other in _pile:
		if is_instance_valid(other) and other != item:
			item.add_collision_exception_with(other)


var _parting: Array = []


func _tick_parting() -> void:
	if _parting.is_empty():
		return
	var keep: Array = []
	for pair in _parting:
		var a: Carryable = pair [0] if is_instance_valid(pair [0]) else null
		var b: Carryable = pair [1] if is_instance_valid(pair [1]) else null
		if a == null or b == null:
			continue
		if a in _pile and b in _pile:
			continue
		if _boxes_touch(a, b):
			keep.append(pair)
			continue
		_see_each_other(a, b)
	_parting = keep


func _see_each_other(a: Carryable, b: Carryable) -> void:
	a.remove_collision_exception_with(b)
	b.remove_collision_exception_with(a)


func _boxes_touch(a: Carryable, b: Carryable) -> bool:
	if not a.is_inside_tree() or not b.is_inside_tree():
		return false
	var ba:= (a.global_transform * a.ride_box()).grow(0.02)
	var bb:= b.global_transform * b.ride_box()
	return ba.intersects(bb)


func _restack() -> void:
	_lifts.resize(_pile.size())
	var top:= 0.0
	for i in _pile.size():
		var span:= _hold_span(_pile [i])


		var lift:= 0.0 if i == 0 else top + Cfg.CARRY_STACK_GAP - span.x
		_lifts [i] = lift
		top = maxf(top, lift + span.y)


func _hold_span(item: Carryable) -> Vector2:
	var spin:= item.carry_aim() * Basis(Vector3.UP, item.carry_yaw())
	var box:= Transform3D(spin, Vector3.ZERO) * item.ride_box()
	if box.size == Vector3.ZERO:
		return Vector2.ZERO
	var pivot:= (spin * item.carry_pivot()).y
	return Vector2(box.position.y - pivot, box.end.y - pivot)


func _pile_height() -> float:
	if _pile.is_empty():
		return 0.0
	return _lifts [_lifts.size() - 1] + _hold_span(_pile [_pile.size() - 1]).y


func _stack_sink() -> float:
	if _pile.size() < 2:
		return 0.0
	return minf(_pile_height() * Cfg.CARRY_STACK_SINK, Cfg.CARRY_STACK_SINK_MAX)


func _stack_lean() -> float:
	return Cfg.CARRY_STACK_LEAN if _pile.size() >= 2 else 0.0


func _stack_side() -> float:
	if _pile.size() < 2:
		return 0.0
	return minf(_pile_height() * Cfg.CARRY_STACK_SIDE, Cfg.CARRY_STACK_SIDE_MAX)


func _stack_forward() -> float:
	if _pile.size() < 2:
		return 0.0
	return minf(_pile_height() * Cfg.CARRY_STACK_FORWARD, Cfg.CARRY_STACK_FORWARD_MAX)


func drop_all() -> void:
	var all:= _pile.duplicate()
	_letting_all_go = true
	while is_carrying():
		drop()
	_letting_all_go = false
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a:= all [i] as Carryable
			var b:= all [j] as Carryable
			if is_instance_valid(a) and is_instance_valid(b):
				_see_each_other(a, b)
	_parting = _parting.filter(func(pair: Array) -> bool:
		return not (pair [0] in all and pair [1] in all))


var _letting_all_go:= false


func target() -> Carryable:
	return _target if is_instance_valid(_target) else null


func _set_target(item: Carryable) -> void:
	if item == _target:
		return
	if is_instance_valid(_target):
		_target.set_highlighted(false)
	_target = item
	if item != null:
		item.set_highlighted(true)


func try_pick(hand_only: bool = false) -> bool:
	if is_carrying() or player == null:
		return false
	var item:= _probe()
	if item == null:


		return _pick_record()
	if hand_only and item.carry_mode() != Carryable.Mode.HELD:
		return false


	if item is ToolProp:
		return _reclaim(item as ToolProp)


	if item is SandShovel:
		return _claim_toy(item as SandShovel)
	return take(item)


func take(item: Carryable) -> bool:
	if is_carrying() or player == null or item == null:
		return false
	_held = item
	_pile = [item]
	_restack()
	_tilt_pitch = 0.0
	_tilt_roll = 0.0
	_sway_pitch = 0.0
	_sway_roll = 0.0
	item.set_highlighted(false)
	item.carrier = player
	item.pick_up()
	if item is SandShovel:
		(item as SandShovel).attach_player(player)
	_have_prev = false
	_have_ground = false


	item.warp(_pose())
	_set_target(null)
	carry_changed.emit(item)
	return true


func _claim_toy(toy: SandShovel) -> bool:

	var id:= toy.item_id
	if not GameState.grant_tool(id):
		return _refuse_owned(id)
	Audio.play_3d("item_pick", toy.global_position, -4.0)
	_set_target(null)
	var props:= player.get_tree().current_scene.get("props") as PropManager
	if props != null:
		props.remove(toy)
	else:
		toy.queue_free()
	player.equip_tool_id(id)
	return true


func _reclaim(prop: ToolProp) -> bool:
	if not prop.claim(player):
		return _refuse_owned(prop.tool_id)
	_set_target(null)
	var props:= player.get_tree().current_scene.get("props") as PropManager
	if props != null:
		props.remove(prop)
	else:
		prop.queue_free()
	return true


func _refuse_owned(id: String) -> bool:
	Audio.play("ui_error")
	if hud == null:
		return false
	if GameState.has_tool(id):
		hud.show_toast(tr("YOU ALREADY HAVE THE %s") % Cfg.upper(ItemDb.display_name(id)))
	else:
		hud.show_toast(tr("YOUR HANDS ARE FULL  ·  PRESS %s TO PUT A TOOL DOWN FIRST")
			% InputSetup.hint("drop_tool"))
	return false


func stow() -> void:
	if not is_carrying():
		return
	var item:= _pop()
	item.release(Vector3.ZERO)
	carry_changed.emit(_held)


func eat_held() -> bool:
	var coin:= held() as ExtraLifeCoin
	if coin == null:
		return false
	_pop()
	coin.eat(player)
	carry_changed.emit(_held)
	return true


func begin_eat() -> bool:
	var coin:= held() as ExtraLifeCoin
	if coin == null:
		return false
	coin.begin_eat()
	return true


func _tick_eat(delta: float) -> void:
	var coin:= _held as ExtraLifeCoin
	if coin == null or not coin.is_eating():
		return
	if not coin.eat_committed() and not Input.is_action_pressed("primary"):
		coin.cancel_eat()
		return
	if coin.tick_eat(delta, player.eye_position()):
		eat_held()


func _refused(item: Carryable) -> bool:


	if item.is_held():
		return true


	var box:= item as HayContainer
	if box != null and box.docked_in != null:
		return true
	if _refused_while_building(item):
		return true
	return item.hay_strands() > 0 and player != null and player.broom != null and player.broom.is_active()


func _refused_while_building(item: Carryable) -> bool:
	return player != null and player.build != null and player.build.is_active() and item.hay_strands() > 0


func toy_in_hand() -> bool:
	return _held is SandShovel


func _probe(stack_only: bool = false) -> Carryable:
	var item:= _probe_ray(stack_only)

	if item == null and not stack_only:
		item = _blade_bundle()
	return item


func _blade_bundle() -> HayWad:
	var wad: HayWad = null
	if toy_in_hand():
		wad = (_held as SandShovel).bundle_under_aim()
	elif not is_carrying():

		if player.shovel != null:
			wad = player.shovel.bundle_under_aim()
		if wad == null and player.pitchfork != null:
			wad = player.pitchfork.bundle_under_aim()
	if wad != null and _refused(wad):
		return null
	return wad


func _probe_ray(stack_only: bool) -> Carryable:
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Tech.carry_reach())


	q.collision_mask = Cfg.L_PROP | Cfg.L_COIN
	q.collide_with_areas = false


	var ex: Array [RID] = []
	for it in _pile:
		if is_instance_valid(it):
			ex.append(it.get_rid())
	q.exclude = ex
	var space:= get_world_3d().direct_space_state
	for _i in PROBE_SKIPS:
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			return null
		var item:= hit.get("collider") as Carryable
		var fits:= item != null and not _refused(item)
		if fits and (not stack_only or item.stacks_in_arms()):
			return item


		ex = q.exclude
		ex.append(hit ["rid"])
		q.exclude = ex
	return null


func _pick_record(onto_stack: bool = false) -> bool:
	var found:= _record_under_crosshair()
	if found.is_empty():
		return false
	var path:= found ["path"] as BeltPath
	var row:= int(found ["row"])
	var kind:= int((found ["record"] as Dictionary) ["kind"])
	if kind < 0 or kind >= BeltRun.ITEM_IDS.size() or _record_refused(kind):
		return false
	var props:= _prop_manager()
	if props == null:
		return false
	var pose: Transform3D = path.run.pose_of(row)
	var rec:= path.take_record_at(row)
	if rec.is_empty():
		return false
	var state: Variant = rec.get("state")
	var item:= props.spawn(BeltRun.ITEM_IDS [kind], pose,
		state if state is Dictionary else { })
	if item == null:


		path.run.board_record(rec, float(rec ["s"]), float(rec ["speed"]), false)
		return false
	if onto_stack:
		if stack_on(item):
			return true
		props.remove(item)
		path.run.board_record(rec, float(rec ["s"]), float(rec ["speed"]), false)
		return false
	return take(item)


func _record_under_crosshair() -> Dictionary:
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Tech.carry_reach())
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return { }
	return BeltPath.record_in(hit ["position"] as Vector3, RECORD_REACH)


func _record_refused(_kind: int) -> bool:
	if player.build != null and player.build.is_active():
		return true
	return player.broom != null and player.broom.is_active()


func _prop_manager() -> PropManager:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PropManager.GROUP) as PropManager


func drop() -> void:
	if not is_carrying():
		return
	var item:= _held


	if item.stays_upright():
		item.level_in_hand()
	_pop()


	if item.carry_mode() == Carryable.Mode.PUSHED:
		item.release(Vector3.ZERO)
		carry_changed.emit(_held)
		return
	_out_of_arms(item)


	if _board_on_belt(item):
		carry_changed.emit(_held)
		return
	_clear_of_pile(item)


	var fwd:= player.look_direction()
	fwd.y = 0.0
	_blind_to_the_tools(item)
	item.release(fwd.normalized() * Cfg.CARRY_DROP_SPEED + Vector3(0, -0.4, 0))
	carry_changed.emit(_held)


func _clear_of_pile(item: Carryable) -> void:
	if _pile.is_empty() or _letting_all_go or player == null or not item.is_inside_tree():
		return
	var xf:= _pose_of(item, 0.0, true)
	var flat:= Basis(Vector3.UP, player.global_rotation.y) * Vector3.FORWARD


	var step:= (item.ride_box().get_longest_axis_size()
		+ _pile [0].ride_box().get_longest_axis_size()) * 0.5 + 0.06
	xf.origin += flat * step
	item.warp(xf)


func _out_of_arms(item: Carryable) -> void:
	if player == null or not item.is_inside_tree():
		return

	var reach:= item.ride_box().get_longest_axis_size() * 0.5
	var at:= item.global_position
	var to:= RoboticArm.clear_of_arms(get_tree(), at, reach, player.global_position)
	if to == at:
		return
	item.global_position = to


	PhysicsServer3D.body_set_state(item.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
		item.global_transform)


func _board_on_belt(item: Carryable) -> bool:
	if BeltPath.record_kind(item) < 0:
		return false
	var at:= item.global_position
	var reach:= float(BeltPath.load_shape(item) ["reach"])
	var belt:= BeltPath.path_under(at, reach, OVER_DECK)
	if belt == null or belt.board_body(item, at) < 0:
		return false


	Audio.play_3d("item_drop", at, -7.0)
	return true


func throw() -> void:
	if not is_carrying():
		return
	if _held.carry_mode() == Carryable.Mode.PUSHED:
		drop()
		return
	var item:= _pop()
	_out_of_arms(item)

	item.tumble()


	_blind_to_the_tools(item)
	item.release(player.look_direction() * Cfg.CARRY_THROW_SPEED + Vector3(0, 1.0, 0),
		Vector3(randfn(0.0, 2.4), randfn(0.0, 2.4), randfn(0.0, 2.4)))


	Audio.play("item_throw", -12.0)
	carry_changed.emit(_held)


func _blind_to_the_tools(item: Carryable) -> void:
	if item == null or player == null:
		return

	Shovel.mark_let_go(item, LET_GO_PAN)
	var blades: Array [AnimatableBody3D] = []
	if player.shovel != null and player.shovel.body != null:
		blades.append(player.shovel.body)
	if player.pitchfork != null and player.pitchfork.body != null:
		blades.append(player.pitchfork.body)
	if blades.is_empty():
		return
	for b in blades:
		item.add_collision_exception_with(b)
	await get_tree().create_timer(LET_GO_BLIND).timeout


	if not is_instance_valid(item):
		return
	for b in blades:
		if is_instance_valid(b):
			item.remove_collision_exception_with(b)


func rotate_input(rel: Vector2) -> void:
	if not is_carrying():
		return

	var lim: Vector3 = _held.tilt_limits()
	_tilt_pitch = clampf(_tilt_pitch + rel.y * Cfg.CARRY_TILT_SENS, - lim.x, lim.y)
	_tilt_roll = clampf(_tilt_roll - rel.x * Cfg.CARRY_TILT_SENS, - lim.z, lim.z)


func _relax_tilt(delta: float) -> void:


	if Input.is_action_pressed("carry_rotate") or Input.is_action_pressed("secondary"):
		return
	var k:= 1.0 - exp(- Cfg.CARRY_TILT_RETURN * delta)
	_tilt_pitch = lerpf(_tilt_pitch, 0.0, k)
	_tilt_roll = lerpf(_tilt_roll, 0.0, k)


func _sway() -> void:
	var amp: float = Cfg.JOSTLE_AMPLITUDE * Tech.jostle_scale() * player.stride()
	var kick:= player.land_kick()
	if _held != null and _held.carry_mode() == Carryable.Mode.PUSHED:
		amp *= Cfg.JOSTLE_PUSHED_SCALE
		kick *= Cfg.JOSTLE_PUSHED_SCALE
	var phase:= player.stride_phase()
	_sway_pitch = sin(phase * 0.5) * amp + kick
	_sway_roll = sin(phase * 0.25) * amp * Cfg.JOSTLE_ROLL_RATIO


func _anchor_point() -> Vector3:
	if _held.carry_mode() == Carryable.Mode.PUSHED:
		return _push_anchor()
	var yaw:= player.global_rotation.y


	if _held.carry_pitches():
		var look:= _look_basis()
		return player.eye_position() + look * Vector3(
			Cfg.CARRY_RIGHT, - Cfg.CARRY_DOWN, - Cfg.CARRY_FORWARD)
	var pitch:= clampf(player.head.rotation.x,
		- Cfg.CARRY_PITCH_LIMIT, Cfg.CARRY_PITCH_LIMIT)
	var aim:= Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	return (player.eye_position() + (aim * Vector3.FORWARD) * Cfg.CARRY_FORWARD
		+ (aim * Vector3.RIGHT) * Cfg.CARRY_RIGHT
		+ Vector3.DOWN * Cfg.CARRY_DOWN)


func _look_basis() -> Basis:
	return Basis(Vector3.UP, player.global_rotation.y) * Basis(Vector3.RIGHT, player.head.rotation.x)


func _push_anchor() -> Vector3:
	var yaw:= player.global_rotation.y
	var flat:= Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var foot:= player.global_position
	var pos:= foot + flat * _push_distance(foot, flat)
	if not _have_ground:
		_ground_y = _sample_ground(pos, flat, foot.y)
		_have_ground = true
	return Vector3(pos.x, _ground_y + _held.carry_pivot().y, pos.z)


func _sample_ground(pos: Vector3, flat: Vector3, fallback: float) -> float:
	var pivot:= _held.carry_pivot()
	return maxf(
		_ground_under(pos + flat * pivot.z, fallback),
		_ground_under(pos + flat * (pivot.z + _held.push_reach() * 0.8), fallback))


func _ground_under(at: Vector3, fallback: float) -> float:
	var from:= Vector3(at.x, fallback + 1.6, at.z)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	return (hit ["position"] as Vector3).y if not hit.is_empty() else fallback


func _push_distance(foot: Vector3, flat: Vector3) -> float:
	var reach: float = _held.push_reach()
	if reach <= 0.0:
		return Cfg.PUSH_DISTANCE
	var room:= minf(_room_ahead(foot, flat, Cfg.L_WORLD | Cfg.L_BUILD, 0.5, reach),
		_pile_room(foot, flat))
	return clampf(room, Cfg.PUSH_MIN_DISTANCE, Cfg.PUSH_DISTANCE)


func _room_ahead(foot: Vector3, flat: Vector3, mask: int, height: float,
		reach: float) -> float:
	var from:= foot + Vector3(0, height, 0)
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + flat * (Cfg.PUSH_DISTANCE + reach))
	q.collision_mask = mask
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	return from.distance_to(hit ["position"]) - reach


func _pile_room(foot: Vector3, flat: Vector3) -> float:
	var reach: float = _held.push_reach()
	if reach <= 0.0:
		return INF
	var far: float = maxf(reach, _held.carry_pivot().z + reach * 0.8)
	return _room_ahead(foot, flat, Cfg.L_PILE, Cfg.PUSH_PILE_STEP, far)


func hold_back(v: Vector3) -> Vector3:
	if player == null or not is_carrying() or not is_instance_valid(_held) or _held.carry_mode() != Carryable.Mode.PUSHED:
		return v
	var flat:= Basis(Vector3.UP, player.global_rotation.y) * Vector3.FORWARD
	var ahead:= v.x * flat.x + v.z * flat.z
	if ahead <= 0.0:
		return v
	if _pile_room(player.global_position, flat) > Cfg.PUSH_DISTANCE:
		return v
	return v - flat * ahead


func _face_basis(fallback: Carryable) -> Basis:
	var base: Carryable = _pile [0] if not _pile.is_empty() else fallback
	if base != null and base.carry_pitches():
		return _look_basis()
	return Basis(Vector3.UP, player.global_rotation.y)


func _hold_basis(solo: bool) -> Basis:
	var lim: float = Cfg.CARRY_TILT_LIMIT
	return (_face_basis(_held) * Basis.from_euler(Vector3(
		clampf(_tilt_pitch + _sway_pitch, - lim, lim), 0.0,
		clampf(_tilt_roll + _sway_roll, - lim, lim)))
		* Basis(Vector3.RIGHT, 0.0 if solo else _stack_lean()))


func _pose() -> Transform3D:
	return _pose_of(_held, _lifts [_lifts.size() - 1] if not _lifts.is_empty() else 0.0)


func _pose_of(item: Carryable, lift: float, solo: bool = false) -> Transform3D:
	var face:= _face_basis(item)


	var spin:= item.carry_aim() * Basis(Vector3.UP, item.carry_yaw())
	var hold:= _hold_basis(solo)
	var level:= face * spin
	var tilted:= hold * spin
	var tp:= item.tilt_pivot()


	var anchor:= _anchor_point()
	if not solo:
		anchor += (hold.x * _stack_side() - hold.y * _stack_sink()
			- hold.z * _stack_forward())

	var hinge:= anchor - level * item.carry_pivot() + level * tp

	var xf:= Transform3D(tilted, hinge - tilted * tp)


	xf.origin += hold.y * lift
	return xf


func rip_target() -> Carryable:
	var item:= held()
	if item == null:
		item = target()
	if item == null or not item.can_rip():
		return null


	if item != held() and _building_before(item):
		return null
	return item


func _building_before(item: Carryable) -> bool:
	if player == null or player.build == null or player.build.dismantle_target() == null:
		return false
	var from:= player.eye_position()
	var reach:= from.distance_to(item.global_position)
	var q:= PhysicsRayQueryParameters3D.create(from, from + player.look_direction() * reach)
	q.collision_mask = Cfg.L_BUILD


	q.collide_with_areas = true
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func rip_progress() -> float:
	if _rip == null:
		return -1.0
	return clampf(_rip_time / RIP_HOLD, 0.0, 1.0)


func _tick_rip(delta: float) -> void:
	var item:= rip_target()
	if item == null or not Input.is_action_pressed("dismantle") or not player.is_mouse_captured():
		_rip = null
		_rip_time = 0.0
		return


	if item != _rip:
		_rip = item
		_rip_time = 0.0
	_rip_time += delta
	if _rip_time < RIP_HOLD:
		return
	_rip = null
	_rip_time = 0.0


	var props:= player.get_tree().current_scene.get("props") as PropManager
	if props != null:
		props.rip(item)


func _process(delta: float) -> void:
	if player == null:
		return
	_prune()
	_tick_rip(delta)
	if is_carrying():
		_relax_tilt(delta)
		_sway()
		_ease_ground(delta)


		_write_poses()
		for it in _pile:
			it.on_drawn()

		_tick_eat(delta)


		if not toy_in_hand():
			if stack_has_room():
				_full_latched = false
				_since += delta
				if _since >= TARGET_REFRESH:
					_since = 0.0
					_set_target(_probe(true))
			else:
				_set_target(null)
				_look_while_full(delta)
			return
	else:


		_held = null
	_since += delta
	if _since >= TARGET_REFRESH:
		_since = 0.0
		_set_target(_probe())


func since_full() -> float:
	if full_msec < 0:
		return INF
	return float(Time.get_ticks_msec() - full_msec) / 1000.0


func _look_while_full(delta: float) -> void:
	if _held == null or not _held.stacks_in_arms():
		_full_latched = false
		return
	_since += delta
	if _since < TARGET_REFRESH:
		return
	_since = 0.0
	var item:= _probe_ray(true)
	if item == null:
		_full_latched = false
		return
	full_msec = Time.get_ticks_msec()
	full_cap = stack_capacity()
	if not _full_latched:
		_full_latched = true
		arms_full += 1


func _write_poses() -> void:
	for i in _pile.size():
		_pile [i].global_transform = _pose_of(_pile [i], _lifts [i])


func _prune() -> void:
	if _pile.is_empty():
		return
	var stale:= false
	for it in _pile:
		if not is_instance_valid(it) or not it.is_held():
			stale = true
			break
	if not stale:
		return
	var kept: Array [Carryable] = []
	var gone: Array [Carryable] = []
	for it in _pile:
		if is_instance_valid(it) and it.is_held():
			kept.append(it)
		elif is_instance_valid(it):
			gone.append(it)


	for it in gone:
		for other in kept:
			_parting.append([it, other])
	_pile = kept
	_held = _pile [_pile.size() - 1] if not _pile.is_empty() else null
	_restack()
	_have_prev = false


func _ease_ground(delta: float) -> void:
	if not _have_ground or _held.carry_mode() != Carryable.Mode.PUSHED:
		return
	var yaw:= player.global_rotation.y
	var flat:= Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var foot:= player.global_position
	var pos:= foot + flat * _push_distance(foot, flat)
	_ground_y = lerpf(_ground_y, _sample_ground(pos, flat, foot.y),
		1.0 - exp(- Cfg.PUSH_GROUND_FOLLOW * delta))


func _physics_process(delta: float) -> void:


	_tick_parting()
	if not is_carrying() or player == null:
		return
	_prune()
	if not is_carrying():
		return


	var base_xf:= _pose_of(_pile [0], 0.0)
	var moved:= Transform3D.IDENTITY
	if _have_prev:
		moved = base_xf * _prev_xform.affine_inverse()
	for i in _pile.size():
		var xf:= base_xf if i == 0 else _pose_of(_pile [i], _lifts [i])
		_pile [i].global_transform = xf
		_pile [i].on_carried(xf, moved, delta)
	_prev_xform = base_xf
	_have_prev = true


func _exit_tree() -> void:

	if is_instance_valid(_target):
		_target.set_highlighted(false)
