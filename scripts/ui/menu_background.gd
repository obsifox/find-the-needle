class_name MenuBackground
extends Node3D


const HDRI_PATH:= "res://assets/downloaded/hdri/kloofendal_43d_clear_puresky_2k.hdr"

const HDRI_SUN_DIR:= Vector3(0.4313, 0.6817, -0.591)


const MENU_SEED:= 41207

const CAM_TARGET:= Vector3(0.0, 2.4, 0.0)


const CAM_RADIUS:= 21.0
const CAM_HEIGHT:= 8.6


const CAM_BASE_ANGLE:= 44.0

const CAM_SWING:= 4.0
const CAM_PERIOD:= 78.0
const CAM_RISE:= 0.5


const CAM_OFFSET_YAW:= 12.0


const MENU_PERF_SCALE:= 1.7


const GLINT_XZ:= Vector2(4.5, 7.5)


const GLINT_TILT:= Vector2(6.0, 1.3)
const GLINT_RATE:= Vector2(0.19, 0.071)


const GLINT_SHARPNESS:= 4500.0


const GLINT_DECAY:= 5.5


const GLINT_ENERGY:= 7.5

const BASE_GLOW:= 0.18
const FLARE_GLOW:= 0.3

var field: HayField
var camera: Camera3D

var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _needle_glint: Node3D
var _glint_flash: Node3D
var _glint_light: OmniLight3D
var _flare_mat: ShaderMaterial
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial


var _facet_aim:= Vector3.UP

var _glint_hot:= 0.0

var _time:= 0.0


var staged:= false


signal built


func _ready() -> void:
	await _build()
	built.emit()


func _stage(caption: String, progress: float) -> void:
	if not staged:
		return
	Loading.step(caption, progress)
	await get_tree().process_frame


func _build() -> void:


	StrandFactory.set_highlight(Vector3.ZERO, 0.0)
	_build_environment()
	_build_sun()

	var warehouse:= Warehouse.new()
	warehouse.name = "Warehouse"


	warehouse.follow_tech = false
	add_child(warehouse)


	PhysicsServer3D.set_active(false)

	Cfg.perf_scale = MENU_PERF_SCALE


	Cfg.apply_pile_size(Cfg.DEFAULT_PILE_SIZE)

	await _stage(tr("RAISING THE SHED"), 0.2)
	field = HayField.new()
	field.name = "Pile"
	add_child(field)


	field.set_process(false)
	if staged:
		await field.generate_staged(MENU_SEED, PackedFloat32Array(),
			func(f: float) -> void: Loading.step(tr("STACKING THE HAY"), lerpf(0.25, 0.9, f)))
	else:
		field.generate(MENU_SEED)

	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = 64.0
	camera.far = 140.0


	var attrs:= CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 26.0
	attrs.dof_blur_far_transition = 14.0
	attrs.dof_blur_amount = 0.05
	camera.attributes = attrs
	add_child(camera)
	_place_camera(0.0)
	field.update_lod(camera.global_position)
	_build_needle_glint()


	_apply_preset()
	Cfg.quality_changed.connect(_on_quality_changed)


func _exit_tree() -> void:
	PhysicsServer3D.set_active(true)
	Cfg.perf_scale = 1.0


func _process(delta: float) -> void:

	if camera == null:
		return
	_time += delta
	_place_camera(_time)
	_animate_needle_glint()


	field.update_lod(camera.global_position)


func _build_needle_glint() -> void:
	_needle_glint = Node3D.new()
	_needle_glint.name = "NeedleGlint"
	_needle_glint.position = Vector3(
		GLINT_XZ.x,
		field.height_at(GLINT_XZ.x, GLINT_XZ.y) + 0.07,
		GLINT_XZ.y
	)
	add_child(_needle_glint)


	var to_sun:= HDRI_SUN_DIR.normalized()
	var to_cam:= (camera.global_position - _needle_glint.global_position).normalized()
	_facet_aim = (to_sun + to_cam).normalized()

	_glint_flash = Node3D.new()
	_glint_flash.name = "Flash"
	_needle_glint.add_child(_glint_flash)


	var flare_shader:= Shader.new()
	flare_shader.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled, shadows_disabled;\n\nuniform vec4 core_tint : source_color = vec4(1.0, 0.99, 0.96, 1.0);\nuniform vec4 edge_tint : source_color = vec4(1.0, 0.84, 0.55, 1.0);\nuniform float energy = 0.0;\n\nvoid fragment() {\n\tvec2 p = UV * 2.0 - 1.0;\n\tfloat r = length(p);\n\n\t// The core: a point that clips whatever the exposure, sat in a hot ball.\n\tfloat core = exp(-r * r * 1400.0) * 6.0 + exp(-r * r * 210.0) * 1.4;\n\n\t// The bloom around it. Wide and soft, and warmer than the core, because the\n\t// long end of the spectrum is the end that scatters on the way through.\n\tfloat halo = exp(-r * r * 34.0) * 0.42 + exp(-r * r * 7.0) * 0.15;\n\n\tfloat v = (core + halo) * (1.0 - smoothstep(0.62, 1.0, r));\n\t// White at the middle, gold at the fringes: hot centres lose their colour.\n\tALBEDO = mix(edge_tint.rgb, core_tint.rgb, clamp(core, 0.0, 1.0)) * v * energy;\n\tALPHA = 1.0;\n}\n"


	_flare_mat = ShaderMaterial.new()
	_flare_mat.shader = flare_shader
	var flare_mesh:= QuadMesh.new()
	flare_mesh.size = Vector2(1.15, 1.15)
	flare_mesh.material = _flare_mat
	var flare:= MeshInstance3D.new()
	flare.name = "SpecularGlint"
	flare.mesh = flare_mesh
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint_flash.add_child(flare)

	_glint_light = OmniLight3D.new()
	_glint_light.name = "FlashLight"
	_glint_light.light_color = Color(1.0, 0.93, 0.72)
	_glint_light.light_energy = 0.0
	_glint_light.omni_range = 2.4
	_glint_light.shadow_enabled = false
	_needle_glint.add_child(_glint_light)

	_build_flare_overlay()
	_animate_needle_glint()


func _build_flare_overlay() -> void:
	var overlay_shader:= Shader.new()
	overlay_shader.code = "\nshader_type canvas_item;\nrender_mode blend_add, unshaded;\n\nuniform vec2 flare_pos = vec2(0.5, 0.5);\nuniform float intensity = 0.0;\nuniform float aspect = 1.777;\n\n// A soft aperture disc, brighter at its rim the way a defocused iris is.\nfloat ghost(vec2 q, vec2 c, float rad, float soft) {\n\tfloat d = length(q - c) / rad;\n\tfloat body = 1.0 - smoothstep(1.0 - soft, 1.0, d);\n\tfloat rim = smoothstep(0.55, 0.95, d) * (1.0 - smoothstep(0.95, 1.06, d));\n\treturn body * 0.5 + rim * 1.0;\n}\n\nvoid fragment() {\n\t// Distances in screen heights, so nothing here stretches with the window.\n\tvec2 q = (UV - flare_pos) * vec2(aspect, 1.0);\n\tvec2 axis = (vec2(0.5) - flare_pos) * vec2(aspect, 1.0);\n\tfloat d = length(q);\n\tfloat a = atan(q.y, q.x);\n\n\t// The source, as the lens passes it on. A core that clips to flat white --\n\t// no colour survives at that level -- inside two balls of scattered light,\n\t// each wider and warmer than the last.\n\tvec3 v = vec3(1.0) * smoothstep(0.013, 0.006, d) * 2.5;\n\tv += vec3(1.0) * exp(-d * 74.0) * 2.4;\n\tv += vec3(1.0, 0.98, 0.93) * exp(-d * 21.0) * 0.42;\n\tv += vec3(1.0, 0.90, 0.70) * exp(-d * 6.6) * 0.13;\n\n\t// Veiling glare: light loose inside the barrel, lifting the whole frame and\n\t// taking the blacks with it. Small, but it is most of why a real flare feels\n\t// like it is happening to the camera rather than in the room.\n\tv += vec3(1.0, 0.88, 0.70) * exp(-d * 3.0) * 0.045;\n\n\t// The star. Dust and scratches on the glass, so the spikes are of uneven\n\t// length and unevenly spaced -- an even star is a decal.\n\tfloat star = 0.0;\n\tstar += pow(max(cos(a), 0.0), 44.0) * exp(-d * 4.6) * 1.05;\n\tstar += pow(max(-cos(a), 0.0), 44.0) * exp(-d * 6.4) * 0.78;\n\tstar += pow(abs(sin(a)), 90.0) * exp(-d * 8.5) * 0.62;\n\tstar += pow(abs(cos(a * 2.0 + 0.79)), 120.0) * exp(-d * 16.0) * 0.30;\n\tstar += pow(abs(cos(a * 9.0 + 0.4)), 80.0) * exp(-d * 24.0) * 0.19;\n\tstar *= smoothstep(0.0, 0.010, d);\n\tv += vec3(1.0, 0.95, 0.82) * star;\n\n\t// The anamorphic streak: one long horizontal smear, a hard line inside a\n\t// soft one, cooler than the rest because it comes off the coatings.\n\tfloat dx = abs(q.x);\n\tfloat dy = abs(q.y);\n\tv += vec3(0.80, 0.89, 1.0) * exp(-dy * 420.0) * exp(-dx * 5.0) * 0.70;\n\tv += vec3(0.72, 0.82, 1.0) * exp(-dy * 90.0) * exp(-dx * 7.0) * 0.16;\n\n\t// Ghosts, walking the line from the source through the middle of frame and\n\t// out the far side. Sizes and tints vary per element, as they do in glass.\n\tv += vec3(1.00, 0.78, 0.48) * ghost(q, axis * 0.42, 0.070, 0.55) * 0.11;\n\tv += vec3(0.58, 0.95, 0.74) * ghost(q, axis * 0.79, 0.032, 0.75) * 0.15;\n\tv += vec3(0.68, 0.80, 1.00) * ghost(q, axis * 1.31, 0.105, 0.35) * 0.07;\n\tv += vec3(1.00, 0.92, 0.62) * ghost(q, axis * 1.74, 0.022, 0.85) * 0.13;\n\tv += vec3(0.84, 0.70, 1.00) * ghost(q, axis * 2.10, 0.048, 0.60) * 0.06;\n\n\tCOLOR = vec4(v * intensity, 1.0);\n}\n"


	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = overlay_shader


	var layer:= CanvasLayer.new()
	layer.name = "FlareLayer"
	layer.layer = 0
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.name = "LensFlare"
	_overlay.material = _overlay_mat
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	layer.add_child(_overlay)


func _animate_needle_glint() -> void:
	if _needle_glint == null or camera == null:
		return
	_glint_flash.look_at(camera.global_position, Vector3.UP)


	var side:= _facet_aim.cross(Vector3.UP).normalized()
	var up:= side.cross(_facet_aim).normalized()
	var normal:= _facet_aim.rotated(up, deg_to_rad(sin(_time * TAU * GLINT_RATE.x) * GLINT_TILT.x)).rotated(side, deg_to_rad(sin(_time * TAU * GLINT_RATE.y + 1.1) * GLINT_TILT.y))


	var to_sun:= HDRI_SUN_DIR.normalized()
	var to_cam:= (camera.global_position - _needle_glint.global_position).normalized()
	var half:= (to_sun + to_cam).normalized()
	var spec:= pow(maxf(normal.dot(half), 0.0), GLINT_SHARPNESS)


	_glint_hot = maxf(spec, _glint_hot - get_process_delta_time() * GLINT_DECAY)
	var hot:= _glint_hot

	_glint_flash.visible = hot > 0.002
	if _glint_flash.visible:


		_glint_flash.scale = Vector3.ONE * lerpf(0.42, 1.0, pow(hot, 0.35))
		_flare_mat.set_shader_parameter("energy", hot * GLINT_ENERGY)
	_glint_light.light_energy = hot * 4.5

	_update_flare_overlay(hot)


	var e:= _env.environment
	if e.glow_enabled:
		e.glow_intensity = lerpf(BASE_GLOW, FLARE_GLOW, hot)


func _update_flare_overlay(hot: float) -> void:


	if hot <= 0.004 or camera.is_position_behind(_needle_glint.global_position):
		_overlay.visible = false
		return
	var size:= get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		_overlay.visible = false
		return
	var at:= camera.unproject_position(_needle_glint.global_position) / size
	_overlay.visible = true
	_overlay_mat.set_shader_parameter("flare_pos", at)
	_overlay_mat.set_shader_parameter("aspect", size.x / size.y)
	_overlay_mat.set_shader_parameter("intensity", hot)


func _on_quality_changed(_level: int) -> void:
	Cfg.perf_scale = MENU_PERF_SCALE
	_apply_preset()


	field.rebuild_density()
	field.update_lod(camera.global_position)


func _apply_preset() -> void:
	var p:= Cfg.preset()
	var vp:= get_viewport()
	vp.msaa_3d = p ["msaa"]
	vp.scaling_3d_scale = p ["render_scale"]


	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if float(p ["render_scale"]) >= 0.999 else Viewport.SCALING_3D_MODE_FSR
	vp.use_taa = p ["taa"]
	var e:= _env.environment
	e.ssao_enabled = p ["ssao"]
	e.glow_enabled = p ["glow"]
	_sun.shadow_enabled = p ["shadows"]


func _place_camera(t: float) -> void:
	var phase:= TAU * t / CAM_PERIOD
	var angle:= deg_to_rad(CAM_BASE_ANGLE + sin(phase) * CAM_SWING)
	var h:= CAM_HEIGHT + sin(phase * 0.61) * CAM_RISE
	var pos:= Vector3(cos(angle) * CAM_RADIUS, h, sin(angle) * CAM_RADIUS)
	camera.look_at_from_position(pos, CAM_TARGET, Vector3.UP)

	camera.rotate_y(deg_to_rad(CAM_OFFSET_YAW))


func _build_environment() -> void:
	var e:= Environment.new()

	var sky_mat:= PanoramaSkyMaterial.new()
	sky_mat.panorama = load(HDRI_PATH)
	sky_mat.energy_multiplier = 1.0
	var sky:= Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	e.background_mode = Environment.BG_SKY
	e.sky = sky


	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.85
	e.ambient_light_color = Color(0.62, 0.5, 0.36)
	e.ambient_light_energy = 0.62
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.85
	e.tonemap_white = 8.0

	e.glow_enabled = true
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.glow_intensity = BASE_GLOW
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.9
	e.glow_hdr_scale = 2.0
	var glow_curve:= [0.0, 0.1, 0.3, 0.7, 1.0, 0.7, 0.4]
	for i in glow_curve.size():
		e.set_glow_level(i, glow_curve [i])

	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.8
	e.ssao_power = 1.5
	e.ssao_light_affect = 0.12

	e.fog_enabled = true
	e.fog_density = 0.0035
	e.fog_light_color = Color(0.74, 0.74, 0.76)
	e.fog_sun_scatter = 0.15
	e.fog_aerial_perspective = 0.1
	e.fog_sky_affect = 0.0

	e.adjustment_enabled = true
	e.adjustment_contrast = 1.09
	e.adjustment_saturation = 1.04

	_env = WorldEnvironment.new()
	_env.name = "Environment"
	_env.environment = e
	add_child(_env)


func _build_sun() -> void:


	var sun:= DirectionalLight3D.new()
	_sun = sun
	sun.name = "Sun"
	add_child(sun)
	sun.look_at_from_position(HDRI_SUN_DIR, Vector3.ZERO, Vector3.UP)
	sun.light_energy = 2.6
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.light_angular_distance = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.7


	var fill:= DirectionalLight3D.new()
	fill.name = "BounceFill"
	add_child(fill)
	fill.look_at_from_position(Vector3(0.45, -0.55, -0.62), Vector3.ZERO, Vector3.UP)
	fill.light_energy = 0.52
	fill.light_color = Color(1.0, 0.84, 0.62)
	fill.light_specular = 0.0
	fill.shadow_enabled = false
