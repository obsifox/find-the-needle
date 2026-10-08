class_name MachineSeat
extends RefCounted


const SINK_TOLERANCE:= 0.08


const FLOAT_TOLERANCE:= 0.3


const STUB_PITCH:= 0.49


const STUB_LEVEL:= 0.03


const MOUTH_BELT:= 1.0


const MOUTH_BELT_REACH:= 1.5


const MOUTH_LANE_ACROSS:= Cfg.BELT_WIDTH * 0.5


static func seat(space: PhysicsDirectSpaceState3D, joint: Dictionary,
		spec: Dictionary, aim:= Vector3.INF) -> Dictionary:


	var intake:= not bool(joint ["start"])
	if intake and not spec.has("in"):
		return { }
	if not intake and not spec.has("out"):
		return { }
	var forward: Vector3 = joint ["forward"]
	var mouth: Vector3 = joint ["point"]
	var port:= mouth
	var stub:= PackedVector3Array()
	if bool(joint.get("wye", false)):
		return lane_seat(space, joint, aim, spec)
	if bool(spec.get("grounded", false)):


		port = _stub_port(space, mouth, forward, intake, spec, false)
	if port == Vector3.INF:
		return { }
	if not port.is_equal_approx(mouth):
		stub = PackedVector3Array([mouth, port]) if intake else PackedVector3Array([port, mouth])
	return { "joint": joint, "forward": forward, "intake": intake, "port": port,
		"stub": stub, "origin": origin_for(port, forward, intake, spec) }


static func lane_seat(space: PhysicsDirectSpaceState3D, joint: Dictionary,
		aim: Vector3, spec: Dictionary) -> Dictionary:
	if aim == Vector3.INF:
		return { }
	var intake:= not bool(joint ["start"])
	if intake and not spec.has("in"):
		return { }
	if not intake and not spec.has("out"):
		return { }
	var forward: Vector3 = joint ["forward"]
	var mouth: Vector3 = joint ["point"]
	var d:= Vector3(aim.x - mouth.x, 0.0, aim.z - mouth.z)
	var along:= d.dot(forward)
	if (d - forward * along).length() > MOUTH_LANE_ACROSS:
		return { }


	var body: float = float(spec ["in"]) if intake else float(spec ["out"])
	var out_by:= along - body if intake else - along - body
	if out_by > MOUTH_BELT_REACH or out_by < - (body + MOUTH_BELT):
		return { }
	var grounded:= bool(spec.get("grounded", false))
	var up:= float(spec ["feet"]) + float(spec ["rise"])
	var floor_y:= aim.y
	var away:= forward if intake else - forward
	var port:= mouth
	for i in 3:
		var rise:= floor_y + up - mouth.y if grounded else 0.0
		if absf(rise) < STUB_LEVEL:
			rise = 0.0
		var run:= MOUTH_BELT
		if rise != 0.0:
			run = maxf(run, absf(rise) / tan(STUB_PITCH))
		port = mouth + away * run + Vector3.UP * rise
		if not grounded or i == 2:
			break
		var over:= origin_for(port, forward, intake, spec)
		var top:= maxf(aim.y, mouth.y) + 0.3
		var q:= PhysicsRayQueryParameters3D.create(Vector3(over.x, top, over.z),
			Vector3(over.x, top - 8.0, over.z))
		q.collision_mask = Cfg.BUILD_SURFACE_MASK
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			return { }
		floor_y = (hit ["position"] as Vector3).y
	var stub:= PackedVector3Array([mouth, port]) if intake else PackedVector3Array([port, mouth])
	return { "joint": joint, "forward": forward, "intake": intake, "port": port,
		"stub": stub, "origin": origin_for(port, forward, intake, spec), "lane": true }


static func origin_for(port: Vector3, forward: Vector3, intake: bool,
		spec: Dictionary) -> Vector3:
	var along: float = float(spec ["in"]) if intake else - float(spec ["out"])
	return port + forward * along - Vector3.UP * float(spec ["rise"])


static func choose(space: PhysicsDirectSpaceState3D, joints: Array [Dictionary],
		aim: Vector3, spec: Dictionary) -> Dictionary:
	var best: Dictionary = { }
	var best_d:= INF
	for joint in joints:
		var s:= seat(space, joint, spec, aim)
		if s.is_empty():
			continue
		var at: Vector3 = s ["origin"]
		var d:= Vector2(at.x - aim.x, at.z - aim.z).length()
		if d < best_d:
			best_d = d
			best = s
	return best


static func _stub_port(space: PhysicsDirectSpaceState3D, mouth: Vector3,
		forward: Vector3, intake: bool, spec: Dictionary,
		must_run: bool) -> Vector3:
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var floor_y:= mouth.y - lift
	var up:= float(spec ["feet"]) + float(spec ["rise"])
	var away:= forward if intake else - forward
	var port:= mouth
	for i in 3:
		var rise:= floor_y + up - mouth.y
		if absf(rise) < STUB_LEVEL:
			rise = 0.0
		var run:= 0.0
		if rise != 0.0 or must_run:


			run = sqrt(maxf(Cfg.BELT_MIN_LENGTH * Cfg.BELT_MIN_LENGTH - rise * rise,
				0.0)) + 0.02
			if rise != 0.0:
				run = maxf(run, absf(rise) / tan(STUB_PITCH))
		port = mouth + away * run + Vector3.UP * rise
		if i == 2:
			break
		var over:= origin_for(port, forward, intake, spec)
		var q:= PhysicsRayQueryParameters3D.create(
			Vector3(over.x, mouth.y + 0.3, over.z),
			Vector3(over.x, mouth.y - 8.0, over.z))
		q.collision_mask = Cfg.BUILD_SURFACE_MASK
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			return Vector3.INF
		floor_y = (hit ["position"] as Vector3).y
	return port


static func floor_fault(space: PhysicsDirectSpaceState3D, origin: Vector3,
		forward: Vector3, spec: Dictionary) -> String:
	var feet:= origin.y - float(spec ["feet"])
	var reach:= float(spec.get("half", 1.0)) * 0.5
	var grounded:= bool(spec.get("grounded", false))
	for t: float in [0.0, - reach, reach]:
		var at:= Vector3(origin.x, feet, origin.z) + forward * t


		var q:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1,
			at - Vector3.UP * (FLOAT_TOLERANCE + 0.5))
		q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
		q.hit_from_inside = true
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			if grounded:
				return "high"
			continue
		var floor_y:= (hit ["position"] as Vector3).y
		if floor_y > feet + SINK_TOLERANCE:
			return "low"
		if grounded and floor_y < feet - FLOAT_TOLERANCE:
			return "high"
	return ""
