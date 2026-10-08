extends "res://scripts/dev/machine_palette_probe.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/machine_palette_profiles.json"))
	for file: String in profiles:
		var profile: Dictionary = profiles [file]
		var name:= file.get_basename()
		var source:= "res://robotic_arm_game_ready.glb" if name == "robotic_arm_game_ready" else "res://assets/models/" + file
		var spec_path: String = profile.get("spec", "res://assets/models/%s_materials.json" % name)
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
		var suffix:= "tscn" if name in ["paper_machine", "briquette_press", "needle_radar"] else "scn"
		var before: Node = load("res://.scratchpad/model-rollout-before/%s.%s" % [name, suffix]).instantiate()
		var after: Node = load(source).instantiate()
		var count_before:= 0
		var count_after:= 0
		_check(before.find_children("*", "", true, false).size() == after.find_children("*", "", true, false).size(), "node count: " + name)
		for node in before.find_children("*", "", true, false):
			var path: NodePath = before.get_path_to(node)
			var other:= after.get_node_or_null(path)
			_check(other != null and other.get_class() == node.get_class(), "node contract: %s/%s" % [name, path])
			if other == null:
				continue
			if node is Node3D:
				_check(node.transform == other.transform and node.visible == other.visible, "transform and visibility: %s/%s" % [name, path])
			if node is AnimationPlayer:
				_check(node.get_animation_list() == other.get_animation_list(), "animation names: " + name)
				for clip: String in node.get_animation_list():
					var original_clip: Animation = node.get_animation(clip)
					if name == "paper_machine":
						original_clip = load("res://.scratchpad/model-rollout-before/paper_%s.res" % clip)
					elif name in ["briquette_press", "needle_radar"]:
						original_clip = load("res://.scratchpad/model-rollout-before/%s_%s.res" % [name, clip])
					_check(_animation(original_clip) == _animation(other.get_animation(clip)), "animation data: %s/%s" % [name, clip])
			if node is CollisionShape3D:
				_check(node.shape.get_class() == other.shape.get_class(), "collision type: %s/%s" % [name, path])
				for property: Dictionary in node.shape.get_property_list():
					if property ["usage"] & PROPERTY_USAGE_STORAGE and not property ["name"].begins_with("resource_"):
						_check(node.shape.get(property ["name"]) == other.shape.get(property ["name"]), "collision property: %s/%s/%s" % [name, path, property ["name"]])
			if not node is MeshInstance3D:
				continue
			count_before += node.mesh.get_surface_count()
			count_after += other.mesh.get_surface_count()
			var palettes:= []
			for s in other.mesh.get_surface_count():
				var material: Material = other.mesh.surface_get_material(s)
				if material != null and material.get_meta("immutable_palette", false):
					palettes.append(material)
			if palettes.is_empty():
				_check(_mesh_hashes(node.mesh) == _mesh_hashes(other.mesh), "untouched buffers: %s/%s" % [name, path])
				for s in node.mesh.get_surface_count():
					_check(_material_properties(node.mesh.surface_get_material(s)) == _material_properties(other.mesh.surface_get_material(s)), "untouched finish: %s/%s/%d" % [name, path, s])
				continue
			_check(palettes.size() == 1, "single compatible palette group: %s/%s" % [name, path])
			for material: ShaderMaterial in palettes:
				var entries: Array = material.get_meta("palette_entries")
				_check(material.get_meta("palette_spec_rows", { }).size() == entries.size(), "recorded material table: %s/%s" % [name, path])
				for key: String in entries:
					_check(material.get_meta("palette_spec_rows", { }).get(key) == spec ["flats"] [key], "current material table: " + key)
				_check("OUTPUT_IS_SRGB" in material.shader.code, "renderer colour conversion: %s/%s" % [name, path])
				_compare_body(node.mesh, other.mesh, entries, material.resource_name)
				var image: Image = material.get_shader_parameter("palette").get_image()
				for i in entries.size():
					var expected:= _effective_material(entries [i], node.mesh, spec, profile ["finish_source"])
					_check(expected != null, "effective original finish: " + str(entries [i]))
					if expected == null:
						continue
					_check(image.get_pixel(i, 0).is_equal_approx(expected.albedo_color.srgb_to_linear()), "effective linear colour: " + str(entries [i]))
					_check(image.get_pixel(i, 1).is_equal_approx(Color(expected.metallic, expected.roughness, expected.metallic_specular)), "metal, roughness and specular: " + str(entries [i]))
					_check(("cull_disabled" in material.shader.code) == (expected.cull_mode == BaseMaterial3D.CULL_DISABLED), "original face culling: " + str(entries [i]))
					_check(not expected.clearcoat_enabled and not expected.emission_enabled and expected.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "special finish remains excluded: " + str(entries [i]))
		PALETTE.apply_profile(before, spec, profile)
		for node in before.find_children("*", "MeshInstance3D", true, false):
			var other:= after.get_node(before.get_path_to(node)) as MeshInstance3D
			_check(_mesh_hashes(node.mesh) == _mesh_hashes(other.mesh), "current merge reproduces import: %s/%s" % [name, before.get_path_to(node)])
		print("[machine surfaces] %s: %d to %d source surfaces" % [name, count_before, count_after])
		before.free()
		after.free()
	print("[machine surfaces] %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _effective_material(key: String, source: ArrayMesh, spec: Dictionary, mode: String) -> StandardMaterial3D:
	if mode == "imported":
		for s in source.get_surface_count():
			if source.surface_get_material(s).resource_name == key:
				return source.surface_get_material(s)
		return null
	if mode == "linear_table":
		var arm: Node = load("res://scripts/build/robotic_arm.gd").new()
		var material: StandardMaterial3D = arm._game_material(key)
		arm.free()
		return material
	var factory: GDScript = load("res://scripts/build/hay_compressor.gd")
	var material:= factory.make_material(key, spec, load(factory.SHADER)) as StandardMaterial3D
	if spec ["flats"] [key].get("linear_color", false):
		material.albedo_color = material.albedo_color.linear_to_srgb()
	return material


func _material_properties(material: Material) -> Dictionary:
	var result:= { }
	if material == null:
		return result
	for property: Dictionary in material.get_property_list():
		var name: String = property ["name"]
		if not property ["usage"] & PROPERTY_USAGE_STORAGE or name == "resource_path":
			continue
		var value: Variant = material.get(name)
		if value is Texture2D:
			value = value.get_image().get_data().hex_encode().sha256_text()
		elif value is float:
			value = snappedf(value, 1e-06)
		result [name] = value
	return result
