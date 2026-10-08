@tool
extends "res://assets/models/lods/import.gd"


func _post_import(scene: Node) -> Object:
	var source:= get_source_file()
	var spec_path:= "%s/%s_materials.json" % [source.get_base_dir(), source.get_file().get_basename()]
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/machine_palette_profiles.json"))
	var profile: Dictionary = profiles.get(source.get_file(), { })
	if profile.get("install_lods", true):
		super._post_import(scene)
	if not profile.get("enabled", true):
		return scene
	if not profile.is_empty():
		spec_path = profile.get("spec", spec_path)
	if FileAccess.file_exists(spec_path):
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
		preload("res://assets/models/machine_palette.gd").apply(scene, spec)
		if not profile.is_empty():
			preload("res://assets/models/machine_palette.gd").apply_profile(scene, spec, profile)
	return scene
