extends SceneTree


const SUBJECTS:= {
	"briquette_press": "res://scripts/build/briquette_press.gd",
	"hay_pulper_reference": "res://scripts/build/hay_pulper.gd",
	"borehole_pump": "res://scripts/build/borehole_pump.gd",
	"hay_silo": "res://scripts/build/hay_silo.gd",
	"paper_machine": "res://scripts/build/paper_machine.gd",
	"feed_disc": "res://scripts/items/feed_disc.gd",
	"hay_pulp": "res://scripts/items/hay_pulp.gd" }
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var folder:= "res://.scratchpad/machine_opt/shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280, 720)
	root.use_taa = false
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.msaa_3d = Viewport.MSAA_4X
	root.mesh_lod_threshold = 1.0
	var stage:= Node3D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(stage)
	var env:= WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.14, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var sun:= DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	var fill:= DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_energy = 0.5
	stage.add_child(fill)
	var cam:= Camera3D.new()
	cam.fov = 50
	cam.near = 0.02
	cam.far = 1000
	stage.add_child(cam)
	for name in SUBJECTS:
		if not OS.get_cmdline_user_args().is_empty() and not name in OS.get_cmdline_user_args():
			continue
		var script: Script = load(SUBJECTS [name])
		var subject: Node3D = script.new()
		subject.process_mode = Node.PROCESS_MODE_DISABLED
		stage.add_child(subject)
		if subject is RigidBody3D: subject.freeze = true
		await process_frame
		for anim: AnimationPlayer in subject.find_children("*", "AnimationPlayer", true, false):
			anim.active = false
		var meshes: Array = subject.find_children("*", "MeshInstance3D", true, false)
		var replacements:= { }
		var bounds:= AABB()
		var first:= true
		for mi: MeshInstance3D in meshes:
			if mi.mesh == null or not mi.is_visible_in_tree(): continue
			var box: AABB = mi.global_transform * mi.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			if mi.mesh is ArrayMesh and mi.mesh.get_blend_shape_count() == 0:
				var full:= ArrayMesh.new()
				var surfaces: Array = mi.mesh.get("_surfaces")
				for surface: Dictionary in surfaces: surface.erase("lods")
				full.set("_surfaces", surfaces)
				replacements [mi] = [mi.mesh, full]
		var center:= bounds.get_center()
		var extent:= bounds.size.length()
		for angle in 2:
			var direction:= Vector3(-1, 0.55, 1) if angle == 0 else Vector3(1, 0.7, -1)
			for distance in ["near", "far"]:
				var dist: float = extent if distance == "near" else maxf(extent * 4.0, 12.0)
				cam.look_at_from_position(center + direction.normalized() * dist, center)
				for variant in ["full", "lod"]:
					for mi: MeshInstance3D in replacements: mi.mesh = replacements [mi] [1 if variant == "full" else 0]
					for i in 8: await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("%s/%s_%d_%s_%s.png" % [folder, name, angle, distance, variant])
		subject.free()
		print("[mesh shots] ", name)
	stage.free()
	quit()
