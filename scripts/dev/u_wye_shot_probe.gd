class_name DevUWyeShotProbe
extends Node


var world: Node3D


const SPLITTER_AT:= Vector3(-13.0, 0.0, 7.0)
const JOINER_AT:= Vector3(-13.0, 0.0, -2.0)
const PAIR_AT:= Vector3(-8.0, 0.0, -11.0)
const RUN:= 2.5

var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--uwyeshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for _i in 20:
		await get_tree().process_frame

	var deck:= Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)
	var builds: BuildManager = world.builds
	var s: ConveyorUSplitter = builds.add_u_splitter(SPLITTER_AT + deck, 0.0)
	var j: ConveyorUJoiner = builds.add_u_joiner(JOINER_AT + deck, 0.0)
	var ps: ConveyorUSplitter = builds.add_u_splitter(PAIR_AT + deck, 0.0)

	var pj: ConveyorUJoiner = builds.add_u_joiner(
		ps.global_position + Vector3(0.0, 0.0, ConveyorUSplitter.OUT_Z * 2.0), 0.0)
	var feed:= builds.add_conveyor(ps.port_in() - ps.forward() * RUN, ps.port_in())
	builds.add_conveyor(pj.port_out(), pj.port_out() + pj.forward() * RUN)

	var player: Node3D = world.get("player")
	if player != null:
		player.global_position = Vector3(-3.0, 0.4, 14.0)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	get_tree().root.add_child(_cam)
	_cam.make_current()
	for _i in 30:
		await get_tree().physics_frame

	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		world.live.spawn(feed.a + Vector3(rng.randf_range(-0.2, 0.2), 0.22,
			rng.randf_range(0.0, 1.8)), StrandFactory.random_strand_basis(rng),
			Vector3.ZERO, Cfg.COL_HAY_LIGHT)
	for _i in 200:
		await get_tree().physics_frame

	for row: Array in [["u_splitter", s as Node3D], ["u_joiner", j as Node3D],
			["u_pair", ps as Node3D]]:
		var name_: String = row [0]
		var wye: Node3D = row [1]


		var mid:= wye.global_position + wye.global_basis.z * (0.5 if name_ != "u_pair" else 2.0)
		if name_ == "u_joiner":
			mid = wye.global_position - wye.global_basis.z * 0.5
		_report(name_, wye)
		var up:= 7.0 if name_ == "u_pair" else 4.5
		await _shot(mid + Vector3(0.001, up, 0.0), mid, "%s/%s_top.png" % [out_dir, name_])
		for k in 3:
			var bearing:= TAU * float(k) / 3.0 + PI / 6.0
			var out:= Vector3(sin(bearing), 0.0, cos(bearing))
			await _shot(mid + out * (3.4 if name_ != "u_pair" else 5.5) + Vector3(0.0, 0.5, 0.0),
				mid + Vector3(0.0, -0.2, 0.0), "%s/%s_low_%d.png" % [out_dir, name_, k])
		if name_ == "u_pair":
			continue
		var ports: Array = wye.call("ports")
		for i in ports.size():
			var mouth: Vector3 = ports [i]
			var d:= wye.global_basis.z
			if (mouth - wye.global_position).dot(d) < 0.0:
				d = - d
			var across:= Vector3.UP.cross(d).normalized()
			await _shot(mouth + d * 0.9 + across * 1.5 + Vector3(0.0, 0.25, 0.0),
				mouth - d * 0.2 + Vector3(0.0, -0.2, 0.0),
				"%s/%s_mouth_%d.png" % [out_dir, name_, i])
	get_tree().quit()


func _report(name_: String, wye: Node3D) -> void:
	var mmi:= wye.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		print("[uwyeshot] %s: no legs" % name_)
		return
	var mm:= mmi.multimesh
	print("[uwyeshot] %s: %d legs" % [name_, mm.instance_count])
	for i in mm.instance_count:
		print("[uwyeshot]   top %s" % wye.to_local(mm.get_instance_transform(i).origin))


func _shot(eye: Vector3, target: Vector3, path: String) -> void:
	_cam.look_at_from_position(eye, target, Vector3.UP)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[uwyeshot] %s" % path.get_file())
