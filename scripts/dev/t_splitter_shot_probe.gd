class_name DevTSplitterShotProbe
extends Node


var world: Node3D
var player: Player


const RIGS:= [
	[Vector3(-14.0, 0.0, 8.0), 0.0, [ConveyorTSplitter.STEM], -1],
	[Vector3(-14.0, 0.0, -2.0), 0.0, [ConveyorTSplitter.BAR_POS, ConveyorTSplitter.BAR_NEG], -1],
	[Vector3(-14.0, 0.0, -12.0), 0.0, [ConveyorTSplitter.BAR_NEG], ConveyorSplitter.RIGHT],
]
const FEED_RUN:= 4.0
const OUT_RUN:= 2.5

var _cam: Camera3D


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var out_dir:= "."
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--tsplittershot")
	if at >= 0 and at + 1 < args.size():
		out_dir = args [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for _i in 20:
		await get_tree().process_frame

	var deck:= Vector3(0.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, 0.0)
	var builds: BuildManager = world.builds
	if "--hover" in args:
		await _hover_shots(out_dir, deck)
		get_tree().quit()
		return
	var ts: Array [Node3D] = []
	var feeds: Array [Conveyor] = []
	for rig: Array in RIGS:
		var placed:= builds.add_t_splitter(rig [0] + deck, rig [1]) as ConveyorTSplitter
		var site: Vector3 = placed.global_position
		var basis:= placed.global_basis
		var lanes: Array = rig [2]
		for lane: int in lanes:
			var mouth:= site + basis * placed.mouth_of(lane)
			var out:= (basis * ConveyorTSplitter.lane_out(lane)).normalized()
			feeds.append(builds.add_conveyor(mouth + out * FEED_RUN, mouth))


		var t: Node3D = null
		for n: Node3D in builds.splitters:
			if n.global_position.is_equal_approx(site):
				t = n
		for n: Node3D in builds.joiners:
			if n.global_position.is_equal_approx(site):
				t = n
		if t is ConveyorTSplitter:
			var s:= t as ConveyorTSplitter
			for side: int in ConveyorSplitter.SIDES:
				builds.add_conveyor(s.port(side), s.port(side) + s.arm_travel(side) * OUT_RUN)
			if int(rig [3]) >= 0:
				s.set_forced_side(int(rig [3]))
			print("[tsplittershot] splitter fed at %d, %s" % [s.entry, s.setting_name()])
		else:
			var j:= t as ConveyorTJoiner
			builds.add_conveyor(j.port_out(), j.port_out() + j.forward() * OUT_RUN)
			print("[tsplittershot] merge out by %d" % j.out_lane)
		ts.append(t)

	if player != null:
		player.global_position = Vector3(-2.0, 0.4, 16.0)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	get_tree().root.add_child(_cam)
	_cam.make_current()
	for _i in 30:
		await get_tree().physics_frame

	var fed:= 0
	var frames:= 0
	var shots:= [240, 300, 420]
	var next:= 0
	while next < shots.size():
		if frames % 70 == 0:
			for feed in feeds:
				world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP,
					atan2(feed.forward.x, feed.forward.z)),
					feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)))
				fed += 1
		await get_tree().physics_frame
		frames += 1
		if frames < int(shots [next]):
			continue
		for i in ts.size():
			var t:= ts [i]
			var mid:= t.global_position
			print("[tsplittershot] rig %d frame %d arm %.3f" % [i, frames, t.call("arm_angle")])
			await _shot(mid + Vector3(0.001, 4.2, 0.0), mid,
				"%s/rig%d_top_%d.png" % [out_dir, i, next])
			if next == 0:
				var fwd: Vector3 = t.call("forward")
				await _shot(mid - fwd * 3.2 + Vector3(0.0, 1.5, 0.0) + t.global_basis.x * 1.2,
					mid + Vector3(0.0, 0.1, 0.0), "%s/rig%d_low.png" % [out_dir, i])
		next += 1


	var t0:= ts [0]
	var glass:= t0.to_global(ConveyorTBody.SCREEN_AT)
	await _shot(glass + (t0.global_basis * Vector3(0.0, 0.05, -0.9)), glass,
		"%s/rig0_screen.png" % out_dir)
	for i in [1, 2]:
		var tn:= ts [i]
		glass = tn.to_global(ConveyorTBody.SCREEN_AT)
		await _shot(glass + (tn.global_basis * Vector3(0.0, 0.05, -0.9)), glass,
			"%s/rig%d_screen.png" % [out_dir, i])
	print("[tsplittershot] fed %d wads" % fed)
	get_tree().quit()


func _hover_shots(out_dir: String, deck: Vector3) -> void:
	var builds: BuildManager = world.builds
	var t:= builds.add_t_splitter(Vector3(-14.0, 0.0, 8.0) + deck, 0.0) as ConveyorTSplitter
	if player != null:
		player.global_position = Vector3(-2.0, 0.4, 16.0)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 60.0
	get_tree().root.add_child(_cam)
	_cam.make_current()
	for _i in 30:
		await get_tree().physics_frame
	var mid:= t.global_position
	var eye:= mid + t.global_basis * Vector3(0.6, 1.7, -3.6)
	t.show_possible(true, 0.0)
	for step in t.setups().size():
		await _shot(eye, mid + Vector3(0.0, 0.4, 0.0), "%s/hover_%d.png" % [out_dir, step])
		t.show_possible(true, ConveyorTSplitter.SHOW_EACH + 0.01)
	t.show_possible(false, 0.0)
	var stem:= t.to_global(t.mouth_of(ConveyorTSplitter.STEM))
	builds.add_conveyor(stem, stem + t.global_basis * ConveyorTSplitter.lane_out(
		ConveyorTSplitter.STEM) * OUT_RUN)
	for _i in 10:
		await get_tree().physics_frame
	t.show_possible(true, 0.0)
	await _shot(eye + t.global_basis * Vector3(2.0, 0.0, 0.0), mid + Vector3(0.0, 0.4, 0.0),
		"%s/hover_stem_out.png" % out_dir)


func _shot(eye: Vector3, target: Vector3, path: String) -> void:
	_cam.look_at_from_position(eye, target, Vector3.UP)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[tsplittershot] %s" % path.get_file())
