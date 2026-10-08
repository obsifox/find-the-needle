extends SceneTree


const OUT:= "res://.scratchpad/hay_product_rollout/"
var stage: Node3D
var groups:= { }
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mesh_lod_threshold = 0.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	stage = Node3D.new()
	root.add_child(stage)
	var env:= WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.12, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	stage.add_child(env)
	var sun:= DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.5
	stage.add_child(sun)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 24, 29)
	camera.look_at(Vector3(0, 0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 42
	var results:= []
	for count in [1000, 3000]:
		for version in ["before", "after"]:
			var holder:= Node3D.new()
			stage.add_child(holder)
			groups [version] = holder
			var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(OUT + version + "/runtime.json"))
			for kind in rows.size():
				var row: Dictionary = rows [kind]
				for part: Dictionary in row.parts:
					var mm:= MultiMesh.new()
					mm.transform_format = MultiMesh.TRANSFORM_3D
					mm.mesh = load(part.mesh)
					mm.instance_count = count / rows.size()
					var local: Transform3D = str_to_var(part.transform)
					for i in mm.instance_count:
						var n: int = i * rows.size() + kind
						var position:= Vector3((n % 50 - 24.5) * 0.75, 0, (n / 50 - (count / 50 - 1) * 0.5) * 0.75)
						mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, position) * local)
					var mi:= MultiMeshInstance3D.new()
					mi.multimesh = mm
					holder.add_child(mi)
				holder.visible = false
		camera.size = 42 if count == 1000 else 52
		for version in ["before", "after", "before", "after"]:
			groups.before.visible = version == "before"
			groups.after.visible = version == "after"
			for i in 45:
				await process_frame
			var start:= Time.get_ticks_usec()
			var gpu:= 0.0
			var cpu:= 0.0
			for i in 120:
				await process_frame
				if i % 10 == 9:
					gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
					cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			var result:= { "version": version, "count": count,
				"frame_ms": (Time.get_ticks_usec() - start) / 120000.0,
				"gpu_ms": gpu / 12, "render_cpu_ms": cpu / 12,
				"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) }
			results.append(result)
			print("[product render] ", JSON.stringify(result))
		for holder: Node3D in groups.values():
			holder.free()
		groups.clear()
	FileAccess.open(OUT + "render_results.json", FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	stage.free()
	quit()
