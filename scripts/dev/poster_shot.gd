class_name PosterShot
extends Node


const OUT_DIR:= "res://captures"
const SIZE:= Vector2i(3840, 2160)


const RAW_FLAG:= "--raw"


const WATCH_SECONDS:= 22.0


const SETTLE_FRAMES:= 40

const SHOT_FLOOR:= 0.45


const CLEAN_CEILING:= 0.01

const CLEAN_PATIENCE:= 240


const TITLE_TOP:= 163
const TITLE_BOTTOM:= 250
const TITLE_MARGIN:= Vector2(182.0, 132.0)


const TITLE_SEPARATION:= -19
const COL_TEXT:= Color(0.95, 0.96, 0.99)


const FOG_DENSITY:= 0.022


const FOG_ANISOTROPY:= 0.74
const SUN_FOG_ENERGY:= 5.4


const FOG_AMBIENT:= 0.05


const FOG_GRID:= 320
const FOG_GRID_DEPTH:= 256


const FOG_LENGTH:= 40.0


const DEPTH_FOG_DENSITY:= 0.0018


const EXPOSURE:= 0.71
const CONTRAST:= 1.2
const SATURATION:= 1.1


const RAY_SAMPLES:= 72


const RAY_DENSITY:= 0.4

const RAY_DECAY:= 0.98

const RAY_WEIGHT:= 0.058


const RAY_SKY_DIST:= 100.0

const RAY_TINT:= Color(1.0, 0.93, 0.78)


const MOTE_COUNT:= 3400
const MOTE_BOX:= Vector3(26.0, 12.0, 30.0)
const MOTE_CENTRE:= Vector3(0.0, 6.5, 0.0)
const MOTE_ENERGY:= 3.0


const MOTE_SIZE:= 0.032

var _vp: SubViewport
var _bg: MenuBackground
var _ray_mat: ShaderMaterial


var _raw:= false


func _ready() -> void:
	_raw = RAW_FLAG in OS.get_cmdline_user_args()
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build()


	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _shoot_clean()
	await _shoot_glint()
	get_tree().quit()


func _build() -> void:
	_vp = SubViewport.new()
	_vp.name = "PosterViewport"
	_vp.size = SIZE


	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	add_child(_vp)


	var layer:= CanvasLayer.new()
	layer.name = "PreviewLayer"
	add_child(layer)
	var preview:= TextureRect.new()
	preview.name = "Preview"
	preview.texture = _vp.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(preview)


	_bg = MenuBackground.new()
	_bg.name = "Background"
	_bg.staged = false
	_vp.add_child(_bg)


	_dress_the_viewport()
	if _raw:
		return
	_light_it()
	_build_shafts()
	_build_title()


func _process(_delta: float) -> void:
	if _ray_mat == null or _bg == null or _bg.camera == null:
		return
	var cam:= _bg.camera


	var away:= cam.global_position - MenuBackground.HDRI_SUN_DIR.normalized() * 400.0
	if cam.is_position_behind(away):
		return
	var size:= Vector2(_vp.size)
	_ray_mat.set_shader_parameter("origin", cam.unproject_position(away) / size)


func _build_shafts() -> void:
	var shader:= Shader.new()
	shader.code = "\r\nshader_type spatial;\r\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled,\r\n\tfog_disabled, shadows_disabled;\r\n\r\nuniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;\r\nuniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;\r\n\r\nuniform vec2 origin = vec2(-0.86, 2.62);\r\nuniform float density = 0.44;\r\nuniform float decay = 0.976;\r\nuniform float weight = 0.050;\r\nuniform float sky_dist = 100.0;\r\nuniform vec4 tint : source_color = vec4(1.0, 0.93, 0.78, 1.0);\r\n\r\nconst int SAMPLES = %d;\r\n\r\nvoid fragment() {\r\n\t// One step along the beam this pixel sits on. The line is the one through\r\n\t// the vanishing point, and the march runs AWAY from it -- back up the beam\r\n\t// towards the sky the light is arriving from, which is the end of it with\r\n\t// something on it worth collecting.\r\n\tvec2 step_uv = (SCREEN_UV - origin) * (density / float(SAMPLES));\r\n\tvec2 at = SCREEN_UV;\r\n\tfloat lit = 1.0;\r\n\tvec3 acc = vec3(0.0);\r\n\r\n\tfor (int i = 0; i < SAMPLES; i++) {\r\n\t\tat += step_uv;\r\n\t\tvec2 tap = clamp(at, vec2(0.001), vec2(0.999));\r\n\t\t// Open sky, or something in the way. A truss in the way is the whole\r\n\t\t// reason there are separate shafts rather than one wash of light.\r\n\t\tvec3 ndc = vec3(tap * 2.0 - 1.0, textureLod(depth_tex, tap, 0.0).r);\r\n\t\tvec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);\r\n\t\tfloat open = step(sky_dist, -view.z / view.w);\r\n\t\tacc += texture(screen_tex, tap).rgb * open * lit * weight;\r\n\t\tlit *= decay;\r\n\t}\r\n\r\n\tALBEDO = acc * tint.rgb;\r\n\tALPHA = 1.0;\r\n}\r\n" % RAY_SAMPLES

	_ray_mat = ShaderMaterial.new()
	_ray_mat.shader = shader
	_ray_mat.render_priority = 20
	_ray_mat.set_shader_parameter("density", RAY_DENSITY)
	_ray_mat.set_shader_parameter("decay", RAY_DECAY)
	_ray_mat.set_shader_parameter("weight", RAY_WEIGHT)
	_ray_mat.set_shader_parameter("sky_dist", RAY_SKY_DIST)
	_ray_mat.set_shader_parameter("tint", RAY_TINT)


	var cam:= _bg.camera
	var half:= tan(deg_to_rad(cam.fov) * 0.5) * 0.5
	var quad:= QuadMesh.new()
	quad.size = Vector2(half * 2.0 * 2.4, half * 2.0 * 1.2)
	quad.material = _ray_mat

	var mi:= MeshInstance3D.new()
	mi.name = "Shafts"
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	mi.extra_cull_margin = 100.0
	mi.position = Vector3(0.0, 0.0, -0.5)
	cam.add_child(mi)


func _dress_the_viewport() -> void:
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.scaling_3d_scale = 1.0
	_vp.use_taa = false
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.positional_shadow_atlas_size = 4096
	var sun:= _bg.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 60.0


func _light_it() -> void:
	var we:= _bg.get_node_or_null("Environment") as WorldEnvironment
	if we == null:
		push_error("[poster] the backdrop has no Environment to light")
		return
	var e:= we.environment

	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = FOG_DENSITY
	e.volumetric_fog_albedo = Color(0.9, 0.84, 0.72)
	e.volumetric_fog_emission_energy = 0.0
	e.volumetric_fog_gi_inject = 0.0
	e.volumetric_fog_anisotropy = FOG_ANISOTROPY
	e.volumetric_fog_length = FOG_LENGTH


	e.volumetric_fog_detail_spread = 1.2
	e.volumetric_fog_ambient_inject = FOG_AMBIENT
	e.volumetric_fog_sky_affect = 0.0


	e.volumetric_fog_temporal_reprojection_enabled = true
	e.volumetric_fog_temporal_reprojection_amount = 0.9
	RenderingServer.environment_set_volumetric_fog_volume_size(FOG_GRID, FOG_GRID_DEPTH)

	e.fog_density = DEPTH_FOG_DENSITY


	e.glow_enabled = true
	e.glow_bloom = 0.1

	e.tonemap_exposure = EXPOSURE
	e.adjustment_enabled = true
	e.adjustment_contrast = CONTRAST
	e.adjustment_saturation = SATURATION

	var sun:= _bg.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_volumetric_fog_energy = SUN_FOG_ENERGY


	var fill:= _bg.get_node_or_null("BounceFill") as DirectionalLight3D
	if fill != null:
		fill.light_volumetric_fog_energy = 0.0

	_build_motes()


func _build_motes() -> void:
	var shader:= Shader.new()
	shader.code = "\r\nshader_type spatial;\r\nrender_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;\r\n\r\nuniform vec4 tint : source_color = vec4(1.0, 0.94, 0.80, 1.0);\r\n// Which way the sun is coming from. A mote is only visible when it is between\r\n// the light and the eye, so this is most of what sells them.\r\nuniform vec3 to_sun = vec3(0.4313, 0.6817, -0.5910);\r\nuniform float energy = 3.0;\r\n\r\nvoid fragment() {\r\n\tvec2 p = UV * 2.0 - 1.0;\r\n\tfloat r = length(p);\r\n\t// A soft speck, gone well inside its quad so no edge is ever visible.\r\n\tfloat speck = exp(-r * r * 12.0) * (1.0 - smoothstep(0.55, 1.0, r));\r\n\r\n\t// Forward scatter: brightest looking into the sun, almost nothing looking\r\n\t// away from it.\r\n\tvec3 eye = normalize(-VERTEX);\r\n\tfloat phase = clamp(dot(eye, -normalize(to_sun)), -1.0, 1.0);\r\n\tfloat lobe = 0.10 + 0.90 * pow(clamp(-phase, 0.0, 1.0), 3.0);\r\n\r\n\tALBEDO = tint.rgb * speck * lobe * energy;\r\n\tALPHA = 1.0;\r\n}\r\n"


	var mat:= ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("energy", MOTE_ENERGY)

	var mesh:= QuadMesh.new()
	mesh.size = Vector2(MOTE_SIZE, MOTE_SIZE)
	mesh.material = mat

	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = MOTE_COUNT


	var rng:= RandomNumberGenerator.new()
	rng.seed = 90210
	var eye:= _bg.camera.global_position
	for i in MOTE_COUNT:
		var at:= MOTE_CENTRE + Vector3(
			rng.randf_range(-0.5, 0.5) * MOTE_BOX.x,
			rng.randf_range(-0.5, 0.5) * MOTE_BOX.y,
			rng.randf_range(-0.5, 0.5) * MOTE_BOX.z
		)

		var s:= rng.randf_range(0.45, 1.9)


		var b:= Basis.looking_at(at - eye, Vector3.UP).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(b, at))

	var mmi:= MultiMeshInstance3D.new()
	mmi.name = "Motes"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	mmi.material_override = mat
	_bg.add_child(mmi)


func _build_title() -> void:
	var layer:= CanvasLayer.new()
	layer.name = "TitleLayer"
	layer.layer = 2
	_vp.add_child(layer)

	var box:= VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", TITLE_SEPARATION)
	box.position = TITLE_MARGIN
	box.custom_minimum_size = Vector2(2200.0, 0.0)
	layer.add_child(box)

	box.add_child(_title_line("FIND THE", TITLE_TOP))
	box.add_child(_title_line("NEEDLE", TITLE_BOTTOM))


func _title_line(text: String, size: int) -> Control:
	var font:= UiFont.bold()
	var height:= ceilf(font.get_height(size))
	var bounds:= Vector2(2200.0, height + 24.0)

	var holder:= Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(bounds.x, height)

	var radius:= 4.0 * (float(size) / 104.0) * 2.4
	for i in 16:
		var angle:= TAU * float(i) / 16.0
		holder.add_child(_glyphs(text, size, Color(0.0, 0.0, 0.0, 0.92),
			Vector2(cos(angle), sin(angle)) * radius, bounds))
	holder.add_child(_glyphs(text, size, COL_TEXT, Vector2.ZERO, bounds))
	return holder


func _glyphs(text: String, size: int, colour: Color, at: Vector2,
		bounds: Vector2) -> Label:
	var label:= Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override("font", UiFont.bold())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", 0)
	label.position = at
	label.size = bounds
	return label


func _shoot_clean() -> void:
	var waited:= 0
	while waited < CLEAN_PATIENCE:
		await get_tree().process_frame
		waited += 1
		if float(_bg.get("_glint_hot")) <= CLEAN_CEILING:
			break
	var img:= await _grab()
	_save("poster_menu_4k%s" % ("_raw" if _raw else ""), img)


func _shoot_glint() -> void:
	var elapsed:= 0.0
	var best:= 0.0
	var best_img: Image = null
	var seen:= 0
	var previous:= 0.0
	var rising:= false

	while elapsed < WATCH_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var hot:= float(_bg.get("_glint_hot"))
		if hot > previous:
			rising = true
		elif rising and previous > SHOT_FLOOR:
			rising = false
			seen += 1
			print("[poster] glint %d at %5.2fs, peak %.2f" % [seen, elapsed, previous])
		previous = hot

		if hot > SHOT_FLOOR and hot > best:
			best = hot
			best_img = await _grab()

	if best_img == null:
		push_error("[poster] no glint over %.2f in %.0fs -- nothing to photograph"
			% [SHOT_FLOOR, WATCH_SECONDS])
		return
	print("[poster] %d glints, brightest %.2f" % [seen, best])
	_save("poster_glint_4k%s" % ("_raw" if _raw else ""), best_img)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


func _save(shot_name: String, img: Image) -> void:
	var path:= "%s/%s.png" % [OUT_DIR, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[poster] %s  %dx%d" % [path, img.get_width(), img.get_height()])
