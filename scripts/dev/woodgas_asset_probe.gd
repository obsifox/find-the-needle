extends SceneTree


var failures: Array [String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var scene:= load("res://assets/models/woodgas_plant/woodgas_plant.tscn") as PackedScene
	check(scene != null, "Plant scene imports")
	if scene == null:
		quit(1)
		return
	var plant:= scene.instantiate() as Node3D
	root.add_child(plant)
	await process_frame
	var inlet:= plant.find_child("Marker_BeltIn", true, false) as Node3D
	var head:= plant.find_child("Marker_BeltHead", true, false) as Node3D
	check(inlet != null and head != null, "Belt markers exist")
	if inlet != null and head != null:
		check(inlet.position.is_equal_approx(Vector3(0, 0.43, -3)), "Inlet is on the metre grid at the game deck height")
		check(is_equal_approx(inlet.position.y, head.position.y), "Intake remains horizontal")
	var report: Dictionary = { }
	for node in plant.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		check(mesh.get_surface_count() == 1, node.name + " has one merged surface")
		var triangles: int = 0
		for i in mesh.get_surface_count():
			check(mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_TEX_UV != 0, node.name + " has UVs")
			triangles += mesh.surface_get_array_index_len(i) / 3
		report [node.name] = triangles
	var near:= plant.find_child("WG_Body_LOD0", true, false) as MeshInstance3D
	var mid:= plant.find_child("WG_Body_LOD1", true, false) as MeshInstance3D
	var far:= plant.find_child("WG_Body_LOD2", true, false) as MeshInstance3D
	check(near.visibility_range_end == mid.visibility_range_begin, "First LOD boundary is continuous")
	check(mid.visibility_range_end == far.visibility_range_begin, "Second LOD boundary is continuous")
	check(mid.material_override == near.mesh.surface_get_material(0), "Middle LOD shares the atlas material")
	check(far.material_override == mid.material_override, "Far LOD shares the atlas material")
	check(report ["WG_Body_LOD0"] < 25000, "Close body triangle budget")
	check(report ["WG_Body_LOD1"] < 10000, "Middle body triangle budget")
	check(report ["WG_Body_LOD2"] < 5000, "Far body triangle budget")
	plant.drive = 1.0
	plant._process(0.25)
	check(plant.phase > 0.0, "Running moves the frosted pattern")
	plant.drive = 0.0
	var stopped: float = plant.phase
	plant._process(0.25)
	check(plant.phase == stopped, "Stopped freezes the frosted pattern")
	check(not plant.hearth.visible, "Stopped extinguishes the hearth")
	print("[woodgas] ", JSON.stringify(report))
	var args:= OS.get_cmdline_user_args()
	if args.has("--render"):
		await capture(plant, args [args.find("--render") + 1])
	print("[woodgas] PASS" if failures.is_empty() else "[woodgas] FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)

func cube(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node:= MeshInstance3D.new()
	var mesh:= BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	node.material_override = mat
	root.add_child(node)
	node.position = at
	return node

func capture(plant: Node3D, folder: String) -> void:
	root.size = Vector2i(1400, 1400)
	var environment:= WorldEnvironment.new()
	var env:= Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	root.add_child(environment)
	var light:= DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	cube(Vector3(0, -0.075, 0), Vector3(200, 0.1, 200), Color(0.22, 0.24, 0.22))

	cube(Vector3(0, 0.395, -3.75), Vector3(0.9, 0.07, 1.5), Color(0.035, 0.04, 0.035))
	for x in [- 0.4275, 0.4275]:
		cube(Vector3(x, 0.495, -3.75), Vector3(0.045, 0.13, 1.5), Color(0.24, 0.26, 0.24))
		for z in [-3.1, -4.35]:
			cube(Vector3(x, 0.19, z), Vector3(0.07, 0.38, 0.07), Color(0.2, 0.23, 0.2))
	var camera:= Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.6
	camera.current = true
	plant.drive = 0.7
	for view in ["front", "cleaning"]:
		camera.position = Vector3(9, 7, -11) if view == "front" else Vector3(-10, 6, -8)
		camera.look_at(Vector3(0, 2.1, 0))
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("godot_" + view + ".png"))
