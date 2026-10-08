class_name NeedleView
extends SubViewportContainer


const FIT:= 0.72


const FOV:= 26.0


const IDLE_SPIN:= 0.55

var type:= -1


var yaw:= 0.0
var pitch:= -0.18

var zoom:= 1.0


var spin:= IDLE_SPIN


var clip: Control = null

var _view: SubViewport
var _pivot: Node3D
var _mesh: MeshInstance3D
var _cam: Camera3D

var _fit_distance:= 0.5


func _init() -> void:
	stretch = true


	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	if type >= 0:
		set_type(type)


func park() -> void:
	if _view == null:
		return
	stretch = false
	_view.size = Vector2i(8, 8)


func _notification(what: int) -> void:

	if what == NOTIFICATION_ENTER_TREE and not stretch and clip == null:
		stretch = true


func _build() -> void:
	_view = SubViewport.new()
	_view.name = "SpecimenView"


	_view.size = Vector2i(8, 8)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.disable_3d = false


	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.msaa_3d = Viewport.MSAA_4X if rich() else Viewport.MSAA_DISABLED
	add_child(_view)

	var world:= WorldEnvironment.new()
	world.environment = _studio_env()
	_view.add_child(world)

	_add_lights(_view)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_view.add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_mesh)

	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.01
	_cam.far = 12.0
	_view.add_child(_cam)


static func rich() -> bool:
	return Cfg.quality > Cfg.Quality.LOW


func apply_preset() -> void:
	if _view == null:
		return
	var msaa:= Viewport.MSAA_4X if rich() else Viewport.MSAA_DISABLED
	if _view.msaa_3d != msaa:
		_view.msaa_3d = msaa
	_studio_env()


static var _env: Environment = null


static func _studio_env() -> Environment:
	if _env != null:

		if _env.glow_enabled != rich():
			_env.glow_enabled = rich()
		return _env
	var env:= Environment.new()


	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.sky = _studio_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY


	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.glow_enabled = rich()
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	_env = env
	return env


static func _add_lights(into: Node) -> void:
	var key:= DirectionalLight3D.new()
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.96, 0.88)
	key.light_specular = 1.1
	key.rotation = Vector3(deg_to_rad(-32.0), deg_to_rad(38.0), 0.0)
	key.shadow_enabled = false
	into.add_child(key)
	var fill:= DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.light_color = Color(0.66, 0.76, 1.0)
	fill.rotation = Vector3(deg_to_rad(18.0), deg_to_rad(-128.0), 0.0)
	fill.shadow_enabled = false
	into.add_child(fill)
	var rim:= DirectionalLight3D.new()
	rim.light_energy = 1.3
	rim.light_color = Color(1.0, 0.9, 0.74)
	rim.light_specular = 1.6
	rim.rotation = Vector3(deg_to_rad(24.0), deg_to_rad(168.0), 0.0)
	rim.shadow_enabled = false
	into.add_child(rim)


func set_type(t: int) -> void:
	type = t
	if _mesh == null:
		return
	var mesh:= StrandFactory.needle_model(t)
	_mesh.mesh = mesh


	apply_preset()
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		_mesh.set_surface_override_material(s, _display_material(mesh, s))


	var aabb:= mesh.get_aabb()
	_mesh.position = - aabb.get_center()
	var span:= maxf(aabb.size.length(), 0.001)
	_fit_distance = (span * 0.5) / tan(deg_to_rad(FOV * 0.5)) / FIT


static var _display_mats: Dictionary = { }


static func _display_material(mesh: Mesh, surface: int) -> StandardMaterial3D:
	var src:= mesh.surface_get_material(surface)
	var key:= src.resource_name if src != null else ""
	if _display_mats.has(key):
		return _display_mats [key]
	var m:= _make_display_material(key)
	_display_mats [key] = m
	return m


static func _make_display_material(key: String) -> StandardMaterial3D:
	var spec:= NeedleCabinet.flat_spec(key)
	var m:= StandardMaterial3D.new()
	m.resource_name = key
	var colour:= Cfg.COL_NEEDLE
	if spec.has("color"):
		var c: Array = spec ["color"]
		colour = Color(float(c [0]), float(c [1]), float(c [2]))
	var alpha:= float(spec.get("alpha", 1.0))
	m.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	m.metallic = float(spec.get("metal", 0.0))


	var polish:= 0.45 if float(spec.get("metal", 0.0)) >= 0.5 else 0.7
	m.roughness = clampf(float(spec.get("rough", 0.3)) * polish, 0.02, 1.0)
	m.metallic_specular = 0.8
	if m.metallic < 0.5:


		m.clearcoat_enabled = true
		m.clearcoat = 0.7
		m.clearcoat_roughness = 0.06
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.5
	var emit:= float(spec.get("emit", 0.0))
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = emit * 1.6
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


const SKY_W:= 256
const SKY_H:= 128


const SOFTBOXES:= [
	{ "at": 0.1, "width": 0.055, "power": 7.0 },
	{ "at": 0.42, "width": 0.025, "power": 9.0 },
	{ "at": 0.68, "width": 0.09, "power": 3.4 },
]

static var _sky: Sky = null


static func _studio_sky() -> Sky:
	if _sky != null:
		return _sky
	var img:= Image.create(SKY_W, SKY_H, false, Image.FORMAT_RGBF)
	for y in SKY_H:

		var v:= float(y) / float(SKY_H - 1)


		var room:= lerpf(0.42, 0.01, smoothstep(0.0, 0.72, v))
		for x in SKY_W:
			var u:= float(x) / float(SKY_W)
			var lit:= room
			for box: Dictionary in SOFTBOXES:


				var d: float = absf(u - float(box ["at"]))
				d = minf(d, 1.0 - d)
				var across:= 1.0 - smoothstep(0.0, float(box ["width"]), d)


				var down:= 1.0 - smoothstep(0.6, 0.86, v)
				var up:= smoothstep(0.02, 0.14, v)
				lit += float(box ["power"]) * across * across * down * up
			img.set_pixel(x, y, Color(lit, lit * 0.985, lit * 0.955))
	var mat:= PanoramaSkyMaterial.new()
	mat.panorama = ImageTexture.create_from_image(img)
	mat.energy_multiplier = 1.0
	_sky = Sky.new()
	_sky.sky_material = mat
	_sky.radiance_size = Sky.RADIANCE_SIZE_128
	return _sky


func _process(delta: float) -> void:
	if _pivot == null or _cam == null:
		return
	yaw += spin * delta


	if clip != null and is_instance_valid(clip) and is_visible_in_tree():
		var mode:= SubViewport.UPDATE_ALWAYS
		var mine:= get_global_rect()
		var seen:= clip.get_global_rect()
		if mine.has_area() and seen.has_area() and not seen.intersects(mine):
			mode = SubViewport.UPDATE_DISABLED
		if _view.render_target_update_mode != mode:
			_view.render_target_update_mode = mode
		if mode == SubViewport.UPDATE_DISABLED:
			return
		if not stretch:
			stretch = true


	_pivot.transform = Transform3D(
		Basis.from_euler(Vector3(pitch, yaw, deg_to_rad(-9.0))), Vector3.ZERO)
	_cam.position = Vector3(0, 0, _fit_distance * zoom)
	_cam.look_at(Vector3.ZERO, Vector3.UP)


static var warm_enabled: bool = not ("--oldneedlewarm" in OS.get_cmdline_user_args())


static func warm_view() -> SubViewport:
	var view:= SubViewport.new()
	view.name = "NeedleWarm"
	view.size = Vector2i(16, 16)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X if rich() else Viewport.MSAA_DISABLED
	var world:= WorldEnvironment.new()
	world.environment = _studio_env()
	view.add_child(world)
	_add_lights(view)
	var reach:= 0.001
	for t in NeedleTypes.count():
		var mesh:= StrandFactory.needle_model(t)
		if mesh == null:
			continue
		var mi:= MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mesh.get_surface_count():
			mi.set_surface_override_material(s, _display_material(mesh, s))
		var aabb:= mesh.get_aabb()
		mi.position = - aabb.get_center()
		reach = maxf(reach, aabb.size.length())
		view.add_child(mi)
	var cam:= Camera3D.new()
	cam.fov = FOV
	cam.near = 0.01
	cam.far = 12.0
	cam.position = Vector3(0, 0, (reach * 0.5) / tan(deg_to_rad(FOV * 0.5)) / FIT)
	view.add_child(cam)
	return view
