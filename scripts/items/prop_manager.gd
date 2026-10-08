class_name PropManager
extends Node3D


signal changed()


signal item_added(item: Carryable)
signal item_removed(item: Carryable)


const META_CLAIM:= "prop_claim"


const GROUP:= "prop_manager"


var live: LiveStrandManager


var truck: DeliveryTruck

var items: Array [Carryable] = []


var demo_withheld: Array [Dictionary] = []


func _ready() -> void:
	add_to_group(GROUP)
	warm_up()


static func warm_up() -> void:
	HayWad.warm_up()
	HayBale.warm_up()
	FoiledBale.warm_up()
	EcoBrick.warm_up()
	PaperRoll.warm_up()
	HayPulp.warm_up()


func spawn(id: String, xform: Transform3D, state: Dictionary = { }) -> Carryable:
	var item:= ItemDb.make(id)
	if item == null:
		return null
	if item is HayContainer:
		(item as HayContainer).live = live
	items.append(item)
	add_child(item)


	item.tree_exited.connect(_forget.bind(item))
	item.global_transform = xform
	if not state.is_empty():
		item.from_state(state)


		item.needle_index = int(state.get("needle", -1))


	LiveStrandManager.hold(item, Cfg.PROP_BIRTH_GRACE)
	item_added.emit(item)
	changed.emit()
	return item


func spawn_at_feet(id: String, player: Node3D) -> Carryable:
	return spawn_near(id, player, 0.62, 0.12)


func place_at_feet(item: Carryable, player: Node3D, index: int = 0) -> void:
	if not is_instance_valid(item):
		return
	var fwd:= - player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-06 else Vector3.FORWARD


	var spread:= deg_to_rad(38.0) * (float(index >> 1) + 1.0) * (1.0 if index % 2 == 0 else -1.0)
	var out:= fwd.rotated(Vector3.UP, 0.0 if index == 0 else spread)
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.global_transform = Transform3D(
		Basis(Vector3.UP, atan2(- out.x, - out.z)),
		player.global_position + out * 0.72 + Vector3(0, 0.14, 0))
	item.sleeping = false


func spawn_near(id: String, player: Node3D, distance: float = 1.5,
		height: float = 0.9) -> Carryable:
	var fwd:= - player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-06 else Vector3.FORWARD
	var pos:= player.global_position + fwd * distance + Vector3(0, height, 0)


	var b:= Basis(Vector3.UP, atan2(- fwd.x, - fwd.z))
	return spawn(id, Transform3D(b, pos))


func remove(item: Carryable) -> void:
	var i:= items.find(item)
	if i < 0:
		return
	items.remove_at(i)


	HayContainer.support_gone(item.global_position, 1.2)
	remove_child(item)
	item.queue_free()
	item_removed.emit(item)
	changed.emit()


func rip(item: Carryable) -> RigidBody3D:
	if item == null or not is_instance_valid(item) or not item.can_rip():
		return null


	BeltPath.release(item)


	if item.carrier != null and item.carrier.carry != null and item.carrier.carry.held() == item:
		item.carrier.carry.stow()
	var at:= item.global_position
	var basis:= item.global_basis.orthonormalized()
	var count:= item.rip_yield()
	var index:= item.needle_index
	var what:= item.item_id


	var loose:= item.rips_loose()
	var shreds:= item.rips_to_shreds()
	var box:= item.clearance_size()


	item.needle_index = -1
	remove(item)
	if shreds:


		ShredBurst.play(at, basis, box, self)


		Audio.play_3d("paper_tear", at + Vector3.UP * 0.3, -3.0)
	elif count > 0 and loose:
		_spill_loose(count, at, basis)
		Audio.play_3d("hay_dump", at + Vector3.UP * 0.3, -4.0)
	else:
		if count > 0:
			var wad:= spawn("hay_wad", Transform3D(basis, at + Vector3.UP * 0.05),
				{ "strands": count }) as HayWad
			if wad == null:


				push_warning("PropManager: no room for the wad from a ripped %s" % what)
		Audio.play_3d("hay_dump", at + Vector3.UP * 0.3, -4.0)
	if index < 0 or live == null:
		return null


	var needle:= live.reveal_needle(index, at + Vector3.UP * 0.45)
	if needle != null:
		Audio.play_3d("needle_ting", at + Vector3.UP * 0.45, -4.0)
	return needle


func _spill_loose(count: int, at: Vector3, basis: Basis) -> int:
	if live == null:
		GameState.return_hay(float(count))
		return 0
	if _spill_rng == null:
		_spill_rng = RandomNumberGenerator.new()
		_spill_rng.randomize()
	var half:= Cfg.WAD_BASE_SIZE * HayWad.scale_for(count) * 0.5
	var made:= 0
	for _i in count:
		var offset:= Vector3(
			_spill_rng.randf_range(- half.x, half.x),
			half.y + _spill_rng.randf_range(0.0, half.y),
			_spill_rng.randf_range(- half.z, half.z))
		var p:= at + basis * offset


		var out:= p - at
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 1e-06 else Vector3.ZERO
		var v:= out * _spill_rng.randf_range(0.3, 1.1) + Vector3.UP * _spill_rng.randf_range(0.4, 1.2)
		if live.spawn(p, StrandFactory.random_strand_basis(_spill_rng), v,
				StrandFactory.random_tint(_spill_rng)) == null:
			GameState.return_hay(float(count - made))
			return made
		made += 1
	return made


var _spill_rng: RandomNumberGenerator = null


func _forget(item: Carryable) -> void:
	var i:= items.find(item)
	if i < 0:
		return
	items.remove_at(i)
	_still_at.erase(item.get_instance_id())
	_still_for.erase(item.get_instance_id())
	item_removed.emit(item)
	changed.emit()


func clear() -> void:

	demo_withheld.clear()


	var doomed:= items.duplicate()
	items.clear()
	_still_at.clear()
	_still_for.clear()
	for item in doomed:
		remove_child(item)
		item.queue_free()


	for child in get_children():
		if child is PropFold:
			child.queue_free()
	changed.emit()


func count_of(id: String) -> int:
	var n:= 0
	for item in items:
		if item.item_id == id:
			n += 1
	return n


var player_ref: Node3D = null


var _scan_left:= 0.0


var _since_pass:= 0.0


var _still_at: Dictionary = { }
var _still_for: Dictionary = { }


var clean_blocked:= false


func _process(delta: float) -> void:
	_scan_left -= delta
	_since_pass += delta
	if _scan_left > 0.0:
		return
	_scan_left = Cfg.PROP_SCAN_PERIOD
	var step:= _since_pass
	_since_pass = 0.0
	_tuft_pass()
	if Cfg.prop_decay:
		_drain_pass()
	if Cfg.auto_clean and not clean_blocked:
		_clean_pass(step)
	elif not _still_at.is_empty():


		_still_at.clear()
		_still_for.clear()


func _clean_pass(step: float) -> void:
	var doomed: Array [Carryable] = []
	var move2:= Cfg.AUTO_CLEAN_MOVE * Cfg.AUTO_CLEAN_MOVE
	for item in items:
		if not is_instance_valid(item):
			continue
		var id:= item.get_instance_id()
		if item.is_held() or BeltPath.is_rider(item) or item.hay_strands() <= 0:
			_still_at.erase(id)
			_still_for.erase(id)
			continue
		var here:= item.global_position
		if not _still_at.has(id) or here.distance_squared_to(_still_at [id]) > move2:
			_still_at [id] = here
			_still_for [id] = 0.0
			continue
		var lain: float = _still_for [id] + step
		_still_for [id] = lain
		if lain >= Cfg.auto_clean_seconds and doomed.size() < Cfg.AUTO_CLEAN_PER_PASS and not is_spoken_for(item):
			doomed.append(item)


	for item in doomed:
		fold_away(item)


func _tuft_pass() -> void:
	var lying: Array [HayTuft] = []
	for t in HayTuft.all:
		if is_instance_valid(t) and t.is_inside_tree() and not t.is_held() and not BeltPath.is_rider(t):
			lying.append(t)
	var over:= lying.size() - Cfg.TUFT_FLOOR_CAP
	if over <= 0:
		return
	var budget:= mini(over, Cfg.PROP_DRAIN_PER_PASS)

	for t in lying:
		if budget <= 0:
			break
		if is_spoken_for(t) or not items.has(t):
			continue
		fold_away(t)
		budget -= 1


func yard_count() -> int:
	var n:= 0
	for item in items:
		if is_instance_valid(item) and not BeltPath.is_rider(item):
			n += 1
	return n


func _drain_pass() -> void:
	var count:= yard_count()
	if count <= Cfg.prop_cap:
		return
	var here:= player_ref.global_position if is_instance_valid(player_ref) else Vector3.ZERO
	var keep2:= Cfg.PROP_KEEP_DIST * Cfg.PROP_KEEP_DIST
	var budget: int = mini(count - Cfg.prop_cap, Cfg.PROP_DRAIN_PER_PASS)
	var took:= 0
	var i:= 0


	while took < budget and i < items.size():
		var item:= items [i]
		if not is_instance_valid(item) or not _may_retire(item, here, keep2):
			i += 1
			continue


		fold_away(item)
		took += 1
	if took < budget:
		_drain_the_sheltered(budget - took, here)


func _drain_the_sheltered(budget: int, here: Vector3) -> void:


	var pool: Array [Carryable] = []
	var far: PackedFloat32Array = PackedFloat32Array()
	for item in items:
		if not is_instance_valid(item) or not _may_retire_anywhere(item):
			continue
		pool.append(item)
		far.append(item.global_position.distance_squared_to(here))
	for n in budget:
		var worst:= -1
		var worst_d2:= -1.0
		for j in pool.size():
			if far [j] > worst_d2:
				worst_d2 = far [j]
				worst = j
		if worst < 0:
			return
		var item:= pool [worst]
		pool.remove_at(worst)
		far.remove_at(worst)
		fold_away(item)


func fold_away(item: Carryable) -> void:
	_credit_hay(item)
	PropFold.play(item, self)
	remove(item)


func sweep_floor() -> int:
	var doomed: Array [Carryable] = []
	for item in items:
		if not is_instance_valid(item):
			continue
		if not _may_retire_anywhere(item):
			continue
		doomed.append(item)


	for item in doomed:
		fold_away(item)
	return doomed.size()


func _may_retire(item: Carryable, here: Vector3, keep2: float) -> bool:
	if not _may_retire_anywhere(item):
		return false
	if _on_a_machines_ground(item.global_position):
		return false
	if _arm_shelter().has(item.get_instance_id()):
		return false
	return item.global_position.distance_squared_to(here) >= keep2


func _may_retire_anywhere(item: Carryable) -> bool:
	return item.hay_strands() > 0 and not is_spoken_for(item)


func is_spoken_for(item: Carryable) -> bool:


	if item.holds_needle():
		return true
	if item.is_held():
		return true
	if BeltPath.is_rider(item):
		return true
	if LiveStrandManager.is_on_hold(item):
		return true
	if item.has_meta(META_CLAIM):
		var owner_node:= instance_from_id(int(item.get_meta(META_CLAIM)))
		if owner_node != null and is_instance_valid(owner_node):
			return true


	if is_order_stock(item):
		return true
	return false


func is_order_stock(item: Carryable) -> bool:
	if truck == null or not is_instance_valid(truck):
		return false
	if not DeliveryBook.wanted_now(item.item_id):
		return false
	var r:= Cfg.DELIVERY_STOCK_R
	return item.global_position.distance_squared_to(truck.bay_point()) < r * r


const WORK_SPOT_R:= 2.2


func _on_a_machines_ground(at: Vector3) -> bool:
	var builds:= _build_manager()
	if builds == null:
		return false
	var r2:= WORK_SPOT_R * WORK_SPOT_R
	for rake: Node3D in builds.get("piston_rakes"):
		if is_instance_valid(rake) and rake.has_method("discharge_spot") and at.distance_squared_to(rake.call("discharge_spot")) < r2:
			return true
	for mill: Node3D in builds.get("pelletizers"):
		if is_instance_valid(mill) and mill.has_method("throw_target") and at.distance_squared_to(mill.call("throw_target")) < r2:
			return true
	return false


func _arm_shelter() -> Dictionary:
	var now:= Engine.get_process_frames()
	if _shelter_frame == now:
		return _shelter
	_shelter_frame = now
	_shelter = { }
	var builds:= _build_manager()
	if builds == null:
		return _shelter
	var spots: Array [Vector3] = []
	var radii: Array [float] = []
	var used:= PackedInt32Array()
	for arm: Node3D in builds.get("robotic_arms"):
		if not is_instance_valid(arm) or not arm.has_method("reach_m"):
			continue
		spots.append(arm.global_position)
		radii.append(pow(float(arm.call("reach_m")) + WORK_SPOT_R, 2.0))
		used.append(0)
	if spots.is_empty():
		return _shelter
	var full:= 0
	for i in range(items.size() - 1, -1, -1):
		if full >= spots.size():
			break
		var item:= items [i]
		if not is_instance_valid(item):
			continue
		var at:= item.global_position
		var inside:= -1
		for a in spots.size():
			if used [a] < Cfg.ARM_PAD_WADS and at.distance_squared_to(spots [a]) < radii [a]:
				inside = a
				break
		if inside < 0:
			continue


		if item.hay_strands() <= 0 or is_spoken_for(item):
			continue
		used [inside] += 1
		if used [inside] >= Cfg.ARM_PAD_WADS:
			full += 1
		_shelter [item.get_instance_id()] = true
	return _shelter


var _shelter: Dictionary = { }
var _shelter_frame:= -1


var _builds_cache: Node = null


func _build_manager() -> Node:
	if is_instance_valid(_builds_cache):
		return _builds_cache
	_builds_cache = null
	var parent:= get_parent()
	if parent == null:
		return null
	for sibling in parent.get_children():
		if sibling is BuildManager:
			_builds_cache = sibling
			return _builds_cache
	return null


func _credit_hay(item: Carryable) -> void:
	GameState.return_hay(float(item.hay_strands()))


func to_array() -> Array:
	var out: Array = []
	for item in items:
		if not is_instance_valid(item):
			continue


		if not item.is_inside_tree():
			continue


		if item is SandShovel and item.carrier != null:
			continue
		var state: Dictionary = item.to_state()


		if item.holds_needle():
			state ["needle"] = item.needle_index
		out.append({
			"id": item.item_id,
			"xform": item.global_transform,
			"state": state,
		})
	out.append_array(demo_withheld)
	return out


func from_array(data: Array) -> void:
	clear()
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var id: String = d.get("id", "")
		if not ItemDb.has_item(id):
			push_warning("PropManager: unknown item '%s' in save" % id)
			continue
		if Cfg.DEMO and id in GameState.DEMO_WITHHELD_TOOLS:
			demo_withheld.append(d)
			continue
		spawn(id, d.get("xform", Transform3D.IDENTITY), d.get("state", { }))
