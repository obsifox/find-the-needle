extends SceneTree


var failed:= false

func check(label: String, ok: bool) -> void:
	print("[feed disc] %s: %s" % ["PASS" if ok else "FAIL", label])
	failed = failed or not ok

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var disc_script: Script = load("res://scripts/items/feed_disc.gd")
	var mesh: Mesh = disc_script.shared_mesh()
	check("mesh imports", mesh != null)
	if mesh == null:
		quit(1)
		return
	check("two shared surfaces", mesh.get_surface_count() == 2)
	check("under 5500 triangles", mesh.get_faces().size() / 3 <= 5500)
	var box:= mesh.get_aabb()
	check("base sits on floor", absf(box.position.y) < 0.001)
	check("collider fit", box.size.distance_to(Vector3(0.596, 0.198, 0.602)) < 0.012)
	var mat:= mesh.surface_get_material(0) as StandardMaterial3D
	check("shared baked material", mat != null)
	if mat != null:
		check("albedo atlas", mat.albedo_texture != null)
		check("normal atlas", mat.normal_enabled and mat.normal_texture != null)
	var stage:= Node3D.new()
	root.add_child(stage)
	var first = disc_script.new()
	var second = disc_script.new()
	stage.add_child(first)
	stage.add_child(second)
	first.freeze = true
	second.freeze = true
	second.position = Vector3(0.7, 0, 0.2)
	var a:= first.get_node("Disc") as MeshInstance3D
	var b:= second.get_node("Disc") as MeshInstance3D
	check("instances share mesh and material", a.mesh == b.mesh and a.get_active_material(0) == b.get_active_material(0))
	check("highlight mesh is registered", first._meshes.has(a))
	check("cylinder collider", first.find_children("*", "CollisionShape3D", true, false).size() == 1)
	if OS.get_cmdline_user_args().has("--shot"):
		var env:= WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.13, 0.15, 0.17)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.35
		stage.add_child(env)
		var sun:= DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -35, 0)
		sun.light_energy = 1.3
		sun.shadow_enabled = true
		stage.add_child(sun)
		var floor_mesh:= MeshInstance3D.new()
		var plane:= PlaneMesh.new()
		plane.size = Vector2(200, 200)
		floor_mesh.mesh = plane
		floor_mesh.position.y = -0.002
		var floor_mat:= StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.8, 0.8, 0.8)
		floor_mat.roughness = 1.0
		floor_mesh.material_override = floor_mat
		stage.add_child(floor_mesh)
		var camera:= Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(0.55, 0.72, 0.98)
		camera.look_at(Vector3(0.03, 0.09, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 0.83
		second.visible = false
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/feed_disc/godot.png")
		camera.size = 0.18
		camera.position = Vector3(0.12, 0.34, 0.35)
		camera.look_at(Vector3(0, 0.16, 0.08))
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/feed_disc/detail.png")
	stage.free()
	quit(1 if failed else 0)
