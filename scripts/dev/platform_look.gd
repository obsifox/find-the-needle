extends Node3D


const SHOT:= "user://platform_look.png"


func _ready() -> void:
	_floor()
	_light()
	_camera()

	var builds:= BuildManager.new()
	add_child(builds)
	await get_tree().process_frame
	await get_tree().physics_frame

	var a:= builds.add_platform(Vector3(0.0, 3.0, 0.0), Vector2(8.0, 6.0))
	builds.add_platform(Vector3(8.0, 3.0, 0.0), Vector2(8.0, 6.0))
	await get_tree().process_frame
	await get_tree().physics_frame

	var edge: Dictionary = a.nearest_edge(Vector3(0.0, 3.0, 9.0))
	var out_yaw:= atan2(- edge ["outward"].x, - edge ["outward"].z)
	builds.add_stair(edge ["point"], out_yaw, 3.0)


	builds.add_stair(edge ["point"] + Vector3(-3.0, 0.0, 0.0), out_yaw, 3.0,
		Cfg.STAIR_PITCH_MIN)

	var belt_y:= 3.0 + Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	builds.add_conveyor(Vector3(-2.5, belt_y, -1.5), Vector3(10.0, belt_y, -1.5))


	var back:= -3.0
	var front:= 3.0
	builds.add_railing(Vector3(-4.0, 3.0, back), Vector3(12.0, 3.0, back))
	builds.add_railing(Vector3(-4.0, 3.0, front), Vector3(-1.2, 3.0, front))
	builds.add_railing(Vector3(1.2, 3.0, front), Vector3(12.0, 3.0, front))


	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image:= get_viewport().get_texture().get_image()
	image.save_png(SHOT)
	print("wrote ", ProjectSettings.globalize_path(SHOT))
	get_tree().quit()


func _floor() -> void:
	var body:= StaticBody3D.new()
	body.collision_layer = Cfg.L_WORLD
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)

	var mi:= MeshInstance3D.new()
	var plane:= PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	var mat:= StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.32)
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)


func _light() -> void:
	var sun:= DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-125.0), 0.0)
	sun.light_energy = 1.5
	add_child(sun)

	var env:= Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	var world_env:= WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _camera() -> void:
	var cam:= Camera3D.new()
	cam.position = Vector3(-11.0, 7.5, 12.0)
	cam.look_at_from_position(cam.position, Vector3(2.0, 2.0, 0.0), Vector3.UP)
	cam.fov = 62.0
	add_child(cam)
