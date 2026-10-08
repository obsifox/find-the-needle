extends RefCounted


var _paths: Array [String] = []
var _retained: Array [Node] = []

func _collect(folder: String) -> void:
	for file in ResourceLoader.list_directory(folder):
		if file.ends_with("/"):
			_collect(folder.path_join(file.trim_suffix("/")))
		elif file.get_extension() in ["glb", "tscn", "scn"]:
			_paths.append(folder.path_join(file))

func run(probe: Node) -> void:
	if not probe.world.block_save:
		push_error("Model gallery requires the guarded yard performance harness")
		probe.get_tree().quit(1)
		return
	_collect("res://assets/models")
	_collect("res://assets/terrain/flora")
	_paths.append("res://robotic_arm_game_ready.glb")
	_paths.sort()
	var folder:= "res://.scratchpad/all-model-gallery-game"
	var args:= OS.get_cmdline_user_args()
	var output_at:= args.find("--gallery-output")
	if output_at >= 0: folder = args [output_at + 1]
	DirAccess.make_dir_recursive_absolute(folder)

	var layer:= CanvasLayer.new()
	layer.layer = 100
	probe.world.add_child(layer)
	var container:= SubViewportContainer.new()
	container.size = probe.get_viewport().get_visible_rect().size
	container.stretch = true
	layer.add_child(container)
	var root:= SubViewport.new()
	root.size = Vector2i(960, 540)
	root.own_world_3d = true
	root.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(root)
	root.use_taa = false
	var stage:= Node3D.new()
	root.add_child(stage)
	var environment:= WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.2, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.5
	stage.add_child(environment)
	var sun:= DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	var camera:= Camera3D.new()
	camera.fov = 50
	camera.near = 0.01
	camera.far = 5000.0
	stage.add_child(camera)
	camera.make_current()
	var rows:= []
	for index in _paths.size():
		var path:= _paths [index]
		var packed:= load(path) as PackedScene
		if packed == null:
			push_error("Model did not load: " + path)
			probe.get_tree().quit(1)
			return
		var model:= packed.instantiate() as Node3D
		if model == null:
			push_error("Model did not instantiate: " + path)
			probe.get_tree().quit(1)
			return
		model.process_mode = Node.PROCESS_MODE_DISABLED
		var name:= path.get_file().get_basename()
		var script_name:= "robotic_arm" if name == "robotic_arm_game_ready" else name
		if name == "hay_pulper_reference": script_name = "hay_pulper"
		var skinned:= false
		var script_path:= "res://scripts/build/%s.gd" % script_name
		if ResourceLoader.exists(script_path):
			var machine: Object = load(script_path).new()
			if machine is Node: _retained.append(machine)
			var has_model:= false
			for property: Dictionary in machine.get_property_list():
				has_model = has_model or property ["name"] == "_model"
			var method:= "_apply_game_materials" if script_name == "robotic_arm" else "_skin"
			if has_model and machine.has_method(method):
				machine.set("_model", model)
				machine.call(method)
				skinned = true
			if script_name == "robotic_arm":
				for hidden: String in machine.HIDDEN_HELPERS + ["RA_ReachOrb_Ghost", "RA_ReachGroundRing"]:
					var helper:= model.find_child(hidden, true, false) as Node3D
					if helper != null: helper.visible = false
		for animation: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
			animation.active = false
		stage.add_child(model)
		var bounds:= AABB()
		var have_bounds:= false
		for mesh: Node3D in [model] + model.find_children("*", "Node3D", true, false):
			if not mesh.is_visible_in_tree(): continue
			var local_bounds:= AABB()
			if mesh is MeshInstance3D and mesh.mesh != null:
				local_bounds = mesh.mesh.get_aabb()
			elif mesh is MultiMeshInstance3D and mesh.multimesh != null:
				local_bounds = mesh.multimesh.get_aabb()
			else: continue
			var box: AABB = mesh.global_transform * local_bounds
			bounds = bounds.merge(box) if have_bounds else box
			have_bounds = true
		if not have_bounds:
			push_error("Model has no visible mesh: " + path)
			probe.get_tree().quit(1)
			return
		var center:= bounds.get_center()
		var radius:= maxf(bounds.size.length() * 1.05, 0.05)
		var shots:= []
		for view in 2:
			var direction:= Vector3(1, 0.55, 1) if view == 0 else Vector3(-1, 0.45, -1)
			camera.look_at_from_position(center + direction.normalized() * radius, center)
			for frame in 24: await probe.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var output:= "%s/%03d-%s-%d.png" % [folder, index, name, view]
			var saved:= root.get_texture().get_image().save_png(output)
			if saved != OK:
				push_error("Model screenshot could not be saved: " + output)
				probe.get_tree().quit(1)
				return
			shots.append(output)
		rows.append({ "path": path, "runtime_skin": skinned, "shots": shots })
		print("[all model gallery] %d/%d %s runtime_skin=%s" % [index + 1, _paths.size(), path, skinned])

		model.visible = false
		await probe.get_tree().process_frame
	var report:= FileAccess.open(folder.path_join("manifest.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(rows, "\t"))
	for machine: Node in _retained:
		machine.free()
	_retained.clear()
	layer.queue_free()
	for frame in 8: await probe.get_tree().process_frame
	print("[all model gallery] PASS %d models, %d views" % [_paths.size(), _paths.size() * 2])
	probe.get_tree().quit(0)
