class_name DevWyeShotProbe
extends Node


var world: Node3D
var player: Player

const SPLITTER_AT:= Vector3(13.0, 0.0, 5.5)
const JOINER_AT:= Vector3(13.0, 0.0, -5.5)
const RUN:= 2.5

var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--wyeshot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for _i in 20:
		await get_tree().process_frame

	GameState.add_money(50000.0)
	var deck:= Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)
	var builds: BuildManager = world.builds

	var s: ConveyorSplitter = builds.add_splitter(SPLITTER_AT + deck, 0.0)
	var fwd:= s.forward()
	builds.add_conveyor(s.port_in() - fwd * RUN, s.port_in())
	var left_dir:= (s.port_left() - s.global_position).normalized()
	builds.add_conveyor(s.port_left(), s.port_left() + left_dir * RUN)
	var right_dir:= (s.port_right() - s.global_position).normalized()
	var bend:= s.port_right() + right_dir * 1.4
	builds.add_conveyor(s.port_right(), bend)
	builds.add_conveyor(bend, bend + fwd * RUN)


	var j: ConveyorJoiner = builds.add_joiner(JOINER_AT + deck, PI)
	var out_dir_j:= j.forward()
	builds.add_conveyor(j.port_out(), j.port_out() + out_dir_j * RUN)
	for side: int in ConveyorJoiner.SIDES:
		var arm:= j.port(side)
		builds.add_conveyor(arm - j.arm_travel(side) * RUN, arm)

	player.global_position = Vector3(20.0, 0.4, 0.0)


	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 55.0
	get_tree().root.add_child(_cam)
	_cam.make_current()
	for _i in 30:
		await get_tree().physics_frame

	for row: Array in [["splitter", s as Node3D], ["joiner", j as Node3D]]:
		var name_: String = row [0]
		var m: Node3D = row [1]
		var c:= m.global_position
		var f:= m.global_basis.z.normalized()
		var x:= m.global_basis.x.normalized()

		await _shot(c + Vector3(0.0, 4.2, 0.001), c, "%s/%s_top.png" % [out_dir, name_])

		var nose:= c + f * Cfg.SPLITTER_GATE_PIVOT * (1.0 if m is ConveyorSplitter else -1.0)
		var toward:= (c - nose).normalized()
		await _shot(nose + toward * 1.3 + x * 0.5 + Vector3(0.0, 1.0, 0.0), nose,
			"%s/%s_nose.png" % [out_dir, name_])

		await _shot(c + x * 2.2 - f * 0.9 + Vector3(0.0, 1.5, 0.0), c,
			"%s/%s_notch.png" % [out_dir, name_])

		await _shot(c + f * 2.3 + Vector3(0.0, 1.4, 0.0), c + f * 0.3,
			"%s/%s_crotch.png" % [out_dir, name_])

		await _shot(c + x * 1.6 + f * 1.8 + Vector3(0.0, 1.1, 0.0), c + x * 0.6 + f * 0.6,
			"%s/%s_mouth.png" % [out_dir, name_])
	get_tree().quit()


func _shot(eye: Vector3, target: Vector3, path: String) -> void:
	var up:= Vector3.UP
	if absf((target - eye).normalized().dot(up)) > 0.98:
		up = Vector3(0.0, 0.0, -1.0)
	_cam.look_at_from_position(eye, target, up)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[wyeshot] %s" % path)
