class_name DevWyeLegShotProbe
extends Node


var world: Node3D

const SPLITTER_AT:= Vector3(13.0, 0.0, 6.0)
const JOINER_AT:= Vector3(13.0, 0.0, -6.0)
const MATED_AT:= Vector3(13.0, 0.0, 0.0)
const RUN:= 2.5

var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--wyelegshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for _i in 20:
		await get_tree().process_frame

	var deck:= Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)
	var builds: BuildManager = world.builds
	var s: ConveyorSplitter = builds.add_splitter(SPLITTER_AT + deck, 0.0)
	var j: ConveyorJoiner = builds.add_joiner(JOINER_AT + deck, 0.0)
	var m: ConveyorSplitter = builds.add_splitter(MATED_AT + deck, 0.0)
	var arm:= m.port_right()
	var run_off:= builds.add_conveyor(arm, arm + (arm - m.global_position).normalized() * RUN)

	var player: Node3D = world.get("player")
	if player != null:
		player.global_position = Vector3(24.0, 0.4, 0.0)

	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	get_tree().root.add_child(_cam)
	_cam.make_current()
	for _i in 30:
		await get_tree().physics_frame


	print("[wyelegshot] run off the arm stands at %s" % [run_off.support_stations()])

	for row: Array in [["splitter", s as Node3D], ["joiner", j as Node3D],
			["mated", m as Node3D]]:
		var name_: String = row [0]
		var wye: Node3D = row [1]
		var c:= wye.global_position
		_report(name_, wye)


		for k in 3:
			var bearing:= TAU * float(k) / 3.0 + PI / 6.0
			var out:= Vector3(sin(bearing), 0.0, cos(bearing))
			await _shot(c + out * 2.6 + Vector3(0.0, 0.35, 0.0), c + Vector3(0.0, -0.2, 0.0),
				"%s/%s_low_%d.png" % [out_dir, name_, k])

		for mouth: Vector3 in wye.call("ports"):
			var d:= (mouth - c).normalized()
			var across:= Vector3.UP.cross(d).normalized()
			var i: int = (wye.call("ports") as Array).find(mouth)
			await _shot(mouth + d * 0.9 + across * 1.5 + Vector3(0.0, 0.25, 0.0),
				mouth - d * 0.2 + Vector3(0.0, -0.2, 0.0),
				"%s/%s_mouth_%d.png" % [out_dir, name_, i])
	get_tree().quit()


func _report(name_: String, wye: Node3D) -> void:
	var mmi:= wye.get_node_or_null("Supports/Legs") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		print("[wyelegshot] %s: no legs" % name_)
		return
	var mm:= mmi.multimesh
	print("[wyelegshot] %s: %d legs" % [name_, mm.instance_count])
	for i in mm.instance_count:
		var top:= wye.to_local(mm.get_instance_transform(i).origin)
		print("[wyelegshot]   top %s  r %.3f" % [top, Vector2(top.x, top.z).length()])


func _shot(eye: Vector3, target: Vector3, path: String) -> void:
	_cam.look_at_from_position(eye, target, Vector3.UP)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[wyelegshot] %s" % path.get_file())
