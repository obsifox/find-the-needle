class_name DevDronePathProbe
extends Node


const DURATION:= 420.0

const STALL_LIMIT:= 14.0

const CLIP_SLACK:= 0.08

const PILE_SLACK:= 0.05

const FLEET:= 10
const CALM_WINDOW:= 60
const CALM_TOLERANCE:= 0.05
const CALM_LIMIT:= 4000

var world: Node3D
var player: Player

var _field: HayField
var _builds: BuildManager
var _props: PropManager
var _space: PhysicsDirectSpaceState3D
var _plate:= Vector3.INF
var _toe:= 0.0
var _taken: Array [Vector3] = []
var _runs: Array [Dictionary] = []
var _exclude: Array [RID] = []
var _box:= BoxShape3D.new()
var _box_centre:= Vector3.ZERO
var _query:= PhysicsShapeQueryParameters3D.new()
var _load_ball:= SphereShape3D.new()
var _load_query:= PhysicsShapeQueryParameters3D.new()
var _t:= 0.0
var _flying:= false
var _fails:= 0
var _min_sep:= INF
var _min_sep_where:= ""
var _contacts:= 0
var _contact_first:= ""
var _next_tidy:= 0.0
var _next_stock:= 0.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	_field = world.get("field")
	_builds = world.get("builds")
	_props = world.get("props")
	_space = world.get_world_3d().direct_space_state
	GameState.add_money(5000000.0)


	Tech.grant("drone", 1)
	Tech.grant("drone_radius", Cfg.DRONE_RADIUS_RANKS)
	var spec:= Cfg.pile_size_spec(Cfg.pile_size_id)
	_toe = float(spec.get("toe", _field.crust_radius))
	print("\n=== drone paths, %s pile ===" % Cfg.pile_size_id)
	await _wait_for_calm()
	var stand: HaySellingStand = world.get("stand")
	_plate = stand.delivery_point()
	print("  peak %.1f m, toe %.1f m, shed inner %.1f m, range %.1f m, zones up to %.1f m"
		% [_field.height_at(0.0, 0.0), _toe, Cfg.yard_inner_for_pile(),
			Tech.drone_radius(), Tech.drone_zone_max()])
	if player != null:
		player.global_position = Vector3(_plate.x, 0.4, _plate.z) + Vector3(0.0, 0.0, 3.0)
		player.set_process(false)
		player.set_physics_process(false)


	await _build_awkward()
	await _build_fleet()
	for i in 90:
		await get_tree().physics_frame
	_measure_airframe()
	HayDrone.cost_plan_us = 0
	HayDrone.cost_plan_worst = 0
	HayDrone.cost_pick_us = 0
	HayDrone.cost_pick_worst = 0
	HayDrone.cost_traffic_us = 0
	HayDrone.cost_traffic_worst = 0
	HayDrone.cost_frame_us = 0


	for r: Dictionary in _runs:
		var d: HayDrone = r ["drone"]
		d.plan_now()
		r ["plans0"] = d.plans
		r ["refused"] = d._route_why
	print("\n  %d drones set up; flying %.0f s of game time, lane gap %.2f m, v_sep %.2f m"
		% [_runs.size(), DURATION, HayDrone.lane_gap(), HayDrone.v_sep()])
	_flying = true
	var frames:= 0
	while _t < DURATION:
		await get_tree().process_frame
		frames += 1
	_flying = false
	_report(frames)
	print("\n[dronepath] %s  %d drones, %d failed checks, %s pile"
		% ["PASS" if _fails == 0 else "FAIL", _runs.size(), _fails, Cfg.pile_size_id])
	world.set("block_save", true)
	get_tree().quit(0 if _fails == 0 else 1)


func _wait_for_calm() -> void:
	var waited:= 0
	var previous:= -1.0
	while waited < CALM_LIMIT:
		var started:= Time.get_ticks_usec()
		for i in CALM_WINDOW:
			await get_tree().process_frame
		waited += CALM_WINDOW
		var ms:= float(Time.get_ticks_usec() - started) / 1000.0 / CALM_WINDOW
		var preparing: bool = bool(_field.get("_preparing_dome"))
		if not preparing and previous > 0.0 and absf(ms - previous) <= previous * CALM_TOLERANCE:
			print("  the yard went still after %d frames." % waited)
			return
		previous = ms
	print("  the yard never went still: gave up after %d frames." % waited)


func _build_fleet() -> void:
	for i in FLEET:
		var a:= TAU * float(i) / float(FLEET) + 0.21
		var pad:= _find_floor(Vector3(cos(a), 0.0, sin(a)) * (_toe + 3.2), 1.6)
		if pad == Vector3.INF:
			continue
		var collect:= i % 3 == 2
		var d:= _new_drone(pad)
		d.set_mode(HayDrone.Mode.COLLECT if collect else HayDrone.Mode.DIG)
		var zone:= Vector3.INF
		var r:= 2.5
		if collect:
			zone = _floor_zone_for(d, pad, 2.0)
			r = 2.0
		else:


			var pa:= atan2(pad.z, pad.x)
			r = 2.0
			var rings: Array [float] = [maxf(_toe - 2.8, 1.5), maxf(_toe - 5.5, 1.2)]
			if i % 2 == 1:
				rings.reverse()
			for ring: float in rings:
				for swing: float in [1.05, -1.05, 0.7, -0.7, 1.4, -1.4, 0.35, -0.35, 0.0]:
					var za:= pa + swing
					var zp:= Vector3(cos(za), 0.0, sin(za)) * ring
					if d.zone_refusal(zp, r) == "":
						zone = zp
						break
				if zone != Vector3.INF:
					break
		if zone == Vector3.INF or d.set_zone(zone, r) != "":
			print("  skip fleet %d: no zone for the pad at %v" % [i, pad])
			_builds.demolish(d)
			continue
		var drop:= _drop_for(d, pad)
		if drop == Vector3.INF or d.set_drop(drop, HayDrone.Drop.FLOOR) != "":
			print("  skip fleet %d: no drop near the pad at %v" % [i, pad])
			_builds.demolish(d)
			continue
		_add_run("%s %d" % ["collect" if collect else "dig", i], d, false)
		await get_tree().physics_frame


func _build_awkward() -> void:
	var deck_y:= HayLift.deck_top_for(0.0, 1)
	var behind:= - Vector3(_plate.x, 0.0, _plate.z).normalized()
	var at:= _find_floor(behind.rotated(Vector3.UP, 0.5) * (_toe + 3.5), 2.8)
	if at != Vector3.INF:
		var d:= _new_drone(at)

		d.set_mode(HayDrone.Mode.COLLECT)
		var zp:= _floor_zone_for(d, at, 1.5)
		var zone_said:= d.set_zone(zp, 1.5) if zp != Vector3.INF else "no floor"
		var dp:= _drop_for(d, at)
		var drop_said:= d.set_drop(dp, HayDrone.Drop.FLOOR) if dp != Vector3.INF else "no floor"
		var job:= zone_said == "" and drop_said == ""
		if not job:
			print("  under a deck: zone %s, drop %s" % [zone_said, drop_said])


		_builds.add_platform(Vector3(at.x, deck_y, at.z), Vector2(4.0, 4.0))
		await get_tree().physics_frame
		if job:
			_add_run("under a deck", d, true)
		else:
			print("  skip under a deck: no job fits")
			_builds.demolish(d)

	at = _find_floor(behind.rotated(Vector3.UP, -0.5) * (_toe + 3.5), 1.6)
	if at != Vector3.INF:
		var d:= _new_drone(at)
		d.set_mode(HayDrone.Mode.COLLECT)
		var placed:= false
		for k in 16:
			var a:= TAU * float(k) / 16.0
			var far:= at + Vector3(cos(a), 0.0, sin(a)) * 7.5
			var mid:= (at + far) * 0.5
			if _floor_disc(far, 2.0, 2.4) == INF or _floor_disc(mid, 2.4, 2.4) == INF:
				continue
			far.y = 0.0
			if d.zone_refusal(far, 1.5) != "":
				continue
			_builds.add_silo(Vector3(mid.x, 0.0, mid.z), 0.0)
			await get_tree().physics_frame
			var zone_said:= d.set_zone(far, 1.5)
			var dp:= _drop_for(d, at)
			var drop_said:= d.set_drop(dp, HayDrone.Drop.FLOOR) if dp != Vector3.INF else "no floor"
			placed = zone_said == "" and drop_said == ""
			if not placed:
				print("  over a silo: zone %s, drop %s" % [zone_said, drop_said])
			break
		if placed:
			_add_run("over a silo", d, false)
		else:
			print("  skip over a silo: no job fits")
			_builds.demolish(d)
	_builds.changed.emit()


func _new_drone(pad: Vector3) -> HayDrone:
	var d: HayDrone = _builds.add_hay_drone(pad, 0.0, 0.0)
	d.power_ports()
	d.set_power(1.0)
	_taken.append(pad)
	return d


func _floor_zone_for(d: HayDrone, pad: Vector3, r: float) -> Vector3:
	for ring: float in [5.0, 6.5, 8.0, 10.0]:
		for k in 16:
			var a:= TAU * float(k) / 16.0
			var p:= pad + Vector3(cos(a), 0.0, sin(a)) * ring
			if _floor_disc(p, r + 0.3, r + 0.5) == INF:
				continue
			p.y = 0.0
			if d.zone_refusal(p, r) == "":
				return p
	return Vector3.INF


func _drop_for(d: HayDrone, pad: Vector3) -> Vector3:
	for ring: float in [2.8, 3.6, 4.5, 5.5, 7.0]:
		for k in 16:
			var a:= TAU * float(k) / 16.0
			var p:= pad + Vector3(cos(a), 0.0, sin(a)) * ring
			var y:= _floor_disc(p, 1.6, 1.8)
			if y == INF:
				continue
			p.y = y
			if d.drop_refusal(p) != "":
				continue


			if not d.has_job() or d.zone_at == Vector3.INF:
				return p
			if d.set_drop(p, HayDrone.Drop.FLOOR) == "" and d._route_why == "":
				return p
	return Vector3.INF


func _wall_distance(from: Vector3, dir: Vector3, skip: float) -> float:
	var start:= from + dir * skip
	var ray:= PhysicsRayQueryParameters3D.create(start, start + dir * 200.0)
	ray.collision_mask = Cfg.L_WORLD
	var hit: Dictionary = _space.intersect_ray(ray)
	if hit.is_empty():
		return 200.0
	return skip + (hit ["position"] as Vector3).distance_to(start)


func _find_floor(want: Vector3, need: float, wall: float = -1.0) -> Vector3:
	if wall < 0.0:
		wall = need
	var ring:= 0.0
	while ring <= 12.0:
		var steps:= maxi(1, int(TAU * ring / 0.5))
		for i in steps:
			var t:= TAU * float(i) / float(steps)
			var p:= Vector3(want.x + cos(t) * ring, 0.0, want.z + sin(t) * ring)
			var floor_y:= _floor_disc(p, need, wall)
			if floor_y == INF:
				continue
			var ok:= true
			var bay:= _bay_point()
			if bay != Vector3.INF and Vector2(bay.x - p.x, bay.z - p.z).length() < Cfg.DELIVERY_STOCK_R + 2.0:
				ok = false
			if Vector2(_plate.x - p.x, _plate.z - p.z).length() < 6.0:
				ok = false
			for q in _taken:
				if Vector2(q.x - p.x, q.z - p.z).length() < 4.5:
					ok = false
					break
			if ok and HayDrone.pad_refusal(p) != "":
				ok = false
			if ok and not _pad_clear(Vector3(p.x, floor_y, p.z)):
				ok = false
			if ok:
				return Vector3(p.x, floor_y + 0.02, p.z)
		ring += 0.5
	print("  no floor near %v for a %.1f m disc" % [want, need])
	return Vector3.INF


func _bay_point() -> Vector3:
	var truck: DeliveryTruck = _props.truck
	if truck == null or not is_instance_valid(truck):
		return Vector3.INF
	return truck.bay_point()


func _floor_disc(p: Vector3, need: float, wall: float) -> float:

	var inner: float = (world.get("warehouse") as Warehouse).inner - 1.6
	if absf(p.x) > inner or absf(p.z) > inner:
		return INF
	var floor_y:= INF
	for k in 9:
		var off:= Vector3.ZERO
		if k > 0:
			var t:= TAU * float(k - 1) / 8.0
			off = Vector3(cos(t), 0.0, sin(t)) * need
		var at:= p + off
		if _field.height_at(at.x, at.z) > 0.05:
			return INF
		var ray:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at + Vector3.DOWN)
		ray.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
		var hit: Dictionary = _space.intersect_ray(ray)
		if hit.is_empty():
			return INF
		var y: float = (hit ["position"] as Vector3).y
		if y > 0.2 or y < -0.03:
			return INF
		floor_y = minf(floor_y, y)
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var from:= p + Vector3.UP
		var ray:= PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
		ray.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
		var hit: Dictionary = _space.intersect_ray(ray)
		if hit.is_empty() or (hit ["position"] as Vector3).distance_to(from) < wall:
			return INF
	return floor_y


func _pad_clear(at: Vector3) -> bool:
	var probe:= BoxShape3D.new()
	probe.size = Vector3(3.1, 1.1, 3.1)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.62)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
	return _space.intersect_shape(q, 1).is_empty()


func _add_run(label: String, d: HayDrone, grounded: bool) -> void:
	var pad:= d.global_position
	var over:= PhysicsRayQueryParameters3D.create(pad + Vector3.UP * 1.3, pad + Vector3.UP * 80.0)
	over.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	var roof: Dictionary = _space.intersect_ray(over)
	var head:= "open sky" if roof.is_empty() else "%.1f m of headroom" % ((roof ["position"] as Vector3).y - pad.y)
	print("  %-14s pad %v, zone %.1f m off (r %.1f), drop %.1f m off, %s, route %s legs %s"
		% [label, pad.snapped(Vector3.ONE * 0.1), _flat(d.zone_at, pad), d.zone_r,
			_flat(d.drop_at, pad), head, d._route_why if d._route_why != "" else "ok",
			str(d._leg_y)])
	_runs.append({
		"label": label, "drone": d, "progress_t": 0.0, "sig": "",
		"worst_stall": 0.0, "worst_where": "", "worked": 0.0, "first_trip": -1.0,
		"held": null, "releases": d._releases, "phase": -1,
		"clip": 0, "clip_first": "", "pile_clip": 0, "pile_first": "",
		"load_clip": 0, "load_first": "", "stray": 0, "stray_first": "",
		"under": 0, "under_first": "", "clip_by": { }, "signs": { },
		"work_seen": false, "work_check": 0, "plans0": d.plans, "grounded": grounded,
	})


func _measure_airframe() -> void:
	for d: HayDrone in _builds.hay_drones:
		for body in _collision_objects(d):
			_exclude.append(body)
	if _runs.is_empty():
		return
	var d: HayDrone = _runs [0] ["drone"]
	var model: Node3D = d._model
	var inv:= model.global_transform.affine_inverse()
	var box:= AABB()
	var first:= true
	var stack: Array [Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == HayDrone.N_HOOK or node.name == HayDrone.N_CABLE:
			continue
		var mi:= node as MeshInstance3D
		if mi != null and mi.mesh != null:
			var local:= (inv * mi.global_transform) * mi.mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		for kid: Node in node.get_children():
			stack.append(kid)
	_box.size = (box.size - Vector3.ONE * CLIP_SLACK * 2.0).max(Vector3.ONE * 0.05)
	_box_centre = box.get_center()
	_query.shape = _box
	_query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	_query.exclude = _exclude
	_load_ball.radius = 0.28
	_load_query.shape = _load_ball
	_load_query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	_load_query.exclude = _exclude
	print("  airframe box %v centred %v in the model's space (hook and cable left out)"
		% [box.size, box.get_center()])


func _collision_objects(root: Node) -> Array [RID]:
	var out: Array [RID] = []
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var co:= node as CollisionObject3D
		if co != null:
			out.append(co.get_rid())
		for kid: Node in node.get_children():
			stack.append(kid)
	return out


static func _flat(a: Vector3, b: Vector3) -> float:
	if a == Vector3.INF or b == Vector3.INF:
		return INF
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(delta: float) -> void:
	if not _flying:
		return
	_t += delta


	if _t >= _next_tidy:
		_next_tidy = _t + 25.0
		_tidy_drops()
	if _t >= _next_stock:
		_next_stock = _t + 9.0
		_stock_collect_zones()
	for r: Dictionary in _runs:
		_watch(r, delta)
	_separation()


func _tidy_drops() -> void:
	for r: Dictionary in _runs:
		var d: HayDrone = r ["drone"]
		if not is_instance_valid(d) or d.drop_at == Vector3.INF:
			continue
		for item: Carryable in _props.items.duplicate():
			if is_instance_valid(item) and not item.is_held() and not BeltPath.is_rider(item) and _flat(item.global_position, d.drop_at) < 2.4:
				_props.remove(item)


func _stock_collect_zones() -> void:
	var kinds:= ["hay_bale", "eco_brick", "hay_wad"]
	for r: Dictionary in _runs:
		var d: HayDrone = r ["drone"]
		if not is_instance_valid(d) or d.mode != HayDrone.Mode.COLLECT or d.zone_at == Vector3.INF:
			continue
		var there:= 0
		for item: Carryable in _props.items:
			if is_instance_valid(item) and _flat(item.global_position, d.zone_at) <= d.zone_r:
				there += 1
		if there >= 2:
			continue
		var a:= randf() * TAU
		var p:= d.zone_at + Vector3(cos(a), 0.0, sin(a)) * randf() * (d.zone_r - 0.5)
		var id: String = kinds [randi() % kinds.size()]
		var state:= { "strands": Cfg.COMPRESSOR_BALE_STRANDS } if id != "eco_brick" else { }
		_props.spawn(id, Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.6), state)


func _has_work(d: HayDrone) -> bool:
	if not d.has_job() or d._route_why != "":
		return false
	if d.mode == HayDrone.Mode.DIG:
		return d._highest_in_zone() != Vector3.INF
	for item: Carryable in _props.items:
		if is_instance_valid(item) and _flat(item.global_position, d.zone_at) <= d.zone_r and d._is_prize(item):
			return true
	return false


func _watch(r: Dictionary, delta: float) -> void:
	var d: HayDrone = r ["drone"]
	if not is_instance_valid(d):
		return
	if d.power < 1.0:
		d.set_power(1.0)
	var model: Node3D = d._model
	var phase: int = d._phase
	var where:= "%s at %v" % [HayDrone.Phase.keys() [phase], model.global_position.snapped(Vector3.ONE * 0.01)]


	if d._releases > int(r ["releases"]):
		var item = r ["held"]
		var at: Vector3 = (item as Node3D).global_position if is_instance_valid(item) else model.global_position
		var off:= _flat(at, d.drop_at)
		if off > HayDrone.FLOOR_SPREAD * 2.0 + 0.8:
			r ["stray"] = int(r ["stray"]) + 1
			if r ["stray_first"] == "":
				r ["stray_first"] = "let go at %v, %.1f m from its drop (%s)" % [at.snapped(Vector3.ONE * 0.01), off, where]
		elif float(r ["first_trip"]) < 0.0:
			r ["first_trip"] = _t
		r ["releases"] = d._releases
	r ["held"] = d._held

	var sign: String = d.alert_reason()
	if sign != "":
		(r ["signs"] as Dictionary) [sign] = true


	var sig:= "%d %s %.2f" % [phase, model.position.snapped(Vector3.ONE * 0.03), snappedf(d._drop, 0.02)]
	var has_work:= phase != HayDrone.Phase.IDLE
	if not has_work:
		r ["work_check"] = int(r ["work_check"]) - 1
		if int(r ["work_check"]) <= 0:
			r ["work_check"] = 30
			r ["work_seen"] = _has_work(d)


		has_work = bool(r ["work_seen"]) and d._stall == "" and not d._wait.contains("too close") and not d._wait.contains("too steep")
	if has_work:
		r ["worked"] = float(r ["worked"]) + delta
	if sig != r ["sig"] or not has_work:
		r ["sig"] = sig
		r ["progress_t"] = _t
	var stalled:= _t - float(r ["progress_t"])
	if stalled > float(r ["worst_stall"]):
		r ["worst_stall"] = stalled
		r ["worst_where"] = where


	_query.transform = model.global_transform * Transform3D(Basis.IDENTITY, _box_centre)
	var hits:= _space.intersect_shape(_query, 4)
	if not hits.is_empty():
		r ["clip"] = int(r ["clip"]) + 1
		if r ["clip_first"] == "":
			r ["clip_first"] = "%s into %s" % [where, _names(hits)]
		var by: Dictionary = r ["clip_by"]
		for h: Dictionary in hits:
			var key:= "%s in %s" % [_name(h.get("collider")), HayDrone.Phase.keys() [phase]]
			by [key] = int(by.get(key, 0)) + 1


	var bottom:= (model.global_transform * Transform3D(Basis.IDENTITY, _box_centre)).origin.y - _box.size.y * 0.5
	var worst_hay:= 0.0
	for off: Vector3 in [Vector3.ZERO, Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		var p:= model.global_transform * (_box_centre + off * _box.size * 0.5)
		worst_hay = maxf(worst_hay, _field.height_at(p.x, p.z))
	if worst_hay > bottom + PILE_SLACK and worst_hay > 0.05:
		r ["pile_clip"] = int(r ["pile_clip"]) + 1
		if r ["pile_first"] == "":
			r ["pile_first"] = "%s, hay %.2f m over the underside" % [where, worst_hay - bottom]


	var held = d._held
	if held != null and is_instance_valid(held) and (phase == HayDrone.Phase.CLIMB or phase == HayDrone.Phase.TO_DROP):
		var lp: Vector3 = (held as Node3D).global_position
		var hay:= _field.height_at(lp.x, lp.z)
		_load_query.transform = Transform3D(Basis.IDENTITY, lp)
		var load_hits:= _space.intersect_shape(_load_query, 4)
		if hay > lp.y - 0.3 + PILE_SLACK and hay > 0.05 and phase == HayDrone.Phase.TO_DROP:
			r ["load_clip"] = int(r ["load_clip"]) + 1
			if r ["load_first"] == "":
				r ["load_first"] = "load at %v through the hay (%.2f m deep), %s" % [lp.snapped(Vector3.ONE * 0.01), hay - (lp.y - 0.3), where]
		elif not load_hits.is_empty():
			r ["load_clip"] = int(r ["load_clip"]) + 1
			if r ["load_first"] == "":
				r ["load_first"] = "load at %v into %s, %s" % [lp.snapped(Vector3.ONE * 0.01), _names(load_hits), where]


	if phase != int(r ["phase"]) and int(r ["phase"]) >= 0:
		var mp:= model.global_position
		var ground:= maxf(0.0, _field.height_at(mp.x, mp.z))
		if mp.y < ground - 0.05:
			r ["under"] = int(r ["under"]) + 1
			if r ["under_first"] == "":
				r ["under_first"] = "%s ended %.2f m below the ground" % [where, ground - mp.y]
	r ["phase"] = phase


func _separation() -> void:
	var sep:= HayDrone.v_sep()
	for i in _runs.size():
		var a: HayDrone = _runs [i] ["drone"]
		if not is_instance_valid(a) or not a._airborne():
			continue
		for j in range(i + 1, _runs.size()):
			var b: HayDrone = _runs [j] ["drone"]
			if not is_instance_valid(b) or not b._airborne():
				continue
			var pa:= a._model.global_position
			var pb:= b._model.global_position
			if absf(pa.y - pb.y) >= sep:
				continue
			var dist:= _flat(pa, pb)
			if dist < _min_sep:
				_min_sep = dist
				_min_sep_where = "%s (%s) and %s (%s) at %v, %.2f m apart in height" % [
					_runs [i] ["label"], HayDrone.Phase.keys() [a._phase],
					_runs [j] ["label"], HayDrone.Phase.keys() [b._phase],
					pa.snapped(Vector3.ONE * 0.1), absf(pa.y - pb.y)]


			if dist < 3.3 and _airframes_touch(a._model, b._model):
				_contacts += 1
				if _contact_first == "":
					_contact_first = _min_sep_where if is_equal_approx(dist, _min_sep) else "%s and %s at %v" % [_runs [i] ["label"], _runs [j] ["label"],
							pa.snapped(Vector3.ONE * 0.1)]


func _airframes_touch(a: Node3D, b: Node3D) -> bool:
	var ha:= _box.size * 0.5
	var ta:= a.global_transform * Transform3D(Basis.IDENTITY, _box_centre)
	var tb:= b.global_transform * Transform3D(Basis.IDENTITY, _box_centre)
	if absf(ta.origin.y - tb.origin.y) > _box.size.y + 0.6:
		return false
	var corners_a:= _plan_corners(ta, ha)
	var corners_b:= _plan_corners(tb, ha)
	for poly: PackedVector2Array in [corners_a, corners_b]:
		for k in 4:
			var edge:= poly [(k + 1) % 4] - poly [k]
			var axis:= Vector2(- edge.y, edge.x).normalized()
			var a_lo:= INF
			var a_hi:= - INF
			var b_lo:= INF
			var b_hi:= - INF
			for c in corners_a:
				a_lo = minf(a_lo, c.dot(axis))
				a_hi = maxf(a_hi, c.dot(axis))
			for c in corners_b:
				b_lo = minf(b_lo, c.dot(axis))
				b_hi = maxf(b_hi, c.dot(axis))
			if a_hi < b_lo or b_hi < a_lo:
				return false
	return true


static func _plan_corners(t: Transform3D, half: Vector3) -> PackedVector2Array:
	var out:= PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p:= t * Vector3(half.x * s.x, 0.0, half.z * s.y)
		out.append(Vector2(p.x, p.z))
	return out


func _names(hits: Array [Dictionary]) -> String:
	var out:= PackedStringArray()
	for h: Dictionary in hits:
		var one:= _name(h.get("collider"))
		if not out.has(one):
			out.append(one)
	return ", ".join(out)


func _name(c: Object) -> String:
	var n:= c as Node3D
	if n == null:
		return "?"
	var owner_name:= ""
	var up:= n.get_parent()
	while up != null and up != world:
		var sc: Script = up.get_script()
		if sc != null and sc.get_global_name() != "":
			owner_name = "%s %s" % [sc.get_global_name(), up.name]
			break
		up = up.get_parent()
	var own:= "" if str(n.name).begins_with("@") else str(n.name)
	return "%s/%s at y %.1f" % [owner_name, own, n.global_position.y]


func _report(frames: int) -> void:
	print("\n--- %.0f s flown, %s pile ---" % [_t, Cfg.pile_size_id])
	print("  %-14s %5s %7s %8s %7s %7s %6s %5s  %s" % ["drone", "loads", "first s",
		"worked s", "stall s", "held s", "plans", "near", "longest stall at"])
	var misses:= 0
	for r: Dictionary in _runs:
		var d: HayDrone = r ["drone"]
		misses += d.near_misses
		print("  %-14s %5d %7.1f %8.0f %7.1f %7.1f %6d %5d  %s  [%s]"
			% [r ["label"], d.trips, r ["first_trip"], r ["worked"], r ["worst_stall"],
				d.held_for, d.plans - int(r ["plans0"]), d.near_misses, r ["worst_where"],
				str(d.plate_status() [1])])
	print("")
	for r: Dictionary in _runs:
		var d: HayDrone = r ["drone"]
		var label: String = r ["label"]
		var signs: Array = (r ["signs"] as Dictionary).keys()
		if bool(r ["grounded"]):
			var said:= false
			for t: String in signs:
				if t.begins_with("CAN'T TAKE OFF"):
					said = true
			_check(d.trips == 0 and said,
				"%s: stays on its pad and says why (%d loads; signs: %s)" % [label, d.trips, " / ".join(signs)])
			continue
		_check(float(r ["worst_stall"]) <= STALL_LIMIT,
			"%s: longest stall %.1f s (limit %.0f)" % [label, r ["worst_stall"], STALL_LIMIT])
		_check(d.trips > 0 or float(r ["worked"]) < 30.0,
			"%s: carried %d loads (had work for %.0f s; signs: %s)"
			% [label, d.trips, r ["worked"], " / ".join(signs)])


		if str(r ["refused"]) == "":
			_check(d.plans - int(r ["plans0"]) == 0,
				"%s: no route planned again in flight with nothing changed (%d)"
				% [label, d.plans - int(r ["plans0"])])
		else:
			print("  note %s: its route is refused (%s), so it stays down and says why: %s"
				% [label, r ["refused"], " / ".join(signs)])
		_check(int(r ["clip"]) == 0, "%s: airframe clear of buildings (%d frames%s)"
			% [label, r ["clip"], "" if r ["clip_first"] == "" else ", first: " + str(r ["clip_first"])])
		var by: Dictionary = r ["clip_by"]
		for key: String in by:
			print("         %5d frames  %s" % [by [key], key])
		_check(int(r ["pile_clip"]) == 0, "%s: airframe clear of the pile (%d frames%s)"
			% [label, r ["pile_clip"], "" if r ["pile_first"] == "" else ", first: " + str(r ["pile_first"])])
		_check(int(r ["load_clip"]) == 0, "%s: load carried clear (%d frames%s)"
			% [label, r ["load_clip"], "" if r ["load_first"] == "" else ", first: " + str(r ["load_first"])])
		_check(int(r ["stray"]) == 0, "%s: every load let go at its drop (%d stray%s)"
			% [label, r ["stray"], "" if r ["stray_first"] == "" else ", first: " + str(r ["stray_first"])])
		_check(int(r ["under"]) == 0, "%s: every leg ended above the ground (%d%s)"
			% [label, r ["under"], "" if r ["under_first"] == "" else ", first: " + str(r ["under_first"])])
	_check(_contacts == 0, "no two airframes ever touched (%d frames%s)"
		% [_contacts, "" if _contact_first == "" else ", first: " + _contact_first])
	_check(misses == 0, "no two drones came within %.1f m of each other at the same height (%d near misses)"
		% [HayDrone.HARD_SEP, misses])
	print("  closest two drones at the same height came: %.2f m, %s"
		% [_min_sep, _min_sep_where if _min_sep_where != "" else "never at one height"])
	var n:= maxi(frames, 1)
	print("\n  what the fleet cost over %d frames:" % frames)
	print("    traffic pass   %6.1f us a frame on average, %6.1f us at worst"
		% [float(HayDrone.cost_traffic_us) / n, float(HayDrone.cost_traffic_worst)])
	print("    looks for work %6.1f us a frame on average, %6.1f us at worst (one a frame at most)"
		% [float(HayDrone.cost_pick_us) / n, float(HayDrone.cost_pick_worst)])
	print("    route plans    %6.1f us a frame on average, %6.1f us at worst"
		% [float(HayDrone.cost_plan_us) / n, float(HayDrone.cost_plan_worst)])
	print("    every drone's whole frame, all of it: %.3f ms a frame for %d drones (%.1f us each)"
		% [float(HayDrone.cost_frame_us) / n / 1000.0, _runs.size(),
			float(HayDrone.cost_frame_us) / n / maxf(1.0, float(_runs.size()))])
	_check(HayDrone.cost_traffic_worst < 1000, "the traffic pass never took a millisecond (%d us)"
		% HayDrone.cost_traffic_worst)
	_check(HayDrone.cost_plan_worst < 3000, "no route plan took three milliseconds (%d us)"
		% HayDrone.cost_plan_worst)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)
