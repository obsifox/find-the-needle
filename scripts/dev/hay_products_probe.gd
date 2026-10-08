extends SceneTree


const OUT:= "res://.scratchpad/hay_product_rollout/"
const PRODUCTS:= {
	"hay_pulp": 4900, "feed_disc": 5500, "hay_wad": 12400,
	"tuft_small": 520, "tuft_medium": 1600, "tuft_large": 3610,
	"hay_bale": 410, "foiled_bale": 1210, "eco_brick": 860, "paper_roll": 530,
}
var failed:= false
var stage: Node3D
var rows:= []

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	print("[products] %s %s" % ["PASS" if ok else "FAIL", label])
	failed = failed or not ok

func make(id: String):
	var body = load("res://scripts/items/item_db.gd").make("hay_tuft" if id.begins_with("tuft_") else id)
	if id.begins_with("tuft_"):
		body.strands = { "tuft_small": 12, "tuft_medium": 40, "tuft_large": 100 } [id]
	body.freeze = true
	stage.add_child(body)
	if id == "hay_wad" or id.begins_with("tuft_"):
		body._set_lod(0)
	return body

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "after"))
	var originals: Array = []
	if FileAccess.file_exists(OUT + "before/runtime.json"):
		originals = JSON.parse_string(FileAccess.get_file_as_string(OUT + "before/runtime.json"))
	for id: String in PRODUCTS:
		var first = make(id)
		var second = make(id)
		var state: Dictionary = first.to_state()
		second.from_state(state)
		check(id + " state and value", second.to_state() == state and is_equal_approx(first.sale_strands(), second.sale_strands()) and first.hay_strands() == second.hay_strands())
		check(id + " collider present", not first.find_children("*", "CollisionShape3D", true, false).is_empty())
		var row:= { "id": id, "triangles": 0, "surfaces": 0, "parts": [], "native_lod_levels": 0 }
		var matches:= originals.filter(func(r): return r.id == id)
		var old: Dictionary = { } if matches.is_empty() else matches [0]
		for part in first._meshes.size():
			var mi: MeshInstance3D = first._meshes [part]
			var other: MeshInstance3D = second._meshes [part]
			var mesh:= mi.mesh
			check(id + " shared mesh %d" % part, mesh == other.mesh)
			if not old.is_empty():
				var baseline: Mesh = load(old.parts [part].mesh)
				var box:= mesh.get_aabb()
				var before:= baseline.get_aabb()
				check(id + " bounds %d" % part, box.position.distance_to(before.position) < 0.03 and box.size.distance_to(before.size) < 0.04)
			for s in mesh.get_surface_count():
				var material:= mi.get_active_material(s)
				check(id + " shared material %d:%d" % [part, s], material != null and material == other.get_active_material(s))
				if material != null and material.resource_name in ["Pulp_Baked", "Feed_Baked", "Paper_Baked"]:
					check(id + " baked detail textures", material is StandardMaterial3D and material.albedo_texture != null and material.normal_enabled and material.normal_texture != null)
				row.native_lod_levels += RenderingServer.mesh_get_surface(mesh.get_rid(), s).get("lods", []).size()
			row.triangles += mesh.get_faces().size() / 3
			row.surfaces += mesh.get_surface_count()
			var copy: Mesh = mesh.duplicate()
			for s in mesh.get_surface_count():
				copy.surface_set_material(s, mi.get_active_material(s))
			var path:= OUT + "after/%s_%d.res" % [id, part]
			ResourceSaver.save(copy, path)
			var xf: Transform3D = first.global_transform.affine_inverse() * mi.global_transform
			row.parts.append({ "mesh": path, "transform": var_to_str(xf) })
		check(id + " triangle budget", row.triangles <= PRODUCTS [id])
		rows.append(row)
		first.free()
		second.free()
	var sack: Node = load("res://assets/models/hay_sack.glb").instantiate()
	var sack_mesh:= sack.find_child("HaySack", true, false) as MeshInstance3D
	check("sack Fill morph", sack_mesh != null and sack_mesh.mesh.get_blend_shape_count() == 1 and sack_mesh.mesh.get_blend_shape_name(0) == "Fill")
	if sack_mesh != null:
		check("sack triangle budget", sack_mesh.mesh.get_faces().size() / 3 <= 1500)
		check("sack morph arrays", not sack_mesh.mesh.surface_get_blend_shape_arrays(0).is_empty())
	sack.free()
	FileAccess.open(OUT + "after/runtime.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("[products] COUNTS ", JSON.stringify(rows))
	if "--render" in OS.get_cmdline_user_args():
		await render_group()
	stage.free()
	quit(1 if failed else 0)

func render_group() -> void:
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
	var camera:= Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 5.8, 7.6)
	camera.look_at(Vector3(0, 0, - 0.5))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.2
	var index:= 0
	for id: String in PRODUCTS:
		var body = make(id)
		body.position = Vector3((index % 5 - 2) * 1.2, 0.1, (index / 5 - 0.5) * 2.0)
		if id == "paper_roll":
			body.rotation.y = 0.6
		var label:= Label3D.new()
		label.text = id.replace("_", " ")
		label.font_size = 40
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = body.position + Vector3(0, 0, 0.65)
		stage.add_child(label)
		index += 1
	var sack: Node3D = load("res://assets/models/hay_sack.glb").instantiate()
	stage.add_child(sack)
	sack.position = Vector3(0, 0.1, -2.8)
	var sack_mesh:= sack.find_child("HaySack", true, false) as MeshInstance3D
	sack_mesh.set_blend_shape_value(0, 1.0)
	var sack_label:= Label3D.new()
	sack_label.text = "hay sack (filled)"
	sack_label.font_size = 40
	sack_label.pixel_size = 0.003
	sack_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sack_label.position = sack.position + Vector3(0, 0, 0.65)
	stage.add_child(sack_label)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "group.png")
