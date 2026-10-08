class_name DevYardDigProbe
extends Node


const SCOOPS:= 5
const SAMPLE:= 40


const HEADER:= "   n  lifted   live  awake   worst_ms   mean_ms  worst_phys_ms  chunks   grid  shape   surf  visits  settling"

var world: Node3D
var player: Player
var field: HayField


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--yarddig")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("YARDDIG: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("YARDDIG: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("YARDDIG: save version %d, %d buildings, %d props, block_save=%s"
		% [int(d.get("version", 0)), (d.get("buildings", []) as Array).size(),
			(d.get("props", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))


	var props_n: int = (d.get("props", []) as Array).size()
	if props_n > Cfg.prop_cap:
		Cfg.prop_cap = props_n
	Cfg.perf_scale = 1.0

	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)


	var face:= Vector3.INF
	for step in 60:
		var x:= 14.0 - float(step) * 0.25
		var h:= field.height_at(x, -1.0)
		if h > 1.2:
			face = Vector3(x, h, -1.0)
			break
	if face == Vector3.INF:
		print("YARDDIG: no pile face found along z = -1")
		get_tree().quit(1)
		return
	var eye:= Vector3(face.x + 1.3, 1.7, face.z)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	var flat:= Vector3(face.x - eye.x, 0.0, face.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(face.y - 0.3 - eye.y, maxf(flat.length(), 0.001))
	player.shovel.reset_aim()
	print("YARDDIG: face at %s, %.2f m of hay, %d strands in the pile"
		% [str(face), face.y, int(GameState.hay_total)])
	for k in 240:
		await get_tree().physics_frame

	print("\n--- standing still at the face ---")
	await _sample("idle", 0)

	await _round("AS PLAYED", false, false)
	await _round("PILE FROZEN (no settling, no redraw)", true, false)
	await _round("PAN EMPTIED (strands consumed on the click)", false, true)
	await _litter(600)
	print("\n(16.7 ms = 60 fps; worst_ms is the single worst frame after a click;"
		+ " grid/shape/surf are HayChunk rebuild ms inside the sample; visits are relax vertex visits)")
	get_tree().quit()


func _round(label: String, freeze_pile: bool, empty_pan: bool) -> void:
	print("\n--- %s ---" % label)
	print(HEADER)
	field.set_process(not freeze_pile)


	HotSpots.start()
	var frames0:= Engine.get_process_frames()
	var ticks0:= Engine.get_physics_frames()
	var usec0:= Time.get_ticks_usec()
	for n in range(1, SCOOPS + 1):
		var lifted: int = player.shovel.scoop()
		if empty_pan:
			_consume_all()
		await _sample("", n, lifted)


		if not empty_pan:
			player.shovel.dump()
		for k in 30:
			await get_tree().physics_frame
	HotSpots.stop()
	var frames:= maxi(1, Engine.get_process_frames() - frames0)
	print("  round: %d frames, %.2f ms a frame, %.2f ticks a frame, %d live strands at the end; by system:"
		% [frames, (Time.get_ticks_usec() - usec0) / 1000.0 / frames,
		float(Engine.get_physics_frames() - ticks0) / frames, world.live.active_count()])
	for line in HotSpots.lines(frames):
		print(line)
	field.set_process(true)


	_consume_all()
	for k in 60:
		await get_tree().physics_frame


func _sample(label: String, n: int, lifted: int = 0) -> void:
	var worst:= 0.0
	var worst_phys:= 0.0
	var total:= 0.0
	var visits:= 0
	var settling:= 0
	var rebuilds0:= HayChunk.profile_rebuilds
	var grid0:= HayChunk.profile_grid_usec
	var shape0:= HayChunk.profile_shape_usec
	var surf0:= HayChunk.profile_surface_usec
	for i in SAMPLE:
		await get_tree().process_frame
		var dt:= get_process_delta_time()
		total += dt
		worst = maxf(worst, dt)
		worst_phys = maxf(worst_phys,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		visits += field.last_relax_visits()
		settling = maxi(settling, field.settling_count())
	var rebuilds:= HayChunk.profile_rebuilds - rebuilds0
	var grid:= float(HayChunk.profile_grid_usec - grid0) / 1000.0
	var shape:= float(HayChunk.profile_shape_usec - shape0) / 1000.0
	var surf:= float(HayChunk.profile_surface_usec - surf0) / 1000.0
	if label != "":
		print(HEADER)
	print("  %2d  %6d  %5d  %5d   %8.2f  %8.2f   %12.2f  %6d  %6.2f %6.2f %6.2f  %6d  %8d"
		% [n, lifted, world.live.active_count(), _awake(),
					worst * 1000.0, total / SAMPLE * 1000.0, worst_phys * 1000.0,
					rebuilds, grid, shape, surf, visits, settling])


func _litter(n: int) -> void:
	print("\n--- LITTER (%d strands dropped near the player) ---" % n)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var at:= player.global_position - player.global_transform.basis.z * 2.0
	for i in n:
		var p:= at + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(1.0, 3.0),
			rng.randf_range(-2.0, 2.0))
		var b:= Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		world.live.spawn(p, b, Vector3.ZERO, Color(0.8, 0.7, 0.4))
	for phase in ["falling", "lying"]:
		if phase == "lying":
			for k in 600:
				await get_tree().physics_frame
		HotSpots.start()
		var frames0:= Engine.get_process_frames()
		var ticks0:= Engine.get_physics_frames()
		var usec0:= Time.get_ticks_usec()
		for k in 300:
			await get_tree().process_frame
		HotSpots.stop()
		var frames:= maxi(1, Engine.get_process_frames() - frames0)
		print("  %s: %.2f ms a frame, %.2f ticks a frame, %d live, %d awake; by system:"
			% [phase, (Time.get_ticks_usec() - usec0) / 1000.0 / frames,
			float(Engine.get_physics_frames() - ticks0) / frames,
			world.live.active_count(), _awake()])
		for line in HotSpots.lines(frames).slice(0, 10):
			print(line)


func _awake() -> int:
	var n:= 0
	for b in world.live._active:
		if b is RigidBody3D and not (b as RigidBody3D).sleeping:
			n += 1
	return n


func _consume_all() -> void:
	var bodies: Array = world.live._active.duplicate()
	for b in bodies:
		if b is RigidBody3D:
			world.live.consume(b)
