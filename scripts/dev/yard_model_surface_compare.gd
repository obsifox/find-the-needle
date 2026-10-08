extends RefCounted


var _rows: Array [Dictionary] = []


func prepare(probe: Node) -> void:
	assert (probe.world.block_save)
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/machine_palette_profiles.json"))
	var originals:= { }
	var specs:= { }
	for file: String in profiles:
		if not profiles [file].get("enabled", true):
			continue
		var name:= file.get_basename()
		var suffix:= "tscn" if name in ["paper_machine", "briquette_press", "needle_radar"] else "scn"
		var type:= "robotic_arm" if name == "robotic_arm_game_ready" else name
		originals [type] = load("res://.scratchpad/model-rollout-before/%s.%s" % [name, suffix]).instantiate()
		var path: String = profiles [file].get("spec", "res://assets/models/%s_materials.json" % name)
		specs [type] = JSON.parse_string(FileAccess.get_file_as_string(path))
	originals ["hay_pulper"] = load("res://.scratchpad/pulper-palette-before/imported.scn").instantiate()
	specs ["hay_pulper"] = HayPulper.spec_table()
	var machines:= 0
	for machine: Node3D in probe.world.builds.every_placed():
		var type: String = machine.get_script().resource_path.get_file().get_basename()
		if not originals.has(type):
			continue
		var model:= machine.get("_model") as Node3D
		if model == null:
			continue
		var reference: Node = originals [type]
		var built:= { }
		var changed:= false
		for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if node.mesh == null or not reference.has_node(model.get_path_to(node)):
				continue
			var palette:= false
			for s in node.mesh.get_surface_count():
				var material: Material = node.mesh.surface_get_material(s)
				palette = palette or (material != null and (material.get_meta("immutable_palette", false) or specs [type].get("palettes", { }).has(material.resource_name)))
			if not palette:
				continue
			var original:= reference.get_node(model.get_path_to(node)) as MeshInstance3D
			assert (original != null)
			var kept:= { }
			var after: Array [Material] = []
			for s in node.mesh.get_surface_count():
				var key:= node.mesh.surface_get_material(s).resource_name
				kept [key] = node.get_surface_override_material(s)
				after.append(node.get_surface_override_material(s))
			var before: Array [Material] = []
			for s in original.mesh.get_surface_count():
				var key:= original.mesh.surface_get_material(s).resource_name
				if kept.has(key):
					before.append(kept [key])
					continue
				if not built.has(key):
					var material: Material = null
					if type == "robotic_arm":
						material = machine._game_material(key)
					elif type == "hay_pulper":
						material = machine._material_for(key, specs [type], load(HayCompressor.SHADER))
					elif profiles [type + ".glb"] ["finish_source"] == "table":
						material = HayCompressor.make_material(key, specs [type], load(HayCompressor.SHADER))
						if type == "hay_generator" and specs [type] ["flats"].get(key, { }).get("linear_color", false) and material is StandardMaterial3D:
							material.albedo_color = material.albedo_color.linear_to_srgb()
					built [key] = material
				before.append(built [key])
			_rows.append({ "node": node, "before_mesh": original.mesh, "after_mesh": node.mesh, "before": before, "after": after })
			changed = true
		if changed:
			machines += 1
	for reference: Node in originals.values():
		reference.free()
	assert (not _rows.is_empty())
	print("YARDPERF: model comparison prepared for %d machines and %d meshes" % [machines, _rows.size()])
	apply(false)
	if "--model-census" in OS.get_cmdline_user_args():
		var census:= preload("res://scripts/dev/yard_machine_census.gd").new()
		print("MODEL_CENSUS_STATE before")
		census.count(probe)
		apply(true)
		print("MODEL_CENSUS_STATE after")
		census.count(probe)
		apply(false)


func apply(merged: bool) -> void:
	var key:= "after" if merged else "before"
	for row: Dictionary in _rows:
		var node: MeshInstance3D = row ["node"]
		node.mesh = row [key + "_mesh"]
		for s in node.mesh.get_surface_count():
			node.set_surface_override_material(s, row [key] [s])
