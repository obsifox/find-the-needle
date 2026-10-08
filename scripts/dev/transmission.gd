class_name DevTransmission
extends Node


var world: Node3D


const DISTANCES:= [3.0, 10.0, 25.0]

const BACKDROP:= Color(1.0, 0.0, 1.0)


const CONFIGS:= [
	["crust + shells (core)", true, true, true, "a_full"],
	["crust + shells (NO core)", true, true, false, "b_nocore"],
	["crust only", true, false, true, "c_crust"],
	["shells only (NO core)", false, true, false, "d_shells"],
]

var _cam: Camera3D
var _silhouette_mat: StandardMaterial3D


func run() -> void:
	for i in 40:
		await get_tree().process_frame

	_silhouette_mat = StandardMaterial3D.new()
	_silhouette_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_silhouette_mat.albedo_color = Color(1, 1, 1)

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.05
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true

	var env: Environment = world.env_node.environment
	var saved:= {
		"bg": env.background_mode,
		"color": env.background_color,
		"tone": env.tonemap_mode,
		"exposure": env.tonemap_exposure,
		"glow": env.glow_enabled,
		"amb_src": env.ambient_light_source,
		"amb_col": env.ambient_light_color,
		"amb_e": env.ambient_light_energy,
	}
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKDROP
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 1.0
	world.warehouse.visible = false

	print("\n=== pile transmission ===")
	print("  dist  configuration              leaked_px   body_px   transmission")
	for d: float in DISTANCES:
		_place(d)


		_set_silhouette(true)
		var body:= await _grab()
		_set_silhouette(false)
		for cfg: Array in CONFIGS:
			_apply(cfg)
			var shown:= await _grab("t_%.0f_%s" % [d, cfg [4]])
			var res:= _compare(body, shown)
			var leaked: int = res [0]
			var area: int = res [1]
			var t:= 0.0
			if area > 0:
				t = 100.0 * float(leaked) / float(area)
			print("  %4.0fm  %-24s %9d  %8d   %9.4f%%" % [d, cfg [0], leaked, area, t])
		_apply(CONFIGS [0])
		print("")

	print("  (transmission = fraction of the pile you can see through)")

	world.warehouse.visible = true
	env.background_mode = saved ["bg"]
	env.background_color = saved ["color"]
	env.tonemap_mode = saved ["tone"]
	env.tonemap_exposure = saved ["exposure"]
	env.glow_enabled = saved ["glow"]
	env.ambient_light_source = saved ["amb_src"]
	env.ambient_light_color = saved ["amb_col"]
	env.ambient_light_energy = saved ["amb_e"]
	get_tree().quit()


func _place(gap: float) -> void:
	var pos:= Vector3(Cfg.PILE_RADIUS + gap, 1.7, 0.0)
	_cam.look_at_from_position(pos, Vector3(0.0, Cfg.PILE_HEIGHT * 0.45, 0.0), Vector3.UP)
	var p: Player = world.player
	if p != null:
		p.global_position = pos - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
		p.velocity = Vector3.ZERO
	world.field.update_lod(pos)


func _set_silhouette(on: bool) -> void:
	for c in world.field.chunks:
		var crust: Node3D = c.get_node_or_null("Crust")
		var shell: Node3D = c.get_node_or_null("Shell")
		var proxy: MeshInstance3D = c.get_node_or_null("ShadowProxy")
		if crust != null:
			crust.visible = not on
		if shell != null:
			shell.visible = not on
		if proxy != null:
			if on:
				proxy.material_override = _silhouette_mat
				proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				proxy.material_override = StrandFactory.shadow_proxy_material()
				proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


const EDGE_ERODE:= 3


func _compare(body: PackedByteArray, shown: PackedByteArray) -> Array:
	var size:= get_viewport().get_visible_rect().size
	var w:= int(size.x)
	var h:= int(size.y)
	var leaked:= 0
	var area:= 0
	var e:= EDGE_ERODE
	for y in range(e, h - e):
		var row:= y * w
		for x in range(e, w - e):
			var i:= (row + x) * 4
			if _is_backdrop(body, i):
				continue

			if _is_backdrop(body, (row + x - e) * 4) or _is_backdrop(body, (row + x + e) * 4) or _is_backdrop(body, ((y - e) * w + x) * 4) or _is_backdrop(body, ((y + e) * w + x) * 4):
				continue
			area += 1
			if _is_backdrop(shown, i):
				leaked += 1
	return [leaked, area]


func _apply(cfg: Array) -> void:
	StrandFactory.pile_surface_material().set_shader_parameter("solid_core", cfg [3])
	for c in world.field.chunks:
		var crust: Node3D = c.get_node_or_null("Crust")
		var shell: Node3D = c.get_node_or_null("Shell")
		if crust != null:
			crust.visible = cfg [1]
		if shell != null:
			shell.visible = cfg [2]


func _pixels() -> int:
	var s:= get_viewport().get_visible_rect().size
	return int(s.x) * int(s.y)


func _is_backdrop(data: PackedByteArray, i: int) -> bool:
	return data [i] > 90 and data [i + 2] > 90 and data [i + 1] * 2 < data [i + 2]


func _grab(dump: String = "") -> PackedByteArray:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if dump != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
		img.save_png("res://captures/%s.png" % dump)
	return img.get_data()
