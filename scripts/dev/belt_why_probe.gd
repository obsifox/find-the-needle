class_name DevBeltWhyProbe
extends Node


var world: Node3D
var player: Player


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--beltwhy")
	var path: String = ua [i + 1] if i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("BELTWHY: no save copy given: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var d: Dictionary = f.get_var(true)
	f.close()
	Cfg.apply_pile_size(str((d.get("meta", { }) as Dictionary).get("pile_size",
		Cfg.DEFAULT_PILE_SIZE)))
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array([])
	var shed:= world.get_node_or_null("Warehouse")
	if shed != null:
		shed._follow_tech()
		print("BELTWHY: site %s, pile %s, shed inner %.2f" % [SaveManager.current_map,
			(d.get("meta", { }) as Dictionary).get("pile_size"), shed.inner])
	for _k in 60:
		await get_tree().physics_frame
	var b: BuildManager = world.builds
	var tool: BuildTool = world.player.build
	tool.set_active(false)
	tool._mode = BuildTool.Mode.CONVEYOR
	print("BELTWHY: block_save=%s" % world.block_save)

	var raw:= Vector3(float(ua [i + 2]), Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR,
		float(ua [i + 3]))
	var to:= b.snap_endpoint(raw)
	print("aim %v snaps to %v  port bearing %v" % [raw, to, b.port_bearing_at(to)])

	print("--- buildings within 10 m of the aim ---")
	var seen:= { }
	for n in b.find_children("*", "Node3D", true, false):
		var building:= b.owner_of(n)
		if building == null or building is Conveyor or seen.has(building):
			continue
		seen [building] = true
		if building.global_position.distance_to(to) > 10.0:
			continue
		print("  %-24s %-20s at %v" % [building.name, b.name_of(building),
			building.global_position])
		if building is ConveyorUSplitter:
			print("    ports %v and %v" % [(building as ConveyorUSplitter).port_left(),
				(building as ConveyorUSplitter).port_right()])
	print("--- belt ends within 14 m ---")
	for c in b.conveyors:
		for end in [c.a, c.b]:
			if (end as Vector3).distance_to(to) < 14.0:
				print("  %s end %v  in=%s out=%s" % [c.name, end,
					b.feed_run_into(end) != null, b.run_out_of(end) != null])

	if ua.size() < i + 6:
		get_tree().quit(0)
		return
	var from:= b.snap_endpoint(Vector3(float(ua [i + 4]),
		Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, float(ua [i + 5])))


	var dropped:= ua.find("drop")
	if dropped > 0 and dropped + 4 < ua.size():
		var y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
		b.add_conveyor(Vector3(float(ua [dropped + 1]), y, float(ua [dropped + 2])),
			Vector3(float(ua [dropped + 3]), y, float(ua [dropped + 4])))
		for _k in 5:
			await get_tree().physics_frame
	tool._state = BuildTool.State.RUNNING
	var ev:= tool._evaluate(from, to, true)


	var old:= ""
	var pieces:= tool._port_knees(from, to)
	for k in pieces.size() - 1:
		if old == "" and pieces [k].distance_to(pieces [k + 1]) > 0.01:
			old = tool._leg_clear_reason(pieces [k], pieces [k + 1], pieces [k].distance_to(pieces [k + 1]))
	print("  with slack at the bends (old) it was '%s'" % old)
	print("--- run %v -> %v ---" % [from, to])
	print("  reason '%s'  knees %s" % [ev ["reason"], tool._port_knees(from, to)])
	print("  blocker named in the readout: '%s'" % tool._run_blocker)
	var hit: Object = tool._obstruction(from, to, from.distance_to(to))
	if hit != null:
		var who: Node = b.owner_of(hit as Node) if hit is Node else null
		print("  the straight line (not what is laid) hits %s (%s) owned by %s" % [hit,
			(hit as Node).get_path() if hit is Node else "", who])
	if hit is CollisionObject3D:
		for cs: CollisionShape3D in (hit as Node).find_children("*", "CollisionShape3D", true, false):
			print("    shape %s, bounds %s" % [cs.shape.get_class(),
				cs.global_transform * cs.shape.get_debug_mesh().get_aabb()])
	var knees:= tool._port_knees(from, to)
	for k in knees.size() - 1:
		var a:= knees [k]
		var z:= knees [k + 1]
		if a.distance_to(z) < 0.01:
			continue
		print("  leg %d %v -> %v  shape '%s'  clear '%s'" % [k, a, z,
			tool._leg_shape_reason(a, z, a.distance_to(z)),
			tool._leg_clear_reason(a, z, a.distance_to(z))])
	var router:= BeltRouter.new(tool)
	var shapes:= router._shapes(from, to)
	shapes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x ["score"] < y ["score"])
	print("  router: %d shapes, %d picks" % [shapes.size(), router.find(from, to).size()])
	for s in shapes.slice(0, 12):
		var pts: PackedVector3Array = s ["points"]
		var why:= ""
		for k in pts.size() - 1:
			var r: String = tool._leg_shape_reason(pts [k], pts [k + 1], pts [k].distance_to(pts [k + 1]))
			if r == "":
				r = tool._leg_clear_reason(pts [k], pts [k + 1], pts [k].distance_to(pts [k + 1]))
			if r != "":
				var h: Object = tool._obstruction(pts [k], pts [k + 1], pts [k].distance_to(pts [k + 1]))
				why = "leg %d '%s' %s" % [k, r, (h as Node).name if h is Node else ""]
				break
		if why == "" and tool._doubles_back(pts):
			why = "doubles back"
		print("    %-18s len %.1f  %s" % [s ["sig"], s ["length"], why if why != "" else "CLEARS?"])
	get_tree().quit(0)
