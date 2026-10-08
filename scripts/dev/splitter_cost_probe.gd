class_name DevSplitterCostProbe
extends Node


var world: Node3D
var player: Player

const OUT_LEN:= 8.0
const FEED_LEN:= 10.0

const LOADS:= 24
const GAP:= 0.45

const DRAIN:= 6.0

var _deck_y:= 0.0
var _rows: Array = []


func run() -> void:
	_deck_y = Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	for i in 30:
		await get_tree().process_frame
	GameState.add_money(10000000.0)


	world.props.clean_blocked = true
	player.set_physics_process(false)
	Tech.grant("belt_speed", 6)
	print("[splittercost] belt speed %.2f m/s, %d wads a rig" % [
		Tech.belt_speed(), LOADS])
	for kind in ["wye", "u", "t", "compact", "smart"]:
		await _measure(kind)
	_report()
	get_tree().quit(0)


func _measure(kind: String) -> void:
	var builds: BuildManager = world.builds
	var centre:= Vector3(0.0, _deck_y, 0.0)
	var s: ConveyorSplitter = null
	match kind:
		"wye":
			s = builds.add_splitter(centre, 0.0)
		"u":
			s = builds.add_u_splitter(centre, 0.0)
		"t":
			s = builds.add_t_splitter(centre, 0.0)
		"compact":
			s = builds.add_compact_splitter(centre, 0.0)
		"smart":
			s = builds.add_compact_splitter(centre, 0.0, true)
	if s == null:
		push_error("[splittercost] %s did not build" % kind)
		return
	await get_tree().physics_frame
	var census:= _census(s)
	var sides: Array = s.output_sides()
	var into:= s.port_in()
	var back:= into - Vector3(0.0, 0.0, FEED_LEN)
	back.y = _deck_y
	var feed: Conveyor = builds.add_conveyor(back, into)
	var outs: Array [Conveyor] = []
	for side in sides:
		var mouth:= s.port(side)
		var dir:= s.arm_travel(side)
		dir.y = 0.0
		var far:= mouth + dir.normalized() * OUT_LEN
		var c: Conveyor = builds.add_conveyor(mouth, far)

		c.set_outlet_held(true)
		outs.append(c)
	for i in 10:
		await get_tree().physics_frame

	FactoryClock.prof.clear()
	FactoryClock.profile = true
	await _feed(feed)
	FactoryClock.profile = false

	var mach:= _prof_row("machine " + FactoryClock.class_of(s))
	var belt:= _prof_sum("belt of " + FactoryClock.class_of(s))
	var through:= 0
	for c in outs:
		through += c.run.count()
	_rows.append({
		"kind": kind, "class": FactoryClock.class_of(s), "doors": sides.size(),
		"census": census, "machine": mach, "belt": belt,
		"through": through, "left": feed.run.count(),
	})

	for c in outs:
		builds.demolish(c)
	builds.demolish(feed)
	builds.demolish(s)
	for i in 20:
		await get_tree().physics_frame


func _feed(feed: Conveyor) -> void:
	var spawn_at:= feed.a + feed.forward * 0.6 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var t:= 0.0
	var next:= 0.0
	var fed:= 0
	var total:= GAP * LOADS + DRAIN
	while t < total:
		if fed < LOADS and t >= next:
			world.props.spawn("hay_wad",
				Transform3D(Basis(Vector3.UP, yaw), spawn_at))
			fed += 1
			next += GAP
		await get_tree().physics_frame
		t += step


func _census(root: Node) -> Dictionary:
	var out:= { "nodes": 0, "shapes": 0, "areas": 0, "bodies": 0,
		"meshes": 0, "multimeshes": 0, "paths": 0, "anim": 0 }
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n != root:
			out ["nodes"] += 1
		if n is CollisionShape3D:
			out ["shapes"] += 1
		elif n is Area3D:
			out ["areas"] += 1
		elif n is StaticBody3D or n is RigidBody3D:
			out ["bodies"] += 1
		elif n is MultiMeshInstance3D:
			out ["multimeshes"] += 1
		elif n is MeshInstance3D:
			out ["meshes"] += 1
		elif n is AnimationPlayer:
			out ["anim"] += 1
		if n is BeltPath:
			out ["paths"] += 1
	return out


func _prof_row(key: String) -> Array:
	return FactoryClock.prof.get(key, [0, 0]) as Array


func _prof_sum(prefix: String) -> Array:
	var us:= 0
	var calls:= 0
	for key: String in FactoryClock.prof:
		if not key.begins_with(prefix):
			continue
		var row: Array = FactoryClock.prof [key]
		us += int(row [0])
		calls += int(row [1])
	return [us, calls]


func _report() -> void:
	print("\n=== splitter cost ===")
	print("%-8s %5s %6s %7s %6s %6s %6s %6s | %8s %8s %8s | %5s %5s" % [
		"kind", "doors", "nodes", "shapes", "areas", "bodies", "meshes",
		"paths", "us/tick", "us/route", "us total", "thru", "left"])
	for r: Dictionary in _rows:
		var c: Dictionary = r ["census"]
		var mach: Array = r ["machine"]
		var belt: Array = r ["belt"]
		var m_us:= (float(mach [0]) / float(mach [1])) if int(mach [1]) > 0 else 0.0
		var b_us:= (float(belt [0]) / float(belt [1])) if int(belt [1]) > 0 else 0.0
		var per_tick:= m_us + b_us * (float(belt [1]) / maxf(float(mach [1]), 1.0))
		print("%-8s %5d %6d %7d %6d %6d %6d %6d | %8.1f %8.1f %8.1f | %5d %5d" % [
			r ["kind"], r ["doors"], c ["nodes"], c ["shapes"], c ["areas"],
			c ["bodies"], c ["meshes"], c ["paths"],
			m_us, b_us, per_tick, r ["through"], r ["left"]])
	print("\nus/tick is the machine's own call. us/route is one of its belt")
	print("paths. us total is what one of these costs the factory clock each")
	print("tick, machine plus all its routes.")
