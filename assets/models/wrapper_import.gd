@tool
extends "res://assets/models/palette_import.gd"


func _post_import(scene: Node) -> Object:
	super._post_import(scene)
	var shared:= { }
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var original = node.mesh.surface_get_material(surface)
			if original == null or not original.get_meta("immutable_palette", false):
				continue
			var id = original.get_instance_id()
			if not shared.has(id):
				var material: ShaderMaterial = original.duplicate()
				material.shader = preload("res://assets/shaders/wrapper_palette.gdshader")
				var image: Image = original.get_shader_parameter("palette").get_image()
				var entries: Array = original.get_meta("palette_entries")
				for index in entries.size():
					var key: String = entries [index].trim_prefix("M_HW_")
					var kind:= 0.0
					if key in ["Frame", "Shell", "Ivory", "Guard", "Trim", "Cast"]:
						kind = 1.0
					elif key in ["Chrome", "Steel", "Roller", "Rod", "Copper"]:
						kind = 2.0
					elif key in ["Dark", "Rubber"]:
						kind = 3.0
					var color:= image.get_pixel(index, 0)
					color.a = kind
					image.set_pixel(index, 0, color)
				material.set_shader_parameter("palette", ImageTexture.create_from_image(image))
				material.set_shader_parameter("paint_detail", preload("res://assets/models/wrapper_paint_detail.png"))
				material.set_shader_parameter("steel_detail", preload("res://assets/models/wrapper_steel_detail.png"))
				material.set_shader_parameter("rubber_detail", preload("res://assets/models/wrapper_rubber_detail.png"))
				shared [id] = material
			node.mesh.surface_set_material(surface, shared [id])
	_hide_collapsed_props(scene)
	return scene


func _hide_collapsed_props(scene: Node) -> void:
	var player:= scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation("Cycle"):
		return
	var clip:= player.get_animation("Cycle")
	var count:= clip.get_track_count()
	for track in count:
		if clip.track_get_type(track) != Animation.TYPE_SCALE_3D:
			continue
		var path:= clip.track_get_path(track)
		var node_name:= String(path.get_name(path.get_name_count() - 1))
		if not node_name in ["Wrapper_Bale", "Wrapper_Foiled", "Wrapper_Film"]:
			continue
		var visibility:= clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(visibility, NodePath(String(path) + ":visible"))
		clip.value_track_set_update_mode(visibility, Animation.UPDATE_DISCRETE)
		var previous:= false
		for key in clip.track_get_key_count(track):
			var scale: Vector3 = clip.track_get_key_value(track, key)
			var shown:= scale.length_squared() > 0.01
			if key == 0 or shown != previous:
				clip.track_insert_key(visibility, clip.track_get_key_time(track, key), shown)
			previous = shown
